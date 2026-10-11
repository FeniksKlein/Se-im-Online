-- 2026-10-11 / Oyuncu bankalari kredi urunleri, izinli finansal belge, taksit takvimi
-- Var olan kredi ve bakiye satirlari degistirilmez; yeni kredilere uygulanir.
BEGIN;
ALTER TABLE oyun.oyb_kredi DROP CONSTRAINT IF EXISTS oyb_kredi_saat_check;
ALTER TABLE oyun.oyb_kredi ADD CONSTRAINT oyb_kredi_saat_check CHECK (saat IN (1,3,6,12,24,72,168,336,504,672));
ALTER TABLE oyun.oyb_kredi ADD COLUMN IF NOT EXISTS taksit_sayisi smallint NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS oyun.oyb_kredi_urun (
 banka_id bigint NOT NULL REFERENCES oyun.sirketler(id) ON DELETE CASCADE,
 saat smallint NOT NULL CHECK (saat IN (24,72,168,336,504,672)),
 taksit_sayisi smallint NOT NULL DEFAULT 1 CHECK (taksit_sayisi BETWEEN 1 AND 4),
 ek_faiz numeric NOT NULL DEFAULT 0 CHECK (ek_faiz BETWEEN 0 AND 3),
 aktif boolean NOT NULL DEFAULT false,
 PRIMARY KEY(banka_id,saat),
 CHECK (saat % taksit_sayisi = 0)
);
CREATE TABLE IF NOT EXISTS oyun.oyb_kredi_taksit (
 kredi_id bigint NOT NULL REFERENCES oyun.oyb_kredi(id) ON DELETE CASCADE,
 sira smallint NOT NULL,
 vade timestamptz NOT NULL,
 tutar numeric NOT NULL CHECK(tutar>0),
 odenen numeric NOT NULL DEFAULT 0 CHECK (odenen>=0),
 PRIMARY KEY(kredi_id,sira)
);
CREATE INDEX IF NOT EXISTS oyb_taksit_vade_idx ON oyun.oyb_kredi_taksit(vade) WHERE odenen<tutar;
CREATE TABLE IF NOT EXISTS oyun.oyb_bilgi_izin (
 kredi_id bigint PRIMARY KEY REFERENCES oyun.oyb_kredi(id) ON DELETE CASCADE,
 banka_id bigint NOT NULL REFERENCES oyun.sirketler(id),
 borclu uuid NOT NULL REFERENCES oyun.profiller(id),
 istenen text[] NOT NULL,
 izinli text[] NOT NULL DEFAULT '{}',
 durum text NOT NULL DEFAULT 'talep' CHECK (durum IN ('talep','izin','ret','iptal')),
 istek_at timestamptz NOT NULL DEFAULT now(),
 cevap_at timestamptz
);
CREATE INDEX IF NOT EXISTS oyb_izin_borclu_idx ON oyun.oyb_bilgi_izin(borclu,durum);
ALTER TABLE oyun.oyb_kredi_urun ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.oyb_kredi_taksit ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.oyb_bilgi_izin ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.oyb_kredi_urun,oyun.oyb_kredi_taksit,oyun.oyb_bilgi_izin FROM PUBLIC,anon,authenticated;

-- Yeni bankalara ilk gun 1, 3, 7 gun urunleri sunulur; sahip ayarlarla degistirir.
INSERT INTO oyun.oyb_kredi_urun(banka_id,saat,taksit_sayisi,aktif)
SELECT id, v.saat,v.taksit,true FROM oyun.sirketler
CROSS JOIN (VALUES (24::smallint,1::smallint),(72::smallint,1::smallint),(168::smallint,2::smallint)) v(saat,taksit)
WHERE sektor='banka' ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION oyun.oyb_urun_bankaya_ekle()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
 IF new.sektor='banka' THEN
  INSERT INTO oyun.oyb_kredi_urun(banka_id,saat,taksit_sayisi,aktif)
  VALUES(new.id,24,1,true),(new.id,72,1,true),(new.id,168,2,true)
  ON CONFLICT DO NOTHING;
 END IF;
 RETURN new;
