-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 99) VEKİL OY KAYDI + MECLİS ARAŞTIRMASI
--
--  A) Herkese açık oy kaydı
--     Her milletvekilinin Genel Kurul'daki açık oyları (kanun ilk/ısrar oylaması, gensoru,
--     hükümet güvenoyu, erken seçim, Meclis araştırması öngörüşmesi, komisyon oyları) tek yerde,
--     oyuncu kartında görünür. Anayasa değişikliği ve Meclis içi seçimler gizli oyla yapıldığı
--     için listede yer almaz. Grup kararına aykırı oylar işaretlenir; katılım oranı hesaplanır.
--
--  B) Meclis araştırması (Anayasa md. 98, İçtüzük md. 104-105)
--     1. Önerge: bir vekil konu + gerekçe yazar. 24 saatte dolu sandalyelerin otuzda biri kadar
--        (en az 2) vekilin imzası gerekir.
--     2. Öngörüşme: Genel Kurul 24 saat açık oyla karar verir (toplantı ve karar yeter sayısı
--        kanunlarla aynı). Meclis Başkanı oy kullanamaz.
--     3. Kuruluş (24 saat): komisyon üyeleri partilerin sandalye oranına göre (D'Hondt) belirlenir;
--        vekiller kendi partilerinin kontenjanından katılır. İlk 12 saatte dolmayan yerlere her
--        vekil katılabilir. Üyeler aralarından komisyon başkanını seçer.
--     4. Çalışma (6 gün): üyeler herhangi bir oyuncuyu (bakan, belediye başkanı, şirket sahibi…)
--        komisyona davet edip soru sorar; davetli 48 saat içinde yazılı cevap verir, vermezse
--        "gelmedi" diye rapora geçer. Başkan raporu yazar.
--     5. Rapor oylaması (24 saat): üyeler raporu oylar, katılmayanlar muhalefet şerhi yazar.
--        Rapor herkese açıktır; Meclis'e ve kamuoyuna duyurulur.
--     Yasama dönemi biterse sonuçlanmamış araştırmalar kadük olur.
--  Yalnız ekler; oyuncu verisi silinmez. İki kez çalıştırılabilir.
-- =====================================================================

-- ---------- Tablolar ----------
create table if not exists oyun.meclis_arastirma(
  id            bigserial primary key,
  no            int,
  konu          text not null check (char_length(konu) between 10 and 150),
  gerekce       text not null check (char_length(gerekce) between 50 and 3000),
  teklif_eden   uuid not null references oyun.profiller(id),
  teklif_parti  bigint,
  durum         text not null default 'imza' check (durum in
                  ('imza','oylamada','kurulus','calisma','rapor_oylama','tamamlandi','reddedildi','dustu','kaduk','geri_cekildi')),
  olusturma     timestamptz not null,
  imza_bit      timestamptz not null,
  oy_bas        timestamptz,
  oy_bit        timestamptz,
  kurulus_bit   timestamptz,
  calisma_bit   timestamptz,
  rapor_oy_bit  timestamptz,
  uye_sayisi    int,
  kontenjan     jsonb,                       -- {"parti_id": koltuk} (bağımsız yok)
  baskan        uuid,
  rapor         text,
  oneriler      text,
  rapor_at      timestamptz,
  rapor_sonuc   text check (rapor_sonuc in ('kabul','ret')),
  sonuc_metin   text,
  sonuc_at      timestamptz
);
create index if not exists meclis_arastirma_durum on oyun.meclis_arastirma(durum, id desc);
create index if not exists meclis_arastirma_teklif on oyun.meclis_arastirma(teklif_eden);

create table if not exists oyun.meclis_arastirma_imza(
  arastirma_id bigint not null references oyun.meclis_arastirma(id) on delete cascade,
  vekil        uuid not null references oyun.profiller(id),
  zaman        timestamptz not null,
  primary key (arastirma_id, vekil)
);
create table if not exists oyun.meclis_arastirma_oy(
  arastirma_id bigint not null references oyun.meclis_arastirma(id) on delete cascade,
  asama        text not null check (asama in ('ongorusme','rapor')),
  vekil        uuid not null references oyun.profiller(id),
  parti_id     bigint,
  oy           text not null check (oy in ('kabul','ret','cekimser')),
  zaman        timestamptz not null,
  primary key (arastirma_id, asama, vekil)
);
create index if not exists meclis_arastirma_oy_vekil on oyun.meclis_arastirma_oy(vekil, zaman desc);
create table if not exists oyun.meclis_arastirma_uye(
  arastirma_id bigint not null references oyun.meclis_arastirma(id) on delete cascade,
  vekil        uuid not null references oyun.profiller(id),
  parti_id     bigint,
  katilma      timestamptz not null,
  baskan_oy    uuid,
  primary key (arastirma_id, vekil)
);
create index if not exists meclis_arastirma_uye_vekil on oyun.meclis_arastirma_uye(vekil);
create table if not exists oyun.meclis_arastirma_dinleme(
  id            bigserial primary key,
  arastirma_id  bigint not null references oyun.meclis_arastirma(id) on delete cascade,
  soran         uuid not null references oyun.profiller(id),
  davetli       uuid not null references oyun.profiller(id),
  davetli_unvan text,
  soru          text not null check (char_length(soru) between 20 and 1000),
  zaman         timestamptz not null,
  son           timestamptz not null,
  cevap         text,
  cevap_at      timestamptz,
  durum         text not null default 'bekliyor' check (durum in ('bekliyor','cevaplandi','gelmedi'))
);
create index if not exists meclis_arastirma_dinleme_a on oyun.meclis_arastirma_dinleme(arastirma_id, id);
create index if not exists meclis_arastirma_dinleme_d on oyun.meclis_arastirma_dinleme(davetli, durum);
create table if not exists oyun.meclis_arastirma_serh(
  arastirma_id bigint not null references oyun.meclis_arastirma(id) on delete cascade,
  vekil        uuid not null references oyun.profiller(id),
  metin        text not null check (char_length(metin) between 20 and 1500),
  zaman        timestamptz not null,
  primary key (arastirma_id, vekil)
);

do $$ declare t text; begin
  foreach t in array array['meclis_arastirma','meclis_arastirma_imza','meclis_arastirma_oy','meclis_arastirma_uye',
                           'meclis_arastirma_dinleme','meclis_arastirma_serh'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $$;
revoke all on sequence oyun.meclis_arastirma_id_seq, oyun.meclis_arastirma_dinleme_id_seq from public, anon, authenticated;

-- ---------- Yardımcılar ----------
create or replace function oyun.mar_tbmm_baskani(u uuid) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.makamlar where user_id = u and tur = 'tbmm' and bit is null)
$$;
create or replace function oyun.mar_imza_yeter() returns int language sql stable set search_path = '' as $$
  select least(greatest(2, ceil(oyun.dolu_sandalye() * 20 / 600.0)::int), greatest(1, oyun.dolu_sandalye()))
$$;
create or replace function oyun.mar_uye_sayisi() returns int language sql stable set search_path = '' as $$
  select least(15, greatest(5, ceil(oyun.dolu_sandalye() / 8.0)::int), greatest(1, oyun.dolu_sandalye() - 1))
$$;
-- Yasama döneminin başladığı an (yeni dönemde TBMM Başkanlığı seçimi açılır)
create or replace function oyun.mar_donem_bas() returns timestamptz language sql stable set search_path = '' as $$
  select max(olusturma) from oyun.meclis_secim where tur = 'baskan'
$$;
-- Partilerin komisyon kontenjanı: sandalye sayısına göre D'Hondt (bağımsızlar kontenjan almaz)
create or replace function oyun.mar_kontenjan(p_n int) returns jsonb language plpgsql stable set search_path = '' as $$
declare r record; sonuc jsonb := '{}'::jsonb; i int;
begin
  if p_n <= 0 then return sonuc; end if;
  for r in
    with s as (select m.user_id, p.parti_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
                where m.tur = 'mv' and m.bit is null and p.parti_id is not null),
         ps as (select s.parti_id, count(*) sandalye from s group by s.parti_id),
         bol as (select ps.parti_id, ps.sandalye::numeric / d bolum, ps.sandalye from ps cross join generate_series(1, p_n) d)
    select bol.parti_id from bol order by bol.bolum desc, bol.sandalye desc, bol.parti_id limit p_n
  loop
    i := coalesce((sonuc ->> r.parti_id::text)::int, 0) + 1;
    sonuc := sonuc || jsonb_build_object(r.parti_id::text, i);
  end loop;
  return sonuc;
end $$;

-- ---------- Durum geçişleri ----------
create or replace function oyun.mar_ongorusme_sonuc(p_id bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare a oyun.meclis_arastirma; dolu int := oyun.dolu_sandalye(); kab int; ret int; cek int; n int;
begin
  select * into a from oyun.meclis_arastirma where id = p_id for update;
  if a.id is null or a.durum <> 'oylamada' or t < a.oy_bit then return; end if;
  select count(*) filter (where oy = 'kabul'), count(*) filter (where oy = 'ret'), count(*) filter (where oy = 'cekimser')
    into kab, ret, cek from oyun.meclis_arastirma_oy where arastirma_id = p_id and asama = 'ongorusme';
  if kab + ret + cek >= ceil(dolu / 3.0) and kab > ret and kab >= floor(dolu / 4.0) + 1 then
    n := oyun.mar_uye_sayisi();
    update oyun.meclis_arastirma set durum = 'kurulus', kurulus_bit = t + interval '24 hours', uye_sayisi = n,
      kontenjan = oyun.mar_kontenjan(n),
      sonuc_metin = format('Genel Kurul araştırma açılmasını kabul etti (%s kabul, %s ret, %s çekimser).', kab, ret, cek)
    where id = p_id;
    perform oyun.olay('meclis', format('Meclis araştırması açıldı: "%s". %s üyeli araştırma komisyonu kuruluyor.', a.konu, n), null, a.teklif_parti, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select m.user_id, t, format('"%s" konulu Meclis araştırması kabul edildi. Komisyona 24 saat içinde katılabilirsin (Meclis › Araştırma).', a.konu)
      from oyun.makamlar m where m.tur = 'mv' and m.bit is null;
  else
    update oyun.meclis_arastirma set durum = 'reddedildi', sonuc_at = t,
      sonuc_metin = case when kab + ret + cek < ceil(dolu / 3.0)
        then format('Toplantı yeter sayısı sağlanamadı (%s vekil oy kullandı, en az %s gerekiyordu).', kab + ret + cek, ceil(dolu / 3.0)::int)
        else format('Genel Kurul önergeyi reddetti (%s kabul, %s ret, %s çekimser; kabul için en az %s ve retten fazla oy gerekiyordu).', kab, ret, cek, floor(dolu / 4.0)::int + 1) end
    where id = p_id;
    perform oyun.bildir(a.teklif_eden, format('"%s" konulu Meclis araştırması önergen kabul edilmedi.', a.konu), t);
  end if;
end $$;

create or replace function oyun.mar_kurulus_sonuc(p_id bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare a oyun.meclis_arastirma; uye int; b uuid;
begin
  select * into a from oyun.meclis_arastirma where id = p_id for update;
  if a.id is null or a.durum <> 'kurulus' or t < a.kurulus_bit then return; end if;
  -- Görevi biten üyeler komisyondan düşer
  delete from oyun.meclis_arastirma_uye u where u.arastirma_id = p_id
    and not exists (select 1 from oyun.makamlar m where m.user_id = u.vekil and m.tur = 'mv' and m.bit is null);
  select count(*) into uye from oyun.meclis_arastirma_uye where arastirma_id = p_id;
  if uye < 2 then
    update oyun.meclis_arastirma set durum = 'dustu', sonuc_at = t,
      sonuc_metin = format('Komisyon kurulamadı: süresinde yalnız %s vekil katıldı (en az 2 gerekir).', uye) where id = p_id;
    perform oyun.bildir(a.teklif_eden, format('"%s" araştırma komisyonu yeterli üye olmadığı için kurulamadı.', a.konu), t);
    return;
  end if;
  -- Başkan: en çok oyu alan üye; eşitlikte önce katılan. Hiç oy yoksa önerge sahibi (üyeyse) ya da ilk katılan.
  select x.aday into b from (
    select u.baskan_oy aday, count(*) n, min(k.katilma) ilk from oyun.meclis_arastirma_uye u
      join oyun.meclis_arastirma_uye k on k.arastirma_id = u.arastirma_id and k.vekil = u.baskan_oy
     where u.arastirma_id = p_id and u.baskan_oy is not null group by u.baskan_oy
     order by n desc, ilk limit 1) x;
  if b is null then
    select vekil into b from oyun.meclis_arastirma_uye where arastirma_id = p_id
      order by (vekil = a.teklif_eden) desc, katilma limit 1;
  end if;
  update oyun.meclis_arastirma set durum = 'calisma', baskan = b, calisma_bit = t + interval '6 days' where id = p_id;
  perform oyun.olay('meclis', format('"%s" araştırma komisyonu %s üyeyle çalışmaya başladı. Komisyon Başkanı: %s.', a.konu, uye, oyun.kad(b)), null, null, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select u.vekil, t, format('"%s" araştırma komisyonu çalışmaya başladı. %s 6 gün; tanıkları davet edebilirsin.', a.konu,
      case when u.vekil = b then 'Komisyon Başkanı sensin: raporu sen yazacaksın. Çalışma süresi' else 'Çalışma süresi' end)
    from oyun.meclis_arastirma_uye u where u.arastirma_id = p_id;
end $$;

create or replace function oyun.mar_rapor_sonuc(p_id bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare a oyun.meclis_arastirma; kab int; ret int; cek int; s text;
begin
  select * into a from oyun.meclis_arastirma where id = p_id for update;
  if a.id is null or a.durum <> 'rapor_oylama' or t < a.rapor_oy_bit then return; end if;
  select count(*) filter (where oy = 'kabul'), count(*) filter (where oy = 'ret'), count(*) filter (where oy = 'cekimser')
    into kab, ret, cek from oyun.meclis_arastirma_oy where arastirma_id = p_id and asama = 'rapor';
  s := case when kab > ret and kab >= 1 then 'kabul' else 'ret' end;
  update oyun.meclis_arastirma set durum = 'tamamlandi', rapor_sonuc = s, sonuc_at = t,
    sonuc_metin = format('Komisyon raporu %s (%s kabul, %s ret, %s çekimser).', case when s = 'kabul' then 'kabul edildi' else 'kabul edilmedi' end, kab, ret, cek)
  where id = p_id;
  perform oyun.olay('meclis', format('"%s" Meclis araştırma raporu %s. Rapor herkese açık (Meclis › Araştırma).', a.konu,
    case when s = 'kabul' then 'kabul edildi' else 'komisyonda reddedildi' end), null, null, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select m.user_id, t, format('"%s" Meclis araştırma raporu yayımlandı (%s).', a.konu, case when s = 'kabul' then 'kabul' else 'ret' end)
    from oyun.makamlar m where m.tur = 'mv' and m.bit is null;
end $$;

create or replace function oyun.meclis_arastirma_tick(t timestamptz default null) returns void
language plpgsql set search_path = '' as $$
declare r record; db timestamptz := oyun.mar_donem_bas();
begin
  t := coalesce(t, oyun.simdi());
  -- Yeni yasama dönemi başladıysa önceki dönemin sonuçlanmamış araştırmaları kadük
  if db is not null then
    update oyun.meclis_arastirma set durum = 'kaduk', sonuc_at = t, sonuc_metin = 'Yasama dönemi sona erdiği için kadük oldu.'
    where durum in ('imza','oylamada','kurulus','calisma','rapor_oylama') and olusturma < db;
  end if;
  -- İmza süresi doldu
  for r in select id from oyun.meclis_arastirma where durum = 'imza' and imza_bit <= t loop
    update oyun.meclis_arastirma set durum = 'dustu', sonuc_at = t,
      sonuc_metin = format('Yeterli imza toplanamadı (%s imza, %s gerekiyordu).',
        (select count(*) from oyun.meclis_arastirma_imza i where i.arastirma_id = r.id), oyun.mar_imza_yeter())
    where id = r.id;
  end loop;
  for r in select id from oyun.meclis_arastirma where durum = 'oylamada' and oy_bit <= t loop perform oyun.mar_ongorusme_sonuc(r.id, t); end loop;
  for r in select id from oyun.meclis_arastirma where durum = 'kurulus' and kurulus_bit <= t loop perform oyun.mar_kurulus_sonuc(r.id, t); end loop;
  -- Cevapsız davetler
  update oyun.meclis_arastirma_dinleme set durum = 'gelmedi' where durum = 'bekliyor' and son <= t;
  -- Çalışma süresi bitti: rapor yoksa düşer
  for r in select id, konu, baskan from oyun.meclis_arastirma where durum = 'calisma' and calisma_bit <= t loop
    update oyun.meclis_arastirma set durum = 'dustu', sonuc_at = t,
      sonuc_metin = 'Komisyon Başkanı çalışma süresi içinde rapor sunmadı; araştırma raporsuz kapandı.' where id = r.id;
    perform oyun.olay('meclis', format('"%s" araştırma komisyonu süresinde rapor sunamadı.', r.konu), null, null, t);
  end loop;
  for r in select id from oyun.meclis_arastirma where durum = 'rapor_oylama' and rapor_oy_bit <= t loop perform oyun.mar_rapor_sonuc(r.id, t); end loop;
end $$;

-- ---------- JSON ----------
create or replace function oyun.mar_ozet(a oyun.meclis_arastirma, u uuid) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', a.id, 'no', a.no, 'konu', a.konu, 'durum', a.durum,
    'teklif_eden', oyun.kad(a.teklif_eden), 'parti', oyun.parti_json(a.teklif_parti), 'olusturma', a.olusturma,
    'son', case a.durum when 'imza' then a.imza_bit when 'oylamada' then a.oy_bit when 'kurulus' then a.kurulus_bit
                         when 'calisma' then a.calisma_bit when 'rapor_oylama' then a.rapor_oy_bit end,
    'imza', (select count(*) from oyun.meclis_arastirma_imza i where i.arastirma_id = a.id),
    'uye', (select count(*) from oyun.meclis_arastirma_uye x where x.arastirma_id = a.id), 'uye_sayisi', a.uye_sayisi,
    'baskan', oyun.kad(a.baskan), 'rapor_sonuc', a.rapor_sonuc, 'sonuc_at', a.sonuc_at,
    'uyesiyim', exists (select 1 from oyun.meclis_arastirma_uye x where x.arastirma_id = a.id and x.vekil = u),
    'bekleyen_oy', case when a.durum = 'oylamada' then not exists (select 1 from oyun.meclis_arastirma_oy o where o.arastirma_id = a.id and o.asama = 'ongorusme' and o.vekil = u)
                        when a.durum = 'rapor_oylama' then exists (select 1 from oyun.meclis_arastirma_uye x where x.arastirma_id = a.id and x.vekil = u)
                             and not exists (select 1 from oyun.meclis_arastirma_oy o where o.arastirma_id = a.id and o.asama = 'rapor' and o.vekil = u)
                        else false end)
$$;

create or replace function oyun.mar_oy_say(p_id bigint, p_asama text) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'kabul', count(*) filter (where o.oy = 'kabul'), 'ret', count(*) filter (where o.oy = 'ret'), 'cekimser', count(*) filter (where o.oy = 'cekimser'),
    'liste', coalesce(jsonb_agg(jsonb_build_object('kad', oyun.kad(o.vekil), 'oy', o.oy, 'parti', oyun.parti_json(o.parti_id)) order by o.zaman), '[]'::jsonb))
  from oyun.meclis_arastirma_oy o where o.arastirma_id = p_id and o.asama = p_asama
$$;

-- ---------- Okuma RPC'leri ----------
create or replace function public.meclis_arastirmalar(p_limit int default 30) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); vek boolean;
begin
  perform oyun.meclis_arastirma_tick(t);
  vek := oyun.aktif_vekil(p.id);
  return jsonb_build_object(
    'vekilim', vek, 'tbmm_baskani', oyun.mar_tbmm_baskani(p.id),
    'imza_yeter', oyun.mar_imza_yeter(), 'uye_sayisi', oyun.mar_uye_sayisi(), 'dolu', oyun.dolu_sandalye(),
    'aktif', coalesce((select jsonb_agg(oyun.mar_ozet(a, p.id) order by a.id desc) from oyun.meclis_arastirma a
                        where a.durum in ('imza','oylamada','kurulus','calisma','rapor_oylama')), '[]'::jsonb),
    'biten', coalesce((select jsonb_agg(oyun.mar_ozet(a, p.id) order by a.id desc) from (
                        select * from oyun.meclis_arastirma where durum not in ('imza','oylamada','kurulus','calisma','rapor_oylama')
                        order by id desc limit least(greatest(coalesce(p_limit, 30), 1), 60)) a), '[]'::jsonb),
    'davetlerim', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'arastirma_id', d.arastirma_id, 'konu', a.konu,
                        'soran', oyun.kad(d.soran), 'soru', d.soru, 'son', d.son) order by d.son)
                        from oyun.meclis_arastirma_dinleme d join oyun.meclis_arastirma a on a.id = d.arastirma_id
                        where d.davetli = p.id and d.durum = 'bekliyor'), '[]'::jsonb));
