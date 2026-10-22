# Canlı Oyun Yönetimi — 22 Ekim 2026

Bu sürümde mobil uygulamanın içine kod enjekte edilmez. Yalnızca Supabase üzerindeki veriler, mevcut izinli oyun API'leri ve önceden uygulamaya yerleştirilmiş arayüz seçenekleri değiştirilir.

## Yönetici akışı
- Ben → Yönetici Paneli → Kontrol Merkezi → **Canlı Oyun Yönetimi**.
- `Şirket alım-satım pazarı` ve `NPC stoklu işletmeler` sunucudan açılıp kapatılır. Modül kapalıyken ilgili sunucu RPC/trigger işlemleri de reddeder.
- **Tüm açık telefonlara yenileme sinyali gönder** yalnızca oyun sahibi için kullanılır; para ve makam kaydı değiştirmez.
- Diğer mevcut yönetim işlemleri (para, makam, oyuncu yasakları, seçim tarihleri, bakım, duyuru) mevcut `yk_*` RPC'leri, Supabase tabloları ve denetim kayıtlarıyla çalışmaya devam eder.

## Senkronizasyon
- `public.oyun_kontrol_sinyali`: yalnızca genel `rev/tur/zaman`; isim, para, erişim anahtarı, oyuncu verisi içermez. RLS yalnızca kimliği doğrulanmış oyuncuların SELECT işlemini kabul eder. İstemcinin UPDATE/INSERT izni yoktur.
- `public.uzaktan_kontrol_durum()`: oturum gerektiren ve güvenli modül bayraklarını dönen RPC. Yöneticiye ait gizli ayarları döndürmez.
- Supabase Realtime `postgres_changes` UPDATE olayları; yedek olarak uygulama açıkken yaklaşık 45 saniyede bir ve uygulamaya dönüldüğünde kontrol.
- Yeni sinyal geldiğinde istemci `uygulama_ayar`, `surum`, `durum` RPC'lerini sorgular. İç içe ekran, açık modal veya arka planda çalışma varsa ekran zorla değiştirilmez. Sunucu her kritik eylemde yetki kontrolünü korur.

## ChatGPT üzerinden doğrudan veritabanı değişiklikleri
- Yönetici panelindeki `yk_*` işlemleri `oyun.yk_degisiklik` üzerinden otomatik sinyal verir.
- Yasak güncellemesi `oyun.profiller` ve seçim takvimi `oyun.secimler` üzerinden otomatik sinyal verir.
- Doğrudan SQL ile çok sayıda hesaba para yükleme, makam atama, ekonomi müdahalesi yapılırsa aynı işlemden sonra `select oyun.uzaktan_sinyal_yay('yonetici');` çağrılır. Bu sadece istemcilerin durumu tekrar okumasını sağlar; yetkisiz bir API değildir ve uygulama kullanıcısına EXECUTE verilmez.
- Toplu ekonomik işlemlerde tüm cüzdan hareketlerini Realtime'a yayınlayan genel tetikleyici kurma; gereksiz maliyet ve güvenlik riski yaratır.

## Mağaza sürümü
- Yayın kaynağı: `docs/` (GitHub Pages); Capacitor paketi: `gelistirici/build/magaza_paketi.js`, `mobil/www`. Paket oluşturulurken `docs` altındaki JS'ler kopyalanır ve Supabase SDK yerel hale getirilir.
- Sürüm: `gelistirici/SURUM` ve `window.UYGULAMA_SURUM`. Eski uygulamayı zorla kilitlemek için **min_uygulama** değerini ancak yeni iOS/Android sürümleri gerçekten yayımlandıktan sonra yükselt.
- Tamamen yeni native özellik, yeni HTML/JS ekranı veya paketlenmiş kod güncellemesi için App Store/Google Play üzerinden incelemeli yeni uygulama sürümü gerekir. Sunucudan dinamik JS çalıştırılmamalıdır.
- Otomatik senkronizasyon internet bağlantısı, oyuncu oturumu ve çalışan uygulama gerektirir. Arka plandaki telefonlara kesin anlık ulaşma garantisi yoktur; gerektiğinde push bildirimi ayrıdır.

## Kontroller
- Güvenli yeni tablo RLS + Realtime publication etkin.
- Yönetici RPC'si `oyun.yk_sahip()` ile doğrulanır. Yetkisiz oyuncunun modül aç/kapat isteği reddedilmiştir.
- Rollback içinde NPC modülünü geçici kapatıp motorun çalışmadığı doğrulandı; rollback sonrası modüller açık ve oyuncu verileri değişmeden kaldı.
- İlk yedek `yedek_20261022_131647_520342` olarak alındı.
