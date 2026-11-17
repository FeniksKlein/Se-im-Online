-- Istinaf 2.0: gonullu hukuk kariyeri, dosya kabulu ve sureli heyet.
-- Gecmis adliye_juri/adliye_istinaf satirlari degistirilmez.
-- Yeni istinaf basvurulari sadece profesyonel kadroya aktarilir.
CREATE TABLE IF NOT EXISTS oyun.istinaf_hakimleri (
 user_id uuid PRIMARY KEY REFERENCES oyun.profiller(id),
 durum text NOT NULL DEFAULT 'aktif' CHECK (durum IN ('aktif','pasif','askida')),
 atanma timestamptz NOT NULL DEFAULT now(),
 hazir_son timestamptz,
 son_davet timestamptz,
 puan integer NOT NULL DEFAULT 100 CHECK (puan BETWEEN 0 AND 200),
 gorev_adet integer NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS oyun.istinaf_hakim_kurul_kayit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id uuid NOT NULL REFERENCES oyun.profiller(id),
 karar text NOT NULL CHECK (karar IN ('liyakat_onayi','gorevden_ayrilma','askiya_alma')),
 gerekce text NOT NULL,
 zaman timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS oyun.istinaf_hakim_dosya (
 dava_id bigint PRIMARY KEY REFERENCES oyun.adliye_istinaf(dava_id),
 durum text NOT NULL DEFAULT 'atama' CHECK (durum IN ('atama','karar')),
 olusturma timestamptz NOT NULL DEFAULT now(),
 karar_bas timestamptz,
 karar_son timestamptz,
 ek_sure_verildi boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS oyun.istinaf_hakim_davet (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 dava_id bigint NOT NULL REFERENCES oyun.istinaf_hakim_dosya(dava_id),
 user_id uuid NOT NULL REFERENCES oyun.profiller(id),
 durum text NOT NULL DEFAULT 'davet' CHECK (durum IN ('davet','kabul','ret','sure_doldu','degistirildi')),
 atama timestamptz NOT NULL DEFAULT now(),
 kabul_son timestamptz NOT NULL DEFAULT (now()+interval '10 minutes'),
 cevap_at timestamptz,
 UNIQUE (dava_id,user_id)
);
CREATE INDEX IF NOT EXISTS istinaf_davet_kisi_durum_idx ON oyun.istinaf_hakim_davet(user_id,durum,kabul_son);
CREATE INDEX IF NOT EXISTS istinaf_davet_dosya_durum_idx ON oyun.istinaf_hakim_davet(dava_id,durum);
CREATE INDEX IF NOT EXISTS istinaf_hakim_hazir_idx ON oyun.istinaf_hakimleri(durum,hazir_son);
REVOKE ALL ON oyun.istinaf_hakimleri,oyun.istinaf_hakim_kurul_kayit,oyun.istinaf_hakim_dosya,oyun.istinaf_hakim_davet FROM PUBLIC,anon,authenticated;
ALTER TABLE oyun.istinaf_hakimleri ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.istinaf_hakim_kurul_kayit ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.istinaf_hakim_dosya ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.istinaf_hakim_davet ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION oyun.istinaf_hakim_uygun(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $f$
SELECT EXISTS (
 SELECT 1 FROM oyun.profiller p JOIN oyun.hukuk_akademisi a ON a.user_id=p.id
 WHERE p.id=p_user AND NOT p.yasakli AND p.parti_id IS NULL
 AND a.sinav_gecildi IS NOT NULL AND a.pratik1 IS NOT NULL AND a.pratik2 IS NOT NULL
 AND NOT oyun.avukat_ruhsatli(p.id)
 AND NOT oyun.mahkeme_uyesi_mi(p.id)
 AND NOT EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.user_id=p.id AND m.bit IS NULL)
 AND NOT EXISTS(SELECT 1 FROM oyun.avukat_vekaletleri v WHERE v.avukat_id=p.id AND v.aktif)
);
$f$;
REVOKE ALL ON FUNCTION oyun.istinaf_hakim_uygun(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.istinaf_hakim_kontenjan()
RETURNS integer LANGUAGE sql STABLE SET search_path TO '' AS $f$
 SELECT LEAST(45,GREATEST(6,CEIL((SELECT count(*) FROM oyun.profiller
 WHERE NOT yasakli AND son_gorulme>oyun.simdi()-interval '7 days')/400.0)::int*3))
$f$;
REVOKE ALL ON FUNCTION oyun.istinaf_hakim_kontenjan() FROM PUBLIC,anon,authenticated;

-- Kural esasli bagimsiz sicil: siyasi atanma degil, mevcut akademi mezuniyeti ve liyakat.
CREATE OR REPLACE FUNCTION public.istinaf_hakim_basvur()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
DECLARE u uuid:=auth.uid(); n integer; mevcut text;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('istinaf_kadro_kabul'));
 IF NOT oyun.istinaf_hakim_uygun(u) THEN
  RAISE EXCEPTION 'Hukuk Akademisi sinavi ve iki staj tamamlanmali; aktif avukatlik, siyasi makam ve parti uyeligi bulunmamali.';
 END IF;
 SELECT durum INTO mevcut FROM oyun.istinaf_hakimleri WHERE user_id=u FOR UPDATE;
 IF mevcut='askida' THEN RAISE EXCEPTION 'Askidaki hakimlik basvurusu incelenmelidir.'; END IF;
 IF mevcut IS NULL THEN
   SELECT count(*) INTO n FROM oyun.istinaf_hakimleri WHERE durum='aktif';
   IF n >= oyun.istinaf_hakim_kontenjan() THEN
     RAISE EXCEPTION 'Istinaf hakimligi kontenjani dolu. Daha sonra yeniden basvurabilirsin.';
   END IF;
   INSERT INTO oyun.istinaf_hakimleri(user_id) VALUES(u);
   INSERT INTO oyun.istinaf_hakim_kurul_kayit(user_id,karar,gerekce)
    VALUES(u,'liyakat_onayi','Hukuk Akademisi sinavi ve iki staj, partisizlik ve gorev bagdasmazligi sistem tarafindan dogrulandi.');
 ELSE
   UPDATE oyun.istinaf_hakimleri SET durum='aktif' WHERE user_id=u;
 END IF;
 PERFORM oyun.bildir(u,'⚖️ Istinaf hakimligi kaydin aktif. Gorev almak icin Istinaf Hakimligi ekranindan Hazirim secenegini ac.');
 RETURN jsonb_build_object('tamam',true,'durum','aktif','kontenjan',oyun.istinaf_hakim_kontenjan());
END $f$;

CREATE OR REPLACE FUNCTION public.istinaf_hakim_hazir(p_hazir boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.istinaf_hakimleri WHERE user_id=u AND durum='aktif')
 THEN RAISE EXCEPTION 'Aktif hakimlik kaydin yok.'; END IF;
 IF p_hazir AND NOT oyun.istinaf_hakim_uygun(u) THEN
   RAISE EXCEPTION 'Hakimlik bagimsizligi veya hukuk egitimi sartlari artik saglanmiyor.';
 END IF;
 UPDATE oyun.istinaf_hakimleri SET hazir_son=CASE WHEN p_hazir THEN oyun.simdi()+interval '2 hours' ELSE NULL END
 WHERE user_id=u;
 RETURN jsonb_build_object('tamam',true,'hazir',coalesce(p_hazir,false));
END $f$;

CREATE OR REPLACE FUNCTION public.istinaf_hakim_istifa()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Giris gerekli.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.istinaf_hakim_davet v JOIN oyun.adliye_istinaf i ON i.dava_id=v.dava_id
 WHERE v.user_id=u AND v.durum='kabul' AND i.durum='acik') THEN
  RAISE EXCEPTION 'Once kabul ettigin acik dosyalari tamamlamalisin.';
 END IF;
 UPDATE oyun.istinaf_hakimleri SET durum='pasif',hazir_son=NULL WHERE user_id=u AND durum='aktif';
 IF NOT FOUND THEN RAISE EXCEPTION 'Aktif istinaf hakimligi bulunamadi.'; END IF;
 UPDATE oyun.istinaf_hakim_davet SET durum='ret',cevap_at=oyun.simdi() WHERE user_id=u AND durum='davet';
 INSERT INTO oyun.istinaf_hakim_kurul_kayit(user_id,karar,gerekce) VALUES(u,'gorevden_ayrilma','Oyuncunun gonullu istifasi.');
 RETURN jsonb_build_object('tamam',true);
END $f$;

CREATE OR REPLACE FUNCTION oyun.istinaf_hakim_davet_yap(p_dava bigint,p_t timestamptz DEFAULT oyun.simdi())
RETURNS integer LANGUAGE plpgsql SET search_path TO '' AS $f$
DECLARE d oyun.adliye_davalar; secilen uuid; adet integer; eklenen integer:=0;
BEGIN
 SELECT * INTO d FROM oyun.adliye_davalar WHERE id=p_dava;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM oyun.istinaf_hakim_dosya WHERE dava_id=p_dava AND durum='atama')
 OR NOT EXISTS(SELECT 1 FROM oyun.adliye_istinaf WHERE dava_id=p_dava AND durum='acik') THEN RETURN 0; END IF;
 LOOP
  SELECT count(*) INTO adet FROM oyun.istinaf_hakim_davet
   WHERE dava_id=p_dava AND durum IN ('davet','kabul');
  EXIT WHEN adet>=3;
  SELECT k.user_id INTO secilen FROM oyun.istinaf_hakimleri k
   JOIN oyun.profiller pr ON pr.id=k.user_id
   WHERE k.durum='aktif' AND k.hazir_son>p_t
    AND pr.son_gorulme>p_t-interval '15 minutes'
    AND oyun.istinaf_hakim_uygun(k.user_id)
    AND oyun.juri_aday_uygun(d,k.user_id,p_t)
    AND NOT EXISTS(SELECT 1 FROM oyun.istinaf_hakim_davet v
      WHERE v.dava_id=p_dava AND v.user_id=k.user_id)
    AND (SELECT count(*) FROM oyun.istinaf_hakim_davet v
      JOIN oyun.adliye_istinaf i ON i.dava_id=v.dava_id
      WHERE v.user_id=k.user_id AND i.durum='acik' AND v.durum='kabul')<2
   ORDER BY k.son_davet NULLS FIRST,pr.son_gorulme DESC,k.user_id
   LIMIT 1 FOR UPDATE OF k SKIP LOCKED;
  EXIT WHEN secilen IS NULL;
  INSERT INTO oyun.istinaf_hakim_davet(dava_id,user_id,atama,kabul_son)
   VALUES(p_dava,secilen,p_t,p_t+interval '10 minutes');
  UPDATE oyun.istinaf_hakimleri SET son_davet=p_t WHERE user_id=secilen;
  PERFORM oyun.bildir(secilen,format('⚖️ ISTINAF HAKIMLIGI: Dosya #%s icin gorev davetin var. 10 dakika icinde kabul veya ret et. Istinaf Hakimligi ekranini ac.',p_dava),p_t);
  eklenen:=eklenen+1; secilen:=NULL;
 END LOOP;
 RETURN eklenen;
