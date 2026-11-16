create schema oyun; create schema oyun_yonetim;
do $r$ begin create role anon; exception when others then null; end $r$; do $r$ begin create role authenticated; exception when others then null; end $r$;
create schema auth; create function auth.uid() returns uuid language sql as $$ select null::uuid $$;
create function oyun.simdi() returns timestamptz language sql as $$ select now() $$;
create table oyun.partiler(id bigint primary key, gb uuid, kapali bool default false, kisa text, ad text);
create table oyun.profiller(id uuid primary key, kad text, parti_id bigint, il_id smallint, yasakli bool default false, parti_at timestamptz, il_at timestamptz, olusturma timestamptz default now());
create table oyun.parti_gby(parti_id bigint, sira smallint, user_id uuid, atama timestamptz, miting_yetkisi bool default false, gorev text);
create table oyun.parti_teskilat_gorev(parti_id bigint, il_id smallint, user_id uuid, atayan uuid, atama timestamptz, aktif bool, primary key(parti_id,il_id));
create table oyun.parti_teskilat(parti_id bigint, il_id smallint);
create table oyun.parti_hareket(parti_id bigint, zaman timestamptz, tutar numeric, tur text, aciklama text);
create table oyun.zamanlayici_adim(adim text primary key, komut text, periyot_dk int default 1, ofset_dk int default 0, sira int default 100, aktif bool default true);
create table oyun.iller(id smallint primary key, ad text);
create function oyun.gby_alan(p text) returns text language sql immutable as $$ select null::text $$;
create function public.gby_ata(p_sira integer, p_kad text) returns jsonb language plpgsql as $f$
declare pa oyun.partiler; begin
  if p_sira is null or p_sira not between 1 and 6 then
    raise exception 'Geçersiz sıra (1-6).';
  end if; return null; end $f$;
create function public.teskilat_gorev_ver(p_il integer, p_kad text) returns jsonb language plpgsql as $f$
declare ilad text; begin
  select ad into ilad from oyun.iller where id=p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  perform format('seni %s Parti İl Başkanı yaptı. Milletvekili olsan da bu görev devam eder.');
  return null; end $f$;
create function public.teskilat_gorev_al(p_il integer) returns jsonb language plpgsql as $f$
declare h uuid; begin
  select user_id into h from oyun.parti_teskilat_gorev
  where il_id=p_il and aktif for update;
  return null; end $f$;
insert into oyun.partiler values(1,'00000000-0000-0000-0000-000000000001',false,'TP','Test');
insert into oyun.profiller(id,kad,parti_id,il_id) values('00000000-0000-0000-0000-000000000001','gb',1,6),('00000000-0000-0000-0000-000000000002','y',1,6);
insert into oyun.parti_gby values(1,1,'00000000-0000-0000-0000-000000000002',now(),true,null);
insert into oyun.parti_teskilat_gorev values(1,6,'00000000-0000-0000-0000-000000000002',null,now(),true);
