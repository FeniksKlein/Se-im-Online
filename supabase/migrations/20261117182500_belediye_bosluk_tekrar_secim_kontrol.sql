-- 81 il icin bos belediye takibi: secim ve makam verilerini silmez, otomatik atama yapmaz.
-- Varsayilan p_kuru=true ile SADECE raporlar. Aktivasyon icin cron/yeni tick entegrasyonu ayri onaylanmalidir.
CREATE OR REPLACE FUNCTION oyun.bos_belediye_secim_kontrol(
 p_kuru boolean DEFAULT true,
 p_zaman timestamptz DEFAULT oyun.simdi()
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fn$
DECLARE il record; son_sandik timestamptz; secmen integer;
 rapor jsonb := '[]'::jsonb; acilan integer := 0; aday integer := 0;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtext('oyun.bos_belediye_secim_kontrol'));
 FOR il IN SELECT i.id,i.ad FROM oyun.iller i ORDER BY i.id LOOP
  IF EXISTS (SELECT 1 FROM oyun.makamlar m WHERE m.tur='bel' AND m.il_id=il.id
             AND m.bit IS NULL AND m.bas <= p_zaman) THEN CONTINUE; END IF;
  -- Acilmis bir ara secim veya yakin olagan belediye secimi varken cift secim acma.
  IF EXISTS (SELECT 1 FROM oyun.secimler s WHERE s.tur='bel'
     AND s.durum='bekliyor' AND s.oy_bas>=p_zaman
     AND (s.hedef_il_id=il.id OR (s.hedef_il_id IS NULL AND s.ara=false))
     AND NOT (s.sonuc ? 'iptal')) THEN CONTINUE; END IF;
  SELECT max(s.oy_bas) INTO son_sandik FROM oyun.secimler s
     WHERE s.tur='bel' AND (s.hedef_il_id=il.id OR s.hedef_il_id IS NULL)
       AND s.oy_bas<=p_zaman AND s.durum='tamam' AND NOT (s.sonuc ? 'iptal');
  -- Surekli oy gelmeyen ilde her gun anlamsiz secim acma: 7 gun dinlenme.
  IF son_sandik IS NOT NULL AND son_sandik > p_zaman-interval '7 days' THEN CONTINUE; END IF;
  SELECT count(*) INTO secmen FROM oyun.profiller p WHERE p.il_id=il.id
    AND NOT p.yasakli AND p.son_gorulme>p_zaman-interval '7 days';
  IF secmen=0 THEN CONTINUE; END IF;
  aday:=aday+1;
  rapor := rapor || jsonb_build_array(jsonb_build_object('il_id',il.id,'il',il.ad,
                            'aktif_secmen',secmen,'son_secim',son_sandik));
  IF NOT p_kuru THEN
    PERFORM oyun.ara_secim_olustur('bel',NULL,il.id,p_zaman);
    acilan:=acilan+1;
  END IF;
 END LOOP;
 RETURN jsonb_build_object('kuru',p_kuru,'yeniden_secime_uygun_il',aday,
                           'acilan_secim',acilan,'iller',rapor);
END $fn$;
REVOKE ALL ON FUNCTION oyun.bos_belediye_secim_kontrol(boolean,timestamptz) FROM PUBLIC,anon,authenticated;
