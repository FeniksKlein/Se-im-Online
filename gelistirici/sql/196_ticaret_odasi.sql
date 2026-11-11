-- =====================================================================
--  196 (11.11.2026) · TİCARET ODALARI VE İŞVEREN SENDİKALARI (Ercan)
--  • 81 il ticaret odası + Türkiye Odalar Birliği (il_id = 0). Faal her şirket, merkez ilinin odasına
--    ZORUNLU ve otomatik kaydedilir (merkez il: ilk şube ili → işletme ili → yöneticinin ili).
--  • Aidat: haftalık, şirket başına; tutarı il oda başkanı belirler (500–25.000 ₺, başlangıç 3.000 ₺).
--    Şirket kasasından alınır; %75'i il odasına, %25'i Birliğe gider. Kasada para yoksa borç birikir
--    (en çok 8 hafta); aidat borcu olan şirket oy kullanamaz.
--  • Seçim: her şirketin 1 oyu vardır, oyu şirket yöneticisi kullanır; en çok oyu alan kazanır.
--    Adaylık 48 saat, oylama 24 saat, görev 21 gün. Aday, o odaya (Birlik için herhangi bir odaya) üye bir
--    şirketin yöneticisi olmalıdır; isterse üyesi olduğu işveren sendikasının adayı olarak çıkar.
--  • Oda başkanı oda bütçesiyle icraat yapar: üyelere eşit destek, ticaret fuarı (il gelişimi), mesleki eğitim
--    (il memnuniyeti), ekonomi raporu, aidat ayarı; Birlik başkanı ayrıca il odalarına kaynak aktarır.
--  • İşveren sendikaları: şirket yöneticileri kurar (şirket kasasından 50.000 ₺ harç), şirketler serbestçe
--    üye olur (şirket başına tek sendika). Sendika aday çıkarır; Birlik başkanlığını alamayan sendikalar
--    "muhalefet" olur: bildiri yayımlar, kampanya yapar, üye şirketlerin yarısından fazlasının imzasıyla
--    erken seçim açtırır.
--  Para yalnız şirket ↔ oda/sendika kasası arasında döner; oda/sendika kasasından kişilere ödeme yoktur.
--  Aidat şirket hareketinde kasa çıkışı olarak yazılır (faaliyet gideri sayılmaz; şirket değeri çarpanını bozmaz).
--  Mevcut tablo ve işlevlere dokunulmaz (yalnız oyun.unvan'a oda başkanı ünvanı eklenir).
-- =====================================================================

create table if not exists oyun.oda(
  il_id smallint primary key,                       -- 0: Türkiye Odalar Birliği
  kasa numeric not null default 0, baskan uuid, baskan_bas timestamptz, baskan_sendika bigint,
  aidat numeric not null default 3000 check (aidat between 500 and 25000), aidat_degisim timestamptz,
  sonraki_secim timestamptz, toplam_aidat numeric not null default 0, toplam_harcama numeric not null default 0);
create table if not exists oyun.oda_uye(
  sirket_id bigint primary key, il_id smallint not null, kayit timestamptz not null, aidat_son date not null,
  aidat_borc numeric not null default 0, toplam_aidat numeric not null default 0, aktif boolean not null default true);
create index if not exists oda_uye_il on oyun.oda_uye(il_id) where aktif;
create table if not exists oyun.oda_hareket(
  id bigserial primary key, il_id smallint not null, zaman timestamptz not null, tutar numeric not null, tur text not null, aciklama text, user_id uuid);
create index if not exists oda_hareket_il on oyun.oda_hareket(il_id, id desc);
create table if not exists oyun.oda_secim(
  id bigserial primary key, il_id smallint not null, aday_bas timestamptz not null, oy_bas timestamptz not null, oy_son timestamptz not null,
  durum text not null default 'aday' check (durum in ('aday','oy','bitti','iptal')), kazanan uuid, katilim int, sonuc jsonb, neden text);
create index if not exists oda_secim_il on oyun.oda_secim(il_id, id desc);
create table if not exists oyun.oda_aday(
  secim_id bigint not null references oyun.oda_secim(id), user_id uuid not null, sendika_id bigint, vaat text,
  cekildi boolean not null default false, zaman timestamptz not null, primary key (secim_id, user_id));
create table if not exists oyun.oda_oy(
  secim_id bigint not null references oyun.oda_secim(id), sirket_id bigint not null, aday uuid not null, oy_veren uuid not null,
  zaman timestamptz not null, primary key (secim_id, sirket_id));
create table if not exists oyun.oda_icraat(
  id bigserial primary key, il_id smallint not null, tur text not null, baslik text not null, tutar numeric not null default 0,
  yapan uuid, zaman timestamptz not null, detay jsonb);
create index if not exists oda_icraat_il on oyun.oda_icraat(il_id, id desc);
create table if not exists oyun.oda_imza(
  il_id smallint not null, sirket_id bigint not null, imzalayan uuid not null, zaman timestamptz not null, primary key (il_id, sirket_id));
create table if not exists oyun.sendika(
  id bigserial primary key, ad text not null, amac text, kurucu uuid not null, baskan uuid, kasa numeric not null default 0,
  aidat numeric not null default 0 check (aidat between 0 and 10000), kurulus timestamptz not null, kapali boolean not null default false);
create unique index if not exists sendika_ad_tek on oyun.sendika(lower(ad)) where not kapali;
create table if not exists oyun.sendika_uye(
  sirket_id bigint primary key, sendika_id bigint not null references oyun.sendika(id), katilim timestamptz not null, aidat_son date not null);
create index if not exists sendika_uye_s on oyun.sendika_uye(sendika_id);
create table if not exists oyun.sendika_hareket(
  id bigserial primary key, sendika_id bigint not null, zaman timestamptz not null, tutar numeric not null, tur text not null, aciklama text, user_id uuid);
create table if not exists oyun.sendika_bildiri(
  id bigserial primary key, sendika_id bigint not null references oyun.sendika(id), il_id smallint not null, yazar uuid not null,
  tur text not null default 'bildiri', baslik text not null, metin text not null, tutar numeric not null default 0, zaman timestamptz not null, silindi boolean not null default false);
create index if not exists sendika_bildiri_il on oyun.sendika_bildiri(il_id, id desc);

do $r$ declare x text; begin
  foreach x in array array['oda','oda_uye','oda_hareket','oda_secim','oda_aday','oda_oy','oda_icraat','oda_imza','sendika','sendika_uye','sendika_hareket','sendika_bildiri'] loop
    execute format('alter table oyun.%I enable row level security', x);
    execute format('revoke all on oyun.%I from anon, authenticated', x);
  end loop;
end $r$;

-- ---------------------------------------------------------------- yardımcılar
-- Boş metinde hata vermeyen temizleyici (metin_temizle boş metni reddeder)
create or replace function oyun.metin_ops(m text, n integer) returns text language sql set search_path = '' as $$
  select case when m is null or btrim(m) = '' then '' else oyun.metin_temizle(m, n) end
$$;
revoke all on function oyun.metin_ops(text, integer) from public, anon, authenticated;
create or replace function oyun.sirket_merkez_il(p_sirket bigint) returns smallint language sql stable set search_path = '' as $$
  select coalesce(
    (select x.il_id from oyun.sirket_il_subeleri x where x.sirket_id = p_sirket order by x.acilis, x.id limit 1),
    (select e.il_id from oyun.eko_isletmeler e where e.sirket_id = p_sirket and e.il_id is not null order by e.olusturma limit 1),
    (select pr.il_id from oyun.sirketler s join oyun.profiller pr on pr.id = coalesce(s.yonetici, s.kurucu) where s.id = p_sirket),
    6)::smallint
$$;
create or replace function oyun.sirket_sorumlu(p_sirket bigint) returns uuid language sql stable set search_path = '' as $$
  select coalesce(s.yonetici, (select o.user_id from oyun.sirket_ortaklari o where o.sirket_id = s.id order by o.pay desc, o.user_id limit 1), s.kurucu)
    from oyun.sirketler s where s.id = p_sirket
$$;
create or replace function oyun.oda_ad(p_il smallint) returns text language sql stable set search_path = '' as $$
  select case when p_il = 0 then 'Türkiye Odalar Birliği' else coalesce((select ad from oyun.iller where id = p_il), '?') || ' Ticaret Odası' end
$$;
-- u, p_il odasına (0: herhangi bir odaya) üye faal bir şirketin yöneticisi mi?
create or replace function oyun.oda_temsilci(u uuid, p_il smallint) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.oda_uye m join oyun.sirketler s on s.id = m.sirket_id and s.aktif
                  where m.aktif and (p_il = 0 or m.il_id = p_il) and oyun.sirket_yonetici_mi(s.id, u))
