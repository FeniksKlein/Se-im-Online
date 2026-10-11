-- Halka arz ve şirket kartında tek canlı pazar modelini kullan; oyuncu hesaplarına yazma yok.

-- Canlı rekabet piyasasındaki haftalık kârı esas alır; varsayımsal yatırımı veritabanına yazmaz.
CREATE OR REPLACE FUNCTION oyun.halka_arz_net_tahmin(p_sirket bigint, p_ek_sermaye numeric DEFAULT 0)
RETURNS numeric LANGUAGE plpgsql STABLE SET search_path TO '' AS $forecast$
DECLARE s oyun.sirketler; v jsonb; ps oyun.pazar_sirket; k oyun.pazar_sektor;
  yeni_sermaye numeric; yeni_gelir numeric; yeni_gider numeric; eski_personel numeric;
  yeni_personel numeric; talep numeric; diger_gider numeric; ceza numeric; ruhsat numeric; brut numeric; v_kurumlar numeric;
BEGIN
  SELECT * INTO s FROM oyun.sirketler WHERE id=p_sirket AND aktif;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Şirket bulunamadı'; END IF;
  yeni_sermaye := s.sermaye+greatest(0,coalesce(p_ek_sermaye,0));
  v := oyun.pazar_tahmin(p_sirket);
  IF v IS NULL THEN
    RETURN oyun.sirket_ort_net(yeni_sermaye,s.sektor);
  END IF;
  -- İlk tutar, şirket yönetimi ekranındaki 7 günlük canlı pazar tahminiyle bire bir aynıdır.
  IF coalesce(p_ek_sermaye,0)<=0 THEN RETURN (v->>'net')::numeric; END IF;
  SELECT * INTO ps FROM oyun.pazar_sirket WHERE sirket_id=p_sirket;
  SELECT * INTO k FROM oyun.pazar_sektor WHERE kod=s.sektor;
  -- Talep mevcut fiyat, rakip ve şehir şartlarına dayanır; yatırım kapasiteyi yükseltebilir.
  talep := (v->>'pazar')::numeric * (v->>'pay')::numeric / 100 * oyun.pazar_fiyat_katsayi(ps.fiyat);
  yeni_gelir := least(talep,yeni_sermaye*k.kapasite);
  eski_personel := (v->>'personel')::numeric;
  yeni_personel := eski_personel *
    power(greatest(.5,yeni_sermaye/400000)/greatest(.5,s.sermaye/400000),.7);
  diger_gider := greatest(0,(v->>'gider')::numeric-eski_personel)*yeni_sermaye/nullif(s.sermaye,0);
  yeni_gider := yeni_personel+diger_gider;
  ceza := CASE WHEN (v->>'ceza')::numeric>0 THEN yeni_gelir*.12 ELSE 0 END;
  ruhsat := yeni_gelir * (v->>'ruhsat_oran')::numeric/100;
  brut := yeni_gelir-yeni_gider-ruhsat-ceza;
  SELECT kurumlar INTO v_kurumlar FROM oyun.pazar_ayar WHERE id=1;
  RETURN round(brut-greatest(0,brut)*coalesce(v_kurumlar,0)/100);
