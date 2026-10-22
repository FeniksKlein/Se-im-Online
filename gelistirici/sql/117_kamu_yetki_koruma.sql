-- 2026-10-22 Kamu atama ve toptan teklif guvenlik duzeltmesi
-- Sadece mevcut RPC tanimlarini daraltir, oyuncu verisini degistirmez.
DO $migrate$
DECLARE f text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO f FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='kamu_kurum_islem';
 IF f IS NULL THEN RAISE EXCEPTION 'Kamu kurum islem RPC eksik';END IF;
 IF strpos(f,'Atamayi teklif eden yonetici artik gorevde degil')=0 THEN
  IF strpos(f, 'IF a.teklif_at+interval ''24 hours''<now()')=0 THEN RAISE EXCEPTION 'Atama sablonu uyusmadi';END IF;
  f:=replace(f,
   'IF a.teklif_at+interval ''24 hours''<now()',
   'IF NOT EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.user_id=a.atayan AND m.bit IS NULL AND ((a.gorev=''belediye_genel_sekreteri'' AND m.tur=''bel'' AND m.il_id=a.il_id) OR (a.gorev<>''belediye_genel_sekreteri'' AND m.tur=''cb''))) THEN RAISE EXCEPTION ''Atamayi teklif eden yonetici artik gorevde degil'';END IF;
  IF a.teklif_at+interval ''24 hours''<now()');
  EXECUTE f;
 END IF;
 SELECT pg_get_functiondef(p.oid) INTO f FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='kamu_toptan_panel';
 IF f IS NULL THEN RAISE EXCEPTION 'Toptan panel RPC eksik';END IF;
 IF strpos(f,'WHERE oyun.sirket_yonetici_mi(alici,u) OR oyun.sirket_yonetici_mi(satici,u)')=0 THEN
  IF strpos(f,'WHERE EXISTS(SELECT 1 FROM oyun.sirket_ortaklari o WHERE o.user_id=u AND o.sirket_id IN (alici,satici))')=0 THEN RAISE EXCEPTION 'Ticaret sablonu uyusmadi';END IF;
  f:=replace(f,
   'WHERE EXISTS(SELECT 1 FROM oyun.sirket_ortaklari o WHERE o.user_id=u AND o.sirket_id IN (alici,satici))',
   'WHERE oyun.sirket_yonetici_mi(alici,u) OR oyun.sirket_yonetici_mi(satici,u) OR EXISTS(SELECT 1 FROM oyun.sirket_ortaklari o WHERE o.user_id=u AND o.sirket_id IN (alici,satici))');
  EXECUTE f;
 END IF;
END $migrate$;