-- Marka kaydinda kolon adiyla ayni olan kategori degiskenini ayir.
do $patch$
declare source text;
begin
 select pg_get_functiondef('public.eko_ticaret_islem(text,jsonb)'::regprocedure) into source;
 source:=replace(source,'kategori text:=','v_kategori text:=');
 source:=replace(source,'kategori not in (','v_kategori not in (');
 source:=replace(source,'m.kategori<>kategori','m.kategori<>v_kategori');
 source:=replace(source,'magaza_kategori=kategori','magaza_kategori=v_kategori');
 source:=replace(source,'set kategori=kategori,','set kategori=v_kategori,');
 source:=replace(source,'''kategori'',kategori','''kategori'',v_kategori');
 execute source;
end $patch$;