# 1.0.9 (11)
Oyun sürümü 2026.11.25-4. Yük koruması sürümü; ekran ve özellik değişikliği yok.

- Geri sayım sıfırlanınca (oylama bitişi, sonuç saati, göreve başlama) bütün telefonlar aynı saniyede ana ekranı yeniliyordu; 25.11 akşamı 22.00 ve 22.30'da sunucuyu kilitleyen buydu. Yenileme artık oyuncu başına rastgele 3–28 saniye sonra, tek sefer yapılır.
- 1.0.8 (10) içeriğinin tamamını kapsar.

Sunucu tarafındaki hızlandırmalar (Kürsü, sohbet, unvan önbelleği) mağaza sürümünden bağımsızdır ve 25.11 gecesi canlıya alındı; kaynağı `gelistirici/sql/zz_20261125_yuk_hizlandirma.sql`.

Paketler güncel kaynak kodundan derlenir (GitHub Actions › magaza.yml). Android paketi imzasızdır; Google Play'e yüklenmeden önce yükleme anahtarıyla imzalanır. iOS için proje MacinCloud'da Xcode ile arşivlenir.
