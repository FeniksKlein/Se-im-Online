-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 171) SÜPER YÖNETİCİ PORTALI · AŞAMA 3
--  Canlı ayarlar: açıklamalı ayar kataloğu, ön izlemeli değişiklik, geçmiş, geri alma,
--  ileri tarihli ve süreli (otomatik geri dönen) değişiklikler (07.11.2026)
--
--  • Yalnız katalogdaki ayarlar değiştirilebilir (tablo/sütun katalogdan gelir; serbest SQL yok).
--  • Her ayarın türü, alt/üst sınırı ve risk düzeyi vardır; sınırlar oyundaki CHECK kısıtlarının
--    ve eski yönetici panelindeki sınırların içindedir.
--  • Yüksek riskli bir ayar değişikliği ikinci onay (ONAYLIYORUM) ister.
--  • Her yazım oyun.yp_ayar_gecmis tablosuna önceki/yeni değerle kaydedilir.
--  • İleri tarihli / süreli değişiklikler oyun.yp_ayar_plan'a yazılır, dakikada bir çalışan
--    "yp-ayar-plan" zamanlayıcısı uygular. Süre bitince ayar eski değerine döner (arada başka biri
--    değiştirdiyse dokunulmaz).
--  • Değişiklikten sonra canlı sinyal yayılır; telefonlar 0–8 sn içinde ayarları yeniden okur.
--
--  Oyuncu verisini silmez veya sıfırlamaz.
-- =====================================================================

create table if not exists oyun.yp_ayar_katalog (
  anahtar  text primary key,
  tablo    text not null,
  sutun    text not null,
  satir    jsonb,                       -- çok satırlı tablolarda satır seçimi, ör. {"anahtar":"bakim"}
  grup     text not null,
  baslik   text not null,
  aciklama text not null,
  tur      text not null check (tur in ('tamsayi', 'sayi', 'para', 'yuzde', 'evet_hayir', 'metin')),
  birim    text,
  en_az    numeric,
  en_cok   numeric,
  en_uzun  int,
  risk     text not null default 'dusuk' check (risk in ('dusuk', 'orta', 'yuksek')),
  etki     text not null default 'Hemen: oyuncunun bir sonraki işleminde geçerli.',
  sira     int not null default 100,
  aktif    boolean not null default true
);
alter table oyun.yp_ayar_katalog enable row level security;

create table if not exists oyun.yp_ayar_gecmis (
  id       bigint generated always as identity primary key,
  anahtar  text not null,
  zaman    timestamptz not null default now(),
  eski     jsonb,
  yeni     jsonb,
  kaynak   text not null check (kaynak in ('portal', 'plan', 'plan_bitis', 'geri_al')),
  islem_id bigint,
  plan_id  bigint,
  user_id  uuid,
  kad      text,
  neden    text
);
create index if not exists yp_ayar_gecmis_anahtar on oyun.yp_ayar_gecmis (anahtar, id desc);
create index if not exists yp_ayar_gecmis_islem on oyun.yp_ayar_gecmis (islem_id);
alter table oyun.yp_ayar_gecmis enable row level security;

create table if not exists oyun.yp_ayar_plan (
  id            bigint generated always as identity primary key,
  islem_id      bigint not null,
  zaman         timestamptz not null,
  tur           text not null check (tur in ('uygula', 'geri_don')),
  degisiklikler jsonb not null,          -- [{anahtar, deger, beklenen?}]
  durum         text not null default 'bekliyor' check (durum in ('bekliyor', 'uygulandi', 'iptal', 'basarisiz')),
  olusturma     timestamptz not null default now(),
  uygulama      timestamptz,
  sonuc         jsonb,
  hata          text
);
create index if not exists yp_ayar_plan_bekleyen on oyun.yp_ayar_plan (zaman) where durum = 'bekliyor';
create index if not exists yp_ayar_plan_islem on oyun.yp_ayar_plan (islem_id);
alter table oyun.yp_ayar_plan enable row level security;

insert into oyun.yp_katalog (islem, baslik, aciklama, grup, kritik, geri_alinabilir, onay_metni) values
  ('ayar_degistir', 'Canlı ayar değiştir', 'Katalogdaki oyun ayarlarını hemen, ileri bir tarihte ya da belirli bir süre için değiştirir. Yüksek riskli ayarlar ikinci onay ister.', 'ayar', false, true, 'ONAYLIYORUM')
on conflict (islem) do update set baslik = excluded.baslik, aciklama = excluded.aciklama, grup = excluded.grup,
  kritik = excluded.kritik, geri_alinabilir = excluded.geri_alinabilir, onay_metni = excluded.onay_metni;

-- ---------------------------------------------------------------------
-- 1) Katalog
-- ---------------------------------------------------------------------
insert into oyun.yp_ayar_katalog (anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, sira) values
-- Genel ve bakım
  ('uygulama.bakim', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"bakim"}', 'genel', 'Bakım modu',
   'Açıkken yalnız yönetici oyuna girebilir; oyuncular bakım ekranını görür. Bakım bitince kapatmayı unutma.', 'evet_hayir', null, null, null, null, 'yuksek',
   'Telefonlarda 0–8 saniye içinde.', 10),
  ('uygulama.bakim_mesaj', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"bakim_mesaj"}', 'genel', 'Bakım ekranı mesajı',
   'Bakım ekranında oyunculara gösterilen açıklama.', 'metin', null, null, null, 300, 'dusuk', 'Telefonlarda 0–8 saniye içinde.', 11),
  ('uygulama.duyuru_bandi', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"duyuru_bandi"}', 'genel', 'Duyuru bandı',
   'Uygulamanın üstünde herkese görünen kısa duyuru. Boş bırakılırsa bant görünmez.', 'metin', null, null, null, 200, 'dusuk', 'Telefonlarda 0–8 saniye içinde.', 12),
  ('uygulama.iletisim', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"iletisim"}', 'genel', 'Destek e-postası',
   'Oyuncuların ulaşacağı destek e-posta adresi.', 'metin', null, null, null, 120, 'dusuk', 'Telefonlarda 0–8 saniye içinde.', 13),
  ('uygulama.reklam_acik', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"reklam_acik"}', 'genel', 'Ödüllü reklam düğmesi',
   'Kapalıyken oyuncular ödüllü reklam izleyemez.', 'evet_hayir', null, null, null, null, 'orta', 'Telefonlarda 0–8 saniye içinde.', 14),
  ('uygulama.satis_acik', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"satis_acik"}', 'genel', '₺ paketi satışı',
   'Kapalıyken uygulama içi ₺ paketi satışı durur.', 'evet_hayir', null, null, null, null, 'orta', 'Telefonlarda 0–8 saniye içinde.', 15),
  ('uygulama.kart_gunluk', 'oyun.uygulama_ayar', 'deger', '{"anahtar":"kart_gunluk"}', 'genel', 'Siyaset Kartı günlük ödülü',
   'Siyaset Kartı sahiplerine verilen günlük ödül.', 'para', '₺', 0, 100000, null, 'orta', 'Bir sonraki günlük ödülde.', 16),
  ('modul.sirket_pazari', 'oyun.uzaktan_modul_ayar', 'acik', '{"kod":"sirket_pazari"}', 'genel', 'Şirket alım-satım pazarı',
   'Yeni şirket ilanları ve oyuncular arasındaki normal şirket devri. Kapatılırsa düğmeler pasifleşir.', 'evet_hayir', null, null, null, null, 'orta', 'Telefonlarda 0–8 saniye içinde.', 20),
  ('modul.npc_isletme', 'oyun.uzaktan_modul_ayar', 'acik', '{"kod":"npc_isletme"}', 'genel', 'NPC stoklu işletmeler',
   'Akaryakıt istasyonu, mağaza ve galeri stok işlemleri ile otomatik NPC satışları.', 'evet_hayir', null, null, null, null, 'orta', 'Telefonlarda 0–8 saniye içinde.', 21),
