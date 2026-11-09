# Halk Hareketleri — 2026.11.07-1

Partiler → Halk Hareketleri. İl memnuniyetsizliği; ülke memnuniyeti, işsizlik, enflasyon, vergi ve belediye memnuniyetinden hesaplanır. Parti genel başkanı 50.000 TL ödeyerek 24 saatlik barışçıl eylem açar. Her 50.000 TL ek fon 12 saat ekler; başlangıçtan itibaren en fazla 120 saat. Cüzdan, parti ve dernek destekleri aynı eylemde birleşir; para ilgili kaynaktan atomik düşer ve hareket kaydı tutulur.

## Sınırlar

- Eylem başlatan hesap en az 7 günlük, katılımcı hesap en az 3 günlük olmalıdır. Katılım için il ikameti veya ilde 3 gün yaşama şartı yoktur; 81 ilden katılınabilir.
- Parti veya dernek başkanı, oyuncu sayısı ve memnuniyetsizlik ön şartı aranmadan eylem başlatabilir.
- İl başına tek eylem, kapanıştan itibaren 7 gün dinlenme; parti başına tek aktif eylem ve başlangıçlar arasında 72 saat.
- Ülkede en fazla 6 eylem; kişi/kurum başına en fazla 3 eşzamanlı destek.
- Son 24 saat protesto fonu: kişi 100.000 TL, kurum 250.000 TL. Uzlaşma limitleri üç katı. Bir eylemde toplam protesto fonu en fazla 1 milyon TL.
- Kırmızı için 75 puan ve Türkiye genelinden en az 3 gerçek katılımcı gerekir. Para tek başına yetmez. Uzaktaki katılımcılar güç ve ulusal kriz hesabında sayılır.
- Üç kat uzlaşma fonu eylemi kapatır. Hükümet altı saatte bir somut yanıt yayımlayabilir; açıklama tek başına puan düşürmez. Hizmet iyileşmesi memnuniyetsizliği azaltır.
- Erken seçim: en az 3 kırmızı il + en az 15 farklı kişi ve aktif ülkenin %20'si, kesintisiz 72 saat. Yakın/aktif seçimler ve yeni CB'nin ilk 7 günü korunur; kriz kaynaklı seçim arasında 14 gün gerekir. Makamlar zorla silinmez, seçim takvimiyle devredilir.

## Ekonomik etkiler

Kırmızı iller için ülke çapında 24 saatte bir, en çok 2 puan memnuniyet, 0,6 puan büyüme kaybı ve 0,3 puan enflasyon artışı. Şirket değerlemesinde pozitif kâr beklentisine kırmızı il başına %1, en çok %6 risk indirimi; risk eylem sona erince kalkar. Gerçekleşmiş hisse işlem fiyatları ve defter varlıkları değiştirilmez.

## Doğrulama

`halk_hareketleri.sql` ve `halk_kriz.sql` Supabase üzerinde transaction + rollback ile çalıştırıldı: para düşümü, limitler, mükerrer katılım, hükümet yanıtı, yetkiler, süre sonu, 3x uzlaşma, ulusal sayaç, erken seçim takvimi ve piyasa riski doğrulandı. Testlerin bütün satır değişiklikleri geri alındı.

`halk_hareketleri_ui.js` jsdom 26.1.0 ile ekran/olay bağlantıları ve HTML kaçışını doğrular. Derleme ve RPC yüzeyi taraması çalıştırıldı. Yerel kalıcılık paketi psql bulunmadığı için çalıştırılamadı; Chromium ortamın socket kısıtı nedeniyle açılamadı. Gerçek cihazda oturum açılmış uçtan uca test yapılmadı.

RPC'ler yalnız authenticated rolüne açık; hesap ve kurum yetkisi sunucuda kontrol edilir. İç yardımcılar ve tablolar istemciye kapalıdır. Danışmanın RLS-politikasız tablo ve authenticated SECURITY DEFINER bildirimleri bu kontrollü RPC mimarisi için beklenir.

