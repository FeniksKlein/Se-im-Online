#!/bin/bash
# 191 ödeme gücüne göre şahsi kredi + şirket işletme kredisi (yerel PG; tamamı geri alınır)
psql -h /tmp -U postgres -d oyun_test -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | sed 's/^psql:<stdin>:[0-9]*: //' | grep -v "^CONTEXT\|^SAVEPOINT\|^ROLLBACK\|^BEGIN\|^INSERT\|^UPDATE\|^DO\|^[0-9a-f-]\{36\}"
begin;
-- yerel test veritabanı kısmi: eksik ekonomi tabloları için boş saplamalar (geri alınır)
create table if not exists oyun.eko_urun_stok(sirket_id bigint, urun text, adet integer, maliyet_birim numeric, satis_fiyati numeric, guncelleme timestamptz);
create table if not exists oyun.eko_arsalar(id bigint, il_id smallint, kademe smallint, alan_m2 integer, fiyat numeric, durum text, sahibi_sirket bigint, alis_zamani timestamptz, olusturma timestamptz);
create table if not exists oyun.eko_yapilar(id bigint, arsa_id bigint, sirket_id bigint, il_id smallint, ad text, daire_sayisi integer, dukkan_sayisi integer, maliyet numeric, baslangic timestamptz, bitis timestamptz);
create table if not exists oyun.eko_isletmeler(sirket_id bigint, tur text, il_id smallint, urun text);
\i sql/191_kredi_odeme_gucu.sql
\i sql/192_kredi_kalibrasyon.sql
\i sql/199_sirket_kredi_kapasite_duzeltme.sql
select set_config('t.a', (select id::text from oyun.profiller order by kad limit 1), true);
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
-- yerel test veritabanında banka_json yok: banka() yerine bütçe doğrudan, kredi_cek dönüşü için saplama
create or replace function public.banka() returns jsonb language sql as $$ select '{}'::jsonb $$;
-- ===== kişi =====
select 'bütçe: ' || string_agg(g || '=' || (oyun.devlet_kredi_limit(current_setting('t.a')::uuid, g)->>'azami_kredi'), ' ') from unnest(array[7,14,28,60,90,180,365]) g;
select 'eski statü tavanı yerine limit: ' || oyun.kredi_limiti(current_setting('t.a')::uuid);
select 'detay365: ' || (oyun.devlet_kredi_limit(current_setting('t.a')::uuid, 365) - 'teminat')::text;
savepoint s; select public.kredi_cek(1000, 45); rollback to s;
savepoint s; select public.kredi_cek(999999999, 365); rollback to s;
select set_config('t.l', (oyun.devlet_kredi_limit(current_setting('t.a')::uuid, 365)->>'azami_kredi'), true);
select set_config('t.c0', (select para::text from oyun.cuzdan where user_id = current_setting('t.a')::uuid), true);
select 'çek365: ' || (public.kredi_cek(current_setting('t.l')::numeric, 365) is not null);
select 'kredi: ' || row_to_json(k)::text from (select anapara, gun, toplam, taksit, durum from oyun.krediler where user_id = current_setting('t.a')::uuid and durum = 'aktif') k;
select 'cüzdan artışı: ' || ((select para from oyun.cuzdan where user_id = current_setting('t.a')::uuid) - current_setting('t.c0')::numeric);
savepoint s; select public.kredi_cek(1000, 7); rollback to s;
select 'kredi sonrası teminat: ' || (oyun.kredi_teminat(current_setting('t.a')::uuid))::text;
-- ===== şirket ===== (kuruluş statü tetikleyicisi yalnız bu deneme kaydı için devre dışı)
set local session_replication_role = replica;
insert into oyun.sirketler(id, ad, sektor, kurucu, sermaye, kasa, kurulus, yonetici) overriding system value values
  (900201,'Deneme Lojistik A.Ş.','tarim',current_setting('t.a')::uuid,200000,900000, now()-interval '10 days', current_setting('t.a')::uuid);
insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values (900201,current_setting('t.a')::uuid,100);
insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir) values (900201, now()-interval '2 days', 800000, 'Günlük faaliyet deneme', 800000);
set local session_replication_role = origin;
select 'defter0: ' || oyun.sirket_defter(900201);
select 'kapasite: ' || (public.yatirim_kredisi_panel(900201)->'isletme_kapasite')::text;
savepoint s; select public.sirket_kredi_al(900201, 999999999, 365); rollback to s;
select set_config('t.k', (public.yatirim_kredisi_panel(900201)->'isletme_kapasite'->>'180'), true);
select 'işletme: ' || public.sirket_kredi_al(900201, current_setting('t.k')::numeric, 180)::text;
select 'kasa: ' || kasa || ' defter: ' || oyun.sirket_defter(900201) from oyun.sirketler where id = 900201;
select 'cari limit: ' || (public.ortak_cari_panel(900201)->>'limit') || ' / ' || coalesce(public.ortak_cari_panel(900201)->>'neden','');
savepoint s; select public.sirket_kar_payi(900201, 1000000); rollback to s;
select 'kapasite sonra: ' || (public.yatirim_kredisi_panel(900201)->'isletme_kapasite')::text;
update oyun.yatirim_kredisi set son_tahsil = son_tahsil - 1 where sirket_id = 900201;
select 'tick: ' || oyun.yatirim_kredisi_tick();
select 'kredi: ' || row_to_json(k)::text from (select amac, anapara, vade_gun, taksit, kalan, durum from oyun.yatirim_kredisi where sirket_id = 900201) k;
-- tasfiye edilmiş şirket: kredi kapanır
update oyun.sirketler set aktif = false, kasa = 0 where id = 900201;
update oyun.yatirim_kredisi set son_tahsil = son_tahsil - 1 where sirket_id = 900201;
select 'tick2: ' || oyun.yatirim_kredisi_tick();
select 'kapandı: ' || durum from oyun.yatirim_kredisi where sirket_id = 900201;
rollback;
SQL
