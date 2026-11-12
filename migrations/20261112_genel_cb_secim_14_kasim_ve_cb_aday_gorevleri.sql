-- 14 Kasim CB ve MV secimi; 13 Kasim 00.01 basvuru; CB kesin adaylikta makam ayriligi.
-- Yayin veritabani on yedegi: yedek_20261112_224134_994009
-- Canli veritabanina 12 Kasim'da uygulanmistir. Tekrar calistirmaya guvenlidir.

CREATE OR REPLACE FUNCTION oyun.cb_kesin_aday_gorev_birak()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_secim oyun.secimler;
  v_t timestamptz := oyun.simdi();
  v_m record;
  v_tbmm boolean := false;
BEGIN
  SELECT * INTO v_secim FROM oyun.secimler WHERE id=NEW.secim_id;
  IF v_secim.tur <> 'cb' OR v_secim.durum <> 'bekliyor' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND NEW.secim_id=OLD.secim_id AND NEW.user_id=OLD.user_id THEN RETURN NEW; END IF;
  PERFORM 1 FROM oyun.profiller WHERE id=NEW.user_id FOR UPDATE;

  -- Her türlü mevcut milletvekilliği ve mevcut cumhurbaşkanlığı korunur.
  -- Bakanlık, TBMM başkanlığı, belediye, grup başkan vekilliği, CB yardımcılığı ve diğer makamlar biter.
  FOR v_m IN
    SELECT id,tur,il_id FROM oyun.makamlar
     WHERE user_id=NEW.user_id AND bit IS NULL AND tur NOT IN ('mv','cb')
     ORDER BY id
  LOOP
    PERFORM oyun.makam_bitir(v_m.id,v_t,'cb_adayligi');
    IF v_m.tur='tbmm' THEN v_tbmm:=true; END IF;
    IF v_m.tur='bel' AND v_m.il_id IS NOT NULL THEN
      PERFORM oyun.ara_secim_olustur('bel',NULL,v_m.il_id,v_t);
    END IF;
  END LOOP;
  IF v_tbmm THEN PERFORM oyun.tbmm_ara_secim(v_t); END IF;

  -- Siyasi parti yönetimi adaylıktan ayrı tutulmaz: aday GB/GBY olarak kalamaz.
  DELETE FROM oyun.parti_gby WHERE user_id=NEW.user_id;
  UPDATE oyun.partiler SET gb=NULL WHERE gb=NEW.user_id AND NOT kapali;
  UPDATE oyun.partiler SET gb_vekil=NULL,gb_vekil_bas=NULL
    WHERE gb_vekil=NEW.user_id AND gb IS DISTINCT FROM NEW.user_id;

  -- Yüksek mahkemenin 3. üyesi Adalet Bakanlığıyla otomatik eşlenir.
  -- Diğer yargı üyeleri ve atanmış yargı makamı bırakılır.
  UPDATE oyun.mahkeme_uye SET user_id=NULL,gorev_bit=v_t,bos_since=v_t
    WHERE user_id=NEW.user_id AND sira<>3;
  UPDATE oyun.adliye_makam SET hakim=NULL,degistirme_at=v_t
    WHERE hakim=NEW.user_id;

  -- Diğer kamu/meslek/sivil toplum başkanlıkları; üyelik, kuruculuk, mülkiyet korunur.
  UPDATE oyun.oda SET baskan=NULL,baskan_bas=NULL,baskan_sendika=NULL WHERE baskan=NEW.user_id;
  UPDATE oyun.baro SET baskan=NULL,baskan_bas=NULL WHERE baskan=NEW.user_id;
  UPDATE oyun.dernekler SET baskan=NULL WHERE baskan=NEW.user_id;
  UPDATE oyun.sendika SET baskan=NULL WHERE baskan=NEW.user_id;

  PERFORM oyun.bildir(NEW.user_id,
    'Cumhurbaşkanı adaylığın kesinleşti. Mevcut milletvekilliğin ve varsa cumhurbaşkanlığın korundu; diğer siyasi ve kurumsal görevlerin sona erdi.',
    v_t);
  RETURN NEW;
END;
$function$

DROP TRIGGER IF EXISTS cb_kesin_aday_gorev_birak_tg ON oyun.adaylar;
CREATE TRIGGER cb_kesin_aday_gorev_birak_tg AFTER INSERT OR UPDATE OF secim_id,user_id ON oyun.adaylar FOR EACH ROW EXECUTE FUNCTION oyun.cb_kesin_aday_gorev_birak();

DO $once$
DECLARE
  t timestamptz:=oyun.simdi();
  d text:='erken-genel-14kasim2026';
  b timestamptz:=timestamptz '2026-11-13 00:01:00+03';
BEGIN
  PERFORM 1 FROM oyun.ayarlar WHERE id=1 FOR UPDATE;
  IF EXISTS(SELECT 1 FROM oyun.secimler WHERE tur='cb' AND donem=d) THEN
    RAISE NOTICE '14 Kasim secim kayitlari zaten var; korunuyor';
    RETURN;
  END IF;
  IF t>=b THEN RAISE EXCEPTION '14 Kasim 2026 secim adaylik baslangici gecti'; END IF;
  IF EXISTS (SELECT 1 FROM oyun.secimler WHERE tur IN ('mv_on','mv','cb_on','cb','cb2') AND durum='bekliyor' AND oy_bas<=t AND oy_bit>t) THEN
    RAISE EXCEPTION 'Devam eden secim var';
  END IF;
  IF oyun.hukumet_sistemi()<>0 THEN RAISE EXCEPTION 'CB secimi icin hukumet sistemi uygun degil'; END IF;
  INSERT INTO oyun.tek_seferlik(anahtar,zaman) VALUES('genel_cb_secim_20261114',t) ON CONFLICT DO NOTHING;
  INSERT INTO oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden)
  VALUES
  ('mv_on',d,b,timestamptz '2026-11-13 08:00+03',timestamptz '2026-11-13 08:00+03',timestamptz '2026-11-13 22:00+03',timestamptz '2026-11-13 22:30+03',null,true,'erken_secim'),
  ('mv',d,null,null,timestamptz '2026-11-14 08:00+03',timestamptz '2026-11-14 22:00+03',timestamptz '2026-11-14 22:30+03',timestamptz '2026-11-15 00:00+03',true,'erken_secim'),
  ('cb_on',d,b,timestamptz '2026-11-13 08:00+03',timestamptz '2026-11-13 08:00+03',timestamptz '2026-11-13 22:00+03',timestamptz '2026-11-13 22:30+03',null,true,'erken_secim'),
  ('cb',d,b,timestamptz '2026-11-13 08:00+03',timestamptz '2026-11-14 08:00+03',timestamptz '2026-11-14 22:00+03',timestamptz '2026-11-14 22:30+03',timestamptz '2026-11-15 00:00+03',true,'erken_secim');
  PERFORM oyun.olay('secim','14 Kasim Cumartesi cumhurbaskanligi ve milletvekili secimleri. Basvurular 13 Kasim 00.01, oy 14 Kasim 08.00-22.00.',null,null,t);
  INSERT INTO oyun.bildirimler(user_id,zaman,metin)
  SELECT id,t,'14 Kasim 2026 secimi: adaylik 13 Kasim 00.01-08.00, on secim 13 Kasim 08.00-22.00, oy 14 Kasim 08.00-22.00.'
  FROM oyun.profiller WHERE NOT yasakli;
END $once$;
