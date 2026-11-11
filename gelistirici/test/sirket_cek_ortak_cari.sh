#!/bin/bash
# 187 şirket çeki kuralları + 188 ortaklar cari hesabı (yerel PG; tamamı geri alınır)
psql -h /tmp -U postgres -d oyun_test -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | sed 's/^psql:<stdin>:[0-9]*: //' | grep -v "^CONTEXT\|^SAVEPOINT\|^ROLLBACK\|^BEGIN\|^INSERT\|^UPDATE"
begin;
select set_config('t.a', (select id::text from oyun.profiller order by kad limit 1), true), set_config('t.b', (select id::text from oyun.profiller order by kad offset 1 limit 1), true);
insert into oyun.sirketler(id, ad, sektor, kurucu, sermaye, kasa) overriding system value values
  (900001,'Alıcı A.Ş.','tarim',current_setting('t.a')::uuid,100000,1000000),(900002,'Satıcı A.Ş.','tarim',current_setting('t.b')::uuid,100000,500000);
insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values (900001,current_setting('t.a')::uuid,70),(900001,current_setting('t.b')::uuid,30),(900002,current_setting('t.b')::uuid,100);
-- ===== 187 =====
savepoint s; insert into oyun.cekler(duzenleyen,borclu_sirket,ilk_lehtar,hamil,tutar,durum,keside_at) values (current_setting('t.a')::uuid,900001,current_setting('t.b')::uuid,current_setting('t.b')::uuid,5000,'aktif',now()); rollback to s;
savepoint s; insert into oyun.cekler(duzenleyen,borclu_sirket,ilk_lehtar_sirket,hamil_sirket,tutar,durum,keside_at) values (current_setting('t.a')::uuid,900001,900002,900002,5000,'aktif',now()); rollback to s;
insert into oyun.eko_b2b(zaman,gun,alici,satici,kalem,tutar,islendi) values (now(),current_date,900001,900002,'deneme',20000,true);
insert into oyun.cekler(duzenleyen,borclu_sirket,ilk_lehtar_sirket,hamil_sirket,tutar,durum,keside_at) values (current_setting('t.a')::uuid,900001,900002,900002,15000,'aktif',now());
select '✓ ticaret varken 15.000 ₺ şirket çeki kabul';
savepoint s; insert into oyun.cekler(duzenleyen,borclu_sirket,ilk_lehtar_sirket,hamil_sirket,tutar,durum,keside_at) values (current_setting('t.a')::uuid,900001,900002,900002,6000,'aktif',now()); rollback to s;
insert into oyun.cekler(duzenleyen,borclu_sirket,ilk_lehtar_sirket,hamil_sirket,tutar,durum,keside_at,aciklama) values (current_setting('t.a')::uuid,900001,900002,900002,900000,'aktif',now(),'Toptan mal bedeli · 10 x un · sipariş #1');
select '✓ toptan sipariş çeki (ticaretin kendisi) kabul';
savepoint s; insert into oyun.cekler(duzenleyen,borclu_sirket,ilk_lehtar_sirket,hamil_sirket,tutar,durum,keside_at,aciklama) values (current_setting('t.a')::uuid,900001,900002,900002,200000,'aktif',now(),'Toptan mal bedeli · 2 x un · sipariş #2'); rollback to s;
-- ===== 188 =====
select set_config('request.jwt.claim.sub', current_setting('t.b'), true);
savepoint s; select public.ortak_cari_cek(900001, 10000); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select 'durum: ' || (public.ortak_cari_panel(900001) - 'hareketler' - 'ortaklar')::text;
savepoint s; select public.ortak_cari_cek(900001, 99999999); rollback to s;
update oyun.cekler set durum='odendi', odenen=tutar where borclu_sirket=900001;
select 'limit (çekler ödendi): ' || (public.ortak_cari_panel(900001)->>'limit');
select 'çek: ' || public.ortak_cari_cek(900001, 300000)::text;
select 'kasa: ' || kasa from oyun.sirketler where id=900001;
update oyun.ortak_cari set son_faiz = current_date - 3 where sirket_id=900001;
select 'tick: ' || oyun.ortak_cari_tick();
select 'faiz sonrası: ' || row_to_json(c)::text from (select borc, toplam_faiz, son_faiz from oyun.ortak_cari where sirket_id=900001) c;
select 'öde: ' || public.ortak_cari_ode(900001, 100000)::text;
select 'hareketler: ' || string_agg(tur || ' ' || round(tutar), ', ' order by id) from oyun.ortak_cari_hareket where sirket_id=900001;
select 'şirket hareketi: ' || count(*) from oyun.sirket_hareket where sirket_id=900001 and aciklama like 'Ortaklar cari%';
select 'diğer ortağa bildirim: ' || count(*) from oyun.bildirimler where user_id=current_setting('t.b')::uuid and metin like '%ortaklar cari hesabıyla%';
rollback;
SQL
