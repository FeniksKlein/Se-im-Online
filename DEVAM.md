# DEVAM — yeni sohbette önce bunu oku

Sahibi: Ercan (FeniksKlein / Gülveren Games). Kodlama bilmiyor; **her şeyi Türkçe, sade ve adım adım anlat.**
Proje: "Seçim Simülasyonu Online" — çok oyunculu siyaset rol yapma oyunu (tek dosya HTML/JS + Capacitor, Supabase arka uç).

## ⚠️ Önce bunu oku (2026-10-09)
- **Tek doğru kaynak `gelistirici/` klasörüdür.** `www/index.html`, `docs/index.html` ve `supabase-kurulum.sql` derleme çıktısıdır; **elle düzenleme**. 8 Ekim akşamı doğrudan derlenmiş dosyalara ve canlıya yapılan değişiklikler 9 Ekim'de kaynağa geri taşındı (`gelistirici/sql/38_canli_20261008.sql`).
- Canlıya küçük değişiklik gerekiyorsa: kaynağa yeni bir `gelistirici/sql/NN_*.sql` modülü ekle, `build/sql_birlestir.js` listesine yaz, **aynısını** `migrations/YYYYMMDD_*.sql` olarak (begin/commit içinde) Ercan'a çalıştırt.
- Canlı veritabanında migration geçmişi: 8 Ekim migration'ları (`migrations/20261008_*`) ve **`migrations/20261009_oyuncu_deneyimi.sql`** (Ercan çalıştırmalı; 1 Kasım genel seçiminden önce şart — genel seçim sayımındaki hata burada düzeltildi).
- Tam kurulum dosyası artık temiz bir veritabanında hatasız kuruluyor (pg_cron yalnız Supabase'de).

## Testler ve önizleme (Linux + Postgres 16)
- `bash gelistirici/test/hepsi.sh` → bakımı yapılan testler: simulasyon (404 oyunculu tam ay), guvenlik, oyuncu_deneyimi (39 modülü + canlı geçişi), kalicilik. ~8 dk. `bash test/hepsi.sh eski` eski testleri de çalıştırır; onların bir kısmı ekonomi dengesi değiştiği için güncel olmayan beklentiler içerir (hata değil, test bakımı gerekiyor).
- Eski tarayıcı testleri (`arayuz.js`, `basin_arayuz.js`, `istifa_arayuz.js`) 9 Ekim öncesinde de geçmiyordu (bayat beklentiler).
- **Gerçek verili önizleme:** `bash kur_yerel.sh && cd test && python3 simulasyon.py && python3 onizleme_dunya.py gundem` (sonra `sandik`, `sonuc`), `node test/onizleme_sunucu.js &` ve `NODE_PATH=/opt/npm-tools/node_modules node test/onizleme_ekran.js <klasör> Ercan_Ege gundem,hayat,sandik,...` → 390 px ekran görüntüleri. Uygulama Supabase yerine yerel veritabanına bağlanır.

## Arayüz kimliği (2026-10-09)
"Seçim gecesi stüdyosu": lacivert zemin, oy pusulası kâğıdı, tercih mührü moru (`--ink`, oyuncunun eylemi), canlı kırmızısı (`--al`). Başlık/rakam yazı tipi Kurul Display (`gelistirici/www/yazi/`, derlemede base64 gömülür). Emoji ve büyük harf etiket kullanılmaz. Yeni ekran parçaları `gelistirici/www/arayuz.js` içinde (portre, Gündem panosu, sonuç sahnesi, parti pusulası/testi, tarih, mitingler).

## Canlı durum
- 2026.10.07-3 kaynak eşitlemesi: canlı migration `20261007153118 / basin_ve_teskilat_gorevlisi_20261007`, `gelistirici/sql/17_basin_teskilat.sql` içine alındı. İçteki güncelleme başlat/bitir çağrıları çıkarıldı; bunları birleşik dosya tek kez yönetir. RPC yetkileri aynı dosyada korunur. **Bu çalışma için canlı Supabase'e SQL tekrar uygulanmaz.**
- Gündem → Basın / Gazeteler: kurma, abonelik, kilitli önizleme, yazar teklifleri, yayınlama, kasa ve ayarlar. Kaynak: `gelistirici/www/basin.js`; HTML derlemesine gömülür. Alt menü altı sekme olarak kaldı.
- İl seçimi oyuncu/MV oranıyla sıralanır; bağlantı hatasında oyuncu sayısı sıfır sayılmaz. Parti ekranı sorumlu atama/kaldırma ve `teskilat_ac2` ile ödeme kaynaklarını destekler. Mevcut `bagis_yap` korunmuştur.
- Windows'ta SQL üretimi: `node gelistirici/build/sql_birlestir.js`; eski bash komutu aynı üreticiyi çağırır. Basın/görev tabloları da kalıcılık parmak izine eklendi. Canlıya uygulanmadı.
- Yeni bağımsız test: `node gelistirici/test/basin_arayuz.js` (Playwright, gerekirse NODE_PATH ve CHROME_PATH). Gerçek mobil DOM + sahte RPC; canlıya bağlantı/yazma yok. İl, tüm basın işlemleri, teşkilat, bağış, XSS, kilit, hata, 320/390/768/1280 px kontrolleri.
- Bu Windows ortamında eski Postgres testleri `psql`/`bash` eksikliğinden, eski arayüz testi sabit `/opt/npm-tools/node_modules/playwright` yolundan çalışamadı. Bunlar başarılı sayılmamalı; uygun yerel Linux/Postgres ortamında tekrar çalıştırılmalı.
- Oyun (web): https://feniksklein.github.io/Se-im-Online/  (GitHub Pages, `docs/` klasörü)
- Depo: FeniksKlein/Se-im-Online (public). Supabase projesi: secim-online (Free, Frankfurt).
- Uygulamadaki Supabase URL + publishable anahtar `www/index.html` içindeki `window.AYAR` bloğunda (herkese açık anahtar; sorun değil).
- Güncel sürüm: dosya `gelistirici/SURUM`.

## GİZLİ tutulacaklar (asla isteme, asla uygulamaya koyma)
service_role / secret anahtar, veritabanı şifresi, FCM servis hesabı JSON'u, ODEME_GIZLI. Kullanıcıdan yalnızca Project URL ve publishable/anon anahtar istenir.
Ücretli Supabase kaynağı, maliyeti gösterip onay almadan açılmaz.

## Kod nerede
- `gelistirici/sql/` SQL dosyaları (01…16, kalicilik_bas/son), `gelistirici/www/` kaynak, `gelistirici/test/` testler, `gelistirici/build/` derleme, `gelistirici/kur_yerel.sh` yerel kurulum.
  - 15_ekonomi3.sql: parti kuruluş ücreti, il teşkilatları, oyuncudan oyuncuya para gönderme, banka (vadesiz/vadeli/kredi, gecikme ve yasal takip).
  - 16_moderator.sql: moderatör ekibi, yetkiler (`oyun.yetki_zorunlu('kod')`), moderasyon günlüğü. Admin fonksiyonları artık yetki koduyla korunuyor.
- Yayın dosyaları: `supabase-kurulum.sql` (Supabase'e yapıştırılan tek dosya), `docs/index.html` ve `www/index.html` (derlenmiş tek dosya).
- Okunacak belgeler: `TASARIM.md`, `GUNCELLEME_KURALLARI.md`, `KURULUM.md`.

## Altın kural: OYUN HİÇ SIFIRLANMAZ
Güncellemeler yalnızca EKLER (yeni tablo/sütun/makam). Oyuncunun makamı, parası, kıdemi, geçmişi korunur; `guncelleme_bitti` parmak izi farklıysa güncellemeyi durdurur. Ayrıntı: `GUNCELLEME_KURALLARI.md`. Sıfırlamayı yalnızca Ercan bilerek yapar.

## Her değişiklikte izlenecek yol
1. SQL/uygulama değiştir → `gelistirici/SURUM` artır (YYYY.AA.GG-N).
2. Yerel Postgres 16'yı aç (soket /tmp), `bash test/hepsi.sh` ile testleri çalıştır; arayüz için önizleme ekran görüntülerine bak.
   Postgres açmak: `su postgres -c "/usr/lib/postgresql/16/bin/initdb -D /tmp/pgdata -A trust -U postgres"` ve `su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /tmp/pgdata -o \"-k /tmp -c listen_addresses=''\" -l /tmp/pg.log start"`.
3. `node build/derle.js` + `bash build/sql_birlestir.sh` → dist üret.
4. Depoya senkronla (supabase-kurulum.sql, docs/index.html, www/index.html, gelistirici/*), commit, `git push origin main`.
5. Ercan'a: raw GitHub linkinden **yeni migration dosyasını** kopyalayıp Supabase SQL Editor'de Run'lamasını söyle (adım adım). Tam `supabase-kurulum.sql` yalnız yeni kurulum içindir.
   Örnek: https://raw.githubusercontent.com/FeniksKlein/Se-im-Online/main/migrations/20261009_oyuncu_deneyimi.sql
   (Gmail zip/.js/.sh dosyalarını engeller; zip yerine bu link.)

## Şu an canlıda ne var / test ayarları
- Test için Supabase'de gevşetilmiş kurallar: min_hesap_gun=0, oy_min_kidem=0, oy_il_gun=0, parti_kurucu_sayi=1, parti_kurucu_kidem=0. Gerçek oyuncular gelmeden **sıkı hâle döndür** (önerilen üretim değerleri, 9 Ekim'den beri: min_hesap_gun 3, **oy_min_kidem 3**, oy_il_gun 7 (yalnız il değiştirene uygulanır), parti_kurucu_sayi 5, parti_kurucu_kidem 30; meclis_olcek 0,25; ihmal_gun_atama 3; ihmal_gun_secim 7).
- Supabase Auth: "Confirm email" kapalı (test için). Gerçek oyunculardan önce özel SMTP (Resend/Gmail) kurup tekrar aç.
- Oyun hızı: `oyun.ayarlar.maas_hizi` = 3 (vatandaş maaşı çarpanı; makam maaşları etkilenmez). Ercan SQL ile değiştirebilir: `update oyun.ayarlar set maas_hizi = 4 where id = 1;`
- Yönetici yapmak: `update oyun.profiller set yonetici=true where kad='KullaniciAdi';` Moderatörleri Ercan uygulamadan atar (Ben › Yönetici paneli › Moderatör ekibi).
- 2026.10.07-2 ile gelenler: parti kuruluş ücreti 25.000 ₺ (düşerse yarısı iade), il teşkilatı (aday göstermek için şart; 2.000/4.000/6.000 ₺ parti kasasından), para gönderme (günde 1 asgari ücret), banka (faiz = enflasyon + 5; kredi 7/15/30 gün, gecikmede %1/gün, 3. gün yasal takip ve maaş haczi), moderatör ekibi. Ayarların hepsi yönetici panelindeki "Oyun kuralları" kartında.
- Sonra yapılacaklar: özel SMTP, kuralları sıkılaştırma, Pro plan düşüncesi (önce maliyeti göster), yerel yapıda @capacitor/device eklentisi, mağaza yayını, kumbara artık 16 saat (yasayla 12–24).

## Tanıtım
Twitter flood metni sohbette hazırlandı (12 tweet). Oyun ~1 ay içinde, ilgi yüksek olursa tamamlanıp yayınlanacak.


## 2026-10-07 · 2026.10.07-8 canlı güncelleme
- Siyasi sistem: erken seçim kararı/çağrısı ve TBMM oylaması; parlamenter sistemde hükümet kurma görüşmeleri, koalisyon, dışarıdan destekli azınlık hükümeti, güvenoyu, gensoru ve koalisyon ortağının çekilmesiyle hükümetin düşmesi.
- Anayasa ekranı: hükümet sistemi, seçim barajı, CB görev süresi, milletvekili sayısı, yerel yönetim yetkisi ve erken seçim çoğunluğu gerçek oyun motoruna bağlı.
- Genel seçim barajı %7. İttifak toplamı %7'yi geçerse ittifaktaki partiler barajı geçmiş sayılır.
- Genel seçime katılmak için partinin Türkiye'de en az 1 il teşkilatı yeterli; belediye adaylığı için ilgili il teşkilatı gerekli. Teşkilat taban maliyeti 500'e düşürüldü.
- Vadesiz banka hesabı oyuncular arası transferin tek kanalı oldu: cüzdandan cüzdana havale kaldırıldı, transfer vadesizden vadesize gider.
- Bütün oyuncu transferleri oyun.banka_transfer tablosunda kalıcı kayıtlı. Yönetici panelinde gönderen/alıcı, tutar, açıklama, tarih, iki hesap arasındaki 30 günlük toplam ve bağlı-hesap uyarısı görülebilir/filtrelenebilir.
- Web/GitHub Pages ve uygulama tek dosyası 2026.10.07-8 olarak derlendi. Canlı Supabase migration'ları uygulandı.

## 2026-10-09 · 2026.10.09-2 oyuncu deneyimi + yeni arayüz
- Sunucu (`39_oyuncu_deneyimi.sql`): yeni oyuncu seçmen kartı kolaylığı, Meclis ölçeği, sandık 08–22 / sonuç 22:30 / başvurular 3 gün, hediye sınırı, kumbara 16 saat ve yumuşak seri, görev ihmali, ilk adımlar, tarih arşivi, parti kimliği, portre/biyografi, mitingler. Ayrıntı: TASARIM.md §10.
- Hata düzeltmeleri: genel seçim sayımı ("aday_id is ambiguous" — motoru kilitlerdi), yedekten dönüş (identity sütunları), temiz kurulum.
- Arayüz baştan giydirildi (CSS sistemi, yazı tipi, emoji temizliği); Gündem, Hayat, pusula, sonuç, Partiler, Profil, oyuncu kartı, sohbet, karşılama yeniden düzenlendi.

## 2026-10-09 · 2026.10.09-8 il bazlı emlak + mülk vergisi + 600 sandalye (tek geçerli migration)
- 9 Ekim öğleden sonra aynı istek için ~23 birbirinin yerine geçen deneme migration'ı üretilmişti (çoğu hatalı). Hepsi `migrations/_iptal_20261009/` klasörüne taşındı — **çalıştırılmaz**.
- Tek geçerli dosya: `migrations/20261009_emlak_meclis_son.sql` (= kaynak `43_meclis_salt_cogunluk.sql` + `44_il_emlak_stok_vergi.sql` + `45_emlak_temizlik.sql`). Denemelerden hangisi canlıda çalışmış olursa olsun tetikleyici, fonksiyon ve kural kalıntılarını temizler. `bash gelistirici/test/emlak_gecis.sh` bunu doğrular.
- Emlak: il başına nüfusa (iller.mv) göre sınırlı stok (İstanbul 100 / Bayburt 8 daire), fiyat ve kira il büyüklüğü + gelişmişlik (%60 `il_kalkinma` SEGE'ye yakın kademe, %40 belediye gelişim puanı). Her ilden alınabilir (`mulk_il_satin_al`, `mulk_il_stok`).
- Haftalık mülk vergisi: il rayiç bedeli × `mulk_vergi_ulusal` (yalnız TBMM kanunu; kararname yolu kapalı) × `mulk_vergi_yerel` (belediye başkanı çarpanı). Para mülkün ilinin belediye kasasına (milyar ₺) gider, `emlak_vergi_tahsilat` tablosuna yazılır. Para yetmezse `vergi_borc`; tapu devrinde satıcıdan kesilir.
- Meclis: 600 sandalye seçime açık (`meclis_olcek=0`); kanun kabulü dolu sandalyelerin salt çoğunluğu (11 vekil → 6 evet).
- Arayüz: Hayat'taki yinelenen "Banka" kartı ve Gayrimenkul'deki "Diğer oyuncuların satılık mülklerini gör" düğmesi kaldırıldı; Gayrimenkul ekranında il seçerek alım, vergi ve borç bilgisi var.
- Test: `python3 test/emlak_il.py` (kur_yerel sonrası). Not: `simulasyon`, `guvenlik`, `kalicilik` testleri 41_kurucu_ideoloji'deki "3 kurucu onayı" kuralı yüzünden bu değişiklikten önce de kırıktı (test bakımı gerekiyor).
