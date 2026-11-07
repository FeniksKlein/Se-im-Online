-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 176) PANO İŞLETME HAKKI İHALESİ (07.11.2026)
--
--  Gerçek hayattaki açık hava reklam alanı kiralamasına (2886 sayılı Devlet İhale Kanunu,
--  kapalı teklif usulü) benzer:
--   • İdare: il panoları için il belediyesi, ülke geneli dev panolar için Ulaştırma ve Altyapı
--     Bakanlığı (Karayolları). İşletmecisi olmayan ya da sözleşmesi bitmek üzere olan panolar için
--     ihale ilanı kendiliğinden yayımlanır (ülke geneli her zaman; il panoları son 7 günde oyuncusu
--     olan illerde). Teklif süresi 48 saat, işletme süresi 14 gün (Süper Yönetici Portalı'ndan değişir).
--   • Muhammen bedel: devletin pano tarifesi × pano sayısı × süre × beklenen doluluk.
--     En düşük teklif muhammen bedelin %50'si (oyun dengesi için ayarlanabilir).
--   • Kapalı teklif: teklif tutarları ihale bitene kadar gizlidir; her oyuncu/şirket bir kez
--     teklif verir, değiştiremez. Teklifle birlikte %3 geçici teminat tahsil edilir.
--   • İhale yetkilisi yasağı: o ilin belediye başkanı (ülke genelinde Cumhurbaşkanı ve Ulaştırma
--     Bakanı) ve yönettiği/ortağı olduğu şirketler teklif veremez.
--   • Tekel sınırı: bir oyuncu (yönettiği şirketlerle birlikte) aynı anda en fazla 3 işletme tutar.
--   • Sonuç: en yüksek teklifin kalan bedeli tahsil edilir ve sözleşme yapılır. Ödeyemeyen kazananın
--     teminatı idareye gelir kaydedilir, sıradaki teklife geçilir. Kaybedenlerin teminatı iade edilir.
--     İhale bedeli (il ihaleleri dahil) devlete, Hazine'ye gelir yazılır.
--   • İşletmeci her panonun günlük fiyatını kendisi belirler. Kira geliri işletmeciye geçer; her
--     kiralamadan %10 ilan ve reklam vergisi belediyeye (ülke genelinde Hazine'ye) kesilir.
--   • İşletmecisi olmayan panoları idare eski tarifeyle doğrudan kiralamaya devam eder.
--  Oyuncu verisini silmez veya sıfırlamaz. Tekrar çalıştırmak güvenlidir.
-- =====================================================================

alter table oyun.pano_ayar add column if not exists ihale_acik boolean not null default true;
alter table oyun.pano_ayar add column if not exists ihale_teklif_saat int not null default 48;
alter table oyun.pano_ayar add column if not exists ihale_isletme_gun int not null default 14;
alter table oyun.pano_ayar add column if not exists ihale_asgari_oran numeric not null default 0.5;
alter table oyun.pano_ayar add column if not exists ihale_teminat_oran numeric not null default 0.03;
alter table oyun.pano_ayar add column if not exists ihale_doluluk numeric not null default 0.25;
alter table oyun.pano_ayar add column if not exists ihale_en_fazla int not null default 3;
alter table oyun.pano_ayar add column if not exists ihale_aktif_gun int not null default 7;
alter table oyun.pano_ayar add column if not exists reklam_vergisi numeric not null default 0.10;

create table if not exists oyun.pano_ihale (
  id            bigint generated always as identity primary key,
  kapsam        text not null check (kapsam in ('il', 'ulke')),
  il_id         smallint,
  slot          int not null,
  isletme_gun   int not null,
  isletme_bas   timestamptz not null,
  muhammen      numeric not null,
  asgari        numeric not null,
  teminat_oran  numeric not null,
  bas           timestamptz not null default now(),
  bit           timestamptz not null,
  durum         text not null default 'acik' check (durum in ('acik', 'sonuclandi', 'teklifsiz', 'bozuldu', 'iptal')),
  kazanan_teklif bigint,
  bedel         numeric,
  olusturma     timestamptz not null default now()
);
create unique index if not exists pano_ihale_tek_acik on oyun.pano_ihale (kapsam, coalesce(il_id, 0)) where durum = 'acik';
create index if not exists pano_ihale_durum on oyun.pano_ihale (durum, bit);
alter table oyun.pano_ihale enable row level security;

create table if not exists oyun.pano_ihale_teklif (
  id          bigint generated always as identity primary key,
  ihale_id    bigint not null references oyun.pano_ihale(id),
  teklif_tur  text not null check (teklif_tur in ('oyuncu', 'sirket')),
  teklif_id   bigint,
  user_id     uuid not null,
  teklif_ad   text not null,
  tutar       numeric not null,
  teminat     numeric not null,
  zaman       timestamptz not null default now(),
  durum       text not null default 'bekliyor' check (durum in ('bekliyor', 'kazandi', 'kaybetti', 'irat'))
);
create unique index if not exists pano_ihale_teklif_tek on oyun.pano_ihale_teklif
  (ihale_id, teklif_tur, coalesce(teklif_id, 0), (case when teklif_tur = 'oyuncu' then user_id else '00000000-0000-0000-0000-000000000000'::uuid end));
alter table oyun.pano_ihale_teklif enable row level security;

create table if not exists oyun.pano_isletme (
  id              bigint generated always as identity primary key,
  ihale_id        bigint references oyun.pano_ihale(id),
  kapsam          text not null check (kapsam in ('il', 'ulke')),
  il_id           smallint,
  slot            int not null,
  isletmeci_tur   text not null check (isletmeci_tur in ('oyuncu', 'sirket')),
  isletmeci_id    bigint,
  isletmeci_user  uuid not null,
  isletmeci_ad    text not null,
  bedel           numeric not null,
  bas             timestamptz not null,
  bit             timestamptz not null,
  fiyatlar        jsonb not null,
  gelir           numeric not null default 0,
  vergi           numeric not null default 0,
  durum           text not null default 'aktif' check (durum in ('aktif', 'bitti', 'fesih')),
  olusturma       timestamptz not null default now()
);
create index if not exists pano_isletme_yer on oyun.pano_isletme (kapsam, il_id, bit) where durum = 'aktif';
alter table oyun.pano_isletme enable row level security;

alter table oyun.pano_yayin add column if not exists isletme_id bigint;
alter table oyun.pano_yayin add column if not exists vergi numeric not null default 0;

-- ---------------------------------------------------------------------
-- YARDIMCILAR
-- ---------------------------------------------------------------------
create or replace function oyun.pano_isletme_bul(p_kapsam text, p_il smallint, p_an timestamptz default now()) returns oyun.pano_isletme
language sql stable set search_path = '' as $$
  select * from oyun.pano_isletme
   where durum = 'aktif' and kapsam = p_kapsam and il_id is not distinct from (case when p_kapsam = 'il' then p_il end)
     and bas <= p_an and bit > p_an
   order by bas desc limit 1
$$;

-- Henüz başlamamış bir sözleşme varsa başlangıcı (idare o tarihten sonrasını kiralayamaz)
create or replace function oyun.pano_isletme_sonraki(p_kapsam text, p_il smallint) returns timestamptz
language sql stable set search_path = '' as $$
  select min(bas) from oyun.pano_isletme
   where durum = 'aktif' and kapsam = p_kapsam and il_id is not distinct from (case when p_kapsam = 'il' then p_il end) and bas > now()
$$;

create or replace function oyun.pano_slot_bos(p_kapsam text, p_il smallint, p_slot int) returns timestamptz
language sql stable set search_path = '' as $$
  select greatest(now(), coalesce((select max(y.bit) from oyun.pano_yayin y
                                    where y.durum = 'aktif' and y.kapsam = p_kapsam and y.slot = p_slot
                                      and y.il_id is not distinct from (case when p_kapsam = 'il' then p_il end)), now()))
$$;

create or replace function oyun.pano_idare_ad(p_kapsam text, p_il smallint) returns text
language sql stable set search_path = '' as $$
  select case when p_kapsam = 'il' then coalesce((select i.ad from oyun.iller i where i.id = p_il), '') || ' Belediyesi'
              else 'Ulaştırma ve Altyapı Bakanlığı (Karayolları)' end
$$;

-- Muhammen bedel: devlet tarifesi × pano × gün × beklenen doluluk
create or replace function oyun.pano_muhammen(p_kapsam text, p_il smallint, p_gun int) returns numeric
language plpgsql stable set search_path = '' as $$
declare a oyun.pano_ayar; nuf numeric; gs numeric; baz numeric; endeks numeric;
begin
  select * into a from oyun.pano_ayar where id = 1;
  if p_kapsam = 'il' then
    select e.nufus, e.gsyh_kisi_usd into nuf, gs from oyun.il_ekonomi e where e.il_id = p_il;
    nuf := greatest(coalesce(nuf, 500000), 50000); gs := greatest(coalesce(gs, 12000), 5000);
    baz := a.il_taban * power(nuf / 1000000.0, 0.55) * power(gs / 15000.0, 0.6);
  else
    baz := a.ulusal_gunluk;
  end if;
  endeks := greatest(coalesce((select u.endeks from oyun.ulke u where u.id = 1), 1), 0.5);
  return greatest(5000, round(baz * endeks * oyun.pano_slot(p_kapsam, p_il) * p_gun * a.ihale_doluluk / 500) * 500);
end $$;

-- İhale yetkilileri (teklif veremezler)
create or replace function oyun.pano_ihale_yetkilileri(p_kapsam text, p_il smallint) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct m.user_id), '{}') from oyun.makamlar m
   where m.bit is null and m.user_id is not null
     and ((p_kapsam = 'il' and m.tur = 'bel' and m.il_id = p_il)
       or (p_kapsam = 'ulke' and (m.tur = 'cb' or (m.tur = 'bakan' and m.bakanlik = 'ulastirma'))))
