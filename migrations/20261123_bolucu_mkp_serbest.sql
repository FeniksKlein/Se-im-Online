-- 2026-11-23: "MKP" (kurucu parti: Millî Kalkınma Partisi) bölücü/küfür süzgecine takılıyordu.
-- 'mkp' tek kelime yasak listesinden çıkarıldı; terör örgütü adı tam yazımla ('maoistkomunist') yakalanmaya devam eder.
-- Canlı veritabanına uygulandı (Supabase migration: bolucu_mkp_serbest).
CREATE OR REPLACE FUNCTION oyun.bolucu_eslesen2(t text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  with s as (select oyun.sade_siki(t) sd,
                    regexp_split_to_array(btrim(regexp_replace(oyun.katla(t), '[^a-z0-9]+', ' ', 'g')), ' ') tk),
       g as (select sd, tk, translate(sd, '013457', 'oieast') lt from s),
       h as (select sd, tk, lt, regexp_replace(lt, '(.)\1+', '\1', 'g') tek from g)
  select coalesce(
    (select y from h, unnest(array[
      'kurdistan','pkk','pjak','qandil','kongragel','berxwedanjiyane','sehidnamirin','gerilla',
      'rojava','rojhilat','ozyonetim',
      'fetullah','fethullah','gulenist','bylock',
      'dhkpc','mlkp','tikko','devrimcikarargah','maoistkomunist',
      'elkaide','hilafetgelsin','hizbullah','ibdac','siegheil',
      'serokapo','bijiserok','apoyaozgurluk',
      'kahrolsunturkiye','kahrolsunlaik','kahrolsuncumhuriyet','seriatgelecek','seriatgelsin'
    ]) y
      where h.sd like '%' || y || '%' or h.lt like '%' || y || '%'
         or (char_length(regexp_replace(y, '(.)\1+', '\1', 'g')) >= 7 and h.tek like '%' || regexp_replace(y, '(.)\1+', '\1', 'g') || '%')
      limit 1),
    (select k from h, unnest(h.tk) k
      where k = any (array['apo','biji','kck','ypg','ypj','yja','pyd','hpg','feto',
                           'isid','deas','daes','dais','nazi','1488','bakur','gerila'])
         or translate(k, '013457', 'oieast') = any (array['apo','biji','feto','isid','nazi','bakur'])
         or k ~ '^(ocalan|hitler)' limit 1))
$function$;
