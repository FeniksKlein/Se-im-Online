-- psql -d denge_test -v ON_ERROR_STOP=1 -f gelistirici/test/halk_denge_derle.sql
do $$ begin
 if current_database()<>'denge_test' then raise exception 'Bu dosya yalnız denge_test veritabanında çalışır'; end if;
end $$;
create schema if not exists oyun;
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
create table if not exists oyun.profiller(id uuid primary key, kad text, il_id int, yasakli boolean default false, olusturma timestamptz, son_gorulme timestamptz);
create table if not exists oyun.partiler(id bigint generated always as identity primary key, kasa numeric default 0, gb uuid, kapali boolean default false);
create table if not exists oyun.dernekler(id bigint generated always as identity primary key, kasa numeric default 0, baskan uuid, kapali boolean default false);
create table if not exists oyun.parti_hareket(parti_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text);
create table if not exists oyun.dernek_hareket(dernek_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text, user_id uuid);
create table if not exists oyun.sokak_eylem(
 id bigint generated always as identity primary key, il_id int, parti_id bigint, org_tur text, org_id bigint,
 baslatan uuid, gerekce text, durum text, baslangic timestamptz default now(), bitis timestamptz, seviye numeric);
create table if not exists oyun.sokak_eylem_destek(eylem_id bigint, destekci_tur text, destekci_id text, destek_turu text, taraf text, temsilci uuid);
create table if not exists oyun.il_durum(il_id int primary key, memnuniyet numeric, kasa numeric);
create table if not exists oyun.sokak_meydan_etki(id bigint generated always as identity primary key, eylem_id bigint, tur text, puan numeric, bitis timestamptz);
create table if not exists oyun.sokak_hamle(id bigint generated always as identity primary key, eylem_id bigint, tur text, yapan uuid, bedel numeric, durum text, zaman timestamptz, bitis timestamptz, etki jsonb default '{}');
create table if not exists oyun.sokak_sert(id bigint generated always as identity primary key, eylem_id bigint, tur text, yapan uuid, gerekce text, bedel numeric, durum text, zaman timestamptz, bitis timestamptz);
create or replace function oyun.simdi() returns timestamptz language sql as $$ select timestamptz '2026-11-09 12:00:00+00' $$;
create or replace function oyun.sokak_memnuniyetsizlik(p_il integer) returns numeric language sql as $$ select 20::numeric $$;
create or replace function public.sokak_org_baslat(p_il integer, p_gerekce text, p_tur text, p_kaynak text, p_kaynak_id bigint, p_olay bigint) returns jsonb
language plpgsql as $$
declare u uuid:=auth.uid(); eid bigint;
begin
 insert into oyun.sokak_eylem(il_id,parti_id,org_tur,org_id,baslatan,gerekce,durum,baslangic,bitis,seviye)
  values(p_il, case when p_kaynak='parti' then p_kaynak_id end, p_kaynak, p_kaynak_id, u, p_gerekce, 'aktif', oyun.simdi(), oyun.simdi()+interval '1 day', 10)
  returning id into eid;
 return jsonb_build_object('tamam',true,'eylem_id',eid);
end $$;

\i supabase/migrations/20261109250000_halk_eylem_denge.sql

do $$
declare lider uuid:='00000000-0000-0000-0000-00000000d001';
 a uuid:='00000000-0000-0000-0000-00000000d002';
 b uuid:='00000000-0000-0000-0000-00000000d003';
 c uuid:='00000000-0000-0000-0000-00000000d004';
 d uuid:='00000000-0000-0000-0000-00000000d005';
 pid bigint; cid bigint; eid bigint; v jsonb; tutar numeric;
