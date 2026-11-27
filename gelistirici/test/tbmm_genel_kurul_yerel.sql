-- TBMM Genel Kurul salonu · yerel akış testi (27.11.2026). Her şey sonda geri alınır.
-- Çalıştırma: psql -h /tmp -U postgres -d oyun_test -v ON_ERROR_STOP=1 -f gelistirici/test/tbmm_genel_kurul_yerel.sql
begin;
create or replace function pg_temp.ben(u uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u::text, true), set_config('request.jwt.claims', jsonb_build_object('sub', u, 'role', 'authenticated')::text, true),
         set_config('oyun.gk_degisti', '', true), set_config('oyun.gk_ayna', '', true)
$$;
create or replace function pg_temp.saat(t text) returns void language sql as $$
  update oyun.ayarlar set test_simdi = t::timestamptz where id = 1;
  select set_config('oyun.gk_degisti', '', true);
$$;
create or replace function pg_temp.hata(q text) returns text language plpgsql as $$
begin execute q; return 'HATA YOK'; exception when others then return sqlerrm; end $$;

do $t$
declare pa bigint; pb bigint; u uuid; ua uuid[] := '{}'; ub uuid[] := '{}'; i int; x jsonb; y jsonb; b bigint; s bigint; r text; n int; tid bigint;
  gbv uuid; gb_b uuid; yon uuid;
