-- 27.11.2026 · Aday Vitrini + Aday Tanıtım Lansmanı (sürüm 2026.11.27-1)
-- İstek (Ercan): "Partilerin milletvekili adaylarını lanse edebilecekleri bir ekran/menü/harita olsun: hangi ilde kim aday,
-- kaçıncı sıradan. Bir de partiler aday tanıtım lansmanı yapabilsin."
--
-- 1) ADAY VİTRİNİ (herkese açık, yalnız okuma)
--    • Aktif genel seçim döneminin (oyun.secimler tur='mv' bekliyor) 81 il haritası: her ilde kontenjan, aday sayısı, partiler.
--    • İl detayı: her partinin listesi sırasıyla, bağımsızlar, o ildeki lansmanlar.
--    • Görünürlük (gerçek usul): ön seçim sonuçlanmadan önce yalnız aday adaylığına BAŞVURANLAR "aday adayı" olarak görünür
--      (Genel Başkanın kendi taslağına eklediği ama başvurmamış üyeler görünmez). Ön seçim sonuçlanınca (mv_on durum='tamam')
--      kesin listeler sıra numarasıyla, listeye giremeyenler hiç görünmez. Ön seçim oyları sonuçtan önce gösterilmez.
-- 2) ADAY TANITIM LANSMANI (partiler düzenler)
--    • Düzenleyen: Genel Başkan veya "Seçim İşleri" / "Tanıtım ve Medya" yetkili GBY (oyun.parti_gorevli, parti_aday_tanit ile aynı).
--    • Kapsam: bir il (o ilin listesinden en çok min(12, kontenjan) aday) ya da Türkiye geneli (her ilden en çok 12 aday).
--    • Aday şartı: kesin listede (sira) ya da kesinleşmeden önce Genel Başkan atamalı partide GB listesinde (atama_sira).
--      Ön seçimli partide ön seçim sonucu beklenir (ön seçimde bir aday adayını parti eliyle öne çıkarmak adil olmaz).
--    • Zaman: en erken 15 dk, en geç 3 gün sonrası; 1 saat sürer; genel seçim oylaması bitmeden biter.
--    • Sınırlar (binlerce oyuncu ölçeği): parti başına dönemde her ilde 1, Türkiye genelinde 1 lansman; 24 saatte en çok 4 yeni.
--    • Bedel parti kasasından: il = taban + sandalye başı ek; Türkiye geneli sabit (oyun.aday_lansman_ayar, portaldan değişir).
--      Başlamadan iptal edilirse bedel kasaya tam iade edilir; yönetim kaldırırsa iade yok.
--    • Oyuncular önceden "Hatırlat" der (başlayınca bildirim), canlıyken katılır, her adayı bir kez alkışlar, kısa destek
--      mesajı yazar (200 karakter, 20 sn'de bir, lansman başına 15; susturma/gözaltı/yasaklı ifade süzgeçleri geçerli).
--    • Başlayınca Gündem haberi + partinin o ildeki (Türkiye genelinde bütün) üyelerine ve hatırlat diyenlere bildirim;
--      bitince katılım/alkış özetiyle sonuç haberi. Oy hesabına doğrudan etkisi YOK (oyu gerçek oyuncular verir); etkisi görünürlük.
--    • İçerik Masası (yetki 'sikayet') lansmanı kaldırabilir, mesaj silebilir; kaldırılan lansman vitrinde görünmez.
-- Eski uygulama bu RPC'leri çağırmaz; hiçbir eski fonksiyon değişmez. Tekrar çalıştırmak güvenlidir.

-- ============ AYARLAR ============
create table if not exists oyun.aday_lansman_ayar (
  id integer primary key default 1 check (id = 1),
  aktif boolean not null default true,
  il_taban numeric not null default 10000 check (il_taban >= 0),
  il_sandalye numeric not null default 1000 check (il_sandalye >= 0),
  ulke numeric not null default 150000 check (ulke >= 0),
  gunluk_sinir integer not null default 4 check (gunluk_sinir between 1 and 50),
  sure_dk integer not null default 60 check (sure_dk between 15 and 240),
  guncelleme timestamptz not null default now()
);
insert into oyun.aday_lansman_ayar(id) values (1) on conflict (id) do nothing;
alter table oyun.aday_lansman_ayar enable row level security;
revoke all on oyun.aday_lansman_ayar from public, anon, authenticated;

-- ============ TABLOLAR ============
create table if not exists oyun.aday_lansman (
  id bigint generated always as identity primary key,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  donem text not null,
  il_id smallint references oyun.iller(id),          -- null = Türkiye geneli
  baslik text not null check (char_length(baslik) between 5 and 90),
  metin text not null check (char_length(metin) between 30 and 1500),
  bas timestamptz not null,
  bit timestamptz not null,
  bedel numeric not null default 0 check (bedel >= 0 and bedel < 'Infinity'::numeric),
  duzenleyen uuid not null,
  durum text not null default 'planli' check (durum in ('planli', 'iptal', 'kaldirildi')),
  kaldir_gerekce text,
  duyuruldu boolean not null default false,
  ozet_yazildi boolean not null default false,
  olusturma timestamptz not null default now(),
  check ("bit" > bas)
);
create index if not exists aday_lansman_donem_idx on oyun.aday_lansman(donem, bas);
create index if not exists aday_lansman_parti_idx on oyun.aday_lansman(parti_id, donem);
create index if not exists aday_lansman_bekleyen_idx on oyun.aday_lansman(bas) where durum = 'planli' and not duyuruldu;
create index if not exists aday_lansman_bitecek_idx on oyun.aday_lansman(bit) where durum = 'planli' and not ozet_yazildi;

create table if not exists oyun.aday_lansman_aday (
  lansman_id bigint not null references oyun.aday_lansman(id) on delete cascade,
  aday_id bigint not null references oyun.adaylar(id) on delete cascade,
  sira smallint not null,
  not_metin text check (not_metin is null or char_length(not_metin) <= 240),
  primary key (lansman_id, aday_id)
);
create index if not exists aday_lansman_aday_aday_idx on oyun.aday_lansman_aday(aday_id);

create table if not exists oyun.aday_lansman_katilim (
  lansman_id bigint not null references oyun.aday_lansman(id) on delete cascade,
  user_id uuid not null,
  hatirlat boolean not null default false,             -- başlamadan önce "Hatırlat" dedi
  katildi timestamptz,                                  -- canlıyken salona girdi
  zaman timestamptz not null default now(),
  primary key (lansman_id, user_id)
);

create table if not exists oyun.aday_lansman_alkis (
  lansman_id bigint not null references oyun.aday_lansman(id) on delete cascade,
  aday_id bigint not null,
  user_id uuid not null,
  zaman timestamptz not null default now(),
  primary key (lansman_id, aday_id, user_id)
);

create table if not exists oyun.aday_lansman_mesaj (
  id bigint generated always as identity primary key,
  lansman_id bigint not null references oyun.aday_lansman(id) on delete cascade,
  user_id uuid not null,
  metin text not null check (char_length(metin) between 1 and 200),
  zaman timestamptz not null default now(),
  silindi boolean not null default false
);
create index if not exists aday_lansman_mesaj_idx on oyun.aday_lansman_mesaj(lansman_id, id desc);
create index if not exists aday_lansman_mesaj_kisi_idx on oyun.aday_lansman_mesaj(user_id, zaman desc);

do $r$
declare t text;
begin
  foreach t in array array['aday_lansman', 'aday_lansman_aday', 'aday_lansman_katilim', 'aday_lansman_alkis', 'aday_lansman_mesaj'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $r$;

-- Yasaklı ifade süzgeci ve gözaltı yazı yasağı (diğer bütün oyuncu metinleriyle aynı tetikleyiciler)
do $tg$
begin
  if to_regprocedure('oyun.bolucu_metin_trg()') is not null then
    execute 'create or replace trigger bolucu_metin before insert or update on oyun.aday_lansman for each row execute function oyun.bolucu_metin_trg(''baslik'', ''metin'')';
    execute 'create or replace trigger bolucu_metin before insert or update on oyun.aday_lansman_aday for each row execute function oyun.bolucu_metin_trg(''not_metin'')';
    execute 'create or replace trigger bolucu_metin before insert or update on oyun.aday_lansman_mesaj for each row execute function oyun.bolucu_metin_trg(''metin'')';
  end if;
  if to_regprocedure('oyun.gozalti_yazi_engel_trg()') is not null then
    execute 'create or replace trigger gozalti_yazi_engel before insert on oyun.aday_lansman for each row execute function oyun.gozalti_yazi_engel_trg(''duzenleyen'')';
    execute 'create or replace trigger gozalti_yazi_engel before insert on oyun.aday_lansman_mesaj for each row execute function oyun.gozalti_yazi_engel_trg(''user_id'')';
  end if;
end $tg$;

-- ============ YARDIMCILAR ============
-- Vitrinin gösterdiği genel seçim dönemi: verilmişse o, yoksa bekleyen en yakın MV seçimi, o da yoksa son MV seçimi.
create or replace function oyun.alv_donem(p_donem text)
returns text language sql stable set search_path to '' as $$
  select coalesce(nullif(btrim(coalesce(p_donem, '')), ''),
    (select s.donem from oyun.secimler s where s.tur = 'mv' and s.durum = 'bekliyor' order by s.oy_bit, s.id limit 1),
    (select s.donem from oyun.secimler s where s.tur = 'mv' order by s.oy_bit desc, s.id desc limit 1))
$$;

create or replace function oyun.alv_asama(s_on oyun.secimler, s_mv oyun.secimler, t timestamptz)
returns text language sql stable set search_path to '' as $$
  select case
    when s_on.id is null and s_mv.id is null then 'yok'
    when s_on.id is not null and t < s_on.basvuru_bas then 'hazirlik'
    when s_on.id is not null and t < s_on.oy_bas then 'basvuru'
    when s_on.id is not null and t < s_on.oy_bit then 'onsecim'
    when s_on.id is not null and s_on.durum <> 'tamam' then 'sayim'
    when s_mv.id is not null and t < s_mv.oy_bas then 'kesin'
    when s_mv.id is not null and t < s_mv.oy_bit then 'sandik'
    else 'sonuc' end
$$;

create or replace function oyun.alv_asama_yazi(a text)
returns text language sql immutable set search_path to '' as $$
  select case a
    when 'hazirlik' then 'Aday adaylığı başvuruları henüz açılmadı'
    when 'basvuru' then 'Aday adaylığı başvuruları sürüyor — listede görünenler aday adayıdır'
    when 'onsecim' then 'Ön seçim oylaması sürüyor — listeler henüz kesin değil'
    when 'sayim' then 'Ön seçim sonuçları kesinleşiyor'
    when 'kesin' then 'Aday listeleri kesinleşti — sandık yaklaşıyor'
    when 'sandik' then 'Sandık açık — genel seçim oylaması sürüyor'
    when 'sonuc' then 'Seçim tamamlandı'
    else 'Takvimde genel seçim yok' end
$$;

create or replace function oyun.alv_gorunen_ad(u uuid)
returns text language sql stable set search_path to '' as $$
  select coalesce(nullif(btrim(p.ad_soyad), ''), p.kad) from oyun.profiller p where p.id = u
$$;

-- Bir lansmanın bedeli (il null = Türkiye geneli)
create or replace function oyun.alv_bedel(p_il smallint)
returns numeric language sql stable set search_path to '' as $$
  select case when p_il is null then a.ulke
              else a.il_taban + a.il_sandalye * coalesce((select coalesce(i.mv_secim, i.mv) from oyun.iller i where i.id = p_il), 0) end
  from oyun.aday_lansman_ayar a where a.id = 1
$$;

-- Lansmanın adayları (listeden düşen aday gösterilmez)
create or replace function oyun.alv_lansman_adaylar(p_lansman bigint, ben uuid)
returns jsonb language sql stable set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'aday_id', a.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
      'il_id', a.il_id, 'il', (select ad from oyun.iller where id = a.il_id),
      'sira', coalesce(a.sira, a.atama_sira), 'not', la.not_metin,
      'alkis', (select count(*) from oyun.aday_lansman_alkis x where x.lansman_id = la.lansman_id and x.aday_id = a.id),
      'alkisladim', ben is not null and exists (select 1 from oyun.aday_lansman_alkis x where x.lansman_id = la.lansman_id and x.aday_id = a.id and x.user_id = ben)
    ) order by la.sira), '[]'::jsonb)
  from oyun.aday_lansman_aday la
  join oyun.adaylar a on a.id = la.aday_id
  join oyun.profiller pr on pr.id = a.user_id
  join oyun.secimler s on s.id = a.secim_id
  where la.lansman_id = p_lansman
    and (s.durum <> 'tamam' or a.sira is not null)
