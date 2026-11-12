-- 200 (12.11.2026) NPC şirket kârı: 20:00 Türkiye saati sonraki ödeme takvimi düzeltmesi.
-- Kâr miktarı, önceki ödeme kayıtları ve kasa bakiyesi değiştirilmez.
CREATE OR REPLACE FUNCTION oyun.npc_kar_dagitim_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_yerel timestamp := now() AT TIME ZONE 'Europe/Istanbul';
  v_kesim timestamptz := ((now() AT TIME ZONE 'Europe/Istanbul')::date::timestamp + interval '20 hours') AT TIME ZONE 'Europe/Istanbul';
  s record; d oyun.npc_kar_dagitim_durum; o record;
  v_satis numeric; v_bakim numeric; v_bakiye numeric;
  v_pay_limit numeric; v_odenen numeric; v_odeme numeric; v_n integer:=0;
BEGIN
  -- NPC stores use the local 20:00 profit cutoff. Keep the company panel
  -- schedule in sync even when there is no distributable profit today.
  IF NOT pg_try_advisory_xact_lock(882772) THEN RETURN 0; END IF;
  UPDATE oyun.sirketler c
     SET sonraki_kazanc = CASE WHEN now() >= v_kesim
                              THEN v_kesim + interval '1 day' ELSE v_kesim END
   WHERE c.aktif
     AND EXISTS (SELECT 1 FROM oyun.npc_urun_katalog n WHERE n.sektor=c.sektor)
     AND c.sonraki_kazanc IS DISTINCT FROM
         (CASE WHEN now() >= v_kesim THEN v_kesim + interval '1 day' ELSE v_kesim END);
  IF extract(hour FROM v_yerel)<20 THEN RETURN 0; END IF;
  FOR s IN
    SELECT c.id,c.ad,c.kasa,c.kurulus
    FROM oyun.sirketler c
    WHERE c.aktif
       AND EXISTS (SELECT 1 FROM oyun.npc_urun_katalog n WHERE n.sektor=c.sektor)
    ORDER BY c.id
  LOOP
    INSERT INTO oyun.npc_kar_dagitim_durum(sirket_id,son_kesim)
    VALUES(s.id,s.kurulus) ON CONFLICT(sirket_id) DO NOTHING;
    SELECT * INTO d FROM oyun.npc_kar_dagitim_durum WHERE sirket_id=s.id FOR UPDATE;
    IF d.son_kesim>=v_kesim THEN CONTINUE; END IF;
    PERFORM 1 FROM oyun.sirketler WHERE id=s.id FOR UPDATE;
    SELECT coalesce(sum(tutar-maliyet-vergi-isletme_gideri),0)
    INTO v_satis FROM oyun.npc_satis_kayit
    WHERE sirket_id=s.id AND zaman>d.son_kesim AND zaman<=v_kesim;
    SELECT coalesce(sum(tutar),0)
    INTO v_bakim FROM oyun.sirket_hareket
    WHERE sirket_id=s.id AND zaman>d.son_kesim AND zaman<=v_kesim
      AND aciklama='NPC mağaza 15 dakikalık personel, enerji ve bakım';
    v_bakiye:=d.biriken_net+v_satis+v_bakim;
    v_pay_limit:=least(greatest(0,v_bakiye),
      greatest(0,(SELECT kasa FROM oyun.sirketler WHERE id=s.id)));
    v_odenen:=0;
    FOR o IN SELECT user_id,pay FROM oyun.sirket_ortaklari
      WHERE sirket_id=s.id AND NOT kar_kasada ORDER BY user_id
    LOOP
      v_odeme:=least(round(v_pay_limit*o.pay/100),greatest(0,v_pay_limit-v_odenen));
      IF v_odeme<=0 THEN CONTINUE; END IF;
      UPDATE oyun.sirketler SET kasa=kasa-v_odeme
      WHERE id=s.id AND kasa>=v_odeme;
      IF NOT FOUND THEN RAISE EXCEPTION 'NPC kâr ödeme bakiyesi yetersiz, şirket %',s.id; END IF;
      PERFORM oyun.para_islem(o.user_id,v_odeme,'sirket',
        format('%s NPC faaliyet dönem kâr payı (%s)',s.ad,to_char(v_kesim AT TIME ZONE 'Europe/Istanbul','DD.MM.YYYY')),
        now());
      INSERT INTO oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
      VALUES(s.id,now(),-v_odeme,'NPC dönem kâr payı ortak ödemesi',0,0,v_odeme);
      v_odenen:=v_odenen+v_odeme;
    END LOOP;
    UPDATE oyun.npc_kar_dagitim_durum SET son_kesim=v_kesim,
      biriken_net=v_bakiye-v_odenen,
      toplam_odenen=toplam_odenen+v_odenen,
      son_odeme=CASE WHEN v_odenen>0 THEN now() ELSE son_odeme END
      WHERE sirket_id=s.id;
    v_n:=v_n+1;
  END LOOP;
  RETURN v_n;
END
$function$
;
