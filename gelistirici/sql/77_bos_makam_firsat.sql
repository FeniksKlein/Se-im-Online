-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 77) BOŞ MAKAM FIRSAT BİLDİRİMİ
--  Boş bir belediye, milletvekili sandalyesi, genel başkanlık ya da genel başkan yardımcılığı
--  varsa ve oyuncu o işe bugün gerçekten talip olabiliyorsa, ona bildirim gider.
--   • Yalnız GERÇEK bir fırsatta: aday adaylığı açıkken ya da hemen üstlenilebilen genel başkanlıkta.
--   • Sınır: oyuncuya günde en fazla 1 fırsat bildirimi, aynı fırsat 3 günde bir, bir taramada en çok 300 kişi.
--   • Tarama 3 saatte bir, yalnız 09:00–21:59 arası (gece telefonu çalmaz).
--   • Bildirim oyuncunun "kişisel" bildirim tercihine uyar (oyun.bildir → push).
--  Gündem'deki "Fırsatlar" kartı aynı kaynaktan okur: public.bos_makam_firsatlari().
--  Yalnız yeni tablo ve işlev ekler; mevcut hiçbir şeyi değiştirmez.
-- =====================================================================

create table if not exists oyun.firsat_bildirim(
  user_id  uuid not null,
  tur      text not null,
  anahtar  text not null,
  zaman    timestamptz not null default now(),
  primary key (user_id, tur, anahtar)
);
create index if not exists firsat_bildirim_zaman on oyun.firsat_bildirim(user_id, zaman desc);
alter table oyun.firsat_bildirim enable row level security;
revoke all on oyun.firsat_bildirim from public, anon, authenticated;

create table if not exists oyun.firsat_durum(
  id boolean primary key default true check (id),
  son timestamptz
);
insert into oyun.firsat_durum(id, son) values (true, null) on conflict do nothing;
alter table oyun.firsat_durum enable row level security;
revoke all on oyun.firsat_durum from public, anon, authenticated;

-- Fırsat adayları: (oyuncu, tür, anahtar, metin, ekran). p_user doluysa yalnız o oyuncu için.
create or replace function oyun.firsat_adaylari(p_user uuid default null)
returns table(user_id uuid, tur text, anahtar text, metin text, ekran text)
language plpgsql stable as $$
declare t timestamptz := oyun.simdi(); bel oyun.secimler; mv oyun.secimler;
begin
  select * into bel from oyun.secimler s
   where s.tur = 'bel_on' and s.durum = 'bekliyor' and s.basvuru_bas <= t and s.basvuru_bit > t
   order by s.basvuru_bit limit 1;
  select * into mv from oyun.secimler s
   where s.tur = 'mv_on' and s.durum = 'bekliyor' and s.basvuru_bas <= t and s.basvuru_bit > t
   order by s.basvuru_bit limit 1;

  -- 1) Belediye başkanlığı boş ve aday adaylığı açık
  if bel.id is not null then
    return query
    select pr.id, 'belediye'::text, 'bel:' || il.id, format('%s belediye başkanlığı boş. Aday adaylığı %s tarihine kadar açık.',
             il.ad, to_char(bel.basvuru_bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), 'gundem'::text
      from oyun.profiller pr join oyun.iller il on il.id = pr.il_id
     where (p_user is null or pr.id = p_user) and not pr.yasakli
       and not exists (select 1 from oyun.makamlar m where m.tur = 'bel' and m.il_id = il.id and m.bit is null)
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur in ('mv','bel','cb'))
       and not exists (select 1 from oyun.adaylar a where a.secim_id = bel.id and a.user_id = pr.id);
  end if;

  -- 2) Milletvekili sandalyesi boş ve aday adaylığı açık
  if mv.id is not null then
    return query
    select pr.id, 'vekil'::text, 'mv:' || il.id, format('%s için %s milletvekili sandalyesi boş. Aday adaylığı %s tarihine kadar açık.',
             il.ad, il.mv_secim - c.n, to_char(mv.basvuru_bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), 'gundem'::text
      from oyun.profiller pr join oyun.iller il on il.id = pr.il_id
      cross join lateral (select count(*)::int n from oyun.makamlar m where m.tur = 'mv' and m.il_id = il.id and m.bit is null) c
     where (p_user is null or pr.id = p_user) and not pr.yasakli and il.mv_secim > c.n
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur in ('mv','bel','cb'))
       and not exists (select 1 from oyun.adaylar a where a.secim_id = mv.id and a.user_id = pr.id);
  end if;

  -- 3) Genel başkansız parti: üyeler hemen üstlenebilir
  return query
  select pr.id, 'genel_baskan'::text, 'gb:' || pa.id, format('%s genel başkansız. Genel başkanlığı hemen üstlenebilirsin.', pa.ad), 'parti'::text
    from oyun.profiller pr join oyun.partiler pa on pa.id = pr.parti_id
   where (p_user is null or pr.id = p_user) and not pr.yasakli and not pa.kapali and pa.gb is null
     and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur = 'cb');

  -- 4) Genel başkan yardımcısı kadrosu eksik: yalnız genel başkana
  return query
  select pa.gb, 'yardimci'::text, 'gby:' || pa.id, format('%s genel başkan yardımcısı kadrosunda %s yer boş. Üyelerinden atayabilirsin.', pa.ad, 6 - c.n), 'parti'::text
    from oyun.partiler pa
    cross join lateral (select count(*)::int n from oyun.parti_gby g where g.parti_id = pa.id) c
   where pa.gb is not null and not pa.kapali and c.n < 6 and (p_user is null or pa.gb = p_user)
     and (select count(*) from oyun.profiller x where x.parti_id = pa.id and x.id <> pa.gb and not x.yasakli) > c.n;
