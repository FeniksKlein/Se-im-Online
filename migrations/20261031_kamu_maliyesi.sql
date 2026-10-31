-- 2026-10-31 · Kamu Maliyesi 2.0 (gelistirici/sql/158_kamu_maliyesi.sql ile aynı). Canlıya Claude tarafından uygulandı; tekrar çalıştırılabilir (bir kerelik devir anahtarla korunur).
begin;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 158) KAMU MALİYESİ 2.0 (2026-10-31)
--  * Hazine defteri: her Hazine hareketi kalem kalem (gelir / gider /
--    finansman) yazılır; "Diğer" kayıtları çağıran fonksiyondan çözülür.
--  * Gelirler Hazine'ye akar (oyuncu maaşlarından kesilen gelir vergisi
--    artık Hazine'ye gelir), giderler Hazine'den düşer (partilere Hazine
--    yardımı, faiz ve anapara ayrı kalemler).
--  * Türkiye Varlık Fonu: eski hatadan şişen fazla nakit fonda durur;
--    yürütme 30 günde sınırlı tutar çekebilir, fon Hazine'ye temettü öder.
--  * Genel devlet dengesi (Hazine + bakanlık kasaları) → enflasyon,
--    büyüme ve tahvil faizi. Hazine eksiye düşerse açık Merkez Bankası
--    kaynağıyla kapanır (parasallaşma) ve bakanlık ödenekleri kesilir.
--  Kurallar: TASARIM.md bölüm 26.
--  Not: Supabase MCP ile uygulanabilmesi için bu dosyada tablo/satır
--  kaldıran komut yoktur; tetikleyiciler "create or replace" ile kurulur.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.hazine_hareketleri (
  id bigint generated always as identity primary key,
  zaman timestamptz not null default now(),
  onceki numeric not null,
  sonraki numeric not null,
  fark numeric not null,
  tur text not null,
  aciklama text not null,
  kullanici uuid,
  constraint hazine_hareket_denge check (sonraki = onceki + fark)
);
create index if not exists hazine_hareketleri_zaman on oyun.hazine_hareketleri(id desc);
alter table oyun.hazine_hareketleri enable row level security;
alter table oyun.hazine_hareketleri add column if not exists kalem text;
alter table oyun.hazine_hareketleri add column if not exists kaynak text;
create index if not exists hazine_hareketleri_zaman2 on oyun.hazine_hareketleri(zaman);
create index if not exists bakanlik_hareket_zaman on oyun.bakanlik_hareket(zaman);
create index if not exists hesap_hareket_maas_vergi on oyun.hesap_hareket(zaman) where tur = 'maas' and vergi > 0;

-- Bütçe kalemleri (gerçek bütçe sınıflandırmasına benzer)
create table if not exists oyun.hazine_kalem(
  kod      text primary key,
  ad       text not null,
  sinif    text not null check (sinif in ('gelir', 'gider', 'finansman')),
  sira     int  not null default 100,
  aciklama text
);
alter table oyun.hazine_kalem enable row level security;
insert into oyun.hazine_kalem(kod, ad, sinif, sira, aciklama) values
 ('gelir_vergisi',  'Gelir vergisi (ülke geneli)',           'gelir', 10, 'Ülkedeki ücretlilerden alınan gelir vergisi; oran ve asgari ücretle değişir.'),
 ('stopaj',         'Gelir vergisi stopajı (oyuncular)',     'gelir', 11, 'Oyuncuların maaşından kaynakta kesilen vergi, ertesi gece Hazine''ye geçer.'),
 ('dolayli_vergi',  'KDV, ÖTV ve diğer vergiler',            'gelir', 12, 'Tüketim vergileri; büyüme ve fiyat düzeyiyle artar.'),
 ('kurumlar_vergisi','Kurumlar vergisi ve şirket vergileri', 'gelir', 13, 'Şirket kârlarından ve işletme satışlarından alınan vergiler.'),
 ('servet_vergisi', 'Servet vergisi',                         'gelir', 14, 'Kademeli servet vergisinin Hazine payı ve kanuni servet vergisi.'),
 ('emlak_vergisi',  'Kira ve emlak vergileri',                'gelir', 15, 'Kira gelirlerinden alınan vergiler.'),
 ('harc_ucret',     'Harçlar, komisyonlar ve ücretler',       'gelir', 16, 'Tapu harcı, borsa ve SPK ücretleri, ilan ve işlem harçları.'),
 ('ceza',           'Para cezaları ve el koymalar',           'gelir', 17, 'Rekabet, SPK, MASAK cezaları, mahkeme kararları ve müsadereler.'),
 ('icraat_gelir',   'Bakanlık icraatlarından gelir',          'gelir', 18, 'Yatırım zirvesi, bedelli askerlik, varlık barışı gibi gelir getiren icraatlar.'),
 ('vf_getiri',      'Varlık Fonu temettüsü',                  'gelir', 19, 'Türkiye Varlık Fonu''nun Hazine''ye ödediği günlük temettü.'),
 ('bagis',          'Bağışlar',                               'gelir', 20, 'Oyuncuların devlet Hazinesine yaptığı bağışlar.'),
 ('diger_gelir',    'Diğer gelirler',                         'gelir', 29, null),
 ('bakanlik_odenek','Bakanlık ödenekleri (günlük)',           'gider', 30, 'Bütçe kanunundaki paylarla her gece bakanlık kasalarına aktarılan ödenek.'),
 ('ek_odenek',      'Ek ödenek ve merkezi tahsis',            'gider', 31, 'Yürütmenin onayladığı ek ödenekler, tahsisler; bakanlık iadeleri bu kalemden düşer.'),
 ('belediye_payi',  'Belediyelere vergi payı',                'gider', 32, 'Vergi gelirlerinden il belediyelerine aktarılan pay.'),
 ('sosyal',         'Sosyal destek ve ikramiyeler',           'gider', 33, 'Sosyal destek, bayram ikramiyesi, vergi iadesi ve borç affı maliyeti.'),
 ('kalkinma',       'İl kalkınma destekleri',                 'gider', 34, 'Kararnameyle illere verilen kalkınma destekleri.'),
 ('kriz',           'Afet ve kriz harcamaları',               'gider', 35, 'Ülke krizlerinde alınan kararların maliyeti.'),
 ('program',        'Resmî program ve temsil giderleri',      'gider', 36, 'Makam programları, törenler ve resmî ziyaretler.'),
 ('mevzuat',        'Kanuni hibe ve destekler',               'gider', 37, 'Hoş geldin hibesi, aday desteği gibi kanuni ödemeler.'),
 ('parti_yardim',   'Siyasi partilere Hazine yardımı',        'gider', 38, 'Seçimde barajı geçen partilere günlük Hazine yardımı.'),
 ('faiz',           'Faiz giderleri',                         'gider', 39, 'Devlet iç borçlanma senetlerinin faizi.'),
 ('kamu_alim',      'Kamu alımları',                          'gider', 40, 'Devlet müzayede evi alımları gibi doğrudan kamu alımları.'),
 ('diger_gider',    'Diğer giderler',                         'gider', 49, null),
 ('borclanma',      'İç borçlanma (tahvil ihracı)',           'finansman', 60, 'Tahvil satışıyla Hazine''ye giren borç; bütçe geliri sayılmaz.'),
 ('borc_odeme',     'Borç anapara ödemeleri',                 'finansman', 61, 'Tahvillerin anapara geri ödemesi; faiz ayrı gider kalemidir.'),
 ('ozellestirme',   'Özelleştirme',                           'finansman', 62, 'Kamu varlığı satışı; tek seferlik olduğu için bütçe geliri sayılmaz.'),
 ('vf_aktarim',     'Varlık Fonu aktarımları',                'finansman', 63, 'Hazine ile Türkiye Varlık Fonu arasındaki aktarımlar.'),
 ('dibs',           'Devlet tahvili (DİBS) işlemleri',        'finansman', 64, 'Bankaların ve oyuncuların devlet tahvili alım-satımı ve itfası.'),
 ('kamu_banka',     'Kamu bankası işlemleri',                 'finansman', 65, 'Devlet bankası kredi kartı fonlaması ve geri ödemeleri.')
