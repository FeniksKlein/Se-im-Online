-- Sabit logaritma paydasini numeric yap; iki parametreli round() uyumlu olsun.
do $patch$
declare s text; fn regprocedure;
begin
 foreach fn in array array[
  'oyun.sokak_yenile(bigint)'::regprocedure,
  'public.sokak_finans_panel()'::regprocedure
 ] loop
  s:=pg_get_functiondef(fn);
  if position('ln(21)' in s)=0 then raise exception '% için fon hesabı bulunamadı',fn;end if;
  s:=replace(s,'ln(21)','ln(21::numeric)');
  execute s;
 end loop;
end $patch$;