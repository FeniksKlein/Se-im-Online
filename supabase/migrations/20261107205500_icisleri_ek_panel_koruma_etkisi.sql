-- Komuta Merkezi için yetkiye göre sınırlı ekran verisi. Yanlış dosyaların delilleri başka oyunculara açılmaz.
CREATE OR REPLACE FUNCTION public.icisleri_ek_panel() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); bm boolean; hakim boolean;
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
 bm:=oyun.bm_yetki(u,'icisleri') IS NOT NULL;
 hakim:=EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u);
 RETURN jsonb_build_object(
 'bakan',bm,'hakim',hakim,
 'olaylar',COALESCE((SELECT jsonb_agg(jsonb_build_object(
  'id',o.id,'tur',o.tur,'kurum_tur',o.kurum_tur,'kurum_id',o.kurum_id,
  'basvuran',o.basvuran,'basvuran_ad',(SELECT kad FROM oyun.profiller WHERE id=o.basvuran),
  'hedef',o.hedef,'hedef_ad',(SELECT kad FROM oyun.profiller WHERE id=o.hedef),
  'benim',o.basvuran=u,'beni_ilgilendirir',o.hedef=u,
  'baslik',o.baslik,'delil',o.delil,'durum',o.durum,'acilis',o.acilis,
  'bakan_gerekce',o.bakan_gerekce,'savunma',o.savunma,'kapanis_at',o.kapanis_at
  ) ORDER BY o.acilis DESC) FROM
   (SELECT * FROM oyun.icisleri_olay_v2
    WHERE basvuran=u OR hedef=u OR bm OR (hakim AND durum='adliye')
    ORDER BY acilis DESC LIMIT 50) o),'[]'::jsonb),
 'korumalar',COALESCE((SELECT jsonb_agg(jsonb_build_object(
   'id',k.id,'tur',k.tur,'hedef',k.hedef,'hedef_ad',(SELECT kad FROM oyun.profiller WHERE id=k.hedef),
   'benim',k.hedef=u,'gerekce',k.gerekce,'olay_id',k.olay_id,
   'durum',CASE WHEN k.durum='onay' AND k.bitis<=oyun.simdi() THEN 'sona_erdi' ELSE k.durum END,
   'basvuru_at',k.basvuru_at,'karar_gerekce',k.karar_gerekce,'bitis',k.bitis
  ) ORDER BY k.basvuru_at DESC) FROM
   (SELECT * FROM oyun.icisleri_koruma_v2 WHERE bm OR hedef=u ORDER BY basvuru_at DESC LIMIT 35) k),'[]'::jsonb),
 'tedbirler',COALESCE((SELECT jsonb_agg(jsonb_build_object(
   'id',d.id,'olay_id',d.olay_id,'tur',d.tur,'hedef',d.hedef,'hedef_ad',(SELECT kad FROM oyun.profiller WHERE id=d.hedef),
   'bakan',d.bakan,'benim',d.hedef=u,'avukatim',d.avukat=u,
   'gerekce',d.gerekce,'tutar',d.tutar,
   'durum',CASE WHEN d.durum='onay' AND d.bitis<=oyun.simdi() THEN 'sona_erdi' ELSE d.durum END,
   'acilis',d.acilis,'bitis',d.bitis,'hakim',d.hakim,'karar_gerekce',d.karar_gerekce,
   'ifade',d.ifade,'avukat',d.avukat,'avukat_durum',d.avukat_durum,
   'itiraz_metin',d.itiraz_metin,'itiraz_karar',d.itiraz_karar,'inceleme_ozet',d.inceleme_ozet
  ) ORDER BY d.acilis DESC) FROM
   (SELECT * FROM oyun.icisleri_tedbir_v2 d WHERE bm OR hedef=u OR avukat=u OR (hakim AND durum IN ('talep','itiraz'))
    ORDER BY acilis DESC LIMIT 50) d),'[]'::jsonb),
 'avukatlar',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',p.id,'ad',p.kad) ORDER BY p.kad) FROM
   (SELECT r.user_id FROM oyun.avukat_ruhsat r WHERE r.durum='aktif' ORDER BY r.ruhsat_at DESC LIMIT 40) r
   JOIN oyun.profiller p ON p.id=r.user_id WHERE NOT p.yasakli),'[]'::jsonb),
 'oduller',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',o.id,'hedef_ad',(SELECT kad FROM oyun.profiller WHERE id=o.hedef),
   'tur',o.tur,'gerekce',o.gerekce,'para',o.para,'zaman',o.zaman) ORDER BY o.zaman DESC)
   FROM (SELECT * FROM oyun.icisleri_odul_v2 ORDER BY zaman DESC LIMIT 20) o),'[]'::jsonb),
 'anlasmalar',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',a.id,'oyuncu',a.oyuncu,
   'oyuncu_ad',(SELECT kad FROM oyun.profiller WHERE id=a.oyuncu),
   'benim',a.oyuncu=u,'kurum_tur',a.kurum_tur,'kurum_id',a.kurum_id,'tur',a.tur,
   'aciklama',a.aciklama,'durum',CASE WHEN a.durum='teklif' AND a.olusturma<oyun.simdi()-interval '48 hours' THEN 'suresi_doldu' ELSE a.durum END,
   'olusturma',a.olusturma,'cevap_at',a.cevap_at,'rapor',a.rapor,'rapor_at',a.rapor_at,
   'karar_gerekce',a.karar_gerekce,'odeme',a.odeme) ORDER BY a.olusturma DESC)
   FROM (SELECT * FROM oyun.icisleri_anlasma_v2 WHERE bm OR oyuncu=u ORDER BY olusturma DESC LIMIT 40) a),'[]'::jsonb),
 'sorular',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',s.id,'basvuran_ad',(SELECT kad FROM oyun.profiller WHERE id=s.basvuran),
   'karar_id',s.karar_id,'olay_id',s.olay_id,'konu',s.konu,'metin',s.metin,'durum',s.durum,
   'zaman',s.zaman,'yanit',s.yanit,'yanit_at',s.yanit_at) ORDER BY s.zaman DESC)
   FROM (SELECT * FROM oyun.icisleri_sorumluluk_v2 WHERE bm OR basvuran=u ORDER BY zaman DESC LIMIT 40) s),'[]'::jsonb),
 'ozet',jsonb_build_object(
   'acik_ihbar',(SELECT count(*) FROM oyun.icisleri_olay_v2 WHERE durum IN ('ihbar','inceleme','adliye')),
   'mahkeme_bekleyen',(SELECT count(*) FROM oyun.icisleri_tedbir_v2 WHERE durum='talep'),
   'koruma_bekleyen',(SELECT count(*) FROM oyun.icisleri_koruma_v2 WHERE durum='bekliyor'),
   'anlasma_bekleyen',(SELECT count(*) FROM oyun.icisleri_anlasma_v2 WHERE durum='tamamlandi')
 )
 );
