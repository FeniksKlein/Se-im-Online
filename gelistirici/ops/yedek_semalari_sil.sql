-- YEDEK ŞEMA SİLME — ELLE, AYRI, GERİ DÖNÜŞÜ DUMP'TAN.
-- Bu dosya migration değildir, supabase-kurulum.sql içine girmez ve bu oturumda ÇALIŞTIRILMADI.
--
-- Sıra:
--   1. bash gelistirici/ops/yedek_semalari_disa_aktar.sh
--      Çıkan .sql dosyalarını açıp şema adlarını ve satır varlığını gözle kontrol edin.
--   2. Aşağıdaki SELECT'i çalıştırın (salt okunur). Başka şemadan yedek_* nesnesine
--      bağımlılık varsa DROP durur; önce onu kaldırın.
--   3. Dump'lar duruyor ve liste beklediğiniz şemalarsa, AYNI oturumda:
--        set yedek.silmeyi_onayliyorum = 'evet';
--      deyip bu dosyanın DO bloğunu çalıştırın.
--      Onay ayarı yoksa hiçbir DROP çalışmaz, işlem hata ile biter.
--   4. Geri alma: pg_dump dosyasını psql ile geri yükleyin
--        psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f yedek-semalar-.../yedek_....sql
--      CASCADE yalnız o şemanın içindeki nesneleri ve onlara bağlı olanları siler.
--      oyun / public / auth şemalarına dokunulmaz; betik önce çapraz bağımlılığı reddeder.
--
-- Kapsam: adı ^yedek_ ile eşleşen şemalar. yuk_testi ve oyun şeması silinmez.
-- 31 Ekim 2026'da canlıda beş şema vardı (dört yedek_2026... ve yedek_test_reset_20261008_0830).
-- Betik listeyi çalıştırma anında okur; yeni yedek_* şema da düşer. Çalıştırmadan önce SELECT'e bakın.

-- Adım 2: ne silinecek, başka şema bağlı mı?
select n.nspname,
       pg_size_pretty(coalesce((select sum(pg_total_relation_size(c.oid)) from pg_class c where c.relnamespace = n.oid), 0)) as boyut,
       (select count(*) from pg_class c where c.relnamespace = n.oid and c.relkind = 'r') as tablo,
       obj_description(n.oid, 'pg_namespace') as aciklama
from pg_namespace n
where n.nspname ~ '^yedek_'
order by 1;

-- Adım 3: ancak set yedek.silmeyi_onayliyorum = 'evet'; sonrası.
do $$
declare
  s text;
  bagli int;
begin
  if coalesce(current_setting('yedek.silmeyi_onayliyorum', true), '') is distinct from 'evet' then
    raise exception 'Silme kapalı. Önce pg_dump alın (gelistirici/ops/yedek_semalari_disa_aktar.sh). Sonra aynı oturumda: set yedek.silmeyi_onayliyorum = ''evet'';';
  end if;
  select count(*) into bagli
  from pg_depend d
  join pg_class c on c.oid = d.objid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_class rc on rc.oid = d.refobjid
  join pg_namespace rn on rn.oid = rc.relnamespace
  where rn.nspname ~ '^yedek_'
    and n.nspname !~ '^yedek_'
    and d.deptype = 'n';
  if bagli > 0 then
    raise exception 'Başka şemada yedek_* nesnesine bağlı % nesne var. DROP iptal.', bagli;
  end if;
  for s in select nspname from pg_namespace where nspname ~ '^yedek_' order by 1
  loop
    if s !~ '^yedek_[A-Za-z0-9_]+$' then
      raise exception 'Beklenmeyen şema adı: %', s;
    end if;
    raise notice 'DROP SCHEMA % CASCADE', s;
    execute format('drop schema %I cascade', s);
  end loop;
end $$;
