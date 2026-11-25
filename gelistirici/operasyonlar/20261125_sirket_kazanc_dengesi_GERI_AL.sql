-- ŞİRKET KAZANÇ DENGESİ · GERİ ALMA (yalnız gerekirse; kendiliğinden ÇALIŞTIRILMAZ)
-- En kolay yol sistemi kapatmaktır; fonksiyonlar kalır, eski hesap geçerli olur:
--     update oyun.sirket_denge_ayar set aktif = false;
-- Aşağıdaki komutlar 25.11.2026 öncesi işlev tanımlarını birebir geri yükler (aynıları oyun.sirket_denge_yedek'te durur).
-- oyun.sube_pazar_tahmin yeni hâliyle kalabilir: eski sube_bolge_analiz ile de aynı sonucu verir.
begin;
update oyun.sirket_denge_ayar set aktif = false where id = 1;
update oyun.zamanlayici_adim set aktif = false where adim = 'sirket_denge';

-- oyun.eko_ticaret_tick()
CREATE OR REPLACE FUNCTION oyun.eko_ticaret_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 t timestamptz:=oyun.simdi(); oto record; mag record; item record;
 stok_adet integer; sup bigint; siparis int; yapilan int:=0; alim int:=0; satilan int:=0;talep int; rakip int;
 faktor numeric; maliyet numeric; personel numeric; v_vergi numeric;
 ciro numeric; royalty numeric; karpayi numeric; kardegeri numeric;net numeric;
 v_musteri text; v_saat integer; v_saat_kalan integer; v_sehir_kalan integer; v_saat_carpan numeric; v_sehir_ust integer;
 sale_id bigint; corp_branch numeric; corp_brand numeric; branch_taxbase numeric; brandgross numeric;
 f oyun.eko_franchise; m oyun.eko_markalar;
 v_donem timestamptz:=date_trunc('hour',now());
begin
 if not pg_try_advisory_xact_lock(424261) then return jsonb_build_object('kilitli',true); end if;
 -- Tamamlanmis uretim emrini bir defa stoklara aktar; maliyet baslangicta odenmistir.
 yapilan := oyun.eko_uretim_teslim(null);

 -- Istege bagli 7 gunluk otomatik stok yenileme: tedarikci stogu ve magaza parasi yoksa satin almaz.
 for oto in select a.* from oyun.eko_otomatik_tedarik a
 join oyun.eko_isletmeler ei on ei.sirket_id=a.sirket_id and ei.tur='magaza'
 join oyun.sirketler s on s.id=a.sirket_id and s.aktif
 where a.aktif and a.bitis>t order by a.sirket_id,a.urun limit 250
 loop
  begin
   select coalesce(adet,0) into stok_adet from oyun.eko_urun_stok
    where sirket_id=oto.sirket_id and urun=oto.urun;
   if coalesce(stok_adet,0)>oto.esik then continue;end if;
   select st.sirket_id into sup
    from oyun.eko_urun_stok st join oyun.eko_isletmeler e
      on e.sirket_id=st.sirket_id and e.tur='fabrika'
    join oyun.sirketler s on s.id=st.sirket_id and s.aktif
    where st.urun=oto.urun and st.adet>0 and st.satis_fiyati<=oto.azami_birim_fiyat
      and st.sirket_id<>oto.sirket_id
    order by st.satis_fiyati,st.sirket_id limit 1;
   if sup is null then continue;end if;
   select least(oto.miktar,adet) into siparis from oyun.eko_urun_stok
     where sirket_id=sup and urun=oto.urun;
   if siparis>0 then
     perform oyun.eko_urun_toptan(oto.sirket_id,sup,oto.urun,siparis,null);
     alim:=alim+1;
   end if;
  exception when others then null; -- tek siparisin basarisizligi digerlerinin satisini engellemez
  end;
 end loop;
 update oyun.eko_otomatik_tedarik set aktif=false where aktif and bitis<=t;

 -- NPC tuketimi: ilin nufusu ve geliri (talep), alim gucu, yerel fiyat duzeyi, piyasa fiyati ve rakip sayisi.
 for mag in select ei.sirket_id,ei.il_id,ei.magaza_kategori,
   s.sermaye,coalesce(d.gelisim,50) as gelisim,
   oyun.il_talep_endeksi(ei.il_id) as te, oyun.il_alim_gucu(ei.il_id) as ag, oyun.il_fiyat_duzeyi(ei.il_id) as fd
   from oyun.eko_isletmeler ei join oyun.sirketler s on s.id=ei.sirket_id and s.aktif
   left join oyun.il_durum d on d.il_id=ei.il_id
   where ei.tur='magaza' and ei.satis_aktif and ei.son_perakende<=t-interval '1 hour'
   order by md5(ei.sirket_id::text||((t at time zone 'Europe/Istanbul')::date)::text) limit 250
 loop
  update oyun.eko_isletmeler set son_perakende=t
   where sirket_id=mag.sirket_id and son_perakende<=t-interval '1 hour';
  if not found then continue;end if;
  v_saat:=extract(hour from (t at time zone 'Europe/Istanbul'))::integer;
  v_saat_carpan:=case when v_saat between 1 and 5 then 0.18
    when v_saat between 6 and 9 then 0.75
    when v_saat between 10 and 15 then 1.15
    when v_saat between 16 and 22 then 1.0 else 0.55 end;
  -- Mağaza başı saatlik müşteri: büyük şehirde yoğun, küçük şehirde seyrek
  v_saat_kalan:=greatest(4,round((case mag.magaza_kategori when 'market' then 18 when 'fastfood' then 22 else 16 end)
    *greatest(0.6,least(1.8,power(coalesce(mag.te,1),0.35))))::integer);
  -- Şehrin günlük müşteri kotası: nüfus ve gelirle (İstanbul ~6 kat, Tunceli ~0,25 kat)
  v_sehir_ust:=greatest(50,round((case mag.magaza_kategori when 'market' then 600
    when 'fastfood' then 450 else 380 end)*coalesce(mag.te,1))::integer);
  insert into oyun.eko_sehir_musteri_limiti(il_id,kategori,gun,ust_sinir)
  values(mag.il_id,mag.magaza_kategori,(t at time zone 'Europe/Istanbul')::date,v_sehir_ust)
  on conflict(il_id,kategori,gun) do update set ust_sinir=excluded.ust_sinir;
  select greatest(0,lim.ust_sinir-lim.satilan) into v_sehir_kalan
  from oyun.eko_sehir_musteri_limiti lim where lim.il_id=mag.il_id
    and kategori=mag.magaza_kategori and gun=(t at time zone 'Europe/Istanbul')::date for update;
  if v_sehir_kalan<=0 then continue;end if;
  v_musteri:=case mag.magaza_kategori
    when 'fastfood' then case when v_saat between 11 and 15 then 'Öğle yemeği müşterileri' else 'Çalışanlar, öğrenciler ve aileler' end
    when 'kahve' then case when v_saat between 7 and 11 then 'Sabah kahvesi müşterileri' else 'Öğrenciler ve ofis çalışanları' end
    else 'Mahalle sakinleri ve aileler' end;
  select count(*) into rakip from oyun.eko_isletmeler ei join oyun.sirketler s
  on s.id=ei.sirket_id and s.aktif where ei.tur='magaza' and ei.il_id=mag.il_id;
  select * into f from oyun.eko_franchise where sube=mag.sirket_id;
  if f.id is not null then select * into m from oyun.eko_markalar where sirket_id=f.marka;end if;
  for item in select st.*,k.kullanim,k.talep,k.onerilen_satis from oyun.eko_urun_stok st
      join oyun.eko_urun_katalog k on k.kod=st.urun and k.aktif
      where st.sirket_id=mag.sirket_id and st.adet>0 and st.satis_fiyati>0
      order by st.urun for update of st skip locked
  loop
    -- Yerel fiyat düzeyine göre makul fiyat ve ilin alım gücü
    faktor:=greatest(.12,least(1.4,(item.onerilen_satis*coalesce(mag.fd,1)/greatest(item.satis_fiyati,1))^.8))
      *coalesce(mag.ag,1)
      /(1+greatest(0,rakip-1)*.1);
    if mag.magaza_kategori<>'market' and mag.magaza_kategori<>item.kullanim then faktor:=faktor*.22;end if;
    faktor:=faktor*v_saat_carpan;
    if item.talep<=4 then
      talep:=case when (extract(epoch from v_donem)/3600+mag.sirket_id)::bigint%greatest(2,7-item.talep)=0
        then 1 else 0 end;
    else
      talep:=greatest(0,round((item.talep/8.0)*faktor)::integer);
    end if;
    siparis:=least(item.adet,talep,v_saat_kalan,v_sehir_kalan);
    if siparis<=0 then continue;end if;
    ciro:=round(siparis*item.satis_fiyati);
    maliyet:=round(siparis*item.maliyet_birim);
    personel:=round(ciro*.07);
    v_vergi:=oyun.eko_vergi_hesap('satis',ciro);
    royalty:=0;karpayi:=0;
    if f.id is not null then
     royalty:=round(ciro*f.komisyon/100);
     kardegeri:=greatest(0,ciro-maliyet-personel-v_vergi-royalty);
     karpayi:=round(kardegeri*f.kar_payi/100);
    end if;
    branch_taxbase:=greatest(0,ciro-maliyet-personel-v_vergi-royalty-karpayi);
    corp_branch:=oyun.eko_vergi_hesap('kar',branch_taxbase);
    brandgross:=royalty+karpayi;
    corp_brand:=case when f.id is not null then oyun.eko_vergi_hesap('kar',brandgross) else 0 end;
    net:=ciro-maliyet-personel-v_vergi-royalty-karpayi-corp_branch;
    insert into oyun.eko_npc_satis(sirket_id,urun,donem,adet,ciro,mal_maliyeti,personel_gideri,
       vergi,isim_hakki,kar_paylasim,net_kar,musteri_kesimi)
       values(mag.sirket_id,item.urun,v_donem,siparis,ciro,maliyet,personel,v_vergi+corp_branch,royalty,karpayi,net,v_musteri)
       on conflict(sirket_id,urun,donem) do nothing returning id into sale_id;
    if not found then continue;end if;
    if oyun.eko_vergi_tahsil(mag.sirket_id,'satis',ciro,'npc_sale',sale_id)<>v_vergi
      then raise exception 'Perakende satis vergisi uyusmuyor.';end if;
    if oyun.eko_vergi_tahsil(mag.sirket_id,'kar',branch_taxbase,'npc_branch',sale_id)<>corp_branch
      then raise exception 'Magaza kurumlar vergisi uyusmuyor.';end if;
    if f.id is not null and corp_brand>0 then
      if oyun.eko_vergi_tahsil(f.marka,'kar',brandgross,'npc_brand',sale_id)<>corp_brand
       then raise exception 'Franchise kurumlar vergisi uyusmuyor.';end if;
    end if;
    update oyun.eko_urun_stok set adet=adet-siparis,guncelleme=t where sirket_id=mag.sirket_id and urun=item.urun;
    update oyun.sirketler set kasa=kasa+ciro-personel-v_vergi-royalty-karpayi-corp_branch where id=mag.sirket_id;
    if f.id is not null and (royalty+karpayi)>0 then
      update oyun.sirketler set kasa=kasa+royalty+karpayi-corp_brand where id=f.marka and aktif;
    end if;
    perform oyun.eko_kar_yaz(mag.sirket_id,'magaza',sale_id,ciro,
      v_vergi+corp_branch,net,t);
    if f.id is not null and brandgross>0 then
      perform oyun.eko_kar_yaz(f.marka,'franchise',sale_id,brandgross,
      corp_brand,brandgross-corp_brand,t);
    end if;
    update oyun.eko_sehir_musteri_limiti set satilan=oyun.eko_sehir_musteri_limiti.satilan+siparis
    where il_id=mag.il_id and kategori=mag.magaza_kategori
    and gun=(t at time zone 'Europe/Istanbul')::date and oyun.eko_sehir_musteri_limiti.satilan+siparis<=oyun.eko_sehir_musteri_limiti.ust_sinir;
    if not found then raise exception 'Şehir talep limiti değişti, satış tekrar denenmeli.';end if;
    v_sehir_kalan:=v_sehir_kalan-siparis;
    v_saat_kalan:=v_saat_kalan-siparis;
    satilan:=satilan+siparis;
  end loop;
 end loop;
 return jsonb_build_object('uretimler',yapilan,'oto_alimlar',alim,'satilan_adet',satilan);
end $function$;

-- oyun.halka_arz_net_tahmin(bigint,numeric)
CREATE OR REPLACE FUNCTION oyun.halka_arz_net_tahmin(p_sirket bigint, p_ek_sermaye numeric DEFAULT 0)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE s oyun.sirketler; v jsonb; ps oyun.pazar_sirket; k oyun.pazar_sektor;
  yeni_sermaye numeric; yeni_gelir numeric; yeni_gider numeric; eski_personel numeric;
  yeni_personel numeric; talep numeric; diger_gider numeric; ceza numeric; ruhsat numeric; brut numeric; v_kurumlar numeric;
BEGIN
  SELECT * INTO s FROM oyun.sirketler WHERE id=p_sirket AND aktif;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Şirket bulunamadı'; END IF;
  yeni_sermaye := s.sermaye+greatest(0,coalesce(p_ek_sermaye,0));
  v := oyun.pazar_tahmin(p_sirket);
  IF v IS NULL THEN
    RETURN oyun.sirket_ort_net(yeni_sermaye,s.sektor);
  END IF;
  -- İlk tutar, şirket yönetimi ekranındaki 7 günlük canlı pazar tahminiyle bire bir aynıdır.
  IF coalesce(p_ek_sermaye,0)<=0 THEN RETURN (v->>'net')::numeric; END IF;
  SELECT * INTO ps FROM oyun.pazar_sirket WHERE sirket_id=p_sirket;
  SELECT * INTO k FROM oyun.pazar_sektor WHERE kod=s.sektor;
  -- Talep mevcut fiyat, rakip ve şehir şartlarına dayanır; yatırım kapasiteyi yükseltebilir.
  talep := (v->>'pazar')::numeric * (v->>'pay')::numeric / 100 * oyun.pazar_fiyat_katsayi(ps.fiyat);
  yeni_gelir := least(talep,yeni_sermaye*k.kapasite);
  eski_personel := (v->>'personel')::numeric;
  yeni_personel := eski_personel *
    power(greatest(.5,yeni_sermaye/400000)/greatest(.5,s.sermaye/400000),.7);
  diger_gider := greatest(0,(v->>'gider')::numeric-eski_personel)*yeni_sermaye/nullif(s.sermaye,0);
  yeni_gider := yeni_personel+diger_gider;
  ceza := CASE WHEN (v->>'ceza')::numeric>0 THEN yeni_gelir*.12 ELSE 0 END;
  ruhsat := yeni_gelir * (v->>'ruhsat_oran')::numeric/100;
  brut := yeni_gelir-yeni_gider-ruhsat-ceza;
  SELECT kurumlar INTO v_kurumlar FROM oyun.pazar_ayar WHERE id=1;
  RETURN round(brut-greatest(0,brut)*coalesce(v_kurumlar,0)/100);
END $function$;

-- oyun.npc_isletme_tick()
CREATE OR REPLACE FUNCTION oyun.npc_isletme_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s record; st record;
 t timestamptz:=now(); v_gun date:=(now() at time zone 'Europe/Istanbul')::date;
 v_lim integer; v_satilan integer; v_adet integer; v_rakip integer;
 v_gelir numeric; v_maliyet numeric; v_kdv numeric; v_kurum numeric; v_diger numeric; v_bakim numeric;
 v_kar numeric; v_satis_id bigint; v_n integer:=0; v_ciro numeric:=0;
 v_tlm numeric:=oyun.pazar_tl_milyar(); v_oran numeric:=oyun.eko_vergi_oran('kdv');
 v_kv numeric:=oyun.eko_vergi_oran('kurumlar');
 v_tavan_oran numeric:=oyun.tf('npc_marj_tavan'); v_tavan numeric; v_marj numeric; v_birim numeric;
begin
 if not oyun.uzaktan_modul_acik('npc_isletme') then return jsonb_build_object('durdu',true); end if;
 if not pg_try_advisory_xact_lock(444722,7) then return jsonb_build_object('kilitli',true); end if;
 for s in
 select c.id,c.ad,c.kasa,c.sermaye,c.sektor,p.il_id,d.gelisim,
       -- Şehirdeki müşteri sayısı ilin nüfusu ve gelirine göre (161); harcama ilin alım gücüne göre
       oyun.il_talep_endeksi(p.il_id) as sehir_carpani,
       oyun.il_alim_gucu(p.il_id) as alim_gucu
 from oyun.sirketler c join oyun.pazar_sirket p on p.sirket_id=c.id
 join oyun.il_durum d on d.il_id=p.il_id
 where c.aktif and exists(select 1 from oyun.npc_urun_katalog n where n.sektor=c.sektor)
 order by c.id limit 400
 loop
  perform pg_advisory_xact_lock(98763,hashtext(s.id::text));
  perform 1 from oyun.sirketler where id=s.id for update;
  insert into oyun.npc_son_saat(sirket_id,son_saat) values(s.id,t) on conflict do nothing;
  update oyun.npc_son_saat set son_saat=t
  where sirket_id=s.id and son_saat<=t-interval '15 minutes';
  if not found then continue; end if;
  v_bakim:=least(greatest(0,(select kasa from oyun.sirketler where id=s.id)),
    round((10+s.sermaye*0.00008)/4,2));
  if v_bakim>0 then
   update oyun.sirketler set kasa=kasa-v_bakim where id=s.id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
   values(s.id,t,-v_bakim,'NPC mağaza 15 dakikalık personel, enerji ve bakım',0,v_bakim,0);
  end if;
  v_tavan:=greatest(0,coalesce(s.sermaye,0))*v_tavan_oran/100;
  select coalesce((select m.marj from oyun.npc_marj_gun m where m.sirket_id=s.id and m.gun=v_gun),0) into v_marj;
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
    v_lim:=greatest(1,round(2*st.gunluk_talep*greatest(0.3,least(4,s.sehir_carpani))*
      (1+oyun.belediye_yatirim_oran(s.il_id,'talep'))));
    v_adet:=least(st.adet,greatest(0,v_lim-v_satilan),
       greatest(0,floor(st.gunluk_talep*greatest(0.3,least(4,s.sehir_carpani))/30*
       (0.65+random()*.7)/sqrt(greatest(1,v_rakip))*
       coalesce(s.alim_gucu,1)*
       greatest(0.2,least(1.7,power(
       oyun.npc_piyasa_fiyati(st.urun,s.il_id,'satis')/greatest(st.satis_fiyati,0.01),3)))
       +random())::integer));
    if v_adet<=0 then continue; end if;
    v_birim:=st.satis_fiyati-st.alis_ortalama;
    if v_tavan_oran>0 and v_birim>0 then
      -- Oto galerisinde 2,5% sermaye kar tavanı tek aracı tümden kilitlemesin.
      -- İşlem hacmi dengesi: yüksek fiyatlı araçta en fazla 1 NPC araç/gün.
      v_adet:=least(v_adet,
        case when s.sektor='oto_galeri' and st.urun='oto' then 1 else v_adet end,
        greatest(0,floor((
          case when s.sektor='oto_galeri' and st.urun='oto'
               then greatest(v_tavan,v_birim) else v_tavan end
          -v_marj)/v_birim))::integer);
      if v_adet<=0 then continue; end if;
    end if;
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
    v_marj:=v_marj+greatest(0,v_gelir-v_maliyet);
    insert into oyun.npc_marj_gun(sirket_id,gun,marj) values(s.id,v_gun,greatest(0,v_gelir-v_maliyet))
      on conflict (sirket_id,gun) do update set marj=oyun.npc_marj_gun.marj+excluded.marj;
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

-- oyun.pazar_hesapla(bigint)
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
    if kasa_son < 0 then
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

-- oyun.pazar_tahmin(bigint,smallint,smallint,text,timestamp with time zone)
CREATE OR REPLACE FUNCTION oyun.pazar_tahmin(p_sirket bigint, p_fiyat smallint DEFAULT NULL::smallint, p_kalite smallint DEFAULT NULL::smallint, p_kaynak text DEFAULT NULL::text, t timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare s oyun.sirketler; ps oyun.pazar_sirket; k oyun.pazar_sektor; u oyun.ulke; zt timestamptz := coalesce(t, oyun.simdi());
  v_f smallint; v_k smallint; v_kay text; w numeric; makro numeric; pol numeric; pazar numeric; dis numeric; kamu numeric;
  ben numeric; toplam numeric; pay numeric; gelir numeric; kap numeric; gider numeric; personel numeric; ruh numeric; ruhsat numeric;
  vergi numeric; net numeric; ceza numeric := 0; kalite_gid numeric; kaynak_gid numeric := 0; rakip int; usd numeric; pold text;
  sabit numeric; talep numeric; reklam_oran numeric; reklam numeric; tes jsonb; kv numeric; sgk numeric; brut numeric; v_sube jsonb;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  select * into k from oyun.pazar_sektor where kod = s.sektor;
  if s.id is null or ps.sirket_id is null or k.kod is null then return null; end if;
  select * into u from oyun.ulke where id = 1;
  v_f := coalesce(p_fiyat, ps.fiyat); v_k := coalesce(p_kalite, ps.kalite);
  v_kay := case when s.sektor = 'enerji' then coalesce(p_kaynak, ps.kaynak, 'dogalgaz') else null end;

  w := oyun.pazar_il_agirlik(ps.il_id);
  makro := case when s.sektor in ('enerji','sanayi','insaat') then oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.06, 0.7, 1.4)
                else oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.03 + (coalesce(u.memnuniyet, 50) - 50) * 0.004, 0.8, 1.25) end;
  pold := oyun.sektor_pol_durum(s.sektor, zt);
  pol := case pold when 'tesvik' then 1.15 when 'denetim' then 0.92 else 1 end;
  pazar := k.taban * w * makro * pol * oyun.kriz_sektor_carpani(s.sektor, zt);

  kamu := coalesce((select kasa from oyun.bakanlik_kasa where kod = k.bakanlik), 20);
  dis := k.dis * (0.85 + least(greatest(kamu, 0), 60) / 100.0);

  ben := (1 + 0.35 * v_k + ps.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(v_f), k.esneklik);
  select coalesce(sum((1 + 0.35 * p2.kalite + p2.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p2.fiyat), k.esneklik)), 0), count(*)
    into toplam, rakip
  from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
  where p2.il_id = ps.il_id and s2.sektor = s.sektor and s2.aktif and p2.sirket_id <> s.id;
  pay := ben / (dis + toplam + ben);
  kap := s.sermaye * k.kapasite;
  talep := pazar * pay;
  gelir := least(talep, kap) * oyun.pazar_fiyat_katsayi(v_f);

  tes := oyun.bolge_tesvik(ps.il_id);
  sgk := (tes->>'sgk_destek')::numeric;
  personel := coalesce(u.asgari, 30000) * k.personel * power(greatest(0.25, s.sermaye / 400000.0), 0.7) * (1 - sgk / 100);
  kalite_gid := s.sermaye * case v_k when 1 then 0.01 when 2 then 0.022 when 3 then 0.036 else 0 end;
  sabit := s.sermaye * k.sabit;
  if v_kay = 'komur' then sabit := sabit * 0.75;
  elsif v_kay = 'dogalgaz' then
    usd := coalesce((select fiyat from oyun.piyasa_varlik where kod = 'USD'), 42);
    kaynak_gid := s.sermaye * 0.015 * usd / 42.0;
  elsif v_kay = 'yenilenebilir' then sabit := sabit + s.sermaye * 0.02;
  end if;
  reklam_oran := (array[0, 0.015, 0.03, 0.05])[coalesce(ps.reklam, 0) + 1];
  -- Merkez faaliyetinin yanina her ek subenin kendi cirosu ve maliyeti eklenir.
  v_sube := oyun.sube_pazar_tahmin(p_sirket,v_f,v_k,zt);
  gelir := gelir + coalesce((v_sube->>'gelir')::numeric,0);
  sabit := sabit + coalesce((v_sube->>'sabit')::numeric,0);
  personel := personel + coalesce((v_sube->>'personel')::numeric,0);
  reklam := gelir * reklam_oran;
  gider := sabit + personel + kalite_gid + kaynak_gid + reklam
           + coalesce((v_sube->>'stok')::numeric,0);

  if pold = 'denetim' and (v_k = 0 or v_kay = 'komur') then ceza := gelir * 0.12; end if;
  ruh := coalesce((select oran from oyun.il_ruhsat where il_id = ps.il_id), 0);
  ruhsat := gelir * ruh / 100;
  brut := gelir - gider - ruhsat - ceza;
  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), (select kurumlar from oyun.pazar_ayar where id = 1));
  vergi := greatest(0, brut) * kv / 100 * (1 - (tes->>'vergi_indirim')::numeric / 100);
  net := brut - vergi;
  return jsonb_build_object('sube_sayisi',coalesce((v_sube->>'sube_sayisi')::int,0),
    'sube_gelir',coalesce((v_sube->>'gelir')::numeric,0),
    'sube_gider',coalesce((v_sube->>'gider')::numeric,0),
    'sube_detaylar',coalesce(v_sube->'subeler','[]'::jsonb),
    'pazar', round(pazar), 'pay', round(pay * 100, 1), 'rakip', rakip, 'gelir', round(gelir),
    'talep', round(talep), 'kapasite', round(kap), 'kapasite_dolu', talep >= kap - 1, 'gider', round(gider), 'personel', round(personel),
    'kalite_gider', round(kalite_gid), 'kaynak_gider', round(kaynak_gid), 'sabit', round(sabit), 'reklam', round(reklam),
    'reklam_seviye', coalesce(ps.reklam, 0),
    'ruhsat', round(ruhsat), 'ruhsat_oran', ruh, 'ceza', round(ceza), 'vergi', round(vergi), 'net', round(net),
    'gunluk_net', round(net / 7), 'kurumlar_orani', kv,
    'bolge', (tes->>'bolge')::int, 'vergi_indirim', (tes->>'vergi_indirim')::int, 'sgk_destek', (tes->>'sgk_destek')::int,
    'politika', pold, 'kamu_guc', round(dis, 2),
    'fiyat', v_f, 'kalite', v_k, 'kaynak', v_kay, 'getiri', round(net / s.sermaye * 100, 1));