$$;
create or replace function oyun.oda_uye_sayisi(p_il smallint) returns int language sql stable set search_path = '' as $$
  select count(*)::int from oyun.oda_uye m where m.aktif and (p_il = 0 or m.il_id = p_il)
$$;
create or replace function oyun.oda_duyur(p_il smallint, p_metin text, t timestamptz) returns void language plpgsql set search_path = '' as $$
declare u uuid;
begin
  for u in select distinct oyun.sirket_sorumlu(m.sirket_id) from oyun.oda_uye m where m.aktif and (p_il = 0 or m.il_id = p_il) loop
    if u is not null then perform oyun.bildir(u, p_metin, t); end if;
  end loop;
end $$;

-- Zorunlu kayıt: faal her şirket bir odanın üyesidir
create or replace function oyun.oda_uye_esitle() returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; n int := 0; r record;
begin
  insert into oyun.oda(il_id) select 0 where not exists (select 1 from oyun.oda where il_id = 0);
  insert into oyun.oda(il_id) select i.id from oyun.iller i where not exists (select 1 from oyun.oda o where o.il_id = i.id);
  insert into oyun.oda_uye(sirket_id, il_id, kayit, aidat_son)
    select s.id, oyun.sirket_merkez_il(s.id), t, bugun from oyun.sirketler s
     where s.aktif and not exists (select 1 from oyun.oda_uye u where u.sirket_id = s.id);
  get diagnostics n = row_count;
  if n > 0 then
    for r in select oyun.sirket_sorumlu(u.sirket_id) kisi, count(*) adet from oyun.oda_uye u where u.kayit = t group by 1 loop
      if r.kisi is not null then
        perform oyun.bildir(r.kisi, format('%s şirketin ticaret odasına kaydedildi (üyelik zorunludur). Haftalık aidat şirket kasasından alınır; şirket başına 1 oy hakkınla oda başkanını seçer, aday olabilirsin. Ekonomi › Ticaret Odası.', r.adet), t);
      end if;
    end loop;
  end if;
  update oyun.oda_uye u set aktif = false where u.aktif and not exists (select 1 from oyun.sirketler s where s.id = u.sirket_id and s.aktif);
  update oyun.oda_uye u set aktif = true, aidat_son = bugun where not u.aktif and exists (select 1 from oyun.sirketler s where s.id = u.sirket_id and s.aktif);
  delete from oyun.sendika_uye su where not exists (select 1 from oyun.sirketler s where s.id = su.sirket_id and s.aktif);
  return n;
end $$;

-- Haftalık aidat (borç en çok 8 hafta birikir)
create or replace function oyun.oda_aidat_tahsil(p_sirket bigint, p_tahakkuk boolean) returns numeric language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; m oyun.oda_uye; o oyun.oda;
  v_kasa numeric; v_ad text; borc numeric; ode numeric; ilpay numeric;
begin
  perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(p_sirket::text));
  select * into m from oyun.oda_uye where sirket_id = p_sirket and aktif for update;
  if m.sirket_id is null then return 0; end if;
  select * into o from oyun.oda where il_id = m.il_id;
  select s.kasa, s.ad into v_kasa, v_ad from oyun.sirketler s where s.id = p_sirket and s.aktif for update;
  if not found then return 0; end if;
  borc := case when p_tahakkuk then least(o.aidat * 8, m.aidat_borc + o.aidat) else m.aidat_borc end;
  ode := greatest(0, least(floor(coalesce(v_kasa, 0)), borc));
  if ode > 0 then
    ilpay := round(ode * 0.75, 2);
    update oyun.sirketler set kasa = kasa - ode where id = p_sirket;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
      values (p_sirket, t, -ode, format('%s aidatı', oyun.oda_ad(m.il_id)), 0, 0, 0);
    update oyun.oda set kasa = kasa + ilpay, toplam_aidat = toplam_aidat + ilpay where il_id = m.il_id;
    update oyun.oda set kasa = kasa + (ode - ilpay), toplam_aidat = toplam_aidat + (ode - ilpay) where il_id = 0;
    insert into oyun.oda_hareket(il_id, zaman, tutar, tur, aciklama) values
      (m.il_id, t, ilpay, 'aidat', v_ad || ' aidatı'), (0, t, ode - ilpay, 'birlik_payi', v_ad || ' · ' || oyun.oda_ad(m.il_id) || ' aidatından Birlik payı');
  end if;
  update oyun.oda_uye set aidat_son = case when p_tahakkuk then bugun else aidat_son end, aidat_borc = borc - ode, toplam_aidat = toplam_aidat + ode
   where sirket_id = p_sirket;
  return ode;
end $$;

create or replace function oyun.oda_aidat_isle() returns int language plpgsql security definer set search_path = '' as $$
declare bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; r record; n int := 0; t timestamptz := oyun.simdi(); x numeric; ode numeric; v_kasa numeric;
begin
  for r in select u.sirket_id from oyun.oda_uye u where u.aktif and u.aidat_son <= bugun - 7 order by u.sirket_id loop
    perform oyun.oda_aidat_tahsil(r.sirket_id, true); n := n + 1;
  end loop;
  -- sendika aidatı: kasada varsa alınır, borç birikmez
  for r in select su.sirket_id, su.sendika_id, sd.aidat, sd.ad from oyun.sendika_uye su join oyun.sendika sd on sd.id = su.sendika_id and not sd.kapali
            where su.aidat_son <= bugun - 7 order by su.sirket_id loop
    perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(r.sirket_id::text));
    select s.kasa into v_kasa from oyun.sirketler s where s.id = r.sirket_id and s.aktif for update;
    ode := case when found and r.aidat > 0 and coalesce(v_kasa, 0) >= r.aidat then r.aidat else 0 end;
    if ode > 0 then
      update oyun.sirketler set kasa = kasa - ode where id = r.sirket_id;
      insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
        values (r.sirket_id, t, -ode, r.ad || ' sendika aidatı', 0, 0, 0);
      update oyun.sendika set kasa = kasa + ode where id = r.sendika_id;
      insert into oyun.sendika_hareket(sendika_id, zaman, tutar, tur, aciklama) values (r.sendika_id, t, ode, 'aidat', (select ad from oyun.sirketler where id = r.sirket_id) || ' aidatı');
    end if;
    update oyun.sendika_uye set aidat_son = bugun where sirket_id = r.sirket_id;
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------- seçim motoru
create or replace function oyun.oda_secim_ac(p_il smallint, p_neden text) returns bigint language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); i bigint;
begin
  if exists (select 1 from oyun.oda_secim where il_id = p_il and durum in ('aday','oy')) then return null; end if;
  insert into oyun.oda_secim(il_id, aday_bas, oy_bas, oy_son, neden) values (p_il, t, t + interval '48 hours', t + interval '72 hours', p_neden) returning id into i;
  delete from oyun.oda_imza where il_id = p_il;
  perform oyun.oda_duyur(p_il, format('%s başkanlık seçimi başladı%s. Adaylık 48 saat açık; ardından 24 saat oylama. Her şirketin 1 oyu var. Ekonomi › Ticaret Odası.',
    oyun.oda_ad(p_il), case when p_neden is not null then ' (' || p_neden || ')' else '' end), t);
  if p_il = 0 then perform oyun.olay('ekonomi', 'Türkiye Odalar Birliği başkanlık seçimi süreci başladı; adaylık 48 saat açık.', null, null, t); end if;
  return i;
