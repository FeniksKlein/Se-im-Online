# 16 Kasım 2026 — Geçersiz erken seçim iptali, 1 Aralık normal genel seçimlerinin yeniden etkinleştirilmesi

**Durum: CANLI SUNUCUDA UYGULANDI VE SQL SORGULARIYLA DOĞRULANDI.**

## Gerekçe
15 Kasım 2026 tarihli erken seçim önergesi #6, yalnızca **6 kabul** oyuyla kabul edilmişti. `oyun.gercekci_siyaset()=true` olduğunda geçerli Anayasa md.116 eşiği 600 milletvekili üzerinden **360 kabul** oyudur. Önceki beta kuralıyla yanlışlıkla kabul edilen bu önerge geçersizleştirildi.

## İşlem, kapsam ve sonuç
- Supabase migration: `20261116053423_gecersiz_erken_secim_6_iptal_aralik_2026_geri_ac` (işlem başarılı).
- Geçersiz önerge: `oyun.erken_secim_teklifleri.id=6`, durum `kabul` -> `ret`; altındaki **6 eski kabul oyu tarihsel kayıtta kalır**.
- Erken seçim dönemi `erken-genel-6-20261115234022`: `mv_on`, `cb_on` (17 Kasım 2026), `mv`, `cb` (18 Kasım 2026) toplam 4 kayıt: `durum=tamam`, `sonuc.iptal=gerekli_360_oy_saglanmadi`. Bunlar artık canlı seçim olarak sayılmaz.
- Normal dönem `2026-12`: `mv_on`, `cb_on` (28 Kasım 2026 TSİ 08.00–22.00) ve `mv`, `cb` (1 Aralık 2026 TSİ 08.00–22.00) toplam 4 kayıt: `durum=bekliyor`, `sonuc=NULL`.
- Önceki 8 seçim satırının JSON bütünlüğü ve önerge #6'nın önceki hali `oyun_yonetim.secim_takvim_iptal_audit` tablosunda `20261116_gecersiz_erken_secim_6` anahtarıyla saklandı (tablo RLS etkin, anonim/oturumlu kullanıcıya yetki yok).
- Önceden oy kullanılmış normal Aralık genel seçim kaydı olmadığı ayrıca kontrol edildi; hiçbir oy, aday, profil veya mali veri silinmedi.
- `public.durum()` takvim üretirken `sonuc ? 'iptal'` koşulu ile iptal edilmiş seçimleri dışladığı için hatalı 17–18 Kasım takvimi Gündem'de görünmez.
- Diğer geçmiş / normal / belediye / kurultay seçimleri değiştirilmedi. Eski 14–17 Kasım tarihli `gecersiz_erken_secim_karari` işaretli seçimler olduğu gibi bırakıldı.

## Canlı doğrulama
- Aralık 2026 dört normal seçim: `bekliyor`.
- 17–18 Kasım 2026 hatalı erken seçimin dört kaydı: `tamam`, iptal işaretli.
- Önerge #6: `ret`, `kabul=6`, `gerekli=360`.
- `ara_neden='erken_secim'` olan gelecek ve iptalsiz `bekliyor` seçim sayısı: **0**.
- `oyun_yonetim.secim_takvim_iptal_audit` kaydı: **8 seçim anlık görüntüsü**.

## Kaynak ve tekrar uygulama politikası
İşlem kaynağı: `gelistirici/operasyonlar/20261116_gecersiz_erken_secim_6_iptal_1_aralik_geri_ac.sql`.

Bu SQL yalnızca geçmişteki belirli beta kazasını geri almak için bir kez çalıştırılmıştır. **Ana `supabase-kurulum.sql` birleştirme listesine eklenmez**; gelecekte oyun resetlenirse veya yeni bir dünya kurulursa eski tarihsel olayı tekrar değiştirmek ya da hata vermek istemiyoruz. Canlıda zaten uygulanmış olduğundan tekrar yürütülmemelidir. 360 oy eşik koruması canlı `oyun.erken_secim_gerekli_oy()` fonksiyonuyla kalıcı tutulur.
