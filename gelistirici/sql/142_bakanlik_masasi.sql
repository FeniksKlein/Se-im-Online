-- =====================================================================
--  142 · BAKANLIK MASASI — bütçe mantığı, görevler, etkinlikler (27.10.2026)
--
--  Bütçe mantığı (tek cümleyle): Hazine her gün bütçe kanunundaki paylara
--  göre bakanlıklara ödenek aktarır; bakan bu kasayla icraat, etkinlik,
--  saha ziyareti ve ihale yapar; yetmezse Cumhurbaşkanından (parlamenter
--  sistemde Başbakandan) ek ödenek ister; kullanmadığını Hazine'ye iade
--  edebilir. Her kuruş bakanlık hesap defterine (oyun.bakanlik_hareket)
--  kaynağıyla yazılır.
--
--  · Hesap defteri: bakanlik_kasa'daki her değişiklik tetikleyiciyle
--    kaydedilir (eski fonksiyonlara dokunmadan; neden, çağrılan işlemden
--    ya da oyun.bk_neden ayarından bulunur).
--  · Tavan: kasa tavanı (varsayılan 100 milyar ₺) dolduğunda günlük ödenek
--    eskiden yok oluyordu; artık Hazine'de kalır (gunluk_ekonomi'de tek
--    ifade değişir).
--  · Ek ödenek talebi → yürütme onayı / reddi; Hazine'ye iade; yürütmenin
--    bakanlıklar arası ödenek aktarımı (kaynağın en çok %25'i, 24 saatte bir).
--  · Merkezi bütçe tahsisi (kamu_butce_dagit) artık 12 bakanlığın hepsine.
--  · Etkinlikler: her bakanlığın iki etkinliği (24 tür). Oyuncular katılır,
--    katılan kıdem kazanır, katılım arttıkça etkinliğin etkisi büyür.
--  · Saha ziyareti, bakanlık açıklaması (Resmî Gazete duyurusu).
--  · Haftalık 3 görev (her hafta değişir) ve kıdem ödülü; bakan karnesi.
--  Yalnız yeni tablo / sütun / fonksiyon ekler; oyuncu verisine dokunmaz;
--  iki kez çalıştırmak güvenlidir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.bakanlik_ayar(
  id                    int primary key default 1 check (id = 1),
  tavan                 numeric not null default 100,   -- bakanlık kasası tavanı (milyar ₺)
  talep_ust             numeric not null default 25,    -- tek ek ödenek talebi üst sınırı (milyar ₺)
  talep_bekleme_saat    int not null default 24,
  talep_sure_saat       int not null default 72,
  aktarim_oran          numeric not null default 25,    -- kaynak kasanın en çok yüzde kaçı aktarılabilir
  aktarim_bekleme_saat  int not null default 24,
  ziyaret_maliyet       numeric not null default 0.5,   -- milyar ₺
  ziyaret_bekleme_saat  int not null default 12,
  aciklama_bekleme_dk   int not null default 360,
  katilim_gunluk_odul   int not null default 2,         -- günde kaç etkinlik katılımı kıdem kazandırır
  gorev_kidem           numeric not null default 1,
  gorev_tam_bonus       numeric not null default 2
);
insert into oyun.bakanlik_ayar(id) values (1) on conflict do nothing;

create table if not exists oyun.bakanlik_hareket(
  id       bigserial primary key,
  kod      text not null references oyun.bakanliklar(kod),
  zaman    timestamptz not null default now(),
  tutar    numeric not null,          -- milyar ₺ (+ giriş, − çıkış)
  bakiye   numeric not null,
  tur      text not null,
  aciklama text not null,
  user_id  uuid
);
create index if not exists bakanlik_hareket_kod_zaman on oyun.bakanlik_hareket(kod, zaman desc);

create table if not exists oyun.bakanlik_odenek_talep(
  id          bigserial primary key,
  kod         text not null references oyun.bakanliklar(kod),
  user_id     uuid not null,
  tutar       numeric not null check (tutar > 0),
  gerekce     text not null,
  durum       text not null default 'bekliyor' check (durum in ('bekliyor', 'onay', 'red', 'iptal', 'dusen')),
  zaman       timestamptz not null default now(),
  bitis       timestamptz not null,
  karar_user  uuid,
  karar_zaman timestamptz,
  karar_not   text
);
create unique index if not exists bakanlik_odenek_talep_tek on oyun.bakanlik_odenek_talep(kod) where durum = 'bekliyor';
create index if not exists bakanlik_odenek_talep_zaman on oyun.bakanlik_odenek_talep(zaman desc);

create table if not exists oyun.bakanlik_etkinlik_tur(
  kod          text primary key,
  bakanlik     text not null references oyun.bakanliklar(kod),
  ad           text not null,
  aciklama     text not null,
  maliyet      numeric not null,        -- milyar ₺
  sure_saat    int not null default 12,
  il_gerekli   boolean not null default true,
  etki         jsonb not null,          -- buyume, enflasyon, issizlik, memnuniyet (ulusal) · gelisim, il_memnuniyet (il)
  kidem        numeric not null default 0.5,
  bekleme_saat int not null default 72,
  sira         int not null default 0
);

create table if not exists oyun.bakanlik_etkinlik(
  id        bigserial primary key,
  tur       text not null references oyun.bakanlik_etkinlik_tur(kod),
  bakanlik  text not null references oyun.bakanliklar(kod),
  il_id     smallint,
  user_id   uuid not null,
  not_metin text,
  bas       timestamptz not null,
  bit       timestamptz not null,
  maliyet   numeric not null,
  durum     text not null default 'aktif' check (durum in ('aktif', 'bitti', 'iptal')),
  katilimci int not null default 0,
  yerel     int not null default 0,
  sonuc     jsonb
);
create index if not exists bakanlik_etkinlik_durum on oyun.bakanlik_etkinlik(durum, bit);
create index if not exists bakanlik_etkinlik_bakanlik on oyun.bakanlik_etkinlik(bakanlik, bas desc);

create table if not exists oyun.bakanlik_etkinlik_katilim(
  etkinlik_id bigint not null references oyun.bakanlik_etkinlik(id),
  user_id     uuid not null,
  zaman       timestamptz not null default now(),
  tepki       text not null default 'katildim' check (tepki in ('katildim', 'destek', 'elestiri')),
  yerel       boolean not null default false,
  odul        numeric not null default 0,
  primary key (etkinlik_id, user_id)
);
create index if not exists bakanlik_etkinlik_katilim_user on oyun.bakanlik_etkinlik_katilim(user_id, zaman desc);

create table if not exists oyun.bakanlik_ziyaret(
  id        bigserial primary key,
  kod       text not null references oyun.bakanliklar(kod),
  user_id   uuid not null,
  il_id     smallint not null,
  zaman     timestamptz not null default now(),
  not_metin text
);
create index if not exists bakanlik_ziyaret_kod on oyun.bakanlik_ziyaret(kod, zaman desc);

create table if not exists oyun.bakanlik_aciklama(
  id      bigserial primary key,
  kod     text not null references oyun.bakanliklar(kod),
  user_id uuid not null,
  baslik  text not null,
  metin   text not null,
  zaman   timestamptz not null default now()
);
create index if not exists bakanlik_aciklama_kod on oyun.bakanlik_aciklama(kod, zaman desc);

create table if not exists oyun.bakanlik_gorev_odul(
  kod     text not null references oyun.bakanliklar(kod),
  hafta   date not null,
  gorev   text not null,
  user_id uuid not null,
  zaman   timestamptz not null default now(),
  kidem   numeric not null default 0,
  primary key (kod, hafta, gorev)
);

do $rls$
declare tb text;
begin
  foreach tb in array array['bakanlik_ayar', 'bakanlik_hareket', 'bakanlik_odenek_talep', 'bakanlik_etkinlik_tur', 'bakanlik_etkinlik',
                            'bakanlik_etkinlik_katilim', 'bakanlik_ziyaret', 'bakanlik_aciklama', 'bakanlik_gorev_odul'] loop
    execute format('alter table oyun.%I enable row level security', tb);
  end loop;
end $rls$;

-- ---------------------------------------------------------------------
-- 2) ETKİNLİK KATALOĞU (12 bakanlık × 2)
-- ---------------------------------------------------------------------
insert into oyun.bakanlik_etkinlik_tur(kod, bakanlik, ad, aciklama, maliyet, sure_saat, il_gerekli, etki, kidem, bekleme_saat, sira) values
 ('bke_adl_acik_kapi', 'adalet', 'Adliyede açık kapı günü', 'Vatandaşlar adliyeyi gezer, hâkim ve avukatlarla tanışır, ücretsiz hukuk danışmanlığı alır.', 2, 12, true, '{"gelisim":1,"il_memnuniyet":1}', 0.5, 72, 1),
 ('bke_adl_kurultay', 'adalet', 'Hukuk kurultayı', 'Hâkimler, avukatlar ve akademisyenler yargının hızlanması için önerileri tartışır.', 3, 24, false, '{"memnuniyet":0.4}', 0.5, 96, 2),
 ('bke_dis_buyukelci', 'disisleri', 'Büyükelçiler konferansı', 'Büyükelçiler yeni dış politika ve ticaret hedeflerini Ankara''da görüşür.', 4, 24, false, '{"buyume":0.08,"memnuniyet":0.2}', 0.5, 96, 1),
 ('bke_dis_kultur', 'disisleri', 'Uluslararası kültür festivali', 'Konuk ülkelerin müzik, yemek ve el sanatları şehirde buluşur.', 3, 12, true, '{"gelisim":1.5,"il_memnuniyet":1}', 0.5, 72, 2),
 ('bke_ic_muhtar', 'icisleri', 'Muhtarlar buluşması', 'İlin muhtarları sorunlarını doğrudan bakanlığa iletir.', 2, 12, true, '{"gelisim":1,"il_memnuniyet":1.5}', 0.5, 72, 1),
 ('bke_ic_tatbikat', 'icisleri', 'Büyük afet tatbikatı', 'AFAD, emniyet ve gönüllüler deprem ve sel senaryosunu sahada dener.', 3, 12, true, '{"gelisim":1.5,"il_memnuniyet":0.5}', 0.5, 72, 2),
 ('bke_mal_vergi', 'maliye', 'Vergi haftası', 'Vergi bilinci, e-beyanname kolaylıkları ve vergi rekortmenlerine teşekkür.', 2, 24, false, '{"memnuniyet":0.3}', 0.5, 96, 1),
 ('bke_mal_yatirimci', 'maliye', 'Yatırımcı buluşması', 'Yerli ve yabancı yatırımcılar ilin yatırım fırsatlarını dinler.', 4, 12, true, '{"gelisim":1.5,"buyume":0.05}', 0.5, 72, 2),
 ('bke_sav_fuar', 'savunma', 'Savunma sanayii fuarı', 'Yerli savunma şirketleri ürünlerini sergiler, gençlere staj imkânı sunar.', 5, 24, true, '{"gelisim":2,"buyume":0.05}', 0.5, 96, 1),
 ('bke_sav_toren', 'savunma', 'Mehmetçik gösterisi ve tören', 'Askerî bando, paraşüt gösterisi ve şehit ailelerine vefa töreni.', 3, 12, false, '{"memnuniyet":0.5}', 0.5, 96, 2),
 ('bke_egt_bilim', 'egitim', 'Bilim şenliği', 'Öğrenciler projelerini sergiler, deney atölyeleri ve robot yarışması yapılır.', 2, 12, true, '{"gelisim":1.5,"il_memnuniyet":0.5}', 0.5, 72, 1),
 ('bke_egt_kitap', 'egitim', 'Kitap fuarı', 'Yayınevleri ve yazarlar okurlarla buluşur, okullara kitap bağışlanır.', 3, 24, true, '{"gelisim":1,"il_memnuniyet":1}', 0.5, 72, 2),
 ('bke_sag_kan', 'saglik', 'Kan bağışı kampanyası', 'Hastanelerin kan stoku için ülke çapında bağış seferberliği.', 2, 24, false, '{"memnuniyet":0.4}', 0.5, 96, 1),
 ('bke_sag_tarama', 'saglik', 'Ücretsiz sağlık taraması günü', 'Şeker, tansiyon ve kanser taraması meydanlarda ücretsiz yapılır.', 3, 12, true, '{"gelisim":1,"il_memnuniyet":1.5}', 0.5, 72, 2),
 ('bke_san_teknoloji', 'sanayi', 'Teknoloji festivali', 'Robotik, yapay zekâ ve girişim yarışmaları; gençler için atölyeler.', 5, 24, true, '{"gelisim":2,"buyume":0.05}', 0.5, 96, 1),
 ('bke_san_girisim', 'sanayi', 'Girişimcilik zirvesi', 'Girişimciler, melek yatırımcılar ve sanayiciler aynı salonda buluşur.', 3, 12, false, '{"buyume":0.1}', 0.5, 96, 2),
 ('bke_tic_esnaf', 'ticaret', 'Esnaf buluşması', 'Çarşı esnafının kira, kredi ve denetim sorunları dinlenir.', 2, 12, true, '{"gelisim":1,"il_memnuniyet":1}', 0.5, 72, 1),
 ('bke_tic_ihracat', 'ticaret', 'İhracat fuarı', 'İhracatçılar yabancı alıcılarla eşleşir; yeni pazarlar açılır.', 4, 24, false, '{"buyume":0.1,"enflasyon":-0.05}', 0.5, 96, 2),
 ('bke_tar_fuar', 'tarim', 'Tarım ve hayvancılık fuarı', 'Çiftçiler yeni tohum, makine ve destekleri yerinde görür.', 3, 24, true, '{"gelisim":1.5,"enflasyon":-0.03}', 0.5, 72, 1),
 ('bke_tar_fidan', 'tarim', 'Fidan dikim şenliği', 'Okullar ve dernekler binlerce fidanı birlikte toprakla buluşturur.', 2, 12, true, '{"gelisim":1,"il_memnuniyet":1}', 0.5, 72, 2),
 ('bke_ula_acilis', 'ulastirma', 'Yeni hat açılış töreni', 'Yeni yol, tünel ya da raylı sistem hattı törenle hizmete girer.', 4, 12, true, '{"gelisim":2,"il_memnuniyet":0.5}', 0.5, 72, 1),
 ('bke_ula_trafik', 'ulastirma', 'Trafik güvenliği haftası', 'Okullarda eğitim, yollarda denetim ve kamu spotlarıyla farkındalık.', 2, 24, false, '{"memnuniyet":0.3}', 0.5, 96, 2),
 ('bke_cal_istihdam', 'calisma', 'Kariyer ve istihdam fuarı', 'İşverenler ve iş arayanlar fuarda buluşur; yerinde mülakatlar yapılır.', 3, 24, true, '{"gelisim":1,"issizlik":-0.05}', 0.5, 72, 1),
 ('bke_cal_emekli', 'calisma', 'Emekliler ve çalışanlar buluşması', 'Sendikalar, emekli dernekleri ve işverenlerle sosyal diyalog toplantısı.', 2, 12, false, '{"memnuniyet":0.4}', 0.5, 96, 2)