end $$;

create or replace function oyun.oda_secim_isle() returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); o oyun.oda; s oyun.oda_secim; n int := 0; kaz uuid; ksen bigint; topl int; son jsonb;
begin
  for o in select * from oyun.oda order by il_id loop
    if o.baskan is not null and not oyun.oda_temsilci(o.baskan, o.il_id) then
      update oyun.oda set baskan = null, baskan_bas = null, baskan_sendika = null, sonraki_secim = null where il_id = o.il_id;
      perform oyun.oda_duyur(o.il_id, format('%s başkanı, üye bir şirketin yöneticisi olmadığı için görevinden düştü. Yeni seçim açılacak.', oyun.oda_ad(o.il_id)), t);
      o.baskan := null;
    end if;
    if oyun.oda_uye_sayisi(o.il_id) > 0 and (o.baskan is null or o.baskan_bas < t - interval '21 days')
       and (o.sonraki_secim is null or o.sonraki_secim <= t)
       and not exists (select 1 from oyun.oda_secim x where x.il_id = o.il_id and x.durum in ('aday','oy')) then
      perform oyun.oda_secim_ac(o.il_id, case when o.baskan is null then null else 'görev süresi doldu' end); n := n + 1;
    end if;
  end loop;
  for s in select * from oyun.oda_secim where durum in ('aday','oy') order by id for update loop
    if s.durum = 'aday' and t >= s.oy_bas then
      if not exists (select 1 from oyun.oda_aday a where a.secim_id = s.id and not a.cekildi and oyun.oda_temsilci(a.user_id, s.il_id)) then
        update oyun.oda_secim set durum = 'iptal' where id = s.id;
        update oyun.oda set sonraki_secim = t + interval '3 days' where il_id = s.il_id;
        perform oyun.oda_duyur(s.il_id, format('%s seçimine aday çıkmadı; seçim 3 gün sonra yeniden açılacak.', oyun.oda_ad(s.il_id)), t);
      else
        update oyun.oda_secim set durum = 'oy' where id = s.id;
        perform oyun.oda_duyur(s.il_id, format('%s seçiminde oylama başladı (24 saat). Her şirketin için ayrı oy kullan: Ekonomi › Ticaret Odası.', oyun.oda_ad(s.il_id)), t);
      end if;
      n := n + 1;
    elsif s.durum = 'oy' and t >= s.oy_son then
      with sayim as (
        select a.user_id, a.sendika_id, a.zaman,
               (select count(*) from oyun.oda_oy y join oyun.oda_uye m on m.sirket_id = y.sirket_id and m.aktif and (s.il_id = 0 or m.il_id = s.il_id)
                 where y.secim_id = s.id and y.aday = a.user_id)::int oy
          from oyun.oda_aday a where a.secim_id = s.id and not a.cekildi and oyun.oda_temsilci(a.user_id, s.il_id))
      select (select x.user_id from sayim x order by x.oy desc, x.zaman limit 1),
             (select x.sendika_id from sayim x order by x.oy desc, x.zaman limit 1),
             (select coalesce(sum(x.oy), 0)::int from sayim x),
             (select coalesce(jsonb_agg(jsonb_build_object('aday', oyun.kad(x.user_id), 'oy', x.oy,
                 'sendika', (select sd.ad from oyun.sendika sd where sd.id = x.sendika_id)) order by x.oy desc, x.zaman), '[]'::jsonb) from sayim x)
        into kaz, ksen, topl, son;
      update oyun.oda_secim set durum = 'bitti', kazanan = kaz, katilim = topl, sonuc = son where id = s.id;
      if kaz is not null then
        update oyun.oda set baskan = kaz, baskan_bas = t, baskan_sendika = ksen, sonraki_secim = null where il_id = s.il_id;
        perform oyun.oda_duyur(s.il_id, format('%s başkanlığını %s kazandı (%s oy kullanıldı).', oyun.oda_ad(s.il_id), oyun.kad(kaz), topl), t);
        perform oyun.bildir(kaz, format('%s başkanı seçildin. Oda bütçesiyle icraat yapabilirsin: Ekonomi › Ticaret Odası.', oyun.oda_ad(s.il_id)), t);
        perform oyun.olay('ekonomi', format('%s başkanlığına %s seçildi%s.', oyun.oda_ad(s.il_id), oyun.kad(kaz),
          coalesce(' (' || (select sd.ad from oyun.sendika sd where sd.id = ksen) || ' adayı)', '')), case when s.il_id = 0 then null else s.il_id end, null, t);
      else
        update oyun.oda set sonraki_secim = t + interval '3 days' where il_id = s.il_id;
      end if;
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

create or replace function oyun.oda_tick() returns int language plpgsql security definer set search_path = '' as $$
declare n int := 0; r record; yeni uuid;
begin
  if not pg_try_advisory_xact_lock(hashtext('oyun.oda_tick')) then return 0; end if;
  n := oyun.oda_uye_esitle();
  -- sendika başkanı üye bir şirketin yöneticisi olmalı; değilse en eski üyenin yöneticisine geçer, üye yoksa sendika kapanır
  for r in select sd.* from oyun.sendika sd where not sd.kapali loop
    if not exists (select 1 from oyun.sendika_uye su where su.sendika_id = r.id) then
      update oyun.sendika set kapali = true, baskan = null where id = r.id;
    elsif r.baskan is null or not exists (select 1 from oyun.sendika_uye su where su.sendika_id = r.id and oyun.sirket_yonetici_mi(su.sirket_id, r.baskan)) then
      select oyun.sirket_sorumlu(su.sirket_id) into yeni from oyun.sendika_uye su where su.sendika_id = r.id order by su.katilim, su.sirket_id limit 1;
      update oyun.sendika set baskan = yeni where id = r.id;
      if yeni is not null then perform oyun.bildir(yeni, format('%s sendikasının başkanlığı sana geçti.', r.ad)); end if;
    end if;
  end loop;
  n := n + oyun.oda_aidat_isle();
  n := n + oyun.oda_secim_isle();
  return n;
end $$;