Cron: `halk-hareketleri`, beş dakikada bir `oyun.sokak_tick()`. Devre dışı bırakmak için yalnız `oyun.sokak_eylem_ayar.aktif=false` ayarlanır; veri silinmez. Yeni kurulum varsayılanı kapalıdır; canlı açılış testlerden sonra ayrı yapılır.

## Hükümet karşılıkları — 2026.11.07-2

Cumhurbaşkanı ve İçişleri Bakanı eylem kartındaki müdahale bölümünü kullanır. Kaynak İçişleri bütçesidir; mevcut `pazar_tl_milyar()` oyun ölçeğiyle TL tutarı kamu bütçesi birimine çevrilir ve bakanlık hesap defterine kaydedilir.

| Karar | Bedel | Sonuç |
|---|---:|---|
| Uzlaşma masası | Başlatma bedelinin 2 katı | Organizatör 12 saat içinde kabul ederse eylem kapanır, il memnuniyeti +2. Ret/süre dolması otomatik kapatmaz. Eylem başına bir teklif. |
| Bilgilendirme/yönlendirme | 3 katı | 12 saat yoğunluk −10 puan. |
| Sert siyasi uyarı | 1 katı | 6 saat −8 puan; sonraki 18 saat +6 tepki. Ülke memnuniyeti −1. |
| Ek bütçeli dağıtma | En az 5 başlangıç bedeli; protesto fonunun 5 katından mevcut uzlaşma fonu düşülür | 12 saattir kırmızı eylem kapanır. Ülke memnuniyeti −4, il −5. Ülke çapında 48 saatte bir. |
| Süreli yaptırım | 2 katı | Katılımcının yalnız o eyleme katılım/fon hakkı 6 saat durur; ülke memnuniyeti −1. |

Her eylemde kararlar arasında 6 saat; hükümetin ülke çapında 24 saatte en fazla 4 kararı. Bir eylemde en fazla 3 yaptırım, aynı kişiye 7 günde bir. Yaptırım hesap kapatmaz, para cezası kesmez, oy kullanmayı engellemez. Hedef oyuncu itiraz edince uygulama durur. Mevcut adliye hakimi onaylar/kaldırır; karar veren ve hedef kendi dosyasını inceleyemez. Onay asıl 6 saatlik bitişi uzatmaz. Açıklama ve kararlar bildirim/eylem geçmişine yazılır.

Doğrulama: `halk_hukumet.sql` rollback testinde CB/İçişleri yetkileri, kamu tahsilatı, bekleme, uzlaşma kabul/ret, yönlendirme, uyarı/geri tepme, yaptırım/itiraz/yargı ve dağıtma kontrol edildi. DOM testi yeni karar ve uzlaşma yanıtı formlarını da kapsar. Gerçek cihaz testi yapılmadı.

## Somut talepler ve oylamalı uzlaşma — 2026.11.07-4

Yeni eylemde değiştirilemeyen bir talep seçilir: il hizmet memnuniyeti +5 puan, ulusal işsizlik −0,5 puan veya yürürlükteki vergi −1 puan. Eski eylemin organizatörü talebini bir kez kesinleştirebilir.

Hükümet somut teklif sunduğunda başlangıç/hedef kaydedilir ve Türkiye genelinden en az üç gerçek katılımcıdan oluşan seçmen listesi sabitlenir. Oylar tek seferliktir. On iki saatte tüm seçmenlerin yarısından fazlası kabul ederse eylem 24 saat askıya alınır; fonlama ve yeni hükümet müdahalesi durur. Organizatör tek başına kabul ederek bu süreci atlayamaz. Ret veya yetersiz kabul eylemi kapatmaz.

