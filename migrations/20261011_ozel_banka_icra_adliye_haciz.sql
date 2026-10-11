-- 11.10.2026 | Oyun ici icra, yargi ve mahkeme gozetimli haciz
BEGIN;
CREATE TABLE IF NOT EXISTS oyun.oyb_icra(
 id bigserial PRIMARY KEY,
 kredi_id bigint NOT NULL UNIQUE REFERENCES oyun.oyb_kredi(id),
 banka_id bigint NOT NULL REFERENCES oyun.sirketler(id),
 borclu uuid NOT NULL REFERENCES oyun.profiller(id),
 basvuran uuid NOT NULL REFERENCES oyun.profiller(id),
 tur text NOT NULL CHECK (tur IN ('gelir','mulk','hisse','karma')),
 durum text NOT NULL DEFAULT 'acik' CHECK(durum IN ('acik','kabul','ret','itiraz','kapandi')),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 20 AND 1500),
 savunma text,
 acilis timestamptz NOT NULL DEFAULT now(),
 savunma_son timestamptz NOT NULL,
 karar_at timestamptz,
 kesin_son timestamptz,
 itiraz text,
 itiraz_at timestamptz
);
CREATE TABLE IF NOT EXISTS oyun.oyb_icra_oy(
 icra_id bigint NOT NULL REFERENCES oyun.oyb_icra(id) ON DELETE CASCADE,
 uye uuid NOT NULL REFERENCES oyun.profiller(id),
 asama text NOT NULL DEFAULT 'ilk' CHECK(asama IN ('ilk','itiraz')),
 karar text NOT NULL CHECK(karar IN ('kabul','ret')),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 10 AND 750),
 zaman timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(icra_id,uye,asama)
);
CREATE TABLE IF NOT EXISTS oyun.oyb_icra_haciz(
 id bigserial PRIMARY KEY,
 icra_id bigint NOT NULL REFERENCES oyun.oyb_icra(id),
 tur text NOT NULL CHECK(tur IN ('mulk','ev','hisse')),
 varlik_id bigint NOT NULL,
 tutar numeric NOT NULL CHECK(tutar>=1),
 durum text NOT NULL DEFAULT 'acik' CHECK(durum IN ('acik','satildi','iptal')),
 alici uuid REFERENCES oyun.profiller(id),
 satis_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS oyb_haciz_tek_aktif ON oyun.oyb_icra_haciz(tur,varlik_id) WHERE durum='acik';
CREATE INDEX IF NOT EXISTS oyb_icra_borclu ON oyun.oyb_icra(borclu,durum);
CREATE INDEX IF NOT EXISTS oyb_icra_banka ON oyun.oyb_icra(banka_id,durum);
ALTER TABLE oyun.oyb_icra ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.oyb_icra_oy ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.oyb_icra_haciz ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.oyb_icra,oyun.oyb_icra_oy,oyun.oyb_icra_haciz FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.oyb_icra_baslat(p_kredi bigint,p_tur text,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE k oyun.oyb_kredi;u uuid:=auth.uid();x bigint;t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 IF p_tur NOT IN ('gelir','mulk','hisse','karma') OR char_length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 20 AND 1500 THEN
 RAISE EXCEPTION 'Icra turu veya gerekce gecersiz';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_kredi FOR UPDATE;
 IF NOT FOUND OR k.durum<>'aktif' OR k.kalan<=0 THEN RAISE EXCEPTION 'Tahsil edilecek aktif kredi yok';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=k.banka_id AND user_id=u AND pay>=50) THEN
 RAISE EXCEPTION 'Banka yoneticisi degilsin';END IF;
 IF k.vade IS NULL OR k.vade+interval '12 hours'>t THEN RAISE EXCEPTION 'Vade ve 12 saatlik ek odeme suresi dolmadi';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.oyb_kredi_taksit WHERE kredi_id=k.id) THEN
 RAISE EXCEPTION 'Icra sozlesmesi bu sistemden onceki kredilere uygulanamaz';END IF;
 INSERT INTO oyun.oyb_icra(kredi_id,banka_id,borclu,basvuran,tur,gerekce,acilis,savunma_son)
 VALUES(k.id,k.banka_id,k.borclu,u,p_tur,trim(p_gerekce),t,t+interval '24 hours')
 RETURNING id INTO x;
 PERFORM oyun.bildir(k.borclu,'Adliyede kredi icra dosyasi #'||x||' acildi. Savunma icin 24 saatin var.',t);
 RETURN jsonb_build_object('id',x,'durum','acik','savunma_son',t+interval '24 hours');
