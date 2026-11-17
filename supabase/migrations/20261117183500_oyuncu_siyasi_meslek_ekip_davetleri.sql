-- Oyuncular arasi siyasi ekip/meslek sistemi (ilk surum).
-- Mevcut makam, para ve parti kayitlarini degistirmez. Ucret / kamu harcamasi yok.
CREATE TABLE IF NOT EXISTS oyun.siyasi_meslek_davet(
 id bigint generated always as identity primary key,
 tur text not null CHECK (tur IN ('mv_danismani','belediye_danismani','parti_kampanya','parti_organizasyon')),
 kurum_id bigint not null,
 davet_eden uuid not null references oyun.profiller(id),
 davet_edilen uuid not null references oyun.profiller(id),
 durum text not null default 'bekliyor' CHECK (durum IN ('bekliyor','kabul','ret','iptal','sure_doldu')),
 olusturma timestamptz not null default now(),
 bitis timestamptz not null default (now()+interval '48 hours'),
 cevap_at timestamptz,
 CHECK (davet_eden<>davet_edilen)
);
CREATE UNIQUE INDEX IF NOT EXISTS siyasi_meslek_davet_tekrar
 ON oyun.siyasi_meslek_davet(davet_eden,davet_edilen,tur,kurum_id) WHERE durum='bekliyor';
CREATE INDEX IF NOT EXISTS siyasi_meslek_davet_alici
 ON oyun.siyasi_meslek_davet(davet_edilen,durum,olusturma DESC);
CREATE TABLE IF NOT EXISTS oyun.siyasi_meslek_gorev(
 id bigint generated always as identity primary key,
 tur text not null CHECK (tur IN ('mv_danismani','belediye_danismani','parti_kampanya','parti_organizasyon')),
 kurum_id bigint not null,
 calisan uuid not null references oyun.profiller(id),
 atayan uuid not null references oyun.profiller(id),
 bas timestamptz not null default now(),
 bit timestamptz,
 bitis_neden text
);
CREATE UNIQUE INDEX IF NOT EXISTS siyasi_meslek_aktif_tekil
 ON oyun.siyasi_meslek_gorev(tur,kurum_id,calisan) WHERE bit IS NULL;
CREATE INDEX IF NOT EXISTS siyasi_meslek_gorev_aktif
 ON oyun.siyasi_meslek_gorev(calisan,bas DESC) WHERE bit IS NULL;
REVOKE ALL ON oyun.siyasi_meslek_davet,oyun.siyasi_meslek_gorev FROM PUBLIC,anon,authenticated;
ALTER TABLE oyun.siyasi_meslek_davet ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.siyasi_meslek_gorev ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION oyun.siyasi_meslek_atama_yetkisi(
 p_veren uuid,p_tur text,p_kurum bigint
) RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $fun$
 SELECT CASE
  WHEN p_tur='mv_danismani' THEN EXISTS(
    SELECT 1 FROM oyun.makamlar m WHERE m.id=p_kurum AND m.tur='mv'
     AND m.user_id=p_veren AND m.bit IS NULL AND m.bas<=oyun.simdi())
  WHEN p_tur='belediye_danismani' THEN EXISTS(
    SELECT 1 FROM oyun.makamlar m WHERE m.id=p_kurum AND m.tur='bel'
     AND m.user_id=p_veren AND m.bit IS NULL AND m.bas<=oyun.simdi())
  WHEN p_tur IN ('parti_kampanya','parti_organizasyon') THEN EXISTS(
    SELECT 1 FROM oyun.partiler p WHERE p.id=p_kurum AND p.gb=p_veren AND NOT p.kapali)
  ELSE false END
