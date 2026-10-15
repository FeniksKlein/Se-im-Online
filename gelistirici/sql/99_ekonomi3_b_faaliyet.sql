-- 99b · EKONOMİ 3.0 — her şirkete günlük ana faaliyet (2026-10-15)
-- * Rekabetçi pazar modeli (pazar_tahmin) 5 sektörden 11 sektöre çıkar: teknoloji, sanayi, ticaret,
--   inşaat, medya, tarım da artık il pazarında fiyat/kalite/marka ile rekabet eder.
-- * Hesap kesimi haftalıktan GÜNLÜĞE iner (aynı haftalık tutar / 7). Geçmiş günler bir defada kapanır.
-- * Kapasite artık "hizmet hacmi"dir: gelir = min(talep, kapasite) × fiyat katsayısı → fiyat kararı
--   kapasite doluyken de anlamlı (yüksek fiyat daha çok kazandırır ama müşteri kaçırır, Rekabet Kurumu izler).
-- * Bölgesel teşvik (6 bölge, il kalkınma puanından): kurumlar vergisi indirimi + SGK işveren desteği.
-- * Şirketler arası gider zinciri: sabit giderin %30'u elektrik faturası (enerji şirketlerine),
--   %20'si lojistik (ulaşım şirketlerine), isteğe bağlı reklam bütçesi (medya şirketlerine) gerçek
--   oyuncu şirketlerine akar; oyuncu tedarikçi yoksa yurt içi NPC tedarikçilere gider.
-- * Kurumlar vergisi tek kaynaktan: eko_vergi_turleri 'kurumlar' (Meclis değiştirebilir).
-- İki kez çalıştırılabilir.

-- 1) Yeni sektör pazarları
insert into oyun.pazar_sektor(kod,ad,bakanlik,taban,esneklik,dis,sabit,kapasite,personel,min_sermaye,sira,aciklama) values
 ('teknoloji','Bilişim ve Yazılım','sanayi',160000,1.2,0.5,0.04,0.26,1.2,100000,6,
  'Yazılım, veri merkezi ve bilişim hizmetleri. Müşteri kaliteye ve markaya bakar; iyi ekip pahalıdır ama premium fiyatı taşır.'),
 ('sanayi','Sanayi Üretimi','sanayi',150000,1.5,0.6,0.05,0.26,1.4,100000,7,
  'Fabrika üretimi ve ara mallar. Büyüme ve dolar kuru talebi etkiler; ölçek büyüdükçe birim maliyet düşer.'),
 ('ticaret','Toptan ve Perakende Ticaret','ticaret',145000,2.0,0.5,0.04,0.28,1.0,100000,8,
  'Mağazalar, toptancılar ve e-ticaret. Fiyata duyarlı müşteri; ucuz olan çok satar.'),
 ('insaat','İnşaat ve Taahhüt','ulastirma',155000,1.3,0.8,0.05,0.25,1.3,100000,9,
  'Konut, iş yeri ve altyapı taahhüdü. Kamu yatırımları güçlüyse özel sektöre iş azalır; kamu ihaleleri ayrıca kazanılır.'),
 ('medya','Medya ve Yayıncılık','ulastirma',120000,1.4,0.7,0.045,0.26,1.1,100000,10,
  'Televizyon, gazete ve dijital yayın. Marka her şeydir; diğer şirketlerin reklam bütçeleri medya şirketlerine akar.'),
 ('tarim','Tarım ve Hayvancılık','tarim',130000,1.8,0.6,0.045,0.26,1.2,100000,11,
  'Tarla, sera ve hayvancılık. Doğu ve kırsal illerde teşvik yüksektir; fiyata duyarlı bir pazardır.')
on conflict (kod) do nothing;

-- 2) Yeni kolonlar ve tablolar
alter table oyun.pazar_sirket add column if not exists reklam smallint not null default 0;
do $$ begin
  alter table oyun.pazar_sirket add constraint pazar_sirket_reklam_ck check (reklam between 0 and 3);
exception when duplicate_object then null; end $$;

create table if not exists oyun.eko_gunluk(
  sirket_id bigint not null references oyun.sirketler(id) on delete cascade,
  gun date not null,
  gelir numeric not null default 0, gider numeric not null default 0, reklam numeric not null default 0,
  b2b_gider numeric not null default 0, b2b_gelir numeric not null default 0,
  ruhsat numeric not null default 0, ceza numeric not null default 0,
  vergi numeric not null default 0, tesvik numeric not null default 0,
  net numeric not null default 0, dagitilan numeric not null default 0,
  pazar numeric, pay numeric, rakip int, fiyat smallint, kalite smallint, il_id smallint,
  zaman timestamptz not null default now(),
  primary key(sirket_id, gun));
create index if not exists eko_gunluk_gun on oyun.eko_gunluk(gun);

create table if not exists oyun.eko_b2b(
  id bigserial primary key,
  zaman timestamptz not null default now(),
  gun date not null,
  alici bigint not null, satici bigint, kalem text not null,
  tutar numeric not null, islendi boolean not null default false);
