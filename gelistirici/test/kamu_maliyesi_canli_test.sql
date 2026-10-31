-- Kamu Maliyesi 2.0 (modül 158) — canlı veritabanında GERİ ALINAN deneme.
-- Kullanım: modülün (sql/158_kamu_maliyesi.sql) hemen ardından aynı sorguda çalıştırılır;
-- son satırdaki hata bütün işlemi geri alır ve sonuçları mesaj olarak döndürür.
-- (Deneme sırasında oyun.yedek_al yerine geçici bir taklit kullanılabilir.)
do $t$
declare r jsonb := '{}'; cb uuid := oyun.yurutme_user(); h0 numeric; h1 numeric; x jsonb; e text; son_id bigint; enf0 numeric; u oyun.ulke;
begin
  r := r || jsonb_build_object('hazine_sonra', round((select hazine from oyun.ulke where id = 1), 3),
                               'fon', round((select bakiye from oyun.varlik_fonu where id = 1), 3), 'cb_var', cb is not null,
                               'devir', (select jsonb_agg(jsonb_build_object('fark', round(fark, 2), 'kalem', kalem, 'kaynak', kaynak)) from (select * from oyun.hazine_hareketleri order by id desc limit 1) z));
  if cb is not null then
    perform set_config('request.jwt.claim.sub', cb::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', cb, 'role', 'authenticated')::text, true);
  end if;

  -- 1) Kararnameyle ek ödenek: Hazine düşmeli, kalem ek_odenek
  begin
    h0 := (select hazine from oyun.ulke where id = 1);
    x := public.kararname_cikar('odenek', null, 'Deneme', '{"bakanlik":"egitim","miktar":5}'::jsonb);
    h1 := (select hazine from oyun.ulke where id = 1);
    r := r || jsonb_build_object('t1_odenek_fark', round(h1 - h0, 3),
      't1_kayit', (select jsonb_build_object('kalem', kalem, 'kaynak', kaynak, 'aciklama', aciklama) from oyun.hazine_hareketleri order by id desc limit 1));
  exception when others then r := r || jsonb_build_object('t1_hata', sqlerrm); end;

  -- 2) Varlık Fonu'ndan çekim
  begin
    h0 := (select hazine from oyun.ulke where id = 1);
    x := public.varlik_fonu_aktar('cek', 10, 'Deneme');
    h1 := (select hazine from oyun.ulke where id = 1);
    r := r || jsonb_build_object('t2_cek_fark', round(h1 - h0, 3), 't2_kalan_hak', x -> 'varlik_fonu' -> 'kalan_hak');
  exception when others then r := r || jsonb_build_object('t2_hata', sqlerrm); end;
  begin
    x := public.varlik_fonu_aktar('cek', 5, 'Deneme 2');
    r := r || jsonb_build_object('t2b', 'beklenmedik: ikinci aktarım geçti');
  exception when others then r := r || jsonb_build_object('t2b_beklenen_hata', sqlerrm); end;

  -- 3) Rapor
  begin
    x := public.butce_raporu(7);
    r := r || jsonb_build_object('t3_rapor_anahtar', (select jsonb_agg(k) from jsonb_object_keys(x) k), 't3_ozet', x -> 'ozet',
                                 't3_gelirler', x -> 'gelirler', 't3_giderler', x -> 'giderler', 't3_finansman', x -> 'finansman');
  exception when others then r := r || jsonb_build_object('t3_hata', sqlerrm); end;

  -- 4) Takdire bağlı harcama Hazine'yi eksiye düşüremez
  begin
    perform oyun.hazine_kaydet('diger_gider', -((select hazine from oyun.ulke where id = 1) - 2), 'deneme');
    x := public.kararname_cikar('il_destek', null, 'Deneme', '{"il_id":35,"miktar":5}'::jsonb);
    r := r || jsonb_build_object('t4', 'beklenmedik: eksiye düşürdü');
  exception when others then r := r || jsonb_build_object('t4_beklenen_hata', sqlerrm); end;
  -- Hazine'yi eski hâline getir (geri alınacak zaten)
  perform oyun.hazine_kaydet('diger_gelir', 1100 - (select hazine from oyun.ulke where id = 1), 'deneme');

  -- 5) Günlük ekonomi: dünü tam gün say, bir gün işlet
  begin
    update oyun.makro_ayar set baslangic = oyun.simdi() - interval '5 days' where id = 1;
    update oyun.ulke set son_gun = (oyun.simdi() at time zone 'Europe/Istanbul')::date - 1 where id = 1;
    select * into u from oyun.ulke where id = 1; enf0 := u.enflasyon;
    son_id := (select max(id) from oyun.hazine_hareketleri);
    perform oyun.gunluk_ekonomi(oyun.simdi());
    r := r || jsonb_build_object('t5_kayitlar', (select jsonb_agg(jsonb_build_object('kalem', kalem, 'fark', round(fark, 3), 'ac', aciklama) order by id) from oyun.hazine_hareketleri where id > son_id),
      't5_makro', (select to_jsonb(m) from oyun.makro_gunluk m order by gun desc limit 1),
      't5_enf', jsonb_build_object('once', round(enf0, 3), 'sonra', round((select enflasyon from oyun.ulke where id = 1), 3)),
      't5_hazine', round((select hazine from oyun.ulke where id = 1), 3),
      't5_tahvil_faiz', oyun.tahvil_faiz(), 't5_risk', oyun.mali_risk_primi());
  exception when others then get stacked diagnostics e = pg_exception_context; r := r || jsonb_build_object('t5_hata', sqlerrm, 't5_yer', e); end;

  -- 6) Masa (yurutme_butce_masasi) maliye bloğu
  begin
    x := public.yurutme_butce_masasi();
    r := r || jsonb_build_object('t6_maliye', x -> 'maliye' -> 'bugun');
  exception when others then r := r || jsonb_build_object('t6_hata', sqlerrm); end;

  -- 7) Statik denetim (plpgsql_check)
  begin
    r := r || jsonb_build_object('t7_plpgsql_check', coalesce((select jsonb_agg(f || ': ' || coalesce(c.message, '')) from
       unnest(array['oyun.gunluk_ekonomi(timestamptz)', 'oyun.makro_hesap(date,oyun.ulke)', 'oyun.hazine_kalem_coz(numeric,text)',
                    'oyun.maliye_ozet()', 'public.butce_raporu(integer)', 'public.varlik_fonu_aktar(text,numeric,text)', 'oyun.maliye_uyari(date,timestamptz)',
                    'oyun.varlik_fonu_getiri(date)', 'oyun.hazine_kaydet(text,numeric,text)', 'public.kararname_cikar(text,text,text,jsonb)',
                    'public.yurutme_butce_masasi()', 'public.kriz_karar_ver(bigint,text)']) f
       cross join lateral (select * from plpgsql_check_function_tb(f::regprocedure) z where z.level = 'error') c), '[]'::jsonb),
      't7_tetik', coalesce((select jsonb_agg(c.message) from plpgsql_check_function_tb('oyun.tg_hazine_harcama_siniri()'::regprocedure, 'oyun.ulke'::regclass) c where c.level = 'error'), '[]'::jsonb)
             || coalesce((select jsonb_agg(c.message) from plpgsql_check_function_tb('oyun.tg_hazine_hareket()'::regprocedure, 'oyun.ulke'::regclass) c where c.level = 'error'), '[]'::jsonb));
  exception when others then r := r || jsonb_build_object('t7_hata', sqlerrm); end;

  raise exception 'TEST_SONUC %', r::text;
end $t$;
