-- Seçim Simülasyonu Online — Ekonomi 2. aşama: borsa, Rekabet Kurumu, şirket bağışları, danışman/otopilot, yerel fiyat → geçim, piyasa raporu.
-- Kaynak: gelistirici/sql/85_ekonomi_borsa_rekabet.sql. Önce 20261011_ekonomi_pazar_ihale.sql gerekir. Yalnız ekler; iki kez çalıştırılabilir.
begin;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 85) Ekonomi 2. aşama: borsa, Rekabet Kurumu, şirket bağışları,
--  danışman ve otopilot, yerel piyasa fiyatlarının geçime etkisi, piyasa raporu
--
--  • DANIŞMAN / OTOPİLOT: Sunucu rekabetçi şirket için 12 fiyat × kalite seçeneğini hesaplar,
--    en kârlısını "önerilen" diye verir. Otopilot açıksa her hafta en kârlı ayarı kendisi seçer;
--    bedeli o haftaki gelirin %4'ü (profesyonel yönetici ücreti).
--  • PARAVAN KURALI: Bir oyuncu aynı ilde aynı türde iki şirketin çoğunluğuna sahip olamaz.
--  • BORSA: Halka açık şirketlerin payları oyuncular arasında satılır. Satıcı "% pay başına fiyat"
--    ile emir verir, alıcı dilediği kadarını alır. Alıcıdan %0,5 komisyon hazineye gider.
--    Alım-satımdan önce şirketin geciken haftası kapanır (kâr eski sahibe ödenir).
--  • REKABET KURUMU: Ticaret Bakanı (boşsa CB) bir il + sektör için 24 saatlik soruşturma açar
--    (bakanlık kasasından 0,5 milyar ₺). Sonuçta: aynı kişinin çoğunluğunda birden çok şirket
--    (paravan), ildeki bütün rakiplerin premium fiyatı (kartel) ya da tek şirketin %55+ pay ile
--    premium fiyatı (hâkim durumun kötüye kullanılması) → ilgili şirketlere kasalarının %8'i ceza,
--    fiyat ortaya çekilir, karar Resmî Gazete'de.
--  • ŞİRKET BAĞIŞI: En büyük ortak şirket kasasından partiye bağış yapar (7 günde en fazla
--    sermayenin %20'si). Her bağış herkese açık listede ve olay akışında görünür.
--  • YEREL PİYASA FİYATLARI: Günde bir kez her ilin market ve enerji şirketlerinin (gelir ağırlıklı)
--    fiyat düzeyinden o ilin geçim masrafı etkisi çıkar: ucuz ve rekabetçi → geçim %5'e kadar ucuz,
--    premium tekel → %7,5'e kadar pahalı (oyun.etkiler, tur 'gecim'). Ülke endeksi enflasyona
--    küçük bir itki verir.
--  • PİYASA RAPORU: tek ekranda endeks, vergi, sektör liderleri, borsa, ihaleler, kararlar, bağışlar.
--  Yalnız ekler; oyuncu verisi silinmez.
-- =====================================================================

alter table oyun.pazar_sirket add column if not exists otopilot boolean not null default false;
alter table oyun.pazar_ayar add column if not exists yonetici_ucret numeric not null default 4;
alter table oyun.pazar_ayar add column if not exists komisyon numeric not null default 0.5;
alter table oyun.pazar_ayar add column if not exists endeks numeric not null default 1;
alter table oyun.pazar_ayar add column if not exists son_endeks_gun date;

create table if not exists oyun.borsa_emir(
  id        bigserial primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  satici    uuid not null,
  pay       numeric not null check (pay > 0),
  kalan     numeric not null check (kalan >= 0),
  birim     numeric not null check (birim > 0),      -- %1 pay başına ₺
  zaman     timestamptz not null,
  durum     text not null default 'acik' check (durum in ('acik','bitti','iptal'))
);
create index if not exists borsa_emir_acik on oyun.borsa_emir(sirket_id, birim) where durum = 'acik';

create table if not exists oyun.borsa_islem(
  id        bigserial primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  emir_id   bigint references oyun.borsa_emir(id),
  satici    uuid not null,
  alici     uuid not null,
  pay       numeric not null,
  birim     numeric not null,
  tutar     numeric not null,
  komisyon  numeric not null,
  zaman     timestamptz not null
);
create index if not exists borsa_islem_sirket on oyun.borsa_islem(sirket_id, zaman desc);

create table if not exists oyun.rekabet_sorusturma(
  id      bigserial primary key,
  il_id   smallint not null references oyun.iller(id),
  sektor  text not null,
  acan    uuid not null,
  bas     timestamptz not null,
  bit     timestamptz not null,
  durum   text not null default 'acik' check (durum in ('acik','ihlal','temiz')),
  karar   text,
  ceza    numeric not null default 0
);
create index if not exists rekabet_acik on oyun.rekabet_sorusturma(durum, bit);

create table if not exists oyun.sirket_bagis(
  id        bigserial primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  parti_id  bigint not null references oyun.partiler(id),
  veren     uuid not null,
  tutar     numeric not null check (tutar > 0),
  zaman     timestamptz not null
);
create index if not exists sirket_bagis_zaman on oyun.sirket_bagis(zaman desc);

do $$ declare t text; begin
  foreach t in array array['borsa_emir','borsa_islem','rekabet_sorusturma','sirket_bagis'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
  revoke all on sequence oyun.borsa_emir_id_seq, oyun.borsa_islem_id_seq, oyun.rekabet_sorusturma_id_seq, oyun.sirket_bagis_id_seq
    from public, anon, authenticated;
end $$;

-- ---------------------------------------------------------------- yardımcılar
-- Şirketin en büyük ortağı
create or replace function oyun.sirket_sahibi(p_sirket bigint) returns uuid language sql stable set search_path = '' as $$
  select user_id from oyun.sirket_ortaklari where sirket_id = p_sirket order by pay desc, user_id limit 1
$$;

-- 12 seçenek içinde en kârlı fiyat × kalite (enerji kaynağı aynı kalır)
create or replace function oyun.pazar_en_iyi(p_sirket bigint, t timestamptz default null) returns jsonb
language plpgsql stable set search_path = '' as $$
declare f int; q int; h jsonb; en jsonb;
begin
  for f in 1..3 loop for q in 0..3 loop
    h := oyun.pazar_tahmin(p_sirket, f::smallint, q::smallint, null, t);
    if h is not null and (en is null or (h->>'net')::numeric > (en->>'net')::numeric) then
      en := jsonb_build_object('fiyat', f, 'kalite', q, 'net', (h->>'net')::numeric, 'pay', (h->>'pay')::numeric, 'gelir', (h->>'gelir')::numeric);
    end if;
  end loop; end loop;
  return en;
end $$;

-- Paravan kuralı: aynı kişi aynı ilde aynı türde iki şirketin çoğunluğuna sahip olamaz
create or replace function oyun.tg_pazar_paravan() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_sektor text; u uuid;
begin
  select sektor into v_sektor from oyun.sirketler where id = new.sirket_id;
  for u in select user_id from oyun.sirket_ortaklari where sirket_id = new.sirket_id and pay >= 50 loop
    if exists (select 1 from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
               join oyun.sirket_ortaklari o2 on o2.sirket_id = s2.id and o2.user_id = u and o2.pay >= 50
               where p2.il_id = new.il_id and s2.sektor = v_sektor and s2.aktif and s2.id <> new.sirket_id) then
      raise exception 'Paravan şirket kuralı: bu ilde aynı türde çoğunluğuna sahip olduğun bir şirket zaten var.';
    end if;
  end loop;
  return new;
end $$;
drop trigger if exists pazar_paravan on oyun.pazar_sirket;
create trigger pazar_paravan before insert or update of il_id on oyun.pazar_sirket
  for each row execute function oyun.tg_pazar_paravan();

-- ---------------------------------------------------------------- haftalık hesap (otopilot eklendi)
create or replace function oyun.pazar_hesapla(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare s oyun.sirketler; ps oyun.pazar_sirket; t timestamptz := oyun.simdi(); n int; i int; h jsonb; zt timestamptz;
  gurultu numeric; gelir numeric; gider numeric; ruhsat numeric; ceza numeric; v_vergi numeric; net numeric; oran numeric;
  x record; distributed numeric; distributable numeric; v_odeme numeric; tlm numeric; ilad text; kasa_son numeric;
  en jsonb; yonetim numeric; a oyun.pazar_ayar;
begin
  select * into s from oyun.sirketler where id = p_id for update;
  select * into ps from oyun.pazar_sirket where sirket_id = p_id for update;
  if s.id is null or ps.sirket_id is null or not s.aktif or s.sonraki_kazanc > t then return; end if;
  select * into a from oyun.pazar_ayar where id = 1;
  n := least(52, floor(extract(epoch from (t - s.sonraki_kazanc)) / 604800)::int + 1);
  tlm := oyun.pazar_tl_milyar();
  select ad into ilad from oyun.iller where id = ps.il_id;
  for i in 1..n loop
    zt := s.sonraki_kazanc + (i - 1) * interval '7 days';
    -- otopilot: haftanın başında en kârlı ayara geç
    if ps.otopilot then
      en := oyun.pazar_en_iyi(p_id, zt);
      if en is not null and ((en->>'fiyat')::int <> ps.fiyat or (en->>'kalite')::int <> ps.kalite) then
        update oyun.pazar_sirket set fiyat = (en->>'fiyat')::int, kalite = (en->>'kalite')::int where sirket_id = p_id;
        select * into ps from oyun.pazar_sirket where sirket_id = p_id;
      end if;
    end if;
    h := oyun.pazar_tahmin(p_id, null, null, null, zt);
    gurultu := 0.9 + random()::numeric * 0.2;
    gelir := round((h->>'gelir')::numeric * gurultu);
    yonetim := case when ps.otopilot then round(gelir * a.yonetici_ucret / 100) else 0 end;
    gider := (h->>'gider')::numeric + yonetim;
    oran := coalesce((h->>'ruhsat_oran')::numeric, 0);
    ruhsat := round(gelir * oran / 100);
    ceza := case when (h->>'ceza')::numeric > 0 then round(gelir * 0.12) else 0 end;
    net := gelir - gider - ruhsat - ceza;
    v_vergi := round(greatest(0, net) * a.kurumlar / 100);
    net := net - v_vergi;

    if v_vergi > 0 then update oyun.ulke set hazine = hazine + v_vergi / tlm where id = 1; end if;
    if ruhsat > 0 then
      update oyun.il_durum set kasa = coalesce(kasa, 0) + ruhsat / tlm where il_id = ps.il_id;
      insert into oyun.il_ruhsat(il_id, toplam) values (ps.il_id, ruhsat)
        on conflict (il_id) do update set toplam = oyun.il_ruhsat.toplam + excluded.toplam;
    end if;
    update oyun.il_durum set
      gelisim = oyun.sinir(gelisim + 0.03 + case ps.kaynak when 'yenilenebilir' then 0.05 else 0 end, 0, 100),
      memnuniyet = oyun.sinir(memnuniyet + case when s.sektor = 'enerji' and ps.kaynak = 'komur' then -0.4 when ps.kalite >= 2 then 0.05 else 0 end, 0, 100)
    where il_id = ps.il_id;

    distributed := 0;
    if net < 0 then
      update oyun.sirketler set kasa = kasa + net where id = p_id;
    else
      distributable := least(net, greatest(0, (select kasa from oyun.sirketler where id = p_id) + net));
      for x in select * from oyun.sirket_ortaklari where sirket_id = p_id loop
        if not x.kar_kasada then
          v_odeme := least(round(distributable * x.pay / 100, 2), greatest(0, distributable - distributed));
          if v_odeme > 0 then
            perform oyun.para_islem(x.user_id, v_odeme, 'sirket', format('%s haftalık net kâr payı', s.ad), t);
            distributed := distributed + v_odeme;
          end if;
        end if;
      end loop;
      update oyun.sirketler set kasa = kasa + net - distributed where id = p_id;
    end if;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (p_id, t, net, format('7 günlük faaliyet (%s): pazar payı %%%s, %s rakip%s; gelir - gider - harç - vergi = net',
            ilad, h->>'pay', h->>'rakip', case when ps.otopilot then ', otopilot' else '' end), gelir, gider + ruhsat + ceza + v_vergi, distributed);
    insert into oyun.pazar_rapor(sirket_id, zaman, il_id, pazar, pay, rakip, gelir, gider, ruhsat, vergi, ceza, net, fiyat, kalite, kaynak)
    values (p_id, zt + interval '7 days', ps.il_id, (h->>'pazar')::numeric, (h->>'pay')::numeric, (h->>'rakip')::int,
            gelir, gider, ruhsat, v_vergi, ceza, net, ps.fiyat, ps.kalite, ps.kaynak);
    update oyun.pazar_sirket set marka = least(100, marka * 0.9 + 3 + 2.5 * kalite + case kaynak when 'yenilenebilir' then 3 else 0 end),
      hafta = hafta + 1 where sirket_id = p_id;
    select * into ps from oyun.pazar_sirket where sirket_id = p_id;

    select kasa into kasa_son from oyun.sirketler where id = p_id;
    if kasa_son <= 0 then
      update oyun.sirketler set aktif = false, kasa = 0, satilik = null, son_islem = t where id = p_id;
      update oyun.sirketler set sonraki_kazanc = s.sonraki_kazanc + i * interval '7 days' where id = p_id;
      update oyun.borsa_emir set durum = 'iptal' where sirket_id = p_id and durum = 'acik';
      perform oyun.olay('ekonomi', format('%s (%s, %s) iflas etti; kasası tükendi.', s.ad,
        (select ad from oyun.pazar_sektor where kod = s.sektor), ilad), ps.il_id, null, t);
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
        perform oyun.bildir(x.user_id, format('%s iflas etti: şirket kasası tükendi ve faaliyet durdu.', s.ad), t);
      end loop;
      return;
    end if;
  end loop;
  update oyun.sirketler set sonraki_kazanc = sonraki_kazanc + n * interval '7 days', son_islem = t where id = p_id;
  if kasa_son < s.sermaye * 0.25 and (ps.son_uyari is null or ps.son_uyari < t - interval '6 days') then
    update oyun.pazar_sirket set son_uyari = t where sirket_id = p_id;
    for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
      perform oyun.bildir(x.user_id, format('%s zarar ediyor: kasada %s ₺ kaldı. Önerilen ayarı uygula, otopilotu aç ya da ili değiştir; yoksa iflas edebilir.',
        s.ad, oyun.tl(kasa_son)), t);
    end loop;
  end if;
end $$;

-- ---------------------------------------------------------------- danışman ve otopilot RPC'leri
create or replace function public.pazar_danisman(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; ps oyun.pazar_sirket; h jsonb; en jsonb; saglik text;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  if s.id is null or ps.sirket_id is null then raise exception 'Rekabetçi şirket bulunamadı.'; end if;
  if not s.aktif then return jsonb_build_object('saglik', 'iflas', 'otopilot', ps.otopilot); end if;
  h := oyun.pazar_tahmin(s.id);
  en := oyun.pazar_en_iyi(s.id);
  saglik := case when s.kasa < s.sermaye * 0.25 then 'iflas_riski'
                 when (h->>'net')::numeric > s.sermaye * 0.01 then 'karda'
                 when (h->>'net')::numeric >= -s.sermaye * 0.005 then 'basabas' else 'zararda' end;
  return jsonb_build_object('saglik', saglik, 'otopilot', ps.otopilot, 'oneri', en,
    'oneri_farkli', en is not null and ((en->>'fiyat')::int <> ps.fiyat or (en->>'kalite')::int <> ps.kalite),
    'mevcut_net', (h->>'net')::numeric, 'yonetici_ucret', (select yonetici_ucret from oyun.pazar_ayar where id = 1),
    'otopilot_net', case when en is not null then round((en->>'net')::numeric - (en->>'gelir')::numeric * (select yonetici_ucret from oyun.pazar_ayar where id = 1) / 100 * 0.8) end,
    'yonetici', oyun.sirket_yonetici_mi(s.id, p.id));
end $$;

create or replace function public.pazar_otopilot(p_sirket bigint, p_acik boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; en jsonb;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif or not exists (select 1 from oyun.pazar_sirket where sirket_id = p_sirket) then raise exception 'Rekabetçi şirket bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Otopilotu en büyük ortak açıp kapatır.'; end if;
  perform oyun.sirket_hesapla(s.id);
  update oyun.pazar_sirket set otopilot = coalesce(p_acik, false) where sirket_id = s.id;
  if p_acik then
    en := oyun.pazar_en_iyi(s.id);
    if en is not null then update oyun.pazar_sirket set fiyat = (en->>'fiyat')::int, kalite = (en->>'kalite')::int, son_ayar = oyun.simdi() where sirket_id = s.id; end if;
  end if;
  return public.pazar_danisman(s.id);
end $$;

-- ---------------------------------------------------------------- borsa
create or replace function oyun.borsa_son_fiyat(p_sirket bigint, t timestamptz default null) returns numeric language sql stable set search_path = '' as $$
  select coalesce(
    (select birim from oyun.borsa_islem where sirket_id = p_sirket and (t is null or zaman <= t) order by zaman desc, id desc limit 1),
    (select round((h.deger + h.toplanan) / 100) from oyun.halka_arz h where h.sirket_id = p_sirket and h.durum = 'tamam' order by h.id desc limit 1),
    (select round(sermaye / 100) from oyun.sirketler where id = p_sirket))
$$;

create or replace function oyun.borsa_haftalik_net(p_sirket bigint) returns numeric language sql stable set search_path = '' as $$
  select coalesce(round(avg(tutar)), 0) from (select tutar from oyun.sirket_hareket where sirket_id = p_sirket and faaliyet_gelir > 0
    and aciklama like '7 günlük%' order by zaman desc, id desc limit 4) z
$$;

create or replace function public.borsa_liste() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object('sirketler', coalesce((select jsonb_agg(x order by (x->>'piyasa_degeri')::numeric desc) from (
    select jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sermaye', s.sermaye,
      'son', oyun.borsa_son_fiyat(s.id), 'dun', oyun.borsa_son_fiyat(s.id, t - interval '24 hours'),
      'piyasa_degeri', oyun.borsa_son_fiyat(s.id) * 100,
      'en_ucuz', (select min(birim) from oyun.borsa_emir where sirket_id = s.id and durum = 'acik'),
      'satista', coalesce((select sum(kalan) from oyun.borsa_emir where sirket_id = s.id and durum = 'acik'), 0),
      'hacim_7g', coalesce((select sum(tutar) from oyun.borsa_islem where sirket_id = s.id and zaman > t - interval '7 days'), 0),
      'haftalik_net', oyun.borsa_haftalik_net(s.id),
      'benim_pay', coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = p.id), 0)) x
    from oyun.sirketler s where s.halka_acik and s.aktif) z), '[]'::jsonb),
    'komisyon', (select komisyon from oyun.pazar_ayar where id = 1),
    'cuzdan', (select para from oyun.cuzdan where user_id = p.id));
end $$;

create or replace function public.borsa_sirket(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; t timestamptz := oyun.simdi();
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.halka_acik then raise exception 'Bu şirket borsada işlem görmüyor.'; end if;
  return jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'aktif', s.aktif, 'sermaye', s.sermaye, 'kasa', round(s.kasa),
    'son', oyun.borsa_son_fiyat(s.id), 'dun', oyun.borsa_son_fiyat(s.id, t - interval '24 hours'),
    'haftalik_net', oyun.borsa_haftalik_net(s.id), 'komisyon', (select komisyon from oyun.pazar_ayar where id = 1),
    'benim_pay', coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = p.id), 0),
    'benim_satista', coalesce((select sum(kalan) from oyun.borsa_emir where sirket_id = s.id and satici = p.id and durum = 'acik'), 0),
    'cuzdan', (select para from oyun.cuzdan where user_id = p.id),
    'emirler', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'satici', oyun.kad(e.satici), 'kalan', e.kalan, 'birim', e.birim,
        'benim', e.satici = p.id) order by e.birim, e.id) from oyun.borsa_emir e where e.sirket_id = s.id and e.durum = 'acik'), '[]'::jsonb),
    'islemler', coalesce((select jsonb_agg(jsonb_build_object('zaman', i.zaman, 'pay', i.pay, 'birim', i.birim, 'tutar', i.tutar,
        'satici', oyun.kad(i.satici), 'alici', oyun.kad(i.alici)) order by i.zaman desc) from
        (select * from oyun.borsa_islem where sirket_id = s.id order by zaman desc, id desc limit 20) i), '[]'::jsonb),
    'gunluk', coalesce((select jsonb_agg(jsonb_build_object('gun', g, 'fiyat', f) order by g) from (
        select distinct on ((zaman at time zone 'Europe/Istanbul')::date) (zaman at time zone 'Europe/Istanbul')::date g, birim f
        from oyun.borsa_islem where sirket_id = s.id and zaman > t - interval '30 days'
        order by (zaman at time zone 'Europe/Istanbul')::date, zaman desc) d), '[]'::jsonb),
    'haftalar', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'net', h.tutar) order by h.zaman) from
        (select zaman, tutar from oyun.sirket_hareket where sirket_id = s.id and faaliyet_gelir > 0 and aciklama like '7 günlük%' order by zaman desc, id desc limit 8) h), '[]'::jsonb),
    'ortaklar', (select jsonb_agg(jsonb_build_object('kad', oyun.kad(o.user_id), 'pay', o.pay) order by o.pay desc) from oyun.sirket_ortaklari o where o.sirket_id = s.id));
