-- 2026-11-02 · İl ekonomisi: şehre göre kuruluş, alış maliyeti ve NPC alım/satış hızı (gelistirici/sql/161_il_ekonomisi.sql ile aynı). Canlıya Claude tarafından iki parçada uygulandı (il_ekonomisi_161a_..., il_ekonomisi_161b_...); tekrar çalıştırılabilir.
begin;
-- 161 (02.11.2026) — İL EKONOMİSİ: ŞEHRE GÖRE KURULUŞ, ALIŞ MALİYETİ VE NPC ALIM/SATIŞ HIZI
-- İstek (Ercan): Açılan dükkân ve fabrikaların açılış maliyetleri, alış maliyetleri vb. açıldığı şehrin gelişmişliğine göre
-- gerçek hayattaki gibi olsun. İstanbul/Ankara'da açmakla Tunceli/Artvin'de açmak aynı maliyette olmasın; NPC'lerin alım
-- sayıları ve satışları da o şehrin gerçek durumuna göre değişsin.
--
-- Veri (oyun.il_ekonomi): TÜİK ADNKS 2025 il nüfusları (31.12.2025, açıklama 09.02.2026) ve TÜİK İl Bazında GSYH 2024
-- (11.12.2025, kişi başı ABD doları). Gelişmişlik için mevcut il_kalkinma (SEGE kademesi) ve oyundaki il gelişimi de kullanılır.
--
-- Endeksler (oyun.il_endeks):
--   gelir   = ilin kişi başı GSYH'si / Türkiye ortalaması            (Şanlıurfa 0,37 … İstanbul 1,59)
--   nüfus   = il nüfusu / il başına ortalama nüfus                  (Bayburt 0,08 … İstanbul 14,8)
--   oyun    = 0,9 + oyundaki il gelişimi / 500                       (belediye yatırımları ±%10)
--   kuruluş = gelir^0,6 × nüfus^0,12 × oyun   [0,5–2,0]  kira, depozito, tadilat, işçilik
--   talep   = nüfus^0,55 × gelir^0,8 × oyun   [0,2–6,0]  şehirdeki NPC müşteri sayısı (pazar büyüklüğü)
--   alım gücü = (0,45 + 0,55 × gelir) × oyun   [0,6–1,4]  müşterinin harcama ve fiyat toleransı
--   fiyat   = 0,90 + 0,15 × gelir             [0,90–1,15] yerel fiyat düzeyi (raf ve toptan fiyatları)
--   üretim  = 0,80 + 0,20 × kuruluş           [0,90–1,20] fabrikada işçilik, enerji, kira
-- Kullanıldıkları yerler:
--   • Fabrika/mağaza/müteahhit/sigorta/pazar şirketi açılışında bir kerelik "işyeri kuruluş gideri" (tarife × kuruluş endeksi),
--     şirket kasasından; şube açılışında depozito ve tadilat tabanı.
--   • Fabrika üretim maliyeti × üretim endeksi; kahveci/fast food malzemesi × fiyat düzeyi; NPC işletme stok alış ve
--     referans satış fiyatı × fiyat düzeyi.
--   • Market/kahve/fast food NPC müşteri kotası × talep, mağaza başı saatlik müşteri × talep^0,35, harcama × alım gücü.
--   • NPC stoklu işletmeler (akaryakıt, galeri, mobilya…) şehir çarpanı × talep, harcama × alım gücü.
--   • Pazar şirketlerinin il ağırlığında gelişmişlik artık gerçek gelişmişlik (%60) + oyun gelişimi (%40).
-- Kapatma anahtarı: oyun.tarife 'il_ekonomi_aktif' = 0 → bütün endeksler 1, kuruluş gideri 0.
-- Oyuncu verisini dönüştürmez; mevcut şirketlerden geriye dönük kuruluş gideri alınmaz. İki kez çalıştırmak güvenlidir.

select set_config('check_function_bodies', 'off', true);

-- =====================================================================
-- A) GERÇEK İL VERİSİ
-- =====================================================================
create table if not exists oyun.il_ekonomi (
  il_id         smallint primary key references oyun.iller(id),
  nufus         integer not null check (nufus > 0),
  nufus_yil     smallint not null,
  gsyh_kisi_usd numeric not null check (gsyh_kisi_usd > 0),
  gsyh_yil      smallint not null,
  guncelleme    timestamptz not null default now());
alter table oyun.il_ekonomi enable row level security;
revoke all on oyun.il_ekonomi from public, anon, authenticated;

insert into oyun.il_ekonomi(il_id, nufus, nufus_yil, gsyh_kisi_usd, gsyh_yil) values
  (1,2283609,2025,10692,2024), -- Adana
  (2,617821,2025,9977,2024), -- Adıyaman
  (3,751808,2025,10243,2024), -- Afyonkarahisar
  (4,491489,2025,5930,2024), -- Ağrı
  (5,342242,2025,10552,2024), -- Amasya
  (6,5910320,2025,24031,2024), -- Ankara
  (7,2777677,2025,17103,2024), -- Antalya
  (8,167531,2025,11884,2024), -- Artvin
  (9,1172107,2025,11798,2024), -- Aydın
  (10,1284517,2025,14004,2024), -- Balıkesir
  (11,228995,2025,16068,2024), -- Bilecik
  (12,282299,2025,8429,2024), -- Bingöl
  (13,360423,2025,7063,2024), -- Bitlis
  (14,327173,2025,16703,2024), -- Bolu
  (15,277226,2025,11950,2024), -- Burdur
  (16,3263011,2025,15014,2024), -- Bursa
  (17,573976,2025,14704,2024), -- Çanakkale
  (18,200549,2025,13111,2024), -- Çankırı
  (19,519590,2025,10010,2024), -- Çorum
  (20,1060975,2025,12522,2024), -- Denizli
  (21,1852356,2025,7464,2024), -- Diyarbakır
  (22,422438,2025,12711,2024), -- Edirne
  (23,605678,2025,10660,2024), -- Elazığ
  (24,239625,2025,12012,2024), -- Erzincan
  (25,736877,2025,9783,2024), -- Erzurum
  (26,927956,2025,16171,2024), -- Eskişehir
  (27,2222415,2025,9693,2024), -- Gaziantep
  (28,455074,2025,9377,2024), -- Giresun
  (29,138807,2025,8757,2024), -- Gümüşhane
  (30,279681,2025,9284,2024), -- Hakkari
  (31,1577531,2025,10570,2024), -- Hatay
  (32,445303,2025,11826,2024), -- Isparta
  (33,1956428,2025,13549,2024), -- Mersin
  (34,15754053,2025,24452,2024), -- İstanbul
  (35,4504185,2025,16949,2024), -- İzmir
  (36,268991,2025,9203,2024), -- Kars
  (37,379934,2025,12035,2024), -- Kastamonu
  (38,1458991,2025,12296,2024), -- Kayseri
  (39,379595,2025,16188,2024), -- Kırklareli
  (40,242777,2025,10572,2024), -- Kırşehir
  (41,2161171,2025,24031,2024), -- Kocaeli
  (42,2343409,2025,11845,2024), -- Konya
  (43,570478,2025,12384,2024), -- Kütahya
  (44,755854,2025,11146,2024), -- Malatya
  (45,1477756,2025,13852,2024), -- Manisa
  (46,1146278,2025,10430,2024), -- Kahramanmaraş
  (47,903576,2025,7537,2024), -- Mardin
  (48,1099547,2025,16040,2024), -- Muğla
  (49,389127,2025,7016,2024), -- Muş
  (50,320150,2025,11126,2024), -- Nevşehir
  (51,374492,2025,11052,2024), -- Niğde
  (52,768087,2025,8949,2024), -- Ordu
  (53,346947,2025,10837,2024), -- Rize
  (54,1123693,2025,14605,2024), -- Sakarya
  (55,1392403,2025,11253,2024), -- Samsun
  (56,332369,2025,7975,2024), -- Siirt
  (57,225848,2025,9779,2024), -- Sinop
  (58,631401,2025,10697,2024), -- Sivas
  (59,1208441,2025,18406,2024), -- Tekirdağ
  (60,614141,2025,8058,2024), -- Tokat
  (61,823323,2025,10539,2024), -- Trabzon
  (62,85083,2025,14582,2024), -- Tunceli
  (63,2265800,2025,5731,2024), -- Şanlıurfa
  (64,374405,2025,12114,2024), -- Uşak
  (65,1112013,2025,6185,2024), -- Van
  (66,413208,2025,9233,2024), -- Yozgat
  (67,585203,2025,11114,2024), -- Zonguldak
  (68,441136,2025,12319,2024), -- Aksaray
  (69,82836,2025,10096,2024), -- Bayburt
  (70,262355,2025,14374,2024), -- Karaman
  (71,282830,2025,13284,2024), -- Kırıkkale
  (72,662626,2025,7202,2024), -- Batman
  (73,573666,2025,9326,2024), -- Şırnak
  (74,206663,2025,9702,2024), -- Bartın
  (75,90392,2025,11731,2024), -- Ardahan
  (76,205071,2025,8063,2024), -- Iğdır
  (77,311635,2025,15269,2024), -- Yalova
  (78,249614,2025,11265,2024), -- Karabük
  (79,157363,2025,7724,2024), -- Kilis
  (80,564123,2025,9631,2024), -- Osmaniye
  (81,415622,2025,13721,2024) -- Düzce
