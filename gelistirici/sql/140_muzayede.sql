-- =====================================================================
--  140 · MÜZAYEDE EVİ (25.10.2026)
--  Koleksiyon eserleri (tablo, siyasi tarih belgesi, sikke, pul, antika,
--  saat, klasik otomobil, mücevher, halı) açık artırmayla satılır.
--  · Müzayede evi kataloğdan sınırlı sayıda eser basar (her eserin baskı
--    adedi sabittir: sıradan 4, nadir 3, çok nadir 2, efsanevi 1) ve
--    sürekli ~6 lot açık tutar. Satış bedeli Hazine'ye gelir (para yutağı).
--  · Oyuncu pey verir; pey tutarı cüzdandan bloke edilir, pey geçilince
--    eski lidere anında iade edilir. Son 5 dakikada gelen pey süreyi
--    5 dakika uzatır (en fazla 2 saat).
--  · Eserin tahmini değeri = taban × kategori endeksi × kondisyon × prim
--    (× 1,25 set tamamlama). Kategori endeksi her gün gerçek satış
--    fiyatlarına (talep) göre yükselir ya da düşer; eserin kendi primi
--    son satış fiyatıyla şekillenir ve zamanla 1'e döner.
--  · Oyuncu eserini yeniden açık artırmaya çıkarabilir (%1 ilan ücreti,
--    satışta %7 komisyon), özel müzesinde sergileyip günlük sergi geliri
--    alabilir (günde en fazla 2.000 ₺), müzayede evine değerinin %50'sine
--    satabilir (alımdan 72 saat sonra) ya da Devlet Müzesi'ne bağışlayıp
--    kıdem puanı kazanabilir (bağış başına en fazla +5, toplam +20).
--  Yalnız yeni tablo / fonksiyon ekler; iki kez çalıştırmak güvenlidir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.muzayede_kategori (
  kod text primary key,
  ad text not null,
  endeks numeric not null default 1 check (endeks > 0),
  guncelleme timestamptz,
  sira integer not null default 0
);
create table if not exists oyun.muzayede_endeks_gecmis (
  kategori text not null references oyun.muzayede_kategori(kod) on delete cascade,
  gun date not null,
  endeks numeric not null,
  primary key (kategori, gun)
);
create table if not exists oyun.muzayede_katalog (
  kod text primary key,
  ad text not null,
  kategori text not null references oyun.muzayede_kategori(kod),
  seri text not null,
  nadirlik text not null check (nadirlik in ('siradan','nadir','cok_nadir','efsanevi')),
  taban numeric not null check (taban > 0),
  adet integer not null check (adet between 1 and 10),
  motif text not null,
  renk text not null default '#c9a227',
  donem text,
  aciklama text not null
);
create table if not exists oyun.muzayede_eserler (
  id bigserial primary key,
  katalog text not null references oyun.muzayede_katalog(kod),
  no integer not null,
  kondisyon numeric not null check (kondisyon between 0.5 and 1.5),
  prim numeric not null default 1 check (prim between 0.3 and 3),
  sahip uuid references oyun.profiller(id) on delete set null,
  durum text not null default 'havuz' check (durum in ('havuz','kasa','sergide','artirmada','muzede')),
  alis_bedeli numeric,
  alis_zaman timestamptz,
  son_fiyat numeric,
  son_satis timestamptz,
  sergi_bas timestamptz,
  bagisci uuid references oyun.profiller(id) on delete set null,
  bagis_zaman timestamptz,
  bagis_kidem numeric not null default 0,
  olusturma timestamptz not null default now(),
  unique (katalog, no)
);
create index if not exists muzayede_eser_sahip_idx on oyun.muzayede_eserler(sahip) where sahip is not null;
create index if not exists muzayede_eser_durum_idx on oyun.muzayede_eserler(durum);

create table if not exists oyun.muzayede_lotlar (
  id bigserial primary key,
  eser_id bigint not null references oyun.muzayede_eserler(id),
  satici uuid references oyun.profiller(id) on delete set null,
  baslangic numeric not null check (baslangic >= 100),
  bitis timestamptz not null,
  ilk_bitis timestamptz not null,
  durum text not null default 'acik' check (durum in ('acik','satildi','satilmadi','iptal')),
  en_yuksek numeric,
  lider uuid references oyun.profiller(id) on delete set null,
  pey_sayisi integer not null default 0,
  ucret numeric not null default 0,
  olusturma timestamptz not null default now(),
  kapanis timestamptz
);
create unique index if not exists muzayede_lot_tek_acik on oyun.muzayede_lotlar(eser_id) where durum = 'acik';
create index if not exists muzayede_lot_acik_idx on oyun.muzayede_lotlar(bitis) where durum = 'acik';
create index if not exists muzayede_lot_satici_idx on oyun.muzayede_lotlar(satici, olusturma desc);

create table if not exists oyun.muzayede_peyler (
  id bigserial primary key,
  lot_id bigint not null references oyun.muzayede_lotlar(id) on delete cascade,
  kim uuid not null references oyun.profiller(id) on delete cascade,
  tutar numeric not null check (tutar > 0),
  zaman timestamptz not null default now(),
  durum text not null default 'lider' check (durum in ('lider','gecildi','kazandi','iade'))
);
create index if not exists muzayede_pey_lot_idx on oyun.muzayede_peyler(lot_id, zaman desc);
create index if not exists muzayede_pey_kim_idx on oyun.muzayede_peyler(kim, zaman desc);

create table if not exists oyun.muzayede_satislar (
  id bigserial primary key,
  lot_id bigint references oyun.muzayede_lotlar(id) on delete set null,
  eser_id bigint not null references oyun.muzayede_eserler(id),
  kategori text not null,
  satici uuid,
  alici uuid,
  fiyat numeric not null,
  model_deger numeric not null,
  tur text not null default 'artirma' check (tur in ('artirma','eve_satis','satilmadi')),
  zaman timestamptz not null default now()
);
alter table oyun.muzayede_satislar add column if not exists pey_sayisi integer not null default 0;
create index if not exists muzayede_satis_kat_idx on oyun.muzayede_satislar(kategori, zaman desc);
create index if not exists muzayede_satis_eser_idx on oyun.muzayede_satislar(eser_id, zaman desc);

create table if not exists oyun.muzayede_sergi_odeme (
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  gun date not null,
  tutar numeric not null,
  primary key (user_id, gun)
);
create table if not exists oyun.muzayede_ayar (
  id integer primary key default 1 check (id = 1),
  acik_lot_hedef integer not null default 6,
  son_gunluk date,
  son_efsanevi timestamptz,
  sergi_tavan numeric not null default 2000,
  komisyon numeric not null default 0.07,
  eve_satis_oran numeric not null default 0.5,
  baslangic_oran numeric not null default 0.6
);
insert into oyun.muzayede_ayar(id) values (1) on conflict (id) do nothing;

alter table oyun.muzayede_kategori enable row level security;
alter table oyun.muzayede_endeks_gecmis enable row level security;
alter table oyun.muzayede_katalog enable row level security;
alter table oyun.muzayede_eserler enable row level security;
alter table oyun.muzayede_lotlar enable row level security;
alter table oyun.muzayede_peyler enable row level security;
alter table oyun.muzayede_satislar enable row level security;
alter table oyun.muzayede_sergi_odeme enable row level security;
alter table oyun.muzayede_ayar enable row level security;

-- ---------------------------------------------------------------------
-- B. KATALOG (kurgusal eserler; gerçek sanat eseri / marka kullanılmaz)
-- ---------------------------------------------------------------------
insert into oyun.muzayede_kategori(kod, ad, sira) values
  ('tablo','Tablolar',1), ('belge','Siyasi tarih',2), ('sikke','Sikkeler',3), ('pul','Pullar',4),
  ('antika','Antikalar',5), ('saat','Saatler',6), ('otomobil','Klasik otomobiller',7),
  ('mucevher','Mücevherler',8), ('hali','Halı ve kilim',9)