END $$;
REVOKE ALL ON FUNCTION public.icisleri_ek_panel() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.icisleri_ek_panel() TO authenticated;

-- Koruma tahsisi: yalnız rastgele protesto gözaltısı seçiminde düşük ihtimal.
-- Bilinçli/delilli adli tedbir veya mahkeme kararında dokunulmazlık sağlamaz.
CREATE OR REPLACE FUNCTION oyun.icisleri_korumali_v2(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM oyun.icisleri_koruma_v2 WHERE hedef=p_user AND durum='onay' AND bitis>oyun.simdi())
$$;
DO $patch$ DECLARE s text;
BEGIN
 s:=pg_get_functiondef('public.sokak_polis_gonder(bigint,text,text)'::regprocedure);
 IF position('oyun.icisleri_korumali_v2' IN s)=0 THEN
  IF position('    order by random() limit hedef_sayisi' IN s)=0 THEN RAISE EXCEPTION 'Polis rastgele gözaltı entegrasyonu bulunamadı'; END IF;
  s:=replace(s,'    order by random() limit hedef_sayisi',
  '    order by random() + CASE WHEN oyun.icisleri_korumali_v2(p.id) THEN 0.65 ELSE 0 END limit hedef_sayisi');
  EXECUTE s;
 END IF;
END $patch$;
REVOKE ALL ON FUNCTION oyun.icisleri_korumali_v2(uuid) FROM PUBLIC,anon,authenticated;