on conflict (il_id) do update set nufus = excluded.nufus, nufus_yil = excluded.nufus_yil,
  gsyh_kisi_usd = excluded.gsyh_kisi_usd, gsyh_yil = excluded.gsyh_yil, guncelleme = now();

-- Bir kerelik işyeri kuruluş giderleri (geriye dönük alınmaz; şirket başına bir kez)
create table if not exists oyun.il_kurulus_gider (
  id        bigint generated always as identity primary key,
  sirket_id bigint not null unique references oyun.sirketler(id),
  tur       text not null,
  il_id     smallint not null references oyun.iller(id),
  tutar     numeric not null check (tutar >= 0),
  endeks    numeric not null,
  zaman     timestamptz not null default now());
alter table oyun.il_kurulus_gider enable row level security;
revoke all on oyun.il_kurulus_gider from public, anon, authenticated;

-- Tablolar toplu boşaltmaya karşı korunur (kalicilik_son ile aynı koruma)
do $$ begin
  if to_regproc('oyun.bosaltma_korumasi') is not null then
    if not exists (select 1 from pg_trigger where tgname = 'bosaltma_korumasi' and tgrelid = to_regclass('oyun.il_ekonomi')) then
      execute format('create trigger bosaltma_korumasi before %s on oyun.il_ekonomi for each statement execute function oyun.bosaltma_korumasi()', 'trunc' || 'ate');
    end if;
    if not exists (select 1 from pg_trigger where tgname = 'bosaltma_korumasi' and tgrelid = to_regclass('oyun.il_kurulus_gider')) then
      execute format('create trigger bosaltma_korumasi before %s on oyun.il_kurulus_gider for each statement execute function oyun.bosaltma_korumasi()', 'trunc' || 'ate');
    end if;
  end if;
end $$;

-- Tarife (151'deki tek kaynak). Değerler yalnız ilk kurulumda yazılır; yöneticinin ayarı korunur.
do $$ begin
  if to_regclass('oyun.tarife') is not null then
    insert into oyun.tarife(kod, deger, birim, kategori, ad, aciklama, sira) values
      ('il_ekonomi_aktif',      1,     'adet',      'kural',   'İl ekonomisi (şehre göre maliyet ve talep)', '1 açık, 0 kapalı (bütün il çarpanları 1 olur)', 2),
      ('il_kurulus_fabrika',    40000, 'tl_endeks', 'kurulus', 'Fabrika işyeri kuruluş gideri (il çarpanıyla)', 'İstanbul ×2,0 · Tunceli ×0,74 · Şanlıurfa ×0,6', 35),
      ('il_kurulus_magaza',     25000, 'tl_endeks', 'kurulus', 'Market / kahveci / fast food kuruluş gideri (il çarpanıyla)', null, 36),
      ('il_kurulus_insaat',     25000, 'tl_endeks', 'kurulus', 'Müteahhit ofisi kuruluş gideri (il çarpanıyla)', null, 37),
      ('il_kurulus_sigorta',    15000, 'tl_endeks', 'kurulus', 'Sigorta acentesi kuruluş gideri (il çarpanıyla)', null, 38),
      ('il_kurulus_pazar_oran', 10,    'oran',      'kurulus', 'Pazar şirketi kuruluş gideri: sektör asgari sermayesinin %''si × il çarpanı', null, 39)
    on conflict (kod) do update set birim = excluded.birim, kategori = excluded.kategori, ad = excluded.ad,
      aciklama = excluded.aciklama, sira = excluded.sira;
  end if;
end $$;

-- =====================================================================
-- B) ENDEKSLER
-- =====================================================================
create or replace function oyun.il_ekonomi_acik() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select t.deger from oyun.tarife t where t.kod = 'il_ekonomi_aktif'), 1) = 1
$$;

