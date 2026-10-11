-- Seçim Simülasyonu Online — YAYIN ÖNCESİ (gerçek oyuncular gelmeden) çalıştırılacak sıkı ayarlar.
-- Test döneminde gevşetilmiş kuralları üretim değerlerine çeker. Oyuncu verisine dokunmaz; istediğin zaman tekrar gevşetebilirsin.
begin;
update oyun.ayarlar set
  min_hesap_gun      = 3,     -- yeni hesap 3 gün dolmadan oy kullanamaz / aday olamaz
  oy_min_kidem       = 3,     -- oy için en az 3 kıdem puanı
  oy_il_gun          = 7,     -- il değiştiren 7 gün o ilde oy kullanamaz
  parti_kurucu_sayi  = 5,     -- yeni parti için 5 kurucu
  parti_kurucu_kidem = 30,    -- kurucuların en az 30 kıdemi olmalı
  coklu_kontrol      = true,  -- aynı cihazdaki hesaplar ilişkili sayılır
  cihaz_zorunlu      = true,
  eposta_zorunlu     = true
where id = 1;
update oyun.guvenlik_ayar set fiyat_bandi = true, masak = true, odul_min_gun = 7, gunluk_odul_sinir = 3 where id = 1;
commit;
-- Not: Supabase › Authentication › "Confirm email" seçeneğini de açmayı unutma (özel SMTP kurulduktan sonra).
