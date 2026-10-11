BEGIN;
CREATE OR REPLACE FUNCTION oyun.belediye_bina_tick() RETURNS integer
LANGUAGE plpgsql SET search_path='oyun','public','pg_temp' AS $$
DECLARE r record; bugun date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
        gun int; gider numeric; gelir numeric; v_kasa numeric; n integer := 0;
BEGIN
 IF NOT pg_try_advisory_xact_lock(772921,1) THEN RETURN 0; END IF;
 FOR r IN SELECT b.id,b.il_id,b.kod,b.hedef_seviye,k.gelisim,k.memnuniyet,k.ad
  FROM oyun.belediye_bina b JOIN oyun.belediye_bina_katalog k USING(kod)
  WHERE b.durum='insa' AND b.bitis<=now() ORDER BY b.id FOR UPDATE OF b LOOP
   UPDATE oyun.belediye_bina SET durum='aktif',seviye=r.hedef_seviye,son_bakim=bugun WHERE id=r.id;
   UPDATE oyun.il_durum SET gelisim=oyun.sinir(gelisim+r.gelisim,0,100),
      memnuniyet=oyun.sinir(memnuniyet+r.memnuniyet,0,100) WHERE il_id=r.il_id;
   INSERT INTO oyun.belediye_sehir_hareket(il_id,bina_id,tur,aciklama)
    VALUES(r.il_id,r.id,'tamamlandi',r.ad || ' · ' || r.hedef_seviye || '. seviye tamamlandi');
   n:=n+1;
 END LOOP;
 FOR r IN SELECT b.id,b.il_id,b.seviye,b.son_bakim,k.ad,k.gunluk_bakim,k.gunluk_gelir
  FROM oyun.belediye_bina b JOIN oyun.belediye_bina_katalog k USING(kod)
  WHERE b.durum='aktif' AND b.son_bakim<bugun ORDER BY b.id FOR UPDATE OF b LOOP
   gun:=LEAST(30,bugun-r.son_bakim); gider:=round(r.gunluk_bakim*r.seviye*gun,6);
   gelir:=round(r.gunluk_gelir*r.seviye*gun,6);
   SELECT d.kasa INTO v_kasa FROM oyun.il_durum d WHERE d.il_id=r.il_id FOR UPDATE;
   IF v_kasa < gider THEN
     UPDATE oyun.belediye_bina SET durum='askida',son_bakim=bugun WHERE id=r.id;
     UPDATE oyun.il_durum SET memnuniyet=oyun.sinir(memnuniyet-0.15,0,100) WHERE il_id=r.il_id;
     INSERT INTO oyun.belediye_sehir_hareket(il_id,bina_id,tur,aciklama)
       VALUES(r.il_id,r.id,'askida',r.ad || ' bakim butcesi olmadigindan durduruldu');
   ELSE
     UPDATE oyun.il_durum SET kasa=kasa-gider+gelir WHERE il_id=r.il_id;
     UPDATE oyun.belediye_bina SET son_bakim=bugun WHERE id=r.id;
     INSERT INTO oyun.belediye_sehir_hareket(il_id,bina_id,tur,tutar,aciklama)
       VALUES(r.il_id,r.id,'isletme',gelir-gider,r.ad || ' · ' || gun || ' gunluk isletme neti');
   END IF;
   n:=n+1;
 END LOOP;
 RETURN n;
END $$;