create index if not exists eko_b2b_satici on oyun.eko_b2b(satici) where not islendi;
create index if not exists eko_b2b_alici on oyun.eko_b2b(alici, gun);

alter table oyun.eko_gunluk enable row level security;
alter table oyun.eko_b2b enable row level security;
alter table oyun.ekonomi3_kayit enable row level security;

-- 3) Bölgesel teşvik (Türkiye'nin 6 bölgeli teşvik sistemine benzer; il_kalkinma puanı 90/75/60/45/30/15)
create or replace function oyun.il_bolge(p_il smallint)
 returns smallint language sql stable set search_path to ''
as $$ select greatest(1, least(6, 7 - round(coalesce((select puan from oyun.il_kalkinma where il_id = p_il), 60) / 15.0)))::smallint $$;

create or replace function oyun.bolge_tesvik(p_il smallint)
 returns jsonb language sql stable set search_path to ''
as $$
  select jsonb_build_object('bolge', b,
    'vergi_indirim', (array[0,10,20,30,45,60])[b],
    'sgk_destek', (array[0,0,5,10,15,20])[b])
  from (select oyun.il_bolge(p_il) b) x
$$;

-- 4) Pazar tahmini (haftalık birimle; günlük kesimde /7 kullanılır)
create or replace function oyun.pazar_tahmin(p_sirket bigint, p_fiyat smallint default null::smallint, p_kalite smallint default null::smallint, p_kaynak text default null::text, t timestamp with time zone default null::timestamp with time zone)
 returns jsonb language plpgsql stable set search_path to ''
as $function$
declare s oyun.sirketler; ps oyun.pazar_sirket; k oyun.pazar_sektor; u oyun.ulke; zt timestamptz := coalesce(t, oyun.simdi());
  v_f smallint; v_k smallint; v_kay text; w numeric; makro numeric; pol numeric; pazar numeric; dis numeric; kamu numeric;
  ben numeric; toplam numeric; pay numeric; gelir numeric; kap numeric; gider numeric; personel numeric; ruh numeric; ruhsat numeric;
  vergi numeric; net numeric; ceza numeric := 0; kalite_gid numeric; kaynak_gid numeric := 0; rakip int; usd numeric; pold text;
  sabit numeric; talep numeric; reklam_oran numeric; reklam numeric; tes jsonb; kv numeric; sgk numeric; brut numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  select * into k from oyun.pazar_sektor where kod = s.sektor;
  if s.id is null or ps.sirket_id is null or k.kod is null then return null; end if;
  select * into u from oyun.ulke where id = 1;
  v_f := coalesce(p_fiyat, ps.fiyat); v_k := coalesce(p_kalite, ps.kalite);
  v_kay := case when s.sektor = 'enerji' then coalesce(p_kaynak, ps.kaynak, 'dogalgaz') else null end;

  w := oyun.pazar_il_agirlik(ps.il_id);
  makro := case when s.sektor in ('enerji','sanayi','insaat') then oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.06, 0.7, 1.4)
                else oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.03 + (coalesce(u.memnuniyet, 50) - 50) * 0.004, 0.8, 1.25) end;
  pold := oyun.sektor_pol_durum(s.sektor, zt);
  pol := case pold when 'tesvik' then 1.15 when 'denetim' then 0.92 else 1 end;
  pazar := k.taban * w * makro * pol * oyun.kriz_sektor_carpani(s.sektor, zt);

  kamu := coalesce((select kasa from oyun.bakanlik_kasa where kod = k.bakanlik), 20);
  dis := k.dis * (0.85 + least(greatest(kamu, 0), 60) / 100.0);

  ben := (1 + 0.35 * v_k + ps.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(v_f), k.esneklik);
  select coalesce(sum((1 + 0.35 * p2.kalite + p2.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p2.fiyat), k.esneklik)), 0), count(*)
    into toplam, rakip
  from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
  where p2.il_id = ps.il_id and s2.sektor = s.sektor and s2.aktif and p2.sirket_id <> s.id;
  pay := ben / (dis + toplam + ben);
  kap := s.sermaye * k.kapasite;
  talep := pazar * pay;
  -- kapasite hizmet hacmidir; fiyat katsayısı hacmin üstüne biner
  gelir := least(talep, kap) * oyun.pazar_fiyat_katsayi(v_f);

  tes := oyun.bolge_tesvik(ps.il_id);
  sgk := (tes->>'sgk_destek')::numeric;
  personel := coalesce(u.asgari, 30000) * k.personel * power(greatest(0.25, s.sermaye / 400000.0), 0.7) * (1 - sgk / 100);
  kalite_gid := s.sermaye * case v_k when 1 then 0.01 when 2 then 0.022 when 3 then 0.036 else 0 end;
  sabit := s.sermaye * k.sabit;
  if v_kay = 'komur' then sabit := sabit * 0.75;
  elsif v_kay = 'dogalgaz' then
    usd := coalesce((select fiyat from oyun.piyasa_varlik where kod = 'USD'), 42);
    kaynak_gid := s.sermaye * 0.015 * usd / 42.0;
  elsif v_kay = 'yenilenebilir' then sabit := sabit + s.sermaye * 0.02;
  end if;
  reklam_oran := (array[0, 0.015, 0.03, 0.05])[coalesce(ps.reklam, 0) + 1];
  reklam := gelir * reklam_oran;
  gider := sabit + personel + kalite_gid + kaynak_gid + reklam;

  if pold = 'denetim' and (v_k = 0 or v_kay = 'komur') then ceza := gelir * 0.12; end if;
  ruh := coalesce((select oran from oyun.il_ruhsat where il_id = ps.il_id), 0);
  ruhsat := gelir * ruh / 100;
  brut := gelir - gider - ruhsat - ceza;
  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), (select kurumlar from oyun.pazar_ayar where id = 1));
  vergi := greatest(0, brut) * kv / 100 * (1 - (tes->>'vergi_indirim')::numeric / 100);
  net := brut - vergi;
  return jsonb_build_object('pazar', round(pazar), 'pay', round(pay * 100, 1), 'rakip', rakip, 'gelir', round(gelir),
    'talep', round(talep), 'kapasite', round(kap), 'kapasite_dolu', talep >= kap - 1, 'gider', round(gider), 'personel', round(personel),
    'kalite_gider', round(kalite_gid), 'kaynak_gider', round(kaynak_gid), 'sabit', round(sabit), 'reklam', round(reklam),
    'reklam_seviye', coalesce(ps.reklam, 0),
    'ruhsat', round(ruhsat), 'ruhsat_oran', ruh, 'ceza', round(ceza), 'vergi', round(vergi), 'net', round(net),
    'gunluk_net', round(net / 7), 'kurumlar_orani', kv,
    'bolge', (tes->>'bolge')::int, 'vergi_indirim', (tes->>'vergi_indirim')::int, 'sgk_destek', (tes->>'sgk_destek')::int,
    'politika', pold, 'kamu_guc', round(dis, 2),
    'fiyat', v_f, 'kalite', v_k, 'kaynak', v_kay, 'getiri', round(net / s.sermaye * 100, 1));
