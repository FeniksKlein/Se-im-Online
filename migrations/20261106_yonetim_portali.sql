-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 164) SÜPER YÖNETİCİ PORTALI · AŞAMA 0 + 1
--  (06.11.2026)
--
--  Ayrı web portalı (docs/yonetim/) yalnızca bu dosyadaki public.yp_* işlemlerini çağırır.
--
--  Güvenlik (Aşama 0)
--    • oyun.yp_sahip(): oyunun yöneticisi + çok faktörlü doğrulanmış oturum (JWT aal = aal2).
--      Kritik işlemler son 10 dakikada kod girilmiş olmasını da ister (JWT amr totp zamanı).
--    • Her veri değiştiren işlem iki adımdır:
--        yp_onizle(islem, parametre) → etkilenecek kayıtlar, riskler, engel, tek kullanımlık anahtar
--        yp_uygula(anahtar, onay)    → aynı ön izleme yeniden hesaplanır; veriler değiştiyse durur,
--                                     aynı anahtar ikinci kez uygulanmaz (mükerrer kayıt yok).
--    • oyun.yp_islem: kim, ne zaman, ne yaptı; ön izleme, önceki/yeni değerler, sonuç, hata, geri alma.
--    • Gizli oy: hiçbir yp_* işlemi seçmen ile tercihini birlikte döndürmez; yalnız katılım sayıları.
--
--  Seçim merkezi (Aşama 1)
--    takvim değiştir · oylamayı şimdi başlat · süreyi uzat · oylamayı bitir · erken genel seçim ilan et ·
--    MV adaylığı (tek/toplu, CB adayları hariç) · adaylık iptali · CB adaylarını MV adaylığından çıkar ·
--    boş pusula uyarısı · oy kullanamayan oyuncu teşhisi · geri alma.
--
--  Oyuncu verisini değiştirmez; yalnız yeni tablo ve fonksiyon ekler. İki kez çalışabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Tablolar
-- ---------------------------------------------------------------------
create table if not exists oyun.yp_katalog (
  islem text primary key,
  baslik text not null,
  aciklama text,
  grup text not null default 'genel',
  kritik boolean not null default false,
  geri_alinabilir boolean not null default false,
  onay_metni text
);
alter table oyun.yp_katalog enable row level security;

create table if not exists oyun.yp_islem (
  id bigserial primary key,
  anahtar uuid not null unique default gen_random_uuid(),
  islem text not null,
  parametre jsonb not null default '{}'::jsonb,
  durum text not null default 'onizleme'
    check (durum in ('onizleme', 'uygulandi', 'basarisiz', 'iptal', 'geri_alindi')),
  user_id uuid,
  kad text,
  olusturma timestamptz not null default now(),
  gecerlilik timestamptz not null,
  onizleme jsonb,
  parmak text,
  uygulama timestamptz,
  sonuc jsonb,
  once jsonb,
  sonra jsonb,
  hata text,
  geri_alan bigint,
  geri_alinan bigint
);
alter table oyun.yp_islem enable row level security;
create index if not exists yp_islem_olusturma on oyun.yp_islem (olusturma desc);
create index if not exists yp_islem_durum on oyun.yp_islem (durum, olusturma desc);

insert into oyun.yp_katalog (islem, baslik, aciklama, grup, kritik, geri_alinabilir, onay_metni) values
  ('secim_takvim', 'Seçim takvimini değiştir', 'Başvuru, oylama, sonuç ve göreve başlama saatlerini değiştirir.', 'secim', false, true, null),
  ('secim_simdi_baslat', 'Oylamayı şimdi başlat', 'Oy vermeyi hemen açar; açık başvurular kapanır.', 'secim', true, true, 'ONAYLIYORUM'),
  ('secim_uzat', 'Oy verme süresini uzat', 'Oylama bitişini, sonuç ve göreve başlama saatini aynı süre kadar kaydırır.', 'secim', false, true, null),
  ('secim_oylamayi_bitir', 'Oylamayı şimdi bitir', 'Sandığı hemen kapatır; sonuç belirlenen dakikada açıklanır.', 'secim', true, true, 'ONAYLIYORUM'),
  ('genel_secim_olustur', 'Erken genel seçim ilan et', 'Milletvekili ve (başkanlık sisteminde) Cumhurbaşkanlığı ön seçim + seçim takvimini kurar.', 'secim', true, true, 'ONAYLIYORUM'),
  ('mv_toplu_adaylik', 'Milletvekili adaylığı', 'Seçilen veya filtreye uyan bütün uygun oyuncuları kendi il ve partisinden MV adayı yapar.', 'secim', true, true, 'ONAYLIYORUM'),
  ('adaylik_iptal', 'Adaylığı iptal et', 'Oylama başlamamış bir seçimdeki adaylığı kaldırır.', 'secim', false, true, null),
  ('cb_adaylari_mv_den_cikar', 'CB adaylarını MV adaylığından çıkar', 'Aynı dönemde Cumhurbaşkanı adayı olanların milletvekili adaylıklarını kaldırır.', 'secim', true, true, 'ONAYLIYORUM'),
  ('geri_al', 'İşlemi geri al', 'Daha önce uygulanmış bir yönetici işlemini geri alır.', 'genel', true, false, 'ONAYLIYORUM')
on conflict (islem) do update set
  baslik = excluded.baslik, aciklama = excluded.aciklama, grup = excluded.grup,
  kritik = excluded.kritik, geri_alinabilir = excluded.geri_alinabilir, onay_metni = excluded.onay_metni;

-- ---------------------------------------------------------------------
-- 2) Yetki kapısı
-- ---------------------------------------------------------------------
create or replace function oyun.yp_sahip(p_taze_dk integer default null)
returns oyun.profiller
language plpgsql
stable
set search_path to 'oyun', 'public', 'extensions', 'pg_temp'
as $$
declare
  p oyun.profiller := oyun.profilim();
  j jsonb := coalesce(auth.jwt(), '{}'::jsonb);
  son numeric;
begin
  if not coalesce(p.yonetici, false) then
    raise exception 'YP_YETKI: Bu portal yalnızca oyunun sahibine açıktır.';
  end if;
  if coalesce(j->>'aal', '') <> 'aal2' then
    raise exception 'YP_MFA: Bu işlem için doğrulama uygulamasındaki kodla giriş yapmalısın.';
  end if;
  if p_taze_dk is not null then
    select max((e->>'timestamp')::numeric) into son
    from jsonb_array_elements(case when jsonb_typeof(j->'amr') = 'array' then j->'amr' else '[]'::jsonb end) e
    where e->>'method' in ('totp', 'mfa/totp');
    if son is null or to_timestamp(son) < now() - make_interval(mins => p_taze_dk) then
      raise exception 'YP_TAZE: Bu kritik işlem için doğrulama kodunu yeniden girmelisin.';
    end if;
  end if;
  return p;
end $$;

-- ---------------------------------------------------------------------
-- 3) Yardımcılar
-- ---------------------------------------------------------------------
create or replace function oyun.yp_tur_ad(p_tur text)
returns text language sql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case p_tur
    when 'mv_on' then 'Milletvekili ön seçimi' when 'mv' then 'Milletvekili genel seçimi'
    when 'cb_on' then 'Cumhurbaşkanlığı ön seçimi' when 'cb' then 'Cumhurbaşkanlığı seçimi'
    when 'cb2' then 'Cumhurbaşkanlığı ikinci turu' when 'bel_on' then 'Belediye ön seçimi'
    when 'bel' then 'Belediye seçimi' when 'kurultay' then 'Kurultay' else p_tur end
$$;

create or replace function oyun.yp_asama(s oyun.secimler, t timestamptz)
returns text language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case
    when coalesce(s.sonuc ? 'iptal', false) then 'iptal'
    when s.durum = 'tamam' then 'tamam'
    when s.durum = 'sonuclandi' then 'sonuclandi'
    when s.basvuru_bas is not null and t >= s.basvuru_bas and t < s.basvuru_bit and t < s.oy_bas then 'basvuru'
    when t < s.oy_bas then 'bekliyor'
    when t < s.oy_bit then 'oy'
    else 'sayim' end
$$;

create or replace function oyun.yp_secim_json(s oyun.secimler, t timestamptz)
returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select jsonb_build_object(
    'id', s.id, 'tur', s.tur, 'tur_ad', oyun.yp_tur_ad(s.tur), 'donem', s.donem, 'durum', s.durum,
    'asama', oyun.yp_asama(s, t), 'ara', s.ara, 'ara_neden', s.ara_neden,
    'hedef_il', (select ad from oyun.iller where id = s.hedef_il_id),
    'hedef_parti', (select kisa from oyun.partiler where id = s.hedef_parti_id),
    'basvuru_bas', s.basvuru_bas, 'basvuru_bit', s.basvuru_bit, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit,
    'sonuc_at', s.sonuc_at, 'goreve_bas', s.goreve_bas,
    'aday', (select count(*) from oyun.adaylar a where a.secim_id = s.id),
    'katilim', (select count(*) from oyun.oylar o where o.secim_id = s.id))
$$;

