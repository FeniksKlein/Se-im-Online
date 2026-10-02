# Seçim Simülasyonu Online

Gerçek oyuncuların oynadığı online siyaset oyunu: seçimler, makamlar, devlet ekonomisi, belediyeler, vaatler.
Tek dosyalık HTML uygulaması (`www/index.html`), Capacitor ile iOS/Android'e paketlenir; sunucu Supabase (PostgreSQL).

| Dosya | Ne işe yarar |
|---|---|
| `KURULUM.md` | Adım adım kurulum rehberi (Supabase, giriş, push, reklam, satın alma) |
| `TASARIM.md` | Oyunun tüm kuralları |
| `supabase-kurulum.sql` | Sunucunun tamamı; Supabase SQL Editor'a yapıştırılır |
| `www/index.html` | Telefon uygulaması |
| `push-gonder.ts`, `odeme-webhook.ts` | Supabase Edge Function'ları |
| `gelistirici/` | Kaynak parçalar, testler, derleme komutları |

Oyunda bot/NPC yoktur; yalnızca gerçek oyuncular vardır.
Gizli anahtarlar (service_role, FCM hizmet hesabı, ODEME_GIZLI) bu depoya **asla** konmaz.
