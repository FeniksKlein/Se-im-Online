-- =====================================================================
--  164 · BASIN VE KİTAP REKABETİ (05.11.2026)
--
--  Ercan: "Gazete tirajlarını haftalık açıkla; yayınevleri ve yazarlar imza
--  günü düzenleyip satışlarını artırabilsin; bu iki ekranda kullanıcılar
--  arasında rekabet olsun."
--
--  1) Gazete okuma kaydı: gazete_detay her açılışta (gazete, oyuncu, gün)
--     kaydı bırakır. Sahip ve köşe yazarları okur sayılmaz.
--  2) Haftalık tiraj (Pazartesi 00:00 – Pazar 23:59, İstanbul saati):
--       yayın puanı = haftanın en iyi 14 yazısı (köşe 1,3 · haber 1 ·
--                     propaganda 0,5) × uzunluk (800 karakterde tam puan)
--       tiraj = 420 × puan^0,85 × (1 + 0,12×okur + 0,25×abone + 0,06×yorumcu)
--               × (ücretsiz gazete 1,1), 10'a yuvarlı. Yayın yoksa 0.
--     Okur ve yorumcu: hesabı en az 72 saatlik gerçek oyuncu. Üst sınır 40.
--     Pazartesi 00:00'dan sonra geçen hafta "resmî tiraj" olarak
--     gazete_tiraj'a yazılır, Türkiye Gündem'de açıklanır, sahiplere bildirim.
--  3) Haftalık çok satanlar: uc_kitap_satis'ten hesaplanır; Pazartesi
--     Türkiye Gündem'de açıklanır, 1. kitabın yazarına ve yayınevine bildirim.
--  4) İmza günü: kitabın yazarı (cüzdandan) ya da yayınevinin %50+ ortağı
--     (yayınevi kasasından) bir ilde 3 saatlik imza günü düzenler.
--       bedel   = tarife 'imza_gunu' (2.000 ₺) × il kuruluş endeksi × fiyat
--                 endeksi; masa açılınca o ilin belediye kasasına geçer
--                 (kültür merkezi salon kirası).
--       satış   = 30 × √(il talep endeksi) × (400/fiyat)^0,55
--                 × (1 + 0,22 × katılım puanı) — en çok 150 nüsha,
--                 3 saat boyunca 5 dakikada bir, stok yettiğince.
--                 Katılım puanı: aynı ildeki okur 2, başka ilden 1 (en çok 12).
--       oyuncu  = masa açıkken "İmzalı nüsha al" (kitabın normal fiyatı).
--       kurallar= stok ≥ 10; başlangıç 15 dk – 7 gün sonrası; aynı kitaba
--                 aynı anda tek imza günü, bitişten 48 saat sonra yenisi;
--                 düzenleyen başına en çok 2 açık imza günü; başlamadan iptal
--                 edilirse bedelin yarısı iade, yarısı belediyeye.
--
--  Yalnız yeni tablo/sütun/fonksiyon eklenir; oyuncu verisi değiştirilmez.
--  uc_kitap tabloları 20261014_* göçlerinden gelir (supabase-kurulum.sql'de
--  yoktur), bu yüzden bu dosya yalnız migrations/ altında durur.
-- =====================================================================

-- ---------- Tablolar ------------------------------------------------------
create table if not exists oyun.gazete_okuma (
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id),
  user_id   uuid   not null references oyun.profiller(id),
  gun       date   not null,
  primary key (gazete_id, gun, user_id)
);
create index if not exists gazete_okuma_user_idx on oyun.gazete_okuma(user_id);

create table if not exists oyun.gazete_tiraj (
  hafta     date    not null,
  gazete_id bigint  not null references oyun.oyuncu_gazeteleri(id),
  tiraj     integer not null default 0,
  yayin     integer not null default 0,
  okur      integer not null default 0,
  abone     integer not null default 0,
  yorumcu   integer not null default 0,
  sira      integer not null,
  olusturma timestamptz not null default now(),
  primary key (hafta, gazete_id)
);
create index if not exists gazete_tiraj_gazete_idx on oyun.gazete_tiraj(gazete_id, hafta desc);

create table if not exists oyun.haftalik_aciklama (
  hafta date not null,
  tur   text not null check (tur in ('tiraj', 'cok_satan')),
  zaman timestamptz not null default now(),
  duyuruldu boolean not null default false,
  primary key (hafta, tur)
);

create table if not exists oyun.kitap_imza_gunu (
  id          bigserial primary key,
  kitap_id    bigint not null references oyun.uc_kitap(id),
  duzenleyen  uuid   not null references oyun.profiller(id),
  rol         text   not null check (rol in ('yazar', 'yayinevi')),
  odeme       text   not null check (odeme in ('cuzdan', 'yayinevi')),
  il_id       smallint not null references oyun.iller(id),
  baslangic   timestamptz not null,
  bitis       timestamptz not null,
  maliyet     numeric not null default 0 check (maliyet >= 0),
  durum       text not null default 'planli' check (durum in ('planli', 'canli', 'bitti', 'iptal')),
  satis       integer not null default 0,
  oyuncu_satis integer not null default 0,
  olusturma   timestamptz not null default now(),
  son_islem   timestamptz,
  check (bitis > baslangic)
);
create index if not exists kitap_imza_durum_idx on oyun.kitap_imza_gunu(durum, baslangic);
create index if not exists kitap_imza_kitap_idx on oyun.kitap_imza_gunu(kitap_id, bitis desc);
create index if not exists kitap_imza_duzenleyen_idx on oyun.kitap_imza_gunu(duzenleyen);
create index if not exists kitap_imza_il_idx on oyun.kitap_imza_gunu(il_id);

create table if not exists oyun.kitap_imza_katilim (
  imza_id bigint not null references oyun.kitap_imza_gunu(id),
  user_id uuid   not null references oyun.profiller(id),
  yerel   boolean not null default false,
  zaman   timestamptz not null default now(),
  primary key (imza_id, user_id)
);
create index if not exists kitap_imza_katilim_user_idx on oyun.kitap_imza_katilim(user_id);

alter table oyun.uc_kitap_satis add column if not exists imza_id bigint references oyun.kitap_imza_gunu(id);
create index if not exists uc_kitap_satis_imza_idx on oyun.uc_kitap_satis(imza_id) where imza_id is not null;
create index if not exists uc_kitap_satis_zaman_idx on oyun.uc_kitap_satis(zaman);