$fun$;
REVOKE ALL ON FUNCTION oyun.siyasi_meslek_atama_yetkisi(uuid,text,bigint) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.siyasi_meslek_davet_gonder(
 p_tur text,p_kurum bigint,p_kullanici text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fun$
DECLARE veren uuid:=auth.uid(); hedef oyun.profiller; n integer; d bigint;
BEGIN
 IF veren IS NULL THEN RAISE EXCEPTION 'Giris gerekli'; END IF;
 IF NOT oyun.siyasi_meslek_atama_yetkisi(veren,p_tur,p_kurum) THEN RAISE EXCEPTION 'Bu kurumda davet yetkin yok'; END IF;
 hedef:=oyun.profil_bul(p_kullanici);
 IF hedef.id IS NULL OR hedef.yasakli OR hedef.id=veren THEN RAISE EXCEPTION 'Uygun oyuncu bulunamadi'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.siyasi_meslek_gorev g WHERE g.calisan=hedef.id
 AND g.tur=p_tur AND g.kurum_id=p_kurum AND g.bit IS NULL) THEN RAISE EXCEPTION 'Oyuncu zaten bu gorevde'; END IF;
 SELECT count(*) INTO n FROM oyun.siyasi_meslek_gorev g WHERE g.tur=p_tur AND g.kurum_id=p_kurum AND g.bit IS NULL;
 IF n >= CASE WHEN p_tur='mv_danismani' THEN 2 WHEN p_tur='belediye_danismani' THEN 3 ELSE 5 END
 THEN RAISE EXCEPTION 'Danisman/ekip kontenjani dolu'; END IF;
 INSERT INTO oyun.siyasi_meslek_davet(tur,kurum_id,davet_eden,davet_edilen)
 VALUES(p_tur,p_kurum,veren,hedef.id)
 ON CONFLICT(davet_eden,davet_edilen,tur,kurum_id) WHERE durum='bekliyor'
 DO UPDATE SET olusturma=excluded.olusturma,bitis=excluded.bitis
 RETURNING id INTO d;
 PERFORM oyun.bildir(hedef.id,'Siyasi ekip gorevi icin davetin var: '||p_tur||'. Kabul veya ret cevabi verebilirsin.');
 RETURN jsonb_build_object('tamam',true,'davet_id',d);
END $fun$;

