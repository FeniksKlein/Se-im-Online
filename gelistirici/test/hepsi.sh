#!/bin/bash
# Bakımı yapılan testleri sırayla çalıştırır; her testten önce yerel veritabanı sıfırdan kurulur.
# Kullanım: bash test/hepsi.sh          (yerel Postgres /tmp soketinde açık olmalı)
#           bash test/hepsi.sh eski     (ek olarak eski testler: ekonomi dengesi değiştiği için bazı beklentileri güncel değil)
cd "$(dirname "$0")"
basarisiz=0
testler="simulasyon guvenlik miting_canli parti_miting gazete_uzun gby_gorev_tepki"
[ "$1" = "eski" ] && testler="$testler sosyal devlet asama3 tek_gorev vatandas ekonomi2 bos_makam mevzuat meclis ekonomi3"
for t in $testler; do
  bash ../kur_yerel.sh >/dev/null 2>&1 || { echo "KURULUM HATASI ($t)"; exit 1; }
  if out=$(timeout 900 python3 "$t.py" 2>&1); then echo "✓ $t: $(echo "$out" | tail -1)"; else echo "✗ $t"; echo "$out" | tail -15; basarisiz=1; fi
done
# Kendi veritabanını kuran testler
for t in oyuncu_deneyimi kalicilik; do
  if out=$(timeout 900 python3 "$t.py" 2>&1); then echo "✓ $t: $(echo "$out" | tail -1)"; else echo "✗ $t"; echo "$out" | tail -15; basarisiz=1; fi
done
exit $basarisiz
