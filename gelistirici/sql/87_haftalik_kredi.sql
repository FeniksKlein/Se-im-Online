-- 11.10.2026 / Gelire dayali krediler, 1-4 haftalik vadeler
-- Mevcut kredi bakiyeleri ve vadeleri DEGISTIRILMEZ.
-- Islem cercevesi gelistirici/build/sql_birlestir.js tarafindan yonetilir.
ALTER TABLE oyun.krediler DROP CONSTRAINT IF EXISTS krediler_gun_check;
ALTER TABLE oyun.krediler ADD CONSTRAINT krediler_gun_check CHECK (gun IN (7,14,15,21,28,30));
ALTER TABLE oyun.oyb_kredi DROP CONSTRAINT IF EXISTS oyb_kredi_saat_check;
ALTER TABLE oyun.oyb_kredi ADD CONSTRAINT oyb_kredi_saat_check CHECK (saat IN (1,3,6,12,24,168,336,504,672));
CREATE OR REPLACE FUNCTION oyun.kredi_risk_ozeti(p_user uuid, p_saat integer)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = ''
AS $fn$
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
    IF p_user IS NULL OR p_saat IS NULL OR p_saat NOT IN (1,3,6,12,24,168,336,360,504,672,720) THEN
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

    -- Kar: son 28 gunluk GEREKCELI isletme hareketleri; pay oranina gore, haftaya cevrilir.
    SELECT coalesce(sum(greatest(0,net_28_gun)*ortak_pay),0)/4*0.40
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
        WHEN notu<900 THEN .35
        WHEN notu<1100 THEN .50
        WHEN notu<1500 THEN .70
        WHEN notu<1700 THEN .85
        ELSE 1 END;

    -- 1-24 saatlik kredi vadeleri icin gelir vade ile orantilidir;
    -- boylece kisa vadeye gercekci olmayacak buyuk kredi verilmez.
    -- DTI: en fazla haftalik duzenli gelirin %40'i borc servisine ayrilir.
    -- Nakit bir krediyi tek basina hak ettirmez, sadece gelir varsa teminata destek olur.
    mevcut_kapasite := greatest(0,
        haftalik_gelir * p_saat / 168 * 0.40
        + least(nakit * 0.10, haftalik_gelir * p_saat / 168 * 0.10)
        - devlet_gunluk_borc * p_saat / 24 - vadedeki_ozel_borc);
    IF haftalik_gelir < 1000 THEN mevcut_kapasite := 0; END IF;
    -- %20 faiz tamponu ve kredi notu katsayisi; 100 TL adim.
    limit_tl := greatest(0,least(500000,
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
END $fn$;
CREATE OR REPLACE FUNCTION public.kredi_uygunluk(p_banka bigint DEFAULT NULL,p_saat integer DEFAULT 24)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
    u uuid := auth.uid();
    risk jsonb;
    bank oyun.sirketler;
    faiz numeric;
    limit_tl numeric;
BEGIN
    IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
    risk := oyun.kredi_risk_ozeti(u,p_saat);
    limit_tl := (risk->>'azami_kredi')::numeric;
    IF p_banka IS NULL THEN
        -- Devlet bankasindaki mevcut statut/puan tavanini da korur.
        limit_tl := least(limit_tl,oyun.kredi_limiti(u));
        faiz := oyun.kredi_orani(u)*p_saat/720;
    ELSE
        IF p_saat NOT IN (1,3,6,12,24,168,336,504,672) THEN
            RAISE EXCEPTION 'Gecersiz oyuncu banka vadesi';
        END IF;
        SELECT * INTO bank FROM oyun.sirketler
         WHERE id=p_banka AND sektor='banka' AND aktif;
        IF NOT FOUND THEN RAISE EXCEPTION 'Banka bulunamadi'; END IF;
        IF EXISTS(SELECT 1 FROM oyun.sirket_ortaklari
           WHERE sirket_id=p_banka AND user_id=u AND pay>0) THEN
            limit_tl:=0;
            risk:=risk||jsonb_build_object('neden','Kendi bankandan kredi alamazsin');
        END IF;
        limit_tl:=least(limit_tl,
            coalesce((oyun.oyb_saglik(p_banka)->>'kredi_verilebilir')::numeric,0));
        -- Kredi notu yuksekse dusuk faiz, riskli profilse yuksek faiz.
        faiz:=round(least(19.50,
            least(bank.banka_kredi_faiz,1.0)
            * CASE WHEN p_saat>=168 THEN 7 + 2*(p_saat/168-1)
                   ELSE p_saat/24.0 END
            * CASE WHEN (risk->>'kredi_notu')::integer<900 THEN 1.5
                   WHEN (risk->>'kredi_notu')::integer<1100 THEN 1.35
                   WHEN (risk->>'kredi_notu')::integer<1500 THEN 1.15
                   WHEN (risk->>'kredi_notu')::integer<1700 THEN 1.00
                   ELSE .90 END
            + CASE WHEN p_saat>=168 THEN (p_saat/168-1)*.50 ELSE 0 END),2);
    END IF;
    limit_tl:=greatest(0,floor(limit_tl/100)*100);
    RETURN risk||jsonb_build_object('azami_kredi',limit_tl,
       'uygun',limit_tl>=1000,'oran',faiz,'banka_id',p_banka);
END $fn$;
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
    IF p_saat NOT IN (1,3,6,12,24,168,336,504,672) OR p_saat IS NULL THEN
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
    RETURN jsonb_build_object('id',yeni_id,'anapara',p_tutar,'toplam',toplam,
        'oran',faiz,'saat',p_saat,'durum','basvuru',
        'kredi_notu',risk->'kredi_notu','azami_kredi',risk->'azami_kredi');
END $fn$;
CREATE OR REPLACE FUNCTION public.kredi_cek(p_miktar numeric,p_gun integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'oyun','public','pg_temp'
AS $fn$
DECLARE
    p oyun.profiller:=oyun.profilim();
    t timestamptz:=oyun.simdi();
    m numeric:=round(coalesce(p_miktar,0));
    mu oyun.banka_musteri;
    lim numeric;
    oran numeric;
    top numeric;
    tak numeric;
    risk jsonb;
BEGIN
    PERFORM oyun.banka_acik_mi();
    IF oyun.uyari(p,t) IS NOT NULL THEN
        RAISE EXCEPTION 'Kredi icin secmen kartin hazir olmali: %',oyun.uyari(p,t);
    END IF;
    IF EXISTS(SELECT 1 FROM oyun.krediler
        WHERE user_id=p.id AND durum IN ('aktif','takip')) THEN
        RAISE EXCEPTION 'Odenmemis kredin var. Once onu kapatmalisin';
    END IF;
    mu:=oyun.musteri(p.id,t);
    IF mu.kara_liste>t THEN
        RAISE EXCEPTION 'Takibe dusen kredin nedeniyle su anda kredi alamazsin';
    END IF;
    IF mu.kredi_notu<700 THEN
        RAISE EXCEPTION 'Kredi notun cok dusuk (%)',mu.kredi_notu;
    END IF;
    IF p_gun NOT IN (7,14,15,21,28,30) THEN
        RAISE EXCEPTION 'Vade 1, 2, 3, 4 hafta olabilir (eski 15/30 gun vadeler desteklenir)';
    END IF;
    risk:=oyun.kredi_risk_ozeti(p.id,p_gun*24);
    lim:=least(oyun.kredi_limiti(p.id),(risk->>'azami_kredi')::numeric);
    IF m<1000 THEN RAISE EXCEPTION 'En az 1.000 TL kredi cekebilirsin'; END IF;
    IF m>lim THEN
        RAISE EXCEPTION 'Gelir/butce/not durumuna gore bu vadede kredi limitin % TL. %',
           lim,risk->>'neden';
    END IF;
    oran:=oyun.kredi_orani(p.id);
    top:=round(m*(1+oran/100*p_gun/30+
        case when p_gun in (7,14,21,28) then .0025*(p_gun/7-1) else 0 end));
    tak:=ceil(top/p_gun);
    INSERT INTO oyun.krediler(user_id,anapara,oran,gun,toplam,taksit,kalan,acilis)
    VALUES(p.id,m,oran,p_gun,top,tak,top,t);
    PERFORM oyun.para_islem(p.id,m,'kredi',
       format('Kredi kullanildi: %s gun vade, aylik %%%s faiz',p_gun,replace(oran::text,'.',',')),t);
    PERFORM oyun.banka_kayit(p.id,'kredi',top,
       format('%s TL kredi (geri odeme %s TL, gunluk %s TL x %s gun)',
         oyun.tl(m),oyun.tl(top),oyun.tl(tak),p_gun),t);
    PERFORM oyun.bildir(p.id,
       format('Kredin hesabina gecti: %s TL. Yarin itibaren her gece %s TL taksit (%s gun).',
         oyun.tl(m),oyun.tl(tak),p_gun),t);
    RETURN public.banka();
END $fn$;
CREATE OR REPLACE FUNCTION public.banka()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE
    p oyun.profiller:=oyun.profilim();
    j jsonb;
    vv jsonb;
    risk7 jsonb;
    risk14 jsonb;
    risk15 jsonb;
    risk21 jsonb;
    risk28 jsonb;
    risk30 jsonb;
    gercek_limit numeric;
BEGIN
    j:=oyun.banka_json(p,oyun.simdi());
    risk7:=oyun.kredi_risk_ozeti(p.id,168);
    risk14:=oyun.kredi_risk_ozeti(p.id,336);
    risk15:=oyun.kredi_risk_ozeti(p.id,360);
    risk21:=oyun.kredi_risk_ozeti(p.id,504);
    risk28:=oyun.kredi_risk_ozeti(p.id,672);
    risk30:=oyun.kredi_risk_ozeti(p.id,720);
    gercek_limit:=least(coalesce((j->>'kredi_limit')::numeric,0),
        greatest((risk7->>'azami_kredi')::numeric,
                 (risk14->>'azami_kredi')::numeric,
                 (risk15->>'azami_kredi')::numeric,
                 (risk21->>'azami_kredi')::numeric,
                 (risk28->>'azami_kredi')::numeric,
                 (risk30->>'azami_kredi')::numeric));
    j:=j||jsonb_build_object('kredi_limit',greatest(0,gercek_limit),
      'kredi_butce',jsonb_build_object('vade7',risk7,'vade14',risk14,'vade15',risk15,'vade21',risk21,'vade28',risk28,'vade30',risk30));
    j:=jsonb_set(j,'{vadesiz}',coalesce(j->'vadesiz','{}'::jsonb)
        ||jsonb_build_object('saatlik',0,'gunluk',0,'birikmis',0,'faiz_toplam',0),true);
    SELECT coalesce(jsonb_agg(x||CASE WHEN x?'saatlik' THEN '{}'::jsonb
      ELSE jsonb_build_object('saatlik',0) END),'[]'::jsonb)
      INTO vv FROM jsonb_array_elements(coalesce(j->'vadeliler','[]'::jsonb)) x;
    RETURN jsonb_set(j,'{vadeliler}',vv,true);
END $fn$;
REVOKE EXECUTE ON FUNCTION oyun.kredi_risk_ozeti(uuid,integer) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.kredi_uygunluk(bigint,integer),
  public.oyb_kredi_basvur(bigint,numeric,integer),
  public.kredi_cek(numeric,integer),public.banka() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.kredi_uygunluk(bigint,integer),
  public.oyb_kredi_basvur(bigint,numeric,integer),
  public.kredi_cek(numeric,integer),public.banka() TO authenticated;