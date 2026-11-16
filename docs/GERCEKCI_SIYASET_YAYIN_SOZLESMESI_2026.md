# Seçim Simülasyonu Online — Gerçekçi Türk siyaseti yayın sözleşmesi

Sürüm başlangıcı: 15 Kasım 2026. Durum: Gerçekçi siyaset kuralları mevcut beta oyununda aktif (`gercekci_siyaset=true`). Lansman sıfırlaması bundan ayrı ve kontrollü işlemdir.

## Kapsam ve değişmez yayın prensibi

Oyun, küçük beta grubuna göre verilen keyfî çoğunluk ve imza muafiyetlerinden vazgeçer. Türkiye Cumhuriyeti Anayasası, TBMM İçtüzüğü ve seçim mevzuatı siyasi sistemin referansıdır. Gerçek dünyada oyuna birebir taşınamayacak nüfus, süre ve gerçek kimlik koşulları **açıkça oyun uyarlaması** olarak etiketlenir. Seçmen desteği yerine para yatırarak demokrasi şartları aşılamaz.

### TBMM — 600 üyelik tam sayı

- Anayasa md. 95: Siyasi parti grubu kurmak için en az **20 milletvekili**.
- Anayasa md. 96: Genel Kurul toplantı yeter sayısı **200 milletvekili**, olağan kanun/karar için katılanların salt çoğunluğu; her hâlükârda en az **151 olumlu oy**. Sayılar o an çevrimiçi olan kullanıcıya göre azaltılmaz.
- Anayasa md. 116: Meclis seçimlerin yenilenmesine **360 oyla** karar verir. Her milletvekili önerge verebilir. Cumhurbaşkanının ayrı karar yetkisi vardır. İki seçim birlikte yenilenir.
- Anayasa md. 94: Meclis Başkanı seçiminin ilk iki turunda **400**, üçüncü turunda **301** oy; dördüncü turda üçüncü turun en çok oy alan iki adayı ve en yüksek oy. Seçimde gizli oy. TBMM Başkanı Genel Kurulda oy kullanmaz.
- Milletvekilliği sadece oyuncunun 7 gün oyuna girmemesi nedeniyle düşmez. Oyuncunun makamı ve siyasi statüsü ayrı tutulur.
- Anayasa md. 88/161: Olağan kanun teklifleri milletvekillerinden; bütçe teklifi Cumhurbaşkanından gelir. Bütçe kanunu Cumhurbaşkanınca geri gönderilemez (md. 89).
- Normal kanun veto edilirse Meclis üye tam sayısının salt çoğunluğuyla (**301**) aynen kabul etmek zorundadır.

### Anayasa md. 175

- En az **200 milletvekili** imzayla teklif verebilir.
- Genel Kurulda iki görüşme; ikincisi ilk görüşmeden **en az 48 saat sonra**. Oyunda bu iki safha ayrı, gizli elektronik pusula olarak modellenmiştir. Madde madde görüşme ayrıntıları gelecekte genişletilecek oyun uyarlamasıdır.
- En az **360** kabul oyu zorunludur. **360–399** oyda Cumhurbaşkanı geri göndermezse halkoylamasına gidilir. **400 ve üzeri** oyda Cumhurbaşkanı yayımlayabilir veya referanduma sunabilir. Gerekçeli iade sonrası aynen kabulde **400** aranır.
- İkinci görüşme başladığında ilk teklif imzaları yeniden çekilemez ve aynı imza kotası ikinci kez aranmaz.
- Gizli oylamanın kimin ne oy verdiğini ifşa eden kayıtları kamu arayüzüne dökülmez; kendi oyu ise seçmenin ekranında gösterilir.

### Siyasi partilerin Cumhurbaşkanı adayı göstermesi

- Anayasa md. 101 ve 6271 sayılı Kanun md. 7: Mecliste **en az 20 milletvekiliyle siyasi parti grubu** kurmuş parti veya en son milletvekili genel seçiminde tek başına ya da birlikte **en az %5 oy** almış siyasi partiler aday gösterebilir.
- Seçim sonucundaki gerçek parti yüzdeleri ve o seçime ait ittifak üyeliğinin anlık tarihî kaydı esas alınır. Daha sonra yapılan ittifak değişikliği eski seçimdeki oyu geriye dönük değiştirmez.
- İlk lansman seçimi için geçmiş geçerli genel seçim olmadığından yalnızca dört hazır sistem partisine geçici aday gösterme hakkı tanınır. Sonraki seçimlerde normal anayasal koşullar aranır.
- Seçmen imzasıyla bağımsız adaylık, bu parti adaylığı yolu dışında ayrı işler.

### Cumhurbaşkanı adaylığı — oyun nüfusuna uyarlama

- Türkiye'de seçmen tarafından aday gösterme için 100.000 imza gerekir. Oyunda bağımsız aday için aktif, uygun seçmenlerin **en az %3'ü**, asgari **10 geçerli imza**, ve **50.000 TL** teminat kuralı uygulanır.
- İmza ve teminat tamamlanana kadar kişi aday pusulasına alınmaz. Yeterli imza tamamlanınca teminat iade edilir.
- Aynı seçmen aynı cumhurbaşkanlığı seçimi için birden fazla bağımsız adaya imza atamaz; kayıt benzersiz veritabanı anahtarıyla korunur.
- Bu rakamlar **kanuni adaylık şartlarının birebir sayıları değil**, gerçek oyunun oyuncu nüfusuna uyarlamasıdır. Parti adaylıkları için anayasal usul ayrı uygulanmalıdır.

