-- Canlıya 21.11.2026'da Supabase migration'ı olarak uygulandı: (yardımcı işlev)
-- Kaynak: gelistirici/sql/zz_20261121_00_yama.sql · tekrar çalıştırmak güvenlidir.
begin;
set local lock_timeout = '5s';

-- 21.11.2026 · Yama yardımcısı (koşulsuz; 21.11 dosyalarından ÖNCE gelmeli)
-- Yama yardımcısı: pg_get_functiondef çıktısında tek ifadeyi değiştirir. İşaret zaten varsa ya da aranan ifade
-- bulunmazsa sessizce (uyarıyla) atlar; tam kurulumu durdurmaz.
create or replace function oyun._yama(p_fn text, p_desen text, p_yeni text, p_isaret text, p_duz boolean default false)
returns boolean language plpgsql set search_path to '' as $yama$
declare d text; y text; r regprocedure := to_regprocedure(p_fn);
begin
  if r is null then raise warning 'yama atlandı (işlev yok): %', p_fn; return false; end if;
  d := pg_get_functiondef(r);
  if position(p_isaret in d) > 0 then return false; end if;
  y := case when p_duz then replace(d, p_desen, p_yeni) else regexp_replace(d, p_desen, p_yeni, 'i') end;
  if y = d then raise warning 'yama atlandı (ifade bulunamadı): % [%]', p_fn, p_isaret; return false; end if;
  execute y;
  return true;
end $yama$;
revoke all on function oyun._yama(text,text,text,text,boolean) from public;

commit;
