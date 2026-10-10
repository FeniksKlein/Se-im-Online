-- Parti sözcüsü herkesin görebildiği parti makamı; atamayı yalnız genel başkan yapar.
create or replace function public.parti_sozcu_bilgi(p_parti bigint)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'parti_id',pa.id,'sozcu',oyun.kad(s.user_id),
  'gb_miyim',pa.gb=auth.uid(),'genel_baskan',oyun.kad(pa.gb))
 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id
 where pa.id=p_parti and not pa.kapali and auth.uid() is not null;
$$;
revoke all on function public.parti_sozcu_bilgi(bigint) from public,anon;
grant execute on function public.parti_sozcu_bilgi(bigint) to authenticated;