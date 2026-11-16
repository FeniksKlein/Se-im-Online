-- Seçim/makam güvenliği regresyon testi · canlıda GERİ ALINAN işlem (sonda kasıtlı hata).
do $test$
declare sonuc jsonb:='[]'; cb oyun.makamlar; mv0 int; bk0 int; sid bigint; iptal_id bigint; u2 uuid; mvu uuid; ym uuid; x int; il smallint; r text;
begin
  select * into cb from oyun.makamlar where tur='cb' and bit is null;
  select count(*) into mv0 from oyun.makamlar where tur='mv' and bit is null;
  select count(*) into bk0 from oyun.makamlar where tur='bakan' and bit is null;

  -- T1: erken seçim kararı mevcut görevleri bitirmez
  begin
    r := oyun.erken_genel_secim_olustur(oyun.simdi(), -999);
  exception when others then r := 'karar_reddedildi: '||left(sqlerrm,60); end;
  sonuc := sonuc || jsonb_build_object('T1_erken_karar',r,'mv_ayni',(select count(*) from oyun.makamlar where tur='mv' and bit is null)=mv0,
     'bakan_ayni',(select count(*) from oyun.makamlar where tur='bakan' and bit is null)=bk0,'cb_ayni',(select bit is null from oyun.makamlar where id=cb.id),
     'aralik_secimi_bekliyor',(select count(*) from oyun.secimler where tur='mv' and not ara and durum='bekliyor' and oy_bas::date='2026-12-01'));

  -- T2: iptal edilmiş seçim yeniden canlandırılamaz ve görev değiştiremez
  select id into iptal_id from oyun.secimler where sonuc ? 'iptal' and tur='mv' order by id desc limit 1;
  update oyun.secimler set durum='sonuclandi' where id=iptal_id;
  sonuc := sonuc || jsonb_build_object('T2_iptal_durum',(select durum from oyun.secimler where id=iptal_id),'iptal_korundu',(select sonuc ? 'iptal' from oyun.secimler where id=iptal_id));
  perform oyun.goreve_baslat(iptal_id);
  sonuc := sonuc || jsonb_build_object('T2_mv_ayni',(select count(*) from oyun.makamlar where tur='mv' and bit is null)=mv0);

  -- T3: aynı CB yeniden seçilir → kabine korunur
  perform set_config('oyun.takvim_kurali','1',true);
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum,ara,ara_neden,sonuc)
   values('cb','test-T3',oyun.simdi()-interval '3 days',oyun.simdi()-interval '2 days',oyun.simdi()-interval '2 days',oyun.simdi()-interval '1 day',oyun.simdi()-interval '1 day',oyun.simdi()-interval '1 minute','sonuclandi',true,'test','{}') returning id into sid;
  insert into oyun.kazananlar(secim_id,user_id,parti_id) values(sid,cb.user_id,cb.parti_id);
  perform oyun.goreve_baslat(sid);
  sonuc := sonuc || jsonb_build_object('T3_ayni_cb',(select oyun.kad(user_id) from oyun.makamlar where tur='cb' and bit is null)=oyun.kad(cb.user_id),
     'bakan_korundu',(select count(*) from oyun.makamlar where tur='bakan' and bit is null)=bk0,'secim',(select durum from oyun.secimler where id=sid));
  -- T3b: aynı seçim ikinci kez çalıştırılınca mükerrer görev oluşmaz
  update oyun.secimler set durum='sonuclandi' where id=sid;
  perform oyun.goreve_baslat(sid);
  sonuc := sonuc || jsonb_build_object('T3b_tek_cb',(select count(*) from oyun.makamlar where tur='cb' and bit is null));

  -- T4: farklı CB seçilir → eski bakanların görevi devirle biter, yeni CB göreve başlar
  select p.id into u2 from oyun.profiller p where not coalesce(p.yasakli,false) and p.id<>cb.user_id
    and not exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null)
    and not exists(select 1 from oyun.mahkeme_uye y where y.user_id=p.id) limit 1;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum,ara,ara_neden,sonuc)
   values('cb','test-T4',oyun.simdi()-interval '3 days',oyun.simdi()-interval '2 days',oyun.simdi()-interval '2 days',oyun.simdi()-interval '1 day',oyun.simdi()-interval '1 day',oyun.simdi()-interval '1 minute','sonuclandi',true,'test','{}') returning id into sid;
  insert into oyun.kazananlar(secim_id,user_id) values(sid,u2);
  perform oyun.goreve_baslat(sid);
  sonuc := sonuc || jsonb_build_object('T4_yeni_cb',(select user_id from oyun.makamlar where tur='cb' and bit is null)=u2,
     'eski_bakan_kalan',(select count(*) from oyun.makamlar where tur='bakan' and bit is null),
     'neden',(select max(bitis_neden) from oyun.makamlar where tur='bakan' and bit>=oyun.simdi()-interval '1 minute'));

  -- T5: tek ile hedefli MV ara seçimi diğer illerin vekillerini bitirmez; YM üyesi aday seçimi kilitlemez
  select il_id into il from oyun.makamlar where tur='mv' and bit is null group by il_id order by count(*) desc limit 1;
  select user_id into ym from oyun.mahkeme_uye where sira in (1,2) limit 1;
  select p.id into mvu from oyun.profiller p where not coalesce(p.yasakli,false)
    and not exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null)
    and not exists(select 1 from oyun.mahkeme_uye y where y.user_id=p.id) and p.id<>u2 limit 1;
  select count(*) into mv0 from oyun.makamlar where tur='mv' and bit is null;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum,ara,ara_neden,hedef_il_id,sonuc)
   values('mv','test-T5',oyun.simdi()-interval '3 days',oyun.simdi()-interval '2 days',oyun.simdi()-interval '2 days',oyun.simdi()-interval '1 day',oyun.simdi()-interval '1 day',oyun.simdi()-interval '1 minute','sonuclandi',true,'test',il,'{}') returning id into sid;
  if ym is not null then insert into oyun.kazananlar(secim_id,user_id,il_id) values(sid,ym,il); end if;
  insert into oyun.kazananlar(secim_id,user_id,il_id) values(sid,mvu,il);
  perform oyun.goreve_baslat(sid);
  sonuc := sonuc || jsonb_build_object('T5_diger_mv_korundu',(select count(*) from oyun.makamlar where tur='mv' and bit is null and secim_id is distinct from sid)=mv0,
     'normal_aday_basladi',exists(select 1 from oyun.makamlar where secim_id=sid and user_id=mvu and bit is null),
     'ym_aday_baslamadi',not exists(select 1 from oyun.makamlar where secim_id=sid and user_id=ym and bit is null),'ym_var',ym is not null,
     'secim_tamam',(select durum from oyun.secimler where id=sid));

  -- T6: milletvekili bakan atanırsa yalnız milletvekilliği biter; bakanlık ve diğer vekiller etkilenmez
  select count(*) into mv0 from oyun.makamlar where tur='mv' and bit is null;
  insert into oyun.makamlar(tur,user_id,bakanlik,bas,kaynak)
   values('bakan',mvu,(select kod from oyun.bakanliklar b where not exists(select 1 from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.bakanlik=b.kod) limit 1),oyun.simdi(),'atama');
  sonuc := sonuc || jsonb_build_object('T6_mv_bitti',not exists(select 1 from oyun.makamlar where user_id=mvu and tur='mv' and bit is null),
     'bakan_aktif',exists(select 1 from oyun.makamlar where user_id=mvu and tur='bakan' and bit is null),
     'diger_mv_azalmadi',(select count(*) from oyun.makamlar where tur='mv' and bit is null)>=mv0-1);

  -- T7: sınıflandırma
  sonuc := sonuc || jsonb_build_object('T7',jsonb_build_array(oyun_yonetim.gorev_bitis_sinif('cb','kabine_48_saat_suresi_doldu'),
     oyun_yonetim.gorev_bitis_sinif('bakan','cb_adayligi'),oyun_yonetim.gorev_bitis_sinif('bel','cb_adayligi'),oyun_yonetim.gorev_bitis_sinif('mv','donem_bitti')));
  raise exception 'TEST_SONUC %', sonuc;
end $test$;
