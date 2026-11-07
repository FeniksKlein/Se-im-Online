-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 167) YÖNETİM PORTALI · TEK ADIMLI GİRİŞ
--  (07.11.2026)
--
--  Sahibin isteğiyle portalda doğrulama uygulaması (TOTP / aal2) şartı kaldırıldı.
--  Portal artık yalnız yönetici hesabının e-posta + şifresiyle açılır.
--    • oyun.yp_sahip(): yalnız "oyunun yöneticisi mi?" kontrolü kalır.
--    • p_taze_dk parametresi eski çağrılar bozulmasın diye durur ama yok sayılır.
--    • Kritik işlemlerdeki iki adım (ön izleme → onay metni) aynen sürer.
--
--  Oyuncu verisini değiştirmez; yalnız fonksiyonu yeniden tanımlar. İki kez çalışabilir.
-- =====================================================================

create or replace function oyun.yp_sahip(p_taze_dk integer default null)
returns oyun.profiller
language plpgsql
stable
set search_path to 'oyun', 'public', 'extensions', 'pg_temp'
as $$
declare
  p oyun.profiller := oyun.profilim();
begin
  if not coalesce(p.yonetici, false) then
    raise exception 'YP_YETKI: Bu portal yalnızca oyunun sahibine açıktır.';
  end if;
  return p;
end $$;
