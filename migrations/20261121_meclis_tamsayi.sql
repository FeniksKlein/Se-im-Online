-- Canlıya 21.11.2026'da Supabase migration'ı olarak uygulandı: meclis_uye_tamsayisi_secilen_vekile_gore
-- Kaynak: gelistirici/sql/zz_20261121_meclis_tamsayi.sql · tekrar çalıştırmak güvenlidir.
begin;
set local lock_timeout = '5s';

-- 21.11.2026 · TBMM üye tamsayısı = o yasama dönemi için seçilen vekil sayısı (canlı migration: meclis_uye_tamsayisi_secilen_vekile_gore)
-- Gerçekte 600 sandalyenin tamamı dolu olduğu için eşikler 600 üzerinden hesaplanır. Oyunda sandalyeleri yalnız gerçek
-- oyuncular doldurur; sabit 600, 200'den az vekilli Meclis'te kanun, bütçe, veto ve erken seçim kararını imkânsız kılıyordu.
-- Oranlar (1/3 toplantı, 1/4+1 kabul, salt çoğunluk, 3/5, 2/3, 20/600 grup) aynen korunur; 600 vekil seçilirse sonuç yine 600'dür.
-- ⚠️ Ercan'ın kararı bekleniyor (DEVAM.md 21.11): 16.11 "yayın ölçeği" temeli sabit 600'ü bilinçli seçmişti.
-- Geri almak için bu dosyayı sql_birlestir.js listesinden çıkarıp canlıda üç işlevi kaynak tanımına döndürmek yeterlidir.
select oyun._yama('oyun.tbmm_tamsayi()',
  $re$coalesce\(\s*\(\s*select\s+round\(deger\)::int\s+from\s+oyun\.anayasa\s+where\s+kod\s*=\s*'milletvekili_sayisi'\s*\)\s*,\s*600\s*\)$re$,
  $new$least(
      coalesce((select round(deger)::int from oyun.anayasa where kod='milletvekili_sayisi'),600),
      greatest(
        coalesce((select count(*)::int from oyun.kazananlar k where k.secim_id = (
            select s.id from oyun.secimler s
             where s.tur='mv' and s.hedef_il_id is null and s.durum='tamam'
               and s.goreve_bas is not null and s.goreve_bas <= oyun.simdi()
               and coalesce(s.sonuc->>'iptal','')=''
             order by s.goreve_bas desc limit 1)),0),
        oyun.dolu_sandalye()))$new$,
  'from oyun.kazananlar k where k.secim_id');
-- Meclis grubu eşiği: 600 üyede 20; daha küçük Meclis'te aynı oran (en az 2)
select oyun._yama('oyun.grup_esigi(integer)',
  $re$when\s+oyun\.gercekci_siyaset\(\)\s+then\s+20\s+else$re$,
  $new$when oyun.gercekci_siyaset() then greatest(2,ceil(oyun.tbmm_tamsayi()*20/600.0))::int else$new$,
  'ceil(oyun.tbmm_tamsayi()*20/600.0)');
-- Erken seçim: Meclis yokken sıfır oyla karar çıkmasın
select oyun._yama('oyun.erken_secim_gerekli_oy()',
  $re$then\s+ceil\(oyun\.tbmm_tamsayi\(\)\*3/5\.0\)::int\s+else$re$,
  $new$then greatest(1,ceil(oyun.tbmm_tamsayi()*3/5.0)::int) else$new$,
  'greatest(1,ceil(oyun.tbmm_tamsayi()*3/5.0)');
-- Bildirim metnindeki sabit "400" gerçek eşiği göstersin
select oyun._yama('public.kanun_cb_karar(bigint,text,text)',
  $re$üçte iki \(400\) kabul oyu gerekir\.'\s*,\s*k\.baslik\s*\)$re$,
  $new$üçte iki (%s) kabul oyu gerekir.',k.baslik,ceil(oyun.tbmm_tamsayi()*2/3.0)::int)$new$,
  'üçte iki (%s) kabul oyu');

commit;