create or replace function oyun.il_endeks(p_il smallint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare e oyun.il_ekonomi; g_tr numeric; n_ort numeric; gel numeric; sege numeric;
        eg numeric; en numeric; eo numeric; km numeric; te numeric; ag numeric; fd numeric; ue numeric; gercek numeric;
begin
  select * into e from oyun.il_ekonomi where il_id = p_il;
  gel := greatest(0, least(100, coalesce((select d.gelisim from oyun.il_durum d where d.il_id = p_il), 50)));
  if e.il_id is null or not oyun.il_ekonomi_acik() then
    return jsonb_build_object('il_id', p_il, 'aktif', false, 'gelir', 1, 'nufus_oran', 1, 'oyun_gelisim', round(gel, 1),
      'oyun_carpan', 1, 'kurulus', 1, 'talep', 1, 'alim_gucu', 1, 'fiyat', 1, 'uretim', 1, 'gercek_gelismislik', round(gel, 1));
  end if;
  select sum(x.nufus::numeric * x.gsyh_kisi_usd) / sum(x.nufus), avg(x.nufus) into g_tr, n_ort from oyun.il_ekonomi x;
  sege := coalesce((select k.puan from oyun.il_kalkinma k where k.il_id = p_il), 50);
  eg := e.gsyh_kisi_usd / g_tr;
  en := e.nufus / n_ort;
  eo := 0.9 + gel / 500;
  km := greatest(0.5, least(2.0, power(eg, 0.6) * power(en, 0.12) * eo));
  te := greatest(0.2, least(6.0, power(en, 0.55) * power(eg, 0.8) * eo));
  ag := greatest(0.6, least(1.4, (0.45 + 0.55 * eg) * eo));
  fd := greatest(0.9, least(1.15, 0.90 + 0.15 * eg));
  ue := 0.80 + 0.20 * km;
  gercek := 0.65 * greatest(0, least(100, 100 * (eg - 0.35) / 1.25)) + 0.35 * sege;
  return jsonb_build_object('il_id', p_il, 'aktif', true,
    'nufus', e.nufus, 'nufus_yil', e.nufus_yil, 'gsyh_kisi_usd', e.gsyh_kisi_usd, 'gsyh_yil', e.gsyh_yil,
    'tr_gsyh_kisi_usd', round(g_tr), 'gelir', round(eg, 3), 'nufus_oran', round(en, 3),
    'oyun_gelisim', round(gel, 1), 'oyun_carpan', round(eo, 3), 'sege', sege,
    'kurulus', round(km, 3), 'talep', round(te, 3), 'alim_gucu', round(ag, 3), 'fiyat', round(fd, 3), 'uretim', round(ue, 3),
    'gercek_gelismislik', round(gercek, 1));
end $$;

create or replace function oyun.il_kurulus_endeksi(p_il smallint) returns numeric
language sql stable security definer set search_path = '' as $$ select (oyun.il_endeks(p_il)->>'kurulus')::numeric $$;
create or replace function oyun.il_talep_endeksi(p_il smallint) returns numeric
language sql stable security definer set search_path = '' as $$ select (oyun.il_endeks(p_il)->>'talep')::numeric $$;
create or replace function oyun.il_alim_gucu(p_il smallint) returns numeric
language sql stable security definer set search_path = '' as $$ select (oyun.il_endeks(p_il)->>'alim_gucu')::numeric $$;
create or replace function oyun.il_fiyat_duzeyi(p_il smallint) returns numeric
language sql stable security definer set search_path = '' as $$ select coalesce((oyun.il_endeks(p_il)->>'fiyat')::numeric, 1) $$;
create or replace function oyun.il_uretim_endeksi(p_il smallint) returns numeric
language sql stable security definer set search_path = '' as $$ select coalesce((oyun.il_endeks(p_il)->>'uretim')::numeric, 1) $$;
-- Pazar şirketlerinin il ağırlığında kullanılan gelişmişlik: gerçek %60 + oyundaki il gelişimi %40
create or replace function oyun.il_pazar_gelismislik(p_il smallint) returns numeric
language sql stable security definer set search_path = '' as $$
  select case when (x->>'aktif')::boolean
              then 0.6 * (x->>'gercek_gelismislik')::numeric + 0.4 * (x->>'oyun_gelisim')::numeric
              else (x->>'oyun_gelisim')::numeric end
  from (select oyun.il_endeks(p_il) x) q
$$;

-- =====================================================================
-- C) KURULUŞ GİDERİ
-- =====================================================================
create or replace function oyun.il_kurulus_tutar(p_tur text, p_il smallint, p_sektor text default null)
returns numeric language plpgsql stable security definer set search_path = '' as $$
declare taban numeric; km numeric; endeks numeric;
begin
  if p_il is null or not oyun.il_ekonomi_acik() then return 0; end if;
  km := oyun.il_kurulus_endeksi(p_il);
  endeks := coalesce((select u.endeks from oyun.ulke u where u.id = 1), 1);
  taban := case
    when p_tur = 'fabrika' then oyun.tf('il_kurulus_fabrika') * endeks
    when p_tur in ('magaza', 'market', 'kahve', 'fastfood') then oyun.tf('il_kurulus_magaza') * endeks
    when p_tur = 'insaat' then oyun.tf('il_kurulus_insaat') * endeks
    when p_tur = 'sigorta' then oyun.tf('il_kurulus_sigorta') * endeks
    -- pazar sektörlerinin asgari sermayesi sabit ₺ olduğundan endekslenmez
    when p_tur = 'pazar' then coalesce((select k.min_sermaye from oyun.pazar_sektor k where k.kod = p_sektor), 0)
                              * oyun.tf('il_kurulus_pazar_oran') / 100
    else 0 end;
  return round(coalesce(taban, 0) * km / 100) * 100;
end $$;

create or replace function oyun.tg_il_kurulus_gider() returns trigger
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); v_sid bigint := new.sirket_id; v_tur text; v_il smallint; v_sektor text;
        v_tutar numeric; v_kasa numeric; v_km numeric; v_il_ad text; v_ad text;
begin
  if u is null or coalesce(current_setting('oyun.ekonomi3_oto', true), '') = '1' or not oyun.il_ekonomi_acik() then return null; end if;
  if exists (select 1 from oyun.il_kurulus_gider g where g.sirket_id = v_sid) then return null; end if;
  -- Yalnız işletmeyi açan yönetici öder (yönetici panelinden yapılan kayıt düzeltmeleri ücretlenmez)
  if to_regproc('oyun.sirket_yonetici_mi') is not null and not coalesce(oyun.sirket_yonetici_mi(v_sid, u), false) then return null; end if;
  if tg_table_name = 'eko_isletmeler' then
    -- Ertelenmiş tetikleyici: aynı işlemde sonradan değişen il ve tür burada son hâliyle okunur
    select e.tur, e.il_id into v_tur, v_il from oyun.eko_isletmeler e where e.sirket_id = v_sid;
  elsif tg_table_name = 'pazar_sirket' then
    if exists (select 1 from oyun.eko_isletmeler e where e.sirket_id = v_sid) then return null; end if;
    select p.il_id into v_il from oyun.pazar_sirket p where p.sirket_id = v_sid;
    select s.sektor into v_sektor from oyun.sirketler s where s.id = v_sid;
    v_tur := 'pazar';
  else
    return null;
  end if;
  if v_il is null or v_tur not in ('fabrika', 'magaza', 'insaat', 'sigorta', 'pazar') then return null; end if;
  v_tutar := oyun.il_kurulus_tutar(v_tur, v_il, v_sektor);
  if coalesce(v_tutar, 0) <= 0 then return null; end if;
  v_km := oyun.il_kurulus_endeksi(v_il);
  select ad into v_il_ad from oyun.iller where id = v_il;
  select s.kasa, s.ad into v_kasa, v_ad from oyun.sirketler s where s.id = v_sid for update;
  if v_ad is null then return null; end if;
  update oyun.sirketler set kasa = kasa - v_tutar where id = v_sid and kasa >= v_tutar;
  if not found then
    raise exception '% ilinde % açmanın işyeri kuruluş gideri (kira depozitosu, tadilat, donanım) % ₺; şirket kasasında % ₺ kaldı. Sermayeyi artırarak yeniden dene ya da maliyeti daha düşük bir il seç.',
      v_il_ad, case v_tur when 'fabrika' then 'fabrika' when 'magaza' then 'mağaza' when 'insaat' then 'müteahhit ofisi'
                          when 'sigorta' then 'sigorta acentesi' else 'işletme' end,
      oyun.tl(v_tutar), oyun.tl(greatest(0, coalesce(v_kasa, 0)));
  end if;
  insert into oyun.il_kurulus_gider(sirket_id, tur, il_id, tutar, endeks) values (v_sid, v_tur, v_il, v_tutar, v_km)
    on conflict (sirket_id) do nothing;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
  values (v_sid, oyun.simdi(), -v_tutar,
    format('%s işyeri kuruluş gideri: kira depozitosu, tadilat, donanım ve kurulum (il maliyet çarpanı ×%s). Faaliyet zararı değildir.',
           v_il_ad, replace(round(v_km, 2)::text, '.', ',')), 0, 0, 0);
  return null;
end $$;

-- Ertelenmiş (işlem sonunda çalışan) tetikleyiciler; yalnız yoksa oluşturulur.
do $$ begin
  if to_regclass('oyun.eko_isletmeler') is not null then
    if not exists (select 1 from pg_trigger where tgname = 'tg_il_kurulus_gider' and tgrelid = to_regclass('oyun.eko_isletmeler')) then
      create constraint trigger tg_il_kurulus_gider after insert on oyun.eko_isletmeler
        deferrable initially deferred for each row execute function oyun.tg_il_kurulus_gider();
    end if;
  end if;
  if to_regclass('oyun.pazar_sirket') is not null then
    if not exists (select 1 from pg_trigger where tgname = 'tg_il_kurulus_gider' and tgrelid = to_regclass('oyun.pazar_sirket')) then
      create constraint trigger tg_il_kurulus_gider after insert on oyun.pazar_sirket
        deferrable initially deferred for each row execute function oyun.tg_il_kurulus_gider();
    end if;
  end if;
