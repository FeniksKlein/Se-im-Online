-- CELAL ve Eyetkin parti kurulusu icin ayni 0 TL / 0 davet istisnasini kullanir.
-- Istisna oyuncu adina degil auth kullanici kimligine baglidir; diger oyunculara acilmaz.
do $celal$
declare v_user uuid;
begin
  select id into strict v_user from oyun.profiller where lower(kad)=lower('CELAL');
  insert into oyun_yonetim.ozel_parti_kurma_izni(user_id,aciklama)
  values (v_user,'CELAL - test istisnasi')
  on conflict (user_id) do update set aciklama=excluded.aciklama;
end
$celal$;