END $$;
DROP TRIGGER IF EXISTS oyb_urun_yeni_banka ON oyun.sirketler;
CREATE TRIGGER oyb_urun_yeni_banka AFTER INSERT ON oyun.sirketler
FOR EACH ROW EXECUTE FUNCTION oyun.oyb_urun_bankaya_ekle();

CREATE OR REPLACE FUNCTION oyun.kredi_risk_ozeti(p_user uuid, p_saat integer)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = ''
AS $fn$
DECLARE
    t timestamptz := oyun.simdi();
    gelir_json jsonb;
    notu integer := 1100;
    kara_liste timestamptz;
    gecikmis integer := 0;
    maas7 numeric := 0;
    kira7 numeric := 0;
    sirket7 numeric := 0;
    nakit numeric := 0;
    devlet_gunluk_borc numeric := 0;
    vadedeki_ozel_borc numeric := 0;
    haftalik_gelir numeric := 0;
    mevcut_kapasite numeric := 0;
    puan_katsayisi numeric := 0;
    limit_tl numeric := 0;
    aciklama text := 'Gelir ve kredi notu uygun';
BEGIN
    IF p_user IS NULL OR p_saat IS NULL OR p_saat NOT IN (1,3,6,12,24,72,168,336,360,504,672,720) THEN
        RAISE EXCEPTION 'Gecersiz kullanici veya kredi vadesi';
    END IF;
    SELECT coalesce(b.kredi_notu,1100), b.kara_liste
      INTO notu, kara_liste
      FROM oyun.banka_musteri b WHERE b.user_id=p_user;
    notu := coalesce(notu,1100);

    SELECT greatest(0, coalesce(c.para,0)+coalesce(b.vadesiz,0))
      INTO nakit
      FROM oyun.cuzdan c
      LEFT JOIN oyun.banka_musteri b ON b.user_id=c.user_id
     WHERE c.user_id=p_user;
    nakit := coalesce(nakit,0);

    gelir_json := oyun.gelir_hesap(p_user,t);
    maas7 := greatest(0,coalesce((gelir_json->>'gunluk_net')::numeric,0))*7*0.70;
    SELECT coalesce(sum(greatest(0,haftalik_kira)),0)*0.80
      INTO kira7
      FROM oyun.yatirim_mulkleri WHERE user_id=p_user;

    -- Kar: son 28 gunluk GEREKCELI isletme hareketleri; pay oranina gore, haftaya cevrilir.
    SELECT coalesce(sum(greatest(0,net_28_gun)*ortak_pay),0)/4*0.40
      INTO sirket7
      FROM (
        SELECT o.sirket_id,
               o.pay/100 AS ortak_pay,
               coalesce(sum(coalesce(h.faaliyet_gelir,0)-coalesce(h.faaliyet_gider,0)),0) AS net_28_gun
          FROM oyun.sirket_ortaklari o
          JOIN oyun.sirketler s ON s.id=o.sirket_id AND s.aktif AND s.sektor<>'banka'
          LEFT JOIN oyun.sirket_hareket h
            ON h.sirket_id=s.id AND h.zaman>=t-interval '28 days'
         WHERE o.user_id=p_user AND o.pay>0
         GROUP BY o.sirket_id,o.pay
      ) x;

    haftalik_gelir := round(maas7+kira7+sirket7,2);

    SELECT coalesce(sum(k.taksit),0)
      INTO devlet_gunluk_borc
      FROM oyun.krediler k
     WHERE k.user_id=p_user AND k.durum IN ('aktif','takip');

    SELECT coalesce(sum(k.kalan) FILTER (WHERE k.vade<=t+make_interval(hours=>p_saat)),0),
           count(*) FILTER (WHERE k.vade<t)
      INTO vadedeki_ozel_borc,gecikmis
      FROM oyun.oyb_kredi k
     WHERE k.borclu=p_user AND k.durum='aktif';

    puan_katsayisi := CASE
        WHEN notu<700 THEN 0
        WHEN notu<900 THEN .35
        WHEN notu<1100 THEN .50
        WHEN notu<1500 THEN .70
        WHEN notu<1700 THEN .85
        ELSE 1 END;

    -- 1-24 saatlik kredi vadeleri icin gelir vade ile orantilidir;
    -- boylece kisa vadeye gercekci olmayacak buyuk kredi verilmez.
    -- DTI: en fazla haftalik duzenli gelirin %40'i borc servisine ayrilir.
    -- Nakit bir krediyi tek basina hak ettirmez, sadece gelir varsa teminata destek olur.
    mevcut_kapasite := greatest(0,
        haftalik_gelir * p_saat / 168 * 0.40
        + least(nakit * 0.10, haftalik_gelir * p_saat / 168 * 0.10)
        - devlet_gunluk_borc * p_saat / 24 - vadedeki_ozel_borc);
    IF haftalik_gelir < 1000 THEN mevcut_kapasite := 0; END IF;
    -- %20 faiz tamponu ve kredi notu katsayisi; 100 TL adim.
    limit_tl := greatest(0,least(500000,
        floor(mevcut_kapasite * puan_katsayisi / 1.20 / 100)*100));

    IF notu<700 THEN
        aciklama:='Kredi notu 700 altinda';limit_tl:=0;
    ELSIF kara_liste>t THEN
        aciklama:='Kara liste suresi devam ediyor';limit_tl:=0;
    ELSIF gecikmis>0 THEN
        aciklama:='Vadesi gecen oyuncu bankasi kredisi var';limit_tl:=0;
    ELSIF EXISTS (
        SELECT 1 FROM oyun.krediler WHERE user_id=p_user AND durum='takip'
    ) THEN
        aciklama:='Yasal takipte devlet bankasi kredisi var';limit_tl:=0;
    ELSIF limit_tl<1000 THEN
        aciklama:='Gelir ve kullanilabilir butce yetersiz';
    END IF;

    RETURN jsonb_build_object(
        'kredi_notu',notu,'not_ad',oyun.not_ad(notu),
        'haftalik_maas',round(maas7,2),
        'haftalik_kira',round(kira7,2),
        'haftalik_sirket',round(sirket7,2),
        'haftalik_gelir',haftalik_gelir,
        'nakit',round(nakit,2),
        'devlet_gunluk_taksit',round(devlet_gunluk_borc,2),
        'bu_vadede_ozel_borc',round(vadedeki_ozel_borc,2),
        'azami_kredi',limit_tl,
        'uygun',limit_tl>=1000,
        'neden',aciklama,
        'vade_saat',p_saat
    );
