-- Seçim Simülasyonu Online — 48 saat kabine kurma ve tek bakanlık kuralı.
-- Eski Cumhurbaşkanı geriye dönük düşürülmez: yürürlüğe giriş anından itibaren 48 saat.
-- Yeni Cumhurbaşkanları göreve başladıkları andan itibaren 48 saat kazanır.
CREATE TABLE IF NOT EXISTS oyun.cb_kabine_sure (
  makam_id bigint PRIMARY KEY REFERENCES oyun.makamlar(id) ON DELETE CASCADE,
  baslangic timestamptz NOT NULL,
  son_tarih timestamptz NOT NULL,
  ilk_tamam timestamptz,
  durum text NOT NULL DEFAULT 'kuruluyor',
  son_uyari integer NOT NULL DEFAULT 0,
  son_islem timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cb_kabine_durum_check CHECK(durum IN ('kuruluyor','tamam','yenileme','dustu'))
);
ALTER TABLE oyun.cb_kabine_sure ENABLE ROW LEVEL SECURITY;

-- Eski çoklu bakanlıkları ilk görevi tutarak tekilleştir.
DO $$
DECLARE r record;
BEGIN
 FOR r IN SELECT id,user_id,bakanlik FROM (
    SELECT m.*, row_number() OVER (PARTITION BY m.user_id ORDER BY m.bas,m.id) rn
    FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL
 ) x WHERE x.rn>1 LOOP
    PERFORM oyun.makam_bitir(r.id,oyun.simdi(),'tek_bakanlik_kurali');
    PERFORM oyun.bildir(r.user_id,
      format('Yeni kabine kuralı: Aynı oyuncu yalnız bir bakanlıkta görev alabilir. %s görevin sona erdi.',
        coalesce((SELECT ad FROM oyun.bakanliklar WHERE kod=r.bakanlik),r.bakanlik)),oyun.simdi());
 END LOOP;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS bakan_tek_oyuncu_aktif_uq
 ON oyun.makamlar(user_id) WHERE tur='bakan' AND bit IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS bakan_tek_bakanlik_aktif_uq
 ON oyun.makamlar(bakanlik) WHERE tur='bakan' AND bit IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS bakan_tek_bekleyen_teklif_aday_uq
 ON oyun.bakan_teklifleri(aday) WHERE durum='bekliyor';


CREATE OR REPLACE FUNCTION oyun.bakan_teklif_tek_kisi()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.durum='bekliyor' THEN
   IF EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL AND m.user_id=NEW.aday) THEN
     RAISE EXCEPTION 'Bu oyuncu zaten bakan. Aynı oyuncuya ikinci bakanlık teklif edilemez.';
   END IF;
   IF EXISTS(SELECT 1 FROM oyun.bakan_teklifleri b
      WHERE b.aday=NEW.aday AND b.durum='bekliyor' AND b.id IS DISTINCT FROM NEW.id AND b.bakanlik IS DISTINCT FROM NEW.bakanlik) THEN
     RAISE EXCEPTION 'Bu oyuncunun cevap bekleyen başka bir bakanlık teklifi var.';
   END IF;
 END IF;
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION oyun.cb_kabine_baslangic_tg()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_son timestamptz:=coalesce(NEW.bas,oyun.simdi())+interval '48 hours';
BEGIN
 IF NEW.tur='cb' AND NEW.bit IS NULL AND oyun.hukumet_sistemi()=0 THEN
   INSERT INTO oyun.cb_kabine_sure(makam_id,baslangic,son_tarih)
    VALUES(NEW.id,coalesce(NEW.bas,oyun.simdi()),v_son)
   ON CONFLICT(makam_id) DO NOTHING;
   PERFORM oyun.bildir(NEW.user_id,
      format('Cumhurbaşkanlığı: 12 bakanlığa 12 ayrı oyuncu atamak için 48 saatin var. Son tarih: %s (Türkiye saati). Eksik kalırsa görevin düşer.',
          to_char(v_son AT TIME ZONE 'Europe/Istanbul','DD.MM.YYYY HH24:MI')),oyun.simdi());
 END IF;
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION oyun.cb_kabine_sure_ata_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_sure timestamptz; v_makam_id bigint; v_durum text;
BEGIN
 IF NEW.tur='bakan' AND NEW.bit IS NULL AND oyun.hukumet_sistemi()=0 THEN
   SELECT m.id INTO v_makam_id FROM oyun.makamlar m
    WHERE m.tur='cb' AND m.bit IS NULL ORDER BY m.bas DESC LIMIT 1;
   IF v_makam_id IS NULL THEN
     RAISE EXCEPTION 'Cumhurbaşkanı bulunmadığı için yeni bakan atanamaz.';
   END IF;
   SELECT c.son_tarih,c.durum INTO v_sure,v_durum FROM oyun.cb_kabine_sure c
     WHERE c.makam_id=v_makam_id;
   IF v_durum IN ('kuruluyor','yenileme','dustu') AND oyun.simdi() >= v_sure THEN
     RAISE EXCEPTION 'Cumhurbaşkanının 48 saatlik kabine kurma süresi doldu. Yeni Cumhurbaşkanı seçimi bekleniyor.';
   END IF;
 END IF;
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION oyun.cb_kabine_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 t timestamptz:=oyun.simdi();
 v_cb oyun.makamlar;
 v_k oyun.cb_kabine_sure;
 dolu integer; toplam integer; r record;
 v_secim jsonb; v_n integer:=0;
