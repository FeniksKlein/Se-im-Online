-- Seçim Simülasyonu Online — Rekabetçi şirketler (okul/hastane/market/ulaşım/enerji), kamu ihaleleri, sektör politikası ve ruhsat harcı.
-- Kaynak: gelistirici/sql/84_ekonomi_pazar_ihale.sql. Yalnız ekler; iki kez çalıştırılabilir.
begin;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 84) Rekabetçi şirketler, kamu ihaleleri, sektör politikası
--
--  Sorun: eski şirketlerin kazancı yalnız "sermaye × sektör oranı × zar" idi. Sahibin kararı,
--  oyuncular arası rekabet ve siyasetin etkisi yoktu.
--
--  1) REKABETÇİ ŞİRKETLER (5 yeni tür): Özel Okul, Özel Hastane, Market Zinciri, Ulaşım Firması,
--     Enerji Santrali. Şirket bir ilde faaliyet gösterir. Sahibi fiyat (ucuz/orta/premium) ve
--     kalite bütçesi (0-3) seçer; enerjide kaynak (kömür/doğalgaz/yenilenebilir) seçer.
--     O ilin haftalık pazarı aynı türdeki oyuncu şirketleri arasında çekiciliğe göre paylaşılır:
--       pazar  = sektör tabanı × il ağırlığı (vekil sayısı + gelişmişlik) × ekonomi × sektör politikası
--       çekicilik = (1 + 0,35×kalite + marka/100) / fiyat^esneklik
--       pay    = çekicilik / (kamu seçeneği + Σ çekicilik)
--     Tek başına bir ilde ~%7-10/hafta kazanır, iki rakip ~%1, kalabalık ilde zarar eder.
--     Kamu seçeneği ilgili bakanlığın kasasıyla büyür (güçlü devlet okulu → özel okula talep az).
--     Gelir sermayenin kapasitesiyle sınırlıdır (İstanbul pazarı büyük sermaye ister).
--     Giderler: sabit gider + kalite bütçesi + personel (asgari ücrete bağlı) + kaynak maliyeti.
--     Kâr vergisi (kurumlar vergisi %20) hazineye, belediye ruhsat harcı il kasasına gider.
--     Kasası sıfırlanan şirket iflas eder. Her faaliyet ilin gelişmişliğine küçük katkı yapar.
--
--  2) KAMU İHALELERİ: Belediye başkanı belediye kasasından, bakan bakanlık kasasından ihale açar
--     (yol, park, metro, şehir hastanesi, okul, OSB…). Bütçe açılışta kasadan ayrılır.
--     İnşaat şirketleri kapalı zarfla teklif verir; en düşük geçerli teklif kazanır, artan para
--     kamu kasasına döner. Kazanan yapım yöntemini seçer:
--       standart (maliyet %70) · kaliteli (%85, etki ×1,35) · tasarruflu (%55, etki ×0,6, denetim riski)
--     Tasarruflu iş denetimde yakalanırsa: hakedişin yarısı ödenmez, %20 ceza, 14 gün ihale yasağı,
--     gazete manşeti. İhaleyi açan, ortağı olduğu şirkete ihale veremez (çıkar çatışması).
--     Teslim edilen iş ile şirket "iş deneyimi" kazanır; metro gibi büyük işler deneyim ister.
--
--  3) SEKTÖR POLİTİKASI: İlgili bakan kendi sektörüne 7 günlük teşvik (pazar ×1,15; bakanlık
--     kasasından 2 milyar ₺) ya da sıkı denetim (pazar ×0,92; kalitesiz ve kömürlü şirkete ceza)
--     uygular. Eski şirket türlerine de işler (Tarım Bakanı → tarım şirketleri vb.).
--     Belediye başkanı ilindeki rekabetçi şirketlere %0-8 ruhsat harcı koyar.
--
--  Para ölçeği: devlet kasaları milyar ₺ (16 milyonluk ülke), oyuncu parası ₺. Dönüşüm
--  oyun.pazar_ayar.tl_milyar (1 milyar kamu ₺ = 150.000 oyuncu ₺ × fiyat düzeyi).
--  Yalnız ekler; eski şirketler, eski RPC'ler ve oyuncu verisi aynen kalır.
-- =====================================================================

-- Yerel testte kriz modülü yoksa nötr çarpan (canlıda gerçeği var, ona dokunulmaz)
do $$ begin
  if to_regprocedure('oyun.kriz_sektor_carpani(text,timestamptz)') is null then
    execute $f$create function oyun.kriz_sektor_carpani(p_sektor text, p_tarih timestamptz) returns numeric
      language sql stable as 'select 1::numeric'$f$;
  end if;
end $$;

-- ---------------------------------------------------------------- ayarlar ve kataloglar
create table if not exists oyun.pazar_ayar(
  id           int primary key default 1 check (id = 1),
  tl_milyar    numeric not null default 150000, -- 1 milyar kamu ₺ = bu kadar oyuncu ₺ (fiyat düzeyiyle çarpılır)
  kurumlar     numeric not null default 20,     -- kurumlar vergisi %
  tesvik_bedel numeric not null default 2,      -- teşvikin bakanlık kasasına maliyeti (milyar ₺)
  politika_gun int not null default 7
);
insert into oyun.pazar_ayar(id) values (1) on conflict do nothing;

create table if not exists oyun.pazar_sektor(
  kod         text primary key,
  ad          text not null,
  bakanlik    text not null,
  taban       numeric not null,   -- il ağırlığı 1 iken haftalık toplam harcama (₺)
  esneklik    numeric not null,   -- fiyat duyarlılığı
  dis         numeric not null,   -- kamu / dış seçenek gücü
  sabit       numeric not null,   -- haftalık sabit gider (sermaye oranı)
  kapasite    numeric not null,   -- haftalık azami gelir (sermaye oranı)
  personel    numeric not null,   -- personel gideri (asgari ücret katı, 400 bin sermayede)
  min_sermaye numeric not null default 200000,
  sira        int not null,
  aciklama    text not null
);
insert into oyun.pazar_sektor values
 ('ozel_okul',    'Özel Okul',       'egitim',    150000, 0.7, 1.2, 0.045, 0.25, 1.0, 200000, 1,
  'Veliler kaliteye fiyattan çok bakar; premium ve kaliteli okul iyi kazanır. Devlet okulları güçlüyse (Millî Eğitim kasası dolu) talep azalır.'),
 ('ozel_hastane', 'Özel Hastane',    'saglik',    175000, 0.9, 1.0, 0.050, 0.25, 1.3, 250000, 2,
  'Hasta kalite ve markaya güvenir. Personel gideri yüksektir. Kamu hastaneleri güçlüyse talep azalır.'),
 ('market',       'Market Zinciri',  'ticaret',   140000, 2.2, 0.6, 0.040, 0.30, 1.1, 200000, 3,
  'Müşteri fiyata çok duyarlıdır; ucuz market rakibin müşterisini çeker. Fiyat savaşı herkesi zarara sokabilir.'),
 ('ulasim',       'Ulaşım Firması',  'ulastirma', 140000, 1.6, 0.9, 0.050, 0.25, 0.9, 200000, 4,
  'Otobüs ve şehirlerarası taşımacılık. Fiyat ve konfor birlikte önemlidir.'),
 ('enerji',       'Enerji Santrali', 'sanayi',    125000, 2.6, 0.6, 0.050, 0.30, 0.7, 300000, 5,
  'Elektrik herkes için aynıdır; fiyat belirleyicidir. Kaynak seçimi gideri ve ili etkiler: kömür ucuz ama kirletir, doğalgaz dolara bağlı, yenilenebilir pahalı ama ili geliştirir. Talep ekonomik büyümeyle artar.')
on conflict (kod) do update set ad = excluded.ad, bakanlik = excluded.bakanlik, taban = excluded.taban, esneklik = excluded.esneklik,
  dis = excluded.dis, sabit = excluded.sabit, kapasite = excluded.kapasite, personel = excluded.personel,
  min_sermaye = excluded.min_sermaye, sira = excluded.sira, aciklama = excluded.aciklama;

-- Hangi bakan hangi sektörün politikasını belirler (eski türler dahil)
create table if not exists oyun.sektor_yetki(
  sektor   text primary key,
  bakanlik text not null,
  ad       text not null
);
insert into oyun.sektor_yetki values
 ('tarim','tarim','Tarım'), ('sanayi','sanayi','Sanayi'), ('teknoloji','sanayi','Teknoloji'), ('ticaret','ticaret','Ticaret'),
 ('insaat','ulastirma','İnşaat'), ('ozel_okul','egitim','Özel Okul'), ('ozel_hastane','saglik','Özel Hastane'),
 ('market','ticaret','Market Zinciri'), ('ulasim','ulastirma','Ulaşım Firması'), ('enerji','sanayi','Enerji Santrali')
on conflict (sektor) do update set bakanlik = excluded.bakanlik, ad = excluded.ad;

