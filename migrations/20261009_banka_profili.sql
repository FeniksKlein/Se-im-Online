-- Banka şubesi: şeffaf yönetim, sahiplik ve kredi/mevduat istatistikleri.
-- Yalnızca okur; mevcut finansal işlemleri ve bakiyeleri değiştirmez.
create or replace function public.oyb_banka_profili(p_banka bigint)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'id',s.id,'ad',s.ad,
  'kurucu',kur.kad,
  'ortaklar',coalesce((select jsonb_agg(jsonb_build_object('kad',u.kad,'pay',o.pay) order by o.pay desc,u.kad)
    from oyun.sirket_ortaklari o join oyun.profiller u on u.id=o.user_id
    where o.sirket_id=s.id and o.pay>0),'[]'::jsonb),
  'musteri_sayisi',(select count(distinct m.user_id) from oyun.banka_mevduat m where m.banka_id=s.id),
  'acik_mevduat_sayisi',(select count(*) from oyun.banka_mevduat m where m.banka_id=s.id and not m.kapandi),
  'acik_mevduat_anapara',coalesce((select sum(m.anapara) from oyun.banka_mevduat m where m.banka_id=s.id and not m.kapandi),0),
  'acik_mevduat_taahhut',coalesce((select sum(round(m.anapara*(1+m.faiz/100),2))
      from oyun.banka_mevduat m where m.banka_id=s.id and not m.kapandi),0),
  'aktif_kredi_sayisi',(select count(*) from oyun.oyb_kredi k where k.banka_id=s.id and k.durum in ('aktif','gecikmis')),
  'kredi_alacak',coalesce((select sum(k.kalan) from oyun.oyb_kredi k
    where k.banka_id=s.id and k.durum in ('aktif','gecikmis')),0),
  'bekleyen_kredi_basvurusu',(select count(*) from oyun.oyb_kredi k where k.banka_id=s.id and k.durum='basvuru')
 )
 from oyun.sirketler s join oyun.profiller kur on kur.id=s.kurucu
 where s.id=p_banka and s.sektor='banka' and s.aktif
$$;
revoke all on function public.oyb_banka_profili(bigint) from public,anon;
grant execute on function public.oyb_banka_profili(bigint) to authenticated;
