do $$
declare src text;
begin
 select pg_get_functiondef('public.ib_hesap_ozet()'::regprocedure) into src;
 if position('select coalesce(cuzdan,0)' in src)=0 then raise exception 'Beklenen fonksiyon surumu bulunamadi'; end if;
 execute replace(src,'select coalesce(cuzdan,0)','select coalesce(para,0)');
end $$;