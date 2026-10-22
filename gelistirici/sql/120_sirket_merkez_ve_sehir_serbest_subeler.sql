
-- Her sektorde serbest merkez ili ve il bazli sube kaydi
create table if not exists oyun.sirket_merkezleri (
  sirket_id bigint primary key references oyun.sirketler(id) on delete cascade,
  il_id smallint not null references oyun.iller(id),
  kayit timestamptz not null default now()
);
create table if not exists oyun.sirket_il_subeleri (
  id bigint generated always as identity primary key,
  sirket_id bigint not null references oyun.sirketler(id) on delete cascade,
  il_id smallint not null references oyun.iller(id),
  acilis timestamptz not null default now(),
  unique (sirket_id, il_id)
);
alter table oyun.sirket_merkezleri enable row level security;
alter table oyun.sirket_il_subeleri enable row level security;
revoke all on oyun.sirket_merkezleri from public, anon, authenticated;
revoke all on oyun.sirket_il_subeleri from public, anon, authenticated;

create or replace function public.sirket_kur_ilde(p_ad text,p_sektor text,p_sermaye numeric,p_il integer)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v jsonb; sid bigint;
begin
 if auth.uid() is null then raise exception 'Oturum acmalisin.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Gecerli bir il sec.';end if;
 v := public.sirket_kur(p_ad,p_sektor,p_sermaye);
 sid := (v->>'id')::bigint;
 insert into oyun.sirket_merkezleri(sirket_id,il_id) values(sid,p_il::smallint);
 update oyun.eko_isletmeler set il_id=p_il::smallint where sirket_id=sid;
 return v || jsonb_build_object('il_id',p_il);
end $$;

create or replace function public.sirket_kur_aktif_ilde(p_ad text,p_sektor text,p_sermaye numeric,p_urun text,p_il integer)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v jsonb; sid bigint;
begin
 if auth.uid() is null then raise exception 'Oturum acmalisin.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Gecerli bir il sec.';end if;
 v := public.sirket_kur_aktif(p_ad,p_sektor,p_sermaye,p_urun);
 sid := (v->>'id')::bigint;
 insert into oyun.sirket_merkezleri(sirket_id,il_id) values(sid,p_il::smallint);
 update oyun.eko_isletmeler set il_id=p_il::smallint where sirket_id=sid;
 return v || jsonb_build_object('il_id',p_il);
end $$;

create or replace function public.ajans_kur_ilde(p_ad text,p_sermaye numeric,p_il integer)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v jsonb;
begin
 if auth.uid() is null then raise exception 'Oturum acmalisin.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Gecerli bir il sec.';end if;
 v := public.ajans_kur(p_ad,p_sermaye);
 insert into oyun.sirket_merkezleri(sirket_id,il_id) values((v->>'id')::bigint,p_il::smallint);
 return v || jsonb_build_object('il_id',p_il);
end $$;

create or replace function public.sirket_yerleri(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare uid uuid:=auth.uid(); merkez smallint; yonetebilir boolean; sir oyun.sirketler;
begin
 if uid is null then raise exception 'Oturum acmalisin.';end if;
 select * into sir from oyun.sirketler where id=p_sirket;
 if sir.id is null or not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=p_sirket and o.user_id=uid and o.pay>0)
 then raise exception 'Bu sirketin konum bilgilerini gormeye yetkin yok.';end if;
 yonetebilir := oyun.sirket_yonetici_mi(p_sirket,uid);
 select coalesce(m.il_id,ei.il_id,ps.il_id,pr.il_id,1) into merkez
 from oyun.sirketler s
 left join oyun.sirket_merkezleri m on m.sirket_id=s.id
 left join oyun.eko_isletmeler ei on ei.sirket_id=s.id
 left join oyun.pazar_sirket ps on ps.sirket_id=s.id
 left join oyun.profiller pr on pr.id=s.kurucu
 where s.id=p_sirket;
 return jsonb_build_object(
   'merkez',jsonb_build_object('il_id',merkez,'il',(select ad from oyun.iller where id=merkez)),
   'yonetici',yonetebilir,
   'subeler',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'il_id',b.il_id,
     'il',(select ad from oyun.iller where id=b.il_id),'acilis',b.acilis) order by b.acilis desc)
     from oyun.sirket_il_subeleri b where b.sirket_id=p_sirket),'[]'::jsonb),
   'acilis_bedeli',25000
 );
end $$;

create or replace function public.sirket_sube_ac_ilde(p_sirket bigint,p_il integer)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare uid uuid:=auth.uid(); aid bigint; ilad text; bedel numeric:=25000; sir oyun.sirketler;
begin
 if uid is null then raise exception 'Oturum acmalisin.';end if;
 select ad into ilad from oyun.iller where id=p_il;
 if ilad is null then raise exception 'Gecerli bir il sec.';end if;
 select * into sir from oyun.sirketler where id=p_sirket for update;
 if sir.id is null or not sir.aktif or not oyun.sirket_yonetici_mi(p_sirket,uid)
 then raise exception 'Aktif sirketin yoneticisi olmalisin.';end if;
 if exists(select 1 from oyun.sirket_il_subeleri where sirket_id=p_sirket and il_id=p_il)
 then raise exception 'Bu ilde zaten bir suben bulunuyor.';end if;
 if sir.kasa<bedel then raise exception 'Sube acilis bedeli icin sirket kasasinda 25.000 ₺ gerekli.';end if;
 update oyun.sirketler set kasa=kasa-bedel where id=p_sirket;
 insert into oyun.sirket_il_subeleri(sirket_id,il_id) values(p_sirket,p_il::smallint) returning id into aid;
 return jsonb_build_object('id',aid,'il_id',p_il,'il',ilad,'bedel',bedel);
end $$;
revoke all on function public.sirket_kur_ilde(text,text,numeric,integer) from public,anon;
revoke all on function public.sirket_kur_aktif_ilde(text,text,numeric,text,integer) from public,anon;
revoke all on function public.ajans_kur_ilde(text,numeric,integer) from public,anon;
revoke all on function public.sirket_yerleri(bigint) from public,anon;
revoke all on function public.sirket_sube_ac_ilde(bigint,integer) from public,anon;
grant execute on function public.sirket_kur_ilde(text,text,numeric,integer) to authenticated;
grant execute on function public.sirket_kur_aktif_ilde(text,text,numeric,text,integer) to authenticated;
grant execute on function public.ajans_kur_ilde(text,numeric,integer) to authenticated;
grant execute on function public.sirket_yerleri(bigint) to authenticated;
grant execute on function public.sirket_sube_ac_ilde(bigint,integer) to authenticated;
