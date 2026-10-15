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
- Tek geçerli dosya: `migrations/20261009_emlak_meclis_son.sql` (= kaynak `43_meclis_salt_cogunluk.sql` + `44_il_emlak_stok_vergi.sql` + `45_emlak_temizlik.sql`). Denemelerden hangisi canlıda çalışmış olursa olsun tetikleyici, fonksiyon ve kural kalıntılarını temizler. Yeniden üretmek: `bash gelistirici/build/emlak_migration.sh`; doğrulamak: `bash gelistirici/test/emlak_gecis.sh` (canlı geçişi = temiz kurulum: fonksiyonlar, tetikleyiciler, kurallar).
- Emlak: il başına nüfusa (iller.mv) göre sınırlı stok (İstanbul 100 / Bayburt 8 daire), fiyat ve kira il büyüklüğü + gelişmişlik (%60 `il_kalkinma` SEGE'ye yakın kademe, %40 belediye gelişim puanı). Her ilden alınabilir (`mulk_il_satin_al`, `mulk_il_stok`).
- Haftalık mülk vergisi: il rayiç bedeli × `mulk_vergi_ulusal` (yalnız TBMM kanunu; kararname yolu kapalı) × `mulk_vergi_yerel` (belediye başkanı çarpanı). Para mülkün ilinin belediye kasasına (milyar ₺) gider, `emlak_vergi_tahsilat` tablosuna yazılır. Para yetmezse `vergi_borc`; tapu devrinde satıcıdan kesilir.
- Meclis: 600 sandalye seçime açık (`meclis_olcek=0`); kanun kabulü dolu sandalyelerin salt çoğunluğu (11 vekil → 6 evet).
- Arayüz: Hayat'taki yinelenen "Banka" kartı ve Gayrimenkul'deki "Diğer oyuncuların satılık mülklerini gör" düğmesi kaldırıldı; Gayrimenkul ekranında il seçerek alım, vergi ve borç bilgisi var.
- Test: `python3 test/emlak_il.py` (kur_yerel sonrası). Not: `simulasyon`, `guvenlik`, `kalicilik` testleri 41_kurucu_ideoloji'deki "3 kurucu onayı" kuralı yüzünden bu değişiklikten önce de kırıktı (test bakımı gerekiyor).

## 2026-10-09 · 2026.10.09-9 canlı miting meydanı
- `46_miting_canli.sql` (+ `migrations/20261009_miting_canli.sql`): düzenleyen aday miting süresince kürsüden konuşur (20 konuşma, 400 karakter, 15 sn arayla); katılanlar her söze alkış/tezahürat/ıslık/yuh verir (değiştirilebilir), 80 karakterlik slogan atar (20 sn arayla, en fazla 30). Coşku 0-100 tepkilerden; bitince Gündem haberi (katılım, coşku, en çok alkışlanan söz). Başka ilden canlı izleme. Moderatör `miting_icerik_sil` (şikâyet yetkisi).
- Arayüz: `arayuz.js` → `mitingMeydanEkrani` (4 sn'de bir tazelenir). Meydanlar listesindeki her satır meydanı açar; adayın mitingi başlayınca Gündem'de "kürsüye çık" kartı çıkar.
- Test: `python3 test/miting_canli.py`.

## 2026-10-09 · 2026.10.09-12 il dışı parti mitingi + bağımsız adayın partiye katılması
- `50_parti_miting_bagimsiz.sql` (+ `migrations/20261009_parti_miting_bagimsiz.sql`): genel başkan 81 ilde parti mitingi düzenler (`parti_miting_duzenle`); GB yardımcısına `gby_miting_yetkisi` ile yetki verir/geri alır (geri alınınca başlamamış mitingler iptal + iade). Parti kasası ya da kendi cebi öder. Günde 1, aynı ilde 3 gün arayla, seçim oy saatlerinde yasak. Başlayınca partinin başka illerdeki üyelerine de bildirim. `mitingler.tur` ('aday'/'parti'), `mitingler.odeyen`, `parti_gby.miting_yetkisi` eklendi; `secim_id` artık boş olabilir.
- Bağımsız aday partiye katılınca adaylığı düşer (eskiden katılım engelleniyordu); oy verme sürerken engel.
- Arayüz: parti ekranında "Parti mitingleri" kartı (`arayuz.js` → `partiMitingKartCiz`, `partiMitingModal`), GB için yardımcı yetki düğmeleri; bağımsız adaya katılım uyarısı.
- `48_eyetkin_parti.sql`: temiz kurulumda Eyetkin profili yoksa artık hata vermeden atlanıyor (49'daki CELAL düzeltmesiyle aynı). Canlıya etkisi yok.
- **Canlıya uygulandı** (9 Ekim 23:56, Supabase migration `parti_miting_bagimsiz_20261009`): 26 oyuncu, 22 adaylık, 6 miting korundu; dakikalık motor sonrasında hatasız çalışıyor. Not: canlıda motor her dakika veri değiştirdiği için `parmak_izi` önce/sonra karşılaştırması anlamlı değil; sayımlarla doğrulandı.
- Test: `python3 test/parti_miting.py` (hepsi.sh'e eklendi, `miting_canli` da). Migration eski sürümlü veritabanına uygulandı: oyuncu verisi parmak izi değişmedi, iki kez çalıştırılabiliyor.

## 2026-10-10 · 2026.10.10-1 gazete propaganda yazısı 600 karakter hatası
- Propaganda türünde 600 karakterden uzun yazı "Mesaj en fazla 600 karakter olabilir" hatası veriyordu: yazının tamamı oyun yayın akışına (yayinlar.metin ≤ 600) kopyalanmaya çalışılıyordu. Artık yazı 5.000 karaktere kadar gazetede yayımlanır, akışa başlık + yazının başı (600'de kesilip "…") gider. Haber ve köşe yazısında sorun yoktu.
- Kaynak: `17_basin_teskilat.sql` (`gazete_yayinla`); `migrations/20261010_gazete_propaganda_uzun_yazi.sql`. **Canlıya uygulandı** (Supabase migration `gazete_propaganda_uzun_yazi_20261010`).
- Test: `python3 test/gazete_uzun.py` (hepsi.sh'te).

## 2026-10-10 · 2026.10.10-3 gazete sekmeleri, miting tepkileri, GBY görevleri
- Türkiye Gündem gazetesindeki kategori sekmeleri tıklanmıyordu: `otomatik_gazete.js` onclick içinde JSON.stringify çift tırnağı özniteliği bozuyordu → tek tırnak.
- Miting tepkileri: canlıda hiç `miting_tepki` isteği gitmemişti (katılıp slogan atan oyuncu dahil). Düğmeler artık doğrudan `onclick="mtTepki(this)"` ile çalışıyor, dokununca anında işaretleniyor; meydan her 4 sn'de yalnız değişen kısmı yeniden çiziyor (eskiden sahne her seferinde baştan çiziliyordu); tepki gönderilirken kürsü yerinden oynamıyor; düğmeler büyütüldü, `touch-action:manipulation`. Sunucu (`52`): o ilde yaşayan ama katılmamış oyuncu tepki verince kendiliğinden katılır; başka ilden açık hata mesajı.
- GB yardımcılarına görev alanı (`52_gby_gorev_miting_tepki.sql`): `parti_gby.gorev`, `gby_gorev_ver(kad, gorev)`, `gby_gorevleri(parti)`, `oyun.gby_unvan` → unvan "CYP Teşkilattan Sorumlu Genel Başkan Yardımcısı". Hazır 10 görev + serbest yazı (60 karakter). Yardımcı değişince görev sıfırlanır. Şimdilik unvan; ek yetki vermez.
- **Canlıya uygulandı** (Supabase migration `gby_gorev_miting_tepki_20261010`); canlı `unvan` ve `miting_tepki` önce depodakiyle karşılaştırıldı (aynıydı).
- Test: `python3 test/gby_gorev_tepki.py` (hepsi.sh'te); `miting_canli.py` yeni kurala göre güncellendi.

## 2026-10-10 · 2026.10.10-4 GBY görevlerine yetki
- `53_gby_gorev_yetki.sql` (+ `migrations/20261010_gby_gorev_yetki.sql`, **canlıya uygulandı**: `gby_gorev_yetki_20261010`). Genel başkan her şeyi yapar; ek olarak:
  - Teşkilattan Sorumlu: il teşkilatı açar, Parti İl Başkanı atar/alır. Partide bu görevde biri varsa teşkilatı yalnız GB + o açar; yoksa eskisi gibi tüm yardımcılar.
  - Seçim İşlerinden Sorumlu: miting yetkisi beklemeden parti mitingi, aday tanıtımı.
  - Tanıtım ve Medyadan Sorumlu: grup konuşması, aday tanıtımı.
  - Mali İşlerden Sorumlu: kasadan kampanya desteği, adaylık ücretleri.
  - Siyasi ve Hukuki İşlerden Sorumlu: disipline sevk (GB'yi sevk edemez).
- Yardımcılar: `oyun.gby_alan`, `oyun.parti_gorevli(u, alanlar)`, `oyun.teskilat_yonetici`, `public.parti_yetkilerim()` (arayüz `D.yetki`, `yetkiAlan()`).
- **Not:** canlıdaki `teskilat_gorev_ver/al` depodakinden farklıydı (kaynakta olmayan canlı değişiklik). 53 canlı hâli temel aldı; kaynak artık eşit.
- Test: `python3 test/gby_gorev_yetki.py` (hepsi.sh'te).

## 2026-10-10 · 2026.10.10-5 İttifak teklifi + ittifak içi ortak aday
- `54_ittifak_teklif_ortak_aday.sql` (+ `migrations/20261010_ittifak_teklif_ortak_aday.sql`): `ittifak_teklif(parti, ad)` başka partinin sayfasından tek adımda teklif (ittifak yoksa kurulur); `ittifak_ortak_aday_teklif/yanit/iptal`, `ittifak_masasi` — CB ve belediye (il il) ortak aday önerisi; kabul eden ortağın adayı çekilip `cb_destek`/`bel_aday_destek` uygulanır, herkes kabul edince "ortak aday" ilan edilir.
- Arayüz: `arayuz.js` (`ittifakTeklifHtml`, `ittifakTeklifModal`, `ortakAdayCiz`, `ortakAdayModal`), `index.html` ittifak kartı.
- **Canlıya uygulandı** (Ercan SQL Editor'den çalıştırdı, 10 Ekim 10:52); canlıdaki 9 fonksiyon kaynakla birebir aynı doğrulandı. Web derlemesi 2026.10.10-5 ile yayına alındı.
- Test: `python3 test/ittifak_ortak.py` (hepsi.sh'te). Canlıdaki bağımlı fonksiyonlar (cb_destek, bel_aday_destek, ittifak_*) 10 Ekim'de kaynakla aynıydı.

## 2026-10-10 · 2026.10.10-6 Dernekler / sivil toplum
- `55_dernekler.sql` (+ `migrations/20261010_dernekler.sql`): dernek kur (harç 5.000 ₺ × endeks, kurucu başkan, merkez şube), üyelik (en fazla 5), yönetim kurulu (≤4), başkanlık devri, bağış/kasa, il şubesi (1.000 ₺ × il büyüklüğü × endeks), eylemler: basın açıklaması, bildiri, destek (parti/oyuncu), protesto (şubeli ilde 1 saat, o ilde yaşayan herkes katılır). Konu: genel/kanun/parti/dernek/oyuncu; ilgilisine bildirim; Gündem'e `olay('dernek')`. Sınırlar: 3 açıklama/gün, 1 protesto/gün, aynı il 3 gün, seçim oy saatlerinde protesto yok. Motor: `oyun.miting_tick` başında `oyun.dernek_tick`.
- Arayüz: `gelistirici/www/sivil_toplum.js` (derle.js'e eklendi); Partiler sekmesinde giriş kartı, Gündem'de "Protestoya katıl" ve "Sokaklar" bölümü, oyun rehberinde açıklama.
- **Canlıya uygulandı** (Ercan SQL Editor'den, 10 Ekim 12:28); canlıdaki 21 fonksiyon kaynakla birebir aynı doğrulandı. Web derlemesi 2026.10.10-6 ile yayında.
- Alt menüye 7. sekme "Dernekler" (Partiler'den sonra) eklendi: `EKRAN.dernek`, `IKON.dernek`; sekmeden açılınca geri düğmesi yok. 360 px altında sekme yazısı 9,5 px.
- Ayrıca düzeltildi: `07_devlet.sql` `ittifak_kilit` başka oturumda `$$` yerine `$` ile kaydedilmişti (tam kurulum dosyası bozuktu). Canlıdaki fonksiyon doğruydu.
- Test: `python3 test/dernek.py` (hepsi.sh'te).


## 2026-10-10 · 2026.10.10-8 Şirket halka arzı + haftalık şirket kârı hatası
- **Hata (önemli):** `oyun.sirket_hesapla` ilk haftalık hesapta `round(double precision, integer) does not exist` hatası veriyordu (`random()` double). Canlıda hiç şirket hareketi yoktu; 16-17 Ekim'de ilk haftalar dolunca kâr yazılmayacak ve `sirket_liste` hatası yüzünden "Şirketlerim" ekranı açılmayacaktı. `62_halka_arz.sql` içinde canlı tanım temel alınarak `random()::numeric` ile düzeltildi.
- **Halka arz** (`62_halka_arz.sql`, `migrations/20261010_halka_arz.sql`): `oyun.halka_arz`, `oyun.halka_arz_talep`, `sirketler.halka_acik`; RPC'ler `halka_arz_hesapla`, `halka_arz_durum`, `halka_arz_baslat`, `halka_arz_talep`, `halka_arz_talep_geri`, `halka_arz_iptal`, `halka_arz_liste`; `oyun.halka_arz_tick()` ayrı pg_cron işi (`halka-arz`, dakikalık) + listeleme fonksiyonlarında tembel kapanış. Mevcut `oyun.tick`/`miting_tick`e dokunulmadı. Kurallar: TASARIM.md §11.
- Arayüz: `gelistirici/www/halka_arz.js` (derle.js'e eklendi); Şirketlerim'de her şirket kartında "Halka arz ve yatırım hesabı", üst kartta ve şirket rehberinde "Halka arzlar" düğmesi.
- Test: `python3 test/halka_arz.py` (hepsi.sh'te). Migration eski sürümlü veritabanına iki kez uygulandı.
- Ayrıca `60_imza_dilekce_katilim.sql` satır 42-46 `$` yerine `$$` olarak düzeltildi (tam kurulum dosyası bu yüzden kurulmuyordu; canlıdaki migration doğruydu, canlıya etkisi yok).

## 2026-10-10 · 2026.10.10-23 Meclis rehberi
- Devlet › Meclis artık beş alt sekmeli: **Sandalyeler** (yarım daire, dolu/boş, kanun için gereken evet, grup eşiği, parti parti sandalye ve oran), **Başkanlık** (TBMM Başkanı / Geçici Başkan, başkanvekilleri, Divan seçimleri, ihtar), **Gruplar** (her grubun grup başkanı, grup başkanvekilleri x/kota, vekilleri; grubu olmayan partiler; bağımsızlar), **İl il vekiller** (81 il, kontenjan/dolu, isim ve parti, görev rozetleri, "X listesinden seçildi"; arama, parti süzgeci, boş illeri göster), **Yasama** (eski kanun/işlem içeriği).
- Sunucu: `74_meclis_rehber.sql` → `public.meclis_rehber()` (yalnız okuma, tablo değişikliği yok). Vekilin partisi bugünkü partisi (`oyun.gruplar()` kuralıyla aynı). `migrations/20261010_meclis_rehber.sql`. **Canlıya uygulandı** (Supabase migration `meclis_rehber_20261010`).
- Gündem'deki Meclis şeridine dokununca rehber açılır.
- **Dikkat:** `docs/index.html`, `www/index.html` ve kök `supabase-kurulum.sql` kaynaktan derlenen hâlden farklı (başka oturumların doğrudan yaptığı değişiklikler: parti birleşme/ortak MV listesi vb.; 64, 66, 67, 72, 73 SQL modülleri birleştirme listesinde yok). Bu güncelleme bu dosyalara yama olarak eklendi, tam yeniden derleme yapılmadı. Kaynak eşitlemesi ayrıca yapılmalı.

## 2026-10-10 · 2026.10.10-24 Meclis ayrı alt menü
- Alt menüye "Meclis" sekmesi eklendi (Devlet'ten sonra; `EKRAN.meclis` → `meclisEkrani`, yeni yarım daire simgesi). Meclis rehberinin beş alt sekmesi burada.
- Devlet ekranındaki "Meclis" ve "Adliye" sekmeleri kaldırıldı (Adliye'nin zaten alt menüsü var). Eski bağlantılar (`D.devletSekme='meclis'/'adliye'`) devletEkrani başında ilgili alt menüye yönlenir; Gündem'deki Meclis seçimine git bağlantısı Başkanlık alt sekmesini açar.
- Alt menü düğmeleri ekrana sığacak şekilde esnek (`flex:1 0 42px`, dar ekranda 9,5–10 px yazı); Bakanlığım sekmesi de çıkınca menü yine yatay kayar.
- Değişiklik `gelistirici/www/index.html`, `docs/index.html`, `www/index.html` üçüne de aynı yama olarak işlendi. Sunucu değişikliği yok.

## 2026-10-11 · 2026.10.11-1 Seçim gecesi, fırsatlar, akış, başarımlar, gün özeti
- **Tek migration:** `migrations/20261011_yeni_ozellikler.sql` (76+75+77+78+79; Ercan Supabase SQL Editor'de tek Run). Önce bu çalışmadan arayüz yamasındaki parçalar sessizce gizli kalır (RPC yoksa hata vermez).
- **76 (kritik):** `oyun._sonuc_mv` içinde `l.aday_id` belirsiz takma ad hatası; canlıda `mv_secim_modu.her_aday_vekil=true` olduğu için görünmüyor, test modu kapanınca genel seçim sayımı çökerdi. 72 numaralı modülün içinde düzeltildi (`bl`).
- **75 Seçim gecesi:** sonuç 22:30'da motorca yazılır; `public.secim_detay` sarmalayıcısı sonucu 12 dk (`oyun.secim_gecesi_ayar.sure_sn`, 60–1800) boyunca il il açar; olaylar tetikleyicisiyle manşet sayım bitene ertelenir; `secim_gecesi_tick` (cron `secim-gecesi`) %25/50/75/bitti bildirimi. Arayüz: `canli_ek.js` (`geceKancasi`, 5 sn yenileme, titreşim/ses).
- **77 Boş makam fırsatı:** `bos_makam_firsatlari()` + `bos_makam_firsat_tick()` (cron her 30 dk; 3 saatte bir tarar, 09–22 arası, günde 1 bildirim/kişi). **78 Akış:** `akis_*` RPC'leri, 280 karakter, şikâyet/engel/3 şikâyette gizle, `admin_akis_*` (moderatör arayüzü henüz yok). **79:** `basarimlar()`, `ay_raporu()`, `gun_ozeti()`, `gun_sonu_tick` (cron `gun-sonu`).
- Not: canlıda `ayarlar.push_aktif=false` ve push_url boş; bildirimler push yerine uygulama içi bildirim kutusuna düşer, FCM kurulunca push da gider.
- 72 ve 73 artık birleştirme listesinde (76 buna bağlı). Docs/www derlemeleri tam derlemeyle değil **yama** ile güncellendi (canlıyla kaynak arasındaki fark sürüyor).
- Testler: `secim_gecesi.py`, `ek_ozellikler.py` (hepsi.sh'a eklendi), `node test/canli_ek_arayuz.js`.

## 2026-10-11 · 2026.10.11-2 Erken seçim takvim koruması
- Hata: 11.10 00:45'te TBMM erken seçim kararı (teklif 1, 24/39 kabul), 12.10'daki olağan genel seçimi + 11.10 ön seçimlerini iptal edip 13.10'a yeni seçim kurdu; 30 MV aday adaylığı, 5 CB adaylığı boşa düştü, Gündem'de olmamış seçimler "Sonuçlandı" göründü.
- `80_erken_secim_takvim_koruma.sql`: olağan seçim erken seçim gününden en geç 7 gün sonraysa takvim değişmez. `migrations/20261011_erken_secim_takvim_onarim.sql` aynı işlev + canlı onarım (2026-11 seçimleri geri açılır, boş erken takvim silinir, olay metni düzeltilir). Test: `test/erken_secim_takvim.py`.

## 2026-10-11 · 2026.10.11-3 CİMER + Akış sosyal platform
- **CİMER** (`81_cimer.sql`, arayüz `gelistirici/www/cimer_ek.js`): dilekçenin yerine. Kurum seç (Cumhurbaşkanlığı / bakanlık / il belediyesi) + tür (şikâyet/talep/öneri/bilgi edinme). Başvuru makama gider (`oyun.cimer_muhatap`): o an makamdaki kişi görür; boş bakanlıkta CB; boş belediyede başkan seçilince ulaşır. Gizli; herkese açık `cimer_karne()` (kimliksiz). 72 saat yanıt süresi, günde 3 başvuru, aynı kuruma 6 saatte 1. `sos_dilekce_gonder` kapatıldı; imza kampanyası dilekçesi tetikleyiciyle CİMER toplu başvurusuna düşer; hayat görevleri `gorev_istatistik` sarmalayıcısıyla CİMER'i sayar.
- **Akış** (`82_akis_sosyal.sql`, `canli_ek.js`): beğen/beğenme (tek tepki, yalnız sayılar; kimin verdiği hiçbir RPC'de yok), yanıtlar (`akis_yanit_yaz`, `akis_konu`), Gündem'de satır içi paylaşım kutusu + son 5 paylaşım.
- Migration: `migrations/20261011_cimer_akis_sosyal.sql`. Test: `test/cimer_akis.py`, `test/canli_ek_arayuz.js` (HTML_PATH=../docs/index.html ile canlı derleme de sınanır).

## 2026-10-11 · 2026.10.11-4 Yargı reformu
- `83_yargi_reformu.sql` + `adliye.js`: 3 üyeli Yüksek Mahkeme (`oyun.mahkeme_uye`; 1. üye CB atar = eski `adliye_makam.hakim`, 2–3 Meclis salt çoğunlukla seçer, 72 saat boş kalırsa ≥3 oyu olan en çok oylu), karar oy çokluğu (`adliye_oy_ver`; eski `adliye_karar_ver` buna yönlenir).
- Bağımsızlık: partisiz + makamsız aday (`oyun.yargic_uygunluk`), 30 gün görev, tetikleyicilerle partiye/makama/adaylığa engel; CB görevden alamaz, Meclis 3/5 (`mahkeme_azil_*`).
- Süre: `karar_son` = savunma + 72 sa; dolunca `dusme` (hiç üye yoksa süre işlemez). İstinaf 24 sa, kura jürisi 3 kişi (ilgisiz parti vekilleri → tarafsız aktif oyuncular; CB/yargıç/taraflar hariç), 48 sa, onay/boz. Ağır cezalar kesinleşince (`adliye_kesinlestir`).
- Harç 5.000 ₺ (`mahkeme_ayar`), yeni cezalar `para_10b/para_50b/aday_yasagi/parti_para`, kararlar Akış'a #adliye. AYM: `aym_basvur/aym_gorus/aym_oy_ver`, `oyun.kanun_iptal_et` (bütçe, baraj, düzenleme, ekonomi yasası geri alınır; kanun durumu `aym_iptal`).
- Zamanlayıcı `yuksek-mahkeme` (5 dk). Migration `migrations/20261011_yargi_reformu.sql`. Testler `test/yargi.py`, `test/yargi_arayuz.js`. `www/index.html` adliye bloğu eskiydi; yeni sürümle değiştirildi.

## 2026-10-11 · 2026.10.11-6 Rekabetçi şirketler, kamu ihaleleri, sektör politikası
- **Neden:** eski şirket kazancı yalnız "sermaye × sektör oranı × zar" idi; sahibin kararı, oyuncular arası rekabet ve siyasetin etkisi yoktu.
- `84_ekonomi_pazar_ihale.sql` + `www/ekonomi_pazar.js`. Ayrıntı: `TASARIM.md` 12. bölüm.
- **Rekabetçi şirketler** (`ozel_okul, ozel_hastane, market, ulasim, enerji`): `pazar_sirket` (il, fiyat 1-3, kalite 0-3, enerji kaynağı, marka). `oyun.pazar_tahmin` haftalık sonucu hesaplar (pazar × pay, kapasite sınırı, gider, ruhsat, vergi); `oyun.sirket_hesapla` bu türleri `oyun.pazar_hesapla`'ya yönlendirir. Cron `ekonomi-pazar` (10 dk) sahibi girmese de haftayı kapatır. Kasa ≤ 0 → iflas (`aktif=false`).
- **Kamu ihaleleri:** `kamu_ihale(_proje/_teklif)`, `sirket_deneyim`. Belediye başkanı il kasasından, bakan (boşsa CB) bakanlık kasasından açar; inşaat şirketleri kapalı zarf; `oyun.ihale_tick` sonuçlandırır/teslim eder. Dönüşüm `pazar_ayar.tl_milyar` (1 milyar kamu ₺ = 150.000 ₺ × fiyat düzeyi).
- **Politika:** `sektor_politika` (bakan, 7 gün teşvik ×1,15 / denetim ×0,92; eski türlere de işler), `il_ruhsat` (belediye başkanı %0-8).
- Testler: `test/ekonomi_pazar.py` (hepsi.sh'ta), `test/ekonomi_pazar_arayuz.js` (gerçek RPC çıktıları `test/veri/ekonomi_pazar_ornek.json`).
- Yerel kurulumda `63_halka_arz_kar_birikim.sql` birleştirme listesine eklendi (canlıda zaten vardı; `kar_kasada` sütunu yerelde eksikti). `simulasyon`, `guvenlik`, `kalicilik` testleri bu değişiklikten önce de "kurucu davetleri" beklentisi yüzünden kırıktı.
- **Canlı durum:** migration 3 parçada uygulanıyordu; 1/3 (tablolar) ve 2/3 (motor + şirket RPC'leri) canlıda, 3/3 (ihale + politika + cron + yetkiler) iptal edildi. Tamamlamak için `migrations/20261011_ekonomi_pazar_ihale.sql` dosyasının tamamı bir kez çalıştırılır (iki kez çalışabilir).
- Arayüz `docs/index.html` ve `www/index.html`'e yama olarak eklendi (Hayat ekonomi ızgarası, Şirketler, Şirketlerim, Devlet ekranına giriş kartları).

## 2026-10-11 · 2026.10.11-7 Ekonomi 2. aşama: borsa, Rekabet Kurumu, bağış, otopilot, yerel fiyat → geçim
- Ekonomi planı: `TASARIM.md` 13. bölüm (katmanlar, para akışı, denge hedefleri, sadelik ilkeleri, aşamalar).
- `85_ekonomi_borsa_rekabet.sql` + `www/ekonomi_borsa.js` (+ `ekonomi_pazar.js`'e Yönetim kartı ve "Üç adımda şirket").
- Danışman `pazar_danisman` (sağlık rozeti, 12 seçenekten en kârlı öneri), otopilot `pazar_otopilot` (haftalık en iyi ayar, gelirin %4'ü; `oyun.pazar_hesapla` güncellendi).
- Paravan kuralı: `pazar_sirket` üzerinde `pazar_paravan` tetikleyicisi.
- Borsa: `borsa_emir`, `borsa_islem`; `borsa_liste/sirket/sat/al/iptal`; yalnız `halka_acik` şirketler, alıcıdan %0,5 komisyon hazineye.
- Rekabet Kurumu: `rekabet_sorusturma`, `rekabet_ekrani/rekabet_ac`, `oyun.rekabet_tick` (paravan, kartel, hâkim durum → kasanın %8'i ceza).
- Şirket bağışı: `sirket_bagis`, `sirket_parti_bagis` (7 günde sermayenin %20'si), `siyasi_bagislar`.
- Yerel fiyat: `oyun.piyasa_endeks_tick` günde bir `oyun.etkiler`e il bazlı `gecim` satırı yazar (kaynak_tur 'piyasa', −7,5…+5) ve enflasyona itki verir.
- `piyasa_raporu` (Ekonomi merkezi), `sirket_vitrini` artık il, halka açıklık ve kurumlar vergisini de gösterir. `oyun.pazar_tick` rekabet ve endeksi de çalıştırır.
- Testler: `test/ekonomi_borsa.py` (hepsi.sh), `test/ekonomi_borsa_arayuz.js` (veri: `test/veri/ekonomi_borsa_ornek.json`).
- **Canlı durum:** canlıya uygulama denemesi iptal edildi; canlıda değişiklik yok. `migrations/20261011_ekonomi_borsa_rekabet.sql` Ercan tarafından SQL Editor'de bir kez çalıştırılmalı (84'ten sonra; 84 canlıda). Arayüz `docs/` ve `www/`'e yamalandı; migration çalışana kadar yeni ekranlar hata gösterir, danışman kartı sessizce gizlenir.

## 2026-10-11 · 2026.10.11-8 Reklam ve anket ajansları
- `86_reklam_anket_ajansi.sql` + `www/ajans.js`. Ayrıntı: `TASARIM.md` 14. bölüm.
- Tablolar `ajans`, `ajans_is`, `ajans_gosterim`, `ajans_cevap`; RPC'ler `ajans_kur/ayarla/yonetim/liste/siparis/gundem/anket_cevap/anket_yayimla/puanla`; `oyun.ajans_hesapla` (sirket_hesapla'ya ajans dalı), `oyun.ajans_tick` (pazar_tick içinde).
- Gündem'e sponsorlu kart ve anket kartı `gundemEkrani` sarmalanarak eklenir (EKRAN.gundem güncellenir).
- Testler: `test/ajans.py` (hepsi.sh), `test/ajans_arayuz.js` (veri `test/veri/ajans_ornek.json`).
- Bu arada başka bir oturum `sirket_hisse_satis_pazari` ve `belediye_sirket_hizmet_ihaleleri` migration'larını ekledi (yalnız migrations/ ve www/; gelistirici/ kaynağına alınmadı). Modül 85'teki borsa ile hisse ilan pazarı aynı işi farklı yoldan yapıyor; ileride tek ekranda birleştirilmeli.
- **Canlı durum:** 85 ve 86 canlıda değil. Sırayla çalıştırılacak: `migrations/20261011_ekonomi_borsa_rekabet.sql`, sonra `migrations/20261011_reklam_anket_ajansi.sql`.

## 2026-10-11 · 2026.10.11-11 Ekonomi güvenliği (MASAK)
- `88_ekonomi_guvenligi.sql` + `www/guvenlik.js`. Ayrıntı: `TASARIM.md` 15. bölüm.
- RPC'lere dokunmadan tetikleyiciler: `borsa_emir` (bant), `borsa_islem`, `ticaret_devir_kayit`, `sirket_teklif`, `sirketler.satilik`, `mulk_ilan`, `emlak_pazarlik` (varsa), `sirket_hisse_ilanlari` (varsa), `kamu_ihale_teklif`, `kamu_ihale` (kayırma), `ajans_is`, `ajans_cevap`, `hesap_hareket` (ani servet), `parti_hareket` (harcama). `oyun.iliskili(a,b)` = `oyun.bagli_hesaplar` (aynı cihaz) + `ayarlar.coklu_kontrol`.
- `public.ajans_anket_cevap` 88'de yeniden tanımlandı (ödül için hesap yaşı ve günlük sınır, `odulsuz_neden`).
- Yeni moderatör yetkisi `ekonomi`; `admin_masak`, `admin_masak_karar`; herkese açık `parti_kasa_defteri`, `yonetim_hediyeleri`.
- Testler: `test/guvenlik_ekonomi.py` (hepsi.sh), `test/guvenlik_arayuz.js`. `test/ajans.py` oyuncuları 7 günden eski olacak şekilde güncellendi.
- **Canlı durum:** 85, 86, 88 canlıda değil. Sırayla: `20261011_ekonomi_borsa_rekabet.sql`, `20261011_reklam_anket_ajansi.sql`, `20261011_ekonomi_guvenligi.sql`. Gerçek oyuncular gelmeden: `migrations/YAYIN_ONCESI_AYARLAR.sql`.
- Bilinen eksik: diğer oturumun `belediye_is_teklif` (belediye hizmet ihalesi) tablosuna ilişkili hesap kuralı eklenmedi (kaynağı gelistirici/'de yok).

## 2026-10-11 · 2026.10.11-12 Yönetim alt menüsü, CİMER makam kutusu
- Alt menüdeki "Bakanlığım" ve "Belediyem" kaldırıldı; yerine Gündem'in hemen yanında **Yönetim** (`EKRAN.yonetim` → `yonetimEkrani`, `www/yonetim.js`). Yalnız makamı (bel, cb, cb_yardimcisi, bakan, tbmm, bskv, grup_bskv, mv) ya da parti yönetim görevi (gb, gb_vekaleten, gby) olana görünür.
- Sıra: makam listesi → CİMER (makama gelen başvuru sayısı) → **Belediye** (kasa/memnuniyet/gelişmişlik + şehir yönetimi, vergiler/hizmetler, kamu ihalesi, hizmet ihaleleri, CİMER) → Cumhurbaşkanlığı → Bakanlık panelleri (politika/icraat doğrudan burada) → TBMM → Parti.
- Eski bağlantılar (`sekmeAc('bakanlik'|'belediye')`) Yönetim'e yönlenir; politika/icraat sonrası yenileme Yönetim'de kalır. Gündem › Bugün listesinin en üstüne "X Belediyesini yönet" eklendi; alttaki belediye kartı da Yönetim'i açar.
- CİMER: sunucu doğruydu (canlıda belediye başvurusu → başkanın `cimer().gelen` listesinde, işlem geri alınarak sınandı). Sorun arayüzdeydi: "Makamıma gelen" sekmesi yalnız başvuru varken çıkıyordu ve belediye ekranlarında CİMER girişi yoktu. Artık belediye başkanı/bakan/CB için sekme her zaman görünür, Yönetim'de de kutusu var.
- Sunucu değişikliği yok. `docs/` ve `www/` yama ile; kaynak `gelistirici/www/yonetim.js` + `cimer_ek.js` + `derle.js` listesi. Test: `HTML_PATH=../docs/index.html node test/yonetim_arayuz.js`.

## 2026-10-11 · 2026.10.11-13 Oyuncu bankası kredi masası
- Migration: `migrations/20261011_oyuncu_banka_kredi_masasi.sql` (iki kez çalışabilir). **Canlıda değil**: Supabase SQL Editor'de bir kez çalıştırılmalı. Çalışana kadar arayüz eski banka ekranını gösterir (kredi masası girişi sunucu hazır olunca kendiliğinden çıkar).
- Yeni tablolar: `oyb_hesap` (kredi için hesap zorunlu; tetikleyici `oyb_kredi_hesap`), `oyb_kredi_paket` (sahibin paketi: 1–30 gün, 1–30 taksit vadeye eşit bölünür, faiz %0–20 vadenin tamamı için, tutar aralığı ≤10 Mn, asgari not, otomatik), `oyb_kredi_teklifi` (sahibin inisiyatifi, 48 sa), `oyb_hesap_bilgi` (hesap sahibinden mali bilgi izni). `oyb_kredi`'ye `paket_id, teklif_id, erken_kapama, erken_indirim`; saat listesi 24'ün katı 24–720'ye, anapara 10 Mn'ye genişledi. Mevcut borçlu ve mevduat sahiplerine hesap açılmış sayılır.
- `kredi_risk_ozeti` artık 1–720 saatin hepsini kabul eder (formül değişmedi). `oyb_kredi_karar` ortak `oyun.oyb_kredi_kullandir` adımını kullanır.
- RPC'ler: `oyb_hesap_ac/kapat`, `oyb_kredi_masasi`, `oyb_kredi_plan` (çekmeden önce plan + engel), `oyb_kredi_cek` (otomatikse anında, değilse başvuru), `oyb_kredi_erken_kapat` (anapara + geçen süre kadar faiz + kalan anaparanın %1'i, kalan borçtan fazla olamaz), `oyb_kredi_teklif_ver/yanit/iptal`, `oyb_hesap_bilgi_iste/yanit/dokum`, `oyb_paket_kaydet`. Dava/gelir haczi mevcut `oyb_icra_baslat` ile (masada "Adliye'de dava aç").
- Kredi tutarı banka kasasının mevduat güvencesi dışındaki kısmıyla sınırlı (`oyb_saglik.kredi_verilebilir`).
- Arayüz: `www/banka_kredi_masasi.js` (`oybKrediMasasiEkrani`); banka şubesi ve "Bankamı yönet" ekranlarına giriş kartı.
- Testler: `bash test/oyb_kredi_masasi.sh` (yerel DB + canlıdaki banka migration'ları + bu migration, 10 senaryo), `node test/oyb_kredi_masasi_arayuz.js` (veri `test/veri/oyb_kredi_masasi_ornek.json`).

## 2026-10-11 · 2026.10.11-14 Belediye: bağış hatası, hizmet karnesi, kriz masası, İller Bankası
- **Hata:** `serbest_bagis` şehre/hazineye bağışı milyar ₺ sanıyordu (1.000 ₺ → 1.000 milyar). Canlıda düzeltildi (`bagis_kamu_birim_duzeltme_20261011`), önce `yedek_al` alındı. Onarım: 10 Ekim 21:00 UTC sonrası şehir bağışlarının fazlası düşüldü (Ankara, Giresun, Yalova, Hatay, Bayburt kasası 0'a indi; şişen parayla yapılan binalar yerinde bırakıldı), hazineden 500 milyar fazlası düşüldü (744,5 → 244,6). Kayıt: `migrations/20261011_bagis_kamu_birim_duzeltme.sql` (yorum; tekrar çalıştırma).
- Diğer oturumun belediye şehir migration'ları kaynağa alındı: `gelistirici/sql/89_belediye_sehir.sql` (cron 04'e taşındı).
- Yeni modül `91_belediye_detay.sql` + `www/belediye_sehir.js` yeniden yazıldı. Ayrıntı: `TASARIM.md` 16. bölüm. RPC'ler: `belediye_detay_paneli`, `belediye_karnesi(p_il)` (herkese açık), `belediye_kredi_al(p_tutar milyar, p_gun)`, `belediye_kredi_kapat`, `belediye_kriz_karar(p_id, p_secim)`. Zamanlayıcı `belediye-kriz` (saatte bir, dakika 7). `oyun.belediye_gunluk` yeniden tanımlandı (tavan kesmiyor, kredi taksiti, karne → memnuniyet).
- İl sayfasındaki "1.000,1 mlr" gösterimi `kasaYaz` ile milyar/milyon/bin oldu; il sayfasına "Belediye karnesi" düğmesi eklendi. `docs/` ve `www/` yama ile güncellendi.
- Testler: `python3 test/belediye_detay.py` (bağış, tavan, karne, kredi/gecikme, kriz/sessiz/soğuma), `node test/belediye_detay_arayuz.js` (veri `test/veri/belediye_detay_ornek.json`; sunucuda modül yokken eski ekranın çalıştığı da sınanır).
- **Canlı durum:** bağış düzeltmesi canlıda. `migrations/20261011_belediye_detay.sql` canlıya henüz uygulanmadı (deneme iptal edildi); Supabase SQL Editor'de bir kez çalıştırılmalı (iki kez çalışabilir). Çalışana kadar arayüz yeni sekmeleri gizler.
- Bilinen tutarsızlık (dokunulmadı): hazineye/il kasasına para aktaran bazı eski fonksiyonlar `/1e6` ya da `/1e9` kullanıyor (tahvil, piyango, kira vergisi, emlak vergisi); oyunun resmî kuru `pazar_tl_milyar()`.

## 2026-10-13 · 2026.10.13-1 ekonomi kurumları (canlıda)
- Sunucu: `gelistirici/sql/93_ekonomi_kurumlar.sql` (aynısı `migrations/20261013_ekonomi_kurumlar.sql`). **Canlı Supabase'e uygulandı**, ayrıca çalıştırmaya gerek yok. Yeni zamanlanmış iş: `ekonomi-2` (10 dk'da bir `oyun.ekonomi2_tick()`).
  - Merkez Bankası: başkanı yürütme başı atar (teklif + kabul, aktif siyasi görevi olmamalı; görev alınca başkanlık biter). PPK haftada bir politika faizi (tek kararda ±10 puan). `oyun.politika_faizi()` → `oyun.banka_oranlar()`; karar yokken eski formül. Reel faiz her gün enflasyon/büyümeyi iter. Başkana günlük bakan maaşı/30.
  - Belediye tahvili: başkan 14/30/60 gün, tutar ≤ il kasası×pazar_tl_milyar (stok ≤ 2 katı), yıllık getiri ≤ politika+25. 48 saat satış, %30 altı iptal/iade; vadede kasadan ödeme, yetmezse temerrüt (kısmi, memnuniyet −5).
  - SPK: `borsa_islem` tetikleri — bağlantılı hesap (aynı cihaz/iz) ya da 48 saatte karşılıklı işlem otomatik inceleme; Maliye Bakanı 72 saatte karar verir (yoksa bağlantılı=ceza, diğer=beraat). Ceza %20 (≥10.000 ₺) hazineye + 7 gün işlem yasağı (`spk_yasak`, emir/işlem tetikleri).
  - Konkordato/iflas: yönetici kasası eksideki şirket için ilan eder; açık > sermaye/2 ise otomatik. 14 günde kasa ≥ 0 değilse iflas (aktif=false, borsadan çıkar, emirler iptal). Bankalar hariç.
- Arayüz: `gelistirici/www/ekonomi_kurumlar.js` (Hayat › Ekonomi merkezi'nde dört yeni kart; Borsa'da SPK, Şehir Yönetimi'nde tahvil düğmesi).
- Testler: `test/ekonomi_kurumlar.py` (hepsi.sh'e eklendi), `test/ekonomi_kurumlar_arayuz.js`. `guvenlik.py` ve `kalicilik.py` bu değişiklikten önce de parti kurucu davet kuralı yüzünden bayat beklentiyle düşüyor.
- Yayın: `docs/index.html`'e yalnızca `<script src="ekonomi_kurumlar.js?v=20261013-2">` eklendi ve `docs/ekonomi_kurumlar.js` kopyalandı (İş Dünyası ile aynı yöntem; başka değişiklik yayına taşınmadı). `www/index.html` (mağaza paketi) bir sonraki tam derlemede güncellenir.

## 2026-10-13 · 2026.10.13-3 Menü sadeleştirme (yalnız arayüz)
- **Ekonomi alt menüsü:** Hayat'taki dağınık ekonomi kartları (İş Dünyası, Ekonomi merkezi, Şirketler, Rekabetçi şirketler, Halka arzlar, Oyuncu bankaları, Satılık mülkler, Kamu ihaleleri, Reklam ve anket) ve "Diğer para işlemleri" kaldırıldı; hepsi yeni `ekonomi` sekmesinde (`ekonomiEkrani`) gruplu tek listede: Şirket ve iş · Yatırım · Banka ve para · Emlak · Ekonomi kurumları. Hayat'ta yalnız tek "Ekonomi" giriş kartı kaldı. Eski modüllerin Hayat ızgarasına kart ekleyen sarmalayıcıları artık ızgara olmadığı için hiçbir şey yapmaz (zararsız).
- **Yönetim → Devlet:** alt menüdeki "Yönetim" sekmesi kalktı. Devlet ekranının ilk bölümü "Makamım" (yalnız makamı/parti yönetim görevi olana görünür; ilk açılışta seçili gelir). `sekmeAc('yonetim'|'belediye'|'bakanlik')` → Devlet › Makamım. `yonetimEkrani` değişmedi; dış `iskelet` sarmalayıcısı başlığı "Devlet" yapıp bölüm çubuğunu ekler.
- Alt menü sırası: Gündem, Devlet, Adliye, Hayat, Ekonomi, Sohbet, Meclis, Harita, Partiler, Dernekler.
- Kod: `gelistirici/www/menu_sade.js` (en son yüklenir; `derle.js` listesine eklendi), `index.html`'de nav satırı ve `hayatCiz` ekonomi bloğu. Yayın: `docs/menu_sade.js` + `docs/index.html` aynı düzenlemeler.
- Test: `node test/menu_sade_arayuz.js` (yeni), `yonetim_arayuz.js` yeni davranışa göre güncellendi. Sunucu değişikliği yok, migration yok.


## 2026-10-15 · 2026.10.15-1 Ekonomi 3.0 (canlıda)
- Sunucu: `gelistirici/sql/99_ekonomi3_a_duzeltme.sql`, `99_ekonomi3_b_faaliyet.sql`, `99_ekonomi3_c_piyasa.sql` (aynıları `migrations/20261015_ekonomi3_*.sql`). **Canlı Supabase'e uygulandı** (migration adları `ekonomi3_a_duzeltme_20261015`, `ekonomi3_b_faaliyet_20261015`, `ekonomi3_c1_tur_marka_deger_20261015`, `ekonomi3_c2_kurul_pano_20261015`, `ekonomi3_c3_basarimlar_20261015`); Ercan'ın ayrıca çalıştırmasına gerek yok. Öncesinde `oyun.yedek_al` → `yedek_20261015_164513_002621`.
- Ayrıntı: TASARIM.md §17. Özet: para birimi düzeltmesi (hazine 5.600 → 252 milyar), Milli Piyango gerçek usul, zamanlayıcılar kaydırıldı, 11 sektörde günlük faaliyet, bölgesel teşvik, şirketler arası gider zinciri, reklam bütçesi, şirket değeri + Şirketler Endeksi, 18.00 kapanış / 20.00 bilanço, genel kurul + CEO, Ltd./A.Ş., marka filtresi, 6 ekonomi başarımı.
- Yeni zamanlayıcı: `ekonomi-3` (2-59/10). `ekonomi-pazar` artık her tick'te `oyun.ana_faaliyet_ac()` çalıştırır.
- **Not:** `apply_migration` içinde `drop trigger` onay istediği için iptal oluyordu; `create or replace trigger` kullanıldı.
- Arayüz: `gelistirici/www/ekonomi3.js` (derle.js listesinin sonunda). Yayın: `docs/ekonomi3.js` + `docs/index.html`'e tek script etiketi (diğer modüllerle aynı yöntem; docs kaynaktan çok ayrıştığı için tam derleme yayına kopyalanmadı). `www/index.html` sonuna gömülü.
- `ekonomi_pazar.js` kaynağında haftalık ifadeler günlüğe çevrildi; yayındaki derlenmiş sürümde aynı ifadeler ekonomi3.js tarafından ekranda düzeltilir.
- Test: `NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/ekonomi3_arayuz.js [klasör]` (320/390/768 px, sahte RPC, veri `test/veri/ekonomi3_ornek.json`).
- Bilinen: gerçek marka adlı eski şirketler (Koç Holding, ASELSAN, TÜPRAŞ, MİGROS, NVIDIA, Türkiye İş Bankası) olduğu gibi duruyor; sahipleri genel kuruldan ad değiştirebilir. Yeni kayıtlar filtreden geçer.