end $$;

create or replace function public.borsa_sat(p_sirket bigint, p_pay numeric, p_birim numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; v_pay numeric; acik numeric; v_id bigint;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif or not s.halka_acik then raise exception 'Borsada yalnız halka açık şirketlerin payları satılır.'; end if;
  if p_pay is null or p_pay < 0.1 or p_pay > 100 or round(p_pay, 2) <> p_pay then raise exception 'Pay %%0,1 ile %%100 arasında olmalı (en fazla iki ondalık).'; end if;
  if p_birim is null or p_birim < 100 or p_birim <> round(p_birim) then raise exception '%%1 pay fiyatı en az 100 ₺ ve tam sayı olmalı.'; end if;
  perform pg_advisory_xact_lock(98763, hashtext(s.id::text));
  select pay into v_pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = p.id;
  select coalesce(sum(kalan), 0) into acik from oyun.borsa_emir where sirket_id = s.id and satici = p.id and durum = 'acik';
  if coalesce(v_pay, 0) < acik + p_pay then
    raise exception 'Satabileceğin pay %%%s (sahip olduğun %%%s, satışta bekleyen %%%s).', greatest(0, coalesce(v_pay, 0) - acik), coalesce(v_pay, 0), acik;
  end if;
  if (select count(*) from oyun.borsa_emir where satici = p.id and durum = 'acik') >= 10 then raise exception 'Aynı anda en fazla 10 satış emrin olabilir.'; end if;
  insert into oyun.borsa_emir(sirket_id, satici, pay, kalan, birim, zaman) values (s.id, p.id, p_pay, p_pay, p_birim, oyun.simdi()) returning id into v_id;
  return public.borsa_sirket(s.id);
end $$;

create or replace function public.borsa_al(p_emir bigint, p_pay numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); e oyun.borsa_emir; s oyun.sirketler; v_pay numeric; tutar numeric; kom numeric; t timestamptz := oyun.simdi();
begin
  select * into e from oyun.borsa_emir where id = p_emir for update;
  if e.id is null or e.durum <> 'acik' then raise exception 'Bu satış emri artık geçerli değil.'; end if;
  if e.satici = p.id then raise exception 'Kendi emrini alamazsın; iptal edebilirsin.'; end if;
  if p_pay is null or p_pay <= 0 or round(p_pay, 2) <> p_pay or p_pay > e.kalan then raise exception 'Alınacak pay %%0,01 ile %%%s arasında olmalı.', e.kalan; end if;
  select * into s from oyun.sirketler where id = e.sirket_id;
  if not s.aktif or not s.halka_acik then raise exception 'Şirket işlem görmüyor.'; end if;
  perform pg_advisory_xact_lock(98763, hashtext(s.id::text));
  perform oyun.sirket_hesapla(s.id);     -- geciken hafta eski ortaklarla kapanır
  select pay into v_pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = e.satici for update;
  if coalesce(v_pay, 0) < p_pay then
    update oyun.borsa_emir set durum = 'iptal' where id = e.id;
    raise exception 'Satıcının payı artık yetmiyor; emir iptal edildi.';
  end if;
  tutar := round(p_pay * e.birim);
  kom := round(tutar * (select komisyon from oyun.pazar_ayar where id = 1) / 100);
  perform oyun.para_islem(p.id, -(tutar + kom), 'sirket', format('Borsa: %s %%%s pay alımı (komisyon %s ₺)', s.ad, p_pay, oyun.tl(kom)), t);
  perform oyun.para_islem(e.satici, tutar, 'sirket', format('Borsa: %s %%%s pay satışı', s.ad, p_pay), t);
  if kom > 0 then update oyun.ulke set hazine = hazine + kom / oyun.pazar_tl_milyar() where id = 1; end if;
  if v_pay = p_pay then delete from oyun.sirket_ortaklari where sirket_id = s.id and user_id = e.satici;
  else update oyun.sirket_ortaklari set pay = pay - p_pay where sirket_id = s.id and user_id = e.satici; end if;
  insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values (s.id, p.id, p_pay)
    on conflict (sirket_id, user_id) do update set pay = oyun.sirket_ortaklari.pay + excluded.pay;
  update oyun.borsa_emir set kalan = kalan - p_pay, durum = case when kalan - p_pay <= 0 then 'bitti' else 'acik' end where id = e.id;
  insert into oyun.borsa_islem(sirket_id, emir_id, satici, alici, pay, birim, tutar, komisyon, zaman)
    values (s.id, e.id, e.satici, p.id, p_pay, e.birim, tutar, kom, t);
  update oyun.sirketler set satilik = null where id = s.id;
  perform oyun.bildir(e.satici, format('Borsa: %s, %s şirketinden %%%s payını %s ₺ karşılığında aldı.', p.kad, s.ad, p_pay, oyun.tl(tutar)), t);
  if p_pay >= 5 then
    perform oyun.olay('ekonomi', format('Borsa: %s, %s şirketinin %%%s payını aldı (%%1 = %s ₺).', p.kad, s.ad, p_pay, oyun.tl(e.birim)), null, null, t);
  end if;
  return public.borsa_sirket(s.id);
end $$;

create or replace function public.borsa_iptal(p_emir bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); e oyun.borsa_emir;
begin
  update oyun.borsa_emir set durum = 'iptal' where id = p_emir and satici = p.id and durum = 'acik' returning * into e;
  if e.id is null then raise exception 'İptal edilecek açık emir bulunamadı.'; end if;
  return public.borsa_sirket(e.sirket_id);
end $$;

-- ---------------------------------------------------------------- Rekabet Kurumu
create or replace function public.rekabet_ekrani() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  perform oyun.rekabet_tick();
  return jsonb_build_object(
    'yetkili', oyun.bakanlik_yetkilisi('ticaret') = p.id,
    'kasa', (select round(kasa, 2) from oyun.bakanlik_kasa where kod = 'ticaret'),
    'bedel', 0.5,
    'sektorler', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad) order by sira) from oyun.pazar_sektor),
    'riskli', coalesce((select jsonb_agg(z order by z.firma desc) from (
        select ps.il_id, i.ad il, s.sektor, k.ad sektor_ad, count(*) firma,
          bool_and(ps.fiyat = 3) hepsi_premium, count(distinct oyun.sirket_sahibi(s.id)) sahip
        from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id join oyun.iller i on i.id = ps.il_id
        join oyun.pazar_sektor k on k.kod = s.sektor where s.aktif
        group by ps.il_id, i.ad, s.sektor, k.ad having bool_or(ps.fiyat = 3)) z), '[]'::jsonb),
    'sorusturmalar', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'il', i.ad, 'sektor', k.ad, 'acan', oyun.kad(r.acan),
        'bas', r.bas, 'bit', r.bit, 'durum', r.durum, 'karar', r.karar, 'ceza', r.ceza) order by r.id desc)
      from (select * from oyun.rekabet_sorusturma order by id desc limit 20) r join oyun.iller i on i.id = r.il_id
      join oyun.pazar_sektor k on k.kod = r.sektor), '[]'::jsonb));
