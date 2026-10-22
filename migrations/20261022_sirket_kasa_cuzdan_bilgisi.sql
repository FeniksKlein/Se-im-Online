-- Sadece oturum acan oyuncunun kendi mevcut cüzdan bakiyesi.
create or replace function public.sirket_kasa_bilgi()
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); bakiye numeric;
begin
 if uid is null then raise exception 'Oturum gerekli.'; end if;
 select coalesce(para,0) into bakiye from oyun.cuzdan where user_id=uid;
 return jsonb_build_object('bakiye',coalesce(bakiye,0));
end $$;
revoke all on function public.sirket_kasa_bilgi() from public,anon,authenticated;
grant execute on function public.sirket_kasa_bilgi() to authenticated;