END $fn$;
CREATE OR REPLACE FUNCTION public.kredi_uygunluk(p_banka bigint DEFAULT NULL,p_saat integer DEFAULT 24)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
    u uuid := auth.uid();
    risk jsonb;
    bank oyun.sirketler;
    faiz numeric;
    limit_tl numeric;
BEGIN
    IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
    risk := oyun.kredi_risk_ozeti(u,p_saat);
    limit_tl := (risk->>'azami_kredi')::numeric;
    IF p_banka IS NULL THEN
        -- Devlet bankasindaki mevcut statut/puan tavanini da korur.
        limit_tl := least(limit_tl,oyun.kredi_limiti(u));
        faiz := oyun.kredi_orani(u)*p_saat/720;
    ELSE
        IF p_saat NOT IN (1,3,6,12,24,72,168,336,504,672) THEN
            RAISE EXCEPTION 'Gecersiz oyuncu banka vadesi';
        END IF;
        SELECT * INTO bank FROM oyun.sirketler
         WHERE id=p_banka AND sektor='banka' AND aktif;
        IF NOT FOUND THEN RAISE EXCEPTION 'Banka bulunamadi'; END IF;
        IF EXISTS(SELECT 1 FROM oyun.sirket_ortaklari
           WHERE sirket_id=p_banka AND user_id=u AND pay>0) THEN
            limit_tl:=0;
            risk:=risk||jsonb_build_object('neden','Kendi bankandan kredi alamazsin');
        END IF;
        limit_tl:=least(limit_tl,
            coalesce((oyun.oyb_saglik(p_banka)->>'kredi_verilebilir')::numeric,0));
        -- Kredi notu yuksekse dusuk faiz, riskli profilse yuksek faiz.
        faiz:=round(least(19.50,
            least(bank.banka_kredi_faiz,1.0)
            * CASE WHEN p_saat>=168 THEN 7 + 2*(p_saat/168-1)
                   ELSE p_saat/24.0 END
            * CASE WHEN (risk->>'kredi_notu')::integer<900 THEN 1.5
                   WHEN (risk->>'kredi_notu')::integer<1100 THEN 1.35
                   WHEN (risk->>'kredi_notu')::integer<1500 THEN 1.15
                   WHEN (risk->>'kredi_notu')::integer<1700 THEN 1.00
                   ELSE .90 END
            + CASE WHEN p_saat>=168 THEN (p_saat/168-1)*.50 ELSE 0 END),2);
    END IF;
    limit_tl:=greatest(0,floor(limit_tl/100)*100);
    RETURN risk||jsonb_build_object('azami_kredi',limit_tl,
       'uygun',limit_tl>=1000,'oran',faiz,'banka_id',p_banka);
