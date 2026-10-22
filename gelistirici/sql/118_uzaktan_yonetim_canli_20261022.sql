-- 118 · Uzaktan oyun yonetimi, canli degisiklik sinyali, guvenli moduller (2026-10-22).
-- Onceki oyuncu, para, makam, secim veya mevcut sistem verilerini SIFIRLAMAZ.
create table if not exists public.oyun_kontrol_sinyali(
 id smallint primary key default 1 check(id=1),
 rev bigint not null default 1,
 tur text not null default 'kurulum',
 zaman timestamptz not null default now()
);
insert into public.oyun_kontrol_sinyali(id,rev,tur) values(1,1,'kurulum') on conflict(id) do nothing;
alter table public.oyun_kontrol_sinyali enable row level security;
revoke all on public.oyun_kontrol_sinyali from public,anon,authenticated;
grant select on public.oyun_kontrol_sinyali to authenticated;
do $$begin
 if not exists(select 1 from pg_policies where schemaname='public'
 and tablename='oyun_kontrol_sinyali' and policyname='oyuncular_sadece_sinyali_gorur') then
  create policy oyuncular_sadece_sinyali_gorur
  on public.oyun_kontrol_sinyali for select to authenticated
  using ((select auth.uid()) is not null);
 end if;
end$$;
do $$begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
 and schemaname='public' and tablename='oyun_kontrol_sinyali') then
  alter publication supabase_realtime add table public.oyun_kontrol_sinyali;
 end if;
end$$;
create table if not exists oyun.uzaktan_modul_ayar(
 kod text primary key, ad text not null, acik boolean not null default true,
 aciklama text not null default '', guncelleme timestamptz not null default now()
);
alter table oyun.uzaktan_modul_ayar enable row level security;
revoke all on oyun.uzaktan_modul_ayar from public,anon,authenticated;
insert into oyun.uzaktan_modul_ayar(kod,ad,aciklama) values
('sirket_pazari','Şirket alım-satım pazarı','Yeni şirket ilanları ve oyuncular arasında normal şirket devri'),
('npc_isletme','NPC stoklu işletmeler','Akaryakıt istasyonu, mağaza ve galeri stok işlemleri ve otomatik NPC satışları')
on conflict(kod) do nothing;