END $$;

CREATE OR REPLACE FUNCTION public.oyb_icra_savun(p_icra bigint,p_savunma text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d oyun.oyb_icra;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 SELECT * INTO d FROM oyun.oyb_icra WHERE id=p_icra AND borclu=auth.uid() FOR UPDATE;
 IF NOT FOUND OR d.durum<>'acik' OR d.savunma_son<oyun.simdi() THEN RAISE EXCEPTION 'Savunma suresi acik degil';END IF;
 IF char_length(trim(coalesce(p_savunma,''))) NOT BETWEEN 10 AND 1500 THEN RAISE EXCEPTION 'Savunma 10-1500 karakter olmali'; END IF;
 UPDATE oyun.oyb_icra SET savunma=trim(p_savunma) WHERE id=p_icra;
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.oyb_icra_karar(p_icra bigint,p_karar text,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d oyun.oyb_icra;k oyun.oyb_kredi;u uuid:=auth.uid();say integer;t timestamptz:=oyun.simdi();asama text;son text;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 IF p_karar NOT IN ('kabul','ret') OR char_length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 10 AND 750 THEN
 RAISE EXCEPTION 'Gerekceli mahkeme karari gerekli';END IF;
 SELECT * INTO d FROM oyun.oyb_icra WHERE id=p_icra FOR UPDATE;
 IF NOT FOUND OR d.durum NOT IN ('acik','itiraz') THEN RAISE EXCEPTION 'Bu dosyada oylama acik degil';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=u) OR
 u IN (d.borclu,d.basvuran) OR EXISTS(
 SELECT 1 FROM oyun.sirket_ortaklari o WHERE o.sirket_id=d.banka_id AND o.user_id=u AND o.pay>0)
 THEN RAISE EXCEPTION 'Yetkili tarafsiz mahkeme uyesi degilsin';END IF;
 IF d.durum='acik' AND d.savunma_son>t AND d.savunma IS NULL THEN
 RAISE EXCEPTION 'Borclunun savunma suresi devam ediyor';END IF;
 IF d.durum='itiraz' AND d.itiraz_at+interval '24 hours'>t THEN
 RAISE EXCEPTION 'Itiraz inceleme hazirlik suresi devam ediyor';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=d.kredi_id;
 IF k.durum='odendi' OR k.kalan<=0 THEN
 UPDATE oyun.oyb_icra SET durum='kapandi' WHERE id=d.id;
 RETURN jsonb_build_object('durum','kapandi');END IF;
 asama:=CASE WHEN d.durum='itiraz' THEN 'itiraz' ELSE 'ilk' END;
 INSERT INTO oyun.oyb_icra_oy(icra_id,uye,asama,karar,gerekce,zaman)
 VALUES(d.id,u,asama,p_karar,trim(p_gerekce),t)
 ON CONFLICT(icra_id,uye,asama) DO UPDATE SET karar=excluded.karar,gerekce=excluded.gerekce,zaman=excluded.zaman;
 SELECT count(*) INTO say FROM oyun.oyb_icra_oy WHERE icra_id=d.id AND asama=asama AND karar=p_karar;
 IF say>=2 THEN
  son:=p_karar;
  UPDATE oyun.oyb_icra SET durum=son,karar_at=t,
     kesin_son=CASE WHEN asama='itiraz' THEN t ELSE t+interval '24 hours' END WHERE id=d.id;
  PERFORM oyun.bildir(d.borclu,'Icra #'||d.id||' mahkeme karari: '||son||
    CASE WHEN asama='ilk' AND son='kabul' THEN '. 24 saat icinde itiraz edebilirsin.' ELSE '' END,t);
  PERFORM oyun.bildir(d.basvuran,'Icra #'||d.id||' mahkeme karari: '||son,t);
 END IF;
 RETURN jsonb_build_object('oy',p_karar,'oy_sayisi',say,'durum',coalesce(son,d.durum));
END $$;

CREATE OR REPLACE FUNCTION public.oyb_icra_itiraz(p_icra bigint,p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d oyun.oyb_icra;t timestamptz:=oyun.simdi();
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 SELECT * INTO d FROM oyun.oyb_icra WHERE id=p_icra AND borclu=auth.uid() FOR UPDATE;
 IF NOT FOUND OR d.durum<>'kabul' OR d.kesin_son<=t OR d.itiraz_at IS NOT NULL THEN
 RAISE EXCEPTION 'Itiraz hakki veya suresi bulunmuyor';END IF;
 IF char_length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 10 AND 1500 THEN RAISE EXCEPTION 'Itiraz gerekcesi eksik';END IF;
 UPDATE oyun.oyb_icra SET durum='itiraz',itiraz=trim(p_gerekce),itiraz_at=t WHERE id=d.id;
 PERFORM oyun.bildir(d.basvuran,'Icra #'||d.id||' kararina borclu itiraz etti. Yargisal inceleme bekleniyor.',t);
 RETURN jsonb_build_object('tamam',true,'durum','itiraz');
END $$;

-- Haciz dosyasi goruntulemesi: kamusal dava ozeti, gizli banka bilgileri aktarilmaz.
CREATE OR REPLACE FUNCTION public.oyb_icra_dosyalar()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
 'id',d.id,'kredi_id',d.kredi_id,'banka_id',d.banka_id,'banka',s.ad,
 'borclu',p.kad,'borclu_muyum',d.borclu=u,
 'banka_yetkilisi',exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=d.banka_id and o.user_id=u and o.pay>=50),
 'hakim_miyim',exists(select 1 from oyun.mahkeme_uye m where m.user_id=u and u<>d.borclu and u<>d.basvuran
 and not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=d.banka_id and o.user_id=u and o.pay>0)),
 'tur',d.tur,'durum',d.durum,'gerekce',d.gerekce,'savunma',d.savunma,
 'savunma_son',d.savunma_son,'kesin_son',d.kesin_son,'itiraz',d.itiraz,
 'itiraz_at',d.itiraz_at,'acilis',d.acilis,
 'kalan',k.kalan,'vade',k.vade,
 'oylar',coalesce((select jsonb_agg(jsonb_build_object('asama',x.asama,'karar',x.karar,
 'gerekce',x.gerekce,'uye',(select kad from oyun.profiller where id=x.uye)))
 from oyun.oyb_icra_oy x where x.icra_id=d.id),'[]'::jsonb))
 ORDER BY d.id DESC)
 FROM (SELECT * FROM oyun.oyb_icra ORDER BY id DESC LIMIT 100) d
 JOIN oyun.oyb_kredi k ON k.id=d.kredi_id
 JOIN oyun.sirketler s ON s.id=d.banka_id
 LEFT JOIN oyun.profiller p ON p.id=d.borclu),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.oyb_icra_haciz_sec(p_icra bigint,p_tur text,p_varlik bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d oyun.oyb_icra;k oyun.oyb_kredi;deger numeric; x bigint;pay numeric;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 SELECT * INTO d FROM oyun.oyb_icra WHERE id=p_icra FOR UPDATE;
 IF NOT FOUND OR d.durum<>'kabul' OR d.kesin_son>oyun.simdi() THEN RAISE EXCEPTION 'Kesinlesmis haciz karari yok';END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=d.banka_id AND user_id=auth.uid() AND pay>=50)
 THEN RAISE EXCEPTION 'Banka yonetim yetkisi yok';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=d.kredi_id FOR UPDATE;
 IF k.kalan<=0 OR k.durum<>'aktif' THEN RAISE EXCEPTION 'Borclu krediyi kapatti';END IF;
 IF p_tur IN ('mulk','ev') AND d.tur NOT IN ('mulk','karma') THEN RAISE EXCEPTION 'Bu mal turune haciz yetkisi verilmedi';END IF;
 IF p_tur='hisse' AND d.tur NOT IN ('hisse','karma') THEN RAISE EXCEPTION 'Hisse haczi yetkisi verilmedi';END IF;
 IF p_tur='mulk' THEN
  SELECT alis_bedeli INTO deger FROM oyun.yatirim_mulkleri WHERE id=p_varlik AND user_id=d.borclu;
 ELSIF p_tur='ev' THEN
  SELECT bedel INTO deger FROM oyun.mulkler WHERE id=p_varlik AND user_id=d.borclu;
 ELSIF p_tur='hisse' THEN
  SELECT greatest(1,round(s.sermaye*o.pay/100)) INTO deger
  FROM oyun.sirket_ortaklari o JOIN oyun.sirketler s ON s.id=o.sirket_id
  WHERE o.sirket_id=p_varlik AND o.user_id=d.borclu AND s.sektor<>'banka';
 ELSE RAISE EXCEPTION 'Haciz turu gecersiz';END IF;
 IF deger IS NULL OR deger<=0 THEN RAISE EXCEPTION 'Varlik mevcut degil veya borcluya ait degil'; END IF;
 INSERT INTO oyun.oyb_icra_haciz(icra_id,tur,varlik_id,tutar)
 VALUES(d.id,p_tur,p_varlik,greatest(1,round(deger*0.85))) RETURNING id INTO x;
 PERFORM oyun.bildir(d.borclu,'Icra #'||d.id||' icin varligin icra satisina cikarildi. Tahmini bedel %85 uzerinden hesaplandi.',oyun.simdi());
 RETURN jsonb_build_object('haciz_id',x,'fiyat',greatest(1,round(deger*0.85)));
