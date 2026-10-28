-- Kredi uygunluk: gercek borc servisi, zararlar ve nedenler.
-- Mevcut kredi/kart kayitlarini veya oyuncu varliklarini degistirmez.

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
END $function$
;

CREATE OR REPLACE FUNCTION oyun.oyb_kredi_limit(u uuid, p_saat integer)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $function$
DECLARE
  risk jsonb;
  card_debt numeric := 0;
  card_limit numeric := 0;
  overdue_min numeric := 0;
  required_payment numeric := 0;
  gross numeric := 0;
  final_limit numeric := 0;
  note text;
BEGIN
  risk := oyun.kredi_risk_ozeti(u, least(720, greatest(1, p_saat)));
  SELECT coalesce(sum(greatest(0, coalesce(borc, 0))),0),
         coalesce(sum(greatest(0, coalesce(limit_tl,0))),0),
         coalesce(sum(greatest(0, coalesce(gecikmis_asgari,0))),0)
    INTO card_debt, card_limit, overdue_min
    FROM oyun.kredi_kartlari
   WHERE user_id=u AND durum NOT IN ('kapali','iptal');

  gross := greatest(0, coalesce((risk->>'azami_kredi')::numeric, 0));
  -- Kullanilmayan kart limiti borc degildir. Sadece kullanilmis borcun
  -- vade boyunca ongorulen %25 aylik asgari servis yuku dikkate alinir.
  required_payment := greatest(overdue_min,
      card_debt * 0.25 * least(1.0, greatest(0,p_saat)::numeric / 720));
  final_limit := greatest(0, floor((gross - required_payment)/100)*100);
  note := risk->>'neden';
  IF overdue_min > 0 THEN
    final_limit := 0;
    note := 'Kredi kartinda gecikmis asgari odeme bulunuyor';
  ELSIF gross >= 1000 AND final_limit < 1000 THEN
    note := 'Kullanilmis kredi karti borcunun odeme yuku nedeniyle yeni kredi limiti kalmadi';
  ELSIF gross >= 1000 AND final_limit > 0 THEN
    note := 'Gelir, mevcut borclar ve kredi notu uygun';
  END IF;
  RETURN risk || jsonb_build_object(
    'azami_kredi', final_limit,
    'uygun', final_limit >= 1000,
    'neden', note,
    'tum_bankalarda_kart_borcu', card_debt,
    'tum_bankalarda_kart_limitleri', card_limit,
    'kart_borcu_vade_odeme_yuku', round(required_payment,2),
    'kart_gecikmis_asgari', overdue_min,
    'kart_riski_sonrasi_kredi', final_limit
  );
END
$function$;

