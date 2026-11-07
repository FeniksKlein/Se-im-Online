-- 2026-11-07: İçişleri ek panelinde "hakim" değişkeninin adliye_makam.hakim sütunuyla ad çakışmasını kaldır.
DO $do$ DECLARE s text;
BEGIN
 s:=pg_get_functiondef('public.icisleri_ek_panel()'::regprocedure);
 IF position('v_hakim boolean' IN s)=0 THEN
  IF position('hakim boolean' IN s)=0 THEN RAISE EXCEPTION 'Unexpected panel signature'; END IF;
  s:=replace(s,'hakim boolean','v_hakim boolean');
  s:=replace(s,' hakim:=EXISTS',' v_hakim:=EXISTS');
  s:=replace(s,'''hakim'',hakim','''hakim'',v_hakim');
  s:=replace(s,'(hakim AND durum','(v_hakim AND durum');
  EXECUTE s;
 END IF;
END $do$;