BEGIN
 IF oyun.hukumet_sistemi()<>0 THEN RETURN 0; END IF;
 IF NOT pg_try_advisory_xact_lock(40881111) THEN RETURN 0; END IF;
 SELECT * INTO v_cb FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL
  ORDER BY bas DESC LIMIT 1 FOR UPDATE;
 IF v_cb.id IS NULL THEN RETURN 0; END IF;

 INSERT INTO oyun.cb_kabine_sure(makam_id,baslangic,son_tarih)
 VALUES (v_cb.id,coalesce(v_cb.bas,t),coalesce(v_cb.bas,t)+interval '48 hours')
 ON CONFLICT(makam_id) DO NOTHING;
 SELECT * INTO v_k FROM oyun.cb_kabine_sure WHERE makam_id=v_cb.id FOR UPDATE;
 SELECT COUNT(*) INTO toplam FROM oyun.bakanliklar;
 SELECT COUNT(*) INTO dolu FROM oyun.bakanliklar b WHERE EXISTS (
     SELECT 1 FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL AND m.bakanlik=b.kod
   );

 IF dolu=toplam AND toplam>0 THEN
   IF v_k.durum<>'tamam' THEN
     UPDATE oyun.cb_kabine_sure SET durum='tamam',ilk_tamam=coalesce(ilk_tamam,t),
       son_islem=t,son_uyari=0 WHERE makam_id=v_cb.id;
     PERFORM oyun.bildir(v_cb.user_id,
       format('Kabine tamamlandı: %s/%s bakanlıkta farklı oyuncular görevde. 48 saatlik yükümlülüğü yerine getirdin.',dolu,toplam),t);
     PERFORM oyun.olay('makam',format('%s 12 bakanlıktan oluşan kabinesini tamamladı.',oyun.kad(v_cb.user_id)),NULL,v_cb.parti_id,t);
   END IF;
   RETURN 0;
 END IF;

 IF v_k.durum='tamam' THEN
    UPDATE oyun.cb_kabine_sure
      SET durum='yenileme',son_tarih=t+interval '48 hours',son_uyari=0,son_islem=t
      WHERE makam_id=v_cb.id;
    PERFORM oyun.bildir(v_cb.user_id,
       format('Kabinede %s boş bakanlık oluştu. Tüm bakanlıkları 48 saat içinde yeniden doldurmalısın.',toplam-dolu),t);
    RETURN 0;
 END IF;
 IF v_k.durum='dustu' THEN RETURN 0; END IF;

 IF t>=v_k.son_tarih THEN
   UPDATE oyun.cb_kabine_sure SET durum='dustu',son_islem=t WHERE makam_id=v_cb.id;
   PERFORM oyun.makam_bitir(v_cb.id,t,'kabine_48_saat_suresi_doldu');
   FOR r IN SELECT id,user_id,bakanlik FROM oyun.makamlar WHERE tur='bakan' AND bit IS NULL LOOP
     PERFORM oyun.makam_bitir(r.id,t,'kabine_dustu');
     PERFORM oyun.bildir(r.user_id,'48 saat içerisinde tüm bakanlıklar doldurulamadığı için kabine düştü. Bakanlık görevin sona erdi.',t);
   END LOOP;
   UPDATE oyun.bakan_teklifleri SET durum='iptal',yanit_at=t WHERE durum='bekliyor';
   PERFORM oyun.bildir(v_cb.user_id,
     format('48 saatte kabineyi tamamlayamadın (%s/%s). Cumhurbaşkanlığı görevin sona erdi; ara seçim başlatılıyor.',dolu,toplam),t);
   PERFORM oyun.olay('makam',format('Cumhurbaşkanı %s, 48 saat içerisinde kabineyi tamamlayamadığı için görevden düştü. (%s/%s bakanlık).',
     oyun.kad(v_cb.user_id),dolu,toplam),NULL,v_cb.parti_id,t);
   PERFORM oyun.gazete_ekle('siyaset','48 saatlik kabine süresi doldu',
     format('Cumhurbaşkanı %s tüm bakanlıkları dolduramadı (%s/%s). Cumhurbaşkanlığı sona erdi ve ara seçim süreci açıldı.',
        oyun.kad(v_cb.user_id),dolu,toplam),v_cb.id,t);
   v_secim:=oyun.ara_secim_olustur('cb',NULL,NULL,t);
   RETURN 1;
 END IF;

 IF v_k.son_uyari<1 AND t>=v_k.son_tarih-interval '24 hours' THEN
   UPDATE oyun.cb_kabine_sure SET son_uyari=1,son_islem=t WHERE makam_id=v_cb.id;
   PERFORM oyun.bildir(v_cb.user_id,format('Kabine kurma süresinin bitmesine 24 saatten az kaldı. Eksik bakanlık sayısı: %s. (%s/%s dolu)',toplam-dolu,dolu,toplam),t);
 ELSIF v_k.son_uyari<2 AND t>=v_k.son_tarih-interval '6 hours' THEN
   UPDATE oyun.cb_kabine_sure SET son_uyari=2,son_islem=t WHERE makam_id=v_cb.id;
   PERFORM oyun.bildir(v_cb.user_id,format('Kritik uyarı: Kabineyi tamamlamak için 6 saatten az kaldı; %s bakanlık boş.',toplam-dolu),t);
 ELSIF v_k.son_uyari<3 AND t>=v_k.son_tarih-interval '1 hour' THEN
   UPDATE oyun.cb_kabine_sure SET son_uyari=3,son_islem=t WHERE makam_id=v_cb.id;
   PERFORM oyun.bildir(v_cb.user_id,'Son 1 saat! Boş bakanlıkları doldurmazsan Cumhurbaşkanlığı görevin düşecek.',t);
 END IF;
 RETURN 0;
