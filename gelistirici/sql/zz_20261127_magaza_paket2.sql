-- 27.11.2026 · MAĞAZA PAKETİ 2 (sürüm 2026.11.27-4) — Ercan onayı: "Hepsini ekleyelim"
-- 20 yeni ürün. HEPSİ aktif=false eklenir: Ercan App Store Connect + Play Console'da aynı kimlikle ürünü açıp onaylatınca
--   update oyun.paketler set aktif = true where urun_id in (...);
-- ile vitrine çıkar. Fiyatlar App Store TR fiyat noktalarına (,99) göre; gerçek fiyatı mağaza belirler, burada yalnız bilgi.
--
-- Ürünler (urun_id · tür · fiyat):
--   secimonline.cash_1000000          para   ₺599,99  Hazine Paketi: 1.000.000 ₺
--   secimonline.politics_card_90d     kart   ₺249,99  Siyaset Kartı 90 gün (hemen 90.000 ₺ + her gün kart ödülü)
--   secimonline.politics_card_365d    kart   ₺799,99  Siyaset Kartı Yıllık (hemen 365.000 ₺ + her gün kart ödülü + "Yıllık Üye" rozeti)
--   secimonline.gift_card_30d         hizmet ₺99,99   Hediye Siyaset Kartı (başka oyuncuya 30 gün)
--   secimonline.party_card_pack       hizmet ₺399,99  Parti Kart Paketi (GB/GBY 5 üyeye 30 gün)
--   secimonline.party_donation        hizmet ₺199,99  Parti Kasasına Bağış (250.000 ₺ + 30 gün "Büyük Bağışçı", yalnız parti içinde)
--   secimonline.hq_campaign           hizmet ₺99,99   Genel Merkez Kampanyası (kasaya 100.000 ₺; 10/25/50 katkıda seviye)
--   secimonline.launch_stage          hizmet ₺199,99  Lansman Sahnesi (partiye kalıcı)
--   secimonline.congress_pack         hizmet ₺99,99   Kongre Paketi (kurultay adaylığına bayrak, afiş, alkış)
--   secimonline.kursu_showcase_24h    hizmet ₺249,99  Kürsü Vitrini 24 saat (aynı anda en çok 3; sonrası sıra)
--   secimonline.headline_24h          hizmet ₺299,99  Gündem Manşeti 24 saat (moderasyon; aynı anda en çok 3; sonrası sıra)
--   secimonline.mandate               hizmet ₺49,99   Mazbata (seçim kazanana)
--   secimonline.victory_night         hizmet ₺49,99   Seçim Gecesi Kutlaması
--   secimonline.vanity_plate          kalici ₺49,99   Özel Plaka
--   secimonline.vanity_plate_elite    kalici ₺149,99  Özel Plaka · Seçkin (tek harf ya da 1–99 numara)
--   secimonline.plate_change          jeton  ₺29,99   Plaka Değiştirme
--   secimonline.supporter_wall_bronze hizmet ₺249,99  Destekçiler Duvarı · Bronz (o ay)
--   secimonline.supporter_wall_silver hizmet ₺499,99  Destekçiler Duvarı · Gümüş
--   secimonline.supporter_wall_gold   hizmet ₺999,99  Destekçiler Duvarı · Altın
--
-- "hizmet" türü yeni: eski mağaza uygulaması bu türü listelemez (kullanım ekranı yok). Etkisi oyun.m2_uygula'da:
-- satın alma bir jeton yazar (oyun.magaza_jeton, kod m2_*); şartı tutanlar hemen kendiliğinden uygulanır
-- (bağış, genel merkez, sahne, kongre, mazbata, kutlama, destekçi), diğerleri oyuncunun seçimiyle kullanılır
-- (vitrin, manşet, hediye kart, parti kart). Bir seçim kazanılınca (oyun.kazananlar) bekleyen mazbata ve kutlama jetonu kendiliğinden kullanılır.
-- Vitrin ve manşet sunucuda kürsü akışının ve haber şeridinin başına eklenir: eski uygulamada da en üstte görünür.
-- Seçim günü oy saatlerinde (genel mv/cb/bel oylaması sürerken; ara seçimler hariç) vitrin ve manşet görünmez, süreleri işlemez.
-- Hiçbiri oy, delege, makam ya da seçim sonucu satmaz. Mevcut veriye dokunmaz; tekrar çalıştırmak güvenlidir.
-- SIRA: kursu_akis ve haberler'i değiştirdiği için yuk_hizlandirma'dan SONRA (listenin en sonunda) gelir.

-- ============ AYARLAR ============
create table if not exists oyun.m2_ayar (
  id integer primary key default 1 check (id = 1),
  vitrin_yer integer not null default 3 check (vitrin_yer between 1 and 10),
  vitrin_saat integer not null default 24 check (vitrin_saat between 1 and 168),
  manset_yer integer not null default 3 check (manset_yer between 1 and 10),
  manset_saat integer not null default 24 check (manset_saat between 1 and 168),
  manset_oto_onay_saat integer not null default 12 check (manset_oto_onay_saat between 1 and 72),
  bagis_tutar numeric not null default 250000 check (bagis_tutar >= 0),
  bagisci_gun integer not null default 30 check (bagisci_gun between 1 and 365),
  gm_tutar numeric not null default 100000 check (gm_tutar >= 0),
  gm_esik integer[] not null default array[10, 25, 50],
  gm_hesap_gun integer not null default 3 check (gm_hesap_gun between 0 and 60),
  parti_kart_adet integer not null default 5 check (parti_kart_adet between 1 and 50),
  son_tick timestamptz,
  guncelleme timestamptz not null default now()
);
insert into oyun.m2_ayar(id) values (1) on conflict (id) do nothing;
alter table oyun.m2_ayar enable row level security;
revoke all on oyun.m2_ayar from public, anon, authenticated;

alter table oyun.magaza_hesap add column if not exists yillik_bitis timestamptz;

-- ============ TABLOLAR ============
-- Kürsü vitrini ve Gündem manşeti (ortak kuyruk; tür başına ayrı yer sayısı)
create table if not exists oyun.m2_yayin (
  id bigserial primary key,
  tur text not null check (tur in ('kursu', 'manset')),
  user_id uuid not null references oyun.profiller(id),
  akis_id bigint references oyun.akis(id) on delete set null,
  baslik text,
  parti_id bigint references oyun.partiler(id),
  durum text not null check (durum in ('onay', 'sirada', 'yayinda', 'bitti', 'kaldirildi', 'reddedildi', 'iptal')),
  sira_zaman timestamptz,
  bas timestamptz,
  bit timestamptz,
  olusturma timestamptz not null,
  karar_zaman timestamptz,
  karar_veren uuid,
  gerekce text
);
create index if not exists m2_yayin_durum_idx on oyun.m2_yayin(tur, durum, sira_zaman, id);
create index if not exists m2_yayin_kisi_idx on oyun.m2_yayin(user_id, durum);

-- Özel plaka (kişi başına bir plaka; aynı plaka iki kişide olmaz)
create table if not exists oyun.m2_plaka (
  user_id uuid primary key references oyun.profiller(id),
  il smallint not null check (il between 1 and 81),
  harf text not null,
  rakam text not null,
  metin text not null,
  secildi boolean not null default false,
  zaman timestamptz not null
);
create unique index if not exists m2_plaka_tekil on oyun.m2_plaka(il, harf, (rakam::integer));

-- Mazbata (seçim başına bir)
create table if not exists oyun.m2_mazbata (
  id bigserial primary key,
  user_id uuid not null references oyun.profiller(id),
  secim_id bigint not null references oyun.secimler(id),
  tur text not null,
  ad text not null,
  gorev text not null,
  il_id smallint,
  parti_id bigint,
  oy_orani numeric,
  tarih timestamptz not null,
  zaman timestamptz not null,
  unique (user_id, secim_id)
);

-- Seçim gecesi kutlaması (zafer rozeti + sahne)
create table if not exists oyun.m2_zafer (
  id bigserial primary key,
  user_id uuid not null references oyun.profiller(id),
  secim_id bigint not null references oyun.secimler(id),
  gorev text not null,
  rozet text not null,
  oy_orani numeric,
  goruldu boolean not null default false,
  zaman timestamptz not null,
  unique (user_id, secim_id)
);

-- Kongre Paketi (kurultay adaylığı başına)
create table if not exists oyun.m2_kongre (
  secim_id bigint not null references oyun.secimler(id),
  user_id uuid not null references oyun.profiller(id),
  slogan text not null,
  zaman timestamptz not null,
  primary key (secim_id, user_id)
);

-- Lansman Sahnesi (partiye kalıcı)
create table if not exists oyun.m2_parti_sahne (
  parti_id bigint primary key references oyun.partiler(id),
  alan uuid not null references oyun.profiller(id),
  zaman timestamptz not null
);

-- Genel Merkez Kampanyası katkıları
create table if not exists oyun.m2_gm_katki (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  user_id uuid not null references oyun.profiller(id),
  tutar numeric not null,
  zaman timestamptz not null
);
create index if not exists m2_gm_katki_parti_idx on oyun.m2_gm_katki(parti_id, id);
create table if not exists oyun.m2_gm_seviye (
  parti_id bigint primary key references oyun.partiler(id),
  seviye integer not null default 0,
  zaman timestamptz not null
);

-- Büyük Bağışçı unvanı (parti içinde)
create table if not exists oyun.m2_bagisci (
  user_id uuid not null references oyun.profiller(id),
  parti_id bigint not null references oyun.partiler(id),
  toplam numeric not null default 0,
  bitis timestamptz not null,
  primary key (user_id, parti_id)
);

-- Destekçiler Duvarı (ay başına)
create table if not exists oyun.m2_destek (
  id bigserial primary key,
  user_id uuid not null references oyun.profiller(id),
  ay text not null,
  kademe integer not null check (kademe between 1 and 3),
  zaman timestamptz not null
);
create index if not exists m2_destek_ay_idx on oyun.m2_destek(ay, kademe desc);

-- Hediye ve parti kartı kayıtları
create table if not exists oyun.m2_hediye (
  id bigserial primary key,
  tur text not null check (tur in ('hediye', 'parti')),
  veren uuid not null references oyun.profiller(id),
  alan uuid not null references oyun.profiller(id),
  parti_id bigint,
  notu text,
  zaman timestamptz not null
);
create index if not exists m2_hediye_alan_idx on oyun.m2_hediye(alan, zaman desc);

