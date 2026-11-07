-- İçişleri · bağımsız mahkeme, sınırlı tedbir, ifade, avukat, itiraz ve tazminat
ALTER TABLE oyun.icisleri_tedbir_v2 ADD COLUMN IF NOT EXISTS ifade text;
ALTER TABLE oyun.icisleri_tedbir_v2 ADD COLUMN IF NOT EXISTS ifade_at timestamptz;
ALTER TABLE oyun.icisleri_tedbir_v2 ADD COLUMN IF NOT EXISTS avukat uuid REFERENCES oyun.profiller(id);
ALTER TABLE oyun.icisleri_tedbir_v2 ADD COLUMN IF NOT EXISTS avukat_durum text NOT NULL DEFAULT 'yok' CHECK(avukat_durum IN ('yok','cagrildi','kabul','red'));
ALTER TABLE oyun.icisleri_tedbir_v2 ADD COLUMN IF NOT EXISTS inceleme_ozet text;

-- Sadece aktif ve mahkeme onaylı oyun içi etkileri sorgular.
CREATE OR REPLACE FUNCTION oyun.icisleri_ihale_yasagi_v2(p_sirket bigint)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(
   SELECT 1 FROM oyun.icisleri_tedbir_v2 d
   JOIN oyun.icisleri_olay_v2 o ON o.id=d.olay_id
   WHERE o.kurum_tur='sirket' AND o.kurum_id=p_sirket AND d.tur IN ('ihale','faaliyet')
     AND d.durum='onay' AND d.bitis>oyun.simdi()
 )