END $forecast$;
REVOKE ALL ON FUNCTION oyun.halka_arz_net_tahmin(bigint,numeric) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.halka_arz_durum(p_sirket bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); s oyun.sirketler; d record;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  perform oyun.halka_arz_tick();
  select * into s from oyun.sirketler where id = p_sirket and aktif;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  select * into d from oyun.halka_arz_deger_sinir(s.sermaye, s.sektor);
  return jsonb_build_object(
    'id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sermaye', s.sermaye, 'kasa', s.kasa, 'halka_acik', s.halka_acik,
    'payim', coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), 0),
    'kar_kasada', coalesce((select kar_kasada from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), false),
    'asgari_ucret', (select asgari from oyun.ulke where id = 1),
    'ort_net', oyun.halka_arz_net_tahmin(s.id, 0),
    'deger_en_az', d.en_az, 'deger_en_cok', d.en_cok, 'deger_onerilen', d.onerilen,
    'en_fazla_tutar', least(100000000 - s.sermaye, floor(d.en_cok * 49 / 51)),
    'acik', (select oyun.halka_arz_json(a, u) from oyun.halka_arz a where a.sirket_id = s.id and a.durum = 'acik'),
    'gecmis', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.bas desc)
                        from (select * from oyun.halka_arz where sirket_id = s.id and durum <> 'acik' order by bas desc limit 5) a), '[]'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION public.halka_arz_hesapla(p_sirket bigint, p_tutar numeric, p_deger numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); s oyun.sirketler; d record; v_deger numeric; v_tutar numeric; post numeric; benim numeric; once numeric; sonra numeric;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  select * into s from oyun.sirketler where id = p_sirket and aktif;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  select * into d from oyun.halka_arz_deger_sinir(s.sermaye, s.sektor);
  v_tutar := greatest(0, round(coalesce(p_tutar, 0)));
  v_deger := least(d.en_cok, greatest(d.en_az, round(coalesce(p_deger, d.onerilen))));
  post := v_deger + v_tutar;
  benim := coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), 0);
  once := oyun.halka_arz_net_tahmin(s.id, 0);
  sonra := oyun.halka_arz_net_tahmin(s.id, v_tutar);
  return jsonb_build_object(
    'sirket', s.ad, 'sektor', s.sektor, 'sermaye', s.sermaye, 'yeni_sermaye', s.sermaye + v_tutar,
    'yatirim', v_tutar, 'deger', v_deger, 'deger_en_az', d.en_az, 'deger_en_cok', d.en_cok, 'deger_onerilen', d.onerilen,
    'asgari_ucret', (select asgari from oyun.ulke where id = 1),
    'ort_net_simdi', once, 'ort_net_sonra', sonra, 'ort_net_artis', sonra - once,
    'yatirimci_payi', round(v_tutar / post * 100, 2),
    'benim_payim_simdi', round(benim, 2), 'benim_payim_sonra', round(benim * v_deger / post, 2),
    'benim_haftalik_simdi', round(greatest(once, 0) * benim / 100), 'benim_haftalik_sonra', round(greatest(sonra, 0) * benim * v_deger / post / 100),
    'yatirimci_haftalik', round(greatest(sonra, 0) * v_tutar / post),
    'yatirimci_geri_donus_hafta', case when sonra > 0 and v_tutar > 0 then ceil(v_tutar / (sonra * v_tutar / post)) end,
    'sinir_asildi', s.sermaye + v_tutar > 100000000 or (v_tutar > 0 and v_tutar / post > .49));
end $function$;

CREATE OR REPLACE FUNCTION oyun.halka_arz_json(a oyun.halka_arz, u uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'id', a.id, 'sirket_id', a.sirket_id, 'sirket', s.ad, 'sektor', s.sektor,
    'baslatan', (select kad from oyun.profiller where id = a.baslatan), 'ben_baslattim', a.baslatan = u,
    'deger', a.deger, 'hedef', a.hedef, 'asgari', a.asgari, 'toplanan', a.toplanan,
    'bas', a.bas, 'bit', a.bit, 'durum', a.durum, 'sonuc_zaman', a.sonuc_zaman, 'aciklama', a.aciklama,
    'sermaye', s.sermaye, 'kasa', s.kasa,
    'satilan_pay_hedef', round(a.hedef / (a.deger + a.hedef) * 100, 2),
    'pay_fiyati_1', round((a.deger + a.hedef) / 100, 2),
    'ort_net_simdi', oyun.halka_arz_net_tahmin(s.id, 0),
    'ort_net_hedef', oyun.halka_arz_net_tahmin(s.id, case when a.durum = 'acik' then a.hedef else 0 end),
    'yatirimci', (select count(*) from oyun.halka_arz_talep h where h.arz_id = a.id),
    'talebim', coalesce((select h.tutar from oyun.halka_arz_talep h where h.arz_id = a.id and h.user_id = u), 0),
    'ortaklar', coalesce((select jsonb_agg(jsonb_build_object('kad', p.kad, 'pay', round(o.pay, 2)) order by o.pay desc)
                  from oyun.sirket_ortaklari o join oyun.profiller p on p.id = o.user_id where o.sirket_id = s.id), '[]'::jsonb))
  from oyun.sirketler s where s.id = a.sirket_id
$function$;
