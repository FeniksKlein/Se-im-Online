-- 2026-10-22: Ek sube cirosu - sehirlerin talebi, rekabeti, personel ve stok maliyeti

-- Ek subeler merkezden bagimsiz illerde gercek musteriler ve rakiplerle gelir uretir.
-- Kira/personel/stok giderleri sube basina ayri hesaplanir.
create or replace function oyun.sube_pazar_tahmin(
 p_sirket bigint, p_fiyat smallint default null, p_kalite smallint default null,
 p_an timestamptz default null)
returns jsonb language plpgsql stable set search_path='' as $$
declare
 s oyun.sirketler; ps oyun.pazar_sirket; k oyun.pazar_sektor; u oyun.ulke;
 b record; v_t timestamptz:=coalesce(p_an,oyun.simdi());
 v_f smallint; v_q smallint; v_makro numeric; v_pol numeric; v_pazar numeric;
 v_ben numeric; v_rakip numeric; v_pay numeric; v_talep numeric; v_kap numeric;
 v_gelir numeric; v_personel numeric; v_sabit numeric; v_stok numeric; v_gider numeric;
 v_gelir_top numeric:=0; v_gider_top numeric:=0; v_personel_top numeric:=0;
 v_sabit_top numeric:=0; v_stok_top numeric:=0; v_count int:=0;
 v_katsayi numeric; v_tes jsonb; v_sgk numeric; v_detay jsonb:='[]'::jsonb;
begin
 select * into s from oyun.sirketler where id=p_sirket;
 select * into ps from oyun.pazar_sirket where sirket_id=p_sirket;
 select * into k from oyun.pazar_sektor where kod=s.sektor;
 if s.id is null or ps.sirket_id is null or k.kod is null then
  return jsonb_build_object('sube_sayisi',0,'gelir',0,'gider',0,'sabit',0,'personel',0,'stok',0,'subeler','[]'::jsonb);
 end if;
 select * into u from oyun.ulke where id=1;
 v_f:=coalesce(p_fiyat,ps.fiyat);
 v_q:=coalesce(p_kalite,ps.kalite);
 v_makro:=case when s.sektor in ('enerji','sanayi','insaat') then
   oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.06,0.7,1.4)
   else oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.03+
   (coalesce(u.memnuniyet,50)-50)*0.004,0.8,1.25) end;
 v_pol:=oyun.sektor_pol_carpan(s.sektor,v_t)*oyun.kriz_sektor_carpani(s.sektor,v_t);
 v_katsayi:=oyun.pazar_fiyat_katsayi(v_f);
 v_ben:=(1+0.35*v_q+ps.marka/100.0)/power(v_katsayi,k.esneklik);
 for b in
  select sb.id,sb.il_id,i.ad from oyun.sirket_il_subeleri sb
  join oyun.iller i on i.id=sb.il_id
  where sb.sirket_id=p_sirket and sb.acilis<=v_t
  order by sb.il_id
 loop
  v_count:=v_count+1;
  v_pazar:=k.taban*oyun.pazar_il_agirlik(b.il_id)*v_makro*v_pol;
  select coalesce(sum((1+0.35*p2.kalite+p2.marka/100.0)/
     power(oyun.pazar_fiyat_katsayi(p2.fiyat),k.esneklik)),0)
  into v_rakip
  from oyun.pazar_sirket p2
  join oyun.sirketler s2 on s2.id=p2.sirket_id
  where s2.aktif and s2.id<>p_sirket and s2.sektor=s.sektor
    and (p2.il_id=b.il_id or exists(
      select 1 from oyun.sirket_il_subeleri bs
      where bs.sirket_id=s2.id and bs.il_id=b.il_id and bs.acilis<=v_t));
  v_pay:=v_ben/(k.dis*(0.85+least(greatest(
      (select kasa from oyun.bakanlik_kasa where kod=k.bakanlik),0),60)/100.0)
      +v_rakip+v_ben);
  v_talep:=v_pazar*v_pay;
  -- Haftalik bolgesel kapasite: sube yatirimi ve sirket sermayesiyle artar.
  v_kap:=greatest(15000,least(s.sermaye*k.kapasite*0.8,180000));
  v_gelir:=round(least(v_talep,v_kap)*v_katsayi);
  v_tes:=oyun.bolge_tesvik(b.il_id);
  v_sgk:=coalesce((v_tes->>'sgk_destek')::numeric,0);
  -- Personel aylik asgari ucretten haftaliga cevrilir; her subenin gideri ayri.
  v_personel:=round(coalesce(u.asgari,30000)/4.3*
    (1.35+0.25*k.personel+0.13*v_q)*(1-v_sgk/100));
  v_sabit:=round(greatest(2500,coalesce(u.asgari,30000)*0.12)*
    (0.8+least(3,oyun.pazar_il_agirlik(b.il_id))*0.15));
  -- Satis maliyeti: markette yuksek, hizmetlerde nispeten dusuk.
  v_stok:=round(v_gelir*(case when s.sektor='market' then 0.45
      when s.sektor in ('ticaret','e_ticaret','yapi_market','mobilya_magaza','elektronik_magaza','tekstil_magaza','oto_galeri') then 0.40
      when s.sektor in ('turizm','danismanlik','ozel_okul','ozel_hastane','oto_servis') then 0.24
      else 0.32 end));
  v_gider:=v_personel+v_sabit+v_stok;
  v_gelir_top:=v_gelir_top+v_gelir;
  v_gider_top:=v_gider_top+v_gider;
  v_personel_top:=v_personel_top+v_personel;
  v_sabit_top:=v_sabit_top+v_sabit;
  v_stok_top:=v_stok_top+v_stok;
  v_detay:=v_detay||jsonb_build_array(jsonb_build_object(
   'id',b.id,'il_id',b.il_id,'il',b.ad,'gelir',v_gelir,
   'personel',v_personel,'kira_enerji',v_sabit,'satis_maliyeti',v_stok,
   'gider',v_gider,'tahmini_net',v_gelir-v_gider,'pazar_payi',round(v_pay*100,1)));
 end loop;
 return jsonb_build_object(
  'sube_sayisi',v_count,'gelir',v_gelir_top,'gider',v_gider_top,
  'personel',v_personel_top,'sabit',v_sabit_top,'stok',v_stok_top,
  'subeler',v_detay);
