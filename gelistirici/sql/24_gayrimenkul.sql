-- Gayrimenkul: her mülk için satın alındığı andan itibaren 7 günde bir kira.
create table if not exists oyun.yatirim_mulkleri (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id),
 il_id smallint not null references oyun.iller(id),
 tip text not null check(tip in ('daire','dukkan','villa')),
 alis_bedeli numeric(16,2) not null check(alis_bedeli>0),
 haftalik_kira numeric(16,2) not null check(haftalik_kira>0),
 satin_alma timestamptz not null default now(),
 sonraki_kira timestamptz not null,
 toplam_kira numeric(16,2) not null default 0,
 kira_sayisi int not null default 0
);
create index if not exists yatirim_mulkleri_user_kira_idx on oyun.yatirim_mulkleri(user_id,sonraki_kira);
alter table oyun.yatirim_mulkleri enable row level security;
revoke all on oyun.yatirim_mulkleri from public,anon,authenticated;
revoke all on sequence oyun.yatirim_mulkleri_id_seq from public,anon,authenticated;

create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
declare m record; n int; gelir numeric; t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text, 78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
   n:=floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1;
   n:=least(n,520);
   gelir:=round(m.haftalik_kira*n,2);
   perform oyun.para_islem(p_user,gelir,'kira',format('%s numaralı mülkten %s haftalık kira',m.id,n),t);
   update oyun.yatirim_mulkleri
   set sonraki_kira=sonraki_kira+(n*interval '7 days'),
       toplam_kira=toplam_kira+gelir,
       kira_sayisi=kira_sayisi+n
   where id=m.id;
 end loop;
end $$;
revoke all on function oyun.mulk_kira_tahsil(uuid) from public,anon,authenticated;

create or replace function public.mulk_liste()
returns jsonb language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); p oyun.profiller; j jsonb;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 perform oyun.mulk_kira_tahsil(u);
 select jsonb_build_object(
   'mulkler',coalesce(jsonb_agg(jsonb_build_object(
      'id',m.id,'tip',m.tip,'il',i.ad,'alis',m.alis_bedeli,
      'haftalik',m.haftalik_kira,'sonraki',m.sonraki_kira,
      'toplam_kira',m.toplam_kira,'kira_sayisi',m.kira_sayisi
   ) order by m.satin_alma desc,m.id desc),'[]'::jsonb),
   'adet',count(m.id),
   'haftalik_toplam',coalesce(sum(m.haftalik_kira),0),
   'mulk_degeri',coalesce(sum(m.alis_bedeli),0),
   'cuzdan',(select para from oyun.cuzdan where user_id=u)
 ) into j
 from oyun.yatirim_mulkleri m join oyun.iller i on i.id=m.il_id where m.user_id=u;
 return j;
end $$;

create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü'; end if;
 bedel:=case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end;
 kira:=round(bedel/13,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s satın alındı',p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p.il_id,p_tip,bedel,kira,t,t+interval '7 days');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_liste() from public,anon;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_liste() to authenticated;
grant execute on function public.mulk_satin_al(text) to authenticated;