on conflict (kod) do nothing;

insert into oyun.muzayede_katalog(kod, ad, kategori, seri, nadirlik, taban, adet, motif, renk, donem, aciklama) values
 ('t_kandilli','Kandilli''de Gün Batımı','tablo','Boğaziçi Manzaraları','siradan',6000,4,'tablo_deniz','#e0894a','1890''lar','Yağlı boya; Anadolu yakasında akşamüstü, sulara vuran turuncu ışık.'),
 ('t_sisli','Sisli Boğaz ve Kayıklar','tablo','Boğaziçi Manzaraları','siradan',5500,4,'tablo_deniz','#8fa6c2','1900''ler','Sabah sisinde balıkçı kayıkları; soluk mavi ve gri tonlar.'),
 ('t_rumeli','Rumelihisarı''nda Sabah','tablo','Boğaziçi Manzaraları','nadir',22000,3,'tablo_deniz','#5fa3c9','1880''ler','Hisar burçları ve güneşin doğuşu; ressamın en bilinen serisinden.'),
 ('t_yali','Yalı Önünde Kayıkçılar','tablo','Boğaziçi Manzaraları','nadir',26000,3,'tablo_deniz','#4f8a8b','1890''lar','Ahşap yalının önünde bekleyen kayıkçılar; ince fırça işçiliği.'),
 ('t_kulede','Kız Kulesi''nde Fırtına','tablo','Boğaziçi Manzaraları','cok_nadir',85000,2,'tablo_deniz','#3a4f7a','1870''ler','Fırtınalı denizde kule ve kıyıya vuran dalgalar; serinin başyapıtı.'),
 ('t_dokumaci','Kapadokyalı Dokumacı','tablo','Anadolu''dan Portreler','siradan',5000,4,'tablo_portre','#c9733f','1930''lar','Tezgâh başında genç bir dokumacı; sıcak toprak renkleri.'),
 ('t_zeytin','Egeli Zeytin Hasatçısı','tablo','Anadolu''dan Portreler','siradan',5200,4,'tablo_portre','#7f9a4f','1930''lar','Sırtında sepetle zeytinlikte yaşlı bir kadın.'),
 ('t_kemence','Karadenizli Kemençeci','tablo','Anadolu''dan Portreler','nadir',19000,3,'tablo_portre','#2f6b5a','1940''lar','Yayla şenliğinde kemençe çalan genç; canlı yeşiller.'),
 ('t_ogretmen','Ankara''da İlk Öğretmen','tablo','Anadolu''dan Portreler','cok_nadir',72000,2,'tablo_portre','#6b4a8a','1920''ler','Yeni açılan bir köy okulunda ilk dersini veren öğretmen.'),
 ('b_afis','1946 Seçim Afişi','belge','Cumhuriyetin İlk Seçimleri','siradan',4500,4,'afis','#c62828','1946','Çok partili döneme geçişin ilk seçim afişlerinden; taş baskı.'),
 ('b_pusula','1950 Tarihli Oy Pusulası','belge','Cumhuriyetin İlk Seçimleri','siradan',4000,4,'pusula','#8d6e63','1950','Kullanılmamış, mühürsüz bir oy pusulası; dönemin baskı tekniği.'),
 ('b_sandik','Ahşap Oy Sandığı','belge','Cumhuriyetin İlk Seçimleri','nadir',18000,3,'sandik','#a1887f','1950''ler','Bir ilçe seçim kurulundan kalma, kilitli ahşap sandık.'),
 ('b_davetiye','Meclis Açılış Davetiyesi','belge','Cumhuriyetin İlk Seçimleri','nadir',24000,3,'davetiye','#c9a227','1920''ler','Yeni dönemin açılış oturumu için basılmış yaldızlı davetiye.'),
 ('b_mazbata','1935 Seçim Mazbatası','belge','Cumhuriyetin İlk Seçimleri','cok_nadir',68000,2,'mazbata','#b71c1c','1935','Seçilen bir milletvekiline verilmiş ıslak imzalı mazbata.'),
 ('b_tutanak','Kurucu Meclis Tutanak Defteri','belge','Cumhuriyetin İlk Seçimleri','efsanevi',320000,1,'defter','#5d4037','1920''ler','Meclisin ilk oturumlarına ait el yazması tutanak defteri. Tek nüsha.'),
 ('s_akce','Osmanlı Gümüş Akçesi','sikke','Anadolu Uygarlıkları','siradan',4200,4,'sikke','#b0bec5','15. yüzyıl','İnce gümüş akçe; tuğra izleri okunabiliyor.'),
 ('s_sestertius','Roma Bronz Sestertiusu','sikke','Anadolu Uygarlıkları','siradan',4800,4,'sikke','#a1663a','2. yüzyıl','Anadolu''da basılmış bronz sikke; yeşil patina.'),
 ('s_dirhem','Selçuklu Gümüş Dirhemi','sikke','Anadolu Uygarlıkları','nadir',17000,3,'sikke','#cfd8dc','13. yüzyıl','Kûfi yazılı gümüş dirhem; çok iyi korunmuş.'),
 ('s_solidus','Bizans Altın Solidusu','sikke','Anadolu Uygarlıkları','nadir',28000,3,'sikke','#d4af37','6. yüzyıl','Saf altından solidus; kenarları kırpılmamış.'),
 ('s_elektrum','Lidya Elektrum Sikkesi','sikke','Anadolu Uygarlıkları','cok_nadir',95000,2,'sikke','#e6c35c','MÖ 6. yüzyıl','Dünyanın ilk sikkelerinden; aslan başı damgalı elektrum.'),
 ('p_onyil','Cumhuriyetin 10. Yılı Blok Pulu','pul','Cumhuriyet Pulları','siradan',4000,4,'pul','#c62828','1933','Onuncu yıl kutlamaları için basılmış blok pul.'),
 ('p_kurtulus','Kurtuluş Savaşı Anma Pulu','pul','Cumhuriyet Pulları','siradan',4300,4,'pul','#2e7d32','1920''ler','Damgasız anma pulu; renkleri canlı.'),
 ('p_hava','İlk Hava Postası Pulu','pul','Cumhuriyet Pulları','nadir',16000,3,'pul','#1565c0','1930''lar','İlk hava postası serisinden; uçak motifli.'),
 ('p_hatali','Hatalı Basım 1929 Pulu','pul','Cumhuriyet Pulları','cok_nadir',64000,2,'pul','#6a1b9a','1929','Ters basılmış merkez desenli hatalı pul; koleksiyoncuların gözdesi.'),
 ('a_ibrik','Tombak İbrik','antika','Saray Sofrası','siradan',5500,4,'ibrik','#c58b3a','18. yüzyıl','Altın yaldızlı bakır ibrik; kabartma çiçek motifleri.'),
 ('a_cini','İznik Çinili Tabak','antika','Saray Sofrası','nadir',21000,3,'tabak','#1e6fa8','16. yüzyıl','Lale ve karanfil desenli, mercan kırmızılı çini tabak.'),
 ('a_serbetlik','Gümüş Şerbetlik Takımı','antika','Saray Sofrası','nadir',23000,3,'vazo','#b0bec5','19. yüzyıl','Kapaklı gümüş şerbetlik, tepsi ve iki bardak.'),
 ('a_beykoz','Beykoz İşi Cam Sürahi','antika','Saray Sofrası','nadir',19500,3,'vazo','#7e57c2','19. yüzyıl','Yaldızlı süt camı sürahi; ince işçilik.'),
 ('a_zarf','Mücevherli Fincan Zarfı','antika','Saray Sofrası','cok_nadir',78000,2,'zarf','#d4af37','18. yüzyıl','Altın fincan zarfı; yakut ve zümrüt taşlı.'),
 ('z_cep','Gümüş Cep Saati','saat','Zamanın Ustaları','siradan',6500,4,'saat','#b0bec5','1900''ler','Kapaklı gümüş cep saati; hâlâ çalışıyor.'),
 ('z_masa','Pirinç Masa Saati','saat','Zamanın Ustaları','nadir',20000,3,'saat','#c9a227','1880''ler','Camlı pirinç kasa; çeyrek vuruşlu.'),
 ('z_mineli','Mineli Köstekli Cep Saati','saat','Zamanın Ustaları','cok_nadir',82000,2,'saat','#3949ab','1850''ler','Mavi mine kapaklı, altın köstekli cep saati.'),
 ('z_astronomik','Saray İçin Yapılmış Astronomik Saat','saat','Zamanın Ustaları','efsanevi',300000,1,'saat','#d4af37','18. yüzyıl','Ay evrelerini ve takvimi gösteren astronomik saat. Tek nüsha.'),
 ('o_dolmus','1958 Model Dolmuş Taksi','otomobil','Yollarımızın Klasikleri','nadir',30000,3,'araba','#f9a825','1958','Damalı şeritli eski dolmuş; orijinal kadranlar.'),
 ('o_aile','1972 Yerli Üretim Aile Otomobili','otomobil','Yollarımızın Klasikleri','nadir',27000,3,'araba','#8d6e63','1972','Yerli banttan çıkmış ilk aile otomobillerinden.'),
 ('o_cabrio','1966 Üstü Açık Klasik','otomobil','Yollarımızın Klasikleri','cok_nadir',90000,2,'araba','#c62828','1966','Kırmızı üstü açık klasik; restore edilmiş.'),
 ('o_prototip','1961 Yerli Prototip Sedan','otomobil','Yollarımızın Klasikleri','efsanevi',360000,1,'araba','#263238','1961','Yerli mühendislerin elinden çıkmış prototip sedan. Tek nüsha.'),
 ('m_zumrut','Zümrüt Broş','mucevher','Hazine Odası','nadir',25000,3,'mucevher','#2e7d32','19. yüzyıl','Pırlanta çevrili büyük zümrüt broş.'),
 ('m_yakut','Yakut Yüzük','mucevher','Hazine Odası','nadir',23000,3,'mucevher','#c62828','19. yüzyıl','Altın yuvaya oturtulmuş kan kırmızısı yakut.'),
 ('m_gerdanlik','Altın Gerdanlık','mucevher','Hazine Odası','cok_nadir',88000,2,'mucevher','#d4af37','18. yüzyıl','İnci sarkaçlı, kakma altın gerdanlık.'),
 ('m_sorguc','Elmas Sorguç','mucevher','Hazine Odası','efsanevi',340000,1,'mucevher','#90caf9','17. yüzyıl','Kavuk süslemesi elmas sorguç. Tek nüsha.'),
 ('h_kilim','Kars Kilimi','hali','Anadolu Halıları','siradan',5200,4,'hali','#b23a3a','20. yüzyıl başı','Kök boyalı, geometrik desenli kilim.'),
 ('h_cuval','Yörük Çuvalı','hali','Anadolu Halıları','siradan',4600,4,'hali','#6d4c41','19. yüzyıl','Göçebe yörüklerin heybe ve çuval dokuması.'),
 ('h_hereke','Hereke İpek Seccade','hali','Anadolu Halıları','nadir',24000,3,'hali','#1e5f8a','1900''ler','Santimetrekarede yüksek düğüm sıklığıyla ipek seccade.'),
 ('h_usak','Uşak Madalyonlu Halı','hali','Anadolu Halıları','cok_nadir',76000,2,'hali','#8e2b2b','16. yüzyıl','Büyük madalyonlu saray halısı; yünü canlı kalmış.')
