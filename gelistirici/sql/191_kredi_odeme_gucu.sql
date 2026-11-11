-- =====================================================================
--  191 (11.11.2026) · ÖDEME GÜCÜNE GÖRE KREDİ (Ercan: "Kişi de şirket de ödeme gücü varsa istediği kadar
--  kredi çekebilsin, limitler düşük kalmasın")
--  KİŞİ (Devlet bankası):
--   • Statüye bağlı sabit tavan (asgari ücret × statü katsayısı) kalktı. Limit artık ödeme gücüdür:
--       gelir kapasitesi  = haftalık düzenli gelir (maaş, kira, şirket kârı payı) × vade × %60  (eski hesap, aynen)
--       teminat kapasitesi = nakit + vadesiz × %50 + vadeli mevduat (devlet ve oyuncu bankası) × %80
--                            (+ 60 gün ve üzeri vadede: mülk alış bedeli × %50 + şirket paylarının değeri × %30)
--                            − açık kredi borçları
--       limit = (gelir + teminat) × kredi notu katsayısı / 1,2 faiz tamponu; mutlak tavan 250 milyon ₺.
--   • Yeni vadeler: 60, 90, 180, 365 gün (eski 7–30 gün vadeler aynen sürer). Faiz formülü değişmedi.
--   • Değişmeyenler: aynı anda tek devlet kredisi, not < 700 / kara liste / gecikme / takip engelleri, günlük taksit,
--     gecikme cezası ve yasal takip. Oyuncu bankalarının kendi likidite sınırı aynen geçerli; kişi başı 2 milyon
--     mutlak tavanı onlarda da 250 milyona çıktı.
--  ŞİRKET:
--   • İşletme kredisi: şirket, son 28 günlük faaliyet kârı ve varlıkları (stok, arsa, yapı) oranında, 30–365 gün
--     vadeli kredi çekebilir. Para şirket kasasına girer, kimsenin cüzdanına geçmez; taksit 190'daki gibi her gün
--     kasadan. Yıllık faiz politika faizi + 4.
--   • Yatırım kredisindeki "en fazla 3 kredi / 25 milyon" sabit tavanı kalktı; yerine şirketin ödeme gücü geldi.
--   • Kredi parası ortaklara dağıtılamaz: kâr payı, genel kurul temettüsü, tasfiye payı ve ortaklar cari hesabı
--     şirketin kredi borcunu düşerek hesaplanır.
--  Mevcut krediler, bakiyeler ve oyuncu verisi değişmez; yalnız işlev ve CHECK genişletme.
-- =====================================================================

-- 1) Vade CHECK'lerini genişlet (mevcut satırlar zaten içinde)
alter table oyun.krediler drop constraint if exists krediler_gun_check;
alter table oyun.krediler add constraint krediler_gun_check check (gun = any (array[7,14,15,21,28,30,60,90,180,365]));
alter table oyun.yatirim_kredisi drop constraint if exists yatirim_kredisi_vade_gun_check;
alter table oyun.yatirim_kredisi add constraint yatirim_kredisi_vade_gun_check check (vade_gun = any (array[30,60,90,180,365]));

