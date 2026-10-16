-- 16 Ekim 2026: Tum oyuncular icin il, parti ve kullanici adi ile arama.
-- Oyuncu verilerini degistirmez; yalnizca herkese acik profil alanlarini dondurur.

CREATE OR REPLACE FUNCTION public.oyuncu_arama(
  p_aranan text DEFAULT '',
  p_il integer DEFAULT NULL,
  p_parti bigint DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'oyun', 'public', 'pg_temp'
AS $$
DECLARE
  v_kullanici uuid := auth.uid();
  v_aranan text := left(trim(coalesce(p_aranan, '')), 40);
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 50);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
  v_toplam integer;
  v_oyuncular jsonb;
BEGIN
  IF v_kullanici IS NULL OR NOT EXISTS (
    SELECT 1 FROM oyun.profiller WHERE id = v_kullanici AND NOT yasakli
  ) THEN
    RAISE EXCEPTION 'Oyuncu oturumu gerekli.';
  END IF;

  SELECT count(*) INTO v_toplam
  FROM oyun.profiller pr
  WHERE NOT pr.yasakli
    AND (v_aranan = '' OR position(lower(v_aranan) IN lower(pr.kad)) > 0)
    AND (p_il IS NULL OR pr.il_id = p_il)
    AND (p_parti IS NULL OR (p_parti = 0 AND pr.parti_id IS NULL) OR pr.parti_id = p_parti);

  SELECT coalesce(jsonb_agg(to_jsonb(x) - 'sira' ORDER BY x.sira, lower(x.kad), x.kad), '[]'::jsonb)
    INTO v_oyuncular
  FROM (
    SELECT pr.kad, pr.il_id, i.ad AS il_ad, oyun.parti_json(pr.parti_id) AS parti,
           oyun.unvan(pr.id) AS unvan,
           CASE WHEN v_aranan <> '' AND lower(pr.kad) = lower(v_aranan) THEN 0 ELSE 1 END AS sira
    FROM oyun.profiller pr
    JOIN oyun.iller i ON i.id = pr.il_id
    WHERE NOT pr.yasakli
      AND (v_aranan = '' OR position(lower(v_aranan) IN lower(pr.kad)) > 0)
      AND (p_il IS NULL OR pr.il_id = p_il)
      AND (p_parti IS NULL OR (p_parti = 0 AND pr.parti_id IS NULL) OR pr.parti_id = p_parti)
    ORDER BY sira, lower(pr.kad), pr.kad
    LIMIT v_limit OFFSET v_offset
  ) x;

  RETURN jsonb_build_object('toplam', v_toplam, 'oyuncular', v_oyuncular);
END;
$$;

REVOKE ALL ON FUNCTION public.oyuncu_arama(text, integer, bigint, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.oyuncu_arama(text, integer, bigint, integer, integer) TO authenticated;
