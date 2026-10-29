# Seçim Simülasyonu Online — App Store aktarım paketi (29.10.2026)

## Tek oyun, tek canlı sunucu
- Kaynak: FeniksKlein/Se-im-Online `main`, `docs/` içindeki web sürümü.
- Uygulama: `mobil/` Capacitor 8 iOS projesi; kimlik `com.feniksklein.secimonline`.
- Backend: Var olan `secim-online` Supabase projesi (`viewlouzlzxteygtnsgd`, eu-central-1). Yeni/boş sunucu veya SQL importu **yapılmayacak**. Canlı oyuncu verileri aynen kalacak.
- `gelistirici/build/magaza_paketi.js` en son `docs/` dosyalarını `mobil/www` içine kopyalar, Supabase istemcisini yerel dosya yapar.
- `.github/workflows/magaza.yml` macOS'ta iOS simülatör derlemesi ve `SecimOnline-proje.zip` üretir. Çıktı: `magaza-ciktilari` dalı. `BILGI.txt` içindeki `kaynak` commit SHA'sı ile son oyun güncellemelerinin dahil olduğunu doğrulayın.

## Apple'a yüklemek için kalan (hesap sahibi tarafından)
1. App Store Connect'te iOS uygulaması açın. Bundle ID tam olarak `com.feniksklein.secimonline` olmalı (varsa mevcut App ID ile aynı).
2. macOS ve Xcode **26 veya üstü** ile `mobil/ios/App/App.xcodeproj` açın. Apple Developer takımını seçin; otomatik signing/provisioning etkinleştirin.
3. Gerçek Apple Developer imzasıyla iPhone için Archive -> Distribute App -> App Store Connect -> Upload. İmzasız simülatör derlemesi veya `SecimOnline-proje.zip` tek başına App Store'a yüklenemez; mağazaya `.ipa` veya Xcode'dan imzalı dağıtım gerekir.
4. App Store Connect'te gizlilik politikası, hesap silme URL'si, yaş derecelendirmesi, açıklama ve iPhone ekran görüntüleri girin. Oyunun gerçek satın alma ve reklam SDK'larını doğrulayın. `mobil/magaza.json` içindeki AdMob kimlikleri TEST değeridir: gerçek kimlikler verilmeden canlı reklamla yayın yapmayın. iOS dijital satın alma sistemi Apple kurallarına uymalıdır.
5. Gerçek iPhone'da oturum açma, seçim, ekonomi, banka, dava, sohbet, satın alma ve hesap silmeyi test edin. Apple incelemesi için etkin bir demo hesabı sağlayın. Kullanıcı içeriği için şikayet/engelleme ve çocuk güvenliği kurallarını kontrol edin.

**Gizlilik:** Service-role / secret anahtarları iOS istemcisine veya GitHub'a yazmayın. Yalnız Supabase publishable/anon anahtarları, RLS ile kullanılabilir.

**Not:** Bu dosya, en güncel oyun kodundan mağaza projesinin yeniden üretilmesi amacıyla eklenmiştir. Yayındaki sunucuyu ve oyuncu verilerini değiştirmez.
