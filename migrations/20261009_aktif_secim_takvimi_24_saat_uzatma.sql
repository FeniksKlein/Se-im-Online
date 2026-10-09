-- 9 Ekim 2026: Sadece aktif ilk test seçimlerini 24 saat ertele.
-- Başvuru başlangıçları ve tüm oyuncu kayıtları korunur.
-- Adaylık sonu +24 saat; önseçim/genel oylamanın başlangıç/bitişi,
-- sonuç açıklama ve göreve başlama anları +24 saat.
-- İleriki aylık takvime ve seçimin diğer alanlarına dokunulmaz.
-- Güvenli/idempotent: işlem tekrar çalışırsa ikinci kez uzatmaz.
DO $secim_24_saat$
DECLARE
  v_eski integer;
  v_yeni integer;
  v_guncellenen integer;
BEGIN
  WITH hedef(id, tur, onceki_oy_bas) AS (
    VALUES
      (2::bigint, 'mv_on'::text, '2026-10-10 05:00:00+00'::timestamptz),
      (3::bigint, 'mv'::text,    '2026-10-11 05:00:00+00'::timestamptz),
      (4::bigint, 'cb'::text,    '2026-10-11 05:00:00+00'::timestamptz),
      (5::bigint, 'cb_on'::text, '2026-10-10 05:00:00+00'::timestamptz)
  )
  SELECT
    count(*) FILTER (
      WHERE s.durum = 'bekliyor'
        AND s.oy_bas = h.onceki_oy_bas
        AND s.basvuru_bit IS NOT DISTINCT FROM
          CASE WHEN h.tur = 'mv' THEN NULL::timestamptz
               ELSE '2026-10-09 21:00:00+00'::timestamptz END
    ),
    count(*) FILTER (
      WHERE s.oy_bas = h.onceki_oy_bas + interval '24 hours'
        AND s.basvuru_bit IS NOT DISTINCT FROM
          CASE WHEN h.tur = 'mv' THEN NULL::timestamptz
               ELSE '2026-10-10 21:00:00+00'::timestamptz END
    )
  INTO v_eski, v_yeni
  FROM hedef h
  JOIN oyun.secimler s ON s.id = h.id AND s.tur = h.tur
  WHERE s.donem = '2026-11' AND s.ara_neden = 'test_reset_20261008';

  IF v_yeni = 4 THEN
    RAISE NOTICE 'Aktif test seçimlerinin 24 saatlik uzatması zaten uygulanmış.';
    RETURN;
  END IF;

  IF v_eski <> 4 THEN
    RAISE EXCEPTION 'Güvenlik kontrolü: beklenen 4 aktif test seçimi bulunamadı (bulunan: %). Değişiklik yapılmadı.', v_eski;
  END IF;

  UPDATE oyun.secimler
  SET basvuru_bit = basvuru_bit + interval '24 hours',
      oy_bas = oy_bas + interval '24 hours',
      oy_bit = oy_bit + interval '24 hours',
      sonuc_at = sonuc_at + interval '24 hours',
      goreve_bas = goreve_bas + interval '24 hours'
  WHERE id IN (2, 3, 4, 5)
    AND donem = '2026-11'
    AND ara_neden = 'test_reset_20261008'
    AND durum = 'bekliyor';

  GET DIAGNOSTICS v_guncellenen = ROW_COUNT;
  IF v_guncellenen <> 4 THEN
    RAISE EXCEPTION 'Beklenen 4 seçim yerine % seçim güncellendi. İşlem geri alınacak.', v_guncellenen;
  END IF;
END;
$secim_24_saat$;
