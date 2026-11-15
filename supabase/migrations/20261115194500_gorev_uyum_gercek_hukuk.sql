-- SEÇİM SİMÜLASYONU ONLINE | 2026-11-15 | Görev uyumu ve hukuki adaylık
-- Mevzuat: T.C. Anayasası m.82, 101, 106; 2839 m.18; 2972 m.17; 6271 m.11.
-- Not: Kaydedilen canlı roller geri döndürülmez; mevcut çakışmalar ayrı denetlenir.

CREATE TABLE IF NOT EXISTS oyun_yonetim.gorev_denetim (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 zaman timestamptz NOT NULL DEFAULT clock_timestamp(),
 makam_id bigint,user_id uuid,gorev text,bakanlik text,
 olay text NOT NULL,neden text,eski_bas timestamptz,eski_bit timestamptz,
 yeni_bit timestamptz,aktor uuid,islem_tx bigint NOT NULL DEFAULT txid_current()
);
REVOKE ALL ON oyun_yonetim.gorev_denetim FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS oyun.gorev_tercihi (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 secim_id bigint NOT NULL REFERENCES oyun.secimler(id),
 user_id uuid NOT NULL REFERENCES oyun.profiller(id),
 il_id smallint NOT NULL REFERENCES oyun.iller(id),
 parti_id bigint,
 baslangic timestamptz NOT NULL DEFAULT now(),
 son_tarih timestamptz NOT NULL,
 durum text NOT NULL DEFAULT 'bekliyor'
   CHECK (durum IN ('bekliyor','belediye','milletvekili','sure_doldu')),
 karar_at timestamptz,
 UNIQUE(secim_id,user_id,il_id)
);
CREATE INDEX IF NOT EXISTS gorev_tercihi_bekleyen_idx
 ON oyun.gorev_tercihi(son_tarih) WHERE durum='bekliyor';
ALTER TABLE oyun.gorev_tercihi ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.gorev_tercihi FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE oyun.gorev_tercihi_id_seq FROM PUBLIC,anon,authenticated;

-- Merkezi fonksiyonlar

CREATE OR REPLACE FUNCTION oyun.goreve_baslat(p_sid bigint)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE s oyun.secimler; k record; m record; t timestamptz:=oyun.simdi();
 v_hata text; v_detay text; v_yeni_cb boolean:=false;