-- Oturum saat diliminden bağımsız, karşılaştırılabilir zaman metni (UTC, ISO 8601).
create or replace function oyun.yp_iso(z timestamptz)
returns text language sql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select to_char(z at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
$$;

create or replace function oyun.yp_takvim_json(s oyun.secimler)
returns jsonb language sql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select jsonb_build_object('basvuru_bas', oyun.yp_iso(s.basvuru_bas), 'basvuru_bit', oyun.yp_iso(s.basvuru_bit),
    'oy_bas', oyun.yp_iso(s.oy_bas), 'oy_bit', oyun.yp_iso(s.oy_bit), 'sonuc_at', oyun.yp_iso(s.sonuc_at),
    'goreve_bas', oyun.yp_iso(s.goreve_bas))
$$;

-- Bir seçimin tarihlerinin kendi içinde ve ön seçim / asıl seçim ile tutarlılığı.
create or replace function oyun.yp_takvim_engel(s oyun.secimler)
returns text language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare onceki text; sonraki text; r oyun.secimler;
begin
  if s.oy_bas is null or s.oy_bit is null or s.sonuc_at is null then
    return 'Oylama başlangıcı, bitişi ve sonuç saati boş olamaz.'; end if;
  if s.oy_bit <= s.oy_bas then return 'Oylama bitişi başlangıçtan sonra olmalı.'; end if;
  if s.sonuc_at < s.oy_bit then return 'Sonuç saati oylama bitişinden önce olamaz.'; end if;
  if s.goreve_bas is not null and s.goreve_bas < s.sonuc_at then
    return 'Göreve başlama sonuç saatinden önce olamaz.'; end if;
  if (s.basvuru_bas is null) <> (s.basvuru_bit is null) then
    return 'Başvuru başlangıcı ve bitişi birlikte girilmeli.'; end if;
  if s.basvuru_bas is not null and s.basvuru_bit < s.basvuru_bas then
    return 'Başvuru bitişi başlangıcından önce olamaz.'; end if;
  if s.basvuru_bit is not null and s.basvuru_bit > s.oy_bas then
    return 'Başvurular oylama başlamadan kapanmalı.'; end if;

  onceki := case s.tur when 'mv' then 'mv_on' when 'cb' then 'cb_on' when 'bel' then 'bel_on' when 'cb2' then 'cb' end;
  sonraki := case s.tur when 'mv_on' then 'mv' when 'cb_on' then 'cb' when 'bel_on' then 'bel' end;
  if onceki is not null then
    select * into r from oyun.secimler where tur = onceki and donem = s.donem;
    if r.id is not null and not coalesce(r.sonuc ? 'iptal', false) and r.sonuc_at > s.oy_bas then
      return format('%s sonucu (%s) bu seçimin oylamasından (%s) önce açıklanmalı.',
        oyun.yp_tur_ad(r.tur), oyun.tr_tarih_saat(r.sonuc_at), oyun.tr_tarih_saat(s.oy_bas));
    end if;
  end if;
  if sonraki is not null then
    select * into r from oyun.secimler where tur = sonraki and donem = s.donem;
    if r.id is not null and not coalesce(r.sonuc ? 'iptal', false) and r.durum = 'bekliyor' and s.sonuc_at > r.oy_bas then
      return format('Bu seçimin sonucu (%s) %s oylamasından (%s) önce açıklanmalı.',
        oyun.tr_tarih_saat(s.sonuc_at), oyun.yp_tur_ad(r.tur), oyun.tr_tarih_saat(r.oy_bas));
    end if;
  end if;
  return null;
end $$;

-- Oyuncu aynı dönemde Cumhurbaşkanı adayı mı? (kaybedilmiş ön seçim başvurusu sayılmaz)
create or replace function oyun.yp_cb_adayi(u uuid, d text)
returns boolean language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select exists (
    select 1 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
    where a.user_id = u and s.donem = d
      and (s.tur in ('cb', 'cb2') or (s.tur = 'cb_on' and s.durum = 'bekliyor'))
      and not coalesce(s.sonuc ? 'iptal', false))
  or exists (select 1 from oyun.cb_kararlar k where k.donem = d and k.aday = u)
$$;

-- MV adaylığına engel (null = uygun). Oyuncu tarafındaki aday_ol / bagimsiz_aday_ol kurallarıyla aynı.
create or replace function oyun.yp_mv_uygunluk(pr oyun.profiller, sm oyun.secimler, t timestamptz)
returns text language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pa oyun.partiler; e text;
begin
  if pr.yasakli then return 'Hesabı engelli.'; end if;
  if pr.il_id is null then return 'İl seçmemiş.'; end if;
  e := oyun.uyari(pr, t);
  if e is not null then return e; end if;
  if pr.adaylik_yasagi_bitis is not null and pr.adaylik_yasagi_bitis > t then
    return format('Adaylık yasağı %s tarihine kadar sürüyor.', oyun.tr_tarih_saat(pr.adaylik_yasagi_bitis)); end if;
  if exists (select 1 from oyun.mahkeme_uye where sira in (1, 2) and user_id = pr.id) then
    return 'Yüksek Mahkemenin 1. ve 2. üyeleri aday olamaz.'; end if;
  if sm.ara and sm.hedef_il_id is not null and pr.il_id is distinct from sm.hedef_il_id then
    return 'Bu seçim başka bir il için.'; end if;
  if pr.parti_id is not null then
    select * into pa from oyun.partiler where id = pr.parti_id;
    if coalesce(pa.kapali, false) then return 'Partisi kapalı.'; end if;
    if pa.kurulus_bit is not null then return 'Partisi kuruluş aşamasında.'; end if;
    e := oyun.teskilat_engeli(pr, 'mv_on');
    if e is not null then return e; end if;
    if pa.gb = pr.id and exists (select 1 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
        where a.user_id = pr.id and s.donem = sm.donem and s.tur in ('cb', 'cb2')) then
      return 'Cumhurbaşkanı adayı olan genel başkan aynı dönemde MV adayı olamaz.'; end if;
  end if;
  return null;
end $$;

-- MV pusulası boş kalacak iller: ilde ne parti listesi ne bağımsız aday var.
create or replace function oyun.yp_bos_pusula(p_mv bigint)
returns table (il_id smallint, il text, secmen integer)
language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  with sm as (select * from oyun.secimler where id = p_mv and tur = 'mv'),
       so as (select o.* from oyun.secimler o join sm on o.tur = 'mv_on' and o.donem = sm.donem)
  select pr.il_id, i.ad, count(*)::integer
  from oyun.profiller pr join oyun.iller i on i.id = pr.il_id, sm
  where not pr.yasakli
    and not exists (select 1 from oyun.adaylar a, so where a.secim_id = so.id and a.il_id = pr.il_id
                    and a.parti_id is not null and (a.sira is not null or so.durum = 'bekliyor'))
    and not exists (select 1 from oyun.adaylar a where a.secim_id = sm.id and a.il_id = pr.il_id and a.parti_id is null)
  group by pr.il_id, i.ad
  order by 3 desc, 2
$$;

create or replace function oyun.yp_bildir_herkese(p_metin text, t timestamptz)
returns integer language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare n integer;
begin
  insert into oyun.bildirimler (user_id, zaman, metin)
  select id, t, p_metin from oyun.profiller where not yasakli;
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------
-- 4) İşlem: seçim takvimi (ve onu kullanan kısayollar)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_secim_takvim(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare
  t timestamptz := oyun.simdi();
  s oyun.secimler; y oyun.secimler; yama jsonb := '{}'::jsonb; k text; e text;
  degisen jsonb := '[]'::jsonb; uyari jsonb := '[]'::jsonb;
begin
  select * into s from oyun.secimler where id = (p->>'secim_id')::bigint;
  if s.id is null then return jsonb_build_object('engel', 'Seçim bulunamadı.'); end if;
  if coalesce(s.sonuc ? 'iptal', false) then return jsonb_build_object('engel', 'Bu seçim iptal edilmiş.'); end if;
  if s.durum <> 'bekliyor' then return jsonb_build_object('engel', 'Sonuçlanmış seçimin takvimi değiştirilemez.'); end if;
  if oyun.secim_gecesi_aktif_mi(s.id) then
    return jsonb_build_object('engel', 'Seçim gecesi sonuç yayını sürüyor; bitince tekrar dene.'); end if;

  foreach k in array array['basvuru_bas', 'basvuru_bit', 'oy_bas', 'oy_bit', 'sonuc_at', 'goreve_bas'] loop
    if p ? k then yama := yama || jsonb_build_object(k, nullif(p->>k, '')::timestamptz); end if;
  end loop;
  if s.tur not in ('mv_on', 'bel_on', 'kurultay', 'cb_on', 'cb') then yama := yama - 'basvuru_bas' - 'basvuru_bit'; end if;
  if s.goreve_bas is null then yama := yama - 'goreve_bas'; end if;
  y := jsonb_populate_record(s, yama);

  foreach k in array array['basvuru_bas', 'basvuru_bit', 'oy_bas', 'oy_bit', 'sonuc_at', 'goreve_bas'] loop
    if (oyun.yp_takvim_json(s)->>k) is distinct from (oyun.yp_takvim_json(y)->>k) then
      degisen := degisen || jsonb_build_array(jsonb_build_object('alan', k,
        'eski', oyun.yp_takvim_json(s)->k, 'yeni', oyun.yp_takvim_json(y)->k));
    end if;
  end loop;
  if jsonb_array_length(degisen) = 0 then return jsonb_build_object('engel', 'Değişiklik yok.'); end if;

  e := oyun.yp_takvim_engel(y);
  if e is null and y.oy_bas > t and exists (select 1 from oyun.oylar where secim_id = s.id) then
    e := 'Oy kullanılmış bir seçimin başlangıcı ileri alınamaz.'; end if;
  if e is null and y.oy_bit <= t and s.oy_bit > t and s.oy_bas <= t then
    uyari := uyari || to_jsonb('Sandık hemen kapanır.'::text); end if;
  if e is null and y.sonuc_at <= t then
    uyari := uyari || to_jsonb('Sonuç saati geçmiş olacak: motor ilk dakikada sonuçlandırır.'::text); end if;
  if s.oy_bas <= t and t < s.oy_bit then
    uyari := uyari || to_jsonb('Oylama şu anda sürüyor.'::text); end if;
  if coalesce((p->>'duyur')::boolean, true) then
    uyari := uyari || to_jsonb(format('Bütün oyunculara (%s kişi) takvim bildirimi gider.',
      (select count(*) from oyun.profiller where not yasakli))); end if;

  return jsonb_build_object(
    'ozet', format('%s: %s alan değişecek.', oyun.yp_tur_ad(s.tur), jsonb_array_length(degisen)),
    'secim', oyun.yp_secim_json(s, t), 'degisen', degisen, 'sayi', 1,
    'uyarilar', uyari, 'engel', e,
    'parmak', md5(oyun.yp_takvim_json(s)::text || s.durum));
end $$;

create or replace function oyun.yp_uy_secim_takvim(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); s oyun.secimler; y oyun.secimler; o jsonb; k text; yama jsonb := '{}'::jsonb; n integer := 0;
begin
  select * into s from oyun.secimler where id = (p->>'secim_id')::bigint for update;
  o := oyun.yp_on_secim_takvim(p);
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  foreach k in array array['basvuru_bas', 'basvuru_bit', 'oy_bas', 'oy_bit', 'sonuc_at', 'goreve_bas'] loop
    if p ? k then yama := yama || jsonb_build_object(k, nullif(p->>k, '')::timestamptz); end if;
  end loop;
  if s.tur not in ('mv_on', 'bel_on', 'kurultay', 'cb_on', 'cb') then yama := yama - 'basvuru_bas' - 'basvuru_bit'; end if;
  if s.goreve_bas is null then yama := yama - 'goreve_bas'; end if;
  y := jsonb_populate_record(s, yama);

  update oyun.secimler set basvuru_bas = y.basvuru_bas, basvuru_bit = y.basvuru_bit, oy_bas = y.oy_bas,
    oy_bit = y.oy_bit, sonuc_at = y.sonuc_at, goreve_bas = y.goreve_bas,
    hatirlatma = case when y.oy_bas is distinct from s.oy_bas and y.oy_bas > t then null else hatirlatma end
  where id = s.id;

  perform oyun.olay('secim', format('Seçim takvimi güncellendi: %s oylaması %s – %s, sonuç %s.',
    oyun.yp_tur_ad(s.tur), oyun.tr_tarih_saat(y.oy_bas), to_char(y.oy_bit at time zone 'Europe/Istanbul', 'HH24:MI'),
    oyun.tr_tarih_saat(y.sonuc_at)), s.hedef_il_id, s.hedef_parti_id, t);
  if coalesce((p->>'duyur')::boolean, true) then
    n := oyun.yp_bildir_herkese(format('Resmî duyuru · %s takvimi güncellendi. Oylama: %s – %s. Sonuç: %s.%s',
      oyun.yp_tur_ad(s.tur), oyun.tr_tarih_saat(y.oy_bas), to_char(y.oy_bit at time zone 'Europe/Istanbul', 'HH24:MI'),
      oyun.tr_tarih_saat(y.sonuc_at),
      case when y.basvuru_bit is not null and y.basvuru_bit > t then ' Başvurular ' || oyun.tr_tarih_saat(y.basvuru_bit) || ' saatine kadar açık.' else '' end), t);
  end if;

  select * into y from oyun.secimler where id = s.id;
  return jsonb_build_object(
    'ozet', format('%s takvimi güncellendi.', oyun.yp_tur_ad(s.tur)),
    'hedef', oyun.yp_tur_ad(s.tur) || ' #' || s.id,
    'once', jsonb_build_object('secim_id', s.id, 'takvim', oyun.yp_takvim_json(s)),
    'sonra', jsonb_build_object('secim_id', s.id, 'takvim', oyun.yp_takvim_json(y)),
    'bildirim', n,
    'dogrulama', jsonb_build_object('kayit', oyun.yp_takvim_json(y),
      'tutarli', oyun.yp_takvim_engel(y) is null, 'asama', oyun.yp_asama(y, t)));
end $$;

-- Takvimi eski hâline döndürür (secim_takvim ve kısayolları için ortak).
create or replace function oyun.yp_gr_secim_takvim(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); s oyun.secimler; eski oyun.secimler; e text;
begin
  select * into s from oyun.secimler where id = (r.once->>'secim_id')::bigint;
  if s.id is null then return jsonb_build_object('engel', 'Seçim bulunamadı.'); end if;
  if s.durum <> 'bekliyor' then return jsonb_build_object('engel', 'Seçim sonuçlandı; takvim geri alınamaz.'); end if;
  if oyun.yp_takvim_json(s) <> (r.sonra->'takvim') then
    return jsonb_build_object('engel', 'Bu işlemden sonra takvim yeniden değişti; önce son değişikliği geri al.'); end if;
  eski := jsonb_populate_record(s, r.once->'takvim');
  e := oyun.yp_takvim_engel(eski);
  if e is null and eski.oy_bas > t and exists (select 1 from oyun.oylar where secim_id = s.id) then
    e := 'Bu arada oy kullanıldı; eski başlangıç saatine dönülemez.'; end if;
  if e is null and eski.sonuc_at <= t then e := 'Eski sonuç saati geçti; takvimi elle düzenle.'; end if;
  if not p_uygula or e is not null then
    return jsonb_build_object('ozet', format('%s eski takvimine döner.', oyun.yp_tur_ad(s.tur)),
      'degisen', jsonb_build_array(jsonb_build_object('alan', 'takvim', 'eski', r.sonra->'takvim', 'yeni', r.once->'takvim')),
      'sayi', 1, 'engel', e);
  end if;
  perform 1 from oyun.secimler where id = s.id for update;
  update oyun.secimler set basvuru_bas = eski.basvuru_bas, basvuru_bit = eski.basvuru_bit, oy_bas = eski.oy_bas,
    oy_bit = eski.oy_bit, sonuc_at = eski.sonuc_at, goreve_bas = eski.goreve_bas where id = s.id;
  perform oyun.olay('secim', format('%s takvimi önceki hâline döndürüldü: oylama %s.', oyun.yp_tur_ad(s.tur),
    oyun.tr_tarih_saat(eski.oy_bas)), s.hedef_il_id, s.hedef_parti_id, t);
  return jsonb_build_object('ozet', 'Takvim geri alındı.', 'once', r.sonra, 'sonra', r.once);
end $$;

-- Kısayolların takvim yaması.
create or replace function oyun.yp_takvim_yama(p_islem text, p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := date_trunc('minute', oyun.simdi()); s oyun.secimler; d integer; y jsonb;
begin
  select * into s from oyun.secimler where id = (p->>'secim_id')::bigint;
  if s.id is null then return jsonb_build_object('secim_id', p->>'secim_id'); end if;
  y := jsonb_build_object('secim_id', s.id, 'duyur', coalesce((p->>'duyur')::boolean, true));
  if p_islem = 'secim_simdi_baslat' then
    y := y || jsonb_build_object('oy_bas', t);
    if s.basvuru_bit is not null and s.basvuru_bit > t then y := y || jsonb_build_object('basvuru_bit', t); end if;
    if s.basvuru_bas is not null and s.basvuru_bas > t then y := y || jsonb_build_object('basvuru_bas', t); end if;
  elsif p_islem = 'secim_uzat' then
    d := coalesce((p->>'dakika')::integer, 0);
    y := y || jsonb_build_object('dakika', d, 'oy_bit', s.oy_bit + make_interval(mins => d),
      'sonuc_at', s.sonuc_at + make_interval(mins => d));
    if s.goreve_bas is not null then y := y || jsonb_build_object('goreve_bas', s.goreve_bas + make_interval(mins => d)); end if;
  elsif p_islem = 'secim_oylamayi_bitir' then
    d := greatest(0, coalesce((p->>'sonuc_dk')::integer, 0));
    y := y || jsonb_build_object('oy_bit', t, 'sonuc_at', t + make_interval(mins => d));
    if s.goreve_bas is not null and s.goreve_bas < t + make_interval(mins => d) then
      y := y || jsonb_build_object('goreve_bas', t + make_interval(mins => d)); end if;
  end if;
  return y;
end $$;

create or replace function oyun.yp_on_secim_simdi_baslat(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); s oyun.secimler; o jsonb; e text;
begin
  select * into s from oyun.secimler where id = (p->>'secim_id')::bigint;
  if s.id is null then return jsonb_build_object('engel', 'Seçim bulunamadı.'); end if;
  if s.oy_bas <= t then e := 'Oylama zaten başladı.'; end if;
  o := oyun.yp_on_secim_takvim(oyun.yp_takvim_yama('secim_simdi_baslat', p));
  return o || jsonb_build_object('ozet', format('%s oylaması şimdi açılacak.', oyun.yp_tur_ad(s.tur)),
    'engel', coalesce(e, o->>'engel'));
end $$;
create or replace function oyun.yp_uy_secim_simdi_baslat(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
begin
  if (oyun.yp_on_secim_simdi_baslat(p))->>'engel' is not null then
    raise exception '%', (oyun.yp_on_secim_simdi_baslat(p))->>'engel'; end if;
  return oyun.yp_uy_secim_takvim(oyun.yp_takvim_yama('secim_simdi_baslat', p));
end $$;
create or replace function oyun.yp_gr_secim_simdi_baslat(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$ select oyun.yp_gr_secim_takvim(r, p_uygula) $$;

create or replace function oyun.yp_on_secim_uzat(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare s oyun.secimler; o jsonb; e text; d integer := coalesce((p->>'dakika')::integer, 0);
begin
  select * into s from oyun.secimler where id = (p->>'secim_id')::bigint;
  if s.id is null then return jsonb_build_object('engel', 'Seçim bulunamadı.'); end if;
  if d < 1 or d > 10080 then e := 'Uzatma süresi 1 dakika ile 7 gün arasında olmalı.'; end if;
  o := oyun.yp_on_secim_takvim(oyun.yp_takvim_yama('secim_uzat', p));
  return o || jsonb_build_object('ozet', format('%s oylaması %s dakika uzatılacak.', oyun.yp_tur_ad(s.tur), d),
    'engel', coalesce(e, o->>'engel'));
end $$;
create or replace function oyun.yp_uy_secim_uzat(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_secim_uzat(p);
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  return oyun.yp_uy_secim_takvim(oyun.yp_takvim_yama('secim_uzat', p));
end $$;
create or replace function oyun.yp_gr_secim_uzat(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$ select oyun.yp_gr_secim_takvim(r, p_uygula) $$;

create or replace function oyun.yp_on_secim_oylamayi_bitir(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); s oyun.secimler; o jsonb; e text;
begin
  select * into s from oyun.secimler where id = (p->>'secim_id')::bigint;
  if s.id is null then return jsonb_build_object('engel', 'Seçim bulunamadı.'); end if;
  if t < s.oy_bas then e := 'Oylama henüz başlamadı; tarihini değiştirmek için takvimi düzenle.'; end if;
  if t >= s.oy_bit then e := 'Oylama zaten kapalı.'; end if;
  o := oyun.yp_on_secim_takvim(oyun.yp_takvim_yama('secim_oylamayi_bitir', p));
  return o || jsonb_build_object('ozet', format('%s sandığı şimdi kapanacak; %s oy kullanılmış.', oyun.yp_tur_ad(s.tur),
    (select count(*) from oyun.oylar where secim_id = s.id)), 'engel', coalesce(e, o->>'engel'));
end $$;
create or replace function oyun.yp_uy_secim_oylamayi_bitir(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_secim_oylamayi_bitir(p);
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  return oyun.yp_uy_secim_takvim(oyun.yp_takvim_yama('secim_oylamayi_bitir', p));
end $$;
create or replace function oyun.yp_gr_secim_oylamayi_bitir(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$ select oyun.yp_gr_secim_takvim(r, p_uygula) $$;

-- ---------------------------------------------------------------------
-- 5) İşlem: erken genel seçim
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_genel_secim_olustur(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare
  t timestamptz := oyun.simdi();
  ongun date; secgun date; e text; cb boolean := oyun.hukumet_sistemi() = 0;
  liste jsonb; uyari jsonb := '[]'::jsonb; r oyun.secimler;
begin
  begin ongun := (p->>'on_gun')::date; secgun := (p->>'secim_gun')::date;
  exception when others then return jsonb_build_object('engel', 'Tarihleri GG.AA.YYYY biçiminde seç.'); end;
  if ongun is null or secgun is null then e := 'Ön seçim ve seçim gününü seç.';
  elsif secgun <= ongun then e := 'Seçim günü ön seçim gününden sonra olmalı.';
  elsif oyun.tr_an(ongun, 8) < t + interval '1 hour' then e := 'Ön seçim en az 1 saat sonra, saat 08.00''de başlamalı.';
  elsif exists (select 1 from oyun.secimler where ara and ara_neden = 'erken_secim' and durum = 'bekliyor'
                and not coalesce(sonuc ? 'iptal', false)) then e := 'Bekleyen bir erken seçim takvimi zaten var.';
  elsif exists (select 1 from oyun.secimler where tur in ('mv_on', 'mv', 'cb_on', 'cb', 'cb2') and durum = 'bekliyor'
                and not coalesce(sonuc ? 'iptal', false) and oy_bas <= t and oy_bit > t) then
    e := 'Şu anda süren bir genel seçim/ön seçim oylaması var.';
  elsif exists (select 1 from oyun.secimler where tur = 'mv' and durum = 'bekliyor' and not coalesce(sonuc ? 'iptal', false)
                and abs(extract(epoch from (oy_bas - oyun.tr_an(secgun, 8)))) < 3 * 86400) then
    e := 'Seçilen güne 3 günden yakın başka bir genel seçim var.';
  end if;
  for r in select * from oyun.secimler where tur = 'mv' and durum = 'bekliyor' and not coalesce(sonuc ? 'iptal', false) loop
    uyari := uyari || to_jsonb(format('Mevcut %s tarihli genel seçim iptal edilmez; ayrıca yapılır.', oyun.tr_tarih_saat(r.oy_bas)));
  end loop;
  uyari := uyari || to_jsonb(format('Bütün oyunculara (%s kişi) seçim duyurusu ve gazete ilanı gider.',
    (select count(*) from oyun.profiller where not yasakli)));
  if not cb then uyari := uyari || to_jsonb('Parlamenter sistem: Cumhurbaşkanlığı seçimi kurulmaz.'::text); end if;
  if e is null then
    liste := jsonb_build_array(
      jsonb_build_object('tur_ad', 'Milletvekili ön seçimi', 'basvuru_bit', oyun.tr_an(ongun, 8), 'oy_bas', oyun.tr_an(ongun, 8), 'oy_bit', oyun.tr_an(ongun, 22), 'sonuc_at', oyun.tr_an(ongun, 22, 30)),
      jsonb_build_object('tur_ad', 'Milletvekili genel seçimi', 'oy_bas', oyun.tr_an(secgun, 8), 'oy_bit', oyun.tr_an(secgun, 22), 'sonuc_at', oyun.tr_an(secgun, 22, 30), 'goreve_bas', oyun.tr_an(secgun + 1, 0)));
    if cb then liste := liste || jsonb_build_array(
      jsonb_build_object('tur_ad', 'Cumhurbaşkanlığı ön seçimi', 'basvuru_bit', oyun.tr_an(ongun, 8), 'oy_bas', oyun.tr_an(ongun, 8), 'oy_bit', oyun.tr_an(ongun, 22), 'sonuc_at', oyun.tr_an(ongun, 22, 30)),
      jsonb_build_object('tur_ad', 'Cumhurbaşkanlığı seçimi', 'basvuru_bit', oyun.tr_an(ongun, 8), 'oy_bas', oyun.tr_an(secgun, 8), 'oy_bit', oyun.tr_an(secgun, 22), 'sonuc_at', oyun.tr_an(secgun, 22, 30), 'goreve_bas', oyun.tr_an(secgun + 1, 0)));
    end if;
  end if;
  return jsonb_build_object('ozet', format('Erken genel seçim: ön seçim %s, seçim %s.', to_char(ongun, 'DD.MM.YYYY'), to_char(secgun, 'DD.MM.YYYY')),
    'etkilenen', coalesce(liste, '[]'::jsonb), 'sayi', coalesce(jsonb_array_length(liste), 0), 'uyarilar', uyari, 'engel', e,
    'parmak', md5(coalesce(ongun::text, '') || coalesce(secgun::text, '') || cb::text));
end $$;

create or replace function oyun.yp_uy_genel_secim_olustur(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare
  t timestamptz := oyun.simdi(); o jsonb; ongun date := (p->>'on_gun')::date; secgun date := (p->>'secim_gun')::date;
  dm text; ids bigint[]; metin text; n integer;
begin
  perform 1 from oyun.ayarlar where id = 1 for update;
  o := oyun.yp_on_genel_secim_olustur(p);
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  dm := 'erken-genel-yp-' || to_char(t at time zone 'Europe/Istanbul', 'YYYYMMDDHH24MISS');
  with eklenen as (
    insert into oyun.secimler (tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas, ara, ara_neden)
    select x.tur, dm, x.bb, x.bt, x.ob, x.oe, x.so, x.gb, true, 'erken_secim' from (values
      ('mv_on', t, oyun.tr_an(ongun, 8), oyun.tr_an(ongun, 8), oyun.tr_an(ongun, 22), oyun.tr_an(ongun, 22, 30), null::timestamptz),
      ('mv', null, null, oyun.tr_an(secgun, 8), oyun.tr_an(secgun, 22), oyun.tr_an(secgun, 22, 30), oyun.tr_an(secgun + 1, 0)),
      ('cb_on', t, oyun.tr_an(ongun, 8), oyun.tr_an(ongun, 8), oyun.tr_an(ongun, 22), oyun.tr_an(ongun, 22, 30), null),
      ('cb', t, oyun.tr_an(ongun, 8), oyun.tr_an(secgun, 8), oyun.tr_an(secgun, 22), oyun.tr_an(secgun, 22, 30), oyun.tr_an(secgun + 1, 0))
    ) x(tur, bb, bt, ob, oe, so, gb)
    where x.tur in ('mv_on', 'mv') or oyun.hukumet_sistemi() = 0
    returning id)
  select array_agg(id order by id) into ids from eklenen;

  perform oyun.olay('secim', format('Erken genel seçim ilan edildi: seçim %s 08.00–22.00, ön seçimler %s.',
    to_char(secgun, 'DD.MM.YYYY'), to_char(ongun, 'DD.MM.YYYY')), null, null, t);
  metin := format('Resmî duyuru · Erken genel seçim %s günü 08.00–22.00 arasında yapılacak. '
    || 'Milletvekili aday adaylığı, bağımsız adaylık ve Cumhurbaşkanı adayı kararları %s 08.00''e kadar açık; '
    || 'ön seçimler %s 08.00–22.00. Sonuçlar seçim günü 22.30''da açıklanır. Takvim: Seçimler ekranı.',
    to_char(secgun, 'DD.MM.YYYY'), to_char(ongun, 'DD.MM.YYYY'), to_char(ongun, 'DD.MM.YYYY'));
  n := oyun.yp_bildir_herkese(metin, t);
  perform oyun.gazete_ekle('duyuru', format('Erken genel seçim %s', to_char(secgun, 'DD.MM.YYYY')), metin, null, t);

  return jsonb_build_object('ozet', format('Erken genel seçim kuruldu (%s seçim kaydı).', cardinality(ids)),
    'hedef', dm, 'once', '{}'::jsonb, 'sonra', jsonb_build_object('donem', dm, 'secim_ids', to_jsonb(ids)), 'bildirim', n,
    'dogrulama', jsonb_build_object('kayit', (select count(*) from oyun.secimler where donem = dm),
      'tutarli', not exists (select 1 from oyun.secimler s where s.donem = dm and oyun.yp_takvim_engel(s) is not null)));
end $$;

create or replace function oyun.yp_gr_genel_secim_olustur(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare ids bigint[] := array(select jsonb_array_elements_text(r.sonra->'secim_ids')::bigint); e text; t timestamptz := oyun.simdi();
begin
  if exists (select 1 from oyun.secimler where id = any(ids) and (durum <> 'bekliyor' or oy_bas <= t)) then
    e := 'Seçimlerden biri başladı veya sonuçlandı; iptal edilemez.';
  elsif exists (select 1 from oyun.oylar where secim_id = any(ids)) then e := 'Oy kullanılmış; iptal edilemez.';
  end if;
  if not p_uygula or e is not null then
    return jsonb_build_object('ozet', format('Erken genel seçim takvimi (%s kayıt) iptal edilecek; %s adaylık başvurusu geçersiz olur.',
      cardinality(ids), (select count(*) from oyun.adaylar where secim_id = any(ids))), 'sayi', cardinality(ids), 'engel', e);
  end if;
  update oyun.secimler set durum = 'tamam', sonuc = coalesce(sonuc, '{}'::jsonb) || jsonb_build_object('iptal', 'yonetici_geri_al')
  where id = any(ids);
  perform oyun.olay('secim', 'Erken genel seçim takvimi oyun yönetimince iptal edildi.', null, null, t);
  perform oyun.yp_bildir_herkese('Resmî duyuru · Erken genel seçim takvimi iptal edildi.', t);
  return jsonb_build_object('ozet', 'Erken genel seçim iptal edildi.', 'once', r.sonra, 'sonra', '{}'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6) İşlem: MV adaylığı (tek ya da toplu)
--    Parametre: secim_id (mv), il_id?, parti_id?, kullanicilar? [uuid], cb_haric (true), bagimsiz_dahil (true),
--               yonetici_haric (true; yalnız filtreyle seçimde)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_mv_toplu_adaylik(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare
  t timestamptz := oyun.simdi();
  sm oyun.secimler; so oyun.secimler; pr oyun.profiller; md text; neden text; secili uuid[];
  ekle jsonb := '[]'::jsonb; haric jsonb := '[]'::jsonb; uyari jsonb := '[]'::jsonb;
  zaten integer := 0; cb integer := 0; ids text[] := '{}'; bos_once integer; bos_sonra integer;
  cb_haric boolean := coalesce((p->>'cb_haric')::boolean, true);
  bagimsiz boolean := coalesce((p->>'bagimsiz_dahil')::boolean, true);
  yon_haric boolean := coalesce((p->>'yonetici_haric')::boolean, true);
begin
  select * into sm from oyun.secimler where id = (p->>'secim_id')::bigint;
  if sm.id is null or sm.tur <> 'mv' then return jsonb_build_object('engel', 'Bir milletvekili genel seçimi seçmelisin.'); end if;
  if sm.durum <> 'bekliyor' or coalesce(sm.sonuc ? 'iptal', false) then
    return jsonb_build_object('engel', 'Bu seçim tamamlanmış veya iptal edilmiş.'); end if;
  if t >= sm.oy_bas then return jsonb_build_object('engel', 'Oy verme başladı; sandık açıkken aday eklenemez.'); end if;
  select * into so from oyun.secimler where tur = 'mv_on' and donem = sm.donem;
  if so.id is null then return jsonb_build_object('engel', 'Bu seçimin ön seçimi bulunamadı.'); end if;
  md := case when so.durum = 'bekliyor' and t < so.oy_bas then 'basvuru' when so.durum = 'bekliyor' then null else 'liste' end;
  if md is null then return jsonb_build_object('engel', 'Ön seçim oylaması sürüyor; ön seçim sonuçlanınca tekrar dene.'); end if;
  if jsonb_typeof(p->'kullanicilar') = 'array' then
    secili := array(select jsonb_array_elements_text(p->'kullanicilar')::uuid);
  end if;

  for pr in
    select x.* from oyun.profiller x left join oyun.iller i on i.id = x.il_id left join oyun.partiler pa on pa.id = x.parti_id
    where (secili is null or x.id = any(secili))
      and (nullif(p->>'il_id', '') is null or x.il_id = (p->>'il_id')::integer)
      and (nullif(p->>'parti_id', '') is null or x.parti_id = (p->>'parti_id')::bigint)
    order by i.ad nulls last, pa.kisa nulls last, x.kad
  loop
    if exists (select 1 from oyun.adaylar a where a.user_id = pr.id and a.secim_id in (so.id, sm.id)) then
      zaten := zaten + 1; continue; end if;
    neden := null;
    if cb_haric and oyun.yp_cb_adayi(pr.id, sm.donem) then cb := cb + 1; neden := 'Cumhurbaşkanı adayı';
    elsif pr.yonetici and secili is null and yon_haric then neden := 'Yönetici hesabı (toplu işleme katılmaz)';
    elsif pr.parti_id is null and not bagimsiz then neden := 'Bağımsız (seçenek kapalı)';
    else neden := oyun.yp_mv_uygunluk(pr, sm, t); end if;
    if neden is not null then
      haric := haric || jsonb_build_array(jsonb_build_object('user_id', pr.id, 'kad', pr.kad,
        'il', (select ad from oyun.iller where id = pr.il_id), 'parti', (select kisa from oyun.partiler where id = pr.parti_id), 'neden', neden));
      continue;
    end if;
    ekle := ekle || jsonb_build_array(jsonb_build_object('user_id', pr.id, 'kad', pr.kad, 'il_id', pr.il_id,
      'il', (select ad from oyun.iller where id = pr.il_id), 'parti_id', pr.parti_id,
      'parti', (select kisa from oyun.partiler where id = pr.parti_id),
      'tur', case when pr.parti_id is null then 'bagimsiz' else 'parti' end,
      'sira', case when md = 'liste' and pr.parti_id is not null then
        (select coalesce(max(a.sira), 0) + 1 from oyun.adaylar a where a.secim_id = so.id and a.il_id = pr.il_id and a.parti_id = pr.parti_id) end));
    ids := ids || pr.id::text;
  end loop;

  select coalesce(sum(b.secmen), 0) into bos_once from oyun.yp_bos_pusula(sm.id) b;
  select coalesce(sum(b.secmen), 0) into bos_sonra from oyun.yp_bos_pusula(sm.id) b
  where b.il_id not in (select (e->>'il_id')::smallint from jsonb_array_elements(ekle) e);

  if md = 'liste' then uyari := uyari || to_jsonb('Ön seçim bitti: eklenenler partilerinin il listesinin sonuna yazılır.'::text);
  else uyari := uyari || to_jsonb(format('Ön seçime (%s) aday adayı olarak eklenirler; liste sırasını ön seçim belirler.', oyun.tr_tarih_saat(so.oy_bas))); end if;
  if exists (select 1 from oyun.mv_secim_modu where id = 1 and her_aday_vekil) then
    uyari := uyari || to_jsonb('MV test modu açık: listedeki her aday milletvekili seçilir.'::text); end if;
  uyari := uyari || to_jsonb('Başvuru harcı alınmaz. Her oyuncuya bildirim gider; istemeyen Adaylıklarım ekranından çekilebilir.'::text);

  return jsonb_build_object(
    'ozet', format('%s oyuncu milletvekili adayı yapılacak%s.', jsonb_array_length(ekle),
      case when cb > 0 then format(' (%s CB adayı hariç)', cb) else '' end),
    'secim', oyun.yp_secim_json(sm, t), 'mod', md, 'sayi', jsonb_array_length(ekle),
    'etkilenen', ekle, 'haric', haric, 'zaten', zaten, 'cb_haric_sayi', cb,
    'bos_pusula_once', bos_once, 'bos_pusula_sonra', bos_sonra, 'uyarilar', uyari,
    'engel', case when jsonb_array_length(ekle) = 0 then 'Eklenecek uygun oyuncu yok.' end,
    'parmak', md5(md || ':' || array_to_string(array(select unnest(ids) order by 1), ',')));
end $$;

create or replace function oyun.yp_uy_mv_toplu_adaylik(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare
  t timestamptz := oyun.simdi(); o jsonb; e jsonb; sm oyun.secimler; so oyun.secimler; yeni bigint; sira integer;
  eklenen jsonb := '[]'::jsonb; eklenemeyen jsonb := '[]'::jsonb; ids bigint[] := '{}'; h text; bos integer;
begin
  select * into sm from oyun.secimler where id = (p->>'secim_id')::bigint for update;
  select * into so from oyun.secimler where tur = 'mv_on' and donem = sm.donem for update;
  o := oyun.yp_on_mv_toplu_adaylik(p);
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  for e in select * from jsonb_array_elements(o->'etkilenen') loop
    begin
      yeni := null;
      if e->>'tur' = 'parti' then
        sira := case when o->>'mod' = 'liste' then
          (select coalesce(max(a.sira), 0) + 1 from oyun.adaylar a where a.secim_id = so.id
           and a.il_id = (e->>'il_id')::smallint and a.parti_id = (e->>'parti_id')::bigint) end;
        insert into oyun.adaylar (secim_id, user_id, parti_id, il_id, basvuru_at, sira)
        values (so.id, (e->>'user_id')::uuid, (e->>'parti_id')::bigint, (e->>'il_id')::smallint, t, sira)
        on conflict (secim_id, user_id) do nothing returning id into yeni;
      else
        insert into oyun.adaylar (secim_id, user_id, parti_id, il_id, basvuru_at)
        values (sm.id, (e->>'user_id')::uuid, null, (e->>'il_id')::smallint, t)
        on conflict (secim_id, user_id) do nothing returning id into yeni;
      end if;
      if yeni is null then
        eklenemeyen := eklenemeyen || jsonb_build_array(jsonb_build_object('kad', e->>'kad', 'hata', 'Zaten aday.'));
      else
        ids := ids || yeni;
        eklenen := eklenen || jsonb_build_array(e || jsonb_build_object('aday_id', yeni, 'sira', sira));
        perform oyun.bildir((e->>'user_id')::uuid, case when e->>'tur' = 'parti' then
          format('Oyun yönetimi seni %s ilinden %s milletvekili %s ekledi. İstemiyorsan Adaylıklarım ekranından çekilebilirsin.',
            e->>'il', e->>'parti', case when sira is null then 'aday adaylarına' else 'aday listesine (' || sira || '. sıra)' end)
          else format('Oyun yönetimi seni %s ilinden bağımsız milletvekili adayı yaptı. İstemiyorsan Adaylıklarım ekranından çekilebilirsin.', e->>'il') end, t);
      end if;
    exception when others then
      get stacked diagnostics h = message_text;
      eklenemeyen := eklenemeyen || jsonb_build_array(jsonb_build_object('kad', e->>'kad', 'hata', h));
    end;
  end loop;
  if cardinality(ids) > 0 then
    perform oyun.olay('secim', format('Oyun yönetimi %s oyuncuyu milletvekili adayı yaptı.', cardinality(ids)), null, null, t);
  end if;
  select coalesce(sum(b.secmen), 0) into bos from oyun.yp_bos_pusula(sm.id) b;
  return jsonb_build_object(
    'ozet', format('%s adaylık eklendi, %s kayıt eklenemedi.', jsonb_array_length(eklenen), jsonb_array_length(eklenemeyen)),
    'hedef', 'MV ' || sm.donem, 'eklenen', eklenen, 'eklenemeyen', eklenemeyen,
    'once', jsonb_build_object('bos_pusula', (o->>'bos_pusula_once')::integer),
    'sonra', jsonb_build_object('aday_ids', to_jsonb(ids), 'secim_mv', sm.id, 'secim_on', so.id, 'mod', o->>'mod'),
    'dogrulama', jsonb_build_object(
      'kayit', (select count(*) from oyun.adaylar where id = any(ids)), 'beklenen', cardinality(ids),
      'bos_pusula_secmen', bos,
      'tutarli', (select count(*) from oyun.adaylar where id = any(ids)) = cardinality(ids)));
end $$;

create or replace function oyun.yp_gr_mv_toplu_adaylik(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare
  t timestamptz := oyun.simdi(); ids bigint[] := array(select jsonb_array_elements_text(r.sonra->'aday_ids')::bigint);
  sm oyun.secimler; so oyun.secimler; e text; n integer; a oyun.adaylar;
begin
  select * into sm from oyun.secimler where id = (r.sonra->>'secim_mv')::bigint;
  select * into so from oyun.secimler where id = (r.sonra->>'secim_on')::bigint;
  select count(*) into n from oyun.adaylar where id = any(ids);
  if sm.durum <> 'bekliyor' or t >= sm.oy_bas then e := 'Genel seçim oylaması başladı; adaylıklar geri alınamaz.';
  elsif so.durum = 'bekliyor' and t >= so.oy_bas then e := 'Ön seçim oylaması sürüyor; geri alınamaz.';
  elsif n = 0 then e := 'Bu adaylıkların hepsi zaten kaldırılmış.'; end if;
  if not p_uygula or e is not null then
    return jsonb_build_object('ozet', format('%s adaylık kaldırılacak.', n), 'sayi', n, 'engel', e);
  end if;
  for a in delete from oyun.adaylar where id = any(ids) returning * loop
    perform oyun.bildir(a.user_id, 'Oyun yönetimi seni eklediği milletvekili adaylığından çıkardı.', t);
  end loop;
  return jsonb_build_object('ozet', format('%s adaylık kaldırıldı.', n), 'once', r.sonra, 'sonra', '{}'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 7) İşlem: adaylık iptali
-- ---------------------------------------------------------------------
create or replace function oyun.yp_aday_hedef_secim(a oyun.adaylar)
returns oyun.secimler language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare s oyun.secimler; h oyun.secimler;
begin
  select * into s from oyun.secimler where id = a.secim_id;
  -- Bitmiş MV ön seçiminin listesi asıl seçim pusulasıdır: asıl seçimin durumuna bakılır.
  if s.tur = 'mv_on' and s.durum <> 'bekliyor' then
    select * into h from oyun.secimler where tur = 'mv' and donem = s.donem;
    if h.id is not null then return h; end if;
  end if;
  return s;
end $$;

create or replace function oyun.yp_on_adaylik_iptal(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); a oyun.adaylar; s oyun.secimler; h oyun.secimler; e text; uyari jsonb := '[]'::jsonb;
begin
  select * into a from oyun.adaylar where id = (p->>'aday_id')::bigint;
  if a.id is null then return jsonb_build_object('engel', 'Adaylık bulunamadı.'); end if;
  select * into s from oyun.secimler where id = a.secim_id;
  h := oyun.yp_aday_hedef_secim(a);
  if h.durum <> 'bekliyor' or coalesce(h.sonuc ? 'iptal', false) then e := 'Seçim sonuçlanmış; adaylık iptal edilemez.';
  elsif t >= h.oy_bas then e := 'Oylama başladı; sandık açıkken adaylık iptal edilemez.'; end if;
  if s.tur in ('cb', 'cb2') then uyari := uyari || to_jsonb('Partinin Cumhurbaşkanı adayı kararı değişmez; genel başkan yeni karar verebilir.'::text); end if;
  if s.tur = 'mv_on' and a.sira is not null then uyari := uyari || to_jsonb('Liste sıraları kaymaz; boş sıra kalır.'::text); end if;
  return jsonb_build_object('ozet', format('%s adlı oyuncunun %s adaylığı iptal edilecek.',
      (select kad from oyun.profiller where id = a.user_id), oyun.yp_tur_ad(s.tur)),
    'etkilenen', jsonb_build_array(jsonb_build_object('aday_id', a.id, 'kad', (select kad from oyun.profiller where id = a.user_id),
      'secim', oyun.yp_tur_ad(s.tur), 'il', (select ad from oyun.iller where id = a.il_id),
      'parti', (select kisa from oyun.partiler where id = a.parti_id), 'sira', a.sira)),
    'sayi', 1, 'uyarilar', uyari, 'engel', e,
    'parmak', md5(a.id::text || ':' || a.secim_id || ':' || a.user_id || ':' || coalesce(a.sira, -1) || ':' || coalesce(a.il_id, -1)));
end $$;

create or replace function oyun.yp_uy_adaylik_iptal(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); a oyun.adaylar; o jsonb;
begin
  select * into a from oyun.adaylar where id = (p->>'aday_id')::bigint for update;
  o := oyun.yp_on_adaylik_iptal(p);
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  delete from oyun.adaylar where id = a.id;
  perform oyun.bildir(a.user_id, format('Oyun yönetimi %s adaylığını iptal etti.', oyun.yp_tur_ad((select tur from oyun.secimler where id = a.secim_id))), t);
  return jsonb_build_object('ozet', 'Adaylık iptal edildi.', 'hedef', (select kad from oyun.profiller where id = a.user_id),
    'once', jsonb_build_object('adaylar', jsonb_build_array(to_jsonb(a))), 'sonra', '{}'::jsonb,
    'dogrulama', jsonb_build_object('tutarli', not exists (select 1 from oyun.adaylar where id = a.id)));
end $$;

-- Silinen adaylık satırlarını geri yazar (adaylik_iptal ve cb_adaylari_mv_den_cikar için ortak).
create or replace function oyun.yp_aday_geri_yaz(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); x jsonb; a oyun.adaylar; h oyun.secimler; e text; n integer := 0;
begin
  for x in select * from jsonb_array_elements(coalesce(r.once->'adaylar', '[]'::jsonb)) loop
    a := jsonb_populate_record(null::oyun.adaylar, x);
    h := oyun.yp_aday_hedef_secim(a);
    if h.id is null or h.durum <> 'bekliyor' or t >= h.oy_bas then e := 'Seçim oylaması başladı veya sonuçlandı; geri alınamaz.';
    elsif exists (select 1 from oyun.adaylar where secim_id = a.secim_id and user_id = a.user_id) then e := 'Oyuncu bu seçimde yeniden aday olmuş.'; end if;
    exit when e is not null;
    n := n + 1;
  end loop;
  if not p_uygula or e is not null then
    return jsonb_build_object('ozet', format('%s adaylık yeniden etkinleşecek.', n), 'sayi', n, 'engel', e);
  end if;
  for x in select * from jsonb_array_elements(r.once->'adaylar') loop
    a := jsonb_populate_record(null::oyun.adaylar, x);
    insert into oyun.adaylar select a.*;
    perform oyun.bildir(a.user_id, 'Oyun yönetimi adaylığını yeniden etkinleştirdi.', t);
  end loop;
  return jsonb_build_object('ozet', format('%s adaylık yeniden etkinleştirildi.', n), 'once', '{}'::jsonb, 'sonra', r.once);
end $$;
create or replace function oyun.yp_gr_adaylik_iptal(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$ select oyun.yp_aday_geri_yaz(r, p_uygula) $$;

-- ---------------------------------------------------------------------
-- 8) İşlem: CB adaylarını MV adaylığından çıkar
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_cb_adaylari_mv_den_cikar(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); sm oyun.secimler; liste jsonb;
begin
  select * into sm from oyun.secimler where id = (p->>'secim_id')::bigint;
  if sm.id is null or sm.tur <> 'mv' then return jsonb_build_object('engel', 'Bir milletvekili genel seçimi seçmelisin.'); end if;
  if sm.durum <> 'bekliyor' or t >= sm.oy_bas then return jsonb_build_object('engel', 'Oylama başladı veya seçim sonuçlandı.'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('aday_id', a.id, 'kad', pr.kad, 'secim', oyun.yp_tur_ad(s.tur),
      'il', i.ad, 'parti', pa.kisa, 'sira', a.sira) order by pr.kad), '[]'::jsonb)
  into liste
  from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id join oyun.profiller pr on pr.id = a.user_id
  left join oyun.iller i on i.id = a.il_id left join oyun.partiler pa on pa.id = a.parti_id
  where s.donem = sm.donem and s.tur in ('mv_on', 'mv') and oyun.yp_cb_adayi(a.user_id, sm.donem)
    and (s.tur = 'mv' or s.durum <> 'bekliyor' or t < s.oy_bas);
  return jsonb_build_object('ozet', format('%s CB adayının milletvekili adaylığı kaldırılacak.', jsonb_array_length(liste)),
    'etkilenen', liste, 'sayi', jsonb_array_length(liste),
    'uyarilar', jsonb_build_array('Cumhurbaşkanı adaylıkları ve seçmenlik hakları değişmez; yalnız MV adaylığı kalkar.'),
    'engel', case when jsonb_array_length(liste) = 0 then 'MV adaylığı olan CB adayı yok.' end,
    'parmak', md5(liste::text));
end $$;

create or replace function oyun.yp_uy_cb_adaylari_mv_den_cikar(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_cb_adaylari_mv_den_cikar(p); ids bigint[]; silinen jsonb := '[]'::jsonb; a oyun.adaylar;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  ids := array(select (x->>'aday_id')::bigint from jsonb_array_elements(o->'etkilenen') x);
  for a in delete from oyun.adaylar where id = any(ids) returning * loop
    silinen := silinen || jsonb_build_array(to_jsonb(a));
    perform oyun.bildir(a.user_id, 'Cumhurbaşkanı adayı olduğun için oyun yönetimi milletvekili adaylığını kaldırdı. Cumhurbaşkanlığı adaylığın ve oy hakkın aynen duruyor.', t);
  end loop;
  return jsonb_build_object('ozet', format('%s MV adaylığı kaldırıldı.', jsonb_array_length(silinen)),
    'hedef', 'MV #' || (p->>'secim_id'), 'once', jsonb_build_object('adaylar', silinen), 'sonra', '{}'::jsonb,
    'dogrulama', jsonb_build_object('tutarli', not exists (select 1 from oyun.adaylar where id = any(ids))));
end $$;
create or replace function oyun.yp_gr_cb_adaylari_mv_den_cikar(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$ select oyun.yp_aday_geri_yaz(r, p_uygula) $$;

-- ---------------------------------------------------------------------
-- 9) İşlem: geri al
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_geri_al(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare r oyun.yp_islem; k oyun.yp_katalog; o jsonb;
begin
  select * into r from oyun.yp_islem where id = (p->>'islem_id')::bigint;
  if r.id is null then return jsonb_build_object('engel', 'İşlem bulunamadı.'); end if;
  select * into k from oyun.yp_katalog where islem = r.islem;
  if not coalesce(k.geri_alinabilir, false) then return jsonb_build_object('engel', 'Bu işlem geri alınamaz.'); end if;
  if r.durum <> 'uygulandi' or r.geri_alan is not null then return jsonb_build_object('engel', 'Bu işlem uygulanmamış ya da zaten geri alınmış.'); end if;
  execute format('select oyun.%I($1, false)', 'yp_gr_' || r.islem) into o using r;
  return o || jsonb_build_object('ozet', 'Geri al · ' || k.baslik || ': ' || coalesce(o->>'ozet', ''),
    'hedef_islem', jsonb_build_object('id', r.id, 'baslik', k.baslik, 'zaman', r.uygulama, 'kad', r.kad),
    'parmak', md5(r.id::text || r.durum || coalesce(o->>'sayi', '')));
end $$;

create or replace function oyun.yp_uy_geri_al(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare r oyun.yp_islem; o jsonb; s jsonb;
begin
  select * into r from oyun.yp_islem where id = (p->>'islem_id')::bigint for update;
  o := oyun.yp_on_geri_al(p);
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  execute format('select oyun.%I($1, true)', 'yp_gr_' || r.islem) into s using r;
  if s->>'engel' is not null then raise exception '%', s->>'engel'; end if;
  update oyun.yp_islem set durum = 'geri_alindi', geri_alan = nullif(current_setting('yp.islem_id', true), '')::bigint where id = r.id;
  return s || jsonb_build_object('hedef', '#' || r.id, 'geri_alinan', r.id);
end $$;

-- ---------------------------------------------------------------------
-- 10) Ön izle / uygula / geri al (portalın çağırdığı tek kapı)
-- ---------------------------------------------------------------------
create or replace function public.yp_onizle(p_islem text, p_param jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); k oyun.yp_katalog; o jsonb; r oyun.yp_islem;
begin
  select * into k from oyun.yp_katalog where islem = p_islem;
  if k.islem is null then raise exception 'Tanımsız işlem: %', p_islem; end if;
  execute format('select oyun.%I($1)', 'yp_on_' || k.islem) into o using coalesce(p_param, '{}'::jsonb);
  insert into oyun.yp_islem (islem, parametre, user_id, kad, gecerlilik, onizleme, parmak)
  values (k.islem, coalesce(p_param, '{}'::jsonb), p.id, p.kad, now() + interval '15 minutes', o, coalesce(o->>'parmak', md5(o::text)))
  returning * into r;
  return o || jsonb_build_object('anahtar', r.anahtar, 'islem_id', r.id, 'gecerlilik', r.gecerlilik,
    'baslik', k.baslik, 'kritik', k.kritik, 'onay_metni', k.onay_metni, 'geri_alinabilir', k.geri_alinabilir);
end $$;

create or replace function public.yp_uygula(p_anahtar uuid, p_onay text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); r oyun.yp_islem; k oyun.yp_katalog; o jsonb; s jsonb; h text;
begin
  select * into r from oyun.yp_islem where anahtar = p_anahtar for update;
  if r.id is null then raise exception 'İşlem bulunamadı.'; end if;
  if r.durum = 'uygulandi' then
    return coalesce(r.sonuc, '{}'::jsonb) || jsonb_build_object('basarili', true, 'tekrar', true, 'islem_id', r.id,
      'mesaj', 'Bu işlem daha önce uygulandı; ikinci kez çalıştırılmadı.');
  end if;
  if r.durum <> 'onizleme' then
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', 'Bu ön izleme artık kullanılamaz. Yeniden ön izleme yap.');
  end if;
  if r.gecerlilik < now() then
    update oyun.yp_islem set durum = 'iptal', hata = 'Ön izlemenin süresi doldu.' where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', 'Ön izlemenin süresi doldu (15 dakika). Yeniden ön izleme yap.');
  end if;
  select * into k from oyun.yp_katalog where islem = r.islem;
  if k.kritik then
    perform oyun.yp_sahip(10);
    if upper(btrim(coalesce(p_onay, ''))) <> upper(k.onay_metni) then
      raise exception 'YP_ONAY: Onaylamak için % yazmalısın.', k.onay_metni;
    end if;
  end if;

  execute format('select oyun.%I($1)', 'yp_on_' || r.islem) into o using r.parametre;
  if o->>'engel' is not null then
    update oyun.yp_islem set durum = 'basarisiz', hata = o->>'engel', uygulama = now() where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', o->>'engel');
  end if;
  if coalesce(o->>'parmak', md5(o::text)) <> r.parmak then
    update oyun.yp_islem set durum = 'iptal', hata = 'Veriler ön izlemeden sonra değişti.' where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'degisti', true,
      'hata', 'Ön izlemeden sonra veriler değişti; hiçbir şey uygulanmadı. Yeniden ön izleme yap.');
  end if;

  perform set_config('yp.islem_id', r.id::text, true);
  begin
    execute format('select oyun.%I($1)', 'yp_uy_' || r.islem) into s using r.parametre;
  exception when others then
    get stacked diagnostics h = message_text;
    update oyun.yp_islem set durum = 'basarisiz', hata = h, uygulama = now() where id = r.id;
    return jsonb_build_object('basarili', false, 'islem_id', r.id, 'hata', h);
  end;

  update oyun.yp_islem set durum = 'uygulandi', uygulama = now(), sonuc = s, once = s->'once', sonra = s->'sonra',
    geri_alinan = case when r.islem = 'geri_al' then (r.parametre->>'islem_id')::bigint end
  where id = r.id;
  perform oyun.mod_log(p, 'yp_' || r.islem, coalesce(s->>'hedef', ''), coalesce(s->>'ozet', k.baslik));
  perform oyun.uzaktan_sinyal_yay('yonetici');
  return s || jsonb_build_object('basarili', true, 'islem_id', r.id);
end $$;

-- ---------------------------------------------------------------------
-- 11) Okuma işlemleri
-- ---------------------------------------------------------------------
create or replace function public.yp_ben()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); p oyun.profiller; j jsonb := coalesce(auth.jwt(), '{}'::jsonb);
begin
  if u is null then return jsonb_build_object('giris', false); end if;
  select * into p from oyun.profiller where id = u;
  return jsonb_build_object('giris', true, 'kad', p.kad, 'yonetici', coalesce(p.yonetici, false), 'aal', j->>'aal',
    'mfa_hazir', exists (select 1 from auth.mfa_factors f where f.user_id = u and f.status = 'verified'));
end $$;

create or replace function public.yp_pano()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); sonraki_mv oyun.secimler;
begin
  select * into sonraki_mv from oyun.secimler s where s.tur = 'mv' and s.durum = 'bekliyor'
    and not coalesce(s.sonuc ? 'iptal', false) and s.oy_bas > t order by s.oy_bas limit 1;
  return jsonb_build_object(
    'zaman', t,
    'oyuncu', jsonb_build_object(
      'toplam', (select count(*) from oyun.profiller),
      'cevrimici', (select count(*) from oyun.profiller where son_gorulme > t - interval '15 minutes'),
      'gunluk', (select count(*) from oyun.profiller where son_gorulme > t - interval '1 day'),
      'haftalik', (select count(*) from oyun.profiller where son_gorulme > t - interval '7 days'),
      'engelli', (select count(*) from oyun.profiller where yasakli),
      'yeni_7g', (select count(*) from oyun.profiller where olusturma > t - interval '7 days')),
    'siyaset', jsonb_build_object(
      'parti', (select count(*) from oyun.partiler where not coalesce(kapali, false)),
      'cb', (select pr.kad from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id where m.tur = 'cb' and m.bit is null order by m.bas desc limit 1),
      'tbmm', (select pr.kad from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id where m.tur = 'tbmm' and m.bit is null order by m.bas desc limit 1),
      'mv', (select count(*) from oyun.makamlar where tur = 'mv' and bit is null),
      'bel', (select count(*) from oyun.makamlar where tur = 'bel' and bit is null),
      'mv_test_modu', exists (select 1 from oyun.mv_secim_modu where id = 1 and her_aday_vekil)),
    'secim', jsonb_build_object(
      'suren', coalesce((select jsonb_agg(oyun.yp_secim_json(s, t) order by s.oy_bit) from oyun.secimler s
        where s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.oy_bas <= t and s.sonuc_at > t), '[]'::jsonb),
      'yaklasan', coalesce((select jsonb_agg(x.j order by x.o) from (select oyun.yp_secim_json(s, t) j, s.oy_bas o from oyun.secimler s
        where s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.oy_bas > t order by s.oy_bas limit 8) x), '[]'::jsonb),
      'son', coalesce((select jsonb_agg(x.j order by x.o desc) from (select oyun.yp_secim_json(s, t) j, s.sonuc_at o from oyun.secimler s
        where s.durum <> 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.sonuc_at <= t and (select count(*) from oyun.oylar o where o.secim_id = s.id) > 0
        order by s.sonuc_at desc limit 5) x), '[]'::jsonb),
      'bos_pusula', case when sonraki_mv.id is null then null else jsonb_build_object(
        'secim', oyun.yp_secim_json(sonraki_mv, t),
        'iller', coalesce((select jsonb_agg(jsonb_build_object('il_id', b.il_id, 'il', b.il, 'secmen', b.secmen)) from oyun.yp_bos_pusula(sonraki_mv.id) b), '[]'::jsonb)) end),
    'ekonomi', jsonb_build_object(
      'para_arzi', (select coalesce(sum(para), 0) from oyun.cuzdan),
      'sirket', (select count(*) from oyun.sirketler where coalesce(aktif, true) and sektor is distinct from 'banka'),
      'banka', (select count(*) from oyun.sirketler where coalesce(aktif, true) and sektor = 'banka'),
      'mulk', (select count(*) from oyun.mulkler)),
    'bekleyen', jsonb_build_object(
      'kayit', (select count(*) from oyun_yonetim.kayit_basvurulari where durum = 'beklemede'),
      'sikayet', (select count(*) from oyun.sikayetler where durum = 'yeni'),
      'masak', (select count(*) from oyun.masak where durum = 'yeni')),
    'sistem', jsonb_build_object(
      'db_mb', round(pg_database_size(current_database()) / 1048576.0),
      'baglanti', (select numbackends from pg_stat_database where datname = current_database()),
      'zamanlayici_son', (select max(son_calisma) from oyun.zamanlayici_adim where aktif),
      'zamanlayici_hatali', (select count(*) from oyun.zamanlayici_adim where aktif and son_hata_at > t - interval '1 day'),
      'tick_hata_24s', (select count(*) from oyun.tick_hata where son > t - interval '1 day'),
      'son_hatalar', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.son, 'adim', h.adim, 'hata', left(h.hata, 160), 'sayi', h.sayi) order by h.son desc)
        from (select * from oyun.tick_hata order by son desc limit 5) h), '[]'::jsonb),
      'test_saati', (select test_simdi from oyun.ayarlar where id = 1)),
    'islemler', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'islem', i.islem, 'baslik', k.baslik, 'durum', i.durum,
        'zaman', coalesce(i.uygulama, i.olusturma), 'ozet', coalesce(i.sonuc->>'ozet', i.onizleme->>'ozet', i.hata)) order by i.id desc)
      from (select * from oyun.yp_islem where durum <> 'onizleme' order by id desc limit 6) i left join oyun.yp_katalog k on k.islem = i.islem), '[]'::jsonb));
end $$;

create or replace function public.yp_sozluk()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return jsonb_build_object(
    'iller', (select jsonb_agg(jsonb_build_object('id', id, 'ad', ad, 'mv', coalesce(mv_secim, mv)) order by ad) from oyun.iller),
    'partiler', (select jsonb_agg(jsonb_build_object('id', id, 'kisa', kisa, 'ad', ad, 'renk', renk) order by kisa)
                 from oyun.partiler where not coalesce(kapali, false)),
    'katalog', (select jsonb_agg(to_jsonb(k) order by k.grup, k.islem) from oyun.yp_katalog k));
end $$;

create or replace function public.yp_secimler(p_tumu boolean default false)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(oyun.yp_secim_json(s, t) order by s.oy_bas desc nulls last, s.id desc)
    from oyun.secimler s
    where p_tumu or s.durum = 'bekliyor' or coalesce(s.goreve_bas, s.sonuc_at) > t - interval '14 days'), '[]'::jsonb);
end $$;

create or replace function public.yp_secim(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); s oyun.secimler; sonuclu boolean;
begin
  select * into s from oyun.secimler where id = p_id;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  sonuclu := s.durum <> 'bekliyor';
  return oyun.yp_secim_json(s, t) || jsonb_build_object(
    'iliskili', coalesce((select jsonb_agg(oyun.yp_secim_json(x, t) order by x.oy_bas) from oyun.secimler x where x.donem = s.donem and x.id <> s.id), '[]'::jsonb),
    'takvim_tutarli', oyun.yp_takvim_engel(s) is null, 'takvim_sorun', oyun.yp_takvim_engel(s),
    'adaylar', coalesce((select jsonb_agg(jsonb_build_object('aday_id', a.id, 'user_id', a.user_id, 'kad', pr.kad,
        'parti', pa.kisa, 'parti_id', a.parti_id, 'renk', pa.renk, 'il', i.ad, 'il_id', a.il_id, 'sira', a.sira,
        'oy', case when sonuclu then a.oy end, 'basvuru_at', a.basvuru_at,
        'cb_adayi', s.tur in ('mv_on', 'mv') and oyun.yp_cb_adayi(a.user_id, s.donem))
        order by i.ad nulls first, pa.kisa nulls last, a.sira nulls last, pr.kad)
      from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
      left join oyun.partiler pa on pa.id = a.parti_id left join oyun.iller i on i.id = a.il_id
      where a.secim_id = s.id), '[]'::jsonb),
    'il_katilim', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'il_id', i.id, 'oy', coalesce(o.n, 0), 'secmen', v.n) order by coalesce(o.n, 0) desc, i.ad)
      from (select il_id, count(*) n from oyun.profiller where not yasakli group by il_id) v
      join oyun.iller i on i.id = v.il_id
      left join (select il_id, count(*) n from oyun.oylar where secim_id = s.id group by il_id) o on o.il_id = v.il_id), '[]'::jsonb),
    'secmen', (select count(*) from oyun.profiller where not yasakli),
    'bos_pusula', case when s.tur = 'mv' then coalesce((select jsonb_agg(jsonb_build_object('il_id', b.il_id, 'il', b.il, 'secmen', b.secmen))
      from oyun.yp_bos_pusula(s.id) b), '[]'::jsonb) end,
    'sonuc', case when sonuclu then s.sonuc end);
