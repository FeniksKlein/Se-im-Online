-- 2026-10-14: kitap fiyatini yazar belirler; yayinevi yalniz baski miktarini yonetir.
-- Veri silinmez, yayinlanan kitaplar ve onceki alislar korunur.
alter table oyun.uc_kitap
  add column if not exists fiyat_son_degisim timestamptz;

create or replace function public.uc_kitap_islem(
  p_islem text, p_id bigint, p_veri jsonb default '{}'::jsonb
)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
  u uuid := auth.uid();
  t timestamptz := oyun.simdi();
  s oyun.sirketler;
  k oyun.uc_kitap;
  title text; qty int; price numeric; expense numeric; bid bigint;
begin
  perform oyun.profilim();
  if p_veri is null or jsonb_typeof(p_veri) <> 'object' then
    raise exception 'Veri hatalı';
  end if;

  if p_islem = 'teklif' then
    select * into s from oyun.sirketler
      where id = p_id and sektor = 'medya' and aktif;
    if s.id is null then raise exception 'Yayınevi bulunamadı'; end if;
    title := trim(coalesce(p_veri->>'baslik',''));
    if length(title) not between 4 and 100
       or length(coalesce(p_veri->>'icerik','')) not between 100 and 15000
       or length(coalesce(p_veri->>'ozet','')) > 600
    then raise exception 'Başlık 4-100, kitap metni 100-15000, özet en çok 600 karakter olmalı'; end if;
    if (select count(*) from oyun.uc_kitap where yazar=u and durum='teklif') >= 5
    then raise exception 'En fazla 5 bekleyen kitap teklifi olabilir'; end if;
    -- Eski mobil surumlerle uyum: eksik fiyat icin 300 TL varsayilir.
    price := coalesce(nullif(p_veri->>'fiyat','')::numeric,300);
    if price not between 100 and 2000 or price <> trunc(price)
    then raise exception 'Kitap fiyatı 100-2000 ₺ arasında tam sayı olmalı'; end if;
    insert into oyun.uc_kitap
      (yayinevi,yazar,baslik,tur,ozet,icerik,fiyat,olusturma)
    values(s.id,u,title,left(coalesce(p_veri->>'tur','Siyasi hatırat'),40),
      left(coalesce(p_veri->>'ozet',''),600),p_veri->>'icerik',price,t)
    returning id into bid;
    return jsonb_build_object('id',bid,'durum','teklif','fiyat',price);
  end if;

  select * into k from oyun.uc_kitap where id=p_id for update;
  if k.id is null then raise exception 'Kitap bulunamadı'; end if;

  if p_islem = 'satinal' then
    if k.durum <> 'yayinda' or k.stok < 1 or k.yazar = u
    then raise exception 'Kitap satışı uygun değil'; end if;
    if exists(select 1 from oyun.uc_kitap_satis where kitap_id=k.id and alici=u)
    then raise exception 'Kitabı zaten aldın'; end if;
    update oyun.cuzdan set para=para-k.fiyat
      where user_id=u and para>=k.fiyat;
    if not found then raise exception 'Bakiye yetersiz'; end if;
    return oyun.uc_kitap_kazanc(k.id,1,u,null);
  end if;

  if p_islem = 'fiyat' then
    if k.yazar <> u then raise exception 'Kitap fiyatını yalnızca yazarı belirleyebilir'; end if;
    if k.durum not in ('teklif','yayinda')
    then raise exception 'Bu kitabın fiyatı değiştirilemez'; end if;
    price := nullif(p_veri->>'fiyat','')::numeric;
    if price is null or price not between 100 and 2000 or price <> trunc(price)
    then raise exception 'Fiyat 100-2000 ₺ arasında tam sayı olmalı'; end if;
    if k.durum = 'yayinda' and k.fiyat_son_degisim is not null
        and k.fiyat_son_degisim > t - interval '24 hours'
    then raise exception 'Yayımlanmış kitabın fiyatı 24 saatte bir değiştirilebilir'; end if;
    if k.durum='yayinda' and price=k.fiyat then
      return jsonb_build_object('fiyat',k.fiyat,'degismedi',true);
    end if;
    update oyun.uc_kitap set fiyat=price,fiyat_son_degisim=t where id=k.id;
    return jsonb_build_object('fiyat',price,'durum',k.durum);
  end if;

  select * into s from oyun.sirketler
    where id=k.yayinevi and aktif for update;
  if s.id is null or not exists (
    select 1 from oyun.sirket_ortaklari
    where sirket_id=s.id and user_id=u and pay>=50
  ) then raise exception 'Yayınevini yönetme yetkin yok'; end if;

  if p_islem = 'reddet' then
    update oyun.uc_kitap set durum='reddedildi'
      where id=k.id and durum='teklif';
    if not found then raise exception 'Bekleyen teklif bulunamadı'; end if;
    return jsonb_build_object('durum','reddedildi');
  elsif p_islem in ('yayinla','yenibaski') then
    if (p_islem='yayinla' and k.durum<>'teklif')
       or (p_islem='yenibaski' and k.durum<>'yayinda')
    then raise exception 'Kitap durumu uygun değil'; end if;
    qty := coalesce(nullif(p_veri->>'adet','')::int,0);
    -- Yayinevi istemciden gelen fiyati degistiremez.
    price := k.fiyat;
    if qty not between 10 and 200 or price not between 100 and 2000
    then raise exception 'Baskı 10-200 adet olmalı; yazar önce 100-2000 ₺ arası fiyat belirlemeli'; end if;
    expense := round(qty*price*.4);
    update oyun.sirketler set kasa=kasa-expense
      where id=s.id and kasa>=expense;
    if not found then raise exception 'Baskı gideri için kasa yetersiz'; end if;
    update oyun.uc_kitap set stok=stok+qty,durum='yayinda',
      yayin=coalesce(yayin,t),son_satis=coalesce(son_satis,t)
      where id=k.id;
    return jsonb_build_object('baski',qty,'gider',expense,'fiyat',price);
  end if;
  raise exception 'Bilinmeyen kitap işlemi';