-- Şirket türü listesi yalnız genişler (eskiler aynen kalır)
alter table oyun.sirketler drop constraint if exists sirketler_sektor_check;
alter table oyun.sirketler add constraint sirketler_sektor_check check (sektor in
  ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka','ozel_okul','ozel_hastane','market','ulasim','enerji'));

-- ---------------------------------------------------------------- rekabetçi şirket tabloları
create table if not exists oyun.pazar_sirket(
  sirket_id   bigint primary key references oyun.sirketler(id),
  il_id       smallint not null references oyun.iller(id),
  fiyat       smallint not null default 2 check (fiyat between 1 and 3),
  kalite      smallint not null default 1 check (kalite between 0 and 3),
  kaynak      text check (kaynak in ('komur','dogalgaz','yenilenebilir')),
  marka       numeric not null default 10,
  son_ayar    timestamptz,
  son_tasima  timestamptz,
  son_uyari   timestamptz,
  hafta       int not null default 0
);
create index if not exists pazar_sirket_il on oyun.pazar_sirket(il_id);

create table if not exists oyun.pazar_rapor(
  id         bigserial primary key,
  sirket_id  bigint not null references oyun.sirketler(id),
  zaman      timestamptz not null,
  il_id      smallint not null,
  pazar      numeric not null,
  pay        numeric not null,
  rakip      int not null,
  gelir      numeric not null,
  gider      numeric not null,
  ruhsat     numeric not null,
  vergi      numeric not null,
  ceza       numeric not null default 0,
  net        numeric not null,
  fiyat      smallint, kalite smallint, kaynak text
);
create index if not exists pazar_rapor_sirket on oyun.pazar_rapor(sirket_id, zaman desc);

create table if not exists oyun.sektor_politika(
  sektor       text primary key,
  durum        text not null default 'normal' check (durum in ('normal','tesvik','denetim')),
  belirleyen   uuid,
  bas          timestamptz,
  bit          timestamptz,
  son_degisim  timestamptz
);

create table if not exists oyun.il_ruhsat(
  il_id       smallint primary key references oyun.iller(id),
  oran        numeric not null default 0 check (oran between 0 and 8),
  belirleyen  uuid,
  son_degisim timestamptz,
  toplam      numeric not null default 0     -- bugüne kadar kasaya giren (oyuncu ₺)
);

-- ---------------------------------------------------------------- kamu ihalesi tabloları
create table if not exists oyun.kamu_ihale_proje(
  kod        text primary key,
  ad         text not null,
  kurum      text not null check (kurum in ('belediye','bakanlik')),
  bakanlik   text,
  carpan     numeric not null,   -- belediye: il günlük geliri katı · bakanlık: milyar ₺
  sure_gun   int not null,
  gelisim    numeric not null default 0,
  memnuniyet numeric not null default 0,
  deneyim    int not null default 0,   -- kazanan şirketin en az iş deneyimi
  aciklama   text not null,
  sira       int not null
);
insert into oyun.kamu_ihale_proje values
 ('park',      'Park ve yeşil alan',            'belediye', null,        3, 2, 0,   3, 0, 'Mahalle parkı, çocuk oyun alanı, yürüyüş yolu.', 1),
 ('kres',      'Kreş ve sosyal tesis',          'belediye', null,        4, 3, 0.5, 2, 0, 'Çalışan ebeveynlere kreş, yaşlılara gündüz bakım evi.', 2),
 ('yol',       'Yol ve asfalt yenileme',        'belediye', null,        5, 3, 1,   2, 0, 'Bozuk yollar, kaldırımlar ve kavşaklar yenilenir.', 3),
 ('metro',     'Raylı sistem / metro hattı',    'belediye', null,       12, 5, 3,   3, 1, 'Büyük ulaşım yatırımı; en az bir işi teslim etmiş şirket girebilir.', 4),
 ('otoyol',    'Otoyol ve bölünmüş yol',        'bakanlik', 'ulastirma', 5, 4, 3,   1, 0, 'İli ülkeye bağlayan yol yatırımı.', 10),
 ('hastane',   'Şehir hastanesi',               'bakanlik', 'saglik',    6, 4, 1,   4, 0, 'Büyük kamu hastanesi.', 11),
 ('okul',      'Okul ve derslik yapımı',        'bakanlik', 'egitim',    4, 3, 2,   1, 0, 'Yeni okul binaları ve derslikler.', 12),
 ('osb',       'Organize sanayi bölgesi',       'bakanlik', 'sanayi',    5, 4, 3,   0, 0, 'Fabrikalar için altyapı; il hızla gelişir.', 13),
 ('sulama',    'Baraj ve sulama kanalı',        'bakanlik', 'tarim',     4, 4, 2,   1, 0, 'Çiftçiye su; tarım bölgesi gelişir.', 14),
 ('emniyet',   'Emniyet ve jandarma binası',    'bakanlik', 'icisleri',  3, 3, 0,   2, 0, 'Asayiş hizmet binası.', 15),
 ('adliye',    'Adliye sarayı',                 'bakanlik', 'adalet',    3, 3, 0.5, 1, 0, 'Mahkemeler için yeni bina.', 16),
 ('meslek',    'Meslek eğitim merkezi',         'bakanlik', 'calisma',   3, 3, 1,   1, 0, 'İşsizlere meslek kursları.', 17),
 ('liman',     'Lojistik merkezi ve gümrük',    'bakanlik', 'ticaret',   4, 4, 2,   1, 0, 'Ticaret ve ihracat altyapısı.', 18),
 ('kisla',     'Askerî tesis yenileme',         'bakanlik', 'savunma',   4, 3, 1,   0, 0, 'Garnizon ve lojman yenileme.', 19),
 ('konsolos',  'Uluslararası kongre merkezi',   'bakanlik', 'disisleri', 3, 3, 1,   1, 0, 'Zirve ve fuarlara ev sahipliği.', 20),
 ('vergi_bina','Vergi dairesi ve defterdarlık', 'bakanlik', 'maliye',    3, 3, 0.5, 1, 0, 'Maliye hizmet binası.', 21)
on conflict (kod) do update set ad = excluded.ad, kurum = excluded.kurum, bakanlik = excluded.bakanlik, carpan = excluded.carpan,
  sure_gun = excluded.sure_gun, gelisim = excluded.gelisim, memnuniyet = excluded.memnuniyet, deneyim = excluded.deneyim,
  aciklama = excluded.aciklama, sira = excluded.sira;

create table if not exists oyun.kamu_ihale(
  id          bigserial primary key,
  proje       text not null references oyun.kamu_ihale_proje(kod),
  kurum       text not null check (kurum in ('belediye','bakanlik')),
  il_id       smallint not null references oyun.iller(id),
  bakanlik    text,
  acan        uuid not null,
  butce       numeric not null,          -- milyar ₺ (kamu kasasından ayrıldı)
  tavan       numeric not null,          -- en yüksek teklif (oyuncu ₺)
  bas         timestamptz not null,
  bit         timestamptz not null,      -- teklif son anı
  durum       text not null default 'acik' check (durum in ('acik','yapim','tamam','teklifsiz','iptal')),
  kazanan     bigint references oyun.sirketler(id),
  bedel       numeric,
  maliyet     numeric,
  yontem      text not null default 'standart' check (yontem in ('standart','kaliteli','tasarruflu')),
  teslim_at   timestamptz,
  sonuc       text,                      -- 'teslim', 'yakalandi'
  teklif_say  int not null default 0
);
create index if not exists kamu_ihale_durum on oyun.kamu_ihale(durum, bit);

create table if not exists oyun.kamu_ihale_teklif(
  ihale_id  bigint not null references oyun.kamu_ihale(id),
  sirket_id bigint not null references oyun.sirketler(id),
  veren     uuid not null,
  tutar     numeric not null,
  zaman     timestamptz not null,
  primary key (ihale_id, sirket_id)
);

create table if not exists oyun.sirket_deneyim(
  sirket_id  bigint primary key references oyun.sirketler(id),
  is_sayisi  int not null default 0,
  puan       int not null default 0,
  yasak_bit  timestamptz
);

do $$ declare t text; begin
  foreach t in array array['pazar_ayar','pazar_sektor','sektor_yetki','pazar_sirket','pazar_rapor','sektor_politika','il_ruhsat',
                           'kamu_ihale_proje','kamu_ihale','kamu_ihale_teklif','sirket_deneyim'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
  revoke all on sequence oyun.pazar_rapor_id_seq, oyun.kamu_ihale_id_seq from public, anon, authenticated;
end $$;

-- ---------------------------------------------------------------- yardımcılar
create or replace function oyun.pazar_tl_milyar() returns numeric language sql stable set search_path = '' as $$
  select a.tl_milyar * coalesce(u.endeks, 1) from oyun.pazar_ayar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;

-- İl ağırlığı: vekil sayısı (nüfus) ve gelişmişlik
create or replace function oyun.pazar_il_agirlik(p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select (0.4 + i.mv / 24.0) * (0.6 + coalesce(d.gelisim, 50) / 125.0)
  from oyun.iller i left join oyun.il_durum d on d.il_id = i.id where i.id = p_il
$$;

-- Sektör politikası çarpanı (süresi dolan politika normal sayılır)
create or replace function oyun.sektor_pol_durum(p_sektor text, t timestamptz) returns text language sql stable set search_path = '' as $$
  select coalesce((select durum from oyun.sektor_politika where sektor = p_sektor and bit > t), 'normal')
$$;
create or replace function oyun.sektor_pol_carpan(p_sektor text, t timestamptz) returns numeric language sql stable set search_path = '' as $$
  select case oyun.sektor_pol_durum(p_sektor, t) when 'tesvik' then 1.15 when 'denetim' then 0.92 else 1 end
$$;

create or replace function oyun.pazar_fiyat_katsayi(f smallint) returns numeric language sql immutable set search_path = '' as $$
  select case f when 1 then 0.8 when 3 then 1.3 else 1.0 end
$$;

-- Bir şirketin haftalık sonucunu (gürültüsüz) hesaplar. Ayar denemesi için fiyat/kalite/kaynak
-- geçici olarak değiştirilebilir (null = mevcut). Hiçbir şey yazmaz.
create or replace function oyun.pazar_tahmin(p_sirket bigint, p_fiyat smallint default null, p_kalite smallint default null,
  p_kaynak text default null, t timestamptz default null) returns jsonb
language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler; ps oyun.pazar_sirket; k oyun.pazar_sektor; u oyun.ulke; zt timestamptz := coalesce(t, oyun.simdi());
  v_f smallint; v_k smallint; v_kay text; w numeric; makro numeric; pol numeric; pazar numeric; dis numeric; kamu numeric;
  ben numeric; toplam numeric; pay numeric; gelir numeric; kap numeric; gider numeric; personel numeric; ruh numeric; ruhsat numeric;
  vergi numeric; net numeric; ceza numeric := 0; kalite_gid numeric; kaynak_gid numeric := 0; rakip int; usd numeric; pold text;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  select * into k from oyun.pazar_sektor where kod = s.sektor;
  if s.id is null or ps.sirket_id is null or k.kod is null then return null; end if;
  select * into u from oyun.ulke where id = 1;
  v_f := coalesce(p_fiyat, ps.fiyat); v_k := coalesce(p_kalite, ps.kalite);
  v_kay := case when s.sektor = 'enerji' then coalesce(p_kaynak, ps.kaynak, 'dogalgaz') else null end;

  w := oyun.pazar_il_agirlik(ps.il_id);
  makro := case when s.sektor = 'enerji' then oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.06, 0.7, 1.4)
                else oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.03 + (coalesce(u.memnuniyet, 50) - 50) * 0.004, 0.8, 1.25) end;
  pold := oyun.sektor_pol_durum(s.sektor, zt);
  pol := case pold when 'tesvik' then 1.15 when 'denetim' then 0.92 else 1 end;
  pazar := k.taban * w * makro * pol * oyun.kriz_sektor_carpani(s.sektor, zt);

  -- kamu seçeneği: ilgili bakanlığın kasası doluysa devlet hizmeti güçlü
  kamu := coalesce((select kasa from oyun.bakanlik_kasa where kod = k.bakanlik), 20);
  dis := k.dis * (0.85 + least(greatest(kamu, 0), 60) / 100.0);

  ben := (1 + 0.35 * v_k + ps.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(v_f), k.esneklik);
  select coalesce(sum((1 + 0.35 * p2.kalite + p2.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p2.fiyat), k.esneklik)), 0), count(*)
    into toplam, rakip
  from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
  where p2.il_id = ps.il_id and s2.sektor = s.sektor and s2.aktif and p2.sirket_id <> s.id;
  pay := ben / (dis + toplam + ben);
  kap := s.sermaye * k.kapasite;
  gelir := least(pazar * pay * oyun.pazar_fiyat_katsayi(v_f), kap);

  personel := coalesce(u.asgari, 30000) * k.personel * power(greatest(0.5, s.sermaye / 400000.0), 0.7);
  kalite_gid := s.sermaye * case v_k when 1 then 0.01 when 2 then 0.022 when 3 then 0.036 else 0 end;
  gider := s.sermaye * k.sabit;
  if v_kay = 'komur' then gider := gider * 0.75;
  elsif v_kay = 'dogalgaz' then
    usd := coalesce((select fiyat from oyun.piyasa_varlik where kod = 'USD'), 42);
    kaynak_gid := s.sermaye * 0.015 * usd / 42.0;
  elsif v_kay = 'yenilenebilir' then gider := gider + s.sermaye * 0.02;
  end if;
  gider := gider + personel + kalite_gid + kaynak_gid;

  -- sıkı denetim: kalitesiz hizmete ve kömüre ceza
  if pold = 'denetim' and (v_k = 0 or v_kay = 'komur') then ceza := gelir * 0.12; end if;
  ruh := coalesce((select oran from oyun.il_ruhsat where il_id = ps.il_id), 0);
  ruhsat := gelir * ruh / 100;
  net := gelir - gider - ruhsat - ceza;
  vergi := greatest(0, net) * (select kurumlar from oyun.pazar_ayar where id = 1) / 100;
  net := net - vergi;
  return jsonb_build_object('pazar', round(pazar), 'pay', round(pay * 100, 1), 'rakip', rakip, 'gelir', round(gelir),
    'kapasite', round(kap), 'kapasite_dolu', gelir >= kap - 1, 'gider', round(gider), 'personel', round(personel),
    'kalite_gider', round(kalite_gid), 'kaynak_gider', round(kaynak_gid), 'ruhsat', round(ruhsat), 'ruhsat_oran', ruh,
    'ceza', round(ceza), 'vergi', round(vergi), 'net', round(net), 'politika', pold, 'kamu_guc', round(dis, 2),
    'fiyat', v_f, 'kalite', v_k, 'kaynak', v_kay, 'getiri', round(net / s.sermaye * 100, 1));
