-- Banka sahibi kredi basvuraninin kredi notu, haftalik geliri, nakit ve limitini gorur.
CREATE OR REPLACE FUNCTION public.oyb_yonetim(p_banka bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u uuid:=auth.uid();s oyun.sirketler;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=p_banka AND user_id=u AND pay>0)
 THEN RAISE EXCEPTION 'Banka ortagi degilsin';END IF;
 SELECT * INTO s FROM oyun.sirketler WHERE id=p_banka AND sektor='banka';
 IF NOT FOUND THEN RAISE EXCEPTION 'Banka bulunamadi';END IF;
 RETURN jsonb_build_object('id',s.id,'ad',s.ad,'yonetebilir',
 EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=p_banka AND user_id=u AND pay>=50),
 'kredi_faiz',least(s.banka_kredi_faiz,1.0),
 'oranlar',jsonb_build_object('1',oyun.oyb_oran(p_banka,1),'3',oyun.oyb_oran(p_banka,3),
 '6',oyun.oyb_oran(p_banka,6),'12',oyun.oyb_oran(p_banka,12),
 '24',oyun.oyb_oran(p_banka,24),'168',oyun.oyb_oran(p_banka,168)),
 'durum',oyun.oyb_saglik(p_banka),
 'krediler',coalesce((SELECT jsonb_agg(jsonb_build_object(
 'id',k.id,'borclu',coalesce(p.kad,'Oyuncu'),'anapara',k.anapara,'toplam',k.toplam,
 'kalan',k.kalan,'oran',k.oran,'saat',k.saat,'vade',k.vade,
 'durum',CASE WHEN k.durum='aktif' AND k.vade<oyun.simdi() THEN 'gecikmis' ELSE k.durum END,
 'kredi_notu',d.j->'kredi_notu','haftalik_gelir',d.j->'haftalik_gelir',
 'nakit',d.j->'nakit','azami_kredi',d.j->'azami_kredi','degerlendirme',d.j->'neden')
 ORDER BY k.id DESC)
 FROM (SELECT * FROM oyun.oyb_kredi WHERE banka_id=p_banka ORDER BY id DESC LIMIT 40) k
 LEFT JOIN oyun.profiller p ON p.id=k.borclu
 CROSS JOIN LATERAL (SELECT oyun.kredi_risk_ozeti(k.borclu,k.saat) j) d),'[]'::jsonb),
 'hareketler',coalesce((SELECT jsonb_agg(jsonb_build_object(
 'tutar',h.tutar,'aciklama',h.aciklama,'zaman',h.zaman) ORDER BY h.id DESC)
 FROM (SELECT * FROM oyun.sirket_hareket WHERE sirket_id=p_banka ORDER BY id DESC LIMIT 20) h),'[]'::jsonb));
END $function$
;
REVOKE EXECUTE ON FUNCTION public.oyb_yonetim(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.oyb_yonetim(bigint) TO authenticated;
