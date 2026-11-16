-- Kabul testi (geri alınan alt işlem): davet aktiflik kademeleri ve 2. kademe katsayı
do $kabul$
declare res jsonb := '{}'; a uuid; b uuid; c uuid; d1 bigint; d2 bigint; t timestamptz := oyun.simdi();
begin
  begin
    select x.id into a from oyun.profiller x where not coalesce(x.yasakli,false) order by x.olusturma limit 1;
    select x.id into b from oyun.profiller x where not coalesce(x.yasakli,false) and x.id<>a and not oyun.bagli_hesap_mi(a,x.id)
       and not exists(select 1 from oyun.davet d where d.davet_edilen=x.id) order by x.olusturma limit 1;
    select x.id into c from oyun.profiller x where not coalesce(x.yasakli,false) and x.id not in (a,b) and not oyun.bagli_hesap_mi(a,x.id) and not oyun.bagli_hesap_mi(b,x.id)
       and not exists(select 1 from oyun.davet d where d.davet_edilen=x.id) order by x.olusturma limit 1;
    insert into oyun.davet(davet_eden,davet_edilen,kod,zaman,durum,odul_at) values(a,b,'TEST01',t-interval '40 days','odendi',t-interval '39 days') returning id into d1;
    insert into oyun.davet(davet_eden,davet_edilen,kod,zaman,durum,odul_at) values(b,c,'TEST02',t-interval '20 days','odendi',t-interval '19 days') returning id into d2;
    update oyun.oyuncu_aktif_gun set gun = gun - 5000 where user_id in (b,c);
    insert into oyun.oyuncu_aktif_gun(user_id,gun) select b, (t at time zone 'Europe/Istanbul')::date - g from generate_series(1,3) g;
    insert into oyun.oyuncu_aktif_gun(user_id,gun) select c, (t at time zone 'Europe/Istanbul')::date - g from generate_series(1,7) g;
    perform oyun.davet_aktiflik_tick();
    res := jsonb_build_object(
      'D1_a_dogrudan', (select coalesce(sum(tutar),0) from oyun.davet_aktiflik_odul where davet_id=d1 and seviye=1),
      'D2_b_dogrudan', (select coalesce(sum(tutar),0) from oyun.davet_aktiflik_odul where davet_id=d2 and seviye=1),
      'D3_a_ag',       (select coalesce(sum(tutar),0) from oyun.davet_aktiflik_odul where davet_id=d2 and seviye=2));
    perform oyun.davet_aktiflik_tick();
    res := res || jsonb_build_object('D4_tekrar_odenmez', (select count(*) from oyun.davet_aktiflik_odul where davet_id in (d1,d2)));
    raise exception using errcode='P0099', message=res::text;
  exception when sqlstate 'P0099' then res := sqlerrm::jsonb;
  end;
  insert into oyun.migration_test_sonuc(ad,sonuc) values('davet_aktiflik_20261116',res);
  if not ((res->>'D1_a_dogrudan')::numeric=5000 and (res->>'D2_b_dogrudan')::numeric=15000
          and (res->>'D3_a_ag')::numeric=3000 and (res->>'D4_tekrar_odenmez')::int=5) then
    raise exception 'KABUL TESTI BASARISIZ: %', res;
  end if;
end $kabul$;
