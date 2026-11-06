-- Süper Yönetici Portalı · kabul testleri (Aşama 0 + 1)
-- Canlı veritabanında güvenle çalışır: blok sonunda sonuçları bir hata mesajı olarak döndürür,
-- bu yüzden içindeki her değişiklik (aday, oy, takvim, denetim kaydı) kendiliğinden geri alınır.
-- Çıktı: "KABUL_SONUC {...}" ile başlayan hata metni (JSON).
do $kabul$
declare
  sonuc jsonb := '[]'::jsonb;
  yon uuid; modr uuid; oyuncu uuid; x uuid; x_parti bigint; x_il smallint;
  sm oyun.secimler; so oyun.secimler; scb oyun.secimler; sbel oyun.secimler;
  o jsonb; s jsonb; n1 bigint; n2 bigint; rev1 bigint; rev2 bigint; h text; ok boolean; cb_aday bigint; liste_parti bigint;

  -- jwt
  procedure_dummy int;
begin
  -- ---------- Hazırlık ----------
  select id into yon from oyun.profiller where yonetici limit 1;
  select user_id into modr from oyun.moderatorler limit 1;
  select * into sm from oyun.secimler where tur = 'mv' and durum = 'bekliyor' and not coalesce(sonuc ? 'iptal', false) and oy_bas > now() order by oy_bas limit 1;
  select * into so from oyun.secimler where tur = 'mv_on' and donem = sm.donem;
  select * into scb from oyun.secimler where tur = 'cb' and donem = sm.donem;
  select * into sbel from oyun.secimler where tur = 'bel' and durum = 'bekliyor' and oy_bas > now() + interval '2 hours' order by oy_bas limit 1;
  -- Uygun, partili, yönetici/moderatör olmayan bir oyuncu (X): CB adayı yapılacak.
  select pr.id, pr.parti_id, pr.il_id into x, x_parti, x_il from oyun.profiller pr
   where not pr.yonetici and pr.parti_id is not null and not exists (select 1 from oyun.moderatorler m where m.user_id = pr.id)
     and oyun.yp_mv_uygunluk(pr, sm, oyun.simdi()) is null
     and not exists (select 1 from oyun.partiler pa where pa.gb = pr.id)
   order by pr.olusturma limit 1;
  select id into oyuncu from oyun.profiller where not yonetici and id is distinct from x and id is distinct from modr and not yasakli limit 1;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('hazirlik', jsonb_build_object('mv', sm.id, 'mv_on', so.id, 'cb', scb.id, 'bel', sbel.id,
    'x_var', x is not null, 'mod_var', modr is not null)));

  -- ---------- Senaryo 8: yetkisiz erişim ----------
  -- (a) normal oyuncu, çok faktörlü bile olsa
  perform set_config('request.jwt.claim.sub', oyuncu::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', oyuncu, 'role', 'authenticated', 'aal', 'aal2',
    'amr', jsonb_build_array(jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now())::bigint)))::text, true);
  execute 'set local role authenticated';
  begin perform public.yp_pano(); ok := false; exception when others then ok := sqlerrm like 'YP_YETKI%'; end;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s8_oyuncu_pano_reddedildi', ok));
  begin perform public.yp_onizle('mv_toplu_adaylik', jsonb_build_object('secim_id', sm.id)); ok := false; exception when others then ok := sqlerrm like 'YP_YETKI%'; end;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s8_oyuncu_onizle_reddedildi', ok));
  begin perform oyun.yp_uy_mv_toplu_adaylik(jsonb_build_object('secim_id', sm.id)); ok := false; exception when insufficient_privilege then ok := true; when others then ok := false; end;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s8_ic_islem_dogrudan_kapali', ok));
  execute 'reset role';
  -- (b) moderatör
  if modr is not null then
    perform set_config('request.jwt.claim.sub', modr::text, true);
    perform set_config('request.jwt.claims', jsonb_build_object('sub', modr, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    execute 'set local role authenticated';
    begin perform public.yp_secimler(false); ok := false; exception when others then ok := sqlerrm like 'YP_YETKI%'; end;
    sonuc := sonuc || jsonb_build_array(jsonb_build_object('s8_moderator_reddedildi', ok));
    execute 'reset role';
  end if;
  -- (c) yönetici ama çok faktörsüz
  perform set_config('request.jwt.claim.sub', yon::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', yon, 'role', 'authenticated', 'aal', 'aal1',
    'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp', extract(epoch from now())::bigint)))::text, true);
  execute 'set local role authenticated';
  begin perform public.yp_pano(); ok := false; exception when others then ok := sqlerrm like 'YP_MFA%'; end;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s8_mfa_yok_reddedildi', ok));
  -- (d) anonim
  execute 'reset role';
  execute 'set local role anon';
  begin perform public.yp_pano(); ok := false; exception when insufficient_privilege then ok := true; when others then ok := false; end;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s8_anonim_kapali', ok));
  execute 'reset role';

  -- ---------- Yönetici oturumu (aal2, taze kod) ----------
  perform set_config('request.jwt.claim.sub', yon::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', yon, 'role', 'authenticated', 'aal', 'aal2',
    'amr', jsonb_build_array(jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now())::bigint)))::text, true);
  execute 'set local role authenticated';
  o := public.yp_pano();
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('pano', jsonb_build_object('oyuncu', o->'oyuncu'->'toplam',
    'yaklasan', jsonb_array_length(o->'secim'->'yaklasan'), 'bos_pusula_il', jsonb_array_length(coalesce(o->'secim'->'bos_pusula'->'iller', '[]')))));
  o := public.yp_secim(sm.id);
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('secim_detay', jsonb_build_object('aday', jsonb_array_length(o->'adaylar'), 'tutarli', o->'takvim_tutarli'))));
  execute 'reset role';

  -- X'i bu dönemin CB adayı yap (test verisi; blok sonunda geri alınır).
  insert into oyun.adaylar (secim_id, user_id, parti_id, basvuru_at) values (scb.id, x, x_parti, now()) returning id into cb_aday;

  -- ---------- Senaryo 1: CB adayları hariç uygun herkes MV adayı ----------
  execute 'set local role authenticated';
  o := public.yp_onizle('mv_toplu_adaylik', jsonb_build_object('secim_id', sm.id, 'cb_haric', true));
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s1_onizleme', jsonb_build_object('sayi', o->'sayi', 'cb_haric', o->'cb_haric_sayi',
    'x_haric_cb_nedeniyle', exists (select 1 from jsonb_array_elements(o->'haric') e where (e->>'user_id')::uuid = x and e->>'neden' = 'Cumhurbaşkanı adayı'),
    'x_eklenecekler_arasinda', exists (select 1 from jsonb_array_elements(o->'etkilenen') e where (e->>'user_id')::uuid = x),
    'bos_once', o->'bos_pusula_once', 'bos_sonra', o->'bos_pusula_sonra', 'engel', o->'engel')));
  -- yanlış onay cümlesi
  begin perform public.yp_uygula((o->>'anahtar')::uuid, 'evet'); ok := false; exception when others then ok := sqlerrm like 'YP_ONAY%'; end;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('kritik_yanlis_onay_reddedildi', ok));
  execute 'reset role';
  select count(*) into n1 from oyun.adaylar where secim_id in (so.id, sm.id);
  execute 'set local role authenticated';
  s := public.yp_uygula((o->>'anahtar')::uuid, 'onaylıyorum');
  execute 'reset role';
  select count(*) into n2 from oyun.adaylar where secim_id in (so.id, sm.id);
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s1_uygula', jsonb_build_object('basarili', s->'basarili', 'eklenen', jsonb_array_length(s->'eklenen'),
    'eklenemeyen', s->'eklenemeyen', 'kayit_farki', n2 - n1, 'onizleme_sayisi', o->'sayi', 'dogrulama', s->'dogrulama',
    'cb_adayi_mv_olmadi', not exists (select 1 from oyun.adaylar where user_id = x and secim_id in (so.id, sm.id)),
    'dogru_il_parti', not exists (select 1 from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
      where a.id in (select (e->>'aday_id')::bigint from jsonb_array_elements(s->'eklenen') e)
        and (a.il_id is distinct from pr.il_id or a.parti_id is distinct from pr.parti_id))));

  -- ---------- Senaryo 7: tekrar çalıştırma mükerrer kayıt üretmez ----------
  execute 'set local role authenticated';
  s := public.yp_uygula((o->>'anahtar')::uuid, 'ONAYLIYORUM');
  o := public.yp_onizle('mv_toplu_adaylik', jsonb_build_object('secim_id', sm.id, 'cb_haric', true));
  execute 'reset role';
  select count(*) into n1 from oyun.adaylar where secim_id in (so.id, sm.id);
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s7_tekrar', jsonb_build_object('ayni_anahtar_tekrar', s->'tekrar',
    'kayit_degismedi', n1 = n2, 'yeni_onizleme_engel', o->'engel')));

  -- ---------- CB adaylarını MV'den çıkar + geri al ----------
  insert into oyun.adaylar (secim_id, user_id, parti_id, il_id, basvuru_at) values (so.id, x, x_parti, x_il, now());
  execute 'set local role authenticated';
  o := public.yp_onizle('cb_adaylari_mv_den_cikar', jsonb_build_object('secim_id', sm.id));
  s := public.yp_uygula((o->>'anahtar')::uuid, 'ONAYLIYORUM');
  execute 'reset role';
  ok := not exists (select 1 from oyun.adaylar where user_id = x and secim_id = so.id);
  execute 'set local role authenticated';
  o := public.yp_onizle('geri_al', jsonb_build_object('islem_id', (s->>'islem_id')::bigint));
  s := public.yp_uygula((o->>'anahtar')::uuid, 'ONAYLIYORUM');
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('cb_cikar', jsonb_build_object('silindi', ok,
    'geri_alindi', exists (select 1 from oyun.adaylar where user_id = x and secim_id = so.id), 'geri_basarili', s->'basarili')));
  delete from oyun.adaylar where user_id = x and secim_id = so.id;

  -- ---------- Senaryo 2: CB adayı pusulayı görür ve oy kullanır ----------
  -- Oyun saati MV seçim gününe alınır (yalnız bu işlem içinde), MV ön seçimi sonuçlandırılır.
  update oyun.ayarlar set test_simdi = so.sonuc_at + interval '1 minute' where id = 1;
  perform oyun.sonuclandir(so.id);
  update oyun.ayarlar set test_simdi = sm.oy_bas + interval '1 hour' where id = 1;
  select a.parti_id into liste_parti from oyun.adaylar a where a.secim_id = so.id and a.il_id = x_il and a.sira is not null limit 1;
  perform set_config('request.jwt.claim.sub', x::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', x, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  execute 'set local role authenticated';
  o := public.secim_detay(sm.id);
  begin perform public.oy_ver(sm.id, liste_parti); h := 'ok'; exception when others then h := sqlerrm; end;
  s := public.secim_detay(scb.id);
  begin perform public.oy_ver(scb.id, cb_aday); s := s || jsonb_build_object('_oy', 'ok'); exception when others then s := s || jsonb_build_object('_oy', sqlerrm); end;
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s2_cb_adayi_oy', jsonb_build_object(
    'mv_pusula_secenek', jsonb_array_length(coalesce(o->'secenekler', '[]')), 'mv_oy_engeli', o->'oy_engeli', 'mv_oy', h,
    'cb_pusula_secenek', jsonb_array_length(coalesce(s->'secenekler', '[]')), 'cb_oy', s->'_oy',
    'oylar_kaydi', (select count(*) from oyun.oylar where secmen = x and secim_id in (sm.id, scb.id)))));
  update oyun.ayarlar set test_simdi = null where id = 1;

  -- ---------- Senaryo 3: takvim değişikliği istemciye yansır + geri al ----------
  perform set_config('request.jwt.claim.sub', yon::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', yon, 'role', 'authenticated', 'aal', 'aal2',
    'amr', jsonb_build_array(jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now())::bigint)))::text, true);
  select rev into rev1 from public.oyun_kontrol_sinyali where id = 1;
  execute 'set local role authenticated';
  o := public.yp_onizle('secim_takvim', jsonb_build_object('secim_id', sbel.id, 'oy_bit', sbel.oy_bit - interval '1 hour', 'duyur', false));
  s := public.yp_uygula((o->>'anahtar')::uuid, null);
  execute 'reset role';
  select rev into rev2 from public.oyun_kontrol_sinyali where id = 1;
  perform set_config('request.jwt.claim.sub', oyuncu::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', oyuncu, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  execute 'set local role authenticated';
  h := (public.secim_detay(sbel.id))->>'oy_bit';
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s3_takvim', jsonb_build_object('basarili', s->'basarili',
    'istemci_yeni_bitis', h::timestamptz = sbel.oy_bit - interval '1 hour', 'sinyal_gitti', rev2 > rev1, 'dogrulama', s->'dogrulama')));
  perform set_config('request.jwt.claim.sub', yon::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', yon, 'role', 'authenticated', 'aal', 'aal2',
    'amr', jsonb_build_array(jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now())::bigint)))::text, true);
  execute 'set local role authenticated';
  o := public.yp_onizle('geri_al', jsonb_build_object('islem_id', (s->>'islem_id')::bigint));
  s := public.yp_uygula((o->>'anahtar')::uuid, 'ONAYLIYORUM');
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s3_geri_al', jsonb_build_object('basarili', s->'basarili',
    'eski_hale_dondu', (select oy_bit from oyun.secimler where id = sbel.id) = sbel.oy_bit)));

  -- ---------- Veri değişirse uygulanmaz; süresi dolan ön izleme uygulanmaz ----------
  execute 'set local role authenticated';
  o := public.yp_onizle('secim_takvim', jsonb_build_object('secim_id', sbel.id, 'oy_bit', sbel.oy_bit - interval '30 minutes', 'duyur', false));
  execute 'reset role';
  update oyun.secimler set sonuc_at = sonuc_at + interval '1 minute' where id = sbel.id;
  execute 'set local role authenticated';
  s := public.yp_uygula((o->>'anahtar')::uuid, null);
  execute 'reset role';
  update oyun.secimler set sonuc_at = sbel.sonuc_at where id = sbel.id;
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('degisen_veri_korumasi', jsonb_build_object('uygulanmadi', s->'basarili' = 'false'::jsonb, 'degisti', s->'degisti',
    'takvim_ayni', (select oy_bit from oyun.secimler where id = sbel.id) = sbel.oy_bit)));
  execute 'set local role authenticated';
  o := public.yp_onizle('secim_takvim', jsonb_build_object('secim_id', sbel.id, 'oy_bit', sbel.oy_bit - interval '30 minutes', 'duyur', false));
  execute 'reset role';
  update oyun.yp_islem set gecerlilik = now() - interval '1 second' where anahtar = (o->>'anahtar')::uuid;
  execute 'set local role authenticated';
  s := public.yp_uygula((o->>'anahtar')::uuid, null);
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('sure_dolu_onizleme', jsonb_build_object('uygulanmadi', s->'basarili' = 'false'::jsonb, 'hata', s->'hata')));

  -- ---------- Kritik işlem, kod eskiyse yeniden doğrulama ister ----------
  perform set_config('request.jwt.claims', jsonb_build_object('sub', yon, 'role', 'authenticated', 'aal', 'aal2',
    'amr', jsonb_build_array(jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now() - interval '2 hours')::bigint)))::text, true);
  execute 'set local role authenticated';
  o := public.yp_onizle('genel_secim_olustur', jsonb_build_object('on_gun', (now() at time zone 'Europe/Istanbul')::date + 20, 'secim_gun', (now() at time zone 'Europe/Istanbul')::date + 21));
  begin perform public.yp_uygula((o->>'anahtar')::uuid, 'ONAYLIYORUM'); ok := false; exception when others then ok := sqlerrm like 'YP_TAZE%'; end;
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('kritik_taze_kod', jsonb_build_object('reddedildi', ok, 'onizleme_engel', o->'engel', 'kayit', o->'sayi')));

  -- ---------- Erken genel seçim + geri al ----------
  perform set_config('request.jwt.claims', jsonb_build_object('sub', yon, 'role', 'authenticated', 'aal', 'aal2',
    'amr', jsonb_build_array(jsonb_build_object('method', 'totp', 'timestamp', extract(epoch from now())::bigint)))::text, true);
  execute 'set local role authenticated';
  s := public.yp_uygula((o->>'anahtar')::uuid, 'ONAYLIYORUM');
  execute 'reset role';
  n1 := (select count(*) from oyun.secimler where donem = s->'sonra'->>'donem' and durum = 'bekliyor');
  execute 'set local role authenticated';
  o := public.yp_onizle('geri_al', jsonb_build_object('islem_id', (s->>'islem_id')::bigint));
  s := public.yp_uygula((o->>'anahtar')::uuid, 'ONAYLIYORUM');
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('erken_secim', jsonb_build_object('kurulan', n1, 'geri_basarili', s->'basarili')));

  -- ---------- Senaryo 10: denetim kayıtları ----------
  execute 'set local role authenticated';
  o := public.yp_islemler(50, 0);
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('s10_denetim', jsonb_build_object('kayit', o->'toplam',
    'durumlar', (select jsonb_object_agg(d, c) from (select e->>'durum' d, count(*) c from jsonb_array_elements(o->'kayitlar') e group by 1) z),
    'once_sonra_dolu', (select count(*) from jsonb_array_elements(o->'kayitlar') e where e->>'durum' in ('uygulandi', 'geri_alindi') and e->'sonra' is not null),
    'mod_log', (select count(*) from oyun.mod_kayit where islem like 'yp\_%'))));

  -- ---------- Oy teşhisi (bu gecenin seçimi; yalnız okuma) ----------
  execute 'set local role authenticated';
  o := public.yp_oy_teshis((select id from oyun.secimler where tur = 'mv' and donem like 'erken-genel-0-%' order by id desc limit 1), null, null, true);
  execute 'reset role';
  sonuc := sonuc || jsonb_build_array(jsonb_build_object('teshis_bu_gece', o->'ozet',
    'gizli_oy', not exists (select 1 from jsonb_array_elements(o->'oyuncular') e where e ? 'parti_id' or e ? 'aday_id' or e ? 'tercih')));

  raise exception 'KABUL_SONUC %', sonuc::text;
end
$kabul$;
