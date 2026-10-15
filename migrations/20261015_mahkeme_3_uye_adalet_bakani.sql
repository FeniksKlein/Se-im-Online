-- 15.10.2026 · Yüksek Mahkeme 3. üye = görevdeki Adalet Bakanı
-- 1. ve 2. üyenin makamı, görev süresi, oyu ve dava geçmişi korunur.
-- Eski mahkeme oyları, geçmiş kararlar ve bakanlık atama geçmişi silinmez.
BEGIN;
ALTER TABLE oyun.mahkeme_uye DROP CONSTRAINT IF EXISTS mahkeme_uye_kaynak_check;
ALTER TABLE oyun.mahkeme_uye ADD CONSTRAINT mahkeme_uye_kaynak_check
  CHECK (kaynak IN ('cb','meclis','adalet'));

CREATE OR REPLACE FUNCTION oyun.adalet_bakani_mahkeme_esitle()
RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE b uuid; atama timestamptz; onceki uuid; t timestamptz:=oyun.simdi();
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('adalet_bakani_mahkeme_esitle'));
  SELECT m.user_id,m.bas INTO b,atama
    FROM oyun.makamlar m
   WHERE m.tur='bakan' AND m.bakanlik='adalet' AND m.bit IS NULL
   ORDER BY m.bas DESC,m.id DESC LIMIT 1;
  SELECT user_id INTO onceki FROM oyun.mahkeme_uye WHERE sira=3 FOR UPDATE;
  UPDATE oyun.mahkeme_uye
     SET kaynak='adalet',user_id=b,atayan=NULL,bas=atama,gorev_bit=NULL,
         bos_since=CASE WHEN b IS NULL THEN t ELSE NULL END
   WHERE sira=3;
  IF onceki IS DISTINCT FROM b THEN
    INSERT INTO oyun.adliye_atama_kayit(yapan,eski,yeni,gerekce,zaman)
    VALUES(coalesce(b,onceki),onceki,b,'3. üyelik görevdeki Adalet Bakanına aittir.',t);
    IF b IS NOT NULL THEN
      PERFORM oyun.bildir(b,'Adalet Bakanı olarak Yüksek Mahkemenin 3. üyesi oldun. Bakanlık görevin bitince üyeliğin de sona erer.',t);
      PERFORM oyun.olay('adliye',format('%s, Adalet Bakanı sıfatıyla Yüksek Mahkemenin 3. üyesi oldu.',oyun.kad(b)),NULL,NULL,t);
    ELSE
      PERFORM oyun.olay('adliye','Adalet Bakanlığı boşaldı; Yüksek Mahkeme 3. üyeliği yeni bakanı bekliyor.',NULL,NULL,t);
    END IF;
  END IF;
END $f$;

CREATE OR REPLACE FUNCTION oyun.tg_adalet_bakani_mahkeme_esitle()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  IF TG_OP='INSERT' THEN
    IF NEW.tur='bakan' AND NEW.bakanlik='adalet' THEN PERFORM oyun.adalet_bakani_mahkeme_esitle(); END IF;
  ELSIF TG_OP='DELETE' THEN
    IF OLD.tur='bakan' AND OLD.bakanlik='adalet' THEN PERFORM oyun.adalet_bakani_mahkeme_esitle(); END IF;
  ELSE
    IF (NEW.tur='bakan' AND NEW.bakanlik='adalet')
       OR (OLD.tur='bakan' AND OLD.bakanlik='adalet')
    THEN PERFORM oyun.adalet_bakani_mahkeme_esitle(); END IF;
  END IF;
  RETURN NULL;
END $f$;
DROP TRIGGER IF EXISTS adalet_bakani_mahkeme_esitle ON oyun.makamlar;
CREATE TRIGGER adalet_bakani_mahkeme_esitle
AFTER INSERT OR UPDATE OF tur,bakanlik,bit,user_id OR DELETE ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun.tg_adalet_bakani_mahkeme_esitle();

