# 3.000 oyuncu / 600 MV / 81 belediye kalite kapısı

Bu daldaki SQL yamaları **canlıya uygulanmamıştır**. Test ortamı için ayrıca ücretli Supabase branch açma onayı gereklidir. Test dalı ana verileri taşımaz.

## Değişiklik kapsamı
1. TBMM Başkanlığı için ortak `tbmm_baskan_gerekli` hesaplaması; ekran ve motor aynı eşiği kullanır.
2. Yüksek Mahkemenin üçüncü (TBMM) koltuğundan eski Adalet Bakanı seçim engeli kaldırılır; üç koltuğun parti ve görev kısıtları eşitlenir.
3. Ocak 2027 iptal seçimleri için veri/yetki/oy/kazanan korumalı **manuel** geri açma operasyonu hazırlanır.
4. Boş belediyeler için varsayılan **kuru çalışma** modunda 81 il taraması hazırlanır; otomatik cron *henüz bağlanmadı*.
5. `600_milletvekili_81_il_kontrol.sql` salt okunur 6 senaryoyu test eder.
6. Çift adaylık tetikleyicisi temizlenir; mevcut merkezî makam bağdaşmazlığı motoru korunur. Uçtan uca geçiş testleri şarttır.
7. Şirket/parti/bakanlık/banka/cüzdan negatif bakiye ve havale çift-harcama koruması aday yaması hazırlanır.
8. Oy tablosundaki `UNIQUE(secim_id,secmen)` doğrulandı; `finans_oy_suistimal_deneti.sql` riskleri kişisel veri dökmeden tarar.
9. k6 yük testi yalnız bağımsız test ortamı ve 3.000 sentetik JWT ile çalışır; canlı projeye yük bindirme engellidir.
10. Siyasi ekip meslek davetleri (MV danışmanı, belediye danışmanı, parti kampanya ve organizasyon) için güvenli backend eklendi. UI bağlantısı henüz gerekli.

## Yayına çıkış kapıları
- Canlı Supabase'de **secim-motoru** cron pasif gözlendi; bakım kararı olup olmadığı açıklığa kavuşmalı.
- Test Supabase branch'inde sıralı SQL migration, uçtan uca davet/oy/makam/itiraz testi.
- Oylamada aynı kişi bir kez oy kullanabilir, para transferlerinde eşzamanlı bakiyeler negatife düşmez.
- 81 il ve toplam 600 kontenjan veri bütünlüğü.
- 500/1000/3000 VU k6 test sonuçları kaydedilmeli.
- Canlıya geçişte yedek, bakım penceresi, rollback ve sürüm onayı.

## Bilinen sınırlar
- Burada gerçek 3.000 bağlantılı yük testi **çalıştırılmadı**.
- Kişi/makam/oy/kasa kayıtları değişmedi.
- Ocak 2027 onarımı ancak ayrıca ve dikkatle işletilir.
- Otomatik 81 il taraması için zamanlayıcı entegrasyonu ve meslekler için arayüz hâlâ tamamlanmalı.

## Test komutu (yalnız TEST projesi)
```bash
RUN_APPROVED=EVET TEST_RPC_URL=https://TEST-REF.supabase.co/rest/v1/rpc/durum \
 TEST_PUBLISHABLE_KEY=TEST-KEY TEST_TOKENS_FILE=./test-tokens.local.json \
 k6 run gelistirici/test/k6_3000_secim_gecesi.js
```
