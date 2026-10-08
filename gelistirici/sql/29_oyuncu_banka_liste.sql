create or replace function public.oyuncu_banka_liste()
returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object('bankalar',coalesce(jsonb_agg(jsonb_build_object('id',id,'ad',ad,'faiz',banka_faiz,'kasa',kasa) order by id),'[]'::jsonb))
 from oyun.sirketler where sektor='banka' and aktif
$$;
revoke all on function public.oyuncu_banka_liste() from public,anon;
grant execute on function public.oyuncu_banka_liste() to authenticated;