end $function$;

-- oyun.sube_bolge_analiz(bigint,smallint,smallint,smallint,timestamp with time zone)
CREATE OR REPLACE FUNCTION oyun.sube_bolge_analiz(p_sirket bigint, p_il smallint, p_fiyat smallint DEFAULT NULL::smallint, p_kalite smallint DEFAULT NULL::smallint, p_an timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
 s oyun.sirketler;ps oyun.pazar_sirket;k oyun.pazar_sektor;u oyun.ulke;
 zt timestamptz:=coalesce(p_an,oyun.simdi());
 vf smallint;vq smallint;price_factor numeric;macro numeric;policy_factor numeric;
 market_size numeric;mine numeric;other_comp numeric:=0;self_count int:=0;
 share_ratio numeric;demand numeric;capacity numeric;revenue numeric;
 wage numeric;fixed_cost numeric;stock numeric;cost numeric;
 sgk numeric;ts jsonb;competitors int:=0;tax_rate numeric;tax numeric;
 advertising numeric;license_rate numeric;lic_fees numeric;pre_tax numeric;net numeric;
 fitout numeric;deposit numeric;opening_stock numeric;training numeric;
 initial_permits numeric;cost_to_open numeric;operating_reserve numeric;
 years_weeks int;city_name text; sector_stock_ratio numeric;enterprise_cost_factor numeric;
begin
 select * into s from oyun.sirketler where id=p_sirket;
 select * into ps from oyun.pazar_sirket where sirket_id=p_sirket;
 select * into k from oyun.pazar_sektor where kod=s.sektor;
 select * into u from oyun.ulke where id=1;
 select ad into city_name from oyun.iller where id=p_il;
 if s.id is null or ps.sirket_id is null or k.kod is null or city_name is null then
  raise exception 'Şirketin veya ilin geçerli pazar bilgisi bulunamadı.';
 end if;
 vf:=coalesce(p_fiyat,ps.fiyat);
 vq:=coalesce(p_kalite,ps.kalite);
 price_factor:=oyun.pazar_fiyat_katsayi(vf);
 macro:=case when s.sektor in ('enerji','sanayi','insaat') then
  oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.06,0.7,1.4)
  else oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.03+
       (coalesce(u.memnuniyet,50)-50)*0.004,0.8,1.25) end;
 policy_factor:=oyun.sektor_pol_carpan(s.sektor,zt)*oyun.kriz_sektor_carpani(s.sektor,zt);
 market_size:=k.taban*oyun.pazar_il_agirlik(p_il)*macro*policy_factor;
 mine:=(1+0.35*vq+ps.marka/100.0)/power(price_factor,k.esneklik);
 select coalesce(sum((1+0.35*p2.kalite+p2.marka/100.0)/
   power(oyun.pazar_fiyat_katsayi(p2.fiyat),k.esneklik)),0),count(*)
 into other_comp,competitors
 from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id=p2.sirket_id
 where s2.aktif and s2.sektor=s.sektor and s2.id<>s.id
  and (p2.il_id=p_il or exists(
   select 1 from oyun.sirket_il_subeleri sb
    where sb.sirket_id=s2.id and sb.il_id=p_il and sb.acilis<=zt));
 -- Aynı şehirde şirketin mevcut merkezi de bölgesel müşteri talebini paylaşır.
 select (case when ps.il_id=p_il then 1 else 0 end)+count(*) into self_count
 from oyun.sirket_il_subeleri sb
 where sb.sirket_id=p_sirket and sb.il_id=p_il and sb.acilis<=zt;
 share_ratio:=mine/(k.dis*(0.85+least(greatest(
   coalesce((select kasa from oyun.bakanlik_kasa where kod=k.bakanlik),20),0),60)/100.0)
   +other_comp+mine*greatest(1,self_count));
 demand:=market_size*share_ratio;
 capacity:=greatest(15000,least(s.sermaye*k.kapasite*0.8,180000));
 revenue:=round(least(demand,capacity)*price_factor);
 ts:=oyun.bolge_tesvik(p_il);
 sgk:=coalesce((ts->>'sgk_destek')::numeric,0);
 wage:=round(coalesce(u.asgari,30000)/4.3*
    (1.35+0.25*k.personel+0.13*vq)*(1-sgk/100));
 fixed_cost:=round(greatest(2500,coalesce(u.asgari,30000)*0.12)*
    oyun.il_kurulus_endeksi(p_il));
 sector_stock_ratio:=case
  when s.sektor='market' then 0.78
  when s.sektor in ('ticaret','e_ticaret','yapi_market','mobilya_magaza',
                  'elektronik_magaza','tekstil_magaza') then 0.63
  when s.sektor in ('akaryakit','oto_galeri') then 0.83
  when s.sektor in ('turizm','danismanlik','ozel_okul','ozel_hastane','oto_servis')
   then 0.28
  else 0.42 end;
 stock:=round(revenue*sector_stock_ratio);
 cost:=wage+fixed_cost+stock;
 advertising:=round(revenue*(array[0,0.015,0.03,0.05])[coalesce(ps.reklam,0)+1]);
 license_rate:=coalesce((select oran from oyun.il_ruhsat where il_id=p_il),0);
 lic_fees:=round(revenue*license_rate/100);
 pre_tax:=revenue-cost-advertising-lic_fees;
 tax_rate:=coalesce(nullif(oyun.eko_vergi_oran('kurumlar'),0),
                    (select kurumlar from oyun.pazar_ayar where id=1));
 tax:=round(greatest(0,pre_tax)*tax_rate/100*
    (1-coalesce((ts->>'vergi_indirim')::numeric,0)/100));
 net:=pre_tax-tax;

 enterprise_cost_factor:=case when s.sektor='market' then 0.90
   when s.sektor in ('ticaret','e_ticaret','tekstil_magaza','elektronik_magaza','mobilya_magaza','yapi_market') then 0.75
   when s.sektor in ('turizm','ozel_hastane','sanayi','enerji') then 1.80
   when s.sektor in ('akaryakit','oto_galeri') then 1.55
   else 1.10 end;
 fitout:=round(greatest(35000*oyun.il_kurulus_endeksi(p_il),revenue*enterprise_cost_factor));
 deposit:=round(fixed_cost*6);
 opening_stock:=round(stock*1.5);
 training:=round(wage*1.5);
 initial_permits:=round(greatest(6000,revenue*0.04));
 cost_to_open:=fitout+deposit+opening_stock+training+initial_permits;
 operating_reserve:=round(greatest(20000,(wage+fixed_cost+stock*0.28)*2));
 years_weeks:=case when net>0 then ceil(cost_to_open/net)::int else null end;
 return jsonb_build_object(
  'il_id',p_il,'il',city_name,'sektor',s.sektor,'sektor_ad',k.ad,
  'haftalik_ciro',revenue,'haftalik_personel',wage,'haftalik_sabit',fixed_cost,
  'haftalik_urun_maliyeti',stock,'haftalik_reklam',advertising,
  'haftalik_harc',lic_fees,'haftalik_vergi',tax,'haftalik_gider',cost+advertising+lic_fees+tax,
  'haftalik_net',net,'pay',round(share_ratio*100,1),'rakip',competitors,
  'dekorasyon_donanim',fitout,'depozito',deposit,'ilk_stok',opening_stock,
  'personel_hazirlik',training,'izin_ruhsat',initial_permits,
  'acilis_maliyeti',cost_to_open,'isletme_rezervi',operating_reserve,
  'gerekli_kasa',cost_to_open+operating_reserve,
  'geri_donus_hafta',years_weeks);