begin
 insert into oyun.profiller values
  (lider,'lider',6,false,oyun.simdi()-interval '30 days',oyun.simdi()),
  (a,'a',6,false,oyun.simdi()-interval '10 days',oyun.simdi()),
  (b,'b',6,false,oyun.simdi()-interval '10 days',oyun.simdi()),
  (c,'c',6,false,oyun.simdi()-interval '10 days',oyun.simdi()),
  (d,'d',6,false,oyun.simdi()-interval '10 days',oyun.simdi());
 insert into oyun.partiler(kasa,gb) values(1000000,lider) returning id into pid;
 insert into oyun.il_durum values(6,80,10);
 perform set_config('request.jwt.claim.sub',lider::text,false);
 begin
  perform public.sokak_cagri_ac(6,'Bu ilde keyfi bir eylem açılmamalıdır','genel','parti',pid);
  raise exception 'TEST şikayet';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%şikayet%' then raise; end if; end;
 update oyun.il_durum set memnuniyet=40 where il_id=6;
 v:=public.sokak_cagri_ac(6,'Memnuniyet düşünce çağrı açılabilir artık','genel','parti',pid);
 cid:=(v->>'cagri_id')::bigint;
 if (select p.kasa from oyun.partiler p where p.id=pid)<>950000 then raise exception 'Depozito alınmadı'; end if;
 begin
  insert into oyun.sokak_eylem(il_id,baslatan,durum,baslangic,bitis,seviye) values(6,lider,'aktif',oyun.simdi(),oyun.simdi()+interval '1 day',5);
  raise exception 'TEST keyfi';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%keyfi%' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',a::text,false);
 perform public.sokak_cagri_imza(cid);
 perform set_config('request.jwt.claim.sub',b::text,false);
 perform public.sokak_cagri_imza(cid);
 perform set_config('request.jwt.claim.sub',c::text,false);
 perform public.sokak_cagri_imza(cid);
 perform set_config('request.jwt.claim.sub',d::text,false);
 v:=public.sokak_cagri_imza(cid);
 eid:=(v->>'eylem_id')::bigint;
 if eid is null or (select durum from oyun.sokak_cagri where id=cid)<>'acildi' then raise exception 'Çağrı eyleme dönmedi'; end if;
 update oyun.sokak_eylem set seviye=40 where id=eid;
 if (select seviye from oyun.sokak_eylem where id=eid)>22 then raise exception 'Saatlik tavan işlemedi: %', (select seviye from oyun.sokak_eylem where id=eid); end if;
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destek_turu,taraf,temsilci) values
  (eid,'oyuncu','katilim','muhalefet',a),(eid,'oyuncu','katilim','muhalefet',b);
 begin
  insert into oyun.sokak_hamle(eylem_id,tur,yapan,durum,zaman,bitis) values(eid,'grev',lider,'aktif',oyun.simdi(),oyun.simdi()+interval '1 hour');
  raise exception 'TEST kapi';
 exception when others then if sqlerrm like 'TEST%' or sqlerrm not like '%büyük hamle%' then raise; end if; end;
 update oyun.sokak_ivme set ivme=80, yorgunluk=0 where eylem_id=eid;
 insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(eid,'mesale',10,oyun.simdi()+interval '1 hour');
 if (select son_not from oyun.sokak_ivme where eylem_id=eid) not like '%Meşale%' and (select son_not from oyun.sokak_ivme where eylem_id=eid) not like '%Az katılımcı%' then
  raise exception 'Geri bildirim yok: %', (select son_not from oyun.sokak_ivme where eylem_id=eid);
 end if;
 insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(eid,'mesale',10,oyun.simdi()+interval '1 hour');
 if (select son_not from oyun.sokak_ivme where eylem_id=eid) not like '%bık%' then raise exception 'Tekrar cezası yok'; end if;
 select depozito into tutar from oyun.sokak_denge_ayar where id=1;
 update oyun.sokak_denge_ayar set depozito=12345 where id=1;
end $$;
\i supabase/migrations/20261109250000_halk_eylem_denge.sql
do $$ begin
 if (select depozito from oyun.sokak_denge_ayar where id=1)<>12345 then raise exception 'Ayar ikinci çalışmada sıfırlandı'; end if;
 if has_function_privilege('anon','public.sokak_cagri_ac(integer,text,text,text,bigint)','execute') then raise exception 'Anon açık'; end if;
end $$;
select 'PASS: çağrı, depozito, keyfi engel, tavan, büyük hamle, tekrar, ayar kalıcı' result;