end $$;

-- Rekabetçi şirketin geciken haftalarını işler. sirket_hesapla tarafından kilit altında çağrılır.
create or replace function oyun.pazar_hesapla(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare s oyun.sirketler; ps oyun.pazar_sirket; t timestamptz := oyun.simdi(); n int; i int; h jsonb; zt timestamptz;
  gurultu numeric; gelir numeric; gider numeric; ruhsat numeric; ceza numeric; v_vergi numeric; net numeric; oran numeric;
  x record; distributed numeric; distributable numeric; v_odeme numeric; tlm numeric; ilad text; kasa_son numeric;
begin
  select * into s from oyun.sirketler where id = p_id for update;
  select * into ps from oyun.pazar_sirket where sirket_id = p_id for update;
  if s.id is null or ps.sirket_id is null or not s.aktif or s.sonraki_kazanc > t then return; end if;
  n := least(52, floor(extract(epoch from (t - s.sonraki_kazanc)) / 604800)::int + 1);
  tlm := oyun.pazar_tl_milyar();
  select ad into ilad from oyun.iller where id = ps.il_id;
  for i in 1..n loop
    zt := s.sonraki_kazanc + (i - 1) * interval '7 days';
    h := oyun.pazar_tahmin(p_id, null, null, null, zt);
    gurultu := 0.9 + random()::numeric * 0.2;
    gelir := round((h->>'gelir')::numeric * gurultu);
    gider := (h->>'gider')::numeric;
    oran := coalesce((h->>'ruhsat_oran')::numeric, 0);
    ruhsat := round(gelir * oran / 100);
    ceza := case when (h->>'ceza')::numeric > 0 then round(gelir * 0.12) else 0 end;
    net := gelir - gider - ruhsat - ceza;
    v_vergi := round(greatest(0, net) * (select kurumlar from oyun.pazar_ayar where id = 1) / 100);
    net := net - v_vergi;

    -- kamuya giden paralar (oyuncu ₺ → milyar ₺)
    if v_vergi > 0 then update oyun.ulke set hazine = hazine + v_vergi / tlm where id = 1; end if;
    if ruhsat > 0 then
      update oyun.il_durum set kasa = coalesce(kasa, 0) + ruhsat / tlm where il_id = ps.il_id;
      insert into oyun.il_ruhsat(il_id, toplam) values (ps.il_id, ruhsat)
        on conflict (il_id) do update set toplam = oyun.il_ruhsat.toplam + excluded.toplam;
    end if;
    -- istihdam ve kaynağın ile etkisi
    update oyun.il_durum set
      gelisim = oyun.sinir(gelisim + 0.03 + case ps.kaynak when 'yenilenebilir' then 0.05 else 0 end, 0, 100),
      memnuniyet = oyun.sinir(memnuniyet + case when s.sektor = 'enerji' and ps.kaynak = 'komur' then -0.4 when ps.kalite >= 2 then 0.05 else 0 end, 0, 100)
    where il_id = ps.il_id;

    distributed := 0;
    if net < 0 then
      update oyun.sirketler set kasa = kasa + net where id = p_id;
    else
      distributable := least(net, greatest(0, (select kasa from oyun.sirketler where id = p_id) + net));
      for x in select * from oyun.sirket_ortaklari where sirket_id = p_id loop
        if not x.kar_kasada then
          v_odeme := least(round(distributable * x.pay / 100, 2), greatest(0, distributable - distributed));
          if v_odeme > 0 then
            perform oyun.para_islem(x.user_id, v_odeme, 'sirket', format('%s haftalık net kâr payı', s.ad), t);
            distributed := distributed + v_odeme;
          end if;
        end if;
      end loop;
      update oyun.sirketler set kasa = kasa + net - distributed where id = p_id;
    end if;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (p_id, t, net, format('7 günlük faaliyet (%s): pazar payı %%%s, %s rakip; gelir - gider - harç - vergi = net',
            ilad, h->>'pay', h->>'rakip'), gelir, gider + ruhsat + ceza + v_vergi, distributed);
    insert into oyun.pazar_rapor(sirket_id, zaman, il_id, pazar, pay, rakip, gelir, gider, ruhsat, vergi, ceza, net, fiyat, kalite, kaynak)
    values (p_id, zt + interval '7 days', ps.il_id, (h->>'pazar')::numeric, (h->>'pay')::numeric, (h->>'rakip')::int,
            gelir, gider, ruhsat, v_vergi, ceza, net, ps.fiyat, ps.kalite, ps.kaynak);
    -- marka: kalite ile büyür, zamanla erir
    update oyun.pazar_sirket set marka = least(100, marka * 0.9 + 3 + 2.5 * kalite + case kaynak when 'yenilenebilir' then 3 else 0 end),
      hafta = hafta + 1 where sirket_id = p_id;
    select * into ps from oyun.pazar_sirket where sirket_id = p_id;

    select kasa into kasa_son from oyun.sirketler where id = p_id;
    if kasa_son <= 0 then
      update oyun.sirketler set aktif = false, kasa = 0, satilik = null, son_islem = t where id = p_id;
      update oyun.sirketler set sonraki_kazanc = s.sonraki_kazanc + i * interval '7 days' where id = p_id;
      perform oyun.olay('ekonomi', format('%s (%s, %s) iflas etti; kasası tükendi.', s.ad,
        (select ad from oyun.pazar_sektor where kod = s.sektor), ilad), ps.il_id, null, t);
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
        perform oyun.bildir(x.user_id, format('%s iflas etti: şirket kasası tükendi ve faaliyet durdu.', s.ad), t);
      end loop;
      return;
    end if;
  end loop;
  update oyun.sirketler set sonraki_kazanc = sonraki_kazanc + n * interval '7 days', son_islem = t where id = p_id;
  -- kasa erirken bir kez uyar
  if kasa_son < s.sermaye * 0.25 and (ps.son_uyari is null or ps.son_uyari < t - interval '6 days') then
    update oyun.pazar_sirket set son_uyari = t where sirket_id = p_id;
    for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
      perform oyun.bildir(x.user_id, format('%s zarar ediyor: kasada %s ₺ kaldı. Fiyatı, kaliteyi ya da ili değiştirmezsen iflas edebilir.',
        s.ad, oyun.tl(kasa_son)), t);
    end loop;
  end if;
end $$;

-- Eski motor + rekabetçi dal + eski türlere sektör politikası (canlıdaki hâl korunarak)
create or replace function oyun.sirket_hesapla(p_id bigint)
returns void language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;distributable numeric;v_odeme numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 if exists(select 1 from oyun.pazar_sektor where kod=s.sektor) then perform oyun.pazar_hesapla(p_id); return; end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()::numeric*.8),2);
  cost:=round(s.sermaye*(.025+random()::numeric*.055)+w*(.5+random()::numeric),2);
  income:=round(income * oyun.kriz_sektor_carpani(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days')
                       * oyun.sektor_pol_carpan(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days'),2); net:=income-cost;
  distributed:=0;
  -- Zararda sirket kasasi erir. Karda dagitilabilir para ortaklara aktarilir.
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributable:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    if not x.kar_kasada then
      v_odeme:=least(round(distributable*x.pay/100,2),greatest(0,distributable-distributed));
      if v_odeme>0 then
        perform oyun.para_islem(x.user_id,v_odeme,'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
        distributed:=distributed+v_odeme;
      end if;
    end if;
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$;

-- Halka arz değerlemesi yeni türleri de tanısın
create or replace function oyun.sirket_ort_net(p_sermaye numeric, p_sektor text) returns numeric language sql stable as $$
  select round(p_sermaye * (case p_sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20
           when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16
           when 'ozel_okul' then .17 when 'ozel_hastane' then .18 when 'market' then .17 when 'ulasim' then .17 when 'enerji' then .18
           else .08 end)
         - p_sermaye * .0525 - (select u.asgari from oyun.ulke u where u.id = 1))
$$;

-- Sahiplik: en az %50 pay ya da en büyük ortak karar verir
create or replace function oyun.sirket_yonetici_mi(p_sirket bigint, u uuid) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = u
                 and (o.pay >= 50 or o.pay >= (select max(pay) from oyun.sirket_ortaklari where sirket_id = p_sirket)))
$$;

-- Makamdaki kişi
create or replace function oyun.makam_sahibi(p_tur text, p_bakanlik text default null, p_il smallint default null) returns uuid
language sql stable set search_path = '' as $$
  select user_id from oyun.makamlar where tur = p_tur and bit is null
    and (p_bakanlik is null or bakanlik = p_bakanlik) and (p_il is null or il_id = p_il)
  order by bas desc limit 1
$$;
-- Bakanlığın yetkilisi: bakan, yoksa cumhurbaşkanı vekâlet eder
create or replace function oyun.bakanlik_yetkilisi(p_bakanlik text) returns uuid language sql stable set search_path = '' as $$
  select coalesce(oyun.makam_sahibi('bakan', p_bakanlik, null), oyun.makam_sahibi('cb', null, null))
$$;

-- ---------------------------------------------------------------- oyuncu RPC'leri: rekabetçi şirket
create or replace function public.pazar_katalog() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'sektorler', (select jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', k.ad, 'aciklama', k.aciklama, 'min_sermaye', k.min_sermaye,
        'bakanlik', b.ad, 'bakan', oyun.kad(oyun.makam_sahibi('bakan', k.bakanlik, null)),
        'politika', oyun.sektor_pol_durum(k.kod, t), 'politika_bit', (select bit from oyun.sektor_politika where sektor = k.kod and bit > t),
        'sirket_sayisi', (select count(*) from oyun.sirketler s where s.sektor = k.kod and s.aktif),
        'esneklik', k.esneklik) order by k.sira)
      from oyun.pazar_sektor k join oyun.bakanliklar b on b.kod = k.bakanlik),
    'eski_politikalar', (select jsonb_agg(jsonb_build_object('sektor', y.sektor, 'ad', y.ad, 'politika', oyun.sektor_pol_durum(y.sektor, t)))
      from oyun.sektor_yetki y where not exists (select 1 from oyun.pazar_sektor k where k.kod = y.sektor)),
    'benim_il', p.il_id,
    'kurumlar', (select kurumlar from oyun.pazar_ayar where id = 1),
    'sirketlerim', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'il', i.ad, 'kasa', round(s.kasa),
        'sermaye', s.sermaye, 'pay', o.pay, 'aktif', s.aktif) order by s.id)
      from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id join oyun.pazar_sirket ps on ps.sirket_id = s.id
      join oyun.iller i on i.id = ps.il_id where o.user_id = p.id), '[]'::jsonb));
