
CREATE OR REPLACE FUNCTION oyun.bakanlik_icerik_olustur(p_kod text,p_alan text)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE s oyun.bakanlik_sablonlar; i jsonb; e jsonb; n int:=0; a int:=0;
BEGIN
 SELECT * INTO s FROM oyun.bakanlik_sablonlar WHERE alan=p_alan;
 IF s.alan IS NULL THEN RAISE EXCEPTION 'Bakanlık faaliyet alanı tanımlı değil.'; END IF;
 FOR i IN SELECT value FROM jsonb_array_elements(s.icraatlar) LOOP
  n:=n+1;
  INSERT INTO oyun.icraatlar(kod,bakanlik,ad,aciklama,maliyet,bekleme_saat,il_gerekli,etki,oyuncu,sure_gun)
  VALUES('kur_'||p_kod||'_i'||n,p_kod,i->>'ad',i->>'aciklama',(i->>'maliyet')::numeric,
    24,coalesce((i->>'il_gerekli')::boolean,false),i->'etki',
    coalesce(i->'oyuncu','[]'::jsonb),case when jsonb_array_length(coalesce(i->'oyuncu','[]'::jsonb))>0 then 7 end);
 END LOOP;
 FOR e IN SELECT value FROM jsonb_array_elements(s.etkinlikler) LOOP
  a:=a+1;
  INSERT INTO oyun.bakanlik_etkinlik_tur(kod,bakanlik,ad,aciklama,maliyet,sure_saat,il_gerekli,etki,kidem,bekleme_saat,sira)
  VALUES('kur_'||p_kod||'_e'||a,p_kod,e->>'ad',e->>'aciklama',(e->>'maliyet')::numeric,
   (e->>'sure_saat')::int,coalesce((e->>'il_gerekli')::boolean,false),e->'etki',0.5,
   (e->>'bekleme_saat')::int,a);
 END LOOP;
 RETURN jsonb_build_object('icraat',n,'etkinlik',a);
END $f$;

CREATE OR REPLACE FUNCTION oyun.bakanlik_butce_pay_duzenle(p_kod text,p_yeni_pay numeric)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE v_eski jsonb; v_yeni jsonb:='{}'::jsonb; v_toplam numeric:=0;
 v_hedef numeric:=round(coalesce(p_yeni_pay,0),4); v_tutar numeric:=0;
 v_ilk text; v_n int:=0; x record; v_pay numeric;
BEGIN
 IF v_hedef<0 OR v_hedef>5 THEN RAISE EXCEPTION 'Yeni bütçe payı 0-5 arası olmalıdır.'; END IF;
 SELECT butce INTO v_eski FROM oyun.ulke WHERE id=1 FOR UPDATE;
 IF v_eski IS NULL THEN RAISE EXCEPTION 'Merkezi bütçe bulunamadı.'; END IF;
 IF v_hedef>0 AND NOT EXISTS(SELECT 1 FROM oyun.bakanliklar WHERE kod=p_kod AND aktif)
 THEN RAISE EXCEPTION 'Bütçe payı alacak bakanlık açık olmalıdır.'; END IF;
 SELECT count(*),coalesce(sum(coalesce((v_eski->>b.kod)::numeric,0)),0)
 INTO v_n,v_toplam FROM oyun.bakanliklar b WHERE b.aktif AND b.kod<>p_kod;
 IF v_n=0 THEN
  IF v_hedef=0 THEN RAISE EXCEPTION 'Son bakanlığın bütçesi kaldırılamaz.'; END IF;
  v_yeni:=jsonb_build_object(p_kod,100);
 ELSE
  FOR x IN SELECT kod FROM oyun.bakanliklar WHERE aktif AND kod<>p_kod ORDER BY sira,kod LOOP
   IF v_ilk IS NULL THEN v_ilk:=x.kod;
   ELSE
    v_pay:=case when v_toplam>0 then round(coalesce((v_eski->>x.kod)::numeric,0)*(100-v_hedef)/v_toplam,4)
               else round((100-v_hedef)/v_n,4) end;
    v_yeni:=v_yeni||jsonb_build_object(x.kod,v_pay);
    v_tutar:=v_tutar+v_pay;
   END IF;
  END LOOP;
  v_yeni:=v_yeni||jsonb_build_object(v_ilk,round(100-v_hedef-v_tutar,4));
  IF v_hedef>0 THEN v_yeni:=v_yeni||jsonb_build_object(p_kod,v_hedef); END IF;
 END IF;
 UPDATE oyun.ulke SET butce=v_yeni WHERE id=1;
 RETURN v_yeni;
END $f$;

