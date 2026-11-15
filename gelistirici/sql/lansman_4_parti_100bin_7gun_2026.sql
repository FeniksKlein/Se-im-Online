-- YAYIN BASLANGICI: YALNIZCA TEST SIFIRLAMASI VE supabase-kurulum.sql SONRASI!
-- Kesin lansman tarihini belirlemeden bu dosyayi calistirma.
-- Bugunku test oyunu etkilenmemesi icin bu dosya sadece repoya eklenmistir.
-- Resmi lansmanda anayasal 600 sandalye, 360 erken secim, 200 anayasa imzasi,
-- 400/301 meclis baskanligi ve bagimsiz CB %3 imza sistemi etkinlesir.
-- Oncesinde oyun.oyunu_sifirla('OYUNU SIFIRLA') ile yedekli sifirlama yapilmali.
-- Eski hesaplarla yeniden profil acma ve satin-alma haklarini geri yukleme test edilmeli.
BEGIN;
SELECT pg_advisory_xact_lock(20261115,70007);
SET LOCAL oyun.takvim_kurali = '1';
DO $go$
DECLARE
  v_lansman timestamptz := NULL; -- ORNEK '2026-12-01 09:00:00+03'
  d date;
  p record;
BEGIN
  IF v_lansman IS NULL THEN
    RAISE EXCEPTION 'Lansman saati tanimlanmadan kurulum calismaz.';
  END IF;
  IF v_lansman < now()-interval '1 day' OR v_lansman > now()+interval '3 days' THEN
    RAISE EXCEPTION 'Gercek yayin saatini kontrol edin: %',v_lansman;
  END IF;
  IF EXISTS (SELECT 1 FROM oyun.profiller)
    OR EXISTS (SELECT 1 FROM oyun.cuzdan)
    OR EXISTS (SELECT 1 FROM oyun.sirketler)
    OR EXISTS (SELECT 1 FROM oyun.dernekler)
    OR EXISTS (SELECT 1 FROM oyun.gazete)
    OR EXISTS (SELECT 1 FROM oyun.oylar)
    OR EXISTS (SELECT 1 FROM oyun.adaylar)
    OR EXISTS (SELECT 1 FROM oyun.makamlar)
  THEN RAISE EXCEPTION 'Sifirlama tamamlanmamis. Eski oyun kayitlari var.'; END IF;
  IF (SELECT count(*) FROM oyun.partiler)<>5
     OR (SELECT count(*) FROM oyun.partiler WHERE sistem)<>5
     OR EXISTS (SELECT 1 FROM oyun.partiler WHERE id NOT IN (1,2,3,4,5))
  THEN RAISE EXCEPTION 'Beklenen 5 baslangic sistem partisi kurulumda bulunamadi.'; END IF;
  d:=(v_lansman AT TIME ZONE 'Europe/Istanbul')::date;

  UPDATE oyun.ayarlar
     SET baslangic=v_lansman, baslangic_para=100000, baraj=7,
         parti_kurucu_sayi=7, parti_kurulus_gun=10, parti_kur_ucret=500000,
         parti_kur_gun=90, test_simdi=NULL,
         gercekci_siyaset=true
   WHERE id=1;
  UPDATE oyun.tarife SET deger=CASE kod
    WHEN 'kilit_aktif' THEN 1 WHEN 'parti_kurucu_min' THEN 7
    WHEN 'parti_kurucu_max' THEN 30 WHEN 'parti_kurucu_oran' THEN 2
    WHEN 'parti_kurucu_statu' THEN 2 WHEN 'parti_ortak_statu' THEN 1
    WHEN 'parti_kurucu_hesap_gun' THEN 14 WHEN 'parti_ortak_hesap_gun' THEN 7
    WHEN 'parti_ortak_bekleme_gun' THEN 30 WHEN 'parti_basvuru_gun' THEN 10
    WHEN 'parti_katki_min' THEN 10000 WHEN 'parti_fon' THEN 1000000
    ELSE deger END
  WHERE kod IN ('kilit_aktif','parti_kurucu_min','parti_kurucu_max',
    'parti_kurucu_oran','parti_kurucu_statu','parti_ortak_statu',
    'parti_kurucu_hesap_gun','parti_ortak_hesap_gun','parti_ortak_bekleme_gun',
    'parti_basvuru_gun','parti_katki_min','parti_fon');

  -- Yeni oyuncu ilk cüzdanda TAM 100.000 TL ile baslasin.
  -- Onceki donemin devlet/sehir hosgeldin bonuslarini tasima.
  DELETE FROM oyun.duzenlemeler WHERE kod='yeni_hibe';
  DELETE FROM oyun.il_duzenleme WHERE kod='hosgeldin';

  -- Testte baraj hesabini atlatan butun adaylar vekil olabilsin modunu kapat.
  INSERT INTO oyun.mv_secim_modu(id,her_aday_vekil,aciklama)
  VALUES(1,false,'Gercek secim: parti veya ittifak toplaminda %7 baraji')
  ON CONFLICT (id) DO UPDATE SET her_aday_vekil=false,aciklama=EXCLUDED.aciklama;
  -- Daha once test oynayanlara ayricalikli 1.000.000 TL verilmesin.
  EXECUTE 'DROP TRIGGER IF EXISTS test_oncelikli_baslangic ON oyun.cuzdan';
  DELETE FROM oyun_yonetim.onceki_test_oyuncu;
  -- Ozel parti kurma ve eski kayit onayi istisnalari da yeni doneme kalmasin.
  DELETE FROM oyun_yonetim.ozel_parti_kurma_izni;
  DELETE FROM oyun_yonetim.kayit_basvurulari;
  -- Oyun semasi disindaki test eylem sohbeti ve canli sinyallerini temizle.
  DELETE FROM public.sokak_eylem_sohbet;
  DELETE FROM public.canli_sinyal;
  -- Belediyeler ilk girenlere otomatik dagitilmasin.
  EXECUTE 'DROP TRIGGER IF EXISTS yeni_oyuncu_baskan_ata ON oyun.profiller';

  UPDATE oyun.partiler SET gb=NULL,kurucu=NULL,gb_vekil=NULL,
      gb_vekil_bas=NULL,kimlik_alan=NULL,kasa=0,kapali=false,
      kurulus=v_lansman,kurulus_bit=NULL,kurulus_ucret=0,
      son_ad_degis=NULL,tuzuk=NULL,tuzuk_at=NULL,
      aday_ucret='{"cb_on":1,"mv_on":1,"bel_on":1,"kurultay":1}'::jsonb
  WHERE sistem;

  -- Besinci kapali sistem partisi (id=2) cikar; dort hazir parti kalir.
  DELETE FROM oyun.parti_teskilat WHERE parti_id=2;
  DELETE FROM oyun.partiler WHERE id=2;
  UPDATE oyun.partiler
    SET ad=CASE id WHEN 1 THEN 'Halk Partisi'
                   WHEN 3 THEN 'Sosyal Demokrasi Partisi'
                   WHEN 4 THEN 'Yeni Parti'
                   WHEN 5 THEN 'Muhafazakar Türkiye Partisi' END,
        kisa=CASE id WHEN 1 THEN 'HP' WHEN 3 THEN 'SDP'
                     WHEN 4 THEN 'YENİ' WHEN 5 THEN 'MTP' END,
        kapali=false,sistem=true
  WHERE id IN (1,3,4,5);

  -- Dort hazir parti tum illerde teskilatli; yeni parti kuranlar degil.
  INSERT INTO oyun.parti_teskilat
    (parti_id,il_id,kurulus,kuran,bedel,genel_merkez)
  SELECT pa.id,i.id,v_lansman,NULL,0,false
  FROM oyun.partiler pa CROSS JOIN oyun.iller i
  WHERE pa.id IN (1,3,4,5)
  ON CONFLICT (parti_id,il_id) DO NOTHING;

  -- Test/ilk kurulumdan gelebilecek bekleyen takvimi bastan kur.
  DELETE FROM oyun.secimler;

  -- Ilk genel baskan: basvuru lansmanda, 3. gun sandik.
  FOR p IN SELECT id FROM oyun.partiler WHERE sistem ORDER BY id LOOP
    INSERT INTO oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,
      oy_bas,oy_bit,sonuc_at,goreve_bas,ara,hedef_parti_id,ara_neden)
    VALUES('kurultay','lansman-gb-'||p.id||'-'||to_char(d,'YYYYMMDD'),
      v_lansman,oyun.tr_an(d+3,8),oyun.tr_an(d+3,8),
      oyun.tr_an(d+3,22),oyun.tr_an(d+3,22,30),
      oyun.tr_an(d+3,23),true,p.id,'lansman_ilk_kurultay');
  END LOOP;

  -- On secimler 5. gun, CB+MV genel secim 7. gun, 08:00-22:00 TSİ.
  INSERT INTO oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,
    oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden)
  VALUES
    ('mv_on','lansman-'||to_char(d,'YYYYMMDD'),
       oyun.tr_an(d+3,23),oyun.tr_an(d+5,8),oyun.tr_an(d+5,8),
       oyun.tr_an(d+5,22),oyun.tr_an(d+5,22,30),NULL,true,'lansman'),
    ('cb_on','lansman-'||to_char(d,'YYYYMMDD'),
       oyun.tr_an(d+3,23),oyun.tr_an(d+5,8),oyun.tr_an(d+5,8),
       oyun.tr_an(d+5,22),oyun.tr_an(d+5,22,30),NULL,true,'lansman'),
    ('mv','lansman-'||to_char(d,'YYYYMMDD'),NULL,NULL,
       oyun.tr_an(d+7,8),oyun.tr_an(d+7,22),oyun.tr_an(d+7,22,30),
       oyun.tr_an(d+8,0),true,'lansman'),
    ('cb','lansman-'||to_char(d,'YYYYMMDD'),
       oyun.tr_an(d+3,23),oyun.tr_an(d+6,8),
       oyun.tr_an(d+7,8),oyun.tr_an(d+7,22),oyun.tr_an(d+7,22,30),
       oyun.tr_an(d+8,0),true,'lansman');

  IF (SELECT count(*) FROM oyun.partiler WHERE sistem AND NOT kapali)<>4
     OR (SELECT count(*) FROM oyun.parti_teskilat WHERE parti_id IN (1,3,4,5))<>324
     OR (SELECT count(*) FROM oyun.secimler WHERE donem LIKE 'lansman-%')<>8
     OR (SELECT baslangic_para FROM oyun.ayarlar WHERE id=1)<>100000
     OR (SELECT baraj FROM oyun.ayarlar WHERE id=1)<>7
     OR NOT (SELECT gercekci_siyaset FROM oyun.ayarlar WHERE id=1)
     OR (SELECT her_aday_vekil FROM oyun.mv_secim_modu WHERE id=1)
  THEN RAISE EXCEPTION 'Lansman dogrulamasi basarisiz; transaction geri alinir.'; END IF;
END
$go$;
COMMIT;
-- NOT: cron yeniden acilmadan normal aylik otomatik takvimle cakisma kontrolu sart.
-- NOT: auth.users korunabilir, ancak profil/para/kidem sifirdan acilmasi test edilmelidir.
-- NOT: Gercek para ile edinilen haklar magasin restore-purchases mekanizmasiyla korunmalidir.
