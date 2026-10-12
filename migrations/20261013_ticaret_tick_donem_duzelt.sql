-- NPC satis tick fonksiyonundaki PL/pgSQL donem degiskenini unique constraint sutun adindan ayir.
do $patch$
declare source text;
begin
 select pg_get_functiondef('oyun.eko_ticaret_tick()'::regprocedure) into source;
 source:=replace(source,'donem timestamptz:=','v_donem timestamptz:=');
 source:=replace(source,'extract(epoch from donem)','extract(epoch from v_donem)');
 source:=replace(source,'values(mag.sirket_id,item.urun,donem,siparis','values(mag.sirket_id,item.urun,v_donem,siparis');
 execute source;
end $patch$;