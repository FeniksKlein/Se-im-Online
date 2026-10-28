-- Seçim Online kredi kolaylastirma paketi, 2026-10-28
-- Gecikme/kara liste, var olan borclar ve banka likiditesi korunur.
-- Kredi gelir/puan carpanlari ve devlet bankasi ust limiti iyilestirilir.
CREATE OR REPLACE FUNCTION oyun.kredi_risk_ozeti(p_user uuid, p_saat integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE
    t timestamptz := oyun.simdi();
    gelir_json jsonb;
    notu integer := 1100;
    kara_liste timestamptz;
    gecikmis integer := 0;
    maas7 numeric := 0;
    kira7 numeric := 0;
    sirket7 numeric := 0;
    nakit numeric := 0;
    devlet_gunluk_borc numeric := 0;
    vadedeki_ozel_borc numeric := 0;
    haftalik_gelir numeric := 0;
    mevcut_kapasite numeric := 0;
    puan_katsayisi numeric := 0;
    limit_tl numeric := 0;
    aciklama text := 'Gelir ve kredi notu uygun';
BEGIN
    IF p_user IS NULL OR p_saat IS NULL OR p_saat NOT BETWEEN 1 AND 720 THEN
        RAISE EXCEPTION 'Gecersiz kullanici veya kredi vadesi';
    END IF;
    SELECT coalesce(b.kredi_notu,1100), b.kara_liste
      INTO notu, kara_liste
      FROM oyun.banka_musteri b WHERE b.user_id=p_user;
    notu := coalesce(notu,1100);

    SELECT greatest(0, coalesce(c.para,0)+coalesce(b.vadesiz,0))
      INTO nakit
      FROM oyun.cuzdan c
      LEFT JOIN oyun.banka_musteri b ON b.user_id=c.user_id
     WHERE c.user_id=p_user;
    nakit := coalesce(nakit,0);

    gelir_json := oyun.gelir_hesap(p_user,t);
    maas7 := greatest(0,coalesce((gelir_json->>'gunluk_net')::numeric,0))*7*0.70;
    SELECT coalesce(sum(greatest(0,haftalik_kira)),0)*0.80
      INTO kira7
      FROM oyun.yatirim_mulkleri WHERE user_id=p_user;

    -- Son 28 gunluk faaliyet gelir/gider dengesi. Zarar eden sirketlerin paya dusen zarari da risk hesabinda mahsuplasir.
    SELECT greatest(0,coalesce(sum(net_28_gun*ortak_pay),0))/4*0.40
      INTO sirket7
      FROM (
        SELECT o.sirket_id,
               o.pay/100 AS ortak_pay,
               coalesce(sum(coalesce(h.faaliyet_gelir,0)-coalesce(h.faaliyet_gider,0)),0) AS net_28_gun
          FROM oyun.sirket_ortaklari o
          JOIN oyun.sirketler s ON s.id=o.sirket_id AND s.aktif AND s.sektor<>'banka'
          LEFT JOIN oyun.sirket_hareket h
            ON h.sirket_id=s.id AND h.zaman>=t-interval '28 days'
         WHERE o.user_id=p_user AND o.pay>0
         GROUP BY o.sirket_id,o.pay
      ) x;

    haftalik_gelir := round(maas7+kira7+sirket7,2);

    SELECT coalesce(sum(k.taksit),0)
      INTO devlet_gunluk_borc
      FROM oyun.krediler k
     WHERE k.user_id=p_user AND k.durum IN ('aktif','takip');

    SELECT coalesce(sum(k.kalan) FILTER (WHERE k.vade<=t+make_interval(hours=>p_saat)),0),
           count(*) FILTER (WHERE k.vade<t)
      INTO vadedeki_ozel_borc,gecikmis
      FROM oyun.oyb_kredi k
     WHERE k.borclu=p_user AND k.durum='aktif';

    puan_katsayisi := CASE
        WHEN notu<700 THEN 0
        WHEN notu<900 THEN .50
        WHEN notu<1100 THEN .70
        WHEN notu<1500 THEN .85
        WHEN notu<1700 THEN .95
        ELSE 1 END;

    -- 1-24 saatlik kredi vadeleri icin gelir vade ile orantilidir;
    -- boylece kisa vadeye gercekci olmayacak buyuk kredi verilmez.
    -- DTI: en fazla haftalik duzenli gelirin %60'i borc servisine ayrilir.
    -- Nakit bir krediyi tek basina hak ettirmez, sadece gelir varsa teminata destek olur.
    mevcut_kapasite := greatest(0,
        haftalik_gelir * p_saat / 168 * 0.60
        + least(nakit * 0.10, haftalik_gelir * p_saat / 168 * 0.10)
        - devlet_gunluk_borc * p_saat / 24 - vadedeki_ozel_borc);
    IF haftalik_gelir < 500 THEN mevcut_kapasite := 0; END IF;
    -- %20 faiz tamponu ve kredi notu katsayisi; 100 TL adim.
    limit_tl := greatest(0,least(2000000,
        floor(mevcut_kapasite * puan_katsayisi / 1.20 / 100)*100));

    IF notu<700 THEN
        aciklama:='Kredi notu 700 altinda';limit_tl:=0;
    ELSIF kara_liste>t THEN
        aciklama:='Kara liste suresi devam ediyor';limit_tl:=0;
    ELSIF gecikmis>0 THEN
        aciklama:='Vadesi gecen oyuncu bankasi kredisi var';limit_tl:=0;
    ELSIF EXISTS (
        SELECT 1 FROM oyun.krediler WHERE user_id=p_user AND durum='takip'
    ) THEN
        aciklama:='Yasal takipte devlet bankasi kredisi var';limit_tl:=0;
    ELSIF limit_tl<1000 THEN
        aciklama:='Gelir ve kullanilabilir butce yetersiz';
    END IF;

    RETURN jsonb_build_object(
        'kredi_notu',notu,'not_ad',oyun.not_ad(notu),
        'haftalik_maas',round(maas7,2),
        'haftalik_kira',round(kira7,2),
        'haftalik_sirket',round(sirket7,2),
        'haftalik_gelir',haftalik_gelir,
        'nakit',round(nakit,2),
        'devlet_gunluk_taksit',round(devlet_gunluk_borc,2),
        'bu_vadede_ozel_borc',round(vadedeki_ozel_borc,2),
        'azami_kredi',limit_tl,
        'uygun',limit_tl>=1000,
        'neden',aciklama,
        'vade_saat',p_saat
    );
END $function$
;
CREATE OR REPLACE FUNCTION oyun.kredi_limiti(u uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select floor(1.50 * ul.asgari * (array[0.5, 1, 1.5, 2, 3, 4])[oyun.statu_basamak(oyun.kidem_puani(u)) + 1]
               * case when exists (select 1 from oyun.makamlar where user_id = u and bit is null) then 1.5 else 1 end
               * oyun.not_limit_kat(coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100)) / 100) * 100
  from oyun.ulke ul where ul.id = 1
$function$
;
-- Yalniz aktif paketlerde tek seferlik asgari tutar, not ve max limit reformu.
-- Kredi faizleri, vade, onay ayarlari, pasif urunler ve mevcut krediler degismez.
UPDATE oyun.oyb_kredi_paket
SET min_tutar = greatest(1000, floor(min_tutar * 0.50 / 1000) * 1000),
    max_tutar = least(2000000, ceil(max_tutar * 2.0 / 1000) * 1000),
    min_not = case when min_not=0 then 0 else greatest(800, min_not-200) end
WHERE aktif AND silindi_at IS NULL;
