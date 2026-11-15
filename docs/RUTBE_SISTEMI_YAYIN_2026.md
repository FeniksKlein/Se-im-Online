# Rütbe Sistemi — Lansman Kuralları (15 Kasım 2026)

Seçim Simülasyonu Online'da rütbe, bir oyuncunun kıdem puanına göre belirlenen uzun vadeli ilerlemesidir. Oyuncunun yetkisi sunucu tarafından denetlenir; arayüzde görünen bir rozet yetki vermez.

## Sabit rütbe merdiveni

| Basamak | Adı | Kıdem eşiği | Aynı anda aktif şirket hakkı | Temel açılım |
|---|---|---:|---:|---|
| 0 | Yeni Gelen | 0 | 0 | Temel oyun ve siyasi katılım (vatandaşlık şartlarına tabi) |
| 1 | Vatandaş | 10 | 1 | Şirket/dernek/gazete kurma, parti kurucular kuruluna katılım |
| 2 | Saygın Vatandaş | 30 | 2 | Parti kurma başvurusu, reklam/anket ajansı |
| 3 | Kanaat Önderi | 75 | 3 | Banka kurma |
| 4 | Duayen | 150 | 5 | Duayen Rozeti (profilde onur unvanı) |
| 5 | Yaşayan Efsane | 300 | 8 | Yaşayan Efsane Nişanı (profilde onur unvanı) |

Kuruluş bedelleri, hesap yaşı, kurucu sayısı, sermaye, ruhsat ve seçmenlik şartları **ayrıca** uygulanır. Mevcut şirketler, kıdem ve diğer oyuncu varlıkları reformdan dolayı silinmez.

## Kıdem kazanma

Günün ilk maaş toplaması: +1 kıdem (ilin bonusu artırabilir). Seçim ve referandumda oy: +3. Miting düzenleme +1, katılım +0,5; stant açma +1, gönüllülük +0,5; il teşkilatı +1; parti açıklaması +0,5; Meclis kanun oyu +0,5, Meclis seçimi +1 ve akşam yoklaması +1. Bu kaynakların günlük tavanları veritabanındaki `oyun.kidem_kaynak` tablosundadır. Kanuni görevler/etkinlikler ve tutulmuş vaatler ek kıdem sağlayabilir; tutulmayan vaat, başarısız kriz yönetimi, kredi takibi ve bazı yaptırımlar kıdem eksiltebilir.

## Maaş primi

Lansmanda ulusal kıdem primi **%5/basamak** olarak bir defa başlatılır; her basamak maaş katsayısına +%5 ekler: ×1,00 / ×1,05 / ×1,10 / ×1,15 / ×1,20 / ×1,25. Prim gelecekte oyun içi yetkili hükümet tarafından değiştirilebilir; bu reform bir kez işlendiği için sonraki hükümet kararlarını yeniden %5'e zorlamaz. Maaş formülü diğer katsayılar, makam ödenekleri ve kesintilerle birlikte çalışmaya devam eder.

## Prestij, yetkiler ve denge

Duayen ve Yaşayan Efsane rozetleri profil kimlik kartında ve statü rehberinde görünür. Rütbe yalnızca açıkça tanımlanmış kuruluş/kariyer erişimleri, şirket limitleri, maaş ve prestij sağlar. Rütbeyle otomatik bakanlık, milletvekilliği veya cumhurbaşkanlığı **verilmez**; seçimde tek oy ilkesi devam eder. Var olan eşitlik bozma/kıdem sıralaması gibi kurallar bu reformla değiştirilmez.

## Kalıcılık ve dağıtım

- Sunucu geçişi: `gelistirici/sql/210_rutbe_lansman_dengesi.sql`; güncelleme işaretçisi: `oyun.tarife.rutbe_reformu_20261115`.
- Bütünleşik SQL üreten dosya: `gelistirici/build/sql_birlestir.js`. 210 yaması en son derlenir; canlı veritabanında yeniden başlangıç primini zorlamaz.
- Oyuncu ekranı: `gelistirici/www/fiyat_tarifesi.js`; kimlik kartı: `gelistirici/www/premium_arayuz.js`.
- Versiyon kaynağı: `gelistirici/SURUM`. Web otomatik derleme ile yayına alınır. Mağazadan indirilmiş iOS/Android uygulamasında yeni görünümün görülmesi uygulamanın güncellenmesini gerektirebilir; sunucudaki rütbe hakları ise hemen geçerlidir.
- Test: `gelistirici/test/rutbe_reformu_sozlesmesi.py`; derleme iş akışında çalışır.

**Koruma:** Mevcut oyuncuların hesapları, para/kıdem bakiyeleri, makamları, şirketleri, partileri ve oyları değiştirilemez. Reform öncesi yedek alınır.
