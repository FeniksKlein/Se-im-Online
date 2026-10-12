-- Panelde mevcut ortaklik yonetici yetkisi: en buyuk ortak >=50 olmasa da yetkili.
CREATE OR REPLACE FUNCTION public.eko_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris yapmalisin.';end if;
 return jsonb_build_object(
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad))
 from oyun.sirketler s where s.aktif and s.sektor<>'banka'),'[]'::jsonb),
 'benim',coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'ad',s.ad,'sektor',s.sektor,'tur',i.tur,'il',i.il_id,
    'urun',i.urun,'pay',o.pay,'yonetici',oyun.sirket_yonetici_mi(s.id,u),'kasa',s.kasa,'sermaye',s.sermaye,
    'stok',coalesce((select sum(st.adet) from oyun.eko_stok st where st.sirket_id=s.id),0),
    'uretim_fiyat',i.uretim_fiyat,'perakende_fiyat',i.perakende_fiyat))
  from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id and o.user_id=u
  left join oyun.eko_isletmeler i on i.sirket_id=s.id where s.aktif),'[]'::jsonb),
 'fabrikalar',coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'ad',s.ad,'urun',i.urun,'fiyat',i.uretim_fiyat,'stok',
    coalesce((select st.adet from oyun.eko_stok st where st.sirket_id=s.id and st.urun=i.urun),0)))
  from oyun.eko_isletmeler i join oyun.sirketler s on s.id=i.sirket_id
  where i.tur='fabrika' and s.aktif),'[]'::jsonb),
 'markalar',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'bedel',m.isim_hakki,'oran',m.komisyon))
  from oyun.eko_markalar m join oyun.sirketler s on s.id=m.sirket_id where s.aktif),'[]'::jsonb),
 'subeler',coalesce((select jsonb_agg(jsonb_build_object('sube',f.sube,'marka',s.ad,'oran',f.komisyon))
 from oyun.eko_franchise f join oyun.sirketler s on s.id=f.marka
 where f.sube in (select sirket_id from oyun.sirket_ortaklari where user_id=u)),'[]'::jsonb),
 'projeler',coalesce((select jsonb_agg(jsonb_build_object(
    'id',p.id,'sirket',s.ad,'sirket_id',s.id,'il',p.il_id,'tip',p.tip,'kalan',p.kalan,
    'birim_fiyat',p.birim_fiyat,'hazir',p.hazir))
  from oyun.eko_projeler p join oyun.sirketler s on s.id=p.sirket_id
  where p.kalan>0 and s.aktif),'[]'::jsonb),
 'sozlesmeler',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'satici',sa.ad,'alici',al.ad,
   'satici_id',sa.id,'alici_id',al.id,'konu',c.konu,'bedel',c.bedel,'durum',c.durum,'vade',c.vade))
 from oyun.eko_sozlesmeler c join oyun.sirketler sa on sa.id=c.satici join oyun.sirketler al on al.id=c.alici
 where (c.satici in (select sirket_id from oyun.sirket_ortaklari where user_id=u)
 or c.alici in (select sirket_id from oyun.sirket_ortaklari where user_id=u))
 and c.durum not in ('tamam','iptal')),'[]'::jsonb),
 'policeler',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'sirket',s.ad,
  'teminat',p.teminat,'prim',p.prim,'durum',p.durum,'bit',p.bit,'kontrol',p.kontrol))
 from oyun.eko_policeler p join oyun.sirketler s on s.id=p.sirket_id where p.musteri=u),'[]'::jsonb),
 'sigortalar',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa))
 from oyun.eko_isletmeler i join oyun.sirketler s on s.id=i.sirket_id where i.tur='sigorta' and s.aktif),'[]'::jsonb)
 );
end $function$;
