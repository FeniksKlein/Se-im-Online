-- 2026-10-11: Halka arz sonrası hakim ortak sermaye katkısı ve rekabetçi şirketlerin doğru finans tahmini.
-- Mevcut bakiyelere, paylara, şirketlere veya geçmiş faaliyet hareketlerine dokunmaz.

CREATE OR REPLACE FUNCTION public.sirket_sermaye_artir(p_sirket bigint, p_tutar numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'oyun', 'public', 'pg_temp'
AS $body$
DECLARE
  u uuid := auth.uid();
  s oyun.sirketler;
  t timestamptz := oyun.simdi();
  v_pay numeric;
BEGIN
  IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
  PERFORM oyun.sirket_hesapla(p_sirket);
  SELECT * INTO s FROM oyun.sirketler WHERE id=p_sirket AND aktif FOR UPDATE;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Aktif şirket bulunamadı'; END IF;
  SELECT pay INTO v_pay FROM oyun.sirket_ortaklari WHERE sirket_id=p_sirket AND user_id=u;
  -- Halka arz yapan hakim ortak yönetimi kaybetmeden ek sermaye koyabilir.
  -- Bu işlemin bedelini yalnızca işlemi yapan oyuncu öder. Diğer ortakların payları değişmez.
  IF coalesce(v_pay,0) < 50 THEN
    RAISE EXCEPTION 'Sermaye katkısı için şirketin en az %%50 payına sahip olmalısın';
  END IF;
  IF p_tutar IS NULL OR p_tutar<>round(p_tutar)
     OR p_tutar<10000 OR p_tutar>10000000 OR s.sermaye+p_tutar>100000000 THEN
    RAISE EXCEPTION 'Sermaye artışı 10.000-10.000.000 TL olmalı; toplam 100 milyon TL sınırı var';
  END IF;
  PERFORM oyun.para_islem(u,-p_tutar,'sirket','Sirket sermaye katkisi (pay oranlari degismez)',t);
  UPDATE oyun.sirketler SET sermaye=sermaye+p_tutar,kasa=kasa+p_tutar WHERE id=p_sirket;
  INSERT INTO oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
  VALUES(p_sirket,t,p_tutar,'Hakim ortak sermaye katkisi (ortaklik oranlari degismedi)');
  RETURN jsonb_build_object('tamam',true,'yeni_sermaye',s.sermaye+p_tutar,
    'benim_payim',v_pay,'paylar_degisti',false);
END;
$body$;
REVOKE ALL ON FUNCTION public.sirket_sermaye_artir(bigint,numeric) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.sirket_sermaye_artir(bigint,numeric) TO authenticated;

-- Geleneksel şirket ve rekabetçi pazar şirketi farklı motorla kazanç üretir;
-- finans özetinde ikisinin de kendi motorundan hesaplanan tahmini kullanılmalı.
CREATE OR REPLACE FUNCTION public.sirket_finans_ozeti(p_sirket bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $body$
DECLARE
  uid uuid := auth.uid();
  s oyun.sirketler;
  w numeric; r numeric;
  gelir_min numeric; gelir_max numeric; gider_min numeric; gider_max numeric;
  net_min numeric; net_max numeric; net_ort numeric;
  v_tahmin jsonb; v_pazar boolean := false;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Oturum açmalısın'; END IF;
  IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari
    WHERE sirket_id=p_sirket AND user_id=uid AND pay>0) THEN
    RAISE EXCEPTION 'Bu şirketin ortağı değilsin';
  END IF;
  PERFORM oyun.sirket_hesapla(p_sirket);
  SELECT * INTO s FROM oyun.sirketler WHERE id=p_sirket AND aktif;
  IF NOT FOUND THEN RAISE EXCEPTION 'Şirket bulunamadı'; END IF;

  v_pazar := EXISTS(SELECT 1 FROM oyun.pazar_sirket ps
    JOIN oyun.pazar_sektor k ON k.kod=s.sektor WHERE ps.sirket_id=s.id);
  IF v_pazar THEN
    v_tahmin := oyun.pazar_tahmin(s.id);
    gelir_min := (v_tahmin->>'gelir')::numeric;
    gelir_max := gelir_min;
    gider_min := (v_tahmin->>'gider')::numeric
      + (v_tahmin->>'ruhsat')::numeric + (v_tahmin->>'ceza')::numeric
      + (v_tahmin->>'vergi')::numeric;
    gider_max := gider_min;
    net_ort := (v_tahmin->>'net')::numeric;
    net_min := round(least(net_ort*.9,net_ort*1.1));
    net_max := round(greatest(net_ort*.9,net_ort*1.1));
  ELSE
    SELECT asgari INTO w FROM oyun.ulke WHERE id=1;
    r:=CASE s.sektor WHEN 'tarim' THEN .12 WHEN 'sanayi' THEN .15
      WHEN 'teknoloji' THEN .20 WHEN 'ticaret' THEN .14 WHEN 'insaat' THEN .18
      WHEN 'medya' THEN .16 ELSE .08 END;
    gelir_min:=round(s.sermaye*r*.6);
    gelir_max:=round(s.sermaye*r*1.4);
    gider_min:=round(s.sermaye*.025+w*.5);
    gider_max:=round(s.sermaye*.08+w*1.5);
    net_min:=gelir_min-gider_max;
    net_max:=gelir_max-gider_min;
    net_ort:=round(s.sermaye*r-s.sermaye*.0525-w);
  END IF;
  RETURN jsonb_build_object(
    'id',s.id,'ad',s.ad,'sektor',s.sektor,'sermaye',s.sermaye,'kasa',s.kasa,
    'benim_payim',(SELECT pay FROM oyun.sirket_ortaklari
      WHERE sirket_id=s.id AND user_id=uid),
    'sonraki_hesaplama',s.sonraki_kazanc,
    'tahmini_gelir_min',gelir_min,'tahmini_gelir_max',gelir_max,
    'tahmini_gider_min',gider_min,'tahmini_gider_max',gider_max,
    'tahmini_net_min',net_min,'tahmini_net_max',net_max,
    'tahmini_ortalama_net',net_ort,
    'tahmin_kaynagi', CASE WHEN v_pazar THEN 'rekabetci_pazar' ELSE 'klasik' END,
    'pazar_tahmin',v_tahmin,
    'dagitilabilir_kar',greatest(0,s.kasa-s.sermaye-coalesce((
      SELECT sum(round(m.anapara*(1+m.faiz/100)))
      FROM oyun.banka_mevduat m
      WHERE m.banka_id=s.id AND NOT m.kapandi),0)),
    'islemler',coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'tarih',h.zaman,'net',h.tutar,'faaliyet_gelir',h.faaliyet_gelir,
        'faaliyet_gider',h.faaliyet_gider,'dagitilan_kar',h.dagitilan_kar,
        'aciklama',h.aciklama) ORDER BY h.zaman DESC,h.id DESC)
      FROM (SELECT * FROM oyun.sirket_hareket
        WHERE sirket_id=s.id ORDER BY zaman DESC,id DESC LIMIT 12) h
    ),'[]'::jsonb));
END;
$body$;
REVOKE ALL ON FUNCTION public.sirket_finans_ozeti(bigint) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.sirket_finans_ozeti(bigint) TO authenticated;