BEGIN
 SELECT * INTO s FROM oyun.secimler WHERE id=p_sid FOR UPDATE;
 IF s.id IS NULL OR s.durum<>'sonuclandi' THEN RETURN; END IF;
 -- GEÇMİŞE DOĞRU GÖREV DEĞİŞİKLİĞİ YASAK; gelecekteki seçim çalıştırılamaz.
 IF s.goreve_bas IS NULL OR s.goreve_bas>t THEN RETURN; END IF;
 IF s.tur='kurultay' THEN
  FOR k IN SELECT * FROM oyun.kazananlar WHERE secim_id=s.id LOOP
   BEGIN
    CONTINUE WHEN NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=k.user_id AND parti_id=k.parti_id);
    IF (SELECT gb FROM oyun.partiler WHERE id=k.parti_id) IS DISTINCT FROM k.user_id THEN
      DELETE FROM oyun.parti_gby WHERE parti_id=k.parti_id;
    END IF;
    DELETE FROM oyun.parti_gby WHERE user_id=k.user_id;
    -- Parti genel başkanlığı milletvekilliği veya bakanlık görevini düşürmez.
    -- TBMM başkanlığı ile aktif parti liderliği bağdaşmaz.
    FOR m IN SELECT id FROM oyun.makamlar
      WHERE user_id=k.user_id AND tur='tbmm' AND bit IS NULL AND bas<=t
    LOOP
      PERFORM oyun.makam_bitir(m.id,t,'gorev_bagdasmazligi');
    END LOOP;
    UPDATE oyun.partiler SET gb=k.user_id WHERE id=k.parti_id;
    PERFORM oyun.bildir(k.user_id,
      format('Kurultayı kazandın: %s Genel Başkanı oldun.',(SELECT ad FROM oyun.partiler WHERE id=k.parti_id)),t);
   EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hata=MESSAGE_TEXT,v_detay=PG_EXCEPTION_CONTEXT;
    PERFORM oyun.tick_hata_yaz('goreve_baslat kurultay #'||s.id,v_hata,v_detay);
   END;
  END LOOP;
  PERFORM oyun.gb_halef(t);
 ELSIF s.tur='cb' AND coalesce((s.sonuc->>'ikinci_tur')::boolean,false) THEN
  NULL;
 ELSE
  -- Yalnızca yeni seçimde kazanan varsa yeni yasama dönemi başlasın.
  -- Eski milletvekillerinden sonradan atanmış olanlar geçmiş tarihli sonuçla silinemez.
  IF s.tur='mv' AND EXISTS(SELECT 1 FROM oyun.kazananlar WHERE secim_id=s.id) THEN
   FOR m IN SELECT id FROM oyun.makamlar
     WHERE tur='mv' AND bit IS NULL AND bas<=s.goreve_bas AND
       (secim_id IS DISTINCT FROM s.id)
   LOOP
    PERFORM oyun.makam_bitir(m.id,t,'donem_bitti');
   END LOOP;
  END IF;
  FOR k IN SELECT * FROM oyun.kazananlar WHERE secim_id=s.id ORDER BY sira,il_id LOOP
   BEGIN
    CONTINUE WHEN NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=k.user_id);
    -- Seçim anında uygun olmayan aday tüm seçimi kilitleyemez.
    IF EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=k.user_id AND sira IN (1,2)) THEN
      PERFORM oyun.bildir(k.user_id,'Yüksek Mahkeme üyeliği ile seçilmiş siyasi görev bağdaşmadığı için göreve başlayamadın.',t);
      IF s.tur='mv' THEN PERFORM oyun.yedek_getir(s.id,k.il_id,k.parti_id,t); END IF;
      CONTINUE;
    END IF;
    IF s.tur='bel' AND EXISTS(SELECT 1 FROM oyun.partiler WHERE gb=k.user_id AND NOT kapali) THEN
      PERFORM oyun.bildir(k.user_id,'Parti genel başkanlığın nedeniyle belediye başkanlığına geçiş uygun bulunmadı.',t);
      CONTINUE;
    END IF;
    -- 2972 m.17: MV iken belediye başkanı seçilenin 15 günlük görev tercih süresi.
    -- Bu süre içerisinde milletvekilliği düşmez, belediye görev devri bekler.
    IF s.tur='bel' AND EXISTS(SELECT 1 FROM oyun.makamlar
       WHERE user_id=k.user_id AND tur='mv' AND bit IS NULL) THEN
      INSERT INTO oyun.gorev_tercihi(secim_id,user_id,il_id,parti_id,baslangic,son_tarih)
       VALUES(s.id,k.user_id,k.il_id,k.parti_id,t,t+interval '15 days')
       ON CONFLICT(secim_id,user_id,il_id) DO NOTHING;
      PERFORM oyun.bildir(k.user_id,
        format('Belediye başkanı seçildin. 15 gün içinde milletvekilliğini korumayı veya belediye başkanlığını seçmelisin. Son tarih: %s.',
        to_char((t+interval '15 days') AT TIME ZONE 'Europe/Istanbul','DD.MM.YYYY HH24:MI')),t);
      CONTINUE;
    END IF;
    IF s.tur='bel' THEN
      FOR m IN SELECT id FROM oyun.makamlar WHERE tur='bel' AND il_id=k.il_id AND bit IS NULL LOOP
        PERFORM oyun.makam_bitir(m.id,t,'donem_bitti');
      END LOOP;
    ELSIF s.tur IN ('cb','cb2') THEN
      FOR m IN SELECT id FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL LOOP
        PERFORM oyun.makam_bitir(m.id,t,'donem_bitti');
      END LOOP;
    END IF;
    IF s.tur IN ('cb','cb2','bel') THEN DELETE FROM oyun.parti_gby WHERE user_id=k.user_id; END IF;
    -- Asla adayın tüm görevlerini indiscriminately kapatma.
    -- Yalnızca yeni görevin atanmasıyla mevzuata göre çakışanlar düşer
    -- (makam_bagdasmazlik_tg atama tetikleyicisinde).
    IF NOT EXISTS(SELECT 1 FROM oyun.makamlar
       WHERE secim_id=s.id AND tur=CASE WHEN s.tur='cb2' THEN 'cb' ELSE s.tur END AND user_id=k.user_id AND bit IS NULL) THEN
      INSERT INTO oyun.makamlar(tur,user_id,il_id,parti_id,secim_id,bas)
      VALUES(CASE WHEN s.tur='cb2' THEN 'cb' ELSE s.tur END,k.user_id,k.il_id,k.parti_id,s.id,t);
    END IF;
    IF s.tur IN ('cb','cb2') THEN v_yeni_cb:=true; END IF;
    PERFORM oyun.bildir(k.user_id,
      CASE WHEN s.tur IN ('cb','cb2') THEN 'Cumhurbaşkanlığı görevine başladın.'
        ELSE format('%s olarak göreve başladın.',
          CASE WHEN s.tur='mv' THEN (SELECT ad FROM oyun.iller WHERE id=k.il_id)||' Milletvekili'
               ELSE (SELECT ad FROM oyun.iller WHERE id=k.il_id)||' Belediye Başkanı' END) END,t);
   EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hata=MESSAGE_TEXT,v_detay=PG_EXCEPTION_CONTEXT;
      PERFORM oyun.tick_hata_yaz('goreve_baslat #'||s.id||' aday',v_hata,v_detay);
      PERFORM oyun.bildir(k.user_id,'Seçildiğin göreve geçişte teknik veya hukuki engel oluştu. Diğer oyuncuların seçim işlemleri devam ediyor.',t);
   END;
  END LOOP;
  IF s.tur IN ('cb','cb2') AND v_yeni_cb THEN
    FOR m IN SELECT id FROM oyun.makamlar WHERE tur='bakan' AND bit IS NULL
       AND secim_id IS DISTINCT FROM s.id
    LOOP
      PERFORM oyun.makam_bitir(m.id,t,'kabine_yenilendi');
    END LOOP;
  END IF;
  IF s.tur='mv' THEN PERFORM oyun.kanunlar_kaduk(t); END IF;
 END IF;
 UPDATE oyun.secimler SET durum='tamam' WHERE id=s.id;
