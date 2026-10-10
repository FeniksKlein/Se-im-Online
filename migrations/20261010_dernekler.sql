-- 2026-10-10 · Dernekler ve sivil toplum kuruluşları. Kaynak: gelistirici/sql/55_dernekler.sql
begin;
-- =====================================================================
--  55 · DERNEKLER VE SİVİL TOPLUM KURULUŞLARI
--
--  • Kuruluş: her oyuncu bir dernek kurabilir (kuruluş harcı 5.000 ₺ × fiyat düzeyi). Kurucu başkan olur,
--    kayıtlı olduğu il merkez şube olur. Bir oyuncu aynı anda yalnız bir derneğin başkanı olabilir.
--  • Üyelik: herkes ücretsiz üye olur (en fazla 5 dernek). Başkan en fazla 4 kişilik yönetim kurulu atar,
--    başkanlığı devredebilir. Son üye ayrılırsa dernek kapanır.
--  • Kasa: herkes bağış yapabilir (en az 100 ₺). Şubeler kasadan açılır.
--  • Şube: başkan/yönetim her ilde şube açar (1.000 ₺ × il büyüklüğü × fiyat düzeyi).
--  • Eylemler (başkan/yönetim):
--      basin    → basın açıklaması
--      bildiri  → bildiri
--      destek   → bir partiye ya da oyuncuya (adaya) destek açıklaması
--      protesto → şubesi olan bir ilde 1 saatlik protesto; o ilde yaşayan herkes katılabilir
--    Konu (hedef): genel bir konu, bir kanun, bir parti, başka bir dernek ya da bir oyuncu.
--    Yazılı açıklamalar derneğe günde en fazla 3; protesto derneğe günde 1, aynı ilde 3 günde 1; seçim günlerinin oy saatlerinde protesto yok.
--    Hedefteki parti genel başkanına / oyuncuya / dernek başkanına / kanunu teklif edene bildirim gider; her eylem Gündem'e haber olur.
--  Oyuncu verisi değişmez; yalnız tablo ve fonksiyon eklenir.
-- =====================================================================

create table if not exists oyun.dernekler(
  id        bigint generated always as identity primary key,
  ad        text not null check (char_length(ad) between 4 and 50),
  alan      text not null default 'genel',
  amac      text not null default '' check (char_length(amac) <= 600),
  baskan    uuid references oyun.profiller(id) on delete set null,
  kurucu    uuid references oyun.profiller(id) on delete set null,
  merkez_il smallint references oyun.iller(id),
  kasa      numeric not null default 0 check (kasa >= 0),
  kurulus   timestamptz not null default now(),
  kapali    boolean not null default false
);
create unique index if not exists dernek_ad_tek on oyun.dernekler(lower(ad)) where not kapali;

create table if not exists oyun.dernek_uyeler(
  dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
  user_id   uuid not null references oyun.profiller(id) on delete cascade,
  rol       text not null default 'uye' check (rol in ('baskan','yonetim','uye')),
  katilim   timestamptz not null default now(),
  primary key (dernek_id, user_id)
);
create index if not exists dernek_uyeler_u on oyun.dernek_uyeler(user_id);

create table if not exists oyun.dernek_sube(
  dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
  il_id     smallint not null references oyun.iller(id),
  kurulus   timestamptz not null default now(),
  kuran     uuid,
  bedel     numeric not null default 0,
  primary key (dernek_id, il_id)
);

create table if not exists oyun.dernek_hareket(
  id        bigint generated always as identity primary key,
  dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
  zaman     timestamptz not null default now(),
  tutar     numeric not null,
  tur       text not null,
  aciklama  text not null,
  user_id   uuid
);
create index if not exists dernek_hareket_d on oyun.dernek_hareket(dernek_id, zaman desc);

create table if not exists oyun.dernek_eylem(
  id         bigint generated always as identity primary key,
  dernek_id  bigint not null references oyun.dernekler(id) on delete cascade,
  tur        text not null check (tur in ('basin','bildiri','destek','protesto')),
  baslik     text not null check (char_length(baslik) between 4 and 100),
  metin      text not null check (char_length(metin) between 10 and 2000),
  hedef_tur  text not null default 'genel' check (hedef_tur in ('genel','kanun','parti','dernek','oyuncu')),
  hedef_id   text,
  hedef_ad   text,
  il_id      smallint references oyun.iller(id),
  bas        timestamptz,
  bit        timestamptz,
  yazan      uuid,
  zaman      timestamptz not null default now(),
  duyuruldu  boolean not null default false,
  sonuc_yazildi boolean not null default false,
  silindi    boolean not null default false
);
create index if not exists dernek_eylem_d on oyun.dernek_eylem(dernek_id, zaman desc);
create index if not exists dernek_eylem_z on oyun.dernek_eylem(zaman desc);
create index if not exists dernek_eylem_p on oyun.dernek_eylem(il_id, bas) where tur = 'protesto';

