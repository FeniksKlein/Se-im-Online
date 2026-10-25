-- =====================================================================
--  135 · BANKACILIK 2.0 (25.10.2026)
--  1) Kasa gizliliği: şirket, banka, dernek ve gazete kasaları sahibi /
--     yöneticisi dışında görünmez; sahibi isterse herkese (dernekte
--     yalnız üyelere) açar. Herkese açık 45+ ekran fonksiyonu
--     oyun.kasa_goster() ile yamalanır (iki kez çalıştırmak güvenli).
--  2) Banka bilançosu: vadesiz mevduat artık bankanın borcu sayılır
--     (önceden kâr payı / kredi kapasitesi hesabında unutuluyordu).
--  3) Banka Genel Müdürlüğü: tek ekranda bilanço, oranlar, güven notu,
--     gelir tablosu, başvurular, ürün ve risk ayarları, DİBS (devlet
--     tahvili), kâr payı (stopajlı), sermaye artır / azalt, emniyet payı,
--     banka rengi ve sloganı.
--  4) Mobil Şube: müşterinin tüm hesap, kart, kredi ve birikimleri tek
--     sorguda; FAST ile her bankaya (Devlet Bankası dahil) para gönderme
--     ve hesaplar arası aktarım.
--  5) Devlet Bankası kredi kartı ödemelerindeki Hazine birim hatası.
--  Oyuncu bakiyelerine dokunmaz; yalnız yeni tablo / fonksiyon ekler.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.kasa_gizlilik(
  tur         text not null check (tur in ('sirket','dernek','gazete')),
  kimlik      bigint not null,
  gorunurluk  text not null default 'gizli' check (gorunurluk in ('gizli','uyeler','herkes')),
  guncelleyen uuid,
  guncelleme  timestamptz not null default now(),
  primary key (tur, kimlik)
);
alter table oyun.kasa_gizlilik enable row level security;

create table if not exists oyun.banka_politika(
  banka_id     bigint primary key references oyun.sirketler(id),
  emniyet_payi numeric not null default 0 check (emniyet_payi >= 0 and emniyet_payi <= 100000000),
  risk_profili text not null default 'ozel' check (risk_profili in ('ozel','temkinli','dengeli','atak','manuel')),
  renk         text not null default 'lacivert'
               check (renk in ('lacivert','bordo','zumrut','turuncu','mor','altin','turkuaz','gece','kirmizi','gumus')),
  slogan       text check (slogan is null or char_length(slogan) <= 80),
  guncelleme   timestamptz not null default now()
);
alter table oyun.banka_politika enable row level security;

create table if not exists oyun.banka_dibs(
  id       bigserial primary key,
  banka_id bigint not null references oyun.sirketler(id),
  tutar    numeric(18,2) not null check (tutar > 0),
  gun      smallint not null check (gun in (1,7,30)),
  oran     numeric(9,4) not null check (oran >= 0),
  acilis   timestamptz not null,
  vade     timestamptz not null,
  durum    text not null default 'acik' check (durum in ('acik','odendi','bozuldu')),
  odenen   numeric(18,2),
  kapanis  timestamptz,
  alan     uuid
);
create index if not exists banka_dibs_banka_durum on oyun.banka_dibs(banka_id, durum);
create index if not exists banka_dibs_vade on oyun.banka_dibs(vade) where durum = 'acik';
alter table oyun.banka_dibs enable row level security;

create table if not exists oyun.banka_temettu(
  id       bigserial primary key,
  banka_id bigint not null references oyun.sirketler(id),
  tur      text not null check (tur in ('temettu','sermaye_iade')),
  brut     numeric(18,2) not null default 0,
  stopaj   numeric(18,2) not null default 0,
  net      numeric(18,2) not null default 0,
  yapan    uuid,
  zaman    timestamptz not null
);
create index if not exists banka_temettu_banka on oyun.banka_temettu(banka_id, id desc);
alter table oyun.banka_temettu enable row level security;

-- FAST: Devlet Bankası ile özel bankalar arasındaki anlık transferler
create table if not exists oyun.banka_fast(
  id           bigserial primary key,
  gonderen     uuid not null,
  alici        uuid not null,
  kaynak_banka bigint,          -- null = Devlet Bankası
  hedef_banka  bigint,          -- null = Devlet Bankası
  tutar        numeric(18,2) not null check (tutar > 0),
  aciklama     text,
  zaman        timestamptz not null
);
create index if not exists banka_fast_gonderen on oyun.banka_fast(gonderen, zaman desc);
alter table oyun.banka_fast enable row level security;

-- ---------------------------------------------------------------------
-- B. YARDIMCI FONKSİYONLAR
-- ---------------------------------------------------------------------
create or replace function oyun.banka_vadesiz_toplam(p_banka bigint)
returns numeric language plpgsql stable set search_path = '' as $$
begin
  if to_regclass('oyun.ib_vadesiz') is null then return 0; end if;
  return coalesce((select sum(bakiye) from oyun.ib_vadesiz where banka_id = p_banka), 0);
end $$;

-- Kasa rakamını görmeye yetkili mi? (sahip / ortak / yönetici)
create or replace function oyun.kasa_yetkili(p_tur text, p_id bigint, u uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $$
begin
  if u is null or p_id is null then return false; end if;
  if p_tur = 'sirket' then
    return exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_id and o.user_id = u and o.pay > 0)
        or exists(select 1 from oyun.sirketler s where s.id = p_id and s.yonetici = u);
  elsif p_tur = 'dernek' then
    return exists(select 1 from oyun.dernekler d where d.id = p_id and d.baskan = u)
        or exists(select 1 from oyun.dernek_uyeler x where x.dernek_id = p_id and x.user_id = u and x.rol in ('baskan','yonetim'));
  elsif p_tur = 'gazete' then
    return exists(select 1 from oyun.oyuncu_gazeteleri g where g.id = p_id and g.sahip = u);
  end if;
  return false;
end $$;

-- Ekranlara giden kasa rakamı: yetkisi yoksa null döner (arayüz "Gizli" yazar).
-- Zamanlayıcı / SQL Editor gibi oturumsuz sistem çağrılarında değer aynen döner.
create or replace function oyun.kasa_goster(p_tur text, p_id bigint, p_deger numeric)
returns numeric language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid(); g text;
begin
  if p_deger is null then return null; end if;
  if u is null then
    if coalesce(auth.role(), '') in ('', 'service_role', 'postgres', 'supabase_admin') then return p_deger; end if;
    return null;
  end if;
  if exists(select 1 from oyun.profiller where id = u and yonetici) then return p_deger; end if;
  if oyun.kasa_yetkili(p_tur, p_id, u) then return p_deger; end if;
  select gorunurluk into g from oyun.kasa_gizlilik where tur = p_tur and kimlik = p_id;
  if g = 'herkes' then return p_deger; end if;
  if g = 'uyeler' and p_tur = 'dernek'
     and exists(select 1 from oyun.dernek_uyeler x where x.dernek_id = p_id and x.user_id = u) then
    return p_deger;
  end if;
  return null;
end $$;

-- Hesap numarası (IBAN biçiminde, kişiye ve bankaya özel, kalıcı). 0 = Devlet Bankası.
create or replace function oyun.banka_iban(p_banka bigint, u uuid)
returns text language plpgsql stable set search_path = '' as $$
declare h bigint; s text;
begin
  h := (hashtext(u::text || ':' || coalesce(p_banka, 0)::text)::bigint & 2147483647);
  s := lpad(h::text, 10, '0');
  return 'TR' || lpad(((hashtext(coalesce(p_banka, 0)::text || '/' || u::text)::bigint & 2147483647) % 89 + 10)::text, 2, '0')
      || ' ' || lpad(coalesce(p_banka, 0)::text, 4, '0')
      || ' ' || substr(s, 1, 4) || ' ' || substr(s, 5, 4) || ' ' || substr(s, 9, 2);
end $$;

create or replace function oyun.banka_dibs_orani(p_gun integer)
returns numeric language sql stable set search_path = '' as $$
  select round(oyun.politika_faizi() * p_gun / 365.0
               * case p_gun when 30 then 1.05 when 1 then 0.90 else 1 end, 4)
$$;