on conflict (kod) do nothing;

-- ---------------------------------------------------------------------
-- C. YARDIMCILAR
-- ---------------------------------------------------------------------
create or replace function oyun.mz_nadirlik_ad(p text) returns text language sql immutable set search_path = '' as $$
  select case p when 'siradan' then 'Sıradan' when 'nadir' then 'Nadir' when 'cok_nadir' then 'Çok nadir' when 'efsanevi' then 'Efsanevi' else p end
$$;
create or replace function oyun.mz_sergi_oran(p text) returns numeric language sql immutable set search_path = '' as $$
  select case p when 'efsanevi' then 0.0025 when 'cok_nadir' then 0.0022 when 'nadir' then 0.0018 else 0.0015 end
$$;
create or replace function oyun.mz_yuvarla(p numeric) returns numeric language sql immutable set search_path = '' as $$
  select case when p >= 100000 then round(p / 1000) * 1000 when p >= 10000 then round(p / 100) * 100 else round(p / 50) * 50 end
$$;
-- Oyuncu bir serinin bütün eserlerine sahip mi (müzede ya da havuzdakiler hariç)
create or replace function oyun.mz_set_tam(p_sahip uuid, p_seri text) returns boolean
language sql stable set search_path = '' as $$
  select p_sahip is not null and
    (select count(distinct k.kod) from oyun.muzayede_katalog k where k.seri = p_seri) =
    (select count(distinct e.katalog) from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog
      where k.seri = p_seri and e.sahip = p_sahip and e.durum in ('kasa','sergide','artirmada'))
$$;
-- Model değer (prim hariç) ve tahmini değer
create or replace function oyun.mz_model(p_eser bigint) returns numeric
language sql stable set search_path = '' as $$
  select k.taban * c.endeks * e.kondisyon
    from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog join oyun.muzayede_kategori c on c.kod = k.kategori
   where e.id = p_eser
$$;
create or replace function oyun.mz_deger(p_eser bigint) returns numeric
language sql stable set search_path = '' as $$
  select oyun.mz_yuvarla(k.taban * c.endeks * e.kondisyon * e.prim
           * case when e.sahip is not null and oyun.mz_set_tam(e.sahip, k.seri) then 1.25 else 1 end)
    from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog join oyun.muzayede_kategori c on c.kod = k.kategori
   where e.id = p_eser
$$;
create or replace function oyun.mz_kad(p uuid) returns text language sql stable set search_path = '' as $$
  select kad from oyun.profiller where id = p
$$;
-- Bir sonraki geçerli pey alt sınırı
create or replace function oyun.mz_min_pey(p_lot bigint) returns numeric
language sql stable set search_path = '' as $$
  select case when l.pey_sayisi = 0 or l.en_yuksek is null then l.baslangic
              else l.en_yuksek + greatest(100, ceil(l.en_yuksek * 0.05 / 100) * 100) end
    from oyun.muzayede_lotlar l where l.id = p_lot
$$;

create or replace function oyun.mz_eser_ozet(p_eser bigint, p_u uuid) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', e.id, 'kod', k.kod, 'ad', k.ad, 'kategori', k.kategori, 'kategori_ad', c.ad, 'seri', k.seri,
    'nadirlik', k.nadirlik, 'nadirlik_ad', oyun.mz_nadirlik_ad(k.nadirlik), 'no', e.no, 'adet', k.adet,
    'motif', k.motif, 'renk', k.renk, 'donem', k.donem, 'aciklama', k.aciklama,
    'kondisyon', round(e.kondisyon, 2), 'deger', oyun.mz_deger(e.id), 'durum', e.durum,
    'sahip', oyun.mz_kad(e.sahip), 'benim', e.sahip is not null and e.sahip = p_u,
    'set_tam', e.sahip is not null and oyun.mz_set_tam(e.sahip, k.seri),
    'son_fiyat', e.son_fiyat, 'son_satis', e.son_satis,
    'alis_bedeli', case when e.sahip = p_u then e.alis_bedeli end,
    'alis_zaman', case when e.sahip = p_u then e.alis_zaman end,
    'bagisci', oyun.mz_kad(e.bagisci), 'bagis_zaman', e.bagis_zaman)
  from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog join oyun.muzayede_kategori c on c.kod = k.kategori
  where e.id = p_eser
