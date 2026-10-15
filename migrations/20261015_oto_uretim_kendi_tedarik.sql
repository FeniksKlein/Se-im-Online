-- Automatic factory production, same-owner factory-to-market purchasing, and NPC store-sale toggle.
-- Server deployment: 2026-10-15, source-of-truth migration for rebuilds.
-- Existing players, stock, money, permissions and earlier automations are preserved.
alter table oyun.eko_isletmeler add column if not exists satis_aktif boolean not null default true;

create table if not exists oyun.eko_otomatik_uretim(
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.eko_urun_katalog(kod),
 esik integer not null check(esik between 0 and 5000),
 miktar integer not null check(miktar between 1 and 500),
 gunluk_butce numeric not null check(gunluk_butce between 100 and 100000000),
 aktif boolean not null default true,
 son_deneme timestamptz,
 son_islem timestamptz,
 son_hata text,
 guncelleme timestamptz not null default now(),
 primary key(sirket_id,urun)
);
create table if not exists oyun.eko_otomatik_kendi_tedarik(
 magaza_id bigint not null references oyun.sirketler(id),
 fabrika_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.eko_urun_katalog(kod),
 esik integer not null check(esik between 0 and 5000),
 miktar integer not null check(miktar between 1 and 500),
 azami_birim_fiyat numeric not null check(azami_birim_fiyat>0),
 aktif boolean not null default true,
 son_deneme timestamptz,
 son_islem timestamptz,
 son_hata text,
 guncelleme timestamptz not null default now(),
 primary key(magaza_id,fabrika_id,urun),
 check(magaza_id<>fabrika_id)
);
create index if not exists eko_auto_uretim_aktif_idx on oyun.eko_otomatik_uretim(aktif) where aktif;
create index if not exists eko_auto_kendi_aktif_idx on oyun.eko_otomatik_kendi_tedarik(aktif) where aktif;
revoke all on oyun.eko_otomatik_uretim,oyun.eko_otomatik_kendi_tedarik from public,anon,authenticated;
alter table oyun.eko_otomatik_uretim enable row level security;
alter table oyun.eko_otomatik_kendi_tedarik enable row level security;

-- oyun.eko_otomasyon_tick
CREATE OR REPLACE FUNCTION oyun.eko_otomasyon_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 t timestamptz:=oyun.simdi();
 a record; k oyun.eko_urun_katalog;
 v_stok integer;v_hazir integer;v_miktar integer;v_tutar numeric;v_gunluk numeric;
 v_kapasite numeric;v_siparis integer;v_fiyat numeric;v_kasa numeric;
 v_uretilen integer:=0;v_tedarik integer:=0;v_hata integer:=0;
