-- psql -d ayril_test -v ON_ERROR_STOP=1 -f gelistirici/test/halk_ayril_derle.sql
do $$ begin
 if current_database()<>'ayril_test' then raise exception 'Bu dosya yalnız ayril_test veritabanında çalışır'; end if;
end $$;
create schema if not exists oyun;
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
create table if not exists oyun.profiller(id uuid primary key, kad text, il_id int, yasakli boolean default false);
create table if not exists oyun.partiler(id bigint generated always as identity primary key, kasa numeric default 0);
create table if not exists oyun.dernekler(id bigint generated always as identity primary key, kasa numeric default 0);
create table if not exists oyun.parti_hareket(parti_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text);
create table if not exists oyun.dernek_hareket(dernek_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text, user_id uuid);
create table if not exists oyun.cuzdan(user_id uuid primary key, para numeric default 0);
create table if not exists oyun.sokak_eylem(
 id bigint generated always as identity primary key, il_id int, parti_id bigint, org_tur text default 'parti', org_id bigint,
 baslatan uuid, durum text, baslangic timestamptz, bitis timestamptz, seviye numeric default 10);
create table if not exists oyun.sokak_eylem_destek(
 eylem_id bigint, destekci_tur text, destekci_id text, destek_turu text, taraf text, temsilci uuid);
create table if not exists oyun.ulke(id int primary key, hazine numeric, memnuniyet numeric);
insert into oyun.ulke values(1,200,50) on conflict do nothing;
create table if not exists oyun.il_durum(il_id int primary key, kasa numeric, memnuniyet numeric);
insert into oyun.il_durum values(6,10,50) on conflict do nothing;
create table if not exists oyun.bakanlik_kasa(kod text primary key, kasa numeric);
insert into oyun.bakanlik_kasa values('icisleri',5) on conflict do nothing;
create table if not exists oyun.makamlar(user_id uuid, tur text, bakanlik text, bit timestamptz);
create table if not exists oyun.sokak_meydan_etki(id bigint generated always as identity primary key, eylem_id bigint, tur text, puan numeric, bitis timestamptz);
create table if not exists oyun.sokak_itibar(user_id uuid primary key, puan int);
create table if not exists oyun.sokak_gensoru(id bigint generated always as identity primary key, acan uuid, gerekce text, bas timestamptz, bit timestamptz, durum text default 'oylamada');
create table if not exists oyun.sokak_taktik(eylem_id bigint, user_id uuid, tur text, metin text, zaman timestamptz, bitis timestamptz);
create table if not exists oyun.sokak_gorevli(eylem_id bigint, user_id uuid, unvan text, katilma timestamptz, ayrilma timestamptz);
create table if not exists oyun.sokak_nobet_rota(eylem_id bigint, user_id uuid, gun date, zaman timestamptz, primary key(eylem_id,user_id,gun));
create table if not exists oyun.sokak_sert(id bigint generated always as identity primary key, eylem_id bigint, tur text, yapan uuid, gerekce text, bedel numeric, durum text, zaman timestamptz, bitis timestamptz);
create table if not exists oyun.bildirimler(user_id uuid, zaman timestamptz, metin text);
create table if not exists public.sokak_eylem_sohbet(id bigint generated always as identity primary key, eylem_id bigint, user_id uuid, metin text, zaman timestamptz);
create or replace function oyun.simdi() returns timestamptz language sql stable as $$
 select coalesce(nullif(current_setting('oyun.simdi', true),'')::timestamptz, timestamptz '2026-11-09 12:00:00+00') $$;
create or replace function oyun.pazar_tl_milyar() returns numeric language sql as $$ select 150000::numeric $$;
create or replace function oyun.bm_kasa_harca(p_kod text, p_tutar numeric, p_tur text, p_aciklama text) returns numeric language plpgsql as $$
declare v numeric; begin select kasa into v from oyun.bakanlik_kasa where kod=p_kod for update;
 if v<p_tutar then raise exception 'yetersiz'; end if; update oyun.bakanlik_kasa set kasa=kasa-p_tutar where kod=p_kod; return v-p_tutar; end $$;