do $r$
declare t text;
begin
  foreach t in array array['m2_yayin', 'm2_plaka', 'm2_mazbata', 'm2_zafer', 'm2_kongre', 'm2_parti_sahne', 'm2_gm_katki',
                           'm2_gm_seviye', 'm2_bagisci', 'm2_destek', 'm2_hediye'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $r$;

-- Yasaklı ifade süzgeci (oyuncu metinleri)
do $tg$
begin
  if to_regprocedure('oyun.bolucu_metin_trg()') is not null then
    execute 'create or replace trigger bolucu_metin before insert or update on oyun.m2_yayin for each row execute function oyun.bolucu_metin_trg(''baslik'')';
    execute 'create or replace trigger bolucu_metin before insert or update on oyun.m2_kongre for each row execute function oyun.bolucu_metin_trg(''slogan'')';
    execute 'create or replace trigger bolucu_metin before insert or update on oyun.m2_hediye for each row execute function oyun.bolucu_metin_trg(''notu'')';
  end if;
end $tg$;

-- ============ ÜRÜNLER (aktif=false) ============
insert into oyun.paketler(urun_id, ad, miktar, sira, tur, gun, hak, aciklama, etiket, fiyat, aktif) values
  ('secimonline.cash_1000000', 'Hazine Paketi', 1000000, 14, 'para', 0, null,
   'Cüzdanına 1.000.000 ₺. Lira başına en avantajlı paket.', '%100 fazla', '₺599,99', false),
  ('secimonline.politics_card_90d', 'Siyaset Kartı · 90 gün', 90000, 4, 'kart', 90, null,
   'Hemen 90.000 ₺ ve 90 gün boyunca her gün Kart ödülü. Aylık almaktan ucuzdur. Otomatik yenilenmez.', '3 ay', '₺249,99', false),
  ('secimonline.politics_card_365d', 'Siyaset Kartı · Yıllık', 365000, 5, 'kart', 365, null,
   'Hemen 365.000 ₺ ve 365 gün boyunca her gün Kart ödülü; aylığa göre yaklaşık 4 ay bedava. Yıllık Üye rozeti. Otomatik yenilenmez.', 'Yıllık Üye', '₺799,99', false),
  ('secimonline.gift_card_30d', 'Hediye Siyaset Kartı', 0, 50, 'hizmet', 0, null,
   'Seçtiğin oyuncuya 30 günlük Siyaset Kartı hediye edersin. Alana bildirim gider, Türkiye sohbetine duyurulur.', 'Hediye', '₺99,99', false),
  ('secimonline.party_card_pack', 'Parti Kart Paketi', 0, 51, 'hizmet', 0, null,
   'Genel başkan ya da genel başkan yardımcısı, partisinin 5 üyesine 30 günlük Siyaset Kartı dağıtır.', '5 kart', '₺399,99', false),
  ('secimonline.party_donation', 'Parti Kasasına Bağış', 0, 52, 'hizmet', 0, null,
   'Üyesi olduğun partinin kasasına 250.000 ₺. Partide duyurulur, 30 gün parti içinde "Büyük Bağışçı" unvanı. Oy, delege ya da makam vermez.', 'Parti', '₺199,99', false),
  ('secimonline.hq_campaign', 'Genel Merkez Kampanyası', 0, 53, 'hizmet', 0, null,
   'Partinin ortak hedefine katkı: kasaya 100.000 ₺. 10, 25 ve 50 katkıda parti İl Binası, Genel Merkez ve Büyük Genel Merkez olur; bütün üyeler rozet alır.', 'Parti', '₺99,99', false),
  ('secimonline.launch_stage', 'Lansman Sahnesi', 0, 54, 'hizmet', 0, null,
   'Partinin aday lansmanlarında ışıklı sahne, alkışta konfeti ve parti posteri. Partiye kalıcı olarak bağlanır.', 'Partiye kalıcı', '₺199,99', false),
  ('secimonline.congress_pack', 'Kongre Paketi', 0, 55, 'hizmet', 0, null,
   'Kurultay adaylığında oy pusulasında ve aday listesinde bayrak, kendi sloganınla aday afişi ve alkış efekti. O kurultay için geçerlidir.', 'Kurultay', '₺99,99', false),
  ('secimonline.kursu_showcase_24h', 'Kürsü Vitrini · 24 saat', 0, 60, 'hizmet', 0, null,
   'Seçtiğin Kürsü paylaşımın 24 saat akışın en üstünde "Öne çıkan" etiketiyle durur. Aynı anda en çok 3 vitrin olur; doluysa sıraya girersin ve yayına gireceğin saat önceden bildirilir.', 'En çok 3', '₺249,99', false),
  ('secimonline.headline_24h', 'Gündem Manşeti · 24 saat', 0, 61, 'hizmet', 0, null,
   'Yazdığın manşet moderasyondan geçtikten sonra 24 saat haber şeridinin başında durur. Aynı anda en çok 3 manşet olur; doluysa sıraya girersin ve yayın saati önceden bildirilir. Reddedilirse hakkın geri verilir.', 'En çok 3', '₺299,99', false),
  ('secimonline.mandate', 'Mazbata', 0, 62, 'hizmet', 0, null,
   'Kazandığın seçim için adın, görevin, tarihin ve oy oranın yazılı mazbata. Profilinde çerçeveli durur, X ve Instagram''da paylaşabilirsin.', 'Seçim', '₺49,99', false),
  ('secimonline.victory_night', 'Seçim Gecesi Kutlaması', 0, 63, 'hizmet', 0, null,
   'Seçimi kazanınca konfetili zafer sahnesi, Türkiye sohbetine tebrik kartı ve profilinde kalıcı zafer rozeti. Önceden alırsan kazandığın gece kendiliğinden kullanılır.', 'Seçim', '₺49,99', false),
  ('secimonline.vanity_plate', 'Özel Plaka', 0, 27, 'kalici', 0, 'plaka',
   'Profilinde, oyuncu kartında ve sohbette kişisel plakan. Her plaka yalnız bir kişide olur; makamdayken plaka altın makam görünümüne geçer. İlk plakanı seçmek ücretsizdir.', 'Kalıcı', '₺49,99', false),
  ('secimonline.vanity_plate_elite', 'Özel Plaka · Seçkin', 0, 28, 'kalici', 0, 'plaka_seckin',
   'Tek harfli ya da 01–99 numaralı kıt plakalar (örneğin 06 K 07). Özel Plaka''nın bütün özellikleri dahildir.', 'Kıt', '₺149,99', false),
  ('secimonline.plate_change', 'Plaka Değiştirme', 0, 32, 'jeton', 0, 'plaka_degis',
   'Plakanı bir kez değiştirme hakkı.', null, '₺29,99', false),
  ('secimonline.supporter_wall_bronze', 'Destekçiler Duvarı · Bronz', 0, 70, 'hizmet', 0, null,
   'Bu ayın destekçileri arasında bronz kademede anılırsın: Gündem''deki duvarda, Mağaza''da ve ay boyunca sohbette adının yanında. Oyun avantajı vermez.', 'Bu ay', '₺249,99', false),
  ('secimonline.supporter_wall_silver', 'Destekçiler Duvarı · Gümüş', 0, 71, 'hizmet', 0, null,
   'Bu ayın destekçileri arasında gümüş kademede anılırsın. Oyun avantajı vermez.', 'Bu ay', '₺499,99', false),
  ('secimonline.supporter_wall_gold', 'Destekçiler Duvarı · Altın', 0, 72, 'hizmet', 0, null,
   'Bu ayın destekçileri arasında altın kademede, duvarın en üstünde anılırsın. Oyun avantajı vermez.', 'Bu ay', '₺999,99', false)
on conflict (urun_id) do update set ad = excluded.ad, miktar = excluded.miktar, sira = excluded.sira, tur = excluded.tur, gun = excluded.gun,
  hak = excluded.hak, aciklama = excluded.aciklama, etiket = excluded.etiket, fiyat = excluded.fiyat;
-- not: aktif sütunu güncellenmez; Ercan açtıysa açık kalır.

-- ============ YARDIMCILAR ============
create or replace function oyun.m2_ad(u uuid) returns text language sql stable set search_path to '' as $$
  select coalesce(nullif(btrim(p.ad_soyad), ''), p.kad) from oyun.profiller p where p.id = u
$$;

create or replace function oyun.m2_ay_yil(t timestamptz) returns text language sql immutable set search_path to '' as $$
  select (array['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'])
           [extract(month from t at time zone 'Europe/Istanbul')::integer] || ' ' || extract(year from t at time zone 'Europe/Istanbul')::integer
$$;

create or replace function oyun.m2_ay(t timestamptz) returns text language sql immutable set search_path to '' as $$
  select to_char(t at time zone 'Europe/Istanbul', 'YYYY-MM')
$$;

create or replace function oyun.m2_jeton(u uuid, k text) returns integer language sql stable set search_path to '' as $$
  select coalesce((select adet from oyun.magaza_jeton where user_id = u and kod = k), 0)
$$;

create or replace function oyun.m2_jeton_ekle(u uuid, k text, n integer) returns void language plpgsql set search_path to '' as $$
begin
  insert into oyun.magaza_jeton(user_id, kod, adet) values (u, k, greatest(n, 0))
  on conflict (user_id, kod) do update set adet = greatest(oyun.magaza_jeton.adet + n, 0);
end $$;

-- Jeton harca: yoksa false
create or replace function oyun.m2_jeton_harca(u uuid, k text) returns boolean language plpgsql set search_path to '' as $$
begin
  update oyun.magaza_jeton set adet = adet - 1 where user_id = u and kod = k and adet > 0;
  return found;
end $$;

-- Oyuncu adına sohbete kart mesajı (susturma/gözaltı/kurul tedbiri varsa sessizce atlanır; satın almayı bozmaz)
create or replace function oyun.m2_sohbet(u uuid, k text, m text, t timestamptz) returns boolean language plpgsql set search_path to '' as $$
begin
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values (k, u, left(m, 480), t);
  return true;
exception when others then
  return false;
end $$;

-- Genel seçim oylaması sürerken vitrin ve manşet durur (ara seçimler hariç)
create or replace function oyun.m2_duraklat(t timestamptz) returns boolean language sql stable set search_path to '' as $$
  select exists (select 1 from oyun.secimler s
                  where s.tur in ('mv', 'cb', 'cb2', 'bel') and not coalesce(s.ara, false)
                    and s.durum not in ('iptal', 'tamam') and s.oy_bas <= t and s.oy_bit > t)
$$;

-- Makamda mı (plakanın makam görünümü): seçilmiş/atanmış makam ya da parti genel başkanlığı
create or replace function oyun.m2_makamda(u uuid) returns boolean language sql stable set search_path to '' as $$
  select exists (select 1 from oyun.makamlar m where m.user_id = u and (m.bit is null or m.bit > oyun.simdi()))
      or exists (select 1 from oyun.partiler pa where pa.gb = u and not pa.kapali)
$$;

-- Partide GB ya da GBY mi (parti kartı dağıtımı); partinin id'si
create or replace function oyun.m2_parti_yonetici(u uuid) returns bigint language sql stable set search_path to '' as $$
  select coalesce(
    (select pa.id from oyun.profiller p join oyun.partiler pa on pa.id = p.parti_id where p.id = u and pa.gb = u and not pa.kapali),
    (select pa.id from oyun.profiller p join oyun.parti_gby g on g.parti_id = p.parti_id and g.user_id = u
       join oyun.partiler pa on pa.id = p.parti_id where p.id = u and not pa.kapali limit 1))
$$;

-- Manşeti parti adına verebilir mi: GB, Tanıtım/Seçim GBY'si ya da parti sözcüsü
create or replace function oyun.m2_parti_adina(u uuid) returns bigint language sql stable set search_path to '' as $$
  select coalesce(oyun.parti_gorevli(u, array['tanitim', 'secim']),
    (select pa.id from oyun.profiller p join oyun.parti_sozcu s on s.parti_id = p.parti_id and s.user_id = u
       join oyun.partiler pa on pa.id = p.parti_id where p.id = u and not pa.kapali limit 1))
$$;

-- Bir oyuncunun bir seçimdeki oy oranı (yüzde): mv = partisinin ildeki oyu; bel = ildeki aday oyu; cb/kurultay = aday oyu
create or replace function oyun.m2_oy_orani(p_secim bigint, u uuid, p_il smallint, p_parti bigint) returns numeric
language plpgsql stable set search_path to '' as $$
declare s oyun.secimler; top bigint; bu bigint; aday bigint;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null then return null; end if;
  if s.tur = 'mv' then
    select count(*) into top from oyun.oylar where secim_id = p_secim and il_id = p_il;
    select count(*) into bu from oyun.oylar where secim_id = p_secim and il_id = p_il and parti_id = p_parti;
  else
    select a.id into aday from oyun.adaylar a where a.secim_id = p_secim and a.user_id = u order by a.id limit 1;
    if aday is null then return null; end if;
    if s.tur = 'bel' then
      select count(*) into top from oyun.oylar where secim_id = p_secim and il_id = p_il;
    else
      select count(*) into top from oyun.oylar where secim_id = p_secim;
    end if;
    select count(*) into bu from oyun.oylar where secim_id = p_secim and aday_id = aday;
  end if;
  if coalesce(top, 0) = 0 then return null; end if;
  return round(bu * 100.0 / top, 1);
end $$;

-- Kazanılmış seçimin görev metni ("İzmir milletvekili")
create or replace function oyun.m2_gorev(p_secim bigint, p_il smallint, p_parti bigint) returns text
language sql stable set search_path to '' as $$
  select case s.tur
    when 'mv' then coalesce((select i.ad from oyun.iller i where i.id = p_il), 'Türkiye') || ' milletvekili'
    when 'bel' then coalesce((select i.ad from oyun.iller i where i.id = p_il), '') || ' belediye başkanı'
    when 'cb' then 'Cumhurbaşkanı'
    when 'cb2' then 'Cumhurbaşkanı'
    when 'kurultay' then coalesce((select pa.ad from oyun.partiler pa where pa.id = coalesce(p_parti, s.hedef_parti_id)), 'Parti') || ' genel başkanı'
    else 'Seçilmiş' end
  from oyun.secimler s where s.id = p_secim
$$;

-- Oyuncunun son N gündeki seçim zaferleri (ön seçimler hariç), yeniden eskiye
create or replace function oyun.m2_zaferler(u uuid, p_gun integer) returns table(secim_id bigint, tur text, il_id smallint, parti_id bigint, tarih timestamptz)
language sql stable set search_path to '' as $$
  select k.secim_id, s.tur, k.il_id, k.parti_id, coalesce(s.sonuc_at, s.oy_bit) tarih
    from oyun.kazananlar k join oyun.secimler s on s.id = k.secim_id
   where k.user_id = u and s.tur in ('mv', 'bel', 'cb', 'cb2', 'kurultay')
     and coalesce(s.sonuc_at, s.oy_bit) > oyun.simdi() - make_interval(days => p_gun)
     and coalesce(s.sonuc_at, s.oy_bit) <= oyun.simdi()
   order by coalesce(s.sonuc_at, s.oy_bit) desc, k.secim_id desc
$$;

-- ============ KENDİLİĞİNDEN UYGULAMALAR (jeton varsa ve şart tutuyorsa) ============
-- Parti Kasasına Bağış
create or replace function oyun.m2_bagis_uygula(u uuid, t timestamptz) returns boolean
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare a oyun.m2_ayar; pa oyun.partiler; ad text; yeni numeric;
begin
  if oyun.m2_jeton(u, 'm2_bagis') <= 0 then return false; end if;
  select pa2.* into pa from oyun.profiller p join oyun.partiler pa2 on pa2.id = p.parti_id where p.id = u and not pa2.kapali;
  if pa.id is null then return false; end if;
  select * into a from oyun.m2_ayar where id = 1;
  if not oyun.m2_jeton_harca(u, 'm2_bagis') then return false; end if;
  ad := oyun.m2_ad(u);
  update oyun.partiler set kasa = kasa + a.bagis_tutar where id = pa.id returning kasa into yeni;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, a.bagis_tutar, format('Büyük Bağış · %s', ad), 'bagis');
  insert into oyun.m2_bagisci(user_id, parti_id, toplam, bitis) values (u, pa.id, a.bagis_tutar, t + make_interval(days => a.bagisci_gun))
  on conflict (user_id, parti_id) do update set toplam = oyun.m2_bagisci.toplam + excluded.toplam,
    bitis = greatest(oyun.m2_bagisci.bitis, t) + make_interval(days => a.bagisci_gun);
  perform oyun.m2_sohbet(u, 'parti:' || pa.id, format('[Büyük Bağış] %s parti kasamıza %s ₺ bağışladı. Kasa: %s ₺', ad, oyun.tl(a.bagis_tutar), oyun.tl(yeni)), t);
  if pa.gb is not null and pa.gb <> u then
    perform oyun.bildir(pa.gb, format('%s partiye %s ₺ bağış yaptı (Parti Kasasına Bağış).', ad, oyun.tl(a.bagis_tutar)), t);
  end if;
  perform oyun.bildir(u, format('Bağışın %s kasasına geçti: %s ₺. %s gün boyunca parti içinde Büyük Bağışçı unvanını taşıyorsun.', pa.ad, oyun.tl(a.bagis_tutar), a.bagisci_gun), t);
  return true;