-- ---------------------------------------------------------------- oda RPC'leri
create or replace function public.oda_panel(p_il integer default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v_il smallint; o oyun.oda; s oyun.oda_secim; son oyun.oda_secim; uye int;
begin
  perform oyun.oda_uye_esitle();
  v_il := coalesce(p_il, (select m.il_id from oyun.oda_uye m where m.aktif and oyun.sirket_yonetici_mi(m.sirket_id, p.id) order by m.kayit, m.sirket_id limit 1), p.il_id, 0)::smallint;
  select * into o from oyun.oda where il_id = v_il;
  if o.il_id is null then raise exception 'Oda bulunamadı.'; end if;
  uye := oyun.oda_uye_sayisi(v_il);
  select * into s from oyun.oda_secim where il_id = v_il and durum in ('aday','oy') order by id desc limit 1;
  select * into son from oyun.oda_secim where il_id = v_il and durum = 'bitti' order by id desc limit 1;
  return jsonb_build_object('il', v_il, 'ad', oyun.oda_ad(v_il), 'ulusal', v_il = 0, 'simdi', t,
    'oda', jsonb_build_object('kasa', round(o.kasa), 'aidat', o.aidat, 'baskan', oyun.sm_kisi(o.baskan), 'baskan_bas', o.baskan_bas,
      'donem_bitis', o.baskan_bas + interval '21 days', 'uye', uye,
      'borclu', (select count(*) from oyun.oda_uye m where m.aktif and m.aidat_borc > 0 and (v_il = 0 or m.il_id = v_il)),
      'baskan_sendika', (select jsonb_build_object('id', sd.id, 'ad', sd.ad) from oyun.sendika sd where sd.id = o.baskan_sendika),
      'toplam_aidat', round(o.toplam_aidat), 'toplam_harcama', round(o.toplam_harcama), 'sonraki_secim', o.sonraki_secim),
    'benim', jsonb_build_object('baskan', o.baskan = p.id, 'temsilci', oyun.oda_temsilci(p.id, v_il),
      'sirketler', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ad', c.ad, 'il_id', m.il_id, 'il', (select ad from oyun.iller where id = m.il_id),
          'aidat_borc', round(m.aidat_borc), 'bu_oda', (v_il = 0 or m.il_id = v_il),
          'sendika', (select jsonb_build_object('id', sd.id, 'ad', sd.ad) from oyun.sendika_uye su join oyun.sendika sd on sd.id = su.sendika_id where su.sirket_id = c.id),
          'oy', (select oyun.kad(y.aday) from oyun.oda_oy y where y.secim_id = s.id and y.sirket_id = c.id),
          'imza', exists (select 1 from oyun.oda_imza z where z.il_id = v_il and z.sirket_id = c.id)) order by c.ad), '[]'::jsonb)
        from oyun.oda_uye m join oyun.sirketler c on c.id = m.sirket_id and c.aktif where m.aktif and oyun.sirket_yonetici_mi(c.id, p.id))),
    'secim', case when s.id is null then null else jsonb_build_object('id', s.id, 'durum', s.durum, 'aday_bas', s.aday_bas, 'oy_bas', s.oy_bas, 'oy_son', s.oy_son, 'neden', s.neden,
      'adayim', exists (select 1 from oyun.oda_aday a where a.secim_id = s.id and a.user_id = p.id and not a.cekildi),
      'kullanilan', (select count(*) from oyun.oda_oy y where y.secim_id = s.id), 'oy_hakki', uye,
      'adaylar', (select coalesce(jsonb_agg(oyun.sm_kisi(a.user_id) || jsonb_build_object('vaat', a.vaat,
          'sendika', (select sd.ad from oyun.sendika sd where sd.id = a.sendika_id)) order by a.zaman), '[]'::jsonb)
        from oyun.oda_aday a where a.secim_id = s.id and not a.cekildi)) end,
    'son_secim', case when son.id is null then null else jsonb_build_object('bitis', son.oy_son, 'kazanan', oyun.kad(son.kazanan), 'katilim', son.katilim, 'sonuc', son.sonuc) end,
    'icraatlar', (select coalesce(jsonb_agg(jsonb_build_object('tur', x.tur, 'baslik', x.baslik, 'tutar', round(x.tutar), 'yapan', oyun.kad(x.yapan), 'zaman', x.zaman,
        'metin', x.detay->>'metin') order by x.id desc), '[]'::jsonb)
      from (select * from oyun.oda_icraat where il_id = v_il order by id desc limit 15) x),
    'bildiriler', (select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'sendika', sd.ad, 'sendika_id', sd.id, 'tur', b.tur, 'baslik', b.baslik, 'metin', b.metin, 'zaman', b.zaman,
        'yazar', oyun.kad(b.yazar), 'konum', case when sd.id = o.baskan_sendika then 'yonetim' else 'muhalefet' end) order by b.id desc), '[]'::jsonb)
      from (select * from oyun.sendika_bildiri where il_id = v_il and not silindi order by id desc limit 15) b join oyun.sendika sd on sd.id = b.sendika_id),
    'imza', jsonb_build_object('sayi', (select count(*) from oyun.oda_imza z join oyun.oda_uye m on m.sirket_id = z.sirket_id and m.aktif where z.il_id = v_il),
      'gereken', uye / 2 + 1),
    'uyeler', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ad', c.ad, 'yonetici', oyun.kad(oyun.sirket_sorumlu(c.id)), 'borclu', m.aidat_borc > 0,
        'il', case when v_il = 0 then (select ad from oyun.iller where id = m.il_id) end,
        'sendika', (select sd.ad from oyun.sendika_uye su join oyun.sendika sd on sd.id = su.sendika_id where su.sirket_id = c.id)) order by c.ad), '[]'::jsonb)
      from (select * from oyun.oda_uye where aktif and (v_il = 0 or il_id = v_il) order by sirket_id limit 150) m join oyun.sirketler c on c.id = m.sirket_id),
    'iller', (select coalesce(jsonb_agg(jsonb_build_object('il_id', x.il_id, 'ad', oyun.oda_ad(x.il_id), 'uye', x.n,
        'baskan', (select oyun.kad(od.baskan) from oyun.oda od where od.il_id = x.il_id)) order by x.n desc, x.il_id), '[]'::jsonb)
      from (select m.il_id, count(*) n from oyun.oda_uye m where m.aktif group by m.il_id) x),
    'sendikalar', (select coalesce(jsonb_agg(jsonb_build_object('id', sd.id, 'ad', sd.ad, 'amac', sd.amac, 'baskan', oyun.kad(sd.baskan), 'aidat', sd.aidat,
        'uye', (select count(*) from oyun.sendika_uye su where su.sendika_id = sd.id),
        'konum', case when sd.id = (select od.baskan_sendika from oyun.oda od where od.il_id = 0) then 'yonetim' else 'muhalefet' end)
        order by (select count(*) from oyun.sendika_uye su where su.sendika_id = sd.id) desc, sd.id), '[]'::jsonb)
      from oyun.sendika sd where not sd.kapali));
end $$;

