-- 2026-11-07 · İçişleri komuta merkezi ve gerçek oyuncu etkileri.
-- Mevcut polis/eylem/uzlaşma sistemini değiştirmez; 13 görev ve hak denetimli oyuncu dosyaları ekler.
INSERT INTO oyun.icraatlar(kod,bakanlik,ad,aciklama,maliyet,bekleme_saat,il_gerekli,etki,oyuncu,sure_gun)
VALUES
('ic_vali_koordinasyon','icisleri','Valilik kriz koordinasyonu','Seçilen ilde valilik ve kolluk planlaması; kamu hizmeti koordinasyonu iyileşir.',3,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
('ic_polis_devriye','icisleri','Polis devriyesi seferberliği','İlde kolluk görünürlüğü artırılır; güvenlik ve kamu memnuniyeti iyileşir.',4,72,true,'{"gelisim":1,"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('ic_jandarma_takviye','icisleri','Jandarma kırsal takviye','Kırsal ulaşım ve emniyet hizmetlerine ekip sevk edilir.',4,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
('ic_emniyet_egitim','icisleri','Emniyet personeli eğitim programı','Ülke genelinde müdahale kalitesi ve hesap verebilirlik eğitimleri.',3,168,false,'{"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('ic_belediye_mufettis','icisleri','Belediye müfettişi görevlendir','İldeki belediye hizmetlerinin idari denetimine kaynak ayrılır; usul denetimi yapılır.',2,72,true,'{"gelisim":1,"memnuniyet":0.1}'::jsonb,'[]'::jsonb,null),
('ic_suc_mucadele','icisleri','Organize suçla mücadele koordinasyonu','İl genelinde oyun içi suç önleme kapasitesi ve kamu güveni artar.',5,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
('ic_siber_ihbar_ekip','icisleri','Siber ihbar ve koruma ekipleri','Vatandaş şikâyetleri ve dijital dolandırıcılık ihbarlarının ele alınması.',3,168,false,'{"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('ic_istihbarat_analiz','icisleri','Güvenlik istihbarat analiz birimi','İlgili ilin güvenlik göstergelerini izlemek için analiz kapasitesi kurulur.',3,72,true,'{"gelisim":1}'::jsonb,'[]'::jsonb,null),
('ic_sehir_takviye','icisleri','İl güvenlik seferberliği','Kamu güvenliği krizinde geçici kolluk kaynakları tahsis edilir; yüksek harcama tepkilere yol açar.',8,168,true,'{"gelisim":2,"memnuniyet":-0.3}'::jsonb,'[]'::jsonb,null),
('ic_afet_mudahale','icisleri','Afet koordinasyon ve tahliye merkezi','Afet müdahalesi ve geçici barınma kapasitesini artırır.',6,72,true,'{"gelisim":3,"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('ic_vatandas_hatti','icisleri','Vatandaş başvuru ve şikâyet masası','Oyuncu dilekçelerinin değerlendirilmesi için ülke çapında hizmet hattı kurulur.',2,168,false,'{"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('ic_genelge_hizmet','icisleri','Valiliklere hizmet genelgesi','81 ilde hizmet standardizasyonuna yönelik bağlayıcı idari talimat ve masraf.',4,168,false,'{"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('ic_kriz_uzlasma','icisleri','Toplumsal uzlaşma heyeti','Ülke genelinde arabuluculuk ve hukuk destek ekipleri görevlendirilir.',4,168,false,'{"memnuniyet":0.5}'::jsonb,'[]'::jsonb,null)
ON CONFLICT(kod) DO NOTHING;

CREATE TABLE IF NOT EXISTS oyun.icisleri_basvuru (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id uuid NOT NULL REFERENCES oyun.profiller(id),
 tur text NOT NULL CHECK(tur IN ('yardim','egitim')),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 25 AND 600),
 durum text NOT NULL DEFAULT 'bekliyor' CHECK(durum IN ('bekliyor','onay','red')),
 acilis timestamptz NOT NULL DEFAULT now(),
 karar_veren uuid REFERENCES oyun.profiller(id),
 karar_at timestamptz,
 karar_gerekce text,
 odul numeric NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS icisleri_basvuru_son ON oyun.icisleri_basvuru(acilis DESC);
CREATE INDEX IF NOT EXISTS icisleri_basvuru_oyuncu ON oyun.icisleri_basvuru(user_id,acilis DESC);

CREATE TABLE IF NOT EXISTS oyun.icisleri_dosya (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 bakan uuid NOT NULL REFERENCES oyun.profiller(id),
 hedef uuid NOT NULL REFERENCES oyun.profiller(id),
 konu text NOT NULL CHECK(char_length(konu) BETWEEN 20 AND 180),
 delil text NOT NULL CHECK(char_length(delil) BETWEEN 40 AND 800),
 acilis timestamptz NOT NULL DEFAULT now(),
 durum text NOT NULL DEFAULT 'inceleme' CHECK(durum IN ('inceleme','aklandi','ceza','itiraz','kaldirildi')),
 savunma text,
 savunma_at timestamptz,
 hakim uuid REFERENCES oyun.profiller(id),
 karar_at timestamptz,
 karar_gerekce text,
 ceza_tutari numeric NOT NULL DEFAULT 0,
 kidem_kaybi numeric NOT NULL DEFAULT 0,
 itiraz_metni text,
 itiraz_at timestamptz,
 itiraz_hakim uuid REFERENCES oyun.profiller(id),
 itiraz_karar text,
 itiraz_karar_at timestamptz
);
CREATE INDEX IF NOT EXISTS icisleri_dosya_son ON oyun.icisleri_dosya(acilis DESC);
CREATE INDEX IF NOT EXISTS icisleri_dosya_hedef ON oyun.icisleri_dosya(hedef,acilis DESC);
ALTER TABLE oyun.icisleri_basvuru ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.icisleri_dosya ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.icisleri_basvuru,oyun.icisleri_dosya FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.icisleri_basvur(p_tur text,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n bigint;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=u AND NOT yasakli) THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 IF p_tur NOT IN ('yardim','egitim') OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 600 THEN RAISE EXCEPTION 'Başvuru türü ve 25–600 karakter gerekçe gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext(u::text),77118);
 IF EXISTS(SELECT 1 FROM oyun.icisleri_basvuru WHERE user_id=u AND tur=p_tur AND (durum='bekliyor' OR acilis>t-interval '7 days')) THEN RAISE EXCEPTION 'Aynı destek türü için 7 günlük bekleme süresi var'; END IF;
 INSERT INTO oyun.icisleri_basvuru(user_id,tur,gerekce,acilis) VALUES(u,p_tur,btrim(p_gerekce),t) RETURNING id INTO n;
 PERFORM oyun.bildir(u,'İçişleri Bakanlığı başvurunuz #'||n||' alındı; karar bildirimle gönderilecek.');
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_basvuru_karar(p_id bigint,p_kabul boolean,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_basvuru; tut numeric; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'İçişleri Bakanı veya yetkili vekil gerekli'; END IF;
 IF p_kabul IS NULL OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 20 AND 500 THEN RAISE EXCEPTION '20–500 karakter gerekçeli karar gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_basvuru WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'bekliyor' THEN RAISE EXCEPTION 'Başvuru sonuçlandırılmış ya da bulunamadı'; END IF;
 IF p_kabul AND (SELECT count(*) FROM oyun.icisleri_basvuru WHERE durum='onay' AND karar_at>t-interval '24 hours')>=8 THEN RAISE EXCEPTION 'Günlük 8 destek onayı sınırına ulaşıldı'; END IF;
 IF p_kabul THEN
   tut:=CASE x.tur WHEN 'yardim' THEN 3000 ELSE 0 END;
   PERFORM oyun.bm_kasa_harca('icisleri', (30000+tut)/oyun.pazar_tl_milyar(),'gider','Oyuncu başvurusu #'||x.id||' / kamu desteği');
   IF x.tur='yardim' THEN
     UPDATE oyun.cuzdan SET para=para+tut WHERE user_id=x.user_id;
     IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
     INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(x.user_id,t,tut,'yardim','İçişleri onaylı sosyal destek #'||x.id);
   ELSE
     UPDATE oyun.cuzdan SET kidem=kidem+1 WHERE user_id=x.user_id;
     IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
   END IF;
 END IF;
 UPDATE oyun.icisleri_basvuru SET durum=CASE WHEN p_kabul THEN 'onay' ELSE 'red' END,karar_veren=u,karar_at=t,karar_gerekce=btrim(p_gerekce),odul=CASE WHEN p_kabul THEN CASE WHEN x.tur='yardim' THEN 3000 ELSE 1 END ELSE 0 END WHERE id=x.id;
 PERFORM oyun.bildir(x.user_id,'İçişleri başvurunuz #'||x.id||' '||CASE WHEN p_kabul THEN 'onaylandı' ELSE 'reddedildi' END||'. '||btrim(p_gerekce));
 PERFORM oyun.gazete_ekle('icisleri','İçişleri başvuru kararı #'||x.id,CASE WHEN p_kabul THEN 'Kamu destek programı onaylandı.' ELSE 'Kamu destek başvurusu reddedildi.' END||' Gerekçe: '||btrim(p_gerekce),x.id,t);
 RETURN jsonb_build_object('tamam',true,'odul',CASE WHEN p_kabul THEN CASE WHEN x.tur='yardim' THEN 3000 ELSE 1 END ELSE 0 END);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_sorusturma_ac(p_hedef uuid,p_konu text,p_delil text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n bigint;
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'Yalnız İçişleri Bakanı veya yetkili vekil'; END IF;
 IF p_hedef IS NULL OR p_hedef=u OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=p_hedef AND NOT yasakli) THEN RAISE EXCEPTION 'Geçerli, farklı bir oyuncu seçin'; END IF;
 IF char_length(btrim(coalesce(p_konu,''))) NOT BETWEEN 20 AND 180 OR char_length(btrim(coalesce(p_delil,''))) NOT BETWEEN 40 AND 800 THEN RAISE EXCEPTION '20–180 karakter konu, 40–800 karakter somut delil yazılmalı'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 IF (SELECT count(*) FROM oyun.icisleri_dosya WHERE acilis>t-interval '24 hours')>=5 THEN RAISE EXCEPTION '24 saatte en fazla 5 inceleme açılabilir'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_dosya WHERE hedef=p_hedef AND acilis>t-interval '7 days') THEN RAISE EXCEPTION 'Aynı oyuncu 7 günde yalnız bir kez incelemeye alınabilir'; END IF;
 PERFORM oyun.bm_kasa_harca('icisleri',50000/oyun.pazar_tl_milyar(),'gider','Gerekçeli idari denetim');
 INSERT INTO oyun.icisleri_dosya(bakan,hedef,konu,delil,acilis) VALUES(u,p_hedef,btrim(p_konu),btrim(p_delil),t) RETURNING id INTO n;
 PERFORM oyun.bildir(p_hedef,'İçişleri Bakanlığınca hakkınızda #'||n||' numaralı oyun içi inceleme açıldı. Savunma hakkınız var; yaptırım için bağımsız hâkim kararı gereklidir.');
 PERFORM oyun.gazete_ekle('icisleri','İdari inceleme açıldı #'||n,'İçişleri Bakanlığı '||btrim(p_konu)||' konusunda inceleme açtı; hüküm verilmedi.',n,t);
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_savunma(p_id bigint,p_metin text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_dosya;
BEGIN
 IF u IS NULL OR char_length(btrim(coalesce(p_metin,''))) NOT BETWEEN 25 AND 1000 THEN RAISE EXCEPTION '25–1000 karakter savunma gerekli'; END IF;
 SELECT * INTO x FROM oyun.icisleri_dosya WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.hedef<>u OR x.durum<>'inceleme' THEN RAISE EXCEPTION 'Savunma hakkınız olan açık dosya bulunamadı'; END IF;
 IF x.savunma IS NOT NULL THEN RAISE EXCEPTION 'Bu dosyada savunma zaten verildi'; END IF;
 UPDATE oyun.icisleri_dosya SET savunma=btrim(p_metin),savunma_at=oyun.simdi() WHERE id=p_id;
 PERFORM oyun.bildir(x.bakan,'İçişleri inceleme dosyası #'||p_id||' için oyuncu savunmasını sundu.');
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_hakim_karar(p_id bigint,p_karar text,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_dosya; t timestamptz:=oyun.simdi(); c numeric; k numeric;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u) THEN RAISE EXCEPTION 'Bağımsız hâkim yetkisi gerekli'; END IF;
 IF p_karar NOT IN ('aklandi','ceza') OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 700 THEN RAISE EXCEPTION 'Gerekçeli karar ve 25–700 karakter açıklama gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_dosya WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'inceleme' OR x.acilis<t-interval '48 hours' THEN RAISE EXCEPTION 'Dosya artık karara uygun değil'; END IF;
 IF u IN (x.bakan,x.hedef) OR oyun.bm_yetki(u,'icisleri') IS NOT NULL THEN RAISE EXCEPTION 'İşleme taraf olan veya İçişleri yetkilisi yargılama yapamaz'; END IF;
 IF p_karar='ceza' AND x.savunma IS NULL AND x.acilis>t-interval '6 hours' THEN RAISE EXCEPTION 'Savunma hakkı için ilk 6 saat tamamlanmalı'; END IF;
 c:=0;k:=0;
 IF p_karar='ceza' THEN
   SELECT LEAST(1000,GREATEST(0,para)),LEAST(1,GREATEST(0,kidem)) INTO c,k FROM oyun.cuzdan WHERE user_id=x.hedef FOR UPDATE;
   IF c IS NULL THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
   UPDATE oyun.cuzdan SET para=para-c,kidem=kidem-k WHERE user_id=x.hedef;
   IF c>0 THEN
      INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(x.hedef,t,-c,'ceza','Mahkeme onaylı İçişleri idari cezası #'||x.id);
   END IF;
   UPDATE oyun.ulke SET memnuniyet=GREATEST(0,memnuniyet-0.1) WHERE id=1;
 END IF;
 UPDATE oyun.icisleri_dosya SET durum=p_karar,hakim=u,karar_at=t,karar_gerekce=btrim(p_gerekce),ceza_tutari=c,kidem_kaybi=k WHERE id=x.id;
 PERFORM oyun.bildir(x.hedef,'İçişleri inceleme dosyası #'||x.id||' hâkim kararı: '||p_karar||'. Ceza varsa 24 saat içinde itiraz edebilirsiniz.');
 PERFORM oyun.gazete_ekle('icisleri','İdari inceleme kararı #'||x.id,CASE WHEN p_karar='ceza' THEN 'Mahkeme gerekçeli idari cezayı onayladı.' ELSE 'Oyuncu hakkında soruşturma sona erdi; yaptırım uygulanmadı.' END||' '||btrim(p_gerekce),x.id,t);
 RETURN jsonb_build_object('tamam',true,'ceza',c,'kidem',k);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_itiraz(p_id bigint,p_metin text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_dosya;
BEGIN
 IF u IS NULL OR char_length(btrim(coalesce(p_metin,''))) NOT BETWEEN 25 AND 800 THEN RAISE EXCEPTION '25–800 karakter itiraz gerekçesi gerekli'; END IF;
 SELECT * INTO x FROM oyun.icisleri_dosya WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.hedef<>u OR x.durum<>'ceza' OR x.karar_at<oyun.simdi()-interval '24 hours' THEN RAISE EXCEPTION 'Açık itiraz hakkı bulunamadı'; END IF;
 UPDATE oyun.icisleri_dosya SET durum='itiraz',itiraz_metni=btrim(p_metin),itiraz_at=oyun.simdi() WHERE id=p_id;
 PERFORM oyun.bildir(u,'İçişleri dosyası #'||p_id||' itirazınız alındı; ikinci bir hâkim inceleyecek.');
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_itiraz_karar(p_id bigint,p_kaldir boolean,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_dosya; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u) THEN RAISE EXCEPTION 'Bağımsız hâkim gerekli'; END IF;
 IF p_kaldir IS NULL OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 700 THEN RAISE EXCEPTION '25–700 karakter gerekçe gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_dosya WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'itiraz' THEN RAISE EXCEPTION 'İtiraz bulunamadı'; END IF;
 IF u IN (x.hedef,x.bakan,x.hakim) THEN RAISE EXCEPTION 'İlk hâkim veya dosya tarafları ikinci kararı veremez'; END IF;
 IF p_kaldir THEN
   UPDATE oyun.cuzdan SET para=para+x.ceza_tutari,kidem=kidem+x.kidem_kaybi WHERE user_id=x.hedef;
   IF x.ceza_tutari>0 THEN
      INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(x.hedef,t,x.ceza_tutari,'iade','İptal edilen İçişleri cezası iadesi #'||x.id);
   END IF;
 END IF;
 UPDATE oyun.icisleri_dosya SET durum=CASE WHEN p_kaldir THEN 'kaldirildi' ELSE 'ceza' END,
  itiraz_hakim=u,itiraz_karar=btrim(p_gerekce),itiraz_karar_at=t WHERE id=x.id;
 PERFORM oyun.bildir(x.hedef,'İçişleri dosyası #'||x.id||' itiraz kararı: '||CASE WHEN p_kaldir THEN 'ceza kaldırıldı ve iade yapıldı' ELSE 'ceza onandı' END||'.');
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_oyuncu_ara(p_ara text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'Yetkisiz erişim'; END IF;
 IF length(btrim(coalesce(p_ara,'')))<2 THEN RETURN '[]'::jsonb; END IF;
 RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'kad',kad,'il', (SELECT ad FROM oyun.iller WHERE id=p.il_id))) FROM
 (SELECT id,kad,il_id FROM oyun.profiller WHERE kad ILIKE '%'||left(btrim(p_ara),40)||'%' AND NOT yasakli ORDER BY kad LIMIT 12) p),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_komuta_panel() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); yetki boolean; yargi boolean;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 yetki:=oyun.bm_yetki(u,'icisleri') IS NOT NULL;
 yargi:=EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u);
 RETURN jsonb_build_object(
 'yetki',yetki,'yargi',yargi,'kasa_tl',CASE WHEN yetki THEN (SELECT kasa*oyun.pazar_tl_milyar() FROM oyun.bakanlik_kasa WHERE kod='icisleri') ELSE NULL END,
 'icraatlar',CASE WHEN yetki THEN COALESCE((SELECT jsonb_agg(jsonb_build_object('kod',kod,'ad',ad,'aciklama',aciklama,'maliyet',maliyet,'il_gerekli',il_gerekli) ORDER BY ad) FROM oyun.icraatlar WHERE bakanlik='icisleri' AND kod LIKE 'ic_%'),'[]'::jsonb) ELSE '[]'::jsonb END,
 'iller',CASE WHEN yetki THEN COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'ad',ad) ORDER BY ad) FROM oyun.iller),'[]'::jsonb) ELSE '[]'::jsonb END,
 'basvurular',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',b.id,'user_id',b.user_id,'oyuncu',p.kad,'tur',b.tur,'gerekce',b.gerekce,'durum',b.durum,'acilis',b.acilis,'karar_gerekce',b.karar_gerekce,'odul',b.odul) ORDER BY b.acilis DESC) FROM
 (SELECT * FROM oyun.icisleri_basvuru WHERE yetki OR user_id=u ORDER BY acilis DESC LIMIT 40) b JOIN oyun.profiller p ON p.id=b.user_id),'[]'::jsonb),
 'dosyalar',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',d.id,'hedef',d.hedef,'oyuncu',p.kad,'bakan',d.bakan,'konu',d.konu,'delil',d.delil,'durum',CASE WHEN d.durum='inceleme' AND d.acilis<oyun.simdi()-interval '48 hours' THEN 'suresi_doldu' ELSE d.durum END,'acilis',d.acilis,'savunma',d.savunma,'karar_at',d.karar_at,'hakim',d.hakim,'karar_gerekce',d.karar_gerekce,'ceza',d.ceza_tutari,'kidem_kaybi',d.kidem_kaybi,'itiraz_metni',d.itiraz_metni,'itiraz_karar',d.itiraz_karar,'benim',d.hedef=u) ORDER BY d.acilis DESC) FROM
 (SELECT * FROM oyun.icisleri_dosya WHERE yetki OR yargi OR hedef=u ORDER BY acilis DESC LIMIT 40) d JOIN oyun.profiller p ON p.id=d.hedef),'[]'::jsonb));
END $$;

REVOKE ALL ON FUNCTION public.icisleri_basvur(text,text),public.icisleri_basvuru_karar(bigint,boolean,text),
 public.icisleri_sorusturma_ac(uuid,text,text),public.icisleri_savunma(bigint,text),public.icisleri_hakim_karar(bigint,text,text),
 public.icisleri_itiraz(bigint,text),public.icisleri_itiraz_karar(bigint,boolean,text),public.icisleri_oyuncu_ara(text),
 public.icisleri_komuta_panel() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.icisleri_basvur(text,text),public.icisleri_basvuru_karar(bigint,boolean,text),
 public.icisleri_sorusturma_ac(uuid,text,text),public.icisleri_savunma(bigint,text),public.icisleri_hakim_karar(bigint,text,text),
 public.icisleri_itiraz(bigint,text),public.icisleri_itiraz_karar(bigint,boolean,text),public.icisleri_oyuncu_ara(text),
 public.icisleri_komuta_panel() TO authenticated;