end $$;

-- Genel Merkez Kampanyası
create or replace function oyun.m2_gm_seviye_hesap(n bigint, esik integer[]) returns integer language sql immutable set search_path to '' as $$
  select coalesce((select max(i) from generate_subscripts(esik, 1) i where n >= esik[i]), 0)
$$;
create or replace function oyun.m2_gm_ad(s integer) returns text language sql immutable set search_path to '' as $$
  select case s when 1 then 'İl Binası' when 2 then 'Genel Merkez' when 3 then 'Büyük Genel Merkez' else 'Arsa' end
$$;

create or replace function oyun.m2_gm_uygula(u uuid, t timestamptz) returns boolean
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare a oyun.m2_ayar; pa oyun.partiler; pr oyun.profiller; ad text; n bigint; eski integer; yeni integer; r record; say integer := 0;
begin
  if oyun.m2_jeton(u, 'm2_gm') <= 0 then return false; end if;
  select * into a from oyun.m2_ayar where id = 1;
  select * into pr from oyun.profiller where id = u;
  if pr.olusturma > t - make_interval(days => a.gm_hesap_gun) then return false; end if;
  select * into pa from oyun.partiler where id = pr.parti_id and not kapali;
  if pa.id is null then return false; end if;
  perform pg_advisory_xact_lock(hashtext('m2_gm'), pa.id::integer);
  if not oyun.m2_jeton_harca(u, 'm2_gm') then return false; end if;
  ad := oyun.m2_ad(u);
  update oyun.partiler set kasa = kasa + a.gm_tutar where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, a.gm_tutar, format('Genel Merkez Kampanyası katkısı · %s', ad), 'genel_merkez');
  insert into oyun.m2_gm_katki(parti_id, user_id, tutar, zaman) values (pa.id, u, a.gm_tutar, t);
  select count(*) into n from oyun.m2_gm_katki where parti_id = pa.id;
  select coalesce((select seviye from oyun.m2_gm_seviye where parti_id = pa.id), 0) into eski;
  yeni := oyun.m2_gm_seviye_hesap(n, a.gm_esik);
  if yeni > eski then
    insert into oyun.m2_gm_seviye(parti_id, seviye, zaman) values (pa.id, yeni, t)
    on conflict (parti_id) do update set seviye = excluded.seviye, zaman = excluded.zaman;
    perform oyun.m2_sohbet(u, 'parti:' || pa.id, format('[Genel Merkez] %s %s açıldı. %s. katkıyı %s verdi; bütün üyelerimize rozet tanımlandı.',
      pa.kisa, oyun.m2_gm_ad(yeni), n, ad), t);
    insert into oyun.olaylar(zaman, tur, il_id, parti_id, metin) values (t, 'parti', null, pa.id, format('%s %s''ne taşındı', pa.ad, oyun.m2_gm_ad(yeni)));
    for r in select p.id from oyun.profiller p where p.parti_id = pa.id and not p.yasakli order by p.son_gorulme desc nulls last limit 3000 loop
      perform oyun.bildir(r.id, format('Partin %s %s seviyesine ulaştı. Rozetin adının yanında.', pa.kisa, oyun.m2_gm_ad(yeni)), t);
      say := say + 1;
    end loop;
  else
    perform oyun.m2_sohbet(u, 'parti:' || pa.id, format('[Genel Merkez] %s kampanyaya katkı verdi (%s katkı).', ad, n), t);
  end if;
  return true;
end $$;

-- Lansman Sahnesi
create or replace function oyun.m2_sahne_uygula(u uuid, t timestamptz) returns boolean
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pa oyun.partiler;
begin
  if oyun.m2_jeton(u, 'm2_sahne') <= 0 then return false; end if;
  select pa2.* into pa from oyun.profiller p join oyun.partiler pa2 on pa2.id = p.parti_id where p.id = u and not pa2.kapali;
  if pa.id is null or exists (select 1 from oyun.m2_parti_sahne where parti_id = pa.id) then return false; end if;
  if not oyun.m2_jeton_harca(u, 'm2_sahne') then return false; end if;
  insert into oyun.m2_parti_sahne(parti_id, alan, zaman) values (pa.id, u, t) on conflict (parti_id) do nothing;
  perform oyun.m2_sohbet(u, 'parti:' || pa.id, format('[Lansman Sahnesi] %s partimize Lansman Sahnesi kazandırdı. Aday lansmanlarımız artık ışıklı sahnede.', oyun.m2_ad(u)), t);
  return true;
end $$;

-- Kongre Paketi: açık kurultay adaylığına uygulanır
create or replace function oyun.m2_kurultay_adaylik(u uuid) returns bigint language sql stable set search_path to '' as $$
  select a.secim_id from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
   where a.user_id = u and s.tur = 'kurultay' and s.durum not in ('tamam', 'iptal') and coalesce(s.oy_bit, 'infinity') > oyun.simdi()
   order by s.oy_bas desc nulls last limit 1
$$;

create or replace function oyun.m2_kongre_uygula(u uuid, t timestamptz) returns boolean
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare sid bigint; pa oyun.partiler;
begin
  if oyun.m2_jeton(u, 'm2_kongre') <= 0 then return false; end if;
  sid := oyun.m2_kurultay_adaylik(u);
  if sid is null or exists (select 1 from oyun.m2_kongre where secim_id = sid and user_id = u) then return false; end if;
  if not oyun.m2_jeton_harca(u, 'm2_kongre') then return false; end if;
  select pa2.* into pa from oyun.secimler s join oyun.partiler pa2 on pa2.id = s.hedef_parti_id where s.id = sid;
  insert into oyun.m2_kongre(secim_id, user_id, slogan, zaman) values (sid, u, 'Yeniden büyük ' || coalesce(pa.kisa, 'parti'), t)
  on conflict do nothing;
  perform oyun.bildir(u, 'Kongre Paketin kurultay adaylığına uygulandı. Afişindeki sloganı Mağaza › Kongre Paketi''nden değiştirebilirsin.', t);
  return true;
end $$;

-- Mazbata: verilen seçim ya da son 30 gündeki mazbatasız son zafer
create or replace function oyun.m2_mazbata_uygula(u uuid, t timestamptz, p_secim bigint default null) returns bigint
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare z record; yeni bigint;
begin
  if oyun.m2_jeton(u, 'm2_mazbata') <= 0 then return null; end if;
  select * into z from oyun.m2_zaferler(u, 30) x
   where (p_secim is null or x.secim_id = p_secim)
     and not exists (select 1 from oyun.m2_mazbata m where m.user_id = u and m.secim_id = x.secim_id)
   limit 1;
  if z.secim_id is null then return null; end if;
  if not oyun.m2_jeton_harca(u, 'm2_mazbata') then return null; end if;
  insert into oyun.m2_mazbata(user_id, secim_id, tur, ad, gorev, il_id, parti_id, oy_orani, tarih, zaman)
  values (u, z.secim_id, z.tur, oyun.m2_ad(u), oyun.m2_gorev(z.secim_id, z.il_id, z.parti_id), z.il_id, z.parti_id,
          oyun.m2_oy_orani(z.secim_id, u, z.il_id, z.parti_id), z.tarih, t)
  on conflict (user_id, secim_id) do nothing returning id into yeni;
  if yeni is null then perform oyun.m2_jeton_ekle(u, 'm2_mazbata', 1); return null; end if;
  perform oyun.bildir(u, format('Mazbatan hazır: %s. Profilinde çerçeveli duruyor; oradan paylaşabilirsin.', oyun.m2_gorev(z.secim_id, z.il_id, z.parti_id)), t);
  return yeni;
end $$;

-- Seçim Gecesi Kutlaması: verilen seçim ya da son 7 gündeki kutlamasız son zafer
create or replace function oyun.m2_kutlama_uygula(u uuid, t timestamptz, p_secim bigint default null) returns bigint
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare z record; yeni bigint; gorev text; oran numeric;
begin
  if oyun.m2_jeton(u, 'm2_kutlama') <= 0 then return null; end if;
  select * into z from oyun.m2_zaferler(u, 7) x
   where (p_secim is null or x.secim_id = p_secim)
     and not exists (select 1 from oyun.m2_zafer m where m.user_id = u and m.secim_id = x.secim_id)
   limit 1;
  if z.secim_id is null then return null; end if;
  if not oyun.m2_jeton_harca(u, 'm2_kutlama') then return null; end if;
  gorev := oyun.m2_gorev(z.secim_id, z.il_id, z.parti_id);
  oran := oyun.m2_oy_orani(z.secim_id, u, z.il_id, z.parti_id);
  insert into oyun.m2_zafer(user_id, secim_id, gorev, rozet, oy_orani, zaman)
  values (u, z.secim_id, gorev, oyun.m2_ay_yil(z.tarih) || ' zaferi', oran, t)
  on conflict (user_id, secim_id) do nothing returning id into yeni;
  if yeni is null then perform oyun.m2_jeton_ekle(u, 'm2_kutlama', 1); return null; end if;
  perform oyun.m2_sohbet(u, 'genel', format('[Zafer] %s %s seçildi.%s', oyun.m2_ad(u), gorev,
    case when oran is not null then format(' Oy oranı: %%%s', replace(oran::text, '.', ',')) else '' end), t);
  return yeni;