end $$;

revoke all on function public.uc_kitap_islem(text,bigint,jsonb) from public,anon;
grant execute on function public.uc_kitap_islem(text,bigint,jsonb) to authenticated;

create or replace function public.uc_kitap_panel()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid();
begin
 perform oyun.profilim();
 return jsonb_build_object(
 'yayinevleri',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad,'kasa',kasa))
  from oyun.sirketler where aktif and sektor='medya'),'[]'::jsonb),
 'benim_yayinevleri',coalesce((select jsonb_agg(s.id)
  from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id
  where s.aktif and s.sektor='medya' and o.user_id=u and o.pay>=50),'[]'::jsonb),
 'kitaplar',coalesce((select jsonb_agg(jsonb_build_object(
  'id',k.id,'baslik',k.baslik,'tur',k.tur,'ozet',k.ozet,
  'icerik',case when k.yazar=u
   or exists(select 1 from oyun.sirket_ortaklari o
     where o.sirket_id=k.yayinevi and o.user_id=u and o.pay>=50)
   or exists(select 1 from oyun.uc_kitap_satis a
     where a.kitap_id=k.id and a.alici=u) then k.icerik else null end,
  'yazar',(select kad from oyun.profiller where id=k.yazar),
  'yazar_benim',k.yazar=u,'yayinevi',k.yayinevi,'yayinevi_ad',s.ad,
  'durum',k.durum,'fiyat',k.fiyat,'stok',k.stok,'satilan',k.satilan,
  'telif',k.telif_orani,'aldim',
  exists(select 1 from oyun.uc_kitap_satis a where a.kitap_id=k.id and a.alici=u),
  'fiyat_son_degisim',k.fiyat_son_degisim
  )) from oyun.uc_kitap k join oyun.sirketler s on s.id=k.yayinevi
  where k.durum='yayinda' or k.yazar=u or exists(
    select 1 from oyun.sirket_ortaklari o where o.sirket_id=k.yayinevi
    and o.user_id=u and o.pay>=50)),'[]'::jsonb)
 );
end $$;
revoke all on function public.uc_kitap_panel() from public,anon;
grant execute on function public.uc_kitap_panel() to authenticated;
