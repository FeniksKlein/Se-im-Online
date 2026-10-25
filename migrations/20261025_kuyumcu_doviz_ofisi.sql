
-- 2026-10-25 | Kuyumcu ve doviz burosu; mevcut oyun bakiyeleri degismez.
create table if not exists oyun.meslek_kur(
 kod text primary key check(kod in ('USD','EUR','GBP','CHF','ALTIN')),
 fiyat numeric(22,8) not null check(fiyat>0),
 kaynak text not null,
 veri_tarihi timestamptz not null,
 guncelleme timestamptz not null default now()
);
create table if not exists oyun.meslek_dukkan(
 id bigint generated always as identity primary key,
 sahibi uuid not null references auth.users(id),
 tur text not null check(tur in ('doviz','kuyumcu')),
 ad text not null check(length(ad) between 3 and 60),
 il_id smallint,
 kasa numeric(24,2) not null default 0 check(kasa>=0),
 makas numeric(6,3) not null default 1 check(makas between 0.25 and 6),
 aktif boolean not null default true,
 acilis timestamptz not null default now(),
 unique(sahibi,tur)
);
create table if not exists oyun.meslek_stok(
 dukkan_id bigint not null references oyun.meslek_dukkan(id),
 kod text not null check(kod in ('USD','EUR','GBP','CHF','ALTIN')),
 miktar numeric(24,4) not null default 0 check(miktar>=0),
 primary key(dukkan_id,kod)
);
create table if not exists oyun.meslek_portfoy(
 user_id uuid not null references auth.users(id),
 kod text not null check(kod in ('USD','EUR','GBP','CHF','ALTIN')),
 miktar numeric(24,4) not null default 0 check(miktar>=0),
 primary key(user_id,kod)
);
create table if not exists oyun.meslek_islemler(
 id bigint generated always as identity primary key,
 dukkan_id bigint not null references oyun.meslek_dukkan(id),
 user_id uuid not null references auth.users(id),
 kod text not null,
 yon text not null check(yon in ('al','sat','tedarik')),
 miktar numeric(24,4) not null check(miktar>0),
 birim_fiyat numeric(22,8) not null,
 tutar numeric(24,2) not null,
 tarih timestamptz not null default now()
);
create index if not exists meslek_islem_dukkan on oyun.meslek_islemler(dukkan_id,tarih desc);
create index if not exists meslek_islem_user on oyun.meslek_islemler(user_id,tarih desc);
do $z$ declare t text; begin
 foreach t in array array['meslek_kur','meslek_dukkan','meslek_stok','meslek_portfoy','meslek_islemler'] loop
  execute format('alter table oyun.%I enable row level security',t);
  execute format('revoke all on table oyun.%I from public,anon,authenticated',t);
 end loop;
end $z$;