end $$;

-- Satın alma anında ve sonradan (yeni partiye katılınca vb.) bekleyen jetonları dener
create or replace function oyun.m2_bekleyenleri_uygula(u uuid, t timestamptz) returns void
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
begin
  perform oyun.m2_bagis_uygula(u, t);
  perform oyun.m2_gm_uygula(u, t);
  perform oyun.m2_sahne_uygula(u, t);
  perform oyun.m2_kongre_uygula(u, t);
  perform oyun.m2_mazbata_uygula(u, t, null);
  perform oyun.m2_kutlama_uygula(u, t, null);
end $$;

-- Özel plaka: ilk plaka kendiliğinden (sonra bir kez ücretsiz değiştirilir)
create or replace function oyun.m2_ascii(s text) returns text language sql immutable set search_path to '' as $$
  select upper(translate(coalesce(s, ''), 'çğıöşüÇĞİÖŞÜâîûÂÎÛ', 'cgiosuCGIOSUaiuAIU'))
$$;
create or replace function oyun.m2_plaka_ver(u uuid, t timestamptz) returns void
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pr oyun.profiller; il smallint; h text; parca text[]; r integer; i integer;
begin
  if exists (select 1 from oyun.m2_plaka where user_id = u) then return; end if;
  select * into pr from oyun.profiller where id = u;
  il := coalesce(pr.il_id, 6);
  parca := regexp_split_to_array(btrim(oyun.m2_ascii(coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad))), '[^A-Z]+');
  h := left(coalesce(parca[1], ''), 1) || left(coalesce(parca[array_length(parca, 1)], ''), 1);
  if h !~ '^[ABCDEFGHIJKLMNOPRSTUVYZ]{2}$' or length(h) <> 2 then h := 'SO'; end if;
  if h in ('CC', 'CD', 'CV', 'CR', 'CA', 'AA') then h := 'SO'; end if;
  for i in 1..40 loop
    r := 1000 + floor(random() * 9000)::integer;
    begin
      insert into oyun.m2_plaka(user_id, il, harf, rakam, metin, secildi, zaman)
      values (u, il, h, r::text, lpad(il::text, 2, '0') || ' ' || h || ' ' || r::text, false, t);
      return;
    exception when unique_violation then
      if exists (select 1 from oyun.m2_plaka where user_id = u) then return; end if;
    end;
  end loop;
end $$;

-- ============ SATIN ALMA ETKİSİ ============
-- magaza_uygula'nın sonunda çağrılır (isaret 1 = ver, -1 = iade). Dönüş: iadede düşülen para (yok: 0).
create or replace function oyun.m2_uygula(u uuid, pk oyun.paketler, isaret integer, t timestamptz) returns numeric
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare a oyun.m2_ayar; k text; adet integer := 1; v_kademe integer; pid bigint; dus numeric := 0; r record;
begin
  select * into a from oyun.m2_ayar where id = 1;
  k := case pk.urun_id
    when 'secimonline.gift_card_30d' then 'm2_hediye_kart'
    when 'secimonline.party_card_pack' then 'm2_parti_kart'
    when 'secimonline.party_donation' then 'm2_bagis'
    when 'secimonline.hq_campaign' then 'm2_gm'
    when 'secimonline.launch_stage' then 'm2_sahne'
    when 'secimonline.congress_pack' then 'm2_kongre'
    when 'secimonline.kursu_showcase_24h' then 'm2_vitrin'
    when 'secimonline.headline_24h' then 'm2_manset'
    when 'secimonline.mandate' then 'm2_mazbata'
    when 'secimonline.victory_night' then 'm2_kutlama'
    else null end;
  v_kademe := case pk.urun_id when 'secimonline.supporter_wall_bronze' then 1 when 'secimonline.supporter_wall_silver' then 2
                            when 'secimonline.supporter_wall_gold' then 3 else null end;
  if pk.urun_id = 'secimonline.party_card_pack' then adet := a.parti_kart_adet; end if;

  if isaret > 0 then
    if k is not null then
      perform oyun.m2_jeton_ekle(u, k, adet);
      perform oyun.m2_bekleyenleri_uygula(u, t);
    elsif v_kademe is not null then
      insert into oyun.m2_destek(user_id, ay, kademe, zaman) values (u, oyun.m2_ay(t), v_kademe, t);
      perform oyun.bildir(u, format('Teşekkürler! Bu ayın destekçileri arasında %s kademede anılıyorsun.',
        case v_kademe when 3 then 'altın' when 2 then 'gümüş' else 'bronz' end), t);
    elsif pk.urun_id = 'secimonline.politics_card_365d' then
      insert into oyun.magaza_hesap(user_id, yillik_bitis) values (u, t + interval '365 days')
      on conflict (user_id) do update set yillik_bitis = greatest(coalesce(oyun.magaza_hesap.yillik_bitis, t), t) + interval '365 days';
    elsif pk.hak in ('plaka', 'plaka_seckin') then
      perform oyun.m2_plaka_ver(u, t);
    end if;
    return 0;
  end if;

  -- İade
  if k is not null then
    if oyun.m2_jeton(u, k) >= adet then
      perform oyun.m2_jeton_ekle(u, k, -adet);
    elsif k = 'm2_bagis' then
      select b.parti_id into pid from oyun.m2_bagisci b where b.user_id = u order by b.bitis desc limit 1;
      if pid is not null then
        select least(a.bagis_tutar, greatest(kasa, 0)) into dus from oyun.partiler where id = pid;
        update oyun.partiler set kasa = kasa - dus where id = pid;
        insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pid, t, -dus, 'Mağaza iadesi: Büyük Bağış geri alındı', 'bagis');
        update oyun.m2_bagisci set bitis = greatest(bitis - make_interval(days => a.bagisci_gun), t), toplam = greatest(toplam - a.bagis_tutar, 0)
         where user_id = u and parti_id = pid;
        dus := 0;  -- oyuncunun cüzdanından düşülmedi
      end if;
    elsif k = 'm2_gm' then
      select * into r from oyun.m2_gm_katki where user_id = u order by id desc limit 1;
      if r.id is not null then
        delete from oyun.m2_gm_katki where id = r.id;
        update oyun.partiler set kasa = kasa - least(r.tutar, greatest(kasa, 0)) where id = r.parti_id;
        insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (r.parti_id, t, -r.tutar, 'Mağaza iadesi: Genel Merkez katkısı geri alındı', 'genel_merkez');
      end if;
    else
      perform oyun.m2_jeton_ekle(u, k, -oyun.m2_jeton(u, k));  -- kullanılmış hizmet geri alınamaz; kalan jetonlar sıfırlanır
    end if;
  elsif v_kademe is not null then
    delete from oyun.m2_destek where id = (select d.id from oyun.m2_destek d where d.user_id = u and d.kademe = v_kademe order by d.id desc limit 1);
  elsif pk.urun_id = 'secimonline.politics_card_365d' then
    update oyun.magaza_hesap set yillik_bitis = yillik_bitis - interval '365 days' where user_id = u and yillik_bitis is not null;
  elsif pk.hak in ('plaka', 'plaka_seckin') then
    if not oyun.hak_var(u, 'plaka') and not oyun.hak_var(u, 'plaka_seckin') then
      delete from oyun.m2_plaka where user_id = u;
    end if;
  end if;
  return 0;
end $$;

-- Seçim kazanılınca bekleyen mazbata ve kutlama jetonu kendiliğinden kullanılır (seçim işlemini asla bozmaz)
create or replace function oyun.m2_kazanan_trg() returns trigger
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
begin
  begin
    if new.user_id is not null and exists (select 1 from oyun.secimler s where s.id = new.secim_id and s.tur in ('mv', 'bel', 'cb', 'cb2', 'kurultay')) then
      perform oyun.m2_mazbata_uygula(new.user_id, oyun.simdi(), new.secim_id);
      perform oyun.m2_kutlama_uygula(new.user_id, oyun.simdi(), new.secim_id);
    end if;
  exception when others then
    raise warning 'm2_kazanan_trg: %', sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists m2_kazanan on oyun.kazananlar;
create trigger m2_kazanan after insert on oyun.kazananlar for each row execute function oyun.m2_kazanan_trg();

-- ============ VİTRİN VE MANŞET KUYRUĞU ============
create or replace function oyun.m2_saat_yaz(t timestamptz) returns text language sql immutable set search_path to '' as $$
  select to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')
$$;

-- Tahmini yayın başlangıcı. p_id verilirse sıradaki o kaydın, verilmezse şimdi eklenecek yeni kaydın.
create or replace function oyun.m2_tahmin(p_tur text, p_id bigint default null) returns timestamptz
language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare a oyun.m2_ayar; yer integer; saat integer; t timestamptz := oyun.simdi(); dur_bit timestamptz; ends timestamptz[]; r record; i integer; m integer; bas timestamptz;
begin
  select * into a from oyun.m2_ayar where id = 1;
  yer := case when p_tur = 'kursu' then a.vitrin_yer else a.manset_yer end;
  saat := case when p_tur = 'kursu' then a.vitrin_saat else a.manset_saat end;
  if oyun.m2_duraklat(t) then
    select max(s.oy_bit) into dur_bit from oyun.secimler s
     where s.tur in ('mv', 'cb', 'cb2', 'bel') and not coalesce(s.ara, false) and s.durum not in ('iptal', 'tamam') and s.oy_bas <= t and s.oy_bit > t;
  end if;
  select coalesce(array_agg(greatest(y.bit, t) + coalesce(dur_bit - t, interval '0') order by y.bit), '{}') into ends
    from oyun.m2_yayin y where y.tur = p_tur and y.durum = 'yayinda';
  t := greatest(t, coalesce(dur_bit, t));
  while coalesce(array_length(ends, 1), 0) < yer loop ends := ends || t; end loop;
  for r in select y.id from oyun.m2_yayin y where y.tur = p_tur and y.durum = 'sirada' order by y.sira_zaman, y.id loop
    m := 1;
    for i in 2..array_length(ends, 1) loop if ends[i] < ends[m] then m := i; end if; end loop;
    bas := greatest(ends[m], t);
    if r.id = p_id then return bas; end if;
    ends[m] := bas + make_interval(hours => saat);
  end loop;
  if p_id is not null then return null; end if;
  m := 1;
  for i in 2..array_length(ends, 1) loop if ends[i] < ends[m] then m := i; end if; end loop;
  return greatest(ends[m], t);
end $$;

create or replace function oyun.m2_sira_no(p_id bigint) returns integer language sql stable set search_path to '' as $$
  select count(*)::integer + 1 from oyun.m2_yayin y, oyun.m2_yayin b
   where b.id = p_id and y.tur = b.tur and y.durum = 'sirada' and (y.sira_zaman, y.id) < (b.sira_zaman, b.id)
$$;

create or replace function oyun.m2_ad_tur(p_tur text) returns text language sql immutable set search_path to '' as $$
  select case when p_tur = 'kursu' then 'Kürsü vitrinin' else 'Gündem manşetin' end
$$;

-- Zamanlayıcı (5 dk): biten/kaldırılan kayıtlar, manşet otomatik inceleme, boşalan yerlere sıradakiler
create or replace function oyun.m2_tick() returns jsonb
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare a oyun.m2_ayar; t timestamptz := oyun.simdi(); dur boolean; r record; v_tur text; yer integer; saat integer; bos integer;
        n_bas integer := 0; n_son integer := 0; n_onay integer := 0; hata integer := 0;