end $$;

create or replace function public.meclis_arastirma_detay(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma; uye boolean; vek boolean; dolu int;
begin
  perform oyun.meclis_arastirma_tick(t);
  select * into a from oyun.meclis_arastirma where id = p_id;
  if a.id is null then raise exception 'Meclis araştırması bulunamadı.'; end if;
  uye := exists (select 1 from oyun.meclis_arastirma_uye where arastirma_id = a.id and vekil = p.id);
  vek := oyun.aktif_vekil(p.id); dolu := oyun.dolu_sandalye();
  return oyun.mar_ozet(a, p.id) || jsonb_build_object(
    'gerekce', a.gerekce, 'imza_bit', a.imza_bit, 'oy_bas', a.oy_bas, 'oy_bit', a.oy_bit, 'kurulus_bit', a.kurulus_bit,
    'calisma_bit', a.calisma_bit, 'rapor_oy_bit', a.rapor_oy_bit, 'sonuc_metin', a.sonuc_metin,
    'rapor', a.rapor, 'oneriler', a.oneriler, 'rapor_at', a.rapor_at,
    'imza_yeter', oyun.mar_imza_yeter(), 'dolu', dolu, 'toplanti_yeter', ceil(dolu / 3.0)::int, 'karar_yeter', floor(dolu / 4.0)::int + 1,
    'imzalar', coalesce((select jsonb_agg(oyun.kad(i.vekil) order by i.zaman) from oyun.meclis_arastirma_imza i where i.arastirma_id = a.id), '[]'::jsonb),
    'ongorusme', oyun.mar_oy_say(a.id, 'ongorusme'),
    'rapor_oy', case when a.durum in ('rapor_oylama','tamamlandi') then oyun.mar_oy_say(a.id, 'rapor') end,
    'uyeler', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(u.vekil), 'parti', oyun.parti_json(u.parti_id),
                'baskan', u.vekil = a.baskan, 'oy_aldi', (select count(*) from oyun.meclis_arastirma_uye z where z.arastirma_id = a.id and z.baskan_oy = u.vekil))
                order by (u.vekil = a.baskan) desc, u.katilma) from oyun.meclis_arastirma_uye u where u.arastirma_id = a.id), '[]'::jsonb),
    'kontenjan', case when a.durum = 'kurulus' then coalesce((select jsonb_agg(jsonb_build_object('parti', oyun.parti_json(k.key::bigint), 'koltuk', k.value::int,
                'dolu', (select count(*) from oyun.meclis_arastirma_uye u where u.arastirma_id = a.id and u.parti_id = k.key::bigint)) order by k.value::int desc)
                from jsonb_each_text(a.kontenjan) k), '[]'::jsonb) end,
    'serbest_an', case when a.durum = 'kurulus' then a.kurulus_bit - interval '12 hours' end,
    'dinlemeler', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'soran', oyun.kad(d.soran), 'davetli', oyun.kad(d.davetli),
                'davetli_unvan', d.davetli_unvan, 'soru', d.soru, 'zaman', d.zaman, 'son', d.son, 'cevap', d.cevap, 'cevap_at', d.cevap_at,
                'durum', d.durum, 'bana', d.davetli = p.id) order by d.id) from oyun.meclis_arastirma_dinleme d where d.arastirma_id = a.id), '[]'::jsonb),
    'serhler', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(s.vekil), 'metin', s.metin, 'zaman', s.zaman) order by s.zaman)
                from oyun.meclis_arastirma_serh s where s.arastirma_id = a.id), '[]'::jsonb),
    'ben', jsonb_build_object(
      'vekil', vek, 'tbmm_baskani', oyun.mar_tbmm_baskani(p.id), 'uye', uye, 'baskan', a.baskan = p.id, 'teklif_eden', a.teklif_eden = p.id,
      'imzaladim', exists (select 1 from oyun.meclis_arastirma_imza i where i.arastirma_id = a.id and i.vekil = p.id),
      'ongorusme_oyum', (select oy from oyun.meclis_arastirma_oy o where o.arastirma_id = a.id and o.asama = 'ongorusme' and o.vekil = p.id),
      'rapor_oyum', (select oy from oyun.meclis_arastirma_oy o where o.arastirma_id = a.id and o.asama = 'rapor' and o.vekil = p.id),
      'baskan_oyum', (select oyun.kad(baskan_oy) from oyun.meclis_arastirma_uye u where u.arastirma_id = a.id and u.vekil = p.id),
      'serh_yazdim', exists (select 1 from oyun.meclis_arastirma_serh s where s.arastirma_id = a.id and s.vekil = p.id),
      'parti_id', p.parti_id));