on conflict (kod) do update set ad = excluded.ad, sinif = excluded.sinif, sira = excluded.sira, aciklama = excluded.aciklama;

-- Hazine'yi değiştiren fonksiyon → kalem eşlemesi (giriş/çıkış yönüne göre). pasif: aracı fonksiyon, bir dış çağırana bakılır.
create table if not exists oyun.hazine_kaynak(
  fonk  text primary key,
  giris text,
  cikis text,
  pasif boolean not null default false
);
alter table oyun.hazine_kaynak enable row level security;
insert into oyun.hazine_kaynak(fonk, giris, cikis, pasif) values
 ('etki_uygula', null, null, true),
 ('gunluk_ekonomi', null, null, true),
 ('para_islem', null, null, true),
 ('eko_vergi_tahsil', 'kurumlar_vergisi', 'kurumlar_vergisi', false),
 ('pazar_hesapla', 'kurumlar_vergisi', 'kurumlar_vergisi', false),
 ('ajans_hesapla', 'kurumlar_vergisi', 'kurumlar_vergisi', false),
 ('npc_isletme_tick', 'kurumlar_vergisi', 'kurumlar_vergisi', false),
 ('denge_tick', 'servet_vergisi', 'servet_vergisi', false),
 ('mulk_kira_tahsil', 'emlak_vergisi', 'emlak_vergisi', false),
 ('yatirim_pazar_kira_tahsil', 'emlak_vergisi', 'emlak_vergisi', false),
 ('mulk_tapu_bedel_ode', 'harc_ucret', 'harc_ucret', false),
 ('tg_sirket_devir_kayit_vergi', 'harc_ucret', 'harc_ucret', false),
 ('halka_arz_dagitim_finans', 'harc_ucret', 'harc_ucret', false),
 ('ilan_devret', 'harc_ucret', 'harc_ucret', false),
 ('ilan_ver', 'harc_ucret', 'harc_ucret', false),
 ('ilan_one_cikar', 'harc_ucret', 'harc_ucret', false),
 ('borsa_al', 'harc_ucret', 'harc_ucret', false),
 ('piyasa_emir', 'harc_ucret', 'harc_ucret', false),
 ('cek_ticaret_islem', 'harc_ucret', 'harc_ucret', false),
 ('eko_emlak_islem', 'harc_ucret', 'harc_ucret', false),
 ('eko_islem', 'harc_ucret', 'harc_ucret', false),
 ('eko_ticaret_islem', 'harc_ucret', 'harc_ucret', false),
 ('yatirim_pazar_islem', 'harc_ucret', 'harc_ucret', false),
 ('sirket_as_donustur', 'harc_ucret', 'harc_ucret', false),
 ('meslek_dukkan_ac', 'harc_ucret', 'harc_ucret', false),
 ('muzayede_lot_ac', 'harc_ucret', 'harc_ucret', false),
 ('mz_lot_kapat', 'harc_ucret', 'harc_ucret', false),
 ('parti_finans_emir', 'harc_ucret', 'harc_ucret', false),
 ('adliye_musadere_tahsil', 'ceza', 'ceza', false),
 ('icra_tahsil_et', 'ceza', 'ceza', false),
 ('pkd_kapat', 'ceza', 'ceza', false),
 ('rekabet_tick', 'ceza', 'ceza', false),
 ('spk_sonuclandir', 'ceza', 'ceza', false),
 ('yikici_rekabet_tick', 'ceza', 'ceza', false),
 ('admin_masak_karar', 'ceza', 'ceza', false),
 ('serbest_bagis', 'bagis', 'bagis', false),
 ('icraat_yap', 'icraat_gelir', 'sosyal', false),
 ('bakanlik_tick', 'icraat_gelir', 'diger_gider', false),
 ('borc_affi_uygula', 'sosyal', 'sosyal', false),
 ('ekonomi_kanun_yururluk', 'diger_gelir', 'sosyal', false),
 ('bakanlik_odenek_karar', 'ek_odenek', 'ek_odenek', false),
 ('kamu_butce_dagit', 'ek_odenek', 'ek_odenek', false),
 ('bakanlik_hazineye_iade', 'ek_odenek', 'ek_odenek', false),
 ('kriz_karar_ver', 'kriz', 'kriz', false),
 ('uk_uygula', 'kriz', 'kriz', false),
 ('resmi_program_yap', 'program', 'program', false),
 ('muzayede_eve_sat', 'kamu_alim', 'kamu_alim', false),
 ('mz_gunluk', 'kamu_alim', 'kamu_alim', false),
 ('tahvil_al', 'dibs', 'dibs', false),
 ('tahvil_portfoy', 'dibs', 'dibs', false),
 ('banka_dibs_al', 'dibs', 'dibs', false),
 ('banka_dibs_boz', 'dibs', 'dibs', false),
 ('banka_dibs_tahsil', 'dibs', 'dibs', false),
 ('kart_harca', 'kamu_banka', 'kamu_banka', false),
 ('kart_nakit_avans', 'kamu_banka', 'kamu_banka', false),
 ('kart_ode', 'kamu_banka', 'kamu_banka', false),
 ('kart_pos_iade', 'kamu_banka', 'kamu_banka', false)
on conflict (fonk) do update set giris = excluded.giris, cikis = excluded.cikis, pasif = excluded.pasif;

-- Türkiye Varlık Fonu (milyar ₺)
create table if not exists oyun.varlik_fonu(
  id             int primary key default 1 check (id = 1),
  bakiye         numeric not null default 0,
  getiri_yillik  numeric not null default 0.25,   -- Hazine'ye yıllık temettü (%)
  aktarim_tavan  numeric not null default 60,     -- yürütmenin aktarim_gun içinde çekebileceği en çok tutar
  aktarim_gun    int     not null default 30,
  son_getiri_gun date,
  kurulus        timestamptz
);
alter table oyun.varlik_fonu enable row level security;
insert into oyun.varlik_fonu(id) values (1) on conflict do nothing;

create table if not exists oyun.varlik_fonu_hareket(
  id       bigserial primary key,
  zaman    timestamptz not null,
  tutar    numeric not null,
  bakiye   numeric not null,
  tur      text not null check (tur in ('devir', 'cek', 'yatir', 'temettu')),
  aciklama text not null,
  user_id  uuid
);
create index if not exists varlik_fonu_hareket_zaman on oyun.varlik_fonu_hareket(zaman desc);
alter table oyun.varlik_fonu_hareket enable row level security;