create or replace function public.oda_aday_ol(p_il integer, p_vaat text, p_sendika bigint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.oda_secim; v text; sen bigint;
begin
  perform oyun.yazabilir_mi(p, t);
  select * into s from oyun.oda_secim where il_id = p_il::smallint and durum = 'aday' order by id desc limit 1 for update;
  if s.id is null then raise exception 'Bu odada şu an adaylık dönemi açık değil.'; end if;
  if not oyun.oda_temsilci(p.id, s.il_id) then
    raise exception '%', case when s.il_id = 0 then 'Aday olmak için bir ticaret odasına üye faal bir şirketin yöneticisi olmalısın.'
                              else 'Aday olmak için bu odaya üye faal bir şirketin yöneticisi olmalısın.' end;
  end if;
  if exists (select 1 from oyun.oda od where od.baskan = p.id and od.il_id <> s.il_id) then raise exception 'Başka bir odanın başkanıyken aday olamazsın.'; end if;
  if exists (select 1 from oyun.oda_aday a join oyun.oda_secim x on x.id = a.secim_id and x.durum in ('aday','oy') where a.user_id = p.id and not a.cekildi and x.il_id <> s.il_id) then
    raise exception 'Aynı anda yalnız bir oda seçiminde aday olabilirsin.'; end if;
  v := oyun.metin_ops(p_vaat, 600);
  if char_length(v) < 10 then raise exception 'Seçim vaadini en az 10 karakterle yaz.'; end if;
  select su.sendika_id into sen from oyun.sendika_uye su join oyun.sendika sd on sd.id = su.sendika_id and not sd.kapali
   where oyun.sirket_yonetici_mi(su.sirket_id, p.id) and (p_sendika is null or su.sendika_id = p_sendika)
   order by (sd.baskan = p.id) desc, su.katilim limit 1;
  if p_sendika is not null and sen is null then raise exception 'Yalnız şirketinin üye olduğu sendikanın adayı olabilirsin.'; end if;
  insert into oyun.oda_aday(secim_id, user_id, sendika_id, vaat, zaman) values (s.id, p.id, sen, v, t)
    on conflict (secim_id, user_id) do update set cekildi = false, vaat = excluded.vaat, sendika_id = excluded.sendika_id;
  perform oyun.olay('ekonomi', format('%s, %s başkanlığına aday oldu%s.', p.kad, oyun.oda_ad(s.il_id),
    coalesce(' (' || (select ad from oyun.sendika where id = sen) || ')', '')), case when s.il_id = 0 then null else s.il_id end, null, t);
  return public.oda_panel(s.il_id);
end $$;

create or replace function public.oda_aday_cekil(p_il integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.oda_secim;
begin
  select * into s from oyun.oda_secim where il_id = p_il::smallint and durum in ('aday','oy') order by id desc limit 1;
  if s.id is null then raise exception 'Açık seçim yok.'; end if;
  update oyun.oda_aday set cekildi = true where secim_id = s.id and user_id = p.id and not cekildi;
  if not found then raise exception 'Bu seçimde aday değilsin.'; end if;
  delete from oyun.oda_oy where secim_id = s.id and aday = p.id;
  return public.oda_panel(s.il_id);
end $$;

-- p_sirket boşsa oy hakkı olan bütün şirketlerim için
create or replace function public.oda_oy_ver(p_il integer, p_aday text, p_sirket bigint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.oda_secim; h oyun.profiller; r record; n int := 0; borclu int := 0;
begin
  select * into s from oyun.oda_secim where il_id = p_il::smallint and durum = 'oy' order by id desc limit 1;
  if s.id is null then raise exception 'Bu odada şu an oylama yok.'; end if;
  if t >= s.oy_son then raise exception 'Oylama süresi doldu.'; end if;
  h := oyun.profil_bul(p_aday);
  if not exists (select 1 from oyun.oda_aday a where a.secim_id = s.id and a.user_id = h.id and not a.cekildi) then raise exception 'Bu oyuncu seçimde aday değil.'; end if;
  for r in select m.sirket_id, m.aidat_borc from oyun.oda_uye m join oyun.sirketler c on c.id = m.sirket_id and c.aktif
            where m.aktif and (s.il_id = 0 or m.il_id = s.il_id) and (p_sirket is null or m.sirket_id = p_sirket) and oyun.sirket_yonetici_mi(c.id, p.id) loop
    if r.aidat_borc > 0 then borclu := borclu + 1; continue; end if;
    insert into oyun.oda_oy(secim_id, sirket_id, aday, oy_veren, zaman) values (s.id, r.sirket_id, h.id, p.id, t)
      on conflict (secim_id, sirket_id) do update set aday = excluded.aday, oy_veren = excluded.oy_veren, zaman = excluded.zaman;
    n := n + 1;
  end loop;
  if n = 0 then
    raise exception '%', case when borclu > 0 then 'Aidat borcu olan şirket oy kullanamaz. Önce aidat borcunu öde.'
                              else 'Bu seçimde oy kullanabileceğin (yöneticisi olduğun, odaya üye) bir şirketin yok.' end;
  end if;
  return public.oda_panel(s.il_id) || jsonb_build_object('oy_sayisi', n, 'borclu_atlanan', borclu);
end $$;

create or replace function public.oda_aidat_ode(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x numeric; m oyun.oda_uye;
begin
  if not oyun.sirket_yonetici_mi(p_sirket, p.id) then raise exception 'Bu şirketin yöneticisi değilsin.'; end if;
  select * into m from oyun.oda_uye where sirket_id = p_sirket and aktif;
  if m.sirket_id is null or m.aidat_borc <= 0 then raise exception 'Bu şirketin aidat borcu yok.'; end if;
  x := oyun.oda_aidat_tahsil(p_sirket, false);
  if x <= 0 then raise exception 'Şirket kasasında aidat borcunu ödeyecek para yok.'; end if;
  return jsonb_build_object('tamam', true, 'odenen', x, 'kalan', (select aidat_borc from oyun.oda_uye where sirket_id = p_sirket));
end $$;

create or replace function public.oda_erken_secim_imza(p_il integer, p_sirket bigint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); o oyun.oda; v_il smallint := p_il::smallint; n int := 0; sayi int; uye int;
begin
  select * into o from oyun.oda where il_id = v_il for update;
  if o.il_id is null then raise exception 'Oda bulunamadı.'; end if;
  if o.baskan is null then raise exception 'Odanın başkanı yok; seçim zaten açılacak.'; end if;
  if o.baskan_bas > t - interval '5 days' then raise exception 'Başkan göreve geleli 5 gün olmadan erken seçim istenemez.'; end if;
  if exists (select 1 from oyun.oda_secim where il_id = v_il and durum in ('aday','oy')) then raise exception 'Zaten açık bir seçim var.'; end if;
  insert into oyun.oda_imza(il_id, sirket_id, imzalayan, zaman)
    select v_il, m.sirket_id, p.id, t from oyun.oda_uye m join oyun.sirketler c on c.id = m.sirket_id and c.aktif
     where m.aktif and (v_il = 0 or m.il_id = v_il) and (p_sirket is null or m.sirket_id = p_sirket) and oyun.sirket_yonetici_mi(c.id, p.id)
    on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'İmza atabileceğin yeni bir şirket yok (zaten imzaladın ya da bu odaya üye şirketin yok).'; end if;
  uye := oyun.oda_uye_sayisi(v_il);
  select count(*) into sayi from oyun.oda_imza z join oyun.oda_uye m on m.sirket_id = z.sirket_id and m.aktif where z.il_id = v_il;
  if sayi > uye / 2 then
    perform oyun.oda_secim_ac(v_il, 'üyelerin çoğunluğu erken seçim istedi');
    perform oyun.olay('ekonomi', format('%s üyelerinin çoğunluğu erken seçim istedi; başkanlık seçimi açıldı.', oyun.oda_ad(v_il)), case when v_il = 0 then null else v_il end, null, t);
  end if;
  return public.oda_panel(v_il) || jsonb_build_object('imzalanan', n, 'secim_acildi', sayi > uye / 2);
end $$;

-- Başkan icraatları
create or replace function public.oda_icraat(p_il integer, p_tur text, p_tutar numeric default null, p_metin text default null, p_hedef integer default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); o oyun.oda; v_il smallint := p_il::smallint; m numeric := round(coalesce(p_tutar, 0));
  n int; pay numeric; r record; gel numeric; mem numeric; say int; baslik text; metin text; kdv numeric;
begin
  select * into o from oyun.oda where il_id = v_il for update;
  if o.il_id is null or o.baskan is distinct from p.id then raise exception 'Bu işlemi yalnız oda başkanı yapabilir.'; end if;
  if p_tur = 'aidat' then
    if v_il = 0 then raise exception 'Aidatı il odaları belirler; Birlik aidatların %%25''ini alır.'; end if;
    if m < 500 or m > 25000 then raise exception 'Haftalık aidat 500 ₺ ile 25.000 ₺ arasında olmalı.'; end if;
    if o.aidat_degisim > t - interval '7 days' then raise exception 'Aidat haftada bir kez değiştirilebilir.'; end if;
    update oyun.oda set aidat = m, aidat_degisim = t where il_id = v_il;
    insert into oyun.oda_icraat(il_id, tur, baslik, tutar, yapan, zaman) values (v_il, 'aidat', format('Haftalık aidat %s ₺ olarak belirlendi', oyun.tl(m)), 0, p.id, t);
    perform oyun.oda_duyur(v_il, format('%s haftalık aidatı %s ₺ olarak belirledi (önceki %s ₺).', oyun.oda_ad(v_il), oyun.tl(m), oyun.tl(o.aidat)), t);
    return public.oda_panel(v_il);
  elsif p_tur = 'rapor' then
    perform oyun.yazabilir_mi(p, t);
    metin := oyun.metin_ops(p_metin, 1500);
    if char_length(metin) < 20 then raise exception 'Açıklama en az 20 karakter olmalı.'; end if;
    if exists (select 1 from oyun.oda_icraat where il_id = v_il and tur = 'rapor' and zaman > t - interval '24 hours') then raise exception 'Günde bir açıklama yayımlanabilir.'; end if;
    insert into oyun.oda_icraat(il_id, tur, baslik, tutar, yapan, zaman, detay) values (v_il, 'rapor', 'Başkanlık açıklaması', 0, p.id, t, jsonb_build_object('metin', metin));
    perform oyun.olay('ekonomi', format('%s Başkanı %s: "%s"', oyun.oda_ad(v_il), p.kad, left(metin, 220)), case when v_il = 0 then null else v_il end, null, t);
    return public.oda_panel(v_il);
  end if;
  if m <= 0 or m > o.kasa then raise exception 'Oda kasasında yeterli para yok (kasa % ₺).', oyun.tl(o.kasa); end if;
  if p_tur = 'destek' then
    if m < 10000 then raise exception 'Destek fonu en az 10.000 ₺ olmalı.'; end if;
    select count(*) into n from oyun.oda_uye u join oyun.sirketler c on c.id = u.sirket_id and c.aktif where u.aktif and u.aidat_borc <= 0 and (v_il = 0 or u.il_id = v_il);
    if n = 0 then raise exception 'Aidat borcu olmayan üye şirket yok.'; end if;
    pay := floor(m / n);
    if pay < 100 then raise exception 'Şirket başına düşen tutar çok küçük; fonu büyüt.'; end if;
    for r in select u.sirket_id from oyun.oda_uye u join oyun.sirketler c on c.id = u.sirket_id and c.aktif where u.aktif and u.aidat_borc <= 0 and (v_il = 0 or u.il_id = v_il) order by u.sirket_id loop
      perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(r.sirket_id::text));
      update oyun.sirketler set kasa = kasa + pay where id = r.sirket_id;
      insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
        values (r.sirket_id, t, pay, oyun.oda_ad(v_il) || ' üye destek fonu', 0, 0, 0);
    end loop;
    m := pay * n; baslik := format('Üye destek fonu: %s şirkete %s''er ₺', n, oyun.tl(pay));
    perform oyun.oda_duyur(v_il, format('%s üye destek fonu dağıttı: aidat borcu olmayan her şirketin kasasına %s ₺ yatırıldı.', oyun.oda_ad(v_il), oyun.tl(pay)), t);
  elsif p_tur = 'il_destek' then
    if v_il <> 0 then raise exception 'İl odalarına kaynağı yalnız Birlik başkanı aktarır.'; end if;
    if m < 10000 or not exists (select 1 from oyun.oda where il_id = p_hedef::smallint and il_id <> 0) then raise exception 'Geçerli bir il odası ve en az 10.000 ₺ gir.'; end if;
    update oyun.oda set kasa = kasa + m where il_id = p_hedef::smallint;
    insert into oyun.oda_hareket(il_id, zaman, tutar, tur, aciklama, user_id) values (p_hedef::smallint, t, m, 'birlik_destegi', 'Türkiye Odalar Birliği kaynak aktarımı', p.id);
    baslik := format('%s''na %s ₺ kaynak aktarıldı', oyun.oda_ad(p_hedef::smallint), oyun.tl(m));
    perform oyun.oda_duyur(p_hedef::smallint, format('Türkiye Odalar Birliği, %s kasasına %s ₺ kaynak aktardı.', oyun.oda_ad(p_hedef::smallint), oyun.tl(m)), t);
  elsif p_tur in ('fuar', 'egitim') then
    if exists (select 1 from oyun.oda_icraat where il_id = v_il and tur = p_tur and zaman > t - interval '48 hours') then
      raise exception 'Aynı tür organizasyon 48 saatte bir yapılabilir.'; end if;
    if v_il = 0 then
      if p_tur <> 'fuar' then raise exception 'Birlik yalnız Türkiye geneli fuar düzenler; eğitimi il odaları yapar.'; end if;
      if m < 500000 or m > 10000000 then raise exception 'Türkiye geneli fuar bütçesi 500.000 ₺ ile 10.000.000 ₺ arasında olmalı.'; end if;
      gel := round(least(0.30, m / 2000000 * 0.15), 3);
      update oyun.il_durum d set gelisim = least(100, coalesce(d.gelisim, 50) + gel)
       where exists (select 1 from oyun.oda_uye u where u.aktif and u.il_id = d.il_id);
      get diagnostics say = row_count;
      baslik := format('Türkiye Ticaret Fuarı: üyesi olan %s ilde gelişim +%s', say, gel);
    else
      if m < 50000 or m > 2000000 then raise exception 'Bütçe 50.000 ₺ ile 2.000.000 ₺ arasında olmalı.'; end if;
      select count(*) into say from oyun.oda_icraat where il_id = v_il and tur in ('fuar','egitim') and zaman > t - interval '7 days';
      if p_tur = 'fuar' then gel := least(0.60, m / 500000 * 0.30); mem := gel / 3;
      else mem := least(0.60, m / 400000 * 0.30); gel := mem / 3; end if;
      gel := round(gel / (1 + 0.5 * say), 3); mem := round(mem / (1 + 0.5 * say), 3);
      update oyun.il_durum set gelisim = least(100, coalesce(gelisim, 50) + gel), memnuniyet = least(100, coalesce(memnuniyet, 50) + mem) where il_id = v_il;
      baslik := format('%s: il gelişimi +%s, memnuniyet +%s', case when p_tur = 'fuar' then 'Ticaret fuarı' else 'Mesleki eğitim programı' end, gel, mem);
    end if;
    kdv := round(m * 0.20);
    perform oyun.hazine_kaydet('dolayli_vergi', kdv / oyun.pazar_tl_milyar(), oyun.oda_ad(v_il) || ' organizasyon KDV''si');
    perform oyun.olay('ekonomi', format('%s %s düzenledi (bütçe %s ₺).', oyun.oda_ad(v_il),
      case when p_tur = 'fuar' then case when v_il = 0 then 'Türkiye Ticaret Fuarı' else 'ticaret fuarı' end else 'mesleki eğitim programı' end, oyun.tl(m)),
      case when v_il = 0 then null else v_il end, null, t);
  else
    raise exception 'Geçersiz icraat türü.';
  end if;
  update oyun.oda set kasa = kasa - m, toplam_harcama = toplam_harcama + m where il_id = v_il;
  insert into oyun.oda_hareket(il_id, zaman, tutar, tur, aciklama, user_id) values (v_il, t, -m, p_tur, baslik, p.id);
  insert into oyun.oda_icraat(il_id, tur, baslik, tutar, yapan, zaman, detay) values (v_il, p_tur, baslik, m, p.id, t, jsonb_build_object('hedef', p_hedef));
  return public.oda_panel(v_il);
end $$;

-- ---------------------------------------------------------------- işveren sendikaları
create or replace function public.sendika_panel(p_sendika bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); sd oyun.sendika; uyeyim boolean;
begin
  select * into sd from oyun.sendika where id = p_sendika;
  if sd.id is null then raise exception 'Sendika bulunamadı.'; end if;
  uyeyim := exists (select 1 from oyun.sendika_uye su where su.sendika_id = sd.id and oyun.sirket_yonetici_mi(su.sirket_id, p.id));
  return jsonb_build_object('id', sd.id, 'ad', sd.ad, 'amac', sd.amac, 'kapali', sd.kapali, 'baskan', oyun.sm_kisi(sd.baskan), 'kurucu', oyun.kad(sd.kurucu),
    'kurulus', sd.kurulus, 'aidat', sd.aidat, 'kasa', case when uyeyim then round(sd.kasa) end, 'baskanim', sd.baskan = p.id, 'uyeyim', uyeyim,
    'konum', case when sd.id = (select od.baskan_sendika from oyun.oda od where od.il_id = 0) then 'yonetim' else 'muhalefet' end,
    'odalar', (select coalesce(jsonb_agg(oyun.oda_ad(od.il_id) order by od.il_id), '[]'::jsonb) from oyun.oda od where od.baskan_sendika = sd.id),
    'uyeler', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ad', c.ad, 'yonetici', oyun.kad(oyun.sirket_sorumlu(c.id)),
        'il', (select i.ad from oyun.oda_uye m join oyun.iller i on i.id = m.il_id where m.sirket_id = c.id), 'benim', oyun.sirket_yonetici_mi(c.id, p.id)) order by su.katilim), '[]'::jsonb)
      from oyun.sendika_uye su join oyun.sirketler c on c.id = su.sirket_id where su.sendika_id = sd.id),
    'sirketlerim', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ad', c.ad, 'kasa', round(c.kasa),
        'sendika_id', (select su.sendika_id from oyun.sendika_uye su where su.sirket_id = c.id)) order by c.ad), '[]'::jsonb)
      from oyun.oda_uye m join oyun.sirketler c on c.id = m.sirket_id and c.aktif where m.aktif and oyun.sirket_yonetici_mi(c.id, p.id)),
    'bildiriler', (select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'tur', b.tur, 'oda', oyun.oda_ad(b.il_id), 'baslik', b.baslik, 'metin', b.metin, 'zaman', b.zaman,
        'yazar', oyun.kad(b.yazar), 'tutar', round(b.tutar)) order by b.id desc), '[]'::jsonb)
      from (select * from oyun.sendika_bildiri where sendika_id = sd.id and not silindi order by id desc limit 20) b),
    'hareketler', case when uyeyim then (select coalesce(jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', round(h.tutar), 'aciklama', h.aciklama) order by h.id desc), '[]'::jsonb)
      from (select * from oyun.sendika_hareket where sendika_id = sd.id order by id desc limit 20) h) else '[]'::jsonb end);
