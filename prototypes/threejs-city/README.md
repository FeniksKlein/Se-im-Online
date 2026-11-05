# Seçim Online — Three.js 3D şehir pilotu

## Mevcut mimari
README.md ve KURULUM.md: ana arayüz `www/index.html` (tek HTML), Capacitor iOS/Android paketleme, Supabase PostgreSQL. Pilot mevcut uygulama veya veritabanına bağlı değildir.

## Pilot
`prototypes/threejs-city/index.html`: Three.js, OrbitControls, dört etkileşimli bina (belediye, banka, parti merkezi, TBMM), mobil dokunma/döndürme/yakınlaştırma, yalnızca demo bilgi panelleri. CDN üzerinden ES modülleri yükler; çevrimdışı çalışmaz. Yeni API anahtarı veya SQL migration yoktur.

## Çalıştırma
Dosyayı statik bir HTTP sunucusuyla servis edin (ör. `python3 -m http.server 8080` komutunu depo kökünde çalıştırıp `http://localhost:8080/prototypes/threejs-city/` adresini açın). WebGL ve internet bağlantısı gerekir. Bu yol GitHub Pages'e otomatik yayımlanmaz; main dalında değişiklik yoktur.

## Canlı oyuna entegrasyon öncesi
1. `www/index.html` içindeki mevcut navigasyon ve ekran açma fonksiyonlarını ayrıntılı tespit et.
2. Oyuncu isteğiyle yüklenen isteğe bağlı 3D ekran tasarla; 2D ekranı varsayılan ve geri dönüş seçeneği olarak koru.
3. CDN bağımlılığını sürüm sabitleyerek yerel derlemeye taşı; CSP, Capacitor WebView ve ağsız kullanım testlerini yap.
4. Düşük performanslı Android/iOS cihazlarda FPS, bellek ve pil tüketimini ölç; kalite seçenekleri ekle.
5. Kurum nesnelerinin tıklamalarını mevcut ekran yönlendirmelerine bağla; oyuncu/para/seçim kayıtlarını değiştirme.
6. Erişilebilirlik, dokunmatik alanlar, ekran döndürme, güvenlik ve regresyon testleri tamamlanmadan main'e birleştirme.

## Güvenlik
Bu dalda hiçbir SQL, Edge Function, `www/index.html`, dağıtım veya canlı Supabase ayarı değiştirilmedi. Demo gerçek oyun verilerini okumaz ve yazmaz.
