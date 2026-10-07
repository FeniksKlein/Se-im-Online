# Güncelleme kuralları — oyun hiç sıfırlanmaz

Bu proje, yayındaki oyunun **hiçbir güncellemeyle sıfırlanmaması** üzerine kuruludur. Oyuncuların hesabı, makamı, parası, kıdemi, oyları, partileri, mülkleri ve geçmişi her güncellemede aynen kalır. Bu dosya, ileride yapılacak her değişiklikte (bende ya da başka bir geliştiricide) uyulacak kuralları anlatır.

## Sistem nasıl koruyor?
1. **Tek işlem.** `supabase-kurulum.sql` baştan sona tek bir işlem (transaction) olarak çalışır. Ortada bir hata olursa hiçbir şey uygulanmaz.
2. **Otomatik yedek.** Güncellemenin ilk adımı oyunun tam yedeğini almaktır (`yedek_YYYYMMDD_SSDDSS` şeması). Son 5 yedek tutulur.
3. **Bütünlük kontrolü.** Güncelleme başlarken ve biterken oyuncu verisinin "parmak izi" çıkarılır. Karşılaştırılanlar şunlardır:
   - hesaplar, makamlar ve makam sahipleri;
   - cüzdanlar, toplam para ve kıdem;
   - partiler, seçimler, oylar, kanunlar;
   - mülkler, ülke ve il durumu, kurallar;
   - banka hesapları, vadeli hesaplar, krediler, il teşkilatları ve moderatörler.
   Tek bir değer değiştiyse güncelleme **kendiliğinden iptal olur**.
4. **Silme koruması.** Oyun tabloları `TRUNCATE` ile boşaltılamaz, `DROP TABLE` ya da `DROP COLUMN` ile silinemez.
5. **Sürüm kaydı.** Her güncelleme `oyun.surumler` tablosuna yazılır: sürüm, tarih, yedeğin adı, parmak izleri.
6. **Uygulama sürümü.** Sunucu eski uygulamaları desteklemeyi bırakırsa (yönetici panelinde "en düşük uygulama sürümü"), eski telefon uygulaması "Güncelleme gerekli" ekranı gösterir. Oyuncunun verisi sunucuda olduğu için güncelleyince kaldığı yerden devam eder.

## Değişiklik yaparken
- **Yeni tablo:** `create table if not exists …`
- **Yeni sütun:** `alter table … add column if not exists … default …`. Eski satırlar varsayılan değeri alır.
- **Yeni makam türü:** makamlar tablosundaki izin listesine **ekle**; eski türleri çıkarma. Kişilere makam güncellemeyle verilmez, oyun içinden (seçim ya da atama) verilir. Güncelleme makam sahiplerini değiştirmeye kalkarsa durdurulur.
- **İzin verilen değer listeleri (check):** yalnızca genişler. Bir listeyi birden çok dosyada yeniden kurma; en güncel liste tek yerde dursun. 07'deki kanun ve kararname türü listelerinin 12'ye taşınma sebebi budur.
- **Katalog verisi** (vaat türleri, icraatlar, kurallar, iller): `insert … on conflict do update`. Asla `delete from` kullanma; verilmiş vaatler ve kayıtlar bu kodlara bağlıdır.
- **Fonksiyonlar:** `create or replace` kullanılır. Uygulamanın çağırdığı bir fonksiyonun parametreleri değişecekse eskisini silme; yeni adla ekle ya da varsayılan değerli parametre ekle. Mağazadaki eski uygulama çalışmaya devam etmeli.
- **Oyuncu verisini dönüştürmek gerçekten gerekiyorsa** (çok nadir): bunu bütünlük kontrolünün dışında, ayrı ve bilinçli bir işlemle yap. Önce `select oyun.yedek_al('açıklama');` ile yedek al.
- **Tablo ya da sütun kaldırmak gerçekten gerekiyorsa:** `select set_config('oyun.tablo_kaldir', 'evet', true);` ile, yalnızca o işlemde.

## Her güncellemede
1. `SURUM` dosyasındaki sürümü artır (biçim `YYYY.AA.GG-N`).
2. `bash build/sql_birlestir.sh` ve `node build/derle.js` çalıştır.
3. `python3 test/kalicilik.py` ve diğer testleri çalıştır.
4. Supabase → SQL Editor → `supabase-kurulum.sql` dosyasının tamamını yapıştır → Run. Sonuçta `"kontrol": "oyuncu verisi değişmedi"` görülür.

## Sahibin araçları (yalnızca Supabase SQL Editor'den; uygulamadan çağrılamaz)
- **Yedekleri listele:** `select * from oyun.yedekler();`
- **Elle yedek al:** `select oyun.yedek_al('açıklama');`
- **Bir yedeğe dön:** `select oyun.yedekten_don('yedek_…', 'GERİ YÜKLE');`. Dönmeden önce o anın da yedeği alınır.
- **Oyunu sıfırla:** `select oyun.oyunu_sifirla('OYUNU SIFIRLA');`
  - Önce yedek alınır.
  - Oyun dünyası boşalır; giriş hesapları ve kataloglar kalır.
  - Ardından `supabase-kurulum.sql` bir kez daha çalıştırılır.
