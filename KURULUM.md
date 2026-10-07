# Seçim Simülasyonu Online — Kurulum Rehberi

Bu paketle hazır olanlar:
- Kayıt, giriş ve il seçimi.
- Parti kurma ve partiye katılma.
- Tüm seçimler: belediye, kurultay, vekil ön seçimi, genel seçim, cumhurbaşkanlığı ve 2. tur.
- Makamlar: cumhurbaşkanı, 12 bakanlık kabine, genel başkan ve 6 yardımcısı, vekiller, belediye başkanları.
- Devlet yönetimi: ülke karnesi, bakanlık icraatları, kanun süreci (oylama, onay, veto, ısrar), cumhurbaşkanlığı kararları, ittifaklar ve Resmî Gazete.
- Vatandaş ekonomisi: maaş kumbarası, günlük seri, statü ve kıdem primi, gerçek oranlarda makam maaşları, ödüllü reklam ve ₺ paketi satışı; hükümetin ekonomi masası, bütçe kanunu, belediye hizmetleri ve bakanlık icraatlarının oyunculara etkisi; aday ücretleri, taşınma masrafı, parti kasası; bütçeyle hesaplanan ölçülebilir vaatler (her bakanlık icraatı, vekillik ve genel başkanlık için ayrı vaat türü) ve vaat karnesi; tutulan vaadin kıdem puanı ve itibar karşılığı (Sözünün Eri / Lafta Kalan); şehir kalkınma bağışı ve verginin nereye gittiğini gösteren vergi karnesi; boş makam kuralı (bakanlıkta cumhurbaşkanı vekâleti, aday çıkmazsa görevdekinin devamı, genel başkansız parti kalmaması) ve Boş Makamlar panosu; mevzuat (servet vergisi, oy cezası, hoş geldin hibesi, siyasi katılım fonu, devamsızlık kesintisi…) ile Anayasa › Kanun › Kararname hiyerarşisi, özelleştirme ve tahvil, anayasa değişikliği ve gizli oylu halk oylaması (il il sonuç), belediye meclisi kararları (emlak vergisi, hoş geldin desteği, imar barışı, arsa ihalesi ve kira geliri veren mülkler), bakan arama listesi; TBMM Başkanlık Divanı (4 turlu gizli oyla Meclis Başkanı, başkanvekilleri, grup başkanvekilleri, grup kararı, Genel Kurul'da ihtar) ve Meclis grubu / Başkanlık Divanı sohbetleri; çoklu hesaba karşı cihaz ve bağlantı izi, seçmen kartı (oy ve adaylık şartları), cihaz başına tek oy, tek kullanımlık e-posta engeli, yönetici şüpheli hesap paneli; kurucu üyeli parti kuruluşu.
- Belediye hizmetleri, adayların seçim bildirgeleri, rozetler, yönetici paneli ve telefona gelen bildirimler (push).
- Sohbet: Türkiye Meydanı, il kahvesi, belediye meclisi, parti, parti yönetim kurulu, ittifak, TBMM Genel Kurulu ve Bakanlar Kurulu kanalları (okunmamış sayacı, kilitli kanal bilgisi); özel mesaj, propaganda yayınları ve bildirimler.
- Şikâyet etme ve engelleme.
- Harita ve Meclis ekranları.

Oyunun bütün kuralları ve sunucunun nasıl çalıştığı **TASARIM.md** dosyasında.

## Paketteki dosyalar

| Dosya | Ne işe yarar |
|---|---|
| `TASARIM.md` | Oyunun kuralları, makamlar, sohbet/propaganda ve sunucunun nasıl çalıştığı |
| `supabase-kurulum.sql` | Sunucunun tamamı: tablolar, 81 il, seçim motoru, uygulama fonksiyonları, zamanlayıcı. Supabase'e bir kez yapıştırılır. |
| `www/index.html` | Telefon uygulaması (tek dosya). Capacitor'ın `www` klasörüne konur. |
| `push-gonder.ts` | Telefona bildirim gönderen sunucu fonksiyonu (9. bölüm). Supabase'e yapıştırılır. |
| `odeme-webhook.ts` | Mağaza ödemesini cüzdana ekleyen sunucu fonksiyonu (10. bölüm). Supabase'e yapıştırılır. |
| `gelistirici/` | Kaynak parçalar ve testler. Sonraki aşamalarda bana geri gönderirsin; senin dokunman gerekmez. |

---

## 1) Supabase projesi aç (5 dk)

1. **supabase.com** → *Start your project* → GitHub veya e-postayla giriş yap.
2. *New project*:
   - **Name:** `secim-online`
   - **Database Password:** güçlü bir şifre üret ve bir yere kaydet.
   - **Region:** *Central EU (Frankfurt)*. Türkiye'ye en yakın bölge bu.
3. Projenin hazırlanmasını bekle (1-2 dk).

## 2) Sunucuyu kur (2 dk)

1. Soldaki menüden **SQL Editor** → **New query**.
2. `supabase-kurulum.sql` dosyasını bilgisayarında bir metin düzenleyiciyle aç, **tamamını** kopyala, buraya yapıştır.
3. Sağ alttaki **Run** düğmesine bas. "Success" görmelisin.
   - `pg_cron` ile ilgili bir hata görürsen: **Database → Extensions** sayfasında `pg_cron`'u bulup aç, sonra dosyayı tekrar çalıştır. Dosyayı tekrar çalıştırmak güvenlidir.
4. Kontrol: SQL Editor'da yeni bir sorgu aç ve şunu çalıştır:
   ```sql
   select tur, donem, oy_bas at time zone 'Europe/Istanbul' as oylama from oyun.secimler order by oy_bas;
   ```
   Yaklaşan seçimlerin listesini görmelisin. Seçim saati her dakika kendiliğinden işler, senin bir şey yapmana gerek yok.

## 3) Giriş ayarları (5 dk)

**Authentication → Sign In / Providers → Email:**
- *Enable Email provider*: **açık**
- *Confirm email*: **açık**
- *Minimum password length*: **8**

**Authentication → Emails (Email Templates):** Uygulama bağlantı yerine **6 haneli kod** kullanıyor. Bu yüzden iki şablonu değiştirmen gerekiyor.

*Confirm signup* şablonu:
- Subject: `Seçim Simülasyonu Online doğrulama kodun`
- Body:
```html
<h2>Hoş geldin!</h2>
<p>Hesabını doğrulamak için bu kodu uygulamaya yaz:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
<p>Bu işlemi sen yapmadıysan bu e-postayı yok sayabilirsin.</p>
```

*Reset Password* şablonu:
- Subject: `Şifre yenileme kodun`
- Body:
```html
<p>Şifreni yenilemek için bu kodu uygulamaya yaz:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
<p>Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin.</p>
```

> ⚠️ **E-posta gönderimi:** Supabase'in kendi e-posta sunucusu yalnızca deneme içindir ve saatte çok az e-posta gönderir. Gerçek oyuncular gelmeden önce kendi e-posta servisini bağlamalısın. Örneğin Resend'in ücretsiz planı ayda 3.000 e-posta gönderiyor ve bir alan adı (domain) gerektiriyor. Bağlantıyı **Project Settings → Authentication → SMTP Settings** sayfasından yaparsın. Bu adımda takılırsan birlikte yaparız.

## 4) Anahtarları uygulamaya gir (1 dk)

1. **Project Settings → API** (veya *Data API*) sayfasında şu iki değeri kopyala:
   - **Project URL** (`https://xxxx.supabase.co`)
   - **anon public** anahtarı (uzun bir metin)
2. `www/index.html` dosyasını aç. En üstteki **AYARLAR** bölümünde üç satırı doldur:
   ```js
   SUPABASE_URL:  "https://xxxx.supabase.co",
   SUPABASE_ANON: "eyJhbGciOi....",
   ILETISIM:      "senin-destek-adresin@...",
   ```
   *anon* anahtarı herkese açık olacak şekilde tasarlanmıştır, uygulamada durması güvenlidir. Oyunun tabloları dışarıya kapalıdır; oyuncular yalnızca giriş yapınca ve oyunun kurallarına uyan işlemleri yapabilir. **service_role** anahtarını ise hiçbir zaman uygulamaya koyma.

## 5) Dene

- `www/index.html` dosyasını bilgisayarında Chrome ile aç. Kayıt ol, e-postana gelen kodu gir, il seç.
- Telefona koymak için yeni bir Capacitor projesi aç (mevcut oyunun projesinden ayrı):
  - appId önerisi: `com.feniksklein.secimonline`
  - `index.html`'i `www` klasörüne koy → `npx cap sync` → her zamanki gibi Xcode/Android Studio.
- Uygulama internetsiz açılmaz. Bu durumda "İnternet gerekli" ekranı çıkar.

## 6) Yönetici komutları (SQL Editor'da)

| Ne yapmak istiyorsun | Komut |
|---|---|
| İlk gün herkes hemen oy verebilsin (normalde hesap 3 günlük olmalı) | `update oyun.ayarlar set min_hesap_gun = 0;` |
| Kuralı geri al | `update oyun.ayarlar set min_hesap_gun = 3;` |
| Barajı değiştir (örn. %5) | `update oyun.ayarlar set baraj = 5;` |
| Oyuncu sayısı | `select count(*) from oyun.profiller;` |
| Hesapların hepsi gerçek mi? (bot ya da test hesabı olmamalı) | `select count(*) from oyun.profiller where kad like 'Bot\_%';` → 0 olmalı |
| Bir oyuncuyu oyundan at | `delete from auth.users where email = 'kisi@ornek.com';` |
| Zamanlayıcı çalışıyor mu? | `select status, start_time from cron.job_run_details order by start_time desc limit 5;` |
| Son haberler | `select zaman, metin from oyun.olaylar order by zaman desc limit 20;` |
| Bir oyuncuyu 7 gün sustur | `update oyun.profiller set susturma_bitis = now() + interval '7 days' where kad = 'KullaniciAdi';` |
| Hazineye para ekle veya çıkar (milyar ₺) | `update oyun.ulke set hazine = hazine + 50;` |
| Ülke göstergelerini gör | `select * from oyun.ulke;` |
| Susturmayı kaldır | `update oyun.profiller set susturma_bitis = null where kad = 'KullaniciAdi';` |
| Bir sohbet mesajını gizle | `update oyun.mesajlar set gizli = true where id = 123;` |
| Şikâyetleri incelendi say | `update oyun.sikayetler set durum = 'incelendi' where durum = 'yeni';` |
| Bir oyuncunun cüzdanını gör | `select c.* from oyun.cuzdan c join oyun.profiller p on p.id = c.user_id where p.kad = 'KullaniciAdi';` |
| Son satın almalar | `select * from oyun.satin_almalar order by zaman desc limit 20;` |
| Ülke ekonomisini gör (asgari ücret, vergi, destekler) | `select asgari, vergi, vergi_alt, vergi_ust, kidem_primi, destek, tasinma_destek, belediye_payi, parti_yardim, endeks from oyun.ulke;` |

**Yeni şikâyetleri görmek için** (Apple, şikâyetlere 24 saat içinde bakılmasını istiyor):
```sql
select s.zaman, s.tur, s.neden, h.kad as sikayet_edilen, coalesce(m.metin, y.metin, o.metin) as icerik, s.kayit_id
from oyun.sikayetler s
join oyun.profiller h on h.id = s.hedef_user
left join oyun.mesajlar m on s.tur = 'mesaj' and m.id = s.kayit_id
left join oyun.yayinlar y on s.tur = 'yayin' and y.id = s.kayit_id
left join oyun.ozel o on s.tur = 'ozel' and o.id = s.kayit_id
where s.durum = 'yeni' order by s.zaman desc;
```

## 7) Canlıya çıkmadan önce

- [ ] Kendi e-posta servisini (SMTP) bağla.
- [ ] Canlıya çıkmadan **yalnızca** `supabase-kurulum.sql`'i çalıştır. `gelistirici/sql/90_test_botlar.sql` test içindir; canlı projeye yapıştırma. Canlıda test saati kapalı olmalı: `select test_simdi from oyun.ayarlar;` → boş (null) gelmeli.
- [ ] Supabase'i **Pro** plana geçir (ayda yaklaşık 25$). Ücretsiz projeler bir süre kullanılmazsa durdurulabilir ve yedekleme sunmaz.
- [ ] Gizlilik/KVKK metnini bir hukukçuya okut. Metin uygulamada **Ben → Gizlilik ve KVKK** sayfasında.
- [ ] App Store (Kural 1.2) için gerekenler:
  - Şikâyet et / engelle: **hazır**.
  - Hesap silme: **hazır**.
  - Mağaza sayfasında bir **iletişim e-postası** olmalı.
  - Şikâyetlere **24 saat içinde** bakmalısın. Sorgu yukarıdaki yönetici komutlarında.
- [ ] Reklam: `AYAR` içinde kendi AdMob birimlerini yaz, `ADMOB_TEST: false` yap. iOS'ta kişiselleştirilmiş reklam için App Tracking Transparency izni ve AdMob'un gizlilik mesajı (Avrupa için onay formu) gerekir; AdMob panelindeki *Gizlilik ve mesajlar* bölümünden açılır.
- [ ] Satın alma: App Store ve Google Play'deki ürün açıklamalarında "oyun içi para, gerçek paraya çevrilemez" yaz. App Store'un incelemesi için bir Sandbox satın almanın çalıştığından emin ol.

## 8) Kendini yönetici yap

Uygulamada kayıt olup kullanıcı adını aldıktan sonra SQL Editor'da şunu çalıştır:
```sql
update oyun.profiller set yonetici = true where kad = 'KullaniciAdin';
```
Bundan sonra **Ben → Yönetici paneli** açılır. Panelde şunları yapabilirsin:
- Şikâyetleri görüp karar vermek: sorun yok, gizle, 1 ya da 7 gün sustur, hesabı kapat.
- Oyuncu aramak (e-posta adresi yalnızca sana ve "E-posta görme" yetkisi verdiğin moderatöre görünür).
- Tüm oyunculara duyuru göndermek.
- Oyun kurallarını ayarlamak: hesap yaşı, oy ve parti kurma şartları, parti kuruluş ücreti, il teşkilatı bedeli ve şartı, para gönderme sınırı, banka faizi ve tavanı, bankayı açıp kapama.
- **Moderatör ekibi kurmak:** "Moderatör ekibi" kartında **+ Moderatör ekle** → kullanıcı adını yaz → yapabileceği işleri tek tek işaretle → Kaydet. Yetkileri sonradan "Yetkileri düzenle" ile değiştirir, "Görevden al" ile kaldırırsın. Moderatörler panele **Ben › Moderatör paneli**'nden girer, yalnızca verdiğin işleri yapabilir ve sana ya da birbirlerine işlem yapamaz.
- **Moderasyon günlüğü:** Kimin, ne zaman, kime ne yaptığını gösterir. Yalnızca sen görürsün.

## 9) Telefona gelen bildirimler (push)

Bu bölüm isteğe bağlı; push kurulmadan da oyun çalışır, bildirimler uygulamanın içindeki zil ikonunda görünür. Push için Google'ın ücretsiz Firebase hizmeti kullanılıyor. iPhone bildirimleri de Firebase üzerinden gider.

**A. Firebase projesi**
1. **console.firebase.google.com** → *Proje ekle* → ad: `secim-online` (Google Analytics gerekmez).
2. **iOS uygulaması ekle** → Bundle ID: `com.feniksklein.secimonline` → `GoogleService-Info.plist` dosyasını indir.
3. **Android uygulaması ekle** → paket adı: `com.feniksklein.secimonline` → `google-services.json` dosyasını indir.
4. **Apple bildirim anahtarı:**
   - developer.apple.com → *Certificates, IDs & Profiles* → *Keys* → **+** → *Apple Push Notifications service (APNs)* işaretle → `.p8` dosyasını indir, **Key ID**'yi not al.
   - Firebase → ⚙️ *Proje ayarları* → *Cloud Messaging* → *Apple uygulama yapılandırması* → *APNs Kimlik Doğrulama Anahtarı* → `.p8` dosyasını, Key ID'yi ve Team ID'ni gir.
5. Firebase → ⚙️ *Proje ayarları* → *Hizmet hesapları* → **Yeni özel anahtar oluştur** → bir JSON dosyası iner. Bu dosya gizlidir, kimseyle paylaşma.

**B. Uygulama (Capacitor)**
1. Online oyunun Capacitor projesinde:
   ```
   npm install @capacitor-firebase/messaging firebase @capacitor/device
   npx cap sync
   ```
   (`@capacitor/device`, çoklu hesap önlemi için telefonun kalıcı cihaz kimliğini verir. Kurulmazsa uygulama kendi ürettiği kimliği kullanır; o kimlik uygulama silinince sıfırlanır.)
2. `GoogleService-Info.plist`'i Xcode'da `App/App` klasörüne sürükle ("Copy items if needed" işaretli). `google-services.json`'u `android/app/` klasörüne koy.
3. Xcode → *Signing & Capabilities* → **+ Capability** → **Push Notifications** ve **Background Modes → Remote notifications**.
4. iOS'ta `AppDelegate.swift` dosyasına Firebase'i başlatan birkaç satır eklenir. Satırlar eklentinin kurulum sayfasında var: capawesome.io → *Firebase Cloud Messaging*. Bu adımda ekran görüntüsü atarsan birlikte yaparız.
5. `capacitor.config` dosyasına, uygulama açıkken de bildirim görünsün diye:
   ```json
   "plugins": { "FirebaseMessaging": { "presentationOptions": ["badge", "sound", "alert"] } }
   ```
   Uygulama girişte bildirim izni ister, telefonu kaydeder ve doğru konulara abone olur. Bunun için `index.html`'de değişiklik gerekmez.

**C. Sunucu**
1. Supabase → **Database → Extensions** → **pg_net**'i aç.
2. Supabase → **Edge Functions** → *Deploy a new function* → *Via Editor* → adı **push-gonder** → `push-gonder.ts` dosyasının tamamını yapıştır → *Deploy*.
3. Fonksiyonun ayarlarında **"Verify JWT"** (JWT doğrulaması) seçeneğini **kapat**. Fonksiyon kendi gizli anahtarıyla korunuyor.
4. **Edge Functions → Secrets** bölümüne iki değer ekle:
   - `FCM_SERVICE_ACCOUNT` → A5'te indirdiğin JSON dosyasının **tamamı**
   - `PUSH_GIZLI` → uzun, rastgele bir metin (ör. 40 karışık harf ve rakam)
5. SQL Editor'da (proje kodunu ve aynı gizli metni yaz):
   ```sql
   update oyun.ayarlar set
     push_url   = 'https://PROJE-KODUN.supabase.co/functions/v1/push-gonder',
     push_gizli = 'PUSH_GIZLI ile aynı metin',
     push_aktif = true;
   ```
6. Dene: Yönetici panelinden bir duyuru gönder; telefonuna gelmeli. Gelmezse şu sorguyla hatayı görebilirsin:
   ```sql
   select id, baslik, deneme, hata from oyun.push_kuyruk order by id desc limit 10;
   ```

**Hangi bildirimler gider?**
- **Seçim hatırlatmaları:** başvurular açıldı, sandık açıldı (genel/belediye/parti içi), sonuçlar açıklandı.
- **Özel mesajlar.**
- **Propaganda yayınları ve yönetim duyuruları:** oyuncunun il ve partisine göre.
- **Kişisel bildirimler:** atandın, seçildin, kanun onayını bekliyor, ittifak daveti gibi.

Oyuncu her türü **Ben → Bildirimler**'den kapatabilir.

## 10) Ödüllü reklam ve oyun içi para satışı

Bu bölüm de isteğe bağlı. Kurulmazsa oyun çalışır; "Reklam izle" ve "Mağaza" düğmeleri yalnızca "telefonda" uyarısı gösterir.

**A. Ödüllü reklam (Google AdMob)**
1. **admob.google.com** → *Uygulama ekle* → iOS ve Android için ayrı ayrı `Seçim Simülasyonu Online`.
2. Her uygulamada *Reklam birimi ekle* → **Ödüllü** (Rewarded). Ödül miktarını 1 bırak; asıl ödülü sunucu hesaplar (2 saatlik maaş).
3. Capacitor projesinde:
   ```
   npm install @capacitor-community/admob
   npx cap sync
   ```
4. Uygulama kimliklerini ekle (AdMob'daki `ca-app-pub-...~...` biçimindeki **uygulama** kimliği):
   - iOS: `Info.plist` → `GADApplicationIdentifier`
   - Android: `AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`
5. `www/index.html`'in başındaki `AYAR` bölümünde:
   - `ADMOB_ODULLU_IOS` / `ADMOB_ODULLU_ANDROID` → kendi **reklam birimi** kimliklerin (`ca-app-pub-.../...`).
   - Hazır gelen değerler Google'ın test birimleridir. Test ederken onlarla kal; yayından önce kendi birimlerini yaz ve `ADMOB_TEST: false` yap.
   - Kendi reklamına tıklama: AdMob hesabı kapanabilir.
6. Kurallar: Günde 5 reklam, aralarında en az 60 saniye. Ödül yalnızca reklam sonuna kadar izlenince verilir.

**B. ₺ paketleri (App Store / Google Play + RevenueCat)**

Ödemeyi Apple ve Google alır. RevenueCat ödemeyi doğrular ve sunucuna haber verir. Para cüzdana sunucu tarafında eklenir; uygulama kendi kendine para ekleyemez.

1. **App Store Connect** → uygulaman → *Uygulama İçi Satın Alımlar* → üç **Tüketilebilir** (Consumable) ürün:
   - `tl_10000` — Cep harçlığı (10.000 ₺)
   - `tl_35000` — Kampanya kasası (35.000 ₺)
   - `tl_100000` — Seçim fonu (100.000 ₺)
2. **Google Play Console** → *Uygulama içi ürünler* → aynı üç kimlikle ürün oluştur.
   - Fiyatları sen belirlersin.
   - Apple ve Google'ın kesintisi %15–30 arasıdır.
3. **app.revenuecat.com** → proje aç → iOS ve Android uygulamalarını bağla (App Store Connect API anahtarı ve Google Play hizmet hesabı istenir; RevenueCat adım adım gösteriyor).
   - *Products* bölümüne üç ürünü ekle.
   - *API keys* bölümündeki genel anahtarları (`appl_...`, `goog_...`) `AYAR` içindeki `REVENUECAT_IOS` / `REVENUECAT_ANDROID`'e yaz. Bunlar gizli değildir.
4. Capacitor projesinde:
   ```
   npm install @revenuecat/purchases-capacitor
   npx cap sync
   ```
   Xcode → *Signing & Capabilities* → **+ Capability** → **In-App Purchase**.
5. Sunucu:
   1. Supabase → **Edge Functions** → *Deploy a new function* → *Via Editor* → adı **odeme-webhook** → `odeme-webhook.ts` dosyasının tamamını yapıştır → *Deploy*.
   2. Ayarlarında **"Verify JWT"** seçeneğini **kapat**.
   3. **Edge Functions → Secrets** → `ODEME_GIZLI` → uzun, rastgele bir metin. Bu metni kimseyle paylaşma.
6. RevenueCat → *Project settings* → *Integrations* → **Webhooks** → *Add*:
   - **URL:** `https://PROJE-KODUN.supabase.co/functions/v1/odeme-webhook`
   - **Authorization header:** `Bearer ` + ODEME_GIZLI ile aynı metin
7. Dene: Apple'ın *Sandbox* test hesabıyla bir paket al. Birkaç saniye içinde cüzdanına eklenmeli. Kontrol için:
   ```sql
   select * from oyun.satin_almalar order by zaman desc limit 10;
   ```
   - Aynı ödeme iki kez gelirse bir kez eklenir.
   - İade edilen ödemenin parası cüzdandan geri düşer (yetmiyorsa cüzdan sıfırlanır).

**Paket içerikleri ve başlangıç parası** SQL Editor'dan değiştirilebilir:
```sql
update oyun.paketler set miktar = 12000 where urun_id = 'tl_10000';
update oyun.ayarlar set baslangic_para = 10000;
```

## Sonraki adımlar

- Canlıya çıkış kontrol listesi (7. bölüm) ve mağaza gönderimi.
- Gerçek oyuncularla ekonomi ve propaganda dengesinin ayarlanması.


## Yayına almadan önce: vatandaşlık şartları
Üretimde varsayılan şartlar şunlardır; hepsi yönetici panelinden (Ben › Yönetici paneli › Vatandaşlık ve parti kurma şartları) değiştirilebilir:
- **Hesap yaşı:** 3 gün.
- **Oy için en az kıdem:** 10 ("Vatandaş" statüsü, yaklaşık 10 gün maaş toplamak).
- **Seçmen kütüğü:** yerel ve genel seçimde ilinde en az 7 gündür kayıtlı olmak.
- **Bir cihazda en fazla hesap:** 2. İkinci hesap yönetici onayına kadar oy kullanamaz.
- **Parti kurmak:** 30 kıdem, 7 gün içinde 5 kurucu üye, 25.000 ₺ kuruluş ücreti (fiyat düzeyiyle artar).
- **İl teşkilatı:** Parti yalnızca teşkilatı olan illerde aday gösterebilir; il binası 2.000 / 4.000 / 6.000 ₺ (küçük / orta / büyük il), parti kasasından.
- **Para gönderme:** Günde en fazla 1 aylık asgari ücret.
- **Banka:** Faizler enflasyon + 5 puan üzerinden hesaplanır; kişi başı en fazla 2.000.000 ₺ mevduat.

Açılış günlerinde oyuncu azken kıdem ve kurucu sayısını düşürüp oyuncu sayısı arttıkça yükseltebilirsin.


## Güncelleme yapmak (oyun sıfırlanmaz)
Oyunda bir şeyi değiştirdiğimde ya da yeni bir özellik eklediğimde sana yeni bir `supabase-kurulum.sql` gönderirim. Yapacağın tek şey: Supabase → **SQL Editor** → **New query** → dosyanın tamamını yapıştır → **Run**.
- Dosya önce oyunun tam yedeğini alır.
- Oyuncuların hesabı, makamı, parası, kıdemi, oyları, partileri ve mülkleri güncellemeden önce ve sonra karşılaştırılır. Tek bir değer değişecek olursa güncelleme **kendiliğinden iptal olur** ve oyun olduğu gibi kalır.
- Başarılı güncellemenin sonunda `"kontrol": "oyuncu verisi değişmedi"` yazar.
- Yeni bir makam ya da özellik geldiğinde yalnızca o eklenir; mevcut makamlar ve o makamlardaki kişiler değişmez.
- Ayrıntılar ve geliştirici kuralları: `GUNCELLEME_KURALLARI.md`.

**Oyunu sıfırlamak sadece senin elinde:** SQL Editor'de `select oyun.oyunu_sifirla('OYUNU SIFIRLA');` çalıştırırsın, ardından kurulum dosyasını bir kez daha çalıştırırsın. Sıfırlamadan önce de otomatik yedek alınır; pişman olursan `select * from oyun.yedekler();` ile yedeği bulup `select oyun.yedekten_don('yedek_…', 'GERİ YÜKLE');` ile geri dönersin.

**Telefon uygulaması eski kalırsa:** Ben › Yönetici paneli › "En düşük uygulama sürümü" alanına sürüm yazarsan (ör. `2026.10.06-3`) daha eski uygulamalar "Güncelleme gerekli" ekranı gösterir. Web sürümü (GitHub Pages) her zaman en günceldir.