-- 2) Gelir kapasitesi: 1 yıla kadar vade, 250 milyon mutlak tavan (hesap aynen)
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
    IF p_user IS NULL OR p_saat IS NULL OR p_saat NOT BETWEEN 1 AND 8760 THEN
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

    -- DTI: en fazla haftalik duzenli gelirin %60'i borc servisine ayrilir (vade ile orantili).
    mevcut_kapasite := greatest(0,
        haftalik_gelir * p_saat / 168 * 0.60
        + least(nakit * 0.10, haftalik_gelir * p_saat / 168 * 0.10)
        - devlet_gunluk_borc * p_saat / 24 - vadedeki_ozel_borc);
    IF haftalik_gelir < 500 THEN mevcut_kapasite := 0; END IF;
    limit_tl := greatest(0,least(250000000,
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
END $function$;

-- 3) Kişinin teminat gücü
create or replace function oyun.kredi_teminat(p_user uuid) returns jsonb
language sql stable set search_path = '' as $$
  with v as (
    select
      coalesce((select greatest(0, coalesce(c.para, 0)) from oyun.cuzdan c where c.user_id = p_user), 0)
        + coalesce((select greatest(0, coalesce(b.vadesiz, 0)) from oyun.banka_musteri b where b.user_id = p_user), 0) as nakit,
      coalesce((select sum(m.anapara) from oyun.banka_mevduat m where m.user_id = p_user and not m.kapandi and not coalesce(m.iptal, false)), 0)
        + coalesce((select sum(v.anapara) from oyun.vadeli v where v.user_id = p_user and v.durum = 'acik'), 0) as mevduat,
      coalesce((select sum(greatest(0, y.alis_bedeli)) from oyun.yatirim_mulkleri y where y.user_id = p_user), 0) as mulk,
      coalesce((select sum(oyun.sirket_deger(o.sirket_id) * o.pay / 100) from oyun.sirket_ortaklari o
                 join oyun.sirketler s on s.id = o.sirket_id and s.aktif where o.user_id = p_user and o.pay > 0), 0) as sirket,
      coalesce((select sum(k.kalan) from oyun.krediler k where k.user_id = p_user and k.durum in ('aktif','takip')), 0)
        + coalesce((select sum(k.kalan) from oyun.oyb_kredi k where k.borclu = p_user and k.durum in ('aktif','takip')), 0) as borc
  )
  select jsonb_build_object('nakit', round(nakit), 'mevduat', round(mevduat), 'mulk', round(mulk), 'sirket_paylari', round(sirket),
    'acik_borc', round(borc), 'likit', round(nakit * 0.50 + mevduat * 0.80), 'duran', round(mulk * 0.50 + sirket * 0.30))
  from v
$$;

-- 4) Devlet bankası şahsi kredi limiti = gelir kapasitesi + teminat kapasitesi
create or replace function oyun.devlet_kredi_limit(p_user uuid, p_gun int, p_tem jsonb default null) returns jsonb
language plpgsql stable set search_path = '' as $$
declare r jsonb; tem jsonb; puan numeric; notu int; gelir_lim numeric; tem_lim numeric; lim numeric; neden text; engel boolean;
begin
  r := oyun.kredi_risk_ozeti(p_user, p_gun * 24);
  tem := coalesce(p_tem, oyun.kredi_teminat(p_user));
  notu := coalesce((r->>'kredi_notu')::int, 1100);
  puan := case when notu < 700 then 0 when notu < 900 then .50 when notu < 1100 then .70 when notu < 1500 then .85 when notu < 1700 then .95 else 1 end;
  engel := (r->>'neden') in ('Kredi notu 700 altinda', 'Kara liste suresi devam ediyor', 'Vadesi gecen oyuncu bankasi kredisi var', 'Yasal takipte devlet bankasi kredisi var');
  gelir_lim := coalesce((r->>'azami_kredi')::numeric, 0);
  tem_lim := greatest(0, (tem->>'likit')::numeric + case when p_gun >= 60 then (tem->>'duran')::numeric else 0 end - (tem->>'acik_borc')::numeric)
             * puan / 1.20;
  lim := case when engel then 0 else greatest(0, least(250000000, floor((gelir_lim + tem_lim) / 100) * 100)) end;
  neden := case when engel then r->>'neden'
                when lim < 1000 then 'Gelir ve teminat (nakit, mevduat, mülk, şirket payı) yetersiz'
                else 'Ödeme gücüne göre uygun' end;
  return r || jsonb_build_object('azami_kredi', lim, 'uygun', lim >= 1000, 'neden', neden, 'vade_gun', p_gun,
    'gelir_limiti', round(gelir_lim), 'teminat_limiti', round(tem_lim), 'teminat', tem);
end $$;

-- Genel limit (banka ekranı, kredi_uygunluk): en uzun vadedeki ödeme gücü. Statü tavanı kalktı.
create or replace function oyun.kredi_limiti(u uuid) returns numeric
language sql stable set search_path = '' as $$
  select coalesce((oyun.devlet_kredi_limit(u, 365)->>'azami_kredi')::numeric, 0)
$$;

