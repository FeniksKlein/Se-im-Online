-- Halka arz değerleme bandını şirketin yaşayan haftalık net pazar kârı üzerinden oluştur.
CREATE OR REPLACE FUNCTION oyun.halka_arz_deger_sinir_sirket(p_sirket bigint,
 OUT en_az numeric, OUT en_cok numeric, OUT onerilen numeric)
RETURNS record LANGUAGE plpgsql STABLE SET search_path TO '' AS $deger$
DECLARE s oyun.sirketler; net numeric;
BEGIN
 SELECT * INTO s FROM oyun.sirketler WHERE id=p_sirket AND aktif;
 IF s.id IS NULL THEN RAISE EXCEPTION 'Şirket bulunamadı'; END IF;
 net:=greatest(0,oyun.halka_arz_net_tahmin(p_sirket,0));
 en_az:=s.sermaye;
 en_cok:=least(500000000,greatest(s.sermaye*2,52*net));
 onerilen:=least(en_cok,greatest(s.sermaye,26*net));
END $deger$;

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
  select * into d from oyun.halka_arz_deger_sinir_sirket(s.id);
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
  select * into d from oyun.halka_arz_deger_sinir_sirket(s.id);
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

CREATE OR REPLACE FUNCTION public.halka_arz_baslat(p_sirket bigint, p_hedef numeric, p_deger numeric, p_asgari numeric DEFAULT NULL::numeric, p_saat integer DEFAULT 72)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); s oyun.sirketler; d record; t timestamptz := oyun.simdi(); v_asgari numeric; v_id bigint;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu hesabı gerekli'; end if;
  perform pg_advisory_xact_lock(98763, hashtext(p_sirket::text));
  select * into s from oyun.sirketler where id = p_sirket and aktif for update;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  if not exists (select 1 from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u and pay >= 50) then
    raise exception 'Halka arzı yalnız şirketin en az %%50''sine sahip ortak başlatabilir'; end if;
  if exists (select 1 from oyun.halka_arz where sirket_id = s.id and durum = 'acik') then raise exception 'Bu şirketin zaten açık bir halka arzı var'; end if;
  if p_hedef is null or p_hedef <> round(p_hedef) or p_hedef < 10000 then raise exception 'Halka arz tutarı en az 10.000 ₺ ve tam sayı olmalı'; end if;
  if s.sermaye + p_hedef > 100000000 then raise exception 'Halka arz sonrası sermaye 100.000.000 ₺''yi aşamaz (en fazla % ₺ toplanabilir)', oyun.tl(100000000 - s.sermaye); end if;
  select * into d from oyun.halka_arz_deger_sinir_sirket(s.id);
  if p_deger is null or p_deger <> round(p_deger) or p_deger < d.en_az or p_deger > d.en_cok then
    raise exception 'Şirket değeri % ₺ ile % ₺ arasında olmalı', oyun.tl(d.en_az), oyun.tl(d.en_cok); end if;
  if p_hedef / (p_deger + p_hedef) > .49 then
    raise exception 'Halka arzda şirketin en fazla %%49''u satılabilir. Bu değerle en fazla % ₺ toplayabilirsin', oyun.tl(floor(p_deger * 49 / 51)); end if;
  v_asgari := coalesce(round(p_asgari), round(p_hedef / 2));
  if v_asgari < 10000 or v_asgari > p_hedef then raise exception 'Asgari tutar 10.000 ₺ ile hedef tutar arasında olmalı'; end if;
  if p_saat not in (24, 48, 72) then raise exception 'Talep süresi 24, 48 ya da 72 saat olmalı'; end if;
  update oyun.sirketler set satilik = null where id = s.id;
  insert into oyun.halka_arz(sirket_id, baslatan, deger, hedef, asgari, bas, bit)
    values (s.id, u, p_deger, p_hedef, v_asgari, t, t + make_interval(hours => p_saat)) returning id into v_id;
  perform oyun.olay('ekonomi', format('%s halka arz ediliyor: %s ₺ hedef, şirketin %%%s''i satışta. Talep toplama %s saat sürecek.',
    s.ad, oyun.tl(p_hedef), round(p_hedef / (p_deger + p_hedef) * 100, 2), p_saat), null, null, t);
  return oyun.halka_arz_json((select a from oyun.halka_arz a where a.id = v_id), u);
end $function$;