end $function$;

-- 5) Şirketler arası ödeme: alıcının giderinden tedarikçi oyuncu şirketlerine pay
--    Tedarikçi ağırlığı = (1 + 0,35×kalite + marka/100) / fiyat^1,5 × (aynı il ise 3).
--    Oyuncu tedarikçilerin toplam payı = W / (W + 4) (geri kalanı yurt içi NPC tedarikçiler).
create or replace function oyun.b2b_ode(p_alici bigint, p_sektor text, p_tutar numeric, p_il smallint, p_kalem text, p_gun date)
 returns numeric language plpgsql security definer set search_path to ''
as $function$
declare toplam_w numeric; oyuncu_pay numeric; x record; dagit numeric := 0; parca numeric;
begin
  if coalesce(p_tutar, 0) <= 0 then return 0; end if;
  select coalesce(sum(w), 0) into toplam_w from (
    select (1 + 0.35 * p.kalite + p.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p.fiyat), 1.5)
           * case when p.il_id = p_il then 3 else 1 end w
    from oyun.pazar_sirket p join oyun.sirketler s on s.id = p.sirket_id
    where s.sektor = p_sektor and s.aktif and s.id <> p_alici) q;
  if toplam_w <= 0 then
    insert into oyun.eko_b2b(gun, alici, satici, kalem, tutar, islendi) values (p_gun, p_alici, null, p_kalem, round(p_tutar), true);
    return 0;
  end if;
  oyuncu_pay := p_tutar * toplam_w / (toplam_w + 4);
  for x in select s.id, (1 + 0.35 * p.kalite + p.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p.fiyat), 1.5)
           * case when p.il_id = p_il then 3 else 1 end w
    from oyun.pazar_sirket p join oyun.sirketler s on s.id = p.sirket_id
    where s.sektor = p_sektor and s.aktif and s.id <> p_alici
  loop
    parca := round(oyuncu_pay * x.w / toplam_w);
    if parca > 0 then
      update oyun.sirketler set kasa = kasa + parca where id = x.id;
      insert into oyun.eko_b2b(gun, alici, satici, kalem, tutar) values (p_gun, p_alici, x.id, p_kalem, parca);
      dagit := dagit + parca;
    end if;
  end loop;
  if p_tutar - dagit > 0 then
    insert into oyun.eko_b2b(gun, alici, satici, kalem, tutar, islendi) values (p_gun, p_alici, null, p_kalem, round(p_tutar - dagit), true);
  end if;
  return dagit;
end $function$;