END $function$;

CREATE OR REPLACE FUNCTION public.bakan_adaylari(p_ara text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); a text := lower(btrim(coalesce(p_ara,'')));
begin
 perform oyun.cb_zorunlu(p);
 return coalesce((
 select jsonb_agg(x order by (x->>'kidem')::numeric desc) from (
   select jsonb_build_object(
     'kad',pr.kad,'il',(select ad from oyun.iller where id=pr.il_id),
     'parti',oyun.parti_json(pr.parti_id),
     'kidem',oyun.kidem_puani(pr.id),
     'statu',oyun.statu_ad(oyun.statu_basamak(oyun.kidem_puani(pr.id))),
     'gorev',null,
     'bakanlik',(select b.ad from oyun.makamlar m join oyun.bakanliklar b on b.kod=m.bakanlik
       where m.user_id=pr.id and m.tur='bakan' and m.bit is null limit 1),
     'uygun',
     NOT EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.user_id=pr.id AND m.tur='bakan' AND m.bit IS NULL)
     AND NOT EXISTS(SELECT 1 FROM oyun.bakan_teklifleri bt WHERE bt.aday=pr.id AND bt.durum='bekliyor'),
     'engel',CASE
       WHEN EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.user_id=pr.id AND m.tur='bakan' AND m.bit IS NULL)
         THEN 'Zaten bir bakanlıkta görev yapıyor'
       WHEN EXISTS(SELECT 1 FROM oyun.bakan_teklifleri bt WHERE bt.aday=pr.id AND bt.durum='bekliyor')
         THEN 'Cevap bekleyen başka bakanlık teklifi var'
       ELSE NULL END
   ) x
   from oyun.profiller pr
   where not pr.yasakli
     and (a='' or lower(pr.kad) like a||'%' or lower(pr.kad) like '%'||a||'%')
   order by (lower(pr.kad) like a||'%') desc,pr.son_gorulme desc nulls last
   limit 25
 ) q),'[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION public.kabine()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 p oyun.profiller:=oyun.profilim();
 hid bigint:=oyun.aktif_hukumet_id();
 v_cb_id bigint;
 v_sure oyun.cb_kabine_sure;
 v_toplam integer;
 v_dolu integer;