end $$;

create or replace function public.rekabet_ac(p_il int, p_sektor text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v_id bigint; ilad text; sad text;
begin
  if oyun.bakanlik_yetkilisi('ticaret') is distinct from p.id then raise exception 'Rekabet soruşturmasını Ticaret Bakanı açar (bakanlık boşsa Cumhurbaşkanı).'; end if;
  select ad into sad from oyun.pazar_sektor where kod = p_sektor;
  if sad is null then raise exception 'Geçersiz sektör.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  if not exists (select 1 from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id where ps.il_id = p_il and s.sektor = p_sektor and s.aktif) then
    raise exception 'Bu ilde bu türde faaliyet gösteren şirket yok.';
  end if;
  if exists (select 1 from oyun.rekabet_sorusturma where il_id = p_il and sektor = p_sektor and durum = 'acik') then raise exception 'Bu pazar için soruşturma zaten sürüyor.'; end if;
  if (select count(*) from oyun.rekabet_sorusturma where acan = p.id and bas > t - interval '24 hours') >= 3 then raise exception 'Günde en fazla 3 soruşturma açılabilir.'; end if;
  update oyun.bakanlik_kasa set kasa = kasa - 0.5 where kod = 'ticaret' and kasa >= 0.5;
  if not found then raise exception 'Ticaret Bakanlığı kasasında 0,5 milyar ₺ gerekli.'; end if;
  insert into oyun.rekabet_sorusturma(il_id, sektor, acan, bas, bit) values (p_il, p_sektor, p.id, t, t + interval '24 hours') returning id into v_id;
  perform oyun.olay('ekonomi', format('Rekabet Kurumu %s''daki %s pazarı hakkında soruşturma başlattı; karar 24 saat içinde.', ilad, lower(sad)), p_il::smallint, p.parti_id, t);
  perform oyun.gazete_ekle('icraat', format('Rekabet soruşturması: %s %s pazarı', ilad, sad),
    format('Ticaret Bakanlığı, %s''daki %s şirketleri hakkında kartel ve hâkim durumun kötüye kullanılması iddialarıyla soruşturma başlattı.', ilad, lower(sad)), v_id, t);
  for sad in select distinct oyun.sirket_sahibi(s.id)::text from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
             where ps.il_id = p_il and s.sektor = p_sektor and s.aktif loop
    perform oyun.bildir(sad::uuid, format('Rekabet Kurumu %s''daki şirketin hakkında soruşturma açtı. Karar 24 saat sonra; fiyat politikanı gözden geçirebilirsin.', ilad), t);
  end loop;
  return public.rekabet_ekrani();
end $$;

create or replace function oyun.rekabet_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare r oyun.rekabet_sorusturma; t timestamptz := oyun.simdi(); x record; ilad text; sad text; n int := 0; firma int; sahip int;
  premium_hepsi boolean; ihlaller text[]; toplam numeric; c numeric; tlm numeric;
begin
  if not pg_try_advisory_xact_lock(84851) then return 0; end if;
  tlm := oyun.pazar_tl_milyar();
  for r in select * from oyun.rekabet_sorusturma where durum = 'acik' and bit <= t order by bit for update loop
    select ad into ilad from oyun.iller where id = r.il_id;
    select ad into sad from oyun.pazar_sektor where kod = r.sektor;
    select count(*), count(distinct oyun.sirket_sahibi(s.id)), bool_and(ps.fiyat = 3) into firma, sahip, premium_hepsi
      from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id where ps.il_id = r.il_id and s.sektor = r.sektor and s.aktif;
    ihlaller := '{}'; toplam := 0;
    for x in select s.id, s.ad, s.kasa, ps.fiyat, oyun.sirket_sahibi(s.id) sahip_id,
                    (oyun.pazar_tahmin(s.id)->>'pay')::numeric pay,
                    (select count(*) from oyun.pazar_sirket p3 join oyun.sirketler s3 on s3.id = p3.sirket_id
                      where p3.il_id = r.il_id and s3.sektor = r.sektor and s3.aktif and oyun.sirket_sahibi(s3.id) = oyun.sirket_sahibi(s.id)) ayni
             from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id
             where ps.il_id = r.il_id and s.sektor = r.sektor and s.aktif loop
      if x.ayni >= 2 or (firma >= 2 and sahip >= 2 and premium_hepsi) or (x.pay >= 55 and x.fiyat = 3) then
        c := round(greatest(0, x.kasa) * 0.08);
        update oyun.sirketler set kasa = kasa - c where id = x.id;
        update oyun.pazar_sirket set fiyat = least(fiyat, 2), son_ayar = t where sirket_id = x.id;
        if c > 0 then update oyun.ulke set hazine = hazine + c / tlm where id = 1; end if;
        insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
          values (x.id, t, -c, format('Rekabet Kurumu idari para cezası (soruşturma #%s)', r.id), 0, c, 0);
        perform oyun.bildir(x.sahip_id, format('Rekabet Kurumu %s şirketine %s ₺ ceza verdi; fiyat ortaya çekildi.', x.ad, oyun.tl(c)), t);
        ihlaller := ihlaller || (x.ad || case when x.ayni >= 2 then ' (paravan yapı)' when x.pay >= 55 and x.fiyat = 3 then ' (hâkim durum)' else ' (kartel)' end);
        toplam := toplam + c;
      end if;
    end loop;
    if array_length(ihlaller, 1) > 0 then
      update oyun.rekabet_sorusturma set durum = 'ihlal', ceza = toplam,
        karar = format('İhlal bulundu: %s. Toplam ceza %s ₺; fiyatlar ortaya çekildi.', array_to_string(ihlaller, ', '), oyun.tl(toplam)) where id = r.id;
      perform oyun.gazete_ekle('icraat', format('Rekabet Kurumu kararı: %s %s pazarı', ilad, sad),
        format('%s''daki %s pazarında rekabet ihlali tespit edildi: %s. Şirketlere toplam %s ₺ idari para cezası verildi.', ilad, lower(sad),
          array_to_string(ihlaller, ', '), oyun.tl(toplam)), r.id, r.bit);
      perform oyun.olay('ekonomi', format('Rekabet Kurumu %s''daki %s pazarında ihlal buldu; toplam ceza %s ₺.', ilad, lower(sad), oyun.tl(toplam)), r.il_id, null, r.bit);
    else
      update oyun.rekabet_sorusturma set durum = 'temiz', karar = 'İhlal bulunmadı; pazarda rekabet işliyor.' where id = r.id;
      perform oyun.olay('ekonomi', format('Rekabet Kurumu %s''daki %s pazarında ihlal bulmadı.', ilad, lower(sad)), r.il_id, null, r.bit);
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------- şirket bağışları
create or replace function public.sirket_parti_bagis(p_sirket bigint, p_parti bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; pa oyun.partiler; t timestamptz := oyun.simdi(); hafta numeric; sinir numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif then raise exception 'Şirket bulunamadı.'; end if;
  if s.sektor = 'banka' then raise exception 'Bankalar siyasi bağış yapamaz.'; end if;
  if not oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Şirket adına bağışı en büyük ortak yapar.'; end if;
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null or pa.kapali then raise exception 'Parti bulunamadı.'; end if;
  if p_tutar is null or p_tutar < 1000 or p_tutar <> round(p_tutar) then raise exception 'Bağış en az 1.000 ₺ ve tam sayı olmalı.'; end if;
  perform pg_advisory_xact_lock(98763, hashtext(s.id::text));
  perform oyun.sirket_hesapla(s.id);
  select * into s from oyun.sirketler where id = p_sirket;
  select coalesce(sum(tutar), 0) into hafta from oyun.sirket_bagis where sirket_id = s.id and zaman > t - interval '7 days';
  sinir := round(s.sermaye * 0.20);
  if hafta + p_tutar > sinir then raise exception 'Bu şirket 7 günde en fazla % ₺ bağış yapabilir (kalan % ₺).', oyun.tl(sinir), oyun.tl(greatest(0, sinir - hafta)); end if;
  if s.kasa < p_tutar then raise exception 'Şirket kasasında yeterli para yok.'; end if;
  update oyun.sirketler set kasa = kasa - p_tutar where id = s.id;
  update oyun.partiler set kasa = kasa + p_tutar where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, p_tutar, format('%s şirketinden bağış (%s)', s.ad, p.kad), 'bagis');
  insert into oyun.sirket_bagis(sirket_id, parti_id, veren, tutar, zaman) values (s.id, pa.id, p.id, p_tutar, t);
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (s.id, t, -p_tutar, format('Siyasi bağış: %s', pa.ad), 0, p_tutar, 0);
  perform oyun.olay('ekonomi', format('%s şirketi %s''ye %s ₺ bağış yaptı (en büyük ortak: %s).', s.ad, pa.kisa, oyun.tl(p_tutar), p.kad), null, pa.id, t);
  return jsonb_build_object('tamam', true, 'kalan_sinir', sinir - hafta - p_tutar);
end $$;

create or replace function public.siyasi_bagislar() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'son', coalesce((select jsonb_agg(jsonb_build_object('sirket', s.ad, 'sektor', s.sektor, 'veren', oyun.kad(b.veren), 'parti', pa.ad,
        'kisa', pa.kisa, 'renk', pa.renk, 'tutar', b.tutar, 'zaman', b.zaman) order by b.zaman desc)
      from (select * from oyun.sirket_bagis order by zaman desc limit 50) b join oyun.sirketler s on s.id = b.sirket_id
      join oyun.partiler pa on pa.id = b.parti_id), '[]'::jsonb),
    'parti_toplam', coalesce((select jsonb_agg(jsonb_build_object('parti', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'tutar', z.tutar, 'sirket', z.sirket) order by z.tutar desc)
      from (select parti_id, sum(tutar) tutar, count(distinct sirket_id) sirket from oyun.sirket_bagis where zaman > t - interval '30 days' group by parti_id) z
      join oyun.partiler pa on pa.id = z.parti_id), '[]'::jsonb),
    'sirketlerim', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'kasa', round(s.kasa), 'sinir', round(s.sermaye * 0.2),
        'kalan', greatest(0, round(s.sermaye * 0.2) - coalesce((select sum(tutar) from oyun.sirket_bagis where sirket_id = s.id and zaman > t - interval '7 days'), 0))) order by s.id)
      from oyun.sirketler s where s.aktif and s.sektor <> 'banka' and oyun.sirket_yonetici_mi(s.id, p.id)), '[]'::jsonb),
    'partiler', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'ad', ad, 'kisa', kisa) order by ad) from oyun.partiler where not kapali), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------- yerel piyasa fiyatları → geçim, enflasyon
