-- 2026-10-10 | Gündem sayfasında aktif dernek genel kurulu seçimleri
-- Oyuncu verilerini değiştirmez; sadece açık seçimlerin genel bilgilerini döndürür.
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
  where s.durum = 'acik'
    and s.oy_bit > oyun.simdi()
    and not d.kapali;
$$;
revoke all on function public.gundem_dernek_secimler() from public, anon, authenticated;
grant execute on function public.gundem_dernek_secimler() to authenticated;
commit;