end $$;

-- Pazar haritası: bir sektör için 81 ilin fırsatları
create or replace function public.pazar_harita(p_sektor text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); k oyun.pazar_sektor; t timestamptz := oyun.simdi(); u oyun.ulke; makro numeric; pol numeric;
begin
  select * into k from oyun.pazar_sektor where kod = p_sektor;
  if k.kod is null then raise exception 'Geçersiz şirket türü.'; end if;
  select * into u from oyun.ulke where id = 1;
  makro := case when k.kod = 'enerji' then oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.06, 0.7, 1.4)
                else oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.03 + (coalesce(u.memnuniyet, 50) - 50) * 0.004, 0.8, 1.25) end;
  pol := oyun.sektor_pol_carpan(k.kod, t) * oyun.kriz_sektor_carpani(k.kod, t);
  return jsonb_build_object('sektor', k.kod, 'ad', k.ad, 'iller', (
    select jsonb_agg(x order by (x->>'firsat')::numeric desc) from (
      select jsonb_build_object('il_id', i.id, 'il', i.ad, 'mv', i.mv, 'gelisim', round(coalesce(d.gelisim, 50)),
        'pazar', round(k.taban * oyun.pazar_il_agirlik(i.id) * makro * pol),
        'rakip', (select count(*) from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
                  where ps.il_id = i.id and s.sektor = k.kod and s.aktif),
        'ruhsat', coalesce((select oran from oyun.il_ruhsat where il_id = i.id), 0),
        'benim', i.id = p.il_id,
        'firsat', round(k.taban * oyun.pazar_il_agirlik(i.id) * makro * pol
                  / (1 + (select count(*) from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
                          where ps.il_id = i.id and s.sektor = k.kod and s.aktif)))) x
      from oyun.iller i left join oyun.il_durum d on d.il_id = i.id) z));
end $$;

create or replace function public.pazar_sirket_kur(p_ad text, p_sektor text, p_sermaye numeric, p_il int, p_kaynak text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); k oyun.pazar_sektor; v_id bigint; t timestamptz := oyun.simdi(); ilad text;
begin
  select * into k from oyun.pazar_sektor where kod = p_sektor;
  if k.kod is null then raise exception 'Geçersiz şirket türü.'; end if;
  if p_ad is null or char_length(btrim(p_ad)) not between 3 and 50 then raise exception 'Şirket adı 3-50 karakter olmalı.'; end if;
  if not exists (select 1 from oyun.iller where id = p_il) then raise exception 'Geçersiz il.'; end if;
  if p_sermaye is null or p_sermaye <> round(p_sermaye) or p_sermaye < k.min_sermaye or p_sermaye > 100000000 then
    raise exception '% için kuruluş sermayesi en az % ₺, en fazla 100.000.000 ₺ olmalı.', k.ad, oyun.tl(k.min_sermaye);
  end if;
  if p_sektor = 'enerji' and coalesce(p_kaynak, 'dogalgaz') not in ('komur','dogalgaz','yenilenebilir') then raise exception 'Geçersiz enerji kaynağı.'; end if;
  if (select count(*) from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id
      where o.user_id = p.id and s.kurucu = p.id and s.aktif and s.kurulus > t - interval '24 hours') >= 3 then
    raise exception 'Son 24 saatte en fazla 3 şirket kurabilirsin.';
  end if;
  perform oyun.para_islem(p.id, -p_sermaye, 'sirket', format('%s kuruluş sermayesi', k.ad), t);
  insert into oyun.sirketler(ad, sektor, kurucu, sermaye, kasa, son_islem, kurulus, sonraki_kazanc) values (btrim(p_ad), p_sektor, p.id, p_sermaye, p_sermaye, t, t, t + interval '7 days')
    returning id into v_id;
  insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values (v_id, p.id, 100);
  insert into oyun.pazar_sirket(sirket_id, il_id, kaynak) values (v_id, p_il,
    case when p_sektor = 'enerji' then coalesce(p_kaynak, 'dogalgaz') end);
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.olay('ekonomi', format('%s, %s''da %s açtı: %s.', p.kad, ilad, lower(k.ad), btrim(p_ad)), p_il::smallint, null, t);
  return jsonb_build_object('id', v_id, 'tahmin', oyun.pazar_tahmin(v_id));
end $$;

