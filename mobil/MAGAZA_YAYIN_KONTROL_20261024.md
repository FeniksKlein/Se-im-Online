# Seçim Online — mağaza paketleri / 24.10.2026

Bu klasördeki Capacitor yapılandırması canlı web sürümünü Android ve iOS uygulama projelerine dönüştürür.

## Otomatik derleme
`.github/workflows/magaza.yml` ana dala bu klasörde yapılan değişikliklerle otomatik çalışır.
Başarılı derlemenin çıktıları `magaza-ciktilari` dalındadır:

- `SecimOnline-deneme.apk` — yalnızca cihazda test içindir, Play yüklemesi değildir.
- `SecimOnline-imzasiz.aab` — Google Play için **imzalanması gerekir**. Başka birinin anahtarını kullanmayın.
- `SecimOnline-proje.zip` — Xcode/Android Studio açılabilen yerel projeler. App Store için Apple Developer hesabıyla arşivlenip imzalanmalıdır.

## Yayından önce gerçek hesaplarda tamamlanacaklar
1. Android AAB: uygulamanın yükleme anahtarıyla imza, kalıcı anahtar yedeği, Play Console uygulama kimliği ve sürüm kodu.
2. iOS IPA: Apple Developer ekibi, dağıtım sertifikası/provisioning, App Store Connect ve Xcode Archive/Distribute.
3. `magaza.json` içindeki AdMob uygulama kimlikleri **test değerleridir**. Reklam yayınlanacaksa gerçek AdMob hesap kimlikleriyle değiştirilmelidir.
4. Mağaza gizlilik/veri güvenliği açıklamaları, hesap silme bağlantısı, ekran görüntüleri, yaş derecelendirmeleri, ödeme abonelik ayarları, test cihazı kontrolleri.

Derleme olması tek başına mağaza onayı veya canlıda hatasız çalışma anlamına gelmez.