Mevcut beş dakikalık halk hareketleri kontrolü, 24 saat sonunda göstergeyi ölçer. Hedef sağlanırsa eylem kapanır ve hükümet memnuniyeti +1 olur. Sağlanmazsa memnuniyet −3 olur; eylem kalan süresiyle devam eder. Askıda geçirilen 24 saat eylemin bitişine bir kez eklenir; aynı eylemde tekrar uzlaşmayla sınırsız süre uzatılamaz. Göstergeler mevcut ekonomi/belediye kararlarından değişir; uzlaşma düğmesi tek başına vaadi gerçekleştirmez.

`halk_uzlasma.sql`: rollback ile çoğunluk, tekrar oy, tek kişiyle atlama engeli, askı, sözün tutulması/tutulmaması ve iç fonksiyon yetkileri doğrulandı. DOM testi teklif/oylama arayüzünü kapsar. Gerçek cihaz testi yapılmadı.

## Türkiye geneli eylem katılımı — 2026.11.07

Eylemin ilinde yaşamak veya ikamet süresini doldurmak gerekmiyor. Kısıtsız, en az 3 günlük hesabı bulunan oyuncular 81 ilden katılabilir; parti ve dernek üyeleri uygun kuruluş desteğiyle, diğer oyuncular bağımsız olarak başvurur. Katılımcılar eylem gücü, kırmızı eşik ve ulusal kriz sayacında illerinden bağımsız sayılır. Somut uzlaşma oylaması da tüm kayıtlı katılımcıları kapsar. Canlı RPC değişiklikleri `20261107190500_sokak_eylem_ulke_geneli_katilim.sql` ve `20261107191500_sokak_uzlasma_turkiye_geneli_oylama.sql` içinde tutulur. Geri alınan işlem testinde başka ilden bağımsız katılım başarılı oldu.

## On iki yeni hükümet aracı — 2026.11.09

Cumhurbaşkanı ve İçişleri Bakanı kullanır. Para İçişleri kasasından düşer; açılış bedeli varsayılan 50.000 TL’dir. Aynı eylemde 12 saatte en çok 3 yeni araç açılır. Uzlaşma takibi sürerken açılamaz. Mesajlaşma ve seçim oyu hiç kapanmaz. Karşı hamleler gerçek oyuncuya aittir: katılımcı, organizatör, şirket, basın, avukat, vekil, parti üyesi veya dernek başkanı.

