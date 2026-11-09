-- psql -d kaynak_test -v ON_ERROR_STOP=1 -f gelistirici/test/halk_kaynak_derle.sql
do $$ begin
 if current_database()<>'kaynak_test' then raise exception 'Bu dosya yalnız kaynak_test veritabanında çalışır'; end if;
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
create table if not exists oyun.cuzdan(user_id uuid primary key, para numeric default 0);
create table if not exists oyun.sokak_eylem(
 id bigint generated always as identity primary key, il_id int, parti_id bigint, org_tur text, org_id bigint,
 baslatan uuid, gerekce text, durum text, baslangic timestamptz default now(), bitis timestamptz, seviye numeric);
create table if not exists oyun.sokak_eylem_destek(eylem_id bigint, destekci_tur text, destekci_id text, destek_turu text, taraf text, temsilci uuid);
create table if not exists oyun.il_durum(il_id int primary key, memnuniyet numeric, kasa numeric);
create table if not exists oyun.ulke(id int primary key, hazine numeric);
insert into oyun.ulke values(1,200) on conflict do nothing;
create table if not exists oyun.sokak_meydan_etki(id bigint generated always as identity primary key, eylem_id bigint, tur text, puan numeric, bitis timestamptz);
create table if not exists oyun.sokak_hamle(id bigint generated always as identity primary key, eylem_id bigint, tur text, yapan uuid, bedel numeric, durum text, zaman timestamptz, bitis timestamptz, etki jsonb default '{}');
create table if not exists oyun.sokak_sert(id bigint generated always as identity primary key, eylem_id bigint, tur text, yapan uuid, gerekce text, bedel numeric, durum text, zaman timestamptz, bitis timestamptz);
create or replace function oyun.simdi() returns timestamptz language sql as $$ select timestamptz '2026-11-09 12:00:00+00' $$;
create or replace function oyun.sokak_memnuniyetsizlik(p_il integer) returns numeric language sql as $$ select 50::numeric $$;
create or replace function oyun.sokak_katilimci(e bigint, u uuid) returns boolean language sql as $$
 select exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=e and d.temsilci=u and d.destek_turu='katilim') $$;
create or replace function oyun.sokak_yenile(p_id bigint) returns void language sql as $$ select null::void $$;
create or replace function public.sokak_org_baslat(p_il integer, p_gerekce text, p_tur text, p_kaynak text, p_kaynak_id bigint, p_olay bigint) returns jsonb
language sql as $$ select '{}'::jsonb $$;

\i supabase/migrations/20261109250000_halk_eylem_denge.sql
\i supabase/migrations/20261109260000_halk_eylem_kaynak.sql

do $$
declare lider uuid:='00000000-0000-0000-0000-00000000e001';
 kat uuid:='00000000-0000-0000-0000-00000000e002';
 pid bigint; cid bigint; e1 bigint; e2 bigint; g1 numeric; g2 numeric; g3 numeric; haz numeric;
