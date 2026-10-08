-- Sadece sanal emlak pazarında oyuncular arası satış. Mevcut mülkleri koru.
create table if not exists oyun.mulk_ilan (
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 satici uuid not null references oyun.profiller(id),
 alici uuid references oyun.profiller(id),
 fiyat numeric(16,2) not null check(fiyat between 10000 and 100000000),
 durum text not null default 'acik' check(durum in ('acik','satildi','iptal')),
 olusturma timestamptz not null default now(), kapanma timestamptz
);
create unique index if not exists mulk_ilan_tek_acik on oyun.mulk_ilan(mulk_id) where durum='acik';
create index if not exists mulk_ilan_liste on oyun.mulk_ilan(durum,olusturma desc);
alter table oyun.mulk_ilan enable row level security;
revoke all on oyun.mulk_ilan from public,anon,authenticated;

create or replace function public.mulk_pazar()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('ilanlar',coalesce((select jsonb_agg(to_jsonb(q) order by q.id desc) from
   (select a.id,a.mulk_id,a.fiyat,(a.satici=auth.uid()) as benim,
           p.kad as satici,m.tip,i.ad as il,m.haftalik_kira as haftalik,m.alis_bedeli as eski_alis
    from oyun.mulk_ilan a join oyun.profiller p on p.id=a.satici
    join oyun.yatirim_mulkleri m on m.id=a.mulk_id join oyun.iller i on i.id=m.il_id
    where a.durum='acik' order by a.id desc limit 100) q),'[]'::jsonb));
end $$;

create or replace function public.mulk_ilan_ver(p_mulk bigint,p_fiyat numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); m oyun.yatirim_mulkleri%rowtype;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_fiyat is null or p_fiyat<10000 or p_fiyat>100000000 or p_fiyat<>trunc(p_fiyat) then raise exception 'Fiyat 10.000 - 100.000.000 ₺ arasında tam sayı olmalı'; end if;
 select * into m from oyun.yatirim_mulkleri where id=p_mulk and user_id=u for update;
 if not found then raise exception 'Mülk sana ait değil'; end if;
 if exists(select 1 from oyun.mulk_ilan where mulk_id=p_mulk and durum='acik') then raise exception 'Mülk zaten satışta'; end if;
 insert into oyun.mulk_ilan(mulk_id,satici,fiyat) values(m.id,u,p_fiyat);
 return public.mulk_pazar();
end $$;

create or replace function public.mulk_ilan_iptal(p_ilan bigint)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
 update oyun.mulk_ilan set durum='iptal',kapanma=now() where id=p_ilan and satici=auth.uid() and durum='acik';
 if not found then raise exception 'Açık satış ilanın bulunamadı'; end if;
 return public.mulk_pazar();
end $$;

create or replace function public.mulk_ilan_satin_al(p_ilan bigint)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); a oyun.mulk_ilan%rowtype; m oyun.yatirim_mulkleri%rowtype;
 vergi numeric; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 select * into a from oyun.mulk_ilan where id=p_ilan for update;
 if not found or a.durum<>'acik' then raise exception 'İlan artık açık değil'; end if;
 if a.satici=u then raise exception 'Kendi mülkünü satın alamazsın'; end if;
 select * into m from oyun.yatirim_mulkleri where id=a.mulk_id for update;
 if not found or m.user_id<>a.satici then raise exception 'Satıcı artık mülkün sahibi değil'; end if;
 perform oyun.mulk_kira_tahsil(a.satici);
 vergi:=round(a.fiyat*0.02);
 perform oyun.para_islem(u,-a.fiyat,'emlak','Oyuncudan mülk satın alındı #'||a.mulk_id,t);
 perform oyun.para_islem(a.satici,a.fiyat-vergi,'emlak','Mülk satışı #'||a.mulk_id,t);
 update oyun.ulke set hazine=hazine+vergi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=u,satin_alma=t,alis_bedeli=a.fiyat,
   sonraki_kira=t+interval '7 days',toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=u,kapanma=t where id=a.id;
 perform oyun.bildir(a.satici,'Satıştaki mülkün satıldı. Satış vergisi %2.',t);
 return public.mulk_pazar();
end $$;
revoke all on function public.mulk_pazar(),public.mulk_ilan_ver(bigint,numeric),
 public.mulk_ilan_iptal(bigint),public.mulk_ilan_satin_al(bigint) from public,anon;
grant execute on function public.mulk_pazar(),public.mulk_ilan_ver(bigint,numeric),
 public.mulk_ilan_iptal(bigint),public.mulk_ilan_satin_al(bigint) to authenticated;
