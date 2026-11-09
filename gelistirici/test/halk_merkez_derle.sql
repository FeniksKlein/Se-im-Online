-- Yerel derleme. Canlı veritabanında çalışmaz.
-- psql -d merkez_test -v ON_ERROR_STOP=1 -f gelistirici/test/halk_merkez_derle.sql
do $$ begin
 if current_database()<>'merkez_test' then raise exception 'Bu dosya yalnız merkez_test veritabanında çalışır'; end if;
end $$;
create schema if not exists oyun;
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;

create table if not exists oyun.profiller(id uuid primary key, kad text, il_id int, yasakli boolean default false);
create table if not exists oyun.partiler(id bigint generated always as identity primary key, kasa numeric default 0, kapali boolean default false);
create table if not exists oyun.dernekler(id bigint generated always as identity primary key, kasa numeric default 0);
create table if not exists oyun.parti_hareket(parti_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text);
create table if not exists oyun.dernek_hareket(dernek_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text, user_id uuid);
create table if not exists oyun.cuzdan(user_id uuid primary key, para numeric default 0);
create table if not exists oyun.sokak_eylem(
 id bigint generated always as identity primary key, il_id integer, parti_id bigint, org_tur text default 'parti', org_id bigint,
 baslatan uuid, gerekce text, durum text, baslangic timestamptz, bitis timestamptz, seviye numeric default 40);
create table if not exists oyun.sokak_eylem_destek(eylem_id bigint, destekci_tur text, destek_turu text, taraf text, temsilci uuid);
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
create table if not exists oyun.sokak_taktik(eylem_id bigint, user_id uuid, tur text, bitis timestamptz);
create table if not exists oyun.sokak_sert(id bigint generated always as identity primary key, eylem_id bigint, tur text, yapan uuid, gerekce text, bedel numeric, durum text, zaman timestamptz, bitis timestamptz);
create table if not exists oyun.belediye_bina(id bigint generated always as identity primary key, il_id int, kod text, durum text);
create table if not exists oyun.icisleri_atama(id bigint generated always as identity primary key, il_id int, hedef uuid, tur text);
create table if not exists public.sokak_eylem_sohbet(id bigint generated always as identity primary key, eylem_id bigint, user_id uuid, metin text, zaman timestamptz);
create table if not exists oyun.bildirimler(user_id uuid, zaman timestamptz, metin text);

create or replace function oyun.simdi() returns timestamptz language sql stable as $$
 select coalesce(nullif(current_setting('oyun.simdi', true),'')::timestamptz, timestamptz '2026-11-09 12:00:00+00') $$;
create or replace function oyun.pazar_tl_milyar() returns numeric language sql as $$ select 150000::numeric $$;
create or replace function oyun.bm_kasa_harca(p_kod text, p_tutar numeric, p_tur text, p_aciklama text) returns numeric language plpgsql as $$
declare v numeric; begin
 select kasa into v from oyun.bakanlik_kasa where kod=p_kod for update;
 if v< p_tutar then raise exception 'Bakanlık kasasında yeterli ödenek yok'; end if;
 update oyun.bakanlik_kasa set kasa=kasa-p_tutar where kod=p_kod; return v-p_tutar; end $$;
create or replace function oyun.sokak_sert_yetkili(u uuid, il integer) returns boolean language sql as $$
 select exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb') $$;
create or replace function oyun.sokak_katilimci(e bigint, u uuid) returns boolean language sql as $$
 select exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=e and d.temsilci=u and d.destek_turu='katilim' and d.taraf='muhalefet') $$;
create or replace function oyun.sokak_iktidar(u uuid) returns boolean language sql as $$ select false $$;
create or replace function oyun.sokak_temiz(m text, n int) returns text language plpgsql as $$
begin m:=btrim(coalesce(m,'')); if char_length(m)<1 then m:='Gerekçe metni yeterince uzun tutuldu'; end if; return left(m,n); end $$;
create or replace function oyun.sokak_duyur(p_id bigint, p_metin text) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_yenile(p_id bigint) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_manset_yaz(m text) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_sicil_yaz(u uuid, e bigint, tur text, ozet text) returns void language sql as $$ select null::void $$;
create or replace function oyun.sokak_memnuniyetsizlik(p_il integer) returns numeric language sql as $$ select 55::numeric $$;
create or replace function oyun.bildir(p_user uuid, p_metin text, p_zaman timestamptz default null) returns void language sql as $$ select null::void $$;
create or replace function oyun.kad(u uuid) returns text language sql as $$ select kad from oyun.profiller where id=u $$;

\i supabase/migrations/20261109230000_halk_eylem_merkezi.sql

