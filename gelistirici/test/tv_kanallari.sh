#!/bin/bash
# 198 TV kanalları: kanal, sunucu, program, canlı yazışma, izleyici, reklam (yerel PG; tamamı geri alınır)
cd "$(dirname "$0")/.."
psql -h /tmp -U postgres -d oyun_test -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | sed 's/^psql:[^ ]*:[0-9]*: //' | grep -v "^CONTEXT\|^SAVEPOINT\|^ROLLBACK\|^BEGIN\|^INSERT\|^UPDATE\|^DELETE\|^DO\|^SET\|^CREATE\|^ALTER\|^REVOKE\|^GRANT\|^NOTICE\|^DROP\|^SQL statement\|^PL/pgSQL\|^[0-9a-f-]\{36\}$\|^$"
begin;
\i sql/198_tv_kanallari.sql
-- sahip (s), sunucu (u), konuklar (k1,k2), izleyiciler (i1,i2,i3), reklamveren (r)
create temp table tk as select id, kad, row_number() over (order by kad) n from (select id, kad from oyun.profiller where not yasakli and olusturma < now() - interval '8 days' order by kad limit 8) x;
update oyun.cuzdan set para = para + 2000000 where user_id in (select id from tk);
create or replace function pg_temp.ben(i int) returns text language sql as $$ select set_config('request.jwt.claim.sub', (select id::text from tk where n = i), true) $$;
create or replace function pg_temp.kad(i int) returns text language sql as $$ select kad from tk where n = i $$;
create or replace function pg_temp.para(i int) returns numeric language sql as $$ select para from oyun.cuzdan where user_id = (select id from tk where n = i) $$;
select pg_temp.ben(1);
select set_config('t.p0', pg_temp.para(1)::text, true);
select set_config('t.k', (public.tv_kanal_kur('Deneme TV', 'Gerçeğin ekranı')->>'id'), true);
select 'kanal: ' || current_setting('t.k') is not null || ' · lisans ' || (current_setting('t.p0')::numeric - pg_temp.para(1));
savepoint s; select public.tv_kanal_kur('İkinci TV'); rollback to s;
select 'kasa yatır: ' || (public.tv_kasa(current_setting('t.k')::bigint, 'yatir', 30000)->>'kasa');
select 'ayar: ' || (public.tv_kanal_ayar(current_setting('t.k')::bigint, null, 500)->>'izleyici_ucret');
-- sunucu teklifi ve kabul
select 'teklif: ' || jsonb_array_length(public.tv_sunucu_teklif(current_setting('t.k')::bigint, pg_temp.kad(2), 10000)->'sunucular');
select pg_temp.ben(2);
savepoint s; select public.tv_program_ac(current_setting('t.k')::bigint, 'duello', 'Yetkisiz program'); rollback to s;
select 'sunucu teklifi görünüyor: ' || jsonb_array_length(public.tv_liste()->'sunucu_teklif');
select 'kabul: ' || (public.tv_sunucu_yanit(current_setting('t.k')::bigint, true)->>'yayinciyim');
-- sunucu cuma 19:00–19:30 düello planlar (burada: 2 saat sonrası, 30 dk)
select set_config('t.pr', (public.tv_program_ac(current_setting('t.k')::bigint, 'duello', 'Ekonomi düellosu', 'Asgari ücret tartışması', now() + interval '2 hours', 30)->>'id'), true);
select 'program: ' || (d->>'durum') || ' rol ' || (d->>'rolum') || ' süre dk ' || round(extract(epoch from ((d->>'bit')::timestamptz - (d->>'bas')::timestamptz)) / 60) from (select public.tv_detay(current_setting('t.pr')::bigint) d) x;
savepoint s; select public.tv_program_ac(current_setting('t.k')::bigint, 'haber', 'Çakışan program', null, now() + interval '2 hours 10 minutes', 20); rollback to s;
select 'davet k1: ' || jsonb_array_length(public.tv_konuk_davet(current_setting('t.pr')::bigint, pg_temp.kad(3))->'konuk_liste');
select 'davet k2: ' || jsonb_array_length(public.tv_konuk_davet(current_setting('t.pr')::bigint, pg_temp.kad(4))->'konuk_liste');
select pg_temp.ben(3); select 'k1 davetleri: ' || jsonb_array_length(public.tv_liste()->'davetlerim') || ' → ' || (public.tv_konuk_yanit(current_setting('t.pr')::bigint, true)->>'rolum');
select pg_temp.ben(4); select 'k2 → ' || (public.tv_konuk_yanit(current_setting('t.pr')::bigint, true)->>'rolum');
savepoint s; select public.tv_yaz(current_setting('t.pr')::bigint, 'Erken söz'); rollback to s;
-- reklamlar: r (8) cüzdandan 20.000 ₺; sahip kendi kanalına veremez; i3 (7) onaylanmayacak reklam verir
select pg_temp.ben(1); savepoint s; select public.tv_reklam_ver(current_setting('t.pr')::bigint, 'Kendi markam', 'Kendi kanalıma reklam', 10000); rollback to s;
select pg_temp.ben(8); select set_config('t.r0', pg_temp.para(8)::text, true);
select 'reklam verildi: ' || (public.tv_reklam_ver(current_setting('t.pr')::bigint, 'Anadolu Kahve', 'Güne taze kahveyle başla', 20000)->'reklamlarim'->0->>'durum');
select pg_temp.ben(7); select 'reklam 2: ' || (public.tv_reklam_ver(current_setting('t.pr')::bigint, 'Bekleyen Marka', 'Onaylanmayacak reklam', 10000)->'reklamlarim'->0->>'durum');
select pg_temp.ben(1); select 'bekleyen: ' || jsonb_array_length(public.tv_kanal_detay(current_setting('t.k')::bigint)->'bekleyen_reklam');
select 'onay: ' || jsonb_array_length(public.tv_reklam_karar((select id from oyun.tv_reklam where marka = 'Anadolu Kahve'), true)->'bekleyen_reklam');
-- yayın saati geldi
update oyun.tv_program set bas = now() - interval '1 minute', bit = now() + interval '29 minutes' where id = current_setting('t.pr')::bigint;
select pg_temp.ben(2); select 'canlı: ' || (d->>'durum') || ' · reklam mesajı: ' || (d->'mesajlar'->0->>'rol') from (select public.tv_detay(current_setting('t.pr')::bigint) d) x;
select 'sunucu yazdı: ' || (public.tv_yaz(current_setting('t.pr')::bigint, 'İyi akşamlar, düellomuz başlıyor.')->>'tamam');
select pg_temp.ben(3); select 'k1 yazdı: ' || (public.tv_yaz(current_setting('t.pr')::bigint, 'Asgari ücret enflasyonun üzerinde artmalı.')->>'tamam');
select pg_temp.ben(4); select 'k2 yazdı: ' || (public.tv_yaz(current_setting('t.pr')::bigint, 'Kaynağı gösterilmeyen artış enflasyonu büyütür.')->>'tamam');
-- izleyiciler (5,6,7) + reklamveren (8) izler; izleyici yazamaz, alkışlar, oy verir
select pg_temp.ben(5); select 'i1 rol: ' || (d->>'rolum') || ' anlık ' || (d->'izleyiciler'->>'anlik') from (select public.tv_detay(current_setting('t.pr')::bigint) d) x;
savepoint s; select public.tv_yaz(current_setting('t.pr')::bigint, 'İzleyici yazamaz'); rollback to s;
select 'alkış: ' || (public.tv_tepki(current_setting('t.pr')::bigint, 'alkis')->>'alkis') || ' oy: ' || (public.tv_oyla(current_setting('t.pr')::bigint, pg_temp.kad(3))->>'oyum');
select pg_temp.ben(6); select 'i2 oy: ' || (public.tv_oyla(current_setting('t.pr')::bigint, pg_temp.kad(3))->>'oyum');
select pg_temp.ben(7); select 'i3 oy: ' || (public.tv_oyla(current_setting('t.pr')::bigint, pg_temp.kad(4))->>'oyum');
select pg_temp.ben(8); select 'r izliyor, izleyiciler: ' || (public.tv_detay(current_setting('t.pr')::bigint)->'izleyiciler')::text;
select pg_temp.ben(3); savepoint s; select public.tv_oyla(current_setting('t.pr')::bigint, pg_temp.kad(3)); rollback to s;
select 'listede canlı: ' || jsonb_array_length(public.tv_liste()->'canli') || ' izleyici ' || (public.tv_liste()->'canli'->0->>'izleyici');
-- sunucu yayını bitirir → reklam hesabı: 3 izleyici (reklamveren hariç) × 500 = 1.500; vergi %10
select pg_temp.ben(5); savepoint s; select public.tv_bitir(current_setting('t.pr')::bigint); rollback to s;
select pg_temp.ben(2); select 'bitti: ' || (public.tv_bitir(current_setting('t.pr')::bigint)->>'durum');
select 'reklamlar: ' || string_agg(marka || ' ' || durum || ' ödenen ' || odenen || ' vergi ' || vergi || ' iade ' || iade, ' | ' order by id) from oyun.tv_reklam;
select 'reklamveren net: ' || (current_setting('t.r0')::numeric - pg_temp.para(8)) || ' · kanal kasası ' || (select kasa from oyun.tv_kanal where id = current_setting('t.k')::bigint);
savepoint s; select public.tv_yaz(current_setting('t.pr')::bigint, 'Bitti sonrası'); rollback to s;
-- düello sonucu (15 dk sonra) ve sunucu ücreti (ertesi gün)
update oyun.tv_program set gercek_bit = now() - interval '16 minutes' where id = current_setting('t.pr')::bigint;
update oyun.tv_sunucu set son_odeme = son_odeme - 1;
select set_config('t.u0', pg_temp.para(2)::text, true);
select 'tick: ' || oyun.tv_tick();
select 'sunucu ücreti: ' || (pg_temp.para(2) - current_setting('t.u0')::numeric) || ' · kasa ' || (select kasa from oyun.tv_kanal where id = current_setting('t.k')::bigint)
  || ' · sonuç yazıldı ' || (select sonuc_yazildi from oyun.tv_program where id = current_setting('t.pr')::bigint);