CREATE OR REPLACE FUNCTION oyun.uzaktan_modul_acik(p_kod text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
select coalesce((select acik from oyun.uzaktan_modul_ayar where kod=p_kod),true)
$function$;

CREATE OR REPLACE FUNCTION oyun.uzaktan_sinyal_yay(p_tur text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_rev bigint;
begin
 update public.oyun_kontrol_sinyali
 set rev=rev+1,tur=left(coalesce(nullif(btrim(p_tur),''),'yonetim'),40),zaman=now()
 where id=1 returning rev into v_rev;
 return v_rev;
end$function$;

CREATE OR REPLACE FUNCTION oyun.uzaktan_sinyal_tetikle()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform oyun.uzaktan_sinyal_yay(tg_argv[0]);
 return coalesce(new,old);
end$function$;

CREATE OR REPLACE FUNCTION oyun.uzaktan_satis_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if new.satilik is not null and new.satilik is distinct from old.satilik
   and not oyun.uzaktan_modul_acik('sirket_pazari') then
   raise exception 'Şirket pazarı geçici olarak kapalı';
 end if;
 return new;
end$function$;

CREATE OR REPLACE FUNCTION oyun.uzaktan_devir_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if new.tur in ('sirket_tam','sirket_hisse')
   and not oyun.uzaktan_modul_acik('sirket_pazari') then
   raise exception 'Şirket pazarı geçici olarak kapalı';
 end if;
 return new;
end$function$;

CREATE OR REPLACE FUNCTION oyun.uzaktan_yeni_npc_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if not oyun.uzaktan_modul_acik('npc_isletme')
   and exists(select 1 from oyun.sirketler s join oyun.npc_urun_katalog u
              on s.sektor=u.sektor where s.id=new.sirket_id) then
   raise exception 'Stoklu NPC işletme kuruluşu geçici olarak kapalı';
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION oyun.uzaktan_hisse_ilan_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if not oyun.uzaktan_modul_acik('sirket_pazari') then
   raise exception 'Şirket alım-satım pazarı geçici olarak kapalı';
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.uzaktan_kontrol_durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v jsonb;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
 select jsonb_build_object(
 'rev',s.rev,'tur',s.tur,'zaman',s.zaman,
 'moduller',(select coalesce(jsonb_object_agg(kod,acik),'{}'::jsonb) from oyun.uzaktan_modul_ayar),
 'bakim',coalesce((select (deger #>> '{}')::boolean from oyun.uygulama_ayar where anahtar='bakim'),false)
 ) into v from public.oyun_kontrol_sinyali s where s.id=1;
 return v;
end$function$;

CREATE OR REPLACE FUNCTION public.uzaktan_kontrol_ayarlari()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare y oyun.profiller;
begin
 y:=oyun.yk_sahip();
 return (select coalesce(jsonb_agg(jsonb_build_object(
 'kod',kod,'ad',ad,'acik',acik,'aciklama',aciklama,'guncelleme',guncelleme
 ) order by kod),'[]'::jsonb) from oyun.uzaktan_modul_ayar);
end$function$;

CREATE OR REPLACE FUNCTION public.uzaktan_kontrol_ayarla(p_kod text, p_acik boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare y oyun.profiller; z oyun.uzaktan_modul_ayar; t timestamptz:=now();
begin
 y:=oyun.yk_sahip();
 if p_acik is null then raise exception 'Açık/kapalı bilgisi gerekli'; end if;
 select * into z from oyun.uzaktan_modul_ayar where kod=p_kod for update;
 if z.kod is null then raise exception 'Tanımsız modül'; end if;
 if z.acik is distinct from p_acik then
   update oyun.uzaktan_modul_ayar set acik=p_acik,guncelleme=t where kod=p_kod;
   insert into oyun.yk_degisiklik(user_id,kad,tablo,islem,anahtar,once,sonra,aciklama)
   values(y.id,y.kad,'oyun.uzaktan_modul_ayar','guncelle',
     jsonb_build_object('kod',p_kod),jsonb_build_object('acik',z.acik),
     jsonb_build_object('acik',p_acik),'Sunucu kontrollü modül durumu');
 end if;
 return jsonb_build_object('tamam',true,'kod',p_kod,'acik',p_acik);
end$function$;

CREATE OR REPLACE FUNCTION public.npc_isletme_islem(p_eylem text, p_sirket bigint, p_urun text, p_adet integer DEFAULT NULL::integer, p_fiyat numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); s oyun.sirketler;
 ps oyun.pazar_sirket; u oyun.npc_urun_katalog; st oyun.npc_stok;
 v_tutar numeric; v_ref numeric; v_adet integer; v_id bigint;
begin
 if not oyun.uzaktan_modul_acik('npc_isletme') then raise exception 'Bu işletme özelliği geçici olarak kapalı'; end if;
 if p.id is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(98763,hashtext(p_sirket::text));
 select * into s from oyun.sirketler where id=p_sirket for update;
 select * into ps from oyun.pazar_sirket where sirket_id=p_sirket;
 select * into u from oyun.npc_urun_katalog where kod=p_urun and sektor=s.sektor;
 if s.id is null or not s.aktif or ps.sirket_id is null or u.kod is null then
  raise exception 'Faal şirket veya sektör ürünü bulunamadı';
 end if;
 if not oyun.sirket_yonetici_mi(s.id,p.id) then raise exception 'Şirket yöneticisi olmalısın'; end if;
 if p_eylem='al' then
  if p_adet is null or p_adet<1 or p_adet>10000 then raise exception 'Alış adedi 1-10.000 olmalı'; end if;
  v_ref:=oyun.npc_piyasa_fiyati(p_urun,ps.il_id,'alis');
  v_tutar:=round(p_adet*v_ref,2);
  if s.kasa<v_tutar then raise exception 'Şirket kasasında % TL yok',round(v_tutar); end if;
  update oyun.sirketler set kasa=kasa-v_tutar,son_islem=now() where id=s.id;
  insert into oyun.npc_stok(sirket_id,urun,adet,alis_ortalama,satis_fiyati)
   values(s.id,p_urun,p_adet,v_ref,oyun.npc_piyasa_fiyati(p_urun,ps.il_id,'satis'))
  on conflict(sirket_id,urun) do update set
    alis_ortalama=round((oyun.npc_stok.adet*oyun.npc_stok.alis_ortalama+
         excluded.adet*excluded.alis_ortalama)/(oyun.npc_stok.adet+excluded.adet),2),
    adet=oyun.npc_stok.adet+excluded.adet,son_guncelleme=now();
  insert into oyun.npc_satis_kayit(sirket_id,urun,adet,tutar,maliyet,tur)
  values(s.id,p_urun,p_adet,v_tutar,v_tutar,'alim') returning id into v_id;
  return jsonb_build_object('tamam',true,'islem','alim','fiyat',v_ref,'tutar',v_tutar,'kayit',v_id);
 elsif p_eylem='fiyat' then
  if p_fiyat is null or p_fiyat<>round(p_fiyat,2) then raise exception 'Fiyat iki ondalikli olmalı'; end if;
  v_ref:=oyun.npc_piyasa_fiyati(p_urun,ps.il_id,'satis');
  if p_fiyat<round(v_ref*0.80,2) or p_fiyat>round(v_ref*1.30,2) then
    raise exception 'Satış fiyatı referans piyasanın %%80-130 aralığında olmalı';
  end if;
  insert into oyun.npc_stok(sirket_id,urun,adet,alis_ortalama,satis_fiyati)
   values(s.id,p_urun,0,0,p_fiyat)
  on conflict(sirket_id,urun) do update set
    satis_fiyati=excluded.satis_fiyati,son_guncelleme=now();
  return jsonb_build_object('tamam',true,'islem','fiyat','fiyat',p_fiyat);
 else raise exception 'Geçersiz işlem';
 end if;
end $function$;

CREATE OR REPLACE FUNCTION oyun.npc_isletme_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s record; st record; z record;
 t timestamptz:=now(); v_gun date:=(now() at time zone 'Europe/Istanbul')::date;
 v_lim integer; v_satilan integer; v_adet integer; v_rakip integer;
 v_gelir numeric; v_maliyet numeric; v_kdv numeric; v_kurum numeric; v_diger numeric; v_bakim numeric;
 v_kar numeric; v_satis_id bigint; v_n integer:=0; v_ciro numeric:=0;
 v_tlm numeric:=oyun.pazar_tl_milyar(); v_oran numeric:=oyun.eko_vergi_oran('kdv');
 v_kv numeric:=oyun.eko_vergi_oran('kurumlar');
begin
 if not oyun.uzaktan_modul_acik('npc_isletme') then return jsonb_build_object('durdu',true); end if;
 if not pg_try_advisory_xact_lock(444722,7) then return jsonb_build_object('kilitli',true); end if;
 for s in
 select c.id,c.ad,c.kasa,c.sermaye,c.sektor,p.il_id,d.gelisim,
       oyun.pazar_il_agirlik(p.il_id) as sehir_carpani
 from oyun.sirketler c join oyun.pazar_sirket p on p.sirket_id=c.id
 join oyun.il_durum d on d.il_id=p.il_id
 where c.aktif and exists(select 1 from oyun.npc_urun_katalog n where n.sektor=c.sektor)
 order by c.id limit 400
 loop
  perform pg_advisory_xact_lock(98763,hashtext(s.id::text));
  perform 1 from oyun.sirketler where id=s.id for update;
  insert into oyun.npc_son_saat(sirket_id,son_saat) values(s.id,t) on conflict do nothing;
  update oyun.npc_son_saat set son_saat=t
  where sirket_id=s.id and son_saat<=t-interval '1 hour';
  if not found then continue; end if;
  -- Saatlik enerji, personel ve bakım: stok bitse de ödenir.
  v_bakim:=least(greatest(0,(select kasa from oyun.sirketler where id=s.id)),
    round(10+s.sermaye*0.00008,2));
  if v_bakim>0 then
   update oyun.sirketler set kasa=kasa-v_bakim where id=s.id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
   values(s.id,t,-v_bakim,'NPC mağaza saatlik personel, enerji ve bakım',0,v_bakim,0);
  end if;
  select count(*) into v_rakip from oyun.pazar_sirket ps
   join oyun.sirketler c on c.id=ps.sirket_id
   where ps.il_id=s.il_id and c.aktif and c.sektor=s.sektor;
  for st in select ns.urun,ns.adet,ns.alis_ortalama,ns.satis_fiyati,
    u.gunluk_talep from oyun.npc_stok ns join oyun.npc_urun_katalog u on u.kod=ns.urun
    where ns.sirket_id=s.id and ns.adet>0 order by ns.urun for update of ns
  loop
    insert into oyun.npc_talep_gun(il_id,urun,gun)
    values(s.il_id,st.urun,v_gun) on conflict do nothing;
    select adet into v_satilan from oyun.npc_talep_gun
       where il_id=s.il_id and urun=st.urun and gun=v_gun for update;
    v_lim:=greatest(1,round(st.gunluk_talep*greatest(0.7,least(3,s.sehir_carpani))*
      (1+oyun.belediye_yatirim_oran(s.il_id,'talep'))));
    v_adet:=least(st.adet,greatest(0,v_lim-v_satilan),
       greatest(0,floor(st.gunluk_talep*greatest(.7,least(3,s.sehir_carpani))/15*
       (0.65+random()*.7)/sqrt(greatest(1,v_rakip))*
       (0.65+s.gelisim/150.0)*
       greatest(0.2,least(1.7,power(
       oyun.npc_piyasa_fiyati(st.urun,s.il_id,'satis')/greatest(st.satis_fiyati,0.01),3)))
       +random())::integer));
    if v_adet<=0 then continue; end if;
    v_gelir:=round(st.satis_fiyati*v_adet,2);
    v_maliyet:=round(st.alis_ortalama*v_adet,2);
    v_kdv:=round(greatest(0,v_gelir-v_maliyet)*v_oran/(100+v_oran),2);
    v_diger:=round(v_gelir*0.006,2);
    v_kurum:=round(greatest(0,v_gelir-v_maliyet-v_kdv-v_diger)*v_kv/100,2);
    v_kar:=v_gelir-v_maliyet-v_kdv-v_diger-v_kurum;
    update oyun.npc_stok set adet=adet-v_adet,son_guncelleme=t
     where sirket_id=s.id and urun=st.urun;
    update oyun.npc_talep_gun set adet=adet+v_adet
     where il_id=s.il_id and urun=st.urun and gun=v_gun;
    update oyun.sirketler set kasa=kasa+v_gelir-v_kdv-v_diger-v_kurum,son_islem=t where id=s.id;
    insert into oyun.npc_satis_kayit(sirket_id,urun,adet,tutar,maliyet,vergi,isletme_gideri,tur,zaman)
      values(s.id,st.urun,v_adet,v_gelir,v_maliyet,v_kdv+v_kurum,v_diger,'npc_satis',t) returning id into v_satis_id;
    insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
      values(s.id,t,v_kar,format('NPC satış: %s adet %s (KDV ve kâr vergisi dahil)',v_adet,st.urun),
      v_gelir,v_maliyet+v_kdv+v_kurum+v_diger,0);
    if v_kdv+v_kurum>0 then
      update oyun.ulke set hazine=hazine+(v_kdv+v_kurum)/v_tlm where id=1;
      if v_kdv>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kdv',v_gelir,v_oran,v_kdv,'npc_satis',v_satis_id,t);
      end if;
      if v_kurum>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kurumlar',greatest(0,v_gelir-v_maliyet-v_kdv-v_diger),v_kv,v_kurum,'npc_satis',v_satis_id,t);
      end if;
    end if;
    v_ciro:=v_ciro+v_gelir;v_n:=v_n+v_adet;
  end loop;
 end loop;
 return jsonb_build_object('satilan',v_n,'ciro',v_ciro,'zaman',t);
end $function$;


create or replace function public.uzaktan_kontrol_yayin()
returns jsonb language plpgsql security definer set search_path='' as $$
declare y oyun.profiller; v_rev bigint;
begin
 y:=oyun.yk_sahip();
 v_rev:=oyun.uzaktan_sinyal_yay('yonetici');
 return jsonb_build_object('tamam',true,'rev',v_rev,'mesaj','Bagli uygulamalara yenileme sinyali gonderildi');
end $$;
revoke all on function public.uzaktan_kontrol_yayin() from public,anon;
grant execute on function public.uzaktan_kontrol_yayin() to authenticated;

revoke all on function oyun.uzaktan_sinyal_yay(text) from public,anon,authenticated;
revoke all on function oyun.uzaktan_sinyal_tetikle() from public,anon,authenticated;
revoke all on function public.uzaktan_kontrol_durum() from public,anon;
grant execute on function public.uzaktan_kontrol_durum() to authenticated;
revoke all on function public.uzaktan_kontrol_ayarlari() from public,anon;
grant execute on function public.uzaktan_kontrol_ayarlari() to authenticated;
revoke all on function public.uzaktan_kontrol_ayarla(text,boolean) from public,anon;
grant execute on function public.uzaktan_kontrol_ayarla(text,boolean) to authenticated;
revoke all on function oyun.npc_isletme_tick() from public,anon,authenticated;

drop trigger if exists uzaktan_sinyal_ayar on oyun.uygulama_ayar;
create trigger uzaktan_sinyal_ayar after insert or update or delete
 on oyun.uygulama_ayar for each statement execute function oyun.uzaktan_sinyal_tetikle('uygulama_ayari');
drop trigger if exists uzaktan_sinyal_modul on oyun.uzaktan_modul_ayar;
create trigger uzaktan_sinyal_modul after insert or update or delete
 on oyun.uzaktan_modul_ayar for each statement execute function oyun.uzaktan_sinyal_tetikle('modul');
drop trigger if exists uzaktan_sinyal_yonetici on oyun.yk_degisiklik;
create trigger uzaktan_sinyal_yonetici after insert on oyun.yk_degisiklik
 for each statement execute function oyun.uzaktan_sinyal_tetikle('yonetici');
drop trigger if exists uzaktan_sinyal_secim on oyun.secimler;
create trigger uzaktan_sinyal_secim after insert or delete or update of basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum
 on oyun.secimler for each statement execute function oyun.uzaktan_sinyal_tetikle('secim');
drop trigger if exists uzaktan_sinyal_engel on oyun.profiller;
create trigger uzaktan_sinyal_engel after update of yasakli,engel_bitis
 on oyun.profiller for each statement execute function oyun.uzaktan_sinyal_tetikle('engel');
drop trigger if exists uzaktan_satis_kontrol on oyun.sirketler;
create trigger uzaktan_satis_kontrol before update of satilik
 on oyun.sirketler for each row execute function oyun.uzaktan_satis_kontrol();
drop trigger if exists uzaktan_devir_kontrol on oyun.ticaret_devir_kayit;
create trigger uzaktan_devir_kontrol before insert
 on oyun.ticaret_devir_kayit for each row execute function oyun.uzaktan_devir_kontrol();
drop trigger if exists uzaktan_npc_yeni on oyun.pazar_sirket;
create trigger uzaktan_npc_yeni before insert
 on oyun.pazar_sirket for each row execute function oyun.uzaktan_yeni_npc_kontrol();
drop trigger if exists uzaktan_hisse_ilan_kontrol on oyun.sirket_hisse_ilanlari;
create trigger uzaktan_hisse_ilan_kontrol before insert
 on oyun.sirket_hisse_ilanlari for each row execute function oyun.uzaktan_hisse_ilan_kontrol();
