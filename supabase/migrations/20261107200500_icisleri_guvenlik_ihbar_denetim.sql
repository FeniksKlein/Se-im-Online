-- Seçim Online · İçişleri oyuncu güvenliği, ihbar ve denetim 2026-11-07
-- Var olan oyuncu, şirket, para ve makam kayıtlarını silmez/güncellemez.
CREATE TABLE IF NOT EXISTS oyun.icisleri_olay_v2(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 basvuran uuid NOT NULL REFERENCES oyun.profiller(id),
 tur text NOT NULL CHECK (tur IN ('tehdit','ihbar','yolsuzluk','denetim','siyasi','kriz')),
 kurum_tur text NOT NULL CHECK (kurum_tur IN ('oyuncu','sirket','dernek','belediye','makam')),
 kurum_id bigint,
 hedef uuid REFERENCES oyun.profiller(id),
 baslik text NOT NULL CHECK (char_length(baslik) BETWEEN 18 AND 180),
 delil text NOT NULL CHECK (char_length(delil) BETWEEN 40 AND 1200),
 durum text NOT NULL DEFAULT 'ihbar' CHECK (durum IN ('ihbar','inceleme','adliye','reddedildi','kapandi')),
 acilis timestamptz NOT NULL DEFAULT now(),
 bakan uuid REFERENCES oyun.profiller(id),
 bakan_gerekce text,
 sevk_at timestamptz,
 savunma text,
 savunma_at timestamptz,
 kapanis_at timestamptz
);
CREATE INDEX IF NOT EXISTS ic_olay_v2_basvuran ON oyun.icisleri_olay_v2(basvuran,acilis DESC);
CREATE INDEX IF NOT EXISTS ic_olay_v2_hedef ON oyun.icisleri_olay_v2(hedef,acilis DESC);
CREATE INDEX IF NOT EXISTS ic_olay_v2_durum ON oyun.icisleri_olay_v2(durum,acilis DESC);
CREATE TABLE IF NOT EXISTS oyun.icisleri_koruma_v2(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 isteyen uuid NOT NULL REFERENCES oyun.profiller(id),
 hedef uuid NOT NULL REFERENCES oyun.profiller(id),
 tur text NOT NULL CHECK(tur IN ('koruma','tanik')),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 40 AND 800),
 olay_id bigint REFERENCES oyun.icisleri_olay_v2(id),
 durum text NOT NULL DEFAULT 'bekliyor' CHECK (durum IN ('bekliyor','onay','red','iptal','sona_erdi')),
 basvuru_at timestamptz NOT NULL DEFAULT now(),
 karar_veren uuid REFERENCES oyun.profiller(id),
 karar_at timestamptz,
 karar_gerekce text,
 bitis timestamptz
);
CREATE INDEX IF NOT EXISTS ic_koruma_hedef ON oyun.icisleri_koruma_v2(hedef,basvuru_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS ic_koruma_tek_aktif ON oyun.icisleri_koruma_v2(hedef,tur) WHERE durum='onay';
CREATE TABLE IF NOT EXISTS oyun.icisleri_tedbir_v2(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 olay_id bigint NOT NULL REFERENCES oyun.icisleri_olay_v2(id),
 tur text NOT NULL CHECK(tur IN ('ifade','arama','gozalti','faaliyet','ihale','ceza','tazminat')),
 bakan uuid NOT NULL REFERENCES oyun.profiller(id),
 hedef uuid REFERENCES oyun.profiller(id),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 40 AND 1000),
 tutar numeric NOT NULL DEFAULT 0 CHECK(tutar >= 0),
 durum text NOT NULL DEFAULT 'talep' CHECK(durum IN ('talep','onay','red','itiraz','kaldirildi','sona_erdi')),
 acilis timestamptz NOT NULL DEFAULT now(),
 hakim uuid REFERENCES oyun.profiller(id),
 karar_at timestamptz,
 karar_gerekce text,
 bitis timestamptz,
 itiraz_metin text,
 itiraz_at timestamptz,
 itiraz_hakim uuid REFERENCES oyun.profiller(id),
 itiraz_karar text,
 itiraz_karar_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS ic_tedbir_tek_acik ON oyun.icisleri_tedbir_v2(olay_id,tur) WHERE durum IN ('talep','onay','itiraz');
CREATE INDEX IF NOT EXISTS ic_tedbir_hedef ON oyun.icisleri_tedbir_v2(hedef,acilis DESC);
CREATE TABLE IF NOT EXISTS oyun.icisleri_gorev_kayit_v2(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 yapan uuid NOT NULL REFERENCES oyun.profiller(id),
 tur text NOT NULL,
 konu_id bigint NOT NULL,
 aciklama text NOT NULL,
 zaman timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ic_gorev_kayit_son ON oyun.icisleri_gorev_kayit_v2(zaman DESC);
DO $rls$ DECLARE s text; BEGIN
 FOREACH s IN ARRAY ARRAY['icisleri_olay_v2','icisleri_koruma_v2','icisleri_tedbir_v2','icisleri_gorev_kayit_v2'] LOOP
  EXECUTE format('ALTER TABLE oyun.%I ENABLE ROW LEVEL SECURITY',s);
  EXECUTE format('REVOKE ALL ON TABLE oyun.%I FROM PUBLIC,anon,authenticated',s);
 END LOOP;
END $rls$;

CREATE OR REPLACE FUNCTION public.icisleri_kisi_ara(p_ara text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giriş gerekli'; END IF;
 IF length(trim(coalesce(p_ara,'')))<2 THEN RETURN '[]'::jsonb; END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',p.id,'ad',p.kad)) FROM
 (SELECT id,kad FROM oyun.profiller WHERE NOT yasakli AND kad ILIKE '%'||left(trim(p_ara),40)||'%' ORDER BY kad LIMIT 12)p),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_kurum_ara(p_tur text,p_ara text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giriş gerekli'; END IF;
 IF length(trim(coalesce(p_ara,'')))<2 THEN RETURN '[]'::jsonb; END IF;
 IF p_tur='sirket' THEN
   RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad)) FROM
    (SELECT id,ad FROM oyun.sirketler WHERE aktif AND ad ILIKE '%'||left(trim(p_ara),40)||'%' ORDER BY ad LIMIT 12)s),'[]'::jsonb);
 ELSIF p_tur='dernek' THEN
   RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',d.id,'ad',d.ad)) FROM
    (SELECT id,ad FROM oyun.dernekler WHERE NOT kapali AND ad ILIKE '%'||left(trim(p_ara),40)||'%' ORDER BY ad LIMIT 12)d),'[]'::jsonb);
 ELSIF p_tur='belediye' THEN
   RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad)) FROM
    (SELECT id,ad FROM oyun.iller WHERE ad ILIKE '%'||left(trim(p_ara),40)||'%' ORDER BY ad LIMIT 12)i),'[]'::jsonb);
 ELSIF p_tur='makam' THEN
   RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',m.id,'ad',m.tur||' · '||p.kad)) FROM
    (SELECT id,tur,user_id FROM oyun.makamlar WHERE bit IS NULL ORDER BY id LIMIT 150)m JOIN oyun.profiller p ON p.id=m.user_id WHERE (m.tur||' · '||p.kad) ILIKE '%'||left(trim(p_ara),40)||'%'),'[]'::jsonb);
 ELSE RAISE EXCEPTION 'Geçerli kurum türü seçin'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_olay_bildir(p_tur text,p_kurum_tur text,p_kurum_id bigint,p_hedef uuid,p_baslik text,p_delil text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); h uuid; n bigint; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=u AND NOT yasakli) THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 IF p_tur NOT IN ('tehdit','ihbar','yolsuzluk','denetim','siyasi','kriz') OR p_kurum_tur NOT IN ('oyuncu','sirket','dernek','belediye','makam') THEN RAISE EXCEPTION 'Geçersiz ihbar/kurum türü'; END IF;
 IF length(trim(coalesce(p_baslik,''))) NOT BETWEEN 18 AND 180 OR length(trim(coalesce(p_delil,''))) NOT BETWEEN 40 AND 1200 THEN RAISE EXCEPTION '18–180 karakter konu ve 40–1200 karakter oyun içi delil gerekli'; END IF;
 IF p_kurum_tur='oyuncu' THEN
   IF p_hedef IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=p_hedef AND NOT yasakli) THEN RAISE EXCEPTION 'Geçerli hedef oyuncu seçin'; END IF; h:=p_hedef;
 ELSIF p_kurum_tur='sirket' THEN
   SELECT coalesce(s.yonetici,s.kurucu) INTO h FROM oyun.sirketler s WHERE s.id=p_kurum_id AND s.aktif;
 ELSIF p_kurum_tur='dernek' THEN
   SELECT coalesce(d.baskan,d.kurucu) INTO h FROM oyun.dernekler d WHERE d.id=p_kurum_id AND NOT d.kapali;
 ELSIF p_kurum_tur='belediye' THEN
   IF NOT EXISTS(SELECT 1 FROM oyun.iller WHERE id=p_kurum_id) THEN RAISE EXCEPTION 'Böyle bir il yok'; END IF;
   SELECT user_id INTO h FROM oyun.makamlar WHERE il_id=p_kurum_id AND bit IS NULL AND tur IN ('belediye','bel') ORDER BY bas DESC LIMIT 1;
 ELSIF p_kurum_tur='makam' THEN
   SELECT user_id INTO h FROM oyun.makamlar WHERE id=p_kurum_id AND bit IS NULL;
 END IF;
 IF p_kurum_tur IN ('sirket','dernek','makam') AND h IS NULL THEN RAISE EXCEPTION 'Kurum veya aktif makam bulunamadı'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 IF (SELECT count(*) FROM oyun.icisleri_olay_v2 WHERE basvuran=u AND acilis>t-interval '24 hours')>=3 THEN RAISE EXCEPTION '24 saatte en fazla üç ihbar hakkı var'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_olay_v2 WHERE basvuran=u AND hedef IS NOT DISTINCT FROM h AND kurum_tur=p_kurum_tur AND kurum_id IS NOT DISTINCT FROM p_kurum_id AND acilis>t-interval '24 hours') THEN RAISE EXCEPTION 'Aynı kişi veya kuruma yeni ihbar için 24 saat bekleyin'; END IF;
 INSERT INTO oyun.icisleri_olay_v2(basvuran,tur,kurum_tur,kurum_id,hedef,baslik,delil,acilis)
 VALUES(u,p_tur,p_kurum_tur,CASE WHEN p_kurum_tur='oyuncu' THEN NULL ELSE p_kurum_id END,h,trim(p_baslik),trim(p_delil),t) RETURNING id INTO n;
 PERFORM oyun.bildir(u,'İçişleri ihbar/dilekçe #'||n||' alındı. İhbar suç veya kesin hüküm sayılmaz.');
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_olay_sevk(p_id bigint,p_islem text,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'İçişleri yetkisi gerekli'; END IF;
 IF p_islem NOT IN ('inceleme','adliye','reddedildi','kapandi') OR char_length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 700 THEN RAISE EXCEPTION 'Gerekçeli geçerli işlem seçin'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum NOT IN ('ihbar','inceleme','adliye') THEN RAISE EXCEPTION 'Aktif dosya yok'; END IF;
 IF x.basvuran=u OR x.hedef=u THEN RAISE EXCEPTION 'Dosyanın tarafı kendi hakkında karar alamaz'; END IF;
 IF p_islem='adliye' AND x.durum NOT IN ('inceleme','adliye') THEN RAISE EXCEPTION 'Önce idari inceleme gerekir'; END IF;
 IF x.durum='adliye' AND p_islem='inceleme' THEN RAISE EXCEPTION 'Mahkemeye sevk edilmiş dosya geri alınamaz'; END IF;
 UPDATE oyun.icisleri_olay_v2 SET durum=p_islem,bakan=u,bakan_gerekce=trim(p_gerekce),sevk_at=t,kapanis_at=CASE WHEN p_islem IN ('reddedildi','kapandi') THEN t END WHERE id=p_id;
 IF x.hedef IS NOT NULL THEN PERFORM oyun.bildir(x.hedef,'İçişleri dosyası #'||p_id||' yeni durum: '||p_islem||'. Savunma hakkınız vardır.'); END IF;
 PERFORM oyun.bildir(x.basvuran,'İçişleri ihbarınız #'||p_id||' durum: '||p_islem||'. '||left(trim(p_gerekce),120));
 INSERT INTO oyun.icisleri_gorev_kayit_v2(yapan,tur,konu_id,aciklama,zaman) VALUES(u,'olay_sevk',p_id,p_islem||': '||trim(p_gerekce),t);
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_olay_savun(p_id bigint,p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_olay_v2;
BEGIN
 IF u IS NULL OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 30 AND 1200 THEN RAISE EXCEPTION 'En az 30 karakter savunma gerekli'; END IF;
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.hedef IS DISTINCT FROM u OR x.durum NOT IN ('inceleme','adliye') OR x.savunma IS NOT NULL THEN RAISE EXCEPTION 'Savunma hakkınız olan açık dosya bulunamadı'; END IF;
 UPDATE oyun.icisleri_olay_v2 SET savunma=trim(p_metin),savunma_at=oyun.simdi() WHERE id=p_id;
 IF x.bakan IS NOT NULL THEN PERFORM oyun.bildir(x.bakan,'İçişleri dosyası #'||p_id||' için savunma sunuldu'); END IF;
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_koruma_basvur(p_tur text,p_gerekce text,p_olay bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n bigint;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=u AND NOT yasakli) THEN RAISE EXCEPTION 'Giriş gerekli'; END IF;
 IF p_tur NOT IN ('koruma','tanik') OR char_length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 40 AND 800 THEN RAISE EXCEPTION '40–800 karakter güvenlik gerekçesi gerekli'; END IF;
 IF p_tur='tanik' AND (p_olay IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.icisleri_olay_v2 WHERE id=p_olay AND (basvuran=u OR hedef=u))) THEN RAISE EXCEPTION 'Tanık koruması için taraf olduğunuz dosya gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 UPDATE oyun.icisleri_koruma_v2 SET durum='sona_erdi' WHERE durum='onay' AND bitis<=t;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_koruma_v2 WHERE isteyen=u AND tur=p_tur AND (durum IN ('bekliyor','onay') OR basvuru_at>t-interval '24 hours')) THEN RAISE EXCEPTION 'Aynı türde aktif veya yakın tarihli başvurunuz var'; END IF;
 INSERT INTO oyun.icisleri_koruma_v2(isteyen,hedef,tur,gerekce,olay_id,basvuru_at) VALUES(u,u,p_tur,trim(p_gerekce),p_olay,t) RETURNING id INTO n;
 PERFORM oyun.bildir(u,'Koruma başvurusu #'||n||' alındı.');
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_koruma_karar(p_id bigint,p_kabul boolean,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_koruma_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'Bakanlık yetkisi gerekli'; END IF;
 IF p_kabul IS NULL OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 600 THEN RAISE EXCEPTION '25–600 karakter gerekçe gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO x FROM oyun.icisleri_koruma_v2 WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'bekliyor' THEN RAISE EXCEPTION 'Bekleyen başvuru yok'; END IF;
 IF x.hedef=u THEN RAISE EXCEPTION 'Bakan kendi koruma başvurusunu onaylayamaz'; END IF;
 UPDATE oyun.icisleri_koruma_v2 SET durum='sona_erdi' WHERE durum='onay' AND bitis<=t;
 IF p_kabul AND EXISTS(SELECT 1 FROM oyun.icisleri_koruma_v2 WHERE hedef=x.hedef AND tur=x.tur AND durum='onay') THEN RAISE EXCEPTION 'Oyuncuya mevcut aktif koruma verilmiş'; END IF;
 IF p_kabul THEN
  IF (SELECT count(*) FROM oyun.icisleri_koruma_v2 WHERE karar_at>t-interval '24 hours' AND durum='onay')>=8 THEN RAISE EXCEPTION 'Günlük 8 koruma sınırı'; END IF;
  PERFORM oyun.bm_kasa_harca('icisleri',100000/oyun.pazar_tl_milyar(),'gider','Koruma programı #'||x.id);
 END IF;
 UPDATE oyun.icisleri_koruma_v2 SET durum=CASE WHEN p_kabul THEN 'onay' ELSE 'red' END,karar_veren=u,karar_at=t,karar_gerekce=trim(p_gerekce),bitis=CASE WHEN p_kabul THEN t+interval '24 hours' END WHERE id=p_id;
 PERFORM oyun.bildir(x.hedef,'Koruma talebi #'||p_id||' '||CASE WHEN p_kabul THEN 'onaylandı: 24 saat geçerli' ELSE 'reddedildi' END||'.');
 INSERT INTO oyun.icisleri_gorev_kayit_v2(yapan,tur,konu_id,aciklama,zaman) VALUES(u,'koruma',p_id,CASE WHEN p_kabul THEN 'onay' ELSE 'red' END||' '||trim(p_gerekce),t);
 RETURN jsonb_build_object('tamam',true);
END $$;

DO $exec$ DECLARE p regprocedure; BEGIN
 FOREACH p IN ARRAY ARRAY[
 'public.icisleri_kisi_ara(text)'::regprocedure,
 'public.icisleri_kurum_ara(text,text)'::regprocedure,
 'public.icisleri_olay_bildir(text,text,bigint,uuid,text,text)'::regprocedure,
 'public.icisleri_olay_sevk(bigint,text,text)'::regprocedure,
 'public.icisleri_olay_savun(bigint,text)'::regprocedure,
 'public.icisleri_koruma_basvur(text,text,bigint)'::regprocedure,
 'public.icisleri_koruma_karar(bigint,boolean,text)'::regprocedure
 ] LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',p);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',p);
 END LOOP;
END $exec$;
