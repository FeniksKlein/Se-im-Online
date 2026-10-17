-- Canlı veritabanına uygulanacak tek seferlik TGP ad değişikliği yaması.
-- Kaynak: gelistirici/sql/105_tgp_tek_ad_hakki.sql
-- TGP: bir defaya mahsus, 7 günlük bekleme süresinden bağımsız ad değişikliği.
-- Parti yöneticisi değişse de hak partiye aittir; kullanılmış bir hak yeniden açılmaz.
create table if not exists oyun.parti_ozel_ad_hakki (
  parti_id bigint primary key references oyun.partiler(id) on delete cascade,
  tanindi timestamptz not null default now(),
  kullanildi timestamptz
);

alter table oyun.parti_ozel_ad_hakki enable row level security;
revoke all on oyun.parti_ozel_ad_hakki from public, anon, authenticated;

-- Partiyi mevcut tam adı ve kısa adından bul; üretilmiş kimlikleri sabitleme.
insert into oyun.parti_ozel_ad_hakki(parti_id)
select id from oyun.partiler where ad='Türkçü Gelişim Partisi' and kisa='TGP' and not kapali
on conflict (parti_id) do nothing;

create or replace function public.parti_ad_ozel_hakki(p_parti bigint)
returns text language sql stable security definer
set search_path=''
as $$
  select coalesce((select case when kullanildi is null then 'hazir' else 'kullanildi' end
                   from oyun.parti_ozel_ad_hakki where parti_id=p_parti), 'yok');
$$;
revoke all on function public.parti_ad_ozel_hakki(bigint) from public, anon;
grant execute on function public.parti_ad_ozel_hakki(bigint) to authenticated;

create or replace function public.parti_ad_degistir(p_ad text,p_kisa text)
returns jsonb
language plpgsql security definer
set search_path=''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  ozel_hak boolean;
  eski_ad text;
  eski_kisa text;
begin
  -- Bu kilit aynı partiye ait eşzamanlı isim değişikliklerini sıraya alır.
  select * into pa
  from oyun.partiler
  where id=p.parti_id and not kapali
  for update;

  if pa.id is null or pa.gb is distinct from p.id then
    raise exception 'Partinin adını yalnızca genel başkan değiştirebilir.';
  end if;

  select exists(select 1 from oyun.parti_ozel_ad_hakki
                where parti_id=pa.id and kullanildi is null) into ozel_hak;
  if not ozel_hak and pa.son_ad_degis is not null and pa.son_ad_degis + interval '7 days' > t then
    raise exception 'Parti adı 7 günde bir değiştirilebilir. En erken %.',
      to_char((pa.son_ad_degis + interval '7 days') at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI');
  end if;

  p_ad := btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
  p_kisa := upper(btrim(coalesce(p_kisa,'')));

  if length(p_ad)<5 or length(p_ad)>40 then raise exception 'Parti adı 5-40 karakter olmalı.'; end if;
  if p_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then raise exception 'Parti adında yalnızca harf kullanılabilir.'; end if;
  if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' then raise exception 'Kısa ad 2-6 büyük harf olmalı.'; end if;
  if oyun.yasakli_ad(p_ad) or oyun.yasakli_kisa(p_kisa) then raise exception 'Gerçek bir partiyi çağrıştıran veya uygunsuz adlar kullanılamaz.'; end if;
  if exists(select 1 from oyun.partiler where id<>pa.id and not kapali and lower(ad)=lower(p_ad)) then raise exception 'Bu adla bir parti zaten var.'; end if;
  if exists(select 1 from oyun.partiler where id<>pa.id and not kapali and lower(kisa)=lower(p_kisa)) then raise exception 'Bu kısa ad kullanılıyor.'; end if;
  if lower(pa.ad)=lower(p_ad) and lower(pa.kisa)=lower(p_kisa) then raise exception 'Partinin adı zaten bu.'; end if;

  eski_ad := pa.ad; eski_kisa := pa.kisa;
  insert into oyun.parti_ad_gecmis(parti_id,eski_ad,eski_kisa,yeni_ad,yeni_kisa,degistiren,zaman)
  values(pa.id,eski_ad,eski_kisa,p_ad,p_kisa,p.id,t);

  update oyun.partiler set ad=p_ad,kisa=p_kisa,son_ad_degis=t where id=pa.id;
  if ozel_hak then
    update oyun.parti_ozel_ad_hakki set kullanildi=t
    where parti_id=pa.id and kullanildi is null;
  end if;

  insert into oyun.bildirimler(user_id,zaman,metin)
  select id,t,format('%s (%s) partisinin adı %s (%s) olarak değiştirildi.',eski_ad,eski_kisa,p_ad,p_kisa)
  from oyun.profiller where parti_id=pa.id and id<>p.id;

  perform oyun.olay('parti',format('%s (%s), adını %s (%s) olarak değiştirdi.',eski_ad,eski_kisa,p_ad,p_kisa),null,pa.id,t);
  return public.parti_detay(pa.id);
end $$;

revoke all on function public.parti_ad_degistir(text,text) from public, anon;
grant execute on function public.parti_ad_degistir(text,text) to authenticated;
