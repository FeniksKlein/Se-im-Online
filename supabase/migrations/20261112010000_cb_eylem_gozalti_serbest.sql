-- 12.11.2026 | Cumhurbaşkanı, yalnız eylem/polis kaynaklı aktif gözaltıları
-- süre sınırlaması olmadan, mahkeme kayıtlarını silmeden serbest bırakabilir.
ALTER TABLE oyun.sokak_gozalti
  ADD COLUMN IF NOT EXISTS cb_serbest_birakan uuid REFERENCES oyun.profiller(id);
ALTER TABLE oyun.sokak_gozalti
  ADD COLUMN IF NOT EXISTS cb_serbest_zaman timestamptz;
ALTER TABLE oyun.sokak_gozalti
  ADD COLUMN IF NOT EXISTS cb_serbest_gerekce text;

CREATE INDEX IF NOT EXISTS sokak_gozalti_aktif_bitis_idx
  ON oyun.sokak_gozalti (bitis, id) WHERE durum = 'aktif';

CREATE OR REPLACE FUNCTION public.sokak_cb_gozaltilar()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO ''
AS $func$
DECLARE
  u uuid := auth.uid();
  t timestamptz := oyun.simdi();
  yetkili boolean;
  liste jsonb;
BEGIN
  IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM oyun.makamlar m
    WHERE m.user_id = u AND m.tur = 'cb' AND m.bit IS NULL
  ) INTO yetkili;

  IF NOT yetkili THEN
    RETURN jsonb_build_object('cb_miyim', false, 'gozaltilar', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', g.id,
    'eylem_id', g.eylem_id,
    'hedef', p.kad,
    'il', i.ad,
    'baslangic', g.baslangic,
    'bitis', g.bitis,
    'itiraz_var', g.itiraz IS NOT NULL,
    'hakim_incelemesi', g.on_inceleme_karari
  ) ORDER BY g.baslangic DESC), '[]'::jsonb)
  INTO liste
  FROM (
    SELECT * FROM oyun.sokak_gozalti
    WHERE durum = 'aktif' AND bitis > t AND karar IS NULL
    ORDER BY baslangic DESC LIMIT 100
  ) g
  JOIN oyun.profiller p ON p.id = g.hedef
  JOIN oyun.sokak_eylem e ON e.id = g.eylem_id
  JOIN oyun.iller i ON i.id = e.il_id;

  RETURN jsonb_build_object('cb_miyim', true, 'gozaltilar', liste);
END
$func$;

CREATE OR REPLACE FUNCTION public.sokak_cb_serbest_birak(
  p_gozalti bigint, p_gerekce text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO ''
AS $func$
DECLARE
  u uuid := auth.uid();
  t timestamptz := oyun.simdi();
  g oyun.sokak_gozalti;
  sebep text;
BEGIN
  IF u IS NULL OR NOT EXISTS (
    SELECT 1 FROM oyun.makamlar m
    WHERE m.user_id = u AND m.tur = 'cb' AND m.bit IS NULL
  ) THEN RAISE EXCEPTION 'Bu işlem yalnızca görevdeki Cumhurbaşkanına aittir'; END IF;
  IF p_gozalti IS NULL OR p_gozalti <= 0 THEN
    RAISE EXCEPTION 'Geçerli gözaltı dosyası seçilmelidir'; END IF;
  sebep := COALESCE(NULLIF(btrim(p_gerekce), ''), 'Cumhurbaşkanlığı kararı');
  IF char_length(sebep) > 500 THEN
    RAISE EXCEPTION 'Gerekçe 500 karakteri aşamaz'; END IF;

  -- Diğer polis ve hâkim kararlarıyla aynı kilit: çift serbest bırakma oluşmaz.
  PERFORM pg_catalog.pg_advisory_xact_lock(781231, 1);
  SELECT * INTO g FROM oyun.sokak_gozalti WHERE id = p_gozalti FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Gözaltı dosyası bulunamadı'; END IF;
  IF g.durum <> 'aktif' OR g.bitis <= t OR g.karar IS NOT NULL THEN
    RAISE EXCEPTION 'Bu dosyada devam eden gözaltı yok'; END IF;
  IF NOT EXISTS (SELECT 1 FROM oyun.sokak_polis p WHERE p.id = g.polis_id AND p.eylem_id = g.eylem_id)
  THEN RAISE EXCEPTION 'Bu dosya eylem kaynaklı gözaltı değil'; END IF;

  UPDATE oyun.sokak_gozalti
  SET durum = 'serbest',
      bitis = t,
      cb_serbest_birakan = u,
      cb_serbest_zaman = t,
      cb_serbest_gerekce = sebep
  WHERE id = g.id;

  PERFORM oyun.bildir(g.hedef,
    format('Cumhurbaşkanlığı kararıyla eylem gözaltın (#%s) derhal sonlandırıldı. %s', g.id, sebep), t);
  PERFORM oyun.sokak_duyur(g.eylem_id,
    format('Cumhurbaşkanı, eylem gözaltı dosyası #%s için serbest bırakma kararı verdi. %s', g.id, sebep));

  RETURN jsonb_build_object(
    'tamam', true, 'gozalti_id', g.id, 'durum', 'serbest', 'zaman', t
  );
END
$func$;

REVOKE ALL ON FUNCTION public.sokak_cb_gozaltilar() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sokak_cb_serbest_birak(bigint,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sokak_cb_gozaltilar() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sokak_cb_serbest_birak(bigint,text) TO authenticated;