begin
  if not pg_try_advisory_xact_lock(hashtext('m2_tick')) then return jsonb_build_object('atlandi', true); end if;
  select * into a from oyun.m2_ayar where id = 1;
  dur := oyun.m2_duraklat(t);
  if dur and a.son_tick is not null and t > a.son_tick then
    update oyun.m2_yayin set bit = bit + least(t - a.son_tick, interval '15 minutes') where durum = 'yayinda';
  end if;
  -- Kürsü paylaşımı gizlendi ya da silindi
  for r in select y.id, y.user_id, y.durum from oyun.m2_yayin y left join oyun.akis ak on ak.id = y.akis_id
            where y.tur = 'kursu' and y.durum in ('sirada', 'yayinda') and (ak.id is null or ak.gizli) order by y.id limit 200 loop
    begin
      update oyun.m2_yayin set durum = 'kaldirildi', bit = least(coalesce(bit, t), t),
        gerekce = coalesce(gerekce, 'Paylaşım kaldırıldığı ya da silindiği için vitrinden çıktı.') where id = r.id;
      perform oyun.bildir(r.user_id, 'Vitrindeki Kürsü paylaşımın kaldırıldığı ya da silindiği için vitrinden çıktı.', t);
      n_son := n_son + 1;
    exception when others then hata := hata + 1;
    end;
  end loop;
  -- Süresi dolanlar
  for r in select y.id, y.user_id, y.tur from oyun.m2_yayin y where y.durum = 'yayinda' and y.bit <= t order by y.bit limit 200 loop
    begin
      update oyun.m2_yayin set durum = 'bitti' where id = r.id;
      perform oyun.bildir(r.user_id, format('%s süresini doldurdu ve yayından kalktı. İlgin için teşekkürler!', oyun.m2_ad_tur(r.tur)), t);
      n_son := n_son + 1;
    exception when others then hata := hata + 1;
    end;
  end loop;
  -- Süresinde incelenmeyen manşet: süzgeçten geçerse sıraya girer, geçmezse reddedilir ve hak geri verilir
  for r in select y.* from oyun.m2_yayin y where y.tur = 'manset' and y.durum = 'onay'
             and y.olusturma <= t - make_interval(hours => a.manset_oto_onay_saat) order by y.id limit 100 loop
    begin
      if oyun.kufurlu(r.baslik) or oyun.bolucu(r.baslik) then
        update oyun.m2_yayin set durum = 'reddedildi', karar_zaman = t, gerekce = 'Uygunsuz ifade içerdiği için reddedildi.' where id = r.id;
        perform oyun.m2_jeton_ekle(r.user_id, 'm2_manset', 1);
        perform oyun.bildir(r.user_id, 'Gündem manşetin uygunsuz ifade içerdiği için reddedildi. Manşet hakkın geri verildi.', t);
      else
        update oyun.m2_yayin set durum = 'sirada', sira_zaman = t, karar_zaman = t,
          gerekce = 'Süresinde karar verilmediği için kendiliğinden onaylandı.' where id = r.id;
        n_onay := n_onay + 1;
      end if;
    exception when others then hata := hata + 1;
    end;
  end loop;
  -- Boşalan yerler
  if not dur then
    foreach v_tur in array array['kursu', 'manset'] loop
      yer := case when v_tur = 'kursu' then a.vitrin_yer else a.manset_yer end;
      saat := case when v_tur = 'kursu' then a.vitrin_saat else a.manset_saat end;
      bos := yer - (select count(*) from oyun.m2_yayin where tur = v_tur and durum = 'yayinda');
      if bos > 0 then
        for r in select y.id, y.user_id from oyun.m2_yayin y where y.tur = v_tur and y.durum = 'sirada'
                  order by y.sira_zaman, y.id limit bos loop
          begin
            update oyun.m2_yayin set durum = 'yayinda', bas = t, bit = t + make_interval(hours => saat) where id = r.id;
            perform oyun.bildir(r.user_id, format('%s şu an yayında! %s saat sürecek, bitiş: %s.', oyun.m2_ad_tur(v_tur), saat,
              oyun.m2_saat_yaz(t + make_interval(hours => saat))), t);
            n_bas := n_bas + 1;
          exception when others then hata := hata + 1;
          end;
        end loop;
      end if;
    end loop;
  end if;
  -- Kendiliğinden onaylanan manşetlerin sahiplerine tahmini yayın saati (yayına girmediyse)
  if n_onay > 0 then
    for r in select y.id, y.user_id from oyun.m2_yayin y where y.tur = 'manset' and y.durum = 'sirada' and y.karar_zaman = t loop
      perform oyun.bildir(r.user_id, format('Gündem manşetin onaylandı ve sıraya girdi. Tahmini yayın: %s. Yayına girince haber vereceğiz.',
        oyun.m2_saat_yaz(oyun.m2_tahmin('manset', r.id))), t);
    end loop;
  end if;
  update oyun.m2_ayar set son_tick = t where id = 1;
  if n_bas + n_son > 0 and to_regprocedure('oyun.canli_sinyal(text)') is not null then
    perform oyun.canli_sinyal('kursu:akis');
  end if;
  return jsonb_build_object('baslayan', n_bas, 'biten', n_son, 'oto_onay', n_onay, 'duraklat', dur, 'hata', hata);
end $$;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
    values ('magaza_paket2', 'select oyun.m2_tick()', 5, 1, 130, true)
    on conflict (adim) do nothing;
  end if;
end $z$;

-- Kuyruğa giren kaydın sahibine bilgi ve dönüş
create or replace function oyun.m2_kuyruk_cevap(p_id bigint) returns jsonb
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare y oyun.m2_yayin; tah timestamptz; sn integer;
begin
  select * into y from oyun.m2_yayin where id = p_id;
  if y.durum = 'sirada' then
    tah := oyun.m2_tahmin(y.tur, y.id); sn := oyun.m2_sira_no(y.id);
    perform oyun.bildir(y.user_id, format('%s sıraya girdi (%s. sıra). Tahmini yayın: %s. Yayına girdiğinde haber vereceğiz.',
      oyun.m2_ad_tur(y.tur), sn, oyun.m2_saat_yaz(tah)), oyun.simdi());
  end if;
  return jsonb_build_object('id', y.id, 'tur', y.tur, 'durum', y.durum, 'bas', y.bas, 'bit', y.bit, 'tahmin', tah, 'sira', sn);
end $$;

create or replace function public.kursu_vitrin_baslat(p_akis bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); ak oyun.akis; yid bigint;
begin
  perform pg_advisory_xact_lock(hashtext('m2_tick'));
  select * into ak from oyun.akis where id = p_akis;
  if ak.id is null or ak.gizli then raise exception 'Paylaşım bulunamadı ya da kaldırılmış.'; end if;
  if ak.user_id is distinct from p.id then raise exception 'Yalnız kendi paylaşımını vitrine çıkarabilirsin.'; end if;
  if ak.yanit_id is not null then raise exception 'Yanıtlar vitrine çıkamaz; ana paylaşımlarından birini seç.'; end if;
  if exists (select 1 from oyun.m2_yayin where user_id = p.id and tur = 'kursu' and durum in ('sirada', 'yayinda')) then
    raise exception 'Sırada ya da yayında bir vitrinin zaten var. O bitince yenisini başlatabilirsin.';
  end if;
  if not oyun.m2_jeton_harca(p.id, 'm2_vitrin') then raise exception 'Kürsü Vitrini hakkın yok. Mağaza''dan alabilirsin.'; end if;
  insert into oyun.m2_yayin(tur, user_id, akis_id, durum, sira_zaman, olusturma) values ('kursu', p.id, ak.id, 'sirada', t, t) returning id into yid;
  perform oyun.m2_tick();
  return oyun.m2_kuyruk_cevap(yid);
end $$;

create or replace function public.manset_basvur(p_baslik text, p_parti_adina boolean default false) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m text; pid bigint; yid bigint; a oyun.m2_ayar; r record;
begin
  select * into a from oyun.m2_ayar where id = 1;
  m := btrim(regexp_replace(coalesce(p_baslik, ''), '\s+', ' ', 'g'));
  if length(m) < 10 then raise exception 'Manşet en az 10 karakter olmalı.'; end if;
  if length(m) > 120 then raise exception 'Manşet en fazla 120 karakter olabilir.'; end if;
  if oyun.kufurlu(m) then raise exception 'Manşette uygunsuz bir ifade var.'; end if;
  if m ~* '(https?://|www\.|\.com\b)' then raise exception 'Manşette bağlantı paylaşılamaz.'; end if;
  if exists (select 1 from oyun.m2_yayin where user_id = p.id and tur = 'manset' and durum in ('onay', 'sirada', 'yayinda')) then
    raise exception 'İncelemede, sırada ya da yayında bir manşetin zaten var. O bitince yenisini verebilirsin.';
  end if;
  if coalesce(p_parti_adina, false) then
    pid := oyun.m2_parti_adina(p.id);
    if pid is null then raise exception 'Parti adına manşet için genel başkan, tanıtım ya da seçim işlerinden sorumlu yardımcı veya parti sözcüsü olmalısın.'; end if;
  end if;
  perform pg_advisory_xact_lock(hashtext('m2_tick'));
  if not oyun.m2_jeton_harca(p.id, 'm2_manset') then raise exception 'Gündem Manşeti hakkın yok. Mağaza''dan alabilirsin.'; end if;
  insert into oyun.m2_yayin(tur, user_id, baslik, parti_id, durum, olusturma) values ('manset', p.id, m, pid, 'onay', t) returning id into yid;
  perform oyun.bildir(p.id, format('Gündem manşetin incelemeye gönderildi. Onaylanınca sıraya girer; %s saat içinde karar verilmezse kendiliğinden incelenir.', a.manset_oto_onay_saat), t);
  for r in select m2.user_id from oyun.moderatorler m2 join oyun.profiller pr on pr.id = m2.user_id
            where 'sikayet' = any (m2.yetkiler) and not pr.yasakli limit 30 loop
    perform oyun.bildir(r.user_id, 'Onay bekleyen bir Gündem Manşeti var (Gündem › Manşet onayı).', t);
  end loop;
  return jsonb_build_object('id', yid, 'durum', 'onay');
end $$;

create or replace function oyun.m2_yayin_json(y oyun.m2_yayin) returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select jsonb_build_object('id', y.id, 'tur', y.tur, 'durum', y.durum, 'baslik', y.baslik, 'akis_id', y.akis_id,
    'kad', (select kad from oyun.profiller where id = y.user_id), 'ad', oyun.m2_ad(y.user_id),
    'parti', case when y.parti_id is not null then (select jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = y.parti_id) end,
    'metin', case when y.tur = 'kursu' then (select left(ak.metin, 200) from oyun.akis ak where ak.id = y.akis_id) end,
    'olusturma', y.olusturma, 'sira_zaman', y.sira_zaman, 'bas', y.bas, 'bit', y.bit, 'gerekce', y.gerekce,
    'tahmin', case when y.durum = 'sirada' then oyun.m2_tahmin(y.tur, y.id) end,
    'sira', case when y.durum = 'sirada' then oyun.m2_sira_no(y.id) end)
$$;

-- İçerik Masası: onay bekleyen manşetler + yayındaki/sıradaki vitrin ve manşetler
create or replace function public.manset_onay_liste() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  return jsonb_build_object(
    'onay', (select coalesce(jsonb_agg(oyun.m2_yayin_json(y) order by y.id), '[]') from oyun.m2_yayin y where y.tur = 'manset' and y.durum = 'onay'),
    'aktif', (select coalesce(jsonb_agg(oyun.m2_yayin_json(y) order by y.tur, y.durum desc, y.sira_zaman, y.id), '[]') from oyun.m2_yayin y where y.durum in ('sirada', 'yayinda')),
    'oto_saat', (select manset_oto_onay_saat from oyun.m2_ayar where id = 1));
end $$;

create or replace function public.manset_karar(p_id bigint, p_onay boolean, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); y oyun.m2_yayin; g text := nullif(btrim(coalesce(p_gerekce, '')), '');
begin
  perform pg_advisory_xact_lock(hashtext('m2_tick'));
  select * into y from oyun.m2_yayin where id = p_id for update;
  if y.id is null or y.tur <> 'manset' then raise exception 'Manşet bulunamadı.'; end if;
  if y.durum <> 'onay' then raise exception 'Bu manşet için karar zaten verilmiş.'; end if;
  if p_onay then
    update oyun.m2_yayin set durum = 'sirada', sira_zaman = t, karar_zaman = t, karar_veren = p.id where id = y.id;
    perform oyun.m2_tick();
    select * into y from oyun.m2_yayin where id = p_id;
    if y.durum = 'sirada' then return oyun.m2_kuyruk_cevap(y.id); end if;
    return oyun.m2_yayin_json(y);
  end if;
  if g is null or length(g) < 5 then raise exception 'Ret gerekçesi yaz (en az 5 karakter).'; end if;
  update oyun.m2_yayin set durum = 'reddedildi', karar_zaman = t, karar_veren = p.id, gerekce = left(g, 300) where id = y.id;
  perform oyun.m2_jeton_ekle(y.user_id, 'm2_manset', 1);
  perform oyun.bildir(y.user_id, format('Gündem manşetin yayına uygun bulunmadı: %s. Manşet hakkın geri verildi; düzenleyip yeniden gönderebilirsin.', left(g, 300)), t);
  return jsonb_build_object('id', y.id, 'durum', 'reddedildi');
