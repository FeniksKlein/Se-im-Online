-- 25.11.2026 — YÜK HIZLANDIRMA (canlıda 25.11 akşamı uygulanan migration'ların depo eşitlemesi)
--
-- Neden: 25.11 akşamı ~150 çevrimiçi oyuncuda sunucu işlemcisi doldu; seçim saatlerinde (22.00, 22.30)
-- bütün istemciler aynı saniyede ana ekranı yenileyince oyun 7 dakika yanıt veremedi.
-- Bu dosya en pahalı okuma yollarını ucuzlatır. Oyuncu verisine dokunmaz; yalnız okuma işlevleri,
-- üç küçük önbellek tablosu, üç dizin ve dakikalık üç yenileme işi ekler.
--
--  1) Kürsü gündemi: herkese ortak kısım dakikada bir hesaplanır (eskiden her açılışta kişi x paylaşım taraması, ~3 sn).
--  2) Kürsü akışı: "Sana özel" puanı önbellekten; sayfanın JSON'u tek sorguda; sekmeler zaman dizininden.
--  3) Sohbet: kanalın son 40 mesajı dizinden; "okundu" satırı yalnız ilerleyince yazılır.
--  4) Unvan: her mesaj/paylaşım için 10 ayrı sorgu yerine dakikalık önbellek (bayatsa eski canlı hesap).
--
-- SIRA: listenin SONUNDA kalmalı. sohbet_oku, kursu_akis, kursu_gundem ve oyun.unvan'ı yeniden yazan
-- dosyalardan sonra gelir; yoksa eski (yavaş) gövdeler geri döner.
-- oyun.unvan'ın asıl hesabı değişirse yalnız eski yerinde (52_gby_gorev_miting_tepki.sql) değiştirin:
-- bu dosya o gövdeyi her kurulumda oyun.unvan_hesap adına kopyalar.

set local check_function_bodies = off;

-- ---------- Önbellek tabloları ----------
create table if not exists oyun.kursu_gundem_onbellek (
  id smallint primary key default 1 check (id = 1),
  zaman timestamptz not null default now(),
  veri jsonb not null
);
create table if not exists oyun.kursu_skor_onbellek (
  akis_id bigint primary key,
  taban integer not null
);
create table if not exists oyun.unvan_onbellek (
  user_id uuid primary key,
  unvan text not null
);
create table if not exists oyun.unvan_onbellek_durum (
  id smallint primary key default 1 check (id = 1),
  zaman timestamptz not null
);
alter table oyun.kursu_gundem_onbellek enable row level security;
alter table oyun.kursu_skor_onbellek enable row level security;
alter table oyun.unvan_onbellek enable row level security;
alter table oyun.unvan_onbellek_durum enable row level security;
revoke all on oyun.kursu_gundem_onbellek, oyun.kursu_skor_onbellek, oyun.unvan_onbellek, oyun.unvan_onbellek_durum from anon, authenticated;

-- ---------- Dizinler ----------
create index if not exists akis_ust_zaman on oyun.akis (zaman desc) where (not gizli and yanit_id is null);
create index if not exists akis_ust_il_zaman on oyun.akis (il_id, zaman desc) where (not gizli and yanit_id is null);
create index if not exists akis_ust_parti_zaman on oyun.akis (parti_id, zaman desc) where (not gizli and yanit_id is null);

