# Kredi notu ve bütçeye göre kredi

10 Ekim 2026 tarihinde canlı Supabase secim-online projesine kredi risk hesaplama güncellemesi uygulandı.

- Oyuncunun kredi notu (0-1900), cüzdan ve vadesiz bakiyesi, maaş/kira/şirket gelirleri hesaba katılır.
- Devlet kredisi ve oyuncu bankası kredisi limitleri geri ödeme gücü ile sınırlanır.
- Oyuncu bankası kredi başvurusu ve kredi onayı ayrı ayrı kontrol edilir.
- Banka likidite güvenliği, ortakların kendi bankasından kredi alamama kuralı ve mevcut krediler korunur.
- Oyuncu bankası kredisi zamanında tamamen kapatılırsa kredi notu artar; geç kapatılırsa azalır.

Canlı işlevler: `oyun.kredi_risk_ozeti`, `public.kredi_uygunluk`, `public.oyb_kredi_basvur`, `public.oyb_kredi_karar`, `public.kredi_cek`, `public.banka`, `public.oyb_yonetim` ve `oyun.oyb_kredi_puan_tetik`.

Not: Bu dosya bilgilendirme amaçlıdır; tek başına SQL migration değildir. Canlı veritabanında yapılan değişiklikler ayrı doğrulanmalıdır.
