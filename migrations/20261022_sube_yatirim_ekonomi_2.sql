-- Guncel sube ekonomisi ve yatirim teklifi

-- Existing function's arguments and response keys are preserved.
create or replace function oyun.sube_pazar_tahmin(
 p_sirket bigint,p_fiyat smallint default null,p_kalite smallint default null,
 p_an timestamptz default null)
returns jsonb language plpgsql stable set search_path='' as $$
declare
  sb record; d jsonb; zt timestamptz:=coalesce(p_an,oyun.simdi());
  total_sales numeric:=0;total_cost numeric:=0;wage_cost numeric:=0;
  fixed_cost numeric:=0;goods_cost numeric:=0;n integer:=0;details jsonb:='[]'::jsonb;
begin
  for sb in
   select a.id,a.il_id from oyun.sirket_il_subeleri a
   where a.sirket_id=p_sirket and a.acilis<=zt
   order by a.il_id,a.id
  loop
    d:=oyun.sube_bolge_analiz(p_sirket,sb.il_id,p_fiyat,p_kalite,zt);
    n:=n+1;
    total_sales:=total_sales+(d->>'haftalik_ciro')::numeric;
    wage_cost:=wage_cost+(d->>'haftalik_personel')::numeric;
    fixed_cost:=fixed_cost+(d->>'haftalik_sabit')::numeric;
    goods_cost:=goods_cost+(d->>'haftalik_urun_maliyeti')::numeric;
    details:=details||jsonb_build_array(jsonb_build_object(
      'id',sb.id,'il_id',sb.il_id,'il',d->>'il',
      'gelir',(d->>'haftalik_ciro')::numeric,
      'personel',(d->>'haftalik_personel')::numeric,
      'kira_enerji',(d->>'haftalik_sabit')::numeric,
      'satis_maliyeti',(d->>'haftalik_urun_maliyeti')::numeric,
      'gider',(d->>'haftalik_personel')::numeric+
        (d->>'haftalik_sabit')::numeric+(d->>'haftalik_urun_maliyeti')::numeric,
      'tahmini_net',(d->>'haftalik_net')::numeric,
      'pazar_payi',(d->>'pay')::numeric));
  end loop;
  total_cost:=wage_cost+fixed_cost+goods_cost;
  return jsonb_build_object('sube_sayisi',n,
   'gelir',total_sales,'gider',total_cost,'personel',wage_cost,
   'sabit',fixed_cost,'stok',goods_cost,'subeler',details);
end $$;