on conflict (kod) do update set bakanlik = excluded.bakanlik, ad = excluded.ad, aciklama = excluded.aciklama, maliyet = excluded.maliyet,
  sure_saat = excluded.sure_saat, il_gerekli = excluded.il_gerekli, etki = excluded.etki, kidem = excluded.kidem,
  bekleme_saat = excluded.bekleme_saat, sira = excluded.sira;

-- ---------------------------------------------------------------------
-- 3) YARDIMCILAR
-- ---------------------------------------------------------------------
-- Kullanıcının bu bakanlıktaki yetkisi: 'bakan' | 'vekalet' (bakan yokken yürütme) | null
create or replace function oyun.bm_yetki(p_user uuid, p_kod text) returns text
language sql stable set search_path = '' as $$
  select case
    when p_user is null then null
    when exists(select 1 from oyun.makamlar m where m.user_id = p_user and m.tur = 'bakan' and m.bakanlik = p_kod and m.bit is null) then 'bakan'
    when oyun.bakanlik_vekili(p_user, p_kod) then 'vekalet'
  end
$$;

-- Türkçe ondalık: 3.5 → "3,5"
create or replace function oyun.bm_sayi(x numeric, d int default 1) returns text
language sql immutable set search_path = '' as $$
  select replace(round(coalesce(x, 0), d)::text, '.', ',')
$$;

create or replace function oyun.bm_neden(p_tur text, p_aciklama text) returns void
language plpgsql set search_path = '' as $$
begin
  perform set_config('oyun.bk_neden', case when p_tur is null then '' else p_tur || '|' || coalesce(p_aciklama, '') end, true);
end $$;

-- Haftanın başı (İstanbul saatiyle pazartesi 00.00)
create or replace function oyun.bm_hafta(t timestamptz) returns timestamptz
language sql stable set search_path = '' as $$
  select (date_trunc('week', t at time zone 'Europe/Istanbul')) at time zone 'Europe/Istanbul'
$$;

create or replace function oyun.bm_gunluk(p_kod text) returns numeric
language sql stable set search_path = '' as $$
  select round((oyun.ulke_hesap(u) ->> 'cari')::numeric * coalesce((u.butce ->> p_kod)::numeric, 0) / 100, 3)
    from oyun.ulke u where u.id = 1
$$;

-- Kasadan harcama (kilitli, yetersizse anlaşılır hata)
create or replace function oyun.bm_kasa_harca(p_kod text, p_tutar numeric, p_tur text, p_aciklama text) returns numeric
language plpgsql set search_path = '' as $$
declare v numeric;
begin
  select k.kasa into v from oyun.bakanlik_kasa k where k.kod = p_kod for update;
  if v is null then raise exception 'Bakanlık kasası bulunamadı.'; end if;
  if v < p_tutar then
    raise exception 'Bakanlık kasasında yeterli ödenek yok (% milyar ₺ gerekli, kasada % milyar ₺ var). Cumhurbaşkanlığından ek ödenek isteyebilirsin.',
      oyun.bm_sayi(p_tutar, 1), oyun.bm_sayi(v, 1);
  end if;
  perform oyun.bm_neden(p_tur, p_aciklama);
  update oyun.bakanlik_kasa set kasa = kasa - p_tutar where kod = p_kod;
  perform oyun.bm_neden(null, null);
  return v - p_tutar;
end $$;

