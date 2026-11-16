# 16.11.2026 kabul testleri (canlıda, geri alınan alt işlemle)

Her migration sonunda kabul testi çalıştı; sonuç `oyun.migration_test_sonuc` tablosunda.
Test başarısız olsaydı migration tamamen geri alınacaktı.

| Migration | Test | Sonuç |
|---|---|---|
| kredi_denge_20261116 | test/kredi_denge_kabul.sql | 30 ve 365 gün limiti eşit (268.200 ₺); 6,3 M ₺ borçla 1 M ₺ şirket kurulamadı; borç düşünce kuruldu; MASAK kaydı oluştu |
| davet_aktiflik_20261116 | test/davet_aktiflik_kabul.sql | 3 gün → 5.000 ₺; 7 gün → 15.000 ₺; 2. kademe %20 → 3.000 ₺; tekrar ödeme yok |
| mod_gorev_finans_20261116 | migration içinde (M1–M3) | Finans ana görevi MASAK yetkisini ekledi; 6 görev tanımı; finans masası moderatörde açıldı |
| kayit_onay_ad_soyad_20261116 | migration içinde (R1–R6) | Kayıt yetkisi olmayan mod göremedi; "Recep Tayyip Erdoğan" uyarısı; ret; aynı isimle yeniden başvuru engellendi; yeni isimle başvuru ve onay; profil ad soyadı yazıldı |
| kurucu_partiler_20261116 | migration içinde (P1–P6) | Oy 5. gün, göreve başlama 8. gün; üyelik kesimi oy gününden 24 saat önce; tek üyeli kurucu parti lidersiz kaldı; vekâlet yok; ikinci çağrı yeni kurultay açmadı |