-- ---------------------------------------------------------------------
-- C. BİLANÇO, ORANLAR, GÜVEN NOTU, GELİR TABLOSU
-- ---------------------------------------------------------------------
create or replace function oyun.banka_bilanco(p_banka bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  s oyun.sirketler; t timestamptz := oyun.simdi();
  nakit numeric; kredi numeric := 0; kredi_gec numeric := 0; kart numeric := 0; kart_gec numeric := 0; dibs numeric := 0;
  vadesiz numeric := 0; vadeli_ana numeric := 0; vadeli_yuk numeric := 0; yakin numeric := 0; gecik_mev numeric := 0;
  tampon numeric; rezerv numeric; riskli numeric; ozk numeric; emniyet numeric := 0; al numeric;
  kv numeric; dag numeric; azalt numeric; lik numeric; syr numeric; npl numeric; km numeric;
  puan int := 100; harf text; v_durum text;
begin
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka';
  if s.id is null then raise exception 'Banka bulunamadı.'; end if;
  nakit := coalesce(s.kasa, 0);

  select coalesce(sum(k.kalan), 0),
         coalesce(sum(k.kalan) filter (where k.vade < t or exists(
           select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t)), 0)
    into kredi, kredi_gec
    from oyun.oyb_kredi k where k.banka_id = p_banka and k.durum in ('aktif','takip');

  if to_regclass('oyun.kredi_kartlari') is not null then
    select coalesce(sum(borc), 0),
           coalesce(sum(borc) filter (where gecikmis_asgari > 0 or durum in ('takip','kapali')), 0)
      into kart, kart_gec
      from oyun.kredi_kartlari where banka_id = p_banka and borc > 0;
  end if;

  select coalesce(sum(tutar), 0) into dibs from oyun.banka_dibs where banka_id = p_banka and durum = 'acik';
  vadesiz := oyun.banka_vadesiz_toplam(p_banka);

  select coalesce(sum(anapara), 0),
         coalesce(sum(round(anapara * (1 + faiz / 100), 2)), 0),
         coalesce(sum(round(anapara * (1 + faiz / 100), 2)) filter (where vade <= t + interval '24 hours'), 0),
         coalesce(sum(round(anapara * (1 + faiz / 100), 2)) filter (where vade <= t), 0)
    into vadeli_ana, vadeli_yuk, yakin, gecik_mev
    from oyun.banka_mevduat where banka_id = p_banka and not kapandi;

  emniyet := coalesce((select emniyet_payi from oyun.banka_politika where banka_id = p_banka), 0);

  -- Yasal tampon: sermayenin ya da toplam mevduatın %10'u (hangisi büyükse)
  tampon := greatest(round(s.sermaye * .10, 2), round((vadeli_ana + vadesiz) * .10, 2));
  -- Likidite rezervi: vadesizin %30'u + (vadelilerin yarısı ya da 24 saatte ödenecekler) + tampon
  rezerv := round(vadesiz * .30, 2) + greatest(round(vadeli_ana * .50, 2), yakin) + tampon;
  -- Risk ağırlıklı varlıklar (DİBS risksiz)
  riskli := (kredi - kredi_gec) + kredi_gec * 1.5 + (kart - kart_gec) + kart_gec * 1.5;
  -- Özkaynak = varlıklar - borçlar
  ozk := nakit + kredi + kart + dibs - vadesiz - vadeli_yuk;
  -- Kredi kapasitesi (eski oyb_saglik formülü + vadesiz mevduat + emniyet payı)
  al := (kredi - kredi_gec) * .70 + kredi_gec * .25;
  kv := greatest(0, least(nakit - rezerv - emniyet, (nakit + al - vadeli_yuk - vadesiz - tampon) / .30));
  -- Dağıtılabilir kâr: birikmiş kâr, kasadaki serbest nakit ve %12 sermaye yeterliliği sınırı
  dag := greatest(0, least(ozk - s.sermaye, nakit - rezerv, ozk - riskli * .12));
  -- Sermaye azaltımı: asgari 1.000.000 ₺ sermaye, nakit ve %12 sınırı
  azalt := greatest(0, least(s.sermaye - 1000000, nakit - rezerv, ozk - riskli * .12));

  lik := case when (vadesiz + yakin + vadeli_ana * .5) > 0 then round(nakit / (vadesiz + yakin + vadeli_ana * .5), 2) end;
  syr := case when riskli > 0 then round(ozk / riskli * 100, 1) end;
  npl := case when (kredi + kart) > 0 then round((kredi_gec + kart_gec) / (kredi + kart) * 100, 1) else 0 end;
  km  := case when (vadesiz + vadeli_ana) > 0 then round((kredi + kart) / (vadesiz + vadeli_ana) * 100, 1) end;

  if lik is not null then puan := puan - case when lik < 1 then 35 when lik < 1.2 then 15 else 0 end; end if;
  if syr is not null then puan := puan - case when syr < 8 then 40 when syr < 12 then 20 when syr < 15 then 8 else 0 end; end if;
  puan := puan - case when npl > 20 then 30 when npl > 10 then 15 when npl > 5 then 6 else 0 end;
  if gecik_mev > 0 and nakit < gecik_mev then puan := puan - 40; end if;
  if ozk < s.sermaye * .5 then puan := puan - 20; end if;
  harf := case when puan >= 95 then 'AAA' when puan >= 88 then 'AA' when puan >= 80 then 'A' when puan >= 70 then 'BBB'
               when puan >= 60 then 'BB' when puan >= 45 then 'B' else 'C' end;
  v_durum := case when puan >= 80 then 'saglam' when puan >= 60 then 'dikkat' else 'riskli' end;

  return jsonb_build_object(
    'nakit', round(nakit, 2), 'krediler', round(kredi, 2), 'krediler_geciken', round(kredi_gec, 2),
    'kart_alacak', round(kart, 2), 'kart_geciken', round(kart_gec, 2), 'dibs', round(dibs, 2),
    'varlik', round(nakit + kredi + kart + dibs, 2),
    'vadesiz', round(vadesiz, 2), 'vadeli_anapara', round(vadeli_ana, 2), 'vadeli_yukumluluk', round(vadeli_yuk, 2),
    'yaklasan_odeme', round(yakin, 2), 'geciken_mevduat', round(gecik_mev, 2),
    'borc', round(vadesiz + vadeli_yuk, 2),
    'ozkaynak', round(ozk, 2), 'sermaye', s.sermaye, 'birikmis_kar', round(ozk - s.sermaye, 2),
    'tampon', round(tampon, 2), 'rezerv', round(rezerv, 2), 'emniyet_payi', emniyet,
    'riskli_varlik', round(riskli, 2),
    'kredi_verilebilir', round(kv, 2), 'dagitilabilir_kar', round(dag, 2), 'sermaye_azaltilabilir', round(azalt, 2),
    'dibs_alinabilir', round(greatest(0, nakit - rezerv), 2),
    'likidite', lik, 'sermaye_yeterlilik', syr, 'takipteki_oran', npl, 'kredi_mevduat', km,
    'puan', greatest(0, puan), 'not', harf, 'durum', v_durum);
end $$;

-- Eski oyb_saglik aynı anahtarları döndürmeye devam eder; artık vadesiz mevduatı da borç sayar.
create or replace function oyun.oyb_saglik(p_banka bigint)
returns jsonb language plpgsql stable set search_path = '' as $$
declare b jsonb := oyun.banka_bilanco(p_banka);
begin
  return jsonb_build_object(
    'kasa', b->'nakit', 'sermaye', b->'sermaye',
    'mevduat_anapara', b->'vadeli_anapara', 'mevduat_yukumluluk', b->'vadeli_yukumluluk',
    'vadesiz_mevduat', b->'vadesiz',
    'yaklasan_odeme', b->'yaklasan_odeme',
    'riskli_kredi_varligi', round(((b->>'krediler')::numeric - (b->>'krediler_geciken')::numeric) * .70
                                  + (b->>'krediler_geciken')::numeric * .25, 2),
    'tampon', b->'tampon', 'asgari_likidite', b->'rezerv',
    'kredi_verilebilir', b->'kredi_verilebilir', 'dagitilabilir_kar', b->'dagitilabilir_kar',
    'not', b->'not', 'durum', b->'durum');
end $$;

-- Şirket defter değeri: bankada vadesiz mevduat, kart alacağı ve DİBS de hesaba girer.
create or replace function oyun.sirket_defter(p_sirket bigint)
returns numeric language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler; d numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null then return 0; end if;
  d := s.kasa
     + coalesce((select sum(adet * maliyet_birim) from oyun.eko_urun_stok where sirket_id = s.id), 0)
     + coalesce((select sum(fiyat) from oyun.eko_arsalar where sahibi_sirket = s.id), 0)
     + coalesce((select sum(maliyet) from oyun.eko_yapilar where sirket_id = s.id), 0);
  if s.sektor = 'banka' then
    d := d + coalesce((select sum(kalan) from oyun.oyb_kredi where banka_id = s.id and durum in ('aktif','takip')), 0)
           + coalesce((select sum(borc) from oyun.kredi_kartlari where banka_id = s.id and borc > 0), 0)
           + coalesce((select sum(tutar) from oyun.banka_dibs where banka_id = s.id and durum = 'acik'), 0)
           - coalesce((select sum(round(m.anapara * (1 + m.faiz / 100), 2)) from oyun.banka_mevduat m where m.banka_id = s.id and not m.kapandi), 0)
           - oyun.banka_vadesiz_toplam(s.id);
  end if;
  return greatest(0, d);
end $$;

create or replace function oyun.banka_gelir(p_banka bigint, p_gun integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); bas timestamptz := oyun.simdi() - make_interval(days => p_gun);
  kf numeric := 0; fa numeric := 0; pk numeric := 0; kt numeric := 0; db numeric := 0; mf numeric := 0; td numeric := 0;
begin
  select coalesce(sum(tutar) filter (where aciklama ilike '%faiz geliri%'), 0),
         coalesce(sum(tutar) filter (where aciklama ilike '%günlük faaliyet%' or aciklama ilike '%gunluk faaliyet%'), 0)
    into kf, fa from oyun.sirket_hareket where sirket_id = p_banka and zaman >= bas;
  if to_regclass('oyun.kart_pos_talepleri') is not null then
    select coalesce(sum(z.komisyon_tl), 0) into pk
      from oyun.kart_pos_talepleri z join oyun.sirket_pos x on x.id = z.pos_id
     where x.banka_id = p_banka and z.durum = 'odendi' and z.odendi >= bas;
    select coalesce(sum(h.tutar), 0) into kt
      from oyun.kart_hareketler h join oyun.kredi_kartlari c on c.id = h.kart_id
     where c.banka_id = p_banka and h.tur in ('faiz','gecikme','avans_masraf') and h.zaman >= bas;
  end if;
  select coalesce(sum(odenen - tutar), 0) into db from oyun.banka_dibs where banka_id = p_banka and durum = 'odendi' and kapanis >= bas;
  select coalesce(sum(round(anapara * faiz / 100, 2)), 0) into mf
    from oyun.banka_mevduat where banka_id = p_banka and kapandi and not iptal and vade >= bas and vade <= t;
  select coalesce(sum(brut), 0) into td from oyun.banka_temettu where banka_id = p_banka and tur = 'temettu' and zaman >= bas;
  return jsonb_build_object('gun', p_gun, 'kredi_faiz', round(kf, 2), 'pos_komisyon', round(pk, 2), 'kart_faiz', round(kt, 2),
    'dibs', round(db, 2), 'faaliyet', round(fa, 2), 'mevduat_faiz', round(mf, 2),
    'net', round(kf + pk + kt + db + fa - mf, 2), 'dagitilan', round(td, 2));
end $$;

-- Herkese açık banka künyesi: kasa YOK, yalnız güven notu ve ürünler
create or replace function oyun.banka_kunye(p_banka bigint, u uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare s oyun.sirketler; bp oyun.banka_politika; b jsonb;
begin
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif;
  if s.id is null then return null; end if;
  select * into bp from oyun.banka_politika where banka_id = p_banka;
  b := oyun.banka_bilanco(p_banka);
  return jsonb_build_object(
    'id', s.id, 'ad', s.ad, 'kurulus', s.kurulus,
    'renk', coalesce(bp.renk, 'lacivert'), 'slogan', bp.slogan,
    'not', b->'not', 'durum', b->'durum',
    'mevduat7', least(s.banka_faiz, 1.8), 'kredi24', least(s.banka_kredi_faiz, 1.0),
    'vadeler', jsonb_build_object('1', oyun.oyb_oran(s.id, 1), '6', oyun.oyb_oran(s.id, 6),
                                  '24', oyun.oyb_oran(s.id, 24), '168', oyun.oyb_oran(s.id, 168)),
    'paket_sayisi', (select count(*) from oyun.oyb_kredi_paket p where p.banka_id = s.id and p.aktif and p.silindi_at is null),
    'en_dusuk_kredi', (select min(p.faiz) from oyun.oyb_kredi_paket p where p.banka_id = s.id and p.aktif and p.silindi_at is null),
    'musteri', (select count(*) from oyun.oyb_hesap h where h.banka_id = s.id and h.kapanis is null),
    'hesabim', oyun.oyb_hesap_acik(s.id, u),
    'bankam', exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = u and o.pay > 0),
    'kart_otomatik', coalesce((select kart_otomatik from oyun.banka_yonetim_ayar a where a.banka_id = s.id), false),
    'kredi_otomatik', coalesce((select kredi_otomatik from oyun.banka_yonetim_ayar a where a.banka_id = s.id), false));
end $$;

-- ---------------------------------------------------------------------
-- D. DİBS (Devlet İç Borçlanma Senedi) — bankanın atıl parası
-- ---------------------------------------------------------------------
create or replace function oyun.banka_dibs_tahsil(p_banka bigint default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare d oyun.banka_dibs; t timestamptz := oyun.simdi(); n int := 0; odeme numeric; tlm numeric;
begin
  tlm := coalesce(nullif(oyun.pazar_tl_milyar(), 0), 1000000000);
  for d in select * from oyun.banka_dibs
            where durum = 'acik' and vade <= t and (p_banka is null or banka_id = p_banka)
            order by id for update skip locked loop
    odeme := round(d.tutar * (1 + d.oran / 100), 2);
    update oyun.sirketler set kasa = kasa + odeme where id = d.banka_id;
    update oyun.banka_dibs set durum = 'odendi', odenen = odeme, kapanis = t where id = d.id;
    update oyun.ulke set hazine = hazine - odeme / tlm where id = 1;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama)
    values (d.banka_id, t, odeme, format('DİBS itfası #%s: %s gün vadeli tahvil kasaya döndü (anapara %s ₺ + getiri %s ₺)',
            d.id, d.gun, oyun.tl(d.tutar), oyun.tl(odeme - d.tutar)));
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.banka_dibs_al(p_banka bigint, p_tutar numeric, p_gun integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; b jsonb; ora numeric; x bigint; tlm numeric;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.sirket_yonetici_mi(p_banka, u) then raise exception 'DİBS alımına bankanın yöneticisi ya da en az %%50 ortağı karar verir.'; end if;
  if p_gun not in (1, 7, 30) then raise exception 'DİBS vadesi 1, 7 ya da 30 gün olabilir.'; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < 10000 or p_tutar > 50000000 then
    raise exception 'DİBS tutarı 10.000 – 50.000.000 ₺ arasında tam sayı olmalı.'; end if;
  perform oyun.banka_dibs_tahsil(p_banka);
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif for update;
  if s.id is null then raise exception 'Faal banka bulunamadı.'; end if;
  b := oyun.banka_bilanco(p_banka);
  if p_tutar > (b->>'dibs_alinabilir')::numeric then
    raise exception 'Likidite rezervi korunmalı. Bu bankayla en fazla % ₺ DİBS alınabilir.', oyun.tl((b->>'dibs_alinabilir')::numeric); end if;
  ora := oyun.banka_dibs_orani(p_gun);
  tlm := coalesce(nullif(oyun.pazar_tl_milyar(), 0), 1000000000);
  update oyun.sirketler set kasa = kasa - p_tutar, son_islem = t where id = p_banka and kasa >= p_tutar;
  if not found then raise exception 'Kasa yetersiz.'; end if;
  insert into oyun.banka_dibs(banka_id, tutar, gun, oran, acilis, vade, alan)
  values (p_banka, p_tutar, p_gun, ora, t, t + make_interval(days => p_gun), u) returning id into x;
  update oyun.ulke set hazine = hazine + p_tutar / tlm where id = 1;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama)
  values (p_banka, t, -p_tutar, format('DİBS alımı #%s: %s gün vadeli devlet tahvili, %%%s getiri (%s)', x, p_gun, ora, oyun.kad(u)));
  return jsonb_build_object('tamam', true, 'id', x, 'oran', ora, 'vade', t + make_interval(days => p_gun),
                            'getiri', round(p_tutar * ora / 100, 2));
end $$;

create or replace function public.banka_dibs_boz(p_banka bigint, p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); d oyun.banka_dibs; odeme numeric; tlm numeric;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.sirket_yonetici_mi(p_banka, u) then raise exception 'Bu bankanın yönetim yetkin yok.'; end if;
  select * into d from oyun.banka_dibs where id = p_id and banka_id = p_banka for update;
  if d.id is null or d.durum <> 'acik' then raise exception 'Açık DİBS bulunamadı.'; end if;
  if d.vade <= t then
    perform oyun.banka_dibs_tahsil(p_banka);
    return jsonb_build_object('tamam', true, 'vadeli', true);
  end if;
  tlm := coalesce(nullif(oyun.pazar_tl_milyar(), 0), 1000000000);
  odeme := round(d.tutar * 0.998, 2);   -- vadeden önce satış: getiri yok, %0,2 kırım
  update oyun.sirketler set kasa = kasa + odeme where id = p_banka;
  update oyun.banka_dibs set durum = 'bozuldu', odenen = odeme, kapanis = t where id = d.id;
  update oyun.ulke set hazine = hazine - odeme / tlm where id = 1;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama)
  values (p_banka, t, odeme, format('DİBS #%s vadeden önce satıldı (getirisiz, %%0,2 kırım)', d.id));
  return jsonb_build_object('tamam', true, 'odenen', odeme);