-- 6) Günlük hesap kesimi
create or replace function oyun.pazar_hesapla(p_id bigint)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare s oyun.sirketler; ps oyun.pazar_sirket; t timestamptz := oyun.simdi(); n int; i int; h jsonb; zt timestamptz; gun date;
  gurultu numeric; gelir numeric; gider numeric; ruhsat numeric; ceza numeric; v_vergi numeric; net numeric; oran numeric;
  x record; distributed numeric; distributable numeric; v_odeme numeric; tlm numeric; ilad text; kasa_son numeric;
  en jsonb; yonetim numeric; a oyun.pazar_ayar; sabit numeric; reklam numeric; enerji numeric; lojistik numeric;
  b2b_in numeric; brut numeric; kv numeric; tes jsonb; indirim numeric; net_op numeric; tesvik_tl numeric;
  reklam_bonus numeric; kalite_bonus numeric;
begin
  select * into s from oyun.sirketler where id = p_id for update;
  select * into ps from oyun.pazar_sirket where sirket_id = p_id for update;
  if s.id is null or ps.sirket_id is null or not s.aktif or s.sonraki_kazanc > t then return; end if;
  select * into a from oyun.pazar_ayar where id = 1;
  n := least(30, floor(extract(epoch from (t - s.sonraki_kazanc)) / 86400)::int + 1);
  tlm := oyun.pazar_tl_milyar();
  select ad into ilad from oyun.iller where id = ps.il_id;
  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), a.kurumlar);
  for i in 1..n loop
    zt := s.sonraki_kazanc + (i - 1) * interval '1 day';
    gun := (zt at time zone 'Europe/Istanbul')::date;
    if ps.otopilot and (ps.hafta % 7 = 0) then
      en := oyun.pazar_en_iyi(p_id, zt);
      if en is not null and ((en->>'fiyat')::int <> ps.fiyat or (en->>'kalite')::int <> ps.kalite) then
        update oyun.pazar_sirket set fiyat = (en->>'fiyat')::int, kalite = (en->>'kalite')::int where sirket_id = p_id;
        select * into ps from oyun.pazar_sirket where sirket_id = p_id;
      end if;
    end if;
    h := oyun.pazar_tahmin(p_id, null, null, null, zt);
    gurultu := 0.88 + random()::numeric * 0.24;
    gelir := round((h->>'gelir')::numeric / 7 * gurultu);
    yonetim := case when ps.otopilot then round(gelir * a.yonetici_ucret / 100) else 0 end;
    sabit := (h->>'sabit')::numeric / 7;
    reklam := round(gelir * (array[0, 0.015, 0.03, 0.05])[coalesce(ps.reklam, 0) + 1]);
    gider := round(((h->>'gider')::numeric - (h->>'reklam')::numeric) / 7) + reklam + yonetim;
    oran := coalesce((h->>'ruhsat_oran')::numeric, 0);
    ruhsat := round(gelir * oran / 100);
    ceza := case when (h->>'ceza')::numeric > 0 then round(gelir * 0.12) else 0 end;
    net_op := gelir - gider - ruhsat - ceza;

    -- şirketler arası gider zinciri (giderin bir parçası tedarikçi oyunculara akar)
    enerji := round(sabit * 0.30); lojistik := round(sabit * 0.20);
    if s.sektor <> 'enerji' then perform oyun.b2b_ode(p_id, 'enerji', enerji, ps.il_id, 'Elektrik faturası', gun); end if;
    if s.sektor <> 'ulasim' then perform oyun.b2b_ode(p_id, 'ulasim', lojistik, ps.il_id, 'Lojistik ve servis', gun); end if;
    if reklam > 0 and s.sektor <> 'medya' then perform oyun.b2b_ode(p_id, 'medya', reklam, ps.il_id, 'Reklam', gun); end if;

    -- müşteri olduğun şirketlerden gelen ödemeler (kasaya zaten girdi; burada vergilendirilir)
    with u as (update oyun.eko_b2b set islendi = true where satici = p_id and not islendi returning tutar)
    select coalesce(sum(tutar), 0) into b2b_in from u;

    brut := net_op + b2b_in;
    tes := oyun.bolge_tesvik(ps.il_id);
    indirim := (tes->>'vergi_indirim')::numeric;
    v_vergi := round(greatest(0, brut) * kv / 100 * (1 - indirim / 100));
    tesvik_tl := round(greatest(0, brut) * kv / 100) - v_vergi;
    net := brut - v_vergi;

    if v_vergi > 0 then update oyun.ulke set hazine = hazine + v_vergi / tlm where id = 1; end if;
    if ruhsat > 0 then
      update oyun.il_durum set kasa = coalesce(kasa, 0) + ruhsat / tlm where il_id = ps.il_id;
      insert into oyun.il_ruhsat(il_id, toplam) values (ps.il_id, ruhsat)
        on conflict (il_id) do update set toplam = oyun.il_ruhsat.toplam + excluded.toplam;
    end if;
    update oyun.il_durum set
      gelisim = oyun.sinir(gelisim + (0.03 + case ps.kaynak when 'yenilenebilir' then 0.05 else 0 end) / 7, 0, 100),
      memnuniyet = oyun.sinir(memnuniyet + (case when s.sektor = 'enerji' and ps.kaynak = 'komur' then -0.4 when ps.kalite >= 2 then 0.05 else 0 end) / 7, 0, 100)
    where il_id = ps.il_id;

    -- kasaya: faaliyet sonucu − vergi (b2b geliri zaten kasada)
    update oyun.sirketler set kasa = kasa + net_op - v_vergi where id = p_id;
    distributed := 0;
    if net > 0 then
      distributable := least(net, greatest(0, (select kasa from oyun.sirketler where id = p_id)));
      for x in select * from oyun.sirket_ortaklari where sirket_id = p_id loop
        if not x.kar_kasada then
          v_odeme := least(round(distributable * x.pay / 100, 2), greatest(0, distributable - distributed));
          if v_odeme > 0 then
            perform oyun.para_islem(x.user_id, v_odeme, 'sirket', format('%s günlük net kâr payı (%s)', s.ad, to_char(gun, 'DD.MM')), t);
            distributed := distributed + v_odeme;
          end if;
        end if;
      end loop;
      update oyun.sirketler set kasa = kasa - distributed where id = p_id;
    end if;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (p_id, t, net, format('Günlük faaliyet %s (%s): pazar payı %%%s, %s rakip%s%s', to_char(gun, 'DD.MM'),
            ilad, h->>'pay', h->>'rakip', case when ps.otopilot then ', otopilot' else '' end,
            case when b2b_in > 0 then format(', şirketlerden %s ₺ satış', oyun.tl(b2b_in)) else '' end),
            gelir + b2b_in, gider + ruhsat + ceza + v_vergi, distributed);
    insert into oyun.pazar_rapor(sirket_id, zaman, il_id, pazar, pay, rakip, gelir, gider, ruhsat, vergi, ceza, net, fiyat, kalite, kaynak)
    values (p_id, zt + interval '1 day', ps.il_id, round((h->>'pazar')::numeric / 7), (h->>'pay')::numeric, (h->>'rakip')::int,
            gelir + b2b_in, gider, ruhsat, v_vergi, ceza, net, ps.fiyat, ps.kalite, ps.kaynak);
    insert into oyun.eko_gunluk(sirket_id, gun, gelir, gider, reklam, b2b_gider, b2b_gelir, ruhsat, ceza, vergi, tesvik, net, dagitilan,
                                pazar, pay, rakip, fiyat, kalite, il_id, zaman)
    values (p_id, gun, gelir, gider, reklam, enerji + lojistik + reklam, b2b_in, ruhsat, ceza, v_vergi, tesvik_tl, net, distributed,
            round((h->>'pazar')::numeric / 7), (h->>'pay')::numeric, (h->>'rakip')::int, ps.fiyat, ps.kalite, ps.il_id, t)
    on conflict on constraint eko_gunluk_pkey do update set
      gelir = oyun.eko_gunluk.gelir + excluded.gelir, gider = oyun.eko_gunluk.gider + excluded.gider,
      reklam = oyun.eko_gunluk.reklam + excluded.reklam, b2b_gider = oyun.eko_gunluk.b2b_gider + excluded.b2b_gider,
      b2b_gelir = oyun.eko_gunluk.b2b_gelir + excluded.b2b_gelir, ruhsat = oyun.eko_gunluk.ruhsat + excluded.ruhsat,
      ceza = oyun.eko_gunluk.ceza + excluded.ceza, vergi = oyun.eko_gunluk.vergi + excluded.vergi,
      tesvik = oyun.eko_gunluk.tesvik + excluded.tesvik, net = oyun.eko_gunluk.net + excluded.net,
      dagitilan = oyun.eko_gunluk.dagitilan + excluded.dagitilan, zaman = excluded.zaman;

    reklam_bonus := (array[0, 3, 6, 10])[coalesce(ps.reklam, 0) + 1];
    kalite_bonus := 3 + 2.5 * ps.kalite + case ps.kaynak when 'yenilenebilir' then 3 else 0 end;
    update oyun.pazar_sirket set marka = least(100, marka * 0.985 + (kalite_bonus + reklam_bonus) / 7.0),
      hafta = hafta + 1 where sirket_id = p_id;
    select * into ps from oyun.pazar_sirket where sirket_id = p_id;

    select kasa into kasa_son from oyun.sirketler where id = p_id;
    if kasa_son <= 0 then
      update oyun.sirketler set aktif = false, kasa = 0, satilik = null, son_islem = t,
        sonraki_kazanc = s.sonraki_kazanc + i * interval '1 day' where id = p_id;
      update oyun.borsa_emir set durum = 'iptal' where sirket_id = p_id and durum = 'acik';
      perform oyun.olay('ekonomi', format('%s (%s, %s) iflas etti; kasası tükendi.', s.ad,
        (select ad from oyun.pazar_sektor where kod = s.sektor), ilad), ps.il_id, null, t);
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
        perform oyun.bildir(x.user_id, format('%s iflas etti: şirket kasası tükendi ve faaliyet durdu.', s.ad), t);
      end loop;
      return;
    end if;
  end loop;
  update oyun.sirketler set sonraki_kazanc = sonraki_kazanc + n * interval '1 day', son_islem = t where id = p_id;
  if kasa_son < s.sermaye * 0.25 and (ps.son_uyari is null or ps.son_uyari < t - interval '2 days') then
    update oyun.pazar_sirket set son_uyari = t where sirket_id = p_id;
    for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
      perform oyun.bildir(x.user_id, format('%s zarar ediyor: kasada %s ₺ kaldı. Fiyat/kaliteyi gözden geçir, otopilotu aç ya da ili değiştir; yoksa iflas edebilir.',
        s.ad, oyun.tl(kasa_son)), t);
    end loop;
  end if;