end $$;
revoke all on function oyun.sube_pazar_tahmin(bigint,smallint,smallint,timestamptz)
 from public,anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.pazar_tahmin(p_sirket bigint, p_fiyat smallint DEFAULT NULL::smallint, p_kalite smallint DEFAULT NULL::smallint, p_kaynak text DEFAULT NULL::text, t timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare s oyun.sirketler; ps oyun.pazar_sirket; k oyun.pazar_sektor; u oyun.ulke; zt timestamptz := coalesce(t, oyun.simdi());
  v_f smallint; v_k smallint; v_kay text; w numeric; makro numeric; pol numeric; pazar numeric; dis numeric; kamu numeric;
  ben numeric; toplam numeric; pay numeric; gelir numeric; kap numeric; gider numeric; personel numeric; ruh numeric; ruhsat numeric;
  vergi numeric; net numeric; ceza numeric := 0; kalite_gid numeric; kaynak_gid numeric := 0; rakip int; usd numeric; pold text;
  sabit numeric; talep numeric; reklam_oran numeric; reklam numeric; tes jsonb; kv numeric; sgk numeric; brut numeric; v_sube jsonb;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  select * into k from oyun.pazar_sektor where kod = s.sektor;
  if s.id is null or ps.sirket_id is null or k.kod is null then return null; end if;
  select * into u from oyun.ulke where id = 1;
  v_f := coalesce(p_fiyat, ps.fiyat); v_k := coalesce(p_kalite, ps.kalite);
  v_kay := case when s.sektor = 'enerji' then coalesce(p_kaynak, ps.kaynak, 'dogalgaz') else null end;

  w := oyun.pazar_il_agirlik(ps.il_id);
  makro := case when s.sektor in ('enerji','sanayi','insaat') then oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.06, 0.7, 1.4)
                else oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.03 + (coalesce(u.memnuniyet, 50) - 50) * 0.004, 0.8, 1.25) end;
  pold := oyun.sektor_pol_durum(s.sektor, zt);
  pol := case pold when 'tesvik' then 1.15 when 'denetim' then 0.92 else 1 end;
  pazar := k.taban * w * makro * pol * oyun.kriz_sektor_carpani(s.sektor, zt);

  kamu := coalesce((select kasa from oyun.bakanlik_kasa where kod = k.bakanlik), 20);
  dis := k.dis * (0.85 + least(greatest(kamu, 0), 60) / 100.0);

  ben := (1 + 0.35 * v_k + ps.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(v_f), k.esneklik);
  select coalesce(sum((1 + 0.35 * p2.kalite + p2.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p2.fiyat), k.esneklik)), 0), count(*)
    into toplam, rakip
  from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
  where p2.il_id = ps.il_id and s2.sektor = s.sektor and s2.aktif and p2.sirket_id <> s.id;
  pay := ben / (dis + toplam + ben);
  kap := s.sermaye * k.kapasite;
  talep := pazar * pay;
  gelir := least(talep, kap) * oyun.pazar_fiyat_katsayi(v_f);

  tes := oyun.bolge_tesvik(ps.il_id);
  sgk := (tes->>'sgk_destek')::numeric;
  personel := coalesce(u.asgari, 30000) * k.personel * power(greatest(0.25, s.sermaye / 400000.0), 0.7) * (1 - sgk / 100);
  kalite_gid := s.sermaye * case v_k when 1 then 0.01 when 2 then 0.022 when 3 then 0.036 else 0 end;
  sabit := s.sermaye * k.sabit;
  if v_kay = 'komur' then sabit := sabit * 0.75;
  elsif v_kay = 'dogalgaz' then
    usd := coalesce((select fiyat from oyun.piyasa_varlik where kod = 'USD'), 42);
    kaynak_gid := s.sermaye * 0.015 * usd / 42.0;
  elsif v_kay = 'yenilenebilir' then sabit := sabit + s.sermaye * 0.02;
  end if;
  reklam_oran := (array[0, 0.015, 0.03, 0.05])[coalesce(ps.reklam, 0) + 1];
  -- Merkez faaliyetinin yanina her ek subenin kendi cirosu ve maliyeti eklenir.
  v_sube := oyun.sube_pazar_tahmin(p_sirket,v_f,v_k,zt);
  gelir := gelir + coalesce((v_sube->>'gelir')::numeric,0);
  sabit := sabit + coalesce((v_sube->>'sabit')::numeric,0);
  personel := personel + coalesce((v_sube->>'personel')::numeric,0);
  reklam := gelir * reklam_oran;
  gider := sabit + personel + kalite_gid + kaynak_gid + reklam
           + coalesce((v_sube->>'stok')::numeric,0);

  if pold = 'denetim' and (v_k = 0 or v_kay = 'komur') then ceza := gelir * 0.12; end if;
  ruh := coalesce((select oran from oyun.il_ruhsat where il_id = ps.il_id), 0);
  ruhsat := gelir * ruh / 100;
  brut := gelir - gider - ruhsat - ceza;
  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), (select kurumlar from oyun.pazar_ayar where id = 1));
  vergi := greatest(0, brut) * kv / 100 * (1 - (tes->>'vergi_indirim')::numeric / 100);
  net := brut - vergi;
  return jsonb_build_object('sube_sayisi',coalesce((v_sube->>'sube_sayisi')::int,0),
    'sube_gelir',coalesce((v_sube->>'gelir')::numeric,0),
    'sube_gider',coalesce((v_sube->>'gider')::numeric,0),
    'sube_detaylar',coalesce(v_sube->'subeler','[]'::jsonb),
    'pazar', round(pazar), 'pay', round(pay * 100, 1), 'rakip', rakip, 'gelir', round(gelir),
    'talep', round(talep), 'kapasite', round(kap), 'kapasite_dolu', talep >= kap - 1, 'gider', round(gider), 'personel', round(personel),
    'kalite_gider', round(kalite_gid), 'kaynak_gider', round(kaynak_gid), 'sabit', round(sabit), 'reklam', round(reklam),
    'reklam_seviye', coalesce(ps.reklam, 0),
    'ruhsat', round(ruhsat), 'ruhsat_oran', ruh, 'ceza', round(ceza), 'vergi', round(vergi), 'net', round(net),
    'gunluk_net', round(net / 7), 'kurumlar_orani', kv,
    'bolge', (tes->>'bolge')::int, 'vergi_indirim', (tes->>'vergi_indirim')::int, 'sgk_destek', (tes->>'sgk_destek')::int,
    'politika', pold, 'kamu_guc', round(dis, 2),
    'fiyat', v_f, 'kalite', v_k, 'kaynak', v_kay, 'getiri', round(net / s.sermaye * 100, 1));
