-- Yerel derleme testi. Canlı veritabanında çalıştırılmaz.
-- psql -d sert_test -v ON_ERROR_STOP=1 -f gelistirici/test/halk_sert_derle.sql
do $$ begin
 if current_database()<>'sert_test' then raise exception 'Bu dosya yalnız sert_test veritabanında çalışır'; end if;
end $$;
create schema if not exists oyun;
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;

create table if not exists oyun.profiller(id uuid primary key, kad text, yasakli boolean default false, susturma_bitis timestamptz);
create table if not exists oyun.partiler(id bigint generated always as identity primary key, kasa numeric default 0, kapali boolean default false);
create table if not exists oyun.sokak_eylem(
 id bigint generated always as identity primary key, il_id integer, parti_id bigint, baslatan uuid,
 gerekce text, durum text, baslangic timestamptz, bitis timestamptz, kapandi timestamptz,
 kirmizi_baslangic timestamptz, seviye numeric default 0, muhalefet_fonu numeric default 0);
create table if not exists oyun.sokak_eylem_destek(
 eylem_id bigint, destekci_tur text, destekci_id text, taraf text, temsilci uuid, destek_turu text, tutar numeric);
create table if not exists oyun.sokak_eylem_ayar(id integer primary key, baslatma_bedeli numeric, aktif boolean default true);
insert into oyun.sokak_eylem_ayar values(1,50000,true) on conflict do nothing;
create table if not exists oyun.sokak_taktik(eylem_id bigint, user_id uuid, tur text, bitis timestamptz);
create table if not exists oyun.sokak_gorevli(eylem_id bigint, ayrilma timestamptz);
create table if not exists oyun.makamlar(user_id uuid, tur text, bakanlik text, bit timestamptz);
create table if not exists oyun.icisleri_atama(hedef uuid, tur text, il_id integer, durum text, bitis timestamptz);
create table if not exists oyun.ulke(id integer primary key, memnuniyet numeric);
insert into oyun.ulke values(1,50) on conflict do nothing;
create table if not exists oyun.il_durum(il_id integer primary key, memnuniyet numeric);
insert into oyun.il_durum values(6,50) on conflict do nothing;
create table if not exists oyun.sokak_kriz(id integer primary key, kirmizi_baslangic timestamptz, ivme_saat integer default 0);
insert into oyun.sokak_kriz values(1,null,0) on conflict do nothing;
create table if not exists oyun.sokak_soz(eylem_id bigint, durum text);
create table if not exists oyun.avukat_ruhsat(user_id uuid, durum text);
create table if not exists oyun.mahkeme_uye(user_id uuid);
create table if not exists oyun.sirketler(id bigint primary key, aktif boolean);
create table if not exists oyun.sirket_deneyim(sirket_id bigint primary key, is_sayisi int default 0, puan int default 0, yasak_bit timestamptz);
create table if not exists oyun.sokak_sicil(id bigint generated always as identity primary key, user_id uuid, eylem_id bigint, tur text, ozet text, zaman timestamptz);
create table if not exists oyun.sokak_meydan_etki(id bigint generated always as identity primary key, eylem_id bigint, tur text, puan numeric, bitis timestamptz);
create table if not exists oyun.sokak_itibar(user_id uuid primary key, puan integer default 0);
create table if not exists oyun.sokak_denetim(id bigint generated always as identity, eylem_id bigint, user_id uuid, tur text, hedef uuid, metin text, zaman timestamptz);
create table if not exists oyun.parti_hareket(parti_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text);

create or replace function oyun.simdi() returns timestamptz language sql stable as $$
 select coalesce(nullif(current_setting('oyun.simdi', true), '')::timestamptz, now()) $$;
create or replace function oyun.kufurlu(m text) returns boolean language sql immutable as $$ select false $$;
create or replace function oyun.sokak_temiz(m text, n int) returns text language plpgsql as $$
begin m:=btrim(coalesce(m,'')); if char_length(m)<1 or char_length(m)>n then raise exception 'Metin'; end if; return m; end $$;
create or replace function oyun.pazar_tl_milyar() returns numeric language sql as $$ select 150000::numeric $$;
create or replace function oyun.bm_kasa_harca(p_kod text, p_tutar numeric, p_tur text, p_aciklama text) returns numeric language plpgsql as $$
begin return p_tutar; end $$;
create or replace function oyun.sokak_yonetebilir(u uuid) returns boolean language sql stable as $$
 select exists(select 1 from oyun.makamlar where user_id=u and bit is null and (tur='cb' or tur='bakan' and bakanlik='icisleri')) $$;
