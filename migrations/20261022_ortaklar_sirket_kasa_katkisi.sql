-- 22.10.2026: Ortaklarin kisisel cuzdanlarindan sirket kasasina guvenli ek sermaye katkisi.
-- Sirket paylari degismez; katki kar, satis veya temettu sayilmaz.
-- Eski kayitlar ve eski sirket_sermaye_artir RPC'si korunur.
create or replace function public.sirket_kasa_yatir(p_sirket bigint, p_tutar numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_pay numeric;
  v_s oyun.sirketler;
  v_an timestamptz := oyun.simdi();
begin
  if v_user is null then raise exception 'İşlem için giriş yapmalısın.'; end if;
  if p_sirket is null or p_sirket <= 0 then raise exception 'Geçerli bir şirket seç.'; end if;
  if not exists (
    select 1 from oyun.sirket_ortaklari o
    join oyun.sirketler s on s.id=o.sirket_id
    where o.sirket_id=p_sirket and o.user_id=v_user and o.pay>0 and s.aktif
  ) then raise exception 'Yalnızca faal şirketin mevcut ortakları kasaya para yatırabilir.'; end if;
  if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<1 or p_tutar>100000000 then
    raise exception '1 ile 100.000.000 TL arasında tam sayı tutar gir.'; end if;

  -- Diger sirket islemleriyle ayni kilit; eski faaliyet kazanci once hesaplanir.
  perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(p_sirket::text));
  perform oyun.sirket_hesapla(p_sirket);
  select * into v_s from oyun.sirketler where id=p_sirket and aktif for update;
  if v_s.id is null then raise exception 'Aktif şirket bulunamadı.'; end if;
  select o.pay into v_pay from oyun.sirket_ortaklari o
  where o.sirket_id=p_sirket and o.user_id=v_user for update;
  if coalesce(v_pay,0)<=0 then raise exception 'Bu şirketin ortağı değilsin.'; end if;
  if v_s.sermaye+p_tutar>100000000 then
    raise exception 'Şirketin toplam sermayesi 100.000.000 TL sınırını geçemez.'; end if;

  -- Hepsi ayni SQL isleminde: yetersiz bakiyede tamami geri alinir.
  perform oyun.para_islem(v_user,-p_tutar,'sirket',
    pg_catalog.format('%s: şahsi hesaptan şirket kasasına sermaye katkısı (hisse değişmedi)',v_s.ad),v_an);
  update oyun.sirketler set
    sermaye=sermaye+p_tutar,
    kasa=kasa+p_tutar,
    son_islem=v_an
  where id=p_sirket;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
  values(p_sirket,v_an,p_tutar,
    pg_catalog.format('Ortak %s şirket kasasına kendi parasından %s TL yatırdı; paylar değişmedi.',
      oyun.kad(v_user), p_tutar::text));

  return jsonb_build_object('tamam',true,'sirket_id',p_sirket,'yatirilan',p_tutar,
    'kasa',v_s.kasa+p_tutar,'sermaye',v_s.sermaye+p_tutar,
    'benim_payim',v_pay,'paylar_degisti',false);
end;
$$;

revoke all on function public.sirket_kasa_yatir(bigint,numeric) from public,anon,authenticated;
grant execute on function public.sirket_kasa_yatir(bigint,numeric) to authenticated;
