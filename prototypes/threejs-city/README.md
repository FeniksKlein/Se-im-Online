# Seçim Online — izometrik Ankara şehir demosu

Bağımsız oyun prototipi. Canlı arayüze (`www/`), Supabase’e, SQL’e ve mağaza paketine bağlı değildir. Bu dalda onlar değişmedi.

Eski pilot dört renkli kutuydu. Bu demo aynı etkileşimi korur (tek parmakla kaydırma, yakınlaştırma, kuruma dokununca panel) ve şehri yollar, araçlar, ağaçlar ve Ankara’daki yapılardan esinlenen kurum binalarıyla değiştirir.

## Çalıştırma

Depo kökünde:

```bash
python3 -m http.server 8091
```

Tarayıcıda `http://127.0.0.1:8091/prototypes/threejs-city/` adresini açın. ES modülleri için dosyayı `file://` ile açmak yetmez. Three.js ve modeller prototip klasörünün içindedir; sayfa açıldıktan sonra ağ gerekmez. WebGL gerekir.

Mobil tarayıcıda da aynı adres açılır. Kontroller:

- Bir parmak: kaydır (pan)
- İki parmak veya tekerlek: yakınlaştır
- TBMM, belediye, banka veya parti merkezine dokun: kurum paneli
- Genel görünüm: kamerayı başa alır

Paneldeki sayılar örnektir. “Kurum masasını aç” canlı oyundaki ekrana gitmez.

## Sahnede ne var

Kuzeyde sütunlu, alınlıklı tören cepheli bir meclis (TBMM düzeninden esinlenir; ölçü alınmış bir röleve değildir). Saatli belediye konağı, cam giydirme banka kulesi ve amblemli parti merkezi. Parti amblemi yıldızlı genel bir rozettir; gerçek bir parti logosu değildir.

Aralarında Kenney yol karoları (kaldırım, şerit, yaya geçidi, kavşak), sokak lambası, trafik ışığı, iğne yapraklı ağaçlar, saksı ve ölçeklenmiş araçlar vardır. Konutlar, dükkânlar, çınar benzeri ağaçlar, çeşme ve banklar bu demo için üretilmiş geometridir.

## Lisanslar

| Kaynak | Sürüm | Ne kullanıldı | Lisans |
| --- | --- | --- | --- |
| [Kenney City Kit (Roads)](https://kenney.nl/assets/city-kit-roads) | 2.2 | Yol, kaldırım, çim karosu, lamba, trafik ışığı | CC0 1.0 |
| [Kenney City Kit (Suburban)](https://kenney.nl/assets/city-kit-suburban) | 2.0 | İğne yapraklı ağaç, taş patika, saksı | CC0 1.0 |
| [Kenney Car Kit](https://kenney.nl/assets/car-kit) | 3.1 | Sedan, taksi, van, SUV, polis, ambulans | CC0 1.0 |
| [Three.js](https://github.com/mrdoob/three.js) | r170.0 | `vendor/` altında motor, OrbitControls, GLTFLoader | MIT |
| Bu depo | — | Kurum binaları, konut ve dükkânlar, çatı dokuları, bayrak, saat, amblem, çeşme, bank, geniş tepeli ağaç, arayüz | Proje kaynağının parçası |

Kenney paketlerinin kendi `License.txt` dosyaları `assets/kenney/*/License.txt` içindedir. CC0 metni: <https://creativecommons.org/publicdomain/zero/1.0/>. Atıf zorunlu değildir; Kenney’ye teşekkür edilir.

Dosyalar OpenGameArt üzerindeki aynı CC0 arşivlerden alındı (Kenney’nin kendi indirme sayfası bağış adımına düşüyor): `kenney_city-kit-roads_2.2.zip`, `kenney_city-kit-suburban_2.0.zip`, `kenney_car-kit_3.1.zip`. Repoya paketin tamamı değil, sahnede kullanılan glTF dosyaları ve ortak `colormap.png` kondu.

KayKit City Builder Bits (CC0) incelendi, ızgara Kenney yollarıyla kurulduğu için sahneye alınmadı. Quaternius Downtown City MegaKit de CC0’dır; standart paket 223 MB olduğu için bu demoya kopyalanmadı.

Araç kiti şehir ızgarasından büyük modellendiği için araçlar yaklaşık 0.2 ölçeğe indirildi. Tekerlekler yol boyunca döner.

## Bilinçli olarak yapılmayanlar

- Yürüyen karakter veya oyuncu avatarı yok.
- `www/index.html`, Capacitor paketi, `supabase/` ve `migrations/` değişmedi.
- Demo oyuncu, para veya seçim verisi okumaz ve yazmaz.

## Sınırlamalar

- Canlı kurum ekranlarına bağlı değil. Panel bir arayüz iskeletidir.
- Görünüm stilize, düşük poligonlu bir şehir kurma oyununa yakındır; Tropico veya SimCity düzeyinde fotogerçekçi değildir.
- Meclis, gerçek TBMM binasının ölçüleri veya Holzmeister çizimleri değildir.
- Kenney kavşak karosu dört kolludur. Izgara kenarındaki T kavşaklarda kısa bir kol görünebilir.
- Trafik ışıkları yanıp sönmez. Gece döngüsü yoktur.
- Düşük donanımlı Android cihazlarda kare hızı ölçülmedi. Gölge haritası 2048, piksel oranı en fazla 2’dir.
- İki parmakla yakınlaştırma OrbitControls’a bağlıdır. Bu ortamda tekerlek yakınlaştırması, sürükleyerek kaydırma ve masaüstü ile 390×844 görünümde kuruma dokunma denendi; fiziksel telefonda pinch ayrıca denenmedi.

## Denenenler

Headless Chrome (SwiftShader):

- Sayfa hatasız yüklendi, `__cityReady` true oldu.
- Tekerlek ile yakınlaştırma ve sürükleyerek kaydırma kamera hedefini değiştirdi.
- 1280×800 tuvalde TBMM’ye tıklanınca “Türkiye Büyük Millet Meclisi” paneli, örnek sandalye / gündem / dönem kartları ve “canlı ekran kapalı” notu geldi. Kapat çalıştı.
- 390×844 görünümde belediyeye dokununca “Ankara Büyükşehir Belediyesi” paneli açıldı.

## Canlı oyuna bağlanmadan önce

1. 3D ekranı isteğe bağlı tutun; mevcut 2D ekran varsayılan kalsın.
2. Kurum tıklamasını bugünkü ekran açma fonksiyonlarına bağlayın. Oyuncu kaydını bu sahneden yazmayın.
3. Düşük Android’de kare hızı, bellek ve ısınmayı ölçün; gölge ve piksel oranı için kalite seçeneği koyun.
4. Capacitor WebView, CSP ve çevrimdışı açılışı ayrıca sınayın. Bu prototip yerel dosyalarla açılır, CDN beklemez.