$$;

create or replace function oyun.mz_lot_ozet(p_lot bigint, p_u uuid) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', l.id, 'eser', oyun.mz_eser_ozet(l.eser_id, p_u), 'baslangic', l.baslangic, 'bitis', l.bitis,
    'durum', l.durum, 'en_yuksek', l.en_yuksek, 'pey_sayisi', l.pey_sayisi, 'lider', oyun.mz_kad(l.lider),
    'lider_benim', l.lider is not null and l.lider = p_u, 'satici', coalesce(oyun.mz_kad(l.satici), 'Müzayede Evi'),
    'satici_benim', l.satici is not null and l.satici = p_u, 'min_pey', oyun.mz_min_pey(l.id),
    'peyim', (select max(pp.tutar) from oyun.muzayede_peyler pp where pp.lot_id = l.id and pp.kim = p_u),
    'uzadi', l.bitis > l.ilk_bitis)
  from oyun.muzayede_lotlar l where l.id = p_lot
$$;

-- ---------------------------------------------------------------------
-- D. ÇEKİRDEK İŞLEMLER (yalnız sunucu içinden çağrılır)
-- ---------------------------------------------------------------------
-- Kataloğdan yeni bir eser bas (baskı adedi dolmamışsa); kondisyon 0,85–1,25
create or replace function oyun.mz_eser_bas(p_katalog text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare k oyun.muzayede_katalog; v_no integer; v_id bigint; v_kond numeric;
begin
  select * into k from oyun.muzayede_katalog where kod = p_katalog;
  if k.kod is null then return null; end if;
  perform pg_advisory_xact_lock(91407, hashtext(p_katalog));
  select coalesce(max(no), 0) + 1 into v_no from oyun.muzayede_eserler where katalog = k.kod;
  if v_no > k.adet then return null; end if;
  v_kond := round((0.85 + (random() + random() + random()) / 3 * 0.40)::numeric, 2);
  insert into oyun.muzayede_eserler(katalog, no, kondisyon, durum) values (k.kod, v_no, v_kond, 'havuz') returning id into v_id;
  return v_id;
end $$;

-- Müzayede evinin açık lot sayısını hedefte tut (önce havuzdaki eserler, sonra yeni baskı)
create or replace function oyun.mz_sistem_lot_ac(p_adet integer default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  a oyun.muzayede_ayar; v_t timestamptz := oyun.simdi(); v_acik integer; v_eksik integer; v_acilan integer := 0;
  v_nad text; v_eser bigint; v_saat numeric; v_deger numeric; r double precision; v_deneme integer;
begin
  if not oyun.uzaktan_modul_acik('muzayede') then return 0; end if;
  perform pg_advisory_xact_lock(91407, 1);
  select * into a from oyun.muzayede_ayar where id = 1 for update;
  select count(*) into v_acik from oyun.muzayede_lotlar where durum = 'acik' and satici is null;
  v_eksik := coalesce(p_adet, a.acik_lot_hedef - v_acik);
  while v_eksik > 0 loop
    v_eser := null; v_deneme := 0;
    while v_eser is null and v_deneme < 6 loop
      v_deneme := v_deneme + 1;
      r := random();
      v_nad := case when r < 0.05 then 'efsanevi' when r < 0.22 then 'cok_nadir' when r < 0.55 then 'nadir' else 'siradan' end;
      if v_nad = 'efsanevi' and (exists (select 1 from oyun.muzayede_lotlar l join oyun.muzayede_eserler e on e.id = l.eser_id
             join oyun.muzayede_katalog k on k.kod = e.katalog where l.durum = 'acik' and k.nadirlik = 'efsanevi')
           or (a.son_efsanevi is not null and a.son_efsanevi > v_t - interval '72 hours')) then
        v_nad := 'cok_nadir';
      end if;
      -- 1) havuzda bekleyen (satılmamış / müzayede evine satılmış) eser
      select e.id into v_eser from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog
       where e.durum = 'havuz' and e.sahip is null and k.nadirlik = v_nad
         and not exists (select 1 from oyun.muzayede_lotlar l where l.eser_id = e.id and l.durum = 'acik')
         and not exists (select 1 from oyun.muzayede_lotlar l where l.eser_id = e.id and l.kapanis > v_t - interval '12 hours')
       order by random() limit 1;
      -- 2) yeni baskı
      if v_eser is null then
        select oyun.mz_eser_bas(x.kod) into v_eser from (
          select k.kod from oyun.muzayede_katalog k
           where k.nadirlik = v_nad and (select count(*) from oyun.muzayede_eserler e where e.katalog = k.kod) < k.adet
           order by random() limit 1) x;
      end if;
    end loop;
    exit when v_eser is null;
    v_saat := case v_nad when 'efsanevi' then 48 when 'cok_nadir' then 24 + random() * 12 when 'nadir' then 20 + random() * 8 else 14 + random() * 8 end;
    v_deger := oyun.mz_deger(v_eser);
    insert into oyun.muzayede_lotlar(eser_id, satici, baslangic, bitis, ilk_bitis)
      values (v_eser, null, greatest(500, oyun.mz_yuvarla(v_deger * a.baslangic_oran)),
              date_trunc('minute', v_t + make_interval(secs => v_saat * 3600)), date_trunc('minute', v_t + make_interval(secs => v_saat * 3600)));
    update oyun.muzayede_eserler set durum = 'artirmada' where id = v_eser;
    if v_nad = 'efsanevi' then update oyun.muzayede_ayar set son_efsanevi = v_t where id = 1; end if;
    v_acilan := v_acilan + 1; v_eksik := v_eksik - 1;
  end loop;
  return v_acilan;
end $$;

