
-- Legacy tarim companies also appear in farm panel; conversion stays permission-checked by existing economy API.
create or replace function public.uc_tarim_panel() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid();
begin
 perform oyun.profilim();
 return jsonb_build_object(
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,
 'il',coalesce(e.il_id,p.il_id),'bagli',e.sirket_id is not null,
 'tarla',coalesce(c.tarla,0),'hayvan',coalesce(c.hayvan,0),'son_sut',c.son_sut))
 from oyun.sirketler s
 join oyun.sirket_ortaklari o on o.sirket_id=s.id
 join oyun.profiller p on p.id=u
 left join oyun.eko_isletmeler e on e.sirket_id=s.id and e.tur='fabrika' and e.urun='gida'
 left join oyun.uc_ciftlik c on c.sirket_id=s.id
 where s.aktif and s.sektor='tarim' and o.user_id=u and o.pay>=50),'[]'::jsonb),
 'ekimler',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'sirket',x.sirket_id,
 'urun',x.urun,'tarla',x.tarla,'hazir',x.hazir,'verim',x.verim))
 from oyun.uc_ekimler x join oyun.sirket_ortaklari o on o.sirket_id=x.sirket_id
 where o.user_id=u and x.hasat is null),'[]'::jsonb),
 'stok',coalesce((select jsonb_agg(jsonb_build_object('urun',st.urun,'sirket',st.sirket_id,
 'adet',st.adet,'fiyat',st.satis_fiyati))
 from oyun.eko_urun_stok st join oyun.sirket_ortaklari o on o.sirket_id=st.sirket_id
 where o.user_id=u and st.urun like 'uc_%' and st.adet>0),'[]'::jsonb));
end $$;
revoke all on function public.uc_tarim_panel() from public,anon;
grant execute on function public.uc_tarim_panel() to authenticated;
