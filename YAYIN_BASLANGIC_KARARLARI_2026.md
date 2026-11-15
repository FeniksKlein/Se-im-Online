# Seçim Simülasyonu Online — resmî lansman başlangıcı (15 Kasım 2026)

Bu dosya lansman kararlarını kaydeder. Mevcut test oyununu sıfırlamaz.

## Oyun kuralları
- Bütün eski oyun ilerlemesi sıfırlanacak: profil, para, kıdem, şirket, banka, gazete, dernek, parti, ittifak, makam, seçim ve oyun içi işlemler.
- Eski oyuncular aynı giriş bilgileriyle yeniden oyuna dönebilir; sıfır oyun profili ve tam 100.000 TL cüzdanla başlamaları gerekir. Auth kullanıcılarını silmek zorunlu değildir. Oyun kayıtlarının temizliği ve onboarding yeni kullanıcı gibi çalışmalıdır.
- Dört temsili, boş yönetimli sistem partisi: Halk Partisi (HP), Sosyal Demokrasi Partisi (SDP), Yeni Parti (YENİ), Muhafazakar Türkiye Partisi (MTP). Bu dört isim mevcut dört aktif sistem partisinden seçilmiştir, eski başkanlar ve tüzükler taşınmaz.
- Partiye katılmak da bağımsız siyaset yapmak da serbest.
- Dört partinin ilk genel başkanı üyelerin katıldığı kurultaylarda seçilir, yönetici atanmaz.
- Oyuncular kendi partilerini kurabilir: başvuran en az 14 günlük hesap + Saygın Vatandaş (30 puan), diğer kurucular en az 7 günlük hesap + Vatandaş (10 puan), min 7 kurucu; aktif oyuncu sayısının %2'sine göre artar, azami 30.
- Kuruluş başvurusuna 10 gün süre, 500.000 TL x fiyat endeksi harç ve kurucu katkısıyla 1.000.000 TL x fiyat endeksi kuruluş fonu, min 10.000 TL katkı. Sonraki kurucu üyeliklerinde 30 gün, tekrar parti kuruluşunda 90 gün bekleme.
- Genel seçimde her partinin kendi ülke oy oranı %7 veya dahil olduğu ittifakın toplam ülke oy oranı %7 ve üzeriyse barajı geçer. Dağıtım her partiye ayrı kendi oylarına göre D'Hondt olur. Bağımsız adaylar özel yöntemiyle yarışır.
- Belediyeler yalnızca seçimle kazanılır; ilk girenleri otomatik belediye başkanı atama sistemi kapatılır.
- Lansmandan sonra 3. gün ilk dört kurultay, 5. gün CB ve MV ön seçimleri, 7. gün 08:00-22:00 ilk CB ve MV genel seçimleri.

## Teknik doğrulama gerektiren bulgular
- Canlı veritabanında mv_secim_modu.her_aday_vekil etkin; bu geçici test kuralı ülke barajını bypass ediyor. Lansman dosyasında kapatılıyor.
- Eski test kimliklerine 1.000.000 TL tanımlayan tetikleyici ve oyun_yonetim.onceki_test_oyuncu listesi lansman dosyasında temizleniyor.
- Yeni oyuncuyu boş belediyeye otomatik atayan tetikleyici lansman dosyasında kaldırılıyor.
- oyun.oyunu_sifirla yalnız oyun şemasının katalog olmayan tablolarını temizliyor. auth.users ve oyun_yonetim gibi şemalar ayrı değerlendirilmeli.
- Mevcut iki parti kurucu denetim yolu farklı min kurucu sayılarına sahip olabilir. Lansman SQL'i eski kontrol değeri ile yeni dinamik alt sınırı 7 olarak eşitliyor.
- Hoş geldin hibesi ve şehir hoş geldin destekleri varsa başlangıç para tutarı 100.000 TL'nin üzerine çıkabilir; lansman sonrası bunlar ayrıca sıfır olmalı.
- Seçim takvimi motorunun rutin aylık kurultayları, ilk 7 günlük özel seçim programıyla çakışmadığı doğrulanmalı.
- Kalıcı gerçek para alışverişleri ve mağaza hakları silinmemeli; oyun içi ilerleme temizlenirken mağazadan hak geri yükleme senaryosu test edilmeli.

## Yayın prosedürü (manuel, kontrollü)
1. App Store/Google Play gerçek çıkış tarihi kesinleşsin; bakım modu ve cron planlansın.
2. Tüm verilerin ve kalıcı satın alma haklarının yedeği güvenli şekilde alınsın.
3. Önce test ortamında reset + temel kurulum + lansman SQL'i denenip doğrulansın.
4. Resmî lansmanda oyun.oyunu_sifirla ('OYUNU SIFIRLA') komutuyla yedekli sıfırlama ve ardından supabase-kurulum.sql yeniden kurulum yapılsın.
5. gelistirici/sql/lansman_4_parti_100bin_7gun_2026.sql dosyasındaki v_lansman NULL yerinde gerçek lansman saati yazılsın; SQL Editor'da çalıştırılsın.
6. 100.000 TL, 4 parti, bağımsızlık, kurucu kontrolleri, kurultay, %7 ittifak barajı, belediye atanmaması, ilk genel seçim tarihleri ve eski kullanıcı onboarding'i uçtan uca kontrol edilsin.
7. Normal aylık takvim çakışmaları çözüldükten sonra zamanlayıcı açılsın ve uygulama lansmanı yapılsın.

## Dikkat
14 günlük hesap şartı nedeniyle ilk yedi günde yeni kurulan oyuncu partileri genel seçime yetişemeyecek. İlk seçime ancak dört hazır parti veya bağımsız adaylar katılabilir.

Değişiklikler yayın günü uygulanmak üzere **hazırlanmıştır**. SQL dosyasının GitHub'da durması kendi başına mevcut oyunu değiştirmez.

## Gercekci siyaset aktivasyonu (15 Kasim 2026 ek karari)
- Beta dunyasindaki secim/oyuncu verisini yasama reformu sirf kod eklenerek degistirmez; `oyun.ayarlar.gercekci_siyaset` lansmana kadar `false` kalir.
- Resmi lansman dosyasi kontrollu sifirlamadan sonra `gercekci_siyaset=true` yapar ve sonucu dogrular; TBMM tam sayisi 600, erken secim 360, anayasa degisikligi 200 teklif imzasi, 360/400 kabul esikleri ve Meclis Baskanligi 400/400/301 esiklerine gecer.
- Bagimsiz CB adayligi icin 50.000 TL teminat ve uygun aktif secmenlerin asgari 10 veya %3 imzasi uygulanir; yeterli imzaya ulasinca teminat iade edilir. Imza basvurusu kesin adaylik sayilmaz.
- Buyuk eylemler icin asgari 10 veya aktif 7 gunluk kitlenin %1 imzasi aranir; dogrudan eylem acma yolunda sunucu kontrolu bulunur. Kucuk ve bariscil siyasi ifadeler kapatilmaz.
- `gelistirici/build/sql_birlestir.js` icindeki `zz_20261115_...` yamalari sirayla kurulur; uygulama arayuzunun guncele alinmasi ve butun oy akislari uc-uca sinanmadan yayin acilmaz.
