-- Kalici belediye yatirimlari + NPC stoklu sirketler + vergili sirket devri.
-- Bu dosya mevcut oyuncu verisini sifirlamaz; tekrar calistirmak guvenlidir.
-- Canli sunucuya 22.10.2026 tarihinde uygulanmistir.

insert into oyun.pazar_sektor(kod,ad,bakanlik,taban,esneklik,dis,sabit,kapasite,personel,min_sermaye,sira,aciklama)
values
('akaryakit','Akaryakıt İstasyonu','ticaret',145000,1.8,0.20,0.045,0.26,0.20,300000,30,'Benzin, motorin ve LPG stoku al, NPC sürücülere sat.'),
('yapi_market','Yapı Market','ticaret',135000,1.7,0.15,0.045,0.25,0.20,200000,31,'Yapı malzemelerini toptan al ve şehre sat.'),
('elektronik_magaza','Elektronik Mağazası','ticaret',135000,1.8,0.20,0.045,0.25,0.20,220000,32,'Elektronik ürün alım satımı.'),
('tekstil_magaza','Giyim Mağazası','ticaret',130000,1.8,0.14,0.045,0.25,0.20,180000,33,'Tekstil ürün alım satımı.'),
('mobilya_magaza','Mobilya Mağazası','ticaret',125000,1.5,0.14,0.045,0.25,0.20,240000,34,'Mobilya alım satımı.'),
('oto_galeri','Otomobil Galerisi','ticaret',130000,1.3,0.17,0.055,0.22,0.20,500000,35,'İkinci el araç alımı ve NPC müşterilere satışı.')
on conflict(kod) do nothing;

create table if not exists oyun.npc_urun_katalog (
 kod text primary key, sektor text not null references oyun.pazar_sektor(kod),
 ad text not null, alis_ref numeric not null check(alis_ref>0),
 satis_ref numeric not null check(satis_ref>alis_ref),
 gunluk_talep integer not null check(gunluk_talep>0)
);
insert into oyun.npc_urun_katalog(kod,sektor,ad,alis_ref,satis_ref,gunluk_talep)
values
('benzin','akaryakit','Benzin (litre)',46,51,150),
('motorin','akaryakit','Motorin (litre)',48,53,180),
('lpg','akaryakit','LPG (litre)',26,30,85),
('yapi','yapi_market','Yapı malzemesi (paket)',1200,1520,25),
('elektronik','elektronik_magaza','Elektronik ürün (adet)',11000,13900,7),
('giyim','tekstil_magaza','Giyim ürünü (adet)',460,650,50),
('mobilya','mobilya_magaza','Mobilya ürünü (adet)',6400,8500,9),
('oto','oto_galeri','İkinci el araç (adet)',560000,625000,2)
on conflict(kod) do nothing;
create table if not exists oyun.npc_stok (
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.npc_urun_katalog(kod),
 adet integer not null default 0 check(adet>=0),
 alis_ortalama numeric not null default 0 check(alis_ortalama>=0),
 satis_fiyati numeric not null default 0 check(satis_fiyati>=0),
 son_guncelleme timestamptz not null default now(), primary key(sirket_id,urun)
);
create table if not exists oyun.npc_satis_kayit (
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.npc_urun_katalog(kod),
 adet integer not null check(adet>0), tutar numeric not null,
 maliyet numeric not null, vergi numeric not null default 0,
 isletme_gideri numeric not null default 0,
 tur text not null check(tur in ('alim','npc_satis')),
 zaman timestamptz not null default now()
);
create index if not exists npc_satis_sirket_tarih_idx on oyun.npc_satis_kayit(sirket_id,zaman desc);
create table if not exists oyun.npc_talep_gun (
 il_id smallint not null, urun text not null, gun date not null,
 adet integer not null default 0 check(adet>=0), primary key(il_id,urun,gun)
);
create table if not exists oyun.npc_son_saat (
 sirket_id bigint primary key references oyun.sirketler(id),
 son_saat timestamptz not null default now()
);
create table if not exists oyun.sirket_devir_vergi (
 devir_id bigint primary key references oyun.ticaret_devir_kayit(id),
 sirket_id bigint not null references oyun.sirketler(id),
 satici uuid not null, alici uuid not null, bedel numeric not null,
 oran numeric not null, vergi numeric not null,
 zaman timestamptz not null default now()
);
alter table oyun.npc_urun_katalog enable row level security;
alter table oyun.npc_stok enable row level security;
alter table oyun.npc_satis_kayit enable row level security;
alter table oyun.npc_talep_gun enable row level security;
alter table oyun.npc_son_saat enable row level security;
alter table oyun.sirket_devir_vergi enable row level security;
revoke all on oyun.npc_urun_katalog,oyun.npc_stok,oyun.npc_satis_kayit,oyun.npc_talep_gun,oyun.npc_son_saat,oyun.sirket_devir_vergi from anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.belediye_yatirim_oran(p_il smallint, p_tur text)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 with k as (
 select
 least(8,count(*) filter (where kod='altyapi')) a,
 least(4,count(*) filter (where kod='rayli')) r,
 least(3,count(*) filter (where kod='imar_barisi')) i,
 least(3,count(*) filter (where kod='arsa_satisi')) s
 from oyun.belediye_proje_kayit where il_id=p_il
 )
 select case p_tur
 when 'gelir' then greatest(-0.08,least(0.35,a*0.018+r*0.042+i*0.005-s*0.009))
 when 'bakim' then a*0.006+r*0.012+i*0.002
 when 'talep' then greatest(0,least(0.30,a*0.012+r*0.036+i*0.003))
 when 'gelisim' then greatest(0,least(16,a*0.8+r*2.6+i*0.4-s*0.3))
 else 0 end from k
