-- Cihaz yasağı · canlı veritabanında GERİ ALINAN işlemle uçtan uca senaryo testi (sql/zz_20261123_cihaz_yasak.sql).
-- Sonunda kasıtlı hata fırlatılır; hiçbir değişiklik kalmaz. Çıktı hata metnindedir (TEST_SONUC {...}).
-- Deneme hesapları (zzt…) işlem içinde açılır ve işlemle birlikte yok olur; gerçek oyunculara yalnız okuma yapılır.
do $test$
declare
  s jsonb := '{}'::jsonb; r jsonb; msg text; v_id bigint; v_u uuid; t0 timestamptz;
  kurucu uuid; mod_oyuncu uuid; mod_diger uuid;
  ua uuid := gen_random_uuid(); ub uuid := gen_random_uuid(); uc uuid := gen_random_uuid(); ud uuid := gen_random_uuid();
  ue uuid := gen_random_uuid(); uf uuid := gen_random_uuid(); ug uuid := gen_random_uuid(); uh uuid := gen_random_uuid();
  ui uuid := gen_random_uuid(); uj uuid := gen_random_uuid();
  ek text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);
  ka text; kc text; kd text; ke text; kf text; kh text; kj text;
begin
  perform set_config('lock_timeout', '4s', true);
  -- @GOVDE
  ka := 'zzta' || ek; kc := 'zztc' || ek; kd := 'zztd' || ek; ke := 'zzte' || ek; kf := 'zztf' || ek; kh := 'zzth' || ek; kj := 'zztj' || ek;
  execute $h$create function pg_temp.cy_ol(u uuid, ip text) returns void language sql as $x$
    select set_config('request.jwt.claims', json_build_object('sub', u::text, 'role', 'authenticated')::text, true),
           set_config('request.jwt.claim.sub', u::text, true),
           set_config('request.headers', json_build_object('x-forwarded-for', ip)::text, true) $x$ $h$;
  select p.id into kurucu from oyun.profiller p join oyun.yonetici_kimlik k on k.user_id = p.id where p.yonetici limit 1;
  select m2.user_id into mod_oyuncu from oyun.moderatorler m2 join oyun.profiller p on p.id = m2.user_id
   where 'coklu_hesap' = any(m2.yetkiler) and 'kayit' = any(m2.yetkiler) and not p.yasakli order by m2.kod_no limit 1;
  select m2.user_id into mod_diger from oyun.moderatorler m2 join oyun.profiller p on p.id = m2.user_id
   where not ('coklu_hesap' = any(m2.yetkiler)) and 'kayit' = any(m2.yetkiler) and 'hesap_kapat' = any(m2.yetkiler) and not p.yasakli order by m2.kod_no limit 1;
  insert into auth.users(id, instance_id, aud, role, email)
  select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zzt_' || x::text || '@gmail.com'
    from unnest(array[ua, ub, uc, ud, ue, uf, ug, uh, ui, uj]) x;

  -- T0: yamalar yerinde mi, ilk liste, masum oyuncu etkileniyor mu
  s := s || jsonb_build_object('T0_yamalar', (select jsonb_object_agg(split_part(x, '(', 1), position('/* cihaz_yasak */' in pg_get_functiondef(x::regprocedure)) > 0)
      from unnest(array['public.durum()', 'public.kayit_basvuru_gonder(text,integer,text)', 'public.profil_olustur(text,integer)',
                        'public.admin_kayit_karar2(uuid,boolean,text)', 'public.admin_kayit_basvurulari()']) x));
  s := s || jsonb_build_object('T0_md5', (select jsonb_object_agg(pr.proname, md5(pr.prosrc)) from pg_proc pr join pg_namespace ns on ns.oid = pr.pronamespace
       where (ns.nspname = 'oyun' and pr.proname like 'cihaz\_%') or (ns.nspname = 'public' and pr.proname in ('oturum_kaydet', 'mod_kayit_karar', 'mod_cihaz_yasaklari', 'mod_cihaz_yasak_ayarla'))));
  s := s || jsonb_build_object('T0_liste', (select coalesce(jsonb_agg(jsonb_build_object('kaynak', y.kaynak_kad, 'aktif', y.aktif)), '[]'::jsonb) from oyun_yonetim.cihaz_yasak y));
  s := s || jsonb_build_object('T0_masum_son_cihaz', (select coalesce(jsonb_agg(p.kad), '[]'::jsonb) from oyun.profiller p
       where not p.yasakli and oyun.cihaz_yasak_bul(p.id, true) is not null and not oyun.cihaz_yasak_muaf(p.id)));
  s := s || jsonb_build_object('T0_masum_herhangi', (select coalesce(jsonb_agg(distinct p.kad), '[]'::jsonb) from oyun.profiller p
       join oyun.oturumlar o on o.user_id = p.id join oyun_yonetim.cihaz_yasak y on y.cihaz = o.cihaz and y.aktif where not p.yasakli));

  -- T1: gerçek, engelsiz bir oyuncu oyuna giriyor
  select p.id into v_u from oyun.profiller p
   where not p.yasakli and not p.yonetici and exists (select 1 from oyun.oturumlar o where o.user_id = p.id)
   order by p.son_gorulme desc nulls last limit 1;
  perform pg_temp.cy_ol(v_u, '10.0.0.1');
  r := public.durum();
  s := s || jsonb_build_object('T1_gercek_oyuncu_durum', jsonb_typeof(r -> 'profil') = 'object');

  -- T2: kalıcı engelli oyuncu kendi engel mesajını görür (cihaz mesajını değil)
  select p.id into v_u from oyun.profiller p
   where p.yasakli and p.engel_bitis is null and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad) limit 1;
  if v_u is not null then
    perform pg_temp.cy_ol(v_u, '10.0.0.2');
    begin r := public.durum(); msg := 'HATA: girdi'; exception when others then msg := left(sqlerrm, 45); end;
    s := s || jsonb_build_object('T2_engelli_kendi_mesaji', msg);
  end if;

  -- T3: A kayıt olur; onay beklerken cihazı kaydedilir; moderatör onaylar
  perform pg_temp.cy_ol(ua, '10.1.1.1');
  r := public.oturum_kaydet('TEST-DEV-A-' || ek, 'TEST-IZ-1-' || ek);
  s := s || jsonb_build_object('T3_onaysiz_oturum', r, 'T3_satir', (select count(*) from oyun.oturumlar o where o.user_id = ua));
  r := public.durum();
  s := s || jsonb_build_object('T3_durum_profilsiz', r ->> 'kayit_durumu');
  r := public.kayit_basvuru_gonder(ka, 34, 'Deneme Birinci');
  perform pg_temp.cy_ol(mod_oyuncu, '10.2.2.2');
  r := public.admin_kayit_karar2(ua, true, null);
  s := s || jsonb_build_object('T3_onay', r ->> 'durum');

  -- T4: kurucu A'yı kalıcı engeller → cihazı yasak listesine girer (işlem sonu taklidi: set constraints)
  perform pg_temp.cy_ol(kurucu, '10.3.3.3');
  r := public.yk_engelle(ka, null, 'Test: ağır hakaret ve tehdit', false);
  set constraints all immediate;
  set constraints all deferred;
  select y.id into v_id from oyun_yonetim.cihaz_yasak y where y.kaynak_user = ua and y.aktif;
  s := s || jsonb_build_object('T4_kalici_engel_cihaz_yasak', v_id is not null);

  -- T5: B aynı telefondan yeni hesap açar → giremez, başvuramaz; deneme kayda geçer, kurucuya bildirim gider
  perform pg_temp.cy_ol(ub, '10.4.4.4');
  r := public.oturum_kaydet('TEST-DEV-A-' || ek, 'TEST-IZ-9-' || ek);
  s := s || jsonb_build_object('T5_oturum', r);
  begin r := public.durum(); msg := 'HATA: girdi'; exception when others then msg := left(sqlerrm, 40); end;
  s := s || jsonb_build_object('T5_durum', msg);
  begin r := public.kayit_basvuru_gonder('zztb' || ek, 34, 'Deneme İkinci'); msg := 'HATA: kabul edildi'; exception when others then msg := left(sqlerrm, 40); end;
  s := s || jsonb_build_object('T5_basvuru', msg,
    'T5_deneme_kaydi', (select x.sayi from oyun_yonetim.cihaz_yasak_deneme x where x.user_id = ub),
    'T5_kurucu_bildirim', exists (select 1 from oyun.bildirimler bl where bl.user_id = kurucu and bl.metin like 'Cihaz yasağı: yasaklı bir cihazdan giriş denemesi%'));

  -- T6: D başka telefondan ama A ile aynı bağlantı + aynı cihaz izi → güçlü uyarı; eski onay yolu reddeder, görerek onay geçer
  perform pg_temp.cy_ol(ud, '10.1.1.1');
  r := public.oturum_kaydet('TEST-DEV-D-' || ek, 'TEST-IZ-1-' || ek);
  s := s || jsonb_build_object('T6_oturum', r);
  r := public.durum();
  r := public.kayit_basvuru_gonder(kd, 34, 'Deneme Dördüncü');
  s := s || jsonb_build_object('T6_uyari', oyun.cihaz_basvuru_uyari(ud));
  perform pg_temp.cy_ol(mod_diger, '10.2.2.3');
  begin r := public.admin_kayit_karar2(ud, true, null); msg := 'HATA: onaylandı'; exception when others then msg := left(sqlerrm, 70); end;
  s := s || jsonb_build_object('T6_eski_onay_reddi', msg);
  select x into r from jsonb_array_elements(public.admin_kayit_basvurulari()) x where x ->> 'user_id' = ud::text;
  s := s || jsonb_build_object('T6_listede_guclu', r -> 'cihaz_uyari' -> 'guclu');
  r := public.mod_kayit_karar(ud, true, null, true);
  s := s || jsonb_build_object('T6_gorerek_onay', r ->> 'durum');

  -- T7: C ilgisiz, masum yeni oyuncu → uyarısız, eski onay yolu çalışır, oyuna girer
  perform pg_temp.cy_ol(uc, '10.5.5.5');
  r := public.oturum_kaydet('TEST-DEV-C-' || ek, 'TEST-IZ-5-' || ek);
  r := public.kayit_basvuru_gonder(kc, 34, 'Deneme Üçüncü');
  s := s || jsonb_build_object('T7_masum_uyari', oyun.cihaz_basvuru_uyari(uc));
  perform pg_temp.cy_ol(mod_diger, '10.2.2.3');
  r := public.admin_kayit_karar2(uc, true, null);
  perform pg_temp.cy_ol(uc, '10.5.5.5');
  r := public.durum();
  s := s || jsonb_build_object('T7_masum_oyunda', jsonb_typeof(r -> 'profil') = 'object');

  -- T8: E'nin hesabı var; yasaklı telefondan giremez, kendi telefonundan girer; "ayrı kişi" onayı alınca muaf
  perform pg_temp.cy_ol(ue, '10.6.6.6');
  r := public.oturum_kaydet('TEST-DEV-E-' || ek, 'TEST-IZ-6-' || ek);
  r := public.kayit_basvuru_gonder(ke, 34, 'Deneme Beşinci');
  perform pg_temp.cy_ol(mod_diger, '10.2.2.3');
  r := public.admin_kayit_karar2(ue, true, null);
  perform pg_temp.cy_ol(ue, '10.6.6.6');
  r := public.oturum_kaydet('TEST-DEV-A-' || ek, 'TEST-IZ-6-' || ek);
  update oyun.oturumlar o set son = clock_timestamp() where o.user_id = ue and o.cihaz = oyun.ozet('TEST-DEV-A-' || ek);
  begin r := public.durum(); msg := 'HATA: girdi'; exception when others then msg := left(sqlerrm, 40); end;
  s := s || jsonb_build_object('T8_hesapli_yasakli_cihazdan', msg);
  update oyun.oturumlar o set son = clock_timestamp() where o.user_id = ue and o.cihaz = oyun.ozet('TEST-DEV-E-' || ek);
  r := public.durum();
  s := s || jsonb_build_object('T8_kendi_cihazindan', jsonb_typeof(r -> 'profil') = 'object');
  update oyun.oturumlar o set son = clock_timestamp() where o.user_id = ue and o.cihaz = oyun.ozet('TEST-DEV-A-' || ek);
  insert into oyun.hesap_onay(user_id, yonetici, not_, zaman) values (ue, kurucu, 'test', oyun.simdi());
  r := public.durum();
  s := s || jsonb_build_object('T8_muaf_hesap', jsonb_typeof(r -> 'profil') = 'object');

  -- T9: F süreli uzaklaştırılır → cihaz yasağı yok; ama aynı telefondan G yeni başvuru yapamaz
  perform pg_temp.cy_ol(uf, '10.7.7.7');
  r := public.oturum_kaydet('TEST-DEV-F-' || ek, 'TEST-IZ-7-' || ek);
  r := public.kayit_basvuru_gonder(kf, 34, 'Deneme Altıncı');
  perform pg_temp.cy_ol(mod_diger, '10.2.2.3');
  r := public.admin_kayit_karar2(uf, true, null);
  perform pg_temp.cy_ol(kurucu, '10.3.3.3');
  r := public.yk_engelle(kf, 1, 'Test: süreli uzaklaştırma', false);
  set constraints all immediate;
  set constraints all deferred;
  s := s || jsonb_build_object('T9_sureli_engelde_cihaz_yasagi_yok', not exists (select 1 from oyun_yonetim.cihaz_yasak y where y.kaynak_user = uf));
  perform pg_temp.cy_ol(ug, '10.8.8.8');
  r := public.oturum_kaydet('TEST-DEV-F-' || ek, 'TEST-IZ-8-' || ek);
  r := public.durum();
  s := s || jsonb_build_object('T9_durum', r ->> 'kayit_durumu');
  begin r := public.kayit_basvuru_gonder('zztg' || ek, 34, 'Deneme Yedinci'); msg := 'HATA: kabul edildi'; exception when others then msg := left(sqlerrm, 70); end;
  s := s || jsonb_build_object('T9_uzaklastirma_sirasinda_basvuru', msg);

  -- T10: cihaz başına hesap sınırı başvuruda uygulanır (C'nin telefonunda 2. hesap olur, 3. olmaz)
  perform pg_temp.cy_ol(uh, '10.5.5.6');
  r := public.oturum_kaydet('TEST-DEV-C-' || ek, 'TEST-IZ-5-' || ek);
  r := public.kayit_basvuru_gonder(kh, 34, 'Deneme Sekizinci');
  s := s || jsonb_build_object('T10_ikinci_hesap_uyari', oyun.cihaz_basvuru_uyari(uh));
  perform pg_temp.cy_ol(mod_diger, '10.2.2.3');
  r := public.admin_kayit_karar2(uh, true, null);
  s := s || jsonb_build_object('T10_ikinci_hesap_onay', r ->> 'durum');
  perform pg_temp.cy_ol(ui, '10.5.5.7');
  r := public.oturum_kaydet('TEST-DEV-C-' || ek, 'TEST-IZ-5-' || ek);
  begin r := public.kayit_basvuru_gonder('zzti' || ek, 34, 'Deneme Dokuzuncu'); msg := 'HATA: kabul edildi'; exception when others then msg := left(sqlerrm, 50); end;
  s := s || jsonb_build_object('T10_ucuncu_hesap', msg);

  -- T11: A'nın engeli kalkınca cihaz yasağı da kalkar; yeniden kalıcı engellenince yeniden açılır
  perform pg_temp.cy_ol(kurucu, '10.3.3.3');
  r := public.yk_engel_kaldir(ka);
  set constraints all immediate;
  set constraints all deferred;
  s := s || jsonb_build_object('T11_engel_kalkinca', (select jsonb_build_object('aktif', y.aktif, 'not', y.kaldirma_not) from oyun_yonetim.cihaz_yasak y where y.id = v_id));
  perform pg_temp.cy_ol(ub, '10.4.4.4');
  r := public.durum();
  s := s || jsonb_build_object('T11_b_artik_girebilir', r ->> 'kayit_durumu');
  perform pg_temp.cy_ol(kurucu, '10.3.3.3');
  r := public.yk_engelle(ka, null, 'Test: yeniden kalıcı engel', false);
  set constraints all immediate;
  set constraints all deferred;
  s := s || jsonb_build_object('T11_yeniden_engel', (select y.aktif from oyun_yonetim.cihaz_yasak y where y.id = v_id));

  -- T12: Yasaklı cihazlar ekranı ve elle kaldırma / yeniden açma
  perform pg_temp.cy_ol(mod_diger, '10.2.2.3');
  begin r := public.mod_cihaz_yasak_ayarla(v_id, false, 'Test: yetkisiz kaldırma denemesi'); msg := 'HATA: kaldırdı'; exception when others then msg := left(sqlerrm, 50); end;
  s := s || jsonb_build_object('T12_yetkisiz_kaldirma', msg);
  r := public.mod_cihaz_yasaklari();
  s := s || jsonb_build_object('T12_liste', jsonb_build_object('aktif', jsonb_array_length(r -> 'aktif'), 'kaldirabilir', r -> 'kaldirabilir',
    'deneme', jsonb_array_length(r -> 'denemeler'),
    'ornek', (select x - 'id' from jsonb_array_elements(r -> 'aktif') x where (x ->> 'id')::bigint = v_id)));
  perform pg_temp.cy_ol(mod_oyuncu, '10.2.2.2');
  r := public.mod_cihaz_yasak_ayarla(v_id, false, 'Test: yanlışlıkla yasaklanan cihaz');
  s := s || jsonb_build_object('T12_kaldirildi', not (select y.aktif from oyun_yonetim.cihaz_yasak y where y.id = v_id));
  update oyun.profiller p set engel_neden = 'Test: gerekçe güncellendi' where p.id = ua;
  set constraints all immediate;
  set constraints all deferred;
  s := s || jsonb_build_object('T12_elle_kaldirilan_kendiliginden_acilmaz', not (select y.aktif from oyun_yonetim.cihaz_yasak y where y.id = v_id));
  r := public.mod_cihaz_yasak_ayarla(v_id, true, 'Test: yeniden açma gerekçesi');
  s := s || jsonb_build_object('T12_yeniden_acildi', (select y.aktif from oyun_yonetim.cihaz_yasak y where y.id = v_id));
  perform pg_temp.cy_ol(uc, '10.5.5.5');
  begin r := public.mod_cihaz_yasaklari(); msg := 'HATA: oyuncu gördü'; exception when others then msg := left(sqlerrm, 50); end;
  s := s || jsonb_build_object('T12_oyuncu_goremez', msg);

  -- T13: hesabını kendi silen oyuncunun cihazı yasaklanmaz
  perform pg_temp.cy_ol(uj, '10.9.9.9');
  r := public.oturum_kaydet('TEST-DEV-J-' || ek, 'TEST-IZ-9-' || ek);
  r := public.kayit_basvuru_gonder(kj, 34, 'Deneme Onuncu');
  perform pg_temp.cy_ol(mod_diger, '10.2.2.3');
  r := public.admin_kayit_karar2(uj, true, null);
  perform pg_temp.cy_ol(uj, '10.9.9.9');
  r := public.hesabimi_sil();
  set constraints all immediate;
  set constraints all deferred;
  s := s || jsonb_build_object('T13_kendi_silen', r, 'T13_cihaz_yasagi_yok',
    not exists (select 1 from oyun_yonetim.cihaz_yasak y where y.cihaz = oyun.ozet('TEST-DEV-J-' || ek)));

  -- T14: giriş kapısının maliyeti (300 engelsiz oyuncu)
  t0 := clock_timestamp();
  begin
    perform oyun.cihaz_yasak_kapi(p.id, true) from (select x.id from oyun.profiller x where not x.yasakli order by x.id limit 300) p;
    msg := 'tamam';
  exception when others then msg := left(sqlerrm, 60); end;
  s := s || jsonb_build_object('T14_kapi_300_cagri', msg, 'T14_ms', round(extract(epoch from clock_timestamp() - t0) * 1000));

  raise exception 'TEST_SONUC %', s;
end $test$;