-- 5) kredi_cek: yeni vadeler + ödeme gücü limiti (gövdenin geri kalanı aynen)
do $p$
declare d text; y text;
begin
  d := pg_get_functiondef('public.kredi_cek(numeric,integer)'::regprocedure);
  if position('oyun.devlet_kredi_limit' in d) > 0 then return; end if;
  y := replace(d, 'IF p_gun NOT IN (7,14,15,21,28,30) THEN', 'IF p_gun NOT IN (7,14,15,21,28,30,60,90,180,365) THEN');
  y := replace(y, '''Vade 1, 2, 3, 4 hafta olabilir (eski 15/30 gun vadeler desteklenir)''', '''Vade 1-4 hafta ya da 60, 90, 180, 365 gun olabilir''');
  y := replace(y, 'risk:=oyun.kredi_risk_ozeti(p.id,p_gun*24);', 'risk:=oyun.devlet_kredi_limit(p.id,p_gun);');
  y := replace(y, 'lim:=least(oyun.kredi_limiti(p.id),(risk->>''azami_kredi'')::numeric);', 'lim:=(risk->>''azami_kredi'')::numeric;');
  if y = d or position('oyun.devlet_kredi_limit(p.id,p_gun)' in y) = 0 or position('60,90,180,365) THEN' in y) = 0
     or position('oyun.kredi_limiti' in y) > 0 then
    raise exception '191: kredi_cek beklenen biçimde değil, yama uygulanmadı';
  end if;
  execute y;
end $p$;

-- 6) banka(): her vade için ödeme gücü bütçesi (teminat bir kez hesaplanır)
CREATE OR REPLACE FUNCTION public.banka()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    p oyun.profiller:=oyun.profilim();
    j jsonb;
    vv jsonb;
    tem jsonb;
    butce jsonb := '{}'::jsonb;
    r jsonb;
    g int;
    gercek_limit numeric := 0;
BEGIN
    j:=oyun.banka_json(p,oyun.simdi());
    tem:=oyun.kredi_teminat(p.id);
    FOREACH g IN ARRAY array[7,14,15,21,28,30,60,90,180,365] LOOP
        r:=oyun.devlet_kredi_limit(p.id,g,tem);
        butce:=butce||jsonb_build_object('vade'||g,r);
        gercek_limit:=greatest(gercek_limit,coalesce((r->>'azami_kredi')::numeric,0));
    END LOOP;
    j:=j||jsonb_build_object('kredi_limit',greatest(0,gercek_limit),'kredi_butce',butce,'kredi_teminat',tem,
      'kredi_vadeler',to_jsonb(array[7,14,21,28,60,90,180,365]));
    j:=jsonb_set(j,'{vadesiz}',coalesce(j->'vadesiz','{}'::jsonb)
        ||jsonb_build_object('saatlik',0,'gunluk',0,'birikmis',0,'faiz_toplam',0),true);
    SELECT coalesce(jsonb_agg(x||CASE WHEN x?'saatlik' THEN '{}'::jsonb
      ELSE jsonb_build_object('saatlik',0) END),'[]'::jsonb)
      INTO vv FROM jsonb_array_elements(coalesce(j->'vadeliler','[]'::jsonb)) x;
    RETURN jsonb_set(j,'{vadeliler}',vv,true);
END $function$;

-- 7a) Şirketin kredi borcu (defter, dağıtım sınırları): kalan bakiyenin ANAPARA kısmı + işlemiş gecikme faizi.
--     Henüz işlememiş gelecek faiz borç sayılmaz; kredi çekmek şirket değerini düşürmez (kasa +X, borç +X).
create or replace function oyun.yatirim_kredisi_borc(p_sirket bigint) returns numeric
language sql stable set search_path = '' as $$
  select coalesce((select sum(round(kalan * anapara / nullif(toplam, 0)) + gecikme_faizi)
                     from oyun.yatirim_kredisi where sirket_id = p_sirket and durum <> 'kapandi'), 0)
$$;

