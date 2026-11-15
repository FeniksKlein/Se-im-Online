-- 209 TV canlı yayın — canlı veritabanında GERİ ALINAN deneme. Önce modül, sonra bu blok; sonunda bilerek hata verir (her şey geri alınır).
-- Oyuncular: S = kanal sahibi (UYGAR TR TV, id 3), V1/V2/V3 izleyiciler.
do $t$
declare S uuid := 'f9d4bed7-92bc-4646-875e-3dcd794fed28'; V1 uuid := '3b8d707e-84f4-4107-aafd-daa784f0a416';
  V2 uuid := 'd7898b4b-0c01-441b-bc57-788bcf0e9465'; V3 uuid := '5a9ffa76-18d0-494a-8b1d-3a1d03dd4378';
  out jsonb := '{}'; d jsonb; pid bigint; aid bigint; yid bigint; c1 numeric; c1b numeric; kasa0 numeric; kasa1 numeric; e text; pid2 bigint;
  procedure_ok boolean;
begin
  -- yardımcı: kullanıcı değiştir
  perform set_config('request.jwt.claim.sub', S::text, true);
  select kasa into kasa0 from oyun.tv_kanal where id = 3;
  -- aynı gün eski program sayısı sınırına takılmamak için: yalnız seviye bilgisini oku
  out := out || jsonb_build_object('seviye', oyun.tv_seviye(3));
  d := public.tv_program_ac(3, 'yarisma', 'Deneme Bilgi Yarışması', 'test', null, 30, null);
  pid := (d->>'id')::bigint; out := out || jsonb_build_object('acilis', d->>'durum', 'tur_ad', d->>'tur_ad');
  d := public.tv_odul_koy(pid, 30000); out := out || jsonb_build_object('odul', d);
  begin perform public.tv_odul_koy(pid, 80000); exception when others then out := out || jsonb_build_object('odul_sinir', sqlerrm); end;

  perform set_config('request.jwt.claim.sub', V1::text, true); d := public.tv_canli(pid, 0, 0);
  out := out || jsonb_build_object('v1_rol', d->>'rolum', 'v1_izleyici', d->'izleyici', 'reyting', d->'reyting', 'pay', d->'pay');
  perform set_config('request.jwt.claim.sub', V2::text, true); perform public.tv_canli(pid, 0, 0);

  perform set_config('request.jwt.claim.sub', S::text, true);
  d := public.tv_anket_ac(pid, 'Türkiye''nin başkenti neresidir?', array['İzmir','Ankara','Bursa',''], 30, 1); aid := (d->>'id')::bigint;
  begin perform public.tv_anket_ac(pid, 'İkinci soru?', array['a','b'], 30, 0); exception when others then out := out || jsonb_build_object('tek_soru', sqlerrm); end;
  d := public.tv_canli(pid, 0, 0); out := out || jsonb_build_object('sunucu_goru_dogru', d->'anket'->'dogru', 'secenek_n', jsonb_array_length(d->'anket'->'secenekler'));

  perform set_config('request.jwt.claim.sub', V1::text, true);
  d := public.tv_canli(pid, 0, 0); out := out || jsonb_build_object('izleyici_dogru_gizli', d->'anket'->'dogru', 'izleyici_oylar_gizli', d->'anket'->'oylar');
  perform public.tv_anket_oyla(aid, 1);
  begin perform public.tv_anket_oyla(aid, 0); exception when others then out := out || jsonb_build_object('kilit', sqlerrm); end;
  perform set_config('request.jwt.claim.sub', V2::text, true); perform public.tv_anket_oyla(aid, 0);
  perform set_config('request.jwt.claim.sub', S::text, true);
  begin perform public.tv_anket_oyla(aid, 1); exception when others then out := out || jsonb_build_object('sunucu_oy', sqlerrm); end;
  perform public.tv_anket_kapat(aid);
  perform set_config('request.jwt.claim.sub', V1::text, true); d := public.tv_canli(pid, 0, 0);
  out := out || jsonb_build_object('acik_sonra', d->'anket', 'tablo', d->'yarisma');

  -- emoji, yorum, soru, destek, ekrana alma
  d := public.tv_emoji(pid, 'ates'); out := out || jsonb_build_object('emoji1', d);
  d := public.tv_emoji(pid, 'kalp'); out := out || jsonb_build_object('emoji2_hiz', d);
  d := public.tv_yorum_yaz(pid, 'Sunucuya sorum: ödül ne zaman dağıtılıyor?', true); yid := (d->>'id')::bigint;
  begin perform public.tv_yorum_yaz(pid, 'Hemen ikinci yorum', false); exception when others then out := out || jsonb_build_object('yorum_hiz', sqlerrm); end;
  perform set_config('request.jwt.claim.sub', V2::text, true); d := public.tv_yorum_destek(yid); out := out || jsonb_build_object('destek', d);
  perform public.tv_emoji(pid, 'alkis');
  d := public.tv_soz_iste(pid, true); out := out || jsonb_build_object('soz', d);
  perform set_config('request.jwt.claim.sub', S::text, true);
  d := public.tv_canli(pid, 0, 0); out := out || jsonb_build_object('kuyruk', d->'soz'->'kuyruk', 'sorular', d->'sorular', 'emoji', d->'emoji', 'isi', d->'isi');
  perform public.tv_yorum_ekrana(yid);
  perform public.tv_soz_ver(pid, (select kad from oyun.profiller where id = V2));
  begin perform public.tv_reklam_arasi(pid); exception when others then out := out || jsonb_build_object('reklam_arasi', sqlerrm); end;
  -- anket (her formatta)
  d := public.tv_anket_ac(pid, 'Yarışma formatını beğendiniz mi?', array['Evet','Hayır'], 60, null); aid := (d->>'id')::bigint;
  perform set_config('request.jwt.claim.sub', V1::text, true); perform public.tv_anket_oyla(aid, 0); perform public.tv_anket_oyla(aid, 1);
  d := public.tv_canli(pid, 0, 0); out := out || jsonb_build_object('anket_canli', d->'anket'->'oylar', 'ekranda', d->'ekranda');
  perform set_config('request.jwt.claim.sub', V2::text, true);
  d := public.tv_yaz(pid, 'Canlı bağlantıdan merhaba!'); out := out || jsonb_build_object('baglanti_yaz', d->'tamam');
  begin perform public.tv_anket_oyla((select max(id) from oyun.tv_anket where program_id = pid and tur='yarisma'), 0); exception when others then out := out || jsonb_build_object('kapali_oy', sqlerrm); end;

  -- bitir, ödül dağıt
  select para into c1 from oyun.cuzdan where user_id = V1;
  perform set_config('request.jwt.claim.sub', S::text, true);
  perform public.tv_bitir(pid);
  perform set_config('request.jwt.claim.sub', V1::text, true); d := public.tv_canli(pid, 0, 0);
  select para into c1b from oyun.cuzdan where user_id = V1; select kasa into kasa1 from oyun.tv_kanal where id = 3;
  out := out || jsonb_build_object('v1_kazanc', c1b - c1, 'kasa_fark', kasa1 - kasa0, 'kazananlar', d->'yarisma'->'kazananlar', 'durum_son', d->>'durum',
     'mesaj_sayi', jsonb_array_length(d->'mesajlar'), 'son_mesajlar', (select jsonb_agg(m->>'metin') from jsonb_array_elements(d->'mesajlar') m where m->>'rol' in ('sistem','seyirci')));

  -- takip, hatırlatma, planlı program, ek ekranlar
  d := public.tv_takip(3, true); out := out || jsonb_build_object('takip', d);
  perform set_config('request.jwt.claim.sub', S::text, true);
  d := public.tv_program_ac(3, 'acik_oturum', 'Deneme Açık Oturum', null, oyun.simdi() + interval '2 hours', 30, null); pid2 := (d->>'id')::bigint;
  perform set_config('request.jwt.claim.sub', V1::text, true);
  d := public.tv_hatirlat(pid2, true); out := out || jsonb_build_object('hatirlat', d);
  out := out || jsonb_build_object('liste_ek', public.tv_liste_ek() - 'kanallar', 'kanal_ek', public.tv_kanal_ek(3), 'reyting_prog', public.tv_reyting()->'programlar'->0,
    'reyting_ozet', public.tv_reyting() - 'programlar' - 'kanallar' - 'baz');
  -- program başlarken takipçi + hatırlatma bildirimi (saat ileri alınamadığı için bas geriye çekilir)
  update oyun.tv_program set bas = oyun.simdi() - interval '1 second', bit = oyun.simdi() + interval '30 minutes' where id = pid2;
  perform oyun.tv_program_guncelle(pid2);
  out := out || jsonb_build_object('basla_bildirim', (select jsonb_agg(metin) from oyun.bildirimler where user_id = V1 and zaman >= oyun.simdi() and (metin like 'Hatırlatma%' or metin like 'Takip%'))) ;
  out := out || jsonb_build_object('hafta', oyun.tv_hafta_kontrol(), 'eski_detay_calisir', (public.tv_detay(pid2) ? 'mesajlar'), 'eski_liste', jsonb_array_length(public.tv_liste()->'kanallar'));
  raise exception 'SONUC %', out;
end $t$;