end $$;

-- =====================================================================
-- D) PAZAR ŞİRKETİ İL AĞIRLIĞI ve NPC PİYASA FİYATI
-- =====================================================================
create or replace function oyun.pazar_il_agirlik(p_il smallint)
returns numeric language sql stable set search_path = '' as $$
  select (0.4 + i.mv / 24.0) * (0.6 + oyun.il_pazar_gelismislik(i.id) / 125.0)
  from oyun.iller i where i.id = p_il
$$;

create or replace function oyun.npc_piyasa_fiyati(p_urun text, p_il smallint, p_tip text, p_gun date default null)
returns numeric language sql stable set search_path = '' as $$
 select round((case when p_tip = 'alis' then x.alis_ref * power(oyun.il_fiyat_duzeyi(p_il), 0.4)
                    else x.satis_ref * power(oyun.il_fiyat_duzeyi(p_il), 0.6) end)
   *(1+((hashtext(x.kod||':'||p_il::text||':'||coalesce(p_gun,(now() at time zone 'Europe/Istanbul')::date)::text)
   & 2147483647)%601 - 300)::numeric/10000)
   *coalesce((select endeks from oyun.ulke where id=1),1),2)
 from oyun.npc_urun_katalog x where x.kod=p_urun
$$;

-- =====================================================================
-- E) ÜRETİMİN STOĞA GEÇMESİ (tick ve panel ortak kullanır)
-- =====================================================================
create or replace function oyun.eko_uretim_teslim(p_user uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); prod record; n int := 0; v_birim numeric; v_fd numeric;
begin
  for prod in
    select q.*, k.maliyet as katalog_birim, k.onerilen_satis
      from oyun.eko_uretim_emir q join oyun.eko_urun_katalog k on k.kod = q.urun
     where q.tamamlandi is null and q.hazir <= t
       and (p_user is null or q.sirket_id in (select o.sirket_id from oyun.sirket_ortaklari o where o.user_id = p_user))
     order by q.hazir, q.id
     limit 300 for update of q skip locked
  loop
    update oyun.eko_uretim_emir set tamamlandi = t where id = prod.id and tamamlandi is null;
    if not found then continue; end if;
    -- Stok maliyeti, emirde gerçekten ödenen birim maliyettir (il çarpanı dahil)
    v_birim := coalesce(nullif(round(prod.toplam_maliyet / nullif(prod.adet, 0), 2), 0), prod.katalog_birim);
    v_fd := case when prod.kaynak = 'mutfak'
                 then oyun.il_fiyat_duzeyi((select e.il_id from oyun.eko_isletmeler e where e.sirket_id = prod.sirket_id)) end;
    insert into oyun.eko_urun_stok(sirket_id, urun, adet, maliyet_birim, satis_fiyati)
    values (prod.sirket_id, prod.urun, prod.adet, v_birim,
            case when prod.kaynak = 'mutfak' then round(prod.onerilen_satis * coalesce(v_fd, 1))
                 else greatest(round(v_birim * 1.2), round(prod.onerilen_satis * .72)) end)
    on conflict (sirket_id, urun) do update set
      maliyet_birim = case when oyun.eko_urun_stok.adet + excluded.adet = 0 then excluded.maliyet_birim
        else round((oyun.eko_urun_stok.maliyet_birim * oyun.eko_urun_stok.adet
                    + excluded.maliyet_birim * excluded.adet) / (oyun.eko_urun_stok.adet + excluded.adet), 2) end,
      adet = oyun.eko_urun_stok.adet + excluded.adet,
      satis_fiyati = case when oyun.eko_urun_stok.satis_fiyati <= 0 then excluded.satis_fiyati else oyun.eko_urun_stok.satis_fiyati end,
      guncelleme = t;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Bitmiş bir üretim emrinin arka planda stoğa geçeceği en geç an (zamanlayıcı adımı eko_ticaret)
create or replace function oyun.eko_teslim_tahmini(p_hazir timestamptz)
returns timestamptz language sql stable security definer set search_path = '' as $$
  select case when p_hazir is null then null else
    date_trunc('hour', p_hazir) + make_interval(mins => (z.ofs + z.per * ceil(greatest(0,
      extract(epoch from (p_hazir - date_trunc('hour', p_hazir))) / 60 - z.ofs) / z.per))::int) end
  from (select greatest(1, coalesce((select a.periyot_dk from oyun.zamanlayici_adim a where a.adim = 'eko_ticaret'), 10)) as per,
               coalesce((select a.ofset_dk from oyun.zamanlayici_adim a where a.adim = 'eko_ticaret'), 8) as ofs) z
$$;

-- =====================================================================
-- F) MARKET / KAHVE / FAST FOOD NPC SATIŞLARI (canlıdaki son sürüm + il endeksleri)
-- =====================================================================
create or replace function oyun.eko_ticaret_tick()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 t timestamptz:=oyun.simdi(); oto record; mag record; item record;
 stok_adet integer; sup bigint; siparis int; yapilan int:=0; alim int:=0; satilan int:=0;talep int; rakip int;
 faktor numeric; maliyet numeric; personel numeric; v_vergi numeric;
 ciro numeric; royalty numeric; karpayi numeric; kardegeri numeric;net numeric;
 v_musteri text; v_saat integer; v_saat_kalan integer; v_sehir_kalan integer; v_saat_carpan numeric; v_sehir_ust integer;
 sale_id bigint; corp_branch numeric; corp_brand numeric; branch_taxbase numeric; brandgross numeric;
 f oyun.eko_franchise; m oyun.eko_markalar;
 v_donem timestamptz:=date_trunc('hour',now());