CREATE OR REPLACE FUNCTION public.bakanlik_kur_alan(p_ad text,p_alan text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE p oyun.profiller:=oyun.profilim();
 v_ad text; v_kod text; v_sira integer; v_t timestamptz:=oyun.simdi();
 v_alan text:=lower(btrim(coalesce(p_alan,'genel'))); v_sablon oyun.bakanlik_sablonlar;
 v_faaliyet jsonb; v_butce jsonb; v_baslangic numeric:=5;
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN
  RAISE EXCEPTION 'Bu yetki yalnız görevdeki Cumhurbaşkanına aittir.'; END IF;
 PERFORM pg_advisory_xact_lock(40881117);
 v_ad:=btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
 IF length(v_ad)<5 OR length(v_ad)>80 THEN RAISE EXCEPTION 'Bakanlık adı 5-80 karakter olmalıdır.'; END IF;
 IF v_ad !~* 'Bakanlığı$' THEN v_ad:=v_ad||' Bakanlığı'; END IF;
 IF length(v_ad)>90 THEN RAISE EXCEPTION 'Bakanlık adı fazla uzun.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.bakanliklar WHERE lower(ad)=lower(v_ad))
 THEN RAISE EXCEPTION 'Bu isimde bir bakanlık zaten var. Kapalıysa yeniden açabilirsin.'; END IF;
 IF (SELECT count(*) FROM oyun.bakanliklar)>=30 THEN
  RAISE EXCEPTION 'En fazla 30 farklı bakanlık kurulabilir; kapalı bakanlıklar yeniden açılabilir.'; END IF;
 IF v_alan='' THEN v_alan:='genel'; END IF;
 IF v_alan='genel' THEN
  v_alan:=CASE
   WHEN lower(v_ad) ~ 'enerji|maden|petrol|elektrik' THEN 'enerji'
   WHEN lower(v_ad) ~ 'çevre|iklim|şehircilik' THEN 'cevre'
   WHEN lower(v_ad) ~ 'kültür|turizm|sanat' THEN 'kultur'
   WHEN lower(v_ad) ~ 'siber|dijital|bilişim' THEN 'dijital'
   WHEN lower(v_ad) ~ 'aile|sosyal hizmet|engelli' THEN 'aile'
   WHEN lower(v_ad) ~ 'gençlik|spor' THEN 'genclik'
   WHEN lower(v_ad) ~ 'afet|acil durum|arama kurtarma' THEN 'afet'
   WHEN lower(v_ad) ~ 'bilim|uzay|araştırma' THEN 'bilim'
   WHEN lower(v_ad) ~ 'basın|medya|iletişim' THEN 'basin'
   WHEN lower(v_ad) ~ 'din işleri|inanç' THEN 'din'
   ELSE 'genel' END;
 END IF;
 SELECT * INTO v_sablon FROM oyun.bakanlik_sablonlar WHERE alan=v_alan;
 IF v_sablon.alan IS NULL THEN RAISE EXCEPTION 'Seçilen bakanlık faaliyet alanı bulunamadı.'; END IF;

 v_kod:='ek_'||substr(replace(gen_random_uuid()::text,'-',''),1,14);
 SELECT coalesce(max(sira),0)+1 INTO v_sira FROM oyun.bakanliklar;
 INSERT INTO oyun.bakanliklar(kod,ad,sira,aktif,sistem,kurulus_at,alan)
 VALUES(v_kod,v_ad,v_sira,true,false,v_t,v_alan);
 INSERT INTO oyun.bakanlik_kasa(kod,kasa) VALUES(v_kod,0);
 v_faaliyet:=oyun.bakanlik_icerik_olustur(v_kod,v_alan);
 v_butce:=oyun.bakanlik_butce_pay_duzenle(v_kod,2);

 PERFORM set_config('oyun.hazine_islem','Yeni bakanlık için kuruluş ödeneği',true);
 UPDATE oyun.ulke SET hazine=hazine-v_baslangic WHERE id=1 AND hazine>=v_baslangic;
 IF NOT FOUND THEN RAISE EXCEPTION 'Hazine kuruluş ödeneği için yeterli değil (5 milyar ₺).'; END IF;
 PERFORM set_config('oyun.hazine_islem','',true);
 PERFORM oyun.bm_neden('kurulus','Hazine kaynaklı ilk kuruluş ödeneği');
 UPDATE oyun.bakanlik_kasa SET kasa=kasa+v_baslangic WHERE kod=v_kod;
 PERFORM oyun.bm_neden(null,null);
 PERFORM oyun.olay('duyuru',format('Cumhurbaşkanı %s, %s kurumunu kurdu. 5 milyar ₺ açılış ödeneği ve %%2 bütçe payı tanımlandı.',p.kad,v_ad),null,p.parti_id,v_t);
 RETURN jsonb_build_object('tamam',true,'islem','kuruldu','kod',v_kod,'ad',v_ad,'alan',v_alan,
  'kurulus_odenegi',v_baslangic,'butce_payi',v_butce->v_kod,'faaliyetler',v_faaliyet);
END $f$;

CREATE OR REPLACE FUNCTION public.bakanlik_kur(p_ad text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
 SELECT public.bakanlik_kur_alan(p_ad,'genel')
$f$;

REVOKE ALL ON FUNCTION oyun.bakanlik_icerik_olustur(text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION oyun.bakanlik_butce_pay_duzenle(text,numeric) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.bakanlik_kur_alan(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bakanlik_kur_alan(text,text) TO authenticated;