| Araç | Bedel | Etki | Risk | Karşı hamle |
|---|---:|---|---|---|
| Acil Hizmet Seferberliği | 5 kat (250.000 TL) | Yalnız hizmet talebinde. İl memnuniyeti hemen +4 (100 tavanı). 12 saat yoğunluk −8. | 24 saat sonra il, hedefte değilse ülke memnuniyeti −3. | Katılımcıların yarısından fazlası “yetersiz” derse +4 geri alınır ve sakinleşme biter. |
| Bölgesel Vergi Tatili | 6 kat (300.000 TL) | Yalnız vergi talebinde. 48 saat o ilin kent vergisi −1. Yoğunluk −6. | Büyüme −0,2. Diğer illerin memnuniyeti −0,5. Ülke memnuniyeti −1. Tepki +4. | “Yetersiz” çoğunluğu −6 sakinleşmeyi siler; vergi indirimi ve ekonomik bedel kalır. |
| İstihdam Taahhüt Paketi | 4 kat (200.000 TL) | Yalnız işsizlik talebinde. İşsizlik −0,3 (taban %2). İldeki şirket söz verirse yoğunluk −6. | 12 saatte şirket sözü yoksa indirim geri gelir, ülke memnuniyeti −2, yoğunluk +6. | Organizatör grev çağırır: indirimin yarısı hemen geri gelir, grev taktiği açılır. |
| Resmi Basın Brifingi | 2 kat (100.000 TL) | 12 saat tarafsız nabız hükümete +3 ağırlık. Her hükümet yanlısı gazeteci +2, en çok +6. | Muhalif gazetecinin karşı brifingi etkiyi ters çevirir. | Katılımcı slogan yazar ve “ikna olmadım” der (en çok +8 destek ağırlığı). |
| Acil Sosyal Destek Kartı | 4.000 TL × en çok 15 kişi | İlin eyleme taraf olmayan aktif oyuncularına nakit. | Ülke memnuniyeti −1. “Oy satın alma” yoğunluğu +5; iadeler yarıyı geçerse +10. | Organizatör reddetmeye çağırır. Kartı alan 12 saat içinde 4.000 TL’yi iade eder. |
| Güvenli Alan / Güzergâh | 2 kat (100.000 TL) | Çoğunluk kabul ederse güç değişmez, düzen +5. Bu ilin kırmızı ekonomik hasarı 24 saat sayılmaz. | Ret: inat +5. Dayatma: inat +8 ve ekonomi kalkanı yok. | Katılımcılar kabul veya ret eder. |
| Meclis Araştırma Komisyonu | 2 kat (100.000 TL) | 24 saat eylem yeni kırmızıya çıkamaz. İktidar vekili lehine kapatırsa 6 saat −8. | Muhalefet devralırsa veya süre sonunda fazla çıkarsa talep kısmen uygulanır (hizmet +3, işsizlik −0,25 veya vergi −0,5). Vekil yoksa +4. | Muhalefet vekili sandalyeye oturur ve sayıyı geçince komisyonu devralır. |
| Bağımsız Gözlemci | 1 kat (50.000 TL) | İlk avukat katılınca 12 saat polis sevki ve barikat kapalı. Avukat 2 saat içinde gelmezse protokol düşer; para geri gelmez. | Uyarı, dağıtma, yaptırım, bütçeli müdahale, gece kısıtı veya iletişim yavaşlatma yine yapılırsa ülke −4, il −3, basın skandalı, yoğunluk +10. | Organizatör, avukat gelmeden protokolü reddeder. |
| İktidar Kapı Kapı | 2 kat açılış; üye başı 8.000 TL parti kasası | 12 saatlik seferberlik. Her üye 6 saat +1 karşı nabız ağırlığı, en çok 8. Oyuncu başı 3 saat bekleme. | Parti kasası erir. İletişim yavaşlatma varken çağrı yapılamaz. | Muhalefet partisi üyesi aynı ilde 8.000 TL ile karşı çağrı yapar. Katılımcının mevcut çağrı taktiği de açık kalır. |
| Gece Toplanma Kısıtı | 2 kat (100.000 TL) | 48 saat boyunca 22.00–06.00 (İstanbul) yeni katılım ve taktik kapalı. | İl memnuniyeti −1. Gündüz inat +2. | Üç katılımcı “kısıtı tanımıyorum” derse gündüz inat +4 olur. |
| İletişim Yavaşlatma | 3 kat (150.000 TL) | 6 saat eylem çağrısı, karşı çağrı, kapı kapı ve nabız oyu durur. | Ülke memnuniyeti −2. Kriz sayacı 6 saat ileri alınır (en çok 12 saat birikir). Basın skandalı +6. | Miting otobüsü (en çok +8) ve dernek daveti (en çok +6). Mesaj ve uzlaşma/seçim oyu açık kalır. |
| Kültür-Festival | 3 kat (150.000 TL) | 8 saat. Festivale giden her tarafsız oyuncu nabızdan çekilir, en çok 12 karşı ağırlık. | Her zaman “ekmek yok oyun var” +5. Ülke memnuniyeti −0,5. | Katılımcı sahneyi pankartla işgal eder: +4, en çok +12. |

Güç dökümünde bu satırlar görünür. Nabız eğimi, katılımcı çarpanının içinde “ağırlık” satırı olarak da yazılır. Yeni RPC’ler `sokak_tedbir_ac`, `sokak_tedbir_hamle` ve `sokak_tedbir_panel`; yalnız authenticated rolüne açıktır. Şema `20261109150000_halk_hukumet_yeni_tedbirler.sql` içindedir ve bu değişiklikle canlı veritabanına uygulanmamıştır.

## Meydan sohbeti, muhbir ve kriz oyunları — 2026.11.09