create table if not exists oyun.dernek_protesto_katilim(
  eylem_id bigint not null references oyun.dernek_eylem(id) on delete cascade,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  zaman    timestamptz not null default now(),
  primary key (eylem_id, user_id)
);

do $$ declare t text; begin
  foreach t in array array['dernekler','dernek_uyeler','dernek_sube','dernek_hareket','dernek_eylem','dernek_protesto_katilim'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
    if to_regproc('oyun.bosaltma_korumasi') is not null then
      execute format('drop trigger if exists bosaltma_korumasi on oyun.%I', t);
      execute format('create trigger bosaltma_korumasi before truncate on oyun.%I for each statement execute function oyun.bosaltma_korumasi()', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------
create or replace function oyun.dernek_alan_ad(a text) returns text language sql immutable as $$
  select case a when 'genel' then 'Genel' when 'emek' then 'Emek ve Sendika' when 'cevre' then 'Çevre' when 'hak' then 'İnsan Hakları'
    when 'genclik' then 'Gençlik' when 'kadin' then 'Kadın' when 'egitim' then 'Eğitim' when 'esnaf' then 'Esnaf ve Meslek'
    when 'hayvan' then 'Hayvan Hakları' when 'kultur' then 'Kültür ve Sanat' when 'yerel' then 'Kent ve Yerel' else 'Genel' end
$$;

create or replace function oyun.dernek_json(p_id bigint) returns jsonb language sql stable set search_path = '' as $$
  select case when d.id is null then null else jsonb_build_object('id', d.id, 'ad', d.ad, 'alan', d.alan, 'alan_ad', oyun.dernek_alan_ad(d.alan)) end
  from (select 1) x left join oyun.dernekler d on d.id = p_id
$$;

create or replace function oyun.dernek_harci() returns numeric language sql stable set search_path = '' as $$
  select round(5000 * coalesce((select endeks from oyun.ulke where id = 1), 1) / 100) * 100
$$;
create or replace function oyun.dernek_sube_ucreti(p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select round(1000 * oyun.il_buyukluk(p_il) * coalesce((select endeks from oyun.ulke where id = 1), 1) / 100) * 100
$$;

-- Başkan ya da yönetim kurulu üyesi mi? Değilse hata.
create or replace function oyun.dernek_yetkili(p_dernek bigint, u uuid) returns oyun.dernekler
language plpgsql stable set search_path = '' as $$
declare d oyun.dernekler;
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali;
  if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  if not exists (select 1 from oyun.dernek_uyeler where dernek_id = d.id and user_id = u and rol in ('baskan','yonetim')) then
    raise exception 'Bu işlemi derneğin başkanı ya da yönetim kurulu yapabilir.';
  end if;
  return d;
end $$;

-- ---------------------------------------------------------------------
-- Kuruluş, üyelik, yönetim
-- ---------------------------------------------------------------------
create or replace function public.dernek_kur(p_ad text, p_alan text, p_amac text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v_ad text; harc numeric; yeni bigint; amac text;
begin
  if oyun.uyari(p, t) is not null then raise exception 'Dernek kurmak için: %', oyun.uyari(p, t); end if;
  if exists (select 1 from oyun.dernekler where baskan = p.id and not kapali) then raise exception 'Zaten bir derneğin başkanısın.'; end if;
  if (select count(*) from oyun.dernek_uyeler u join oyun.dernekler d on d.id = u.dernek_id where u.user_id = p.id and not d.kapali) >= 5 then
    raise exception 'En fazla 5 derneğe üye olabilirsin.';
  end if;
  v_ad := btrim(regexp_replace(coalesce(p_ad, ''), '\s+', ' ', 'g'));
  if char_length(v_ad) < 4 or char_length(v_ad) > 50 then raise exception 'Dernek adı 4-50 karakter olmalı.'; end if;
  if v_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ0-9'' .,&-]+$' then raise exception 'Dernek adında yalnız harf, rakam ve noktalama kullanılabilir.'; end if;
  if oyun.yasakli_ad(v_ad) then raise exception 'Gerçek kurumları çağrıştıran ya da uygunsuz adlar kullanılamaz.'; end if;
  perform oyun.metin_temizle(v_ad, 50);
  if exists (select 1 from oyun.dernekler d where not d.kapali and lower(d.ad) = lower(v_ad)) then
    raise exception 'Bu adla bir dernek zaten var.';
  end if;
  amac := case when coalesce(btrim(p_amac), '') = '' then '' else oyun.metin_temizle(p_amac, 600) end;
  harc := oyun.dernek_harci();
  perform oyun.para_islem(p.id, -harc, 'dernek', format('%s kuruluş harcı', v_ad), t);
  insert into oyun.dernekler(ad, alan, amac, baskan, kurucu, merkez_il, kurulus)
    values (v_ad, case when p_alan in ('genel','emek','cevre','hak','genclik','kadin','egitim','esnaf','hayvan','kultur','yerel') then p_alan else 'genel' end,
            amac, p.id, p.id, p.il_id, t) returning id into yeni;
  insert into oyun.dernek_uyeler(dernek_id, user_id, rol, katilim) values (yeni, p.id, 'baskan', t);
  insert into oyun.dernek_sube(dernek_id, il_id, kurulus, kuran, bedel) values (yeni, p.il_id, t, p.id, 0);
  perform oyun.olay('dernek', format('%s, %s adıyla yeni bir sivil toplum kuruluşu kurdu (%s).', p.kad, v_ad, oyun.dernek_alan_ad(p_alan)), p.il_id, null, t);
  return public.dernek_detay(yeni);
end $$;

create or replace function public.dernek_katil(p_dernek bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler;
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali;
  if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  if exists (select 1 from oyun.dernek_uyeler where dernek_id = d.id and user_id = p.id) then raise exception 'Zaten bu derneğin üyesisin.'; end if;
  if (select count(*) from oyun.dernek_uyeler u join oyun.dernekler x on x.id = u.dernek_id where u.user_id = p.id and not x.kapali) >= 5 then
    raise exception 'En fazla 5 derneğe üye olabilirsin.';
  end if;
  insert into oyun.dernek_uyeler(dernek_id, user_id, rol, katilim) values (d.id, p.id, 'uye', t);
  if d.baskan is not null then perform oyun.bildir(d.baskan, format('%s, %s derneğine üye oldu.', p.kad, d.ad), t); end if;
  return public.dernek_detay(d.id);
end $$;

create or replace function public.dernek_ayril(p_dernek bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; r text;
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali for update;
  if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  select rol into r from oyun.dernek_uyeler where dernek_id = d.id and user_id = p.id;
  if r is null then raise exception 'Bu derneğin üyesi değilsin.'; end if;
  if r = 'baskan' and exists (select 1 from oyun.dernek_uyeler where dernek_id = d.id and user_id <> p.id) then
    raise exception 'Başkan ayrılmadan önce başkanlığı bir üyeye devretmeli.';
  end if;
  delete from oyun.dernek_uyeler where dernek_id = d.id and user_id = p.id;
  if r = 'baskan' then
    update oyun.dernekler set kapali = true, baskan = null where id = d.id;
    perform oyun.olay('dernek', format('%s kapandı: son üyesi de ayrıldı.', d.ad), d.merkez_il, null, t);
  end if;
  return public.dernek_detay(d.id);
end $$;

-- Başkan bir üyeyi yönetim kuruluna alır (p_yonetim = true) ya da çıkarır
create or replace function public.dernek_yonetim_ata(p_dernek bigint, p_kad text, p_yonetim boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; h oyun.profiller;
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali for update;
  if d.id is null or d.baskan is distinct from p.id then raise exception 'Yönetim kurulunu yalnız derneğin başkanı belirler.'; end if;
  h := oyun.profil_bul(p_kad);
  if not exists (select 1 from oyun.dernek_uyeler where dernek_id = d.id and user_id = h.id and rol <> 'baskan') then
    raise exception 'Bu oyuncu derneğin üyesi değil.';
  end if;
  if p_yonetim and (select count(*) from oyun.dernek_uyeler where dernek_id = d.id and rol = 'yonetim') >= 4 then
    raise exception 'Yönetim kurulu en fazla 4 kişidir.';
  end if;
  update oyun.dernek_uyeler set rol = case when p_yonetim then 'yonetim' else 'uye' end where dernek_id = d.id and user_id = h.id;
  perform oyun.bildir(h.id, format(case when p_yonetim then '%s yönetim kuruluna alındın.' else '%s yönetim kurulundaki görevin sona erdi.' end, d.ad), t);
  return public.dernek_detay(d.id);
end $$;

create or replace function public.dernek_baskan_devret(p_dernek bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; h oyun.profiller;
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali for update;
  if d.id is null or d.baskan is distinct from p.id then raise exception 'Başkanlığı yalnız başkan devredebilir.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = p.id or not exists (select 1 from oyun.dernek_uyeler where dernek_id = d.id and user_id = h.id) then raise exception 'Başkanlık yalnız derneğin başka bir üyesine devredilebilir.'; end if;
  if exists (select 1 from oyun.dernekler where baskan = h.id and not kapali) then raise exception '% zaten başka bir derneğin başkanı.', h.kad; end if;
  update oyun.dernek_uyeler set rol = 'yonetim' where dernek_id = d.id and user_id = p.id;
  update oyun.dernek_uyeler set rol = 'baskan' where dernek_id = d.id and user_id = h.id;
  update oyun.dernekler set baskan = h.id where id = d.id;
  perform oyun.bildir(h.id, format('%s başkanlığı sana devredildi.', d.ad), t);
  perform oyun.olay('dernek', format('%s başkanlığını %s devraldı.', d.ad, h.kad), d.merkez_il, null, t);
  return public.dernek_detay(d.id);
end $$;

-- ---------------------------------------------------------------------
-- Kasa ve şubeler
-- ---------------------------------------------------------------------
create or replace function public.dernek_bagis(p_dernek bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; m numeric := round(coalesce(p_tutar, 0));
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali for update;
  if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ bağış yapabilirsin.'; end if;
  perform oyun.para_islem(p.id, -m, 'dernek', format('%s derneğine bağış', d.ad), t);
  update oyun.dernekler set kasa = kasa + m where id = d.id;
  insert into oyun.dernek_hareket(dernek_id, zaman, tutar, tur, aciklama, user_id) values (d.id, t, m, 'bagis', format('%s bağış yaptı', p.kad), p.id);
  if d.baskan is not null and d.baskan <> p.id then perform oyun.bildir(d.baskan, format('%s, %s derneğine %s ₺ bağış yaptı.', p.kad, d.ad, oyun.tl(m)), t); end if;
  return public.dernek_detay(d.id);
end $$;

create or replace function public.dernek_sube_ac(p_dernek bigint, p_il int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; u numeric; ilad text;
begin
  d := oyun.dernek_yetkili(p_dernek, p.id);
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  if exists (select 1 from oyun.dernek_sube where dernek_id = d.id and il_id = p_il) then raise exception 'Derneğin % ilinde zaten şubesi var.', ilad; end if;
  u := oyun.dernek_sube_ucreti(p_il::smallint);
  update oyun.dernekler set kasa = kasa - u where id = d.id and kasa >= u;
  if not found then raise exception '% şubesi için dernek kasasında % ₺ olmalı (kasada % ₺ var). Üyeler bağış yaparak kasayı doldurabilir.', ilad, oyun.tl(u), oyun.tl(d.kasa); end if;
  insert into oyun.dernek_hareket(dernek_id, zaman, tutar, tur, aciklama, user_id) values (d.id, t, -u, 'sube', format('%s şubesi açıldı · %s', ilad, p.kad), p.id);
  insert into oyun.dernek_sube(dernek_id, il_id, kurulus, kuran, bedel) values (d.id, p_il, t, p.id, u);
  perform oyun.olay('dernek', format('%s, %s şubesini açtı.', d.ad, ilad), p_il::smallint, null, t);
  return public.dernek_detay(d.id);
end $$;

-- ---------------------------------------------------------------------
-- Eylemler: basın açıklaması, bildiri, destek, protesto
-- ---------------------------------------------------------------------
create or replace function public.dernek_eylem(p_dernek bigint, p_tur text, p_baslik text, p_metin text,
  p_hedef_tur text default 'genel', p_hedef text default null, p_il int default null, p_bas timestamptz default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; b text; m text; hid text; had text;
        bildir_u uuid; ilad text; yasak text; eid bigint; tur_ad text; ht text := coalesce(p_hedef_tur, 'genel');
begin
  d := oyun.dernek_yetkili(p_dernek, p.id);
  if p_tur not in ('basin','bildiri','destek','protesto') then raise exception 'Geçersiz eylem türü.'; end if;
  perform oyun.yazabilir_mi(p, t);
  b := oyun.metin_temizle(p_baslik, 100);
  if char_length(b) < 4 then raise exception 'Başlık en az 4 karakter olmalı.'; end if;
  m := oyun.metin_temizle(p_metin, 2000);
  if char_length(m) < 10 then raise exception 'Metin en az 10 karakter olmalı.'; end if;

  -- Konu / hedef
  if ht = 'genel' then
    hid := null; had := case when coalesce(btrim(p_hedef), '') = '' then null else oyun.metin_temizle(p_hedef, 80) end;
  elsif ht = 'kanun' then
    select k.id::text, k.baslik, k.teklif_eden into hid, had, bildir_u from oyun.kanunlar k where k.id = nullif(p_hedef, '')::bigint;
    if hid is null then raise exception 'Kanun bulunamadı.'; end if;
  elsif ht = 'parti' then
    select x.id::text, x.ad, x.gb into hid, had, bildir_u from oyun.partiler x where x.id = nullif(p_hedef, '')::bigint and not x.kapali;
    if hid is null then raise exception 'Parti bulunamadı.'; end if;
  elsif ht = 'dernek' then
    select x.id::text, x.ad, x.baskan into hid, had, bildir_u from oyun.dernekler x where x.id = nullif(p_hedef, '')::bigint and not x.kapali;
    if hid is null then raise exception 'Dernek bulunamadı.'; end if;
    if hid = d.id::text then raise exception 'Derneğin kendisini hedef gösteremezsin.'; end if;
  elsif ht = 'oyuncu' then
    select x.id::text, x.kad, x.id into hid, had, bildir_u from oyun.profiller x where lower(x.kad) = lower(btrim(coalesce(p_hedef, ''))) and not x.yasakli;
    if hid is null then raise exception 'Oyuncu bulunamadı.'; end if;
  else
    raise exception 'Geçersiz konu türü.';
  end if;
  if p_tur = 'destek' and ht not in ('parti','oyuncu') then raise exception 'Destek açıklaması bir partiye ya da bir oyuncuya (adaya) yapılır.'; end if;

  if p_tur in ('basin','bildiri','destek') then
    if (select count(*) from oyun.dernek_eylem where dernek_id = d.id and tur <> 'protesto' and zaman >= t - interval '24 hours') >= 3 then
      raise exception 'Dernek 24 saatte en fazla 3 açıklama yapabilir.';
    end if;
    insert into oyun.dernek_eylem(dernek_id, tur, baslik, metin, hedef_tur, hedef_id, hedef_ad, yazan, zaman, duyuruldu, sonuc_yazildi)
      values (d.id, p_tur, b, m, ht, hid, had, p.id, t, true, true) returning id into eid;
    tur_ad := case p_tur when 'basin' then 'basın açıklaması yaptı' when 'bildiri' then 'bildiri yayımladı' else 'destek açıkladı' end;
    perform oyun.olay('dernek', format('%s %s%s: “%s”', d.ad, tur_ad, case when had is not null then format(' (%s)', had) else '' end, b),
      d.merkez_il, case when ht = 'parti' then hid::bigint end, t);
  else
    -- Protesto
    if p_il is null then p_il := d.merkez_il; end if;
    select ad into ilad from oyun.iller where id = p_il;
    if ilad is null then raise exception 'Geçersiz il.'; end if;
    if not exists (select 1 from oyun.dernek_sube where dernek_id = d.id and il_id = p_il) then
      raise exception 'Protesto yalnız derneğin şubesi olan illerde düzenlenebilir (% ilinde şube yok).', ilad;
    end if;
    if p_bas is null or p_bas < t + interval '15 minutes' then raise exception 'Protestoyu en erken 15 dakika sonrasına koyabilirsin.'; end if;
    if p_bas > t + interval '3 days' then raise exception 'Protestoyu en fazla 3 gün sonrasına planlayabilirsin.'; end if;
    yasak := oyun.miting_secim_yasagi(p_bas, p_bas + interval '1 hour');
    if yasak is not null then raise exception 'Seçim yasağı: % oy verme saatlerinde protesto yapılamaz.', yasak; end if;
    if exists (select 1 from oyun.dernek_eylem where dernek_id = d.id and tur = 'protesto' and not silindi
               and (bas at time zone 'Europe/Istanbul')::date = (p_bas at time zone 'Europe/Istanbul')::date) then
      raise exception 'Dernek aynı gün için zaten bir protesto düzenledi.';
    end if;
    if exists (select 1 from oyun.dernek_eylem where dernek_id = d.id and tur = 'protesto' and not silindi and il_id = p_il
               and bas > p_bas - interval '3 days' and bas < p_bas + interval '3 days') then
      raise exception 'Dernek % ilinde 3 gün içinde zaten protesto yapıyor ya da yaptı.', ilad;
    end if;
    insert into oyun.dernek_eylem(dernek_id, tur, baslik, metin, hedef_tur, hedef_id, hedef_ad, il_id, bas, bit, yazan, zaman)
      values (d.id, 'protesto', b, m, ht, hid, had, p_il, p_bas, p_bas + interval '1 hour', p.id, t) returning id into eid;
    perform oyun.olay('dernek', format('%s, %s''de protesto düzenleyecek: “%s”%s (%s).', d.ad, ilad, b,
      case when had is not null then format(' · %s', had) else '' end, to_char(p_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), p_il::smallint, null, t);
  end if;

  if bildir_u is not null and bildir_u <> p.id then
    perform oyun.bildir(bildir_u, format('%s %s hakkında %s: “%s”', d.ad,
      case ht when 'parti' then 'partin' when 'oyuncu' then 'senin' when 'dernek' then 'derneğin' else 'teklif ettiğin kanun' end,
      case p_tur when 'basin' then 'basın açıklaması yaptı' when 'bildiri' then 'bildiri yayımladı' when 'destek' then 'destek açıkladı' else 'protesto düzenliyor' end, b), t);
  end if;
  return public.dernek_detay(d.id);
end $$;

create or replace function public.dernek_protesto_katil(p_eylem bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); e oyun.dernek_eylem; n int;
begin
  select * into e from oyun.dernek_eylem where id = p_eylem and tur = 'protesto' and not silindi;
  if e.id is null then raise exception 'Protesto bulunamadı.'; end if;
  if t < e.bas then raise exception 'Protesto henüz başlamadı.'; end if;
  if t >= e.bit then raise exception 'Protesto sona erdi.'; end if;
  if p.il_id is distinct from e.il_id then
    raise exception 'Protestoya yalnız % ilinde yaşayanlar katılabilir; başka ilden izleyebilirsin.', (select ad from oyun.iller where id = e.il_id);
  end if;
  insert into oyun.dernek_protesto_katilim(eylem_id, user_id, zaman) values (e.id, p.id, t) on conflict do nothing;
  select count(*) into n from oyun.dernek_protesto_katilim where eylem_id = e.id;
  return jsonb_build_object('katilim', n);
end $$;

-- Moderatör: uygunsuz eylemi kaldırır (şikâyet yetkisi)
create or replace function public.dernek_eylem_sil(p_eylem bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform oyun.yetki_zorunlu('sikayet');
  update oyun.dernek_eylem set silindi = true where id = p_eylem;
  if not found then raise exception 'Eylem bulunamadı.'; end if;
  return jsonb_build_object('tamam', true);
end $$;

-- ---------------------------------------------------------------------
-- Okuma
-- ---------------------------------------------------------------------
create or replace function oyun.dernek_eylem_json(e oyun.dernek_eylem, u uuid, t timestamptz) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', e.id, 'dernek', oyun.dernek_json(e.dernek_id), 'tur', e.tur, 'baslik', e.baslik, 'metin', e.metin,
    'hedef_tur', e.hedef_tur, 'hedef_id', e.hedef_id, 'hedef_ad', e.hedef_ad, 'il', (select ad from oyun.iller where id = e.il_id), 'il_id', e.il_id,
    'bas', e.bas, 'bit', e.bit, 'zaman', e.zaman, 'yazan', oyun.kad(e.yazan),
    'canli', e.tur = 'protesto' and t >= e.bas and t < e.bit, 'bitti', e.tur = 'protesto' and t >= e.bit,
    'katilim', case when e.tur = 'protesto' then (select count(*) from oyun.dernek_protesto_katilim k where k.eylem_id = e.id) end,
    'katildim', e.tur = 'protesto' and exists (select 1 from oyun.dernek_protesto_katilim k where k.eylem_id = e.id and k.user_id = u),
    'benim_ilim', e.il_id is not null and e.il_id = (select il_id from oyun.profiller where id = u))
$$;

create or replace function public.dernekler() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'ad', d.ad, 'alan', d.alan, 'alan_ad', oyun.dernek_alan_ad(d.alan),
      'merkez', (select ad from oyun.iller where id = d.merkez_il), 'baskan', oyun.kad(d.baskan),
      'uye', (select count(*) from oyun.dernek_uyeler u where u.dernek_id = d.id),
      'sube', (select count(*) from oyun.dernek_sube s where s.dernek_id = d.id),
      'uyesiyim', exists (select 1 from oyun.dernek_uyeler u where u.dernek_id = d.id and u.user_id = auth.uid()))
    order by (select count(*) from oyun.dernek_uyeler u where u.dernek_id = d.id) desc, d.id), '[]'::jsonb)
  from oyun.dernekler d where not d.kapali
$$;

create or replace function public.dernek_detay(p_dernek bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); d oyun.dernekler; rol text;
begin
  select * into d from oyun.dernekler where id = p_dernek;
  if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  select x.rol into rol from oyun.dernek_uyeler x where x.dernek_id = d.id and x.user_id = u;
  return jsonb_build_object('id', d.id, 'ad', d.ad, 'alan', d.alan, 'alan_ad', oyun.dernek_alan_ad(d.alan), 'amac', d.amac,
    'kapali', d.kapali, 'kurulus', d.kurulus, 'kurucu', oyun.kad(d.kurucu), 'baskan', oyun.kad(d.baskan),
    'merkez', (select ad from oyun.iller where id = d.merkez_il), 'merkez_il', d.merkez_il,
    'kasa', round(d.kasa), 'rolum', rol, 'yetkili', rol in ('baskan','yonetim'),
    'harc', oyun.dernek_harci(),
    'uyeler', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'il', i.ad, 'rol', x.rol) order by (x.rol = 'baskan') desc, (x.rol = 'yonetim') desc, x.katilim)
               from oyun.dernek_uyeler x join oyun.profiller pr on pr.id = x.user_id join oyun.iller i on i.id = pr.il_id where x.dernek_id = d.id), '[]'::jsonb),
    'subeler', coalesce((select jsonb_agg(jsonb_build_object('il_id', s.il_id, 'il', i.ad, 'merkez', s.il_id = d.merkez_il) order by s.il_id <> d.merkez_il, i.ad)
               from oyun.dernek_sube s join oyun.iller i on i.id = s.il_id where s.dernek_id = d.id), '[]'::jsonb),
    'sube_ucretleri', (select jsonb_build_object('1', round(1000 * e / 100) * 100, '2', round(2000 * e / 100) * 100, '3', round(3000 * e / 100) * 100)
                       from (select coalesce((select endeks from oyun.ulke where id = 1), 1) e) z),
    'hareketler', case when rol in ('baskan','yonetim') then coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'aciklama', h.aciklama) order by h.zaman desc)
               from (select * from oyun.dernek_hareket where dernek_id = d.id order by zaman desc limit 15) h), '[]'::jsonb) end,
    'eylemler', coalesce((select jsonb_agg(oyun.dernek_eylem_json(e, u, t) order by coalesce(e.bas, e.zaman) desc)
               from (select * from oyun.dernek_eylem where dernek_id = d.id and not silindi order by coalesce(bas, zaman) desc limit 30) e), '[]'::jsonb));
