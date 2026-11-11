#!/bin/bash
# 187 · şirket çeki kişiye yazılamaz / kişiye ciro edilemez (yerel PG, her şey geri alınır)
psql -h /tmp -U postgres -d oyun_test -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | sed 's/^psql:<stdin>:[0-9]*: //'
begin;
select set_config('t.a', (select id::text from oyun.profiller order by kad limit 1), true), set_config('t.b', (select id::text from oyun.profiller order by kad offset 1 limit 1), true);
insert into oyun.sirketler(id, ad, sektor, kurucu, sermaye) overriding system value values (900001,'Deneme A.Ş.','tarim',current_setting('t.a')::uuid,1000),(900002,'Karşı A.Ş.','tarim',current_setting('t.b')::uuid,1000);
savepoint s;
-- 1) şirket → kişi: RED
insert into oyun.cekler(id, duzenleyen, borclu_sirket, ilk_lehtar, hamil, tutar, durum, keside_at) overriding system value values (990001, current_setting('t.a')::uuid, 900001, current_setting('t.b')::uuid, current_setting('t.b')::uuid, 5000, 'aktif', now());
rollback to s;
-- 2) şirket → şirket: KABUL
insert into oyun.cekler(id, duzenleyen, borclu_sirket, ilk_lehtar_sirket, hamil_sirket, tutar, durum, keside_at) overriding system value values (990002, current_setting('t.a')::uuid, 900001, 900002, 900002, 5000, 'aktif', now());
select '✓ şirket→şirket kabul';
savepoint s2;
-- 3) şirket çeki kişiye ciro: RED
update oyun.cekler set hamil = current_setting('t.b')::uuid, hamil_sirket = null where id = 990002;
rollback to s2;
-- 4) şirket çeki başka şirkete ciro / bankaya iskonto: KABUL
update oyun.cekler set hamil = null, hamil_sirket = 900001 where id = 990002;
select '✓ şirket çeki şirkete ciro kabul';
-- 5) kişisel çek kişiye: KABUL
insert into oyun.cekler(id, duzenleyen, ilk_lehtar, hamil, tutar, durum, keside_at) overriding system value values (990003, current_setting('t.a')::uuid, current_setting('t.b')::uuid, current_setting('t.b')::uuid, 5000, 'aktif', now());
select '✓ kişisel çek kabul';
rollback;
SQL
