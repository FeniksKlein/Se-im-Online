-- 27.11.2026 — Yazara günlük telif özeti bildirimi (Ercan: "Ekle").
-- Telif her satışta zaten otomatik olarak yazarın cüzdanına geçiyor (oyun.uc_kitap_kazanc). Bu dosya yalnız bilgilendirme ekler:
--   • Her sabah 09:00 TSİ'den sonra (zamanlayıcı 15 dakikada bir bakar) bir önceki TSİ gününün satışları yazar başına toplanır.
--   • Satışı olan her yazara tek bildirim: en çok satan 3 kitap (adet), toplam adet ve cüzdana yatan toplam telif.
--   • Gün başına bir kez çalışır (oyun.kitap_telif_ozet_gun işaret tablosu); tekrar çalıştırılırsa bir şey yapmaz.
--   • Yük: uc_kitap_satis(zaman) indeksiyle tek günlük aralık taranır; yazar başına bir insert. Binlerce yazarda da tek sorgu.
-- Oyuncu verisine dokunmaz; para hareketi yoktur.

create table if not exists oyun.kitap_telif_ozet_gun (
  gun date primary key,
  zaman timestamptz not null default now(),
  yazar_sayisi integer not null default 0
);
alter table oyun.kitap_telif_ozet_gun enable row level security;
revoke all on oyun.kitap_telif_ozet_gun from public, anon, authenticated;

create or replace function oyun.kitap_telif_tl(x numeric) returns text
language sql immutable set search_path to '' as $$
  select replace(to_char(round(coalesce(x, 0)), 'FM999,999,999,999,990'), ',', '.') || ' ₺'
$$;

create or replace function oyun.kitap_telif_ozet_tick(p_simdi timestamptz default null)
returns integer language plpgsql security definer set search_path to '' as $$
declare
  t timestamptz := coalesce(p_simdi, oyun.simdi());
  yerel timestamp := t at time zone 'Europe/Istanbul';
  v_gun date := (yerel - interval '1 day')::date;
  bas timestamptz; bit timestamptz; n integer := 0;
begin
  if extract(hour from yerel) < 9 then return 0; end if;
  insert into oyun.kitap_telif_ozet_gun(gun, zaman) values (v_gun, t) on conflict (gun) do nothing;
  if not found then return 0; end if;
  bas := (v_gun::timestamp) at time zone 'Europe/Istanbul';
  bit := ((v_gun + 1)::timestamp) at time zone 'Europe/Istanbul';

  with ks as (
    select k.yazar, k.id, k.baslik, sum(s.adet)::bigint adet, sum(s.telif) telif
      from oyun.uc_kitap_satis s join oyun.uc_kitap k on k.id = s.kitap_id
     where s.zaman >= bas and s.zaman < bit and k.yazar is not null
     group by k.yazar, k.id, k.baslik
  ), sirali as (
    select ks.*, row_number() over (partition by yazar order by adet desc, telif desc, id) sn,
           count(*) over (partition by yazar) kitap_say from ks
  ), yazar as (
    select yazar, sum(adet) adet, sum(telif) telif, max(kitap_say) kitap_say,
           string_agg(case when sn <= 3 then '«' || baslik || '» ' || adet || ' adet' end, ', ' order by sn) liste
      from sirali group by yazar
  ), ekle as (
    insert into oyun.bildirimler(user_id, zaman, metin)
    select y.yazar, t,
           '📚 Dünkü kitap satışların: ' || y.liste ||
           case when y.kitap_say > 3 then ' ve ' || (y.kitap_say - 3) || ' kitap daha' else '' end ||
           '. Toplam ' || y.adet || ' kitap satıldı; cüzdanına ' || oyun.kitap_telif_tl(y.telif) || ' telif yattı.'
      from yazar y
     where y.telif > 0 and exists (select 1 from oyun.profiller p where p.id = y.yazar)
    returning 1
  )
  select count(*) into n from ekle;

  update oyun.kitap_telif_ozet_gun set yazar_sayisi = n where gun = v_gun;
  return n;
end $$;

revoke all on function oyun.kitap_telif_ozet_tick(timestamptz), oyun.kitap_telif_tl(numeric) from public, anon, authenticated;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif) values
      ('kitap_telif_ozet', 'select oyun.kitap_telif_ozet_tick(oyun.simdi())', 15, 4, 134, true)
    on conflict (adim) do nothing;
  end if;
end $z$;
