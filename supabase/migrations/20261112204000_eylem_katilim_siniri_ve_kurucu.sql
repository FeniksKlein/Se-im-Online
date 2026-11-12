-- 2026-11-12: İl bazlı oyuncu tavanını kaldır; organizatörü katılımcı say.
-- Mevcut eylemlerde daha önce ayrılmamış kurucuların eksik kayıtlarını tamamla.

CREATE OR REPLACE FUNCTION oyun.sokak_katilim_tavan()
RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $fn$
BEGIN
  -- İl tavanı sıfır aktif oyunculu şehirlerde katılımı tamamen engelliyordu.
  RETURN NEW;
END
$fn$;

DO $block$
DECLARE
  v_def text; v_start int; v_tail text; v_end int;
  v_needle text := ' if not exists(select 1 from oyun.sokak_eylem_destek where eylem_id=x.id and destekci_tur=p_kaynak';
BEGIN
  SELECT pg_get_functiondef('public.sokak_destek(bigint,text,text,bigint,numeric)'::regprocedure) INTO v_def;
  v_start := strpos(v_def, v_needle);
  IF v_start > 0 THEN
    v_tail := substr(v_def,v_start);
    v_end := strpos(v_tail,' end if;');
    IF v_end = 0 OR strpos(substr(v_tail,1,v_end),'>=a.orgut_es_zamanli_destek_siniri') = 0
    THEN RAISE EXCEPTION 'Eşzamanlı katılım sınırı güvenle bulunamadı'; END IF;
    v_def := substr(v_def,1,v_start-1) ||
       E' -- Eszamanli eylem katiliminda kisi siniri bulunmaz.\n' ||
       substr(v_def,v_start+v_end+length(' end if;')-1);
    EXECUTE v_def;
  ELSIF strpos(v_def,'>=a.orgut_es_zamanli_destek_siniri') > 0 THEN
    RAISE EXCEPTION 'Eşzamanlı katılım sınırı başka yerde: elle inceleyin';
  END IF;
END
$block$;

CREATE OR REPLACE FUNCTION oyun.sokak_kurucu_otomatik_katil()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
BEGIN
  IF NEW.baslatan IS NOT NULL THEN
    INSERT INTO oyun.sokak_eylem_destek
      (eylem_id,destekci_tur,destekci_id,taraf,temsilci,destek_turu,tutar)
    VALUES
      (NEW.id,'oyuncu',NEW.baslatan::text,'muhalefet',NEW.baslatan,'katilim',0)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END
$fn$;

REVOKE ALL ON FUNCTION oyun.sokak_kurucu_otomatik_katil() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sokak_kurucu_otomatik_katil ON oyun.sokak_eylem;
CREATE TRIGGER sokak_kurucu_otomatik_katil
AFTER INSERT ON oyun.sokak_eylem FOR EACH ROW
EXECUTE FUNCTION oyun.sokak_kurucu_otomatik_katil();

INSERT INTO oyun.sokak_eylem_destek
  (eylem_id,destekci_tur,destekci_id,taraf,temsilci,destek_turu,tutar)
SELECT e.id,'oyuncu',e.baslatan::text,'muhalefet',e.baslatan,'katilim',0
FROM oyun.sokak_eylem e
JOIN oyun.profiller p ON p.id=e.baslatan
WHERE e.durum='aktif' AND e.bitis>oyun.simdi()
  AND NOT EXISTS (
    SELECT 1 FROM oyun.sokak_eylem_destek d
    WHERE d.eylem_id=e.id AND d.destekci_tur='oyuncu'
      AND d.destekci_id=e.baslatan::text AND d.destek_turu='katilim'
  )
  AND NOT EXISTS (
    SELECT 1 FROM oyun.sokak_ayrilma a
    WHERE a.eylem_id=e.id AND a.user_id=e.baslatan AND a.rol='eylem'
  )
ON CONFLICT DO NOTHING;