END $$;

CREATE OR REPLACE FUNCTION public.oyb_icra_haciz_liste()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 RETURN jsonb_build_object(
 'ihaleler',coalesce((SELECT jsonb_agg(jsonb_build_object('id',h.id,'icra_id',h.icra_id,
 'tur',h.tur,'varlik_id',h.varlik_id,'fiyat',h.tutar,'durum',h.durum,
 'banka',s.ad,'borclu',p.kad) ORDER BY h.id DESC)
 FROM oyun.oyb_icra_haciz h JOIN oyun.oyb_icra d ON d.id=h.icra_id
 JOIN oyun.sirketler s ON s.id=d.banka_id
 JOIN oyun.profiller p ON p.id=d.borclu
 WHERE h.durum='acik' AND d.durum='kabul' AND d.kesin_son<=oyun.simdi()),'[]'::jsonb),
 'varliklar',coalesce((SELECT jsonb_agg(v) FROM (
 SELECT jsonb_build_object('icra_id',d.id,'tur','mulk','varlik_id',m.id,
 'ad',m.tip||' (il '||m.il_id||')','tahmini',greatest(1,round(m.alis_bedeli*.85))) v
 FROM oyun.oyb_icra d JOIN oyun.yatirim_mulkleri m ON m.user_id=d.borclu
 WHERE d.durum='kabul' AND d.kesin_son<=oyun.simdi() AND d.tur IN ('mulk','karma')
 AND EXISTS(SELECT 1 FROM oyun.sirket_ortaklari o WHERE o.sirket_id=d.banka_id AND o.user_id=u AND o.pay>=50)
 UNION ALL
 SELECT jsonb_build_object('icra_id',d.id,'tur','ev','varlik_id',m.id,
 'ad',m.tur||' (il '||m.il_id||')','tahmini',greatest(1,round(m.bedel*.85)))
 FROM oyun.oyb_icra d JOIN oyun.mulkler m ON m.user_id=d.borclu
 WHERE d.durum='kabul' AND d.kesin_son<=oyun.simdi() AND d.tur IN ('mulk','karma')
 AND EXISTS(SELECT 1 FROM oyun.sirket_ortaklari o WHERE o.sirket_id=d.banka_id AND o.user_id=u AND o.pay>=50)
 UNION ALL
 SELECT jsonb_build_object('icra_id',d.id,'tur','hisse','varlik_id',s.id,
 'ad',s.ad||' ('||o.pay||'%)','tahmini',greatest(1,round(s.sermaye*o.pay/100*.85)))
 FROM oyun.oyb_icra d JOIN oyun.sirket_ortaklari o ON o.user_id=d.borclu
 JOIN oyun.sirketler s ON s.id=o.sirket_id AND s.sektor<>'banka'
 WHERE d.durum='kabul' AND d.kesin_son<=oyun.simdi() AND d.tur IN ('hisse','karma')
 AND EXISTS(SELECT 1 FROM oyun.sirket_ortaklari x WHERE x.sirket_id=d.banka_id AND x.user_id=u AND x.pay>=50)
 ) t WHERE v IS NOT NULL),'[]'::jsonb)
 );