CREATE OR REPLACE FUNCTION public.belediye_bina_islem(p_kod text,p_islem text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='oyun','public','pg_temp' AS $$
DECLARE p oyun.profiller := oyun.profilim(); m oyun.makamlar := oyun.baskan_zorunlu(p);
 k oyun.belediye_bina_katalog; b oyun.belediye_bina; v_kasa numeric; bedel numeric; hedef int; sure int; yeni_id bigint;
BEGIN
 IF p_islem NOT IN ('insa','yukselt','yeniden_ac') THEN RAISE EXCEPTION 'Gecersiz bina islemi'; END IF;
 SELECT * INTO k FROM oyun.belediye_bina_katalog WHERE kod=p_kod;
 IF k.kod IS NULL THEN RAISE EXCEPTION 'Bina katalogda yok'; END IF;
 PERFORM pg_advisory_xact_lock(772922,m.il_id::integer);
 SELECT kasa INTO v_kasa FROM oyun.il_durum WHERE il_id=m.il_id FOR UPDATE;
 SELECT * INTO b FROM oyun.belediye_bina WHERE il_id=m.il_id AND kod=p_kod FOR UPDATE;
 IF p_islem='insa' THEN
   IF b.id IS NOT NULL THEN RAISE EXCEPTION 'Bu bina sehirde zaten var. Yukseltme secenegini kullan'; END IF;
   hedef:=1; bedel:=k.maliyet; sure:=k.insaat_saat;
 ELSIF p_islem='yukselt' THEN
   IF b.id IS NULL OR b.durum<>'aktif' OR b.seviye>=3 THEN RAISE EXCEPTION 'Yalnizca aktif ve 3. seviyenin altindaki binalar yukseltilebilir'; END IF;
   hedef:=b.seviye+1; bedel:=round(k.maliyet*(0.6+0.55*hedef),6); sure:=k.insaat_saat;
 ELSE
   IF b.id IS NULL OR b.durum<>'askida' THEN RAISE EXCEPTION 'Yalnizca bakim nedeniyle kapanmis bina yeniden acilabilir'; END IF;
   hedef:=b.seviye; bedel:=round(k.gunluk_bakim*3*b.seviye,6); sure:=1;
 END IF;
 IF v_kasa<bedel THEN RAISE EXCEPTION 'Belediye kasasi yetersiz. Gerekli: % milyar TL; kasa: % milyar TL',bedel,v_kasa; END IF;
 UPDATE oyun.il_durum SET kasa=kasa-bedel WHERE il_id=m.il_id;
 IF b.id IS NULL THEN
   INSERT INTO oyun.belediye_bina(il_id,kod,seviye,hedef_seviye,durum,baslangic,bitis,baskan,son_yatirim)
   VALUES(m.il_id,p_kod,0,hedef,'insa',now(),now()+make_interval(hours=>sure),p.id,bedel) RETURNING id INTO yeni_id;
 ELSE
   UPDATE oyun.belediye_bina SET hedef_seviye=hedef,durum='insa',baslangic=now(),
     bitis=now()+make_interval(hours=>sure),baskan=p.id,son_yatirim=bedel WHERE id=b.id;
   yeni_id:=b.id;
 END IF;
 INSERT INTO oyun.belediye_sehir_hareket(il_id,bina_id,tur,tutar,aciklama)
 VALUES(m.il_id,yeni_id,p_islem,-bedel,k.ad || ' · ' || hedef || '. seviye insaat/yatirim');
 PERFORM oyun.olay('belediye',format('%s Belediyesi %s projesini baslatti.',(select ad from oyun.iller where id=m.il_id),k.ad),m.il_id,p.parti_id,now());
 RETURN jsonb_build_object('tamam',true,'bina_id',yeni_id,'bedel',bedel,'bitiş',now()+make_interval(hours=>sure));
END $$;

CREATE OR REPLACE FUNCTION public.belediye_ekonomi_programi(p_kod text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='oyun','public','pg_temp' AS $$
DECLARE p oyun.profiller := oyun.profilim(); m oyun.makamlar := oyun.baskan_zorunlu(p);
 k oyun.belediye_ekonomi_katalog; v_kasa numeric; t timestamptz:=now();
BEGIN
 SELECT * INTO k FROM oyun.belediye_ekonomi_katalog WHERE kod=p_kod;
 IF k.kod IS NULL THEN RAISE EXCEPTION 'Ekonomi programi bulunamadi'; END IF;
 PERFORM pg_advisory_xact_lock(772922,m.il_id::integer);
 IF EXISTS(SELECT 1 FROM oyun.belediye_ekonomi_karar WHERE il_id=m.il_id AND zaman>t-interval '12 hours') THEN
  RAISE EXCEPTION 'Belediye 12 saatte bir ekonomi programi uygulayabilir'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.belediye_ekonomi_karar WHERE il_id=m.il_id AND kod=p_kod AND zaman>t-interval '48 hours') THEN
  RAISE EXCEPTION 'Ayni program 48 saatte bir uygulanabilir'; END IF;
 SELECT kasa INTO v_kasa FROM oyun.il_durum WHERE il_id=m.il_id FOR UPDATE;
 IF v_kasa<k.maliyet THEN RAISE EXCEPTION 'Butce yetersiz: % milyar TL gerekli',k.maliyet; END IF;
 UPDATE oyun.il_durum SET kasa=kasa-k.maliyet,gelisim=oyun.sinir(gelisim+k.gelisim,0,100),
  memnuniyet=oyun.sinir(memnuniyet+k.memnuniyet,0,100) WHERE il_id=m.il_id;
 INSERT INTO oyun.belediye_ekonomi_karar(il_id,kod,baskan,maliyet,zaman) VALUES(m.il_id,p_kod,p.id,k.maliyet,t);
 INSERT INTO oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama) VALUES(m.il_id,'ekonomi',-k.maliyet,k.ad);
 PERFORM oyun.olay('belediye',format('%s Belediyesi %s uyguladi.',(select ad from oyun.iller where id=m.il_id),k.ad),m.il_id,p.parti_id,t);
 RETURN jsonb_build_object('tamam',true,'maliyet',k.maliyet,'gelisim',k.gelisim,'memnuniyet',k.memnuniyet);
END $$;
COMMIT;