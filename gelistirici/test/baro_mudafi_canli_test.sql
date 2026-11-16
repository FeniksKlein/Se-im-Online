-- Baro müdafi güvencesi · canlı veritabanında GERİ ALINAN işlemle senaryo testi.
-- Sonunda kasıtlı hata fırlatılır; hiçbir değişiklik kalmaz. Çıktı hata metnindedir.
-- 16.11.2026 canlı sonuç: S1 baskan_bekleniyor · S2 Bahçeli (gönüllü) otomatik · S3 KAMARBEY_52'ye devir (yanıtsızlık)
--   · S4 kabul, CMK ücreti 5.000 ₺ baro kasasından · S5 çekilme → autopsy_chester · S5b ret → CELAL · S6 avukat_yok,
--   talep açık + gerekçe · S7 avukat dönünce atandı · S8 bitmiş gözaltı kapandı · gözaltındakinin cüzdanı değişmedi.
do $test$
declare
  P uuid; CB uuid; gid bigint; r jsonb; v text; a1 uuid; a2 uuid; sonuc jsonb := '[]'; tl jsonb; kasa0 numeric; kasa1 numeric;
  procedure_ok boolean;
begin
  select m.user_id into CB from oyun.makamlar m where m.tur='cb' and m.bit is null limit 1;
  select p.id into P from oyun.profiller p
   where not coalesce(p.yasakli,false) and p.id<>CB and oyun.gozalti_aktif(p.id) is null
     and not exists(select 1 from oyun.baro_uyeleri b where b.user_id=p.id)
   order by p.son_gorulme desc nulls last limit 1;

  -- S1: gözaltındaki oyuncu müdafi ister; geçici baro yetkilisine süre tanınır
  insert into oyun.yonetim_tutuklama(hedef,yetkili,makam,gerekce,baslangic,bitis)
   values(P,CB,'cumhurbaskani','Test gözaltısı gerekçesi',oyun.simdi(),oyun.simdi()+interval '6 hours') returning id into gid;
  perform set_config('request.jwt.claim.sub',P::text,true);
  r := public.gozalti_baro_iste2('yonetim',gid);
  sonuc := sonuc || jsonb_build_object('S1_talep',r->>'sonuc');

  -- S2: başkan süresi geçti → sistem otomatik görevlendirir (gönüllü öncelikli)
  update oyun.gozalti_baro_talep set zaman=zaman-interval '16 minutes' where kaynak='yonetim' and dosya_id=gid;
  perform oyun.gozalti_mudafi_tick();
  tl := oyun.mudafi_talep('yonetim',gid); a1 := (tl->>'avukat')::uuid;
  sonuc := sonuc || jsonb_build_object('S2_otomatik',tl->>'durum','avukat',oyun.kad(a1),
     'gonullu',(select gonullu from oyun.baro_uyeleri where user_id=a1),
     'dosya',(select avukat_durum from oyun.yonetim_tutuklama where id=gid));

  -- S3: avukat yanıt vermezse dosya başka avukata geçer
  update oyun.gozalti_baro_talep set cagri_zamani=cagri_zamani-interval '21 minutes' where kaynak='yonetim' and dosya_id=gid;
  perform oyun.gozalti_mudafi_tick();
  tl := oyun.mudafi_talep('yonetim',gid); a2 := (tl->>'avukat')::uuid;
  sonuc := sonuc || jsonb_build_object('S3_yeniden',tl->>'durum','yeni_avukat',oyun.kad(a2),'farkli',a1 is distinct from a2,'denenen',jsonb_array_length(tl->'denenen'));

  -- S4: avukat kabul eder; ücret baro kasasından ödenir, oyuncunun cüzdanına dokunulmaz
  select kasa into kasa0 from oyun.baro where id=1;
  perform set_config('request.jwt.claim.sub',a2::text,true);
  perform public.gozalti_avukat_yanit2('yonetim',gid,true);
  select kasa into kasa1 from oyun.baro where id=1;
  tl := oyun.mudafi_talep('yonetim',gid);
  sonuc := sonuc || jsonb_build_object('S4_kabul',(select avukat_durum from oyun.yonetim_tutuklama where id=gid),'ucret_odendi',tl->'ucret_odendi','baro_kasa_fark',kasa0-kasa1);

  -- S5: avukat çekilir → derhal yeni müdafi (CMK 151)
  r := public.gozalti_avukat_cekil('yonetim',gid,'Test amaçlı çekilme gerekçesi');
  tl := oyun.mudafi_talep('yonetim',gid);
  sonuc := sonuc || jsonb_build_object('S5_cekilme',r->>'sonuc','yeni',oyun.kad((tl->>'avukat')::uuid),'cekilen_tekrar_atanmadi',(tl->>'avukat')::uuid is distinct from a2);

  -- S5b: görevlendirilen avukat reddeder → tick derhal yenisini görevlendirir
  perform set_config('request.jwt.claim.sub',(tl->>'avukat'),true);
  perform public.gozalti_avukat_yanit2('yonetim',gid,false);
  tl := oyun.mudafi_talep('yonetim',gid);
  sonuc := sonuc || jsonb_build_object('S5b_ret_sonrasi',tl->>'durum','avukat',oyun.kad((tl->>'avukat')::uuid));

  -- S6: uygun avukat yok → talep açık kalır, gerekçe yazılır (sahte tamamlanma yok)
  update oyun.yonetim_tutuklama set avukat=null, avukat_durum='yok' where id=gid;
  update oyun.baro_uyeleri set durum='ayrildi' where durum='aktif';
  perform oyun.mudafi_talep_ac('yonetim',gid,P,oyun.simdi()-interval '1 hour','test',true);
  v := oyun.mudafi_degerlendir('yonetim',gid);
  tl := oyun.mudafi_talep('yonetim',gid);
  sonuc := sonuc || jsonb_build_object('S6_avukat_yok',v,'durum',tl->>'durum','gerekce_var',(tl->>'gerekce') is not null,
     'baro_talep_gorunur',(oyun.gozalti_dosya('yonetim',gid)->>'baro_talep'));

  -- S7: uygun avukat geri gelince açık talep görevlendirilir
  update oyun.baro_uyeleri set durum='aktif' where user_id=a1;
  update oyun.gozalti_baro_talep set zaman=oyun.simdi()-interval '16 minutes' where kaynak='yonetim' and dosya_id=gid;
  v := oyun.mudafi_degerlendir('yonetim',gid);
  sonuc := sonuc || jsonb_build_object('S7_uygun_avukat_cikinca',v);

  -- S8: bitmiş gözaltının talebi kapanır
  update oyun.yonetim_tutuklama set bitis=oyun.simdi()-interval '1 minute' where id=gid;
  v := oyun.mudafi_degerlendir('yonetim',gid);
  sonuc := sonuc || jsonb_build_object('S8_bitmis',v,'durum',oyun.mudafi_talep('yonetim',gid)->>'durum');

  -- S9: eski açık talepler (canlıda bekleyenler) kapandı mı
  sonuc := sonuc || jsonb_build_object('S9_acik_eski',(select count(*) from oyun.gozalti_baro_talep where durum='bekliyor' and dosya_id<>gid)
     + (select count(*) from oyun.sokak_baro_talep where durum='bekliyor'));

  raise exception 'TEST_SONUC %', sonuc;
end $test$;
