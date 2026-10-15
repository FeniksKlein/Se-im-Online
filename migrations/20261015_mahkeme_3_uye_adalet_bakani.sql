-- Yüksek Mahkeme'nin 3. üyesi, görevdeki Adalet Bakanıdır.
-- 1. başkan ve 2. üye korunur; 3. koltuk için ayrı seçim, istifa veya azil yoktur.
BEGIN;

ALTER TABLE oyun.mahkeme_uye DROP CONSTRAINT IF EXISTS mahkeme_uye_kaynak_check;
ALTER TABLE oyun.mahkeme_uye ADD CONSTRAINT mahkeme_uye_kaynak_check
  CHECK (kaynak IN ('cb', 'meclis', 'adalet'));

-- Bakanın görevi bittiğinde mahkeme üyeliği de aynı işlemde sona erer.
CREATE OR REPLACE FUNCTION oyun.adalet_bakani_mahkeme_esitle()
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  b_user uuid;
  b_bas timestamptz;
  onceki uuid;
  t timestamptz := oyun.simdi();
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('oyun.adalet_bakani_mahkeme_esitle'));
  SELECT m.user_id, m.bas INTO b_user,b_bas
  FROM oyun.makamlar m
  WHERE m.tur='bakan' AND m.bakanlik='adalet' AND m.bit IS NULL
  ORDER BY m.bas DESC, m.id DESC LIMIT 1;

  SELECT user_id INTO onceki FROM oyun.mahkeme_uye WHERE sira=3 FOR UPDATE;
  UPDATE oyun.mahkeme_uye
     SET kaynak='adalet', user_id=b_user, atayan=NULL,
         bas=CASE WHEN b_user IS NULL THEN NULL ELSE b_bas END,
         gorev_bit=NULL,
         bos_since=CASE WHEN b_user IS NULL THEN t ELSE NULL END
   WHERE sira=3;

  IF onceki IS DISTINCT FROM b_user THEN
    INSERT INTO oyun.adliye_atama_kayit(yapan, eski, yeni, gerekce, zaman)
    VALUES (coalesce(b_user, onceki), onceki, b_user,
            '3. üye Adalet Bakanlığı göreviyle otomatik belirlenir.', t);
    IF b_user IS NOT NULL THEN
      PERFORM oyun.bildir(b_user,
        'Adalet Bakanı olarak Yüksek Mahkeme 3. üyeliğini de üstlendin. Bakanlık görevin bitince bu üyelik de sona erecek.', t);
      PERFORM oyun.olay('adliye',format('%s, Adalet Bakanı olarak Yüksek Mahkeme 3. üyesi oldu.',oyun.kad(b_user)),NULL,NULL,t);
    ELSE
      PERFORM oyun.olay('adliye','Adalet Bakanlığı boşaldı; Yüksek Mahkeme 3. üyelik koltuğu yeni bakanı bekliyor.',NULL,NULL,t);
    END IF;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION oyun.tg_adalet_bakani_mahkeme_esitle()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    IF NEW.tur='bakan' AND NEW.bakanlik='adalet' THEN
      PERFORM oyun.adalet_bakani_mahkeme_esitle();
    END IF;
  ELSIF TG_OP='DELETE' THEN
    IF OLD.tur='bakan' AND OLD.bakanlik='adalet' THEN
      PERFORM oyun.adalet_bakani_mahkeme_esitle();
    END IF;
  ELSIF (NEW.tur='bakan' AND NEW.bakanlik='adalet')
        OR (OLD.tur='bakan' AND OLD.bakanlik='adalet') THEN
    PERFORM oyun.adalet_bakani_mahkeme_esitle();
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS adalet_bakani_mahkeme_esitle ON oyun.makamlar;
CREATE TRIGGER adalet_bakani_mahkeme_esitle
AFTER INSERT OR UPDATE OF tur,bakanlik,bit,user_id OR DELETE ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun.tg_adalet_bakani_mahkeme_esitle();