end $$;

-- Oy kullanamayan oyuncu teşhisi. Kimin kime oy verdiğini asla döndürmez; yalnız oy kullanıp kullanmadığını.
create or replace function public.yp_oy_teshis(p_secim bigint, p_kad text default null, p_il integer default null, p_sadece_sorunlu boolean default true)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); s oyun.secimler; liste jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  with x as (
    select pr.id, pr.kad, pr.il_id, pr.parti_id, pr.yasakli,
      case when pr.yasakli then coalesce(pr.engel_neden, 'Hesap engelli.') else oyun.oy_engeli(pr, s) end engel,
      exists (select 1 from oyun.oylar o where o.secim_id = s.id and o.secmen = pr.id) oy_verdi,
      case
        when s.tur = 'mv' then pr.il_id in (select b.il_id from oyun.yp_bos_pusula(s.id) b)
        when s.tur = 'bel' then not exists (select 1 from oyun.adaylar a where a.secim_id = s.id and a.il_id = pr.il_id)
        when s.tur in ('cb', 'cb2') then not exists (select 1 from oyun.adaylar a where a.secim_id = s.id)
        when s.tur in ('mv_on', 'bel_on') then not exists (select 1 from oyun.adaylar a where a.secim_id = s.id and a.il_id = pr.il_id and a.parti_id = pr.parti_id)
        when s.tur = 'kurultay' then not exists (select 1 from oyun.adaylar a where a.secim_id = s.id and a.parti_id = pr.parti_id)
        else false end pusula_bos,
      s.tur in ('mv_on', 'mv') and oyun.yp_cb_adayi(pr.id, s.donem) cb_adayi,
      exists (select 1 from oyun.adaylar a join oyun.secimler z on z.id = a.secim_id where a.user_id = pr.id and z.donem = s.donem and z.tur in ('mv_on', 'mv')) mv_adayi
    from oyun.profiller pr
    where (p_kad is null or pr.kad ilike '%' || btrim(p_kad) || '%') and (p_il is null or pr.il_id = p_il)
  ), y as (
    select x.*, case when x.oy_verdi then 'oy_kullandi' when x.engel is not null then 'engelli'
                     when x.pusula_bos then 'bos_pusula' else 'kullanabilir' end durum from x
  )
  select coalesce(jsonb_agg(jsonb_build_object('user_id', y.id, 'kad', y.kad, 'il', i.ad, 'il_id', y.il_id, 'parti', pa.kisa,
      'durum', y.durum, 'engel', y.engel, 'pusula_bos', y.pusula_bos, 'cb_adayi', y.cb_adayi, 'mv_adayi', y.mv_adayi,
      'oneri', case
        when y.durum = 'oy_kullandi' then null
        when y.yasakli then 'Hesap engelli: engel kaldırılırsa oy kullanabilir.'
        when y.engel like 'Bu cihazda daha önce%' then 'Çoklu hesap incelemesi: oyun içi Kontrol Merkezi › Şüpheli hesaplar ekranından onaylanabilir.'
        when y.engel like 'Cihaz doğrulaması%' then 'Oyuncu uygulamayı güncelleyip yeniden açmalı; sunucudan düzeltilemez.'
        when y.engel like 'Seçmen kütüğü%' then 'İl değişikliği yakın tarihli; kural gereği bu seçimde oy kullanamaz.'
        when y.engel like 'En az % kıdem%' then 'Kıdem puanı yetersiz.'
        when y.engel like 'E-posta%' then 'Oyuncu e-posta adresini doğrulamalı.'
        when y.engel like 'Hesabın en az%' then 'Hesap çok yeni; kural gereği bekler.'
        when y.engel is not null then 'Kural gereği oy kullanamıyor.'
        when y.pusula_bos and s.tur = 'mv' and t < s.oy_bas then 'İlinde aday yok: Seçim › Adaylık › Toplu MV adaylığı ile bu ile aday eklenebilir.'
        when y.pusula_bos then 'İlinde aday yok; oylama başladığı için bu seçimde düzeltilemez.'
        when oyun.yp_asama(s, t) in ('basvuru', 'bekliyor') then 'Sandık açılınca oy kullanabilir.'
        else 'Oy kullanabilir; henüz kullanmadı.' end)
    order by case y.durum when 'bos_pusula' then 0 when 'engelli' then 1 when 'kullanabilir' then 2 else 3 end, i.ad, y.kad), '[]'::jsonb)
  into liste
  from y left join oyun.iller i on i.id = y.il_id left join oyun.partiler pa on pa.id = y.parti_id
  where not p_sadece_sorunlu or y.durum in ('engelli', 'bos_pusula') or p_kad is not null;

  return jsonb_build_object('secim', oyun.yp_secim_json(s, t), 'oyuncular', liste,
    'ozet', (select jsonb_object_agg(d, n) from (select e->>'durum' d, count(*) n from jsonb_array_elements(liste) e group by 1) z),
    'kontrol_zamani', now());