begin
 if not pg_try_advisory_xact_lock(424261) then return jsonb_build_object('kilitli',true); end if;
 -- Tamamlanmis uretim emrini bir defa stoklara aktar; maliyet baslangicta odenmistir.
 yapilan := oyun.eko_uretim_teslim(null);

 -- Istege bagli 7 gunluk otomatik stok yenileme: tedarikci stogu ve magaza parasi yoksa satin almaz.
 for oto in select a.* from oyun.eko_otomatik_tedarik a
 join oyun.eko_isletmeler ei on ei.sirket_id=a.sirket_id and ei.tur='magaza'
 join oyun.sirketler s on s.id=a.sirket_id and s.aktif
 where a.aktif and a.bitis>t order by a.sirket_id,a.urun limit 250
 loop
  begin
   select coalesce(adet,0) into stok_adet from oyun.eko_urun_stok
    where sirket_id=oto.sirket_id and urun=oto.urun;
   if coalesce(stok_adet,0)>oto.esik then continue;end if;
   select st.sirket_id into sup
    from oyun.eko_urun_stok st join oyun.eko_isletmeler e
      on e.sirket_id=st.sirket_id and e.tur='fabrika'
    join oyun.sirketler s on s.id=st.sirket_id and s.aktif
    where st.urun=oto.urun and st.adet>0 and st.satis_fiyati<=oto.azami_birim_fiyat
      and st.sirket_id<>oto.sirket_id
    order by st.satis_fiyati,st.sirket_id limit 1;
   if sup is null then continue;end if;
   select least(oto.miktar,adet) into siparis from oyun.eko_urun_stok
     where sirket_id=sup and urun=oto.urun;
   if siparis>0 then
     perform oyun.eko_urun_toptan(oto.sirket_id,sup,oto.urun,siparis,null);
     alim:=alim+1;
   end if;
  exception when others then null; -- tek siparisin basarisizligi digerlerinin satisini engellemez
  end;
 end loop;
 update oyun.eko_otomatik_tedarik set aktif=false where aktif and bitis<=t;

 -- NPC tuketimi: ilin nufusu ve geliri (talep), alim gucu, yerel fiyat duzeyi, piyasa fiyati ve rakip sayisi.
 for mag in select ei.sirket_id,ei.il_id,ei.magaza_kategori,
   s.sermaye,coalesce(d.gelisim,50) as gelisim,
   oyun.il_talep_endeksi(ei.il_id) as te, oyun.il_alim_gucu(ei.il_id) as ag, oyun.il_fiyat_duzeyi(ei.il_id) as fd
   from oyun.eko_isletmeler ei join oyun.sirketler s on s.id=ei.sirket_id and s.aktif
   left join oyun.il_durum d on d.il_id=ei.il_id
   where ei.tur='magaza' and ei.satis_aktif and ei.son_perakende<=t-interval '1 hour'
   order by md5(ei.sirket_id::text||((t at time zone 'Europe/Istanbul')::date)::text) limit 250
 loop
  update oyun.eko_isletmeler set son_perakende=t
   where sirket_id=mag.sirket_id and son_perakende<=t-interval '1 hour';
  if not found then continue;end if;
  v_saat:=extract(hour from (t at time zone 'Europe/Istanbul'))::integer;
  v_saat_carpan:=case when v_saat between 1 and 5 then 0.18
    when v_saat between 6 and 9 then 0.75
    when v_saat between 10 and 15 then 1.15
    when v_saat between 16 and 22 then 1.0 else 0.55 end;
  -- Mağaza başı saatlik müşteri: büyük şehirde yoğun, küçük şehirde seyrek
  v_saat_kalan:=greatest(4,round((case mag.magaza_kategori when 'market' then 18 when 'fastfood' then 22 else 16 end)
    *greatest(0.6,least(1.8,power(coalesce(mag.te,1),0.35))))::integer);
  -- Şehrin günlük müşteri kotası: nüfus ve gelirle (İstanbul ~6 kat, Tunceli ~0,25 kat)
  v_sehir_ust:=greatest(50,round((case mag.magaza_kategori when 'market' then 600
    when 'fastfood' then 450 else 380 end)*coalesce(mag.te,1))::integer);
  insert into oyun.eko_sehir_musteri_limiti(il_id,kategori,gun,ust_sinir)
  values(mag.il_id,mag.magaza_kategori,(t at time zone 'Europe/Istanbul')::date,v_sehir_ust)
  on conflict(il_id,kategori,gun) do update set ust_sinir=excluded.ust_sinir;
  select greatest(0,lim.ust_sinir-lim.satilan) into v_sehir_kalan
  from oyun.eko_sehir_musteri_limiti lim where lim.il_id=mag.il_id
    and kategori=mag.magaza_kategori and gun=(t at time zone 'Europe/Istanbul')::date for update;
  if v_sehir_kalan<=0 then continue;end if;
  v_musteri:=case mag.magaza_kategori
    when 'fastfood' then case when v_saat between 11 and 15 then 'Öğle yemeği müşterileri' else 'Çalışanlar, öğrenciler ve aileler' end
    when 'kahve' then case when v_saat between 7 and 11 then 'Sabah kahvesi müşterileri' else 'Öğrenciler ve ofis çalışanları' end
    else 'Mahalle sakinleri ve aileler' end;
  select count(*) into rakip from oyun.eko_isletmeler ei join oyun.sirketler s
  on s.id=ei.sirket_id and s.aktif where ei.tur='magaza' and ei.il_id=mag.il_id;
  select * into f from oyun.eko_franchise where sube=mag.sirket_id;
  if f.id is not null then select * into m from oyun.eko_markalar where sirket_id=f.marka;end if;
  for item in select st.*,k.kullanim,k.talep,k.onerilen_satis from oyun.eko_urun_stok st
      join oyun.eko_urun_katalog k on k.kod=st.urun and k.aktif
      where st.sirket_id=mag.sirket_id and st.adet>0 and st.satis_fiyati>0
      order by st.urun for update of st skip locked
  loop
    -- Yerel fiyat düzeyine göre makul fiyat ve ilin alım gücü
    faktor:=greatest(.12,least(1.4,(item.onerilen_satis*coalesce(mag.fd,1)/greatest(item.satis_fiyati,1))^.8))
      *coalesce(mag.ag,1)
      /(1+greatest(0,rakip-1)*.1);
    if mag.magaza_kategori<>'market' and mag.magaza_kategori<>item.kullanim then faktor:=faktor*.22;end if;
    faktor:=faktor*v_saat_carpan;
    if item.talep<=4 then
      talep:=case when (extract(epoch from v_donem)/3600+mag.sirket_id)::bigint%greatest(2,7-item.talep)=0
        then 1 else 0 end;
    else
      talep:=greatest(0,round((item.talep/8.0)*faktor)::integer);
    end if;
    siparis:=least(item.adet,talep,v_saat_kalan,v_sehir_kalan);
    if siparis<=0 then continue;end if;
    ciro:=round(siparis*item.satis_fiyati);
    maliyet:=round(siparis*item.maliyet_birim);
    personel:=round(ciro*.07);
    v_vergi:=oyun.eko_vergi_hesap('satis',ciro);
    royalty:=0;karpayi:=0;
    if f.id is not null then
     royalty:=round(ciro*f.komisyon/100);
     kardegeri:=greatest(0,ciro-maliyet-personel-v_vergi-royalty);
     karpayi:=round(kardegeri*f.kar_payi/100);
    end if;
    branch_taxbase:=greatest(0,ciro-maliyet-personel-v_vergi-royalty-karpayi);
    corp_branch:=oyun.eko_vergi_hesap('kar',branch_taxbase);
    brandgross:=royalty+karpayi;
    corp_brand:=case when f.id is not null then oyun.eko_vergi_hesap('kar',brandgross) else 0 end;
    net:=ciro-maliyet-personel-v_vergi-royalty-karpayi-corp_branch;
    insert into oyun.eko_npc_satis(sirket_id,urun,donem,adet,ciro,mal_maliyeti,personel_gideri,
       vergi,isim_hakki,kar_paylasim,net_kar,musteri_kesimi)
       values(mag.sirket_id,item.urun,v_donem,siparis,ciro,maliyet,personel,v_vergi+corp_branch,royalty,karpayi,net,v_musteri)
       on conflict(sirket_id,urun,donem) do nothing returning id into sale_id;
    if not found then continue;end if;
    if oyun.eko_vergi_tahsil(mag.sirket_id,'satis',ciro,'npc_sale',sale_id)<>v_vergi
      then raise exception 'Perakende satis vergisi uyusmuyor.';end if;
    if oyun.eko_vergi_tahsil(mag.sirket_id,'kar',branch_taxbase,'npc_branch',sale_id)<>corp_branch
      then raise exception 'Magaza kurumlar vergisi uyusmuyor.';end if;
    if f.id is not null and corp_brand>0 then
      if oyun.eko_vergi_tahsil(f.marka,'kar',brandgross,'npc_brand',sale_id)<>corp_brand
       then raise exception 'Franchise kurumlar vergisi uyusmuyor.';end if;
    end if;
    update oyun.eko_urun_stok set adet=adet-siparis,guncelleme=t where sirket_id=mag.sirket_id and urun=item.urun;
    update oyun.sirketler set kasa=kasa+ciro-personel-v_vergi-royalty-karpayi-corp_branch where id=mag.sirket_id;
    if f.id is not null and (royalty+karpayi)>0 then
      update oyun.sirketler set kasa=kasa+royalty+karpayi-corp_brand where id=f.marka and aktif;
    end if;
    perform oyun.eko_kar_yaz(mag.sirket_id,'magaza',sale_id,ciro,
      v_vergi+corp_branch,net,t);
    if f.id is not null and brandgross>0 then
      perform oyun.eko_kar_yaz(f.marka,'franchise',sale_id,brandgross,
      corp_brand,brandgross-corp_brand,t);
    end if;
    update oyun.eko_sehir_musteri_limiti set satilan=oyun.eko_sehir_musteri_limiti.satilan+siparis
    where il_id=mag.il_id and kategori=mag.magaza_kategori
    and gun=(t at time zone 'Europe/Istanbul')::date and oyun.eko_sehir_musteri_limiti.satilan+siparis<=oyun.eko_sehir_musteri_limiti.ust_sinir;
    if not found then raise exception 'Şehir talep limiti değişti, satış tekrar denenmeli.';end if;
    v_sehir_kalan:=v_sehir_kalan-siparis;
    v_saat_kalan:=v_saat_kalan-siparis;
    satilan:=satilan+siparis;
  end loop;
 end loop;
 return jsonb_build_object('uretimler',yapilan,'oto_alimlar',alim,'satilan_adet',satilan);