end $function$;

-- 7) Şirket hesap yönlendirmesi: pazar satırı olan her şirket önce günlük ana faaliyetini kapatır
create or replace function oyun.sirket_hesapla(p_id bigint)
 returns void language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;distributable numeric;v_odeme numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 if exists(select 1 from oyun.pazar_sirket where sirket_id=p_id) then perform oyun.pazar_hesapla(p_id); return; end if;
 if exists(select 1 from oyun.eko_isletmeler where sirket_id=p_id) then
  update oyun.sirketler set sonraki_kazanc=greatest(sonraki_kazanc,t)+interval '1 day',son_islem=t where id=p_id;
  return;
 end if;
 if s.sektor='ajans' then perform oyun.ajans_hesapla(p_id); return; end if;
 -- Buraya yalnız bankalar ve henüz pazar satırı açılmamış eski şirketler düşer (eski haftalık usul).
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()::numeric*.8),2);
  cost:=round(s.sermaye*(.025+random()::numeric*.055)+w*(.5+random()::numeric),2);
  income:=round(income * oyun.kriz_sektor_carpani(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days')
                       * oyun.sektor_pol_carpan(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days'),2); net:=income-cost;
  distributed:=0;
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributable:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    if not x.kar_kasada then
      v_odeme:=least(round(distributable*x.pay/100,2),greatest(0,distributable-distributed));
      if v_odeme>0 then
        perform oyun.para_islem(x.user_id,v_odeme,'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
        distributed:=distributed+v_odeme;
      end if;
    end if;
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$;

-- 8) Ruhsat ve paravan kapıları: sistemin kendi açtığı ana faaliyet satırı için atlanır
create or replace function oyun.bel_ruhsat_kapi()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare u uuid:=auth.uid(); sid bigint; il smallint; hedef bigint; tip text;
 s oyun.sirketler; r oyun.bel_yatirim_ruhsat; tutar numeric; matrah numeric; il_ad text;
begin
 if coalesce(current_setting('oyun.ekonomi3_oto', true), '') = '1' then return new; end if;
 if u is null then raise exception 'Yatırım işlemi için oyuncu oturumu gerekli.';end if;
 if tg_table_name='eko_isletmeler' then
   sid:=new.sirket_id; il:=new.il_id; tip:='kur_'||new.tur;
 elsif tg_table_name='pazar_sirket' then
   sid:=new.sirket_id; il:=new.il_id; tip:='kur_pazar';
 elsif tg_table_name='eko_yapilar' then
   sid:=new.sirket_id; il:=new.il_id; tip:='arsa_insaat'; hedef:=new.arsa_id;
 elsif tg_table_name='eko_projeler' then
   sid:=new.sirket_id; il:=new.il_id; tip:='yeni_proje';
 elsif tg_table_name='eko_subeler' then
   sid:=new.sirket_id; tip:='sube'; hedef:=new.bolum_id;
   select y.il_id into il from oyun.eko_bolumler b join oyun.eko_yapilar y on y.id=b.yapi_id where b.id=hedef;
 else return new; end if;
 select * into s from oyun.sirketler where id=sid;
 if s.id is null or not s.aktif or not oyun.sirket_yonetici_mi(sid,u) then raise exception 'Ruhsat için şirket yönetim yetkisi gerekli.';end if;
 select * into r from oyun.bel_yatirim_ruhsat br
 where br.oyuncu=u and br.il_id=il and br.tur=tip and br.durum='onay'
 and (br.sirket_id=sid or (br.sirket_id is null and br.sirket_adi=s.ad))
 and (br.hedef_id is null or br.hedef_id=hedef)
 and (br.sektor is null or br.sektor=s.sektor)
 and br.karar_zamani>now()-interval '72 hours'
 order by br.id asc limit 1 for update;
 if r.id is null then
  raise exception 'Bu yatırım için % belediyesinden onaylı ruhsat gerekli. Ekonomi veya Belediye menüsündeki Ruhsat Merkezi üzerinden başvur.',(select ad from oyun.iller where id=il);
 end if;
 matrah:=case when tg_table_name in ('eko_yapilar','eko_projeler')
   then coalesce((to_jsonb(new)->>'maliyet')::numeric,0)
   when tg_table_name='eko_subeler' then greatest(0,s.sermaye*0.10)
   else s.sermaye end;
 tutar:=oyun.bel_ruhsat_tutar(r.onay_oran,r.onay_taban,matrah);
 update oyun.sirketler set kasa=kasa-tutar where id=sid and kasa>=tutar;
 if not found then raise exception 'Ruhsat harcı için şirket kasasında % TL gerekli.',tutar;end if;
 update oyun.il_durum set kasa=kasa+tutar/nullif(oyun.pazar_tl_milyar(),0) where il_id=il;
 update oyun.bel_yatirim_ruhsat set durum='kullanildi',odenen_tl=tutar,kullanma=now() where id=r.id;
 insert into oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama,zaman)
 values(il,'ruhsat_geliri',tutar/nullif(oyun.pazar_tl_milyar(),0),format('%s ruhsatı (#%s) - %s TL belediye geliri',tip,r.id,tutar),oyun.simdi());
 return new;
end $function$;

create or replace function oyun.tg_pazar_paravan()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_sektor text; u uuid;
begin
  if coalesce(current_setting('oyun.ekonomi3_oto', true), '') = '1' then return new; end if;
  select sektor into v_sektor from oyun.sirketler where id = new.sirket_id;
  for u in select user_id from oyun.sirket_ortaklari where sirket_id = new.sirket_id and pay >= 50 loop
    if exists (select 1 from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
               join oyun.sirket_ortaklari o2 on o2.sirket_id = s2.id and o2.user_id = u and o2.pay >= 50
               where p2.il_id = new.il_id and s2.sektor = v_sektor and s2.aktif and s2.id <> new.sirket_id) then
      raise exception 'Paravan şirket kuralı: bu ilde aynı türde çoğunluğuna sahip olduğun bir şirket zaten var.';
    end if;
  end loop;
  return new;
end $function$;

-- 9) Ana faaliyet satırı açma: pazar satırı olmayan aktif şirketlere (banka, ajans hariç).
--    İl: işletmenin ili, yoksa en büyük ortağın ikamet ili. Kuruluş işlemi tamamlandıktan sonra
--    zamanlayıcı açar; böylece kuruluş ruhsatı akışı değişmez.
create or replace function oyun.ana_faaliyet_ac()
 returns int language plpgsql security definer set search_path to ''
as $function$
declare r record; n int := 0; v_il smallint;
begin
  perform set_config('oyun.ekonomi3_oto', '1', true);
  for r in select s.* from oyun.sirketler s
           where s.aktif and s.sektor in (select kod from oyun.pazar_sektor)
             and not exists (select 1 from oyun.pazar_sirket p where p.sirket_id = s.id)
             and s.kurulus < now() - interval '2 minutes'
           order by s.id limit 100
  loop
    v_il := coalesce((select il_id from oyun.eko_isletmeler where sirket_id = r.id),
                     (select il_id from oyun.profiller where id = oyun.sirket_sahibi(r.id)),
                     (select il_id from oyun.profiller where id = r.kurucu), 34);
    insert into oyun.pazar_sirket(sirket_id, il_id, fiyat, kalite, kaynak)
    values (r.id, v_il, 2, 1, case when r.sektor = 'enerji' then 'dogalgaz' end)
    on conflict (sirket_id) do nothing;
    -- işletmesi (mağaza/fabrika/şantiye) olmayan eski şirketler için en kârlı büyük il seçilir
    if not exists (select 1 from oyun.eko_isletmeler where sirket_id = r.id) then
      declare c smallint; en_il smallint := v_il; en_net numeric; h numeric;
      begin
        en_net := (oyun.pazar_tahmin(r.id)->>'net')::numeric;
        foreach c in array array[34,6,35,16,7,41,1,42,27,33,v_il]::smallint[] loop
          update oyun.pazar_sirket set il_id = c where sirket_id = r.id;
          h := (oyun.pazar_tahmin(r.id)->>'net')::numeric;
          if h > en_net then en_net := h; en_il := c; end if;
        end loop;
        update oyun.pazar_sirket set il_id = en_il where sirket_id = r.id;
      end;
    end if;
    -- günlük kesim kuruluştan bir gün sonra başlar
    update oyun.sirketler set sonraki_kazanc = least(coalesce(sonraki_kazanc, now()), greatest(kurulus + interval '1 day', now() - interval '29 days'))
      where id = r.id;
    n := n + 1;
  end loop;
  perform set_config('oyun.ekonomi3_oto', '', true);
  -- eski haftalık takvimde kalan şirketler günlük takvime çekilir
  update oyun.sirketler s set sonraki_kazanc = s.kurulus + interval '1 day'
    where s.aktif and s.sonraki_kazanc > now() + interval '1 day'
      and exists (select 1 from oyun.pazar_sirket p where p.sirket_id = s.id)
      and not exists (select 1 from oyun.eko_gunluk g where g.sirket_id = s.id);
  return n;
end $function$;

-- 10) Pazar kurma: ana faaliyet satırı varsa çakışmasın
create or replace function public.pazar_sirket_kur(p_ad text, p_sektor text, p_sermaye numeric, p_il integer, p_kaynak text default null::text)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); k oyun.pazar_sektor; v_id bigint; t timestamptz := oyun.simdi(); ilad text;
begin
  select * into k from oyun.pazar_sektor where kod = p_sektor;
  if k.kod is null then raise exception 'Geçersiz şirket türü.'; end if;
  if p_ad is null or char_length(btrim(p_ad)) not between 3 and 50 then raise exception 'Şirket adı 3-50 karakter olmalı.'; end if;
  if not exists (select 1 from oyun.iller where id = p_il) then raise exception 'Geçersiz il.'; end if;
  if p_sermaye is null or p_sermaye <> round(p_sermaye) or p_sermaye < k.min_sermaye or p_sermaye > 100000000 then
    raise exception '% için kuruluş sermayesi en az % ₺, en fazla 100.000.000 ₺ olmalı.', k.ad, oyun.tl(k.min_sermaye);
  end if;
  if p_sektor = 'enerji' and coalesce(p_kaynak, 'dogalgaz') not in ('komur','dogalgaz','yenilenebilir') then raise exception 'Geçersiz enerji kaynağı.'; end if;
  if (select count(*) from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id
      where o.user_id = p.id and s.kurucu = p.id and s.aktif and s.kurulus > t - interval '24 hours') >= 3 then
    raise exception 'Son 24 saatte en fazla 3 şirket kurabilirsin.';
  end if;
  perform oyun.para_islem(p.id, -p_sermaye, 'sirket', format('%s kuruluş sermayesi', k.ad), t);
  insert into oyun.sirketler(ad, sektor, kurucu, sermaye, kasa, son_islem, kurulus, sonraki_kazanc) values (btrim(p_ad), p_sektor, p.id, p_sermaye, p_sermaye, t, t, t + interval '1 day')
    returning id into v_id;
  insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values (v_id, p.id, 100);
  insert into oyun.pazar_sirket(sirket_id, il_id, kaynak) values (v_id, p_il,
    case when p_sektor = 'enerji' then coalesce(p_kaynak, 'dogalgaz') end);
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.olay('ekonomi', format('%s, %s''da %s açtı: %s.', p.kad, ilad, lower(k.ad), btrim(p_ad)), p_il::smallint, null, t);
  return jsonb_build_object('id', v_id, 'tahmin', oyun.pazar_tahmin(v_id));