-- Süresi dolan lotu sonuçlandır
create or replace function oyun.mz_lot_kapat(p_lot bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare
  l oyun.muzayede_lotlar; e oyun.muzayede_eserler; k oyun.muzayede_katalog; a oyun.muzayede_ayar;
  v_t timestamptz := oyun.simdi(); v_model numeric; v_kom numeric; v_oran numeric;
begin
  select * into l from oyun.muzayede_lotlar where id = p_lot for update;
  if l.id is null or l.durum <> 'acik' or l.bitis > v_t then return; end if;
  select * into a from oyun.muzayede_ayar where id = 1;
  select * into e from oyun.muzayede_eserler where id = l.eser_id for update;
  select * into k from oyun.muzayede_katalog where kod = e.katalog;
  v_model := oyun.mz_model(e.id);
  if l.lider is not null and l.en_yuksek is not null then
    -- Eser kazanana; pey zaten bloke edilmişti
    v_oran := greatest(0.3, least(3, l.en_yuksek / nullif(v_model, 0)));
    update oyun.muzayede_eserler
       set sahip = l.lider, durum = 'kasa', alis_bedeli = l.en_yuksek, alis_zaman = v_t, son_fiyat = l.en_yuksek, son_satis = v_t,
           sergi_bas = null, prim = greatest(0.6, least(2.2, round((e.prim * 0.5 + sqrt(v_oran) * 0.5)::numeric, 4)))
     where id = e.id;
    update oyun.muzayede_peyler set durum = 'kazandi' where lot_id = l.id and kim = l.lider and durum = 'lider';
    update oyun.muzayede_lotlar set durum = 'satildi', kapanis = v_t where id = l.id;
    if l.satici is not null then
      v_kom := round(l.en_yuksek * a.komisyon);
      perform oyun.para_islem(l.satici, l.en_yuksek - v_kom, 'muzayede',
        format('Müzayede: “%s” satıldı (%%%s komisyon düşüldü)', k.ad, round(a.komisyon * 100)), v_t, v_kom);
      update oyun.ulke set hazine = hazine + v_kom / oyun.pazar_tl_milyar() where id = 1;
      perform oyun.bildir(l.satici, format('Müzayede: “%s” eserin %s ₺ bedelle %s adlı oyuncuya satıldı.', k.ad, oyun.tl(l.en_yuksek), oyun.mz_kad(l.lider)), v_t);
    else
      update oyun.ulke set hazine = hazine + l.en_yuksek / oyun.pazar_tl_milyar() where id = 1;
    end if;
    insert into oyun.muzayede_satislar(lot_id, eser_id, kategori, satici, alici, fiyat, model_deger, tur, zaman, pey_sayisi)
      values (l.id, e.id, k.kategori, l.satici, l.lider, l.en_yuksek, v_model, 'artirma', v_t, l.pey_sayisi);
    perform oyun.bildir(l.lider, format('Müzayede: “%s” artık senin! %s ₺ ile açık artırmayı kazandın; eser koleksiyonuna eklendi.', k.ad, oyun.tl(l.en_yuksek)), v_t);
  else
    update oyun.muzayede_lotlar set durum = 'satilmadi', kapanis = v_t where id = l.id;
    if l.satici is not null then
      update oyun.muzayede_eserler set durum = case when sahip = l.satici then 'kasa' else durum end where id = e.id;
      perform oyun.bildir(l.satici, format('Müzayede: “%s” için pey gelmedi; eser koleksiyonuna geri döndü.', k.ad), v_t);
    else
      update oyun.muzayede_eserler set durum = 'havuz', sahip = null where id = e.id;
      insert into oyun.muzayede_satislar(lot_id, eser_id, kategori, satici, alici, fiyat, model_deger, tur, zaman)
        values (l.id, e.id, k.kategori, null, null, 0, v_model, 'satilmadi', v_t);
    end if;
  end if;
end $$;

-- Günlük: kategori endeksleri (talep), primlerin 1'e dönüşü, sergi gelirleri
create or replace function oyun.mz_gunluk() returns void
language plpgsql security definer set search_path = '' as $$
declare
  a oyun.muzayede_ayar; v_t timestamptz := oyun.simdi(); v_gun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
  c record; v_talep numeric; v_n integer; v_deg numeric; r record; v_gelir numeric;
begin
  select * into a from oyun.muzayede_ayar where id = 1 for update;
  if a.son_gunluk is not null and a.son_gunluk >= v_gun then return; end if;
  update oyun.muzayede_ayar set son_gunluk = v_gun where id = 1;
  -- 1) Endeks: son 7 günün rekabeti. Her lot için talep puanı: satılmadı −1, tek pey 0, 2–3 pey +0,5,
  --    4+ pey +1; çekiç fiyatı tahmini değeri aşarsa aşan oran kadar (en çok +1) eklenir.
  for c in select * from oyun.muzayede_kategori loop
    select count(*), avg(case when s.tur = 'satilmadi' then -1
                              else (case when s.pey_sayisi >= 4 then 1 when s.pey_sayisi >= 2 then 0.5 else 0 end)
                                   + greatest(0, least(1, s.fiyat / nullif(s.model_deger, 0) - 1)) end)
      into v_n, v_talep
      from oyun.muzayede_satislar s where s.kategori = c.kod and s.zaman > v_t - interval '7 days' and s.tur in ('artirma','satilmadi');
    if v_n = 0 or v_talep is null then v_deg := -0.002;           -- işlem yoksa piyasa çok hafif soğur
    else v_deg := greatest(-0.04, least(0.06, 0.03 * v_talep)); end if;
    v_deg := v_deg + (random() * 0.016 - 0.008);
    update oyun.muzayede_kategori set endeks = greatest(0.4, least(4, round((endeks * (1 + v_deg))::numeric, 4))), guncelleme = v_t where kod = c.kod;
    insert into oyun.muzayede_endeks_gecmis(kategori, gun, endeks)
      select kod, v_gun, endeks from oyun.muzayede_kategori where kod = c.kod
      on conflict (kategori, gun) do update set endeks = excluded.endeks;
  end loop;
  -- 2) Son satıştan gelen prim her gün %3 sönümlenir
  update oyun.muzayede_eserler set prim = round((1 + (prim - 1) * 0.97)::numeric, 4) where prim <> 1 and durum <> 'muzede';
  -- 3) Sergi geliri (en az 20 saattir sergide olan eserler; kişi başı tavan)
  for r in select e.sahip, sum(oyun.mz_deger(e.id) * oyun.mz_sergi_oran(k.nadirlik)) as gelir, count(*) as n
             from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog
             join oyun.profiller p on p.id = e.sahip and not p.yasakli
            where e.durum = 'sergide' and e.sahip is not null and e.sergi_bas <= v_t - interval '20 hours'
            group by e.sahip loop
    v_gelir := least(a.sergi_tavan, round(r.gelir));
    continue when v_gelir < 1;
    insert into oyun.muzayede_sergi_odeme(user_id, gun, tutar) values (r.sahip, v_gun, v_gelir) on conflict do nothing;
    if found then
      perform oyun.para_islem(r.sahip, v_gelir, 'muzayede', format('Müzayede: özel müzendeki %s eserin sergi geliri', r.n), v_t);
      update oyun.ulke set hazine = hazine - v_gelir / oyun.pazar_tl_milyar() where id = 1;
    end if;
  end loop;
end $$;

-- Zamanlayıcı: lotları kapat, günlük işleri yap, salonu doldur
create or replace function oyun.muzayede_bakim() returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select id from oyun.muzayede_lotlar where durum = 'acik' and bitis <= oyun.simdi() order by bitis limit 200 loop
    begin
      perform oyun.mz_lot_kapat(r.id);
    exception when others then
      raise warning 'muzayede lot % kapatılamadı: %', r.id, sqlerrm;
    end;
  end loop;
  perform oyun.mz_gunluk();
  perform oyun.mz_sistem_lot_ac();
end $$;