end $$;

-- ---------------------------------------------------------------------
-- E. KASA YÖNETİMİ: sermaye koy, kâr payı (stopajlı), sermaye azalt,
--    emniyet payı, kimlik, risk profili
-- ---------------------------------------------------------------------
create or replace function public.banka_sermaye_koy(p_banka bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r jsonb;
begin
  if not exists(select 1 from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif) then
    raise exception 'Faal banka bulunamadı.'; end if;
  r := public.sirket_kasa_yatir(p_banka, p_tutar);
  return r || jsonb_build_object('bilanco', oyun.banka_bilanco(p_banka));
end $$;

create or replace function public.banka_kar_dagit(p_banka bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; b jsonb; dag numeric; x record; tid bigint;
  brut numeric; st numeric; net numeric; tb numeric := 0; ts numeric := 0; tn numeric := 0;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.sirket_yonetici_mi(p_banka, u) then
    raise exception 'Kâr payı dağıtımına bankanın yöneticisi ya da en az %%50 ortağı karar verir.'; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < 1000 then
    raise exception 'Kâr payı en az 1.000 ₺ ve tam sayı olmalı.'; end if;
  perform oyun.sirket_hesapla(p_banka);
  perform oyun.banka_dibs_tahsil(p_banka);
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif for update;
  if s.id is null then raise exception 'Faal banka bulunamadı.'; end if;
  b := oyun.banka_bilanco(p_banka);
  dag := floor(coalesce((b->>'dagitilabilir_kar')::numeric, 0));
  if p_tutar > dag then
    raise exception 'Dağıtılabilir kâr % ₺. Sermaye, mevduat sahiplerinin parası ve yasal karşılık dağıtılamaz.', oyun.tl(dag); end if;
  insert into oyun.banka_temettu(banka_id, tur, yapan, zaman) values (p_banka, 'temettu', u, t) returning id into tid;
  for x in select user_id, pay from oyun.sirket_ortaklari where sirket_id = p_banka and pay > 0 order by pay desc, user_id loop
    brut := round(p_tutar * x.pay / 100);
    if brut <= 0 then continue; end if;
    st := oyun.eko_vergi_tahsil(p_banka, 'dagitim', brut, 'banka_temettu', tid, x.user_id);
    net := brut - st;
    perform oyun.para_islem(x.user_id, net, 'sirket',
      format('%s kâr payı (brüt %s ₺, stopaj %s ₺)', s.ad, oyun.tl(brut), oyun.tl(st)), t, st);
    perform oyun.bildir(x.user_id, format('🏦 %s ortaklarına kâr payı dağıttı. Payına düşen net %s ₺ cüzdanına geçti.', s.ad, oyun.tl(net)), t);
    tb := tb + brut; ts := ts + st; tn := tn + net;
  end loop;
  if tb <= 0 then raise exception 'Dağıtılacak ortak bulunamadı.'; end if;
  update oyun.sirketler set kasa = kasa - tb, son_islem = t where id = p_banka and kasa >= tb;
  if not found then raise exception 'Kasa yetersiz.'; end if;
  update oyun.banka_temettu set brut = tb, stopaj = ts, net = tn where id = tid;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, dagitilan_kar)
  values (p_banka, t, -tb, format('Kâr payı dağıtımı: brüt %s ₺, stopaj %s ₺ Hazine''ye, ortaklara net %s ₺', oyun.tl(tb), oyun.tl(ts), oyun.tl(tn)), tb);
  return jsonb_build_object('tamam', true, 'brut', tb, 'stopaj', ts, 'net', tn);
end $$;

create or replace function public.banka_sermaye_azalt(p_banka bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; b jsonb; mx numeric; x record; tid bigint; pay numeric; top numeric := 0;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.sirket_yonetici_mi(p_banka, u) then
    raise exception 'Sermaye azaltımına bankanın yöneticisi ya da en az %%50 ortağı karar verir.'; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < 10000 then
    raise exception 'Sermaye azaltımı en az 10.000 ₺ ve tam sayı olmalı.'; end if;
  perform oyun.banka_dibs_tahsil(p_banka);
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif for update;
  if s.id is null then raise exception 'Faal banka bulunamadı.'; end if;
  b := oyun.banka_bilanco(p_banka);
  mx := floor(coalesce((b->>'sermaye_azaltilabilir')::numeric, 0));
  if p_tutar > mx then
    raise exception 'En fazla % ₺ sermaye azaltılabilir. Bankanın sermayesi 1.000.000 ₺ altına düşemez; mevduat ve %%12 sermaye yeterliliği korunur.', oyun.tl(mx); end if;
  insert into oyun.banka_temettu(banka_id, tur, yapan, zaman) values (p_banka, 'sermaye_iade', u, t) returning id into tid;
  for x in select user_id, o.pay from oyun.sirket_ortaklari o where sirket_id = p_banka and o.pay > 0 order by o.pay desc, user_id loop
    pay := round(p_tutar * x.pay / 100);
    if pay <= 0 then continue; end if;
    perform oyun.para_islem(x.user_id, pay, 'sirket', format('%s sermaye iadesi (vergisiz)', s.ad), t);
    perform oyun.bildir(x.user_id, format('🏦 %s sermayesini azalttı. Payına düşen %s ₺ cüzdanına iade edildi.', s.ad, oyun.tl(pay)), t);
    top := top + pay;
  end loop;
  if top <= 0 then raise exception 'İade edilecek ortak bulunamadı.'; end if;
  update oyun.sirketler set kasa = kasa - top, sermaye = sermaye - top, son_islem = t where id = p_banka and kasa >= top;
  if not found then raise exception 'Kasa yetersiz.'; end if;
  update oyun.banka_temettu set brut = top, net = top where id = tid;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama)
  values (p_banka, t, -top, format('Sermaye azaltımı: ortaklara %s ₺ iade edildi; yeni sermaye %s ₺', oyun.tl(top), oyun.tl(s.sermaye - top)));
  return jsonb_build_object('tamam', true, 'iade', top, 'yeni_sermaye', s.sermaye - top);
end $$;

create or replace function public.banka_politika_kaydet(p_banka bigint, p_emniyet numeric default null,
  p_renk text default null, p_slogan text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); sl text;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not exists(select 1 from oyun.sirketler where id = p_banka and sektor = 'banka') then raise exception 'Banka bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(p_banka, u) then raise exception 'Bu bankanın yönetim yetkin yok.'; end if;
  if p_emniyet is not null and (p_emniyet < 0 or p_emniyet > 100000000 or p_emniyet <> round(p_emniyet)) then
    raise exception 'Emniyet payı 0 – 100.000.000 ₺ arasında tam sayı olmalı.'; end if;
  if p_renk is not null and p_renk not in ('lacivert','bordo','zumrut','turuncu','mor','altin','turkuaz','gece','kirmizi','gumus') then
    raise exception 'Geçersiz banka rengi.'; end if;
  if p_slogan is not null then
    sl := nullif(btrim(regexp_replace(p_slogan, '[<>]', '', 'g')), '');
    if sl is not null and char_length(sl) > 80 then raise exception 'Slogan en fazla 80 karakter olabilir.'; end if;
  end if;
  insert into oyun.banka_politika(banka_id, emniyet_payi, renk, slogan, guncelleme)
  values (p_banka, coalesce(p_emniyet, 0), coalesce(p_renk, 'lacivert'), sl, now())
  on conflict (banka_id) do update set
    emniyet_payi = coalesce(p_emniyet, oyun.banka_politika.emniyet_payi),
    renk = coalesce(p_renk, oyun.banka_politika.renk),
    slogan = case when p_slogan is null then oyun.banka_politika.slogan else sl end,
    guncelleme = now();
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.banka_risk_profili(p_banka bigint, p_profil text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); a oyun.banka_yonetim_ayar; pos boolean; kart boolean; kredi boolean; mn int; kmx numeric; krmx numeric;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if p_profil not in ('temkinli','dengeli','atak','manuel') then raise exception 'Risk profili temkinli, dengeli, atak ya da manuel olmalı.'; end if;
  select * into a from oyun.banka_yonetim_ayar where banka_id = p_banka;
  if p_profil = 'temkinli' then pos := true; kart := true; kredi := true; mn := 1500; kmx := 100000;  krmx := 100000;
  elsif p_profil = 'dengeli' then pos := true; kart := true; kredi := true; mn := 1100; kmx := 300000;  krmx := 300000;
  elsif p_profil = 'atak' then pos := true; kart := true; kredi := true; mn := 900;  kmx := 1000000; krmx := 1000000;
  else pos := false; kart := false; kredi := false; mn := coalesce(a.asgari_not, 850);
       kmx := coalesce(a.kart_azami, 500000); krmx := coalesce(a.kredi_azami, 500000);
  end if;
  perform public.banka_yonetim_ayar_kaydet(p_banka, pos, kart, kredi, mn, kmx, krmx);
  insert into oyun.banka_politika(banka_id, risk_profili, guncelleme) values (p_banka, p_profil, now())
  on conflict (banka_id) do update set risk_profili = excluded.risk_profili, guncelleme = now();
  return jsonb_build_object('tamam', true, 'profil', p_profil, 'asgari_not', mn, 'kart_max', kmx, 'kredi_max', krmx);
end $$;

-- ---------------------------------------------------------------------
-- F. KASA GİZLİLİĞİ RPC'LERİ
-- ---------------------------------------------------------------------
create or replace function public.kasa_gizlilik_ayarla(p_tur text, p_id bigint, p_gorunurluk text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); ok boolean;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if p_tur not in ('sirket','dernek','gazete') then raise exception 'Geçersiz kurum türü.'; end if;
  if p_gorunurluk not in ('gizli','uyeler','herkes') then raise exception 'Görünürlük gizli, üyeler ya da herkes olmalı.'; end if;
  if p_gorunurluk = 'uyeler' and p_tur <> 'dernek' then raise exception '“Yalnız üyeler” seçeneği dernekler içindir.'; end if;
  ok := case p_tur
    when 'sirket' then oyun.sirket_yonetici_mi(p_id, u)
    when 'dernek' then exists(select 1 from oyun.dernekler d where d.id = p_id and d.baskan = u)
    else exists(select 1 from oyun.oyuncu_gazeteleri g where g.id = p_id and g.sahip = u) end;
  if not coalesce(ok, false) then raise exception 'Kasa görünürlüğünü yalnız kurumun sahibi ya da yöneticisi değiştirebilir.'; end if;
  insert into oyun.kasa_gizlilik(tur, kimlik, gorunurluk, guncelleyen, guncelleme)
  values (p_tur, p_id, p_gorunurluk, u, now())
  on conflict (tur, kimlik) do update set gorunurluk = excluded.gorunurluk, guncelleyen = excluded.guncelleyen, guncelleme = excluded.guncelleme;
  return jsonb_build_object('tamam', true, 'tur', p_tur, 'id', p_id, 'gorunurluk', p_gorunurluk);
end $$;

create or replace function public.kasa_gizlilik_listem()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  return jsonb_build_object(
    'sirketler', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'kasa', s.kasa,
        'gorunurluk', coalesce(g.gorunurluk, 'gizli'), 'ayarlayabilir', oyun.sirket_yonetici_mi(s.id, u)) order by s.sektor <> 'banka', s.ad)
      from oyun.sirketler s left join oyun.kasa_gizlilik g on g.tur = 'sirket' and g.kimlik = s.id
     where s.aktif and oyun.kasa_yetkili('sirket', s.id, u)), '[]'::jsonb),
    'dernekler', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'ad', d.ad, 'kasa', d.kasa,
        'gorunurluk', coalesce(g.gorunurluk, 'gizli'), 'ayarlayabilir', d.baskan = u) order by d.ad)
      from oyun.dernekler d left join oyun.kasa_gizlilik g on g.tur = 'dernek' and g.kimlik = d.id
     where not d.kapali and oyun.kasa_yetkili('dernek', d.id, u)), '[]'::jsonb),
    'gazeteler', coalesce((select jsonb_agg(jsonb_build_object('id', z.id, 'ad', z.ad, 'kasa', z.kasa,
        'gorunurluk', coalesce(g.gorunurluk, 'gizli'), 'ayarlayabilir', true) order by z.ad)
      from oyun.oyuncu_gazeteleri z left join oyun.kasa_gizlilik g on g.tur = 'gazete' and g.kimlik = z.id
     where z.aktif and z.sahip = u), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- G. MÜŞTERİ: MOBİL ŞUBE
-- ---------------------------------------------------------------------
create or replace function public.banka_sube()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); p oyun.profiller; m oyun.banka_musteri; c record; cuz numeric;
  vadeli_devlet numeric; mev numeric; kredi numeric; kart numeric; vadesiz_ozel numeric; dk oyun.krediler;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into p from oyun.profiller where id = u;
  if p.id is null then raise exception 'Profil bulunamadı.'; end if;
  m := oyun.vadesiz_isle(u, t);
  for c in select id from oyun.kredi_kartlari where user_id = u loop perform oyun.kart_donem_isle(c.id); end loop;
  perform public.banka_mevduat_tahsil();
  cuz := coalesce((select para from oyun.cuzdan where user_id = u), 0);
  vadeli_devlet := coalesce((select sum(anapara) from oyun.vadeli where user_id = u and durum = 'acik'), 0);
  mev := coalesce((select sum(anapara) from oyun.banka_mevduat where user_id = u and not kapandi), 0);
  vadesiz_ozel := coalesce((select sum(bakiye) from oyun.ib_vadesiz where user_id = u), 0);
  kredi := coalesce((select sum(kalan) from oyun.oyb_kredi where borclu = u and durum in ('aktif','takip')), 0)
         + coalesce((select sum(kalan) from oyun.krediler where user_id = u and durum in ('aktif','takip')), 0);
  kart := coalesce((select sum(borc) from oyun.kredi_kartlari where user_id = u), 0);
  select * into dk from oyun.krediler where user_id = u and durum in ('aktif','takip') order by id desc limit 1;

  return jsonb_build_object(
    'kad', p.kad, 'cuzdan', cuz, 'simdi', t,
    'kredi_notu', coalesce(m.kredi_notu, 1100), 'not_ad', oyun.not_ad(coalesce(m.kredi_notu, 1100)),
    'kara_liste', case when m.kara_liste > t then m.kara_liste end,
    'toplam', jsonb_build_object(
       'varlik', round(cuz + coalesce(m.vadesiz, 0) + vadesiz_ozel + vadeli_devlet + mev, 2),
       'banka', round(coalesce(m.vadesiz, 0) + vadesiz_ozel + vadeli_devlet + mev, 2),
       'borc', round(kredi + kart, 2)),
    'devlet', jsonb_build_object(
       'iban', oyun.banka_iban(0, u), 'vadesiz', round(coalesce(m.vadesiz, 0), 2),
       'oranlar', oyun.banka_oranlar(),
       'vadeliler', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'anapara', v.anapara, 'oran', v.oran,
            'gun', v.gun, 'vade_saat', v.vade_saat, 'oran_tur', v.oran_tur, 'acilis', v.acilis, 'vade', v.vade,
            'biriken', oyun.vadeli_biriken(v, t)) order by v.vade)
          from oyun.vadeli v where v.user_id = u and v.durum = 'acik'), '[]'::jsonb),
       'kredi', case when dk.id is not null then jsonb_build_object('id', dk.id, 'anapara', dk.anapara, 'kalan', dk.kalan,
            'taksit', dk.taksit, 'gecikmis', dk.gecikmis, 'gun', dk.gun, 'durum', dk.durum, 'acilis', dk.acilis,
            'erken_kapama', oyun.erken_kapama(dk)) end),
    'hesaplar', coalesce((select jsonb_agg(jsonb_build_object(
         'banka_id', s.id, 'ad', s.ad, 'renk', coalesce(bp.renk, 'lacivert'), 'slogan', bp.slogan,
         'iban', oyun.banka_iban(s.id, u), 'acilis', h.acilis,
         'vadesiz', coalesce((select v.bakiye from oyun.ib_vadesiz v where v.banka_id = s.id and v.user_id = u), 0),
         'vadeli', coalesce((select sum(x.anapara) from oyun.banka_mevduat x where x.banka_id = s.id and x.user_id = u and not x.kapandi), 0),
         'kredi', coalesce((select sum(x.kalan) from oyun.oyb_kredi x where x.banka_id = s.id and x.borclu = u and x.durum in ('aktif','takip')), 0),
         'kart', coalesce((select sum(x.borc) from oyun.kredi_kartlari x where x.banka_id = s.id and x.user_id = u), 0)
       ) order by h.acilis)
       from oyun.oyb_hesap h join oyun.sirketler s on s.id = h.banka_id and s.aktif and s.sektor = 'banka'
       left join oyun.banka_politika bp on bp.banka_id = s.id
       where h.user_id = u and h.kapanis is null), '[]'::jsonb),
    'kartlar', coalesce((select jsonb_agg(jsonb_build_object(
         'id', k.id, 'banka_id', k.banka_id, 'banka', coalesce(s.ad, 'Devlet Bankası'),
         'renk', case when k.banka_id is null then 'devlet' else coalesce(bp.renk, 'lacivert') end,
         'limit', k.limit_tl, 'borc', k.borc, 'kullanilabilir', greatest(k.limit_tl - k.borc, 0), 'durum', k.durum,
         'son_dort', lpad((k.id % 10000)::text, 4, '0'), 'kesim_at', k.kesim_at, 'gecikmis_asgari', k.gecikmis_asgari,
         'nakit_avans', k.nakit_avans_bakiye,
         'ekstre', (select jsonb_build_object('id', e.id, 'kesim', e.kesim, 'son_odeme', e.son_odeme, 'toplam', e.toplam,
                    'asgari', e.asgari, 'odenen', e.odenen) from oyun.kart_ekstreler e
                    where e.kart_id = k.id and e.durum = 'acik' order by e.son_odeme limit 1),
         'hareketler', coalesce((select jsonb_agg(jsonb_build_object('tur', a.tur, 'tutar', a.tutar, 'aciklama', a.aciklama, 'zaman', a.zaman) order by a.id desc)
                    from (select * from oyun.kart_hareketler where kart_id = k.id order by id desc limit 8) a), '[]'::jsonb)
       ) order by k.id desc)
       from oyun.kredi_kartlari k left join oyun.sirketler s on s.id = k.banka_id
       left join oyun.banka_politika bp on bp.banka_id = k.banka_id
       where k.user_id = u and k.durum <> 'iptal'), '[]'::jsonb),
    'kart_basvurulari', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'banka_id', b.banka_id,
         'banka', coalesce(s.ad, 'Devlet Bankası'), 'istek', b.istek, 'istenen', b.istenen, 'izin', b.izin,
         'teklif_limit', b.teklif_limit, 'basvuru', b.basvuru) order by b.id desc)
       from oyun.kart_basvurular b left join oyun.sirketler s on s.id = b.banka_id
       where b.user_id = u and b.durum = 'bekliyor'), '[]'::jsonb),
    'krediler', coalesce((select jsonb_agg(jsonb_build_object(
         'id', k.id, 'banka_id', k.banka_id, 'banka', s.ad, 'renk', coalesce(bp.renk, 'lacivert'),
         'anapara', k.anapara, 'toplam', k.toplam, 'kalan', k.kalan, 'oran', k.oran, 'durum', k.durum,
         'vade_gun', round(k.saat / 24.0, 1), 'acilis', k.acilis, 'vade', k.vade, 'basvuru', k.basvuru,
         'taksit_sayisi', k.taksit_sayisi,
         'odenen_taksit', (select count(*) from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen >= x.tutar),
         'siradaki', (select jsonb_build_object('sira', x.sira, 'vade', x.vade, 'kalan', x.tutar - x.odenen)
                      from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar order by x.sira limit 1),
         'geciken', (select coalesce(sum(x.tutar - x.odenen), 0) from oyun.oyb_kredi_taksit x
                     where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t),
         'erken_kapama', case when k.durum = 'aktif' then oyun.oyb_erken_kapama_tutari(k, t) end,
         'icra', (select i.durum from oyun.oyb_icra i where i.kredi_id = k.id)
       ) order by (k.durum = 'basvuru') desc, k.id desc)
       from oyun.oyb_kredi k join oyun.sirketler s on s.id = k.banka_id
       left join oyun.banka_politika bp on bp.banka_id = k.banka_id
       where k.borclu = u and k.durum in ('basvuru','aktif','takip')), '[]'::jsonb),
    'mevduatlar', coalesce((select jsonb_agg(jsonb_build_object(
         'id', x.id, 'banka_id', x.banka_id, 'banka', s.ad, 'renk', coalesce(bp.renk, 'lacivert'),
         'anapara', x.anapara, 'oran', x.faiz, 'getiri', round(x.anapara * x.faiz / 100, 2),
         'saat', coalesce(x.vade_saat, 168), 'acilis', x.acilis, 'vade', x.vade, 'vadesi_doldu', x.vade <= t) order by x.vade)
       from oyun.banka_mevduat x join oyun.sirketler s on s.id = x.banka_id
       left join oyun.banka_politika bp on bp.banka_id = x.banka_id
       where x.user_id = u and not x.kapandi), '[]'::jsonb),
    'bekleyen', jsonb_build_object(
       'teklifler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'banka', s.ad, 'banka_id', x.banka_id,
            'tutar', x.tutar, 'vade_gun', x.vade_gun, 'taksit_sayisi', x.taksit_sayisi, 'faiz', x.faiz, 'mesaj', x.mesaj,
            'son', x.son, 'plan', oyun.oyb_plan(x.tutar, x.vade_gun, x.taksit_sayisi, x.faiz, t)) order by x.id desc)
          from oyun.oyb_kredi_teklifi x join oyun.sirketler s on s.id = x.banka_id
          where x.user_id = u and x.durum = 'teklif' and x.son > t), '[]'::jsonb),
       'bilgi', coalesce((select jsonb_agg(jsonb_build_object('banka_id', b.banka_id, 'banka', s.ad, 'istenen', b.istenen, 'istek_at', b.istek_at))
          from oyun.oyb_hesap_bilgi b join oyun.sirketler s on s.id = b.banka_id
          where b.user_id = u and b.durum = 'bekliyor'), '[]'::jsonb),
       'kredi_bilgi', coalesce((select jsonb_agg(jsonb_build_object('kredi_id', b.kredi_id, 'banka', s.ad, 'istenen', b.istenen))
          from oyun.oyb_bilgi_izin b join oyun.sirketler s on s.id = b.banka_id
          where b.borclu = u and b.durum = 'bekliyor'), '[]'::jsonb),
       'pos', coalesce((select jsonb_agg(jsonb_build_object('id', z.id, 'sirket', s.ad, 'tutar', z.tutar, 'aciklama', z.aciklama,
            'olusturma', z.olusturma) order by z.id desc)
          from oyun.kart_pos_talepleri z join oyun.sirketler s on s.id = z.sirket_id
          where z.musteri = u and z.durum = 'bekliyor'), '[]'::jsonb)),
    'hareketler', coalesce((select jsonb_agg(q.j order by q.z desc) from (
         (select jsonb_build_object('kaynak', 'Devlet Bankası', 'renk', 'devlet', 'tutar', h.tutar, 'aciklama', h.aciklama, 'zaman', h.zaman) j, h.zaman z
            from oyun.banka_hareket h where h.user_id = u order by h.zaman desc limit 25)
         union all
         (select jsonb_build_object('kaynak', s.ad, 'renk', coalesce(bp.renk, 'lacivert'), 'tutar', h.tutar, 'aciklama', h.aciklama, 'zaman', h.zaman), h.zaman
            from oyun.ib_hareket h join oyun.sirketler s on s.id = h.banka_id left join oyun.banka_politika bp on bp.banka_id = h.banka_id
           where h.user_id = u order by h.zaman desc limit 25)
         union all
         (select jsonb_build_object('kaynak', 'Kart •••• ' || lpad((k.id % 10000)::text, 4, '0'), 'renk', 'kart',
                 'tutar', case when a.tur = 'odeme' then a.tutar else -a.tutar end, 'aciklama', a.aciklama, 'zaman', a.zaman), a.zaman
            from oyun.kart_hareketler a join oyun.kredi_kartlari k on k.id = a.kart_id
           where k.user_id = u order by a.zaman desc limit 15)
       ) q), '[]'::jsonb),
    'bankalar', coalesce((select jsonb_agg(oyun.banka_kunye(s.id, u) order by s.kurulus)
       from oyun.sirketler s where s.sektor = 'banka' and s.aktif), '[]'::jsonb));