-- ---------- 4) Unvan önbelleği ----------
-- Asıl hesap "unvan_hesap" adına kopyalanır (gövde, o an yürürlükteki oyun.unvan'dan alınır).
do $unvan$ declare src text; begin
  select prosrc into src from pg_proc where oid = 'oyun.unvan(uuid)'::regprocedure;
  if src not like '%unvan_onbellek%' then
    execute format('create or replace function oyun.unvan_hesap(u uuid) returns text language sql stable set search_path to '''' as %L', src);
  end if;
end $unvan$;
revoke all on function oyun.unvan_hesap(uuid) from public, anon, authenticated;

create or replace function oyun.unvan_yenile()
 returns void
 language plpgsql
 set search_path to ''
as $function$
begin
  -- Unvanı olabilecek herkes (kaynak tablolarda adı geçenler); gerisi unvansızdır.
  with aday as (
    select h.basbakan id from oyun.hukumetler h where h.bit is null
    union select m.user_id from oyun.makamlar m where m.bit is null
    union select pa.gb from oyun.partiler pa where pa.gb is not null
    union select o.baskan from oyun.oda o where o.baskan is not null
    union select a.hedef from oyun.icisleri_atama a where a.tur = 'vali' and a.durum = 'aktif'
    union select g.user_id from oyun.parti_gby g
    union select s.user_id from oyun.parti_sozcu s
  ), yeni as materialized (
    select a.id, oyun.unvan_hesap(a.id) unvan from aday a where a.id is not null
  ), sil as (
    delete from oyun.unvan_onbellek c
     where not exists (select 1 from yeni y where y.id = c.user_id and y.unvan is not null)
  )
  insert into oyun.unvan_onbellek (user_id, unvan)
  select y.id, y.unvan from yeni y where y.unvan is not null
  on conflict (user_id) do update set unvan = excluded.unvan
   where oyun.unvan_onbellek.unvan is distinct from excluded.unvan;

  insert into oyun.unvan_onbellek_durum (id, zaman) values (1, now())
  on conflict (id) do update set zaman = excluded.zaman;
end $function$;
revoke all on function oyun.unvan_yenile() from public, anon, authenticated;

create or replace function oyun.unvan(u uuid)
 returns text
 language sql
 stable
 set search_path to ''
as $function$
  select case when (select d.zaman > now() - interval '5 minutes' from oyun.unvan_onbellek_durum d where d.id = 1)
              then (select c.unvan from oyun.unvan_onbellek c where c.user_id = u)
              else oyun.unvan_hesap(u) end
$function$;

-- ---------- 1) Kürsü gündemi ----------
create or replace function oyun.kursu_gundem_hesap()
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
declare v_t timestamptz := oyun.simdi(); v_bas timestamptz; v_saat integer := 48;
  v_et jsonb; v_kisi jsonb; v_parti jsonb; v_dernek jsonb;
begin
  if (select count(*) from oyun.akis where zaman > v_t - interval '48 hours' and not gizli) < 15 then v_saat := 168; end if;
  v_bas := v_t - make_interval(hours => v_saat);
  select coalesce(jsonb_agg(x order by (x->>'sayi')::int desc, (x->>'kisi')::int desc), '[]'::jsonb) into v_et from (
    select jsonb_build_object('tur', 'etiket', 'ad', '#' || e.etiket, 'anahtar', e.etiket, 'sayi', count(*), 'kisi', count(distinct e.user_id)) x
      from oyun.akis_etiket e join oyun.akis a on a.id = e.akis_id and not a.gizli
     where e.zaman > v_bas group by e.etiket order by count(*) desc, count(distinct e.user_id) desc limit 20) t;

  -- Kişiler: @anmalar paylaşımlardan tek geçişte çıkarılır; İ/I/ı/i aynı sayılır (Türkçe yazım farkı anmayı kaçırmasın).
  with u as materialized (
    select pr.id, translate(lower(translate(pr.kad, 'İI', 'ii')), 'ı', 'i') kk from oyun.profiller pr
     where not pr.yasakli and exists (select 1 from oyun.akis a where a.user_id = pr.id and a.zaman > v_t - interval '30 days')
  ), anilan as materialized (
    select distinct a.id akis_id, a.user_id, translate(lower(translate(m.m[1], 'İI', 'ii')), 'ı', 'i') tok
      from oyun.akis a cross join lateral regexp_matches(a.metin, '@([[:alnum:]_]+)', 'g') m(m)
     where a.zaman > v_bas and not a.gizli and a.metin like '%@%'
  ), anma as (
    select u.id, count(*) n from u join anilan t on t.tok = u.kk and t.user_id <> u.id group by u.id
  ), yanit as (
    select a.user_id id, count(*) n from oyun.akis r join oyun.akis a on a.id = r.yanit_id
     where r.zaman > v_bas and not r.gizli and r.user_id <> a.user_id group by a.user_id
  ), yp as (
    select a.user_id id, count(*) n from oyun.kursu_yp y join oyun.akis a on a.id = y.akis_id
     where y.zaman > v_bas and y.user_id <> a.user_id group by a.user_id
  ), begeni as (
    select a.user_id id, count(*) n from oyun.akis_begeni b join oyun.akis a on a.id = b.akis_id
     where b.zaman > v_bas group by a.user_id
  ), z as (
    select u.id, coalesce(anma.n, 0) anma, coalesce(yanit.n, 0) yanit, coalesce(yp.n, 0) yp, coalesce(begeni.n, 0) begeni
      from u left join anma on anma.id = u.id left join yanit on yanit.id = u.id left join yp on yp.id = u.id left join begeni on begeni.id = u.id
  )
  select coalesce(jsonb_agg(x order by (x->>'puan')::numeric desc), '[]'::jsonb) into v_kisi from (
    select jsonb_build_object('id', pr.id, 'tur', 'kisi', 'ad', pr.kad, 'anahtar', pr.kad, 'unvan', oyun.unvan(pr.id), 'parti', oyun.parti_json(pr.parti_id),
             'sayi', z.anma + z.yanit, 'anma', z.anma, 'puan', z.anma * 3 + z.yanit * 2 + z.yp * 2 + z.begeni) x
      from z join oyun.profiller pr on pr.id = z.id
     where z.anma * 3 + z.yanit * 2 + z.yp * 2 + z.begeni > 0
     order by z.anma * 3 + z.yanit * 2 + z.yp * 2 + z.begeni desc limit 10) t;

  -- Parti ve dernek: paylaşım metni bir kez küçük harfe çevrilir, hepsi aynı kümeden sayılır.
  with pm as materialized (
    select a.metin, lower(a.metin) lm from oyun.akis a where a.zaman > v_bas and not a.gizli
  ), pj as (
    select jsonb_build_object('tur', 'parti', 'ad', pa.ad, 'anahtar', pa.id, 'parti', oyun.parti_json(pa.id), 'sayi', c.n) x
      from oyun.partiler pa
      cross join lateral (select count(*) n from pm
                           where pm.lm like '%' || lower(pa.ad) || '%'
                              or (char_length(pa.kisa) >= 2 and pm.metin ~ ('(^|[^[:alnum:]])' || regexp_replace(pa.kisa, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g') || '($|[^[:alnum:]])'))) c
     where not pa.kapali and c.n > 0 order by c.n desc limit 8
  ), dj as (
    select jsonb_build_object('tur', 'dernek', 'ad', d.ad, 'anahtar', d.id, 'sayi', c.n) x
      from oyun.dernekler d
      cross join lateral (select count(*) n from pm where pm.lm like '%' || lower(d.ad) || '%') c
     where not coalesce(d.kapali, false) and c.n > 0 order by c.n desc limit 8
  )
  select (select coalesce(jsonb_agg(x order by (x->>'sayi')::int desc), '[]'::jsonb) from pj),
         (select coalesce(jsonb_agg(x order by (x->>'sayi')::int desc), '[]'::jsonb) from dj)
    into v_parti, v_dernek;
  return jsonb_build_object('saat', v_saat, 'etiketler', v_et, 'kisiler', v_kisi, 'partiler', v_parti, 'dernekler', v_dernek);
end $function$;

create or replace function oyun.kursu_gundem_yenile()
 returns void
 language sql
 set search_path to ''
as $function$
  insert into oyun.kursu_gundem_onbellek (id, zaman, veri) values (1, now(), oyun.kursu_gundem_hesap())
  on conflict (id) do update set zaman = excluded.zaman, veri = excluded.veri;
$function$;
revoke all on function oyun.kursu_gundem_hesap() from public, anon, authenticated;
revoke all on function oyun.kursu_gundem_yenile() from public, anon, authenticated;

create or replace function public.kursu_gundem()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); c jsonb; v_kisi jsonb;
begin
  -- Gündemin herkese ortak kısmı dakikada bir yenilenen önbellekten gelir; önbellek bayatsa canlı hesaplanır.
  select o.veri into c from oyun.kursu_gundem_onbellek o where o.id = 1 and o.zaman > now() - interval '10 minutes';
  if c is null then c := oyun.kursu_gundem_hesap(); end if;
  select coalesce(jsonb_agg((k.k - 'id') || jsonb_build_object('takip_ediyorum',
             exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = (k.k->>'id')::uuid)) order by k.n), '[]'::jsonb)
    into v_kisi from jsonb_array_elements(c->'kisiler') with ordinality k(k, n);
  return jsonb_build_object('saat', c->'saat', 'etiketler', c->'etiketler', 'kisiler', v_kisi, 'partiler', c->'partiler', 'dernekler', c->'dernekler',
    'oneriler', coalesce((select jsonb_agg(oyun.kursu_kisi_json(x.id, p.id) order by x.takipci desc, x.son desc) from (
        select u.id, (select count(*) from oyun.kursu_takip t where t.takip_edilen = u.id) takipci,
               (select max(a.zaman) from oyun.akis a where a.user_id = u.id) son
          from oyun.profiller u
         where not u.yasakli and u.id <> p.id
           and not exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = u.id)
           and not oyun.kursu_engelli(p.id, u.id)
           and exists (select 1 from oyun.akis a where a.user_id = u.id and a.zaman > v_t - interval '7 days')
         order by 2 desc, 3 desc nulls last limit 6) x), '[]'::jsonb));
end $function$;

-- ---------- 2) Kürsü akışı ----------
create or replace function oyun.kursu_skor_hesapla()
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_t timestamptz := oyun.simdi();
begin
  insert into oyun.kursu_skor_onbellek as k (akis_id, taban)
  select a.id,
         (coalesce(b.n, 0) * 2 + coalesce(y.n, 0) * 3 + coalesce(yp.n, 0) * 4 + coalesce(q.n, 0) * 3 - coalesce(bm.n, 0))::integer
    from oyun.akis a
    left join (select akis_id, count(*) n from oyun.akis_begeni group by akis_id) b on b.akis_id = a.id
    left join (select yanit_id, count(*) n from oyun.akis where yanit_id is not null and not gizli group by yanit_id) y on y.yanit_id = a.id
    left join (select akis_id, count(*) n from oyun.kursu_yp group by akis_id) yp on yp.akis_id = a.id
    left join (select alinti_id, count(*) n from oyun.akis where alinti_id is not null and not gizli group by alinti_id) q on q.alinti_id = a.id
    left join (select akis_id, count(*) n from oyun.akis_begenmeme group by akis_id) bm on bm.akis_id = a.id
   where not a.gizli and a.yanit_id is null and a.zaman > v_t - interval '8 days'
  on conflict (akis_id) do update set taban = excluded.taban where k.taban is distinct from excluded.taban;

  delete from oyun.kursu_skor_onbellek k
   where not exists (select 1 from oyun.akis a where a.id = k.akis_id and a.zaman > v_t - interval '8 days');
end $function$;
revoke all on function oyun.kursu_skor_hesapla() from public, anon, authenticated;

-- Bir sayfadaki paylaşımların tamamını tek sorguda JSON'a çevirir (kursu_json ile birebir aynı içerik).
create or replace function oyun.kursu_json_toplu(p_ids bigint[], ben uuid)
 returns table(id bigint, g jsonb)
 language sql
 stable
 set search_path to ''
as $function$
  select a.id,
    case when pr.id is null then null else
      jsonb_build_object('id', a.id, 'kad', pr.kad, 'unvan', oyun.unvan(a.user_id),
           'parti', case when pa.id is null then null else jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'amblem', pa.amblem) end,
           'il', (select i.ad from oyun.iller i where i.id = a.il_id), 'metin', a.metin, 'zaman', a.zaman, 'yanit_id', a.yanit_id,
           'begeni', (select count(*) from oyun.akis_begeni b where b.akis_id = a.id),
           'begenmeme', (select count(*) from oyun.akis_begenmeme b where b.akis_id = a.id),
           'yanit', (select count(*) from oyun.akis y where y.yanit_id = a.id and not y.gizli),
           'begendim', exists (select 1 from oyun.akis_begeni b where b.akis_id = a.id and b.user_id = ben),
           'begenmedim', exists (select 1 from oyun.akis_begenmeme b where b.akis_id = a.id and b.user_id = ben),
           'benim', a.user_id = ben)
      || jsonb_build_object(
           'kurum', case when a.kurum_tur is not null then jsonb_build_object(
             'tur', a.kurum_tur, 'kimlik', a.kurum_id, 'ad', a.kurum_ad, 'rol', a.kurum_rol) else null end,
           'yp', (select count(*) from oyun.kursu_yp y where y.akis_id = a.id),
           'ypledim', exists (select 1 from oyun.kursu_yp y where y.akis_id = a.id and y.user_id = ben),
           'alinti_sayi', (select count(*) from oyun.akis q where q.alinti_id = a.id and not q.gizli),
           'alinti', case when a.alinti_id is not null then oyun.kursu_alinti_json(a.alinti_id) end,
           'yanit_kad', case when a.yanit_id is not null then (select pr2.kad from oyun.akis u2 join oyun.profiller pr2 on pr2.id = u2.user_id where u2.id = a.yanit_id) end,
           'takip_ediyorum', exists (select 1 from oyun.kursu_takip t where t.takipci = ben and t.takip_edilen = a.user_id))
    end
  from oyun.akis a
  left join oyun.profiller pr on pr.id = a.user_id
  left join oyun.partiler pa on pa.id = a.parti_id
  where a.id = any (p_ids)
$function$;
revoke all on function oyun.kursu_json_toplu(bigint[], uuid) from public, anon, authenticated;

create or replace function public.kursu_akis(p_sekme text DEFAULT 'sana'::text, p_imlec text DEFAULT NULL::text, p_limit integer DEFAULT 20)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 40);
  v_t timestamptz := oyun.simdi(); v_once timestamptz; v_atla integer := 0; v_liste jsonb; v_eng uuid[];
  v_ids bigint[]; v_skor double precision[]; v_ts timestamptz[]; v_yp text[];
begin
  if p_sekme not in ('sana','takip','il','parti','herkes') then raise exception 'Geçersiz akış.'; end if;
  select array_agg(case when g.engelleyen = p.id then g.engellenen else g.engelleyen end) into v_eng
    from oyun.engellemeler g where g.engelleyen = p.id or g.engellenen = p.id;
  if p_sekme = 'sana' then
    v_atla := greatest(0, least(coalesce(nullif(p_imlec, '')::integer, 0), 400));
    select array_agg(x.id order by x.skor desc, x.id desc), array_agg(x.skor order by x.skor desc, x.id desc)
      into v_ids, v_skor
      from (select a.id, ((
                coalesce(k.taban, 0)
              + case when a.user_id in (select t.takip_edilen from oyun.kursu_takip t where t.takipci = p.id) then 6 else 0 end
              + case when p.parti_id is not null and a.parti_id = p.parti_id then 2 else 0 end
              + case when a.il_id = p.il_id then 1 else 0 end + 1)::double precision
              / power(date_part('epoch', v_t - a.zaman) / 3600 + 2, 1.35::double precision)) as skor
              from oyun.akis a
              left join oyun.kursu_skor_onbellek k on k.akis_id = a.id
             where not a.gizli and a.yanit_id is null and a.zaman > v_t - interval '7 days'
               and (v_eng is null or a.user_id is null or a.user_id <> all (v_eng))
             order by 2 desc, a.id desc offset v_atla limit v_lim) x;
    select coalesce(jsonb_agg(jsonb_build_object('sira', u.skor::numeric, 'yp', null, 'g', j.g) order by u.ord), '[]'::jsonb)
      into v_liste
      from unnest(v_ids, v_skor) with ordinality u(id, skor, ord)
      join oyun.kursu_json_toplu(v_ids, p.id) j on j.id = u.id;
    return jsonb_build_object('liste', v_liste, 'imlec', case when jsonb_array_length(v_liste) = v_lim then (v_atla + v_lim)::text end);
  end if;
  v_once := coalesce(nullif(p_imlec, '')::timestamptz, 'infinity'::timestamptz);
  if p_sekme = 'herkes' then
    select array_agg(s.id), array_agg(s.zaman), array_agg(null::text) into v_ids, v_ts, v_yp
      from (select a.id, a.zaman from oyun.akis a
             where not a.gizli and a.yanit_id is null and a.zaman < v_once
               and (v_eng is null or a.user_id is null or a.user_id <> all (v_eng))
             order by a.zaman desc limit v_lim) s;
  elsif p_sekme = 'il' then
    select array_agg(s.id), array_agg(s.zaman), array_agg(null::text) into v_ids, v_ts, v_yp
      from (select a.id, a.zaman from oyun.akis a
             where not a.gizli and a.yanit_id is null and a.zaman < v_once and a.il_id = p.il_id
               and (v_eng is null or a.user_id is null or a.user_id <> all (v_eng))
             order by a.zaman desc limit v_lim) s;
  elsif p_sekme = 'parti' then
    select array_agg(s.id), array_agg(s.zaman), array_agg(null::text) into v_ids, v_ts, v_yp
      from (select a.id, a.zaman from oyun.akis a
             where not a.gizli and a.yanit_id is null and a.zaman < v_once
               and p.parti_id is not null and a.parti_id = p.parti_id
               and (v_eng is null or a.user_id is null or a.user_id <> all (v_eng))
             order by a.zaman desc limit v_lim) s;
  else
    with u as (
      select a.id akis_id, a.zaman sira, null::text yp_kad from oyun.akis a
       where not a.gizli and a.yanit_id is null and a.zaman < v_once
         and (a.user_id = p.id or exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = a.user_id))
      union all
      select y.akis_id, y.zaman, pr.kad from oyun.kursu_yp y join oyun.profiller pr on pr.id = y.user_id
       where y.zaman < v_once
         and (y.user_id = p.id or exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = y.user_id))
    ), d as (
      select distinct on (akis_id) akis_id, sira, yp_kad from u order by akis_id, sira desc
    ), s as (
      select d.* from d join oyun.akis a on a.id = d.akis_id and not a.gizli
       where (v_eng is null or a.user_id is null or a.user_id <> all (v_eng)) order by d.sira desc limit v_lim
    )
    select array_agg(s.akis_id), array_agg(s.sira), array_agg(s.yp_kad) into v_ids, v_ts, v_yp from s;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('sira', u.sira, 'yp', u.yp, 'g', j.g) order by u.sira desc), '[]'::jsonb)
    into v_liste
    from unnest(v_ids, v_ts, v_yp) as u(id, sira, yp)
    join oyun.kursu_json_toplu(v_ids, p.id) j on j.id = u.id;
  return jsonb_build_object('liste', v_liste,
    'imlec', case when jsonb_array_length(v_liste) = v_lim then (v_liste -> (v_lim - 1) ->> 'sira') end);
end $function$;

-- ---------- 3) Sohbet ----------
create or replace function public.sohbet_oku(p_kanal text, p_once bigint DEFAULT NULL::bigint, p_sonra bigint DEFAULT NULL::bigint)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb; son bigint; v_t timestamptz := oyun.simdi(); v_eng uuid[]; v_gizlenen jsonb;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  -- engellenenler bir kez okunur; saat bir kez alınır (her mesaj için ayrı sorgu yok)
  v_eng := array(select g.engellenen from oyun.engellemeler g where g.engelleyen = p.id);
  if p_sonra is null then
    -- kanalın son 40 mesajı dizinden doğrudan okunur (tüm kanal taranıp sıralanmaz)
    select coalesce(jsonb_agg(jsonb_build_object('id', x.id,
              'kad', case when x.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
              'metin', x.metin, 'zaman', x.zaman,
              'parti', case when x.gorevli then null else oyun.parti_json(pr.parti_id) end,
              'unvan', case when x.gorevli then 'Oyun Yönetimi' else oyun.unvan(x.user_id) end,
              'benim', x.user_id = p.id, 'gorevli', x.gorevli,
              'silebilir', x.gorevli and (x.user_id = p.id or coalesce(p.yonetici, false)),
              'yeni', coalesce(not x.gorevli and pr.olusturma > v_t - interval '7 days', false),
              'yanit', case when x.yanit_id is not null then oyun.mesaj_alinti(p, x.yanit_id) end) order by x.id), '[]'::jsonb)
      into liste
    from (
      select * from oyun.mesajlar m
      where m.kanal = k and not m.gizli and m.zaman <= v_t and (m.gorevli or coalesce(m.user_id <> all (v_eng), true))
        and (p_once is null or m.id < p_once)
      order by m.id desc
      limit 40
    ) x left join oyun.profiller pr on pr.id = x.user_id;
  else
    select coalesce(jsonb_agg(jsonb_build_object('id', x.id,
              'kad', case when x.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
              'metin', x.metin, 'zaman', x.zaman,
              'parti', case when x.gorevli then null else oyun.parti_json(pr.parti_id) end,
              'unvan', case when x.gorevli then 'Oyun Yönetimi' else oyun.unvan(x.user_id) end,
              'benim', x.user_id = p.id, 'gorevli', x.gorevli,
              'silebilir', x.gorevli and (x.user_id = p.id or coalesce(p.yonetici, false)),
              'yeni', coalesce(not x.gorevli and pr.olusturma > v_t - interval '7 days', false),
              'yanit', case when x.yanit_id is not null then oyun.mesaj_alinti(p, x.yanit_id) end) order by x.id), '[]'::jsonb)
      into liste
    from (
      select * from oyun.mesajlar m
      where m.kanal = k and not m.gizli and m.zaman <= v_t and (m.gorevli or coalesce(m.user_id <> all (v_eng), true))
        and m.id > p_sonra and (p_once is null or m.id < p_once)
      order by m.id
      limit 100
    ) x left join oyun.profiller pr on pr.id = x.user_id;
  end if;
  if p_once is null then
    select max(id) into son from oyun.mesajlar where kanal = k and not gizli and zaman <= v_t;
    if son is not null then
      insert into oyun.kanal_okuma(user_id, kanal, son_id) values (p.id, k, son)
      on conflict (user_id, kanal) do update set son_id = greatest(oyun.kanal_okuma.son_id, excluded.son_id)
        where oyun.kanal_okuma.son_id is distinct from greatest(oyun.kanal_okuma.son_id, excluded.son_id);
    end if;
  end if;
  -- 26.11.2026: sonradan kaldırılan (gizlenen) son mesajlar; açık ekranlar bunları listeden düşer.
  -- Kısmi dizin (mesajlar_kanal_gizli) yalnız gizli satırları tutar, sorgu her yoklamada birkaç satır okur.
  select coalesce(jsonb_agg(g.id), '[]'::jsonb) into v_gizlenen
    from (select m.id from oyun.mesajlar m where m.kanal = k and m.gizli order by m.id desc limit 30) g;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste, 'yazabilir', oyun.kanal_yazabilir(p, p_kanal),
    'baslik', oyun.kanal_baslik(p, p_kanal), 'sinyal', 'sohbet:' || k,
    'gorevli_yazabilir', k = 'yardim' and oyun.yardim_gorevli_mi(p), 'resmi_yazabilir', oyun.sohbet_resmi_yazabilir(p, k), 'kanal_kod', k,
    -- 26.11.2026: sabit mesajlar (parti / yönetim / özel grup; eski sayfa yüklemesinde gönderilmez)
    'sabitler', case when p_once is null and oyun.sohbet_sabit_kanal(k) then oyun.sohbet_sabit_liste(k) end,
    'sabitleyebilir', p_once is null and oyun.sohbet_sabit_kanal(k) and oyun.sohbet_sabit_yetki(p, k),
    'gizlenen', v_gizlenen);
end $function$;

set local check_function_bodies = on;

-- ---------- İlk doldurma ve dakikalık yenileme (yalnız Supabase'de pg_cron varsa) ----------
do $ilk$
begin
  perform oyun.unvan_yenile();
  perform oyun.kursu_skor_hesapla();
  perform oyun.kursu_gundem_yenile();
exception when others then
  raise notice 'yük önbellekleri ilk doldurma atlandı: %', sqlerrm;
end $ilk$;

do $zaman$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if not exists (select 1 from cron.job where jobname = 'unvan-onbellek') then
      perform cron.schedule('unvan-onbellek', '* * * * *', 'select oyun.unvan_yenile()');
    end if;
    if not exists (select 1 from cron.job where jobname = 'kursu-skor-onbellek') then
      perform cron.schedule('kursu-skor-onbellek', '* * * * *', 'select oyun.kursu_skor_hesapla()');
    end if;
    if not exists (select 1 from cron.job where jobname = 'kursu-gundem-onbellek') then
      perform cron.schedule('kursu-gundem-onbellek', '* * * * *', 'select oyun.kursu_gundem_yenile()');
    end if;
  end if;
exception when others then
  raise notice 'yük önbelleği zamanlanamadı: %', sqlerrm;
end
$zaman$;