END $fn$;
CREATE OR REPLACE FUNCTION public.oyb_kredi_basvur(p_banka bigint,p_tutar numeric,p_saat integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
    u uuid:=auth.uid();
    bank oyun.sirketler;
    risk jsonb;
    faiz numeric;
    toplam numeric;
    yeni_id bigint;
BEGIN
    IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
    IF p_tutar IS NULL OR p_tutar<>trunc(p_tutar) OR p_tutar<1000 OR p_tutar>500000 THEN
        RAISE EXCEPTION 'Kredi 1.000 - 500.000 TL arasinda tam TL olmali';
    END IF;
    IF p_saat NOT IN (1,3,6,12,24,72,168,336,504,672) OR p_saat IS NULL THEN
        RAISE EXCEPTION 'Vade 1 gun, 3 gun, 1, 2, 3, 4 hafta veya saatlik olabilir';
    END IF;
    SELECT * INTO bank FROM oyun.sirketler
      WHERE id=p_banka AND aktif AND sektor='banka';
    IF NOT FOUND THEN RAISE EXCEPTION 'Banka bulunamadi'; END IF;
    IF EXISTS(SELECT 1 FROM oyun.sirket_ortaklari
      WHERE sirket_id=p_banka AND user_id=u AND pay>0) THEN
        RAISE EXCEPTION 'Kendi bankandan kredi alamazsin';
    END IF;
    IF EXISTS(SELECT 1 FROM oyun.oyb_kredi
      WHERE borclu=u AND durum IN ('basvuru','aktif')) THEN
        RAISE EXCEPTION 'Once diger oyuncu bankasi kredini kapat veya yanitini bekle';
    END IF;

    risk:=public.kredi_uygunluk(p_banka,p_saat);
    IF p_tutar>(risk->>'azami_kredi')::numeric THEN
        RAISE EXCEPTION 'Kredi reddedildi: %. Azami limit % TL; notun %.',
          risk->>'neden',risk->>'azami_kredi',risk->>'kredi_notu';
    END IF;
    faiz:=(risk->>'oran')::numeric;
    toplam:=round(p_tutar*(1+faiz/100));
    INSERT INTO oyun.oyb_kredi(banka_id,borclu,anapara,saat,oran,toplam,kalan)
    VALUES(p_banka,u,p_tutar,p_saat,faiz,toplam,toplam) RETURNING id INTO yeni_id;
    RETURN jsonb_build_object('id',yeni_id,'anapara',p_tutar,'toplam',toplam,
        'oran',faiz,'saat',p_saat,'durum','basvuru',
        'kredi_notu',risk->'kredi_notu','azami_kredi',risk->'azami_kredi');
END $fn$;

-- Urun acik degilse basvuru yapilamaz. Vade faizi sunucu tarafinda kilitlenir.
CREATE OR REPLACE FUNCTION oyun.oyb_kredi_urun_dogrula()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE ur oyun.oyb_kredi_urun;
BEGIN
 SELECT * INTO ur FROM oyun.oyb_kredi_urun
 WHERE banka_id=new.banka_id AND saat=new.saat AND aktif;
 IF NOT FOUND THEN RAISE EXCEPTION 'Banka bu kredi vadesini sunmuyor'; END IF;
 new.taksit_sayisi:=ur.taksit_sayisi;
 new.oran:=least(19.50,round(new.oran+ur.ek_faiz,2));
 new.toplam:=round(new.anapara*(1+new.oran/100));
 new.kalan:=new.toplam;
 RETURN new;
END $$;
DROP TRIGGER IF EXISTS oyb_kredi_urun_basvuru ON oyun.oyb_kredi;
CREATE TRIGGER oyb_kredi_urun_basvuru BEFORE INSERT ON oyun.oyb_kredi
FOR EACH ROW EXECUTE FUNCTION oyun.oyb_kredi_urun_dogrula();

-- Mevcut kredi karar prosedurunu bozmadan banka tarafindan istenen dokumun iznini zorunlu tut.
CREATE OR REPLACE FUNCTION oyun.oyb_onay_ve_taksit_koruma()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
 IF old.durum='basvuru' AND new.durum='aktif' AND
   EXISTS (SELECT 1 FROM oyun.oyb_bilgi_izin
     WHERE kredi_id=new.id AND durum='talep') THEN
   RAISE EXCEPTION 'Oyuncunun finansal bilgi talebine yaniti bekleniyor';
 END IF;
 RETURN new;
END $$;
DROP TRIGGER IF EXISTS oyb_onay_izin_kontrol ON oyun.oyb_kredi;
CREATE TRIGGER oyb_onay_izin_kontrol BEFORE UPDATE OF durum ON oyun.oyb_kredi
FOR EACH ROW EXECUTE FUNCTION oyun.oyb_onay_ve_taksit_koruma();

CREATE OR REPLACE FUNCTION oyun.oyb_taksit_olustur_guncelle()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE i integer; n integer; kalan_odeme numeric; od numeric; x record;
BEGIN
 IF old.durum='basvuru' AND new.durum='aktif' AND new.acilis IS NOT NULL THEN
  n:=greatest(1,coalesce(new.taksit_sayisi,1));
  FOR i IN 1..n LOOP
   od:=CASE WHEN i=n THEN new.toplam-floor(new.toplam/n)*(n-1) ELSE floor(new.toplam/n) END;
   INSERT INTO oyun.oyb_kredi_taksit(kredi_id,sira,vade,tutar)
   VALUES(new.id,i,new.acilis+make_interval(hours=>(new.saat*i/n)),od)
   ON CONFLICT DO NOTHING;
  END LOOP;
 ELSIF new.kalan<old.kalan THEN
  kalan_odeme:=old.kalan-new.kalan;
  FOR x IN SELECT kredi_id,sira,tutar,odenen FROM oyun.oyb_kredi_taksit
           WHERE kredi_id=new.id AND odenen<tutar ORDER BY sira FOR UPDATE LOOP
   od:=least(kalan_odeme,x.tutar-x.odenen);
   UPDATE oyun.oyb_kredi_taksit SET odenen=odenen+od WHERE kredi_id=x.kredi_id AND sira=x.sira;
   kalan_odeme:=kalan_odeme-od;
   EXIT WHEN kalan_odeme<=0;
  END LOOP;
 END IF;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS oyb_taksit_takip ON oyun.oyb_kredi;
CREATE TRIGGER oyb_taksit_takip AFTER UPDATE OF durum,kalan ON oyun.oyb_kredi
FOR EACH ROW EXECUTE FUNCTION oyun.oyb_taksit_olustur_guncelle();

CREATE OR REPLACE FUNCTION public.oyb_urunler(p_banka bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirketler WHERE id=p_banka AND sektor='banka' AND aktif) THEN
 RAISE EXCEPTION 'Banka bulunamadi'; END IF;
 RETURN jsonb_build_object('urunler',coalesce((
 SELECT jsonb_agg(jsonb_build_object('saat',saat,'taksit',taksit_sayisi,'ek_faiz',ek_faiz,'aktif',aktif) ORDER BY saat)
 FROM oyun.oyb_kredi_urun WHERE banka_id=p_banka),'[]'::jsonb),
 'yonetebilir',EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=p_banka AND user_id=u AND pay>=50));
