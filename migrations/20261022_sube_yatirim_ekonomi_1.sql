-- 22.10.2026 / Şubelerin yatırımı ve haftalık kârını bağlayan ortak ekonomik model.
-- Eski şubelere geriye dönük maliyet yüklenmez.
create or replace function oyun.sube_bolge_analiz(
 p_sirket bigint,p_il smallint,p_fiyat smallint default null,
 p_kalite smallint default null,p_an timestamptz default null)
returns jsonb language plpgsql stable set search_path='' as $$
declare
 s oyun.sirketler;ps oyun.pazar_sirket;k oyun.pazar_sektor;u oyun.ulke;
 zt timestamptz:=coalesce(p_an,oyun.simdi());
 vf smallint;vq smallint;price_factor numeric;macro numeric;policy_factor numeric;
 market_size numeric;mine numeric;other_comp numeric:=0;self_count int:=0;
 share_ratio numeric;demand numeric;capacity numeric;revenue numeric;
 wage numeric;fixed_cost numeric;stock numeric;cost numeric;
 sgk numeric;ts jsonb;competitors int:=0;tax_rate numeric;tax numeric;
 advertising numeric;license_rate numeric;lic_fees numeric;pre_tax numeric;net numeric;
 fitout numeric;deposit numeric;opening_stock numeric;training numeric;
 initial_permits numeric;cost_to_open numeric;operating_reserve numeric;
 years_weeks int;city_name text; sector_stock_ratio numeric;enterprise_cost_factor numeric;
