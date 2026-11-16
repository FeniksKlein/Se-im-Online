#!/bin/bash
# GBY yetki + il kongresi: yerel Postgres'te taklit tablolarla senaryo testi (canlı veritabanına dokunmaz).
set -e; cd "$(dirname "$0")/.."
psql -h /tmp -U postgres -q -c "drop database if exists gby_test" -c "create database gby_test"
PGOPTIONS='-c check_function_bodies=off' psql -h /tmp -U postgres -d gby_test -q -v ON_ERROR_STOP=1 -f test/veri/gby_taklit.sql -f test/veri/gby_taklit2.sql -f sql/zz_20261116_gby_yetki_sistemi.sql -f sql/zz_20261116_il_kongre_sistemi.sql
psql -h /tmp -U postgres -d gby_test -At -f test/gby_il_kongre_yerel_test.sql