-- Makro ayarlar (tek satır; yönetici SQL ile değiştirebilir, aktif=false ile mali etki kapanır)
create table if not exists oyun.makro_ayar(
  id             int primary key default 1 check (id = 1),
  aktif          boolean not null default true,
  baslangic      timestamptz not null default now(),  -- bu andan önceki günler mali hesaba girmez
  gsyh_baz       numeric not null default 200,        -- günlük GSYH (milyar ₺), fiyat ve reel endeks 1 iken
  reel_endeks    numeric not null default 1,          -- reel büyüme birikimi
  k_acik         numeric not null default 0.9,        -- açığın GSYH'ye oranındaki her puan → enflasyon hedefine +0,9 puan
  k_fazla        numeric not null default 0.4,        -- bütçe fazlasında dezenflasyon katsayısı
  enf_tavan      numeric not null default 25,
  enf_taban      numeric not null default 5,
  k_parasal      numeric not null default 10,         -- Hazine eksideyken (açık/GSYH) × k → enflasyon hedefine
  odenek_kesinti numeric not null default 0.5,        -- Hazine eksideyken günlük bakanlık ödeneği çarpanı
  hedef_gun      int     not null default 90,         -- Hazine'de tutulacak nakit: kaç günlük cari gider
  son_uyari      date
);
alter table oyun.makro_ayar enable row level security;
insert into oyun.makro_ayar(id) values (1) on conflict do nothing;

-- Günlük bütçe gerçekleşmesi ve makro hesap dökümü (gun = bütçe günü, İstanbul saati)
create table if not exists oyun.makro_gunluk(
  gun           date primary key,
  tam           boolean not null default true,
  gelir         numeric not null default 0,
  merkezi_gider numeric not null default 0,
  bakanlik      numeric not null default 0,
  finansman     numeric not null default 0,
  denge         numeric not null default 0,
  denge7        numeric,
  gsyh          numeric,
  acik_orani    numeric,
  enf_hedef     numeric,
  enf_bilesen   jsonb not null default '{}',
  buyume_hedef  numeric,
  buyume_mali   numeric,
  hazine        numeric,
  varlik_fonu   numeric,
  zaman         timestamptz not null default now()
);
alter table oyun.makro_gunluk enable row level security;

-- ---------------------------------------------------------------------
-- 2) HAZİNE DEFTERİ: kalem çözümü, kayıt tetikleyicisi, harcama sınırı
-- ---------------------------------------------------------------------
create or replace function oyun.hazine_kalem_coz(p_fark numeric, p_tanim text default null)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare k text := nullif(current_setting('oyun.hazine_kalem', true), ''); ctx text; f text; ilk text; m oyun.hazine_kaynak;
begin
  if k is null and p_tanim in ('Bakanlığa ek ödenek', 'Merkezi bütçe tahsisi') then k := 'ek_odenek'; end if;
  get diagnostics ctx = pg_context;
  for f in select x[1] from regexp_matches(coalesce(ctx, ''), '(?:PL/pgSQL|SQL) function "?(?:[A-Za-z_0-9]+\.)?([A-Za-z_0-9]+)', 'g') x loop
    continue when f in ('hazine_kalem_coz', 'tg_hazine_hareket', 'tg_hazine_harcama_siniri', 'hazine_kaydet', 'inline_code_block');
    ilk := coalesce(ilk, f);
    exit when k is not null;
    select * into m from oyun.hazine_kaynak where fonk = f;
    if found and not m.pasif then
      k := case when p_fark >= 0 then m.giris else m.cikis end;
    end if;
  end loop;
  if k is null or not exists (select 1 from oyun.hazine_kalem z where z.kod = k) then
    k := case when p_fark >= 0 then 'diger_gelir' else 'diger_gider' end;
  end if;
  return array[k, ilk];
end $$;

create or replace function oyun.tg_hazine_hareket()
returns trigger language plpgsql security definer set search_path = '' as $$
declare tanim text; k text[]; kad text;
begin
  if new.hazine is distinct from old.hazine then
    tanim := nullif(current_setting('oyun.hazine_islem', true), '');
    k := oyun.hazine_kalem_coz(new.hazine - old.hazine, tanim);
    select z.ad into kad from oyun.hazine_kalem z where z.kod = k[1];
    insert into oyun.hazine_hareketleri(onceki, sonraki, fark, tur, aciklama, kullanici, kalem, kaynak)
    values (old.hazine, new.hazine, new.hazine - old.hazine,
            case when new.hazine < old.hazine then 'cikis' else 'giris' end,
            coalesce(tanim, kad, case when new.hazine < old.hazine then 'Diğer Hazine çıkışı' else 'Diğer Hazine girişi' end),
            auth.uid(), k[1], k[2]);
  end if;
  return new;
end $$;
create or replace trigger hazine_hareket_kaydi after update of hazine on oyun.ulke
  for each row execute function oyun.tg_hazine_hareket();

-- Takdire bağlı harcama (kararname, resmî program, fon aktarımı) Hazine'yi eksiye düşüremez.
-- Kanuni ve otomatik ödemeler (ödenek, faiz, belediye payı) düşürebilir: o zaman açık Merkez Bankası kaynağıyla kapanır.
create or replace function oyun.tg_hazine_harcama_siniri()
returns trigger language plpgsql security definer set search_path = '' as $$
declare ctx text;
begin
  if new.hazine < old.hazine and new.hazine < 0 and auth.uid() is not null then
    get diagnostics ctx = pg_context;
    if ctx ~ '(kararname_cikar|resmi_program_yap|varlik_fonu_aktar)\(' then
      raise exception 'Hazine''de yeterli nakit yok: bu harcama % milyar ₺ tutuyor, Hazine''de % milyar ₺ var. Harcamayı küçültün ya da önce kaynak bulun (Varlık Fonu''ndan aktarım, tahvil ihracı, özelleştirme).',
        oyun.bm_sayi(old.hazine - new.hazine, 1), oyun.bm_sayi(greatest(old.hazine, 0), 1);
    end if;
  end if;
  return new;
end $$;
create or replace trigger hazine_harcama_siniri before update of hazine on oyun.ulke
  for each row execute function oyun.tg_hazine_harcama_siniri();

-- Hazine'ye kalemi belli bir hareket yazar (artı: gelir/giriş, eksi: gider/çıkış). Yeni Hazine bakiyesini döner.
create or replace function oyun.hazine_kaydet(p_kalem text, p_tutar numeric, p_aciklama text default null)
returns numeric language plpgsql security definer set search_path = '' as $$
declare ek text := current_setting('oyun.hazine_kalem', true); ea text := current_setting('oyun.hazine_islem', true); y numeric;
begin
  if coalesce(round(p_tutar, 6), 0) = 0 then return (select hazine from oyun.ulke where id = 1); end if;
  perform set_config('oyun.hazine_kalem', coalesce(p_kalem, ''), true);
  perform set_config('oyun.hazine_islem', coalesce(p_aciklama, ''), true);
  update oyun.ulke set hazine = hazine + round(p_tutar, 6) where id = 1 returning hazine into y;
  perform set_config('oyun.hazine_kalem', coalesce(ek, ''), true);
  perform set_config('oyun.hazine_islem', coalesce(ea, ''), true);
  return y;