begin
 select * into s from oyun.sirketler where id=p_sirket;
 select * into ps from oyun.pazar_sirket where sirket_id=p_sirket;
 select * into k from oyun.pazar_sektor where kod=s.sektor;
 select * into u from oyun.ulke where id=1;
 select ad into city_name from oyun.iller where id=p_il;
 if s.id is null or ps.sirket_id is null or k.kod is null or city_name is null then
  raise exception 'Şirketin veya ilin geçerli pazar bilgisi bulunamadı.';
 end if;
 vf:=coalesce(p_fiyat,ps.fiyat);
 vq:=coalesce(p_kalite,ps.kalite);
 price_factor:=oyun.pazar_fiyat_katsayi(vf);
 macro:=case when s.sektor in ('enerji','sanayi','insaat') then
  oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.06,0.7,1.4)
  else oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.03+
       (coalesce(u.memnuniyet,50)-50)*0.004,0.8,1.25) end;
 policy_factor:=oyun.sektor_pol_carpan(s.sektor,zt)*oyun.kriz_sektor_carpani(s.sektor,zt);
 market_size:=k.taban*oyun.pazar_il_agirlik(p_il)*macro*policy_factor;
 mine:=(1+0.35*vq+ps.marka/100.0)/power(price_factor,k.esneklik);
 select coalesce(sum((1+0.35*p2.kalite+p2.marka/100.0)/
   power(oyun.pazar_fiyat_katsayi(p2.fiyat),k.esneklik)),0),count(*)
 into other_comp,competitors
 from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id=p2.sirket_id
 where s2.aktif and s2.sektor=s.sektor and s2.id<>s.id
  and (p2.il_id=p_il or exists(
   select 1 from oyun.sirket_il_subeleri sb
    where sb.sirket_id=s2.id and sb.il_id=p_il and sb.acilis<=zt));
 -- Aynı şehirde şirketin mevcut merkezi de bölgesel müşteri talebini paylaşır.
 select (case when ps.il_id=p_il then 1 else 0 end)+count(*) into self_count
 from oyun.sirket_il_subeleri sb
 where sb.sirket_id=p_sirket and sb.il_id=p_il and sb.acilis<=zt;
 share_ratio:=mine/(k.dis*(0.85+least(greatest(
   coalesce((select kasa from oyun.bakanlik_kasa where kod=k.bakanlik),20),0),60)/100.0)
   +other_comp+mine*greatest(1,self_count));
 demand:=market_size*share_ratio;
 capacity:=greatest(15000,least(s.sermaye*k.kapasite*0.8,180000));
 revenue:=round(least(demand,capacity)*price_factor);
 ts:=oyun.bolge_tesvik(p_il);
 sgk:=coalesce((ts->>'sgk_destek')::numeric,0);
 wage:=round(coalesce(u.asgari,30000)/4.3*
    (1.35+0.25*k.personel+0.13*vq)*(1-sgk/100));
 fixed_cost:=round(greatest(2500,coalesce(u.asgari,30000)*0.12)*
    (0.8+least(3,oyun.pazar_il_agirlik(p_il))*0.15));
 sector_stock_ratio:=case
  when s.sektor='market' then 0.78
  when s.sektor in ('ticaret','e_ticaret','yapi_market','mobilya_magaza',
                  'elektronik_magaza','tekstil_magaza') then 0.63
  when s.sektor in ('akaryakit','oto_galeri') then 0.83
  when s.sektor in ('turizm','danismanlik','ozel_okul','ozel_hastane','oto_servis')
   then 0.28
  else 0.42 end;
 stock:=round(revenue*sector_stock_ratio);
 cost:=wage+fixed_cost+stock;
 advertising:=round(revenue*(array[0,0.015,0.03,0.05])[coalesce(ps.reklam,0)+1]);
 license_rate:=coalesce((select oran from oyun.il_ruhsat where il_id=p_il),0);
 lic_fees:=round(revenue*license_rate/100);
 pre_tax:=revenue-cost-advertising-lic_fees;
 tax_rate:=coalesce(nullif(oyun.eko_vergi_oran('kurumlar'),0),
                    (select kurumlar from oyun.pazar_ayar where id=1));
 tax:=round(greatest(0,pre_tax)*tax_rate/100*
    (1-coalesce((ts->>'vergi_indirim')::numeric,0)/100));
 net:=pre_tax-tax;

 enterprise_cost_factor:=case when s.sektor='market' then 0.90
   when s.sektor in ('ticaret','e_ticaret','tekstil_magaza','elektronik_magaza','mobilya_magaza','yapi_market') then 0.75
   when s.sektor in ('turizm','ozel_hastane','sanayi','enerji') then 1.80
   when s.sektor in ('akaryakit','oto_galeri') then 1.55
   else 1.10 end;
 fitout:=round(greatest(35000,revenue*enterprise_cost_factor));
 deposit:=round(fixed_cost*6);
 opening_stock:=round(stock*1.5);
 training:=round(wage*1.5);
 initial_permits:=round(greatest(6000,revenue*0.04));
 cost_to_open:=fitout+deposit+opening_stock+training+initial_permits;
 operating_reserve:=round(greatest(20000,(wage+fixed_cost+stock*0.28)*2));
 years_weeks:=case when net>0 then ceil(cost_to_open/net)::int else null end;
 return jsonb_build_object(
  'il_id',p_il,'il',city_name,'sektor',s.sektor,'sektor_ad',k.ad,
  'haftalik_ciro',revenue,'haftalik_personel',wage,'haftalik_sabit',fixed_cost,
  'haftalik_urun_maliyeti',stock,'haftalik_reklam',advertising,
  'haftalik_harc',lic_fees,'haftalik_vergi',tax,'haftalik_gider',cost+advertising+lic_fees+tax,
  'haftalik_net',net,'pay',round(share_ratio*100,1),'rakip',competitors,
  'dekorasyon_donanim',fitout,'depozito',deposit,'ilk_stok',opening_stock,
  'personel_hazirlik',training,'izin_ruhsat',initial_permits,
  'acilis_maliyeti',cost_to_open,'isletme_rezervi',operating_reserve,
  'gerekli_kasa',cost_to_open+operating_reserve,
  'geri_donus_hafta',years_weeks);
end $$;
revoke all on function oyun.sube_bolge_analiz(bigint,smallint,smallint,smallint,timestamptz)
 from public,anon,authenticated;
