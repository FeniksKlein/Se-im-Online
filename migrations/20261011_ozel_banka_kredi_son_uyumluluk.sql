BEGIN;
-- Legacy hourly bank loans stay functional.
CREATE OR REPLACE FUNCTION oyun.oyb_kredi_urun_dogrula()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE ur oyun.oyb_kredi_urun;
BEGIN
 IF new.saat IN (1,3,6,12) THEN RETURN new; END IF; -- legacy short-hour products unaffected
 SELECT * INTO ur FROM oyun.oyb_kredi_urun
 WHERE banka_id=new.banka_id AND saat=new.saat AND aktif;
 IF NOT FOUND THEN RAISE EXCEPTION 'Banka bu kredi vadesini sunmuyor'; END IF;
 new.taksit_sayisi:=ur.taksit_sayisi;
 new.oran:=least(19.50,round(new.oran+ur.ek_faiz,2));
 new.toplam:=round(new.anapara*(1+new.oran/100));
 new.kalan:=new.toplam;
 RETURN new;
END $function$;
-- Return actual interest and total stored by the product trigger.
CREATE OR REPLACE FUNCTION public.oyb_kredi_basvur(p_banka bigint, p_tutar numeric, p_saat integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    u uuid:=auth.uid();
    bank oyun.sirketler;
    risk jsonb;
    faiz numeric;
    toplam numeric;
    yeni_id bigint;
BEGIN
    IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
    IF p_tutar IS NULL OR p_tutar<>trunc(p_tutar) OR p_tutar<1000 OR p_tutar>500000 THEN
        RAISE EXCEPTION 'Kredi 1.000 - 500.000 TL arasinda tam TL olmali';
    END IF;
    IF p_saat NOT IN (1,3,6,12,24,72,168,336,504,672) OR p_saat IS NULL THEN
        RAISE EXCEPTION 'Vade 1 gun, 3 gun, 1, 2, 3, 4 hafta veya saatlik olabilir';
    END IF;
    SELECT * INTO bank FROM oyun.sirketler
      WHERE id=p_banka AND aktif AND sektor='banka';
    IF NOT FOUND THEN RAISE EXCEPTION 'Banka bulunamadi'; END IF;
    IF EXISTS(SELECT 1 FROM oyun.sirket_ortaklari
      WHERE sirket_id=p_banka AND user_id=u AND pay>0) THEN
        RAISE EXCEPTION 'Kendi bankandan kredi alamazsin';
    END IF;
    IF EXISTS(SELECT 1 FROM oyun.oyb_kredi
      WHERE borclu=u AND durum IN ('basvuru','aktif')) THEN
        RAISE EXCEPTION 'Once diger oyuncu bankasi kredini kapat veya yanitini bekle';
    END IF;

    risk:=public.kredi_uygunluk(p_banka,p_saat);
    IF p_tutar>(risk->>'azami_kredi')::numeric THEN
        RAISE EXCEPTION 'Kredi reddedildi: %. Azami limit % TL; notun %.',
          risk->>'neden',risk->>'azami_kredi',risk->>'kredi_notu';
    END IF;
    faiz:=(risk->>'oran')::numeric;
    toplam:=round(p_tutar*(1+faiz/100));
    INSERT INTO oyun.oyb_kredi(banka_id,borclu,anapara,saat,oran,toplam,kalan)
    VALUES(p_banka,u,p_tutar,p_saat,faiz,toplam,toplam) RETURNING id,oran,toplam INTO yeni_id,faiz,toplam;
    RETURN jsonb_build_object('id',yeni_id,'anapara',p_tutar,'toplam',toplam,
        'oran',faiz,'saat',p_saat,'durum','basvuru',
        'kredi_notu',risk->'kredi_notu','azami_kredi',risk->'azami_kredi');
END $function$;
-- A missed scheduled installment may trigger enforcement after a grace period.
CREATE OR REPLACE FUNCTION public.oyb_icra_baslat(p_kredi bigint, p_tur text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE k oyun.oyb_kredi;u uuid:=auth.uid();x bigint;t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 IF p_tur NOT IN ('gelir','mulk','hisse','karma') OR char_length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 20 AND 1500 THEN
 RAISE EXCEPTION 'Icra turu veya gerekce gecersiz';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_kredi FOR UPDATE;
 IF NOT FOUND OR k.durum<>'aktif' OR k.kalan<=0 THEN RAISE EXCEPTION 'Tahsil edilecek aktif kredi yok';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=k.banka_id AND user_id=u AND pay>=50) THEN
 RAISE EXCEPTION 'Banka yoneticisi degilsin';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.oyb_kredi_taksit x
    WHERE x.kredi_id=k.id AND x.odenen<x.tutar
      AND x.vade+interval '12 hours' <= t)
 THEN RAISE EXCEPTION 'Geciken kredi taksiti veya 12 saatlik ek odeme suresi yok';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.oyb_kredi_taksit WHERE kredi_id=k.id) THEN
 RAISE EXCEPTION 'Icra sozlesmesi bu sistemden onceki kredilere uygulanamaz';END IF;
 INSERT INTO oyun.oyb_icra(kredi_id,banka_id,borclu,basvuran,tur,gerekce,acilis,savunma_son)
 VALUES(k.id,k.banka_id,k.borclu,u,p_tur,trim(p_gerekce),t,t+interval '24 hours')
 RETURNING id INTO x;
 PERFORM oyun.bildir(k.borclu,'Adliyede kredi icra dosyasi #'||x||' acildi. Savunma icin 24 saatin var.',t);
 RETURN jsonb_build_object('id',x,'durum','acik','savunma_son',t+interval '24 hours');
END $function$;
COMMIT;
