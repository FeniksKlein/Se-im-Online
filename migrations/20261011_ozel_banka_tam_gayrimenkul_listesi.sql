BEGIN;
CREATE OR REPLACE FUNCTION public.oyb_bilgi_dokumu(p_kredi bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE i oyun.oyb_bilgi_izin;k oyun.oyb_kredi;r jsonb:='{}'::jsonb;t timestamptz:=oyun.simdi();
 g jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Oturum gerekli';END IF;
 SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_kredi;
 IF NOT FOUND THEN RAISE EXCEPTION 'Kredi yok'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.sirket_ortaklari WHERE sirket_id=k.banka_id
 AND user_id=auth.uid() AND pay>=50) THEN RAISE EXCEPTION 'Yonetim yetkisi yok';END IF;
 SELECT * INTO i FROM oyun.oyb_bilgi_izin WHERE kredi_id=p_kredi AND durum='izin' AND borclu=k.borclu;
 IF NOT FOUND OR k.durum NOT IN ('basvuru','aktif') THEN RAISE EXCEPTION 'Oyuncu bu bilgiler icin izin vermedi';END IF;
 g:=oyun.gelir_hesap(k.borclu,t);
 IF 'maas'=ANY(i.izinli) THEN r:=r||jsonb_build_object('maas',jsonb_build_object('gunluk_net',g->'gunluk_net',
   'saatlik_maas',g#>'{saatlik,maas}','saatlik_makam',g#>'{saatlik,makam}')); END IF;
 IF 'gunluk'=ANY(i.izinli) THEN r:=r||jsonb_build_object('gunluk',jsonb_build_object('gelir',g->'gunluk_net')); END IF;
 IF 'mulk'=ANY(i.izinli) THEN r:=r||jsonb_build_object('mulk',
  coalesce((SELECT jsonb_agg(jsonb_build_object('id',m.id,'tip',m.tip,'il',m.il_id,
   'alis_bedeli',m.alis_bedeli,'haftalik_kira',m.haftalik_kira) ORDER BY m.id)
  FROM oyun.yatirim_mulkleri m WHERE m.user_id=k.borclu),'[]'::jsonb));END IF;
 IF 'kira'=ANY(i.izinli) THEN r:=r||jsonb_build_object('kira',jsonb_build_object('haftalik',
  (SELECT coalesce(sum(haftalik_kira),0) FROM oyun.yatirim_mulkleri WHERE user_id=k.borclu),
  'gunluk', (SELECT round(coalesce(sum(haftalik_kira),0)/7,2) FROM oyun.yatirim_mulkleri WHERE user_id=k.borclu))); END IF;
 IF 'sirket'=ANY(i.izinli) THEN r:=r||jsonb_build_object('sirket',
  coalesce((SELECT jsonb_agg(jsonb_build_object('sirket_id',s.id,'ad',s.ad,'pay',o.pay,
  'sermaye_pay_degeri',round(s.sermaye*o.pay/100)) ORDER BY s.id)
  FROM oyun.sirket_ortaklari o JOIN oyun.sirketler s ON s.id=o.sirket_id
  WHERE o.user_id=k.borclu AND o.pay>0),'[]'::jsonb));END IF;
 IF 'mulk'=ANY(i.izinli) THEN
  r:=jsonb_set(r,'{mulk}',jsonb_build_object(
   'yatirim_gayrimenkulleri',coalesce(r->'mulk','[]'::jsonb),
   'diger_gayrimenkuller',coalesce((SELECT jsonb_agg(jsonb_build_object(
     'id',m.id,'tip',m.tur,'il',m.il_id,'alis_bedeli',m.bedel,'gunluk_getiri',m.gunluk) ORDER BY m.id)
     FROM oyun.mulkler m WHERE m.user_id=k.borclu),'[]'::jsonb)),true);
 END IF;
 RETURN jsonb_build_object('kredi_id',p_kredi,'izinli',i.izinli,'dokum',r);
END $function$;
COMMIT;