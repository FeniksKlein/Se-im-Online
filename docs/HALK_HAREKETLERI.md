# Halk Hareketleri — 2026.11.07-1

Partiler → Halk Hareketleri. İl memnuniyetsizliği; ülke memnuniyeti, işsizlik, enflasyon, vergi ve belediye memnuniyetinden hesaplanır. Parti genel başkanı 50.000 TL ödeyerek 24 saatlik barışçıl eylem açar. Her 50.000 TL ek fon 12 saat ekler; başlangıçtan itibaren en fazla 120 saat. Cüzdan, parti ve dernek destekleri aynı eylemde birleşir; para ilgili kaynaktan atomik düşer ve hareket kaydı tutulur.

## Sınırlar

- Başlatan hesap en az 7 günlük; katılımcı hesap ve yerel ikamet en az 3 günlük.
- Başlatmak için ilde 3 aktif oyuncu ve 35 memnuniyetsizlik gerekir.
- İl başına tek eylem, kapanıştan itibaren 7 gün dinlenme; parti başına tek aktif eylem ve başlangıçlar arasında 72 saat.
- Ülkede en fazla 6 eylem; kişi/kurum başına en fazla 3 eşzamanlı destek.
- Son 24 saat protesto fonu: kişi 100.000 TL, kurum 250.000 TL. Uzlaşma limitleri üç katı. Bir eylemde toplam protesto fonu en fazla 1 milyon TL.
- Kırmızı için 75 puan, 40 memnuniyetsizlik, en az 5 kişi ve aktif yerel oyuncuların %30'u. Para tek başına yetmez.
- Üç kat uzlaşma fonu eylemi kapatır. Hükümet altı saatte bir somut yanıt yayımlayabilir; açıklama tek başına puan düşürmez. Hizmet iyileşmesi memnuniyetsizliği azaltır.
- Erken seçim: en az 3 kırmızı il + en az 15 farklı kişi ve aktif ülkenin %20'si, kesintisiz 72 saat. Yakın/aktif seçimler ve yeni CB'nin ilk 7 günü korunur; kriz kaynaklı seçim arasında 14 gün gerekir. Makamlar zorla silinmez, seçim takvimiyle devredilir.

## Ekonomik etkiler

Kırmızı iller için ülke çapında 24 saatte bir, en çok 2 puan memnuniyet, 0,6 puan büyüme kaybı ve 0,3 puan enflasyon artışı. Şirket değerlemesinde pozitif kâr beklentisine kırmızı il başına %1, en çok %6 risk indirimi; risk eylem sona erince kalkar. Gerçekleşmiş hisse işlem fiyatları ve defter varlıkları değiştirilmez.

## Doğrulama

`halk_hareketleri.sql` ve `halk_kriz.sql` Supabase üzerinde transaction + rollback ile çalıştırıldı: para düşümü, limitler, mükerrer katılım, hükümet yanıtı, yetkiler, süre sonu, 3x uzlaşma, ulusal sayaç, erken seçim takvimi ve piyasa riski doğrulandı. Testlerin bütün satır değişiklikleri geri alındı.

`halk_hareketleri_ui.js` jsdom 26.1.0 ile ekran/olay bağlantıları ve HTML kaçışını doğrular. Derleme ve RPC yüzeyi taraması çalıştırıldı. Yerel kalıcılık paketi psql bulunmadığı için çalıştırılamadı; Chromium ortamın socket kısıtı nedeniyle açılamadı. Gerçek cihazda oturum açılmış uçtan uca test yapılmadı.

RPC'ler yalnız authenticated rolüne açık; hesap ve kurum yetkisi sunucuda kontrol edilir. İç yardımcılar ve tablolar istemciye kapalıdır. Danışmanın RLS-politikasız tablo ve authenticated SECURITY DEFINER bildirimleri bu kontrollü RPC mimarisi için beklenir.

Cron: `halk-hareketleri`, beş dakikada bir `oyun.sokak_tick()`. Devre dışı bırakmak için yalnız `oyun.sokak_eylem_ayar.aktif=false` ayarlanır; veri silinmez. Yeni kurulum varsayılanı kapalıdır; canlı açılış testlerden sonra ayrı yapılır.
