-- Oyuncuların adaylığını ve milletvekili oylarını yalnız RPC üzerinden kabul et.
CREATE OR REPLACE FUNCTION public.mahkeme_toplu_durum()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE p oyun.profiller:=oyun.profilim(); s oyun.mahkeme_toplu_secim;
BEGIN
 IF p.id IS NULL THEN RAISE EXCEPTION 'Önce giriş yapmalısın.'; END IF;
 PERFORM oyun.mahkeme_toplu_tick(oyun.simdi());
 SELECT * INTO s FROM oyun.mahkeme_toplu_secim ORDER BY id DESC LIMIT 1;
 IF s.id IS NULL THEN RETURN jsonb_build_object('durum','bekleniyor','aciklama',
 '13 Ekim, TBMM Başkanı seçildikten sonra 45 dakika adaylık ve 90 dakika oylama yapılır.'); END IF;
 RETURN jsonb_build_object(
 'id',s.id,'durum',s.durum,'aday_bit',s.aday_bit,'oy_bas',s.oy_bas,'oy_bit',s.oy_bit,
 'sonuc',s.sonuc,'vekil_miyim',oyun.aktif_vekil(p.id),
 'adayim',EXISTS(SELECT 1 FROM oyun.mahkeme_toplu_aday a WHERE a.secim_id=s.id AND a.user_id=p.id),
 'aday_olabilirim',oyun.yargic_uygunluk(p.id) IS NULL,'engel',oyun.yargic_uygunluk(p.id),
 'oyum',(SELECT oyun.kad(o.aday) FROM oyun.mahkeme_toplu_oy o WHERE o.secim_id=s.id AND o.vekil=p.id),
 'adaylar',coalesce((SELECT jsonb_agg(jsonb_build_object('id',a.user_id,'kad',oyun.kad(a.user_id),
    'uygun',oyun.yargic_uygunluk(a.user_id) IS NULL,
    'oy',CASE WHEN s.durum='bitti' THEN
       (SELECT count(*) FROM oyun.mahkeme_toplu_oy o WHERE o.secim_id=s.id AND o.aday=a.user_id)
       ELSE NULL END) ORDER BY a.zaman,a.user_id)
    FROM oyun.mahkeme_toplu_aday a WHERE a.secim_id=s.id),'[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.mahkeme_toplu_aday_ol(p_aday boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE p oyun.profiller:=oyun.profilim();s oyun.mahkeme_toplu_secim;
BEGIN
 IF p.id IS NULL THEN RAISE EXCEPTION 'Önce giriş yapmalısın.'; END IF;
 PERFORM oyun.mahkeme_toplu_tick(oyun.simdi());
 SELECT * INTO s FROM oyun.mahkeme_toplu_secim ORDER BY id DESC LIMIT 1;
 IF s.id IS NULL OR s.durum<>'aday' OR oyun.simdi()>=s.aday_bit
 THEN RAISE EXCEPTION 'Yüksek Mahkeme adaylığı henüz açılmadı ya da sona erdi.'; END IF;
 IF p_aday THEN
   IF oyun.yargic_uygunluk(p.id) IS NOT NULL THEN RAISE EXCEPTION '%',oyun.yargic_uygunluk(p.id); END IF;
   INSERT INTO oyun.mahkeme_toplu_aday(secim_id,user_id,zaman)
   VALUES(s.id,p.id,oyun.simdi()) ON CONFLICT DO NOTHING;
   IF NOT FOUND THEN RAISE EXCEPTION 'Zaten adaysın.'; END IF;
 ELSE
   DELETE FROM oyun.mahkeme_toplu_aday WHERE secim_id=s.id AND user_id=p.id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Adaylığın bulunamadı.'; END IF;
 END IF;
 RETURN public.mahkeme_toplu_durum();
END $$;

CREATE OR REPLACE FUNCTION public.mahkeme_toplu_oy_ver(p_aday uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE p oyun.profiller:=oyun.profilim();s oyun.mahkeme_toplu_secim;
BEGIN
 IF p.id IS NULL THEN RAISE EXCEPTION 'Önce giriş yapmalısın.'; END IF;
 PERFORM oyun.mahkeme_toplu_tick(oyun.simdi());
 SELECT * INTO s FROM oyun.mahkeme_toplu_secim ORDER BY id DESC LIMIT 1;
 IF s.id IS NULL OR s.durum<>'oylama' OR oyun.simdi()<s.oy_bas OR oyun.simdi()>=s.oy_bit
 THEN RAISE EXCEPTION 'Yüksek Mahkeme seçim sandığı kapalı.'; END IF;
 IF NOT oyun.aktif_vekil(p.id) THEN RAISE EXCEPTION 'Yalnızca milletvekilleri oy kullanabilir.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.mahkeme_toplu_aday a WHERE a.secim_id=s.id AND a.user_id=p_aday)
    OR oyun.yargic_uygunluk(p_aday) IS NOT NULL
 THEN RAISE EXCEPTION 'Aday bulunamadı veya adaylık şartlarını kaybetti.'; END IF;
 INSERT INTO oyun.mahkeme_toplu_oy(secim_id,vekil,aday,zaman)
 VALUES(s.id,p.id,p_aday,oyun.simdi());
 RETURN public.mahkeme_toplu_durum();
END $$;
REVOKE ALL ON FUNCTION public.mahkeme_toplu_durum() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.mahkeme_toplu_aday_ol(boolean) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.mahkeme_toplu_oy_ver(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION oyun.mahkeme_toplu_tick(timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mahkeme_toplu_durum() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mahkeme_toplu_aday_ol(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mahkeme_toplu_oy_ver(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';