do $$
declare cb uuid:='00000000-0000-0000-0000-0000000000c1';
 lider uuid:='00000000-0000-0000-0000-0000000000a1';
 a uuid:='00000000-0000-0000-0000-0000000000a2';
 b uuid:='00000000-0000-0000-0000-0000000000a3';
 c uuid:='00000000-0000-0000-0000-0000000000a4';
 pid bigint; e bigint; once numeric; sonra numeric;
begin
 insert into oyun.profiller values(cb,'baskan',6),(lider,'lider',6),(a,'ayse',6),(b,'berk',6),(c,'cem',34);
 insert into oyun.makamlar(user_id,tur) values(cb,'cb');
 insert into oyun.partiler(kasa) values(1000000) returning id into pid;
 insert into oyun.sokak_eylem(il_id,parti_id,org_tur,org_id,baslatan,durum,baslangic,bitis)
  values(6,pid,'parti',pid,lider,'aktif',oyun.simdi()-interval '2 hours',oyun.simdi()+interval '2 days') returning id into e;
 insert into oyun.sokak_eylem_destek values
  (e,'oyuncu','katilim','muhalefet',lider),(e,'oyuncu','katilim','muhalefet',a),
  (e,'oyuncu','katilim','muhalefet',b),(e,'oyuncu','katilim','muhalefet',c);
 perform set_config('request.jwt.claim.sub',lider::text,false);
 select hazine into once from oyun.ulke where id=1;
 perform public.sokak_eylem_merkezi_islem(e,'hamle','{"tur":"grev","gerekce":"İl ekonomisi duruncaya kadar genel grev"}'::jsonb);
 if (select count(*) from oyun.sokak_hamle where eylem_id=e and tur='grev' and durum='aktif')<>1 then raise exception 'Grev açılmadı'; end if;
 if (select kasa from oyun.partiler where id=pid)<>850000 then raise exception 'Parti kasası grevi ödemedi'; end if;
 update oyun.il_durum set kasa=20 where il_id=6;
 if (select kasa from oyun.il_durum where il_id=6)<>16 then raise exception 'Grev il gelirini kırmadı: %', (select kasa from oyun.il_durum where il_id=6); end if;
 select hazine into sonra from oyun.ulke where id=1;
 if sonra>=once then raise exception 'Hazine düşmedi'; end if;
 if (select count(*) from oyun.sokak_hazine_defter where eylem_id=e)=0 then raise exception 'Defter boş'; end if;

 perform public.sokak_eylem_merkezi_islem(e,'hamle','{"tur":"kalkan","gerekce":"Ekonomik önlemlere karşı boykot kalkanı"}'::jsonb);
 begin
  insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(e,'ihale',cb,'ihale',1,'aktif',oyun.simdi(),oyun.simdi()+interval '1 hour');
  raise exception 'TEST kalkan';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%Boykot kalkanı%' then raise; end if; end;

 perform set_config('oyun.simdi','2026-11-09 20:00:00+00',false);
 perform set_config('request.jwt.claim.sub',lider::text,false);
 perform public.sokak_eylem_merkezi_islem(e,'hamle','{"tur":"isgal","bina":"belediye","gerekce":"Belediye binası sembolik olarak tutulacak"}'::jsonb);
 update oyun.bakanlik_kasa set kasa=0.1 where kod='icisleri';
 perform set_config('request.jwt.claim.sub',cb::text,false);
 begin
  perform public.sokak_eylem_merkezi_islem(e,'kusatma','{}'::jsonb);
  raise exception 'TEST butce';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%bütçe%' then raise; end if; end;
 begin
  insert into oyun.belediye_bina(il_id,kod,durum) values(6,'park','insa');
  raise exception 'TEST bina';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%işgal%' then raise; end if; end;
 insert into oyun.belediye_bina(il_id,kod,durum) values(7,'park','insa');

 if has_function_privilege('anon','public.sokak_eylem_merkezi()','execute') then raise exception 'Anon açık'; end if;
 if not has_function_privilege('authenticated','public.sokak_eylem_merkezi_islem(bigint,text,jsonb)','execute') then raise exception 'İşlem kapalı'; end if;
 if to_regprocedure('public.sokak_eylem_baslat(integer,text)') is not null then
  if position('sokak_merkez' in pg_get_functiondef('public.sokak_eylem_baslat(integer,text)'::regprocedure))>0 then
   raise exception 'Açılış fonksiyonuna dokunuldu'; end if;
 end if;
end $$;
select 'PASS: grev, hazine, kalkan, bütçe, işgal tetikleyicisi' result;

\i supabase/migrations/20261109230000_halk_eylem_merkezi.sql
select 'PASS: migration ikinci kez uygulanır' result;
