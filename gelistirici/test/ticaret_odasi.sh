#!/bin/bash
# 196 ticaret odaları + işveren sendikaları (yerel PG; tamamı geri alınır)
cd "$(dirname "$0")/.."
psql -h /tmp -U postgres -d oyun_test -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | sed 's/^psql:[^ ]*:[0-9]*: //' | grep -v "^CONTEXT\|^SAVEPOINT\|^ROLLBACK\|^BEGIN\|^INSERT\|^UPDATE\|^DELETE\|^DO\|^SET\|^CREATE\|^ALTER\|^REVOKE\|^GRANT\|^NOTICE\|^[0-9a-f-]\{36\}$\|^$"
begin;
create table if not exists oyun.eko_isletmeler(sirket_id bigint, tur text, il_id smallint, urun text, olusturma timestamptz);
\i sql/196_ticaret_odasi.sql
select set_config('t.a', (select id::text from oyun.profiller order by kad limit 1), true);
select set_config('t.b', (select id::text from oyun.profiller order by kad offset 1 limit 1), true);
select set_config('t.c', (select id::text from oyun.profiller order by kad offset 2 limit 1), true);
update oyun.profiller set il_id = 6 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid, current_setting('t.c')::uuid);
set local session_replication_role = replica;
insert into oyun.sirketler(id, ad, sektor, kurucu, sermaye, kasa, kurulus, yonetici) overriding system value values
  (900301,'Deneme A1 A.Ş.','ticaret',current_setting('t.a')::uuid,100000,500000, now()-interval '10 days', current_setting('t.a')::uuid),
  (900302,'Deneme A2 A.Ş.','ticaret',current_setting('t.a')::uuid,100000,1000, now()-interval '10 days', current_setting('t.a')::uuid),
  (900303,'Deneme B1 A.Ş.','ticaret',current_setting('t.b')::uuid,100000,500000, now()-interval '10 days', current_setting('t.b')::uuid),
  (900304,'Deneme C1 A.Ş.','ticaret',current_setting('t.c')::uuid,100000,500000, now()-interval '10 days', current_setting('t.c')::uuid),
  (900305,'Deneme C2 A.Ş.','ticaret',current_setting('t.c')::uuid,100000,500000, now()-interval '10 days', current_setting('t.c')::uuid);
insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values (900301,current_setting('t.a')::uuid,100),(900302,current_setting('t.a')::uuid,100),
  (900303,current_setting('t.b')::uuid,100),(900304,current_setting('t.c')::uuid,100),(900305,current_setting('t.c')::uuid,100);
set local session_replication_role = origin;
delete from oyun.oda_uye where sirket_id < 900000;       -- yalnız deneme şirketleriyle sayım
select 'kayıt: ' || oyun.oda_uye_esitle();
delete from oyun.oda_uye where sirket_id < 900000;
select 'il6 üye: ' || oyun.oda_uye_sayisi(6::smallint) || ' · toplam: ' || oyun.oda_uye_sayisi(0::smallint);
select 'tick: ' || oyun.oda_tick();
select 'seçim: ' || string_agg(il_id || ':' || durum, ' ' order by il_id) from oyun.oda_secim;
-- adaylık
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select 'a aday: ' || (public.oda_aday_ol(6, 'Aidatı düşüreceğim, fuar yapacağım.')->'secim'->>'adayim');
savepoint s; select public.oda_aday_ol(0, 'İki odada birden adaylık denemesi'); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.c'), true);
select 'c aday: ' || jsonb_array_length(public.oda_aday_ol(6, 'Üyelere destek fonu dağıtacağım.')->'secim'->'adaylar');
savepoint s; select public.oda_oy_ver(6, (select kad from oyun.profiller where id = current_setting('t.c')::uuid)); rollback to s;
update oyun.oda_secim set oy_bas = now() - interval '1 minute' where il_id = 6;
select 'tick: ' || oyun.oda_tick() || ' · ' || (select durum from oyun.oda_secim where il_id = 6);
-- oylama: a (2 şirket, biri borçlu olacak), b (1), c (2)
update oyun.oda_uye set aidat_borc = 3000 where sirket_id = 900302;
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select 'a oy: ' || (r->>'oy_sayisi') || ' borçlu atlanan ' || (r->>'borclu_atlanan') from (select public.oda_oy_ver(6, (select kad from oyun.profiller where id = current_setting('t.a')::uuid)) r) x;
select 'a borç öde (kasa 1000): ' || public.oda_aidat_ode(900302)::text;
select set_config('request.jwt.claim.sub', current_setting('t.b'), true);
select 'b oy: ' || (public.oda_oy_ver(6, (select kad from oyun.profiller where id = current_setting('t.c')::uuid))->>'oy_sayisi');
savepoint s; select public.oda_oy_ver(6, (select kad from oyun.profiller where id = current_setting('t.a')::uuid), 900304); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.c'), true);
select 'c oy: ' || (public.oda_oy_ver(6, (select kad from oyun.profiller where id = current_setting('t.c')::uuid))->>'oy_sayisi');
update oyun.oda_secim set oy_son = now() - interval '1 minute' where il_id = 6;
select 'tick: ' || oyun.oda_tick();
select 'sonuç: ' || sonuc::text || ' kazanan c mi: ' || (kazanan = current_setting('t.c')::uuid) from oyun.oda_secim where il_id = 6;
select 'ünvan: ' || oyun.unvan(current_setting('t.c')::uuid);
-- aidat (7 gün sonrası)
update oyun.oda_uye set aidat_son = aidat_son - 7 where sirket_id >= 900000;
select 'aidat işlenen: ' || oyun.oda_aidat_isle();
select 'kasalar: il6=' || (select kasa from oyun.oda where il_id = 6) || ' birlik=' || (select kasa from oyun.oda where il_id = 0)
  || ' A1=' || (select kasa from oyun.sirketler where id = 900301) || ' A2 borç=' || (select aidat_borc from oyun.oda_uye where sirket_id = 900302);
