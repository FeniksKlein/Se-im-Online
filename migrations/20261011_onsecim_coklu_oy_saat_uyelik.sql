-- 11 Ekim 2026: 09:00–17:00 önseçimi, mevcut adayları koru, çoklu MV tercihi.
-- 12 Ekim olağan genel seçimi ve başvuruları korunur. Bu dosya tekrar çalıştırılabilir.
BEGIN;

ALTER TABLE oyun.oylar ADD COLUMN IF NOT EXISTS tercih_aday_ids bigint[];

-- Yalnız mevcut 2026-11 önseçimi; diğer dönemlerin üyelik kütüğü kuralı korunur.
CREATE OR REPLACE FUNCTION oyun.oy_engeli(p oyun.profiller, s oyun.secimler)
RETURNS text LANGUAGE sql STABLE SET search_path TO '' AS $$
 SELECT coalesce(
  oyun.uyari(p,s.oy_bas),
  oyun.ilk_uc_gorev_engel(p),
  CASE WHEN s.ara AND s.hedef_il_id IS NOT NULL AND p.il_id IS DISTINCT FROM s.hedef_il_id
    THEN format('Bu olağanüstü seçim yalnızca %s ili içindir.',
      (SELECT ad FROM oyun.iller WHERE id=s.hedef_il_id)) END,
  CASE WHEN s.ara AND s.hedef_parti_id IS NOT NULL AND p.parti_id IS DISTINCT FROM s.hedef_parti_id
    THEN format('Bu olağanüstü kurultay yalnızca %s üyeleri içindir.',
      (SELECT kisa FROM oyun.partiler WHERE id=s.hedef_parti_id)) END,
  CASE WHEN s.tur IN ('mv','bel','mv_on','bel_on') AND p.son_il_degis IS NOT NULL
            AND p.il_at > s.oy_bas - make_interval(days=>(SELECT oy_il_gun FROM oyun.ayarlar WHERE id=1))
       THEN format('Seçmen kütüğü: bu ilde en az %s gün kayıtlı olmalısın.',
            (SELECT oy_il_gun FROM oyun.ayarlar WHERE id=1)) END,
  CASE WHEN s.tur IN ('mv_on','bel_on','kurultay','cb_on') THEN
    CASE WHEN p.parti_id IS NULL THEN 'Bu parti içi seçimde parti üyesi olmalısın.'
         WHEN p.parti_at > s.basvuru_bas AND NOT (s.donem='2026-11' AND s.tur IN ('mv_on','cb_on'))
         THEN 'Başvurular açılmadan önce parti üyesi olmalısın.' END END)
$$;

-- Dünkü aday adayları ve 12 Ekim genel seçimi aynen durur. Yalnız 11 Ekim saatleri düzeltilir.
UPDATE oyun.secimler SET
  oy_bas=oyun.tr_an('2026-10-11'::date,9),
  oy_bit=oyun.tr_an('2026-10-11'::date,17),
  sonuc_at=oyun.tr_an('2026-10-11'::date,17,30)
WHERE donem='2026-11' AND tur IN ('mv_on','cb_on') AND durum='bekliyor' AND ara=false;

-- CB önseçiminin boş bırakılmış pusulasına yarınki seçimde kayıtlı parti adaylarını aktar.
-- Bağımsız CB adayları yarınki genel seçimde kalır ve parti içi önseçime girmez.
INSERT INTO oyun.adaylar(secim_id,user_id,parti_id,il_id,basvuru_at,vaat)
SELECT on_s.id,a.user_id,a.parti_id,a.il_id,a.basvuru_at,a.vaat
FROM oyun.secimler cb_s
JOIN oyun.secimler on_s ON on_s.donem=cb_s.donem AND on_s.tur='cb_on'
JOIN oyun.adaylar a ON a.secim_id=cb_s.id
WHERE cb_s.tur='cb' AND cb_s.donem='2026-11' AND a.parti_id IS NOT NULL
ON CONFLICT (secim_id,user_id) DO NOTHING;

-- Bir MV önseçimi pusulasında 1–5 farklı aday; tek oyuncu = tek pusula.
CREATE OR REPLACE FUNCTION public.oy_ver_coklu(p_secim bigint,p_hedefler bigint[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'oyun','public','pg_temp' AS $$
DECLARE
 p oyun.profiller := oyun.profilim();
 s oyun.secimler;
 t timestamptz := oyun.simdi();
 engel text;
 n int;
BEGIN
 IF p.id IS NULL THEN RAISE EXCEPTION 'Önce giriş yapmalısın.'; END IF;
 SELECT * INTO s FROM oyun.secimler WHERE id=p_secim FOR SHARE;
 IF s.id IS NULL OR s.tur<>'mv_on' THEN
   RAISE EXCEPTION 'Çoklu oy yalnızca milletvekili önseçiminde geçerlidir.';
 END IF;
 IF s.durum<>'bekliyor' OR t<s.oy_bas OR t>=s.oy_bit THEN
   RAISE EXCEPTION 'Sandık kapalı. Oy verme 09.00–17.00 arasındadır.';
 END IF;
 engel := oyun.oy_engeli(p,s);
 IF engel IS NOT NULL THEN RAISE EXCEPTION '%',engel; END IF;
 n:=coalesce(cardinality(p_hedefler),0);
 IF n<1 OR n>5 THEN
   RAISE EXCEPTION 'En az 1, en fazla 5 aday seçebilirsin.';
 END IF;
 IF EXISTS(SELECT 1 FROM unnest(p_hedefler) AS h(id) WHERE h.id IS NULL) OR
    (SELECT count(DISTINCT h.id) FROM unnest(p_hedefler) AS h(id))<>n THEN
   RAISE EXCEPTION 'Aynı aday birden fazla seçilemez.';
 END IF;
 IF (SELECT count(*) FROM oyun.adaylar a WHERE a.id=ANY(p_hedefler)
       AND a.secim_id=s.id AND a.parti_id=p.parti_id AND a.il_id=p.il_id)<>n THEN
   RAISE EXCEPTION 'Yalnız kendi ilindeki ve kendi partindeki aday adaylarına oy verebilirsin.';
 END IF;
 INSERT INTO oyun.oylar(secim_id,secmen,il_id,parti_id,aday_id,zaman,tercih_aday_ids)
 VALUES(s.id,p.id,p.il_id,p.parti_id,p_hedefler[1],t,p_hedefler)
 ON CONFLICT (secim_id,secmen) DO NOTHING;
 IF NOT FOUND THEN RAISE EXCEPTION 'Bu seçimde zaten oy kullandın.'; END IF;
 RETURN public.durum();
END $$;
REVOKE ALL ON FUNCTION public.oy_ver_coklu(bigint,bigint[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.oy_ver_coklu(bigint,bigint[]) TO authenticated;

-- Eski tek-oylu kayıtlarda aday_id, yeni çoklu oylarda tercih_aday_ids esas alınır.
CREATE OR REPLACE FUNCTION oyun.aday_oylarini_say(p_sid bigint)
RETURNS void LANGUAGE sql SET search_path TO '' AS $$
 UPDATE oyun.adaylar a SET oy=(
   SELECT count(*)::int FROM oyun.oylar o JOIN oyun.secimler s ON s.id=o.secim_id
   WHERE o.secim_id=a.secim_id AND
     ((s.tur='mv_on' AND a.id=ANY(coalesce(o.tercih_aday_ids,ARRAY[o.aday_id])))
      OR (s.tur<>'mv_on' AND o.aday_id=a.id))
 ) WHERE a.secim_id=p_sid
$$;
NOTIFY pgrst,'reload schema';
COMMIT;