create or replace function public.pazar_detay(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; ps oyun.pazar_sirket; k oyun.pazar_sektor; yon boolean; f int; q int; senaryo jsonb := '[]'::jsonb; kay text;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  if s.id is null or ps.sirket_id is null then raise exception 'Rekabetçi şirket bulunamadı.'; end if;
  if s.aktif and exists (select 1 from oyun.sirket_ortaklari where sirket_id = s.id and user_id = p.id) then
    perform oyun.sirket_hesapla(s.id);
    select * into s from oyun.sirketler where id = p_sirket;
    select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  end if;
  select * into k from oyun.pazar_sektor where kod = s.sektor;
  yon := oyun.sirket_yonetici_mi(s.id, p.id);
  if yon and s.aktif then
    for f in 1..3 loop for q in 0..3 loop
      senaryo := senaryo || jsonb_build_array(jsonb_build_object('fiyat', f, 'kalite', q,
        'net', (oyun.pazar_tahmin(s.id, f::smallint, q::smallint, null)->>'net')::numeric,
        'pay', (oyun.pazar_tahmin(s.id, f::smallint, q::smallint, null)->>'pay')::numeric));
    end loop; end loop;
    if s.sektor = 'enerji' then
      foreach kay in array array['komur','dogalgaz','yenilenebilir'] loop
        senaryo := senaryo || jsonb_build_array(jsonb_build_object('kaynak', kay,
          'net', (oyun.pazar_tahmin(s.id, null, null, kay)->>'net')::numeric));
      end loop;
    end if;
  end if;
  return jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sektor_ad', k.ad, 'aciklama', k.aciklama, 'aktif', s.aktif,
    'il_id', ps.il_id, 'il', (select ad from oyun.iller where id = ps.il_id), 'kasa', round(s.kasa), 'sermaye', s.sermaye,
    'fiyat', ps.fiyat, 'kalite', ps.kalite, 'kaynak', ps.kaynak, 'marka', round(ps.marka), 'hafta', ps.hafta,
    'sonraki', s.sonraki_kazanc, 'yonetici', yon, 'son_tasima', ps.son_tasima, 'sahip', oyun.kad(s.kurucu),
    'ortaklar', (select jsonb_agg(jsonb_build_object('kad', oyun.kad(o.user_id), 'pay', o.pay) order by o.pay desc) from oyun.sirket_ortaklari o where o.sirket_id = s.id),
    'tahmin', case when s.aktif then oyun.pazar_tahmin(s.id) end, 'senaryo', senaryo,
    'tasima_bedel', round(s.sermaye * 0.10),
    'rakipler', coalesce((select jsonb_agg(jsonb_build_object('id', s2.id, 'ad', s2.ad, 'sahip', oyun.kad(s2.kurucu), 'fiyat', p2.fiyat,
        'kalite', p2.kalite, 'marka', round(p2.marka / 10) * 10, 'sermaye', s2.sermaye, 'kaynak', p2.kaynak) order by s2.sermaye desc)
      from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
      where p2.il_id = ps.il_id and s2.sektor = s.sektor and s2.aktif and s2.id <> s.id), '[]'::jsonb),
    'raporlar', coalesce((select jsonb_agg(r order by r.zaman desc) from (
      select zaman, pazar, pay, rakip, gelir, gider, ruhsat, vergi, ceza, net, fiyat, kalite, kaynak from oyun.pazar_rapor
      where sirket_id = s.id order by zaman desc limit 8) r), '[]'::jsonb));
end $$;

