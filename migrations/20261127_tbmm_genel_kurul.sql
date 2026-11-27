-- =====================================================================
-- 27.11.2026 · TBMM GENEL KURUL SALONU (sürüm 2026.11.27-4)
-- İstek (Ercan): "Meclis görüşmeleri için ayrı bir ekran; meclis açılınca oyuncular tıklayarak girsin, meclis atmosferi
-- olsun. Üyeler söz alsın, Meclis Başkanı sıraya soksun, herkesin süre/kelime kısıtı olsun, oylamada evet/hayır desinler.
-- Piyasadaki en iyi meclis dinamiğini kur."
--
-- Gerçek karşılığı (TBMM İçtüzüğü ve Anayasa):
--   • Birleşim: Başkan birleşimi açar, elektronik cihazla yoklama yapılır (m.57). Toplantı yeter sayısı üye tamsayısının
--     üçte biri, karar yeter sayısı dörtte birinin bir fazlası (Anayasa m.96). Yeter sayı yoksa ara verilir, yine yoksa
--     birleşim kapanır.
--   • Gündem: Başkanlık sunuşları, gündem dışı konuşmalar (m.59; günde en çok 3, 5 dk), siyasi parti grubu önerileri
--     (m.19), genel görüşme (Anayasa m.98, İçtüzük m.102-103), kanun teklifleri.
--   • Söz: Başkandan istenir; şahsı adına 10 dk, grup ve hükümet adına 20 dk, yerinden kısa açıklama 1 dk (m.60),
--     sataşma nedeniyle 2 dk (m.69), usul hakkında (m.63). Süre bitince "(Mikrofon otomatik cihaz tarafından kapatıldı)";
--     Başkan "tamamlayın" diyerek 1 dakika ek süre verebilir.
--   • İşaret oylaması; karar yeter sayısı istenirse sayım (m.57). Eşitlikte önerge reddedilmiş sayılır.
--   • Kapalı oturum (m.70), disiplin: uyarma, kınama, geçici çıkarma (m.156-163; kınama ödeneğin 1/3'ü, çıkarma 2/3'ü).
--   • İlk birleşimde milletvekilleri andiçer (Anayasa m.81).
-- Oyun kuralları (açıkça):
--   • Olağan birleşim her akşam 21.00–22.00 (TSİ). Çalışma süresi işaret oylamasıyla 30'ar dk, en çok 2 kez uzar.
--     Meclis Başkanı ve Cumhurbaşkanı olağanüstü birleşim çağırabilir (Anayasa m.93).
--   • Konuşma süresi gerçek sürenin oyundaki karşılığıdır, ayrıca kelime sınırı vardır:
--     şahsı adına 150 kelime/4 dk · grup ve hükümet adına 280/6 dk · gündem dışı 120/5 dk · yerinden 45/1 dk ·
--     sataşma 70/2 dk · usul 70/2 dk. Söz verilen vekil 90 sn içinde kürsüye çıkmazsa söz sırası düşer.
--   • Toplantı ve karar yeter sayıları, canlı birleşimde DOLU sandalyeler üzerinden hesaplanır (600 sandalye dolunca
--     Anayasa'daki sayılarla birebir aynı: 200 ve 151). Kanun oylamalarının eşikleri DEĞİŞMEDİ (600 üzerinden).
--     Yönetim portalından `gk.yeter_taban` = tamsayi yapılırsa canlı birleşim de 600 üzerinden hesaplar.
--   • Yayın ölçeği güvencesi: Başkanlık salonda değilse ya da 90 sn işlem yapmazsa söz sırayla kendiliğinden verilir,
--     gündem kendiliğinden ilerler, önerilerin oylaması kendiliğinden açılır. Tek yetkilinin yokluğu birleşimi durdurmaz.
--   • Kanun teklifleri eskisi gibi 24 saat görüşme + 24 saat oylama ile işler; salonda canlı elektronik oylama panosu,
--     zil ve sonuç duyurusu vardır (oylama süresine dokunulmadı).
-- Yük: ekran tek RPC (gk_durum) ile çalışır; ortak görünüm önbellekten (sürüm numarası) gelir, kişiye özel kısım küçük;
--      tutanak artımlı okunur; canlı sinyal anahtarı 'sohbet:meclis' (yeni anahtar türü yok).
-- Eski uygulama: Genel Kurul sohbeti ve "Söz iste" düğmesi çalışmaya devam eder; salondaki konuşmalar sohbete,
--      sohbetten yazılanlar tutanağa yansır. Birleşim yokken Genel Kurul sohbetine yazılmaz.
-- Tekrar çalıştırmak güvenlidir; oyuncu verisi değiştirilmez.
-- =====================================================================

-- ---------------------------------------------------------------- AYARLAR
create table if not exists oyun.gk_ayar (
  id int primary key default 1 check (id = 1),
  aktif boolean not null default true,
  olagan_bas time not null default '21:00',
  olagan_bit time not null default '22:00',
  yoklama_dk int not null default 5 check (yoklama_dk between 2 and 15),
  ara_dk int not null default 10 check (ara_dk between 3 and 30),
  yeter_taban text not null default 'dolu' check (yeter_taban in ('dolu', 'tamsayi')),
  gundem_disi_sayi int not null default 3 check (gundem_disi_sayi between 0 and 5),
  uzatma_dk int not null default 30 check (uzatma_dk between 10 and 60),
  uzatma_azami int not null default 2 check (uzatma_azami between 0 and 4),
  oylama_dk int not null default 3 check (oylama_dk between 1 and 10),
  laf_aralik_sn int not null default 20 check (laf_aralik_sn between 5 and 120),
  laf_azami int not null default 3 check (laf_azami between 0 and 10),
  tepki_oran numeric not null default 0.04 check (tepki_oran between 0.01 and 0.5)
);
insert into oyun.gk_ayar(id) values (1) on conflict (id) do nothing;

create table if not exists oyun.gk_salon (
  id int primary key default 1 check (id = 1),
  surum bigint not null default 1,
  kirli boolean not null default false,
  sonraki timestamptz,
  degisti timestamptz
);
insert into oyun.gk_salon(id) values (1) on conflict (id) do nothing;

create table if not exists oyun.gk_onbellek (
  anahtar text primary key,
  surum bigint not null default 0,
  veri jsonb,
  zaman timestamptz not null default now()
);

-- ---------------------------------------------------------------- TABLOLAR
create table if not exists oyun.gk_birlesim (
  id bigserial primary key,
  no int,
  donem bigint,
  tur text not null default 'olagan' check (tur in ('olagan', 'olaganustu')),
  gun date not null,
  plan_bas timestamptz not null,
  plan_bit timestamptz not null,
  durum text not null default 'planli' check (durum in ('planli', 'yoklama', 'acik', 'arada', 'kapandi', 'toplanamadi', 'iptal')),
  acilis timestamptz, kapanis timestamptz,
  yoneten uuid,
  ara_bit timestamptz, ara_neden text,
  uzatma int not null default 0,
  yoklama_hata int not null default 0,
  yeter boolean,
  kapali boolean not null default false,
  aktif_gundem bigint,
  kursu_bos timestamptz,
  salon_azami int not null default 0,
  cagiran uuid, gerekce text,
  ozet jsonb, haber_at timestamptz,
  olusturma timestamptz not null default now()
);
create unique index if not exists gk_birlesim_olagan_gun on oyun.gk_birlesim (gun) where tur = 'olagan';
create index if not exists gk_birlesim_durum on oyun.gk_birlesim (durum, plan_bas);
create index if not exists gk_birlesim_donem on oyun.gk_birlesim (donem, id);

create table if not exists oyun.gk_gundem (
  id bigserial primary key,
  birlesim_id bigint not null,
  sira int not null,
  tur text not null check (tur in ('yemin', 'sunus', 'gundem_disi', 'grup_onerisi', 'genel_gorusme_on', 'genel_gorusme', 'kanun', 'kanun_oylama', 'serbest')),
  ref_id bigint,
  baslik text not null,
  durum text not null default 'bekliyor' check (durum in ('bekliyor', 'gorusuluyor', 'tamam')),
  bas timestamptz, bit timestamptz
);
create index if not exists gk_gundem_b on oyun.gk_gundem (birlesim_id, sira);

create table if not exists oyun.gk_tutanak (
  id bigserial primary key,
  birlesim_id bigint,
  salon text not null default 'gk',
  zaman timestamptz not null,
  tur text not null check (tur in ('baskan', 'konusma', 'laf', 'tepki', 'sistem', 'oylama', 'yoklama', 'gundem', 'yemin')),
  user_id uuid,
  ad text, kad text, il text, parti_id bigint, parti_kisa text, renk text, rol text,
  soz_id bigint, soz_tur text, gundem_id bigint,
  metin text not null,
  veri jsonb,
  kapali boolean not null default false,
  gizli boolean not null default false,
  kaldiran uuid,
  mesaj_id bigint
);
alter table oyun.gk_tutanak add column if not exists kaldiran uuid;
create index if not exists gk_tutanak_b on oyun.gk_tutanak (birlesim_id, id);
create index if not exists gk_tutanak_salon on oyun.gk_tutanak (salon, id);
create index if not exists gk_tutanak_kisi on oyun.gk_tutanak (user_id, zaman) where tur = 'konusma';

create table if not exists oyun.gk_tepki (
  tutanak_id bigint not null,
  user_id uuid not null,
  tur text not null check (tur in ('alkis', 'protesto')),
  vekil boolean not null default false,
  parti_id bigint,
  zaman timestamptz not null,
  primary key (tutanak_id, user_id)
);
create table if not exists oyun.gk_tepki_satir (
  tutanak_id bigint not null, parti_id bigint not null, tur text not null,
  primary key (tutanak_id, parti_id, tur)
);

create table if not exists oyun.gk_salonda (
  birlesim_id bigint not null,
  user_id uuid not null,
  son timestamptz not null,
  vekil boolean not null default false,
  primary key (birlesim_id, user_id)
);
create index if not exists gk_salonda_son on oyun.gk_salonda (birlesim_id, son);

create table if not exists oyun.gk_yoklama (
  id bigserial primary key,
  birlesim_id bigint not null,
  bas timestamptz not null, bit timestamptz not null,
  neden text not null check (neden in ('acilis', 'tekrar', 'istem')),
  isteyen uuid,
  sayi int, yeter int,
  sonuc text not null default 'acik' check (sonuc in ('acik', 'var', 'yok'))
);
create index if not exists gk_yoklama_b on oyun.gk_yoklama (birlesim_id, id);
create table if not exists oyun.gk_yoklama_kayit (
  yoklama_id bigint not null, user_id uuid not null, zaman timestamptz not null, pusula boolean not null default false,
  primary key (yoklama_id, user_id)
);

create table if not exists oyun.gk_oylama (
  id bigserial primary key,
  birlesim_id bigint not null,
  gundem_id bigint,
  konu text not null check (konu in ('grup_onerisi', 'genel_gorusme', 'uzatma', 'kapali_oturum', 'disiplin')),
  ref_id bigint,
  baslik text not null,
  bas timestamptz not null, bit timestamptz not null,
  durum text not null default 'acik' check (durum in ('acik', 'kabul', 'ret', 'yetersiz', 'iptal')),
  acan uuid,
  kabul int not null default 0, ret int not null default 0, cekimser int not null default 0,
  yeter_istendi boolean not null default false, yeter_isteyen uuid, yeter int,
  tekrar boolean not null default false
);
create index if not exists gk_oylama_b on oyun.gk_oylama (birlesim_id, id);
create table if not exists oyun.gk_oy (
  oylama_id bigint not null, user_id uuid not null,
  oy text not null check (oy in ('kabul', 'ret', 'cekimser')),
  parti_id bigint, zaman timestamptz not null,
  primary key (oylama_id, user_id)
);

create table if not exists oyun.gk_grup_onerisi (
  id bigserial primary key,
  gun date not null,
  birlesim_id bigint,
  parti_id bigint not null,
  veren uuid not null,
  tur text not null check (tur in ('gundem', 'uzatma', 'bildiri', 'genel_gorusme')),
  baslik text not null,
  metin text not null,
  ref_id bigint,
  zaman timestamptz not null,
  durum text not null default 'bekliyor' check (durum in ('bekliyor', 'gorusuluyor', 'kabul', 'ret', 'geri', 'dustu')),
  oylama_id bigint
);
create index if not exists gk_grup_onerisi_gun on oyun.gk_grup_onerisi (gun, durum);

create table if not exists oyun.gk_gundem_disi (
  id bigserial primary key,
  gun date not null,
  user_id uuid not null,
  konu text not null,
  istek timestamptz not null,
  durum text not null default 'bekliyor' check (durum in ('bekliyor', 'secildi', 'konustu', 'dustu', 'geri')),
  secen uuid
);
create unique index if not exists gk_gundem_disi_tek on oyun.gk_gundem_disi (gun, user_id) where durum <> 'geri';

create table if not exists oyun.gk_genel_gorusme (
  id bigserial primary key,
  no int not null,
  konu text not null,
  gerekce text not null,
  veren uuid not null,
  parti_id bigint,
  grup_adina boolean not null default false,
  durum text not null default 'imza' check (durum in ('imza', 'bekliyor', 'acildi', 'gorusuldu', 'ret', 'dustu', 'geri')),
  olusturma timestamptz not null,
  imza_bit timestamptz,
  karar_at timestamptz,
  gorusme_birlesim bigint,
  sonuc_metin text
);
create index if not exists gk_genel_gorusme_durum on oyun.gk_genel_gorusme (durum, id);
create table if not exists oyun.gk_gg_imza (gg_id bigint not null, user_id uuid not null, zaman timestamptz not null, primary key (gg_id, user_id));

create table if not exists oyun.gk_disiplin (
  id bigserial primary key,
  birlesim_id bigint,
  user_id uuid not null,
  veren uuid,
  tur text not null check (tur in ('uyarma', 'kinama', 'cikarma')),
  gerekce text not null,
  birlesim_sayi int not null default 0,
  oylama_id bigint,
  durum text not null default 'teklif' check (durum in ('teklif', 'uygulandi', 'ret')),
  zaman timestamptz not null,
  bit timestamptz,
  son_no int
);
create index if not exists gk_disiplin_kisi on oyun.gk_disiplin (user_id, durum, bit);

create table if not exists oyun.gk_zil (birlesim_id bigint not null, kanun_id bigint not null, zaman timestamptz not null, primary key (birlesim_id, kanun_id));
create table if not exists oyun.gk_yemin (donem bigint not null, user_id uuid not null, zaman timestamptz not null, birlesim_id bigint, primary key (donem, user_id));

-- Söz kaydı (24.11 meclis_soz) salon için genişler; eski uygulamanın kullandığı sütunlar aynen kalır.
alter table oyun.meclis_soz add column if not exists gk boolean not null default false;
alter table oyun.meclis_soz add column if not exists birlesim_id bigint;
alter table oyun.meclis_soz add column if not exists gundem_id bigint;
alter table oyun.meclis_soz add column if not exists kursu_bas timestamptz;
alter table oyun.meclis_soz add column if not exists kursu_bit timestamptz;
alter table oyun.meclis_soz add column if not exists kelime_kullanilan int not null default 0;
alter table oyun.meclis_soz add column if not exists ek_sure boolean not null default false;
alter table oyun.meclis_soz add column if not exists sira_no numeric;
alter table oyun.meclis_soz add column if not exists konu text;
alter table oyun.meclis_soz add column if not exists hedef_tutanak bigint;
alter table oyun.meclis_soz drop constraint if exists meclis_soz_tur_check;
alter table oyun.meclis_soz add constraint meclis_soz_tur_check
  check (tur in ('kisisel', 'grup', 'hukumet', 'yerinden', 'satasma', 'gundem_disi', 'usul'));
create index if not exists meclis_soz_gk on oyun.meclis_soz (birlesim_id, durum) where gk;

do $rls$
declare t text;
begin
  foreach t in array array['gk_ayar','gk_salon','gk_onbellek','gk_birlesim','gk_gundem','gk_tutanak','gk_tepki','gk_tepki_satir',
    'gk_salonda','gk_yoklama','gk_yoklama_kayit','gk_oylama','gk_oy','gk_grup_onerisi','gk_gundem_disi','gk_genel_gorusme',
    'gk_gg_imza','gk_disiplin','gk_zil','gk_yemin'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $rls$;

-- Eski söz şeridinin (meclis_soz.js) bilmediği türler de karakter sınırıyla çalışsın
create or replace function oyun.meclis_soz_tur() returns table(kod text, ad text, sinir int, sira int)
language sql immutable set search_path to '' as $f$
  values ('kisisel', 'Şahsı adına', 800, 1), ('grup', 'Grup adına', 1500, 2), ('hukumet', 'Hükümet adına', 1500, 3),
         ('yerinden', 'Yerinden kısa söz', 250, 4), ('satasma', 'Sataşma nedeniyle', 450, 5),
         ('gundem_disi', 'Gündem dışı', 900, 6), ('usul', 'Usul hakkında', 450, 7)
$f$;

-- ---------------------------------------------------------------- SABİTLER ve YARDIMCILAR
create or replace function oyun.gk_soz_tur() returns table(kod text, ad text, kelime int, sure_sn int, sira int)
language sql immutable set search_path to '' as $f$
  values ('kisisel', 'Şahsı adına', 150, 240, 1), ('grup', 'Grup adına', 280, 360, 2), ('hukumet', 'Hükümet adına', 280, 360, 3),
         ('yerinden', 'Yerinden kısa açıklama', 45, 60, 4), ('satasma', 'Sataşma nedeniyle cevap hakkı', 70, 120, 5),
         ('gundem_disi', 'Gündem dışı konuşma', 120, 300, 6), ('usul', 'Usul hakkında', 70, 120, 7)
$f$;

create or replace function oyun.gk_kelime(m text) returns int
language sql immutable set search_path to '' as $f$
  select case when btrim(coalesce(m, '')) = '' then 0 else coalesce(array_length(regexp_split_to_array(btrim(m), '\s+'), 1), 0) end
$f$;

-- 1'inci, 2'nci, 3'üncü … (Türkçe sıra sayısı eki)
create or replace function oyun.gk_sira(n int) returns text
language sql immutable set search_path to '' as $f$
  select n::text || '''' || case
    when n % 10 <> 0 then (array['inci','nci','üncü','üncü','inci','ncı','nci','inci','uncu'])[n % 10]
    when n % 100 <> 0 then (array['uncu','nci','uncu','ıncı','nci','ıncı','inci','inci','ıncı'])[(n % 100) / 10]
    when n % 1000 <> 0 then 'üncü' else 'inci' end
$f$;

create or replace function oyun.gk_saat(t timestamptz) returns text
language sql stable set search_path to '' as $f$ select to_char(t at time zone 'Europe/Istanbul', 'HH24.MI') $f$;

create or replace function oyun.gk_gun(t timestamptz) returns date
language sql stable set search_path to '' as $f$ select (t at time zone 'Europe/Istanbul')::date $f$;

create or replace function oyun.gk_vekil(u uuid) returns boolean
language sql stable set search_path to '' as $f$
  select u is not null and exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv' and m.bit is null)
$f$;

create or replace function oyun.gk_hukumet(u uuid) returns boolean
language sql stable set search_path to '' as $f$
  select u is not null and (exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur in ('cb', 'bakan', 'cb_yardimcisi'))
    or exists (select 1 from oyun.hukumetler h where h.basbakan = u and h.durum = 'gorevde' and h.bit is null))
$f$;

-- Oturumu yönetebilenler: TBMM Başkanı, başkanvekilleri; Başkan seçilene kadar Geçici Başkan
create or replace function oyun.gk_yonetebilir(u uuid) returns boolean
language sql stable set search_path to '' as $f$
  select u is not null and (oyun.meclis_baskanlik_mi(u) or (oyun.tbmm_baskani() is null and oyun.gecici_baskan() is not distinct from u))
$f$;

-- Grup adına konuşma/öneri yetkisi: grup başkanvekili ya da milletvekili genel başkan (grubu olan partide)
create or replace function oyun.gk_grup_parti(u uuid) returns bigint
language sql stable set search_path to '' as $f$
  select coalesce(
    (select m.parti_id from oyun.makamlar m where m.user_id = u and m.tur = 'grup_bskv' and m.bit is null and m.parti_id is not null limit 1),
    (select pa.id from oyun.partiler pa where pa.gb = u and not pa.kapali and oyun.gk_vekil(u)
       and exists (select 1 from oyun.gruplar() g where g.parti_id = pa.id) limit 1))
$f$;

create or replace function oyun.gk_kimlik(u uuid) returns jsonb
language sql stable set search_path to '' as $f$
  select jsonb_build_object('ad', coalesce(nullif(btrim(p.ad_soyad), ''), p.kad), 'kad', p.kad,
    'il', (select i.ad from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'mv' and m.bit is null limit 1),
    'mk', (select m.id from oyun.makamlar m where m.user_id = u and m.tur = 'mv' and m.bit is null limit 1),
    'parti_id', p.parti_id, 'kisa', pa.kisa, 'renk', pa.renk,
    'rol', case
      when exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur = 'cb') then 'Cumhurbaşkanı'
      when exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur = 'cb_yardimcisi') then 'Cumhurbaşkanı Yardımcısı'
      when exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur = 'tbmm') then 'TBMM Başkanı'
      else (select replace(b.ad, 'Bakanlığı', 'Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik
             where m.user_id = u and m.bit is null and m.tur = 'bakan' limit 1) end)
  from oyun.profiller p left join oyun.partiler pa on pa.id = p.parti_id where p.id = u
$f$;

create or replace function oyun.gk_taban() returns int
language sql stable set search_path to '' as $f$
  select greatest(1, case when (select yeter_taban from oyun.gk_ayar where id = 1) = 'tamsayi' then oyun.tbmm_tamsayi() else oyun.dolu_sandalye() end)
$f$;
create or replace function oyun.gk_toplanti_yeter() returns int
language sql stable set search_path to '' as $f$ select greatest(1, ceil(oyun.gk_taban() / 3.0))::int $f$;
create or replace function oyun.gk_karar_yeter() returns int
language sql stable set search_path to '' as $f$ select (floor(oyun.gk_taban() / 4.0) + 1)::int $f$;

-- Meclis dönemi: görevdeki milletvekillerini seçen son genel seçim
-- Yasama dönemi = görevdeki milletvekillerini getiren son seçim; seçimsiz atamalarda 0 (andiçme kaydı boş kalmasın)
create or replace function oyun.gk_donem() returns bigint
language sql stable set search_path to '' as $f$
  select coalesce(max(m.secim_id), 0) from oyun.makamlar m where m.tur = 'mv' and m.bit is null
$f$;

create or replace function oyun.gk_su_an() returns oyun.gk_birlesim
language sql stable set search_path to '' as $f$
  select b from oyun.gk_birlesim b where b.durum in ('yoklama', 'acik', 'arada') order by b.plan_bas desc limit 1
$f$;

create or replace function oyun.gk_bitis(b oyun.gk_birlesim) returns timestamptz
language sql stable set search_path to '' as $f$
  select b.plan_bit + make_interval(mins => b.uzatma * (select uzatma_dk from oyun.gk_ayar where id = 1))
$f$;

-- Geçici çıkarma cezası süren vekil (bu birleşimde salona giremez)
create or replace function oyun.gk_cikarilmis(u uuid, b oyun.gk_birlesim) returns boolean
language sql stable set search_path to '' as $f$
  select b.id is not null and exists (select 1 from oyun.gk_disiplin d where d.user_id = u and d.tur = 'cikarma' and d.durum = 'uygulandi'
                                      and d.son_no is not null and coalesce(b.no, 0) <= d.son_no and d.birlesim_id is distinct from null
                                      and (select donem from oyun.gk_birlesim x where x.id = d.birlesim_id) is not distinct from b.donem)
$f$;

-- Kınama / geçici çıkarma ödenek kesintisi (yüzde). Kınama 1/3, çıkarma 2/3; 30 gün (bir aylık ödeneğin karşılığı)
create or replace function oyun.gk_disiplin_kesinti(u uuid, t timestamptz) returns numeric
language sql stable set search_path to '' as $f$
  select coalesce(max(case d.tur when 'cikarma' then 66.7 when 'kinama' then 33.3 else 0 end), 0)
  from oyun.gk_disiplin d where d.user_id = u and d.durum = 'uygulandi' and d.bit > t
$f$;

-- Mevcut devamsızlık kesintisine disiplin kesintisi eklenir (toplam en çok %100)
create or replace function oyun.vekil_kesinti_orani(u uuid, t timestamptz) returns numeric
language sql stable set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $f$
  select least(100, round(oyun.duz('vekil_kesinti') * oyun.vekil_devamsizlik(u, t), 1) + oyun.gk_disiplin_kesinti(u, t))
$f$;

-- Değişiklik bildirimi: işlem başına bir kez sürüm artar ve canlı sinyal gider
create or replace function oyun.gk_degisti() returns void
language plpgsql security definer set search_path to '' as $f$
begin
  if current_setting('oyun.gk_degisti', true) = '1' then return; end if;
  perform set_config('oyun.gk_degisti', '1', true);
  update oyun.gk_salon set surum = surum + 1, kirli = false, degisti = now(), sonraki = null where id = 1;
  perform oyun.canli_sinyal('sohbet:meclis');
end $f$;

create or replace function oyun.gk_kirlet() returns void
language sql security definer set search_path to '' as $f$
  update oyun.gk_salon set kirli = true where id = 1 and not kirli
$f$;

-- Tutanağa satır yaz (kimlik o anki hâliyle saklanır)
create or replace function oyun.gk_yaz(p_b bigint, p_tur text, p_u uuid, p_metin text, p_veri jsonb default null,
  p_soz bigint default null, p_soz_tur text default null, p_t timestamptz default null) returns bigint
language plpgsql security definer set search_path to '' as $f$
declare k jsonb; v_id bigint; v_kapali boolean; v_g bigint;
begin
  if p_u is not null then k := oyun.gk_kimlik(p_u); end if;
  select b.kapali, b.aktif_gundem into v_kapali, v_g from oyun.gk_birlesim b where b.id = p_b;
  insert into oyun.gk_tutanak(birlesim_id, zaman, tur, user_id, ad, kad, il, parti_id, parti_kisa, renk, rol, soz_id, soz_tur, gundem_id, metin, veri, kapali)
  values (p_b, coalesce(p_t, oyun.simdi()), p_tur, p_u, k ->> 'ad', k ->> 'kad', k ->> 'il', (k ->> 'parti_id')::bigint, k ->> 'kisa', k ->> 'renk', k ->> 'rol',
          p_soz, p_soz_tur, v_g, p_metin, p_veri, coalesce(v_kapali, false))
  returning id into v_id;
  perform oyun.gk_degisti();
  return v_id;
end $f$;

create or replace function oyun.gk_baskan(p_b bigint, p_metin text, p_u uuid default null, p_t timestamptz default null) returns bigint
language sql security definer set search_path to '' as $f$
  select oyun.gk_yaz(p_b, 'baskan', p_u, p_metin, null, null, null, p_t)
$f$;

-- Bütün aktif milletvekillerine bildirim
create or replace function oyun.gk_vekillere_bildir(p_metin text, p_t timestamptz, p_haric uuid default null) returns int
language plpgsql security definer set search_path to '' as $f$
declare n int;
begin
  insert into oyun.bildirimler(user_id, zaman, metin)
  select distinct m.user_id, p_t, p_metin from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
  where m.tur = 'mv' and m.bit is null and not coalesce(pr.yasakli, false) and m.user_id is distinct from p_haric
  limit 700;
  get diagnostics n = row_count;
  return n;
end $f$;

-- Başkanlık salonda mı (son 90 sn içinde salonu açık tutan yönetici)
create or replace function oyun.gk_yoneten_salonda(p_b bigint, t timestamptz) returns uuid
language sql stable set search_path to '' as $f$
  select s.user_id from oyun.gk_salonda s where s.birlesim_id = p_b and s.son > t - interval '90 seconds' and oyun.gk_yonetebilir(s.user_id)
  order by (s.user_id = oyun.tbmm_baskani()) desc, s.son desc limit 1
$f$;

-- ---------------------------------------------------------------- GÜNDEM
create or replace function oyun.gk_madde_ekle(p_b bigint, p_tur text, p_ref bigint, p_baslik text, p_once_serbest boolean default true) returns bigint
language plpgsql security definer set search_path to '' as $f$
declare s int; v_id bigint;
begin
  if p_ref is not null and exists (select 1 from oyun.gk_gundem g where g.birlesim_id = p_b and g.tur = p_tur and g.ref_id = p_ref) then return null; end if;
  if p_once_serbest and exists (select 1 from oyun.gk_gundem g where g.birlesim_id = p_b and g.tur = 'serbest' and g.durum = 'bekliyor') then
    select g.sira into s from oyun.gk_gundem g where g.birlesim_id = p_b and g.tur = 'serbest' and g.durum = 'bekliyor' order by g.sira limit 1;
    update oyun.gk_gundem set sira = sira + 1 where birlesim_id = p_b and sira >= s;
  else
    select coalesce(max(g.sira), 0) + 1 into s from oyun.gk_gundem g where g.birlesim_id = p_b;
  end if;
  insert into oyun.gk_gundem(birlesim_id, sira, tur, ref_id, baslik) values (p_b, s, p_tur, p_ref, left(p_baslik, 220)) returning id into v_id;
  return v_id;
end $f$;

create or replace function oyun.gk_gundem_kur(b oyun.gk_birlesim, t timestamptz) returns void
language plpgsql security definer set search_path to '' as $f$
declare r record;
begin
  if exists (select 1 from oyun.gk_gundem where birlesim_id = b.id) then return; end if;
  if not exists (select 1 from oyun.gk_birlesim x where x.donem is not distinct from b.donem and x.id <> b.id and x.acilis is not null) then
    perform oyun.gk_madde_ekle(b.id, 'yemin', null, 'Milletvekillerinin andiçmeleri (Anayasa m.81)', false);
  elsif exists (select 1 from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
                where m.tur = 'mv' and m.bit is null and pr.son_gorulme > t - interval '2 days'
                  and not exists (select 1 from oyun.gk_yemin y where y.donem is not distinct from b.donem and y.user_id = m.user_id)) then
    -- İlk birleşimde bulunamayan ya da sonradan gelen (ara seçim, yedek) vekiller ilk katıldıkları birleşimde andiçer
    perform oyun.gk_madde_ekle(b.id, 'yemin', null, 'Andiçmeyen milletvekillerinin andiçmeleri (Anayasa m.81)', false);
  end if;
  perform oyun.gk_madde_ekle(b.id, 'sunus', null, 'Başkanlığın Genel Kurula sunuşları', false);
  if exists (select 1 from oyun.gk_gundem_disi d where d.gun = b.gun and d.durum in ('bekliyor', 'secildi')) then
    perform oyun.gk_madde_ekle(b.id, 'gundem_disi', null, 'Gündem dışı konuşmalar', false);
  end if;
  for r in select o.id, o.baslik, pa.kisa from oyun.gk_grup_onerisi o join oyun.partiler pa on pa.id = o.parti_id
           where o.gun = b.gun and o.durum = 'bekliyor' order by o.zaman loop
    perform oyun.gk_madde_ekle(b.id, 'grup_onerisi', r.id, format('%s Grubu önerisi: %s', r.kisa, r.baslik), false);
  end loop;
  for r in select g.id, g.no, g.konu from oyun.gk_genel_gorusme g where g.durum = 'bekliyor' order by g.id limit 3 loop
    perform oyun.gk_madde_ekle(b.id, 'genel_gorusme_on', r.id, format('%s esas numaralı genel görüşme önergesinin ön görüşmesi: %s', r.no, r.konu), false);
  end loop;
  for r in select g.id, g.no, g.konu from oyun.gk_genel_gorusme g where g.durum = 'acildi' order by g.karar_at limit 2 loop
    perform oyun.gk_madde_ekle(b.id, 'genel_gorusme', r.id, format('Genel görüşme: %s', r.konu), false);
  end loop;
  for r in select k.id, k.no, k.baslik from oyun.kanunlar k where k.durum = 'gorusmede' order by k.oy_bas nulls last, k.id limit 6 loop
    perform oyun.gk_madde_ekle(b.id, 'kanun', r.id, format('%s — tümü üzerindeki görüşmeler', r.baslik), false);
  end loop;
  for r in select k.id, k.no, k.baslik from oyun.kanunlar k where k.durum in ('oylamada', 'israr') order by k.oy_bit nulls last, k.id limit 6 loop
    perform oyun.gk_madde_ekle(b.id, 'kanun_oylama', r.id, format('%s — elektronik oylama', r.baslik), false);
  end loop;
  perform oyun.gk_madde_ekle(b.id, 'serbest', null, 'Diğer işler ve serbest görüşmeler', false);
end $f$;

-- Başkanlık sunuşları: son birleşimden bu yana Meclis'e gelen işler
create or replace function oyun.gk_sunus(b oyun.gk_birlesim, t timestamptz) returns void
language plpgsql security definer set search_path to '' as $f$
declare v_son timestamptz; n int; m text := '';
begin
  select max(x.kapanis) into v_son from oyun.gk_birlesim x where x.id <> b.id and x.kapanis is not null;
  v_son := coalesce(v_son, t - interval '1 day');
  select count(*) into n from oyun.kanunlar k where k.teklif_at > v_son;
  if n > 0 then m := m || format('%s kanun teklifi Başkanlığa sunulmuş ve ilgili komisyonlara havale edilmiştir. ', n); end if;
  if to_regclass('oyun.kom_kanun') is not null then
    execute 'select count(*) from oyun.kom_kanun where karar_at > $1 and karar in (''kabul'',''ret'')' into n using v_son;
    if n > 0 then m := m || format('%s teklif hakkında komisyon kararı Genel Kurula sunulmuştur. ', n); end if;
  end if;
  select count(*) into n from oyun.bakan_soru s where s.yanit_at > v_son;
  if n > 0 then m := m || format('%s yazılı soru önergesine Hükümet tarafından cevap verilmiştir. ', n); end if;
  select count(*) into n from oyun.bakan_soru s where s.yanit is null and s.zaman <= t - interval '15 days' and s.zaman > v_son - interval '15 days';
  if n > 0 then m := m || format('%s yazılı soru önergesi 15 günlük süresi içinde cevaplanmamıştır. ', n); end if;
  select count(*) into n from oyun.gk_genel_gorusme g where g.olusturma > v_son and g.durum <> 'geri';
  if n > 0 then m := m || format('%s genel görüşme önergesi Başkanlığa sunulmuştur. ', n); end if;
  if to_regclass('oyun.meclis_arastirma') is not null then
    execute 'select count(*) from oyun.meclis_arastirma where olusturma > $1' into n using v_son;
    if n > 0 then m := m || format('%s Meclis araştırması önergesi Başkanlığa sunulmuştur. ', n); end if;
  end if;
  if to_regclass('oyun.tbmm_dilekce') is not null then
    execute 'select count(*) from oyun.tbmm_dilekce where zaman > $1' into n using v_son;
    if n > 0 then m := m || format('Vatandaşlarımızdan %s dilekçe Dilekçe Komisyonuna havale edilmiştir. ', n); end if;
  end if;
  if m = '' then m := 'Başkanlığa sunulmuş yeni bir evrak bulunmamaktadır.'; end if;
  perform oyun.gk_yaz(b.id, 'sistem', null, 'Başkanlık Divanının sunuşları: ' || btrim(m), null, null, null, t);
end $f$;

create or replace function oyun.gk_madde_baslat(p_b bigint, p_g bigint, t timestamptz) returns void
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim; g oyun.gk_gundem; o oyun.gk_grup_onerisi; r record; n int := 0; lim int; v_kisa text; gg oyun.gk_genel_gorusme;
begin
  select * into b from oyun.gk_birlesim where id = p_b for update;
  select * into g from oyun.gk_gundem where id = p_g;
  if g.id is null or g.durum <> 'bekliyor' then return; end if;
  update oyun.gk_gundem set durum = 'gorusuluyor', bas = t where id = g.id;
  update oyun.gk_birlesim set aktif_gundem = g.id, kursu_bos = t where id = b.id;
  perform oyun.gk_yaz(b.id, 'gundem', null, g.baslik, jsonb_build_object('tur', g.tur, 'ref', g.ref_id), null, null, t);
  if g.tur = 'yemin' then
    if g.baslik like 'Andiçmeyen%' then
      perform oyun.gk_baskan(b.id, 'Henüz andiçmemiş milletvekillerimiz Anayasanın 81''inci maddesindeki andı içecekler. "Andiçiyorum" düğmesini kullanabilirler.', null, t);
    else
      perform oyun.gk_baskan(b.id, 'Yeni yasama döneminin ilk birleşimindeyiz. Milletvekillerimiz Anayasanın 81''inci maddesindeki andı içecekler. Sırası gelen milletvekilimiz "Andiçiyorum" düğmesiyle andını içer.', null, t);
    end if;
  elsif g.tur = 'sunus' then
    perform oyun.gk_sunus(b, t);
    perform oyun.gk_madde_bitir(b.id, g.id, t);
  elsif g.tur = 'gundem_disi' then
    lim := (select gundem_disi_sayi from oyun.gk_ayar where id = 1);
    -- Başkanın seçtikleri; eksikse istem sırasıyla, partiler dengeli doldurulur
    for r in with aday as (
                select d.*, pr.parti_id, row_number() over (partition by pr.parti_id order by d.istek) pn
                from oyun.gk_gundem_disi d join oyun.profiller pr on pr.id = d.user_id
                where d.gun = b.gun and d.durum in ('bekliyor', 'secildi') and oyun.gk_vekil(d.user_id))
             select * from aday order by (durum = 'secildi') desc, pn, istek limit lim loop
      n := n + 1;
      update oyun.gk_gundem_disi set durum = 'secildi' where id = r.id;
      insert into oyun.meclis_soz(user_id, tur, istek, otomatik, gk, birlesim_id, gundem_id, sira_no, konu)
      values (r.user_id, 'gundem_disi', t, oyun.gk_bitis(b), true, b.id, g.id, n, r.konu);
      perform oyun.bildir(r.user_id, format('Gündem dışı söz sırası sende (%s. konuşmacı): "%s". Genel Kurul salonuna gir.', n, r.konu), t);
    end loop;
    update oyun.gk_gundem_disi set durum = 'dustu' where gun = b.gun and durum = 'bekliyor';
    if n = 0 then perform oyun.gk_madde_bitir(b.id, g.id, t);
    else perform oyun.gk_baskan(b.id, format('Gündeme geçmeden önce %s sayın milletvekiline gündem dışı söz vereceğim.', n), null, t); end if;
  elsif g.tur = 'grup_onerisi' then
    select * into o from oyun.gk_grup_onerisi where id = g.ref_id for update;
    if o.id is null or o.durum <> 'bekliyor' then perform oyun.gk_madde_bitir(b.id, g.id, t); return; end if;
    update oyun.gk_grup_onerisi set durum = 'gorusuluyor', birlesim_id = b.id where id = o.id;
    select kisa into v_kisa from oyun.partiler where id = o.parti_id;
    perform oyun.gk_baskan(b.id, format('%s Grubunun İçtüzüğün 19''uncu maddesine göre verilmiş bir önerisi vardır, okutup işleme alacağım.', v_kisa), null, t);
    perform oyun.gk_yaz(b.id, 'sistem', null, format('Öneri (%s): %s', o.baslik, o.metin), jsonb_build_object('oneri', o.id), null, null, t);
    perform oyun.gk_baskan(b.id, 'Önerinin lehinde ve aleyhinde söz isteyen grup başkanvekillerine ve milletvekillerine söz vereceğim; ardından öneriyi oylarınıza sunacağım.', null, t);
  elsif g.tur = 'genel_gorusme_on' then
    select * into gg from oyun.gk_genel_gorusme where id = g.ref_id;
    if gg.id is null or gg.durum <> 'bekliyor' then perform oyun.gk_madde_bitir(b.id, g.id, t); return; end if;
    perform oyun.gk_yaz(b.id, 'sistem', null, format('Önerge (%s): %s', gg.konu, left(gg.gerekce, 1200)), jsonb_build_object('gg', gg.id), null, null, t);
    perform oyun.gk_baskan(b.id, 'Önerge sahibine, Hükümete ve gruplara söz vereceğim; ardından genel görüşme açılıp açılmamasını oylarınıza sunacağım.', null, t);
  elsif g.tur = 'genel_gorusme' then
    update oyun.gk_genel_gorusme set gorusme_birlesim = b.id where id = g.ref_id;
    perform oyun.gk_baskan(b.id, 'Genel görüşmeye başlıyoruz. Gruplara ve milletvekillerine sırayla söz vereceğim. Genel görüşme oylama yapılmadan tamamlanır.', null, t);
  elsif g.tur = 'kanun_oylama' then
    perform oyun.gk_baskan(b.id, 'Teklifin elektronik oylaması devam ediyor. Milletvekillerimizin oylarını salondaki oylama panosundan kullanmalarını rica ediyorum.', null, t);
  end if;
end $f$;

create or replace function oyun.gk_madde_bitir(p_b bigint, p_g bigint, t timestamptz) returns void
language plpgsql security definer set search_path to '' as $f$
declare g oyun.gk_gundem; nx bigint;
begin
  select * into g from oyun.gk_gundem where id = p_g for update;
  if g.id is null or g.durum = 'tamam' then return; end if;
  update oyun.gk_gundem set durum = 'tamam', bit = t where id = g.id;
  if g.tur = 'genel_gorusme' then
    update oyun.gk_genel_gorusme set durum = 'gorusuldu', sonuc_metin = format('Genel görüşme %s tarihli birleşimde yapıldı.', to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY'))
     where id = g.ref_id and durum = 'acildi';
    perform oyun.gk_baskan(p_b, 'Genel görüşme tamamlanmıştır.', null, t);
  elsif g.tur = 'gundem_disi' then
    update oyun.meclis_soz set durum = 'geri' where birlesim_id = p_b and gk and tur = 'gundem_disi' and durum = 'bekliyor';
  end if;
  update oyun.gk_birlesim set aktif_gundem = null, kursu_bos = t where id = p_b;
  select x.id into nx from oyun.gk_gundem x where x.birlesim_id = p_b and x.durum = 'bekliyor' order by x.sira limit 1;
  if nx is not null and (select durum from oyun.gk_birlesim where id = p_b) = 'acik' then perform oyun.gk_madde_baslat(p_b, nx, t); end if;
  perform oyun.gk_degisti();
end $f$;

-- ---------------------------------------------------------------- BİRLEŞİM AÇ / KAPAT
create or replace function oyun.gk_yoklama_baslat(p_b bigint, p_neden text, p_isteyen uuid, t timestamptz) returns bigint
language plpgsql security definer set search_path to '' as $f$
declare v_id bigint; dk int := (select yoklama_dk from oyun.gk_ayar where id = 1);
begin
  update oyun.gk_yoklama set sonuc = 'yok' where birlesim_id = p_b and sonuc = 'acik';
  insert into oyun.gk_yoklama(birlesim_id, bas, bit, neden, isteyen, yeter) values (p_b, t, t + make_interval(mins => dk), p_neden, p_isteyen, oyun.gk_toplanti_yeter())
  returning id into v_id;
  update oyun.gk_birlesim set durum = 'yoklama' where id = p_b;
  perform oyun.gk_baskan(p_b, format('Elektronik cihazla yoklama yapacağız. Yoklama için %s dakika süre veriyorum. Bu süre içinde salondaki "Buradayım" düğmesine basmayan üyelerimizin yoklama pusulası salonda bulunduklarına göre düzenlenecektir.', dk), null, t);
  perform oyun.gk_vekillere_bildir(format('Zil çaldı: TBMM Genel Kurulunda yoklama var (%s dk). Salona gir ve "Buradayım" de.', dk), t);
  return v_id;
end $f$;

create or replace function oyun.gk_ac(p_b bigint, t timestamptz, p_u uuid) returns void
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim; d bigint := oyun.gk_donem(); n int;
begin
  select * into b from oyun.gk_birlesim where id = p_b for update;
  if b.id is null or b.durum <> 'planli' then return; end if;
  select count(*) + 1 into n from oyun.gk_birlesim x where x.donem is not distinct from d and x.acilis is not null;
  update oyun.gk_birlesim set durum = 'yoklama', acilis = t, no = n, donem = d, yoneten = p_u, kursu_bos = t where id = b.id returning * into b;
  perform oyun.gk_baskan(b.id, format('Türkiye Büyük Millet Meclisinin %s Birleşimini açıyorum.', oyun.gk_sira(n)), p_u, t);
  perform oyun.gk_gundem_kur(b, t);
  perform oyun.gk_yoklama_baslat(b.id, 'acilis', null, t);
  -- Sohbetten (eski uygulama) istenmiş sözler sıraya alınır
  update oyun.meclis_soz set gk = true, birlesim_id = b.id, otomatik = oyun.gk_bitis(b), sira_no = extract(epoch from istek)
   where not gk and durum = 'bekliyor' and istek > t - interval '1 hour';
end $f$;

create or replace function oyun.gk_ozet(p_b bigint) returns jsonb
language sql stable set search_path to '' as $f$
  with k as (select t.* from oyun.gk_tutanak t where t.birlesim_id = p_b and t.tur = 'konusma' and not t.gizli),
  a as (select t.soz_id, min(t.id) tid, min(t.user_id::text)::uuid u, min(t.ad) ad, min(t.parti_kisa) kisa, min(t.il) il,
               (select count(*) from oyun.gk_tepki x join oyun.gk_tutanak y on y.id = x.tutanak_id where y.soz_id = t.soz_id and x.tur = 'alkis' and x.vekil) alkis,
               (select left(string_agg(y.metin, ' ' order by y.id), 160) from oyun.gk_tutanak y where y.soz_id = t.soz_id and y.tur = 'konusma' and not y.gizli) alinti
        from k t where t.soz_id is not null group by t.soz_id)
  select jsonb_build_object(
    'konusma', (select count(distinct coalesce(soz_id, id)) from k),
    'konusan', (select count(distinct user_id) from k),
    'laf', (select count(*) from oyun.gk_tutanak t where t.birlesim_id = p_b and t.tur = 'laf' and not t.gizli),
    'alkis', (select count(*) from oyun.gk_tepki x join oyun.gk_tutanak y on y.id = x.tutanak_id where y.birlesim_id = p_b and x.tur = 'alkis'),
    'hatip', (select jsonb_build_object('ad', a.ad, 'kisa', a.kisa, 'il', a.il, 'alkis', a.alkis, 'alinti', a.alinti) from a where a.alkis > 0 order by a.alkis desc, a.tid limit 1),
    'oylamalar', coalesce((select jsonb_agg(jsonb_build_object('baslik', o.baslik, 'durum', o.durum, 'kabul', o.kabul, 'ret', o.ret, 'cekimser', o.cekimser) order by o.id)
                           from oyun.gk_oylama o where o.birlesim_id = p_b and o.durum <> 'iptal'), '[]'::jsonb),
    'yoklama', (select y.sayi from oyun.gk_yoklama y where y.birlesim_id = p_b and y.sayi is not null order by y.id desc limit 1),
    'yemin', (select count(*) from oyun.gk_yemin y where y.birlesim_id = p_b),
    'salon', (select b.salon_azami from oyun.gk_birlesim b where b.id = p_b),
    'izleyici', (select count(*) from oyun.gk_salonda s where s.birlesim_id = p_b and not s.vekil),
    'sure_dk', (select round(extract(epoch from (coalesce(b.kapanis, now()) - b.acilis)) / 60) from oyun.gk_birlesim b where b.id = p_b))
$f$;

create or replace function oyun.gk_kapat(p_b bigint, t timestamptz, p_neden text) returns void
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim; z jsonb; v_sonraki timestamptz; v_baslik text; v_ozet text; v_metin text; a oyun.gk_ayar;
begin
  select * into a from oyun.gk_ayar where id = 1;
  select * into b from oyun.gk_birlesim where id = p_b for update;
  if b.id is null or b.durum not in ('yoklama', 'acik', 'arada') then return; end if;
  v_sonraki := ((oyun.gk_gun(t) + 1) + a.olagan_bas) at time zone 'Europe/Istanbul';
  if p_neden = 'sure' then
    perform oyun.gk_baskan(b.id, format('Gündemdeki konuları sırasıyla görüşmek için %s günü saat %s''de toplanmak üzere birleşimi kapatıyorum.',
      to_char(v_sonraki at time zone 'Europe/Istanbul', 'DD.MM.YYYY'), to_char(a.olagan_bas, 'HH24.MI')), null, t);
  elsif p_neden = 'karar' then
    perform oyun.gk_baskan(b.id, 'Karar yeter sayısı bir kez daha bulunamadığından, gündemdeki konuları sırasıyla görüşmek için birleşimi kapatıyorum.', null, t);
  elsif p_neden = 'toplanamadi' then
    perform oyun.gk_baskan(b.id, 'Toplantı yeter sayısı bulunamadığından, gündemdeki konuları sırasıyla görüşmek için birleşimi kapatıyorum.', null, t);
  end if;
  update oyun.meclis_soz set durum = case when durum = 'verildi' and kelime_kullanilan > 0 then 'kullanildi' else 'geri' end,
         kullanildi = case when durum = 'verildi' and kelime_kullanilan > 0 then coalesce(kullanildi, t) else kullanildi end
   where birlesim_id = b.id and gk and durum in ('bekliyor', 'verildi');
  update oyun.gk_oylama set durum = 'iptal' where birlesim_id = b.id and durum = 'acik';
  update oyun.gk_yoklama set sonuc = 'yok' where birlesim_id = b.id and sonuc = 'acik';
  update oyun.gk_gundem set durum = 'tamam', bit = coalesce(bit, t) where birlesim_id = b.id and durum = 'gorusuluyor';
  update oyun.gk_grup_onerisi set durum = 'dustu' where gun = b.gun and durum in ('bekliyor', 'gorusuluyor');
  update oyun.gk_gundem_disi set durum = 'dustu' where gun = b.gun and durum in ('bekliyor', 'secildi');
  update oyun.gk_birlesim set durum = case when p_neden = 'toplanamadi' then 'toplanamadi' else 'kapandi' end, kapanis = t,
         aktif_gundem = null, kapali = false where id = b.id;
  z := oyun.gk_ozet(b.id);
  update oyun.gk_birlesim set ozet = z, haber_at = t where id = b.id;
  if p_neden = 'toplanamadi' then
    v_baslik := format('TBMM Genel Kurulu toplanamadı: %s Birleşimde yeter sayı bulunamadı', oyun.gk_sira(coalesce(b.no, 1)));
    v_ozet := format('Yoklamada %s milletvekili hazır bulundu; %s gerekiyordu.', coalesce((z ->> 'yoklama'), '0'), oyun.gk_toplanti_yeter());
    v_metin := v_ozet || ' Birleşim, toplantı yeter sayısı bulunamadığı için kapandı. Hangi milletvekillerinin salonda olduğu Genel Kurul tutanağında herkese açıktır.';
  else
    v_baslik := format('TBMM Genel Kurulu %s Birleşimini tamamladı: %s konuşma, %s oylama', oyun.gk_sira(coalesce(b.no, 1)), z ->> 'konusma', jsonb_array_length(z -> 'oylamalar'));
    v_ozet := coalesce(format('Günün hatibi: %s%s — %s alkış', z -> 'hatip' ->> 'ad', coalesce(' (' || (z -> 'hatip' ->> 'kisa') || ')', ''), z -> 'hatip' ->> 'alkis'),
                     format('%s milletvekili kürsüye çıktı.', z ->> 'konusan'));
    v_metin := format('Genel Kurulda bugün %s milletvekili kürsüye çıktı, %s konuşma yapıldı, sıralardan %s kez söz atıldı ve konuşmacılar toplam %s alkış aldı.',
                    z ->> 'konusan', z ->> 'konusma', z ->> 'laf', z ->> 'alkis')
      || coalesce(format(' Günün en çok alkışlanan konuşması %s%s milletvekili %s''e aitti: "%s…"', coalesce((z -> 'hatip' ->> 'il') || ' ', ''),
                         coalesce((z -> 'hatip' ->> 'kisa') || ' ', ''), z -> 'hatip' ->> 'ad', z -> 'hatip' ->> 'alinti'), '')
      || coalesce((select ' Oylamalar: ' || string_agg(format('%s — %s (%s kabul, %s ret)', x ->> 'baslik',
                     case x ->> 'durum' when 'kabul' then 'kabul edildi' when 'ret' then 'reddedildi' else 'karar yeter sayısı bulunamadı' end,
                     x ->> 'kabul', x ->> 'ret'), '; ') || '.' from jsonb_array_elements(z -> 'oylamalar') x), '')
      || case when (z ->> 'yemin')::int > 0 then format(' %s milletvekili andiçti.', z ->> 'yemin') else '' end;
  end if;
  perform oyun.ajans_yayinla('tbmm-birlesim-' || b.id, 'meclis', v_baslik, v_ozet, v_metin, 70, null, null, t);
  perform oyun.gk_degisti();
end $f$;

-- ---------------------------------------------------------------- SÖZ VERME / BİTİRME
create or replace function oyun.gk_soz_baslat(p_b bigint, p_soz bigint, p_veren uuid, t timestamptz) returns void
language plpgsql security definer set search_path to '' as $f$
declare s oyun.meclis_soz; k jsonb; m text; v_ad text;
begin
  select * into s from oyun.meclis_soz where id = p_soz for update;
  if s.id is null or s.durum <> 'bekliyor' then return; end if;
  update oyun.meclis_soz set durum = 'verildi', veren = p_veren, verildi = t, kursu_bas = null, kursu_bit = t + interval '90 seconds', birlesim_id = p_b, gk = true
   where id = s.id;
  k := oyun.gk_kimlik(s.user_id);
  v_ad := coalesce(k ->> 'ad', '');
  m := case s.tur
    when 'grup' then format('%s Grubu adına Sayın %s, buyurun.', coalesce(k ->> 'kisa', ''), v_ad)
    when 'hukumet' then format('Hükümet adına %s Sayın %s, buyurun.', coalesce(k ->> 'rol', ''), v_ad)
    when 'yerinden' then format('Sayın %s, yerinizden bir dakika söz veriyorum.', v_ad)
    when 'satasma' then format('Sayın %s, sataşma nedeniyle iki dakika söz veriyorum; lütfen yeni bir sataşmaya mahal vermeyelim.', v_ad)
    when 'usul' then format('Sayın %s, usul hakkında buyurun.', v_ad)
    when 'gundem_disi' then format('Gündem dışı söz isteyen %sSayın %s: "%s". Buyurun.', coalesce((k ->> 'il') || ' Milletvekili ', ''), v_ad, coalesce(s.konu, ''))
    else format('Şahsı adına %sSayın %s, buyurun.', coalesce((k ->> 'il') || ' Milletvekili ', ''), v_ad) end;
  perform oyun.gk_baskan(p_b, m, p_veren, t);
  perform oyun.bildir(s.user_id, format('Söz sende! Genel Kurul kürsüsüne çık: %s. 90 saniye içinde konuşmaya başlamazsan söz sırası düşer.',
    (select ad from oyun.gk_soz_tur() where kod = s.tur)), t);
end $f$;

create or replace function oyun.gk_soz_kapat(p_soz bigint, t timestamptz, p_neden text) returns void
language plpgsql security definer set search_path to '' as $f$
declare s oyun.meclis_soz; v_ad text;
begin
  select * into s from oyun.meclis_soz where id = p_soz for update;
  if s.id is null or s.durum <> 'verildi' then return; end if;
  v_ad := oyun.gk_kimlik(s.user_id) ->> 'ad';
  if s.kelime_kullanilan = 0 then
    update oyun.meclis_soz set durum = 'geri' where id = s.id;
    if p_neden = 'sure' then
      perform oyun.gk_baskan(s.birlesim_id, format('Sayın %s salonda bulunmadığından söz sırası düşmüştür.', v_ad), null, t);
    end if;
  else
    update oyun.meclis_soz set durum = 'kullanildi', kullanildi = t where id = s.id;
    if p_neden = 'sure' then
      perform oyun.gk_yaz(s.birlesim_id, 'sistem', null, '(Mikrofon otomatik cihaz tarafından kapatıldı)', jsonb_build_object('soz', s.id), s.id, s.tur, t);
    elsif p_neden = 'kes' then
      perform oyun.gk_yaz(s.birlesim_id, 'sistem', null, '(Mikrofon Başkanlıkça kapatıldı)', jsonb_build_object('soz', s.id), s.id, s.tur, t);
    end if;
    if s.tur = 'gundem_disi' then update oyun.gk_gundem_disi set durum = 'konustu' where user_id = s.user_id and durum = 'secildi'; end if;
  end if;
  update oyun.gk_birlesim set kursu_bos = t where id = s.birlesim_id;
  perform oyun.gk_degisti();
end $f$;

-- ---------------------------------------------------------------- YOKLAMA ve OYLAMA SONUCU
create or replace function oyun.gk_yoklama_sonuc(p_y bigint, t timestamptz) returns void
language plpgsql security definer set search_path to '' as $f$
declare y oyun.gk_yoklama; b oyun.gk_birlesim; n int; ytr int; a oyun.gk_ayar;
begin
  select * into a from oyun.gk_ayar where id = 1;
  select * into y from oyun.gk_yoklama where id = p_y for update;
  if y.id is null or y.sonuc <> 'acik' then return; end if;
  select * into b from oyun.gk_birlesim where id = y.birlesim_id for update;
  -- Salonu açık tutan vekiller için pusula
  insert into oyun.gk_yoklama_kayit(yoklama_id, user_id, zaman, pusula)
  select y.id, s.user_id, t, true from oyun.gk_salonda s
  where s.birlesim_id = b.id and s.vekil and s.son >= y.bas - interval '30 seconds' and oyun.gk_vekil(s.user_id)
    and not oyun.gk_cikarilmis(s.user_id, b)
  on conflict do nothing;
  insert into oyun.meclis_yoklama(gun, user_id, zaman)
  select b.gun, k.user_id, t from oyun.gk_yoklama_kayit k where k.yoklama_id = y.id on conflict do nothing;
  select count(*) into n from oyun.gk_yoklama_kayit k where k.yoklama_id = y.id;
  ytr := oyun.gk_toplanti_yeter();
  update oyun.gk_yoklama set sayi = n, yeter = ytr, sonuc = case when n >= ytr then 'var' else 'yok' end where id = y.id;
  perform oyun.gk_yaz(b.id, 'yoklama', null, format('Yoklama sonucu: %s milletvekili hazır. Toplantı yeter sayısı %s.', n, ytr),
    jsonb_build_object('yoklama', y.id, 'sayi', n, 'yeter', ytr), null, null, t);
  if n >= ytr then
    update oyun.gk_birlesim set durum = 'acik', yeter = true, yoklama_hata = 0, kursu_bos = t where id = b.id;
    if y.neden in ('acilis', 'tekrar') and b.aktif_gundem is null and not exists (select 1 from oyun.gk_gundem g where g.birlesim_id = b.id and g.durum <> 'bekliyor') then
      perform oyun.gk_baskan(b.id, 'Toplantı yeter sayısı vardır, görüşmelere başlıyoruz.', null, t);
      perform oyun.gk_madde_baslat(b.id, (select g.id from oyun.gk_gundem g where g.birlesim_id = b.id and g.durum = 'bekliyor' order by g.sira limit 1), t);
    else
      perform oyun.gk_baskan(b.id, 'Toplantı yeter sayısı vardır, görüşmelere kaldığımız yerden devam ediyoruz.', null, t);
    end if;
  elsif b.yoklama_hata = 0 then
    update oyun.gk_birlesim set durum = 'arada', ara_bit = t + make_interval(mins => a.ara_dk), ara_neden = 'yoklama', yoklama_hata = 1, yeter = false where id = b.id;
    perform oyun.gk_baskan(b.id, format('Toplantı yeter sayısı bulunamamıştır. Birleşime %s dakika ara veriyorum.', a.ara_dk), null, t);
    perform oyun.gk_vekillere_bildir(format('TBMM Genel Kurulunda toplantı yeter sayısı bulunamadı (%s/%s). %s dakika sonra yoklama yenilenecek; salona gel.', n, ytr, a.ara_dk), t);
  else
    perform oyun.gk_kapat(b.id, t, 'toplanamadi');
  end if;
  perform oyun.gk_degisti();
end $f$;

create or replace function oyun.gk_oylama_ac(p_b bigint, p_konu text, p_ref bigint, p_baslik text, p_acan uuid, t timestamptz, p_tekrar boolean default false) returns bigint
language plpgsql security definer set search_path to '' as $f$
declare v_id bigint; dk int := (select oylama_dk from oyun.gk_ayar where id = 1); b oyun.gk_birlesim;
begin
  select * into b from oyun.gk_birlesim where id = p_b;
  if exists (select 1 from oyun.gk_oylama o where o.birlesim_id = p_b and o.durum = 'acik') then raise exception 'Salonda zaten açık bir oylama var.'; end if;
  insert into oyun.gk_oylama(birlesim_id, gundem_id, konu, ref_id, baslik, bas, bit, acan, tekrar, yeter_istendi)
  values (p_b, b.aktif_gundem, p_konu, p_ref, left(p_baslik, 220), t, t + make_interval(mins => dk), p_acan, p_tekrar, p_tekrar)
  returning id into v_id;
  perform oyun.gk_baskan(p_b, format('%s oylarınıza sunuyorum: Kabul edenler… Kabul etmeyenler… Oylama %s dakika açıktır.', p_baslik, dk), p_acan, t);
  perform oyun.gk_vekillere_bildir(format('Zil çaldı: Genel Kurulda oylama var — %s (%s dk). Salona gir, oyunu kullan.', left(p_baslik, 90), dk), t, p_acan);
  return v_id;
end $f$;

create or replace function oyun.gk_oylama_sonuc(p_o bigint, t timestamptz) returns void
language plpgsql security definer set search_path to '' as $f$
declare o oyun.gk_oylama; b oyun.gk_birlesim; a int; r int; c int; ky int; v_kabul boolean; gg oyun.gk_grup_onerisi; d oyun.gk_disiplin;
  v_ara int := 5; g bigint; v_kisa text;
begin
  select * into o from oyun.gk_oylama where id = p_o for update;
  if o.id is null or o.durum <> 'acik' then return; end if;
  select * into b from oyun.gk_birlesim where id = o.birlesim_id for update;
  select count(*) filter (where x.oy = 'kabul'), count(*) filter (where x.oy = 'ret'), count(*) filter (where x.oy = 'cekimser')
    into a, r, c from oyun.gk_oy x where x.oylama_id = o.id;
  ky := oyun.gk_karar_yeter();
  if o.yeter_istendi and a + r + c < ky then
    update oyun.gk_oylama set durum = 'yetersiz', kabul = a, ret = r, cekimser = c, yeter = ky where id = o.id;
    perform oyun.gk_yaz(b.id, 'oylama', null, format('%s — Karar yeter sayısı bulunamamıştır (%s oy kullanıldı, en az %s gerekiyordu).', o.baslik, a + r + c, ky),
      jsonb_build_object('oylama', o.id, 'kabul', a, 'ret', r, 'cekimser', c, 'sonuc', 'yetersiz'), null, null, t);
    if o.tekrar then
      perform oyun.gk_kapat(b.id, t, 'karar');
    else
      update oyun.gk_birlesim set durum = 'arada', ara_bit = t + make_interval(mins => v_ara), ara_neden = 'karar:' || o.id where id = b.id;
      perform oyun.gk_baskan(b.id, format('Birleşime %s dakika ara veriyorum; aradan sonra oylamayı tekrarlayacağım.', v_ara), null, t);
    end if;
    perform oyun.gk_degisti();
    return;
  end if;
  v_kabul := a > r;  -- eşitlikte reddedilmiş sayılır
  update oyun.gk_oylama set durum = case when v_kabul then 'kabul' else 'ret' end, kabul = a, ret = r, cekimser = c, yeter = ky where id = o.id;
  perform oyun.gk_yaz(b.id, 'oylama', null, format('%s — %s (Kabul: %s · Ret: %s · Çekimser: %s)', o.baslik, case when v_kabul then 'Kabul edilmiştir.' else 'Kabul edilmemiştir.' end, a, r, c),
    jsonb_build_object('oylama', o.id, 'kabul', a, 'ret', r, 'cekimser', c, 'sonuc', case when v_kabul then 'kabul' else 'ret' end), null, null, t);
  if o.konu = 'grup_onerisi' then
    select * into gg from oyun.gk_grup_onerisi where id = o.ref_id for update;
    update oyun.gk_grup_onerisi set durum = case when v_kabul then 'kabul' else 'ret' end, oylama_id = o.id where id = gg.id;
    select kisa into v_kisa from oyun.partiler where id = gg.parti_id;
    if v_kabul and gg.tur = 'uzatma' then
      if b.uzatma < (select uzatma_azami from oyun.gk_ayar where id = 1) then
        update oyun.gk_birlesim set uzatma = uzatma + 1 where id = b.id;
        perform oyun.gk_baskan(b.id, format('Çalışma süremiz %s dakika uzatılmıştır.', (select uzatma_dk from oyun.gk_ayar where id = 1)), null, t);
      end if;
    elsif v_kabul and gg.tur = 'gundem' then
      select x.id into g from oyun.gk_gundem x where x.birlesim_id = b.id and x.durum = 'bekliyor' and x.tur in ('kanun', 'kanun_oylama') and x.ref_id = gg.ref_id order by x.sira limit 1;
      if g is null then
        g := oyun.gk_madde_ekle(b.id, case when (select durum from oyun.kanunlar where id = gg.ref_id) in ('oylamada', 'israr') then 'kanun_oylama' else 'kanun' end, gg.ref_id,
               coalesce((select baslik from oyun.kanunlar where id = gg.ref_id), gg.baslik) || ' — grup önerisiyle gündemin başına alındı');
      end if;
      if g is not null then
        update oyun.gk_gundem set sira = -1 * (select count(*) from oyun.gk_gundem where birlesim_id = b.id) where id = g;
      end if;
    elsif v_kabul and gg.tur = 'bildiri' then
      perform oyun.ajans_yayinla('tbmm-bildiri-' || gg.id, 'meclis', format('TBMM Genel Kurulu ortak bildiri kabul etti: %s', gg.baslik),
        format('%s Grubunun önerisi %s kabul, %s ret oyla kabul edildi.', v_kisa, a, r), gg.metin, 75, gg.parti_id, null, t);
      perform oyun.olay('meclis', format('TBMM ortak bildiri kabul etti: "%s".', gg.baslik), null, gg.parti_id, t);
    elsif v_kabul and gg.tur = 'genel_gorusme' and gg.ref_id is not null then
      update oyun.gk_genel_gorusme set durum = 'acildi', karar_at = t where id = gg.ref_id and durum in ('bekliyor', 'imza');
      perform oyun.gk_madde_ekle(b.id, 'genel_gorusme', gg.ref_id, format('Genel görüşme: %s', (select konu from oyun.gk_genel_gorusme where id = gg.ref_id)));
    end if;
    perform oyun.bildir(gg.veren, format('Grup önerin ("%s") Genel Kurulda %s (%s kabul, %s ret).', gg.baslik, case when v_kabul then 'kabul edildi' else 'reddedildi' end, a, r), t);
  elsif o.konu = 'genel_gorusme' then
    update oyun.gk_genel_gorusme set durum = case when v_kabul then 'acildi' else 'ret' end, karar_at = t,
           sonuc_metin = case when v_kabul then null else format('Genel Kurul genel görüşme açılmasını kabul etmedi (%s kabul, %s ret).', a, r) end
     where id = o.ref_id and durum = 'bekliyor';
    if v_kabul then
      perform oyun.gk_madde_ekle(b.id, 'genel_gorusme', o.ref_id, format('Genel görüşme: %s', (select konu from oyun.gk_genel_gorusme where id = o.ref_id)));
    end if;
    perform oyun.bildir((select veren from oyun.gk_genel_gorusme where id = o.ref_id),
      format('Genel görüşme önergen %s (%s kabul, %s ret).', case when v_kabul then 'kabul edildi; görüşme gündeme alındı' else 'reddedildi' end, a, r), t);
  elsif o.konu = 'uzatma' then
    if v_kabul and b.uzatma < (select uzatma_azami from oyun.gk_ayar where id = 1) then
      update oyun.gk_birlesim set uzatma = uzatma + 1 where id = b.id;
      perform oyun.gk_baskan(b.id, format('Çalışma süremiz %s dakika uzatılmıştır.', (select uzatma_dk from oyun.gk_ayar where id = 1)), null, t);
    end if;
  elsif o.konu = 'kapali_oturum' then
    if v_kabul then
      update oyun.gk_birlesim set kapali = true where id = b.id;
      perform oyun.gk_baskan(b.id, 'Kapalı oturuma geçilmesi kabul edilmiştir. Salondaki izleyicilerin ve basın mensuplarının salonu terk etmelerini rica ediyorum. Bu bölümün tutanağı gizlidir.', null, t);
    end if;
  elsif o.konu = 'disiplin' then
    select * into d from oyun.gk_disiplin where id = o.ref_id for update;
    if v_kabul then
      update oyun.gk_disiplin set durum = 'uygulandi', bit = t + interval '30 days',
             son_no = case when d.tur = 'cikarma' then coalesce(b.no, 0) + greatest(1, d.birlesim_sayi) - 1 end where id = d.id;
      perform oyun.bildir(d.user_id, case when d.tur = 'kinama'
        then 'Genel Kurul sana kınama cezası verdi: 30 gün süreyle milletvekili ödeneğinin üçte biri kesilecek.'
        else format('Genel Kurul seni %s birleşim için Meclisten geçici olarak çıkardı: bu süre Genel Kurul salonuna giremezsin; 30 gün ödeneğinin üçte ikisi kesilecek.', greatest(1, d.birlesim_sayi)) end, t);
      if d.tur = 'cikarma' then
        update oyun.meclis_soz set durum = 'geri' where birlesim_id = b.id and gk and user_id = d.user_id and durum in ('bekliyor', 'verildi');
      end if;
    else
      update oyun.gk_disiplin set durum = 'ret' where id = d.id;
    end if;
  end if;
  update oyun.gk_birlesim set kursu_bos = t where id = b.id;
  -- Oylamayla karara bağlanan gündem maddesi tamamlanır
  if o.konu in ('grup_onerisi', 'genel_gorusme') and o.gundem_id is not null then perform oyun.gk_madde_bitir(b.id, o.gundem_id, t); end if;
  perform oyun.gk_degisti();
end $f$;

-- ---------------------------------------------------------------- MOTOR
create or replace function oyun.gk_ilerlet(t timestamptz default null) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare a oyun.gk_ayar; b oyun.gk_birlesim; g oyun.gk_gundem; s oyun.meclis_soz; q oyun.meclis_soz; y oyun.gk_yoklama; o oyun.gk_oylama;
  v_gun date; yon uuid; bos timestamptz; v_sonraki timestamptz; i int; isler int := 0; v_oy bigint; v_ref bigint; v_baslik text;
begin
  t := coalesce(t, oyun.simdi());
  if not pg_try_advisory_xact_lock(hashtext('gk_ilerlet')) then return jsonb_build_object('mesgul', true); end if;
  select * into a from oyun.gk_ayar where id = 1;
  if not coalesce(a.aktif, false) then return jsonb_build_object('kapali', true); end if;

  -- 1) Bugünün ve yarının olağan birleşimi (Meclis'te vekil varsa; genel seçim günlerinde toplanılmaz)
  if oyun.dolu_sandalye() > 0 then
    for i in 0..1 loop
      v_gun := oyun.gk_gun(t) + i;
      if not exists (select 1 from oyun.secimler x where x.tur in ('mv', 'cb') and x.durum <> 'tamam' and oyun.gk_gun(x.oy_bas) = v_gun) then
        insert into oyun.gk_birlesim(tur, gun, plan_bas, plan_bit)
        values ('olagan', v_gun, (v_gun + a.olagan_bas) at time zone 'Europe/Istanbul', (v_gun + a.olagan_bit) at time zone 'Europe/Istanbul')
        on conflict do nothing;
      end if;
    end loop;
  end if;

  -- 2) Zamanı gelen birleşim açılır (Başkanlık çevrimiçiyse 5 dakika açmasını bekler)
  for b in select * from oyun.gk_birlesim x where x.durum = 'planli' and x.plan_bas <= t order by x.plan_bas limit 3 loop
    begin
      if b.plan_bit <= t or oyun.dolu_sandalye() = 0 or exists (select 1 from oyun.gk_birlesim z where z.durum in ('yoklama', 'acik', 'arada')) then
        update oyun.gk_birlesim set durum = 'iptal' where id = b.id and (b.plan_bit <= t or oyun.dolu_sandalye() = 0);
        continue;
      end if;
      if t < b.plan_bas + interval '5 minutes' and exists (
          select 1 from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
          where m.bit is null and m.tur in ('tbmm', 'bskv') and pr.son_gorulme > t - interval '3 minutes') then
        continue;
      end if;
      perform oyun.gk_ac(b.id, t, null);
      isler := isler + 1;
    exception when others then raise warning 'gk_ac %: %', b.id, sqlerrm;
    end;
  end loop;

  -- 3) Süren birleşim
  b := oyun.gk_su_an();
  if b.id is not null then
    begin
      yon := oyun.gk_yoneten_salonda(b.id, t);
      if b.durum = 'yoklama' then
        select * into y from oyun.gk_yoklama where birlesim_id = b.id and sonuc = 'acik' order by id desc limit 1;
        if y.id is null then
          update oyun.gk_birlesim set durum = 'acik' where id = b.id;
        elsif y.bit <= t then
          perform oyun.gk_yoklama_sonuc(y.id, t); isler := isler + 1;
        end if;
      elsif b.durum = 'arada' then
        if b.ara_bit <= t then
          update oyun.gk_birlesim set durum = 'acik', ara_bit = null, kursu_bos = t where id = b.id;
          if b.ara_neden = 'yoklama' then
            perform oyun.gk_baskan(b.id, 'Birleşimin ikinci oturumunu açıyorum. Yoklamayı yenileyeceğim.', null, t);
            perform oyun.gk_yoklama_baslat(b.id, 'tekrar', null, t);
          elsif b.ara_neden like 'karar:%' then
            select * into o from oyun.gk_oylama where id = substr(b.ara_neden, 7)::bigint;
            perform oyun.gk_baskan(b.id, 'Birleşimin oturumunu açıyorum. Karar yeter sayısı bulunamayan oylamayı tekrarlayacağım.', null, t);
            v_oy := oyun.gk_oylama_ac(b.id, o.konu, o.ref_id, o.baslik, null, t, true);
            update oyun.gk_oylama set gundem_id = o.gundem_id where id = v_oy;
          else
            perform oyun.gk_baskan(b.id, 'Birleşimin oturumunu açıyorum.', null, t);
          end if;
          isler := isler + 1;
        end if;
      elsif b.durum = 'acik' then
        -- süre doldu mu (kürsüdeki konuşmacı en çok 5 dk taşabilir)
        select * into s from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi' order by x.verildi desc limit 1;
        if t >= oyun.gk_bitis(b) and (s.id is null or coalesce(s.kursu_bit, s.verildi + interval '90 seconds') <= t or t >= oyun.gk_bitis(b) + interval '5 minutes') then
          perform oyun.gk_kapat(b.id, t, 'sure');
          isler := isler + 1;
        else
          -- açık oylama
          select * into o from oyun.gk_oylama where birlesim_id = b.id and durum = 'acik' order by id desc limit 1;
          if o.id is not null and o.bit <= t then perform oyun.gk_oylama_sonuc(o.id, t); isler := isler + 1; o := null; end if;
          -- kürsü süresi
          if s.id is not null and coalesce(s.kursu_bit, s.verildi + interval '90 seconds') <= t then
            perform oyun.gk_soz_kapat(s.id, t, 'sure'); isler := isler + 1; s := null;
          end if;
          select * into b from oyun.gk_birlesim where id = b.id;
          if b.durum = 'acik' and s.id is null and (o.id is null or o.durum <> 'acik') and not exists (select 1 from oyun.gk_oylama x where x.birlesim_id = b.id and x.durum = 'acik') then
            bos := coalesce(b.kursu_bos, b.acilis);
            select * into g from oyun.gk_gundem where id = b.aktif_gundem;
            select * into q from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'bekliyor'
              order by (x.tur = 'gundem_disi') desc, x.sira_no nulls last, x.id limit 1;
            if q.id is not null then
              if yon is null or t >= bos + interval '90 seconds' or (q.tur = 'gundem_disi' and t >= bos + interval '20 seconds') then
                perform oyun.gk_soz_baslat(b.id, q.id, null, t); isler := isler + 1;
              end if;
            elsif g.id is not null then
              if g.tur in ('grup_onerisi', 'genel_gorusme_on') and not exists (select 1 from oyun.gk_oylama x where x.gundem_id = g.id) then
                if t >= bos + (case when yon is null then interval '90 seconds' else interval '3 minutes' end) and t >= g.bas + interval '2 minutes' then
                  if g.tur = 'grup_onerisi' then
                    v_baslik := format('%s Grubunun önerisini', coalesce((select pa.kisa from oyun.gk_grup_onerisi x join oyun.partiler pa on pa.id = x.parti_id where x.id = g.ref_id), ''));
                    v_oy := oyun.gk_oylama_ac(b.id, 'grup_onerisi', g.ref_id, v_baslik, null, t);
                  else
                    v_oy := oyun.gk_oylama_ac(b.id, 'genel_gorusme', g.ref_id, 'Genel görüşme açılıp açılmamasını', null, t);
                  end if;
                  isler := isler + 1;
                end if;
              elsif g.tur = 'gundem_disi' then
                if t >= bos + interval '20 seconds' then perform oyun.gk_madde_bitir(b.id, g.id, t); isler := isler + 1; end if;
              elsif g.tur = 'yemin' then
                if /*GK_YEMIN2*/ (g.baslik like 'Andiçmeyen%' and t >= g.bas + interval '2 minutes' and t >= bos + interval '60 seconds')
                   or (t >= g.bas + interval '15 minutes' and t >= bos + (case when yon is null then interval '3 minutes' else interval '5 minutes' end)) then
                  perform oyun.gk_madde_bitir(b.id, g.id, t); isler := isler + 1;
                end if;
              elsif g.tur <> 'serbest' then
                if t >= bos + (case when yon is null then interval '150 seconds' else interval '5 minutes' end) then
                  perform oyun.gk_madde_bitir(b.id, g.id, t); isler := isler + 1;
                end if;
              end if;
            elsif exists (select 1 from oyun.gk_gundem x where x.birlesim_id = b.id and x.durum = 'bekliyor') then
              perform oyun.gk_madde_baslat(b.id, (select x.id from oyun.gk_gundem x where x.birlesim_id = b.id and x.durum = 'bekliyor' order by x.sira limit 1), t);
            end if;
          end if;
        end if;
      end if;
    exception when others then raise warning 'gk_ilerlet %: %', b.id, sqlerrm;
    end;
  end if;

  -- 4) Genel görüşme önergelerinin imza süresi ve kadük olanlar
  update oyun.gk_genel_gorusme set durum = 'dustu', sonuc_metin = 'Yeterli imza toplanamadı.' where durum = 'imza' and imza_bit <= t;
  update oyun.gk_genel_gorusme set durum = 'dustu', sonuc_metin = 'Yedi gün içinde Genel Kurulda ön görüşmesi yapılamadığı için düştü.'
   where durum = 'bekliyor' and olusturma <= t - interval '7 days';

  -- 5) Bir sonraki iş zamanı
  b := oyun.gk_su_an();
  select least(
      (select min(x.plan_bas) from oyun.gk_birlesim x where x.durum = 'planli' and x.plan_bas > t - interval '1 minute'),
      case when b.id is not null then least(
        case when b.durum = 'arada' then b.ara_bit end,
        case when b.durum = 'yoklama' then (select min(y2.bit) from oyun.gk_yoklama y2 where y2.birlesim_id = b.id and y2.sonuc = 'acik') end,
        case when b.durum = 'acik' then least(oyun.gk_bitis(b),
          (select min(o2.bit) from oyun.gk_oylama o2 where o2.birlesim_id = b.id and o2.durum = 'acik'),
          (select min(coalesce(s2.kursu_bit, s2.verildi + interval '90 seconds')) from oyun.meclis_soz s2 where s2.birlesim_id = b.id and s2.gk and s2.durum = 'verildi'),
          coalesce(b.kursu_bos, b.acilis) + interval '20 seconds') end) end,
      t + interval '60 seconds')
    into v_sonraki;
  update oyun.gk_salon set sonraki = greatest(v_sonraki, t + interval '5 seconds') where id = 1;
  return jsonb_build_object('isler', isler, 'sonraki', v_sonraki);
end $f$;

-- ---------------------------------------------------------------- GÖRÜNÜM (ortak, önbellekli)
create or replace function oyun.gk_genel_json(t timestamptz) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim; yon uuid; j jsonb; s oyun.meclis_soz; o oyun.gk_oylama; y oyun.gk_yoklama; son oyun.gk_birlesim; nx oyun.gk_birlesim;
  sal jsonb; kl jsonb; tp jsonb; gz jsonb;
begin
  b := oyun.gk_su_an();
  select * into nx from oyun.gk_birlesim x where x.durum = 'planli' and x.plan_bit > t order by x.plan_bas limit 1;
  select * into son from oyun.gk_birlesim x where x.durum in ('kapandi', 'toplanamadi') order by x.kapanis desc nulls last limit 1;
  j := jsonb_build_object('simdi', t, 'esik', jsonb_build_object('taban', oyun.gk_taban(), 'toplanti', oyun.gk_toplanti_yeter(), 'karar', oyun.gk_karar_yeter(), 'dolu', oyun.dolu_sandalye()),
    'sonraki', case when nx.id is not null then jsonb_build_object('id', nx.id, 'tur', nx.tur, 'bas', nx.plan_bas, 'bit', nx.plan_bit, 'gerekce', nx.gerekce) end,
    'son', case when son.id is not null then jsonb_build_object('id', son.id, 'no', son.no, 'durum', son.durum, 'acilis', son.acilis, 'kapanis', son.kapanis, 'ozet', son.ozet) end);
  if b.id is null then return j; end if;
  yon := oyun.gk_yoneten_salonda(b.id, t);
  select * into s from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi' order by x.verildi desc limit 1;
  select * into o from oyun.gk_oylama x where x.birlesim_id = b.id order by x.id desc limit 1;
  select * into y from oyun.gk_yoklama x where x.birlesim_id = b.id order by x.id desc limit 1;
  select coalesce(jsonb_agg(m.id), '[]'::jsonb) into sal
    from oyun.gk_salonda x join oyun.makamlar m on m.user_id = x.user_id and m.tur = 'mv' and m.bit is null
    where x.birlesim_id = b.id and x.vekil and x.son > t - interval '90 seconds';
  select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'no', k.no, 'baslik', k.baslik, 'tur', k.tur, 'durum', k.durum,
           'bit', case when k.durum = 'israr' then k.israr_bit else k.oy_bit end,
           'kabul', z.kabul, 'ret', z.ret, 'cekimser', z.cekimser, 'partiler', z.partiler, 'oy', z.oymap) order by k.oy_bit), '[]'::jsonb) into kl
    from oyun.kanunlar k
    cross join lateral (
      select count(*) filter (where ko.oy = 'kabul') kabul, count(*) filter (where ko.oy = 'ret') ret, count(*) filter (where ko.oy = 'cekimser') cekimser,
             coalesce((select jsonb_agg(jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk, 'k', pp.k, 'r', pp.r, 'c', pp.c) order by pp.k + pp.r + pp.c desc)
                       from (select o2.parti_id, count(*) filter (where o2.oy = 'kabul') k, count(*) filter (where o2.oy = 'ret') r, count(*) filter (where o2.oy = 'cekimser') c
                             from oyun.kanun_oylari o2 where o2.kanun_id = k.id and o2.asama = case when k.durum = 'israr' then 'israr' else 'ilk' end group by o2.parti_id) pp
                       left join oyun.partiler pa on pa.id = pp.parti_id), '[]'::jsonb) partiler,
             case when k.tur = 'anayasa' then null else coalesce((select jsonb_object_agg(m.id::text, left(o3.oy, 1))
                       from oyun.kanun_oylari o3 join oyun.makamlar m on m.user_id = o3.vekil and m.tur = 'mv' and m.bit is null
                       where o3.kanun_id = k.id and o3.asama = case when k.durum = 'israr' then 'israr' else 'ilk' end), '{}'::jsonb) end oymap
      from oyun.kanun_oylari ko where ko.kanun_id = k.id and ko.asama = case when k.durum = 'israr' then 'israr' else 'ilk' end) z
    where k.durum in ('oylamada', 'israr');
  select coalesce(jsonb_object_agg(z.tid::text, jsonb_build_array(z.a, z.p, z.g)), '{}'::jsonb) into tp
    from (select tt.id tid, count(*) filter (where x.tur = 'alkis' and x.vekil) a, count(*) filter (where x.tur = 'protesto' and x.vekil) p,
                 count(*) filter (where not x.vekil) g
          from (select id from oyun.gk_tutanak where birlesim_id = b.id and tur = 'konusma' order by id desc limit 60) tt
          join oyun.gk_tepki x on x.tutanak_id = tt.id group by tt.id) z;
  select coalesce(jsonb_agg(x.id), '[]'::jsonb) into gz from (select id from oyun.gk_tutanak where birlesim_id = b.id and gizli order by id desc limit 40) x;
  return j || jsonb_build_object(
    'b', jsonb_build_object('id', b.id, 'no', b.no, 'tur', b.tur, 'durum', b.durum, 'gun', b.gun, 'plan_bas', b.plan_bas, 'bitis', oyun.gk_bitis(b),
         'acilis', b.acilis, 'ara_bit', b.ara_bit, 'ara_neden', b.ara_neden, 'uzatma', b.uzatma, 'uzatma_azami', (select uzatma_azami from oyun.gk_ayar where id = 1),
         'yeter', b.yeter, 'kapali', b.kapali, 'aktif', b.aktif_gundem, 'gerekce', b.gerekce,
         'yoneten', case when yon is not null then oyun.gk_kimlik(yon) || jsonb_build_object('baskan', yon = oyun.tbmm_baskani()) end,
         'baskan', case when oyun.tbmm_baskani() is not null then oyun.gk_kimlik(oyun.tbmm_baskani()) end,
         'gecici', case when oyun.tbmm_baskani() is null and oyun.gecici_baskan() is not null then oyun.gk_kimlik(oyun.gecici_baskan()) end),
    'gundem', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'sira', g.sira, 'tur', g.tur, 'ref', g.ref_id, 'baslik', g.baslik, 'durum', g.durum) order by g.sira)
                        from oyun.gk_gundem g where g.birlesim_id = b.id), '[]'::jsonb),
    'kursu', case when s.id is not null then jsonb_build_object('id', s.id, 'tur', s.tur, 'tur_ad', (select ad from oyun.gk_soz_tur() where kod = s.tur),
         'kelime', (select kelime from oyun.gk_soz_tur() where kod = s.tur) + case when s.ek_sure then 40 else 0 end,
         'kullanilan', s.kelime_kullanilan, 'ek', s.ek_sure, 'verildi', s.verildi, 'bas', s.kursu_bas,
         'bit', coalesce(s.kursu_bit, s.verildi + interval '90 seconds'), 'konu', s.konu, 'kisi', oyun.gk_kimlik(s.user_id)) end,
    'sira', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tur', x.tur, 'tur_ad', (select ad from oyun.gk_soz_tur() where kod = x.tur),
                         'konu', x.konu, 'istek', x.istek, 'kisi', oyun.gk_kimlik(x.user_id)) order by (x.tur = 'gundem_disi') desc, x.sira_no nulls last, x.id)
                      from (select * from oyun.meclis_soz z where z.birlesim_id = b.id and z.gk and z.durum = 'bekliyor'
                            order by (z.tur = 'gundem_disi') desc, z.sira_no nulls last, z.id limit 30) x), '[]'::jsonb),
    'sira_sayi', (select count(*) from oyun.meclis_soz z where z.birlesim_id = b.id and z.gk and z.durum = 'bekliyor'),
    'yoklama', case when y.id is not null then jsonb_build_object('id', y.id, 'bas', y.bas, 'bit', y.bit, 'neden', y.neden, 'sonuc', y.sonuc,
         'sayi', coalesce(y.sayi, (select count(*) from oyun.gk_yoklama_kayit k where k.yoklama_id = y.id)), 'yeter', coalesce(y.yeter, oyun.gk_toplanti_yeter())) end,
    'oylama', case when o.id is not null and (o.durum = 'acik' or o.bit > t - interval '2 minutes') then jsonb_build_object('id', o.id, 'konu', o.konu, 'baslik', o.baslik,
         'bas', o.bas, 'bit', o.bit, 'durum', o.durum, 'yeter_istendi', o.yeter_istendi, 'karar_yeter', oyun.gk_karar_yeter(),
         'kabul', (select count(*) from oyun.gk_oy v where v.oylama_id = o.id and v.oy = 'kabul'),
         'ret', (select count(*) from oyun.gk_oy v where v.oylama_id = o.id and v.oy = 'ret'),
         'cekimser', (select count(*) from oyun.gk_oy v where v.oylama_id = o.id and v.oy = 'cekimser'),
         'partiler', coalesce((select jsonb_agg(jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk, 'k', pp.k, 'r', pp.r, 'c', pp.c) order by pp.k + pp.r + pp.c desc)
                       from (select v.parti_id, count(*) filter (where v.oy = 'kabul') k, count(*) filter (where v.oy = 'ret') r, count(*) filter (where v.oy = 'cekimser') c
                             from oyun.gk_oy v where v.oylama_id = o.id group by v.parti_id) pp left join oyun.partiler pa on pa.id = pp.parti_id), '[]'::jsonb),
         'oy', coalesce((select jsonb_object_agg(m.id::text, left(v.oy, 1)) from oyun.gk_oy v join oyun.makamlar m on m.user_id = v.user_id and m.tur = 'mv' and m.bit is null
                         where v.oylama_id = o.id), '{}'::jsonb)) end,
    'kanunlar', kl, 'tepki', tp, 'gizlenen', gz, 'sal', sal,
    'yemin', case when exists (select 1 from oyun.gk_gundem g where g.id = b.aktif_gundem and g.tur = 'yemin')
                  then (select count(*) from oyun.gk_yemin x where x.donem is not distinct from b.donem) end,
    'gundem_disi', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'konu', d.konu, 'durum', d.durum, 'kisi', oyun.gk_kimlik(d.user_id)) order by d.istek)
                             from oyun.gk_gundem_disi d where d.gun = b.gun and d.durum in ('bekliyor', 'secildi', 'konustu')), '[]'::jsonb),
    'oneriler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tur', x.tur, 'baslik', x.baslik, 'durum', x.durum, 'kisa', pa.kisa, 'renk', pa.renk) order by x.zaman)
                          from oyun.gk_grup_onerisi x join oyun.partiler pa on pa.id = x.parti_id where x.gun = b.gun), '[]'::jsonb));
end $f$;

create or replace function oyun.gk_ben_json(p oyun.profiller, t timestamptz) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim := oyun.gk_su_an(); v boolean := oyun.gk_vekil(p.id); h boolean := oyun.gk_hukumet(p.id); s oyun.meclis_soz; w oyun.meclis_soz;
  gp bigint := oyun.gk_grup_parti(p.id); son timestamptz; lafson timestamptz; ks oyun.meclis_soz; turler jsonb; o oyun.gk_oylama; y oyun.gk_yoklama; ih timestamptz;
begin
  if b.id is not null then
    select * into s from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.user_id = p.id and x.durum = 'verildi' order by x.id desc limit 1;
    select * into w from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.user_id = p.id and x.durum = 'bekliyor' order by x.id desc limit 1;
    select * into ks from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi' order by x.verildi desc limit 1;
    select * into o from oyun.gk_oylama x where x.birlesim_id = b.id and x.durum = 'acik' order by x.id desc limit 1;
    select * into y from oyun.gk_yoklama x where x.birlesim_id = b.id and x.sonuc = 'acik' order by x.id desc limit 1;
  end if;
  select max(kullanildi) into son from oyun.meclis_soz where user_id = p.id and kullanildi > t - interval '2 minutes';
  select max(zaman) into lafson from oyun.gk_tutanak where user_id = p.id and tur = 'laf' and zaman > t - interval '5 minutes';
  ih := oyun.ihtarli(p.id, t);
  select coalesce(jsonb_agg(jsonb_build_object('kod', x.kod, 'ad', x.ad, 'kelime', x.kelime, 'sure', x.sure_sn) order by x.sira), '[]'::jsonb) into turler
    from oyun.gk_soz_tur() x
    where (x.kod = 'kisisel' and v) or (x.kod = 'yerinden' and (v or h)) or (x.kod = 'satasma' and (v or h))
       or (x.kod in ('grup', 'usul') and gp is not null) or (x.kod = 'hukumet' and h);
  return jsonb_build_object(
    'vekil', v, 'hukumet', h, 'yonetebilir', oyun.gk_yonetebilir(p.id) or coalesce(p.yonetici, false), 'baskan', oyun.tbmm_baskani() is not distinct from p.id,
    'yonetici', coalesce(p.yonetici, false), 'mod', coalesce(oyun.yetkili(p.id, 'sikayet'), false),
    'grup_parti', gp, 'grup_kisa', (select kisa from oyun.partiler where id = gp),
    'cb', exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null and m.tur = 'cb'),
    'mk', (select m.id from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null limit 1),
    'cikarildi', oyun.gk_cikarilmis(p.id, b), 'ihtar_bit', ih,
    'turler', turler,
    'soz', case when s.id is not null then jsonb_build_object('id', s.id, 'tur', s.tur, 'ad', (select ad from oyun.gk_soz_tur() where kod = s.tur),
              'kelime', (select kelime from oyun.gk_soz_tur() where kod = s.tur) + case when s.ek_sure then 40 else 0 end, 'kullanilan', s.kelime_kullanilan,
              'bas', s.kursu_bas, 'bit', coalesce(s.kursu_bit, s.verildi + interval '90 seconds'), 'sure', (select sure_sn from oyun.gk_soz_tur() where kod = s.tur)) end,
    'bekleyen', case when w.id is not null then jsonb_build_object('id', w.id, 'tur', w.tur, 'ad', (select ad from oyun.gk_soz_tur() where kod = w.tur),
              'kelime', (select kelime from oyun.gk_soz_tur() where kod = w.tur),
              'sira', (select count(*) from oyun.meclis_soz z where z.birlesim_id = b.id and z.gk and z.durum = 'bekliyor'
                        and ((z.tur = 'gundem_disi') > (w.tur = 'gundem_disi') or ((z.tur = 'gundem_disi') = (w.tur = 'gundem_disi')
                             and (coalesce(z.sira_no, 1e12), z.id) <= (coalesce(w.sira_no, 1e12), w.id))))) end,
    'bekleme_bitis', case when son is not null then son + interval '2 minutes' end,
    'laf_bitis', case when lafson is not null then lafson + make_interval(secs => (select laf_aralik_sn from oyun.gk_ayar where id = 1)) end,
    'laf_kalan', case when ks.id is not null then greatest(0, (select laf_azami from oyun.gk_ayar where id = 1)
                   - (select count(*) from oyun.gk_tutanak z where z.user_id = p.id and z.tur = 'laf' and z.soz_id = ks.id)) end,
    'yoklamada', case when y.id is not null then exists (select 1 from oyun.gk_yoklama_kayit k where k.yoklama_id = y.id and k.user_id = p.id) end,
    'oyum', case when o.id is not null then (select v2.oy from oyun.gk_oy v2 where v2.oylama_id = o.id and v2.user_id = p.id) end,
    'kanun_oylarim', coalesce((select jsonb_object_agg(k.id::text, ko.oy) from oyun.kanunlar k join oyun.kanun_oylari ko on ko.kanun_id = k.id and ko.vekil = p.id
                                 and ko.asama = case when k.durum = 'israr' then 'israr' else 'ilk' end where k.durum in ('oylamada', 'israr')), '{}'::jsonb),
    'tepkilerim', case when b.id is not null then coalesce((select jsonb_object_agg(x.tutanak_id::text, x.tur) from oyun.gk_tepki x
                     where x.user_id = p.id and x.tutanak_id in (select id from oyun.gk_tutanak where birlesim_id = b.id and tur = 'konusma' order by id desc limit 60)), '{}'::jsonb) end,
    'gundem_disi', (select jsonb_build_object('id', d.id, 'konu', d.konu, 'durum', d.durum) from oyun.gk_gundem_disi d
                     where d.user_id = p.id and d.gun = coalesce(b.gun, oyun.gk_gun(t)) and d.durum <> 'geri' order by d.id desc limit 1),
    'oneri_verdim', gp is not null and exists (select 1 from oyun.gk_grup_onerisi x where x.parti_id = gp and x.gun = coalesce(b.gun, oyun.gk_gun(t)) and x.durum <> 'geri'),
    'yemin', exists (select 1 from oyun.gk_yemin x where x.user_id = p.id and x.donem is not distinct from coalesce(b.donem, oyun.gk_donem())));
end $f$;

create or replace function oyun.gk_tutanak_json(p_b bigint, p_son bigint, p_once bigint, p_limit int, p_gizli_gorur boolean) returns jsonb
language sql stable set search_path to '' as $f$
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'z', x.zaman, 'tur', x.tur, 'ad', x.ad, 'kad', x.kad, 'il', x.il, 'kisa', x.parti_kisa,
           'renk', x.renk, 'rol', x.rol, 'soz', x.soz_id, 'st', x.soz_tur, 'g', x.gundem_id,
           'm', case when x.gizli then '(Bu bölüm Oyun Yönetimince tutanaktan çıkarıldı.)' when x.kapali and not p_gizli_gorur then '(Kapalı oturum — tutanak gizlidir.)' else x.metin end,
           'v', case when x.gizli or (x.kapali and not p_gizli_gorur) then null else x.veri end, 'gz', x.gizli, 'kp', x.kapali) order by x.id), '[]'::jsonb)
  from (select * from oyun.gk_tutanak t where t.birlesim_id = p_b
          and (p_son is null or t.id > p_son) and (p_once is null or t.id < p_once)
        order by t.id desc limit p_limit) x
$f$;

-- ---------------------------------------------------------------- OYUNCU RPC'LERİ
create or replace function public.gk_durum(p_surum bigint default 0, p_son bigint default 0)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.gk_salon; b oyun.gk_birlesim; c oyun.gk_onbellek;
  g jsonb; v boolean; sal int := 0; izl int := 0; yeni jsonb; gor boolean; gsurum bigint; bid bigint;
begin
  select * into s from oyun.gk_salon where id = 1;
  if s.sonraki is null or s.sonraki <= t then perform oyun.gk_ilerlet(t); select * into s from oyun.gk_salon where id = 1; end if;
  b := oyun.gk_su_an();
  v := oyun.gk_vekil(p.id);
  gor := v or oyun.gk_hukumet(p.id) or coalesce(p.yonetici, false);
  if b.id is not null then
    insert into oyun.gk_salonda(birlesim_id, user_id, son, vekil) values (b.id, p.id, t, v)
    on conflict (birlesim_id, user_id) do update set son = excluded.son, vekil = excluded.vekil
      where oyun.gk_salonda.son < excluded.son - interval '40 seconds';
    select count(*) filter (where x.vekil), count(*) filter (where not x.vekil) into sal, izl
      from oyun.gk_salonda x where x.birlesim_id = b.id and x.son > t - interval '90 seconds';
    if sal > b.salon_azami then update oyun.gk_birlesim set salon_azami = sal where id = b.id; end if;
    bid := b.id;
  else
    select x.id into bid from oyun.gk_birlesim x where x.acilis is not null order by x.acilis desc limit 1;
  end if;
  select * into c from oyun.gk_onbellek where anahtar = 'genel';
  if s.kirli and (c.zaman is null or c.zaman < t - interval '3 seconds') then
    perform oyun.gk_degisti(); select * into s from oyun.gk_salon where id = 1;
  end if;
  yeni := case when bid is null then '[]'::jsonb
               when coalesce(p_son, 0) > 0 then oyun.gk_tutanak_json(bid, p_son, null, 120, gor)
               else oyun.gk_tutanak_json(bid, null, null, 80, gor) end;
  if coalesce(p_surum, 0) = s.surum then
    return jsonb_build_object('surum', s.surum, 'ayni', true, 'simdi', t, 'ben', oyun.gk_ben_json(p, t), 'yeni', yeni, 'bid', bid,
      'salon', jsonb_build_object('vekil', sal, 'izleyici', izl));
  end if;
  if c.surum = s.surum then
    g := c.veri; gsurum := c.surum;
  elsif pg_try_advisory_xact_lock(hashtext('gk_insa')) then
    g := oyun.gk_genel_json(t); gsurum := s.surum;
    insert into oyun.gk_onbellek(anahtar, surum, veri, zaman) values ('genel', s.surum, g, t)
    on conflict (anahtar) do update set surum = excluded.surum, veri = excluded.veri, zaman = excluded.zaman where oyun.gk_onbellek.surum < excluded.surum;
  else
    g := coalesce(c.veri, oyun.gk_genel_json(t)); gsurum := coalesce(c.surum, 0);
  end if;
  return jsonb_build_object('surum', gsurum, 'ayni', false, 'simdi', t, 'genel', g, 'ben', oyun.gk_ben_json(p, t), 'yeni', yeni, 'bid', bid,
    'salon', jsonb_build_object('vekil', sal, 'izleyici', izl));
end $f$;

-- Salon oturma düzeni: milletvekilleri parti bloklarına göre (seyrek değişir, 2 dk önbellek)
create or replace function public.gk_salon_harita()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.gk_onbellek; j jsonb;
begin
  select * into c from oyun.gk_onbellek where anahtar = 'harita';
  if c.anahtar is not null and c.zaman > t - interval '2 minutes' then return c.veri; end if;
  with v as (select m.id mk, m.user_id, coalesce(pr.parti_id, 0) pid, pr.kad, coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad) ad, i.ad il
             from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id left join oyun.iller i on i.id = m.il_id
             where m.tur = 'mv' and m.bit is null),
       ps as (select pid, count(*) n from v group by pid)
  select jsonb_build_object('zaman', t, 'toplam', oyun.tbmm_tamsayi(), 'baskan', case when oyun.tbmm_baskani() is not null then oyun.gk_kimlik(oyun.tbmm_baskani()) end,
    'partiler', coalesce((select jsonb_agg(jsonb_build_object('id', nullif(ps.pid, 0), 'kisa', coalesce(pa.kisa, 'Bağımsız'), 'ad', coalesce(pa.ad, 'Bağımsız milletvekilleri'),
                                 'renk', coalesce(pa.renk, '#8E97B5'), 'n', ps.n) order by (ps.pid = 0), ps.n desc, ps.pid)
                          from ps left join oyun.partiler pa on pa.id = ps.pid), '[]'::jsonb),
    'vekiller', coalesce((select jsonb_agg(jsonb_build_object('m', v.mk, 'k', v.kad, 'a', v.ad, 'p', nullif(v.pid, 0), 'i', v.il)
                                 order by (v.pid = 0), ps.n desc, v.pid, v.il, v.ad)
                          from v join ps on ps.pid = v.pid), '[]'::jsonb))
    into j;
  insert into oyun.gk_onbellek(anahtar, surum, veri, zaman) values ('harita', 0, j, t)
  on conflict (anahtar) do update set veri = excluded.veri, zaman = excluded.zaman;
  return j;
end $f$;

-- Tutanak arşivi
create or replace function public.gk_birlesimler(p_limit int default 30)
returns jsonb language sql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
  select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'no', b.no, 'tur', b.tur, 'durum', b.durum, 'gun', b.gun, 'acilis', b.acilis, 'kapanis', b.kapanis,
           'ozet', b.ozet, 'gerekce', b.gerekce) order by b.acilis desc), '[]'::jsonb)
  from (select * from oyun.gk_birlesim x where x.acilis is not null order by x.acilis desc limit least(greatest(coalesce(p_limit, 30), 1), 100)) b
$f$;

create or replace function public.gk_tutanak_oku(p_birlesim bigint, p_once bigint default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); b oyun.gk_birlesim;
begin
  select * into b from oyun.gk_birlesim where id = p_birlesim;
  if b.id is null then raise exception 'Birleşim bulunamadı.'; end if;
  return jsonb_build_object('birlesim', jsonb_build_object('id', b.id, 'no', b.no, 'tur', b.tur, 'durum', b.durum, 'gun', b.gun, 'acilis', b.acilis, 'kapanis', b.kapanis, 'ozet', b.ozet),
    'satirlar', oyun.gk_tutanak_json(b.id, null, p_once, 150, oyun.gk_vekil(p.id) or oyun.gk_hukumet(p.id) or coalesce(p.yonetici, false)));
end $f$;

-- Söz iste
create or replace function public.gk_soz_iste(p_tur text, p_hedef bigint default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); v boolean := oyun.gk_vekil(p.id);
  h boolean := oyun.gk_hukumet(p.id); gp bigint := oyun.gk_grup_parti(p.id); son timestamptz; n int; ht oyun.gk_tutanak; v_id bigint;
begin
  if b.id is null then raise exception 'Genel Kurul şu an toplantı hâlinde değil.'; end if;
  if b.durum <> 'acik' then raise exception '%', case b.durum when 'yoklama' then 'Yoklama sürüyor; yoklama bitince söz isteyebilirsin.' else 'Birleşime ara verildi; oturum açılınca söz isteyebilirsin.' end; end if;
  if not (v or h) then raise exception 'Genel Kurulda yalnız milletvekilleri ve Hükümet üyeleri söz alabilir. Sen salonu izleyebilirsin.'; end if;
  if oyun.gk_yonetebilir(p.id) and oyun.tbmm_baskani() = p.id then raise exception 'Meclis Başkanı oturumu yönetir; söz istemeden Başkanlık kürsüsünden konuşursun.'; end if;
  if oyun.gk_cikarilmis(p.id, b) then raise exception 'Meclisten geçici çıkarma cezan sürüyor; bu birleşimde söz alamazsın.'; end if;
  if oyun.ihtarli(p.id, t) is not null then raise exception 'Meclis Başkanlığından ihtar aldın; % saatine kadar söz alamazsın.', oyun.gk_saat(oyun.ihtarli(p.id, t)); end if;
  perform oyun.yazabilir_mi(p, t);
  if p_tur is null or p_tur not in ('kisisel', 'grup', 'hukumet', 'yerinden', 'satasma', 'usul') then raise exception 'Geçersiz söz türü.'; end if;
  if (p_tur = 'kisisel' and not v) or (p_tur in ('grup', 'usul') and gp is null) or (p_tur = 'hukumet' and not h) then
    raise exception 'Bu türde söz isteyemezsin.'; end if;
  perform pg_advisory_xact_lock(hashtext('meclis_soz'), hashtext(p.id::text));
  if exists (select 1 from oyun.meclis_soz x where x.user_id = p.id and x.birlesim_id = b.id and x.gk and x.durum in ('bekliyor', 'verildi')) then
    raise exception 'Zaten söz sırasındasın ya da kürsüdesin.'; end if;
  select max(kullanildi) into son from oyun.meclis_soz where user_id = p.id and kullanildi > t - interval '2 minutes';
  if son is not null then raise exception 'Az önce konuştun; % saatinden sonra yeniden söz isteyebilirsin.', oyun.gk_saat(son + interval '2 minutes'); end if;
  if p_tur = 'kisisel' then
    select count(*) into n from oyun.meclis_soz x where x.user_id = p.id and x.birlesim_id = b.id and x.tur = 'kisisel' and x.durum = 'kullanildi';
    if n >= 3 then raise exception 'Bir birleşimde şahsın adına en çok 3 kez konuşabilirsin.'; end if;
  elsif p_tur = 'yerinden' then
    select count(*) into n from oyun.meclis_soz x where x.user_id = p.id and x.birlesim_id = b.id and x.tur = 'yerinden' and x.durum = 'kullanildi';
    if n >= 5 then raise exception 'Bir birleşimde yerinden en çok 5 kez söz alabilirsin.'; end if;
  elsif p_tur = 'grup' then
    if exists (select 1 from oyun.meclis_soz x join oyun.profiller z on z.id = x.user_id where x.birlesim_id = b.id and x.tur = 'grup' and x.gk
               and x.durum in ('bekliyor', 'verildi', 'kullanildi') and x.gundem_id is not distinct from b.aktif_gundem and oyun.gk_grup_parti(x.user_id) = gp) then
      raise exception 'Grubun bu gündem maddesinde grup adına söz aldı ya da sırada.'; end if;
  elsif p_tur = 'usul' then
    select count(*) into n from oyun.meclis_soz x where x.birlesim_id = b.id and x.tur = 'usul' and x.gk and x.durum in ('bekliyor', 'verildi', 'kullanildi') and oyun.gk_grup_parti(x.user_id) = gp;
    if n >= 2 then raise exception 'Grubun bu birleşimde usul hakkında 2 kez söz aldı.'; end if;
  elsif p_tur = 'satasma' then
    select * into ht from oyun.gk_tutanak where id = p_hedef and birlesim_id = b.id and tur in ('konusma', 'laf');
    if ht.id is null or ht.zaman < t - interval '20 minutes' then raise exception 'Sataşma son 20 dakikadaki bir konuşmaya ya da söze yapılmış olmalı.'; end if;
    if ht.user_id = p.id then raise exception 'Kendi konuşmana sataşma cevabı veremezsin.'; end if;
    if exists (select 1 from oyun.meclis_soz x where x.user_id = p.id and x.hedef_tutanak = p_hedef) then raise exception 'Bu söz için zaten cevap hakkı istedin.'; end if;
  end if;
  insert into oyun.meclis_soz(user_id, tur, istek, otomatik, gk, birlesim_id, gundem_id, sira_no, hedef_tutanak)
  values (p.id, p_tur, t, oyun.gk_bitis(b), true, b.id, b.aktif_gundem,
          extract(epoch from t) - case p_tur when 'satasma' then 600 when 'usul' then 300 when 'grup' then 120 when 'hukumet' then 120 else 0 end, p_hedef)
  returning id into v_id;
  -- Başkanlık yoksa sataşma kendiliğinden değerlendirilir: adı ya da partisi geçmiyorsa reddedilir
  if p_tur = 'satasma' and oyun.gk_yoneten_salonda(b.id, t) is null then
    if not (position(lower(coalesce(nullif(btrim(p.ad_soyad), ''), p.kad)) in lower(ht.metin)) > 0 or position(lower(p.kad) in lower(ht.metin)) > 0
            or (p.parti_id is not null and (position(lower((select kisa from oyun.partiler where id = p.parti_id)) in lower(ht.metin)) > 0
                                          or position(lower((select ad from oyun.partiler where id = p.parti_id)) in lower(ht.metin)) > 0))) then
      update oyun.meclis_soz set durum = 'ret', verildi = t where id = v_id;
      perform oyun.gk_degisti();
      raise exception 'Konuşmada adın ya da partin geçmediği için sataşma görülmedi. Başkanlık salondayken yeniden isteyebilirsin.';
    end if;
  end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

create or replace function public.gk_soz_geri()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_soz;
begin
  select * into s from oyun.meclis_soz where user_id = p.id and gk and durum in ('bekliyor', 'verildi') order by id desc limit 1 for update;
  if s.id is null then raise exception 'Söz istemin yok.'; end if;
  if s.durum = 'verildi' then perform oyun.gk_soz_kapat(s.id, t, 'bitir');
  else update oyun.meclis_soz set durum = 'geri' where id = s.id; end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true);
end $f$;

-- Kürsüye çık (süre şimdi başlar)
create or replace function public.gk_kursu_cik()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_soz;
begin
  select * into s from oyun.meclis_soz where user_id = p.id and gk and durum = 'verildi' order by id desc limit 1 for update;
  if s.id is null then raise exception 'Kürsüde söz sende değil.'; end if;
  if s.kursu_bas is null then
    update oyun.meclis_soz set kursu_bas = t, kursu_bit = t + make_interval(secs => (select sure_sn from oyun.gk_soz_tur() where kod = s.tur)) where id = s.id;
    perform oyun.gk_degisti();
  end if;
  return jsonb_build_object('tamam', true);
end $f$;

-- Konuş: kürsüdeki vekil (kelime hakkı içinde, birden çok parça) ya da Başkanlık
create or replace function public.gk_konus(p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); s oyun.meclis_soz;
  m text; n int; kalan int; sinir int; sure int; v_tid bigint; v_mid bigint; ilk boolean; v_son timestamptz;
begin
  if b.id is null or b.durum not in ('acik', 'yoklama', 'arada') then raise exception 'Genel Kurul şu an toplantı hâlinde değil.'; end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(coalesce(p_metin, ''), 1500);
  n := oyun.gk_kelime(m);
  if n = 0 then raise exception 'Boş konuşma gönderilemez.'; end if;
  select * into s from oyun.meclis_soz where user_id = p.id and gk and birlesim_id = b.id and durum = 'verildi' order by id desc limit 1 for update;
  if s.id is null then
    if not (oyun.gk_yonetebilir(p.id) or coalesce(p.yonetici, false)) then raise exception 'Kürsüde söz sende değil. Önce söz iste.'; end if;
    -- Başkanlık konuşması: en çok 100 kelime, 5 sn'de bir
    if n > 100 then raise exception 'Başkanlık açıklaması en çok 100 kelime olabilir (yazdığın: %).', n; end if;
    select max(zaman) into v_son from oyun.gk_tutanak where birlesim_id = b.id and user_id = p.id and tur = 'baskan';
    if v_son > t - interval '5 seconds' then raise exception 'Biraz bekle.'; end if;
    perform set_config('oyun.gk_ayna', '1', true);
    v_tid := oyun.gk_yaz(b.id, 'baskan', p.id, m, null, null, null, t);
    if not b.kapali then
      insert into oyun.mesajlar(kanal, user_id, metin, zaman) values ('meclis', p.id, m, t) returning id into v_mid;
      update oyun.gk_tutanak set mesaj_id = v_mid where id = v_tid;
    end if;
    update oyun.gk_birlesim set yoneten = p.id where id = b.id and yoneten is distinct from p.id and oyun.gk_yonetebilir(p.id);
    update oyun.profiller set son_mesaj = t where id = p.id;
    return jsonb_build_object('tamam', true, 'id', v_tid);
  end if;
  if b.durum <> 'acik' then raise exception 'Oturuma ara verildi.'; end if;
  if s.kursu_bas is null then
    sure := (select sure_sn from oyun.gk_soz_tur() where kod = s.tur);
    update oyun.meclis_soz set kursu_bas = t, kursu_bit = t + make_interval(secs => sure) + case when ek_sure then interval '60 seconds' else interval '0' end
     where id = s.id returning * into s;
  end if;
  if s.kursu_bit <= t then raise exception 'Konuşma süren doldu; mikrofon kapandı.'; end if;
  sinir := (select kelime from oyun.gk_soz_tur() where kod = s.tur) + case when s.ek_sure then 40 else 0 end;
  kalan := sinir - s.kelime_kullanilan;
  if n > kalan then raise exception 'Kalan kelime hakkın: %. Yazdığın: % kelime. Konuşmanı kısalt.', kalan, n; end if;
  ilk := s.kelime_kullanilan = 0;
  perform set_config('oyun.gk_ayna', '1', true);
  v_tid := oyun.gk_yaz(b.id, 'konusma', p.id, m, case when ilk then jsonb_build_object('ilk', true, 'konu', s.konu) end, s.id, s.tur, t);
  if not b.kapali then
    insert into oyun.mesajlar(kanal, user_id, metin, zaman) values ('meclis', p.id, m, t) returning id into v_mid;
    update oyun.gk_tutanak set mesaj_id = v_mid where id = v_tid;
  end if;
  update oyun.meclis_soz set kelime_kullanilan = kelime_kullanilan + n where id = s.id;
  if kalan - n <= 0 then
    update oyun.meclis_soz set durum = 'kullanildi', kullanildi = t where id = s.id;
    update oyun.gk_birlesim set kursu_bos = t where id = b.id;
    if s.tur = 'gundem_disi' then update oyun.gk_gundem_disi set durum = 'konustu' where user_id = p.id and gun = b.gun and durum = 'secildi'; end if;
  end if;
  if ilk then perform oyun.kidem_ekle(p.id, 'meclis_konusma'); end if;
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true, 'id', v_tid, 'kalan', kalan - n);
end $f$;

create or replace function public.gk_konusma_bitir()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_soz;
begin
  select * into s from oyun.meclis_soz where user_id = p.id and gk and durum = 'verildi' order by id desc limit 1;
  if s.id is null then raise exception 'Kürsüde değilsin.'; end if;
  perform oyun.gk_soz_kapat(s.id, t, 'bitir');
  if oyun.gk_yoneten_salonda(s.birlesim_id, t) is null and s.kelime_kullanilan > 0 then
    perform oyun.gk_baskan(s.birlesim_id, format('Teşekkür ederim Sayın %s.', oyun.gk_kimlik(p.id) ->> 'ad'), null, t);
  end if;
  return jsonb_build_object('tamam', true);
end $f$;

-- Sıradan laf atma (yerinden müdahale)
create or replace function public.gk_laf(p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); a oyun.gk_ayar; ks oyun.meclis_soz;
  m text; n int; v_son timestamptz; v_id bigint;
begin
  select * into a from oyun.gk_ayar where id = 1;
  if b.id is null or b.durum <> 'acik' then raise exception 'Şu an kürsüde konuşma yok.'; end if;
  if not (oyun.gk_vekil(p.id) or oyun.gk_hukumet(p.id)) then raise exception 'Sıralardan yalnız milletvekilleri ve Hükümet üyeleri söz atabilir.'; end if;
  if oyun.gk_cikarilmis(p.id, b) then raise exception 'Meclisten geçici çıkarma cezan sürüyor.'; end if;
  if oyun.ihtarli(p.id, t) is not null then raise exception 'İhtar aldın; % saatine kadar söz atamazsın.', oyun.gk_saat(oyun.ihtarli(p.id, t)); end if;
  perform oyun.yazabilir_mi(p, t);
  select * into ks from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi' and x.kelime_kullanilan > 0 order by x.verildi desc limit 1;
  if ks.id is null then raise exception 'Kürsüde konuşan biri olunca sıralardan söz atabilirsin.'; end if;
  if ks.user_id = p.id then raise exception 'Kürsüdesin; konuşmana devam et.'; end if;
  m := btrim(regexp_replace(coalesce(p_metin, ''), '\s+', ' ', 'g'));
  n := oyun.gk_kelime(m);
  if n = 0 then raise exception 'Boş söz atılamaz.'; end if;
  if n > 12 or char_length(m) > 90 then raise exception 'Sıralardan atılan söz en çok 12 kelime ve 90 karakter olabilir.'; end if;
  select max(zaman) into v_son from oyun.gk_tutanak where user_id = p.id and tur = 'laf' and zaman > t - interval '5 minutes';
  if v_son > t - make_interval(secs => a.laf_aralik_sn) then raise exception 'Çok sık söz atıyorsun; % saniye bekle.', a.laf_aralik_sn; end if;
  if (select count(*) from oyun.gk_tutanak z where z.user_id = p.id and z.tur = 'laf' and z.soz_id = ks.id) >= a.laf_azami then
    raise exception 'Bu konuşmaya en çok % kez söz atabilirsin.', a.laf_azami; end if;
  if (select count(*) from oyun.gk_tutanak z where z.tur = 'laf' and z.soz_id = ks.id) >= 40 then raise exception 'Salon çok gürültülü; Başkanlık düzeni sağlıyor.'; end if;
  v_id := oyun.gk_yaz(b.id, 'laf', p.id, m, null, ks.id, ks.tur, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

-- Alkış / protesto (milletvekili sıralardan; diğerleri halk galerisinden)
create or replace function public.gk_tepki(p_tutanak bigint, p_tur text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.gk_tutanak; v boolean := oyun.gk_vekil(p.id); n int; esik int; pk text; eski text; b oyun.gk_birlesim;
begin
  if p_tur not in ('alkis', 'protesto') then raise exception 'Geçersiz tepki.'; end if;
  select * into r from oyun.gk_tutanak where id = p_tutanak;
  if r.id is null or r.tur <> 'konusma' or r.gizli then raise exception 'Konuşma bulunamadı.'; end if;
  select * into b from oyun.gk_birlesim where id = r.birlesim_id;
  if b.durum not in ('acik', 'yoklama', 'arada') or r.zaman < t - interval '30 minutes' then raise exception 'Bu konuşmaya artık tepki verilemez.'; end if;
  if r.user_id = p.id then raise exception 'Kendi konuşmanı alkışlayamazsın.'; end if;
  if b.kapali and not (v or oyun.gk_hukumet(p.id)) then raise exception 'Kapalı oturum sürüyor.'; end if;
  if v and oyun.gk_cikarilmis(p.id, b) then raise exception 'Meclisten geçici çıkarma cezan sürüyor.'; end if;
  if exists (select 1 from oyun.gk_tepki x where x.user_id = p.id and x.zaman > t - interval '2 seconds') then raise exception 'Biraz yavaş.'; end if;
  select x.tur into eski from oyun.gk_tepki x where x.tutanak_id = r.id and x.user_id = p.id;
  if eski = p_tur then
    delete from oyun.gk_tepki where tutanak_id = r.id and user_id = p.id;
    perform oyun.gk_kirlet();
    return jsonb_build_object('tamam', true, 'tepki', null);
  end if;
  insert into oyun.gk_tepki(tutanak_id, user_id, tur, vekil, parti_id, zaman) values (r.id, p.id, p_tur, v, p.parti_id, t)
  on conflict (tutanak_id, user_id) do update set tur = excluded.tur, zaman = excluded.zaman;
  -- Parti sıralarından yeterli tepki gelince tutanağa geçer: "(MBP sıralarından alkışlar)"
  if v and p.parti_id is not null then
    select count(distinct x.user_id) into n from oyun.gk_tepki x join oyun.gk_tutanak y on y.id = x.tutanak_id
      where y.soz_id is not distinct from r.soz_id and y.birlesim_id = r.birlesim_id and x.tur = p_tur and x.vekil and x.parti_id = p.parti_id
        and (r.soz_id is not null or y.id = r.id);
    esik := greatest(2, ceil((select count(*) from oyun.makamlar m join oyun.profiller z on z.id = m.user_id where m.tur = 'mv' and m.bit is null and z.parti_id = p.parti_id)
                              * (select tepki_oran from oyun.gk_ayar where id = 1)))::int;
    if n >= esik then
      insert into oyun.gk_tepki_satir(tutanak_id, parti_id, tur) values (coalesce(r.soz_id, r.id), p.parti_id, p_tur) on conflict do nothing;
      if found then
        select kisa into pk from oyun.partiler where id = p.parti_id;
        perform oyun.gk_yaz(r.birlesim_id, 'tepki', null, format('(%s sıralarından %s)', pk, case when p_tur = 'alkis' then 'alkışlar' else 'gürültüler' end),
          jsonb_build_object('parti', pk, 'tur', p_tur, 'hedef', r.id), r.soz_id, r.soz_tur, t);
      end if;
    end if;
  end if;
  perform oyun.gk_kirlet();
  return jsonb_build_object('tamam', true, 'tepki', p_tur);
end $f$;

-- Yoklama: "Buradayım"
create or replace function public.gk_buradayim()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); y oyun.gk_yoklama; ek numeric := 0;
begin
  if not oyun.gk_vekil(p.id) then raise exception 'Yoklamaya yalnız milletvekilleri katılır.'; end if;
  if b.id is null then raise exception 'Genel Kurul toplantıda değil.'; end if;
  if oyun.gk_cikarilmis(p.id, b) then raise exception 'Meclisten geçici çıkarma cezan sürüyor.'; end if;
  select * into y from oyun.gk_yoklama where birlesim_id = b.id and sonuc = 'acik' order by id desc limit 1;
  if y.id is null then raise exception 'Şu an yoklama yok.'; end if;
  insert into oyun.gk_yoklama_kayit(yoklama_id, user_id, zaman) values (y.id, p.id, t) on conflict do nothing;
  if found then
    insert into oyun.meclis_yoklama(gun, user_id, zaman) values (b.gun, p.id, t) on conflict do nothing;
    if found then ek := oyun.kidem_ekle(p.id, 'meclis_yoklama'); end if;
    perform oyun.gk_kirlet();
  end if;
  insert into oyun.gk_salonda(birlesim_id, user_id, son, vekil) values (b.id, p.id, t, true)
  on conflict (birlesim_id, user_id) do update set son = excluded.son, vekil = true;
  return jsonb_build_object('tamam', true, 'kidem', ek);
end $f$;

-- İşaret oylamasında oy
create or replace function public.gk_oy(p_oylama bigint, p_oy text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); o oyun.gk_oylama; b oyun.gk_birlesim;
begin
  if p_oy not in ('kabul', 'ret', 'cekimser') then raise exception 'Geçersiz oy.'; end if;
  select * into o from oyun.gk_oylama where id = p_oylama;
  if o.id is null or o.durum <> 'acik' or o.bit <= t then raise exception 'Bu oylama kapandı.'; end if;
  select * into b from oyun.gk_birlesim where id = o.birlesim_id;
  if not oyun.gk_vekil(p.id) then raise exception 'Genel Kurulda yalnız milletvekilleri oy kullanır.'; end if;
  if oyun.tbmm_baskani() = p.id then raise exception 'Meclis Başkanı Genel Kurulda oy kullanamaz (Anayasa m.94).'; end if;
  if oyun.gk_cikarilmis(p.id, b) then raise exception 'Meclisten geçici çıkarma cezan sürüyor.'; end if;
  if o.konu = 'disiplin' and (select user_id from oyun.gk_disiplin where id = o.ref_id) = p.id then raise exception 'Kendi disiplin cezanın oylamasına katılamazsın.'; end if;
  insert into oyun.gk_oy(oylama_id, user_id, oy, parti_id, zaman) values (o.id, p.id, p_oy, p.parti_id, t)
  on conflict (oylama_id, user_id) do update set oy = excluded.oy, zaman = excluded.zaman, parti_id = excluded.parti_id;
  insert into oyun.gk_salonda(birlesim_id, user_id, son, vekil) values (b.id, p.id, t, true)
  on conflict (birlesim_id, user_id) do update set son = excluded.son, vekil = true;
  perform oyun.gk_kirlet();
  return jsonb_build_object('tamam', true, 'oy', p_oy);
end $f$;

-- Karar yeter sayısı istemi (grup başkanvekili)
create or replace function public.gk_karar_yeter_iste(p_oylama bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); o oyun.gk_oylama; gp bigint := oyun.gk_grup_parti(p.id);
begin
  if gp is null then raise exception 'Karar yeter sayısını grup başkanvekilleri ister.'; end if;
  select * into o from oyun.gk_oylama where id = p_oylama for update;
  if o.id is null or o.durum <> 'acik' then raise exception 'Bu oylama kapandı.'; end if;
  if o.yeter_istendi then raise exception 'Karar yeter sayısı zaten arandı.'; end if;
  if (select count(*) from oyun.gk_oylama x join oyun.gk_birlesim bb on bb.id = x.birlesim_id where x.birlesim_id = o.birlesim_id and x.yeter_isteyen is not null
        and oyun.gk_grup_parti(x.yeter_isteyen) = gp) >= 2 then raise exception 'Grubun bu birleşimde karar yeter sayısını 2 kez istedi.'; end if;
  update oyun.gk_oylama set yeter_istendi = true, yeter_isteyen = p.id where id = o.id;
  perform oyun.gk_baskan(o.birlesim_id, format('%s Grubu karar yeter sayısı istedi; oylamayı elektronik cihazla sayacağım. Karar yeter sayısı %s.',
    (select kisa from oyun.partiler where id = gp), oyun.gk_karar_yeter()), null, t);
  return jsonb_build_object('tamam', true);
end $f$;

-- Andiçme (dönemin ilk birleşimi)
create or replace function public.gk_andic()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); g oyun.gk_gundem;
begin
  if not oyun.gk_vekil(p.id) then raise exception 'Andı milletvekilleri içer.'; end if;
  if b.id is null or b.durum <> 'acik' then raise exception 'Andiçme töreni Genel Kurul açıkken yapılır.'; end if;
  select * into g from oyun.gk_gundem where id = b.aktif_gundem;
  if g.tur is distinct from 'yemin' then raise exception 'Şu an andiçme töreni yapılmıyor.'; end if;
  insert into oyun.gk_yemin(donem, user_id, zaman, birlesim_id) values (b.donem, p.id, t, b.id) on conflict do nothing;
  if not found then raise exception 'Andını zaten içtin.'; end if;
  perform oyun.gk_yaz(b.id, 'yemin', p.id,
    'Devletin varlığı ve bağımsızlığını, vatanın ve milletin bölünmez bütünlüğünü, milletin kayıtsız şartsız egemenliğini koruyacağıma; hukukun üstünlüğüne, demokratik ve laik Cumhuriyete ve Atatürk ilke ve inkılâplarına bağlı kalacağıma; toplumun huzur ve refahı, millî dayanışma ve adalet anlayışı içinde herkesin insan haklarından ve temel hürriyetlerinden yararlanması ülküsünden ve Anayasaya sadakatten ayrılmayacağıma; büyük Türk Milleti önünde namusum ve şerefim üzerine andiçerim.',
    null, null, null, t);
  update oyun.gk_birlesim set kursu_bos = t where id = b.id;
  return jsonb_build_object('tamam', true);
end $f$;

-- Gündem dışı söz istemi (o günün birleşimi için)
create or replace function public.gk_gundem_disi_iste(p_konu text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); k text; v_gun date; n int;
begin
  if not oyun.gk_vekil(p.id) then raise exception 'Gündem dışı sözü milletvekilleri ister.'; end if;
  k := btrim(regexp_replace(coalesce(p_konu, ''), '\s+', ' ', 'g'));
  if char_length(k) not between 10 and 150 then raise exception 'Konu 10–150 karakter olmalı.'; end if;
  if oyun.kufurlu(k) then raise exception 'Konuda uygunsuz bir ifade var.'; end if;
  v_gun := coalesce(b.gun, oyun.gk_gun(t));
  if b.id is not null and exists (select 1 from oyun.gk_gundem g where g.birlesim_id = b.id and ((g.tur = 'gundem_disi' and g.durum <> 'bekliyor')
                                    or (g.tur not in ('yemin', 'sunus', 'gundem_disi') and g.durum <> 'bekliyor'))) then
    v_gun := v_gun + 1;  -- bugünkü gündem dışı bölümü geçti: yarınki birleşime yazılır
  end if;
  insert into oyun.gk_gundem_disi(gun, user_id, konu, istek) values (v_gun, p.id, k, t);
  if b.id is not null and b.gun = v_gun and not exists (select 1 from oyun.gk_gundem g where g.birlesim_id = b.id and g.tur = 'gundem_disi') then
    select min(g.sira) into n from oyun.gk_gundem g where g.birlesim_id = b.id and g.durum = 'bekliyor' and g.tur not in ('yemin', 'sunus');
    if n is null then
      perform oyun.gk_madde_ekle(b.id, 'gundem_disi', null, 'Gündem dışı konuşmalar');
    else
      update oyun.gk_gundem set sira = sira + 1 where birlesim_id = b.id and sira >= n;
      insert into oyun.gk_gundem(birlesim_id, sira, tur, baslik) values (b.id, n, 'gundem_disi', 'Gündem dışı konuşmalar');
    end if;
  end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true, 'gun', v_gun);
exception when unique_violation then raise exception 'Bu birleşim için zaten gündem dışı söz istedin.';
end $f$;

-- Siyasi parti grubu önerisi
create or replace function public.gk_grup_onerisi_ver(p_tur text, p_baslik text, p_metin text, p_ref bigint default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); gp bigint := oyun.gk_grup_parti(p.id); b oyun.gk_birlesim := oyun.gk_su_an();
  v_gun date; bs text; mt text; v_id bigint; v_kisa text;
begin
  if gp is null then raise exception 'Grup önerisini grup başkanvekili ya da milletvekili genel başkan verir (grubu olan partide).'; end if;
  if p_tur not in ('gundem', 'uzatma', 'bildiri', 'genel_gorusme') then raise exception 'Geçersiz öneri türü.'; end if;
  bs := btrim(regexp_replace(coalesce(p_baslik, ''), '\s+', ' ', 'g'));
  mt := btrim(coalesce(p_metin, ''));
  if p_tur = 'uzatma' then bs := coalesce(nullif(bs, ''), 'Genel Kurul çalışma süresinin uzatılması'); mt := coalesce(nullif(mt, ''), 'Genel Kurulun bugünkü birleşimde çalışma süresinin uzatılmasını öneriyoruz.'); end if;
  if char_length(bs) not between 5 and 120 then raise exception 'Başlık 5–120 karakter olmalı.'; end if;
  if char_length(mt) not between 10 and 2000 then raise exception 'Öneri metni 10–2000 karakter olmalı.'; end if;
  if oyun.kufurlu(bs || ' ' || mt) then raise exception 'Öneride uygunsuz bir ifade var.'; end if;
  if p_tur = 'gundem' and not exists (select 1 from oyun.kanunlar k where k.id = p_ref and k.durum in ('gorusmede', 'oylamada', 'israr')) then
    raise exception 'Gündemin başına alınacak kanun teklifini seç.'; end if;
  if p_tur = 'genel_gorusme' and not exists (select 1 from oyun.gk_genel_gorusme g where g.id = p_ref and g.durum in ('bekliyor', 'imza')) then
    raise exception 'Bekleyen bir genel görüşme önergesi seç.'; end if;
  v_gun := coalesce(b.gun, oyun.gk_gun(t));
  if p_tur = 'uzatma' and (b.id is null or b.durum <> 'acik') then raise exception 'Çalışma süresi önerisi birleşim açıkken verilir.'; end if;
  if exists (select 1 from oyun.gk_grup_onerisi x where x.parti_id = gp and x.gun = v_gun and x.durum <> 'geri') then
    raise exception 'Grubun bugün zaten bir öneri verdi.'; end if;
  insert into oyun.gk_grup_onerisi(gun, parti_id, veren, tur, baslik, metin, ref_id, zaman) values (v_gun, gp, p.id, p_tur, bs, mt, p_ref, t) returning id into v_id;
  select kisa into v_kisa from oyun.partiler where id = gp;
  if b.id is not null and b.gun = v_gun then
    perform oyun.gk_madde_ekle(b.id, 'grup_onerisi', v_id, format('%s Grubu önerisi: %s', v_kisa, bs));
  end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

create or replace function public.gk_grup_onerisi_geri(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); o oyun.gk_grup_onerisi;
begin
  select * into o from oyun.gk_grup_onerisi where id = p_id for update;
  if o.id is null or o.durum <> 'bekliyor' then raise exception 'Öneri geri çekilemez.'; end if;
  if oyun.gk_grup_parti(p.id) is distinct from o.parti_id then raise exception 'Öneriyi grubun yetkilileri geri çeker.'; end if;
  update oyun.gk_grup_onerisi set durum = 'geri' where id = o.id;
  delete from oyun.gk_gundem where tur = 'grup_onerisi' and ref_id = o.id and durum = 'bekliyor';
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true);
end $f$;

-- Kapalı oturum istemi (Anayasa/İçtüzük: Cumhurbaşkanı, bakan, grup başkanvekili)
create or replace function public.gk_kapali_oturum_iste(p_gerekce text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); g text;
begin
  if not (oyun.gk_hukumet(p.id) or oyun.gk_grup_parti(p.id) is not null) then raise exception 'Kapalı oturumu Hükümet üyeleri ve grup başkanvekilleri ister.'; end if;
  if b.id is null or b.durum <> 'acik' then raise exception 'Birleşim açık değil.'; end if;
  if b.kapali then raise exception 'Zaten kapalı oturumdayız.'; end if;
  g := btrim(coalesce(p_gerekce, ''));
  if char_length(g) not between 10 and 300 then raise exception 'Gerekçe 10–300 karakter olmalı.'; end if;
  if exists (select 1 from oyun.gk_oylama o where o.birlesim_id = b.id and o.konu = 'kapali_oturum' and o.durum <> 'iptal' and o.bas > t - interval '30 minutes') then
    raise exception 'Kapalı oturum istemi son 30 dakikada oylandı.'; end if;
  perform oyun.gk_yaz(b.id, 'sistem', p.id, 'Kapalı oturum istemi: ' || g, null, null, null, t);
  perform oyun.gk_oylama_ac(b.id, 'kapali_oturum', null, 'Kapalı oturuma geçilmesini', null, t);
  return jsonb_build_object('tamam', true);
end $f$;

-- Genel görüşme önergesi (grup adına ya da imzayla)
create or replace function oyun.gk_gg_imza_yeter() returns int
language sql stable set search_path to '' as $f$ select greatest(5, ceil(oyun.gk_taban() * 20 / 600.0))::int $f$;

create or replace function public.gk_gg_ver(p_konu text, p_gerekce text, p_grup_adina boolean default false)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; g text; gp bigint := oyun.gk_grup_parti(p.id); v_id bigint;
begin
  if not oyun.gk_vekil(p.id) then raise exception 'Genel görüşme önergesini milletvekilleri verir.'; end if;
  if oyun.tbmm_baskani() = p.id then raise exception 'Meclis Başkanı önerge veremez.'; end if;
  if p_grup_adina and gp is null then raise exception 'Grup adına önergeyi grup başkanvekili verir.'; end if;
  k := btrim(regexp_replace(coalesce(p_konu, ''), '\s+', ' ', 'g')); g := btrim(coalesce(p_gerekce, ''));
  if char_length(k) not between 10 and 150 then raise exception 'Konu 10–150 karakter olmalı.'; end if;
  if char_length(g) not between 50 and 6000 then raise exception 'Gerekçe 50–6000 karakter olmalı.'; end if;
  if oyun.kufurlu(k || ' ' || g) then raise exception 'Önergede uygunsuz bir ifade var.'; end if;
  if exists (select 1 from oyun.gk_genel_gorusme x where x.veren = p.id and x.durum in ('imza', 'bekliyor')) then raise exception 'Bekleyen bir genel görüşme önergen var.'; end if;
  if (select count(*) from oyun.gk_genel_gorusme x where x.durum in ('imza', 'bekliyor')) >= 6 then raise exception 'Meclis gündeminde aynı anda en çok 6 genel görüşme önergesi bekleyebilir.'; end if;
  insert into oyun.gk_genel_gorusme(no, konu, gerekce, veren, parti_id, grup_adina, durum, olusturma, imza_bit)
  values ((select coalesce(max(no), 0) + 1 from oyun.gk_genel_gorusme), k, g, p.id, case when p_grup_adina then gp else p.parti_id end, p_grup_adina,
          case when p_grup_adina then 'bekliyor' else 'imza' end, t, case when p_grup_adina then null else t + interval '48 hours' end)
  returning id into v_id;
  insert into oyun.gk_gg_imza(gg_id, user_id, zaman) values (v_id, p.id, t);
  perform oyun.olay('meclis', format('%s genel görüşme önergesi verdi: "%s".', oyun.gk_kimlik(p.id) ->> 'ad', k), null, p.parti_id, t);
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

create or replace function public.gk_gg_imza(p_id bigint, p_imza boolean default true)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); g oyun.gk_genel_gorusme; n int;
begin
  if not oyun.gk_vekil(p.id) then raise exception 'Önergeyi milletvekilleri imzalar.'; end if;
  select * into g from oyun.gk_genel_gorusme where id = p_id for update;
  if g.id is null or g.durum <> 'imza' or g.imza_bit <= t then raise exception 'Önerge imzaya açık değil.'; end if;
  if g.veren = p.id then raise exception 'Önerge sahibisin.'; end if;
  if p_imza then insert into oyun.gk_gg_imza(gg_id, user_id, zaman) values (g.id, p.id, t) on conflict do nothing;
  else delete from oyun.gk_gg_imza where gg_id = g.id and user_id = p.id; end if;
  select count(*) into n from oyun.gk_gg_imza where gg_id = g.id;
  if n >= oyun.gk_gg_imza_yeter() then
    update oyun.gk_genel_gorusme set durum = 'bekliyor' where id = g.id;
    perform oyun.bildir(g.veren, format('Genel görüşme önergen yeterli imzaya ulaştı (%s). İlk birleşimde ön görüşmesi yapılacak.', n), t);
    if (oyun.gk_su_an()).id is not null and (oyun.gk_su_an()).durum = 'acik' then
      perform oyun.gk_madde_ekle((oyun.gk_su_an()).id, 'genel_gorusme_on', g.id, format('%s esas numaralı genel görüşme önergesinin ön görüşmesi: %s', g.no, g.konu));
    end if;
  end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true, 'imza', n, 'yeter', oyun.gk_gg_imza_yeter());
end $f$;

create or replace function public.gk_gg_liste()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim();
begin
  return jsonb_build_object('yeter', oyun.gk_gg_imza_yeter(), 'vekilim', oyun.gk_vekil(p.id), 'grup', oyun.gk_grup_parti(p.id) is not null,
    'liste', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'no', g.no, 'konu', g.konu, 'gerekce', g.gerekce, 'durum', g.durum, 'grup_adina', g.grup_adina,
       'olusturma', g.olusturma, 'imza_bit', g.imza_bit, 'karar_at', g.karar_at, 'sonuc', g.sonuc_metin, 'veren', oyun.gk_kimlik(g.veren),
       'imza', (select count(*) from oyun.gk_gg_imza i where i.gg_id = g.id),
       'imzaladim', exists (select 1 from oyun.gk_gg_imza i where i.gg_id = g.id and i.user_id = p.id),
       'imzacilar', (select coalesce(jsonb_agg(oyun.gk_kimlik(i.user_id) ->> 'ad' order by i.zaman), '[]'::jsonb) from oyun.gk_gg_imza i where i.gg_id = g.id),
       'benim', g.veren = p.id) order by (g.durum in ('imza', 'bekliyor', 'acildi')) desc, g.id desc)
       from (select * from oyun.gk_genel_gorusme order by id desc limit 60) g), '[]'::jsonb));
end $f$;

create or replace function public.gk_gg_geri(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); g oyun.gk_genel_gorusme;
begin
  select * into g from oyun.gk_genel_gorusme where id = p_id for update;
  if g.id is null or g.veren <> p.id or g.durum not in ('imza', 'bekliyor') then raise exception 'Önerge geri çekilemez.'; end if;
  update oyun.gk_genel_gorusme set durum = 'geri' where id = g.id;
  delete from oyun.gk_gundem where tur = 'genel_gorusme_on' and ref_id = g.id and durum = 'bekliyor';
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true);
end $f$;

-- ---------------------------------------------------------------- BAŞKANLIK RPC'LERİ
create or replace function oyun.gk_yonetici_zorunlu(p oyun.profiller) returns oyun.gk_birlesim
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim := oyun.gk_su_an();
begin
  if not (oyun.gk_yonetebilir(p.id) or coalesce(p.yonetici, false)) then raise exception 'Bu işlemi Meclis Başkanı ve başkanvekilleri yapar.'; end if;
  if b.id is null then raise exception 'Genel Kurul toplantı hâlinde değil.'; end if;
  if oyun.gk_yonetebilir(p.id) then update oyun.gk_birlesim set yoneten = p.id where id = b.id and yoneten is distinct from p.id; end if;
  return b;
end $f$;

create or replace function public.gk_birlesim_ac()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim;
begin
  if not (oyun.gk_yonetebilir(p.id) or coalesce(p.yonetici, false)) then raise exception 'Birleşimi Meclis Başkanı ya da başkanvekili açar.'; end if;
  if (oyun.gk_su_an()).id is not null then raise exception 'Birleşim zaten açık.'; end if;
  select * into b from oyun.gk_birlesim where durum = 'planli' and plan_bas <= t + interval '2 minutes' and plan_bit > t order by plan_bas limit 1;
  if b.id is null then raise exception 'Açılacak birleşimin saati gelmedi.'; end if;
  perform oyun.gk_ac(b.id, greatest(t, b.plan_bas - interval '2 minutes'), p.id);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.gk_soz_ver(p_soz bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); s oyun.meclis_soz;
begin
  if b.durum <> 'acik' then raise exception 'Oturum açık değil.'; end if;
  if exists (select 1 from oyun.gk_oylama o where o.birlesim_id = b.id and o.durum = 'acik') then raise exception 'Oylama sürerken söz verilmez.'; end if;
  select * into s from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi' limit 1;
  if s.id is not null then raise exception 'Kürsüde konuşmacı var; önce konuşmanın bitmesini bekle ya da sözü kes.'; end if;
  select * into s from oyun.meclis_soz where id = p_soz and birlesim_id = b.id and gk and durum = 'bekliyor';
  if s.id is null then raise exception 'Bu istem artık sırada değil.'; end if;
  perform oyun.gk_soz_baslat(b.id, s.id, p.id, t);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.gk_soz_reddet(p_soz bigint, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); s oyun.meclis_soz; g text := btrim(coalesce(p_gerekce, ''));
begin
  if char_length(g) not between 5 and 200 then raise exception 'Gerekçe 5–200 karakter olmalı (vekil görür).'; end if;
  select * into s from oyun.meclis_soz where id = p_soz and birlesim_id = b.id and gk and durum = 'bekliyor' for update;
  if s.id is null then raise exception 'Bu istem artık sırada değil.'; end if;
  update oyun.meclis_soz set durum = 'ret', veren = p.id, verildi = t where id = s.id;
  perform oyun.bildir(s.user_id, format('Meclis Başkanlığı söz istemini karşılamadı: %s', g), t);
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true);
end $f$;

-- Sırayı düzenle: öne al (1), bir yukarı (2), bir aşağı (3), sona at (4)
create or replace function public.gk_soz_sira(p_soz bigint, p_yon int)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); s oyun.meclis_soz; komsu oyun.meclis_soz; v numeric;
begin
  select * into s from oyun.meclis_soz where id = p_soz and birlesim_id = b.id and gk and durum = 'bekliyor' for update;
  if s.id is null then raise exception 'Bu istem artık sırada değil.'; end if;
  if s.tur = 'gundem_disi' then raise exception 'Gündem dışı konuşmacıların sırası değiştirilmez.'; end if;
  if p_yon = 1 then
    select coalesce(min(sira_no), 0) - 1 into v from oyun.meclis_soz where birlesim_id = b.id and gk and durum = 'bekliyor' and tur <> 'gundem_disi';
    update oyun.meclis_soz set sira_no = v where id = s.id;
  elsif p_yon = 4 then
    select coalesce(max(sira_no), 0) + 1 into v from oyun.meclis_soz where birlesim_id = b.id and gk and durum = 'bekliyor' and tur <> 'gundem_disi';
    update oyun.meclis_soz set sira_no = v where id = s.id;
  elsif p_yon in (2, 3) then
    select * into komsu from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'bekliyor' and x.tur <> 'gundem_disi' and x.id <> s.id
      and case when p_yon = 2 then (coalesce(x.sira_no, 1e12), x.id) < (coalesce(s.sira_no, 1e12), s.id) else (coalesce(x.sira_no, 1e12), x.id) > (coalesce(s.sira_no, 1e12), s.id) end
      order by case when p_yon = 2 then coalesce(x.sira_no, 1e12) end desc, case when p_yon = 3 then coalesce(x.sira_no, 1e12) end asc limit 1;
    if komsu.id is not null then
      update oyun.meclis_soz set sira_no = coalesce(komsu.sira_no, 1e12) where id = s.id;
      update oyun.meclis_soz set sira_no = coalesce(s.sira_no, 1e12) where id = komsu.id;
      if coalesce(komsu.sira_no, 1e12) = coalesce(s.sira_no, 1e12) then
        update oyun.meclis_soz set sira_no = coalesce(s.sira_no, 1e12) + case when p_yon = 2 then -0.5 else 0.5 end where id = s.id;
      end if;
    end if;
  else raise exception 'Geçersiz yön.';
  end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.gk_ek_sure(p_soz bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); s oyun.meclis_soz;
begin
  select * into s from oyun.meclis_soz where id = p_soz and birlesim_id = b.id and gk for update;
  if s.id is null then raise exception 'Konuşma bulunamadı.'; end if;
  if s.ek_sure then raise exception 'Bu konuşmacıya ek süre zaten verildi.'; end if;
  if not (s.durum = 'verildi' or (s.durum = 'kullanildi' and coalesce(s.kullanildi > t - interval '45 seconds', false) and s.kelime_kullanilan > 0)) then
    raise exception 'Ek süre ancak konuşma sürerken ya da mikrofon kapandıktan hemen sonra verilir.'; end if;
  if s.durum = 'kullanildi' and exists (select 1 from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi') then
    raise exception 'Kürsüde başka konuşmacı var.'; end if;
  update oyun.meclis_soz set ek_sure = true, durum = 'verildi', kullanildi = null,
         kursu_bas = coalesce(kursu_bas, t), kursu_bit = greatest(coalesce(kursu_bit, t), t) + interval '60 seconds' where id = s.id;
  perform oyun.gk_baskan(b.id, format('Sayın %s, tamamlayın lütfen; bir dakika ek süre veriyorum.', oyun.gk_kimlik(s.user_id) ->> 'ad'), p.id, t);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.gk_sozu_kes(p_soz bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); s oyun.meclis_soz;
begin
  select * into s from oyun.meclis_soz where id = p_soz and birlesim_id = b.id and gk and durum = 'verildi';
  if s.id is null then raise exception 'Kürsüde bu konuşmacı yok.'; end if;
  perform oyun.gk_soz_kapat(s.id, t, 'kes');
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.gk_ara_ver(p_dk int)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); s oyun.meclis_soz;
begin
  if b.durum <> 'acik' then raise exception 'Oturum açık değil.'; end if;
  if p_dk not in (5, 10, 15) then raise exception 'Ara 5, 10 ya da 15 dakika olabilir.'; end if;
  if exists (select 1 from oyun.gk_oylama o where o.birlesim_id = b.id and o.durum = 'acik') then raise exception 'Oylama sürerken ara verilmez.'; end if;
  if t + make_interval(mins => p_dk) >= oyun.gk_bitis(b) then raise exception 'Ara birleşimin bitişini geçemez.'; end if;
  select * into s from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi' limit 1;
  if s.id is not null then perform oyun.gk_soz_kapat(s.id, t, 'kes'); end if;
  update oyun.gk_birlesim set durum = 'arada', ara_bit = t + make_interval(mins => p_dk), ara_neden = 'baskan' where id = b.id;
  perform oyun.gk_baskan(b.id, format('Birleşime %s dakika ara veriyorum.', p_dk), p.id, t);
  return jsonb_build_object('tamam', true);
end $f$;

-- Gündemde sonraki maddeye geç / belirli maddeye geç / oylamayı aç
create or replace function public.gk_gundem_gec(p_madde bigint default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); g oyun.gk_gundem; hedef oyun.gk_gundem;
begin
  if b.durum <> 'acik' then raise exception 'Oturum açık değil.'; end if;
  if exists (select 1 from oyun.gk_oylama o where o.birlesim_id = b.id and o.durum = 'acik') then raise exception 'Oylama sürüyor.'; end if;
  if exists (select 1 from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi') then raise exception 'Kürsüde konuşmacı var.'; end if;
  if p_madde is not null then
    select * into hedef from oyun.gk_gundem where id = p_madde and birlesim_id = b.id and durum = 'bekliyor';
    if hedef.id is null then raise exception 'Bu madde bekleyen gündemde yok.'; end if;
    update oyun.gk_gundem set sira = (select coalesce(min(sira), 1) from oyun.gk_gundem where birlesim_id = b.id and durum = 'bekliyor') - 1 where id = hedef.id;
  end if;
  select * into g from oyun.gk_gundem where id = b.aktif_gundem;
  if g.id is not null then
    if g.tur in ('grup_onerisi', 'genel_gorusme_on') and not exists (select 1 from oyun.gk_oylama o where o.gundem_id = g.id and o.durum <> 'iptal') and p_madde is null then
      raise exception 'Bu öneri oylanmadan geçilemez; "Oylamaya sun" düğmesini kullan.'; end if;
    if g.tur in ('grup_onerisi') then update oyun.gk_grup_onerisi set durum = 'dustu' where id = g.ref_id and durum = 'gorusuluyor'; end if;
    perform oyun.gk_madde_bitir(b.id, g.id, t);
  else
    perform oyun.gk_madde_baslat(b.id, (select x.id from oyun.gk_gundem x where x.birlesim_id = b.id and x.durum = 'bekliyor' order by x.sira limit 1), t);
  end if;
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.gk_oylamaya_sun(p_konu text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); g oyun.gk_gundem; v_id bigint; v_kisa text;
begin
  if b.durum <> 'acik' then raise exception 'Oturum açık değil.'; end if;
  if exists (select 1 from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi') then raise exception 'Kürsüde konuşmacı var.'; end if;
  if p_konu = 'uzatma' then
    if b.uzatma >= (select uzatma_azami from oyun.gk_ayar where id = 1) then raise exception 'Çalışma süresi en çok % kez uzatılabilir.', (select uzatma_azami from oyun.gk_ayar where id = 1); end if;
    if t < oyun.gk_bitis(b) - interval '25 minutes' then raise exception 'Uzatma, birleşimin son 25 dakikasında oylanır.'; end if;
    v_id := oyun.gk_oylama_ac(b.id, 'uzatma', null, format('Çalışma süresinin %s dakika uzatılmasını', (select uzatma_dk from oyun.gk_ayar where id = 1)), p.id, t);
    return jsonb_build_object('tamam', true, 'id', v_id);
  end if;
  select * into g from oyun.gk_gundem where id = b.aktif_gundem;
  if g.id is null or g.tur not in ('grup_onerisi', 'genel_gorusme_on') then raise exception 'Gündemdeki madde oylanacak bir öneri değil.'; end if;
  if exists (select 1 from oyun.gk_oylama o where o.gundem_id = g.id and o.durum <> 'iptal') then raise exception 'Bu madde zaten oylandı.'; end if;
  if g.tur = 'grup_onerisi' then
    select pa.kisa into v_kisa from oyun.gk_grup_onerisi x join oyun.partiler pa on pa.id = x.parti_id where x.id = g.ref_id;
    v_id := oyun.gk_oylama_ac(b.id, 'grup_onerisi', g.ref_id, format('%s Grubunun önerisini', v_kisa), p.id, t);
  else
    v_id := oyun.gk_oylama_ac(b.id, 'genel_gorusme', g.ref_id, 'Genel görüşme açılıp açılmamasını', p.id, t);
  end if;
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

create or replace function public.gk_yoklama_iste()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); gp bigint := oyun.gk_grup_parti(p.id);
begin
  if not (oyun.gk_yonetebilir(p.id) or coalesce(p.yonetici, false) or gp is not null) then raise exception 'Yoklamayı Başkanlık yapar ya da grup başkanvekili ister.'; end if;
  if b.id is null or b.durum <> 'acik' then raise exception 'Oturum açık değil.'; end if;
  if exists (select 1 from oyun.meclis_soz x where x.birlesim_id = b.id and x.gk and x.durum = 'verildi') then raise exception 'Kürsüde konuşmacı varken yoklama istenmez.'; end if;
  if exists (select 1 from oyun.gk_oylama o where o.birlesim_id = b.id and o.durum = 'acik') then raise exception 'Oylama sürüyor.'; end if;
  if exists (select 1 from oyun.gk_yoklama y where y.birlesim_id = b.id and y.bas > t - interval '20 minutes') then raise exception 'Son 20 dakikada yoklama yapıldı.'; end if;
  if gp is not null and not (oyun.gk_yonetebilir(p.id) or coalesce(p.yonetici, false)) then
    if exists (select 1 from oyun.gk_yoklama y where y.birlesim_id = b.id and y.neden = 'istem' and oyun.gk_grup_parti(y.isteyen) = gp) then
      raise exception 'Grubun bu birleşimde yoklama istedi.'; end if;
    perform oyun.gk_baskan(b.id, format('%s Grubu yoklama istedi.', (select kisa from oyun.partiler where id = gp)), null, t);
  end if;
  perform oyun.gk_yoklama_baslat(b.id, 'istem', p.id, t);
  return jsonb_build_object('tamam', true);
end $f$;

-- Oylama zili: oylamadaki kanun için oy kullanmamış vekillere çağrı
create or replace function public.gk_zil(p_kanun bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); k oyun.kanunlar; n int;
begin
  select * into k from oyun.kanunlar where id = p_kanun and durum in ('oylamada', 'israr');
  if k.id is null then raise exception 'Bu teklif oylamada değil.'; end if;
  insert into oyun.gk_zil(birlesim_id, kanun_id, zaman) values (b.id, k.id, t) on conflict do nothing;
  if not found then raise exception 'Bu birleşimde bu teklif için zil çalındı.'; end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
  select distinct m.user_id, t, format('Zil çaldı: Genel Kurulda "%s" teklifinin oylaması sürüyor. Oyunu kullan.', left(k.baslik, 90))
  from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
  where m.tur = 'mv' and m.bit is null and not coalesce(pr.yasakli, false)
    and not exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = m.user_id and o.asama = case when k.durum = 'israr' then 'israr' else 'ilk' end)
  limit 700;
  get diagnostics n = row_count;
  perform oyun.gk_yaz(b.id, 'sistem', null, format('(Oylama zili çalındı: %s — oy kullanmayan %s milletvekili çağrıldı.)', k.baslik, n), null, null, null, t);
  return jsonb_build_object('tamam', true, 'cagrilan', n);
end $f$;

-- Disiplin: uyarma hemen; kınama ve geçici çıkarma Genel Kurul oyuyla (görüşmesiz)
create or replace function public.gk_disiplin(p_kad text, p_tur text, p_gerekce text, p_birlesim int default 1)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p); h oyun.profiller; g text; v_id bigint; v_ad text;
begin
  select * into h from oyun.profiller where kad = p_kad;
  if h.id is null then raise exception 'Milletvekili bulunamadı.'; end if;
  if not oyun.gk_vekil(h.id) then raise exception 'Disiplin cezası milletvekillerine verilir.'; end if;
  if h.id = p.id then raise exception 'Kendine ceza veremezsin.'; end if;
  if p_tur not in ('uyarma', 'kinama', 'cikarma') then raise exception 'Geçersiz ceza.'; end if;
  g := btrim(coalesce(p_gerekce, ''));
  if char_length(g) not between 5 and 300 then raise exception 'Gerekçe 5–300 karakter olmalı.'; end if;
  v_ad := oyun.gk_kimlik(h.id) ->> 'ad';
  if p_tur = 'uyarma' then
    insert into oyun.gk_disiplin(birlesim_id, user_id, veren, tur, gerekce, durum, zaman) values (b.id, h.id, p.id, 'uyarma', g, 'uygulandi', t);
    perform oyun.gk_baskan(b.id, format('Sayın %s, %s; sizi uyarıyorum. Uyarma cezası tutanağa geçmiştir.', v_ad, g), p.id, t);
    perform oyun.bildir(h.id, format('Meclis Başkanlığı sana uyarma cezası verdi: %s', g), t);
    return jsonb_build_object('tamam', true);
  end if;
  if b.durum <> 'acik' then raise exception 'Oturum açık değil.'; end if;
  if exists (select 1 from oyun.gk_disiplin d where d.user_id = h.id and d.durum = 'teklif') then raise exception 'Bu vekil için bekleyen bir ceza teklifi var.'; end if;
  insert into oyun.gk_disiplin(birlesim_id, user_id, veren, tur, gerekce, birlesim_sayi, zaman)
  values (b.id, h.id, p.id, p_tur, g, case when p_tur = 'cikarma' then least(3, greatest(1, coalesce(p_birlesim, 1))) else 0 end, t) returning id into v_id;
  perform oyun.gk_baskan(b.id, format('Başkanlık Divanı, %s nedeniyle Sayın %s hakkında %s cezası verilmesini teklif etmektedir. Teklif görüşmesiz oylanacaktır.', g, v_ad,
    case when p_tur = 'kinama' then 'kınama' else format('%s birleşim Meclisten geçici çıkarma', least(3, greatest(1, coalesce(p_birlesim, 1)))) end), p.id, t);
  perform oyun.gk_oylama_ac(b.id, 'disiplin', v_id, format('Sayın %s hakkındaki %s cezası teklifini', v_ad, case when p_tur = 'kinama' then 'kınama' else 'geçici çıkarma' end), p.id, t);
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

create or replace function public.gk_acik_oturum()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_yonetici_zorunlu(p);
begin
  if not b.kapali then raise exception 'Kapalı oturumda değiliz.'; end if;
  update oyun.gk_birlesim set kapali = false where id = b.id;
  perform oyun.gk_baskan(b.id, 'Kapalı oturum sona ermiştir; açık oturuma geçiyoruz.', p.id, t);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.gk_gundem_disi_sec(p_id bigint, p_sec boolean default true)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.gk_gundem_disi; n int;
begin
  if not (oyun.gk_yonetebilir(p.id) or coalesce(p.yonetici, false)) then raise exception 'Gündem dışı konuşmacıları Meclis Başkanlığı seçer.'; end if;
  select * into d from oyun.gk_gundem_disi where id = p_id for update;
  if d.id is null or d.durum not in ('bekliyor', 'secildi') then raise exception 'İstem bulunamadı.'; end if;
  if p_sec then
    select count(*) into n from oyun.gk_gundem_disi x where x.gun = d.gun and x.durum = 'secildi';
    if n >= (select gundem_disi_sayi from oyun.gk_ayar where id = 1) then raise exception 'Bir birleşimde en çok % gündem dışı konuşma yapılır.', (select gundem_disi_sayi from oyun.gk_ayar where id = 1); end if;
    update oyun.gk_gundem_disi set durum = 'secildi', secen = p.id where id = d.id;
  else
    update oyun.gk_gundem_disi set durum = 'bekliyor', secen = null where id = d.id;
  end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true);
end $f$;

-- Olağanüstü birleşim (Meclis Başkanı ya da Cumhurbaşkanı; Anayasa m.93)
create or replace function public.gk_olaganustu_cagir(p_bas timestamptz, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); g text := btrim(coalesce(p_gerekce, '')); v_bas timestamptz; v_id bigint; kim text;
begin
  if not (oyun.tbmm_baskani() is not distinct from p.id or exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null) or coalesce(p.yonetici, false)) then
    raise exception 'Olağanüstü birleşimi Meclis Başkanı ya da Cumhurbaşkanı çağırır.'; end if;
  if oyun.dolu_sandalye() = 0 then raise exception 'Meclis''te görevde milletvekili yok.'; end if;
  v_bas := date_trunc('minute', p_bas);
  if v_bas < t + interval '60 minutes' or v_bas > t + interval '72 hours' then raise exception 'Olağanüstü birleşim en az 1 saat, en çok 3 gün sonrası için çağrılır.'; end if;
  if char_length(g) not between 10 and 300 then raise exception 'Gerekçe 10–300 karakter olmalı.'; end if;
  if exists (select 1 from oyun.gk_birlesim x where x.durum in ('planli', 'yoklama', 'acik', 'arada') and tstzrange(x.plan_bas - interval '15 minutes', oyun.gk_bitis(x) + interval '15 minutes') && tstzrange(v_bas, v_bas + interval '60 minutes')) then
    raise exception 'Bu saat başka bir birleşimle çakışıyor.'; end if;
  if exists (select 1 from oyun.gk_birlesim x where x.tur = 'olaganustu' and x.gun = oyun.gk_gun(v_bas) and x.durum <> 'iptal') then raise exception 'Aynı güne ikinci olağanüstü birleşim çağrılamaz.'; end if;
  insert into oyun.gk_birlesim(tur, gun, plan_bas, plan_bit, cagiran, gerekce) values ('olaganustu', oyun.gk_gun(v_bas), v_bas, v_bas + interval '60 minutes', p.id, g) returning id into v_id;
  kim := oyun.gk_kimlik(p.id) ->> 'rol';
  perform oyun.gk_vekillere_bildir(format('TBMM olağanüstü toplantıya çağrıldı: %s saat %s. Gerekçe: %s', to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM'), oyun.gk_saat(v_bas), left(g, 120)), t);
  perform oyun.ajans_yayinla('tbmm-olaganustu-' || v_id, 'meclis', format('TBMM olağanüstü toplantıya çağrıldı (%s %s)', to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM'), oyun.gk_saat(v_bas)),
    format('%s %s Meclis''i olağanüstü toplantıya çağırdı.', coalesce(kim, ''), oyun.gk_kimlik(p.id) ->> 'ad'), g, 70, null, null, t);
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

-- İçerik Masası: tutanaktan çıkarma
create or replace function public.gk_tutanak_kaldir(p_id bigint, p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); r oyun.gk_tutanak;
begin
  if not coalesce(p.yonetici, false) then perform oyun.yetki_zorunlu('sikayet'); end if;
  select * into r from oyun.gk_tutanak where id = p_id for update;
  if r.id is null then raise exception 'Kayıt bulunamadı.'; end if;
  update oyun.gk_tutanak set gizli = true, kaldiran = p.id where id = r.id;
  if r.mesaj_id is not null then update oyun.mesajlar set gizli = true where id = r.mesaj_id; end if;
  perform oyun.gk_degisti();
  return jsonb_build_object('tamam', true);
end $f$;

-- ---------------------------------------------------------------- TETİKLEYİCİLER
-- Eski uygulamadan Genel Kurul sohbetine yazılan mesaj birleşim açıkken tutanağa geçer
create or replace function oyun.gk_mesaj_ayna_trg() returns trigger
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim; s oyun.meclis_soz; v_tid bigint;
begin
  if new.kanal <> 'meclis' or coalesce(current_setting('oyun.gk_ayna', true), '') = '1' or coalesce(new.gorevli, false) then return null; end if;
  b := oyun.gk_su_an();
  if b.id is null then return null; end if;
  select * into s from oyun.meclis_soz x where x.user_id = new.user_id and x.durum in ('verildi', 'bekliyor') order by x.id desc limit 1;
  insert into oyun.gk_tutanak(birlesim_id, zaman, tur, user_id, ad, kad, il, parti_id, parti_kisa, renk, rol, soz_id, soz_tur, gundem_id, metin, kapali, mesaj_id)
  select b.id, new.zaman, case when oyun.gk_yonetebilir(new.user_id) then 'baskan' else 'konusma' end, new.user_id, k ->> 'ad', k ->> 'kad', k ->> 'il',
         (k ->> 'parti_id')::bigint, k ->> 'kisa', k ->> 'renk', k ->> 'rol', s.id, s.tur, b.aktif_gundem, new.metin, b.kapali, new.id
  from (select oyun.gk_kimlik(new.user_id) k) z
  returning id into v_tid;
  perform oyun.gk_degisti();
  return null;
exception when others then return null;
end $f$;
drop trigger if exists gk_mesaj_ayna on oyun.mesajlar;
create trigger gk_mesaj_ayna after insert on oyun.mesajlar for each row when (new.kanal = 'meclis') execute function oyun.gk_mesaj_ayna_trg();

-- Kanun teklifinin oylaması başlayınca / sonuçlanınca salona duyuru
create or replace function oyun.gk_kanun_trg() returns trigger
language plpgsql security definer set search_path to '' as $f$
declare b oyun.gk_birlesim; a int; r int; c int;
begin
  if new.durum is not distinct from old.durum then return null; end if;
  b := oyun.gk_su_an();
  if b.id is null or b.durum not in ('acik', 'yoklama', 'arada') then return null; end if;
  if new.durum in ('oylamada', 'israr') then
    perform oyun.gk_yaz(b.id, 'sistem', null, format('%s teklifinin %soylaması başladı; elektronik oylama %s''e kadar açıktır.', new.baslik,
      case when new.durum = 'israr' then 'ısrar ' else '' end, oyun.gk_saat(case when new.durum = 'israr' then new.israr_bit else new.oy_bit end)),
      jsonb_build_object('kanun', new.id), null, null, oyun.simdi());
    perform oyun.gk_madde_ekle(b.id, 'kanun_oylama', new.id, format('%s — elektronik oylama', new.baslik));
  elsif old.durum in ('oylamada', 'israr') then
    select count(*) filter (where o.oy = 'kabul'), count(*) filter (where o.oy = 'ret'), count(*) filter (where o.oy = 'cekimser') into a, r, c
      from oyun.kanun_oylari o where o.kanun_id = new.id and o.asama = case when old.durum = 'israr' then 'israr' else 'ilk' end;
    perform oyun.gk_yaz(b.id, 'oylama', null, format('%s — %s (Kabul: %s · Ret: %s · Çekimser: %s)', new.baslik,
      case when new.durum in ('cb_onayinda', 'yururlukte', 'halkoylamasinda') then 'Teklif kabul edilmiştir.' else 'Teklif kabul edilmemiştir.' end, a, r, c),
      jsonb_build_object('kanun', new.id, 'kabul', a, 'ret', r, 'cekimser', c, 'sonuc', case when new.durum in ('cb_onayinda', 'yururlukte', 'halkoylamasinda') then 'kabul' else 'ret' end),
      null, null, oyun.simdi());
  end if;
  return null;
exception when others then return null;
end $f$;
drop trigger if exists gk_kanun on oyun.kanunlar;
create trigger gk_kanun after update of durum on oyun.kanunlar for each row execute function oyun.gk_kanun_trg();

create or replace function oyun.gk_kanun_oy_trg() returns trigger
language plpgsql security definer set search_path to '' as $f$
begin
  if exists (select 1 from oyun.gk_birlesim b where b.durum in ('acik', 'yoklama', 'arada')) then perform oyun.gk_kirlet(); end if;
  return null;
exception when others then return null;
end $f$;
drop trigger if exists gk_kanun_oy on oyun.kanun_oylari;
create trigger gk_kanun_oy after insert or update on oyun.kanun_oylari for each row execute function oyun.gk_kanun_oy_trg();

-- Tutanağa yazılan metinler de bölücü/küfür süzgecinden ve gözaltı kısıtından geçer
drop trigger if exists bolucu_metin on oyun.gk_tutanak;
create trigger bolucu_metin before insert or update of metin on oyun.gk_tutanak for each row execute function oyun.bolucu_metin_trg('metin');
drop trigger if exists gozalti_yazi_engel on oyun.gk_tutanak;
create trigger gozalti_yazi_engel before insert on oyun.gk_tutanak for each row execute function oyun.gozalti_yazi_engel_trg('user_id');

-- Genel Kurul sohbeti: birleşim yokken, yoklamada, arada ve kapalı oturumda yazılmaz (eski uygulama dahil)
create or replace function oyun.gk_yazma_engeli(u uuid) returns text
language plpgsql stable security definer set search_path to '' as $f$
declare b oyun.gk_birlesim; nx timestamptz;
begin
  if not coalesce((select aktif from oyun.gk_ayar where id = 1), false) then return null; end if;
  b := oyun.gk_su_an();
  if b.id is null then
    select min(x.plan_bas) into nx from oyun.gk_birlesim x where x.durum = 'planli' and x.plan_bas > oyun.simdi();
    return 'Genel Kurul şu an toplantı hâlinde değil; birleşimler her akşam 21.00''de açılır' || coalesce(' (sonraki: ' || to_char(nx at time zone 'Europe/Istanbul', 'DD.MM HH24.MI') || ')', '') || '. Kulis için parti grubu sohbetini kullan.';
  end if;
  if b.durum = 'yoklama' then return 'Yoklama sürüyor; yoklama bitince konuşabilirsin.'; end if;
  if b.durum = 'arada' then return 'Birleşime ara verildi.'; end if;
  if b.kapali then return 'Kapalı oturum sürüyor; güncel uygulamadaki Genel Kurul salonunu kullan.'; end if;
  if oyun.gk_cikarilmis(u, b) then return 'Meclisten geçici çıkarma cezan sürüyor.'; end if;
  return null;
end $f$;

select oyun._yama('public.sohbet_yaz(text,text)',
  $re$(  perform oyun\.yazabilir_mi\(p, t\);\n  if p_kanal = 'meclis' and not coalesce\(p\.yonetici, false\) then)$re$,
  E'  /*GK_SALON*/ if p_kanal = ''meclis'' and not coalesce(p.yonetici, false) and to_regprocedure(''oyun.gk_yazma_engeli(uuid)'') is not null and oyun.gk_yazma_engeli(p.id) is not null then\n    raise exception ''%'', oyun.gk_yazma_engeli(p.id);\n  end if;\n\\1',
  '/*GK_SALON*/');

-- Kıdem kaynağı: Genel Kurul kürsüsünden konuşmak
do $k$
begin
  if to_regclass('oyun.kidem_kaynak') is not null then
    insert into oyun.kidem_kaynak(kod, ad, puan, gunluk_tavan, sira) values ('meclis_konusma', 'Genel Kurul kürsüsünden konuşmak', 0.5, 1, 23)
    on conflict (kod) do nothing;
  end if;
end $k$;

-- Zamanlayıcı: her dakika (ekran açıkken gk_durum da ilerletir)
do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
    values ('genel_kurul', 'select oyun.gk_ilerlet(oyun.simdi())', 1, 0, 131, true)
    on conflict (adim) do nothing;
  end if;
end $z$;

-- Yönetim portalı ayarları
do $p$
begin
  if to_regclass('oyun.yp_ayar_katalog') is null then return; end if;
  insert into oyun.yp_ayar_katalog(anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, sira, aktif) values
  ('gk.aktif','oyun.gk_ayar','aktif',null,'siyaset','Genel Kurul salonu','Kapatılırsa yeni birleşim açılmaz ve Genel Kurul sohbeti serbest kalır.','evet_hayir',null,null,null,null,'yuksek','Bir dakika içinde.',210,true),
  ('gk.yoklama_dk','oyun.gk_ayar','yoklama_dk',null,'siyaset','Yoklama süresi','Elektronik yoklamanın açık kaldığı süre.','tamsayi','dk',2,15,null,'dusuk','Sonraki yoklamada.',211,true),
  ('gk.ara_dk','oyun.gk_ayar','ara_dk',null,'siyaset','Yeter sayı bulunamayınca ara','Toplantı yeter sayısı bulunamayınca verilen ara.','tamsayi','dk',3,30,null,'dusuk','Sonraki yoklamada.',212,true),
  ('gk.yeter_taban','oyun.gk_ayar','yeter_taban',null,'siyaset','Canlı birleşim yeter sayı tabanı','dolu = dolu sandalyeler (oyun kuralı), tamsayi = 600 (Anayasa m.96 birebir).','metin',null,null,null,10,'yuksek','Hemen.',213,true),
  ('gk.gundem_disi_sayi','oyun.gk_ayar','gundem_disi_sayi',null,'siyaset','Gündem dışı konuşma sayısı','Bir birleşimde yapılabilecek gündem dışı konuşma sayısı (İçtüzük: 3).','tamsayi','adet',0,5,null,'dusuk','Sonraki birleşimde.',214,true),
  ('gk.oylama_dk','oyun.gk_ayar','oylama_dk',null,'siyaset','İşaret oylaması süresi','Grup önerisi, uzatma, kapalı oturum ve disiplin oylamalarının açık kalma süresi.','tamsayi','dk',1,10,null,'dusuk','Sonraki oylamada.',215,true),
  ('gk.laf_aralik_sn','oyun.gk_ayar','laf_aralik_sn',null,'siyaset','Sıralardan söz atma aralığı','Bir vekilin iki laf atma arasında beklemesi gereken süre.','tamsayi','sn',5,120,null,'dusuk','Hemen.',216,true)
  on conflict (anahtar) do nothing;
end $p$;

-- ---------------------------------------------------------------- YETKİLER
revoke all on function oyun.gk_soz_tur(), oyun.gk_kelime(text), oyun.gk_sira(int), oyun.gk_saat(timestamptz), oyun.gk_gun(timestamptz),
  oyun.gk_vekil(uuid), oyun.gk_hukumet(uuid), oyun.gk_yonetebilir(uuid), oyun.gk_grup_parti(uuid), oyun.gk_kimlik(uuid), oyun.gk_taban(),
  oyun.gk_toplanti_yeter(), oyun.gk_karar_yeter(), oyun.gk_donem(), oyun.gk_su_an(), oyun.gk_bitis(oyun.gk_birlesim),
  oyun.gk_cikarilmis(uuid, oyun.gk_birlesim), oyun.gk_disiplin_kesinti(uuid, timestamptz), oyun.gk_degisti(), oyun.gk_kirlet(),
  oyun.gk_yaz(bigint, text, uuid, text, jsonb, bigint, text, timestamptz), oyun.gk_baskan(bigint, text, uuid, timestamptz),
  oyun.gk_vekillere_bildir(text, timestamptz, uuid), oyun.gk_yoneten_salonda(bigint, timestamptz),
  oyun.gk_madde_ekle(bigint, text, bigint, text, boolean), oyun.gk_gundem_kur(oyun.gk_birlesim, timestamptz), oyun.gk_sunus(oyun.gk_birlesim, timestamptz),
  oyun.gk_madde_baslat(bigint, bigint, timestamptz), oyun.gk_madde_bitir(bigint, bigint, timestamptz),
  oyun.gk_yoklama_baslat(bigint, text, uuid, timestamptz), oyun.gk_ac(bigint, timestamptz, uuid), oyun.gk_ozet(bigint), oyun.gk_kapat(bigint, timestamptz, text),
  oyun.gk_soz_baslat(bigint, bigint, uuid, timestamptz), oyun.gk_soz_kapat(bigint, timestamptz, text), oyun.gk_yoklama_sonuc(bigint, timestamptz),
  oyun.gk_oylama_ac(bigint, text, bigint, text, uuid, timestamptz, boolean), oyun.gk_oylama_sonuc(bigint, timestamptz), oyun.gk_ilerlet(timestamptz),
  oyun.gk_genel_json(timestamptz), oyun.gk_ben_json(oyun.profiller, timestamptz), oyun.gk_tutanak_json(bigint, bigint, bigint, int, boolean),
  oyun.gk_gg_imza_yeter(), oyun.gk_yonetici_zorunlu(oyun.profiller), oyun.gk_mesaj_ayna_trg(), oyun.gk_kanun_trg(), oyun.gk_kanun_oy_trg(),
  oyun.gk_yazma_engeli(uuid)
  from public, anon, authenticated;

do $g$
declare f text;
begin
  foreach f in array array['gk_durum(bigint, bigint)', 'gk_salon_harita()', 'gk_birlesimler(integer)', 'gk_tutanak_oku(bigint, bigint)',
    'gk_soz_iste(text, bigint)', 'gk_soz_geri()', 'gk_kursu_cik()', 'gk_konus(text)', 'gk_konusma_bitir()', 'gk_laf(text)', 'gk_tepki(bigint, text)',
    'gk_buradayim()', 'gk_oy(bigint, text)', 'gk_karar_yeter_iste(bigint)', 'gk_andic()', 'gk_gundem_disi_iste(text)',
    'gk_grup_onerisi_ver(text, text, text, bigint)', 'gk_grup_onerisi_geri(bigint)', 'gk_kapali_oturum_iste(text)',
    'gk_gg_ver(text, text, boolean)', 'gk_gg_imza(bigint, boolean)', 'gk_gg_liste()', 'gk_gg_geri(bigint)',
    'gk_birlesim_ac()', 'gk_soz_ver(bigint)', 'gk_soz_reddet(bigint, text)', 'gk_soz_sira(bigint, integer)', 'gk_ek_sure(bigint)', 'gk_sozu_kes(bigint)',
    'gk_ara_ver(integer)', 'gk_gundem_gec(bigint)', 'gk_oylamaya_sun(text)', 'gk_yoklama_iste()', 'gk_zil(bigint)',
    'gk_disiplin(text, text, text, integer)', 'gk_acik_oturum()', 'gk_gundem_disi_sec(bigint, boolean)',
    'gk_olaganustu_cagir(timestamptz, text)', 'gk_tutanak_kaldir(bigint, text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $g$;