END $function$
;

CREATE OR REPLACE FUNCTION oyun.makam_bitir(p_id bigint, p_zaman timestamp with time zone, p_neden text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE m oyun.makamlar; v_bas timestamptz; v_zaman timestamptz := COALESCE(p_zaman,oyun.simdi());
BEGIN
 SELECT bas INTO v_bas FROM oyun.makamlar WHERE id=p_id AND bit IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 IF v_zaman < v_bas THEN
  INSERT INTO oyun_yonetim.gorev_denetim(makam_id,olay,neden,eski_bas,yeni_bit,aktor)
   VALUES(p_id,'engellendi',coalesce(p_neden,'?')||': geçmiştarih',v_bas,v_zaman,auth.uid());
  RETURN;
 END IF;
 IF v_zaman > oyun.simdi()+interval '60 seconds' THEN
  INSERT INTO oyun_yonetim.gorev_denetim(makam_id,olay,neden,eski_bas,yeni_bit,aktor)
   VALUES(p_id,'engellendi',coalesce(p_neden,'?')||': gelecek_tarih',v_bas,v_zaman,auth.uid());
  RETURN;
 END IF;
 UPDATE oyun.makamlar SET bit=v_zaman,bitis_neden=p_neden
   WHERE id=p_id AND bit IS NULL AND bas<=v_zaman RETURNING * INTO m;
 IF m.id IS NULL THEN RETURN; END IF;
 IF p_neden IN ('yeni_gorev','gorevden_alindi','kabine_yenilendi','gorev_bagdasmazligi') THEN
  PERFORM oyun.bildir(m.user_id,
   CASE p_neden
    WHEN 'yeni_gorev' THEN format('Yeni göreve başladığın için %s görevin sona erdi.',oyun.makam_ad(m.tur,m.il_id,m.bakanlik))
    WHEN 'gorev_bagdasmazligi' THEN format('Yeni atama veya seçilme nedeniyle bağdaşmayan %s görevin sona erdi.',oyun.makam_ad(m.tur,m.il_id,m.bakanlik))
    WHEN 'gorevden_alindi' THEN format('Cumhurbaşkanı seni %s görevinden aldı.',oyun.makam_ad(m.tur,m.il_id,m.bakanlik))
    ELSE format('Yeni Cumhurbaşkanı göreve başladığı için %s görevin sona erdi.',oyun.makam_ad(m.tur,m.il_id,m.bakanlik))
   END,v_zaman);
 END IF;
 IF m.tur='mv' AND p_neden <> 'donem_bitti' THEN
   PERFORM oyun.yedek_getir(m.secim_id,m.il_id,m.parti_id,v_zaman);
 END IF;
END $function$
;

CREATE OR REPLACE FUNCTION oyun.cb_kesin_aday_gorev_birak()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_secim oyun.secimler; v_t timestamptz := oyun.simdi(); v_m record;
BEGIN
 SELECT * INTO v_secim FROM oyun.secimler WHERE id=NEW.secim_id;
 IF v_secim.tur <> 'cb' OR v_secim.durum <> 'bekliyor' THEN RETURN NEW; END IF;
 IF TG_OP = 'UPDATE' AND NEW.secim_id=OLD.secim_id AND NEW.user_id=OLD.user_id THEN RETURN NEW; END IF;
 PERFORM 1 FROM oyun.profiller WHERE id=NEW.user_id FOR UPDATE;
 -- 6271 s. Kanun madde 11: CB aday listesinin kesinleşmesinde belediye başkanlığı sona erer.
 -- Milletvekilliği sırf adaylık nedeniyle sona ERMEZ. Aynı şekilde milli parti liderliği, bakanlık
 -- ve CB yardımcılığı için doğrudan kanuni düşme kuralı bulunmadığından keyfi düşme yapılmaz.
 FOR v_m IN SELECT id,il_id FROM oyun.makamlar
   WHERE user_id=NEW.user_id AND tur='bel' AND bit IS NULL AND bas<=v_t
 LOOP
  PERFORM oyun.makam_bitir(v_m.id,v_t,'cb_adayligi');
  IF v_m.il_id IS NOT NULL THEN PERFORM oyun.ara_secim_olustur('bel',NULL,v_m.il_id,v_t); END IF;
 END LOOP;
 -- 6271 m.11 kapsamındaki meslek kuruluşu ve sendika yönetim görevleri
 UPDATE oyun.oda SET baskan=NULL,baskan_bas=NULL,baskan_sendika=NULL WHERE baskan=NEW.user_id;
 UPDATE oyun.sendika SET baskan=NULL WHERE baskan=NEW.user_id;
 PERFORM oyun.bildir(NEW.user_id,
   'Cumhurbaşkanlığı kesin adaylığın kaydedildi. Milletvekilliği ve varsa mevcut cumhurbaşkanlığı devam eder; belediye başkanlığı ile mevzuatta ayrılması gereken meslek kuruluşu ve sendika başkanlıkları sona erer.',v_t);
 RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION oyun.rol_uyumlu(a text, b text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT CASE
  WHEN a IS NULL OR b IS NULL THEN false
  WHEN a=b THEN false
  WHEN a='mv' OR b='mv' THEN
    (CASE WHEN a='mv' THEN b ELSE a END) IN ('gb','gby','tbmm','bskv','grup_bskv')
  WHEN a='cb' OR b='cb' THEN
    (CASE WHEN a='cb' THEN b ELSE a END) IN ('gb','gby')
  WHEN a='bel' OR b='bel' THEN
    (CASE WHEN a='bel' THEN b ELSE a END) IN ('gb','gby')
  WHEN a='bakan' OR b='bakan' THEN
    (CASE WHEN a='bakan' THEN b ELSE a END) IN ('gb','gby')
  WHEN a='cb_yardimcisi' OR b='cb_yardimcisi' THEN
    (CASE WHEN a='cb_yardimcisi' THEN b ELSE a END) IN ('gb','gby')
  WHEN a='tbmm' OR b='tbmm' THEN
    (CASE WHEN a='tbmm' THEN b ELSE a END) IN ('mv')
  WHEN a IN ('gb','gby') AND b IN ('gb','gby') THEN false
  WHEN a IN ('bskv','grup_bskv') AND b IN ('gb','gby') THEN true
  WHEN b IN ('bskv','grup_bskv') AND a IN ('gb','gby') THEN true
  ELSE false
 END
$function$
;

CREATE OR REPLACE FUNCTION oyun.gorev_tercihi_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r record; t timestamptz:=oyun.simdi(); n integer:=0;
BEGIN
 FOR r IN SELECT id,user_id FROM oyun.gorev_tercihi
   WHERE durum='bekliyor' AND son_tarih<=t FOR UPDATE SKIP LOCKED
 LOOP
  UPDATE oyun.gorev_tercihi SET durum='sure_doldu',karar_at=t WHERE id=r.id;
  PERFORM oyun.bildir(r.user_id,
    '15 günlük görev tercih süren doldu. Kanun gereği seçildiğin yeni belediye başkanlığını reddetmiş sayıldın; mevcut milletvekilliğin devam ediyor.',t);
  n:=n+1;
 END LOOP;
 RETURN n;
END $function$
;

CREATE OR REPLACE FUNCTION oyun_yonetim.gorev_denetim_tg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF TG_OP = 'INSERT' THEN
  INSERT INTO oyun_yonetim.gorev_denetim(makam_id,user_id,gorev,bakanlik,olay,neden,eski_bas,yeni_bit,aktor)
  VALUES(NEW.id,NEW.user_id,NEW.tur,NEW.bakanlik,'atandi',NEW.kaynak,NEW.bas,NEW.bit,auth.uid());
 ELSIF TG_OP = 'UPDATE' AND OLD.bit IS NULL AND NEW.bit IS NOT NULL THEN
  INSERT INTO oyun_yonetim.gorev_denetim(makam_id,user_id,gorev,bakanlik,olay,neden,eski_bas,eski_bit,yeni_bit,aktor)
  VALUES(NEW.id,NEW.user_id,NEW.tur,NEW.bakanlik,'bitti',NEW.bitis_neden,NEW.bas,OLD.bit,NEW.bit,auth.uid());
 END IF;
 RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION oyun_yonetim.makam_tarih_koru_tg()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.bit IS NOT NULL AND NEW.bas IS NOT NULL AND NEW.bit < NEW.bas THEN
  RAISE EXCEPTION 'Görev bitiş tarihi başlangıçtan önce olamaz: makam %, bas %, bit %',NEW.id,NEW.bas,NEW.bit;
 END IF;
 RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION oyun_yonetim.mv_adaylik_gorev_tg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_secim oyun.secimler; v_t timestamptz:=oyun.simdi(); v_m record;
BEGIN
 SELECT * INTO v_secim FROM oyun.secimler WHERE id=NEW.secim_id;
 IF v_secim.tur NOT IN ('mv_on','mv') OR v_secim.durum<>'bekliyor' THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' AND NEW.secim_id=OLD.secim_id AND NEW.user_id=OLD.user_id THEN RETURN NEW; END IF;
 PERFORM 1 FROM oyun.profiller WHERE id=NEW.user_id FOR UPDATE;
 -- 2839 s. Kanun m.18: belediye başkanı MV adaylık başvurusundan önce ayrılır.
 FOR v_m IN SELECT id,il_id FROM oyun.makamlar
   WHERE user_id=NEW.user_id AND tur='bel' AND bit IS NULL AND bas<=v_t
 LOOP
  PERFORM oyun.makam_bitir(v_m.id,v_t,'mv_adayligi');
  IF v_m.il_id IS NOT NULL THEN PERFORM oyun.ara_secim_olustur('bel',NULL,v_m.il_id,v_t); END IF;
  PERFORM oyun.bildir(NEW.user_id,
    'Milletvekilliği adaylık başvurun nedeniyle belediye başkanlığı görevin 2839 sayılı Kanun madde 18 uyarınca sona erdi.',v_t);
 END LOOP;
 RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION oyun_yonetim.makam_bagdasmazlik_tg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_m record; v_t timestamptz:=oyun.simdi();
BEGIN
 IF NEW.bit IS NOT NULL THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' AND OLD.bit IS NULL AND OLD.tur=NEW.tur AND OLD.user_id=NEW.user_id THEN RETURN NEW; END IF;
 IF NEW.bas > v_t+interval '60 seconds' THEN RETURN NEW; END IF;
 IF NEW.tur IN ('bakan','cb_yardimcisi') THEN
   FOR v_m IN SELECT id FROM oyun.makamlar
    WHERE user_id=NEW.user_id AND id<>NEW.id AND bit IS NULL AND bas<=NEW.bas
     AND tur IN ('mv','tbmm','bskv','grup_bskv','bel',
       CASE WHEN NEW.tur='bakan' THEN 'cb_yardimcisi' ELSE 'bakan' END)
   LOOP
    PERFORM oyun.makam_bitir(v_m.id,v_t,'gorev_bagdasmazligi');
   END LOOP;
 ELSIF NEW.tur='mv' THEN
   FOR v_m IN SELECT id FROM oyun.makamlar
    WHERE user_id=NEW.user_id AND id<>NEW.id AND bit IS NULL AND bas<=NEW.bas
      AND tur IN ('bakan','cb_yardimcisi','bel','cb')
   LOOP
    PERFORM oyun.makam_bitir(v_m.id,v_t,'gorev_bagdasmazligi');
   END LOOP;
 ELSIF NEW.tur='bel' THEN
   FOR v_m IN SELECT id FROM oyun.makamlar
    WHERE user_id=NEW.user_id AND id<>NEW.id AND bit IS NULL AND bas<=NEW.bas
     AND tur IN ('mv','tbmm','bskv','grup_bskv','bakan','cb_yardimcisi','cb')
   LOOP
    PERFORM oyun.makam_bitir(v_m.id,v_t,'gorev_bagdasmazligi');
   END LOOP;
 ELSIF NEW.tur='cb' THEN
   FOR v_m IN SELECT id FROM oyun.makamlar
    WHERE user_id=NEW.user_id AND id<>NEW.id AND bit IS NULL AND bas<=NEW.bas
     AND tur IN ('mv','tbmm','bskv','grup_bskv','bakan','cb_yardimcisi','bel')
   LOOP
    PERFORM oyun.makam_bitir(v_m.id,v_t,'gorev_bagdasmazligi');
   END LOOP;
 END IF;
 RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION oyun_yonetim.cb_bakan_ayni_kisi_yasak_tg()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.bit IS NULL AND NEW.tur IN ('bakan','cb_yardimcisi')
   AND EXISTS(SELECT 1 FROM oyun.makamlar m
     WHERE m.user_id=NEW.user_id AND m.tur='cb' AND m.bit IS NULL AND m.id IS DISTINCT FROM NEW.id)
 THEN
  RAISE EXCEPTION 'Cumhurbaşkanı aynı zamanda bakan veya cumhurbaşkanı yardımcısı olamaz.';
 END IF;
 RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public.gorev_tercihi_bekleyen()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',g.id,'secim_id',g.secim_id,'il',i.ad,
      'son_tarih',g.son_tarih,'durum',g.durum) ORDER BY g.id), '[]'::jsonb)
 FROM oyun.gorev_tercihi g JOIN oyun.iller i ON i.id=g.il_id
 WHERE g.user_id=auth.uid() AND g.durum='bekliyor' AND g.son_tarih>oyun.simdi()