-- 7) Şirketin kredi ödeme gücü
create or replace function oyun.sirket_kredi_kapasite(p_sirket bigint, p_gun int) returns jsonb
language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler; net28 numeric; haftalik numeric; varlik numeric; acik numeric; borc numeric; gelir_kap numeric; tem numeric; kap numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null then return jsonb_build_object('kapasite', 0); end if;
  select coalesce(sum(coalesce(h.faaliyet_gelir, 0) - coalesce(h.faaliyet_gider, 0)), 0) into net28
    from oyun.sirket_hareket h where h.sirket_id = p_sirket and h.zaman >= now() - interval '28 days';
  haftalik := greatest(0, net28 / 4);
  varlik := coalesce((select sum(adet * maliyet_birim) from oyun.eko_urun_stok where sirket_id = s.id), 0)
          + coalesce((select sum(fiyat) from oyun.eko_arsalar where sahibi_sirket = s.id), 0)
          + coalesce((select sum(maliyet) from oyun.eko_yapilar where sirket_id = s.id), 0);
  select coalesce(sum(greatest(0, c.tutar - coalesce(c.odenen, 0))), 0) into acik
    from oyun.cekler c where c.borclu_sirket = p_sirket and c.durum in ('aktif','karsiliksiz');
  borc := oyun.yatirim_kredisi_borc(p_sirket);
  gelir_kap := haftalik * p_gun / 7.0 * 0.60;
  tem := varlik * 0.50 + greatest(0, coalesce(s.kasa, 0)) * 0.30;
  kap := greatest(0, least(250000000, floor((gelir_kap + tem - borc - acik) / 1.20 / 100) * 100));
  return jsonb_build_object('vade', p_gun, 'kapasite', kap, 'haftalik_kar', round(haftalik), 'varlik', round(varlik),
    'kasa', round(coalesce(s.kasa, 0)), 'kredi_borcu', round(borc), 'acik_cek', round(acik), 'gelir_kapasitesi', round(gelir_kap), 'teminat', round(tem));
end $$;

-- 8) Uygunluk: sabit 3 kredi / 25 milyon tavanı yerine ödeme gücü
create or replace function oyun.yatirim_kredisi_uygunluk(p_sirket bigint, p_vade int) returns jsonb
language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler; adet int; borc numeric; neden text; kap jsonb;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select count(*), coalesce(sum(kalan), 0) into adet, borc from oyun.yatirim_kredisi where sirket_id = p_sirket and durum <> 'kapandi';
  kap := oyun.sirket_kredi_kapasite(p_sirket, coalesce(p_vade, 90));
  neden := case
    when s.id is null or not s.aktif then 'Şirket faal değil.'
    when s.sektor = 'banka' then 'Bankalar bu krediyi kullanamaz.'
    when s.kurulus > now() - interval '3 days' then 'Kredi için şirket en az 3 gündür faal olmalı.'
    when exists (select 1 from oyun.cekler c where c.borclu_sirket = p_sirket and c.durum = 'karsiliksiz') then 'Şirketin karşılıksız çeki var.'
    when exists (select 1 from oyun.yatirim_kredisi y where y.sirket_id = p_sirket and y.durum = 'gecikmede') then 'Gecikmiş kredi taksiti var.'
    else null end;
  return jsonb_build_object('uygun', neden is null, 'neden', neden, 'acik_kredi', adet, 'acik_bakiye', round(borc),
    'kalan_tavan', (kap->>'kapasite')::numeric, 'kapasite', kap, 'oran', oyun.yatirim_kredisi_oran(), 'finansman_orani', 70);
end $$;
create or replace function oyun.yatirim_kredisi_uygunluk(p_sirket bigint) returns jsonb
language sql stable set search_path = '' as $$ select oyun.yatirim_kredisi_uygunluk(p_sirket, 90) $$;

