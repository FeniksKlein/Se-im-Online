#!/bin/bash
# Tüm testleri sırayla çalıştırır; her testten önce yerel veritabanı sıfırdan kurulur.
# Kullanım: bash test/hepsi.sh   (yerel Postgres /tmp soketinde açık olmalı)
cd "$(dirname "$0")"
basarisiz=0
for t in sosyal devlet asama3 simulasyon tek_gorev vatandas ekonomi2 bos_makam mevzuat meclis guvenlik ekonomi3; do
  [ -f "$t.py" ] || continue
  bash ../kur_yerel.sh >/dev/null 2>&1 || { echo "KURULUM HATASI ($t)"; exit 1; }
  if out=$(timeout 900 python3 "$t.py" 2>&1); then
    echo "✓ $t: $(echo "$out" | tail -1)"
  else
    echo "✗ $t"; echo "$out" | tail -15; basarisiz=1
  fi
done
if out=$(node istifa_arayuz.js 2>&1); then echo "✓ istifa_arayuz: $(echo "$out" | tail -1)"; else echo "✗ istifa_arayuz"; echo "$out" | tail -15; basarisiz=1; fi
bash ../build/sql_birlestir.sh >/dev/null
if out=$(python3 kalicilik.py 2>&1); then echo "✓ kalicilik: $(echo "$out" | tail -1)"; else echo "✗ kalicilik"; echo "$out" | tail -15; basarisiz=1; fi
exit $basarisiz