-- Yalniz Edge Function sunucu anahtari bu RPC ile fiyat gunceller.
create or replace function public.meslek_kur_kaydet(p_kod text,p_fiyat numeric,p_kaynak text,p_veri_tarihi timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'Yetkisiz kur guncellemesi'; end if;
 if p_kod not in ('USD','EUR','GBP','CHF','ALTIN') or p_fiyat is null or p_fiyat<=0 or p_fiyat>100000000
  or p_kaynak not in ('TCMB','Gold-API/TCMB') or p_veri_tarihi is null
  or p_veri_tarihi>now()+interval '10 minutes' then raise exception 'Gecersiz piyasa verisi';end if;
 insert into oyun.meslek_kur(kod,fiyat,kaynak,veri_tarihi,guncelleme)
 values(p_kod,round(p_fiyat,8),p_kaynak,p_veri_tarihi,now())
 on conflict(kod) do update set fiyat=excluded.fiyat,kaynak=excluded.kaynak,
 veri_tarihi=excluded.veri_tarihi,guncelleme=now();
 return jsonb_build_object('kod',p_kod,'ok',true);
end; $$;
revoke all on function public.meslek_kur_kaydet(text,numeric,text,timestamptz) from public,anon,authenticated;
grant execute on function public.meslek_kur_kaydet(text,numeric,text,timestamptz) to service_role;

create or replace function oyun.meslek_kur_kontrol(p_kod text)
returns numeric language plpgsql stable set search_path='' as $$
declare r record;
begin
 select fiyat,guncelleme into r from oyun.meslek_kur where kod=p_kod;
 if not found then raise exception 'Piyasa kuru henuz baglanmadi. Kur guncelle butonunu kullan.';end if;
 if r.guncelleme<now()-interval '20 minutes' then raise exception 'Piyasa kuru eski. Islemden once kuru yenile.';end if;
 return r.fiyat;
end; $$;

create or replace function public.meslek_panel()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oturum gerekli';end if;
 select para into c from oyun.cuzdan where user_id=u;
 return jsonb_build_object(
  'cuzdan',coalesce(c,0),
  'kurlar',coalesce((select jsonb_agg(jsonb_build_object('kod',kod,'fiyat',fiyat,'kaynak',kaynak,'veri_tarihi',veri_tarihi,'guncelleme',guncelleme) order by kod) from oyun.meslek_kur),'[]'::jsonb),
  'dukkanlar',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'ad',d.ad,'tur',d.tur,'il_id',d.il_id,'makas',d.makas,'benim',d.sahibi=u,'kasa',case when d.sahibi=u then d.kasa else null end,'stok',(select coalesce(jsonb_object_agg(st.kod,st.miktar),'{}'::jsonb) from oyun.meslek_stok st where st.dukkan_id=d.id)) order by d.id desc) from oyun.meslek_dukkan d where d.aktif),'[]'::jsonb),
  'portfoy',coalesce((select jsonb_object_agg(kod,miktar) from oyun.meslek_portfoy where user_id=u),'{}'::jsonb),
  'islemler',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'dukkan_id',q.dukkan_id,'kod',q.kod,'yon',q.yon,'tutar',q.tutar,'miktar',q.miktar,'tarih',q.tarih)) from (select * from oyun.meslek_islemler where user_id=u or dukkan_id in(select id from oyun.meslek_dukkan where sahibi=u) order by tarih desc limit 30) q),'[]'::jsonb));
end; $$;
revoke all on function public.meslek_panel() from public,anon;
grant execute on function public.meslek_panel() to authenticated;

create or replace function public.meslek_dukkan_ac(p_tur text,p_ad text,p_sermaye numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); il smallint; did bigint; bedel numeric:=5000;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris gerekli';end if;
 if p_tur not in ('doviz','kuyumcu') or p_ad is null or length(btrim(p_ad)) not between 3 and 60 then raise exception 'Dukkan turu veya adi gecersiz';end if;
 if p_sermaye is null or p_sermaye<>trunc(p_sermaye) or p_sermaye<100000 or p_sermaye>100000000 then raise exception 'Sermaye 100.000 ile 100.000.000 TL arasinda tam sayi olmali';end if;
 if exists(select 1 from oyun.meslek_dukkan where sahibi=u and tur=p_tur) then raise exception 'Bu turde zaten dukkanin var';end if;
 perform oyun.para_islem(u,-p_sermaye,'meslek','Dukkan acma ve sermaye: '||p_ad,now());
 select il_id into il from oyun.profiller where id=u;
 insert into oyun.meslek_dukkan(sahibi,tur,ad,il_id,kasa,makas) values(u,p_tur,btrim(p_ad),il,p_sermaye-bedel,case when p_tur='doviz' then 0.7 else 1.5 end) returning id into did;
 update oyun.ulke set hazine=hazine+bedel/oyun.pazar_tl_milyar() where id=1;
 return jsonb_build_object('id',did,'kasa',p_sermaye-bedel,'ruhsat',bedel);
end; $$;
revoke all on function public.meslek_dukkan_ac(text,text,numeric) from public,anon;
grant execute on function public.meslek_dukkan_ac(text,text,numeric) to authenticated;

