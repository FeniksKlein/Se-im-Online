-- Mevcut sirketlerin eski birikmis kârlarini yok etme: gunluk kazanilmis ortak haklari rezervde kalirken eskiden birikmis kâr toplu dagitilabilir.
do $patch$
declare src text;
begin
 select pg_get_functiondef('public.sirket_kar_payi(bigint,numeric)'::regprocedure) into src;
 src:=replace(src,
  'if exists(select 1 from oyun.eko_isletmeler where sirket_id=p_sirket) then raise exception ''Gunluk ticaret kar payi icin Ekonomi > Vergi ve Temettu ekranini kullan.'';end if; ',
  '');
 if position('eko_ortak_gunluk_hak' in src)=0 then
  src:=replace(src,
   'update oyun.sirketler set kasa=kasa-p_tutar where id=p_sirket;',
   'if exists(select 1 from oyun.eko_isletmeler where sirket_id=p_sirket)
    and p_tutar > greatest(0,s.kasa-s.sermaye
      -coalesce((select sum(round(bm.anapara*(1+bm.faiz/100),2)) from oyun.banka_mevduat bm
                 where bm.banka_id=p_sirket and not bm.kapandi),0)
      -greatest(0,coalesce((select sum(h.hak-h.cekilen)
         from oyun.eko_ortak_gunluk_hak h where h.sirket_id=p_sirket),0))) then
     raise exception ''Gunluk ortak haklari sakli. Sadece onceki birikmis dagitilabilir kâr toplu dagitilabilir.'';
    end if;
    update oyun.sirketler set kasa=kasa-p_tutar where id=p_sirket;');
 end if;
 execute src;
end $patch$;