end $$;

-- Alıcının hangi bankalarda hesabı var? (yalnız banka adları; bakiye yok)
create or replace function public.banka_alici(p_kad text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid(); h oyun.profiller;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if h.id is null then raise exception 'Bu kullanıcı adıyla oyuncu bulunamadı.'; end if;
  if h.id = u then raise exception 'Kendi hesapların arasında aktarım için “Hesaplarım arası”nı kullan.'; end if;
  return jsonb_build_object('kad', h.kad, 'yasakli', h.yasakli,
    'hesaplar', jsonb_build_array(jsonb_build_object('hedef', 'devlet', 'ad', 'Devlet Bankası', 'renk', 'devlet'))
      || coalesce((select jsonb_agg(jsonb_build_object('hedef', 'b:' || s.id, 'ad', s.ad, 'renk', coalesce(bp.renk, 'lacivert')) order by s.ad)
           from oyun.oyb_hesap x join oyun.sirketler s on s.id = x.banka_id and s.aktif
           left join oyun.banka_politika bp on bp.banka_id = s.id
          where x.user_id = h.id and x.kapanis is null), '[]'::jsonb));
end $$;

-- Günlük aktarım sınırı artık FAST transferlerini de sayar
create or replace function oyun.gunluk_aktarim(u uuid, t timestamp with time zone)
returns numeric language plpgsql stable set search_path = '' as $$
begin
  return coalesce((select sum(tutar) from oyun.banka_transfer where gonderen = u and zaman >= oyun.bugun_bas(t)), 0)
       + coalesce((select sum(tutar) from oyun.serbest_bagis_kayit where gonderen = u and alici_tur in ('oyuncu','sirket','gazete')
                   and zaman >= oyun.bugun_bas(t)), 0)
       + coalesce((select sum(tutar) from oyun.banka_fast where gonderen = u and zaman >= oyun.bugun_bas(t)), 0);
end $$;

-- FAST: her hesaptan her hesaba (aynı banka = havale, başka banka = EFT, Devlet ↔ özel = FAST)
create or replace function public.banka_fast(p_kaynak text, p_alici text, p_hedef text, p_tutar numeric, p_aciklama text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); p oyun.profiller; h oyun.profiller; m numeric; kb bigint; hb bigint;
  ack text; v numeric; bugun numeric; tavan numeric; sad text; had text; r jsonb;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  p := oyun.profilim();
  if p_kaynak is null or (p_kaynak <> 'devlet' and p_kaynak !~ '^b:[0-9]+$') then raise exception 'Gönderen hesabı seç.'; end if;
  if p_hedef is null or (p_hedef <> 'devlet' and p_hedef !~ '^b:[0-9]+$') then raise exception 'Alıcının hesabını seç.'; end if;
  kb := case when p_kaynak = 'devlet' then null else substr(p_kaynak, 3)::bigint end;
  hb := case when p_hedef = 'devlet' then null else substr(p_hedef, 3)::bigint end;
  h := oyun.profil_bul(p_alici);
  if h.id = u then raise exception 'Kendi hesapların arasında aktarım için “Hesaplarım arası”nı kullan.'; end if;
  if h.yasakli then raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
  m := round(coalesce(p_tutar, 0));
  if m < 100 then raise exception 'En az 100 ₺ gönderebilirsin.'; end if;
  if m > 10000000 then raise exception 'Tek işlemde en fazla 10.000.000 ₺ gönderebilirsin.'; end if;
  if oyun.uyari(p, t) is not null then raise exception 'Para göndermek için seçmen kartın hazır olmalı: %', oyun.uyari(p, t); end if;
  if (select coklu_kontrol from oyun.ayarlar where id = 1)
     and exists(select 1 from oyun.bagli_hesaplar(u) b where b = h.id) then
    raise exception 'Aynı cihazda açılmış hesaplar arasında banka transferi yapılamaz.'; end if;
  if oyun.engelli(h.id, u) then raise exception 'Bu oyuncu seni engellediği için ona para gönderemezsin.'; end if;
  perform oyun.takip_engel(u, 'banka transferi yapamazsın');

  -- Mevcut kanallar (kurallarıyla birlikte)
  if kb is null and hb is null then
    return public.para_gonder(h.kad, m, p_aciklama) || jsonb_build_object('yol', 'havale', 'kanal', 'Devlet Bankası');
  end if;
  if kb is not null and hb is not null then
    if kb = hb then
      r := public.ib_havale(kb, h.kad, m);
      return r || jsonb_build_object('yol', 'havale');
    end if;
    r := public.ib_eft(kb, hb, h.kad, m);
    return r || jsonb_build_object('yol', 'eft');
  end if;

  -- Devlet Bankası ↔ özel banka: FAST
  if nullif(btrim(coalesce(p_aciklama, '')), '') is not null then ack := oyun.metin_temizle(p_aciklama, 100); end if;
  bugun := oyun.gunluk_aktarim(u, t);
  tavan := round((select asgari from oyun.ulke where id = 1) * (select havale_sinir from oyun.ayarlar where id = 1));
  if bugun + m > tavan then
    raise exception 'Günlük para aktarma sınırı % ₺ (bugün % ₺ gönderdin).', oyun.tl(tavan), oyun.tl(bugun); end if;

  if kb is null then
    select ad into had from oyun.sirketler where id = hb and sektor = 'banka' and aktif for update;
    if had is null then raise exception 'Alıcının bankası faal değil.'; end if;
    if not oyun.oyb_hesap_acik(hb, h.id) then raise exception 'Alıcının % bankasında açık hesabı yok.', had; end if;
    perform oyun.vadesiz_isle(u, t);
    update oyun.banka_musteri set vadesiz = vadesiz - m where user_id = u and vadesiz >= m;
    if not found then raise exception 'Devlet Bankası vadesiz hesabında yeterli para yok.'; end if;
    update oyun.sirketler set kasa = kasa + m where id = hb;
    insert into oyun.ib_vadesiz(banka_id, user_id, bakiye, guncelleme) values (hb, h.id, m, t)
    on conflict (banka_id, user_id) do update set bakiye = oyun.ib_vadesiz.bakiye + excluded.bakiye, guncelleme = excluded.guncelleme;
    perform oyun.banka_kayit(u, 'vadesiz', -m, format('FAST giden: %s · %s%s', h.kad, had, coalesce(': ' || ack, '')), t);
    insert into oyun.ib_hareket(banka_id, user_id, tutar, aciklama, zaman)
    values (hb, h.id, m, format('FAST gelen: %s · Devlet Bankası%s', p.kad, coalesce(': ' || ack, '')), t);
  else
    select ad into sad from oyun.sirketler where id = kb and sektor = 'banka' and aktif for update;
    if sad is null then raise exception 'Banka faal değil.'; end if;
    if not oyun.oyb_hesap_acik(kb, u) then raise exception '% bankasında açık hesabın yok.', sad; end if;
    select bakiye into v from oyun.ib_vadesiz where banka_id = kb and user_id = u for update;
    if coalesce(v, 0) < m then raise exception 'Banka hesabında yeterli bakiye yok.'; end if;
    perform oyun.vadesiz_isle(h.id, t);
    if oyun.mevduat_toplam(h.id) + m > oyun.banka_tavani() then
      raise exception 'Alıcının Devlet Bankası mevduatı üst sınıra çok yakın.'; end if;
    update oyun.sirketler set kasa = kasa - m where id = kb and kasa >= m;
    if not found then raise exception 'Banka şu an bu ödemeyi karşılayamıyor; biraz sonra tekrar dene.'; end if;
    update oyun.ib_vadesiz set bakiye = bakiye - m, guncelleme = t where banka_id = kb and user_id = u;
    update oyun.banka_musteri set vadesiz = vadesiz + m where user_id = h.id;
    insert into oyun.ib_hareket(banka_id, user_id, tutar, aciklama, zaman)
    values (kb, u, -m, format('FAST giden: %s · Devlet Bankası%s', h.kad, coalesce(': ' || ack, '')), t);
    perform oyun.banka_kayit(h.id, 'vadesiz', m, format('FAST gelen: %s · %s%s', p.kad, sad, coalesce(': ' || ack, '')), t);
  end if;
  insert into oyun.banka_fast(gonderen, alici, kaynak_banka, hedef_banka, tutar, aciklama, zaman)
  values (u, h.id, kb, hb, m, ack, t);
  perform oyun.bildir(h.id, format('💸 %s sana FAST ile %s ₺ gönderdi (%s hesabına).%s', p.kad, oyun.tl(m),
          coalesce(had, 'Devlet Bankası'), coalesce(' Not: “' || ack || '”', '')), t);
  return jsonb_build_object('tamam', true, 'yol', 'fast', 'tutar', m, 'alici', h.kad,
                            'gunluk_kalan', greatest(0, tavan - bugun - m));
end $$;

-- Hesaplarım arası (cüzdan, Devlet Bankası, özel bankalar)
create or replace function public.banka_hesaplar_arasi(p_kaynak text, p_hedef text, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); m numeric;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if p_kaynak is null or (p_kaynak not in ('cuzdan','devlet') and p_kaynak !~ '^b:[0-9]+$') then raise exception 'Kaynak hesabı seç.'; end if;
  if p_hedef is null or (p_hedef not in ('cuzdan','devlet') and p_hedef !~ '^b:[0-9]+$') then raise exception 'Hedef hesabı seç.'; end if;
  if p_kaynak = p_hedef then raise exception 'Kaynak ve hedef aynı hesap olamaz.'; end if;
  m := round(coalesce(p_tutar, 0));
  if m < 1 then raise exception 'Geçerli bir tutar gir.'; end if;
  -- Kaynaktan cüzdana
  if p_kaynak = 'devlet' then perform public.banka_cek(m);
  elsif p_kaynak like 'b:%' then perform public.ib_vadesiz_islem(substr(p_kaynak, 3)::bigint, m, 'cek');
  end if;
  -- Cüzdandan hedefe
  if p_hedef = 'devlet' then perform public.banka_yatir(m);
  elsif p_hedef like 'b:%' then perform public.ib_vadesiz_islem(substr(p_hedef, 3)::bigint, m, 'yatir');
  end if;
  return jsonb_build_object('tamam', true, 'tutar', m);
end $$;

-- ---------------------------------------------------------------------
-- H. BANKA GENEL MÜDÜRLÜĞÜ (banka sahibi paneli, tek sorgu)
-- ---------------------------------------------------------------------
create or replace function public.banka_yonettiklerim()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'aktif', s.aktif,
      'renk', coalesce(bp.renk, 'lacivert'), 'yonetebilir', oyun.sirket_yonetici_mi(s.id, u),
      'not', (oyun.banka_bilanco(s.id))->'not',
      'bekleyen', (select count(*) from oyun.oyb_kredi k where k.banka_id = s.id and k.durum = 'basvuru')
                + (select count(*) from oyun.kart_basvurular b where b.banka_id = s.id and b.durum = 'bekliyor')
                + (select count(*) from oyun.sirket_pos x where x.banka_id = s.id and x.durum = 'bekliyor')) order by s.id)
    from oyun.sirketler s left join oyun.banka_politika bp on bp.banka_id = s.id
    where s.sektor = 'banka' and s.aktif
      and (s.yonetici = u or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = u and o.pay > 0))), '[]'::jsonb);