create or replace function public.meslek_makas_ayarla(p_dukkan bigint,p_makas numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d oyun.meslek_dukkan%rowtype;
begin
 select * into d from oyun.meslek_dukkan where id=p_dukkan and sahibi=auth.uid() for update;
 if not found then raise exception 'Bu dukkan sana ait degil';end if;
 if p_makas is null or p_makas<0.25 or p_makas>6 then raise exception 'Gecersiz makas orani';end if;
 if (d.tur='doviz' and p_makas>3) or (d.tur='kuyumcu' and p_makas<0.5) then raise exception 'Bu dukkan icin makas siniri disinda';end if;
 update oyun.meslek_dukkan set makas=round(p_makas,3) where id=p_dukkan;
 return jsonb_build_object('makas',round(p_makas,3));
end; $$;
revoke all on function public.meslek_makas_ayarla(bigint,numeric) from public,anon;
grant execute on function public.meslek_makas_ayarla(bigint,numeric) to authenticated;

create or replace function public.meslek_kasa(p_dukkan bigint,p_yon text,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d oyun.meslek_dukkan%rowtype;
begin
 if p_yon not in ('yatir','cek') or p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<100 or p_tutar>100000000 then raise exception 'Gecersiz kasa islemi';end if;
 select * into d from oyun.meslek_dukkan where id=p_dukkan and sahibi=auth.uid() and aktif for update;
 if not found then raise exception 'Dukkan yetkin yok';end if;
 if p_yon='yatir' then
  perform oyun.para_islem(auth.uid(),-p_tutar,'meslek','Dukkan kasasina sermaye',now());
  update oyun.meslek_dukkan set kasa=kasa+p_tutar where id=d.id;
 else
  if d.kasa<p_tutar then raise exception 'Kasada yeterli para yok';end if;
  update oyun.meslek_dukkan set kasa=kasa-p_tutar where id=d.id;
  perform oyun.para_islem(auth.uid(),p_tutar,'meslek','Dukkan kasasindan aktarim',now());
 end if;
 return jsonb_build_object('kasa',(select kasa from oyun.meslek_dukkan where id=d.id));
end; $$;
revoke all on function public.meslek_kasa(bigint,text,numeric) from public,anon;
grant execute on function public.meslek_kasa(bigint,text,numeric) to authenticated;

create or replace function public.meslek_stok_tedarik(p_dukkan bigint,p_kod text,p_miktar numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d oyun.meslek_dukkan%rowtype; fiyat numeric; tutar numeric;
begin
 if p_miktar is null or p_miktar<=0 or p_miktar>100000 or p_miktar<>round(p_miktar,4) then raise exception 'Miktar 0-100.000 arasinda, en cok 4 ondalik olmali';end if;
 select * into d from oyun.meslek_dukkan where id=p_dukkan and sahibi=auth.uid() and aktif for update;
 if not found then raise exception 'Dukkan yetkin yok';end if;
 if not ((d.tur='doviz' and p_kod in ('USD','EUR','GBP','CHF')) or (d.tur='kuyumcu' and p_kod='ALTIN')) then raise exception 'Bu urun dukkaninda satilamaz';end if;
 fiyat:=oyun.meslek_kur_kontrol(p_kod);
 tutar:=ceil(p_miktar*fiyat*1.001);
 if d.kasa<tutar then raise exception 'Tedarik icin dukkan kasasinda % TL olmali',tutar;end if;
 update oyun.meslek_dukkan set kasa=kasa-tutar where id=d.id;
 insert into oyun.meslek_stok(dukkan_id,kod,miktar) values(d.id,p_kod,p_miktar)
 on conflict(dukkan_id,kod) do update set miktar=oyun.meslek_stok.miktar+excluded.miktar;
 insert into oyun.meslek_islemler(dukkan_id,user_id,kod,yon,miktar,birim_fiyat,tutar) values(d.id,auth.uid(),p_kod,'tedarik',p_miktar,fiyat,tutar);
 return jsonb_build_object('stok',p_miktar,'odenen',tutar);
end; $$;
revoke all on function public.meslek_stok_tedarik(bigint,text,numeric) from public,anon;
grant execute on function public.meslek_stok_tedarik(bigint,text,numeric) to authenticated;

create or replace function public.meslek_ticaret(p_dukkan bigint,p_kod text,p_yon text,p_miktar numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d oyun.meslek_dukkan%rowtype; fiyat numeric; birim numeric; tutar numeric; mevcut numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris gerekli';end if;
 if p_yon not in ('al','sat') or p_miktar is null or p_miktar<=0 or p_miktar>100000 or p_miktar<>round(p_miktar,4) then raise exception 'Gecersiz islem miktari';end if;
 select * into d from oyun.meslek_dukkan where id=p_dukkan and aktif for update;
 if not found then raise exception 'Dukkan bulunamadi';end if;
 if d.sahibi=u then raise exception 'Kendi dukkanindan kendine alis-satis yapamazsin';end if;
 if not ((d.tur='doviz' and p_kod in ('USD','EUR','GBP','CHF')) or (d.tur='kuyumcu' and p_kod='ALTIN')) then raise exception 'Urun bu dukkanda islem gormuyor';end if;
 fiyat:=oyun.meslek_kur_kontrol(p_kod);
 birim:=round(fiyat*(case when p_yon='al' then 1+d.makas/100 else 1-d.makas/100 end),8);
 tutar:=case when p_yon='al' then ceil(birim*p_miktar) else floor(birim*p_miktar) end;
 if tutar<100 then raise exception 'Islem tutari en az 100 TL olmali';end if;
 insert into oyun.meslek_stok(dukkan_id,kod,miktar) values(d.id,p_kod,0) on conflict do nothing;
 insert into oyun.meslek_portfoy(user_id,kod,miktar) values(u,p_kod,0) on conflict do nothing;
 select miktar into mevcut from oyun.meslek_stok where dukkan_id=d.id and kod=p_kod for update;
 perform 1 from oyun.meslek_portfoy where user_id=u and kod=p_kod for update;
 if p_yon='al' then
  if mevcut<p_miktar then raise exception 'Dukkanda yeterli stok yok';end if;
  perform oyun.para_islem(u,-tutar,'meslek','Dukkandan '||p_kod||' alimi',now());
  update oyun.meslek_stok set miktar=miktar-p_miktar where dukkan_id=d.id and kod=p_kod;
  update oyun.meslek_portfoy set miktar=miktar+p_miktar where user_id=u and kod=p_kod;
  update oyun.meslek_dukkan set kasa=kasa+tutar where id=d.id;
 else
  if (select miktar from oyun.meslek_portfoy where user_id=u and kod=p_kod)<p_miktar then raise exception 'Portfoyunde yeterli varlik yok';end if;
  if d.kasa<tutar then raise exception 'Dukkan kasasi bu alim icin yetersiz';end if;
  update oyun.meslek_portfoy set miktar=miktar-p_miktar where user_id=u and kod=p_kod;
  update oyun.meslek_stok set miktar=miktar+p_miktar where dukkan_id=d.id and kod=p_kod;
  update oyun.meslek_dukkan set kasa=kasa-tutar where id=d.id;
  perform oyun.para_islem(u,tutar,'meslek','Dukkana '||p_kod||' satisi',now());
 end if;
 insert into oyun.meslek_islemler(dukkan_id,user_id,kod,yon,miktar,birim_fiyat,tutar) values(d.id,u,p_kod,p_yon,p_miktar,birim,tutar);
 return jsonb_build_object('yon',p_yon,'kod',p_kod,'miktar',p_miktar,'birim',birim,'tutar',tutar,'dukkan',d.ad);
end; $$;
revoke all on function public.meslek_ticaret(bigint,text,text,numeric) from public,anon;
grant execute on function public.meslek_ticaret(bigint,text,text,numeric) to authenticated;
