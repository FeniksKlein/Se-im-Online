-- İçişleri: ödüller, kamu anlaşmaları ve siyasi hesap verebilirlik.
CREATE TABLE IF NOT EXISTS oyun.icisleri_odul_v2(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 veren uuid NOT NULL REFERENCES oyun.profiller(id),
 hedef uuid NOT NULL REFERENCES oyun.profiller(id),
 tur text NOT NULL CHECK(tur IN ('kahramanlik','afet','kamu_hizmeti')),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 40 AND 800),
 para numeric NOT NULL DEFAULT 2000 CHECK(para BETWEEN 0 AND 2000),
 zaman timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ic_odul_v2_hedef ON oyun.icisleri_odul_v2(hedef,zaman DESC);
CREATE TABLE IF NOT EXISTS oyun.icisleri_anlasma_v2(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 bakan uuid NOT NULL REFERENCES oyun.profiller(id),
 oyuncu uuid NOT NULL REFERENCES oyun.profiller(id),
 kurum_tur text NOT NULL CHECK(kurum_tur IN ('oyuncu','sirket','dernek','belediye')),
 kurum_id bigint,
 tur text NOT NULL CHECK(tur IN ('afet','guvenlik','toplum')),
 aciklama text NOT NULL CHECK(char_length(aciklama) BETWEEN 60 AND 900),
 durum text NOT NULL DEFAULT 'teklif' CHECK(durum IN ('teklif','kabul','red','tamamlandi','odendi','iptal','suresi_doldu')),
 olusturma timestamptz NOT NULL DEFAULT now(),
 cevap_at timestamptz,
 rapor text,
 rapor_at timestamptz,
 karar_at timestamptz,
 karar_gerekce text,
 odeme numeric NOT NULL DEFAULT 4000 CHECK(odeme BETWEEN 0 AND 4000)
);
CREATE INDEX IF NOT EXISTS ic_anlasma_v2_oyuncu ON oyun.icisleri_anlasma_v2(oyuncu,olusturma DESC);
CREATE TABLE IF NOT EXISTS oyun.icisleri_sorumluluk_v2(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 basvuran uuid NOT NULL REFERENCES oyun.profiller(id),
 karar_id bigint REFERENCES oyun.icisleri_kriz_karar(id),
 olay_id bigint REFERENCES oyun.icisleri_olay_v2(id),
 konu text NOT NULL CHECK(char_length(konu) BETWEEN 25 AND 180),
 metin text NOT NULL CHECK(char_length(metin) BETWEEN 50 AND 1000),
 zaman timestamptz NOT NULL DEFAULT now(),
 durum text NOT NULL DEFAULT 'bekliyor' CHECK(durum IN ('bekliyor','yanitlandi','kapandi')),
 yanit_veren uuid REFERENCES oyun.profiller(id),
 yanit text,
 yanit_at timestamptz
);
CREATE INDEX IF NOT EXISTS ic_sorumluluk_v2_son ON oyun.icisleri_sorumluluk_v2(zaman DESC);
DO $rls$ DECLARE s text; BEGIN
 FOREACH s IN ARRAY ARRAY['icisleri_odul_v2','icisleri_anlasma_v2','icisleri_sorumluluk_v2'] LOOP
  EXECUTE format('ALTER TABLE oyun.%I ENABLE ROW LEVEL SECURITY',s);
  EXECUTE format('REVOKE ALL ON TABLE oyun.%I FROM PUBLIC,anon,authenticated',s);
 END LOOP;
END $rls$;