-- ---------------------------------------------------------------------
-- E. OYUNCU İŞLEMLERİ (public RPC)
-- ---------------------------------------------------------------------
-- Salon: açık lotlar, kategori endeksleri, son satışlar, kişisel özet
create or replace function public.muzayede_salon()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); a oyun.muzayede_ayar;
begin
  select * into a from oyun.muzayede_ayar where id = 1;
  -- Zamanlayıcıyı beklemeden süresi dolanları kapat (kısa ve güvenli)
  perform oyun.mz_lot_kapat(l.id) from oyun.muzayede_lotlar l where l.durum = 'acik' and l.bitis <= v_t;
  return jsonb_build_object(
    'simdi', v_t, 'acik', oyun.uzaktan_modul_acik('muzayede'),
    'lotlar', coalesce((select jsonb_agg(oyun.mz_lot_ozet(l.id, p.id) order by l.bitis)
                          from oyun.muzayede_lotlar l where l.durum = 'acik'), '[]'::jsonb),
    'kategoriler', coalesce((select jsonb_agg(jsonb_build_object('kod', c.kod, 'ad', c.ad, 'endeks', round(c.endeks, 4),
          'degisim7', round(((c.endeks / nullif((select g.endeks from oyun.muzayede_endeks_gecmis g where g.kategori = c.kod and g.gun <= (v_t at time zone 'Europe/Istanbul')::date - 7 order by g.gun desc limit 1), 0)) - 1) * 100, 1),
          'seri', coalesce((select jsonb_agg(g.endeks order by g.gun) from (select * from oyun.muzayede_endeks_gecmis g2 where g2.kategori = c.kod order by g2.gun desc limit 30) g), '[]'::jsonb)
        ) order by c.sira) from oyun.muzayede_kategori c), '[]'::jsonb),
    'son_satislar', coalesce((select jsonb_agg(x order by (x->>'zaman') desc) from (
        select jsonb_build_object('eser', k.ad, 'nadirlik', k.nadirlik, 'motif', k.motif, 'renk', k.renk, 'fiyat', s.fiyat,
               'alici', oyun.mz_kad(s.alici), 'zaman', s.zaman, 'oran', round(s.fiyat / nullif(s.model_deger, 0), 2)) x
          from oyun.muzayede_satislar s join oyun.muzayede_eserler e on e.id = s.eser_id join oyun.muzayede_katalog k on k.kod = e.katalog
         where s.tur = 'artirma' order by s.zaman desc limit 12) t), '[]'::jsonb),
    'benim', jsonb_build_object(
      'eser', (select count(*) from oyun.muzayede_eserler e where e.sahip = p.id and e.durum in ('kasa','sergide','artirmada')),
      'deger', coalesce((select sum(oyun.mz_deger(e.id)) from oyun.muzayede_eserler e where e.sahip = p.id and e.durum in ('kasa','sergide','artirmada')), 0),
      'lider', (select count(*) from oyun.muzayede_lotlar l where l.durum = 'acik' and l.lider = p.id),
      'bloke', coalesce((select sum(l.en_yuksek) from oyun.muzayede_lotlar l where l.durum = 'acik' and l.lider = p.id), 0),
      'cuzdan', (select c.para from oyun.cuzdan c where c.user_id = p.id)),
    'kurallar', jsonb_build_object('komisyon', a.komisyon, 'eve_satis_oran', a.eve_satis_oran, 'sergi_tavan', a.sergi_tavan,
      'baslangic_oran', a.baslangic_oran));
end $$;

create or replace function public.muzayede_lot(p_lot bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); l oyun.muzayede_lotlar; k oyun.muzayede_katalog; e oyun.muzayede_eserler;
begin
  select * into l from oyun.muzayede_lotlar where id = p_lot;
  if l.id is null then raise exception 'Lot bulunamadı.'; end if;
  if l.durum = 'acik' and l.bitis <= oyun.simdi() then perform oyun.mz_lot_kapat(l.id); end if;
  select * into e from oyun.muzayede_eserler where id = l.eser_id;
  select * into k from oyun.muzayede_katalog where kod = e.katalog;
  return oyun.mz_lot_ozet(l.id, p.id) || jsonb_build_object(
    'simdi', oyun.simdi(),
    'peyler', coalesce((select jsonb_agg(jsonb_build_object('kim', oyun.mz_kad(x.kim), 'benim', x.kim = p.id, 'tutar', x.tutar, 'zaman', x.zaman, 'durum', x.durum) order by x.zaman desc)
                          from (select * from oyun.muzayede_peyler pp where pp.lot_id = l.id order by pp.zaman desc limit 25) x), '[]'::jsonb),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('fiyat', s.fiyat, 'zaman', s.zaman, 'alici', oyun.mz_kad(s.alici)) order by s.zaman desc)
                          from (select * from oyun.muzayede_satislar s2 where s2.eser_id = e.id and s2.tur = 'artirma' order by s2.zaman desc limit 8) s), '[]'::jsonb),
    'endeks', coalesce((select jsonb_agg(g.endeks order by g.gun) from (select * from oyun.muzayede_endeks_gecmis g2 where g2.kategori = k.kategori order by g2.gun desc limit 30) g), '[]'::jsonb),
    'seri_eserler', coalesce((select jsonb_agg(jsonb_build_object('ad', kk.ad, 'nadirlik', kk.nadirlik, 'motif', kk.motif, 'renk', kk.renk,
          'bende', exists (select 1 from oyun.muzayede_eserler ee where ee.katalog = kk.kod and ee.sahip = p.id and ee.durum in ('kasa','sergide','artirmada'))) order by kk.taban)
        from oyun.muzayede_katalog kk where kk.seri = k.seri), '[]'::jsonb));
end $$;

-- Pey ver: tutar bloke edilir, geçilen eski lidere iade edilir; son 5 dakikada süre uzar
create or replace function public.muzayede_pey(p_lot bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); l oyun.muzayede_lotlar; k oyun.muzayede_katalog;
  v_min numeric; v_tutar numeric := round(coalesce(p_tutar, 0)); v_eski uuid; v_eski_tutar numeric; v_bitis timestamptz;
begin
  if not oyun.uzaktan_modul_acik('muzayede') then raise exception 'Müzayede evi şu an geçici olarak kapalı.'; end if;
  select * into l from oyun.muzayede_lotlar where id = p_lot for update;
  if l.id is null then raise exception 'Lot bulunamadı.'; end if;
  if l.durum <> 'acik' or l.bitis <= v_t then raise exception 'Bu açık artırma sona erdi.'; end if;
  if l.satici = p.id then raise exception 'Kendi eserine pey veremezsin.'; end if;
  if l.satici is not null and oyun.iliskili(l.satici, p.id) then perform oyun.iliskili_hata(); end if;
  select k2.* into k from oyun.muzayede_eserler e join oyun.muzayede_katalog k2 on k2.kod = e.katalog where e.id = l.eser_id;
  v_min := oyun.mz_min_pey(l.id);
  if v_tutar < v_min then raise exception 'Pey en az % ₺ olmalı.', oyun.tl(v_min); end if;
  if v_tutar > 100000000 then raise exception 'Pey tutarı çok yüksek.'; end if;
  v_eski := l.lider; v_eski_tutar := l.en_yuksek;
  if v_eski = p.id then
    -- Kendi peyini yükseltiyor: yalnız fark bloke edilir
    perform oyun.para_islem(p.id, -(v_tutar - v_eski_tutar), 'muzayede', format('Müzayede: “%s” peyini %s ₺''ye yükselttin (fark bloke edildi)', k.ad, oyun.tl(v_tutar)), v_t);
    update oyun.muzayede_peyler set durum = 'gecildi' where lot_id = l.id and kim = p.id and durum = 'lider';
  else
    perform oyun.para_islem(p.id, -v_tutar, 'muzayede', format('Müzayede: “%s” için %s ₺ pey (bloke)', k.ad, oyun.tl(v_tutar)), v_t);
    if v_eski is not null then
      perform oyun.para_islem(v_eski, v_eski_tutar, 'iade', format('Müzayede: “%s” peyin geçildi, %s ₺ iade edildi', k.ad, oyun.tl(v_eski_tutar)), v_t);
      update oyun.muzayede_peyler set durum = 'gecildi' where lot_id = l.id and kim = v_eski and durum = 'lider';
      perform oyun.bildir(v_eski, format('Müzayede: “%s” lotunda peyin geçildi! Yeni pey %s ₺. Bloke ettiğin %s ₺ cüzdanına döndü.', k.ad, oyun.tl(v_tutar), oyun.tl(v_eski_tutar)), v_t);
    end if;
  end if;
  insert into oyun.muzayede_peyler(lot_id, kim, tutar, zaman, durum) values (l.id, p.id, v_tutar, v_t, 'lider');
  v_bitis := l.bitis;
  if l.bitis - v_t < interval '5 minutes' then v_bitis := least(l.ilk_bitis + interval '2 hours', v_t + interval '5 minutes'); end if;
  update oyun.muzayede_lotlar set en_yuksek = v_tutar, lider = p.id, pey_sayisi = pey_sayisi + 1, bitis = greatest(bitis, v_bitis) where id = l.id;
  return public.muzayede_lot(l.id);