create or replace function oyun.piyasa_endeks_tick() returns void
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); gun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; r record; v_deger numeric;
  ulke_idx numeric; v_id bigint;
begin
  if (select son_endeks_gun from oyun.pazar_ayar where id = 1) is not distinct from gun then return; end if;
  if not pg_try_advisory_xact_lock(84852) then return; end if;
  create temp table if not exists pg_temp._pz_fiyat(il_id smallint, sektor text, fk numeric, w numeric) on commit drop;
  truncate pg_temp._pz_fiyat;
  insert into pg_temp._pz_fiyat
    select ps.il_id, s.sektor, oyun.pazar_fiyat_katsayi(ps.fiyat), greatest(1, coalesce((oyun.pazar_tahmin(s.id)->>'gelir')::numeric, 1))
    from oyun.pazar_sirket ps join oyun.sirketler s on s.id = ps.sirket_id where s.aktif and s.sektor in ('market','enerji');
  for r in select il_id, sum(fk * w) / sum(w) idx, count(*) filter (where sektor = 'market') market from pg_temp._pz_fiyat group by il_id loop
    v_deger := oyun.sinir(round((1 - r.idx) * 25 + case when r.market >= 2 then 1 else 0 end, 1), -7.5, 5);
    select id into v_id from oyun.etkiler where kaynak_tur = 'piyasa' and kaynak_kod = 'il_' || r.il_id order by id desc limit 1;
    if v_id is null then
      insert into oyun.etkiler(il_id, tur, deger, bas, bit, kaynak_tur, kaynak_kod, kaynak_ad)
        values (r.il_id, 'gecim', v_deger, t, t + interval '36 hours', 'piyasa', 'il_' || r.il_id, 'Yerel piyasa fiyatları (market ve enerji)');
    else
      update oyun.etkiler set deger = v_deger, bas = t, bit = t + interval '36 hours' where id = v_id;
    end if;
  end loop;
  update oyun.etkiler set bit = t where kaynak_tur = 'piyasa' and bit > t
    and il_id not in (select distinct il_id from pg_temp._pz_fiyat);
  select sum(fk * w) / nullif(sum(w), 0) into ulke_idx from pg_temp._pz_fiyat;
  if ulke_idx is not null then
    update oyun.ulke set enflasyon = oyun.sinir(enflasyon + (ulke_idx - 1) * 0.4, 0, 200) where id = 1;
  end if;
  update oyun.pazar_ayar set endeks = coalesce(round(ulke_idx, 3), 1), son_endeks_gun = gun where id = 1;