create or replace function oyun.sokak_iktidar(u uuid) returns boolean language sql as $$ select false $$;
create or replace function oyun.sokak_gazeteci(u uuid) returns boolean language sql as $$ select false $$;
create or replace function oyun.sokak_katilimci(e bigint, u uuid) returns boolean language sql as $$
 select exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=e and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and d.temsilci=u) $$;
create or replace function oyun.sokak_kad_bul(k text) returns uuid language sql as $$
 select id from oyun.profiller where lower(kad)=lower(btrim(coalesce(k,''))) limit 1 $$;
create or replace function oyun.kad(u uuid) returns text language sql as $$ select kad from oyun.profiller where id=u $$;
create or replace function oyun.sirket_sahibi(p_sirket bigint) returns uuid language sql as $$ select null::uuid $$;
create or replace function oyun.salt_cogunluk() returns int language sql as $$ select 1 $$;
create or replace function oyun.bildir(p_user uuid, p_metin text, p_zaman timestamptz default null) returns void language sql as $$ select null $$;
create or replace function oyun.sokak_duyur(p_id bigint, p_metin text) returns void language sql as $$ select null $$;
create or replace function oyun.sokak_yenile(p_id bigint) returns void language sql as $$ select null $$;
create or replace function oyun.sokak_kriz_kontrol() returns void language sql as $$ select null $$;
create or replace function oyun.sokak_log(e bigint, u uuid, tur text, hedef uuid, metin text) returns void language sql as $$ select null $$;
create or replace function oyun.sokak_sicil_yaz(u uuid, e bigint, tur text, ozet text) returns void language sql as $$
 insert into oyun.sokak_sicil(user_id,eylem_id,tur,ozet,zaman) values(u,e,tur,left(ozet,200),oyun.simdi()) $$;
create or replace function oyun.sokak_manset_yaz(m text) returns void language sql as $$ select null $$;
create or replace function oyun.sokak_gece_kapali(e bigint) returns boolean language sql as $$ select false $$;

create or replace function public.sokak_destek(p_eylem bigint, p_taraf text, p_kaynak text, p_kaynak_id bigint, p_tutar numeric) returns jsonb language plpgsql as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
begin
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if oyun.sokak_gece_kapali(x.id) then raise exception 'Gece toplanma kısıtı: 22.00–06.00 arasında yeni katılım kapalı'; end if;
 if p_tutar<1000 then raise exception 'En az 1.000 TL fonlanabilir'; end if;
 update oyun.partiler set kasa=kasa-p_tutar where id=p_kaynak_id and kasa>=p_tutar;
 if p_kaynak='oyuncu' then null;
 elsif p_kaynak='parti' then insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(p_kaynak_id,t,-p_tutar,'gider','Halk hareketi #'||x.id||' / '||p_taraf);
 end if;
 return '{}'::jsonb;
end $$;
create or replace function public.sokak_sohbet_yaz(p_eylem bigint, p_metin text) returns jsonb language plpgsql as $$
declare u uuid:=auth.uid();
begin
 if false then raise exception 'Gözaltındayken eylem sohbetine yazamazsın'; end if;
 return '{}'::jsonb;
end $$;
create or replace function public.sokak_taktik_yap(p_eylem bigint, p_tur text, p_metin text) returns jsonb language plpgsql as $$
declare u uuid; x oyun.sokak_eylem;
begin
 if oyun.sokak_gece_kapali(x.id) then raise exception 'Gece toplanma kısıtı: 22.00–06.00 arasında taktik uygulanamaz'; end if;
 return '{}'::jsonb;
end $$;
create or replace function public.sokak_meydan_islem(p_eylem bigint, p_islem text, p_veri jsonb) returns jsonb language plpgsql as $$
declare u uuid; me oyun.profiller;
begin
 select * into me from oyun.profiller where id=u;
 if me.yasakli then raise exception 'Hesabın kısıtlı'; end if;
 return '{}'::jsonb;
end $$;
create or replace function public.sokak_meydan_panel() returns jsonb language plpgsql as $$
declare u uuid;
begin
 return jsonb_build_object('pusula',(select jsonb_build_object('sahada',count(*) filter(where tur='sahada'),'yasak',count(*) filter(where tur='yasak'),'anlasma',count(*) filter(where tur='anlasma'),'saf',count(*) filter(where tur='saf'),'muhbir',count(*) filter(where tur='muhbir')) from oyun.sokak_sicil where user_id=u));
end $$;
create or replace function public.sokak_eylem_baslat(p_il integer, p_gerekce text) returns jsonb language plpgsql as $$
begin
 if true then raise exception 'Sokak hareketleri kapalı'; end if;
 return '{}'::jsonb;