$function$
;

CREATE OR REPLACE FUNCTION public.gorev_tercihi_yap(p_id bigint, p_tercih text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v oyun.gorev_tercihi; m record; t timestamptz:=oyun.simdi(); v_uid uuid:=auth.uid();
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'Giriş yapmalısın.'; END IF;
 IF p_tercih NOT IN ('belediye','milletvekili') THEN RAISE EXCEPTION 'Geçersiz tercih.'; END IF;
 SELECT * INTO v FROM oyun.gorev_tercihi WHERE id=p_id AND user_id=v_uid FOR UPDATE;
 IF v.id IS NULL THEN RAISE EXCEPTION 'Tercih kaydı bulunamadı.'; END IF;
 IF v.durum<>'bekliyor' OR v.son_tarih<t THEN RAISE EXCEPTION 'Tercih süresi doldu veya tercih yapılmış.'; END IF;
 IF p_tercih='belediye' THEN
   IF NOT EXISTS (SELECT 1 FROM oyun.makamlar WHERE tur='mv' AND user_id=v_uid AND bit IS NULL) THEN
    RAISE EXCEPTION 'Tercih edilecek mevcut milletvekilliği artık yok.'; END IF;
   IF EXISTS (SELECT 1 FROM oyun.makamlar WHERE tur='bel' AND il_id=v.il_id AND bit IS NULL AND bas>v.baslangic) THEN
    RAISE EXCEPTION 'Belediye başkanlığı koltuğu yeni bir atamayla dolmuş.'; END IF;
   FOR m IN SELECT id FROM oyun.makamlar WHERE tur='bel' AND il_id=v.il_id AND bit IS NULL LOOP
    PERFORM oyun.makam_bitir(m.id,t,'donem_bitti');
   END LOOP;
   INSERT INTO oyun.makamlar(tur,user_id,il_id,parti_id,secim_id,bas,kaynak)
    VALUES('bel',v_uid,v.il_id,v.parti_id,v.secim_id,t,'secim');
   UPDATE oyun.gorev_tercihi SET durum='belediye',karar_at=t WHERE id=v.id;
   PERFORM oyun.bildir(v_uid,'15 günlük görev tercihinde belediye başkanlığını seçtin. Milletvekilliğin sona erdi.',t);
 ELSE
   UPDATE oyun.gorev_tercihi SET durum='milletvekili',karar_at=t WHERE id=v.id;
   PERFORM oyun.bildir(v_uid,'15 günlük görev tercihinde milletvekilliğini korudun; belediye başkanlığına geçmedin.',t);
 END IF;
 RETURN jsonb_build_object('tamam',true,'tercih',p_tercih);
END $function$
;

CREATE OR REPLACE FUNCTION public.bakan_teklif_yanit(p_teklif bigint, p_kabul boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 p oyun.profiller := oyun.profilim();
 t timestamptz := oyun.simdi();
 teklif oyun.bakan_teklifleri;
 b oyun.bakanliklar;
 makam record;
 eski_makam bigint;
 unvan text;
begin
 if p_kabul is null then raise exception 'Kabul veya ret seçmelisin.'; end if;
 select * into teklif from oyun.bakan_teklifleri where id=p_teklif;
 if teklif.id is null or teklif.aday<>p.id then raise exception 'Bu teklif sana ait değil.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('bakan_teklif'),
                                         pg_catalog.hashtext(teklif.bakanlik));
 select * into teklif from oyun.bakan_teklifleri where id=p_teklif for update;
 if teklif.durum<>'bekliyor' then raise exception 'Bu teklif artık geçerli değil.'; end if;
 if teklif.teklif_eden is distinct from oyun.yurutme_user()
 then raise exception 'Hükümet değiştiği için bu teklif artık geçerli değil.'; end if;
 select * into b from oyun.bakanliklar where kod=teklif.bakanlik;
 unvan := oyun.yurutme_unvan();
 if not p_kabul then
   update oyun.bakan_teklifleri set durum='ret',yanit_at=t where id=teklif.id;
   perform oyun.bildir(teklif.teklif_eden,format('%s, %s bakanlığı teklifini reddetti.',p.kad,b.ad),t);
   return jsonb_build_object('durum','ret','bakanlik',b.ad);
 end if;
 if p.yasakli then raise exception 'Yasaklı hesap bakanlık görevini kabul edemez.'; end if;
 for makam in select id,user_id from oyun.makamlar
              where tur='bakan' and bakanlik=b.kod and bit is null
 loop
   if makam.user_id=p.id then
     raise exception 'Zaten bu bakanlık görevindesin.';
   end if;
   perform oyun.makam_bitir(makam.id,t,'gorevden_alindi');
 end loop;
 insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,kaynak,bas)
 values('bakan',p.id,null,p.parti_id,b.kod,'atama',t)
 returning id into eski_makam;
 update oyun.bakan_teklifleri set durum='kabul',yanit_at=t where id=teklif.id;
 update oyun.bakan_teklifleri set durum='iptal',yanit_at=t
   where bakanlik=b.kod and id<>teklif.id and durum='bekliyor';
 perform oyun.bildir(p.id,format('%s görevini kabul ettin. Milletvekilliği dahil bağdaşmayan eski makamların sona erer.',replace(b.ad,'Bakanlığı','Bakanlığı')),t);
 perform oyun.bildir(teklif.teklif_eden,format('%s, %s görevini kabul etti ve bakan olarak atandı.',p.kad,b.ad),t);
 perform oyun.olay('makam',format('%s, %s olarak atandı.',p.kad,replace(b.ad,'Bakanlığı','Bakanı')),null,p.parti_id,t);
 perform oyun.gazete_ekle('atama',format('%s''na %s atandı',b.ad,p.kad),
   format('%s, %s tarafından sunulan bakanlık teklifini kabul etti.',p.kad,unvan),
   null,t);
 return jsonb_build_object('durum','kabul','bakanlik',b.ad,'makam_id',eski_makam);