END $$;
CREATE OR REPLACE FUNCTION public.oyb_urun_ayarla(p_banka bigint,p_saat integer,p_aktif boolean,p_taksit integer,p_ek_faiz numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari
 WHERE sirket_id=p_banka AND user_id=auth.uid() AND pay>=50)
 THEN RAISE EXCEPTION 'Banka yonetim yetkisi yok'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirketler WHERE id=p_banka AND sektor='banka' AND aktif)
 THEN RAISE EXCEPTION 'Banka faal degil'; END IF;
 IF p_saat NOT IN (24,72,168,336,504,672) OR p_aktif IS NULL OR
 p_taksit IS NULL OR p_taksit NOT BETWEEN 1 AND 4 OR p_saat%p_taksit<>0 OR
 p_ek_faiz IS NULL OR p_ek_faiz<0 OR p_ek_faiz>3 THEN RAISE EXCEPTION 'Gecersiz kredi urunu'; END IF;
 INSERT INTO oyun.oyb_kredi_urun(banka_id,saat,taksit_sayisi,ek_faiz,aktif)
 VALUES(p_banka,p_saat,p_taksit,p_ek_faiz,p_aktif)
 ON CONFLICT(banka_id,saat) DO UPDATE
 SET taksit_sayisi=excluded.taksit_sayisi,ek_faiz=excluded.ek_faiz,aktif=excluded.aktif;
 RETURN public.oyb_urunler(p_banka);
