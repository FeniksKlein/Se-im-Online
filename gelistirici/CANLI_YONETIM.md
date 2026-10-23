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

## Yük koruması — 23 Ekim 2026 (seçim gecesi çöküşü sonrası)
- **Periyodik işler tek zamanlayıcıda.** 27 ayrı cron işi pasif; yerine her dakika `oyun-zamanlayici` → `call oyun.zamanlayici_calistir()`. Adımlar `oyun.zamanlayici_adim` tablosunda (periyot, ofset, sıra, son çalışma, son hata). **Yeni periyodik iş eklerken `cron.schedule` kullanma**, bu tabloya satır ekle. Ayrıntı ve geri alma: `migrations/20261023_secim_gecesi_yuk_azaltma.sql`.
- **Sunucu önbelleği.** `oyun.genel_onbellek` (UNLOGGED). Seçim gecesi canlı ekranının herkese aynı kısmı 5 sn, ana sayfadaki seçim gecesi kartı 10 sn önbellekten gelir.
- **İstemci yük koruması (`YUK`, docs/index.html).** Sık okunan RPC'ler kısa süre telefonda tutulur (`SURE` listesi), aynı anda giden aynı istek teke iner. Oyuncu dokunduktan sonraki 6 sn içinde yapılan, sunucuda STABLE olmayan her çağrı önbelleği siler (oy, başvuru, mesaj vb. sonrası veri hep taze). 5xx/zaman aşımında zamanlayıcıyla yapılan yenilemeler 5 sn'den 5 dk'ya kadar kademeli bekletilir. Yeni bir **okuma** RPC'si sık çağrılacaksa `SURE` listesine ekle; **yazma** RPC'lerini asla ekleme.
- **Yenileme aralıkları.** Ana sayfa 2–2,5 dk; seçim gecesi canlı ekranı 15–19 sn; sohbet ve miting 6–7,5 sn; mesaj rozetleri 45–55 sn; uzaktan kontrol yedek sorgusu 90–120 sn. Geri sayım sıfırlanınca ana sayfa 2–30 sn arasında rastgele yenilenir (herkes aynı saniyede değil).
- **Yayın kaynağı `docs/`.** Canlı web ve mağaza paketi `docs/`tan üretilir; `www/index.html` eski geliştirici kopyasıdır, oraya yapılan değişiklik oyunculara ulaşmaz.
- **Meclis okuma kilidi.** `meclis_baskanlik()` artık `meclis_tick`'i beklemeden dener (başkası ilerletiyorsa geçer, en fazla 15 sn'de bir); `oyun.tick()` her dakika zaten ilerletir. Okuma yolunda **genel kilit (`pg_advisory_xact_lock`) alan tick çağırma**; gerekirse `pg_try_advisory_xact_lock` kullan.
- **Yük testi (23.10.2026, Large, 2 vCPU).** Ana sayfa turu (~23 RPC) tek işçide 49 ms; doyumda saniyede ~27 tur, 8 eşzamanlı işçide bile hata yok, gecikme doğrusal (295 ms). Tahmini kapasite: Large ≈ 1.000, XL ≈ 2.000 eşzamanlı aktif oyuncu.