end $$;

-- =====================================================================
-- G) NPC STOKLU İŞLETMELER (akaryakıt, galeri, elektronik, giyim, mobilya, yapı market)
-- =====================================================================
create or replace function oyun.npc_isletme_tick()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s record; st record;
 t timestamptz:=now(); v_gun date:=(now() at time zone 'Europe/Istanbul')::date;
 v_lim integer; v_satilan integer; v_adet integer; v_rakip integer;
 v_gelir numeric; v_maliyet numeric; v_kdv numeric; v_kurum numeric; v_diger numeric; v_bakim numeric;
 v_kar numeric; v_satis_id bigint; v_n integer:=0; v_ciro numeric:=0;
 v_tlm numeric:=oyun.pazar_tl_milyar(); v_oran numeric:=oyun.eko_vergi_oran('kdv');
 v_kv numeric:=oyun.eko_vergi_oran('kurumlar');
 v_tavan_oran numeric:=oyun.tf('npc_marj_tavan'); v_tavan numeric; v_marj numeric; v_birim numeric;
begin
 if not oyun.uzaktan_modul_acik('npc_isletme') then return jsonb_build_object('durdu',true); end if;
 if not pg_try_advisory_xact_lock(444722,7) then return jsonb_build_object('kilitli',true); end if;
 for s in
 select c.id,c.ad,c.kasa,c.sermaye,c.sektor,p.il_id,d.gelisim,
       -- Şehirdeki müşteri sayısı ilin nüfusu ve gelirine göre (161); harcama ilin alım gücüne göre
       oyun.il_talep_endeksi(p.il_id) as sehir_carpani,
       oyun.il_alim_gucu(p.il_id) as alim_gucu
 from oyun.sirketler c join oyun.pazar_sirket p on p.sirket_id=c.id
 join oyun.il_durum d on d.il_id=p.il_id
 where c.aktif and exists(select 1 from oyun.npc_urun_katalog n where n.sektor=c.sektor)
 order by c.id limit 400
 loop
  perform pg_advisory_xact_lock(98763,hashtext(s.id::text));
  perform 1 from oyun.sirketler where id=s.id for update;
  insert into oyun.npc_son_saat(sirket_id,son_saat) values(s.id,t) on conflict do nothing;
  update oyun.npc_son_saat set son_saat=t
  where sirket_id=s.id and son_saat<=t-interval '15 minutes';
  if not found then continue; end if;
  v_bakim:=least(greatest(0,(select kasa from oyun.sirketler where id=s.id)),
    round((10+s.sermaye*0.00008)/4,2));
  if v_bakim>0 then
   update oyun.sirketler set kasa=kasa-v_bakim where id=s.id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
   values(s.id,t,-v_bakim,'NPC mağaza 15 dakikalık personel, enerji ve bakım',0,v_bakim,0);
  end if;
  v_tavan:=greatest(0,coalesce(s.sermaye,0))*v_tavan_oran/100;
  select coalesce((select m.marj from oyun.npc_marj_gun m where m.sirket_id=s.id and m.gun=v_gun),0) into v_marj;
  select count(*) into v_rakip from oyun.pazar_sirket ps
   join oyun.sirketler c on c.id=ps.sirket_id
   where ps.il_id=s.il_id and c.aktif and c.sektor=s.sektor;
  for st in select ns.urun,ns.adet,ns.alis_ortalama,ns.satis_fiyati,
    u.gunluk_talep from oyun.npc_stok ns join oyun.npc_urun_katalog u on u.kod=ns.urun
    where ns.sirket_id=s.id and ns.adet>0 order by ns.urun for update of ns
  loop
    insert into oyun.npc_talep_gun(il_id,urun,gun)
    values(s.il_id,st.urun,v_gun) on conflict do nothing;
    select adet into v_satilan from oyun.npc_talep_gun
       where il_id=s.il_id and urun=st.urun and gun=v_gun for update;
    v_lim:=greatest(1,round(2*st.gunluk_talep*greatest(0.3,least(4,s.sehir_carpani))*
      (1+oyun.belediye_yatirim_oran(s.il_id,'talep'))));
    v_adet:=least(st.adet,greatest(0,v_lim-v_satilan),
       greatest(0,floor(st.gunluk_talep*greatest(0.3,least(4,s.sehir_carpani))/30*
       (0.65+random()*.7)/sqrt(greatest(1,v_rakip))*
       coalesce(s.alim_gucu,1)*
       greatest(0.2,least(1.7,power(
       oyun.npc_piyasa_fiyati(st.urun,s.il_id,'satis')/greatest(st.satis_fiyati,0.01),3)))
       +random())::integer));
    if v_adet<=0 then continue; end if;
    v_birim:=st.satis_fiyati-st.alis_ortalama;
    if v_tavan_oran>0 and v_birim>0 then
      v_adet:=least(v_adet,greatest(0,floor((v_tavan-v_marj)/v_birim))::integer);
      if v_adet<=0 then continue; end if;
    end if;
    v_gelir:=round(st.satis_fiyati*v_adet,2);
    v_maliyet:=round(st.alis_ortalama*v_adet,2);
    v_kdv:=round(greatest(0,v_gelir-v_maliyet)*v_oran/(100+v_oran),2);
    v_diger:=round(v_gelir*0.006,2);
    v_kurum:=round(greatest(0,v_gelir-v_maliyet-v_kdv-v_diger)*v_kv/100,2);
    v_kar:=v_gelir-v_maliyet-v_kdv-v_diger-v_kurum;
    update oyun.npc_stok set adet=adet-v_adet,son_guncelleme=t
     where sirket_id=s.id and urun=st.urun;
    update oyun.npc_talep_gun set adet=adet+v_adet
     where il_id=s.il_id and urun=st.urun and gun=v_gun;
    update oyun.sirketler set kasa=kasa+v_gelir-v_kdv-v_diger-v_kurum,son_islem=t where id=s.id;
    v_marj:=v_marj+greatest(0,v_gelir-v_maliyet);
    insert into oyun.npc_marj_gun(sirket_id,gun,marj) values(s.id,v_gun,greatest(0,v_gelir-v_maliyet))
      on conflict (sirket_id,gun) do update set marj=oyun.npc_marj_gun.marj+excluded.marj;
    insert into oyun.npc_satis_kayit(sirket_id,urun,adet,tutar,maliyet,vergi,isletme_gideri,tur,zaman)
      values(s.id,st.urun,v_adet,v_gelir,v_maliyet,v_kdv+v_kurum,v_diger,'npc_satis',t) returning id into v_satis_id;
    insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
      values(s.id,t,v_kar,format('NPC satış: %s adet %s (KDV ve kâr vergisi dahil)',v_adet,st.urun),
      v_gelir,v_maliyet+v_kdv+v_kurum+v_diger,0);
    if v_kdv+v_kurum>0 then
      update oyun.ulke set hazine=hazine+(v_kdv+v_kurum)/v_tlm where id=1;
      if v_kdv>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kdv',v_gelir,v_oran,v_kdv,'npc_satis',v_satis_id,t);
      end if;
      if v_kurum>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kurumlar',greatest(0,v_gelir-v_maliyet-v_kdv-v_diger),v_kv,v_kurum,'npc_satis',v_satis_id,t);
      end if;
    end if;
    v_ciro:=v_ciro+v_gelir;v_n:=v_n+v_adet;
  end loop;
 end loop;
 return jsonb_build_object('satilan',v_n,'ciro',v_ciro,'zaman',t);
