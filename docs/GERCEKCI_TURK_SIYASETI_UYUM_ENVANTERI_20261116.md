# Seçim Simülasyonu Online — Türk siyaset hukuku uyum envanteri

Tarih: 16.11.2026. Kaynaklar: GitHub ana dalı, canlı `secim-online` Supabase PostgreSQL fonksiyonları ve Türkiye Cumhuriyeti Anayasası / siyasi partiler ve seçim mevzuatı.

**Kapsam uyarısı:** Kaynakta var olması uçtan uca gerçek oyuncu testi yapıldığı anlamına gelmez. Durumlar: **Doğrulandı** (SQL fonksiyonu ve çalışma parametresi incelendi), **Kısmi** (fonksiyon var, uygulama uçtan uca doğrulanmadı), **Uyarlama** (gerçek hukuktan bilinçli ayrılan oyuncu/nüfus/zaman ölçeği), **Açık fark** (hukukla uyuşmayan veya ayrı uygulama isteyen mekanik).

| Konu | Türkiye hukukundaki kural | Oyun ve durum |
|---|---|---|
| TBMM sandalye | 600 milletvekili (Anayasa 75) | 600, canlı SQL doğrulandı |
| Genel Kurul toplantı yeter sayısı | 600'ün 1/3'ü = 200 (md.96) | Kanun oylaması 200, ret metni 200; kaynak + canlı |
| Normal kanun kabulü | Katılanların salt çoğunluğu ve her halde asgari 151 kabul (md.96) | `oyun.kanun_tick` kontrolü mevcut; doğrulandı |
| Üye tamsayısı salt çoğunluğu | 301 | Eski fonksiyon canlıda 5 döndürüyordu; 301'e kalıcı düzeltildi |
| TBMM'nin seçim yenileme kararı | 3/5 = 360 (md.116) | `oyun.erken_secim_gerekli_oy` 360, doğrulandı |
| Cumhurbaşkanının seçim yenileme kararı | CB'nin ayrı karar yetkisi, her iki genel seçim birlikte (md.116) | `public.cb_erken_secim_karar` ile `oyun.erken_genel_secim_olustur` mevcut; kısmi |
| Siyasi parti grubu | En az 20 milletvekili (md.95) | `oyun.grup_esigi` =20, doğrulandı |
| TBMM Başkanı seçim turları | 400 / 400 / 301 ve son turda en yüksek oyu alan (md.94) | `oyun.meclis_tick` kontrolü mevcut; 4. turda 200 katılım eklendi |
| Meclis Başkanı tarafsızlığı | TBMM Başkanı siyasi parti faaliyetlerine ve Meclis oylamalarına katılmaz (md.94) | Erken seçim ve Meclis siyasi oylama RPC'lerinde yeni sunucu engeli; kanun oyunda önceden mevcut |
| Olağan kanun teklifi | Milletvekilleri verir (md.88) | `public.kanun_teklif` denetimi mevcut; doğrulandı |
| Bütçe teklifi | Cumhurbaşkanınca sunulur (md.161) | `public.kanun_teklif` doğrulandı |
| Bütçe geri gönderme | Cumhurbaşkanı bütçe kanununu geri gönderemez (md.89) | `public.kanun_cb_karar` doğrulandı |
| Normal kanuna karşı yeniden kabul | Üye tamsayısı salt çoğunluğu 301 (md.89) | `oyun.kanun_tick` kontrolü mevcut; doğrulandı |
| Anayasa değişikliği | En az 200 teklifçi, iki görüşme, asgari 360 oy, 360-399 halkoylaması, 400+ için yayımlama/referandum (md.175) | Kaynakta ve `oyun.kanun_tick`'te mevcut, gerçekçi mod açık; kısmi uçtan uca |
| Milletvekili genel seçim barajı | %7 (2839 sayılı Kanun) | `oyun.ayarlar.baraj` =7, doğrulandı |
| CB adayı parti yolu | En az 20 vekilli parti grubu veya son genel seçimde birlikte/tek başına en az %5 oy (md.101) | `oyun.cb_parti_aday_gosterebilir` mevcut; kısmi |
| CB adayı seçmen yolu | 100.000 seçmen (md.101) | Oyuncu sayısına göre %3, en az 10 imza ve 50.000 TL oyun teminatı; **uyarlama**, birebir hukuk değil |
| Siyasi parti kuruluşu | 2820/8 uyarınca en az 30 Türk vatandaşı, ön izin gerekmez | Oyunda 7 ve aktif oyuncuya göre artan sayı; **uyarlama** |
| Milletvekilliği ve bakanlık | MV, CB yardımcısı veya bakan atanırsa vekilliği sona erer (md.106) | Güncel görev uyum migration mevcut; kısmi |
| Genel seçim dönemi | Normal dönemde 5 yıl (md.77) | Oyunda çok daha kısa düzenli takvim, lansmanda 7. gün ilk seçim; **uyarlama** |
| Mahkeme kararı ve gözaltı | Hukuka aykırı tutma yargısal denetimle derhal kaldırılmalı; mahkeme kararları uygulanmalı (md.19/138) | İki `sokak_gozalti` yargı RPC'sinde doğrudan serbest bırakma 16.11.2026'da uygulandı |
| Cumhurbaşkanının doğrudan gözaltı başlatması | Ceza muhakemesinde kolluk/savcılık ve yargı usulü gerekir, keyfî siyasî tutma yetkisi yok | `public.yonetim_tutuklama_yap` doğrudan siyasi yetki veriyor; **açık fark**, savcılık/soruşturma sistemi gerektiriyor |
| Sokak eylemi | Anayasa md.34, 2911 sayılı Kanun ayrı usul ve güvenceler öngörür | Makro eylem imzaları ve fonlama oyun mekaniği; **kısmi/uyarlama**, küçük barışçıl siyasi ifade hakkı korunmalı |
| Yerel seçim ve belediye yetkileri | Belediye başkanlarının seçimi ve görevden ayrılması özel mevzuatla bağlı | Oyun sistemleri var; belediye atama/parti değişimi/istisna yolları uçtan uca ayrıca denetlenmeli |
| Kanun değiştirme etkisinin seçimlere yansıması | Anayasa md.67 uyarınca seçim kanunlarında değişiklikler 1 yıl içindeki seçimlerde uygulanmaz | Seçim takvimini hızlandırılmış oyun süresine uyarlama kuralı ayrıca tasarlanmalı |

