#!/bin/bash
# migrations/20261009_emlak_meclis_son.sql dosyasını üretir:
#   43 + 44 + 45 kaynak modülleri
#   + deneme migration'larının (migrations/_iptal_20261009) üzerine yazdığı asıl fonksiyonların
#     temiz kurulumdaki tanımları (canlıda hangisi çalışmış olursa olsun asıl hâline döner).
# Yerel Postgres (/tmp soketi) açık olmalı; kur_yerel.sh ile temiz kurulum yapar.
set -e
cd "$(dirname "$0")/.."
bash kur_yerel.sh >/dev/null 2>&1
ISIMLER=$(cat ../migrations/_iptal_20261009/*.sql | grep -oiE "create or replace function (oyun|public)\.[a-z_0-9]+" | awk '{print tolower($5)}' | sort -u | paste -sd, -)
GERI=$(psql -h /tmp -U postgres -d oyun_test -At -c "
  select string_agg(pg_get_functiondef(p.oid) || ';', E'\n' order by n.nspname, p.proname, p.oid::regprocedure::text)
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname || '.' || p.proname = any (string_to_array('$ISIMLER', ','))")
CIKTI=../migrations/20261009_emlak_meclis_son.sql
{
  echo "-- 2026-10-09 · TEK GEÇERLİ GÜNCELLEME (sürüm $(cat SURUM)): il bazlı emlak stoğu ve fiyatı, haftalık mülk vergisi"
  echo "-- (belediyeye), 600 sandalyelik Meclis ve dolu sandalyeye göre salt çoğunluk."
  echo "-- Aynı gün üretilen deneme migration'larının (migrations/_iptal_20261009) yerine geçer; onlardan hangisi"
  echo "-- çalıştırılmış olursa olsun kalıntılarını temizler. Üreten: gelistirici/build/emlak_migration.sh"
  echo "begin;"
  cat sql/43_meclis_salt_cogunluk.sql sql/44_il_emlak_stok_vergi.sql sql/45_emlak_temizlik.sql
  echo
  echo "-- ---------------------------------------------------------------------"
  echo "-- Deneme migration'larının değiştirdiği asıl fonksiyonlar temiz kurulumdaki hâline döner"
  echo "-- ---------------------------------------------------------------------"
  echo "$GERI"
  echo "commit;"
} > "$CIKTI"
echo "$CIKTI: $(wc -l < "$CIKTI") satır, geri yüklenen fonksiyon: $(echo "$GERI" | grep -c '^CREATE OR REPLACE FUNCTION')"