-- Hesap ve güvenlik
  ('ayarlar.coklu_kontrol', 'oyun.ayarlar', 'coklu_kontrol', null, 'hesap', 'Çoklu hesap denetimi',
   'Aynı cihazda açılmış hesaplar arasında oy, para transferi ve kayıt denetimleri. Kapatmak hile riskini artırır.', 'evet_hayir', null, null, null, null, 'yuksek', default, 10),
  ('ayarlar.cihaz_max_hesap', 'oyun.ayarlar', 'cihaz_max_hesap', null, 'hesap', 'Cihaz başına en fazla hesap',
   'Bir cihazda açılabilecek en fazla oyuncu hesabı.', 'tamsayi', 'hesap', 1, 5, null, 'orta', 'Yeni kayıtlarda.', 11),
  ('ayarlar.eposta_zorunlu', 'oyun.ayarlar', 'eposta_zorunlu', null, 'hesap', 'Doğrulanmış e-posta şartı',
   'Seçmen kartı (oy, adaylık, para gönderme) için doğrulanmış e-posta şartı.', 'evet_hayir', null, null, null, null, 'orta', default, 12),
  ('ayarlar.cihaz_zorunlu', 'oyun.ayarlar', 'cihaz_zorunlu', null, 'hesap', 'Doğrulanmış cihaz şartı',
   'Seçmen kartı için oyuncunun en az bir cihaz oturumu olması şartı.', 'evet_hayir', null, null, null, null, 'orta', default, 13),
  ('ayarlar.min_hesap_gun', 'oyun.ayarlar', 'min_hesap_gun', null, 'hesap', 'En az hesap yaşı',
   'Oy kullanmak ve aday olmak için hesabın en az kaç günlük olması gerektiği.', 'tamsayi', 'gün', 0, 30, null, 'orta', default, 14),
  ('ayarlar.oy_min_kidem', 'oyun.ayarlar', 'oy_min_kidem', null, 'hesap', 'Oy için en az kıdem',
   'Seçmen kartı için gereken en az kıdem puanı.', 'tamsayi', 'puan', 0, 100, null, 'orta', default, 15),
  ('ayarlar.oy_il_gun', 'oyun.ayarlar', 'oy_il_gun', null, 'hesap', 'Seçmen kütüğü süresi',
   'Milletvekili, belediye ve ön seçimlerde oy kullanmak için o ilde en az kaç gün kayıtlı olmak gerektiği (0: şart yok).', 'tamsayi', 'gün', 0, 30, null, 'orta', default, 16),
  ('ayarlar.il_degis_gun', 'oyun.ayarlar', 'il_degis_gun', null, 'hesap', 'İl değiştirme aralığı',
   'Bir oyuncunun iki il değişikliği arasında beklemesi gereken en az gün.', 'tamsayi', 'gün', 0, 90, null, 'dusuk', default, 17),
  ('ayarlar.havale_sinir', 'oyun.ayarlar', 'havale_sinir', null, 'hesap', 'Günlük para gönderme sınırı',
   'Bir oyuncunun günde gönderebileceği para; aylık asgari ücretin katı olarak.', 'sayi', '× asgari ücret', 0, 50, null, 'orta', default, 18),
-- Ekonomi
  ('ayarlar.maas_hizi', 'oyun.ayarlar', 'maas_hizi', null, 'ekonomi', 'Gelir toplama hızı',
   'Oyuncuların saatlik maaş/gelir birikiminin çarpanı. Artırmak para arzını hızla büyütür.', 'sayi', '×', 0, 20, null, 'yuksek', 'Bir sonraki gelir toplamada.', 10),
  ('ayarlar.baslangic_para', 'oyun.ayarlar', 'baslangic_para', null, 'ekonomi', 'Başlangıç parası',
   'Yeni açılan hesaplara verilen başlangıç parası (mevcut oyuncular etkilenmez).', 'para', '₺', 0, 10000000, null, 'orta', 'Yeni hesaplarda.', 11),
  ('ayarlar.banka_acik', 'oyun.ayarlar', 'banka_acik', null, 'ekonomi', 'Devlet Bankası açık',
   'Kapalıyken Devlet Bankası işlemleri (vadeli hesap vb.) yapılamaz.', 'evet_hayir', null, null, null, null, 'yuksek', default, 12),
  ('ayarlar.banka_reel_faiz', 'oyun.ayarlar', 'banka_reel_faiz', null, 'ekonomi', 'Banka reel faizi',
   'Devlet Bankası mevduatına uygulanan reel faiz.', 'sayi', '%', -10, 30, null, 'orta', 'Yeni açılan vadeli hesaplarda.', 13),
  ('ayarlar.banka_tavan', 'oyun.ayarlar', 'banka_tavan', null, 'ekonomi', 'Banka mevduat tavanı',
   'Bir oyuncunun Devlet Bankası mevduat üst sınırı (fiyat endeksiyle çarpılır).', 'para', '₺', 0, 100000000, null, 'orta', default, 14),
  ('ayarlar.mentor_odul', 'oyun.ayarlar', 'mentor_odul', null, 'ekonomi', 'Mentorluk ödülü',
   'Mentorluk görevi tamamlandığında verilen ödül.', 'para', '₺', 0, 1000000, null, 'dusuk', default, 15),
  ('ayarlar.stant_bedel', 'oyun.ayarlar', 'stant_bedel', null, 'ekonomi', 'Seçim standı bedeli',
   'Seçim standı kurma bedeli.', 'para', '₺', 0, 1000000, null, 'dusuk', default, 16),
  ('guvenlik.masak', 'oyun.guvenlik_ayar', 'masak', null, 'ekonomi', 'MASAK denetimi',
   'Olağan dışı servet artışında yönetime bildirim gönderen denetim.', 'evet_hayir', null, null, null, null, 'orta', default, 17),
  ('guvenlik.masak_servet_esik', 'oyun.guvenlik_ayar', 'masak_servet_esik', null, 'ekonomi', 'MASAK bildirim eşiği',
   '24 saatte bu kadar gelir elde eden oyuncu için bildirim oluşur (fiyat düzeyiyle).', 'para', '₺', 10000, 1000000000, null, 'dusuk', default, 18),
  ('guvenlik.fiyat_bandi', 'oyun.guvenlik_ayar', 'fiyat_bandi', null, 'ekonomi', 'Fiyat bandı koruması',
   'Oyuncular arası satışlarda aşırı düşük/yüksek fiyatı engelleyen bant.', 'evet_hayir', null, null, null, null, 'orta', default, 19),
