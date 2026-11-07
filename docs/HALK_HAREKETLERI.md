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
