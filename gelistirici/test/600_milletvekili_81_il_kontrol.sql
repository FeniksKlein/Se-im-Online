-- Sadece SELECT: mevcut oyun verisi degismez. 81 il, 600 MV, kurallar ve dagitim testi.
WITH senaryo(sandalye) AS (VALUES(81),(120),(400),(599),(600),(1000)),
agirlik AS (
 SELECT id,mv::numeric AS w,sum(mv::numeric) OVER() AS toplam FROM oyun.iller
), pay AS (
 SELECT s.sandalye,a.id,1+floor((s.sandalye-81)*a.w/nullif(a.toplam,0))::int AS taban,
   (s.sandalye-81)*a.w/nullif(a.toplam,0)-floor((s.sandalye-81)*a.w/nullif(a.toplam,0)) AS kesir
 FROM senaryo s CROSS JOIN agirlik a
), sirali AS (
 SELECT *,row_number() OVER(PARTITION BY sandalye ORDER BY kesir DESC,id) siralama,
 sum(taban) OVER(PARTITION BY sandalye) toplam_taban FROM pay
), sonuc AS (
 SELECT sandalye,id,taban+CASE WHEN siralama<=sandalye-toplam_taban THEN 1 ELSE 0 END AS mv FROM sirali
)
SELECT sandalye,count(*) AS il,sum(mv) AS dagitilan,
 CASE WHEN count(*)=81 AND sum(mv)=sandalye AND min(mv)>=1 THEN 'PASS' ELSE 'FAIL' END AS test
FROM sonuc GROUP BY sandalye ORDER BY sandalye;

SELECT oyun.tbmm_tamsayi() tamsayi,oyun.erken_secim_gerekli_oy() erken_secim_esik,
       (SELECT count(*) FROM oyun.iller) il_sayisi,
       (SELECT sum(mv_secim) FROM oyun.iller) mevcut_kontenjan,
       (SELECT count(*) FROM oyun.makamlar WHERE tur='mv' AND bit IS NULL) aktif_mv;