end $$;

-- Eski kayıtlara kalem (ileriye dönük her kayıt zaten kalemli yazılır)
update oyun.hazine_hareketleri
   set kalem = case when aciklama in ('Bakanlığa ek ödenek', 'Merkezi bütçe tahsisi') then 'ek_odenek'
                    when fark >= 0 then 'diger_gelir' else 'diger_gider' end
 where kalem is null;

-- ---------------------------------------------------------------------
-- 3) GELİR KAYNAKLARI: oyuncu stopajı, Varlık Fonu temettüsü
-- ---------------------------------------------------------------------
-- Bir günün (İstanbul) oyuncu maaşlarından kesilen gelir vergisi, milyar ₺ (oyunun resmî kuruyla)
create or replace function oyun.oyuncu_stopaj(p_gun date)
returns numeric language sql stable security definer set search_path = '' as $$
  select round(coalesce(sum(h.vergi), 0) / greatest(oyun.pazar_tl_milyar(), 1), 6)
    from oyun.hesap_hareket h
   where h.tur = 'maas' and h.vergi > 0
     and h.zaman >= (p_gun::timestamp at time zone 'Europe/Istanbul')
     and h.zaman <  ((p_gun + 1)::timestamp at time zone 'Europe/Istanbul')
$$;

create or replace function oyun.varlik_fonu_getiri(p_gun date)
returns numeric language plpgsql security definer set search_path = '' as $$
declare v oyun.varlik_fonu; x numeric;
begin
  select * into v from oyun.varlik_fonu where id = 1 for update;
  if v.id is null or v.bakiye <= 0 or (v.son_getiri_gun is not null and v.son_getiri_gun >= p_gun) then return 0; end if;
  x := round(v.bakiye * v.getiri_yillik / 36500, 6);
  update oyun.varlik_fonu set son_getiri_gun = p_gun where id = 1;
  if x > 0 then
    insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama)
    values (oyun.simdi(), x, v.bakiye, 'temettu', 'Hazine''ye günlük temettü ödendi (fon varlığı değişmez)');
  end if;
  return x;
end $$;

-- ---------------------------------------------------------------------
-- 4) MAKRO HESAP: genel devlet dengesi → enflasyon / büyüme / faiz
--    Genel devlet = Hazine + bakanlık kasaları. Hazine'den bakanlığa
--    aktarım iki defterde birbirini götürür; geriye bakanlıkların gerçek
--    harcaması kalır. Finansman (borç, özelleştirme, fon) gelir sayılmaz.
-- ---------------------------------------------------------------------
create or replace function oyun.makro_hesap(p_gun date, u oyun.ulke)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare ma oyun.makro_ayar;
        g0 timestamptz := (p_gun::timestamp at time zone 'Europe/Istanbul');
        g1 timestamptz := ((p_gun + 1)::timestamp at time zone 'Europe/Istanbul');
        gl numeric; gd numeric; fn numeric; bk numeric; dn numeric; tam boolean; d7 numeric; gs numeric;
        ao numeric := 0; bs numeric := 0; be numeric := 0; ps numeric := 0;
begin
  select * into ma from oyun.makro_ayar where id = 1;
  tam := g0 >= ma.baslangic;
  select coalesce(sum(h.fark) filter (where k.sinif = 'gelir'), 0),
         coalesce(sum(h.fark) filter (where k.sinif = 'gider'), 0),
         coalesce(sum(h.fark) filter (where k.sinif = 'finansman'), 0)
    into gl, gd, fn
    from oyun.hazine_hareketleri h join oyun.hazine_kalem k on k.kod = h.kalem
   where h.zaman >= g0 and h.zaman < g1;
  select coalesce(sum(b.tutar), 0) into bk from oyun.bakanlik_hareket b where b.zaman >= g0 and b.zaman < g1;
  dn := gl + gd + bk;
  gs := ma.gsyh_baz * coalesce(u.endeks, 1) * coalesce(ma.reel_endeks, 1);
  insert into oyun.makro_gunluk(gun, tam, gelir, merkezi_gider, bakanlik, finansman, denge, gsyh, hazine, varlik_fonu, zaman)
  values (p_gun, tam, round(gl, 4), round(gd, 4), round(bk, 4), round(fn, 4), round(dn, 4), round(gs, 4), round(u.hazine, 3),
          (select round(v.bakiye, 3) from oyun.varlik_fonu v where v.id = 1), oyun.simdi())
  on conflict (gun) do update set tam = excluded.tam, gelir = excluded.gelir, merkezi_gider = excluded.merkezi_gider,
    bakanlik = excluded.bakanlik, finansman = excluded.finansman, denge = excluded.denge, gsyh = excluded.gsyh,
    hazine = excluded.hazine, varlik_fonu = excluded.varlik_fonu, zaman = excluded.zaman;
  select avg(m.denge) into d7 from oyun.makro_gunluk m where m.tam and m.gun > p_gun - 7 and m.gun <= p_gun;
  if ma.aktif then
    if d7 is not null and gs > 0 then ao := round(-d7 / gs * 100, 3); end if;
    bs := case when ao > 0 then least(ma.enf_tavan, ao * ma.k_acik) else greatest(-ma.enf_taban, ao * ma.k_fazla) end;
    be := case when ao > 0 then least(1.5, ao * 0.12) - greatest(0, ao - 8) * 0.15 else greatest(-0.8, ao * 0.05) end;
    if u.hazine < 0 and gs > 0 then
      ps := least(20, -u.hazine / gs * ma.k_parasal);
      be := be - 0.5;
    end if;
  end if;
  update oyun.makro_gunluk set denge7 = round(d7, 4), acik_orani = ao, buyume_mali = round(be, 3) where gun = p_gun;
  return jsonb_build_object('acik_orani', ao, 'mali_baski', round(bs, 3), 'buyume_etki', round(be, 3), 'parasal', round(ps, 3),
                            'gsyh', round(gs, 3), 'denge', round(dn, 4), 'denge7', round(d7, 4));
end $$;

-- Tahvil faizine mali risk primi: açık GSYH'nin %3'ünü aşınca ve Hazine eksideyken artar
create or replace function oyun.mali_risk_primi()
returns numeric language sql stable security definer set search_path = '' as $$
  select round(least(15, greatest(0, coalesce((select m.acik_orani from oyun.makro_gunluk m where m.tam order by m.gun desc limit 1), 0) - 3) * 0.5
         + case when (select u.hazine from oyun.ulke u where u.id = 1) < 0 then 3 else 0 end), 2)
$$;
create or replace function oyun.tahvil_faiz()
returns numeric language sql stable security definer set search_path = '' as $$
  select round(oyun.sinir(8 + enflasyon / 2 + oyun.mali_risk_primi(), 8, 80), 1) from oyun.ulke where id = 1
$$;