Aktif eylemin sohbetini yalnız o an içindeki katılımcılar okur ve yazar. Satır güvenliği (RLS) ve canlı yayın sinyali bunu tutar. Küfür süzgeci mevcut sohbet süzgeciyle aynıdır. Gözaltındaki oyuncu yazamaz.

Muhbirlik gizli bir anlaşmadır. Hükümet para (en çok 80.000 TL) ve bir makam sözü teklif eder. Oyuncu kabul eder, reddeder ya da teklifi kendi adıyla ifşa eder. Kabulden 3 saat sonra herkese “Eylem alanında bir muhbir var” denir; isim yoktur. Sızıntı şüphe puanını yükseltir. İfşa oyu günde bir, en az 3 oy ve katılımcıların yarısından fazlasıdır. Doğru ifşa muhbiri çıkarır, hükümetin memnuniyetini düşürür. Yanlış ifşa 10.000 TL tazminat, eyleme küçük ceza ve oy verenlere bir gün oy yasağı getirir. İktidardan biri eyleme katılırsa hükümet onu içeriden kişi olarak işaretleyebilir.

Ayrıca: 21.00’de 60 dakikalık son gece yayını, kabine notunun gazeteciye sızması ve soruşturma, vekilin partiden ayrılıp sandalyesinin bağımsız renge dönmesi, kırmızı hat, şirket boykotu, sahadan gazeteci notu, en çok 9 kişilik halk jürisi, bir hafta sonra açılan kabine oyu, hesap günü pusulası, biten eylemin adı ve “Oradaydım” rozeti, iline meşale, 81 ilin kriz haritası ve imzasız iktidar mektubu. Ayrıntı çekme isteğinde `20261109183000_meydan_sohbet_muhbir.sql` içindedir. Canlı veritabanına bu dosyayla uygulanmamıştır. Şehir maketi bu dalda yoktur.

## On sert önlem — 2026.11.09

Cumhurbaşkanı, İçişleri Bakanı veya eylemin ilindeki vali kullanır. Para İçişleri kasasından düşer. Açılış bedeli 50.000 TL ise katlar aşağıdaki gibidir. OHAL yürürlükteyken bu ildeki hükümet eylem araçları ve sonraki sert önlemler yarı fiyat olur; OHAL’in kendi bedeli yarıya inmez. Aynı eylemde 12 saatte en çok 2 sert önlem, aralarında en az 3 saat vardır. Şafak dışında her önlem eylem başına bir kezdir. Uzlaşma takibinde açılamaz. Her kullanım hesap günü pusulasına “sert” diye yazılır. Şiddet, yaralanma ve silah yoktur; sonuçlar süre, fon, oy ve memnuniyet üzerindedir.

