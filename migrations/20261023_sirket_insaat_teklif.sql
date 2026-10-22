-- 2026-10-23: İnşaata başlamadan tam yapım maliyeti, şirket kasası ve eksik tutar.
-- Sunucudaki eko_emlak_islem ile aynı formülden hesaplanır. Mutasyon yapmaz.
CREATE OR REPLACE FUNCTION public.sirket_insaat_teklif(p_sirket bigint, p_arsa bigint, p_daire integer, p_dukkan integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_u uuid := auth.uid();
 v_arsa oyun.eko_arsalar%ROWTYPE;
 v_sirket oyun.sirketler%ROWTYPE;
 v_baz_daire numeric;
 v_baz_dukkan numeric;
 v_daire_tutari numeric;
 v_dukkan_tutari numeric;
 v_toplam numeric;
 v_maks_dukkan integer;
 v_sure integer;
BEGIN
 IF v_u IS NULL OR NOT EXISTS (SELECT 1 FROM oyun.profiller WHERE id=v_u AND NOT yasakli)
 THEN RAISE EXCEPTION 'Giriş yapmalısın.'; END IF;
 SELECT * INTO v_arsa FROM oyun.eko_arsalar WHERE id=p_arsa;
 IF v_arsa.id IS NULL OR v_arsa.sahibi_sirket IS DISTINCT FROM p_sirket OR v_arsa.durum<>'satildi'
 THEN RAISE EXCEPTION 'Arsa seçili şirkete ait değil.'; END IF;
 SELECT * INTO v_sirket FROM oyun.sirketler WHERE id=p_sirket;
 IF v_sirket.id IS NULL OR NOT v_sirket.aktif
   OR NOT oyun.sirket_yonetici_mi(p_sirket,v_u)
   OR NOT EXISTS (SELECT 1 FROM oyun.eko_isletmeler WHERE sirket_id=p_sirket AND tur='insaat')
 THEN RAISE EXCEPTION 'Bu inşaatın maliyetini görme yetkin yok.'; END IF;
 IF EXISTS (SELECT 1 FROM oyun.eko_yapilar WHERE arsa_id=p_arsa)
 THEN RAISE EXCEPTION 'Bu arsada zaten proje var.'; END IF;
 v_maks_dukkan := greatest(1,ceil(v_arsa.kademe*.3)::integer);
 IF p_daire IS NULL OR p_dukkan IS NULL OR p_daire<0 OR p_dukkan<0
   OR p_daire+p_dukkan<1 OR p_daire+p_dukkan>v_arsa.kademe OR p_dukkan>v_maks_dukkan
 THEN
   RETURN jsonb_build_object(
    'gecerli',false,'uygun',false,'kapasite',v_arsa.kademe,'maks_dukkan',v_maks_dukkan,
    'hata',format('Bu arsada en çok %s bölüm ve %s dükkân yapılabilir. En az 1 bölüm seç.',v_arsa.kademe,v_maks_dukkan)
   );
 END IF;
 -- eko_emlak_islem(insaata_basla) ile birebir aynı tutar; ayrı kalemler toplamı yuvarlama farkı yaratmaz.
 v_baz_daire := oyun.mulk_il_bedel(v_arsa.il_id,'daire');
 v_baz_dukkan := oyun.mulk_il_bedel(v_arsa.il_id,'dukkan');
 v_toplam := round(v_baz_daire*.62*p_daire + v_baz_dukkan*.65*p_dukkan);
 IF v_toplam<=0 THEN RAISE EXCEPTION 'Geçersiz inşaat maliyeti.'; END IF;
 v_daire_tutari := round(v_baz_daire*.62*p_daire);
 v_dukkan_tutari := v_toplam-v_daire_tutari;
 v_sure := CASE WHEN p_daire+p_dukkan<=5 THEN 12 WHEN p_daire+p_dukkan<=10 THEN 24
               WHEN p_daire+p_dukkan<=20 THEN 48 ELSE 96 END;
 RETURN jsonb_build_object(
  'gecerli',true,'uygun',v_sirket.kasa>=v_toplam,
  'sirket',p_sirket,'arsa',p_arsa,'kapasite',v_arsa.kademe,'maks_dukkan',v_maks_dukkan,
  'daire_maliyeti',v_daire_tutari,'dukkan_maliyeti',v_dukkan_tutari,
  'toplam_maliyet',v_toplam,'mevcut_kasa',v_sirket.kasa,
  'eksik',greatest(0,v_toplam-v_sirket.kasa),
  'kalan_kasa',greatest(0,v_sirket.kasa-v_toplam),
  'arsa_alis_bedeli',v_arsa.fiyat,'sure_saat',v_sure
 );
END;
$function$

REVOKE ALL ON FUNCTION public.sirket_insaat_teklif(bigint,bigint,integer,integer) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sirket_insaat_teklif(bigint,bigint,integer,integer) TO authenticated;
