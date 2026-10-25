begin;
-- 25.10.2026: banka hesaplari ve sirket kâr tercihleri (yalnizca oturum sahibi).
create or replace function public.sirket_kar_tercihleri()
returns jsonb language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'sirket_id', o.sirket_id,
    'kar_kasada', o.kar_kasada
  ) order by o.sirket_id), '[]'::jsonb)
  from oyun.sirket_ortaklari o
  join oyun.sirketler s on s.id=o.sirket_id and s.aktif
  where o.user_id=auth.uid()
$$;
revoke all on function public.sirket_kar_tercihleri() from public, anon;
grant execute on function public.sirket_kar_tercihleri() to authenticated;

create or replace function public.internet_banka_hesaplarim()
returns jsonb language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'banka_id', h.banka_id,
    'ad', s.ad,
    'acilis', h.acilis
  ) order by s.ad), '[]'::jsonb)
  from oyun.oyb_hesap h
  join oyun.sirketler s on s.id=h.banka_id and s.aktif and s.sektor='banka'
  where h.user_id=auth.uid() and h.kapanis is null
$$;
revoke all on function public.internet_banka_hesaplarim() from public, anon;
grant execute on function public.internet_banka_hesaplarim() to authenticated;
commit;
