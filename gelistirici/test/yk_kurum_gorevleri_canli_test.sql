-- Yönetici kurum görevleri · canlıda GERİ ALINAN işlem (sonda kasıtlı hata).
do $test$
declare yk uuid; a uuid; b uuid; c uuid; res jsonb := '[]'; r jsonb; il smallint; e text;
begin
  select id into yk from oyun.profiller where yonetici and not coalesce(yasakli,false) order by olusturma limit 1;
  perform set_config('request.jwt.claim.sub', yk::text, true);
  select p.id into a from oyun.profiller p where not coalesce(p.yasakli,false) and p.id<>yk and p.parti_id is null
     and not exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null) and not exists(select 1 from oyun.mahkeme_uye y where y.user_id=p.id) limit 1;
  select p.id into b from oyun.profiller p where not coalesce(p.yasakli,false) and p.id not in (yk,a) and p.parti_id is not null
     and exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null and m.tur='mv') limit 1;
  -- Y1: partisiz, görevsiz oyuncu Yüksek Mahkeme Başkanı
  r := public.yk_kurum_gorev_ver(oyun.kad(a),'ym_baskan',null,true);
  res := res || jsonb_build_object('Y1_ym_baskan',(select user_id from oyun.mahkeme_uye where sira=1)=a,'hakim',(select hakim from oyun.adliye_makam where id=1)=a);
  -- Y2: partili milletvekili, tek görev kapalı → reddedilir
  begin perform public.yk_kurum_gorev_ver(oyun.kad(b),'ym_uye',null,false); e:='atandi'; exception when others then e:=left(sqlerrm,70); end;
  res := res || jsonb_build_object('Y2_engel',e);
  -- Y3: aynı kişi, tek görev açık → milletvekilliği ve parti üyeliği biter, üye olur
  r := public.yk_kurum_gorev_ver(oyun.kad(b),'ym_uye',null,true);
  res := res || jsonb_build_object('Y3_ym_uye',(select user_id from oyun.mahkeme_uye where sira=2)=b,'mv_bitti',not exists(select 1 from oyun.makamlar where user_id=b and bit is null),
     'partisiz',(select parti_id from oyun.profiller where id=b) is null);
  -- Y4: baro başkanı
  select user_id into c from oyun.baro_uyeleri where durum='aktif' and oyun.avukat_ruhsatli(user_id) and oyun.avukat_gorev_engeli(user_id) is null limit 1;
  r := public.yk_kurum_gorev_ver(oyun.kad(c),'baro_baskan',null,true);
  res := res || jsonb_build_object('Y4_baro',(select baskan from oyun.baro where id=1)=c,'baro_baskan_fn',oyun.baro_baskan()=c);
  -- Y5: vali (havuzda değilse yönetici kararıyla havuza alınır)
  select p.id into a from oyun.profiller p where not coalesce(p.yasakli,false) and p.id not in (yk,b,c,a)
     and not exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null) and not exists(select 1 from oyun.mahkeme_uye y where y.user_id=p.id) limit 1;
  r := public.yk_kurum_gorev_ver(oyun.kad(a),'vali',6,true);
  res := res || jsonb_build_object('Y5_vali',exists(select 1 from oyun.icisleri_atama where hedef=a and tur='vali' and durum='aktif' and il_id=6));
  -- Y6: liste ve görevden alma
  res := res || jsonb_build_object('Y6_liste',jsonb_array_length(public.yk_kurum_gorevleri(null)));
  r := public.yk_kurum_gorev_al(oyun.kad(a),'vali',6);
  r := public.yk_kurum_gorev_al(oyun.kad(b),'ym_uye',null);
  res := res || jsonb_build_object('Y6_vali_alindi',not exists(select 1 from oyun.icisleri_atama where hedef=a and tur='vali' and durum='aktif'),
     'ym_uye_bos',(select user_id from oyun.mahkeme_uye where sira=2) is null);
  raise exception 'TEST_SONUC %', res;
end $test$;