END $$;
CREATE OR REPLACE FUNCTION public.oyb_bilgi_talep(p_kredi bigint,p_kapsam text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE k oyun.oyb_kredi; a text[]; t timestamptz:=oyun.simdi();
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_kredi AND durum='basvuru';
 IF NOT FOUND THEN RAISE EXCEPTION 'Bekleyen kredi basvurusu yok'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=k.banka_id
   AND user_id=auth.uid() AND pay>=50) THEN RAISE EXCEPTION 'Banka yonetim yetkisi yok'; END IF;
 SELECT array_agg(DISTINCT v) INTO a FROM unnest(p_kapsam) v
 WHERE v IN ('maas','mulk','kira','sirket','gunluk');
 IF a IS NULL OR cardinality(a)=0 OR cardinality(a)<>cardinality(p_kapsam) THEN
 RAISE EXCEPTION 'Bilgi talebi kapsami gecersiz'; END IF;
 INSERT INTO oyun.oyb_bilgi_izin(kredi_id,banka_id,borclu,istenen,izinli,durum,istek_at,cevap_at)
 VALUES(k.id,k.banka_id,k.borclu,a,'{}','talep',t,NULL)
 ON CONFLICT (kredi_id) DO UPDATE SET istenen=excluded.istenen,izinli='{}',
  durum='talep',istek_at=t,cevap_at=NULL;
 PERFORM oyun.bildir(k.borclu,'Banka kredi basvurun icin finansal bilgi izni istiyor. Kredi/Mevduat bolumunden kabul veya ret verebilirsin.',t);
 RETURN jsonb_build_object('tamam',true,'durum','talep','istenen',a);