-- Hazine nakdi azalınca yürütmeye ve Maliye Bakanı'na bildirim (eksideyse her gün, değilse 3 günde bir)
create or replace function oyun.maliye_uyari(g date, t timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare u oyun.ulke; ma oyun.makro_ayar; gider numeric; yur uuid; mal uuid; metin text;
begin
  select * into u from oyun.ulke where id = 1;
  select * into ma from oyun.makro_ayar where id = 1;
  gider := greatest((oyun.ulke_hesap(u) ->> 'gider')::numeric, 1);
  if u.hazine >= 15 * gider then return; end if;
  if u.hazine >= 0 and ma.son_uyari is not null and ma.son_uyari > g - 3 then return; end if;
  yur := oyun.yurutme_user();
  mal := (select m.user_id from oyun.makamlar m where m.tur = 'bakan' and m.bakanlik = 'maliye' and m.bit is null limit 1);
  metin := case when u.hazine < 0 then
      format('Hazine: kasa eksiye düştü (%s milyar ₺). Açık Merkez Bankası kaynağıyla kapatılıyor; enflasyon hızla yükselir, bakanlık ödenekleri yarıya indi. Harcamaları kısın ya da Varlık Fonu, tahvil veya özelleştirmeyle kaynak bulun.', oyun.bm_sayi(u.hazine, 1))
    else
      format('Hazine: nakit azaldı, kasada %s milyar ₺ var (yaklaşık %s günlük cari gider). Yeni harcamalarda dikkatli olun; bütçe açığı enflasyonu yükseltir.', oyun.bm_sayi(u.hazine, 1), round(u.hazine / gider))
    end;
  if yur is not null then perform oyun.bildir(yur, metin, t); end if;
  if mal is not null and mal is distinct from yur then perform oyun.bildir(mal, metin, t); end if;
  update oyun.makro_ayar set son_uyari = g where id = 1;
end $$;

-- ---------------------------------------------------------------------
-- 5) GÜNLÜK EKONOMİ (07_devlet'teki sürümün yerine): gelirler ve giderler
--    Hazine'ye kalem kalem yazılır; bütçe dengesi makroya bağlanır.
-- ---------------------------------------------------------------------
create or replace function oyun.gunluk_ekonomi(t timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare u oyun.ulke; bugun date := (t at time zone 'Europe/Istanbul')::date; g date; h jsonb; hb numeric; he numeric; hi numeric; hm numeric;
        acik numeric; mk jsonb; mb jsonb; ma oyun.makro_ayar; kes numeric; cari numeric; fazla numeric; x numeric; faiz numeric; anapara numeric;
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
    select * into ma from oyun.makro_ayar where id = 1;
    h := oyun.ulke_hesap(u);
    perform oyun.hazine_kaydet('gelir_vergisi', (h ->> 'gelir_vergisi')::numeric, 'Gelir vergisi (ülke geneli ücretliler)');
    perform oyun.hazine_kaydet('dolayli_vergi', (h ->> 'diger_gelir')::numeric, 'KDV, ÖTV ve diğer vergiler');
    perform oyun.hazine_kaydet('servet_vergisi', (h ->> 'servet')::numeric, 'Servet vergisi (kanuni)');
    perform oyun.hazine_kaydet('stopaj', oyun.oyuncu_stopaj(g - 1), 'Gelir vergisi stopajı: oyuncu maaşları (' || to_char(g - 1, 'DD.MM') || ')');
    perform oyun.hazine_kaydet('vf_getiri', oyun.varlik_fonu_getiri(g), 'Türkiye Varlık Fonu temettüsü');
    kes := case when (select z.hazine from oyun.ulke z where z.id = 1) < 0 then coalesce(ma.odenek_kesinti, 0.5) else 1 end;
    cari := round((h ->> 'cari')::numeric * kes, 6);
    fazla := coalesce(oyun.bakanlik_gunluk_odenek(cari, u.butce), 0);
    perform oyun.hazine_kaydet('bakanlik_odenek', -(cari - fazla),
      case when kes < 1 then 'Bakanlık ödenekleri (Hazine eksideyken kesintili)' else 'Bakanlık ödenekleri (bütçe kanunu payları)' end);
    perform oyun.hazine_kaydet('belediye_payi', -(h ->> 'belediye')::numeric, 'Belediyelere vergi payı');
    perform oyun.hazine_kaydet('sosyal', -(h ->> 'destek')::numeric, 'Sosyal destek ödemeleri');
    perform oyun.hazine_kaydet('mevzuat', -(h ->> 'mevzuat')::numeric, 'Kanuni hibe ve destekler');
    select coalesce(sum(b.anapara / 60.0), 0), coalesce(sum(b.gunluk - b.anapara / 60.0), 0)
      into anapara, faiz from oyun.borclar b where b.kalan_gun > 0;
    perform oyun.hazine_kaydet('faiz', -greatest(faiz, 0), 'İç borç faiz ödemesi');
    perform oyun.hazine_kaydet('borc_odeme', -anapara, 'İç borç anapara ödemesi');
    if u.parti_yardim > 0 then
      select coalesce(sum(round(r.oran * u.parti_yardim)), 0) into x from oyun.parti_yardim_paylari() r;
      perform oyun.hazine_kaydet('parti_yardim', -round(x / greatest(oyun.pazar_tl_milyar(), 1), 6), 'Siyasi partilere Hazine yardımı');
    end if;
    update oyun.ulke set endeks = u.endeks, belediye_payi = u.belediye_payi where id = 1;
    perform oyun.belediye_gunluk(t);
    select * into u from oyun.ulke where id = 1;
    mb := oyun.makro_hesap(g - 1, u);
    mk := oyun.mevzuat_makro();
    hb := 4 - (u.vergi - 20) * 0.15 - greatest(0, u.enflasyon - 30) * 0.03 + (mk ->> 'buyume')::numeric + (mb ->> 'buyume_etki')::numeric;
    u.buyume := u.buyume + (hb - u.buyume) * 0.05;
    acik := greatest(0, u.asgari / u.asgari_ref - 1);
    he := 25 + (u.buyume - 3) * 0.5 + acik * 40 + (u.kidem_primi - 10) * 0.15 + u.destek / 100 + (mk ->> 'enflasyon')::numeric
          + (mb ->> 'mali_baski')::numeric + (mb ->> 'parasal')::numeric;
    u.enflasyon := u.enflasyon + (he - u.enflasyon) * 0.03 + case when u.hazine < 0 then 0.2 else 0 end;
    hi := 12 - u.buyume * 0.8;
    u.issizlik := u.issizlik + (hi - u.issizlik) * 0.05;
    hm := oyun.sinir(50 - (u.enflasyon - 30) * 0.4 - (u.issizlik - 9) * 1.5 + (u.buyume - 3) * 2 - (u.vergi - 20) * 0.6 + (mk ->> 'memnuniyet')::numeric, 5, 95);
    u.memnuniyet := u.memnuniyet + (hm - u.memnuniyet) * 0.08;
    u.buyume := oyun.sinir(u.buyume, -10, 15); u.enflasyon := oyun.sinir(u.enflasyon, 0, 200);
    u.issizlik := oyun.sinir(u.issizlik, 2, 40); u.memnuniyet := oyun.sinir(u.memnuniyet, 0, 100);
    u.endeks := round(u.endeks * (1 + u.enflasyon / 36500), 6);
    u.asgari_ref := round(u.asgari_ref * (1 + (u.enflasyon + greatest(0, u.buyume)) / 36500), 2);
    update oyun.ulke set buyume = u.buyume, enflasyon = u.enflasyon, issizlik = u.issizlik, memnuniyet = u.memnuniyet,
      endeks = u.endeks, asgari_ref = u.asgari_ref where id = 1;
    update oyun.makro_ayar set reel_endeks = round(reel_endeks * (1 + u.buyume / 36500), 8) where id = 1;
    update oyun.makro_gunluk set enf_hedef = round(he, 3), buyume_hedef = round(hb, 3),
      enf_bilesen = jsonb_build_object('taban', 25, 'buyume', round((u.buyume - 3) * 0.5, 3), 'ucret', round(acik * 40, 3),
        'kidem', round((u.kidem_primi - 10) * 0.15, 3), 'destek', round(u.destek / 100, 3), 'mevzuat', round((mk ->> 'enflasyon')::numeric, 3),
        'butce', (mb ->> 'mali_baski')::numeric, 'parasal', (mb ->> 'parasal')::numeric)
     where gun = g - 1;
    perform oyun.maliye_uyari(g, t);
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
-- 6) ÖZET ve RAPOR (herkese açık: gerçek bütçe istatistikleri gibi)
-- ---------------------------------------------------------------------
create or replace function oyun.maliye_ozet()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u oyun.ulke; ma oyun.makro_ayar; t timestamptz := oyun.simdi(); bas timestamptz; gs numeric; son oyun.makro_gunluk;
        bg numeric; bd numeric; bf numeric; bb numeric; s7 record; bugun date;
begin
  select * into u from oyun.ulke where id = 1;
  select * into ma from oyun.makro_ayar where id = 1;
  bugun := (t at time zone 'Europe/Istanbul')::date;
  bas := (bugun::timestamp at time zone 'Europe/Istanbul');
  gs := ma.gsyh_baz * coalesce(u.endeks, 1) * coalesce(ma.reel_endeks, 1);
  select * into son from oyun.makro_gunluk m where m.tam order by m.gun desc limit 1;
  select coalesce(sum(h.fark) filter (where k.sinif = 'gelir'), 0), coalesce(sum(h.fark) filter (where k.sinif = 'gider'), 0),
         coalesce(sum(h.fark) filter (where k.sinif = 'finansman'), 0)
    into bg, bd, bf from oyun.hazine_hareketleri h join oyun.hazine_kalem k on k.kod = h.kalem where h.zaman >= bas;
  select coalesce(sum(b.tutar), 0) into bb from oyun.bakanlik_hareket b where b.zaman >= bas;
  select count(*) n, coalesce(sum(m.gelir), 0) gelir, coalesce(sum(m.merkezi_gider + m.bakanlik), 0) harcama_net,
         coalesce(sum(m.denge), 0) denge, avg(m.denge) ort
    into s7 from oyun.makro_gunluk m where m.tam and m.gun > bugun - 8 and m.gun < bugun;
  return jsonb_build_object(
    'hazine', round(u.hazine, 3),
    'varlik_fonu', (select round(v.bakiye, 1) from oyun.varlik_fonu v where v.id = 1),
    'gsyh_gunluk', round(gs, 2),
    'bugun', jsonb_build_object('gelir', round(bg, 3), 'harcama', round(-(bd + bb), 3), 'denge', round(bg + bd + bb, 3), 'finansman', round(bf, 3),
                                'merkezi_gider', round(bd, 3), 'bakanlik_net', round(bb, 3)),
    'son7', jsonb_build_object('gun', s7.n, 'gelir', round(s7.gelir, 2), 'harcama', round(-s7.harcama_net, 2), 'denge', round(s7.denge, 2),
                               'ortalama', round(s7.ort, 2)),
    'acik_orani', son.acik_orani, 'enf_hedef', son.enf_hedef, 'enf_bilesen', son.enf_bilesen, 'son_gun', son.gun,
    'enflasyon', round(u.enflasyon, 2), 'buyume', round(u.buyume, 2), 'baslangic', ma.baslangic, 'aktif', ma.aktif,
    'k_acik', ma.k_acik, 'k_fazla', ma.k_fazla, 'enf_tavan', ma.enf_tavan, 'enf_taban', ma.enf_taban,
    'gun_gider', round((oyun.ulke_hesap(u) ->> 'gider')::numeric, 3));
end $$;

create or replace function public.butce_raporu(p_gun int default 7)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); n int := least(30, greatest(1, coalesce(p_gun, 7)));
        bas timestamptz; v oyun.varlik_fonu; cek numeric; tr text[] := array['gunluk', 'odenek', 'tahsis', 'iade', 'aktarim', 'tavan'];
