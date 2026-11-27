-- 27.11.2026 — Yayınevi sayfası (Ercan: "yayınevlerinin sahibi, çıkarttığı kitaplar falan herkes görsün").
-- uc_kitap_panel › yayinevleri satırına herkese açık kimlik bilgileri eklenir: il, kuruluş tarihi, yönetici ve ortaklar (ad + pay).
-- %50 ortağı olmayan ortak şirketlerde "sahip" boş kalıyordu; artık yönetici (atanmışsa o, yoksa en büyük ortak) gösterilir.
-- Kasa/para bilgisi eklenmez; yalnız okuma. Ekran: www/kitap_vitrini.js (Yayınevleri sekmesi › yayınevi sayfası).
do $y$
begin
  perform oyun._yama('public.uc_kitap_panel()',
    $a$'bekleyen',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='teklif'),$a$,
    $b$/*YAYINEVI_SAYFASI*/ 'kurulus',kurulus,
    'il',(select i.ad from oyun.sirket_merkezleri m join oyun.iller i on i.id=m.il_id where m.sirket_id=sirketler.id),
    'yonetici',coalesce(oyun.kad(yonetici),(select oyun.kad(so.user_id) from oyun.sirket_ortaklari so where so.sirket_id=sirketler.id order by so.pay desc, so.user_id limit 1)),
    'ortaklar',coalesce((select jsonb_agg(jsonb_build_object('kad',x.kad,'pay',x.pay) order by x.pay desc, x.kad)
       from (select oyun.kad(so.user_id) kad, round(so.pay,1) pay from oyun.sirket_ortaklari so
              where so.sirket_id=sirketler.id and so.pay>0 order by so.pay desc, so.user_id limit 12) x where x.kad is not null),'[]'::jsonb),
    'ortak_sayisi',(select count(*) from oyun.sirket_ortaklari so where so.sirket_id=sirketler.id and so.pay>0),
    'bekleyen',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='teklif'),$b$,
    'YAYINEVI_SAYFASI', true);
end $y$;
