-- 15.11.2026 · Çalıştay giderleri gerçekçi bütçe
-- Bakanlık finansmanı milyar TL cinsindendir: 0.0015 milyar = 1.500.000 TL.
-- Yalnız iki konuşmacı odaklı çalıştayı etkiler; eski etkinlik işlemlerine dokunmaz.
-- Yeni kurulum ve tekrar çalıştırma için idempotent katalog düzeltmesidir.
update oyun.bakanlik_etkinlik_tur
set maliyet = 0.0015,
    aciklama = 'Konuşmacı odaklı çalıştay; giderler yalnızca salon kirası, masa-sandalye düzeni ve yiyecek-içecek ikramlarıdır. Oyuncular katılım, destek veya eleştiri bildirebilir; katılanlar günlük limit dahilinde kıdem kazanır ve katılım arttıkça ilin etkinlik etkisi güçlenir.'
where kod in ('bke_bo26_egitim', 'bke_bo26_ulastirma');
