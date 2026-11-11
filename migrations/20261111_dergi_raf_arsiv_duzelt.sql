-- 195: Kapatilan dergilerin satin alinmis sayilari ve sahip arsivi gizlilikle korunur.
create or replace function public.dergi_raf()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); sonuc jsonb;
begin
 if u is null then raise exception 'Oturum acman gerekiyor.'; end if;
 select jsonb_build_object(
  'kurulus_ucreti', oyun.gazete_kur_ucreti(),
  'azami_sayi_fiyat', 1000,
  'benim', (select jsonb_build_object('id',d.id,'ad',d.ad,'slogan',d.slogan,'kasa',d.kasa,
    'toplam_satis',(select coalesce(sum(s.satis),0) from oyun.karikatur_sayi s where s.dergi_id=d.id))
    from oyun.karikatur_dergi d where d.sahip=u and d.aktif limit 1),
  'dergiler', coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'ad',d.ad,'slogan',d.slogan,
    'sahip',coalesce(p.kad,'Oyuncu'),
    'sayi_sayisi',(select count(*) from oyun.karikatur_sayi s where s.dergi_id=d.id),
    'son_sayi',(select max(no) from oyun.karikatur_sayi s where s.dergi_id=d.id))
    order by d.kurulus desc) from oyun.karikatur_dergi d
    left join oyun.profiller p on p.id=d.sahip where d.aktif),'[]'::jsonb),
  'sayilar', coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'dergi_id',d.id,'dergi',d.ad,'no',s.no,'baslik',s.baslik,'fiyat',s.fiyat,
    'sablon',s.sayfalar->0->>'sablon',
    'sayfa_sayisi',jsonb_array_length(s.sayfalar),'yayin',s.yayin,'satis',s.satis,
    'sahibim',d.sahip=u,'satin_aldim',exists(select 1 from oyun.karikatur_satin_alma x where x.sayi_id=s.id and x.user_id=u)
    ) order by s.yayin desc)
    from oyun.karikatur_sayi s join oyun.karikatur_dergi d on d.id=s.dergi_id where d.aktif or d.sahip=u or exists (select 1 from oyun.karikatur_satin_alma x where x.sayi_id=s.id and x.user_id=u)),'[]'::jsonb)
 ) into sonuc;
 return sonuc;
end; $f$;

