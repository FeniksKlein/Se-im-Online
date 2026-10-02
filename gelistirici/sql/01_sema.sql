-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 1) ŞEMA
--  Tablolar "oyun" şemasında durur; bu şema internete AÇILMAZ.
--  Uygulama yalnızca public şemadaki fonksiyonları (RPC) çağırabilir.
-- =====================================================================
create schema if not exists oyun;
revoke all on schema oyun from public;

-- Tek satırlık oyun ayarları
create table if not exists oyun.ayarlar(
  id            int primary key default 1 check (id = 1),
  baraj         numeric not null default 7,      -- ulusal seçim barajı (%)
  min_hesap_gun int     not null default 3,      -- oy/aday için hesabın en az kaç günlük olması gerektiği
  il_degis_gun  int     not null default 30,     -- iki il değişikliği arası en az gün
  parti_kur_gun int     not null default 30,     -- iki parti kuruluşu arası en az gün
  baslangic     timestamptz not null default now(), -- bu andan önceki seçimler oluşturulmaz
  test_simdi    timestamptz,                     -- SADECE TEST: doluysa oyun saati bu kabul edilir
  son_temizlik  date                             -- eski sohbet/bildirimlerin en son temizlendiği gün
);
insert into oyun.ayarlar(id) values (1) on conflict do nothing;

create or replace function oyun.simdi() returns timestamptz language sql stable as $$
  select coalesce((select test_simdi from oyun.ayarlar where id = 1), now())
$$;

-- 81 il (plaka kodu = id), vekil sayıları YSK Mart 2026
create table if not exists oyun.iller(
  id smallint primary key,
  ad text not null unique,
  mv smallint not null check (mv > 0)
);

create table if not exists oyun.partiler(
  id        bigserial primary key,
  ad        text not null,
  kisa      text not null,
  renk      text not null default '#888888',
  amblem    text not null default 'a_yildiz',
  gb        uuid,            -- genel başkan
  kurucu    uuid,
  sistem    boolean not null default false,   -- oyunla gelen kurgusal parti
  kapali    boolean not null default false,
  kurulus   timestamptz not null default now()
);
create unique index if not exists partiler_ad_tekil   on oyun.partiler (lower(ad))   where not kapali;
create unique index if not exists partiler_kisa_tekil on oyun.partiler (lower(kisa)) where not kapali;

create table if not exists oyun.profiller(
  id             uuid primary key references auth.users(id) on delete cascade,
  kad            text not null,                 -- kullanıcı adı
  il_id          smallint not null references oyun.iller(id),
  il_at          timestamptz not null default now(),   -- bu ile kayıt anı
  son_il_degis   timestamptz,
  parti_id       bigint references oyun.partiler(id),
  parti_at       timestamptz,                   -- bu partiye katılma anı
  son_parti_kur  timestamptz,
  olusturma      timestamptz not null default now(),
  bildirim_okundu timestamptz not null default now(),  -- bildirim kutusunu en son açtığı an
  susturma_bitis timestamptz,                           -- yönetici susturduysa bu ana kadar yazamaz
  son_mesaj      timestamptz,
  son_gorulme    timestamptz,
  yonetici       boolean not null default false,        -- oyun yöneticisi (yönetici paneline erişir)
  yasakli        boolean not null default false,        -- hesabı kapatılmış
  bildirim_ayar  jsonb not null default '{"secim":true,"ozel":true,"propaganda":true,"kisisel":true}'
);
create unique index if not exists profiller_kad_tekil on oyun.profiller (lower(kad));
create index if not exists profiller_il on oyun.profiller(il_id);
create index if not exists profiller_parti on oyun.profiller(parti_id);

-- İttifaklar (2. aşamada arayüzü gelecek; baraj hesabı şimdiden destekliyor)
create table if not exists oyun.ittifaklar(
  id bigserial primary key,
  ad text not null,
  kurulus timestamptz not null default now()
);
create table if not exists oyun.ittifak_uyeler(
  ittifak_id bigint not null references oyun.ittifaklar(id) on delete cascade,
  parti_id   bigint not null references oyun.partiler(id) on delete cascade,
  primary key (parti_id)
);