end $$;

-- Gündem için: son açıklamalar ve yaklaşan/canlı protestolar
create or replace function public.dernek_akis(p_limit int default 20) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'protestolar', coalesce((select jsonb_agg(oyun.dernek_eylem_json(e, auth.uid(), oyun.simdi()) order by e.bas)
       from oyun.dernek_eylem e where e.tur = 'protesto' and not e.silindi and e.bit > oyun.simdi() - interval '6 hours' and e.bas < oyun.simdi() + interval '3 days'), '[]'::jsonb),
    'aciklamalar', coalesce((select jsonb_agg(oyun.dernek_eylem_json(e, auth.uid(), oyun.simdi()) order by e.zaman desc)
       from (select * from oyun.dernek_eylem where tur <> 'protesto' and not silindi order by zaman desc limit least(greatest(coalesce(p_limit, 20), 1), 50)) e), '[]'::jsonb))
$$;

-- ---------------------------------------------------------------------
-- Dakikalık motor: protesto başlayınca ve bitince
-- ---------------------------------------------------------------------
create or replace function oyun.dernek_tick(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare e record; n int;
begin
  for e in select x.*, d.ad dernek_ad, i.ad il_ad from oyun.dernek_eylem x join oyun.dernekler d on d.id = x.dernek_id join oyun.iller i on i.id = x.il_id
           where x.tur = 'protesto' and not x.silindi and not x.duyuruldu and x.bas <= t and x.bit > t loop
    update oyun.dernek_eylem set duyuruldu = true where id = e.id;
    insert into oyun.bildirimler(user_id, zaman, metin)
      select pr.id, t, format('%s şu an %s''de protesto düzenliyor: “%s”. Bir saat içinde Gündem''den katılabilirsin.', e.dernek_ad, e.il_ad, e.baslik)
      from oyun.profiller pr where pr.il_id = e.il_id and not pr.yasakli;
    insert into oyun.bildirimler(user_id, zaman, metin)
      select u.user_id, t, format('Derneğin %s %s''de protestoda: “%s”.', e.dernek_ad, e.il_ad, e.baslik)
      from oyun.dernek_uyeler u join oyun.profiller pr on pr.id = u.user_id where u.dernek_id = e.dernek_id and pr.il_id <> e.il_id;
    if oyun.push_acik() then
      perform oyun.push_konuya('s_il_' || e.il_id, null, format('%s sokakta!', e.dernek_ad),
        format('%s protestosu başladı: “%s”. Katılmak için dokun.', e.il_ad, e.baslik), jsonb_build_object('ekran', 'gundem'));
    end if;
  end loop;
  for e in select x.*, d.ad dernek_ad, i.ad il_ad from oyun.dernek_eylem x join oyun.dernekler d on d.id = x.dernek_id join oyun.iller i on i.id = x.il_id
           where x.tur = 'protesto' and not x.silindi and not x.sonuc_yazildi and x.bit <= t loop
    select count(*) into n from oyun.dernek_protesto_katilim where eylem_id = e.id;
    update oyun.dernek_eylem set sonuc_yazildi = true, duyuruldu = true where id = e.id;
    perform oyun.olay('dernek', format('%s''deki %s protestosu %s kişiyle tamamlandı: “%s”%s.', e.il_ad, e.dernek_ad, n, e.baslik,
      case when e.hedef_ad is not null then format(' · %s', e.hedef_ad) else '' end), e.il_id, case when e.hedef_tur = 'parti' then e.hedef_id::bigint end, t);
  end loop;
end $$;

-- 50'deki miting motoruna dernek motoru eklenir (miting davranışı aynı)
create or replace function oyun.miting_tick(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare m record; n int; c int; enIyi text; konusma int;
begin
  perform oyun.dernek_tick(t);
  perform oyun.parti_miting_temizle(t);
  for m in select x.*, p.kad, i.ad il_ad, pa.kisa parti_kisa from oyun.mitingler x join oyun.profiller p on p.id = x.user_id join oyun.iller i on i.id = x.il_id
           left join oyun.partiler pa on pa.id = x.parti_id
           where not x.duyuruldu and x.bas <= t and x.bit > t loop
    update oyun.mitingler set duyuruldu = true where id = m.id;
    insert into oyun.bildirimler(user_id, zaman, metin)
      select pr.id, t, format('%s şu an %s meydanında: “%s”. Bir saat içinde Gündem''den mitinge katılıp konuşmaları dinleyebilir, tepki verebilirsin.', m.kad, m.il_ad, m.baslik)
      from oyun.profiller pr where pr.il_id = m.il_id and pr.id <> m.user_id and not pr.yasakli;
    if m.tur = 'parti' then
      insert into oyun.bildirimler(user_id, zaman, metin)
        select pr.id, t, format('%s mitingi başladı: %s, %s meydanında “%s”. Gündem''den canlı izleyebilirsin.', m.parti_kisa, m.kad, m.il_ad, m.baslik)
        from oyun.profiller pr where pr.parti_id = m.parti_id and pr.il_id <> m.il_id and pr.id <> m.user_id and not pr.yasakli;
    end if;
    perform oyun.bildir(m.user_id, format('%s mitingin başladı. Meydan seni bekliyor: Gündem''den mitingine girip kürsüden konuş.', m.il_ad), t);
    if oyun.push_acik() then
      perform oyun.push_konuya('s_il_' || m.il_id, null, format('%s meydanda!', m.kad),
        format('%s mitingi başladı: “%s”. Katılmak için dokun.', m.il_ad, m.baslik), jsonb_build_object('ekran', 'gundem'));
    end if;
  end loop;
  for m in select x.*, p.kad, i.ad il_ad from oyun.mitingler x join oyun.profiller p on p.id = x.user_id join oyun.iller i on i.id = x.il_id
           where not x.sonuc_yazildi and x.bit <= t loop
    select count(*) into n from oyun.miting_katilim where miting_id = m.id and user_id <> m.user_id;
    select count(*) into konusma from oyun.miting_konusma where miting_id = m.id and not silindi;
    c := oyun.miting_cosku(m.id);
    select left(k.metin, 120) into enIyi from oyun.miting_konusma k
      where k.miting_id = m.id and not k.silindi
        and exists (select 1 from oyun.miting_tepki r where r.konusma_id = k.id and oyun.miting_tepki_puan(r.tur) > 0)
      order by (select sum(oyun.miting_tepki_puan(r.tur)) from oyun.miting_tepki r where r.konusma_id = k.id) desc, k.id limit 1;
    update oyun.mitingler set sonuc_yazildi = true, duyuruldu = true, cosku = c where id = m.id;
    if konusma = 0 then
      perform oyun.olay('secim', format('%s, %s meydanında %s kişiyi topladı ama kürsüye hiç çıkmadı: “%s”.', m.kad, m.il_ad, n, m.baslik), m.il_id, m.parti_id, t);
    else
      perform oyun.olay('secim', format('%s %s mitingi: %s kişi, coşku %s/100 (%s).%s', m.kad, m.il_ad, n, c, lower(oyun.miting_cosku_ad(c)),
        case when enIyi is not null then format(' En çok alkışlanan söz: “%s”', enIyi) else '' end), m.il_id, m.parti_id, t);
    end if;
    perform oyun.bildir(m.user_id, format('%s mitingin sona erdi: %s kişi katıldı, %s kez kürsüye çıktın, meydanın coşkusu %s/100.', m.il_ad, n, konusma, c), t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['dernek_kur(text,text,text)','dernek_katil(bigint)','dernek_ayril(bigint)','dernek_yonetim_ata(bigint,text,boolean)',
    'dernek_baskan_devret(bigint,text)','dernek_bagis(bigint,numeric)','dernek_sube_ac(bigint,integer)',
    'dernek_eylem(bigint,text,text,text,text,text,integer,timestamptz)','dernek_protesto_katil(bigint)','dernek_eylem_sil(bigint)',
    'dernekler()','dernek_detay(bigint)','dernek_akis(integer)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
revoke all on function oyun.dernek_tick(timestamptz), oyun.miting_tick(timestamptz) from public, anon, authenticated;
commit;
