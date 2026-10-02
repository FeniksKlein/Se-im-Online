#!/bin/bash
# yerel test veritabanını sıfırdan kurar
set -e
cd /home/claude/online/app/sql
psql -h /tmp -U postgres -q -c "drop database if exists oyun_test" -c "create database oyun_test"
for f in 00_supabase_taklit.sql 01_sema.sql iller.sql 02_motor.sql 03_api.sql 05_kabine_sosyal.sql 07_devlet.sql 08_asama3.sql 09_vatandas.sql 10_ekonomi2.sql 06_yetkiler.sql; do
  psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1 -f $f
done
echo kuruldu
