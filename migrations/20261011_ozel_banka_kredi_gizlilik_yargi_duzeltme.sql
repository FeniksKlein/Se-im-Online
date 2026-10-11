BEGIN;
-- Banka, oyuncu izni olmadan ayrintili gelir/nakit bilgilerini gormez.
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
 'kredi_notu',d.j->'kredi_notu','haftalik_gelir',CASE WHEN i.durum='izin' AND (i.izinli && ARRAY['maas','kira','sirket','gunluk']::text[]) THEN d.j->'haftalik_gelir' ELSE NULL END,
 'nakit',NULL,'azami_kredi',d.j->'azami_kredi','degerlendirme',d.j->'neden')
 ORDER BY k.id DESC)
 FROM (SELECT * FROM oyun.oyb_kredi WHERE banka_id=p_banka ORDER BY id DESC LIMIT 40) k
 LEFT JOIN oyun.profiller p ON p.id=k.borclu
 LEFT JOIN oyun.oyb_bilgi_izin i ON i.kredi_id=k.id
 CROSS JOIN LATERAL (SELECT oyun.kredi_risk_ozeti(k.borclu,k.saat) j) d),'[]'::jsonb),
 'hareketler',coalesce((SELECT jsonb_agg(jsonb_build_object(
 'tutar',h.tutar,'aciklama',h.aciklama,'zaman',h.zaman) ORDER BY h.id DESC)
 FROM (SELECT * FROM oyun.sirket_hareket WHERE sirket_id=p_banka ORDER BY id DESC LIMIT 20) h),'[]'::jsonb));
END $function$

-- Mahkeme oy asamasi degiskeni sutun adi ile karistirilmaz.

CREATE OR REPLACE FUNCTION public.oyb_icra_karar(p_icra bigint,p_karar text,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d oyun.oyb_icra;k oyun.oyb_kredi;u uuid:=auth.uid();say integer;t timestamptz:=oyun.simdi();v_asama text;son text;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 IF p_karar NOT IN ('kabul','ret') OR char_length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 10 AND 750 THEN
 RAISE EXCEPTION 'Gerekceli mahkeme karari gerekli';END IF;
 SELECT * INTO d FROM oyun.oyb_icra WHERE id=p_icra FOR UPDATE;
 IF NOT FOUND OR d.durum NOT IN ('acik','itiraz') THEN RAISE EXCEPTION 'Bu dosyada oylama acik degil';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=u) OR
 u IN (d.borclu,d.basvuran) OR EXISTS(
 SELECT 1 FROM oyun.sirket_ortaklari o WHERE o.sirket_id=d.banka_id AND o.user_id=u AND o.pay>0)
 THEN RAISE EXCEPTION 'Yetkili tarafsiz mahkeme uyesi degilsin';END IF;
 IF d.durum='acik' AND d.savunma_son>t AND d.savunma IS NULL THEN
 RAISE EXCEPTION 'Borclunun savunma suresi devam ediyor';END IF;
 IF d.durum='itiraz' AND d.itiraz_at+interval '24 hours'>t THEN
 RAISE EXCEPTION 'Itiraz inceleme hazirlik suresi devam ediyor';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=d.kredi_id;
 IF k.durum='odendi' OR k.kalan<=0 THEN
 UPDATE oyun.oyb_icra SET durum='kapandi' WHERE id=d.id;
 RETURN jsonb_build_object('durum','kapandi');END IF;
 v_asama:=CASE WHEN d.durum='itiraz' THEN 'itiraz' ELSE 'ilk' END;
 INSERT INTO oyun.oyb_icra_oy(icra_id,uye,asama,karar,gerekce,zaman)
 VALUES(d.id,u,v_asama,p_karar,trim(p_gerekce),t)
 ON CONFLICT(icra_id,uye,asama) DO UPDATE SET karar=excluded.karar,gerekce=excluded.gerekce,zaman=excluded.zaman;
 SELECT count(*) INTO say FROM oyun.oyb_icra_oy WHERE icra_id=d.id AND asama=v_asama AND karar=p_karar;
 IF say>=2 THEN
  son:=p_karar;
  UPDATE oyun.oyb_icra SET durum=son,karar_at=t,
     kesin_son=CASE WHEN v_asama='itiraz' THEN t ELSE t+interval '24 hours' END WHERE id=d.id;
  PERFORM oyun.bildir(d.borclu,'Icra #'||d.id||' mahkeme karari: '||son||
    CASE WHEN v_asama='ilk' AND son='kabul' THEN '. 24 saat icinde itiraz edebilirsin.' ELSE '' END,t);
  PERFORM oyun.bildir(d.basvuran,'Icra #'||d.id||' mahkeme karari: '||son,t);
 END IF;
 RETURN jsonb_build_object('oy',p_karar,'oy_sayisi',say,'durum',coalesce(son,d.durum));
END $$;
COMMIT;