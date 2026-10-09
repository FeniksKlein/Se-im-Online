#!/bin/bash
# Yerel test veritabanını sıfırdan kurar: Supabase/pg_cron taklitleri + derlenmiş tam kurulum dosyası.
# (Yerelde pg_cron yok; taklit yalnızca iş kaydı tutar. check_function_bodies kapalı: Supabase'deki gibi
#  fonksiyon gövdeleri ilk çağrıda doğrulanır.)
set -e
cd "$(dirname "$0")"
node build/sql_birlestir.js >/dev/null
psql -h /tmp -U postgres -q -c "drop database if exists oyun_test" -c "create database oyun_test" 2>/dev/null
psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1 -f sql/00_supabase_taklit.sql -f sql/00_cron_taklit.sql >/dev/null
sed 's/^create extension if not exists pg_cron.*$//' dist/supabase-kurulum.sql > dist/yerel-kurulum.sql
PGOPTIONS='-c check_function_bodies=off -c client_min_messages=warning' psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1 -f dist/yerel-kurulum.sql >/dev/null
echo kuruldu
# Yerel test: eski testler için vatandaşlık şartlarını gevşet (yeni testler kendi değerlerini kurar)
psql -h /tmp -U postgres -d oyun_test -q -c "update oyun.ayarlar set maas_hizi=1, oy_min_kidem=0, oy_il_gun=0, cihaz_zorunlu=false, parti_kurucu_sayi=1, parti_kurucu_kidem=0, coklu_kontrol=false, eposta_zorunlu=false, parti_kur_ucret=0, teskilat_zorunlu=false"