$function$;

CREATE OR REPLACE FUNCTION oyun.il_gelir(p_il smallint)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select round((
  oyun.il_gunluk_gelir(i.mv) * u.endeks
  * (0.5 + d.gelisim/100)
  * (0.5 + 0.5*u.belediye_payi/10)
  * (1+d.kent_vergisi/10)
  + oyun.il_duz(i.id,'emlak')*u.endeks*oyun.nufus('il_hane')*i.mv/600/1e9
 )*(1+oyun.belediye_yatirim_oran(p_il,'gelir')),4)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id,
 oyun.ulke u where i.id=p_il and u.id=1
$function$;

CREATE OR REPLACE FUNCTION oyun.il_gider(p_il smallint)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select coalesce((select sum(oyun.hizmet_gider(p_il,h.kod))
 from oyun.il_hizmet h where h.il_id=p_il),0)
 + oyun.hemsehri_gider(p_il,(select hemsehri from oyun.il_durum where il_id=p_il))
 + oyun.il_gelir(p_il)*oyun.belediye_yatirim_oran(p_il,'bakim')
$function$;

CREATE OR REPLACE FUNCTION oyun.belediye_gunluk(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare r record; h record; b record; v_kasa numeric; bas uuid; g numeric; pay numeric;
  bugun date := (t at time zone 'Europe/Istanbul')::date;
begin
  for r in select d.il_id, i.ad, i.mv from oyun.il_durum d join oyun.iller i on i.id = d.il_id loop
    g := oyun.il_gelir(r.il_id);
    -- Vergi geliri 60 günlük gelire kadar birikir; bağış ve kredi gibi dış kaynaklar kesilmez.
    update oyun.il_durum set kasa = coalesce(kasa, 0) + least(g, greatest(0, 60 * g - coalesce(kasa, 0))) - oyun.il_gider(r.il_id)
     where il_id = r.il_id returning kasa into v_kasa;
    -- İller Bankası taksitleri
    for b in select * from oyun.belediye_borc where il_id = r.il_id and durum = 'aktif' and son_odeme < bugun order by id loop
      pay := least(b.taksit, b.kalan);
      if v_kasa >= pay then
        update oyun.il_durum set kasa = kasa - pay where il_id = r.il_id returning kasa into v_kasa;
        update oyun.belediye_borc set kalan = round(kalan - pay, 6), son_odeme = bugun,
               durum = case when kalan - pay <= 0.000001 then 'kapandi' else 'aktif' end,
               kapanis = case when kalan - pay <= 0.000001 then t end
         where id = b.id;
        insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
        values (r.il_id, 'kredi_taksit', -pay, 'İller Bankası taksiti', t);
      else
        update oyun.belediye_borc set kalan = round(kalan + b.taksit * 0.05, 6), gecikme = gecikme + 1, son_odeme = bugun
         where id = b.id;
        update oyun.il_durum set memnuniyet = oyun.sinir(memnuniyet - 1, 0, 100) where il_id = r.il_id;
        insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
        values (r.il_id, 'kredi_gecikme', 0, 'İller Bankası taksiti ödenemedi; %5 gecikme cezası borca eklendi', t);
        bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
        if bas is not null then
          perform oyun.bildir(bas, 'İller Bankası taksiti kasada para olmadığı için ödenemedi; %5 gecikme cezası eklendi.', t);
        end if;
        if (b.gecikme + 1) % 3 = 0 then
          perform oyun.olay('belediye', format('Sayıştay uyarısı: %s Belediyesi İller Bankası borcunu %s gündür ödeyemiyor.', r.ad, b.gecikme + 1), r.il_id, null, t);
        end if;
      end if;
    end loop;
    if v_kasa < 0 then
      bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
      update oyun.il_durum set hemsehri = 0 where il_id = r.il_id and hemsehri > 0;
      for h in select k.kod, bh.ad from oyun.il_hizmet k join oyun.belediye_hizmetleri bh on bh.kod = k.kod
               where k.il_id = r.il_id order by bh.oran desc loop
        exit when (select kasa from oyun.il_durum where il_id = r.il_id) >= 0;
        delete from oyun.il_hizmet where il_id = r.il_id and kod = h.kod;
        update oyun.il_durum set kasa = kasa + oyun.hizmet_gider(r.il_id, h.kod) where il_id = r.il_id;
        perform oyun.olay('belediye', format('%s Belediyesi kasası yetmediği için %s hizmetini kapattı.', r.ad, h.ad), r.il_id, null, t);
      end loop;
      if bas is not null then perform oyun.bildir(bas, 'Belediye kasası eksiye düştü: hemşehri desteği durduruldu, gerekirse hizmetler kapatıldı.', t); end if;
      update oyun.il_durum set kasa = greatest(kasa, 0) where il_id = r.il_id;
    end if;
  end loop;
  delete from oyun.belediye_karne_etki where bitis < t - interval '30 days';
  -- gelişmişlik yatırım almazsa yavaşça ortalamaya döner; memnuniyet hizmetlere, desteğe, vergiye
  -- ve hizmet karnesine (binalar, programlar, kriz kararları) göre şekillenir
  update oyun.il_durum d set gelisim = gelisim + (50 + oyun.belediye_yatirim_oran(d.il_id, 'gelisim') - gelisim) * 0.01,
    memnuniyet = oyun.sinir(memnuniyet + (50 + 4 * (select count(*) from oyun.il_hizmet ih where ih.il_id = d.il_id) + least(10, hemsehri / 30)
                                          - kent_vergisi * 2 - oyun.il_duz(d.il_id, 'emlak') / 30
                                          + (oyun.belediye_karne_ort(d.il_id) - 45) * 0.5 - memnuniyet) * 0.05, 0, 100);
end $function$;

CREATE OR REPLACE FUNCTION public.belediye_yatirim_ekonomi_panel(p_il integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v record;
begin
 if auth.uid() is null then raise exception 'Oturum acmalisin'; end if;
 if p_il is null or p_il not between 1 and 81 then raise exception 'Gecersiz il'; end if;
 select i.ad, d.gelisim,d.memnuniyet,d.kasa,
 oyun.il_gelir(d.il_id) gelir,oyun.il_gider(d.il_id) gider,
 oyun.belediye_yatirim_oran(d.il_id,'gelir') gelir_orani,
 oyun.belediye_yatirim_oran(d.il_id,'bakim') bakim_orani,
 oyun.belediye_yatirim_oran(d.il_id,'talep') npc_orani,
 oyun.belediye_yatirim_oran(d.il_id,'gelisim') kalici_gelisim
 into v from oyun.il_durum d join oyun.iller i on i.id=d.il_id where d.il_id=p_il;
 return jsonb_build_object('il',v.ad,'gelisim',v.gelisim,'memnuniyet',v.memnuniyet,
 'kasa',v.kasa,'gunluk_gelir',v.gelir,'gunluk_gider',v.gider,
 'yatirim_gelir_yuzdesi',round(v.gelir_orani*100,1),
 'yatirim_bakim_yuzdesi',round(v.bakim_orani*100,1),
 'npc_talep_yuzdesi',round(v.npc_orani*100,1),
 'kalici_gelisim_destegi',v.kalici_gelisim,
 'yatirimlar',(select coalesce(jsonb_agg(jsonb_build_object('kod',q.kod,'ad',b.ad,'adet',q.adet)),'[]'::jsonb)
 from (select kod,count(*) adet from oyun.belediye_proje_kayit where il_id=p_il group by kod) q
 join oyun.belediye_yatirimlari b on b.kod=q.kod));
end $function$;

CREATE OR REPLACE FUNCTION oyun.npc_piyasa_fiyati(p_urun text, p_il smallint, p_tip text, p_gun date DEFAULT NULL::date)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select round((case when p_tip='alis' then x.alis_ref else x.satis_ref end)
   *(1+((hashtext(x.kod||':'||p_il::text||':'||coalesce(p_gun,(now() at time zone 'Europe/Istanbul')::date)::text)
   & 2147483647)%601 - 300)::numeric/10000)
   *coalesce((select endeks from oyun.ulke where id=1),1),2)
 from oyun.npc_urun_katalog x where x.kod=p_urun
$function$;

CREATE OR REPLACE FUNCTION public.npc_isletme_panel(p_sirket bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); s oyun.sirketler; ps oyun.pazar_sirket;
begin
 select * into s from oyun.sirketler where id=p_sirket;
 select * into ps from oyun.pazar_sirket where sirket_id=p_sirket;
 if p.id is null then raise exception 'Oturum gerekli'; end if;
 if s.id is null or ps.sirket_id is null or not exists(select 1 from oyun.npc_urun_katalog where sektor=s.sektor)
 then raise exception 'Stoklu işletme bulunamadı'; end if;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=p.id) then
 raise exception 'Bu şirketin sahibi veya ortağı değilsin'; end if;
 return jsonb_build_object('id',s.id,'ad',s.ad,'aktif',s.aktif,'sektor',s.sektor,
 'yonetici',oyun.sirket_yonetici_mi(s.id,p.id),
 'kasa',round(s.kasa),'il', (select ad from oyun.iller where id=ps.il_id),
 'gelisim', (select round(gelisim,1) from oyun.il_durum where il_id=ps.il_id),
 'belediye_talep_bonus',round(oyun.belediye_yatirim_oran(ps.il_id,'talep')*100,1),
 'urunler',(select coalesce(jsonb_agg(jsonb_build_object(
 'kod',u.kod,'ad',u.ad,'alis',oyun.npc_piyasa_fiyati(u.kod,ps.il_id,'alis'),
 'referans',oyun.npc_piyasa_fiyati(u.kod,ps.il_id,'satis'),
 'stok',coalesce(st.adet,0),'maliyet',coalesce(st.alis_ortalama,0),
 'fiyat',coalesce(nullif(st.satis_fiyati,0),oyun.npc_piyasa_fiyati(u.kod,ps.il_id,'satis'))
 ) order by u.kod),'[]'::jsonb)
 from oyun.npc_urun_katalog u left join oyun.npc_stok st
 on st.sirket_id=s.id and st.urun=u.kod where u.sektor=s.sektor),
 'son_satislar',(select coalesce(jsonb_agg(z order by z.zaman desc),'[]'::jsonb)
 from(select urun,adet,tutar,maliyet,vergi,isletme_gideri,tur,zaman
 from oyun.npc_satis_kayit where sirket_id=s.id order by id desc limit 12) z),
 'son_7_gun',(select jsonb_build_object(
 'ciro',coalesce(sum(tutar)filter(where tur='npc_satis'),0),
 'satilan',coalesce(sum(adet)filter(where tur='npc_satis'),0),
 'stok_alim',coalesce(sum(tutar)filter(where tur='alim'),0),
 'vergi',coalesce(sum(vergi)filter(where tur='npc_satis'),0))
 from oyun.npc_satis_kayit where sirket_id=s.id and zaman>now()-interval '7 days'));
end $function$;

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

CREATE OR REPLACE FUNCTION oyun.pazar_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r record; n int := 0;
begin
  perform oyun.ana_faaliyet_ac();
  perform oyun.ihale_tick();
  perform oyun.rekabet_tick();
  perform oyun.ajans_tick();
  for r in select s.id from oyun.sirketler s
           where s.aktif and s.sonraki_kazanc <= oyun.simdi() and not exists(select 1 from oyun.npc_urun_katalog np where np.sektor=s.sektor)
             and (exists (select 1 from oyun.pazar_sirket ps where ps.sirket_id = s.id) or s.sektor = 'ajans')
           order by s.sonraki_kazanc limit 200 loop
    perform oyun.sirket_hesapla(r.id); n := n + 1;
  end loop;
  perform oyun.piyasa_endeks_tick();
  return n;
end $function$;

CREATE OR REPLACE FUNCTION oyun.pazar_hesapla(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s oyun.sirketler; ps oyun.pazar_sirket; t timestamptz := oyun.simdi(); n int; i int; h jsonb; zt timestamptz; gun date;
  gurultu numeric; gelir numeric; gider numeric; ruhsat numeric; ceza numeric; v_vergi numeric; net numeric; oran numeric;
  x record; distributed numeric; distributable numeric; v_odeme numeric; tlm numeric; ilad text; kasa_son numeric;
  en jsonb; yonetim numeric; a oyun.pazar_ayar; sabit numeric; reklam numeric; enerji numeric; lojistik numeric;
  b2b_in numeric; brut numeric; kv numeric; tes jsonb; indirim numeric; net_op numeric; tesvik_tl numeric;
  reklam_bonus numeric; kalite_bonus numeric;
begin
  select * into s from oyun.sirketler where id = p_id for update;
  select * into ps from oyun.pazar_sirket where sirket_id = p_id for update;
  if s.id is null or ps.sirket_id is null or not s.aktif or s.sonraki_kazanc > t then return; end if;
  if exists(select 1 from oyun.npc_urun_katalog n where n.sektor=s.sektor) then return; end if;
  select * into a from oyun.pazar_ayar where id = 1;
  n := least(30, floor(extract(epoch from (t - s.sonraki_kazanc)) / 86400)::int + 1);
  tlm := oyun.pazar_tl_milyar();
  select ad into ilad from oyun.iller where id = ps.il_id;
  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), a.kurumlar);
  for i in 1..n loop
    zt := s.sonraki_kazanc + (i - 1) * interval '1 day';
    gun := (zt at time zone 'Europe/Istanbul')::date;
    if ps.otopilot and (ps.hafta % 7 = 0) then
      en := oyun.pazar_en_iyi(p_id, zt);
      if en is not null and ((en->>'fiyat')::int <> ps.fiyat or (en->>'kalite')::int <> ps.kalite) then
        update oyun.pazar_sirket set fiyat = (en->>'fiyat')::int, kalite = (en->>'kalite')::int where sirket_id = p_id;
        select * into ps from oyun.pazar_sirket where sirket_id = p_id;
      end if;
    end if;
    h := oyun.pazar_tahmin(p_id, null, null, null, zt);
    gurultu := 0.88 + random()::numeric * 0.24;
    gelir := round((h->>'gelir')::numeric / 7 * gurultu);
    yonetim := case when ps.otopilot then round(gelir * a.yonetici_ucret / 100) else 0 end;
    sabit := (h->>'sabit')::numeric / 7;
    reklam := round(gelir * (array[0, 0.015, 0.03, 0.05])[coalesce(ps.reklam, 0) + 1]);
    gider := round(((h->>'gider')::numeric - (h->>'reklam')::numeric) / 7) + reklam + yonetim;
    oran := coalesce((h->>'ruhsat_oran')::numeric, 0);
    ruhsat := round(gelir * oran / 100);
    ceza := case when (h->>'ceza')::numeric > 0 then round(gelir * 0.12) else 0 end;
    net_op := gelir - gider - ruhsat - ceza;

    enerji := round(sabit * 0.30); lojistik := round(sabit * 0.20);
    if s.sektor <> 'enerji' then perform oyun.b2b_ode(p_id, 'enerji', enerji, ps.il_id, 'Elektrik faturası', gun); end if;
    if s.sektor <> 'ulasim' then perform oyun.b2b_ode(p_id, 'ulasim', lojistik, ps.il_id, 'Lojistik ve servis', gun); end if;
    if reklam > 0 and s.sektor <> 'medya' then perform oyun.b2b_ode(p_id, 'medya', reklam, ps.il_id, 'Reklam', gun); end if;

    with u as (update oyun.eko_b2b set islendi = true where satici = p_id and not islendi returning tutar)
    select coalesce(sum(tutar), 0) into b2b_in from u;

    brut := net_op + b2b_in;
    tes := oyun.bolge_tesvik(ps.il_id);
    indirim := (tes->>'vergi_indirim')::numeric;
    v_vergi := round(greatest(0, brut) * kv / 100 * (1 - indirim / 100));
    tesvik_tl := round(greatest(0, brut) * kv / 100) - v_vergi;
    net := brut - v_vergi;

    if v_vergi > 0 then update oyun.ulke set hazine = hazine + v_vergi / tlm where id = 1; end if;
    if ruhsat > 0 then
      update oyun.il_durum set kasa = coalesce(kasa, 0) + ruhsat / tlm where il_id = ps.il_id;
      insert into oyun.il_ruhsat(il_id, toplam) values (ps.il_id, ruhsat)
        on conflict (il_id) do update set toplam = oyun.il_ruhsat.toplam + excluded.toplam;
    end if;
    update oyun.il_durum set
      gelisim = oyun.sinir(gelisim + (0.03 + case ps.kaynak when 'yenilenebilir' then 0.05 else 0 end) / 7, 0, 100),
      memnuniyet = oyun.sinir(memnuniyet + (case when s.sektor = 'enerji' and ps.kaynak = 'komur' then -0.4 when ps.kalite >= 2 then 0.05 else 0 end) / 7, 0, 100)
    where il_id = ps.il_id;

    update oyun.sirketler set kasa = kasa + net_op - v_vergi where id = p_id;
    distributed := 0;
    if net > 0 then
      distributable := least(net, greatest(0, (select kasa from oyun.sirketler where id = p_id)));
      for x in select * from oyun.sirket_ortaklari where sirket_id = p_id loop
        if not x.kar_kasada then
          v_odeme := least(round(distributable * x.pay / 100, 2), greatest(0, distributable - distributed));
          if v_odeme > 0 then
            perform oyun.para_islem(x.user_id, v_odeme, 'sirket', format('%s günlük net kâr payı (%s)', s.ad, to_char(gun, 'DD.MM')), t);
            distributed := distributed + v_odeme;
          end if;
        end if;
      end loop;
      update oyun.sirketler set kasa = kasa - distributed where id = p_id;
    end if;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (p_id, t, net, format('Günlük faaliyet %s (%s): pazar payı %%%s, %s rakip%s%s', to_char(gun, 'DD.MM'),
            ilad, h->>'pay', h->>'rakip', case when ps.otopilot then ', otopilot' else '' end,
            case when b2b_in > 0 then format(', şirketlerden %s ₺ satış', oyun.tl(b2b_in)) else '' end),
            gelir + b2b_in, gider + ruhsat + ceza + v_vergi, distributed);
    insert into oyun.pazar_rapor(sirket_id, zaman, il_id, pazar, pay, rakip, gelir, gider, ruhsat, vergi, ceza, net, fiyat, kalite, kaynak)
    values (p_id, zt + interval '1 day', ps.il_id, round((h->>'pazar')::numeric / 7), (h->>'pay')::numeric, (h->>'rakip')::int,
            gelir + b2b_in, gider, ruhsat, v_vergi, ceza, net, ps.fiyat, ps.kalite, ps.kaynak);
    insert into oyun.eko_gunluk(sirket_id, gun, gelir, gider, reklam, b2b_gider, b2b_gelir, ruhsat, ceza, vergi, tesvik, net, dagitilan,
                                pazar, pay, rakip, fiyat, kalite, il_id, zaman)
    values (p_id, gun, gelir, gider, reklam, enerji + lojistik + reklam, b2b_in, ruhsat, ceza, v_vergi, tesvik_tl, net, distributed,
            round((h->>'pazar')::numeric / 7), (h->>'pay')::numeric, (h->>'rakip')::int, ps.fiyat, ps.kalite, ps.il_id, t)
    on conflict on constraint eko_gunluk_pkey do update set
      gelir = oyun.eko_gunluk.gelir + excluded.gelir, gider = oyun.eko_gunluk.gider + excluded.gider,
      reklam = oyun.eko_gunluk.reklam + excluded.reklam, b2b_gider = oyun.eko_gunluk.b2b_gider + excluded.b2b_gider,
      b2b_gelir = oyun.eko_gunluk.b2b_gelir + excluded.b2b_gelir, ruhsat = oyun.eko_gunluk.ruhsat + excluded.ruhsat,
      ceza = oyun.eko_gunluk.ceza + excluded.ceza, vergi = oyun.eko_gunluk.vergi + excluded.vergi,
      tesvik = oyun.eko_gunluk.tesvik + excluded.tesvik, net = oyun.eko_gunluk.net + excluded.net,
      dagitilan = oyun.eko_gunluk.dagitilan + excluded.dagitilan, zaman = excluded.zaman;

    reklam_bonus := (array[0, 3, 6, 10])[coalesce(ps.reklam, 0) + 1];
    kalite_bonus := 3 + 2.5 * ps.kalite + case ps.kaynak when 'yenilenebilir' then 3 else 0 end;
    update oyun.pazar_sirket set marka = least(100, marka * 0.985 + (kalite_bonus + reklam_bonus) / 7.0),
      hafta = hafta + 1 where sirket_id = p_id;
    select * into ps from oyun.pazar_sirket where sirket_id = p_id;

    select kasa into kasa_son from oyun.sirketler where id = p_id;
    if kasa_son <= 0 then
      update oyun.sirketler set aktif = false, kasa = 0, satilik = null, son_islem = t,
        sonraki_kazanc = s.sonraki_kazanc + i * interval '1 day' where id = p_id;
      update oyun.borsa_emir set durum = 'iptal' where sirket_id = p_id and durum = 'acik';
      perform oyun.olay('ekonomi', format('%s (%s, %s) iflas etti; kasası tükendi.', s.ad,
        (select ad from oyun.pazar_sektor where kod = s.sektor), ilad), ps.il_id, null, t);
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
        perform oyun.bildir(x.user_id, format('%s iflas etti: şirket kasası tükendi ve faaliyet durdu.', s.ad), t);
      end loop;
      return;
    end if;
  end loop;
  update oyun.sirketler set sonraki_kazanc = sonraki_kazanc + n * interval '1 day', son_islem = t where id = p_id;
  if kasa_son < s.sermaye * 0.25 and (ps.son_uyari is null or ps.son_uyari < t - interval '2 days') then
    update oyun.pazar_sirket set son_uyari = t where sirket_id = p_id;
    for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
      perform oyun.bildir(x.user_id, format('%s zarar ediyor: kasada %s ₺ kaldı. Fiyat/kaliteyi gözden geçir, otopilotu aç ya da ili değiştir; yoksa iflas edebilir.',
        s.ad, oyun.tl(kasa_son)), t);
    end loop;
  end if;