-- İl sakinlerine (son 7 günde oyuna girmiş, en çok 300 kişi) bildirim
create or replace function oyun.bm_il_bildir(p_il smallint, p_metin text, t timestamptz, p_haric uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if p_il is null then return 0; end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
  select x.id, t, p_metin from oyun.profiller x
   where x.il_id = p_il and not x.yasakli and x.id is distinct from p_haric and x.son_gorulme > t - interval '7 days'
   order by x.son_gorulme desc limit 300;
  get diagnostics n = row_count;
  return n;
end $$;

-- Metin kuralları (bağlantı yasağı, uzunluk)
create or replace function oyun.bm_metin(p text, p_alan text, p_min int, p_max int) returns text
language plpgsql immutable set search_path = '' as $$
declare m text := trim(regexp_replace(coalesce(p, ''), '\s+', ' ', 'g'));
begin
  if char_length(m) < p_min or char_length(m) > p_max then
    raise exception '% % ile % karakter arasında olmalı.', p_alan, p_min, p_max;
  end if;
  if m ~* '(https?://|www\.|t\.me/|discord\.gg)' then raise exception '% içinde bağlantı kullanılamaz.', p_alan; end if;
  return m;
end $$;

-- ---------------------------------------------------------------------
-- 4) HESAP DEFTERİ TETİKLEYİCİSİ
-- ---------------------------------------------------------------------
create or replace function oyun.tg_bakanlik_kasa_hareket() returns trigger
language plpgsql security definer set search_path = '' as $$
declare n text := nullif(current_setting('oyun.bk_neden', true), ''); q text; tur text; ac text; d numeric;
begin
  if new.kasa is not distinct from old.kasa then return null; end if;
  d := new.kasa - old.kasa;
  if n is not null then
    tur := split_part(n, '|', 1); ac := substr(n, length(tur) + 2);
  else
    q := lower(coalesce(current_query(), ''));
    tur := case
      when q like '%icraat_yap%' then 'icraat'
      when q like '%kararname_cikar%' then 'odenek'
      when q like '%kamu_butce_dagit%' then 'tahsis'
      when q like '%ihale%' then 'ihale'
      when q like '%rekabet_ac%' or q like '%spk_inceleme%' then 'denetim'
      when q like '%sektor_politika%' then 'tesvik'
      when q like '%adliye%' or q like '%dava%' or q like '%tazminat%' then 'dava'
      when d > 0 then 'gelir' else 'gider' end;
    ac := case tur
      when 'icraat' then 'İcraat bedeli'
      when 'odenek' then 'Kararnameyle ek ödenek (Hazine''den)'
      when 'tahsis' then 'Merkezi bütçe tahsisi (Hazine''den)'
      when 'ihale' then case when d > 0 then 'Kamu ihalesi iadesi' else 'Kamu ihalesi bütçesi' end
      when 'denetim' then 'Denetim / soruşturma gideri'
      when 'tesvik' then 'Sektör teşvik ödemesi'
      when 'dava' then 'Dava, tazminat ya da icra'
      when 'gelir' then 'Kasaya giriş'
      else 'Kasadan çıkış' end;
  end if;
  insert into oyun.bakanlik_hareket(kod, zaman, tutar, bakiye, tur, aciklama, user_id)
  values (new.kod, oyun.simdi(), round(d, 4), round(new.kasa, 4), tur, left(ac, 200), auth.uid());
  return null;
end $$;

do $trg$
begin
  if not exists (select 1 from pg_trigger where tgname = 'bakanlik_kasa_hareket' and tgrelid = 'oyun.bakanlik_kasa'::regclass) then
    create trigger bakanlik_kasa_hareket after update of kasa on oyun.bakanlik_kasa
      for each row execute function oyun.tg_bakanlik_kasa_hareket();
  end if;
end $trg$;

-- ---------------------------------------------------------------------
-- 5) GÜNLÜK ÖDENEK: tavanı aşan pay Hazine'de kalır
-- ---------------------------------------------------------------------
create or replace function oyun.bakanlik_gunluk_odenek(p_cari numeric, p_butce jsonb) returns numeric
language plpgsql security definer set search_path = '' as $$
declare
  tav numeric := coalesce((select a.tavan from oyun.bakanlik_ayar a where a.id = 1), 100);
  r record; pay numeric; yeni numeric; fazla numeric := 0; kalan numeric; t timestamptz := oyun.simdi();
begin
  perform oyun.bm_neden('gunluk', 'Günlük bütçe ödeneği (bütçe kanunu payı)');
  for r in select k.kod, k.kasa from oyun.bakanlik_kasa k order by k.kod for update loop
    pay := round(coalesce(p_cari, 0) * coalesce((p_butce ->> r.kod)::numeric, 0) / 100, 6);
    if pay <= 0 then continue; end if;
    if r.kasa >= tav then yeni := r.kasa; else yeni := least(tav, r.kasa + pay); end if;
    kalan := pay - (yeni - r.kasa);
    if yeni > r.kasa then update oyun.bakanlik_kasa set kasa = yeni where kod = r.kod; end if;
    if kalan > 0.0001 then
      fazla := fazla + kalan;
      insert into oyun.bakanlik_hareket(kod, zaman, tutar, bakiye, tur, aciklama)
      values (r.kod, t, 0, round(yeni, 4), 'tavan',
              format('Kasa tavanda (%s milyar ₺): %s milyar ₺ ödenek Hazine''de kaldı', oyun.bm_sayi(tav, 0), oyun.bm_sayi(kalan, 2)));
    end if;
  end loop;
  perform oyun.bm_neden(null, null);
  return round(fazla, 6);
end $$;

do $gunluk$
declare
  d text;
  eski text := $e$update oyun.bakanlik_kasa k set kasa = least(100, kasa + (h ->> 'cari')::numeric * coalesce((u.butce ->> k.kod)::numeric, 0) / 100);$e$;
  yeni text := $y$u.hazine := u.hazine + oyun.bakanlik_gunluk_odenek((h ->> 'cari')::numeric, u.butce);$y$;
begin
  if to_regprocedure('oyun.gunluk_ekonomi(timestamptz)') is null then return; end if;
  d := pg_get_functiondef('oyun.gunluk_ekonomi(timestamptz)'::regprocedure);
  if position(eski in d) > 0 then
    begin
      execute replace(d, eski, yeni);
    exception when others then
      raise warning 'Günlük ödenek tavan düzeltmesi uygulanamadı: %', sqlerrm;
    end;
  end if;
end $gunluk$;

-- ---------------------------------------------------------------------
-- 6) HAFTALIK GÖREVLER VE KARNE
-- ---------------------------------------------------------------------
create or replace function oyun.bm_gorevler(p_kod text, p_user uuid, t timestamptz) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  h timestamptz := oyun.bm_hafta(t);
  hd date := (h at time zone 'Europe/Istanbul')::date;
  hk text := to_char(h at time zone 'Europe/Istanbul', 'IYYY-IW');
  slotA text[] := array['icraat2', 'il_icraat2', 'butce'];
  slotB text[] := array['etkinlik1', 'katilim5'];
  slotC text[] := array['ziyaret2', 'aciklama1'];
  secim text[]; g text; ilerleme numeric; hedef numeric; ad text; ac text; sonuc jsonb := '[]'::jsonb; alindi boolean;
  gunluk numeric := oyun.bm_gunluk(p_kod);
begin
  secim := array[
    slotA[1 + abs(hashtext(p_kod || hk || 'A')) % 3],
    slotB[1 + abs(hashtext(p_kod || hk || 'B')) % 2],
    slotC[1 + abs(hashtext(p_kod || hk || 'C')) % 2]];
  foreach g in array secim loop
    case g
      when 'icraat2' then
        ad := 'İki icraat başlat'; ac := 'Bu hafta bakanlığından en az iki icraat başlat.'; hedef := 2;
        select count(*) into ilerleme from oyun.icraat_kayit k join oyun.icraatlar i on i.kod = k.kod
         where i.bakanlik = p_kod and k.bakan = p_user and k.zaman >= h;
      when 'il_icraat2' then
        ad := 'İki ilde yerinde hizmet'; ac := 'Bu hafta iki farklı ilde il bazlı icraat yap.'; hedef := 2;
        select count(distinct k.il_id) into ilerleme from oyun.icraat_kayit k join oyun.icraatlar i on i.kod = k.kod
         where i.bakanlik = p_kod and k.bakan = p_user and k.zaman >= h and k.il_id is not null;
      when 'butce' then
        hedef := greatest(3, round(gunluk * 7 * 0.4, 1));
        ad := 'Ödeneği hizmete dönüştür'; ac := format('Bu hafta kasadan en az %s milyar ₺ kamu hizmetine harca (icraat, etkinlik, saha ziyareti, ihale).', oyun.bm_sayi(hedef, 1));
        select coalesce(-sum(x.tutar), 0) into ilerleme from oyun.bakanlik_hareket x
         where x.kod = p_kod and x.zaman >= h and x.tutar < 0 and x.tur in ('icraat', 'etkinlik', 'ziyaret', 'ihale', 'tesvik', 'denetim');
        ilerleme := round(ilerleme, 1);
      when 'etkinlik1' then
        ad := 'Bir etkinlik düzenle'; ac := 'Bu hafta bakanlığın adına bir etkinlik düzenle.'; hedef := 1;
        select count(*) into ilerleme from oyun.bakanlik_etkinlik e where e.bakanlik = p_kod and e.user_id = p_user and e.bas >= h and e.durum <> 'iptal';
      when 'katilim5' then
        ad := 'Halkla buluş'; ac := 'Bu hafta düzenlediğin etkinliklere toplam beş katılım topla.'; hedef := 5;
        select coalesce(sum(e.katilimci), 0) into ilerleme from oyun.bakanlik_etkinlik e where e.bakanlik = p_kod and e.user_id = p_user and e.bas >= h;
      when 'ziyaret2' then
        ad := 'Saha ziyaretleri'; ac := 'Bu hafta iki farklı ilde saha ziyareti yap.'; hedef := 2;
        select count(distinct z.il_id) into ilerleme from oyun.bakanlik_ziyaret z where z.kod = p_kod and z.user_id = p_user and z.zaman >= h;
      when 'aciklama1' then
        ad := 'Kamuoyunu bilgilendir'; ac := 'Bu hafta bir bakanlık açıklaması yayımla.'; hedef := 1;
        select count(*) into ilerleme from oyun.bakanlik_aciklama a where a.kod = p_kod and a.user_id = p_user and a.zaman >= h;
    end case;
    alindi := exists(select 1 from oyun.bakanlik_gorev_odul o where o.kod = p_kod and o.hafta = hd and o.gorev = g);
    sonuc := sonuc || jsonb_build_array(jsonb_build_object('kod', g, 'ad', ad, 'aciklama', ac, 'hedef', hedef,
      'ilerleme', least(ilerleme, hedef), 'tamam', ilerleme >= hedef, 'alindi', alindi));
  end loop;
  return jsonb_build_object('hafta', hd, 'bitis', h + interval '7 days', 'liste', sonuc,
    'odul', (select a.gorev_kidem from oyun.bakanlik_ayar a where a.id = 1),
    'bonus', (select a.gorev_tam_bonus from oyun.bakanlik_ayar a where a.id = 1));
