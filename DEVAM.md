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