-- Seçimler. tur:
--   mv_on    vekil ön seçimi (parti listeleri)      donem = genel seçimin ayı
--   mv       genel seçim (partiye oy)               donem = genel seçimin ayı
--   cb_on    parti içi cumhurbaşkanı adayı ön seçimi
--   cb       cumhurbaşkanı seçimi 1. tur  (basvuru penceresi = genel başkanın aday kararı süresi)
--   cb2      cumhurbaşkanı seçimi 2. tur  (gerekirse otomatik açılır)
--   bel_on   belediye başkanı ön seçimi
--   bel      il belediye başkanlığı seçimi
--   kurultay genel başkan seçimi
create table if not exists oyun.secimler(
  id          bigserial primary key,
  tur         text not null check (tur in ('mv_on','mv','cb_on','cb','cb2','bel_on','bel','kurultay')),
  donem       text not null,          -- 'YYYY-MM'
  basvuru_bas timestamptz,
  basvuru_bit timestamptz,
  oy_bas      timestamptz not null,
  oy_bit      timestamptz not null,
  sonuc_at    timestamptz not null,
  goreve_bas  timestamptz,
  durum       text not null default 'bekliyor' check (durum in ('bekliyor','sonuclandi','tamam')),
  sonuc       jsonb,
  hatirlatma  jsonb not null default '{}',   -- gönderilen push hatırlatmaları
  unique (tur, donem)
);

create table if not exists oyun.adaylar(
  id          bigserial primary key,
  secim_id    bigint not null references oyun.secimler(id) on delete cascade,
  user_id     uuid not null,
  parti_id    bigint references oyun.partiler(id),
  il_id       smallint references oyun.iller(id),
  basvuru_at  timestamptz not null default now(),
  sira        int,            -- mv_on: ön seçim sonrası liste sırası
  oy          int,            -- sayım sonrası aldığı oy
  vaat        text,           -- adayın seçim bildirgesi
  unique (secim_id, user_id)
);
create index if not exists adaylar_secim on oyun.adaylar(secim_id, il_id, parti_id);

-- Oylar GİZLİDİR: hiçbir uygulama fonksiyonu kimin kime oy verdiğini döndürmez.
create table if not exists oyun.oylar(
  secim_id  bigint not null references oyun.secimler(id) on delete cascade,
  secmen    uuid not null,
  il_id     smallint,
  parti_id  bigint,
  aday_id   bigint,
  zaman     timestamptz not null default now(),
  primary key (secim_id, secmen)
);
create index if not exists oylar_say on oyun.oylar(secim_id, il_id, parti_id);

-- Genel başkanın cumhurbaşkanı adayı kararı (her genel seçim dönemi için)
create table if not exists oyun.cb_kararlar(
  donem    text not null,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  yontem   text not null check (yontem in ('kendisi','baskasi','onsecim','destek')),
  aday     uuid,
  destek_parti bigint,     -- yontem = 'destek' ise desteklenen ittifak ortağı
  zaman    timestamptz not null default now(),
  primary key (donem, parti_id)
);

-- Seçim kazananları (göreve başlamayı bekleyen)
create table if not exists oyun.kazananlar(
  secim_id bigint not null references oyun.secimler(id) on delete cascade,
  user_id  uuid not null,
  il_id    smallint,
  parti_id bigint,
  primary key (secim_id, user_id)
);

-- Seçilmiş makamlar: mv (vekil), bel (il belediye başkanı), cb (cumhurbaşkanı)
create table if not exists oyun.makamlar(
  id        bigserial primary key,
  tur       text not null check (tur in ('mv','bel','cb','bakan')),
  user_id   uuid not null,
  bakanlik  text,               -- tur = 'bakan' ise bakanlık kodu
  il_id     smallint,
  parti_id  bigint,             -- seçildiği parti
  secim_id  bigint references oyun.secimler(id) on delete set null,
  kaynak    text not null default 'secim' check (kaynak in ('secim','yedek','atama')),
  bas       timestamptz not null,
  bit       timestamptz,        -- null = görevde
  bitis_neden text
);
create index if not exists makamlar_aktif on oyun.makamlar(tur, il_id) where bit is null;
create index if not exists makamlar_user  on oyun.makamlar(user_id) where bit is null;
create unique index if not exists makamlar_bakanlik_tek on oyun.makamlar(bakanlik) where bit is null and tur = 'bakan';

-- Genel başkan yardımcıları (6 sıra, genel başkan atar)
create table if not exists oyun.parti_gby(
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  sira     smallint not null check (sira between 1 and 6),
  user_id  uuid not null,
  atama    timestamptz not null default now(),
  primary key (parti_id, sira),
  unique (user_id)
);

-- 12 temel bakanlık (cumhurbaşkanı atar)
create table if not exists oyun.bakanliklar(
  kod  text primary key,
  ad   text not null,
  sira int not null
);
insert into oyun.bakanliklar(kod, ad, sira) values
  ('adalet',   'Adalet Bakanlığı', 1),
  ('disisleri','Dışişleri Bakanlığı', 2),
  ('icisleri', 'İçişleri Bakanlığı', 3),
  ('maliye',   'Hazine ve Maliye Bakanlığı', 4),
  ('savunma',  'Millî Savunma Bakanlığı', 5),
  ('egitim',   'Millî Eğitim Bakanlığı', 6),
  ('saglik',   'Sağlık Bakanlığı', 7),
  ('sanayi',   'Sanayi ve Teknoloji Bakanlığı', 8),
  ('ticaret',  'Ticaret Bakanlığı', 9),
  ('tarim',    'Tarım ve Orman Bakanlığı', 10),
  ('ulastirma','Ulaştırma ve Altyapı Bakanlığı', 11),
  ('calisma',  'Çalışma ve Sosyal Güvenlik Bakanlığı', 12)
