BEGIN;
CREATE OR REPLACE FUNCTION public.oyb_kredi_basvur(p_banka bigint,p_tutar numeric,p_saat integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
    u uuid:=auth.uid();
    bank oyun.sirketler;
    risk jsonb;
    faiz numeric;
    toplam numeric;
    yeni_id bigint;
BEGIN
    IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
    IF p_tutar IS NULL OR p_tutar<>trunc(p_tutar) OR p_tutar<1000 OR p_tutar>500000 THEN
        RAISE EXCEPTION 'Kredi 1.000 - 500.000 TL arasinda tam TL olmali';
    END IF;
    IF p_saat NOT IN (1,3,6,12,24,72,168,336,504,672) OR p_saat IS NULL THEN
        RAISE EXCEPTION 'Vade saatlik veya 1, 2, 3, 4 haftalik olabilir';
    END IF;
    SELECT * INTO bank FROM oyun.sirketler
      WHERE id=p_banka AND aktif AND sektor='banka';
    IF NOT FOUND THEN RAISE EXCEPTION 'Banka bulunamadi'; END IF;
    IF EXISTS(SELECT 1 FROM oyun.sirket_ortaklari
      WHERE sirket_id=p_banka AND user_id=u AND pay>0) THEN
        RAISE EXCEPTION 'Kendi bankandan kredi alamazsin';
    END IF;
    IF EXISTS(SELECT 1 FROM oyun.oyb_kredi
      WHERE borclu=u AND durum IN ('basvuru','aktif')) THEN
        RAISE EXCEPTION 'Once diger oyuncu bankasi kredini kapat veya yanitini bekle';
    END IF;

    risk:=public.kredi_uygunluk(p_banka,p_saat);
    IF p_tutar>(risk->>'azami_kredi')::numeric THEN
        RAISE EXCEPTION 'Kredi reddedildi: %. Azami limit % TL; notun %.',
          risk->>'neden',risk->>'azami_kredi',risk->>'kredi_notu';
    END IF;
    faiz:=(risk->>'oran')::numeric;
    toplam:=round(p_tutar*(1+faiz/100));
    INSERT INTO oyun.oyb_kredi(banka_id,borclu,anapara,saat,oran,toplam,kalan)
    VALUES(p_banka,u,p_tutar,p_saat,faiz,toplam,toplam) RETURNING id INTO yeni_id;
    RETURN (SELECT jsonb_build_object('id',k.id,'anapara',k.anapara,'toplam',k.toplam,
        'oran',k.oran,'saat',k.saat,'durum',k.durum,'taksit_sayisi',k.taksit_sayisi,
        'kredi_notu',risk->'kredi_notu','azami_kredi',risk->'azami_kredi')
        FROM oyun.oyb_kredi k WHERE k.id=yeni_id);
END $fn$;
COMMIT;