create or replace function oyun.sokak_sert_yetkili(u uuid, il integer) returns boolean language sql as $$ select true $$;
create or replace function oyun.sokak_katilimci(e bigint, u uuid) returns boolean language sql as $$
 select exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=e and d.temsilci=u and d.destek_turu='katilim') $$;
create or replace function oyun.sokak_iktidar(u uuid) returns boolean language sql as $$ select false $$;
create or replace function oyun.sokak_temiz(m text, n int) returns text language sql as $$ select left(coalesce(nullif(btrim(m),''),'Gerekçe metni yeterince uzun tutuldu'),n) $$;
create or replace function oyun.sokak_duyur(p_id bigint, p_metin text) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_yenile(p_id bigint) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_kriz_kontrol() returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_manset_yaz(m text) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_sicil_yaz(u uuid, e bigint, tur text, ozet text) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_memnuniyetsizlik(p_il integer) returns numeric language sql as $$ select 40::numeric $$;
create or replace function oyun.bildir(p_user uuid, p_metin text, p_zaman timestamptz default null) returns void language sql as $$ select null::void $$;
create or replace function oyun.kad(u uuid) returns text language sql as $$ select 'oyuncu' $$;
create or replace function public.sokak_eylemden_ayril(p_eylem bigint) returns jsonb language plpgsql as $$
declare u uuid:=auth.uid(); n int; begin
 delete from oyun.sokak_eylem_destek where eylem_id=p_eylem and temsilci=u and destek_turu='katilim';
 get diagnostics n=row_count; if n=0 then raise exception 'Bu eyleme katılmıyorsun'; end if;
 return jsonb_build_object('tamam',true); end $$;
create or replace function public.sokak_gorevden_ayril(p_eylem bigint) returns jsonb language plpgsql as $$
declare u uuid:=auth.uid(); n int; begin
 update oyun.sokak_gorevli set ayrilma=oyun.simdi() where eylem_id=p_eylem and user_id=u and ayrilma is null;
 get diagnostics n=row_count; if n=0 then raise exception 'görev yok'; end if; return jsonb_build_object('tamam',true); end $$;

\i supabase/migrations/20261109230000_halk_eylem_merkezi.sql
\i supabase/migrations/20261109240000_halk_katilim_ayril.sql

do $$
declare u uuid:='00000000-0000-0000-0000-0000000000b1';
 b uuid:='00000000-0000-0000-0000-0000000000b2';
 c uuid:='00000000-0000-0000-0000-0000000000b3';
 d uuid:='00000000-0000-0000-0000-0000000000b4';
 pid bigint; e bigint; iid bigint; qid bigint; hid bigint;
