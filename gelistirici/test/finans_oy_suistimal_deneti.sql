-- Guvenli butce / transfer / oy denetimi: YALNIZCA SELECT; kimlik bilgisi disari cikmaz.
SELECT
 (SELECT count(*) FROM oyun.cuzdan WHERE para<0) AS negatif_cuzdan,
 (SELECT count(*) FROM oyun.banka_musteri WHERE vadesiz<0) AS negatif_devlet_mevduati,
 (SELECT count(*) FROM oyun.sirketler WHERE kasa<0) AS negatif_sirket_kasa,
 (SELECT count(*) FROM oyun.partiler WHERE kasa<0) AS negatif_parti_kasa,
 (SELECT count(*) FROM oyun.bakanlik_kasa WHERE kasa<0) AS negatif_bakanlik_kasa,
 (SELECT count(*) FROM oyun.banka_fast WHERE tutar<=0) AS gecersiz_fast_tutari,
 (SELECT count(*) FROM oyun.banka_transfer WHERE tutar<=0) AS gecersiz_havale_tutari;
-- Ayni secimde bir oyuncunun birden fazla oyu olmamali.
SELECT coalesce(sum(n-1),0) AS fazla_oy_sayisi
 FROM (SELECT count(*) n FROM oyun.oylar GROUP BY secim_id,secmen HAVING count(*)>1) t;
-- Cuzdan / banka / sirket transferleri: son 24 saatte tek oyuncudan cok sayida buyuk transfer.
-- Bu rapor sadece inceleme adedini verir; suclu oldugunu iddia etmez.
SELECT count(*) AS risk_isaretli_gonderen_sayisi FROM
 (SELECT gonderen, count(*) islem_sayisi, sum(tutar) toplam
  FROM oyun.banka_transfer WHERE zaman>now()-interval '24 hours'
  GROUP BY gonderen HAVING count(*)>=20 OR sum(tutar)>=10000000) x;
SELECT count(*) AS benzersiz_oy_kisiti FROM pg_indexes WHERE schemaname='oyun' AND tablename='oylar'
AND indexdef ~* 'unique index.+\\(secim_id, secmen\\)';