END $$;
CREATE OR REPLACE FUNCTION public.oyb_bilgi_bekleyen()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('kredi_id',i.kredi_id,
   'banka',s.ad,'istenen',i.istenen,'izinli',i.izinli,'durum',i.durum,'istek_at',i.istek_at)
   ORDER BY i.istek_at DESC)
 FROM oyun.oyb_bilgi_izin i JOIN oyun.sirketler s ON s.id=i.banka_id
 WHERE i.borclu=auth.uid()),'[]'::jsonb);
END $$;
CREATE OR REPLACE FUNCTION public.oyb_bilgi_yanit(p_kredi bigint,p_onay boolean,p_kapsam text[] DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i oyun.oyb_bilgi_izin; a text[];t timestamptz:=oyun.simdi();
BEGIN
 IF auth.uid() IS NULL OR p_onay IS NULL THEN RAISE EXCEPTION 'Oturum/karar gerekli';END IF;
 SELECT * INTO i FROM oyun.oyb_bilgi_izin WHERE kredi_id=p_kredi AND borclu=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Sana ait bilgi talebi yok'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.oyb_kredi WHERE id=p_kredi AND durum='basvuru')
 THEN RAISE EXCEPTION 'Basvuru artik beklemede degil'; END IF;
 IF p_onay THEN
  SELECT array_agg(distinct v) INTO a FROM unnest(coalesce(p_kapsam,i.istenen)) v WHERE v=ANY(i.istenen);
  IF a IS NULL OR cardinality(a)=0 OR
  (p_kapsam IS NOT NULL AND cardinality(a)<>cardinality(p_kapsam)) THEN
    RAISE EXCEPTION 'Izin verilen bilgiler istenen kapsam icinde olmali';END IF;
 ELSE a:='{}';END IF;
 UPDATE oyun.oyb_bilgi_izin SET izinli=a,durum=CASE WHEN p_onay THEN 'izin' ELSE 'ret' END,cevap_at=t WHERE kredi_id=p_kredi;
 RETURN jsonb_build_object('tamam',true,'durum',CASE WHEN p_onay THEN 'izin' ELSE 'ret' END,'izinli',a);
END $$;
CREATE OR REPLACE FUNCTION public.oyb_bilgi_dokumu(p_kredi bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i oyun.oyb_bilgi_izin;k oyun.oyb_kredi;r jsonb:='{}'::jsonb;t timestamptz:=oyun.simdi();
 g jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_kredi;
 IF NOT FOUND THEN RAISE EXCEPTION 'Kredi yok'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=k.banka_id
 AND user_id=auth.uid() AND pay>=50) THEN RAISE EXCEPTION 'Yonetim yetkisi yok';END IF;
 SELECT * INTO i FROM oyun.oyb_bilgi_izin WHERE kredi_id=p_kredi AND durum='izin' AND borclu=k.borclu;
 IF NOT FOUND OR k.durum NOT IN ('basvuru','aktif') THEN RAISE EXCEPTION 'Oyuncu bu bilgiler icin izin vermedi';END IF;
 g:=oyun.gelir_hesap(k.borclu,t);
 IF 'maas'=ANY(i.izinli) THEN r:=r||jsonb_build_object('maas',jsonb_build_object('gunluk_net',g->'gunluk_net',
   'saatlik_maas',g#>'{saatlik,maas}','saatlik_makam',g#>'{saatlik,makam}')); END IF;
 IF 'gunluk'=ANY(i.izinli) THEN r:=r||jsonb_build_object('gunluk',jsonb_build_object('gelir',g->'gunluk_net')); END IF;
 IF 'mulk'=ANY(i.izinli) THEN r:=r||jsonb_build_object('mulk',
  coalesce((SELECT jsonb_agg(jsonb_build_object('id',m.id,'tip',m.tip,'il',m.il_id,
   'alis_bedeli',m.alis_bedeli,'haftalik_kira',m.haftalik_kira) ORDER BY m.id)
  FROM oyun.yatirim_mulkleri m WHERE m.user_id=k.borclu),'[]'::jsonb));END IF;
 IF 'kira'=ANY(i.izinli) THEN r:=r||jsonb_build_object('kira',jsonb_build_object('haftalik',
  (SELECT coalesce(sum(haftalik_kira),0) FROM oyun.yatirim_mulkleri WHERE user_id=k.borclu),
  'gunluk', (SELECT round(coalesce(sum(haftalik_kira),0)/7,2) FROM oyun.yatirim_mulkleri WHERE user_id=k.borclu))); END IF;
 IF 'sirket'=ANY(i.izinli) THEN r:=r||jsonb_build_object('sirket',
  coalesce((SELECT jsonb_agg(jsonb_build_object('sirket_id',s.id,'ad',s.ad,'pay',o.pay,
  'sermaye_pay_degeri',round(s.sermaye*o.pay/100)) ORDER BY s.id)
  FROM oyun.sirket_ortaklari o JOIN oyun.sirketler s ON s.id=o.sirket_id
  WHERE o.user_id=k.borclu AND o.pay>0),'[]'::jsonb));END IF;
 RETURN jsonb_build_object('kredi_id',p_kredi,'izinli',i.izinli,'dokum',r);
END $$;

-- Takvimi ve bilgi durumunu yalnizca ilgili oyuncu/banka yoneticisi gorur.
CREATE OR REPLACE FUNCTION public.oyb_kredi_ekler(p_banka bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',k.id,'banka_id',k.banka_id,
 'bilgi_durum',coalesce(i.durum,'yok'),'istenen',coalesce(i.istenen,'{}'::text[]),
 'izinli',coalesce(i.izinli,'{}'::text[]),'taksit_sayisi',k.taksit_sayisi,
 'taksitler',coalesce((SELECT jsonb_agg(jsonb_build_object('sira',t.sira,'vade',t.vade,
 'tutar',t.tutar,'odenen',t.odenen) ORDER BY t.sira)
 FROM oyun.oyb_kredi_taksit t WHERE t.kredi_id=k.id),'[]'::jsonb))
 ORDER BY k.id DESC)
 FROM oyun.oyb_kredi k LEFT JOIN oyun.oyb_bilgi_izin i ON i.kredi_id=k.id
 WHERE (p_banka IS NULL AND k.borclu=u) OR
 (p_banka IS NOT NULL AND k.banka_id=p_banka AND EXISTS(
 SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=p_banka AND user_id=u AND pay>0))
 ),'[]'::jsonb);
END $$;

REVOKE EXECUTE ON FUNCTION public.oyb_urunler(bigint),public.oyb_urun_ayarla(bigint,integer,boolean,integer,numeric),
 public.oyb_bilgi_talep(bigint,text[]),public.oyb_bilgi_yanit(bigint,boolean,text[]),
 public.oyb_bilgi_bekleyen(),public.oyb_bilgi_dokumu(bigint),public.oyb_kredi_ekler(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.oyb_urunler(bigint),public.oyb_urun_ayarla(bigint,integer,boolean,integer,numeric),
 public.oyb_bilgi_talep(bigint,text[]),public.oyb_bilgi_yanit(bigint,boolean,text[]),
 public.oyb_bilgi_bekleyen(),public.oyb_bilgi_dokumu(bigint),public.oyb_kredi_ekler(bigint) TO authenticated;
COMMIT;