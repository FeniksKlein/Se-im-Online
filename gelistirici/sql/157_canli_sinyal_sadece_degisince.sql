-- 157 (31.10.2026) — Canlı yenileme sinyali yalnız gerçek değişiklikte
-- Sorun (Ercan): oyun sayfayı sürekli yeniliyor, en üste atıyor, Kürsü'ye yazılan yarım kalıyor.
-- Neden: oyun_kontrol_sinyali.rev'i artıran tetikleyiciler "FOR EACH STATEMENT" idi; dakikalık bakım işleri
-- (engel süresi kontrolü, seçim motoru) hiçbir satırı değiştirmese bile her çalışmada sinyal yaydı (dakikada ~7).
-- Her sinyalde bağlı bütün cihazlar açık ana ekranı baştan çiziyordu.
-- Çözüm: tetikleyiciler satır düzeyinde ve yalnız ilgili sütun gerçekten değiştiğinde çalışır; aynı işlem içinde tek sinyal.

create or replace function oyun.uzaktan_sinyal_yay(p_tur text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_rev bigint;
begin
  -- Aynı veritabanı işleminde birden çok satır değişse de tek sinyal
  if current_setting('oyun.sinyal_yayildi', true) = '1' then return null; end if;
  perform set_config('oyun.sinyal_yayildi', '1', true);
  update public.oyun_kontrol_sinyali
     set rev = rev + 1, tur = left(coalesce(nullif(btrim(p_tur), ''), 'yonetim'), 40), zaman = now()
   where id = 1 returning rev into v_rev;
  return v_rev;
end $$;

create or replace trigger uzaktan_sinyal_engel after update of yasakli, engel_bitis on oyun.profiller
  for each row when (old.yasakli is distinct from new.yasakli or old.engel_bitis is distinct from new.engel_bitis)
  execute function oyun.uzaktan_sinyal_tetikle('engel');

create or replace trigger uzaktan_sinyal_secim after update of basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas, durum on oyun.secimler
  for each row when (old.basvuru_bas is distinct from new.basvuru_bas or old.basvuru_bit is distinct from new.basvuru_bit
    or old.oy_bas is distinct from new.oy_bas or old.oy_bit is distinct from new.oy_bit or old.sonuc_at is distinct from new.sonuc_at
    or old.goreve_bas is distinct from new.goreve_bas or old.durum is distinct from new.durum)
  execute function oyun.uzaktan_sinyal_tetikle('secim');
create or replace trigger uzaktan_sinyal_secim_ekle after insert or delete on oyun.secimler
  for each row execute function oyun.uzaktan_sinyal_tetikle('secim');

create or replace trigger uzaktan_sinyal_ayar after update on oyun.uygulama_ayar
  for each row when (old.* is distinct from new.*) execute function oyun.uzaktan_sinyal_tetikle('uygulama_ayari');
create or replace trigger uzaktan_sinyal_ayar_ekle after insert or delete on oyun.uygulama_ayar
  for each row execute function oyun.uzaktan_sinyal_tetikle('uygulama_ayari');

create or replace trigger uzaktan_sinyal_modul after update on oyun.uzaktan_modul_ayar
  for each row when (old.* is distinct from new.*) execute function oyun.uzaktan_sinyal_tetikle('modul');
create or replace trigger uzaktan_sinyal_modul_ekle after insert or delete on oyun.uzaktan_modul_ayar
  for each row execute function oyun.uzaktan_sinyal_tetikle('modul');

create or replace trigger uzaktan_sinyal_yonetici after insert on oyun.yk_degisiklik
  for each row execute function oyun.uzaktan_sinyal_tetikle('yonetici');