end $$;

create or replace function public.sendika_kur(p_sirket bigint, p_ad text, p_amac text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
  a text; am text; v_kasa numeric; i bigint; harc numeric := 50000;
begin
  perform oyun.yazabilir_mi(p, t);
  perform oyun.oda_uye_esitle();
  if not oyun.sirket_yonetici_mi(p_sirket, p.id) or not exists (select 1 from oyun.oda_uye where sirket_id = p_sirket and aktif) then
    raise exception 'Sendikayı, ticaret odasına kayıtlı faal bir şirketin yöneticisi kurabilir.'; end if;
  if exists (select 1 from oyun.sendika_uye where sirket_id = p_sirket) then raise exception 'Bu şirket zaten bir sendikaya üye. Önce ayrıl.'; end if;
  if exists (select 1 from oyun.sendika where baskan = p.id and not kapali) then raise exception 'Zaten bir sendikanın başkanısın.'; end if;
  a := oyun.metin_ops(p_ad, 60); am := oyun.metin_ops(p_amac, 300);
  if char_length(a) < 4 then raise exception 'Sendika adı en az 4 karakter olmalı.'; end if;
  if exists (select 1 from oyun.sendika where lower(ad) = lower(a) and not kapali) then raise exception 'Bu adla bir sendika var.'; end if;
  perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(p_sirket::text));
  select s.kasa into v_kasa from oyun.sirketler s where s.id = p_sirket and s.aktif for update;
  if coalesce(v_kasa, 0) < harc then raise exception 'Kuruluş harcı % ₺ şirket kasasından ödenir; kasada % ₺ var.', oyun.tl(harc), oyun.tl(coalesce(v_kasa, 0)); end if;
  update oyun.sirketler set kasa = kasa - harc where id = p_sirket;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (p_sirket, t, -harc, 'İşveren sendikası kuruluş harcı: ' || a, 0, 0, 0);
  perform oyun.hazine_kaydet('diger_gelir', harc / oyun.pazar_tl_milyar(), 'İşveren sendikası kuruluş harcı');
  insert into oyun.sendika(ad, amac, kurucu, baskan, kurulus) values (a, nullif(am, ''), p.id, p.id, t) returning id into i;
  insert into oyun.sendika_uye(sirket_id, sendika_id, katilim, aidat_son) values (p_sirket, i, t, bugun);
  perform oyun.olay('ekonomi', format('%s, "%s" işveren sendikasını kurdu.', p.kad, a), null, null, t);
  return public.sendika_panel(i);
