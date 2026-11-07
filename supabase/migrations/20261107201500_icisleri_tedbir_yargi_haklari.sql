-- İçişleri v2 · mahkeme yetkisi, savunma, geçici işlem, itiraz ve tazminat.
CREATE OR REPLACE FUNCTION public.icisleri_tedbir_talep(p_olay bigint,p_tur text,p_gerekce text,p_tutar numeric DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_olay_v2; n bigint; t timestamptz:=oyun.simdi(); tut numeric;
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'İçişleri yetkisi gerekli'; END IF;
 IF p_tur NOT IN ('ifade','arama','gozalti','faaliyet','ihale','ceza','tazminat') OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 40 AND 1000 THEN RAISE EXCEPTION 'Geçerli tedbir ve 40–1000 karakter gerekçe gerekir'; END IF;
 tut:=coalesce(p_tutar,0);
 IF tut<0 OR (p_tur='ceza' AND tut>1000) OR (p_tur='tazminat' AND tut>10000) OR (p_tur NOT IN ('ceza','tazminat') AND tut<>0) THEN RAISE EXCEPTION 'Tedbir bedeli sınır dışında'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=p_olay FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'adliye' THEN RAISE EXCEPTION 'Önce gerekçeli inceleme ve adliyeye sevk gerekir'; END IF;
 IF x.hedef=u OR x.basvuran=u THEN RAISE EXCEPTION 'Bakan kendi taraf olduğu dosyada tedbir isteyemez'; END IF;
 IF p_tur IN ('ifade','gozalti','ceza','tazminat') AND x.hedef IS NULL THEN RAISE EXCEPTION 'Tedbirin hedef oyuncusu belirli olmalı'; END IF;
 IF p_tur IN ('faaliyet','ihale') AND x.kurum_tur<>'sirket' THEN RAISE EXCEPTION 'Bu tedbir yalnız şirket dosyasında kullanılabilir'; END IF;
 IF p_tur='arama' AND x.kurum_tur NOT IN ('sirket','dernek') THEN RAISE EXCEPTION 'Arama/denetim yalnız şirket veya dernek işlemlerinde uygulanır'; END IF;
 IF p_tur='tazminat' AND x.basvuran IS DISTINCT FROM x.hedef THEN RAISE EXCEPTION 'Tazminat istemi yalnız hedefin kendisinin bildirdiği ihlal dosyasında açılabilir'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_tedbir_v2 WHERE olay_id=p_olay AND tur=p_tur AND durum IN ('talep','onay','itiraz')) THEN RAISE EXCEPTION 'Aynı türde açık tedbir mevcut'; END IF;
 IF (SELECT count(*) FROM oyun.icisleri_tedbir_v2 WHERE bakan=u AND acilis>oyun.simdi()-interval '24 hours')>=8 THEN RAISE EXCEPTION '24 saatte en fazla 8 tedbir isteği'; END IF;
 PERFORM oyun.bm_kasa_harca('icisleri',20000/oyun.pazar_tl_milyar(),'gider','Yargı denetimli tedbir başvurusu #'||p_olay);
 INSERT INTO oyun.icisleri_tedbir_v2(olay_id,tur,bakan,hedef,gerekce,tutar,acilis)
 VALUES(p_olay,p_tur,u,x.hedef,trim(p_gerekce),tut,t) RETURNING id INTO n;
 IF x.hedef IS NOT NULL THEN PERFORM oyun.bildir(x.hedef,'İçişleri dosyası #'||p_olay||' için '||p_tur||' tedbiri hâkime sunuldu. Henüz onay veya ceza yok.'); END IF;
 INSERT INTO oyun.icisleri_gorev_kayit_v2(yapan,tur,konu_id,aciklama,zaman) VALUES(u,'tedbir_talep',n,p_tur||' · '||trim(p_gerekce),t);
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_karar(p_id bigint,p_onay boolean,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); k oyun.icisleri_tedbir_v2; x oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi(); c numeric; active_count int;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u) THEN RAISE EXCEPTION 'Bağımsız hâkim yetkisi gerekli'; END IF;
 IF p_onay IS NULL OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 30 AND 900 THEN RAISE EXCEPTION '30–900 karakter gerekçeli karar gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO k FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF k.id IS NULL OR k.durum<>'talep' OR k.acilis<t-interval '36 hours' THEN RAISE EXCEPTION 'Aktif tedbir talebi yok veya 36 saatlik süre doldu'; END IF;
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=k.olay_id FOR UPDATE;
 IF x.durum<>'adliye' THEN RAISE EXCEPTION 'Dosya mahkemeye sevk edilmemiş'; END IF;
 IF u IN (k.bakan,x.basvuran,x.hedef) OR oyun.bm_yetki(u,'icisleri') IS NOT NULL THEN RAISE EXCEPTION 'Davacı, hedef veya bakan aynı dosyada hâkim olamaz'; END IF;
 IF p_onay AND x.hedef IS NOT NULL AND x.savunma IS NULL AND k.acilis>t-interval '6 hours' THEN RAISE EXCEPTION 'Oyuncunun savunma hakkı için en az 6 saat geçmeli'; END IF;
 IF p_onay AND k.tur='ceza' AND k.tutar>0 THEN
   SELECT LEAST(k.tutar,GREATEST(0,para)) INTO c FROM oyun.cuzdan WHERE user_id=k.hedef FOR UPDATE;
   IF c IS NULL THEN RAISE EXCEPTION 'Oyuncu cüzdanı bulunamadı'; END IF;
   UPDATE oyun.cuzdan SET para=para-c WHERE user_id=k.hedef;
   IF c>0 THEN INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(k.hedef,t,-c,'ceza','Mahkeme onaylı İçişleri tedbiri #'||k.id); END IF;
   UPDATE oyun.icisleri_tedbir_v2 SET tutar=c WHERE id=k.id;
 ELSIF p_onay AND k.tur='tazminat' AND k.tutar>0 THEN
   PERFORM oyun.bm_kasa_harca('icisleri',k.tutar/oyun.pazar_tl_milyar(),'gider','Mahkeme onaylı tazminat #'||k.id);
   UPDATE oyun.cuzdan SET para=para+k.tutar WHERE user_id=k.hedef;
   IF NOT FOUND THEN RAISE EXCEPTION 'Tazminat alıcısının cüzdanı yok'; END IF;
   INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(k.hedef,t,k.tutar,'tazminat','İçişleri hak ihlali tazminatı #'||k.id);
 END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET durum=CASE WHEN p_onay THEN 'onay' ELSE 'red' END,hakim=u,karar_at=t,karar_gerekce=trim(p_gerekce),
 bitis=CASE WHEN p_onay THEN t+CASE k.tur WHEN 'gozalti' THEN interval '30 minutes' WHEN 'faaliyet' THEN interval '2 hours' WHEN 'ihale' THEN interval '12 hours' WHEN 'ifade' THEN interval '12 hours' WHEN 'arama' THEN interval '2 hours' ELSE interval '24 hours' END END
 WHERE id=p_id;
 IF k.hedef IS NOT NULL THEN PERFORM oyun.bildir(k.hedef,'Mahkeme İçişleri tedbiri #'||p_id||': '||CASE WHEN p_onay THEN 'onaylandı' ELSE 'reddedildi' END||'. 24 saat itiraz hakkı vardır.'); END IF;
 PERFORM oyun.gazete_ekle('icisleri','Bağımsız mahkeme kararı #'||p_id,'Gerekçe: '||trim(p_gerekce)||' · Tür: '||k.tur||' · Karar: '||CASE WHEN p_onay THEN 'onay' ELSE 'ret' END,p_id,t);
 RETURN jsonb_build_object('tamam',true,'onay',p_onay);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_ifade(p_id bigint,p_metin text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); k oyun.icisleri_tedbir_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 30 AND 1200 THEN RAISE EXCEPTION '30–1200 karakter ifade gerekli'; END IF;
 SELECT * INTO k FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF k.id IS NULL OR k.hedef IS DISTINCT FROM u OR k.tur<>'ifade' OR k.durum<>'onay' OR k.bitis<=t THEN RAISE EXCEPTION 'Aktif ifadeye çağrı yok'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_gorev_kayit_v2 WHERE tur='ifade_alindi' AND konu_id=p_id) THEN RAISE EXCEPTION 'İfadeniz zaten kaydedildi'; END IF;
 INSERT INTO oyun.icisleri_gorev_kayit_v2(yapan,tur,konu_id,aciklama,zaman) VALUES(u,'ifade_alindi',p_id,trim(p_metin),t);
 PERFORM oyun.bildir(k.bakan,'İçişleri tedbiri #'||p_id||' için oyuncu ifadesi sunuldu');
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_itiraz(p_id bigint,p_metin text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); k oyun.icisleri_tedbir_v2; x oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 30 AND 900 THEN RAISE EXCEPTION '30–900 karakter itiraz gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO k FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF k.id IS NULL OR k.durum<>'onay' OR k.karar_at<t-interval '24 hours' THEN RAISE EXCEPTION '24 saatlik itiraz hakkı yok veya kullanıldı'; END IF;
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=k.olay_id;
 IF u NOT IN (x.hedef,x.basvuran) THEN RAISE EXCEPTION 'Yalnız dosya tarafları itiraz edebilir'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim IS NOT NULL AND hakim<>k.hakim AND hakim IS DISTINCT FROM k.bakan AND hakim IS DISTINCT FROM x.basvuran AND hakim IS DISTINCT FROM x.hedef) THEN
   -- İkinci bağımsız hâkim bulunmazsa cezayı ve kamu ödemesini geri al; kullanıcı lehine derhal iptal.
   IF k.tur='ceza' AND k.tutar>0 THEN
      UPDATE oyun.cuzdan SET para=para+k.tutar WHERE user_id=k.hedef;
      INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(k.hedef,t,k.tutar,'iade','İçişleri ceza itiraz iadesi #'||k.id);
   END IF;
   IF k.tur='tazminat' AND k.tutar>0 THEN
      -- Hak ihlaline bağlı verilmiş tazminat ikinci hâkim eksikliğinde geri alınmaz.
      NULL;
   END IF;
   UPDATE oyun.icisleri_tedbir_v2 SET durum='kaldirildi',bitis=t,itiraz_metin=trim(p_metin),itiraz_at=t,itiraz_karar='İkinci bağımsız hâkim bulunmadığından tedbir kaldırıldı',itiraz_karar_at=t WHERE id=k.id;
   PERFORM oyun.bildir(k.bakan,'Tedbir #'||k.id||' bağımsız ikinci hâkim yokluğu nedeniyle kaldırıldı.');
   RETURN jsonb_build_object('tamam',true,'otomatik_kaldirildi',true);
 END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET durum='itiraz',bitis=CASE WHEN tur IN ('gozalti','faaliyet','ihale') THEN t ELSE bitis END,
 itiraz_metin=trim(p_metin),itiraz_at=t WHERE id=k.id;
 PERFORM oyun.bildir(u,'İtiraz alındı. Fizikî/ekonomik kısıtlama varsa durduruldu.');
 RETURN jsonb_build_object('tamam',true,'otomatik_kaldirildi',false);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_itiraz_karar(p_id bigint,p_kaldir boolean,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); k oyun.icisleri_tedbir_v2; x oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u) THEN RAISE EXCEPTION 'Bağımsız hâkim gerekli'; END IF;
 IF p_kaldir IS NULL OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 30 AND 900 THEN RAISE EXCEPTION '30–900 karakter mahkeme gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO k FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF k.id IS NULL OR k.durum<>'itiraz' THEN RAISE EXCEPTION 'İtiraz incelemesi bulunamadı'; END IF;
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=k.olay_id;
 IF u IN (k.hakim,k.bakan,x.basvuran,x.hedef) THEN RAISE EXCEPTION 'Tarafsız ikinci hâkim gerekli'; END IF;
 IF p_kaldir AND k.tur='ceza' AND k.tutar>0 THEN
   UPDATE oyun.cuzdan SET para=para+k.tutar WHERE user_id=k.hedef;
   INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(k.hedef,t,k.tutar,'iade','İçişleri ceza iptali #'||k.id);
 END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET durum=CASE WHEN p_kaldir THEN 'kaldirildi' ELSE 'onay' END,
  bitis=CASE WHEN p_kaldir OR k.tur IN ('gozalti','faaliyet','ihale') THEN t ELSE k.bitis END,
  itiraz_hakim=u,itiraz_karar=trim(p_gerekce),itiraz_karar_at=t WHERE id=k.id;
 IF k.hedef IS NOT NULL THEN PERFORM oyun.bildir(k.hedef,'İçişleri tedbiri #'||p_id||' itiraz sonucu: '||CASE WHEN p_kaldir THEN 'kaldırıldı' ELSE 'onandı' END); END IF;
 RETURN jsonb_build_object('tamam',true);
END $$;

-- Etkin tedbir durumunu diğer oyun fonksiyonları güvenli biçimde sorgulayabilir.
CREATE OR REPLACE FUNCTION oyun.icisleri_tedbir_aktif(p_user uuid,p_tur text) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM oyun.icisleri_tedbir_v2 WHERE hedef=p_user AND tur=p_tur AND durum='onay' AND bitis>oyun.simdi())
$$;
REVOKE ALL ON FUNCTION oyun.icisleri_tedbir_aktif(uuid,text) FROM PUBLIC,anon,authenticated;
DO $grant$ DECLARE p regprocedure;BEGIN
 FOREACH p IN ARRAY ARRAY[
 'public.icisleri_tedbir_talep(bigint,text,text,numeric)'::regprocedure,
 'public.icisleri_tedbir_karar(bigint,boolean,text)'::regprocedure,
 'public.icisleri_tedbir_ifade(bigint,text)'::regprocedure,
 'public.icisleri_tedbir_itiraz(bigint,text)'::regprocedure,
 'public.icisleri_tedbir_itiraz_karar(bigint,boolean,text)'::regprocedure
 ] LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',p);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',p);
 END LOOP;
END $grant$;