-- icraat (başkan c)
savepoint s; select set_config('request.jwt.claim.sub', current_setting('t.a'), true); select public.oda_icraat(6, 'destek', 5000); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.c'), true);
savepoint s; select public.oda_icraat(6, 'destek', 9999999); rollback to s;
update oyun.oda set kasa = kasa + 600000 where il_id = 6;
select 'gelişim önce: ' || round(gelisim, 3) || ' / ' || round(memnuniyet, 3) from oyun.il_durum where il_id = 6;
select 'destek: ' || (public.oda_icraat(6, 'destek', 40000)->'icraatlar'->0->>'baslik');
select 'fuar: ' || (public.oda_icraat(6, 'fuar', 250000)->'icraatlar'->0->>'baslik');
savepoint s; select public.oda_icraat(6, 'fuar', 100000); rollback to s;
select 'eğitim: ' || (public.oda_icraat(6, 'egitim', 100000)->'icraatlar'->0->>'baslik');
select 'aidat ayarı: ' || (public.oda_icraat(6, 'aidat', 5000)->'oda'->>'aidat');
select 'rapor: ' || (public.oda_icraat(6, 'rapor', null, 'İlimizde ticaret canlanıyor; fuar için hazırlıklar tamamlandı.')->'icraatlar'->0->>'tur');
select 'gelişim sonra: ' || round(gelisim, 3) || ' / ' || round(memnuniyet, 3) || ' · oda kasası ' || (select kasa from oyun.oda where il_id = 6) from oyun.il_durum where il_id = 6;
-- sendika (a kurar, b katılır), bildiri, kampanya, erken seçim
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select 'sendika: ' || (r->>'ad') || ' başkanım ' || (r->>'baskanim') || ' konum ' || (r->>'konum') from (select public.sendika_kur(900301, 'Deneme İşverenler Sendikası', 'Küçük işletmelerin sesi') r) x;
select set_config('t.s', (select id::text from oyun.sendika order by id desc limit 1), true);
savepoint s; select public.sendika_kur(900302, 'İkinci sendika', ''); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.b'), true);
select 'b katıldı, üye: ' || jsonb_array_length(public.sendika_katil(current_setting('t.s')::bigint, 900303)->'uyeler');
savepoint s; select public.sendika_islem(current_setting('t.s')::bigint, 'aidat', '{"aidat":2000}'); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select 'sendika aidat: ' || (public.sendika_islem(current_setting('t.s')::bigint, 'aidat', '{"aidat":2000}')->>'aidat');
select 'bildiri: ' || (public.sendika_islem(current_setting('t.s')::bigint, 'bildiri', '{"il":6,"baslik":"Oda yönetimi şeffaf değil","metin":"Fuar harcamalarının dökümü üyelere açıklanmalıdır."}')->'bildiriler'->0->>'baslik');
select 'panelde bildiri konumu: ' || (public.oda_panel(6)->'bildiriler'->0->>'konum');
update oyun.sendika_uye set aidat_son = aidat_son - 7;
select 'sendika aidat işlendi: ' || oyun.oda_aidat_isle() || ' kasa ' || (select kasa from oyun.sendika where id = current_setting('t.s')::bigint);
savepoint s; select public.sendika_islem(current_setting('t.s')::bigint, 'kampanya', '{"il":6,"baslik":"Erken seçim","metin":"Üyeleri erken seçim için imzaya çağırıyoruz.","tutar":25000}'); rollback to s;
savepoint s; select public.oda_erken_secim_imza(6); rollback to s;
update oyun.oda set baskan_bas = now() - interval '6 days' where il_id = 6;
select 'a imza: ' || (r->>'imzalanan') || ' açıldı ' || (r->>'secim_acildi') from (select public.oda_erken_secim_imza(6) r) x;
select set_config('request.jwt.claim.sub', current_setting('t.b'), true);
select 'b imza: ' || (r->>'imzalanan') || ' açıldı ' || (r->>'secim_acildi') || ' seçim ' || (r->'secim'->>'durum') from (select public.oda_erken_secim_imza(6) r) x;
-- şirket kapanınca üyelik ve başkanlık düşer
update oyun.sirketler set aktif = false where id in (900304, 900305);
select 'tick: ' || oyun.oda_tick();
select 'başkan boş mu: ' || (select baskan is null from oyun.oda where il_id = 6) || ' · üye ' || oyun.oda_uye_sayisi(6::smallint) || ' · ünvan: ' || coalesce(oyun.unvan(current_setting('t.c')::uuid), '-');
rollback;
SQL
