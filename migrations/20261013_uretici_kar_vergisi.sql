-- Uretici toptan kazancini satis ani defterine yaz ve kurumlar vergisini tahsil et.
do $patch$
declare src text;
begin
 select pg_get_functiondef('oyun.eko_urun_toptan(bigint,bigint,text,integer,uuid)'::regprocedure) into src;
 if position('toptan_kar' in src)>0 then return;end if;
 src:=replace(src,'tutar numeric; fiyat numeric;',
   'tutar numeric; fiyat numeric; brt_kar numeric; kurumlar numeric; hareket bigint;');
 src:=replace(src,'tutar:=round(fiyat*p_adet);',
   'tutar:=round(fiyat*p_adet);
    brt_kar:=greatest(0,tutar-round(stok.maliyet_birim*p_adet));
    kurumlar:=oyun.eko_vergi_hesap(''kar'',brt_kar);');
 src:=replace(src,'kasa=kasa+tutar where id=p_uretici;',
   'kasa=kasa+tutar-kurumlar where id=p_uretici;');
 src:=replace(src,
  'values(p_magaza,p_uretici,p_islemci,''urun_tedarik'',-tutar,format(''%s x %s toptan alimi'',p_adet,p_urun));',
  'values(p_magaza,p_uretici,p_islemci,''urun_tedarik'',-tutar,format(''%s x %s toptan alimi'',p_adet,p_urun)) returning id into hareket;
   if oyun.eko_vergi_tahsil(p_uretici,''kar'',brt_kar,''toptan_kar'',hareket)<>kurumlar
   then raise exception ''Uretici kurumlar vergisi uyusmuyor.'';end if;
   perform oyun.eko_kar_yaz(p_uretici,''toptan'',hareket,tutar,kurumlar,
    tutar-round(stok.maliyet_birim*p_adet)-kurumlar,oyun.simdi());');
 execute src;
end $patch$;