-- Şube yatırım kredisi: banka yatırımın %70'ine kadar finanse eder; şubenin kendisi teminattır (bedelin yarısı kapasiteye eklenir)
create or replace function public.sirket_sube_ac_kredili(p_sirket bigint, p_il integer, p_kredi numeric, p_vade integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; d jsonb; uy jsonb; acilis numeric; rezerv numeric;
  azami numeric; oran numeric; toplam numeric; taksit numeric; kid bigint; r jsonb; city text;
begin
  if u is null then raise exception 'Oturum açmalısın.'; end if;
  if p_vade is null or p_vade not in (30, 60, 90, 180, 365) then raise exception 'Vade 30, 60, 90, 180 ya da 365 gün olabilir.'; end if;
  perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(p_sirket::text));
  perform oyun.sirket_hesapla(p_sirket);
  select * into s from oyun.sirketler where id = p_sirket and aktif for update;
  if s.id is null or not oyun.sirket_yonetici_mi(p_sirket, u) then raise exception 'Faaliyetteki şirketin yöneticisi olmalısın.'; end if;
  uy := oyun.yatirim_kredisi_uygunluk(p_sirket, p_vade);
  if not (uy->>'uygun')::boolean then raise exception '%', uy->>'neden'; end if;
  d := public.sirket_sube_teklif(p_sirket, p_il);
  acilis := (d->>'acilis_maliyeti')::numeric; rezerv := (d->>'isletme_rezervi')::numeric; city := d->>'il';
  azami := least(floor(acilis * 0.70), floor((uy->>'kalan_tavan')::numeric + acilis * 0.50 / 1.20));
  if p_kredi is null or p_kredi <> round(p_kredi) or p_kredi < 10000 then raise exception 'En az 10.000 ₺, tam sayı kredi tutarı gir.'; end if;
  if p_kredi > azami then
    raise exception 'Bu şube yatırımı için azami kredi % ₺ (yatırım bedeli % ₺; banka en fazla %%70''ini ve şirketin ödeme gücü kadarını finanse eder).', oyun.tl(azami), oyun.tl(acilis);
  end if;
  if s.kasa < (acilis - p_kredi) + rezerv then
    raise exception 'Öz katkı yetersiz: yatırımın kredi dışındaki kısmı % ₺ ve işletme rezervi % ₺ şirket kasasında olmalı (toplam % ₺, kasada % ₺).',
      oyun.tl(acilis - p_kredi), oyun.tl(rezerv), oyun.tl(acilis - p_kredi + rezerv), oyun.tl(s.kasa);
  end if;
  oran := oyun.yatirim_kredisi_oran();
  toplam := round(p_kredi * (1 + oran / 100 * p_vade / 365));
  taksit := ceil(toplam / p_vade);
  update oyun.sirketler set kasa = kasa + p_kredi where id = p_sirket;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
  values (p_sirket, t, p_kredi, format('Yatırım kredisi kullandırıldı (%s şubesi): %s ₺, %s gün, yıllık %%%s. Yalnız şube yatırımına harcanır.', city, oyun.tl(p_kredi), p_vade, oran), 0, 0, 0);
  r := public.sirket_sube_ac_ilde(p_sirket, p_il);
  insert into oyun.yatirim_kredisi(sirket_id, kullanan, amac, ref_id, yatirim_bedeli, anapara, oran, vade_gun, toplam, taksit, kalan, son_tahsil, acilis)
  values (p_sirket, u, format('%s şubesi', city), (r->>'id')::bigint, acilis, p_kredi, oran, p_vade, toplam, taksit, toplam, (t at time zone 'Europe/Istanbul')::date, t)
  returning id into kid;
  perform oyun.bildir(u, format('%s: %s şubesi açıldı. Yatırım kredisi #%s: %s ₺ (geri ödeme %s ₺, %s gün boyunca günde %s ₺ şirket kasasından).',
    s.ad, city, kid, oyun.tl(p_kredi), oyun.tl(toplam), p_vade, oyun.tl(taksit)), t);
  return r || jsonb_build_object('kredi_id', kid, 'kredi', p_kredi, 'toplam_geri_odeme', toplam, 'gunluk_taksit', taksit, 'oran', oran, 'oz_katki', acilis - p_kredi);
end $$;