begin
  insert into oyun.ayarlar(id) values (1) on conflict do nothing;
  insert into oyun.secimler(id, tur, donem, oy_bas, oy_bit, sonuc_at, durum) overriding system value values (6, 'mv', 'test', '2026-11-26 05:00+00', '2026-11-26 19:00+00', '2026-11-26 19:30+00', 'tamam') on conflict do nothing;
  update oyun.ayarlar set gercekci_siyaset = true where id = 1;
  insert into oyun.partiler(ad, kisa, renk) values ('Cumhuriyet Yolu Partisi', 'CYP', '#c62828') returning id into pa;
  insert into oyun.partiler(ad, kisa, renk) values ('Milliyetçi Birlik Partisi', 'MBP', '#ef8f00') returning id into pb;
  for i in 1..30 loop
    insert into auth.users(id) values (gen_random_uuid()) returning id into u;
    insert into oyun.profiller(id, kad, il_id, parti_id, ad_soyad) values (u, 'vekil' || i, (i % 81) + 1, case when i <= 21 then pa else pb end, 'Vekil Ad' || i || ' Soyad');
    insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, kaynak, bas) values ('mv', u, (i % 81) + 1, case when i <= 21 then pa else pb end, 6, 'secim', '2026-11-27 12:00+00');
    if i <= 21 then ua := ua || u; else ub := ub || u; end if;
  end loop;
  -- izleyici (vekil değil)
  insert into auth.users(id) values ('00000000-0000-0000-0000-0000000000aa');
  insert into oyun.profiller(id, kad, il_id, ad_soyad) values ('00000000-0000-0000-0000-0000000000aa', 'izleyici', 34, 'İzleyici Vatandaş');
  gbv := ua[2];
  insert into oyun.makamlar(tur, user_id, parti_id, kaynak, bas) values ('grup_bskv', gbv, pa, 'secim', '2026-11-27 12:00+00');
  update oyun.partiler set gb = ub[1] where id = pb;

  perform pg_temp.saat('2026-11-27 18:00:00+00');   -- 21.00 TSİ
  perform pg_temp.ben(ua[1]);
  -- birleşim öncesi: gündem dışı istemi ve grup önerisi
  x := public.gk_gundem_disi_iste('Ege''de kuraklık ve çiftçinin borç yükü');
  raise notice 'GD istemi: %', x;
  perform pg_temp.ben(gbv);
  x := public.gk_grup_onerisi_ver('bildiri', 'Depremzedelerle dayanışma bildirisi', 'Türkiye Büyük Millet Meclisi deprem bölgesindeki yurttaşlarımızın yanındadır.', null);
  raise notice 'Grup önerisi: %', x;

  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'ilerlet1: %', x;
  select id into b from oyun.gk_birlesim where durum = 'yoklama';
  if b is null then raise exception 'Birleşim açılmadı'; end if;
  raise notice 'Birleşim %: %', b, (select jsonb_agg(baslik order by sira) from oyun.gk_gundem where birlesim_id = b);

  -- yoklama: 12 vekil buradayım (yeter = ceil(30/3) = 10)
  for i in 1..12 loop perform pg_temp.ben(case when i <= 8 then ua[i] else ub[i - 8] end); x := public.gk_buradayim(); end loop;
  perform pg_temp.ben(ua[1]);
  r := pg_temp.hata('select public.gk_soz_iste(''kisisel'')');
  raise notice 'Yoklamada söz istemi: %', r;
  perform pg_temp.saat('2026-11-27 18:05:05+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Yoklama sonrası durum: % aktif=%', (select durum from oyun.gk_birlesim where id = b), (select g.baslik from oyun.gk_gundem g join oyun.gk_birlesim bb on bb.aktif_gundem = g.id where bb.id = b);

  -- yemin
  for i in 1..5 loop perform pg_temp.ben(ua[i]); x := public.gk_andic(); end loop;
  perform pg_temp.ben(ua[1]); r := pg_temp.hata('select public.gk_andic()'); raise notice 'İkinci yemin: %', r;

  -- Geçici başkan gündemi ilerletir (yemin -> sunuş -> gündem dışı)
  yon := oyun.gecici_baskan();
  raise notice 'Geçici başkan: %', (select kad from oyun.profiller where id = yon);
  perform pg_temp.ben(yon);
  x := public.gk_durum(0, 0);   -- salonda (yönetici)
  x := public.gk_gundem_gec(null);
  raise notice 'Gündem geçildi: aktif=%', (select g.tur from oyun.gk_gundem g join oyun.gk_birlesim bb on bb.aktif_gundem = g.id where bb.id = b);
  -- gündem dışı konuşmacı otomatik söz alır (20 sn bekleme)
  perform pg_temp.saat('2026-11-27 18:06:00+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  select id into s from oyun.meclis_soz where birlesim_id = b and durum = 'verildi';
  raise notice 'Kürsüde: % (%)', (select tur from oyun.meclis_soz where id = s), (select kad from oyun.profiller p join oyun.meclis_soz m on m.user_id = p.id where m.id = s);
  perform pg_temp.ben(ua[1]);
  x := public.gk_kursu_cik();
  x := public.gk_konus('Sayın Başkan, değerli milletvekilleri; Ege''de kuraklık üçüncü yılına girdi. Çiftçimiz borç sarmalında.');
  raise notice 'Konuştu: %', x;
  perform pg_temp.saat('2026-11-27 18:06:05+00');
  r := pg_temp.hata('select public.gk_konus(''' || repeat('kelime ', 130) || ''')');
  raise notice 'Kelime aşımı: %', r;
  -- laf ve alkış
  perform pg_temp.ben(ub[2]); perform pg_temp.saat('2026-11-27 18:06:10+00');
  x := public.gk_laf('Hükümet ne yapıyor peki?');
  raise notice 'Laf: %', x;
  perform pg_temp.saat('2026-11-27 18:06:15+00');
  r := pg_temp.hata('select public.gk_laf(''tekrar tekrar'')'); raise notice 'Laf sınırı: %', r;
  select id into tid from oyun.gk_tutanak where birlesim_id = b and tur = 'konusma' order by id desc limit 1;
  for i in 2..6 loop perform pg_temp.ben(ua[i]); perform pg_temp.saat('2026-11-27 18:06:' || (10 + i * 3) || '+00'); x := public.gk_tepki(tid, 'alkis'); end loop;
  perform pg_temp.ben('00000000-0000-0000-0000-0000000000aa'); x := public.gk_tepki(tid, 'alkis');
  raise notice 'Tepki satırı: %', (select metin from oyun.gk_tutanak where birlesim_id = b and tur = 'tepki' order by id desc limit 1);
  -- mikrofon kapanır (gündem dışı 300 sn)
  perform pg_temp.saat('2026-11-27 18:11:30+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Süre doldu: % / söz=%', (select metin from oyun.gk_tutanak where birlesim_id = b and tur = 'sistem' order by id desc limit 1), (select durum from oyun.meclis_soz where id = s);
  -- Başkan ek süre verir
  perform pg_temp.ben(yon); x := public.gk_durum(0, 0);
  x := public.gk_ek_sure(s);
  perform pg_temp.ben(ua[1]); perform pg_temp.saat('2026-11-27 18:11:40+00');
  x := public.gk_konus('Tamamlıyorum Sayın Başkan: borç erteleme şart. Teşekkür ederim.');
  x := public.gk_konusma_bitir();
  raise notice 'Ek süre sonrası söz: %', (select durum || '/' || kelime_kullanilan from oyun.meclis_soz where id = s);

  -- gündem dışı bitince grup önerisine geçer
  perform pg_temp.saat('2026-11-27 18:12:10+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Aktif madde: %', (select g.tur || ' · ' || g.baslik from oyun.gk_gundem g join oyun.gk_birlesim bb on bb.aktif_gundem = g.id where bb.id = b);
  -- grup adına söz + sıra düzenleme
  perform pg_temp.ben(gbv); x := public.gk_soz_iste('grup');
  perform pg_temp.ben(ub[3]); x := public.gk_soz_iste('kisisel');
  perform pg_temp.ben(ub[4]); x := public.gk_soz_iste('kisisel');
  perform pg_temp.ben(ua[9]); r := pg_temp.hata('select public.gk_soz_iste(''grup'')'); raise notice 'Yetkisiz grup sözü: %', r;
  perform pg_temp.ben(yon); x := public.gk_durum(0, 0);
  x := public.gk_soz_sira((select id from oyun.meclis_soz where user_id = ub[4] and durum = 'bekliyor'), 1);
  x := public.gk_durum(0, 0);
  raise notice 'Sıra: %', (select jsonb_agg(z -> 'kisi' ->> 'kad') from jsonb_array_elements(x -> 'genel' -> 'sira') z);
  x := public.gk_soz_ver((select id from oyun.meclis_soz where user_id = ub[4] and durum = 'bekliyor'));
  r := pg_temp.hata('select public.gk_soz_ver(' || (select id from oyun.meclis_soz where user_id = gbv and durum = 'bekliyor') || ')');
  raise notice 'Kürsü doluyken ikinci söz: %', r;
  perform pg_temp.ben(ub[4]); x := public.gk_konus('MBP olarak bu öneriyi destekliyoruz.'); x := public.gk_konusma_bitir();
  -- Başkan öneriyi oylamaya sunar; sıradakiler bekler -> önce sırayı boşalt
  perform pg_temp.ben(yon);
  update oyun.meclis_soz set durum = 'geri' where birlesim_id = b and durum = 'bekliyor';
  x := public.gk_oylamaya_sun(null);
  raise notice 'Oylama açıldı: %', x;
  s := (x ->> 'id')::bigint;
  for i in 1..8 loop perform pg_temp.ben(ua[i + 2]); x := public.gk_oy(s, case when i <= 6 then 'kabul' else 'ret' end); end loop;
  select to_jsonb(o) into y from oyun.gk_oylama o where birlesim_id = b order by id desc limit 1;
  perform pg_temp.ben(ub[1]); r := pg_temp.hata('select public.gk_karar_yeter_iste(' || (y ->> 'id') || ')'); raise notice 'Grubu olmayan GB karar yeter istemi: %', r;
  perform pg_temp.ben('00000000-0000-0000-0000-0000000000aa'); r := pg_temp.hata('select public.gk_oy(' || (y ->> 'id') || ', ''kabul'')'); raise notice 'İzleyici oyu: %', r;
  x := public.gk_durum(0, 0);
  raise notice 'İzleyici görünümü: oylama=% kabul=% izleyici=% ben=%', x -> 'genel' -> 'oylama' ->> 'baslik', x -> 'genel' -> 'oylama' ->> 'kabul', x -> 'salon' ->> 'izleyici', x -> 'ben' ->> 'vekil';
  perform pg_temp.saat('2026-11-27 18:16:00+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Oylama sonucu: % | haber=%', (select metin from oyun.gk_tutanak where birlesim_id = b and tur = 'oylama' order by id desc limit 1),
    (select baslik from oyun.ajans_haberleri where kaynak_anahtar like 'tbmm-bildiri-%' order by id desc limit 1);
  raise notice 'Sonraki madde: %', (select g.tur || ' · ' || g.baslik from oyun.gk_gundem g join oyun.gk_birlesim bb on bb.aktif_gundem = g.id where bb.id = b);

  -- disiplin: uyarma + kınama oylaması
  perform pg_temp.ben(yon);
  x := public.gk_disiplin('vekil25', 'uyarma', 'Kürsüdeki hatibe hakaret ettiğiniz için', 1);
  x := public.gk_disiplin('vekil25', 'kinama', 'Genel Kurulda ağır hakaret', 1);
  for i in 3..9 loop perform pg_temp.ben(ua[i]); x := public.gk_oy((select id from oyun.gk_oylama where birlesim_id = b and durum = 'acik'), 'kabul'); end loop;
  perform pg_temp.saat('2026-11-27 18:20:00+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Kınama: % · kesinti=%', (select durum from oyun.gk_disiplin where tur = 'kinama' order by id desc limit 1),
    oyun.vekil_kesinti_orani((select id from oyun.profiller where kad = 'vekil25'), oyun.simdi());

  -- sataşma (Başkanlık yokken otomatik değerlendirme)
  update oyun.gk_salonda set son = son - interval '10 minutes' where birlesim_id = b;
  perform pg_temp.ben(ua[5]); x := public.gk_soz_iste('kisisel');
  perform pg_temp.saat('2026-11-27 18:20:30+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Başkansız otomatik söz: %', (select durum from oyun.meclis_soz where user_id = ua[5] and birlesim_id = b order by id desc limit 1);
  perform pg_temp.ben(ua[5]); x := public.gk_konus('MBP grubunun tutumunu anlamakta zorlanıyoruz.');
  select id into tid from oyun.gk_tutanak where birlesim_id = b and tur = 'konusma' order by id desc limit 1;
  perform pg_temp.ben(ub[5]); x := public.gk_soz_iste('satasma', tid);
  raise notice 'Sataşma istemi (MBP adı geçti): %', x;
  perform pg_temp.ben(ub[6]); r := pg_temp.hata('select public.gk_soz_iste(''satasma'', ' || tid || ')'); raise notice 'Sataşma (aynı parti, ikinci istem): %', r;

  -- arşiv, harita, durum (artımlı)
  x := public.gk_durum(0, 0);
  y := public.gk_durum((x ->> 'surum')::bigint, (select max(id) from oyun.gk_tutanak where birlesim_id = b) - 3);
  raise notice 'Artımlı: ayni=% yeni=%', y ->> 'ayni', jsonb_array_length(y -> 'yeni');
  x := public.gk_salon_harita();
  raise notice 'Harita: % parti, % vekil', jsonb_array_length(x -> 'partiler'), jsonb_array_length(x -> 'vekiller');

  -- süre biter: kapanış + haber
  perform pg_temp.saat('2026-11-27 19:10:00+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Kapanış: % · özet=%', (select durum from oyun.gk_birlesim where id = b), (select ozet from oyun.gk_birlesim where id = b);
  raise notice 'Haber: %', (select baslik || ' | ' || ozet from oyun.ajans_haberleri where kaynak_anahtar = 'tbmm-birlesim-' || b);
  x := public.gk_birlesimler(5);
  raise notice 'Arşiv: %', jsonb_array_length(x);
  x := public.gk_tutanak_oku(b, null);
  raise notice 'Tutanak satırı: %', jsonb_array_length(x -> 'satirlar');
  -- birleşim yokken Genel Kurul sohbeti kapalı
  perform pg_temp.ben(ua[7]);
  r := pg_temp.hata('select public.sohbet_yaz(''meclis'', ''Merhaba'')'); raise notice 'Birleşim yokken sohbet: %', r;
  -- genel görüşme önergesi + imza
  x := public.gk_gg_ver('Gençlerin işsizliği ve beyin göçü üzerine genel görüşme', repeat('Gençlerimizin işsizlik oranı yükseliyor ve beyin göçü artıyor. ', 3), false);
  for i in 8..11 loop perform pg_temp.ben(ua[i]); y := public.gk_gg_imza((x ->> 'id')::bigint, true); end loop;
  raise notice 'Genel görüşme: % (imza %/%)', (select durum from oyun.gk_genel_gorusme where id = (x ->> 'id')::bigint), y ->> 'imza', y ->> 'yeter';
  -- ertesi gün birleşimi gündemde ön görüşme
  perform pg_temp.saat('2026-11-28 18:00:00+00');
  x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Yeni birleşim gündemi: %', (select jsonb_agg(g.tur order by g.sira) from oyun.gk_gundem g join oyun.gk_birlesim bb on bb.id = g.birlesim_id where bb.gun = '2026-11-28');
  -- yoklama başarısız -> ara -> tekrar -> kapanır (toplanamadı)
  perform pg_temp.saat('2026-11-28 18:05:10+00'); x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Yetersiz yoklama: %', (select durum || ' ara=' || coalesce(ara_neden, '') from oyun.gk_birlesim where gun = '2026-11-28');
  perform pg_temp.saat('2026-11-28 18:15:20+00'); x := oyun.gk_ilerlet(oyun.simdi());
  perform pg_temp.saat('2026-11-28 18:20:30+00'); x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'İkinci yoklama: % | haber=%', (select durum from oyun.gk_birlesim where gun = '2026-11-28'),
    (select baslik from oyun.ajans_haberleri where kaynak_anahtar = 'tbmm-birlesim-' || (select id from oyun.gk_birlesim where gun = '2026-11-28'));
  -- olağanüstü birleşim çağrısı (yetkisiz / yetkili)
  perform pg_temp.ben(ua[3]); r := pg_temp.hata('select public.gk_olaganustu_cagir(''2026-11-29 11:00+00'', ''Deprem bölgesi için acil toplantı'')'); raise notice 'Yetkisiz olağanüstü: %', r;
  update oyun.profiller set yonetici = true where id = ua[4];
  perform pg_temp.ben(ua[4]); x := public.gk_olaganustu_cagir('2026-11-29 11:00+00', 'Deprem bölgesi için acil toplantı');
  raise notice 'Yönetici olağanüstü: % · çakışma: %', x, pg_temp.hata('select public.gk_olaganustu_cagir(''2026-11-29 11:30+00'', ''İkinci deneme toplantısı'')');
  perform pg_temp.saat('2026-11-29 11:00:30+00'); x := oyun.gk_ilerlet(oyun.simdi());
  raise notice 'Olağanüstü açıldı: %', (select tur || '/' || durum || '/no=' || no from oyun.gk_birlesim where tur = 'olaganustu');
  raise notice 'Tutanak örnekleri: %', (select jsonb_agg(coalesce(ad, '·') || ' | ' || tur || ' | ' || left(metin, 90) order by id) from oyun.gk_tutanak where birlesim_id = b);
end $t$;
rollback;
