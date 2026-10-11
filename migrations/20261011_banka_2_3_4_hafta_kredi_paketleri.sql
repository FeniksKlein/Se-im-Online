BEGIN;
INSERT INTO oyun.oyb_kredi_urun(banka_id,saat,taksit_sayisi,ek_faiz,aktif)
SELECT s.id,v.saat,v.taksit,0,false FROM oyun.sirketler s
CROSS JOIN (VALUES (336::smallint,2::smallint),(504::smallint,3::smallint),(672::smallint,4::smallint))v(saat,taksit)
WHERE s.sektor='banka' ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION oyun.oyb_urun_bankaya_ekle()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF new.sektor='banka' THEN
  INSERT INTO oyun.oyb_kredi_urun(banka_id,saat,taksit_sayisi,ek_faiz,aktif)
  VALUES(new.id,24,1,0,true),(new.id,72,1,0,true),(new.id,168,2,0,true),
  (new.id,336,2,0,false),(new.id,504,3,0,false),(new.id,672,4,0,false)
  ON CONFLICT DO NOTHING;
 END IF;
 RETURN new;
END $$;
COMMIT;