begin;
-- CELAL ve Eyetkin parti kurulusu icin ayni 0 TL / 0 davet istisnasini kullanir.
-- Istisna oyuncu adina degil auth kullanici kimligine baglidir; diger oyunculara acilmaz.
-- Temiz kurulumda henuz CELAL profili yoksa atlanir; canli migrasyonda zaten eklenmistir.
insert into oyun_yonetim.ozel_parti_kurma_izni(user_id,aciklama)
select id,'CELAL - test istisnasi' from oyun.profiller
where lower(kad)=lower('CELAL')
on conflict (user_id) do update set aciklama=excluded.aciklama;
commit;
