-- 2026-10-22: Ortak kuruluşu tüm pazar sektörlerini kapsayacak biçimde genişletir; mevcut şirketler etkilenmez.
create or replace function public.ortak_sirket_kur_teklif(
 p_ad text,p_sektor text,p_il integer,p_urun text,p_kendi numeric,p_ortaklar jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
 v_id bigint; v_toplam numeric:=0; v_kisi jsonb; v_tutar numeric;
 v_hedef oyun.profiller; v_kad text; v_adet int;
begin
 if p_ad is null or length(btrim(p_ad)) not between 3 and 50 then raise exception 'Şirket adı 3-50 karakter olmalı.';end if;
 if p_sektor not in ('tarim','sanayi','teknoloji','ticaret','insaat','medya') and not exists(select 1 from oyun.pazar_sektor where kod=p_sektor) then
  raise exception 'Ortak kuruluş için geçerli şirket sektörü seç.'; end if;
 if p_il is null or not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçerli il seç.';end if;
 if p_sektor='sanayi' and coalesce(p_urun,'malzeme') not in ('gida','teknoloji','malzeme') then
  raise exception 'Üretim grubu geçersiz.';end if;
 if p_kendi is null or p_kendi<=0 or p_kendi<>round(p_kendi) then raise exception 'Kendi sermayeni tam sayı gir.';end if;
 if p_ortaklar is null or jsonb_typeof(p_ortaklar)<>'array' then raise exception 'Davet listesi gerekli.';end if;
 v_adet:=jsonb_array_length(p_ortaklar);
 if v_adet<1 or v_adet>7 then raise exception 'En az 1, en fazla 7 ortak davet edebilirsin.';end if;
 v_toplam:=p_kendi;
 for v_kisi in select value from jsonb_array_elements(p_ortaklar) loop
  v_kad:=btrim(coalesce(v_kisi->>'kad',''));
  if length(v_kad)<2 then raise exception 'Geçerli oyuncu adı gir.'; end if;
  if coalesce(v_kisi->>'tutar','') !~ '^[0-9]+$' then raise exception '% için sermaye pozitif tam sayı olmalı.',v_kad;end if;
  v_tutar:=(v_kisi->>'tutar')::numeric;
  if v_tutar<=0 then raise exception 'Ortakların sermayesi sıfır olamaz.';end if;
  select * into v_hedef from oyun.profiller
   where lower(kad)=lower(v_kad) and not yasakli;
  if v_hedef.id is null or v_hedef.id=p.id then raise exception 'Oyuncu bulunamadı: %',v_kad;end if;
  v_toplam:=v_toplam+v_tutar;
 end loop;
 if v_toplam < 100000 or v_toplam>100000000 then
  raise exception 'Toplam kuruluş sermayesi 100.000–100.000.000 ₺ olmalı.';end if;
 if exists(select 1 from oyun.pazar_sektor where kod=p_sektor and min_sermaye>v_toplam) then
  raise exception 'Bu sektörün toplam kuruluş sermayesi yetersiz. Asgari sermaye: % ₺',
   oyun.tl((select min_sermaye from oyun.pazar_sektor where kod=p_sektor));end if;
 if p_sektor='enerji' and coalesce(p_urun,'dogalgaz') not in ('komur','dogalgaz','yenilenebilir') then
  raise exception 'Enerji üretim kaynağı geçersiz.';end if;
 insert into oyun.ortak_sirket_kurulus(kurucu,ad,sektor,il_id,urun,toplam)
 values(p.id,btrim(p_ad),p_sektor,p_il::smallint,nullif(p_urun,''),v_toplam) returning id into v_id;
 insert into oyun.ortak_sirket_katilim(kurulus_id,user_id,tutar,durum)
 values(v_id,p.id,p_kendi,'kabul');
 for v_kisi in select value from jsonb_array_elements(p_ortaklar) loop
  select * into v_hedef from oyun.profiller where lower(kad)=lower(btrim(v_kisi->>'kad')) and not yasakli;
  insert into oyun.ortak_sirket_katilim(kurulus_id,user_id,tutar)
  values(v_id,v_hedef.id,(v_kisi->>'tutar')::numeric);
  perform oyun.bildir(v_hedef.id,format('%s seni %s şirketine %s ₺ sermaye ile ortak olmaya davet etti. Şirketler > Ortaklık Merkezi ekranından yanıtla.',p.kad,p_ad,oyun.tl((v_kisi->>'tutar')::numeric)),oyun.simdi());
 end loop;
 return jsonb_build_object('tamam',true,'kurulus_id',v_id,'toplam',v_toplam);
end $$;

create or replace function public.ortak_sirket_kur_tamamla(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); k oyun.ortak_sirket_kurulus;
 a record; sonuc jsonb; sid bigint; v_pay numeric; v_diger numeric:=0;
begin
 perform pg_advisory_xact_lock(98765,hashtext(p_id::text));
 select * into k from oyun.ortak_sirket_kurulus where id=p_id for update;
 if k.kurucu is distinct from p.id or k.durum<>'bekliyor' or k.bitis<=oyun.simdi()
  then raise exception 'Kuruluş teklifi geçersiz veya yetkisiz işlem.';end if;
 if exists(select 1 from oyun.ortak_sirket_katilim where kurulus_id=p_id and durum<>'kabul') then
  raise exception 'Kuruluş için tüm ortaklar daveti kabul etmeli.';end if;
 if (select count(*) from oyun.ortak_sirket_katilim where kurulus_id=p_id)<2 or
  (select sum(tutar) from oyun.ortak_sirket_katilim where kurulus_id=p_id)<>k.toplam then
  raise exception 'Sermaye ve ortaklık toplamı uyuşmuyor.';end if;
 -- Oyuncu bakiyeleri kararlı sırayla kilitlenir, herkesin fonu teyit edilir.
 for a in select a.user_id,a.tutar from oyun.ortak_sirket_katilim a
  where a.kurulus_id=p_id order by a.user_id loop
  perform 1 from oyun.cuzdan where user_id=a.user_id and para>=a.tutar for update;
  if not found then raise exception '% için % ₺ kullanılabilir bakiye gerekli.',oyun.kad(a.user_id),oyun.tl(a.tutar);end if;
 end loop;
 -- Para hiçbir ara aşamada harcanmaz; tüm katılım tek DB işleminde kaydedilir.
 for a in select a.user_id,a.tutar from oyun.ortak_sirket_katilim a
  where a.kurulus_id=p_id and a.user_id<>p.id order by a.user_id loop
  perform oyun.para_islem(a.user_id,-a.tutar,'sirket',format('Ortak kuruluş sermayesi: %s',k.ad),oyun.simdi());
  perform oyun.para_islem(p.id,a.tutar,'sirket',format('Ortak kuruluş sermayesi aktarımı: %s',k.ad),oyun.simdi());
 end loop;
 if k.sektor in ('tarim','sanayi','teknoloji') then
  sonuc:=public.sirket_kur_aktif_ilde(k.ad,k.sektor,k.toplam,k.urun,k.il_id);
 elsif k.sektor in ('ticaret','insaat','medya') then
  sonuc:=public.sirket_kur_ilde(k.ad,k.sektor,k.toplam,k.il_id);
  if k.sektor='ticaret' then perform public.eko_ticaret_islem('bagla',jsonb_build_object('sirket',(sonuc->>'id')::bigint)); end if;
 else
  sonuc:=public.pazar_sirket_kur(k.ad,k.sektor,k.toplam,k.il_id,
    case when k.sektor='enerji' then coalesce(k.urun,'dogalgaz') else null end);
 end if;
 sid:=(sonuc->>'id')::bigint;
 -- Yuvarlama farkı yalnızca kurucunun payından düşülür; toplam tam %100 olur.
 for a in select user_id,tutar from oyun.ortak_sirket_katilim
  where kurulus_id=p_id and user_id<>p.id order by user_id loop
  v_pay:=round(a.tutar*100/k.toplam,6);
  if v_pay<=0 then raise exception 'Ortak payı hesaplanamadı.';end if;
  insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(sid,a.user_id,v_pay);
  v_diger:=v_diger+v_pay;
 end loop;
 update oyun.sirket_ortaklari set pay=100-v_diger where sirket_id=sid and user_id=p.id;
 if (select pay from oyun.sirket_ortaklari where sirket_id=sid and user_id=p.id)<=0 then
  raise exception 'Kurucu payı hesaplanamadı.'; end if;
 update oyun.ortak_sirket_kurulus set durum='kuruldu',sirket_id=sid where id=p_id;
 for a in select user_id from oyun.ortak_sirket_katilim where kurulus_id=p_id loop
  perform oyun.bildir(a.user_id,format('%s ortak şirketi kuruldu. Şirketlerim bölümünde payını görebilirsin.',k.ad),oyun.simdi());
 end loop;
 return jsonb_build_object('tamam',true,'sirket_id',sid,'toplam',k.toplam);
end $$;