begin
 insert into oyun.profiller values
  (lider,'lider',6,false,oyun.simdi()-interval '20 days',oyun.simdi()),
  (kat,'kat',6,false,oyun.simdi()-interval '20 days',oyun.simdi());
 insert into oyun.partiler(kasa,gb) values(5000000,lider) returning id into pid;
 insert into oyun.cuzdan values(kat,100000);
 insert into oyun.il_durum values(6,40,0);
 insert into oyun.sokak_cagri(il_id,acan,kaynak,kaynak_id,talep,gerekce,depozito,durum,acilis,bitis)
  values(6,lider,'parti',pid,'genel','Kaynak denemesi için hazır çağrı metni',0,'hazir',oyun.simdi(),oyun.simdi()+interval '2 hours')
  returning id into cid;
 perform set_config('oyun.cagri_id',cid::text,true);
 perform set_config('request.jwt.claim.sub',lider::text,true);
 insert into oyun.sokak_eylem(il_id,parti_id,org_tur,org_id,baslatan,durum,baslangic,bitis,seviye)
  values(6,pid,'parti',pid,lider,'aktif',oyun.simdi(),oyun.simdi()+interval '1 day',20) returning id into e1;
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destek_turu,taraf,temsilci) values(e1,'oyuncu','katilim','muhalefet',kat);
 update oyun.sokak_ivme set ivme=80, yorgunluk=0 where eylem_id=e1;
 perform public.sokak_kaynak_aktar(e1,'parti',pid,'ses',100000);
 select guc into g1 from oyun.sokak_kaynak where eylem_id=e1 order by id desc limit 1;
 if (select p.kasa from oyun.partiler p where p.id=pid)<>4900000 then raise exception 'Parti kasası düşmedi'; end if;
 if (select hazine from oyun.ulke where id=1)<>200 then raise exception 'Hazine kaynağa bağlandı'; end if;
 if (select count(*) from oyun.sokak_eylem_destek where eylem_id=e1 and destek_turu='katilim')<>1 then raise exception 'Kaynak sahte katılımcı ekledi'; end if;
 update oyun.sokak_eylem set baslangic=oyun.simdi()-interval '3 days' where id=e1;
 insert into oyun.sokak_cagri(il_id,acan,kaynak,kaynak_id,talep,gerekce,depozito,durum,acilis,bitis)
  values(7,lider,'parti',pid,'genel','İkinci eylem çağrısı yorgunluk için',0,'hazir',oyun.simdi(),oyun.simdi()+interval '2 hours')
  returning id into cid;
 perform set_config('oyun.cagri_id',cid::text,true);
 insert into oyun.sokak_eylem(il_id,parti_id,org_tur,org_id,baslatan,durum,baslangic,bitis,seviye)
  values(7,pid,'parti',pid,lider,'aktif',oyun.simdi()-interval '2 days',oyun.simdi()+interval '1 day',20) returning id into e2;
 update oyun.sokak_ivme set ivme=10, yorgunluk=90 where eylem_id=e2;
 perform public.sokak_kaynak_aktar(e2,'parti',pid,'yemek',100000);
 select guc into g2 from oyun.sokak_kaynak where eylem_id=e2 order by id desc limit 1;
 if g2>=g1 then raise exception 'Yorgun kaynak en az birinci kadar güç verdi: % ve %', g2, g1; end if;
 create or replace function oyun.simdi() returns timestamptz language sql as $s$ select timestamptz '2026-11-09 14:00:00+00' $s$;
 perform public.sokak_kaynak_aktar(e1,'parti',pid,'ulasim',100000);
 select guc into g3 from oyun.sokak_kaynak where eylem_id=e1 order by id desc limit 1;
 if g3>=g1 then raise exception 'İkinci aktarım azalmadı'; end if;
 if (select (public.sokak_kaynak_ozet()->'eylemler') is null) then raise exception 'Özet yok'; end if;
 if not (select bool_or((x->>'sinyal')::boolean) from jsonb_array_elements((public.sokak_kaynak_ozet()->'eylemler')) x where (x->>'id')::bigint=e1) then
  raise exception 'Sinyal yanmadı'; end if;
 insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(e1,'mali',lider,'Mali',1,'aktif',oyun.simdi(),oyun.simdi()+interval '1 hour');
 if (select count(*) from oyun.sokak_meydan_etki where eylem_id=e1 and tur='kaynak_baski')<>1 then raise exception 'Mali kuşatma sinyali beslenmedi'; end if;
 perform set_config('request.jwt.claim.sub',kat::text,true);
 perform public.sokak_kaynak_aktar(e1,'oyuncu',null,'pankart',10000);
 if (select para from oyun.cuzdan where user_id=kat)<>90000 then raise exception 'Cüzdan düşmedi'; end if;
 update oyun.sokak_denge_ayar set kaynak_min=11111 where id=1;
end $$;
\i supabase/migrations/20261109260000_halk_eylem_kaynak.sql
do $$ begin
 if (select kaynak_min from oyun.sokak_denge_ayar where id=1)<>11111 then raise exception 'Ayar sıfırlandı'; end if;
 if has_function_privilege('anon','public.sokak_kaynak_aktar(bigint,text,bigint,text,numeric)','execute') then raise exception 'Anon açık'; end if;
end $$;
select 'PASS: kaynak, azalan getiri, yorgunluk, sinyal, cüzdan, ayar kalıcı' result;
