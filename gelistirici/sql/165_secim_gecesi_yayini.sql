-- =====================================================================
--  165 · SEÇİM GECESİ CANLI YAYINI — sandık sandık sayım
--
--  Ne değişti:
--   • Sandıklar kapanınca (oy_bit) iki dakika içinde sayım başlar ve sonuç
--     saatinden (sonuc_at) bir dakika önce biter. Eskiden sayım sonuç
--     saatinden SONRA 12 dakikada il il açılıyordu; "Sayım sürüyor" yazısı
--     arada yarım saat boş duruyordu.
--   • Her ilin oyları sandıklara bölünür (oyun.secim_gecesi_sandik). Her
--     sandığın açılış saniyesi bellidir; bir sandık açılmadan içindeki oylar
--     hiçbir yere yazılmaz. İlin son sandığı, ilin eski plandaki açılış
--     saniyesinde açılır; eski uygulamalar il il görmeye devam eder.
--   • Yeni RPC public.secim_yayini(secim): aynı gecenin yarışları (CB + MV ya
--     da yalnız 2. tur), açılan sandık / sayılan oy, adaylar ve partiler,
--     il il durum, son açılan sandıklar, ittifaklar, müşahitler ve sonuç
--     kesinleşince resmî sonuç. Herkese aynı olan gövde, açılan sandık sayısına
--     bağlı anahtarla sunucu önbelleğinde tutulur.
--   • public.secim_yayini_tekrar(secim): sayım bittikten sonra bütün
--     sandıklar; uygulama geceyi baştan, hızlandırılmış oynatır.
--   • Bildirimler: canlı sayımda başladı / yarısı / tamamı (3 bildirim);
--     resmî "Sonuçlar açıklandı" bildirimi yine sonuç saatinde gider.
--
--  Güvenlik: oy sayımı ve motor (oyun.sonuclandir) DEĞİŞMEZ. Bu modül yalnız
--  ne zaman neyin gösterileceğini belirler. Kapatma anahtarı:
--     update oyun.secim_gecesi_ayar set canli_sayim = false;   -- eski düzen
--  Oyuncu verisine dokunmaz; tekrar çalıştırmak güvenlidir.
-- =====================================================================

alter table oyun.secim_gecesi_ayar add column if not exists canli_sayim boolean not null default true;
alter table oyun.secim_gecesi add column if not exists mod text not null default 'sonuc';
alter table oyun.secim_gecesi add column if not exists secmen jsonb;
alter table oyun.secim_gecesi add column if not exists sandik_kap int;

create table if not exists oyun.secim_gecesi_sandik(
  secim_id bigint   not null references oyun.secimler(id) on delete cascade,
  il_id    smallint not null,
  no       int      not null,             -- 1001, 1002, … (il içinde)
  sn       numeric  not null,             -- sayım başlangıcından kaç saniye sonra açılır
  oy       int      not null,
  dagilim  jsonb    not null,             -- {"p12": 3, "a45": 1}  p: parti, a: aday
  primary key (secim_id, il_id, no)
);
create index if not exists secim_gecesi_sandik_sn on oyun.secim_gecesi_sandik(secim_id, sn);
alter table oyun.secim_gecesi_sandik enable row level security;
revoke all on oyun.secim_gecesi_sandik from public, anon, authenticated;