end $$;

-- İçerik Masası: sıradaki/yayındaki vitrin ya da manşeti kaldırır (kurala aykırı; hak iade edilmez)
create or replace function public.m2_yayin_kaldir(p_id bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); y oyun.m2_yayin; g text := nullif(btrim(coalesce(p_gerekce, '')), '');
begin
  if g is null or length(g) < 5 then raise exception 'Kaldırma gerekçesi yaz (en az 5 karakter).'; end if;
  perform pg_advisory_xact_lock(hashtext('m2_tick'));
  select * into y from oyun.m2_yayin where id = p_id for update;
  if y.id is null or y.durum not in ('sirada', 'yayinda') then raise exception 'Kaldırılacak kayıt bulunamadı.'; end if;
  update oyun.m2_yayin set durum = 'kaldirildi', karar_zaman = t, karar_veren = p.id, gerekce = left(g, 300), bit = least(coalesce(bit, t), t) where id = y.id;
  perform oyun.bildir(y.user_id, format('%s oyun kurallarına aykırı bulunduğu için yönetim tarafından kaldırıldı: %s', oyun.m2_ad_tur(y.tur), left(g, 300)), t);
  perform oyun.m2_tick();
  return jsonb_build_object('id', y.id, 'durum', 'kaldirildi');
end $$;

-- Sahibi incelemedeki ya da sıradaki kaydını geri çeker; hakkı geri verilir
create or replace function public.m2_yayin_iptal(p_id bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); y oyun.m2_yayin;
begin
  perform pg_advisory_xact_lock(hashtext('m2_tick'));
  select * into y from oyun.m2_yayin where id = p_id for update;
  if y.id is null or y.user_id <> p.id then raise exception 'Kayıt bulunamadı.'; end if;
  if y.durum not in ('onay', 'sirada') then raise exception 'Yalnız incelemede ya da sırada bekleyen kayıt geri çekilebilir.'; end if;
  update oyun.m2_yayin set durum = 'iptal', karar_zaman = oyun.simdi() where id = y.id;
  perform oyun.m2_jeton_ekle(p.id, case when y.tur = 'kursu' then 'm2_vitrin' else 'm2_manset' end, 1);
  return jsonb_build_object('id', y.id, 'durum', 'iptal');
end $$;

-- ============ ÖZEL PLAKA ============
create or replace function oyun.m2_plaka_yasak(h text) returns boolean language sql immutable set search_path to '' as $$
  select h = any (array['A', 'AA', 'CC', 'CD', 'CV', 'CR', 'CA', 'PKK', 'YPG', 'PYD', 'KCK', 'FET', 'DHK', 'ISD', 'DAE', 'AMK', 'AK', 'SIK',
                        'GOT', 'PIC', 'OC', 'MAL', 'SKM', 'SKT', 'YAR', 'TCK', 'POL', 'JAN', 'EMN', 'MIT', 'TSK', 'KKK', 'SS', 'NAZ'])
$$;

create or replace function public.plaka_kaydet(p_il integer, p_harf text, p_rakam text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h text; rk text; n integer; seckin boolean; mv oyun.m2_plaka; metin text; ucretli boolean := false;
begin
  if not oyun.hak_var(p.id, 'plaka') and not oyun.hak_var(p.id, 'plaka_seckin') then raise exception 'Özel Plaka''n yok. Mağaza''dan alabilirsin.'; end if;
  h := upper(btrim(coalesce(p_harf, ''))); rk := btrim(coalesce(p_rakam, ''));
  if p_il is null or p_il not between 1 and 81 then raise exception 'İl kodu 01 ile 81 arasında olmalı.'; end if;
  if h !~ '^[ABCDEFGHIJKLMNOPRSTUVYZ]{1,3}$' then raise exception 'Plakada 1–3 harf olur; Ç, Ğ, İ, Ö, Ş, Ü, Q, W ve X kullanılmaz.'; end if;
  if rk !~ '^[0-9]{1,4}$' then raise exception 'Plaka numarası 1–4 rakam olmalı.'; end if;
  n := rk::integer;
  if n < 1 then raise exception 'Plaka numarası 0 olamaz.'; end if;
  seckin := length(h) = 1 or n <= 99;
  if seckin then
    if not oyun.hak_var(p.id, 'plaka_seckin') then raise exception 'Tek harfli ya da 01–99 numaralı plakalar Seçkin Plaka ister.'; end if;
    if length(rk) > 3 then raise exception 'Seçkin plakada numara en çok 3 haneli yazılır (örneğin 07 ya da 001).'; end if;
  else
    if length(h) < 2 or length(rk) not between 3 and 4 or rk ~ '^0' then raise exception 'Standart plakada 2–3 harf ve 100–9999 arası numara olur (örneğin 35 AY 1923).'; end if;
  end if;
  if oyun.m2_plaka_yasak(h) or oyun.kufurlu(h) or oyun.bolucu(h) then raise exception 'Bu harf grubu plakada kullanılamaz.'; end if;
  metin := lpad(p_il::text, 2, '0') || ' ' || h || ' ' || rk;
  perform pg_advisory_xact_lock(hashtext('m2_plaka'));
  if exists (select 1 from oyun.m2_plaka where il = p_il and harf = h and rakam::integer = n and user_id <> p.id) then
    raise exception 'Bu plaka başka bir oyuncuda. Başka bir harf ya da numara dene.';
  end if;
  select * into mv from oyun.m2_plaka where user_id = p.id for update;
  if mv.user_id is not null and mv.il = p_il and mv.harf = h and mv.rakam = rk then return jsonb_build_object('plaka', metin); end if;
  if mv.user_id is not null and mv.secildi then
    if not oyun.m2_jeton_harca(p.id, 'plaka_degis') then raise exception 'Plakanı yeniden değiştirmek için Plaka Değiştirme hakkı gerekir.'; end if;
    ucretli := true;
  end if;
  insert into oyun.m2_plaka(user_id, il, harf, rakam, metin, secildi, zaman) values (p.id, p_il, h, rk, metin, true, t)
  on conflict (user_id) do update set il = excluded.il, harf = excluded.harf, rakam = excluded.rakam, metin = excluded.metin, secildi = true, zaman = excluded.zaman;
  return jsonb_build_object('plaka', metin, 'ucretli', ucretli, 'seckin', seckin);
end $$;

-- ============ MAZBATA / KUTLAMA ============
create or replace function public.mazbata_olustur(p_secim bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); yid bigint;
begin
  if oyun.m2_jeton(p.id, 'm2_mazbata') <= 0 then raise exception 'Mazbata hakkın yok. Mağaza''dan alabilirsin.'; end if;
  yid := oyun.m2_mazbata_uygula(p.id, oyun.simdi(), p_secim);
  if yid is null then raise exception 'Bu seçim için mazbata alınamaz: son 30 günde kazandığın ve daha önce mazbatası alınmamış bir seçim olmalı.'; end if;
  return jsonb_build_object('id', yid);
end $$;

create or replace function oyun.m2_mazbata_json(m oyun.m2_mazbata) returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select jsonb_build_object('id', m.id, 'secim_id', m.secim_id, 'tur', m.tur, 'ad', m.ad, 'gorev', m.gorev, 'oy_orani', m.oy_orani,
    'tarih', m.tarih, 'donem', oyun.m2_ay_yil(m.tarih), 'kad', (select kad from oyun.profiller where id = m.user_id),
    'parti', (select jsonb_build_object('ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = m.parti_id))
$$;

create or replace function public.mazbatalar(p_kad text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); h uuid;
begin
  if p_kad is null or btrim(p_kad) = '' then h := p.id; else select id into h from oyun.profiller where lower(kad) = lower(btrim(p_kad)); end if;
  if h is null then return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(oyun.m2_mazbata_json(m) order by m.tarih desc), '[]') from oyun.m2_mazbata m where m.user_id = h);
end $$;

create or replace function public.kutlama_uygula(p_secim bigint default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); yid bigint;
begin
  if oyun.m2_jeton(p.id, 'm2_kutlama') <= 0 then raise exception 'Seçim Gecesi Kutlaması hakkın yok.'; end if;
  yid := oyun.m2_kutlama_uygula(p.id, oyun.simdi(), p_secim);
  if yid is null then raise exception 'Kutlama yalnız son 7 günde kazandığın bir seçim için yapılabilir. Hakkın, kazandığın gece kendiliğinden kullanılacak.'; end if;
  return jsonb_build_object('id', yid);
end $$;

create or replace function public.kutlama_goruldu(p_id bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim();
begin
  update oyun.m2_zafer set goruldu = true where id = p_id and user_id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- ============ KONGRE PAKETİ ============
create or replace function public.kongre_slogan(p_slogan text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); sid bigint; m text := btrim(regexp_replace(coalesce(p_slogan, ''), '\s+', ' ', 'g'));
begin
  sid := oyun.m2_kurultay_adaylik(p.id);
  if sid is null or not exists (select 1 from oyun.m2_kongre where secim_id = sid and user_id = p.id) then
    perform oyun.m2_kongre_uygula(p.id, oyun.simdi());
    if sid is null or not exists (select 1 from oyun.m2_kongre where secim_id = sid and user_id = p.id) then
      raise exception 'Sloganı açık bir kurultay adaylığında Kongre Paketin varken değiştirebilirsin.';
    end if;
  end if;
  if length(m) < 3 or length(m) > 40 then raise exception 'Slogan 3–40 karakter olmalı.'; end if;
  if oyun.kufurlu(m) then raise exception 'Sloganda uygunsuz bir ifade var.'; end if;
  update oyun.m2_kongre set slogan = m where secim_id = sid and user_id = p.id;
  return jsonb_build_object('secim_id', sid, 'slogan', m);
end $$;

create or replace function public.kongre_paketleri(p_secim bigint) returns jsonb
language sql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'ad', oyun.m2_ad(pr.id), 'slogan', k.slogan,
           'renk', (select pa.renk from oyun.secimler s join oyun.partiler pa on pa.id = s.hedef_parti_id where s.id = k.secim_id))), '[]')
    from oyun.m2_kongre k join oyun.profiller pr on pr.id = k.user_id
   where k.secim_id = p_secim and not pr.yasakli
$$;

-- ============ HEDİYE VE PARTİ KARTI ============
create or replace function oyun.m2_kart_ver(u uuid, t timestamptz, aciklama text) returns void
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pk oyun.paketler;
begin
  select * into pk from oyun.paketler where tur = 'kart' and gun = 30 order by (urun_id = 'secimonline.politics_card_30d') desc, aktif desc limit 1;
  if pk.urun_id is null then pk.miktar := 30000; pk.gun := 30; end if;
  if coalesce(pk.miktar, 0) > 0 then perform oyun.para_islem(u, pk.miktar, 'satin_alma', aciklama, t); end if;
  insert into oyun.magaza_hesap(user_id, kart_bitis) values (u, t + make_interval(days => coalesce(pk.gun, 30)))
  on conflict (user_id) do update set kart_bitis = greatest(coalesce(oyun.magaza_hesap.kart_bitis, t), t) + make_interval(days => coalesce(pk.gun, 30));
end $$;