BEGIN
 SELECT id INTO v_cb_id FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL ORDER BY bas DESC LIMIT 1;
 SELECT * INTO v_sure FROM oyun.cb_kabine_sure WHERE makam_id=v_cb_id;
 SELECT count(*) INTO v_toplam FROM oyun.bakanliklar;
 SELECT count(*) INTO v_dolu FROM oyun.bakanliklar b WHERE EXISTS(
   SELECT 1 FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL AND m.bakanlik=b.kod);
 RETURN jsonb_build_object(
   'sistem',CASE WHEN oyun.hukumet_sistemi()=1 THEN 'parlamenter' ELSE 'cumhurbaskanligi' END,
   'yurutme_benim',oyun.yurutme_user()=p.id,
   'basbakan',(SELECT jsonb_build_object('kad',oyun.kad(h.basbakan),'parti',oyun.parti_json(h.kuran_parti),'bas',h.bas,'tur',h.tur) FROM oyun.hukumetler h WHERE h.id=hid),
   'hukumet_id',hid,
   'cb',(SELECT jsonb_build_object('kad',oyun.kad(m.user_id),'parti',oyun.parti_json(m.parti_id),'bas',m.bas) FROM oyun.makamlar m WHERE m.tur='cb' AND m.bit IS NULL ORDER BY m.bas DESC LIMIT 1),
   'bakanlar',(SELECT jsonb_agg(jsonb_build_object('kod',b.kod,'ad',b.ad,'kad',oyun.kad(m.user_id),'parti',oyun.parti_json((SELECT parti_id FROM oyun.profiller WHERE id=m.user_id)),'bas',m.bas) ORDER BY b.sira)
     FROM oyun.bakanliklar b LEFT JOIN oyun.makamlar m ON m.bakanlik=b.kod AND m.tur='bakan' AND m.bit IS NULL),
   'kabine_sure',CASE WHEN oyun.hukumet_sistemi()=0 AND v_sure.makam_id IS NOT NULL THEN
      jsonb_build_object(
       'durum',v_sure.durum,
       'son_tarih',v_sure.son_tarih,
       'toplam',v_toplam,
       'dolu',v_dolu,
       'eksik',greatest(0,v_toplam-v_dolu),
       'kalan_saniye',greatest(0,floor(extract(epoch FROM v_sure.son_tarih-oyun.simdi()))::integer),
       'eksik_bakanliklar',coalesce((SELECT jsonb_agg(jsonb_build_object('kod',b.kod,'ad',b.ad) ORDER BY b.sira) FROM oyun.bakanliklar b WHERE NOT EXISTS(
          SELECT 1 FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL AND m.bakanlik=b.kod)), '[]'::jsonb))
      ELSE NULL END
 );
END $function$;


DROP TRIGGER IF EXISTS bakan_teklif_tek_kisi_trg ON oyun.bakan_teklifleri;
CREATE TRIGGER bakan_teklif_tek_kisi_trg
 BEFORE INSERT OR UPDATE OF aday,bakanlik,teklif_eden ON oyun.bakan_teklifleri
 FOR EACH ROW EXECUTE FUNCTION oyun.bakan_teklif_tek_kisi();

DROP TRIGGER IF EXISTS cb_kabine_baslangic_trg ON oyun.makamlar;
CREATE TRIGGER cb_kabine_baslangic_trg AFTER INSERT ON oyun.makamlar
 FOR EACH ROW EXECUTE FUNCTION oyun.cb_kabine_baslangic_tg();

DROP TRIGGER IF EXISTS cb_kabine_sure_ata_trg ON oyun.makamlar;
CREATE TRIGGER cb_kabine_sure_ata_trg
 BEFORE INSERT OR UPDATE OF tur,user_id,bakanlik,bit ON oyun.makamlar
 FOR EACH ROW EXECUTE FUNCTION oyun.cb_kabine_sure_ata_kontrol();

-- O an görevde olan Cumhurbaşkanına da yeni süre tanımlanır.
INSERT INTO oyun.cb_kabine_sure(makam_id,baslangic,son_tarih)
SELECT id,oyun.simdi(),oyun.simdi()+interval '48 hours'
FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL
ON CONFLICT(makam_id) DO NOTHING;

DO $$
DECLARE r record;
BEGIN
 SELECT m.user_id,c.son_tarih INTO r
  FROM oyun.makamlar m JOIN oyun.cb_kabine_sure c ON c.makam_id=m.id
  WHERE m.tur='cb' AND m.bit IS NULL ORDER BY m.bas DESC LIMIT 1;
 IF r.user_id IS NOT NULL THEN
  PERFORM oyun.bildir(r.user_id,format(
   '48 saatlik kabine zorunluluğu başladı. 12 bakanlığı 12 ayrı oyuncuyla doldur. Son tarih %s (Türkiye saati). Aksi hâlde görevin sona erer.',
   to_char(r.son_tarih AT TIME ZONE 'Europe/Istanbul','DD.MM.YYYY HH24:MI')),oyun.simdi());
 END IF;
END $$;

-- Ana zamanlayıcının etkin adımı: her dakika.
INSERT INTO oyun.zamanlayici_adim(adim,komut,periyot_dk,ofset_dk,sira,aktif)
VALUES ('cb_kabine_48saat','select oyun.cb_kabine_tick()',1,0,11,true)
ON CONFLICT(adim) DO UPDATE SET komut=excluded.komut,periyot_dk=excluded.periyot_dk,
ofset_dk=excluded.ofset_dk,sira=excluded.sira,aktif=excluded.aktif;
