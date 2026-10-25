-- Kişisel yatırım kasası. Mevcut pozisyonları taşımadan veya nakde çevirmeden okur.
create or replace function public.yatirim_kasam() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); a jsonb; nakit numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then
  raise exception 'Oturum gerekli';
 end if;
 perform oyun.piyasa_guncelle();
 select para into nakit from oyun.cuzdan where user_id=u;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.kaynak,x.ad),'[]'::jsonb) into a from (
  select 'piyasa'::text kaynak, p.kod, v.ad, v.sinif, p.miktar,
   v.fiyat, round(p.miktar*v.fiyat,2) deger, p.maliyet,
   round(p.miktar*v.fiyat-p.maliyet,2) kar, v.aktif islem_acik,
   v.saat fiyat_zamani, false eski, null::bigint sirket_id,
   'Yatırım borsası'::text aciklama
  from oyun.piyasa_pozisyon p join oyun.piyasa_varlik v using(kod) where p.user_id=u and p.miktar>0
  union all
  select 'carsi',p.kod,case p.kod when 'ALTIN' then 'Gram altın' else p.kod end,
   case when p.kod='ALTIN' then 'altin' else 'doviz' end,p.miktar,k.fiyat,
   round(p.miktar*k.fiyat,2),null::numeric,null::numeric,
   coalesce(k.guncelleme>=now()-interval '20 minutes',false),k.guncelleme,
   coalesce(k.guncelleme<now()-interval '20 minutes',true),null::bigint,'Kuyumcu / döviz ofisi'
  from oyun.meslek_portfoy p left join oyun.meslek_kur k using(kod) where p.user_id=u and p.miktar>0
  union all
  select 'sirket',s.id::text,s.ad,'hisse',o.pay,
   case when s.aktif then oyun.borsa_son_fiyat(s.id) else null end,
   case when s.aktif then round(o.pay*oyun.borsa_son_fiyat(s.id),2) else null end,
   null::numeric,null::numeric,s.aktif and s.halka_acik,null::timestamptz,false,s.id,
   case when not s.aktif then 'Şirket faal değil; değer hesaplanmadı' when s.halka_acik then 'Borsada işlem gören şirket payı' else 'Halka açık olmayan şirket payı; tahmini değer' end
  from oyun.sirket_ortaklari o join oyun.sirketler s on s.id=o.sirket_id where o.user_id=u and o.pay>0
 ) x;
 return jsonb_build_object('nakit',coalesce(nakit,0),'varliklar',a,'zaman',now(),
  'yatirim_degeri',(select coalesce(sum((v->>'deger')::numeric),0) from jsonb_array_elements(a) v),
  'eksik_deger',(select count(*) from jsonb_array_elements(a) v where v->>'deger' is null));
end $$;
revoke all on function public.yatirim_kasam() from public,anon;
grant execute on function public.yatirim_kasam() to authenticated;
