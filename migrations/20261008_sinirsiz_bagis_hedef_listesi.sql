-- Tüm oyuncuların seçebileceği kamuya açık bağış alıcıları.
-- Başka oyuncuların özel mali verileri açıklanmaz.
create or replace function public.bagis_hedefleri()
returns jsonb language plpgsql security definer set search_path='' as $f$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;
 return jsonb_build_object(
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad,'kisa',kisa)
    order by ad) from oyun.partiler where not kapali),'[]'::jsonb),
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad)
    order by ad) from oyun.sirketler where aktif),'[]'::jsonb),
 'gazeteler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad)
    order by ad) from oyun.oyuncu_gazeteleri where aktif),'[]'::jsonb),
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad)
    order by ad) from oyun.iller),'[]'::jsonb));
end $f$;
revoke all on function public.bagis_hedefleri() from public,anon;
grant execute on function public.bagis_hedefleri() to authenticated;
