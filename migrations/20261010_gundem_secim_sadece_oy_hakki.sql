-- 2026-10-10 · Gündem: dernek seçimleri sadece oy verebilecek üyelere.
-- Adaylık dönemi ve diğer derneklerin seçimleri gösterilmez.
begin;
create or replace function public.gundem_dernek_secimler()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id,
    'dernek_id', d.id,
    'ad', d.ad,
    'aday_bit', s.aday_bit,
    'oy_bit', s.oy_bit,
    'durum', s.durum
  ) order by s.oy_bit, s.id), '[]'::jsonb)
  from oyun.sos_dernek_secim s
  join oyun.dernekler d on d.id = s.dernek_id
  join oyun.dernek_uyeler uye on uye.dernek_id = d.id
    and uye.user_id = auth.uid()
    and uye.katilim <= s.bas
  where s.durum = 'acik'
    and s.aday_bit <= oyun.simdi()
    and s.oy_bit > oyun.simdi()
    and not d.kapali;
$$;
revoke all on function public.gundem_dernek_secimler() from public, anon, authenticated;
grant execute on function public.gundem_dernek_secimler() to authenticated;
commit;