end $function$
;

CREATE OR REPLACE FUNCTION public.cb_yardimcisi_yanit(p_teklif bigint, p_kabul boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); x oyun.cb_yardimcisi_teklifleri; m record; t timestamptz:=oyun.simdi(); mid bigint;
begin
 if p_kabul is null then raise exception 'Kabul veya ret seçmelisin.'; end if;
 select * into x from oyun.cb_yardimcisi_teklifleri where id=p_teklif;
 if x.id is null or x.aday<>p.id then raise exception 'Teklif sana ait değil.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('cb_yardimcisi'),x.sira);
 select * into x from oyun.cb_yardimcisi_teklifleri where id=p_teklif for update;
 if x.durum<>'bekliyor' then raise exception 'Teklif artık geçerli değil.'; end if;
 if not exists(select 1 from oyun.makamlar where user_id=x.teklif_eden and tur='cb' and bit is null)
 then raise exception 'Cumhurbaşkanı değiştiği için teklif geçersiz.'; end if;
 if not p_kabul then
  update oyun.cb_yardimcisi_teklifleri set durum='ret',yanit_at=t where id=x.id;
  perform oyun.bildir(x.teklif_eden,format('%s, %s. Cumhurbaşkanı Yardımcılığı teklifini reddetti.',p.kad,x.sira),t);
  return jsonb_build_object('durum','ret','sira',x.sira);
 end if;
 if p.yasakli then raise exception 'Yasaklı hesap görevi kabul edemez.'; end if;
 if exists(select 1 from oyun.makamlar where tur='cb_yardimcisi' and user_id=p.id and bit is null)
 then raise exception 'Zaten cumhurbaşkanı yardımcısısın.'; end if;
 for m in select id from oyun.makamlar where tur='cb_yardimcisi' and bakanlik=x.sira::text and bit is null loop
  perform oyun.makam_bitir(m.id,t,'gorevden_alindi');
 end loop;
 insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,kaynak,bas)
 values('cb_yardimcisi',p.id,null,p.parti_id,x.sira::text,'atama',t) returning id into mid;
 update oyun.cb_yardimcisi_teklifleri set durum='kabul',yanit_at=t where id=x.id;
 update oyun.cb_yardimcisi_teklifleri set durum='iptal',yanit_at=t
 where durum='bekliyor' and (sira=x.sira or aday=p.id);
 perform oyun.bildir(x.teklif_eden,format('%s, %s. Cumhurbaşkanı Yardımcılığı teklifini kabul etti.',p.kad,x.sira),t);
 perform oyun.bildir(p.id,format('%s. Cumhurbaşkanı Yardımcılığı görevin başladı. Milletvekilliği dahil bağdaşmayan eski görevlerin sona erer.',x.sira),t);
 perform oyun.olay('makam',format('%s, %s. Cumhurbaşkanı Yardımcısı olarak atandı.',p.kad,x.sira),null,p.parti_id,t);
 return jsonb_build_object('durum','kabul','sira',x.sira,'makam_id',mid);