| Önlem | Bedel | Etki | Risk | Karşı hamle |
|---|---:|---|---|---|
| Şafak Operasyonu | 4 kat (200.000 TL) | Yalnız 04.00–06.00, İstanbul saati. Nöbetteki gerçek katılımcı, katılımcıların yüzde 30’undan ve en az 2 kişiden azsa eylem hemen biter. | Nöbet yeterse operasyon tutmaz, 12 saat +12 güç ve ülke memnuniyeti −1. | Katılımcı nöbet listesine yazılır. Aktif nöbet taktiği de sayılır. |
| Elebaşı Gözaltısı | 3 kat (150.000 TL) | Organizatör ve son 24 saatte en hareketli iki katılımcı 12 saat eylemin dışındadır: katılamaz, taktik uygulayamaz. Kalanlar yeni sözcü seçer. | Ülke memnuniyeti −2. | Ruhsatlı avukat süreyi bir kez yarıya indirir. İçeridekiler kullanıcı adıyla sözcü oyu verir; yarıdan fazlası ve en az 2 oy yeni sözcüyü belirler. |
| Mali Kuşatma | 5 kat (250.000 TL) | 48 saat parti ve dernek kasasıyla süre uzatılamaz. | Yüksek Mahkeme aykırı derse kuşatma kalkar, partiye 100.000 TL tazminat yazılır, ülke memnuniyeti −2. | Yüksek Mahkeme üyesi “hukuka aykırı” oyu kullanır. Dosya Adliye formuna da açılır; form kabul etmezse oy bu ekranda kalır. |
| Kapatma Davası Tehdidi | 2 kat (100.000 TL) | 48 saat bu partinin protesto harcaması iki kat tahsil edilir; kazanılan süre istenen tutara göredir. | Hükümet kaybederse ülke memnuniyeti −4, önlemi açanın itibarı −15 ve basın skandalı. | Yüksek Mahkeme üyesi aykırı oyuyla tehdidi düşürür. |
| OHAL | 6 kat (300.000 TL) | Meclisteki gerçek vekillerin salt çoğunluğu 6 saat içinde evet derse 72 saat o ilde yeni katılım ve yeni eylem yasaktır. Yasak, açılış fonksiyonunun içine yazılmaz; eylem satırı kaydedilirken kontrol edilir. Hükümetin eylem araçları yarı fiyat olur. | Teklif reddedilirse ya da süre dolarsa para geri gelmez. Onayda ülke memnuniyeti −4. Erken seçim sayacı 12 saat ileri alınır, birikim en çok 24 saat. | Milletvekili hayır oyu kullanır. Salt çoğunluk hayır da teklifi düşürür. |
| Kara Propaganda | 2 kat (100.000 TL) | İktidar yanlısı gazeteci manşeti yazınca 12 saat −8 güç. | Gazeteci 2 saat içinde yazmazsa önlem boşa düşer. Çürütülürse +10 güç, ülke memnuniyeti −2 ve skandal manşeti. | Muhalif gazeteci ya da ruhsatlı avukat kanıt metniyle çürütür. |
| Böl ve Yönet | 3 kat (150.000 TL) | Katılımcılar kabul ve direniş diye ikiye ayrılır. 24 saat −8 güç. | Birlik sağlanırsa bölünme silinir ve 12 saat +6 güç gelir. | Katılımcıların yarısından fazlası, en az 2 kişi, birlik oyu verir. |
| Kuşatma Çemberi | 4 kat (200.000 TL) | 24 saat yeni katılım yoktur. Açılışta −5, sonra 6 saatte bir −5, en çok −20. | İl memnuniyeti −1. Çember bozulunca katılım yeniden açılır. | Eylemin ve hükümetin dışındaki oyuncular dayanışma ziyareti yapar. Eşik, katılımcıların beşte biri ve en az 2 kişidir. |
| İhale ve Lisans Kılıcı | 3 kat (150.000 TL) | Eyleme katılan şirket sahiplerinin kamu ihalesi 48 saat askıya alınır. Sahip çekilince o şirketin yasağı, önlemden önceki haline döner. | Her şirket için iş dünyası tepkisi: ülke memnuniyeti en çok −3 ve eyleme en çok +12 güç. | Şirket sahibi eylemden çekilir. |
| Toplu Sanal Gözaltı | 8 kat (400.000 TL) | En az 4 katılımcı varken, en çok 5 kişi (biri içeride kalacak şekilde) 6 saat oy ve sohbet kullanamaz. Eylemde kalırlar. | Ülke memnuniyeti −5, 12 saat +12 sempati ve basın skandalı. En ağır siyasi bedel budur. | Süre dolunca haklar geri gelir. Bu önlemin kısaltan bir itirazı yoktur; bedeli memnuniyet ve seçim kaydıdır. |

Yeni çağrılar `sokak_sert_islem` ve `sokak_sert_panel`. Yalnız authenticated rolüne açıktır. Şema `20261109210000_halk_sert_onlem.sql` içindedir ve bu değişiklikle canlı veritabanına uygulanmamıştır.

## Eylem Merkezi — 2026.11.09

Ekranın başında tek kart vardır: kalabalık, nabız, hazinenin biriken bedeli ve önerilen hamle. Eski düğmeler altta kapalı durur; kaybolmaz.

