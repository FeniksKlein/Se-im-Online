# Seçim Simülasyonu Online — Oyun Tasarımı ve Sunucu

## 1. Zaman

Oyunun saati gerçek hayatın saatidir. Bugün 2 Ekim 2026 ise oyunda da 2 Ekim 2026'dır.

- Saat **sunucudan** alınır (Türkiye saati). Telefonun saati değiştirilse bile hiçbir şey değişmez; kimse saatini ileri alıp hile yapamaz.
- Seçim motoru sunucuda **her dakika** kendiliğinden çalışır. Sandığı açar ve kapatır, 22:30'da oyları sayar, kazananları göreve başlatır, görev süresi biteni görevden alır.
- Hiç kimse uygulamayı açmasa bile takvim işler.

## 2. Aylık takvim

| Gün | Olay |
|---|---|
| 4–6 | Belediye başkanı aday adaylığı başvurusu (3 gün) |
| 8 | Belediye ön seçimi (partinin ildeki üyeleri), 08:00–22:00 |
| 10 | İl belediye başkanlığı seçimi (ildeki herkes), 08:00–22:00, sonuç 22:30 |
| 11 | Belediye başkanları göreve başlar (görev 1 ay) |
| 15–17 | Genel başkanlık başvurusu |
| 18 | Kurultay: partinin üyeleri genel başkanı seçer |
| 19 | Yeni genel başkan göreve başlar, 6 yardımcısını atar |
| 19–25 | Genel başkan cumhurbaşkanı adayını belirler: kendisi, başka bir üye ya da üyelerin ön seçimi |
| 24–26 | Milletvekili aday adaylığı (3 gün); CB ön seçimi başvurusu 26–27 |
| 28 | Vekil ve CB ön seçimleri, 08:00–22:00: partinin ildeki üyeleri liste sırasını belirler |
| 1 | Genel seçim + cumhurbaşkanlığı seçimi, 08:00–22:00, sonuç 22:30 |
| 2 | Vekiller göreve başlar. CB'de kimse %50'yi geçemediyse ilk iki aday 2. tura girer, kazanan 3'ünde göreve başlar |

## 3. Makamlar

| Makam | Nasıl belirlenir | Süre |
|---|---|---|
| **Cumhurbaşkanı** | Adayı partilerin genel başkanları belirler; genel seçimle tüm oyuncular seçer (%50+1, yoksa 2. tur) | 1 ay |
| **Bakanlar (12)** | Cumhurbaşkanı atar ve görevden alır | Yeni CB gelince kabine düşer |
| **Genel başkan** | Kurultayda partinin üyeleri seçer | 1 ay (aday çıkmazsa devam eder) |
| **Genel başkan yardımcıları (6)** | Genel başkan atar | Yeni genel başkan gelince düşer |
| **Milletvekili (600)** | Ön seçimle liste, genel seçimde il il D'Hondt ve %7 baraj | 1 ay |
| **İl belediye başkanı (81)** | Ön seçimle parti adayı, ildeki oyuncuların oyuyla en çok oyu alan | 1 ay |

**12 bakanlık:** Adalet, Dışişleri, İçişleri, Hazine ve Maliye, Millî Savunma, Millî Eğitim, Sağlık, Sanayi ve Teknoloji, Ticaret, Tarım ve Orman, Ulaştırma ve Altyapı, Çalışma ve Sosyal Güvenlik.

**Tek görev kuralı:** Kimse aynı anda iki görev taşıyamaz. Görevler: milletvekili, belediye başkanı, bakan, cumhurbaşkanı, genel başkan, genel başkan yardımcısı. İki istisna var:
- **Milletvekili + genel başkan yardımcısı** birlikte olabilir.
- **Milletvekili + genel başkan** birlikte olabilir. Ancak aynı seçim döneminde kesin cumhurbaşkanı adayı olan genel başkan, milletvekili adayı olamaz.
- **Genel başkan + cumhurbaşkanı** birlikte olabilir: genel başkan kendini cumhurbaşkanı adayı gösterip seçilirse ikisini de taşır.

Uygulaması:
- **Atama:** Genel başkan yardımcılarını yalnızca genel başkan, bakanları yalnızca cumhurbaşkanı atar. Başka görevi olan biri bakan atanamaz; önce görevinden istifa etmelidir. Yardımcı olarak yalnızca milletvekilleri ve görevi olmayanlar atanabilir.
- **Seçim:** Seçimi kazanan kişinin eski görevi sona erer (belediye başkanı seçilen vekil, vekil seçilen bakan gibi). Aday olurken bu uyarı gösterilir. Belediye ya da cumhurbaşkanı seçilen yardımcı yardımcılıktan, kurultayı kazanan vekil ve bakan eski görevinden düşer.
- **Genel başkan** milletvekili adayı olabilir; milletvekili seçilse de genel başkanlığı sürer. Aynı dönem cumhurbaşkanı adayıysa milletvekili adayı olamaz. Belediye başkanı adaylığına ilişkin mevcut diğer kural değişmez.
- **İstifa:** Bakan, genel başkan yardımcısı, milletvekili ve belediye başkanı istediği zaman istifa edebilir. İstifa eden vekilin yerine listedeki sıradaki aday girer.

**Yapay oyuncu yok:** Oyunda bot ya da NPC bulunmaz. Her vekil, bakan, başkan ve seçmen gerçek bir oyuncudur. Makama aday çıkmazsa makam boş kalır. Test botları yalnızca geliştirici klasöründeki testlerde kullanılır; `supabase-kurulum.sql` içinde yoktur.

## 4. Sohbet, özel mesaj ve propaganda

**Sohbet kanalları**
Sohbet ekranı kanalları üç grupta gösterir. Her kanalda son mesaj, okunmamış mesaj sayısı ve çevrimiçi oyuncu sayısı görünür. Girmeye yetkin olmayan kanallar silinmez, **kilitli** görünür ve nasıl açılacağı yazar.

| Grup | Kanal | Kim girer, kim yazar |
|---|---|---|
| Herkese açık | **Türkiye Meydanı** | Tüm oyuncular |
| | **İl Kahvesi** | Yalnızca senin ilindeki oyuncular |
| | **Belediye Meclisi** | İlin herkesi izler. Yalnızca o ilin belediye başkanı ve milletvekilleri yazar |
| Siyasi örgüt | **Parti sohbeti** | Partinin üyeleri |
| | **Parti Yönetim Kurulu** | Yalnızca genel başkan ve genel başkan yardımcıları (sıradan üye giremez) |
| | **İttifak sohbeti** | İttifaktaki partilerin üyeleri |
| Devlet | **TBMM Genel Kurulu** | Vekiller, bakanlar ve cumhurbaşkanı konuşur, herkes izler |
| | **Bakanlar Kurulu** | Yalnızca cumhurbaşkanı ve bakanlar |

**Özel mesaj:** İki oyuncu arasında.

**Propaganda yayınları** alıcıların bildirim kutusuna düşer:

| Kim | Kime | Günde |
|---|---|---|
| Cumhurbaşkanı (ulusa sesleniş) | Tüm Türkiye | 1 |
| Bakan (bakanlık açıklaması) | Tüm Türkiye | 1 |
| Genel başkan (parti genelgesi) | Partinin tüm üyeleri | 3 |
| Genel başkan yardımcısı | Partinin tüm üyeleri | 1 |
| Milletvekili | İlindeki herkes | 1 |
| Belediye başkanı | İlindeki herkes | 1 |
| Ön seçim adayı | Partinin o ildeki üyeleri (kurultay ve CB ön seçiminde tüm üyeler) | Her seçim için 1 |
| Belediye adayı / vekil listesindeki aday | İlindeki herkes | Her seçim için 1 |
| Cumhurbaşkanı adayı | Tüm Türkiye | 1 |

Haklar her gece 00:00'da yenilenir. Adayın propaganda hakkı, oylama bitince kalkar.

**Kişisel bildirimler:** atandın, görevden alındın, seçildin, yedekten Meclis'e girdin ve benzeri olaylarda gelir.

