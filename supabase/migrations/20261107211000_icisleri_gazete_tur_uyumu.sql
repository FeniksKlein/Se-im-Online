-- Resmî Gazete tur alanı yalnız tanımlı türleri kabul eder.
-- İçişleri resmi duyurularını 'duyuru' sınıfıyla yayınla (mevcut CHECK korunur).
DO $fix$ DECLARE x record; s text; n integer:=0;
BEGIN
 FOR x IN
  SELECT p.oid FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
  WHERE ns.nspname='public' AND p.proname LIKE 'icisleri_%'
    AND pg_get_functiondef(p.oid) LIKE '%gazete_ekle(''icisleri''%'
 LOOP
  s:=pg_get_functiondef(x.oid);
  s:=replace(s,'oyun.gazete_ekle(''icisleri'',','oyun.gazete_ekle(''duyuru'',');
  EXECUTE s;
  n:=n+1;
 END LOOP;
 IF n<7 THEN RAISE EXCEPTION 'Beklenen resmi duyuru bağlantıları bulunamadı: %',n; END IF;
END $fix$;