end $$;

-- =====================================================================
-- H) ÜRETİM VE TİCARET PANELİ: bitmiş emir anında stoğa geçer, il bilgisi ve teslim saati
-- =====================================================================
create or replace function public.eko_ticaret_panel()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then
 raise exception 'Giris yapmalisin.';end if;
 -- Süresi dolmuş üretim emirleri oyuncu paneli açınca hemen stoğa geçer (zamanlayıcıyı beklemez)
 perform oyun.eko_uretim_teslim(u);
 return jsonb_build_object(
 'simdi', oyun.simdi(),
 'urunler',coalesce((select jsonb_agg(jsonb_build_object('kod',kod,'ad',ad,'grup',grup,'kategori',kullanim,'maliyet',maliyet,
 'parti',parti_ust,'dakika',uretim_dakika,'satis',onerilen_satis,'talep',talep) order by maliyet) from oyun.eko_urun_katalog where aktif),'[]'::jsonb),
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object(
 'id',s.id,'ad',s.ad,'sektor',s.sektor,'tur',e.tur,'grup',e.urun,'kategori',e.magaza_kategori,
 'il',e.il_id,'il_ad',(select i.ad from oyun.iller i where i.id=e.il_id),
 'il_endeks',case when e.il_id is not null then oyun.il_endeks(e.il_id) end,
 'sonraki_satis',e.son_perakende+interval '1 hour','kasa',oyun.kasa_goster('sirket', s.id, s.kasa),'sermaye',s.sermaye,'kapasite',case when e.tur='fabrika' then oyun.eko_fabrika_kapasite(s.id) else null end,'yonetici',oyun.sirket_yonetici_mi(s.id,u),
 'marka',case when mk.sirket_id is not null then jsonb_build_object('kategori',mk.kategori,'bedel',mk.isim_hakki,
 'ciro_payi',mk.komisyon,'kar_payi',mk.kar_payi) else null end,
 'bayilik',case when fr.id is not null then jsonb_build_object('marka',fr.marka,'ciro_payi',fr.komisyon,'kar_payi',fr.kar_payi) else null end
 ) order by s.id) from oyun.sirketler s
 join oyun.sirket_ortaklari o on o.sirket_id=s.id and o.user_id=u
 left join oyun.eko_isletmeler e on e.sirket_id=s.id
 left join oyun.eko_markalar mk on mk.sirket_id=s.id
 left join oyun.eko_franchise fr on fr.sube=s.id
 where s.aktif),'[]'::jsonb),
 'stok',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'urun',x.urun,'adet',x.adet,
 'maliyet',x.maliyet_birim,'fiyat',x.satis_fiyati))
 from oyun.eko_urun_stok x where x.sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u)),'[]'::jsonb),
 'tedarikciler',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'ad',s.ad,'urun',x.urun,'adet',x.adet,
 'fiyat',x.satis_fiyati,'il',e.il_id))
 from oyun.eko_urun_stok x join oyun.sirketler s on s.id=x.sirket_id
 join oyun.eko_isletmeler e on e.sirket_id=s.id and e.tur='fabrika'
 where x.adet>0 and s.aktif),'[]'::jsonb),
 'uretim',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'sirket',x.sirket_id,'urun',x.urun,'adet',x.adet,
 'maliyet',x.toplam_maliyet,'baslangic',x.baslangic,'hazir',x.hazir,'tamam',x.tamamlandi,'kaynak',x.kaynak,
 'teslim',case when x.tamamlandi is null then oyun.eko_teslim_tahmini(x.hazir) end) order by x.id desc)
 from (select * from oyun.eko_uretim_emir where sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u) order by id desc limit 60) x),'[]'::jsonb),
 'oto',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'urun',x.urun,
 'esik',x.esik,'miktar',x.miktar,'ust',x.azami_birim_fiyat,'bitis',x.bitis,'aktif',x.aktif))
 from oyun.eko_otomatik_tedarik x where x.sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u)),'[]'::jsonb),
 'satislar',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'urun',x.urun,'adet',x.adet,'ciro',x.ciro,
 'maliyet',x.mal_maliyeti,'gider',x.personel_gideri,'vergi',x.vergi,'royalty',x.isim_hakki,
 'kar_payi',x.kar_paylasim,'kar',x.net_kar,'musteri',x.musteri_kesimi,'zaman',x.zaman))
 from (select * from oyun.eko_npc_satis where sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u) order by id desc limit 70)x),'[]'::jsonb),
 'markalar',coalesce((select jsonb_agg(jsonb_build_object('id',m.sirket_id,'ad',s.ad,
 'kategori',m.kategori,'bedel',m.isim_hakki,'ciro_payi',m.komisyon,'kar_payi',m.kar_payi))
 from oyun.eko_markalar m join oyun.sirketler s on s.id=m.sirket_id where s.aktif),'[]'::jsonb)
 );
end $$;