-- Üçüncü üyeyi doğrudan yazan eski yollar yanlış kişiyi yerleştiremez.
CREATE OR REPLACE FUNCTION oyun.tg_mahkeme_adalet_koru()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE b uuid;
BEGIN
  IF NEW.sira=3 THEN
    SELECT m.user_id INTO b FROM oyun.makamlar m
     WHERE m.tur='bakan' AND m.bakanlik='adalet' AND m.bit IS NULL
     ORDER BY m.bas DESC,m.id DESC LIMIT 1;
    IF NEW.kaynak IS DISTINCT FROM 'adalet' OR NEW.user_id IS DISTINCT FROM b
       OR NEW.gorev_bit IS NOT NULL THEN
      RAISE EXCEPTION '3. üye yalnız görevdeki Adalet Bakanıdır.';
    END IF;
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS mahkeme_adalet_koru ON oyun.mahkeme_uye;
CREATE TRIGGER mahkeme_adalet_koru
BEFORE INSERT OR UPDATE ON oyun.mahkeme_uye
FOR EACH ROW EXECUTE FUNCTION oyun.tg_mahkeme_adalet_koru();

-- Tarihi oy kayıtlarını koru; yeni 3. üye oyları ve ayrı azil önerileri kabul edilmesin.
CREATE OR REPLACE FUNCTION oyun.tg_mahkeme_sira3_islem_koru()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  IF NEW.sira=3 THEN
    RAISE EXCEPTION 'Yüksek Mahkeme 3. üyesi Adalet Bakanıdır; ayrı seçim veya azil yapılamaz.';
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS mahkeme_3_secim_koru ON oyun.mahkeme_meclis_oy;
CREATE TRIGGER mahkeme_3_secim_koru BEFORE INSERT OR UPDATE ON oyun.mahkeme_meclis_oy
FOR EACH ROW EXECUTE FUNCTION oyun.tg_mahkeme_sira3_islem_koru();
DROP TRIGGER IF EXISTS mahkeme_3_azil_koru ON oyun.mahkeme_azil;
CREATE TRIGGER mahkeme_3_azil_koru BEFORE INSERT OR UPDATE ON oyun.mahkeme_azil
FOR EACH ROW EXECUTE FUNCTION oyun.tg_mahkeme_sira3_islem_koru();

-- Partisizlik ve başka makamda çalışmama şartı yalnız seçilen/atanan 1. ve 2. üye içindir.
CREATE OR REPLACE FUNCTION oyun.tg_yargic_parti()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  IF NEW.parti_id IS NOT NULL AND NEW.parti_id IS DISTINCT FROM OLD.parti_id
    AND EXISTS (SELECT 1 FROM oyun.mahkeme_uye WHERE sira IN (1,2) AND user_id=NEW.id)
  THEN RAISE EXCEPTION 'Yüksek Mahkemenin 1. ve 2. üyeleri partiye üye olamaz.'; END IF;
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION oyun.tg_yargic_makam()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
  IF NEW.bit IS NULL AND EXISTS (SELECT 1 FROM oyun.mahkeme_uye WHERE sira IN (1,2) AND user_id=NEW.user_id)
  THEN RAISE EXCEPTION 'Yüksek Mahkemenin 1. ve 2. üyeleri başka makam alamaz.'; END IF;
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION oyun.tg_aday_yasak()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE b timestamptz;
BEGIN
  IF EXISTS (SELECT 1 FROM oyun.mahkeme_uye WHERE sira IN (1,2) AND user_id=NEW.user_id)
  THEN RAISE EXCEPTION 'Yüksek Mahkemenin 1. ve 2. üyeleri aday olamaz.'; END IF;
  SELECT adaylik_yasagi_bitis INTO b FROM oyun.profiller WHERE id=NEW.user_id;
  IF b IS NOT NULL AND b>oyun.simdi() THEN
    RAISE EXCEPTION 'Mahkeme kararıyla % tarihine kadar aday olamazsın.',
      to_char(b AT TIME ZONE 'Europe/Istanbul','DD.MM.YYYY HH24:MI');
  END IF;
  RETURN NEW;
END $f$;

-- İlk uygulamada görevdeki Adalet Bakanı (15.10.2026: halilmutlu) üçüncü koltuğa geçer.
SELECT oyun.adalet_bakani_mahkeme_esitle();

-- Bakanlık değişiminde otomatik senkronizasyonu kontrol etmek için:
-- SELECT u.sira,u.kaynak,p.kad,u.gorev_bit
-- FROM oyun.mahkeme_uye u LEFT JOIN oyun.profiller p ON p.id=u.user_id ORDER BY u.sira;
COMMIT;