end $$;

create or replace function public.sendika_katil(p_sendika bigint, p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); sd oyun.sendika;
begin
  select * into sd from oyun.sendika where id = p_sendika and not kapali;
  if sd.id is null then raise exception 'Sendika bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(p_sirket, p.id) or not exists (select 1 from oyun.oda_uye where sirket_id = p_sirket and aktif) then
    raise exception 'Yalnız yöneticisi olduğun, odaya kayıtlı faal bir şirketi üye yapabilirsin.'; end if;
  if exists (select 1 from oyun.sendika_uye where sirket_id = p_sirket) then raise exception 'Bu şirket zaten bir sendikaya üye. Önce ayrıl.'; end if;
  insert into oyun.sendika_uye(sirket_id, sendika_id, katilim, aidat_son) values (p_sirket, sd.id, t, (t at time zone 'Europe/Istanbul')::date);
  if sd.baskan is not null and sd.baskan <> p.id then
    perform oyun.bildir(sd.baskan, format('%s şirketi %s sendikasına üye oldu.', (select ad from oyun.sirketler where id = p_sirket), sd.ad), t); end if;
  return public.sendika_panel(sd.id);
end $$;

create or replace function public.sendika_ayril(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); sid bigint;
begin
  if not oyun.sirket_yonetici_mi(p_sirket, p.id) then raise exception 'Bu şirketin yöneticisi değilsin.'; end if;
  delete from oyun.sendika_uye where sirket_id = p_sirket returning sendika_id into sid;
  if sid is null then raise exception 'Bu şirket bir sendikaya üye değil.'; end if;
  perform oyun.oda_tick();
  return jsonb_build_object('tamam', true, 'sendika_id', sid);