$$;
CREATE OR REPLACE FUNCTION oyun.icisleri_gozaltinda_v2(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM oyun.icisleri_tedbir_v2 WHERE hedef=p_user AND tur='gozalti' AND durum='onay' AND bitis>oyun.simdi())
$$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_iste(p_olay bigint,p_tur text,p_gerekce text,p_tutar numeric DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); o oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi(); n bigint; tut numeric:=coalesce(p_tutar,0);
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'İçişleri yetkisi gerekli'; END IF;
 IF p_tur NOT IN ('ifade','arama','gozalti','faaliyet','ihale','ceza','tazminat') OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 40 AND 1000 THEN RAISE EXCEPTION '40–1000 karakter hukuki gerekçe gerekli'; END IF;
 IF p_tur IN ('ceza','tazminat') AND (tut<0 OR tut>CASE WHEN p_tur='ceza' THEN 2000 ELSE 5000 END OR tut<>round(tut) OR tut=0) THEN RAISE EXCEPTION 'Para cezası 1–2.000, tazminat 1–5.000 TL olabilir'; END IF;
 IF p_tur NOT IN ('ceza','tazminat') AND tut<>0 THEN RAISE EXCEPTION 'Bu tedbirde para tutarı kullanılmaz'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO o FROM oyun.icisleri_olay_v2 WHERE id=p_olay FOR UPDATE;
 IF o.id IS NULL OR o.durum<>'adliye' OR o.hedef IS NULL THEN RAISE EXCEPTION 'Mahkemeye sevk edilmiş, gerçek oyunculu açık dosya gerekli'; END IF;
 IF o.basvuran=u OR o.hedef=u THEN RAISE EXCEPTION 'Dosya tarafı kendisi hakkında tedbir isteyemez'; END IF;
 IF p_tur IN ('faaliyet','ihale','arama') AND o.kurum_tur NOT IN ('sirket','dernek') THEN RAISE EXCEPTION 'Bu tedbir şirket/dernek dosyasında kullanılabilir'; END IF;
 IF p_tur IN ('faaliyet','ihale') AND o.kurum_tur<>'sirket' THEN RAISE EXCEPTION 'Süreli ihale/işletme kısıtı yalnız şirket için'; END IF;
 IF (SELECT count(*) FROM oyun.icisleri_tedbir_v2 WHERE bakan=u AND acilis>t-interval '24 hours')>=6 THEN RAISE EXCEPTION '24 saatte en fazla 6 mahkeme tedbiri talebi'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_tedbir_v2 WHERE olay_id=p_olay AND tur=p_tur AND durum IN ('talep','onay','itiraz')) THEN RAISE EXCEPTION 'Bu dosyada aynı türden açık tedbir mevcut'; END IF;
 PERFORM oyun.bm_kasa_harca('icisleri',25000/oyun.pazar_tl_milyar(),'gider','Yargı gözetimli tedbir başvurusu');
 INSERT INTO oyun.icisleri_tedbir_v2(olay_id,tur,bakan,hedef,gerekce,tutar,acilis)
 VALUES(p_olay,p_tur,u,o.hedef,trim(p_gerekce),tut,t) RETURNING id INTO n;
 PERFORM oyun.bildir(o.hedef,'İçişleri dosyası #'||p_olay||': '||p_tur||' tedbiri mahkeme onayına sunuldu. Savunma, avukat ve itiraz hakları geçerli.');
 INSERT INTO oyun.bildirimler(user_id,zaman,metin)
  SELECT hakim,t,'İçişleri tedbir talebi #'||n||' için bağımsız mahkeme kararı bekleniyor.' FROM oyun.adliye_makam WHERE hakim IS NOT NULL AND hakim<>u AND hakim<>o.hedef;
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_karar(p_id bigint,p_onay boolean,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); d oyun.icisleri_tedbir_v2; o oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi(); tut numeric; rapor text;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u) THEN RAISE EXCEPTION 'Hâkim makamı gerekli'; END IF;
 IF p_onay IS NULL OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 30 AND 900 THEN RAISE EXCEPTION '30–900 karakter gerekçeli karar gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO d FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF d.id IS NULL OR d.durum<>'talep' OR d.acilis<t-interval '24 hours' THEN RAISE EXCEPTION 'Karara açık tedbir bulunamadı'; END IF;
 SELECT * INTO o FROM oyun.icisleri_olay_v2 WHERE id=d.olay_id;
 IF u IN (d.bakan,d.hedef,o.basvuran) OR oyun.bm_yetki(u,'icisleri') IS NOT NULL THEN RAISE EXCEPTION 'Bağımsız hâkim dosyanın tarafı veya Bakanlık görevlisi olamaz'; END IF;
 IF p_onay AND d.tur IN ('gozalti','faaliyet','ihale','ceza','arama') AND o.savunma IS NULL AND d.acilis>t-interval '2 hours' THEN RAISE EXCEPTION 'Savunma için en az 2 saat beklenmeli veya oyuncu savunması alınmalı'; END IF;
 IF p_onay AND d.tur='arama' THEN
  IF o.kurum_tur='sirket' THEN SELECT format('Şirket kaydı: %s; sektör: %s; sermaye: %s; kasa: %s',ad,sektor,sermaye,kasa) INTO rapor FROM oyun.sirketler WHERE id=o.kurum_id;
  ELSIF o.kurum_tur='dernek' THEN SELECT format('Dernek kaydı: %s; faaliyet: %s; kamuya açık kasa: %s',ad,alan,kasa) INTO rapor FROM oyun.dernekler WHERE id=o.kurum_id;
  END IF;
 END IF;
 tut:=d.tutar;
 IF p_onay AND d.tur='ceza' THEN
  SELECT least(d.tutar,greatest(0,para)) INTO tut FROM oyun.cuzdan WHERE user_id=d.hedef FOR UPDATE;
  IF tut IS NULL THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
  UPDATE oyun.cuzdan SET para=para-tut WHERE user_id=d.hedef;
  IF tut>0 THEN INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(d.hedef,t,-tut,'ceza','Mahkeme onaylı İçişleri cezası #'||d.id); END IF;
 ELSIF p_onay AND d.tur='tazminat' THEN
  PERFORM oyun.bm_kasa_harca('icisleri',tut/oyun.pazar_tl_milyar(),'gider','Mahkeme kararlı oyuncu tazminatı #'||d.id);
  UPDATE oyun.cuzdan SET para=para+tut WHERE user_id=d.hedef;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
  INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(d.hedef,t,tut,'tazminat','Mahkeme onaylı İçişleri tazminatı #'||d.id);
 END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET durum=CASE WHEN p_onay THEN 'onay' ELSE 'red' END,hakim=u,karar_at=t,karar_gerekce=trim(p_gerekce),
  bitis=CASE WHEN p_onay THEN
    t+CASE d.tur WHEN 'gozalti' THEN interval '1 hour' WHEN 'arama' THEN interval '3 hours'
      WHEN 'ifade' THEN interval '12 hours' WHEN 'faaliyet' THEN interval '2 hours' WHEN 'ihale' THEN interval '6 hours' ELSE interval '24 hours' END
    END,tutar=CASE WHEN p_onay AND d.tur='ceza' THEN tut ELSE d.tutar END,
  inceleme_ozet=rapor WHERE id=d.id;
 PERFORM oyun.bildir(d.hedef,'İçişleri tedbiri #'||d.id||' hâkim kararı: '||CASE WHEN p_onay THEN 'onaylandı' ELSE 'reddedildi' END||'. İtiraz hakkınız vardır.');
 PERFORM oyun.bildir(o.basvuran,'Dosyanız #'||o.id||' için hâkim '||CASE WHEN p_onay THEN 'tedbiri onayladı' ELSE 'tedbiri reddetti' END||'.');
 PERFORM oyun.gazete_ekle('icisleri','İçişleri yargı tedbiri #'||d.id,d.tur||' tedbiri: '||CASE WHEN p_onay THEN 'onaylandı' ELSE 'reddedildi' END||'. Mahkeme gerekçesi: '||left(trim(p_gerekce),400),d.id,t);
 RETURN jsonb_build_object('tamam',true,'onay',p_onay,'tutar',tut);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_ifade_ver(p_id bigint,p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); d oyun.icisleri_tedbir_v2;