end $$;

-- Koleksiyonum
create or replace function public.muzayede_koleksiyonum()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.muzayede_ayar; v_bagis numeric;
begin
  select * into a from oyun.muzayede_ayar where id = 1;
  select coalesce(sum(bagis_kidem), 0) into v_bagis from oyun.muzayede_eserler where bagisci = p.id;
  return jsonb_build_object(
    'simdi', oyun.simdi(),
    'eserler', coalesce((select jsonb_agg(oyun.mz_eser_ozet(e.id, p.id) || jsonb_build_object(
          'lot', (select l.id from oyun.muzayede_lotlar l where l.eser_id = e.id and l.durum = 'acik'),
          'sergi_gunluk', case when e.durum = 'sergide' then round(oyun.mz_deger(e.id) * oyun.mz_sergi_oran(k.nadirlik)) end,
          'sergi_bas', e.sergi_bas,
          'eve_satis', oyun.mz_yuvarla(oyun.mz_deger(e.id) * a.eve_satis_oran),
          'eve_satis_acilis', e.alis_zaman + interval '72 hours',
          'bagis_kidem', least(5, floor(oyun.mz_deger(e.id) / 20000)))
        order by oyun.mz_deger(e.id) desc)
        from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog
       where e.sahip = p.id and e.durum in ('kasa','sergide','artirmada')), '[]'::jsonb),
    'seriler', coalesce((select jsonb_agg(jsonb_build_object('seri', s.seri, 'toplam', s.toplam, 'bende', s.bende, 'tam', s.bende = s.toplam) order by s.bende desc, s.seri)
        from (select k.seri, count(distinct k.kod) toplam,
                     count(distinct k.kod) filter (where exists (select 1 from oyun.muzayede_eserler e where e.katalog = k.kod and e.sahip = p.id and e.durum in ('kasa','sergide','artirmada'))) bende
                from oyun.muzayede_katalog k group by k.seri) s where s.bende > 0), '[]'::jsonb),
    'peylerim', coalesce((select jsonb_agg(oyun.mz_lot_ozet(l.id, p.id) order by l.bitis)
        from oyun.muzayede_lotlar l where l.durum = 'acik' and exists (select 1 from oyun.muzayede_peyler pp where pp.lot_id = l.id and pp.kim = p.id)), '[]'::jsonb),
    'satistakiler', coalesce((select jsonb_agg(oyun.mz_lot_ozet(l.id, p.id) order by l.bitis) from oyun.muzayede_lotlar l where l.durum = 'acik' and l.satici = p.id), '[]'::jsonb),
    'sergi_bugun', (select tutar from oyun.muzayede_sergi_odeme where user_id = p.id and gun = (oyun.simdi() at time zone 'Europe/Istanbul')::date),
    'sergi_tavan', a.sergi_tavan, 'komisyon', a.komisyon, 'bagis_kidem', v_bagis, 'bagis_kidem_tavan', 20,
    'toplam_deger', coalesce((select sum(oyun.mz_deger(e.id)) from oyun.muzayede_eserler e where e.sahip = p.id and e.durum in ('kasa','sergide','artirmada')), 0),
    'toplam_maliyet', coalesce((select sum(e.alis_bedeli) from oyun.muzayede_eserler e where e.sahip = p.id and e.durum in ('kasa','sergide','artirmada')), 0));
end $$;

-- Eserini açık artırmaya çıkar
create or replace function public.muzayede_lot_ac(p_eser bigint, p_baslangic numeric, p_saat integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); e oyun.muzayede_eserler; k oyun.muzayede_katalog;
  v_bas numeric := round(coalesce(p_baslangic, 0)); v_ucret numeric; v_id bigint;
begin
  if not oyun.uzaktan_modul_acik('muzayede') then raise exception 'Müzayede evi şu an geçici olarak kapalı.'; end if;
  if p_saat not in (6, 12, 24, 48) then raise exception 'Süre 6, 12, 24 ya da 48 saat olabilir.'; end if;
  select * into e from oyun.muzayede_eserler where id = p_eser for update;
  if e.id is null or e.sahip is distinct from p.id then raise exception 'Bu eser senin değil.'; end if;
  if e.durum not in ('kasa','sergide') then raise exception 'Bu eser şu an açık artırmaya çıkarılamaz.'; end if;
  if (select count(*) from oyun.muzayede_lotlar l where l.satici = p.id and l.durum = 'acik') >= 3 then
    raise exception 'Aynı anda en fazla 3 eserini açık artırmaya çıkarabilirsin.'; end if;
  if v_bas < 500 then raise exception 'Başlangıç fiyatı en az 500 ₺ olmalı.'; end if;
  if v_bas > oyun.mz_deger(e.id) * 5 then raise exception 'Başlangıç fiyatı tahmini değerin 5 katını geçemez.'; end if;
  select * into k from oyun.muzayede_katalog where kod = e.katalog;
  v_ucret := greatest(250, least(5000, round(v_bas * 0.01)));
  perform oyun.para_islem(p.id, -v_ucret, 'muzayede', format('Müzayede: “%s” için lot açma ücreti', k.ad), v_t);
  update oyun.ulke set hazine = hazine + v_ucret / oyun.pazar_tl_milyar() where id = 1;
  update oyun.muzayede_eserler set durum = 'artirmada', sergi_bas = null where id = e.id;
  insert into oyun.muzayede_lotlar(eser_id, satici, baslangic, bitis, ilk_bitis, ucret)
    values (e.id, p.id, v_bas, date_trunc('minute', v_t + make_interval(hours => p_saat)), date_trunc('minute', v_t + make_interval(hours => p_saat)), v_ucret)
    returning id into v_id;
  return public.muzayede_lot(v_id);
end $$;

-- Pey gelmemiş lotunu geri çek
create or replace function public.muzayede_lot_iptal(p_lot bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); l oyun.muzayede_lotlar;
begin
  select * into l from oyun.muzayede_lotlar where id = p_lot for update;
  if l.id is null or l.satici is distinct from p.id then raise exception 'Bu lot senin değil.'; end if;
  if l.durum <> 'acik' then raise exception 'Bu açık artırma zaten kapandı.'; end if;
  if l.pey_sayisi > 0 then raise exception 'Pey gelmiş bir açık artırma geri çekilemez.'; end if;
  update oyun.muzayede_lotlar set durum = 'iptal', kapanis = oyun.simdi() where id = l.id;
  update oyun.muzayede_eserler set durum = 'kasa' where id = l.eser_id and sahip = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- Özel müzede sergile / sergiden kaldır
create or replace function public.muzayede_sergi(p_eser bigint, p_ac boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); e oyun.muzayede_eserler;
begin
  select * into e from oyun.muzayede_eserler where id = p_eser for update;
  if e.id is null or e.sahip is distinct from p.id then raise exception 'Bu eser senin değil.'; end if;
  if p_ac then
    if e.durum <> 'kasa' then raise exception 'Yalnız kasandaki eserler sergilenebilir.'; end if;
    update oyun.muzayede_eserler set durum = 'sergide', sergi_bas = oyun.simdi() where id = e.id;
  else
    if e.durum <> 'sergide' then raise exception 'Bu eser sergide değil.'; end if;
    update oyun.muzayede_eserler set durum = 'kasa', sergi_bas = null where id = e.id;
  end if;
  return oyun.mz_eser_ozet(e.id, p.id);