end $function$;

-- 11) Reklam bütçesi kararı
create or replace function public.sirket_reklam_ayarla(p_sirket bigint, p_seviye integer)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); ps oyun.pazar_sirket;
begin
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  if ps.sirket_id is null then raise exception 'Şirketin ana faaliyeti henüz açılmadı; birkaç dakika sonra tekrar dene.'; end if;
  if not oyun.sirket_yonetici_mi(p_sirket, p.id) then raise exception 'Reklam bütçesini şirketin yöneticisi belirler.'; end if;
  if p_seviye not between 0 and 3 then raise exception 'Reklam seviyesi 0-3 olmalı.'; end if;
  perform oyun.sirket_hesapla(p_sirket);
  update oyun.pazar_sirket set reklam = p_seviye where sirket_id = p_sirket;
  return oyun.pazar_tahmin(p_sirket);
end $function$;

-- 12) Zamanlayıcı: önce ana faaliyet satırlarını aç, sonra vadesi gelenleri kapat
create or replace function oyun.pazar_tick()
 returns integer language plpgsql security definer set search_path to ''
as $function$
declare r record; n int := 0;
begin
  perform oyun.ana_faaliyet_ac();
  perform oyun.ihale_tick();
  perform oyun.rekabet_tick();
  perform oyun.ajans_tick();
  for r in select s.id from oyun.sirketler s
           where s.aktif and s.sonraki_kazanc <= oyun.simdi()
             and (exists (select 1 from oyun.pazar_sirket ps where ps.sirket_id = s.id) or s.sektor = 'ajans')
           order by s.sonraki_kazanc limit 200 loop
    perform oyun.sirket_hesapla(r.id); n := n + 1;
  end loop;
  perform oyun.piyasa_endeks_tick();
  return n;
end $function$;

-- 13) Yetkiler
revoke all on function public.sirket_reklam_ayarla(bigint, integer) from public, anon;
grant execute on function public.sirket_reklam_ayarla(bigint, integer) to authenticated;
revoke all on function oyun.b2b_ode(bigint, text, numeric, smallint, text, date) from public, anon, authenticated;
revoke all on function oyun.ana_faaliyet_ac() from public, anon, authenticated;
