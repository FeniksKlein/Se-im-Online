-- 2026-10-12: Halka acik secimlerde ilk uc baslangic gorevi oy vermeyi engellemesin.
-- Mevcut oylar, adaylar, sandik saatleri ve oyuncu verileri korunur.
-- E-posta, cihaz, coklu hesap, yasakli hesap, il/parti kisitlari korunur.
CREATE OR REPLACE FUNCTION oyun.oy_engeli(p oyun.profiller, s oyun.secimler)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 SELECT coalesce(
  oyun.uyari(p,s.oy_bas),
  CASE WHEN s.tur IN ('mv','cb','cb2','bel') THEN NULL::text ELSE oyun.ilk_uc_gorev_engel(p) END,
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
$function$;