-- 9) İşletme kredisi (şirket kasasına)
create or replace function public.sirket_kredi_al(p_sirket bigint, p_tutar numeric, p_vade integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; uy jsonb; azami numeric; oran numeric; toplam numeric; taksit numeric; kid bigint;
  hk uuid;
begin
  if u is null then raise exception 'Oturum açmalısın.'; end if;
  if p_vade is null or p_vade not in (30, 60, 90, 180, 365) then raise exception 'Vade 30, 60, 90, 180 ya da 365 gün olabilir.'; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < 10000 then raise exception 'En az 10.000 ₺, tam sayı kredi tutarı gir.'; end if;
  perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(p_sirket::text));
  perform oyun.sirket_hesapla(p_sirket);
  select * into s from oyun.sirketler where id = p_sirket and aktif for update;
  if s.id is null or not oyun.sirket_yonetici_mi(p_sirket, u) then raise exception 'Faaliyetteki şirketin yöneticisi olmalısın.'; end if;
  uy := oyun.yatirim_kredisi_uygunluk(p_sirket, p_vade);
  if not (uy->>'uygun')::boolean then raise exception '%', uy->>'neden'; end if;
  azami := (uy->>'kalan_tavan')::numeric;
  if p_tutar > azami then
    raise exception 'Şirketin bu vadedeki ödeme gücü % ₺ kredi kaldırır (son 28 gün kârı, varlıkları ve mevcut borçlarına göre).', oyun.tl(azami);
  end if;
  oran := oyun.yatirim_kredisi_oran();
  toplam := round(p_tutar * (1 + oran / 100 * p_vade / 365));
  taksit := ceil(toplam / p_vade);
  update oyun.sirketler set kasa = kasa + p_tutar, son_islem = t where id = p_sirket;
  insert into oyun.yatirim_kredisi(sirket_id, kullanan, amac, ref_id, yatirim_bedeli, anapara, oran, vade_gun, toplam, taksit, kalan, son_tahsil, acilis)
  values (p_sirket, u, 'İşletme kredisi', null, p_tutar, p_tutar, oran, p_vade, toplam, taksit, toplam, (t at time zone 'Europe/Istanbul')::date, t)
  returning id into kid;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
  values (p_sirket, t, p_tutar, format('İşletme kredisi #%s kullanıldı: %s ₺, %s gün, yıllık %%%s (geri ödeme %s ₺, günde %s ₺). Kredi parası ortaklara dağıtılamaz.',
    kid, oyun.tl(p_tutar), p_vade, oran, oyun.tl(toplam), oyun.tl(taksit)), 0, 0, 0);
  for hk in select distinct v from (select s.yonetici v union select o.user_id from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.pay >= 50) z where v is not null loop
    perform oyun.bildir(hk, format('%s: %s ₺ işletme kredisi şirket kasasına geçti (#%s). %s gün boyunca günde %s ₺ kasadan ödenecek.',
      s.ad, oyun.tl(p_tutar), kid, p_vade, oyun.tl(taksit)), t);
  end loop;
  return jsonb_build_object('tamam', true, 'kredi_id', kid, 'kredi', p_tutar, 'toplam_geri_odeme', toplam, 'gunluk_taksit', taksit, 'oran', oran, 'vade', p_vade);
end $$;

create or replace function public.yatirim_kredisi_panel(p_sirket bigint, p_il integer default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); d jsonb; uy jsonb; acilis numeric; az numeric; isl jsonb := '{}'::jsonb; g int;
begin
  if not exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = u and o.pay > 0)
     and not coalesce(oyun.sirket_yonetici_mi(p_sirket, u), false) then raise exception 'Bu şirketin ortağı değilsin.'; end if;
  uy := oyun.yatirim_kredisi_uygunluk(p_sirket, 90);
  foreach g in array array[30, 60, 90, 180, 365] loop
    isl := isl || jsonb_build_object(g::text, (oyun.sirket_kredi_kapasite(p_sirket, g)->>'kapasite')::numeric);
  end loop;
  if p_il is not null then
    begin
      d := public.sirket_sube_teklif(p_sirket, p_il);
      acilis := (d->>'acilis_maliyeti')::numeric;
      az := least(floor(acilis * 0.70), floor((uy->>'kalan_tavan')::numeric + acilis * 0.50 / 1.20));
      uy := uy || jsonb_build_object('sube', jsonb_build_object('il', d->>'il', 'acilis', acilis, 'rezerv', (d->>'isletme_rezervi')::numeric,
        'azami_kredi', az, 'kasa', (d->>'mevcut_kasa')::numeric,
        'gerekli_oz_katki', acilis - az + (d->>'isletme_rezervi')::numeric));
    exception when others then uy := uy || jsonb_build_object('sube_hata', sqlerrm);
    end;
  end if;
  return uy || jsonb_build_object('yonetici', coalesce(oyun.sirket_yonetici_mi(p_sirket, u), false), 'isletme_kapasite', isl,
    'krediler', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'amac', k.amac, 'anapara', k.anapara, 'oran', k.oran, 'vade', k.vade_gun,
        'toplam', k.toplam, 'taksit', k.taksit, 'kalan', k.kalan, 'gecikmis', k.gecikmis, 'durum', k.durum, 'acilis', k.acilis,
        'odenen_gun', least(k.vade_gun, k.odenen_taksit)) order by k.id desc)
      from (select * from oyun.yatirim_kredisi where sirket_id = p_sirket order by id desc limit 10) k), '[]'::jsonb));