Eylemci on iki sert hamle açabilir. Genel grev, yol kapatma ve vergi itaatsizliği il kasasına giren parayı keser. Açlık grevi sempatiyi saatle artırır ve o kişinin taktiğini kapatır. Bakanlık önü oturma ilgili bakanın itibarını düşürür. Üç ilde eylem varsa zincir kurulur. Hükümetteki biri not sızdırır; kabine oyu onu açığa çıkarır. Gensoru baskısı İçişleri için meclis önergesi açar. Boykot kalkanı ihale kılıcını ve mali kuşatmayı durdurur. Gece meşalesi yalnız 00.00–01.00 arasında yanar.

Sembolik işgal belediye ya da valilik binasını tutar. Yeni bina kararı ve valilik ataması yazılamaz. İşgalciler birer saatlik nöbet tutar. Nöbet seyrelirse işgal dağılır. Başka ilden gelen dayanışma ziyareti güç katar. Cumhurbaşkanı, İçişleri Bakanı veya vali kuşatmayı İçişleri bütçesinden başlatır. İktidar oyuncuları kuşatma nöbeti tutar. Müzakere teklifini işgalciler oylar. Tahliye emrinden sonra 30 dakika sayılır. Sonuç, katılan insan sayısı ağır basacak şekilde nöbet, ziyaret, kuşatma ve nabızla hesaplanır. Hükümet kazanırsa bina boşalır ve savunanlar 6 saat hamle kullanamaz. Eylemci kazanırsa hükümet sempati kaybeder ve 12 saat yeniden deneyemez. Nabız eylemciden yanaysa hükümet kazansa da memnuniyet düşer.

Her yeni hükümet müdahalesi İçişleri kasasından düşer. Kasada para yoksa işlem açılmaz. Eski yumuşak ve sert araçlar da zaten bu kasadan ödenir. Süren her eylem hazineye saatlik borç yazar. Kalabalık, grev, yol, vergi ve işgal bedeli büyütür. Tutar deftere işlenir ve iki tarafta da görünür.

Şema `20261109230000_halk_eylem_merkezi.sql`. Canlı fonksiyonların içine yama yok. Canlı veritabanına bu dosyayla uygulanmamıştır.

Eylem keyfi açılmaz. Önce çağrı, depozito ve bu ilden yeterli imza gerekir. Sayılar `oyun.sokak_denge_ayar` satırındadır: memnuniyet eşiği 55, memnuniyetsizlik eşiği 40, olay penceresi 12 saat, hesap yaşı 7 gün, depozito 50.000 TL, imza 4 kişi ve 6 saat, il beklemesi 24 saat, organizatör beklemesi 48 saat, ülke tavanı en az 2 ve aktif oyuncu / 15, saatlik güç tavanı %12, büyük hamle için ivme 35, katılımcı 8 ve nabız 45. Çağrı düşünce depozito yanar. Mevcut açılış fonksiyonu imza eşiğinde çağrılır; gövdesine yama yok. Şema `20261109250000_halk_eylem_denge.sql`.

Katılımcı, Eylem Merkezi’ndeki her aktif katılımın yanında Ayrıl düğmesini görür. Onaydan sonra yalnız kendi payı biter: açlık grevinin taktik yasağı hemen kalkar, bina ve kuşatma nöbeti, dayanışma ziyareti, tahliye sayımı, gece ışığı, sızma rolü, şafak nöbet listesi ve süren taktik düşer. Genel grev, yol kapatma ve vergi itaatsizliğinde kişi listesinden çıkılır; ödenen bedel ve hamlenin süresi durur, kesinti ise yazılan kimse kalmayınca kesilir. Eylem katılımı ve sahadaki görev zaten olan ayrılma kurallarını kullanır. Ayrılmak parayı iade etmez. Aynı yere dönmek için kısa bir bekleme vardır. Şema `20261109240000_halk_katilim_ayril.sql`.