end $$;

-- Müzayede evine hızlı satış (tahmini değerin %50'si, alımdan 72 saat sonra)
create or replace function public.muzayede_eve_sat(p_eser bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); e oyun.muzayede_eserler; k oyun.muzayede_katalog;
  a oyun.muzayede_ayar; v_bedel numeric; v_model numeric;
begin
  if not oyun.uzaktan_modul_acik('muzayede') then raise exception 'Müzayede evi şu an geçici olarak kapalı.'; end if;
  select * into a from oyun.muzayede_ayar where id = 1;
  select * into e from oyun.muzayede_eserler where id = p_eser for update;
  if e.id is null or e.sahip is distinct from p.id then raise exception 'Bu eser senin değil.'; end if;
  if e.durum not in ('kasa','sergide') then raise exception 'Bu eser şu an satılamaz.'; end if;
  if e.alis_zaman is not null and e.alis_zaman > v_t - interval '72 hours' then
    raise exception 'Müzayede evi bir eseri satın alındıktan 72 saat sonra geri alır (%).', oyun.ilan_tarih(e.alis_zaman + interval '72 hours'); end if;
  select * into k from oyun.muzayede_katalog where kod = e.katalog;
  v_bedel := oyun.mz_yuvarla(oyun.mz_deger(e.id) * a.eve_satis_oran);
  v_model := oyun.mz_model(e.id);
  perform oyun.para_islem(p.id, v_bedel, 'muzayede', format('Müzayede: “%s” müzayede evine satıldı', k.ad), v_t);
  update oyun.ulke set hazine = hazine - v_bedel / oyun.pazar_tl_milyar() where id = 1;
  update oyun.muzayede_eserler set sahip = null, durum = 'havuz', sergi_bas = null, alis_bedeli = null, alis_zaman = null where id = e.id;
  insert into oyun.muzayede_satislar(eser_id, kategori, satici, alici, fiyat, model_deger, tur, zaman)
    values (e.id, k.kategori, p.id, null, v_bedel, v_model, 'eve_satis', v_t);
  return jsonb_build_object('tamam', true, 'bedel', v_bedel);
end $$;

-- Devlet Müzesi'ne bağışla: eser kalıcı olarak müzeye geçer, kıdem puanı kazanılır
create or replace function public.muzayede_bagis(p_eser bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); e oyun.muzayede_eserler; k oyun.muzayede_katalog;
  v_onceki numeric; v_kidem numeric;
begin
  select * into e from oyun.muzayede_eserler where id = p_eser for update;
  if e.id is null or e.sahip is distinct from p.id then raise exception 'Bu eser senin değil.'; end if;
  if e.durum not in ('kasa','sergide') then raise exception 'Bu eser şu an bağışlanamaz.'; end if;
  if e.alis_zaman is not null and e.alis_zaman > v_t - interval '24 hours' then raise exception 'Yeni aldığın eseri en erken 24 saat sonra bağışlayabilirsin.'; end if;
  select * into k from oyun.muzayede_katalog where kod = e.katalog;
  select coalesce(sum(bagis_kidem), 0) into v_onceki from oyun.muzayede_eserler where bagisci = p.id;
  v_kidem := greatest(0, least(5, floor(oyun.mz_deger(e.id) / 20000), 20 - v_onceki));
  update oyun.muzayede_eserler set sahip = null, durum = 'muzede', sergi_bas = null, bagisci = p.id, bagis_zaman = v_t, bagis_kidem = v_kidem where id = e.id;
  if v_kidem > 0 then
    perform oyun.cuzdanim(p.id);
    update oyun.cuzdan set kidem = coalesce(kidem, 0) + v_kidem where user_id = p.id;
  end if;
  perform oyun.bildir(p.id, format('Müzayede: “%s” Devlet Müzesi''ne bağışlandı. Adın müzede bağışçı olarak yazılı%s.', k.ad,
    case when v_kidem > 0 then format('; +%s kıdem puanı kazandın', v_kidem) else '' end), v_t);
  return jsonb_build_object('tamam', true, 'kidem', v_kidem);
end $$;

-- Koleksiyoncular sıralaması ve Devlet Müzesi
create or replace function public.muzayede_siralama()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  return jsonb_build_object(
    'koleksiyoncular', coalesce((select jsonb_agg(x order by (x->>'deger')::numeric desc) from (
        select jsonb_build_object('kad', pr.kad, 'benim', pr.id = p.id, 'parti', (select jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = pr.parti_id),
               'eser', count(*), 'deger', sum(oyun.mz_deger(e.id)),
               'efsanevi', count(*) filter (where k.nadirlik = 'efsanevi'),
               'tam_set', (select count(distinct k2.seri) from oyun.muzayede_katalog k2 where oyun.mz_set_tam(pr.id, k2.seri))) x
          from oyun.muzayede_eserler e join oyun.muzayede_katalog k on k.kod = e.katalog join oyun.profiller pr on pr.id = e.sahip
         where e.durum in ('kasa','sergide','artirmada') and not pr.yasakli
         group by pr.id, pr.kad, pr.parti_id order by sum(oyun.mz_deger(e.id)) desc limit 20) t), '[]'::jsonb),
    'muze', coalesce((select jsonb_agg(oyun.mz_eser_ozet(e.id, p.id) order by e.bagis_zaman desc)
        from oyun.muzayede_eserler e where e.durum = 'muzede'), '[]'::jsonb),
    'rekorlar', coalesce((select jsonb_agg(x order by (x->>'fiyat')::numeric desc) from (
        select jsonb_build_object('eser', k.ad, 'nadirlik', k.nadirlik, 'motif', k.motif, 'renk', k.renk, 'fiyat', s.fiyat, 'alici', oyun.mz_kad(s.alici), 'zaman', s.zaman) x
          from oyun.muzayede_satislar s join oyun.muzayede_eserler e on e.id = s.eser_id join oyun.muzayede_katalog k on k.kod = e.katalog
         where s.tur = 'artirma' order by s.fiyat desc limit 10) t), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- F. ZAMANLAYICI VE YETKİLER
-- ---------------------------------------------------------------------
do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'muzayede-bakim') then perform cron.unschedule('muzayede-bakim'); end if;
    perform cron.schedule('muzayede-bakim', '* * * * *', 'select oyun.muzayede_bakim()');
  end if;
end $cron$;

do $yetki$
declare f text;
begin
  foreach f in array array[
    'public.muzayede_salon()', 'public.muzayede_lot(bigint)', 'public.muzayede_pey(bigint,numeric)',
    'public.muzayede_koleksiyonum()', 'public.muzayede_lot_ac(bigint,numeric,integer)', 'public.muzayede_lot_iptal(bigint)',
    'public.muzayede_sergi(bigint,boolean)', 'public.muzayede_eve_sat(bigint)', 'public.muzayede_bagis(bigint)',
    'public.muzayede_siralama()']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array[
    'oyun.mz_eser_bas(text)', 'oyun.mz_sistem_lot_ac(integer)', 'oyun.mz_lot_kapat(bigint)', 'oyun.mz_gunluk()', 'oyun.muzayede_bakim()']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $yetki$;

-- Başlangıç: endeks geçmişi bugünle başlar (ilk günlük güncelleme yarın), salon 6 lotla açılır
update oyun.muzayede_ayar set son_gunluk = coalesce(son_gunluk, (now() at time zone 'Europe/Istanbul')::date), sergi_tavan = 2000 where id = 1;
insert into oyun.muzayede_endeks_gecmis(kategori, gun, endeks)
  select kod, (now() at time zone 'Europe/Istanbul')::date, endeks from oyun.muzayede_kategori on conflict do nothing;
select oyun.mz_sistem_lot_ac();