end $$;

-- 10) Kredi parası ortaklara dağıtılamaz
create or replace function oyun.ortak_cari_durum(p_sirket bigint, u uuid) returns jsonb
language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler; pay numeric; acik numeric; hak numeric; kb numeric; serbest numeric; limit_ numeric; neden text;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select coalesce(o.pay, 0) into pay from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = u;
  pay := coalesce(pay, 0);
  select coalesce(sum(greatest(0, c.tutar - coalesce(c.odenen, 0))), 0) into acik
    from oyun.cekler c where c.borclu_sirket = p_sirket and c.durum in ('aktif','karsiliksiz');
  select coalesce(sum(greatest(0, h.hak - h.cekilen)), 0) into hak from oyun.eko_ortak_gunluk_hak h where h.sirket_id = p_sirket;
  kb := oyun.yatirim_kredisi_borc(p_sirket);
  serbest := greatest(0, coalesce(s.kasa, 0) - coalesce(s.sermaye, 0) - acik - hak - kb);
  limit_ := floor(least(100000000, serbest * pay / 100));
  neden := case
    when s.id is null or not s.aktif then 'Şirket faal değil.'
    when s.sektor = 'banka' then 'Bankalarda ortaklar cari hesabı kullanılamaz (mevduat sahipleri korunur).'
    when s.halka_acik then 'Halka açık şirketlerde ortaklar cari hesabı kullanılamaz (küçük yatırımcı korunur).'
    when pay < 50 then 'Cari hesaptan yalnız en az %50 paya sahip hakim ortak borç çekebilir.'
    when exists (select 1 from oyun.cekler c where c.borclu_sirket = p_sirket and c.durum = 'karsiliksiz') then 'Şirketin karşılıksız çeki varken ortağa borç verilemez.'
    when exists (select 1 from oyun.yatirim_kredisi y where y.sirket_id = p_sirket and y.durum = 'gecikmede') then 'Gecikmiş kredi taksiti varken ortağa borç verilemez.'
    when limit_ < 1000 then 'Serbest kâr yetersiz: sermaye, şirketin borçları ve banka kredisi çekilemez.'
    else null end;
  return jsonb_build_object('pay', pay, 'kasa', round(coalesce(s.kasa, 0)), 'sermaye', round(coalesce(s.sermaye, 0)), 'acik_cek', round(acik),
    'sakli_hak', round(hak), 'kredi_borcu', round(kb), 'serbest', round(serbest), 'limit', case when neden is null then limit_ else 0 end, 'neden', neden,
    'oran', oyun.politika_faizi());
end $$;

do $p$
declare d text; y text;
begin
  -- kâr payı: dağıtılabilir tutardan banka kredisi borcu düşülür
  d := pg_get_functiondef('public.sirket_kar_payi(bigint,numeric)'::regprocedure);
  if position('yatirim_kredisi_borc' in d) = 0 then
    y := replace(d, 'greatest(0,s.kasa-s.sermaye', 'greatest(0,s.kasa-s.sermaye-oyun.yatirim_kredisi_borc(p_sirket)');
    y := replace(y, 'Kurulus sermayesi ve mevduat borclari dagitilamaz', 'Kurulus sermayesi, mevduat borclari ve banka kredisi dagitilamaz');
    if y = d then raise exception '191: sirket_kar_payi beklenen biçimde değil'; end if;
    execute y;
  end if;
  -- genel kurul: temettü ve tasfiye payı kredi borcu düşülerek
  d := pg_get_functiondef('oyun.genel_kurul_kapat(bigint,boolean)'::regprocedure);
  if position('yatirim_kredisi_borc' in d) = 0 then
    y := replace(d, 'least((k.veri->>''tutar'')::numeric, greatest(0, s.kasa))', 'least((k.veri->>''tutar'')::numeric, greatest(0, s.kasa - oyun.yatirim_kredisi_borc(s.id)))');
    y := replace(y, 'greatest(0, s.kasa) * x.pay / 100', 'greatest(0, s.kasa - oyun.yatirim_kredisi_borc(s.id)) * x.pay / 100');
    if position('greatest(0, s.kasa - oyun.yatirim_kredisi_borc(s.id)))' in y) = 0
       or position('greatest(0, s.kasa - oyun.yatirim_kredisi_borc(s.id)) * x.pay / 100' in y) = 0 then
      raise exception '191: genel_kurul_kapat beklenen biçimde değil';
    end if;
    execute y;
  end if;