end $$;

create or replace function oyun.bm_karne(p_kod text, t timestamptz) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_bas timestamptz := t - interval '28 days';
  gorev int; icraat int; etk int; katil int; ziy int; cim_top int; cim_y int; soru_top int; soru_y int; harc numeric; oden numeric;
  cevap numeric; puan numeric;
begin
  select count(*) into gorev from oyun.bakanlik_gorev_odul o where o.kod = p_kod and o.zaman > v_bas;
  select count(*) into icraat from oyun.icraat_kayit k join oyun.icraatlar i on i.kod = k.kod where i.bakanlik = p_kod and k.zaman > v_bas;
  select count(*), coalesce(sum(e.katilimci), 0) into etk, katil from oyun.bakanlik_etkinlik e where e.bakanlik = p_kod and e.bas > v_bas and e.durum <> 'iptal';
  select count(*) into ziy from oyun.bakanlik_ziyaret z where z.kod = p_kod and z.zaman > v_bas;
  select count(*), count(*) filter (where c.cevap_at is not null) into cim_top, cim_y
    from oyun.cimer_basvuru c where c.hedef = 'bakanlik' and c.bakanlik = p_kod and c.zaman > v_bas;
  select count(*), count(*) filter (where s.yanit_at is not null) into soru_top, soru_y
    from oyun.bakan_soru s where s.bakanlik = p_kod and s.zaman > v_bas;
  select coalesce(-sum(x.tutar) filter (where x.tutar < 0 and x.tur in ('icraat', 'etkinlik', 'ziyaret', 'ihale', 'tesvik', 'denetim')), 0),
         coalesce(sum(x.tutar) filter (where x.tur = 'gunluk'), 0)
    into harc, oden from oyun.bakanlik_hareket x where x.kod = p_kod and x.zaman > v_bas;
  cevap := case when cim_top + soru_top = 0 then 1 else (cim_y + soru_y)::numeric / (cim_top + soru_top) end;
  puan := round(30 * least(1, gorev / 12.0) + 20 * least(1, icraat / 6.0) + 15 * least(1, etk / 3.0) + 10 * least(1, ziy / 4.0)
               + 15 * cevap + 10 * case when oden > 0 then least(1, harc / oden) else least(1, harc / 10.0) end);
  return jsonb_build_object('puan', puan, 'gorev', gorev, 'icraat', icraat, 'etkinlik', etk, 'katilim', katil, 'ziyaret', ziy,
    'cimer', cim_top, 'cimer_yanit', cim_y, 'soru', soru_top, 'soru_yanit', soru_y,
    'harcama', round(harc, 1), 'odenek', round(oden, 1), 'gun', 28);
end $$;

-- ---------------------------------------------------------------------
-- 7) OKUMA
-- ---------------------------------------------------------------------
create or replace function public.bakanlik_masasi(p_kod text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
  b oyun.bakanliklar; a oyun.bakanlik_ayar; yetki text; kasa numeric; pay numeric; gunluk numeric;
  bakan_u uuid; yurutme uuid := oyun.yurutme_user(); ciz jsonb;
begin
  select * into b from oyun.bakanliklar where kod = p_kod;
  if b.kod is null then raise exception 'Bakanlık bulunamadı.'; end if;
  select * into a from oyun.bakanlik_ayar where id = 1;
  yetki := oyun.bm_yetki(p.id, b.kod);
  select k.kasa into kasa from oyun.bakanlik_kasa k where k.kod = b.kod;
  pay := coalesce(((select u.butce from oyun.ulke u where u.id = 1) ->> b.kod)::numeric, 0);
  gunluk := oyun.bm_gunluk(b.kod);
  bakan_u := oyun.makam_sahibi('bakan', b.kod, null);
  ciz := oyun.bakanlik_panel_json(b.kod, t);
  return jsonb_build_object(
    'kod', b.kod, 'ad', b.ad, 'yetki', yetki, 'simdi', t,
    'bakan', (select jsonb_build_object('kad', x.kad, 'parti', (select jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = x.parti_id),
                                        'bas', (select m.bas from oyun.makamlar m where m.user_id = x.id and m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null))
              from oyun.profiller x where x.id = bakan_u),
    'yurutme', (select x.kad from oyun.profiller x where x.id = yurutme),
    'sistem', case when oyun.hukumet_sistemi() = 1 then 'parlamenter' else 'baskanlik' end,
    'kasa', round(kasa, 2), 'pay', pay, 'gunluk', gunluk, 'tavan', a.tavan,
    'ozet7', (select jsonb_build_object(
                'gelir', round(coalesce(sum(x.tutar) filter (where x.tutar > 0), 0), 2),
                'gider', round(coalesce(-sum(x.tutar) filter (where x.tutar < 0), 0), 2))
              from oyun.bakanlik_hareket x where x.kod = b.kod and x.zaman > t - interval '7 days'),
    'dagilim30', coalesce((select jsonb_agg(jsonb_build_object('tur', g.tur, 'giris', g.giris, 'cikis', g.cikis) order by g.giris + g.cikis desc)
                 from (select x.tur, round(coalesce(sum(x.tutar) filter (where x.tutar > 0), 0), 2) giris,
                              round(coalesce(-sum(x.tutar) filter (where x.tutar < 0), 0), 2) cikis
                         from oyun.bakanlik_hareket x where x.kod = b.kod and x.zaman > t - interval '30 days' group by x.tur) g), '[]'::jsonb),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', x.zaman, 'tutar', round(x.tutar, 3), 'bakiye', round(x.bakiye, 2),
                                   'tur', x.tur, 'aciklama', x.aciklama, 'kim', (select pr.kad from oyun.profiller pr where pr.id = x.user_id)) order by x.zaman desc, x.id desc)
                 from (select * from oyun.bakanlik_hareket h where h.kod = b.kod order by h.zaman desc, h.id desc limit 30) x), '[]'::jsonb),
    'icraatlar', coalesce(ciz -> 'icraatlar', '[]'::jsonb),
    'politikalar', case when yetki is not null then oyun.politika_listesi(b.kod, t) else '[]'::jsonb end,
    'gorevler', case when yetki = 'bakan' then oyun.bm_gorevler(b.kod, p.id, t) end,
    'etkinlik_turleri', coalesce((select jsonb_agg(jsonb_build_object('kod', et.kod, 'ad', et.ad, 'aciklama', et.aciklama, 'maliyet', et.maliyet,
                                   'sure_saat', et.sure_saat, 'il_gerekli', et.il_gerekli, 'etki', et.etki, 'kidem', et.kidem, 'bekleme_saat', et.bekleme_saat,
                                   'hazir', (select max(e.bas) + make_interval(hours => et.bekleme_saat) from oyun.bakanlik_etkinlik e where e.tur = et.kod and e.durum <> 'iptal'))
                                   order by et.sira)
                 from oyun.bakanlik_etkinlik_tur et where et.bakanlik = b.kod), '[]'::jsonb),
    'etkinlikler', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'tur', e.tur, 'ad', et.ad, 'il', (select i.ad from oyun.iller i where i.id = e.il_id),
                                   'bas', e.bas, 'bit', e.bit, 'durum', e.durum, 'katilimci', e.katilimci, 'yerel', e.yerel, 'sonuc', e.sonuc, 'not', e.not_metin,
                                   'aktif', e.durum = 'aktif' and e.bit > t) order by e.bas desc)
                 from (select * from oyun.bakanlik_etkinlik x where x.bakanlik = b.kod order by x.bas desc limit 8) e
                 join oyun.bakanlik_etkinlik_tur et on et.kod = e.tur), '[]'::jsonb),
    'ziyaret', jsonb_build_object('maliyet', a.ziyaret_maliyet, 'bekleme_saat', a.ziyaret_bekleme_saat,
                 'hazir', (select max(z.zaman) + make_interval(hours => a.ziyaret_bekleme_saat) from oyun.bakanlik_ziyaret z where z.kod = b.kod),
                 'son', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'zaman', z.zaman, 'not', z.not_metin, 'kad', pr.kad) order by z.zaman desc)
                          from (select * from oyun.bakanlik_ziyaret x where x.kod = b.kod order by x.zaman desc limit 5) z
                          join oyun.iller i on i.id = z.il_id left join oyun.profiller pr on pr.id = z.user_id), '[]'::jsonb)),
    'aciklama', jsonb_build_object('bekleme_dk', a.aciklama_bekleme_dk,
                 'hazir', (select max(x.zaman) + make_interval(mins => a.aciklama_bekleme_dk) from oyun.bakanlik_aciklama x where x.kod = b.kod),
                 'son', coalesce((select jsonb_agg(jsonb_build_object('baslik', x.baslik, 'metin', x.metin, 'zaman', x.zaman, 'kad', pr.kad) order by x.zaman desc)
                          from (select * from oyun.bakanlik_aciklama y where y.kod = b.kod order by y.zaman desc limit 5) x
                          left join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb)),
    'talepler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tutar', x.tutar, 'gerekce', x.gerekce, 'durum', x.durum, 'zaman', x.zaman,
                                   'bitis', x.bitis, 'karar_zaman', x.karar_zaman, 'karar_not', x.karar_not) order by x.zaman desc)
                 from (select * from oyun.bakanlik_odenek_talep y where y.kod = b.kod order by y.zaman desc limit 6) x), '[]'::jsonb),
    'talep_ayar', jsonb_build_object('ust', a.talep_ust, 'sure_saat', a.talep_sure_saat,
                 'hazir', (select max(x.zaman) + make_interval(hours => a.talep_bekleme_saat) from oyun.bakanlik_odenek_talep x where x.kod = b.kod)),
    'sorumluluk', jsonb_build_object(
                 'cimer_bekleyen', (select count(*) from oyun.cimer_basvuru c where c.hedef = 'bakanlik' and c.bakanlik = b.kod and c.cevap_at is null and c.durum <> 'sonuclandi'),
                 'soru_bekleyen', (select count(*) from oyun.bakan_soru s where s.bakanlik = b.kod and s.yanit_at is null)),
    'karne', oyun.bm_karne(b.kod, t));