**Güvenlik (Apple'ın şartı)**
- Her mesaj, yayın ve oyuncu şikâyet edilebilir ve engellenebilir.
- 3 farklı kişinin şikâyet ettiği içerik otomatik gizlenir.
- 24 saatte 8 farklı kişiden şikâyet alan hesap 24 saat susturulur.
- Küfür filtresi var. Hız sınırı: 3 saniyede 1 mesaj, dakikada en fazla 12 mesaj.

**Saklama süresi:** Sohbet ve yayınlar 30 gün, bildirimler 60 gün, özel mesajlar 90 gün sonra kendiliğinden silinir.

## 5. Devlet yönetimi (2. aşama)

### Ülke karnesi
Ülkenin durumu 6 göstergeyle izlenir: **halk memnuniyeti**, **büyüme**, **enflasyon**, **işsizlik**, **hazine** (milyar ₺) ve **vergi oranı**. Ayrıca 81 ilin her birinin 0-100 arası bir **gelişmişlik** puanı var.

Göstergeler her gece kendiliğinden hesaplanır:
- Devletin günlük geliri vergi oranına ve büyümeye bağlıdır. Günlük harcama 10 milyar ₺'dir.
- Harcama, bütçe kanunundaki paylara göre 12 bakanlığın kasasına aktarılır.
- Vergi artarsa hazine dolar ama büyüme ve memnuniyet düşer.
- Hazine eksiye düşerse enflasyon tırmanır.
- Enflasyon ve işsizlik halkın memnuniyetini düşürür, büyüme artırır.
- Yatırım almayan iller zamanla ortalamaya geri döner.

### Bakanlık icraatları
Her bakanın, bakanlık kasasındaki parayla yapabileceği 2 icraatı var. İcraatların hepsi oyuncuların maaşına, geçim masrafına, cüzdanına ya da haklarına dokunur. Çalışma, Maliye ve Ulaştırma bakanları ayrıca ekonomi ayarlarını (asgari ücret, vergi, destekler) yönetir. Ayrıntısı 7. bölümde.

"(il)" yazan icraatlarda bakan bir il seçer ve etki yalnızca o ilde yaşayanlara işler. Vekillerin bakanlara "ilime fabrika" diye lobi yapması tam olarak bu yüzden anlamlı.

### Kanunlar (yalnızca milletvekilleri teklif eder)

| Tür | Ne yapar |
|---|---|
| Serbest kanun | Metniyle Resmî Gazete'de yayımlanır |
| Bütçe kanunu | Gelir vergisi bandını, belediyelerin vergi payını, partilere hazine yardımını ve 12 bakanlığın bütçe payını belirler (7. bölüm) |
| Seçim kanunu | Ülke barajını (%0–10) değiştirir. Seçim döneminde kabul edilirse sonraki seçimden itibaren uygulanır |
| Kararname iptali | Yürürlükteki bir cumhurbaşkanlığı kararını iptal eder |

**Süreç:**
1. Teklif verilir, Meclis 24 saat görüşür.
2. Ardından 24 saat oylanır. Vekiller kabul, ret ya da çekimser oy verir; oylama bitene kadar oy değiştirilebilir. Oylar isim isim açıktır.
3. Kabul edilmesi için üç şart var:
   - Dolu sandalyelerin en az üçte biri oylamaya katılmalı (toplantı yeter sayısı).
   - Kabul oyu retten fazla olmalı.
   - Kabul oyu dolu sandalyelerin dörtte birinden en az 1 fazla olmalı.
4. Kabul edilen kanunu cumhurbaşkanı 48 saat içinde **onaylar** ya da **veto eder** (gerekçesiyle). Karar vermezse kanun kendiliğinden yürürlüğe girer. Cumhurbaşkanı makamı boşsa kanun hemen yürürlüğe girer.
5. Veto edilen kanun 24 saat ısrar oylamasına girer. Dolu sandalyelerin salt çoğunluğu (yarısından fazlası) kabul ederse cumhurbaşkanına gitmeden yürürlüğe girer.
6. Yeni Meclis göreve başlayınca (ayın 2'si) sonuçlanmamış teklifler **kadük** olur.
- Bir vekilin aynı anda yalnızca 1 sonuçlanmamış teklifi olabilir. Yürürlüğe giren kanunlar 8001'den başlayarak numaralanır.

### Cumhurbaşkanlığı kararları (günde en fazla 3)
- **İl desteği:** Hazineden bir ile 1–30 milyar ₺. İlin gelişmişliği ve halkın memnuniyeti artar.
- **Ek ödenek:** Hazineden bir bakanlığın kasasına 1–30 milyar ₺.
- **Bayram ikramiyesi:** Son 7 günde oyuna giren her oyuncuya 500–5.000 ₺ tek seferlik ödeme. Bedeli hazineden çıkar. 7 günde bir verilebilir.
- Cumhurbaşkanı ayrıca **ekonomi masasından** asgari ücreti, vergiyi, kıdem primini, sosyal desteği ve taşınma desteğini ayarlar (7. bölüm).
- **Serbest karar:** Metniyle yayımlanır (millî yas ilanı gibi).

### İttifaklar
- Genel başkan ittifak kurar ve diğer partileri davet eder. Davet edilen partinin genel başkanı kabul ya da ret eder. Partiler istedikleri zaman ayrılabilir.
- Genel seçim döneminde (aday adaylığı başvurusundan seçim sonucuna kadar) ittifaklarda hiçbir değişiklik yapılamaz.
- **Baraj:** İttifakın toplam oyu barajı aşarsa ittifaktaki tüm partiler barajı geçmiş sayılır. Sandalyeler her partinin kendi oyuna göre dağıtılır, gerçekteki gibi.
- **Cumhurbaşkanlığı:** Genel başkan kendi adayını çıkarmak yerine ittifak ortağının adayını destekleyebilir. Oy pusulasında adayın yanında destekleyen partiler görünür.
- İttifak partilerinin üyelerine özel bir sohbet kanalı var.
- Gerçek ittifakları çağrıştıran adlar kullanılamaz.

### Resmî Gazete
Yürürlüğe giren kanunlar, cumhurbaşkanlığı kararları, bakan atamaları ve bakanlık icraatları gün gün **Resmî Gazete** ekranında yayımlanır.

## 6. Belediyeler, bildirgeler, rozetler, yönetim (3. aşama)

### Belediye başkanı yetkileri
- Her ilin **belediye kasası** her gece ilin gelirleriyle dolar. Gelir ilin büyüklüğüne, gelişmişliğine, Meclis'in belirlediği belediye payına ve başkanın kent vergisine bağlıdır.
- Maliyetler "ilin taban gelirinin yüzdesi" olarak tanımlıdır. Böylece küçük ilin başkanı da büyük ilinki de aynı hizmetleri açabilir.
- Başkan kent vergisini (%0–5) ve hemşehri desteğini ayarlar, hizmetleri açıp kapatır, yatırım yapar. Ayrıntısı 7. bölümde.

### Seçim bildirgesi ve ölçülebilir vaatler
Her aday en fazla 280 karakterlik bir bildirge yazar ve makamına uygun **ölçülebilir vaatler** seçer. Partinin genel başkanı da genel seçim için seçim beyannamesi yazar. Karşılıksız vaat kaydedilemez. Ayrıntısı 7. bölümde.

### Rozetler
Oyuncu kartında görünür: Cumhurbaşkanı, Bakan, Genel Başkan, Milletvekili, Belediye Başkanı, Kanun Yapıcı (teklifi yasalaştı), Parti Kurucusu, Hatip (10+ propaganda yayını), Sandık Neferi (ilk oy) ve Demokrasi Emektarı (20+ seçimde oy).

### Yönetici paneli ve moderatör ekibi
Yönetici (oyunun sahibi) her şeyi yapar. Panelde şunlar var:
- Özet: oyuncu sayısı, son 24 saatte aktif olanlar, mesajlar, açık şikâyetler, kayıtlı cihazlar.
- Şikâyet kararları: sorun yok, gizle, gizle ve 1 ya da 7 gün sustur, hesabı kapat.
- Oyuncu arama: e-posta, son mesajlar, hakkındaki şikâyetler ve kredi borcu.
- Tüm oyunculara duyuru gönderme.
- Oyun kuralları: hesap yaşı, oy ve parti kurma şartları, parti kuruluş ücreti, teşkilat bedeli ve şartı, günlük para gönderme sınırı, banka faizi, mevduat tavanı, bankayı açıp kapama.

**Moderatör ekibi.** Yönetici istediği oyuncuyu moderatör yapar ve yetkilerini tek tek seçer:

| Yetki | Ne yapar |
|---|---|
| Özet | Özet rakamları görür |
| Şikâyetler | Şikâyet edilen içerikleri görür, "sorun yok" ya da "gizle" der |
| Susturma | Oyuncuyu 1 / 7 gün susturur, susturmayı kaldırır |
| Hesap kapatma | Hesabı kapatır ya da yeniden açar |
| Oyuncu inceleme | Oyuncu bilgilerini ve son mesajlarını görür |
| E-posta görme | İncelerken e-posta adresini de görür (kişisel veri) |
| Duyuru | Tüm oyunculara duyuru gönderir |
| Çoklu hesap incelemesi | Aynı cihazdaki hesapları görür, gerçek kişiyi onaylar |
| Kurallar ve ayarlar | Oyun kurallarını değiştirir |

- Moderatör yalnızca verilen yetkiyi kullanır; yöneticiye ve başka moderatörlere işlem yapamaz, moderatör atayamaz.
- Moderatör atamak, yetki vermek ve zorunlu uygulama sürümü yalnızca yöneticinindir.
- Her yetkili işlem **moderasyon günlüğüne** yazılır (kim, ne zaman, kime, ne yaptı). Günlüğü yalnızca yönetici görür.
- Yetkileri boş bırakılan oyuncunun moderatörlüğü biter; kendisine bildirim gider.

Kapatılan hesap oyuna giremez, görevleri düşer, mesajları gizlenir.

### Telefona gelen bildirimler (push)
- Telefon girişte kaydedilir ve Firebase "konu"larına abone olur:
  - seçim hatırlatmaları: tüm oyuncular ve kendi partisi
  - propaganda: tüm Türkiye, kendi ili ve kendi partisi
  - yönetim duyuruları
- İl ya da parti değişince abonelikler kendiliğinden güncellenir.
- Kişisel bildirimler ve özel mesajlar doğrudan kişinin telefonuna gider. Bir kişinin en fazla 5 cihazı kaydedilir.
- Veritabanı bildirimleri bir kuyruğa yazar. Kuyrukta bildirim varsa her dakika sunucu fonksiyonu (`push-gonder`) çalışır ve bildirimleri Firebase'e iletir.
- Başarısız gönderim 3 kez denenir. 6 saati geçen bildirim artık gönderilmez. Geçersizleşen cihaz kaydı silinir.
- Bildirime dokunan oyuncu ilgili ekrana gider: özel mesaj, seçim ya da bildirim kutusu.

## 7. Vatandaş ekonomisi (4. aşama)

Oyunda NPC halk yok; seçmen de vatandaş da gerçek oyuncular. Bu yüzden belediyenin, bakanların, Meclis'in ve cumhurbaşkanının her kararı oyuncuların kendi cüzdanına yansır. Ekonomi bilerek basit tutuldu: oyuncu "çalış, yemek ye, kurs al" gibi angarya yapmaz. Oyuna girer, birikeni toplar, siyaset yapar.

### Para nasıl kazanılır?
| Yol | Nasıl çalışır |
|---|---|
| **Maaş kumbarası** | Maaş saat saat kumbarada birikir. 16 saatte dolar ve durur (yasayla 12–24 saat). Oyuncu girip "Topla"ya basınca cüzdana geçer. Günde 3 kez gelen kaybetmez. Kumbara dolunca telefona bildirim gider |
| **Günlük seri** | Her gün en az bir kez toplayan oyuncunun maaşına her gün +%5 eklenir, en fazla +%30. Kaçırılan her gün seri bir basamak geri gider (sıfırlanmaz) |
| **Statü (kıdem)** | Oyuna girilen her gün +1, kullanılan her oy +3 kıdem puanı. Basamaklar: Yeni Gelen (0), Vatandaş (10), Saygın Vatandaş (30), Kanaat Önderi (75), Duayen (150), Yaşayan Efsane (300). Her basamak maaşa **kıdem primi** kadar ekler (başlangıçta %10; hükümet belirler) |
| **Makam maaşı** | Görevdekiler asgari ücretin yanında makam maaşı da alır (aşağıdaki tablo) |
| **Ödüllü reklam** | Reklam izleyen 2 saatlik maaşı kadar ödül alır. Günde 5 kez, aralarında en az 60 saniye |
| **Destekler** | Hükümetin sosyal desteği, belediyenin hemşehri desteği, ikramiye, AFAD yardımı, vergi iadesi, partinin kampanya desteği |
| **Satın alma** | Mağazada ₺ paketleri: Cep harçlığı 10.000 ₺, Kampanya kasası 35.000 ₺, Seçim fonu 100.000 ₺. Ödeme App Store / Google Play'den alınır, RevenueCat sunucuya bildirir, para cüzdana eklenir. Fiyatı mağaza panelinde sen belirlersin |

Yeni oyuncu 150.000 ₺ ile başlar (31.10.2026; `ayarlar.baslangic_para`).

**Maaş** = asgari ücret × statü çarpanı × il çarpanı × (1 + destekler) × (1 + seri). İl çarpanı ilin gelişmişliğine bağlıdır: gelişmişlik 0 → ×0,8, 50 → ×1,0, 100 → ×1,2.

**Kesintiler:**
- **Gelir vergisi:** Yalnızca asgari ücretin üstündeki kazançtan kesilir. Asgari ücretli vergi ödemez.
- **Kent vergisi:** %0–5. İlin belediye başkanı belirler, belediye kasasına gider.
- **Geçim masrafı:** Günde 350 ₺ × fiyat düzeyi. Enflasyonla artar. Belediye hizmetleri ve bakanlık icraatları düşürür.

### Makam maaşları (gerçek oranlarla, fiyat düzeyiyle artar)
| Makam | Aylık |
|---|---|
| Asgari ücret (net) | 28.075 ₺ |
| Cumhurbaşkanı | 354.497 ₺ |
| Bakan | 318.009 ₺ |
| Milletvekili | 310.332 ₺ |
| Belediye başkanı (büyük il / orta / küçük / en küçük) | 317.800 / 267.800 / 198.900 / 171.400 ₺ |

Birden fazla makamı olan en yüksek makamın maaşını tam, diğer her makamın %25'ini alır (31.10.2026; `oyun.tarife.makam_ek_oran`). Meclis Başkanlığı, başkanvekilliği ve grup başkanvekilliği vekil ödeneğine eklenen görev tazminatıdır, tam ödenir.

### Para nereye harcanır?
| Harcama | Tutar |
|---|---|
| **Aday adaylığı ücreti** (parti kasasına gider) | Milletvekili 15.000, belediye 10.000 × il büyüklüğü (1–3), genel başkanlık 50.000, cumhurbaşkanlığı 150.000 ₺ (31.10.2026, `oyun.tarife`). Fiyat düzeyiyle artar. Genel başkan her ücreti ×0 ile ×3 arasında ayarlayabilir |
| **Taşınma** (il değiştirme) | 20.000 ₺ × fiyat düzeyi. Devletin taşınma desteği, ücretsiz ulaşım ve hızlı tren düşürür (en fazla %90) |
| **Ek propaganda hakkı** | 1.500 ₺. Günlük hak bitince bir yayın daha. Günde en fazla 3 |
| **Partiye bağış** | Parti kasasına girer. Günde en fazla bir aylık asgari ücret kadar (şehir bağışıyla ortak sınır). Her asgari ücret tutarı **+1 kıdem puanı** kazandırır |
| **Şehir kalkınma bağışı** | İlin gelişmişliğini artırır: her asgari ücret tutarı için **+0,005 gelişmişlik** (gelişmiş ilde maaşlar ve belediye geliri artar) ve **+1 kıdem puanı**. Ayın hayırseverleri listesi herkese açıktır |
| **Parti kuruluşu** | 500.000 ₺ × fiyat düzeyi harç (başvurandan) + 1.000.000 ₺ × fiyat düzeyi kuruluş fonu (kurucular birlikte toplar, partinin kasasına geçer). Ayrıntı: bölüm 21 |
| **İl teşkilatı** (parti kasasından) | 10.000 ₺ × il büyüklüğü (1–3) × fiyat düzeyi. Bir kez ödenir |
| **Para gönderme** | Başka bir oyuncuya; günde en fazla 1 aylık asgari ücret |

**Verginin karşılığı:** "Hayat" ekranındaki vergi karnesi, son 7 günde ödediğin gelir vergisinin bütçe kanunundaki paylara göre hangi bakanlığa, belediyelere ve sosyal desteğe gittiğini gösterir; karşılığında sana işleyen hizmetleri (icraatlar, belediye hizmetleri) de listeler.

### Ülke ekonomisini kim yönetir?
Cumhurbaşkanı ve kabine. Ekonomi masasındaki her ayar Resmî Gazete'de yayımlanır.

| Ayar | Kim | Sınır | Bekleme |
|---|---|---|---|
| Asgari ücret | Çalışma Bakanı, CB | Düşürülemez; bir seferde en fazla %30 artar | 7 gün |
| Kıdem primi | Çalışma Bakanı, CB | %0–20 | 7 gün |
| Sosyal destek (Yeni Gelen ve Vatandaş'a) | Çalışma Bakanı, CB | 0–1.000 ₺/gün | 3 gün |
| Gelir vergisi | Maliye Bakanı, CB | Meclis'in bütçe kanunundaki bant içinde, bir seferde ±5 puan | 3 gün |
| Taşınma desteği | Ulaştırma Bakanı, CB | %0–80 | 7 gün |

Ayarı girerken bütçeye ve enflasyona etkisi anında gösterilir.

**Hazine nüfus ölçeğinde hesaplanır.** Oyuncu sayısı bütçeyi etkilemez. Bir ayar sanki 85 milyon kişilik ülkeye uygulanıyormuş gibi hesaplanır. Örneğin 100 ₺ sosyal destek 8 milyon kişiye gider, günde 0,8 milyar ₺ eder.
- **Gelir:** Gelir vergisi (asgari ücretle büyür) ve diğer gelirler (büyümeyle artar).
- **Gider:** Cari harcama, belediyelere aktarılan pay ve sosyal destek.
- Gelir giderden fazlaysa ve hazine doluysa **mali alan** oluşur. Mali alan ne kadar genişse o kadar büyük vaat verilebilir. Ülkeyi refaha sokan hükümet daha cömert vaatler verebilir, çünkü para vardır.
- Asgari ücreti ekonominin kaldırabileceğinden hızlı artırmak, yüksek kıdem primi ve büyük sosyal destek enflasyonu yükseltir. Enflasyon fiyat düzeyini, yani geçim masrafını ve tüm fiyatları artırır.

### Meclis'in ekonomideki yeri: Bütçe kanunu
Vekil asgari ücreti doğrudan değiştiremez. Bütçe kanunuyla hükümete çerçeve çizer:

| Değer | Başlangıç | Aralık |
|---|---|---|
| Gelir vergisi bandı (taban–tavan) | %10–35 | %0–45 |
| Belediyelerin vergi payı | %10 | %2–30 |
| Partilere hazine yardımı | 30.000 ₺/gün | 0–200.000 |
| 12 bakanlığın bütçe payı | — | Toplam 100 |

Bütçe kanunu ekranında eski ve yeni değerler yan yana görünür.

### Cumhurbaşkanlığı kararnameleri (günde en fazla 3)
- **İl desteği:** Hazineden bir ile 1–30 milyar ₺. İl gelişir, maaşlar artar.
- **Ek ödenek:** Bir bakanlığa 1–30 milyar ₺.
- **Bayram ikramiyesi:** Son 7 günde oyuna giren herkese 500–5.000 ₺. 7 günde bir. Bedeli 16 milyon kişi üzerinden hazineden çıkar.
- **Serbest karar:** Metniyle yayımlanır.

### Belediyeler: o ilde yaşayan oyunculara işler
**Belediye geliri** = ilin taban geliri × fiyat düzeyi × gelişmişlik × Meclis'in belediye payı × kent vergisi. Büyük il, gelişmiş il, yüksek pay ve yüksek kent vergisi daha çok gelir demektir.

Hizmetler açık kaldığı sürece her gece kasadan gider düşer. Kasa eksiye düşerse hizmetler kendiliğinden kapanır.

| Hizmet | Günlük gider (taban gelirin) | Oyuncuya etkisi |
|---|---|---|
| Kent lokantası | %12 | Geçim masrafı −%15 |
| Ücretsiz toplu ulaşım | %10 | Geçim −%10, bu ile/bu ilden taşınma yarı fiyat |
| Sosyal konut ve kira yardımı | %18 | Geçim −%20 |
| Belediye istihdam ofisi | %15 | İldeki maaşlar +%10 |
| Hemşehri desteği | Sakin sayısına göre | Her sakine günlük 0–1.000 ₺ |
| Yol ve altyapı (yatırım) | 8 günlük gelir, 3 günde bir | Gelişmişlik kalıcı +4 |
| Raylı sistem (yatırım) | 20 günlük gelir, 7 günde bir | Gelişmişlik kalıcı +10 |

Kent vergisi ve hemşehri desteği günde bir kez değiştirilebilir.

### Bakanlık icraatları (her bakanlığın 2 icraatı)
Süreli etkiler 7 gün, il seçilenler 14 gün sürer.

| Bakanlık | İcraat 1 | İcraat 2 |
|---|---|---|
| Adalet | Harç muafiyeti: taşınma −%50 | İfade özgürlüğü paketi: yayın hakkı +1 |
| Dışişleri | Yatırım zirvesi: hazine +15 milyar, maaşlar +%5 | Turizm tanıtımı (il): o ilde maaş +%10, il gelişir |
| İçişleri | Nüfus kolaylığı: il değiştirme beklemesi 30 → 7 gün | AFAD (il): o ilin her sakinine 3.000 ₺ |
| Hazine ve Maliye | Vergi iadesi: son 7 günün vergisinin yarısı geri | Varlık barışı: hazine +25 milyar (mali alan açar) |
| Millî Savunma | Savunma sanayii (il): o ilde maaş +%15 | Bedelli askerlik: hazine +20 milyar, memnuniyet düşer |
| Millî Eğitim | Burs ve staj: yeni oyuncuların maaşı +%20 | Hayat boyu öğrenme: kıdem puanı ×2 |
| Sağlık | Ücretsiz sağlık: geçim −%10 | Şehir hastanesi (il): o ilde geçim −%10, il gelişir |
| Sanayi ve Teknoloji | OSB (il): o ilde maaş +%15, il gelişir | Teknoloji teşviki: maaşlar +%5 |
| Ticaret | Fahiş fiyat denetimi: geçim −%10 | İhracat seferberliği: enflasyon −2 |
| Tarım ve Orman | Tarım Kredi marketleri: geçim −%15 | Sulama (il): o ilde geçim −%5, il gelişir |
| Ulaştırma ve Altyapı | Toplu taşıma indirimi: geçim −%5, taşınma −%30 | Hızlı tren (il): il gelişir, o ile taşınma yarı fiyat |
| Çalışma ve Sosyal Güvenlik | İstihdam paketi: maaşlar +%10 | Esnaf kredisi: maaş +%5, geçim −%5 |

Etkiler üst üste biner; indirimler en fazla %90'dır.

### Parti kuruluş ücreti ve il teşkilatları
- **Kuruluş ücreti (31.10.2026).** Başvuran 500.000 ₺ × fiyat düzeyi harç öder; ayrıca 1.000.000 ₺ × fiyat düzeyi kuruluş fonu gerekir (kurucular emanete katkı yapar, eksiğini başvuran tamamlar; fon partinin kasasına geçer). Ücretler parti kurma ekranında, seçmen kartında ve Fiyat Tarifesi'nde görünür. Ayrıntı: bölüm 21.
- **Genel merkez.** Kurucunun ilinde partinin ilk il teşkilatı olarak açılır.
- **Kuruluş düşerse** (10 gün içinde yeterli kurucu toplanamazsa ya da başvuru iptal edilirse) harç alınmaz; fona yapılan bütün katkılar sahiplerine iade edilir.
- **İl teşkilatı.** Parti yalnızca teşkilatı olan illerde milletvekili ve belediye başkanı adayı gösterebilir (gerçekte de partiler teşkilatlandıkları yerde seçime girer). Teşkilatı genel başkan ya da yardımcıları açar; il binasının bedeli parti kasasından bir kez ödenir: küçük ilde 10.000, orta ilde 20.000, büyük ilde 30.000 ₺ (× fiyat düzeyi). O ildeki üyelere bildirim gider. Parti sayfasında hangi illerde teşkilatlı olduğu görünür.
- Oyunla gelen 5 parti 81 ilde teşkilatlıdır. Bu özellikten önce kurulmuş partiler, üyelerinin, adaylarının ve seçilmişlerinin bulunduğu illerde teşkilatlı sayıldı (kimsenin adaylığı güncelleme yüzünden düşmedi).
- Yönetici teşkilat şartını panelden kapatabilir.

### Para gönderme
- Seçmen kartı hazır oyuncu, başka bir oyuncuya cüzdanından para gönderebilir (oyuncu kartında ya da Banka ekranında "Para gönder"). İsteğe bağlı 100 karakterlik not yazılır.
- Alıcıya bildirim gider; iki tarafın hesap hareketlerinde görünür. Gönderilen para geri alınamaz.
- En az 100 ₺; günde en fazla 1 aylık asgari ücret (yönetici katsayıyı değiştirebilir).
- Aynı cihazda açılmış hesaplar arasında, seni engellemiş oyuncuya ve gecikmiş kredi borcun varken gönderilemez. Böylece çoklu hesapla para toplanamaz.

### Banka
Faizler enflasyona bağlıdır. **Politika faizi (yıllık) = enflasyon + 5 puan** (en az %10; reel faiz puanını yönetici ayarlar). Oranlar aylık gösterilir:

| Ürün | Faiz (aylık) | Enflasyon %35 iken |
|---|---|---|
| Vadesiz hesap | politika ÷ 12 × 0,5 | %1,67 |
| Vadeli 7 gün | politika ÷ 12 × 0,8 | %2,67 |
| Vadeli 30 gün | politika ÷ 12 × 0,95 | %3,17 |
| Kredi | politika ÷ 12 × 1,6 (kredi notuna göre ×0,9–1,2) | %5,33 |

- **Vadesiz hesap:** İstenildiği an yatırılır ve çekilir. Faiz saat saat işler, para hesapta durduğu kadar kazandırır; işleyen faiz her gece 00:00'da hesaba eklenir.
- **Vadeli hesap:** En az 1.000 ₺, 7 ya da 30 gün, aynı anda en fazla 3. Faiz açılışta sabitlenir; vade dolunca anapara ve faiz cüzdana yatar. Vadeden önce bozulursa durduğu gün kadar vadesiz faizi verilir.
- **Mevduat tavanı:** Kişi başı 2.000.000 ₺ × fiyat düzeyi. Bankadaki para da servet vergisine sayılır.
- **Kredi:** Seçmen kartı hazır oyuncu çeker. Vade 7, 15 ya da 30 gün; aynı anda tek kredi. Faiz basittir: geri ödeme = tutar × (1 + aylık faiz × gün / 30). Ertesi geceden başlayarak her gece eşit taksit önce cüzdandan, yetmezse vadesiz hesaptan otomatik ödenir. Ara ödeme ve erken kapama yapılabilir; erken kapamada işlememiş günlerin faizi alınmaz.
- **Kredi limiti** = aylık asgari ücret × statü katsayısı (Yeni Gelen 0,5 · Vatandaş 1 · Saygın 1,5 · Kanaat Önderi 2 · Duayen 3 · Yaşayan Efsane 4) × görevdeyse 1,5 × kredi notu katsayısı.
- **Kredi notu** (0–1900, başlangıç 1100): zamanında kapatılan kredi +60, ödenmeyen her gün −40, yasal takip −250. 700'ün altında kredi verilmez; 1100'ün altında limit yarıya iner ve faiz %20 artar, 1500 üstünde limit 1,5 kat (1700 üstünde 2 kat), faiz %10 düşer.

**Ödemeyenin cezası:**
1. Ödenmeyen tutara her gün **%1 gecikme faizi** eklenir, kredi notu düşer, oyuncuya bildirim ve gündemde uyarı gider.
2. Gecikmiş borç varken bankadaki para **bloke** olur; oyuncu para gönderemez, partiye ya da şehre bağış yapamaz, vadeli hesap açamaz.
3. **3 gün üst üste** ödenmezse kredi **yasal takibe** düşer: vadeli hesaplar bozulup borca sayılır, toplanan maaşın **yarısına haciz** konur, kıdem 5 puan düşer, oyuncu kartında herkese **"Takipteki borçlu"** yazar, Gündem'de haber çıkar.
4. Takipteki borç kapanınca haciz kalkar ama 30 gün yeni kredi verilmez.

### Parti kasası
- Aday adaylığı ücretleri, üye bağışları ve hazine yardımıyla dolar. Hazine yardımı son genel seçimde %3'ü geçen partilere oy oranıyla dağıtılır.
- Genel başkan kasadan üyelerine **kampanya desteği** gönderir ve aday ücretlerinin çarpanını ayarlar.
- Kasa hareketleri, partinin seçim beyannamesi ve iktidardaysa hükümet karnesi parti sayfasında herkese açıktır.

### Kalıcılık: oyun hiç sıfırlanmaz
- **Kurulum dosyası.** Her güncelleme tek işlem olarak çalışır:
  - Önce yedek alınır (son 5 yedek tutulur).
  - Oyuncu verisinin parmak izi çıkarılır: hesaplar, makamlar ve sahipleri, cüzdanlar, partiler, seçimler, oylar, kanunlar, mülkler, ülke ve il durumu, kurallar.
  - Sonda parmak izi yeniden karşılaştırılır; tek fark güncellemeyi iptal eder.
  - Hiç oyuncu yokken (ilk kurulum ya da sıfırlama) başlangıç verileri serbestçe yüklenir.
- **Silme koruması.** Oyun tabloları TRUNCATE ile boşaltılamaz; DROP TABLE ve DROP COLUMN, olay tetikleyicisiyle engellenir.
- **Sahibin araçları.** Sıfırlama (`'OYUNU SIFIRLA'` cümlesiyle) ve yedeğe dönüş (`'GERİ YÜKLE'`) yalnızca SQL Editor'den yapılabilir; uygulamadan çağrılamaz. İkisi de işlemden önce otomatik yedek alır.
- **Uygulama sürümü.** `SURUM` dosyasından hem sunucuya hem uygulamaya yazılır. Yönetici "en düşük uygulama sürümü"nü yükseltirse eski telefon uygulamaları güncelleme ekranı gösterir.
- **Kurallar.** Ayrıntılı geliştirici kuralları `GUNCELLEME_KURALLARI.md` dosyasında.

### TBMM Başkanlık Divanı ve parti grupları (gerçek usul: Anayasa md. 94, TBMM İçtüzüğü)
- **Geçici Başkan.** Yeni Meclis göreve başlayınca en kıdemli milletvekili Geçici Başkan olur.
- **TBMM Başkanı seçimi.**
  - Adaylık 24 saat sürer; seçim gizli oyla yapılır, her tur 12 saattir.
  - 1. ve 2. turda dolu sandalyelerin 2/3'ü, 3. turda salt çoğunluk gerekir. 4. tur, 3. turda en çok oy alan iki aday arasındadır; en çok oy alan seçilir.
  - Tur sonuçlarında yalnızca sayılar açıklanır.
  - Aday çıkmazsa adaylık iki kez 24 saat uzar. Başkanlık boşalırsa ara seçim açılır.
- **Meclis Başkanının kısıtları.** Genel Kurul'da oy kullanamaz, kanun teklifi veremez ve imzalayamaz. Partisinin faaliyetlerine katılamaz: seçilince genel başkanlığı ve GBY'liği düşer.
- **İhtar.** Meclis Başkanı ve başkanvekilleri, Başkan seçilene kadar da Geçici Başkan, Genel Kurul'da ihtar verebilir. İhtar alan vekil 1 saat Genel Kurul'da söz alamaz.
- **Siyasi parti grubu.**
  - Gerçekte 600 sandalyede 20 vekil gerekir; oyunda eşik dolu sandalyeye oranlanır (en az 2).
  - Gruba vekilin bugünkü partisi sayılır: partisinden ayrılan vekil bağımsız kalır.
- **Başkanvekilleri ve grup başkanvekilleri.**
  - En büyük 3 grup birer TBMM Başkanvekili seçer.
  - Her grup kendi grup başkanvekillerini seçer: 2 kişi, sandalyelerin 1/6'sından büyük grupta 3 kişi.
  - Grup seçimleri 24 saat adaylık ve 12 saat oylamayla, yalnızca o partinin vekilleri arasında yapılır.
- **Grup kararı.** Grup başkanvekili ya da milletvekili olan genel başkan, oylanacak kanun için kabul, ret ya da serbest kararı alır. Karar partinin vekillerine bildirilir; karara aykırı açık oy listede işaretlenir.
- **Görev tazminatı** (vekil ödeneğine ek): TBMM Başkanı 60.000 ₺, başkanvekili 30.000 ₺, grup başkanvekili 20.000 ₺ (fiyat düzeyiyle artar).
- **Yeni sohbet kanalları.** Parti Meclis Grubu (partinin vekilleri ve genel başkan) ve TBMM Başkanlık Divanı ve Danışma Kurulu (Başkan, başkanvekilleri, grup başkanvekilleri).

### Bir insan = bir vatandaş: çoklu hesap önlemleri ve seçmen kartı
- **Sinyaller.**
  - Uygulamanın cihaz kimliği (`@capacitor/device` ya da uygulamanın ürettiği kalıcı kimlik).
  - Cihaz izi: ekran, dil, saat dilimi, tuval çizimi.
  - Bağlantı adresi (IP).
  - Hepsi gizli tuzla SHA-256 özeti olarak saklanır. Silinen hesapların ve 180 gündür kullanılmayan kayıtların izi silinir.
- **Kurallar.**
  - Aynı cihaz kimliğinde sonradan açılan hesap "inceleme bekliyor" olur. Yönetici onaylayana kadar oy kullanamaz, aday olamaz, parti kuramaz, kurucu sayılmaz.
  - Bir cihazda en fazla 2 hesap açılabilir.
  - Aynı cihazdan aynı sandıkta tek oy kullanılır; bu, onaylı hesaplar ve halk oylaması için de geçerlidir.
  - Tek kullanımlık e-posta servisleri reddedilir.
- **Zayıf sinyaller.** Cihaz izi aynı model telefonlarda çakışabilir. IP de aile, okul ya da mobil operatörde paylaşılır. Bu ikisi engel sebebi değildir; yalnızca yönetici panelinde küme olarak gösterilir. eRepublik de aynı IP'yi tek başına çoklu hesap delili saymaz.
- **Seçmen kartı.** Oy, adaylık, kurucu üyelik ve bakanlık için şartlar:
  - hesap yaşı;
  - doğrulanmış e-posta;
  - doğrulanmış cihaz;
  - tek hesap olmak;
  - en az "Vatandaş" statüsü (kıdem).
  Yerel ve genel seçimde bunlara seçmen kütüğü eklenir: ilinde en az 7 gündür kayıtlı olmak.
- **Parti kuruluşu (31.10.2026).** Başvuran en az "Saygın Vatandaş" (30 kıdem) ve 14 günlük hesap; kurucular kurulu sen dahil en az 7 kişi, aktif oyuncu sayısıyla büyür (%2), en çok 30 (Siyasi Partiler Kanunu). Kurucu üyeler en az "Vatandaş", 7 günlük hesap, aynı cihaz değil, son 30 günde başka partinin kurucusu değil. Ayrıntı: bölüm 21.

### Belediye arsası ihalesi ve imar barışı: oyuncuya doğrudan karşılık
- **Arsa ihalesi.**
  - Başkan arsayı 48 saatlik açık artırmaya çıkarır. Açılış fiyatı, ilin büyüklüğü ve gelişmişliğiyle belirlenir.
  - Yalnızca o ilde yaşayan oyuncular pey sürebilir; başkan katılamaz.
  - Teklif teminat olarak cüzdandan alınır, teklif geçilirse iade edilir. Son 10 dakikadaki teklif süreyi uzatır.
  - Kazanan arsa sahibi olur ve her gün bedelin binde 4'ü kadar kira alır (yaklaşık 250 günde amorti).
  - Kasaya bedele göre 6 günlük taban gelir civarında para girer. Şehrin geri kalanı için yeşil alan azalır: gelişmişlik −1, memnuniyet −3.
- **İmar barışı.** Kasaya 4 günlük gelir girer. Hemşehrilerin geçim masrafı 14 gün %8 düşer. Buna karşılık gelişmişlik −3 olur: ildeki maaşlar kalıcı olarak yaklaşık %1,2 azalır.

### Mevzuat, anayasa değişikliği ve halk oylaması
Oyuncuların cüzdanına doğrudan dokunan kurallar ("Devlet › Mevzuat"). Yetki sırası gerçekteki gibidir: **Anayasa › Kanun › Cumhurbaşkanlığı kararnamesi**.
- Cumhurbaşkanı kuralı kararnameyle değiştirir; Meclis aynı konuyu kanunla düzenlerse artık kararname çıkarılamaz. Kararname kanunla iptal edilirse kural bir önceki hâline döner.
- Anayasaya bağlanan kural ne kanunla ne kararnameyle değişir; ancak yeni bir anayasa değişikliğiyle.

| Kural | Tür | Oyuncuya | Devlete |
|---|---|---|---|
| Servet vergisi (‰0-10) | gelir | 250.000 ₺ üstü servetten günlük kesinti | her ‰1 günde +0,3 milyar ₺; büyüme düşer |
| Sandığa gitmeyene ceza (0-5.000 ₺) | yaptırım | oy kullanabilecekken kullanmayana bir kez | katılım artar, memnuniyet biraz düşer |
| Yeni vatandaşa hoş geldin hibesi (0-50.000 ₺) | kolaylık | yeni hesaba bir kez | 5.000 kişi/gün maliyet |
| Siyasi katılım fonu (%0-100) | kolaylık | aday ücretinin bu kadarını devlet öder | her %10 günde 0,04 milyar ₺ |
| Devamlılık primi tavanı (%0-60) | kolaylık | seri primi tavanı | %30 üstü enflasyon |
| Maaş kumbarası kapasitesi (6-12 saat) | kolaylık | maaş daha uzun birikir | büyüme biraz düşer |
| Meclis devamsızlık kesintisi (%0-50) | yaptırım | oylamaya katılmayan vekilin maaşından | memnuniyet artar |

- Ceza geriye yürümez: sandığa gitmeme cezası sandık açılmadan önce yürürlükte olan kurala göre kesilir.
- **Devlete para:** özelleştirme (10-100 milyar ₺, kamu varlığı 400 milyar ₺ ile sınırlı, 7 günde bir; işsizlik artar, memnuniyet düşer) ve tahvil (10-100 milyar ₺; faiz = 8 + enflasyon/2, 60 günde faiziyle geri ödenir; borç stoku en fazla 300 milyar ₺).
- **Anayasa değişikliği:**
  - Bir milletvekili teklif eder ve 24 saatte dolu sandalyelerin 1/3'ü imza vermelidir.
  - Meclis gizli oyla oylar. ≥3/5 kabul çıkarsa halk oylamasına gider. ≥2/3 kabul çıkarsa cumhurbaşkanı yayımlar ya da halkoyuna sunar; karar vermezse 48 saat sonra yayımlanmış sayılır. Anayasa değişikliği veto edilemez.
  - Maddeler: bir kuralı anayasaya bağla ya da anayasadan çıkar; cumhurbaşkanının günlük kararname sayısı (0-5; 0 yetkiyi kaldırır); gelir vergisinin anayasal tavanı (%20-45).
- **Halk oylaması:**
  - En az 24 saat kampanya süresi vardır; oylama belirlenen gün 08:00-20:00 arasındadır.
  - Seçmen kütüğü halk oylaması kararıyla kesinleşir.
  - Oy gizlidir: kimin oy kullandığı ve sandıktaki Evet/Hayır sayısı ayrı tablolarda tutulur, birbirine bağlanamaz.
  - Geçerli oyların yarısından fazlası Evet ise değişiklik yürürlüğe girer; sonuç il il açıklanır. Oy kullanmak +3 kıdem puanı kazandırır.
- **Belediye meclisi kararları:**
  - Emlak vergisi (0-300 ₺/gün) belediye kasasına gelir getirir, ildeki memnuniyeti düşürür.
  - Hoş geldin desteği (0-20.000 ₺) ile yerleşene her ilde bir kez ödenir ve kasadan düşer.
  - Gelir işlemleri: imar barışı (kasaya 4 günlük gelir, gelişmişlik −3) ve belediye arsası satışı (6 günlük gelir, gelişmişlik −1, memnuniyet −3).
- **Vaatler:** Her kural için CB adayı, vekil ve belediye başkanı vaat türleri vardır ("servet vergisini kanunla belirleyeceğim", "anayasa teklifine imza vereceğim", "emlak vergisini indireceğim"…). Bunlar söz karnesine işlenir.
- **Bakan atama:** Cumhurbaşkanı görev süresi boyunca istediği oyuncuyu arayıp bakan atar, istediği an görevden alıp yerine başkasını atar. Arama listesinde kimin atanabileceği ve kimin başka görevi olduğu görünür.

### Boş makam kuralı: hiçbir koltuk sahipsiz kalmaz
- **Bakanlık boşsa** cumhurbaşkanı vekâleten yönetir; o bakanlığın icraatlarını kendisi yapar (Resmî Gazete'de "… vekâleten Cumhurbaşkanı …" yazar). Bakan atanınca vekâlet sona erer.
- **Seçimde kazanan çıkmazsa** (kimse aday olmadıysa) görevdeki belediye başkanı ya da cumhurbaşkanı, yenisi seçilene kadar yerinde kalır; kabine de cumhurbaşkanı değişene kadar dağılmaz. Yeni kazanan çıkan yerde görev devredilir. Meclis ise liste usulüyle topluca yenilenir.
- **Genel başkansız parti kalmaz:** üyelerden biri "Genel başkanlığı üstlen" ile gönüllü olabilir; kurultayda aday çıkmazsa başka görevi olmayan en kıdemli üye otomatik genel başkan olur. Üyesi olmayan parti boş kalır, zorla kimse atanmaz.
- **Meclis eşikleri** dolu sandalye sayısına göre hesaplanır; boş sandalye karar sayısını bozmaz.
- **Boş Makamlar panosu** (Hükümet sekmesi): boş bakanlıklar, belediyeler, Meclis sandalyeleri, genel başkansız partiler ve sıradaki seçimler.

### Vaatler: her biri ölçülebilir ve karşılıklı
Her makam yalnızca **kendi yetkisindeki** şeyi vaat edebilir. Örneğin vekil asgari ücreti artıramaz, ama partisi seçim beyannamesinde vaat edebilir.

| Kim | En fazla | Ne vaat edebilir |
|---|---|---|
| **Parti (seçim beyannamesi, genel başkan yazar)** | 5 | Asgari ücret hedefi, gelir vergisi hedefi, kıdem primi, sosyal destek, taşınma desteği, bayram ikramiyesi ve **24 bakanlık icraatının hepsi** (her icraatın kendi vaadi vardır; yapılınca tutulmuş sayılır) |
| **Milletvekili adayı** | 3 | Vergi tavanını indiren bütçeye, belediye payını artıran bütçeye, partilere yardımı azaltan bütçeye, barajı indiren seçim kanununa kabul oyu vermek; Meclis oylamalarının en az %50-100'üne katılmak; en az 1-5 kanun teklifi vermek |
| **Belediye başkanı adayı** | 4 | Kent vergisini indirmek, hemşehri desteği, kent lokantası, ücretsiz ulaşım, kira yardımı, istihdam ofisi, altyapı, raylı sistem |
| **Genel başkan adayı** | 2 | Aday ücretlerini düşürmek, adaylara kampanya desteği, parti üye sayısını artırmak, parti kasasını büyütmek |

**Karşılıksız vaat verilemez.** Aday vaatleri seçerken sistem maliyetini ülkenin ya da ilin mali alanıyla karşılaştırır:
- **Karşılığı var:** Maliyet mali alanın yarısından az, enflasyon etkisi en fazla 3 puan.
- **Bütçeyi zorlar:** Maliyet mali alan içinde, enflasyon etkisi en fazla 6 puan. Kaydedilebilir ama seçmen görür.
- **Karşılıksız:** Kaydedilemez.

Vergi artışı vaadi gelir yaratır, yani başka vaatlere yer açar.

**Vaat karnesi:** Seçilen adayın vaatleri her gece kontrol edilir.
- Sürekli vaatler (asgari ücret, kent vergisi, hizmetler) için "kaç gündür tutuluyor" sayılır.
- Tek seferlik vaatler (ikramiye, yatırım, kanun oyu) yerine getirilince "tutuldu" olur.

Karne oyuncu kartında, parti sayfasında, il sayfasında ve belediye ekranında herkese açıktır.

**Söz tutmanın karşılığı (itibar):** Vaat sonuçlanınca oyuncunun kişisel itibarına ve kıdem puanına işlenir. Kıdem puanı statüyü, statü de maaşını belirlediği için vaat tutmanın doğrudan parasal karşılığı vardır.
- **Tek seferlik vaat yapılınca** hemen **+5 kıdem puanı**. Görev bitene kadar yapılmazsa **−3** (puan 0'ın altına inmez).
- **Sürekli vaat** görev bitince değerlendirilir: günlerin en az yarısında tutulduysa **+5**, değilse **−3**.
- Cumhurbaşkanı partinin beyannamesindeki vaatlerin sorumlusudur; vaatler onun karnesine işlenir.
- Oyuncunun **söz karnesi** (tutulan / toplam vaat) oyuncu kartında, aday listelerinde ve Hayat ekranında görünür. En az 3 vaat sonuçlanmışsa tutma oranı %70 ve üstüyse **Sözünün Eri**, %30'un altındaysa **Lafta Kalan** rozeti çıkar.
- Her vaat tek bir kez işlenir, tekrar saymaz.

## 8. Sunucu: veriler nerede, nasıl saklanıyor?

**Telefon yalnızca ekrandır.** Oyunun tüm verileri tek bir merkezde, internetteki bir veritabanında durur. Herkes aynı Türkiye'yi görür ve oylar tek yerde sayılır. Bu yüzden sunucu şart.

**Önerim: Supabase.** Hazır bir hizmet; sunucu bakımı, güvenlik güncellemesi ve yedekleme onlarda.
- Veritabanı **PostgreSQL**. Bankaların da kullandığı, sağlam bir veritabanı türü.
- Bölge: **Frankfurt**, Türkiye'ye en yakın veri merkezi.
- E-postayla kayıt ve giriş sistemi hazır geliyor.
- Seçim motorunu her dakika çalıştıran zamanlayıcı (pg_cron) var.

**Sunucuda neler saklanıyor:**

| Kayıt | İçerik |
|---|---|
| Hesaplar | E-posta ve şifrelenmiş şifre (Supabase tutar) |
| Profiller | Kullanıcı adı, il, parti, katılım tarihi |
| İller | 81 il ve vekil sayıları |
| Partiler | Ad, kısa ad, renk, amblem, genel başkan, 6 yardımcı |
| Seçimler | Takvim, adaylar, oylar, sonuçlar |
| Makamlar | Kim, hangi görevde, ne zamandan beri |
| Kabine | 12 bakanlık ve atamalar |
| Sosyal | Sohbet mesajları, özel mesajlar, propaganda yayınları, bildirimler, engellemeler, şikâyetler |
| Devlet | Ülke göstergeleri ve günlük geçmişi, il gelişmişlikleri, bakanlık kasaları ve icraatları, kanun teklifleri ve vekil oyları, cumhurbaşkanlığı kararları, ittifaklar, Resmî Gazete |
| Vatandaş | Cüzdan, maaş kumbarası, seri ve kıdem, hesap hareketleri (60 gün), süreli etkiler, belediye hizmetleri, parti kasası ve hareketleri, il teşkilatları, vaatler ve karneleri, satın almalar |
| Banka | Vadesiz hesaplar ve kredi notları, vadeli hesaplar, krediler, banka hareketleri (90 gün) |
| Yönetim | Moderatörler ve yetkileri, moderasyon günlüğü |
| Haberler | Oyun içi olay günlüğü |

**Güvenlik:**
- Tablolar internete kapalıdır.
- Uygulama yalnızca oyunun kurallarını uygulayan fonksiyonları çağırabilir: "oy ver", "aday ol", "mesaj yaz" gibi. Kural dışı bir işlem sunucuda reddedilir.
- **Oylar gizlidir.** Kimin kime oy verdiği hiçbir ekranda gösterilmez.

**Maliyet:**
- Tasarım ve test aşamasında **ücretsiz plan** yeterli.
- Canlıya çıkınca **Pro plan**, ayda yaklaşık 25$. Günlük yedekleme içeriyor ve projenin durdurulma riski olmuyor. Güncel fiyatı supabase.com/pricing sayfasından kontrol et.
- On binlerce oyuncuya kadar bu plan yeter.

**Alternatif: kendi sunucun.** Ayda 5–10€'luk bir sanal sunucuya (VPS) kurmak da mümkün. Ama güncelleme, güvenlik ve yedekleme senin sorumluluğuna geçer. Teknik olmayan biri için önermiyorum.

**KVKK:**
- Veriler Frankfurt'ta durduğu için yurt dışına aktarım sayılır. Bu durum uygulamadaki aydınlatma metninde yazılı.
- 2024 KVKK değişikliğinden sonra yurt dışı aktarımda standart sözleşme ve Kurul'a bildirim yükümlülükleri olabilir. Bunu bir avukata teyit ettir.

**Telefona gelen bildirimler (push):** Google Firebase üzerinden gider ve ücretsizdir. Nasıl çalıştığı 6. bölümde, kurulumu KURULUM.md'nin 9. bölümünde.

## 9. Sıradaki adımlar

- **Sunucuyu açmak:** KURULUM.md, 1–6. bölümler.
- **Push kurulumu:** KURULUM.md, 9. bölüm.
- **Reklam ve satın alma:** KURULUM.md, 10. bölüm (AdMob ve RevenueCat).
- **Mağaza:** Capacitor ile paketleme ve mağazaya gönderim.
- **Denge:** Gerçek oyuncularla ekonomi, propaganda ve belediye dengesinin ayarlanması.

## 10. Oyuncu deneyimi güncellemesi (2026-10-09)

**Neden:** Gerçek oyuncuların ilk günlerde sıkılmaması, az oyuncuyla da seçimlerin yarış olması ve çalışan/öğrenci oyuncuların takvimi kaçırmaması için.

### Yeni oyuncu
- Seçmen kartı için önerilen kıdem şartı **3** (her gün maaş toplamak +1). Hesap yaşı şartı (3 gün) aynen sürer.
- Seçmen kütüğü beklemesi (ilde 7 gün) yalnızca **il değiştirenlere** uygulanır; hesabı açtığın ilk ilde bekleme yoktur.
- Gündem'de yeni oyuncuya **İlk adımlar** listesi: ilk maaş, portre, partiye katılma, il kahvesinde tanışma, haftalık anket, ilk oy.

### Meclis oyuncu sayısına göre ölçeklenir
- Genel seçimin başvuruları açılırken sandalye sayısı = son 14 günde oyuna giren oyuncu × **meclis ölçeği** (varsayılan 0,25; yönetici panelinden değişir, 0 = kapalı).
- En az 81 (her ile bir), en fazla anayasadaki sayı (600). Sandalyeler illere nüfus ağırlığıyla dağıtılır. Gündem'e haber olur.

### Görev ihmali
- 3 gün oyuna girmeyen **bakan** ve **genel başkan yardımcısı**, 7 gün girmeyen **cumhurbaşkanı**, **belediye başkanı** ve **genel başkan** görevden düşer.
- Önce bildirimle uyarılır (atamada 1, seçilmiş görevde 2 gün süre). Seçilmiş makam boşalınca olağanüstü seçim takvimi açılır.
- Genel başkansız kalan partide otomatik halef önce son 7 günde oyuna girmiş üyeler arasından seçilir. Süreler yönetici panelinden değişir (0 = kapalı).

### Mitingler
- Bir seçimde aday olan oyuncu, oylama bitmeden ilinde **1 saatlik** miting düzenler (15 dk–3 gün sonrasına). Bedeli 1.500 ₺ × il büyüklüğü × fiyat düzeyi.
- Aynı ilde aynı saatte tek miting olur. Başlayınca ildeki herkese bildirim ve push gider; ildeki oyuncular katılır, katılan günde bir kez **+1 kıdem** kazanır.
- Bitince "X, İzmir mitinginde N kişiye seslendi" haberi Gündem'e düşer.

### Parti mitingi: il dışı miting yetkisi (2026-10-09, modül 50)
- **Genel başkan** 81 ilin herhangi birinde parti adına miting düzenler; ikametgâhı değişmez.
- **Genel başkan yardımcıları**, genel başkan kendilerine "miting yetkisi" verirse aynı hakka sahip olur. Genel başkan bu yetkiyi dilediği yardımcıya verir, dilediği an geri alır.
- Yetki geri alınırsa (ya da düzenleyen görevini veya üyeliğini kaybederse) başlamamış mitingleri iptal olur, bedeli ödeyene iade edilir.
- Bedel aday mitinginin bedelidir (ilin büyüklüğüne göre). Parti kasası ya da düzenleyenin kendi cebi öder; kasa yetmezse miting açılmaz.
- Sınırlar: her yetkili günde en fazla 1 parti mitingi; aynı partinin aynı ildeki iki parti mitingi arasında en az 3 gün; genel, belediye ve cumhurbaşkanlığı seçimlerinin oy verme saatlerinde parti mitingi yapılmaz.
- Başlayınca o ildeki herkese ve partinin tüm üyelerine bildirim gider. Kürsü, tepki, slogan ve coşku canlı meydanla aynıdır; katılıp tepki verenler o ilde yaşayanlardır, diğer illerden üyeler canlı izler.
- Mitingin etkisi harcanan paraya bağlı değildir; meydanın coşkusu katılan gerçek oyuncuların tepkilerinden hesaplanır.

### Dernekler ve sivil toplum (2026-10-10, modül 55)
- Alt menüde "Dernekler" sekmesi. Her oyuncu bir dernek kurabilir (kuruluş harcı, hesap en az 3 günlük); kurucu başkan olur, ili merkez şubedir. Bir oyuncu en fazla 5 derneğe üye, yalnız birinin başkanı olabilir.
- Başkan en fazla 4 kişilik yönetim kurulu atar ve başkanlığı devredebilir. Son üye ayrılırsa dernek kapanır.
- Herkes bağış yapabilir; kasa ile il şubeleri açılır (küçük/orta/büyük il 1.000/2.000/3.000 ₺ × fiyat düzeyi).
- Başkan ve yönetim kurulu: basın açıklaması, bildiri, bir partiye ya da adaya destek açıklaması ve şubeli ilde bir saatlik protesto. Konu bir kanun, parti, dernek ya da oyuncu olabilir; ilgilisine bildirim gider; her eylem Gündem'e haber olur.
- Protestoya o ilde yaşayan herkes katılabilir; başlayınca ildekilere ve derneğin üyelerine haber gider, bitince katılım haberi çıkar.
- Sınırlar: dernek başına günde 3 açıklama ve 1 protesto, aynı ilde 3 günde 1 protesto, seçimlerin oy saatlerinde protesto yok.

### İttifak teklifi ve ortak aday (2026-10-10, modül 54)
- Genel başkan başka bir partinin sayfasından ittifak teklif eder. Partisi bir ittifakta değilse ittifak, verdiği adla kurulur. Karşı partinin genel başkanı kabul ya da reddeder.
- İttifak ortakları cumhurbaşkanlığı ve il il belediye başkanlığı için ortak aday önerir. Öneren ve kabul eden partilerin kendi adayları çekilir, ortak adayı desteklerler. Reddeden ortak kendi adayıyla yarışır. Herkes kabul edince ortak aday ilan edilir.
- Öneri zamanı: cumhurbaşkanlığı için ayın 19-25'i, belediye için ön seçim sonucundan oy verme başlayana kadar. Genel seçim döneminde ittifak kurulamaz, değiştirilemez (önceki kural).

### Genel başkan yardımcılarının görevleri (2026-10-10, modül 52)
- Genel başkan her yardımcısına bir görev alanı verir: Teşkilattan, Seçim İşlerinden, Siyasi ve Hukuki İşlerden, Ekonomi Politikalarından, Mali İşlerden, Tanıtım ve Medyadan, Dış İlişkilerden, Yerel Yönetimlerden, Sosyal Politikalardan, Halkla İlişkilerden Sorumlu ya da kendi yazdığı bir alan.
- Unvan her yerde görünür ("CYP Teşkilattan Sorumlu Genel Başkan Yardımcısı"). Yardımcı değişince görev sıfırlanır.
- Beş görev yetki verir (modül 53); genel başkan her işi yapmaya devam eder:
  - Teşkilattan Sorumlu: il teşkilatı açar, Parti İl Başkanı atar ve görevden alır. Bu görevde biri varsa il teşkilatını yalnız genel başkan ve o açar; yoksa tüm yardımcılar açabilir.
  - Seçim İşlerinden Sorumlu: ayrıca miting yetkisi beklemeden 81 ilde parti mitingi düzenler, aday tanıtır.
  - Tanıtım ve Medyadan Sorumlu: grup konuşması yayımlar, aday tanıtır.
  - Mali İşlerden Sorumlu: parti kasasından üyeye kampanya desteği verir, adaylık ücretlerini ayarlar.
  - Siyasi ve Hukuki İşlerden Sorumlu: üyeyi disipline sevk eder; genel başkanı sevk edemez.
- Diğer görevler ve serbest yazılanlar yalnız unvandır.
- Mitingde o ilde yaşayan oyuncu bir söze tepki verdiğinde mitinge kendiliğinden katılmış sayılır.

### Bağımsız adayın partiye katılması (2026-10-09, modül 50)
- Bağımsız aday, oy verme başlamadan önce istediği an bir partiye katılabilir (ya da parti kurabilir). Katıldığı anda bağımsız adaylığı düşer; başvuru harcı iade edilmez. Uygulama katılmadan önce uyarı gösterir.
- Başvuru süresi hâlâ açıksa yeni partisinden aday adayı olabilir; kapanmışsa o dönem aday olamaz.
- Oy verme sürerken pusula kilitlidir; bağımsız aday ancak sandık kapandıktan sonra katılabilir.
- Seçilmiş bağımsız vekil partiye katılırsa vekilliği sürer; Meclis grubu üyeliğe göre sayıldığı için sandalyesi yeni partisine geçer.

### Para hediyesi
- Oyuncuya, şirkete ya da gazeteye aktarılan para (hediye + banka havalesi birlikte) **günlük aktarma sınırına** tabidir ve seçmen kartı ister.
- Partiye, şehre ve hazineye bağış sınırsızdır; kıdem kazancı yalnız bu kamusal bağışlardan (günde en fazla 1).
- Hediyeler yönetici panelindeki transfer listesinde "hediye" kanalıyla görünür.

### Kimlik ve tarih
- **Portre:** oyuncu ten, saç (başörtüsü dahil), bıyık/sakal, gözlük, kıyafet ve arka plan seçerek kendi portresini çizer; 160 karakterlik biyografi yazar. Oyuncu kartında, sohbette, sonuçlarda görünür.
- **Parti kimliği:** genel başkan partinin ekonomi (devletçi ↔ serbest piyasa) ve toplum (özgürlükçü ↔ muhafazakâr) konumunu ve sloganını belirler (konum günde bir kez değişir). Partiler ekranında siyasi harita; "Hangi parti bana yakın?" 8 soruluk test.
- **Cumhuriyet tarihi** (Devlet › Tarih): cumhurbaşkanları, Meclis dönemleri, kanunlar, partiler ve rekorlar. Oyun hiç sıfırlanmadığı için tarih birikir.

### Arayüz kimliği: "Seçim gecesi stüdyosu"
- Lacivert stüdyo zemini; oy pusulası kâğıdı; **tercih mührü moru** oyuncunun eylemleri için; **canlı kırmızısı** sandık açık / son dakika için; diğer renkleri partiler taşır.
- Başlık ve rakamlar **Kurul Display** (TeX Gyre Heros Cn'nin Türkçe alt kümesi, GUST lisansı) — dosyaya gömülü, internet istemez. Metin telefonun kendi yazı tipi.
- Oy verme kâğıt pusula üzerinde "TERCİH" mührüyle; sonuçlar seçim gecesi yayını gibi sahnelenir (sandalye şeridi, yarım daire Meclis, il haritası).
- Gündem: kayan haber şeridi, sıradaki an için büyük geri sayım, ayın seçim takvimi şeridi, "Bugün" yapılacaklar listesi; dakikalık yenilemede kaydırma konumu korunur.

### Düzeltilen hatalar
- Genel seçim sayımı "aday_id is ambiguous" hatasıyla duruyordu; ilk genel seçimde motor kilitlenirdi.
- Yedekten dönüş, kimlik sütunu "generated always" olan tablolarda hata veriyordu.
- Tam kurulum dosyası temiz bir veritabanında çalışmıyordu.

## 11. Şirket halka arzı ve yatırım hesaplayıcısı (2026-10-10)
- **Haftalık ortalama net kâr** = sermaye × sektör oranı − sermaye × %5,25 − asgari ücret (sektör oranları: tarım %12, sanayi %15, teknoloji %20, ticaret %14, inşaat %18, medya %16, banka %8). Örnek: 950.000 ₺ teknoloji şirketi, asgari 28.075 ₺ → 112.050 ₺/hafta; 1.950.000 ₺ yatırımla sermaye 2.900.000 ₺ → 399.675 ₺/hafta.
- **Hesaplayıcı** (Şirketlerim › şirket kartı › Hesapla): yatırım tutarı ve şirket değerine göre yeni sermaye, haftalık kâr, ortakların yeni payı, kişiye düşen haftalık tutar, yatırımcının geri kazanma süresi.
- **Halka arzı başlatma:** şirketin en az %50'sine sahip ortak. Şirket değeri (arz öncesi) en az sermaye, en çok max(2 × sermaye, 52 × haftalık ortalama net); önerilen 26 haftalık kâr. En fazla %49 pay satılır, sermaye 100 milyon ₺'yi aşamaz. Asgari başarı tutarı hedefin %25/50/75/100'ü; talep süresi 24/48/72 saat. Bir şirketin aynı anda tek açık arzı olur.
- **Talep:** başka oyuncular en az 1.000 ₺ talep verir; para arz bitene kadar emanette tutulur, arz sürerken geri alınabilir. Başlatan kendi arzına talep veremez.
- **Sonuç:** hedef dolunca hemen, değilse süre bitince. Asgariye ulaşıldıysa toplanan para sermayeye ve kasaya girer, eski ortakların payı değer/(değer + toplanan) oranında seyrelir, yatırımcılar tutar/(değer + toplanan) oranında ortak olur; şirket "halka açık" olur. Ulaşılamazsa ya da iptal edilirse herkese iade. Toplanan para sermaye olduğu için kâr payı olarak dağıtılamaz; ortaklar haftalık kârdan paylarına göre alır.
- Herkes açık arzları Şirketler › Halka arzlar ekranında görür; Gündem'e haber düşer, yatırımcılara ve ortaklara bildirim gider.


## 12. Rekabetçi şirketler, kamu ihaleleri ve sektör politikası (2026-10-11, modül 84)

### Rekabetçi şirketler
- Beş tür: **Özel Okul** (Millî Eğitim), **Özel Hastane** (Sağlık), **Market Zinciri** (Ticaret), **Ulaşım Firması** (Ulaştırma), **Enerji Santrali** (Sanayi). Asgari sermaye 200-300 bin ₺.
- Şirket bir ilde faaliyet gösterir. O ilin haftalık pazarı = sektör tabanı × il ağırlığı (vekil sayısı ve gelişmişlik) × ekonomi (büyüme, memnuniyet) × sektör politikası × kriz çarpanı.
- Pazar, aynı ildeki aynı türdeki oyuncu şirketleri arasında **çekiciliğe** göre paylaşılır: çekicilik = (1 + 0,35 × kalite + marka/100) / fiyat^esneklik. Kamu hizmeti (ilgili bakanlığın kasası) müşterinin bir kısmını tutar.
- Sahibin kararları: **fiyat** (ucuz ×0,8 / orta / premium ×1,3), **kalite bütçesi** (0-3, sermayenin %0-3,6'sı/hafta), enerjide **kaynak** (kömür ucuz ama ilin memnuniyetini düşürür, doğalgaz dolar kuruna bağlı, güneş-rüzgâr pahalı ama marka ve gelişim getirir). Market ve enerjide fiyat çok önemlidir, okul ve hastanede kalite.
- Gelir sermayenin kapasitesiyle sınırlıdır (haftada sermayenin %25-30'u). Giderler: sabit gider, personel (asgari ücret × ölçek), kalite, yakıt.
- Belediye **ruhsat harcı** (%0-8) il kasasına, **kurumlar vergisi** (%20, yalnız kârdan) hazineye gider. Her faaliyet haftası ilin gelişmişliğine katkı yapar.
- Örnek denge: tek başına orta ilde haftalık %7-10, iki rakipte ~%1, dört rakipte zarar. Küçük ilde büyük sermaye giderini karşılayamaz.
- Ekranda: 81 ilin pazar haritası (pazar, rakip sayısı, harç), haftalık tahmin, 12'li fiyat × kalite senaryo tablosu, rakiplerin fiyat/kalite bilgisi, haftalık raporlar. Ayarlar 10 dakikada bir, il taşıma 7 günde bir (bedel sermayenin %10'u, marka %60 erir).
- Kasası sıfırlanan şirket **iflas eder**; kasa sermayenin %25'inin altına inince ortaklara uyarı gider.

### Kamu ihaleleri
- **Belediye başkanı** il kasasından: park, kreş, yol, metro (metro en az 1 teslim edilmiş iş ister). **Bakanlar** (boş bakanlıkta Cumhurbaşkanı) bakanlık kasasından, istedikleri ile: otoyol, şehir hastanesi, okul, OSB, sulama, emniyet, adliye, meslek merkezi, lojistik merkezi, askerî tesis, kongre merkezi, vergi dairesi.
- Bütçe ilan anında kasadan ayrılır. Teklif süresi 12/24/48 saat; aynı anda en fazla 3 ihale.
- Yalnız **inşaat şirketleri** teklif verir (kapalı zarf; teklif yaklaşık maliyetin %40-100'ü). En düşük geçerli teklif kazanır; artan para kasaya döner. İhaleyi açan, ortağı olduğu şirkete ihale veremez.
- Kazanan **yapım yöntemini** seçer: standart (maliyet %70), kaliteli (%85, etki ×1,35, deneyim puanı), tasarruflu (%55, etki ×0,6). Tasarruflu iş teslimde %35 (inşaatta sıkı denetim varsa %60) ihtimalle yakalanır: hakedişin yarısı ödenmez, %20 ceza, 14 gün ihale yasağı, gazete manşeti.
- Sonuç ve kazanan şirketin en büyük ortağı Resmî Gazete'de yayımlanır.

### Sektör politikası
- İlgili bakan 24 saatte bir: **teşvik** (7 gün, sektör pazarı ×1,15, bakanlık kasasından 2 milyar ₺) ya da **sıkı denetim** (7 gün, ×0,92; kalitesiz hizmete ve kömüre gelirin %12'si ceza). Eski türlere de işler: Tarım → tarım, Sanayi → sanayi ve teknoloji, Ticaret → ticaret, Ulaştırma → inşaat.

## 13. Ekonomi planı (2026-10-11, modül 85 ile birlikte)

### Amaç
Ekonomi, siyaset oyununun yakıtı olsun: oyuncu parayı şirketiyle kazanır, partisine ve kampanyasına harcar; siyasetçinin kararı (vergi, teşvik, ihale, harç) oyuncuların cebine dokunur. Kural: **kapsamlı ama sade.** Bir şirketi yönetmek için iki karar (fiyat, kalite) yeterli; istemeyen otopilota bırakır. Angarya yok: her şey haftalık hesaplanır, sürekli girip tıklamak gerekmez.

### Dört katman
| Katman | Kim | Ne yapar |
|---|---|---|
| Vatandaş | Herkes | Maaş kumbarası, makam maaşı, geçim masrafı, kıdem, banka hesabı |
| Şirket | Girişimci oyuncular | Eski şirketler (pasif getiri), rekabetçi şirketler (ilde pazar payı), inşaat şirketleri (kamu ihalesi) |
| Piyasa | Yatırımcılar | Oyuncu bankaları, halka arz, **borsa** (halka açık şirket payları), döviz/altın/hisse, emlak |
| Devlet | Seçilmişler | Hazine ve bakanlık kasaları, belediye kasası, vergi, teşvik/denetim, ihale, **Rekabet Kurumu** |

### Para nereden girer, nereye çıkar
- **Giriş (yeni para):** maaş ve makam maaşı, devlet/belediye destekleri, reklam ödülü ve mağaza paketleri, şirket faaliyet kârı, ihale hakedişi (kamu kasasından), faiz.
- **Çıkış (yok olan para):** geçim masrafı, şirket giderleri (personel, sabit gider, kalite, yakıt), adaylık ve parti ücretleri, taşınma, cezalar.
- **Kamuya aktarılan:** gelir vergisi, kurumlar vergisi (%20, kârdan), belediye ruhsat harcı (%0-8), borsa komisyonu (%0,5), Rekabet Kurumu cezaları. Kamu bu parayı ihale ve icraatla oyunculara geri döndürür.
- Ölçek: kamu kasaları milyar ₺, oyuncu parası ₺; 1 milyar kamu ₺ = 150.000 oyuncu ₺ × fiyat düzeyi.

### Denge hedefleri
| Durum | Haftalık getiri (sermayeye oran) |
|---|---|
| Eski pasif şirket | yaklaşık %5-7 (rastgele) |
| Rekabetçi şirket, ilde tek | %7-10 |
| İki rakip | %1-3 |
| Dört ve fazla rakip / yanlış il | zarar → iflas riski |
| Kamu ihalesi (standart yapım) | teklife göre %0-25 marj |
| Borsa | şirketin gerçek kârı ve oyuncuların alım-satımı belirler |

### Şirket yönetimi nasıl sade kalır
1. **Üç adımda kur:** tür seç → haritadan il seç (fırsat çubuğu) → sermaye gir.
2. **İki karar:** fiyat (ucuz/orta/premium) ve kalite (0-3). Enerjide bir de kaynak.
3. **Danışman önerisi:** sunucu 12 seçeneği hesaplar, en kârlısını "Önerilen" diye gösterir; tek dokunuşla uygulanır.
4. **Otopilot:** açıksa her hafta en kârlı ayarı kendisi seçer; bedeli gelirin %4'ü (profesyonel yönetici ücreti).
5. **Sağlık rozeti:** Kârda / Başa baş / Zararda / İflas riski. Kasa sermayenin %25'inin altına inince bildirim.

### Siyasetin ekonomiye dokunduğu yerler
| Makam | Araç | Etki |
|---|---|---|
| İlgili bakan | Teşvik / sıkı denetim (7 gün) | Sektör pazarı ×1,15 / ×0,92, kalitesize ceza |
| Ticaret Bakanı | Rekabet Kurumu soruşturması | Kartel (ildeki tüm rakipler premium) ve hâkim durumun kötüye kullanılması (tek şirket %55+ pay ve premium) → kasasının %8'i ceza |
| Belediye başkanı | Ruhsat harcı, belediye ihaleleri | İl kasası dolar; park/yol/metro ile il gelişir |
| Bakanlar | Bakanlık ihaleleri | Seçilen il gelişir, inşaat şirketleri iş alır |
| Meclis / CB | Vergi, asgari ücret | Şirket personel gideri asgari ücrete bağlıdır |

### Şirketler halkı nasıl etkiler
- **Geçim masrafı:** Bir ildeki market zincirleri ve enerji santrallerinin fiyatları o ilde yaşayan **herkesin** geçim masrafını değiştirir. Ucuz ve rekabetçi piyasa geçimi %5'e kadar düşürür, premium tekel %7,5'e kadar artırır (Vatandaş › Süreli etkiler'de "Yerel piyasa fiyatları" olarak görünür, günde bir güncellenir).
- **Enflasyon:** Ülke genelindeki market/enerji fiyat endeksi günlük enflasyona küçük bir itki verir.
- **İl gelişimi:** Her faaliyet haftası ve teslim edilen ihale ili geliştirir; kömür santrali memnuniyeti düşürür.

### Şeffaflık
- **Şirket bağışı:** Şirketin en büyük ortağı şirket kasasından bir partiye bağış yapabilir (7 günde en fazla sermayenin %20'si). Her bağış herkese açık "Siyasi bağışlar" listesinde ve Gündem'de yayımlanır.
- İhale kazananları, Rekabet Kurumu kararları ve politika değişiklikleri Resmî Gazete'ye düşer.

### Aşamalar
1. **Modül 84 (yapıldı):** rekabetçi şirketler, kamu ihaleleri, sektör politikası, ruhsat harcı.
2. **Modül 85 (bu güncelleme):** borsa, Rekabet Kurumu, şirket bağışları, danışman ve otopilot, yerel piyasa fiyatlarının geçime etkisi, piyasa raporu, paravan şirket kuralı.
3. **Sonraki adaylar:** reklam ve anket ajansı (partiler kampanya hizmetini oyuncu şirketlerinden alır), şube ağı (bir şirketin birden çok ilde şubesi), sendika ve toplu sözleşme, ihracat (Dışişleri ve Ticaret ile), sigorta şirketi.

## 14. Reklam ve anket ajansları (2026-10-11, modül 86)
- Yeni şirket türü **ajans** (sermaye en az 150.000 ₺, bir oyuncu bir ajansın çoğunluğuna sahip olabilir). Sahibi fiyat (ucuz/orta/premium) ve kalite (0-3) seçer.
- **Reklam:** parti (genel başkan, parti kasasından) ya da oyuncu (kendi cebinden) satın alır. Hedef ildeki (ya da tüm Türkiye'deki) oyuncuların Gündem'inin başında "Sponsorlu" kart olarak görünür; süre 12 + 8 × kalite saat, kalite 2+ ise başlarken bildirim. Bir ilde aynı anda en fazla 2, Türkiye genelinde 1 reklam. Gösterimler tekil sayılır.
- **Anket:** 24 saat boyunca hedefteki oyunculara "Bugün seçim olsa hangi partiye oy verirdin?" sorusu (partiler + kararsızım). Cevaplayana ajans kasasından katılım ödülü (300 + 250 × kalite ₺, havuz ücretin %40'ı; 1 günden yeni hesaplara ödül yok). Sonuç (oranlar, kararsızlar, hata payı ±98/√n) yalnız sipariş verene ve parti genel başkanına gelir; isterse yayımlar (en az 3 katılımcı). **Seçim yasağı:** oy günü ve öncesindeki 24 saatte yayımlanamaz. Aynı hedefte aynı anda tek anket.
- **Fiyat:** reklam 15.000 ₺, anket 20.000 ₺ × il büyüklüğü (küçük 1, orta 2, büyük 3, Türkiye 6) × fiyat katsayısı × fiyat düzeyi.
- **Kapasite:** aynı anda 1 + kalite + her 300.000 ₺ sermaye için 1 iş (en fazla 6).
- **Haftalık hesap:** sipariş geliri − katılım ödülleri − gider (sermayenin %3'ü + kalite × %1,2 + personel) − %20 kurumlar vergisi; kâr ortaklara. Kasa biterse iflas.
- **Marka:** her biten iş ve yayımlanan anket büyütür; müşteri 1-5 puanı (3'ün üstü artırır, altı düşürür); haftalık %5 erir.

## 15. Ekonomi güvenliği (2026-10-11, modül 88)
Haksız zenginleşmenin ana yolu, bir oyuncunun ikinci hesabıyla "meşru işlem" kılığında para taşımasıdır. Kurallar oyuncuyu yormaz; sunucuda tetikleyicilerle işler.
- **İlişkili hesap:** Aynı cihazda açılmış hesaplar birbirleriyle borsada, şirket ve pay satışında, emlakta, ortaklık teklifinde işlem yapamaz; birbirinin ihalesine giremez (ortaklardan biri ihaleyi açanla aynı cihazdaysa); birbirinin ajansından sipariş veremez; birbirinin anketine katılamaz. Banka transferi ve hediyede bu kural zaten vardı. Aile içi ortak cihaz için yönetime başvurulur.
- **Fiyat bantları:** Borsa: son işlem fiyatının ±%20'si (ilk işlemde referansın 0,5-2 katı). Şirket/pay satışı: %1 pay başına kasanın %0,5'i ile kasa/sermayenin %3'ü arası. Emlak: ilin rayiç bedelinin 0,4-2,5 katı.
- **MASAK:** Şunlar kendiliğinden kaydedilir: 24 saatte 1.000.000 ₺ (fiyat düzeyiyle) üstü gelir (yönetici hediyeleri hariç); aynı iki oyuncu arasında 7 günde 3+ alım-satım; parti kasasından 250.000 ₺ ya da kasanın %30'u üstü tek harcama; ihalenin ihaleyi açanla aynı partiden birinin şirketine gitmesi. "MASAK (ekonomi denetimi)" yetkili moderatör inceler: temiz / ihtar (bildirim) / el koyma (para hazineye, oyuncuya bildirim, Gündem'de ve herkese açık listede).
- **Ödül tavanı:** Anket katılım ödülü yalnız 7 günden eski hesaplara, kişi başı günde en fazla 3 kez.
- **Şeffaflık:** Her partinin kasa defteri herkese açık; 50.000 ₺ üstü parti harcamasında genel başkan yardımcılarına bildirim. Yönetimin dağıttığı hediyeler ve el koyma kararları herkese açık.
- Ayarlar `oyun.guvenlik_ayar`; yayın öncesi sıkı ayarlar `migrations/YAYIN_ONCESI_AYARLAR.sql`.

## 16. Belediye yönetimi: karne, kriz masası, İller Bankası (2026-10-11, modül 89 ve 91)
- **Bağış birimi:** şehre ve hazineye bağış kamu kuruyla çevrilir: 1 milyar kamu ₺ = `oyun.pazar_tl_milyar()` oyuncu ₺ (≈150.000 ₺ × fiyat düzeyi). 1.000 ₺ bağış belediye kasasına ≈6,7 milyon ₺ ekler ve işlem defterine yazılır.
- **Gece kasası:** vergi geliri kasada 60 günlük gelire kadar birikir; tavanın üstündeki para (bağış, kredi) artık kesilmez.
- **Şehir yönetimi sekmeleri:** Bütçe · Karne · Kriz · Binalar · Ekonomi · İller Bankası · İşlem defteri. Tutarlar milyar/milyon/bin olarak yazılır.
- **Hizmet karnesi:** 7 alan (temizlik, su ve altyapı, ulaşım, sağlık ve sosyal, eğitim ve kültür, güvenlik ve afet, yeşil alan). Taban = 30 + gelişmişlik × 0,3. Katkılar: binalar (seviye 1/2/3 → ×1 / ×1,6 / ×2,1), açık belediye hizmetleri, son 7 günün ekonomi programları (azalarak), altyapı (30 gün) ve raylı sistem (kalıcı, en çok 2), kriz kararları (14 gün). Katkılar şehrin büyüklüğüne bölünür (×0,7–2,2; Ankara/İstanbul en zor). Karne ortalaması her gece memnuniyet hedefine (ort − 45) × 0,5 olarak eklenir. Karne herkese açıktır (il sayfası › Belediye karnesi).
- **Kriz masası:** başkanlı ilde saatlik kontrol (%6), son krizden 36 saat sonra yeni kriz; aynı anda tek kriz; son 4 kriz tekrarlanmaz; mevsime göre (kar kışın, yangın yazın). 15 olay: kar, isale hattı, çöp krizi, sel, deprem, festival, sokak hayvanları, kavşak kazası, müteahhit imar teklifi, hava kirliliği, orman yangını, işçi maaş farkı, tarihî eser, sıcak hava, fabrika yatırımı. Seçeneklerin maliyeti ilin günlük geliri cinsinden (eksi = kasaya para); bazı seçenekler şansa bağlı. 24 saatte karar verilmezse "sessiz kaldı" sonucu işler. Başlangıç ve karar Akış'a düşer, başkana bildirim gider. Başkanlık boşalınca açık kriz kapanır.
- **İller Bankası:** 10/20/30 gün vadeli kredi; faiz dönem için (enflasyon/12 + 1) × gün/30 puan; limit 20 günlük gelir − mevcut borç; 24 saatte bir kredi, en çok 3 açık kredi, 3+ gecikmede yeni kredi yok. Taksit her gece kasadan; ödenemezse %5 ceza borca eklenir, memnuniyet −1, her 3 gecikmede Sayıştay uyarısı Akış'a. Erken kapama: kalan borç. Borç şehre aittir, yeni başkan devralır.

## 17. Ekonomi 3.0: günlük faaliyet, şirketler arası ticaret, şirket değeri, genel kurul (2026-10-15, modül 99)
- **Para birimi:** Kamu kasaları (hazine, il, bakanlık) milyar ₺ birimindedir; oyuncu ₺ ile dönüşüm her yerde `oyun.pazar_tl_milyar()` (≈150.000 × fiyat endeksi). Şirket vergileri, piyango, kira vergisi, tahvil, kazı kazan, piyasa komisyonu ve belediye hizmet ihaleleri bu kura çekildi (önceden 1e6 / 1e9 / doğrudan ₺ karışıktı; vergiler hazineyi 250 → 5.600 milyar şişirmişti, düzeltildi).
- **Ana faaliyet (11 sektör):** Her aktif şirketin (banka ve ajans hariç) `pazar_sirket` satırı vardır; yoksa `oyun.ana_faaliyet_ac()` zamanlayıcıda açar (işletmesi olmayan eski şirketler en kârlı büyük ile yerleşir). Yeni pazarlar: teknoloji, sanayi, ticaret, inşaat, medya, tarım. Mağaza/fabrika/inşaat işletmesi olan şirketler ana faaliyete ek olarak kendi satışlarından kazanmaya devam eder.
- **Günlük hesap:** `pazar_hesapla` artık her gün kapanır (haftalık tahmin / 7, ±%12 gürültü), en çok 30 gün geriye doğru. Satır `eko_gunluk` (gelir, gider, reklam, b2b, vergi, teşvik, net, dağıtılan). Kâr payı her gün ortaklara (kasada biriktirmeyi seçmeyenlere) ödenir.
- **Fiyat ve kapasite:** gelir = min(talep, kapasite) × fiyat katsayısı (Ucuz 0,8 / Normal 1 / Premium 1,3). Kapasite doluyken yüksek fiyat daha çok kazandırır ama pazar payı düşer; Rekabet Kurumu hâkim durumu izler.
- **Personel:** asgari ücret × sektör katsayısı × (sermaye/400.000, alt sınır 0,25)^0,7 × (1 − SGK desteği).
- **Bölgesel teşvik:** il kalkınma puanından 6 bölge (90→1 … 15→6). Kurumlar vergisi indirimi %0/10/20/30/45/60, SGK desteği %0/0/5/10/15/20.
- **Kurumlar vergisi:** tek kaynak `eko_vergi_turleri.kurumlar` (Meclis değiştirir, şu an %25).
- **Şirketler arası gider zinciri (`oyun.b2b_ode`, `eko_b2b`):** sabit giderin %30'u elektrik (enerji şirketlerine), %20'si lojistik (ulaşım şirketlerine), reklam bütçesi (Yok/Az/Orta/Yoğun = gelirin %0/1,5/3/5) medya şirketlerine. Tedarikçi ağırlığı (1 + 0,35·kalite + marka/100) / fiyat^1,5, aynı ilde ×3; oyuncu tedarikçilerin toplam payı W/(W+4), kalan yurt içi NPC tedarikçilere. Satıcıya para anında kasaya girer, vergisi satıcının günlük hesabında kesilir. Reklam markayı büyütür (günlük marka × 0,985 + (kalite katkısı + reklam katkısı)/7).
- **Şirket değeri:** defter (kasa + stok + arsa + bina; bankada kredi alacağı − mevduat borcu) + son 7 gün kârı × 10 (zarar × 3, değer defterin yarısının altına inmez). Borsadaki şirketlerde hisse fiyatı × 100. `sirket_deger_gecmis` saatte bir güncellenir.
- **Şirketler Endeksi (`piyasa_endeks`):** ilk gün 1000; her gün yalnız iki günde de var olan şirketlerin toplam değer değişimiyle zincirlenir. 18.00 kapanış haberi (Akış/olaylar), pazar günleri "en değerli 10 şirket" listesi, 20.00'de ortaklara günün bilançosu bildirimi. Zamanlayıcı `ekonomi-3` (10 dakikada bir, `oyun.ekonomi3_tick`).
- **Genel kurul (`genel_kurul`, `genel_kurul_oy`):** %5 pay sahibi ya da yönetici önerge açar: temettü (stopaj kesilir), yönetici (CEO) ataması, ad değişikliği, tasfiye. 24 saat; payların yarısını aşan evet/hayır sonucu hemen belirler; tasfiye için %75; süre sonunda yeter sayı %25 ve evet > hayır.
- **Yönetici (CEO):** `sirketler.yonetici`; atanmışsa yönetim yetkisi CEO'ya ve %50+ pay sahiplerine geçer (`sirket_yonetici_mi`).
- **Hukuki tür:** `sirketler.tur_hukuki` ltd/as. Halka arz yalnız A.Ş. (`halka_arz_as` tetikleyicisi). Dönüşüm: en az 250.000 ₺ sermaye, harç sermayenin %0,5'i (en az 2.500 ₺) hazineye.
- **Marka filtresi:** yeni şirket adı ve ad değişikliğinde gerçek şirket/marka adları reddedilir (`oyun.yasakli_marka`); mevcut adlara dokunulmaz.
- **Milli Piyango:** bilet 1.000 ₺ → %50 ikramiye havuzu, %10 amorti, %40 hazine. Büyük ikramiye son üç hane (1/1000), çıkmazsa devreder; son hane tutana amorti. Yeni dönem tabanı 100.000 ₺.
- **Başarımlar:** Girişimci, İlk Kâr, Patron (paylar ≥ 1 Mn ₺), Gong Çaldı (halka arz), Holding (3 sektörde çoğunluk), Sektör Devi (en değerli 10).
- **Arayüz:** `gelistirici/www/ekonomi3.js` — Piyasa panosu (endeks, portföy, en değerli şirketler, yükselenler, sektörler, şirketler arası ticaret, bölgesel teşvik), Şirket karnesi (değer grafiği, son 14 gün, haftalık tahmin, fiyat/kalite/reklam kararları, hukuki yapı, müşteriler/tedarikçiler, ortaklar, genel kurul). Girişler bir çizim gözcüsüyle eklenir (Ekonomi sekmesi, şirket portföyü, şirket detayı, eski Şirketlerim).


## 18. Siyaset Merkezi: haftalık ritim ve siyasi dram (2026-10-16, modül 102)
Gündem'deki "Siyasi hafta" kartından ve Siyaset Merkezi ekranından açılır. Hiçbiri angarya değildir; hepsi oyuncular arası etkileşim yaratır.

### Haftalık takvim
Pazartesi Meclis haftası · Salı basın günü · Çarşamba grup günü · Perşembe oylama günü · Cuma anket günü · Cumartesi saha günü · Pazar haftanın özeti (20.00). Takvim kısıtlama getirmez; ilgili günde ilgili kişilere bir kez hatırlatma gider (vekiller, genel başkanlar, ankete katılanlar).

### "Şu an seçim olsa"
Haftalık ankete katılan oyuncuların oyları yaşadıkları ile göre dağıtılır; her ilin sandalyesi d'Hondt ile, ülke barajını geçen partiler arasında paylaştırılır. Ankete katılım olmayan illerde ülke geneli oranlar kullanılır. Bu hafta 10 kişiden az katılım varsa geçen hafta gösterilir. 30 kişiden az katılımda "kesin değil" uyarısı çıkar.

### Haftanın özeti
Her pazar 20.00'de kaydedilir: yasalaşan kanunlar, transferler, yeni partiler, sonuçlanan seçimler, miting sayısı ve en kalabalığı, anketin ilk beşi, haftanın en beğenilen paylaşımı, canlı yayın, stant ve kapı ziyareti sayıları, yeni vatandaşlar. Arşivde 12 hafta görünür.

### Canlı yayınlar
- **Basın toplantısı:** makam sahibi, genel başkan, yardımcı ya da parti sözcüsü açar; hemen başlar, 30 dakika sürer, kişi başı günde bir. Gazeteciler (aktif gazete sahibi ya da yazarı) en fazla 2 soru sorar; konuşmacı soruları yanıtlar. Gazetecilere ve parti üyelerine haber gider.
- **Tartışma programı:** gazete sahibi 48 saat içine planlar (45 dakika, gazete başına günde bir). 2–4 konuk davet eder; yalnız moderatör ve kabul eden konuklar konuşur. İzleyiciler program boyunca ve bittikten sonra 15 dakika "en ikna edici konuğu" seçer; sonuç Gündem'e haber olur.
- Herkes alkışlayabilir ya da yuhalayabilir.

### Transferler ve rozet töreni
Makamı olan ya da kıdem puanı 60 ve üstü bir oyuncu parti değiştirince Gündem'e haber düşer, iki partinin üyelerine bildirim gider. Yeni partinin genel başkanı ya da yardımcısı 72 saat içinde rozet takabilir; tören Akış'ta paylaşılır. Parti kapanması ya da aynı anda üçten fazla geçiş duyurulmaz. Oyuncu kartında parti geçmişi görünür.

### Balkon konuşması ve tebrik
Genel seçimde en çok sandalye alan partinin genel başkanı, cumhurbaşkanlığı seçiminde kazanan, sonuçtan sonraki 48 saat içinde bir kez balkon konuşması yapar (herkese bildirim). Rakip partilerin genel başkanları ve seçimin adayları bir kez tebrik mesajı gönderebilir.

### Müşahitler
Genel başkan ya da teşkilattan sorumlu yardımcı, yaklaşan genel/cumhurbaşkanlığı/belediye seçimi için her ile bir müşahit atar: o ilde yaşayan, o seçimde aday olmayan parti üyesi. Müşahit oy saatlerinde sandık başına geçer (kıdem +1, "Sandık Görevlisi" rozeti), sonuçlardan sonra 48 saat içinde "temiz" ya da "itiraz" tutanağı yazar. İtiraz tutanağı genel başkana gider; resmî itiraz Adliye'den açılır. Partilerin il kapsaması herkese görünür. Kaldırılan müşahit kaydı silinmez, iptal edilmiş olarak saklanır.

### Resmî günler
29 Ekim, 10 Kasım, 18 Mart, 23 Nisan, 1 Mayıs, 19 Mayıs, 15 Temmuz, 30 Ağustos (2026–2030) ve dini bayramlar (2027: Ramazan 9 Mart, Kurban 16 Mayıs). O gün 08.00'de makam sahiplerine ve genel başkanlara hatırlatma, 09.00'da herkese bildirim gider. Makam sahipleri ve parti yöneticileri günde bir mesaj yayımlar. Yeni yılların dini bayramları `oyun.resmi_gun` tablosuna eklenir.

### Saha çalışması
- **Stant:** genel başkan, teşkilattan sorumlu yardımcı ya da o ilin partili vekili/belediye başkanı, partinin teşkilatı olan bir ilde stant açar (parti kasasından 2.000 ₺, 3 saat, il başına günde bir). İlde yaşayan herkese haber gider. İldekiler uğrar ve soru bırakır, parti üyeleri gönüllü olur ve soruları yanıtlar (24 saat).
- **Kapı kapı:** parti üyesi haftada 3 kez kendi ilinde başka partiden ya da bağımsız birine kısa not bırakır. Aynı partiden bir oyuncuya haftada bir ziyaret; engelleyenlere ve propaganda bildirimini kapatanlara gitmez.

### Yol arkadaşı
Hesabı 14 günden eski ve kıdem puanı 10+ olan oyuncular gönüllü olur (en fazla 5 eşlik). İlk 14 günündeki yeni oyuncu birini seçer ya da otomatik eşlenir (aynı il önce). Yeni oyuncu ilk oyunu kullanınca (seçim ya da haftalık anket) ikisine de 1.000 ₺ ödül; aynı cihazdan bağlı hesaplara ödül verilmez. Eşlik 21 günde biter. Mentor "Yol Arkadaşı" rozeti alır.

### Yeni rozetler
Kurucu Vatandaş (31.12.2026'ya kadar kayıt olanlar), Sandık Görevlisi, Yol Arkadaşı.

### Yaş ve içerik kuralı
Oyun 18 yaş ve üzeri içindir. Gerçek kişilere ya da oyunculara hakaret, tehdit, nefret söylemi ve kişisel bilgi paylaşımı yasaktır; şikâyet ve engelleme her profilde açıktır.

## 19. Avukatlık kontenjanı ve Türkiye Barosu (2026-10-23, modül 130)

### Ruhsat yolu
7 günlük hesap → 24 saatlik Hukuk Akademisi (ders notları açık) → 60 soruluk bankadan her denemede farklı 20 soru (en az 16 doğru; başarısızlıkta 24 saat sonra yeni set) → iki uygulamalı staj vakası → kontenjanlı ruhsat (100.000 ₺ harç, yalnız kontenjana yerleşince) → Türkiye Barosu levhasına kayıt. Mesleği icra etmek (teklif, savunma, büro) için ruhsat + baro kaydı + disiplin yasağı olmaması gerekir.

### Kontenjan
- Formül: son 7 günde aktif her **10** oyuncuya 1 ruhsat, en az **2**. Yönetici Adliye ekranındaki "Kontenjan ayarı"ndan sabit kontenjan, oran, asgari sayı ve pasiflik süresini değiştirir. Kontenjan düşerse mevcut avukatların ruhsatı alınmaz; yalnız yeni yerleşme durur.
- Bekleme listesi başvuru sırasıyla işler; 10 dakikada bir boş kontenjan kendiliğinden sıradaki adaya verilir. Son 7 günde oyuna girmeyen ya da engelli aday sırayı tıkamaz (yeri korunur). Harcı olmayan aday atlanır, sırası korunur, günde bir kez bildirim alır.
- **Pasiflik:** 14 gün oyuna girmeyen (ya da engellenen) avukatın ruhsatı askıya alınır, kontenjanı sıradakine açılır, açık dosyalardaki vekâletleri biter (müvekkile bildirilir). Avukat kendi isteğiyle de ruhsatını askıya alabilir. Dönünce "yeniden etkinleştir" ile harçsız olarak listenin sonuna girer; boş yer varsa hemen açılır ve askı yüzünden düşen baro kaydı kendiliğinden geri gelir.
- Başarı primi en fazla %25 (Avukatlık Kanunu m.164).

### Türkiye Barosu
- **Levha:** yalnız aktif ruhsatlı avukat kaydolur (giriş keseneği 10.000 ₺, sicil numarası 1001'den başlar ve ayrılınca da korunur). Baro binasına (pano, davalar, levha, seçim, disiplin, hesabım) yalnız kayıtlı avukatlar girer; diğer oyuncular kilitli kapı ve özet bilgi görür. Yönetici denetim için salt okunur girer.
- **Aidat:** aylık 5.000 ₺, süresi dolunca cüzdandan otomatik alınır; 7 gün ödenmezse levhadan silinir (ruhsat durur, yeniden kaydolabilir). En fazla 3 ay peşin ödenir.
- **Kasa:** ruhsat harçlarının %25'i + giriş keseneği + aidat; yalnız adli yardım ücretine harcanır. Hareketler üyelere açıktır.
- **Başkanlık seçimi:** her ay, adaylık 15'i 00:00 – 20'si 10:00, oylama 20'si 10:00–20:00. Aday: mesleği icra edebilen üye. Seçmen: oylama başlamadan kayıtlı üye, tek oy. Eşitlikte küçük sicilli kazanır. Aday çıkmazsa başkan devam eder. Seçilmiş başkan yoksa (ya da üyeliği/ruhsatı düşerse) en küçük sicilli üye geçici başkandır.
- **Başkanın yetkileri:** duyuru (bütün üyelere bildirim), panodan mesaj kaldırma, adli yardım görevlendirmesi, disiplin kararı.
- **Adli yardım:** cüzdanında 50.000 ₺'den az parası olan davanın kişisel tarafı, dosyasından ücretsiz avukat ister. Başkan gönüllü bir avukatı (ya da kendini) görevlendirir; avukata kasadan 20.000 ₺ ödenir, başkan kendini görevlendirirse ücret ödenmez.
- **Disiplin:** müvekkil ya da dosya tarafı, dosyada vekil olmuş avukatı şikâyet eder (aynı avukata tek bekleyen şikâyet). Başkan ret / uyarma / kınama / 3 ya da 7 gün işten yasaklama verir; kendisi hakkındaki şikâyete karar veremez (yönetici verebilir). İşten yasaklanan avukatın açık dosyalardaki vekâletleri biter. Kararlar ve disiplin sicili üyelere açıktır.
- **Avukat bekleyen davalar:** açık davalarda vekili olmayan taraflar listesi; avukat dosyayı açıp teklif verir.

## 20. Mahkemede avukat zorunluluğu ve Parti Sözcüsü (2026-10-23, modül 131)

### Kim mahkemeye ne yapabilir?
- **Dava açmak, savunma ve beyan sunmak, istinafa başvurmak, seçim sonucuna itiraz etmek ve parti kapatma davasında savunma vermek yalnız avukat eliyle yapılır.** Oyuncu kendi adına, parti genel başkanı partisi adına, şirket/dernek/belediye/bakanlık/gazete yetkilisi kurumu adına avukat tutar.
- Yargıcın davaya çağırdığı **ilgili taraf** tanık olarak kendi beyanını verebilir; bu savunma sayılmaz.
- Geçişten (23.10.2026) önce açılmış davaların istinafı eski usulle (sözcü hariç) sürer; o tarihte açık dava yoktu.

### Hukuki iş talebi (dava açma, seçim itirazı, parti kapatma savunması)
1. Müvekkil Adliye > "Avukatla dava aç" (ya da seçim itirazı) ile talebi yayımlar; iddia, delil, davalı ve tazminat talebi yazılır. Aynı anda en fazla 3 açık iş.
2. Baroya kayıtlı avukatlar Türkiye Barosu > Davalar > "Avukat arayan hukuki işler"den ücret teklif eder (tazminat davasında en fazla %25 başarı primi). Müvekkil belirli bir avukatı davet edebilir.
3. Müvekkil bir teklifi kabul edince ücret cüzdanından **emanete** alınır.
4. Avukat dilekçeyi düzenleyip "mahkemeye sun"ar: dava müvekkilin adına açılır (harç müvekkilden), avukat dosyada davacı vekili olur ve emanetteki ücret ona geçer.
5. Sunulmadan önce müvekkil talebi geri çekebilir, avukat vekâletten çekilebilir; emanet müvekkile iade edilir.
- Davalı tarafa yeni davalarda savunma süresi **24 saattir** (avukat bulma süresi için; `ayarlar.avukat_savunma_saat`).

### Parti Sözcüsü
- Mahkemede hiçbir yetkisi yoktur (temsil izni, parti davasında beyan, istinaf ve seçim itirazı kaldırıldı).
- Görevi **parti adına resmî açıklama**dır: parti sayfasındaki "Resmî açıklamalar" bölümünden başlık + metin yayımlar; açıklama Gündem akışına düşer ve bütün üyelere bildirilir. Genel başkan da açıklama yapabilir. 15 dakikada bir açıklama; yazar ya da genel başkan kaldırabilir.
- Sözcüyü yalnız genel başkan atar ve görevden alır.

## 21. Uzun Soluklu Ekonomi: fiyat merdiveni, statü hakları, ekip partisi (2026-10-31, modül 151)

**Amaç.** Oyun aylarca, yıllarca oynanacak. Ne yeni oyuncu ilk gün zengin olsun ne de eski oyuncu hedefsiz kalsın; düzenli oynayan daha hızlı ilerlesin. Parti kurmak ekip işi olsun.

**Ölçülen sorun (30.10.2026, 21 günlük oyun):** pazar şirketleri haftada sermayenin %11'ini kazanıyordu; iki oto galeri haftada %160–225 getiriyle 4 milyon ₺ üretiyordu; enerji şirketleri herkesin elektrik faturasını topluyordu (%46/hafta); konut kirası bedelin 1/13'ü (%7,7/hafta); aynı kişi 3–4 makamın maaşını birden alıyordu; 25.000 ₺ ve 3 onayla parti kurulabildiği için 50 oyuncuya 11 parti vardı.

### Tek tarife
Bütün yeni fiyat ve oranlar `oyun.tarife` tablosundadır (yönetici SQL ile değiştirebilir; kurulum dosyası yeniden çalışınca ayarlanan değer korunur). `oyun.tf(kod)` değeri, `oyun.tf_tl(kod)` fiyat düzeyiyle güncellenmiş tutarı verir. Oyunculara açık ekran: **Ekonomi › Fiyat Tarifesi** (`public.fiyat_tarifesi`); bütün tutarlar sunucudaki gerçek fonksiyonlardan hesaplanır. Kilitleri toptan kapatmak: `update oyun.tarife set deger = 0 where kod = 'kilit_aktif';`

### Statü hakları (kıdem kilidi)
| Statü (kıdem) | Maaş | Şirket hakkı | Açılanlar |
|---|---|---|---|
| Yeni Gelen (0) | ×1,0 | 0 | aday olma, dernek üyeliği, yatırım |
| Vatandaş (10) | ×1,2 | 1 | şirket ve dükkân, gazete, dernek kurmak; kurucu üye olmak |
| Saygın Vatandaş (30) | ×1,4 | 2 | reklam ajansı, parti kurma başvurusu |
| Kanaat Önderi (75) | ×1,6 | 3 | banka |
| Duayen (150) | ×1,8 | 5 | |
| Yaşayan Efsane (300) | ×2,0 | 8 | |

Şirket hakkı = aynı anda en büyük ortağı olunabilecek aktif şirket sayısı. Kilit tek geçitte, `oyun.sirketler` tetiğinde (`tg_kurulus_denge_sirket`) uygulanır; yalnız oyuncu işlemlerinde çalışır. Mevcut şirketler korunur; hakkı dolu oyuncu yeni şirket kuramaz ama satın alabilir. Gazete ve dernek kilidi de tetikle (`tg_kurulus_denge_gazete`, `tg_kurulus_denge_dernek`). Kıdem: her gün maaş toplama +1, her oy ve halk oylaması +3, bakanlık etkinlikleri, müze bağışları.

### Kuruluş sermayeleri
| Ne | Tutar | Statü |
|---|---|---|
| Küçük işletme: ticaret, teknoloji, sanayi, inşaat, medya, tarım, danışmanlık, oto servis | 200.000 ₺ | Vatandaş |
| Orta: market, ulaşım, lojistik, e-ticaret, geri dönüşüm, turizm, özel okul, giyim, yapı market, elektronik, mobilya | 500.000 ₺ | Vatandaş |
| Özel hastane, akaryakıt | 1.000.000 ₺ | Vatandaş |
| Enerji santrali | 1.500.000 ₺ | Vatandaş |
| Otomobil galerisi | 2.500.000 ₺ | Vatandaş |
| Reklam ve anket ajansı | 400.000 ₺ | Saygın Vatandaş |
| Banka | 15.000.000 ₺ (ortaklı kurulabilir) | Kanaat Önderi |
| Döviz bürosu / kuyumcu | 200.000 ₺ | Vatandaş |
| Gazete | 150.000 ₺ × fiyat düzeyi | Vatandaş |
| Dernek / şube | 50.000 ₺ / 5.000 ₺ × il büyüklüğü (× fiyat düzeyi) | Vatandaş |

### Getiri dengesi
- **Pazar şirketleri:** kapasite ×0,8, sabit gider +0,5 puan. Ortalama haftalık getiri %11 → %7,3 (iyi yönetilen ~%13, kötü yönetilen zarar).
- **Perakende (NPC mağaza):** günlük brüt kâr sermayenin %2,5'ini aşamaz (`oyun.npc_marj_gun`); kalan talep ildeki rakiplere kalır. Zayıf kalan akaryakıt (×6), giyim, yapı, elektronik, mobilya talebi artırıldı.
- **Şirketler arası fatura (elektrik, lojistik, reklam):** alan şirket günde en çok sermayesinin %1,2'sini toplar; fazlası kimseye gitmez.
- **Kira:** yeni alınan konut/dükkânın haftalık kirası il taban bedelinin %2'si (eski %7,7). Önceden alınanlar eski kirasıyla devam eder.
- **Makam:** en yüksek makam tam, diğerleri %25 (Meclis görev tazminatları tam).
- **Görev ödülleri ×2** (izin aralığı 50–10.000 ₺).

Hiyerarşi: vadeli mevduat (~%0,8/hafta, risksiz) < kira (%2/hafta, güvenli) < şirket (~%7/hafta, yönetim ve risk ister). Servet vergisi (bölüm 148) en üst dilimi frenler.

### İlerleme hedefleri (simülasyon: her gün / haftada 5 gün / haftada 3 gün oynayan)
İlk şirket ~14 / 28 / 56. gün · 1 milyon ₺ net servet ~70 / 120 / 180. gün · 5 milyon ₺ ~190. gün (her gün oynayan) · banka 4–6 aylık ekip hedefi.

### Ekip partisi
- **Kurucular kurulu:** sen dahil en az 7 kişi; son 14 günde aktif oyuncuların %2'si kadar büyür, en çok 30 (yasal sayı). Başvuru anındaki sayı geçerlidir.
- **Başvuran:** en az Saygın Vatandaş, 14 günlük hesap, partisi olan genel başkan değil, Yüksek Mahkeme üyesi değil; iki kuruluş arası 90 gün; aynı anda tek başvuru.
- **Kurucu üye:** en az Vatandaş, 7 günlük hesap, aynı cihazdaki hesaplar aynı kurulda sayılmaz, son 30 günde başka partinin kurucusu olmamış, genel başkan ve Yüksek Mahkeme üyesi değil. Onayını geri çekebilir.
- **Para:** 500.000 ₺ harç (başvurandan, yok olur) + 1.000.000 ₺ kuruluş fonu. Kurucular fona emanetle katkı yapar (`public.kurucu_katki`, en az 10.000 ₺); eksiğini kuruluşta başvuran tamamlar; fon partinin kasasına geçer. Başvuru 10 günde dolar; iptal, ret, onay geri çekme ya da süre dolunca katkılar iade edilir (`oyun.kurucu_suresi_dolan`, zamanlayıcı 15 dk). Kuruluşta şartları taşımayan onaylar sayılmaz, katkıları iade edilir.
- Mevcut partiler aynen kalır. Eyetkin, CELAL ve matestappen hesaplarına daha önce tanınan özel kuruluş istisnası değiştirilmedi.

### Diğer ücretler
Aday adaylığı: milletvekili 15.000, belediye 10.000 × il büyüklüğü, genel başkanlık 50.000, cumhurbaşkanı 150.000 ₺ · miting 5.000 × il büyüklüğü · taşınma 20.000 ₺ (devlet desteği düşülür) · il teşkilatı 10.000 × il büyüklüğü · yeni oyuncu 150.000 ₺ ile başlar (hepsi × fiyat düzeyi). Mağaza paketleri değişmedi.

## 22. Siyaset Arenası: canlı anlar, karşılıklı bağımlılık, sezonlar (2026-10-31, modül 154)
Amaç oyuncunun her gün belli saatte oyunda olması ve başkalarının ona ihtiyaç duyması.
- **Randevu:** her akşam 21:00–22:00 TBMM Genel Kurulu. Vekil yoklaması +1 kıdem; gelmeyenin adı herkese açık. Haftalık parti hedeflerinden biri de yoklamadır.
- **Bekleyen işler:** oyuncunun kararını bekleyen her şey tek listede; ödenek, oylama, kurucu daveti, ittifak teklifi.
- **Takım hedefi:** her pazartesi partiye 3 hedef; ödül parti kasasına 25.000 ₺ × endeks ve katılan üyelere kıdem. Tek kişi tamamlayamaz.
- **Sezon:** aylık 4 sıralama (Siyasetçi, Vekil, İş İnsanı, Kalem), ayın 1'inde unvan + 5 kıdem + gazete; haftalık "Haftanın Kalemi". Oyun sıfırlanmaz; ödüller oyuncu kartında birikir (×adet).
- **Gölge kabine:** ana muhalefete iş ve görünürlük; raporlar iktidar bakanına bildirim olarak gider, iki taraf arasında gerilim üretir.
- Dengeleme: bütün yeni kıdem kaynakları günlük tavanlı (`oyun.kidem_kaynak`), para ödülü yalnız parti kasasına gider; bireysel para enjeksiyonu yok.

## 23. Yargı düzeni: kimse "atandığımı bilmiyordum" demesin, hiçbir dava asılı kalmasın (2026-10-31, modül 155)
- Taraf partilerden jüri ya da yargıç olmaz. Kura aktif oyunculardan başlar, yük dağıtılır (en çok 2 açık görev).
- Görev Gündem'in en üstünde kırmızı kartla ve Bekleyen işlerde görünür; oy veren +1 kıdem kazanır.
- Süreler kesin: 8 saat ortada yoksa yedek, 24 saatte çoğunluk yoksa değişim + 24 saat, 48. saatte verilen oylarla karar (bozma için en az 2 oy). Görevi ihmal eden 14 gün jüriye çağrılmaz; Yüksek Mahkeme'de ihmal atayan makama bildirilir.