-- Siyaset ve seçim
  ('mv_modu.her_aday_vekil', 'oyun.mv_secim_modu', 'her_aday_vekil', null, 'siyaset', 'MV seçimi test modu',
   'Açıkken milletvekili seçiminde bütün kesinleşmiş adaylar vekil olur ve baraj uygulanmaz. Kapalıyken normal kurallar (baraj) işler.', 'evet_hayir', null, null, null, null, 'yuksek',
   'Bir sonraki sonuçlandırmada.', 10),
  ('ayarlar.baraj', 'oyun.ayarlar', 'baraj', null, 'siyaset', 'Seçim barajı',
   'Milletvekili seçiminde ulusal baraj (test modu kapalıyken geçerli).', 'yuzde', '%', 0, 20, null, 'yuksek', 'Bir sonraki sonuçlandırmada.', 11),
  ('secim_gecesi.sure_sn', 'oyun.secim_gecesi_ayar', 'sure_sn', null, 'siyaset', 'Seçim gecesi süresi',
   'Canlı seçim gecesi sayım gösteriminin uzunluğu.', 'tamsayi', 'saniye', 60, 1800, null, 'dusuk', 'Bir sonraki seçim gecesinde.', 12),
  ('secim_gecesi.canli_sayim', 'oyun.secim_gecesi_ayar', 'canli_sayim', null, 'siyaset', 'Canlı sayım',
   'Açıkken sandık kapandıktan sonra sonuçlar canlı sayım olarak açılır.', 'evet_hayir', null, null, null, null, 'dusuk', 'Bir sonraki seçim gecesinde.', 13),
  ('ayarlar.parti_kur_ucret', 'oyun.ayarlar', 'parti_kur_ucret', null, 'siyaset', 'Parti kuruluş ücreti',
   'Yeni parti kurmanın bedeli.', 'para', '₺', 0, 1000000, null, 'dusuk', default, 14),
  ('ayarlar.parti_kur_gun', 'oyun.ayarlar', 'parti_kur_gun', null, 'siyaset', 'Parti kurma aralığı',
   'Bir oyuncunun iki parti kuruluşu arasında beklemesi gereken en az gün.', 'tamsayi', 'gün', 0, 365, null, 'dusuk', default, 15),
  ('ayarlar.parti_kurucu_sayi', 'oyun.ayarlar', 'parti_kurucu_sayi', null, 'siyaset', 'Gerekli kurucu sayısı',
   'Kuruluş aşamasındaki partinin kesinleşmesi için gereken kurucu üye sayısı.', 'tamsayi', 'kişi', 1, 30, null, 'dusuk', default, 16),
  ('ayarlar.parti_kurucu_kidem', 'oyun.ayarlar', 'parti_kurucu_kidem', null, 'siyaset', 'Parti kurmak için kıdem',
   'Parti kurmak için gereken en az kıdem puanı.', 'tamsayi', 'puan', 0, 300, null, 'dusuk', default, 17),
  ('ayarlar.parti_kurulus_gun', 'oyun.ayarlar', 'parti_kurulus_gun', null, 'siyaset', 'Kuruluş süresi',
   'Yeni partinin kurucularını toplamak için verilen süre.', 'tamsayi', 'gün', 1, 30, null, 'dusuk', 'Yeni kurulan partilerde.', 18),
  ('ayarlar.teskilat_ucret', 'oyun.ayarlar', 'teskilat_ucret', null, 'siyaset', 'İl teşkilatı ücreti',
   'Partinin bir ilde teşkilat açma bedeli.', 'para', '₺', 0, 100000, null, 'dusuk', default, 19),
  ('ayarlar.teskilat_zorunlu', 'oyun.ayarlar', 'teskilat_zorunlu', null, 'siyaset', 'Aday için teşkilat şartı',
   'Açıkken parti, teşkilatı olmayan ilde aday gösteremez.', 'evet_hayir', null, null, null, null, 'orta', default, 20),
  ('ayarlar.meclis_olcek', 'oyun.ayarlar', 'meclis_olcek', null, 'siyaset', 'Meclis büyüklüğü ölçeği',
   'Aktif oyuncu başına meclis sandalyesi (0: ölçek kapalı, il kontenjanları geçerli).', 'sayi', 'sandalye/oyuncu', 0, 5, null, 'yuksek', 'Bir sonraki seçim takviminde.', 21),
  ('ayarlar.ihmal_gun_atama', 'oyun.ayarlar', 'ihmal_gun_atama', null, 'siyaset', 'İhmal uyarısı (atanmış görev)',
   'Bakan veya CB yardımcısı bu kadar gün oyuna girmezse bağlı olduğu kişilere bir kez bildirim gider (0: kapalı). Görevden alma yapılmaz.', 'tamsayi', 'gün', 0, 30, null, 'dusuk', default, 22),
  ('ayarlar.ihmal_gun_secim', 'oyun.ayarlar', 'ihmal_gun_secim', null, 'siyaset', 'İhmal uyarısı (seçilmiş görev)',
   'CB, genel başkan veya belediye başkanı bu kadar gün oyuna girmezse ilgililere bir kez bildirim gider (0: kapalı).', 'tamsayi', 'gün', 0, 30, null, 'dusuk', default, 23),
-- Olaylar ve krizler
  ('kriz.aktif', 'oyun.kriz_ayar', 'aktif', null, 'olay', 'Ülke krizleri',
   'Haftalık çekilişle rastgele ülke krizi çıkar.', 'evet_hayir', null, null, null, null, 'orta', 'Bir sonraki haftalık çekilişte.', 10),
  ('kriz.haftalik_ihtimal', 'oyun.kriz_ayar', 'haftalik_ihtimal', null, 'olay', 'Ülke krizi olasılığı',
   'Haftalık çekilişte kriz çıkma olasılığı.', 'tamsayi', '%', 0, 50, null, 'dusuk', 'Bir sonraki haftalık çekilişte.', 11),
  ('kriz.min_aralik_gun', 'oyun.kriz_ayar', 'min_aralik_gun', null, 'olay', 'İki ülke krizi arası',
   'İki ülke krizi arasında en az geçmesi gereken gün.', 'tamsayi', 'gün', 14, 90, null, 'dusuk', default, 12),
  ('uk.aktif', 'oyun.uk_ayar', 'aktif', null, 'olay', 'Ulusal krizler',
   'Bakanlıkların ve yürütmenin müdahale etmesi gereken ulusal krizler.', 'evet_hayir', null, null, null, null, 'orta', default, 13),
  ('uk.haftalik_ihtimal', 'oyun.uk_ayar', 'haftalik_ihtimal', null, 'olay', 'Ulusal kriz olasılığı',
   'Çekilişte ulusal kriz çıkma olasılığı.', 'tamsayi', '%', 0, 100, null, 'dusuk', default, 14),
  ('uk.min_aralik_gun', 'oyun.uk_ayar', 'min_aralik_gun', null, 'olay', 'İki ulusal kriz arası',
   'İki ulusal kriz arasında en az geçmesi gereken gün.', 'tamsayi', 'gün', 3, 90, null, 'dusuk', default, 15),
  ('sokak.aktif', 'oyun.sokak_eylem_ayar', 'aktif', null, 'olay', 'Halk hareketleri',
   'Oyuncuların sokak eylemi başlatabilmesi.', 'evet_hayir', null, null, null, null, 'orta', default, 16),
  ('sokak.baslatma_bedeli', 'oyun.sokak_eylem_ayar', 'baslatma_bedeli', null, 'olay', 'Eylem başlatma bedeli',
   'Sokak eylemi başlatmanın bedeli.', 'para', '₺', 1, 10000000, null, 'dusuk', default, 17),
  ('sokak.il_cooldown_saat', 'oyun.sokak_eylem_ayar', 'il_cooldown_saat', null, 'olay', 'Aynı ilde eylem aralığı',
   'Aynı ilde iki eylem arasında beklenecek süre.', 'tamsayi', 'saat', 24, 720, null, 'dusuk', default, 18),
  ('sokak.parti_cooldown_saat', 'oyun.sokak_eylem_ayar', 'parti_cooldown_saat', null, 'olay', 'Parti eylem aralığı',
   'Bir partinin iki eylemi arasında beklenecek süre.', 'tamsayi', 'saat', 24, 720, null, 'dusuk', default, 19),
  ('sokak.max_sure_saat', 'oyun.sokak_eylem_ayar', 'max_sure_saat', null, 'olay', 'En uzun eylem süresi',
   'Bir eylemin sürebileceği en uzun süre.', 'tamsayi', 'saat', 24, 168, null, 'dusuk', default, 20),
  ('sokak.ulke_es_zamanli_ust_sinir', 'oyun.sokak_eylem_ayar', 'ulke_es_zamanli_ust_sinir', null, 'olay', 'Ülkede aynı anda eylem',
   'Ülke genelinde aynı anda sürebilecek en fazla eylem.', 'tamsayi', 'eylem', 1, 81, null, 'dusuk', default, 21),
  ('sokak.il_es_zamanli_ust_sinir', 'oyun.sokak_eylem_ayar', 'il_es_zamanli_ust_sinir', null, 'olay', 'Bir ilde aynı anda eylem',
   'Bir ilde aynı anda sürebilecek en fazla eylem.', 'tamsayi', 'eylem', 1, 10, null, 'dusuk', default, 22),