$$;

create or replace function oyun.alv_lansman_ozet(l oyun.aday_lansman, t timestamptz)
returns jsonb language sql stable set search_path to '' as $$
  select jsonb_build_object(
    'id', l.id, 'baslik', l.baslik, 'bas', l.bas, 'bit', l.bit, 'durum', l.durum,
    'canli', l.durum = 'planli' and t >= l.bas and t < l.bit,
    'bitti', l.durum = 'planli' and t >= l.bit,
    'il_id', l.il_id, 'il', case when l.il_id is null then 'Türkiye geneli' else (select ad from oyun.iller where id = l.il_id) end,
    'parti', (select jsonb_build_object('id', p.id, 'kisa', p.kisa, 'ad', p.ad, 'renk', p.renk, 'amblem', p.amblem) from oyun.partiler p where p.id = l.parti_id),
    'aday_sayisi', (select count(*) from oyun.aday_lansman_aday x where x.lansman_id = l.id),
    'katilim', (select count(*) from oyun.aday_lansman_katilim k where k.lansman_id = l.id and k.katildi is not null),
    'hatirlat', (select count(*) from oyun.aday_lansman_katilim k where k.lansman_id = l.id and k.hatirlat))
$$;

-- ============ VİTRİN ============
create or replace function public.aday_vitrini(p_donem text default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d text := oyun.alv_donem(p_donem);
  s_on oyun.secimler; s_mv oyun.secimler; kesin boolean; asama text; gorevli bigint;
begin
  select * into s_on from oyun.secimler where tur = 'mv_on' and donem = d order by id desc limit 1;
  select * into s_mv from oyun.secimler where tur = 'mv' and donem = d order by id desc limit 1;
  kesin := coalesce(s_on.durum = 'tamam', false);
  asama := oyun.alv_asama(s_on, s_mv, t);
  gorevli := oyun.parti_gorevli(p.id, array['secim', 'tanitim']);
  return jsonb_build_object(
    'donem', d, 'asama', asama, 'asama_yazi', oyun.alv_asama_yazi(asama), 'kesin', kesin, 'simdi', t,
    'takvim', jsonb_build_object('basvuru_bas', s_on.basvuru_bas, 'basvuru_bit', s_on.basvuru_bit,
      'onsecim_bas', s_on.oy_bas, 'onsecim_bit', s_on.oy_bit, 'secim_bas', s_mv.oy_bas, 'secim_bit', s_mv.oy_bit),
    'toplam_kontenjan', (select sum(coalesce(i.mv_secim, i.mv)) from oyun.iller i),
    'partiler', coalesce((
      select jsonb_agg(jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'amblem', pa.amblem,
        'yontem', oyun.parti_yontem(pa.id, 'mv'), 'aday', coalesce(x.n, 0), 'il', coalesce(x.il, 0)) order by coalesce(x.n, 0) desc, pa.id)
      from oyun.partiler pa
      left join (select a.parti_id, count(*) n, count(distinct a.il_id) il from oyun.adaylar a
                 where a.secim_id = s_on.id and a.parti_id is not null
                   and case when kesin then a.sira is not null else not a.atama_ekleme end
                 group by a.parti_id) x on x.parti_id = pa.id
      where not pa.kapali), '[]'::jsonb),
    'iller', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad, 'k', coalesce(i.mv_secim, i.mv),
        'n', coalesce(x.n, 0), 'p', coalesce(x.p, '{}'::jsonb), 'b', coalesce(bg.n, 0), 'l', coalesce(l.n, 0)) order by i.id)
      from oyun.iller i
      left join (select y.il_id, sum(y.c)::int n, jsonb_object_agg(y.parti_id::text, y.c) p
                 from (select a.il_id, a.parti_id, count(*)::int c from oyun.adaylar a
                       where a.secim_id = s_on.id and a.parti_id is not null
                         and case when kesin then a.sira is not null else not a.atama_ekleme end
                       group by a.il_id, a.parti_id) y group by y.il_id) x on x.il_id = i.id
      left join (select a.il_id, count(distinct a.user_id)::int n from oyun.adaylar a
                 where a.secim_id in (s_on.id, s_mv.id) and a.parti_id is null group by a.il_id) bg on bg.il_id = i.id
      left join (select la.il_id, count(*)::int n from oyun.aday_lansman la
                 where la.donem = d and la.durum = 'planli' and la.il_id is not null group by la.il_id) l on l.il_id = i.id), '[]'::jsonb),
    'lansmanlar', coalesce((
      select jsonb_agg(oyun.alv_lansman_ozet(la, t) order by (la.bit <= t), case when la.bit > t then la.bas end, la.bas desc)
      from oyun.aday_lansman la
      where la.id in (select x.id from oyun.aday_lansman x where x.donem = d and x.durum = 'planli'
                      order by (x.bit <= t), case when x.bit > t then x.bas end, x.bas desc limit 30)), '[]'::jsonb),
    'ben', jsonb_build_object('parti_id', p.parti_id, 'il_id', p.il_id, 'lansman_yetkili', gorevli is not null,
      'mod', p.yonetici or exists (select 1 from oyun.moderatorler m where m.user_id = p.id)));
