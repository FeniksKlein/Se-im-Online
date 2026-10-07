# DEVAM — yeni sohbette önce bunu oku

Sahibi: Ercan (FeniksKlein / Gülveren Games). Kodlama bilmiyor; **her şeyi Türkçe, sade ve adım adım anlat.**
Proje: "Seçim Simülasyonu Online" — çok oyunculu siyaset rol yapma oyunu (tek dosya HTML/JS + Capacitor, Supabase arka uç).

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
2. Yerel Postgres 16'yı aç (soket /tmp), `bash test/hepsi.sh` ile tüm testleri çalıştır (her testten önce veritabanını kendisi kurar; ekonomi3 ve kalicilik dahil), sonra `node test/arayuz.js`.
   Postgres açmak: `su postgres -c "/usr/lib/postgresql/16/bin/initdb -D /tmp/pgdata -A trust -U postgres"` ve `su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /tmp/pgdata -o \"-k /tmp -c listen_addresses=''\" -l /tmp/pg.log start"`.
3. `node build/derle.js` + `bash build/sql_birlestir.sh` → dist üret.
4. Depoya senkronla (supabase-kurulum.sql, docs/index.html, www/index.html, gelistirici/*), commit, `git push origin main`.
5. Ercan'a: raw GitHub linkinden `supabase-kurulum.sql`'i kopyalayıp Supabase SQL Editor'de Run'lamasını söyle (adım adım).
   Link: https://raw.githubusercontent.com/FeniksKlein/Se-im-Online/main/supabase-kurulum.sql
   (Gmail zip/.js/.sh dosyalarını engeller; zip yerine bu link.)

## Şu an canlıda ne var / test ayarları
- Test için Supabase'de gevşetilmiş kurallar: min_hesap_gun=0, oy_min_kidem=0, oy_il_gun=0, parti_kurucu_sayi=1, parti_kurucu_kidem=0. Gerçek oyuncular gelmeden **sıkı hâle döndür** (üretim değerleri: min_hesap_gun 3, oy_min_kidem 10, oy_il_gun 7, parti_kurucu_sayi 5, parti_kurucu_kidem 30).
- Supabase Auth: "Confirm email" kapalı (test için). Gerçek oyunculardan önce özel SMTP (Resend/Gmail) kurup tekrar aç.
- Oyun hızı: `oyun.ayarlar.maas_hizi` = 3 (vatandaş maaşı çarpanı; makam maaşları etkilenmez). Ercan SQL ile değiştirebilir: `update oyun.ayarlar set maas_hizi = 4 where id = 1;`
- Yönetici yapmak: `update oyun.profiller set yonetici=true where kad='KullaniciAdi';` Moderatörleri Ercan uygulamadan atar (Ben › Yönetici paneli › Moderatör ekibi).
- 2026.10.07-2 ile gelenler: parti kuruluş ücreti 25.000 ₺ (düşerse yarısı iade), il teşkilatı (aday göstermek için şart; 2.000/4.000/6.000 ₺ parti kasasından), para gönderme (günde 1 asgari ücret), banka (faiz = enflasyon + 5; kredi 7/15/30 gün, gecikmede %1/gün, 3. gün yasal takip ve maaş haczi), moderatör ekibi. Ayarların hepsi yönetici panelindeki "Oyun kuralları" kartında.
- Sonra yapılacaklar: özel SMTP, kuralları sıkılaştırma, Pro plan düşüncesi (önce maliyeti göster), yerel yapıda @capacitor/device eklentisi, mağaza yayını, kumbara süresi (şu an 8 saat, CB mevzuatla 12'ye çıkarabilir) kararı.

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