begin
 if not pg_try_advisory_xact_lock(424262) then return jsonb_build_object('kilitli',true);end if;
 -- Factory production: one active pending batch/product and at most one start per hour.
 for a in
  select o.* from oyun.eko_otomatik_uretim o
  join oyun.sirketler s on s.id=o.sirket_id and s.aktif
  join oyun.eko_isletmeler i on i.sirket_id=o.sirket_id and i.tur='fabrika'
  where o.aktif and (o.son_deneme is null or o.son_deneme<t-interval '1 hour')
  order by o.sirket_id,o.urun limit 250
  for update of o skip locked
 loop
  begin
   select * into k from oyun.eko_urun_katalog where kod=a.urun and aktif;
   if k.kod is null or not exists(select 1 from oyun.eko_isletmeler where sirket_id=a.sirket_id and urun=k.grup and tur='fabrika') then continue;end if;
   select coalesce(sum(adet),0)::int into v_hazir from oyun.eko_uretim_emir
    where sirket_id=a.sirket_id and urun=a.urun and tamamlandi is null;
   if v_hazir>0 then continue;end if;
   select coalesce(adet,0) into v_stok from oyun.eko_urun_stok
    where sirket_id=a.sirket_id and urun=a.urun;
   if coalesce(v_stok,0)>a.esik then continue;end if;
   -- Attempt cooldown prevents repeated empty-cash loops or runaway orders.
   update oyun.eko_otomatik_uretim set son_deneme=t where sirket_id=a.sirket_id and urun=a.urun;
   v_kapasite:=coalesce((oyun.eko_fabrika_kapasite(a.sirket_id)->>'katsayi')::numeric,1);
   v_miktar:=least(a.miktar,500,ceil(k.parti_ust*greatest(1,least(10,v_kapasite)))::integer);
   v_tutar:=round(k.maliyet*v_miktar);
   select coalesce(sum(toplam_maliyet),0) into v_gunluk from oyun.eko_uretim_emir
    where sirket_id=a.sirket_id and baslangic>=(t at time zone 'Europe/Istanbul')::date at time zone 'Europe/Istanbul'
     and baslangic<((t at time zone 'Europe/Istanbul')::date+1) at time zone 'Europe/Istanbul';
   if v_tutar+v_gunluk>a.gunluk_butce then
     update oyun.eko_otomatik_uretim set son_hata='Gunluk uretim butcesi doldu.' where sirket_id=a.sirket_id and urun=a.urun;
     continue;
   end if;
   update oyun.sirketler set kasa=kasa-v_tutar
    where id=a.sirket_id and kasa>=v_tutar;
   if not found then
     update oyun.eko_otomatik_uretim set son_hata='Fabrika kasasi yetersiz.' where sirket_id=a.sirket_id and urun=a.urun;
     continue;
   end if;
   insert into oyun.eko_uretim_emir(sirket_id,urun,adet,toplam_maliyet,baslangic,hazir,kaynak)
   values(a.sirket_id,a.urun,v_miktar,v_tutar,t,t+make_interval(mins=>k.uretim_dakika),'fabrika');
   insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
   values(a.sirket_id,null,'urun_uretim',-v_tutar,format('Otomatik: %s adet %s uretildi',v_miktar,k.ad));
   update oyun.eko_otomatik_uretim set son_islem=t,son_hata=null where sirket_id=a.sirket_id and urun=a.urun;
   v_uretilen:=v_uretilen+1;
  exception when others then
   v_hata:=v_hata+1;
   update oyun.eko_otomatik_uretim set son_deneme=t,son_hata=left(sqlerrm,250)
    where sirket_id=a.sirket_id and urun=a.urun;
  end;
 end loop;
 -- Replenishment only from factory owned/managed by same player. No phantom stock.
 for a in
  select o.* from oyun.eko_otomatik_kendi_tedarik o
  join oyun.sirketler s on s.id=o.magaza_id and s.aktif
  join oyun.sirketler f on f.id=o.fabrika_id and f.aktif
  where o.aktif and (o.son_deneme is null or o.son_deneme<t-interval '1 hour')
  order by o.magaza_id,o.urun,o.fabrika_id limit 250
  for update of o skip locked
 loop
  begin
   if not exists(
    select 1 from oyun.sirket_ortaklari z
    where z.sirket_id=a.magaza_id
     and oyun.sirket_yonetici_mi(a.magaza_id,z.user_id)
     and oyun.sirket_yonetici_mi(a.fabrika_id,z.user_id)
   ) or not exists(select 1 from oyun.eko_isletmeler where sirket_id=a.magaza_id and tur='magaza')
   or not exists(select 1 from oyun.eko_isletmeler where sirket_id=a.fabrika_id and tur='fabrika')
   then
    update oyun.eko_otomatik_kendi_tedarik set aktif=false,son_hata='Ortak yonetim veya faaliyet durumu degisti.'
    where magaza_id=a.magaza_id and fabrika_id=a.fabrika_id and urun=a.urun;
    continue;
   end if;
   select coalesce(adet,0) into v_stok from oyun.eko_urun_stok
    where sirket_id=a.magaza_id and urun=a.urun;
   if coalesce(v_stok,0)>a.esik then continue;end if;
   select adet,satis_fiyati into v_hazir,v_fiyat from oyun.eko_urun_stok
    where sirket_id=a.fabrika_id and urun=a.urun;
   if coalesce(v_hazir,0)<=0 then continue;end if;
   if v_fiyat<=0 or v_fiyat>a.azami_birim_fiyat then
    update oyun.eko_otomatik_kendi_tedarik set son_hata='Fabrika satis fiyati belirlenen ust limiti asti.'
     where magaza_id=a.magaza_id and fabrika_id=a.fabrika_id and urun=a.urun;
    continue;
   end if;
   update oyun.eko_otomatik_kendi_tedarik set son_deneme=t
    where magaza_id=a.magaza_id and fabrika_id=a.fabrika_id and urun=a.urun;
   select kasa into v_kasa from oyun.sirketler where id=a.magaza_id;
   v_siparis:=least(a.miktar,500,coalesce(v_hazir,0),floor(greatest(0,v_kasa)/v_fiyat)::int);
   if v_siparis<=0 then
    update oyun.eko_otomatik_kendi_tedarik set son_hata='Market kasasi yetersiz.'
     where magaza_id=a.magaza_id and fabrika_id=a.fabrika_id and urun=a.urun;
    continue;
   end if;
   perform oyun.eko_urun_toptan(a.magaza_id,a.fabrika_id,a.urun,v_siparis,null);
   update oyun.eko_otomatik_kendi_tedarik set son_islem=t,son_hata=null
    where magaza_id=a.magaza_id and fabrika_id=a.fabrika_id and urun=a.urun;
   v_tedarik:=v_tedarik+1;
  exception when others then
   v_hata:=v_hata+1;
   update oyun.eko_otomatik_kendi_tedarik set son_deneme=t,son_hata=left(sqlerrm,250)
    where magaza_id=a.magaza_id and fabrika_id=a.fabrika_id and urun=a.urun;
  end;
 end loop;
 return jsonb_build_object('uretim_emri',v_uretilen,'kendi_tedarik',v_tedarik,'hata',v_hata);
