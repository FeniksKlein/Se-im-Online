-- İçişleri Bakanı olağanüstü il güvenlik tedbiri önerir; Cumhurbaşkanı onaylar/reddeder.
-- Sadece 12 saatlik kamu güvenliği ve memnuniyet göstergesi etkisi yaratır.
-- Oyuncunun hesap, oy, mesaj ve ekonomik haklarını kısıtlamaz.
CREATE TABLE IF NOT EXISTS oyun.icisleri_kriz_karar (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 il_id smallint NOT NULL REFERENCES oyun.iller(id),
 bakan uuid NOT NULL REFERENCES oyun.profiller(id),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 40 AND 600),
 durum text NOT NULL DEFAULT 'onay_bekliyor' CHECK(durum IN ('onay_bekliyor','reddedildi','aktif','sona_erdi')),
 acilis timestamptz NOT NULL DEFAULT now(),
 karar_veren uuid REFERENCES oyun.profiller(id),
 karar_at timestamptz,
 karar_gerekce text,
 bitis timestamptz,
 maliyet numeric NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS icisleri_kriz_tek_il ON oyun.icisleri_kriz_karar(il_id) WHERE durum IN ('onay_bekliyor','aktif');
CREATE INDEX IF NOT EXISTS icisleri_kriz_tarih ON oyun.icisleri_kriz_karar(acilis DESC);
ALTER TABLE oyun.icisleri_kriz_karar ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.icisleri_kriz_karar FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.icisleri_kriz_teklif(p_il integer,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n bigint;
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'İçişleri Bakanlığı yetkisi gerekli'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.iller WHERE id=p_il) OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 40 AND 600 THEN
 RAISE EXCEPTION 'Geçerli il ve 40–600 karakter somut kamu güvenliği gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 UPDATE oyun.icisleri_kriz_karar SET durum='sona_erdi' WHERE (durum='aktif' AND bitis<=t) OR (durum='onay_bekliyor' AND acilis<t-interval '24 hours');
 IF EXISTS(SELECT 1 FROM oyun.icisleri_kriz_karar WHERE il_id=p_il AND durum IN ('onay_bekliyor','aktif')) THEN RAISE EXCEPTION 'Bu ilde aktif veya bekleyen tedbir var'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_kriz_karar WHERE il_id=p_il AND acilis>t-interval '72 hours') THEN RAISE EXCEPTION 'Aynı il için 72 saatlik bekleme süresi var'; END IF;
 IF (SELECT count(*) FROM oyun.icisleri_kriz_karar WHERE durum='aktif' AND bitis>t)>=2 THEN RAISE EXCEPTION 'Ülke çapında en fazla iki aktif il krizi yönetilebilir'; END IF;
 INSERT INTO oyun.icisleri_kriz_karar(il_id,bakan,gerekce,acilis) VALUES(p_il,u,btrim(p_gerekce),t) RETURNING id INTO n;
 PERFORM oyun.bildir(oyun.yurutme_user(),'İçişleri Bakanlığı #'||n||' numaralı il güvenlik tedbiri için Cumhurbaşkanlığı onayı bekliyor.');
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_kriz_karar(p_id bigint,p_kabul boolean,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_kriz_karar; t timestamptz:=oyun.simdi(); maliyet numeric:=2000000; n int;
BEGIN
 IF u IS NULL OR u IS DISTINCT FROM oyun.yurutme_user() THEN RAISE EXCEPTION 'Yalnız Cumhurbaşkanı veya yetkili yürütme makamı'; END IF;
 IF p_kabul IS NULL OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 600 THEN RAISE EXCEPTION '25–600 karakter Cumhurbaşkanlığı gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_kriz_karar WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'onay_bekliyor' OR x.acilis<t-interval '24 hours' THEN RAISE EXCEPTION 'Karara açık, geçerli teklif bulunamadı'; END IF;
 IF p_kabul THEN
   SELECT count(*) INTO n FROM oyun.icisleri_kriz_karar WHERE durum='aktif' AND bitis>t;
   IF n>=2 THEN RAISE EXCEPTION 'En fazla iki ilde eş zamanlı özel tedbir'; END IF;
   PERFORM oyun.bm_kasa_harca('icisleri',maliyet/oyun.pazar_tl_milyar(),'gider','Cumhurbaşkanlığı onaylı 12 saatlik il güvenlik tedbiri');
   UPDATE oyun.il_durum SET gelisim=LEAST(100,gelisim+1),memnuniyet=GREATEST(0,memnuniyet-1.5) WHERE il_id=x.il_id;
   UPDATE oyun.ulke SET memnuniyet=GREATEST(0,memnuniyet-0.3) WHERE id=1;
 END IF;
 UPDATE oyun.icisleri_kriz_karar SET durum=CASE WHEN p_kabul THEN 'aktif' ELSE 'reddedildi' END,karar_veren=u,karar_at=t,karar_gerekce=btrim(p_gerekce),bitis=CASE WHEN p_kabul THEN t+interval '12 hours' END,maliyet=CASE WHEN p_kabul THEN maliyet ELSE 0 END WHERE id=x.id;
 PERFORM oyun.bildir(x.bakan,'İl güvenlik tedbiri #'||x.id||' '||CASE WHEN p_kabul THEN 'onaylandı, 12 saat etkin' ELSE 'reddedildi' END||'.');
 IF p_kabul THEN
   INSERT INTO oyun.bildirimler(user_id,zaman,metin)
   SELECT p.id,t,'Bulunduğunuz ilde 12 saatlik özel kamu güvenliği tedbiri ilan edildi. Hesabınızın, oy ve ekonomik işlemlerinizin kullanımına kısıtlama getirmez.'
   FROM oyun.profiller p WHERE p.il_id=x.il_id AND NOT p.yasakli;
 END IF;
 PERFORM oyun.gazete_ekle('icisleri','İl güvenlik kararı #'||x.id,
   (SELECT ad FROM oyun.iller WHERE id=x.il_id)||' için '||CASE WHEN p_kabul THEN '12 saatlik özel tedbir kabul edildi. ' ELSE 'tedbir önerisi reddedildi. ' END||btrim(p_gerekce),x.id,t);
 RETURN jsonb_build_object('tamam',true);
END $$;
-- Kriz teklif ve karar kayıtları yalnız yetki sahipleri/ilgili ili ikamet edenlere değil, direkt ilgili idarecilere görünür.
CREATE OR REPLACE FUNCTION public.icisleri_kriz_panel() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); b boolean; cb boolean;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 b:=oyun.bm_yetki(u,'icisleri') IS NOT NULL;
 cb:=u=oyun.yurutme_user();
 RETURN jsonb_build_object('bakan',b,'yurutme',cb,
  'iller',CASE WHEN b THEN COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'ad',ad) ORDER BY ad) FROM oyun.iller),'[]'::jsonb) ELSE '[]'::jsonb END,
  'kararlar',CASE WHEN b OR cb THEN COALESCE((SELECT jsonb_agg(jsonb_build_object('id',k.id,'il',i.ad,'bakan',k.bakan,'gerekce',k.gerekce,'durum',CASE WHEN k.durum='aktif' AND k.bitis<=oyun.simdi() THEN 'sona_erdi' ELSE k.durum END,'acilis',k.acilis,'bitis',k.bitis,'karar_gerekce',k.karar_gerekce) ORDER BY k.acilis DESC) FROM
 (SELECT * FROM oyun.icisleri_kriz_karar ORDER BY acilis DESC LIMIT 30) k JOIN oyun.iller i ON i.id=k.il_id),'[]'::jsonb) ELSE '[]'::jsonb END);
END $$;
REVOKE ALL ON FUNCTION public.icisleri_kriz_teklif(integer,text),public.icisleri_kriz_karar(bigint,boolean,text),public.icisleri_kriz_panel() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.icisleri_kriz_teklif(integer,text),public.icisleri_kriz_karar(bigint,boolean,text),public.icisleri_kriz_panel() TO authenticated;