end $$;

create or replace function public.aday_vitrini_il(p_il integer, p_donem text default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d text := oyun.alv_donem(p_donem);
  s_on oyun.secimler; s_mv oyun.secimler; il oyun.iller; kesin boolean; asama text;
begin
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  select * into s_on from oyun.secimler where tur = 'mv_on' and donem = d order by id desc limit 1;
  select * into s_mv from oyun.secimler where tur = 'mv' and donem = d order by id desc limit 1;
  kesin := coalesce(s_on.durum = 'tamam', false);
  asama := oyun.alv_asama(s_on, s_mv, t);
  return jsonb_build_object(
    'donem', d, 'asama', asama, 'asama_yazi', oyun.alv_asama_yazi(asama), 'kesin', kesin,
    'il', jsonb_build_object('id', il.id, 'ad', il.ad, 'kontenjan', coalesce(il.mv_secim, il.mv)),
    'benim_ilim', p.il_id = il.id,
    'listeler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'parti', jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'amblem', pa.amblem),
        'yontem', oyun.parti_yontem(pa.id, 'mv'),
        'adaylar', (select jsonb_agg(jsonb_build_object(
            'aday_id', a.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
            'sira', case when kesin then a.sira end,
            'oy', case when kesin and oyun.parti_yontem(pa.id, 'mv') = 'onsecim' then coalesce(a.oy, 0) end,
            'vaat', nullif(btrim(coalesce(a.vaat, '')), ''),
            'gb', pa.gb = a.user_id,
            'lansman', (select count(*) from oyun.aday_lansman_aday la join oyun.aday_lansman l on l.id = la.lansman_id
                        where la.aday_id = a.id and l.durum = 'planli'),
            'alkis', (select count(*) from oyun.aday_lansman_alkis x join oyun.aday_lansman l on l.id = x.lansman_id
                      where x.aday_id = a.id and l.durum = 'planli'))
            order by case when kesin then a.sira end nulls last, a.basvuru_at, a.id)
          from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
          where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
            and case when kesin then a.sira is not null else not a.atama_ekleme end))
        order by (select count(*) from oyun.adaylar a where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
                    and case when kesin then a.sira is not null else not a.atama_ekleme end) desc, pa.id)
      from oyun.partiler pa
      where not pa.kapali and exists (select 1 from oyun.adaylar a where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
                                        and case when kesin then a.sira is not null else not a.atama_ekleme end)), '[]'::jsonb),
    'bagimsizlar', coalesce((
      select jsonb_agg(jsonb_build_object('aday_id', x.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
               'vaat', nullif(btrim(coalesce(x.vaat, '')), '')) order by x.basvuru_at)
      from (select distinct on (a.user_id) a.* from oyun.adaylar a
            where a.secim_id in (s_on.id, s_mv.id) and a.parti_id is null and a.il_id = il.id
            order by a.user_id, (a.secim_id = s_mv.id) desc) x
      join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb),
    'bos_listeli_partiler', coalesce((
      select jsonb_agg(jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk, 'yontem', oyun.parti_yontem(pa.id, 'mv')) order by pa.id)
      from oyun.partiler pa where not pa.kapali
        and not exists (select 1 from oyun.adaylar a where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
                          and case when kesin then a.sira is not null else not a.atama_ekleme end)), '[]'::jsonb),
    'lansmanlar', coalesce((
      select jsonb_agg(oyun.alv_lansman_ozet(la, t) order by la.bas)
      from oyun.aday_lansman la
      where la.donem = d and la.durum = 'planli'
        and (la.il_id = il.id or (la.il_id is null and exists (
              select 1 from oyun.aday_lansman_aday x join oyun.adaylar a on a.id = x.aday_id where x.lansman_id = la.id and a.il_id = il.id)))), '[]'::jsonb));