end $function$


-- public.eko_otomasyon_ayarla
CREATE OR REPLACE FUNCTION public.eko_otomasyon_ayarla(p_eylem text, p_veri jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 u uuid:=auth.uid();
 sid bigint:=nullif(p_veri->>'sirket','')::bigint;
 fid bigint:=nullif(p_veri->>'fabrika','')::bigint;
 ur text:=p_veri->>'urun';
 v_esik int:=coalesce((p_veri->>'esik')::int,0);
 v_miktar int:=coalesce((p_veri->>'adet')::int,0);
 v_butce numeric:=coalesce((p_veri->>'butce')::numeric,0);
 v_ust numeric:=coalesce((p_veri->>'ust')::numeric,0);
 v_aktif boolean:=coalesce((p_veri->>'aktif')::boolean,true);
 k oyun.eko_urun_katalog; e oyun.eko_isletmeler;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli)
 then raise exception 'Giris yapmalisin.'; end if;
 if p_veri is null or jsonb_typeof(p_veri)<>'object'
 then raise exception 'Gecersiz veri.'; end if;
 if sid is null or not exists(select 1 from oyun.sirketler where id=sid and aktif)
 or not oyun.sirket_yonetici_mi(sid,u) then
 raise exception 'Sirketi yonetme yetkin yok.';end if;

 if p_eylem='satis' then
  update oyun.eko_isletmeler set satis_aktif=v_aktif
  where sirket_id=sid and tur='magaza';
  if not found then raise exception 'Magaza bulunamadi.';end if;
  return jsonb_build_object('aktif',v_aktif);
 end if;
 if p_eylem not in ('uretim','kendi') then raise exception 'Bilinmeyen otomasyon.';end if;
 select * into k from oyun.eko_urun_katalog where kod=ur and aktif;
 if k.kod is null then raise exception 'Urun bulunamadi.';end if;
 if p_eylem='uretim' then
  select * into e from oyun.eko_isletmeler where sirket_id=sid and tur='fabrika';
  if e.sirket_id is null or e.urun<>k.grup then raise exception 'Fabrika bu urunu uretemez.';end if;
  if not v_aktif then
   update oyun.eko_otomatik_uretim set aktif=false,guncelleme=now() where sirket_id=sid and urun=ur;
   return jsonb_build_object('aktif',false);
  end if;
  if v_esik not between 0 and 5000 or v_miktar not between 1 and 500
   or v_butce not between 100 and 100000000 or v_butce<round(k.maliyet*v_miktar)
  then raise exception 'Uretim esigi, parti veya gunluk butce gecersiz.';end if;
  insert into oyun.eko_otomatik_uretim(sirket_id,urun,esik,miktar,gunluk_butce,aktif,son_deneme,son_hata)
  values(sid,ur,v_esik,v_miktar,v_butce,true,null,null)
  on conflict(sirket_id,urun) do update set esik=excluded.esik,miktar=excluded.miktar,
   gunluk_butce=excluded.gunluk_butce,aktif=true,son_hata=null,guncelleme=now();
  return jsonb_build_object('aktif',true,'tur','uretim');
 end if;
 -- Own-factory supply is *not* free inventory: uses real wholesale trade accounting.
 if fid is null or fid=sid or not oyun.sirket_yonetici_mi(fid,u)
 or not exists(select 1 from oyun.sirketler where id=fid and aktif)
 or not exists(select 1 from oyun.eko_isletmeler where sirket_id=sid and tur='magaza')
 or not exists(select 1 from oyun.eko_isletmeler where sirket_id=fid and tur='fabrika' and urun=k.grup)
 then raise exception 'Her iki sirketi de yonetmeli ve uygun fabrika secmelisin.';end if;
 if not v_aktif then
  update oyun.eko_otomatik_kendi_tedarik set aktif=false,guncelleme=now()
  where magaza_id=sid and fabrika_id=fid and urun=ur;
  return jsonb_build_object('aktif',false);
 end if;
 if v_esik not between 0 and 5000 or v_miktar not between 1 and 500
   or v_ust < k.maliyet or v_ust > k.onerilen_satis*3
 then raise exception 'Tedarik esigi, adet veya fiyat limiti gecersiz.';end if;
 insert into oyun.eko_otomatik_kendi_tedarik(
 magaza_id,fabrika_id,urun,esik,miktar,azami_birim_fiyat,aktif,son_deneme,son_hata)
 values(sid,fid,ur,v_esik,v_miktar,v_ust,true,null,null)
 on conflict(magaza_id,fabrika_id,urun) do update set
 esik=excluded.esik,miktar=excluded.miktar,
 azami_birim_fiyat=excluded.azami_birim_fiyat,aktif=true,son_hata=null,guncelleme=now();
 return jsonb_build_object('aktif',true,'tur','kendi');