end $function$;

CREATE OR REPLACE FUNCTION oyun.tg_sirket_devir_kayit_vergi()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_oran numeric; v_vergi numeric; v_pay numeric;
begin
 if new.tur not in ('sirket_tam','sirket_hisse') then return new; end if;
 if new.satici is null or new.alici is null or new.bedel<=0 then
   raise exception 'Devir kimlikleri ve bedeli gecersiz';
 end if;
 -- Oyuncu icra borcu/hacizli şirket payını normal ilanla devredemez.
 if exists(select 1 from oyun.icra_haciz_yeni h where h.varlik_id=new.varlik_id
     and h.tur in ('sirket','sirket_hisse','sirket_pay','hisse')
     and h.durum not in ('satildi','kaldirildi','iptal','tamamlandi','kapandi')) or
    exists(select 1 from oyun.oyb_icra_haciz h where h.varlik_id=new.varlik_id
     and h.tur in ('sirket','sirket_hisse','sirket_pay','hisse')
     and h.durum not in ('satildi','kaldirildi','iptal','tamamlandi','kapandi')) then
   raise exception 'İcra haczi bulunan şirket/hisse normal satışla devredilemez';
 end if;
 if exists(select 1 from oyun.sirket_konkordato where sirket_id=new.varlik_id
    and durum='aktif' and bit>now()) then
    raise exception 'Aktif konkordato korumasındaki şirket devredilemez';
 end if;
 v_oran:=greatest(0,coalesce(oyun.eko_vergi_oran('damga'),1));
 v_vergi:=round(new.bedel*v_oran/100,2);
 if v_vergi>0 then
   perform oyun.para_islem(new.satici,-v_vergi,'sirket',
      format('Şirket #%s devir işlemi vergisi (%%%s)',new.varlik_id,v_oran),new.zaman,v_vergi);
   update oyun.ulke set hazine=hazine+v_vergi/oyun.pazar_tl_milyar() where id=1;
   insert into oyun.eko_vergi_hareket(sirket_id,oyuncu,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
    values(new.varlik_id,new.satici,'damga',new.bedel,v_oran,v_vergi,'sirket_devir',new.id,new.zaman);
 end if;
 insert into oyun.sirket_devir_vergi(devir_id,sirket_id,satici,alici,bedel,oran,vergi,zaman)
  values(new.id,new.varlik_id,new.satici,new.alici,new.bedel,v_oran,v_vergi,new.zaman)
  on conflict (devir_id) do nothing;
 -- Firma devriyle kurucu geçmişi korunur, güncel yönetici aktarılır.
 if new.tur='sirket_tam' then
   update oyun.sirketler set yonetici=new.alici where id=new.varlik_id;
   update oyun.sirket_hisse_ilanlari set durum='iptal',kapanis=new.zaman
   where sirket_id=new.varlik_id and durum='acik';
 elsif (select yonetici from oyun.sirketler where id=new.varlik_id)=new.satici and
    not exists (select 1 from oyun.sirket_ortaklari where sirket_id=new.varlik_id and user_id=new.satici and pay>0)
 then
   update oyun.sirketler set yonetici=oyun.sirket_sahibi(new.varlik_id) where id=new.varlik_id;
 end if;
 return new;
end $function$;

revoke all on function public.belediye_yatirim_ekonomi_panel(integer) from public,anon;
grant execute on function public.belediye_yatirim_ekonomi_panel(integer) to authenticated;
revoke all on function public.npc_isletme_panel(bigint) from public,anon;
grant execute on function public.npc_isletme_panel(bigint) to authenticated;
revoke all on function public.npc_isletme_islem(text,bigint,text,integer,numeric) from public,anon;
grant execute on function public.npc_isletme_islem(text,bigint,text,integer,numeric) to authenticated;
revoke all on function oyun.npc_isletme_tick() from public,anon,authenticated;
drop trigger if exists sirket_devir_vergi_yeni on oyun.ticaret_devir_kayit;
create trigger sirket_devir_vergi_yeni after insert on oyun.ticaret_devir_kayit
for each row execute function oyun.tg_sirket_devir_kayit_vergi();
do $$ begin
 if not exists(select 1 from cron.job where jobname='npc-isletme-hourly') then
   perform cron.schedule('npc-isletme-hourly','21 * * * *','select oyun.npc_isletme_tick()');
 end if;
end $$;
