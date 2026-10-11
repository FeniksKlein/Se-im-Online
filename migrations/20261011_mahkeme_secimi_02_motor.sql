CREATE OR REPLACE FUNCTION oyun.mahkeme_toplu_tick(t timestamptz DEFAULT oyun.simdi())
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE h record; s oyun.mahkeme_toplu_secim; r record; k int:=2; atan jsonb:='[]'::jsonb; siralama jsonb:='[]'::jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtext('oyun.mahkeme_toplu_tick'));
 -- Seçimler sadece 12 Ekim genel seçiminden oluşan yeni TBMM Başkanı seçilince açılır.
 SELECT b.id AS baskan_secim,g.id AS mv_id INTO h
 FROM oyun.meclis_secim b JOIN oyun.secimler g ON g.id=b.mv_secim_id
 WHERE b.tur='baskan' AND b.durum='bitti' AND g.tur='mv'
   AND (g.oy_bas AT TIME ZONE 'Europe/Istanbul')::date=date '2026-10-12'
   AND EXISTS (SELECT 1 FROM oyun.makamlar m
      WHERE m.tur='tbmm' AND m.bit IS NULL AND m.bas>=g.goreve_bas)
 ORDER BY b.id DESC LIMIT 1;
 IF h.baskan_secim IS NULL THEN RETURN; END IF;
 INSERT INTO oyun.mahkeme_toplu_secim(mv_secim_id,meclis_secim_id,bas,aday_bit,oy_bas,oy_bit)
 VALUES(h.mv_id,h.baskan_secim,t,t+interval '45 minutes',
        t+interval '45 minutes',t+interval '135 minutes')
 ON CONFLICT(mv_secim_id) DO NOTHING;
 IF FOUND THEN
   PERFORM oyun.olay('adliye','Yüksek Mahkeme için iki üyelik adaylığı başladı. Başvurular 45 dakika boyunca Adliye ekranında açık.',null,null,t);
   INSERT INTO oyun.bildirimler(user_id,zaman,metin)
   SELECT pr.id,t,'Yüksek Mahkeme üyeliği için adaylık başladı! 45 dakika içinde Adliye bölümünden başvurabilirsin.'
   FROM oyun.profiller pr WHERE oyun.yargic_uygunluk(pr.id) IS NULL;
 END IF;
 SELECT * INTO s FROM oyun.mahkeme_toplu_secim WHERE mv_secim_id=h.mv_id FOR UPDATE;
 IF s.durum='aday' AND t>=s.aday_bit THEN
   UPDATE oyun.mahkeme_toplu_secim SET durum='oylama' WHERE id=s.id;
   s.durum:='oylama';
   INSERT INTO oyun.bildirimler(user_id,zaman,metin)
   SELECT DISTINCT m.user_id,t,'Yüksek Mahkeme için 2 üyelik oylama başladı. Adliye bölümünde oyunuzu kullanın.'
   FROM oyun.makamlar m WHERE m.tur='mv' AND m.bit IS NULL;
 END IF;
 IF s.durum='oylama' AND t>=s.oy_bit THEN
   -- Her vekil en fazla 1 tercih yapar; oylar bitiş saatinde sayılır.
   FOR r IN
    SELECT a.user_id,a.zaman,count(DISTINCT o.vekil)::int AS oy
    FROM oyun.mahkeme_toplu_aday a
    JOIN oyun.mahkeme_toplu_oy o ON o.secim_id=a.secim_id AND o.aday=a.user_id
    JOIN oyun.makamlar m ON m.user_id=o.vekil AND m.tur='mv' AND m.bit IS NULL
    WHERE a.secim_id=s.id AND oyun.yargic_uygunluk(a.user_id) IS NULL
    GROUP BY a.user_id,a.zaman HAVING count(DISTINCT o.vekil)>0
    ORDER BY count(DISTINCT o.vekil) DESC,a.zaman,a.user_id
    LIMIT 2
   LOOP
    WHILE k<=3 AND EXISTS(SELECT 1 FROM oyun.mahkeme_uye u WHERE u.sira=k AND u.user_id IS NOT NULL)
    LOOP k:=k+1; END LOOP;
    EXIT WHEN k>3;
    PERFORM oyun.mahkeme_oturt(k::smallint,r.user_id,null,s.oy_bit);
    atan:=atan||jsonb_build_array(jsonb_build_object('kad',oyun.kad(r.user_id),'oy',r.oy,'sira',k));
    k:=k+1;
   END LOOP;
   SELECT coalesce(jsonb_agg(jsonb_build_object('kad',oyun.kad(a.user_id),'oy',
     (SELECT count(*) FROM oyun.mahkeme_toplu_oy o WHERE o.secim_id=s.id AND o.aday=a.user_id))
     ORDER BY (SELECT count(*) FROM oyun.mahkeme_toplu_oy o WHERE o.secim_id=s.id AND o.aday=a.user_id) DESC,a.zaman),
     '[]'::jsonb) INTO siralama
   FROM oyun.mahkeme_toplu_aday a WHERE a.secim_id=s.id;
   UPDATE oyun.mahkeme_toplu_secim SET durum='bitti',
    sonuc=jsonb_build_object('siralamalar',siralama,'atananlar',atan) WHERE id=s.id;
   PERFORM oyun.olay('adliye',format('Yüksek Mahkeme seçimi tamamlandı: %s üye atandı.',jsonb_array_length(atan)),null,null,t);
 END IF;
END $$;