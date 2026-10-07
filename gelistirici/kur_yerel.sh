#!/bin/bash
# yerel test veritabanını sıfırdan kurar
set -e
cd /home/claude/online/app/sql
psql -h /tmp -U postgres -q -c "drop database if exists oyun_test" -c "create database oyun_test"
psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1 -f 00_supabase_taklit.sql -f kalicilik_bas.sql -c "select oyun.guncelleme_basla('yerel')"
for f in 01_sema.sql iller.sql 02_motor.sql 03_api.sql 05_kabine_sosyal.sql 07_devlet.sql 08_asama3.sql 09_vatandas.sql 10_ekonomi2.sql 11_bos_makam.sql 12_mevzuat.sql 13_meclis.sql 14_guvenlik.sql 06_yetkiler.sql kalicilik_son.sql; do
  psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1 -f $f
done
psql -h /tmp -U postgres -d oyun_test -q -At -v ON_ERROR_STOP=1 -c "select oyun.guncelleme_bitti()" >/dev/null
echo kuruldu
# Yerel test: eski testler için vatandaşlık şartlarını gevşet (yeni testler kendi değerlerini kurar)
psql -h /tmp -U postgres -d oyun_test -q -c "update oyun.ayarlar set maas_hizi=1, oy_min_kidem=0, oy_il_gun=0, cihaz_zorunlu=false, parti_kurucu_sayi=1, parti_kurucu_kidem=0, coklu_kontrol=false, eposta_zorunlu=false"