create or replace function public.hediye_kart_ver(p_kad text, p_not text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; n text := nullif(btrim(coalesce(p_not, '')), ''); son timestamptz;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendine hediye edemezsin; kendin için Mağaza''dan Siyaset Kartı alabilirsin.'; end if;
  if h.yasakli then raise exception 'Bu hesaba hediye gönderilemez.'; end if;
  if n is not null and (length(n) > 120 or oyun.kufurlu(n)) then raise exception 'Hediye notu en fazla 120 karakter olmalı ve uygunsuz ifade içermemeli.'; end if;
  if not oyun.m2_jeton_harca(p.id, 'm2_hediye_kart') then raise exception 'Hediye Siyaset Kartı hakkın yok. Mağaza''dan alabilirsin.'; end if;
  select max(zaman) into son from oyun.m2_hediye where veren = p.id;
  perform oyun.m2_kart_ver(h.id, t, format('Hediye Siyaset Kartı (%s)', oyun.m2_ad(p.id)));
  insert into oyun.m2_hediye(tur, veren, alan, notu, zaman) values ('hediye', p.id, h.id, n, t);
  perform oyun.bildir(h.id, format('%s sana 30 günlük Siyaset Kartı hediye etti%s', oyun.m2_ad(p.id), case when n is not null then ': “' || n || '”' else '.' end), t);
  if son is null or son < t - interval '10 minutes' then
    perform oyun.m2_sohbet(p.id, 'genel', format('[Hediye Kart] %s, %s adlı oyuncuya Siyaset Kartı hediye etti.', oyun.m2_ad(p.id), oyun.m2_ad(h.id)), t);
  end if;
  return jsonb_build_object('alan', h.kad, 'kalan', oyun.m2_jeton(p.id, 'm2_hediye_kart'));
end $$;

create or replace function public.parti_kart_ver(p_kad text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; pid bigint;
begin
  pid := oyun.m2_parti_yonetici(p.id);
  if pid is null then raise exception 'Parti kartlarını genel başkan ya da genel başkan yardımcıları dağıtır.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pid then raise exception 'Parti kartı yalnız partinin üyelerine verilebilir.'; end if;
  if h.id = p.id then raise exception 'Parti kartını kendine veremezsin; üyelerine dağıtılır.'; end if;
  if h.yasakli then raise exception 'Bu hesaba kart verilemez.'; end if;
  if exists (select 1 from oyun.m2_hediye where tur = 'parti' and alan = h.id and parti_id = pid and zaman > t - interval '30 days') then
    raise exception 'Bu üyeye son 30 günde partiden kart verildi.';
  end if;
  if not oyun.m2_jeton_harca(p.id, 'm2_parti_kart') then raise exception 'Parti kartı hakkın kalmadı. Mağaza''dan Parti Kart Paketi alabilirsin.'; end if;
  perform oyun.m2_kart_ver(h.id, t, format('Parti Kartı (%s)', oyun.m2_ad(p.id)));
  insert into oyun.m2_hediye(tur, veren, alan, parti_id, zaman) values ('parti', p.id, h.id, pid, t);
  perform oyun.bildir(h.id, format('%s partimiz adına sana 30 günlük Siyaset Kartı verdi.', oyun.m2_ad(p.id)), t);
  perform oyun.m2_sohbet(p.id, 'parti:' || pid, format('[Parti Kartı] %s, %s adlı üyemize 30 günlük Siyaset Kartı verdi.', oyun.m2_ad(p.id), oyun.m2_ad(h.id)), t);
  return jsonb_build_object('alan', h.kad, 'kalan', oyun.m2_jeton(p.id, 'm2_parti_kart'));
end $$;

-- Bekleyen jetonları (bağış, genel merkez, sahne, kongre, mazbata, kutlama) şimdi dener
create or replace function public.m2_bekleyen_uygula() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim();
begin
  perform oyun.m2_bekleyenleri_uygula(p.id, oyun.simdi());
  return oyun.m2_magaza_ek(p.id) -> 'm2';
end $$;

-- ============ GENEL MERKEZ ============
create or replace function public.genel_merkez(p_parti bigint default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); pid bigint := coalesce(p_parti, p.parti_id); a oyun.m2_ayar; n bigint; s integer;
begin
  select * into a from oyun.m2_ayar where id = 1;
  select count(*) into n from oyun.m2_gm_katki where parti_id = pid;
  s := oyun.m2_gm_seviye_hesap(n, a.gm_esik);
  return jsonb_build_object(
    'parti', (select jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = pid),
    'katki', n, 'seviye', s, 'seviye_ad', oyun.m2_gm_ad(s), 'esik', to_jsonb(a.gm_esik),
    'sonraki', case when s < coalesce(array_length(a.gm_esik, 1), 0) then a.gm_esik[s + 1] end,
    'sonraki_ad', case when s < coalesce(array_length(a.gm_esik, 1), 0) then oyun.m2_gm_ad(s + 1) end,
    'tutar', a.gm_tutar,
    'liste', (select coalesce(jsonb_agg(z.x order by z.adet desc, z.son), '[]') from (
                select jsonb_build_object('kad', pr.kad, 'ad', oyun.m2_ad(pr.id), 'adet', count(*)) x, count(*) adet, max(k.id) son
                  from oyun.m2_gm_katki k join oyun.profiller pr on pr.id = k.user_id where k.parti_id = pid
                 group by pr.id, pr.kad order by count(*) desc, max(k.id) limit 20) z),
    'siralama', (select coalesce(jsonb_agg(jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'katki', coalesce(g.n, 0),
                    'seviye', oyun.m2_gm_seviye_hesap(coalesce(g.n, 0), a.gm_esik)) order by coalesce(g.n, 0) desc, pa.id), '[]')
                  from oyun.partiler pa left join (select parti_id, count(*) n from oyun.m2_gm_katki group by parti_id) g on g.parti_id = pa.id
                 where not pa.kapali),
    'uyesiyim', p.parti_id = pid,
    'katki_verebilir', p.parti_id = pid and p.olusturma <= oyun.simdi() - make_interval(days => a.gm_hesap_gun),
    'hesap_gun', a.gm_hesap_gun);
end $$;

-- ============ DESTEKÇİLER DUVARI ============
create or replace function oyun.m2_duvar(p_ay text) returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'ad', oyun.m2_ad(pr.id), 'kademe', d.k) order by d.k desc, d.ilk), '[]')
    from (select user_id, max(kademe) k, min(zaman) ilk from oyun.m2_destek where ay = p_ay group by user_id) d
    join oyun.profiller pr on pr.id = d.user_id where not pr.yasakli
$$;

create or replace function public.destekci_duvari(p_ay text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); ay text := coalesce(nullif(p_ay, ''), oyun.m2_ay(oyun.simdi()));
begin
  if ay !~ '^\d{4}-\d{2}$' then raise exception 'Geçersiz ay.'; end if;
  return jsonb_build_object('ay', ay, 'ay_ad', oyun.m2_ay_yil((ay || '-15')::date::timestamptz), 'liste', oyun.m2_duvar(ay));
end $$;

-- ============ HERKESE AÇIK ÖZET (istemci 5 dk önbellekler) ============
create or replace function public.m2_genel() returns jsonb
language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.m2_ayar; dur boolean := oyun.m2_duraklat(oyun.simdi());
begin
  select * into a from oyun.m2_ayar where id = 1;
  return jsonb_build_object(
    'sahne', (select coalesce(jsonb_agg(parti_id), '[]') from oyun.m2_parti_sahne),
    'gm', (select coalesce(jsonb_agg(jsonb_build_object('p', parti_id, 'k', n, 's', oyun.m2_gm_seviye_hesap(n, a.gm_esik))), '[]')
             from (select parti_id, count(*) n from oyun.m2_gm_katki group by parti_id) g),
    'duvar', oyun.m2_duvar(oyun.m2_ay(t)), 'ay_ad', oyun.m2_ay_yil(t),
    'vitrin', case when dur then '[]'::jsonb else (select coalesce(jsonb_agg(y.akis_id), '[]') from oyun.m2_yayin y where y.tur = 'kursu' and y.durum = 'yayinda') end,
    'manset', case when dur then '[]'::jsonb else (select coalesce(jsonb_agg(oyun.m2_yayin_json(y) order by y.bas), '[]') from oyun.m2_yayin y where y.tur = 'manset' and y.durum = 'yayinda') end,
    'duraklat', dur,
    'manset_onay', case when oyun.yetkili(p.id, 'sikayet') then (select count(*) from oyun.m2_yayin where tur = 'manset' and durum = 'onay') end);
end $$;

-- ============ MAĞAZA DURUMUNA EK (magaza_durum || ...) ============
create or replace function oyun.m2_magaza_ek(u uuid) returns jsonb
language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare a oyun.m2_ayar; t timestamptz := oyun.simdi(); pr oyun.profiller; pa oyun.partiler; pl oyun.m2_plaka; n bigint; s integer; sid bigint;
begin
  select * into a from oyun.m2_ayar where id = 1;
  select * into pr from oyun.profiller where id = u;
  select * into pa from oyun.partiler where id = pr.parti_id and not kapali;
  select * into pl from oyun.m2_plaka where user_id = u;
  select count(*) into n from oyun.m2_gm_katki where parti_id = pa.id;
  s := oyun.m2_gm_seviye_hesap(n, a.gm_esik);
  sid := oyun.m2_kurultay_adaylik(u);
  return jsonb_build_object('m2', jsonb_build_object(
    'jeton', (select coalesce(jsonb_object_agg(kod, adet), '{}') from oyun.magaza_jeton where user_id = u and adet > 0 and (kod like 'm2\_%' or kod = 'plaka_degis')),
    'plaka', case when pl.user_id is not null then jsonb_build_object('metin', pl.metin, 'il', pl.il, 'harf', pl.harf, 'rakam', pl.rakam, 'secildi', pl.secildi, 'makam', oyun.m2_makamda(u)) end,
    'plaka_hak', oyun.hak_var(u, 'plaka') or oyun.hak_var(u, 'plaka_seckin'), 'seckin_hak', oyun.hak_var(u, 'plaka_seckin'), 'il', pr.il_id,
    'vitrin', jsonb_build_object('yer', a.vitrin_yer, 'saat', a.vitrin_saat,
        'dolu', (select count(*) from oyun.m2_yayin where tur = 'kursu' and durum = 'yayinda'),
        'sira', (select count(*) from oyun.m2_yayin where tur = 'kursu' and durum = 'sirada'),
        'tahmin', oyun.m2_tahmin('kursu', null)),
    'manset', jsonb_build_object('yer', a.manset_yer, 'saat', a.manset_saat, 'oto_saat', a.manset_oto_onay_saat,
        'dolu', (select count(*) from oyun.m2_yayin where tur = 'manset' and durum = 'yayinda'),
        'sira', (select count(*) from oyun.m2_yayin where tur = 'manset' and durum = 'sirada'),
        'tahmin', oyun.m2_tahmin('manset', null)),
    'yayinlarim', (select coalesce(jsonb_agg(oyun.m2_yayin_json(y) order by y.id desc), '[]') from oyun.m2_yayin y
                    where y.user_id = u and (y.durum in ('onay', 'sirada', 'yayinda') or y.olusturma > t - interval '7 days')),
    'parti', case when pa.id is not null then jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk,
        'sahne', exists (select 1 from oyun.m2_parti_sahne where parti_id = pa.id), 'gm_katki', n, 'gm_seviye', s, 'gm_seviye_ad', oyun.m2_gm_ad(s),
        'gm_sonraki', case when s < coalesce(array_length(a.gm_esik, 1), 0) then a.gm_esik[s + 1] end,
        'yonetici', oyun.m2_parti_yonetici(u) is not null, 'parti_adina', oyun.m2_parti_adina(u) is not null,
        'bagisci_bitis', (select b.bitis from oyun.m2_bagisci b where b.user_id = u and b.parti_id = pa.id and b.bitis > t)) end,
    'gm_hesap_tamam', pr.olusturma <= t - make_interval(days => a.gm_hesap_gun), 'gm_hesap_gun', a.gm_hesap_gun,
    'bagis_tutar', a.bagis_tutar, 'gm_tutar', a.gm_tutar, 'parti_kart_adet', a.parti_kart_adet,
    'kongre', case when sid is not null then jsonb_build_object('secim_id', sid,
        'slogan', (select slogan from oyun.m2_kongre where secim_id = sid and user_id = u)) end,
    'zaferler', (select coalesce(jsonb_agg(jsonb_build_object('secim_id', z.secim_id, 'gorev', oyun.m2_gorev(z.secim_id, z.il_id, z.parti_id), 'tarih', z.tarih,
        'mazbata', exists (select 1 from oyun.m2_mazbata m where m.user_id = u and m.secim_id = z.secim_id),
        'kutlama', exists (select 1 from oyun.m2_zafer m where m.user_id = u and m.secim_id = z.secim_id))), '[]') from oyun.m2_zaferler(u, 30) z),
    'mazbata_sayi', (select count(*) from oyun.m2_mazbata where user_id = u),
    'kutlama_bekleyen', (select jsonb_build_object('id', z.id, 'gorev', z.gorev, 'rozet', z.rozet, 'oy_orani', z.oy_orani)
                           from oyun.m2_zafer z where z.user_id = u and not z.goruldu and z.zaman > t - interval '7 days' order by z.id desc limit 1),
    'destek', (select max(kademe) from oyun.m2_destek where user_id = u and ay = oyun.m2_ay(t)),
    'yillik_bitis', (select yillik_bitis from oyun.magaza_hesap where user_id = u and yillik_bitis > t),
    'duraklat', oyun.m2_duraklat(t)));
