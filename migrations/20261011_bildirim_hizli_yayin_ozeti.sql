-- 11 Ekim 2026: Bildirimler ekranini hayat() gibi agir istatistiklerden ayir.
-- Yalnizca yayin rozetine ve ek yayin hakki satin alimina gereken bilgiyi getir.
-- Oyuncu bakiyeleri, bildirimler ve mevcut veriler degistirilmez.
BEGIN;
CREATE OR REPLACE FUNCTION public.bildirim_yayin_ozet()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'oyun','public','pg_temp' AS $$
DECLARE
  p oyun.profiller := oyun.profilim();
  c oyun.cuzdan;
BEGIN
  SELECT * INTO c FROM oyun.cuzdan WHERE user_id=p.id;
  RETURN jsonb_build_object(
    'ek_yayin',jsonb_build_object(
      'kalan_alim',greatest(0,3-coalesce(c.reklam_n,0)),
      'elde',greatest(0,coalesce(c.reklam_n,0)-coalesce(c.reklam_kul,0))
    ),
    'fiyat',jsonb_build_object('reklam',oyun.reklam_fiyat())
  );
END $$;
REVOKE ALL ON FUNCTION public.bildirim_yayin_ozet() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bildirim_yayin_ozet() TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;