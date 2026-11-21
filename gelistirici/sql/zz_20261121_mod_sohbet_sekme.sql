-- 21.11.2026 · Sohbet bölümündeki "Mod" sekmesi (canlı migration: mod_sohbet_sekme_20261121)
-- İstemci, sekmeyi göstermek için nöbet yetkisini sorar. Yetkisiz hesapta hata vermez, false döner.
-- Sekme mevcut Sohbet nöbeti ekranını (mod_sohbet_nobeti) açar; yeni görme yetkisi vermez.
create or replace function public.mod_sohbet_sekme()
returns jsonb language sql stable security definer set search_path to '' as $fn$
  select jsonb_build_object(
    'nobet', auth.uid() is not null and oyun.yetkili(auth.uid(), 'sikayet'),
    'tum',   auth.uid() is not null and oyun.yetkili(auth.uid(), 'sohbet_tum'))
$fn$;
revoke all on function public.mod_sohbet_sekme() from public, anon;
grant execute on function public.mod_sohbet_sekme() to authenticated, service_role;