end $$;
create or replace function oyun.sokak_meydan_tick() returns void language sql as $$ select null $$;
create or replace function oyun.sokak_tick() returns void language plpgsql as $$
begin perform oyun.sokak_meydan_tick(); end $$;
create or replace function oyun.sokak_tedbir_ad(k text) returns text language sql as $$ select k $$;
create or replace function public.sokak_tedbir_ac(p_eylem bigint, p_tur text, p_gerekce text) returns jsonb language plpgsql as $$
declare tut numeric:=100; x oyun.sokak_eylem;
begin
 select * into x from oyun.sokak_eylem where id=p_eylem;
 perform oyun.bm_kasa_harca('icisleri',tut/oyun.pazar_tl_milyar(),'gider','Halk hareketi #'||x.id||' / '||oyun.sokak_tedbir_ad(p_tur)||' / '||tut||' TL');
 return jsonb_build_object('bedel',tut);
end $$;
create or replace function public.sokak_hukumet_karar(p_eylem bigint, p_tur text, p_gerekce text, p_hedef uuid) returns jsonb language plpgsql as $$
declare tut numeric:=100; x oyun.sokak_eylem;
begin
 select * into x from oyun.sokak_eylem where id=p_eylem;
 perform oyun.bm_kasa_harca('icisleri',tut/oyun.pazar_tl_milyar(),'gider','Halk hareketi #'||x.id||' / '||p_tur||' / '||tut||' TL');
 return jsonb_build_object('bedel',tut);
end $$;

\i supabase/migrations/20261109210000_halk_sert_onlem.sql

do $$
declare cb uuid:='00000000-0000-0000-0000-000000000001'; vali uuid:='00000000-0000-0000-0000-000000000002';
 lider uuid:='00000000-0000-0000-0000-000000000010'; a uuid:='00000000-0000-0000-0000-000000000011';
 b uuid:='00000000-0000-0000-0000-000000000012'; c uuid:='00000000-0000-0000-0000-000000000013';
 av uuid:='00000000-0000-0000-0000-000000000020'; hakim uuid:='00000000-0000-0000-0000-000000000021';
 mv uuid:='00000000-0000-0000-0000-000000000022'; yaban uuid:='00000000-0000-0000-0000-000000000030';
 pid bigint; e bigint; v jsonb; n int;
