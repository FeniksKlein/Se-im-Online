-- İçişleri: oyunculara valilik/emniyet müdürlüğü; görev teklifi, kabul, emir ve görevden alma.
CREATE TABLE IF NOT EXISTS oyun.icisleri_atama(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 il_id smallint NOT NULL REFERENCES oyun.iller(id),
 tur text NOT NULL CHECK(tur IN ('vali','emniyet')),
 hedef uuid NOT NULL REFERENCES oyun.profiller(id),
 bakan uuid NOT NULL REFERENCES oyun.profiller(id),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 20 AND 500),
 durum text NOT NULL DEFAULT 'teklif' CHECK(durum IN ('teklif','aktif','red','alindi','istifa','suresi_doldu')),
 olusturma timestamptz NOT NULL DEFAULT now(),
 cevap_at timestamptz,
 bas timestamptz,
 bitis timestamptz,
 son_karar timestamptz,
 kapatma_gerekce text
);
CREATE UNIQUE INDEX IF NOT EXISTS icisleri_atama_tek_il ON oyun.icisleri_atama(il_id,tur) WHERE durum IN ('teklif','aktif');
CREATE UNIQUE INDEX IF NOT EXISTS icisleri_atama_tek_oyuncu ON oyun.icisleri_atama(hedef) WHERE durum = 'aktif';
CREATE INDEX IF NOT EXISTS icisleri_atama_oyuncu ON oyun.icisleri_atama(hedef,olusturma DESC);
CREATE TABLE IF NOT EXISTS oyun.icisleri_il_emir(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 atama_id bigint NOT NULL REFERENCES oyun.icisleri_atama(id),
 il_id smallint NOT NULL REFERENCES oyun.iller(id),
 yapan uuid NOT NULL REFERENCES oyun.profiller(id),
 tur text NOT NULL CHECK(tur IN ('devriye','takviye','uzlasma')),
 gerekce text NOT NULL CHECK(char_length(gerekce) BETWEEN 25 AND 500),
 maliyet numeric NOT NULL CHECK(maliyet >=0),
 tarih timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS icisleri_il_emir_il ON oyun.icisleri_il_emir(il_id,tarih DESC);
ALTER TABLE oyun.icisleri_atama ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.icisleri_il_emir ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.icisleri_atama,oyun.icisleri_il_emir FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.icisleri_atama_teklif(p_il integer,p_tur text,p_hedef uuid,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n bigint; ilad text;
BEGIN
 IF u IS NULL OR oyun.bm_yetki(u,'icisleri') IS NULL THEN RAISE EXCEPTION 'İçişleri Bakanlığı yetkisi gerekli'; END IF;
 SELECT ad INTO ilad FROM oyun.iller WHERE id=p_il;
 IF ilad IS NULL OR p_tur NOT IN ('vali','emniyet') OR p_hedef IS NULL OR p_hedef=u OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=p_hedef AND NOT yasakli) THEN
   RAISE EXCEPTION 'Geçerli il, görev ve oyuncu gerekli';
 END IF;
 IF char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 20 AND 500 THEN RAISE EXCEPTION 'Atama gerekçesi en az 20 karakter'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 UPDATE oyun.icisleri_atama SET durum='suresi_doldu' WHERE (durum='teklif' AND olusturma<t-interval '24 hours') OR (durum='aktif' AND bitis<=t);
 IF EXISTS(SELECT 1 FROM oyun.icisleri_atama WHERE il_id=p_il AND tur=p_tur AND durum IN ('teklif','aktif')) THEN RAISE EXCEPTION 'Bu ilde görev dolu veya yanıt bekleniyor'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.icisleri_atama WHERE hedef=p_hedef AND durum IN ('teklif','aktif')) THEN RAISE EXCEPTION 'Bu oyuncunun aktif veya bekleyen görev teklifi var'; END IF;
 IF (SELECT count(*) FROM oyun.icisleri_atama WHERE olusturma>t-interval '24 hours')>=6 THEN RAISE EXCEPTION '24 saatte en fazla 6 atama teklifi'; END IF;
 PERFORM oyun.bm_kasa_harca('icisleri',50000/oyun.pazar_tl_milyar(),'gider','Valilik/emniyet müdürlüğü atama teklifi / '||ilad);
 INSERT INTO oyun.icisleri_atama(il_id,tur,hedef,bakan,gerekce,olusturma) VALUES(p_il,p_tur,p_hedef,u,btrim(p_gerekce),t) RETURNING id INTO n;
 PERFORM oyun.bildir(p_hedef,'İçişleri Bakanlığı size '||ilad||' ili '||CASE WHEN p_tur='vali' THEN 'Valiliği' ELSE 'Emniyet Müdürlüğü' END||' görevini teklif etti. İçişleri Komuta Merkezi ekranından 24 saatte cevap verebilirsiniz.');
 RETURN jsonb_build_object('tamam',true,'id',n);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_atama_yanit(p_id bigint,p_kabul boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_atama; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR p_kabul IS NULL THEN RAISE EXCEPTION 'Oturum ve yanıt gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_atama WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.hedef<>u OR x.durum<>'teklif' OR x.olusturma<t-interval '24 hours' THEN RAISE EXCEPTION 'Yanıtlanabilir görev teklifi bulunamadı'; END IF;
 IF p_kabul AND EXISTS(SELECT 1 FROM oyun.icisleri_atama WHERE hedef=u AND durum='aktif') THEN RAISE EXCEPTION 'Zaten başka bir idari göreviniz var'; END IF;
 UPDATE oyun.icisleri_atama SET durum=CASE WHEN p_kabul THEN 'aktif' ELSE 'red' END,cevap_at=t,bas=CASE WHEN p_kabul THEN t END,bitis=CASE WHEN p_kabul THEN t+interval '7 days' END WHERE id=x.id;
 PERFORM oyun.bildir(x.bakan,'Valilik/emniyet görev teklifi #'||x.id||' '||CASE WHEN p_kabul THEN 'kabul edildi' ELSE 'reddedildi' END||'.');
 IF p_kabul THEN
   PERFORM oyun.gazete_ekle('icisleri','İl idaresi atama kararı #'||x.id,
    (SELECT kad FROM oyun.profiller WHERE id=u)||' oyuncusu '||(SELECT ad FROM oyun.iller WHERE id=x.il_id)||' ilinde '||CASE WHEN x.tur='vali' THEN 'vali' ELSE 'emniyet müdürü' END||' görevine atandı.',x.id,t);
 END IF;
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_atama_kapat(p_id bigint,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_atama;
BEGIN
 IF u IS NULL OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 20 AND 500 THEN RAISE EXCEPTION 'Giriş ve en az 20 karakter gerekçe gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_atama WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.durum NOT IN ('teklif','aktif') OR (x.hedef<>u AND oyun.bm_yetki(u,'icisleri') IS NULL) THEN RAISE EXCEPTION 'Görev kapatma yetkisi yok'; END IF;
 UPDATE oyun.icisleri_atama SET durum=CASE WHEN x.hedef=u THEN 'istifa' ELSE 'alindi' END,kapatma_gerekce=btrim(p_gerekce),bitis=oyun.simdi() WHERE id=p_id;
 PERFORM oyun.bildir(x.hedef,'İl idaresi görev kaydınız #'||x.id||' kapatıldı: '||btrim(p_gerekce));
 PERFORM oyun.gazete_ekle('icisleri','İl idaresi görev sonu #'||x.id,'Gerekçe: '||btrim(p_gerekce),x.id,oyun.simdi());
 RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.icisleri_il_emir_ver(p_atama bigint,p_tur text,p_gerekce text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_atama; t timestamptz:=oyun.simdi(); maliyet numeric; n bigint;
BEGIN
 IF u IS NULL OR p_tur NOT IN ('devriye','takviye','uzlasma') OR char_length(btrim(coalesce(p_gerekce,''))) NOT BETWEEN 25 AND 500 THEN RAISE EXCEPTION 'Geçerli emir ve en az 25 karakter gerekçe gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_atama WHERE id=p_atama FOR UPDATE;
 IF x.id IS NULL OR x.durum<>'aktif' OR x.bitis<=t OR (x.hedef<>u AND oyun.bm_yetki(u,'icisleri') IS NULL) THEN RAISE EXCEPTION 'Aktif il görevi veya İçişleri yetkisi gerekli'; END IF;
 IF x.son_karar IS NOT NULL AND x.son_karar>t-interval '6 hours' THEN RAISE EXCEPTION 'Bu il makamında iki emir arasında 6 saat gerekir'; END IF;
 maliyet:=CASE p_tur WHEN 'devriye' THEN 150000 WHEN 'takviye' THEN 500000 ELSE 100000 END;
 PERFORM oyun.bm_kasa_harca('icisleri',maliyet/oyun.pazar_tl_milyar(),'gider','İl güvenlik ve uzlaşma emri #'||x.id);
 IF p_tur='devriye' THEN
   UPDATE oyun.il_durum SET memnuniyet=LEAST(100,memnuniyet+0.3),gelisim=LEAST(100,gelisim+0.2) WHERE il_id=x.il_id;
 ELSIF p_tur='takviye' THEN
   UPDATE oyun.il_durum SET memnuniyet=GREATEST(0,memnuniyet-0.5),gelisim=LEAST(100,gelisim+0.6) WHERE il_id=x.il_id;
 ELSE
   UPDATE oyun.il_durum SET memnuniyet=LEAST(100,memnuniyet+0.8) WHERE il_id=x.il_id;
 END IF;
 INSERT INTO oyun.icisleri_il_emir(atama_id,il_id,yapan,tur,gerekce,maliyet,tarih) VALUES(x.id,x.il_id,u,p_tur,btrim(p_gerekce),maliyet,t) RETURNING id INTO n;
 UPDATE oyun.icisleri_atama SET son_karar=t WHERE id=x.id;
 PERFORM oyun.gazete_ekle('icisleri','İl güvenlik emri #'||n,(SELECT ad FROM oyun.iller WHERE id=x.il_id)||' ilinde '||p_tur||' kararı: '||btrim(p_gerekce),n,t);
 RETURN jsonb_build_object('tamam',true,'id',n,'maliyet',maliyet);
END $$;

-- İtirazın yanıtsız kalmasını önle: başka bir bağımsız hâkim yoksa yaptırım iade edilir.
CREATE OR REPLACE FUNCTION public.icisleri_itiraz(p_id bigint,p_metin text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); x oyun.icisleri_dosya; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR char_length(btrim(coalesce(p_metin,''))) NOT BETWEEN 25 AND 800 THEN RAISE EXCEPTION '25–800 karakter itiraz gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(77118,1);
 SELECT * INTO x FROM oyun.icisleri_dosya WHERE id=p_id FOR UPDATE;
 IF x.id IS NULL OR x.hedef<>u OR x.durum<>'ceza' OR x.karar_at<t-interval '24 hours' THEN RAISE EXCEPTION 'Açık itiraz hakkı bulunamadı'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim IS NOT NULL AND hakim NOT IN (x.bakan,x.hedef,x.hakim)) THEN
   UPDATE oyun.cuzdan SET para=para+x.ceza_tutari,kidem=kidem+x.kidem_kaybi WHERE user_id=u;
   IF x.ceza_tutari>0 THEN
     INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(u,t,x.ceza_tutari,'iade','İçişleri cezası itiraz iadesi #'||x.id);
   END IF;
   UPDATE oyun.icisleri_dosya SET durum='kaldirildi',itiraz_metni=btrim(p_metin),itiraz_at=t,itiraz_karar='İkinci bağımsız hâkim bulunmadığından oyuncu lehine yaptırım kaldırıldı.',itiraz_karar_at=t WHERE id=p_id;
   PERFORM oyun.bildir(u,'İçişleri dosyası #'||p_id||': bağımsız itiraz hakimi olmadığı için ceza iade edildi.');
   RETURN jsonb_build_object('tamam',true,'otomatik_iade',true);
 END IF;
 UPDATE oyun.icisleri_dosya SET durum='itiraz',itiraz_metni=btrim(p_metin),itiraz_at=t WHERE id=p_id;
 PERFORM oyun.bildir(u,'İçişleri dosyası #'||p_id||' itirazınız alındı; ikinci bağımsız hâkim inceleyecek.');
 RETURN jsonb_build_object('tamam',true,'otomatik_iade',false);
END $$;

-- Önceki komuta paneliyle aynı yetki filtresini koruyarak il görevlilerini ekler.
CREATE OR REPLACE FUNCTION public.icisleri_komuta_panel() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); yetki boolean; yargi boolean; veri jsonb;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 yetki:=oyun.bm_yetki(u,'icisleri') IS NOT NULL;
 yargi:=EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u);
 veri:=jsonb_build_object(
 'yetki',yetki,'yargi',yargi,'kasa_tl',CASE WHEN yetki THEN (SELECT kasa*oyun.pazar_tl_milyar() FROM oyun.bakanlik_kasa WHERE kod='icisleri') ELSE NULL END,
 'icraatlar',CASE WHEN yetki THEN COALESCE((SELECT jsonb_agg(jsonb_build_object('kod',kod,'ad',ad,'aciklama',aciklama,'maliyet',maliyet,'il_gerekli',il_gerekli) ORDER BY ad) FROM oyun.icraatlar WHERE bakanlik='icisleri' AND kod LIKE 'ic_%'),'[]'::jsonb) ELSE '[]'::jsonb END,
 'iller',CASE WHEN yetki THEN COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'ad',ad) ORDER BY ad) FROM oyun.iller),'[]'::jsonb) ELSE '[]'::jsonb END,
 'basvurular',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',b.id,'user_id',b.user_id,'oyuncu',p.kad,'tur',b.tur,'gerekce',b.gerekce,'durum',b.durum,'acilis',b.acilis,'karar_gerekce',b.karar_gerekce,'odul',b.odul) ORDER BY b.acilis DESC) FROM
 (SELECT * FROM oyun.icisleri_basvuru WHERE yetki OR user_id=u ORDER BY acilis DESC LIMIT 40) b JOIN oyun.profiller p ON p.id=b.user_id),'[]'::jsonb),
 'dosyalar',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',d.id,'hedef',d.hedef,'oyuncu',p.kad,'bakan',d.bakan,'konu',d.konu,'delil',d.delil,'durum',CASE WHEN d.durum='inceleme' AND d.acilis<oyun.simdi()-interval '48 hours' THEN 'suresi_doldu' ELSE d.durum END,'acilis',d.acilis,'savunma',d.savunma,'karar_at',d.karar_at,'hakim',d.hakim,'karar_gerekce',d.karar_gerekce,'ceza',d.ceza_tutari,'kidem_kaybi',d.kidem_kaybi,'itiraz_metni',d.itiraz_metni,'itiraz_karar',d.itiraz_karar,'benim',d.hedef=u) ORDER BY d.acilis DESC) FROM
 (SELECT * FROM oyun.icisleri_dosya WHERE yetki OR yargi OR hedef=u ORDER BY acilis DESC LIMIT 40) d JOIN oyun.profiller p ON p.id=d.hedef),'[]'::jsonb),
 'atamalar',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',a.id,'il',i.ad,'il_id',a.il_id,'tur',a.tur,'oyuncu',p.kad,'hedef',a.hedef,'durum',CASE WHEN a.durum='teklif' AND a.olusturma<oyun.simdi()-interval '24 hours' THEN 'suresi_doldu' WHEN a.durum='aktif' AND a.bitis<=oyun.simdi() THEN 'suresi_doldu' ELSE a.durum END,'gerekce',a.gerekce,'olusturma',a.olusturma,'bitis',a.bitis,'benim',a.hedef=u,'son_karar',a.son_karar) ORDER BY a.olusturma DESC) FROM
 (SELECT * FROM oyun.icisleri_atama WHERE yetki OR hedef=u ORDER BY olusturma DESC LIMIT 100) a JOIN oyun.profiller p ON p.id=a.hedef JOIN oyun.iller i ON i.id=a.il_id),'[]'::jsonb));
 RETURN veri;
END $$;

REVOKE ALL ON FUNCTION public.icisleri_atama_teklif(integer,text,uuid,text),public.icisleri_atama_yanit(bigint,boolean),
 public.icisleri_atama_kapat(bigint,text),public.icisleri_il_emir_ver(bigint,text,text),public.icisleri_itiraz(bigint,text),
 public.icisleri_komuta_panel() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.icisleri_atama_teklif(integer,text,uuid,text),public.icisleri_atama_yanit(bigint,boolean),
 public.icisleri_atama_kapat(bigint,text),public.icisleri_il_emir_ver(bigint,text,text),public.icisleri_itiraz(bigint,text),
 public.icisleri_komuta_panel() TO authenticated;