end $$;

create or replace function public.aday_vitrini_ara(p_ara text, p_donem text default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  p oyun.profiller := oyun.profilim(); d text := oyun.alv_donem(p_donem); q text := btrim(coalesce(p_ara, ''));
  s_on oyun.secimler; s_mv oyun.secimler; kesin boolean; desen text;
begin
  if char_length(q) < 2 then return '[]'::jsonb; end if;
  if char_length(q) > 40 then q := left(q, 40); end if;
  desen := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  select * into s_on from oyun.secimler where tur = 'mv_on' and donem = d order by id desc limit 1;
  select * into s_mv from oyun.secimler where tur = 'mv' and donem = d order by id desc limit 1;
  kesin := coalesce(s_on.durum = 'tamam', false);
  return coalesce((
    select jsonb_agg(z order by z->>'ad')
    from (select jsonb_build_object('aday_id', a.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
                   'il_id', a.il_id, 'il', (select ad from oyun.iller where id = a.il_id),
                   'sira', case when kesin then a.sira end,
                   'parti', case when a.parti_id is null then null else
                     (select jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = a.parti_id) end) z
          from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
          where ((a.secim_id = s_on.id and (a.parti_id is null or case when kesin then a.sira is not null else not a.atama_ekleme end))
                 or (a.secim_id = s_mv.id and a.parti_id is null))
            and (pr.kad ilike desen or pr.ad_soyad ilike desen)
          limit 30) q2), '[]'::jsonb);
end $$;

-- ============ LANSMAN: HAZIRLIK ============
create or replace function public.aday_lansman_hazirlik(p_il integer default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d text := oyun.alv_donem(null);
  pa oyun.partiler; s_on oyun.secimler; s_mv oyun.secimler; kesin boolean; yontem text; ay oyun.aday_lansman_ayar;
  son timestamptz; il oyun.iller;
begin
  select * into pa from oyun.partiler where id = oyun.parti_gorevli(p.id, array['secim', 'tanitim']) and not kapali;
  if pa.id is null then raise exception 'Aday lansmanını Genel Başkan ile Seçim İşlerinden ya da Tanıtım ve Medyadan Sorumlu Genel Başkan Yardımcısı düzenler.'; end if;
  select * into ay from oyun.aday_lansman_ayar where id = 1;
  select * into s_on from oyun.secimler where tur = 'mv_on' and donem = d order by id desc limit 1;
  select * into s_mv from oyun.secimler where tur = 'mv' and donem = d order by id desc limit 1;
  kesin := coalesce(s_on.durum = 'tamam', false);
  yontem := oyun.parti_yontem(pa.id, 'mv');
  son := least(t + interval '3 days', s_mv.oy_bit - make_interval(mins => ay.sure_dk));
  if p_il is not null then select * into il from oyun.iller where id = p_il; end if;
  return jsonb_build_object(
    'acik', ay.aktif and s_mv.id is not null and s_mv.durum = 'bekliyor' and s_on.id is not null and t >= s_on.basvuru_bas
            and son >= t + interval '15 minutes',
    'donem', d, 'kesin', kesin, 'yontem', yontem,
    'aday_hazir', kesin or yontem = 'atama',
    'kural_yazi', case when kesin then 'Listeler kesinleşti: listedeki adaylarınla lansman yapabilirsin.'
                       when yontem = 'atama' then 'Genel Başkan listesindeki (atadığın) adaylarla lansman yapabilirsin. Listeden çıkardığın aday lansmandan da düşer.'
                       else format('Partin adaylarını ön seçimle belirliyor. Listeler ön seçim sonuçlanınca (%s) kesinleşir; lansmanı o zaman listedeki adaylarla düzenleyebilirsin.', oyun.tr_tarih_saat(s_on.oy_bit)) end,
    'en_erken', t + interval '15 minutes', 'en_gec', son, 'sure_dk', ay.sure_dk,
    'parti', jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'amblem', pa.amblem, 'kasa', pa.kasa),
    'bedel', jsonb_build_object('il_taban', ay.il_taban, 'il_sandalye', ay.il_sandalye, 'ulke', ay.ulke,
      'secili', case when p_il is null then ay.ulke else oyun.alv_bedel(p_il::smallint) end),
    'gunluk_sinir', ay.gunluk_sinir,
    'son24', (select count(*) from oyun.aday_lansman l where l.parti_id = pa.id and l.olusturma > t - interval '24 hours' and l.durum <> 'kaldirildi'),
    'il', case when il.id is null then null else jsonb_build_object('id', il.id, 'ad', il.ad, 'kontenjan', coalesce(il.mv_secim, il.mv)) end,
    'adaylar', coalesce((
      select jsonb_agg(jsonb_build_object('aday_id', a.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
               'il_id', a.il_id, 'il', (select ad from oyun.iller where id = a.il_id), 'sira', coalesce(a.sira, a.atama_sira))
             order by a.il_id, coalesce(a.sira, a.atama_sira), a.id)
      from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
      where a.secim_id = s_on.id and a.parti_id = pa.id
        and (p_il is null or a.il_id = p_il)
        and case when kesin then a.sira is not null when yontem = 'atama' then a.atama_sira is not null else false end), '[]'::jsonb),
    'lansmanlarim', coalesce((
      select jsonb_agg(oyun.alv_lansman_ozet(l, t) || jsonb_build_object('bedel', l.bedel) order by l.bas desc)
      from oyun.aday_lansman l where l.parti_id = pa.id and l.donem = d), '[]'::jsonb));
end $$;

-- ============ LANSMAN: DÜZENLE / İPTAL ============
create or replace function public.aday_lansman_duzenle(p_il integer, p_bas timestamptz, p_baslik text, p_metin text,
  p_adaylar bigint[], p_notlar text[] default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d text := oyun.alv_donem(null);
  pa oyun.partiler; s_on oyun.secimler; s_mv oyun.secimler; ay oyun.aday_lansman_ayar; il oyun.iller;
  kesin boolean; yontem text; b text; m text; bedel numeric; lid bigint; ust int; n int; i int; nt text; a oyun.adaylar;
  il_ad text; bitis timestamptz;
begin
  select * into pa from oyun.partiler where id = oyun.parti_gorevli(p.id, array['secim', 'tanitim']) and not kapali for update;
  if pa.id is null then raise exception 'Aday lansmanını Genel Başkan ile Seçim İşlerinden ya da Tanıtım ve Medyadan Sorumlu Genel Başkan Yardımcısı düzenler.'; end if;
  if oyun.mod_kisit_aktif(p.id, 'sustur') then raise exception 'Hesabın susturulmuşken lansman duyurusu yapamazsın.'; end if;
  select * into ay from oyun.aday_lansman_ayar where id = 1;
  if not ay.aktif then raise exception 'Aday lansmanları şu anda yönetim tarafından kapalı.'; end if;
  select * into s_on from oyun.secimler where tur = 'mv_on' and donem = d order by id desc limit 1;
  select * into s_mv from oyun.secimler where tur = 'mv' and donem = d order by id desc limit 1;
  if s_mv.id is null or s_mv.durum <> 'bekliyor' or s_on.id is null then raise exception 'Takvimde lansman yapılabilecek bir genel seçim yok.'; end if;
  if t < s_on.basvuru_bas then raise exception 'Lansmanlar aday adaylığı başvuruları açılınca (%) başlar.', oyun.tr_tarih_saat(s_on.basvuru_bas); end if;
  kesin := s_on.durum = 'tamam';
  yontem := oyun.parti_yontem(pa.id, 'mv');

  if p_bas is null or p_bas < t + interval '15 minutes' then raise exception 'Lansmanı en erken 15 dakika sonrasına koyabilirsin.'; end if;
  if p_bas > t + interval '3 days' then raise exception 'Lansmanı en fazla 3 gün sonrasına planlayabilirsin.'; end if;
  bitis := p_bas + make_interval(mins => ay.sure_dk);
  if bitis > s_mv.oy_bit then raise exception 'Lansman genel seçim oylaması bitmeden (%) sona ermeli.', oyun.tr_tarih_saat(s_mv.oy_bit); end if;
  if not kesin and yontem = 'onsecim' then
    raise exception 'Partin adaylarını ön seçimle belirliyor; listeler ön seçim sonuçlanınca (%) kesinleşir, lansmanı o zaman düzenleyebilirsin.', oyun.tr_tarih_saat(s_on.oy_bit);
  end if;

  b := oyun.metin_temizle(p_baslik, 90);
  if char_length(b) < 5 then raise exception 'Lansman başlığı en az 5 karakter olmalı.'; end if;
  m := oyun.metin_temizle(p_metin, 1500);
  if char_length(m) < 30 then raise exception 'Lansman sunuşu en az 30 karakter olmalı.'; end if;

  if p_il is not null then
    select * into il from oyun.iller where id = p_il;
    if il.id is null then raise exception 'İl bulunamadı.'; end if;
    ust := least(12, coalesce(il.mv_secim, il.mv));
    if exists (select 1 from oyun.aday_lansman l where l.parti_id = pa.id and l.donem = d and l.il_id = il.id and l.durum <> 'iptal') then
      raise exception 'Partin bu seçim döneminde % için zaten bir lansman düzenledi.', il.ad; end if;
  else
    ust := 12;
    if exists (select 1 from oyun.aday_lansman l where l.parti_id = pa.id and l.donem = d and l.il_id is null and l.durum <> 'iptal') then
      raise exception 'Partin bu seçim döneminde Türkiye geneli lansmanını zaten düzenledi.'; end if;
  end if;
  if (select count(*) from oyun.aday_lansman l where l.parti_id = pa.id and l.olusturma > t - interval '24 hours' and l.durum <> 'kaldirildi') >= ay.gunluk_sinir then
    raise exception 'Partin 24 saatte en çok % lansman duyurabilir.', ay.gunluk_sinir; end if;
  if exists (select 1 from oyun.aday_lansman l where l.parti_id = pa.id and l.durum = 'planli'
               and l.bas < bitis and l.bit > p_bas and l.il_id is not distinct from il.id) then
    raise exception 'Bu saatte partinin aynı yerde başka bir lansmanı var.'; end if;

  n := coalesce(cardinality(p_adaylar), 0);
  if n < 1 then raise exception 'Lansmanda en az bir aday tanıtmalısın.'; end if;
  if n > ust then raise exception 'Bu lansmanda en çok % aday tanıtabilirsin.', ust; end if;
  if (select count(distinct x) from unnest(p_adaylar) x) <> n then raise exception 'Aynı adayı iki kez ekleyemezsin.'; end if;
  if p_notlar is not null and cardinality(p_notlar) > n then raise exception 'Aday notu sayısı aday sayısını aşıyor.'; end if;

  for i in 1..n loop
    select * into a from oyun.adaylar where id = p_adaylar[i];
    if a.id is null or a.secim_id <> s_on.id or a.parti_id is distinct from pa.id then
      raise exception 'Seçilen adaylardan biri partinin bu seçimdeki adayı değil.'; end if;
    if p_il is not null and a.il_id <> p_il then raise exception 'Bu lansmanda yalnız % adayları tanıtılabilir.', il.ad; end if;
    if kesin and a.sira is null then raise exception '% kesin listede yer almıyor.', oyun.alv_gorunen_ad(a.user_id); end if;
    if not kesin and yontem = 'atama' and a.atama_sira is null then
      raise exception '% Genel Başkan listesinde değil; önce Aday belirleme ekranından listeye ekle.', oyun.alv_gorunen_ad(a.user_id); end if;
  end loop;

  bedel := oyun.alv_bedel(il.id);
  if bedel > 0 then
    update oyun.partiler set kasa = kasa - bedel where id = pa.id and kasa >= bedel;
    if not found then raise exception 'Parti kasasında yeterli para yok (lansman bedeli % ₺).', oyun.tl(bedel); end if;
  end if;
  insert into oyun.aday_lansman(parti_id, donem, il_id, baslik, metin, bas, bit, bedel, duzenleyen, olusturma)
    values (pa.id, d, il.id, b, m, p_bas, bitis, bedel, p.id, t) returning id into lid;
  for i in 1..n loop
    nt := null;
    if p_notlar is not null and i <= cardinality(p_notlar) and nullif(btrim(coalesce(p_notlar[i], '')), '') is not null then
      nt := oyun.metin_temizle(p_notlar[i], 240);
    end if;
    insert into oyun.aday_lansman_aday(lansman_id, aday_id, sira, not_metin) values (lid, p_adaylar[i], i, nt);
  end loop;
  il_ad := coalesce(il.ad, 'Türkiye geneli');
  if bedel > 0 then
    insert into oyun.parti_hareket(parti_id, zaman, tutar, tur, aciklama)
      values (pa.id, t, -bedel, 'lansman', format('Aday tanıtım lansmanı · %s · %s', il_ad, b));
  end if;
  perform oyun.olay('secim', format('%s %s aday lansmanı düzenleyecek: “%s” (%s).', pa.kisa, il_ad, b,
    to_char(p_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), il.id, pa.id, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
  select a2.user_id, t, format('%s seni “%s” aday tanıtım lansmanına aldı (%s · %s). Aday Vitrini''nden takip edebilirsin.',
           pa.kisa, b, il_ad, to_char(p_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'))
  from oyun.aday_lansman_aday x join oyun.adaylar a2 on a2.id = x.aday_id
  where x.lansman_id = lid and a2.user_id <> p.id;
  return jsonb_build_object('tamam', true, 'id', lid, 'bedel', bedel, 'bas', p_bas, 'bit', bitis);
end $$;

create or replace function public.aday_lansman_iptal(p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); l oyun.aday_lansman; pa oyun.partiler;
begin
  select * into l from oyun.aday_lansman where id = p_id for update;
  if l.id is null then raise exception 'Lansman bulunamadı.'; end if;
  if oyun.parti_gorevli(p.id, array['secim', 'tanitim']) is distinct from l.parti_id then
    raise exception 'Lansmanı yalnız partinin Genel Başkanı ya da seçim/tanıtım yetkili yardımcısı iptal edebilir.'; end if;
  if l.durum <> 'planli' then raise exception 'Bu lansman zaten iptal edilmiş ya da kaldırılmış.'; end if;
  if t >= l.bas then raise exception 'Başlamış ya da bitmiş lansman iptal edilemez.'; end if;
  update oyun.aday_lansman set durum = 'iptal' where id = l.id;
  if l.bedel > 0 then
    update oyun.partiler set kasa = kasa + l.bedel where id = l.parti_id returning * into pa;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, tur, aciklama)
      values (l.parti_id, t, l.bedel, 'lansman', format('Aday lansmanı iptal edildi, bedel iade · %s', l.baslik));
  end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
  select k.user_id, t, format('Hatırlatma istediğin “%s” aday lansmanı parti tarafından iptal edildi.', l.baslik)
  from oyun.aday_lansman_katilim k where k.lansman_id = l.id and k.hatirlat limit 3000;
  return jsonb_build_object('tamam', true, 'iade', l.bedel);
end $$;

-- ============ LANSMAN: DETAY VE KATILIM ============
create or replace function public.aday_lansmanlari(p_donem text default null, p_il integer default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d text := oyun.alv_donem(p_donem);
begin
  return coalesce((
    select jsonb_agg(oyun.alv_lansman_ozet(l, t) order by (l.bit <= t), case when l.bit > t then l.bas end, l.bas desc)
    from oyun.aday_lansman l
    where l.id in (select x.id from oyun.aday_lansman x
                   where x.donem = d and x.durum = 'planli' and (p_il is null or x.il_id = p_il or x.il_id is null)
                   order by (x.bit <= t), case when x.bit > t then x.bas end, x.bas desc limit 80)), '[]'::jsonb);
end $$;

create or replace function public.aday_lansman_detay(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); l oyun.aday_lansman; k oyun.aday_lansman_katilim; md boolean;
begin
  select * into l from oyun.aday_lansman where id = p_id;
  md := p.yonetici or exists (select 1 from oyun.moderatorler m where m.user_id = p.id);
  if l.id is null or (l.durum = 'kaldirildi' and not md) then raise exception 'Lansman bulunamadı ya da yönetim tarafından kaldırıldı.'; end if;
  select * into k from oyun.aday_lansman_katilim where lansman_id = l.id and user_id = p.id;
  return oyun.alv_lansman_ozet(l, t) || jsonb_build_object(
    'metin', l.metin, 'simdi', t, 'kaldir_gerekce', case when md then l.kaldir_gerekce end,
    'duzenleyen', jsonb_build_object('kad', oyun.kad(l.duzenleyen), 'ad', oyun.alv_gorunen_ad(l.duzenleyen)),
    'adaylar', oyun.alv_lansman_adaylar(l.id, p.id),
    'katildim', k.katildi is not null, 'hatirlatiyor', coalesce(k.hatirlat, false),
    'yetkili', oyun.parti_gorevli(p.id, array['secim', 'tanitim']) is not distinct from l.parti_id,
    'mod', md,
    'mesajlar', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
               'parti', (select jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = pr.parti_id),
               'metin', x.metin, 'zaman', x.zaman, 'benim', x.user_id = p.id) order by x.id)
      from (select * from oyun.aday_lansman_mesaj m where m.lansman_id = l.id and not m.silindi order by m.id desc limit 60) x
      join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb));
end $$;

-- Başlamadan önce: hatırlat (aç/kapat). Canlıyken: salona gir.
create or replace function public.aday_lansman_katil(p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); l oyun.aday_lansman; k oyun.aday_lansman_katilim;
begin
  select * into l from oyun.aday_lansman where id = p_id;
  if l.id is null or l.durum <> 'planli' then raise exception 'Lansman bulunamadı ya da iptal edildi.'; end if;
  if t >= l.bit then raise exception 'Bu lansman sona erdi.'; end if;
  select * into k from oyun.aday_lansman_katilim where lansman_id = l.id and user_id = p.id;
  if t < l.bas then
    insert into oyun.aday_lansman_katilim as k0 (lansman_id, user_id, hatirlat, zaman) values (l.id, p.id, true, t)
      on conflict (lansman_id, user_id) do update set hatirlat = not k0.hatirlat;
    return jsonb_build_object('tamam', true, 'hatirlat', not coalesce(k.hatirlat, false));
  end if;
  insert into oyun.aday_lansman_katilim as k0 (lansman_id, user_id, katildi, zaman) values (l.id, p.id, t, t)
    on conflict (lansman_id, user_id) do update set katildi = coalesce(k0.katildi, excluded.katildi);
  return jsonb_build_object('tamam', true, 'katildi', true);
end $$;

create or replace function public.aday_lansman_alkis(p_id bigint, p_aday bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); l oyun.aday_lansman;
begin
  select * into l from oyun.aday_lansman where id = p_id;
  if l.id is null or l.durum <> 'planli' then raise exception 'Lansman bulunamadı.'; end if;
  if t < l.bas then raise exception 'Lansman henüz başlamadı; başlayınca alkışlayabilirsin.'; end if;
  if t >= l.bit then raise exception 'Lansman sona erdi.'; end if;
  if not exists (select 1 from oyun.aday_lansman_aday where lansman_id = l.id and aday_id = p_aday) then raise exception 'Bu aday lansmanda yok.'; end if;
  insert into oyun.aday_lansman_katilim as k0 (lansman_id, user_id, katildi, zaman) values (l.id, p.id, t, t)
    on conflict (lansman_id, user_id) do update set katildi = coalesce(k0.katildi, excluded.katildi);
  insert into oyun.aday_lansman_alkis(lansman_id, aday_id, user_id, zaman) values (l.id, p_aday, p.id, t) on conflict do nothing;
  if not found then raise exception 'Bu adayı zaten alkışladın.'; end if;
  return jsonb_build_object('tamam', true,
    'alkis', (select count(*) from oyun.aday_lansman_alkis where lansman_id = l.id and aday_id = p_aday));
end $$;

create or replace function public.aday_lansman_mesaj_yaz(p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); l oyun.aday_lansman; m text; mid bigint;
begin
  select * into l from oyun.aday_lansman where id = p_id;
  if l.id is null or l.durum <> 'planli' then raise exception 'Lansman bulunamadı.'; end if;
  if t < l.bas then raise exception 'Lansman henüz başlamadı.'; end if;
  if t >= l.bit then raise exception 'Lansman sona erdi; mesaj yazılamaz.'; end if;
  if oyun.mod_kisit_aktif(p.id, 'sustur') or coalesce(p.susturma_bitis > t, false) then raise exception 'Hesabın susturulmuşken mesaj yazamazsın.'; end if;
  m := oyun.metin_temizle(p_metin, 200);
  if exists (select 1 from oyun.aday_lansman_mesaj x where x.user_id = p.id and x.zaman > t - interval '20 seconds') then
    raise exception 'Biraz yavaş: 20 saniyede bir mesaj yazabilirsin.'; end if;
  if (select count(*) from oyun.aday_lansman_mesaj x where x.lansman_id = l.id and x.user_id = p.id) >= 15 then
    raise exception 'Bu lansmanda en çok 15 mesaj yazabilirsin.'; end if;
  insert into oyun.aday_lansman_katilim as k0 (lansman_id, user_id, katildi, zaman) values (l.id, p.id, t, t)
    on conflict (lansman_id, user_id) do update set katildi = coalesce(k0.katildi, excluded.katildi);
  insert into oyun.aday_lansman_mesaj(lansman_id, user_id, metin, zaman) values (l.id, p.id, m, t) returning id into mid;
  return jsonb_build_object('tamam', true, 'id', mid);
end $$;

-- ============ YÖNETİM (İçerik Masası) ============
create or replace function public.aday_lansman_kaldir(p_id bigint, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); l oyun.aday_lansman; g text := btrim(coalesce(p_gerekce, ''));
begin
  if char_length(g) < 5 then raise exception 'Kaldırma gerekçesi en az 5 karakter olmalı.'; end if;
  select * into l from oyun.aday_lansman where id = p_id for update;
  if l.id is null then raise exception 'Lansman bulunamadı.'; end if;
  if l.durum = 'kaldirildi' then raise exception 'Lansman zaten kaldırıldı.'; end if;
  update oyun.aday_lansman set durum = 'kaldirildi', kaldir_gerekce = left(g, 500) where id = l.id;
  perform oyun.bildir(l.duzenleyen, format('Oyun Yönetimi “%s” aday lansmanını kaldırdı. Gerekçe: %s. Lansman bedeli iade edilmez.', l.baslik, left(g, 300)), t);
  if l.duzenleyen <> (select gb from oyun.partiler where id = l.parti_id) then
    perform oyun.bildir((select gb from oyun.partiler where id = l.parti_id), format('Oyun Yönetimi partinin “%s” aday lansmanını kaldırdı. Gerekçe: %s.', l.baslik, left(g, 300)), t);
  end if;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.aday_lansman_mesaj_sil(p_mesaj bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  update oyun.aday_lansman_mesaj set silindi = true where id = p_mesaj and not silindi;
  if not found then raise exception 'Mesaj bulunamadı ya da zaten silinmiş.'; end if;
  return jsonb_build_object('tamam', true);
end $$;

-- ============ ZAMANLAYICI: başlangıç duyurusu ve sonuç haberi ============
create or replace function oyun.aday_lansman_tick()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi(); l oyun.aday_lansman; pa oyun.partiler; il_ad text; adlar text; n_bas int := 0; n_son int := 0; hata int := 0;
  katilim int; alkis int; en text; mesaj int;
begin
  for l in select * from oyun.aday_lansman x where x.durum = 'planli' and not x.duyuruldu and x.bas <= t order by x.bas limit 100 loop
    begin
      select * into pa from oyun.partiler where id = l.parti_id;
      il_ad := coalesce((select ad from oyun.iller where id = l.il_id), 'Türkiye geneli');
      select string_agg(coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad), ', ' order by la.sira) into adlar
        from oyun.aday_lansman_aday la join oyun.adaylar a on a.id = la.aday_id join oyun.profiller pr on pr.id = a.user_id
        where la.lansman_id = l.id;
      update oyun.aday_lansman set duyuruldu = true where id = l.id;
      if t < l.bit then
        perform oyun.ajans_yayinla('aday-lansman-' || l.id || '-bas', 'adaylar',
          format('%s %s aday lansmanı başladı: “%s”', pa.kisa, il_ad, l.baslik),
          format('Sahnede: %s', coalesce(adlar, '-')),
          format('%s, %s milletvekili adaylarını kamuoyuna tanıtıyor. Sahnedeki adaylar: %s. Lansman %s''e kadar canlı; Aday Vitrini''nden katılıp adayları alkışlayabilirsin.',
                 pa.ad, il_ad, coalesce(adlar, '-'), to_char(l.bit at time zone 'Europe/Istanbul', 'HH24:MI')),
          66, pa.id, l.il_id, t);
        insert into oyun.bildirimler(user_id, zaman, metin)
        select u, t, format('Canlı: %s %s aday lansmanı başladı — “%s”. Aday Vitrini''nden katıl.', pa.kisa, il_ad, l.baslik)
        from (select k.user_id u from oyun.aday_lansman_katilim k where k.lansman_id = l.id and k.hatirlat
              union
              select pr.id from oyun.profiller pr where pr.parti_id = l.parti_id and not pr.yasakli
                and (l.il_id is null or pr.il_id = l.il_id)) x
        limit 3000;
      end if;
      n_bas := n_bas + 1;
    exception when others then hata := hata + 1;
    end;
  end loop;

  for l in select * from oyun.aday_lansman x where x.durum = 'planli' and not x.ozet_yazildi and x.bit <= t order by x.bit limit 100 loop
    begin
      select * into pa from oyun.partiler where id = l.parti_id;
      il_ad := coalesce((select ad from oyun.iller where id = l.il_id), 'Türkiye geneli');
      select count(*) into katilim from oyun.aday_lansman_katilim k where k.lansman_id = l.id and k.katildi is not null;
      select count(*) into alkis from oyun.aday_lansman_alkis k where k.lansman_id = l.id;
      select count(*) into mesaj from oyun.aday_lansman_mesaj k where k.lansman_id = l.id and not k.silindi;
      select coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad) || ' (' || c || ' alkış)' into en
        from (select x.aday_id, count(*) c from oyun.aday_lansman_alkis x where x.lansman_id = l.id group by x.aday_id order by count(*) desc limit 1) z
        join oyun.adaylar a on a.id = z.aday_id join oyun.profiller pr on pr.id = a.user_id;
      update oyun.aday_lansman set ozet_yazildi = true, duyuruldu = true where id = l.id;
      perform oyun.ajans_yayinla('aday-lansman-' || l.id || '-son', 'adaylar',
        format('%s %s aday lansmanı tamamlandı: %s katılımcı, %s alkış', pa.kisa, il_ad, katilim, alkis),
        coalesce('En çok alkışlanan: ' || en, 'Lansman sona erdi.'),
        format('%s partisinin “%s” başlıklı %s aday tanıtım lansmanı sona erdi. Salona %s oyuncu katıldı, adaylar toplam %s alkış aldı, %s destek mesajı yazıldı.%s',
               pa.ad, l.baslik, il_ad, katilim, alkis, mesaj, coalesce(' En çok alkışlanan aday: ' || en || '.', '')),
        52, pa.id, l.il_id, t);
      insert into oyun.bildirimler(user_id, zaman, metin)
      select distinct u, t, format('“%s” lansmanı bitti: %s katılımcı, %s alkış%s.', l.baslik, katilim, alkis, coalesce(' · En çok alkışlanan: ' || en, ''))
      from (select l.duzenleyen u union select a.user_id from oyun.aday_lansman_aday la join oyun.adaylar a on a.id = la.aday_id where la.lansman_id = l.id) x;
      n_son := n_son + 1;
    exception when others then hata := hata + 1;
    end;
  end loop;
  return jsonb_build_object('baslayan', n_bas, 'biten', n_son, 'hata', hata);
end $$;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
    values ('aday_lansman', 'select oyun.aday_lansman_tick()', 5, 2, 129, true)
    on conflict (adim) do nothing;
  end if;
end $z$;

-- ============ YÖNETİM PORTALI AYARLARI ============
do $p$
begin
  if to_regclass('oyun.yp_ayar_katalog') is null then return; end if;
  insert into oyun.yp_ayar_katalog(anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, sira, aktif) values
  ('lansman.aktif','oyun.aday_lansman_ayar','aktif',null,'siyaset','Aday lansmanları','Partiler milletvekili adayları için tanıtım lansmanı düzenleyebilir. Kapatılırsa yeni lansman açılamaz; planlananlar sürer.','evet_hayir',null,null,null,null,'orta','Hemen.',200,true),
  ('lansman.il_taban','oyun.aday_lansman_ayar','il_taban',null,'siyaset','İl lansmanı taban bedeli','Bir il lansmanının sabit bedeli (parti kasasından).','sayi','₺',0,100000000,null,'orta','Yeni lansmanlarda.',201,true),
  ('lansman.il_sandalye','oyun.aday_lansman_ayar','il_sandalye',null,'siyaset','İl lansmanı sandalye başı ek','İlin her milletvekili sandalyesi için tabana eklenen bedel (büyük il daha pahalı).','sayi','₺',0,10000000,null,'orta','Yeni lansmanlarda.',202,true),
  ('lansman.ulke','oyun.aday_lansman_ayar','ulke',null,'siyaset','Türkiye geneli lansman bedeli','Türkiye geneli büyük lansmanın bedeli.','sayi','₺',0,1000000000,null,'orta','Yeni lansmanlarda.',203,true),
  ('lansman.gunluk_sinir','oyun.aday_lansman_ayar','gunluk_sinir',null,'siyaset','Partinin 24 saatteki lansman sınırı','Bir partinin son 24 saatte duyurabileceği en çok lansman.','tamsayi','adet',1,50,null,'dusuk','Hemen.',204,true),
  ('lansman.sure_dk','oyun.aday_lansman_ayar','sure_dk',null,'siyaset','Lansman süresi','Bir lansmanın canlı kaldığı süre.','tamsayi','dk',15,240,null,'dusuk','Yeni lansmanlarda.',205,true)
  on conflict (anahtar) do nothing;
end $p$;

-- ============ YETKİLER ============
revoke all on function oyun.alv_donem(text), oyun.alv_asama(oyun.secimler, oyun.secimler, timestamptz), oyun.alv_asama_yazi(text),
  oyun.alv_gorunen_ad(uuid), oyun.alv_bedel(smallint), oyun.alv_lansman_adaylar(bigint, uuid),
  oyun.alv_lansman_ozet(oyun.aday_lansman, timestamptz), oyun.aday_lansman_tick()
  from public, anon, authenticated;
do $g$
declare f text;
begin
  foreach f in array array['aday_vitrini(text)', 'aday_vitrini_il(integer, text)', 'aday_vitrini_ara(text, text)',
    'aday_lansman_hazirlik(integer)', 'aday_lansman_duzenle(integer, timestamptz, text, text, bigint[], text[])',
    'aday_lansman_iptal(bigint)', 'aday_lansmanlari(text, integer)', 'aday_lansman_detay(bigint)', 'aday_lansman_katil(bigint)',
    'aday_lansman_alkis(bigint, bigint)', 'aday_lansman_mesaj_yaz(bigint, text)', 'aday_lansman_kaldir(bigint, text)',
    'aday_lansman_mesaj_sil(bigint)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $g$;
