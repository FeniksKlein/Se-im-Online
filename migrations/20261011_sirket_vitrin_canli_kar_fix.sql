-- Şirketlerim ekranı doğru rekabetçi pazar tahminini gösterir.
-- Sadece fonksiyon değişir; bakiye ve geçmiş kayıtlara dokunulmaz.
CREATE OR REPLACE FUNCTION public.sirket_liste()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid();x record;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 for x in select distinct s.id from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id where o.user_id=u and s.aktif loop perform oyun.sirket_hesapla(x.id);end loop;
 return jsonb_build_object('sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'sektor',s.sektor,'kasa',s.kasa,'sermaye',s.sermaye,'sonraki_kazanc',s.sonraki_kazanc,'dagitilabilir_kar',greatest(0,s.kasa-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=s.id and not m.kapandi),0)),'pay',o.pay,'satilik',s.satilik,'faiz',s.banka_faiz,'pazar_tahmin',
 case when exists(select 1 from oyun.pazar_sirket ps join oyun.pazar_sektor k on k.kod=s.sektor
 where ps.sirket_id=s.id) then oyun.pazar_tahmin(s.id) else null end)) from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id where o.user_id=u and s.aktif),'[]'::jsonb),
 'pazar',coalesce((select jsonb_agg(jsonb_build_object('id',s2.id,'ad',s2.ad,'sektor',s2.sektor,'fiyat',s2.satilik)) from oyun.sirketler s2 where s2.satilik is not null and s2.aktif),'[]'::jsonb),
 'teklifler',coalesce((select jsonb_agg(jsonb_build_object('id',st.id,'sirket_id',st.sirket_id,'pay',st.pay,'bedel',st.bedel)) from oyun.sirket_teklif st where st.alici=u and st.durum='bekliyor'),'[]'::jsonb),
 'asgari',(select ul.asgari from oyun.ulke ul where ul.id=1),
 'sirket_asgari_sermaye',100000,'banka_asgari_sermaye',1000000);
end $function$;