### Eylem ve halk hareketleri — siyasi etki oyunu

- Anayasa md. 34 barışçıl toplantı ve gösteri hakkını korur. Oyun içindeki siyasi **ifade, paylaşım ve barışçıl itiraz hakkı**, makro eylem eşiklerine tabi değildir.
- Hükümet, borsa ve kamu düzenine büyük siyasi etki yapan oyun mekaniğinde en az **10 doğrulanmış destekçi** veya son 7 gün aktif seçmenlerin **%1'i** (hangisi daha yüksekse) gerekir.
- Doğrudan eylem açma RPC'si veya doğrudan INSERT ile imza aşaması atlanamaz; sunucu tetikleyicisi zorunludur. Başka oyunculara sunucu tarafında çifte imza yazdırılamaz.
- 2911 sayılı Kanunun en az 7 kişilik düzenleme kurulu ve 48 saatlik idari bildirim gibi gereklilikleri **henüz tüm ayrıntısıyla simüle edilmemiştir**; bu siyasi kriz/eylem mekaniği gerçek dünyadaki toplantı hakkının hukuki koşullarıyla karıştırılmamalıdır.

## Süreklilik ve kodun tek kaynağı

1. Her yeni `gelistirici/sql/zz_20261115_*.sql` dosyası `gelistirici/build/sql_birlestir.js` içindeki sıraya eklenir. Tek dosya `supabase-kurulum.sql` yeniden üretilir.
2. `gelistirici/test/gercekci_siyaset_sozlesmesi.py` kaynak denetimi GitHub Actions'ı geçmeden yeni derleme başarılı kabul edilmez.
3. `gelistirici/www/index.html` kaynak oyuncu ekranıdır. GitHub Actions bunu `docs/index.html` ve `www/index.html` yayın kopyalarına aktarır. iOS/Android mağaza paketleri **ayrıca yayımlanır**.
4. Canlı beta oyununda `oyun.ayarlar.gercekci_siyaset=true` etkin, varsayılanı true'dur; resmî lansmanda da açık tutulur. **Resmî lansman sıfırlaması** yalnız yedek, kalıcı satın almalar ve doğrulamalar sonrası `gelistirici/sql/lansman_4_parti_100bin_7gun_2026.sql` ile `true` yapar.
5. Lansman SQL'inde dört temsili parti, 100.000 TL başlangıç bakiyesi, %7 seçim barajı ve ilk genel seçimin yedinci gün yapılması kararı korunur.
6. Mobil yayın açılmadan önce: eski oyuncu verisi ve mağaza hakları yedeklenecek, 2, 50, 200, 600 ve 10.000 eşzamanlı kullanıcı senaryolarında test koşulacak, gerçek cihaz akışları ve güvenlik/rol testi doğrulanacak.
7. **Başlangıç riski**: 600 üzerinden 200 kişilik yasal toplantı nisabı için en az 200 görevde gerçek milletvekili gerekir. Lansmanda 200 milletvekili yoksa, Meclis faaliyetleri anayasal nedenle tıkanabilir. Bu durum sayıları birkaç kişiye göre düşürerek gizlenmez; oyuncu erişim/üyelik hedefiyle çözülür.

## Resmî mevzuat bağlantıları

- Anayasa Mahkemesi: https://www.anayasa.gov.tr/tr/mevzuat/anayasa/
- TBMM İçtüzüğü: https://cdn.tbmm.gov.tr/TbmmWeb/Anayasa/ictuzuk.pdf
- 2911 sayılı Kanun: https://www.mevzuat.gov.tr/mevzuatmetin/1.5.2911.pdf

Bu bir *yayın sözleşmesi ve uygulanan/yayın öncesi tamamlanacak koşullar* belgesidir; henüz yapılmamış yük testi veya mağaza onayı yapılmış gibi gösterilmez.

## 16 Kasım 2026 — Canlı anayasal nisap uyum yaması

- Canlı doğrulama: TBMM tam sayısı 600, erken seçim oyu 360, siyasi grup 20, toplantı yeter sayısı 200; olağan kanun en az 151 olumlu oy, tam üye salt çoğunluğu 301.
- `oyun.salt_cogunluk()` fonksiyonu 9 fiilî milletvekiline göre yanlışlıkla 5 döndürüyordu; gerçekçi modda 301'e düzeltildi.
- Erken seçim oyu bir kere kullanılır, sonradan değiştirilemez. Meclis Başkanı siyasi oylamaya katılamaz.
- Başkanlık 4. turu en az 200 katılım olmadan kesinleşmez. Kanun oylaması ret gerekçesindeki nisap ifadesi doğru hesaplanır.
- Bu yamalar oyuncu, oy geçmişi, para, parti veya makam verilerini silmez. Sunucu migration başarılı ve sonuçları SQL ile doğrulanmıştır. Kalıcı kaynak: `gelistirici/sql/zz_20261116_tbmm_nisap_oy_koruma.sql`.
- Oyun uyarlamaları (süre sıkıştırması, 7 oyunculu parti kuruluşu, bağımsız CB adaylığında 100.000 gerçek seçmen yerine oran) hukukî birebir kopya olarak sunulmaz.