## Bu denetimde gerçekten uygulanan değişiklikler

- Supabase migration `tbmm_salt_nisap_oy_guvencesi_20261115`: 301 çoğunluk, erken seçimde oy değişimini engelleme, Meclis Başkanı oy yasağı, 4. tur toplantı nisabı, kanun ret mesajı. Canlı SQL doğrulaması başarılı.
- Supabase migration `mahkeme_gozalti_tahliye_bagimsizligi_20261116`: hâkim ön incelemesi ve mahkeme kararında hukuka aykırı gözaltının derhal sona erdirilmesi. Canlı SQL doğrulaması başarılı.
- Kaynakları `gelistirici/sql/zz_20261116_*.sql`, `gelistirici/build/sql_birlestir.js` ve `gelistirici/test/gercekci_siyaset_sozlesmesi.py` içerisinde korundu.
- Beta oyun kayıtları, geçmiş oylar ve mevcut oyuncu bakiyeleri silinmedi. Lansman sıfırlaması bağımsız operasyon olarak kaldı.

## Tamamlanmadan birebir hukuk uyumu ilan edilmemesi gereken başlıklar

1. Savcılık, kolluk ve mahkemeye bağlı gözaltı/tutuklama başlatma; keyfî CB ve bakan işlemlerinin kaldırılması.
2. Meclis komisyonlarının İçtüzük usulleri, araştırma/soruşturma, konuşma ve gündem takvimi.
3. CB adaylığı, dönem/yeniden seçilme istisnaları, seçim çevresi ve D'Hondt testleri, itiraz ve YSK eşdeğeri kurum.
4. Partilerin kurultay, üyelik, mali denetim, hazine yardımı, kapatma ve kuruluş süreçlerinin hukuki / oyun uyarlaması ayrımı.
5. Bakanlıkların gerçek anayasal yetki sınırları, idari yargı ve Sayıştay, belediye başkanlığının seçimi ve hukuki sona ermesi.
6. Kanunların yayımlanması, yürürlük zamanı, bütçe yılı ve seçim kanunu değişiklikleri geçiş dönemi.
7. 200/301/360/400 oyuncu vekil gerektiren durumlarda test: mevcut betada 9 görevde vekil olduğundan bilinçli anayasal tıkanma vardır. Sayılar az oyuncuya göre düşürülmez.
8. Beta, 3 bin ve 10 bin kullanıcı, mobil paket ve gerçek cihaz testleri. CI derleme geçmesi uçtan uca doğrulama yerine geçmez.

## Resmî kaynaklar
- Anayasa: https://www.anayasa.gov.tr/tr/mevzuat/anayasa/
- Siyasi Partiler Kanunu md.8 (Adalet Bakanlığı): https://mevzuat.adalet.gov.tr/mevzuat/103476?query=Madde+15
- TBMM İçtüzüğü: https://www.tbmm.gov.tr/ictuzuk
- YSK: https://www.ysk.gov.tr/

Bu rapor bitmişlerin ve hâlen açık farkların kalıcı kaydıdır; otomatik olarak gelecekte iş yapılacağı veya bütün oyunun eşzamanlı hukuken tamamlandığı iddiası değildir.