end $p$;

-- 11) Taksit tahsilatı: tasfiye edilen şirketin kredisi kapanır (tasfiyede borç kadar kasa dağıtılmadan bankaya kalır)
create or replace function oyun.yatirim_kredisi_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; k record; gun int; borc_bugun numeric;
  v_kasa numeric; v_aktif boolean; odenen numeric; gf numeric; n int := 0; ad text; hk uuid; i int;
begin
  if not pg_try_advisory_xact_lock(hashtext('oyun.yatirim_kredisi_tick')) then return 0; end if;
  for k in select * from oyun.yatirim_kredisi where durum <> 'kapandi' and son_tahsil < bugun order by id loop
    perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(k.sirket_id::text));
    select s.kasa, s.ad, s.aktif into v_kasa, ad, v_aktif from oyun.sirketler s where s.id = k.sirket_id for update;
    if not coalesce(v_aktif, false) then
      update oyun.yatirim_kredisi set durum = 'kapandi', kapanis = t, son_tahsil = bugun where id = k.id;
      n := n + 1; continue;
    end if;
    gun := least(31, bugun - k.son_tahsil);
    gf := round(k.gecikmis * k.oran * 1.5 / 100 / 365 * gun);
    borc_bugun := least(greatest(0, k.kalan - k.gecikmis), k.taksit * gun);
    odenen := greatest(0, least(coalesce(v_kasa, 0), k.gecikmis + gf + borc_bugun));
    update oyun.sirketler sx set kasa = sx.kasa - odenen where sx.id = k.sirket_id;
    update oyun.yatirim_kredisi set
      gecikme_faizi = 0,
      gecikmis = greatest(0, k.gecikmis + gf + borc_bugun - odenen),
      kalan = greatest(0, k.kalan + gf - odenen),
      odenen_taksit = odenen_taksit + gun,
      son_tahsil = bugun,
      durum = case when k.kalan + gf - odenen <= 0 then 'kapandi'
                   when k.gecikmis + gf + borc_bugun - odenen > 0 then 'gecikmede' else 'aktif' end,
      kapanis = case when k.kalan + gf - odenen <= 0 then t end
     where id = k.id;
    if odenen > 0 then
      insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
      values (k.sirket_id, t, -odenen, format('Kredi #%s taksiti (%s)%s', k.id, k.amac, case when gf > 0 then format(', gecikme faizi %s ₺ dahil', oyun.tl(gf)) else '' end), 0, gf, 0);
    end if;
    if k.gecikmis + gf + borc_bugun - odenen > 0 then
      for hk in select distinct v from (select s.yonetici v from oyun.sirketler s where s.id = k.sirket_id
                 union select o.user_id from oyun.sirket_ortaklari o where o.sirket_id = k.sirket_id and o.pay >= 50) z where v is not null loop
        perform oyun.bildir(hk, format('%s: kredi #%s (%s) taksiti kasada para olmadığı için ödenemedi. Gecikmiş tutar %s ₺; gecikme faizi işliyor, kasaya giren para önce bu borca gider.',
          ad, k.id, k.amac, oyun.tl(k.gecikmis + gf + borc_bugun - odenen)), t);
      end loop;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function oyun.kredi_teminat(uuid), oyun.devlet_kredi_limit(uuid, int, jsonb), oyun.sirket_kredi_kapasite(bigint, int),
  oyun.yatirim_kredisi_uygunluk(bigint, int), oyun.yatirim_kredisi_uygunluk(bigint), oyun.yatirim_kredisi_tick() from public, anon, authenticated;
revoke all on function public.sirket_kredi_al(bigint, numeric, integer) from public, anon;
grant execute on function public.sirket_kredi_al(bigint, numeric, integer) to authenticated, service_role;