end $function$
;

create or replace function public.sirket_sube_finans(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s oyun.sirketler; h jsonb;
begin
 if u is null then raise exception 'Oturum gerekli.';end if;
 if not exists (select 1 from oyun.sirket_ortaklari
  where sirket_id=p_sirket and user_id=u and pay>0) then
  raise exception 'Bu sirketin ortagi degilsin.';end if;
 select * into s from oyun.sirketler where id=p_sirket;
 if s.id is null then raise exception 'Sirket bulunamadi.'; end if;
 h:=oyun.pazar_tahmin(p_sirket);
 return jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,
    'sube_sayisi',(select count(*) from oyun.sirket_il_subeleri where sirket_id=s.id),
    'haftalik_toplam_gelir',coalesce((h->>'gelir')::numeric,0),
    'haftalik_toplam_gider',coalesce((h->>'gider')::numeric,0),
    'haftalik_net',coalesce((h->>'net')::numeric,0),
    'sube_gelir',coalesce((h->>'sube_gelir')::numeric,0),
    'sube_gider',coalesce((h->>'sube_gider')::numeric,0),
    'subeler',coalesce(h->'sube_detaylar','[]'::jsonb));
end $$;
revoke all on function public.sirket_sube_finans(bigint) from public,anon,authenticated;
grant execute on function public.sirket_sube_finans(bigint) to authenticated;
