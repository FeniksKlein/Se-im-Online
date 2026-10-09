-- Şirket kurucusunu ve en büyük pay sahibini birbirinden ayır.
create or replace function public.sirket_vitrini()
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('sirketler',
 coalesce((select jsonb_agg(jsonb_build_object(
   'id',s.id,'ad',s.ad,'sektor',s.sektor,'kurucu',p.kad,
   'sahip',coalesce((select x.kad from oyun.sirket_ortaklari o join oyun.profiller x on x.id=o.user_id
       where o.sirket_id=s.id and o.pay>0 order by o.pay desc,o.user_id limit 1),p.kad),
   'sermaye',s.sermaye,'kasa',s.kasa,'kurulus',s.kurulus,
   'aktif',s.aktif,'satilik',s.satilik,
   'ortaklar',coalesce((select jsonb_agg(jsonb_build_object('kad',x.kad,'pay',o.pay) order by o.pay desc)
      from oyun.sirket_ortaklari o join oyun.profiller x on x.id=o.user_id where o.sirket_id=s.id),'[]'::jsonb),
   'toplam_gelir',coalesce((select sum(greatest(0,h.faaliyet_gelir)) from oyun.sirket_hareket h where h.sirket_id=s.id),0),
   'net_kazanc',coalesce((select sum(h.tutar) from oyun.sirket_hareket h where h.sirket_id=s.id and h.faaliyet_gelir is not null),0),
   'vergi',coalesce((select sum(h.vergi) from oyun.hesap_hareket h
      where h.tur='sirket' and h.vergi>0 and h.aciklama like 'Sirket #'||s.id::text||' %'),0)
 ) order by s.id) from oyun.sirketler s join oyun.profiller p on p.id=s.kurucu where s.aktif and s.sektor<>'banka'),'[]'::jsonb),
 'vergi_notu','Sadece kayda alınmış gerçek şirket kazancı vergileri gösterilir; eski faaliyetler için şirket vergisi kaydı bulunmayabilir.')
$$;