end $function$
;

DROP TRIGGER IF EXISTS gorev_denetim_tg ON oyun.makamlar;
CREATE TRIGGER gorev_denetim_tg AFTER INSERT OR UPDATE OF bit ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun_yonetim.gorev_denetim_tg();

DROP TRIGGER IF EXISTS makam_tarih_koru_tg ON oyun.makamlar;
CREATE TRIGGER makam_tarih_koru_tg BEFORE INSERT OR UPDATE OF bas,bit ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun_yonetim.makam_tarih_koru_tg();

DROP TRIGGER IF EXISTS mv_adaylik_gorev_tg ON oyun.adaylar;
CREATE TRIGGER mv_adaylik_gorev_tg AFTER INSERT OR UPDATE OF secim_id,user_id ON oyun.adaylar
FOR EACH ROW EXECUTE FUNCTION oyun_yonetim.mv_adaylik_gorev_tg();

DROP TRIGGER IF EXISTS makam_bagdasmazlik_tg ON oyun.makamlar;
CREATE TRIGGER makam_bagdasmazlik_tg AFTER INSERT OR UPDATE OF bit,tur,user_id ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun_yonetim.makam_bagdasmazlik_tg();

DROP TRIGGER IF EXISTS cb_bakan_ayni_kisi_yasak_tg ON oyun.makamlar;
CREATE TRIGGER cb_bakan_ayni_kisi_yasak_tg BEFORE INSERT OR UPDATE OF tur,user_id,bit ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun_yonetim.cb_bakan_ayni_kisi_yasak_tg();


REVOKE ALL ON FUNCTION oyun_yonetim.gorev_denetim_tg() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION oyun_yonetim.mv_adaylik_gorev_tg() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION oyun_yonetim.makam_bagdasmazlik_tg() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.gorev_tercihi_bekleyen() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.gorev_tercihi_yap(bigint,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gorev_tercihi_bekleyen() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gorev_tercihi_yap(bigint,text) TO authenticated;
REVOKE ALL ON FUNCTION oyun.gorev_tercihi_tick() FROM PUBLIC,anon,authenticated;

DO $cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='gorev-tercihi-15gun') THEN
  PERFORM cron.schedule('gorev-tercihi-15gun','*/15 * * * *',
      'SELECT oyun.gorev_tercihi_tick()');
 END IF;
END $cron$;
