-- Mikro odeme vergi yuvarlama arbitrajini engelle. Gunluk kar hakki 100 TL'ye ulasana kadar birikir.
do $patch$
declare src text;
begin
 select pg_get_functiondef('public.eko_gunluk_kar_cek(bigint,numeric)'::regprocedure) into src;
 src:=replace(src,
 'if net_alinabilir<1 then raise exception ''Onceki gunlerden nakit olarak cekilebilir net karin yok.'';end if;',
 'if net_alinabilir<100 then raise exception ''Gunluk kar birikimin veya nakit rezervin henuz 100 TL degil.'';end if;');
 src:=replace(src,
 'if odeme<>round(odeme) or odeme<1 or odeme>floor(net_alinabilir)',
 'if odeme<>round(odeme) or odeme<100 or odeme>floor(net_alinabilir)');
 execute src;
end $patch$;