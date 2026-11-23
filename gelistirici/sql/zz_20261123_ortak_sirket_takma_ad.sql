-- 23.11.2026 · ORTAK ŞİRKET KURULUŞU: "record "a" is not assigned yet" düzeltmesi (depo eşitlemesi)
-- Hata: 123/124'teki ortak_sirket_kur_tamamla'da döngü değişkeni "a" ile sorgudaki tablo takma adı "a" çakışıyordu;
-- ortaklar kabul ettikten sonra "Kuruluşu tamamla" her seferinde bu hatayla duruyordu.
-- Canlıda 23.11.2026 06:28'de düzeltildi (migration fix_ortak_sirket_kur_tamamla_kayit_takma_ad); bu dosya aynı gövdeyi
-- depoya alır ki tam kurulum eski hatalı gövdeyi geri getirmesin. Değişken r, takma ad kt; mantık aynı.
create or replace function public.ortak_sirket_kur_tamamla(p_id bigint) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); k oyun.ortak_sirket_kurulus;
 r record; sonuc jsonb; sid bigint; v_pay numeric; v_diger numeric:=0;
begin
 perform pg_advisory_xact_lock(98765,hashtext(p_id::text));
 select * into k from oyun.ortak_sirket_kurulus where id=p_id for update;
 if k.kurucu is distinct from p.id or k.durum<>'bekliyor' or k.bitis<=oyun.simdi()
  then raise exception 'Kuruluş teklifi geçersiz veya yetkisiz işlem.';end if;
 if exists(select 1 from oyun.ortak_sirket_katilim kt where kt.kurulus_id=p_id and kt.durum<>'kabul') then
  raise exception 'Kuruluş için tüm ortaklar daveti kabul etmeli.';end if;
 if (select count(*) from oyun.ortak_sirket_katilim kt where kt.kurulus_id=p_id)<2 or
  (select sum(kt.tutar) from oyun.ortak_sirket_katilim kt where kt.kurulus_id=p_id)<>k.toplam then
  raise exception 'Sermaye ve ortaklık toplamı uyuşmuyor.';end if;
 -- Oyuncu bakiyeleri kararlı sırayla kilitlenir, herkesin fonu teyit edilir.
 for r in select kt.user_id,kt.tutar from oyun.ortak_sirket_katilim kt
  where kt.kurulus_id=p_id order by kt.user_id loop
  perform 1 from oyun.cuzdan c where c.user_id=r.user_id and c.para>=r.tutar for update;
  if not found then raise exception '% için % ₺ kullanılabilir bakiye gerekli.',oyun.kad(r.user_id),oyun.tl(r.tutar);end if;
 end loop;
 -- Para hiçbir ara aşamada harcanmaz; tüm katılım tek DB işleminde kaydedilir.
 for r in select kt.user_id,kt.tutar from oyun.ortak_sirket_katilim kt
  where kt.kurulus_id=p_id and kt.user_id<>p.id order by kt.user_id loop
  perform oyun.para_islem(r.user_id,-r.tutar,'sirket',format('Ortak kuruluş sermayesi: %s',k.ad),oyun.simdi());
  perform oyun.para_islem(p.id,r.tutar,'sirket',format('Ortak kuruluş sermayesi aktarımı: %s',k.ad),oyun.simdi());
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
 for r in select kt.user_id,kt.tutar from oyun.ortak_sirket_katilim kt
  where kt.kurulus_id=p_id and kt.user_id<>p.id order by kt.user_id loop
  v_pay:=round(r.tutar*100/k.toplam,6);
  if v_pay<=0 then raise exception 'Ortak payı hesaplanamadı.';end if;
  insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(sid,r.user_id,v_pay);
  v_diger:=v_diger+v_pay;
 end loop;
 update oyun.sirket_ortaklari so set pay=100-v_diger where so.sirket_id=sid and so.user_id=p.id;
 if coalesce((select so.pay from oyun.sirket_ortaklari so where so.sirket_id=sid and so.user_id=p.id),0)<=0 then
  raise exception 'Kurucu payı hesaplanamadı.'; end if;
 update oyun.ortak_sirket_kurulus set durum='kuruldu',sirket_id=sid where id=p_id;
 for r in select kt.user_id from oyun.ortak_sirket_katilim kt where kt.kurulus_id=p_id loop
  perform oyun.bildir(r.user_id,format('%s ortak şirketi kuruldu. Şirketlerim bölümünde payını görebilirsin.',k.ad),oyun.simdi());
 end loop;
 return jsonb_build_object('tamam',true,'sirket_id',sid,'toplam',k.toplam);
end $function$;
