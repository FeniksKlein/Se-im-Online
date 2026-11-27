-- MANUEL ONARIM: Gecersiz 6 oyla verilen 15 Kasim erken secim karari, Ocak 2027 planini iptal etmis.
-- UYARI: YALNIZCA onayli bakim penceresinde, yedek ve test ortami denetiminden sonra calistirin.
-- Hicbir oy, kazanan, mevcut makam, kisi veya para kaydi degismez.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

CREATE TABLE IF NOT EXISTS oyun_yonetim.secim_takvim_onarim_audit(
 id bigint generated always as identity primary key,
 onarim text not null,
 eski jsonb not null,
 yeni jsonb not null,
 zaman timestamptz not null default now()
);
REVOKE ALL ON oyun_yonetim.secim_takvim_onarim_audit FROM PUBLIC,anon,authenticated;
ALTER TABLE oyun_yonetim.secim_takvim_onarim_audit ENABLE ROW LEVEL SECURITY;

DO $onarmak$
DECLARE eski jsonb; yeni jsonb; n integer; onay integer;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM oyun.erken_secim_teklifleri
                WHERE id=6 AND durum='ret') THEN
  RAISE EXCEPTION 'Erken secim #6 kesin reddedilmeden onarim yapilamaz';
 END IF;
 SELECT count(*) INTO onay FROM oyun.erken_secim_oylari WHERE teklif_id=6 AND oy='kabul';
 IF onay>=oyun.erken_secim_gerekli_oy() THEN RAISE EXCEPTION 'Erken secim #6 gecerli gorunuyor'; END IF;
 IF EXISTS (SELECT 1 FROM oyun.oylar o JOIN oyun.secimler s ON s.id=o.secim_id WHERE s.donem='2027-01')
 OR EXISTS (SELECT 1 FROM oyun.kazananlar k JOIN oyun.secimler s ON s.id=k.secim_id WHERE s.donem='2027-01')
 THEN RAISE EXCEPTION '2027-01 icin oy/kazanan var; geri acma guvenli degil'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.makamlar m JOIN oyun.secimler s ON s.id=m.secim_id WHERE s.donem='2027-01')
 THEN RAISE EXCEPTION '2027-01 secimiyle bagli makam mevcut; elle incele'; END IF;
 SELECT count(*) INTO n FROM oyun.secimler
 WHERE donem='2027-01' AND tur IN ('cb','cb_on','mv','mv_on')
   AND durum='tamam' AND sonuc->>'iptal'='erken_secim';
 IF n<>4 THEN RAISE EXCEPTION 'Beklenen 4 kayit yerine % kayit; elle incele',n; END IF;
 IF EXISTS (SELECT 1 FROM oyun.secimler WHERE donem='2027-01' AND tur IN ('cb','cb_on','mv','mv_on')
 AND (oy_bas<=oyun.simdi() OR (durum='tamam' AND sonuc->>'iptal'<>'erken_secim')))
 THEN RAISE EXCEPTION 'Gecmis veya farkli durumda 2027-01 secimi bulundu'; END IF;
 SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) INTO eski FROM oyun.secimler s
  WHERE donem='2027-01' AND tur IN ('cb','cb_on','mv','mv_on');
 UPDATE oyun.secimler SET durum='bekliyor',sonuc=NULL
  WHERE donem='2027-01' AND tur IN ('cb','cb_on','mv','mv_on')
   AND durum='tamam' AND sonuc->>'iptal'='erken_secim';
 SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) INTO yeni FROM oyun.secimler s
  WHERE donem='2027-01' AND tur IN ('cb','cb_on','mv','mv_on');
 INSERT INTO oyun_yonetim.secim_takvim_onarim_audit(onarim,eski,yeni)
 VALUES ('20261117_ocak_2027_dort_kayit',eski,yeni);
END $onarmak$;
COMMIT;