create or replace function public.pazar_ayarla(p_sirket bigint, p_fiyat int, p_kalite int, p_kaynak text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; ps oyun.pazar_sirket; t timestamptz := oyun.simdi();
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  if s.id is null or ps.sirket_id is null or not s.aktif then raise exception 'Rekabetçi şirket bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Şirketin kararlarını en büyük ortak (ya da en az %%50 pay sahibi) verir.'; end if;
  if p_fiyat not between 1 and 3 or p_kalite not between 0 and 3 then raise exception 'Fiyat 1-3, kalite 0-3 arasında olmalı.'; end if;
  if s.sektor = 'enerji' and coalesce(p_kaynak, ps.kaynak) not in ('komur','dogalgaz','yenilenebilir') then raise exception 'Geçersiz enerji kaynağı.'; end if;
  if ps.son_ayar is not null and ps.son_ayar > t - interval '10 minutes' then raise exception 'Ayarları 10 dakikada bir değiştirebilirsin.'; end if;
  perform oyun.sirket_hesapla(s.id);   -- geçmiş haftalar eski ayarla kapanır
  update oyun.pazar_sirket set fiyat = p_fiyat, kalite = p_kalite,
    kaynak = case when s.sektor = 'enerji' then coalesce(p_kaynak, kaynak) else null end, son_ayar = t
  where sirket_id = s.id;
  return oyun.pazar_tahmin(s.id);
end $$;

create or replace function public.pazar_tasi(p_sirket bigint, p_il int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; ps oyun.pazar_sirket; t timestamptz := oyun.simdi(); bedel numeric; ilad text;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  if s.id is null or ps.sirket_id is null or not s.aktif then raise exception 'Rekabetçi şirket bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Şirketi yalnız en büyük ortak taşıyabilir.'; end if;
  if not exists (select 1 from oyun.iller where id = p_il) or p_il = ps.il_id then raise exception 'Farklı ve geçerli bir il seç.'; end if;
  if ps.son_tasima is not null and ps.son_tasima > t - interval '7 days' then raise exception 'Şirket 7 günde bir taşınabilir.'; end if;
  perform oyun.sirket_hesapla(s.id);
  select * into s from oyun.sirketler where id = p_sirket;
  bedel := round(s.sermaye * 0.10);
  if s.kasa < bedel then raise exception 'Taşınma bedeli % ₺; şirket kasasında yeterli para yok.', oyun.tl(bedel); end if;
  update oyun.sirketler set kasa = kasa - bedel where id = s.id;
  update oyun.pazar_sirket set il_id = p_il, marka = marka * 0.4, son_tasima = t where sirket_id = s.id;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (s.id, t, -bedel, 'Başka ile taşınma bedeli (kira, kurulum, nakliye)', 0, bedel, 0);
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.olay('ekonomi', format('%s faaliyetini %s''a taşıdı.', s.ad, ilad), p_il::smallint, null, t);
  return oyun.pazar_tahmin(s.id);
end $$;

-- ---------------------------------------------------------------- siyasetçi RPC'leri
create or replace function public.sektor_politika_ayarla(p_sektor text, p_durum text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); y oyun.sektor_yetki; sp oyun.sektor_politika; t timestamptz := oyun.simdi();
  a oyun.pazar_ayar; bakad text; metin text;
begin
  select * into y from oyun.sektor_yetki where sektor = p_sektor;
  if y.sektor is null then raise exception 'Geçersiz sektör.'; end if;
  if p_durum not in ('normal','tesvik','denetim') then raise exception 'Politika normal, teşvik ya da denetim olmalı.'; end if;
  if oyun.bakanlik_yetkilisi(y.bakanlik) is distinct from p.id then
    raise exception '% politikasını % belirler.', y.ad, (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = y.bakanlik);
  end if;
  select * into a from oyun.pazar_ayar where id = 1;
  select * into sp from oyun.sektor_politika where sektor = p_sektor for update;
  if sp.son_degisim is not null and sp.son_degisim > t - interval '24 hours' then raise exception 'Sektör politikası 24 saatte bir değiştirilebilir.'; end if;
  if p_durum = 'tesvik' then
    update oyun.bakanlik_kasa set kasa = kasa - a.tesvik_bedel where kod = y.bakanlik and kasa >= a.tesvik_bedel;
    if not found then raise exception 'Teşvik için bakanlık kasasında % milyar ₺ gerekli.', a.tesvik_bedel; end if;
  end if;
  insert into oyun.sektor_politika(sektor, durum, belirleyen, bas, bit, son_degisim)
    values (p_sektor, p_durum, p.id, t, case when p_durum = 'normal' then t else t + a.politika_gun * interval '1 day' end, t)
  on conflict (sektor) do update set durum = excluded.durum, belirleyen = excluded.belirleyen, bas = excluded.bas, bit = excluded.bit, son_degisim = excluded.son_degisim;
  bakad := (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = y.bakanlik);
  metin := case p_durum
    when 'tesvik' then format('%s %s, %s sektörüne %s günlük teşvik paketi açıkladı: sektörün pazarı %%15 büyüyecek.', bakad, p.kad, y.ad, a.politika_gun)
    when 'denetim' then format('%s %s, %s sektöründe %s günlük sıkı denetim başlattı: kalitesiz hizmete ve kirletici üretime ceza kesilecek.', bakad, p.kad, y.ad, a.politika_gun)
    else format('%s %s, %s sektöründeki özel uygulamayı sona erdirdi.', bakad, p.kad, y.ad) end;
  perform oyun.olay('ekonomi', metin, null, p.parti_id, t);
  perform oyun.gazete_ekle('icraat', format('%s sektöründe yeni dönem', y.ad), metin, null, t);
  return jsonb_build_object('sektor', p_sektor, 'durum', p_durum, 'bit', case when p_durum = 'normal' then null else t + a.politika_gun * interval '1 day' end);
end $$;

create or replace function public.il_ruhsat_ayarla(p_oran numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_il smallint; r oyun.il_ruhsat; t timestamptz := oyun.simdi(); ilad text;
begin
  select il_id into v_il from oyun.makamlar where tur = 'bel' and user_id = p.id and bit is null limit 1;
  if v_il is null then raise exception 'Ruhsat harcını yalnız belediye başkanı belirler.'; end if;
  if p_oran is null or p_oran < 0 or p_oran > 8 then raise exception 'Ruhsat harcı %%0 ile %%8 arasında olmalı.'; end if;
  select * into r from oyun.il_ruhsat where il_id = v_il for update;
  if r.son_degisim is not null and r.son_degisim > t - interval '24 hours' then raise exception 'Ruhsat harcı 24 saatte bir değiştirilebilir.'; end if;
  insert into oyun.il_ruhsat(il_id, oran, belirleyen, son_degisim) values (v_il, round(p_oran, 1), p.id, t)
  on conflict (il_id) do update set oran = excluded.oran, belirleyen = excluded.belirleyen, son_degisim = excluded.son_degisim;
  select ad into ilad from oyun.iller where id = v_il;
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s işyeri ruhsat harcını %%%s yaptı.', ilad, p.kad, replace(round(p_oran, 1)::text, '.', ',')), v_il, p.parti_id, t);
  return jsonb_build_object('il_id', v_il, 'oran', round(p_oran, 1));
end $$;

-- ---------------------------------------------------------------- kamu ihaleleri
create or replace function oyun.ihale_butce(pr oyun.kamu_ihale_proje, p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select round(case when pr.kurum = 'belediye'
    then pr.carpan * oyun.il_gunluk_gelir((select mv from oyun.iller where id = p_il)) * coalesce((select endeks from oyun.ulke where id = 1), 1)
    else pr.carpan * coalesce((select endeks from oyun.ulke where id = 1), 1) end, 3)
$$;

create or replace function oyun.ihale_json(x oyun.kamu_ihale, u uuid) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', x.id, 'proje', x.proje, 'ad', pr.ad, 'aciklama', pr.aciklama, 'kurum', x.kurum,
    'kurum_ad', case when x.kurum = 'belediye' then i.ad || ' Belediyesi' else (select ad from oyun.bakanliklar where kod = x.bakanlik) end,
    'il_id', x.il_id, 'il', i.ad, 'acan', oyun.kad(x.acan), 'acan_unvan', oyun.unvan(x.acan), 'butce', x.butce, 'tavan', x.tavan,
    'bas', x.bas, 'bit', x.bit, 'durum', x.durum, 'teklif_say', x.teklif_say, 'deneyim', pr.deneyim, 'sure_gun', pr.sure_gun,
    'gelisim', pr.gelisim, 'memnuniyet', pr.memnuniyet,
    'kazanan', (select ad from oyun.sirketler where id = x.kazanan), 'kazanan_sahip', (select oyun.kad(kurucu) from oyun.sirketler where id = x.kazanan),
    'kazanan_parti', (select pa.kisa from oyun.sirket_ortaklari o join oyun.profiller pf on pf.id = o.user_id join oyun.partiler pa on pa.id = pf.parti_id
                      where o.sirket_id = x.kazanan order by o.pay desc limit 1),
    'bedel', case when x.durum <> 'acik' then x.bedel end, 'yontem', case when x.durum = 'tamam' then x.yontem end,
    'teslim_at', x.teslim_at, 'sonuc', x.sonuc, 'acan_benim', x.acan = u,
    'kazanan_benim', x.kazanan is not null and oyun.sirket_yonetici_mi(x.kazanan, u),
    'benim_yontem', case when x.kazanan is not null and oyun.sirket_yonetici_mi(x.kazanan, u) then x.yontem end,
    'tekliflerim', coalesce((select jsonb_agg(jsonb_build_object('sirket_id', t.sirket_id, 'sirket', s.ad, 'tutar', t.tutar))
                   from oyun.kamu_ihale_teklif t join oyun.sirketler s on s.id = t.sirket_id where t.ihale_id = x.id and t.veren = u), '[]'::jsonb),
    'teklifler', case when x.durum <> 'acik' then (select jsonb_agg(jsonb_build_object('sirket', s.ad, 'tutar', t.tutar) order by t.tutar)
                   from oyun.kamu_ihale_teklif t join oyun.sirketler s on s.id = t.sirket_id where t.ihale_id = x.id) end)
  from oyun.kamu_ihale_proje pr, oyun.iller i where pr.kod = x.proje and i.id = x.il_id
$$;

create or replace function public.ihale_ekrani() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); bel smallint; bakanliklar text[]; cb boolean;
begin
  perform oyun.ihale_tick();
  select il_id into bel from oyun.makamlar where tur = 'bel' and user_id = p.id and bit is null limit 1;
  cb := exists (select 1 from oyun.makamlar where tur = 'cb' and user_id = p.id and bit is null);
  select array_agg(b.kod) into bakanliklar from oyun.bakanliklar b where oyun.bakanlik_yetkilisi(b.kod) = p.id;
  return jsonb_build_object(
    'acik', coalesce((select jsonb_agg(oyun.ihale_json(x, p.id) order by x.bit) from oyun.kamu_ihale x where x.durum = 'acik'), '[]'::jsonb),
    'yapim', coalesce((select jsonb_agg(oyun.ihale_json(x, p.id) order by x.teslim_at) from oyun.kamu_ihale x where x.durum = 'yapim'), '[]'::jsonb),
    'biten', coalesce((select jsonb_agg(oyun.ihale_json(x, p.id) order by x.id desc) from
                (select * from oyun.kamu_ihale where durum in ('tamam','teklifsiz','iptal') order by id desc limit 20) x), '[]'::jsonb),
    'insaat_sirketlerim', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'kasa', round(s.kasa),
          'deneyim', coalesce(d.is_sayisi, 0), 'yasak_bit', case when d.yasak_bit > t then d.yasak_bit end))
        from oyun.sirketler s left join oyun.sirket_deneyim d on d.sirket_id = s.id
        where s.sektor = 'insaat' and s.aktif and oyun.sirket_yonetici_mi(s.id, p.id)), '[]'::jsonb),
    'yetki', jsonb_build_object(
      'belediye_il', bel, 'belediye_il_ad', (select ad from oyun.iller where id = bel),
      'belediye_kasa', (select round(kasa, 3) from oyun.il_durum where il_id = bel),
      'ruhsat', (select oran from oyun.il_ruhsat where il_id = bel),
      'bakanliklar', coalesce((select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'kasa', round(k.kasa, 2)) order by b.sira)
          from oyun.bakanliklar b left join oyun.bakanlik_kasa k on k.kod = b.kod where b.kod = any(bakanliklar)), '[]'::jsonb),
      'vekalet', cb and exists (select 1 from unnest(bakanliklar) z where oyun.makam_sahibi('bakan', z, null) is null),
      'sektorler', coalesce((select jsonb_agg(jsonb_build_object('sektor', y.sektor, 'ad', y.ad, 'durum', oyun.sektor_pol_durum(y.sektor, t),
            'bit', (select bit from oyun.sektor_politika where sektor = y.sektor and bit > t),
            'son_degisim', (select son_degisim from oyun.sektor_politika where sektor = y.sektor)) order by y.ad)
          from oyun.sektor_yetki y where y.bakanlik = any(bakanliklar)), '[]'::jsonb),
      'projeler', coalesce((select jsonb_agg(jsonb_build_object('kod', pr.kod, 'ad', pr.ad, 'kurum', pr.kurum, 'bakanlik', pr.bakanlik,
            'aciklama', pr.aciklama, 'sure_gun', pr.sure_gun, 'gelisim', pr.gelisim, 'memnuniyet', pr.memnuniyet, 'deneyim', pr.deneyim,
            'butce', case when pr.kurum = 'belediye' then oyun.ihale_butce(pr, bel) else oyun.ihale_butce(pr, null) end,
            'tavan', round(case when pr.kurum = 'belediye' then oyun.ihale_butce(pr, bel) else oyun.ihale_butce(pr, null) end * oyun.pazar_tl_milyar(), -3)) order by pr.sira)
          from oyun.kamu_ihale_proje pr where (pr.kurum = 'belediye' and bel is not null) or (pr.kurum = 'bakanlik' and pr.bakanlik = any(bakanliklar))), '[]'::jsonb),
      'tesvik_bedel', (select tesvik_bedel from oyun.pazar_ayar where id = 1)));
end $$;

create or replace function public.ihale_ac(p_proje text, p_il int, p_saat int default 24) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); pr oyun.kamu_ihale_proje; t timestamptz := oyun.simdi(); v_il smallint; butce numeric; tavan numeric;
  v_id bigint; kurumad text; ilad text;
begin
  select * into pr from oyun.kamu_ihale_proje where kod = p_proje;
  if pr.kod is null then raise exception 'Geçersiz proje.'; end if;
  if p_saat not in (12, 24, 48) then raise exception 'Teklif süresi 12, 24 ya da 48 saat olmalı.'; end if;
  if pr.kurum = 'belediye' then
    select il_id into v_il from oyun.makamlar where tur = 'bel' and user_id = p.id and bit is null limit 1;
    if v_il is null then raise exception 'Belediye ihalesini yalnız belediye başkanı açar.'; end if;
  else
    if oyun.bakanlik_yetkilisi(pr.bakanlik) is distinct from p.id then
      raise exception 'Bu ihaleyi % açar.', (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = pr.bakanlik);
    end if;
    v_il := p_il;
    if not exists (select 1 from oyun.iller where id = v_il) then raise exception 'Projenin yapılacağı ili seç.'; end if;
  end if;
  if (select count(*) from oyun.kamu_ihale where acan = p.id and durum in ('acik','yapim')) >= 3 then
    raise exception 'Aynı anda en fazla 3 ihalen sürebilir.';
  end if;
  if exists (select 1 from oyun.kamu_ihale where proje = pr.kod and il_id = v_il and durum in ('acik','yapim')) then
    raise exception 'Bu ilde aynı proje zaten ihalede ya da yapımda.';
  end if;
  butce := oyun.ihale_butce(pr, v_il);
  tavan := round(butce * oyun.pazar_tl_milyar(), -3);
  if tavan < 1000 then raise exception 'Proje bütçesi çok küçük.'; end if;
  if pr.kurum = 'belediye' then
    update oyun.il_durum set kasa = kasa - butce where il_id = v_il and kasa >= butce;
    if not found then raise exception 'Belediye kasasında % milyar ₺ gerekli.', replace(butce::text, '.', ','); end if;
    kurumad := (select ad from oyun.iller where id = v_il) || ' Belediyesi';
  else
    update oyun.bakanlik_kasa set kasa = kasa - butce where kod = pr.bakanlik and kasa >= butce;
    if not found then raise exception 'Bakanlık kasasında % milyar ₺ gerekli.', replace(butce::text, '.', ','); end if;
    kurumad := (select ad from oyun.bakanliklar where kod = pr.bakanlik);
  end if;
  insert into oyun.kamu_ihale(proje, kurum, il_id, bakanlik, acan, butce, tavan, bas, bit)
    values (pr.kod, pr.kurum, v_il, pr.bakanlik, p.id, butce, tavan, t, t + p_saat * interval '1 hour') returning id into v_id;
  select ad into ilad from oyun.iller where id = v_il;
  perform oyun.olay('ekonomi', format('%s ihale açtı: %s (%s). Yaklaşık maliyet %s ₺; teklifler %s saat içinde.',
    kurumad, pr.ad, ilad, oyun.tl(tavan), p_saat), v_il, p.parti_id, t);
  perform oyun.gazete_ekle(case when pr.kurum = 'belediye' then 'belediye' else 'icraat' end, format('İhale ilanı: %s', pr.ad),
    format('%s, %s için kapalı zarf usulüyle ihaleye çıktı. Yaklaşık maliyet %s ₺. En düşük geçerli teklif kazanır.', kurumad, ilad, oyun.tl(tavan)), v_id, t);
  return oyun.ihale_json((select x from oyun.kamu_ihale x where id = v_id), p.id);