BEGIN
 IF u IS NULL OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 30 AND 1000 THEN RAISE EXCEPTION 'En az 30 karakter ifade gerekli'; END IF;
 SELECT * INTO d FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF d.id IS NULL OR d.hedef<>u OR d.tur<>'ifade' OR d.durum<>'onay' OR d.bitis<=oyun.simdi() OR d.ifade IS NOT NULL THEN RAISE EXCEPTION 'Açık ifade verme hakkınız yok'; END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET ifade=trim(p_metin),ifade_at=oyun.simdi() WHERE id=p_id;
 PERFORM oyun.bildir(d.bakan,'İfade talebi #'||d.id||' için oyuncu ifadesini sundu.');
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_avukat_cagir(p_id bigint,p_avukat uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); d oyun.icisleri_tedbir_v2;
BEGIN
 IF u IS NULL OR p_avukat IS NULL OR p_avukat=u OR NOT EXISTS(SELECT 1 FROM oyun.avukat_ruhsat WHERE user_id=p_avukat AND durum='aktif') THEN RAISE EXCEPTION 'Geçerli ruhsatlı avukat gerekli'; END IF;
 SELECT * INTO d FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF d.id IS NULL OR d.hedef<>u OR d.durum NOT IN ('talep','onay','itiraz') OR d.avukat_durum='kabul' THEN RAISE EXCEPTION 'Bu dosyada yeni avukat çağrılamaz'; END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET avukat=p_avukat,avukat_durum='cagrildi' WHERE id=p_id;
 PERFORM oyun.bildir(p_avukat,'İçişleri tedbiri #'||p_id||': savunma avukatı olarak çağrıldınız. Hukuk ekranından ve İçişleri Komuta Merkezinden yanıt verin.');
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_avukat_yanit(p_id bigint,p_kabul boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); d oyun.icisleri_tedbir_v2;
BEGIN
 IF u IS NULL OR p_kabul IS NULL THEN RAISE EXCEPTION 'Giriş ve cevap gerekli'; END IF;
 SELECT * INTO d FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF d.id IS NULL OR d.avukat<>u OR d.avukat_durum<>'cagrildi' THEN RAISE EXCEPTION 'Aktif avukatlık daveti yok'; END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET avukat_durum=CASE WHEN p_kabul THEN 'kabul' ELSE 'red' END WHERE id=p_id;
 PERFORM oyun.bildir(d.hedef,'İçişleri avukat çağrısı #'||p_id||': '||CASE WHEN p_kabul THEN 'avukat kabul etti' ELSE 'avukat reddetti' END);
 RETURN jsonb_build_object('tamam',true);
