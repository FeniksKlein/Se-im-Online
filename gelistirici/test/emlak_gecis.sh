#!/bin/bash
# 9 Ekim deneme migration'larının hepsi canlıya uygulanmış olsa bile 20261009_emlak_meclis_son.sql'in
# her şeyi temiz kuruluma eşitlediğini doğrular. Yerel Postgres (/tmp soketi) açık olmalı.
set -e
cd "$(dirname "$0")/.."
P="psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1"
FN="oyun._emlak_pazarlik_tamamla oyun.kanun_tick oyun.kanun_yururluk oyun.meclis_olcek_hesap oyun.mulk_kira_tahsil public.kanun_detay public.mulk_il_satin_al public.mulk_il_stok public.mulk_ilan_satin_al public.mulk_liste public.mulk_satin_al"
GECICI=$(mktemp -d)
dok() { for f in $FN; do psql -h /tmp -U postgres -d oyun_test -Atc "select string_agg(pg_get_functiondef(p.oid), E'\n' order by p.oid::regprocedure::text) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname||'.'||p.proname='$f'" > "$GECICI/$1_$f"; done; }

# 1) 43-45 olmadan kur (canlının 9 Ekim öğleden önceki hâli) + eski mülkler
cp build/sql_birlestir.js "$GECICI/sb.js"
sed -i "s/'43_meclis_salt_cogunluk.sql', '44_il_emlak_stok_vergi.sql', '45_emlak_temizlik.sql', //" build/sql_birlestir.js
bash kur_yerel.sh >/dev/null 2>&1 || { cp "$GECICI/sb.js" build/sql_birlestir.js; echo "kurulum hatası"; exit 1; }
cp "$GECICI/sb.js" build/sql_birlestir.js
(cd test && python3 -c "
from db import *
saat('2026-10-12 10:00')
for i in range(3):
    u=kullanici_ekle(f'eski{i}@t.com'); rpc(u,'profil_olustur',f'Eski{i}',34)
    q(f\"update oyun.cuzdan set para=5000000 where user_id='{u}'\"); rpc(u,'mulk_satin_al','daire')")

# 2) Bütün deneme migration'ları (çalışanlar uygulanır, bozuklar kendi işlemlerinde geri alınır)
n=0; for f in ../migrations/_iptal_20261009/*.sql; do PGOPTIONS='-c client_min_messages=error' $P -f "$f" >/dev/null 2>&1 && n=$((n+1)) || true; done
echo "deneme migration'larından $n tanesi uygulandı"

# 3) Tek geçerli migration
PGOPTIONS='-c client_min_messages=warning' $P -f ../migrations/20261009_emlak_meclis_son.sql >/dev/null
dok karma

# 4) Temiz kurulumla karşılaştır
bash kur_yerel.sh >/dev/null 2>&1; dok temiz
fark=0; for f in $FN; do cmp -s "$GECICI/karma_$f" "$GECICI/temiz_$f" || { echo "FARKLI: $f"; fark=1; }; done
[ $fark = 0 ] && echo "emlak_gecis: canlı geçişi temiz kurulumla aynı"
rm -rf "$GECICI"; exit $fark