-- Davet ve yargı
  ('davet.aktif', 'oyun.davet_ayar', 'aktif', null, 'diger', 'Davet sistemi',
   'Davet koduyla arkadaş getirme ve ödüller.', 'evet_hayir', null, null, null, null, 'dusuk', default, 10),
  ('davet.odul_eden', 'oyun.davet_ayar', 'odul_eden', null, 'diger', 'Davet eden ödülü',
   'Davet ettiği oyuncu şartları tamamlayınca davet edene verilen ödül.', 'para', '₺', 0, 1000000, null, 'dusuk', default, 11),
  ('davet.odul_edilen', 'oyun.davet_ayar', 'odul_edilen', null, 'diger', 'Davet edilen ödülü',
   'Davetle gelen oyuncuya verilen ödül.', 'para', '₺', 0, 1000000, null, 'dusuk', default, 12),
  ('davet.haftalik_tavan', 'oyun.davet_ayar', 'haftalik_tavan', null, 'diger', 'Haftalık davet sınırı',
   'Bir oyuncunun haftada ödül alabileceği en fazla davet.', 'tamsayi', 'davet', 0, 100, null, 'dusuk', default, 13),
  ('mahkeme.harc', 'oyun.mahkeme_ayar', 'harc', null, 'diger', 'Dava harcı',
   'Dava açarken ödenen harç.', 'para', '₺', 0, 1000000, null, 'dusuk', 'Yeni açılan davalarda.', 14),
  ('ayarlar.avukat_savunma_saat', 'oyun.ayarlar', 'avukat_savunma_saat', null, 'diger', 'Avukatlı savunma süresi',
   'Avukatlı davalarda savunma için verilen süre.', 'tamsayi', 'saat', 1, 168, null, 'dusuk', 'Yeni açılan davalarda.', 15)
on conflict (anahtar) do update set
  tablo = excluded.tablo, sutun = excluded.sutun, satir = excluded.satir, grup = excluded.grup, baslik = excluded.baslik,
  aciklama = excluded.aciklama, tur = excluded.tur, birim = excluded.birim, en_az = excluded.en_az, en_cok = excluded.en_cok,
  en_uzun = excluded.en_uzun, risk = excluded.risk, etki = excluded.etki, sira = excluded.sira, aktif = true;

-- İlan tarifeleri (çok satırlı tablo; tablo yoksa atlanır)
do $ilan$
begin
  if to_regclass('oyun.ilan_ayar') is not null then
    insert into oyun.yp_ayar_katalog (anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, risk, etki, sira)
    select 'ilan.' || i.kod, 'oyun.ilan_ayar', 'tutar', jsonb_build_object('kod', i.kod), 'diger', 'İlan ücreti: ' || i.ad,
           coalesce(i.aciklama, i.ad), 'para', '₺', 0, 1000000, 'dusuk', 'Yeni verilen ilanlarda.', 30 + i.sira
    from oyun.ilan_ayar i
    on conflict (anahtar) do update set baslik = excluded.baslik, aciklama = excluded.aciklama, sira = excluded.sira, aktif = true;
  end if;
end
$ilan$;

-- Canlı şemada olmayan tablo/sütun/satıra işaret eden kayıt pasif kalır (kurulum farkları güvenli olsun)
update oyun.yp_ayar_katalog k set aktif = false
where to_regclass(k.tablo) is null
   or not exists (select 1 from pg_attribute a where a.attrelid = to_regclass(k.tablo) and a.attname = k.sutun and not a.attisdropped);

create or replace function oyun.yp_ayar_grup_ad(p text)
returns text language sql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case p when 'genel' then 'Genel ve bakım' when 'hesap' then 'Hesap ve güvenlik' when 'ekonomi' then 'Ekonomi'
    when 'siyaset' then 'Siyaset ve seçim' when 'olay' then 'Olaylar ve krizler' when 'diger' then 'Davet, yargı ve ilanlar' else p end
$$;