end $$;

create or replace function public.ihale_teklif(p_ihale bigint, p_sirket bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x oyun.kamu_ihale; s oyun.sirketler; d oyun.sirket_deneyim; pr oyun.kamu_ihale_proje; t timestamptz := oyun.simdi();
begin
  perform oyun.ihale_tick();
  select * into x from oyun.kamu_ihale where id = p_ihale for update;
  if x.id is null or x.durum <> 'acik' or x.bit <= t then raise exception 'İhale teklife açık değil.'; end if;
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif or s.sektor <> 'insaat' then raise exception 'Kamu ihalelerine yalnız inşaat şirketleri girebilir.'; end if;
  if not oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Şirket adına teklifi en büyük ortak verir.'; end if;
  if exists (select 1 from oyun.sirket_ortaklari where sirket_id = s.id and user_id = x.acan) then
    raise exception 'Çıkar çatışması: ihaleyi açan kişi bu şirketin ortağı.';
  end if;
  select * into d from oyun.sirket_deneyim where sirket_id = s.id;
  if d.yasak_bit > t then raise exception 'Şirket % tarihine kadar kamu ihalelerinden yasaklı.', to_char(d.yasak_bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'); end if;
  select * into pr from oyun.kamu_ihale_proje where kod = x.proje;
  if coalesce(d.is_sayisi, 0) < pr.deneyim then raise exception 'Bu ihale en az % teslim edilmiş iş deneyimi ister.', pr.deneyim; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < round(x.tavan * 0.4) or p_tutar > x.tavan then
    raise exception 'Teklif % ₺ ile % ₺ arasında olmalı (yaklaşık maliyetin %%40''ı ile tamamı).', oyun.tl(round(x.tavan * 0.4)), oyun.tl(x.tavan);
  end if;
  if s.kasa < round(x.tavan * 0.55) then raise exception 'İşi yapabilmek için şirket kasasında en az % ₺ olmalı.', oyun.tl(round(x.tavan * 0.55)); end if;
  insert into oyun.kamu_ihale_teklif(ihale_id, sirket_id, veren, tutar, zaman) values (x.id, s.id, p.id, p_tutar, t)
  on conflict (ihale_id, sirket_id) do update set tutar = excluded.tutar, zaman = excluded.zaman, veren = excluded.veren;
  update oyun.kamu_ihale set teklif_say = (select count(*) from oyun.kamu_ihale_teklif where ihale_id = x.id) where id = x.id;
  return oyun.ihale_json((select z from oyun.kamu_ihale z where id = x.id), p.id);
end $$;

create or replace function public.ihale_teklif_geri(p_ihale bigint, p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x oyun.kamu_ihale;
begin
  select * into x from oyun.kamu_ihale where id = p_ihale for update;
  if x.id is null or x.durum <> 'acik' then raise exception 'İhale teklife açık değil.'; end if;
  delete from oyun.kamu_ihale_teklif where ihale_id = x.id and sirket_id = p_sirket and veren = p.id;
  if not found then raise exception 'Bu şirketin teklifi yok.'; end if;
  update oyun.kamu_ihale set teklif_say = (select count(*) from oyun.kamu_ihale_teklif where ihale_id = x.id) where id = x.id;
  return oyun.ihale_json((select z from oyun.kamu_ihale z where id = x.id), p.id);
end $$;

create or replace function public.ihale_iptal(p_ihale bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x oyun.kamu_ihale; t timestamptz := oyun.simdi();
begin
  select * into x from oyun.kamu_ihale where id = p_ihale for update;
  if x.id is null or x.durum <> 'acik' then raise exception 'Yalnız teklif süresi süren ihale iptal edilebilir.'; end if;
  if x.acan <> p.id then raise exception 'İhaleyi yalnız açan kişi iptal edebilir.'; end if;
  perform oyun.ihale_iade(x, x.butce);
  update oyun.kamu_ihale set durum = 'iptal' where id = x.id;
  perform oyun.olay('ekonomi', format('%s ihalesi (%s) iptal edildi.', (select ad from oyun.kamu_ihale_proje where kod = x.proje),
    (select ad from oyun.iller where id = x.il_id)), x.il_id, null, t);
  return jsonb_build_object('id', x.id, 'durum', 'iptal');
end $$;

-- Kazanan şirket yapım yöntemini seçer (yapım sürerken)
create or replace function public.ihale_yontem(p_ihale bigint, p_yontem text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x oyun.kamu_ihale; s oyun.sirketler; yeni numeric; fark numeric;
begin
  select * into x from oyun.kamu_ihale where id = p_ihale for update;
  if x.id is null or x.durum <> 'yapim' then raise exception 'Yöntem yalnız yapım sürerken değiştirilebilir.'; end if;
  if not oyun.sirket_yonetici_mi(x.kazanan, p.id) then raise exception 'Yöntemi kazanan şirketin en büyük ortağı seçer.'; end if;
  if p_yontem not in ('standart','kaliteli','tasarruflu') then raise exception 'Geçersiz yöntem.'; end if;
  if p_yontem = x.yontem then return oyun.ihale_json(x, p.id); end if;
  yeni := round(x.tavan * case p_yontem when 'kaliteli' then 0.85 when 'tasarruflu' then 0.55 else 0.70 end);
  fark := yeni - x.maliyet;   -- pozitifse ek harcama, negatifse kasaya dönen malzeme parası
  select * into s from oyun.sirketler where id = x.kazanan for update;
  if fark > 0 and s.kasa < fark then raise exception 'Kaliteli yapım için şirket kasasında % ₺ daha gerekli.', oyun.tl(fark); end if;
  update oyun.sirketler set kasa = kasa - fark where id = s.id;
  update oyun.kamu_ihale set yontem = p_yontem, maliyet = yeni where id = x.id;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (s.id, oyun.simdi(), -fark, format('İhale #%s yapım yöntemi: %s', x.id, p_yontem), 0, greatest(fark, 0), 0);
  return oyun.ihale_json((select z from oyun.kamu_ihale z where id = x.id), p.id);
end $$;

-- Kullanılmayan bütçe kamu kasasına döner
create or replace function oyun.ihale_iade(x oyun.kamu_ihale, p_milyar numeric) returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_milyar <= 0 then return; end if;
  if x.kurum = 'belediye' then update oyun.il_durum set kasa = coalesce(kasa, 0) + p_milyar where il_id = x.il_id;
  else update oyun.bakanlik_kasa set kasa = kasa + p_milyar where kod = x.bakanlik; end if;
end $$;

-- Teklif süresi biten ihaleyi sonuçlandırır, yapımı biteni teslim eder
create or replace function oyun.ihale_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); x oyun.kamu_ihale; b record; pr oyun.kamu_ihale_proje; v_kazanan bigint; v_bedel numeric; v_mal numeric;
  ilad text; kurumad text; carp numeric; yakalandi boolean; odeme numeric; ceza numeric; risk numeric; n int := 0; sahip uuid; sad text;
begin
  if not pg_try_advisory_xact_lock(84841) then return 0; end if;
  -- 1) teklif süresi bitenler
  for x in select * from oyun.kamu_ihale where durum = 'acik' and bit <= t order by bit for update loop
    select * into pr from oyun.kamu_ihale_proje where kod = x.proje;
    select ad into ilad from oyun.iller where id = x.il_id;
    kurumad := case when x.kurum = 'belediye' then ilad || ' Belediyesi' else (select ad from oyun.bakanliklar where kod = x.bakanlik) end;
    v_kazanan := null;
    for b in select tk.*, s.kasa, s.aktif, s.sektor from oyun.kamu_ihale_teklif tk join oyun.sirketler s on s.id = tk.sirket_id
             where tk.ihale_id = x.id order by tk.tutar, tk.zaman loop
      v_mal := round(x.tavan * 0.70);
      continue when not b.aktif or b.sektor <> 'insaat' or b.kasa < v_mal;
      continue when exists (select 1 from oyun.sirket_ortaklari where sirket_id = b.sirket_id and user_id = x.acan);
      continue when coalesce((select yasak_bit from oyun.sirket_deneyim where sirket_id = b.sirket_id), '-infinity') > t;
      v_kazanan := b.sirket_id; v_bedel := b.tutar; exit;
    end loop;
    if v_kazanan is null then
      perform oyun.ihale_iade(x, x.butce);
      update oyun.kamu_ihale set durum = 'teklifsiz' where id = x.id;
      perform oyun.olay('ekonomi', format('%s ihalesine (%s, %s) geçerli teklif gelmedi; bütçe kasaya döndü.', kurumad, pr.ad, ilad), x.il_id, null, x.bit);
      perform oyun.bildir(x.acan, format('%s ihalesine geçerli teklif gelmedi; bütçe kasaya döndü.', pr.ad), x.bit);
    else
      update oyun.sirketler set kasa = kasa - v_mal where id = v_kazanan;
      insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
        values (v_kazanan, x.bit, -v_mal, format('İhale #%s yapım maliyeti (standart)', x.id), 0, v_mal, 0);
      perform oyun.ihale_iade(x, round((x.tavan - v_bedel) / x.tavan * x.butce, 4));
      update oyun.kamu_ihale set durum = 'yapim', kazanan = v_kazanan, bedel = v_bedel, maliyet = v_mal,
        teslim_at = x.bit + pr.sure_gun * interval '1 day' where id = x.id;
      select kurucu, ad into sahip, sad from oyun.sirketler where id = v_kazanan;
      perform oyun.olay('ekonomi', format('%s ihalesini (%s, %s) %s kazandı: %s ₺ (yaklaşık maliyetin %%%s''i). %s teklif vardı.',
        kurumad, pr.ad, ilad, sad, oyun.tl(v_bedel), round(v_bedel / x.tavan * 100), x.teklif_say), x.il_id, null, x.bit);
      perform oyun.gazete_ekle(case when x.kurum = 'belediye' then 'belediye' else 'icraat' end, format('%s ihalesi sonuçlandı', pr.ad),
        format('%s ihalesini %s teklif arasından %s kazandı. Bedel %s ₺. Şirketin en büyük ortağı: %s.', kurumad, x.teklif_say, sad, oyun.tl(v_bedel),
          coalesce((select oyun.kad(user_id) from oyun.sirket_ortaklari where sirket_id = v_kazanan order by pay desc limit 1), '-')), x.id, x.bit);
      for b in select distinct veren from oyun.kamu_ihale_teklif where ihale_id = x.id loop
        perform oyun.bildir(b.veren, case when exists (select 1 from oyun.kamu_ihale_teklif where ihale_id = x.id and veren = b.veren and sirket_id = v_kazanan)
          then format('%s ihalesini kazandın (%s ₺). Yapım %s gün sürecek; yöntemi ihale ekranından seçebilirsin.', pr.ad, oyun.tl(v_bedel), pr.sure_gun)
          else format('%s ihalesini %s kazandı (%s ₺).', pr.ad, sad, oyun.tl(v_bedel)) end, x.bit);
      end loop;
      perform oyun.bildir(x.acan, format('%s ihalesini %s kazandı (%s ₺).', pr.ad, sad, oyun.tl(v_bedel)), x.bit);
    end if;
    n := n + 1;
  end loop;

  -- 2) yapımı bitenler
  for x in select * from oyun.kamu_ihale where durum = 'yapim' and teslim_at <= t order by teslim_at for update loop
    select * into pr from oyun.kamu_ihale_proje where kod = x.proje;
    select ad into ilad from oyun.iller where id = x.il_id;
    select ad into sad from oyun.sirketler where id = x.kazanan;
    kurumad := case when x.kurum = 'belediye' then ilad || ' Belediyesi' else (select ad from oyun.bakanliklar where kod = x.bakanlik) end;
    yakalandi := false; ceza := 0; odeme := x.bedel;
    if x.yontem = 'tasarruflu' then
      risk := case when oyun.sektor_pol_durum('insaat', t) = 'denetim' then 0.6 else 0.35 end;
      yakalandi := random() < risk;
    end if;
    carp := case x.yontem when 'kaliteli' then 1.35 when 'tasarruflu' then case when yakalandi then 0.3 else 0.6 end else 1 end;
    if yakalandi then
      odeme := round(x.bedel * 0.5);
      ceza := round(x.bedel * 0.2);
      perform oyun.ihale_iade(x, round((x.bedel - odeme) / x.tavan * x.butce, 4));
    end if;
    update oyun.sirketler set kasa = greatest(0, kasa + odeme - ceza) where id = x.kazanan;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
      values (x.kazanan, x.teslim_at, odeme - ceza, format('İhale #%s hakedişi%s', x.id, case when yakalandi then ' (denetimde eksik çıktı: kesinti ve ceza)' else '' end),
              odeme, ceza, 0);
    insert into oyun.sirket_deneyim(sirket_id, is_sayisi, puan, yasak_bit)
      values (x.kazanan, case when yakalandi then 0 else 1 end, case x.yontem when 'kaliteli' then 2 when 'standart' then 1 else case when yakalandi then -3 else 0 end end,
              case when yakalandi then x.teslim_at + interval '14 days' end)
    on conflict (sirket_id) do update set is_sayisi = oyun.sirket_deneyim.is_sayisi + excluded.is_sayisi,
      puan = oyun.sirket_deneyim.puan + excluded.puan, yasak_bit = coalesce(excluded.yasak_bit, oyun.sirket_deneyim.yasak_bit);
    update oyun.il_durum set gelisim = oyun.sinir(gelisim + pr.gelisim * carp, 0, 100),
      memnuniyet = oyun.sinir(memnuniyet + pr.memnuniyet * carp, 0, 100) where il_id = x.il_id;
    update oyun.kamu_ihale set durum = 'tamam', sonuc = case when yakalandi then 'yakalandi' else 'teslim' end where id = x.id;
    if yakalandi then
      perform oyun.olay('ekonomi', format('Skandal: %s''daki %s denetimde eksik çıktı. %s''e ceza kesildi, şirket 14 gün ihalelerden men edildi.',
        ilad, lower(pr.ad), sad), x.il_id, null, x.teslim_at);
      perform oyun.gazete_ekle(case when x.kurum = 'belediye' then 'belediye' else 'icraat' end, format('%s''da ihale skandalı', ilad),
        format('%s tarafından ihale edilen %s, ucuz malzeme kullanıldığı için denetimden geçemedi. Yüklenici %s''in hakedişinin yarısı ödenmedi, %s ₺ ceza kesildi.',
          kurumad, lower(pr.ad), sad, oyun.tl(ceza)), x.id, x.teslim_at);
      perform oyun.bildir(x.acan, format('Açtığın %s ihalesinde yüklenici denetime takıldı; kamuoyunda tartışılıyor.', pr.ad), x.teslim_at);
    else
      perform oyun.olay('ekonomi', format('%s''da %s hizmete açıldı (%s, yüklenici %s%s).', ilad, lower(pr.ad), kurumad, sad,
        case x.yontem when 'kaliteli' then ', kaliteli yapım' when 'tasarruflu' then ', vatandaş işçilikten şikâyetçi' else '' end), x.il_id, null, x.teslim_at);
    end if;
    for b in select user_id from oyun.sirket_ortaklari where sirket_id = x.kazanan and pay >= 50 loop
      perform oyun.bildir(b.user_id, format('%s teslim edildi. Hakediş: %s ₺%s.', pr.ad, oyun.tl(odeme),
        case when yakalandi then format(', ceza %s ₺, 14 gün ihale yasağı', oyun.tl(ceza)) else '' end), x.teslim_at);
    end loop;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Rekabetçi şirketlerin haftalık hesabı sahipleri ekranı açmasa da yapılsın (adil rekabet)
create or replace function oyun.pazar_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  perform oyun.ihale_tick();
  for r in select s.id from oyun.sirketler s join oyun.pazar_sirket ps on ps.sirket_id = s.id
           where s.aktif and s.sonraki_kazanc <= oyun.simdi() order by s.sonraki_kazanc limit 200 loop
    perform oyun.sirket_hesapla(r.id); n := n + 1;
  end loop;
  return n;
end $$;

do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'ekonomi-pazar';
    perform cron.schedule('ekonomi-pazar', '*/10 * * * *', 'select oyun.pazar_tick()');
  end if;
end $$;

-- ---------------------------------------------------------------- yetkiler
revoke all on function public.pazar_katalog(), public.pazar_harita(text), public.pazar_sirket_kur(text, text, numeric, int, text),
  public.pazar_detay(bigint), public.pazar_ayarla(bigint, int, int, text), public.pazar_tasi(bigint, int),
  public.sektor_politika_ayarla(text, text), public.il_ruhsat_ayarla(numeric), public.ihale_ekrani(), public.ihale_ac(text, int, int),
  public.ihale_teklif(bigint, bigint, numeric), public.ihale_teklif_geri(bigint, bigint), public.ihale_iptal(bigint),
  public.ihale_yontem(bigint, text) from public, anon;
grant execute on function public.pazar_katalog(), public.pazar_harita(text), public.pazar_sirket_kur(text, text, numeric, int, text),
  public.pazar_detay(bigint), public.pazar_ayarla(bigint, int, int, text), public.pazar_tasi(bigint, int),
  public.sektor_politika_ayarla(text, text), public.il_ruhsat_ayarla(numeric), public.ihale_ekrani(), public.ihale_ac(text, int, int),
  public.ihale_teklif(bigint, bigint, numeric), public.ihale_teklif_geri(bigint, bigint), public.ihale_iptal(bigint),
  public.ihale_yontem(bigint, text) to authenticated;
revoke all on function oyun.pazar_tahmin(bigint, smallint, smallint, text, timestamptz), oyun.pazar_hesapla(bigint), oyun.pazar_tick(),
  oyun.ihale_tick(), oyun.ihale_iade(oyun.kamu_ihale, numeric), oyun.ihale_json(oyun.kamu_ihale, uuid),
  oyun.ihale_butce(oyun.kamu_ihale_proje, smallint), oyun.sirket_yonetici_mi(bigint, uuid), oyun.makam_sahibi(text, text, smallint),
  oyun.bakanlik_yetkilisi(text), oyun.pazar_tl_milyar(), oyun.pazar_il_agirlik(smallint), oyun.sektor_pol_durum(text, timestamptz),
  oyun.sektor_pol_carpan(text, timestamptz) from public, anon, authenticated;
commit;