select 'olay: ' || metin from oyun.olaylar where metin like '%düellosunu%' order by id desc limit 1;
-- kasa yetmeyince sözleşme biter
update oyun.tv_sunucu set son_odeme = son_odeme - 3;
select 'tick: ' || oyun.tv_tick();
select 'sözleşme: ' || durum || ' toplam ' || toplam from oyun.tv_sunucu;
-- sahip açık uçlu program açar, hemen canlı; şirket reklamı kuralı; iptal iadesi; kasadan çekme
select pg_temp.ben(1);
select set_config('t.pr2', (public.tv_program_ac(current_setting('t.k')::bigint, 'soylesi', 'Gece söyleşisi')->>'id'), true);
select 'açık uçlu: ' || (d->>'durum') || ' ' || (d->>'acik_uclu') || ' rol ' || (d->>'rolum') from (select public.tv_detay(current_setting('t.pr2')::bigint) d) x;
select set_config('t.pr3', (public.tv_program_ac(current_setting('t.k')::bigint, 'haber', 'Yarın haberleri', null, now() + interval '20 hours', 20)->>'id'), true);
select pg_temp.ben(8); select set_config('t.r1', pg_temp.para(8)::text, true);
select 'planlı programa reklam: ' || (public.tv_reklam_ver(current_setting('t.pr3')::bigint, 'Anadolu Kahve', 'Yarın da buradayız', 15000)->'reklamlarim'->0->>'durum');
select pg_temp.ben(1); select 'program iptal: ' || (public.tv_bitir(current_setting('t.pr3')::bigint)->>'durum') || ' · iade ' || (select durum || ' ' || iade from oyun.tv_reklam where program_id = current_setting('t.pr3')::bigint);
select 'reklamveren bakiyesi değişmedi: ' || (pg_temp.para(8) = current_setting('t.r1')::numeric);
select 'yatır+çek: ' || (public.tv_kasa(current_setting('t.k')::bigint, 'yatir', 5000)->>'kasa') || ' → ' || (public.tv_kasa(current_setting('t.k')::bigint, 'cek', 1000)->>'kasa');
savepoint s; select public.tv_kasa(current_setting('t.k')::bigint, 'cek', 99999999); rollback to s;
-- reklam kaynağı: cüzdan + kanal sahibiyle bağı olmayan şirketlerim; kanal sahibinin şirketi listelenmez, reklam veremez
set local session_replication_role = replica;
insert into oyun.sirketler(id, ad, sektor, kurucu, sermaye, kasa, kurulus, yonetici) overriding system value values
  (900301,'Reklamveren A.Ş.','tarim',(select id from tk where n = 8),100000,400000, now()-interval '10 days', (select id from tk where n = 8)),
  (900302,'Sahibin Ortak Şirketi','tarim',(select id from tk where n = 8),100000,400000, now()-interval '10 days', (select id from tk where n = 8));
insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values (900301,(select id from tk where n = 8),100),
  (900302,(select id from tk where n = 8),60),(900302,(select id from tk where n = 1),40);
set local session_replication_role = origin;
select pg_temp.ben(8);
select 'kaynak şirketler: ' || (select string_agg(x->>'ad', ',') from jsonb_array_elements(public.tv_reklam_kaynak(current_setting('t.pr2')::bigint)->'sirketler') x);
savepoint s; select public.tv_reklam_ver(current_setting('t.pr2')::bigint, 'Ortak Marka', 'Sahibin şirketi reklamı', 20000, 900302); rollback to s;
select 'şirket reklamı: ' || (public.tv_reklam_ver(current_setting('t.pr2')::bigint, 'Reklamveren', 'Şirket kasasından reklam', 20000, 900301)->'reklamlarim'->0->>'sirket');
select 'bütçe ayrıldı, kasa: ' || kasa from oyun.sirketler where id = 900301;
select 'şirket iptal iadesi: ' || (public.tv_reklam_iptal((select id from oyun.tv_reklam where sirket_id = 900301))->'reklamlarim'->0->>'durum');
select 'iade sonrası kasa: ' || kasa from oyun.sirketler where id = 900301;
rollback;
SQL
