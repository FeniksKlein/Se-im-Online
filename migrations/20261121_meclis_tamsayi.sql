-- 21.11.2026 · TBMM eşikleri SABİT 600 üzerinden kalır (Ercan'ın kararı, 16.11 "yayın ölçeği" temeli).
-- Seçilen vekil sayısına bağlama denemesi aynı gün geri alındı (canlı: meclis_tamsayi_sabit_600_geri);
-- tbmm_tamsayi, grup_esigi ve erken_secim_gerekli_oy kaynak tanımlarındaki hâliyle (zz_20261115_gercekci_siyaset_asama1.sql) durur.
-- Burada yalnız bildirim metnindeki sabit "400"ün gerçek eşikten okunması kalır (600'de yine 400).
-- Bildirim metnindeki sabit "400" gerçek eşiği göstersin
select oyun._yama('public.kanun_cb_karar(bigint,text,text)',
  $re$üçte iki \(400\) kabul oyu gerekir\.'\s*,\s*k\.baslik\s*\)$re$,
  $new$üçte iki (%s) kabul oyu gerekir.',k.baslik,ceil(oyun.tbmm_tamsayi()*2/3.0)::int)$new$,
  'üçte iki (%s) kabul oyu');
