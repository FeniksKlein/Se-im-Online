-- TBMM komisyon / denetim / vekil görevleri · yerel akış testi (27.11.2026). Sonda geri alınır.
begin;
create or replace function pg_temp.ben(u uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u::text, true), set_config('request.jwt.claims', jsonb_build_object('sub', u, 'role', 'authenticated')::text, true),
         set_config('oyun.gk_degisti', '', true)
$$;
create or replace function pg_temp.saat(t text) returns void language sql as $$ update oyun.ayarlar set test_simdi = t::timestamptz where id = 1 $$;
create or replace function pg_temp.hata(q text) returns text language plpgsql as $$ begin execute q; return 'HATA YOK'; exception when others then return sqlerrm; end $$;
do $t$
declare pa bigint; u uuid; v uuid[] := '{}'; vat uuid[] := '{}'; bakan uuid; i int; x jsonb; hb bigint; q bigint; r text; d bigint;
begin
  insert into oyun.ayarlar(id) values (1) on conflict do nothing;
  insert into oyun.secimler(id, tur, donem, oy_bas, oy_bit, sonuc_at, durum) overriding system value values (6, 'mv', 'test', '2026-11-26 05:00+00', '2026-11-26 19:00+00', '2026-11-26 19:30+00', 'tamam') on conflict do nothing;
  insert into oyun.partiler(ad, kisa, renk) values ('Test Partisi', 'TP', '#123456') returning id into pa;
  for i in 1..6 loop
    insert into auth.users(id) values (gen_random_uuid()) returning id into u;
    insert into oyun.profiller(id, kad, il_id, parti_id, ad_soyad, olusturma) values (u, 'mv' || i, 35, pa, 'Milletvekili ' || i, '2026-11-01');
    insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, kaynak, bas) values ('mv', u, 35, pa, 6, 'secim', '2026-11-27 12:00+00');
    v := v || u;
  end loop;
  for i in 1..5 loop
    insert into auth.users(id) values (gen_random_uuid()) returning id into u;
    insert into oyun.profiller(id, kad, il_id, ad_soyad, olusturma, son_gorulme) values (u, 'vatandas' || i, 35, 'Vatandaş ' || i, '2026-11-01', '2026-11-27 10:00+00');
    vat := vat || u;
  end loop;
  insert into auth.users(id) values (gen_random_uuid()) returning id into bakan;
  insert into oyun.profiller(id, kad, il_id, ad_soyad, olusturma) values (bakan, 'bakan1', 6, 'Tarım Bakanı Test', '2026-11-01');
  insert into oyun.makamlar(tur, user_id, bakanlik, kaynak, bas) values ('bakan', bakan, 'tarim', 'atama', '2026-11-27 12:00+00');
  perform pg_temp.saat('2026-11-27 12:00:00+00');

  -- komisyon kod seçimi
  raise notice 'Havale: tarım=% savunma=% yol=% sosyal medya=% vergi=%', oyun.kom_sec('serbest', 'Çiftçiye gübre desteği', null), oyun.kom_sec('serbest', 'Bedelli askerlik', null),
    oyun.kom_sec('serbest', 'Otoyol köprü geçiş ücretleri', null), oyun.kom_sec('serbest', 'Sosyal medya düzenlemesi', null), oyun.kom_sec('serbest', 'KDV indirimi', null);
  raise notice 'Komisyon sayısı: %', (select count(*) from oyun.kom_tanim);

  -- yazılı soru önergesi
  perform pg_temp.ben(v[1]);
  x := public.tbmm_soru_ver('tarim', 'Ege kuraklığı', 'Bakanlık, Ege''deki kuraklık için çiftçiye ne tür destek vermeyi planlıyor?', null);
  raise notice 'Soru: %', x;
  perform pg_temp.ben(vat[1]); r := pg_temp.hata('select public.tbmm_soru_ver(''tarim'', ''Deneme konu'', ''Vatandaş soru vermeye çalışıyor burada'', null)'); raise notice 'Vatandaş soru: %', r;
  perform pg_temp.ben(bakan);
  x := public.tbmm_sorular('bana', null);
  raise notice 'Bakana gelen: % · cevaplayabilir=%', jsonb_array_length(x -> 'liste'), x -> 'liste' -> 0 ->> 'cevaplayabilirim';
  x := public.tbmm_soru_cevapla((x -> 'liste' -> 0 ->> 'id')::bigint, 'Kuraklık destek paketi hazırlanmıştır; borçlar bir yıl ertelenecektir.');
  x := public.tbmm_sorular('hepsi', null);
  raise notice 'Karne: %', x -> 'karne';

  -- dilekçe
  perform pg_temp.ben(vat[2]);
  x := public.tbmm_dilekce_ver('Köy yolu bozuk', 'Köyümüzün yolu iki yıldır yapılmıyor, okul servisi gelemiyor. Yardım bekliyoruz.', 'ulastirma');
  raise notice 'Dilekçe: %', x; d := (x ->> 'id')::bigint;
  r := pg_temp.hata('select public.tbmm_dilekce_ver(''İkinci dilekçe'', ''Aynı gün ikinci bir dilekçe vermeyi deniyorum bakalım olacak mı'', null)'); raise notice '48 saat: %', r;
  perform pg_temp.saat('2026-11-30 13:00:00+00');
  raise notice 'Dilekçe tick: % · durum=%', oyun.tbmm_dilekce_tick(oyun.simdi()), (select durum || '/' || bakanlik from oyun.tbmm_dilekce where id = d);

  -- halk buluşması
  perform pg_temp.saat('2026-11-27 12:00:00+00');
  perform pg_temp.ben(v[2]);
  r := pg_temp.hata('select public.hb_planla(''2026-11-27 18:10+00'', ''Akşam buluşması'', null)'); raise notice 'Genel Kurul saatinde: %', r;
  x := public.hb_planla('2026-11-27 13:00+00', 'İzmir esnafıyla buluşma', 'Kira ve vergi sorunlarını konuşalım.');
  hb := (x ->> 'id')::bigint; raise notice 'Buluşma: %', x;
  r := pg_temp.hata('select public.hb_planla(''2026-11-27 15:00+00'', ''İkinci buluşma aynı gün'', null)'); raise notice 'Günde bir: %', r;
  perform pg_temp.ben(vat[1]); x := public.hb_katil(hb); raise notice 'Hatırlat: %', x;
  perform pg_temp.saat('2026-11-27 13:01:00+00');
  x := oyun.hb_tick(oyun.simdi()); raise notice 'Başlangıç: % · bildirim=%', x, (select count(*) from oyun.bildirimler where metin like 'Canlı: İzmir%');
  for i in 1..4 loop perform pg_temp.ben(vat[i]); x := public.hb_katil(hb); x := public.hb_soru_sor(hb, 'Esnafın kira yükü için bir yasa teklifi verecek misiniz? Soru ' || i); end loop;
  perform pg_temp.ben(vat[5]); x := public.hb_soru_begen((select id from oyun.hb_soru where bulusma_id = hb order by id limit 1));
  perform pg_temp.ben(v[2]);
  x := public.hb_detay(hb); raise notice 'Detay: katilim=% soru=% canli=%', x ->> 'katilim', x ->> 'soru', x ->> 'canli';
  q := (x -> 'sorular' -> 0 ->> 'id')::bigint;
  x := public.hb_yanitla(q, 'Evet, önümüzdeki hafta kira artış sınırı için teklif vereceğim.');
  x := public.tbmm_soru_ver('ticaret', 'Esnaf kira yükü', 'Halk buluşmasında vatandaşımızın sorusu: esnafın kira yükü için ne yapılacak?', q);
  raise notice 'Soruya çevrildi: % · vatandaş=%', x, (select vatandas is not null from oyun.bakan_soru where id = (x ->> 'id')::bigint);
  perform pg_temp.saat('2026-11-27 13:40:00+00');
  perform pg_temp.ben(vat[1]); x := public.hb_puanla(hb, 5); perform pg_temp.ben(vat[2]); x := public.hb_puanla(hb, 4);
  perform pg_temp.saat('2026-11-27 13:46:00+00');
  x := oyun.hb_tick(oyun.simdi()); raise notice 'Bitiş: % · haber=%', x, (select baslik || ' | ' || ozet from oyun.ajans_haberleri where kaynak_anahtar = 'hb-' || hb);

  -- karne ve özet
  perform pg_temp.ben(v[2]);
  x := public.tbmm_vekil_karne(null); raise notice 'Karne: puan=% sira=%/% hb=% hb_puan=% soru=%', x ->> 'puan', x ->> 'sira', x ->> 'toplam', x ->> 'hb', x ->> 'hb_puan', x ->> 'soru';
  x := public.tbmm_meclis_siralama(5); raise notice 'Sıralama: %', (select jsonb_agg(z ->> 'ad' || ':' || (z ->> 'puan')) from jsonb_array_elements(x) z);
  x := public.tbmm_ozet(); raise notice 'Özet: %', x -> 'sayilar';
  -- komisyon salonu konuşması (üye değil)
  r := pg_temp.hata('select public.kom_konus(''tarim'', ''Komisyonda konuşmaya çalışıyorum'')'); raise notice 'Üye olmayan komisyon: %', r;
  perform pg_temp.ben(bakan); x := public.kom_konus('tarim', 'Bakanlık olarak kuraklık paketini komisyonun bilgisine sunuyoruz.');
  perform pg_temp.ben(v[3]); x := public.kom_salon('tarim', 0); raise notice 'Komisyon salonu: % satır · yazabilirim=%', jsonb_array_length(x -> 'tutanak'), x ->> 'yazabilirim';
end $t$;
rollback;
