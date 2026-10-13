-- Emlak satisindaki gecersiz PostgreSQL '+' karakter dizisi birlestirme operatorunu duzelt.
do $patch$
declare source text;
begin
 select pg_get_functiondef('public.eko_emlak_islem(text,jsonb)'::regprocedure) into source;
 source:=replace(source,'''Yeni ''+b.tur+'' alimi, %2 tapu harci''',
   '''Yeni ''||b.tur||'' alimi, %2 tapu harci''');
 execute source;
end $patch$;