CREATE OR REPLACE FUNCTION public.siyasi_meslek_davet_cevap(
 p_davet bigint,p_kabul boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fun$
DECLARE d oyun.siyasi_meslek_davet; n integer;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giris gerekli'; END IF;
 SELECT * INTO d FROM oyun.siyasi_meslek_davet WHERE id=p_davet FOR UPDATE;
 IF d.id IS NULL OR d.davet_edilen IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Davet bulunamadi'; END IF;
 IF d.durum<>'bekliyor' THEN RAISE EXCEPTION 'Davet daha once yanitlandi'; END IF;
 IF d.bitis < oyun.simdi() THEN
   UPDATE oyun.siyasi_meslek_davet SET durum='sure_doldu',cevap_at=oyun.simdi() WHERE id=d.id;
   RAISE EXCEPTION 'Davet suresi dolmus'; END IF;
 IF p_kabul THEN
   IF NOT oyun.siyasi_meslek_atama_yetkisi(d.davet_eden,d.tur,d.kurum_id) THEN
     RAISE EXCEPTION 'Davet eden oyuncunun bu gorev icin yetkisi kalmadi'; END IF;
   IF EXISTS(SELECT 1 FROM oyun.siyasi_meslek_gorev WHERE tur=d.tur AND kurum_id=d.kurum_id
     AND calisan=d.davet_edilen AND bit IS NULL) THEN RAISE EXCEPTION 'Zaten gorevdesin'; END IF;
   SELECT count(*) INTO n FROM oyun.siyasi_meslek_gorev WHERE tur=d.tur AND kurum_id=d.kurum_id AND bit IS NULL;
   IF n>=CASE WHEN d.tur='mv_danismani' THEN 2 WHEN d.tur='belediye_danismani' THEN 3 ELSE 5 END
    THEN RAISE EXCEPTION 'Ekip kontenjani dolmus'; END IF;
   INSERT INTO oyun.siyasi_meslek_gorev(tur,kurum_id,calisan,atayan)
    VALUES(d.tur,d.kurum_id,d.davet_edilen,d.davet_eden);
 END IF;
 UPDATE oyun.siyasi_meslek_davet SET durum=CASE WHEN p_kabul THEN 'kabul' ELSE 'ret' END,
 cevap_at=oyun.simdi() WHERE id=d.id;
 RETURN jsonb_build_object('tamam',true,'kabul',p_kabul,'meslek',d.tur);
END $fun$;

CREATE OR REPLACE FUNCTION public.siyasi_meslek_istifa(
 p_gorev bigint
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fun$
DECLARE n integer;
BEGIN
 UPDATE oyun.siyasi_meslek_gorev SET bit=oyun.simdi(),bitis_neden='istifa'
 WHERE id=p_gorev AND calisan=auth.uid() AND bit IS NULL;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Aktif gorev bulunamadi'; END IF;
 RETURN jsonb_build_object('tamam',true);
END $fun$;

CREATE OR REPLACE FUNCTION public.siyasi_mesleklerim() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $fun$
SELECT jsonb_build_object(
 'davetler',coalesce((SELECT jsonb_agg(jsonb_build_object('id',d.id,'tur',d.tur,'kurum',d.kurum_id,
   'veren',p.kad,'bitis',d.bitis) ORDER BY d.olusturma DESC)
   FROM oyun.siyasi_meslek_davet d JOIN oyun.profiller p ON p.id=d.davet_eden
   WHERE d.davet_edilen=auth.uid() AND d.durum='bekliyor' AND d.bitis>oyun.simdi()),'[]'::jsonb),
 'gorevler',coalesce((SELECT jsonb_agg(jsonb_build_object('id',g.id,'tur',g.tur,'kurum',g.kurum_id,
   'atanma',g.bas) ORDER BY g.bas DESC)
   FROM oyun.siyasi_meslek_gorev g WHERE g.calisan=auth.uid() AND g.bit IS NULL),'[]'::jsonb),
 'yetkiler',coalesce((SELECT jsonb_agg(jsonb_build_object('kurum',x.kurum,'tur',x.tur,'ad',x.ad)) FROM (
   SELECT m.id AS kurum,'mv_danismani'::text AS tur,'Milletvekili danışmanı'::text AS ad
   FROM oyun.makamlar m WHERE m.user_id=auth.uid() AND m.tur='mv' AND m.bit IS NULL
   UNION ALL SELECT m.id,'belediye_danismani','Belediye danışmanı'
   FROM oyun.makamlar m WHERE m.user_id=auth.uid() AND m.tur='bel' AND m.bit IS NULL
   UNION ALL SELECT p.id,'parti_kampanya','Parti kampanya ekibi'
   FROM oyun.partiler p WHERE p.gb=auth.uid() AND NOT p.kapali
   UNION ALL SELECT p.id,'parti_organizasyon','Parti organizasyon ekibi'
   FROM oyun.partiler p WHERE p.gb=auth.uid() AND NOT p.kapali
 ) x),'[]'::jsonb))
$fun$;

DO $grant$
BEGIN
 EXECUTE 'REVOKE ALL ON FUNCTION public.siyasi_meslek_davet_gonder(text,bigint,text) FROM PUBLIC,anon';
 EXECUTE 'REVOKE ALL ON FUNCTION public.siyasi_meslek_davet_cevap(bigint,boolean) FROM PUBLIC,anon';
 EXECUTE 'REVOKE ALL ON FUNCTION public.siyasi_meslek_istifa(bigint) FROM PUBLIC,anon';
 EXECUTE 'REVOKE ALL ON FUNCTION public.siyasi_mesleklerim() FROM PUBLIC,anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.siyasi_meslek_davet_gonder(text,bigint,text) TO authenticated';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.siyasi_meslek_davet_cevap(bigint,boolean) TO authenticated';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.siyasi_meslek_istifa(bigint) TO authenticated';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.siyasi_mesleklerim() TO authenticated';
END $grant$;

-- Eski siyasi makam bittiginde yalniz O makama bagli yeni danismanliklar sonlandirilir.
CREATE OR REPLACE FUNCTION oyun.siyasi_meslek_makam_sonlanma() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fun$
BEGIN
 IF OLD.bit IS NULL AND NEW.bit IS NOT NULL AND OLD.tur IN ('mv','bel') THEN
 UPDATE oyun.siyasi_meslek_gorev SET bit=NEW.bit,bitis_neden='bagli_makam_sona_erdi'
 WHERE kurum_id=OLD.id AND tur=CASE WHEN OLD.tur='mv' THEN 'mv_danismani'
 ELSE 'belediye_danismani' END AND bit IS NULL;
 END IF;
 RETURN NEW;
END $fun$;
DROP TRIGGER IF EXISTS siyasi_meslek_makam_sonlanma_tg ON oyun.makamlar;
CREATE TRIGGER siyasi_meslek_makam_sonlanma_tg AFTER UPDATE OF bit ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun.siyasi_meslek_makam_sonlanma();