begin
  if p.id is null then raise exception 'Giriş gerekli.'; end if;
  bas := (((t at time zone 'Europe/Istanbul')::date - (n - 1))::timestamp at time zone 'Europe/Istanbul');
  select * into v from oyun.varlik_fonu where id = 1;
  select coalesce(sum(h.tutar), 0) into cek from oyun.varlik_fonu_hareket h where h.tur = 'cek' and h.zaman > t - make_interval(days => v.aktarim_gun);
  return jsonb_build_object(
    'simdi', t, 'gun', n, 'bas', bas,
    'ozet', oyun.maliye_ozet(),
    'gelirler', coalesce((select jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', k.ad, 'tutar', round(x.s, 3), 'aciklama', k.aciklama) order by x.s desc)
        from (select h.kalem, sum(h.fark) s from oyun.hazine_hareketleri h where h.zaman >= bas group by h.kalem) x
        join oyun.hazine_kalem k on k.kod = x.kalem where k.sinif = 'gelir' and round(x.s, 3) <> 0), '[]'::jsonb),
    'giderler', coalesce((select jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', k.ad, 'tutar', round(x.s, 3), 'aciklama', k.aciklama) order by x.s)
        from (select h.kalem, sum(h.fark) s from oyun.hazine_hareketleri h where h.zaman >= bas group by h.kalem) x
        join oyun.hazine_kalem k on k.kod = x.kalem where k.sinif = 'gider' and round(x.s, 3) <> 0), '[]'::jsonb),
    'finansman', coalesce((select jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', k.ad, 'tutar', round(x.s, 3), 'aciklama', k.aciklama) order by x.s desc)
        from (select h.kalem, sum(h.fark) s from oyun.hazine_hareketleri h where h.zaman >= bas group by h.kalem) x
        join oyun.hazine_kalem k on k.kod = x.kalem where k.sinif = 'finansman' and round(x.s, 3) <> 0), '[]'::jsonb),
    'bakanlik_harcama', coalesce((select jsonb_agg(jsonb_build_object('tur', x.tur, 'tutar', round(x.s, 3)) order by x.s)
        from (select b.tur, sum(b.tutar) s from oyun.bakanlik_hareket b where b.zaman >= bas and not (b.tur = any(tr)) group by b.tur) x
        where round(x.s, 3) <> 0), '[]'::jsonb),
    'bakanlik_transfer', (select round(coalesce(sum(b.tutar), 0), 3) from oyun.bakanlik_hareket b where b.zaman >= bas and b.tur = any(tr)),
    'bakanlik_kasa', (select round(coalesce(sum(k.kasa), 0), 2) from oyun.bakanlik_kasa k),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('gun', m.gun, 'gelir', round(m.gelir, 2), 'harcama', round(-(m.merkezi_gider + m.bakanlik), 2),
                                     'denge', round(m.denge, 2), 'acik_orani', m.acik_orani, 'enf_hedef', m.enf_hedef, 'hazine', round(m.hazine, 1),
                                     'enflasyon', (select g.enflasyon from oyun.ulke_gecmis g where g.gun = m.gun + 1)) order by m.gun)
        from (select * from oyun.makro_gunluk z where z.tam order by z.gun desc limit 30) m), '[]'::jsonb),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', z.zaman, 'fark', round(z.fark, 3), 'sonraki', round(z.sonraki, 3),
                                     'aciklama', z.aciklama, 'kalem', z.kalem, 'sinif', k.sinif) order by z.id desc)
        from (select * from oyun.hazine_hareketleri y where abs(y.fark) >= 0.0005 order by y.id desc limit 30) z left join oyun.hazine_kalem k on k.kod = z.kalem), '[]'::jsonb),
    'varlik_fonu', jsonb_build_object('bakiye', round(v.bakiye, 1), 'getiri_yillik', v.getiri_yillik, 'gunluk_temettu', round(v.bakiye * v.getiri_yillik / 36500, 3),
        'aktarim_tavan', v.aktarim_tavan, 'aktarim_gun', v.aktarim_gun, 'cekilen', round(cek, 1), 'kalan_hak', round(greatest(0, v.aktarim_tavan - cek), 1),
        'son_islem', (select max(h.zaman) from oyun.varlik_fonu_hareket h where h.tur in ('cek', 'yatir')),
        'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tur', h.tur, 'tutar', round(h.tutar, 3), 'aciklama', h.aciklama) order by h.id desc)
            from (select * from oyun.varlik_fonu_hareket y where y.tur <> 'temettu' order by y.id desc limit 10) h), '[]'::jsonb)),
    'borc', jsonb_build_object('stok', (select round(coalesce(sum(b.gunluk * b.kalan_gun), 0), 2) from oyun.borclar b where b.kalan_gun > 0),
                               'gunluk', (select round(coalesce(sum(b.gunluk), 0), 3) from oyun.borclar b where b.kalan_gun > 0)),
    'faiz', jsonb_build_object('politika', oyun.politika_faizi(), 'tahvil', oyun.tahvil_faiz(), 'risk_primi', oyun.mali_risk_primi()),
    'yetkili', p.id = oyun.yurutme_user(),
    'sistem', case when oyun.hukumet_sistemi() = 1 then 'parlamenter' else 'baskanlik' end);
