-- Çevrimiçi oyuncular: genel sohbetle aynı 5 dakikalık eşik.
-- Yeni salt okunur RPC; oyuncu verisine dokunmaz.
create or replace function public.cevrimici_oyuncular()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t timestamptz := oyun.simdi();
  sonuc jsonb;
begin
  perform oyun.profilim();
  select jsonb_build_object(
    'cevrimici', count(*),
    'oyuncular', coalesce(jsonb_agg(
      jsonb_build_object(
        'kad', q.kad,
        'il', q.il_ad,
        'parti', q.parti_kisa,
        'renk', q.parti_renk
      ) order by lower(q.kad), q.kad
    ), '[]'::jsonb)
  )
  into sonuc
  from (
    select p.kad, il.ad as il_ad, pa.kisa as parti_kisa, pa.renk as parti_renk
    from oyun.profiller p
    left join oyun.iller il on il.id = p.il_id
    left join oyun.partiler pa on pa.id = p.parti_id
    where not p.yasakli and p.son_gorulme > t - interval '5 minutes'
  ) q;
  return sonuc;
end;
$$;
revoke all on function public.cevrimici_oyuncular() from public;
grant execute on function public.cevrimici_oyuncular() to authenticated;