-- ---------------------------------------------------------------------
-- 2) Okuma / doğrulama / yazma
-- ---------------------------------------------------------------------
create or replace function oyun.yp_ayar_kosul(k oyun.yp_ayar_katalog)
returns text language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(string_agg(format('t.%I::text = %L', e.key, e.value #>> '{}'), ' and '), 'true')
  from jsonb_each(coalesce(k.satir, '{}'::jsonb)) e
$$;

create or replace function oyun.yp_ayar_oku(k oyun.yp_ayar_katalog)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v jsonb;
begin
  if not k.aktif then return null; end if;
  execute format('select to_jsonb(t.%I) from %s t where %s limit 1', k.sutun, k.tablo::regclass, oyun.yp_ayar_kosul(k)) into v;
  return v;
end $$;

create or replace function oyun.yp_ayar_dogrula(k oyun.yp_ayar_katalog, v jsonb)
returns jsonb language plpgsql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare s text := v #>> '{}'; n numeric;
begin
  if k.tur = 'evet_hayir' then
    if jsonb_typeof(v) = 'boolean' then return jsonb_build_object('deger', v); end if;
    if lower(coalesce(s, '')) in ('true', 'evet', 'acik', 'açık', '1') then return jsonb_build_object('deger', true); end if;
    if lower(coalesce(s, '')) in ('false', 'hayir', 'hayır', 'kapali', 'kapalı', '0') then return jsonb_build_object('deger', false); end if;
    return jsonb_build_object('hata', 'Açık ya da kapalı seçilmeli.');
  elsif k.tur = 'metin' then
    s := btrim(coalesce(case when jsonb_typeof(v) = 'null' then null else s end, ''));
    if char_length(s) > coalesce(k.en_uzun, 500) then
      return jsonb_build_object('hata', format('En fazla %s karakter olabilir.', coalesce(k.en_uzun, 500)));
    end if;
    return jsonb_build_object('deger', to_jsonb(s));
  end if;
  s := replace(btrim(coalesce(s, '')), ',', '.');
  if s !~ '^-?\d{1,12}(\.\d{1,6})?$' then return jsonb_build_object('hata', 'Sayı girilmeli.'); end if;
  n := s::numeric;
  if k.tur in ('tamsayi', 'para') and n <> trunc(n) then return jsonb_build_object('hata', 'Tam sayı olmalı.'); end if;
  if k.en_az is not null and n < k.en_az then return jsonb_build_object('hata', format('En az %s olabilir.', k.en_az)); end if;
  if k.en_cok is not null and n > k.en_cok then return jsonb_build_object('hata', format('En çok %s olabilir.', k.en_cok)); end if;
  return jsonb_build_object('deger', to_jsonb(n));
end $$;

create or replace function oyun.yp_ayar_esit(k oyun.yp_ayar_katalog, a jsonb, b jsonb)
returns boolean language plpgsql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
begin
  if k.tur in ('tamsayi', 'sayi', 'para', 'yuzde') then
    return (a #>> '{}') ~ '^-?\d+(\.\d+)?$' and (b #>> '{}') ~ '^-?\d+(\.\d+)?$' and (a #>> '{}')::numeric = (b #>> '{}')::numeric;
  elsif k.tur = 'metin' then
    return coalesce(a #>> '{}', '') = coalesce(b #>> '{}', '');
  end if;
  return (a #>> '{}') is not distinct from (b #>> '{}');
end $$;

create or replace function oyun.yp_ayar_metin(k oyun.yp_ayar_katalog, v jsonb)
returns text language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare s text := v #>> '{}';
begin
  if k.tur = 'evet_hayir' then return case when s = 'true' then 'Açık' when s = 'false' then 'Kapalı' else '—' end; end if;
  if k.tur = 'metin' then return case when coalesce(s, '') = '' then '(boş)' else s end; end if;
  if s is null or s !~ '^-?\d+(\.\d+)?$' then return coalesce(s, '—'); end if;
  if k.tur = 'para' then return oyun.tl(s::numeric) || ' ₺'; end if;
  return trim(trailing '.' from trim(trailing '0' from case when s ~ '\.' then s else s || '.' end))
         || coalesce(case when k.birim in ('%', '×') then k.birim else ' ' || k.birim end, '');
end $$;

-- Tek yazım noktası: değer doğrulanır, yazılır, geçmişe işlenir.
create or replace function oyun.yp_ayar_yaz(p_anahtar text, p_deger jsonb, p_kaynak text, p_islem bigint, p_plan bigint, p_neden text)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare k oyun.yp_ayar_katalog; d jsonb; eski jsonb; yeni jsonb; tip text; n int; ek text := ''; ben oyun.profiller; r oyun.yp_islem;
begin
  select * into k from oyun.yp_ayar_katalog where anahtar = p_anahtar;
  if k.anahtar is null or not k.aktif then raise exception 'Tanımsız ayar: %', p_anahtar; end if;
  d := oyun.yp_ayar_dogrula(k, p_deger);
  if d->>'hata' is not null then raise exception '%: %', k.baslik, d->>'hata'; end if;
  eski := oyun.yp_ayar_oku(k);
  select format_type(a.atttypid, a.atttypmod) into tip from pg_attribute a
   where a.attrelid = k.tablo::regclass and a.attname = k.sutun and not a.attisdropped;
  if exists (select 1 from pg_attribute a where a.attrelid = k.tablo::regclass and a.attname = 'guncelleme' and not a.attisdropped) then
    ek := ', guncelleme = now()';
  end if;
  if tip = 'jsonb' then
    execute format('update %s t set %I = $1%s where %s', k.tablo::regclass, k.sutun, ek, oyun.yp_ayar_kosul(k)) using d->'deger';
  else
    execute format('update %s t set %I = ($1 #>> ''{}'')::%s%s where %s', k.tablo::regclass, k.sutun, tip, ek, oyun.yp_ayar_kosul(k)) using d->'deger';
  end if;
  get diagnostics n = row_count;
  if n = 0 then raise exception '% için ayar satırı bulunamadı.', k.baslik; end if;
  yeni := oyun.yp_ayar_oku(k);
  if p_islem is not null then select * into r from oyun.yp_islem where id = p_islem; end if;
  insert into oyun.yp_ayar_gecmis (anahtar, eski, yeni, kaynak, islem_id, plan_id, user_id, kad, neden)
  values (k.anahtar, eski, yeni, p_kaynak, p_islem, p_plan, r.user_id, r.kad, p_neden);
  return jsonb_build_object('anahtar', k.anahtar, 'baslik', k.baslik, 'eski', eski, 'yeni', yeni,
    'eski_metin', oyun.yp_ayar_metin(k, eski), 'yeni_metin', oyun.yp_ayar_metin(k, yeni));
end $$;

-- ---------------------------------------------------------------------
-- 3) İşlem: ayar_degistir
--    p: degisiklikler [{anahtar, deger}], neden, baslangic (isteğe bağlı, ileri tarih), bitis (isteğe bağlı: eski değere dönüş)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_ayar_degistir(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare z jsonb; k oyun.yp_ayar_katalog; d jsonb; eski jsonb; satir jsonb := '[]'::jsonb; hata text[] := '{}'; uy jsonb := '[]'::jsonb;
        bas timestamptz; bit timestamptz; neden text := oyun.yp_metin(p->>'neden', 3, 300); kritik boolean := false; gor text[] := '{}';
        degisen jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p->'degisiklikler') <> 'array' or jsonb_array_length(p->'degisiklikler') = 0 then
    return jsonb_build_object('engel', 'Değiştirilecek ayar seçmelisin.');
  end if;
  if jsonb_array_length(p->'degisiklikler') > 30 then return jsonb_build_object('engel', 'Bir seferde en fazla 30 ayar değiştirilebilir.'); end if;
  if neden is null then return jsonb_build_object('engel', 'Değişikliğin nedenini yaz (3-300 karakter); geçmişte görünür.'); end if;
  begin
    bas := nullif(p->>'baslangic', '')::timestamptz; bit := nullif(p->>'bitis', '')::timestamptz;
  exception when others then return jsonb_build_object('engel', 'Tarih biçimi geçersiz.'); end;
  if bas is not null and bas <= now() then return jsonb_build_object('engel', 'Başlangıç zamanı gelecekte olmalı (hemen uygulamak için boş bırak).'); end if;
  if bit is not null and bit <= coalesce(bas, now()) + interval '5 minutes' then
    return jsonb_build_object('engel', 'Bitiş zamanı başlangıçtan en az 5 dakika sonra olmalı.');
  end if;
  if bas > now() + interval '90 days' or bit > now() + interval '180 days' then return jsonb_build_object('engel', 'En fazla 90 gün ileriye planlanabilir.'); end if;

  for z in select * from jsonb_array_elements(p->'degisiklikler') loop
    select * into k from oyun.yp_ayar_katalog where anahtar = z->>'anahtar';
    if k.anahtar is null or not k.aktif then hata := hata || format('Tanımsız ayar: %s', z->>'anahtar'); continue; end if;
    if k.anahtar = any(gor) then hata := hata || format('%s iki kez seçilmiş.', k.baslik); continue; end if;
    gor := gor || k.anahtar;
    d := oyun.yp_ayar_dogrula(k, z->'deger');
    if d->>'hata' is not null then hata := hata || format('%s: %s', k.baslik, d->>'hata'); continue; end if;
    eski := oyun.yp_ayar_oku(k);
    if bas is null and oyun.yp_ayar_esit(k, eski, d->'deger') then hata := hata || format('%s zaten %s.', k.baslik, oyun.yp_ayar_metin(k, eski)); continue; end if;
    if k.risk = 'yuksek' then kritik := true; end if;
    if exists (select 1 from oyun.yp_ayar_plan pl, jsonb_array_elements(pl.degisiklikler) x
               where pl.durum = 'bekliyor' and x->>'anahtar' = k.anahtar) then
      uy := uy || to_jsonb(format('%s için bekleyen planlı bir değişiklik var; o da zamanı gelince uygulanır.', k.baslik));
    end if;
    satir := satir || jsonb_build_array(jsonb_build_object('anahtar', k.anahtar, 'ad', k.baslik, 'grup', oyun.yp_ayar_grup_ad(k.grup),
      'once', oyun.yp_ayar_metin(k, eski), 'sonra', oyun.yp_ayar_metin(k, d->'deger'),
      'risk', case k.risk when 'yuksek' then 'Yüksek' when 'orta' then 'Orta' else 'Düşük' end, 'etki', k.etki));
    degisen := degisen || jsonb_build_array(jsonb_build_object('alan', k.baslik, 'eski', oyun.yp_ayar_metin(k, eski), 'yeni', oyun.yp_ayar_metin(k, d->'deger')));
  end loop;
  if array_length(hata, 1) > 0 then return jsonb_build_object('engel', array_to_string(hata, ' ')); end if;

  if kritik then uy := uy || to_jsonb('Yüksek riskli ayar var: uygulamak için ikinci onay istenir.'::text); end if;
  if bas is not null then uy := uy || to_jsonb(format('Değişiklik %s tarihinde otomatik uygulanacak.', to_char(bas at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'))); end if;
  if bit is not null then uy := uy || to_jsonb(format('%s tarihinde ayarlar eski değerine dönecek (arada başkası değiştirirse dokunulmaz).', to_char(bit at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'))); end if;
  uy := uy || to_jsonb('Oyunda açık olan telefonlar değişikliği 0–8 saniye içinde alır; uygulama güncellemesi gerekmez.'::text);

  return jsonb_build_object(
    'ozet', format('%s ayar %s.', jsonb_array_length(satir),
      case when bas is null then 'hemen değişecek' else to_char(bas at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI') || ' tarihinde değişecek' end)
      || case when bit is not null then format(' %s tarihinde eski değerine dönecek.', to_char(bit at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')) else '' end,
    'degisen', degisen, 'ayarlar', satir, 'sayi', jsonb_array_length(satir), 'uyarilar', uy, 'kritik_islem', kritik,
    'parmak', md5(concat_ws('|', (select string_agg(x->>'anahtar' || '=' || coalesce(x->>'once', ''), ',' order by x->>'anahtar') from jsonb_array_elements(satir) x),
                  p->'degisiklikler', bas, bit, neden)));
end $$;

create or replace function oyun.yp_uy_ayar_degistir(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_ayar_degistir(p); islem bigint := nullif(current_setting('yp.islem_id', true), '')::bigint;
        bas timestamptz := nullif(p->>'baslangic', '')::timestamptz; bit timestamptz := nullif(p->>'bitis', '')::timestamptz;
        neden text := oyun.yp_metin(p->>'neden', 3, 300); z jsonb; k oyun.yp_ayar_katalog; r jsonb; kay jsonb := '[]'::jsonb;
        geri jsonb := '[]'::jsonb; plan_ids bigint[] := '{}'; pid bigint; tutarli boolean := true;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  if islem is null then raise exception 'İşlem kimliği yok.'; end if;
  if bas is null then
    for z in select * from jsonb_array_elements(p->'degisiklikler') loop
      select * into k from oyun.yp_ayar_katalog where anahtar = z->>'anahtar';
      r := oyun.yp_ayar_yaz(k.anahtar, (oyun.yp_ayar_dogrula(k, z->'deger'))->'deger', 'portal', islem, null, neden);
      kay := kay || jsonb_build_array(r);
      geri := geri || jsonb_build_array(jsonb_build_object('anahtar', k.anahtar, 'deger', r->'eski', 'beklenen', r->'yeni'));
      if not oyun.yp_ayar_esit(k, oyun.yp_ayar_oku(k), r->'yeni') then tutarli := false; end if;
    end loop;
    if bit is not null then
      insert into oyun.yp_ayar_plan (islem_id, zaman, tur, degisiklikler) values (islem, bit, 'geri_don', geri) returning id into pid;
      plan_ids := plan_ids || pid;
    end if;
  else
    insert into oyun.yp_ayar_plan (islem_id, zaman, tur, degisiklikler)
    select islem, bas, 'uygula', jsonb_agg(jsonb_build_object('anahtar', k2.anahtar, 'deger', (oyun.yp_ayar_dogrula(k2, x->'deger'))->'deger'))
    from jsonb_array_elements(p->'degisiklikler') x join oyun.yp_ayar_katalog k2 on k2.anahtar = x->>'anahtar'
    returning id into pid;
    plan_ids := plan_ids || pid;
    if bit is not null then
      -- eski değerler, planın uygulandığı anda yakalanıp buraya yazılır
      insert into oyun.yp_ayar_plan (islem_id, zaman, tur, degisiklikler) values (islem, bit, 'geri_don', '[]'::jsonb) returning id into pid;
      plan_ids := plan_ids || pid;
    end if;
  end if;
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', 'Canlı ayarlar',
    'eklenen', (select coalesce(jsonb_agg(jsonb_build_object('ad', x->>'baslik', 'once', x->>'eski_metin', 'sonra', x->>'yeni_metin')), '[]'::jsonb) from jsonb_array_elements(kay) x),
    'planlar', to_jsonb(plan_ids),
    'once', jsonb_build_object('kayitlar', (select coalesce(jsonb_agg(jsonb_build_object('anahtar', x->>'anahtar', 'deger', x->'eski')), '[]'::jsonb) from jsonb_array_elements(kay) x)),
    'sonra', jsonb_build_object('kayitlar', (select coalesce(jsonb_agg(jsonb_build_object('anahtar', x->>'anahtar', 'deger', x->'yeni')), '[]'::jsonb) from jsonb_array_elements(kay) x),
                                'planlar', to_jsonb(plan_ids), 'hemen', bas is null),
    'dogrulama', jsonb_build_object('tutarli', tutarli, 'planlanan', coalesce(array_length(plan_ids, 1), 0)));
end $$;

-- Geri al: bekleyen planlar iptal edilir; bu işlemle (ya da planıyla) yazılmış ve o günden beri değişmemiş ayarlar eski değerine döner.
create or replace function oyun.yp_gr_ayar_degistir(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare n_plan int := 0; g record; k oyun.yp_ayar_katalog; ok jsonb := '[]'::jsonb; atla jsonb := '[]'::jsonb; y jsonb;
begin
  select count(*) into n_plan from oyun.yp_ayar_plan where islem_id = r.id and durum = 'bekliyor';
  for g in select distinct on (anahtar) * from oyun.yp_ayar_gecmis
           where islem_id = r.id and kaynak in ('portal', 'plan') order by anahtar, id desc loop
    select * into k from oyun.yp_ayar_katalog where anahtar = g.anahtar;
    if exists (select 1 from oyun.yp_ayar_gecmis x where x.islem_id = r.id and x.anahtar = g.anahtar and x.kaynak = 'plan_bitis' and x.id > g.id) then
      continue;  -- süreli değişiklik zaten sona ermiş
    end if;
    if not oyun.yp_ayar_esit(k, oyun.yp_ayar_oku(k), g.yeni) then
      atla := atla || jsonb_build_array(jsonb_build_object('ad', k.baslik, 'neden', 'Bu işlemden sonra yeniden değişmiş; dokunulmadı.'));
      continue;
    end if;
    if p_uygula then
      y := oyun.yp_ayar_yaz(k.anahtar, g.eski, 'geri_al', r.id, null, 'İşlem #' || r.id || ' geri alındı');
    end if;
    ok := ok || jsonb_build_array(jsonb_build_object('ad', k.baslik, 'once', oyun.yp_ayar_metin(k, g.yeni), 'sonra', oyun.yp_ayar_metin(k, g.eski)));
  end loop;
  if p_uygula and n_plan > 0 then
    update oyun.yp_ayar_plan set durum = 'iptal', hata = 'İşlem geri alındı.' where islem_id = r.id and durum = 'bekliyor';
  end if;
  return jsonb_build_object(
    'ozet', format('%s ayar eski değerine %s%s.', jsonb_array_length(ok), case when p_uygula then 'döndü' else 'dönecek' end,
      case when n_plan > 0 then format(', %s bekleyen plan iptal %s', n_plan, case when p_uygula then 'edildi' else 'edilecek' end) else '' end),
    'sayi', jsonb_array_length(ok) + n_plan, 'eklenen', ok, 'eklenemeyen', atla,
    'uyarilar', case when jsonb_array_length(atla) > 0 then jsonb_build_array(format('%s ayar bu arada başka değere çekildiği için atlanacak.', jsonb_array_length(atla))) else '[]'::jsonb end,
    'engel', case when jsonb_array_length(ok) = 0 and n_plan = 0 then 'Geri alınacak bir şey kalmadı.' end,
    'once', r.sonra, 'sonra', r.once);
end $$;

-- ---------------------------------------------------------------------
-- 4) Zamanlayıcı: ileri tarihli ve süreli değişiklikler
-- ---------------------------------------------------------------------
create or replace function oyun.yp_ayar_plan_isle()
returns int language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pl oyun.yp_ayar_plan; z jsonb; k oyun.yp_ayar_katalog; r jsonb; yak jsonb; notlar jsonb; n int := 0; h text; ri oyun.yp_islem;
begin
  for pl in select * from oyun.yp_ayar_plan where durum = 'bekliyor' and zaman <= now() order by zaman, id for update skip locked loop
    yak := '[]'::jsonb; notlar := '[]'::jsonb;
    begin
      for z in select * from jsonb_array_elements(pl.degisiklikler) loop
        select * into k from oyun.yp_ayar_katalog where anahtar = z->>'anahtar';
        if k.anahtar is null or not k.aktif then notlar := notlar || to_jsonb(format('%s artık katalogda yok.', z->>'anahtar')); continue; end if;
        if pl.tur = 'geri_don' and not oyun.yp_ayar_esit(k, oyun.yp_ayar_oku(k), z->'beklenen') then
          notlar := notlar || to_jsonb(format('%s bu arada değiştirilmiş; eski değere döndürülmedi.', k.baslik)); continue;
        end if;
        if oyun.yp_ayar_esit(k, oyun.yp_ayar_oku(k), z->'deger') then continue; end if;
        r := oyun.yp_ayar_yaz(k.anahtar, z->'deger', case when pl.tur = 'uygula' then 'plan' else 'plan_bitis' end, pl.islem_id, pl.id,
                              case when pl.tur = 'uygula' then 'Planlı değişiklik' else 'Süreli değişiklik sona erdi' end);
        yak := yak || jsonb_build_array(jsonb_build_object('anahtar', k.anahtar, 'deger', r->'eski', 'beklenen', r->'yeni'));
      end loop;
      if pl.tur = 'uygula' then
        update oyun.yp_ayar_plan set degisiklikler = yak where islem_id = pl.islem_id and tur = 'geri_don' and durum = 'bekliyor';
      end if;
      update oyun.yp_ayar_plan set durum = 'uygulandi', uygulama = now(), sonuc = jsonb_build_object('yazilan', yak, 'notlar', notlar) where id = pl.id;
      select * into ri from oyun.yp_islem where id = pl.islem_id;
      insert into oyun.mod_kayit (zaman, user_id, kad, islem, hedef, ayrinti)
      values (now(), ri.user_id, ri.kad, case when pl.tur = 'uygula' then 'yp_ayar_plan' else 'yp_ayar_plan_bitis' end, 'Canlı ayarlar',
              format('İşlem #%s · %s ayar', pl.islem_id, jsonb_array_length(yak)));
      if jsonb_array_length(yak) > 0 then perform oyun.uzaktan_sinyal_yay('ayar'); end if;
      n := n + 1;
    exception when others then
      get stacked diagnostics h = message_text;
      update oyun.yp_ayar_plan set durum = 'basarisiz', hata = h, uygulama = now() where id = pl.id;
    end;
  end loop;
  return n;
end $$;

do $zamanlayici$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'yp-ayar-plan') then
      perform cron.unschedule('yp-ayar-plan');
    end if;
    perform cron.schedule('yp-ayar-plan', '* * * * *', 'select oyun.yp_ayar_plan_isle()');
  end if;
end
$zamanlayici$;

-- ---------------------------------------------------------------------
-- 5) Okuma
-- ---------------------------------------------------------------------
create or replace function public.yp_ayarlar()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return jsonb_build_object(
    'gruplar', (select jsonb_agg(jsonb_build_object('kod', g, 'ad', oyun.yp_ayar_grup_ad(g)) order by o)
                from (values ('genel', 1), ('hesap', 2), ('ekonomi', 3), ('siyaset', 4), ('olay', 5), ('diger', 6)) v(g, o)),
    'ayarlar', coalesce((select jsonb_agg(jsonb_build_object(
        'anahtar', k.anahtar, 'grup', k.grup, 'baslik', k.baslik, 'aciklama', k.aciklama, 'tur', k.tur, 'birim', k.birim,
        'en_az', k.en_az, 'en_cok', k.en_cok, 'en_uzun', k.en_uzun, 'risk', k.risk, 'etki', k.etki,
        'deger', v.deger, 'deger_metin', oyun.yp_ayar_metin(k, v.deger),
        'son', (select jsonb_build_object('zaman', g.zaman, 'kad', g.kad, 'kaynak', g.kaynak, 'islem_id', g.islem_id)
                from oyun.yp_ayar_gecmis g where g.anahtar = k.anahtar order by g.id desc limit 1),
        'planli', exists (select 1 from oyun.yp_ayar_plan pl, jsonb_array_elements(pl.degisiklikler) x
                          where pl.durum = 'bekliyor' and x->>'anahtar' = k.anahtar)) order by k.grup, k.sira, k.anahtar)
      from oyun.yp_ayar_katalog k cross join lateral (select oyun.yp_ayar_oku(k) deger) v where k.aktif), '[]'::jsonb),
    'planlar', coalesce((select jsonb_agg(jsonb_build_object('id', pl.id, 'islem_id', pl.islem_id, 'zaman', pl.zaman, 'tur', pl.tur,
        'kad', i.kad, 'neden', i.parametre->>'neden',
        'ayarlar', (select jsonb_agg(jsonb_build_object('ad', coalesce(k.baslik, x->>'anahtar'),
                       'deger', case when x ? 'deger' and k.anahtar is not null
                                          and not (pl.tur = 'geri_don' and jsonb_array_length(pl.degisiklikler) = 0)
                                     then oyun.yp_ayar_metin(k, x->'deger') end))
                    from jsonb_array_elements(case when pl.tur = 'geri_don' and jsonb_array_length(pl.degisiklikler) = 0
                                                   then i.parametre->'degisiklikler' else pl.degisiklikler end) x
                    left join oyun.yp_ayar_katalog k on k.anahtar = x->>'anahtar')) order by pl.zaman)
      from oyun.yp_ayar_plan pl left join oyun.yp_islem i on i.id = pl.islem_id where pl.durum = 'bekliyor'), '[]'::jsonb));
end $$;

create or replace function public.yp_ayar_gecmis(p_anahtar text default null, p_limit integer default 50)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'anahtar', g.anahtar, 'baslik', coalesce(k.baslik, g.anahtar), 'zaman', g.zaman,
      'eski', oyun.yp_ayar_metin(k, g.eski), 'yeni', oyun.yp_ayar_metin(k, g.yeni), 'kaynak', g.kaynak, 'islem_id', g.islem_id,
      'kad', g.kad, 'neden', g.neden) order by g.id desc)
    from (select * from oyun.yp_ayar_gecmis x where p_anahtar is null or x.anahtar = p_anahtar
          order by x.id desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) g
    left join oyun.yp_ayar_katalog k on k.anahtar = g.anahtar), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6) Çerçeve: yüksek riskli ayar içeren ön izleme ikinci onay ister (164/168 sürümlerinin yerine)
-- ---------------------------------------------------------------------
create or replace function public.yp_onizle(p_islem text, p_param jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); k oyun.yp_katalog; o jsonb; r oyun.yp_islem; pm text; onceki oyun.yp_islem; kritik boolean;
begin
  select * into k from oyun.yp_katalog where islem = p_islem;
  if k.islem is null then raise exception 'Tanımsız işlem: %', p_islem; end if;
  execute format('select oyun.%I($1)', 'yp_on_' || k.islem) into o using coalesce(p_param, '{}'::jsonb);
  pm := coalesce(o->>'parmak', md5(o::text));
  select * into onceki from oyun.yp_islem x where x.islem = k.islem and x.parametre = coalesce(p_param, '{}'::jsonb)
    and x.durum = 'uygulandi' and x.uygulama > now() - interval '24 hours' order by x.id desc limit 1;
  if onceki.id is not null and o->>'engel' is null then
    o := jsonb_set(o, '{uyarilar}', coalesce(o->'uyarilar', '[]'::jsonb) || to_jsonb(format(
      'Dikkat: aynı işlem aynı değerlerle %s tarihinde zaten uygulandı (#%s). Mükerrer olmadığından emin ol.',
      to_char(onceki.uygulama at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), onceki.id)));
    o := o || jsonb_build_object('mukerrer', onceki.id);
  end if;
  kritik := k.kritik or coalesce((o->>'kritik_islem')::boolean, false);
  insert into oyun.yp_islem (islem, parametre, user_id, kad, gecerlilik, onizleme, parmak)
  values (k.islem, coalesce(p_param, '{}'::jsonb), p.id, p.kad, now() + interval '15 minutes', o, pm)
  returning * into r;
  return o || jsonb_build_object('anahtar', r.anahtar, 'islem_id', r.id, 'gecerlilik', r.gecerlilik,
    'baslik', k.baslik, 'kritik', kritik, 'onay_metni', coalesce(k.onay_metni, 'ONAYLIYORUM'), 'geri_alinabilir', k.geri_alinabilir);
end $$;

create or replace function public.yp_uygula(p_anahtar uuid, p_onay text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); r oyun.yp_islem; k oyun.yp_katalog; o jsonb; s jsonb; h text;
begin
  select * into r from oyun.yp_islem where anahtar = p_anahtar for update;
  if r.id is null then raise exception 'İşlem bulunamadı.'; end if;
  if r.durum = 'uygulandi' then
    return coalesce(r.sonuc, '{}'::jsonb) || jsonb_build_object('basarili', true, 'tekrar', true, 'islem_id', r.id,
      'mesaj', 'Bu işlem daha önce uygulandı; ikinci kez çalıştırılmadı.');
  end if;
  if r.durum <> 'onizleme' then
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', 'Bu ön izleme artık kullanılamaz. Yeniden ön izleme yap.');
  end if;
  if r.gecerlilik < now() then
    update oyun.yp_islem set durum = 'iptal', hata = 'Ön izlemenin süresi doldu.' where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', 'Ön izlemenin süresi doldu (15 dakika). Yeniden ön izleme yap.');
  end if;
  select * into k from oyun.yp_katalog where islem = r.islem;
  if k.kritik or coalesce((r.onizleme->>'kritik_islem')::boolean, false) then
    perform oyun.yp_sahip(10);
    if upper(btrim(coalesce(p_onay, ''))) <> upper(coalesce(k.onay_metni, 'ONAYLIYORUM')) then
      raise exception 'YP_ONAY: Onaylamak için % yazmalısın.', coalesce(k.onay_metni, 'ONAYLIYORUM');
    end if;
  end if;

  execute format('select oyun.%I($1)', 'yp_on_' || r.islem) into o using r.parametre;
  if o->>'engel' is not null then
    update oyun.yp_islem set durum = 'basarisiz', hata = o->>'engel', uygulama = now() where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', o->>'engel');
  end if;
  if coalesce(o->>'parmak', md5(o::text)) <> r.parmak then
    update oyun.yp_islem set durum = 'iptal', hata = 'Veriler ön izlemeden sonra değişti.' where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'degisti', true,
      'hata', 'Ön izlemeden sonra veriler değişti; hiçbir şey uygulanmadı. Yeniden ön izleme yap.');
  end if;

  perform set_config('yp.islem_id', r.id::text, true);
  begin
    execute format('select oyun.%I($1)', 'yp_uy_' || r.islem) into s using r.parametre;
  exception when others then
    get stacked diagnostics h = message_text;
    update oyun.yp_islem set durum = 'basarisiz', hata = h, uygulama = now() where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', h);
  end;

  update oyun.yp_islem set durum = 'uygulandi', uygulama = now(), sonuc = s, once = s->'once', sonra = s->'sonra',
    geri_alinan = case when r.islem = 'geri_al' then (r.parametre->>'islem_id')::bigint end
  where id = r.id;
  perform oyun.mod_log(p, 'yp_' || r.islem, coalesce(s->>'hedef', ''), coalesce(s->>'ozet', k.baslik));
  perform oyun.uzaktan_sinyal_yay('yonetici');
  return s || jsonb_build_object('basarili', true, 'islem_id', r.id);
end $$;

-- ---------------------------------------------------------------------
-- 7) Yetkiler (164 ile aynı kural)
-- ---------------------------------------------------------------------
do $yp_yetki$
declare r record;
begin
  for r in select p.oid::regprocedure imza from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'oyun' and p.proname like 'yp\_%' loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.imza);
  end loop;
  for r in select p.oid::regprocedure imza from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'yp\_%' loop
    execute format('revoke execute on function %s from public, anon', r.imza);
    execute format('grant execute on function %s to authenticated', r.imza);
  end loop;
end
$yp_yetki$;