end $function$;

-- pazar_danisman(bigint)
CREATE OR REPLACE FUNCTION public.pazar_danisman(p_sirket bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; ps oyun.pazar_sirket; h jsonb; en jsonb; saglik text;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  if s.id is null or ps.sirket_id is null then raise exception 'Rekabetçi şirket bulunamadı.'; end if;
  if not s.aktif then return jsonb_build_object('saglik', 'iflas', 'otopilot', ps.otopilot); end if;
  h := oyun.pazar_tahmin(s.id);
  en := oyun.pazar_en_iyi(s.id);
  saglik := case when s.kasa < s.sermaye * 0.25 then 'iflas_riski'
                 when (h->>'net')::numeric > s.sermaye * 0.01 then 'karda'
                 when (h->>'net')::numeric >= -s.sermaye * 0.005 then 'basabas' else 'zararda' end;
  return jsonb_build_object('saglik', saglik, 'otopilot', ps.otopilot, 'oneri', en,
    'oneri_farkli', en is not null and ((en->>'fiyat')::int <> ps.fiyat or (en->>'kalite')::int <> ps.kalite),
    'mevcut_net', (h->>'net')::numeric, 'yonetici_ucret', (select yonetici_ucret from oyun.pazar_ayar where id = 1),
    'otopilot_net', case when en is not null then round((en->>'net')::numeric - (en->>'gelir')::numeric * (select yonetici_ucret from oyun.pazar_ayar where id = 1) / 100 * 0.8) end,
    'yonetici', oyun.sirket_yonetici_mi(s.id, p.id));
end $function$;

commit;
