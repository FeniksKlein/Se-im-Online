-- 13 Ekim 2026: Yeni tapu yalnizca muteahhit projesinden alinir.
-- Mevcut eski tapular silinmez; yeni eski-tip olusturma/devir yasaklanir.
-- Uygulama: Supabase secim-online projesinde uygulanmistir; tekrar calistirilabilir.
CREATE OR REPLACE FUNCTION oyun.eski_tapu_yeni_sahip_engelle()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $$
BEGIN
 IF TG_OP='INSERT' OR (TG_OP='UPDATE' AND new.user_id IS DISTINCT FROM old.user_id) THEN
  RAISE EXCEPTION 'Yeni mulk edinimi sadece muteahhitlerin tamamladigi projelerden yapilabilir. Sehir Emlak ve Insaat bolumune git.';
 END IF;
 RETURN new;
END $$;
REVOKE ALL ON FUNCTION oyun.eski_tapu_yeni_sahip_engelle() FROM public,anon,authenticated;
DROP TRIGGER IF EXISTS eski_yatirim_mulk_edinim_kilit ON oyun.yatirim_mulkleri;
CREATE TRIGGER eski_yatirim_mulk_edinim_kilit BEFORE INSERT OR UPDATE OF user_id
ON oyun.yatirim_mulkleri FOR EACH ROW EXECUTE FUNCTION oyun.eski_tapu_yeni_sahip_engelle();
DROP TRIGGER IF EXISTS eski_mulk_edinim_kilit ON oyun.mulkler;
CREATE TRIGGER eski_mulk_edinim_kilit BEFORE INSERT OR UPDATE OF user_id
ON oyun.mulkler FOR EACH ROW EXECUTE FUNCTION oyun.eski_tapu_yeni_sahip_engelle();

CREATE OR REPLACE FUNCTION public.mulk_il_satin_al(p_tip text,p_il integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 RAISE EXCEPTION 'Belediyeden hazir daire/dukkan/villa satisi kapandi. Yeni gayrimenkuller sadece muteahhitlerin tamamladigi projelerden satin alinabilir.';
END $$;
CREATE OR REPLACE FUNCTION public.mulk_satin_al(p_tip text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 RAISE EXCEPTION 'Hazir gayrimenkul alimi kapandi. Sehir Emlak ve Insaat bolumundeki muteahhit projelerini incele.';
END $$;
CREATE OR REPLACE FUNCTION public.mulk_ilan_satin_al(p_ilan bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 RAISE EXCEPTION 'Eski emlak pazari kapandi. Yeni tapular yalnizca muteahhit projelerinden alinabilir.';
END $$;
CREATE OR REPLACE FUNCTION public.mulk_ilan_ver(p_mulk bigint,p_fiyat numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 RAISE EXCEPTION 'Eski emlak ilani acilamiyor. Yeni gayrimenkul arzini muteahhitler olusturur.';
END $$;
CREATE OR REPLACE FUNCTION oyun._emlak_pazarlik_tamamla(p_teklif bigint,p_fiyat numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 RAISE EXCEPTION 'Eski gayrimenkul pazarligiyla tapu devri kapandi. Yeni tapular muteahhit projelerinden alinir.';
END $$;
CREATE OR REPLACE FUNCTION public.arsa_teklif(p_ihale bigint,p_tutar numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 RAISE EXCEPTION 'Eski arsa ihaleleri kapandi. Imarli belediye arsalari sadece muteahhitlik sirketlerince satin alinir.';
END $$;
CREATE OR REPLACE FUNCTION oyun.arsa_ihale_ac(p_il smallint,p oyun.profiller,t timestamptz)
RETURNS bigint LANGUAGE plpgsql SET search_path TO '' AS $$
BEGIN
 RAISE EXCEPTION 'Eski arsa ihale sistemi kapandi. Belediye arsalari Sehir Emlak ve Insaat ekranindan muteahhitlere satilir.';
END $$;
CREATE OR REPLACE FUNCTION public.mulk_il_stok()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
 SELECT '[]'::jsonb
$$;
CREATE OR REPLACE FUNCTION public.mulk_pazar()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
 SELECT jsonb_build_object('ilanlar','[]'::jsonb)
$$;
-- Ihaleyi iptal ederken en yuksek teklif tutarinin teminati tam iade edilir.
ALTER TABLE oyun.arsa_ihale DROP CONSTRAINT IF EXISTS arsa_ihale_durum_check;
ALTER TABLE oyun.arsa_ihale ADD CONSTRAINT arsa_ihale_durum_check
CHECK(durum IN ('acik','satildi','satilamadi','iptal'));
DO $$
DECLARE a oyun.arsa_ihale;
BEGIN
 FOR a IN SELECT * FROM oyun.arsa_ihale WHERE durum='acik' FOR UPDATE LOOP
  IF a.en_yuksek_user IS NOT NULL AND COALESCE(a.en_yuksek,0)>0 THEN
   PERFORM oyun.para_islem(a.en_yuksek_user,a.en_yuksek,'ihale_iade',
    'Eski arsa ihale sistemi kapandigi icin tam teminat iadesi',oyun.simdi());
   PERFORM oyun.bildir(a.en_yuksek_user,
    'Eski arsa ihalen iptal edildi. Yatirdigin teklif teminatinin tamami cuzdanina iade edildi.',oyun.simdi());
  END IF;
  UPDATE oyun.arsa_ihale SET durum='iptal' WHERE id=a.id;
 END LOOP;
 UPDATE oyun.emlak_pazarlik SET durum='iptal',sonuc_at=oyun.simdi()
 WHERE durum IN ('bekliyor','karsi');
END $$;
