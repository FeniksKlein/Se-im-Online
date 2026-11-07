-- Duyuru türü uyumu: mahkeme kararları Resmi Gazete'nin geçerli duyuru kategorisinde.
DO $fix$
DECLARE s text;
BEGIN
 s:=pg_get_functiondef('public.icisleri_tedbir_karar(bigint,boolean,text)'::regprocedure);
 IF position('oyun.gazete_ekle(''icisleri'',' IN s)>0 THEN
  s:=replace(s,'oyun.gazete_ekle(''icisleri'',','oyun.gazete_ekle(''duyuru'',');
  EXECUTE s;
 END IF;
 IF position('oyun.gazete_ekle(''icisleri'',' IN pg_get_functiondef('public.icisleri_tedbir_karar(bigint,boolean,text)'::regprocedure))>0 THEN
  RAISE EXCEPTION 'Resmî Gazete türü geçersiz kaldı';
 END IF;
END $fix$;