end $$;

-- ---------- Yazma RPC'leri ----------
create or replace function oyun.mar_vekil_zorunlu(p oyun.profiller, t timestamptz) returns void language plpgsql stable set search_path = '' as $$
begin
  if p.id is null then raise exception 'Önce giriş yap.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Bu işlemi yalnız milletvekilleri yapabilir.'; end if;
  if p.susturma_bitis is not null and p.susturma_bitis > t then raise exception 'Hesabın şu anda yazamaz (kural ihlali).'; end if;
end $$;

create or replace function public.meclis_arastirma_ver(p_konu text, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; g text; yeni bigint;
begin
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  if oyun.mar_tbmm_baskani(p.id) then raise exception 'Meclis Başkanı önerge veremez.'; end if;
  k := btrim(regexp_replace(coalesce(p_konu, ''), '\s+', ' ', 'g'));
  g := btrim(coalesce(p_gerekce, ''));
  if char_length(k) not between 10 and 150 then raise exception 'Araştırma konusu 10–150 karakter olmalı.'; end if;
  if char_length(g) not between 50 and 3000 then raise exception 'Gerekçe 50–3000 karakter olmalı.'; end if;
  if oyun.kufurlu(k || ' ' || g) then raise exception 'Önergede uygunsuz bir ifade var. Hakaret ve küfür yasaktır.'; end if;
  if exists (select 1 from oyun.meclis_arastirma where teklif_eden = p.id and durum in ('imza','oylamada')) then
    raise exception 'İmza ya da oylama aşamasında zaten bir araştırma önergen var.';
  end if;
  if (select count(*) from oyun.meclis_arastirma where durum in ('imza','oylamada')) >= 3 then
    raise exception 'Meclis gündeminde aynı anda en fazla 3 araştırma önergesi olabilir. Biri sonuçlanınca tekrar dene.';
  end if;
  if exists (select 1 from oyun.meclis_arastirma where teklif_eden = p.id and olusturma > t - interval '24 hours') then
    raise exception 'Günde en fazla bir araştırma önergesi verebilirsin.';
  end if;
  insert into oyun.meclis_arastirma(no, konu, gerekce, teklif_eden, teklif_parti, olusturma, imza_bit)
    values ((select coalesce(max(no), 0) + 1 from oyun.meclis_arastirma), k, g, p.id, p.parti_id, t, t + interval '24 hours')
    returning id into yeni;
  insert into oyun.meclis_arastirma_imza(arastirma_id, vekil, zaman) values (yeni, p.id, t);
  perform oyun.olay('meclis', format('%s Meclis araştırması önergesi verdi: "%s". İmza toplanıyor.', p.kad, k), null, p.parti_id, t);
  perform oyun.mar_imza_kontrol(yeni, t);
  return public.meclis_arastirma_detay(yeni);
end $$;

-- Yeterli imza toplanınca öngörüşme oylaması hemen başlar
create or replace function oyun.mar_imza_kontrol(p_id bigint, t timestamptz) returns void language plpgsql set search_path = '' as $$
declare a oyun.meclis_arastirma;
begin
  select * into a from oyun.meclis_arastirma where id = p_id for update;
  if a.durum <> 'imza' then return; end if;
  if (select count(*) from oyun.meclis_arastirma_imza i where i.arastirma_id = p_id
        and exists (select 1 from oyun.makamlar m where m.user_id = i.vekil and m.tur = 'mv' and m.bit is null)) >= oyun.mar_imza_yeter() then
    update oyun.meclis_arastirma set durum = 'oylamada', oy_bas = t, oy_bit = t + interval '24 hours' where id = p_id;
    perform oyun.olay('meclis', format('"%s" araştırma önergesi yeterli imzaya ulaştı; Genel Kurul 24 saat oylayacak.', a.konu), null, a.teklif_parti, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select m.user_id, t, format('Genel Kurul oylaması: "%s" konusunda Meclis araştırması açılsın mı? 24 saat içinde oy ver (Meclis › Araştırma).', a.konu)
      from oyun.makamlar m where m.tur = 'mv' and m.bit is null;
  end if;
end $$;

create or replace function public.meclis_arastirma_imza(p_id bigint, p_imza boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma;
begin
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  if oyun.mar_tbmm_baskani(p.id) then raise exception 'Meclis Başkanı önergeye imza veremez.'; end if;
  select * into a from oyun.meclis_arastirma where id = p_id;
  if a.id is null or a.durum <> 'imza' then raise exception 'Bu önerge imza aşamasında değil.'; end if;
  if a.teklif_eden = p.id then raise exception 'Önerge sahibinin imzası geri çekilemez; önergeyi geri çekebilirsin.'; end if;
  if coalesce(p_imza, true) then
    insert into oyun.meclis_arastirma_imza(arastirma_id, vekil, zaman) values (a.id, p.id, t) on conflict do nothing;
    perform oyun.mar_imza_kontrol(a.id, t);
  else
    delete from oyun.meclis_arastirma_imza where arastirma_id = a.id and vekil = p.id;
  end if;
  return public.meclis_arastirma_detay(a.id);
end $$;

create or replace function public.meclis_arastirma_geri_cek(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma;
begin
  select * into a from oyun.meclis_arastirma where id = p_id for update;
  if a.id is null or a.teklif_eden <> p.id then raise exception 'Yalnız önerge sahibi geri çekebilir.'; end if;
  if a.durum <> 'imza' then raise exception 'Önerge yalnız imza aşamasında geri çekilebilir.'; end if;
  update oyun.meclis_arastirma set durum = 'geri_cekildi', sonuc_at = t, sonuc_metin = 'Önerge sahibi önergeyi geri çekti.' where id = a.id;
  return public.meclis_arastirma_detay(a.id);
end $$;

create or replace function public.meclis_arastirma_oy(p_id bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma; s text;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  select * into a from oyun.meclis_arastirma where id = p_id;
  if a.id is null then raise exception 'Meclis araştırması bulunamadı.'; end if;
  if a.durum = 'oylamada' and t >= a.oy_bas and t < a.oy_bit then
    if oyun.mar_tbmm_baskani(p.id) then raise exception 'Meclis Başkanı Genel Kurul''da oy kullanamaz (Anayasa md. 94).'; end if;
    s := 'ongorusme';
  elsif a.durum = 'rapor_oylama' and t < a.rapor_oy_bit then
    if not exists (select 1 from oyun.meclis_arastirma_uye where arastirma_id = a.id and vekil = p.id) then
      raise exception 'Raporu yalnız komisyon üyeleri oylar.';
    end if;
    s := 'rapor';
  else raise exception 'Bu araştırma şu anda oylamada değil.'; end if;
  insert into oyun.meclis_arastirma_oy(arastirma_id, asama, vekil, parti_id, oy, zaman) values (a.id, s, p.id, p.parti_id, p_oy, t)
  on conflict (arastirma_id, asama, vekil) do update set oy = excluded.oy, zaman = excluded.zaman, parti_id = excluded.parti_id;
  return public.meclis_arastirma_detay(a.id);
end $$;

create or replace function public.meclis_arastirma_uye_ol(p_id bigint, p_katil boolean default true) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma; kota int; dolu int; top int;
begin
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  select * into a from oyun.meclis_arastirma where id = p_id for update;
  if a.id is null or a.durum <> 'kurulus' then raise exception 'Komisyona yalnız kuruluş aşamasında katılınır.'; end if;
  if not coalesce(p_katil, true) then
    delete from oyun.meclis_arastirma_uye where arastirma_id = a.id and vekil = p.id;
    update oyun.meclis_arastirma_uye set baskan_oy = null where arastirma_id = a.id and baskan_oy = p.id;
    return public.meclis_arastirma_detay(a.id);
  end if;
  if oyun.mar_tbmm_baskani(p.id) then raise exception 'Meclis Başkanı komisyonlarda görev almaz.'; end if;
  if exists (select 1 from oyun.meclis_arastirma_uye where arastirma_id = a.id and vekil = p.id) then raise exception 'Zaten bu komisyonun üyesisin.'; end if;
  if (select count(*) from oyun.meclis_arastirma_uye u join oyun.meclis_arastirma x on x.id = u.arastirma_id
       where u.vekil = p.id and x.durum in ('kurulus','calisma','rapor_oylama')) >= 2 then
    raise exception 'Aynı anda en fazla 2 araştırma komisyonunda üye olabilirsin.';
  end if;
  select count(*) into top from oyun.meclis_arastirma_uye where arastirma_id = a.id;
  if top >= a.uye_sayisi then raise exception 'Komisyonun bütün üyelikleri doldu.'; end if;
  kota := coalesce((a.kontenjan ->> coalesce(p.parti_id, 0)::text)::int, 0);
  select count(*) into dolu from oyun.meclis_arastirma_uye where arastirma_id = a.id and parti_id is not distinct from p.parti_id;
  if (p.parti_id is null or dolu >= kota) and t < a.kurulus_bit - interval '12 hours' then
    raise exception '%', case when p.parti_id is null
      then 'Bağımsız vekiller, partilerin dolduramadığı yerlere kuruluşun son 12 saatinde katılabilir.'
      else format('Partinin bu komisyondaki kontenjanı (%s) doldu. Boş kalan yerler kuruluşun son 12 saatinde herkese açılır.', kota) end;
  end if;
  -- Son 12 saatte partilerin doldurmadığı yerler herkese açıktır (toplam üye sınırı yukarıda kontrol edildi)
  insert into oyun.meclis_arastirma_uye(arastirma_id, vekil, parti_id, katilma) values (a.id, p.id, p.parti_id, t);
  return public.meclis_arastirma_detay(a.id);
end $$;

create or replace function public.meclis_arastirma_baskan_oy(p_id bigint, p_aday text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma; ad uuid;
begin
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  select * into a from oyun.meclis_arastirma where id = p_id;
  if a.id is null or a.durum <> 'kurulus' then raise exception 'Komisyon başkanı kuruluş aşamasında seçilir.'; end if;
  if not exists (select 1 from oyun.meclis_arastirma_uye where arastirma_id = a.id and vekil = p.id) then raise exception 'Başkanı yalnız komisyon üyeleri seçer.'; end if;
  select u.vekil into ad from oyun.meclis_arastirma_uye u join oyun.profiller x on x.id = u.vekil
   where u.arastirma_id = a.id and lower(x.kad) = lower(btrim(coalesce(p_aday, '')));
  if ad is null then raise exception 'Aday komisyon üyesi olmalı.'; end if;
  update oyun.meclis_arastirma_uye set baskan_oy = ad where arastirma_id = a.id and vekil = p.id;
  return public.meclis_arastirma_detay(a.id);
end $$;

create or replace function public.meclis_arastirma_davet(p_id bigint, p_kad text, p_soru text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma; d oyun.profiller; s text;
begin
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  select * into a from oyun.meclis_arastirma where id = p_id;
  if a.id is null or a.durum <> 'calisma' then raise exception 'Davet yalnız komisyonun çalışma süresinde yapılabilir.'; end if;
  if not exists (select 1 from oyun.meclis_arastirma_uye where arastirma_id = a.id and vekil = p.id) then raise exception 'Davet yalnız komisyon üyelerince yapılır.'; end if;
  if t > a.calisma_bit - interval '12 hours' then raise exception 'Çalışma süresinin son 12 saatinde yeni davet yapılamaz.'; end if;
  select * into d from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if d.id is null then raise exception 'Bu kullanıcı adında oyuncu yok.'; end if;
  if d.id = p.id then raise exception 'Kendini davet edemezsin.'; end if;
  s := btrim(coalesce(p_soru, ''));
  if char_length(s) not between 20 and 1000 then raise exception 'Soru 20–1000 karakter olmalı.'; end if;
  if oyun.kufurlu(s) then raise exception 'Soruda uygunsuz bir ifade var.'; end if;
  if exists (select 1 from oyun.meclis_arastirma_dinleme where arastirma_id = a.id and davetli = d.id and durum = 'bekliyor') then
    raise exception 'Bu kişinin cevaplamadığı bir davet zaten var.';
  end if;
  if (select count(*) from oyun.meclis_arastirma_dinleme where arastirma_id = a.id and soran = p.id and zaman > t - interval '24 hours') >= 3 then
    raise exception 'Bir üye 24 saatte en fazla 3 davet yapabilir.';
  end if;
  if (select count(*) from oyun.meclis_arastirma_dinleme where arastirma_id = a.id) >= 30 then
    raise exception 'Bu komisyon davet sınırına (30) ulaştı.';
  end if;
  insert into oyun.meclis_arastirma_dinleme(arastirma_id, soran, davetli, davetli_unvan, soru, zaman, son)
    values (a.id, p.id, d.id, oyun.unvan(d.id), s, t, least(t + interval '48 hours', a.calisma_bit));
  perform oyun.bildir(d.id, format('"%s" Meclis araştırma komisyonu seni dinlemek istiyor. %s sordu; cevabın rapora geçecek (Meclis › Araştırma).', a.konu, p.kad), t);
  return public.meclis_arastirma_detay(a.id);
end $$;

create or replace function public.meclis_arastirma_cevap(p_dinleme bigint, p_cevap text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.meclis_arastirma_dinleme; c text;
begin
  perform oyun.meclis_arastirma_tick(t);
  if p.susturma_bitis is not null and p.susturma_bitis > t then raise exception 'Hesabın şu anda yazamaz (kural ihlali).'; end if;
  select * into d from oyun.meclis_arastirma_dinleme where id = p_dinleme for update;
  if d.id is null or d.davetli <> p.id then raise exception 'Bu davet sana yapılmadı.'; end if;
  if d.durum <> 'bekliyor' then raise exception 'Bu davetin cevap süresi geçti ya da zaten cevapladın.'; end if;
  c := btrim(coalesce(p_cevap, ''));
  if char_length(c) not between 20 and 2000 then raise exception 'Cevap 20–2000 karakter olmalı.'; end if;
  if oyun.kufurlu(c) then raise exception 'Cevabında uygunsuz bir ifade var.'; end if;
  update oyun.meclis_arastirma_dinleme set cevap = c, cevap_at = t, durum = 'cevaplandi' where id = d.id;
  perform oyun.bildir(d.soran, format('%s komisyon davetini cevapladı.', p.kad), t);
  return public.meclis_arastirma_detay(d.arastirma_id);
end $$;

create or replace function public.meclis_arastirma_rapor(p_id bigint, p_rapor text, p_oneriler text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma; r text; o text;
begin
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  select * into a from oyun.meclis_arastirma where id = p_id for update;
  if a.id is null or a.durum <> 'calisma' then raise exception 'Rapor yalnız çalışma süresinde sunulabilir.'; end if;
  if a.baskan is distinct from p.id then raise exception 'Raporu Komisyon Başkanı sunar.'; end if;
  r := btrim(coalesce(p_rapor, '')); o := nullif(btrim(coalesce(p_oneriler, '')), '');
  if char_length(r) not between 100 and 6000 then raise exception 'Rapor 100–6000 karakter olmalı.'; end if;
  if o is not null and char_length(o) > 2000 then raise exception 'Öneriler en fazla 2000 karakter olabilir.'; end if;
  if oyun.kufurlu(r || ' ' || coalesce(o, '')) then raise exception 'Raporda uygunsuz bir ifade var.'; end if;
  update oyun.meclis_arastirma set rapor = r, oneriler = o, rapor_at = t, durum = 'rapor_oylama', rapor_oy_bit = t + interval '24 hours' where id = a.id;
  -- Henüz cevaplanmamış davetler rapora "gelmedi" diye geçer
  update oyun.meclis_arastirma_dinleme set durum = 'gelmedi' where arastirma_id = a.id and durum = 'bekliyor';
  insert into oyun.bildirimler(user_id, zaman, metin)
    select u.vekil, t, format('"%s" komisyon raporu sunuldu. 24 saat içinde oyla; katılmıyorsan muhalefet şerhi yaz.', a.konu)
    from oyun.meclis_arastirma_uye u where u.arastirma_id = a.id and u.vekil <> p.id;
  return public.meclis_arastirma_detay(a.id);
end $$;

create or replace function public.meclis_arastirma_serh(p_id bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.meclis_arastirma; m text;
begin
  perform oyun.mar_vekil_zorunlu(p, t);
  perform oyun.meclis_arastirma_tick(t);
  select * into a from oyun.meclis_arastirma where id = p_id;
  if a.id is null or a.durum <> 'rapor_oylama' then raise exception 'Muhalefet şerhi rapor oylaması sırasında yazılır.'; end if;
  if not exists (select 1 from oyun.meclis_arastirma_uye where arastirma_id = a.id and vekil = p.id) then raise exception 'Şerhi yalnız komisyon üyeleri yazar.'; end if;
  if a.baskan = p.id then raise exception 'Raporu yazan başkan şerh düşemez.'; end if;
  m := btrim(coalesce(p_metin, ''));
  if char_length(m) not between 20 and 1500 then raise exception 'Şerh 20–1500 karakter olmalı.'; end if;
  if oyun.kufurlu(m) then raise exception 'Şerhte uygunsuz bir ifade var.'; end if;
  insert into oyun.meclis_arastirma_serh(arastirma_id, vekil, metin, zaman) values (a.id, p.id, m, t)
  on conflict (arastirma_id, vekil) do update set metin = excluded.metin, zaman = excluded.zaman;
  return public.meclis_arastirma_detay(a.id);
end $$;

-- ---------- A) Herkese açık vekil oy kaydı ----------
create or replace function public.vekil_oy_kaydi(p_kad text, p_limit int default 40) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid; lim int := least(greatest(coalesce(p_limit, 40), 1), 200); kayit jsonb; ozet jsonb; kat jsonb; kom jsonb := '[]'::jsonb;
begin
  select id into u from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if u is null then raise exception 'Bu kullanıcı adında oyuncu yok.'; end if;
  if not exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv') then
    return jsonb_build_object('vekil', false);
  end if;

  -- Komisyon oyları (komisyon sistemi kuruluysa)
  if to_regclass('oyun.kom_oy') is not null then
    execute $q$
      select coalesce(jsonb_agg(jsonb_build_object('tur', 'komisyon', 'ref', k.id, 'baslik', coalesce(k.no::text || ' sayılı ', '') || k.baslik,
               'asama', 'Komisyon', 'oy', o.oy, 'zaman', o.zaman, 'sonuc', k.durum, 'aykiri', false)), '[]'::jsonb)
        from oyun.kom_oy o join oyun.kanunlar k on k.id = o.kanun_id where o.uye = $1 and k.tur <> 'anayasa'
    $q$ into kom using u;
  end if;

  with h as (
    select 'kanun'::text tur, k.id ref, coalesce(k.no::text || ' sayılı ', '') || k.baslik baslik,
           case o.asama when 'israr' then 'Israr oylaması' else 'Genel Kurul' end asama, o.oy, o.zaman, k.durum sonuc,
           exists (select 1 from oyun.grup_kararlari g where g.kanun_id = k.id and g.parti_id = o.parti_id
                     and g.karar in ('kabul','ret') and g.karar <> o.oy) aykiri
      from oyun.kanun_oylari o join oyun.kanunlar k on k.id = o.kanun_id where o.vekil = u and k.tur <> 'anayasa'
    union all
    select 'gensoru', g.id, 'Gensoru: ' || left(g.gerekce, 90), 'Genel Kurul', o.oy, o.zaman, g.durum, false
      from oyun.gensoru_oylari o join oyun.gensorular g on g.id = o.gensoru_id where o.vekil = u
    union all
    select 'guvenoyu', o.hukumet_id, 'Hükümete güvenoyu', 'Genel Kurul', o.oy, o.zaman, null, false
      from oyun.hukumet_guven_oylari o where o.vekil = u
    union all
    select 'erken_secim', e.id, 'Erken seçim kararı: ' || left(e.gerekce, 80), 'Genel Kurul', o.oy, o.zaman, e.durum, false
      from oyun.erken_secim_oylari o join oyun.erken_secim_teklifleri e on e.id = o.teklif_id where o.vekil = u
    union all
    select 'arastirma', a.id, 'Meclis araştırması: ' || a.konu,
           case o.asama when 'rapor' then 'Komisyon raporu' else 'Öngörüşme' end, o.oy, o.zaman, a.durum, false
      from oyun.meclis_arastirma_oy o join oyun.meclis_arastirma a on a.id = o.arastirma_id where o.vekil = u
    union all
    select x->>'tur', (x->>'ref')::bigint, x->>'baslik', x->>'asama', x->>'oy', (x->>'zaman')::timestamptz, x->>'sonuc', false
      from jsonb_array_elements(kom) x
  )
  select
    coalesce((select jsonb_agg(jsonb_build_object('tur', tur, 'ref', ref, 'baslik', baslik, 'asama', asama, 'oy', oy,
                'zaman', zaman, 'sonuc', sonuc, 'aykiri', aykiri) order by zaman desc)
              from (select * from h order by zaman desc limit lim) s), '[]'::jsonb),
    jsonb_build_object('toplam', count(*), 'kabul', count(*) filter (where oy = 'kabul'), 'ret', count(*) filter (where oy = 'ret'),
                       'cekimser', count(*) filter (where oy = 'cekimser'), 'aykiri', count(*) filter (where aykiri))
    into kayit, ozet from h;

  -- Katılım: vekilken sonuçlanan açık kanun oylamaları (ilk tur) ve araştırma öngörüşmeleri
  with gorev as (select bas, coalesce(bit, 'infinity'::timestamptz) bit from oyun.makamlar where user_id = u and tur = 'mv'),
  oturum as (
    select k.id, 'k'::text cins, k.oy_bas from oyun.kanunlar k
     where k.tur <> 'anayasa' and k.oy_bas is not null and k.durum not in ('geri_cekildi','gorusmede','oylamada')
       and exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.asama = 'ilk')
    union all
    select a.id, 'a', a.oy_bas from oyun.meclis_arastirma a
     where a.oy_bas is not null and a.durum not in ('imza','oylamada','geri_cekildi')
  ),
  sorumlu as (select o.* from oturum o where exists (select 1 from gorev g where o.oy_bas >= g.bas and o.oy_bas < g.bit))
  select jsonb_build_object('oturum', count(*),
    'katildi', count(*) filter (where (cins = 'k' and exists (select 1 from oyun.kanun_oylari x where x.kanun_id = s.id and x.asama = 'ilk' and x.vekil = u))
                                   or (cins = 'a' and exists (select 1 from oyun.meclis_arastirma_oy x where x.arastirma_id = s.id and x.asama = 'ongorusme' and x.vekil = u))))
    into kat from sorumlu s;

  return jsonb_build_object('vekil', true, 'kad', oyun.kad(u),
    'gorevde', oyun.aktif_vekil(u), 'tbmm_baskani', oyun.mar_tbmm_baskani(u),
    'ozet', ozet || jsonb_build_object('oturum', kat->'oturum', 'katildi', kat->'katildi'),
    'kayit', kayit);
end $$;

-- ---------- Yetkiler ----------
revoke all on function public.meclis_arastirmalar(int), public.meclis_arastirma_detay(bigint), public.meclis_arastirma_ver(text, text),
  public.meclis_arastirma_imza(bigint, boolean), public.meclis_arastirma_geri_cek(bigint), public.meclis_arastirma_oy(bigint, text),
  public.meclis_arastirma_uye_ol(bigint, boolean), public.meclis_arastirma_baskan_oy(bigint, text), public.meclis_arastirma_davet(bigint, text, text),
  public.meclis_arastirma_cevap(bigint, text), public.meclis_arastirma_rapor(bigint, text, text), public.meclis_arastirma_serh(bigint, text),
  public.vekil_oy_kaydi(text, int) from public, anon;
grant execute on function public.meclis_arastirmalar(int), public.meclis_arastirma_detay(bigint), public.meclis_arastirma_ver(text, text),
  public.meclis_arastirma_imza(bigint, boolean), public.meclis_arastirma_geri_cek(bigint), public.meclis_arastirma_oy(bigint, text),
  public.meclis_arastirma_uye_ol(bigint, boolean), public.meclis_arastirma_baskan_oy(bigint, text), public.meclis_arastirma_davet(bigint, text, text),
  public.meclis_arastirma_cevap(bigint, text), public.meclis_arastirma_rapor(bigint, text, text), public.meclis_arastirma_serh(bigint, text),
  public.vekil_oy_kaydi(text, int) to authenticated;
revoke all on function oyun.mar_tbmm_baskani(uuid), oyun.mar_imza_yeter(), oyun.mar_uye_sayisi(), oyun.mar_donem_bas(), oyun.mar_kontenjan(int),
  oyun.mar_ongorusme_sonuc(bigint, timestamptz), oyun.mar_kurulus_sonuc(bigint, timestamptz), oyun.mar_rapor_sonuc(bigint, timestamptz),
  oyun.meclis_arastirma_tick(timestamptz), oyun.mar_ozet(oyun.meclis_arastirma, uuid), oyun.mar_oy_say(bigint, text),
  oyun.mar_vekil_zorunlu(oyun.profiller, timestamptz), oyun.mar_imza_kontrol(bigint, timestamptz) from public, anon, authenticated;

-- ---------- Zamanlayıcı: 5 dakikada bir aşama geçişleri ----------
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'meclis-arastirma';
    perform cron.schedule('meclis-arastirma', '*/5 * * * *', 'select oyun.meclis_arastirma_tick()');
  end if;
end $$;