-- Kısa ömürlü önbellek (canlıda 23.10.2026'dan beri var; temiz kurulumda yoksa kurulur)
do $kur$ begin
  if to_regclass('oyun.genel_onbellek') is null then
    create unlogged table oyun.genel_onbellek(anahtar text primary key, veri jsonb, bitis timestamptz not null);
    alter table oyun.genel_onbellek enable row level security;
    revoke all on oyun.genel_onbellek from anon, authenticated;
  end if;
  if to_regprocedure('oyun.onbellek_oku(text)') is null then
    execute $f$create function oyun.onbellek_oku(p_anahtar text) returns jsonb language sql stable set search_path to '' as
      'select g.veri from oyun.genel_onbellek g where g.anahtar = p_anahtar and g.bitis > clock_timestamp()'$f$;
  end if;
  if to_regprocedure('oyun.onbellek_yaz(text,jsonb,interval)') is null then
    execute $f$create function oyun.onbellek_yaz(p_anahtar text, p_veri jsonb, p_sure interval) returns void language plpgsql set search_path to '' as $g$
      begin
        insert into oyun.genel_onbellek(anahtar, veri, bitis) values (p_anahtar, p_veri, clock_timestamp() + p_sure)
        on conflict (anahtar) do update set veri = excluded.veri, bitis = excluded.bitis;
      exception when others then null;
      end $g$ $f$;
  end if;
end $kur$;

-- 0..1 arası sabit "rastgele" sayı (aynı girdi hep aynı sonucu verir)
create or replace function oyun.sg_zar(p text) returns numeric
language sql immutable set search_path = '' as $$
  select (('x' || substr(md5(p), 1, 8))::bit(32)::bigint & 2147483647)::numeric / 2147483648
$$;

-- Dağılım anahtarının adı: p12 → parti kısa adı, a45 → adayın kullanıcı adı
create or replace function oyun.sg_ad(p_k text) returns text
language sql stable security definer set search_path = '' as $$
  select case when p_k like 'p%' then (select coalesce(pa.kisa, pa.ad) from oyun.partiler pa where pa.id = substr(p_k, 2)::bigint)
              when p_k like 'a%' then (select pr.kad from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id where a.id = substr(p_k, 2)::bigint)
         end
$$;

-- ---------------------------------------------------------------------
-- Sandıkları kur: her ilin oyları karıştırılır ve eşit büyüklükte sandıklara
-- bölünür. İlin sandıkları, ilin plan saniyesine (son sandık) doğru açılır.
-- ---------------------------------------------------------------------
create or replace function oyun.secim_gecesi_sandik_kur(p_secim bigint) returns int
language plpgsql security definer set search_path = '' as $$
declare g oyun.secim_gecesi; kap int; adet int; mv boolean;
begin
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  mv := exists (select 1 from oyun.secimler where id = p_secim and tur = 'mv');
  if g.secim_id is null then return 0; end if;
  if exists (select 1 from oyun.secim_gecesi_sandik where secim_id = p_secim) then return 0; end if;
  perform pg_advisory_xact_lock(hashtext('secim_gecesi_sandik:' || p_secim));
  if exists (select 1 from oyun.secim_gecesi_sandik where secim_id = p_secim) then return 0; end if;
  kap := coalesce(g.sandik_kap, greatest(1, ceil(g.toplam_oy / 150.0)::int));   -- gece başına ~150 sandık

  insert into oyun.secim_gecesi_sandik(secim_id, il_id, no, sn, oy, dagilim)
  with v as (
    select o.il_id,
           -- CB oyunda aday ve partisi birlikte yazılır: CB'de aday, MV'de parti (bağımsızda aday) sayılır
           case when mv and o.parti_id is not null then 'p' || o.parti_id when o.aday_id is not null then 'a' || o.aday_id
                when o.parti_id is not null then 'p' || o.parti_id else 'x' end k,
           row_number() over (partition by o.il_id order by md5(o.secmen::text || ':' || p_secim)) - 1 r,
           count(*) over (partition by o.il_id) n
    from oyun.oylar o where o.secim_id = p_secim and o.il_id is not null
  ), b as (
    select il_id, k, ceil(n::numeric / kap)::int s, floor(r * ceil(n::numeric / kap)::int / n)::int j from v
  ), kk as (
    select il_id, s, j, k, count(*)::int c from b group by il_id, s, j, k
  ), sd as (
    select il_id, s, j, sum(c)::int oy, jsonb_object_agg(k, c) dagilim from kk group by il_id, s, j
  ), pl as (
    select (e->>'il')::int il_id, (e->>'sn')::numeric c from jsonb_array_elements(g.plan) e
  )
  select p_secim, sd.il_id, 1001 + sd.j,
         case when sd.j = sd.s - 1 then pl.c
              else round(least(pl.c - 1, greatest(8,
                     pl.c * 0.15 + pl.c * 0.85 * (sd.j + 1)::numeric / sd.s
                     + (oyun.sg_zar(p_secim || ':' || sd.il_id || ':' || sd.j) - 0.5) * 0.6 * pl.c * 0.85 / sd.s)), 1) end,
         sd.oy, sd.dagilim
  from sd join pl on pl.il_id = sd.il_id
  on conflict do nothing;
  get diagnostics adet = row_count;
  update oyun.secim_gecesi set sandik_kap = kap where secim_id = p_secim and sandik_kap is null;
  return adet;
end $$;

-- ---------------------------------------------------------------------
-- Plan: canlı düzende sayım sandık kapanınca başlar, sonuç saatinden önce biter.
-- ---------------------------------------------------------------------
create or replace function oyun.secim_gecesi_hazirla(p_secim bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare s oyun.secimler; t timestamptz := oyun.simdi(); sure int := oyun.secim_gecesi_sure(); top bigint; p jsonb;
        canli boolean; bas timestamptz; bit timestamptz; sec jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2') then return false; end if;
  if exists (select 1 from oyun.secim_gecesi where secim_id = s.id) then
    perform oyun.secim_gecesi_sandik_kur(s.id);
    return true;
  end if;
  canli := coalesce((select canli_sayim from oyun.secim_gecesi_ayar where id), true)
           and s.oy_bit is not null and s.sonuc_at - s.oy_bit >= interval '8 minutes';
  if canli then
    if t < s.oy_bit + interval '60 seconds' then return false; end if;   -- son oylar yazılsın
    bas := s.oy_bit + interval '2 minutes';
    bit := least(s.sonuc_at - interval '1 minute', bas + interval '40 minutes');
    if bit - greatest(bas, t) < interval '4 minutes' then canli := false; end if;   -- zamanlayıcı çok geç kaldı
  end if;
  if not canli then
    if t < s.oy_bit then return false; end if;
    bas := s.sonuc_at;
    -- canlıdaki eski özel durumlar korunur
    if s.tur = 'cb2' and s.donem = '2026-11' then sure := 1; end if;
    if s.id in (118267, 118269) and (s.oy_bas at time zone 'Europe/Istanbul')::date = date '2026-10-23' then sure := 900; end if;
  else
    sure := extract(epoch from bit - bas)::int;
  end if;
  perform pg_advisory_xact_lock(hashtext('secim_gecesi_hazirla:' || s.id));
  if exists (select 1 from oyun.secim_gecesi where secim_id = s.id) then return true; end if;
  select count(*) into top from oyun.oylar where secim_id = s.id and il_id is not null;
  if top = 0 then return false; end if;
  if canli then
    -- aynı büyüklükteki iller plaka sırasıyla değil karışık açılır
    select jsonb_agg(jsonb_build_object('il', il_id, 'oy', oy,
             'sn', least(sure, greatest(20, ceil(sure * kum::numeric / top)::int))) order by kum, z)
      into p
    from (select il_id, oy, z, sum(oy) over (order by oy, z, il_id) kum
          from (select il_id, count(*) oy, md5(il_id || ':' || s.id) z from oyun.oylar
                where secim_id = s.id and il_id is not null group by il_id) x) y;
  else
    select jsonb_agg(jsonb_build_object('il', il_id, 'oy', oy,
             'sn', least(sure, greatest(15, ceil(sure * kum::numeric / top)::int))) order by kum, il_id)
      into p
    from (select il_id, oy, sum(oy) over (order by oy, il_id) kum
          from (select il_id, count(*) oy from oyun.oylar
                where secim_id = s.id and il_id is not null group by il_id) x) y;
  end if;
  select coalesce(jsonb_object_agg(il_id::text, n), '{}'::jsonb) into sec
    from (select il_id, count(*) n from oyun.profiller where not yasakli and il_id is not null group by il_id) x;
  insert into oyun.secim_gecesi(secim_id, baslangic, sure_sn, plan, toplam_oy, mod, secmen)
  values (s.id, bas, sure, p, top, case when canli then 'canli' else 'sonuc' end, sec)
  on conflict (secim_id) do nothing;
  if not canli then
    -- eski düzen: genel "Sonuçlar açıklandı" bildirimi yerine kademeli bildirimler gider
    update oyun.secimler set hatirlatma = hatirlatma || '{"sonuc":true}'::jsonb where id = s.id;
  end if;
  perform oyun.secim_gecesi_sandik_kur(s.id);
  return true;
end $$;

-- ---------------------------------------------------------------------
-- Özet (Gündem kartı, bildirimler, eski uygulamalar): canlı düzende sandığa göre
-- (yuzde = açılan sandık oranı); eski düzende eskisi gibi il il. Eski anahtarlar aynen durur.
-- ---------------------------------------------------------------------
create or replace function oyun.secim_gecesi_ozet(p_secim bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s oyun.secimler; g oyun.secim_gecesi; acik int[]; acilan_oy bigint; onde text; n int;
        gecen numeric; ts int; acs int; k1 text; c1 bigint; c2 bigint;
begin
  select * into s from oyun.secimler where id = p_secim;
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  if g.secim_id is null then return null; end if;
  if g.mod = 'canli' and exists (select 1 from oyun.secim_gecesi_sandik where secim_id = p_secim) then
    gecen := oyun.secim_gecesi_gecen(p_secim);
    select count(*), count(*) filter (where sn <= gecen), coalesce(sum(oy) filter (where sn <= gecen), 0)
      into ts, acs, acilan_oy from oyun.secim_gecesi_sandik where secim_id = p_secim;
    select count(*) into n from (select il_id from oyun.secim_gecesi_sandik where secim_id = p_secim
                                 group by il_id having max(sn) <= gecen) x;
    if acilan_oy > 0 then
      select (array_agg(k order by c desc, k))[1], (array_agg(c order by c desc, k))[1], (array_agg(c order by c desc, k))[2]
        into k1, c1, c2
      from (select e.key k, sum(e.value::int) c from oyun.secim_gecesi_sandik sd, jsonb_each_text(sd.dagilim) e
            where sd.secim_id = p_secim and sd.sn <= gecen group by e.key) x;
      onde := case when c2 is not null and c2 = c1 then 'başa baş'
                   else oyun.sg_ad(k1) || ' %' || replace(round(c1 * 100.0 / acilan_oy, 1)::text, '.', ',') end;
    end if;
    return jsonb_build_object('acilan_il', n, 'toplam_il', jsonb_array_length(g.plan),
      'acilan_oy', acilan_oy, 'toplam_oy', g.toplam_oy,
      'yuzde', case when ts > 0 then round(acs * 100.0 / ts, 1) else 0 end,
      'oy_yuzde', case when g.toplam_oy > 0 then round(acilan_oy * 100.0 / g.toplam_oy, 1) else 0 end,
      'acilan_sandik', acs, 'toplam_sandik', ts, 'onde', onde);
  end if;
  -- sandık kaydı olmayan eski geceler (değişmedi)
  acik := oyun.secim_gecesi_acik_iller(p_secim);
  select count(*), coalesce(sum((e->>'oy')::bigint), 0) into n, acilan_oy
  from jsonb_array_elements(g.plan) e where (e->>'il')::int = any(acik);
  if acilan_oy > 0 then
    if s.tur = 'mv' then
      select pa.kisa || ' %' || replace(round(c * 100.0 / acilan_oy, 1)::text, '.', ',') into onde
      from (select parti_id, count(*) c from oyun.oylar
            where secim_id = p_secim and il_id = any(acik) and parti_id is not null
            group by parti_id order by count(*) desc, parti_id limit 1) t
      join oyun.partiler pa on pa.id = t.parti_id;
    else
      select pr.kad || ' %' || replace(round(c * 100.0 / acilan_oy, 1)::text, '.', ',') into onde
      from (select aday_id, count(*) c from oyun.oylar
            where secim_id = p_secim and il_id = any(acik) and aday_id is not null
            group by aday_id order by count(*) desc, aday_id limit 1) t
      join oyun.adaylar a on a.id = t.aday_id
      join oyun.profiller pr on pr.id = a.user_id;
    end if;
  end if;
  return jsonb_build_object('acilan_il', n, 'toplam_il', jsonb_array_length(g.plan),
    'acilan_oy', acilan_oy, 'toplam_oy', g.toplam_oy,
    'yuzde', case when g.toplam_oy > 0 then round(acilan_oy * 100.0 / g.toplam_oy, 1) else 0 end,
    'onde', onde);
end $$;

-- Gündem kartı: şu an sayımı süren seçimler (10 sn önbellek, canlıdaki gibi)
create or replace function public.secim_gecesi_aktif() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb;
begin
  r := oyun.onbellek_oku('secim_gecesi_aktif');
  if r is not null then return r; end if;
  select coalesce(jsonb_agg(jsonb_build_object('secim_id', g.secim_id, 'tur', s.tur, 'mod', g.mod,
           'bitis', g.baslangic + make_interval(secs => g.sure_sn), 'sonuc_at', s.sonuc_at,
           'yuzde', oz->'yuzde', 'onde', oz->'onde', 'acilan_sandik', oz->'acilan_sandik',
           'toplam_sandik', oz->'toplam_sandik', 'acilan_oy', oz->'acilan_oy', 'toplam_oy', oz->'toplam_oy')
           order by case s.tur when 'mv' then 1 else 0 end, g.secim_id), '[]'::jsonb)
    into r
  from oyun.secim_gecesi g join oyun.secimler s on s.id = g.secim_id
  cross join lateral (select oyun.secim_gecesi_ozet(g.secim_id) oz) z
  where oyun.secim_gecesi_aktif_mi(g.secim_id);
  perform oyun.onbellek_yaz('secim_gecesi_aktif', r, interval '10 seconds');
  return r;
end $$;

-- ---------------------------------------------------------------------
-- Bir yarışın açılmış sandıklara göre durumu (herkese aynı)
-- ---------------------------------------------------------------------
create or replace function oyun.secim_yayini_yaris(p_secim bigint, p_gecen numeric) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s oyun.secimler; g oyun.secim_gecesi; dag jsonb; secenek jsonb; iller jsonb; son jsonb; itt jsonb := '[]'::jsonb;
        sayilan bigint := 0; acilan int := 0; tsandik int := 0; toplam_oy bigint; secmen_top bigint; bag jsonb := '[]'::jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  select count(*), count(*) filter (where sn <= p_gecen), coalesce(sum(oy) filter (where sn <= p_gecen), 0)
    into tsandik, acilan, sayilan from oyun.secim_gecesi_sandik where secim_id = p_secim;
  select coalesce(jsonb_object_agg(k, n), '{}'::jsonb) into dag
    from (select e.key k, sum(e.value::int) n from oyun.secim_gecesi_sandik sd, jsonb_each_text(sd.dagilim) e
          where sd.secim_id = p_secim and sd.sn <= p_gecen group by e.key) x;
  toplam_oy := coalesce(g.toplam_oy, (select count(*) from oyun.oylar where secim_id = p_secim and il_id is not null));
  select coalesce(sum(v::bigint), 0) into secmen_top from jsonb_each_text(coalesce(g.secmen, '{}'::jsonb)) e(k, v);
  if secmen_top = 0 then
    select count(*) into secmen_top from oyun.profiller where not yasakli and il_id is not null;
  end if;

  if s.tur = 'mv' then
    with pk as (
      select distinct a.parti_id id from oyun.adaylar a join oyun.secimler o on o.id = a.secim_id
       where o.tur = 'mv_on' and o.donem = s.donem and a.parti_id is not null and a.sira is not null
      union select substr(k, 2)::bigint from jsonb_object_keys(dag) k where k like 'p%'
    )
    select coalesce(jsonb_agg(jsonb_build_object('k', 'p' || pa.id, 'parti_id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad,
             'renk', coalesce(pa.renk, '#8E97B5'), 'amblem', pa.amblem, 'oy', coalesce((dag->>('p' || pa.id))::int, 0))
             order by coalesce((dag->>('p' || pa.id))::int, 0) desc, pa.kisa), '[]'::jsonb)
      into secenek from pk join oyun.partiler pa on pa.id = pk.id;
    select coalesce(jsonb_agg(jsonb_build_object('k', 'a' || a.id, 'kad', pr.kad, 'il_id', a.il_id,
             'oy', coalesce((dag->>('a' || a.id))::int, 0)) order by coalesce((dag->>('a' || a.id))::int, 0) desc, pr.kad), '[]'::jsonb)
      into bag from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
     where a.secim_id = p_secim and a.parti_id is null;
    -- ittifaklar: seçim günü anlık görüntüsü (modül 92) varsa o, yoksa bugünkü üyelik
    if to_regclass('oyun.secim_ittifak_anlik') is not null then
      execute $q$select coalesce(jsonb_agg(jsonb_build_object('ad', x.ad, 'partiler', x.partiler, 'oy', x.oy) order by x.oy desc, x.ad), '[]'::jsonb)
        from (select ia.ittifak_ad ad, jsonb_agg(ia.parti_kisa order by ia.parti_kisa) partiler,
                     sum(coalesce(($1->>('p' || ia.parti_id))::int, 0)) oy
              from oyun.secim_ittifak_anlik ia where ia.secim_id = $2 group by ia.ittifak_id, ia.ittifak_ad) x$q$
        into itt using dag, p_secim;
    else
      select coalesce(jsonb_agg(jsonb_build_object('ad', x.ad, 'partiler', x.partiler, 'oy', x.oy) order by x.oy desc, x.ad), '[]'::jsonb)
        into itt
      from (select i.ad, jsonb_agg(pa.kisa order by pa.kisa) partiler, sum(coalesce((dag->>('p' || pa.id))::int, 0)) oy
            from oyun.ittifaklar i join oyun.ittifak_uyeler u on u.ittifak_id = i.id join oyun.partiler pa on pa.id = u.parti_id
            group by i.id, i.ad) x;
    end if;
  else
    select coalesce(jsonb_agg(jsonb_build_object('k', 'a' || a.id, 'kad', coalesce(pr.kad, '(silinmiş)'), 'parti_id', a.parti_id,
             'kisa', pa.kisa, 'ad', pa.ad, 'renk', coalesce(pa.renk, '#8E97B5'), 'amblem', pa.amblem,
             'oy', coalesce((dag->>('a' || a.id))::int, 0))
             order by coalesce((dag->>('a' || a.id))::int, 0) desc, a.basvuru_at, a.id), '[]'::jsonb)
      into secenek
    from oyun.adaylar a left join oyun.profiller pr on pr.id = a.user_id left join oyun.partiler pa on pa.id = a.parti_id
    where a.secim_id = p_secim;
  end if;

  -- il il: sandık sayısı herkese açıktır; içerik yalnız açılmış sandıklardan
  select coalesce(jsonb_agg(x order by x->>'ad'), '[]'::jsonb) into iller from (
    select jsonb_build_object('il_id', sd.il_id, 'ad', i.ad, 'mv', coalesce(i.mv_secim, i.mv),
             'sandik', count(*), 'acilan', count(*) filter (where sd.sn <= p_gecen),
             'oy', sum(sd.oy), 'sayilan', coalesce(sum(sd.oy) filter (where sd.sn <= p_gecen), 0),
             'secmen', (g.secmen->>sd.il_id::text)::int,
             'dagilim', (select coalesce(jsonb_object_agg(z.k, z.n), '{}'::jsonb)
                         from (select e.key k, sum(e.value::int) n from oyun.secim_gecesi_sandik s2, jsonb_each_text(s2.dagilim) e
                               where s2.secim_id = p_secim and s2.il_id = sd.il_id and s2.sn <= p_gecen group by e.key) z),
             'musahit', oyun.secim_yayini_musahit(p_secim, sd.il_id)) x
    from oyun.secim_gecesi_sandik sd join oyun.iller i on i.id = sd.il_id
    where sd.secim_id = p_secim group by sd.il_id, i.ad, i.mv_secim, i.mv) t;

  select coalesce(jsonb_agg(jsonb_build_object('il_id', sd.il_id, 'il', i.ad, 'no', sd.no, 'sn', sd.sn,
           'an', g.baslangic + make_interval(secs => sd.sn::double precision), 'oy', sd.oy, 'dagilim', sd.dagilim)
           order by sd.sn desc, sd.il_id, sd.no), '[]'::jsonb)
    into son
  from (select * from oyun.secim_gecesi_sandik where secim_id = p_secim and sn <= p_gecen order by sn desc, il_id, no limit 15) sd
  join oyun.iller i on i.id = sd.il_id;

  return jsonb_build_object('toplam_sandik', tsandik, 'acilan_sandik', acilan, 'toplam_oy', toplam_oy,
    'sayilan_oy', sayilan, 'secmen', secmen_top, 'dagilim', dag, 'secenekler', secenek, 'bagimsizlar', bag,
    'ittifaklar', itt, 'iller', iller, 'son', son,
    'baraj', case when s.tur = 'mv' then (select baraj from oyun.ayarlar where id = 1) end,
    'sandalye_toplam', case when s.tur = 'mv' then (select coalesce(sum(coalesce(mv_secim, mv)), 600) from oyun.iller) end);
end $$;

-- Sandık başındaki müşahitlerin partileri (yalnız parti adı ve rengi; kişi adı yok)
create or replace function oyun.secim_yayini_musahit(p_secim bigint, p_il int) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  if to_regclass('oyun.musahit') is null then return '[]'::jsonb; end if;
  execute $q$select coalesce(jsonb_agg(jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk) order by pa.kisa), '[]'::jsonb)
    from oyun.musahit m join oyun.partiler pa on pa.id = m.parti_id
    where m.secim_id = $1 and m.il_id = $2 and m.sandik_at is not null and m.iptal_at is null$q$ into r using p_secim, p_il;
  return coalesce(r, '[]'::jsonb);
end $$;

-- Resmî sonuç (yalnız sonuç kesinleşince istenir)
create or replace function oyun.secim_yayini_kesin(p_secim bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s oyun.secimler; k jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.sonuc is null then return null; end if;
  if s.tur = 'mv' then
    return jsonb_build_object('ulusal', coalesce((select jsonb_agg(jsonb_build_object('parti_id', u->'parti_id', 'kisa', u->'kisa',
               'ad', u->'ad', 'renk', u->'renk', 'oy', u->'oy', 'yuzde', u->'yuzde', 'gecti', u->'gecti', 'sandalye', u->'sandalye'))
             from jsonb_array_elements(coalesce(s.sonuc->'ulusal', '[]'::jsonb)) u), '[]'::jsonb),
      'dolu', s.sonuc->'dolu', 'bos', s.sonuc->'bos', 'baraj', s.sonuc->'baraj',
      'sandalye_toplam', coalesce(s.sonuc->'sandalye_toplam',
        to_jsonb(coalesce((s.sonuc->>'dolu')::int, 0) + coalesce((s.sonuc->>'bos')::int, 0))),
      'bagimsiz_sandalye', coalesce(s.sonuc->'bagimsiz_sandalye', '0'::jsonb), 'toplam', s.sonuc->'toplam');
  end if;
  k := s.sonuc->'kazanan';
  return jsonb_build_object('toplam', s.sonuc->'toplam', 'ikinci_tur', coalesce((s.sonuc->>'ikinci_tur')::boolean, false),
    'kazanan', case when k is null or jsonb_typeof(k) <> 'object' then null
                    else jsonb_build_object('kad', k->'kad', 'kisa', k->'kisa', 'renk', k->'renk', 'parti_id', k->'parti_id',
                                            'k', 'a' || (k->>'aday_id')) end,
    'ikinci_tur_id', (select x.id from oyun.secimler x where x.tur = 'cb2' and x.donem = s.donem and s.tur = 'cb' limit 1));
end $$;

-- ---------------------------------------------------------------------
-- RPC: canlı yayın durumu. Herkese aynı gövde açılan sandık sayısına bağlı
-- anahtarla 90 sn önbellekte; saat alanları her çağrıda taze.
-- ---------------------------------------------------------------------
create or replace function public.secim_yayini(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s oyun.secimler; r oyun.secimler; g oyun.secim_gecesi; t timestamptz := oyun.simdi();
        yar jsonb := '[]'::jsonb; govde jsonb; gecen numeric; acilan int; toplam int; kesin boolean; durum text;
        sonraki numeric; x numeric;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2') then raise exception 'Seçim bulunamadı.'; end if;
  for r in select * from oyun.secimler y
           where (s.tur = 'cb2' and y.id = s.id) or (s.tur <> 'cb2' and y.donem = s.donem and y.tur in ('cb','mv'))
           order by case y.tur when 'mv' then 1 else 0 end, y.id loop
    g := null;
    select * into g from oyun.secim_gecesi where secim_id = r.id;
    if g.secim_id is null and t >= r.oy_bit and t < r.sonuc_at + interval '2 hours' then   -- zamanlayıcı geciktiyse
      perform oyun.secim_gecesi_hazirla(r.id);
      select * into g from oyun.secim_gecesi where secim_id = r.id;
    end if;
    if g.secim_id is not null and not exists (select 1 from oyun.secim_gecesi_sandik where secim_id = r.id) then
      perform oyun.secim_gecesi_sandik_kur(r.id);
    end if;
    gecen := case when g.secim_id is null then null else extract(epoch from t - g.baslangic) end;
    kesin := r.durum <> 'bekliyor' and t >= r.sonuc_at and (g.secim_id is null or gecen >= g.sure_sn);
    durum := case when kesin then 'kesin' when t < r.oy_bas then 'yakinda' when t < r.oy_bit then 'oy'
                  when g.secim_id is null or gecen < 0 then 'once' when gecen < g.sure_sn then 'sayim' else 'tamam' end;
    select count(*) filter (where kesin or sn <= coalesce(gecen, -1)), count(*) into acilan, toplam
      from oyun.secim_gecesi_sandik where secim_id = r.id;
    govde := oyun.onbellek_oku('secim_yayini:' || r.id || ':' || acilan || '/' || toplam || ':' || durum);
    if govde is null then
      govde := oyun.secim_yayini_yaris(r.id, case when kesin then 1e12 else coalesce(gecen, -1) end);
      if kesin then govde := govde || jsonb_build_object('kesin_sonuc', oyun.secim_yayini_kesin(r.id)); end if;
      perform oyun.onbellek_yaz('secim_yayini:' || r.id || ':' || acilan || '/' || toplam || ':' || durum, govde,
                                case when durum in ('oy','yakinda') then interval '20 seconds' else interval '90 seconds' end);
    end if;
    -- bir sonraki olay: sandık açılışı, sayımın sonu, plan, resmî sonuç
    if not kesin then
      if g.secim_id is not null then
        select min(sn) into x from oyun.secim_gecesi_sandik where secim_id = r.id and sn > gecen;
        if x is not null then sonraki := least(coalesce(sonraki, x - gecen), x - gecen); end if;
        if gecen < g.sure_sn then sonraki := least(coalesce(sonraki, g.sure_sn - gecen), g.sure_sn - gecen); end if;
        if gecen < 0 then sonraki := least(coalesce(sonraki, -gecen), -gecen); end if;
      end if;
      x := case when t < r.oy_bas then extract(epoch from r.oy_bas - t)
                when t < r.oy_bit + interval '62 seconds' then extract(epoch from r.oy_bit + interval '62 seconds' - t)
                when t < r.sonuc_at + interval '8 seconds' then extract(epoch from r.sonuc_at + interval '8 seconds' - t)
                else 15 end;
      sonraki := least(coalesce(sonraki, x), x);
    end if;
    yar := yar || jsonb_build_array(govde || jsonb_build_object(
      'secim_id', r.id, 'tur', r.tur, 'ara', r.ara, 'donem', r.donem, 'durum', durum, 'mod', g.mod,
      'oy_bas', r.oy_bas, 'oy_bit', r.oy_bit, 'sonuc_at', r.sonuc_at, 'goreve_bas', r.goreve_bas,
      'baslangic', g.baslangic, 'bitis', case when g.secim_id is null then null else g.baslangic + make_interval(secs => g.sure_sn) end,
      'sure_sn', g.sure_sn, 'gecen_sn', case when gecen is null then null else round(gecen, 1) end));
  end loop;
  return jsonb_build_object('simdi', t, 'secim_id', p_secim, 'yarislar', yar,
    'sonraki_sn', case when sonraki is null then null else greatest(1, ceil(sonraki))::int end);
end $$;

-- RPC: yeniden izleme — sayım bittikten sonra bütün sandıklar
create or replace function public.secim_yayini_tekrar(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s oyun.secimler; r oyun.secimler; g oyun.secim_gecesi; t timestamptz := oyun.simdi(); yar jsonb := '[]'::jsonb; govde jsonb;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2') then raise exception 'Seçim bulunamadı.'; end if;
  for r in select * from oyun.secimler y
           where (s.tur = 'cb2' and y.id = s.id) or (s.tur <> 'cb2' and y.donem = s.donem and y.tur in ('cb','mv'))
           order by case y.tur when 'mv' then 1 else 0 end, y.id loop
    g := null;
    select * into g from oyun.secim_gecesi where secim_id = r.id;
    if r.durum = 'bekliyor' or t < r.sonuc_at
       or (g.secim_id is not null and t < g.baslangic + make_interval(secs => g.sure_sn)) then
      raise exception 'Seçim gecesi yayını sayım bitince yeniden izlenebilir.';
    end if;
    continue when g.secim_id is null;
    perform oyun.secim_gecesi_sandik_kur(r.id);
    govde := oyun.onbellek_oku('secim_yayini_tekrar:' || r.id);
    if govde is null then
      govde := oyun.secim_yayini_yaris(r.id, -1)
        || jsonb_build_object('kesin_sonuc', oyun.secim_yayini_kesin(r.id),
             'sandiklar', (select coalesce(jsonb_agg(jsonb_build_object('il_id', sd.il_id, 'no', sd.no, 'sn', sd.sn, 'oy', sd.oy, 'dagilim', sd.dagilim)
                             order by sd.sn, sd.il_id, sd.no), '[]'::jsonb) from oyun.secim_gecesi_sandik sd where sd.secim_id = r.id),
             'iller_bilgi', (select coalesce(jsonb_agg(jsonb_build_object('il_id', i.id, 'ad', i.ad, 'mv', coalesce(i.mv_secim, i.mv),
                             'secmen', (g.secmen->>i.id::text)::int, 'musahit', oyun.secim_yayini_musahit(r.id, i.id)) order by i.ad), '[]'::jsonb)
                             from oyun.iller i where exists (select 1 from oyun.secim_gecesi_sandik sd where sd.secim_id = r.id and sd.il_id = i.id)));
      perform oyun.onbellek_yaz('secim_yayini_tekrar:' || r.id, govde, interval '10 minutes');
    end if;
    yar := yar || jsonb_build_array(govde || jsonb_build_object('secim_id', r.id, 'tur', r.tur, 'ara', r.ara, 'donem', r.donem,
      'durum', 'kesin', 'mod', g.mod, 'oy_bas', r.oy_bas, 'oy_bit', r.oy_bit, 'sonuc_at', r.sonuc_at, 'goreve_bas', r.goreve_bas,
      'baslangic', g.baslangic, 'bitis', g.baslangic + make_interval(secs => g.sure_sn), 'sure_sn', g.sure_sn));
  end loop;
  return jsonb_build_object('simdi', t, 'secim_id', p_secim, 'yarislar', yar);
end $$;

-- ---------------------------------------------------------------------
-- Her dakika: planı hazırla, bildirim gönder. Canlı düzende sonuç motorunu
-- beklemez (sayım sonuçtan önce biter); en çok 3 bildirim gider.
-- ---------------------------------------------------------------------
create or replace function oyun.secim_gecesi_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); s oyun.secimler; g oyun.secim_gecesi; n int := 0;
        gecen numeric; hedef int; oz jsonb; baslik text; govde text; kisa text; push boolean; yuzde text;
        ana boolean; olay_metin text; onde_m text;
begin
  for s in select * from oyun.secimler
           where tur in ('mv','cb','cb2') and t >= oy_bit and t < sonuc_at + interval '2 hours' loop
    perform oyun.secim_gecesi_hazirla(s.id);
  end loop;
  for g in select * from oyun.secim_gecesi
           where oyun.secim_gecesi_gecen(secim_id) >= 0
             and oyun.secim_gecesi_gecen(secim_id) < greatest(sure_sn + 300, 86400) and asama < 4 loop
    select * into s from oyun.secimler where id = g.secim_id;
    continue when s.durum = 'bekliyor' and g.mod <> 'canli';   -- eski düzen: sonuç yazılmadıysa bekle
    gecen := oyun.secim_gecesi_gecen(g.secim_id);
    hedef := case when gecen >= g.sure_sn then 4 when gecen >= g.sure_sn * .75 then 3
                  when gecen >= g.sure_sn * .5 then 2 when gecen >= g.sure_sn * .25 then 1 else 0 end;
    continue when hedef <= g.asama;
    oz := oyun.secim_gecesi_ozet(g.secim_id);
    kisa := case s.tur when 'mv' then 'Genel seçim' when 'cb2' then 'Cumhurbaşkanlığı 2. tur' else 'Cumhurbaşkanlığı' end;
    if g.mod = 'canli' then
      yuzde := replace(coalesce(oz->>'yuzde', '0'), '.', ',');
      onde_m := case when oz->>'onde' = 'başa baş' then '. Yarış başa baş' else coalesce('. Önde: ' || (oz->>'onde'), '') end;
      baslik := case hedef when 0 then 'Seçim gecesi: sayım başladı'
                           when 2 then kisa || ': sandıkların yarısı açıldı'
                           when 4 then kisa || ': sandıkların tamamı açıldı'
                           else kisa || ': açılan sandık %' || yuzde end;
      govde := case hedef when 0 then 'Sandıklar açılıyor. Sonuçları sandık sandık canlı izle.'
                          when 4 then 'Kesin olmayan sonuçlar' || onde_m
                                      || '. Resmî sonuç saat ' || to_char(s.sonuc_at at time zone 'Europe/Istanbul', 'HH24:MI') || '.'
                          else 'Açılan sandık %' || yuzde || ', ' || (oz->>'acilan_oy') || ' oy sayıldı'
                               || onde_m || '.' end;
      -- aynı gecede CB ve MV varsa bildirimi ve Gündem satırını CB yarışı yazar; çeyreklerde bildirim yok
      ana := s.tur in ('cb','cb2') or not exists (select 1 from oyun.secimler c where c.tur = 'cb' and c.donem = s.donem);
      push := ana and hedef in (0, 2, 4);
      olay_metin := case when ana and hedef between 1 and 3 then 'Seçim gecesi · ' || baslik || ' · ' || govde end;
    else
      baslik := case hedef when 0 then kisa || ': sayım başladı'
                           when 4 then kisa || ': sayım tamamlandı'
                           else kisa || ': sayımın %' || (hedef * 25) || '''i tamam' end;
      govde := case hedef when 0 then 'Sandıklar il il açılıyor. Canlı sonuçları izlemek için dokun.'
                          else (oz->>'acilan_il') || '/' || (oz->>'toplam_il') || ' il açıldı'
                               || coalesce('. Önde: ' || (oz->>'onde'), '') || '.' end;
      push := s.tur in ('mv','cb2');
      olay_metin := case when hedef between 1 and 3 and s.tur in ('mv','cb2') then 'Seçim gecesi · ' || baslik || ' · ' || govde end;
    end if;
    if push then
      perform oyun.push_konuya('s_tum', null, baslik, govde, jsonb_build_object('ekran', 'secim', 'id', s.id));
    end if;
    if olay_metin is not null then
      perform oyun.olay('secim', olay_metin);
    end if;
    update oyun.secim_gecesi set asama = hedef where secim_id = g.secim_id;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function oyun.sg_zar(text), oyun.sg_ad(text), oyun.secim_gecesi_sandik_kur(bigint),
  oyun.secim_gecesi_hazirla(bigint), oyun.secim_gecesi_ozet(bigint), oyun.secim_yayini_yaris(bigint, numeric),
  oyun.secim_yayini_musahit(bigint, int), oyun.secim_yayini_kesin(bigint), oyun.secim_gecesi_tick()
  from public, anon, authenticated;
revoke all on function public.secim_yayini(bigint), public.secim_yayini_tekrar(bigint), public.secim_gecesi_aktif()
  from public, anon;
grant execute on function public.secim_yayini(bigint), public.secim_yayini_tekrar(bigint), public.secim_gecesi_aktif()
  to authenticated;

-- Sayımı bitmiş son gecelere sandık kaydı (yalnız yeniden izleme için; sonuç değişmez)
select oyun.secim_gecesi_sandik_kur(g.secim_id)
from oyun.secim_gecesi g join oyun.secimler s on s.id = g.secim_id
where s.sonuc_at > oyun.simdi() - interval '45 days'
  and oyun.simdi() >= g.baslangic + make_interval(secs => g.sure_sn);