end $$;

-- Başkan işlemleri: aidat | bildiri | kampanya | devret
create or replace function public.sendika_islem(p_sendika bigint, p_islem text, p_veri jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); sd oyun.sendika; v_il smallint; b text; m text; x numeric; h oyun.profiller; kdv numeric;
begin
  select * into sd from oyun.sendika where id = p_sendika and not kapali for update;
  if sd.id is null or sd.baskan is distinct from p.id then raise exception 'Bu işlemi yalnız sendika başkanı yapabilir.'; end if;
  if p_islem = 'aidat' then
    x := round(coalesce((p_veri->>'aidat')::numeric, -1));
    if x < 0 or x > 10000 then raise exception 'Haftalık sendika aidatı 0 ile 10.000 ₺ arasında olmalı.'; end if;
    update oyun.sendika set aidat = x where id = sd.id;
  elsif p_islem in ('bildiri', 'kampanya') then
    perform oyun.yazabilir_mi(p, t);
    v_il := coalesce((p_veri->>'il')::int, 0)::smallint;
    if not exists (select 1 from oyun.oda where il_id = v_il) then raise exception 'Oda bulunamadı.'; end if;
    b := oyun.metin_ops(p_veri->>'baslik', 90); m := oyun.metin_ops(p_veri->>'metin', 1500);
    if char_length(b) < 4 or char_length(m) < 20 then raise exception 'Başlık en az 4, metin en az 20 karakter olmalı.'; end if;
    if exists (select 1 from oyun.sendika_bildiri where sendika_id = sd.id and tur = p_islem and zaman > t - interval '24 hours') then
      raise exception 'Sendika günde bir % yayımlayabilir.', case when p_islem = 'bildiri' then 'bildiri' else 'kampanya' end; end if;
    x := 0;
    if p_islem = 'kampanya' then
      x := round(coalesce((p_veri->>'tutar')::numeric, 0));
      if x < 25000 then raise exception 'Kampanya bütçesi en az 25.000 ₺ olmalı.'; end if;
      if x > sd.kasa then raise exception 'Sendika kasasında yeterli para yok (kasa % ₺).', oyun.tl(sd.kasa); end if;
      kdv := round(x * 0.20);
      update oyun.sendika set kasa = kasa - x where id = sd.id;
      insert into oyun.sendika_hareket(sendika_id, zaman, tutar, tur, aciklama, user_id) values (sd.id, t, -x, 'kampanya', b, p.id);
      perform oyun.hazine_kaydet('dolayli_vergi', kdv / oyun.pazar_tl_milyar(), sd.ad || ' kampanya KDV''si');
      perform oyun.oda_duyur(v_il, format('%s sendikasından %s üyelerine: "%s" — %s', sd.ad, oyun.oda_ad(v_il), b, left(m, 300)), t);
    end if;
    insert into oyun.sendika_bildiri(sendika_id, il_id, yazar, tur, baslik, metin, tutar, zaman) values (sd.id, v_il, p.id, p_islem, b, m, x, t);
    perform oyun.olay('ekonomi', format('%s sendikası (%s): "%s"', sd.ad, oyun.oda_ad(v_il), b), case when v_il = 0 then null else v_il end, null, t);
  elsif p_islem = 'devret' then
    h := oyun.profil_bul(p_veri->>'kad');
    if h.id = p.id or not exists (select 1 from oyun.sendika_uye su where su.sendika_id = sd.id and oyun.sirket_yonetici_mi(su.sirket_id, h.id)) then
      raise exception 'Başkanlık yalnız üye bir şirketin yöneticisine devredilebilir.'; end if;
    if exists (select 1 from oyun.sendika where baskan = h.id and not kapali) then raise exception 'Bu oyuncu zaten bir sendikanın başkanı.'; end if;
    update oyun.sendika set baskan = h.id where id = sd.id;
    perform oyun.bildir(h.id, format('%s sendikasının başkanlığı sana devredildi.', sd.ad), t);
  else
    raise exception 'Geçersiz işlem.';
  end if;
  return public.sendika_panel(sd.id);
end $$;

-- ---------------------------------------------------------------- ünvan, yetki, zamanlayıcı
do $u$
declare d text; y text; ek text := E'    (select case when od.il_id = 0 then ''Türkiye Odalar Birliği Başkanı'' else (select i.ad from oyun.iller i where i.id = od.il_id) || '' Ticaret Odası Başkanı'' end\n       from oyun.oda od where od.baskan = u order by od.il_id limit 1),\n';
begin
  d := pg_get_functiondef('oyun.unvan(uuid)'::regprocedure);
  if position('Ticaret Odası Başkanı' in d) > 0 then return; end if;
  y := replace(d, E'    oyun.gby_unvan(u)\n', ek || E'    oyun.gby_unvan(u)\n');
  if y = d then raise notice '196: oyun.unvan beklenen biçimde değil; oda başkanı ünvanı eklenmedi'; return; end if;
  execute y;
exception when others then raise notice '196: ünvan yaması atlandı: %', sqlerrm;
end $u$;

revoke all on function oyun.sirket_merkez_il(bigint), oyun.sirket_sorumlu(bigint), oyun.oda_ad(smallint), oyun.oda_temsilci(uuid, smallint), oyun.oda_uye_sayisi(smallint),
  oyun.oda_duyur(smallint, text, timestamptz), oyun.oda_uye_esitle(), oyun.oda_aidat_tahsil(bigint, boolean), oyun.oda_aidat_isle(),
  oyun.oda_secim_ac(smallint, text), oyun.oda_secim_isle(), oyun.oda_tick() from public, anon, authenticated;
do $g$ declare f text; begin
  foreach f in array array['oda_panel(integer)','oda_aday_ol(integer,text,bigint)','oda_aday_cekil(integer)','oda_oy_ver(integer,text,bigint)','oda_aidat_ode(bigint)',
    'oda_erken_secim_imza(integer,bigint)','oda_icraat(integer,text,numeric,text,integer)','sendika_panel(bigint)','sendika_kur(bigint,text,text)',
    'sendika_katil(bigint,bigint)','sendika_ayril(bigint)','sendika_islem(bigint,text,jsonb)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $g$;

select oyun.oda_uye_esitle();

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, sira, periyot_dk, ofset_dk, komut, aktif)
    values ('ticaret_odasi', 81, 10, 3, 'select oyun.oda_tick()', true)
    on conflict (adim) do nothing;
  end if;
exception when others then raise notice 'ticaret_odasi zamanlanamadı: %', sqlerrm;
end $z$;