end $$;
revoke all on function oyun.firsat_adaylari(uuid) from public, anon, authenticated;

-- Tarama: kuyruğa bildirim bırakır
create or replace function oyun.bos_makam_firsat_tick() returns integer
language plpgsql set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); saat int := extract(hour from t at time zone 'Europe/Istanbul')::int; r record; n int := 0;
begin
  if saat < 9 or saat >= 22 then return 0; end if;
  if not pg_try_advisory_xact_lock(424243) then return 0; end if;
  if (select son from oyun.firsat_durum where id) > t - interval '3 hours' then return 0; end if;
  update oyun.firsat_durum set son = t where id;
  delete from oyun.firsat_bildirim where zaman < t - interval '14 days';
  for r in select * from oyun.firsat_adaylari(null) f order by random() loop
    continue when exists (select 1 from oyun.firsat_bildirim b where b.user_id = r.user_id and (b.zaman > t - interval '20 hours'
                  or (b.tur = r.tur and b.anahtar = r.anahtar and b.zaman > t - interval '3 days')));
    insert into oyun.firsat_bildirim(user_id, tur, anahtar, zaman) values (r.user_id, r.tur, r.anahtar, t)
      on conflict (user_id, tur, anahtar) do update set zaman = excluded.zaman;
    perform oyun.bildir(r.user_id, r.metin, t);
    n := n + 1; exit when n >= 300;
  end loop;
  return n;
end $$;
revoke all on function oyun.bos_makam_firsat_tick() from public, anon, authenticated;

-- Gündem kartı
create or replace function public.bos_makam_firsatlari() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('tur', f.tur, 'anahtar', f.anahtar, 'metin', f.metin, 'ekran', f.ekran) order by f.tur, f.anahtar), '[]'::jsonb)
    from oyun.firsat_adaylari(oyun.ben()) f
$$;
revoke all on function public.bos_makam_firsatlari() from public, anon;
grant execute on function public.bos_makam_firsatlari() to authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'bos-makam-firsat';
    perform cron.schedule('bos-makam-firsat', '*/30 * * * *', 'select oyun.bos_makam_firsat_tick()');
  end if;
end $$;
