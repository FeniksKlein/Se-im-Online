-- SEÇİM SİMÜLASYONU ONLINE — üretilmiş kaynak; elle düzenlemeyin.
-- Oyunu sıfırlamaz. Tek işlem, otomatik yedek ve oyuncu verisi bütünlük kontrolü.
-- Canlı sunucuda uygulanmış sürümler için tekrar çalıştırmayın; bu dosya kurulum/eşitleme kaynağıdır.
begin;
-- =====================================================================
--  KALICILIK: OYUN HİÇ SIFIRLANMAZ
--
--  Her güncelleme (supabase-kurulum.sql) tek bir işlem (transaction) içinde çalışır:
--    1) guncelleme_basla : oyunun yedeği alınır, oyuncu verisinin "parmak izi" çıkarılır
--    2) şema ve fonksiyonlar güncellenir (yalnızca EKLER: yeni tablo, yeni sütun, yeni makam türü…)
--    3) guncelleme_bitti : parmak izi yeniden çıkarılır. Oyuncuların hesabı, makamı, parası, kıdemi,
--       oyları, partileri, mülkleri… tek bir bayt bile değiştiyse GÜNCELLEME DURDURULUR ve hiçbir şey
--       uygulanmaz (işlem geri alınır). Böylece bir güncelleme oyunu asla bozamaz.
--  Ayrıca: oyun tabloları TRUNCATE ile boşaltılamaz, DROP TABLE / DROP COLUMN ile silinemez
--  (yalnızca sahibinin bilerek çalıştıracağı sıfırlama/geri yükleme fonksiyonlarıyla).
--  Oyunu sıfırlamak yalnızca oyun sahibinin işidir:  select oyun.oyunu_sifirla('OYUNU SIFIRLA');
-- =====================================================================
create schema if not exists oyun;
revoke all on schema oyun from public;

create table if not exists oyun.surumler(
  id          serial primary key,
  surum       text not null,
  aciklama    text,
  baslangic   timestamptz not null default clock_timestamp(),
  bitis       timestamptz,
  yedek       text,
  parmak_once jsonb,
  parmak_sonra jsonb
);

-- Oyuncu verisinin parmak izi: sayılar, toplamlar ve içerik özetleri (var olan tablo/sütunlar üzerinden)
create or replace function oyun.parmak_izi() returns jsonb language plpgsql as $$
declare sonuc jsonb := '{}'; r record; v text; yeni_tablo text;
begin
  for r in select * from (values
    ('oyuncu',        'oyun.profiller',     'select count(*)::text from oyun.profiller'),
    ('profiller',     'oyun.profiller',     'select md5(coalesce(string_agg(id::text||''|''||kad||''|''||il_id||''|''||coalesce(parti_id::text,'''')||''|''||olusturma::text, '','' order by id), '''')) from oyun.profiller'),
    ('makamlar',      'oyun.makamlar',      'select md5(coalesce(string_agg(id||''|''||tur||''|''||user_id||''|''||coalesce(il_id::text,'''')||''|''||coalesce(bakanlik,'''')||''|''||bas::text||''|''||coalesce(bit::text,''''), '','' order by id), '''')) from oyun.makamlar'),
    ('aktif_makam',   'oyun.makamlar',      'select count(*)::text from oyun.makamlar where bit is null'),
    ('cuzdanlar',     'oyun.cuzdan',        'select md5(coalesce(string_agg(user_id||''|''||para||''|''||kidem||''|''||coalesce(seri::text,''''), '','' order by user_id), '''')) from oyun.cuzdan'),
    ('toplam_para',   'oyun.cuzdan',        'select coalesce(sum(para),0)::text from oyun.cuzdan'),
    ('toplam_kidem',  'oyun.cuzdan',        'select coalesce(sum(kidem),0)::text from oyun.cuzdan'),
    ('partiler',      'oyun.partiler',      'select md5(coalesce(string_agg(id||''|''||ad||''|''||kisa||''|''||coalesce(gb::text,'''')||''|''||kasa||''|''||kapali, '','' order by id), '''')) from oyun.partiler'),
    ('gby',           'oyun.parti_gby',     'select count(*)::text from oyun.parti_gby'),
    ('oylar',         'oyun.oylar',         'select count(*)::text from oyun.oylar'),
    ('secimler',      'oyun.secimler',      'select md5(coalesce(string_agg(id||''|''||tur||''|''||donem||''|''||durum, '','' order by id), '''')) from oyun.secimler'),
    ('adaylar',       'oyun.adaylar',       'select count(*)::text from oyun.adaylar'),
    ('kazananlar',    'oyun.kazananlar',    'select count(*)::text from oyun.kazananlar'),
    ('hareketler',    'oyun.hesap_hareket', 'select count(*)::text from oyun.hesap_hareket'),
    ('kanunlar',      'oyun.kanunlar',      'select md5(coalesce(string_agg(id||''|''||durum||''|''||coalesce(no::text,''''), '','' order by id), '''')) from oyun.kanunlar'),
    ('kararnameler',  'oyun.kararnameler',  'select count(*)::text from oyun.kararnameler'),
    ('mesajlar',      'oyun.mesajlar',      'select count(*)::text from oyun.mesajlar'),
    ('ozel',          'oyun.ozel', 'select count(*)::text from oyun.ozel'),
    ('vaatler',       'oyun.vaatler',       'select count(*)::text from oyun.vaatler'),
    ('itibar',        'oyun.itibar',        'select count(*)::text from oyun.itibar'),
    ('mulkler',       'oyun.mulkler',       'select md5(coalesce(string_agg(id||''|''||user_id||''|''||bedel, '','' order by id), '''')) from oyun.mulkler'),
    ('ulke',          'oyun.ulke',          'select md5(coalesce(string_agg(hazine||''|''||vergi||''|''||asgari, '',''), '''')) from oyun.ulke'),
    ('iller',         'oyun.il_durum',      'select md5(coalesce(string_agg(il_id||''|''||gelisim||''|''||coalesce(kasa,0), '','' order by il_id), '''')) from oyun.il_durum'),
    ('satin_alma',    'oyun.satin_almalar', 'select count(*)::text from oyun.satin_almalar'),
    ('referandum',    'oyun.referandumlar', 'select count(*)::text from oyun.referandumlar'),
    ('duzenlemeler',  'oyun.duzenlemeler',  'select md5(coalesce(string_agg(kod||''|''||deger||''|''||kaynak, '','' order by kod), '''')) from oyun.duzenlemeler'),
    ('banka',         'oyun.banka_musteri', 'select md5(coalesce(string_agg(user_id||''|''||vadesiz||''|''||kredi_notu, '','' order by user_id), '''')) from oyun.banka_musteri'),
    ('vadeli',        'oyun.vadeli',        'select md5(coalesce(string_agg(id||''|''||user_id||''|''||anapara||''|''||durum, '','' order by id), '''')) from oyun.vadeli'),
    ('krediler',      'oyun.krediler',      'select md5(coalesce(string_agg(id||''|''||user_id||''|''||kalan||''|''||durum, '','' order by id), '''')) from oyun.krediler'),
    ('teskilat',      'oyun.parti_teskilat','select count(*)::text from oyun.parti_teskilat'),
    ('moderator',     'oyun.moderatorler',  'select md5(coalesce(string_agg(user_id||''|''||array_to_string(yetkiler, '';''), '','' order by user_id), '''')) from oyun.moderatorler')
  ) x(ad, tablo, sorgu) loop
    if to_regclass(r.tablo) is null then continue; end if;
    begin
      execute r.sorgu into v;
      sonuc := sonuc || jsonb_build_object(r.ad, v);
    exception when undefined_column or undefined_table then null;   -- eski sürümde olmayan sütun: karşılaştırmaya girmez
    end;
  end loop;
  -- Basın kasaları, abonelikler ve il görevleri de sonraki güncellemelerde korunur.
  -- İlk kurulumda henüz bulunmayan tablolar eski sürümün karşılaştırmasına girmez.
  foreach yeni_tablo in array array['parti_teskilat_gorev', 'oyuncu_gazeteleri',
    'gazete_abonelik', 'gazete_yazar_teklif', 'gazete_yazarlar', 'gazete_yayinlari', 'gazete_hareket'] loop
    if to_regclass('oyun.' || yeni_tablo) is null then continue; end if;
    execute format('select md5(coalesce(string_agg(to_jsonb(x)::text, '','' order by to_jsonb(x)::text), '''')) from oyun.%I x', yeni_tablo) into v;
    sonuc := sonuc || jsonb_build_object(yeni_tablo, v);
  end loop;
  return sonuc;
end $$;

-- Yedek: oyun şemasındaki bütün tabloların anlık kopyası (ayrı şemada; internete açık değildir). Son 5 yedek tutulur.
create or replace function oyun.yedek_al(p_etiket text) returns text language plpgsql as $$
declare sema text := 'yedek_' || to_char(clock_timestamp() at time zone 'Europe/Istanbul', 'YYYYMMDD_HH24MISS_US'); t record; eski record;
begin
  execute format('create schema %I', sema);
  execute format('revoke all on schema %I from public', sema);
  execute format('comment on schema %I is %L', sema, coalesce(p_etiket, 'yedek') || ' · ' || to_char(clock_timestamp() at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'));
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind in ('r','p') loop
    execute format('create table %I.%I as table oyun.%I', sema, t.relname, t.relname);
  end loop;
  for eski in select nspname from pg_namespace where nspname like 'yedek\_%' order by nspname desc offset 5 loop
    execute format('drop schema %I cascade', eski.nspname);
  end loop;
  return sema;
end $$;

create or replace function oyun.yedekler() returns table(sema text, aciklama text) language sql stable as $$
  select n.nspname::text, obj_description(n.oid, 'pg_namespace') from pg_namespace n where n.nspname like 'yedek\_%' order by n.nspname desc
$$;

create or replace function oyun.guncelleme_basla(p_surum text, p_aciklama text default null) returns void language plpgsql as $$
declare y text; var boolean := false;
begin
  if to_regclass('oyun.profiller') is not null then
    execute 'select exists (select 1 from oyun.profiller)' into var;
  end if;
  if var then y := oyun.yedek_al('Güncelleme öncesi ' || p_surum); end if;
  insert into oyun.surumler(surum, aciklama, yedek, parmak_once) values (p_surum, p_aciklama, y, oyun.parmak_izi());
end $$;
select oyun.guncelleme_basla('2026.10.07-5', 'supabase-kurulum.sql');
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
insert into oyun.iller(id,ad,mv) values
(1,'Adana',15),
(2,'Adıyaman',5),
(3,'Afyonkarahisar',6),
(4,'Ağrı',4),
(5,'Amasya',3),
(6,'Ankara',37),
(7,'Antalya',18),
(8,'Artvin',2),
(9,'Aydın',8),
(10,'Balıkesir',9),
(11,'Bilecik',2),
(12,'Bingöl',3),
(13,'Bitlis',3),
(14,'Bolu',3),
(15,'Burdur',3),
(16,'Bursa',21),
(17,'Çanakkale',4),
(18,'Çankırı',2),
(19,'Çorum',4),
(20,'Denizli',7),
(21,'Diyarbakır',12),
(22,'Edirne',4),
(23,'Elazığ',5),
(24,'Erzincan',2),
(25,'Erzurum',5),
(26,'Eskişehir',7),
(27,'Gaziantep',14),
(28,'Giresun',4),
(29,'Gümüşhane',2),
(30,'Hakkari',3),
(31,'Hatay',10),
(32,'Isparta',4),
(33,'Mersin',13),
(34,'İstanbul',96),
(35,'İzmir',28),
(36,'Kars',3),
(37,'Kastamonu',3),
(38,'Kayseri',10),
(39,'Kırklareli',3),
(40,'Kırşehir',2),
(41,'Kocaeli',14),
(42,'Konya',15),
(43,'Kütahya',4),
(44,'Malatya',6),
(45,'Manisa',10),
(46,'Kahramanmaraş',8),
(47,'Mardin',6),
(48,'Muğla',8),
(49,'Muş',3),
(50,'Nevşehir',3),
(51,'Niğde',3),
(52,'Ordu',6),
(53,'Rize',3),
(54,'Sakarya',8),
(55,'Samsun',9),
(56,'Siirt',3),
(57,'Sinop',2),
(58,'Sivas',5),
(59,'Tekirdağ',8),
(60,'Tokat',5),
(61,'Trabzon',6),
(62,'Tunceli',2),
(63,'Şanlıurfa',15),
(64,'Uşak',3),
(65,'Van',8),
(66,'Yozgat',3),
(67,'Zonguldak',5),
(68,'Aksaray',4),
(69,'Bayburt',1),
(70,'Karaman',3),
(71,'Kırıkkale',3),
(72,'Batman',5),
(73,'Şırnak',4),
(74,'Bartın',2),
(75,'Ardahan',2),
(76,'Iğdır',2),
(77,'Yalova',3),
(78,'Karabük',2),
(79,'Kilis',2),
(80,'Osmaniye',4),
(81,'Düzce',3)
on conflict (id) do update set ad=excluded.ad, mv=excluded.mv;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 2) SEÇİM MOTORU
--  Takvim üretimi, sayım (D'Hondt + baraj), göreve başlatma, yedek vekil,
--  ve her dakika çalışan oyun.tick().
--  Tüm saatler Türkiye saatidir (Europe/Istanbul).
-- =====================================================================

-- Türkiye saatiyle belirli bir gün/saat
create or replace function oyun.tr_an(g date, saat int, dk int default 0)
returns timestamptz language sql stable as $$
  select make_timestamptz(extract(year from g)::int, extract(month from g)::int,
                          extract(day from g)::int, saat, dk, 0, 'Europe/Istanbul')
$$;

create or replace function oyun.oncelik(tur text) returns int language sql immutable as $$
  select case tur when 'mv_on' then 1 when 'cb_on' then 2 when 'bel_on' then 3 when 'kurultay' then 4
                  when 'mv' then 5 when 'bel' then 6 when 'cb' then 7 when 'cb2' then 8 else 9 end
$$;

create or replace function oyun.olay(p_tur text, p_metin text, p_il smallint default null, p_parti bigint default null, p_zaman timestamptz default null)
returns void language sql as $$
  insert into oyun.olaylar(zaman, tur, il_id, parti_id, metin)
  values (coalesce(p_zaman, oyun.simdi()), p_tur, p_il, p_parti, p_metin)
$$;

create or replace function oyun.bildir(p_user uuid, p_metin text, p_zaman timestamptz default null)
returns void language sql as $$
  insert into oyun.bildirimler(user_id, zaman, metin) values (p_user, coalesce(p_zaman, oyun.simdi()), p_metin)
$$;

-- ---------------------------------------------------------------------
-- Bir ayın tüm seçimlerini oluşturur (tekrar çağrılırsa bir şey yapmaz).
--   Ayın 6'sı   belediye aday adaylığı   · 8'i ön seçim · 10'u seçim · 11'i göreve başlama
--   15–17'si    genel başkanlık başvurusu · 18'i kurultay · 19'u göreve başlama
--   19–25'i     genel başkan CB adayı kararını verir
--   26'sı       vekil (ve gerekirse CB) aday adaylığı · 28'i ön seçimler
--   Ertesi ayın 1'i genel seçim + CB seçimi · 2'si göreve başlama (CB 2. turu gerekirse 2'si)
-- Bitiş zamanları HARİÇTİR (oy_bit 17:00 → 16:59:59'a kadar oy verilebilir).
-- ---------------------------------------------------------------------
create or replace function oyun.donem_olustur(p_ay date) returns void language plpgsql as $$
declare
  m  date := date_trunc('month', p_ay)::date;
  n  date := (date_trunc('month', p_ay) + interval '1 month')::date;
  dm text := to_char(m, 'YYYY-MM');
  dn text := to_char(n, 'YYYY-MM');
  b  timestamptz := (select baslangic from oyun.ayarlar where id = 1);
  g  int := 1;  -- gün ofseti: m + (gün-1)
begin
  -- Belediye grubu
  if oyun.tr_an(m + 5, 0) >= b then
    insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas) values
      ('bel_on', dm, oyun.tr_an(m+5,0), oyun.tr_an(m+6,0), oyun.tr_an(m+7,8), oyun.tr_an(m+7,17), oyun.tr_an(m+7,18), null),
      ('bel',    dm, null, null,                           oyun.tr_an(m+9,8), oyun.tr_an(m+9,17), oyun.tr_an(m+9,18), oyun.tr_an(m+10,0))
    on conflict (tur, donem) do nothing;
  end if;
  -- Kurultay
  if oyun.tr_an(m + 14, 0) >= b then
    insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas) values
      ('kurultay', dm, oyun.tr_an(m+14,0), oyun.tr_an(m+17,0), oyun.tr_an(m+17,8), oyun.tr_an(m+17,17), oyun.tr_an(m+17,18), oyun.tr_an(m+18,0))
    on conflict (tur, donem) do nothing;
  end if;
  -- Genel seçim grubu (ertesi ayın 1'i)
  if oyun.tr_an(m + 25, 0) >= b then
    insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas) values
      ('cb',    dn, oyun.tr_an(m+18,0), oyun.tr_an(m+25,0), oyun.tr_an(n,8),    oyun.tr_an(n,17),    oyun.tr_an(n,18),    oyun.tr_an(n+1,0)),
      ('mv_on', dn, oyun.tr_an(m+25,0), oyun.tr_an(m+26,0), oyun.tr_an(m+27,8), oyun.tr_an(m+27,17), oyun.tr_an(m+27,18), null),
      ('cb_on', dn, oyun.tr_an(m+25,0), oyun.tr_an(m+26,0), oyun.tr_an(m+27,8), oyun.tr_an(m+27,17), oyun.tr_an(m+27,18), null),
      ('mv',    dn, null, null,                             oyun.tr_an(n,8),    oyun.tr_an(n,17),    oyun.tr_an(n,18),    oyun.tr_an(n+1,0))
    on conflict (tur, donem) do nothing;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Adayların oylarını say, adaylar.oy'a yaz
-- ---------------------------------------------------------------------
create or replace function oyun.aday_oylarini_say(p_sid bigint) returns void language sql as $$
  update oyun.adaylar a set oy = coalesce(x.n, 0)
  from (select a2.id, (select count(*) from oyun.oylar o where o.secim_id = a2.secim_id and o.aday_id = a2.id) n
        from oyun.adaylar a2 where a2.secim_id = p_sid) x
  where a.id = x.id
$$;

create or replace function oyun.aday_json(p_aday_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object('aday_id', a.id, 'user_id', a.user_id, 'kad', coalesce(pr.kad, '(silinmiş)'),
                            'parti_id', a.parti_id, 'kisa', pa.kisa, 'renk', pa.renk, 'il_id', a.il_id, 'oy', coalesce(a.oy,0), 'sira', a.sira, 'vaat', a.vaat)
  from oyun.adaylar a left join oyun.profiller pr on pr.id = a.user_id left join oyun.partiler pa on pa.id = a.parti_id
  where a.id = p_aday_id
$$;

-- ---------------------------------------------------------------------
-- SONUÇLANDIRMA
-- ---------------------------------------------------------------------

-- Vekil ön seçimi: her il + parti için oy sırasına göre liste
create or replace function oyun._sonuc_mv_on(s oyun.secimler) returns jsonb language plpgsql as $$
begin
  perform oyun.aday_oylarini_say(s.id);
  update oyun.adaylar a set sira = x.rn
  from (select id, row_number() over (partition by il_id, parti_id order by oy desc, basvuru_at, id) rn
        from oyun.adaylar where secim_id = s.id) x
  where a.id = x.id;
  return jsonb_build_object(
    'katilim', (select count(*) from oyun.oylar where secim_id = s.id),
    'aday',    (select count(*) from oyun.adaylar where secim_id = s.id),
    'liste',   (select count(distinct (il_id, parti_id)) from oyun.adaylar where secim_id = s.id));
end $$;

-- Parti içi tek kazananlı ön seçimler (bel_on: il+parti başına, cb_on: parti başına)
create or replace function oyun._sonuc_tek_kazanan_on(s oyun.secimler, p_hedef_tur text) returns jsonb language plpgsql as $$
declare hedef oyun.secimler; r record; n int := 0;
begin
  perform oyun.aday_oylarini_say(s.id);
  select * into hedef from oyun.secimler where tur = p_hedef_tur and donem = s.donem;
  for r in
    select distinct on (coalesce(il_id, 0), parti_id) *
    from oyun.adaylar where secim_id = s.id
    order by coalesce(il_id, 0), parti_id, oy desc, basvuru_at, id
  loop
    -- CB: genel başkan "kendisi/başkası" dediyse ön seçim sonucu kullanılmaz
    if p_hedef_tur = 'cb' and exists (select 1 from oyun.cb_kararlar k where k.donem = s.donem and k.parti_id = r.parti_id and k.yontem <> 'onsecim') then
      continue;
    end if;
    if p_hedef_tur = 'cb' and exists (select 1 from oyun.adaylar a where a.secim_id = hedef.id and a.parti_id = r.parti_id) then
      continue;
    end if;
    insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at, vaat)
    values (hedef.id, r.user_id, r.parti_id, r.il_id, r.basvuru_at, r.vaat)
    on conflict (secim_id, user_id) do nothing;
    n := n + 1;
  end loop;
  return jsonb_build_object('katilim', (select count(*) from oyun.oylar where secim_id = s.id),
                            'aday', (select count(*) from oyun.adaylar where secim_id = s.id), 'kazanan', n);
end $$;

-- GENEL SEÇİM: ulusal baraj + her ilde D'Hondt
create or replace function oyun._sonuc_mv(s oyun.secimler) returns jsonb language plpgsql as $$
declare
  baraj   numeric := (select baraj from oyun.ayarlar where id = 1);
  onsecim oyun.secimler;
  toplam  bigint;
  il      record;
  pids    bigint[]; oys bigint[]; kaz int[]; lim int[];
  i int; k int; en int; enq numeric; q numeric;
  iller_j jsonb := '{}'::jsonb; ilj jsonb;
  bos int := 0; dolu int := 0;
begin
  select * into onsecim from oyun.secimler where tur = 'mv_on' and donem = s.donem;
  select count(*) into toplam from oyun.oylar where secim_id = s.id;

  -- ulusal oylar ve baraj (ittifak toplamı da barajı aşmaya yeter)
  create temp table if not exists _ulusal(parti_id bigint primary key, oy bigint, yuzde numeric, gecti boolean, sandalye int default 0) on commit drop;
  delete from _ulusal;
  insert into _ulusal(parti_id, oy)
    select parti_id, count(*) from oyun.oylar where secim_id = s.id group by parti_id;
  update _ulusal set yuzde = case when toplam > 0 then round(oy * 100.0 / toplam, 2) else 0 end;
  update _ulusal u set gecti = (u.yuzde >= baraj) or coalesce((
      select sum(u2.oy) * 100.0 / nullif(toplam, 0) >= baraj
      from oyun.ittifak_uyeler iu join oyun.ittifak_uyeler iu2 on iu2.ittifak_id = iu.ittifak_id
      join _ulusal u2 on u2.parti_id = iu2.parti_id
      where iu.parti_id = u.parti_id), false);

  create temp table if not exists _kaz(user_id uuid, il_id smallint, parti_id bigint) on commit drop;
  delete from _kaz;

  for il in select * from oyun.iller order by id loop
    select array_agg(x.parti_id order by x.oy desc, x.parti_id), array_agg(x.oy order by x.oy desc, x.parti_id),
           array_agg(x.lim order by x.oy desc, x.parti_id)
      into pids, oys, lim
    from (
      select o.parti_id, count(*) oy,
             (select count(*) from oyun.adaylar a where a.secim_id = onsecim.id and a.il_id = il.id and a.parti_id = o.parti_id and a.sira is not null)::int lim
      from oyun.oylar o join _ulusal u on u.parti_id = o.parti_id and u.gecti
      where o.secim_id = s.id and o.il_id = il.id
      group by o.parti_id
    ) x where x.lim > 0;

    kaz := array_fill(0, array[coalesce(array_length(pids,1),0)]);
    if pids is not null then
      for k in 1 .. il.mv loop
        en := null; enq := -1;
        for i in 1 .. array_length(pids,1) loop
          if kaz[i] < lim[i] then
            q := oys[i]::numeric / (kaz[i] + 1);
            if q > enq then enq := q; en := i; end if;   -- eşitlikte toplam oyu fazla olan (dizi sırası) kazanır
          end if;
        end loop;
        exit when en is null;
        kaz[en] := kaz[en] + 1;
      end loop;
      for i in 1 .. array_length(pids,1) loop
        if kaz[i] > 0 then
          insert into _kaz select a.user_id, il.id, pids[i] from oyun.adaylar a
            where a.secim_id = onsecim.id and a.il_id = il.id and a.parti_id = pids[i] and a.sira is not null
            order by a.sira limit kaz[i];
          update _ulusal set sandalye = sandalye + kaz[i] where parti_id = pids[i];
        end if;
      end loop;
    end if;

    select jsonb_build_object(
      'gecerli', (select count(*) from oyun.oylar where secim_id = s.id and il_id = il.id),
      'partiler', coalesce((select jsonb_object_agg(o.parti_id::text, jsonb_build_object('oy', o.n,
                     'sandalye', (select count(*) from _kaz z where z.il_id = il.id and z.parti_id = o.parti_id)))
                   from (select parti_id, count(*) n from oyun.oylar where secim_id = s.id and il_id = il.id group by parti_id) o), '{}'::jsonb),
      'secilen', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti_id', z.parti_id))
                   from _kaz z join oyun.profiller pr on pr.id = z.user_id where z.il_id = il.id), '[]'::jsonb),
      'mv', il.mv)
    into ilj;
    if (ilj->>'gecerli')::int > 0 or jsonb_array_length(ilj->'secilen') > 0 then
      iller_j := iller_j || jsonb_build_object(il.id::text, ilj);
    end if;
  end loop;

  insert into oyun.kazananlar(secim_id, user_id, il_id, parti_id)
    select s.id, user_id, il_id, parti_id from _kaz on conflict do nothing;
  select count(*) into dolu from _kaz;
  bos := 600 - dolu;

  perform oyun.olay('secim', format('Genel seçim sonuçlandı: %s oy kullanıldı, %s sandalye doldu, %s sandalye boş kaldı.', toplam, dolu, bos), null, null, s.sonuc_at);

  return jsonb_build_object(
    'toplam', toplam, 'baraj', baraj, 'dolu', dolu, 'bos', bos,
    'ulusal', coalesce((select jsonb_agg(jsonb_build_object('parti_id', u.parti_id, 'kisa', p.kisa, 'ad', p.ad, 'renk', p.renk,
                         'oy', u.oy, 'yuzde', u.yuzde, 'gecti', u.gecti, 'sandalye', u.sandalye) order by u.oy desc)
                        from _ulusal u join oyun.partiler p on p.id = u.parti_id), '[]'::jsonb),
    'iller', iller_j);
end $$;

-- Belediye ve kurultay: tek kazananlı (il başına / parti başına)
create or replace function oyun._sonuc_cok_alanli(s oyun.secimler) returns jsonb language plpgsql as $$
declare r record; liste jsonb := '[]'::jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  for r in
    select distinct on (case when s.tur = 'bel' then il_id::bigint else parti_id end) *
    from oyun.adaylar where secim_id = s.id
    order by (case when s.tur = 'bel' then il_id::bigint else parti_id end), oy desc, basvuru_at, id
  loop
    insert into oyun.kazananlar(secim_id, user_id, il_id, parti_id) values (s.id, r.user_id, r.il_id, r.parti_id)
    on conflict do nothing;
    liste := liste || oyun.aday_json(r.id);
  end loop;
  if s.tur = 'bel' then
    perform oyun.olay('secim', format('Belediye seçimleri sonuçlandı: %s ilde başkan seçildi.', jsonb_array_length(liste)), null, null, s.sonuc_at);
  else
    perform oyun.olay('secim', format('Kurultaylar sonuçlandı: %s partide genel başkan seçildi.', jsonb_array_length(liste)), null, null, s.sonuc_at);
  end if;
  return jsonb_build_object('katilim', (select count(*) from oyun.oylar where secim_id = s.id),
                            'kazananlar', liste,
                            'adaylar', coalesce((select jsonb_agg(oyun.aday_json(a.id) order by a.il_id, a.parti_id, a.oy desc) from oyun.adaylar a where a.secim_id = s.id), '[]'::jsonb));
end $$;

-- Cumhurbaşkanlığı 1. tur: %50'yi geçen kazanır, yoksa ilk iki aday 2. tura
create or replace function oyun._sonuc_cb(s oyun.secimler) returns jsonb language plpgsql as $$
declare
  toplam bigint; n int; birinci record; ikinci record; t2 oyun.secimler;
  gun date := (s.oy_bas at time zone 'Europe/Istanbul')::date;
  adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  select count(*) into toplam from oyun.oylar where secim_id = s.id;
  select count(*) into n from oyun.adaylar where secim_id = s.id;
  select coalesce(jsonb_agg(oyun.aday_json(a.id) order by a.oy desc, a.basvuru_at), '[]'::jsonb) into adaylar_j
    from oyun.adaylar a where a.secim_id = s.id;
  if n = 0 then
    perform oyun.olay('secim', 'Cumhurbaşkanlığı seçiminde aday yoktu; makam boş kalacak.', null, null, s.sonuc_at);
    return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'ikinci_tur', false);
  end if;
  select * into birinci from oyun.adaylar where secim_id = s.id order by oy desc, basvuru_at, id limit 1;
  if n = 1 or (toplam > 0 and birinci.oy * 2 > toplam) then
    insert into oyun.kazananlar values (s.id, birinci.user_id, null, birinci.parti_id) on conflict do nothing;
    perform oyun.olay('secim', format('Cumhurbaşkanı ilk turda seçildi: %s (%%%s).',
      (select kad from oyun.profiller where id = birinci.user_id),
      case when toplam > 0 then round(birinci.oy * 100.0 / toplam, 1) else 100 end), null, birinci.parti_id, s.sonuc_at);
    return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'ikinci_tur', false,
                              'kazanan', oyun.aday_json(birinci.id));
  end if;
  -- 2. tur: ertesi gün 08:00-17:00, göreve başlama bir sonraki gün 00:00
  select * into ikinci from oyun.adaylar where secim_id = s.id and id <> birinci.id order by oy desc, basvuru_at, id limit 1;
  insert into oyun.secimler(tur, donem, oy_bas, oy_bit, sonuc_at, goreve_bas)
  values ('cb2', s.donem, oyun.tr_an(gun+1,8), oyun.tr_an(gun+1,17), oyun.tr_an(gun+1,18), oyun.tr_an(gun+2,0))
  on conflict (tur, donem) do nothing
  returning * into t2;
  if t2.id is not null then
    insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at, vaat) values
      (t2.id, birinci.user_id, birinci.parti_id, null, birinci.basvuru_at, birinci.vaat),
      (t2.id, ikinci.user_id,  ikinci.parti_id,  null, ikinci.basvuru_at, ikinci.vaat);
  end if;
  perform oyun.olay('secim', format('Cumhurbaşkanlığı seçimi ikinci tura kaldı: %s ve %s yarın sandıkta.',
    (select kad from oyun.profiller where id = birinci.user_id), (select kad from oyun.profiller where id = ikinci.user_id)), null, null, s.sonuc_at);
  return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'ikinci_tur', true);
end $$;

-- Cumhurbaşkanlığı 2. tur: çok oy alan kazanır; eşitlikte 1. turda önde olan
create or replace function oyun._sonuc_cb2(s oyun.secimler) returns jsonb language plpgsql as $$
declare k record; ilk bigint; toplam bigint; adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  select id into ilk from oyun.secimler where tur = 'cb' and donem = s.donem;
  select count(*) into toplam from oyun.oylar where secim_id = s.id;
  select a.* into k from oyun.adaylar a
    left join oyun.adaylar a1 on a1.secim_id = ilk and a1.user_id = a.user_id
    where a.secim_id = s.id order by a.oy desc, a1.oy desc nulls last, a.basvuru_at limit 1;
  select coalesce(jsonb_agg(oyun.aday_json(a.id) order by a.oy desc), '[]'::jsonb) into adaylar_j from oyun.adaylar a where a.secim_id = s.id;
  if k.id is not null then
    insert into oyun.kazananlar values (s.id, k.user_id, null, k.parti_id) on conflict do nothing;
    perform oyun.olay('secim', format('Cumhurbaşkanı ikinci turda seçildi: %s.', (select kad from oyun.profiller where id = k.user_id)), null, k.parti_id, s.sonuc_at);
  end if;
  return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'kazanan', case when k.id is null then null else oyun.aday_json(k.id) end);
end $$;

create or replace function oyun.sonuclandir(p_sid bigint) returns void language plpgsql as $$
declare s oyun.secimler; j jsonb;
begin
  select * into s from oyun.secimler where id = p_sid for update;
  if s.durum <> 'bekliyor' then return; end if;
  j := case s.tur
    when 'mv_on'    then oyun._sonuc_mv_on(s)
    when 'bel_on'   then oyun._sonuc_tek_kazanan_on(s, 'bel')
    when 'cb_on'    then oyun._sonuc_tek_kazanan_on(s, 'cb')
    when 'mv'       then oyun._sonuc_mv(s)
    when 'bel'      then oyun._sonuc_cok_alanli(s)
    when 'kurultay' then oyun._sonuc_cok_alanli(s)
    when 'cb'       then oyun._sonuc_cb(s)
    when 'cb2'      then oyun._sonuc_cb2(s)
  end;
  update oyun.secimler set sonuc = j, durum = case when goreve_bas is null then 'tamam' else 'sonuclandi' end
  where id = p_sid;
end $$;

-- ---------------------------------------------------------------------
-- MAKAMLAR
-- ---------------------------------------------------------------------

-- Boşalan vekilliğe, aynı partinin o ildeki listesinden sıradaki aday gelir
create or replace function oyun.yedek_getir(p_mv_secim bigint, p_il smallint, p_parti bigint, p_zaman timestamptz)
returns void language plpgsql as $$
declare onsecim bigint; y record;
begin
  select o.id into onsecim from oyun.secimler o join oyun.secimler m on m.donem = o.donem and m.tur = 'mv'
    where o.tur = 'mv_on' and m.id = p_mv_secim;
  select a.* into y from oyun.adaylar a
    join oyun.profiller pr on pr.id = a.user_id and pr.parti_id = p_parti
    where a.secim_id = onsecim and a.il_id = p_il and a.parti_id = p_parti and a.sira is not null
      and not exists (select 1 from oyun.makamlar m where m.user_id = a.user_id and m.bit is null)
      and not exists (select 1 from oyun.partiler pg where pg.gb = a.user_id)
      and not exists (select 1 from oyun.makamlar m where m.user_id = a.user_id and m.secim_id = p_mv_secim and m.tur = 'mv')
    order by a.sira limit 1;
  if y.id is not null then
    insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, kaynak, bas)
    values ('mv', y.user_id, p_il, p_parti, p_mv_secim, 'yedek', p_zaman);
    perform oyun.bildir(y.user_id, format('Boşalan bir sandalye nedeniyle %s milletvekili olarak Meclis''e girdin.', (select ad from oyun.iller where id = p_il)), p_zaman);
    perform oyun.olay('makam', format('%s, %s listesinden yedek olarak Meclis''e girdi.', (select kad from oyun.profiller where id = y.user_id),
                      (select ad from oyun.iller where id = p_il)), p_il, p_parti, p_zaman);
  else
    perform oyun.olay('makam', format('%s ilinde bir sandalye boş kaldı: listede yedek kalmadı.', (select ad from oyun.iller where id = p_il)), p_il, p_parti, p_zaman);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- TEK GÖREV KURALI: kimse aynı anda iki görev taşıyamaz. İstisnalar:
--   • milletvekili + genel başkan yardımcısı
--   • genel başkan + cumhurbaşkanı (genel başkan kendini aday gösterip kazanırsa)
-- Görevler: mv, bel, cb, bakan (makamlar tablosu), gb (partiler.gb), gby (parti_gby)
-- ---------------------------------------------------------------------
create or replace function oyun.roller(p_user uuid) returns text[] language sql stable as $$
  select coalesce(array_agg(r), '{}'::text[]) from (
    select tur as r from oyun.makamlar where user_id = p_user and bit is null
    union all select 'gb' from oyun.partiler where gb = p_user
    union all select 'gby' from oyun.parti_gby where user_id = p_user) x
$$;

create or replace function oyun.rol_uyumlu(a text, b text) returns boolean language sql immutable as $$
  select (a = b and a in ('gb','gby')) or (a, b) in (('mv','gby'),('gby','mv'),('gb','cb'),('cb','gb'))
$$;

create or replace function oyun.rol_ad(r text) returns text language sql immutable as $$
  select case r when 'mv' then 'milletvekilliği' when 'bel' then 'belediye başkanlığı' when 'cb' then 'cumhurbaşkanlığı'
                when 'bakan' then 'bakanlık' when 'gb' then 'genel başkanlık' when 'gby' then 'genel başkan yardımcılığı' else r end
$$;

-- p_yeni görevi alınırsa, kişinin elindeki hangi görevle çakışır? (yoksa null)
create or replace function oyun.rol_cakisma(p_user uuid, p_yeni text) returns text language sql stable as $$
  select oyun.rol_ad(r) from unnest(oyun.roller(p_user)) r where not oyun.rol_uyumlu(r, p_yeni) limit 1
$$;

create or replace function oyun.makam_ad(p_tur text, p_il smallint, p_bakanlik text) returns text language sql stable as $$
  select case p_tur when 'mv' then (select ad from oyun.iller where id = p_il) || ' milletvekilliği'
                    when 'bel' then (select ad from oyun.iller where id = p_il) || ' belediye başkanlığı'
                    when 'cb' then 'cumhurbaşkanlığı'
                    else coalesce((select ad from oyun.bakanliklar where kod = p_bakanlik), 'bakanlık') end
$$;

create or replace function oyun.makam_bitir(p_id bigint, p_zaman timestamptz, p_neden text) returns void language plpgsql as $$
declare m oyun.makamlar;
begin
  update oyun.makamlar set bit = p_zaman, bitis_neden = p_neden where id = p_id and bit is null returning * into m;
  if m.id is not null and p_neden in ('yeni_gorev','gorevden_alindi','kabine_yenilendi') then
    perform oyun.bildir(m.user_id, case p_neden
      when 'yeni_gorev' then format('Yeni görevine başladığın için %s görevin sona erdi.', oyun.makam_ad(m.tur, m.il_id, m.bakanlik))
      when 'gorevden_alindi' then format('Cumhurbaşkanı seni %s görevinden aldı.', oyun.makam_ad(m.tur, m.il_id, m.bakanlik))
      else format('Yeni cumhurbaşkanı göreve başladığı için %s görevin sona erdi.', oyun.makam_ad(m.tur, m.il_id, m.bakanlik)) end, p_zaman);
  end if;
  if m.id is not null and m.tur = 'mv' and p_neden <> 'donem_bitti' then
    perform oyun.yedek_getir(m.secim_id, m.il_id, m.parti_id, p_zaman);
  end if;
end $$;

create or replace function oyun.goreve_baslat(p_sid bigint) returns void language plpgsql as $$
declare s oyun.secimler; k record; m record; t timestamptz; ilk oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_sid for update;
  if s.durum <> 'sonuclandi' then return; end if;
  t := s.goreve_bas;

  if s.tur = 'kurultay' then
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id and parti_id = k.parti_id);
      if (select gb from oyun.partiler where id = k.parti_id) is distinct from k.user_id then
        delete from oyun.parti_gby where parti_id = k.parti_id;   -- yeni genel başkan kendi ekibini kurar
      end if;
      delete from oyun.parti_gby where user_id = k.user_id;       -- genel başkan aynı zamanda yardımcı olamaz
      -- tek görev kuralı: milletvekili, belediye başkanı, bakan görevleri düşer (cumhurbaşkanlığı kalabilir)
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null and tur <> 'cb' loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      update oyun.partiler set gb = k.user_id where id = k.parti_id;
      perform oyun.bildir(k.user_id, format('Kurultayı kazandın: %s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilirsin.', (select ad from oyun.partiler where id = k.parti_id)), t);
    end loop;
    -- BOŞ MAKAM KURALI: kurultayda kimse aday olmadığı için genel başkansız kalan parti kıdemli üyesini genel başkan yapar
    perform oyun.gb_halef(t);
  elsif s.tur = 'cb' and coalesce((s.sonuc->>'ikinci_tur')::boolean, false) then
    null; -- 2. tur bekleniyor: görevdeki cumhurbaşkanı 2. tur sonucuna kadar devam eder
  else
    -- Milletvekilleri liste usulüyle seçilir: eski Meclis topluca biter. (Boş kalan sandalyeleri yedek listeler doldurur.)
    if s.tur = 'mv' then
      for m in select id from oyun.makamlar where tur = 'mv' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'donem_bitti');
      end loop;
    end if;
    -- BOŞ MAKAM KURALI: belediye başkanlığı ve cumhurbaşkanlığında eski görevli ancak yerine yenisi gerçekten başlayınca düşer.
    -- Seçimde aday çıkmadıysa (ya da kazanan göreve başlayamadıysa) görevdeki, yeni biri seçilene kadar görevine devam eder.
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id);   -- hesap silinmiş
      -- Genel başkan vekil/belediye başkanı olamaz (adaylığı zaten engellenir; yine de güvenceye al)
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) in ('mv','bel')
         and exists (select 1 from oyun.partiler where gb = k.user_id) then
        perform oyun.bildir(k.user_id, 'Genel başkan olduğun için seçildiğin bu görevi üstlenemezsin.', t);
        if s.tur = 'mv' then perform oyun.yedek_getir(s.id, k.il_id, k.parti_id, t); end if;
        continue;
      end if;
      -- Yerine geçilen görevli (aynı ilin belediye başkanı / cumhurbaşkanı) görevi devreder
      if s.tur = 'bel' then
        for m in select id from oyun.makamlar where tur = 'bel' and il_id = k.il_id and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      elsif s.tur in ('cb','cb2') then
        for m in select id from oyun.makamlar where tur = 'cb' and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      end if;
      -- Tek görev kuralı: kişinin elindeki diğer görev düşer (milletvekili + genel başkan yardımcısı ve genel başkan + cumhurbaşkanı hariç)
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) in ('bel','cb') then
        delete from oyun.parti_gby where user_id = k.user_id;
      end if;
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, bas)
      values (case when s.tur = 'cb2' then 'cb' else s.tur end, k.user_id, k.il_id, k.parti_id, s.id, t);
      perform oyun.bildir(k.user_id, case when s.tur in ('cb','cb2') then 'Cumhurbaşkanı olarak göreve başladın. Kabineni kurmak için 12 bakanı atayabilirsin.'
        else format('%s olarak göreve başladın.', case s.tur when 'mv' then (select ad from oyun.iller where id = k.il_id) || ' Milletvekili'
                                                         else (select ad from oyun.iller where id = k.il_id) || ' Belediye Başkanı' end) end, t);
    end loop;
    -- Seçimde kimse kazanamadıysa görevde kalanlara haber ver
    if s.tur in ('cb','cb2') and not exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select user_id from oyun.makamlar where tur = 'cb' and bit is null loop
        perform oyun.bildir(m.user_id, 'Cumhurbaşkanlığı seçiminde yeni bir başkan çıkmadı; yeni cumhurbaşkanı seçilene kadar görevine devam ediyorsun.', t);
      end loop;
    end if;
    -- Yeni Meclis göreve başlayınca sonuçlanmamış kanun teklifleri kadük olur
    if s.tur = 'mv' then perform oyun.kanunlar_kaduk(t); end if;
    -- Yeni bir cumhurbaşkanlığı dönemi gerçekten başlayınca kabine yenilenir; seçimde kimse kazanamadıysa kabine yerinde kalır
    if s.tur in ('cb','cb2') and exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select id from oyun.makamlar where tur = 'bakan' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'kabine_yenilendi');
      end loop;
    end if;
  end if;
  update oyun.secimler set durum = 'tamam' where id = s.id;
end $$;

-- ---------------------------------------------------------------------
-- TICK: her dakika çalışır. Takvimi üretir, saati gelen sayım ve
-- göreve başlamaları sırayla işler. Kaçırılan dakikaları da telafi eder.
-- ---------------------------------------------------------------------
create or replace function oyun.tick() returns int language plpgsql as $$
declare t timestamptz := oyun.simdi(); ay date; r record; n int := 0;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay := date_trunc('month', t at time zone 'Europe/Istanbul')::date;
  perform oyun.donem_olustur(ay);
  perform oyun.donem_olustur((ay + interval '1 month')::date);
  -- Günde bir kez: 30 günden eski sohbet/propaganda, 60 günden eski bildirim, 90 günden eski özel mesaj silinir
  if (select son_temizlik from oyun.ayarlar where id = 1) is distinct from (t at time zone 'Europe/Istanbul')::date then
    delete from oyun.mesajlar where zaman < t - interval '30 days';
    delete from oyun.yayinlar where zaman < t - interval '30 days';
    delete from oyun.bildirimler where zaman < t - interval '60 days';
    delete from oyun.ozel where zaman < t - interval '90 days';
    delete from oyun.push_kuyruk where olusturma < now() - interval '7 days';
    update oyun.ayarlar set son_temizlik = (t at time zone 'Europe/Istanbul')::date where id = 1;
  end if;
  loop
    select * into r from (
      select id, sonuc_at as zaman, 0 as asama, oyun.oncelik(tur) o from oyun.secimler where durum = 'bekliyor' and sonuc_at <= t
      union all
      select id, goreve_bas, 1, oyun.oncelik(tur) from oyun.secimler where durum = 'sonuclandi' and goreve_bas <= t
    ) x order by zaman, asama, o limit 1;
    exit when not found;
    if r.asama = 0 then perform oyun.sonuclandir(r.id); else perform oyun.goreve_baslat(r.id); end if;
    n := n + 1;
    exit when n > 200;
  end loop;
  perform oyun.kanun_tick(t);
  perform oyun.mevzuat_tick(t);
  perform oyun.meclis_tick(t);
  perform oyun.guvenlik_tick(t);
  perform oyun.gunluk_ekonomi(t);
  perform oyun.banka_tick(t);
  perform oyun.push_hatirlatmalar(t);
  perform oyun.push_tetikle();
  return n;
end $$;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 3) UYGULAMA FONKSİYONLARI (RPC)
--  Uygulama yalnızca buradaki public.* fonksiyonlarını çağırabilir.
--  Hepsi giriş yapmış oyuncunun kimliğiyle (auth.uid()) çalışır.
-- =====================================================================

-- ---------- yardımcılar (oyun şeması, dışarı kapalı) ----------
create or replace function oyun.ben() returns uuid language plpgsql stable as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Giriş yapmalısın.'; end if;
  return u;
end $$;

create or replace function oyun.profilim() returns oyun.profiller language plpgsql stable as $$
declare p oyun.profiller;
begin
  select * into p from oyun.profiller where id = oyun.ben();
  if p.id is null then raise exception 'Önce profilini oluştur (kullanıcı adı ve il).'; end if;
  if p.yasakli then raise exception 'Hesabın kural ihlali nedeniyle kapatıldı. İtiraz için oyun yönetimine e-posta gönderebilirsin.'; end if;
  return p;
end $$;

create or replace function oyun.sade(t text) returns text language sql immutable as $$
  select regexp_replace(lower(translate(coalesce(t,''), 'ÇĞİIÖŞÜÂÎÛçğıöşüâîû', 'cgiiosuaiucgiosuaiu')), '[^a-z0-9]', '', 'g')
$$;

-- Gerçek partilere ait adlar ve kaba sözler engellenir
create or replace function oyun.yasakli_ad(t text) returns boolean language sql immutable as $$
  select exists (select 1 from unnest(array[
    'akparti','adaletvekalkinma','cumhuriyethalk','milliyetciharek','demparti','halklarinesitlik','halklarindemokratik',
    'iyiparti','yenidenrefah','zaferpartisi','saadetpartisi','devapartisi','demokrasiveatilim','gelecekpartisi',
    'turkiyeiscipartisi','memleketpartisi','buyukbirlik','demokratparti','vatanpartisi','anahtarparti','emekpartisi',
    'komunistparti','dogruyol','anavatan','refahpartisi','faziletpartisi','demokratiksol','hurdavapartisi',
    'orospu','yarrak','pezevenk','kahpe','amcik','surtuk','serefsiz','yavsak','ibne','gavat','siktir','amina'
  ]) y where oyun.sade(t) like '%' || y || '%')
$$;

create or replace function oyun.yasakli_kisa(t text) returns boolean language sql immutable as $$
  select upper(translate(t, 'çğıöşüi', 'ÇĞIÖŞÜİ')) = any (array['AKP','AK','CHP','MHP','DEM','HDP','İYİ','IYI','YRP','ZP','SP','TİP','TIP',
    'BBP','DP','DSP','EMEP','DEVA','HEDEP','TKP','ANAP','DYP','RP','MP','GP','BTP','HÜDA PAR','HÜDAPAR','HYP','SOL','YSK','TBMM'])
$$;

create or replace function oyun.yasakli_kad(t text) returns boolean language sql immutable as $$
  select oyun.yasakli_ad(t) or oyun.sade(t) in ('admin','yonetici','sistem','ysk','moderator','destek','tbmm','cumhurbaskani')
$$;

create or replace function oyun.uyari(p oyun.profiller, ref timestamptz) returns text language sql stable as $$
  select case when p.olusturma > ref - make_interval(days => (select min_hesap_gun from oyun.ayarlar where id = 1))
    then format('Hesabın en az %s günlük olmalı.', (select min_hesap_gun from oyun.ayarlar where id = 1)) end
$$;

-- İl değiştirmenin kapalı olduğu dönemler: aday adaylığı başvurusundan göreve başlamaya kadar
create or replace function oyun.il_kilit_nedeni(t timestamptz) returns text language sql stable as $$
  select case s.tur when 'mv_on' then 'Genel seçim dönemi (26''sından ayın 2''sine kadar) il değiştirilemez.'
                    else 'Belediye seçim dönemi (6''sından 11''ine kadar) il değiştirilemez.' end
  from oyun.secimler s join oyun.secimler g on g.donem = s.donem and g.tur = case s.tur when 'mv_on' then 'mv' else 'bel' end
  where s.tur in ('mv_on','bel_on') and t >= s.basvuru_bas and t < g.goreve_bas
  limit 1
$$;

create or replace function oyun.parti_json(p_id bigint) returns jsonb language sql stable as $$
  select case when p.id is null then null else jsonb_build_object('id', p.id, 'ad', p.ad, 'kisa', p.kisa, 'renk', p.renk, 'amblem', p.amblem) end
  from (select 1) d left join oyun.partiler p on p.id = p_id
$$;

create or replace function oyun.kad(u uuid) returns text language sql stable as $$
  select kad from oyun.profiller where id = u
$$;

create or replace function oyun.asama(s oyun.secimler, t timestamptz) returns text language sql stable as $$
  select case
    when s.durum <> 'bekliyor' then 'bitti'
    when s.basvuru_bas is not null and t >= s.basvuru_bas and t < s.basvuru_bit then 'basvuru'
    when t >= s.oy_bas and t < s.oy_bit then 'oy'
    when t >= s.oy_bit then 'sayim'
    else 'yakinda' end
$$;

-- Bu oyuncu bu seçimde oy kullanabilir mi? (null = evet, aksi halde neden)
create or replace function oyun.oy_engeli(p oyun.profiller, s oyun.secimler) returns text language sql stable as $$
  select coalesce(
    oyun.uyari(p, s.oy_bas),
    case when s.tur in ('mv_on','bel_on','kurultay','cb_on') then
      case when p.parti_id is null then 'Bu parti içi seçimde oy için bir partiye üye olmalısın.'
           when p.parti_at > s.basvuru_bas then 'Parti içi seçimde oy için başvurular açılmadan önce üye olmuş olmalısın.' end
    end)
$$;

-- ---------- PROFİL ----------
create or replace function public.profil_olustur(p_kad text, p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben();
begin
  if exists (select 1 from oyun.profiller where id = u) then raise exception 'Profilin zaten var.'; end if;
  p_kad := btrim(p_kad);
  if p_kad !~ '^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$' then
    raise exception 'Kullanıcı adı 3-20 karakter olmalı; yalnızca harf, rakam ve _ kullanılabilir.';
  end if;
  if oyun.yasakli_kad(p_kad) then raise exception 'Bu kullanıcı adı kullanılamaz.'; end if;
  if exists (select 1 from oyun.profiller where lower(kad) = lower(p_kad)) then raise exception 'Bu kullanıcı adı alınmış.'; end if;
  if not exists (select 1 from oyun.iller where id = p_il) then raise exception 'Geçersiz il.'; end if;
  insert into oyun.profiller(id, kad, il_id, il_at, olusturma) values (u, p_kad, p_il, oyun.simdi(), oyun.simdi());
  return public.durum();
end $$;

create or replace function public.il_degistir(p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); gun int := oyun.il_bekleme_gun(t); kn text; ucret numeric;
begin
  if not exists (select 1 from oyun.iller where id = p_il) then raise exception 'Geçersiz il.'; end if;
  if p.il_id = p_il then raise exception 'Zaten bu ildesin.'; end if;
  kn := oyun.il_kilit_nedeni(t);
  if kn is not null then raise exception '%', kn; end if;
  if p.son_il_degis is not null and p.son_il_degis + make_interval(days => gun) > t then
    raise exception 'İl en fazla % günde bir değiştirilebilir. Bir sonraki: %', gun,
      to_char((p.son_il_degis + make_interval(days => gun)) at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI');
  end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('mv','bel')) then
    raise exception 'Görevdeki vekil veya belediye başkanı il değiştiremez.';
  end if;
  -- taşınma ücreti (ulaşım ve harç indirimleri düşer)
  ucret := oyun.tasinma_ucreti(p.il_id, p_il::smallint, t);
  if ucret > 0 then
    perform oyun.para_islem(p.id, -ucret, 'tasinma', format('Taşınma: %s → %s', (select ad from oyun.iller where id = p.il_id), (select ad from oyun.iller where id = p_il)), t);
  end if;
  update oyun.profiller set il_id = p_il, il_at = t, son_il_degis = t where id = p.id;
  return public.durum();
end $$;

-- ---------- PARTİ ----------
create or replace function oyun._ayril(u uuid, t timestamptz) returns void language plpgsql as $$
declare pid bigint := (select parti_id from oyun.profiller where id = u);
begin
  if pid is null then return; end if;
  -- Sonuçlanmamış seçimlerdeki adaylıklar düşer (vekil listesi genel seçim bitene kadar bağlıdır)
  delete from oyun.adaylar a using oyun.secimler s
   where a.secim_id = s.id and a.user_id = u
     and (s.durum = 'bekliyor'
          or (s.tur = 'mv_on' and exists (select 1 from oyun.secimler m where m.tur = 'mv' and m.donem = s.donem and m.durum = 'bekliyor')));
  delete from oyun.cb_kararlar k where k.parti_id = pid and k.aday = u
     and exists (select 1 from oyun.secimler s where s.tur = 'cb' and s.donem = k.donem and s.durum = 'bekliyor');
  update oyun.partiler set gb = null where id = pid and gb = u;
  delete from oyun.parti_gby where user_id = u;
  update oyun.profiller set parti_id = null, parti_at = null where id = u;
  update oyun.partiler set kapali = true
   where id = pid and not sistem and not exists (select 1 from oyun.profiller where parti_id = pid);
  perform oyun.ittifak_temizle();
end $$;

-- Kuruluş aşamasındaki parti: kurucu üye sayısı tamamlanana kadar dolu (14_guvenlik)
alter table oyun.partiler add column if not exists kurulus_bit timestamptz;

create or replace function public.parti_kur(p_ad text, p_kisa text, p_renk text, p_amblem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); gun int := (select parti_kur_gun from oyun.ayarlar where id = 1); yeni bigint; ucret numeric;
begin
  p_ad := btrim(regexp_replace(p_ad, '\s+', ' ', 'g')); p_kisa := upper(btrim(p_kisa));
  if length(p_ad) < 5 or length(p_ad) > 40 then raise exception 'Parti adı 5-40 karakter olmalı.'; end if;
  if p_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then raise exception 'Parti adında yalnızca harf kullanılabilir.'; end if;
  if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' then raise exception 'Kısa ad 2-6 büyük harf olmalı.'; end if;
  if p_renk !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Geçersiz renk.'; end if;
  if p_amblem !~ '^[a-z_]{2,20}$' then raise exception 'Geçersiz amblem.'; end if;
  if oyun.yasakli_ad(p_ad) or oyun.yasakli_kisa(p_kisa) then
    raise exception 'Gerçek bir partiyi çağrıştıran veya uygunsuz adlar kullanılamaz.';
  end if;
  if exists (select 1 from oyun.partiler where not kapali and lower(ad) = lower(p_ad)) then raise exception 'Bu adla bir parti zaten var.'; end if;
  if exists (select 1 from oyun.partiler where not kapali and lower(kisa) = lower(p_kisa)) then raise exception 'Bu kısa ad kullanılıyor.'; end if;
  if oyun.uyari(p, t) is not null then raise exception 'Parti kurmak için: %', oyun.uyari(p, t); end if;
  if oyun.kidem_puani(p.id) < (select parti_kurucu_kidem from oyun.ayarlar where id = 1) then
    raise exception 'Parti kurabilmek için en az % kıdem puanın olmalı (şu an %). Her gün maaşını topla, seçimlerde oy kullan.',
      (select parti_kurucu_kidem from oyun.ayarlar where id = 1), oyun.kidem_puani(p.id);
  end if;
  if p.son_parti_kur is not null and p.son_parti_kur + make_interval(days => gun) > t then
    raise exception 'En fazla % günde bir parti kurabilirsin.', gun;
  end if;
  -- kuruluş harcı ve genel merkez binası (15_ekonomi3); para yetmezse parti kurulmaz
  ucret := oyun.parti_kur_harci(p, p_ad, t);
  perform oyun._ayril(p.id, t);
  insert into oyun.partiler(ad, kisa, renk, amblem, gb, kurucu, kurulus, kurulus_bit)
  values (p_ad, p_kisa, lower(p_renk), p_amblem, p.id, p.id, t, t + make_interval(days => (select parti_kurulus_gun from oyun.ayarlar where id = 1)))
  returning id into yeni;
  perform oyun.genel_merkez_ac(yeni, p, ucret, t);
  update oyun.profiller set parti_id = yeni, parti_at = t, son_parti_kur = t where id = p.id;
  perform oyun.olay('parti', format('%s, %s (%s) adıyla yeni bir parti kurmak için kuruluş dilekçesi verdi. Kurucu üyeler aranıyor.', p.kad, p_ad, p_kisa), p.il_id, yeni, t);
  perform oyun.parti_kurulus_kontrol(yeni, t);
  return public.durum();
end $$;

create or replace function public.partiye_katil(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not exists (select 1 from oyun.partiler where id = p_parti and not kapali) then raise exception 'Parti bulunamadı.'; end if;
  if p.parti_id = p_parti then raise exception 'Zaten bu partinin üyesisin.'; end if;
  perform oyun._ayril(p.id, t);
  update oyun.profiller set parti_id = p_parti, parti_at = t where id = p.id;
  return public.durum();
end $$;

create or replace function public.partiden_ayril() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  if p.parti_id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  perform oyun._ayril(p.id, oyun.simdi());
  return public.durum();
end $$;

-- Genel başkan 6 yardımcısını atar (p_kad boş = o sırayı boşalt)
create or replace function public.gby_ata(p_sira int, p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); hedef oyun.profiller; pa oyun.partiler; eski uuid;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then raise exception 'Yalnızca genel başkan yardımcı atayabilir.'; end if;
  if p_sira not between 1 and 6 then raise exception 'Geçersiz sıra (1-6).'; end if;
  select user_id into eski from oyun.parti_gby where parti_id = pa.id and sira = p_sira;
  if coalesce(btrim(p_kad), '') = '' then
    delete from oyun.parti_gby where parti_id = pa.id and sira = p_sira;
    if eski is not null then perform oyun.bildir(eski, format('%s genel başkan yardımcılığı görevin sona erdi.', pa.kisa)); end if;
    return public.durum();
  end if;
  select * into hedef from oyun.profiller where lower(kad) = lower(btrim(p_kad));
  if hedef.id is null or hedef.parti_id is distinct from pa.id then raise exception 'Bu kişi partinin üyesi değil.'; end if;
  if hedef.id = p.id then raise exception 'Kendini yardımcı atayamazsın.'; end if;
  if oyun.rol_cakisma(hedef.id, 'gby') is not null then
    raise exception '% şu anda % görevinde; genel başkan yardımcısı yalnızca milletvekili olabilir.', hedef.kad, oyun.rol_cakisma(hedef.id, 'gby');
  end if;
  if eski = hedef.id then return public.durum(); end if;
  delete from oyun.parti_gby where parti_id = pa.id and (sira = p_sira or user_id = hedef.id);
  insert into oyun.parti_gby(parti_id, sira, user_id, atama) values (pa.id, p_sira, hedef.id, oyun.simdi());
  if eski is not null then perform oyun.bildir(eski, format('%s genel başkan yardımcılığı görevin sona erdi.', pa.kisa)); end if;
  perform oyun.bildir(hedef.id, format('%s Genel Başkanı seni genel başkan yardımcısı olarak atadı.', pa.kisa));
  perform oyun.olay('parti', format('%s, %s genel başkan yardımcılığına atandı.', hedef.kad, pa.kisa), null, pa.id);
  return public.durum();
end $$;

-- Genel başkan cumhurbaşkanı adayı yöntemini seçer (ayın 19-25'i):
--   kendisi | baskasi (p_kad) | onsecim (26'sında başvuru, 28'inde üyeler seçer)
create or replace function public.cb_aday_belirle(p_yontem text, p_kad text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; pa oyun.partiler; hedef oyun.profiller;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then raise exception 'Bu kararı yalnızca genel başkan verebilir.'; end if;
  select * into s from oyun.secimler where tur = 'cb' and t >= basvuru_bas and t < basvuru_bit;
  if s.id is null then raise exception 'Cumhurbaşkanı adayı kararı ayın 19''u ile 25''i arasında verilir.'; end if;
  if p_yontem not in ('kendisi','baskasi','onsecim') then raise exception 'Geçersiz yöntem.'; end if;
  if p_yontem = 'kendisi' then hedef := p;
  elsif p_yontem = 'baskasi' then
    select * into hedef from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad,'')));
    if hedef.id is null or hedef.parti_id is distinct from pa.id then raise exception 'Aday partinin üyesi olmalı.'; end if;
  end if;
  if hedef.id is not null and oyun.uyari(hedef, t) is not null then raise exception 'Aday için: %', oyun.uyari(hedef, t); end if;
  insert into oyun.cb_kararlar(donem, parti_id, yontem, aday, zaman) values (s.donem, pa.id, p_yontem, hedef.id, t)
  on conflict (donem, parti_id) do update set yontem = excluded.yontem, aday = excluded.aday, destek_parti = null, zaman = excluded.zaman;
  delete from oyun.adaylar where secim_id = s.id and parti_id = pa.id;
  if hedef.id is not null then
    insert into oyun.adaylar(secim_id, user_id, parti_id, basvuru_at) values (s.id, hedef.id, pa.id, t);
  end if;
  return public.durum();
end $$;

-- ---------- ADAYLIK ----------
-- p_tur: mv_on (vekil), bel_on (belediye), kurultay (genel başkan), cb_on (parti CB ön seçimi)
create or replace function public.aday_ol(p_tur text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; k oyun.cb_kararlar;
begin
  if p_tur not in ('mv_on','bel_on','kurultay','cb_on') then raise exception 'Geçersiz adaylık türü.'; end if;
  select * into s from oyun.secimler where tur = p_tur and t >= basvuru_bas and t < basvuru_bit;
  if s.id is null then raise exception 'Bu adaylık için başvuru şu anda açık değil.'; end if;
  if p.parti_id is null then raise exception 'Aday olmak için bir partiye üye olmalısın.'; end if;
  if p.parti_at > s.basvuru_bas then raise exception 'Bu dönem aday olabilmek için başvurular açılmadan önce partiye üye olmalıydın.'; end if;
  if oyun.uyari(p, t) is not null then raise exception '%', oyun.uyari(p, t); end if;
  if (select kurulus_bit from oyun.partiler where id = p.parti_id) is not null then
    raise exception 'Partin henüz kuruluş aşamasında: kurucu üye sayısı tamamlanmadan seçime katılamaz.';
  end if;
  if p_tur in ('mv_on','bel_on') and exists (select 1 from oyun.partiler where gb = p.id) then
    raise exception 'Genel başkan milletvekili ya da belediye başkanı adayı olamaz. Genel başkan yalnızca cumhurbaşkanı adayı olabilir.';
  end if;
  -- il teşkilatı şartı (15_ekonomi3)
  if oyun.teskilat_engeli(p, p_tur) is not null then raise exception '%', oyun.teskilat_engeli(p, p_tur); end if;
  if p_tur = 'cb_on' then
    select * into k from oyun.cb_kararlar where donem = s.donem and parti_id = p.parti_id;
    if k.yontem in ('kendisi','baskasi') then raise exception 'Genel başkan cumhurbaşkanı adayını doğrudan belirledi; ön seçim yapılmayacak.'; end if;
    if k.yontem = 'destek' then raise exception 'Partin cumhurbaşkanlığında ittifak ortağının adayını destekliyor; ön seçim yapılmayacak.'; end if;
  end if;
  insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at)
  values (s.id, p.id, p.parti_id, case when p_tur in ('mv_on','bel_on') then p.il_id end, t)
  on conflict (secim_id, user_id) do nothing;
  if not found then raise exception 'Bu seçime zaten başvurdun.'; end if;
  -- aday adaylığı başvuru ücreti (parti kasasına); para yetmezse başvuru geri alınır
  perform oyun.aday_ucreti_al(p, p_tur, t);
  return public.durum();
end $$;

create or replace function public.adaylik_geri_cek(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.durum <> 'bekliyor' or t >= s.oy_bas then raise exception 'Oylama başladıktan sonra adaylıktan çekilemezsin.'; end if;
  delete from oyun.adaylar where secim_id = s.id and user_id = p.id;
  if not found then raise exception 'Bu seçimde adaylığın yok.'; end if;
  return public.durum();
end $$;

-- ---------- OY ----------
-- p_hedef: genel seçimde (mv) PARTİ id'si, diğer tüm seçimlerde ADAY id'si
create or replace function public.oy_ver(p_secim bigint, p_hedef bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; a oyun.adaylar; e text; onsecim bigint;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  if s.durum <> 'bekliyor' or t < s.oy_bas or t >= s.oy_bit then raise exception 'Sandık şu anda kapalı (oy saatleri 08:00–17:00).'; end if;
  e := oyun.oy_engeli(p, s);
  if e is not null then raise exception '%', e; end if;
  if exists (select 1 from oyun.oylar where secim_id = s.id and secmen = p.id) then raise exception 'Bu seçimde zaten oy kullandın.'; end if;

  if s.tur = 'mv' then
    select id into onsecim from oyun.secimler where tur = 'mv_on' and donem = s.donem;
    if not exists (select 1 from oyun.adaylar where secim_id = onsecim and il_id = p.il_id and parti_id = p_hedef and sira is not null) then
      raise exception 'Bu partinin ilinde aday listesi yok.';
    end if;
    insert into oyun.oylar(secim_id, secmen, il_id, parti_id, zaman) values (s.id, p.id, p.il_id, p_hedef, t);
  else
    select * into a from oyun.adaylar where id = p_hedef and secim_id = s.id;
    if a.id is null then raise exception 'Aday bulunamadı.'; end if;
    if s.tur in ('mv_on','bel_on') and (a.il_id <> p.il_id or a.parti_id <> p.parti_id) then
      raise exception 'Ön seçimde yalnızca kendi ilindeki kendi partinin adaylarına oy verebilirsin.';
    end if;
    if s.tur in ('kurultay','cb_on') and a.parti_id <> p.parti_id then raise exception 'Yalnızca kendi partinin seçiminde oy kullanabilirsin.'; end if;
    if s.tur = 'bel' and a.il_id <> p.il_id then raise exception 'Yalnızca kendi ilinin belediye seçiminde oy kullanabilirsin.'; end if;
    insert into oyun.oylar(secim_id, secmen, il_id, parti_id, aday_id, zaman) values (s.id, p.id, p.il_id, a.parti_id, a.id, t);
  end if;
  return public.durum();
end $$;

-- ---------- OKUMA ----------
create or replace function oyun.secim_ozet(s oyun.secimler, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', s.id, 'tur', s.tur, 'donem', s.donem, 'asama', oyun.asama(s, t),
    'basvuru_bas', s.basvuru_bas, 'basvuru_bit', s.basvuru_bit, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit,
    'sonuc_at', s.sonuc_at, 'goreve_bas', s.goreve_bas,
    'adayim', exists (select 1 from oyun.adaylar a where a.secim_id = s.id and a.user_id = p.id),
    'oy_verdim', exists (select 1 from oyun.oylar o where o.secim_id = s.id and o.secmen = p.id),
    'oy_engeli', oyun.oy_engeli(p, s),
    'katilim', case when s.durum <> 'bekliyor' or t >= s.oy_bas then (select count(*) from oyun.oylar o where o.secim_id = s.id) end)
$$;

create or replace function public.durum() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben(); p oyun.profiller; t timestamptz := oyun.simdi(); pa oyun.partiler; gun int := oyun.il_bekleme_gun(oyun.simdi());
begin
  select * into p from oyun.profiller where id = u;
  if p.id is null then
    return jsonb_build_object('simdi', t, 'profil', null);
  end if;
  if p.yasakli then raise exception 'Hesabın kural ihlali nedeniyle kapatıldı. İtiraz için oyun yönetimine e-posta gönderebilirsin.'; end if;
  if p.son_gorulme is null or p.son_gorulme < t - interval '5 minutes' then
    update oyun.profiller set son_gorulme = t where id = p.id;
  end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  return jsonb_build_object(
    'simdi', t,
    'profil', jsonb_build_object(
      'id', p.id, 'kad', p.kad, 'il_id', p.il_id, 'il_ad', (select ad from oyun.iller where id = p.il_id),
      'olusturma', p.olusturma, 'parti', oyun.parti_json(p.parti_id), 'parti_at', p.parti_at,
      'gb', pa.gb = p.id, 'gby', exists (select 1 from oyun.parti_gby g where g.user_id = p.id),
      'il_kilit', oyun.il_kilit_nedeni(t),
      'il_serbest', case when p.son_il_degis is null then null else p.son_il_degis + make_interval(days => gun) end,
      'makamlar', coalesce((select jsonb_agg(jsonb_build_object('tur', m.tur, 'il_id', m.il_id, 'il_ad', i.ad, 'bas', m.bas, 'kaynak', m.kaynak,
                                                    'bakanlik', m.bakanlik, 'bakanlik_ad', (select ad from oyun.bakanliklar b where b.kod = m.bakanlik)))
                            from oyun.makamlar m left join oyun.iller i on i.id = m.il_id where m.user_id = p.id and m.bit is null), '[]'::jsonb),
      'hesap_engeli', oyun.uyari(p, t),
      'cb_mi', exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null),
      'yonetici', p.yonetici, 'bildirim_ayar', p.bildirim_ayar,
      'yetkiler', oyun.yetkilerim(p.id), 'kredi_uyari', oyun.kredi_uyari(p.id),
      'cuzdan', oyun.cuzdan_ozet(p.id, t)),
    'okunmamis', oyun.okunmamis(p),
    'takvim', coalesce((select jsonb_agg(oyun.secim_ozet(s, p, t) order by coalesce(s.basvuru_bas, s.oy_bas), oyun.oncelik(s.tur))
                        from oyun.secimler s
                        where coalesce(s.goreve_bas, s.sonuc_at) >= t - interval '3 days'
                          and coalesce(s.basvuru_bas, s.oy_bas) <= t + interval '40 days'), '[]'::jsonb),
    'cb', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas)
           from oyun.makamlar m where m.tur = 'cb' and m.bit is null limit 1),
    'cb_karar', case when pa.gb = p.id then
       (select jsonb_build_object('secim_id', s.id, 'donem', s.donem, 'acik', t >= s.basvuru_bas and t < s.basvuru_bit,
                                  'yontem', k.yontem, 'aday', oyun.kad(k.aday), 'son', s.basvuru_bit,
                                  'destek', (select kisa from oyun.partiler where id = k.destek_parti))
        from oyun.secimler s left join oyun.cb_kararlar k on k.donem = s.donem and k.parti_id = pa.id
        where s.tur = 'cb' and s.durum = 'bekliyor' order by s.oy_bas limit 1) end
  );
end $$;

-- Bir seçimin ayrıntısı: oy pusulası (bana göre seçenekler) + sonuç
create or replace function public.secim_detay(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; onsecim bigint; secenek jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  if s.tur = 'mv' then
    select id into onsecim from oyun.secimler where tur = 'mv_on' and donem = s.donem;
    select coalesce(jsonb_agg(x order by x->>'kisa'), '[]'::jsonb) into secenek from (
      select oyun.parti_json(a.parti_id) || jsonb_build_object('hedef', a.parti_id, 'beyanname', oyun.beyanname_json(a.parti_id, s.donem),
             'liste', jsonb_agg(jsonb_build_object('kad', oyun.kad(a.user_id), 'sira', a.sira, 'vaat', a.vaat,
                                                   'vaatler', oyun.aday_vaatleri(a.user_id, s.id)) order by a.sira)) x
      from oyun.adaylar a where a.secim_id = onsecim and a.il_id = p.il_id and a.sira is not null
      group by a.parti_id) z;
  else
    select coalesce(jsonb_agg(oyun.aday_json(a.id) || jsonb_build_object('hedef', a.id, 'oy', case when s.durum = 'bekliyor' then null else a.oy end,
                     'beyanname', case when s.tur in ('cb','cb2') then oyun.beyanname_json(a.parti_id, s.donem) end)
                     order by a.parti_id, a.basvuru_at), '[]'::jsonb) into secenek
    from oyun.adaylar a
    where a.secim_id = s.id and (
      (s.tur in ('mv_on','bel_on') and a.il_id = p.il_id and a.parti_id = p.parti_id) or
      (s.tur in ('kurultay','cb_on') and a.parti_id = p.parti_id) or
      (s.tur = 'bel' and a.il_id = p.il_id) or
      (s.tur in ('cb','cb2')));
  end if;
  return oyun.secim_ozet(s, p, t) || jsonb_build_object('secenekler', secenek, 'sonuc', s.sonuc,
           'benim_il', p.il_id, 'benim_parti', p.parti_id,
           'destekler', case when s.tur in ('cb','cb2') then coalesce((select jsonb_object_agg(x.destek_parti::text, x.l) from (
               select k.destek_parti, jsonb_agg(oyun.parti_json(k.parti_id)) l from oyun.cb_kararlar k
               where k.donem = s.donem and k.yontem = 'destek' group by k.destek_parti) x), '{}'::jsonb) end);
end $$;

-- Türkiye haritası için il özeti
create or replace function public.harita() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id, 'ad', i.ad, 'mv', i.mv,
    'oyuncu', (select count(*) from oyun.profiller pr where pr.il_id = i.id),
    'bel', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id))
            from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1),
    'vekil', (select coalesce(jsonb_agg(jsonb_build_object('parti_id', x.parti_id, 'renk', pa.renk, 'kisa', pa.kisa, 'n', x.n) order by x.n desc), '[]'::jsonb)
              from (select parti_id, count(*) n from oyun.makamlar m where m.tur = 'mv' and m.il_id = i.id and m.bit is null group by parti_id) x
              join oyun.partiler pa on pa.id = x.parti_id)
  ) order by i.id), '[]'::jsonb)
  from oyun.iller i
$$;

create or replace function public.il_detay(p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); i oyun.iller; t timestamptz := oyun.simdi();
begin
  select * into i from oyun.iller where id = p_il;
  if i.id is null then raise exception 'İl bulunamadı.'; end if;
  return jsonb_build_object(
    'id', i.id, 'ad', i.ad, 'mv', i.mv,
    'oyuncu', (select count(*) from oyun.profiller where il_id = i.id),
    'partiler', coalesce((select jsonb_agg(oyun.parti_json(x.parti_id) || jsonb_build_object('uye', x.n) order by x.n desc)
                 from (select parti_id, count(*) n from oyun.profiller where il_id = i.id and parti_id is not null group by parti_id) x), '[]'::jsonb),
    'bel', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas)
            from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1),
    'vekiller', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'kaynak', m.kaynak) order by m.parti_id, m.bas)
                 from oyun.makamlar m where m.tur = 'mv' and m.il_id = i.id and m.bit is null), '[]'::jsonb),
    'adaylar', coalesce((select jsonb_agg(oyun.aday_json(a.id) || jsonb_build_object('tur', s.tur) order by s.tur, a.parti_id, a.sira nulls last, a.basvuru_at)
                 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
                 where a.il_id = i.id and (s.durum = 'bekliyor' or (s.tur = 'mv_on' and exists
                   (select 1 from oyun.secimler m where m.tur = 'mv' and m.donem = s.donem and m.durum = 'bekliyor')))), '[]'::jsonb),
    'benim_ilim', p.il_id = i.id,
    'durum', (select jsonb_build_object('gelisim', round(d.gelisim, 1), 'memnuniyet', round(d.memnuniyet, 1), 'kasa', round(d.kasa, 2))
              from oyun.il_durum d where d.il_id = i.id),
    'projeler', coalesce((select jsonb_agg(jsonb_build_object('ad', k.ad, 'zaman', k.zaman, 'baskan', oyun.kad(k.baskan)) order by k.zaman desc)
                 from (select x.*, coalesce(b.ad, y.ad) ad from oyun.belediye_proje_kayit x
                       left join oyun.belediye_hizmetleri b on b.kod = x.kod left join oyun.belediye_yatirimlari y on y.kod = x.kod
                       where x.il_id = i.id order by x.zaman desc limit 5) k), '[]'::jsonb),
    -- ilde yaşayanlara şu an işleyen belediye hizmetleri ve bakanlık tedbirleri
    'hizmetler', oyun.il_hizmet_json(i.id, t),
    'il_carpan', oyun.il_carpan(i.id),
    'kent_vergisi', (select kent_vergisi from oyun.il_durum where il_id = i.id),
    'hemsehri', (select hemsehri from oyun.il_durum where il_id = i.id),
    'tasinma', case when p.il_id <> i.id then oyun.tasinma_ucreti(p.il_id, i.id, t) end,
    'bel_vaatler', (select oyun.vaat_listesi_makam(m.id) from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1));
end $$;

create or replace function public.partiler() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(oyun.parti_json(pa.id) || jsonb_build_object(
    'uye', (select count(*) from oyun.profiller where parti_id = pa.id),
    'gb', oyun.kad(pa.gb), 'sistem', pa.sistem, 'kurulus_bit', pa.kurulus_bit,
    'vekil', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id),
    'belediye', (select count(*) from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.parti_id = pa.id))
    order by (select count(*) from oyun.profiller where parti_id = pa.id) desc, pa.id), '[]'::jsonb)
  from oyun.partiler pa where not pa.kapali
$$;

create or replace function public.parti_detay(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  return oyun.parti_json(pa.id) || jsonb_build_object(
    'kapali', pa.kapali, 'sistem', pa.sistem, 'kurulus', pa.kurulus, 'kurucu', oyun.kad(pa.kurucu),
    'kurulus_bit', pa.kurulus_bit,
    'kurucu_gecerli', case when pa.kurulus_bit is not null then oyun.kurucu_say(pa.id, oyun.simdi()) end,
    'kurucu_gerekli', case when pa.kurulus_bit is not null then (select parti_kurucu_sayi from oyun.ayarlar where id = 1) end,
    'kurucu_engelim', case when pa.kurulus_bit is not null and p.parti_id = pa.id then oyun.uyari(p, oyun.simdi()) end,
    'gb', oyun.kad(pa.gb),
    'gby', coalesce((select jsonb_agg(jsonb_build_object('sira', g.sira, 'kad', oyun.kad(g.user_id)) order by g.sira)
                     from oyun.parti_gby g where g.parti_id = pa.id), '[]'::jsonb),
    'uye', (select count(*) from oyun.profiller where parti_id = pa.id),
    'uyeler', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'il', i.ad,
                 'makam', (select string_agg(m.tur, ',') from oyun.makamlar m where m.user_id = pr.id and m.bit is null))
                 order by (pr.id = pa.gb) desc, exists (select 1 from oyun.parti_gby g where g.user_id = pr.id) desc, pr.parti_at)
               from (select * from oyun.profiller where parti_id = pa.id order by parti_at limit 300) pr join oyun.iller i on i.id = pr.il_id), '[]'::jsonb),
    'vekil', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id),
    'belediye', (select count(*) from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.parti_id = pa.id),
    'teskilat', (select count(*) from oyun.parti_teskilat t where t.parti_id = pa.id),
    'uyesiyim', p.parti_id = pa.id);
end $$;

create or replace function public.meclis() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object(
    'toplam', 600,
    'dolu', (select count(*) from oyun.makamlar where tur = 'mv' and bit is null),
    'partiler', coalesce((select jsonb_agg(oyun.parti_json(x.parti_id) || jsonb_build_object('n', x.n) order by x.n desc)
                 from (select parti_id, count(*) n from oyun.makamlar where tur = 'mv' and bit is null group by parti_id) x), '[]'::jsonb),
    'vekiller', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'il', i.ad, 'parti_id', m.parti_id) order by i.ad, m.parti_id)
                 from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.tur = 'mv' and m.bit is null), '[]'::jsonb))
$$;

create or replace function public.gecmis_secimler(p_limit int default 30) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'tur', s.tur, 'donem', s.donem, 'sonuc_at', s.sonuc_at) order by s.sonuc_at desc), '[]'::jsonb)
  from (select * from oyun.secimler where durum <> 'bekliyor' order by sonuc_at desc limit least(greatest(p_limit,1),100)) s
$$;

create or replace function public.haberler(p_limit int default 40) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('zaman', o.zaman, 'tur', o.tur, 'metin', o.metin, 'parti', oyun.parti_json(o.parti_id)) order by o.zaman desc, o.id desc), '[]'::jsonb)
  from (select * from oyun.olaylar where zaman <= oyun.simdi() order by zaman desc, id desc limit least(greatest(p_limit,1),100)) o
$$;

-- Hesabı ve tüm kişisel verileri siler (App Store zorunluluğu)
create or replace function public.hesabimi_sil() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben(); t timestamptz := oyun.simdi(); m record;
begin
  for m in select id from oyun.makamlar where user_id = u and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'hesap_silindi');
  end loop;
  perform oyun._ayril(u, t);
  delete from oyun.adaylar a using oyun.secimler s where a.secim_id = s.id and a.user_id = u and s.durum = 'bekliyor';
  update oyun.oylar set secmen = gen_random_uuid() where secmen = u;   -- oy sayısı korunur, kimlik kopar
  delete from oyun.mesajlar where user_id = u;
  delete from oyun.ozel where gonderen = u or alici = u;
  delete from oyun.yayinlar where gonderen = u;
  delete from oyun.bildirimler where user_id = u;
  delete from oyun.engellemeler where engelleyen = u or engellenen = u;
  delete from oyun.profiller where id = u;
  delete from auth.users where id = u;
  return jsonb_build_object('silindi', true);
end $$;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 5) KABİNE + SOSYAL
--  Bakan atama, sohbet kanalları, özel mesaj, propaganda yayınları,
--  bildirim kutusu, şikâyet/engelleme.
-- =====================================================================

-- ---------- yardımcılar ----------
create or replace function oyun.kufurlu(t text) returns boolean language sql immutable as $$
  select exists (select 1 from unnest(array[
    'orospu','yarrak','pezevenk','kahpe','amcik','surtuk','serefsiz','yavsak','ibne','gavat','siktir','amina',
    'aminakoy','anani','sikerim','sikeyim','pust','kaltak','dalyarak','gerizekali'
  ]) y where oyun.sade(t) like '%' || y || '%')
$$;

-- Oyuncunun en yüksek unvanı (sohbet rozetleri ve yayın imzası için)
create or replace function oyun.unvan(u uuid) returns text language sql stable as $$
  select coalesce(
    (select 'Cumhurbaşkanı' from oyun.makamlar where user_id = u and tur = 'cb' and bit is null limit 1),
    (select replace(b.ad, 'Bakanlığı', 'Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik
       where m.user_id = u and m.tur = 'bakan' and m.bit is null limit 1),
    (select pa.kisa || ' Genel Başkanı' from oyun.partiler pa where pa.gb = u and not pa.kapali limit 1),
    (select i.ad || ' Milletvekili' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'mv' and m.bit is null limit 1),
    (select i.ad || ' Belediye Başkanı' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'bel' and m.bit is null limit 1),
    (select pa.kisa || ' Genel Başkan Yardımcısı' from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id where g.user_id = u limit 1))
$$;

create or replace function oyun.engelli(ben uuid, diger uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.engellemeler where engelleyen = ben and engellenen = diger)
$$;

create or replace function oyun.yayin_gorur(y oyun.yayinlar, p oyun.profiller) returns boolean language sql stable as $$
  select (y.hedef_il is null or y.hedef_il = p.il_id) and (y.hedef_parti is null or y.hedef_parti = p.parti_id)
$$;

create or replace function oyun.okunmamis(p oyun.profiller) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'bildirim',
      (select count(*) from oyun.yayinlar y where not y.gizli and y.gonderen <> p.id and y.zaman > p.bildirim_okundu
         and y.zaman <= oyun.simdi() and oyun.yayin_gorur(y, p) and not oyun.engelli(p.id, y.gonderen))
      + (select count(*) from oyun.bildirimler b where b.user_id = p.id and b.zaman > p.bildirim_okundu and b.zaman <= oyun.simdi()),
    'ozel',
      (select count(*) from oyun.ozel o where o.alici = p.id and not o.okundu and not o.gizli and not oyun.engelli(p.id, o.gonderen)))
$$;

create or replace function oyun.yazabilir_mi(p oyun.profiller, t timestamptz) returns void language plpgsql as $$
begin
  if p.susturma_bitis is not null and p.susturma_bitis > t then
    raise exception 'Hesabın % tarihine kadar mesaj gönderemez (kural ihlali).', to_char(p.susturma_bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI');
  end if;
  if p.son_mesaj is not null and p.son_mesaj > t - interval '3 seconds' then
    raise exception 'Çok hızlı yazıyorsun, birkaç saniye bekle.';
  end if;
  if (select count(*) from oyun.mesajlar where user_id = p.id and zaman > t - interval '1 minute')
   + (select count(*) from oyun.ozel where gonderen = p.id and zaman > t - interval '1 minute') >= 12 then
    raise exception 'Bir dakikada çok fazla mesaj gönderdin, biraz bekle.';
  end if;
end $$;

create or replace function oyun.metin_temizle(m text, enfazla int) returns text language plpgsql as $$
begin
  m := btrim(regexp_replace(coalesce(m, ''), '[\r\n]{3,}', E'\n\n', 'g'));
  if length(m) = 0 then raise exception 'Mesaj boş olamaz.'; end if;
  if length(m) > enfazla then raise exception 'Mesaj en fazla % karakter olabilir.', enfazla; end if;
  if oyun.kufurlu(m) then raise exception 'Mesajında uygunsuz bir ifade var. Hakaret ve küfür yasaktır.'; end if;
  return m;
end $$;

create or replace function oyun.profil_bul(p_kad text) returns oyun.profiller language plpgsql stable as $$
declare h oyun.profiller;
begin
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  return h;
end $$;

-- =====================================================================
--  KABİNE
-- =====================================================================
create or replace function public.kabine() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object(
    'cb', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas)
           from oyun.makamlar m where m.tur = 'cb' and m.bit is null limit 1),
    'bakanlar', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad,
                   'kad', oyun.kad(m.user_id),
                   'parti', oyun.parti_json((select parti_id from oyun.profiller where id = m.user_id)),
                   'bas', m.bas) order by b.sira)
                 from oyun.bakanliklar b left join oyun.makamlar m on m.bakanlik = b.kod and m.tur = 'bakan' and m.bit is null))
$$;

create or replace function oyun.cb_zorunlu(p oyun.profiller) returns void language plpgsql as $$
begin
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null) then
    raise exception 'Bu yetki yalnızca cumhurbaşkanındadır.';
  end if;
end $$;

-- Cumhurbaşkanı bir bakanlığa atama yapar. Atanan kişinin varsa vekilliği/belediye başkanlığı düşer
-- (vekilliğine listeden yedek gelir); bakanlıkta biri varsa görevden alınır.
create or replace function public.bakan_ata(p_bakanlik text, p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; b oyun.bakanliklar; m record;
begin
  perform oyun.cb_zorunlu(p);
  select * into b from oyun.bakanliklar where kod = p_bakanlik;
  if b.kod is null then raise exception 'Bakanlık bulunamadı.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Cumhurbaşkanı kendini bakan atayamaz.'; end if;
  if oyun.uyari(h, t) is not null then raise exception 'Atanacak kişi için: %', oyun.uyari(h, t); end if;
  if exists (select 1 from oyun.makamlar where tur = 'bakan' and bakanlik = b.kod and bit is null and user_id = h.id) then
    raise exception '% zaten bu bakanlıkta.', h.kad;
  end if;
  -- tek görev kuralı: başka görevi olan kişi bakan atanamaz; önce istifa etmelidir
  if oyun.rol_cakisma(h.id, 'bakan') is not null then
    raise exception '% şu anda % görevinde. Bakan atanabilmesi için önce o görevden ayrılması gerekir.', h.kad, oyun.rol_cakisma(h.id, 'bakan');
  end if;
  -- bakanlıktaki eski bakan görevden alınır
  for m in select id from oyun.makamlar where tur = 'bakan' and bakanlik = b.kod and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'gorevden_alindi');
  end loop;
  insert into oyun.makamlar(tur, user_id, il_id, parti_id, bakanlik, kaynak, bas)
  values ('bakan', h.id, null, h.parti_id, b.kod, 'atama', t);
  perform oyun.bildir(h.id, format('Cumhurbaşkanı %s seni %s olarak atadı.', p.kad, replace(b.ad, 'Bakanlığı', 'Bakanı')), t);
  perform oyun.olay('makam', format('%s, %s olarak atandı.', h.kad, replace(b.ad, 'Bakanlığı', 'Bakanı')), null, h.parti_id, t);
  perform oyun.gazete_ekle('atama', format('%s''na %s atandı', b.ad, h.kad), format('Cumhurbaşkanı %s tarafından %s olarak atanmıştır.', p.kad, replace(b.ad, 'Bakanlığı', 'Bakanı')), null, t);
  return public.kabine();
end $$;

create or replace function public.bakan_gorevden_al(p_bakanlik text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m record; n int := 0;
begin
  perform oyun.cb_zorunlu(p);
  for m in select id, user_id from oyun.makamlar where tur = 'bakan' and bakanlik = p_bakanlik and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'gorevden_alindi');
    perform oyun.olay('makam', format('%s, %s görevinden alındı.', oyun.kad(m.user_id), (select ad from oyun.bakanliklar where kod = p_bakanlik)), null, null, t);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Bu bakanlık zaten boş.'; end if;
  return public.kabine();
end $$;

-- Bakanlıktan veya genel başkan yardımcılığından istifa
create or replace function public.istifa(p_gorev text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; cb uuid;
begin
  if p_gorev = 'bakan' then
    select * into m from oyun.makamlar where user_id = p.id and tur = 'bakan' and bit is null;
    if m.id is null then raise exception 'Bakan değilsin.'; end if;
    perform oyun.makam_bitir(m.id, t, 'istifa');
    select user_id into cb from oyun.makamlar where tur = 'cb' and bit is null limit 1;
    if cb is not null then perform oyun.bildir(cb, format('%s, %s görevinden istifa etti.', p.kad, oyun.makam_ad('bakan', null, m.bakanlik)), t); end if;
    perform oyun.olay('makam', format('%s, %s görevinden istifa etti.', p.kad, oyun.makam_ad('bakan', null, m.bakanlik)), null, p.parti_id, t);
  elsif p_gorev in ('mv','bel') then
    select * into m from oyun.makamlar where user_id = p.id and tur = p_gorev and bit is null;
    if m.id is null then raise exception 'Bu görevde değilsin.'; end if;
    perform oyun.makam_bitir(m.id, t, 'istifa');
    perform oyun.olay('makam', format('%s, %s görevinden istifa etti.', p.kad, oyun.makam_ad(m.tur, m.il_id, null)), m.il_id, p.parti_id, t);
  elsif p_gorev = 'gby' then
    delete from oyun.parti_gby where user_id = p.id;
    if not found then raise exception 'Genel başkan yardımcısı değilsin.'; end if;
    perform oyun.bildir((select gb from oyun.partiler where id = p.parti_id), format('%s genel başkan yardımcılığından istifa etti.', p.kad), t);
  else
    raise exception 'Geçersiz görev.';
  end if;
  return public.durum();
end $$;

create or replace function public.oyuncu_kart(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  return jsonb_build_object('kad', h.kad, 'il_ad', (select ad from oyun.iller where id = h.il_id), 'il_id', h.il_id,
    'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'katilim', h.olusturma,
    'ben', h.id = p.id, 'engelledim', oyun.engelli(p.id, h.id),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('makam', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'bit', m.bit) order by m.bas desc)
                        from (select * from oyun.makamlar where user_id = h.id order by bas desc limit 20) m), '[]'::jsonb));
end $$;

-- =====================================================================
--  SOHBET KANALLARI: genel · il · parti · meclis
-- =====================================================================
create or replace function oyun.kanal_coz(p oyun.profiller, p_kanal text) returns text language plpgsql stable as $$
begin
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (select 'ittifak:' || u.ittifak_id from oyun.ittifak_uyeler u where u.parti_id = p.parti_id)
    else null end;
end $$;

create or replace function oyun.meclis_yazabilir(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.makamlar where user_id = u and bit is null and tur in ('mv','cb','bakan'))
$$;

-- p_sonra: bu id'den yeni mesajlar (canlı takip) · p_once: bu id'den eski mesajlar (yukarı kaydırma)
create or replace function public.sohbet_oku(p_kanal text, p_once bigint default null, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', case when p_kanal = 'ittifak' then 'Partin bir ittifakta değil.' else 'Parti sohbeti için bir partiye üye olmalısın.' end; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'kad', coalesce(pr.kad, '(silinmiş)'), 'metin', x.metin, 'zaman', x.zaman,
            'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(x.user_id), 'benim', x.user_id = p.id) order by x.id), '[]'::jsonb)
    into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal = k and not m.gizli and m.zaman <= oyun.simdi() and not oyun.engelli(p.id, m.user_id)
      and (p_sonra is null or m.id > p_sonra) and (p_once is null or m.id < p_once)
    order by case when p_sonra is null then -m.id else m.id end
    limit case when p_sonra is null then 40 else 100 end
  ) x left join oyun.profiller pr on pr.id = x.user_id;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste,
    'yazabilir', case when p_kanal = 'meclis' then oyun.meclis_yazabilir(p.id) else true end,
    'baslik', case p_kanal when 'genel' then 'Türkiye Meydanı' when 'il' then (select ad from oyun.iller where id = p.il_id) || ' Kahvesi'
                           when 'parti' then (select ad from oyun.partiler where id = p.parti_id) when 'meclis' then 'TBMM Genel Kurulu'
                           when 'ittifak' then (select i.ad from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = p.parti_id) end);
end $$;

create or replace function public.sohbet_yaz(p_kanal text, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; m text;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', case when p_kanal = 'ittifak' then 'Partin bir ittifakta değil.' else 'Parti sohbeti için bir partiye üye olmalısın.' end; end if;
  if p_kanal = 'meclis' and not oyun.meclis_yazabilir(p.id) then
    raise exception 'Genel Kurul''da yalnızca milletvekilleri, bakanlar ve cumhurbaşkanı söz alabilir.';
  end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 500);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values (k, p.id, m, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- =====================================================================
--  ÖZEL MESAJ
-- =====================================================================
create or replace function public.ozel_liste() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  with ben as (select oyun.ben() id),
  m as (
    select o.*, case when o.gonderen = (select id from ben) then o.alici else o.gonderen end diger
    from oyun.ozel o where (o.gonderen = (select id from ben) or o.alici = (select id from ben)) and not o.gizli
  ),
  son as (select distinct on (diger) * from m order by diger, id desc)
  select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(pr.id),
           'son', s.metin, 'zaman', s.zaman, 'benden', s.gonderen = (select id from ben),
           'okunmamis', (select count(*) from m where m.diger = s.diger and m.alici = (select id from ben) and not m.okundu)) order by s.id desc), '[]'::jsonb)
  from son s join oyun.profiller pr on pr.id = s.diger
  where not oyun.engelli((select id from ben), s.diger)
$$;

create or replace function public.ozel_oku(p_kad text, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; liste jsonb;
begin
  h := oyun.profil_bul(p_kad);
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'metin', x.metin, 'zaman', x.zaman, 'benim', x.gonderen = p.id) order by x.id), '[]'::jsonb) into liste
  from (select * from oyun.ozel o
        where ((o.gonderen = p.id and o.alici = h.id) or (o.gonderen = h.id and o.alici = p.id)) and not o.gizli
          and (p_sonra is null or o.id > p_sonra)
        order by o.id desc limit 60) x;
  update oyun.ozel set okundu = true where alici = p.id and gonderen = h.id and not okundu;
  return jsonb_build_object('kad', h.kad, 'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'mesajlar', liste,
                            'engelledim', oyun.engelli(p.id, h.id));
end $$;

create or replace function public.ozel_yaz(p_kad text, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; m text;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendine mesaj gönderemezsin.'; end if;
  if oyun.engelli(h.id, p.id) or oyun.engelli(p.id, h.id) then raise exception 'Bu oyuncuyla mesajlaşamazsın (engelleme var).'; end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 1000);
  insert into oyun.ozel(gonderen, alici, metin, zaman) values (p.id, h.id, m, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- =====================================================================
--  PROPAGANDA YAYINLARI
--  Kim, kime, günde kaç kez:
--    Cumhurbaşkanı      → tüm Türkiye              1/gün  (Ulusa sesleniş)
--    Bakan              → tüm Türkiye              1/gün  (Bakanlık açıklaması)
--    Genel başkan       → partinin tüm üyeleri     3/gün  (Parti genelgesi)
--    GB yardımcısı      → partinin tüm üyeleri     1/gün
--    Milletvekili       → ilindeki herkes          1/gün
--    Belediye başkanı   → ilindeki herkes          1/gün
--    Aday (her seçim için ayrı, oylama bitene kadar) 1/gün:
--       ön seçim adayı  → partinin o ildeki üyeleri (vekil/belediye) ya da tüm üyeleri (kurultay/CB)
--       belediye adayı  → ildeki herkes · vekil listesi adayı → ildeki herkes · CB adayı → tüm Türkiye
-- =====================================================================
create or replace function oyun.yayin_secenekleri(p oyun.profiller, t timestamptz)
returns table(tur text, secim_id bigint, unvan text, hedef_il smallint, hedef_parti bigint, gunluk int)
language sql stable as $$
  select 'cb', null::bigint, 'Cumhurbaşkanı', null::smallint, null::bigint, 1
    from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null
  union all
  select 'bakan', null, replace(b.ad, 'Bakanlığı', 'Bakanı'), null, null, 1
    from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik where m.user_id = p.id and m.tur = 'bakan' and m.bit is null
  union all
  select 'parti', null, pa.kisa || ' Genel Başkanı', null, pa.id, 3 from oyun.partiler pa where pa.gb = p.id and not pa.kapali
  union all
  select 'parti', null, pa.kisa || ' Genel Başkan Yardımcısı', null, pa.id, 1
    from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id where g.user_id = p.id and pa.gb is distinct from p.id
  union all
  select 'vekil', null, i.ad || ' Milletvekili', m.il_id, null, 1
    from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = p.id and m.tur = 'mv' and m.bit is null
  union all
  select 'belediye', null, i.ad || ' Belediye Başkanı', m.il_id, null, 1
    from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = p.id and m.tur = 'bel' and m.bit is null
  union all
  -- adaylıklar (oylama bitene kadar)
  select 'aday', s.id,
         case s.tur when 'mv_on' then pa.kisa || ' ' || i.ad || ' milletvekili aday adayı'
                    when 'bel_on' then pa.kisa || ' ' || i.ad || ' belediye başkanı aday adayı'
                    when 'bel' then pa.kisa || ' ' || i.ad || ' Belediye Başkanı adayı'
                    when 'kurultay' then pa.kisa || ' genel başkan adayı'
                    when 'cb_on' then pa.kisa || ' cumhurbaşkanı aday adayı'
                    else 'Cumhurbaşkanı adayı' end,
         case when s.tur in ('mv_on','bel_on','bel') then a.il_id end,
         case when s.tur in ('mv_on','bel_on','kurultay','cb_on') then a.parti_id end,
         1
    from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
    left join oyun.partiler pa on pa.id = a.parti_id left join oyun.iller i on i.id = a.il_id
    where a.user_id = p.id and s.durum = 'bekliyor' and t < s.oy_bit
  union all
  -- genel seçimde partisinin listesinde olan aday
  select 'aday', g.id, pa.kisa || ' ' || i.ad || ' milletvekili adayı (' || a.sira || '. sıra)', a.il_id, null, 1
    from oyun.adaylar a join oyun.secimler o on o.id = a.secim_id and o.tur = 'mv_on'
    join oyun.secimler g on g.tur = 'mv' and g.donem = o.donem and g.durum = 'bekliyor' and t < g.oy_bit
    join oyun.partiler pa on pa.id = a.parti_id join oyun.iller i on i.id = a.il_id
    where a.user_id = p.id and a.sira is not null
$$;

create or replace function oyun.bugun_bas(t timestamptz) returns timestamptz language sql stable as $$
  select oyun.tr_an((t at time zone 'Europe/Istanbul')::date, 0)
$$;

create or replace function public.yayin_haklari() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(jsonb_build_object(
      'tur', y.tur, 'secim_id', y.secim_id, 'unvan', y.unvan,
      'hedef', case when y.hedef_il is null and y.hedef_parti is null then 'Tüm Türkiye'
                    when y.hedef_parti is null then (select ad from oyun.iller where id = y.hedef_il) || '''deki tüm oyuncular'
                    when y.hedef_il is null then (select kisa from oyun.partiler where id = y.hedef_parti) || ' üyeleri'
                    else (select kisa from oyun.partiler where id = y.hedef_parti) || ' ' || (select ad from oyun.iller where id = y.hedef_il) || ' üyeleri' end,
      'kitle', (select count(*) from oyun.profiller x where x.id <> p.id
                  and (y.hedef_il is null or x.il_id = y.hedef_il) and (y.hedef_parti is null or x.parti_id = y.hedef_parti)),
      'gunluk', y.gunluk + oyun.bonus(p.il_id, 'yayin', t)::int,
      'kalan', greatest(0, y.gunluk + oyun.bonus(p.il_id, 'yayin', t)::int - (select count(*) from oyun.yayinlar k where k.gonderen = p.id and k.tur = y.tur
                  and k.secim_id is not distinct from y.secim_id and k.unvan = y.unvan and k.zaman >= oyun.bugun_bas(t))))
    order by y.tur, y.secim_id) from oyun.yayin_secenekleri(p, t) y), '[]'::jsonb);
end $$;

create or replace function public.yayin_gonder(p_tur text, p_metin text, p_secim bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); y record; m text; kullanilan int; kitle int;
begin
  select * into y from oyun.yayin_secenekleri(p, t) s where s.tur = p_tur and s.secim_id is not distinct from p_secim limit 1;
  if y.tur is null then raise exception 'Bu türde yayın yapma yetkin yok.'; end if;
  if p.susturma_bitis is not null and p.susturma_bitis > t then raise exception 'Hesabın şu anda yayın yapamaz (kural ihlali).'; end if;
  select count(*) into kullanilan from oyun.yayinlar k where k.gonderen = p.id and k.tur = y.tur
    and k.secim_id is not distinct from y.secim_id and k.unvan = y.unvan and k.zaman >= oyun.bugun_bas(t);
  if kullanilan >= y.gunluk + oyun.bonus(p.il_id, 'yayin', t)::int then
    -- satın alınmış ek yayın hakkı (reklam) varsa onu kullan
    perform oyun.cuzdanim(p.id);
    update oyun.cuzdan set reklam_kul = reklam_kul + 1 where user_id = p.id and reklam_n > reklam_kul;
    if not found then raise exception 'Bugünkü yayın hakkını kullandın. Yarın yeniden gönderebilir ya da Hayat ekranından ek yayın hakkı alabilirsin.'; end if;
  end if;
  m := oyun.metin_temizle(p_metin, 600);
  insert into oyun.yayinlar(tur, gonderen, metin, zaman, hedef_il, hedef_parti, secim_id, unvan)
  values (y.tur, p.id, m, t, y.hedef_il, y.hedef_parti, y.secim_id, y.unvan);
  select count(*) into kitle from oyun.profiller x where x.id <> p.id
    and (y.hedef_il is null or x.il_id = y.hedef_il) and (y.hedef_parti is null or x.parti_id = y.hedef_parti);
  return jsonb_build_object('tamam', true, 'kitle', kitle);
end $$;

-- Bildirim kutusu: bana ulaşan propaganda yayınları + kişisel bildirimler. Açınca okundu sayılır.
create or replace function public.bildirim_kutusu(p_limit int default 60) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); j jsonb; lim int := least(greatest(p_limit, 1), 100);
begin
  select coalesce(jsonb_agg(u.x order by u.z desc), '[]'::jsonb) into j from (
    (select jsonb_build_object('tur', 'yayin', 'id', y.id, 'yayin_tur', y.tur, 'zaman', y.zaman, 'metin', y.metin,
             'kad', coalesce(pr.kad, '(silinmiş)'), 'unvan', y.unvan, 'parti', oyun.parti_json(pr.parti_id),
             'benim', y.gonderen = p.id, 'yeni', y.zaman > p.bildirim_okundu and y.gonderen <> p.id) x, y.zaman z
     from oyun.yayinlar y left join oyun.profiller pr on pr.id = y.gonderen
     where not y.gizli and y.zaman <= t and oyun.yayin_gorur(y, p) and not oyun.engelli(p.id, y.gonderen)
     order by y.zaman desc limit lim)
    union all
    (select jsonb_build_object('tur', 'kisisel', 'id', b.id, 'zaman', b.zaman, 'metin', b.metin, 'yeni', b.zaman > p.bildirim_okundu) x, b.zaman z
     from oyun.bildirimler b where b.user_id = p.id and b.zaman <= t
     order by b.zaman desc limit lim)
  ) u;
  update oyun.profiller set bildirim_okundu = t where id = p.id;
  return j;
end $$;

create or replace function public.rozetler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
begin
  return oyun.okunmamis(oyun.profilim());
end $$;

-- =====================================================================
--  ENGELLEME VE ŞİKÂYET
--  3 farklı oyuncunun şikâyet ettiği mesaj/yayın otomatik gizlenir.
--  24 saatte 8 farklı oyuncudan şikâyet alan hesap 24 saat susturulur.
-- =====================================================================
create or replace function public.engelle(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendini engelleyemezsin.'; end if;
  insert into oyun.engellemeler(engelleyen, engellenen) values (p.id, h.id) on conflict do nothing;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.engel_kaldir(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  delete from oyun.engellemeler where engelleyen = p.id and engellenen = h.id;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.engellenenler() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad) order by pr.kad), '[]'::jsonb)
  from oyun.engellemeler e join oyun.profiller pr on pr.id = e.engellenen where e.engelleyen = oyun.ben()
$$;

create or replace function public.sikayet_et(p_tur text, p_id bigint, p_kad text, p_neden text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); hedef uuid; n int;
begin
  if p_neden not in ('hakaret','nefret','spam','taciz','uygunsuz','diger') then raise exception 'Geçersiz şikâyet nedeni.'; end if;
  if p_tur = 'mesaj' then select user_id into hedef from oyun.mesajlar where id = p_id;
  elsif p_tur = 'ozel' then select gonderen into hedef from oyun.ozel where id = p_id and alici = p.id;
  elsif p_tur = 'yayin' then select gonderen into hedef from oyun.yayinlar where id = p_id;
  elsif p_tur = 'oyuncu' then hedef := (oyun.profil_bul(p_kad)).id; p_id := null;
  else raise exception 'Geçersiz şikâyet türü.'; end if;
  if hedef is null then raise exception 'Şikâyet edilecek kayıt bulunamadı.'; end if;
  if hedef = p.id then raise exception 'Kendini şikâyet edemezsin.'; end if;
  insert into oyun.sikayetler(sikayetci, hedef_user, tur, kayit_id, neden, zaman)
  values (p.id, hedef, p_tur, coalesce(p_id, 0), p_neden, t) on conflict do nothing;
  -- kayıt bazında otomatik gizleme
  if p_tur in ('mesaj','ozel','yayin') then
    select count(distinct sikayetci) into n from oyun.sikayetler where tur = p_tur and kayit_id = p_id;
    if n >= 3 or p_tur = 'ozel' then
      if p_tur = 'mesaj' then update oyun.mesajlar set gizli = true where id = p_id;
      elsif p_tur = 'ozel' then update oyun.ozel set gizli = true where id = p_id;
      else update oyun.yayinlar set gizli = true where id = p_id; end if;
    end if;
  end if;
  -- hesap bazında otomatik susturma
  select count(distinct sikayetci) into n from oyun.sikayetler where hedef_user = hedef and zaman > t - interval '24 hours';
  if n >= 8 then
    update oyun.profiller set susturma_bitis = greatest(coalesce(susturma_bitis, t), t + interval '24 hours') where id = hedef;
  end if;
  return jsonb_build_object('tamam', true);
end $$;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 7) DEVLET: ülke ekonomisi, bakanlık
--  icraatları, kanun süreci, cumhurbaşkanı kararnameleri, ittifaklar,
--  Resmî Gazete.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.ulke(
  id          int primary key default 1 check (id = 1),
  hazine      numeric not null default 200,   -- milyar ₺
  vergi       numeric not null default 20,    -- yürürlükteki oran (%)
  vergi_kanun numeric not null default 20,    -- bütçe kanunundaki oran (%)
  buyume      numeric not null default 3,
  enflasyon   numeric not null default 35,
  issizlik    numeric not null default 9,
  memnuniyet  numeric not null default 50,    -- halkın hükümetten memnuniyeti (0-100)
  butce       jsonb not null default '{"adalet":7,"disisleri":5,"icisleri":9,"maliye":6,"savunma":12,"egitim":14,"saglik":13,"sanayi":7,"ticaret":5,"tarim":7,"ulastirma":9,"calisma":6}',
  bekleyen_baraj numeric,                     -- seçim döneminde kabul edilen baraj, seçimden sonra uygulanır
  son_gun     date
);
insert into oyun.ulke(id) values (1) on conflict do nothing;
-- Ekonomi politikaları (oyuncuların cüzdanına doğrudan yansır)
--   Yürütme (cumhurbaşkanı ve ilgili bakan): asgari, kidem_primi, destek, vergi (Meclis bandı içinde), tasinma_destek
--   Meclis (bütçe kanunu): vergi_alt / vergi_ust, belediye_payi, parti_yardim, bakanlık payları
alter table oyun.ulke add column if not exists asgari         numeric not null default 28075;  -- aylık net asgari ücret (₺), 2026
alter table oyun.ulke add column if not exists asgari_ref     numeric not null default 28075;  -- ekonominin enflasyonsuz kaldırabileceği ücret düzeyi
alter table oyun.ulke add column if not exists kidem_primi    numeric not null default 10;     -- statü basamağı başına maaş primi (%)
alter table oyun.ulke add column if not exists destek         numeric not null default 0;      -- yeni oyunculara günlük sosyal destek (₺)
alter table oyun.ulke add column if not exists tasinma_destek numeric not null default 0;      -- taşınma masrafına devlet desteği (%)
alter table oyun.ulke add column if not exists vergi_alt      numeric not null default 10;
alter table oyun.ulke add column if not exists vergi_ust      numeric not null default 35;
alter table oyun.ulke add column if not exists belediye_payi  numeric not null default 10;     -- vergi gelirlerinden belediyelere pay (%)
alter table oyun.ulke add column if not exists parti_yardim   numeric not null default 30000;  -- partilere günlük toplam hazine yardımı (₺)
alter table oyun.ulke add column if not exists endeks         numeric not null default 1;      -- fiyat düzeyi (başlangıç 1)
alter table oyun.ulke drop column if exists temel_gelir;
alter table oyun.ulke drop column if exists katsayi;
update oyun.ulke set asgari = 28075, asgari_ref = 28075 where asgari < 1000;

create table if not exists oyun.ulke_gecmis(
  gun date primary key,
  hazine numeric, vergi numeric, buyume numeric, enflasyon numeric, issizlik numeric, memnuniyet numeric
);

create table if not exists oyun.il_durum(
  il_id      smallint primary key references oyun.iller(id),
  gelisim    numeric not null default 50,      -- 0-100
  memnuniyet numeric not null default 50,      -- ildeki halkın belediyeden memnuniyeti (0-100)
  kasa       numeric                           -- belediye kasası (milyar ₺)
);
insert into oyun.il_durum(il_id) select id from oyun.iller on conflict do nothing;
alter table oyun.il_durum add column if not exists kent_vergisi numeric not null default 2;   -- belediye başkanının belirlediği kent vergisi (%)
alter table oyun.il_durum add column if not exists hemsehri     numeric not null default 0;   -- aktif her il sakinine günlük hemşehri desteği (₺)
alter table oyun.il_durum add column if not exists son_ayar     timestamptz;                  -- kent vergisi / destek son değişiklik
-- İlin günlük taban geliri: 0,02 + 0,004 × vekil sayısı (milyar ₺). Gerçek gelir: gelişmişlik, belediye payı ve kent vergisiyle çarpılır.
-- Başlangıç kasası 5 günlük taban gelir.
create or replace function oyun.il_gunluk_gelir(p_mv int) returns numeric language sql immutable as $$ select 0.02 + 0.004 * p_mv $$;
update oyun.il_durum d set kasa = 5 * oyun.il_gunluk_gelir(i.mv) from oyun.iller i where i.id = d.il_id and d.kasa is null;

create table if not exists oyun.bakanlik_kasa(
  kod  text primary key references oyun.bakanliklar(kod),
  kasa numeric not null default 20             -- milyar ₺
);
insert into oyun.bakanlik_kasa(kod) select kod from oyun.bakanliklar on conflict do nothing;

create table if not exists oyun.icraatlar(
  kod          text primary key,
  bakanlik     text not null references oyun.bakanliklar(kod),
  ad           text not null,
  aciklama     text not null,
  maliyet      numeric not null,
  bekleme_saat int not null,
  il_gerekli   boolean not null default false,
  etki         jsonb not null                  -- buyume, enflasyon, issizlik, memnuniyet, hazine (ulusal) · gelisim (il)
);
-- Oyunculara doğrudan işleyen etkiler (oyuncu: [{tur, deger}], sure_gun gün sürer) ve özel tek seferlik işlemler (ozel)
alter table oyun.icraatlar add column if not exists oyuncu   jsonb not null default '[]';
alter table oyun.icraatlar add column if not exists sure_gun int;
alter table oyun.icraatlar add column if not exists ozel     text;
delete from oyun.icraatlar where kod not in ('adl_harc','adl_ifade','dis_zirve','dis_turizm','ic_nufus','ic_afad','mal_iade','mal_varlik',
  'sav_sanayi','sav_bedelli','egt_burs','egt_seferber','sag_ucretsiz','sag_hastane','san_osb','san_tesvik','tic_fiyat','tic_ihracat',
  'tar_market','tar_sulama','ula_toplu','ula_tren','cal_istihdam','cal_esnaf');
-- oyuncu etkileri: ucret (% maaş) · ucret_yeni (% maaş, yalnız ilk iki statü) · gecim (% geçim masrafı indirimi) · tasinma (% indirim)
--                  il_bekleme (gün) · yayin (+hak/gün) · kidem_x (kıdem puanı çarpanı, %)
insert into oyun.icraatlar(kod, bakanlik, ad, aciklama, maliyet, bekleme_saat, il_gerekli, etki, oyuncu, sure_gun, ozel) values
 ('adl_harc','adalet','Harç muafiyeti','Tapu, nüfus ve noter harçları kaldırılır: taşınma masrafı 7 gün boyunca yarıya iner.',3,168,false,'{"memnuniyet":0.5}','[{"tur":"tasinma","deger":50}]',7,null),
 ('adl_ifade','adalet','İfade özgürlüğü paketi','Propaganda kısıtlamaları gevşer: yayın yetkisi olan herkesin günlük yayın hakkı 7 gün boyunca 1 artar.',4,168,false,'{"memnuniyet":0.5}','[{"tur":"yayin","deger":1}]',7,null),
 ('dis_zirve','disisleri','Uluslararası yatırım zirvesi','Yabancı yatırımcı gelir: hazineye 15 milyar ₺ girer, tüm maaşlar 7 gün boyunca %5 artar.',8,168,false,'{"hazine":15,"buyume":0.2}','[{"tur":"ucret","deger":5}]',7,null),
 ('dis_turizm','disisleri','Turizm tanıtım kampanyası','Seçilen il dünyaya tanıtılır: il kalıcı olarak gelişir, o ilde maaşlar 14 gün boyunca %10 artar.',8,72,true,'{"gelisim":4}','[{"tur":"ucret","deger":10}]',14,null),
 ('ic_nufus','icisleri','Nüfus işlemlerinde kolaylık','Adres değişikliği hızlanır: il değiştirme bekleme süresi 7 gün boyunca 30 günden 7 güne iner.',2,168,false,'{}','[{"tur":"il_bekleme","deger":7}]',7,null),
 ('ic_afad','icisleri','AFAD afet yardımı','Seçilen ilde yaşayan her oyuncunun cüzdanına anında 3.000 ₺ afet yardımı yatar.',6,72,true,'{"memnuniyet":0.3}','[]',null,'il_yardim'),
 ('mal_iade','maliye','Vergi iadesi','Son 7 günde gelirlerinden kesilen verginin yarısı her oyuncuya geri ödenir.',4,168,false,'{"memnuniyet":1,"hazine":-6}','[]',null,'vergi_iade'),
 ('mal_varlik','maliye','Varlık barışı','Kayıt dışı servet kayda alınır: hazineye 25 milyar ₺ girer, enflasyon biraz artar. Yeni vaatlere mali alan açar.',1,168,false,'{"hazine":25,"enflasyon":0.5}','[]',null,null),
 ('sav_sanayi','savunma','Savunma sanayii yatırımı','Seçilen ile savunma fabrikası: o ilde maaşlar 14 gün boyunca %15 artar, il kalıcı olarak gelişir.',12,72,true,'{"gelisim":3,"issizlik":-0.2}','[{"tur":"ucret","deger":15}]',14,null),
 ('sav_bedelli','savunma','Bedelli askerlik düzenlemesi','Bedelli askerlik ücretiyle hazineye 20 milyar ₺ girer; halk memnuniyeti biraz düşer.',1,168,false,'{"hazine":20,"memnuniyet":-1}','[]',null,null),
 ('egt_burs','egitim','Gençlere burs ve staj programı','Yeni Gelen ve Vatandaş statüsündeki oyuncuların maaşı 7 gün boyunca %20 artar.',6,168,false,'{"memnuniyet":0.5}','[{"tur":"ucret_yeni","deger":20}]',7,null),
 ('egt_seferber','egitim','Hayat boyu öğrenme seferberliği','7 gün boyunca kazanılan kıdem puanı iki katına çıkar: herkes daha hızlı statü atlar.',5,168,false,'{"memnuniyet":0.5}','[{"tur":"kidem_x","deger":100}]',7,null),
 ('sag_ucretsiz','saglik','Ücretsiz sağlık hizmeti','Muayene ve ilaç katkı payları kaldırılır: herkesin geçim masrafı 7 gün boyunca %10 düşer.',6,168,false,'{"memnuniyet":1}','[{"tur":"gecim","deger":10}]',7,null),
 ('sag_hastane','saglik','Şehir hastanesi','Seçilen ile şehir hastanesi: il kalıcı olarak gelişir, o ilde geçim masrafı 14 gün boyunca %10 düşer.',15,72,true,'{"gelisim":5,"memnuniyet":0.5}','[{"tur":"gecim","deger":10}]',14,null),
 ('san_osb','sanayi','Organize sanayi bölgesi','Seçilen ile fabrikalar: o ilde maaşlar 14 gün boyunca %15 artar, il kalıcı olarak gelişir.',12,72,true,'{"gelisim":5,"issizlik":-0.3,"buyume":0.2}','[{"tur":"ucret","deger":15}]',14,null),
 ('san_tesvik','sanayi','Teknoloji teşvik paketi','Yerli teknoloji şirketlerine destek: tüm maaşlar 7 gün boyunca %5 artar, büyüme hızlanır.',8,168,false,'{"buyume":0.3}','[{"tur":"ucret","deger":5}]',7,null),
 ('tic_fiyat','ticaret','Fahiş fiyat denetimi','Market ve kira denetimleri: geçim masrafı 7 gün boyunca %10 düşer, enflasyon biraz geriler.',4,168,false,'{"enflasyon":-0.5}','[{"tur":"gecim","deger":10}]',7,null),
 ('tic_ihracat','ticaret','İhracat seferberliği','Döviz girişi artar: enflasyon 2 puan düşer, büyüme hızlanır. Fiyatlar kalıcı olarak yavaşlar.',8,168,false,'{"enflasyon":-2,"buyume":0.3}','[]',null,null),
 ('tar_market','tarim','Tarım Kredi indirim marketleri','Üreticiden tüketiciye ucuz gıda: geçim masrafı 7 gün boyunca %15 düşer.',6,168,false,'{"memnuniyet":0.5,"enflasyon":-0.3}','[{"tur":"gecim","deger":15}]',7,null),
 ('tar_sulama','tarim','Sulama ve kırsal kalkınma','Seçilen ilde baraj ve sulama: il kalıcı olarak gelişir, gıda ucuzlar (o ilde geçim 14 gün %5 düşer).',8,72,true,'{"gelisim":4,"buyume":0.1}','[{"tur":"gecim","deger":5}]',14,null),
 ('ula_toplu','ulastirma','Toplu taşımada indirim','Şehir içi ve şehirlerarası ulaşım ucuzlar: geçim masrafı %5, taşınma masrafı %30 düşer (7 gün).',6,168,false,'{"memnuniyet":0.5}','[{"tur":"gecim","deger":5},{"tur":"tasinma","deger":30}]',7,null),
 ('ula_tren','ulastirma','Hızlı tren hattı','Seçilen il hızlı tren ağına bağlanır: il kalıcı olarak gelişir, o ile/o ilden taşınmak 14 gün yarı fiyat.',20,72,true,'{"gelisim":8,"buyume":0.2}','[{"tur":"tasinma","deger":50}]',14,null),
 ('cal_istihdam','calisma','İstihdam paketi','İşverenlere prim desteği: tüm maaşlar 7 gün boyunca %10 artar.',10,168,false,'{"issizlik":-0.5}','[{"tur":"ucret","deger":10}]',7,null),
 ('cal_esnaf','calisma','Esnaf ve sanatkâra destek kredisi','Ucuz kredi: maaşlar %5 artar, geçim masrafı %5 düşer (7 gün).',6,168,false,'{"memnuniyet":0.5}','[{"tur":"ucret","deger":5},{"tur":"gecim","deger":5}]',7,null)
on conflict (kod) do update set bakanlik = excluded.bakanlik, ad = excluded.ad, aciklama = excluded.aciklama, maliyet = excluded.maliyet,
  bekleme_saat = excluded.bekleme_saat, il_gerekli = excluded.il_gerekli, etki = excluded.etki,
  oyuncu = excluded.oyuncu, sure_gun = excluded.sure_gun, ozel = excluded.ozel;

-- Süreli oyuncu etkileri (bakanlık icraatları). il_id null → tüm ülke.
create table if not exists oyun.etkiler(
  id         bigserial primary key,
  il_id      smallint references oyun.iller(id),
  tur        text not null,
  deger      numeric not null,
  bas        timestamptz not null,
  bit        timestamptz not null,
  kaynak_tur text not null,
  kaynak_kod text not null,
  kaynak_ad  text not null,
  user_id    uuid
);
create index if not exists etkiler_aktif on oyun.etkiler(tur, bit);

create table if not exists oyun.icraat_kayit(
  id     bigserial primary key,
  kod    text not null,
  bakan  uuid not null,
  il_id  smallint,
  zaman  timestamptz not null,
  maliyet numeric not null
);
create index if not exists icraat_kayit_kod on oyun.icraat_kayit(kod, zaman desc);

-- Resmî Gazete
create table if not exists oyun.gazete(
  id     bigserial primary key,
  zaman  timestamptz not null,
  tur    text not null check (tur in ('kanun','kararname','atama','icraat')),
  baslik text not null,
  metin  text,
  ref_id bigint
);
create index if not exists gazete_zaman on oyun.gazete(zaman desc);

create sequence if not exists oyun.kanun_no start 8001;
create sequence if not exists oyun.kararname_no start 1;

create table if not exists oyun.kanunlar(
  id          bigserial primary key,
  no          int,                                   -- yürürlüğe girince verilen kanun numarası
  tur         text not null,
  baslik      text not null,
  metin       text not null,
  veri        jsonb,
  teklif_eden uuid not null,
  teklif_parti bigint,
  durum       text not null default 'gorusmede'
              check (durum in ('gorusmede','oylamada','cb_onayinda','israr','yururlukte','ret','dustu','kaduk','geri_cekildi')),
  teklif_at   timestamptz not null,
  oy_bas      timestamptz not null,
  oy_bit      timestamptz not null,
  cb_bit      timestamptz,
  israr_bit   timestamptz,
  veto_gerekce text,
  sonuc_at    timestamptz,
  sonuc_metin text
);
create index if not exists kanunlar_durum on oyun.kanunlar(durum, teklif_at desc);

create table if not exists oyun.kanun_oylari(
  kanun_id bigint not null references oyun.kanunlar(id) on delete cascade,
  asama    text not null check (asama in ('ilk','israr')),
  vekil    uuid not null,
  parti_id bigint,
  oy       text not null check (oy in ('kabul','ret','cekimser')),
  zaman    timestamptz not null,
  primary key (kanun_id, asama, vekil)
);

create table if not exists oyun.kararnameler(
  id     bigserial primary key,
  no     int not null,
  tur    text not null,
  baslik text not null,
  metin  text,
  veri   jsonb,
  cb     uuid not null,
  zaman  timestamptz not null,
  durum  text not null default 'yururlukte' check (durum in ('yururlukte','iptal'))
);
-- kanunlar_tur_check ve kararnameler_tur_check en güncel listeleriyle 12_mevzuat.sql'de tanımlıdır
-- (kalıcılık kuralı: izin verilen değer listeleri yalnızca genişler; eski dosyalar dar listeyi geri kurmaz)

alter table oyun.ittifaklar add column if not exists kurucu_parti bigint;
create table if not exists oyun.ittifak_davetler(
  ittifak_id bigint not null references oyun.ittifaklar(id) on delete cascade,
  parti_id   bigint not null references oyun.partiler(id) on delete cascade,
  zaman      timestamptz not null,
  primary key (ittifak_id, parti_id)
);

-- ---------------------------------------------------------------------
-- YARDIMCILAR
-- ---------------------------------------------------------------------
-- Ülke çapındaki bir ödemenin kaç kişiye yapıldığı (bütçe maliyeti = kişi başı ₺ × kişi / 1e9 milyar ₺)
--   destek   : yeni oyunculara sosyal destek ≈ 8 milyon kişi
--   ikramiye : bayram ikramiyesi ≈ 16 milyon kişi
--   il_hane  : bir ildeki hemşehri desteği alan hane ≈ 5 milyon × ilin vekil payı
create or replace function oyun.nufus(p_kod text) returns numeric language sql immutable as $$
  select case p_kod when 'destek' then 8e6 when 'ikramiye' then 16e6 when 'il_hane' then 5e6 else 0 end
$$;
drop function if exists oyun.kur();

create or replace function oyun.sinir(x numeric, a numeric, b numeric) returns numeric language sql immutable as $$
  select greatest(a, least(b, x))
$$;

create or replace function oyun.gazete_ekle(p_tur text, p_baslik text, p_metin text, p_ref bigint, p_zaman timestamptz)
returns void language sql as $$
  insert into oyun.gazete(zaman, tur, baslik, metin, ref_id) values (p_zaman, p_tur, p_baslik, p_metin, p_ref)
$$;

create or replace function oyun.aktif_vekil(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv' and bit is null)
$$;

create or replace function oyun.dolu_sandalye() returns int language sql stable as $$
  select count(*)::int from oyun.makamlar where tur = 'mv' and bit is null
$$;

create or replace function oyun.aktif_cb() returns uuid language sql stable as $$
  select user_id from oyun.makamlar where tur = 'cb' and bit is null limit 1
$$;

-- Ulusal göstergelere etki uygula (icraat ve kararnameler)
create or replace function oyun.etki_uygula(e jsonb, p_il smallint) returns void language plpgsql as $$
begin
  update oyun.ulke set
    buyume     = oyun.sinir(buyume + coalesce((e->>'buyume')::numeric, 0), -10, 15),
    enflasyon  = oyun.sinir(enflasyon + coalesce((e->>'enflasyon')::numeric, 0), 0, 200),
    issizlik   = oyun.sinir(issizlik + coalesce((e->>'issizlik')::numeric, 0), 2, 40),
    memnuniyet = oyun.sinir(memnuniyet + coalesce((e->>'memnuniyet')::numeric, 0), 0, 100),
    hazine     = hazine + coalesce((e->>'hazine')::numeric, 0)
  where id = 1;
  if p_il is not null and e ? 'gelisim' then
    update oyun.il_durum set gelisim = oyun.sinir(gelisim + (e->>'gelisim')::numeric, 0, 100) where il_id = p_il;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- GÜNLÜK EKONOMİ (her gece, tick içinden)
-- ---------------------------------------------------------------------
-- Ülkenin günlük gelir-gider kalemleri (milyar ₺). Politikalar 85 milyonluk ülkeye uygulanır;
-- oyuncular bu ülkenin vatandaşlarıdır. Oyuncu sayısı bütçeyi değiştirmez.
--   gelir vergisi : asgari ücreti aşan kazançlardan (asgari ücret vergiden muaftır)
--   diğer gelirler: KDV, ÖTV, kurumlar vergisi — büyüme ve fiyat düzeyiyle artar
--   cari giderler : 10 × fiyat düzeyi, bütçe kanunundaki paylarla bakanlık kasalarına
--   belediye payı : illerin taban gelirinin yarısı × (belediye payı / %10)
--   sosyal destek : yeni oyunculara verilen günlük destek × 8 milyon kişi
create or replace function oyun.ulke_hesap(u oyun.ulke) returns jsonb language sql stable as $$
  with x as (select
      round(u.asgari / 30 * 0.6 * 25e6 * u.vergi / 100 / 1e9, 3) gv,
      round(9.5 * (1 + u.buyume / 50) * u.endeks, 3) diger,
      round(10 * u.endeks, 3) cari,
      round((select sum(oyun.il_gunluk_gelir(mv)) from oyun.iller) * 0.5 * u.belediye_payi / 10 * u.endeks, 3) bel,
      round(u.destek * 8e6 / 1e9, 3) destek)
  select jsonb_build_object('gelir_vergisi', gv, 'diger_gelir', diger, 'gelir', gv + diger,
                            'cari', cari, 'belediye', bel, 'destek', destek, 'gider', cari + bel + destek,
                            'denge', round(gv + diger - cari - bel - destek, 3)) from x
$$;

-- İlin günlük geliri (milyar ₺): taban × gelişmişlik × (öz gelir + kanundaki belediye payı) × (1 + kent vergisi / 10)
create or replace function oyun.il_gelir(p_il smallint) returns numeric language sql stable as $$
  select round(oyun.il_gunluk_gelir(i.mv) * u.endeks * (0.5 + d.gelisim / 100) * (0.5 + 0.5 * u.belediye_payi / 10) * (1 + d.kent_vergisi / 10), 4)
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$$;

create or replace function oyun.gunluk_ekonomi(t timestamptz) returns void language plpgsql as $$
declare u oyun.ulke; bugun date := (t at time zone 'Europe/Istanbul')::date; g date; h jsonb; hb numeric; he numeric; hi numeric; hm numeric; acik numeric; mk jsonb;
begin
  select * into u from oyun.ulke where id = 1 for update;
  if u.son_gun is null then
    update oyun.ulke set son_gun = bugun where id = 1;
    insert into oyun.ulke_gecmis values (bugun, u.hazine, u.vergi, u.buyume, u.enflasyon, u.issizlik, u.memnuniyet) on conflict do nothing;
    return;
  end if;
  if u.son_gun >= bugun then return; end if;
  g := greatest(u.son_gun + 1, bugun - 31);
  while g <= bugun loop
    h := oyun.ulke_hesap(u);
    u.hazine := u.hazine + (h ->> 'denge')::numeric;
    update oyun.bakanlik_kasa k set kasa = least(100, kasa + (h ->> 'cari')::numeric * coalesce((u.butce ->> k.kod)::numeric, 0) / 100);
    -- belediyeler: gelir girer, açık hizmetlerin ve hemşehri desteğinin günlük gideri düşer
    update oyun.ulke set endeks = u.endeks, belediye_payi = u.belediye_payi where id = 1;
    perform oyun.belediye_gunluk(t);
    -- göstergeler hedeflerine doğru kayar
    mk := oyun.mevzuat_makro();
    hb := 4 - (u.vergi - 20) * 0.15 - greatest(0, u.enflasyon - 30) * 0.03 + (mk ->> 'buyume')::numeric;
    u.buyume := u.buyume + (hb - u.buyume) * 0.05;
    acik := greatest(0, u.asgari / u.asgari_ref - 1);           -- ekonominin kaldıramadığı ücret artışı
    he := 25 + greatest(0, -u.hazine) * 0.05 + (u.buyume - 3) * 0.5 + acik * 40 + (u.kidem_primi - 10) * 0.15 + u.destek / 100 + (mk ->> 'enflasyon')::numeric;
    u.enflasyon := u.enflasyon + (he - u.enflasyon) * 0.03 + case when u.hazine < 0 then 0.2 else 0 end;
    hi := 12 - u.buyume * 0.8;
    u.issizlik := u.issizlik + (hi - u.issizlik) * 0.05;
    hm := oyun.sinir(50 - (u.enflasyon - 30) * 0.4 - (u.issizlik - 9) * 1.5 + (u.buyume - 3) * 2 - (u.vergi - 20) * 0.6 + (mk ->> 'memnuniyet')::numeric, 5, 95);
    u.memnuniyet := u.memnuniyet + (hm - u.memnuniyet) * 0.08;
    u.buyume := oyun.sinir(u.buyume, -10, 15); u.enflasyon := oyun.sinir(u.enflasyon, 0, 200);
    u.issizlik := oyun.sinir(u.issizlik, 2, 40); u.memnuniyet := oyun.sinir(u.memnuniyet, 0, 100);
    -- fiyat düzeyi enflasyonla, ücret kaldırma kapasitesi enflasyon + büyümeyle artar
    u.endeks := round(u.endeks * (1 + u.enflasyon / 36500), 6);
    u.asgari_ref := round(u.asgari_ref * (1 + (u.enflasyon + greatest(0, u.buyume)) / 36500), 2);
    update oyun.ulke set hazine = u.hazine, buyume = u.buyume, enflasyon = u.enflasyon, issizlik = u.issizlik, memnuniyet = u.memnuniyet,
      endeks = u.endeks, asgari_ref = u.asgari_ref where id = 1;
    perform oyun.gunluk_odemeler(g, t);
    perform oyun.mevzuat_gunluk(g, t);
    perform oyun.vaat_degerlendir(g, t);
    select * into u from oyun.ulke where id = 1;
    insert into oyun.ulke_gecmis values (g, round(u.hazine, 1), u.vergi, round(u.buyume, 2), round(u.enflasyon, 2), round(u.issizlik, 2), round(u.memnuniyet, 1))
      on conflict (gun) do update set hazine = excluded.hazine, vergi = excluded.vergi, buyume = excluded.buyume,
        enflasyon = excluded.enflasyon, issizlik = excluded.issizlik, memnuniyet = excluded.memnuniyet;
    g := g + 1;
  end loop;
  update oyun.ulke set son_gun = bugun where id = 1;
end $$;

-- ---------------------------------------------------------------------
-- BAKANLIK İCRAATLARI
-- ---------------------------------------------------------------------
create or replace function public.bakanlik_paneli() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; pay numeric;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bakan' and bit is null;
  if m.id is null then return null; end if;
  pay := coalesce(((select butce from oyun.ulke where id = 1) ->> m.bakanlik)::numeric, 0);
  return jsonb_build_object(
    'politikalar', oyun.politika_listesi(m.bakanlik, t),
    'kod', m.bakanlik, 'ad', (select ad from oyun.bakanliklar where kod = m.bakanlik),
    'kasa', round((select kasa from oyun.bakanlik_kasa where kod = m.bakanlik), 1),
    'gunluk', round(10 * pay / 100, 2), 'pay', pay,
    'icraatlar', (select jsonb_agg(jsonb_build_object('kod', i.kod, 'ad', i.ad, 'aciklama', i.aciklama, 'maliyet', i.maliyet,
                    'il_gerekli', i.il_gerekli, 'etki', i.etki, 'bekleme_saat', i.bekleme_saat,
                    'oyuncu', i.oyuncu, 'sure_gun', i.sure_gun, 'ozel', i.ozel,
                    'aktif_bit', (select max(e.bit) from oyun.etkiler e where e.kaynak_kod = i.kod and e.il_id is null and e.bit > t),
                    'hazir', (select max(k.zaman) + make_interval(hours => i.bekleme_saat) from oyun.icraat_kayit k where k.kod = i.kod))
                  order by i.maliyet) from oyun.icraatlar i where i.bakanlik = m.bakanlik));
end $$;

create or replace function public.icraat_yap(p_kod text, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.icraatlar; m oyun.makamlar; son timestamptz; v_kasa numeric; ilad text;
        bk text; n int; toplam numeric; ek text := ''; vekalet_mi boolean := false;
begin
  select * into i from oyun.icraatlar where kod = p_kod;
  if i.kod is null then raise exception 'İcraat bulunamadı.'; end if;
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bakan' and bit is null and bakanlik = i.bakanlik;
  vekalet_mi := m.id is null and oyun.bakanlik_vekili(p.id, i.bakanlik);     -- boş bakanlığa cumhurbaşkanı vekâlet eder
  if m.id is null and not vekalet_mi then raise exception 'Bu icraatı yalnızca ilgili bakan yapabilir; bakanlık boşsa cumhurbaşkanı vekâleten yapar.'; end if;
  if i.il_gerekli then
    select ad into ilad from oyun.iller where id = p_il;
    if ilad is null then raise exception 'Bir il seçmelisin.'; end if;
  else p_il := null; end if;
  select max(zaman) into son from oyun.icraat_kayit where kod = i.kod;
  if son is not null and son + make_interval(hours => i.bekleme_saat) > t then
    raise exception 'Bu icraat % tarihinden sonra tekrar yapılabilir.', to_char((son + make_interval(hours => i.bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  select k.kasa into v_kasa from oyun.bakanlik_kasa k where k.kod = i.bakanlik for update;
  if v_kasa < i.maliyet then raise exception 'Bakanlık kasasında yeterli ödenek yok (% milyar ₺ gerekli, kasada % var).', i.maliyet, round(v_kasa, 1); end if;
  update oyun.bakanlik_kasa set kasa = kasa - i.maliyet where kod = i.bakanlik;
  perform oyun.etki_uygula(i.etki, p_il::smallint);
  select ad into bk from oyun.bakanliklar where kod = i.bakanlik;
  -- oyunculara süreli etki
  perform oyun.etki_ekle(p_il::smallint, 'bakanlik', i.kod, bk || ' · ' || i.ad || coalesce(' (' || ilad || ')', ''), i.oyuncu, i.sure_gun, p.id, t);
  -- tek seferlik ödemeler
  if i.ozel = 'il_yardim' then
    insert into oyun.cuzdan(user_id, para, son_toplama) select id, (select baslangic_para from oyun.ayarlar where id = 1), t - interval '8 hours'
      from oyun.profiller where il_id = p_il on conflict do nothing;
    with h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select id, t, 3000, 'yardim', 'AFAD afet yardımı (' || ilad || ')' from oyun.profiller where il_id = p_il and not yasakli returning user_id)
    update oyun.cuzdan c set para = para + 3000 from h where c.user_id = h.user_id;
    get diagnostics n = row_count;
    ek := format(' %s oyuncuya 3.000''er ₺ ödendi.', n);
  elsif i.ozel = 'vergi_iade' then
    with v as (select user_id, round(sum(vergi) / 2) iade from oyun.hesap_hareket where vergi > 0 and zaman > t - interval '7 days' group by user_id),
         h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select user_id, t, iade, 'iade', 'Vergi iadesi (son 7 günün vergisinin yarısı)' from v where iade > 0 returning user_id, tutar)
    , c as (update oyun.cuzdan c set para = para + h.tutar from h where c.user_id = h.user_id returning h.tutar)
    select count(*), coalesce(sum(tutar), 0) into n, toplam from c;
    ek := format(' %s oyuncuya toplam %s ₺ iade edildi.', n, toplam);
  end if;
  insert into oyun.icraat_kayit(kod, bakan, il_id, zaman, maliyet) values (i.kod, p.id, p_il, t, i.maliyet);
  perform oyun.gazete_ekle('icraat', i.ad || coalesce(' — ' || ilad, ''),
    format('%s %s tarafından başlatıldı. %s Maliyet: %s milyar ₺.%s', case when vekalet_mi then bk || ' vekâleten Cumhurbaşkanı' else replace(bk, 'Bakanlığı', 'Bakanı') end, p.kad, i.aciklama, i.maliyet, ek), null, t);
  perform oyun.olay('icraat', format('%s: %s%s.', case when vekalet_mi then 'Cumhurbaşkanı ' || p.kad || ' (' || bk || ' vekâleten)' else (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = i.bakanlik) || ' ' || p.kad end, i.ad, coalesce(' (' || ilad || ')', '')), p_il::smallint, p.parti_id, t);
  return public.bakanlik_paneli();
end $$;

-- ---------------------------------------------------------------------
-- ÜLKE KARNESİ
-- ---------------------------------------------------------------------
create or replace function public.ulke_karnesi() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.ulke; e oyun.ulke_gecmis;
begin
  select * into u from oyun.ulke where id = 1;
  select * into e from oyun.ulke_gecmis where gun <= (t at time zone 'Europe/Istanbul')::date - 7 order by gun desc limit 1;
  return jsonb_build_object(
    'hazine', round(u.hazine, 1), 'vergi', u.vergi, 'vergi_alt', u.vergi_alt, 'vergi_ust', u.vergi_ust,
    'buyume', round(u.buyume, 2), 'enflasyon', round(u.enflasyon, 1), 'issizlik', round(u.issizlik, 1), 'memnuniyet', round(u.memnuniyet, 1),
    'baraj', (select baraj from oyun.ayarlar where id = 1), 'bekleyen_baraj', u.bekleyen_baraj,
    'kararname_sinir', oyun.anayasa_deger('kararname_sinir'), 'vergi_tavani', oyun.anayasa_deger('vergi_tavani'),
    'asgari', u.asgari, 'asgari_ref', round(u.asgari_ref), 'kidem_primi', u.kidem_primi, 'destek', u.destek, 'tasinma_destek', u.tasinma_destek,
    'belediye_payi', u.belediye_payi, 'parti_yardim', u.parti_yardim, 'endeks', round(u.endeks, 3),
    'hesap', oyun.ulke_hesap(u), 'mali_alan', oyun.mali_alan(),
    'makam_maaslari', (select jsonb_object_agg(k, round(oyun.makam_maasi(k, null))) from unnest(array['cb','bakan','mv']) k),
    'cb_mi', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null),
    'politikalar', oyun.politika_listesi(null, t),
    'aktif_oyuncu', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '7 days'),
    'ulusal_etkiler', coalesce((select jsonb_agg(jsonb_build_object('kaynak', x.kaynak_ad, 'bit', x.bit, 'etkiler', x.e) order by x.bit)
        from (select kaynak_ad, max(bit) bit, jsonb_agg(jsonb_build_object('tur', tur, 'deger', deger)) e from oyun.etkiler
              where il_id is null and bas <= t and bit > t group by kaynak_ad) x), '[]'::jsonb),
    'once', case when e.gun is null then null else to_jsonb(e) end,
    'gecmis', coalesce((select jsonb_agg(to_jsonb(x) order by x.gun) from (select * from oyun.ulke_gecmis order by gun desc limit 30) x), '[]'::jsonb),
    'butce', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'pay', coalesce((u.butce ->> b.kod)::numeric, 0),
                 'kasa', round(k.kasa, 1)) order by b.sira) from oyun.bakanliklar b join oyun.bakanlik_kasa k on k.kod = b.kod),
    'iller', (select jsonb_agg(jsonb_build_object('id', d.il_id, 'ad', i.ad, 'gelisim', round(d.gelisim, 1)) order by d.gelisim desc)
              from oyun.il_durum d join oyun.iller i on i.id = d.il_id));
end $$;

create or replace function public.gazete(p_limit int default 50) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'zaman', g.zaman, 'tur', g.tur, 'baslik', g.baslik, 'metin', g.metin, 'ref_id', g.ref_id)
         order by g.zaman desc, g.id desc), '[]'::jsonb)
  from (select * from oyun.gazete where zaman <= oyun.simdi() order by zaman desc, id desc limit least(greatest(p_limit, 1), 100)) g
$$;

-- ---------------------------------------------------------------------
-- CUMHURBAŞKANLIĞI KARARNAMELERİ (günde en fazla 3)
--   serbest   : metin olarak yayımlanır
--   il_destek : hazineden bir ile 1-30 milyar ₺ kalkınma desteği → il gelişmişliği ve memnuniyet
--   odenek    : hazineden bir bakanlığın kasasına 1-30 milyar ₺ ek ödenek
--   ikramiye  : bayram ikramiyesi — son 7 günde oyuna giren her oyuncuya 500-5.000 ₺ (7 günde bir)
--               bütçe maliyeti: tutar × 16 milyon kişi
-- Ekonomi ayarları (vergi, asgari ücret, kıdem primi, sosyal destek, taşınma desteği) politika_ayarla ile yapılır.
-- ---------------------------------------------------------------------
create or replace function public.kararname_cikar(p_tur text, p_baslik text, p_metin text, p_veri jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); n int; miktar numeric; il_ad text; bk text; yeni bigint; v_no int; b text; m text; maliyet numeric;
        sinir int := coalesce(oyun.anayasa_deger('kararname_sinir'), 3)::int; dt record; eng text; deger numeric; faiz numeric; u oyun.ulke;
begin
  perform oyun.cb_zorunlu(p);
  if sinir = 0 then raise exception 'Anayasa cumhurbaşkanının kararname yetkisini kaldırdı.'; end if;
  if (select count(*) from oyun.kararnameler k where k.cb = p.id and k.zaman >= oyun.bugun_bas(t)) >= sinir then
    raise exception 'Bugün en fazla % kararname çıkarabilirsin (anayasal sınır).', sinir;
  end if;
  m := nullif(btrim(coalesce(p_metin, '')), '');
  if m is not null then m := oyun.metin_temizle(m, 3000); end if;
  if p_tur = 'serbest' then
    b := btrim(coalesce(p_baslik, ''));
    if length(b) < 5 or length(b) > 120 then raise exception 'Başlık 5-120 karakter olmalı.'; end if;
    if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
    if m is null then raise exception 'Kararname metni boş olamaz.'; end if;
  elsif p_tur = 'il_destek' then
    miktar := (p_veri ->> 'miktar')::numeric;
    select ad into il_ad from oyun.iller where id = (p_veri ->> 'il_id')::int;
    if il_ad is null then raise exception 'Geçersiz il.'; end if;
    if miktar is null or miktar < 1 or miktar > 30 then raise exception 'Destek miktarı 1-30 milyar ₺ olmalı.'; end if;
    b := format('%s İline %s Milyar ₺ Kalkınma Desteği Hakkında Karar', il_ad, miktar);
    update oyun.ulke set hazine = hazine - miktar where id = 1;
    perform oyun.etki_uygula(jsonb_build_object('gelisim', miktar * 0.4, 'memnuniyet', miktar * 0.03), (p_veri ->> 'il_id')::smallint);
  elsif p_tur = 'odenek' then
    miktar := (p_veri ->> 'miktar')::numeric;
    select ad into bk from oyun.bakanliklar where kod = p_veri ->> 'bakanlik';
    if bk is null then raise exception 'Geçersiz bakanlık.'; end if;
    if miktar is null or miktar < 1 or miktar > 30 then raise exception 'Ödenek 1-30 milyar ₺ olmalı.'; end if;
    b := format('%s''na %s Milyar ₺ Ek Ödenek Hakkında Karar', bk, miktar);
    update oyun.ulke set hazine = hazine - miktar where id = 1;
    update oyun.bakanlik_kasa set kasa = kasa + miktar where kod = p_veri ->> 'bakanlik';
  elsif p_tur = 'ikramiye' then
    miktar := round((p_veri ->> 'miktar')::numeric);
    if miktar is null or miktar < 500 or miktar > 5000 then raise exception 'İkramiye kişi başı 500-5.000 ₺ arasında olmalı.'; end if;
    if exists (select 1 from oyun.kararnameler where tur = 'ikramiye' and durum = 'yururlukte' and zaman > t - interval '7 days') then
      raise exception 'Bayram ikramiyesi 7 günde bir verilebilir.';
    end if;
    maliyet := round(miktar * oyun.nufus('ikramiye') / 1e9, 2);
    insert into oyun.cuzdan(user_id, para, son_toplama) select id, (select baslangic_para from oyun.ayarlar where id = 1), t - interval '8 hours'
      from oyun.profiller on conflict do nothing;
    with h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select id, t, miktar, 'ikramiye', 'Bayram ikramiyesi (Cumhurbaşkanlığı kararı)' from oyun.profiller
               where not yasakli and son_gorulme > t - interval '7 days' returning user_id)
    update oyun.cuzdan c set para = para + miktar from h where c.user_id = h.user_id;
    get diagnostics n = row_count;
    update oyun.ulke set hazine = hazine - maliyet where id = 1;
    b := format('Kişi Başı %s ₺ Bayram İkramiyesi Ödenmesi Hakkında Karar', to_char(miktar, 'FM999G999'));
    p_veri := jsonb_build_object('miktar', miktar, 'kisi', n, 'maliyet', maliyet);
  elsif p_tur = 'duzenleme' then
    -- Oyuncuları etkileyen kural (mevzuat): kanunla ya da anayasayla düzenlenmiş konuda kararname çıkarılamaz
    select * into dt from oyun.duzenleme_tanim where kod = p_veri ->> 'kod' and kapsam = 'ulke';
    if dt.kod is null then raise exception 'Geçersiz düzenleme.'; end if;
    eng := oyun.duzenleme_engel(dt.kod, 'kararname');
    if eng is not null then raise exception '%', eng; end if;
    deger := oyun.duzenleme_dogrula(dt.kod, (p_veri ->> 'deger')::numeric, 'ulke');
    if deger = oyun.duz(dt.kod) then raise exception 'Bu kural zaten bu değerde.'; end if;
    if exists (select 1 from oyun.duzenlemeler where kod = dt.kod and kaynak = 'kararname' and zaman > t - interval '24 hours') then
      raise exception 'Aynı kural 24 saatte bir değiştirilebilir.';
    end if;
    p_veri := jsonb_build_object('kod', dt.kod, 'deger', deger,
      'onceki', jsonb_build_object('deger', oyun.duz(dt.kod), 'kaynak', (select kaynak from oyun.duzenlemeler where kod = dt.kod),
                                   'ref_id', (select ref_id from oyun.duzenlemeler where kod = dt.kod)));
    b := format('%s Hakkında Karar (%s)', dt.ad, oyun.duz_yaz(dt.kod, deger));
  elsif p_tur = 'ozellestirme' then
    -- Kamu varlığı satışı: hazineye tek seferlik gelir; işsizlik artar, memnuniyet düşer
    miktar := round((p_veri ->> 'miktar')::numeric);
    if miktar is null or miktar < 10 or miktar > 100 then raise exception 'Özelleştirme 10-100 milyar ₺ arasında olmalı.'; end if;
    if miktar > (select kamu_varlik from oyun.ulke where id = 1) then raise exception 'Satılabilecek kamu varlığı kalmadı (kalan % milyar ₺).', round((select kamu_varlik from oyun.ulke where id = 1), 1); end if;
    if exists (select 1 from oyun.kararnameler where tur = 'ozellestirme' and durum = 'yururlukte' and zaman > t - interval '7 days') then
      raise exception 'Özelleştirme 7 günde bir yapılabilir.';
    end if;
    update oyun.ulke set kamu_varlik = kamu_varlik - miktar where id = 1;
    perform oyun.etki_uygula(jsonb_build_object('hazine', miktar, 'issizlik', miktar / 50.0, 'memnuniyet', -miktar / 25.0, 'buyume', miktar / 200.0), null);
    b := format('%s Milyar ₺ Değerinde Kamu Varlığının Özelleştirilmesi Hakkında Karar', miktar);
    p_veri := jsonb_build_object('miktar', miktar);
  elsif p_tur = 'tahvil' then
    -- Borçlanma: para bugün girer, 60 günde faiziyle geri ödenir (faiz enflasyona bağlı)
    miktar := round((p_veri ->> 'miktar')::numeric);
    if miktar is null or miktar < 10 or miktar > 100 then raise exception 'Tahvil ihracı 10-100 milyar ₺ arasında olmalı.'; end if;
    if coalesce((select sum(gunluk * kalan_gun) from oyun.borclar where kalan_gun > 0), 0) + miktar > 300 then
      raise exception 'Toplam borç stoku 300 milyar ₺''yi aşamaz.';
    end if;
    faiz := oyun.tahvil_faiz();
    perform oyun.etki_uygula(jsonb_build_object('hazine', miktar), null);
    b := format('%s Milyar ₺ Devlet İç Borçlanma Senedi (Tahvil) İhracı Hakkında Karar (faiz %%%s, 60 gün)', miktar, faiz);
    p_veri := jsonb_build_object('miktar', miktar, 'faiz', faiz);
  else
    raise exception 'Geçersiz kararname türü.';
  end if;
  v_no := nextval('oyun.kararname_no');
  insert into oyun.kararnameler(no, tur, baslik, metin, veri, cb, zaman) values (v_no, p_tur, b, m, p_veri, p.id, t) returning id into yeni;
  if p_tur = 'duzenleme' then
    perform oyun.duzenleme_uygula(p_veri ->> 'kod', (p_veri ->> 'deger')::numeric, 'kararname', yeni, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('Cumhurbaşkanlığı kararı: %s artık %s. %s', dt.ad, oyun.duz_yaz(dt.kod, deger), dt.oyuncu)
      from oyun.profiller x where not x.yasakli and x.id <> p.id and x.son_gorulme > t - interval '7 days';
  elsif p_tur = 'tahvil' then
    insert into oyun.borclar(kararname_id, anapara, faiz, gunluk, kalan_gun, zaman)
    values (yeni, miktar, faiz, round(miktar * (1 + faiz / 100) / 60, 4), 60, t);
  end if;
  perform oyun.gazete_ekle('kararname', format('%s sayılı Cumhurbaşkanlığı Kararı: %s', v_no, b), m, yeni, t);
  perform oyun.olay('kararname', format('Cumhurbaşkanı %s, %s sayılı kararı imzaladı: %s', p.kad, v_no, b), null, p.parti_id, t);
  return jsonb_build_object('tamam', true, 'no', v_no, 'baslik', b, 'veri', p_veri);
end $$;

create or replace function public.kararnameler(p_limit int default 30) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'no', k.no, 'tur', k.tur, 'baslik', k.baslik, 'metin', k.metin,
           'cb', oyun.kad(k.cb), 'zaman', k.zaman, 'durum', k.durum) order by k.zaman desc, k.no desc), '[]'::jsonb)
  from (select * from oyun.kararnameler order by zaman desc limit least(greatest(p_limit, 1), 100)) k
$$;

-- ---------------------------------------------------------------------
-- KANUN SÜRECİ
--   Teklif (yalnız milletvekili) → 24 saat görüşme → 24 saat oylama
--   Kabul: katılım ≥ dolu sandalyelerin 1/3'ü, kabul > ret ve kabul ≥ dolu/4 + 1
--   → Cumhurbaşkanı 48 saatte onaylar veya veto eder; karar vermezse yürürlüğe girer
--   → Veto edilirse 24 saat ısrar oylaması: dolu sandalyelerin salt çoğunluğu (yarısından fazlası) gerekir
--   Yeni Meclis göreve başlayınca görüşme/oylama/ısrar aşamasındaki teklifler kadük olur.
-- ---------------------------------------------------------------------
create or replace function oyun.kanun_suresi() returns table(gorusme interval, oylama interval, cb interval) language sql immutable as $$
  select interval '24 hours', interval '24 hours', interval '48 hours'
$$;

create or replace function public.kanun_teklif(p_tur text, p_baslik text, p_metin text, p_veri jsonb default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b text; m text; v jsonb; top numeric; k text; yeni bigint; s record; pay numeric;
begin
  if not oyun.aktif_vekil(p.id) then raise exception 'Kanun teklifini yalnızca milletvekilleri verebilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then
    raise exception 'Meclis Başkanı kanun teklifi veremez; tarafsız kalmalıdır.';
  end if;
  if exists (select 1 from oyun.kanunlar where teklif_eden = p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
    raise exception 'Sonuçlanmamış bir teklifin varken yeni teklif veremezsin.';
  end if;
  b := btrim(coalesce(p_baslik, ''));
  if length(b) < 5 or length(b) > 120 then raise exception 'Kanun başlığı 5-120 karakter olmalı.'; end if;
  if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
  m := oyun.metin_temizle(p_metin, 3000);
  if length(m) < 10 then raise exception 'Gerekçe en az 10 karakter olmalı.'; end if;
  if p_tur = 'serbest' then v := null;
  elsif p_tur = 'butce' then
    -- Bütçe kanunu: gelir vergisi bandı (yürütme bu bant içinde ayarlar), belediye payı, partilere hazine yardımı, bakanlık payları.
    -- Verilmeyen alan yürürlükteki değerinde kalır.
    select jsonb_build_object('vergi_alt', round(coalesce((p_veri ->> 'vergi_alt')::numeric, u.vergi_alt), 1),
                              'vergi_ust', round(coalesce((p_veri ->> 'vergi_ust')::numeric, u.vergi_ust), 1),
                              'belediye_payi', round(coalesce((p_veri ->> 'belediye_payi')::numeric, u.belediye_payi), 1),
                              'parti_yardim', round(coalesce((p_veri ->> 'parti_yardim')::numeric, u.parti_yardim)),
                              'paylar', '{}'::jsonb)
      into v from oyun.ulke u where u.id = 1;
    if (v ->> 'vergi_alt')::numeric < 0 or (v ->> 'vergi_ust')::numeric > 45 or (v ->> 'vergi_alt')::numeric > (v ->> 'vergi_ust')::numeric then
      raise exception 'Vergi bandı %%0-%%45 arasında olmalı ve taban tavandan büyük olamaz.';
    end if;
    if (v ->> 'belediye_payi')::numeric not between 2 and 30 then raise exception 'Belediye payı %%2-%%30 arasında olmalı.'; end if;
    if (v ->> 'parti_yardim')::numeric not between 0 and 200000 then raise exception 'Partilere hazine yardımı günlük 0-200.000 ₺ arasında olmalı.'; end if;
    top := 0;
    for k in select kod from oyun.bakanliklar loop
      pay := coalesce((p_veri -> 'paylar' ->> k)::numeric, ((select butce from oyun.ulke where id = 1) ->> k)::numeric, 0);
      if pay < 0 or pay > 60 then raise exception 'Her bakanlığın payı 0-60 arasında olmalı (%).', k; end if;
      top := top + pay;
      v := jsonb_set(v, array['paylar', k], to_jsonb(round(pay, 1)));
    end loop;
    if abs(top - 100) > 0.5 then raise exception 'Bakanlık paylarının toplamı 100 olmalı (şu an %).', round(top, 1); end if;
  elsif p_tur = 'secim' then
    if (p_veri ->> 'baraj') is null or (p_veri ->> 'baraj')::numeric not between 0 and 10 then raise exception 'Baraj %%0-%%10 arasında olmalı.'; end if;
    v := jsonb_build_object('baraj', round((p_veri ->> 'baraj')::numeric, 1));
  elsif p_tur = 'iptal' then
    if not exists (select 1 from oyun.kararnameler where id = (p_veri ->> 'kararname_id')::bigint and durum = 'yururlukte') then
      raise exception 'İptal edilecek yürürlükte bir kararname seçmelisin.';
    end if;
    v := jsonb_build_object('kararname_id', (p_veri ->> 'kararname_id')::bigint);
  elsif p_tur = 'duzenleme' then
    if oyun.duzenleme_engel(p_veri ->> 'kod', 'kanun') is not null then raise exception '%', oyun.duzenleme_engel(p_veri ->> 'kod', 'kanun'); end if;
    v := jsonb_build_object('kod', p_veri ->> 'kod', 'deger', oyun.duzenleme_dogrula(p_veri ->> 'kod', (p_veri ->> 'deger')::numeric, 'ulke'));
    if (v ->> 'deger')::numeric = oyun.duz(v ->> 'kod') and (select kaynak from oyun.duzenlemeler where kod = v ->> 'kod') = 'kanun' then
      raise exception 'Bu kural zaten kanunla bu değerde.';
    end if;
  elsif p_tur = 'anayasa' then
    v := oyun.anayasa_dogrula(p_veri);
  else raise exception 'Geçersiz kanun türü.'; end if;
  if p_tur = 'butce' and (v ->> 'vergi_ust')::numeric > oyun.anayasa_deger('vergi_tavani') then
    raise exception 'Anayasa gelir vergisinin tavanını %%% olarak belirlemiştir; vergi bandı bunun üstüne çıkamaz.', oyun.anayasa_deger('vergi_tavani');
  end if;
  select * into s from oyun.kanun_suresi();
  insert into oyun.kanunlar(tur, baslik, metin, veri, teklif_eden, teklif_parti, teklif_at, oy_bas, oy_bit)
  values (p_tur, b, m, v, p.id, p.parti_id, t, t + s.gorusme, t + s.gorusme + s.oylama) returning id into yeni;
  if p_tur = 'anayasa' then
    insert into oyun.kanun_oylari(kanun_id, asama, vekil, parti_id, oy, zaman) values (yeni, 'imza', p.id, p.parti_id, 'kabul', t);
  end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select m2.user_id, t, case when p_tur = 'anayasa'
             then format('Anayasa değişikliği teklifi: "%s" (%s). Oylamaya geçmesi için vekillerin üçte biri %s''a kadar imza vermeli.', b, p.kad, to_char((t + s.gorusme) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'))
             else format('Yeni kanun teklifi: "%s" (%s). Oylama %s''da başlıyor.', b, p.kad, to_char((t + s.gorusme) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')) end
    from oyun.makamlar m2 where m2.tur = 'mv' and m2.bit is null and m2.user_id <> p.id;
  perform oyun.olay('meclis', format('%s Meclis''e kanun teklifi verdi: %s', p.kad, b), null, p.parti_id, t);
  return jsonb_build_object('id', yeni);
end $$;

create or replace function public.kanun_geri_cek(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  update oyun.kanunlar set durum = 'geri_cekildi', sonuc_at = t, sonuc_metin = 'Teklif sahibi geri çekti.'
  where id = p_id and teklif_eden = p.id and durum = 'gorusmede';
  if not found then raise exception 'Yalnızca görüşme aşamasındaki kendi teklifini geri çekebilirsin.'; end if;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.kanun_oy(p_id bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; a text;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri oy kullanabilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then
    raise exception 'Meclis Başkanı Genel Kurul''da oy kullanamaz (Anayasa md. 94).';
  end if;
  select * into k from oyun.kanunlar where id = p_id;
  if k.durum = 'oylamada' and t >= k.oy_bas and t < k.oy_bit then a := 'ilk';
  elsif k.durum = 'israr' and t < k.israr_bit then a := 'israr';
  else raise exception 'Bu teklif şu anda oylamada değil.'; end if;
  insert into oyun.kanun_oylari(kanun_id, asama, vekil, parti_id, oy, zaman) values (k.id, a, p.id, p.parti_id, p_oy, t)
  on conflict (kanun_id, asama, vekil) do update set oy = excluded.oy, zaman = excluded.zaman, parti_id = excluded.parti_id;
  return public.kanun_detay(p_id);
end $$;

create or replace function public.kanun_cb_karar(p_id bigint, p_karar text, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; s record;
begin
  perform oyun.cb_zorunlu(p);
  select * into k from oyun.kanunlar where id = p_id for update;
  if k.durum <> 'cb_onayinda' or t >= k.cb_bit then raise exception 'Bu kanun onayınızı beklemiyor.'; end if;
  if k.tur = 'anayasa' then
    if p_karar = 'onay' then
      perform oyun.kanun_yururluk(k.id, t, format('Meclis''te üçte iki çoğunlukla kabul edildi; Cumhurbaşkanı %s yayımladı.', p.kad));
    elsif p_karar = 'halkoyu' then
      perform oyun.referandum_baslat(k.id, t);
      perform oyun.olay('referandum', format('Cumhurbaşkanı %s, "%s" anayasa değişikliğini halkoyuna sundu.', p.kad, k.baslik), null, p.parti_id, t);
    else raise exception 'Anayasa değişikliği veto edilemez; yayımlayabilir ya da halkoyuna sunabilirsin.'; end if;
    return public.kanun_detay(p_id);
  end if;
  if p_karar = 'onay' then
    perform oyun.kanun_yururluk(k.id, t, format('Cumhurbaşkanı %s tarafından onaylandı.', p.kad));
  elsif p_karar = 'veto' then
    if coalesce(btrim(p_gerekce), '') = '' then raise exception 'Veto için gerekçe yazmalısın.'; end if;
    select * into s from oyun.kanun_suresi();
    update oyun.kanunlar set durum = 'israr', israr_bit = t + s.oylama, veto_gerekce = oyun.metin_temizle(p_gerekce, 1000) where id = k.id;
    perform oyun.bildir(k.teklif_eden, format('Cumhurbaşkanı "%s" kanununu veto etti. Meclis 24 saat içinde salt çoğunlukla ısrar edebilir.', k.baslik), t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select m.user_id, t, format('Veto: "%s" Meclis''e iade edildi. Israr oylaması 24 saat sürecek.', k.baslik)
      from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.user_id <> k.teklif_eden;
    perform oyun.olay('meclis', format('Cumhurbaşkanı %s, "%s" kanununu veto ederek Meclis''e iade etti.', p.kad, k.baslik), null, p.parti_id, t);
  else raise exception 'Geçersiz karar.'; end if;
  return public.kanun_detay(p_id);
end $$;

-- Kanunun yürürlüğe girmesi ve etkileri
create or replace function oyun.kanun_yururluk(p_id bigint, t timestamptz, p_not text) returns void language plpgsql as $$
declare k oyun.kanunlar; v_no int; kr oyun.kararnameler; pencere boolean;
begin
  select * into k from oyun.kanunlar where id = p_id for update;
  v_no := nextval('oyun.kanun_no');
  update oyun.kanunlar set durum = 'yururlukte', no = v_no, sonuc_at = t, sonuc_metin = p_not where id = k.id;
  if k.tur = 'butce' then
    update oyun.kanunlar set veri = veri || jsonb_build_object('onceki',
      (select jsonb_build_object('vergi_alt', vergi_alt, 'vergi_ust', vergi_ust, 'belediye_payi', belediye_payi, 'parti_yardim', parti_yardim, 'vergi', vergi) from oyun.ulke where id = 1))
    where id = k.id;
    update oyun.ulke set vergi_alt = (k.veri ->> 'vergi_alt')::numeric, vergi_ust = (k.veri ->> 'vergi_ust')::numeric,
      vergi = oyun.sinir(vergi, (k.veri ->> 'vergi_alt')::numeric, (k.veri ->> 'vergi_ust')::numeric),
      belediye_payi = (k.veri ->> 'belediye_payi')::numeric, parti_yardim = (k.veri ->> 'parti_yardim')::numeric,
      butce = k.veri -> 'paylar' where id = 1;
  elsif k.tur = 'secim' then
    -- seçim döneminde kabul edilen baraj o seçime uygulanmaz
    select exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                   where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor') into pencere;
    if pencere then update oyun.ulke set bekleyen_baraj = (k.veri ->> 'baraj')::numeric where id = 1;
    else update oyun.ayarlar set baraj = (k.veri ->> 'baraj')::numeric where id = 1; end if;
  elsif k.tur = 'iptal' then
    update oyun.kararnameler set durum = 'iptal' where id = (k.veri ->> 'kararname_id')::bigint returning * into kr;
    if kr.tur = 'vergi' and not exists (select 1 from oyun.kararnameler where tur = 'vergi' and durum = 'yururlukte' and zaman > kr.zaman) then
      update oyun.ulke set vergi = vergi_kanun where id = 1;
    end if;
    -- iptal edilen kararname hâlâ yürürlükteki kuralı belirliyorsa kural bir önceki hâline döner
    if kr.tur = 'duzenleme' and exists (select 1 from oyun.duzenlemeler where kod = kr.veri ->> 'kod' and kaynak = 'kararname' and ref_id = kr.id) then
      if kr.veri -> 'onceki' ->> 'kaynak' is null then delete from oyun.duzenlemeler where kod = kr.veri ->> 'kod';
      else update oyun.duzenlemeler set deger = (kr.veri -> 'onceki' ->> 'deger')::numeric, kaynak = kr.veri -> 'onceki' ->> 'kaynak',
             ref_id = (kr.veri -> 'onceki' ->> 'ref_id')::bigint, zaman = t where kod = kr.veri ->> 'kod'; end if;
    end if;
  elsif k.tur = 'duzenleme' then
    if not oyun.duzenleme_uygula(k.veri ->> 'kod', (k.veri ->> 'deger')::numeric, 'kanun', k.id, t) then
      update oyun.kanunlar set sonuc_metin = p_not || ' Ancak kural bu arada anayasaya bağlandığı için uygulanamadı.' where id = k.id;
    end if;
  elsif k.tur = 'anayasa' then
    perform oyun.anayasa_uygula(k, t);
  end if;
  perform oyun.gazete_ekle(case when k.tur = 'anayasa' then 'anayasa' else 'kanun' end,
    format('%s sayılı %s', v_no, k.baslik), coalesce(case when k.tur = 'anayasa' then oyun.anayasa_aciklama(k.veri) || ' ' end, '') || k.metin, k.id, t);
  perform oyun.bildir(k.teklif_eden, format('Teklifin yasalaştı: %s sayılı "%s" yürürlüğe girdi.', v_no, k.baslik), t);
  perform oyun.olay('meclis', format('%s sayılı "%s" yürürlüğe girdi. %s', v_no, k.baslik, p_not), null, k.teklif_parti, t);
end $$;

create or replace function oyun.kanun_say(p_id bigint, p_asama text) returns table(kabul int, ret int, cekimser int) language sql stable as $$
  select count(*) filter (where oy = 'kabul')::int, count(*) filter (where oy = 'ret')::int, count(*) filter (where oy = 'cekimser')::int
  from oyun.kanun_oylari where kanun_id = p_id and asama = p_asama
$$;

create or replace function oyun.kanun_tick(t timestamptz) returns void language plpgsql as $$
declare k oyun.kanunlar; c record; dolu int; cb uuid; s record;
begin
  select * into s from oyun.kanun_suresi();
  -- anayasa değişikliği: görüşme bitince imza sayısı dolu sandalyelerin üçte birine ulaşmadıysa teklif düşer
  for k in select * from oyun.kanunlar where durum = 'gorusmede' and tur = 'anayasa' and t >= oy_bas order by oy_bas loop
    dolu := oyun.dolu_sandalye();
    if (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza') < ceil(dolu / 3.0) then
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bas,
        sonuc_metin = format('Yeterli imza toplanamadı: %s imza, en az %s gerekliydi (dolu sandalyelerin üçte biri).',
                             (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza'), ceil(dolu / 3.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin yeterli imza toplayamadı.', k.baslik), k.oy_bas);
    end if;
  end loop;
  update oyun.kanunlar set durum = 'oylamada' where durum = 'gorusmede' and t >= oy_bas;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur = 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    cb := oyun.aktif_cb();
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then
      update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
        sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: üçte iki çoğunluk sağlandı.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.bildir(cb, format('"%s" anayasa değişikliği Meclis''ten üçte iki çoğunlukla geçti. 48 saat içinde yayımla ya da halkoyuna sun.', k.baslik), k.oy_bit);
      perform oyun.olay('meclis', format('"%s" anayasa değişikliği üçte iki çoğunlukla kabul edildi (%s kabul). Cumhurbaşkanına sunuldu.', k.baslik, c.kabul), null, k.teklif_parti, k.oy_bit);
    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      update oyun.kanunlar set sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.referandum_baslat(k.id, k.oy_bit);
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = format('Reddedildi: gizli oylamada %s kabul oyu çıktı; halkoyuna sunulması için en az %s (beşte üç) gerekliydi.', c.kabul, ceil(dolu * 3 / 5.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin Meclis''te gerekli çoğunluğu alamadı.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur <> 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul + c.ret + c.cekimser >= ceil(dolu / 3.0) and c.kabul > c.ret and c.kabul >= floor(dolu / 4.0) + 1 then
      cb := oyun.aktif_cb();
      if cb is null then
        perform oyun.kanun_yururluk(k.id, k.oy_bit, format('Meclis''te %s kabul, %s ret oyla kabul edildi (cumhurbaşkanı makamı boş).', c.kabul, c.ret));
      else
        update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
          sonuc_metin = format('Meclis''te %s kabul, %s ret, %s çekimser oyla kabul edildi.', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.bildir(cb, format('"%s" kanunu Meclis''ten geçti ve onayınızı bekliyor. 48 saat içinde onaylayın ya da veto edin.', k.baslik), k.oy_bit);
        perform oyun.olay('meclis', format('"%s" Meclis''te kabul edildi (%s kabul, %s ret). Cumhurbaşkanının onayına sunuldu.', k.baslik, c.kabul, c.ret), null, k.teklif_parti, k.oy_bit);
      end if;
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = case when c.kabul + c.ret + c.cekimser < ceil(dolu / 3.0) then format('Toplantı yeter sayısı sağlanamadı (%s vekil katıldı, en az %s gerekliydi).', c.kabul + c.ret + c.cekimser, ceil(dolu / 3.0))
                           else format('Reddedildi: %s kabul, %s ret, %s çekimser (kabul için en az %s ve retten fazla oy gerekliydi).', c.kabul, c.ret, c.cekimser, floor(dolu / 4.0) + 1) end
      where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" teklifin Meclis''te kabul edilmedi.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'cb_onayinda' and t >= cb_bit order by cb_bit loop
    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = 'anayasa' then 'Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.'
                                                    else 'Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.' end);
  end loop;
  for k in select * from oyun.kanunlar where durum = 'israr' and t >= israr_bit order by israr_bit loop
    select * into c from oyun.kanun_say(k.id, 'israr');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul >= floor(dolu / 2.0) + 1 then
      perform oyun.kanun_yururluk(k.id, k.israr_bit, format('Veto sonrası Meclis %s oyla ısrar etti.', c.kabul));
    else
      update oyun.kanunlar set durum = 'dustu', sonuc_at = k.israr_bit,
        sonuc_metin = format('Veto sonrası ısrar için %s oy gerekiyordu, %s kabul oyu çıktı. Kanun düştü.', floor(dolu / 2.0) + 1, c.kabul) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" veto sonrası ısrar oylamasında düştü.', k.baslik), k.israr_bit);
    end if;
  end loop;
  -- seçim döneminde kabul edilen baraj, seçim bitince uygulanır
  if (select bekleyen_baraj from oyun.ulke where id = 1) is not null
     and not exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                     where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor') then
    update oyun.ayarlar set baraj = (select bekleyen_baraj from oyun.ulke where id = 1) where id = 1;
    update oyun.ulke set bekleyen_baraj = null where id = 1;
  end if;
end $$;

-- Yeni Meclis göreve başlayınca sonuçlanmamış teklifler kadük olur
create or replace function oyun.kanunlar_kaduk(t timestamptz) returns void language sql as $$
  update oyun.kanunlar set durum = 'kaduk', sonuc_at = t, sonuc_metin = 'Yasama dönemi sona erdiği için kadük oldu.'
  where durum in ('gorusmede','oylamada','israr')
$$;

create or replace function oyun.kanun_ozet(k oyun.kanunlar, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', k.id, 'no', k.no, 'tur', k.tur, 'baslik', k.baslik, 'durum', k.durum,
    'teklif_eden', oyun.kad(k.teklif_eden), 'parti', oyun.parti_json(k.teklif_parti),
    'teklif_at', k.teklif_at, 'oy_bas', k.oy_bas, 'oy_bit', k.oy_bit, 'cb_bit', k.cb_bit, 'israr_bit', k.israr_bit, 'sonuc_at', k.sonuc_at,
    'oy_verdim', exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = p.id
                          and o.asama = case when k.durum = 'israr' then 'israr' else 'ilk' end))
$$;

create or replace function public.kanunlar(p_limit int default 40) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(oyun.kanun_ozet(k, p, t) order by
            (k.durum in ('gorusmede','oylamada','cb_onayinda','israr')) desc, k.teklif_at desc)
          from (select * from oyun.kanunlar order by teklif_at desc limit least(greatest(p_limit, 1), 100)) k), '[]'::jsonb);
end $$;

create or replace function public.kanun_detay(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; dolu int := oyun.dolu_sandalye();
begin
  select * into k from oyun.kanunlar where id = p_id;
  if k.id is null then raise exception 'Kanun bulunamadı.'; end if;
  return oyun.kanun_ozet(k, p, t) || jsonb_build_object(
    'metin', k.metin, 'veri', k.veri, 'veto_gerekce', k.veto_gerekce, 'sonuc_metin', k.sonuc_metin,
    'kararname', case when k.tur = 'iptal' then (select jsonb_build_object('no', no, 'baslik', baslik) from oyun.kararnameler where id = (k.veri ->> 'kararname_id')::bigint) end,
    'dolu', dolu, 'toplanti_yeter', ceil(dolu / 3.0), 'karar_yeter', floor(dolu / 4.0) + 1, 'israr_yeter', floor(dolu / 2.0) + 1,
    'vekilim', oyun.aktif_vekil(p.id),
    'oy_acik', (k.durum = 'oylamada' and t >= k.oy_bas and t < k.oy_bit) or (k.durum = 'israr' and t < k.israr_bit),
    'benim_oyum', (select oy from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = case when k.durum = 'israr' then 'israr' else 'ilk' end),
    'cb_karar_verebilir', k.durum = 'cb_onayinda' and t < k.cb_bit and oyun.aktif_cb() = p.id,
    'anayasa_aciklama', case when k.tur = 'anayasa' then oyun.anayasa_aciklama(k.veri) end,
    'grup', oyun.grup_karar_json(k.id, p), 'tbmm_baskani', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null),
    'duzenleme', case when k.tur = 'duzenleme' then (select jsonb_build_object('ad', d.ad, 'yazi', oyun.duz_yaz(d.kod, (k.veri ->> 'deger')::numeric),
                    'mevcut', oyun.duz_yaz(d.kod, oyun.duz(d.kod)), 'oyuncu', d.oyuncu, 'devlet', d.devlet) from oyun.duzenleme_tanim d where d.kod = k.veri ->> 'kod') end,
    'imza_yeter', ceil(dolu / 3.0), 'uc_bes', ceil(dolu * 3 / 5.0), 'iki_uc', ceil(dolu * 2 / 3.0),
    'imzaladim', exists (select 1 from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = 'imza'),
    'referandum', (select jsonb_build_object('id', r.id, 'oy_bas', r.oy_bas, 'durum', r.durum, 'sonuc', r.sonuc) from oyun.referandumlar r where r.kanun_id = k.id),
    'benim', k.teklif_eden = p.id,
    'oylar', (select jsonb_object_agg(a.asama, a.j) from (
       select o.asama, jsonb_build_object(
         'kabul', count(*) filter (where o.oy = 'kabul'), 'ret', count(*) filter (where o.oy = 'ret'), 'cekimser', count(*) filter (where o.oy = 'cekimser'),
         'liste', case when k.tur = 'anayasa' and o.asama = 'ilk' then '[]'::jsonb
                       else jsonb_agg(jsonb_build_object('kad', oyun.kad(o.vekil), 'oy', o.oy, 'parti', oyun.parti_json(o.parti_id),
                              'aykiri', o.asama <> 'imza' and exists (select 1 from oyun.grup_kararlari g where g.kanun_id = k.id and g.parti_id = o.parti_id
                                                                         and g.karar in ('kabul','ret') and g.karar <> o.oy)) order by o.parti_id, o.zaman) end) j
       from oyun.kanun_oylari o where o.kanun_id = k.id group by o.asama) a));
end $$;

-- ---------------------------------------------------------------------
-- İTTİFAKLAR
--   Genel başkanlar kurar, davet eder, kabul eder, ayrılır.
--   Genel seçim döneminde (26'sından genel seçim sonucuna kadar) değişiklik yapılamaz.
-- ---------------------------------------------------------------------
create or replace function oyun.ittifak_kilit(t timestamptz) returns text language sql stable as $$
  select 'Genel seçim döneminde (aday adaylığı başvurusundan seçim sonucuna kadar) ittifaklarda değişiklik yapılamaz.'
  where exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor')
$$;

create or replace function oyun.gb_partim(p oyun.profiller) returns oyun.partiler language plpgsql stable as $$
declare pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p.parti_id and gb = p.id and not kapali;
  if pa.id is null then raise exception 'Bu işlemi yalnızca partinin genel başkanı yapabilir.'; end if;
  return pa;
end $$;

create or replace function oyun.ittifak_temizle() returns void language sql as $$
  delete from oyun.ittifak_uyeler where parti_id in (select id from oyun.partiler where kapali);
  delete from oyun.ittifak_davetler where parti_id in (select id from oyun.partiler where kapali);
  delete from oyun.ittifaklar i where not exists (select 1 from oyun.ittifak_uyeler u where u.ittifak_id = i.id);
$$;

create or replace function public.ittifak_bilgi(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); iid bigint;
begin
  select ittifak_id into iid from oyun.ittifak_uyeler where parti_id = p_parti;
  return jsonb_build_object(
    'kilit', oyun.ittifak_kilit(t),
    'ittifak', case when iid is null then null else (select jsonb_build_object('id', i.id, 'ad', i.ad, 'kurulus', i.kurulus,
        'uyeler', (select jsonb_agg(oyun.parti_json(u.parti_id) order by u.parti_id) from oyun.ittifak_uyeler u where u.ittifak_id = i.id),
        'davetler', coalesce((select jsonb_agg(oyun.parti_json(d.parti_id)) from oyun.ittifak_davetler d where d.ittifak_id = i.id), '[]'::jsonb))
      from oyun.ittifaklar i where i.id = iid) end,
    'gelen_davetler', coalesce((select jsonb_agg(jsonb_build_object('ittifak_id', i.id, 'ad', i.ad,
        'uyeler', (select jsonb_agg(oyun.parti_json(u.parti_id)) from oyun.ittifak_uyeler u where u.ittifak_id = i.id)))
      from oyun.ittifak_davetler d join oyun.ittifaklar i on i.id = d.ittifak_id where d.parti_id = p_parti), '[]'::jsonb),
    'gb_benim', exists (select 1 from oyun.partiler where id = p_parti and gb = p.id));
end $$;

create or replace function public.ittifak_kur(p_ad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; ad text; kl text; yeni bigint;
begin
  pa := oyun.gb_partim(p);
  kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
  if exists (select 1 from oyun.ittifak_uyeler where parti_id = pa.id) then raise exception 'Partin zaten bir ittifakta.'; end if;
  ad := btrim(regexp_replace(coalesce(p_ad, ''), '\s+', ' ', 'g'));
  if length(ad) < 4 or length(ad) > 40 then raise exception 'İttifak adı 4-40 karakter olmalı.'; end if;
  if oyun.yasakli_ad(ad) or oyun.sade(ad) like any (array['%cumhurittifak%','%millet ittifak%','%millettifak%','%emekveozgurluk%']) then
    raise exception 'Gerçek ittifakları çağrıştıran veya uygunsuz adlar kullanılamaz.';
  end if;
  insert into oyun.ittifaklar(ad, kurulus, kurucu_parti) values (ad, t, pa.id) returning id into yeni;
  insert into oyun.ittifak_uyeler(ittifak_id, parti_id) values (yeni, pa.id);
  perform oyun.olay('ittifak', format('%s, %s adıyla yeni bir ittifak kurdu.', pa.kisa, ad), null, pa.id, t);
  return public.ittifak_bilgi(pa.id);
end $$;

create or replace function public.ittifak_davet(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; hedef oyun.partiler; iid bigint; kl text;
begin
  pa := oyun.gb_partim(p);
  kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
  select ittifak_id into iid from oyun.ittifak_uyeler where parti_id = pa.id;
  if iid is null then raise exception 'Önce bir ittifak kurmalısın.'; end if;
  select * into hedef from oyun.partiler where id = p_parti and not kapali;
  if hedef.id is null or hedef.id = pa.id then raise exception 'Geçersiz parti.'; end if;
  if exists (select 1 from oyun.ittifak_uyeler where parti_id = hedef.id) then raise exception '% zaten bir ittifakta.', hedef.kisa; end if;
  insert into oyun.ittifak_davetler(ittifak_id, parti_id, zaman) values (iid, hedef.id, t) on conflict do nothing;
  if hedef.gb is not null then
    perform oyun.bildir(hedef.gb, format('%s, partini %s ittifakına davet etti. Parti sayfasından yanıtlayabilirsin.', pa.kisa, (select ad from oyun.ittifaklar where id = iid)), t);
  end if;
  return public.ittifak_bilgi(pa.id);
end $$;

create or replace function public.ittifak_davet_yanit(p_ittifak bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; kl text; iad text;
begin
  pa := oyun.gb_partim(p);
  if not exists (select 1 from oyun.ittifak_davetler where ittifak_id = p_ittifak and parti_id = pa.id) then raise exception 'Böyle bir davet yok.'; end if;
  select ad into iad from oyun.ittifaklar where id = p_ittifak;
  if p_kabul then
    kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
    if exists (select 1 from oyun.ittifak_uyeler where parti_id = pa.id) then raise exception 'Partin zaten bir ittifakta; önce ayrılmalısın.'; end if;
    insert into oyun.ittifak_uyeler(ittifak_id, parti_id) values (p_ittifak, pa.id);
    delete from oyun.ittifak_davetler where parti_id = pa.id;
    perform oyun.olay('ittifak', format('%s, %s adlı ittifaka katıldı.', pa.kisa, iad), null, pa.id, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.gb, t, format('%s ittifakınıza katıldı.', pa.kisa) from oyun.ittifak_uyeler u join oyun.partiler x on x.id = u.parti_id
      where u.ittifak_id = p_ittifak and x.gb is not null and x.id <> pa.id;
  else
    delete from oyun.ittifak_davetler where ittifak_id = p_ittifak and parti_id = pa.id;
  end if;
  return public.ittifak_bilgi(pa.id);
end $$;

create or replace function public.ittifak_ayril() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; kl text; iid bigint; iad text;
begin
  pa := oyun.gb_partim(p);
  kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
  delete from oyun.ittifak_uyeler where parti_id = pa.id returning ittifak_id into iid;
  if iid is null then raise exception 'Partin bir ittifakta değil.'; end if;
  select ad into iad from oyun.ittifaklar where id = iid;
  -- ittifak ortağını destekleme kararı varsa düşer
  delete from oyun.cb_kararlar k where k.parti_id = pa.id and k.yontem = 'destek'
    and exists (select 1 from oyun.secimler s where s.tur = 'cb' and s.donem = k.donem and s.durum = 'bekliyor');
  perform oyun.ittifak_temizle();
  perform oyun.olay('ittifak', format('%s, %s adlı ittifaktan ayrıldı.', pa.kisa, iad), null, pa.id, t);
  return public.ittifak_bilgi(pa.id);
end $$;

-- Cumhurbaşkanlığında kendi adayını çıkarmak yerine ittifak ortağının adayını destekle
create or replace function public.cb_destek(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; hedef oyun.partiler;
begin
  pa := oyun.gb_partim(p);
  select * into s from oyun.secimler where tur = 'cb' and t >= basvuru_bas and t < basvuru_bit;
  if s.id is null then raise exception 'Cumhurbaşkanı adayı kararı ayın 19''u ile 25''i arasında verilir.'; end if;
  select * into hedef from oyun.partiler where id = p_parti and not kapali;
  if hedef.id is null or hedef.id = pa.id then raise exception 'Geçersiz parti.'; end if;
  if not exists (select 1 from oyun.ittifak_uyeler a join oyun.ittifak_uyeler b on a.ittifak_id = b.ittifak_id
                 where a.parti_id = pa.id and b.parti_id = hedef.id) then
    raise exception 'Yalnızca ittifak ortağının adayını destekleyebilirsin.';
  end if;
  insert into oyun.cb_kararlar(donem, parti_id, yontem, aday, destek_parti, zaman) values (s.donem, pa.id, 'destek', null, hedef.id, t)
  on conflict (donem, parti_id) do update set yontem = 'destek', aday = null, destek_parti = excluded.destek_parti, zaman = excluded.zaman;
  delete from oyun.adaylar where secim_id = s.id and parti_id = pa.id;
  perform oyun.olay('ittifak', format('%s, cumhurbaşkanlığı seçiminde %s''nin adayını destekleme kararı aldı.', pa.kisa, hedef.kisa), null, pa.id, t);
  return public.durum();
end $$;

-- Harita: il gelişmişliği eklendi (03'teki tanımın yerine geçer)
create or replace function public.harita() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id, 'ad', i.ad, 'mv', i.mv,
    'oyuncu', (select count(*) from oyun.profiller pr where pr.il_id = i.id),
    'gelisim', (select round(gelisim, 1) from oyun.il_durum d where d.il_id = i.id),
    'bel', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id))
            from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1),
    'vekil', (select coalesce(jsonb_agg(jsonb_build_object('parti_id', x.parti_id, 'renk', pa.renk, 'kisa', pa.kisa, 'n', x.n) order by x.n desc), '[]'::jsonb)
              from (select parti_id, count(*) n from oyun.makamlar m where m.tur = 'mv' and m.il_id = i.id and m.bit is null group by parti_id) x
              join oyun.partiler pa on pa.id = x.parti_id)
  ) order by i.id), '[]'::jsonb)
  from oyun.iller i
$$;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 8) 3. AŞAMA
--  Belediye projeleri · seçim bildirgesi (vaat) · rozetler ·
--  yönetici paneli · push bildirim kuyruğu ve cihaz kaydı
-- =====================================================================

alter table oyun.ayarlar add column if not exists push_aktif boolean not null default false;
alter table oyun.ayarlar add column if not exists push_url   text;   -- https://<proje>.supabase.co/functions/v1/push-gonder
alter table oyun.ayarlar add column if not exists push_gizli text;   -- sunucu fonksiyonuyla paylaşılan gizli anahtar

-- =====================================================================
--  BELEDİYE
--  Gelir (günlük): ilin taban geliri (0,02 + 0,004 × vekil sayısı milyar ₺) × fiyat düzeyi
--                  × gelişmişlik (0,5 + gelişim/100) × (öz gelir + kanundaki belediye payı) × (1 + kent vergisi/10)
--  Gider (günlük): açık hizmetlerin işletme gideri + hemşehri desteği
--  Belediye başkanı: kent vergisini (%0-5) ve hemşehri desteğini belirler, hizmet açar/kapar, yatırım yapar.
--  Kasa eksiye düşecekse hizmetler kapanır (en pahalıdan başlayarak) ve başkana bildirim gider.
-- =====================================================================
create table if not exists oyun.belediye_hizmetleri(
  kod text primary key, ad text not null, aciklama text not null,
  oran numeric not null,          -- günlük işletme gideri: ilin taban gelirinin bu oranı
  etki jsonb not null,            -- oyuncu etkileri [{tur, deger}]
  sira int not null
);
insert into oyun.belediye_hizmetleri(kod, ad, aciklama, oran, etki, sira) values
 ('lokanta','Kent lokantası','Uygun fiyatlı sıcak yemek: ildeki herkesin geçim masrafı %15 düşer.',0.12,'[{"tur":"gecim","deger":15}]',1),
 ('ulasim','Ücretsiz toplu ulaşım','Otobüs ve metro bedava: geçim masrafı %10 düşer, bu ile/bu ilden taşınmak yarı fiyat.',0.10,'[{"tur":"gecim","deger":10},{"tur":"tasinma","deger":50}]',2),
 ('kira','Sosyal konut ve kira yardımı','Kira desteği ve uygun konut: geçim masrafı %20 düşer.',0.18,'[{"tur":"gecim","deger":20}]',3),
 ('istihdam','Belediye istihdam ofisi','İş ve meslek eşleştirme: ildeki maaşlar %10 artar.',0.15,'[{"tur":"ucret","deger":10}]',4)
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, oran = excluded.oran, etki = excluded.etki, sira = excluded.sira;

create table if not exists oyun.belediye_yatirimlari(
  kod text primary key, ad text not null, aciklama text not null,
  gun numeric not null, bekleme_saat int not null, gelisim numeric not null, memnuniyet numeric not null, sira int not null
);
insert into oyun.belediye_yatirimlari(kod, ad, aciklama, gun, bekleme_saat, gelisim, memnuniyet, sira) values
 ('altyapi','Yol ve altyapı yenileme','Su, kanalizasyon, asfalt: ilin gelişmişliği kalıcı +4 (maaşlar ve belediye geliri artar).',8,72,4,1,1),
 ('rayli','Raylı sistem hattı','Tramvay ya da metro: ilin gelişmişliği kalıcı +10.',20,168,10,3,2)
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, gun = excluded.gun, bekleme_saat = excluded.bekleme_saat,
  gelisim = excluded.gelisim, memnuniyet = excluded.memnuniyet, sira = excluded.sira;

create table if not exists oyun.il_hizmet(
  il_id smallint not null references oyun.iller(id), kod text not null references oyun.belediye_hizmetleri(kod),
  acilis timestamptz not null, primary key (il_id, kod)
);
create table if not exists oyun.belediye_proje_kayit(
  id bigserial primary key, kod text not null, il_id smallint not null, baskan uuid not null, zaman timestamptz not null, maliyet numeric not null
);
create index if not exists bel_proje_il on oyun.belediye_proje_kayit(il_id, zaman desc);
drop function if exists public.belediye_proje(text);
drop table if exists oyun.belediye_projeleri cascade;  -- eski bel_maliyet() da gider

create or replace function oyun.il_sakin(p_il smallint, t timestamptz) returns int language sql stable as $$
  select count(*)::int from oyun.profiller where il_id = p_il and not yasakli and son_gorulme > t - interval '3 days'
$$;
create or replace function oyun.hizmet_gider(p_il smallint, p_kod text) returns numeric language sql stable as $$
  select round(h.oran * oyun.il_gunluk_gelir(i.mv) * u.endeks, 4)
  from oyun.belediye_hizmetleri h, oyun.iller i, oyun.ulke u where h.kod = p_kod and i.id = p_il and u.id = 1
$$;
-- Hemşehri desteğinin günlük bütçe yükü: tutar × ildeki yardım alan hane (5 milyon × vekil payı)
create or replace function oyun.hemsehri_gider(p_il smallint, p_tutar numeric) returns numeric language sql stable as $$
  select round(p_tutar * oyun.nufus('il_hane') * i.mv / 600 / 1e9, 4) from oyun.iller i where i.id = p_il
$$;
create or replace function oyun.il_gider(p_il smallint) returns numeric language sql stable as $$
  select coalesce((select sum(oyun.hizmet_gider(p_il, h.kod)) from oyun.il_hizmet h where h.il_id = p_il), 0)
       + oyun.hemsehri_gider(p_il, (select hemsehri from oyun.il_durum where il_id = p_il))
$$;
-- Belediyenin harcayabileceği günlük alan: günlük net + kasanın 30'da biri
create or replace function oyun.il_mali_alan(p_il smallint) returns numeric language sql stable as $$
  select round(greatest(0, oyun.il_gelir(p_il) - oyun.il_gider(p_il)) + greatest(0, d.kasa) / 30, 4) from oyun.il_durum d where d.il_id = p_il
$$;

-- Her gece: gelir girer, gider düşer; para yetmezse hizmetler kapanır
create or replace function oyun.belediye_gunluk(t timestamptz) returns void language plpgsql as $$
declare r record; h record; v_kasa numeric; bas uuid;
begin
  for r in select d.il_id, i.ad, i.mv from oyun.il_durum d join oyun.iller i on i.id = d.il_id loop
    update oyun.il_durum set kasa = least(60 * oyun.il_gelir(r.il_id), coalesce(kasa, 0) + oyun.il_gelir(r.il_id)) - oyun.il_gider(r.il_id)
     where il_id = r.il_id returning kasa into v_kasa;
    if v_kasa < 0 then
      bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
      update oyun.il_durum set hemsehri = 0 where il_id = r.il_id and hemsehri > 0;
      for h in select k.kod, b.ad from oyun.il_hizmet k join oyun.belediye_hizmetleri b on b.kod = k.kod
               where k.il_id = r.il_id order by b.oran desc loop
        exit when (select kasa from oyun.il_durum where il_id = r.il_id) >= 0;
        delete from oyun.il_hizmet where il_id = r.il_id and kod = h.kod;
        update oyun.il_durum set kasa = kasa + oyun.hizmet_gider(r.il_id, h.kod) where il_id = r.il_id;
        perform oyun.olay('belediye', format('%s Belediyesi kasası yetmediği için %s hizmetini kapattı.', r.ad, h.ad), r.il_id, null, t);
      end loop;
      if bas is not null then perform oyun.bildir(bas, 'Belediye kasası eksiye düştü: hemşehri desteği durduruldu, gerekirse hizmetler kapatıldı.', t); end if;
      update oyun.il_durum set kasa = greatest(kasa, 0) where il_id = r.il_id;
    end if;
  end loop;
  -- gelişmişlik yatırım almazsa yavaşça ortalamaya döner; memnuniyet hizmetlere, desteğe ve vergiye göre şekillenir
  update oyun.il_durum d set gelisim = gelisim + (50 - gelisim) * 0.01,
    memnuniyet = oyun.sinir(memnuniyet + (50 + 4 * (select count(*) from oyun.il_hizmet ih where ih.il_id = d.il_id) + least(10, hemsehri / 30)
                                          - kent_vergisi * 2 - oyun.il_duz(d.il_id, 'emlak') / 30 - memnuniyet) * 0.05, 0, 100);
end $$;

create or replace function oyun.il_hizmet_json(p_il smallint, t timestamptz) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(x order by x ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '1' || b.sira, 'kaynak', b.ad, 'kod', b.kod, 'tur', 'belediye', 'bas', h.acilis, 'etkiler', b.etki) x
      from oyun.il_hizmet h join oyun.belediye_hizmetleri b on b.kod = h.kod where h.il_id = p_il
    union all
    select jsonb_build_object('sira', '2', 'kaynak', e.kaynak_ad, 'kod', e.kaynak_kod, 'tur', 'bakanlik', 'bit', max(e.bit),
                              'etkiler', jsonb_agg(jsonb_build_object('tur', e.tur, 'deger', e.deger)))
      from oyun.etkiler e where e.il_id = p_il and e.bas <= t and e.bit > t group by e.kaynak_ad, e.kaynak_kod
  ) y
$$;

create or replace function public.belediye_paneli() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; i oyun.iller; d oyun.il_durum;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null;
  if m.id is null then return null; end if;
  select * into i from oyun.iller where id = m.il_id;
  select * into d from oyun.il_durum where il_id = m.il_id;
  return jsonb_build_object('il_id', i.id, 'il_ad', i.ad, 'kasa', round(d.kasa, 3),
    'gelir', oyun.il_gelir(i.id), 'gider', oyun.il_gider(i.id), 'mali_alan', oyun.il_mali_alan(i.id),
    'taban', round(oyun.il_gunluk_gelir(i.mv), 3),
    'gelisim', round(d.gelisim, 1), 'memnuniyet', round(d.memnuniyet, 1), 'il_carpan', oyun.il_carpan(i.id),
    'kent_vergisi', d.kent_vergisi, 'hemsehri', d.hemsehri, 'hemsehri_birim', oyun.hemsehri_gider(i.id, 1),
    'ayar_hazir', case when d.son_ayar > t - interval '24 hours' then d.son_ayar + interval '24 hours' end,
    'sakin', (select count(*) from oyun.profiller where il_id = i.id and not yasakli), 'aktif_sakin', oyun.il_sakin(i.id, t),
    'maas', round(oyun.makam_maasi('bel', i.id)),
    'vaatler', oyun.vaat_listesi_makam(m.id),
    'kurallar', oyun.il_kurallar_json(i.id, t),
    'hizmetler', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'aciklama', b.aciklama, 'etki', b.etki,
                    'gider', oyun.hizmet_gider(i.id, b.kod), 'acik', h.il_id is not null, 'acilis', h.acilis) order by b.sira)
                  from oyun.belediye_hizmetleri b left join oyun.il_hizmet h on h.il_id = i.id and h.kod = b.kod),
    'yatirimlar', (select jsonb_agg(jsonb_build_object('kod', y.kod, 'ad', y.ad, 'aciklama', y.aciklama, 'gelisim', y.gelisim, 'tur', y.tur, 'memnuniyet', y.memnuniyet, 'bekleme_saat', y.bekleme_saat,
                    'maliyet', round(y.gun * oyun.il_gunluk_gelir(i.mv) * (select endeks from oyun.ulke where id = 1), 3), 'gun', y.gun,
                    'hazir', (select max(k.zaman) + make_interval(hours => y.bekleme_saat) from oyun.belediye_proje_kayit k where k.kod = y.kod and k.il_id = i.id))
                  order by y.sira) from oyun.belediye_yatirimlari y),
    'son', coalesce((select jsonb_agg(jsonb_build_object('ad', k.ad, 'zaman', k.zaman, 'baskan', oyun.kad(k.baskan)) order by k.zaman desc)
                     from (select x.*, coalesce(b.ad, y.ad) ad from oyun.belediye_proje_kayit x
                           left join oyun.belediye_hizmetleri b on b.kod = x.kod left join oyun.belediye_yatirimlari y on y.kod = x.kod
                           where x.il_id = i.id order by x.zaman desc limit 10) k), '[]'::jsonb));
end $$;

create or replace function oyun.baskan_zorunlu(p oyun.profiller) returns oyun.makamlar language plpgsql as $$
declare m oyun.makamlar;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null;
  if m.id is null then raise exception 'Bu yetki yalnızca görevdeki il belediye başkanlarındadır.'; end if;
  return m;
end $$;

-- Hizmet aç / kapat. Açmak için kasada en az 3 günlük işletme gideri olmalı.
create or replace function public.belediye_hizmet(p_kod text, p_acik boolean) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); b oyun.belediye_hizmetleri; ilad text; gider numeric;
begin
  select * into b from oyun.belediye_hizmetleri where kod = p_kod;
  if b.kod is null then raise exception 'Hizmet bulunamadı.'; end if;
  select ad into ilad from oyun.iller where id = m.il_id;
  if p_acik then
    if exists (select 1 from oyun.il_hizmet where il_id = m.il_id and kod = b.kod) then raise exception 'Bu hizmet zaten açık.'; end if;
    gider := oyun.hizmet_gider(m.il_id, b.kod);
    if (select kasa from oyun.il_durum where il_id = m.il_id) < 3 * gider then
      raise exception 'Açmak için kasada en az 3 günlük işletme gideri (% milyar ₺) olmalı.', round(3 * gider, 3);
    end if;
    insert into oyun.il_hizmet(il_id, kod, acilis) values (m.il_id, b.kod, t);
    insert into oyun.belediye_proje_kayit(kod, il_id, baskan, zaman, maliyet) values (b.kod, m.il_id, p.id, t, gider);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('%s Belediyesi %s hizmetini başlattı. %s', ilad, b.ad, b.aciklama)
      from oyun.profiller x where x.il_id = m.il_id and x.id <> p.id and not x.yasakli;
    perform oyun.olay('belediye', format('%s Belediye Başkanı %s: %s hizmeti başladı.', ilad, p.kad, b.ad), m.il_id, p.parti_id, t);
  else
    delete from oyun.il_hizmet where il_id = m.il_id and kod = b.kod;
    if not found then raise exception 'Bu hizmet zaten kapalı.'; end if;
    perform oyun.olay('belediye', format('%s Belediye Başkanı %s, %s hizmetini kapattı.', ilad, p.kad, b.ad), m.il_id, p.parti_id, t);
  end if;
  return public.belediye_paneli();
end $$;

create or replace function public.belediye_yatirim(p_kod text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); y oyun.belediye_yatirimlari;
        maliyet numeric; son timestamptz; v_kasa numeric; ilad text;
begin
  select * into y from oyun.belediye_yatirimlari where kod = p_kod;
  if y.kod is null then raise exception 'Yatırım bulunamadı.'; end if;
  select ad into ilad from oyun.iller where id = m.il_id;
  maliyet := round(y.gun * oyun.il_gunluk_gelir((select mv from oyun.iller where id = m.il_id)) * (select endeks from oyun.ulke where id = 1), 3);
  select max(zaman) into son from oyun.belediye_proje_kayit where kod = y.kod and il_id = m.il_id;
  if son is not null and son + make_interval(hours => y.bekleme_saat) > t then
    raise exception 'Bu yatırım % tarihinden sonra tekrar yapılabilir.', to_char((son + make_interval(hours => y.bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  select kasa into v_kasa from oyun.il_durum where il_id = m.il_id for update;
  if y.kod = 'arsa_satisi' then
    -- arsa doğrudan satılmaz: ihaleye çıkar, kasa ve etkiler ihale sonucunda işlenir
    perform oyun.arsa_ihale_ac(m.il_id, p, t);
    insert into oyun.belediye_proje_kayit(kod, il_id, baskan, zaman, maliyet) values (y.kod, m.il_id, p.id, t, 0);
    return public.belediye_paneli();
  end if;
  if v_kasa < maliyet then raise exception 'Belediye kasasında yeterli para yok (% milyar ₺ gerekli, kasada % var).', maliyet, round(v_kasa, 3); end if;
  update oyun.il_durum set kasa = kasa - maliyet, gelisim = oyun.sinir(gelisim + y.gelisim, 0, 100),
    memnuniyet = oyun.sinir(memnuniyet + y.memnuniyet, 0, 100) where il_id = m.il_id;
  insert into oyun.belediye_proje_kayit(kod, il_id, baskan, zaman, maliyet) values (y.kod, m.il_id, p.id, t, maliyet);
  if y.kod = 'imar_barisi' then
    perform oyun.etki_ekle(m.il_id, 'belediye', 'imar_barisi', ilad || ' Belediyesi · İmar barışı', '[{"tur":"gecim","deger":8}]'::jsonb, 14, p.id, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('%s Belediyesi imar barışı ilan etti: 14 gün kira ve geçim masrafın %%8 düşük. Çarpık yapılaşma ilin gelişmişliğini 3 puan düşürdü (maaşlar ~%%1,2 azalır).', ilad)
      from oyun.profiller x where x.il_id = m.il_id and x.id <> p.id and not x.yasakli;
  end if;
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s: %s.', ilad, p.kad, y.ad), m.il_id, p.parti_id, t);
  return public.belediye_paneli();
end $$;

-- Kent vergisi (%0-5) ve hemşehri desteği (0-1.000 ₺/gün); 24 saatte bir değiştirilebilir
create or replace function public.belediye_ayar(p_kent_vergisi numeric, p_hemsehri numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); d oyun.il_durum; ilad text;
        kv numeric := round(coalesce(p_kent_vergisi, -1), 1); hs numeric := round(coalesce(p_hemsehri, -1));
begin
  select * into d from oyun.il_durum where il_id = m.il_id for update;
  select ad into ilad from oyun.iller where id = m.il_id;
  if kv not between 0 and 5 then raise exception 'Kent vergisi %%0-%%5 arasında olmalı.'; end if;
  if hs not between 0 and 1000 then raise exception 'Hemşehri desteği günlük 0-1.000 ₺ arasında olmalı.'; end if;
  if kv = d.kent_vergisi and hs = d.hemsehri then raise exception 'Değişiklik yok.'; end if;
  if d.son_ayar is not null and d.son_ayar > t - interval '24 hours' then
    raise exception 'Kent vergisi ve hemşehri desteği 24 saatte bir değiştirilebilir (sonraki: %).', to_char((d.son_ayar + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  if hs > d.hemsehri and d.kasa < 3 * oyun.hemsehri_gider(m.il_id, hs) then
    raise exception 'Bu desteği vermek için kasada en az 3 günlük gideri (% milyar ₺) olmalı.', round(3 * oyun.hemsehri_gider(m.il_id, hs), 3);
  end if;
  update oyun.il_durum set kent_vergisi = kv, hemsehri = hs, son_ayar = t where il_id = m.il_id;
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s: kent vergisi %%%s, hemşehri desteği günlük %s ₺.', ilad, p.kad, kv, hs), m.il_id, p.parti_id, t);
  if hs > d.hemsehri then
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('%s Belediyesi hemşehri desteğini günlük %s ₺ yaptı. Her gün ilk toplamada cüzdanına yatar.', ilad, hs)
      from oyun.profiller x where x.il_id = m.il_id and x.id <> p.id and not x.yasakli;
  end if;
  return public.belediye_paneli();
end $$;

-- =====================================================================
--  ROZETLER + oyuncu kartı (05'teki tanımın yerine geçer)
-- =====================================================================
create or replace function oyun.rozetler(u uuid) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(r order by r ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '01', 'ad', 'Cumhurbaşkanı', 'aciklama', 'Cumhurbaşkanlığı yaptı') r where exists (select 1 from oyun.makamlar where user_id = u and tur = 'cb')
    union all select jsonb_build_object('sira', '02', 'ad', 'Bakan', 'aciklama', 'Kabinede görev aldı') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bakan')
    union all select jsonb_build_object('sira', '03', 'ad', 'Genel Başkan', 'aciklama', 'Bir partinin genel başkanı oldu')
      where exists (select 1 from oyun.partiler where gb = u) or exists (select 1 from oyun.kazananlar k join oyun.secimler s on s.id = k.secim_id where k.user_id = u and s.tur = 'kurultay')
    union all select jsonb_build_object('sira', '04', 'ad', 'Milletvekili', 'aciklama', 'Meclis''e girdi') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv')
    union all select jsonb_build_object('sira', '05', 'ad', 'Belediye Başkanı', 'aciklama', 'Bir ili yönetti') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bel')
    union all select jsonb_build_object('sira', '06', 'ad', 'Kanun Yapıcı', 'aciklama', 'Teklifi yasalaştı') where exists (select 1 from oyun.kanunlar where teklif_eden = u and durum = 'yururlukte')
    union all select jsonb_build_object('sira', '07', 'ad', 'Parti Kurucusu', 'aciklama', 'Yeni bir parti kurdu') where exists (select 1 from oyun.partiler where kurucu = u)
    union all select jsonb_build_object('sira', '08', 'ad', 'Hatip', 'aciklama', '10+ propaganda yayını') where (select count(*) from oyun.yayinlar where gonderen = u) >= 10
    union all select jsonb_build_object('sira', '09', 'ad', 'Demokrasi Emektarı', 'aciklama', '20+ seçimde oy kullandı') where (select count(*) from oyun.oylar where secmen = u) >= 20
    union all select jsonb_build_object('sira', '10', 'ad', 'Sandık Neferi', 'aciklama', 'İlk oyunu kullandı') where (select count(*) from oyun.oylar where secmen = u) between 1 and 19
  ) x
$$;

create or replace function public.oyuncu_kart(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  return jsonb_build_object('kad', h.kad, 'il_ad', (select ad from oyun.iller where id = h.il_id), 'il_id', h.il_id,
    'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'katilim', h.olusturma,
    'ben', h.id = p.id, 'engelledim', oyun.engelli(p.id, h.id), 'rozetler', oyun.rozetler(h.id),
    'borclu', oyun.takipte(h.id),
    'karneler', oyun.karneler(h.id), 'statu', oyun.statu_json(h.id), 'itibar', oyun.itibar_json(h.id),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('makam', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'bit', m.bit) order by m.bas desc)
                        from (select * from oyun.makamlar where user_id = h.id order by bas desc limit 20) m), '[]'::jsonb));
end $$;

-- =====================================================================
--  YÖNETİCİ PANELİ
--  İlk yönetici SQL ile atanır:  update oyun.profiller set yonetici = true where kad = 'KullaniciAdin';
-- =====================================================================
create or replace function oyun.yonetici_zorunlu() returns oyun.profiller language plpgsql as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not p.yonetici then raise exception 'Bu ekran yalnızca oyun yöneticileri içindir.'; end if;
  return p;
end $$;

create or replace function oyun.hesap_kapat(u uuid, t timestamptz) returns void language plpgsql as $$
declare m record;
begin
  update oyun.profiller set yasakli = true where id = u;
  for m in select id from oyun.makamlar where user_id = u and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'hesap_kapatildi');
  end loop;
  perform oyun._ayril(u, t);
  update oyun.mesajlar set gizli = true where user_id = u;
  update oyun.yayinlar set gizli = true where gonderen = u;
  delete from oyun.cihazlar where user_id = u;
end $$;

create or replace function public.admin_ozet() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('ozet'); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'oyuncu', (select count(*) from oyun.profiller where not yasakli),
    'aktif24', (select count(*) from oyun.profiller where son_gorulme > t - interval '24 hours'),
    'yeni24', (select count(*) from oyun.profiller where olusturma > t - interval '24 hours'),
    'mesaj24', (select count(*) from oyun.mesajlar where zaman > t - interval '24 hours'),
    'sikayet', (select count(distinct (tur, kayit_id, hedef_user)) from oyun.sikayetler where durum = 'yeni'),
    'susturulmus', (select count(*) from oyun.profiller where susturma_bitis > t),
    'yasakli', (select count(*) from oyun.profiller where yasakli),
    'cihaz', (select count(*) from oyun.cihazlar),
    'push_bekleyen', (select count(*) from oyun.push_kuyruk where gonderildi is null and deneme < 3),
    'min_hesap_gun', (select min_hesap_gun from oyun.ayarlar where id = 1),
    'push_aktif', (select push_aktif from oyun.ayarlar where id = 1));
end $$;

create or replace function public.admin_sikayetler(p_durum text default 'yeni') returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  return coalesce((select jsonb_agg(x order by x ->> 'ilk' desc) from (
    select jsonb_build_object('tur', s.tur, 'kayit_id', s.kayit_id, 'hedef', oyun.kad(s.hedef_user),
      'sayi', count(distinct s.sikayetci), 'nedenler', jsonb_agg(distinct s.neden), 'ilk', min(s.zaman),
      'icerik', case s.tur when 'mesaj' then (select metin from oyun.mesajlar where id = s.kayit_id)
                           when 'yayin' then (select metin from oyun.yayinlar where id = s.kayit_id)
                           when 'ozel' then (select metin from oyun.ozel where id = s.kayit_id) end,
      'gizli', case s.tur when 'mesaj' then (select gizli from oyun.mesajlar where id = s.kayit_id)
                          when 'yayin' then (select gizli from oyun.yayinlar where id = s.kayit_id)
                          when 'ozel' then (select gizli from oyun.ozel where id = s.kayit_id) end,
      'hedef_susturma', (select susturma_bitis from oyun.profiller where id = s.hedef_user),
      'hedef_sikayet_toplam', (select count(*) from oyun.sikayetler z where z.hedef_user = s.hedef_user)) x
    from oyun.sikayetler s where s.durum = p_durum
    group by s.tur, s.kayit_id, s.hedef_user limit 100) q), '[]'::jsonb);
end $$;

-- p_islem: yok_say | gizle | gizle_sustur1 | gizle_sustur7 | kapat (hesabı kapat)
create or replace function public.admin_sikayet_karar(p_tur text, p_kayit bigint, p_hedef_kad text, p_islem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_hedef_kad);
  if p_islem not in ('yok_say','gizle','gizle_sustur1','gizle_sustur7','kapat') then raise exception 'Geçersiz işlem.'; end if;
  -- moderatör yetkileri (16_moderator): susturma ve hesap kapatma ayrı yetkilerdir
  if p_islem in ('gizle_sustur1','gizle_sustur7') and not oyun.yetkili(p.id, 'sustur') then raise exception 'Susturma yetkin yok; yalnızca "Gizle" diyebilirsin.'; end if;
  if p_islem = 'kapat' and not oyun.yetkili(p.id, 'hesap_kapat') then raise exception 'Hesap kapatma yetkin yok.'; end if;
  if p_islem <> 'yok_say' then perform oyun.korunan_hedef(p, h.id); end if;
  perform oyun.mod_log(p, 'sikayet_' || p_islem, h.kad, (case p_tur when 'mesaj' then (select metin from oyun.mesajlar where id = p_kayit)
                                                                       when 'yayin' then (select metin from oyun.yayinlar where id = p_kayit)
                                                                       when 'ozel' then (select metin from oyun.ozel where id = p_kayit) end));
  if p_islem = 'yok_say' then
    if p_tur = 'mesaj' then update oyun.mesajlar set gizli = false where id = p_kayit;
    elsif p_tur = 'yayin' then update oyun.yayinlar set gizli = false where id = p_kayit; end if;
  else
    if p_tur = 'mesaj' then update oyun.mesajlar set gizli = true where id = p_kayit;
    elsif p_tur = 'yayin' then update oyun.yayinlar set gizli = true where id = p_kayit;
    elsif p_tur = 'ozel' then update oyun.ozel set gizli = true where id = p_kayit; end if;
  end if;
  if p_islem = 'gizle_sustur1' then update oyun.profiller set susturma_bitis = t + interval '1 day' where id = h.id; end if;
  if p_islem = 'gizle_sustur7' then update oyun.profiller set susturma_bitis = t + interval '7 days' where id = h.id; end if;
  if p_islem = 'kapat' then perform oyun.hesap_kapat(h.id, t); end if;
  if p_islem in ('gizle_sustur1','gizle_sustur7') then
    perform oyun.bildir(h.id, 'Topluluk kurallarını ihlal eden bir içeriğin kaldırıldı ve hesabın bir süre mesaj gönderemeyecek.', t);
  end if;
  update oyun.sikayetler set durum = 'incelendi' where tur = p_tur and kayit_id = coalesce(p_kayit, 0) and hedef_user = h.id;
  return public.admin_sikayetler('yeni');
end $$;

create or replace function public.admin_oyuncu(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('oyuncu_ara'); h oyun.profiller; t timestamptz := oyun.simdi();
begin
  h := oyun.profil_bul(p_kad);
  return jsonb_build_object('kad', h.kad, 'eposta', case when oyun.yetkili(p.id, 'eposta') then (select email from auth.users where id = h.id) end,
    'moderator', exists (select 1 from oyun.moderatorler where user_id = h.id), 'borc', oyun.banka_ozet(h.id),
    'il', (select ad from oyun.iller where id = h.il_id), 'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id),
    'olusturma', h.olusturma, 'son_gorulme', h.son_gorulme, 'yasakli', h.yasakli, 'yonetici', h.yonetici,
    'susturma_bitis', case when h.susturma_bitis > t then h.susturma_bitis end,
    'sikayet', (select count(*) from oyun.sikayetler where hedef_user = h.id),
    'son_mesajlar', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'kanal', m.kanal, 'metin', m.metin, 'zaman', m.zaman, 'gizli', m.gizli) order by m.id desc)
                              from (select * from oyun.mesajlar where user_id = h.id order by id desc limit 15) m), '[]'::jsonb));
end $$;

-- p_islem: sustur1 | sustur7 | susturma_kaldir | kapat | ac
create or replace function public.admin_islem(p_kad text, p_islem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller;
begin
  -- moderatör yetkileri (16_moderator)
  p := oyun.yetki_zorunlu(case when p_islem in ('kapat','ac') then 'hesap_kapat' else 'sustur' end);
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendi hesabına işlem yapamazsın.'; end if;
  perform oyun.korunan_hedef(p, h.id);
  perform oyun.mod_log(p, p_islem, h.kad, null);
  if p_islem = 'sustur1' then update oyun.profiller set susturma_bitis = t + interval '1 day' where id = h.id;
  elsif p_islem = 'sustur7' then update oyun.profiller set susturma_bitis = t + interval '7 days' where id = h.id;
  elsif p_islem = 'susturma_kaldir' then update oyun.profiller set susturma_bitis = null where id = h.id;
  elsif p_islem = 'kapat' then perform oyun.hesap_kapat(h.id, t);
  elsif p_islem = 'ac' then update oyun.profiller set yasakli = false where id = h.id;
  else raise exception 'Geçersiz işlem.'; end if;
  return public.admin_oyuncu(p_kad);
end $$;

create or replace function public.admin_duyuru(p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('duyuru'); t timestamptz := oyun.simdi(); m text;
begin
  m := oyun.metin_temizle(p_metin, 600);
  perform oyun.mod_log(p, 'duyuru', null, m);
  insert into oyun.yayinlar(tur, gonderen, metin, zaman, unvan) values ('sistem', p.id, m, t, 'Oyun Yönetimi');
  return jsonb_build_object('tamam', true, 'kitle', (select count(*) from oyun.profiller where not yasakli));
end $$;

create or replace function public.admin_ayar(p_min_hesap_gun int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('kurallar');
begin
  if p_min_hesap_gun not between 0 and 30 then raise exception 'Hesap yaşı 0-30 gün olmalı.'; end if;
  perform oyun.mod_log(p, 'ayar', null, 'min_hesap_gun=' || p_min_hesap_gun);
  update oyun.ayarlar set min_hesap_gun = p_min_hesap_gun where id = 1;
  return public.admin_ozet();
end $$;

-- =====================================================================
--  PUSH BİLDİRİMLERİ
--  Uygulama, telefonun Firebase anahtarını (token) kaydeder ve Firebase "konu"larına abone olur:
--    s_tum, s_parti_<id>               seçim hatırlatmaları
--    p_tum, p_il_<plaka>, p_parti_<id> propaganda yayınları
--    duyuru                            oyun yönetimi duyuruları
--  Kişisel bildirimler ve özel mesajlar doğrudan kişinin cihazlarına gider.
--  Kuyruktaki bildirimleri "push-gonder" sunucu fonksiyonu Firebase'e iletir.
-- =====================================================================
create table if not exists oyun.cihazlar(
  token      text primary key,
  user_id    uuid not null,
  platform   text,
  guncelleme timestamptz not null default now()
);
create index if not exists cihazlar_user on oyun.cihazlar(user_id);

create table if not exists oyun.push_kuyruk(
  id         bigserial primary key,
  user_id    uuid,          -- kişiye özel
  konu       text,          -- Firebase konusu
  kosul      text,          -- Firebase konu koşulu (iki konunun kesişimi)
  baslik     text not null,
  govde      text not null,
  veri       jsonb not null default '{}',
  olusturma  timestamptz not null default now(),
  alindi     timestamptz,
  gonderildi timestamptz,
  deneme     int not null default 0,
  hata       text
);
create index if not exists push_bekleyen on oyun.push_kuyruk(id) where gonderildi is null;

create or replace function oyun.push_acik() returns boolean language sql stable as $$
  select coalesce((select push_aktif from oyun.ayarlar where id = 1), false)
$$;

create or replace function oyun.push_kisiye(u uuid, tercih text, p_baslik text, p_govde text, p_veri jsonb) returns void language plpgsql as $$
begin
  if not oyun.push_acik() then return; end if;
  if not exists (select 1 from oyun.cihazlar where user_id = u) then return; end if;
  if not coalesce((select (bildirim_ayar ->> tercih)::boolean from oyun.profiller where id = u and not yasakli), false) then return; end if;
  insert into oyun.push_kuyruk(user_id, baslik, govde, veri) values (u, left(p_baslik, 80), left(p_govde, 180), p_veri);
end $$;

create or replace function oyun.push_konuya(p_konu text, p_kosul text, p_baslik text, p_govde text, p_veri jsonb) returns void language plpgsql as $$
begin
  if not oyun.push_acik() then return; end if;
  insert into oyun.push_kuyruk(konu, kosul, baslik, govde, veri) values (p_konu, p_kosul, left(p_baslik, 80), left(p_govde, 180), p_veri);
end $$;

-- Tetikleyiciler
create or replace function oyun.tg_bildirim_push() returns trigger language plpgsql as $$
begin
  perform oyun.push_kisiye(new.user_id, 'kisisel', 'Seçim Simülasyonu', new.metin, '{"ekran":"bildirim"}');
  return null;
end $$;
drop trigger if exists bildirim_push on oyun.bildirimler;
create trigger bildirim_push after insert on oyun.bildirimler for each row execute function oyun.tg_bildirim_push();

create or replace function oyun.tg_ozel_push() returns trigger language plpgsql as $$
declare k text := oyun.kad(new.gonderen);
begin
  if oyun.engelli(new.alici, new.gonderen) then return null; end if;
  perform oyun.push_kisiye(new.alici, 'ozel', k, new.metin, jsonb_build_object('ekran', 'ozel', 'kad', k));
  return null;
end $$;
drop trigger if exists ozel_push on oyun.ozel;
create trigger ozel_push after insert on oyun.ozel for each row execute function oyun.tg_ozel_push();

create or replace function oyun.tg_yayin_push() returns trigger language plpgsql as $$
declare k text := oyun.kad(new.gonderen);
begin
  if new.tur = 'sistem' then
    perform oyun.push_konuya('duyuru', null, 'Oyun Yönetimi', new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_il is null and new.hedef_parti is null then
    perform oyun.push_konuya('p_tum', null, k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_parti is null then
    perform oyun.push_konuya('p_il_' || new.hedef_il, null, k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_il is null then
    perform oyun.push_konuya('p_parti_' || new.hedef_parti, null, k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  else
    perform oyun.push_konuya(null, format('''p_il_%s'' in topics && ''p_parti_%s'' in topics', new.hedef_il, new.hedef_parti),
                             k || ' · ' || new.unvan, new.metin, '{"ekran":"bildirim"}');
  end if;
  return null;
end $$;
drop trigger if exists yayin_push on oyun.yayinlar;
create trigger yayin_push after insert on oyun.yayinlar for each row execute function oyun.tg_yayin_push();

-- Seçim hatırlatmaları (tick içinden, her dakika). Yalnızca ilgili zaman penceresi içindeyken gönderilir.
create or replace function oyun.push_hatirlatmalar(t timestamptz) returns void language plpgsql as $$
declare s oyun.secimler; pid bigint; v jsonb;
begin
  if not oyun.push_acik() then return; end if;
  for s in select * from oyun.secimler where durum = 'bekliyor' and basvuru_bas is not null and t >= basvuru_bas and t < basvuru_bit
             and tur in ('bel_on','mv_on','kurultay') and not (hatirlatma ? 'basvuru') loop
    perform oyun.push_konuya('s_tum', null, 'Başvurular açıldı', case s.tur
      when 'bel_on' then 'Belediye başkanlığı aday adaylığı başvuruları bugün açık. Adayını çıkar!'
      when 'mv_on' then 'Milletvekili aday adaylığı başvuruları bugün açık. Listeye girmek için başvur!'
      else 'Genel başkanlık başvuruları açıldı. Kurultay ayın 18''inde.' end, jsonb_build_object('ekran', 'gundem'));
    update oyun.secimler set hatirlatma = hatirlatma || '{"basvuru":true}' where id = s.id;
  end loop;
  for s in select * from oyun.secimler where durum = 'bekliyor' and t >= oy_bas and t < oy_bit and not (hatirlatma ? 'oy') loop
    v := jsonb_build_object('ekran', 'secim', 'id', s.id);
    if s.tur = 'mv' then
      perform oyun.push_konuya('s_tum', null, 'Bugün seçim var! 🗳️', 'Genel seçim ve cumhurbaşkanlığı seçimi sandıkları 17:00''ye kadar açık.', v);
    elsif s.tur = 'cb2' then
      perform oyun.push_konuya('s_tum', null, 'Cumhurbaşkanlığı 2. turu', 'Sandıklar 17:00''de kapanıyor. Oyunu kullanmayı unutma!', v);
    elsif s.tur = 'bel' then
      perform oyun.push_konuya('s_tum', null, 'Bugün belediye seçimi var! 🗳️', 'İl belediye başkanlığı sandıkları 17:00''ye kadar açık.', v);
    elsif s.tur in ('bel_on','mv_on','kurultay','cb_on') then
      for pid in select distinct parti_id from oyun.adaylar where secim_id = s.id and parti_id is not null loop
        perform oyun.push_konuya('s_parti_' || pid, null, 'Partinde seçim var', case s.tur
          when 'bel_on' then 'Belediye başkanı ön seçimi bugün 17:00''ye kadar.'
          when 'mv_on' then 'Milletvekili ön seçimi bugün 17:00''ye kadar. Liste sırasını sen belirle!'
          when 'cb_on' then 'Cumhurbaşkanı aday ön seçimi bugün 17:00''ye kadar.'
          else 'Kurultay bugün! Genel başkanını seç.' end, v);
      end loop;
    end if;
    update oyun.secimler set hatirlatma = hatirlatma || '{"oy":true}' where id = s.id;
  end loop;
  for s in select * from oyun.secimler where durum <> 'bekliyor' and tur in ('mv','bel','cb','cb2')
             and t >= sonuc_at and t < sonuc_at + interval '3 hours' and not (hatirlatma ? 'sonuc') loop
    if not (s.tur = 'cb') then
      perform oyun.push_konuya('s_tum', null, 'Sonuçlar açıklandı', case s.tur
        when 'mv' then 'Genel seçim ve cumhurbaşkanlığı sonuçları açıklandı. Meclis''in yeni dağılımını gör!'
        when 'bel' then 'Belediye seçimi sonuçları açıklandı. İlini kim kazandı?'
        else 'Cumhurbaşkanlığı ikinci tur sonucu açıklandı.' end, jsonb_build_object('ekran', 'secim', 'id', s.id));
    end if;
    update oyun.secimler set hatirlatma = hatirlatma || '{"sonuc":true}' where id = s.id;
  end loop;
  perform oyun.kumbara_hatirlat(t);
end $$;

-- Kuyrukta bekleyen varsa sunucu fonksiyonunu uyandırır (Supabase'de pg_net eklentisiyle)
create or replace function oyun.push_tetikle() returns void language plpgsql as $$
declare a oyun.ayarlar;
begin
  select * into a from oyun.ayarlar where id = 1;
  if not a.push_aktif or a.push_url is null then return; end if;
  if not exists (select 1 from oyun.push_kuyruk where gonderildi is null and deneme < 3) then return; end if;
  begin
    execute format('select net.http_post(url := %L, body := %L::jsonb, headers := %L::jsonb)',
                   a.push_url, '{}', json_build_object('Content-Type', 'application/json', 'x-gizli', a.push_gizli)::text);
  exception when others then
    null;  -- pg_net yoksa veya istek kurulamazsa oyun motoru durmaz
  end;
end $$;

-- ---------- Uygulamanın çağırdığı fonksiyonlar ----------
create or replace function public.cihaz_kaydet(p_token text, p_platform text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  if coalesce(length(p_token), 0) < 20 or length(p_token) > 4096 then raise exception 'Geçersiz cihaz anahtarı.'; end if;
  insert into oyun.cihazlar(token, user_id, platform, guncelleme) values (p_token, p.id, left(p_platform, 20), now())
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, guncelleme = now();
  -- bir kişinin en fazla 5 cihazı tutulur
  delete from oyun.cihazlar where user_id = p.id and token not in
    (select token from oyun.cihazlar where user_id = p.id order by guncelleme desc limit 5);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.cihaz_sil(p_token text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
begin
  delete from oyun.cihazlar where token = p_token and user_id = oyun.ben();
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.bildirim_ayar_kaydet(p_ayar jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); yeni jsonb := '{}'; k text;
begin
  foreach k in array array['secim','ozel','propaganda','kisisel'] loop
    yeni := yeni || jsonb_build_object(k, coalesce((p_ayar ->> k)::boolean, (p.bildirim_ayar ->> k)::boolean, true));
  end loop;
  update oyun.profiller set bildirim_ayar = yeni where id = p.id;
  return public.durum();
end $$;

-- ---------- Sunucu fonksiyonunun çağırdığı fonksiyonlar (yalnızca service_role) ----------
create or replace function public.push_al(p_limit int default 500) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare j jsonb;
begin
  with secilen as (
    select id from oyun.push_kuyruk
    where gonderildi is null and deneme < 3 and (alindi is null or alindi < now() - interval '2 minutes')
      and olusturma > now() - interval '6 hours'
    order by id limit least(greatest(p_limit, 1), 1000) for update skip locked
  ), al as (
    update oyun.push_kuyruk k set alindi = now(), deneme = deneme + 1 from secilen where k.id = secilen.id returning k.*
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', al.id, 'konu', al.konu, 'kosul', al.kosul, 'baslik', al.baslik, 'govde', al.govde, 'veri', al.veri,
           'tokenlar', case when al.user_id is null then null else
              coalesce((select jsonb_agg(c.token) from oyun.cihazlar c where c.user_id = al.user_id), '[]'::jsonb) end) order by al.id), '[]'::jsonb)
  into j from al;
  -- 6 saatten eski gönderilmemişler artık anlamsız: kapat
  update oyun.push_kuyruk set gonderildi = now(), hata = 'süresi doldu' where gonderildi is null and olusturma <= now() - interval '6 hours';
  return j;
end $$;

-- p_sonuc: {"basarili":[id...], "hatalar":{"id":"mesaj"}, "gecersiz":[token...]}
create or replace function public.push_bitti(p_sonuc jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare n1 int; n2 int;
begin
  update oyun.push_kuyruk set gonderildi = now(), hata = null
   where id in (select (x)::bigint from jsonb_array_elements_text(coalesce(p_sonuc -> 'basarili', '[]')) x);
  get diagnostics n1 = row_count;
  update oyun.push_kuyruk k set hata = h.value, gonderildi = case when k.deneme >= 3 then now() end
   from jsonb_each_text(coalesce(p_sonuc -> 'hatalar', '{}')) h where k.id = h.key::bigint;
  delete from oyun.cihazlar where token in (select x from jsonb_array_elements_text(coalesce(p_sonuc -> 'gecersiz', '[]')) x);
  get diagnostics n2 = row_count;
  delete from oyun.push_kuyruk where olusturma < now() - interval '7 days';
  return jsonb_build_object('gonderildi', n1, 'silinen_cihaz', n2);
end $$;

revoke all on function public.push_al(int) from public, anon, authenticated;
revoke all on function public.push_bitti(jsonb) from public, anon, authenticated;
grant execute on function public.push_al(int) to service_role;
grant execute on function public.push_bitti(jsonb) to service_role;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 9) VATANDAŞ EKONOMİSİ VE VAATLER
--
--  Oyuncunun parası:
--    • Maaş kumbarası: maaş saat saat birikir, en fazla 8 saatlik. Oyuncu girip "Topla" der.
--    • Giriş serisi: üst üste her gün +%5 (en fazla +%30).
--    • Statü: kıdem puanı (oyuna girilen gün + kullanılan oy × 3) → 6 basamak; her basamak kıdem primi kadar maaş artışı.
--    • Reklam izle (günde 5): 2 saatlik maaş. Satın alma: ₺ paketleri (RevenueCat → odeme-webhook).
--  Maaş = asgari ücret × statü × il refahı × destekler (+ makam maaşı). Kesintiler: gelir vergisi (asgari ücret muaf),
--  kent vergisi, geçim masrafı (fiyat düzeyiyle artar; belediye hizmetleri ve bakanlık tedbirleri düşürür).
--  Harcamalar: aday adaylığı ücreti (parti kasasına), taşınma, ek propaganda hakkı, parti bağışı.
--
--  Politikalar: yürütme (cumhurbaşkanı + ilgili bakan) asgari ücret, kıdem primi, sosyal destek, gelir vergisi
--  ve taşınma desteğini ayarlar. Vaatler bu ayarlara bağlıdır; maliyeti ülkenin/ilin/partinin mali alanına sığmalıdır.
-- =====================================================================

alter table oyun.ayarlar add column if not exists baslangic_para numeric not null default 10000;
-- Vatandaş maaşı çarpanı (oyun hızı): asgari ücretin saatlik karşılığı bu kadar katıyla ödenir. Makam maaşları etkilenmez.
alter table oyun.ayarlar add column if not exists maas_hizi numeric not null default 3;

-- Önceki taslak sürümün (enerji/deneyim) kalıntıları
do $$
declare r record;
begin
  if exists (select 1 from information_schema.columns where table_schema = 'oyun' and table_name = 'cuzdan' and column_name = 'enerji') then
    drop table oyun.cuzdan cascade;
  end if;
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where (n.nspname = 'public' and p.proname in ('calis','kurs_al','yemek_ye','vaat_katalog','vaat_yaz'))
              or (n.nspname = 'oyun' and p.proname in ('enerji_max','enerji_hiz','enerji_simdi','cuzdan_gun','yemek_fiyat','kurs_fiyat','yemek_hakki',
                   'calis_enerji','maas_hesap','seviye','seviye_esik','makam_odenek','fiyat_endeksi','taahhut_grubu','taahhut_tutuldu','vaat_karnesi','gunluk_odemeler'))
  loop
    execute 'drop function ' || r.f::text;
  end loop;
end $$;
drop table if exists oyun.vaat_katalog cascade;              -- eski taahhüt kataloğu → vaat_turleri
alter table oyun.adaylar drop column if exists taahhut;      -- eski taahhüt listesi → vaatler tablosu

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.cuzdan(
  user_id     uuid primary key references oyun.profiller(id) on delete cascade,
  para        numeric not null default 0 check (para >= 0),
  son_toplama timestamptz not null,
  seri        int not null default 0,
  seri_gun    date,                 -- son toplama günü (Türkiye saati)
  kidem       numeric not null default 0,   -- oyuna girilen günlerden gelen kıdem puanı
  gun         date,                 -- günlük sayaçların günü
  izle_n      int not null default 0,  -- bugün izlenen ödüllü reklam
  son_izle    timestamptz,
  reklam_n    int not null default 0,  -- bugün satın alınan ek yayın hakkı
  reklam_kul  int not null default 0,
  bagis_bugun numeric not null default 0,
  kumbara_bildirim timestamptz
);

create table if not exists oyun.hesap_hareket(
  id      bigserial primary key,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  zaman   timestamptz not null,
  tutar   numeric not null,
  vergi   numeric not null default 0,
  tur     text not null,
  aciklama text not null
);
create index if not exists hesap_hareket_user on oyun.hesap_hareket(user_id, zaman desc);

alter table oyun.partiler add column if not exists kasa numeric not null default 0;
alter table oyun.partiler add column if not exists aday_ucret jsonb not null default '{"mv_on":1,"bel_on":1,"kurultay":1,"cb_on":1}';
create table if not exists oyun.parti_hareket(
  id       bigserial primary key,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  zaman    timestamptz not null,
  tutar    numeric not null,
  aciklama text not null
);
alter table oyun.parti_hareket add column if not exists tur text not null default 'diger';
create index if not exists parti_hareket_parti on oyun.parti_hareket(parti_id, zaman desc);


create table if not exists oyun.politika_kayit(
  id      bigserial primary key,
  kod     text not null,
  eski    numeric, yeni numeric not null,
  user_id uuid not null,
  makam   text not null,
  zaman   timestamptz not null
);
create index if not exists politika_kayit_kod on oyun.politika_kayit(kod, zaman desc);

create table if not exists oyun.paketler(
  urun_id text primary key, ad text not null, miktar numeric not null, sira int not null
);
insert into oyun.paketler(urun_id, ad, miktar, sira) values
  ('tl_10000', 'Cep harçlığı', 10000, 1),
  ('tl_35000', 'Kampanya kasası', 35000, 2),
  ('tl_100000', 'Seçim fonu', 100000, 3)
on conflict (urun_id) do update set ad = excluded.ad, miktar = excluded.miktar, sira = excluded.sira;

create table if not exists oyun.satin_almalar(
  id        bigserial primary key,
  islem_id  text not null unique,
  user_id   uuid references oyun.profiller(id) on delete set null,
  urun_id   text not null,
  miktar    numeric not null,
  zaman     timestamptz not null default now(),
  iade      boolean not null default false,
  olay      jsonb
);

-- Vaat türleri
create table if not exists oyun.vaat_turleri(
  kapsam text not null check (kapsam in ('beyanname','mv','bel','gb')),
  kod    text not null,
  ad     text not null,
  birim  text not null,           -- tl_ay, tl_gun, tl, yuzde, kat, yok
  tip    text not null check (tip in ('surekli','tek')),
  yon    text,                    -- '>=' / '<=' / null (vergi: hedefe göre belirlenir)
  min    numeric, max numeric,
  sira   int not null,
  aciklama text not null,
  primary key (kapsam, kod)
);
-- katalog: silinmez, güncellenir (verilmiş vaatler bu kodlara bağlıdır)
insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama) values
 ('beyanname','asgari','Asgari ücreti artıracağız','tl_ay','surekli','>=',null,null,1,'Herkesin maaşının tabanı. Ekonominin kaldırabileceğinden hızlı artarsa enflasyon yükselir.'),
 ('beyanname','vergi','Gelir vergisini değiştireceğiz','yuzde','surekli',null,0,45,2,'Asgari ücretin üstündeki kazançtan kesilir. İndirmek hazinenin gelirini azaltır; artırmak yeni vaatlere yer açar.'),
 ('beyanname','kidem','Kıdemlilerin maaşını artıracağız','yuzde','surekli','>=',0,20,3,'Kıdem primi: her statü basamağının maaşa eklediği oran.'),
 ('beyanname','destek','Yeni vatandaşlara günlük sosyal destek','tl_gun','surekli','>=',0,1000,4,'Yeni Gelen ve Vatandaş statüsündekilere her gün ödenir; 8 milyon kişiye gider.'),
 ('beyanname','tasinma','Taşınma masrafını devlet karşılayacak','yuzde','surekli','>=',0,80,5,'İl değiştirirken ödenen masrafın bu kadarını devlet öder.'),
 ('beyanname','ikramiye','Bayram ikramiyesi vereceğiz','tl','tek','>=',500,5000,6,'Görev süresinde en az bir kez kişi başı bu tutarda ikramiye; 16 milyon kişiye gider.'),
 ('beyanname','cal_istihdam','İstihdam paketiyle maaşları artıracağız','yok','tek',null,null,null,7,'Çalışma Bakanlığı icraatı: maaşlar 7 gün %10 artar.'),
 ('beyanname','tar_market','Gıdayı ucuzlatacağız (Tarım Kredi marketleri)','yok','tek',null,null,null,8,'Tarım Bakanlığı icraatı: geçim masrafı %15 düşer.'),
 ('beyanname','sag_ucretsiz','Sağlıkta katkı paylarını kaldıracağız','yok','tek',null,null,null,9,'Sağlık Bakanlığı icraatı: geçim masrafı %10 düşer.'),
 ('beyanname','egt_burs','Gençlere burs ve staj vereceğiz','yok','tek',null,null,null,10,'Eğitim Bakanlığı icraatı: yeni oyuncuların maaşı %20 artar.'),
 ('beyanname','tic_fiyat','Fahiş fiyatla mücadele edeceğiz','yok','tek',null,null,null,11,'Ticaret Bakanlığı icraatı: geçim masrafı %10 düşer.'),
 ('beyanname','ula_toplu','Toplu taşımayı ucuzlatacağız','yok','tek',null,null,null,12,'Ulaştırma Bakanlığı icraatı: geçim %5, taşınma %30 düşer.'),
 ('mv','vergi_tavan','Gelir vergisi tavanını indiren bütçeye oy vereceğim','yuzde','tek','<=',0,45,1,'Bütçe kanunundaki vergi bandının üst sınırı. Hükümet vergiyi bu sınırın üstüne çıkaramaz.'),
 ('mv','belediye_payi','Belediyelerin vergi payını artıracağım','yuzde','tek','>=',2,30,2,'Bütçe kanunuyla. Tüm illerin belediye geliri artar.'),
 ('mv','baraj','Seçim barajını indireceğim','yuzde','tek','<=',0,10,3,'Seçim kanunuyla.'),
 ('mv','parti_yardim','Partilere hazine yardımını azaltacağım','tl_gun','tek','<=',0,200000,4,'Bütçe kanunuyla. Partilere giden günlük toplam yardım.'),
 ('bel','kent_vergisi','Kent vergisini indireceğim','yuzde','surekli','<=',0,5,1,'Hemşehrilerin gelirinden kesilen belediye vergisi.'),
 ('bel','hemsehri','Her hemşehriye günlük destek vereceğim','tl_gun','surekli','>=',0,1000,2,'Her gün ilk toplamada cüzdana yatar.'),
 ('bel','lokanta','Kent lokantası açacağım','yok','surekli',null,null,null,3,'Geçim masrafı %15 düşer.'),
 ('bel','ulasim','Toplu ulaşımı ücretsiz yapacağım','yok','surekli',null,null,null,4,'Geçim %10 düşer, taşınma yarı fiyat.'),
 ('bel','kira','Sosyal konut ve kira yardımı yapacağım','yok','surekli',null,null,null,5,'Geçim masrafı %20 düşer.'),
 ('bel','istihdam','İstihdam ofisiyle maaşları artıracağım','yok','surekli',null,null,null,6,'İldeki maaşlar %10 artar.'),
 ('bel','altyapi','Altyapıyı yenileyeceğim','yok','tek',null,null,null,7,'İlin gelişmişliği kalıcı +4.'),
 ('bel','rayli','Raylı sistem hattı yapacağım','yok','tek',null,null,null,8,'İlin gelişmişliği kalıcı +10.'),
 ('gb','aday_ucret','Aday adaylığı ücretlerini düşüreceğim','kat','surekli','<=',0,3,1,'Parti içi seçimlere başvuru ücretinin çarpanı (en yüksek olanı).'),
 ('gb','kampanya','Adaylara kasadan kampanya desteği vereceğim','tl','tek','>=',1000,1000000,2,'Görev süresince adaylara toplam bu kadar destek.')
on conflict (kapsam, kod) do update set ad = excluded.ad, birim = excluded.birim, tip = excluded.tip, yon = excluded.yon,
  min = excluded.min, max = excluded.max, sira = excluded.sira, aciklama = excluded.aciklama;

create table if not exists oyun.vaatler(
  id         bigserial primary key,
  kapsam     text not null,
  donem      text not null,
  user_id    uuid references oyun.profiller(id) on delete cascade,  -- beyannamede null
  parti_id   bigint references oyun.partiler(id) on delete cascade,
  il_id      smallint,
  kod        text not null,
  hedef      numeric,
  yon        text,
  olusturma  timestamptz not null,
  durum      text not null default 'bekliyor' check (durum in ('bekliyor','aktif','bitti','secilmedi')),
  makam_id   bigint,
  aktif_bas  timestamptz,
  bitis      timestamptz,
  gun_toplam int not null default 0,
  gun_tutuldu int not null default 0,
  tamam      boolean not null default false
);
create index if not exists vaatler_durum on oyun.vaatler(durum);
create index if not exists vaatler_user on oyun.vaatler(user_id, donem);

create table if not exists oyun.parti_beyanname(
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  donem    text not null,
  metin    text,
  zaman    timestamptz not null,
  primary key (parti_id, donem)
);

-- ---------------------------------------------------------------------
-- YARDIMCILAR
-- ---------------------------------------------------------------------
-- 28075 → "28.075"
create or replace function oyun.tl(x numeric) returns text language sql immutable as $$
  select replace(to_char(round(x), 'FM999,999,999,990'), ',', '.')
$$;
create or replace function oyun.birim_yaz(x numeric, b text) returns text language sql immutable as $$
  select case b when 'tl_ay' then oyun.tl(x) || ' ₺/ay' when 'tl_gun' then oyun.tl(x) || ' ₺/gün' when 'tl' then oyun.tl(x) || ' ₺'
                when 'yuzde' then '%' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'kat' then '×' || replace(regexp_replace(trim(to_char(x, 'FM990.00')), '\.?0+$', ''), '.', ',')
                else coalesce(x::text, '') end
$$;

-- Bakanlık icraatlarının ve açık belediye hizmetlerinin bir oyuncuya (ilinde) toplam etkisi
create or replace function oyun.bonus(p_il smallint, p_tur text, t timestamptz) returns numeric language sql stable as $$
  select coalesce((select sum(deger) from oyun.etkiler where tur = p_tur and (il_id is null or il_id = p_il) and bas <= t and bit > t), 0)
       + coalesce((select sum((e ->> 'deger')::numeric) from oyun.il_hizmet h join oyun.belediye_hizmetleri b on b.kod = h.kod,
                          jsonb_array_elements(b.etki) e where h.il_id = p_il and e ->> 'tur' = p_tur), 0)
$$;

-- İlin gelişmişliği maaşları etkiler: gelişim 0 → ×0,8 · 50 → ×1,0 · 100 → ×1,2
create or replace function oyun.il_carpan(p_il smallint) returns numeric language sql stable as $$
  select round(0.8 + coalesce((select gelisim from oyun.il_durum where il_id = p_il), 50) / 250, 3)
$$;

-- Makam maaşları (aylık ₺). Temmuz 2026 gerçek rakamlarıyla aynı oranda; fiyat düzeyiyle artar.
--   Cumhurbaşkanı 354.497 · Bakan 318.009 · Milletvekili 310.332
--   İl belediye başkanı (nüfusa göre): 2 milyon+ 317.800 · 1-2 milyon 267.800 · 250-500 bin 198.900 · daha küçük 171.400
create or replace function oyun.makam_maasi(p_tur text, p_il smallint) returns numeric language sql stable as $$
  select (case p_tur when 'cb' then 354497 when 'bakan' then 318009 when 'mv' then 310332
            when 'tbmm' then 60000 when 'bskv' then 30000 when 'grup_bskv' then 20000   -- vekil ödeneğine ek görev tazminatı
            when 'bel' then (select case when mv >= 14 then 317800 when mv >= 8 then 267800 when mv >= 4 then 198900 else 171400 end
                             from oyun.iller where id = p_il)
            else 0 end) * (select endeks from oyun.ulke where id = 1)
$$;

-- Süreli etki ekle. Aynı kaynaktan aynı yerde süren etki varsa süresini uzatır.
create or replace function oyun.etki_ekle(p_il smallint, p_kaynak_tur text, p_kaynak_kod text, p_kaynak_ad text,
                                          p_oyuncu jsonb, p_sure_gun int, u uuid, t timestamptz) returns timestamptz language plpgsql as $$
declare e jsonb; son timestamptz; bit_ timestamptz;
begin
  if p_oyuncu is null or jsonb_array_length(p_oyuncu) = 0 or p_sure_gun is null then return null; end if;
  select max(bit) into son from oyun.etkiler where kaynak_kod = p_kaynak_kod and il_id is not distinct from p_il and bit > t;
  bit_ := coalesce(son, t) + make_interval(days => p_sure_gun);
  if son is not null then
    update oyun.etkiler set bit = bit_ where kaynak_kod = p_kaynak_kod and il_id is not distinct from p_il and bit > t;
  else
    for e in select * from jsonb_array_elements(p_oyuncu) loop
      insert into oyun.etkiler(il_id, tur, deger, bas, bit, kaynak_tur, kaynak_kod, kaynak_ad, user_id)
      values (p_il, e ->> 'tur', (e ->> 'deger')::numeric, t, bit_, p_kaynak_tur, p_kaynak_kod, p_kaynak_ad, u);
    end loop;
  end if;
  return bit_;
end $$;

-- Statü
create or replace function oyun.statu_esik(i int) returns int language sql immutable as $$
  select (array[0, 10, 30, 75, 150, 300])[i + 1]
$$;
create or replace function oyun.statu_ad(i int) returns text language sql immutable as $$
  select (array['Yeni Gelen','Vatandaş','Saygın Vatandaş','Kanaat Önderi','Duayen','Yaşayan Efsane'])[i + 1]
$$;
create or replace function oyun.kidem_puani(u uuid) returns numeric language sql stable as $$
  select floor(coalesce((select kidem from oyun.cuzdan where user_id = u), 0) + 3 * (select count(*) from oyun.oylar where secmen = u))
$$;
create or replace function oyun.statu_basamak(p numeric) returns int language sql immutable as $$
  select case when p >= 300 then 5 when p >= 150 then 4 when p >= 75 then 3 when p >= 30 then 2 when p >= 10 then 1 else 0 end
$$;
create or replace function oyun.statu_json(u uuid) returns jsonb language sql stable as $$
  with x as (select oyun.kidem_puani(u) puan), y as (select puan, oyun.statu_basamak(puan) b from x)
  select jsonb_build_object('puan', puan, 'basamak', b, 'ad', oyun.statu_ad(b),
           'carpan', round(1 + b * (select kidem_primi from oyun.ulke where id = 1) / 100, 3),
           'sonraki_ad', case when b < 5 then oyun.statu_ad(b + 1) end, 'sonraki_esik', case when b < 5 then oyun.statu_esik(b + 1) end,
           'bu_esik', oyun.statu_esik(b))
  from y
$$;

create or replace function oyun.cuzdanim(u uuid) returns oyun.cuzdan language plpgsql as $$
declare c oyun.cuzdan; t timestamptz := oyun.simdi();
begin
  -- yeni oyuncunun kumbarası dolu başlar
  insert into oyun.cuzdan(user_id, para, son_toplama) values (u, (select baslangic_para from oyun.ayarlar where id = 1), t - interval '8 hours')
  on conflict do nothing;
  update oyun.cuzdan set gun = (t at time zone 'Europe/Istanbul')::date, izle_n = 0, reklam_n = 0, reklam_kul = 0, bagis_bugun = 0
  where user_id = u and gun is distinct from (t at time zone 'Europe/Istanbul')::date;
  select * into c from oyun.cuzdan where user_id = u for update;
  return c;
end $$;

-- Cüzdana para ekle/çıkar (+ hareket kaydı). Yetersiz bakiyede hata verir.
create or replace function oyun.para_islem(u uuid, p_tutar numeric, p_tur text, p_aciklama text, t timestamptz, p_vergi numeric default 0)
returns void language plpgsql as $$
begin
  perform oyun.cuzdanim(u);
  update oyun.cuzdan set para = para + round(p_tutar) where user_id = u and para + round(p_tutar) >= 0;
  if not found then
    raise exception 'Cüzdanında yeterli para yok (% ₺ gerekli, cüzdanında % ₺ var).', oyun.tl(abs(p_tutar)),
      oyun.tl((select para from oyun.cuzdan where user_id = u));
  end if;
  insert into oyun.hesap_hareket(user_id, zaman, tutar, vergi, tur, aciklama) values (u, t, round(p_tutar), round(p_vergi), p_tur, p_aciklama);
end $$;

create or replace function oyun.tasinma_ucreti(p_kaynak smallint, p_hedef smallint, t timestamptz) returns numeric language sql stable as $$
  select round(5000 * u.endeks * (1 - least(90, u.tasinma_destek
                + greatest(oyun.bonus(p_kaynak, 'tasinma', t), oyun.bonus(p_hedef, 'tasinma', t))) / 100))
  from oyun.ulke u where u.id = 1
$$;
create or replace function oyun.il_bekleme_gun(t timestamptz) returns int language sql stable as $$
  select least((select il_degis_gun from oyun.ayarlar where id = 1),
               coalesce((select min(deger)::int from oyun.etkiler where tur = 'il_bekleme' and il_id is null and bas <= t and bit > t),
                        (select il_degis_gun from oyun.ayarlar where id = 1)))
$$;
create or replace function oyun.reklam_fiyat() returns numeric language sql stable as $$
  select round(1500 * endeks) from oyun.ulke where id = 1
$$;

-- Aday adaylığı ücreti: taban × fiyat düzeyi × partinin çarpanı (genel başkan belirler)
create or replace function oyun.aday_ucreti(p_parti bigint, p_tur text, p_il smallint) returns numeric language sql stable as $$
  select round((case p_tur when 'mv_on' then 5000 when 'kurultay' then 10000 when 'cb_on' then 20000
                  when 'bel_on' then 3000 * coalesce((select case when mv >= 14 then 3 when mv >= 8 then 2 else 1 end from oyun.iller where id = p_il), 1)
                  else 0 end)
               * (select endeks from oyun.ulke where id = 1)
               * coalesce((select (aday_ucret ->> p_tur)::numeric from oyun.partiler where id = p_parti), 1))
$$;

-- aday_ol içinden çağrılır: ücret oyuncudan alınır, parti kasasına girer
create or replace function oyun.aday_ucreti_al(p oyun.profiller, p_tur text, t timestamptz) returns numeric language plpgsql as $$
declare ucret numeric := oyun.aday_ucreti(p.parti_id, p_tur, p.il_id); pk text := (select kisa from oyun.partiler where id = p.parti_id);
        fon numeric := round(oyun.aday_ucreti(p.parti_id, p_tur, p.il_id) * oyun.duz('aday_destek') / 100);
begin
  if ucret <= 0 then return 0; end if;
  -- Siyasi katılım fonu (mevzuat): ücretin bir kısmını hazine öder, parti kasasına tamamı girer
  perform oyun.para_islem(p.id, -(ucret - fon), 'aday', format('%s %s başvuru ücreti%s', pk,
    case p_tur when 'mv_on' then 'milletvekili aday adaylığı' when 'bel_on' then 'belediye başkanı aday adaylığı'
               when 'kurultay' then 'genel başkanlık adaylığı' else 'cumhurbaşkanı aday adaylığı' end,
    case when fon > 0 then format(' (%s ₺''sini siyasi katılım fonu ödedi)', oyun.tl(fon)) else '' end), t);
  update oyun.partiler set kasa = kasa + ucret where id = p.parti_id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (p.parti_id, t, ucret, format('%s başvuru ücreti ödedi', p.kad), 'aday');
  return ucret;
end $$;

-- ---------------------------------------------------------------------
-- GELİR HESABI (kumbara)
-- ---------------------------------------------------------------------
create or replace function oyun.gelir_hesap(u uuid, t timestamptz) returns jsonb language plpgsql stable as $$
declare p oyun.profiller; c oyun.cuzdan; ul oyun.ulke; st jsonb; ilc numeric; ub numeric; seri_y int; seri_b numeric;
        maas numeric; makam numeric; brut numeric; vergi numeric; kent numeric; gecim numeric; gecim_ind numeric; net numeric;
        saat numeric; v_hiz numeric := coalesce((select maas_hizi from oyun.ayarlar where id = 1), 1); bugun date := (t at time zone 'Europe/Istanbul')::date; destek numeric := 0; hem numeric := 0; asg_saat numeric; kv numeric;
begin
  select * into p from oyun.profiller where id = u;
  select * into c from oyun.cuzdan where user_id = u;
  select * into ul from oyun.ulke where id = 1;
  st := oyun.statu_json(u);
  ilc := oyun.il_carpan(p.il_id);
  ub := oyun.bonus(p.il_id, 'ucret', t) + case when (st ->> 'basamak')::int <= 1 then oyun.bonus(p.il_id, 'ucret_yeni', t) else 0 end;
  -- seri: bir sonraki (ya da bugünkü) toplamada geçerli olan seri
  seri_y := case when c.seri_gun = bugun then c.seri when c.seri_gun = bugun - 1 then c.seri + 1 else 1 end;
  seri_b := least(oyun.duz('seri_tavan'), 5 * (seri_y - 1));
  asg_saat := ul.asgari / 720;
  maas := asg_saat * v_hiz * (st ->> 'carpan')::numeric * ilc * (1 + ub / 100);
  -- Meclis devamsızlık kesintisi (mevzuat): vekilin katılmadığı oylamalar oranında
  makam := coalesce((select sum(oyun.makam_maasi(m.tur, m.il_id) * case when m.tur = 'mv' then 1 - oyun.vekil_kesinti_orani(u, t) / 100 else 1 end)
                     from oyun.makamlar m where m.user_id = u and m.bit is null), 0) / 720;
  brut := (maas + makam) * (1 + seri_b / 100);
  vergi := greatest(0, brut - asg_saat) * ul.vergi / 100;                 -- asgari ücret gelir vergisinden muaftır
  kv := (select kent_vergisi from oyun.il_durum where il_id = p.il_id);
  kent := brut * kv / 100;
  gecim_ind := least(60, oyun.bonus(p.il_id, 'gecim', t));
  gecim := 350.0 / 24 * ul.endeks * (1 - gecim_ind / 100);
  net := greatest(0, brut - vergi - kent - gecim);
  saat := least(oyun.kumbara_saat(), greatest(0, extract(epoch from (t - c.son_toplama)) / 3600));
  if c.seri_gun is distinct from bugun then
    destek := case when (st ->> 'basamak')::int <= 1 then ul.destek else 0 end;
    hem := (select hemsehri from oyun.il_durum where il_id = p.il_id);
  end if;
  return jsonb_build_object(
    'saat', round(saat, 3), 'dolu', saat >= oyun.kumbara_saat(), 'dolma_an', c.son_toplama + make_interval(hours => oyun.kumbara_saat()::int),
    'kapasite', oyun.kumbara_saat(), 'seri_tavan', oyun.duz('seri_tavan'),
    'vekil_kesinti', case when exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv' and bit is null) then oyun.vekil_kesinti_orani(u, t) end,
    'birikmis', round(net * saat), 'brut_birikmis', round(brut * saat), 'vergi_birikmis', round(vergi * saat),
    'saatlik', jsonb_build_object('maas', round(maas, 2), 'makam', round(makam, 2), 'brut', round(brut, 2), 'vergi', round(vergi, 2),
                                  'kent', round(kent, 2), 'gecim', round(gecim, 2), 'net', round(net, 2)),
    'gunluk_net', round(net * 24), 'asgari', ul.asgari, 'statu_carpan', (st ->> 'carpan')::numeric, 'il_carpan', ilc,
    'ucret_bonus', ub, 'seri', seri_y, 'seri_bonus', seri_b, 'vergi_oran', ul.vergi, 'kent_oran', kv, 'gecim_indirim', gecim_ind,
    'gecim_gunluk', round(350 * ul.endeks * (1 - gecim_ind / 100)),
    'gunluk_destek', jsonb_build_object('devlet', destek, 'belediye', hem),
    'reklam_odul', round(maas * 2));
end $$;

-- Üst çubuk için kısa özet
create or replace function oyun.cuzdan_ozet(u uuid, t timestamptz) returns jsonb language plpgsql as $$
declare c oyun.cuzdan := oyun.cuzdanim(u); g jsonb := oyun.gelir_hesap(u, t);
begin
  return jsonb_build_object('para', c.para, 'birikmis', g -> 'birikmis', 'dolu', g -> 'dolu',
                            'gunun_ilki', c.seri_gun is distinct from (t at time zone 'Europe/Istanbul')::date);
end $$;

-- ---------------------------------------------------------------------
-- HAYAT EKRANI
-- ---------------------------------------------------------------------
create or replace function oyun.etkilerim(p_il smallint, t timestamptz) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(x order by x ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '1' || b.sira, 'kaynak', i.ad || ' Belediyesi · ' || b.ad, 'kaynak_tur', 'belediye', 'yerel', true,
                              'bit', null, 'etkiler', b.etki) x
      from oyun.il_hizmet h join oyun.belediye_hizmetleri b on b.kod = h.kod join oyun.iller i on i.id = h.il_id where h.il_id = p_il
    union all
    select jsonb_build_object('sira', '2' || to_char(max(e.bit), 'YYYYMMDDHH24MI'), 'kaynak', e.kaynak_ad, 'kaynak_tur', e.kaynak_tur,
                              'yerel', e.il_id is not null, 'bit', max(e.bit),
                              'etkiler', jsonb_agg(jsonb_build_object('tur', e.tur, 'deger', e.deger) order by e.id))
      from oyun.etkiler e where (e.il_id is null or e.il_id = p_il) and e.bas <= t and e.bit > t
      group by e.kaynak_ad, e.kaynak_tur, e.kaynak_kod, e.il_id
  ) y
$$;

create or replace function public.hayat() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; u oyun.ulke;
begin
  c := oyun.cuzdanim(p.id);
  select * into u from oyun.ulke where id = 1;
  return jsonb_build_object(
    'para', c.para, 'statu', oyun.statu_json(p.id), 'itibar', oyun.itibar_json(p.id), 'kumbara', oyun.gelir_hesap(p.id, t),
    'seri_gun', c.seri_gun, 'bugun_toplandi', c.seri_gun = (t at time zone 'Europe/Istanbul')::date, 'il_ad', (select ad from oyun.iller where id = p.il_id),
    'makamlar', coalesce((select jsonb_agg(jsonb_build_object('tur', m.tur, 'aylik', round(oyun.makam_maasi(m.tur, m.il_id))))
                          from oyun.makamlar m where m.user_id = p.id and m.bit is null), '[]'::jsonb),
    'reklam', jsonb_build_object('kalan', greatest(0, 5 - c.izle_n),
                                 'hazir', case when c.son_izle > t - interval '60 seconds' then c.son_izle + interval '60 seconds' end),
    'fiyat', jsonb_build_object('tasinma', oyun.tasinma_ucreti(p.il_id, p.il_id, t), 'reklam', oyun.reklam_fiyat(), 'endeks', round(u.endeks, 3)),
    'ek_yayin', jsonb_build_object('kalan_alim', greatest(0, 3 - c.reklam_n), 'elde', greatest(0, c.reklam_n - c.reklam_kul)),
    'bagis', jsonb_build_object('bugun', c.bagis_bugun, 'tavan', u.asgari),
    'ulke', jsonb_build_object('asgari', u.asgari, 'vergi', u.vergi, 'destek', u.destek, 'kidem_primi', u.kidem_primi,
                               'enflasyon', round(u.enflasyon, 1), 'tasinma_destek', u.tasinma_destek),
    'etkiler', oyun.etkilerim(p.il_id, t), 'banka', oyun.banka_ozet(p.id),
    'mulkler', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'tur', m.tur, 'bedel', m.bedel, 'gunluk', m.gunluk) order by m.alis)
                         from oyun.mulkler m join oyun.iller i on i.id = m.il_id where m.user_id = p.id), '[]'::jsonb),
    'paketler', (select jsonb_agg(jsonb_build_object('urun_id', urun_id, 'ad', ad, 'miktar', miktar) order by sira) from oyun.paketler),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'vergi', h.vergi, 'tur', h.tur, 'aciklama', h.aciklama)
                    order by h.zaman desc, h.id desc)
                  from (select * from oyun.hesap_hareket where user_id = p.id order by zaman desc, id desc limit 25) h), '[]'::jsonb));
end $$;

-- Kumbarayı topla. Günün ilk toplamasında: seri ve kıdem işlenir, günlük destekler yatar.
create or replace function public.topla() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; g jsonb; bugun date := (t at time zone 'Europe/Istanbul')::date;
        tutar numeric; ilk boolean; des numeric := 0; hem numeric := 0; kx numeric; once int; sonra int;
begin
  c := oyun.cuzdanim(p.id);
  g := oyun.gelir_hesap(p.id, t);
  tutar := (g ->> 'birikmis')::numeric;
  ilk := c.seri_gun is distinct from bugun;
  if tutar < 1 and not ilk then raise exception 'Kumbaran henüz boş. Maaşın saat saat birikiyor.'; end if;
  once := oyun.statu_basamak(oyun.kidem_puani(p.id));
  if tutar >= 1 then
    perform oyun.para_islem(p.id, tutar, 'maas',
      format('Maaş (%s saat%s)', replace(round((g ->> 'saat')::numeric, 1)::text, '.', ','),
             case when (g ->> 'seri_bonus')::numeric > 0 then format(', seri +%%%s', g ->> 'seri_bonus') else '' end),
      t, (g ->> 'vergi_birikmis')::numeric);
    perform oyun.haciz_uygula(p.id, tutar, t);   -- takipteki kredi: maaşın yarısına haciz (15_ekonomi3)
  end if;
  if ilk then
    kx := 1 + oyun.bonus(p.il_id, 'kidem_x', t) / 100;
    update oyun.cuzdan set seri = (g ->> 'seri')::int, seri_gun = bugun, kidem = kidem + kx where user_id = p.id;
    des := (g -> 'gunluk_destek' ->> 'devlet')::numeric; hem := (g -> 'gunluk_destek' ->> 'belediye')::numeric;
    if des > 0 then perform oyun.para_islem(p.id, des, 'destek', 'Devlet sosyal desteği (günlük)', t); end if;
    if hem > 0 then perform oyun.para_islem(p.id, hem, 'hemsehri', (select ad from oyun.iller where id = p.il_id) || ' Belediyesi hemşehri desteği', t); end if;
    perform oyun.gunluk_kesinti(p.id, t);       -- servet vergisi ve emlak vergisi (mevzuat)
  end if;
  update oyun.cuzdan set son_toplama = t, kumbara_bildirim = null where user_id = p.id;
  sonra := oyun.statu_basamak(oyun.kidem_puani(p.id));
  if sonra > once then
    perform oyun.bildir(p.id, format('Tebrikler! Statün yükseldi: %s. Maaşın arttı.', oyun.statu_ad(sonra)), t);
  end if;
  return public.hayat() || jsonb_build_object('sonuc', jsonb_build_object('maas', tutar, 'ilk', ilk, 'seri', (g ->> 'seri')::int,
    'destek', des + hem, 'statu_atladi', sonra > once));
end $$;

-- Ödüllü reklam izlendi (uygulama reklam bitince çağırır): 2 saatlik maaş, günde 5, en az 60 sn arayla
create or replace function public.reklam_odul() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; odul numeric;
begin
  c := oyun.cuzdanim(p.id);
  if c.izle_n >= 5 then raise exception 'Bugünkü reklam ödüllerini aldın. Yarın yeniden gel.'; end if;
  if c.son_izle is not null and c.son_izle > t - interval '60 seconds' then raise exception 'Bir sonraki reklam için biraz bekle.'; end if;
  odul := (oyun.gelir_hesap(p.id, t) ->> 'reklam_odul')::numeric;
  update oyun.cuzdan set izle_n = izle_n + 1, son_izle = t where user_id = p.id;
  perform oyun.para_islem(p.id, odul, 'reklam_odul', 'Reklam izleme ödülü', t);
  return public.hayat() || jsonb_build_object('sonuc', jsonb_build_object('odul', odul));
end $$;

-- Ek propaganda hakkı (günde en fazla 3; yalnızca yayın yetkisi olanlar)
create or replace function public.reklam_al() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; fiyat numeric := oyun.reklam_fiyat();
begin
  if not exists (select 1 from oyun.yayin_secenekleri(p, t)) then raise exception 'Yayın yetkin olmadığı için ek hak alamazsın.'; end if;
  c := oyun.cuzdanim(p.id);
  if c.reklam_n >= 3 then raise exception 'Bugün en fazla 3 ek yayın hakkı alabilirsin.'; end if;
  perform oyun.para_islem(p.id, -fiyat, 'reklam', 'Ek propaganda yayını hakkı', t);
  update oyun.cuzdan set reklam_n = reklam_n + 1 where user_id = p.id;
  return jsonb_build_object('tamam', true, 'ek_yayin', c.reklam_n + 1 - c.reklam_kul);
end $$;

-- ---------------------------------------------------------------------
-- SATIN ALMA (RevenueCat webhook → odeme-webhook sunucu fonksiyonu → odeme_isle; yalnız service_role)
-- ---------------------------------------------------------------------
create or replace function public.magaza() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('urun_id', urun_id, 'ad', ad, 'miktar', miktar) order by sira), '[]'::jsonb) from oyun.paketler
$$;

create or replace function public.odeme_isle(p_olay jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare e jsonb := coalesce(p_olay -> 'event', p_olay); tur text := e ->> 'type'; u uuid; pk oyun.paketler; islem text; s oyun.satin_almalar; dus numeric;
begin
  islem := coalesce(e ->> 'transaction_id', e ->> 'original_transaction_id', e ->> 'id');
  if tur = 'TEST' then return jsonb_build_object('durum', 'test'); end if;
  begin u := (e ->> 'app_user_id')::uuid; exception when others then return jsonb_build_object('durum', 'kullanici_yok'); end;
  if not exists (select 1 from oyun.profiller where id = u) then return jsonb_build_object('durum', 'kullanici_yok'); end if;
  if tur in ('NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE') then
    select * into pk from oyun.paketler where urun_id = e ->> 'product_id';
    if pk.urun_id is null then return jsonb_build_object('durum', 'urun_yok'); end if;
    if islem is null then return jsonb_build_object('durum', 'islem_yok'); end if;
    insert into oyun.satin_almalar(islem_id, user_id, urun_id, miktar, olay) values (islem, u, pk.urun_id, pk.miktar, e)
    on conflict (islem_id) do nothing;
    if not found then return jsonb_build_object('durum', 'zaten_islendi'); end if;
    perform oyun.para_islem(u, pk.miktar, 'satin_alma', pk.ad || ' (satın alma)', oyun.simdi());
    perform oyun.bildir(u, format('Satın alma tamamlandı: cüzdanına %s ₺ eklendi. Teşekkürler!', oyun.tl(pk.miktar)), oyun.simdi());
    return jsonb_build_object('durum', 'eklendi', 'miktar', pk.miktar);
  elsif tur = 'CANCELLATION' then
    -- mağaza iadesi: eklenen para (cüzdanda kaldığı kadarıyla) geri alınır
    select * into s from oyun.satin_almalar where islem_id = islem for update;
    if s.id is null or s.iade then return jsonb_build_object('durum', 'yok_say'); end if;
    perform oyun.cuzdanim(u);
    dus := least(s.miktar, (select para from oyun.cuzdan where user_id = u));
    update oyun.satin_almalar set iade = true where id = s.id;
    if dus > 0 then perform oyun.para_islem(u, -dus, 'iade', 'Mağaza iadesi', oyun.simdi()); end if;
    return jsonb_build_object('durum', 'iade', 'dusulen', dus);
  end if;
  return jsonb_build_object('durum', 'yok_say');
end $$;

-- ---------------------------------------------------------------------
-- PARTİ KASASI
-- ---------------------------------------------------------------------
-- Bağış: kişi başı günde en fazla 1 aylık asgari ücret (Siyasi Partiler Kanunu'ndaki bağış sınırı gibi)
create or replace function public.bagis_yap(p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); c oyun.cuzdan; tavan numeric;
begin
  if p.parti_id is null then raise exception 'Bağış için bir partiye üye olmalısın.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ bağışlayabilirsin.'; end if;
  perform oyun.takip_engel(p.id, 'bağış yapamazsın');
  c := oyun.cuzdanim(p.id);
  tavan := (select asgari from oyun.ulke where id = 1);
  if c.bagis_bugun + m > tavan then
    raise exception 'Bağış sınırı: kişi başı günde en fazla % ₺ (bugün % ₺ bağışladın).', oyun.tl(tavan), oyun.tl(c.bagis_bugun);
  end if;
  perform oyun.para_islem(p.id, -m, 'bagis', format('%s partisine bağış', (select kisa from oyun.partiler where id = p.parti_id)), t);
  update oyun.cuzdan set bagis_bugun = bagis_bugun + m, kidem = kidem + m / tavan where user_id = p.id;   -- her asgari ücret tutarında bağış 1 kıdem puanı
  update oyun.partiler set kasa = kasa + m where id = p.parti_id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (p.parti_id, t, m, format('%s bağış yaptı', p.kad), 'bagis');
  return public.parti_kasa(p.parti_id);
end $$;

create or replace function public.parti_destek(p_kad text, p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; pa oyun.partiler; m numeric := round(coalesce(p_miktar, 0));
begin
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.gb is distinct from p.id then raise exception 'Parti kasasını yalnızca genel başkan kullanabilir.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pa.id then raise exception 'Yalnızca kendi partinin üyelerine destek verebilirsin.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ destek verebilirsin.'; end if;
  if pa.kasa < m then raise exception 'Parti kasasında yeterli para yok (kasada % ₺ var).', oyun.tl(pa.kasa); end if;
  update oyun.partiler set kasa = kasa - m where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -m, format('%s üyesine kampanya desteği', h.kad), 'destek');
  perform oyun.para_islem(h.id, m, 'parti_destek', format('%s kampanya desteği', pa.kisa), t);
  perform oyun.bildir(h.id, format('Genel Başkan %s, parti kasasından sana %s ₺ kampanya desteği gönderdi.', p.kad, oyun.tl(m)), t);
  return public.parti_kasa(pa.id);
end $$;

-- Genel başkan aday adaylığı ücretlerinin çarpanlarını belirler (0-3)
create or replace function public.parti_ucret_ayarla(p_ucret jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; k text; v jsonb := '{}'; x numeric;
begin
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.gb is distinct from p.id then raise exception 'Aday ücretlerini yalnızca genel başkan belirler.'; end if;
  foreach k in array array['mv_on','bel_on','kurultay','cb_on'] loop
    x := round(coalesce((p_ucret ->> k)::numeric, (pa.aday_ucret ->> k)::numeric, 1), 2);
    if x < 0 or x > 3 then raise exception 'Çarpanlar 0 ile 3 arasında olmalı.'; end if;
    v := v || jsonb_build_object(k, x);
  end loop;
  update oyun.partiler set aday_ucret = v where id = pa.id;
  perform oyun.olay('parti', format('%s aday adaylığı ücretlerini güncelledi.', pa.kisa), null, pa.id, t);
  return public.parti_kasa(pa.id);
end $$;

-- Son genel seçimde %3'ü geçen partiler, oy oranına göre hazine yardımı alır
create or replace function oyun.parti_yardim_paylari() returns table(parti_id bigint, oran numeric) language sql stable as $$
  with s as (select id from oyun.secimler where tur = 'mv' and durum <> 'bekliyor' order by oy_bit desc limit 1),
       o as (select o.parti_id, count(*)::numeric n from oyun.oylar o join s on s.id = o.secim_id where o.parti_id is not null group by o.parti_id),
       tp as (select sum(n) toplam from o),
       g as (select o.parti_id, o.n from o, tp where o.n * 100 / tp.toplam >= 3
             and exists (select 1 from oyun.partiler pa where pa.id = o.parti_id and not pa.kapali))
  select g.parti_id, g.n / sum(g.n) over () from g
$$;
create or replace function oyun.parti_yardim_payi(p_parti bigint) returns numeric language sql stable as $$
  select coalesce(round((select oran from oyun.parti_yardim_paylari() where parti_id = p_parti) * (select parti_yardim from oyun.ulke where id = 1)), 0)
$$;

create or replace function public.parti_kasa(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  return jsonb_build_object('kasa', round(pa.kasa), 'gb_mi', pa.gb = p.id, 'uye_mi', p.parti_id = pa.id,
    'hazine_yardimi', oyun.parti_yardim_payi(pa.id), 'carpanlar', pa.aday_ucret,
    'ucretler', jsonb_build_object('mv_on', oyun.aday_ucreti(pa.id, 'mv_on', p.il_id), 'bel_on', oyun.aday_ucreti(pa.id, 'bel_on', p.il_id),
                                   'kurultay', oyun.aday_ucreti(pa.id, 'kurultay', null), 'cb_on', oyun.aday_ucreti(pa.id, 'cb_on', null)),
    'beyanname', oyun.beyanname_json(pa.id, null), 'iktidar', oyun.iktidar_karnesi(pa.id),
    'beyanname_acik', exists (select 1 from oyun.secimler where tur = 'mv' and durum = 'bekliyor' and oyun.simdi() < oy_bit),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'aciklama', h.aciklama) order by h.zaman desc, h.id desc)
                            from (select * from oyun.parti_hareket where parti_id = pa.id order by zaman desc, id desc limit 15) h), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- GÜNLÜK ÖDEMELER (her gece): partilere hazine yardımı, temizlik
-- ---------------------------------------------------------------------
create or replace function oyun.gunluk_odemeler(g date, t timestamptz) returns void language plpgsql as $$
declare u oyun.ulke; r record; tutar numeric;
begin
  select * into u from oyun.ulke where id = 1;
  if u.parti_yardim > 0 then
    for r in select * from oyun.parti_yardim_paylari() loop
      tutar := round(r.oran * u.parti_yardim);
      continue when tutar <= 0;
      update oyun.partiler set kasa = kasa + tutar where id = r.parti_id;
      insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (r.parti_id, t, tutar, 'Hazine yardımı (' || to_char(g, 'DD.MM') || ')', 'yardim');
    end loop;
  end if;
  delete from oyun.hesap_hareket where zaman < t - interval '60 days';
  delete from oyun.parti_hareket where zaman < t - interval '90 days';
  delete from oyun.etkiler where bit < t - interval '30 days';
end $$;

-- Kumbarası dolan oyuncuya telefon bildirimi (dolum başına bir kez; 3 günden uzun süredir girmeyenlere gönderilmez)
create or replace function oyun.kumbara_hatirlat(t timestamptz) returns void language plpgsql as $$
declare r record;
begin
  for r in select c.user_id from oyun.cuzdan c
           where c.son_toplama <= t - make_interval(hours => oyun.kumbara_saat()::int) and c.son_toplama > t - interval '3 days'
             and (c.kumbara_bildirim is null or c.kumbara_bildirim < c.son_toplama)
             and exists (select 1 from oyun.cihazlar d where d.user_id = c.user_id) loop
    perform oyun.push_kisiye(r.user_id, 'kisisel', 'Kumbaran doldu 💰', format('Maaşın %s saattir birikiyor. Toplamazsan birikme durur.', oyun.kumbara_saat()), '{"ekran":"hayat"}');
    update oyun.cuzdan set kumbara_bildirim = t where user_id = r.user_id;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- POLİTİKALAR (yürütme)
-- ---------------------------------------------------------------------
create or replace function oyun.politika_tanim() returns table(kod text, ad text, birim text, bakanlik text, bekleme_gun int, aciklama text)
language sql immutable as $$
  values ('asgari','Asgari ücret','tl_ay','calisma',7,'Herkesin maaşının tabanı. Düşürülemez; bir seferde en fazla %30 artırılabilir. Ekonominin kaldırabileceğinin üstüne çıkarsa enflasyon yükselir.'),
         ('kidem_primi','Kıdem primi','yuzde','calisma',7,'Her statü basamağının maaşa eklediği prim (%0-20). Yüksek prim enflasyonu biraz artırır.'),
         ('destek','Sosyal destek','tl_gun','calisma',3,'Yeni Gelen ve Vatandaş statüsündekilere günlük destek (0-1.000 ₺). 8 milyon kişiye ödenir.'),
         ('vergi','Gelir vergisi','yuzde','maliye',3,'Asgari ücretin üstündeki kazançtan kesilir. Meclis''in bütçe kanunundaki bant içinde, bir seferde en fazla 5 puan değişir.'),
         ('tasinma_destek','Taşınma desteği','yuzde','ulastirma',7,'İl değiştirirken ödenen masrafın devletin karşıladığı kısmı (%0-80).')
$$;

create or replace function oyun.politika_sinir(p_kod text) returns table(alt numeric, ust numeric) language sql stable as $$
  select case p_kod when 'asgari' then u.asgari when 'vergi' then greatest(u.vergi_alt, u.vergi - 5) else 0 end,
         case p_kod when 'asgari' then round(u.asgari * 1.3) when 'kidem_primi' then 20 when 'destek' then 1000
                    when 'vergi' then least(u.vergi_ust, u.vergi + 5) when 'tasinma_destek' then 80 end
  from oyun.ulke u where u.id = 1
$$;

create or replace function oyun.politika_deger(p_kod text) returns numeric language sql stable as $$
  select case p_kod when 'asgari' then asgari when 'kidem_primi' then kidem_primi when 'destek' then destek
                    when 'vergi' then vergi when 'tasinma_destek' then tasinma_destek end from oyun.ulke where id = 1
$$;

create or replace function oyun.politika_listesi(p_bakanlik text, t timestamptz) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'bakanlik', d.bakanlik, 'aciklama', d.aciklama,
           'deger', oyun.politika_deger(d.kod), 'alt', s.alt, 'ust', s.ust, 'bekleme_gun', d.bekleme_gun,
           'hazir', (select max(k.zaman) + make_interval(days => d.bekleme_gun) from oyun.politika_kayit k where k.kod = d.kod
                     having max(k.zaman) + make_interval(days => d.bekleme_gun) > t))
         order by d.bakanlik, d.kod), '[]'::jsonb)
  from oyun.politika_tanim() d, lateral oyun.politika_sinir(d.kod) s
  where p_bakanlik is null or d.bakanlik = p_bakanlik
$$;

-- Bir politika değişikliğinin bütçeye (günlük, milyar ₺; + maliyet / − gelir) ve enflasyona etkisi
create or replace function oyun.politika_etki(p_kod text, p_deger numeric) returns jsonb language plpgsql stable as $$
declare u oyun.ulke; u2 oyun.ulke; enf numeric := 0;
begin
  select * into u from oyun.ulke where id = 1;
  u2 := u;
  if p_kod = 'asgari' then u2.asgari := p_deger;
    enf := (greatest(0, p_deger / u.asgari_ref - 1) - greatest(0, u.asgari / u.asgari_ref - 1)) * 40;
  elsif p_kod = 'vergi' then u2.vergi := p_deger;
  elsif p_kod = 'destek' then u2.destek := p_deger; enf := (p_deger - u.destek) / 100;
  elsif p_kod = 'kidem_primi' then enf := (p_deger - u.kidem_primi) * 0.15;
  end if;
  return jsonb_build_object('gunluk', round((oyun.ulke_hesap(u) ->> 'denge')::numeric - (oyun.ulke_hesap(u2) ->> 'denge')::numeric, 3),
                            'enflasyon', round(enf, 2));
end $$;

create or replace function public.politika_onizle(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  return oyun.politika_etki(p_kod, p_deger) || jsonb_build_object('mali_alan', oyun.mali_alan());
end $$;

create or replace function public.politika_ayarla(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d record; s record; eski numeric; yeni numeric; son timestamptz;
        mk text; unvan text; bas text;
begin
  select * into d from oyun.politika_tanim() x where x.kod = p_kod;
  if d.kod is null then raise exception 'Geçersiz politika.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null) then mk := 'cb'; unvan := 'Cumhurbaşkanı';
  elsif exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'bakan' and bakanlik = d.bakanlik and bit is null) then
    mk := 'bakan'; unvan := (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = d.bakanlik);
  else raise exception 'Bu ayarı yalnızca cumhurbaşkanı ve ilgili bakan yapabilir.'; end if;
  select * into s from oyun.politika_sinir(p_kod);
  eski := oyun.politika_deger(p_kod);
  yeni := case when d.birim in ('tl_ay','tl_gun') then round(p_deger) else round(p_deger, 1) end;
  if yeni is null or yeni = eski then raise exception 'Yeni değer mevcut değerle aynı.'; end if;
  if yeni < s.alt or yeni > s.ust then
    raise exception '% şu an % ile % arasında ayarlanabilir.', d.ad, oyun.birim_yaz(s.alt, d.birim), oyun.birim_yaz(s.ust, d.birim);
  end if;
  select max(zaman) into son from oyun.politika_kayit where kod = p_kod;
  if son is not null and son + make_interval(days => d.bekleme_gun) > t then
    raise exception '% en erken % tarihinde yeniden değiştirilebilir.', d.ad, to_char((son + make_interval(days => d.bekleme_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  execute format('update oyun.ulke set %I = $1 where id = 1', p_kod) using yeni;
  insert into oyun.politika_kayit(kod, eski, yeni, user_id, makam, zaman) values (p_kod, eski, yeni, p.id, mk, t);
  bas := format('%s: %s → %s', d.ad, oyun.birim_yaz(eski, d.birim), oyun.birim_yaz(yeni, d.birim));
  perform oyun.gazete_ekle(case when mk = 'cb' then 'kararname' else 'icraat' end, bas, format('%s %s tarafından belirlendi.', unvan, p.kad), null, t);
  perform oyun.olay('ekonomi', format('%s %s: %s', unvan, p.kad, bas), null, p.parti_id, t);
  return jsonb_build_object('tamam', true, 'kod', p_kod, 'eski', eski, 'yeni', yeni);
end $$;

-- ---------------------------------------------------------------------
-- MALİ ALAN VE VAAT MALİYETİ
-- ---------------------------------------------------------------------
-- Ülkenin vaatlere ayırabileceği günlük alan (milyar ₺): bütçe fazlası + hazinenin 60'ta biri
create or replace function oyun.mali_alan() returns numeric language sql stable as $$
  select round(greatest(0, (oyun.ulke_hesap(u) ->> 'denge')::numeric) + greatest(0, u.hazine) / 60, 3) from oyun.ulke u where u.id = 1
$$;

-- Tek bir vaadin günlük maliyeti (milyar ₺; gb için ₺) ve enflasyon etkisi
create or replace function oyun.vaat_maliyet(p_kapsam text, p_kod text, p_hedef numeric, p_il smallint, p_parti bigint) returns jsonb
language plpgsql stable as $$
declare u oyun.ulke; d oyun.il_durum; m numeric := 0; enf numeric := 0; e jsonb; mal numeric;
begin
  select * into u from oyun.ulke where id = 1;
  if p_kapsam = 'beyanname' then
    if p_kod in ('asgari','vergi','destek','kidem','tasinma') then
      e := oyun.politika_etki(case p_kod when 'kidem' then 'kidem_primi' when 'tasinma' then 'tasinma_destek' else p_kod end, p_hedef);
      m := (e ->> 'gunluk')::numeric; enf := (e ->> 'enflasyon')::numeric;
    elsif p_kod = 'ikramiye' then m := p_hedef * oyun.nufus('ikramiye') / 1e9 / 30;
    elsif exists (select 1 from oyun.duzenleme_tanim where kod = p_kod and kapsam = 'ulke') then
      e := oyun.duzenleme_etki(p_kod, p_hedef);
      m := (e ->> 'gunluk')::numeric; enf := (e ->> 'enflasyon')::numeric;
    elsif p_kod = 'ozellestirme' then m := -10.0 / 30;
    elsif p_kod = 'referandum' then m := 0;
    else
      select maliyet into mal from oyun.icraatlar where kod = p_kod;
      m := coalesce(mal, 0) / 7;
    end if;
  elsif p_kapsam = 'mv' then
    if p_kod = 'vergi_tavan' and p_hedef < u.vergi then m := (oyun.politika_etki('vergi', p_hedef) ->> 'gunluk')::numeric;
    elsif p_kod = 'belediye_payi' and p_hedef > u.belediye_payi then
      m := (oyun.ulke_hesap(u) ->> 'belediye')::numeric * (p_hedef - u.belediye_payi) / u.belediye_payi;
    elsif exists (select 1 from oyun.duzenleme_tanim where kod = p_kod and kapsam = 'ulke') then
      e := oyun.duzenleme_etki(p_kod, p_hedef);
      m := (e ->> 'gunluk')::numeric; enf := (e ->> 'enflasyon')::numeric;
    end if;
  elsif p_kapsam = 'bel' then
    select * into d from oyun.il_durum where il_id = p_il;
    if p_kod = 'kent_vergisi' and p_hedef < d.kent_vergisi then m := oyun.il_gelir(p_il) * (1 - (1 + p_hedef / 10) / (1 + d.kent_vergisi / 10));
    elsif p_kod = 'kent_vergisi' and p_hedef > d.kent_vergisi then m := -oyun.il_gelir(p_il) * ((1 + p_hedef / 10) / (1 + d.kent_vergisi / 10) - 1);
    elsif p_kod = 'hemsehri' and p_hedef > d.hemsehri then m := oyun.hemsehri_gider(p_il, p_hedef - d.hemsehri);
    elsif p_kod in ('lokanta','ulasim','kira','istihdam') and not exists (select 1 from oyun.il_hizmet where il_id = p_il and kod = p_kod) then
      m := oyun.hizmet_gider(p_il, p_kod);
    elsif p_kod = 'emlak' then
      m := -(p_hedef - oyun.il_duz(p_il, 'emlak')) * u.endeks * oyun.nufus('il_hane') * (select mv from oyun.iller where id = p_il) / 600 / 1e9;
    elsif p_kod = 'hosgeldin' then m := greatest(0, p_hedef - oyun.il_duz(p_il, 'hosgeldin')) * 2000 / 1e9;
    elsif p_kod = 'imar_barisi' then m := -4 * oyun.il_gunluk_gelir((select mv from oyun.iller where id = p_il)) * u.endeks / 30;
    elsif p_kod in ('altyapi','rayli') then
      m := (select gun from oyun.belediye_yatirimlari where kod = p_kod) * oyun.il_gunluk_gelir((select mv from oyun.iller where id = p_il)) * u.endeks / 30;
    end if;
  elsif p_kapsam = 'gb' then
    if p_kod = 'kampanya' then m := p_hedef / 30; end if;
  end if;
  return jsonb_build_object('gunluk', round(m, 4), 'enflasyon', round(enf, 2));
end $$;

create or replace function oyun.vaat_alani(p_kapsam text, p_il smallint, p_parti bigint) returns numeric language sql stable as $$
  select case p_kapsam when 'bel' then oyun.il_mali_alan(p_il)
                       when 'gb' then coalesce((select kasa from oyun.partiler where id = p_parti), 0) / 30 + oyun.parti_yardim_payi(p_parti)
                       else oyun.mali_alan() end
$$;

-- Bir vaat listesinin toplamı ve karşılanabilirliği
create or replace function oyun.vaat_degerlendir_liste(p_kapsam text, p_il smallint, p_parti bigint, p_vaatler jsonb) returns jsonb
language plpgsql stable as $$
declare v jsonb; tur oyun.vaat_turleri; c jsonb; liste jsonb := '[]'; toplam numeric := 0; enf numeric := 0; alan numeric := oyun.vaat_alani(p_kapsam, p_il, p_parti); hedef numeric;
begin
  for v in select * from jsonb_array_elements(coalesce(p_vaatler, '[]')) loop
    select * into tur from oyun.vaat_turleri where kapsam = p_kapsam and kod = v ->> 'kod';
    if tur.kod is null then raise exception 'Geçersiz vaat: %', v ->> 'kod'; end if;
    hedef := nullif(v ->> 'hedef', '')::numeric;
    if tur.birim <> 'yok' then
      if hedef is null then raise exception '"%" için bir hedef değer girmelisin.', tur.ad; end if;
      if (tur.min is not null and hedef < tur.min) or (tur.max is not null and hedef > tur.max) then
        raise exception '"%" için hedef % ile % arasında olmalı.', tur.ad, oyun.birim_yaz(tur.min, tur.birim), oyun.birim_yaz(tur.max, tur.birim);
      end if;
      if tur.kod = 'asgari' and hedef <= (select asgari from oyun.ulke where id = 1) then raise exception 'Asgari ücret vaadi bugünkünden yüksek olmalı.'; end if;
    else hedef := null; end if;
    c := oyun.vaat_maliyet(p_kapsam, tur.kod, hedef, p_il, p_parti);
    toplam := toplam + (c ->> 'gunluk')::numeric; enf := enf + (c ->> 'enflasyon')::numeric;
    liste := liste || jsonb_build_object('kod', tur.kod, 'ad', tur.ad, 'hedef', hedef, 'birim', tur.birim,
                                         'hedef_yazi', case when hedef is not null then oyun.birim_yaz(hedef, tur.birim) end,
                                         'gunluk', c -> 'gunluk', 'enflasyon', c -> 'enflasyon');
  end loop;
  return jsonb_build_object('vaatler', liste, 'toplam', round(toplam, 4), 'enflasyon', round(enf, 2), 'alan', round(alan, 4),
    'birim', case p_kapsam when 'gb' then 'tl' else 'milyar' end,
    'karar', case when toplam <= alan * 0.5 and enf <= 3 then 'karsilanabilir'
                  when toplam <= alan and enf <= 6 then 'zorlayici' else 'karsiliksiz' end);
end $$;

-- Vaat seçenekleri ekranı: katalog + bugünkü değerler + mali alan
create or replace function public.vaat_secenekleri(p_kapsam text, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); u oyun.ulke; d oyun.il_durum; il smallint := coalesce(p_il, p.il_id)::smallint;
begin
  select * into u from oyun.ulke where id = 1;
  select * into d from oyun.il_durum where il_id = il;
  return jsonb_build_object('kapsam', p_kapsam, 'il_id', il, 'il_ad', (select ad from oyun.iller where id = il),
    'en_fazla', case p_kapsam when 'beyanname' then 5 when 'bel' then 4 when 'mv' then 3 else 2 end,
    'alan', oyun.vaat_alani(p_kapsam, il, p.parti_id), 'birim', case p_kapsam when 'gb' then 'tl' else 'milyar' end,
    'turler', (select jsonb_agg(jsonb_build_object('kod', t.kod, 'ad', t.ad, 'birim', t.birim, 'tip', t.tip, 'min', t.min, 'max', t.max, 'aciklama', t.aciklama,
                 'mevcut', case t.kod when 'asgari' then u.asgari when 'vergi' then u.vergi when 'kidem' then u.kidem_primi when 'destek' then u.destek
                                      when 'tasinma' then u.tasinma_destek when 'vergi_tavan' then u.vergi_ust when 'belediye_payi' then u.belediye_payi
                                      when 'baraj' then (select baraj from oyun.ayarlar where id = 1) when 'parti_yardim' then u.parti_yardim
                                      when 'kent_vergisi' then d.kent_vergisi when 'hemsehri' then d.hemsehri
                                      when 'aday_ucret' then (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = p.parti_id) end,
                 'acik', case when t.kod in ('lokanta','ulasim','kira','istihdam') then exists (select 1 from oyun.il_hizmet h where h.il_id = il and h.kod = t.kod) end)
               order by t.sira) from oyun.vaat_turleri t where t.kapsam = p_kapsam));
end $$;

create or replace function public.vaat_hesapla(p_kapsam text, p_vaatler jsonb, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  return oyun.vaat_degerlendir_liste(p_kapsam, coalesce(p_il, p.il_id)::smallint, p.parti_id, p_vaatler);
end $$;

create or replace function oyun.vaat_grubu(p_tur text) returns text language sql immutable as $$
  select case when p_tur in ('bel_on','bel') then 'bel' when p_tur in ('mv_on','mv') then 'mv' when p_tur in ('cb_on','cb','cb2') then 'cb'
              when p_tur = 'kurultay' then 'gb' end
$$;

-- Vaatlerin kaydı (bekleyen eski liste silinir, yenisi yazılır). Karşılıksız liste kaydedilemez.
create or replace function oyun.vaatleri_yaz(p_kapsam text, p_donem text, u uuid, p_parti bigint, p_il smallint, p_vaatler jsonb, t timestamptz) returns jsonb
language plpgsql as $$
declare r jsonb; v jsonb; enfazla int := case p_kapsam when 'beyanname' then 5 when 'bel' then 4 when 'mv' then 3 else 2 end; mevcut numeric;
begin
  if jsonb_array_length(coalesce(p_vaatler, '[]')) > enfazla then raise exception 'En fazla % vaat verebilirsin.', enfazla; end if;
  if (select count(distinct x ->> 'kod') from jsonb_array_elements(coalesce(p_vaatler, '[]')) x) < jsonb_array_length(coalesce(p_vaatler, '[]')) then
    raise exception 'Aynı vaadi iki kez veremezsin.';
  end if;
  r := oyun.vaat_degerlendir_liste(p_kapsam, p_il, p_parti, p_vaatler);
  if r ->> 'karar' = 'karsiliksiz' then
    raise exception 'Bu vaatlerin karşılığı yok: günlük maliyet mali alanı aşıyor ya da enflasyonu fazla artırıyor. Vaatleri küçült ya da vergi artışı gibi gelir getiren bir vaatle dengele.';
  end if;
  delete from oyun.vaatler where kapsam = p_kapsam and donem = p_donem and durum = 'bekliyor'
    and (case when p_kapsam = 'beyanname' then parti_id = p_parti else user_id = u end);
  mevcut := (select vergi from oyun.ulke where id = 1);
  for v in select * from jsonb_array_elements(r -> 'vaatler') loop
    insert into oyun.vaatler(kapsam, donem, user_id, parti_id, il_id, kod, hedef, yon, olusturma)
    values (p_kapsam, p_donem, case when p_kapsam = 'beyanname' then null else u end, p_parti, p_il, v ->> 'kod', (v ->> 'hedef')::numeric,
            coalesce((select yon from oyun.vaat_turleri where kapsam = p_kapsam and kod = v ->> 'kod'),
                     case when (v ->> 'hedef')::numeric < coalesce(oyun.vaat_mevcut(p_kapsam, v ->> 'kod', p_il, p_parti), mevcut) then '<=' else '>=' end), t);
  end loop;
  return r;
end $$;

-- Aday: bildirge metni + makamına uygun ölçülebilir vaatler. Oylama bitene kadar değiştirilebilir.
create or replace function public.vaat_yaz(p_secim bigint, p_metin text, p_vaatler jsonb default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; m text; grup text[]; son timestamptz; kapsam text; a oyun.adaylar; r jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or not exists (select 1 from oyun.adaylar x join oyun.secimler y on y.id = x.secim_id
                                 where x.user_id = p.id and y.donem = s.donem and oyun.vaat_grubu(y.tur) = oyun.vaat_grubu(s.tur)) then
    raise exception 'Bu seçimde adaylığın yok.';
  end if;
  grup := case when s.tur in ('bel_on','bel') then array['bel_on','bel'] when s.tur in ('cb_on','cb','cb2') then array['cb_on','cb','cb2']
               when s.tur in ('mv_on','mv') then array['mv_on','mv'] else array[s.tur] end;
  select max(oy_bit) into son from oyun.secimler where donem = s.donem and tur = any(grup) and durum = 'bekliyor';
  if son is null or t >= son then raise exception 'Oylama bittikten sonra bildirge değiştirilemez.'; end if;
  m := nullif(btrim(coalesce(p_metin, '')), '');
  if m is not null then m := oyun.metin_temizle(m, 280); end if;
  update oyun.adaylar x set vaat = m from oyun.secimler y
   where x.secim_id = y.id and x.user_id = p.id and y.donem = s.donem and y.tur = any(grup);
  kapsam := oyun.vaat_grubu(s.tur);
  if p_vaatler is not null then
    if kapsam = 'cb' then raise exception 'Cumhurbaşkanı adayının vaatleri partisinin seçim beyannamesidir; beyannameyi genel başkan yazar.'; end if;
    select x.* into a from oyun.adaylar x join oyun.secimler y on y.id = x.secim_id where x.user_id = p.id and y.donem = s.donem and y.tur = any(grup) limit 1;
    r := oyun.vaatleri_yaz(kapsam, s.donem, p.id, p.parti_id, a.il_id, p_vaatler, t);
  end if;
  return jsonb_build_object('tamam', true, 'vaat', m, 'hesap', r);
end $$;

-- Adayın o seçimdeki bildirgesi ve vaatleri (düzenleme ekranı için)
create or replace function public.vaatlerim(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); s oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_secim;
  return jsonb_build_object('kapsam', oyun.vaat_grubu(s.tur),
    'vaat', (select x.vaat from oyun.adaylar x join oyun.secimler y on y.id = x.secim_id
             where x.user_id = p.id and y.donem = s.donem and oyun.vaat_grubu(y.tur) = oyun.vaat_grubu(s.tur) and x.vaat is not null limit 1),
    'vaatler', oyun.aday_vaatleri(p.id, p_secim));
end $$;

-- Genel başkanın seçim beyannamesi: yaklaşan genel seçim için, oylama bitene kadar
create or replace function public.beyanname_kaydet(p_metin text, p_vaatler jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; m text; r jsonb;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then raise exception 'Seçim beyannamesini yalnızca genel başkan yazar.'; end if;
  select * into s from oyun.secimler where tur = 'mv' and durum = 'bekliyor' and t < oy_bit order by oy_bas limit 1;
  if s.id is null then raise exception 'Yaklaşan bir genel seçim yok.'; end if;
  m := nullif(btrim(coalesce(p_metin, '')), '');
  if m is not null then m := oyun.metin_temizle(m, 600); end if;
  r := oyun.vaatleri_yaz('beyanname', s.donem, null, pa.id, null, p_vaatler, t);
  insert into oyun.parti_beyanname(parti_id, donem, metin, zaman) values (pa.id, s.donem, m, t)
  on conflict (parti_id, donem) do update set metin = excluded.metin, zaman = excluded.zaman;
  perform oyun.olay('parti', format('%s seçim beyannamesini açıkladı.', pa.kisa), null, pa.id, t);
  return jsonb_build_object('tamam', true, 'hesap', r, 'beyanname', oyun.beyanname_json(pa.id, s.donem));
end $$;

-- ---------------------------------------------------------------------
-- VAAT TAKİBİ (her gece)
-- ---------------------------------------------------------------------
create or replace function oyun.vaat_kosul(v oyun.vaatler, t timestamptz) returns boolean language plpgsql stable as $$
declare u oyun.ulke; d oyun.il_durum; v_cb uuid; bas timestamptz := coalesce(v.aktif_bas, t);
begin
  select * into u from oyun.ulke where id = 1;
  if v.kapsam = 'beyanname' then
    case v.kod
      when 'asgari' then return u.asgari >= v.hedef;
      when 'vergi' then return case when v.yon = '<=' then u.vergi <= v.hedef else u.vergi >= v.hedef end;
      when 'kidem' then return u.kidem_primi >= v.hedef;
      when 'destek' then return u.destek >= v.hedef;
      when 'tasinma' then return u.tasinma_destek >= v.hedef;
      when 'ikramiye' then
        v_cb := (select user_id from oyun.makamlar where id = v.makam_id);
        return exists (select 1 from oyun.kararnameler k where k.tur = 'ikramiye' and k.cb = v_cb and k.zaman >= bas and (k.veri ->> 'miktar')::numeric >= v.hedef);
      else return exists (select 1 from oyun.icraat_kayit k where k.kod = v.kod and k.zaman >= bas);
    end case;
  elsif v.kapsam = 'mv' then
    return exists (select 1 from oyun.kanunlar k where k.durum = 'yururlukte' and k.sonuc_at >= bas
      and exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = v.user_id and o.oy = 'kabul')
      and case v.kod
            when 'vergi_tavan' then k.tur = 'butce' and (k.veri ->> 'vergi_ust')::numeric <= v.hedef
            when 'belediye_payi' then k.tur = 'butce' and (k.veri ->> 'belediye_payi')::numeric >= v.hedef
            when 'parti_yardim' then k.tur = 'butce' and (k.veri ->> 'parti_yardim')::numeric <= v.hedef
            when 'baraj' then k.tur = 'secim' and (k.veri ->> 'baraj')::numeric <= v.hedef
            else false end);
  elsif v.kapsam = 'bel' then
    select * into d from oyun.il_durum where il_id = v.il_id;
    case v.kod
      when 'kent_vergisi' then return d.kent_vergisi <= v.hedef;
      when 'hemsehri' then return d.hemsehri >= v.hedef;
      when 'altyapi', 'rayli' then
        return exists (select 1 from oyun.belediye_proje_kayit k where k.kod = v.kod and k.il_id = v.il_id and k.baskan = v.user_id and k.zaman >= bas);
      else return exists (select 1 from oyun.il_hizmet h where h.il_id = v.il_id and h.kod = v.kod);
    end case;
  elsif v.kapsam = 'gb' then
    if v.kod = 'aday_ucret' then
      return (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = v.parti_id) <= v.hedef;
    else
      return coalesce((select -sum(tutar) from oyun.parti_hareket where parti_id = v.parti_id and tur = 'destek' and zaman >= bas), 0) >= v.hedef;
    end if;
  end if;
  return false;
end $$;

create or replace function oyun.vaat_degerlendir(g date, t timestamptz) returns void language plpgsql as $$
declare v oyun.vaatler; m oyun.makamlar; tip text; bitti boolean; secim_bitti boolean;
begin
  -- 1) seçim sonuçlanınca: seçildiyse aktif, seçilmediyse kapanır
  for v in select * from oyun.vaatler where durum = 'bekliyor' loop
    m := null;
    if v.kapsam in ('mv','bel') then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.user_id = v.user_id and x.tur = v.kapsam and s.donem = v.donem and x.bit is null order by x.bas limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = v.kapsam and s.durum <> 'tamam');
    elsif v.kapsam = 'beyanname' then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.tur = 'cb' and x.parti_id = v.parti_id and s.donem = v.donem and x.bit is null limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur in ('cb','cb2') and s.durum <> 'tamam');
    else
      secim_bitti := exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = 'kurultay' and s.durum = 'tamam');
    end if;
    if m.id is not null then
      update oyun.vaatler set durum = 'aktif', makam_id = m.id, aktif_bas = m.bas where id = v.id;
    elsif v.kapsam = 'gb' and secim_bitti and exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id) then
      update oyun.vaatler set durum = 'aktif', aktif_bas = (select goreve_bas from oyun.secimler where donem = v.donem and tur = 'kurultay') where id = v.id;
    elsif secim_bitti then
      update oyun.vaatler set durum = 'secilmedi', bitis = t where id = v.id;
    end if;
  end loop;
  -- 2) görevdekilerin vaatleri her gün kontrol edilir
  for v in select * from oyun.vaatler where durum = 'aktif' loop
    bitti := case when v.kapsam = 'gb' then not exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id)
                  else exists (select 1 from oyun.makamlar where id = v.makam_id and bit is not null) end;
    if bitti then
      update oyun.vaatler set durum = 'bitti', bitis = coalesce((select bit from oyun.makamlar where id = v.makam_id), t) where id = v.id;
      continue;
    end if;
    select x.tip into tip from oyun.vaat_turleri x where x.kapsam = v.kapsam and x.kod = v.kod;
    if tip = 'tek' then
      if not v.tamam and oyun.vaat_kosul(v, t) then update oyun.vaatler set tamam = true where id = v.id; end if;
    else
      update oyun.vaatler set gun_toplam = gun_toplam + 1, gun_tutuldu = gun_tutuldu + case when oyun.vaat_kosul(v, t) then 1 else 0 end where id = v.id;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- VAAT GÖRÜNÜMLERİ
-- ---------------------------------------------------------------------
create or replace function oyun.vaat_json(v oyun.vaatler) returns jsonb language sql stable as $$
  select jsonb_build_object('id', v.id, 'kod', v.kod, 'ad', t.ad, 'hedef', v.hedef, 'birim', t.birim, 'tip', t.tip, 'yon', v.yon,
    'hedef_yazi', case when t.birim = 'yok' then null else oyun.birim_yaz(v.hedef, t.birim) end,
    'durum', v.durum, 'gun_toplam', v.gun_toplam, 'gun_tutuldu', v.gun_tutuldu, 'tamam', v.tamam,
    'tutuldu', case when t.tip = 'tek' then v.tamam else v.gun_toplam > 0 and v.gun_tutuldu * 2 >= v.gun_toplam end)
  from oyun.vaat_turleri t where t.kapsam = v.kapsam and t.kod = v.kod
$$;

-- Bir adayın o seçim grubundaki vaatleri
create or replace function oyun.aday_vaatleri(u uuid, p_secim bigint) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(oyun.vaat_json(v) order by v.id), '[]'::jsonb)
  from oyun.vaatler v, oyun.secimler s
  where s.id = p_secim and v.user_id = u and v.donem = s.donem and v.kapsam = oyun.vaat_grubu(s.tur)
$$;

create or replace function oyun.beyanname_json(p_parti bigint, p_donem text) returns jsonb language sql stable as $$
  with d as (select coalesce(p_donem, (select donem from oyun.secimler where tur = 'mv' and durum = 'bekliyor' order by oy_bas limit 1)) donem)
  select case when exists (select 1 from oyun.vaatler v, d where v.kapsam = 'beyanname' and v.parti_id = p_parti and v.donem = d.donem)
                or exists (select 1 from oyun.parti_beyanname b, d where b.parti_id = p_parti and b.donem = d.donem) then
    jsonb_build_object('donem', d.donem, 'metin', (select metin from oyun.parti_beyanname b where b.parti_id = p_parti and b.donem = d.donem),
      'vaatler', coalesce((select jsonb_agg(oyun.vaat_json(v) order by v.id) from oyun.vaatler v
                           where v.kapsam = 'beyanname' and v.parti_id = p_parti and v.donem = d.donem), '[]'::jsonb))
  end from d
$$;

-- İktidardaki partinin (cumhurbaşkanı bu partidense) yürürlükteki beyannamesi ve karnesi
create or replace function oyun.iktidar_karnesi(p_parti bigint) returns jsonb language sql stable as $$
  select case when count(*) > 0 then jsonb_build_object('vaatler', jsonb_agg(oyun.vaat_json(v) order by v.id),
           'tutulan', count(*) filter (where (oyun.vaat_json(v) ->> 'tutuldu')::boolean), 'toplam', count(*)) end
  from oyun.vaatler v where v.kapsam = 'beyanname' and v.parti_id = p_parti and v.durum = 'aktif'
$$;

create or replace function oyun.vaat_listesi_makam(p_makam bigint) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(oyun.vaat_json(v) order by v.id), '[]'::jsonb) from oyun.vaatler v where v.makam_id = p_makam
$$;

-- Oyuncunun görev dönemleri ve vaat karnesi
create or replace function oyun.karneler(u uuid) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(x order by x ->> 'bas' desc), '[]'::jsonb) from (
    select jsonb_build_object('makam', case when v.kapsam = 'gb' then (select kisa from oyun.partiler where id = v.parti_id) || ' genel başkanlığı'
                                            else oyun.makam_ad(m.tur, m.il_id, m.bakanlik) end,
                              'bas', min(v.aktif_bas), 'bit', max(v.bitis), 'beyanname', bool_or(v.kapsam = 'beyanname'),
                              'vaatler', jsonb_agg(oyun.vaat_json(v) order by v.id),
                              'tutulan', count(*) filter (where (oyun.vaat_json(v) ->> 'tutuldu')::boolean), 'toplam', count(*)) x
    from oyun.vaatler v left join oyun.makamlar m on m.id = v.makam_id
    where v.durum in ('aktif','bitti') and (v.user_id = u or (v.kapsam = 'beyanname' and m.user_id = u))
    group by v.kapsam, v.donem, v.parti_id, m.tur, m.il_id, m.bakanlik
    order by min(v.aktif_bas) desc limit 8
  ) y
$$;

-- Aday kartı (02'deki tanımın yerine geçer): bildirge + ölçülebilir vaatler
create or replace function oyun.aday_json(p_aday_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object('aday_id', a.id, 'user_id', a.user_id, 'kad', coalesce(pr.kad, '(silinmiş)'),
                            'parti_id', a.parti_id, 'kisa', pa.kisa, 'renk', pa.renk, 'il_id', a.il_id, 'oy', coalesce(a.oy,0), 'sira', a.sira,
                            'vaat', a.vaat, 'vaatler', oyun.aday_vaatleri(a.user_id, a.secim_id))
  from oyun.adaylar a left join oyun.profiller pr on pr.id = a.user_id left join oyun.partiler pa on pa.id = a.parti_id
  where a.id = p_aday_id
$$;

-- Satın alma işlemcisi yalnızca sunucu fonksiyonundan (service_role) çağrılabilir
revoke all on function public.odeme_isle(jsonb) from public, anon, authenticated;
grant execute on function public.odeme_isle(jsonb) to service_role;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 10) EKONOMİ 2 · SÖZ TUTMANIN KARŞILIĞI · SOHBET
--  Her şeyin bir karşılığı olsun:
--   · Vaat tutmak itibar ve kıdem puanı (→ statü → maaş) kazandırır; tutmamak kaybettirir.
--   · Her bakanlık icraatının, milletvekilliğinin ve genel başkanlığın ölçülebilir vaat karşılığı var.
--   · Şehir kalkınma bağışı: şehrin gelişmişliğini artırır, kıdem puanı kazandırır.
--   · Vergi karnesi: ödediğin verginin nereye gittiğini gösterir.
--   · Sohbet: Bakanlar Kurulu, Parti Yönetimi, Belediye Meclisi; okunmamış sayacı.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) İTİBAR (söz tutma karnesi)
-- ---------------------------------------------------------------------
create table if not exists oyun.itibar(
  user_id uuid primary key references oyun.profiller(id) on delete cascade,
  tutulan int not null default 0,
  bozulan int not null default 0
);

create or replace function oyun.kidem_ekle(u uuid, x numeric) returns void language plpgsql as $$
begin
  perform oyun.cuzdanim(u);
  update oyun.cuzdan set kidem = greatest(0, kidem + x) where user_id = u;
end $$;

-- Bir vaat sonuçlanınca: tutulan +5 kıdem puanı, tutulmayan −3 (0'ın altına inmez)
create or replace function oyun.itibar_isle(u uuid, tuttu boolean, p_ad text, t timestamptz) returns void language plpgsql as $$
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u) then return; end if;
  insert into oyun.itibar(user_id, tutulan, bozulan) values (u, case when tuttu then 1 else 0 end, case when tuttu then 0 else 1 end)
  on conflict (user_id) do update set tutulan = oyun.itibar.tutulan + excluded.tutulan, bozulan = oyun.itibar.bozulan + excluded.bozulan;
  perform oyun.kidem_ekle(u, case when tuttu then 5 else -3 end);
  perform oyun.bildir(u, case when tuttu
      then format('Vaadini tuttun: "%s". Kıdem puanın +5 arttı, itibarın yükseldi.', p_ad)
      else format('Vaadini tutamadın: "%s". Kıdem puanın 3 azaldı, itibarın düştü.', p_ad) end, t);
end $$;

create or replace function oyun.itibar_json(u uuid) returns jsonb language sql stable as $$
  select jsonb_build_object('tutulan', coalesce(i.tutulan, 0), 'bozulan', coalesce(i.bozulan, 0), 'toplam', coalesce(i.tutulan + i.bozulan, 0),
    'oran', case when coalesce(i.tutulan + i.bozulan, 0) > 0 then round(100.0 * i.tutulan / (i.tutulan + i.bozulan)) end,
    'rozet', case when coalesce(i.tutulan + i.bozulan, 0) >= 3 and i.tutulan * 10 >= (i.tutulan + i.bozulan) * 7 then 'Sözünün Eri'
                  when coalesce(i.tutulan + i.bozulan, 0) >= 3 and i.tutulan * 10 < (i.tutulan + i.bozulan) * 3 then 'Lafta Kalan' end)
  from (select 1) x left join oyun.itibar i on i.user_id = u
$$;

-- ---------------------------------------------------------------------
-- 2) VAAT TÜRLERİ: her icraatın, her makamın bir vaat karşılığı olsun
-- ---------------------------------------------------------------------
create or replace function oyun.birim_yaz(x numeric, b text) returns text language sql immutable as $$
  select case b when 'tl_ay' then oyun.tl(x) || ' ₺/ay' when 'tl_gun' then oyun.tl(x) || ' ₺/gün' when 'tl' then oyun.tl(x) || ' ₺'
                when 'adet' then oyun.tl(x) || ' adet'
                when 'yuzde' then '%' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'kat' then '×' || replace(regexp_replace(trim(to_char(x, 'FM990.00')), '\.?0+$', ''), '.', ',')
                else coalesce(x::text, '') end
$$;

-- Beyanname: vaadi olmayan bütün bakanlık icraatları (kod = icraat kodu; yapılınca vaat tutulmuş sayılır)
insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama)
select 'beyanname', v.kod, v.ad, 'yok', 'tek', null, null, null, 12 + row_number() over (order by b.sira, v.kod),
       b.ad || ' icraatı: ' || i.aciklama
from (values
  ('adl_harc','Tapu ve noter harçlarını kaldıracağız'), ('adl_ifade','İfade özgürlüğü paketi çıkaracağız'),
  ('dis_zirve','Uluslararası yatırım zirvesi düzenleyeceğiz'), ('dis_turizm','Turizm tanıtım kampanyası yapacağız'),
  ('ic_nufus','Nüfus işlemlerini kolaylaştıracağız'), ('ic_afad','Afet bölgelerine anında yardım ulaştıracağız'),
  ('mal_iade','Vergi iadesi yapacağız'), ('mal_varlik','Varlık barışı çıkaracağız'),
  ('sav_sanayi','Savunma sanayiine yatırım yapacağız'), ('sav_bedelli','Bedelli askerlik düzenlemesi getireceğiz'),
  ('egt_seferber','Hayat boyu öğrenme seferberliği başlatacağız'), ('sag_hastane','Şehir hastaneleri yapacağız'),
  ('san_osb','Organize sanayi bölgeleri kuracağız'), ('san_tesvik','Teknoloji teşvik paketi açıklayacağız'),
  ('tic_ihracat','İhracat seferberliği başlatacağız'), ('tar_sulama','Sulama ve kırsal kalkınma yatırımı yapacağız'),
  ('ula_tren','Hızlı tren hattı yapacağız'), ('cal_esnaf','Esnafa ucuz kredi vereceğiz')) v(kod, ad)
join oyun.icraatlar i on i.kod = v.kod join oyun.bakanliklar b on b.kod = i.bakanlik
on conflict (kapsam, kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, sira = excluded.sira;

insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama) values
 ('mv','katilim','Meclis oylamalarının en az bu kadarına katılacağım','yuzde','surekli','>=',50,100,5,'Görev süresince biten kanun oylamalarının kaçına oy verdiğin her gün ölçülür. Çekimser oy da katılımdır.'),
 ('mv','teklif','Meclise kanun teklifi vereceğim','adet','tek','>=',1,5,6,'Görev süresince verdiğin (geri çekmediğin) kanun teklifi sayısı.'),
 ('gb','uye','Partinin üye sayısını artıracağım','adet','tek','>=',2,1000,3,'Partine kayıtlı oyuncu sayısı bu sayıya ulaşınca vaat tutulur.'),
 ('gb','kasa','Parti kasasını büyüteceğim','tl','tek','>=',1000,10000000,4,'Parti kasasındaki para bu tutara ulaşınca vaat tutulur. Üyelerin bağışları kasaya girer.')
on conflict (kapsam, kod) do update set ad = excluded.ad, birim = excluded.birim, tip = excluded.tip, yon = excluded.yon,
  min = excluded.min, max = excluded.max, sira = excluded.sira, aciklama = excluded.aciklama;

-- Vaat koşulları (mv ve gb'ye yeni türler eklendi)
create or replace function oyun.vaat_kosul(v oyun.vaatler, t timestamptz) returns boolean language plpgsql stable as $$
declare u oyun.ulke; d oyun.il_durum; v_cb uuid; bas timestamptz := coalesce(v.aktif_bas, t); toplam int; katildi int;
begin
  select * into u from oyun.ulke where id = 1;
  if v.kapsam = 'beyanname' then
    case v.kod
      when 'asgari' then return u.asgari >= v.hedef;
      when 'vergi' then return case when v.yon = '<=' then u.vergi <= v.hedef else u.vergi >= v.hedef end;
      when 'kidem' then return u.kidem_primi >= v.hedef;
      when 'destek' then return u.destek >= v.hedef;
      when 'tasinma' then return u.tasinma_destek >= v.hedef;
      when 'ikramiye' then
        v_cb := (select user_id from oyun.makamlar where id = v.makam_id);
        return exists (select 1 from oyun.kararnameler k where k.tur = 'ikramiye' and k.cb = v_cb and k.zaman >= bas and (k.veri ->> 'miktar')::numeric >= v.hedef);
      when 'ozellestirme' then
        v_cb := (select user_id from oyun.makamlar where id = v.makam_id);
        return exists (select 1 from oyun.kararnameler k where k.tur = 'ozellestirme' and k.cb = v_cb and k.zaman >= bas);
      when 'referandum' then return exists (select 1 from oyun.referandumlar r where r.olusturma >= bas);
      else
        if exists (select 1 from oyun.duzenleme_tanim where kod = v.kod) then
          return case when v.yon = '<=' then oyun.duz(v.kod) <= v.hedef else oyun.duz(v.kod) >= v.hedef end;
        end if;
        return exists (select 1 from oyun.icraat_kayit k where k.kod = v.kod and k.zaman >= bas);
    end case;
  elsif v.kapsam = 'mv' then
    if v.kod = 'katilim' then
      select count(*) into toplam from oyun.kanunlar k where k.oy_bit <= t and k.oy_bit >= bas and k.durum not in ('geri_cekildi','gorusmede','oylamada');
      select count(*) into katildi from oyun.kanun_oylari o join oyun.kanunlar k on k.id = o.kanun_id
       where o.vekil = v.user_id and o.asama = 'ilk' and k.oy_bit <= t and k.oy_bit >= bas and k.durum not in ('geri_cekildi','gorusmede','oylamada');
      return toplam < 3 or katildi * 100 >= v.hedef * toplam;     -- henüz yeterli oylama yoksa vaat tutulmuş sayılır
    elsif v.kod = 'teklif' then
      return (select count(*) from oyun.kanunlar where teklif_eden = v.user_id and teklif_at >= bas and durum <> 'geri_cekildi') >= v.hedef;
    elsif v.kod = 'anayasa_imza' then
      return exists (select 1 from oyun.kanun_oylari o join oyun.kanunlar k on k.id = o.kanun_id
                     where o.vekil = v.user_id and o.asama = 'imza' and k.teklif_at >= bas and k.durum <> 'geri_cekildi');
    end if;
    return exists (select 1 from oyun.kanunlar k where k.durum = 'yururlukte' and k.sonuc_at >= bas
      and exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = v.user_id and o.oy = 'kabul')
      and case v.kod
            when 'vergi_tavan' then k.tur = 'butce' and (k.veri ->> 'vergi_ust')::numeric <= v.hedef
            when 'belediye_payi' then k.tur = 'butce' and (k.veri ->> 'belediye_payi')::numeric >= v.hedef
            when 'parti_yardim' then k.tur = 'butce' and (k.veri ->> 'parti_yardim')::numeric <= v.hedef
            when 'baraj' then k.tur = 'secim' and (k.veri ->> 'baraj')::numeric <= v.hedef
            else k.tur in ('duzenleme','anayasa') and k.veri ->> 'kod' = v.kod
                 and case when v.yon = '<=' then (k.veri ->> 'deger')::numeric <= v.hedef else (k.veri ->> 'deger')::numeric >= v.hedef end end);
  elsif v.kapsam = 'bel' then
    select * into d from oyun.il_durum where il_id = v.il_id;
    case v.kod
      when 'kent_vergisi' then return d.kent_vergisi <= v.hedef;
      when 'hemsehri' then return d.hemsehri >= v.hedef;
      when 'emlak', 'hosgeldin' then
        return case when v.yon = '<=' then oyun.il_duz(v.il_id, v.kod) <= v.hedef else oyun.il_duz(v.il_id, v.kod) >= v.hedef end;
      when 'altyapi', 'rayli', 'imar_barisi' then
        return exists (select 1 from oyun.belediye_proje_kayit k where k.kod = v.kod and k.il_id = v.il_id and k.baskan = v.user_id and k.zaman >= bas);
      else return exists (select 1 from oyun.il_hizmet h where h.il_id = v.il_id and h.kod = v.kod);
    end case;
  elsif v.kapsam = 'gb' then
    case v.kod
      when 'aday_ucret' then
        return (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = v.parti_id) <= v.hedef;
      when 'uye' then return (select count(*) from oyun.profiller where parti_id = v.parti_id) >= v.hedef;
      when 'kasa' then return coalesce((select kasa from oyun.partiler where id = v.parti_id), 0) >= v.hedef;
      else
        return coalesce((select -sum(tutar) from oyun.parti_hareket where parti_id = v.parti_id and tur = 'destek' and zaman >= bas), 0) >= v.hedef;
    end case;
  end if;
  return false;
end $$;

-- Her gece: vaatlerin durumu. Sonuçlanan vaat itibar ve kıdem puanına işlenir.
create or replace function oyun.vaat_degerlendir(g date, t timestamptz) returns void language plpgsql as $$
declare v oyun.vaatler; m oyun.makamlar; tip text; vad text; bitti boolean; secim_bitti boolean; sorumlu uuid;
begin
  -- 1) seçim sonuçlanınca: seçildiyse aktif, seçilmediyse kapanır
  for v in select * from oyun.vaatler where durum = 'bekliyor' loop
    m := null;
    if v.kapsam in ('mv','bel') then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.user_id = v.user_id and x.tur = v.kapsam and s.donem = v.donem and x.bit is null order by x.bas limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = v.kapsam and s.durum <> 'tamam');
    elsif v.kapsam = 'beyanname' then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.tur = 'cb' and x.parti_id = v.parti_id and s.donem = v.donem and x.bit is null limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur in ('cb','cb2') and s.durum <> 'tamam');
    else
      secim_bitti := exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = 'kurultay' and s.durum = 'tamam');
    end if;
    if m.id is not null then
      update oyun.vaatler set durum = 'aktif', makam_id = m.id, aktif_bas = m.bas where id = v.id;
    elsif v.kapsam = 'gb' and secim_bitti and exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id) then
      update oyun.vaatler set durum = 'aktif', aktif_bas = (select goreve_bas from oyun.secimler where donem = v.donem and tur = 'kurultay') where id = v.id;
    elsif secim_bitti then
      update oyun.vaatler set durum = 'secilmedi', bitis = t where id = v.id;
    end if;
  end loop;
  -- 2) görevdekilerin vaatleri her gün kontrol edilir
  for v in select * from oyun.vaatler where durum = 'aktif' loop
    select x.tip, x.ad into tip, vad from oyun.vaat_turleri x where x.kapsam = v.kapsam and x.kod = v.kod;
    sorumlu := coalesce(v.user_id, (select user_id from oyun.makamlar where id = v.makam_id));
    bitti := case when v.kapsam = 'gb' then not exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id)
                  else exists (select 1 from oyun.makamlar where id = v.makam_id and bit is not null) end;
    if bitti then
      update oyun.vaatler set durum = 'bitti', bitis = coalesce((select bit from oyun.makamlar where id = v.makam_id), t) where id = v.id;
      -- dönem sonu: tek seferlik vaat yapılmadıysa, sürekli vaat günlerin yarısından azında tutulduysa söz bozulmuştur
      if tip = 'tek' then
        if not v.tamam then perform oyun.itibar_isle(sorumlu, false, vad, t); end if;
      elsif v.gun_toplam > 0 then
        perform oyun.itibar_isle(sorumlu, v.gun_tutuldu * 2 >= v.gun_toplam, vad, t);
      end if;
      continue;
    end if;
    if tip = 'tek' then
      if not v.tamam and oyun.vaat_kosul(v, t) then
        update oyun.vaatler set tamam = true where id = v.id;
        perform oyun.itibar_isle(sorumlu, true, vad, t);
      end if;
    else
      update oyun.vaatler set gun_toplam = gun_toplam + 1, gun_tutuldu = gun_tutuldu + case when oyun.vaat_kosul(v, t) then 1 else 0 end where id = v.id;
    end if;
  end loop;
end $$;

-- Vaat seçenekleri ekranı (yeni türlerin "bugünkü değeri" eklendi)
create or replace function public.vaat_secenekleri(p_kapsam text, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); u oyun.ulke; d oyun.il_durum; il smallint := coalesce(p_il, p.il_id)::smallint;
begin
  select * into u from oyun.ulke where id = 1;
  select * into d from oyun.il_durum where il_id = il;
  return jsonb_build_object('kapsam', p_kapsam, 'il_id', il, 'il_ad', (select ad from oyun.iller where id = il),
    'en_fazla', case p_kapsam when 'beyanname' then 5 when 'bel' then 4 when 'mv' then 3 else 2 end,
    'alan', oyun.vaat_alani(p_kapsam, il, p.parti_id), 'birim', case p_kapsam when 'gb' then 'tl' else 'milyar' end,
    'turler', (select jsonb_agg(jsonb_build_object('kod', t.kod, 'ad', t.ad, 'birim', t.birim, 'tip', t.tip, 'min', t.min, 'max', t.max, 'aciklama', t.aciklama,
                 'mevcut', oyun.vaat_mevcut(t.kapsam, t.kod, il, p.parti_id),
                 'acik', case when t.kod in ('lokanta','ulasim','kira','istihdam') then exists (select 1 from oyun.il_hizmet h where h.il_id = il and h.kod = t.kod) end)
               order by t.sira) from oyun.vaat_turleri t where t.kapsam = p_kapsam));
end $$;

-- Aday kartı: bildirge + ölçülebilir vaatler + söz tutma karnesi
create or replace function oyun.aday_json(p_aday_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object('aday_id', a.id, 'user_id', a.user_id, 'kad', coalesce(pr.kad, '(silinmiş)'),
                            'parti_id', a.parti_id, 'kisa', pa.kisa, 'renk', pa.renk, 'il_id', a.il_id, 'oy', coalesce(a.oy,0), 'sira', a.sira,
                            'vaat', a.vaat, 'vaatler', oyun.aday_vaatleri(a.user_id, a.secim_id), 'itibar', oyun.itibar_json(a.user_id))
  from oyun.adaylar a left join oyun.profiller pr on pr.id = a.user_id left join oyun.partiler pa on pa.id = a.parti_id
  where a.id = p_aday_id
$$;

-- ---------------------------------------------------------------------
-- 3) PARANIN KARŞILIĞI: şehir kalkınma bağışı + vergi karnesi
-- ---------------------------------------------------------------------
create table if not exists oyun.il_bagis_kayit(
  id      bigserial primary key,
  il_id   smallint not null references oyun.iller(id),
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  tutar   numeric not null,
  zaman   timestamptz not null
);
create index if not exists il_bagis_il on oyun.il_bagis_kayit(il_id, zaman desc);

create or replace function public.il_bagis_durum() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan;
begin
  c := oyun.cuzdanim(p.id);
  return jsonb_build_object('il_ad', (select ad from oyun.iller where id = p.il_id), 'gelisim', (select round(gelisim, 2) from oyun.il_durum where il_id = p.il_id),
    'bugun', c.bagis_bugun, 'tavan', (select asgari from oyun.ulke where id = 1),
    'ay_toplam', coalesce((select sum(tutar) from oyun.il_bagis_kayit where il_id = p.il_id and zaman > t - interval '30 days'), 0),
    'benim_toplam', coalesce((select sum(tutar) from oyun.il_bagis_kayit where il_id = p.il_id and user_id = p.id), 0),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('kad', x.kad, 'toplam', x.s) order by x.s desc), '[]'::jsonb)
            from (select pr.kad, sum(b.tutar) s from oyun.il_bagis_kayit b join oyun.profiller pr on pr.id = b.user_id
                  where b.il_id = p.il_id and b.zaman > t - interval '30 days' group by pr.kad order by sum(b.tutar) desc limit 5) x));
end $$;

-- Her asgari ücret tutarındaki bağış: şehrin gelişmişliği +0,005 (maaşları ve belediye gelirini artırır) ve 1 kıdem puanı.
-- Parti bağışıyla birlikte günlük sınır: asgari ücret.
create or replace function public.il_bagis(p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); c oyun.cuzdan; tavan numeric; il_ad text;
begin
  if m < 100 then raise exception 'En az 100 ₺ bağışlayabilirsin.'; end if;
  perform oyun.takip_engel(p.id, 'bağış yapamazsın');
  c := oyun.cuzdanim(p.id);
  tavan := (select asgari from oyun.ulke where id = 1);
  if c.bagis_bugun + m > tavan then
    raise exception 'Bağış sınırı: kişi başı günde en fazla % ₺ (parti ve şehir bağışları birlikte sayılır; bugün % ₺ bağışladın).', oyun.tl(tavan), oyun.tl(c.bagis_bugun);
  end if;
  il_ad := (select ad from oyun.iller where id = p.il_id);
  perform oyun.para_islem(p.id, -m, 'bagis', format('%s kalkınma bağışı', il_ad), t);
  update oyun.cuzdan set bagis_bugun = bagis_bugun + m, kidem = kidem + m / tavan where user_id = p.id;
  update oyun.il_durum set gelisim = least(100, gelisim + 0.005 * m / tavan) where il_id = p.il_id;
  insert into oyun.il_bagis_kayit(il_id, user_id, tutar, zaman) values (p.il_id, p.id, m, t);
  return public.il_bagis_durum();
end $$;

-- Verginin nereye gittiği: son 7 günde ödediğin gelir vergisi, bütçe payları oranında
create or replace function public.vergi_karnem() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.ulke; h jsonb; v numeric; gider numeric; kalem jsonb;
begin
  select * into u from oyun.ulke where id = 1;
  h := oyun.ulke_hesap(u);
  gider := greatest(0.0001, (h ->> 'gider')::numeric);
  v := coalesce((select sum(vergi) from oyun.hesap_hareket where user_id = p.id and tur = 'maas' and zaman > t - interval '7 days'), 0);
  select coalesce(jsonb_agg(z.x order by (z.x ->> 'tl')::numeric desc), '[]'::jsonb) into kalem from (
    select jsonb_build_object('ad', b.ad, 'tl', round(v * ((h ->> 'cari')::numeric / gider) * coalesce((u.butce ->> b.kod)::numeric, 0) / 100, 2)) x from oyun.bakanliklar b
    union all select jsonb_build_object('ad', 'Belediyeler', 'tl', round(v * (h ->> 'belediye')::numeric / gider, 2))
    union all select jsonb_build_object('ad', 'Yeni vatandaşlara sosyal destek', 'tl', round(v * (h ->> 'destek')::numeric / gider, 2))) z;
  return jsonb_build_object('vergi_7gun', round(v), 'vergi_oran', u.vergi, 'kalemler', kalem,
    'destek_gunluk', u.destek, 'etkiler', oyun.etkilerim(p.il_id, t));
end $$;

-- ---------------------------------------------------------------------
-- 4) SOHBET: yeni kanallar (kabine · yonetim · belediye), okunmamış sayacı
-- ---------------------------------------------------------------------
create table if not exists oyun.kanal_okuma(
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  kanal   text not null,
  son_id  bigint not null default 0,
  primary key (user_id, kanal)
);

-- Vekilin bugünkü partisi (13_meclis'te de tanımlı)
create or replace function oyun.aktif_mv_parti(u uuid) returns bigint language sql stable as $$
  select p.parti_id from oyun.profiller p where p.id = u and exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv' and m.bit is null)
$$;

create or replace function oyun.kanal_coz(p oyun.profiller, p_kanal text) returns text language plpgsql stable as $$
begin
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'belediye' then 'belediye:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (select 'ittifak:' || u.ittifak_id from oyun.ittifak_uyeler u where u.parti_id = p.parti_id)
    when 'kabine' then case when exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('cb','bakan')) then 'kabine' end
    when 'grup' then case when oyun.aktif_mv_parti(p.id) is not null then 'grup:' || oyun.aktif_mv_parti(p.id)
                          when exists (select 1 from oyun.partiler pa where pa.gb = p.id and pa.id = p.parti_id) then 'grup:' || p.parti_id end
    when 'divan' then case when exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv','grup_bskv')) then 'divan' end
    when 'yonetim' then (select 'yonetim:' || pa.id from oyun.partiler pa
                         where pa.id = p.parti_id and not pa.kapali
                           and (pa.gb = p.id or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = p.id)))
    else null end;
end $$;

create or replace function oyun.kanal_baslik(p oyun.profiller, kod text) returns text language sql stable as $$
  select case kod
    when 'genel' then 'Türkiye Meydanı'
    when 'il' then (select ad from oyun.iller where id = p.il_id) || ' Kahvesi'
    when 'belediye' then (select ad from oyun.iller where id = p.il_id) || ' Belediye Meclisi'
    when 'parti' then (select ad from oyun.partiler where id = p.parti_id)
    when 'yonetim' then (select kisa from oyun.partiler where id = p.parti_id) || ' Yönetim Kurulu'
    when 'meclis' then 'TBMM Genel Kurulu'
    when 'kabine' then 'Bakanlar Kurulu'
    when 'grup' then (select kisa from oyun.partiler where id = coalesce(oyun.aktif_mv_parti(p.id), p.parti_id)) || ' Meclis Grubu'
    when 'divan' then 'TBMM Başkanlık Divanı ve Danışma Kurulu'
    when 'ittifak' then (select i.ad from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = p.parti_id)
  end
$$;

create or replace function oyun.kanal_yazabilir(p oyun.profiller, kod text) returns boolean language sql stable as $$
  select case kod
    when 'meclis' then oyun.meclis_yazabilir(p.id)
    when 'belediye' then exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null and m.tur in ('bel','mv') and m.il_id = p.il_id)
    else true end
$$;

create or replace function oyun.kanal_hata(kod text) returns text language sql immutable as $$
  select case kod
    when 'ittifak' then 'Partin bir ittifakta değil.'
    when 'kabine' then 'Bakanlar Kurulu sohbetine yalnızca cumhurbaşkanı ve bakanlar girebilir.'
    when 'yonetim' then 'Parti yönetimi sohbetine yalnızca genel başkan ve genel başkan yardımcıları girebilir.'
    when 'grup' then 'Meclis grubu sohbetine yalnızca partinin milletvekilleri ve genel başkanı girebilir.'
    when 'divan' then 'Başkanlık Divanı sohbetine TBMM Başkanı, başkanvekilleri ve grup başkanvekilleri girebilir.'
    else 'Parti sohbeti için bir partiye üye olmalısın.' end
$$;

create or replace function oyun.kanal_yaz_hata(kod text) returns text language sql immutable as $$
  select case kod
    when 'belediye' then 'Belediye meclisinde yalnızca o ilin belediye başkanı ve milletvekilleri söz alabilir; herkes izleyebilir.'
    else 'Genel Kurul''da yalnızca milletvekilleri, bakanlar ve cumhurbaşkanı söz alabilir.' end
$$;

create or replace function public.sohbet_oku(p_kanal text, p_once bigint default null, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb; son bigint;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'kad', coalesce(pr.kad, '(silinmiş)'), 'metin', x.metin, 'zaman', x.zaman,
            'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(x.user_id), 'benim', x.user_id = p.id) order by x.id), '[]'::jsonb)
    into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal = k and not m.gizli and m.zaman <= oyun.simdi() and not oyun.engelli(p.id, m.user_id)
      and (p_sonra is null or m.id > p_sonra) and (p_once is null or m.id < p_once)
    order by case when p_sonra is null then -m.id else m.id end
    limit case when p_sonra is null then 40 else 100 end
  ) x left join oyun.profiller pr on pr.id = x.user_id;
  -- okundu işareti: kanalın en son görünen mesajına kadar
  if p_once is null then
    select max(id) into son from oyun.mesajlar where kanal = k and not gizli and zaman <= oyun.simdi();
    if son is not null then
      insert into oyun.kanal_okuma(user_id, kanal, son_id) values (p.id, k, son)
      on conflict (user_id, kanal) do update set son_id = greatest(oyun.kanal_okuma.son_id, excluded.son_id);
    end if;
  end if;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste, 'yazabilir', oyun.kanal_yazabilir(p, p_kanal), 'baslik', oyun.kanal_baslik(p, p_kanal));
end $$;

create or replace function public.sohbet_yaz(p_kanal text, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; m text;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  if not oyun.kanal_yazabilir(p, p_kanal) then raise exception '%', oyun.kanal_yaz_hata(p_kanal); end if;
  if p_kanal = 'meclis' and oyun.ihtarli(p.id, t) is not null then
    raise exception 'Meclis Başkanlığından ihtar aldın; % saatine kadar Genel Kurul''da söz alamazsın.', to_char(oyun.ihtarli(p.id, t) at time zone 'Europe/Istanbul', 'HH24:MI');
  end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 500);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values (k, p.id, m, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- Sohbet listesi: erişebildiğin ve kilitli kanallar, son mesaj, okunmamış sayısı, çevrimiçi oyuncu
create or replace function public.sohbet_ozet() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); liste jsonb := '[]'; kod text; k text; imlec bigint; okunmamis int; son jsonb; cev int; kilit text;
begin
  foreach kod in array array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine'] loop
    k := oyun.kanal_coz(p, kod);
    kilit := case when k is not null then null else case kod
      when 'parti' then 'Bir partiye katılınca açılır.' when 'yonetim' then 'Genel başkan ya da genel başkan yardımcısı olunca açılır.'
      when 'ittifak' then 'Partin bir ittifaka girince açılır.' when 'kabine' then 'Cumhurbaşkanı ya da bakan olunca açılır.'
      when 'grup' then 'Milletvekili olunca açılır.' when 'divan' then 'TBMM Başkanı, başkanvekili ya da grup başkanvekili olunca açılır.' end end;
    okunmamis := 0; son := null; cev := null;
    if k is not null then
      select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = k;
      select count(*) into okunmamis from (
        select 1 from oyun.mesajlar m where m.kanal = k and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
           and m.zaman <= t and m.zaman > t - interval '3 days' and not oyun.engelli(p.id, m.user_id) limit 100) x;
      select jsonb_build_object('kad', coalesce(pr.kad, '(silinmiş)'), 'metin', m.metin, 'zaman', m.zaman) into son
        from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
       where m.kanal = k and not m.gizli and m.zaman <= t and not oyun.engelli(p.id, m.user_id) order by m.id desc limit 1;
      cev := case kod
        when 'genel' then (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes')
        when 'il' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'belediye' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'parti' then (select count(*) from oyun.profiller where not yasakli and parti_id = p.parti_id and son_gorulme > t - interval '5 minutes')
        end;
    end if;
    liste := liste || jsonb_build_object('kanal', kod, 'baslik', coalesce(oyun.kanal_baslik(p, kod), case kod when 'parti' then 'Parti sohbeti' when 'yonetim' then 'Parti Yönetim Kurulu'
                  when 'ittifak' then 'İttifak sohbeti' when 'kabine' then 'Bakanlar Kurulu' when 'grup' then 'Parti Meclis Grubu'
                  when 'divan' then 'TBMM Başkanlık Divanı' end),
      'kilit', kilit, 'yazabilir', k is not null and oyun.kanal_yazabilir(p, kod), 'okunmamis', okunmamis, 'son', son, 'cevrimici', cev);
  end loop;
  return jsonb_build_object('kanallar', liste,
    'cevrimici', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes'),
    'toplam_okunmamis', (select coalesce(sum((x ->> 'okunmamis')::int), 0) from jsonb_array_elements(liste) x));
end $$;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 11) BOŞ MAKAM KURALI
--  Başlangıçta oyuncu az olacağı için bazı makamlar boş kalabilir. Kural:
--   1. Boş bakanlığa cumhurbaşkanı vekâlet eder (icraat yapabilir, bakanlık kasasından).
--   2. Seçimde aday çıkmayan makamda (belediye, cumhurbaşkanlığı) görevdeki, yenisi seçilene kadar devam eder.
--      (02_motor.sql: goreve_baslat)
--   3. Genel başkansız parti kalmaz: üyeler "Genel başkanlığı üstlen" ile hemen devralabilir; kurultayda da kimse aday olmazsa
--      başka görevi olmayan en kıdemli üye genel başkan olur.
--   4. Meclis'in yetersayıları dolu sandalye sayısına göre ölçeklenir (07_devlet.sql).
--   5. Boş Makamlar panosu: neyin boş olduğu, kimin vekâlet ettiği ve sonraki seçim.
-- =====================================================================

-- Cumhurbaşkanı, boş bir bakanlığa vekâlet edebilir mi?
create or replace function oyun.bakanlik_vekili(p_user uuid, p_bakanlik text) returns boolean language sql stable as $$
  select exists (select 1 from oyun.makamlar where user_id = p_user and tur = 'cb' and bit is null)
     and not exists (select 1 from oyun.makamlar where tur = 'bakan' and bakanlik = p_bakanlik and bit is null)
$$;

-- Bir bakanlığın paneli (bakanlik_paneli ile aynı biçim)
create or replace function oyun.bakanlik_panel_json(p_kod text, t timestamptz) returns jsonb language plpgsql stable as $$
declare pay numeric;
begin
  pay := coalesce(((select butce from oyun.ulke where id = 1) ->> p_kod)::numeric, 0);
  return jsonb_build_object(
    'kod', p_kod, 'ad', (select ad from oyun.bakanliklar where kod = p_kod),
    'kasa', round((select kasa from oyun.bakanlik_kasa where kod = p_kod), 1),
    'gunluk', round(10 * pay / 100, 2), 'pay', pay,
    'icraatlar', (select jsonb_agg(jsonb_build_object('kod', i.kod, 'ad', i.ad, 'aciklama', i.aciklama, 'maliyet', i.maliyet,
                    'il_gerekli', i.il_gerekli, 'etki', i.etki, 'bekleme_saat', i.bekleme_saat,
                    'oyuncu', i.oyuncu, 'sure_gun', i.sure_gun, 'ozel', i.ozel,
                    'aktif_bit', (select max(e.bit) from oyun.etkiler e where e.kaynak_kod = i.kod and e.il_id is null and e.bit > t),
                    'hazir', (select max(k.zaman) + make_interval(hours => i.bekleme_saat) from oyun.icraat_kayit k where k.kod = i.kod))
                  order by i.maliyet) from oyun.icraatlar i where i.bakanlik = p_kod));
end $$;

-- Cumhurbaşkanının vekâleten yönettiği (bakanı olmayan) bakanlıkların panelleri
create or replace function public.vekalet_paneli() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(oyun.bakanlik_panel_json(b.kod, t) order by b.sira) from oyun.bakanliklar b
                   where not exists (select 1 from oyun.makamlar m where m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null)), '[]'::jsonb);
end $$;

-- Genel başkansız kalan parti (kurultayda kimse aday olmadı): başka görevi olmayan (cumhurbaşkanı hariç) en kıdemli üye genel başkan olur.
-- Bir sonraki kurultayda üyeler genel başkanı yeniden seçer. Kurultay sonucu işlenince çağrılır (02_motor.sql: goreve_baslat).
create or replace function oyun.gb_halef(t timestamptz) returns void language plpgsql as $$
declare pa record; aday uuid;
begin
  for pa in select id, ad from oyun.partiler where not kapali and gb is null loop
    select pr.id into aday from oyun.profiller pr
     where pr.parti_id = pa.id and not pr.yasakli
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur <> 'cb')
     order by oyun.kidem_puani(pr.id) desc, pr.parti_at, pr.id limit 1;
    continue when aday is null;
    delete from oyun.parti_gby where user_id = aday;       -- genel başkan aynı zamanda yardımcı olamaz
    update oyun.partiler set gb = aday where id = pa.id and gb is null;
    perform oyun.bildir(aday, format('%s kurultayda genel başkansız kaldığı için kıdemin en yüksek olduğu üye olarak genel başkan oldun. Bir sonraki kurultayda üyeler genel başkanı yeniden seçecek; 6 genel başkan yardımcını atayabilirsin.', pa.ad), t);
    perform oyun.olay('parti', format('%s genel başkansız kaldı; kıdemi en yüksek üye %s genel başkan oldu.', pa.ad, (select kad from oyun.profiller where id = aday)), null, pa.id, t);
  end loop;
end $$;

-- Genel başkansız partinin üyesi, başka görevi yoksa genel başkanlığı hemen üstlenebilir (genel başkan yardımcısı da olabilir)
create or replace function public.genel_baskanlik_uslen() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; c text;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Önce bir partiye üye olmalısın.'; end if;
  if pa.gb is not null then raise exception 'Partinin genel başkanı var.'; end if;
  select oyun.rol_ad(r) into c from unnest(oyun.roller(p.id)) r where r <> 'gby' and not oyun.rol_uyumlu(r, 'gb') limit 1;
  if c is not null then raise exception 'Şu anda % görevindesin; genel başkan olmak için önce o görevden istifa etmelisin.', c; end if;
  delete from oyun.parti_gby where user_id = p.id;
  update oyun.partiler set gb = p.id where id = pa.id;
  perform oyun.olay('parti', format('%s genel başkansız kalan %s partisinin genel başkanlığını üstlendi.', p.kad, pa.ad), null, pa.id, t);
  perform oyun.bildir(p.id, format('%s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilir, seçim beyannamesini yazabilirsin. Bir sonraki kurultayda üyeler genel başkanı yeniden seçer.', pa.ad), t);
  return public.durum();
end $$;

-- Boş Makamlar panosu
create or replace function public.bos_makamlar() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); cb text := (select oyun.kad(user_id) from oyun.makamlar where tur = 'cb' and bit is null limit 1); mv int;
begin
  select count(*) into mv from oyun.makamlar where tur = 'mv' and bit is null;
  return jsonb_build_object(
    'cb', cb,
    'bakanliklar', coalesce((select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad) order by b.sira) from oyun.bakanliklar b
                             where not exists (select 1 from oyun.makamlar m where m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null)), '[]'::jsonb),
    'belediyeler', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad) order by i.ad) from oyun.iller i
                             where not exists (select 1 from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null)), '[]'::jsonb),
    'vekil', jsonb_build_object('dolu', mv, 'bos', 600 - mv),
    'partiler', coalesce((select jsonb_agg(jsonb_build_object('id', pa.id, 'kisa', pa.kisa)) from oyun.partiler pa where not pa.kapali and pa.gb is null
                          and exists (select 1 from oyun.profiller where parti_id = pa.id)), '[]'::jsonb),
    'sonraki', coalesce((select jsonb_agg(jsonb_build_object('tur', x.tur, 'basvuru_bas', x.basvuru_bas, 'basvuru_bit', x.basvuru_bit, 'oy_bas', x.oy_bas) order by x.oy_bas)
                         from (select distinct on (tur) tur, basvuru_bas, basvuru_bit, oy_bas from oyun.secimler
                               where durum = 'bekliyor' and tur in ('bel','mv','cb','kurultay') and oy_bit > t order by tur, oy_bas) x), '[]'::jsonb));
end $$;
-- =====================================================================
--  12 · MEVZUAT, ANAYASA DEĞİŞİKLİĞİ VE HALK OYLAMASI
--
--  Oyuncuları doğrudan etkileyen kurallar (düzenlemeler) ve normlar hiyerarşisi:
--    Anayasa (halk oylaması)  >  Kanun (Meclis)  >  Cumhurbaşkanlığı kararnamesi
--    • Cumhurbaşkanı kanunla düzenlenmiş bir konuyu kararnameyle değiştiremez.
--    • Meclis anayasaya bağlanmış bir konuyu kanunla değiştiremez; ancak yeni bir anayasa değişikliği değiştirir.
--  İl düzenlemeleri (emlak vergisi, hoş geldin desteği) belediye başkanının kararıdır.
--
--  Anayasa değişikliği (gerçek usule yakın):
--    teklif: bir milletvekili verir, 24 saatlik görüşmede dolu sandalyelerin 1/3'ü imza vermeli
--    oylama: GİZLİ oy; ≥ 2/3 → cumhurbaşkanı yürürlüğe koyar ya da halkoyuna sunar (karar vermezse yürürlüğe girer)
--            ≥ 3/5 → doğrudan halk oylamasına gider · daha azı → ret
--    halk oylaması: tüm oyuncular sandığa gider (Evet / Hayır), oy gizlidir; geçerli oyların yarısından fazlası
--                   "Evet" ise yürürlüğe girer. Sonuç il il açıklanır.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.duzenleme_tanim(
  kod        text primary key,
  kapsam     text not null check (kapsam in ('ulke','il')),
  ad         text not null,
  birim      text not null,                 -- binde, tl, tl_gun, yuzde, saat
  varsayilan numeric not null,
  min        numeric not null,
  max        numeric not null,
  adim       numeric not null,
  tur        text not null check (tur in ('kolaylik','yaptirim','gelir')),
  aciklama   text not null,
  oyuncu     text not null,                 -- oyunculara etkisi
  devlet     text not null,                 -- hazineye / ekonomiye etkisi
  sira       int not null
);
insert into oyun.duzenleme_tanim(kod, kapsam, ad, birim, varsayilan, min, max, adim, tur, aciklama, oyuncu, devlet, sira) values
 ('servet_vergisi','ulke','Servet vergisi','binde',0,0,10,0.5,'gelir',
  'Büyük servetlerden alınan günlük vergi. Muafiyet: 250.000 ₺ × fiyat düzeyi.',
  'Cüzdanında muafiyetin üstünde para olan oyuncudan her gün ilk toplamada, aşan kısmın binde bu kadarı kesilir.',
  'Her binde 1 hazineye günde 0,3 milyar ₺ getirir; sermaye kaçışı büyümeyi düşürür, halk memnuniyeti biraz artar.',1),
 ('oy_cezasi','ulke','Sandığa gitmeyene idari para cezası','tl',0,0,5000,250,'yaptirim',
  'Seçimde ya da halk oylamasında oy kullanabilecekken kullanmayan oyuncuya kesilen ceza.',
  'Oy kullanma hakkı olup son 7 günde oyuna girmiş, ama sandığa gitmemiş oyuncunun cüzdanından düşer.',
  'Katılımı artırır; halk memnuniyetini biraz düşürür. Hazine geliri önemsizdir.',2),
 ('yeni_hibe','ulke','Yeni vatandaşa hoş geldin hibesi','tl',0,0,50000,1000,'kolaylik',
  'Oyuna yeni katılan her oyuncuya tek seferlik devlet hibesi.',
  'Yeni hesap açan oyuncunun cüzdanına bir kez yatar.',
  'Ülkede günde 5.000 yeni vatandaşa ödenir: her 10.000 ₺ hazineye günde 0,05 milyar ₺; enflasyonu biraz artırır.',3),
 ('aday_destek','ulke','Siyasi katılım fonu','yuzde',0,0,100,5,'kolaylik',
  'Aday adaylığı başvuru ücretlerinin bu kadarını hazine öder; parti kasasına ücretin tamamı girer.',
  'Aday olmak ucuzlar: oyuncu ücretin yalnızca kalanını öder.',
  'Her %10 hazineye günde 0,04 milyar ₺.',4),
 ('seri_tavan','ulke','Devamlılık primi tavanı','yuzde',30,0,60,5,'kolaylik',
  'Her gün maaşını toplayanın maaşına eklenen seri priminin üst sınırı (günde +%5 artar).',
  'Uzun seri yapan oyuncunun maaşı bu tavana kadar artar.',
  '%30''un üstündeki her 10 puan enflasyonu 0,5 puan artırır; altı enflasyonu düşürür.',5),
 ('kumbara_saat','ulke','Maaş kumbarası kapasitesi','saat',8,6,12,1,'kolaylik',
  'Maaşın en fazla kaç saat birikir (esnek çalışma düzenlemesi).',
  'Uzun kapasite, oyuna seyrek giren oyuncunun maaşını kaybetmemesini sağlar.',
  '8 saatin üstündeki her saat büyümeyi 0,1 puan düşürür, memnuniyeti 0,5 puan artırır.',6),
 ('vekil_kesinti','ulke','Meclis devamsızlık kesintisi','yuzde',0,0,50,5,'yaptirim',
  'Son 7 günde biten kanun oylamalarına katılmayan milletvekilinin makam maaşından kesinti.',
  'Vekilin maaşından: kesinti oranı × katılmadığı oylamaların oranı kadar düşer.',
  'Hazineye etkisi yok; halk memnuniyeti biraz artar.',7),
 ('emlak','il','Emlak vergisi','tl_gun',0,0,300,10,'gelir',
  'İlde yaşayan her oyuncudan günlük emlak vergisi (fiyat düzeyiyle artar).',
  'Her gün ilk toplamada cüzdandan kesilir.',
  'Belediye kasasına ildeki hane sayısıyla orantılı gelir; ildeki memnuniyet düşer.',1),
 ('hosgeldin','il','Yeni hemşehriye hoş geldin desteği','tl',0,0,20000,500,'kolaylik',
  'İle yeni taşınan ya da bu ilde hesap açan oyuncuya bir kez ödenir.',
  'İle ilk kez yerleşen oyuncunun cüzdanına bir kez yatar (her ilde bir kez).',
  'Her ödeme belediye kasasından tutar × 2.000 hane kadar düşer; kasa yetmezse ödenmez.',2)
on conflict (kod) do update set kapsam = excluded.kapsam, ad = excluded.ad, birim = excluded.birim, varsayilan = excluded.varsayilan,
  min = excluded.min, max = excluded.max, adim = excluded.adim, tur = excluded.tur, aciklama = excluded.aciklama,
  oyuncu = excluded.oyuncu, devlet = excluded.devlet, sira = excluded.sira;

create table if not exists oyun.duzenlemeler(
  kod      text primary key references oyun.duzenleme_tanim(kod),
  deger    numeric not null,
  kaynak   text not null check (kaynak in ('kararname','kanun','anayasa')),
  ref_id   bigint,                 -- kararname / kanun id
  zaman    timestamptz not null
);
create table if not exists oyun.il_duzenleme(
  il_id  smallint not null references oyun.iller(id),
  kod    text not null references oyun.duzenleme_tanim(kod),
  deger  numeric not null,
  baskan uuid,
  zaman  timestamptz not null,
  primary key (il_id, kod)
);
create table if not exists oyun.hosgeldin_kayit(
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  il_id   smallint not null,
  zaman   timestamptz not null,
  primary key (user_id, il_id)
);

-- Anayasal sınırlar (yalnız halk oylaması/anayasa değişikliğiyle değişir)
create table if not exists oyun.anayasa(
  kod    text primary key,
  ad     text not null,
  deger  numeric not null,
  min    numeric not null,
  max    numeric not null,
  aciklama text not null,
  kanun_id bigint,
  zaman  timestamptz
);
insert into oyun.anayasa(kod, ad, deger, min, max, aciklama) values
 ('kararname_sinir','Cumhurbaşkanının günlük kararname yetkisi',3,0,5,'Cumhurbaşkanı günde en fazla bu kadar kararname çıkarabilir. 0 olursa kararname yetkisi kalkar.'),
 ('vergi_tavani','Gelir vergisinin anayasal tavanı',45,20,45,'Meclis bütçe kanunuyla vergi bandını bu tavanın üstüne çıkaramaz.')
on conflict (kod) do update set ad = excluded.ad, min = excluded.min, max = excluded.max, aciklama = excluded.aciklama;

-- Kamu varlıkları (özelleştirilebilir) ve borçlar (tahvil)
alter table oyun.ulke add column if not exists kamu_varlik numeric not null default 400;   -- milyar ₺
create table if not exists oyun.borclar(
  id           bigserial primary key,
  kararname_id bigint,
  anapara      numeric not null,
  faiz         numeric not null,         -- toplam faiz oranı (%)
  gunluk       numeric not null,         -- günlük geri ödeme (milyar ₺)
  kalan_gun    int not null,
  zaman        timestamptz not null
);

-- Halk oylaması
create table if not exists oyun.referandumlar(
  id        bigserial primary key,
  kanun_id  bigint not null unique references oyun.kanunlar(id) on delete cascade,
  baslik    text not null,
  olusturma timestamptz not null,
  oy_bas    timestamptz not null,
  oy_bit    timestamptz not null,
  durum     text not null default 'bekliyor' check (durum in ('bekliyor','oylamada','sonuclandi')),
  evet      int not null default 0,
  hayir     int not null default 0,
  secmen    int,                         -- oy kullanma hakkı olan oyuncu sayısı (sonuçta)
  sonuc     text check (sonuc in ('kabul','ret')),
  hatirlatma boolean not null default false
);
-- Oy gizliliği: kimin oy kullandığı ayrı, sandıktaki Evet/Hayır sayısı ayrı tutulur; ikisi birbirine bağlanamaz.
create table if not exists oyun.referandum_katilim(
  ref_id bigint not null references oyun.referandumlar(id) on delete cascade,
  secmen uuid not null,
  zaman  timestamptz not null,
  primary key (ref_id, secmen)
);
create table if not exists oyun.referandum_sandik(
  ref_id bigint not null references oyun.referandumlar(id) on delete cascade,
  il_id  smallint not null,
  evet   int not null default 0,
  hayir  int not null default 0,
  primary key (ref_id, il_id)
);
create table if not exists oyun.oy_cezasi_kayit(
  anahtar text primary key,              -- 's<secim_id>' ya da 'r<referandum_id>'
  ceza    numeric not null,
  kisi    int not null,
  toplam  numeric not null,
  zaman   timestamptz not null
);

-- Kanun türleri ve durumları
alter table oyun.kanunlar drop constraint if exists kanunlar_tur_check;
alter table oyun.kanunlar add constraint kanunlar_tur_check check (tur in ('serbest','butce','secim','iptal','duzenleme','anayasa'));
alter table oyun.kanunlar drop constraint if exists kanunlar_durum_check;
alter table oyun.kanunlar add constraint kanunlar_durum_check
  check (durum in ('gorusmede','oylamada','cb_onayinda','israr','yururlukte','ret','dustu','kaduk','geri_cekildi','halkoylamasinda'));
alter table oyun.kanun_oylari drop constraint if exists kanun_oylari_asama_check;
alter table oyun.kanun_oylari add constraint kanun_oylari_asama_check check (asama in ('ilk','israr','imza'));
alter table oyun.kararnameler drop constraint if exists kararnameler_tur_check;
alter table oyun.kararnameler add constraint kararnameler_tur_check
  check (tur in ('serbest','il_destek','odenek','vergi','ikramiye','duzenleme','ozellestirme','tahvil'));
alter table oyun.gazete drop constraint if exists gazete_tur_check;
alter table oyun.gazete add constraint gazete_tur_check check (tur in ('kanun','kararname','atama','icraat','anayasa','referandum','belediye'));

-- ---------------------------------------------------------------------
-- DEĞER OKUMA
-- ---------------------------------------------------------------------
create or replace function oyun.duz(p_kod text) returns numeric language sql stable as $$
  select coalesce((select deger from oyun.duzenlemeler where kod = p_kod), (select varsayilan from oyun.duzenleme_tanim where kod = p_kod), 0)
$$;
create or replace function oyun.il_duz(p_il smallint, p_kod text) returns numeric language sql stable as $$
  select coalesce((select deger from oyun.il_duzenleme where il_id = p_il and kod = p_kod), (select varsayilan from oyun.duzenleme_tanim where kod = p_kod), 0)
$$;
create or replace function oyun.anayasa_deger(p_kod text) returns numeric language sql stable as $$
  select deger from oyun.anayasa where kod = p_kod
$$;
create or replace function oyun.kumbara_saat() returns numeric language sql stable as $$
  select oyun.duz('kumbara_saat')
$$;
create or replace function oyun.birim_yaz(x numeric, b text) returns text language sql immutable as $$
  select case b when 'tl_ay' then oyun.tl(x) || ' ₺/ay' when 'tl_gun' then oyun.tl(x) || ' ₺/gün' when 'tl' then oyun.tl(x) || ' ₺'
                when 'adet' then oyun.tl(x) || ' adet'
                when 'yuzde' then '%' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'binde' then '‰' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'saat' then round(x)::text || ' saat'
                when 'kat' then '×' || replace(regexp_replace(trim(to_char(x, 'FM990.00')), '\.?0+$', ''), '.', ',')
                else coalesce(x::text, '') end
$$;
create or replace function oyun.duz_yaz(p_kod text, x numeric) returns text language sql stable as $$
  select oyun.birim_yaz(x, (select birim from oyun.duzenleme_tanim where kod = p_kod))
$$;
create or replace function oyun.kaynak_ad(k text) returns text language sql immutable as $$
  select case k when 'anayasa' then 'Anayasa' when 'kanun' then 'Kanun' when 'kararname' then 'Cumhurbaşkanlığı kararnamesi' else 'Varsayılan' end
$$;

-- Değer aralık denetimi (adım katına yuvarlar)
create or replace function oyun.duzenleme_dogrula(p_kod text, p_deger numeric, p_kapsam text default 'ulke') returns numeric language plpgsql stable as $$
declare d oyun.duzenleme_tanim; v numeric;
begin
  select * into d from oyun.duzenleme_tanim where kod = p_kod;
  if d.kod is null or d.kapsam <> p_kapsam then raise exception 'Geçersiz düzenleme.'; end if;
  if p_deger is null then raise exception '"%" için bir değer girmelisin.', d.ad; end if;
  v := round(p_deger / d.adim) * d.adim;
  if v < d.min or v > d.max then
    raise exception '"%" % ile % arasında olmalı.', d.ad, oyun.duz_yaz(d.kod, d.min), oyun.duz_yaz(d.kod, d.max);
  end if;
  return v;
end $$;

-- Ülke düzenlemesini uygula. Hiyerarşiye uymazsa false döner (çağıran karar verir).
create or replace function oyun.duzenleme_uygula(p_kod text, p_deger numeric, p_kaynak text, p_ref bigint, t timestamptz) returns boolean language plpgsql as $$
declare mevcut oyun.duzenlemeler;
begin
  select * into mevcut from oyun.duzenlemeler where kod = p_kod for update;
  if mevcut.kod is not null then
    if mevcut.kaynak = 'anayasa' and p_kaynak <> 'anayasa' then return false; end if;
    if mevcut.kaynak = 'kanun' and p_kaynak = 'kararname' then return false; end if;
  end if;
  insert into oyun.duzenlemeler(kod, deger, kaynak, ref_id, zaman) values (p_kod, p_deger, p_kaynak, p_ref, t)
  on conflict (kod) do update set deger = excluded.deger, kaynak = excluded.kaynak, ref_id = excluded.ref_id, zaman = excluded.zaman;
  return true;
end $$;

-- Hiyerarşi engeli: kim değiştiremez, neden?
create or replace function oyun.duzenleme_engel(p_kod text, p_kaynak text) returns text language sql stable as $$
  select case when d.kaynak = 'anayasa' and p_kaynak <> 'anayasa'
                then 'Bu kural anayasada düzenlenmiş; ancak halk oylamasıyla yapılacak bir anayasa değişikliğiyle değiştirilebilir.'
              when d.kaynak = 'kanun' and p_kaynak = 'kararname'
                then 'Bu konu Meclis tarafından kanunla düzenlenmiş; kanunla düzenlenen konuda cumhurbaşkanlığı kararnamesi çıkarılamaz.' end
  from (select 1) x left join oyun.duzenlemeler d on d.kod = p_kod
$$;

-- ---------------------------------------------------------------------
-- EKONOMİYE ETKİ (önizleme, vaat maliyeti, günlük hesap)
--   gunluk > 0: hazineye günlük maliyet (milyar ₺); < 0: gelir
-- ---------------------------------------------------------------------
create or replace function oyun.duzenleme_etki(p_kod text, p_deger numeric) returns jsonb language sql stable as $$
  with x as (select p_deger v, oyun.duz(p_kod) m)
  select jsonb_build_object(
    'gunluk', round(case p_kod when 'servet_vergisi' then -0.3 * (v - m)
                               when 'yeni_hibe' then (v - m) * 5000 / 1e9
                               when 'aday_destek' then 0.004 * (v - m) else 0 end, 3),
    'enflasyon', round(case p_kod when 'seri_tavan' then 0.05 * (v - m) when 'yeni_hibe' then 0.02 * (v - m) / 1000 else 0 end, 2),
    'buyume', round(case p_kod when 'servet_vergisi' then -0.08 * (v - m) when 'kumbara_saat' then -0.1 * (v - m) else 0 end, 2),
    'memnuniyet', round(case p_kod when 'servet_vergisi' then 0.15 * (v - m) when 'oy_cezasi' then -0.4 * (v - m) / 1000
                                   when 'yeni_hibe' then 0.04 * (v - m) / 1000 when 'seri_tavan' then 0.03 * (v - m)
                                   when 'kumbara_saat' then 0.5 * (v - m) when 'vekil_kesinti' then 0.04 * (v - m) else 0 end, 2))
  from x
$$;

-- Göstergelerin hedeflerine eklenen kaymalar (her gece)
create or replace function oyun.mevzuat_makro() returns jsonb language sql stable as $$
  select jsonb_build_object(
    'buyume', -0.08 * oyun.duz('servet_vergisi') - 0.1 * (oyun.duz('kumbara_saat') - 8),
    'enflasyon', 0.05 * (oyun.duz('seri_tavan') - 30) + 0.02 * oyun.duz('yeni_hibe') / 1000,
    'memnuniyet', 0.15 * oyun.duz('servet_vergisi') - 0.4 * oyun.duz('oy_cezasi') / 1000 + 0.04 * oyun.duz('yeni_hibe') / 1000
                  + 0.03 * (oyun.duz('seri_tavan') - 30) + 0.5 * (oyun.duz('kumbara_saat') - 8) + 0.04 * oyun.duz('vekil_kesinti'))
$$;

-- Ülkenin günlük hesabı: 07'deki kalemlere servet vergisi, mevzuat giderleri ve borç ödemesi eklendi
create or replace function oyun.ulke_hesap(u oyun.ulke) returns jsonb language sql stable as $$
  with x as (select
      round(u.asgari / 30 * 0.6 * 25e6 * u.vergi / 100 / 1e9, 3) gv,
      round(9.5 * (1 + u.buyume / 50) * u.endeks, 3) diger,
      round(0.3 * oyun.duz('servet_vergisi'), 3) servet,
      round(10 * u.endeks, 3) cari,
      round((select sum(oyun.il_gunluk_gelir(mv)) from oyun.iller) * 0.5 * u.belediye_payi / 10 * u.endeks, 3) bel,
      round(u.destek * 8e6 / 1e9, 3) destek,
      round(oyun.duz('yeni_hibe') * 5000 / 1e9 + 0.004 * oyun.duz('aday_destek'), 3) mevzuat,
      round(coalesce((select sum(gunluk) from oyun.borclar where kalan_gun > 0), 0), 3) borc)
  select jsonb_build_object('gelir_vergisi', gv, 'diger_gelir', diger, 'servet', servet, 'gelir', gv + diger + servet,
                            'cari', cari, 'belediye', bel, 'destek', destek, 'mevzuat', mevzuat, 'borc', borc,
                            'gider', cari + bel + destek + mevzuat + borc,
                            'denge', round(gv + diger + servet - cari - bel - destek - mevzuat - borc, 3)) from x
$$;

-- İlin günlük geliri: emlak vergisi eklendi (ildeki hane × günlük vergi)
create or replace function oyun.il_gelir(p_il smallint) returns numeric language sql stable as $$
  select round(oyun.il_gunluk_gelir(i.mv) * u.endeks * (0.5 + d.gelisim / 100) * (0.5 + 0.5 * u.belediye_payi / 10) * (1 + d.kent_vergisi / 10)
               + oyun.il_duz(i.id, 'emlak') * u.endeks * oyun.nufus('il_hane') * i.mv / 600 / 1e9, 4)
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$$;

-- ---------------------------------------------------------------------
-- OYUNCUYA DOĞRUDAN ETKİLER
-- ---------------------------------------------------------------------
-- Vekilin son 7 günde katılmadığı oylamaların oranı (0-1)
create or replace function oyun.vekil_devamsizlik(u uuid, t timestamptz) returns numeric language sql stable as $$
  with k as (select k.id from oyun.kanunlar k
             where k.oy_bit <= t and k.oy_bit > t - interval '7 days' and k.durum not in ('geri_cekildi','gorusmede','oylamada')
               and exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.asama = 'ilk')   -- gerçekten oylanmış olanlar
               and exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv' and m.bas <= k.oy_bas))
  select case when count(*) = 0 then 0
              else round(1 - count(*) filter (where exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = u and o.asama = 'ilk'))::numeric / count(*), 3) end
  from k
$$;
create or replace function oyun.vekil_kesinti_orani(u uuid, t timestamptz) returns numeric language sql stable as $$
  select round(oyun.duz('vekil_kesinti') * oyun.vekil_devamsizlik(u, t), 1)
$$;

-- Günün ilk toplamasında: servet vergisi ve emlak vergisi
create or replace function oyun.gunluk_kesinti(u uuid, t timestamptz) returns numeric language plpgsql as $$
declare p oyun.profiller; c oyun.cuzdan; s numeric; muaf numeric; ks numeric := 0; em numeric; top numeric := 0; ilad text; banka numeric; a numeric; b numeric;
begin
  select * into p from oyun.profiller where id = u;
  select * into c from oyun.cuzdan where user_id = u;
  s := oyun.duz('servet_vergisi');
  if s > 0 then
    muaf := round(250000 * (select endeks from oyun.ulke where id = 1));
    banka := oyun.mevduat_toplam(u);            -- bankadaki mevduat da servete dahildir (15_ekonomi3)
    ks := floor(greatest(0, c.para + banka - muaf) * s / 1000);
    if ks > 0 then
      a := least(ks, c.para);
      if a > 0 then
        perform oyun.para_islem(u, -a, 'servet', format('Servet vergisi (binde %s, %s ₺ muafiyetin üstü%s)', replace(s::text, '.', ','), oyun.tl(muaf),
                                                       case when banka > 0 then ', banka mevduatı dahil' else '' end), t);
      end if;
      b := least(ks - a, floor(coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0)));
      if b > 0 then
        update oyun.banka_musteri set vadesiz = vadesiz - b where user_id = u;
        perform oyun.banka_kayit(u, 'vadesiz', -b, 'Servet vergisi (cüzdan yetmedi)', t);
      end if;
      top := top + a + b;
    end if;
  end if;
  em := round(oyun.il_duz(p.il_id, 'emlak') * (select endeks from oyun.ulke where id = 1));
  if em > 0 then
    em := least(em, (select para from oyun.cuzdan where user_id = u));
    if em > 0 then
      select ad into ilad from oyun.iller where id = p.il_id;
      perform oyun.para_islem(u, -em, 'emlak', ilad || ' Belediyesi emlak vergisi (günlük)', t);
      top := top + em;
    end if;
  end if;
  perform oyun.kira_ode(u, t);
  return top;
end $$;

-- Hoş geldin: devlet hibesi (yeni hesap) ve belediye hoş geldin desteği (her ilde bir kez)
create or replace function oyun.hosgeldin_ode(u uuid, p_il smallint, p_yeni boolean, t timestamptz) returns void language plpgsql as $$
declare h numeric; hb numeric; maliyet numeric; ilad text;
begin
  if p_yeni then
    hb := round(oyun.duz('yeni_hibe'));
    if hb > 0 then
      perform oyun.para_islem(u, hb, 'hibe', 'Devletin yeni vatandaş hoş geldin hibesi', t);
      perform oyun.bildir(u, format('Hoş geldin! Devlet cüzdanına %s ₺ hoş geldin hibesi yatırdı.', oyun.tl(hb)), t);
    end if;
  end if;
  h := round(oyun.il_duz(p_il, 'hosgeldin'));
  if h <= 0 or exists (select 1 from oyun.hosgeldin_kayit where user_id = u and il_id = p_il) then return; end if;
  maliyet := h * 2000 / 1e9;
  select ad into ilad from oyun.iller where id = p_il;
  update oyun.il_durum set kasa = kasa - maliyet where il_id = p_il and coalesce(kasa, 0) >= maliyet;
  if not found then
    perform oyun.bildir(u, format('%s Belediyesi''nin kasası yetmediği için hoş geldin desteği ödenemedi.', ilad), t);
    return;
  end if;
  insert into oyun.hosgeldin_kayit(user_id, il_id, zaman) values (u, p_il, t);
  perform oyun.para_islem(u, h, 'hosgeldin', ilad || ' Belediyesi hoş geldin desteği', t);
  perform oyun.bildir(u, format('%s''e hoş geldin! Belediye cüzdanına %s ₺ hoş geldin desteği yatırdı.', ilad, oyun.tl(h)), t);
end $$;

create or replace function oyun.profil_hosgeldin_tg() returns trigger language plpgsql security definer set search_path = oyun, public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    perform oyun.hosgeldin_ode(new.id, new.il_id, true, oyun.simdi());
  elsif new.il_id is distinct from old.il_id then
    perform oyun.hosgeldin_ode(new.id, new.il_id, false, oyun.simdi());
  end if;
  return null;
end $$;
drop trigger if exists profil_hosgeldin on oyun.profiller;
create trigger profil_hosgeldin after insert or update of il_id on oyun.profiller
  for each row execute function oyun.profil_hosgeldin_tg();

-- Oy kullanma sayısı kıdemi artırır: halk oylamaları da sayılır
create or replace function oyun.kidem_puani(u uuid) returns numeric language sql stable as $$
  select floor(coalesce((select kidem from oyun.cuzdan where user_id = u), 0)
               + 3 * ((select count(*) from oyun.oylar where secmen = u) + (select count(*) from oyun.referandum_katilim where secmen = u)))
$$;

-- ---------------------------------------------------------------------
-- HALK OYLAMASI
-- ---------------------------------------------------------------------
-- Oylama günü: en az 24 saat kampanya; 08:00-20:00 arası
create or replace function oyun.referandum_baslat(p_kanun bigint, t timestamptz) returns bigint language plpgsql as $$
declare k oyun.kanunlar; gun date; bas timestamptz; yeni bigint;
begin
  select * into k from oyun.kanunlar where id = p_kanun;
  gun := ((t + interval '24 hours') at time zone 'Europe/Istanbul')::date;
  bas := (gun + time '08:00') at time zone 'Europe/Istanbul';
  if bas < t + interval '24 hours' then gun := gun + 1; bas := (gun + time '08:00') at time zone 'Europe/Istanbul'; end if;
  update oyun.kanunlar set durum = 'halkoylamasinda' where id = k.id;
  insert into oyun.referandumlar(kanun_id, baslik, olusturma, oy_bas, oy_bit)
  values (k.id, k.baslik, t, bas, (gun + time '20:00') at time zone 'Europe/Istanbul') returning id into yeni;
  perform oyun.gazete_ekle('referandum', format('Halk oylaması kararı: %s', k.baslik),
    format('Anayasa değişikliği %s tarihinde 08:00-20:00 arasında halkoyuna sunulacak. Oyuna %s tarihinden önce kayıtlı her vatandaş oy kullanabilir.',
           to_char(gun, 'DD.MM.YYYY'), to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')), yeni, t);
  perform oyun.olay('referandum', format('"%s" halkoyuna sunuluyor. Sandıklar %s günü 08:00''de açılacak.', k.baslik, to_char(gun, 'DD.MM.YYYY')), null, null, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.id, t, format('Halk oylaması: "%s" anayasa değişikliği %s günü sandıkta. Evet ya da Hayır, karar senin.', k.baslik, to_char(gun, 'DD.MM.YYYY'))
    from oyun.profiller x where not x.yasakli;
  return yeni;
end $$;

-- Oy kullanma hakkı: kütük (halk oylaması kararından önce kayıtlı), yasaklı değil, hesap yaşı yeterli
create or replace function oyun.ref_engeli(p oyun.profiller, r oyun.referandumlar) returns text language sql stable as $$
  select case when p.yasakli then 'Hesabın askıya alınmış.'
              when p.olusturma > r.olusturma then 'Seçmen kütüğü halk oylaması kararıyla kesinleşti; sonradan açılan hesaplar bu oylamada oy kullanamaz.'
              else oyun.uyari(p, r.oy_bas) end
$$;

create or replace function oyun.ref_secmen_say(r oyun.referandumlar) returns int language sql stable as $$
  select count(*)::int from oyun.profiller p where oyun.ref_engeli(p, r) is null
$$;

create or replace function oyun.ref_json(r oyun.referandumlar, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', r.id, 'kanun_id', r.kanun_id, 'baslik', r.baslik, 'oy_bas', r.oy_bas, 'oy_bit', r.oy_bit, 'olusturma', r.olusturma,
    'durum', r.durum, 'sonuc', r.sonuc, 'evet', r.evet, 'hayir', r.hayir, 'secmen', r.secmen,
    'asama', case when r.durum = 'sonuclandi' then 'bitti' when t >= r.oy_bas and t < r.oy_bit then 'oy' when t < r.oy_bas then 'kampanya' else 'sayim' end,
    'oy_kullandim', exists (select 1 from oyun.referandum_katilim k where k.ref_id = r.id and k.secmen = p.id),
    'engel', oyun.ref_engeli(p, r),
    'veri', (select veri from oyun.kanunlar where id = r.kanun_id),
    'teklif_eden', (select oyun.kad(teklif_eden) from oyun.kanunlar where id = r.kanun_id))
$$;

create or replace function public.referandumlar(p_limit int default 20) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(oyun.ref_json(r, p, t) order by (r.durum <> 'sonuclandi') desc, r.oy_bas desc)
                   from (select * from oyun.referandumlar order by oy_bas desc limit least(greatest(p_limit, 1), 50)) r), '[]'::jsonb);
end $$;

create or replace function public.referandum_detay(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.referandumlar; k oyun.kanunlar;
begin
  select * into r from oyun.referandumlar where id = p_id;
  if r.id is null then raise exception 'Halk oylaması bulunamadı.'; end if;
  select * into k from oyun.kanunlar where id = r.kanun_id;
  return oyun.ref_json(r, p, t) || jsonb_build_object(
    'metin', k.metin, 'meclis', k.sonuc_metin, 'aciklama', oyun.anayasa_aciklama(k.veri),
    'katilim', case when r.durum = 'sonuclandi' then r.evet + r.hayir else (select count(*) from oyun.referandum_katilim where ref_id = r.id) end,
    'iller', case when r.durum = 'sonuclandi' then
      coalesce((select jsonb_agg(jsonb_build_object('il_id', s.il_id, 'ad', i.ad, 'evet', s.evet, 'hayir', s.hayir) order by i.ad)
                from oyun.referandum_sandik s join oyun.iller i on i.id = s.il_id where s.ref_id = r.id), '[]'::jsonb) end);
end $$;

create or replace function public.referandum_oy(p_id bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.referandumlar; e text;
begin
  if p_oy not in ('evet','hayir') then raise exception 'Geçersiz oy.'; end if;
  select * into r from oyun.referandumlar where id = p_id for update;
  if r.id is null then raise exception 'Halk oylaması bulunamadı.'; end if;
  if r.durum = 'sonuclandi' or t < r.oy_bas or t >= r.oy_bit then raise exception 'Sandık şu anda kapalı (oy saatleri 08:00–20:00).'; end if;
  e := oyun.ref_engeli(p, r);
  if e is not null then raise exception '%', e; end if;
  insert into oyun.referandum_katilim(ref_id, secmen, zaman) values (r.id, p.id, t) on conflict do nothing;
  if not found then raise exception 'Bu halk oylamasında zaten oy kullandın.'; end if;
  insert into oyun.referandum_sandik(ref_id, il_id, evet, hayir) values (r.id, p.il_id, (p_oy = 'evet')::int, (p_oy = 'hayir')::int)
  on conflict (ref_id, il_id) do update set evet = oyun.referandum_sandik.evet + excluded.evet, hayir = oyun.referandum_sandik.hayir + excluded.hayir;
  return public.referandum_detay(p_id);
end $$;

-- ---------------------------------------------------------------------
-- ANAYASA DEĞİŞİKLİĞİ
--   veri: {madde: 'duzenleme', kod, deger}   bir kuralı anayasaya bağlar (kanun ve kararname artık değiştiremez)
--         {madde: 'serbest_birak', kod}       anayasadaki kuralı kanuna bırakır (Meclis yeniden düzenleyebilir)
--         {madde: 'kararname_sinir', deger}   cumhurbaşkanının günlük kararname sayısı (0-5)
--         {madde: 'vergi_tavani', deger}      gelir vergisinin anayasal tavanı (%20-45)
-- ---------------------------------------------------------------------
create or replace function oyun.anayasa_dogrula(p_veri jsonb) returns jsonb language plpgsql stable as $$
declare m text := p_veri ->> 'madde'; a oyun.anayasa; v numeric;
begin
  if m = 'duzenleme' then
    v := oyun.duzenleme_dogrula(p_veri ->> 'kod', (p_veri ->> 'deger')::numeric, 'ulke');
    return jsonb_build_object('madde', m, 'kod', p_veri ->> 'kod', 'deger', v);
  elsif m = 'serbest_birak' then
    if not exists (select 1 from oyun.duzenlemeler where kod = p_veri ->> 'kod' and kaynak = 'anayasa') then
      raise exception 'Bu kural zaten anayasada değil.';
    end if;
    return jsonb_build_object('madde', m, 'kod', p_veri ->> 'kod');
  elsif m in ('kararname_sinir','vergi_tavani') then
    select * into a from oyun.anayasa where kod = m;
    v := round((p_veri ->> 'deger')::numeric);
    if v is null or v < a.min or v > a.max then raise exception '"%" % ile % arasında olmalı.', a.ad, a.min, a.max; end if;
    if v = a.deger then raise exception 'Bu madde zaten bu değerde.'; end if;
    return jsonb_build_object('madde', m, 'deger', v);
  end if;
  raise exception 'Geçersiz anayasa maddesi.';
end $$;

create or replace function oyun.anayasa_aciklama(v jsonb) returns text language sql stable as $$
  select case v ->> 'madde'
    when 'duzenleme' then format('%s: %s olarak anayasaya bağlanır. Bundan sonra kanunla ya da kararnameyle değiştirilemez.',
                                 (select ad from oyun.duzenleme_tanim where kod = v ->> 'kod'), oyun.duz_yaz(v ->> 'kod', (v ->> 'deger')::numeric))
    when 'serbest_birak' then format('%s anayasadan çıkarılır; Meclis yeniden kanunla düzenleyebilir.', (select ad from oyun.duzenleme_tanim where kod = v ->> 'kod'))
    when 'kararname_sinir' then case when (v ->> 'deger')::numeric = 0 then 'Cumhurbaşkanının kararname yetkisi kaldırılır.'
                                     else format('Cumhurbaşkanı günde en fazla %s kararname çıkarabilir.', v ->> 'deger') end
    when 'vergi_tavani' then format('Gelir vergisinin anayasal tavanı %%%s olur.', v ->> 'deger') end
$$;

create or replace function oyun.anayasa_uygula(k oyun.kanunlar, t timestamptz) returns void language plpgsql as $$
declare v jsonb := k.veri; m text := k.veri ->> 'madde'; tv numeric;
begin
  if m = 'duzenleme' then
    perform oyun.duzenleme_uygula(v ->> 'kod', (v ->> 'deger')::numeric, 'anayasa', k.id, t);
  elsif m = 'serbest_birak' then
    update oyun.duzenlemeler set kaynak = 'kanun', ref_id = k.id, zaman = t where kod = v ->> 'kod' and kaynak = 'anayasa';
  elsif m in ('kararname_sinir','vergi_tavani') then
    update oyun.anayasa set deger = (v ->> 'deger')::numeric, kanun_id = k.id, zaman = t where kod = m;
    if m = 'vergi_tavani' then
      tv := (v ->> 'deger')::numeric;
      update oyun.ulke set vergi_ust = least(vergi_ust, tv), vergi_alt = least(vergi_alt, tv), vergi = least(vergi, tv),
        vergi_kanun = least(vergi_kanun, tv) where id = 1;
    end if;
  end if;
end $$;

-- İmza: anayasa değişikliği teklifine görüşme süresinde vekiller imza verir
create or replace function public.kanun_imza(p_id bigint, p_imza boolean default true) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar;
begin
  if not oyun.aktif_vekil(p.id) then raise exception 'Anayasa değişikliği teklifini yalnızca milletvekilleri imzalayabilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then raise exception 'Meclis Başkanı teklif imzalayamaz.'; end if;
  select * into k from oyun.kanunlar where id = p_id;
  if k.tur <> 'anayasa' then raise exception 'İmza yalnızca anayasa değişikliği tekliflerinde toplanır.'; end if;
  if k.durum <> 'gorusmede' or t >= k.oy_bas then raise exception 'İmza süresi bitti.'; end if;
  if k.teklif_eden = p.id then raise exception 'Teklif sahibinin imzası zaten var.'; end if;
  if p_imza then
    insert into oyun.kanun_oylari(kanun_id, asama, vekil, parti_id, oy, zaman) values (k.id, 'imza', p.id, p.parti_id, 'kabul', t)
    on conflict do nothing;
  else
    delete from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza' and vekil = p.id;
  end if;
  return public.kanun_detay(p_id);
end $$;

-- ---------------------------------------------------------------------
-- ZAMANLAYICI (tick içinden her dakika)
-- ---------------------------------------------------------------------
create or replace function oyun.mevzuat_tick(t timestamptz) returns void language plpgsql as $$
declare r oyun.referandumlar; s oyun.secimler; k oyun.kanunlar; ceza numeric; n int; toplam numeric; pr oyun.profiller; m numeric; yuzde numeric;
        ceza_an timestamptz;
begin
  -- halk oylaması: sandık açılır
  for r in select * from oyun.referandumlar where durum = 'bekliyor' and t >= oy_bas loop
    update oyun.referandumlar set durum = 'oylamada' where id = r.id;
    if not r.hatirlatma then
      perform oyun.push_konuya('s_tum', null, 'Bugün halk oylaması var! 🗳️', format('"%s" için sandıklar 20:00''ye kadar açık. Evet mi, Hayır mı?', r.baslik),
                               jsonb_build_object('ekran', 'referandum', 'id', r.id));
      update oyun.referandumlar set hatirlatma = true where id = r.id;
    end if;
  end loop;
  -- halk oylaması: sayım
  for r in select * from oyun.referandumlar where durum in ('bekliyor','oylamada') and t >= oy_bit order by oy_bit loop
    select coalesce(sum(evet), 0), coalesce(sum(hayir), 0) into r.evet, r.hayir from oyun.referandum_sandik where ref_id = r.id;
    r.secmen := oyun.ref_secmen_say(r);
    r.sonuc := case when r.evet > r.hayir then 'kabul' else 'ret' end;
    update oyun.referandumlar set durum = 'sonuclandi', evet = r.evet, hayir = r.hayir, secmen = r.secmen, sonuc = r.sonuc where id = r.id;
    yuzde := case when r.evet + r.hayir > 0 then round(100.0 * r.evet / (r.evet + r.hayir), 1) else 0 end;
    if r.sonuc = 'kabul' then
      perform oyun.kanun_yururluk(r.kanun_id, r.oy_bit, format('Halk oylamasında %%%s Evet oyuyla kabul edildi (%s Evet, %s Hayır).', replace(yuzde::text, '.', ','), r.evet, r.hayir));
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = r.oy_bit,
        sonuc_metin = format('Halk oylamasında reddedildi: %%%s Hayır (%s Evet, %s Hayır).', replace((100 - yuzde)::text, '.', ','), r.evet, r.hayir) where id = r.kanun_id;
      perform oyun.gazete_ekle('referandum', format('Halk oylaması sonucu: %s — REDDEDİLDİ', r.baslik),
        format('%s Evet, %s Hayır. Anayasa değişikliği yürürlüğe girmedi.', r.evet, r.hayir), r.id, r.oy_bit);
    end if;
    perform oyun.olay('referandum', format('Halk oylaması sonuçlandı: "%s" %s (%%%s Evet, katılım %s/%s).', r.baslik,
      case when r.sonuc = 'kabul' then 'KABUL EDİLDİ' else 'REDDEDİLDİ' end, replace(yuzde::text, '.', ','), r.evet + r.hayir, r.secmen), null, null, r.oy_bit);
  end loop;
  -- sandığa gitmeyene idari para cezası (genel seçim, belediye seçimi, 2. tur ve halk oylaması)
  -- Geriye yürümez: ceza ancak sandık açılmadan önce yürürlükte olan kurala göre kesilir.
  ceza_an := coalesce((select zaman from oyun.duzenlemeler where kod = 'oy_cezasi'), '-infinity'::timestamptz);
  for s in select * from oyun.secimler x where x.tur in ('mv','bel','cb2') and x.durum <> 'bekliyor' and x.oy_bit <= t and x.oy_bit > t - interval '3 days'
             and not exists (select 1 from oyun.oy_cezasi_kayit c where c.anahtar = 's' || x.id) loop
    n := 0; toplam := 0; ceza := case when ceza_an <= s.oy_bas then round(oyun.duz('oy_cezasi')) else 0 end;
    if ceza > 0 then
      for pr in select p.* from oyun.profiller p
                where not p.yasakli and p.son_gorulme > s.oy_bas - interval '7 days' and oyun.oy_engeli(p, s) is null
                  and not exists (select 1 from oyun.oylar o join oyun.secimler s2 on s2.id = o.secim_id where o.secmen = p.id and s2.oy_bas = s.oy_bas)
                  and (s.tur <> 'bel' or exists (select 1 from oyun.adaylar a where a.secim_id = s.id and a.il_id = p.il_id))
                  and (s.tur <> 'mv' or exists (select 1 from oyun.adaylar a join oyun.secimler o on o.id = a.secim_id
                                                 where o.tur = 'mv_on' and o.donem = s.donem and a.il_id = p.il_id and a.sira is not null))
                  and (s.tur <> 'cb2' or exists (select 1 from oyun.adaylar a where a.secim_id = s.id)) loop
        perform oyun.cuzdanim(pr.id);
        m := least(ceza, (select para from oyun.cuzdan where user_id = pr.id));
        if m > 0 then
          perform oyun.para_islem(pr.id, -m, 'ceza', 'Seçimde oy kullanmama idari para cezası', t);
          perform oyun.bildir(pr.id, format('Seçimde oy kullanmadığın için %s ₺ idari para cezası kesildi.', oyun.tl(m)), t);
          n := n + 1; toplam := toplam + m;
        end if;
      end loop;
    end if;
    insert into oyun.oy_cezasi_kayit values ('s' || s.id, ceza, n, toplam, t);
  end loop;
  for r in select * from oyun.referandumlar x where x.durum = 'sonuclandi' and x.oy_bit <= t and x.oy_bit > t - interval '3 days'
             and not exists (select 1 from oyun.oy_cezasi_kayit c where c.anahtar = 'r' || x.id) loop
    n := 0; toplam := 0; ceza := case when ceza_an <= r.oy_bas then round(oyun.duz('oy_cezasi')) else 0 end;
    if ceza > 0 then
      for pr in select p.* from oyun.profiller p
                where p.son_gorulme > r.oy_bas - interval '7 days' and oyun.ref_engeli(p, r) is null
                  and not exists (select 1 from oyun.referandum_katilim rk where rk.ref_id = r.id and rk.secmen = p.id) loop
        perform oyun.cuzdanim(pr.id);
        m := least(ceza, (select para from oyun.cuzdan where user_id = pr.id));
        if m > 0 then
          perform oyun.para_islem(pr.id, -m, 'ceza', 'Halk oylamasında oy kullanmama idari para cezası', t);
          perform oyun.bildir(pr.id, format('Halk oylamasında oy kullanmadığın için %s ₺ idari para cezası kesildi.', oyun.tl(m)), t);
          n := n + 1; toplam := toplam + m;
        end if;
      end loop;
    end if;
    insert into oyun.oy_cezasi_kayit values ('r' || r.id, ceza, n, toplam, t);
  end loop;
  perform oyun.arsa_tick(t);
end $$;

-- Her gece: borç taksitleri (ulke_hesap gideri zaten hazineden düştü)
create or replace function oyun.mevzuat_gunluk(g date, t timestamptz) returns void language plpgsql as $$
begin
  update oyun.borclar set kalan_gun = kalan_gun - 1 where kalan_gun > 0;
end $$;

-- ---------------------------------------------------------------------
-- MEVZUAT EKRANI
-- ---------------------------------------------------------------------
create or replace function public.mevzuat() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.ulke; cbyim boolean; vekilim boolean; baskan smallint;
begin
  select * into u from oyun.ulke where id = 1;
  cbyim := exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null);
  vekilim := oyun.aktif_vekil(p.id);
  baskan := (select il_id from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null limit 1);
  return jsonb_build_object(
    'cb_mi', cbyim, 'vekil_mi', vekilim, 'baskan_il', baskan, 'il_ad', (select ad from oyun.iller where id = p.il_id),
    'kurallar', (select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'tur', d.tur, 'min', d.min, 'max', d.max, 'adim', d.adim,
                   'varsayilan', d.varsayilan, 'aciklama', d.aciklama, 'oyuncu', d.oyuncu, 'devlet', d.devlet,
                   'deger', oyun.duz(d.kod), 'yazi', oyun.duz_yaz(d.kod, oyun.duz(d.kod)),
                   'kaynak', coalesce(z.kaynak, 'varsayilan'), 'kaynak_ad', oyun.kaynak_ad(coalesce(z.kaynak, 'varsayilan')), 'zaman', z.zaman,
                   'ref_no', case z.kaynak when 'kararname' then (select no from oyun.kararnameler where id = z.ref_id)
                                           when 'kanun' then (select no from oyun.kanunlar where id = z.ref_id)
                                           when 'anayasa' then (select no from oyun.kanunlar where id = z.ref_id) end,
                   'cb_engel', oyun.duzenleme_engel(d.kod, 'kararname'), 'kanun_engel', oyun.duzenleme_engel(d.kod, 'kanun'),
                   'hazir', case when z.kaynak = 'kararname' and z.zaman > t - interval '24 hours' then z.zaman + interval '24 hours' end)
                 order by d.sira)
                 from oyun.duzenleme_tanim d left join oyun.duzenlemeler z on z.kod = d.kod where d.kapsam = 'ulke'),
    'il_kurallar', (select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'tur', d.tur, 'min', d.min, 'max', d.max, 'adim', d.adim,
                   'aciklama', d.aciklama, 'oyuncu', d.oyuncu, 'devlet', d.devlet,
                   'deger', oyun.il_duz(p.il_id, d.kod), 'yazi', oyun.duz_yaz(d.kod, oyun.il_duz(p.il_id, d.kod))) order by d.sira)
                    from oyun.duzenleme_tanim d where d.kapsam = 'il'),
    'anayasa', (select jsonb_agg(jsonb_build_object('kod', a.kod, 'ad', a.ad, 'deger', a.deger, 'min', a.min, 'max', a.max, 'aciklama', a.aciklama,
                  'kanun_no', (select no from oyun.kanunlar where id = a.kanun_id), 'zaman', a.zaman) order by a.kod) from oyun.anayasa a),
    'kamu_varlik', round(u.kamu_varlik, 1), 'hazine', round(u.hazine, 1), 'enflasyon', round(u.enflasyon, 1),
    'tahvil_faiz', oyun.tahvil_faiz(),
    'borclar', coalesce((select jsonb_agg(jsonb_build_object('anapara', b.anapara, 'faiz', b.faiz, 'gunluk', round(b.gunluk, 3), 'kalan_gun', b.kalan_gun,
                  'kalan', round(b.gunluk * b.kalan_gun, 1), 'zaman', b.zaman) order by b.zaman desc) from oyun.borclar b where b.kalan_gun > 0), '[]'::jsonb),
    'borc_toplam', round(coalesce((select sum(gunluk * kalan_gun) from oyun.borclar where kalan_gun > 0), 0), 1),
    'beni_etkileyen', jsonb_build_object(
       'servet', case when oyun.duz('servet_vergisi') > 0 then floor(greatest(0, coalesce((select para from oyun.cuzdan where user_id = p.id), 0)
                      - round(250000 * u.endeks)) * oyun.duz('servet_vergisi') / 1000) else 0 end,
       'emlak', round(oyun.il_duz(p.il_id, 'emlak') * u.endeks),
       'vekil_kesinti', case when vekilim then oyun.vekil_kesinti_orani(p.id, t) end,
       'kumbara_saat', oyun.kumbara_saat(), 'seri_tavan', oyun.duz('seri_tavan'), 'aday_destek', oyun.duz('aday_destek'),
       'oy_cezasi', oyun.duz('oy_cezasi')),
    'referandumlar', public.referandumlar(10));
end $$;

create or replace function public.mevzuat_onizle(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  return oyun.duzenleme_etki(p_kod, oyun.duzenleme_dogrula(p_kod, p_deger, 'ulke'));
end $$;

-- Tahvil faizi: enflasyon yükseldikçe borçlanma pahalılaşır (60 günde geri ödenir)
create or replace function oyun.tahvil_faiz() returns numeric language sql stable as $$
  select round(oyun.sinir(8 + enflasyon / 2, 8, 80), 1) from oyun.ulke where id = 1
$$;

-- ---------------------------------------------------------------------
-- BELEDİYE KARARLARI
-- ---------------------------------------------------------------------
create or replace function public.belediye_duzenle(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); v numeric; d oyun.duzenleme_tanim;
        son timestamptz; onceki numeric; ilad text;
begin
  v := oyun.duzenleme_dogrula(p_kod, p_deger, 'il');
  select * into d from oyun.duzenleme_tanim where kod = p_kod;
  select zaman, deger into son, onceki from oyun.il_duzenleme where il_id = m.il_id and kod = p_kod;
  if coalesce(onceki, d.varsayilan) = v then raise exception 'Değişiklik yok.'; end if;
  if son is not null and son > t - interval '24 hours' then
    raise exception '"%" 24 saatte bir değiştirilebilir (sonraki: %).', d.ad, to_char((son + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  insert into oyun.il_duzenleme(il_id, kod, deger, baskan, zaman) values (m.il_id, p_kod, v, p.id, t)
  on conflict (il_id, kod) do update set deger = excluded.deger, baskan = excluded.baskan, zaman = excluded.zaman;
  select ad into ilad from oyun.iller where id = m.il_id;
  perform oyun.gazete_ekle('belediye', format('%s Belediye Meclisi kararı: %s %s', ilad, d.ad, oyun.duz_yaz(p_kod, v)), d.oyuncu, null, t);
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s: %s %s → %s.', ilad, p.kad, d.ad, oyun.duz_yaz(p_kod, coalesce(onceki, d.varsayilan)), oyun.duz_yaz(p_kod, v)), m.il_id, p.parti_id, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.id, t, format('%s Belediyesi: %s artık %s. %s', ilad, d.ad, oyun.duz_yaz(p_kod, v), d.oyuncu)
    from oyun.profiller x where x.il_id = m.il_id and x.id <> p.id and not x.yasakli;
  return public.belediye_paneli();
end $$;

-- Belediye gelir işlemleri (negatif maliyetli "yatırım"): imar barışı ve arsa satışı
alter table oyun.belediye_yatirimlari add column if not exists tur text not null default 'yatirim';
insert into oyun.belediye_yatirimlari(kod, ad, aciklama, gun, bekleme_saat, gelisim, memnuniyet, sira, tur) values
 ('imar_barisi','İmar barışı','Kaçak yapılara harç karşılığı yapı kayıt belgesi. Kasaya 4 günlük taban gelir girer. Hemşehriye: kayıt dışı konutlar yasallaşınca kira ve geçim masrafı 14 gün %8 düşer. Bedeli: çarpık kentleşme gelişmişliği −3 düşürür; ildeki maaşlar kalıcı olarak yaklaşık %1,2 azalır.',-4,720,-3,2,3,'gelir'),
 ('arsa_satisi','Belediye arsası ihalesi','Kamu arazisi 48 saatlik açık artırmaya çıkar. O ilde yaşayan oyuncular pey sürer; kazanan arsanın sahibi olur ve her gün bedelin binde 4''ü kadar kira geliri alır. Kasaya, satış bedeline göre 6 günlük taban gelir civarında para girer. Diğer hemşehriler için yeşil alan azalır: gelişmişlik −1 (maaşlar ~%0,4 düşer), memnuniyet −3.',-6,336,-1,-3,4,'gelir')
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, gun = excluded.gun, bekleme_saat = excluded.bekleme_saat,
  gelisim = excluded.gelisim, memnuniyet = excluded.memnuniyet, sira = excluded.sira, tur = excluded.tur;

-- Belediye paneline il kuralları eklenir
create or replace function oyun.il_kurallar_json(p_il smallint, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'tur', d.tur, 'min', d.min, 'max', d.max, 'adim', d.adim,
           'aciklama', d.aciklama, 'oyuncu', d.oyuncu, 'devlet', d.devlet, 'deger', oyun.il_duz(p_il, d.kod),
           'yazi', oyun.duz_yaz(d.kod, oyun.il_duz(p_il, d.kod)),
           'hazir', (select z.zaman + interval '24 hours' from oyun.il_duzenleme z where z.il_id = p_il and z.kod = d.kod and z.zaman > t - interval '24 hours'),
           'gunluk_gelir', case when d.kod = 'emlak' then round(oyun.il_duz(p_il, 'emlak') * (select endeks from oyun.ulke where id = 1)
                                                               * oyun.nufus('il_hane') * (select mv from oyun.iller where id = p_il) / 600 / 1e9, 4) end,
           'birim_maliyet', case when d.kod = 'hosgeldin' then round(oyun.il_duz(p_il, 'hosgeldin') * 2000 / 1e9, 4) end) order by d.sira)
  from oyun.duzenleme_tanim d where d.kapsam = 'il'
$$;

-- ---------------------------------------------------------------------
-- BAKAN ADAYLARI (cumhurbaşkanının atama ekranı için arama)
-- ---------------------------------------------------------------------
create or replace function public.bakan_adaylari(p_ara text default '') returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a text := lower(btrim(coalesce(p_ara, '')));
begin
  perform oyun.cb_zorunlu(p);
  return coalesce((select jsonb_agg(x order by (x ->> 'uygun')::boolean desc, (x ->> 'kidem')::numeric desc) from (
    select jsonb_build_object('kad', pr.kad, 'il', (select ad from oyun.iller where id = pr.il_id), 'parti', oyun.parti_json(pr.parti_id),
             'kidem', oyun.kidem_puani(pr.id), 'statu', oyun.statu_ad(oyun.statu_basamak(oyun.kidem_puani(pr.id))),
             'gorev', oyun.rol_cakisma(pr.id, 'bakan'),
             'bakanlik', (select b.ad from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik where m.user_id = pr.id and m.tur = 'bakan' and m.bit is null),
             'uygun', oyun.rol_cakisma(pr.id, 'bakan') is null and oyun.uyari(pr, t) is null,
             'engel', coalesce(oyun.uyari(pr, t), case when oyun.rol_cakisma(pr.id, 'bakan') is not null then 'Şu an ' || oyun.rol_cakisma(pr.id, 'bakan') || ' görevinde' end)) x
    from oyun.profiller pr
    where not pr.yasakli and pr.id <> p.id and (a = '' or lower(pr.kad) like a || '%' or lower(pr.kad) like '%' || a || '%')
    order by (lower(pr.kad) like a || '%') desc, pr.son_gorulme desc nulls last limit 25) y), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- VAATLER: her yeni kuralın vaat karşılığı
-- ---------------------------------------------------------------------
insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama) values
 ('beyanname','servet_vergisi','Servet vergisini değiştireceğiz','binde','surekli',null,0,10,40,'Büyük servetlerden günlük vergi. Artırmak hazineye gelir getirir, büyümeyi biraz düşürür.'),
 ('beyanname','yeni_hibe','Yeni vatandaşa hoş geldin hibesi vereceğiz','tl','surekli','>=',1000,50000,41,'Oyuna yeni katılan her oyuncuya tek seferlik hibe.'),
 ('beyanname','aday_destek','Aday olmayı ucuzlatacağız (siyasi katılım fonu)','yuzde','surekli','>=',10,100,42,'Aday adaylığı ücretinin bu kadarını hazine öder.'),
 ('beyanname','seri_tavan','Düzenli çalışana daha yüksek devamlılık primi','yuzde','surekli','>=',35,60,43,'Seri priminin tavanı. Yükseltmek enflasyonu biraz artırır.'),
 ('beyanname','kumbara_saat','Esnek çalışma: maaş daha uzun birikecek','saat','surekli','>=',9,12,44,'Maaş kumbarasının kapasitesi. Büyümeyi biraz düşürür.'),
 ('beyanname','oy_cezasi','Sandığa gitmeyene cezayı değiştireceğiz','tl','surekli',null,0,5000,45,'Oy kullanmayan oyuncuya idari para cezası.'),
 ('beyanname','vekil_kesinti','Meclis''e gelmeyen vekilin maaşını keseceğiz','yuzde','surekli','>=',5,50,46,'Oylamalara katılmayan vekilin maaşından kesinti.'),
 ('beyanname','ozellestirme','Özelleştirmeyle hazineye kaynak yaratacağız','yok','tek',null,null,null,47,'Görev süresinde en az bir özelleştirme kararı.'),
 ('beyanname','referandum','Anayasa değişikliğini halkoyuna götüreceğiz','yok','tek',null,null,null,48,'Görev süresinde en az bir halk oylaması yapılır.'),
 ('mv','servet_vergisi','Servet vergisini kanunla belirleyeceğim','binde','tek',null,0,10,10,'Bu değeri getiren kanuna ya da anayasa değişikliğine kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','oy_cezasi','Sandığa gitmeyene cezayı kanunla belirleyeceğim','tl','tek',null,0,5000,11,'Bu değeri getiren kanuna kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','yeni_hibe','Yeni vatandaş hibesini kanunlaştıracağım','tl','tek','>=',1000,50000,12,'Bu hibeyi getiren kanuna kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','vekil_kesinti','Devamsız vekile maaş kesintisi getireceğim','yuzde','tek','>=',5,50,13,'Bu kesintiyi getiren kanuna kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','anayasa_imza','Anayasa değişikliği teklifine imza vereceğim','yok','tek',null,null,null,14,'Görev süresinde bir anayasa değişikliği teklifine imza verirsem tutulur.'),
 ('bel','emlak','Emlak vergisini değiştireceğim','tl_gun','surekli',null,0,300,9,'İlde yaşayan herkesten günlük emlak vergisi. Artırmak belediye kasasına gelir getirir.'),
 ('bel','hosgeldin','Yeni hemşehrilere hoş geldin desteği vereceğim','tl','surekli','>=',500,20000,10,'İle yerleşen oyuncuya bir kez ödenir; ilin nüfusunu büyütür.'),
 ('bel','imar_barisi','İmar barışı çıkaracağım','yok','tek',null,null,null,11,'Kasaya gelir getirir, gelişmişliği düşürür.')
on conflict (kapsam, kod) do update set ad = excluded.ad, birim = excluded.birim, tip = excluded.tip, yon = excluded.yon,
  min = excluded.min, max = excluded.max, sira = excluded.sira, aciklama = excluded.aciklama;

-- Bir vaadin "bugünkü değeri"
create or replace function oyun.vaat_mevcut(p_kapsam text, p_kod text, p_il smallint, p_parti bigint) returns numeric language sql stable as $$
  select case
    when p_kod in (select kod from oyun.duzenleme_tanim where kapsam = 'ulke') then oyun.duz(p_kod)
    when p_kod in (select kod from oyun.duzenleme_tanim where kapsam = 'il') then oyun.il_duz(p_il, p_kod)
    else (select case p_kod when 'asgari' then u.asgari when 'vergi' then u.vergi when 'kidem' then u.kidem_primi when 'destek' then u.destek
                   when 'tasinma' then u.tasinma_destek when 'vergi_tavan' then u.vergi_ust when 'belediye_payi' then u.belediye_payi
                   when 'baraj' then (select baraj from oyun.ayarlar where id = 1) when 'parti_yardim' then u.parti_yardim
                   when 'kent_vergisi' then (select kent_vergisi from oyun.il_durum where il_id = p_il)
                   when 'hemsehri' then (select hemsehri from oyun.il_durum where il_id = p_il)
                   when 'uye' then (select count(*) from oyun.profiller where parti_id = p_parti)
                   when 'kasa' then (select round(kasa) from oyun.partiler where id = p_parti)
                   when 'aday_ucret' then (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = p_parti) end
          from oyun.ulke u where u.id = 1) end
$$;

-- Profil zaman damgaları oyun saatini kullanır (üretimde oyun saati = gerçek saat; testte test saati)
alter table oyun.profiller alter column bildirim_okundu set default oyun.simdi();
alter table oyun.profiller alter column olusturma set default oyun.simdi();
alter table oyun.profiller alter column il_at set default oyun.simdi();


-- ---------------------------------------------------------------------
-- ARSA İHALESİ VE MÜLKLER (belediye arsası satışının oyuncuya doğrudan karşılığı)
-- ---------------------------------------------------------------------
create table if not exists oyun.arsa_ihale(
  id         bigserial primary key,
  il_id      smallint not null references oyun.iller(id),
  baskan     uuid,
  muhammen   numeric not null,          -- tahmini bedel (₺): açılış fiyatı
  bas        timestamptz not null,
  bit        timestamptz not null,
  en_yuksek  numeric,
  en_yuksek_user uuid references oyun.profiller(id) on delete set null,
  teklif_sayisi int not null default 0,
  durum      text not null default 'acik' check (durum in ('acik','satildi','satilamadi'))
);
create table if not exists oyun.mulkler(
  id       bigserial primary key,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  il_id    smallint not null,
  tur      text not null default 'arsa',
  bedel    numeric not null,
  gunluk   numeric not null,            -- günlük kira geliri (₺)
  alis     timestamptz not null,
  ihale_id bigint
);
create index if not exists mulkler_user on oyun.mulkler(user_id);

create or replace function oyun.arsa_muhammen(p_il smallint) returns numeric language sql stable as $$
  select round(25000 * u.endeks * (1 + i.mv / 20.0) * (0.5 + d.gelisim / 100) / 1000) * 1000
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$$;

create or replace function oyun.arsa_ihale_ac(p_il smallint, p oyun.profiller, t timestamptz) returns bigint language plpgsql as $$
declare yeni bigint; ilad text; mh numeric := oyun.arsa_muhammen(p_il);
begin
  if exists (select 1 from oyun.arsa_ihale where il_id = p_il and durum = 'acik') then raise exception 'İlde süren bir arsa ihalesi var.'; end if;
  insert into oyun.arsa_ihale(il_id, baskan, muhammen, bas, bit) values (p_il, p.id, mh, t, t + interval '48 hours') returning id into yeni;
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.gazete_ekle('belediye', format('%s Belediyesi arsa satış ihalesi', ilad),
    format('Muhammen bedel %s ₺. Teklifler 48 saat boyunca açık artırma usulüyle alınır; yalnızca ilde yaşayan vatandaşlar katılabilir.', oyun.tl(mh)), yeni, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.id, t, format('%s Belediyesi arsa ihalesine çıktı: açılış %s ₺, 48 saat. Kazanan her gün kira geliri alır (Gündem).', ilad, oyun.tl(mh))
    from oyun.profiller x where x.il_id = p_il and x.id <> p.id and not x.yasakli;
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s bir belediye arsasını ihaleye çıkardı.', ilad, p.kad), p_il, p.parti_id, t);
  return yeni;
end $$;

create or replace function public.arsa_teklif(p_ihale bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.arsa_ihale; asgari numeric; tutar numeric := round(p_tutar);
begin
  select * into a from oyun.arsa_ihale where id = p_ihale for update;
  if a.id is null or a.durum <> 'acik' or t >= a.bit then raise exception 'Bu ihale açık değil.'; end if;
  if p.il_id <> a.il_id then raise exception 'İhaleye yalnızca o ilde yaşayan vatandaşlar katılabilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null and il_id = a.il_id) then
    raise exception 'Belediye başkanı kendi belediyesinin ihalesine katılamaz.';
  end if;
  if oyun.uyari(p, t) is not null then raise exception 'İhaleye katılmak için: %', oyun.uyari(p, t); end if;
  if a.en_yuksek_user = p.id then raise exception 'En yüksek teklif zaten senin.'; end if;
  asgari := case when a.en_yuksek is null then a.muhammen else ceil(a.en_yuksek * 1.05 / 100) * 100 end;
  if tutar is null or tutar < asgari then raise exception 'Teklif en az % ₺ olmalı.', oyun.tl(asgari); end if;
  perform oyun.para_islem(p.id, -tutar, 'ihale', format('%s arsa ihalesi teklifi (teminat)', (select ad from oyun.iller where id = a.il_id)), t);
  if a.en_yuksek_user is not null then
    perform oyun.para_islem(a.en_yuksek_user, a.en_yuksek, 'ihale_iade', 'Arsa ihalesinde teklifin geçildi: teminat iadesi', t);
    perform oyun.bildir(a.en_yuksek_user, format('Arsa ihalesinde %s senin teklifini %s ₺ ile geçti. Teminatın iade edildi.', p.kad, oyun.tl(tutar)), t);
  end if;
  update oyun.arsa_ihale set en_yuksek = tutar, en_yuksek_user = p.id, teklif_sayisi = teklif_sayisi + 1,
    bit = greatest(bit, t + interval '10 minutes') where id = a.id;   -- son dakika teklifinde süre 10 dk uzar
  return public.ihaleler();
end $$;

create or replace function public.ihaleler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'acik', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'il_id', a.il_id, 'il', i.ad, 'muhammen', a.muhammen, 'bit', a.bit,
               'en_yuksek', a.en_yuksek, 'lider', oyun.kad(a.en_yuksek_user), 'benim', a.en_yuksek_user = p.id, 'teklif_sayisi', a.teklif_sayisi,
               'asgari', case when a.en_yuksek is null then a.muhammen else ceil(a.en_yuksek * 1.05 / 100) * 100 end,
               'katilabilir', p.il_id = a.il_id, 'kira_orani', 0.004) order by a.bit)
             from oyun.arsa_ihale a join oyun.iller i on i.id = a.il_id where a.durum = 'acik' and (a.il_id = p.il_id or a.en_yuksek_user = p.id)), '[]'::jsonb),
    'mulklerim', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'tur', m.tur, 'bedel', m.bedel, 'gunluk', m.gunluk, 'alis', m.alis) order by m.alis)
             from oyun.mulkler m join oyun.iller i on i.id = m.il_id where m.user_id = p.id), '[]'::jsonb));
end $$;

create or replace function oyun.arsa_tick(t timestamptz) returns void language plpgsql as $$
declare a oyun.arsa_ihale; ilad text; gelir numeric; taban numeric;
begin
  for a in select * from oyun.arsa_ihale where durum = 'acik' and t >= bit order by bit loop
    select ad into ilad from oyun.iller where id = a.il_id;
    if a.en_yuksek_user is null then
      update oyun.arsa_ihale set durum = 'satilamadi' where id = a.id;
      perform oyun.olay('belediye', format('%s Belediyesi arsa ihalesine teklif gelmedi; arsa satılamadı.', ilad), a.il_id, null, a.bit);
      if a.baskan is not null then perform oyun.bildir(a.baskan, 'Arsa ihalesine teklif gelmedi; arsa belediyede kaldı.', a.bit); end if;
      continue;
    end if;
    taban := oyun.il_gunluk_gelir((select mv from oyun.iller where id = a.il_id)) * (select endeks from oyun.ulke where id = 1);
    gelir := round(6 * taban * least(3, a.en_yuksek / a.muhammen), 4);
    update oyun.arsa_ihale set durum = 'satildi' where id = a.id;
    insert into oyun.mulkler(user_id, il_id, tur, bedel, gunluk, alis, ihale_id)
    values (a.en_yuksek_user, a.il_id, 'arsa', a.en_yuksek, round(a.en_yuksek * 0.004), a.bit, a.id);
    update oyun.il_durum set kasa = coalesce(kasa, 0) + gelir, gelisim = oyun.sinir(gelisim - 1, 0, 100), memnuniyet = oyun.sinir(memnuniyet - 3, 0, 100)
      where il_id = a.il_id;
    perform oyun.bildir(a.en_yuksek_user, format('Tebrikler! %s''deki belediye arsasını %s ₺ ile aldın. Her gün %s ₺ kira geliri cüzdanına yatar.',
                                                  ilad, oyun.tl(a.en_yuksek), oyun.tl(round(a.en_yuksek * 0.004))), a.bit);
    perform oyun.gazete_ekle('belediye', format('%s Belediyesi arsa ihalesi sonuçlandı', ilad),
      format('Arsa %s ₺ bedelle %s''e satıldı. Belediye kasasına %s milyar ₺ girdi; yeşil alan azaldı.', oyun.tl(a.en_yuksek), oyun.kad(a.en_yuksek_user), replace(gelir::text, '.', ',')), a.id, a.bit);
    perform oyun.olay('belediye', format('%s''de belediye arsası %s ₺ ile %s''e satıldı.', ilad, oyun.tl(a.en_yuksek), oyun.kad(a.en_yuksek_user)), a.il_id, null, a.bit);
  end loop;
end $$;

-- Mülk kira geliri: günün ilk toplamasında (topla → gunluk_kesinti içinden)
create or replace function oyun.kira_ode(u uuid, t timestamptz) returns numeric language plpgsql as $$
declare k numeric := coalesce((select sum(gunluk) from oyun.mulkler where user_id = u), 0);
begin
  if k > 0 then perform oyun.para_islem(u, k, 'kira', 'Arsa kira geliri (günlük)', t); end if;
  return k;
end $$;
-- =====================================================================
--  13 · TBMM BAŞKANLIK DİVANI VE SİYASİ PARTİ GRUPLARI
--
--  Gerçek usul (Anayasa md. 94, TBMM İçtüzüğü):
--   • Yeni Meclis göreve başlayınca en kıdemli üye Geçici Başkan olarak oturumu yönetir.
--   • TBMM Başkanı: adaylar 24 saat içinde bildirilir; seçim GİZLİ oyla yapılır.
--       1. ve 2. tur: üye tamsayısının (oyunda dolu sandalye) üçte iki çoğunluğu
--       3. tur: salt çoğunluk · 4. tur: 3. turda en çok oy alan iki aday arasında, en çok oy alan seçilir.
--     Meclis Başkanı Genel Kurul'da oy kullanamaz, kanun teklifi veremez, partisinin faaliyetlerine katılamaz.
--   • Meclis'te grup kurmak için 20 milletvekili gerekir (600'de 20). Oyunda eşik dolu sandalyeyle oranlanır (en az 2).
--   • Başkanvekilleri: en büyük 3 grubun her biri bir başkanvekili adayı gösterir; parti grubu kendi vekilleri arasında seçer.
--   • Grup başkanvekilleri: her parti grubu kendi üyeleri arasından seçer (2; sandalyelerin 1/6'sından büyük gruplarda 3).
--     Grup başkanvekili (ya da milletvekili olan genel başkan) kanunlarda "grup kararı" alır: kabul / ret / serbest.
--   • TBMM Başkanı ve oturumu yöneten başkanvekili Genel Kurul'da düzeni sağlar: kürsüden ihtar (1 saat söz yasağı).
-- =====================================================================

alter table oyun.makamlar drop constraint if exists makamlar_tur_check;
alter table oyun.makamlar add constraint makamlar_tur_check check (tur in ('mv','bel','cb','bakan','tbmm','bskv','grup_bskv'));

create table if not exists oyun.meclis_secim(
  id         bigserial primary key,
  mv_secim_id bigint,
  tur        text not null check (tur in ('baskan','grup')),
  parti_id   bigint references oyun.partiler(id) on delete cascade,
  olusturma  timestamptz not null,
  aday_bit   timestamptz not null,
  oy_bit     timestamptz,                 -- grup seçiminin bitişi
  tur_no     int not null default 0,      -- başkan seçiminde içinde bulunulan tur
  tur_bit    timestamptz,
  uzatma     int not null default 0,
  durum      text not null default 'aday' check (durum in ('aday','oylama','bitti')),
  bskv_hakki boolean not null default false,
  grup_bskv_sayi int not null default 2,
  sonuc      text,
  turlar     jsonb not null default '[]'  -- açıklanan tur sonuçları (oy sayıları; kimin kime verdiği gizli)
);
create index if not exists meclis_secim_durum on oyun.meclis_secim(durum);
create table if not exists oyun.meclis_aday(
  secim_id bigint not null references oyun.meclis_secim(id) on delete cascade,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  gorev    text not null check (gorev in ('baskan','bskv','grup_bskv')),
  zaman    timestamptz not null,
  elendi   boolean not null default false,
  primary key (secim_id, user_id, gorev)
);
create table if not exists oyun.meclis_oy(
  secim_id bigint not null references oyun.meclis_secim(id) on delete cascade,
  tur_no   int not null,
  gorev    text not null,
  secmen   uuid not null,
  aday     uuid not null,
  zaman    timestamptz not null,
  primary key (secim_id, tur_no, gorev, secmen)
);
create table if not exists oyun.grup_kararlari(
  kanun_id bigint not null references oyun.kanunlar(id) on delete cascade,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  karar    text not null check (karar in ('kabul','ret','serbest')),
  user_id  uuid,
  zaman    timestamptz not null,
  primary key (kanun_id, parti_id)
);
create table if not exists oyun.meclis_ihtar(
  id      bigserial primary key,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  veren   uuid,
  neden   text,
  bas     timestamptz not null,
  bit     timestamptz not null
);

-- ---------------------------------------------------------------------
-- ROLLER (tek görev kuralına eklenenler)
-- ---------------------------------------------------------------------
create or replace function oyun.rol_uyumlu(a text, b text) returns boolean language sql immutable as $$
  select (a = b and a in ('gb','gby')) or (a, b) in (('mv','gby'),('gby','mv'),('gb','cb'),('cb','gb'),
         ('mv','tbmm'),('tbmm','mv'),('mv','bskv'),('bskv','mv'),('mv','grup_bskv'),('grup_bskv','mv'),('gby','grup_bskv'),('grup_bskv','gby'))
$$;
create or replace function oyun.rol_ad(r text) returns text language sql immutable as $$
  select case r when 'mv' then 'milletvekilliği' when 'bel' then 'belediye başkanlığı' when 'cb' then 'cumhurbaşkanlığı'
                when 'bakan' then 'bakanlık' when 'gb' then 'genel başkanlık' when 'gby' then 'genel başkan yardımcılığı'
                when 'tbmm' then 'TBMM Başkanlığı' when 'bskv' then 'TBMM Başkanvekilliği' when 'grup_bskv' then 'grup başkanvekilliği' else r end
$$;
create or replace function oyun.makam_ad(p_tur text, p_il smallint, p_bakanlik text) returns text language sql stable as $$
  select case p_tur when 'mv' then (select ad from oyun.iller where id = p_il) || ' milletvekilliği'
                    when 'bel' then (select ad from oyun.iller where id = p_il) || ' belediye başkanlığı'
                    when 'cb' then 'cumhurbaşkanlığı'
                    when 'tbmm' then 'TBMM Başkanlığı' when 'bskv' then 'TBMM Başkanvekilliği' when 'grup_bskv' then 'grup başkanvekilliği'
                    else coalesce((select ad from oyun.bakanliklar where kod = p_bakanlik), 'bakanlık') end
$$;
create or replace function oyun.unvan(u uuid) returns text language sql stable as $$
  select coalesce(
    (select 'Cumhurbaşkanı' from oyun.makamlar where user_id = u and tur = 'cb' and bit is null limit 1),
    (select 'TBMM Başkanı' from oyun.makamlar where user_id = u and tur = 'tbmm' and bit is null limit 1),
    (select replace(b.ad, 'Bakanlığı', 'Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik
       where m.user_id = u and m.tur = 'bakan' and m.bit is null limit 1),
    (select 'TBMM Başkanvekili' from oyun.makamlar where user_id = u and tur = 'bskv' and bit is null limit 1),
    (select pa.kisa || ' Genel Başkanı' from oyun.partiler pa where pa.gb = u and not pa.kapali limit 1),
    (select pa.kisa || ' Grup Başkanvekili' from oyun.makamlar m join oyun.partiler pa on pa.id = m.parti_id where m.user_id = u and m.tur = 'grup_bskv' and m.bit is null limit 1),
    (select i.ad || ' Milletvekili' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'mv' and m.bit is null limit 1),
    (select i.ad || ' Belediye Başkanı' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'bel' and m.bit is null limit 1),
    (select pa.kisa || ' Genel Başkan Yardımcısı' from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id where g.user_id = u limit 1))
$$;

create or replace function oyun.grup_esigi(p_dolu int) returns int language sql immutable as $$
  select greatest(2, ceil(p_dolu * 20 / 600.0))::int
$$;
-- Vekilin bugünkü partisi (partisinden istifa eden vekil bağımsız kalır, grubundan çıkar)
create or replace function oyun.aktif_mv_parti(u uuid) returns bigint language sql stable as $$
  select p.parti_id from oyun.profiller p where p.id = u and exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv' and m.bit is null)
$$;
create or replace function oyun.tbmm_baskani() returns uuid language sql stable as $$
  select user_id from oyun.makamlar where tur = 'tbmm' and bit is null limit 1
$$;
-- Geçici Başkan: TBMM Başkanı seçilene kadar en kıdemli milletvekili
create or replace function oyun.gecici_baskan() returns uuid language sql stable as $$
  select m.user_id from oyun.makamlar m where m.tur = 'mv' and m.bit is null order by oyun.kidem_puani(m.user_id) desc, m.bas, m.id limit 1
$$;
-- Parti grupları: grup eşiğini geçen partiler, sandalye sayısına göre
create or replace function oyun.gruplar() returns table(parti_id bigint, vekil int, sira int) language sql stable as $$
  with g as (select p.parti_id, count(*)::int vekil from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
             where m.tur = 'mv' and m.bit is null and p.parti_id is not null group by p.parti_id)
  select g.parti_id, g.vekil, (row_number() over (order by g.vekil desc, g.parti_id))::int from g
  where g.vekil >= oyun.grup_esigi((select count(*)::int from oyun.makamlar where tur = 'mv' and bit is null))
$$;

-- ---------------------------------------------------------------------
-- YASAMA DÖNEMİ BAŞLANGICI
-- ---------------------------------------------------------------------
create or replace function oyun.meclis_donem_baslat(p_mv bigint, t timestamptz) returns void language plpgsql as $$
declare m record; g record; dolu int := oyun.dolu_sandalye(); gb uuid;
begin
  for m in select id from oyun.makamlar where tur in ('tbmm','bskv','grup_bskv') and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'donem_bitti');
  end loop;
  update oyun.meclis_secim set durum = 'bitti', sonuc = coalesce(sonuc, 'Yasama dönemi sona erdi.') where durum <> 'bitti';
  insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (p_mv, 'baskan', t, t + interval '24 hours');
  for g in select * from oyun.gruplar() loop
    insert into oyun.meclis_secim(mv_secim_id, tur, parti_id, olusturma, aday_bit, oy_bit, bskv_hakki, grup_bskv_sayi)
    values (p_mv, 'grup', g.parti_id, t, t + interval '24 hours', t + interval '36 hours', g.sira <= 3, case when g.vekil * 6 > dolu then 3 else 2 end);
  end loop;
  gb := oyun.gecici_baskan();
  perform oyun.olay('meclis', format('Yeni yasama dönemi başladı. Geçici Başkan %s. TBMM Başkanlığı ve grup başkanvekilliği adaylıkları 24 saat açık.', coalesce(oyun.kad(gb), '—')), null, null, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.user_id, t, 'Yeni yasama dönemi: TBMM Başkanlığına ve partinin grup görevlerine 24 saat içinde aday olabilirsin (Devlet › Meclis).'
    from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
end $$;

-- Göreve atama (tek görev kuralı: uyumsuz görevler düşer)
create or replace function oyun.meclis_gorev_ata(u uuid, p_tur text, t timestamptz) returns void language plpgsql as $$
declare pid bigint := oyun.aktif_mv_parti(u); pk text;
begin
  if p_tur = 'tbmm' then
    -- Meclis Başkanı partisinin faaliyetlerine katılamaz
    delete from oyun.parti_gby where user_id = u;
    if exists (select 1 from oyun.partiler where gb = u) then
      update oyun.partiler set gb = null where gb = u;
      perform oyun.bildir(u, 'TBMM Başkanı seçildiğin için genel başkanlıktan ayrıldın (Anayasa md. 94: Meclis Başkanı partisinin faaliyetlerine katılamaz).', t);
    end if;
  end if;
  if p_tur = 'bskv' then delete from oyun.parti_gby where user_id = u; end if;
  insert into oyun.makamlar(tur, user_id, parti_id, kaynak, bas) values (p_tur, u, pid, 'secim', t);
  select kisa into pk from oyun.partiler where id = pid;
  perform oyun.bildir(u, format('Tebrikler! %s görevine seçildin.', case p_tur when 'tbmm' then 'TBMM Başkanlığı' when 'bskv' then 'TBMM Başkanvekilliği' else pk || ' Grup Başkanvekilliği' end), t);
end $$;

-- ---------------------------------------------------------------------
-- SAYIM
-- ---------------------------------------------------------------------
create or replace function oyun.meclis_sayim(p_secim bigint, p_tur int, p_gorev text)
returns table(user_id uuid, oy int, kidem numeric) language sql stable as $$
  select a.user_id, (select count(*)::int from oyun.meclis_oy o where o.secim_id = p_secim and o.tur_no = p_tur and o.gorev = p_gorev and o.aday = a.user_id),
         oyun.kidem_puani(a.user_id)
  from oyun.meclis_aday a where a.secim_id = p_secim and a.gorev = p_gorev and not a.elendi
  order by 2 desc, 3 desc
$$;

create or replace function oyun.meclis_tick(t timestamptz) returns void language plpgsql as $$
declare s oyun.meclis_secim; ms oyun.secimler; r record; dolu int; gerek int; ust record; ikinci uuid; n int; dongu int; m record; pk text;
begin
  -- yeni yasama dönemi
  for ms in select * from oyun.secimler x where x.tur = 'mv' and x.durum = 'tamam' and x.goreve_bas <= t and x.goreve_bas > t - interval '20 days'
              and not exists (select 1 from oyun.meclis_secim y where y.mv_secim_id = x.id) order by x.goreve_bas loop
    perform oyun.meclis_donem_baslat(ms.id, ms.goreve_bas);
  end loop;
  -- görev şartı kalmayanlar (vekilliği düşen, partisi değişen)
  for m in select x.* from oyun.makamlar x where x.tur in ('tbmm','bskv','grup_bskv') and x.bit is null
             and (not oyun.aktif_vekil(x.user_id) or (x.tur in ('bskv','grup_bskv') and oyun.aktif_mv_parti(x.user_id) is distinct from x.parti_id)) loop
    perform oyun.makam_bitir(m.id, t, 'gorev_dustu');
    if m.tur = 'tbmm' and not exists (select 1 from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti') then
      insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (null, 'baskan', t, t + interval '24 hours');
      perform oyun.olay('meclis', 'TBMM Başkanlığı boşaldı. Ara seçim için adaylık 24 saat açık.', null, null, t);
    end if;
  end loop;
  -- TBMM Başkanı seçimi
  for s in select * from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      if not exists (select 1 from oyun.meclis_aday where secim_id = s.id) then
        if s.uzatma < 2 then
          update oyun.meclis_secim set aday_bit = aday_bit + interval '24 hours', uzatma = uzatma + 1 where id = s.id;
          perform oyun.olay('meclis', 'TBMM Başkanlığı için aday çıkmadı; adaylık süresi 24 saat uzatıldı.', null, null, t);
        else
          update oyun.meclis_secim set durum = 'bitti', sonuc = 'Aday çıkmadı; Geçici Başkan oturumları yönetmeye devam ediyor.' where id = s.id;
        end if;
        continue;
      end if;
      update oyun.meclis_secim set durum = 'oylama', tur_no = 1, tur_bit = aday_bit + interval '12 hours' where id = s.id;
      insert into oyun.bildirimler(user_id, zaman, metin)
        select x.user_id, s.aday_bit, 'TBMM Başkanlığı seçiminin 1. turu başladı. Oy pusulan Devlet › Meclis ekranında; oylama gizli.'
        from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
      select * into s from oyun.meclis_secim where id = s.id;
    end if;
    dongu := 0;
    while s.durum = 'oylama' and t >= s.tur_bit and dongu < 5 loop
      dongu := dongu + 1;
      dolu := oyun.dolu_sandalye();
      gerek := case when s.tur_no <= 2 then ceil(dolu * 2 / 3.0) when s.tur_no = 3 then floor(dolu / 2.0) + 1 else 0 end;
      select * into ust from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) limit 1;
      update oyun.meclis_secim set turlar = turlar || jsonb_build_array(jsonb_build_object('tur', s.tur_no, 'gerek', gerek, 'katilim',
          (select count(*) from oyun.meclis_oy where secim_id = s.id and tur_no = s.tur_no and gorev = 'baskan'),
          'sonuc', (select jsonb_agg(jsonb_build_object('kad', oyun.kad(x.user_id), 'oy', x.oy)) from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x)))
        where id = s.id;
      if ust.user_id is not null and (s.tur_no = 4 or ust.oy >= gerek) then
        perform oyun.meclis_gorev_ata(ust.user_id, 'tbmm', s.tur_bit);
        update oyun.meclis_secim set durum = 'bitti', sonuc = format('%s %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy) where id = s.id;
        perform oyun.olay('meclis', format('%s, %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy), null, oyun.aktif_mv_parti(ust.user_id), s.tur_bit);
        perform oyun.gazete_ekle('atama', format('TBMM Başkanlığına %s seçilmiştir', oyun.kad(ust.user_id)), format('Genel Kurul''un gizli oylamasında %s. turda %s oy.', s.tur_no, ust.oy), null, s.tur_bit);
      elsif ust.user_id is null then
        update oyun.meclis_secim set durum = 'bitti', sonuc = 'Adaylar milletvekilliği sıfatını kaybettiği için seçim sonuçsuz kaldı.' where id = s.id;
      else
        if s.tur_no = 3 then
          -- 4. tur: en çok oy alan iki aday
          update oyun.meclis_aday set elendi = true where secim_id = s.id and gorev = 'baskan'
            and user_id not in (select x.user_id from oyun.meclis_sayim(s.id, 3, 'baskan') x where oyun.aktif_vekil(x.user_id) limit 2);
        end if;
        update oyun.meclis_secim set tur_no = tur_no + 1, tur_bit = tur_bit + interval '12 hours' where id = s.id;
        perform oyun.olay('meclis', format('TBMM Başkanlığı seçiminin %s. turunda gerekli %s oya ulaşılamadı; %s. tura geçildi.', s.tur_no, gerek, s.tur_no + 1), null, null, s.tur_bit);
      end if;
      select * into s from oyun.meclis_secim where id = s.id;
    end loop;
  end loop;
  -- Parti grup seçimleri
  for s in select * from oyun.meclis_secim where tur = 'grup' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      update oyun.meclis_secim set durum = 'oylama' where id = s.id;
      s.durum := 'oylama';
    end if;
    if s.durum = 'oylama' and t >= s.oy_bit then
      select kisa into pk from oyun.partiler where id = s.parti_id;
      if s.bskv_hakki then
        select * into ust from oyun.meclis_sayim(s.id, 0, 'bskv') x
          where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'bskv') is null limit 1;
        if ust.user_id is not null then
          perform oyun.meclis_gorev_ata(ust.user_id, 'bskv', s.oy_bit);
          perform oyun.olay('meclis', format('%s grubu %s''i TBMM Başkanvekili olarak seçti.', pk, oyun.kad(ust.user_id)), null, s.parti_id, s.oy_bit);
        end if;
      end if;
      n := (select count(*) from oyun.meclis_aday a where a.secim_id = s.id and a.gorev = 'grup_bskv');
      for r in select x.* from oyun.meclis_sayim(s.id, 0, 'grup_bskv') x
                where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'grup_bskv') is null
                  and (n <= s.grup_bskv_sayi or x.oy > 0)
                limit s.grup_bskv_sayi loop
        perform oyun.meclis_gorev_ata(r.user_id, 'grup_bskv', s.oy_bit);
      end loop;
      update oyun.meclis_secim set durum = 'bitti', sonuc = 'Grup seçimi tamamlandı.' where id = s.id;
      perform oyun.olay('meclis', format('%s Meclis grubu başkanvekillerini seçti.', pk), null, s.parti_id, s.oy_bit);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- OYUNCU FONKSİYONLARI
-- ---------------------------------------------------------------------
create or replace function public.meclis_aday_ol(p_secim bigint, p_gorev text, p_aday boolean default true) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_secim;
begin
  select * into s from oyun.meclis_secim where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  if s.durum <> 'aday' or t >= s.aday_bit then raise exception 'Adaylık süresi bitti.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri aday olabilir.'; end if;
  if s.tur = 'baskan' and p_gorev <> 'baskan' then raise exception 'Geçersiz görev.'; end if;
  if s.tur = 'grup' then
    if oyun.aktif_mv_parti(p.id) is distinct from s.parti_id then raise exception 'Yalnızca bu partinin milletvekilleri aday olabilir.'; end if;
    if p_gorev not in ('bskv','grup_bskv') or (p_gorev = 'bskv' and not s.bskv_hakki) then raise exception 'Geçersiz görev.'; end if;
  end if;
  if p_aday then
    insert into oyun.meclis_aday(secim_id, user_id, gorev, zaman) values (s.id, p.id, p_gorev, t) on conflict do nothing;
    if not found then raise exception 'Zaten adaysın.'; end if;
    if p_gorev = 'baskan' then
      perform oyun.olay('meclis', format('%s TBMM Başkanlığına aday oldu.', p.kad), null, p.parti_id, t);
    end if;
  else
    delete from oyun.meclis_aday where secim_id = s.id and user_id = p.id and gorev = p_gorev;
    if not found then raise exception 'Bu göreve aday değilsin.'; end if;
  end if;
  return public.meclis_baskanlik();
end $$;

create or replace function public.meclis_oy(p_secim bigint, p_gorev text, p_aday text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_secim; a uuid; tn int;
begin
  select * into s from oyun.meclis_secim where id = p_secim;
  if s.id is null or s.durum <> 'oylama' then raise exception 'Bu seçimde şu an oylama yok.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri oy kullanabilir.'; end if;
  if s.tur = 'baskan' then
    if t >= s.tur_bit then raise exception 'Bu tur sona erdi.'; end if;
    tn := s.tur_no;
  else
    if t >= s.oy_bit then raise exception 'Oylama sona erdi.'; end if;
    if oyun.aktif_mv_parti(p.id) is distinct from s.parti_id then raise exception 'Grup seçiminde yalnızca partinin milletvekilleri oy kullanır.'; end if;
    tn := 0;
  end if;
  select ad.user_id into a from oyun.meclis_aday ad join oyun.profiller pr on pr.id = ad.user_id
   where ad.secim_id = s.id and ad.gorev = p_gorev and not ad.elendi and lower(pr.kad) = lower(btrim(p_aday));
  if a is null then raise exception 'Aday bulunamadı.'; end if;
  insert into oyun.meclis_oy(secim_id, tur_no, gorev, secmen, aday, zaman) values (s.id, tn, p_gorev, p.id, a, t) on conflict do nothing;
  if not found then raise exception 'Bu oylamada oyunu zaten kullandın.'; end if;
  return public.meclis_baskanlik();
end $$;

create or replace function oyun.meclis_secim_json(s oyun.meclis_secim, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', s.id, 'tur', s.tur, 'parti', oyun.parti_json(s.parti_id), 'durum', s.durum, 'aday_bit', s.aday_bit,
    'oy_bit', coalesce(s.oy_bit, s.tur_bit), 'tur_no', s.tur_no, 'tur_bit', s.tur_bit, 'bskv_hakki', s.bskv_hakki, 'grup_bskv_sayi', s.grup_bskv_sayi,
    'sonuc', s.sonuc, 'turlar', s.turlar,
    'gerek', case when s.tur = 'baskan' and s.durum = 'oylama' then
               case when s.tur_no <= 2 then ceil(oyun.dolu_sandalye() * 2 / 3.0) when s.tur_no = 3 then floor(oyun.dolu_sandalye() / 2.0) + 1 else 0 end end,
    'adaylar', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'gorev', a.gorev, 'elendi', a.elendi, 'parti', oyun.parti_json(pr.parti_id),
                   'il', (select i.ad from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = pr.id and m.tur = 'mv' and m.bit is null limit 1),
                   'benim', pr.id = p.id) order by a.gorev, a.zaman)
                 from oyun.meclis_aday a join oyun.profiller pr on pr.id = a.user_id where a.secim_id = s.id), '[]'::jsonb),
    'oylarim', coalesce((select jsonb_agg(o.gorev) from oyun.meclis_oy o where o.secim_id = s.id and o.secmen = p.id
                          and o.tur_no = case when s.tur = 'baskan' then s.tur_no else 0 end), '[]'::jsonb),
    'katilabilir', oyun.aktif_vekil(p.id) and (s.tur = 'baskan' or oyun.aktif_mv_parti(p.id) = s.parti_id))
$$;

-- Meclis Başkanlık Divanı ve parti grupları ekranı
create or replace function public.meclis_baskanlik() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); dolu int := oyun.dolu_sandalye();
begin
  return jsonb_build_object(
    'baskan', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas) from oyun.makamlar m where m.tur = 'tbmm' and m.bit is null limit 1),
    'gecici', case when oyun.tbmm_baskani() is null then oyun.kad(oyun.gecici_baskan()) end,
    'baskanvekilleri', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id)) order by m.bas)
                                 from oyun.makamlar m where m.tur = 'bskv' and m.bit is null), '[]'::jsonb),
    'grup_esigi', oyun.grup_esigi(dolu), 'dolu', dolu,
    'gruplar', coalesce((select jsonb_agg(jsonb_build_object('parti', oyun.parti_json(g.parti_id), 'vekil', g.vekil, 'sira', g.sira,
                   'baskan', case when exists (select 1 from oyun.partiler pa where pa.id = g.parti_id and oyun.aktif_vekil(pa.gb)) then (select oyun.kad(gb) from oyun.partiler where id = g.parti_id) end,
                   'bskv', coalesce((select jsonb_agg(oyun.kad(m.user_id) order by m.bas) from oyun.makamlar m where m.tur = 'grup_bskv' and m.bit is null and m.parti_id = g.parti_id), '[]'::jsonb))
                 order by g.sira) from oyun.gruplar() g), '[]'::jsonb),
    'secimler', coalesce((select jsonb_agg(oyun.meclis_secim_json(s, p, t) order by (s.tur = 'baskan') desc, s.id)
                          from oyun.meclis_secim s where s.durum <> 'bitti' or s.id in (select max(id) from oyun.meclis_secim where tur = 'baskan')), '[]'::jsonb),
    'yetkim', jsonb_build_object(
       'ihtar', exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv')) or (oyun.tbmm_baskani() is null and oyun.gecici_baskan() = p.id),
       'grup_karari', oyun.grup_karar_yetkisi(p.id) is not null, 'vekil', oyun.aktif_vekil(p.id)));
end $$;

-- ---------------------------------------------------------------------
-- GRUP KARARI
-- ---------------------------------------------------------------------
create or replace function oyun.grup_karar_yetkisi(u uuid) returns bigint language sql stable as $$
  select pid from (
    select m.parti_id pid from oyun.makamlar m where m.user_id = u and m.tur = 'grup_bskv' and m.bit is null
    union all select pa.id from oyun.partiler pa where pa.gb = u and oyun.aktif_vekil(u) and oyun.aktif_mv_parti(u) = pa.id) x
  where pid in (select g.parti_id from oyun.gruplar() g) limit 1
$$;

create or replace function public.grup_karar(p_kanun bigint, p_karar text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pid bigint := oyun.grup_karar_yetkisi(p.id); k oyun.kanunlar; pk text;
begin
  if pid is null then raise exception 'Grup kararını grup başkanvekilleri ya da milletvekili olan genel başkan alır (partinin Meclis''te grubu olmalı).'; end if;
  if p_karar not in ('kabul','ret','serbest') then raise exception 'Geçersiz karar.'; end if;
  select * into k from oyun.kanunlar where id = p_kanun;
  if k.id is null or k.durum not in ('gorusmede','oylamada','israr') then raise exception 'Bu teklif için grup kararı alınamaz.'; end if;
  insert into oyun.grup_kararlari(kanun_id, parti_id, karar, user_id, zaman) values (k.id, pid, p_karar, p.id, t)
  on conflict (kanun_id, parti_id) do update set karar = excluded.karar, user_id = excluded.user_id, zaman = excluded.zaman;
  select kisa into pk from oyun.partiler where id = pid;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select m.user_id, t, format('%s grup kararı: "%s" için %s.', pk, k.baslik, case p_karar when 'kabul' then 'KABUL oyu' when 'ret' then 'RET oyu' else 'oy serbest' end)
    from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pid and m.user_id <> p.id;
  perform oyun.olay('meclis', format('%s grubu "%s" için %s kararı aldı.', pk, k.baslik, case p_karar when 'kabul' then 'kabul' when 'ret' then 'ret' else 'serbest oy' end), null, pid, t);
  return public.kanun_detay(p_kanun);
end $$;

create or replace function oyun.grup_karar_json(p_kanun bigint, p oyun.profiller) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'liste', coalesce((select jsonb_agg(jsonb_build_object('parti', oyun.parti_json(g.parti_id), 'karar', g.karar, 'kad', oyun.kad(g.user_id))) from oyun.grup_kararlari g where g.kanun_id = p_kanun), '[]'::jsonb),
    'benim_grubum', (select karar from oyun.grup_kararlari where kanun_id = p_kanun and parti_id = oyun.aktif_mv_parti(p.id)),
    'yetkim', oyun.grup_karar_yetkisi(p.id) is not null)
$$;

-- ---------------------------------------------------------------------
-- GENEL KURUL DÜZENİ: İHTAR (1 saat söz yasağı)
-- ---------------------------------------------------------------------
create or replace function oyun.ihtarli(u uuid, t timestamptz) returns timestamptz language sql stable as $$
  select max(bit) from oyun.meclis_ihtar where user_id = u and bit > t
$$;

create or replace function public.meclis_ihtar(p_kad text, p_neden text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller := oyun.profil_bul(p_kad); n text;
begin
  if not (exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv'))
          or (oyun.tbmm_baskani() is null and oyun.gecici_baskan() = p.id)) then
    raise exception 'Genel Kurul''da ihtar yetkisi TBMM Başkanı ve başkanvekillerindedir.';
  end if;
  if h.id = p.id then raise exception 'Kendine ihtar veremezsin.'; end if;
  if not oyun.meclis_yazabilir(h.id) then raise exception 'Bu kişinin Genel Kurul''da söz hakkı yok.'; end if;
  n := oyun.metin_temizle(coalesce(p_neden, ''), 200);
  if length(n) < 3 then raise exception 'İhtarın gerekçesini yaz.'; end if;
  insert into oyun.meclis_ihtar(user_id, veren, neden, bas, bit) values (h.id, p.id, n, t, t + interval '1 hour');
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values ('meclis', p.id, format('[İhtar] Sayın %s, %s. Bir saat süreyle söz verilmeyecektir.', h.kad, n), t);
  perform oyun.bildir(h.id, format('%s sana Genel Kurul''da ihtar verdi: %s. Bir saat Genel Kurul''da söz alamazsın.', p.kad, n), t);
  return jsonb_build_object('tamam', true);
end $$;

-- Görevden ayrılma
create or replace function public.meclis_gorev_birak(p_tur text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = p_tur and bit is null and tur in ('tbmm','bskv','grup_bskv');
  if m.id is null then raise exception 'Bu görevde değilsin.'; end if;
  perform oyun.makam_bitir(m.id, t, 'istifa');
  perform oyun.olay('meclis', format('%s, %s görevinden ayrıldı.', p.kad, oyun.rol_ad(p_tur)), null, p.parti_id, t);
  if p_tur = 'tbmm' then
    insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (null, 'baskan', t, t + interval '24 hours');
  end if;
  return public.meclis_baskanlik();
end $$;
-- =====================================================================
--  14 · ÇOKLU HESAPLA MÜCADELE, VATANDAŞLIK (OY) ŞARTLARI, PARTİ KURULUŞU
--
--  İlke: "bir insan = bir vatandaş". Aynı kişinin birden çok hesapla oy kullanması, aday olması,
--  parti kurması seçimleri çarpıtır. Kullanılan sinyaller (sektördeki yaygın yöntemler):
--    • cihaz kimliği (uygulamanın cihazda ürettiği kalıcı kimlik) ve tarayıcı/cihaz izi (parmak izi)
--    • bağlantı adresi (IP) — tek başına delil sayılmaz (aile, okul, mobil operatör paylaşımı), yöneticiye gösterilir
--    • tek kullanımlık e-posta servisleri engellenir; e-posta doğrulaması aranır
--  Ham değerler saklanmaz: hepsi gizli bir tuzla SHA-256 özetine çevrilir (KVKK: veri en aza indirme).
--
--  Kural: aynı cihazda/izde daha önce açılmış başka bir hesap varsa yeni hesap "inceleme bekliyor" olur;
--  oy kullanamaz, aday olamaz, parti kuramaz ve kurucu olamaz. Aile içi gerçek paylaşımda yönetici onaylar.
--  Ayrıca aynı cihazdan aynı seçimde yalnızca bir oy kullanılabilir.
--
--  Vatandaşlık (oy ve adaylık) şartları — ayarlardan değiştirilebilir:
--    hesap yaşı (min_hesap_gun) · doğrulanmış e-posta · en az "Vatandaş" statüsü (oy_min_kidem)
--    cihaz doğrulaması · şüpheli hesap olmamak · yerel ve genel seçimde ilde en az oy_il_gun gündür kayıtlı olmak
--  Parti kurma: kurucunun kıdemi en az parti_kurucu_kidem; parti_kurulus_gun içinde parti_kurucu_sayi kurucu üye
--  (şartları taşıyan üye) toplanmazsa kuruluş düşer. (Gerçekte Siyasi Partiler Kanunu en az 30 kurucu arar.)
-- =====================================================================

alter table oyun.ayarlar add column if not exists oy_min_kidem       int     not null default 10;
alter table oyun.ayarlar add column if not exists oy_il_gun          int     not null default 7;
alter table oyun.ayarlar add column if not exists eposta_zorunlu     boolean not null default true;
alter table oyun.ayarlar add column if not exists cihaz_zorunlu      boolean not null default true;
alter table oyun.ayarlar add column if not exists cihaz_max_hesap    int     not null default 2;
alter table oyun.ayarlar add column if not exists parti_kurucu_sayi  int     not null default 5;
alter table oyun.ayarlar add column if not exists parti_kurucu_kidem int     not null default 30;
alter table oyun.ayarlar add column if not exists parti_kurulus_gun  int     not null default 7;
alter table oyun.ayarlar add column if not exists coklu_kontrol      boolean not null default true;
alter table oyun.ayarlar add column if not exists iz_tuz             text    not null default md5(random()::text || clock_timestamp()::text);

create table if not exists oyun.oturumlar(
  id      bigserial primary key,
  user_id uuid not null,                 -- auth.users kimliği (profil açılmadan önce de kaydedilir)
  cihaz   text,                          -- tuzlanmış özet
  iz      text,
  ip      text,
  ilk     timestamptz not null,
  son     timestamptz not null,
  sayi    int not null default 1,
  unique (user_id, cihaz, iz, ip)
);
create index if not exists oturum_cihaz on oyun.oturumlar(cihaz);
create index if not exists oturum_iz on oyun.oturumlar(iz);
create index if not exists oturum_ip on oyun.oturumlar(ip, son);

-- Yöneticinin "gerçek kişi, paylaşım meşru" diye onayladığı hesaplar
create table if not exists oyun.hesap_onay(
  user_id  uuid primary key references oyun.profiller(id) on delete cascade,
  yonetici uuid,
  not_     text,
  zaman    timestamptz not null
);
-- Aynı cihazdan aynı seçimde tek oy (oy içeriği değil yalnızca "bu cihaz bu sandıkta oy kullandı" bilgisi)
create table if not exists oyun.oy_cihaz(
  anahtar text not null,                 -- 's<secim_id>' / 'r<referandum_id>'
  cihaz   text not null,
  primary key (anahtar, cihaz)
);
create table if not exists oyun.gecici_eposta(alan text primary key);
insert into oyun.gecici_eposta(alan) values
 ('mailinator.com'),('10minutemail.com'),('guerrillamail.com'),('guerrillamail.net'),('sharklasers.com'),('temp-mail.org'),
 ('tempmail.com'),('tempmail.net'),('yopmail.com'),('yopmail.net'),('trashmail.com'),('getnada.com'),('nada.email'),
 ('dispostable.com'),('maildrop.cc'),('throwawaymail.com'),('fakeinbox.com'),('mintemail.com'),('mohmal.com'),
 ('emailondeck.com'),('tempail.com'),('tempr.email'),('discard.email'),('spamgourmet.com'),('mailnesia.com'),
 ('burnermail.io'),('mytemp.email'),('tmpmail.org'),('tmail.ws'),('moakt.com'),('emailfake.com'),('inboxkitten.com'),
 ('mail.tm'),('1secmail.com'),('dropmail.me'),('tempmailo.com'),('minuteinbox.com'),('linshiyouxiang.net')
on conflict do nothing;

create or replace function oyun.ozet(x text) returns text language sql stable as $$
  select case when nullif(btrim(x), '') is null then null
              else encode(sha256(convert_to((select iz_tuz from oyun.ayarlar where id = 1) || '|' || btrim(x), 'UTF8')), 'hex') end
$$;

create or replace function oyun.istek_ip() returns text language plpgsql stable as $$
declare h json;
begin
  begin h := nullif(current_setting('request.headers', true), '')::json; exception when others then return null; end;
  return nullif(btrim(split_part(coalesce(h ->> 'cf-connecting-ip', h ->> 'x-real-ip', h ->> 'x-forwarded-for', ''), ',', 1)), '');
end $$;

-- Uygulama her açılışta ve girişte çağırır (profil açılmadan önce de)
create or replace function public.oturum_kaydet(p_cihaz text, p_iz text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben(); t timestamptz := oyun.simdi(); c text := oyun.ozet(left(p_cihaz, 200)); z text := oyun.ozet(left(p_iz, 200)); i text := oyun.ozet(oyun.istek_ip());
begin
  if c is null and z is null then raise exception 'Cihaz bilgisi alınamadı.'; end if;
  insert into oyun.oturumlar(user_id, cihaz, iz, ip, ilk, son) values (u, c, z, i, t, t)
  on conflict (user_id, cihaz, iz, ip) do update set son = excluded.son, sayi = oyun.oturumlar.sayi + 1;
  return jsonb_build_object('tamam', true);
end $$;

-- Bu kullanıcının son kullandığı cihaz özeti
create or replace function oyun.son_cihaz(u uuid) returns text language sql stable as $$
  select cihaz from oyun.oturumlar where user_id = u and cihaz is not null order by son desc limit 1
$$;

-- Aynı cihaz kimliğini paylaşan diğer profiller. (Cihaz izi aynı model telefonlarda çakışabildiği için
-- engel sebebi sayılmaz; yalnızca yönetici panelinde "benzer cihaz" olarak gösterilir.)
create or replace function oyun.bagli_hesaplar(u uuid) returns setof uuid language sql stable as $$
  select distinct o2.user_id from oyun.oturumlar o1
  join oyun.oturumlar o2 on o2.user_id <> o1.user_id and o1.cihaz is not null and o2.cihaz = o1.cihaz
  join oyun.profiller p on p.id = o2.user_id
  where o1.user_id = u
$$;

-- Şüphe: aynı cihazda/izde senden önce açılmış bir hesap varsa (yönetici onaylamadıysa)
create or replace function oyun.suphe(u uuid) returns text language sql stable as $$
  select case when not (select coklu_kontrol from oyun.ayarlar where id = 1) then null
              when exists (select 1 from oyun.hesap_onay where user_id = u) then null
              when exists (select 1 from oyun.bagli_hesaplar(u) b join oyun.profiller x on x.id = b
                           where x.olusturma < (select olusturma from oyun.profiller where id = u))
                then 'Bu cihazda daha önce açılmış başka bir hesap var. Bir insan yalnızca bir vatandaş olabilir; hesabın yönetici incelemesinden geçene kadar oy kullanamaz, aday olamaz ve parti kuramaz. Aynı cihazı aile içinde paylaşıyorsanız yöneticiye bildirin.' end
$$;

-- VATANDAŞLIK ŞARTLARI: oy, adaylık, parti kurma ve kurucu üyelik için ortak kontrol (03'teki uyari'nin yerine geçer)
create or replace function oyun.uyari(p oyun.profiller, ref timestamptz) returns text language sql stable as $$
  select coalesce(
    case when p.olusturma > ref - make_interval(days => a.min_hesap_gun)
         then format('Hesabın en az %s günlük olmalı.', a.min_hesap_gun) end,
    case when a.eposta_zorunlu and not exists (select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
         then 'E-posta adresini doğrulamalısın.' end,
    case when a.cihaz_zorunlu and not exists (select 1 from oyun.oturumlar o where o.user_id = p.id)
         then 'Cihaz doğrulaması gerekiyor: uygulamayı güncelleyip yeniden aç.' end,
    oyun.suphe(p.id),
    case when oyun.kidem_puani(p.id) < a.oy_min_kidem
         then format('En az %s kıdem puanın olmalı ("Vatandaş" statüsü; şu an %s). Her gün maaşını toplayarak kıdem kazanırsın.', a.oy_min_kidem, oyun.kidem_puani(p.id)) end)
  from oyun.ayarlar a where a.id = 1
$$;

-- Oy engeli: vatandaşlık şartları + seçmen kütüğü (yerel ve genel seçimde ilde en az N gündür kayıtlı olmak)
create or replace function oyun.oy_engeli(p oyun.profiller, s oyun.secimler) returns text language sql stable as $$
  select coalesce(
    oyun.uyari(p, s.oy_bas),
    case when s.tur in ('mv','bel','mv_on','bel_on') and p.il_at > s.oy_bas - make_interval(days => (select oy_il_gun from oyun.ayarlar where id = 1))
         then format('Seçmen kütüğü: bu ilde oy kullanabilmek için seçimden en az %s gün önce bu ile kayıtlı olmalısın.', (select oy_il_gun from oyun.ayarlar where id = 1)) end,
    case when s.tur in ('mv_on','bel_on','kurultay','cb_on') then
      case when p.parti_id is null then 'Bu parti içi seçimde oy için bir partiye üye olmalısın.'
           when p.parti_at > s.basvuru_bas then 'Parti içi seçimde oy için başvurular açılmadan önce üye olmuş olmalısın.' end
    end)
$$;

-- Aynı cihazdan aynı sandıkta tek oy
create or replace function oyun.oy_cihaz_tg() returns trigger language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare c text; k text;
begin
  if not (select coklu_kontrol from oyun.ayarlar where id = 1) then return new; end if;
  if tg_table_name = 'oylar' then c := oyun.son_cihaz(new.secmen); k := 's' || new.secim_id;
  else c := oyun.son_cihaz(new.secmen); k := 'r' || new.ref_id; end if;
  if c is null then return new; end if;
  insert into oyun.oy_cihaz(anahtar, cihaz) values (k, c) on conflict do nothing;
  if not found then raise exception 'Bu cihazdan bu sandıkta başka bir hesapla oy kullanıldı. Bir cihazdan yalnızca bir oy kullanılabilir.'; end if;
  return new;
end $$;
drop trigger if exists oylar_cihaz on oyun.oylar;
create trigger oylar_cihaz before insert on oyun.oylar for each row execute function oyun.oy_cihaz_tg();
drop trigger if exists ref_cihaz on oyun.referandum_katilim;
create trigger ref_cihaz before insert on oyun.referandum_katilim for each row execute function oyun.oy_cihaz_tg();

-- Profil açarken: tek kullanımlık e-posta engeli ve cihaz başına hesap sınırı
create or replace function oyun.profil_guvenlik_tg() returns trigger language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare v_alan text; n int;
begin
  if not (select coklu_kontrol from oyun.ayarlar where id = 1) then return new; end if;
  v_alan := lower(split_part((select email from auth.users where id = new.id), '@', 2));
  if v_alan <> '' and exists (select 1 from oyun.gecici_eposta g where v_alan = g.alan or v_alan like '%.' || g.alan) then
    raise exception 'Tek kullanımlık e-posta adresleriyle hesap açılamaz. Kalıcı bir e-posta adresi kullan.';
  end if;
  select count(distinct b) into n from oyun.bagli_hesaplar(new.id) b;
  if n >= (select cihaz_max_hesap from oyun.ayarlar where id = 1) then
    raise exception 'Bu cihazda en fazla % oyuncu hesabı açılabilir. Bir insan yalnızca bir vatandaş olabilir.', (select cihaz_max_hesap from oyun.ayarlar where id = 1);
  end if;
  return new;
end $$;
drop trigger if exists profil_guvenlik on oyun.profiller;
create trigger profil_guvenlik before insert on oyun.profiller for each row execute function oyun.profil_guvenlik_tg();

-- ---------------------------------------------------------------------
-- VATANDAŞLIK DURUMU (oyuncunun kendi "seçmen kartı")
-- ---------------------------------------------------------------------
create or replace function public.vatandaslik() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.ayarlar; k numeric := oyun.kidem_puani(p.id);
begin
  select * into a from oyun.ayarlar where id = 1;
  return jsonb_build_object(
    'uygun', oyun.uyari(p, t) is null, 'engel', oyun.uyari(p, t),
    'sartlar', jsonb_build_array(
      jsonb_build_object('ad', format('Hesap en az %s günlük', a.min_hesap_gun), 'tamam', p.olusturma <= t - make_interval(days => a.min_hesap_gun),
                         'not', case when p.olusturma > t - make_interval(days => a.min_hesap_gun) then 'Tamamlanma: ' || to_char((p.olusturma + make_interval(days => a.min_hesap_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') end),
      jsonb_build_object('ad', 'E-posta doğrulanmış', 'tamam', not a.eposta_zorunlu or exists (select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)),
      jsonb_build_object('ad', 'Cihaz doğrulanmış', 'tamam', not a.cihaz_zorunlu or exists (select 1 from oyun.oturumlar o where o.user_id = p.id)),
      jsonb_build_object('ad', 'Tek hesap (bu cihazda önceden açılmış hesap yok ya da yönetici onaylı)', 'tamam', oyun.suphe(p.id) is null),
      jsonb_build_object('ad', format('"Vatandaş" statüsü (en az %s kıdem)', a.oy_min_kidem), 'tamam', k >= a.oy_min_kidem, 'not', format('Kıdemin: %s', k)),
      jsonb_build_object('ad', format('Seçmen kütüğü: yerel ve genel seçimde ilinde en az %s gün', a.oy_il_gun), 'tamam', p.il_at <= t - make_interval(days => a.oy_il_gun),
                         'not', case when p.il_at > t - make_interval(days => a.oy_il_gun) then 'Bu ilde oy hakkı: ' || to_char((p.il_at + make_interval(days => a.oy_il_gun)) at time zone 'Europe/Istanbul', 'DD.MM') end)),
    'parti_kurma', jsonb_build_object('kidem', a.parti_kurucu_kidem, 'kurucu', a.parti_kurucu_sayi, 'gun', a.parti_kurulus_gun, 'benim_kidem', k,
                                      'ucret', oyun.parti_kur_ucreti(), 'para', (select para from oyun.cuzdanim(p.id))));
end $$;

-- ---------------------------------------------------------------------
-- PARTİ KURULUŞU
-- ---------------------------------------------------------------------
create or replace function oyun.kurucu_say(p_parti bigint, t timestamptz) returns int language sql stable as $$
  select count(*)::int from oyun.profiller p where p.parti_id = p_parti and not p.yasakli and oyun.uyari(p, t) is null
$$;

create or replace function oyun.parti_kurulus_kontrol(p_parti bigint, t timestamptz) returns void language plpgsql as $$
declare pa oyun.partiler; n int; u uuid;
begin
  select * into pa from oyun.partiler where id = p_parti for update;
  if pa.id is null or pa.kurulus_bit is null or pa.kapali then return; end if;
  n := oyun.kurucu_say(pa.id, t);
  if n >= (select parti_kurucu_sayi from oyun.ayarlar where id = 1) then
    update oyun.partiler set kurulus_bit = null where id = pa.id;
    perform oyun.olay('parti', format('%s (%s) %s kurucu üyeyle kuruluşunu tamamladı ve seçimlere katılma hakkı kazandı.', pa.ad, pa.kisa, n), null, pa.id, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select id, t, format('%s kuruluşunu tamamladı. Artık seçimlere aday çıkarabilir.', pa.ad) from oyun.profiller where parti_id = pa.id;
  elsif t >= pa.kurulus_bit then
    for u in select id from oyun.profiller where parti_id = pa.id loop
      perform oyun.bildir(u, format('%s süresi içinde yeterli kurucu üye toplayamadığı için kurulamadı. Üyeliğin sona erdi.', pa.ad), t);
    end loop;
    update oyun.partiler set gb = null where id = pa.id;
    delete from oyun.parti_gby where parti_id = pa.id;
    update oyun.profiller set parti_id = null, parti_at = null where parti_id = pa.id;
    update oyun.partiler set kapali = true where id = pa.id;
    perform oyun.parti_kurulus_iade(pa, t);      -- kuruluş ücretinin yarısı kurucuya (15_ekonomi3)
    perform oyun.olay('parti', format('%s (%s) kurucu üye sayısını tamamlayamadığı için kurulamadı.', pa.ad, pa.kisa), null, null, t);
  end if;
end $$;

create or replace function oyun.guvenlik_tick(t timestamptz) returns void language plpgsql as $$
declare pid bigint;
begin
  for pid in select id from oyun.partiler where kurulus_bit is not null and not kapali loop
    perform oyun.parti_kurulus_kontrol(pid, t);
  end loop;
  -- silinen hesapların ve 180 gündür kullanılmayan cihaz kayıtlarının temizliği (saatte bir)
  if extract(minute from t) = 0 then
    delete from oyun.oturumlar o where o.son < t - interval '180 days' or not exists (select 1 from auth.users u where u.id = o.user_id);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- YÖNETİCİ: şüpheli hesap kümeleri, onay, kurallar
-- ---------------------------------------------------------------------
create or replace function public.admin_supheler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('coklu_hesap'); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    -- Güçlü: aynı cihaz kimliği · Zayıf: aynı cihaz izi (aynı model telefonlarda çakışabilir)
    'cihaz', coalesce((select jsonb_agg(k order by k ->> 'son' desc) from (
        select jsonb_build_object('tur', x.tur, 'son', max(o.son),
          'hesaplar', jsonb_agg(distinct jsonb_build_object('kad', pr.kad, 'olusturma', pr.olusturma, 'yasakli', pr.yasakli,
                         'onayli', exists (select 1 from oyun.hesap_onay h where h.user_id = pr.id),
                         'oy', (select count(*) from oyun.oylar where secmen = pr.id),
                         'engel', oyun.suphe(pr.id) is not null))) k
        from (select 'cihaz' tur, cihaz anahtar from oyun.oturumlar where cihaz is not null group by cihaz having count(distinct user_id) > 1
              union select 'iz', iz from oyun.oturumlar where iz is not null group by iz having count(distinct user_id) > 1) x
        join oyun.oturumlar o on (x.tur = 'cihaz' and o.cihaz = x.anahtar) or (x.tur = 'iz' and o.iz = x.anahtar)
        join oyun.profiller pr on pr.id = o.user_id
        group by x.tur, x.anahtar having count(distinct pr.id) > 1 limit 50) z), '[]'::jsonb),
    -- Zayıf: son 7 günde aynı bağlantı adresinden 3+ hesap (aile/okul/operatör olabilir; tek başına delil değildir)
    'ip', coalesce((select jsonb_agg(jsonb_build_object('sayi', n, 'hesaplar', h) order by n desc) from (
        select count(distinct pr.id) n, jsonb_agg(distinct pr.kad) h from oyun.oturumlar o join oyun.profiller pr on pr.id = o.user_id
        where o.ip is not null and o.son > t - interval '7 days' group by o.ip having count(distinct pr.id) >= 3 limit 30) z), '[]'::jsonb));
end $$;

create or replace function public.admin_hesap_onay(p_kad text, p_onay boolean, p_not text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('coklu_hesap'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi();
begin
  perform oyun.mod_log(p, case when p_onay then 'hesap_onay' else 'hesap_onay_kaldir' end, h.kad, p_not);
  if p_onay then
    insert into oyun.hesap_onay(user_id, yonetici, not_, zaman) values (h.id, p.id, oyun.metin_temizle(coalesce(p_not, ''), 300), t)
    on conflict (user_id) do update set yonetici = excluded.yonetici, not_ = excluded.not_, zaman = excluded.zaman;
    perform oyun.bildir(h.id, 'Hesabın yönetici incelemesinden geçti. Artık oy kullanabilir ve aday olabilirsin.', t);
  else
    delete from oyun.hesap_onay where user_id = h.id;
  end if;
  return public.admin_supheler();
end $$;

create or replace function public.admin_kurallar(p jsonb default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare y oyun.profiller := oyun.yetki_zorunlu('kurallar'); a oyun.ayarlar;
begin
  if p is not null then
    update oyun.ayarlar set
      min_hesap_gun      = oyun.sinir(coalesce((p ->> 'min_hesap_gun')::int, min_hesap_gun), 0, 30),
      oy_min_kidem       = oyun.sinir(coalesce((p ->> 'oy_min_kidem')::int, oy_min_kidem), 0, 100),
      oy_il_gun          = oyun.sinir(coalesce((p ->> 'oy_il_gun')::int, oy_il_gun), 0, 30),
      cihaz_max_hesap    = oyun.sinir(coalesce((p ->> 'cihaz_max_hesap')::int, cihaz_max_hesap), 1, 5),
      parti_kurucu_sayi  = oyun.sinir(coalesce((p ->> 'parti_kurucu_sayi')::int, parti_kurucu_sayi), 1, 30),
      parti_kurucu_kidem = oyun.sinir(coalesce((p ->> 'parti_kurucu_kidem')::int, parti_kurucu_kidem), 0, 300),
      parti_kurulus_gun  = oyun.sinir(coalesce((p ->> 'parti_kurulus_gun')::int, parti_kurulus_gun), 1, 30),
      -- 15_ekonomi3: parti ücreti, teşkilat, havale, banka
      parti_kur_ucret    = oyun.sinir(coalesce((p ->> 'parti_kur_ucret')::numeric, parti_kur_ucret), 0, 1000000),
      teskilat_ucret     = oyun.sinir(coalesce((p ->> 'teskilat_ucret')::numeric, teskilat_ucret), 0, 100000),
      teskilat_zorunlu   = coalesce((p ->> 'teskilat_zorunlu')::boolean, teskilat_zorunlu),
      havale_sinir       = oyun.sinir(coalesce((p ->> 'havale_sinir')::numeric, havale_sinir), 0, 10),
      banka_acik         = coalesce((p ->> 'banka_acik')::boolean, banka_acik),
      banka_reel_faiz    = oyun.sinir(coalesce((p ->> 'banka_reel_faiz')::numeric, banka_reel_faiz), -10, 30),
      banka_tavan        = oyun.sinir(coalesce((p ->> 'banka_tavan')::numeric, banka_tavan), 0, 100000000)
    where id = 1;
    perform oyun.mod_log(y, 'kurallar', null, p::text);
  end if;
  select * into a from oyun.ayarlar where id = 1;
  return jsonb_build_object('min_hesap_gun', a.min_hesap_gun, 'oy_min_kidem', a.oy_min_kidem, 'oy_il_gun', a.oy_il_gun,
    'cihaz_max_hesap', a.cihaz_max_hesap, 'parti_kurucu_sayi', a.parti_kurucu_sayi, 'parti_kurucu_kidem', a.parti_kurucu_kidem,
    'parti_kurulus_gun', a.parti_kurulus_gun,
    'parti_kur_ucret', a.parti_kur_ucret, 'teskilat_ucret', a.teskilat_ucret, 'teskilat_zorunlu', a.teskilat_zorunlu,
    'havale_sinir', a.havale_sinir, 'banka_acik', a.banka_acik, 'banka_reel_faiz', a.banka_reel_faiz, 'banka_tavan', a.banka_tavan);
end $$;
-- =====================================================================
--  15 · PARTİ KURULUŞ ÜCRETİ, İL TEŞKİLATLARI, OYUNCUDAN OYUNCUYA PARA GÖNDERME, BANKA
--
--  Parti kuruluşu: kurucu, kuruluş harcını ve genel merkez binasının bedelini cüzdanından öder
--    (parti_kur_ucret × fiyat düzeyi). Genel merkez, kurucunun ilinde ilk il teşkilatı olarak açılır.
--    Kuruluş süresi içinde yeterli kurucu toplanamazsa ücretin yarısı kurucuya iade edilir.
--  İl teşkilatı: parti bir ilde aday (milletvekili, belediye başkanı) gösterebilmek için o ilde teşkilat
--    (il binası) açmalıdır. Bedeli parti kasasından ödenir: teskilat_ucret × il büyüklüğü (1-3) × fiyat düzeyi.
--    Teşkilatı genel başkan ya da yardımcıları açar. Oyunla gelen 5 parti 81 ilde teşkilatlıdır.
--  Para gönderme (havale): seçmen kartı hazır oyuncu başka bir oyuncuya para gönderebilir.
--    Günlük gönderim sınırı: havale_sinir × aylık asgari ücret. Aynı cihazdaki hesaplar arasında gönderilemez.
--  Banka: vadesiz faizli hesap (faiz saat saat işler, her gece hesaba eklenir), vadeli hesap (7/30 gün,
--    sabit ve daha yüksek faiz; erken bozulursa durduğu süre kadar vadesiz faizi), kredi (7/15/30 gün,
--    günlük eşit taksit). Faizler enflasyona bağlıdır: politika faizi = enflasyon + banka_reel_faiz (yıllık).
--    Taksit ödenmezse: gecikme faizi, kredi notu düşer, banka hesabındaki paraya mahsup edilir;
--    3 gün üst üste ödenmezse yasal takip: maaşın yarısına haciz, vadeli hesaplar bozulur, kıdem −5,
--    "Takipteki borçlu" damgası, borç bitene kadar para gönderme/bağış/yeni kredi yok, kapandıktan sonra 30 gün kara liste.
-- =====================================================================

alter table oyun.ayarlar add column if not exists parti_kur_ucret  numeric not null default 25000;
alter table oyun.ayarlar add column if not exists teskilat_ucret   numeric not null default 2000;
alter table oyun.ayarlar add column if not exists teskilat_zorunlu boolean not null default true;
alter table oyun.ayarlar add column if not exists teskilat_gecis   boolean not null default false;   -- mevcut partilere bir kerelik teşkilat verildi mi
alter table oyun.ayarlar add column if not exists havale_sinir     numeric not null default 1;       -- günlük gönderim: aylık asgari ücretin katı
alter table oyun.ayarlar add column if not exists banka_acik       boolean not null default true;
alter table oyun.ayarlar add column if not exists banka_reel_faiz  numeric not null default 5;       -- politika faizi = enflasyon + bu (yıllık puan)
alter table oyun.ayarlar add column if not exists banka_tavan      numeric not null default 2000000; -- kişi başı en fazla mevduat (× fiyat düzeyi)
alter table oyun.ayarlar add column if not exists banka_son_gun    date;

alter table oyun.partiler add column if not exists kurulus_ucret numeric not null default 0;

-- ---------------------------------------------------------------------
-- İL TEŞKİLATLARI
-- ---------------------------------------------------------------------
create table if not exists oyun.parti_teskilat(
  parti_id     bigint not null references oyun.partiler(id) on delete cascade,
  il_id        smallint not null references oyun.iller(id),
  kurulus      timestamptz not null,
  kuran        uuid,
  bedel        numeric not null default 0,
  genel_merkez boolean not null default false,
  primary key (parti_id, il_id)
);
create index if not exists parti_teskilat_il on oyun.parti_teskilat(il_id);

-- Oyunla gelen partiler 81 ilde teşkilatlıdır
insert into oyun.parti_teskilat(parti_id, il_id, kurulus, genel_merkez)
select pa.id, i.id, pa.kurulus, i.id = 6 from oyun.partiler pa cross join oyun.iller i where pa.sistem
on conflict do nothing;

-- Bir kerelik geçiş: bu güncellemeden önce kurulmuş partiler, üyelerinin, adaylarının ve seçilmişlerinin
-- bulunduğu illerde teşkilatlı sayılır (oyuncuların seçim hakları güncelleme yüzünden düşmesin diye).
do $$
begin
  if not (select teskilat_gecis from oyun.ayarlar where id = 1) then
    insert into oyun.parti_teskilat(parti_id, il_id, kurulus, genel_merkez)
    select distinct on (x.parti_id, x.il_id) x.parti_id, x.il_id, pa.kurulus, coalesce(x.il_id = (select il_id from oyun.profiller where id = pa.kurucu), false)
    from (select parti_id, il_id from oyun.profiller where parti_id is not null
          union select pa2.id, pr.il_id from oyun.partiler pa2 join oyun.profiller pr on pr.id = pa2.kurucu
          union select a.parti_id, a.il_id from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
                 where a.parti_id is not null and a.il_id is not null and s.durum <> 'tamam'
          union select parti_id, il_id from oyun.makamlar where bit is null and parti_id is not null and il_id is not null) x
    join oyun.partiler pa on pa.id = x.parti_id
    where not pa.sistem and not pa.kapali and not exists (select 1 from oyun.parti_teskilat t where t.parti_id = pa.id)
    on conflict do nothing;
    update oyun.ayarlar set teskilat_gecis = true where id = 1;
  end if;
end $$;

-- İl büyüklüğü: 14+ vekil 3 · 8-13 vekil 2 · diğerleri 1 (belediye aday ücretindeki gibi)
create or replace function oyun.il_buyukluk(p_il smallint) returns int language sql stable as $$
  select case when mv >= 14 then 3 when mv >= 8 then 2 else 1 end from oyun.iller where id = p_il
$$;
create or replace function oyun.parti_kur_ucreti() returns numeric language sql stable as $$
  select round(a.parti_kur_ucret * u.endeks) from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;
create or replace function oyun.teskilat_ucreti(p_il smallint) returns numeric language sql stable as $$
  select round(a.teskilat_ucret * oyun.il_buyukluk(p_il) * u.endeks) from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;
create or replace function oyun.teskilat_var(p_parti bigint, p_il smallint) returns boolean language sql stable as $$
  select exists (select 1 from oyun.parti_teskilat where parti_id = p_parti and il_id = p_il)
$$;

-- aday_ol içinden: milletvekili ve belediye aday adaylığı için partinin o ilde teşkilatı olmalı
create or replace function oyun.teskilat_engeli(p oyun.profiller, p_tur text) returns text language sql stable as $$
  select case when p_tur in ('mv_on','bel_on') and (select teskilat_zorunlu from oyun.ayarlar where id = 1)
                   and p.parti_id is not null and not oyun.teskilat_var(p.parti_id, p.il_id)
    then format('Partinin %s il teşkilatı yok. Bu ilde aday gösterebilmesi için genel başkan ya da yardımcılarından biri önce il teşkilatı açmalı (Partiler › parti sayfası › İl teşkilatları).',
                (select ad from oyun.iller where id = p.il_id)) end
$$;

-- parti_kur içinden: kuruluş harcı ve genel merkez binası (cüzdandan). Para yetmezse kuruluş yapılmaz.
create or replace function oyun.parti_kur_harci(p oyun.profiller, p_ad text, t timestamptz) returns numeric language plpgsql as $$
declare ucret numeric := oyun.parti_kur_ucreti();
begin
  if ucret <= 0 then return 0; end if;
  if (select para from oyun.cuzdanim(p.id)) < ucret then
    raise exception 'Parti kurmak için % ₺ gerekiyor: kuruluş harcı ve genel merkez binası (cüzdanında % ₺ var).', oyun.tl(ucret), oyun.tl((select para from oyun.cuzdan where user_id = p.id));
  end if;
  perform oyun.para_islem(p.id, -ucret, 'parti_kur', format('%s kuruluş harcı ve genel merkez binası', p_ad), t);
  return ucret;
end $$;

-- parti_kur içinden: genel merkez, kurucunun ilinde ilk il teşkilatıdır
create or replace function oyun.genel_merkez_ac(p_parti bigint, p oyun.profiller, p_ucret numeric, t timestamptz) returns void language plpgsql as $$
begin
  update oyun.partiler set kurulus_ucret = p_ucret where id = p_parti;
  insert into oyun.parti_teskilat(parti_id, il_id, kurulus, kuran, bedel, genel_merkez) values (p_parti, p.il_id, t, p.id, 0, true)
  on conflict do nothing;
end $$;

-- parti_kurulus_kontrol içinden: kuruluş düşünce ücretin yarısı kurucuya iade edilir (bina satılır, harç yanar)
create or replace function oyun.parti_kurulus_iade(pa oyun.partiler, t timestamptz) returns void language plpgsql as $$
declare iade numeric := floor(coalesce(pa.kurulus_ucret, 0) / 2);
begin
  if iade < 1 or pa.kurucu is null or not exists (select 1 from oyun.profiller where id = pa.kurucu) then return; end if;
  perform oyun.para_islem(pa.kurucu, iade, 'parti_kur_iade', format('%s kurulamadı: genel merkez binası satıldı, ücretin yarısı iade', pa.ad), t);
  perform oyun.bildir(pa.kurucu, format('%s kurulamadığı için genel merkez binası satıldı; kuruluş ücretinin yarısı (%s ₺) cüzdanına iade edildi.', pa.ad, oyun.tl(iade)), t);
  update oyun.partiler set kurulus_ucret = 0 where id = pa.id;
end $$;

create or replace function oyun.teskilat_json(p_parti bigint, p oyun.profiller) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'sayi', (select count(*) from oyun.parti_teskilat where parti_id = p_parti),
    'iller', coalesce((select jsonb_agg(jsonb_build_object('il_id', t.il_id, 'ad', i.ad, 'kurulus', t.kurulus, 'genel_merkez', t.genel_merkez,
                         'uye', (select count(*) from oyun.profiller pr where pr.parti_id = p_parti and pr.il_id = t.il_id)) order by t.genel_merkez desc, i.ad)
                       from oyun.parti_teskilat t join oyun.iller i on i.id = t.il_id where t.parti_id = p_parti), '[]'::jsonb),
    'yetkili', p.parti_id = p_parti and (exists (select 1 from oyun.partiler where id = p_parti and gb = p.id)
                                         or exists (select 1 from oyun.parti_gby where parti_id = p_parti and user_id = p.id)),
    'zorunlu', (select teskilat_zorunlu from oyun.ayarlar where id = 1),
    'ucretler', jsonb_build_object('1', round(a.teskilat_ucret * u.endeks), '2', round(a.teskilat_ucret * 2 * u.endeks), '3', round(a.teskilat_ucret * 3 * u.endeks)),
    'kasa', (select round(kasa) from oyun.partiler where id = p_parti),
    'benim_ilim_var', p.parti_id = p_parti and oyun.teskilat_var(p_parti, p.il_id))
  from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;

create or replace function public.teskilatlar(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not exists (select 1 from oyun.partiler where id = p_parti) then raise exception 'Parti bulunamadı.'; end if;
  return oyun.teskilat_json(p_parti, p);
end $$;

-- Genel başkan ya da yardımcısı bir ilde teşkilat (il binası) açar; bedel parti kasasından
create or replace function public.teskilat_ac(p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; ucret numeric; ilad text;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id and not exists (select 1 from oyun.parti_gby where parti_id = pa.id and user_id = p.id) then
    raise exception 'İl teşkilatını yalnızca genel başkan ve genel başkan yardımcıları açabilir.';
  end if;
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  if oyun.teskilat_var(pa.id, p_il::smallint) then raise exception 'Partinin % ilinde zaten teşkilatı var.', ilad; end if;
  ucret := oyun.teskilat_ucreti(p_il::smallint);
  if pa.kasa < ucret then
    raise exception '% il binası için parti kasasında % ₺ olmalı (kasada % ₺ var). Üyeler bağış yaparak kasayı doldurabilir.', ilad, oyun.tl(ucret), oyun.tl(pa.kasa);
  end if;
  update oyun.partiler set kasa = kasa - ucret where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -ucret, format('%s il teşkilatı açıldı (il binası) · %s', ilad, p.kad), 'teskilat');
  insert into oyun.parti_teskilat(parti_id, il_id, kurulus, kuran, bedel) values (pa.id, p_il, t, p.id, ucret);
  perform oyun.olay('parti', format('%s, %s il teşkilatını açtı.', pa.kisa, ilad), p_il::smallint, pa.id, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select id, t, format('%s artık %s ilinde teşkilatlı: partin bu ilde milletvekili ve belediye başkanı adayı gösterebilir.', pa.kisa, ilad)
    from oyun.profiller where parti_id = pa.id and il_id = p_il and id <> p.id;
  return oyun.teskilat_json(pa.id, p);
end $$;

-- ---------------------------------------------------------------------
-- BANKA: TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.banka_musteri(
  user_id       uuid primary key references oyun.profiller(id) on delete cascade,
  vadesiz       numeric not null default 0 check (vadesiz >= 0),   -- vadesiz hesap bakiyesi (tam ₺)
  faiz_birikmis numeric not null default 0,                         -- işleyen, henüz hesaba eklenmemiş faiz (kuruşlu)
  son_faiz      timestamptz not null,
  faiz_toplam   numeric not null default 0,                         -- bugüne kadar kazanılan vadesiz faizi
  kredi_notu    int not null default 1100 check (kredi_notu between 0 and 1900),
  kara_liste    timestamptz                                          -- bu ana kadar yeni kredi verilmez
);

create table if not exists oyun.vadeli(
  id       bigserial primary key,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  anapara  numeric not null check (anapara > 0),
  oran     numeric not null,                 -- aylık faiz (%), açılışta sabitlenir
  gun      int not null check (gun in (7, 30)),
  acilis   timestamptz not null,
  vade     timestamptz not null,
  durum    text not null default 'acik' check (durum in ('acik','vade','bozuldu','haciz')),
  getiri   numeric,
  kapanis  timestamptz
);
create index if not exists vadeli_acik on oyun.vadeli(vade) where durum = 'acik';
create index if not exists vadeli_user on oyun.vadeli(user_id, acilis desc);

create table if not exists oyun.krediler(
  id          bigserial primary key,
  user_id     uuid not null references oyun.profiller(id) on delete cascade,
  anapara     numeric not null check (anapara > 0),
  oran        numeric not null,              -- aylık faiz (%)
  gun         int not null check (gun in (7, 15, 30)),
  toplam      numeric not null,              -- anapara + faiz
  taksit      numeric not null,              -- günlük taksit
  kalan       numeric not null,              -- kalan borç (gecikmiş kısım dahil)
  gecikmis    numeric not null default 0,    -- vadesi geçmiş, ödenmemiş kısım
  gecikme_gun int not null default 0,        -- üst üste ödenmeyen gün
  hic_gecikmedi boolean not null default true,
  acilis      timestamptz not null,
  son_tahsil  date,
  durum       text not null default 'aktif' check (durum in ('aktif','takip','kapandi')),
  kapanis     timestamptz
);
create unique index if not exists krediler_tek on oyun.krediler(user_id) where durum in ('aktif','takip');
create index if not exists krediler_acik on oyun.krediler(durum) where durum in ('aktif','takip');

create table if not exists oyun.banka_hareket(
  id       bigserial primary key,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  zaman    timestamptz not null,
  hesap    text not null check (hesap in ('vadesiz','vadeli','kredi')),
  tutar    numeric not null,
  aciklama text not null
);
create index if not exists banka_hareket_user on oyun.banka_hareket(user_id, zaman desc);

-- ---------------------------------------------------------------------
-- BANKA: YARDIMCILAR
-- ---------------------------------------------------------------------
-- Faiz oranları (aylık %). Politika faizi (yıllık) = enflasyon + reel faiz, en az %10.
create or replace function oyun.banka_oranlar() returns jsonb language sql stable as $$
  with x as (select greatest(10, round(u.enflasyon + a.banka_reel_faiz, 1)) py from oyun.ulke u, oyun.ayarlar a where u.id = 1 and a.id = 1)
  select jsonb_build_object('politika', py, 'vadesiz', round(py / 12 * 0.5, 2), 'vadeli7', round(py / 12 * 0.8, 2),
                            'vadeli30', round(py / 12 * 0.95, 2), 'kredi', round(py / 12 * 1.6, 2), 'gecikme_gunluk', 1)
  from x
$$;

create or replace function oyun.not_ad(n int) returns text language sql immutable as $$
  select case when n < 700 then 'Çok riskli' when n < 1100 then 'Orta riskli' when n < 1500 then 'Az riskli' when n < 1700 then 'İyi' else 'Çok iyi' end
$$;
-- Kredi notu kredi limitini ve faizini etkiler
create or replace function oyun.not_limit_kat(n int) returns numeric language sql immutable as $$
  select case when n < 700 then 0 when n < 1100 then 0.5 when n < 1500 then 1 when n < 1700 then 1.5 else 2 end
$$;
create or replace function oyun.not_faiz_kat(n int) returns numeric language sql immutable as $$
  select case when n < 1100 then 1.2 when n >= 1500 then 0.9 else 1 end
$$;

create or replace function oyun.musteri(u uuid, t timestamptz) returns oyun.banka_musteri language plpgsql as $$
declare m oyun.banka_musteri;
begin
  insert into oyun.banka_musteri(user_id, son_faiz) values (u, t) on conflict do nothing;
  select * into m from oyun.banka_musteri where user_id = u for update;
  return m;
end $$;

create or replace function oyun.banka_kayit(u uuid, p_hesap text, p_tutar numeric, p_aciklama text, t timestamptz) returns void language sql as $$
  insert into oyun.banka_hareket(user_id, zaman, hesap, tutar, aciklama) values (u, t, p_hesap, round(p_tutar), p_aciklama)
$$;

-- Vadesiz hesabın faizini bu ana kadar işlet (faiz_birikmis'e). Hesaba ekleme her gece yapılır.
create or replace function oyun.vadesiz_isle(u uuid, t timestamptz) returns oyun.banka_musteri language plpgsql as $$
declare m oyun.banka_musteri := oyun.musteri(u, t); gun numeric; f numeric;
begin
  gun := greatest(0, extract(epoch from (t - m.son_faiz)) / 86400);
  f := m.vadesiz * (oyun.banka_oranlar() ->> 'vadesiz')::numeric / 100 / 30 * gun;
  update oyun.banka_musteri set faiz_birikmis = faiz_birikmis + f, son_faiz = greatest(son_faiz, t) where user_id = u returning * into m;
  return m;
end $$;

create or replace function oyun.mevduat_toplam(u uuid) returns numeric language sql stable as $$
  select coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0)
       + coalesce((select sum(anapara) from oyun.vadeli where user_id = u and durum = 'acik'), 0)
$$;
create or replace function oyun.banka_tavani() returns numeric language sql stable as $$
  select round(a.banka_tavan * u.endeks) from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;

create or replace function oyun.aktif_kredi(u uuid) returns oyun.krediler language sql stable as $$
  select * from oyun.krediler where user_id = u and durum in ('aktif','takip') limit 1
$$;
create or replace function oyun.takipte(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.krediler where user_id = u and durum = 'takip')
$$;
create or replace function oyun.gecikmede(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.krediler where user_id = u and (durum = 'takip' or (durum = 'aktif' and gecikmis > 0)))
$$;
-- Gecikmiş borcu olan oyuncu para çıkaramaz (gönderme, bağış, bankadan çekme, vadeli açma)
create or replace function oyun.takip_engel(u uuid, p_islem text) returns void language plpgsql as $$
begin
  if oyun.gecikmede(u) then
    raise exception '%', format('Gecikmiş kredi borcun varken %s. Önce borcunu öde (Hayat › Banka).', p_islem);
  end if;
end $$;
create or replace function oyun.kredi_uyari(u uuid) returns text language sql stable as $$
  select case when k.durum = 'takip' then format('Kredin yasal takipte: %s ₺ borcun var. Maaşının yarısına haciz uygulanıyor; borcunu ödeyene kadar para gönderemez, bağış yapamazsın.', oyun.tl(k.kalan))
              when k.gecikmis > 0 then format('Kredi taksitin %s gündür ödenmedi (%s ₺ gecikmede). 3. günde kredin yasal takibe düşer.', k.gecikme_gun, oyun.tl(k.gecikmis)) end
  from oyun.krediler k where k.user_id = u and k.durum in ('aktif','takip') limit 1
$$;

-- Kredi limiti: aylık asgari ücret × statü katsayısı × (görevdeyse 1,5) × kredi notu katsayısı
create or replace function oyun.kredi_limiti(u uuid) returns numeric language sql stable as $$
  select floor(ul.asgari * (array[0.5, 1, 1.5, 2, 3, 4])[oyun.statu_basamak(oyun.kidem_puani(u)) + 1]
               * case when exists (select 1 from oyun.makamlar where user_id = u and bit is null) then 1.5 else 1 end
               * oyun.not_limit_kat(coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100)) / 100) * 100
  from oyun.ulke ul where ul.id = 1
$$;
create or replace function oyun.kredi_orani(u uuid) returns numeric language sql stable as $$
  select round((oyun.banka_oranlar() ->> 'kredi')::numeric * oyun.not_faiz_kat(coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100)), 2)
$$;

-- Erken kapama: henüz işlememiş günlerin faizi alınmaz
create or replace function oyun.erken_kapama(k oyun.krediler) returns numeric language sql immutable as $$
  select greatest(0, k.kalan - round((k.toplam - k.anapara) / k.gun * floor(greatest(0, k.kalan - k.gecikmis) / k.taksit)))
$$;

-- Borç tahsili: önce cüzdandan, yetmezse vadesiz hesaptan (bankanın mahsup hakkı); takipte vadeli hesaplar da bozulur.
create or replace function oyun.tahsil_et(u uuid, p_tutar numeric, p_takip boolean, p_aciklama text, t timestamptz) returns numeric language plpgsql as $$
declare kalan numeric := round(p_tutar); a numeric; m oyun.banka_musteri; v oyun.vadeli; g numeric; ode numeric; odenen numeric := 0;
begin
  if kalan <= 0 then return 0; end if;
  a := least(kalan, (select para from oyun.cuzdanim(u)));
  if a > 0 then perform oyun.para_islem(u, -a, 'kredi', p_aciklama, t); kalan := kalan - a; odenen := a; end if;
  if kalan > 0 then
    m := oyun.vadesiz_isle(u, t);
    a := least(kalan, floor(m.vadesiz));
    if a > 0 then
      update oyun.banka_musteri set vadesiz = vadesiz - a where user_id = u;
      perform oyun.banka_kayit(u, 'vadesiz', -a, 'Kredi borcuna mahsup edildi', t);
      kalan := kalan - a; odenen := odenen + a;
    end if;
  end if;
  if kalan > 0 and p_takip then
    for v in select * from oyun.vadeli where user_id = u and durum = 'acik' order by acilis for update loop
      g := round(v.anapara * (oyun.banka_oranlar() ->> 'vadesiz')::numeric / 100 / 30 * greatest(0, extract(epoch from (t - v.acilis)) / 86400));
      ode := least(kalan, v.anapara + g);
      update oyun.vadeli set durum = 'haciz', getiri = g, kapanis = t where id = v.id;
      perform oyun.banka_kayit(u, 'vadeli', -(v.anapara + g), format('Vadeli hesap (%s ₺) haciz nedeniyle bozuldu', oyun.tl(v.anapara)), t);
      kalan := kalan - ode; odenen := odenen + ode;
      if v.anapara + g - ode > 0 then
        perform oyun.para_islem(u, v.anapara + g - ode, 'banka', 'Bozulan vadeli hesaptan borç sonrası kalan', t);
      end if;
      exit when kalan <= 0;
    end loop;
  end if;
  return odenen;
end $$;

-- Kredi borcu bitince
create or replace function oyun.kredi_kapat(k oyun.krediler, t timestamptz) returns void language plpgsql as $$
begin
  update oyun.krediler set kalan = 0, gecikmis = 0, gecikme_gun = 0, durum = 'kapandi', kapanis = t where id = k.id;
  if k.durum = 'takip' then
    update oyun.banka_musteri set kara_liste = t + interval '30 days' where user_id = k.user_id;
    perform oyun.bildir(k.user_id, 'Takipteki kredi borcunu kapattın; haciz kalktı. 30 gün boyunca yeni kredi kullanamazsın.', t);
  elsif k.hic_gecikmedi then
    update oyun.banka_musteri set kredi_notu = least(1900, kredi_notu + 60) where user_id = k.user_id;
    perform oyun.bildir(k.user_id, 'Kredini zamanında kapattın. Kredi notun yükseldi.', t);
  else
    perform oyun.bildir(k.user_id, 'Kredi borcunu kapattın.', t);
  end if;
  perform oyun.banka_kayit(k.user_id, 'kredi', 0, 'Kredi kapandı', t);
end $$;

-- Takipte maaş haczi: toplanan maaşın yarısı borca (topla içinden çağrılır)
create or replace function oyun.haciz_uygula(u uuid, p_maas numeric, t timestamptz) returns numeric language plpgsql as $$
declare k oyun.krediler; h numeric;
begin
  select * into k from oyun.krediler where user_id = u and durum = 'takip' for update;
  if k.id is null or p_maas < 2 then return 0; end if;
  h := least(k.kalan, floor(p_maas / 2), (select para from oyun.cuzdan where user_id = u));
  if h <= 0 then return 0; end if;
  perform oyun.para_islem(u, -h, 'haciz', 'Maaş haczi: takipteki kredi borcuna', t);
  update oyun.krediler set kalan = kalan - h, gecikmis = greatest(0, gecikmis - h) where id = k.id returning * into k;
  perform oyun.banka_kayit(u, 'kredi', -h, 'Maaş haczi', t);
  if k.kalan <= 0 then perform oyun.kredi_kapat(k, t); end if;
  return h;
end $$;

-- Vade dolan vadeli hesap: anapara + faiz cüzdana
create or replace function oyun.vadeli_kapat(v oyun.vadeli, t timestamptz) returns void language plpgsql as $$
declare g numeric := round(v.anapara * v.oran / 100 * v.gun / 30);
begin
  update oyun.vadeli set durum = 'vade', getiri = g, kapanis = t where id = v.id and durum = 'acik';
  if not found then return; end if;
  perform oyun.para_islem(v.user_id, v.anapara + g, 'banka', format('Vadeli hesap vadesi doldu: %s ₺ anapara + %s ₺ faiz', oyun.tl(v.anapara), oyun.tl(g)), t);
  perform oyun.banka_kayit(v.user_id, 'vadeli', -(v.anapara + g), format('%s günlük vadeli hesap kapandı (faiz %s ₺)', v.gun, oyun.tl(g)), t);
  perform oyun.bildir(v.user_id, format('%s günlük vadeli hesabının vadesi doldu: %s ₺ anapara ve %s ₺ faiz cüzdanına yattı.', v.gun, oyun.tl(v.anapara), oyun.tl(g)), t);
end $$;

-- Bir günün banka işleri (gece 00:00'da): vadesiz faizleri hesaba eklenir, kredi taksitleri tahsil edilir
create or replace function oyun.banka_gunluk(g date, t timestamptz) returns void language plpgsql as $$
declare r record; m oyun.banka_musteri; x numeric; k oyun.krediler; borc numeric; odenen numeric; acik numeric; ceza numeric; gun_bas timestamptz := oyun.tr_an(g, 0);
begin
  -- vadesiz faiz
  for r in select user_id from oyun.banka_musteri where vadesiz > 0 or faiz_birikmis >= 1 loop
    m := oyun.vadesiz_isle(r.user_id, greatest(t, gun_bas));
    x := floor(m.faiz_birikmis);
    if x >= 1 then
      update oyun.banka_musteri set vadesiz = vadesiz + x, faiz_birikmis = faiz_birikmis - x, faiz_toplam = faiz_toplam + x where user_id = r.user_id;
      perform oyun.banka_kayit(r.user_id, 'vadesiz', x, 'Faiz geliri (' || to_char(g - 1, 'DD.MM') || ')', t);
    end if;
  end loop;
  -- kredi taksitleri (kredi o günden önce açılmış olmalı)
  for r in select id from oyun.krediler where durum in ('aktif','takip') and acilis < gun_bas and son_tahsil is distinct from g order by id loop
    select * into k from oyun.krediler where id = r.id for update;
    borc := least(k.kalan, k.gecikmis + k.taksit);
    odenen := oyun.tahsil_et(k.user_id, borc, k.durum = 'takip', 'Kredi taksiti (' || to_char(g, 'DD.MM') || ')', t);
    acik := borc - odenen;
    if odenen > 0 then perform oyun.banka_kayit(k.user_id, 'kredi', -odenen, 'Taksit tahsil edildi', t); end if;
    if acik > 0 then
      ceza := ceil(acik * 0.01);                       -- gecikme faizi: gecikmiş tutarın günlük %1'i
      update oyun.krediler set kalan = kalan - odenen + ceza, gecikmis = acik + ceza, gecikme_gun = gecikme_gun + 1, hic_gecikmedi = false, son_tahsil = g
        where id = k.id returning * into k;
      update oyun.banka_musteri set kredi_notu = greatest(0, kredi_notu - 40) where user_id = k.user_id;
      perform oyun.banka_kayit(k.user_id, 'kredi', ceza, 'Gecikme faizi', t);
      if k.durum = 'aktif' and k.gecikme_gun >= 3 then
        update oyun.krediler set durum = 'takip' where id = k.id returning * into k;
        update oyun.banka_musteri set kredi_notu = greatest(0, kredi_notu - 250) where user_id = k.user_id;
        perform oyun.kidem_ekle(k.user_id, -5);
        -- takip başlarken vadeli hesaplar bozulup borca sayılır
        odenen := oyun.tahsil_et(k.user_id, k.gecikmis, true, 'Yasal takip: gecikmiş borç', t);
        if odenen > 0 then
          update oyun.krediler set kalan = kalan - odenen, gecikmis = greatest(0, gecikmis - odenen) where id = k.id returning * into k;
          perform oyun.banka_kayit(k.user_id, 'kredi', -odenen, 'Takip: hesaplardan tahsil', t);
        end if;
        perform oyun.bildir(k.user_id, format('Kredin 3 gündür ödenmediği için yasal takibe düştü. Kalan borç: %s ₺. Toplanan maaşının yarısına haciz uygulanacak, kıdemin 5 puan düştü; borç bitene kadar para gönderemez, bağış yapamaz, yeni kredi alamazsın.', oyun.tl(k.kalan)), t);
        perform oyun.olay('banka', format('%s adlı oyuncunun kredisi yasal takibe düştü.', oyun.kad(k.user_id)), null, null, t);
      elsif k.durum = 'aktif' then
        perform oyun.bildir(k.user_id, format('Kredi taksitin ödenemedi: %s ₺ gecikmede (%s. gün). Cüzdanına ya da vadesiz hesabına para koy; 3. günde kredin yasal takibe düşer.', oyun.tl(k.gecikmis), k.gecikme_gun), t);
      else
        perform oyun.bildir(k.user_id, format('Takipteki kredi borcun: %s ₺. Gecikme faizi işliyor.', oyun.tl(k.kalan)), t);
      end if;
    else
      update oyun.krediler set kalan = kalan - odenen, gecikmis = 0, gecikme_gun = 0, son_tahsil = g where id = k.id returning * into k;
    end if;
    if k.kalan <= 0 then perform oyun.kredi_kapat(k, t); end if;
  end loop;
  delete from oyun.banka_hareket where zaman < t - interval '90 days';
end $$;

-- Her dakika (tick içinden): vadesi dolan vadeli hesaplar; gün dönünce banka_gunluk
create or replace function oyun.banka_tick(t timestamptz) returns void language plpgsql as $$
declare bugun date := (t at time zone 'Europe/Istanbul')::date; son date; v oyun.vadeli;
begin
  for v in select * from oyun.vadeli where durum = 'acik' and vade <= t order by vade limit 500 loop
    perform oyun.vadeli_kapat(v, t);
  end loop;
  select banka_son_gun into son from oyun.ayarlar where id = 1 for update;
  if son is null then update oyun.ayarlar set banka_son_gun = bugun where id = 1; return; end if;
  if son >= bugun then return; end if;
  son := greatest(son, bugun - 31);
  while son < bugun loop
    son := son + 1;
    perform oyun.banka_gunluk(son, t);
  end loop;
  update oyun.ayarlar set banka_son_gun = bugun where id = 1;
end $$;

create or replace function oyun.banka_acik_mi() returns void language plpgsql as $$
begin
  if not (select banka_acik from oyun.ayarlar where id = 1) then raise exception 'Banka şu an kapalı. Oyun yönetimi yeniden açınca kullanabilirsin.'; end if;
end $$;

-- ---------------------------------------------------------------------
-- BANKA: UYGULAMA FONKSİYONLARI
-- ---------------------------------------------------------------------
create or replace function oyun.banka_ozet(u uuid) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'vadesiz', coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0),
    'vadeli', coalesce((select sum(anapara) from oyun.vadeli where user_id = u and durum = 'acik'), 0),
    'kredi', (select kalan from oyun.krediler where user_id = u and durum in ('aktif','takip') limit 1),
    'uyari', oyun.kredi_uyari(u))
$$;

create or replace function public.banka() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.banka_musteri; k oyun.krediler; o jsonb := oyun.banka_oranlar();
        c oyun.cuzdan := oyun.cuzdanim(p.id); hb numeric; ul oyun.ulke;
begin
  m := oyun.vadesiz_isle(p.id, t);
  k := oyun.aktif_kredi(p.id);
  select * into ul from oyun.ulke where id = 1;
  hb := coalesce((select sum(-tutar) from oyun.hesap_hareket where user_id = p.id and tur = 'havale' and tutar < 0 and zaman >= oyun.bugun_bas(t)), 0);
  return jsonb_build_object(
    'acik', (select banka_acik from oyun.ayarlar where id = 1),
    'cuzdan', c.para, 'oranlar', o, 'enflasyon', round(ul.enflasyon, 1),
    'vadesiz', jsonb_build_object('bakiye', m.vadesiz, 'birikmis', round(m.faiz_birikmis, 2), 'faiz_toplam', m.faiz_toplam,
                                  'gunluk', round(m.vadesiz * (o ->> 'vadesiz')::numeric / 100 / 30, 2)),
    'vadeliler', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'anapara', v.anapara, 'oran', v.oran, 'gun', v.gun, 'acilis', v.acilis,
                       'vade', v.vade, 'durum', v.durum, 'getiri', coalesce(v.getiri, round(v.anapara * v.oran / 100 * v.gun / 30)),
                       'bozma', round(v.anapara * (o ->> 'vadesiz')::numeric / 100 / 30 * greatest(0, extract(epoch from (t - v.acilis)) / 86400)))
                       order by v.durum <> 'acik', v.acilis desc)
                     from (select * from oyun.vadeli where user_id = p.id and (durum = 'acik' or kapanis > t - interval '14 days') order by acilis desc limit 10) v), '[]'::jsonb),
    'kredi', case when k.id is not null then jsonb_build_object('id', k.id, 'anapara', k.anapara, 'oran', k.oran, 'gun', k.gun, 'toplam', k.toplam,
                  'taksit', k.taksit, 'kalan', k.kalan, 'gecikmis', k.gecikmis, 'gecikme_gun', k.gecikme_gun, 'durum', k.durum, 'acilis', k.acilis,
                  'erken_kapama', oyun.erken_kapama(k), 'kalan_gun', ceil(greatest(0, k.kalan - k.gecikmis) / k.taksit)) end,
    'kredi_notu', m.kredi_notu, 'not_ad', oyun.not_ad(m.kredi_notu),
    'kredi_oran', oyun.kredi_orani(p.id), 'kredi_limit', oyun.kredi_limiti(p.id),
    'kara_liste', case when m.kara_liste > t then m.kara_liste end,
    'kredi_engel', oyun.uyari(p, t),
    'tavan', oyun.banka_tavani(), 'mevduat', oyun.mevduat_toplam(p.id),
    'uyari', oyun.kredi_uyari(p.id),
    'havale', jsonb_build_object('bugun', hb, 'tavan', round(ul.asgari * (select havale_sinir from oyun.ayarlar where id = 1)), 'engel', oyun.uyari(p, t)),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'hesap', h.hesap, 'tutar', h.tutar, 'aciklama', h.aciklama) order by h.zaman desc, h.id desc)
                            from (select * from oyun.banka_hareket where user_id = p.id order by zaman desc, id desc limit 25) h), '[]'::jsonb));
end $$;

create or replace function public.banka_yatir(p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); tav numeric := oyun.banka_tavani();
begin
  perform oyun.banka_acik_mi();
  if m < 100 then raise exception 'En az 100 ₺ yatırabilirsin.'; end if;
  perform oyun.vadesiz_isle(p.id, t);
  if oyun.mevduat_toplam(p.id) + m > tav then
    raise exception 'Bankada en fazla % ₺ tutabilirsin (şu an % ₺ var).', oyun.tl(tav), oyun.tl(oyun.mevduat_toplam(p.id));
  end if;
  perform oyun.para_islem(p.id, -m, 'banka', 'Bankaya yatırıldı (vadesiz hesap)', t);
  update oyun.banka_musteri set vadesiz = vadesiz + m where user_id = p.id;
  perform oyun.banka_kayit(p.id, 'vadesiz', m, 'Cüzdandan yatırıldı', t);
  return public.banka();
end $$;

-- p_miktar boş = tamamını çek
create or replace function public.banka_cek(p_miktar numeric default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); mu oyun.banka_musteri; m numeric;
begin
  if oyun.gecikmede(p.id) then
    raise exception 'Gecikmiş kredi borcun olduğu için bankadaki paran bloke. Borcunu ödeyince çekebilirsin (Banka › Kredi › Borç öde).';
  end if;
  mu := oyun.vadesiz_isle(p.id, t);
  m := coalesce(round(p_miktar), floor(mu.vadesiz));
  if m < 1 then raise exception 'Vadesiz hesabında çekilecek para yok.'; end if;
  if m > mu.vadesiz then raise exception 'Vadesiz hesabında % ₺ var.', oyun.tl(mu.vadesiz); end if;
  update oyun.banka_musteri set vadesiz = vadesiz - m where user_id = p.id;
  perform oyun.banka_kayit(p.id, 'vadesiz', -m, 'Cüzdana çekildi', t);
  perform oyun.para_islem(p.id, m, 'banka', 'Bankadan çekildi (vadesiz hesap)', t);
  return public.banka();
end $$;

create or replace function public.vadeli_ac(p_miktar numeric, p_gun int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); oran numeric; tav numeric := oyun.banka_tavani();
begin
  perform oyun.banka_acik_mi();
  perform oyun.takip_engel(p.id, 'vadeli hesap açamazsın');
  if p_gun not in (7, 30) then raise exception 'Vade 7 ya da 30 gün olabilir.'; end if;
  if m < 1000 then raise exception 'Vadeli hesap en az 1.000 ₺ ile açılır.'; end if;
  if (select count(*) from oyun.vadeli where user_id = p.id and durum = 'acik') >= 3 then raise exception 'Aynı anda en fazla 3 vadeli hesabın olabilir.'; end if;
  perform oyun.musteri(p.id, t);
  if oyun.mevduat_toplam(p.id) + m > tav then
    raise exception 'Bankada en fazla % ₺ tutabilirsin (şu an % ₺ var).', oyun.tl(tav), oyun.tl(oyun.mevduat_toplam(p.id));
  end if;
  oran := (oyun.banka_oranlar() ->> case p_gun when 7 then 'vadeli7' else 'vadeli30' end)::numeric;
  perform oyun.para_islem(p.id, -m, 'banka', format('Vadeli hesap açıldı (%s gün, aylık %%%s)', p_gun, replace(oran::text, '.', ',')), t);
  insert into oyun.vadeli(user_id, anapara, oran, gun, acilis, vade) values (p.id, m, oran, p_gun, t, t + make_interval(days => p_gun));
  perform oyun.banka_kayit(p.id, 'vadeli', m, format('%s günlük vadeli hesap açıldı', p_gun), t);
  return public.banka();
end $$;

-- Vadeden önce bozma: durduğu gün kadar vadesiz faizi işler
create or replace function public.vadeli_boz(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v oyun.vadeli; g numeric;
begin
  select * into v from oyun.vadeli where id = p_id and user_id = p.id for update;
  if v.id is null or v.durum <> 'acik' then raise exception 'Açık bir vadeli hesap bulunamadı.'; end if;
  g := round(v.anapara * (oyun.banka_oranlar() ->> 'vadesiz')::numeric / 100 / 30 * greatest(0, extract(epoch from (t - v.acilis)) / 86400));
  update oyun.vadeli set durum = 'bozuldu', getiri = g, kapanis = t where id = v.id;
  perform oyun.para_islem(p.id, v.anapara + g, 'banka', format('Vadeli hesap bozuldu: %s ₺ anapara + %s ₺ faiz', oyun.tl(v.anapara), oyun.tl(g)), t);
  perform oyun.banka_kayit(p.id, 'vadeli', -(v.anapara + g), 'Vadeli hesap vadeden önce bozuldu', t);
  return public.banka();
end $$;

create or replace function public.kredi_cek(p_miktar numeric, p_gun int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); mu oyun.banka_musteri;
        lim numeric; oran numeric; top numeric; tak numeric;
begin
  perform oyun.banka_acik_mi();
  if oyun.uyari(p, t) is not null then raise exception 'Kredi için seçmen kartın hazır olmalı: %', oyun.uyari(p, t); end if;
  if exists (select 1 from oyun.krediler where user_id = p.id and durum in ('aktif','takip')) then raise exception 'Ödenmemiş bir kredin var. Önce onu kapatmalısın.'; end if;
  mu := oyun.musteri(p.id, t);
  if mu.kara_liste > t then
    raise exception 'Takibe düşen kredin nedeniyle % tarihine kadar yeni kredi alamazsın.', to_char(mu.kara_liste at time zone 'Europe/Istanbul', 'DD.MM.YYYY');
  end if;
  if mu.kredi_notu < 700 then raise exception 'Kredi notun çok düşük (%). Not, kredilerini zamanında ödedikçe yükselir.', mu.kredi_notu; end if;
  if p_gun not in (7, 15, 30) then raise exception 'Vade 7, 15 ya da 30 gün olabilir.'; end if;
  lim := oyun.kredi_limiti(p.id);
  if m < 1000 then raise exception 'En az 1.000 ₺ kredi çekebilirsin.'; end if;
  if m > lim then raise exception 'Kredi limitin % ₺. Statün yükseldikçe ve kredilerini zamanında ödedikçe limitin artar.', oyun.tl(lim); end if;
  oran := oyun.kredi_orani(p.id);
  top := round(m * (1 + oran / 100 * p_gun / 30));
  tak := ceil(top / p_gun);
  insert into oyun.krediler(user_id, anapara, oran, gun, toplam, taksit, kalan, acilis) values (p.id, m, oran, p_gun, top, tak, top, t);
  perform oyun.para_islem(p.id, m, 'kredi', format('Kredi kullanıldı: %s gün vadeli, aylık %%%s faiz', p_gun, replace(oran::text, '.', ',')), t);
  perform oyun.banka_kayit(p.id, 'kredi', top, format('%s ₺ kredi (geri ödeme %s ₺, günlük %s ₺ × %s gün)', oyun.tl(m), oyun.tl(top), oyun.tl(tak), p_gun), t);
  perform oyun.bildir(p.id, format('Kredin hesabına geçti: %s ₺. Yarından itibaren her gece %s ₺ taksit cüzdanından otomatik ödenir (%s gün).', oyun.tl(m), oyun.tl(tak), p_gun), t);
  return public.banka();
end $$;

-- Borç ödeme. p_miktar boş = erken kapama (kalan günlerin faizi alınmaz). Önce cüzdandan, yetmezse vadesiz hesaptan.
create or replace function public.kredi_ode(p_miktar numeric default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.krediler; m numeric; mevcut numeric; kapama boolean := p_miktar is null; odenen numeric;
begin
  select * into k from oyun.krediler where user_id = p.id and durum in ('aktif','takip') for update;
  if k.id is null then raise exception 'Ödenecek kredin yok.'; end if;
  m := case when kapama then oyun.erken_kapama(k) else least(round(p_miktar), k.kalan) end;
  if m < 1 then raise exception 'Geçerli bir tutar gir.'; end if;
  if m >= oyun.erken_kapama(k) then kapama := true; m := oyun.erken_kapama(k); end if;
  mevcut := (select para from oyun.cuzdanim(p.id)) + floor((oyun.vadesiz_isle(p.id, t)).vadesiz);
  if mevcut < m then raise exception 'Bu ödeme için % ₺ gerekiyor; cüzdanında ve vadesiz hesabında toplam % ₺ var.', oyun.tl(m), oyun.tl(mevcut); end if;
  odenen := oyun.tahsil_et(p.id, m, false, case when kapama then 'Kredi erken kapama' else 'Kredi ara ödemesi' end, t);
  perform oyun.banka_kayit(p.id, 'kredi', -odenen, case when kapama then 'Erken kapama' else 'Ara ödeme' end, t);
  if kapama then
    perform oyun.kredi_kapat(k, t);
  else
    update oyun.krediler set kalan = kalan - odenen, gecikmis = greatest(0, gecikmis - odenen),
                             gecikme_gun = case when gecikmis - odenen <= 0 then 0 else gecikme_gun end where id = k.id;
  end if;
  return public.banka();
end $$;

-- ---------------------------------------------------------------------
-- OYUNCUDAN OYUNCUYA PARA GÖNDERME (havale)
-- ---------------------------------------------------------------------
create or replace function public.para_gonder(p_kad text, p_miktar numeric, p_aciklama text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; m numeric := round(coalesce(p_miktar, 0));
        ack text; bugun numeric; tavan numeric;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendine para gönderemezsin.'; end if;
  if h.yasakli then raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ gönderebilirsin.'; end if;
  if oyun.uyari(p, t) is not null then raise exception 'Para göndermek için seçmen kartın hazır olmalı: %', oyun.uyari(p, t); end if;
  if (select coklu_kontrol from oyun.ayarlar where id = 1) and exists (select 1 from oyun.bagli_hesaplar(p.id) b where b = h.id) then
    raise exception 'Aynı cihazda açılmış hesaplar arasında para gönderilemez.';
  end if;
  if oyun.engelli(h.id, p.id) then raise exception 'Bu oyuncu seni engellediği için ona para gönderemezsin.'; end if;
  perform oyun.takip_engel(p.id, 'para gönderemezsin');
  bugun := coalesce((select sum(-tutar) from oyun.hesap_hareket where user_id = p.id and tur = 'havale' and tutar < 0 and zaman >= oyun.bugun_bas(t)), 0);
  tavan := round((select asgari from oyun.ulke where id = 1) * (select havale_sinir from oyun.ayarlar where id = 1));
  if bugun + m > tavan then
    raise exception 'Günlük gönderim sınırı % ₺ (bugün % ₺ gönderdin).', oyun.tl(tavan), oyun.tl(bugun);
  end if;
  if nullif(btrim(coalesce(p_aciklama, '')), '') is not null then ack := oyun.metin_temizle(p_aciklama, 100); end if;
  perform oyun.para_islem(p.id, -m, 'havale', format('%s adlı oyuncuya gönderildi%s', h.kad, coalesce(': ' || ack, '')), t);
  perform oyun.para_islem(h.id, m, 'havale', format('%s gönderdi%s', p.kad, coalesce(': ' || ack, '')), t);
  perform oyun.bildir(h.id, format('%s sana %s ₺ gönderdi.%s', p.kad, oyun.tl(m), coalesce(' Not: “' || ack || '”', '')), t);
  return jsonb_build_object('tamam', true, 'alici', h.kad, 'miktar', m, 'para', (select para from oyun.cuzdan where user_id = p.id),
                            'bugun', bugun + m, 'tavan', tavan);
end $$;
-- =====================================================================
--  16 · MODERATÖR EKİBİ
--  Yönetici (profiller.yonetici = true; oyunun sahibi) her şeyi yapar. Yönetici istediği oyuncuyu moderatör
--  yapar ve hangi yetkilerin onda olacağını tek tek seçer. Moderatör yalnızca kendisine verilen işleri yapabilir;
--  yöneticiye ya da başka bir moderatöre işlem yapamaz, moderatör atayamaz. Her yetkili işlem moderasyon
--  günlüğüne yazılır; günlüğü yalnızca yönetici görür.
--  Moderatör atamak ve uygulama sürümünü zorunlu kılmak yalnızca yöneticinin işidir.
-- =====================================================================

create table if not exists oyun.moderatorler(
  user_id  uuid primary key references oyun.profiller(id) on delete cascade,
  yetkiler text[] not null default '{}',
  atayan   uuid,
  zaman    timestamptz not null
);

create table if not exists oyun.mod_kayit(
  id      bigserial primary key,
  zaman   timestamptz not null,
  user_id uuid,
  kad     text,
  islem   text not null,
  hedef   text,
  ayrinti text
);
create index if not exists mod_kayit_zaman on oyun.mod_kayit(zaman desc);

-- Verilebilecek yetkiler
create or replace function oyun.mod_yetki_tanim() returns table(kod text, ad text, aciklama text, sira int) language sql immutable as $$
  values ('ozet',        'Özet',                    'Oyuncu sayısı, aktiflik, açık şikâyet gibi özet rakamları görür.', 1),
         ('sikayet',     'Şikâyetler',              'Şikâyet edilen mesaj ve yayınları görür; "sorun yok" ya da "gizle" kararı verir.', 2),
         ('sustur',      'Susturma',                'Oyuncuyu 1 ya da 7 gün susturur, susturmayı kaldırır.', 3),
         ('hesap_kapat', 'Hesap kapatma',           'Kural ihlali yapan hesabı kapatır ya da yeniden açar.', 4),
         ('oyuncu_ara',  'Oyuncu inceleme',         'Oyuncunun bilgilerini ve son mesajlarını görür.', 5),
         ('eposta',      'E-posta görme',           'Oyuncu incelerken e-posta adresini de görür (kişisel veri; dikkatli ver).', 6),
         ('duyuru',      'Duyuru',                  'Tüm oyunculara oyun yönetimi adına duyuru gönderir.', 7),
         ('coklu_hesap', 'Çoklu hesap incelemesi',  'Aynı cihazdan açılan hesapları görür, gerçek kişi olanları onaylar.', 8),
         ('kurallar',    'Kurallar ve ayarlar',     'Vatandaşlık, parti kurma, teşkilat, havale ve banka kurallarını değiştirir.', 9)
$$;

create or replace function oyun.yetkili(u uuid, p_yetki text) returns boolean language sql stable as $$
  select coalesce((select yonetici from oyun.profiller where id = u), false)
      or exists (select 1 from oyun.moderatorler m join oyun.profiller p on p.id = m.user_id where m.user_id = u and not p.yasakli and p_yetki = any(m.yetkiler))
$$;

-- Admin fonksiyonlarının kapısı: yönetici her şeyi, moderatör yalnızca kendi yetkisini yapar
create or replace function oyun.yetki_zorunlu(p_yetki text) returns oyun.profiller language plpgsql as $$
declare p oyun.profiller := oyun.profilim();
begin
  if p.yonetici then return p; end if;
  if exists (select 1 from oyun.moderatorler where user_id = p.id and p_yetki = any(yetkiler)) then return p; end if;
  if exists (select 1 from oyun.moderatorler where user_id = p.id) then
    raise exception 'Bu işlem için yetkin yok. Moderatör yetkilerini oyunun yöneticisi belirler.';
  end if;
  raise exception 'Bu ekran yalnızca oyun yöneticileri ve moderatörler içindir.';
end $$;

-- Moderatör, yöneticiye ya da başka bir moderatöre işlem yapamaz
create or replace function oyun.korunan_hedef(p oyun.profiller, h uuid) returns void language plpgsql as $$
begin
  if p.yonetici then return; end if;
  if exists (select 1 from oyun.profiller where id = h and yonetici) or exists (select 1 from oyun.moderatorler where user_id = h) then
    raise exception 'Yöneticiye ya da başka bir moderatöre işlem yapamazsın.';
  end if;
end $$;

create or replace function oyun.mod_log(p oyun.profiller, p_islem text, p_hedef text, p_ayrinti text) returns void language sql as $$
  insert into oyun.mod_kayit(zaman, user_id, kad, islem, hedef, ayrinti) values (oyun.simdi(), p.id, p.kad, p_islem, p_hedef, left(p_ayrinti, 300))
$$;

-- Uygulamanın paneli göstermesi için: bu oyuncunun yetkileri
create or replace function oyun.yetkilerim(u uuid) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'yonetici', coalesce(p.yonetici, false),
    'moderator', m.user_id is not null,
    'liste', case when p.yonetici then (select jsonb_agg(kod order by sira) from oyun.mod_yetki_tanim())
                  else coalesce(to_jsonb(m.yetkiler), '[]'::jsonb) end)
  from oyun.profiller p left join oyun.moderatorler m on m.user_id = p.id where p.id = u
$$;

-- ---------- Yalnızca yönetici ----------
create or replace function public.admin_moderatorler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu();
begin
  return jsonb_build_object(
    'tanim', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad, 'aciklama', aciklama) order by sira) from oyun.mod_yetki_tanim()),
    'liste', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'yetkiler', to_jsonb(m.yetkiler), 'zaman', m.zaman, 'atayan', oyun.kad(m.atayan),
                         'son_gorulme', pr.son_gorulme, 'yasakli', pr.yasakli,
                         'islem_7gun', (select count(*) from oyun.mod_kayit k where k.user_id = m.user_id and k.zaman > oyun.simdi() - interval '7 days'))
                         order by m.zaman)
                       from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id), '[]'::jsonb));
end $$;

-- Moderatör ata / yetkilerini değiştir. Boş liste = moderatörlükten çıkar.
create or replace function public.admin_moderator_ayarla(p_kad text, p_yetkiler text[]) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi(); h oyun.profiller := oyun.profil_bul(p_kad);
        y text[]; gecersiz text; adlar text; vardi boolean;
begin
  if h.id = p.id then raise exception 'Kendi yetkilerini değiştiremezsin; sen zaten yöneticisin.'; end if;
  if h.yonetici then raise exception '% zaten yönetici; moderatör yapılamaz.', h.kad; end if;
  if h.yasakli then raise exception 'Hesabı kapatılmış oyuncu moderatör yapılamaz.'; end if;
  select array_agg(distinct x order by x) into y from unnest(coalesce(p_yetkiler, '{}')) x where nullif(btrim(x), '') is not null;
  select string_agg(x, ', ') into gecersiz from unnest(coalesce(y, '{}')) x where x not in (select kod from oyun.mod_yetki_tanim());
  if gecersiz is not null then raise exception 'Geçersiz yetki: %', gecersiz; end if;
  vardi := exists (select 1 from oyun.moderatorler where user_id = h.id);
  if y is null or cardinality(y) = 0 then
    delete from oyun.moderatorler where user_id = h.id;
    if vardi then
      perform oyun.bildir(h.id, 'Oyun yönetimindeki moderatörlük görevin sona erdi. Katkın için teşekkürler.', t);
      perform oyun.mod_log(p, 'moderator_cikar', h.kad, null);
    end if;
    return public.admin_moderatorler();
  end if;
  insert into oyun.moderatorler(user_id, yetkiler, atayan, zaman) values (h.id, y, p.id, t)
  on conflict (user_id) do update set yetkiler = excluded.yetkiler, atayan = excluded.atayan;
  select string_agg(ad, ', ' order by sira) into adlar from oyun.mod_yetki_tanim() where kod = any(y);
  perform oyun.bildir(h.id, case when vardi then 'Moderatör yetkilerin güncellendi: ' || adlar || '.'
                                 else 'Oyun yöneticisi seni moderatör yaptı. Yetkilerin: ' || adlar || '. Paneline Profilim › Moderatör paneli''nden ulaşırsın.' end, t);
  perform oyun.mod_log(p, case when vardi then 'moderator_yetki' else 'moderator_ata' end, h.kad, adlar);
  return public.admin_moderatorler();
end $$;

create or replace function public.admin_mod_kayit(p_limit int default 60) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('zaman', k.zaman, 'kad', k.kad, 'islem', k.islem, 'hedef', k.hedef, 'ayrinti', k.ayrinti) order by k.zaman desc, k.id desc)
                   from (select * from oyun.mod_kayit order by zaman desc, id desc limit least(greatest(coalesce(p_limit, 60), 1), 200)) k), '[]'::jsonb);
end $$;
-- Canlı kaynak: supabase_migrations 20261007153118 / basin_ve_teskilat_gorevlisi_20261007
-- 2026.10.07-3. Dış güncelleme işlemini sql_birlestir yönetir; burada tekrar başlatılmaz.
alter table oyun.ayarlar add column if not exists gazete_kur_ucret numeric not null default 10000;
alter table oyun.ayarlar add column if not exists gazete_abone_gun int not null default 30;
alter table oyun.ayarlar add column if not exists gazete_max_abonelik numeric not null default 10000;
alter table oyun.ayarlar add column if not exists gazete_gunluk_yayin int not null default 10;

create table if not exists oyun.parti_teskilat_gorev(
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  il_id smallint not null references oyun.iller(id),
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  atayan uuid not null references oyun.profiller(id),
  atama timestamptz not null default now(),
  aktif boolean not null default true,
  primary key(parti_id, il_id)
);
create index if not exists parti_teskilat_gorev_user
  on oyun.parti_teskilat_gorev(user_id) where aktif;

create table if not exists oyun.oyuncu_gazeteleri(
  id bigserial primary key,
  ad text not null,
  slogan text not null default '',
  sahip uuid not null references oyun.profiller(id) on delete cascade,
  abonelik_ucret numeric not null default 0 check (abonelik_ucret >= 0),
  kasa numeric not null default 0 check (kasa >= 0),
  kurulus timestamptz not null default now(),
  aktif boolean not null default true
);
create unique index if not exists oyuncu_gazete_ad_aktif
  on oyun.oyuncu_gazeteleri(lower(ad)) where aktif;
create unique index if not exists oyuncu_gazete_sahip_aktif
  on oyun.oyuncu_gazeteleri(sahip) where aktif;

create table if not exists oyun.gazete_abonelik(
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  baslangic timestamptz not null,
  bitis timestamptz not null,
  toplam_odeme numeric not null default 0,
  primary key(gazete_id, user_id)
);
create index if not exists gazete_abonelik_user
  on oyun.gazete_abonelik(user_id, bitis desc);

create table if not exists oyun.gazete_yazar_teklif(
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  teklif_eden uuid not null references oyun.profiller(id),
  ucret_yazi numeric not null default 0 check (ucret_yazi >= 0),
  durum text not null default 'bekliyor'
    check (durum in ('bekliyor','kabul','ret','iptal')),
  zaman timestamptz not null,
  yanit timestamptz,
  primary key(gazete_id, user_id)
);

create table if not exists oyun.gazete_yazarlar(
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  ucret_yazi numeric not null default 0 check (ucret_yazi >= 0),
  baslangic timestamptz not null,
  aktif boolean not null default true,
  primary key(gazete_id, user_id)
);
create index if not exists gazete_yazar_user
  on oyun.gazete_yazarlar(user_id) where aktif;

create table if not exists oyun.gazete_yayinlari(
  id bigserial primary key,
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  yazar uuid not null references oyun.profiller(id),
  tur text not null check (tur in ('haber','kose','propaganda')),
  baslik text not null,
  metin text not null,
  hedef_parti bigint references oyun.partiler(id),
  zaman timestamptz not null
);
create index if not exists gazete_yayin_son
  on oyun.gazete_yayinlari(gazete_id, zaman desc, id desc);

create table if not exists oyun.gazete_hareket(
  id bigserial primary key,
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  zaman timestamptz not null,
  tutar numeric not null,
  tur text not null,
  aciklama text not null
);
create index if not exists gazete_hareket_son
  on oyun.gazete_hareket(gazete_id, zaman desc, id desc);

create or replace function oyun.gazete_kur_ucreti()
returns numeric
language sql stable
set search_path = ''
as $$
  select round(a.gazete_kur_ucret * u.endeks)
  from oyun.ayarlar a, oyun.ulke u
  where a.id = 1 and u.id = 1
$$;

create or replace function oyun.gazete_erisim(
  p_gazete bigint, p_user uuid, p_zaman timestamptz
)
returns boolean
language sql stable
set search_path = ''
as $$
  select exists(
           select 1 from oyun.oyuncu_gazeteleri g
           where g.id = p_gazete and g.aktif and g.sahip = p_user
         )
      or exists(
           select 1 from oyun.gazete_yazarlar y
           where y.gazete_id = p_gazete and y.user_id = p_user and y.aktif
         )
      or exists(
           select 1 from oyun.oyuncu_gazeteleri g
           where g.id = p_gazete and g.aktif and g.abonelik_ucret = 0
         )
      or exists(
           select 1 from oyun.gazete_abonelik a
           where a.gazete_id = p_gazete and a.user_id = p_user and a.bitis > p_zaman
         )
$$;

create or replace function oyun.teskilat_json(p_parti bigint, p oyun.profiller)
returns jsonb
language sql stable
set search_path = ''
as $$
  select jsonb_build_object(
    'sayi', (select count(*) from oyun.parti_teskilat where parti_id = p_parti),
    'iller', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', t.il_id,
        'ad', i.ad,
        'kurulus', t.kurulus,
        'genel_merkez', t.genel_merkez,
        'uye', (select count(*) from oyun.profiller pr
                where pr.parti_id = p_parti and pr.il_id = t.il_id),
        'gorevli', (select oyun.kad(g.user_id)
                    from oyun.parti_teskilat_gorev g
                    where g.parti_id = p_parti
                      and g.il_id = t.il_id
                      and g.aktif)
      ) order by t.genel_merkez desc, i.ad)
      from oyun.parti_teskilat t
      join oyun.iller i on i.id = t.il_id
      where t.parti_id = p_parti
    ), '[]'::jsonb),
    'gorevler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', g.il_id,
        'ad', i.ad,
        'kad', oyun.kad(g.user_id),
        'atama', g.atama,
        'teskilat_acik', oyun.teskilat_var(p_parti, g.il_id)
      ) order by i.ad)
      from oyun.parti_teskilat_gorev g
      join oyun.iller i on i.id = g.il_id
      where g.parti_id = p_parti and g.aktif
    ), '[]'::jsonb),
    'benim_gorevler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', g.il_id,
        'ad', i.ad,
        'teskilat_acik', oyun.teskilat_var(p_parti, g.il_id),
        'ucret', oyun.teskilat_ucreti(g.il_id)
      ) order by i.ad)
      from oyun.parti_teskilat_gorev g
      join oyun.iller i on i.id = g.il_id
      where g.parti_id = p_parti and g.user_id = p.id and g.aktif
    ), '[]'::jsonb),
    'yetkili', p.parti_id = p_parti and (
      exists(select 1 from oyun.partiler where id = p_parti and gb = p.id)
      or exists(select 1 from oyun.parti_gby
                where parti_id = p_parti and user_id = p.id)
    ),
    'gorev_verebilir', p.parti_id = p_parti
      and exists(select 1 from oyun.partiler where id = p_parti and gb = p.id),
    'zorunlu', (select teskilat_zorunlu from oyun.ayarlar where id = 1),
    'ucretler', jsonb_build_object(
      '1', round(a.teskilat_ucret * u.endeks),
      '2', round(a.teskilat_ucret * 2 * u.endeks),
      '3', round(a.teskilat_ucret * 3 * u.endeks)
    ),
    'kasa', (select round(kasa) from oyun.partiler where id = p_parti),
    'cuzdan', coalesce((select round(para) from oyun.cuzdan where user_id = p.id), 0),
    'benim_ilim_var', p.parti_id = p_parti
      and oyun.teskilat_var(p_parti, p.il_id)
  )
  from oyun.ayarlar a, oyun.ulke u
  where a.id = 1 and u.id = 1
$$;

create or replace function public.teskilat_gorev_ver(p_il int, p_kad text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  h oyun.profiller;
  pa oyun.partiler;
  t timestamptz := oyun.simdi();
  ilad text;
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali;

  if pa.id is null or pa.gb is distinct from p.id then
    raise exception 'İl teşkilat görevlisini yalnızca genel başkan atayabilir.';
  end if;

  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pa.id then
    raise exception 'Yalnızca kendi partinin üyesini görevlendirebilirsin.';
  end if;
  if h.il_id is distinct from p_il::smallint then
    raise exception 'Görevli, teşkilat kurulacak ilde kayıtlı olmalı.';
  end if;

  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;

  insert into oyun.parti_teskilat_gorev(
    parti_id, il_id, user_id, atayan, atama, aktif
  ) values (pa.id, p_il, h.id, p.id, t, true)
  on conflict(parti_id, il_id) do update
    set user_id = excluded.user_id,
        atayan = excluded.atayan,
        atama = excluded.atama,
        aktif = true;

  perform oyun.bildir(
    h.id,
    format(
      '%s Genel Başkanı %s seni %s il teşkilat sorumlusu yaptı. Teşkilat henüz açılmadıysa kuruluş bedelini kendi cüzdanından ödeyebilirsin.',
      pa.kisa, p.kad, ilad
    ),
    t
  );

  return oyun.teskilat_json(pa.id, p);
end $$;

create or replace function public.teskilat_gorev_al(p_il int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  pa oyun.partiler;
  h uuid;
  t timestamptz := oyun.simdi();
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali;

  if pa.id is null or pa.gb is distinct from p.id then
    raise exception 'Bu görevi yalnızca genel başkan kaldırabilir.';
  end if;

  select user_id into h
  from oyun.parti_teskilat_gorev
  where parti_id = pa.id and il_id = p_il and aktif
  for update;

  update oyun.parti_teskilat_gorev
  set aktif = false
  where parti_id = pa.id and il_id = p_il and aktif;

  if h is not null then
    perform oyun.bildir(h, 'İl teşkilat sorumluluğu görevin sona erdirildi.', t);
  end if;

  return oyun.teskilat_json(pa.id, p);
end $$;

create or replace function public.teskilat_ac2(
  p_il int,
  p_kaynak text default 'parti'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  pa oyun.partiler;
  t timestamptz := oyun.simdi();
  ucret numeric;
  ilad text;
  yonetim boolean;
  gorevli boolean;
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali
  for update;

  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;

  yonetim := pa.gb = p.id or exists(
    select 1 from oyun.parti_gby
    where parti_id = pa.id and user_id = p.id
  );
  gorevli := exists(
    select 1 from oyun.parti_teskilat_gorev
    where parti_id = pa.id
      and il_id = p_il
      and user_id = p.id
      and aktif
  );

  if not yonetim and not gorevli then
    raise exception 'Bu ilde teşkilat açma yetkin yok.';
  end if;

  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;

  if gorevli and p.il_id is distinct from p_il::smallint then
    raise exception 'Teşkilat sorumlusu yalnızca kayıtlı olduğu il için ödeme yapabilir.';
  end if;

  if oyun.teskilat_var(pa.id, p_il::smallint) then
    raise exception 'Partinin % ilinde zaten teşkilatı var.', ilad;
  end if;

  ucret := oyun.teskilat_ucreti(p_il::smallint);

  if p_kaynak = 'parti' then
    if not yonetim then
      raise exception 'Parti kasasından ödemeyi yalnızca genel başkan veya yardımcısı yapabilir.';
    end if;
    if pa.kasa < ucret then
      raise exception 'Parti kasasında yeterli para yok (% ₺ gerekli).', oyun.tl(ucret);
    end if;

    update oyun.partiler set kasa = kasa - ucret where id = pa.id;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
    values (
      pa.id, t, -ucret,
      format('%s il teşkilatı açıldı · parti kasası · %s', ilad, p.kad),
      'teskilat'
    );

  elsif p_kaynak = 'kendi' then
    perform oyun.para_islem(
      p.id, -ucret, 'teskilat',
      format('%s %s il teşkilatı kuruluş bedeli', pa.kisa, ilad),
      t
    );
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
    values (
      pa.id, t, 0,
      format('%s il teşkilatı açıldı · %s kendi cüzdanından ödedi', ilad, p.kad),
      'teskilat_uye'
    );
  else
    raise exception 'Ödeme kaynağı parti veya kendi olmalı.';
  end if;

  insert into oyun.parti_teskilat(
    parti_id, il_id, kurulus, kuran, bedel
  ) values (pa.id, p_il, t, p.id, ucret);

  perform oyun.olay(
    'parti',
    format('%s, %s il teşkilatını açtı.', pa.kisa, ilad),
    p_il::smallint,
    pa.id,
    t
  );

  insert into oyun.bildirimler(user_id, zaman, metin)
  select
    id,
    t,
    format(
      '%s artık %s ilinde teşkilatlı: partin bu ilde milletvekili ve belediye başkanı adayı gösterebilir.',
      pa.kisa,
      ilad
    )
  from oyun.profiller
  where parti_id = pa.id
    and il_id = p_il
    and id <> p.id;

  return oyun.teskilat_json(pa.id, p);
end $$;

create or replace function public.teskilat_ac(p_il int)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select public.teskilat_ac2(p_il, 'parti')
$$;

create or replace function oyun._ayril(u uuid, t timestamptz)
returns void
language plpgsql
set search_path = oyun, public, pg_temp
as $$
declare
  pid bigint := (select parti_id from oyun.profiller where id = u);
begin
  if pid is null then return; end if;

  delete from oyun.adaylar a
  using oyun.secimler s
  where a.secim_id = s.id
    and a.user_id = u
    and (
      s.durum = 'bekliyor'
      or (
        s.tur = 'mv_on'
        and exists(
          select 1 from oyun.secimler m
          where m.tur = 'mv'
            and m.donem = s.donem
            and m.durum = 'bekliyor'
        )
      )
    );

  delete from oyun.cb_kararlar k
  where k.parti_id = pid
    and k.aday = u
    and exists(
      select 1 from oyun.secimler s
      where s.tur = 'cb'
        and s.donem = k.donem
        and s.durum = 'bekliyor'
    );

  update oyun.parti_teskilat_gorev
  set aktif = false
  where parti_id = pid
    and user_id = u
    and aktif;

  update oyun.partiler set gb = null where id = pid and gb = u;
  delete from oyun.parti_gby where user_id = u;
  update oyun.profiller set parti_id = null, parti_at = null where id = u;

  update oyun.partiler
  set kapali = true
  where id = pid
    and not sistem
    and not exists(
      select 1 from oyun.profiller where parti_id = pid
    );

  perform oyun.ittifak_temizle();
end $$;

create or replace function public.il_degistir(p_il integer)
returns jsonb
language plpgsql
security definer
set search_path = oyun, public, pg_temp
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  gun int := oyun.il_bekleme_gun(t);
  kn text;
  ucret numeric;
begin
  if not exists(select 1 from oyun.iller where id = p_il) then
    raise exception 'Geçersiz il.';
  end if;
  if p.il_id = p_il then
    raise exception 'Zaten bu ildesin.';
  end if;

  kn := oyun.il_kilit_nedeni(t);
  if kn is not null then raise exception '%', kn; end if;

  if p.son_il_degis is not null
     and p.son_il_degis + make_interval(days => gun) > t then
    raise exception 'İl en fazla % günde bir değiştirilebilir. Bir sonraki: %',
      gun,
      to_char(
        (p.son_il_degis + make_interval(days => gun)) at time zone 'Europe/Istanbul',
        'DD.MM.YYYY HH24:MI'
      );
  end if;

  if exists(
    select 1 from oyun.makamlar
    where user_id = p.id
      and bit is null
      and tur in ('mv','bel')
  ) then
    raise exception 'Görevdeki vekil veya belediye başkanı il değiştiremez.';
  end if;

  ucret := oyun.tasinma_ucreti(p.il_id, p_il::smallint, t);
  if ucret > 0 then
    perform oyun.para_islem(
      p.id,
      -ucret,
      'tasinma',
      format(
        'Taşınma: %s → %s',
        (select ad from oyun.iller where id = p.il_id),
        (select ad from oyun.iller where id = p_il)
      ),
      t
    );
  end if;

  update oyun.parti_teskilat_gorev
  set aktif = false
  where user_id = p.id
    and aktif
    and il_id <> p_il::smallint;

  update oyun.profiller
  set il_id = p_il,
      il_at = t,
      son_il_degis = t
  where id = p.id;

  return public.durum();
end $$;

create or replace function public.basin()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'kurulus_ucreti', oyun.gazete_kur_ucreti(),
    'benim', (
      select jsonb_build_object(
        'id', g.id,
        'ad', g.ad,
        'slogan', g.slogan,
        'abonelik_ucret', round(g.abonelik_ucret),
        'kasa', round(g.kasa),
        'abone', (
          select count(*) from oyun.gazete_abonelik a
          where a.gazete_id = g.id and a.bitis > t
        ),
        'yazar', (
          select count(*) from oyun.gazete_yazarlar y
          where y.gazete_id = g.id and y.aktif
        )
      )
      from oyun.oyuncu_gazeteleri g
      where g.sahip = p.id and g.aktif
      limit 1
    ),
    'teklifler', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'gazete_id', g.id,
          'ad', g.ad,
          'sahip', oyun.kad(g.sahip),
          'ucret', round(x.ucret_yazi),
          'zaman', x.zaman
        )
        order by x.zaman desc
      )
      from oyun.gazete_yazar_teklif x
      join oyun.oyuncu_gazeteleri g on g.id = x.gazete_id
      where x.user_id = p.id
        and x.durum = 'bekliyor'
        and g.aktif
    ), '[]'::jsonb),
    'gazeteler', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', g.id,
          'ad', g.ad,
          'slogan', g.slogan,
          'sahip', oyun.kad(g.sahip),
          'abonelik_ucret', round(g.abonelik_ucret),
          'abone', (
            select count(*) from oyun.gazete_abonelik a
            where a.gazete_id = g.id and a.bitis > t
          ),
          'abonem', exists(
            select 1 from oyun.gazete_abonelik a
            where a.gazete_id = g.id
              and a.user_id = p.id
              and a.bitis > t
          ),
          'yaziyim', exists(
            select 1 from oyun.gazete_yazarlar y
            where y.gazete_id = g.id
              and y.user_id = p.id
              and y.aktif
          ),
          'son', (
            select jsonb_build_object(
              'baslik', y.baslik,
              'tur', y.tur,
              'zaman', y.zaman
            )
            from oyun.gazete_yayinlari y
            where y.gazete_id = g.id
            order by y.zaman desc, y.id desc
            limit 1
          )
        )
        order by (
          select count(*) from oyun.gazete_abonelik a
          where a.gazete_id = g.id and a.bitis > t
        ) desc,
        g.kurulus
      )
      from oyun.oyuncu_gazeteleri g
      where g.aktif
    ), '[]'::jsonb)
  );
end $$;

create or replace function public.gazete_detay(p_gazete bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  g oyun.oyuncu_gazeteleri;
  er boolean;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;

  er := oyun.gazete_erisim(g.id, p.id, t);

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
end $$;

create or replace function public.gazete_kur(
  p_ad text,
  p_slogan text,
  p_abonelik numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  ucret numeric := oyun.gazete_kur_ucreti();
  gid bigint;
  azami numeric := (
    select gazete_max_abonelik from oyun.ayarlar where id = 1
  );
  ab numeric := round(coalesce(p_abonelik, 0));
begin
  p_ad := btrim(regexp_replace(coalesce(p_ad, ''), '\s+', ' ', 'g'));
  p_slogan := btrim(coalesce(p_slogan, ''));

  if char_length(p_ad) < 4 or char_length(p_ad) > 40 then
    raise exception 'Gazete adı 4-40 karakter olmalı.';
  end if;
  if char_length(p_slogan) > 100 then
    raise exception 'Slogan en fazla 100 karakter olabilir.';
  end if;
  if ab < 0 or ab > azami then
    raise exception 'Aylık abonelik 0-% ₺ arasında olmalı.', oyun.tl(azami);
  end if;

  if exists(
    select 1 from oyun.oyuncu_gazeteleri
    where sahip = p.id and aktif
  ) then
    raise exception 'Zaten aktif bir gazeten var.';
  end if;

  if exists(
    select 1 from oyun.oyuncu_gazeteleri
    where aktif and lower(ad) = lower(p_ad)
  ) then
    raise exception 'Bu gazete adı kullanılıyor.';
  end if;

  perform oyun.para_islem(
    p.id,
    -ucret,
    'gazete_kur',
    format('%s gazetesini kurdu', p_ad),
    t
  );

  insert into oyun.oyuncu_gazeteleri(
    ad, slogan, sahip, abonelik_ucret, kurulus
  ) values (
    p_ad, p_slogan, p.id, ab, t
  )
  returning id into gid;

  insert into oyun.gazete_hareket(
    gazete_id, zaman, tutar, tur, aciklama
  ) values (
    gid, t, 0, 'kurulus', format('%s tarafından kuruldu', p.kad)
  );

  return public.gazete_detay(gid);
end $$;

create or replace function public.gazete_abone_ol(p_gazete bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  g oyun.oyuncu_gazeteleri;
  gun int;
  eski timestamptz;
  yeni timestamptz;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif
  for update;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;
  if g.sahip = p.id then
    raise exception 'Kendi gazetene abone olmana gerek yok.';
  end if;
  if g.abonelik_ucret <= 0 then
    raise exception 'Bu gazete ücretsiz.';
  end if;

  gun := (select gazete_abone_gun from oyun.ayarlar where id = 1);

  select bitis into eski
  from oyun.gazete_abonelik
  where gazete_id = g.id and user_id = p.id
  for update;

  yeni := greatest(coalesce(eski, t), t) + make_interval(days => gun);

  perform oyun.para_islem(
    p.id,
    -g.abonelik_ucret,
    'gazete_abone',
    format('%s · %s günlük abonelik', g.ad, gun),
    t
  );

  update oyun.oyuncu_gazeteleri
  set kasa = kasa + g.abonelik_ucret
  where id = g.id;

  insert into oyun.gazete_abonelik(
    gazete_id, user_id, baslangic, bitis, toplam_odeme
  ) values (
    g.id, p.id, t, yeni, g.abonelik_ucret
  )
  on conflict(gazete_id, user_id) do update
  set bitis = excluded.bitis,
      toplam_odeme = oyun.gazete_abonelik.toplam_odeme + excluded.toplam_odeme;

  insert into oyun.gazete_hareket(
    gazete_id, zaman, tutar, tur, aciklama
  ) values (
    g.id, t, g.abonelik_ucret, 'abonelik',
    format('%s abonelik ödedi', p.kad)
  );

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_yazar_teklif(
  p_gazete bigint,
  p_kad text,
  p_ucret numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  h oyun.profiller;
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
  u numeric := round(coalesce(p_ucret, 0));
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.sahip is distinct from p.id then
    raise exception 'Yazar teklifini yalnızca gazete sahibi verebilir.';
  end if;

  h := oyun.profil_bul(p_kad);
  if h.id = p.id then
    raise exception 'Kendine yazar teklifi veremezsin.';
  end if;
  if u < 0 or u > 10000 then
    raise exception 'Yazı başı ücret 0-10.000 ₺ olmalı.';
  end if;

  insert into oyun.gazete_yazar_teklif(
    gazete_id, user_id, teklif_eden, ucret_yazi, durum, zaman, yanit
  ) values (
    g.id, h.id, p.id, u, 'bekliyor', t, null
  )
  on conflict(gazete_id, user_id) do update
  set teklif_eden = excluded.teklif_eden,
      ucret_yazi = excluded.ucret_yazi,
      durum = 'bekliyor',
      zaman = excluded.zaman,
      yanit = null;

  perform oyun.bildir(
    h.id,
    format(
      '%s gazetesi sana yazı başına %s ₺ ile köşe yazarlığı teklif etti.',
      g.ad,
      oyun.tl(u)
    ),
    t
  );

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_yazar_yanit(
  p_gazete bigint,
  p_kabul boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  x oyun.gazete_yazar_teklif;
  t timestamptz := oyun.simdi();
  s uuid;
begin
  select * into x
  from oyun.gazete_yazar_teklif
  where gazete_id = p_gazete
    and user_id = p.id
    and durum = 'bekliyor'
  for update;

  if x.gazete_id is null then
    raise exception 'Bekleyen yazar teklifin yok.';
  end if;

  update oyun.gazete_yazar_teklif
  set durum = case when p_kabul then 'kabul' else 'ret' end,
      yanit = t
  where gazete_id = p_gazete
    and user_id = p.id;

  if p_kabul then
    insert into oyun.gazete_yazarlar(
      gazete_id, user_id, ucret_yazi, baslangic, aktif
    ) values (
      p_gazete, p.id, x.ucret_yazi, t, true
    )
    on conflict(gazete_id, user_id) do update
    set ucret_yazi = excluded.ucret_yazi,
        baslangic = excluded.baslangic,
        aktif = true;
  end if;

  select sahip into s
  from oyun.oyuncu_gazeteleri
  where id = p_gazete;

  if s is not null then
    perform oyun.bildir(
      s,
      format(
        '%s köşe yazarlığı teklifini %s.',
        p.kad,
        case when p_kabul then 'kabul etti' else 'reddetti' end
      ),
      t
    );
  end if;

  return public.basin();
end $$;

create or replace function public.gazete_yazar_cikar(
  p_gazete bigint,
  p_kad text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  h oyun.profiller;
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.sahip is distinct from p.id then
    raise exception 'Bu işlemi yalnızca gazete sahibi yapabilir.';
  end if;

  h := oyun.profil_bul(p_kad);

  update oyun.gazete_yazarlar
  set aktif = false
  where gazete_id = g.id
    and user_id = h.id
    and aktif;

  if found then
    perform oyun.bildir(
      h.id,
      format('%s gazetesindeki köşe yazarlığın sona erdi.', g.ad),
      t
    );
  end if;

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_yayinla(
  p_gazete bigint,
  p_tur text,
  p_baslik text,
  p_metin text,
  p_hedef_parti bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
  u numeric := 0;
  gunluk int := (
    select gazete_gunluk_yayin from oyun.ayarlar where id = 1
  );
  hedef_kisa text;
  ozet text;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif
  for update;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;

  if g.sahip is distinct from p.id then
    select ucret_yazi into u
    from oyun.gazete_yazarlar
    where gazete_id = g.id
      and user_id = p.id
      and aktif;

    if u is null then
      raise exception 'Bu gazetede yazı yayımlama yetkin yok.';
    end if;
  end if;

  if (
    select count(*)
    from oyun.gazete_yayinlari
    where gazete_id = g.id
      and zaman >= oyun.bugun_bas(t)
  ) >= gunluk then
    raise exception 'Gazetenin bugünkü yayın sınırı doldu (% yazı).', gunluk;
  end if;

  if p_tur not in ('haber','kose','propaganda') then
    raise exception 'Yayın türü geçersiz.';
  end if;

  p_baslik := btrim(coalesce(p_baslik, ''));
  p_metin := btrim(coalesce(p_metin, ''));

  if char_length(p_baslik) < 4 or char_length(p_baslik) > 100 then
    raise exception 'Başlık 4-100 karakter olmalı.';
  end if;
  if char_length(p_metin) < 20 or char_length(p_metin) > 5000 then
    raise exception 'Yazı 20-5000 karakter olmalı.';
  end if;

  if p_tur = 'propaganda' then
    select kisa into hedef_kisa
    from oyun.partiler
    where id = p_hedef_parti and not kapali;

    if hedef_kisa is null then
      raise exception 'Propaganda yazısında hedef parti seçmelisin.';
    end if;
  else
    p_hedef_parti := null;
  end if;

  if u > 0 then
    if g.kasa < u then
      raise exception 'Gazete kasasında yazar ücretini ödeyecek kadar para yok (% ₺ gerekli).',
                      oyun.tl(u);
    end if;

    update oyun.oyuncu_gazeteleri
    set kasa = kasa - u
    where id = g.id;

    insert into oyun.gazete_hareket(
      gazete_id, zaman, tutar, tur, aciklama
    ) values (
      g.id, t, -u, 'yazar_ucreti', format('%s yazı ücreti', p.kad)
    );

    perform oyun.para_islem(
      p.id, u, 'gazete_yazar', format('%s yazı ücreti', g.ad), t
    );
  end if;

  insert into oyun.gazete_yayinlari(
    gazete_id, yazar, tur, baslik, metin, hedef_parti, zaman
  ) values (
    g.id, p.id, p_tur, p_baslik, p_metin, p_hedef_parti, t
  );

  insert into oyun.bildirimler(user_id, zaman, metin)
  select
    a.user_id,
    t,
    format('%s: “%s” yayımlandı.', g.ad, p_baslik)
  from oyun.gazete_abonelik a
  where a.gazete_id = g.id
    and a.bitis > t
    and a.user_id <> p.id;

  if p_tur = 'propaganda' then
    ozet := oyun.metin_temizle(
      format(
        E'📰 %s · PROPAGANDA · %s\n%s\n%s',
        g.ad,
        hedef_kisa,
        p_baslik,
        p_metin
      ),
      600
    );

    insert into oyun.yayinlar(
      tur, gonderen, metin, zaman, hedef_il,
      hedef_parti, secim_id, unvan, gizli
    ) values (
      'sistem',
      p.id,
      ozet,
      t,
      null,
      null,
      null,
      'Oyuncu gazetesi · propaganda',
      false
    );
  end if;

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_para_cek(
  p_gazete bigint,
  p_miktar numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
  m numeric := round(coalesce(p_miktar, 0));
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif
  for update;

  if g.sahip is distinct from p.id then
    raise exception 'Gazete kasasını yalnızca sahibi kullanabilir.';
  end if;
  if m < 100 then raise exception 'En az 100 ₺ çekebilirsin.'; end if;
  if g.kasa < m then raise exception 'Gazete kasasında yeterli para yok.'; end if;

  update oyun.oyuncu_gazeteleri
  set kasa = kasa - m
  where id = g.id;

  insert into oyun.gazete_hareket(
    gazete_id, zaman, tutar, tur, aciklama
  ) values (
    g.id, t, -m, 'cekme', format('%s kasadan çekti', p.kad)
  );

  perform oyun.para_islem(
    p.id, m, 'gazete_gelir', format('%s gazete geliri', g.ad), t
  );

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_ayar(
  p_gazete bigint,
  p_slogan text,
  p_abonelik numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  g oyun.oyuncu_gazeteleri;
  azami numeric := (
    select gazete_max_abonelik from oyun.ayarlar where id = 1
  );
  ab numeric := round(coalesce(p_abonelik, 0));
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.sahip is distinct from p.id then
    raise exception 'Gazete ayarlarını yalnızca sahibi değiştirebilir.';
  end if;

  if char_length(coalesce(p_slogan, '')) > 100 then
    raise exception 'Slogan en fazla 100 karakter olabilir.';
  end if;

  if ab < 0 or ab > azami then
    raise exception 'Abonelik 0-% ₺ arasında olmalı.', oyun.tl(azami);
  end if;

  update oyun.oyuncu_gazeteleri
  set slogan = btrim(coalesce(p_slogan, '')),
      abonelik_ucret = ab
  where id = g.id;

  return public.gazete_detay(g.id);
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'teskilat_gorev_ver(int,text)',
    'teskilat_gorev_al(int)',
    'teskilat_ac2(int,text)',
    'basin()',
    'gazete_detay(bigint)',
    'gazete_kur(text,text,numeric)',
    'gazete_abone_ol(bigint)',
    'gazete_yazar_teklif(bigint,text,numeric)',
    'gazete_yazar_yanit(bigint,boolean)',
    'gazete_yazar_cikar(bigint,text)',
    'gazete_yayinla(bigint,text,text,text,bigint)',
    'gazete_para_cek(bigint,numeric)',
    'gazete_ayar(bigint,text,numeric)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
-- =====================================================================
-- SEÇİM SİMÜLASYONU ONLINE — 18) İSTİFA + OLAĞANÜSTÜ SEÇİMLER
-- Canlı Supabase sürümü: 2026.10.07-5
-- Bu dosya canlı fonksiyonlarla eşitlenmiştir; oyuncu verisini silmez.
-- =====================================================================

alter table oyun.secimler add column if not exists ara boolean not null default false;
alter table oyun.secimler add column if not exists hedef_parti_id bigint references oyun.partiler(id);
alter table oyun.secimler add column if not exists hedef_il_id smallint references oyun.iller(id);
alter table oyun.secimler add column if not exists ara_neden text;

create index if not exists secimler_ara_hedef_parti
  on oyun.secimler(hedef_parti_id, durum, goreve_bas) where ara;
create index if not exists secimler_ara_hedef_il
  on oyun.secimler(hedef_il_id, durum, goreve_bas) where ara;

CREATE OR REPLACE FUNCTION oyun._sonuc_cb(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  toplam bigint;
  n int;
  birinci record;
  ikinci record;
  t2 oyun.secimler;
  gun date := (s.oy_bas at time zone 'Europe/Istanbul')::date;
  adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);

  select count(*) into toplam
  from oyun.oylar
  where secim_id = s.id;

  select count(*) into n
  from oyun.adaylar
  where secim_id = s.id;

  select coalesce(
    jsonb_agg(
      oyun.aday_json(a.id)
      order by a.oy desc, a.basvuru_at
    ),
    '[]'::jsonb
  )
  into adaylar_j
  from oyun.adaylar a
  where a.secim_id = s.id;

  if n = 0 then
    perform oyun.olay(
      'secim',
      'Cumhurbaşkanlığı seçiminde aday yoktu; makam boş kalacak.',
      null, null, s.sonuc_at
    );

    return jsonb_build_object(
      'toplam', toplam,
      'adaylar', adaylar_j,
      'ikinci_tur', false
    );
  end if;

  select * into birinci
  from oyun.adaylar
  where secim_id = s.id
  order by oy desc, basvuru_at, id
  limit 1;

  if n = 1 or (toplam > 0 and birinci.oy * 2 > toplam) then
    insert into oyun.kazananlar
    values (s.id, birinci.user_id, null, birinci.parti_id)
    on conflict do nothing;

    perform oyun.olay(
      'secim',
      format(
        'Cumhurbaşkanı ilk turda seçildi: %s (%%%s).',
        (select kad from oyun.profiller where id = birinci.user_id),
        case
          when toplam > 0 then round(birinci.oy * 100.0 / toplam,1)
          else 100
        end
      ),
      null, birinci.parti_id, s.sonuc_at
    );

    return jsonb_build_object(
      'toplam', toplam,
      'adaylar', adaylar_j,
      'ikinci_tur', false,
      'kazanan', oyun.aday_json(birinci.id)
    );
  end if;

  select * into ikinci
  from oyun.adaylar
  where secim_id = s.id
    and id <> birinci.id
  order by oy desc, basvuru_at, id
  limit 1;

  insert into oyun.secimler(
    tur, donem, oy_bas, oy_bit, sonuc_at, goreve_bas,
    ara, ara_neden
  )
  values (
    'cb2',
    s.donem,
    oyun.tr_an(gun+1,8),
    oyun.tr_an(gun+1,17),
    oyun.tr_an(gun+1,18),
    oyun.tr_an(gun+2,0),
    s.ara,
    s.ara_neden
  )
  on conflict(tur,donem) do nothing
  returning * into t2;

  if t2.id is not null then
    insert into oyun.adaylar(
      secim_id,user_id,parti_id,il_id,basvuru_at,vaat
    )
    values
      (
        t2.id,birinci.user_id,birinci.parti_id,null,
        birinci.basvuru_at,birinci.vaat
      ),
      (
        t2.id,ikinci.user_id,ikinci.parti_id,null,
        ikinci.basvuru_at,ikinci.vaat
      );
  end if;

  perform oyun.olay(
    'secim',
    format(
      'Cumhurbaşkanlığı seçimi ikinci tura kaldı: %s ve %s yarın sandıkta.',
      (select kad from oyun.profiller where id = birinci.user_id),
      (select kad from oyun.profiller where id = ikinci.user_id)
    ),
    null, null, s.sonuc_at
  );

  return jsonb_build_object(
    'toplam', toplam,
    'adaylar', adaylar_j,
    'ikinci_tur', true
  );
end $function$

CREATE OR REPLACE FUNCTION oyun.ara_secim_olustur(p_tur text, p_parti bigint, p_il smallint, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  ilk_gun date;
  ikinci_gun date;
  o oyun.secimler;
  dm text;
  on_id bigint;
  asil_id bigint;
  asil_bas timestamptz;
begin
  if p_tur not in ('gb','cb','bel') then
    raise exception 'Geçersiz ara seçim türü.';
  end if;

  -- En yakın makul pencere: adaylık süresi en az yaklaşık 8 saat olsun.
  ilk_gun := (t at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(ilk_gun, 8) < t + interval '8 hours' then
    ilk_gun := ilk_gun + 1;
  end if;
  ikinci_gun := ilk_gun + 1;

  if p_tur = 'gb' then
    if p_parti is null then
      raise exception 'Genel başkan ara seçimi için parti gerekli.';
    end if;

    select * into o
    from oyun.secimler
    where tur = 'kurultay'
      and ara
      and hedef_parti_id = p_parti
      and durum <> 'tamam'
      and coalesce(goreve_bas, sonuc_at) > t
    order by coalesce(goreve_bas, sonuc_at)
    limit 1;

    if o.id is not null then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'kurultay', 'ara', true, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    asil_bas := oyun.tr_an(ilk_gun, 19);

    -- Zaten bundan daha erken bitecek olağan kurultay varsa ikinci seçim yaratma.
    select * into o
    from oyun.secimler
    where tur = 'kurultay'
      and not ara
      and durum <> 'tamam'
      and goreve_bas > t
    order by goreve_bas
    limit 1;

    if o.id is not null and o.goreve_bas <= asil_bas then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'kurultay', 'ara', false, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    dm := 'ara-gb-' || p_parti || '-' ||
          to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, hedef_parti_id, ara_neden
    ) values (
      'kurultay', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,17),
      oyun.tr_an(ilk_gun,18), asil_bas,
      true, p_parti, 'genel_baskan_istifa'
    )
    returning id into asil_id;

    return jsonb_build_object(
      'secim_id', asil_id, 'tur', 'kurultay', 'ara', true, 'mevcut', false,
      'oy_bas', oyun.tr_an(ilk_gun,8), 'goreve_bas', asil_bas
    );

  elsif p_tur = 'bel' then
    if p_il is null then
      raise exception 'Belediye ara seçimi için il gerekli.';
    end if;

    select * into o
    from oyun.secimler
    where tur = 'bel'
      and ara
      and hedef_il_id = p_il
      and durum <> 'tamam'
      and coalesce(goreve_bas, sonuc_at) > t
    order by coalesce(goreve_bas, sonuc_at)
    limit 1;

    if o.id is not null then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'bel', 'ara', true, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    asil_bas := oyun.tr_an(ikinci_gun, 19);

    -- Yaklaşan olağan belediye seçimi daha erken başkan çıkaracaksa onu kullan.
    select * into o
    from oyun.secimler
    where tur = 'bel'
      and not ara
      and durum <> 'tamam'
      and goreve_bas > t
    order by goreve_bas
    limit 1;

    if o.id is not null and o.goreve_bas <= asil_bas then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'bel', 'ara', false, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    dm := 'ara-bel-' || p_il || '-' ||
          to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, hedef_il_id, ara_neden
    ) values (
      'bel_on', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,17),
      oyun.tr_an(ilk_gun,18), null,
      true, p_il, 'belediye_baskani_istifa'
    )
    returning id into on_id;

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, hedef_il_id, ara_neden
    ) values (
      'bel', dm,
      null, null,
      oyun.tr_an(ikinci_gun,8), oyun.tr_an(ikinci_gun,17),
      oyun.tr_an(ikinci_gun,18), asil_bas,
      true, p_il, 'belediye_baskani_istifa'
    )
    returning id into asil_id;

    return jsonb_build_object(
      'secim_id', asil_id, 'on_secim_id', on_id,
      'tur', 'bel', 'ara', true, 'mevcut', false,
      'oy_bas', oyun.tr_an(ikinci_gun,8), 'goreve_bas', asil_bas
    );

  else
    select * into o
    from oyun.secimler
    where tur in ('cb','cb2')
      and ara
      and durum <> 'tamam'
      and coalesce(goreve_bas, sonuc_at) > t
    order by coalesce(goreve_bas, sonuc_at)
    limit 1;

    if o.id is not null then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', o.tur, 'ara', true, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    asil_bas := oyun.tr_an(ikinci_gun, 19);

    -- Yaklaşan olağan CB seçimi daha erken sonuç verecekse onu kullan.
    select * into o
    from oyun.secimler
    where tur in ('cb','cb2')
      and not ara
      and durum <> 'tamam'
      and goreve_bas > t
    order by goreve_bas
    limit 1;

    if o.id is not null and o.goreve_bas <= asil_bas then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', o.tur, 'ara', false, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    dm := 'ara-cb-' ||
          to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, ara_neden
    ) values (
      'cb_on', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,17),
      oyun.tr_an(ilk_gun,18), null,
      true, 'cumhurbaskani_istifa'
    )
    returning id into on_id;

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, ara_neden
    ) values (
      'cb', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ikinci_gun,8), oyun.tr_an(ikinci_gun,17),
      oyun.tr_an(ikinci_gun,18), asil_bas,
      true, 'cumhurbaskani_istifa'
    )
    returning id into asil_id;

    return jsonb_build_object(
      'secim_id', asil_id, 'on_secim_id', on_id,
      'tur', 'cb', 'ara', true, 'mevcut', false,
      'oy_bas', oyun.tr_an(ikinci_gun,8), 'goreve_bas', asil_bas
    );
  end if;
end $function$

CREATE OR REPLACE FUNCTION oyun.gb_halef(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  pa record;
  aday uuid;
begin
  for pa in
    select id, ad
    from oyun.partiler
    where not kapali
      and gb is null
      and not exists(
        select 1
        from oyun.secimler s
        where s.tur = 'kurultay'
          and s.ara
          and s.hedef_parti_id = oyun.partiler.id
          and s.durum = 'bekliyor'
      )
  loop
    select pr.id into aday
    from oyun.profiller pr
    where pr.parti_id = pa.id
      and not pr.yasakli
      and not exists(
        select 1
        from oyun.makamlar m
        where m.user_id = pr.id
          and m.bit is null
          and m.tur <> 'cb'
      )
    order by oyun.kidem_puani(pr.id) desc, pr.parti_at, pr.id
    limit 1;

    continue when aday is null;

    delete from oyun.parti_gby where user_id = aday;
    update oyun.partiler
    set gb = aday
    where id = pa.id and gb is null;

    perform oyun.bildir(
      aday,
      format(
        '%s kurultayda genel başkansız kaldığı için kıdemin en yüksek olduğu üye olarak genel başkan oldun. Bir sonraki kurultayda üyeler genel başkanı yeniden seçecek; 6 genel başkan yardımcını atayabilirsin.',
        pa.ad
      ),
      t
    );

    perform oyun.olay(
      'parti',
      format(
        '%s genel başkansız kaldı; kıdemi en yüksek üye %s genel başkan oldu.',
        pa.ad,
        (select kad from oyun.profiller where id = aday)
      ),
      null, pa.id, t
    );
  end loop;
end $function$

CREATE OR REPLACE FUNCTION oyun.oy_engeli(p oyun.profiller, s oyun.secimler)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce(
    oyun.uyari(p, s.oy_bas),

    case
      when s.ara
       and s.hedef_il_id is not null
       and p.il_id is distinct from s.hedef_il_id
      then format(
        'Bu olağanüstü seçim yalnızca %s ili içindir.',
        (select ad from oyun.iller where id = s.hedef_il_id)
      )
    end,

    case
      when s.ara
       and s.hedef_parti_id is not null
       and p.parti_id is distinct from s.hedef_parti_id
      then format(
        'Bu olağanüstü kurultay yalnızca %s üyeleri içindir.',
        (select kisa from oyun.partiler where id = s.hedef_parti_id)
      )
    end,

    case
      when s.tur in ('mv','bel','mv_on','bel_on')
       and p.il_at > s.oy_bas - make_interval(
         days => (select oy_il_gun from oyun.ayarlar where id = 1)
       )
      then format(
        'Seçmen kütüğü: bu ilde oy kullanabilmek için seçimden en az %s gün önce bu ile kayıtlı olmalısın.',
        (select oy_il_gun from oyun.ayarlar where id = 1)
      )
    end,

    case
      when s.tur in ('mv_on','bel_on','kurultay','cb_on') then
        case
          when p.parti_id is null
            then 'Bu parti içi seçimde oy için bir partiye üye olmalısın.'
          when p.parti_at > s.basvuru_bas
            then 'Parti içi seçimde oy için başvurular açılmadan önce üye olmuş olmalısın.'
        end
    end
  )
$function$

CREATE OR REPLACE FUNCTION oyun.push_hatirlatmalar(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  s oyun.secimler;
  pid bigint;
  v jsonb;
  kosul text;
begin
  if not oyun.push_acik() then return; end if;

  -- Başvuru açılışları
  for s in
    select *
    from oyun.secimler
    where durum = 'bekliyor'
      and basvuru_bas is not null
      and t >= basvuru_bas
      and t < basvuru_bit
      and tur in ('bel_on','mv_on','kurultay')
      and not (hatirlatma ? 'basvuru')
  loop
    v := jsonb_build_object('ekran','gundem');

    if s.ara and s.tur = 'bel_on' and s.hedef_il_id is not null then
      perform oyun.push_konuya(
        's_il_' || s.hedef_il_id,
        null,
        'Olağanüstü belediye seçimi',
        format('%s için belediye başkanlığı aday adaylığı başvuruları açıldı.',
               (select ad from oyun.iller where id = s.hedef_il_id)),
        v
      );
    elsif s.ara and s.tur = 'kurultay' and s.hedef_parti_id is not null then
      perform oyun.push_konuya(
        's_parti_' || s.hedef_parti_id,
        null,
        'Olağanüstü kurultay',
        'Genel başkan istifası sonrası adaylık başvuruları açıldı.',
        v
      );
    else
      perform oyun.push_konuya(
        's_tum',
        null,
        'Başvurular açıldı',
        case s.tur
          when 'bel_on' then 'Belediye başkanlığı aday adaylığı başvuruları bugün açık. Adayını çıkar!'
          when 'mv_on' then 'Milletvekili aday adaylığı başvuruları bugün açık. Listeye girmek için başvur!'
          else 'Genel başkanlık başvuruları açıldı. Kurultay ayın 18''inde.'
        end,
        v
      );
    end if;

    update oyun.secimler
    set hatirlatma = hatirlatma || '{"basvuru":true}'
    where id = s.id;
  end loop;

  -- Sandık açılışları
  for s in
    select *
    from oyun.secimler
    where durum = 'bekliyor'
      and t >= oy_bas
      and t < oy_bit
      and not (hatirlatma ? 'oy')
  loop
    v := jsonb_build_object('ekran','secim','id',s.id);

    if s.tur = 'mv' then
      perform oyun.push_konuya(
        's_tum', null,
        'Bugün seçim var! 🗳️',
        'Genel seçim ve cumhurbaşkanlığı seçimi sandıkları 17:00''ye kadar açık.',
        v
      );

    elsif s.tur in ('cb','cb2') then
      perform oyun.push_konuya(
        's_tum', null,
        case when s.tur = 'cb2' then 'Cumhurbaşkanlığı 2. turu'
             when s.ara then 'Olağanüstü cumhurbaşkanlığı seçimi'
             else 'Cumhurbaşkanlığı seçimi' end,
        'Sandıklar 17:00''de kapanıyor. Oyunu kullanmayı unutma!',
        v
      );

    elsif s.tur = 'bel' then
      if s.ara and s.hedef_il_id is not null then
        perform oyun.push_konuya(
          's_il_' || s.hedef_il_id,
          null,
          'Olağanüstü belediye seçimi 🗳️',
          format('%s belediye başkanlığı sandığı 17:00''ye kadar açık.',
                 (select ad from oyun.iller where id = s.hedef_il_id)),
          v
        );
      else
        perform oyun.push_konuya(
          's_tum', null,
          'Bugün belediye seçimi var! 🗳️',
          'İl belediye başkanlığı sandıkları 17:00''ye kadar açık.',
          v
        );
      end if;

    elsif s.tur in ('bel_on','mv_on','kurultay','cb_on') then
      if s.ara and s.tur = 'kurultay' and s.hedef_parti_id is not null then
        perform oyun.push_konuya(
          's_parti_' || s.hedef_parti_id,
          null,
          'Olağanüstü kurultay başladı',
          'Yeni genel başkanı seçmek için oyunu 17:00''ye kadar kullan.',
          v
        );
      elsif s.ara and s.tur = 'bel_on' and s.hedef_il_id is not null then
        for pid in
          select distinct parti_id
          from oyun.adaylar
          where secim_id = s.id and parti_id is not null
        loop
          kosul := format(
            '''s_parti_%s'' in topics && ''s_il_%s'' in topics',
            pid, s.hedef_il_id
          );
          perform oyun.push_konuya(
            's_tum',
            kosul,
            'Partinde olağanüstü ön seçim var',
            format('%s belediye başkanı ön seçimi 17:00''ye kadar.',
                   (select ad from oyun.iller where id = s.hedef_il_id)),
            v
          );
        end loop;
      else
        for pid in
          select distinct parti_id
          from oyun.adaylar
          where secim_id = s.id and parti_id is not null
        loop
          perform oyun.push_konuya(
            's_parti_' || pid,
            null,
            'Partinde seçim var',
            case s.tur
              when 'bel_on' then 'Belediye başkanı ön seçimi bugün 17:00''ye kadar.'
              when 'mv_on' then 'Milletvekili ön seçimi bugün 17:00''ye kadar. Liste sırasını sen belirle!'
              when 'cb_on' then 'Cumhurbaşkanı aday ön seçimi bugün 17:00''ye kadar.'
              else 'Kurultay bugün! Genel başkanını seç.'
            end,
            v
          );
        end loop;
      end if;
    end if;

    update oyun.secimler
    set hatirlatma = hatirlatma || '{"oy":true}'
    where id = s.id;
  end loop;

  -- Sonuçlar
  for s in
    select *
    from oyun.secimler
    where durum <> 'bekliyor'
      and tur in ('mv','bel','cb','cb2')
      and t >= sonuc_at
      and t < sonuc_at + interval '3 hours'
      and not (hatirlatma ? 'sonuc')
  loop
    if s.tur <> 'cb' then
      if s.ara and s.tur = 'bel' and s.hedef_il_id is not null then
        perform oyun.push_konuya(
          's_il_' || s.hedef_il_id,
          null,
          'Olağanüstü seçim sonucu',
          format('%s belediye başkanlığı seçiminin sonucu açıklandı.',
                 (select ad from oyun.iller where id = s.hedef_il_id)),
          jsonb_build_object('ekran','secim','id',s.id)
        );
      else
        perform oyun.push_konuya(
          's_tum',
          null,
          'Sonuçlar açıklandı',
          case s.tur
            when 'mv' then 'Genel seçim ve cumhurbaşkanlığı sonuçları açıklandı. Meclis''in yeni dağılımını gör!'
            when 'bel' then 'Belediye seçimi sonuçları açıklandı. İlini kim kazandı?'
            else 'Cumhurbaşkanlığı ikinci tur sonucu açıklandı.'
          end,
          jsonb_build_object('ekran','secim','id',s.id)
        );
      end if;
    end if;

    update oyun.secimler
    set hatirlatma = hatirlatma || '{"sonuc":true}'
    where id = s.id;
  end loop;

  perform oyun.kumbara_hatirlat(t);
end $function$

CREATE OR REPLACE FUNCTION oyun.secim_ozet(s oyun.secimler, p oyun.profiller, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'id', s.id,
    'tur', s.tur,
    'donem', s.donem,
    'asama', oyun.asama(s,t),
    'basvuru_bas', s.basvuru_bas,
    'basvuru_bit', s.basvuru_bit,
    'oy_bas', s.oy_bas,
    'oy_bit', s.oy_bit,
    'sonuc_at', s.sonuc_at,
    'goreve_bas', s.goreve_bas,
    'ara', s.ara,
    'hedef_il_id', s.hedef_il_id,
    'hedef_il_ad', (select ad from oyun.iller where id = s.hedef_il_id),
    'hedef_parti_id', s.hedef_parti_id,
    'hedef_parti', oyun.parti_json(s.hedef_parti_id),
    'ara_neden', s.ara_neden,
    'adayim', exists(
      select 1 from oyun.adaylar a
      where a.secim_id = s.id and a.user_id = p.id
    ),
    'oy_verdim', exists(
      select 1 from oyun.oylar o
      where o.secim_id = s.id and o.secmen = p.id
    ),
    'oy_engeli', oyun.oy_engeli(p,s),
    'katilim', case
      when s.durum <> 'bekliyor' or t >= s.oy_bas
      then (select count(*) from oyun.oylar o where o.secim_id = s.id)
    end
  )
$function$

CREATE OR REPLACE FUNCTION oyun.tbmm_ara_secim(t timestamp with time zone)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare sid bigint;
begin
  select id into sid
  from oyun.meclis_secim
  where tur = 'baskan' and durum <> 'bitti'
  order by id desc
  limit 1;

  if sid is null then
    insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit)
    values (null, 'baskan', t, t + interval '24 hours')
    returning id into sid;

    perform oyun.olay(
      'meclis',
      'TBMM Başkanlığı boşaldı. Ara seçim için adaylık 24 saat açık.',
      null, null, t
    );
  end if;

  return sid;
end $function$

CREATE OR REPLACE FUNCTION public.aday_ol(p_tur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  k oyun.cb_kararlar;
begin
  if p_tur not in ('mv_on','bel_on','kurultay','cb_on') then
    raise exception 'Geçersiz adaylık türü.';
  end if;

  select * into s
  from oyun.secimler
  where tur = p_tur
    and t >= basvuru_bas
    and t < basvuru_bit
    and (
      not ara
      or (p_tur = 'bel_on' and hedef_il_id = p.il_id)
      or (p_tur = 'kurultay' and hedef_parti_id = p.parti_id)
      or p_tur = 'cb_on'
    )
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Bu adaylık için başvuru şu anda açık değil.';
  end if;
  if p.parti_id is null then
    raise exception 'Aday olmak için bir partiye üye olmalısın.';
  end if;
  if p.parti_at > s.basvuru_bas then
    raise exception 'Bu dönem aday olabilmek için başvurular açılmadan önce partiye üye olmalıydın.';
  end if;
  if oyun.uyari(p,t) is not null then
    raise exception '%', oyun.uyari(p,t);
  end if;
  if (select kurulus_bit from oyun.partiler where id = p.parti_id) is not null then
    raise exception 'Partin henüz kuruluş aşamasında: kurucu üye sayısı tamamlanmadan seçime katılamaz.';
  end if;

  if s.ara and s.hedef_il_id is not null
     and p.il_id is distinct from s.hedef_il_id then
    raise exception 'Bu ara seçim senin ilin için değil.';
  end if;

  if s.ara and s.hedef_parti_id is not null
     and p.parti_id is distinct from s.hedef_parti_id then
    raise exception 'Bu olağanüstü kurultay senin partin için değil.';
  end if;

  if p_tur in ('mv_on','bel_on')
     and exists(select 1 from oyun.partiler where gb = p.id) then
    raise exception 'Genel başkan milletvekili ya da belediye başkanı adayı olamaz. Genel başkan yalnızca cumhurbaşkanı adayı olabilir.';
  end if;

  if oyun.teskilat_engeli(p,p_tur) is not null then
    raise exception '%', oyun.teskilat_engeli(p,p_tur);
  end if;

  if p_tur = 'cb_on' then
    select * into k
    from oyun.cb_kararlar
    where donem = s.donem and parti_id = p.parti_id;

    if k.yontem in ('kendisi','baskasi') then
      raise exception 'Genel başkan cumhurbaşkanı adayını doğrudan belirledi; ön seçim yapılmayacak.';
    end if;
    if k.yontem = 'destek' then
      raise exception 'Partin cumhurbaşkanlığında ittifak ortağının adayını destekliyor; ön seçim yapılmayacak.';
    end if;
  end if;

  insert into oyun.adaylar(
    secim_id, user_id, parti_id, il_id, basvuru_at
  )
  values (
    s.id, p.id, p.parti_id,
    case when p_tur in ('mv_on','bel_on') then p.il_id end,
    t
  )
  on conflict(secim_id,user_id) do nothing;

  if not found then
    raise exception 'Bu seçime zaten başvurdun.';
  end if;

  perform oyun.aday_ucreti_al(p,p_tur,t);
  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.cb_aday_belirle(p_yontem text, p_kad text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  pa oyun.partiler;
  hedef oyun.profiller;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then
    raise exception 'Bu kararı yalnızca genel başkan verebilir.';
  end if;

  select * into s
  from oyun.secimler
  where tur = 'cb'
    and t >= basvuru_bas
    and t < basvuru_bit
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Cumhurbaşkanı adayı belirleme dönemi şu anda açık değil.';
  end if;

  if p_yontem not in ('kendisi','baskasi','onsecim') then
    raise exception 'Geçersiz yöntem.';
  end if;

  if p_yontem = 'kendisi' then
    hedef := p;
  elsif p_yontem = 'baskasi' then
    select * into hedef
    from oyun.profiller
    where lower(kad) = lower(btrim(coalesce(p_kad,'')));

    if hedef.id is null or hedef.parti_id is distinct from pa.id then
      raise exception 'Aday partinin üyesi olmalı.';
    end if;
  end if;

  if hedef.id is not null and oyun.uyari(hedef,t) is not null then
    raise exception 'Aday için: %', oyun.uyari(hedef,t);
  end if;

  insert into oyun.cb_kararlar(
    donem, parti_id, yontem, aday, zaman
  )
  values (
    s.donem, pa.id, p_yontem, hedef.id, t
  )
  on conflict(donem,parti_id) do update
    set yontem = excluded.yontem,
        aday = excluded.aday,
        destek_parti = null,
        zaman = excluded.zaman;

  delete from oyun.adaylar
  where secim_id = s.id and parti_id = pa.id;

  if hedef.id is not null then
    insert into oyun.adaylar(
      secim_id,user_id,parti_id,basvuru_at
    )
    values (
      s.id,hedef.id,pa.id,t
    );
  end if;

  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.cb_destek(p_parti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  s oyun.secimler;
  hedef oyun.partiler;
begin
  pa := oyun.gb_partim(p);

  select * into s
  from oyun.secimler
  where tur = 'cb'
    and t >= basvuru_bas
    and t < basvuru_bit
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Cumhurbaşkanı adayı belirleme dönemi şu anda açık değil.';
  end if;

  select * into hedef
  from oyun.partiler
  where id = p_parti and not kapali;

  if hedef.id is null or hedef.id = pa.id then
    raise exception 'Geçersiz parti.';
  end if;

  if not exists(
    select 1
    from oyun.ittifak_uyeler a
    join oyun.ittifak_uyeler b on a.ittifak_id = b.ittifak_id
    where a.parti_id = pa.id
      and b.parti_id = hedef.id
  ) then
    raise exception 'Yalnızca ittifak ortağının adayını destekleyebilirsin.';
  end if;

  insert into oyun.cb_kararlar(
    donem, parti_id, yontem, aday, destek_parti, zaman
  )
  values (
    s.donem, pa.id, 'destek', null, hedef.id, t
  )
  on conflict(donem,parti_id) do update
    set yontem = 'destek',
        aday = null,
        destek_parti = excluded.destek_parti,
        zaman = excluded.zaman;

  delete from oyun.adaylar
  where secim_id = s.id and parti_id = pa.id;

  perform oyun.olay(
    'ittifak',
    format(
      '%s, cumhurbaşkanlığı seçiminde %s''nin adayını destekleme kararı aldı.',
      pa.kisa, hedef.kisa
    ),
    null, pa.id, t
  );

  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  u uuid := oyun.ben();
  p oyun.profiller;
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  gun int := oyun.il_bekleme_gun(oyun.simdi());
begin
  select * into p from oyun.profiller where id = u;

  if p.id is null then
    return jsonb_build_object('simdi',t,'profil',null);
  end if;

  if p.yasakli then
    raise exception 'Hesabın kural ihlali nedeniyle kapatıldı. İtiraz için oyun yönetimine e-posta gönderebilirsin.';
  end if;

  if p.son_gorulme is null or p.son_gorulme < t - interval '5 minutes' then
    update oyun.profiller
    set son_gorulme = t
    where id = p.id;
  end if;

  select * into pa
  from oyun.partiler
  where id = p.parti_id;

  return jsonb_build_object(
    'simdi', t,

    'profil', jsonb_build_object(
      'id', p.id,
      'kad', p.kad,
      'il_id', p.il_id,
      'il_ad', (select ad from oyun.iller where id = p.il_id),
      'olusturma', p.olusturma,
      'parti', oyun.parti_json(p.parti_id),
      'parti_at', p.parti_at,
      'gb', pa.gb = p.id,
      'gby', exists(
        select 1 from oyun.parti_gby g where g.user_id = p.id
      ),
      'il_kilit', oyun.il_kilit_nedeni(t),
      'il_serbest', case
        when p.son_il_degis is null then null
        else p.son_il_degis + make_interval(days => gun)
      end,
      'makamlar', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'tur',m.tur,
            'il_id',m.il_id,
            'il_ad',i.ad,
            'bas',m.bas,
            'kaynak',m.kaynak,
            'bakanlik',m.bakanlik,
            'bakanlik_ad',(
              select ad from oyun.bakanliklar b where b.kod = m.bakanlik
            )
          )
        )
        from oyun.makamlar m
        left join oyun.iller i on i.id = m.il_id
        where m.user_id = p.id and m.bit is null
      ), '[]'::jsonb),
      'hesap_engeli', oyun.uyari(p,t),
      'cb_mi', exists(
        select 1 from oyun.makamlar m
        where m.user_id = p.id
          and m.tur = 'cb'
          and m.bit is null
      ),
      'yonetici', p.yonetici,
      'bildirim_ayar', p.bildirim_ayar,
      'yetkiler', oyun.yetkilerim(p.id),
      'kredi_uyari', oyun.kredi_uyari(p.id),
      'cuzdan', oyun.cuzdan_ozet(p.id,t)
    ),

    'okunmamis', oyun.okunmamis(p),

    'takvim', coalesce((
      select jsonb_agg(
        oyun.secim_ozet(s,p,t)
        order by coalesce(s.basvuru_bas,s.oy_bas), oyun.oncelik(s.tur)
      )
      from oyun.secimler s
      where coalesce(s.goreve_bas,s.sonuc_at) >= t - interval '3 days'
        and coalesce(s.basvuru_bas,s.oy_bas) <= t + interval '40 days'
        and (
          not s.ara
          or s.tur in ('cb','cb_on','cb2')
          or s.hedef_il_id = p.il_id
          or s.hedef_parti_id = p.parti_id
        )
    ), '[]'::jsonb),

    'cb', (
      select jsonb_build_object(
        'kad', oyun.kad(m.user_id),
        'parti', oyun.parti_json(m.parti_id),
        'bas', m.bas
      )
      from oyun.makamlar m
      where m.tur = 'cb' and m.bit is null
      limit 1
    ),

    'cb_karar', case
      when pa.gb = p.id then (
        select jsonb_build_object(
          'secim_id',s.id,
          'donem',s.donem,
          'acik',t >= s.basvuru_bas and t < s.basvuru_bit,
          'yontem',k.yontem,
          'aday',oyun.kad(k.aday),
          'son',s.basvuru_bit,
          'destek',(select kisa from oyun.partiler where id = k.destek_parti),
          'ara',s.ara
        )
        from oyun.secimler s
        left join oyun.cb_kararlar k
          on k.donem = s.donem
         and k.parti_id = pa.id
        where s.tur = 'cb'
          and s.durum = 'bekliyor'
        order by s.ara desc, s.oy_bas
        limit 1
      )
    end
  );
end $function$

CREATE OR REPLACE FUNCTION public.genel_baskanlik_uslen()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  c text;
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali
  for update;

  if pa.id is null then
    raise exception 'Önce bir partiye üye olmalısın.';
  end if;
  if pa.gb is not null then
    raise exception 'Partinin genel başkanı var.';
  end if;

  if exists(
    select 1
    from oyun.secimler s
    where s.tur = 'kurultay'
      and s.ara
      and s.hedef_parti_id = pa.id
      and s.durum <> 'tamam'
  ) then
    raise exception 'Genel başkan istifa ettiği için olağanüstü kurultay süreci başladı. Yeni genel başkan seçimle belirlenecek.';
  end if;

  select oyun.rol_ad(r) into c
  from unnest(oyun.roller(p.id)) r
  where r <> 'gby'
    and not oyun.rol_uyumlu(r,'gb')
  limit 1;

  if c is not null then
    raise exception 'Şu anda % görevindesin; genel başkan olmak için önce o görevden istifa etmelisin.', c;
  end if;

  delete from oyun.parti_gby where user_id = p.id;
  update oyun.partiler set gb = p.id where id = pa.id;

  perform oyun.olay(
    'parti',
    format(
      '%s genel başkansız kalan %s partisinin genel başkanlığını üstlendi.',
      p.kad, pa.ad
    ),
    null, pa.id, t
  );

  perform oyun.bildir(
    p.id,
    format(
      '%s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilir, seçim beyannamesini yazabilirsin. Bir sonraki kurultayda üyeler genel başkanı yeniden seçer.',
      pa.ad
    ),
    t
  );

  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.istifa(p_gorev text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  m oyun.makamlar;
  cb uuid;
  pa oyun.partiler;
  sec jsonb;
begin
  if p_gorev = 'bakan' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'bakan' and bit is null;

    if m.id is null then raise exception 'Bakan değilsin.'; end if;

    perform oyun.makam_bitir(m.id,t,'istifa');

    select user_id into cb
    from oyun.makamlar
    where tur = 'cb' and bit is null
    limit 1;

    if cb is not null then
      perform oyun.bildir(
        cb,
        format(
          '%s, %s görevinden istifa etti.',
          p.kad,
          oyun.makam_ad('bakan',null,m.bakanlik)
        ),
        t
      );
    end if;

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti.',
        p.kad,
        oyun.makam_ad('bakan',null,m.bakanlik)
      ),
      null, p.parti_id, t
    );

  elsif p_gorev = 'mv' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'mv' and bit is null;

    if m.id is null then raise exception 'Milletvekili değilsin.'; end if;

    perform oyun.makam_bitir(m.id,t,'istifa');

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti.',
        p.kad,
        oyun.makam_ad(m.tur,m.il_id,null)
      ),
      m.il_id, p.parti_id, t
    );

  elsif p_gorev = 'bel' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'bel' and bit is null
    for update;

    if m.id is null then
      raise exception 'Belediye başkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    sec := oyun.ara_secim_olustur('bel',null,m.il_id,t);

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti. Yeni başkan en yakın seçimde belirlenecek.',
        p.kad,
        oyun.makam_ad(m.tur,m.il_id,null)
      ),
      m.il_id, p.parti_id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      id,
      t,
      format(
        '%s Belediye Başkanı istifa etti. Yeni başkan için seçim takvimi oluşturuldu.',
        (select ad from oyun.iller where id = m.il_id)
      )
    from oyun.profiller
    where il_id = m.il_id and id <> p.id;

  elsif p_gorev = 'cb' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'cb' and bit is null
    for update;

    if m.id is null then
      raise exception 'Cumhurbaşkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    sec := oyun.ara_secim_olustur('cb',null,null,t);

    perform oyun.olay(
      'makam',
      format(
        '%s Cumhurbaşkanlığı görevinden istifa etti. Olağanüstü seçim takvimi oluşturuldu.',
        p.kad
      ),
      null, p.parti_id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      pa2.gb,
      t,
      'Cumhurbaşkanı istifa etti. Olağanüstü seçim için aday belirleme süreci başladı.'
    from oyun.partiler pa2
    where pa2.gb is not null
      and not pa2.kapali
      and pa2.gb <> p.id;

  elsif p_gorev = 'gb' then
    select * into pa
    from oyun.partiler
    where gb = p.id and not kapali
    for update;

    if pa.id is null then
      raise exception 'Genel başkan değilsin.';
    end if;

    update oyun.partiler
    set gb = null
    where id = pa.id;

    sec := oyun.ara_secim_olustur('gb',pa.id,null,t);

    perform oyun.olay(
      'parti',
      format(
        '%s, %s Genel Başkanlığından istifa etti. Olağanüstü kurultay takvimi oluşturuldu.',
        p.kad, pa.ad
      ),
      null, pa.id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      id,
      t,
      format(
        '%s Genel Başkanı istifa etti. Olağanüstü kurultay için adaylık süreci başladı.',
        pa.ad
      )
    from oyun.profiller
    where parti_id = pa.id and id <> p.id;

  elsif p_gorev = 'tbmm' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'tbmm' and bit is null
    for update;

    if m.id is null then
      raise exception 'TBMM Başkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    perform oyun.tbmm_ara_secim(t);

    perform oyun.olay(
      'meclis',
      format(
        '%s TBMM Başkanlığı görevinden istifa etti. Ara seçim süreci başladı.',
        p.kad
      ),
      null, p.parti_id, t
    );

  elsif p_gorev = 'gby' then
    delete from oyun.parti_gby where user_id = p.id;

    if not found then
      raise exception 'Genel başkan yardımcısı değilsin.';
    end if;

    perform oyun.bildir(
      (select gb from oyun.partiler where id = p.parti_id),
      format(
        '%s genel başkan yardımcılığından istifa etti.',
        p.kad
      ),
      t
    );

  else
    raise exception 'Geçersiz görev.';
  end if;

  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.meclis_gorev_birak(p_tur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  m oyun.makamlar;
begin
  select * into m
  from oyun.makamlar
  where user_id = p.id
    and tur = p_tur
    and bit is null
    and tur in ('tbmm','bskv','grup_bskv');

  if m.id is null then
    raise exception 'Bu görevde değilsin.';
  end if;

  perform oyun.makam_bitir(m.id,t,'istifa');

  perform oyun.olay(
    'meclis',
    format(
      '%s, %s görevinden ayrıldı.',
      p.kad,
      oyun.rol_ad(p_tur)
    ),
    null, p.parti_id, t
  );

  if p_tur = 'tbmm' then
    perform oyun.tbmm_ara_secim(t);
  end if;

  return public.meclis_baskanlik();
end $function$

revoke all on function public.istifa(text) from public, anon;
grant execute on function public.istifa(text) to authenticated;
revoke all on function public.meclis_gorev_birak(text) from public, anon;
grant execute on function public.meclis_gorev_birak(text) to authenticated;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 6) YETKİLER
--  Yalnızca giriş yapmış oyuncular bu fonksiyonları çağırabilir.
-- =====================================================================
-- ---------- YETKİLER ----------
do $$
declare f text;
begin
  foreach f in array array[
    'profil_olustur(text,int)','il_degistir(int)','parti_kur(text,text,text,text)','partiye_katil(bigint)','partiden_ayril()',
    'gby_ata(int,text)','cb_aday_belirle(text,text)','aday_ol(text)','adaylik_geri_cek(bigint)','oy_ver(bigint,bigint)',
    'durum()','secim_detay(bigint)','harita()','il_detay(int)','partiler()','parti_detay(bigint)','meclis()',
    'gecmis_secimler(int)','haberler(int)','hesabimi_sil()',
    'bakan_ata(text,text)','bakan_gorevden_al(text)','istifa(text)','kabine()','oyuncu_kart(text)',
    'sohbet_oku(text,bigint,bigint)','sohbet_yaz(text,text)','ozel_liste()','ozel_oku(text,bigint)','ozel_yaz(text,text)',
    'yayin_haklari()','yayin_gonder(text,text,bigint)','bildirim_kutusu(int)','rozetler()',
    'engelle(text)','engel_kaldir(text)','engellenenler()','sikayet_et(text,bigint,text,text)',
    'bakanlik_paneli()','icraat_yap(text,int)','ulke_karnesi()','gazete(int)',
    'kararname_cikar(text,text,text,jsonb)','kararnameler(int)',
    'kanun_teklif(text,text,text,jsonb)','kanun_geri_cek(bigint)','kanun_oy(bigint,text)','kanun_cb_karar(bigint,text,text)','kanunlar(int)','kanun_detay(bigint)',
    'ittifak_bilgi(bigint)','ittifak_kur(text)','ittifak_davet(bigint)','ittifak_davet_yanit(bigint,boolean)','ittifak_ayril()','cb_destek(bigint)',
    'belediye_paneli()','belediye_hizmet(text,boolean)','belediye_yatirim(text)','belediye_ayar(numeric,numeric)',
    'hayat()','topla()','reklam_odul()','reklam_al()','magaza()','bagis_yap(numeric)','parti_destek(text,numeric)','parti_kasa(bigint)','parti_ucret_ayarla(jsonb)',
    'politika_ayarla(text,numeric)','politika_onizle(text,numeric)',
    'vaat_secenekleri(text,int)','vaat_hesapla(text,jsonb,int)','vaat_yaz(bigint,text,jsonb)','vaatlerim(bigint)','beyanname_kaydet(text,jsonb)',
    'admin_ozet()','admin_sikayetler(text)','admin_sikayet_karar(text,bigint,text,text)','admin_oyuncu(text)','admin_islem(text,text)','admin_duyuru(text)','admin_ayar(int)',
    'genel_baskanlik_uslen()','vekalet_paneli()','bos_makamlar()',
    'mevzuat()','mevzuat_onizle(text,numeric)','referandumlar(int)','referandum_detay(bigint)','referandum_oy(bigint,text)','kanun_imza(bigint,boolean)','belediye_duzenle(text,numeric)','bakan_adaylari(text)',
    'meclis_aday_ol(bigint,text,boolean)','meclis_oy(bigint,text,text)','meclis_baskanlik()','grup_karar(bigint,text)','meclis_ihtar(text,text)','meclis_gorev_birak(text)',
    'oturum_kaydet(text,text)','arsa_teklif(bigint,numeric)','ihaleler()','vatandaslik()','admin_supheler()','admin_hesap_onay(text,boolean,text)','admin_kurallar(jsonb)','il_bagis(numeric)','il_bagis_durum()','vergi_karnem()','sohbet_ozet()',
    'cihaz_kaydet(text,text)','cihaz_sil(text)','bildirim_ayar_kaydet(jsonb)',
    'teskilatlar(bigint)','teskilat_ac(int)','para_gonder(text,numeric,text)',
    'banka()','banka_yatir(numeric)','banka_cek(numeric)','vadeli_ac(numeric,int)','vadeli_boz(bigint)','kredi_cek(numeric,int)','kredi_ode(numeric)',
    'admin_moderatorler()','admin_moderator_ayarla(text,text[])','admin_mod_kayit(int)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
-- =====================================================================
--  KALICILIK (son): bütünlük kontrolü, silme koruması, sürüm bilgisi, sahibin sıfırlama/geri yükleme araçları
-- =====================================================================
alter table oyun.ayarlar add column if not exists son_uygulama text not null default '0';
alter table oyun.ayarlar add column if not exists min_uygulama text not null default '0';

-- TRUNCATE koruması (tablo bazında): oyun tabloları yalnızca sahibinin sıfırlama/geri yükleme işlemiyle boşaltılabilir
create or replace function oyun.bosaltma_korumasi() returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('oyun.sifirlama', true), '') <> 'evet' then
    raise exception 'Oyun verileri korunuyor: % tablosu boşaltılamaz. Oyunu sıfırlamak için: select oyun.oyunu_sifirla(''OYUNU SIFIRLA'');', tg_table_name;
  end if;
  return null;
end $$;

-- DROP TABLE / DROP COLUMN koruması (olay tetikleyicisi; Supabase izin vermezse atlanır, TRUNCATE koruması yine çalışır)
create or replace function oyun.silme_korumasi() returns event_trigger language plpgsql as $$
declare o record;
begin
  if coalesce(current_setting('oyun.sifirlama', true), '') = 'evet' or coalesce(current_setting('oyun.tablo_kaldir', true), '') = 'evet' then return; end if;
  for o in select * from pg_event_trigger_dropped_objects() loop
    if o.schema_name = 'oyun' and o.object_type in ('table','table column') and not o.is_temporary then
      raise exception 'Oyun verileri korunuyor: % (%) silinemez. Güncellemeler yalnızca ekleme yapar.', o.object_identity, o.object_type;
    end if;
  end loop;
end $$;

create or replace function oyun.koruma_kur() returns void language plpgsql as $$
declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r' loop
    execute format('drop trigger if exists bosaltma_korumasi on oyun.%I', t.relname);
    execute format('create trigger bosaltma_korumasi before truncate on oyun.%I for each statement execute function oyun.bosaltma_korumasi()', t.relname);
  end loop;
  begin
    if not exists (select 1 from pg_event_trigger where evtname = 'oyun_silme_korumasi') then
      create event trigger oyun_silme_korumasi on sql_drop execute function oyun.silme_korumasi();
    end if;
  exception when insufficient_privilege or feature_not_supported then
    raise notice 'Bilgi: DROP koruması (olay tetikleyicisi) bu sunucuda kurulamadı; TRUNCATE koruması ve güncelleme bütünlük kontrolü etkin.';
  end;
end $$;

-- Güncellemenin sonu: oyuncu verisi değiştiyse her şey geri alınır
create or replace function oyun.guncelleme_bitti() returns jsonb language plpgsql as $$
declare s oyun.surumler; once jsonb; sonra jsonb := oyun.parmak_izi(); k text; farklar text := '';
begin
  select * into s from oyun.surumler where bitis is null order by id desc limit 1;
  if s.id is null then raise exception 'guncelleme_basla çağrılmadan guncelleme_bitti çağrıldı.'; end if;
  once := coalesce(s.parmak_once, '{}');
  -- hiç oyuncu yokken (ilk kurulum ya da sahibin sıfırlaması) başlangıç verileri yüklenir; korunacak oyuncu verisi yoktur
  if coalesce(once ->> 'oyuncu', '0') = '0' then once := '{}'; end if;
  for k in select jsonb_object_keys(once) loop
    if sonra ->> k is distinct from once ->> k then farklar := farklar || ' ' || k; end if;
  end loop;
  if farklar <> '' then
    raise exception 'GÜNCELLEME DURDURULDU: bu güncelleme oyuncu verisini değiştirecekti (%). Hiçbir değişiklik uygulanmadı; oyun olduğu gibi duruyor.', btrim(farklar);
  end if;
  update oyun.surumler set bitis = clock_timestamp(), parmak_sonra = sonra where id = s.id;
  update oyun.ayarlar set son_uygulama = s.surum where id = 1;
  perform oyun.koruma_kur();
  return jsonb_build_object('surum', s.surum, 'yedek', s.yedek, 'kontrol', 'oyuncu verisi değişmedi', 'oyuncu', sonra ->> 'oyuncu', 'aktif_makam', sonra ->> 'aktif_makam');
end $$;

-- Uygulamanın sürüm kontrolü: eski uygulama sunucuyla uyumsuz hâle gelirse "güncelle" ekranı gösterir
create or replace function public.surum() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object('sunucu', (select surum from oyun.surumler where bitis is not null order by id desc limit 1),
                            'son_uygulama', a.son_uygulama, 'min_uygulama', a.min_uygulama)
  from oyun.ayarlar a where a.id = 1
$$;
revoke all on function public.surum() from public;
grant execute on function public.surum() to anon, authenticated;

-- Yönetici: eski uygulamaları zorunlu güncellemeye yönlendir
create or replace function public.admin_min_uygulama(p_surum text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare y oyun.profiller := oyun.yonetici_zorunlu();
begin
  if p_surum !~ '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]+$' and p_surum <> '0' then raise exception 'Sürüm biçimi YYYY.AA.GG-N olmalı.'; end if;
  update oyun.ayarlar set min_uygulama = p_surum where id = 1;
  return public.surum();
end $$;
revoke all on function public.admin_min_uygulama(text) from public, anon;
grant execute on function public.admin_min_uygulama(text) to authenticated;

-- ---------------------------------------------------------------------
-- SAHİBİN ARAÇLARI (yalnızca Supabase SQL Editor'den; uygulamadan çağrılamaz)
-- ---------------------------------------------------------------------
-- Katalog tabloları sıfırlamada korunur (iller, bakanlıklar, icraat/vaat/kural katalogları, ayarlar, sürümler)
create or replace function oyun.katalog_tablo(t text) returns boolean language sql immutable as $$
  select t in ('ayarlar','iller','bakanliklar','icraatlar','vaat_turleri','duzenleme_tanim','belediye_hizmetleri','belediye_yatirimlari',
               'paketler','gecici_eposta','surumler')
$$;

-- Oyunu sıfırlar: önce yedek alır, sonra oyun dünyasını boşaltır. Oyuncu hesapları (giriş bilgileri) kalır;
-- herkes yeniden profil oluşturur. Ardından supabase-kurulum.sql bir kez daha çalıştırılmalıdır (başlangıç verileri).
create or replace function oyun.oyunu_sifirla(p_onay text) returns text language plpgsql as $$
declare y text; liste text;
begin
  if p_onay is distinct from 'OYUNU SIFIRLA' then
    raise exception 'Oyunu sıfırlamak için tam olarak şunu yaz: select oyun.oyunu_sifirla(''OYUNU SIFIRLA'');';
  end if;
  y := oyun.yedek_al('Sıfırlama öncesi');
  perform set_config('oyun.sifirlama', 'evet', true);
  select string_agg(format('oyun.%I', c.relname), ', ') into liste
    from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r' and not oyun.katalog_tablo(c.relname);
  execute 'truncate ' || liste || ' restart identity cascade';
  return format('Oyun sıfırlandı. Yedek: %s. Şimdi supabase-kurulum.sql dosyasını bir kez daha çalıştır.', y);
end $$;

-- Bir yedeğe geri döner (o anki durumun da yedeği alınır). Sütunu yedekte olmayan yeni tablolar boş kalır.
create or replace function oyun.yedekten_don(p_sema text, p_onay text) returns text language plpgsql as $$
declare y text; t record; liste text; kalan text[]; tur int := 0; sutunlar text; ok boolean; n int;
begin
  if p_onay is distinct from 'GERİ YÜKLE' then
    raise exception 'Geri yüklemek için: select oyun.yedekten_don(''%'', ''GERİ YÜKLE'');', p_sema;
  end if;
  if p_sema !~ '^yedek_' or not exists (select 1 from pg_namespace where nspname = p_sema) then raise exception 'Yedek bulunamadı: %', p_sema; end if;
  y := oyun.yedek_al('Geri yükleme öncesi');
  perform set_config('oyun.sifirlama', 'evet', true);
  select array_agg(c.relname::text) into kalan from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'oyun' and c.relkind = 'r' and c.relname <> 'surumler'
     and exists (select 1 from pg_class c2 join pg_namespace n2 on n2.oid = c2.relnamespace where n2.nspname = p_sema and c2.relname = c.relname);
  select string_agg(format('oyun.%I', x), ', ') into liste from unnest(kalan) x;
  execute 'truncate ' || liste || ' cascade';
  foreach liste in array kalan loop execute format('alter table oyun.%I disable trigger user', liste); end loop;
  -- yabancı anahtar sırası bilinmediği için birkaç turda yükle
  while array_length(kalan, 1) > 0 and tur < 10 loop
    tur := tur + 1;
    foreach liste in array kalan loop
      select string_agg(format('%I', a.attname), ', ') into sutunlar
        from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'oyun' and c.relname = liste and a.attnum > 0 and not a.attisdropped and a.attgenerated = ''
         and exists (select 1 from pg_attribute b join pg_class c2 on c2.oid = b.attrelid join pg_namespace n2 on n2.oid = c2.relnamespace
                     where n2.nspname = p_sema and c2.relname = liste and b.attname = a.attname and not b.attisdropped);
      ok := true;
      begin
        execute format('insert into oyun.%I (%s) select %s from %I.%I', liste, sutunlar, sutunlar, p_sema, liste);
      exception when foreign_key_violation then ok := false;
      end;
      if ok then kalan := array_remove(kalan, liste); end if;
    end loop;
  end loop;
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r' loop
    execute format('alter table oyun.%I enable trigger user', t.relname);
  end loop;
  if array_length(kalan, 1) > 0 then raise exception 'Geri yükleme tamamlanamadı (%); hiçbir şey değişmedi.', array_to_string(kalan, ', '); end if;
  -- kimlik sayaçlarını yedekteki en büyük değere getir
  for t in select s.relname seq, tc.relname tablo, a.attname sutun from pg_class s
             join pg_depend d on d.objid = s.oid and d.deptype in ('a','i') join pg_class tc on tc.oid = d.refobjid
             join pg_attribute a on a.attrelid = tc.oid and a.attnum = d.refobjsubid join pg_namespace n on n.oid = tc.relnamespace
            where s.relkind = 'S' and n.nspname = 'oyun' loop
    execute format('select coalesce(max(%I), 0) from oyun.%I', t.sutun, t.tablo) into n;
    if n > 0 then execute format('select setval(%L, %s)', 'oyun.' || t.seq, n); end if;
  end loop;
  return format('%s yedeğine dönüldü. Dönüş öncesi durumun yedeği: %s', p_sema, y);
end $$;

revoke all on function oyun.oyunu_sifirla(text), oyun.yedekten_don(text, text), oyun.yedek_al(text) from public;
select oyun.guncelleme_bitti();
commit;

-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 4) ZAMANLAYICI (yalnızca Supabase'de)
--  Seçim motorunu her dakika çalıştırır: takvimi üretir, 18:00'de sayar,
--  göreve başlatmaları yapar. Supabase'de "pg_cron" eklentisi gerekir.
-- =====================================================================
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

-- Oyun saatini bu andan başlat (bu andan önceki seçimler oluşturulmaz)
-- İlk kurulumda (henüz hiç seçim yokken) başlangıcı şimdiye al; güncellemelerde takvime dokunma
update oyun.ayarlar set test_simdi = null where id = 1;
update oyun.ayarlar set baslangic = now() where id = 1 and not exists (select 1 from oyun.secimler);

-- Varsa eski zamanlayıcıyı kaldır, yenisini kur
select cron.unschedule(jobid) from cron.job where jobname = 'secim-motoru';
select cron.schedule('secim-motoru', '* * * * *', 'select oyun.tick()');

-- İlk takvimi hemen üret
select oyun.tick();