END $f$;
REVOKE ALL ON FUNCTION oyun.istinaf_hakim_davet_yap(bigint,timestamptz) FROM PUBLIC,anon,authenticated;

-- Yalniz yeni dosyalari baglar; onceki juri kayitlarini degistirmez.
CREATE OR REPLACE FUNCTION oyun.istinaf_hakim_dosya_ac(p_dava bigint,p_t timestamptz)
RETURNS integer LANGUAGE plpgsql SET search_path TO '' AS $f$
BEGIN
 INSERT INTO oyun.istinaf_hakim_dosya(dava_id,olusturma) VALUES(p_dava,p_t) ON CONFLICT DO NOTHING;
 PERFORM oyun.istinaf_hakim_davet_yap(p_dava,p_t);
 RETURN 3; -- Basvuru kabul edildi; hedeflenen heyet 3 kisidir, uye sayisi bu donuste garanti edilmez.
END $f$;
REVOKE ALL ON FUNCTION oyun.istinaf_hakim_dosya_ac(bigint,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.istinaf_hakim_davet_cevap(p_davet bigint,p_kabul boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
DECLARE u uuid:=auth.uid(); v oyun.istinaf_hakim_davet; d oyun.adliye_davalar; adet integer; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR p_kabul IS NULL THEN RAISE EXCEPTION 'Oturum ve cevap gerekli.'; END IF;
 SELECT * INTO v FROM oyun.istinaf_hakim_davet WHERE id=p_davet FOR UPDATE;
 IF v.id IS NULL OR v.user_id IS DISTINCT FROM u THEN RAISE EXCEPTION 'Davet sana ait degil.'; END IF;
 PERFORM 1 FROM oyun.istinaf_hakim_dosya WHERE dava_id=v.dava_id FOR UPDATE;
 IF v.durum<>'davet' THEN RAISE EXCEPTION 'Davet daha once yanitlandi veya kapandi.'; END IF;
 IF t>v.kabul_son THEN
  UPDATE oyun.istinaf_hakim_davet SET durum='sure_doldu',cevap_at=t WHERE id=v.id;
  PERFORM oyun.istinaf_hakim_davet_yap(v.dava_id,t);
  RETURN jsonb_build_object('tamam',false,'neden','Davetin 10 dakikalik suresi doldu.');
 END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.adliye_istinaf WHERE dava_id=v.dava_id AND durum='acik')
 THEN RAISE EXCEPTION 'Dosya artik acik degil.'; END IF;
 IF p_kabul THEN
  SELECT * INTO d FROM oyun.adliye_davalar WHERE id=v.dava_id;
  IF NOT oyun.istinaf_hakim_uygun(u) OR NOT oyun.juri_aday_uygun(d,u,t)
   OR NOT EXISTS(SELECT 1 FROM oyun.istinaf_hakimleri WHERE user_id=u AND durum='aktif')
  THEN RAISE EXCEPTION 'Hakimlik veya tarafsizlik kosullarin degisti.'; END IF;
  UPDATE oyun.istinaf_hakim_davet SET durum='kabul',cevap_at=t WHERE id=v.id;
  INSERT INTO oyun.adliye_juri(dava_id,user_id,atama) VALUES(v.dava_id,u,t) ON CONFLICT DO NOTHING;
  UPDATE oyun.istinaf_hakimleri SET gorev_adet=gorev_adet+1 WHERE user_id=u;
 ELSE
  UPDATE oyun.istinaf_hakim_davet SET durum='ret',cevap_at=t WHERE id=v.id;
 END IF;
 SELECT count(*) INTO adet FROM oyun.istinaf_hakim_davet WHERE dava_id=v.dava_id AND durum='kabul';
 IF adet=3 AND EXISTS(SELECT 1 FROM oyun.istinaf_hakim_dosya WHERE dava_id=v.dava_id AND durum='atama') THEN
  UPDATE oyun.istinaf_hakim_dosya SET durum='karar',karar_bas=t,karar_son=t+interval '6 hours',
   ek_sure_verildi=false WHERE dava_id=v.dava_id;
  UPDATE oyun.adliye_istinaf SET bit=t+interval '6 hours' WHERE dava_id=v.dava_id;
  UPDATE oyun.adliye_davalar SET istinaf_son=t+interval '6 hours' WHERE id=v.dava_id;
  PERFORM oyun.bildir(x.user_id,format('⚖️ Istinaf #%s: 3 hakim gorevi kabul etti. Dosyayi 6 saat icinde inceleyip gerekceli onay veya bozma oyunuzu verin.',v.dava_id),t)
    FROM oyun.istinaf_hakim_davet x WHERE x.dava_id=v.dava_id AND x.durum='kabul';
 ELSIF NOT p_kabul THEN
  PERFORM oyun.istinaf_hakim_davet_yap(v.dava_id,t);
 END IF;
 RETURN jsonb_build_object('tamam',true,'kabul',p_kabul,'heyet_kabul',adet,'dava_id',v.dava_id);
END $f$;

CREATE OR REPLACE FUNCTION public.istinaf_hakim_panel()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $f$
DECLARE u uuid:=auth.uid(); k oyun.istinaf_hakimleri; a oyun.hukuk_akademisi;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli.'; END IF;
 SELECT * INTO k FROM oyun.istinaf_hakimleri WHERE user_id=u;
 SELECT * INTO a FROM oyun.hukuk_akademisi WHERE user_id=u;
 RETURN jsonb_build_object(
  'hakim',k.user_id IS NOT NULL,'durum',k.durum,'hazir',k.hazir_son>oyun.simdi(),
  'hazir_son',k.hazir_son,'puan',k.puan,
  'akademi_tamam',a.sinav_gecildi IS NOT NULL AND a.pratik1 IS NOT NULL AND a.pratik2 IS NOT NULL,
  'uygun',oyun.istinaf_hakim_uygun(u),
  'kontenjan',oyun.istinaf_hakim_kontenjan(),
  'kadro', (SELECT count(*) FROM oyun.istinaf_hakimleri WHERE durum='aktif'),
  'davetler',coalesce((SELECT jsonb_agg(jsonb_build_object('id',v.id,'dava_id',v.dava_id,'bit',v.kabul_son) ORDER BY v.kabul_son)
   FROM oyun.istinaf_hakim_davet v JOIN oyun.adliye_istinaf i ON i.dava_id=v.dava_id
   WHERE v.user_id=u AND v.durum='davet' AND v.kabul_son>oyun.simdi() AND i.durum='acik'),'[]'::jsonb),
  'dosyalar',coalesce((SELECT jsonb_agg(jsonb_build_object('dava_id',v.dava_id,'bas',g.karar_bas,'bit',g.karar_son,
    'durum',g.durum,'oy',j.oy) ORDER BY v.dava_id DESC)
   FROM oyun.istinaf_hakim_davet v JOIN oyun.istinaf_hakim_dosya g ON g.dava_id=v.dava_id
    JOIN oyun.adliye_istinaf i ON i.dava_id=v.dava_id
    LEFT JOIN oyun.adliye_juri j ON j.dava_id=v.dava_id AND j.user_id=u
   WHERE v.user_id=u AND v.durum='kabul' AND i.durum='acik'),'[]'::jsonb));
END $f$;

-- Yeni dosyalarin sure ve yedek islemleri. Eski davalara asla dokunmaz.
CREATE OR REPLACE FUNCTION oyun.istinaf_hakim_tick()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
DECLARE g record; t timestamptz:=oyun.simdi(); r record; adet integer; yeter boolean; acilan integer:=0; degisen integer:=0;
BEGIN
 IF NOT pg_try_advisory_xact_lock(hashtext('istinaf_hakim_tick')) THEN
  RETURN jsonb_build_object('calisti',false); END IF;
 FOR g IN SELECT h.dava_id,h.durum,h.karar_son,h.ek_sure_verildi
  FROM oyun.istinaf_hakim_dosya h JOIN oyun.adliye_istinaf i ON i.dava_id=h.dava_id
  WHERE i.durum='acik' ORDER BY h.dava_id FOR UPDATE OF h SKIP LOCKED LOOP
  UPDATE oyun.istinaf_hakim_davet SET durum='sure_doldu',cevap_at=t
   WHERE dava_id=g.dava_id AND durum='davet' AND kabul_son<=t;
  SELECT count(*) FILTER(WHERE oy='onay')>=2 OR count(*) FILTER(WHERE oy='boz')>=2
   INTO yeter FROM oyun.adliye_juri WHERE dava_id=g.dava_id;
  IF yeter THEN
    PERFORM oyun.adliye_istinaf_sonuc(g.dava_id,t);
    CONTINUE;
  END IF;
  IF g.durum='karar' AND g.karar_son<=t THEN
   IF NOT g.ek_sure_verildi THEN
    UPDATE oyun.istinaf_hakim_dosya SET ek_sure_verildi=true,karar_son=t+interval '4 hours'
     WHERE dava_id=g.dava_id;
    UPDATE oyun.adliye_istinaf SET bit=t+interval '4 hours' WHERE dava_id=g.dava_id;
    PERFORM oyun.bildir(v.user_id,format('Istinaf #%s: karar icin 4 saat ek sure verildi; gerekceli oyunu tamamla.',g.dava_id),t)
     FROM oyun.istinaf_hakim_davet v WHERE v.dava_id=g.dava_id AND v.durum='kabul'
       AND EXISTS(SELECT 1 FROM oyun.adliye_juri j WHERE j.dava_id=g.dava_id AND j.user_id=v.user_id AND j.oy IS NULL);
   ELSE
    FOR r IN SELECT v.id,v.user_id FROM oyun.istinaf_hakim_davet v JOIN oyun.adliye_juri j
     ON j.dava_id=v.dava_id AND j.user_id=v.user_id
     WHERE v.dava_id=g.dava_id AND v.durum='kabul' AND j.oy IS NULL FOR UPDATE OF v LOOP
      UPDATE oyun.istinaf_hakim_davet SET durum='degistirildi',cevap_at=t WHERE id=r.id;
      DELETE FROM oyun.adliye_juri WHERE dava_id=g.dava_id AND user_id=r.user_id AND oy IS NULL;
      UPDATE oyun.istinaf_hakimleri SET puan=greatest(0,puan-5),hazir_son=NULL WHERE user_id=r.user_id;
      PERFORM oyun.bildir(r.user_id,format('Istinaf #%s: kabul ettigin dosyada karar vermedigin icin gorevin yedege gecti.',g.dava_id),t);
      degisen:=degisen+1;
    END LOOP;
    UPDATE oyun.istinaf_hakim_dosya SET durum='atama',karar_son=NULL WHERE dava_id=g.dava_id;
    UPDATE oyun.adliye_istinaf SET bit=t+interval '24 hours' WHERE dava_id=g.dava_id;
   END IF;
  END IF;
  IF EXISTS(SELECT 1 FROM oyun.istinaf_hakim_dosya WHERE dava_id=g.dava_id AND durum='atama') THEN
    acilan:=acilan+oyun.istinaf_hakim_davet_yap(g.dava_id,t);
  END IF;
 END LOOP;
 RETURN jsonb_build_object('calisti',true,'davet',acilan,'degisen',degisen);
END $f$;
REVOKE ALL ON FUNCTION oyun.istinaf_hakim_tick() FROM PUBLIC,anon,authenticated;

-- Yalniz kimligi dogrulanmis oyuncular RPC cagirsin.
REVOKE ALL ON FUNCTION public.istinaf_hakim_basvur() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.istinaf_hakim_hazir(boolean) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.istinaf_hakim_istifa() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.istinaf_hakim_davet_cevap(bigint,boolean) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.istinaf_hakim_panel() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.istinaf_hakim_basvur() TO authenticated;
GRANT EXECUTE ON FUNCTION public.istinaf_hakim_hazir(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.istinaf_hakim_istifa() TO authenticated;
GRANT EXECUTE ON FUNCTION public.istinaf_hakim_davet_cevap(bigint,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.istinaf_hakim_panel() TO authenticated;


-- Taraflarin dosya ekraninda gorebildigi, kisisel uye verisi ifsa etmeyen heyet durumu.
CREATE OR REPLACE FUNCTION public.istinaf_hakim_dosya_durum(p_dava bigint)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $f$
SELECT CASE WHEN auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.istinaf_hakim_dosya WHERE dava_id=p_dava)
 THEN NULL ELSE (
 SELECT jsonb_build_object('durum',h.durum,'kabul',
   (SELECT count(*) FROM oyun.istinaf_hakim_davet v WHERE v.dava_id=p_dava AND v.durum='kabul'),
   'davet',(SELECT count(*) FROM oyun.istinaf_hakim_davet v WHERE v.dava_id=p_dava AND v.durum='davet'),
   'karar_son',h.karar_son,'ek_sure',h.ek_sure_verildi)
 FROM oyun.istinaf_hakim_dosya h WHERE h.dava_id=p_dava
 ) END
$f$;
REVOKE ALL ON FUNCTION public.istinaf_hakim_dosya_durum(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.istinaf_hakim_dosya_durum(bigint) TO authenticated;