do $$
declare t text;
begin
  foreach t in array array['gazete_okuma','gazete_tiraj','haftalik_aciklama','kitap_imza_gunu','kitap_imza_katilim'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
    if to_regproc('oyun.bosaltma_korumasi') is not null
       and not exists (select 1 from pg_trigger where tgname = 'bosaltma_korumasi' and tgrelid = format('oyun.%I', t)::regclass) then
      execute format('create trigger bosaltma_korumasi before %s on oyun.%I for each statement execute function oyun.bosaltma_korumasi()', 'trunc' || 'ate', t);
    end if;
  end loop;
end $$;

-- Tarife: yönetici sonradan değiştirebilir, değer yalnız ilk kurulumda yazılır.
do $$ begin
  if to_regclass('oyun.tarife') is not null then
    insert into oyun.tarife(kod, deger, birim, kategori, ad, aciklama, sira)
    values ('imza_gunu', 2000, 'tl_endeks', 'kurulus', 'Kitap imza günü salon kirası (il çarpanıyla)',
            'İstanbul ×2,0 · Tunceli ×0,74. Bedel o ilin belediye kasasına geçer.', 40)
    on conflict (kod) do nothing;
  end if;
end $$;

-- ---------- Yardımcılar ----------------------------------------------------
create or replace function oyun.hafta_bas(p timestamptz) returns date
language sql immutable set search_path = '' as $$
  select (date_trunc('week', p at time zone 'Europe/Istanbul'))::date
$$;

create or replace function oyun.hafta_an(p_hafta date) returns timestamptz
language sql immutable set search_path = '' as $$
  select (p_hafta::timestamp at time zone 'Europe/Istanbul')
$$;

create or replace function oyun.imza_gunu_ucret(p_il smallint) returns numeric
language sql stable security definer set search_path = '' as $$
  select greatest(1000, round(
           coalesce(nullif(oyun.tf('imza_gunu'), 0), 2000)
           * case when oyun.il_ekonomi_acik() then coalesce(oyun.il_kurulus_endeksi(p_il), 1) else 1 end
           * coalesce((select u.endeks from oyun.ulke u where u.id = 1), 1) / 100) * 100)
$$;

-- Bir gazetenin [p_bas, p_bit) aralığındaki tirajı.
create or replace function oyun.gazete_tiraj_hesap(p_gazete bigint, p_bas timestamptz, p_bit timestamptz)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  g oyun.oyuncu_gazeteleri;
  m timestamptz := least(p_bit, oyun.simdi());
  puan numeric; yayin int; okur int; abone int; yorum int; tir numeric := 0;
  gun1 date := (p_bas at time zone 'Europe/Istanbul')::date;
  gun2 date := ((p_bit - interval '1 microsecond') at time zone 'Europe/Istanbul')::date;
begin
  select * into g from oyun.oyuncu_gazeteleri where id = p_gazete;
  if g.id is null then return null; end if;

  select count(*) into yayin from oyun.gazete_yayinlari y
   where y.gazete_id = g.id and y.zaman >= p_bas and y.zaman < p_bit;

  select coalesce(sum(w), 0) into puan from (
    select (case y.tur when 'kose' then 1.3 when 'haber' then 1.0 else 0.5 end)
           * least(1.0, greatest(0.3, length(coalesce(y.metin, '')) / 800.0)) w
      from oyun.gazete_yayinlari y
     where y.gazete_id = g.id and y.zaman >= p_bas and y.zaman < p_bit
     order by 1 desc limit 14) x;

  select count(distinct o.user_id) into okur
    from oyun.gazete_okuma o join oyun.profiller p on p.id = o.user_id
   where o.gazete_id = g.id and o.gun between gun1 and gun2
     and o.user_id <> g.sahip
     and p.olusturma <= (o.gun::timestamp at time zone 'Europe/Istanbul') - interval '72 hours'
     and not exists (select 1 from oyun.gazete_yazarlar z where z.gazete_id = g.id and z.user_id = o.user_id and z.aktif);

  select count(*) into abone from oyun.gazete_abonelik a
   where a.gazete_id = g.id and a.user_id <> g.sahip and a.baslangic <= m and a.bitis > m;

  select count(distinct c.user_id) into yorum
    from oyun.gazete_kose_yorum c
    join oyun.gazete_yayinlari y on y.id = c.yayin_id
    join oyun.profiller p on p.id = c.user_id
   where y.gazete_id = g.id and not c.silindi and c.zaman >= p_bas and c.zaman < p_bit
     and c.user_id <> g.sahip and p.olusturma <= c.zaman - interval '72 hours';

  if puan > 0 then
    tir := 420 * power(puan, 0.85)
           * (1 + 0.12 * least(okur, 40) + 0.25 * least(abone, 40) + 0.06 * least(yorum, 40))
           * case when coalesce(g.abonelik_ucret, 0) = 0 then 1.1 else 1 end;
  end if;

  return jsonb_build_object('tiraj', (round(tir / 10) * 10)::int, 'yayin', yayin, 'okur', okur,
                            'abone', abone, 'yorumcu', yorum, 'puan', round(puan, 2));
end $$;

-- Haftanın resmî tirajını kaydeder (bir kez). p_duyur: Türkiye Gündem + bildirim.
create or replace function oyun.gazete_tiraj_kaydet(p_hafta date, p_duyur boolean default true)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_bas timestamptz := oyun.hafta_an(p_hafta);
  v_bit timestamptz := oyun.hafta_an(p_hafta) + interval '7 days';
  n int := 0; ilk record; r record; satirlar text := ''; ozet text := ''; i int := 0;
begin
  if v_bit > oyun.simdi() then return 0; end if;
  insert into oyun.haftalik_aciklama(hafta, tur, duyuruldu) values (p_hafta, 'tiraj', p_duyur)
  on conflict do nothing;
  if not found then return 0; end if;

  insert into oyun.gazete_tiraj(hafta, gazete_id, tiraj, yayin, okur, abone, yorumcu, sira)
  select p_hafta, x.id, (x.j->>'tiraj')::int, (x.j->>'yayin')::int, (x.j->>'okur')::int,
         (x.j->>'abone')::int, (x.j->>'yorumcu')::int,
         row_number() over (order by (x.j->>'tiraj')::int desc, (x.j->>'okur')::int desc, x.id)
    from (select g.id, oyun.gazete_tiraj_hesap(g.id, v_bas, v_bit) j
            from oyun.oyuncu_gazeteleri g where g.aktif and g.kurulus < v_bit) x
  on conflict do nothing;
  get diagnostics n = row_count;

  if not p_duyur then return n; end if;

  select t.*, g.ad, g.sahip into ilk
    from oyun.gazete_tiraj t join oyun.oyuncu_gazeteleri g on g.id = t.gazete_id
   where t.hafta = p_hafta and t.tiraj > 0 order by t.sira limit 1;
  if ilk.gazete_id is null then return n; end if;

  for r in select t.*, g.ad, g.sahip,
                  (select o.sira from oyun.gazete_tiraj o where o.hafta = p_hafta - 7 and o.gazete_id = t.gazete_id and o.tiraj > 0) eski
             from oyun.gazete_tiraj t join oyun.oyuncu_gazeteleri g on g.id = t.gazete_id
            where t.hafta = p_hafta and t.tiraj > 0 order by t.sira limit 10 loop
    i := i + 1;
    satirlar := satirlar || r.sira || '. ' || r.ad || ' — ' || oyun.tl(r.tiraj) || ' nüsha'
                || case when r.eski is null then ' (yeni)' when r.eski > r.sira then ' (▲' || (r.eski - r.sira) || ')'
                        when r.eski < r.sira then ' (▼' || (r.sira - r.eski) || ')' else '' end || E'\n';
    if i = 2 then ozet := ozet || ' ' || r.ad || ' ikinci'; end if;
    if i = 3 then ozet := ozet || ', ' || r.ad || ' üçüncü'; end if;
  end loop;

  insert into oyun.ajans_haberleri(kaynak_anahtar, kategori, baslik, ozet, metin, oncelik, zaman)
  values ('tiraj:' || p_hafta, 'bulten',
          'Haftanın tirajları açıklandı: zirvede ' || ilk.ad,
          ilk.ad || ' ' || oyun.tl(ilk.tiraj) || ' nüshayla haftayı birinci kapattı.'
            || case when ozet <> '' then ozet || '.' else '' end,
          to_char(p_hafta, 'DD.MM.YYYY') || ' haftasının resmî tirajları:' || E'\n\n' || satirlar
            || E'\nTiraj; yayımlanan yazıların sayısı ve uzunluğu, gerçek okur, abone ve yorumcu sayısından hesaplanır.',
          60, oyun.simdi())
  on conflict (kaynak_anahtar) do nothing;

  -- Sayı çıkarmayan gazeteye yalnız son 4 haftada yayın yaptıysa hatırlatma gider.
  for r in select t.sira, t.tiraj, g.ad, g.sahip from oyun.gazete_tiraj t
             join oyun.oyuncu_gazeteleri g on g.id = t.gazete_id
            where t.hafta = p_hafta and g.aktif
              and (t.tiraj > 0 or exists(select 1 from oyun.gazete_yayinlari y where y.gazete_id = g.id
                                           and y.zaman >= v_bit - interval '28 days')) loop
    perform oyun.bildir(r.sahip, case when r.tiraj > 0
      then 'Tiraj: ' || r.ad || ' geçen hafta ' || oyun.tl(r.tiraj) || ' nüsha ile ' || r.sira || '. oldu.'
           || case when r.sira = 1 then ' Haftanın en çok okunan gazetesi seçildi.' else '' end
      else 'Tiraj: ' || r.ad || ' geçen hafta sayı çıkarmadığı için tiraj listesine giremedi.' end);
  end loop;
  return n;
end $$;

-- Haftanın çok satanlarını açıklar (bir kez).
create or replace function oyun.kitap_hafta_aciklama(p_hafta date, p_duyur boolean default true)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_bas timestamptz := oyun.hafta_an(p_hafta);
  v_bit timestamptz := oyun.hafta_an(p_hafta) + interval '7 days';
  r record; ilk record; satirlar text := ''; n int := 0; yv record;
begin
  if v_bit > oyun.simdi() then return 0; end if;
  insert into oyun.haftalik_aciklama(hafta, tur, duyuruldu) values (p_hafta, 'cok_satan', p_duyur)
  on conflict do nothing;
  if not found or not p_duyur then return 0; end if;

  for r in select k.id, k.baslik, k.yazar, k.yayinevi, s.ad yayinevi_ad, sum(x.adet) adet
             from oyun.uc_kitap_satis x join oyun.uc_kitap k on k.id = x.kitap_id
             join oyun.sirketler s on s.id = k.yayinevi
            where x.zaman >= v_bas and x.zaman < v_bit
            group by k.id, k.baslik, k.yazar, k.yayinevi, s.ad
            order by sum(x.adet) desc, k.id desc limit 10 loop
    n := n + 1;
    if n = 1 then ilk := r; end if;
    satirlar := satirlar || n || '. ' || r.baslik || ' — ' || oyun.kad(r.yazar) || ' (' || r.yayinevi_ad || '), '
                || oyun.tl(r.adet) || E' adet\n';
  end loop;
  if n = 0 then return 0; end if;

  select s.ad, sum(x.adet) adet into yv
    from oyun.uc_kitap_satis x join oyun.uc_kitap k on k.id = x.kitap_id join oyun.sirketler s on s.id = k.yayinevi
   where x.zaman >= v_bas and x.zaman < v_bit group by s.id, s.ad order by 2 desc limit 1;

  insert into oyun.ajans_haberleri(kaynak_anahtar, kategori, baslik, ozet, metin, oncelik, zaman)
  values ('cok_satan:' || p_hafta, 'bulten',
          'Haftanın çok satanı: «' || ilk.baslik || '»',
          oyun.kad(ilk.yazar) || ' imzalı kitap ' || oyun.tl(ilk.adet) || ' adetle listenin zirvesinde. Haftanın yayınevi '
            || yv.ad || ' oldu.',
          to_char(p_hafta, 'DD.MM.YYYY') || E' haftasının en çok satan kitapları:\n\n' || satirlar,
          55, oyun.simdi())
  on conflict (kaynak_anahtar) do nothing;

  perform oyun.bildir(ilk.yazar, 'Çok satanlar: «' || ilk.baslik || '» geçen haftanın en çok satan kitabı oldu ('
                      || oyun.tl(ilk.adet) || ' adet).');
  perform oyun.bildir(o.user_id, 'Çok satanlar: ' || ilk.yayinevi_ad || ' yayınevinden çıkan «' || ilk.baslik
                      || '» geçen haftanın en çok satan kitabı oldu.')
     from oyun.sirket_ortaklari o where o.sirket_id = ilk.yayinevi and o.pay >= 50 and o.user_id <> ilk.yazar;
  return n;
end $$;

-- Türkçe bulunma eki: İstanbul'da, İzmir'de, Sinop'ta, Bitlis'te.
create or replace function oyun.ek_de(p text) returns text
language plpgsql immutable set search_path = '' as $$
declare s text := lower(coalesce(p, '')); v text; son text; i int;
begin
  if s = '' then return coalesce(p, ''); end if;
  son := right(s, 1);
  for i in reverse length(s)..1 loop
    if substr(s, i, 1) in ('a', 'ı', 'o', 'u', 'â', 'û') then v := 'a'; exit; end if;
    if substr(s, i, 1) in ('e', 'i', 'ö', 'ü', 'î') then v := 'e'; exit; end if;
  end loop;
  return p || '''' || case when son in ('f', 's', 't', 'k', 'ç', 'ş', 'h', 'p') then 't' else 'd' end || coalesce(v, 'a');
end $$;

-- İmza gününün o anki hedef satışı (katılımla büyür).
create or replace function oyun.kitap_imza_hedef(p_id bigint) returns integer
language sql stable security definer set search_path = '' as $$
  select least(150, round(
           30 * sqrt(greatest(0.1, coalesce(case when oyun.il_ekonomi_acik() then oyun.il_talep_endeksi(e.il_id) end, 1)))
              * power(400.0 / greatest(k.fiyat, 100), 0.55)
              * (1 + 0.22 * least(12, coalesce((
                  select sum(case when c.yerel then 2 else 1 end)
                    from oyun.kitap_imza_katilim c join oyun.profiller p on p.id = c.user_id
                   where c.imza_id = e.id and c.user_id <> e.duzenleyen and c.user_id <> k.yazar
                     and p.olusturma <= c.zaman - interval '72 hours'), 0)))
         ))::int
    from oyun.kitap_imza_gunu e join oyun.uc_kitap k on k.id = e.kitap_id
   where e.id = p_id
$$;

-- Açık imza masasında zamana yayılan satış (NPC okurlar).
create or replace function oyun.kitap_imza_satis(p_id bigint, p_t timestamptz) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  ev oyun.kitap_imza_gunu; stok int; f numeric; hedef int; kalan int; parca int; toplam int := 0; i int := 0; d timestamptz;
begin
  select * into ev from oyun.kitap_imza_gunu where id = p_id for update;
  if ev.id is null or ev.durum <> 'canli' then return 0; end if;
  f := least(1, greatest(0, extract(epoch from (p_t - ev.baslangic)) / extract(epoch from (ev.bitis - ev.baslangic))));
  hedef := oyun.kitap_imza_hedef(ev.id);
  kalan := floor(hedef * f)::int - (ev.satis - ev.oyuncu_satis);
  if kalan <= 0 then return 0; end if;
  select k.stok into stok from oyun.uc_kitap k where k.id = ev.kitap_id and k.durum = 'yayinda' for update;
  kalan := least(kalan, coalesce(stok, 0));
  while kalan > 0 loop
    parca := least(30, kalan);
    i := i + 1;
    d := p_t + make_interval(secs => 0.001 * i);
    perform oyun.uc_kitap_kazanc(ev.kitap_id, parca, null, d);
    update oyun.uc_kitap_satis set imza_id = ev.id where kitap_id = ev.kitap_id and donem = d;
    toplam := toplam + parca; kalan := kalan - parca;
  end loop;
  if toplam > 0 then
    update oyun.kitap_imza_gunu set satis = satis + toplam, son_islem = p_t where id = ev.id;
  end if;
  return toplam;
end $$;

-- Zamanlayıcı adımı: imza masalarını açar/kapatır, satışı işler, haftalık açıklamaları yapar.
create or replace function oyun.basin_kitap_tick() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  t timestamptz := oyun.simdi(); ev record; acilan int := 0; biten int := 0; satilan int := 0; s int;
  hb date := oyun.hafta_bas(oyun.simdi());
begin
  if not pg_try_advisory_xact_lock(hashtext('oyun.basin_kitap_tick')) then return jsonb_build_object('kilitli', true); end if;

  for ev in select e.*, k.baslik, k.yazar from oyun.kitap_imza_gunu e join oyun.uc_kitap k on k.id = e.kitap_id
             where e.durum in ('planli', 'canli') and e.baslangic <= t order by e.baslangic, e.id limit 50 loop
    begin
      if ev.durum = 'planli' then
        update oyun.kitap_imza_gunu set durum = 'canli', son_islem = t where id = ev.id and durum = 'planli';
        if ev.maliyet > 0 then
          update oyun.il_durum set kasa = kasa + ev.maliyet where il_id = ev.il_id;
          if found then
            insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
            values (ev.il_id, 'kultur', ev.maliyet, 'Kültür merkezi salon kirası: «' || ev.baslik || '» imza günü', t);
          end if;
        end if;
        perform oyun.bildir(c.user_id, 'İmza günü: «' || ev.baslik || '» imza masası ' || oyun.ek_de((select ad from oyun.iller where id = ev.il_id))
                            || ' açıldı. 3 saat boyunca imzalı nüsha alabilirsin.')
           from oyun.kitap_imza_katilim c where c.imza_id = ev.id;
        acilan := acilan + 1;
      end if;
      s := oyun.kitap_imza_satis(ev.id, least(t, ev.bitis));
      satilan := satilan + s;
      if t >= ev.bitis then
        update oyun.kitap_imza_gunu set durum = 'bitti', son_islem = t where id = ev.id;
        perform oyun.kitap_imza_bitir(ev.id);
        biten := biten + 1;
      end if;
    exception when others then
      if t >= ev.bitis then
        update oyun.kitap_imza_gunu set durum = 'bitti', son_islem = t where id = ev.id and durum in ('planli', 'canli');
      end if;
    end;
  end loop;

  perform oyun.gazete_tiraj_kaydet(hb - 7, true);
  perform oyun.kitap_hafta_aciklama(hb - 7, true);
  return jsonb_build_object('acilan', acilan, 'biten', biten, 'satilan', satilan);
end $$;

-- Biten imza gününün duyurusu.
create or replace function oyun.kitap_imza_bitir(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare ev record; katilim int; il text;
begin
  select e.*, k.baslik, k.yazar into ev from oyun.kitap_imza_gunu e join oyun.uc_kitap k on k.id = e.kitap_id where e.id = p_id;
  if ev.id is null then return; end if;
  select count(*) into katilim from oyun.kitap_imza_katilim where imza_id = p_id;
  select ad into il from oyun.iller where id = ev.il_id;
  perform oyun.bildir(u, 'İmza günü: «' || ev.baslik || '» ' || oyun.ek_de(il) || ' ' || ev.satis || ' nüsha imzalandı'
                      || case when katilim > 0 then ', ' || katilim || ' okur masaya uğradı.' else '.' end)
     from (select distinct x as u from unnest(array[ev.duzenleyen, ev.yazar]) x) q;
  if ev.satis > 0 then
    insert into oyun.ajans_haberleri(kaynak_anahtar, kategori, baslik, ozet, metin, oncelik, il_id, zaman)
    values ('imza_sonuc:' || p_id, 'gundem',
            oyun.kad(ev.yazar) || ', ' || oyun.ek_de(il) || ' ' || ev.satis || ' kitap imzaladı',
            '«' || ev.baslik || '» için düzenlenen imza gününe ' || katilim || ' oyuncu katıldı; masada '
              || ev.satis || ' nüsha satıldı.',
            '«' || ev.baslik || '» imza günü ' || to_char(ev.baslangic at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')
              || ' – ' || to_char(ev.bitis at time zone 'Europe/Istanbul', 'HH24:MI') || ' saatleri arasında ' || il
              || ' kültür merkezinde yapıldı. Toplam ' || ev.satis || ' imzalı nüsha satıldı; bunların ' || ev.oyuncu_satis
              || ' tanesini oyuncular aldı.',
            35, ev.il_id, oyun.simdi())
    on conflict (kaynak_anahtar) do nothing;
  end if;
end $$;

-- ---------- Okuma kaydı: gazete_detay ------------------------------------
create or replace function public.gazete_detay(p_gazete bigint)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  g oyun.oyuncu_gazeteleri;
  er boolean;
  hb timestamptz := oyun.hafta_an(oyun.hafta_bas(oyun.simdi()));
  tj jsonb;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;

  er := oyun.gazete_erisim(g.id, p.id, t);

  -- 164: haftalık tiraj için okur kaydı (gazete, oyuncu, gün başına bir kez)
  insert into oyun.gazete_okuma(gazete_id, user_id, gun)
  values (g.id, p.id, (t at time zone 'Europe/Istanbul')::date)
  on conflict do nothing;

  tj := oyun.gazete_tiraj_hesap(g.id, hb, hb + interval '7 days');

  return jsonb_build_object(
    'id', g.id,
    'ad', g.ad,
    'slogan', g.slogan,
    'sahip', oyun.kad(g.sahip),
    'sahibim', g.sahip = p.id,
    'abonelik_ucret', round(g.abonelik_ucret),
    'kasa', case when g.sahip = p.id then round(g.kasa) end,
    'erisim', er,
    'abonelik_bitis', (
      select a.bitis
      from oyun.gazete_abonelik a
      where a.gazete_id = g.id
        and a.user_id = p.id
        and a.bitis > t
    ),
    'abone', (
      select count(*)
      from oyun.gazete_abonelik a
      where a.gazete_id = g.id and a.bitis > t
    ),
    'tiraj', jsonb_build_object(
      'hafta', tj,
      'gecen', (select jsonb_build_object('tiraj', x.tiraj, 'sira', x.sira, 'hafta', x.hafta)
                  from oyun.gazete_tiraj x where x.gazete_id = g.id order by x.hafta desc limit 1),
      'birincilik', (select count(*) from oyun.gazete_tiraj x where x.gazete_id = g.id and x.sira = 1 and x.tiraj > 0),
      'rekor', (select max(x.tiraj) from oyun.gazete_tiraj x where x.gazete_id = g.id)
    ),
    'yazarlar', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'kad', oyun.kad(y.user_id),
          'ucret', round(y.ucret_yazi),
          'benim', y.user_id = p.id
        )
        order by oyun.kad(y.user_id)
      )
      from oyun.gazete_yazarlar y
      where y.gazete_id = g.id and y.aktif
    ), '[]'::jsonb),
    'hareketler', case when g.sahip = p.id then coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'zaman', h.zaman,
          'tutar', round(h.tutar),
          'tur', h.tur,
          'aciklama', h.aciklama
        )
        order by h.zaman desc, h.id desc
      )
      from (
        select *
        from oyun.gazete_hareket
        where gazete_id = g.id
        order by zaman desc, id desc
        limit 20
      ) h
    ), '[]'::jsonb) else '[]'::jsonb end,
    'yayinlar', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', y.id,
          'tur', y.tur,
          'baslik', y.baslik,
          'metin', case
            when er then y.metin
            else left(y.metin, 220)
                 || case when length(y.metin) > 220 then '…' else '' end
          end,
          'kilitli', not er and g.abonelik_ucret > 0,
          'yazar', oyun.kad(y.yazar),
          'zaman', y.zaman,
          'hedef_parti', case
            when y.hedef_parti is null then null
            else oyun.parti_json(y.hedef_parti)
          end
        )
        order by y.zaman desc, y.id desc
      )
      from (
        select *
        from oyun.gazete_yayinlari
        where gazete_id = g.id
        order by zaman desc, id desc
        limit 80
      ) y
    ), '[]'::jsonb)
  );
end $function$;

-- ---------- RPC: Basın tiraj tablosu ---------------------------------------
create or replace function public.basin_tiraj()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  hd date := oyun.hafta_bas(oyun.simdi());
  hb timestamptz := oyun.hafta_an(oyun.hafta_bas(oyun.simdi()));
  son date;
begin
  select max(hafta) into son from oyun.gazete_tiraj;
  return jsonb_build_object(
    'simdi', t,
    'hafta', jsonb_build_object('bas', hb, 'bit', hb + interval '7 days', 'tarih', hd,
                                'no', extract(week from hd)::int),
    'canli', coalesce((
      select jsonb_agg(jsonb_build_object(
               'gazete_id', x.id, 'ad', x.ad, 'sahip', oyun.kad(x.sahip), 'benim', x.sahip = p.id,
               'abonelik_ucret', round(x.abonelik_ucret),
               'tiraj', (x.j->>'tiraj')::int, 'yayin', (x.j->>'yayin')::int, 'okur', (x.j->>'okur')::int,
               'abone', (x.j->>'abone')::int, 'yorumcu', (x.j->>'yorumcu')::int,
               'gecen_tiraj', (select o.tiraj from oyun.gazete_tiraj o where o.hafta = son and o.gazete_id = x.id),
               'gecen_sira', (select o.sira from oyun.gazete_tiraj o where o.hafta = son and o.gazete_id = x.id and o.tiraj > 0),
               'birincilik', (select count(*) from oyun.gazete_tiraj o where o.gazete_id = x.id and o.sira = 1 and o.tiraj > 0))
             order by (x.j->>'tiraj')::int desc, (x.j->>'okur')::int desc, x.id)
        from (select g.*, oyun.gazete_tiraj_hesap(g.id, hb, hb + interval '7 days') j
                from oyun.oyuncu_gazeteleri g where g.aktif) x), '[]'::jsonb),
    'gecen', case when son is null then null else jsonb_build_object(
      'hafta', son,
      'resmi', exists(select 1 from oyun.haftalik_aciklama a where a.hafta = son and a.tur = 'tiraj' and a.duyuruldu),
      'liste', coalesce((
        select jsonb_agg(jsonb_build_object('gazete_id', o.gazete_id, 'ad', g.ad, 'tiraj', o.tiraj, 'sira', o.sira,
                                            'yayin', o.yayin, 'okur', o.okur, 'abone', o.abone, 'yorumcu', o.yorumcu)
                         order by o.sira)
          from oyun.gazete_tiraj o join oyun.oyuncu_gazeteleri g on g.id = o.gazete_id
         where o.hafta = son and o.tiraj > 0), '[]'::jsonb)) end,
    'rekor', (select jsonb_build_object('ad', g.ad, 'tiraj', o.tiraj, 'hafta', o.hafta)
                from oyun.gazete_tiraj o join oyun.oyuncu_gazeteleri g on g.id = o.gazete_id
               order by o.tiraj desc, o.hafta limit 1)
  );
end $$;

-- ---------- RPC: Kitap rekabeti ve imza günleri ---------------------------
create or replace function public.kitap_rekabet()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim();
  u uuid := p.id;
  t timestamptz := oyun.simdi();
  hd date := oyun.hafta_bas(oyun.simdi());
  hb timestamptz := oyun.hafta_an(oyun.hafta_bas(oyun.simdi()));
  gb timestamptz := oyun.hafta_an(oyun.hafta_bas(oyun.simdi())) - interval '7 days';
begin
  return jsonb_build_object(
    'simdi', t,
    'il', p.il_id,
    'hafta', jsonb_build_object('bas', hb, 'bit', hb + interval '7 days', 'tarih', hd, 'no', extract(week from hd)::int),
    'haftalik', coalesce((
      select jsonb_agg(jsonb_build_object('kitap_id', x.kitap_id, 'adet', x.adet, 'ciro', round(x.ciro), 'sira', x.sira) order by x.sira)
        from (select s.kitap_id, sum(s.adet) adet, sum(s.ciro) ciro,
                     row_number() over (order by sum(s.adet) desc, s.kitap_id desc) sira
                from oyun.uc_kitap_satis s join oyun.uc_kitap k on k.id = s.kitap_id and k.durum = 'yayinda'
               where s.zaman >= hb group by s.kitap_id) x where x.sira <= 30), '[]'::jsonb),
    'gecen', coalesce((
      select jsonb_agg(jsonb_build_object('kitap_id', x.kitap_id, 'adet', x.adet, 'sira', x.sira) order by x.sira)
        from (select s.kitap_id, sum(s.adet) adet,
                     row_number() over (order by sum(s.adet) desc, s.kitap_id desc) sira
                from oyun.uc_kitap_satis s join oyun.uc_kitap k on k.id = s.kitap_id and k.durum = 'yayinda'
               where s.zaman >= gb and s.zaman < hb group by s.kitap_id) x where x.sira <= 30), '[]'::jsonb),
    'yayinevleri', coalesce((
      select jsonb_agg(jsonb_build_object('id', y.id, 'ad', y.ad, 'hafta_adet', y.ha, 'hafta_ciro', round(y.hc),
                                          'gecen_adet', y.ga, 'toplam_adet', y.ta, 'kitap', y.kc, 'imza', y.ic,
                                          'benim', y.benim) order by y.ha desc, y.ta desc, y.id)
        from (select s.id, s.ad,
                     coalesce((select sum(x.adet) from oyun.uc_kitap_satis x join oyun.uc_kitap k on k.id = x.kitap_id where k.yayinevi = s.id and x.zaman >= hb), 0) ha,
                     coalesce((select sum(x.ciro) from oyun.uc_kitap_satis x join oyun.uc_kitap k on k.id = x.kitap_id where k.yayinevi = s.id and x.zaman >= hb), 0) hc,
                     coalesce((select sum(x.adet) from oyun.uc_kitap_satis x join oyun.uc_kitap k on k.id = x.kitap_id where k.yayinevi = s.id and x.zaman >= gb and x.zaman < hb), 0) ga,
                     coalesce((select sum(k.satilan) from oyun.uc_kitap k where k.yayinevi = s.id and k.durum = 'yayinda'), 0) ta,
                     (select count(*) from oyun.uc_kitap k where k.yayinevi = s.id and k.durum = 'yayinda') kc,
                     (select count(*) from oyun.kitap_imza_gunu e join oyun.uc_kitap k on k.id = e.kitap_id where k.yayinevi = s.id and e.durum = 'bitti') ic,
                     exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = u and o.pay >= 50) benim
                from oyun.sirketler s where s.aktif and s.sektor = 'medya') y), '[]'::jsonb),
    'yazarlar', coalesce((
      select jsonb_agg(jsonb_build_object('kad', oyun.kad(a.yazar), 'toplam_adet', a.ta, 'hafta_adet', a.ha,
                                          'kitap', a.kc, 'benim', a.yazar = u) order by a.ta desc, a.ha desc)
        from (select k.yazar, sum(k.satilan) ta, count(*) kc,
                     coalesce((select sum(x.adet) from oyun.uc_kitap_satis x join oyun.uc_kitap k2 on k2.id = x.kitap_id
                                where k2.yazar = k.yazar and x.zaman >= hb), 0) ha
                from oyun.uc_kitap k where k.durum = 'yayinda' group by k.yazar order by 2 desc limit 20) a), '[]'::jsonb),
    'imza', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'kitap_id', e.kitap_id, 'baslik', k.baslik, 'yazar', oyun.kad(k.yazar),
               'yayinevi_ad', s.ad, 'il_id', e.il_id, 'il_ad', i.ad, 'baslangic', e.baslangic, 'bitis', e.bitis,
               'durum', e.durum, 'satis', e.satis, 'oyuncu_satis', e.oyuncu_satis, 'fiyat', k.fiyat, 'stok', k.stok,
               'duzenleyen', oyun.kad(e.duzenleyen), 'rol', e.rol, 'benim', e.duzenleyen = u, 'yazar_benim', k.yazar = u,
               'katilim', (select count(*) from oyun.kitap_imza_katilim c where c.imza_id = e.id),
               'yerel', (select count(*) from oyun.kitap_imza_katilim c where c.imza_id = e.id and c.yerel),
               'katildim', exists(select 1 from oyun.kitap_imza_katilim c where c.imza_id = e.id and c.user_id = u),
               'aldim', exists(select 1 from oyun.uc_kitap_satis x where x.kitap_id = e.kitap_id and x.alici = u),
               'imzali_aldim', exists(select 1 from oyun.uc_kitap_satis x where x.imza_id = e.id and x.alici = u),
               'hedef', case when e.durum in ('planli', 'canli') then oyun.kitap_imza_hedef(e.id) end,
               'maliyet', case when e.duzenleyen = u then e.maliyet end)
             order by case e.durum when 'canli' then 0 when 'planli' then 1 else 2 end,
                      case when e.durum = 'bitti' then null else e.baslangic end, e.bitis desc)
        from oyun.kitap_imza_gunu e
        join oyun.uc_kitap k on k.id = e.kitap_id
        join oyun.sirketler s on s.id = k.yayinevi
        join oyun.iller i on i.id = e.il_id
       where e.durum in ('planli', 'canli') or (e.durum = 'bitti' and e.bitis > t - interval '14 days')), '[]'::jsonb),
    'imzali', coalesce((select jsonb_agg(distinct x.kitap_id) from oyun.uc_kitap_satis x where x.alici = u and x.imza_id is not null), '[]'::jsonb),
    'duzenlenebilir', coalesce((
      select jsonb_agg(jsonb_build_object(
               'kitap_id', k.id, 'baslik', k.baslik, 'stok', k.stok, 'yazar', k.yazar = u,
               'yayinevi', exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = k.yayinevi and o.user_id = u and o.pay >= 50),
               'yayinevi_ad', s.ad,
               'engel', case
                 when k.stok < 10 then 'Stokta en az 10 nüsha olmalı; yayınevi yeni baskı yapmalı.'
                 when exists(select 1 from oyun.kitap_imza_gunu e where e.kitap_id = k.id and e.durum in ('planli', 'canli'))
                   then 'Bu kitabın zaten planlanmış bir imza günü var.'
                 when exists(select 1 from oyun.kitap_imza_gunu e where e.kitap_id = k.id and e.durum = 'bitti' and e.bitis > t - interval '48 hours')
                   then 'Yeni imza günü için son imza gününden 48 saat geçmeli.'
               end) order by k.baslik)
        from oyun.uc_kitap k join oyun.sirketler s on s.id = k.yayinevi and s.aktif
       where k.durum = 'yayinda'
         and (k.yazar = u or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = k.yayinevi and o.user_id = u and o.pay >= 50))), '[]'::jsonb),
    'aktif_imzam', (select count(*) from oyun.kitap_imza_gunu e where e.duzenleyen = u and e.durum in ('planli', 'canli')),
    'ucretler', coalesce((
      select jsonb_agg(jsonb_build_object('il', i.id, 'ad', i.ad, 'ucret', oyun.imza_gunu_ucret(i.id),
                                          'talep', coalesce(case when oyun.il_ekonomi_acik() then oyun.il_talep_endeksi(i.id) end, 1))
                       order by i.ad)
        from oyun.iller i), '[]'::jsonb),
    'kurallar', jsonb_build_object('sure_saat', 3, 'min_stok', 10, 'bekleme_saat', 48, 'max_aktif', 2,
                                   'iade_yuzde', 50, 'en_erken_dk', 15, 'en_gec_gun', 7, 'tavan', 150)
  );
end $$;

create or replace function public.kitap_imza_islem(p_islem text, p_id bigint, p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim();
  u uuid := p.id;
  t timestamptz := oyun.simdi();
  k oyun.uc_kitap;
  ev oyun.kitap_imza_gunu;
  v_il smallint; v_bas timestamptz; v_rol text; v_odeme text; v_ucret numeric; v_id bigint; v_il_ad text;
  yonetici boolean; iade numeric; kalan_sure interval;
begin
  if p_veri is null or jsonb_typeof(p_veri) <> 'object' then raise exception 'Veri hatalı'; end if;

  if p_islem = 'duzenle' then
    select * into k from oyun.uc_kitap where id = p_id for update;
    if k.id is null or k.durum <> 'yayinda' then raise exception 'Kitap bulunamadı ya da yayında değil.'; end if;
    yonetici := exists(select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id and s.aktif
                        where o.sirket_id = k.yayinevi and o.user_id = u and o.pay >= 50);
    if k.yazar <> u and not yonetici then
      raise exception 'İmza gününü yalnız kitabın yazarı ya da yayınevinin yöneticisi düzenleyebilir.';
    end if;
    v_odeme := coalesce(nullif(p_veri->>'odeme', ''), case when yonetici then 'yayinevi' else 'cuzdan' end);
    if v_odeme not in ('cuzdan', 'yayinevi') then raise exception 'Ödeme kaynağı hatalı.'; end if;
    if v_odeme = 'yayinevi' and not yonetici then raise exception 'Yayınevi kasasını yalnız yayınevinin yöneticisi kullanabilir.'; end if;
    if v_odeme = 'cuzdan' and k.yazar <> u and not yonetici then raise exception 'Yetkin yok.'; end if;
    v_rol := case when v_odeme = 'yayinevi' then 'yayinevi' else 'yazar' end;
    if v_rol = 'yazar' and k.yazar <> u then v_rol := 'yayinevi'; end if;

    if k.stok < 10 then raise exception 'İmza günü için stokta en az 10 nüsha olmalı. Yayınevi önce yeni baskı yapmalı.'; end if;
    begin
      v_il := (p_veri->>'il')::smallint;
      v_bas := date_trunc('minute', (p_veri->>'baslangic')::timestamptz);
    exception when others then raise exception 'İl ve başlangıç zamanı hatalı.';
    end;
    select ad into v_il_ad from oyun.iller where id = v_il;
    if v_il_ad is null then raise exception 'İl bulunamadı.'; end if;
    if v_bas is null or v_bas < t + interval '14 minutes' or v_bas > t + interval '7 days' then
      raise exception 'İmza günü en erken 15 dakika, en geç 7 gün sonrasına planlanabilir.';
    end if;
    if exists(select 1 from oyun.kitap_imza_gunu e where e.kitap_id = k.id and e.durum in ('planli', 'canli')) then
      raise exception 'Bu kitabın zaten planlanmış bir imza günü var.';
    end if;
    select max(e.bitis) + interval '48 hours' - v_bas into kalan_sure
      from oyun.kitap_imza_gunu e where e.kitap_id = k.id and e.durum = 'bitti';
    if kalan_sure is not null and kalan_sure > interval '0' then
      raise exception 'Bu kitap için yeni imza günü, son imza gününün bitişinden 48 saat sonrasına planlanabilir.';
    end if;
    if (select count(*) from oyun.kitap_imza_gunu e where e.duzenleyen = u and e.durum in ('planli', 'canli')) >= 2 then
      raise exception 'Aynı anda en çok 2 açık imza günün olabilir.';
    end if;

    v_ucret := oyun.imza_gunu_ucret(v_il);
    if v_odeme = 'cuzdan' then
      update oyun.cuzdan set para = para - v_ucret where user_id = u and para >= v_ucret;
      if not found then raise exception 'Cüzdanında yeterli para yok. % salon kirası % ₺.', v_il_ad, oyun.tl(v_ucret); end if;
    else
      update oyun.sirketler set kasa = kasa - v_ucret where id = k.yayinevi and aktif and kasa >= v_ucret;
      if not found then raise exception 'Yayınevi kasasında yeterli para yok. % salon kirası % ₺.', v_il_ad, oyun.tl(v_ucret); end if;
      insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
      values (k.yayinevi, t, -v_ucret, 'İmza günü salon kirası: «' || k.baslik || '», ' || v_il_ad, 0, v_ucret, 0);
    end if;

    insert into oyun.kitap_imza_gunu(kitap_id, duzenleyen, rol, odeme, il_id, baslangic, bitis, maliyet, olusturma)
    values (k.id, u, v_rol, v_odeme, v_il, v_bas, v_bas + interval '3 hours', v_ucret, t)
    returning id into v_id;

    insert into oyun.ajans_haberleri(kaynak_anahtar, kategori, baslik, ozet, metin, oncelik, il_id, zaman)
    values ('imza:' || v_id, 'gundem',
            oyun.kad(k.yazar) || ' ' || oyun.ek_de(v_il_ad) || ' okurlarıyla buluşuyor',
            '«' || k.baslik || '» için imza günü ' || to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM.YYYY') || ', saat '
              || to_char(v_bas at time zone 'Europe/Istanbul', 'HH24:MI') || ' – ' || to_char((v_bas + interval '3 hours') at time zone 'Europe/Istanbul', 'HH24:MI') || '.',
            oyun.kad(k.yazar) || ', «' || k.baslik || '» kitabını ' || to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM.YYYY')
              || ' günü saat ' || to_char(v_bas at time zone 'Europe/Istanbul', 'HH24:MI') || ' ile '
              || to_char((v_bas + interval '3 hours') at time zone 'Europe/Istanbul', 'HH24:MI') || ' arasında ' || v_il_ad
              || ' kültür merkezinde imzalayacak. Etkinliği ' || (select s.ad from oyun.sirketler s where s.id = k.yayinevi)
              || ' yayınevi destekliyor. Kitaplar ve yayınevleri ekranından katılabilirsin.',
            30, v_il, t)
    on conflict (kaynak_anahtar) do nothing;

    perform oyun.bildir(q.id, 'İmza günü: «' || k.baslik || '» yazarı ' || oyun.kad(k.yazar) || ', '
                        || to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') || ' – ' || to_char((v_bas + interval '3 hours') at time zone 'Europe/Istanbul', 'HH24:MI')
                        || ' arasında ' || oyun.ek_de(v_il_ad) || ' imza masasında. Kitaplar ve yayınevleri ekranından katılabilirsin.')
       from (select pr.id from oyun.profiller pr where pr.il_id = v_il and pr.id <> u and not coalesce(pr.yasakli, false)
              order by pr.son_gorulme desc nulls last limit 200) q;
    if k.yazar <> u then
      perform oyun.bildir(k.yazar, 'İmza günü: yayınevin «' || k.baslik || '» için ' || oyun.ek_de(v_il_ad) || ' imza günü düzenledi ('
                          || to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') || ').');
    end if;
    return jsonb_build_object('id', v_id, 'maliyet', v_ucret, 'baslangic', v_bas, 'il', v_il_ad);
  end if;

  select * into ev from oyun.kitap_imza_gunu where id = p_id for update;
  if ev.id is null then raise exception 'İmza günü bulunamadı.'; end if;
  select * into k from oyun.uc_kitap where id = ev.kitap_id;

  if p_islem = 'katil' then
    if ev.durum not in ('planli', 'canli') or t >= ev.bitis then raise exception 'Bu imza günü sona erdi.'; end if;
    if ev.duzenleyen = u or k.yazar = u then raise exception 'Kendi imza gününe katılım sayılmaz.'; end if;
    insert into oyun.kitap_imza_katilim(imza_id, user_id, yerel, zaman)
    values (ev.id, u, coalesce(p.il_id = ev.il_id, false), t) on conflict do nothing;
    return jsonb_build_object('katildim', true, 'hedef', oyun.kitap_imza_hedef(ev.id));
  end if;

  if p_islem = 'imzali_al' then
    if ev.durum <> 'canli' or t < ev.baslangic or t >= ev.bitis then raise exception 'İmza masası şu anda açık değil.'; end if;
    select * into k from oyun.uc_kitap where id = ev.kitap_id for update;
    if k.yazar = u then raise exception 'Kendi kitabını satın alamazsın.'; end if;
    if k.durum <> 'yayinda' or k.stok < 1 then raise exception 'Masada imzalanacak kitap kalmadı.'; end if;
    if exists(select 1 from oyun.uc_kitap_satis x where x.kitap_id = k.id and x.alici = u) then
      raise exception 'Bu kitap zaten kitaplığında.';
    end if;
    update oyun.cuzdan set para = para - k.fiyat where user_id = u and para >= k.fiyat;
    if not found then raise exception 'Bakiye yetersiz'; end if;
    perform oyun.uc_kitap_kazanc(k.id, 1, u, null);
    update oyun.uc_kitap_satis set imza_id = ev.id where kitap_id = k.id and alici = u;
    update oyun.kitap_imza_gunu set satis = satis + 1, oyuncu_satis = oyuncu_satis + 1, son_islem = t where id = ev.id;
    if ev.duzenleyen <> u then
      insert into oyun.kitap_imza_katilim(imza_id, user_id, yerel, zaman)
      values (ev.id, u, coalesce(p.il_id = ev.il_id, false), t) on conflict do nothing;
    end if;
    return jsonb_build_object('imzali', true, 'fiyat', k.fiyat);
  end if;

  if p_islem = 'iptal' then
    if ev.duzenleyen <> u then raise exception 'İmza gününü yalnız düzenleyen iptal edebilir.'; end if;
    if ev.durum <> 'planli' or t >= ev.baslangic then raise exception 'Başlamış imza günü iptal edilemez.'; end if;
    iade := round(ev.maliyet / 2);
    if ev.odeme = 'cuzdan' then
      perform oyun.cuzdanim(u);
      update oyun.cuzdan set para = para + iade where user_id = u;
    else
      update oyun.sirketler set kasa = kasa + iade where id = k.yayinevi;
      insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
      values (k.yayinevi, t, iade, 'İptal edilen imza gününün kira iadesi: «' || k.baslik || '»', 0, -iade, 0);
    end if;
    if ev.maliyet - iade > 0 then
      update oyun.il_durum set kasa = kasa + (ev.maliyet - iade) where il_id = ev.il_id;
      if found then
        insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
        values (ev.il_id, 'kultur', ev.maliyet - iade, 'İptal edilen imza günü: salon kirasının yarısı', t);
      end if;
    end if;
    update oyun.kitap_imza_gunu set durum = 'iptal', son_islem = t where id = ev.id;
    perform oyun.bildir(c.user_id, 'İmza günü: «' || k.baslik || '» imza günü iptal edildi.')
       from oyun.kitap_imza_katilim c where c.imza_id = ev.id;
    return jsonb_build_object('iptal', true, 'iade', iade);
  end if;

  raise exception 'Bilinmeyen imza günü işlemi';
end $$;

-- ---------- İzinler --------------------------------------------------------
revoke all on function oyun.hafta_bas(timestamptz), oyun.hafta_an(date), oyun.imza_gunu_ucret(smallint),
  oyun.gazete_tiraj_hesap(bigint, timestamptz, timestamptz), oyun.gazete_tiraj_kaydet(date, boolean),
  oyun.kitap_hafta_aciklama(date, boolean), oyun.kitap_imza_hedef(bigint), oyun.kitap_imza_satis(bigint, timestamptz),
  oyun.basin_kitap_tick(), oyun.kitap_imza_bitir(bigint), oyun.ek_de(text)
  from public, anon, authenticated;
revoke all on function public.basin_tiraj(), public.kitap_rekabet(), public.kitap_imza_islem(text, bigint, jsonb)
  from public, anon;
grant execute on function public.basin_tiraj(), public.kitap_rekabet(), public.kitap_imza_islem(text, bigint, jsonb)
  to authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.basin_tiraj(), public.kitap_rekabet(), public.kitap_imza_islem(text, bigint, jsonb),
      oyun.basin_kitap_tick() to service_role;
  end if;
end $$;

-- ---------- Zamanlayıcı ----------------------------------------------------
insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
values ('basin_kitap_rekabet', 'select oyun.basin_kitap_tick()', 5, 4, 76, true)
on conflict (adim) do update set komut = excluded.komut, periyot_dk = excluded.periyot_dk,
  ofset_dk = excluded.ofset_dk, aktif = true;

-- Geçen haftanın tirajı ilk kurulumda sessizce kaydedilir (karşılaştırma için);
-- duyuru ve bildirim bir sonraki Pazartesi'den itibaren yapılır.
select oyun.gazete_tiraj_kaydet(oyun.hafta_bas(oyun.simdi()) - 7, false);
select oyun.kitap_hafta_aciklama(oyun.hafta_bas(oyun.simdi()) - 7, false);