end $$;

-- ---------------------------------------------------------------- piyasa raporu
create or replace function public.piyasa_raporu() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.ulke;
begin
  select * into u from oyun.ulke where id = 1;
  return jsonb_build_object(
    'endeks', (select endeks from oyun.pazar_ayar where id = 1),
    'enflasyon', round(u.enflasyon, 1), 'buyume', round(u.buyume, 1), 'issizlik', round(u.issizlik, 1), 'asgari', u.asgari,
    'benim_il', p.il_id, 'benim_il_ad', (select ad from oyun.iller where id = p.il_id),
    'benim_gecim', (select deger from oyun.etkiler where kaynak_tur = 'piyasa' and il_id = p.il_id and bit > t order by id desc limit 1),
    'kurumlar_7g', coalesce((select sum(vergi) from oyun.pazar_rapor where zaman > t - interval '7 days'), 0),
    'ruhsat_7g', coalesce((select sum(ruhsat) from oyun.pazar_rapor where zaman > t - interval '7 days'), 0),
    'sektorler', (select jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', k.ad,
        'sayi', (select count(*) from oyun.sirketler s where s.sektor = k.kod and s.aktif),
        'politika', oyun.sektor_pol_durum(k.kod, t),
        'lider', (select jsonb_build_object('ad', s.ad, 'il', i.ad, 'net', r.net, 'sahip', oyun.kad(oyun.sirket_sahibi(s.id)))
                  from oyun.pazar_rapor r join oyun.sirketler s on s.id = r.sirket_id join oyun.iller i on i.id = r.il_id
                  where s.sektor = k.kod and r.zaman > t - interval '7 days' order by r.net desc limit 1)) order by k.sira)
      from oyun.pazar_sektor k),
    'eski_sayi', (select count(*) from oyun.sirketler s where s.aktif and not exists (select 1 from oyun.pazar_sektor k where k.kod = s.sektor)),
    'borsa', jsonb_build_object('sirket', (select count(*) from oyun.sirketler where halka_acik and aktif),
        'deger', coalesce((select sum(oyun.borsa_son_fiyat(id) * 100) from oyun.sirketler where halka_acik and aktif), 0),
        'hacim_7g', coalesce((select sum(tutar) from oyun.borsa_islem where zaman > t - interval '7 days'), 0)),
    'ihale', jsonb_build_object('acik', (select count(*) from oyun.kamu_ihale where durum = 'acik'),
        'yapim', (select count(*) from oyun.kamu_ihale where durum = 'yapim'),
        'tutar_30g', coalesce((select sum(bedel) from oyun.kamu_ihale where durum in ('yapim','tamam') and bas > t - interval '30 days'), 0)),
    'ucuz_iller', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'deger', e.deger) order by e.deger desc)
        from (select * from oyun.etkiler where kaynak_tur = 'piyasa' and bit > t and deger > 0 order by deger desc limit 3) e join oyun.iller i on i.id = e.il_id), '[]'::jsonb),
    'pahali_iller', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'deger', e.deger) order by e.deger)
        from (select * from oyun.etkiler where kaynak_tur = 'piyasa' and bit > t and deger < 0 order by deger limit 3) e join oyun.iller i on i.id = e.il_id), '[]'::jsonb),
    'rekabet', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'sektor', k.ad, 'durum', r.durum, 'karar', r.karar, 'zaman', r.bit) order by r.id desc)
        from (select * from oyun.rekabet_sorusturma order by id desc limit 5) r join oyun.iller i on i.id = r.il_id join oyun.pazar_sektor k on k.kod = r.sektor), '[]'::jsonb),
    'bagislar', coalesce((select jsonb_agg(jsonb_build_object('sirket', s.ad, 'parti', pa.kisa, 'renk', pa.renk, 'tutar', b.tutar, 'zaman', b.zaman) order by b.zaman desc)
        from (select * from oyun.sirket_bagis order by zaman desc limit 5) b join oyun.sirketler s on s.id = b.sirket_id join oyun.partiler pa on pa.id = b.parti_id), '[]'::jsonb));