end $$;

create or replace function public.banka_genel_mudurluk(p_banka bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; yon boolean; bp oyun.banka_politika;
  ay oyun.banka_yonetim_ayar; b jsonb;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka';
  if s.id is null then raise exception 'Banka bulunamadı.'; end if;
  yon := oyun.sirket_yonetici_mi(p_banka, u);
  if not (yon or s.yonetici = u
          or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_banka and o.user_id = u and o.pay > 0)
          or exists(select 1 from oyun.profiller where id = u and yonetici)) then
    raise exception 'Banka Genel Müdürlüğü''ne yalnız bankanın ortakları girebilir.'; end if;
  if not s.aktif then raise exception 'Bu banka faal değil.'; end if;
  perform oyun.banka_dibs_tahsil(p_banka);
  select * into s from oyun.sirketler where id = p_banka;
  select * into bp from oyun.banka_politika where banka_id = p_banka;
  select * into ay from oyun.banka_yonetim_ayar where banka_id = p_banka;
  b := oyun.banka_bilanco(p_banka);
  return jsonb_build_object(
    'simdi', t, 'politika_faizi', oyun.politika_faizi(),
    'banka', jsonb_build_object('id', s.id, 'ad', s.ad, 'kurulus', s.kurulus, 'sermaye', s.sermaye, 'kasa', s.kasa,
       'yonetici', oyun.kad(s.yonetici), 'yonetebilir', yon,
       'renk', coalesce(bp.renk, 'lacivert'), 'slogan', bp.slogan, 'emniyet_payi', coalesce(bp.emniyet_payi, 0),
       'risk_profili', coalesce(bp.risk_profili, 'ozel'),
       'gizlilik', coalesce((select gorunurluk from oyun.kasa_gizlilik where tur = 'sirket' and kimlik = p_banka), 'gizli'),
       'ortaklar', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(o.user_id), 'pay', o.pay, 'ben', o.user_id = u,
            'kar_kasada', o.kar_kasada) order by o.pay desc) from oyun.sirket_ortaklari o where o.sirket_id = p_banka and o.pay > 0), '[]'::jsonb)),
    'bilanco', b,
    'gelir7', oyun.banka_gelir(p_banka, 7), 'gelir30', oyun.banka_gelir(p_banka, 30),
    'urunler', jsonb_build_object(
       'mevduat7', least(s.banka_faiz, 1.8), 'kredi24', least(s.banka_kredi_faiz, 1.0),
       'vadeler', jsonb_build_object('1', oyun.oyb_oran(p_banka, 1), '3', oyun.oyb_oran(p_banka, 3), '6', oyun.oyb_oran(p_banka, 6),
                                     '12', oyun.oyb_oran(p_banka, 12), '24', oyun.oyb_oran(p_banka, 24)),
       'paketler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'ad', x.ad, 'vade_gun', x.vade_gun, 'taksit_sayisi', x.taksit_sayisi,
            'faiz', x.faiz, 'min_tutar', x.min_tutar, 'max_tutar', x.max_tutar, 'otomatik', x.otomatik, 'min_not', x.min_not, 'aktif', x.aktif,
            'kullanan', (select count(*) from oyun.oyb_kredi k where k.paket_id = x.id and k.durum in ('aktif','takip'))) order by x.vade_gun, x.id)
          from oyun.oyb_kredi_paket x where x.banka_id = p_banka and x.silindi_at is null), '[]'::jsonb),
       'pos_komisyon', 2,
       'otomatik', jsonb_build_object('pos', coalesce((select otomatik_onay from oyun.pos_banka_ayar where banka_id = p_banka), false),
                                      'kart', coalesce(ay.kart_otomatik, false), 'kredi', coalesce(ay.kredi_otomatik, false)),
       'asgari_not', coalesce(ay.asgari_not, 850), 'kart_max', coalesce(ay.kart_azami, 500000), 'kredi_max', coalesce(ay.kredi_azami, 500000)),
    'bekleyen', jsonb_build_object(
       'krediler', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'kad', oyun.kad(k.borclu), 'anapara', k.anapara,
            'vade_gun', round(k.saat / 24.0, 1), 'taksit_sayisi', k.taksit_sayisi, 'oran', k.oran, 'toplam', k.toplam, 'basvuru', k.basvuru,
            'not', coalesce((select kredi_notu from oyun.banka_musteri where user_id = k.borclu), 1100),
            'hesap', oyun.oyb_hesap_acik(p_banka, k.borclu),
            'risk', oyun.oyb_kredi_limit(k.borclu, k.saat)) order by k.id)
          from oyun.oyb_kredi k where k.banka_id = p_banka and k.durum = 'basvuru'), '[]'::jsonb),
       'kartlar', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kad', oyun.kad(x.user_id), 'istek', x.istek,
            'istenen', x.istenen, 'izin', x.izin, 'bilgi', case when x.izin <> '[]'::jsonb then x.bilgi else '{}'::jsonb end,
            'teklif_limit', x.teklif_limit, 'basvuru', x.basvuru, 'hesap', oyun.oyb_hesap_acik(p_banka, x.user_id),
            'kapasite', oyun.kart_kredi_kapasite(x.user_id, p_banka)) order by x.id)
          from oyun.kart_basvurular x where x.banka_id = p_banka and x.durum = 'bekliyor'), '[]'::jsonb),
       'poslar', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'sirket', z.ad, 'sektor', z.sektor,
            'kad', oyun.kad(x.basvuran), 'basvuru', x.basvuru, 'hesap', oyun.oyb_hesap_acik(p_banka, x.basvuran)) order by x.id)
          from oyun.sirket_pos x join oyun.sirketler z on z.id = x.sirket_id where x.banka_id = p_banka and x.durum = 'bekliyor'), '[]'::jsonb)),
    'musteriler', coalesce((select jsonb_agg(q.j order by q.iliski desc) from (
         select jsonb_build_object('kad', oyun.kad(h.user_id), 'acilis', h.acilis,
           'not', coalesce(bm.kredi_notu, 1100), 'not_ad', oyun.not_ad(coalesce(bm.kredi_notu, 1100)),
           'vadesiz', coalesce(v.bakiye, 0), 'vadeli', coalesce(md.tp, 0), 'kredi', coalesce(kr.tp, 0), 'kart', coalesce(kc.tp, 0),
           'teklif', (select jsonb_build_object('id', x.id, 'tutar', x.tutar, 'son', x.son) from oyun.oyb_kredi_teklifi x
                      where x.banka_id = p_banka and x.user_id = h.user_id and x.durum = 'teklif' and x.son > t limit 1),
           'bilgi', (select b2.durum from oyun.oyb_hesap_bilgi b2 where b2.banka_id = p_banka and b2.user_id = h.user_id)) j,
           coalesce(v.bakiye, 0) + coalesce(md.tp, 0) + coalesce(kr.tp, 0) + coalesce(kc.tp, 0) iliski
         from oyun.oyb_hesap h
         left join oyun.banka_musteri bm on bm.user_id = h.user_id
         left join oyun.ib_vadesiz v on v.banka_id = p_banka and v.user_id = h.user_id
         left join lateral (select sum(anapara) tp from oyun.banka_mevduat x where x.banka_id = p_banka and x.user_id = h.user_id and not x.kapandi) md on true
         left join lateral (select sum(kalan) tp from oyun.oyb_kredi x where x.banka_id = p_banka and x.borclu = h.user_id and x.durum in ('aktif','takip')) kr on true
         left join lateral (select sum(borc) tp from oyun.kredi_kartlari x where x.banka_id = p_banka and x.user_id = h.user_id) kc on true
         where h.banka_id = p_banka and h.kapanis is null and h.user_id <> u
         order by h.acilis desc limit 200) q), '[]'::jsonb),
    'krediler', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'kad', oyun.kad(k.borclu), 'anapara', k.anapara,
         'toplam', k.toplam, 'kalan', k.kalan, 'oran', k.oran, 'vade_gun', round(k.saat / 24.0, 1), 'durum', k.durum,
         'acilis', k.acilis, 'vade', k.vade,
         'geciken', (select coalesce(sum(x.tutar - x.odenen), 0) from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t),
         'dava_acilabilir', k.durum = 'aktif' and exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar
                              and x.vade + interval '12 hours' <= t) and not exists(select 1 from oyun.oyb_icra i where i.kredi_id = k.id),
         'icra', (select jsonb_build_object('id', i.id, 'durum', i.durum) from oyun.oyb_icra i where i.kredi_id = k.id)) order by k.id desc)
       from oyun.oyb_kredi k where k.banka_id = p_banka and k.durum in ('aktif','takip')), '[]'::jsonb),
    'kartlar', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'kad', oyun.kad(k.user_id), 'limit', k.limit_tl, 'borc', k.borc,
         'durum', k.durum, 'gecikmis_asgari', k.gecikmis_asgari, 'son_dort', lpad((k.id % 10000)::text, 4, '0')) order by k.borc desc)
       from oyun.kredi_kartlari k where k.banka_id = p_banka and k.durum <> 'iptal'), '[]'::jsonb),
    'dibs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'tutar', d.tutar, 'gun', d.gun, 'oran', d.oran, 'acilis', d.acilis,
         'vade', d.vade, 'durum', d.durum, 'odenen', d.odenen, 'getiri', round(d.tutar * d.oran / 100, 2)) order by d.durum <> 'acik', d.id desc)
       from (select * from oyun.banka_dibs where banka_id = p_banka order by id desc limit 20) d), '[]'::jsonb),
    'dibs_oran', jsonb_build_object('1', oyun.banka_dibs_orani(1), '7', oyun.banka_dibs_orani(7), '30', oyun.banka_dibs_orani(30)),
    'temettuler', coalesce((select jsonb_agg(jsonb_build_object('tur', x.tur, 'brut', x.brut, 'stopaj', x.stopaj, 'net', x.net,
         'yapan', oyun.kad(x.yapan), 'zaman', x.zaman) order by x.id desc)
       from (select * from oyun.banka_temettu where banka_id = p_banka order by id desc limit 10) x), '[]'::jsonb),
    'hareketler', coalesce((select jsonb_agg(q.j order by q.z desc) from (
         (select jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'aciklama', h.aciklama, 'tur', 'banka') j, h.zaman z
            from oyun.sirket_hareket h where h.sirket_id = p_banka order by h.id desc limit 40)
         union all
         (select jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'aciklama', oyun.kad(h.user_id) || ' · ' || h.aciklama, 'tur', 'musteri'), h.zaman
            from oyun.ib_hareket h where h.banka_id = p_banka order by h.id desc limit 40)) q), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- I. ZAMANLAYICI: vadesi gelen DİBS'ler kasaya döner (sahibi paneli açmasa da)