end $function$


-- public.eko_otomasyon_panel
CREATE OR REPLACE FUNCTION public.eko_otomasyon_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli)
 then raise exception 'Giris yapmalisin.'; end if;
 return jsonb_build_object(
 'uretim',coalesce((select jsonb_agg(jsonb_build_object(
 'sirket',a.sirket_id,'urun',a.urun,'esik',a.esik,'miktar',a.miktar,
 'gunluk_butce',a.gunluk_butce,'aktif',a.aktif,'son_islem',a.son_islem,
 'son_hata',a.son_hata))
 from oyun.eko_otomatik_uretim a
 where oyun.sirket_yonetici_mi(a.sirket_id,u)),'[]'::jsonb),
 'kendi',coalesce((select jsonb_agg(jsonb_build_object(
 'magaza',a.magaza_id,'fabrika',a.fabrika_id,'urun',a.urun,
 'esik',a.esik,'miktar',a.miktar,'ust',a.azami_birim_fiyat,
 'aktif',a.aktif,'son_islem',a.son_islem,'son_hata',a.son_hata))
 from oyun.eko_otomatik_kendi_tedarik a
 where oyun.sirket_yonetici_mi(a.magaza_id,u) and oyun.sirket_yonetici_mi(a.fabrika_id,u)),'[]'::jsonb),
 'satis',coalesce((select jsonb_agg(jsonb_build_object(
 'sirket',i.sirket_id,'aktif',i.satis_aktif,
 'son_kontrol',i.son_perakende))
 from oyun.eko_isletmeler i join oyun.sirketler s on s.id=i.sirket_id and s.aktif
 where i.tur='magaza' and oyun.sirket_yonetici_mi(i.sirket_id,u)),'[]'::jsonb)
 );
end $function$



-- Execute privileges for authenticated players only; scheduler remains internal.
revoke all on function public.eko_otomasyon_panel() from public,anon;
grant execute on function public.eko_otomasyon_panel() to authenticated;
revoke all on function public.eko_otomasyon_ayarla(text,jsonb) from public,anon;
grant execute on function public.eko_otomasyon_ayarla(text,jsonb) to authenticated;
revoke all on function oyun.eko_otomasyon_tick() from public,anon,authenticated;

-- Preserve existing hourly demand/price/tax code. Only add the sales toggle predicate.
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('oyun.eko_ticaret_tick()'::regprocedure);
 if position('ei.tur=''magaza'' and ei.satis_aktif and ei.son_perakende' in d)>0 then return; end if;
 if position('ei.tur=''magaza'' and ei.son_perakende' in d)=0
 then raise exception 'Expected NPC sales function missing'; end if;
 d:=replace(d,'ei.tur=''magaza'' and ei.son_perakende','ei.tur=''magaza'' and ei.satis_aktif and ei.son_perakende');
 execute d;
end $patch$;

do $schedule$
begin
 if not exists(select 1 from cron.job where jobname='eko_otomatik_uretim_kendi_tedarik') then
  perform cron.schedule('eko_otomatik_uretim_kendi_tedarik','*/10 * * * *',
   'select oyun.eko_otomasyon_tick()');
 end if;
end $schedule$;