end $$;

-- Şirket rehberindeki "kayıtlı vergi" rekabetçi şirketlerin kurumlar vergisini de saysın
create or replace function public.sirket_vitrini() returns jsonb language sql stable security definer set search_path = '' as $$
 select jsonb_build_object('sirketler',
 coalesce((select jsonb_agg(jsonb_build_object(
   'id',s.id,'ad',s.ad,'sektor',s.sektor,'kurucu',p.kad,
   'sahip',coalesce((select x.kad from oyun.sirket_ortaklari o join oyun.profiller x on x.id=o.user_id
       where o.sirket_id=s.id and o.pay>0 order by o.pay desc,o.user_id limit 1),p.kad),
   'sermaye',s.sermaye,'kasa',s.kasa,'kurulus',s.kurulus,
   'aktif',s.aktif,'satilik',s.satilik,'halka_acik',s.halka_acik,
   'il',(select i.ad from oyun.pazar_sirket ps join oyun.iller i on i.id=ps.il_id where ps.sirket_id=s.id),
   'ortaklar',coalesce((select jsonb_agg(jsonb_build_object('kad',x.kad,'pay',o.pay) order by o.pay desc)
      from oyun.sirket_ortaklari o join oyun.profiller x on x.id=o.user_id where o.sirket_id=s.id),'[]'::jsonb),
   'toplam_gelir',coalesce((select sum(greatest(0,h.faaliyet_gelir)) from oyun.sirket_hareket h where h.sirket_id=s.id),0),
   'net_kazanc',coalesce((select sum(h.tutar) from oyun.sirket_hareket h where h.sirket_id=s.id and h.faaliyet_gelir is not null),0),
   'vergi',coalesce((select sum(h.vergi) from oyun.hesap_hareket h
      where h.tur='sirket' and h.vergi>0 and h.aciklama like 'Sirket #'||s.id::text||' %'),0)
      + coalesce((select sum(r.vergi) from oyun.pazar_rapor r where r.sirket_id=s.id),0)
 ) order by s.id) from oyun.sirketler s join oyun.profiller p on p.id=s.kurucu where s.aktif and s.sektor<>'banka'),'[]'::jsonb),
 'vergi_notu','Kayda alınmış gerçek şirket vergileri gösterilir: eski şirketlerin kâr payı vergisi ve rekabetçi şirketlerin kurumlar vergisi.')