-- ---------------------------------------------------------------------
do $cron$
begin
  if exists(select 1 from pg_extension where extname = 'pg_cron') then
    if not exists(select 1 from cron.job where jobname = 'banka-dibs-itfa') then
      perform cron.schedule('banka-dibs-itfa', '12-59/15 * * * *', 'select oyun.banka_dibs_tahsil(null)');
    end if;
  end if;
end $cron$;

-- ---------------------------------------------------------------------
-- J. CANLI FONKSİYON YAMALARI (canlı tanımı okur, tek ifadeyi değiştirir;
--    ifade yoksa atlar → iki kez çalıştırmak güvenlidir)
-- ---------------------------------------------------------------------
do $yama$
declare r record; f record; tanim text; yeni text; adet int := 0; atla text := '';
begin
  for f in
    with liste(ad, tur, takma) as (values
      ('oyb_liste','sirket','s'), ('ib_hesap_ozet','sirket','s'), ('banka_mevduat_teklif','sirket','s'),
      ('oyb_kredi_masasi','sirket','s'), ('borsa_sirket','sirket','s'), ('sirket_vitrini','sirket','s'),
      ('sirket_karnesi','sirket','s'), ('pazar_detay','sirket','s'), ('pazar_katalog','sirket','s'),
      ('eko_panel','sirket','s'), ('halka_arz_durum','sirket','s'), ('ajans_yonetim','sirket','s'),
      ('npc_isletme_panel','sirket','s'), ('sirket_finans_ozeti','sirket','s'), ('sirket_sube_finans','sirket','s'),
      ('sirket_liste','sirket','s'), ('cek_panel','sirket','s'), ('siyasi_bagislar','sirket','s'),
      ('konkordato_durum','sirket','s'), ('konkordato_ekrani','sirket','s'), ('ihale_ekrani','sirket','s'),
      ('eko_ticaret_panel','sirket','s'), ('eko_vergi_panel','sirket','s'), ('kamu_toptan_panel','sirket','s'),
      ('eko_emlak_panel','sirket','s'), ('ortak_sirket_panel','sirket','s'), ('sigorta_afet_panel','sirket','s'),
      ('sigorta_isletme_panel','sirket','s'), ('uc_etkinlik_panel','sirket','s'), ('uc_tarim_panel','sirket','s'),
      ('pos_banka_panel','sirket','b'), ('banka_yonetilen_liste','sirket','b'), ('banka_yonetim_panel','sirket','b'),
      ('dernek_detay','dernek','d'), ('dernek_faaliyetler','dernek','d'), ('dernek_program_ozet','dernek','d'),
      ('dernek_uye_destek_liste','dernek','d'), ('basin','gazete','g'))
    select l.*, p.oid from liste l join pg_proc p on p.proname = l.ad and p.pronamespace = 'public'::regnamespace
  loop
    tanim := pg_get_functiondef(f.oid);
    if tanim !~ ('(oyun\.(sirketler|dernekler|oyuncu_gazeteleri)\s+(as\s+)?' || f.takma || '\M)|(\m' || f.takma || '\s+oyun\.(sirketler|dernekler|oyuncu_gazeteleri)\M)') then
      atla := atla || f.ad || '(takma ad), '; continue;
    end if;
    yeni := regexp_replace(tanim,
      '''kasa''(\s*),(\s*)(round\(\s*)?' || f.takma || '\.kasa\M',
      '''kasa''\1,\2\3oyun.kasa_goster(''' || f.tur || ''', ' || f.takma || '.id, ' || f.takma || '.kasa)', 'g');
    if f.ad = 'oyb_kredi_masasi' then
      yeni := replace(yeni, '''kredi_verilebilir'', greatest(0, (sag->>''kredi_verilebilir'')::numeric)',
                            '''kredi_verilebilir'', oyun.kasa_goster(''sirket'', s.id, greatest(0, (sag->>''kredi_verilebilir'')::numeric))');
    elsif f.ad = 'sirket_karnesi' then
      yeni := replace(yeni, '''defter'', round(oyun.sirket_defter(s.id))',
                            '''defter'', round(oyun.kasa_goster(''sirket'', s.id, oyun.sirket_defter(s.id)))');
      yeni := replace(yeni, '''deger'', oyun.sirket_deger(s.id)',
                            '''deger'', oyun.kasa_goster(''sirket'', s.id, oyun.sirket_deger(s.id))');
    elsif f.tur = 'dernek' then
      yeni := regexp_replace(yeni, '''serbest''(\s*),(\s*)oyun\.dernek_serbest_kasa\(d\.id\)',
                                   '''serbest''\1,\2oyun.kasa_goster(''dernek'', d.id, oyun.dernek_serbest_kasa(d.id))', 'g');
    end if;
    if yeni <> tanim then execute yeni; adet := adet + 1; end if;
  end loop;

  -- Takma adı olmayan liste sorguları (from oyun.sirketler where sektor=...)
  for f in select p.oid, p.proname from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.proname in ('oyuncu_banka_liste','kart_panel','uc_kitap_panel') loop
    tanim := pg_get_functiondef(f.oid);
    yeni := replace(tanim, '''ad'',ad,''kasa'',kasa)', '''ad'',ad,''kasa'',oyun.kasa_goster(''sirket'',id,kasa))');
    yeni := replace(yeni, '''faiz'',least(banka_faiz,1.8),''kasa'',kasa)', '''faiz'',least(banka_faiz,1.8),''kasa'',oyun.kasa_goster(''sirket'',id,kasa))');
    if yeni <> tanim then execute yeni; adet := adet + 1; end if;
  end loop;

  -- Bankalarda vadesiz mevduat da borçtur: eski kâr payı fonksiyonu banka için yeni kurala yönlenir
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'sirket_kar_payi' loop
    tanim := pg_get_functiondef(f.oid);
    if position('banka_kar_dagit' in tanim) = 0 then
      yeni := regexp_replace(tanim, '(\nbegin\n)',
        E'\\1 if (select sektor from oyun.sirketler where id=p_sirket)=''banka'' then return public.banka_kar_dagit(p_sirket,p_tutar); end if;\n', '');
      if yeni <> tanim then execute yeni; adet := adet + 1; else atla := atla || 'sirket_kar_payi, '; end if;
    end if;
  end loop;

  -- Haftalık şirket hesabında banka zararı / dağıtımı vadesiz mevduatı korur
  for f in select p.oid from pg_proc p where p.pronamespace = 'oyun'::regnamespace and p.proname = 'sirket_hesapla' loop
    tanim := pg_get_functiondef(f.oid);
    yeni := replace(tanim, '(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(',
                           '(select kasa from oyun.sirketler where id=p_id)-v_taahhut-oyun.banka_vadesiz_toplam(p_id)-greatest(');
    yeni := replace(yeni, 'where m.banka_id=p_id and not m.kapandi),0))) else least(net',
                          'where m.banka_id=p_id and not m.kapandi),0)-oyun.banka_vadesiz_toplam(p_id))) else least(net');
    if yeni <> tanim then execute yeni; adet := adet + 1; end if;
  end loop;

  -- Devlet Bankası kredi kartı: Hazine milyar birimiyle çalışır (TL / pazar_tl_milyar)
  for f in select p.oid, p.proname from pg_proc p
            where p.pronamespace in ('public'::regnamespace, 'oyun'::regnamespace)
              and p.proname in ('kart_harca','kart_nakit_avans','kart_ode','kart_pos_iade') loop
    tanim := pg_get_functiondef(f.oid);
    yeni := regexp_replace(tanim, 'hazine\s*=\s*hazine\s*-\s*n(\s+where\s+id\s*=\s*1\s+and\s+hazine\s*>=\s*)n\M',
                                  'hazine=hazine-n/oyun.pazar_tl_milyar()\1n/oyun.pazar_tl_milyar()', 'gi');
    yeni := regexp_replace(yeni, 'hazine\s*=\s*hazine\s*\+\s*o(\s+where\s+id\s*=\s*1)', 'hazine=hazine+o/oyun.pazar_tl_milyar()\1', 'gi');
    yeni := regexp_replace(yeni, 'hazine\s*=\s*hazine\s*\+\s*karta(\s+where\s+id\s*=\s*1)', 'hazine=hazine+karta/oyun.pazar_tl_milyar()\1', 'gi');
    if yeni <> tanim then execute yeni; adet := adet + 1; end if;
  end loop;

  -- POS otomatik onayı: hesabı olmayan eski başvurular toplu onayı kilitlemesin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'pos_banka_otomatik' loop
    tanim := pg_get_functiondef(f.oid);
    yeni := replace(tanim, E'where banka_id=p_banka and durum=''bekliyor''\n    returning basvuran',
                           E'where banka_id=p_banka and durum=''bekliyor'' and oyun.oyb_hesap_acik(p_banka,basvuran)\n    returning basvuran');
    if yeni <> tanim then execute yeni; adet := adet + 1; end if;
  end loop;

  raise notice 'bankacilik_v2 yamalari: % fonksiyon guncellendi; atlanan: %', adet, coalesce(nullif(atla, ''), 'yok');
end $yama$;

-- ---------------------------------------------------------------------
-- K. YETKİLER
-- ---------------------------------------------------------------------
do $yetki$
declare f text;
begin
  foreach f in array array[
    'public.banka_dibs_al(bigint,numeric,integer)', 'public.banka_dibs_boz(bigint,bigint)',
    'public.banka_sermaye_koy(bigint,numeric)', 'public.banka_kar_dagit(bigint,numeric)', 'public.banka_sermaye_azalt(bigint,numeric)',
    'public.banka_politika_kaydet(bigint,numeric,text,text)', 'public.banka_risk_profili(bigint,text)',
    'public.kasa_gizlilik_ayarla(text,bigint,text)', 'public.kasa_gizlilik_listem()',
    'public.banka_sube()', 'public.banka_alici(text)', 'public.banka_fast(text,text,text,numeric,text)',
    'public.banka_hesaplar_arasi(text,text,numeric)', 'public.banka_yonettiklerim()', 'public.banka_genel_mudurluk(bigint)']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array[
    'oyun.kasa_goster(text,bigint,numeric)', 'oyun.kasa_yetkili(text,bigint,uuid)', 'oyun.banka_bilanco(bigint)',
    'oyun.banka_gelir(bigint,integer)', 'oyun.banka_kunye(bigint,uuid)', 'oyun.banka_dibs_tahsil(bigint)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $yetki$;
