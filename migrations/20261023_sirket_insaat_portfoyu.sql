-- 2026-10-23. Tek sirketin tum illerdeki arsa ve devam eden projelerini okuma paneli.
-- Guvenlik: yalnizca oturum acmis, faal sirkette hissesi bulunan ortaklar.
CREATE OR REPLACE FUNCTION public.sirket_insaat_portfoyu(p_sirket bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_u uuid := auth.uid();
begin
 if v_u is null then raise exception 'Oturum açmalısın.'; end if;
 if not exists (
  select 1 from oyun.sirket_ortaklari o
  join oyun.sirketler s on s.id=o.sirket_id
  where o.user_id=v_u and o.pay>0 and o.sirket_id=p_sirket and s.aktif
 ) then raise exception 'Bu şirketin bilgilerini görme yetkin yok.'; end if;
 if not exists (
  select 1 from oyun.eko_isletmeler ei where ei.sirket_id=p_sirket and ei.tur='insaat'
 ) then raise exception 'Bu şirket müteahhitlik şirketi değil.'; end if;
 return jsonb_build_object(
  'sirket_id',p_sirket,
  'arsalar',coalesce((
   select jsonb_agg(jsonb_build_object(
    'id',a.id,'il_id',a.il_id,'il',i.ad,'m2',a.alan_m2,
    'kapasite',a.kademe,'alis_bedeli',a.fiyat,'alis_zamani',a.alis_zamani
   ) order by a.alis_zamani desc nulls last,a.id desc)
   from oyun.eko_arsalar a
   join oyun.iller i on i.id=a.il_id
   where a.sahibi_sirket=p_sirket
   and not exists (select 1 from oyun.eko_yapilar y where y.arsa_id=a.id)
  ),'[]'::jsonb),
  'projeler',coalesce((
   select jsonb_agg(jsonb_build_object(
    'id',y.id,'ad',y.ad,'il_id',y.il_id,'il',i.ad,'arsa_id',y.arsa_id,
    'daire',y.daire_sayisi,'dukkan',y.dukkan_sayisi,
    'maliyet',y.maliyet,'baslangic',y.baslangic,'bitis',y.bitis,
    'tamamlandi',y.bitis<=oyun.simdi(),
    'satilan', (select count(*) from oyun.eko_bolumler bb where bb.yapi_id=y.id and bb.sahibi is not null),
    'bolumler',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',b.id,'tur',b.tur,'sira',b.sira,'m2',b.alan_m2,
        'fiyat',b.satis_fiyati,'satildi',b.sahibi is not null
      ) order by b.sira) from oyun.eko_bolumler b where b.yapi_id=y.id
    ),'[]'::jsonb)
   ) order by y.baslangic desc,y.id desc)
   from oyun.eko_yapilar y
   join oyun.iller i on i.id=y.il_id
   where y.sirket_id=p_sirket
  ),'[]'::jsonb)
 );
end;
$function$
;
REVOKE ALL ON FUNCTION public.sirket_insaat_portfoyu(bigint) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sirket_insaat_portfoyu(bigint) TO authenticated;