END $$;

-- İtirazda farklı bağımsız hâkim yoksa otomatik iptal; para cezası iade edilir.
CREATE OR REPLACE FUNCTION oyun.icisleri_tedbir_iptal_v2(p_id bigint,p_karar text,p_hakim uuid)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE d oyun.icisleri_tedbir_v2; t timestamptz:=oyun.simdi();
BEGIN
 SELECT * INTO d FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF d.id IS NULL OR d.durum NOT IN ('onay','itiraz') THEN RAISE EXCEPTION 'İptal edilebilir tedbir yok'; END IF;
 IF d.tur='ceza' AND d.tutar>0 THEN
  UPDATE oyun.cuzdan SET para=para+d.tutar WHERE user_id=d.hedef;
  INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(d.hedef,t,d.tutar,'iade','İptal edilen İçişleri mahkeme cezası #'||d.id);
 END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET durum='kaldirildi',bitis=t,itiraz_hakim=p_hakim,itiraz_karar=p_karar,itiraz_karar_at=t WHERE id=p_id;
 PERFORM oyun.bildir(d.hedef,'İçişleri tedbiri #'||p_id||' kaldırıldı. '||left(p_karar,240));
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_itiraz(p_id bigint,p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); d oyun.icisleri_tedbir_v2; o oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 30 AND 800 THEN RAISE EXCEPTION 'En az 30 karakter itiraz gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO d FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF d.id IS NULL OR d.hedef<>u OR d.durum<>'onay' OR d.karar_at<t-interval '24 hours' OR d.tur='tazminat' THEN RAISE EXCEPTION 'İtiraz edilebilir aktif tedbir bulunamadı'; END IF;
 SELECT * INTO o FROM oyun.icisleri_olay_v2 WHERE id=d.olay_id;
 UPDATE oyun.icisleri_tedbir_v2 SET itiraz_metin=trim(p_metin),itiraz_at=t WHERE id=d.id;
 IF NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim IS NOT NULL AND hakim NOT IN (d.hakim,d.bakan,d.hedef,o.basvuran)) THEN
   PERFORM oyun.icisleri_tedbir_iptal_v2(d.id,'İlk karardan bağımsız ikinci hâkim bulunmadığı için itiraz oyuncu lehine sonuçlandırıldı.',NULL);
   RETURN jsonb_build_object('tamam',true,'otomatik_iptal',true);
 END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET durum='itiraz' WHERE id=d.id;
 -- İtiraz sonuçlanana kadar kısıtlayıcı tedbir durur.
 PERFORM oyun.bildir(u,'İçişleri tedbiri #'||p_id||' itirazınız kabul edildi. İkinci bağımsız hâkim inceleyecek; kısıtlama geçici olarak durduruldu.');
 RETURN jsonb_build_object('tamam',true,'otomatik_iptal',false);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_itiraz_karar(p_id bigint,p_kaldir boolean,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); d oyun.icisleri_tedbir_v2; o oyun.icisleri_olay_v2;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u) OR p_kaldir IS NULL OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 30 AND 800 THEN RAISE EXCEPTION 'İkinci hâkim ve 30–800 karakter gerekçe gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO d FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF d.id IS NULL OR d.durum<>'itiraz' THEN RAISE EXCEPTION 'İtirazda olan tedbir yok'; END IF;
 SELECT * INTO o FROM oyun.icisleri_olay_v2 WHERE id=d.olay_id;
 IF u IN (d.hakim,d.bakan,d.hedef,o.basvuran) THEN RAISE EXCEPTION 'İtiraza farklı bağımsız hâkim bakmalı'; END IF;
 IF p_kaldir THEN
  PERFORM oyun.icisleri_tedbir_iptal_v2(p_id,trim(p_gerekce),u);
 ELSE
  UPDATE oyun.icisleri_tedbir_v2 SET durum='onay',itiraz_hakim=u,itiraz_karar=trim(p_gerekce),itiraz_karar_at=oyun.simdi() WHERE id=p_id;
  PERFORM oyun.bildir(d.hedef,'Tedbir #'||p_id||' itirazınız reddedildi; mevcut süreyi aşmadan karar devam ediyor.');
 END IF;
 RETURN jsonb_build_object('tamam',true);
