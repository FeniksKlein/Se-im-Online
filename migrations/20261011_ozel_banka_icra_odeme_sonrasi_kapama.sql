BEGIN;
CREATE OR REPLACE FUNCTION oyun.oyb_icra_kredi_tam_kapama()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF (new.kalan<=0 OR new.durum='odendi') AND (old.kalan>0 OR old.durum<>'odendi') THEN
  UPDATE oyun.oyb_icra SET durum='kapandi'
    WHERE kredi_id=new.id AND durum IN ('acik','kabul','itiraz');
  UPDATE oyun.oyb_icra_haciz h SET durum='iptal'
    WHERE h.durum='acik' AND EXISTS (
     SELECT 1 FROM oyun.oyb_icra i WHERE i.id=h.icra_id AND i.kredi_id=new.id
    );
 END IF;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS oyb_icra_kredi_kapama ON oyun.oyb_kredi;
CREATE TRIGGER oyb_icra_kredi_kapama
AFTER UPDATE OF kalan,durum ON oyun.oyb_kredi
FOR EACH ROW EXECUTE FUNCTION oyun.oyb_icra_kredi_tam_kapama();
COMMIT;