-- Bağımsız seçilen 1. ve 2. üyeler için mevcut parti/makam/adaylık yasakları sürer.
-- Bakanlıktan kaynaklanan 3. üyelik bunları devreye sokmaz.
CREATE OR REPLACE FUNCTION oyun.tg_yargic_parti()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.parti_id IS NOT NULL AND NEW.parti_id IS DISTINCT FROM OLD.parti_id
     AND EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=NEW.id AND sira IN (1,2)) THEN
    RAISE EXCEPTION 'Seçilmiş/atanmış yargıçlar görev süresince bir partiye üye olamaz.';
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION oyun.tg_yargic_makam()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.bit IS NULL
     AND EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=NEW.user_id AND sira IN (1,2)) THEN
    RAISE EXCEPTION 'Seçilmiş/atanmış yargıçlar görev süresince başka makamda görev alamaz.';
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION oyun.tg_aday_yasak()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE b timestamptz;
BEGIN
  IF EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=NEW.user_id AND sira IN (1,2)) THEN
    RAISE EXCEPTION 'Seçilmiş/atanmış yargıçlar görev süresince aday olamaz.';
  END IF;
  SELECT adaylik_yasagi_bitis INTO b FROM oyun.profiller WHERE id=NEW.user_id;
  IF b IS NOT NULL AND b > oyun.simdi() THEN
    RAISE EXCEPTION 'Mahkeme kararıyla % tarihine kadar aday olamazsın.',
      to_char(b AT TIME ZONE 'Europe/Istanbul','DD.MM.YYYY HH24:MI');
  END IF;
  RETURN NEW;
END $$;

-- Üçüncü koltuğun Meclis, Cumhurbaşkanı ya da eski yargıç akışlarıyla verilmesini engelle.
CREATE OR REPLACE FUNCTION oyun.mahkeme_oturt(p_sira smallint,u uuid,p_atayan uuid,t timestamptz)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF p_sira=3 THEN RAISE EXCEPTION '3. üye yalnızca görevdeki Adalet Bakanıdır.'; END IF;
  UPDATE oyun.mahkeme_uye SET user_id=u,atayan=p_atayan,bas=t,
     gorev_bit=t+make_interval(days=>(SELECT gorev_gun FROM oyun.mahkeme_ayar)),bos_since=NULL
     WHERE sira=p_sira;
  IF p_sira=1 THEN
    UPDATE oyun.adliye_makam SET hakim=u,atayan=p_atayan,atama_at=t,degistirme_at=t WHERE id=1;
  END IF;
  DELETE FROM oyun.mahkeme_meclis_oy WHERE sira=p_sira;
  INSERT INTO oyun.adliye_atama_kayit(yapan,eski,yeni,gerekce,zaman)
  VALUES(coalesce(p_atayan,u),NULL,u,
    CASE WHEN p_sira=1 THEN 'Cumhurbaşkanı ataması (mahkeme başkanı)' ELSE 'Meclis seçimi (2. üye)' END,t);
  PERFORM oyun.bildir(u,format('Yüksek Mahkeme %s. üyesi oldun. Görev süren %s gün; bu sürede partiye giremez, aday olamaz, başka makam alamazsın.',
    p_sira,(SELECT gorev_gun FROM oyun.mahkeme_ayar)),t);
  PERFORM oyun.olay('adliye',format('%s Yüksek Mahkeme %s. üyesi oldu (%s).',oyun.kad(u),p_sira,
    CASE WHEN p_sira=1 THEN 'Cumhurbaşkanı ataması' ELSE 'Meclis seçimi' END),NULL,NULL,t);
END $$;

CREATE OR REPLACE FUNCTION oyun.mahkeme_indir(p_sira smallint,p_yapan uuid,p_gerekce text,t timestamptz)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE u uuid;
BEGIN
  IF p_sira=3 THEN RAISE EXCEPTION '3. üyelik Adalet Bakanlığı göreviyle sona erer.'; END IF;
  SELECT user_id INTO u FROM oyun.mahkeme_uye WHERE sira=p_sira FOR UPDATE;
  IF u IS NULL THEN RETURN; END IF;
  UPDATE oyun.mahkeme_uye SET user_id=NULL,atayan=NULL,bas=NULL,gorev_bit=NULL,bos_since=t WHERE sira=p_sira;
  IF p_sira=1 THEN UPDATE oyun.adliye_makam SET hakim=NULL,atama_at=NULL,degistirme_at=t WHERE id=1; END IF;
  UPDATE oyun.mahkeme_azil SET durum='ret' WHERE uye=u AND durum='acik' AND p_gerekce NOT LIKE 'Meclis%';
  INSERT INTO oyun.adliye_atama_kayit(yapan,eski,yeni,gerekce,zaman)
  VALUES(coalesce(p_yapan,u),u,NULL,p_gerekce,t);
  PERFORM oyun.bildir(u,'Yüksek Mahkeme üyeliğin sona erdi: '||p_gerekce,t);
  PERFORM oyun.olay('adliye',format('%s Yüksek Mahkeme üyeliğinden ayrıldı: %s',oyun.kad(u),p_gerekce),NULL,NULL,t);
