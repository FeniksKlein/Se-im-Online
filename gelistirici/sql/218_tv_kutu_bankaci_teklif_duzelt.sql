CREATE OR REPLACE FUNCTION public.tv_kutu_oyna(p_program bigint, p_islem text, p_kutu integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); g oyun.tv_kutu_oyun; pr oyun.tv_program;
 t timestamptz:=oyun.simdi(); n integer; yeni_adet integer; ort numeric; katsayi numeric; v_teklif numeric; ham_odul numeric; hedef integer;
begin
 perform oyun.tv_program_guncelle(p_program);
 select * into g from oyun.tv_kutu_oyun where program_id=p_program for update;
 select * into pr from oyun.tv_program where id=p_program;
 if g.program_id is null or pr.tur<>'kutunu_sec' then raise exception 'Kutunu Seç oyunu bulunamadı.'; end if;
 if pr.durum<>'canli' or pr.bit<=t then raise exception 'Yarışma yayını sona erdi.'; end if;
 if g.yarismaci is null or g.yarismaci<>p.id then raise exception 'Hamleyi sadece seçilmiş yarışmacı yapabilir.'; end if;
 if not oyun.tv_kutu_uygun(g.kanal_id,p.id) then raise exception 'Yarışmacının ödül uygunluğu kalmadı.'; end if;
 n:=coalesce(array_length(g.acilan,1),0);
 if p_islem='sec' then
   if g.durum<>'secim' or (p_kutu is null or p_kutu not between 1 and 16) then raise exception 'Önce 1-16 arasında kendi kutunu seç.'; end if;
   update oyun.tv_kutu_oyun set secilen=p_kutu,durum='acilis',son_hamle=t where program_id=p_program;
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,kutu,zaman) values(p_program,p.id,'ana_kutu',p_kutu,t);
 elsif p_islem='ac' then
   if g.durum<>'acilis' or (p_kutu is null or p_kutu not between 1 and 16)
      or p_kutu=g.secilen or p_kutu=any(g.acilan) or n>=14 then raise exception 'Bu kutu açılamaz.'; end if;
   yeni_adet:=n+1;
   update oyun.tv_kutu_oyun set acilan=array_append(acilan,p_kutu),son_hamle=t where program_id=p_program;
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,kutu,tutar,zaman)
     values(p_program,p.id,'kutu_ac',p_kutu,g.degerler[p_kutu],t);
   if yeni_adet in (5,9,12,14) then
     select avg(g.degerler[i]) into ort from generate_series(1,16) i
       where i<>p_kutu and i<>all(g.acilan);
     katsayi:=case yeni_adet when 5 then 0.55 when 9 then 0.68 when 12 then 0.80 else 0.90 end;
     v_teklif:=least(50000,greatest(0,round(ort*katsayi/50)*50));
     update oyun.tv_kutu_oyun set durum='teklif',teklif=v_teklif,teklif_sayisi=teklif_sayisi+1 where program_id=p_program;
     insert into oyun.tv_kutu_hareket(program_id,user_id,islem,tutar,zaman)
       values(p_program,p.id,'bankaci_teklif',v_teklif,t);
   end if;
 elsif p_islem='kabul' then
   if g.durum<>'teklif' then raise exception 'Kabul edilecek bankacı teklifi yok.'; end if;
   perform oyun.tv_kutu_odeme(p_program,g.teklif,'bankacı teklifi kabul edildi');
 elsif p_islem='devam' then
   if g.durum<>'teklif' then raise exception 'Önce bankacı teklifini bekle.'; end if;
   update oyun.tv_kutu_oyun set durum=case when n=14 then 'final' else 'acilis' end,
     teklif=null,son_hamle=t where program_id=p_program;
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,zaman) values(p_program,p.id,'devam',t);
 elsif p_islem in ('tut','degistir') then
   if g.durum<>'final' or n<>14 then raise exception 'Final aşamasına henüz gelinmedi.'; end if;
   hedef:=g.secilen;
   if p_islem='degistir' then
     select i into hedef from generate_series(1,16) i where i<>g.secilen and i<>all(g.acilan) limit 1;
   end if;
   if hedef is null then raise exception 'Final kutusu bulunamadı.'; end if;
   ham_odul:=g.degerler[hedef];
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,kutu,tutar,zaman)
       values(p_program,p.id,p_islem,hedef,ham_odul,t);
   perform oyun.tv_kutu_odeme(p_program,ham_odul,
      case when p_islem='degistir' then 'finalde kutu değiştirildi' else 'finalde kendi kutusu seçildi' end);
 else raise exception 'Bilinmeyen yarışma hamlesi.'; end if;
 perform oyun.tv_sinyal(p_program);
 return public.tv_kutu_durum(p_program);
end $function$