$$;

-- ---------------------------------------------------------------- zamanlayıcı
create or replace function oyun.pazar_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  perform oyun.ihale_tick();
  perform oyun.rekabet_tick();
  for r in select s.id from oyun.sirketler s join oyun.pazar_sirket ps on ps.sirket_id = s.id
           where s.aktif and s.sonraki_kazanc <= oyun.simdi() order by s.sonraki_kazanc limit 200 loop
    perform oyun.sirket_hesapla(r.id); n := n + 1;
  end loop;
  perform oyun.piyasa_endeks_tick();
  return n;
end $$;

-- ---------------------------------------------------------------- yetkiler
revoke all on function public.pazar_danisman(bigint), public.pazar_otopilot(bigint, boolean), public.borsa_liste(), public.borsa_sirket(bigint),
  public.borsa_sat(bigint, numeric, numeric), public.borsa_al(bigint, numeric), public.borsa_iptal(bigint), public.rekabet_ekrani(),
  public.rekabet_ac(int, text), public.sirket_parti_bagis(bigint, bigint, numeric), public.siyasi_bagislar(), public.piyasa_raporu() from public, anon;
grant execute on function public.pazar_danisman(bigint), public.pazar_otopilot(bigint, boolean), public.borsa_liste(), public.borsa_sirket(bigint),
  public.borsa_sat(bigint, numeric, numeric), public.borsa_al(bigint, numeric), public.borsa_iptal(bigint), public.rekabet_ekrani(),
  public.rekabet_ac(int, text), public.sirket_parti_bagis(bigint, bigint, numeric), public.siyasi_bagislar(), public.piyasa_raporu() to authenticated;
revoke all on function oyun.sirket_sahibi(bigint), oyun.pazar_en_iyi(bigint, timestamptz), oyun.tg_pazar_paravan(), oyun.borsa_son_fiyat(bigint, timestamptz),
  oyun.borsa_haftalik_net(bigint), oyun.rekabet_tick(), oyun.piyasa_endeks_tick() from public, anon, authenticated;
commit;