begin
 insert into oyun.profiller values(u,'ali',6),(b,'berk',6),(c,'cem',6),(d,'deniz',6);
 insert into oyun.partiler(kasa) values(5000000) returning id into pid;
 insert into oyun.sokak_eylem(il_id,parti_id,org_tur,org_id,baslatan,durum,baslangic,bitis)
  values(6,pid,'parti',pid,u,'aktif',oyun.simdi()-interval '2 hours',oyun.simdi()+interval '1 day') returning id into e;
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,destek_turu,taraf,temsilci)
  values(e,'oyuncu',u::text,'katilim','muhalefet',u),(e,'oyuncu',b::text,'katilim','muhalefet',b),
         (e,'oyuncu',c::text,'katilim','muhalefet',c),(e,'oyuncu',d::text,'katilim','muhalefet',d);
 perform set_config('request.jwt.claim.sub',u::text,false);
 perform public.sokak_eylem_merkezi_islem(e,'hamle','{"tur":"grev","gerekce":"Genel grev için yeterli katılımcı var"}'::jsonb);
 select id into hid from oyun.sokak_hamle where eylem_id=e and tur='grev';
 if (select count(*) from oyun.sokak_hamle_kisi where hamle_id=hid and user_id=u)<>1 then raise exception 'Grev kişisi yazılmadı'; end if;
 perform public.sokak_katilim_ayril(e,'grev',null);
 if exists(select 1 from oyun.sokak_hamle_kisi where hamle_id=hid) then raise exception 'Grevden çıkılmadı'; end if;
 if (select durum from oyun.sokak_hamle where id=hid)<>'aktif' then raise exception 'Grev hamlesi silinmemeli'; end if;
 if (select kasa from oyun.partiler where id=pid)<>4850000 then raise exception 'Ayrılmak parayı iade etti'; end if;
 update oyun.il_durum set kasa=20 where il_id=6;
 if (select kasa from oyun.il_durum where il_id=6)<>20 then raise exception 'Boş grev hâlâ kesiyor'; end if;
 begin
  perform public.sokak_hamle_kisi_katil(e,'grev');
  raise exception 'TEST bekleme';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%kısa bir süre%' then raise; end if; end;

 insert into oyun.sokak_aclik(eylem_id,user_id,bitis) values(e,u,oyun.simdi()+interval '2 hours');
 perform public.sokak_katilim_ayril(e,'aclik',null);
 if exists(select 1 from oyun.sokak_aclik where eylem_id=e and user_id=u) then raise exception 'Açlık bitmedi'; end if;

 insert into oyun.sokak_isgal(eylem_id,il_id,bina,bas,bitis,son) values(e,6,'belediye',oyun.simdi()-interval '20 minutes',oyun.simdi()+interval '2 hours',oyun.simdi()) returning id into iid;
 insert into oyun.sokak_vardiya(isgal_id,user_id,taraf,bas,bitis) values(iid,u,'isgal',oyun.simdi(),oyun.simdi()+interval '1 hour'),(iid,b,'isgal',oyun.simdi(),oyun.simdi()+interval '1 hour');
 perform public.sokak_katilim_ayril(e,'isgal',null);
 if exists(select 1 from oyun.sokak_vardiya where isgal_id=iid and user_id=u and bitis>oyun.simdi()) then raise exception 'Nöbet sürüyor'; end if;
 if (select durum from oyun.sokak_isgal where id=iid)<>'coktu' then raise exception 'İşgal dağılmadı'; end if;

 insert into oyun.sokak_isgal(eylem_id,il_id,bina,durum,bas,bitis,son) values(e,6,'valilik','aktif',oyun.simdi(),oyun.simdi()+interval '2 hours',oyun.simdi()) returning id into iid;
 insert into oyun.sokak_tahliye(isgal_id,yapan,bedel,bas,bitis,durum) values(iid,u,1,oyun.simdi(),oyun.simdi()+interval '20 minutes','geri_sayim') returning id into qid;
 insert into oyun.sokak_tahliye_katilim(tahliye_id,user_id,taraf) values(qid,u,'savun');
 perform public.sokak_katilim_ayril(e,'tahliye_savun',null);
 if exists(select 1 from oyun.sokak_tahliye_katilim where tahliye_id=qid) then raise exception 'Savunma sayımda kaldı'; end if;

 insert into oyun.sokak_nobet_rota values(e,u,(oyun.simdi() at time zone 'Europe/Istanbul')::date,oyun.simdi());
 perform public.sokak_katilim_ayril(e,'rota',null);
 if exists(select 1 from oyun.sokak_nobet_rota where eylem_id=e and user_id=u) then raise exception 'Rota duruyor'; end if;

 insert into oyun.sokak_isik values(e,u,(oyun.simdi() at time zone 'Europe/Istanbul')::date,oyun.simdi());
 perform public.sokak_katilim_ayril(e,'mesale',null);
 if exists(select 1 from oyun.sokak_isik where eylem_id=e and user_id=u) then raise exception 'Işık duruyor'; end if;

 insert into oyun.sokak_sizma(eylem_id,user_id,zaman) values(e,u,oyun.simdi());
 perform public.sokak_katilim_ayril(e,'sizma',null);
 if exists(select 1 from oyun.sokak_sizma where eylem_id=e and user_id=u and durum='aktif') then raise exception 'Sızma sürüyor'; end if;

 perform public.sokak_katilim_ayril(e,'eylem',null);
 if exists(select 1 from oyun.sokak_eylem_destek where eylem_id=e and temsilci=u and destek_turu='katilim') then raise exception 'Eylem katılımı duruyor'; end if;
end $$;
select 'PASS: ayrıl, bekleme, grev kesintisi, işgal, tahliye, rota, ışık, sızma' result;
\i supabase/migrations/20261109240000_halk_katilim_ayril.sql
select 'PASS: ayril migration ikinci kez' result;