$$;

-- İdareye ihale geliri (bedel ya da irat kaydedilen teminat)
create or replace function oyun.pano_ihale_gelir(p_kapsam text, p_il smallint, p_tutar numeric, p_aciklama text)
returns void language plpgsql security definer set search_path = '' as $$
declare kur numeric := nullif(oyun.pazar_tl_milyar(), 0);
begin
  -- İhale bedeli ve irat kaydedilen teminatlar, il ihalesi dahil her zaman devlete (Hazine) gelir yazılır
  if p_tutar = 0 or kur is null then return; end if;
  perform oyun.hazine_kaydet('diger_gelir', p_tutar / kur,
    p_aciklama || case when p_kapsam = 'il' then ' · ' || coalesce((select i.ad from oyun.iller i where i.id = p_il), '') || ' panoları' else '' end);
end $$;

-- Ödeme: şirket gelirleri kâr hesabına faaliyet geliri olarak yazılır
create or replace function oyun.pano_odeme(p_odeme text, p_tur text, p_id bigint, u uuid, p_tutar numeric, p_aciklama text)
returns void language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi();
begin
  if p_tutar = 0 then return; end if;
  if p_odeme = 'oyuncu' then
    update oyun.cuzdan set para = para + p_tutar where user_id = u and para + p_tutar >= 0;
    if not found then raise exception 'Cüzdanında yeterli para yok. Gereken: % ₺', oyun.pano_tl(-p_tutar); end if;
    insert into oyun.hesap_hareket (user_id, zaman, tutar, tur, aciklama) values (u, t, p_tutar, case when p_tutar < 0 then 'gider' else 'gelir' end, p_aciklama);
  elsif p_tur = 'parti' then
    update oyun.partiler set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Parti kasası yetersiz. Gereken: % ₺', oyun.pano_tl(-p_tutar); end if;
    insert into oyun.parti_hareket (parti_id, zaman, tutar, aciklama, tur) values (p_id, t, p_tutar, p_aciklama, case when p_tutar < 0 then 'gider' else 'gelir' end);
  elsif p_tur = 'dernek' then
    update oyun.dernekler set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Dernek kasası yetersiz. Gereken: % ₺', oyun.pano_tl(-p_tutar); end if;
    insert into oyun.dernek_hareket (dernek_id, zaman, tutar, tur, aciklama, user_id) values (p_id, t, p_tutar, case when p_tutar < 0 then 'gider' else 'gelir' end, p_aciklama, u);
  elsif p_tur = 'sirket' then
    update oyun.sirketler set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Şirket kasası yetersiz. Gereken: % ₺', oyun.pano_tl(-p_tutar); end if;
    insert into oyun.sirket_hareket (sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (p_id, t, p_tutar, p_aciklama, greatest(p_tutar, 0), greatest(-p_tutar, 0), 0);
  elsif p_tur = 'gazete' then
    update oyun.oyuncu_gazeteleri set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Gazete kasası yetersiz. Gereken: % ₺', oyun.pano_tl(-p_tutar); end if;
    insert into oyun.gazete_hareket (gazete_id, zaman, tutar, tur, aciklama) values (p_id, t, p_tutar, case when p_tutar < 0 then 'gider' else 'gelir' end, p_aciklama);
  else
    raise exception 'Geçersiz ödeme kaynağı.';
  end if;
end $$;

-- Fiyat: işletmecisi olan panolarda işletmecinin fiyatları
create or replace function oyun.pano_fiyat(p_kapsam text, p_il smallint) returns jsonb
language plpgsql stable set search_path = '' as $$
declare a oyun.pano_ayar; n int; dolu int; nuf numeric; gs numeric; carp numeric := 1; baz numeric; endeks numeric; sezon boolean; g numeric;
  isl oyun.pano_isletme; enaz numeric;
begin
  select * into a from oyun.pano_ayar where id = 1;
  n := oyun.pano_slot(p_kapsam, p_il);
  select count(distinct y.slot) into dolu from oyun.pano_yayin y
   where y.durum = 'aktif' and y.kapsam = p_kapsam and y.il_id is not distinct from (case when p_kapsam = 'il' then p_il end)
     and y.bas <= now() and y.bit > now() and y.slot <= n;
  if p_kapsam = 'il' then
    select e.nufus, e.gsyh_kisi_usd into nuf, gs from oyun.il_ekonomi e where e.il_id = p_il;
    nuf := greatest(coalesce(nuf, 500000), 50000); gs := greatest(coalesce(gs, 12000), 5000);
    select coalesce(i.carpan, 1) into carp from oyun.pano_il_ayar i where i.il_id = p_il;
    carp := coalesce(carp, 1);
    baz := a.il_taban * power(nuf / 1000000.0, 0.55) * power(gs / 15000.0, 0.6);
  else
    baz := a.ulusal_gunluk;
  end if;
  endeks := greatest(coalesce((select u.endeks from oyun.ulke u where u.id = 1), 1), 0.5);
  sezon := oyun.pano_secim_sezonu(p_kapsam, p_il);
  g := baz * endeks * carp * (1 + a.doluluk_carpan * dolu::numeric / greatest(n, 1)) * (case when sezon then a.secim_carpan else 1 end);
  g := greatest(500, round(g / 50) * 50);
  isl := oyun.pano_isletme_bul(p_kapsam, p_il, now());
  if isl.id is not null then
    select min((x #>> '{}')::numeric) into enaz from jsonb_array_elements(isl.fiyatlar) x;
    return jsonb_build_object('gunluk', coalesce(enaz, g), 'devlet_gunluk', g, 'dolu', dolu, 'slot', n, 'doluluk', round(dolu::numeric / greatest(n, 1), 2),
      'sezon', false, 'belediye_carpan', 1, 'fiyatlar', isl.fiyatlar,
      'isletme', jsonb_build_object('id', isl.id, 'ad', isl.isletmeci_ad, 'tur', isl.isletmeci_tur, 'bas', isl.bas, 'bit', isl.bit));
  end if;
  return jsonb_build_object('gunluk', g, 'devlet_gunluk', g, 'baz', round(baz), 'endeks', round(endeks, 4), 'belediye_carpan', carp,
    'dolu', dolu, 'slot', n, 'doluluk', round(dolu::numeric / greatest(n, 1), 2), 'sezon', sezon,
    'sezon_carpan', a.secim_carpan, 'doluluk_carpan', a.doluluk_carpan, 'sonraki_isletme', oyun.pano_isletme_sonraki(p_kapsam, p_il));
end $$;

-- ---------------------------------------------------------------------
-- KİRALAMA (pano seçimiyle): pano_teklif_v2 / pano_kirala_v2
-- ---------------------------------------------------------------------
create or replace function public.pano_teklif_v2(p_kapsam text, p_il integer, p_gun integer, p_slot integer default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.pano_ayar; il smallint; f jsonb; ind numeric; gun int := coalesce(p_gun, 0); bas timestamptz;
  toplam numeric; isl oyun.pano_isletme; n int; s int; gunluk numeric; slotlar jsonb; neden text; sonraki timestamptz; azami int;
begin
  select * into a from oyun.pano_ayar where id = 1;
  if p_kapsam not in ('il', 'ulke') then raise exception 'Pano türü geçersiz.'; end if;
  if gun < 1 or gun > a.en_uzun_gun then raise exception 'Süre 1–% gün arasında olmalı.', a.en_uzun_gun; end if;
  il := case when p_kapsam = 'il' then p_il::smallint end;
  if p_kapsam = 'il' and not exists (select 1 from oyun.iller i where i.id = il) then raise exception 'İl bulunamadı.'; end if;
  n := oyun.pano_slot(p_kapsam, il);
  isl := oyun.pano_isletme_bul(p_kapsam, il, now());
  f := oyun.pano_fiyat(p_kapsam, il);
  select jsonb_agg(jsonb_build_object('slot', x, 'bos', oyun.pano_slot_bos(p_kapsam, il, x),
           'fiyat', case when isl.id is not null then (isl.fiyatlar ->> (x - 1))::numeric else (f ->> 'gunluk')::numeric end) order by x)
    into slotlar from generate_series(1, n) x;
  if p_slot between 1 and n then s := p_slot;
  else
    select (e ->> 'slot')::int into s from jsonb_array_elements(slotlar) e order by (e ->> 'bos')::timestamptz, (e ->> 'fiyat')::numeric limit 1;
  end if;
  bas := oyun.pano_slot_bos(p_kapsam, il, s);
  if isl.id is not null then
    gunluk := (isl.fiyatlar ->> (s - 1))::numeric; ind := 0; toplam := round(gunluk * gun);
    azami := floor(extract(epoch from (isl.bit - bas)) / 86400);
    if bas + make_interval(days => gun) > isl.bit then
      neden := format('İşletmecinin sözleşmesi %s tarihinde bitiyor; bu panoda en fazla %s gün kiralayabilirsin.', to_char(isl.bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'), greatest(azami, 0));
    end if;
  else
    gunluk := (f ->> 'gunluk')::numeric; ind := oyun.pano_indirim(gun); toplam := round(gunluk * gun * (1 - ind));
    sonraki := oyun.pano_isletme_sonraki(p_kapsam, il);
    if sonraki is not null and bas + make_interval(days => gun) > sonraki then
      neden := format('Bu panoların işletmesi %s tarihinde ihaleyi kazanan işletmeciye geçiyor; idareden en fazla %s gün kiralanabilir.', to_char(sonraki at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'), greatest(floor(extract(epoch from (sonraki - bas)) / 86400), 0));
    end if;
  end if;
  if bas > now() + make_interval(days => a.sira_gun) and neden is null then neden := format('Bu pano %s günden uzun süre dolu. Başka bir pano ya da il seç.', a.sira_gun); end if;
  return jsonb_build_object('kapsam', p_kapsam, 'il_id', il, 'il', (select i.ad from oyun.iller i where i.id = il),
    'gun', gun, 'fiyat', f, 'gunluk', gunluk, 'indirim', ind, 'toplam', toplam, 'slot', s, 'slotlar', slotlar,
    'bas', bas, 'bit', bas + make_interval(days => gun), 'hemen', bas <= now() + interval '1 minute', 'sira_dolu', neden is not null, 'neden', neden,
    'isletme', case when isl.id is not null then jsonb_build_object('id', isl.id, 'ad', isl.isletmeci_ad, 'bit', isl.bit) end,
    'vergi_oran', a.reklam_vergisi,
    'gelir_yeri', case when isl.id is not null then isl.isletmeci_ad || ' (işletmeci) · %' || round(a.reklam_vergisi * 100) || ' ilan ve reklam vergisi ' || oyun.pano_idare_ad(p_kapsam, il)
                       when p_kapsam = 'il' then (select i.ad from oyun.iller i where i.id = il) || ' Belediyesi kasası' else 'Hazine (harç ve ücret geliri)' end,
    'yasak_uyari', a.secim_gunu_yasak);
end $$;

create or replace function public.pano_kirala_v2(p_afis bigint, p_kapsam text, p_il integer, p_gun integer, p_odeme_tur text, p_beklenen numeric default null, p_slot integer default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.pano_ayar; f oyun.afis; sahip_ad text; il smallint; fy jsonb; n int; s int;
  ind numeric; gunluk numeric; toplam numeric; v_vergi numeric := 0; bas timestamptz; yid bigint; aciklama text; odeme text;
  isl oyun.pano_isletme; sonraki timestamptz; ilad text;
begin
  select * into a from oyun.pano_ayar where id = 1;
  if not a.acik then raise exception 'Reklam panoları şu anda kapalı.'; end if;
  if p_kapsam not in ('il', 'ulke') then raise exception 'Pano türü geçersiz.'; end if;
  if coalesce(p_gun, 0) < 1 or p_gun > a.en_uzun_gun then raise exception 'Süre 1–% gün arasında olmalı.', a.en_uzun_gun; end if;
  il := case when p_kapsam = 'il' then p_il::smallint end;
  if p_kapsam = 'il' and not exists (select 1 from oyun.iller i where i.id = il) then raise exception 'İl bulunamadı.'; end if;
  ilad := case when p_kapsam = 'il' then (select i.ad from oyun.iller i where i.id = il) else 'Ülke geneli' end;
  select * into f from oyun.afis where id = p_afis and not silindi;
  if f.id is null then raise exception 'Afiş bulunamadı.'; end if;
  sahip_ad := oyun.pano_tasarim_yetki(p.id, f.sahip_tur, f.sahip_id);
  if f.sahip_tur = 'oyuncu' and f.sahip_user <> p.id then raise exception 'Bu afiş senin değil.'; end if;
  perform oyun.afis_dogrula(f.tasarim);
  odeme := case when p_odeme_tur = 'oyuncu' or f.sahip_tur = 'oyuncu' then 'oyuncu' else 'kasa' end;
  if odeme = 'kasa' and not oyun.pano_odeme_yetki(p.id, f.sahip_tur, f.sahip_id) then
    raise exception 'Bu kasadan ödeme yapma yetkin yok. Kendi cüzdanından ödeyebilirsin.';
  end if;

  perform pg_advisory_xact_lock(hashtext('pano:' || p_kapsam || ':' || coalesce(il, 0)));
  n := oyun.pano_slot(p_kapsam, il);
  isl := oyun.pano_isletme_bul(p_kapsam, il, now());
  if p_slot between 1 and n then s := p_slot;
  else s := ((oyun.pano_sonraki_bos(p_kapsam, il)) ->> 'slot')::int; end if;
  bas := oyun.pano_slot_bos(p_kapsam, il, s);
  if bas < now() + interval '1 minute' then bas := now(); end if;
  if bas > now() + make_interval(days => a.sira_gun) then
    raise exception 'Bu pano % günden uzun süre dolu. Başka bir pano ya da il seç.', a.sira_gun;
  end if;

  if isl.id is not null then
    gunluk := (isl.fiyatlar ->> (s - 1))::numeric;
    if gunluk is null or gunluk <= 0 then raise exception 'İşletmeci bu panoya fiyat vermemiş.'; end if;
    if bas + make_interval(days => p_gun) > isl.bit then
      raise exception 'İşletmecinin sözleşmesi % tarihinde bitiyor; daha kısa süre seç.', to_char(isl.bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
    end if;
    toplam := round(gunluk * p_gun);
    v_vergi := round(toplam * a.reklam_vergisi);
  else
    fy := oyun.pano_fiyat(p_kapsam, il);
    gunluk := (fy ->> 'gunluk')::numeric; ind := oyun.pano_indirim(p_gun);
    toplam := round(gunluk * p_gun * (1 - ind));
    sonraki := oyun.pano_isletme_sonraki(p_kapsam, il);
    if sonraki is not null and bas + make_interval(days => p_gun) > sonraki then
      raise exception 'Bu panoların işletmesi % tarihinde ihaleyi kazanan işletmeciye geçiyor; daha kısa süre seç.', to_char(sonraki at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
    end if;
  end if;
  if p_beklenen is not null and toplam > p_beklenen * 1.001 then
    raise exception 'Fiyat değişti. Yeni tutar: % ₺. Teklifi yenileyip tekrar dene.', oyun.pano_tl(toplam);
  end if;

  insert into oyun.pano_yayin (afis_id, afis_ad, tasarim, sahip_tur, sahip_id, sahip_user, sahip_ad, siyasi, odeyen, odeme_tur,
                               kapsam, il_id, slot, bas, bit, gun, gunluk, tutar, isletme_id, vergi)
  values (f.id, f.ad, f.tasarim, f.sahip_tur, f.sahip_id, f.sahip_user, sahip_ad, f.sahip_tur in ('parti', 'oyuncu'), p.id, odeme,
          p_kapsam, il, s, bas, bas + make_interval(days => p_gun), p_gun, gunluk, toplam, isl.id, v_vergi)
  returning id into yid;

  aciklama := format('Reklam panosu #%s · %s · Pano %s · %s gün', yid, ilad, s, p_gun);
  perform oyun.pano_odeme(odeme, f.sahip_tur, f.sahip_id, p.id, -toplam, aciklama);
  if isl.id is not null then
    perform oyun.pano_odeme(case when isl.isletmeci_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, isl.isletmeci_tur, isl.isletmeci_id, isl.isletmeci_user,
                            toplam - v_vergi, format('Pano kira geliri #%s · %s · %s', yid, ilad, sahip_ad));
    perform oyun.pano_gelir(p_kapsam, il, v_vergi, format('İlan ve reklam vergisi · %s · %s ₺ (işletmeci %s)', aciklama, oyun.pano_tl(v_vergi), isl.isletmeci_ad));
    update oyun.pano_isletme set gelir = gelir + (toplam - v_vergi), vergi = vergi + v_vergi where id = isl.id;
    perform oyun.bildir(isl.isletmeci_user, format('Panon kiralandı: %s · Pano %s · %s gün · %s · Net gelir %s ₺ (vergi %s ₺).',
      ilad, s, p_gun, sahip_ad, oyun.pano_tl(toplam - v_vergi), oyun.pano_tl(v_vergi)), oyun.simdi());
  else
    perform oyun.pano_gelir(p_kapsam, il, toplam, format('%s · %s ₺ · %s', aciklama, oyun.pano_tl(toplam), sahip_ad));
  end if;

  return jsonb_build_object('tamam', true, 'id', yid, 'bas', bas, 'bit', bas + make_interval(days => p_gun), 'tutar', toplam,
    'hemen', bas <= now() + interval '1 minute', 'slot', s, 'il', case when p_kapsam = 'il' then ilad end, 'kapsam', p_kapsam,
    'isletmeci', isl.isletmeci_ad);
end $$;

-- Eski adlar (yayına girdikten sonra açık kalan sayfalar için) yeni işlemlere bağlanır
create or replace function public.pano_teklif(p_kapsam text, p_il integer, p_gun integer) returns jsonb
language sql stable security definer set search_path = '' as $$ select public.pano_teklif_v2(p_kapsam, p_il, p_gun, null) $$;
create or replace function public.pano_kirala(p_afis bigint, p_kapsam text, p_il integer, p_gun integer, p_odeme_tur text, p_beklenen numeric default null)
returns jsonb language sql security definer set search_path = '' as $$ select public.pano_kirala_v2(p_afis, p_kapsam, p_il, p_gun, p_odeme_tur, p_beklenen, null) $$;

-- ---------------------------------------------------------------------
-- İHALE İŞLEMLERİ
-- ---------------------------------------------------------------------
create or replace function public.pano_ihale_teklif_ver(p_ihale bigint, p_tur text, p_id bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); i oyun.pano_ihale; a oyun.pano_ayar; v_tutar numeric := round(coalesce(p_tutar, 0)); ad text;
  tur text := case when p_tur = 'sirket' then 'sirket' else 'oyuncu' end; sid bigint; yas uuid[]; n int; v_teminat numeric;
begin
  select * into a from oyun.pano_ayar where id = 1;
  select * into i from oyun.pano_ihale where id = p_ihale for update;
  if i.id is null then raise exception 'İhale bulunamadı.'; end if;
  if i.durum <> 'acik' or i.bit <= now() then raise exception 'Bu ihalenin teklif süresi doldu.'; end if;
  if v_tutar < i.asgari then raise exception 'En az % ₺ teklif vermelisin (muhammen bedel % ₺).', oyun.pano_tl(i.asgari), oyun.pano_tl(i.muhammen); end if;
  if v_tutar > 1000000000 then raise exception 'Teklif çok yüksek.'; end if;
  if tur = 'sirket' then
    sid := p_id;
    if not oyun.pano_odeme_yetki(p.id, 'sirket', sid) then raise exception 'Bu şirket adına teklif vermek için şirketin yöneticisi ya da çoğunluk ortağı olmalısın.'; end if;
    select s.ad into ad from oyun.sirketler s where s.id = sid and s.aktif;
    if ad is null then raise exception 'Şirket bulunamadı.'; end if;
  else
    sid := null; ad := p.kad;
  end if;
  -- İhale yetkilisi yasağı
  yas := oyun.pano_ihale_yetkilileri(i.kapsam, i.il_id);
  if p.id = any (yas) then
    raise exception 'İhale yetkilisi bu ihaleye katılamaz (%). Belediye başkanı kendi ilinin, Cumhurbaşkanı ve Ulaştırma Bakanı ülke geneli pano ihalesine teklif veremez.', oyun.pano_idare_ad(i.kapsam, i.il_id);
  end if;
  if tur = 'sirket' and exists (select 1 from oyun.sirketler s where s.id = sid and (s.yonetici = any (yas) or s.kurucu = any (yas)))
     or tur = 'sirket' and exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = sid and o.pay > 0 and o.user_id = any (yas)) then
    raise exception 'Bu şirkette ihale yetkilisinin yönetimi ya da ortaklığı var; şirket bu ihaleye katılamaz.';
  end if;
  -- Tekel sınırı
  select count(*) into n from oyun.pano_isletme z
   where z.durum = 'aktif' and z.bit > now()
     and (z.isletmeci_user = p.id or (z.isletmeci_tur = 'sirket' and z.isletmeci_id in (select s.id from oyun.sirketler s where s.yonetici = p.id or s.kurucu = p.id)));
  if n >= a.ihale_en_fazla then raise exception 'Aynı anda en fazla % pano işletmesi tutabilirsin (tekel sınırı).', a.ihale_en_fazla; end if;
  if exists (select 1 from oyun.pano_ihale_teklif t where t.ihale_id = i.id and t.teklif_tur = tur
              and ((tur = 'sirket' and t.teklif_id = sid) or (tur = 'oyuncu' and t.user_id = p.id))) then
    raise exception 'Bu ihaleye zaten teklif verdin. Kapalı teklif usulünde teklif geri alınamaz ve değiştirilemez.';
  end if;
  v_teminat := greatest(100, round(v_tutar * i.teminat_oran));
  perform oyun.pano_odeme(case when tur = 'oyuncu' then 'oyuncu' else 'kasa' end, tur, sid, p.id, -v_teminat, format('Geçici teminat · pano ihalesi #%s', i.id));
  insert into oyun.pano_ihale_teklif (ihale_id, teklif_tur, teklif_id, user_id, teklif_ad, tutar, teminat) values (i.id, tur, sid, p.id, ad, v_tutar, v_teminat);
  return jsonb_build_object('tamam', true, 'teminat', v_teminat, 'bit', i.bit);
end $$;

create or replace function public.pano_isletme_fiyat(p_isletme bigint, p_fiyatlar jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); z oyun.pano_isletme; yeni jsonb; x jsonb; v numeric;
begin
  select * into z from oyun.pano_isletme where id = p_isletme and durum = 'aktif' and bit > now() for update;
  if z.id is null then raise exception 'İşletme bulunamadı ya da süresi doldu.'; end if;
  if not ((z.isletmeci_tur = 'oyuncu' and z.isletmeci_user = p.id) or (z.isletmeci_tur = 'sirket' and oyun.pano_odeme_yetki(p.id, 'sirket', z.isletmeci_id))) then
    raise exception 'Fiyatları yalnız işletmeci belirleyebilir.';
  end if;
  if jsonb_typeof(p_fiyatlar) <> 'array' or jsonb_array_length(p_fiyatlar) <> z.slot then raise exception 'Her pano için bir fiyat gir (% pano).', z.slot; end if;
  yeni := '[]'::jsonb;
  for x in select value from jsonb_array_elements(p_fiyatlar) loop
    if jsonb_typeof(x) <> 'number' then raise exception 'Fiyatlar sayı olmalı.'; end if;
    v := round((x #>> '{}')::numeric);
    if v < 100 or v > 5000000 then raise exception 'Günlük pano fiyatı 100 ₺ ile 5.000.000 ₺ arasında olmalı.'; end if;
    yeni := yeni || to_jsonb(v);
  end loop;
  update oyun.pano_isletme set fiyatlar = yeni where id = z.id;
  return jsonb_build_object('tamam', true, 'fiyatlar', yeni);
end $$;

-- İhaleyi sonuçlandır (zamanlayıcıdan)
create or replace function oyun.pano_ihale_kapat(p_ihale bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare i oyun.pano_ihale; t record; k_id bigint; k_tur text; k_tid bigint; k_user uuid; k_ad text; k_tutar numeric; konu text; idare text; bas timestamptz; n int; fy jsonb; yid bigint; sayi int := 0;
begin
  select * into i from oyun.pano_ihale where id = p_ihale and durum = 'acik' for update;
  if i.id is null then return; end if;
  konu := case when i.kapsam = 'il' then (select il.ad from oyun.iller il where il.id = i.il_id) || ' il panoları' else 'Ülke geneli dev panolar' end;
  idare := oyun.pano_idare_ad(i.kapsam, i.il_id);
  for t in select * from oyun.pano_ihale_teklif where ihale_id = i.id order by tutar desc, zaman asc loop
    sayi := sayi + 1;
    if k_id is null then
      begin
        perform oyun.pano_odeme(case when t.teklif_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, t.teklif_tur, t.teklif_id, t.user_id,
                                -(t.tutar - t.teminat), format('İhale bedeli (teminat düşülmüş) · %s işletme hakkı · ihale #%s', konu, i.id));
        k_id := t.id; k_tur := t.teklif_tur; k_tid := t.teklif_id; k_user := t.user_id; k_ad := t.teklif_ad; k_tutar := t.tutar;
        update oyun.pano_ihale_teklif set durum = 'kazandi' where id = t.id;
      exception when others then
        update oyun.pano_ihale_teklif set durum = 'irat' where id = t.id;
        perform oyun.pano_ihale_gelir(i.kapsam, i.il_id, t.teminat, format('Pano ihalesi #%s: bedeli ödenmeyen teklifin teminatı irat kaydedildi', i.id));
        perform oyun.bildir(t.user_id, format('%s ihalesinde en yüksek teklif sizindi ama kalan bedel (%s ₺) ödenemedi. %s ₺ geçici teminat idareye gelir kaydedildi.',
          konu, oyun.pano_tl(t.tutar - t.teminat), oyun.pano_tl(t.teminat)), oyun.simdi());
      end;
    else
      perform oyun.pano_odeme(case when t.teklif_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, t.teklif_tur, t.teklif_id, t.user_id,
                              t.teminat, format('Geçici teminat iadesi · pano ihalesi #%s', i.id));
      update oyun.pano_ihale_teklif set durum = 'kaybetti' where id = t.id;
    end if;
  end loop;
  if sayi = 0 then update oyun.pano_ihale set durum = 'teklifsiz' where id = i.id; return; end if;
  if k_id is null then update oyun.pano_ihale set durum = 'bozuldu' where id = i.id; return; end if;

  perform oyun.pano_ihale_gelir(i.kapsam, i.il_id, k_tutar, format('Pano işletme hakkı ihale bedeli · %s · ihale #%s · %s', konu, i.id, k_ad));
  n := i.slot;
  bas := greatest(now(), coalesce((select max(z.bit) from oyun.pano_isletme z where z.durum = 'aktif' and z.kapsam = i.kapsam
                                    and z.il_id is not distinct from i.il_id and z.bit > now()), now()));
  fy := oyun.pano_fiyat(i.kapsam, i.il_id);
  insert into oyun.pano_isletme (ihale_id, kapsam, il_id, slot, isletmeci_tur, isletmeci_id, isletmeci_user, isletmeci_ad, bedel, bas, bit, fiyatlar)
  values (i.id, i.kapsam, i.il_id, n, k_tur, k_tid, k_user, k_ad, k_tutar,
          bas, bas + make_interval(days => i.isletme_gun),
          (select jsonb_agg(coalesce((fy ->> 'devlet_gunluk')::numeric, (fy ->> 'gunluk')::numeric, 1000)) from generate_series(1, n)))
  returning id into yid;
  update oyun.pano_ihale set durum = 'sonuclandi', kazanan_teklif = k_id, bedel = k_tutar where id = i.id;
  perform oyun.bildir(k_user, format('Tebrikler! %s işletme hakkı ihalesini %s ₺ ile kazandın (%s teklif). İşletme %s – %s. Pano fiyatlarını Reklam Panoları → İşletmelerim bölümünden belirle.',
    konu, oyun.pano_tl(k_tutar), sayi, to_char(bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'),
    to_char((bas + make_interval(days => i.isletme_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), oyun.simdi());
  for t in select * from oyun.pano_ihale_teklif where ihale_id = i.id and durum = 'kaybetti' loop
    perform oyun.bildir(t.user_id, format('%s ihalesini kazanamadın. Kazanan teklif: %s ₺ (%s). %s ₺ geçici teminatın iade edildi.',
      konu, oyun.pano_tl(k_tutar), k_ad, oyun.pano_tl(t.teminat)), oyun.simdi());
  end loop;
end $$;

-- Zamanlayıcı: ihaleleri kapat, sözleşmeleri bitir, yeni ilan aç
create or replace function oyun.pano_ihale_tick() returns void
language plpgsql security definer set search_path = '' as $$
declare a oyun.pano_ayar; r record; son timestamptz; muh numeric;
begin
  select * into a from oyun.pano_ayar where id = 1;
  for r in select id from oyun.pano_ihale where durum = 'acik' and bit <= now() order by bit loop
    perform oyun.pano_ihale_kapat(r.id);
  end loop;
  for r in update oyun.pano_isletme set durum = 'bitti' where durum = 'aktif' and bit <= now()
           returning isletmeci_user, kapsam, il_id, gelir, vergi, bedel loop
    perform oyun.bildir(r.isletmeci_user, format('Pano işletme sözleşmen sona erdi (%s). İhale bedeli %s ₺, net kira gelirin %s ₺. Yeni ihale ilanı Reklam Panoları ekranında.',
      case when r.kapsam = 'il' then (select il.ad from oyun.iller il where il.id = r.il_id) else 'Ülke geneli' end,
      oyun.pano_tl(r.bedel), oyun.pano_tl(r.gelir)), oyun.simdi());
  end loop;
  if not a.ihale_acik or not a.acik then return; end if;
  for r in select 'ulke'::text kapsam, null::smallint il_id
           union all
           select 'il', p.il_id from oyun.profiller p
            where not coalesce(p.yonetici, false) and not coalesce(p.yasakli, false) and p.il_id is not null
              and p.son_gorulme > now() - make_interval(days => a.ihale_aktif_gun)
            group by p.il_id loop
    continue when exists (select 1 from oyun.pano_ihale x where x.durum = 'acik' and x.kapsam = r.kapsam and x.il_id is not distinct from r.il_id);
    continue when exists (select 1 from oyun.pano_ihale x where x.durum in ('teklifsiz', 'bozuldu') and x.kapsam = r.kapsam
                           and x.il_id is not distinct from r.il_id and x.bit > now() - interval '12 hours');
    select max(z.bit) into son from oyun.pano_isletme z where z.durum = 'aktif' and z.kapsam = r.kapsam and z.il_id is not distinct from r.il_id and z.bit > now();
    continue when son is not null and son > now() + interval '48 hours';
    muh := oyun.pano_muhammen(r.kapsam, r.il_id, a.ihale_isletme_gun);
    insert into oyun.pano_ihale (kapsam, il_id, slot, isletme_gun, isletme_bas, muhammen, asgari, teminat_oran, bas, bit)
    values (r.kapsam, r.il_id, oyun.pano_slot(r.kapsam, r.il_id), a.ihale_isletme_gun,
            greatest(now() + make_interval(hours => a.ihale_teklif_saat), coalesce(son, now())),
            muh, greatest(1000, round(muh * a.ihale_asgari_oran / 500) * 500), a.ihale_teminat_oran, now(), now() + make_interval(hours => a.ihale_teklif_saat))
    on conflict do nothing;
  end loop;
end $$;

create or replace function oyun.pano_bakim() returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in update oyun.pano_yayin set durum = 'bitti' where durum = 'aktif' and bit <= now()
           returning id, odeyen, afis_ad, kapsam, il_id, gosterim, begeni loop
    perform oyun.bildir(r.odeyen, format('Reklam süresi doldu: "%s" %s panosunda %s kişiye ulaştı ve %s beğeni aldı. Yeniden yayınlamak için Reklam Panoları ekranına bak.',
      coalesce(r.afis_ad, 'Afiş'), case when r.kapsam = 'il' then (select i.ad from oyun.iller i where i.id = r.il_id) else 'ülke geneli' end,
      r.gosterim, r.begeni), oyun.simdi());
  end loop;
  for r in update oyun.pano_yayin set bas_bildirim = true
            where durum = 'aktif' and not bas_bildirim and bas <= now() and bas > olusturma + interval '5 minutes'
           returning id, odeyen, afis_ad, kapsam, il_id loop
    perform oyun.bildir(r.odeyen, format('Sıradaki reklamın yayına girdi: "%s" artık %s panosunda.',
      coalesce(r.afis_ad, 'Afiş'), case when r.kapsam = 'il' then (select i.ad from oyun.iller i where i.id = r.il_id) else 'ülke geneli' end), oyun.simdi());
  end loop;
  update oyun.pano_yayin set bas_bildirim = true where durum = 'aktif' and not bas_bildirim and bas <= now();
  delete from oyun.pano_gorme where gun < oyun.pano_bugun() - 60;
  perform oyun.pano_ihale_tick();
end $$;

-- İhaleler ve işletmeler ekranı
create or replace function public.pano_ihale_merkez() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.pano_ayar; benim bigint[];
begin
  select * into a from oyun.pano_ayar where id = 1;
  select coalesce(array_agg(s.id), '{}') into benim from oyun.sirketler s where s.aktif and oyun.pano_odeme_yetki(p.id, 'sirket', s.id);
  return jsonb_build_object(
    'ayar', jsonb_build_object('acik', a.ihale_acik, 'teklif_saat', a.ihale_teklif_saat, 'isletme_gun', a.ihale_isletme_gun, 'asgari_oran', a.ihale_asgari_oran,
                               'teminat_oran', a.ihale_teminat_oran, 'en_fazla', a.ihale_en_fazla, 'vergi', a.reklam_vergisi),
    'ihaleler', coalesce((select jsonb_agg(q order by q.sira, q.bit_sira) from (
      select case when i.durum = 'acik' then 0 else 1 end sira, case when i.durum = 'acik' then extract(epoch from i.bit) else -extract(epoch from i.bit) end bit_sira,
             i.id, i.kapsam, i.il_id, (select il.ad from oyun.iller il where il.id = i.il_id) il, oyun.pano_idare_ad(i.kapsam, i.il_id) idare,
             i.slot, i.isletme_gun, i.isletme_bas, i.muhammen, i.asgari, i.teminat_oran, i.bas, i.bit, i.durum, i.bedel,
             (select count(*) from oyun.pano_ihale_teklif t where t.ihale_id = i.id) teklif_say,
             (p.id = any (oyun.pano_ihale_yetkilileri(i.kapsam, i.il_id))) yetkili,
             (select jsonb_agg(jsonb_build_object('ad', t.teklif_ad, 'tur', t.teklif_tur, 'tutar', t.tutar, 'teminat', t.teminat, 'durum', t.durum))
                from oyun.pano_ihale_teklif t where t.ihale_id = i.id and (t.user_id = p.id or (t.teklif_tur = 'sirket' and t.teklif_id = any (benim)))) benim,
             (select jsonb_build_object('ad', t.teklif_ad, 'tutar', t.tutar) from oyun.pano_ihale_teklif t where t.id = i.kazanan_teklif) kazanan
        from oyun.pano_ihale i
       where i.durum = 'acik' or i.id in (select x.id from oyun.pano_ihale x where x.durum <> 'acik' order by x.bit desc limit 12)) q), '[]'::jsonb),
    'isletmelerim', coalesce((select jsonb_agg(jsonb_build_object('id', z.id, 'kapsam', z.kapsam, 'il_id', z.il_id, 'il', (select il.ad from oyun.iller il where il.id = z.il_id),
             'isletmeci_ad', z.isletmeci_ad, 'isletmeci_tur', z.isletmeci_tur, 'bas', z.bas, 'bit', z.bit, 'slot', z.slot, 'fiyatlar', z.fiyatlar,
             'bedel', z.bedel, 'gelir', z.gelir, 'vergi', z.vergi, 'devlet_gunluk', (oyun.pano_fiyat(z.kapsam, z.il_id) ->> 'devlet_gunluk')::numeric,
             'dolu', (select count(distinct y.slot) from oyun.pano_yayin y where y.isletme_id = z.id and y.durum = 'aktif' and y.bas <= now() and y.bit > now()),
             'kiralama', (select count(*) from oyun.pano_yayin y where y.isletme_id = z.id)) order by z.bit)
        from oyun.pano_isletme z
       where z.durum = 'aktif' and z.bit > now()
         and ((z.isletmeci_tur = 'oyuncu' and z.isletmeci_user = p.id) or (z.isletmeci_tur = 'sirket' and z.isletmeci_id = any (benim)))), '[]'::jsonb),
    'isletmeler', coalesce((select jsonb_agg(jsonb_build_object('kapsam', z.kapsam, 'il_id', z.il_id, 'il', (select il.ad from oyun.iller il where il.id = z.il_id),
             'ad', z.isletmeci_ad, 'bas', z.bas, 'bit', z.bit, 'bedel', z.bedel) order by z.bas)
        from oyun.pano_isletme z where z.durum = 'aktif' and z.bit > now()), '[]'::jsonb),
    'kaynaklar', (select jsonb_build_array(jsonb_build_object('tur', 'oyuncu', 'id', null, 'ad', p.kad || ' (kendi adına)', 'kasa', coalesce((select c.para from oyun.cuzdan c where c.user_id = p.id), 0)))
                  || coalesce((select jsonb_agg(jsonb_build_object('tur', 'sirket', 'id', s.id, 'ad', s.ad, 'kasa', s.kasa) order by s.ad) from oyun.sirketler s where s.id = any (benim)), '[]'::jsonb)));
end $$;

-- ---------------------------------------------------------------------
-- SÜPER YÖNETİCİ PORTALI
-- ---------------------------------------------------------------------
do $portal$
begin
  if to_regclass('oyun.yp_ayar_katalog') is not null then
    insert into oyun.yp_ayar_katalog (anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, risk, etki, sira) values
      ('pano.ihale_acik', 'oyun.pano_ayar', 'ihale_acik', '{"id":"1"}', 'ekonomi', 'Pano ihaleleri açık',
       'Açıkken işletmecisi olmayan panolar için ihale ilanı kendiliğinden yayımlanır. Kapalıyken yeni ihale açılmaz; açık ihaleler sonuçlanır.', 'evet_hayir', null, null, null, 'orta', '10 dakika içinde.', 310),
      ('pano.ihale_teklif_saat', 'oyun.pano_ayar', 'ihale_teklif_saat', '{"id":"1"}', 'ekonomi', 'İhale teklif süresi',
       'İhale ilanından teklif kapanışına kadar geçen süre.', 'tamsayi', 'saat', 6, 168, 'dusuk', 'Yeni ihalelerde.', 311),
      ('pano.ihale_isletme_gun', 'oyun.pano_ayar', 'ihale_isletme_gun', '{"id":"1"}', 'ekonomi', 'İşletme (sözleşme) süresi',
       'İhaleyi kazananın panoları işleteceği süre.', 'tamsayi', 'gün', 3, 90, 'dusuk', 'Yeni ihalelerde.', 312),
      ('pano.ihale_asgari_oran', 'oyun.pano_ayar', 'ihale_asgari_oran', '{"id":"1"}', 'ekonomi', 'En düşük teklif (muhammen bedelin oranı)',
       'Teklifler muhammen bedelin bu oranından az olamaz. 1 = muhammen bedel.', 'sayi', 'kat', 0.1, 2, 'dusuk', 'Yeni ihalelerde.', 313),
      ('pano.ihale_doluluk', 'oyun.pano_ayar', 'ihale_doluluk', '{"id":"1"}', 'ekonomi', 'Muhammen bedel doluluk varsayımı',
       'Muhammen bedel = devlet tarifesi × pano sayısı × gün × bu oran. Düşürürsen ihaleler ucuzlar.', 'sayi', 'kat', 0.05, 1, 'dusuk', 'Yeni ihalelerde.', 314),
      ('pano.ihale_teminat_oran', 'oyun.pano_ayar', 'ihale_teminat_oran', '{"id":"1"}', 'ekonomi', 'Geçici teminat oranı',
       'Teklifle birlikte alınan teminat (kaybedene iade, ödemeyen kazanandan irat).', 'sayi', 'kat', 0.01, 0.3, 'dusuk', 'Yeni ihalelerde.', 315),
      ('pano.ihale_en_fazla', 'oyun.pano_ayar', 'ihale_en_fazla', '{"id":"1"}', 'ekonomi', 'Tekel sınırı (işletme sayısı)',
       'Bir oyuncunun yönettiği şirketlerle birlikte aynı anda tutabileceği en fazla pano işletmesi.', 'tamsayi', 'işletme', 1, 30, 'dusuk', 'Yeni tekliflerde.', 316),
      ('pano.reklam_vergisi', 'oyun.pano_ayar', 'reklam_vergisi', '{"id":"1"}', 'ekonomi', 'İlan ve reklam vergisi',
       'İşletmecili panolardaki her kiralamadan belediyeye (ülke genelinde Hazine''ye) kesilen pay.', 'sayi', 'oran', 0, 0.5, 'dusuk', 'Yeni kiralamalarda.', 317)
    on conflict (anahtar) do update set tablo = excluded.tablo, sutun = excluded.sutun, satir = excluded.satir, grup = excluded.grup,
      baslik = excluded.baslik, aciklama = excluded.aciklama, tur = excluded.tur, birim = excluded.birim, en_az = excluded.en_az,
      en_cok = excluded.en_cok, risk = excluded.risk, etki = excluded.etki, sira = excluded.sira, aktif = true;
  end if;
end
$portal$;

-- YETKİLER (159_rpc_yuzey.sql izin listesinde de var)
revoke all on function public.pano_teklif_v2(text, integer, integer, integer), public.pano_kirala_v2(bigint, text, integer, integer, text, numeric, integer),
  public.pano_ihale_teklif_ver(bigint, text, bigint, numeric), public.pano_isletme_fiyat(bigint, jsonb), public.pano_ihale_merkez() from public, anon;
grant execute on function public.pano_teklif_v2(text, integer, integer, integer), public.pano_kirala_v2(bigint, text, integer, integer, text, numeric, integer),
  public.pano_ihale_teklif_ver(bigint, text, bigint, numeric), public.pano_isletme_fiyat(bigint, jsonb), public.pano_ihale_merkez(),
  public.pano_teklif(text, integer, integer), public.pano_kirala(bigint, text, integer, integer, text, numeric) to authenticated;
revoke all on function oyun.pano_ihale_kapat(bigint), oyun.pano_ihale_tick(), oyun.pano_ihale_gelir(text, smallint, numeric, text),
  oyun.pano_ihale_yetkilileri(text, smallint), oyun.pano_odeme(text, text, bigint, uuid, numeric, text), oyun.pano_bakim() from public, anon, authenticated;
