-- Belediye hizmet ihalesi hotfix: PL/pgSQL'de kasa degiskeni ile kasa sutunu cakisiyordu.
-- Mevcut ihaleler, teklifler ve oyuncu paralarina toplu dokunulmaz.
CREATE OR REPLACE FUNCTION public.belediye_is_ihale_ac(
    p_baslik text,
    p_aciklama text,
    p_sektor text,
    p_butce numeric,
    p_saat integer DEFAULT 12
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
DECLARE
    v_kullanici uuid := auth.uid();
    v_il smallint;
    v_kasa numeric;
    v_ihale_id bigint;
BEGIN
    PERFORM oyun.profilim();

    SELECT m.il_id INTO v_il
    FROM oyun.makamlar AS m
    WHERE m.tur = 'bel' AND m.bit IS NULL AND m.user_id = v_kullanici
    ORDER BY m.id DESC LIMIT 1;

    IF v_il IS NULL THEN
        RAISE EXCEPTION 'Yalnizca gorevdeki belediye baskani ihale acabilir';
    END IF;
    IF char_length(btrim(coalesce(p_baslik, ''))) NOT BETWEEN 5 AND 120
       OR char_length(coalesce(p_aciklama, '')) > 1200 THEN
        RAISE EXCEPTION 'Baslik/aciklama sinirini kontrol et';
    END IF;
    IF p_sektor IS NULL OR p_sektor NOT IN ('insaat','teknoloji','ticaret','sanayi','tarim','hizmet') THEN
        RAISE EXCEPTION 'Gecerli sektor sec';
    END IF;
    IF p_saat IS NULL OR p_saat NOT IN (6,12,24) THEN
        RAISE EXCEPTION 'Ihale 6, 12 veya 24 saat acik kalabilir';
    END IF;
    IF p_butce IS NULL OR p_butce <> round(p_butce)
       OR p_butce < 100000 OR p_butce > 20000000 THEN
        RAISE EXCEPTION 'Butce 100 bin - 20 milyon TL olmali';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(83119, v_il::integer);
    IF EXISTS (
        SELECT 1 FROM oyun.belediye_is_ihale AS h
        WHERE h.il_id = v_il AND h.durum = 'acik'
    ) THEN
        RAISE EXCEPTION 'Bu belediyenin halen acik bir hizmet ihalesi var';
    END IF;

    SELECT d.kasa INTO v_kasa
    FROM oyun.il_durum AS d
    WHERE d.il_id = v_il FOR UPDATE;

    IF v_kasa IS NULL OR p_butce > v_kasa * 1000000000 * 0.05
       OR v_kasa < p_butce / 1000000000 THEN
        RAISE EXCEPTION 'Ihale butcesi sehir kasasinin en fazla %%5i olabilir';
    END IF;

    UPDATE oyun.il_durum AS d
    SET kasa = d.kasa - p_butce / 1000000000
    WHERE d.il_id = v_il;

    INSERT INTO oyun.belediye_is_ihale
        (il_id, baskan, baslik, aciklama, sektor, butce, teklif_bit)
    VALUES
        (v_il, v_kullanici, btrim(p_baslik), coalesce(p_aciklama, ''),
         p_sektor, p_butce, now() + make_interval(hours => p_saat))
    RETURNING id INTO v_ihale_id;

    RETURN jsonb_build_object('tamam', true, 'ihale_id', v_ihale_id);
END
$function$;

NOTIFY pgrst, 'reload schema';