END $$;

CREATE OR REPLACE FUNCTION public.adliye_hakim_istifa()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p oyun.profiller:=oyun.profilim(); s smallint; t timestamptz:=oyun.simdi();
BEGIN
  SELECT sira INTO s FROM oyun.mahkeme_uye WHERE user_id=p.id;
  IF s IS NULL THEN RAISE EXCEPTION 'Yalnız görevdeki Yüksek Mahkeme üyeleri istifa edebilir.'; END IF;
  IF s=3 THEN RAISE EXCEPTION 'Adalet Bakanının 3. üyeliği ayrılmaz bir görevdir; bakanlık görevinden ayrılınca sona erer.'; END IF;
  PERFORM oyun.mahkeme_indir(s,p.id,'Kendi isteğiyle istifa etti.',t);
  RETURN jsonb_build_object('tamam',true);
END $$;

CREATE OR REPLACE FUNCTION public.mahkeme_meclis_oy(p_sira integer,p_kad text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); u oyun.profiller; engel text; n int;
BEGIN
  IF p_sira<>2 THEN RAISE EXCEPTION 'Meclis yalnız 2. Yüksek Mahkeme üyesini seçer; 3. üye Adalet Bakanıdır.'; END IF;
  IF NOT EXISTS(SELECT 1 FROM oyun.makamlar WHERE user_id=p.id AND tur='mv' AND bit IS NULL)
  THEN RAISE EXCEPTION 'Yalnız milletvekilleri oy verebilir.'; END IF;
  IF EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE sira=p_sira AND user_id IS NOT NULL)
  THEN RAISE EXCEPTION 'Bu koltuk dolu.'; END IF;
  SELECT * INTO u FROM oyun.profiller WHERE lower(kad)=lower(trim(coalesce(p_kad,''))) AND NOT yasakli;
  IF u.id IS NULL THEN RAISE EXCEPTION 'Aday bulunamadı.'; END IF;
  engel:=oyun.yargic_uygunluk(u.id);
  IF engel IS NOT NULL THEN RAISE EXCEPTION '%',engel; END IF;
  INSERT INTO oyun.mahkeme_meclis_oy(sira,vekil,aday,zaman)
  VALUES(p_sira,p.id,u.id,t)
  ON CONFLICT(sira,vekil) DO UPDATE SET aday=EXCLUDED.aday,zaman=EXCLUDED.zaman;
  SELECT count(*) INTO n FROM oyun.mahkeme_meclis_oy
  WHERE sira=p_sira AND aday=u.id
    AND EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.user_id=vekil AND m.tur='mv' AND m.bit IS NULL);
  IF n>=oyun.salt_cogunluk() THEN PERFORM oyun.mahkeme_oturt(p_sira::smallint,u.id,NULL,t); END IF;
  RETURN jsonb_build_object('tamam',true,'oy',n,'gerekli',oyun.salt_cogunluk(),'secildi',n>=oyun.salt_cogunluk());
END $$;

-- 3. üyeye karşı 3/5 mahkeme azli değil, bakanlık değişikliği uygulanır.
CREATE OR REPLACE FUNCTION oyun.tg_mahkeme_3_azil_koru()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.sira=3 THEN RAISE EXCEPTION '3. üye Adalet Bakanıdır; görev değişikliği bakanlık üzerinden yapılır.'; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS mahkeme_3_azil_koru ON oyun.mahkeme_azil;
CREATE TRIGGER mahkeme_3_azil_koru BEFORE INSERT OR UPDATE OF sira ON oyun.mahkeme_azil
FOR EACH ROW EXECUTE FUNCTION oyun.tg_mahkeme_3_azil_koru();

-- Açık üçüncü koltuk oyları artık seçime dönüşmeyecek; oy geçmişi silinmez.
UPDATE oyun.mahkeme_uye SET kaynak='adalet' WHERE sira=3;
SELECT oyun.adalet_bakani_mahkeme_esitle();
COMMIT;