-- =====================================================================
-- I) MALİYET YAMALARI (canlıdaki fonksiyondan okunur, yalnız ilgili ifade değişir; ifade bulunamazsa atlanır)
-- =====================================================================
do $duzelt$
declare r record; d text; adet int;
begin
  for r in select * from (values
    -- Fabrika üretim emri: işçilik, enerji ve kira ilin üretim endeksiyle
    ('public.eko_ticaret_islem(text,jsonb)', 'v:=round(k.maliyet*miktar);',
       'v:=round(k.maliyet*miktar*oyun.il_uretim_endeksi(e.il_id));'),
    -- Otomatik üretim aynı maliyetle
    ('oyun.eko_otomasyon_tick()', 'v_tutar:=round(k.maliyet*v_miktar);',
       'v_tutar:=round(k.maliyet*v_miktar*oyun.il_uretim_endeksi((select i.il_id from oyun.eko_isletmeler i where i.sirket_id=a.sirket_id)));'),
    -- Kahveci / fast food malzemesi yerel fiyat düzeyiyle; önerilen raf fiyatı da yerel
    ('public.eko_magaza_hazirla(bigint,text,integer)', 'v_bedel:=round(v_k.maliyet*p_adet);',
       'v_bedel:=round(v_k.maliyet*p_adet*oyun.il_fiyat_duzeyi(v_e.il_id));'),
    ('public.eko_magaza_hazirla(bigint,text,integer)', $a$'raf_fiyati',v_k.onerilen_satis);$a$,
       $b$'raf_fiyati',round(v_k.onerilen_satis*oyun.il_fiyat_duzeyi(v_e.il_id)));$b$),
    -- Şube: kira (sabit gider, depozito) ve tadilat tabanı ilin kuruluş endeksiyle
    ('oyun.sube_bolge_analiz(bigint,smallint,smallint,smallint,timestamp with time zone)',
       '(0.8+least(3,oyun.pazar_il_agirlik(p_il))*0.15));', 'oyun.il_kurulus_endeksi(p_il));'),
    ('oyun.sube_bolge_analiz(bigint,smallint,smallint,smallint,timestamp with time zone)',
       'fitout:=round(greatest(35000,revenue*enterprise_cost_factor));',
       'fitout:=round(greatest(35000*oyun.il_kurulus_endeksi(p_il),revenue*enterprise_cost_factor));'),
    ('public.sirket_sube_teklif(bigint,integer)', $a$'dekorasyon_donanim',round(greatest(100000,s.sermaye*.25)),$a$,
       $b$'dekorasyon_donanim',round(greatest(100000,s.sermaye*.25)*oyun.il_kurulus_endeksi(p_il::smallint)),$b$),
    ('public.sirket_sube_teklif(bigint,integer)', $a$'depozito',round(greatest(25000,s.sermaye*.05)),$a$,
       $b$'depozito',round(greatest(25000,s.sermaye*.05)*oyun.il_kurulus_endeksi(p_il::smallint)),$b$),
    -- Ruhsat başvurusu cevabında tahmini kuruluş gideri
    ('public.bel_ruhsat_basvur(text,integer,bigint,bigint,text,text,numeric)', $a$ 'tahmini_harc',$a$,
       $b$ 'kurulus_gideri',oyun.il_kurulus_tutar(case p_tur when 'kur_fabrika' then 'fabrika' when 'kur_magaza' then 'magaza' when 'kur_insaat' then 'insaat' when 'kur_sigorta' then 'sigorta' when 'kur_pazar' then 'pazar' end,v_il,p_sektor),
 'tahmini_harc',$b$)
  ) v(fn, eski, yeni) loop
    if to_regprocedure(r.fn) is null then raise notice '% bu kurulumda yok, atlandı', r.fn; continue; end if;
    d := pg_get_functiondef(to_regprocedure(r.fn));
    if position(r.yeni in d) > 0 then raise notice '% zaten güncel', r.fn; continue; end if;
    adet := (length(d) - length(replace(d, r.eski, ''))) / length(r.eski);
    if adet = 0 then raise notice '% bu kurulumda farklı yazılmış, atlandı: %', r.fn, r.eski; continue; end if;
    if adet > 1 then raise exception '% içinde ifade % kez geçiyor (1 olmalı): %', r.fn, adet, r.eski; end if;
    execute replace(d, r.eski, r.yeni);
  end loop;
end $duzelt$;

-- =====================================================================
-- J) OYUNCUYA AÇIK BİLGİ
-- =====================================================================
create or replace function public.il_ekonomi_bilgi(p_il integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_il smallint; e jsonb; v_ad text; te numeric; km numeric;
begin
  if auth.uid() is null then raise exception 'Oturum açmalısın.'; end if;
  if p_il is null or p_il < 1 or p_il > 32767 then raise exception 'Geçerli bir il seç.'; end if;
  v_il := p_il::smallint;
  select i.ad into v_ad from oyun.iller i where i.id = v_il;
  if v_ad is null then raise exception 'Geçerli bir il seç.'; end if;
  e := oyun.il_endeks(v_il);
  te := (e->>'talep')::numeric; km := (e->>'kurulus')::numeric;
  return e || jsonb_build_object(
    'il', v_ad,
    'kurulus_gideri', jsonb_build_object(
      'fabrika', oyun.il_kurulus_tutar('fabrika', v_il), 'magaza', oyun.il_kurulus_tutar('magaza', v_il),
      'insaat', oyun.il_kurulus_tutar('insaat', v_il), 'sigorta', oyun.il_kurulus_tutar('sigorta', v_il)),
    'pazar_gider_oran', case when (e->>'aktif')::boolean then round(oyun.tf('il_kurulus_pazar_oran') * km, 2) else 0 end,
    'pazar_sektorleri', coalesce((select jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', k.ad, 'min_sermaye', k.min_sermaye,
        'gider', oyun.il_kurulus_tutar('pazar', v_il, k.kod)) order by k.sira) from oyun.pazar_sektor k), '[]'::jsonb),
    'musteri_gunluk', jsonb_build_object('market', greatest(50, round(600 * te)), 'fastfood', greatest(50, round(450 * te)),
        'kahve', greatest(50, round(380 * te))),
    'magaza_saatlik', jsonb_build_object(
        'market', greatest(4, round(18 * greatest(0.6, least(1.8, power(te, 0.35))))),
        'fastfood', greatest(4, round(22 * greatest(0.6, least(1.8, power(te, 0.35))))),
        'kahve', greatest(4, round(16 * greatest(0.6, least(1.8, power(te, 0.35)))))),
    'kaynak', 'TÜİK ADNKS 2025 il nüfusu; TÜİK il bazında GSYH 2024 (kişi başı, ABD doları); SEGE kademesi; oyundaki il gelişimi');
end $$;

create or replace function public.il_ekonomi_liste()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Oturum açmalısın.'; end if;
  return jsonb_build_object(
    'aktif', oyun.il_ekonomi_acik(),
    'pazar_oran', oyun.tf('il_kurulus_pazar_oran'),
    'kaynak', 'TÜİK ADNKS 2025 il nüfusu; TÜİK il bazında GSYH 2024 (kişi başı, ABD doları); SEGE kademesi; oyundaki il gelişimi',
    'iller', coalesce((select jsonb_agg(x order by (x->>'kurulus')::numeric desc, x->>'il')
      from (select oyun.il_endeks(i.id) || jsonb_build_object('il', i.ad,
              'gider_fabrika', oyun.il_kurulus_tutar('fabrika', i.id), 'gider_magaza', oyun.il_kurulus_tutar('magaza', i.id),
              'gider_insaat', oyun.il_kurulus_tutar('insaat', i.id), 'gider_sigorta', oyun.il_kurulus_tutar('sigorta', i.id)) x
            from oyun.iller i) q), '[]'::jsonb));
end $$;

-- =====================================================================
-- K) YETKİLER (159'daki izin listesine de eklendi)
-- =====================================================================
do $$ declare f text; begin
  foreach f in array array['oyun.il_ekonomi_acik()', 'oyun.il_endeks(smallint)', 'oyun.il_kurulus_endeksi(smallint)',
      'oyun.il_talep_endeksi(smallint)', 'oyun.il_alim_gucu(smallint)', 'oyun.il_fiyat_duzeyi(smallint)',
      'oyun.il_uretim_endeksi(smallint)', 'oyun.il_pazar_gelismislik(smallint)', 'oyun.il_kurulus_tutar(text,smallint,text)',
      'oyun.tg_il_kurulus_gider()', 'oyun.eko_uretim_teslim(uuid)', 'oyun.eko_teslim_tahmini(timestamptz)'] loop
    if to_regprocedure(f) is not null then execute format('revoke all on function %s from public, anon, authenticated', f); end if;
  end loop;
  foreach f in array array['public.il_ekonomi_bilgi(integer)', 'public.il_ekonomi_liste()', 'public.eko_ticaret_panel()'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke all on function %s from public, anon', f);
      execute format('grant execute on function %s to authenticated', f);
    end if;
  end loop;
end $$;

select set_config('check_function_bodies', 'on', true);
commit;