-- Oyuncu satın almadan önce net bütçe ve amortisman bilgisini görür.
create or replace function public.sirket_sube_teklif(p_sirket bigint,p_il integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();s oyun.sirketler; d jsonb;
begin
 if uid is null then raise exception 'Oturum açmalısın.';end if;
 if not exists(select 1 from oyun.sirket_ortaklari
   where sirket_id=p_sirket and user_id=uid and pay>0) then
  raise exception 'Yalnızca ortağı olduğun şirketin şube planını görebilirsin.';end if;
 select * into s from oyun.sirketler where id=p_sirket and aktif;
 if s.id is null then raise exception 'Aktif şirket bulunamadı.';end if;
 if not exists(select 1 from oyun.iller where id=p_il) then
   raise exception 'Geçerli il seç.';end if;
 if exists(select 1 from oyun.sirket_il_subeleri where sirket_id=p_sirket and il_id=p_il) then
   raise exception 'Bu ilde şirketin zaten bir şubesi var.';end if;
 if exists(select 1 from oyun.pazar_sirket where sirket_id=p_sirket) then
   d:=oyun.sube_bolge_analiz(p_sirket,p_il::smallint);
 else
   -- Banka ve reklam ajanslarının özel gelir mekanizmaları mevcut.
   -- Bu dallarda şube satış tahmini olmadığından uydurma getiri sunulmaz.
   d:=jsonb_build_object(
    'il_id',p_il,'il',(select ad from oyun.iller where id=p_il),
    'sektor',s.sektor,'haftalik_ciro',null,'haftalik_net',null,
    'dekorasyon_donanim',round(greatest(100000,s.sermaye*.25)),
    'depozito',round(greatest(25000,s.sermaye*.05)),
    'ilk_stok',0,'personel_hazirlik',round(greatest(20000,s.sermaye*.04)),
    'izin_ruhsat',10000,'geri_donus_hafta',null);
   d:=d||jsonb_build_object(
    'acilis_maliyeti',(d->>'dekorasyon_donanim')::numeric+
        (d->>'depozito')::numeric+(d->>'personel_hazirlik')::numeric+10000,
    'isletme_rezervi',round(greatest(25000,s.sermaye*.1)));
   d:=d||jsonb_build_object('gerekli_kasa',
     (d->>'acilis_maliyeti')::numeric+(d->>'isletme_rezervi')::numeric);
 end if;
 return d||jsonb_build_object('sirket_id',s.id,'sirket',s.ad,
   'mevcut_kasa',s.kasa,'yeterli',s.kasa>=(d->>'gerekli_kasa')::numeric,
   'eksik',greatest(0,(d->>'gerekli_kasa')::numeric-s.kasa));
end $$;
revoke all on function public.sirket_sube_teklif(bigint,integer)
 from public,anon,authenticated;
grant execute on function public.sirket_sube_teklif(bigint,integer) to authenticated;

-- Eski RPC adı ve parametreleri aynen korunur: yayınlanmış istemciler de çalışır.
create or replace function public.sirket_sube_ac_ilde(p_sirket bigint,p_il integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();aid bigint;d jsonb;s oyun.sirketler;
 opening_cost numeric;required_cash numeric;city text;nowt timestamptz:=oyun.simdi();
begin
 if uid is null then raise exception 'Oturum açmalısın.';end if;
 if p_sirket is null or p_il is null then raise exception 'Şirket ve il seçmelisin.';end if;
 perform pg_advisory_xact_lock(98763,pg_catalog.hashtext(p_sirket::text));
 -- Bekleyen faaliyet giderlerinin ve gelirlerin güncellenmesi: gerçek bakiye.
 perform oyun.sirket_hesapla(p_sirket);
 select * into s from oyun.sirketler where id=p_sirket and aktif for update;
 if s.id is null or not oyun.sirket_yonetici_mi(p_sirket,uid) then
  raise exception 'Faaliyetteki şirketin yöneticisi olmalısın.';end if;
 select ad into city from oyun.iller where id=p_il;
 if city is null then raise exception 'Geçerli il seç.';end if;
 if exists(select 1 from oyun.sirket_il_subeleri where sirket_id=p_sirket and il_id=p_il) then
  raise exception 'Bu ilde zaten bir şuben bulunuyor.';end if;
 d:=public.sirket_sube_teklif(p_sirket,p_il);
 opening_cost:=(d->>'acilis_maliyeti')::numeric;
 required_cash:=(d->>'gerekli_kasa')::numeric;
 if s.kasa<required_cash then
  raise exception 'Şube yatırım bedeli % TL; işletme için korunacak kasa % TL; toplam gerekli % TL. Şirket kasası % TL. Önce kendi cüzdanından şirkete para aktarabilirsin.',
   oyun.tl(opening_cost),oyun.tl((d->>'isletme_rezervi')::numeric),
   oyun.tl(required_cash),oyun.tl(s.kasa);
 end if;
 update oyun.sirketler set kasa=kasa-opening_cost,son_islem=nowt where id=p_sirket;
 insert into oyun.sirket_il_subeleri(sirket_id,il_id)
 values(p_sirket,p_il::smallint) returning id into aid;
 insert into oyun.sirket_hareket
  (sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_sirket,nowt,-opening_cost,
   pg_catalog.format('%s şubesi açılış yatırımı: dekorasyon %s, depozito %s, ilk stok %s, personel hazırlık %s, ruhsat %s. Faaliyet zararı değildir.',
    city, d->>'dekorasyon_donanim',d->>'depozito',d->>'ilk_stok',
    d->>'personel_hazirlik',d->>'izin_ruhsat'),
   0,0,0);
 return d||jsonb_build_object('id',aid,'il_id',p_il,'il',city,
    'bedel',opening_cost,'acilis_maliyeti',opening_cost,
    'kalan_kasa',s.kasa-opening_cost,'tamam',true);
end $$;
revoke all on function public.sirket_sube_ac_ilde(bigint,integer)
 from public,anon,authenticated;
grant execute on function public.sirket_sube_ac_ilde(bigint,integer) to authenticated;
