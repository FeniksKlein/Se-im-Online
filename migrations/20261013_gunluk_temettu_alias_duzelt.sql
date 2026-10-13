-- Gunluk temettu func icindeki row degiskeni ile banka-mevduat alias cakismasini gider.
do $patch$
declare src text;
begin
 select pg_get_functiondef('public.eko_gunluk_kar_cek(bigint,numeric)'::regprocedure) into src;
 src:=replace(src,'sum(round(m.anapara*(1+m.faiz/100),2))',
 'sum(round(bm.anapara*(1+bm.faiz/100),2))');
 src:=replace(src,'from oyun.banka_mevduat m where m.banka_id=p_sirket and not m.kapandi',
 'from oyun.banka_mevduat bm where bm.banka_id=p_sirket and not bm.kapandi');
 execute src;
end $patch$;