begin
 insert into oyun.profiller(id,kad) values
  (cb,'baskan'),(vali,'vali'),(lider,'lider'),(a,'ayse'),(b,'berk'),(c,'cem'),(av,'avukat'),(hakim,'hakim'),(mv,'vekil'),(yaban,'yaban');
 insert into oyun.makamlar(user_id,tur) values(cb,'cb'),(mv,'mv');
 insert into oyun.icisleri_atama(hedef,tur,il_id,durum) values(vali,'vali',6,'aktif');
 insert into oyun.avukat_ruhsat values(av,'aktif');
 insert into oyun.mahkeme_uye values(hakim);
 insert into oyun.partiler(kasa) values(1000000) returning id into pid;
 update oyun.partiler set kasa=1000000 where id=pid;

 perform set_config('oyun.simdi','2026-11-09 10:00:00+00',false);
 perform set_config('request.jwt.claim.sub',cb::text,false);
 insert into oyun.sokak_eylem(il_id,parti_id,baslatan,gerekce,durum,baslangic,bitis) values(6,pid,lider,'Test eylemi', 'aktif', oyun.simdi(), oyun.simdi()+interval '2 days') returning id into e;
 begin
  perform public.sokak_sert_islem(e,'ac','{"tur":"safak","gerekce":"Bu saat şafak penceresinin dışında kalıyor"}'::jsonb);
  raise exception 'TEST saat';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%04.00–06.00%' then raise; end if; end;

 perform set_config('oyun.simdi','2026-11-09 02:30:00+00',false);
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destek_turu,taraf,temsilci) values
  (e,'oyuncu','katilim','muhalefet',lider),(e,'oyuncu','katilim','muhalefet',a),(e,'oyuncu','katilim','muhalefet',b),(e,'oyuncu','katilim','muhalefet',c);
 v:=public.sokak_sert_islem(e,'ac','{"tur":"safak","gerekce":"Nöbet tutan yok, meydan sabah dağıtılacak"}'::jsonb);
 if (select durum from oyun.sokak_eylem where id=e)<>'yatisti' then raise exception 'Şafak eylemi kapatmadı'; end if;
 if (select count(*) from oyun.sokak_sicil where eylem_id=e and tur='sert')<>1 then raise exception 'Sicil yazılmadı'; end if;

 insert into oyun.sokak_eylem(il_id,parti_id,baslatan,gerekce,durum,baslangic,bitis) values(6,pid,lider,'İkinci eylem','aktif',oyun.simdi(),oyun.simdi()+interval '2 days') returning id into e;
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destek_turu,taraf,temsilci) values
  (e,'oyuncu','katilim','muhalefet',lider),(e,'oyuncu','katilim','muhalefet',a),(e,'oyuncu','katilim','muhalefet',b),(e,'oyuncu','katilim','muhalefet',c);
 perform set_config('request.jwt.claim.sub',a::text,false);
 perform public.sokak_sert_islem(e,'nobet','{}'::jsonb);
 perform set_config('request.jwt.claim.sub',b::text,false);
 perform public.sokak_sert_islem(e,'nobet','{}'::jsonb);
 perform set_config('request.jwt.claim.sub',cb::text,false);
 v:=public.sokak_sert_islem(e,'ac','{"tur":"safak","gerekce":"Nöbet varken şafak tutmamalı ve meydan güçlenmeli"}'::jsonb);
 if (select durum from oyun.sokak_sert where eylem_id=e and tur='safak')<>'basarisiz' then raise exception 'Şafak nöbeti yenemedi'; end if;
 if (select coalesce(sum(puan),0) from oyun.sokak_meydan_etki where eylem_id=e and tur='safak')<>12 then raise exception 'Şafak tepkisi +12 değil'; end if;

 perform set_config('oyun.simdi','2026-11-09 08:00:00+00',false);
 v:=public.sokak_sert_islem(e,'ac','{"tur":"elebasi","gerekce":"Organizatör ve iki kişi on iki saat eylemin dışında"}'::jsonb);
 if exists(select 1 from oyun.sokak_eylem_destek where eylem_id=e and temsilci=lider and destek_turu='katilim') then raise exception 'Organizatör dışarı çıkmadı'; end if;
 select count(*) into n from oyun.sokak_disari where eylem_id=e and tur='elebasi';
 if n<>3 then raise exception 'Elebaşı sayısı %', n; end if;
 perform set_config('request.jwt.claim.sub',av::text,false);
 perform public.sokak_sert_islem(e,'avukat','{}'::jsonb);
 begin perform public.sokak_sert_islem(e,'avukat','{}'::jsonb); raise exception 'TEST cift itiraz';
 exception when others then if sqlerrm like 'TEST%' then raise; end if; end;

 perform set_config('oyun.simdi','2026-11-09 22:00:00+00',false);
 perform set_config('request.jwt.claim.sub',cb::text,false);
 perform public.sokak_sert_islem(e,'ac','{"tur":"mali","gerekce":"Parti ve dernek kasası kırk sekiz saat süre uzatamaz"}'::jsonb);
 perform set_config('request.jwt.claim.sub',lider::text,false);
 begin
  perform public.sokak_destek(e,'muhalefet','parti',pid,5000);
  raise exception 'TEST fon';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%Mali kuşatma%' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',hakim::text,false);
 perform public.sokak_sert_islem(e,'yargi',jsonb_build_object('id',(select id from oyun.sokak_sert where eylem_id=e and tur='mali'),'oy','aykiri'));
 if (select durum from oyun.sokak_sert where eylem_id=e and tur='mali')<>'aykiri' then raise exception 'Mali kuşatma düşmedi'; end if;
 if (select kasa from oyun.partiler where id=pid)<1000000 then raise exception 'Tazminat yazılmadı'; end if;

 if has_function_privilege('anon','public.sokak_sert_islem(bigint,text,jsonb)','execute') then raise exception 'Anon açık'; end if;
 if not has_function_privilege('authenticated','public.sokak_sert_panel()','execute') then raise exception 'Panel kapalı'; end if;
 if has_function_privilege('authenticated','oyun.sokak_sert_tick()','execute') then raise exception 'İç tick açık'; end if;
 if position('sokak_ohal_aktif' in pg_get_functiondef('public.sokak_eylem_baslat(integer,text)'::regprocedure))=0 then raise exception 'OHAL açılışa bağlanmadı'; end if;
 if position('sokak_sert_tick' in pg_get_functiondef('oyun.sokak_tick()'::regprocedure))=0 then raise exception 'Tick bağlanmadı'; end if;
 if position('sokak_ohal_aktif' in pg_get_functiondef('public.sokak_tedbir_ac(bigint,text,text)'::regprocedure))=0 then raise exception 'Yarı fiyat bağlanmadı'; end if;
end $$;
select 'PASS: şafak, nöbet, elebaşı, avukat, mali kuşatma, tazminat, yetki' result;