CREATE OR REPLACE FUNCTION public.oyb_kredi_masasi(p_banka bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; yon boolean; r jsonb; sag jsonb; notu integer;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif;
  if s.id is null then raise exception 'Banka bulunamadı.'; end if;
  -- süresi dolan teklifler
  update oyun.oyb_kredi_teklifi set durum = 'suresi' where banka_id = p_banka and durum = 'teklif' and son <= t;
  yon := oyun.oyb_yonetici(p_banka, u);
  sag := oyun.oyb_saglik(p_banka);
  select coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100) into notu;
  r := jsonb_build_object(
    'banka', jsonb_build_object('id', s.id, 'ad', s.ad, 'kasa', oyun.kasa_goster('sirket', s.id, s.kasa), 'kredi_verilebilir', oyun.kasa_goster('sirket', s.id, greatest(0, (sag->>'kredi_verilebilir')::numeric))),
    'yonetebilir', yon,
    'ortak', exists(select 1 from oyun.sirket_ortaklari where sirket_id = p_banka and user_id = u and pay > 0),
    'hesap', (select jsonb_build_object('acilis', h.acilis) from oyun.oyb_hesap h where h.banka_id = p_banka and h.user_id = u and h.kapanis is null),
    'kredi_notu', notu, 'not_ad', oyun.not_ad(notu),
    'baska_kredi', exists(select 1 from oyun.oyb_kredi where borclu = u and durum in ('basvuru','aktif')),
    'paketler', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'ad', p.ad, 'vade_gun', p.vade_gun, 'taksit_sayisi', p.taksit_sayisi,
        'faiz', p.faiz, 'min_tutar', p.min_tutar, 'max_tutar', p.max_tutar, 'otomatik', p.otomatik, 'min_not', p.min_not, 'aktif', p.aktif,
        'limitim', least(p.max_tutar,
            coalesce((oyun.oyb_kredi_limit(u, p.vade_gun * 24)->>'azami_kredi')::numeric,0),
            greatest(0,coalesce((sag->>'kredi_verilebilir')::numeric,0))),
        'engel', case
          when not oyun.oyb_hesap_acik(p_banka,u) then 'Kredi icin once bu bankada hesap acmalisin.'
          when exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=p_banka and o.user_id=u and o.pay>0) then 'Kendi bankandan kredi cekemezsin.'
          when exists(select 1 from oyun.oyb_kredi k where k.borclu=u and k.durum in ('basvuru','aktif')) then 'Baska aktif kredin ya da bekleyen basvurun bulunuyor.'
          when notu<p.min_not then format('Bu paket icin gereken kredi notu %s, seninki %s.',p.min_not,notu)
          when (oyun.oyb_kredi_limit(u,p.vade_gun*24)->>'azami_kredi')::numeric < p.min_tutar
            then format('Bu vade icin kredi kapasiten %s, paketin alt siniri %s.',
                oyun.tl(coalesce((oyun.oyb_kredi_limit(u,p.vade_gun*24)->>'azami_kredi')::numeric,0)),
                oyun.tl(p.min_tutar))
          when coalesce((sag->>'kredi_verilebilir')::numeric,0)<p.min_tutar then 'Banka rezervleri bu paketin asgari kredisini karsilamiyor.'
          else null end) order by p.vade_gun, p.id)
      from oyun.oyb_kredi_paket p where p.banka_id = p_banka and p.silindi_at is null and (p.aktif or yon)), '[]'),
    'tekliflerim', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tutar', x.tutar, 'vade_gun', x.vade_gun, 'taksit_sayisi', x.taksit_sayisi,
        'faiz', x.faiz, 'mesaj', x.mesaj, 'son', x.son, 'plan', oyun.oyb_plan(x.tutar, x.vade_gun, x.taksit_sayisi, x.faiz, t)) order by x.id desc)
      from oyun.oyb_kredi_teklifi x where x.banka_id = p_banka and x.user_id = u and x.durum = 'teklif'), '[]'),
    'bilgi_talebi', (select jsonb_build_object('istenen', b.istenen, 'izinli', b.izinli, 'durum', b.durum, 'istek_at', b.istek_at)
      from oyun.oyb_hesap_bilgi b where b.banka_id = p_banka and b.user_id = u),
    'kredilerim', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'anapara', k.anapara, 'toplam', k.toplam, 'kalan', k.kalan, 'oran', k.oran,
        'vade_gun', round(k.saat / 24.0, 1), 'durum', case when k.durum = 'aktif' and exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t) then 'gecikmis' else k.durum end,
        'acilis', k.acilis, 'vade', k.vade, 'erken_kapama', oyun.oyb_erken_kapama_tutari(k, t), 'erken_kapandi', k.erken_kapama, 'erken_indirim', k.erken_indirim,
        'icra', (select i.durum from oyun.oyb_icra i where i.kredi_id = k.id),
        'taksitler', coalesce((select jsonb_agg(jsonb_build_object('sira', x.sira, 'vade', x.vade, 'tutar', x.tutar, 'odenen', x.odenen) order by x.sira)
          from oyun.oyb_kredi_taksit x where x.kredi_id = k.id), '[]')) order by k.id desc)
      from (select * from oyun.oyb_kredi where banka_id = p_banka and borclu = u order by id desc limit 10) k), '[]'));
  if yon then
    r := r || jsonb_build_object(
      'saglik', sag,
      'hesaplar', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(h.user_id), 'acilis', h.acilis,
          'kredi_notu', coalesce(bm.kredi_notu, 1100),
          'borc', (select coalesce(sum(k.kalan), 0) from oyun.oyb_kredi k where k.banka_id = p_banka and k.borclu = h.user_id and k.durum = 'aktif'),
          'aktif_kredi', exists(select 1 from oyun.oyb_kredi k where k.borclu = h.user_id and k.durum in ('basvuru','aktif')),
          'bilgi', (select jsonb_build_object('durum', b.durum, 'istenen', b.istenen, 'izinli', b.izinli) from oyun.oyb_hesap_bilgi b where b.banka_id = p_banka and b.user_id = h.user_id),
          'teklif', (select jsonb_build_object('id', x.id, 'tutar', x.tutar, 'son', x.son) from oyun.oyb_kredi_teklifi x where x.banka_id = p_banka and x.user_id = h.user_id and x.durum = 'teklif' limit 1))
          order by h.acilis desc)
        from oyun.oyb_hesap h left join oyun.banka_musteri bm on bm.user_id = h.user_id
        where h.banka_id = p_banka and h.kapanis is null and h.user_id <> u), '[]'),
      'banka_kredileri', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'borclu', oyun.kad(k.borclu), 'anapara', k.anapara, 'toplam', k.toplam,
          'kalan', k.kalan, 'oran', k.oran, 'vade_gun', round(k.saat / 24.0, 1), 'durum', k.durum, 'acilis', k.acilis, 'vade', k.vade,
          'kaynak', case when k.paket_id is not null then 'paket' when k.teklif_id is not null then 'teklif' else 'basvuru' end,
          'geciken', (select coalesce(sum(x.tutar - x.odenen), 0) from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t),
          'dava_acilabilir', k.durum = 'aktif' and exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade + interval '12 hours' <= t)
            and not exists(select 1 from oyun.oyb_icra i where i.kredi_id = k.id),
          'icra', (select jsonb_build_object('id', i.id, 'durum', i.durum, 'tur', i.tur) from oyun.oyb_icra i where i.kredi_id = k.id),
          'risk', case when k.durum = 'basvuru' then oyun.oyb_kredi_limit(k.borclu, k.saat) end) order by (k.durum = 'basvuru') desc, k.id desc)
        from (select * from oyun.oyb_kredi where banka_id = p_banka and durum in ('basvuru','aktif') order by id desc limit 60) k), '[]'),
      'gonderilen_teklifler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kad', oyun.kad(x.user_id), 'tutar', x.tutar, 'vade_gun', x.vade_gun,
          'taksit_sayisi', x.taksit_sayisi, 'faiz', x.faiz, 'durum', x.durum, 'son', x.son) order by x.id desc)
        from (select * from oyun.oyb_kredi_teklifi where banka_id = p_banka order by id desc limit 20) x), '[]'));
  end if;
  return r;
end $function$
;