END $$;

-- Mahkeme karari kesinlesmeden hicbir varlik degistirilmez.
CREATE OR REPLACE FUNCTION public.oyb_icra_haciz_al(p_haciz bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();h oyun.oyb_icra_haciz;d oyun.oyb_icra;k oyun.oyb_kredi;
pay_tutar numeric;fazla numeric;anapara_bolum numeric;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 SELECT * INTO h FROM oyun.oyb_icra_haciz WHERE id=p_haciz FOR UPDATE;
 IF NOT FOUND OR h.durum<>'acik' THEN RAISE EXCEPTION 'Icra satisi acik degil';END IF;
 SELECT * INTO d FROM oyun.oyb_icra WHERE id=h.icra_id;
 IF d.durum<>'kabul' OR d.kesin_son>oyun.simdi() THEN RAISE EXCEPTION 'Kesinlesmis mahkeme karari yok';END IF;
 IF u=d.borclu OR EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=d.banka_id AND user_id=u AND pay>0)
 THEN RAISE EXCEPTION 'Borclu veya bankanin ortaklari icra satisindan mal alamaz'; END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=d.kredi_id FOR UPDATE;
 IF k.durum<>'aktif' OR k.kalan<=0 THEN RAISE EXCEPTION 'Borc zaten kapandi';END IF;
 IF h.tur='mulk' THEN
  PERFORM 1 FROM oyun.yatirim_mulkleri WHERE id=h.varlik_id AND user_id=d.borclu FOR UPDATE;
 ELSIF h.tur='ev' THEN
  PERFORM 1 FROM oyun.mulkler WHERE id=h.varlik_id AND user_id=d.borclu FOR UPDATE;
 ELSE
  PERFORM 1 FROM oyun.sirket_ortaklari WHERE sirket_id=h.varlik_id AND user_id=d.borclu FOR UPDATE;
 END IF;
 IF NOT FOUND THEN RAISE EXCEPTION 'Haczedilen varlik artik borcluya ait degil';END IF;
 PERFORM oyun.para_islem(u,-h.tutar,'icra_satis','Icra varlik alimi #'||h.id,oyun.simdi());
 IF h.tur='mulk' THEN
  UPDATE oyun.yatirim_mulkleri SET user_id=u WHERE id=h.varlik_id AND user_id=d.borclu;
 ELSIF h.tur='ev' THEN
  UPDATE oyun.mulkler SET user_id=u WHERE id=h.varlik_id AND user_id=d.borclu;
 ELSE
  INSERT INTO oyun.sirket_ortaklari(sirket_id,user_id,pay,kar_kasada)
  SELECT sirket_id,u,pay,kar_kasada FROM oyun.sirket_ortaklari
  WHERE sirket_id=h.varlik_id AND user_id=d.borclu
  ON CONFLICT(sirket_id,user_id) DO UPDATE SET pay=oyun.sirket_ortaklari.pay+excluded.pay;
  DELETE FROM oyun.sirket_ortaklari WHERE sirket_id=h.varlik_id AND user_id=d.borclu;
 END IF;
 pay_tutar:=least(h.tutar,k.kalan);fazla:=h.tutar-pay_tutar;
 anapara_bolum:=least(pay_tutar,greatest(0,k.anapara-k.anapara_odendi));
 UPDATE oyun.oyb_kredi SET kalan=kalan-pay_tutar,
 anapara_odendi=anapara_odendi+anapara_bolum,
 durum=CASE WHEN kalan<=pay_tutar THEN 'odendi' ELSE 'aktif' END,
 kapanis=CASE WHEN kalan<=pay_tutar THEN oyun.simdi() ELSE kapanis END
 WHERE id=k.id;
 UPDATE oyun.sirketler SET kasa=kasa+pay_tutar WHERE id=k.banka_id;
 IF fazla>0 THEN PERFORM oyun.para_islem(d.borclu,fazla,'icra_fazla','Icra satisi borc ustu tutar #'||h.id,oyun.simdi());END IF;
 UPDATE oyun.oyb_icra_haciz SET durum='satildi',alici=u,satis_at=oyun.simdi() WHERE id=h.id;
 IF pay_tutar>=k.kalan THEN
  UPDATE oyun.oyb_icra SET durum='kapandi' WHERE id=d.id;
  UPDATE oyun.oyb_icra_haciz SET durum='iptal' WHERE icra_id=d.id AND durum='acik';
 END IF;
 PERFORM oyun.bildir(d.borclu,'Icra #'||d.id||' varlik satisi: '||pay_tutar||' TL borcuna mahsup edildi. Fazla: '||fazla||' TL.',oyun.simdi());
 RETURN jsonb_build_object('tamam',true,'borca_mahsup',pay_tutar,'borcluya_iade',fazla);