end $$;

create or replace function public.bakanlik_etkinlikleri(p_limit int default 30)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object('simdi', t, 'il_id', p.il_id,
    'liste', coalesce((select jsonb_agg(x order by (x ->> 'aktif')::boolean desc, x ->> 'bit' desc) from (
      select jsonb_build_object('id', e.id, 'tur', e.tur, 'ad', et.ad, 'aciklama', et.aciklama, 'bakanlik', e.bakanlik, 'bakanlik_ad', bk.ad,
        'il', i.ad, 'il_id', e.il_id, 'kad', pr.kad, 'not', e.not_metin, 'bas', e.bas, 'bit', e.bit, 'durum', e.durum,
        'aktif', e.durum = 'aktif' and e.bit > t, 'katilimci', e.katilimci, 'yerel', e.yerel, 'kidem', et.kidem, 'sonuc', e.sonuc,
        'benim', (select k.tepki from oyun.bakanlik_etkinlik_katilim k where k.etkinlik_id = e.id and k.user_id = p.id),
        'duzenleyen_benim', e.user_id = p.id,
        'tepkiler', (select jsonb_build_object('katildim', count(*) filter (where k.tepki = 'katildim'),
                                               'destek', count(*) filter (where k.tepki = 'destek'),
                                               'elestiri', count(*) filter (where k.tepki = 'elestiri'))
                       from oyun.bakanlik_etkinlik_katilim k where k.etkinlik_id = e.id)) x
      from oyun.bakanlik_etkinlik e
      join oyun.bakanlik_etkinlik_tur et on et.kod = e.tur
      join oyun.bakanliklar bk on bk.kod = e.bakanlik
      left join oyun.iller i on i.id = e.il_id
      left join oyun.profiller pr on pr.id = e.user_id
      where e.durum <> 'iptal' and (e.bit > t - interval '48 hours')
      order by e.bit desc limit least(greatest(coalesce(p_limit, 30), 1), 60)) y), '[]'::jsonb),
    'bugun_odul', (select count(*) from oyun.bakanlik_etkinlik_katilim k where k.user_id = p.id and k.odul > 0
                     and k.zaman >= (date_trunc('day', t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul')),
    'gunluk_odul', (select a.katilim_gunluk_odul from oyun.bakanlik_ayar a where a.id = 1));
end $$;

create or replace function public.yurutme_butce_masasi()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.bakanlik_ayar; u oyun.ulke; y uuid := oyun.yurutme_user();
begin
  select * into a from oyun.bakanlik_ayar where id = 1;
  select * into u from oyun.ulke where id = 1;
  return jsonb_build_object(
    'simdi', t, 'yetkili', p.id = y, 'cb', exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null),
    'yurutme', (select x.kad from oyun.profiller x where x.id = y),
    'sistem', case when oyun.hukumet_sistemi() = 1 then 'parlamenter' else 'baskanlik' end,
    'hazine', round(u.hazine, 1), 'hesap', oyun.ulke_hesap(u), 'tavan', a.tavan,
    'aktarim_oran', a.aktarim_oran, 'aktarim_bekleme_saat', a.aktarim_bekleme_saat, 'talep_ust', a.talep_ust,
    'son_tahsis', (select max(k.tarih) from oyun.kamu_butce_kararlar k),
    'bakanliklar', (select jsonb_agg(jsonb_build_object(
        'kod', b.kod, 'ad', b.ad, 'kasa', round(k.kasa, 2), 'pay', coalesce((u.butce ->> b.kod)::numeric, 0),
        'gunluk', round((oyun.ulke_hesap(u) ->> 'cari')::numeric * coalesce((u.butce ->> b.kod)::numeric, 0) / 100, 3),
        'bakan', (select x.kad from oyun.makamlar m join oyun.profiller x on x.id = m.user_id where m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null limit 1),
        'harcama7', (select round(coalesce(-sum(h.tutar), 0), 2) from oyun.bakanlik_hareket h where h.kod = b.kod and h.tutar < 0 and h.zaman > t - interval '7 days'),
        'aktarim_hazir', (select max(h.zaman) + make_interval(hours => a.aktarim_bekleme_saat) from oyun.bakanlik_hareket h where h.kod = b.kod and h.tur = 'aktarim' and h.tutar < 0),
        'aktif_etkinlik', exists(select 1 from oyun.bakanlik_etkinlik e where e.bakanlik = b.kod and e.durum = 'aktif' and e.bit > t),
        'puan', (oyun.bm_karne(b.kod, t) ->> 'puan')::numeric) order by b.sira)
      from oyun.bakanliklar b join oyun.bakanlik_kasa k on k.kod = b.kod),
    'talepler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kod', x.kod, 'ad', bk.ad, 'kad', pr.kad, 'tutar', x.tutar, 'gerekce', x.gerekce,
                                   'durum', x.durum, 'zaman', x.zaman, 'bitis', x.bitis, 'karar_zaman', x.karar_zaman, 'karar_not', x.karar_not)
                                   order by (x.durum = 'bekliyor') desc, x.zaman desc)
                 from (select * from oyun.bakanlik_odenek_talep z where z.durum = 'bekliyor' or z.zaman > t - interval '14 days' order by z.zaman desc limit 30) x
                 join oyun.bakanliklar bk on bk.kod = x.kod left join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 8) BÜTÇE İŞLEMLERİ