END $$;

-- Mevcut taşınma kontrolünün başına yeni mahkeme kararlı gözaltı denetimini yerleştir.
DO $patch$ DECLARE s text;
BEGIN
 s:=pg_get_functiondef('public.il_degistir(integer)'::regprocedure);
 IF position('oyun.icisleri_gozaltinda_v2' IN s)=0 THEN
  IF position(' engel:=oyun.il_tasinma_engeli' IN s)=0 THEN RAISE EXCEPTION 'İl değiştirme entegrasyon satırı bulunamadı'; END IF;
  s:=replace(s,' engel:=oyun.il_tasinma_engeli',
    ' IF oyun.icisleri_gozaltinda_v2(p.id) THEN RAISE EXCEPTION ''Mahkeme kararlı geçici gözaltı sürerken il değiştiremezsiniz. Diğer oyun haklarınız açıktır.''; END IF;'||chr(10)||' engel:=oyun.il_tasinma_engeli');
  EXECUTE s;
 END IF;
 s:=pg_get_functiondef('public.ihale_teklif(bigint,bigint,numeric)'::regprocedure);
 IF position('oyun.icisleri_ihale_yasagi_v2' IN s)=0 THEN
  IF position(' if not oyun.sirket_yonetici_mi' IN s)=0 THEN RAISE EXCEPTION 'İhale teklif entegrasyon satırı bulunamadı'; END IF;
  s:=replace(s,' if not oyun.sirket_yonetici_mi',
    ' if oyun.icisleri_ihale_yasagi_v2(s.id) then raise exception ''Şirketinize ilişkin bağımsız hâkim onaylı geçici ihale/faaliyet tedbiri var; İçişleri Komuta Merkezinden itiraz edin.''; end if;'||chr(10)||' if not oyun.sirket_yonetici_mi');
  EXECUTE s;
 END IF;
END $patch$;

DO $exec$ DECLARE p regprocedure; BEGIN
 FOREACH p IN ARRAY ARRAY[
 'public.icisleri_tedbir_iste(bigint,text,text,numeric)'::regprocedure,
 'public.icisleri_tedbir_karar(bigint,boolean,text)'::regprocedure,
 'public.icisleri_ifade_ver(bigint,text)'::regprocedure,
 'public.icisleri_avukat_cagir(bigint,uuid)'::regprocedure,
 'public.icisleri_avukat_yanit(bigint,boolean)'::regprocedure,
 'public.icisleri_tedbir_itiraz(bigint,text)'::regprocedure,
 'public.icisleri_tedbir_itiraz_karar(bigint,boolean,text)'::regprocedure
 ] LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',p);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',p);
 END LOOP;
END $exec$;
REVOKE ALL ON FUNCTION oyun.icisleri_ihale_yasagi_v2(bigint),oyun.icisleri_gozaltinda_v2(uuid),oyun.icisleri_tedbir_iptal_v2(bigint,text,uuid) FROM PUBLIC,anon,authenticated;
