-- Milletvekili onseciminde sifir oy alan aday adaylari da kesin listeye girer.
-- Siralama: once oy sayisi, esitlikte erken basvuru, sonra aday kimligi.
-- Oy sayma fonksiyonuna dokunulmaz; 1-5 tercihli oylar korunur.
CREATE OR REPLACE FUNCTION oyun._sonuc_mv_on(s oyun.secimler)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = ''
AS $mv_on$
BEGIN
  PERFORM oyun.aday_oylarini_say(s.id);

  -- Tum aday adaylari dahil: oy > 0 veya HAVING gibi bir eleme YOK.
  WITH siralama AS (
    SELECT a.id,
           row_number() OVER (
             PARTITION BY a.il_id, a.parti_id
             ORDER BY coalesce(a.oy, 0) DESC,
                      a.basvuru_at ASC NULLS LAST,
                      a.id ASC
           )::integer AS liste_sirasi
    FROM oyun.adaylar a
    WHERE a.secim_id = s.id
  )
  UPDATE oyun.adaylar a
  SET sira = x.liste_sirasi
  FROM siralama x
  WHERE a.id = x.id;

  RETURN jsonb_build_object(
    'katilim', (SELECT count(*) FROM oyun.oylar WHERE secim_id = s.id),
    'aday',    (SELECT count(*) FROM oyun.adaylar WHERE secim_id = s.id),
    'liste',   (SELECT count(DISTINCT (il_id, parti_id))
                FROM oyun.adaylar WHERE secim_id = s.id)
  );
END
$mv_on$;