-- ---------------------------------------------------------------------
create or replace function public.bakanlik_odenek_iste(p_kod text, p_tutar numeric, p_gerekce text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.bakanlik_ayar; g text; tut numeric := round(coalesce(p_tutar, 0), 1);
  son timestamptz; y uuid := oyun.yurutme_user(); bk text;
begin
  if oyun.bm_yetki(p.id, p_kod) is distinct from 'bakan' then raise exception 'Ek ödenek talebini yalnız bakanlığın bakanı yapabilir.'; end if;
  select * into a from oyun.bakanlik_ayar where id = 1;
  if y is null then raise exception 'Görevde onay verecek bir yürütme (Cumhurbaşkanı ya da Başbakan) yok.'; end if;
  if tut < 1 or tut > a.talep_ust then raise exception 'Talep tutarı 1 ile % milyar ₺ arasında olmalı.', a.talep_ust; end if;
  g := oyun.bm_metin(p_gerekce, 'Gerekçe', 10, 400);
  perform 1 from oyun.bakanlik_kasa where kod = p_kod for update;
  if exists(select 1 from oyun.bakanlik_odenek_talep x where x.kod = p_kod and x.durum = 'bekliyor') then
    raise exception 'Bu bakanlığın karar bekleyen bir ek ödenek talebi var.';
  end if;
  select max(x.zaman) into son from oyun.bakanlik_odenek_talep x where x.kod = p_kod;
  if son is not null and son + make_interval(hours => a.talep_bekleme_saat) > t then
    raise exception 'Yeni talep % tarihinden sonra verilebilir.', to_char((son + make_interval(hours => a.talep_bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  insert into oyun.bakanlik_odenek_talep(kod, user_id, tutar, gerekce, zaman, bitis)
  values (p_kod, p.id, tut, g, t, t + make_interval(hours => a.talep_sure_saat));
  select ad into bk from oyun.bakanliklar where kod = p_kod;
  if y <> p.id then
    perform oyun.bildir(y, format('Bakanlık: %s %s, %s milyar ₺ ek ödenek istiyor. Gerekçe: %s (Devlet bütçesi ekranından karar ver.)',
      replace(bk, 'Bakanlığı', 'Bakanı'), p.kad, oyun.bm_sayi(tut, 1), left(g, 160)), t);
  end if;
  return public.bakanlik_masasi(p_kod);
end $$;

create or replace function public.bakanlik_odenek_geri_cek(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x oyun.bakanlik_odenek_talep;
begin
  select * into x from oyun.bakanlik_odenek_talep where id = p_id for update;
  if x.id is null or x.durum <> 'bekliyor' then raise exception 'Karar bekleyen böyle bir talep yok.'; end if;
  if oyun.bm_yetki(p.id, x.kod) is distinct from 'bakan' then raise exception 'Talebi yalnız bakanlığın bakanı geri çekebilir.'; end if;
  update oyun.bakanlik_odenek_talep set durum = 'iptal', karar_zaman = oyun.simdi() where id = x.id;
  return public.bakanlik_masasi(x.kod);
end $$;

create or replace function public.bakanlik_odenek_karar(p_id bigint, p_kabul boolean, p_not text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); x oyun.bakanlik_odenek_talep; hz numeric; bk text; nt text;
  sistem text := case when oyun.hukumet_sistemi() = 1 then 'Başbakan' else 'Cumhurbaşkanı' end;
begin
  if p.id is distinct from oyun.yurutme_user() then raise exception 'Ek ödenek taleplerine yalnız % karar verir.', lower(sistem); end if;
  select * into x from oyun.bakanlik_odenek_talep where id = p_id for update;
  if x.id is null or x.durum <> 'bekliyor' then raise exception 'Karar bekleyen böyle bir talep yok.'; end if;
  if x.bitis <= t then
    update oyun.bakanlik_odenek_talep set durum = 'dusen', karar_zaman = t where id = x.id;
    raise exception 'Talebin süresi dolmuş; düşürüldü.';
  end if;
  nt := nullif(trim(coalesce(p_not, '')), '');
  if nt is not null then nt := oyun.bm_metin(nt, 'Not', 2, 300); end if;
  select ad into bk from oyun.bakanliklar where kod = x.kod;
  if p_kabul then
    select u.hazine into hz from oyun.ulke u where u.id = 1 for update;
    if hz < x.tutar then raise exception 'Hazine''de yeterli kaynak yok (% milyar ₺ var).', oyun.bm_sayi(hz, 1); end if;
    update oyun.ulke set hazine = hazine - x.tutar where id = 1;
    perform oyun.bm_neden('odenek', format('Ek ödenek (%s onayı, talep #%s)', sistem, x.id));
    update oyun.bakanlik_kasa set kasa = kasa + x.tutar where kod = x.kod;
    perform oyun.bm_neden(null, null);
    update oyun.bakanlik_odenek_talep set durum = 'onay', karar_user = p.id, karar_zaman = t, karar_not = nt where id = x.id;
    perform oyun.gazete_ekle('icraat', 'Ek ödenek: ' || bk,
      format('%s %s, %s için %s milyar ₺ ek ödeneği onayladı.%s', sistem, p.kad, bk, oyun.bm_sayi(x.tutar, 1), coalesce(' Not: ' || nt, '')), null, t);
    perform oyun.bildir(x.user_id, format('Bakanlık: %s milyar ₺ ek ödenek talebin onaylandı ve kasaya geçti.%s', oyun.bm_sayi(x.tutar, 1), coalesce(' Not: ' || nt, '')), t);
  else
    update oyun.bakanlik_odenek_talep set durum = 'red', karar_user = p.id, karar_zaman = t, karar_not = nt where id = x.id;
    perform oyun.bildir(x.user_id, format('Bakanlık: %s milyar ₺ ek ödenek talebin reddedildi.%s', oyun.bm_sayi(x.tutar, 1), coalesce(' Gerekçe: ' || nt, '')), t);
  end if;
  return public.yurutme_butce_masasi();
end $$;

create or replace function public.bakanlik_hazineye_iade(p_kod text, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); tut numeric := round(coalesce(p_tutar, 0), 1); bk text;
begin
  if oyun.bm_yetki(p.id, p_kod) is null then raise exception 'Bu bakanlığın kasasını yalnız bakanı (bakan yoksa yürütme vekâleten) yönetir.'; end if;
  if tut < 0.1 then raise exception 'İade tutarı en az 0,1 milyar ₺ olmalı.'; end if;
  perform oyun.bm_kasa_harca(p_kod, tut, 'iade', 'Kullanılmayan ödenek Hazine''ye iade edildi');
  update oyun.ulke set hazine = hazine + tut where id = 1;
  select ad into bk from oyun.bakanliklar where kod = p_kod;
  perform oyun.olay('bakanlik', format('%s kullanmadığı %s milyar ₺ ödeneği Hazine''ye iade etti.', bk, oyun.bm_sayi(tut, 1)), null, p.parti_id, t);
  return public.bakanlik_masasi(p_kod);
end $$;

create or replace function public.bakanlik_odenek_aktar(p_kaynak text, p_hedef text, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.bakanlik_ayar; tut numeric := round(coalesce(p_tutar, 0), 1);
  v_kasa numeric; son timestamptz; ka text; ha text; bk uuid; bh uuid;
  sistem text := case when oyun.hukumet_sistemi() = 1 then 'Başbakan' else 'Cumhurbaşkanı' end;
begin
  if p.id is distinct from oyun.yurutme_user() then raise exception 'Bakanlıklar arası ödenek aktarımını yalnız % yapar.', lower(sistem); end if;
  if p_kaynak = p_hedef then raise exception 'Kaynak ve hedef bakanlık farklı olmalı.'; end if;
  select ad into ka from oyun.bakanliklar where kod = p_kaynak;
  select ad into ha from oyun.bakanliklar where kod = p_hedef;
  if ka is null or ha is null then raise exception 'Bakanlık bulunamadı.'; end if;
  select * into a from oyun.bakanlik_ayar where id = 1;
  select k.kasa into v_kasa from oyun.bakanlik_kasa k where k.kod = p_kaynak for update;
  if tut < 0.5 then raise exception 'Aktarım en az 0,5 milyar ₺ olmalı.'; end if;
  if tut > round(v_kasa * a.aktarim_oran / 100, 1) then
    raise exception 'Bir bakanlığın kasasının en çok %%% kadarı aktarılabilir (bugün en çok % milyar ₺).', oyun.bm_sayi(a.aktarim_oran, 0), oyun.bm_sayi(v_kasa * a.aktarim_oran / 100, 1);
  end if;
  select max(h.zaman) into son from oyun.bakanlik_hareket h where h.kod = p_kaynak and h.tur = 'aktarim' and h.tutar < 0;
  if son is not null and son + make_interval(hours => a.aktarim_bekleme_saat) > t then
    raise exception '% kasasından yeni aktarım % tarihinden sonra yapılabilir.', ka, to_char((son + make_interval(hours => a.aktarim_bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  perform 1 from oyun.bakanlik_kasa where kod = p_hedef for update;
  perform oyun.bm_neden('aktarim', 'Ödenek aktarımı → ' || ha);
  update oyun.bakanlik_kasa set kasa = kasa - tut where kod = p_kaynak;
  perform oyun.bm_neden('aktarim', 'Ödenek aktarımı ← ' || ka);
  update oyun.bakanlik_kasa set kasa = kasa + tut where kod = p_hedef;
  perform oyun.bm_neden(null, null);
  perform oyun.gazete_ekle('icraat', 'Ödenek aktarımı: ' || replace(ka, ' Bakanlığı', '') || ' → ' || replace(ha, ' Bakanlığı', ''),
    format('%s %s, %s kasasından %s kasasına %s milyar ₺ ödenek aktardı.', sistem, p.kad, ka, ha, oyun.bm_sayi(tut, 1)), null, t);
  bk := oyun.makam_sahibi('bakan', p_kaynak, null); bh := oyun.makam_sahibi('bakan', p_hedef, null);
  if bk is not null then perform oyun.bildir(bk, format('Bakanlık: %s, kasandan %s milyar ₺ ödeneği %s''na aktardı.', sistem, oyun.bm_sayi(tut, 1), ha), t); end if;
  if bh is not null then perform oyun.bildir(bh, format('Bakanlık: %s, %s kasasından bakanlığına %s milyar ₺ ödenek aktardı.', sistem, ka, oyun.bm_sayi(tut, 1)), t); end if;
  return public.yurutme_butce_masasi();
end $$;

-- Merkezi bütçe tahsisi: artık 12 bakanlığın hepsine (eski 5 kalemli çağrı da geçerli)
create or replace function public.kamu_butce_dagit(p_toplam numeric, p_paylar jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); total numeric := 0; c record; t timestamptz := oyun.simdi(); n int; pay numeric;
begin
  if u is null or not (exists(select 1 from oyun.makamlar where user_id = u and tur = 'cb' and bit is null) or u = oyun.yurutme_user()) then
    raise exception 'Merkezi bütçeyi yalnız görevdeki Cumhurbaşkanı (parlamenter sistemde Başbakan) dağıtabilir.';
  end if;
  if p_toplam is null or p_toplam < 0.001 or p_toplam > 5 or p_toplam <> round(p_toplam, 3) then
    raise exception 'Dağıtılacak tutar 0,001 ile 5 milyar ₺ arasında olmalı.';
  end if;
  if p_paylar is null or jsonb_typeof(p_paylar) <> 'object' then raise exception 'Bütçe payları geçersiz.'; end if;
  select count(*) into n from jsonb_object_keys(p_paylar);
  if n < 1 or n > 12 then raise exception 'En az bir, en çok 12 bakanlığa pay verilmeli.'; end if;
  for c in select key, value from jsonb_each_text(p_paylar) loop
    if not exists(select 1 from oyun.bakanliklar b where b.kod = c.key) or c.value !~ '^[0-9]+([.][0-9]+)?$' or (c.value)::numeric > 100 then
      raise exception 'Geçersiz bütçe payı: %', c.key;
    end if;
    total := total + (c.value)::numeric;
  end loop;
  if total <> 100 then raise exception 'Bütçe paylarının toplamı %%100 olmalı.'; end if;
  perform pg_advisory_xact_lock(920044, 1);
  if exists(select 1 from oyun.kamu_butce_kararlar where tarih > t - interval '24 hours') then
    raise exception 'Merkezi bütçe en erken 24 saat sonra yeniden dağıtılabilir.';
  end if;
  update oyun.ulke set hazine = hazine - p_toplam where id = 1 and hazine >= p_toplam;
  if not found then raise exception 'Hazine''de yeterli kaynak yok.'; end if;
  for c in select key, value from jsonb_each_text(p_paylar) loop
    pay := round(p_toplam * (c.value)::numeric / 100, 6);
    if pay <= 0 then continue; end if;
    perform oyun.bm_neden('tahsis', 'Merkezi bütçe tahsisi (Hazine''den)');
    update oyun.bakanlik_kasa set kasa = kasa + pay where kod = c.key;
    if not found then raise exception 'Bakanlık kasası eksik: %', c.key; end if;
  end loop;
  perform oyun.bm_neden(null, null);
  insert into oyun.kamu_butce_kararlar(karar_veren, toplam_milyar, paylar, tarih) values (u, p_toplam, p_paylar, t);
  return public.kamu_butce_panel();
end $$;

-- ---------------------------------------------------------------------
-- 9) ETKİNLİK, ZİYARET, AÇIKLAMA, GÖREV ÖDÜLÜ
-- ---------------------------------------------------------------------
create or replace function public.bakanlik_etkinlik_duzenle(p_tur text, p_il int default null, p_not text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); et oyun.bakanlik_etkinlik_tur; yetki text; ilad text; nt text;
  son timestamptz; eid bigint; bk text; unvan text; n int;
begin
  select * into et from oyun.bakanlik_etkinlik_tur where kod = p_tur;
  if et.kod is null then raise exception 'Etkinlik türü bulunamadı.'; end if;
  yetki := oyun.bm_yetki(p.id, et.bakanlik);
  if yetki is null then raise exception 'Bu etkinliği yalnız ilgili bakan (bakan yoksa yürütme vekâleten) düzenleyebilir.'; end if;
  if coalesce(p.susturma_bitis, '-infinity'::timestamptz) > t then raise exception 'Susturma cezan sürerken etkinlik düzenleyemezsin.'; end if;
  if et.il_gerekli then
    select ad into ilad from oyun.iller where id = p_il;
    if ilad is null then raise exception 'Etkinliğin yapılacağı ili seçmelisin.'; end if;
  else p_il := null; end if;
  nt := nullif(trim(coalesce(p_not, '')), '');
  if nt is not null then nt := oyun.bm_metin(nt, 'Davet notu', 3, 200); end if;
  perform 1 from oyun.bakanlik_kasa where kod = et.bakanlik for update;
  if exists(select 1 from oyun.bakanlik_etkinlik e where e.bakanlik = et.bakanlik and e.durum = 'aktif' and e.bit > t) then
    raise exception 'Bakanlığın süren bir etkinliği var; bittikten sonra yenisini düzenleyebilirsin.';
  end if;
  select max(e.bas) into son from oyun.bakanlik_etkinlik e where e.tur = et.kod and e.durum <> 'iptal';
  if son is not null and son + make_interval(hours => et.bekleme_saat) > t then
    raise exception 'Bu etkinlik % tarihinden sonra yeniden düzenlenebilir.', to_char((son + make_interval(hours => et.bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  perform oyun.bm_kasa_harca(et.bakanlik, et.maliyet, 'etkinlik', 'Etkinlik: ' || et.ad || coalesce(' (' || ilad || ')', ''));
  insert into oyun.bakanlik_etkinlik(tur, bakanlik, il_id, user_id, not_metin, bas, bit, maliyet)
  values (et.kod, et.bakanlik, p_il::smallint, p.id, nt, t, t + make_interval(hours => et.sure_saat), et.maliyet) returning id into eid;
  select ad into bk from oyun.bakanliklar where kod = et.bakanlik;
  unvan := case when yetki = 'vekalet' then bk || ' vekâleten ' || p.kad else replace(bk, 'Bakanlığı', 'Bakanı') || ' ' || p.kad end;
  perform oyun.gazete_ekle('icraat', et.ad || coalesce(' — ' || ilad, ''),
    format('%s düzenliyor. %s Katılım %s saat açık; katılan her vatandaş kıdem kazanır.%s', unvan, et.aciklama, et.sure_saat, coalesce(' Not: ' || nt, '')), eid, t);
  perform oyun.olay('bakanlik', format('%s, %s%s etkinliğini başlattı.', unvan, et.ad, coalesce(' (' || ilad || ')', '')), p_il::smallint, p.parti_id, t);
  n := oyun.bm_il_bildir(p_il::smallint, format('Bakanlık: %s ilimizde "%s" düzenliyor. Katıl, kıdem kazan! (Devlet › Bakanlık etkinlikleri)', unvan, et.ad), t, p.id);
  return public.bakanlik_masasi(et.bakanlik) || jsonb_build_object('yeni_etkinlik', eid, 'bildirilen', n);
end $$;

create or replace function public.bakanlik_etkinlik_katil(p_id bigint, p_tepki text default 'katildim')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); e oyun.bakanlik_etkinlik; et oyun.bakanlik_etkinlik_tur; a oyun.bakanlik_ayar;
  tp text := coalesce(nullif(p_tepki, ''), 'katildim'); v_yerel boolean; bugun int; odul numeric := 0;
begin
  if tp not in ('katildim', 'destek', 'elestiri') then raise exception 'Geçersiz tepki.'; end if;
  select * into e from oyun.bakanlik_etkinlik where id = p_id for update;
  if e.id is null or e.durum <> 'aktif' or e.bit <= t then raise exception 'Bu etkinlik sona erdi.'; end if;
  if e.user_id = p.id then raise exception 'Kendi düzenlediğin etkinliğe katılım veremezsin.'; end if;
  if exists(select 1 from oyun.bakanlik_etkinlik_katilim k where k.etkinlik_id = e.id and k.user_id = p.id) then
    update oyun.bakanlik_etkinlik_katilim set tepki = tp where etkinlik_id = e.id and user_id = p.id;
    return jsonb_build_object('odul', 0, 'tepki', tp, 'guncellendi', true);
  end if;
  select * into et from oyun.bakanlik_etkinlik_tur where kod = e.tur;
  select * into a from oyun.bakanlik_ayar where id = 1;
  v_yerel := e.il_id is null or p.il_id = e.il_id;
  select count(*) into bugun from oyun.bakanlik_etkinlik_katilim k where k.user_id = p.id and k.odul > 0
     and k.zaman >= (date_trunc('day', t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul');
  if bugun < a.katilim_gunluk_odul and p.olusturma < t - interval '1 day' then
    odul := case when v_yerel then et.kidem else round(et.kidem / 2, 2) end;
  end if;
  insert into oyun.bakanlik_etkinlik_katilim(etkinlik_id, user_id, zaman, tepki, yerel, odul) values (e.id, p.id, t, tp, v_yerel, odul);
  update oyun.bakanlik_etkinlik set katilimci = katilimci + 1, yerel = yerel + case when v_yerel and e.il_id is not null then 1 else 0 end where id = e.id;
  if odul > 0 then perform oyun.kidem_ekle(p.id, odul); end if;
  return jsonb_build_object('odul', odul, 'tepki', tp, 'yerel', v_yerel,
    'not', case when odul = 0 and p.olusturma >= t - interval '1 day' then 'Yeni hesaplar ilk gün kıdem kazanmaz.'
                when odul = 0 then 'Bugünkü ödüllü katılım hakkın doldu; katılımın yine sayıldı.' end);
end $$;

create or replace function public.bakanlik_saha_ziyareti(p_kod text, p_il int, p_not text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.bakanlik_ayar; yetki text; ilad text; nt text; son timestamptz; bk text; unvan text;
begin
  yetki := oyun.bm_yetki(p.id, p_kod);
  if yetki is null then raise exception 'Saha ziyaretini yalnız bakan (bakan yoksa yürütme vekâleten) yapabilir.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Ziyaret edilecek ili seçmelisin.'; end if;
  nt := nullif(trim(coalesce(p_not, '')), '');
  if nt is not null then nt := oyun.bm_metin(nt, 'Ziyaret notu', 3, 200); end if;
  select * into a from oyun.bakanlik_ayar where id = 1;
  perform 1 from oyun.bakanlik_kasa where kod = p_kod for update;
  select max(z.zaman) into son from oyun.bakanlik_ziyaret z where z.kod = p_kod;
  if son is not null and son + make_interval(hours => a.ziyaret_bekleme_saat) > t then
    raise exception 'Yeni saha ziyareti % tarihinden sonra yapılabilir.', to_char((son + make_interval(hours => a.ziyaret_bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  if exists(select 1 from oyun.bakanlik_ziyaret z where z.kod = p_kod and z.il_id = p_il and z.zaman > t - interval '72 hours') then
    raise exception 'Bakanlık % iline son 72 saatte zaten gitti; başka bir ili seç.', ilad;
  end if;
  perform oyun.bm_kasa_harca(p_kod, a.ziyaret_maliyet, 'ziyaret', 'Saha ziyareti: ' || ilad);
  insert into oyun.bakanlik_ziyaret(kod, user_id, il_id, zaman, not_metin) values (p_kod, p.id, p_il::smallint, t, nt);
  update oyun.il_durum set memnuniyet = oyun.sinir(memnuniyet + 0.5, 0, 100), gelisim = oyun.sinir(gelisim + 0.3, 0, 100) where il_id = p_il;
  select ad into bk from oyun.bakanliklar where kod = p_kod;
  unvan := case when yetki = 'vekalet' then bk || ' vekâleten ' || p.kad else replace(bk, 'Bakanlığı', 'Bakanı') || ' ' || p.kad end;
  perform oyun.gazete_ekle('icraat', 'Saha ziyareti: ' || ilad, format('%s, %s''de vatandaşlarla buluştu, kurumları denetledi.%s', unvan, ilad, coalesce(' ' || nt, '')), null, t);
  perform oyun.olay('bakanlik', format('%s %s''i ziyaret etti.', unvan, ilad), p_il::smallint, p.parti_id, t);
  perform oyun.bm_il_bildir(p_il::smallint, format('Bakanlık: %s ilimizi ziyaret etti.%s', unvan, coalesce(' "' || nt || '"', '')), t, p.id);
  return public.bakanlik_masasi(p_kod);
end $$;

create or replace function public.bakanlik_aciklama_yap(p_kod text, p_baslik text, p_metin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.bakanlik_ayar; yetki text; b text; m text; son timestamptz; bk text; aid bigint;
begin
  yetki := oyun.bm_yetki(p.id, p_kod);
  if yetki is null then raise exception 'Bakanlık adına açıklamayı yalnız bakan (bakan yoksa yürütme vekâleten) yapabilir.'; end if;
  if coalesce(p.susturma_bitis, '-infinity'::timestamptz) > t or coalesce(p.adliye_susturma_bitis, '-infinity'::timestamptz) > t then
    raise exception 'Susturma cezan sürerken açıklama yapamazsın.';
  end if;
  b := oyun.bm_metin(p_baslik, 'Başlık', 3, 120);
  m := oyun.bm_metin(p_metin, 'Açıklama', 10, 1200);
  select * into a from oyun.bakanlik_ayar where id = 1;
  select max(x.zaman) into son from oyun.bakanlik_aciklama x where x.kod = p_kod;
  if son is not null and son + make_interval(mins => a.aciklama_bekleme_dk) > t then
    raise exception 'Yeni bakanlık açıklaması % tarihinden sonra yapılabilir.', to_char((son + make_interval(mins => a.aciklama_bekleme_dk)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  insert into oyun.bakanlik_aciklama(kod, user_id, baslik, metin, zaman) values (p_kod, p.id, b, m, t) returning id into aid;
  select ad into bk from oyun.bakanliklar where kod = p_kod;
  perform oyun.gazete_ekle('duyuru', bk || ': ' || b, m || E'\n— ' || case when yetki = 'vekalet' then 'Vekâleten ' || p.kad else replace(bk, 'Bakanlığı', 'Bakanı') || ' ' || p.kad end, aid, t);
  perform oyun.olay('bakanlik', format('%s açıklama yaptı: %s', bk, b), null, p.parti_id, t);
  return public.bakanlik_masasi(p_kod);
end $$;

create or replace function public.bakanlik_gorev_odul_al(p_kod text, p_gorev text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.bakanlik_ayar; g jsonb; x jsonb; hd date; n int; bk text; ek numeric := 0;
begin
  if oyun.bm_yetki(p.id, p_kod) is distinct from 'bakan' then raise exception 'Haftalık görev ödülünü yalnız bakanlığın bakanı alabilir.'; end if;
  select * into a from oyun.bakanlik_ayar where id = 1;
  perform 1 from oyun.bakanlik_kasa where kod = p_kod for update;
  g := oyun.bm_gorevler(p_kod, p.id, t);
  hd := (g ->> 'hafta')::date;
  select v into x from jsonb_array_elements(g -> 'liste') v where v ->> 'kod' = p_gorev;
  if x is null then raise exception 'Bu görev bu haftanın görevleri arasında değil.'; end if;
  if (x ->> 'alindi')::boolean then raise exception 'Bu görevin ödülü zaten alındı.'; end if;
  if not (x ->> 'tamam')::boolean then raise exception 'Görev henüz tamamlanmadı.'; end if;
  insert into oyun.bakanlik_gorev_odul(kod, hafta, gorev, user_id, zaman, kidem) values (p_kod, hd, p_gorev, p.id, t, a.gorev_kidem);
  perform oyun.kidem_ekle(p.id, a.gorev_kidem);
  select count(*) into n from oyun.bakanlik_gorev_odul o where o.kod = p_kod and o.hafta = hd;
  if n = 3 then
    ek := a.gorev_tam_bonus;
    perform oyun.kidem_ekle(p.id, ek);
    update oyun.bakanlik_gorev_odul set kidem = kidem + ek where kod = p_kod and hafta = hd and gorev = p_gorev;
    select ad into bk from oyun.bakanliklar where kod = p_kod;
    perform oyun.gazete_ekle('icraat', 'Haftanın hedefleri tamam: ' || bk,
      format('%s %s, bakanlığın bu haftaki üç hedefinin tamamına ulaştı.', replace(bk, 'Bakanlığı', 'Bakanı'), p.kad), null, t);
  end if;
  return public.bakanlik_masasi(p_kod) || jsonb_build_object('kazanilan', a.gorev_kidem + ek);
end $$;

-- ---------------------------------------------------------------------
-- 10) ZAMANLAYICI: biten etkinlikler, süresi dolan talepler
-- ---------------------------------------------------------------------
create or replace function oyun.bakanlik_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare
  t timestamptz := oyun.simdi(); e record; f numeric; k text; v jsonb; ulusal jsonb; ilm numeric; n int := 0; x record;
begin
  for e in select be.*, et.ad tur_ad, et.etki, bk.ad bk_ad, i.ad il_ad
             from oyun.bakanlik_etkinlik be
             join oyun.bakanlik_etkinlik_tur et on et.kod = be.tur
             join oyun.bakanliklar bk on bk.kod = be.bakanlik
             left join oyun.iller i on i.id = be.il_id
            where be.durum = 'aktif' and be.bit <= t
            order by be.bit limit 50 loop
    begin
      f := least(2.0, 0.5 + 0.15 * e.katilimci);
      ulusal := '{}'::jsonb; ilm := 0;
      for k, v in select key, value from jsonb_each(e.etki) loop
        if k = 'il_memnuniyet' then ilm := round((v #>> '{}')::numeric * f, 3);
        else ulusal := ulusal || jsonb_build_object(k, round((v #>> '{}')::numeric * f, 3)); end if;
      end loop;
      perform oyun.etki_uygula(ulusal, e.il_id);
      if e.il_id is not null and ilm <> 0 then
        update oyun.il_durum set memnuniyet = oyun.sinir(memnuniyet + ilm, 0, 100) where il_id = e.il_id;
      end if;
      update oyun.bakanlik_etkinlik set durum = 'bitti',
        sonuc = jsonb_build_object('carpan', f, 'etki', ulusal, 'il_memnuniyet', ilm, 'katilimci', e.katilimci, 'yerel', e.yerel)
       where id = e.id;
      perform oyun.gazete_ekle('icraat', e.tur_ad || ' tamamlandı' || coalesce(' — ' || e.il_ad, ''),
        format('%s tarafından düzenlenen %s %s katılımcıyla tamamlandı. Etki çarpanı ×%s.', e.bk_ad, e.tur_ad, e.katilimci, oyun.bm_sayi(f, 2)), e.id, t);
      perform oyun.bildir(e.user_id, format('Bakanlık: "%s" %s katılımcıyla tamamlandı (etki ×%s).', e.tur_ad, e.katilimci, oyun.bm_sayi(f, 2)), t);
      n := n + 1;
    exception when others then
      perform oyun.bildir(e.user_id, 'Bakanlık: etkinlik kapanışında bir sorun oluştu; yönetici bilgilendirildi.', t);
      update oyun.bakanlik_etkinlik set durum = 'bitti', sonuc = jsonb_build_object('hata', left(sqlerrm, 200)) where id = e.id;
    end;
  end loop;
  for x in select * from oyun.bakanlik_odenek_talep where durum = 'bekliyor' and bitis <= t for update skip locked loop
    update oyun.bakanlik_odenek_talep set durum = 'dusen', karar_zaman = t where id = x.id;
    perform oyun.bildir(x.user_id, format('Bakanlık: %s milyar ₺ ek ödenek talebin süresi içinde karara bağlanmadığı için düştü.', oyun.bm_sayi(x.tutar, 1)), t);
  end loop;
  return n;
end $$;

do $zam$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira)
    select 'bakanlik_masasi', 'select oyun.bakanlik_tick()', 5, 2, 48
     where not exists (select 1 from oyun.zamanlayici_adim z where z.adim = 'bakanlik_masasi');
  end if;
end $zam$;

-- ---------------------------------------------------------------------
-- 11) YETKİLER
-- ---------------------------------------------------------------------
do $yetki$
declare f text;
begin
  foreach f in array array[
    'public.bakanlik_masasi(text)', 'public.bakanlik_etkinlikleri(int)', 'public.yurutme_butce_masasi()',
    'public.bakanlik_odenek_iste(text,numeric,text)', 'public.bakanlik_odenek_geri_cek(bigint)', 'public.bakanlik_odenek_karar(bigint,boolean,text)',
    'public.bakanlik_hazineye_iade(text,numeric)', 'public.bakanlik_odenek_aktar(text,text,numeric)', 'public.kamu_butce_dagit(numeric,jsonb)',
    'public.bakanlik_etkinlik_duzenle(text,int,text)', 'public.bakanlik_etkinlik_katil(bigint,text)', 'public.bakanlik_saha_ziyareti(text,int,text)',
    'public.bakanlik_aciklama_yap(text,text,text)', 'public.bakanlik_gorev_odul_al(text,text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array[
    'oyun.bm_yetki(uuid,text)', 'oyun.bm_neden(text,text)', 'oyun.bm_sayi(numeric,int)', 'oyun.bm_hafta(timestamptz)', 'oyun.bm_gunluk(text)',
    'oyun.bm_kasa_harca(text,numeric,text,text)', 'oyun.bm_il_bildir(smallint,text,timestamptz,uuid)', 'oyun.bm_metin(text,text,int,int)',
    'oyun.tg_bakanlik_kasa_hareket()', 'oyun.bakanlik_gunluk_odenek(numeric,jsonb)', 'oyun.bm_gorevler(text,uuid,timestamptz)',
    'oyun.bm_karne(text,timestamptz)', 'oyun.bakanlik_tick()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $yetki$;