CREATE OR REPLACE FUNCTION public.icisleri_odul_ver(p_hedef uuid,p_tur text,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n bigint; ad text;
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'İçişleri Bakanlığı yetkisi gerekli'; END IF;
 IF p_hedef IS NULL OR p_hedef=u OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=p_hedef AND NOT yasakli)
 OR p_tur NOT IN ('kahramanlik','afet','kamu_hizmeti')
 OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 40 AND 800 THEN RAISE EXCEPTION 'Geçerli oyuncu, ödül türü ve 40 karakter gerekçe gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 IF (SELECT count(*) FROM oyun.icisleri_odul_v2 WHERE veren=u AND zaman>t-interval '24 hours')>=3 THEN RAISE EXCEPTION '24 saatte en fazla 3 devlet nişanı'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_odul_v2 WHERE hedef=p_hedef AND zaman>t-interval '7 days') THEN RAISE EXCEPTION 'Aynı oyuncu 7 gün içinde yeniden ödüllendirilemez'; END IF;
 PERFORM oyun.bm_kasa_harca('icisleri',52000/oyun.pazar_tl_milyar(),'gider','Devlet nişanı ve 2.000 TL ödülü');
 UPDATE oyun.cuzdan SET para=para+2000,kidem=kidem+1 WHERE user_id=p_hedef;
 IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
 INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(p_hedef,t,2000,'odul','İçişleri devlet nişanı / kamu hizmeti');
 INSERT INTO oyun.icisleri_odul_v2(veren,hedef,tur,gerekce,para,zaman) VALUES(u,p_hedef,p_tur,trim(p_gerekce),2000,t) RETURNING id INTO n;
 SELECT kad INTO ad FROM oyun.profiller WHERE id=p_hedef;
 INSERT INTO oyun.devlet_nisan(user_id,veren,ad,veren_unvan,gerekce,zaman) VALUES(p_hedef,u,CASE p_tur WHEN 'kahramanlik' THEN 'Kamu Güvenliği Kahramanlığı' WHEN 'afet' THEN 'Afet Dayanışma Nişanı' ELSE 'Kamu Hizmeti Nişanı' END,'İçişleri Bakanlığı',trim(p_gerekce),t);
 PERFORM oyun.bildir(p_hedef,'İçişleri Bakanlığı size devlet nişanı, 1 kıdem ve 2.000 TL verdi. Gerekçe: '||left(trim(p_gerekce),200));
 PERFORM oyun.gazete_ekle('icisleri','Devlet nişanı: '||ad,'İçişleri Bakanlığı devlet nişanı verdi. Gerekçe: '||left(trim(p_gerekce),400),n,t);
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_anlasma_teklif(p_oyuncu uuid,p_kurum_tur text,p_kurum_id bigint,p_tur text,p_aciklama text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); n bigint; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'Bakanlık yetkisi gerekli'; END IF;
 IF p_oyuncu IS NULL OR p_oyuncu=u OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=p_oyuncu AND NOT yasakli) THEN RAISE EXCEPTION 'Başka bir aktif oyuncu gerekli'; END IF;
 IF p_tur NOT IN ('afet','guvenlik','toplum') OR p_kurum_tur NOT IN ('oyuncu','sirket','dernek','belediye')
 OR length(trim(coalesce(p_aciklama,''))) NOT BETWEEN 60 AND 900 THEN RAISE EXCEPTION '60–900 karakter açıklama ve anlaşma türü gerekli'; END IF;
 IF p_kurum_tur='sirket' AND NOT EXISTS(SELECT 1 FROM oyun.sirketler WHERE id=p_kurum_id AND aktif AND (kurucu=p_oyuncu OR yonetici=p_oyuncu)) THEN RAISE EXCEPTION 'Teklif edilen oyuncu şirketin sahibi/yöneticisi olmalı'; END IF;
 IF p_kurum_tur='dernek' AND NOT EXISTS(SELECT 1 FROM oyun.dernekler WHERE id=p_kurum_id AND NOT kapali AND baskan=p_oyuncu) THEN RAISE EXCEPTION 'Teklif edilen oyuncu dernek başkanı olmalı'; END IF;
 IF p_kurum_tur='belediye' AND NOT EXISTS(SELECT 1 FROM oyun.makamlar WHERE tur='bel' AND bit IS NULL AND il_id=p_kurum_id AND user_id=p_oyuncu) THEN RAISE EXCEPTION 'Teklif edilen oyuncu ilgili belediye başkanı olmalı'; END IF;
 IF p_kurum_tur='oyuncu' AND p_kurum_id IS NOT NULL THEN RAISE EXCEPTION 'Oyuncu anlaşmasında kurum numarası boş bırakılmalı'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 IF (SELECT count(*) FROM oyun.icisleri_anlasma_v2 WHERE bakan=u AND olusturma>t-interval '24 hours')>=5 THEN RAISE EXCEPTION '24 saatte en fazla 5 kamu anlaşması teklifi'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_anlasma_v2 WHERE oyuncu=p_oyuncu AND durum IN ('teklif','kabul','tamamlandi')) THEN RAISE EXCEPTION 'Oyuncunun bekleyen kamu anlaşması var'; END IF;
 INSERT INTO oyun.icisleri_anlasma_v2(bakan,oyuncu,kurum_tur,kurum_id,tur,aciklama,olusturma)
 VALUES(u,p_oyuncu,p_kurum_tur,p_kurum_id,p_tur,trim(p_aciklama),t) RETURNING id INTO n;
 PERFORM oyun.bildir(p_oyuncu,'İçişleri Bakanlığından kamu hizmeti anlaşması #'||n||' teklifi var; kabul veya ret hakkınız var.');
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_anlasma_yanit(p_id bigint,p_kabul boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_anlasma_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR p_kabul IS NULL THEN RAISE EXCEPTION 'Yanıt gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO x FROM oyun.icisleri_anlasma_v2 WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.oyuncu<>u OR x.durum<>'teklif' OR x.olusturma<t-interval '48 hours' THEN RAISE EXCEPTION 'Yanıtlanabilir anlaşma yok'; END IF;
 UPDATE oyun.icisleri_anlasma_v2 SET durum=CASE WHEN p_kabul THEN 'kabul' ELSE 'red' END,cevap_at=t WHERE id=p_id;
 PERFORM oyun.bildir(x.bakan,'Kamu anlaşması #'||p_id||' '||CASE WHEN p_kabul THEN 'kabul edildi' ELSE 'reddedildi' END);
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_anlasma_rapor(p_id bigint,p_rapor text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_anlasma_v2;
BEGIN
 IF u IS NULL OR length(trim(coalesce(p_rapor,''))) NOT BETWEEN 60 AND 900 THEN RAISE EXCEPTION '60–900 karakter gerçekleştirilen faaliyet raporu gerekli'; END IF;
 SELECT * INTO x FROM oyun.icisleri_anlasma_v2 WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.oyuncu<>u OR x.durum<>'kabul' OR x.cevap_at<oyun.simdi()-interval '72 hours' THEN RAISE EXCEPTION 'Raporlanabilir aktif anlaşma yok'; END IF;
 UPDATE oyun.icisleri_anlasma_v2 SET durum='tamamlandi',rapor=trim(p_rapor),rapor_at=oyun.simdi() WHERE id=p_id;
 PERFORM oyun.bildir(x.bakan,'Kamu anlaşması #'||p_id||' faaliyet raporu sunuldu. Ödeme onayı bekliyor.');
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_anlasma_kapat(p_id bigint,p_onay boolean,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_anlasma_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL OR p_onay IS NULL OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 800 THEN RAISE EXCEPTION 'Bakanlık yetkisi ve 25 karakter karar gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO x FROM oyun.icisleri_anlasma_v2 WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'tamamlandi' OR x.oyuncu=u THEN RAISE EXCEPTION 'Raporlanmış ve bakan dışındaki oyuncuyla yapılmış anlaşma gerekli'; END IF;
 IF p_onay THEN
  PERFORM oyun.bm_kasa_harca('icisleri', (25000+x.odeme)/oyun.pazar_tl_milyar(),'gider','Tamamlanan kamu hizmeti anlaşması #'||x.id);
  UPDATE oyun.cuzdan SET para=para+x.odeme,kidem=kidem+0.5 WHERE user_id=x.oyuncu;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
  INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(x.oyuncu,t,x.odeme,'yardim','Onaylı İçişleri kamu hizmeti anlaşması #'||x.id);
 END IF;
 UPDATE oyun.icisleri_anlasma_v2 SET durum=CASE WHEN p_onay THEN 'odendi' ELSE 'iptal' END,karar_at=t,karar_gerekce=trim(p_gerekce) WHERE id=p_id;
 PERFORM oyun.bildir(x.oyuncu,'Kamu hizmeti anlaşması #'||x.id||' '||CASE WHEN p_onay THEN 'onaylandı ve 4.000 TL ödendi' ELSE 'raporunuz reddedildi' END||'. Gerekçe: '||left(trim(p_gerekce),200));
 PERFORM oyun.gazete_ekle('icisleri','Kamu hizmeti anlaşması #'||x.id,CASE WHEN p_onay THEN 'Faaliyet teslim alındı ve ödeme yapıldı.' ELSE 'Kamu hizmeti faaliyeti kabul edilmedi.' END||' Gerekçe: '||left(trim(p_gerekce),400),x.id,t);
 RETURN jsonb_build_object('tamam',true,'odendi',p_onay);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_sorumluluk_sor(p_karar bigint,p_olay bigint,p_konu text,p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); n bigint; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=u AND NOT yasakli) THEN RAISE EXCEPTION 'Giriş gerekli'; END IF;
 IF length(trim(coalesce(p_konu,''))) NOT BETWEEN 25 AND 180 OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 50 AND 1000 THEN RAISE EXCEPTION '25 karakter konu ve 50 karakter soru metni gerekli'; END IF;
 IF p_karar IS NOT NULL AND NOT EXISTS(SELECT 1 FROM oyun.icisleri_kriz_karar WHERE id=p_karar) THEN RAISE EXCEPTION 'Özel güvenlik kararı bulunamadı'; END IF;
 IF p_olay IS NOT NULL AND NOT EXISTS(SELECT 1 FROM oyun.icisleri_olay_v2 WHERE id=p_olay AND (basvuran=u OR hedef=u)) THEN RAISE EXCEPTION 'Kendi dosyanıza ait olay seçin'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 IF (SELECT count(*) FROM oyun.icisleri_sorumluluk_v2 WHERE basvuran=u AND zaman>t-interval '24 hours')>=2 THEN RAISE EXCEPTION '24 saatte en fazla 2 yazılı soru'; END IF;
 INSERT INTO oyun.icisleri_sorumluluk_v2(basvuran,karar_id,olay_id,konu,metin,zaman) VALUES(u,p_karar,p_olay,trim(p_konu),trim(p_metin),t) RETURNING id INTO n;
 IF oyun.bakanlik_yetkilisi('icisleri') IS NOT NULL THEN
  PERFORM oyun.bildir(oyun.bakanlik_yetkilisi('icisleri'),'İçişleri Bakanlığına yazılı hesap verme sorusu #'||n||' gönderildi.');
 END IF;
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_sorumluluk_yanit(p_id bigint,p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_sorumluluk_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 50 AND 1200 THEN RAISE EXCEPTION 'Bakanlık yetkisi ve en az 50 karakter yanıt gerekli'; END IF;
 SELECT * INTO x FROM oyun.icisleri_sorumluluk_v2 WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'bekliyor' THEN RAISE EXCEPTION 'Bekleyen soru yok'; END IF;
 UPDATE oyun.icisleri_sorumluluk_v2 SET durum='yanitlandi',yanit_veren=u,yanit=trim(p_metin),yanit_at=t WHERE id=p_id;
 PERFORM oyun.bildir(x.basvuran,'İçişleri Bakanlığı yazılı sorunuzu #'||p_id||' yanıtladı.');
 PERFORM oyun.gazete_ekle('icisleri','Bakanlık hesap verme yanıtı #'||p_id,x.konu||': '||left(trim(p_metin),420),p_id,t);
 RETURN jsonb_build_object('tamam',true);
END $$;

DO $exec$ DECLARE p regprocedure; BEGIN
 FOREACH p IN ARRAY ARRAY[
 'public.icisleri_odul_ver(uuid,text,text)'::regprocedure,
 'public.icisleri_anlasma_teklif(uuid,text,bigint,text,text)'::regprocedure,
 'public.icisleri_anlasma_yanit(bigint,boolean)'::regprocedure,
 'public.icisleri_anlasma_rapor(bigint,text)'::regprocedure,
 'public.icisleri_anlasma_kapat(bigint,boolean,text)'::regprocedure,
 'public.icisleri_sorumluluk_sor(bigint,bigint,text,text)'::regprocedure,
 'public.icisleri_sorumluluk_yanit(bigint,text)'::regprocedure
 ] LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',p);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',p);
 END LOOP;
END $exec$;