end $$;

-- ---------------------------------------------------------------------
-- 7) VARLIK FONU AKTARIMI (yürütme kararı, Resmî Gazete'de yayımlanır)
-- ---------------------------------------------------------------------
create or replace function public.varlik_fonu_aktar(p_yon text, p_tutar numeric, p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v oyun.varlik_fonu; x numeric; cek numeric; hz numeric; gr text; b text;
        sistem text := case when oyun.hukumet_sistemi() = 1 then 'Başbakan' else 'Cumhurbaşkanı' end;
begin
  if p.id is null or p.id is distinct from oyun.yurutme_user() then
    raise exception 'Varlık Fonu aktarımına yalnız görevdeki % karar verir.', lower(sistem);
  end if;
  if coalesce(p_yon, '') not in ('cek', 'yatir') then raise exception 'Geçersiz işlem.'; end if;
  x := round(coalesce(p_tutar, 0), 1);
  if x < 1 then raise exception 'Tutar en az 1 milyar ₺ olmalı.'; end if;
  gr := nullif(btrim(coalesce(p_gerekce, '')), '');
  if gr is not null then gr := oyun.metin_temizle(gr, 500); end if;
  perform pg_advisory_xact_lock(920158, 1);
  select * into v from oyun.varlik_fonu where id = 1 for update;
  if exists (select 1 from oyun.varlik_fonu_hareket h where h.tur in ('cek', 'yatir') and h.zaman > t - interval '24 hours') then
    raise exception 'Varlık Fonu aktarımı 24 saatte bir yapılabilir.';
  end if;
  if p_yon = 'cek' then
    select coalesce(sum(h.tutar), 0) into cek from oyun.varlik_fonu_hareket h where h.tur = 'cek' and h.zaman > t - make_interval(days => v.aktarim_gun);
    if cek + x > v.aktarim_tavan then
      raise exception 'Varlık Fonu''ndan % günde en çok % milyar ₺ çekilebilir; kalan hak % milyar ₺.',
        v.aktarim_gun, oyun.bm_sayi(v.aktarim_tavan, 0), oyun.bm_sayi(greatest(0, v.aktarim_tavan - cek), 1);
    end if;
    if v.bakiye < x then raise exception 'Fonda yeterli varlık yok.'; end if;
    update oyun.varlik_fonu set bakiye = bakiye - x where id = 1;
    insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama, user_id)
    values (t, x, v.bakiye - x, 'cek', coalesce(gr, 'Hazine''ye aktarım'), p.id);
    perform oyun.hazine_kaydet('vf_aktarim', x, 'Varlık Fonu''ndan Hazine''ye aktarım');
    b := format('Türkiye Varlık Fonu''ndan Hazine''ye %s Milyar ₺ Aktarılması Hakkında Karar', oyun.bm_sayi(x, 1));
  else
    select u.hazine into hz from oyun.ulke u where u.id = 1;
    if hz < x then raise exception 'Hazine''de yeterli nakit yok (% milyar ₺ var).', oyun.bm_sayi(hz, 1); end if;
    perform oyun.hazine_kaydet('vf_aktarim', -x, 'Hazine''den Varlık Fonu''na aktarım');
    update oyun.varlik_fonu set bakiye = bakiye + x where id = 1;
    insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama, user_id)
    values (t, x, v.bakiye + x, 'yatir', coalesce(gr, 'Bütçe fazlası fona aktarıldı'), p.id);
    b := format('Hazine''den Türkiye Varlık Fonu''na %s Milyar ₺ Aktarılması Hakkında Karar', oyun.bm_sayi(x, 1));
  end if;
  perform oyun.gazete_ekle('kararname', b,
    coalesce(gr || ' ', '') || format('Aktarım finansman işlemidir; bütçe geliri ya da gideri sayılmaz. Fonda kalan varlık %s milyar ₺.',
      oyun.bm_sayi((select f.bakiye from oyun.varlik_fonu f where f.id = 1), 1)), null, t);
  perform oyun.olay('ekonomi', format('%s %s: %s', sistem, p.kad, b), null, p.parti_id, t);
  return public.butce_raporu(7);
end $$;

