-- 10.10.2026 - Seçim Simülasyonu Online
-- Sahibi onaylı erişim güvenliği düzeltmesi.
-- Mevcut bütün hesapları, paraları, oyları, makamları korur.
-- Ön yedek: yedek_20261010_225932_484078
--
-- oyun şeması anon/authenticated rolüne USAGE vermiyor.
-- Doğrudan oyun tablosu SELECT/INSERT/UPDATE izni yok.
-- Oyun API'si public şemasındaki postgres sahibi SECURITY DEFINER RPC'ler üzerinden çalışıyor.
-- FORCE RLS UYGULAMA: sahip fonksiyonların çalışmasını bozabilir.
-- Sonradan şemaya yeni tablo eklenirse ayrıca RLS tanımlanmalı.
DO $rls$
DECLARE
  t record;
  n integer := 0;
BEGIN
  IF has_schema_privilege('anon','oyun','USAGE')
    OR has_schema_privilege('authenticated','oyun','USAGE')
  THEN
    RAISE EXCEPTION 'oyun şeması beklenmedik biçimde dışarıya açılmış; düzeltme durduruldu';
  END IF;
  IF EXISTS (
     SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
     WHERE s.nspname='oyun' AND c.relkind='r'
       AND NOT c.relrowsecurity AND c.relowner <> 'postgres'::regrole
  ) THEN
    RAISE EXCEPTION 'Sahibi postgres olmayan korumasız oyun tablosu bulundu; düzeltme durduruldu';
  END IF;
  FOR t IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
    WHERE s.nspname='oyun' AND c.relkind='r' AND NOT c.relrowsecurity
    ORDER BY c.relname
  LOOP
    EXECUTE format('ALTER TABLE oyun.%I ENABLE ROW LEVEL SECURITY',t.relname);
    n := n + 1;
  END LOOP;
  RAISE NOTICE '% oyun tablosunda RLS etkinleştirildi; mevcut roller ve politikalar değiştirilmedi', n;
END $rls$;