end $$;

-- ============ MEVCUT İŞLEVLERE BAĞLANTI ============
-- 1) Satın alma etkisi
select oyun._yama('oyun.magaza_uygula(uuid, oyun.paketler, integer, timestamptz)',
  'return dus;', 'dus := dus + coalesce(oyun.m2_uygula(u, pk, isaret, t), 0) /*M2U*/; return dus;', '/*M2U*/', true);
-- 2) Mağaza durumu (yeni istemci 'm2' alanını okur; eski istemci yok sayar)
select oyun._yama('public.magaza_durum()', '/*KG6*/;', '/*KG6*/ || oyun.m2_magaza_ek(p.id) /*M2D*/;', '/*M2D*/', true);

-- 3) Kürsü akışının ilk sayfasının başına vitrindeki paylaşımlar (eski uygulamada da en üstte görünür)
create or replace function oyun.m2_akis_ekle(r jsonb, p_sekme text, p_imlec text, u uuid) returns jsonb
language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v_ids bigint[]; v_eng uuid[]; v jsonb; liste jsonb;
begin
  if coalesce(p_imlec, '') <> '' or p_sekme not in ('sana', 'herkes') or oyun.m2_duraklat(oyun.simdi()) then return r; end if;
  select array_agg(y.akis_id order by y.bas, y.id) into v_ids from oyun.m2_yayin y join oyun.akis a on a.id = y.akis_id
   where y.tur = 'kursu' and y.durum = 'yayinda' and not a.gizli;
  if v_ids is null then return r || jsonb_build_object('vitrin', '[]'::jsonb); end if;
  select array_agg(case when g.engelleyen = u then g.engellenen else g.engelleyen end) into v_eng
    from oyun.engellemeler g where g.engelleyen = u or g.engellenen = u;
  if v_eng is not null then
    select array_agg(x) into v_ids from unnest(v_ids) x
     where not exists (select 1 from oyun.akis a where a.id = x and a.user_id = any (v_eng));
    if v_ids is null then return r || jsonb_build_object('vitrin', '[]'::jsonb); end if;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('sira', j.g ->> 'zaman', 'yp', null, 'vitrin', true, 'g', j.g || jsonb_build_object('vitrin', true)) order by u2.ord), '[]')
    into v from unnest(v_ids) with ordinality u2(id, ord) join oyun.kursu_json_toplu(v_ids, u) j on j.id = u2.id where j.g is not null;
  select coalesce(jsonb_agg(e.x order by e.o), '[]') into liste
    from jsonb_array_elements(coalesce(r -> 'liste', '[]'::jsonb)) with ordinality e(x, o)
   where coalesce((e.x -> 'g' ->> 'id')::bigint, 0) <> all (v_ids);
  return r || jsonb_build_object('liste', v || liste, 'vitrin', to_jsonb(v_ids));
end $$;
select oyun._yama('public.kursu_akis(text,text,integer)',
  'return (jsonb_build_object\(''liste'', v_liste,[^;]*end\));', 'return oyun.m2_akis_ekle(\1, p_sekme, p_imlec, p.id) /*M2A1*/;', '/*M2A1*/');
select oyun._yama('public.kursu_akis(text,text,integer)',
  'return (jsonb_build_object\(''liste'', v_liste,[^;]*end\));', 'return oyun.m2_akis_ekle(\1, p_sekme, p_imlec, p.id) /*M2A2*/;', '/*M2A2*/');

-- 4) Haber şeridinin başına yayındaki manşetler ("Manşet ·" ile işaretli, eski uygulamada da görünür)
create or replace function oyun.m2_manset_haber() returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case when oyun.m2_duraklat(oyun.simdi()) then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object('zaman', y.bas, 'tur', 'manset', 'manset', true, 'id', y.id, 'bit', y.bit, 'baslik', y.baslik,
             'imza', coalesce((select pa.ad from oyun.partiler pa where pa.id = y.parti_id), oyun.m2_ad(y.user_id)),
             'metin', 'Manşet · ' || y.baslik || ' (' || coalesce((select pa.kisa from oyun.partiler pa where pa.id = y.parti_id), oyun.m2_ad(y.user_id)) || ')',
             'parti', oyun.parti_json(y.parti_id)) order by y.bas, y.id)
      from oyun.m2_yayin y where y.tur = 'manset' and y.durum = 'yayinda'), '[]'::jsonb) end
$$;
create or replace function public.haberler(p_limit integer default 40) returns jsonb
language sql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
  select oyun.m2_manset_haber() || coalesce((
    select jsonb_agg(jsonb_build_object('zaman', o.zaman, 'tur', o.tur, 'metin', o.metin, 'parti', oyun.parti_json(o.parti_id)) order by o.zaman desc, o.id desc)
      from (select * from oyun.olaylar where zaman <= oyun.simdi() order by zaman desc, id desc limit least(greatest(p_limit, 1), 100)) o), '[]'::jsonb)
$$;

-- 5) Rozetler: plaka (p:, makamda pm), destekçi duvarı (dw:), genel merkez (gm:), büyük bağışçı (bb:parti), yıllık üye (yu), son zafer (z:)
create or replace function public.magaza_rozetler() returns jsonb
language sql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(jsonb_object_agg(pr.kad, r.rozet), '{}'::jsonb)
      || jsonb_build_object('#partiler', coalesce((select string_agg(id::text, ',' order by id) from oyun.partiler where kimlik_alan is not null and not kapali), ''),
                            '#sahne', coalesce((select string_agg(parti_id::text, ',' order by parti_id) from oyun.m2_parti_sahne), ''))
  from (select user_id, string_agg(rozet, ',' order by rozet) rozet from (
          select user_id, hak rozet from oyun.oyuncu_hak where hak in ('destekci', 'kurucu', 'cerceve', 'imza', 'kampanya_tasarim') and aktif
          union all
          select h.user_id, 'r:' || replace(regexp_replace(k.ad, '\s*Rozeti$', ''), ',', ' ')
            from oyun.oyuncu_hak h join oyun.paketler k on k.hak = h.hak where h.hak like 'rozet\_%' and h.aktif
          union all
          select g.user_id, 'u:' || g.unvan from oyun.oyuncu_gorunum g
           where g.unvan is not null and oyun.hak_var(g.user_id, 'imza')
          union all
          select user_id, 'kart' from oyun.magaza_hesap where kart_bitis > oyun.simdi()
          union all
          select pl.user_id, 'p:' || pl.metin from oyun.m2_plaka pl
           where oyun.hak_var(pl.user_id, 'plaka') or oyun.hak_var(pl.user_id, 'plaka_seckin')
          union all
          select pl.user_id, 'pm' from oyun.m2_plaka pl
           where (oyun.hak_var(pl.user_id, 'plaka') or oyun.hak_var(pl.user_id, 'plaka_seckin')) and oyun.m2_makamda(pl.user_id)
          union all
          select d.user_id, 'dw:' || max(d.kademe) from oyun.m2_destek d where d.ay = oyun.m2_ay(oyun.simdi()) group by d.user_id
          union all
          select p.id, 'gm:' || g.s from oyun.profiller p
            join (select k.parti_id, oyun.m2_gm_seviye_hesap(count(*), (select a.gm_esik from oyun.m2_ayar a where a.id = 1)) s
                    from oyun.m2_gm_katki k group by k.parti_id) g on g.parti_id = p.parti_id
           where g.s > 0
          union all
          select b.user_id, 'bb:' || b.parti_id from oyun.m2_bagisci b join oyun.profiller p on p.id = b.user_id and p.parti_id = b.parti_id
           where b.bitis > oyun.simdi()
          union all
          select user_id, 'yu' from oyun.magaza_hesap where yillik_bitis > oyun.simdi()
          union all
          select z.user_id, 'z:' || replace(z.rozet, ',', ' ') from (select distinct on (user_id) user_id, rozet from oyun.m2_zafer order by user_id, id desc) z
        ) x group by user_id) r
  join oyun.profiller pr on pr.id = r.user_id
  where not pr.yasakli
$$;

-- ============ YÖNETİM PORTALI AYARLARI ============
do $p$
begin
  if to_regclass('oyun.yp_ayar_katalog') is null then return; end if;
  insert into oyun.yp_ayar_katalog(anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, sira, aktif) values
  ('magaza2.vitrin_yer','oyun.m2_ayar','vitrin_yer',null,'ekonomi','Kürsü Vitrini yer sayısı','Kürsü akışının başında aynı anda yayında olabilecek en çok vitrin. Fazlası sıraya girer.','tamsayi','adet',1,10,null,'orta','Sonraki zamanlayıcı turunda.',120,true),
  ('magaza2.vitrin_saat','oyun.m2_ayar','vitrin_saat',null,'ekonomi','Kürsü Vitrini süresi','Bir vitrinin yayında kaldığı süre.','tamsayi','saat',1,168,null,'orta','Yeni yayına girenlerde.',121,true),
  ('magaza2.manset_yer','oyun.m2_ayar','manset_yer',null,'ekonomi','Gündem Manşeti yer sayısı','Haber şeridinin başında aynı anda yayında olabilecek en çok manşet. Fazlası sıraya girer.','tamsayi','adet',1,10,null,'orta','Sonraki zamanlayıcı turunda.',122,true),
  ('magaza2.manset_saat','oyun.m2_ayar','manset_saat',null,'ekonomi','Gündem Manşeti süresi','Bir manşetin yayında kaldığı süre.','tamsayi','saat',1,168,null,'orta','Yeni yayına girenlerde.',123,true),
  ('magaza2.manset_oto_onay_saat','oyun.m2_ayar','manset_oto_onay_saat',null,'ekonomi','Manşet otomatik inceleme süresi','İçerik Masası bu süre içinde karar vermezse manşet süzgeçten geçerse kendiliğinden onaylanır, geçmezse reddedilir.','tamsayi','saat',1,72,null,'orta','Hemen.',124,true),
  ('magaza2.bagis_tutar','oyun.m2_ayar','bagis_tutar',null,'ekonomi','Parti Kasasına Bağış tutarı','Bir Parti Kasasına Bağış satın alımının partiye geçen tutarı.','sayi','₺',0,100000000,null,'orta','Yeni satın alımlarda.',125,true),
  ('magaza2.gm_tutar','oyun.m2_ayar','gm_tutar',null,'ekonomi','Genel Merkez katkı tutarı','Bir Genel Merkez Kampanyası katkısının parti kasasına geçen tutarı.','sayi','₺',0,100000000,null,'orta','Yeni satın alımlarda.',126,true)
  on conflict (anahtar) do nothing;
exception when others then
  raise notice 'magaza2 portal ayarları eklenmedi: %', sqlerrm;
end $p$;

-- ============ YETKİLER ============
do $g$
declare f text;
begin
  foreach f in array array['kursu_vitrin_baslat(bigint)', 'manset_basvur(text, boolean)', 'manset_onay_liste()', 'manset_karar(bigint, boolean, text)',
    'm2_yayin_kaldir(bigint, text)', 'm2_yayin_iptal(bigint)', 'plaka_kaydet(integer, text, text)', 'mazbata_olustur(bigint)', 'mazbatalar(text)',
    'kutlama_uygula(bigint)', 'kutlama_goruldu(bigint)', 'kongre_slogan(text)', 'kongre_paketleri(bigint)', 'hediye_kart_ver(text, text)',
    'parti_kart_ver(text)', 'm2_bekleyen_uygula()', 'genel_merkez(bigint)', 'destekci_duvari(text)', 'm2_genel()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  for f in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'oyun' and p.proname like 'm2\_%' loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $g$;
