-- Ulke tablosunda vergi sutunu ile satis fonksiyonunun degiskeni ayni addaydi.
do $patch$
declare source text;
begin
 select pg_get_functiondef('oyun.eko_ticaret_tick()'::regprocedure) into source;
 source:=replace(source,'vergi numeric;','v_vergi numeric;');
 source:=replace(source,'vergi:=round(ciro*.05)','v_vergi:=round(ciro*.05)');
 source:=replace(source,'-vergi-','-v_vergi-');
 source:=replace(source,'personel,vergi,royalty','personel,v_vergi,royalty');
 source:=replace(source,'hazine=hazine+vergi','hazine=hazine+v_vergi');
 execute source;
end $patch$;