END $$;

-- Yalniz mahkemece kesinlesmis gelir haczinde pozitif gelir akisi uzerinden en fazla %25 kesinti.
CREATE OR REPLACE FUNCTION oyun.oyb_icra_gelir_kesintisi()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE d record;k oyun.oyb_kredi;kes numeric;t timestamptz:=oyun.simdi();
BEGIN
 IF new.tutar<=0 OR new.tur NOT IN ('maas','kira','mulk_kira','sirket','gazete_yazar','gorev') THEN RETURN NULL;END IF;
 FOR d IN SELECT i.id,i.kredi_id,i.banka_id,i.borclu
 FROM oyun.oyb_icra i WHERE i.borclu=new.user_id AND i.durum='kabul'
 AND i.kesin_son<=t AND i.tur IN ('gelir','karma') ORDER BY i.id
 LOOP
  SELECT * INTO k FROM oyun.oyb_kredi WHERE id=d.kredi_id FOR UPDATE;
  IF k.durum<>'aktif' OR k.kalan<=0 THEN CONTINUE;END IF;
  kes:=least(round(new.tutar*.25),k.kalan);
  IF kes<=0 THEN CONTINUE;END IF;
  PERFORM oyun.para_islem(d.borclu,-kes,'icra_haciz','Mahkeme onayli gelir haczi #'||d.id,t);
  UPDATE oyun.sirketler SET kasa=kasa+kes WHERE id=d.banka_id;
  UPDATE oyun.oyb_kredi SET kalan=kalan-kes,
   anapara_odendi=anapara_odendi+least(kes,greatest(0,k.anapara-k.anapara_odendi)),
   durum=CASE WHEN kalan<=kes THEN 'odendi' ELSE 'aktif' END,
   kapanis=CASE WHEN kalan<=kes THEN t ELSE kapanis END
  WHERE id=k.id;
  IF kes>=k.kalan THEN
    UPDATE oyun.oyb_icra SET durum='kapandi' WHERE id=d.id;
    UPDATE oyun.oyb_icra_haciz SET durum='iptal' WHERE icra_id=d.id AND durum='acik';
  END IF;
  EXIT; -- ayni gelir islemi birden fazla davadan kesilmez
 END LOOP;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS oyb_icra_gelir_haczi ON oyun.hesap_hareket;
CREATE TRIGGER oyb_icra_gelir_haczi AFTER INSERT ON oyun.hesap_hareket
FOR EACH ROW EXECUTE FUNCTION oyun.oyb_icra_gelir_kesintisi();

REVOKE EXECUTE ON FUNCTION public.oyb_icra_baslat(bigint,text,text),public.oyb_icra_savun(bigint,text),
public.oyb_icra_karar(bigint,text,text),public.oyb_icra_itiraz(bigint,text),
public.oyb_icra_dosyalar(),public.oyb_icra_haciz_sec(bigint,text,bigint),
public.oyb_icra_haciz_liste(),public.oyb_icra_haciz_al(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.oyb_icra_baslat(bigint,text,text),public.oyb_icra_savun(bigint,text),
public.oyb_icra_karar(bigint,text,text),public.oyb_icra_itiraz(bigint,text),
public.oyb_icra_dosyalar(),public.oyb_icra_haciz_sec(bigint,text,bigint),
public.oyb_icra_haciz_liste(),public.oyb_icra_haciz_al(bigint) TO authenticated;
COMMIT;