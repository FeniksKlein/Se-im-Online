-- Bildirimlerde kaynağa tek dokunuşla ulaşma.
-- Mevcut bildirim metinlerini veya oyuncu kayıtlarını değiştirmez.
-- Kimliği doğrulanan oyuncu yalnız kendi bildirimlerinin bağlantısını alır.

create or replace function public.bildirim_hedefleri(p_idler bigint[])
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(es.bildirim_id::text,
      jsonb_build_object('tur', 'dernek_eylem', 'id', es.eylem_id)), '{}'::jsonb)
  from (
    select b.id as bildirim_id, bag.id as eylem_id
    from oyun.bildirimler b
    join lateral (
      select x.id
      from oyun.dernek_eylem x
      join oyun.dernekler d on d.id = x.dernek_id
      where not x.silindi
        and (
          x.zaman = b.zaman
          or (x.tur = 'protesto' and b.zaman >= x.bas and b.zaman <= x.bit)
        )
        and left(b.metin, char_length(d.ad)) = d.ad
        and strpos(b.metin, '“' || x.baslik || '”') > 0
      order by x.id desc
      limit 1
    ) bag on true
    where b.user_id = auth.uid()
      and b.id = any(coalesce(p_idler, array[]::bigint[]))
      and cardinality(p_idler) between 1 and 100
  ) es;
$$;

create or replace function public.dernek_eylem_oku(p_eylem bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select oyun.dernek_eylem_json(e, auth.uid(), oyun.simdi())
  from oyun.dernek_eylem e
  where e.id = p_eylem and not e.silindi and auth.uid() is not null;
$$;

revoke all on function public.bildirim_hedefleri(bigint[]) from public, anon;
revoke all on function public.dernek_eylem_oku(bigint) from public, anon;
grant execute on function public.bildirim_hedefleri(bigint[]) to authenticated;
grant execute on function public.dernek_eylem_oku(bigint) to authenticated;