end $$;

create or replace function public.yp_oyuncu_ara(p_ara text default null, p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', pr.id, 'kad', pr.kad, 'il', i.ad, 'il_id', pr.il_id,
      'parti', pa.kisa, 'parti_id', pr.parti_id, 'yasakli', pr.yasakli, 'son_gorulme', pr.son_gorulme) order by pr.kad)
    from (select * from oyun.profiller x where p_ara is null or x.kad ilike '%' || btrim(p_ara) || '%' order by x.kad limit least(coalesce(p_limit, 20), 200)) pr
    left join oyun.iller i on i.id = pr.il_id left join oyun.partiler pa on pa.id = pr.parti_id), '[]'::jsonb);
end $$;

create or replace function public.yp_islemler(p_limit integer default 50, p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return jsonb_build_object(
    'toplam', (select count(*) from oyun.yp_islem where durum <> 'onizleme'),
    'kayitlar', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'islem', i.islem, 'baslik', k.baslik, 'durum', i.durum,
        'kad', i.kad, 'olusturma', i.olusturma, 'uygulama', i.uygulama, 'parametre', i.parametre,
        'ozet', coalesce(i.sonuc->>'ozet', i.onizleme->>'ozet'), 'hata', i.hata, 'sonuc', i.sonuc, 'once', i.once, 'sonra', i.sonra,
        'geri_alinabilir', k.geri_alinabilir and i.durum = 'uygulandi' and i.geri_alan is null,
        'geri_alan', i.geri_alan, 'geri_alinan', i.geri_alinan) order by i.id desc)
      from (select * from oyun.yp_islem where durum <> 'onizleme' order by id desc
            limit least(coalesce(p_limit, 50), 200) offset greatest(coalesce(p_offset, 0), 0)) i
      left join oyun.yp_katalog k on k.islem = i.islem), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 12) Yetkiler: oyun.* iç işlemler istemciye kapalı, portal yalnız public.yp_* çağırır.
-- ---------------------------------------------------------------------
do $yp_yetki$
declare r record;
begin
  for r in select p.oid::regprocedure imza from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'oyun' and p.proname like 'yp\_%' loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.imza);
  end loop;
  for r in select p.oid::regprocedure imza from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'yp\_%' loop
    execute format('revoke execute on function %s from public, anon', r.imza);
    execute format('grant execute on function %s to authenticated', r.imza);
  end loop;
end
$yp_yetki$;
