-- Seçim Simülasyonu Online: partilerin 81 ildeki güncel üye sayıları.
-- Salt okunur: Oyuncu hesabı, parti üyeliği ve seçim verilerini değiştirmez.
create or replace function public.parti_il_uyeleri(p_parti bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Üye dağılımını görmek için giriş yapmalısınız.'
      using errcode = '28000';
  end if;

  if not exists(select 1 from oyun.partiler where id = p_parti) then
    raise exception 'Parti bulunamadı.';
  end if;

  return (
    select jsonb_build_object(
      'parti_id', p_parti,
      'toplam', (select count(*) from oyun.profiller where parti_id = p_parti),
      'iller', coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', i.id,
              'ad', i.ad,
              'uye', coalesce(s.uye, 0)
            )
            order by i.ad
          )
          from oyun.iller i
          left join (
            select il_id, count(*) as uye
            from oyun.profiller
            where parti_id = p_parti
            group by il_id
          ) s on s.il_id = i.id
        ),
        '[]'::jsonb
      )
    )
  );
end;
$$;

revoke all on function public.parti_il_uyeleri(bigint) from public;
revoke execute on function public.parti_il_uyeleri(bigint) from anon;
grant execute on function public.parti_il_uyeleri(bigint) to authenticated;