on conflict (kod) do update set ad = excluded.ad, sira = excluded.sira;

-- ---------------- SOSYAL: sohbet, özel mesaj, propaganda, bildirim ----------------
-- Sohbet kanalları: 'genel' · 'il:<plaka>' · 'parti:<id>' · 'meclis'
create table if not exists oyun.mesajlar(
  id      bigserial primary key,
  kanal   text not null,
  user_id uuid not null,
  metin   text not null check (length(metin) between 1 and 500),
  zaman   timestamptz not null default now(),
  gizli   boolean not null default false     -- şikâyet eşiğini aşınca veya yönetici gizleyince
);
create index if not exists mesajlar_kanal on oyun.mesajlar(kanal, id desc);

-- Özel mesajlar (iki oyuncu arası)
create table if not exists oyun.ozel(
  id      bigserial primary key,
  gonderen uuid not null,
  alici   uuid not null,
  metin   text not null check (length(metin) between 1 and 1000),
  zaman   timestamptz not null default now(),
  okundu  boolean not null default false,
  gizli   boolean not null default false
);
create index if not exists ozel_alici on oyun.ozel(alici, id desc);
create index if not exists ozel_gonderen on oyun.ozel(gonderen, id desc);

-- Propaganda / resmi duyuru yayınları. Hedef kitle: hedef_il ve hedef_parti
-- (ikisi de boş = tüm Türkiye; yalnız il = o ildeki herkes; yalnız parti = partinin üyeleri; ikisi = partinin o ildeki üyeleri)
create table if not exists oyun.yayinlar(
  id          bigserial primary key,
  tur         text not null check (tur in ('cb','bakan','parti','vekil','belediye','aday','sistem')),
  gonderen    uuid not null,
  metin       text not null check (length(metin) between 1 and 600),
  zaman       timestamptz not null default now(),
  hedef_il    smallint,
  hedef_parti bigint,
  secim_id    bigint,
  unvan       text not null,          -- gönderildiği andaki sıfat: "Cumhurbaşkanı", "İzmir Belediye Başkanı adayı" ...
  gizli       boolean not null default false
);
create index if not exists yayinlar_zaman on oyun.yayinlar(zaman desc);

-- Kişiye özel bildirimler (atama, seçilme, görevden alınma ...)
create table if not exists oyun.bildirimler(
  id      bigserial primary key,
  user_id uuid not null,
  zaman   timestamptz not null default now(),
  metin   text not null
);
create index if not exists bildirimler_user on oyun.bildirimler(user_id, zaman desc);

create table if not exists oyun.engellemeler(
  engelleyen uuid not null,
  engellenen uuid not null,
  zaman timestamptz not null default now(),
  primary key (engelleyen, engellenen)
);

create table if not exists oyun.sikayetler(
  id        bigserial primary key,
  sikayetci uuid not null,
  hedef_user uuid,
  tur       text not null check (tur in ('mesaj','ozel','yayin','oyuncu')),
  kayit_id  bigint,
  neden     text not null,
  zaman     timestamptz not null default now(),
  durum     text not null default 'yeni' check (durum in ('yeni','incelendi')),
  unique (sikayetci, tur, kayit_id)
);

-- Olay günlüğü (haber akışı)
create table if not exists oyun.olaylar(
  id     bigserial primary key,
  zaman  timestamptz not null default now(),
  tur    text not null,
  il_id  smallint,
  parti_id bigint,
  metin  text not null
);
create index if not exists olaylar_zaman on oyun.olaylar(zaman desc);

-- Oyunla gelen 5 kurgusal parti (gerçek partilerle bağı yoktur)
insert into oyun.partiler(ad, kisa, renk, amblem, sistem)
select * from (values
  ('Cumhuriyet Yolu Partisi', 'CYP', '#c62828', 'a_ayyildiz', true),
  ('Anadolu Birlik Partisi',  'ABP', '#ef8f00', 'a_basak',     true),
  ('Yeni Demokrasi Partisi',  'YDP', '#1565c0', 'a_guvercin',  true),
  ('Millî Kalkınma Partisi',  'MKP', '#2e7d32', 'a_cinar',     true),
  ('Emek ve Özgürlük Partisi','EÖP', '#6a1b9a', 'a_mesale',    true)
) v(ad,kisa,renk,amblem,sistem)
where not exists (select 1 from oyun.partiler where sistem);