-- ---------------------------------------------------------------------
-- 8) MEVCUT FONKSİYONLARA KÜÇÜK EKLER (çapa metni bulunarak; tekrar çalışabilir)
-- ---------------------------------------------------------------------
do $yama$
declare d text; eski text;
begin
  -- Kararnamelerin Hazine hareketleri doğru kaleme yazılsın
  d := pg_get_functiondef('public.kararname_cikar(text,text,text,jsonb)'::regprocedure);
  if position('oyun.hazine_kalem' in d) = 0 then
    eski := 'perform oyun.cb_zorunlu(p);';
    if position(eski in d) = 0 then raise exception 'kararname_cikar değişmiş: çapa bulunamadı.'; end if;
    d := replace(d, eski, eski || chr(10) ||
      '  perform set_config(''oyun.hazine_kalem'', case p_tur when ''il_destek'' then ''kalkinma'' when ''odenek'' then ''ek_odenek'' when ''ikramiye'' then ''sosyal'' when ''ozellestirme'' then ''ozellestirme'' when ''tahvil'' then ''borclanma'' else '''' end, true);');
    execute d;
  end if;

  -- Kriz kararı olay metni: maliyet milyar ₺'dir
  d := pg_get_functiondef('public.kriz_karar_ver(bigint,text)'::regprocedure);
  eski := 'Hazine maliyeti %s TL.';
  if position(eski in d) > 0 then
    execute replace(d, eski, 'Hazine maliyeti %s milyar ₺.');
  end if;

  -- Devlet bütçesi masası gerçekleşen bütçeyi de göstersin
  d := pg_get_functiondef('public.yurutme_butce_masasi()'::regprocedure);
  if position('maliye_ozet' in d) = 0 then
    eski := '''hesap'', oyun.ulke_hesap(u),';
    if position(eski in d) = 0 then raise exception 'yurutme_butce_masasi değişmiş: çapa bulunamadı.'; end if;
    execute replace(d, eski, eski || ' ''maliye'', oyun.maliye_ozet(),');
  end if;

  -- Son Hazine hareketleri listelerinde kuruşluk (0,0005 milyar ₺ altı) kayıtları gösterme
  d := pg_get_functiondef('public.yurutme_butce_masasi()'::regprocedure);
  eski := 'from (select * from oyun.hazine_hareketleri order by id desc limit 8) z';
  if position(eski in d) > 0 then
    execute replace(d, eski, 'from (select * from oyun.hazine_hareketleri where abs(fark) >= 0.0005 order by id desc limit 8) z');
  end if;
  d := pg_get_functiondef('public.kamu_butce_panel()'::regprocedure);
  eski := 'from (select * from oyun.hazine_hareketleri order by id desc limit 15) z';
  if position(eski in d) > 0 then
    execute replace(d, eski, 'from (select * from oyun.hazine_hareketleri where abs(fark) >= 0.0005 order by id desc limit 15) z');
  end if;
end $yama$;

-- ---------------------------------------------------------------------
-- 9) YETKİLER
-- ---------------------------------------------------------------------
revoke all on oyun.hazine_kalem, oyun.hazine_kaynak, oyun.varlik_fonu, oyun.varlik_fonu_hareket, oyun.makro_ayar, oyun.makro_gunluk
  from public, anon, authenticated;
revoke all on function oyun.hazine_kalem_coz(numeric, text) from public, anon, authenticated;
revoke all on function oyun.hazine_kaydet(text, numeric, text) from public, anon, authenticated;
revoke all on function oyun.oyuncu_stopaj(date) from public, anon, authenticated;
revoke all on function oyun.varlik_fonu_getiri(date) from public, anon, authenticated;
revoke all on function oyun.makro_hesap(date, oyun.ulke) from public, anon, authenticated;
revoke all on function oyun.maliye_uyari(date, timestamptz) from public, anon, authenticated;
revoke all on function oyun.gunluk_ekonomi(timestamptz) from public, anon, authenticated;
revoke all on function oyun.maliye_ozet() from public, anon, authenticated;
revoke all on function public.butce_raporu(int) from public, anon;
revoke all on function public.varlik_fonu_aktar(text, numeric, text) from public, anon;
grant execute on function public.butce_raporu(int) to authenticated;
grant execute on function public.varlik_fonu_aktar(text, numeric, text) to authenticated;

-- ---------------------------------------------------------------------
-- 10) BİR KERELİK: şişmiş Hazine fazlası Türkiye Varlık Fonu'na devredilir
--     (silinmez; Hazine'de yaklaşık 3 aylık cari bütçe gideri kalır) ve
--     herkese resmî duyuru yapılır. Yeni kurulumda fazla olmadığı için
--     yalnız anahtar işaretlenir.
-- ---------------------------------------------------------------------
do $$
declare t timestamptz := oyun.simdi(); u oyun.ulke; ma oyun.makro_ayar; gider numeric; hedef numeric; fazla numeric; r record; metin text;
begin
  insert into oyun.tek_seferlik(anahtar, zaman) values ('kamu_maliyesi_158_varlik_fonu', t) on conflict do nothing;
  if not found then return; end if;
  update oyun.makro_ayar set baslangic = t where id = 1;
  select * into ma from oyun.makro_ayar where id = 1;
  select * into u from oyun.ulke where id = 1 for update;
  gider := (oyun.ulke_hesap(u) ->> 'gider')::numeric;
  hedef := greatest(500, round(ma.hedef_gun * gider, -2));
  fazla := round(u.hazine - hedef, 3);
  if fazla <= 0 then return; end if;
  perform oyun.yedek_al('kamu_maliyesi_158_varlik_fonu');
  update oyun.varlik_fonu set bakiye = bakiye + fazla, kurulus = coalesce(kurulus, t) where id = 1;
  insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama)
  values (t, fazla, (select v.bakiye from oyun.varlik_fonu v where v.id = 1), 'devir', 'Hazine''deki fazla nakit fona devredildi (Kamu Maliyesi Reformu)');
  perform oyun.hazine_kaydet('vf_aktarim', -fazla, 'Fazla nakit Türkiye Varlık Fonu''na devredildi (tek seferlik reform)');

  metin := format('Kamu Maliyesi Reformu yürürlükte. Hazine''de biriken %s milyar ₺ fazla nakit silinmedi; Türkiye Varlık Fonu''na devredildi. Hazine''de yaklaşık %s günlük cari bütçe gideri kadar, %s milyar ₺ nakit kaldı. Bundan sonra her ödenek, kararname ve bakanlık harcaması Hazine''den açıkça düşer; vergiler ve harçlar Hazine''ye girer. Gelirden fazla harcanırsa bütçe açığı enflasyonu ve faizi yükseltir, bütçe fazlası enflasyonu düşürür. Hazine eksiye düşerse açık Merkez Bankası kaynağıyla kapanır ve enflasyon hızlanır. Ayrıntılar: Devlet › Hükümet › Bütçe ve ekonomi.',
    oyun.bm_sayi(fazla, 0), ma.hedef_gun, oyun.bm_sayi(hedef, 0));
  perform oyun.gazete_ekle('duyuru', 'Kamu Maliyesi Reformu: Hazine defteri, Türkiye Varlık Fonu ve bütçe disiplini', metin
    || ' Varlık Fonu Hazine''ye günlük temettü öder; yürütme fondan 30 günde en çok 60 milyar ₺ çekebilir. Takdire bağlı harcamalar (kararname, resmî program) Hazine''yi eksiye düşüremez.', null, t);
  perform oyun.olay('ekonomi', format('Kamu Maliyesi Reformu: %s milyar ₺ fazla nakit Türkiye Varlık Fonu''na devredildi; Hazine''de %s milyar ₺ kaldı. Bütçe açığı artık enflasyonu etkiliyor.',
    oyun.bm_sayi(fazla, 0), oyun.bm_sayi(hedef, 0)), null, null, t);
  for r in select p.id from oyun.profiller p where not p.yasakli and p.son_gorulme > t - interval '7 days' loop
    perform oyun.bildir(r.id, metin, t);
  end loop;
end $$;
commit;
