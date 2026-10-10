-- =====================================================================
--  75 · KADEMELİ SEÇİM GECESİ
--
--  Genel seçim (mv), cumhurbaşkanlığı (cb) ve 2. tur (cb2) sonuçları sayım
--  saatinde (22:30) hesaplanır ama oyunculara ANINDA değil, il il, yaklaşık
--  12 dakikada açılır. Küçük iller önce, büyükler sonra; her an yalnızca
--  açılmış illerin oyları toplanır ("ilk sonuçlar"). Süre değişebilir:
--     update oyun.secim_gecesi_ayar set sure_sn = 600;   -- 10 dakika (60-1800)
--
--  Güvenlik ilkesi: motor (oyun.tick, oyun.sonuclandir) ve oy sayımı DEĞİŞMEZ.
--  Gerçek sonuç yine 22:30'da yazılır; bu modül yalnızca oyunculara ne
--  gösterileceğini sınırlar:
--   • public.secim_detay sarmalanır (asıl fonksiyon oyun._secim_detay_ham
--     adıyla korunur); sonuç alanı açılmış illere göre süzülür.
--   • "Genel seçim sonuçlandı / Cumhurbaşkanı seçildi" Gündem satırı sayım
--     bitene kadar ileri tarihlenir (zaman <= şimdi süzgeci gizler).
--   • Sayımın %25-50-75'inde ve bitişinde herkese bildirim gider.
--  Zamanlayıcı (pg_cron) yoksa hiçbir şey gizlenmez; oyun eskisi gibi çalışır.
-- =====================================================================

create table if not exists oyun.secim_gecesi_ayar(
  id     boolean primary key default true check (id),
  sure_sn int not null default 720 check (sure_sn between 60 and 1800)
);
insert into oyun.secim_gecesi_ayar(id) values (true) on conflict (id) do nothing;

create table if not exists oyun.secim_gecesi(
  secim_id   bigint primary key references oyun.secimler(id) on delete cascade,
  baslangic  timestamptz not null,
  sure_sn    int not null,
  plan       jsonb not null,           -- [{"il":12,"oy":40,"sn":35}, ...] açılış sırasıyla
  toplam_oy  bigint not null default 0,
  asama      smallint not null default -1,   -- gönderilen son bildirim eşiği (0..4)
  olusturma  timestamptz not null default now()
);

do $$ declare n text; begin
  foreach n in array array['secim_gecesi_ayar','secim_gecesi'] loop
    execute format('alter table oyun.%I enable row level security', n);
    execute format('revoke all on oyun.%I from public, anon, authenticated', n);
  end loop;
end $$;

create or replace function oyun.secim_gecesi_sure() returns int
language sql stable set search_path = '' as $$
  select coalesce((select sure_sn from oyun.secim_gecesi_ayar where id), 720)
$$;

-- Sayım başlangıcından bu yana geçen saniye (kayıt yoksa null)
create or replace function oyun.secim_gecesi_gecen(p_secim bigint) returns numeric
language sql stable set search_path = '' as $$
  select extract(epoch from (oyun.simdi() - g.baslangic))::numeric
  from oyun.secim_gecesi g where g.secim_id = p_secim
$$;

-- Sayım hâlâ sürüyor mu? (başladı ve süre dolmadı)
create or replace function oyun.secim_gecesi_aktif_mi(p_secim bigint) returns boolean
language sql stable set search_path = '' as $$
  select coalesce((select oyun.secim_gecesi_gecen(g.secim_id) >= 0
                   and oyun.secim_gecesi_gecen(g.secim_id) < g.sure_sn
                   from oyun.secim_gecesi g where g.secim_id = p_secim), false)
$$;

-- Şu ana kadar açılmış il numaraları
create or replace function oyun.secim_gecesi_acik_iller(p_secim bigint) returns int[]
language sql stable set search_path = '' as $$
  select coalesce(array_agg((e->>'il')::int), '{}'::int[])
  from oyun.secim_gecesi g, jsonb_array_elements(g.plan) e
  where g.secim_id = p_secim and (e->>'sn')::numeric <= oyun.secim_gecesi_gecen(p_secim)
$$;

-- Sayım planı: küçük iller önce; ilin açılış zamanı, o ile kadar sayılmış oyların
-- toplam içindeki payıyla orantılı. Oylar kesinleştikten (sandık kapandıktan) sonra çağrılır.
create or replace function oyun.secim_gecesi_hazirla(p_secim bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare s oyun.secimler; sure int := oyun.secim_gecesi_sure(); top bigint; p jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2') then return false; end if;
  if exists (select 1 from oyun.secim_gecesi where secim_id = s.id) then return true; end if;
  select count(*) into top from oyun.oylar where secim_id = s.id and il_id is not null;
  if top = 0 then return false; end if;
  select jsonb_agg(jsonb_build_object('il', il_id, 'oy', oy,
           'sn', least(sure, greatest(15, ceil(sure * kum::numeric / top)::int))) order by kum, il_id)
    into p
  from (select il_id, oy, sum(oy) over (order by oy, il_id) kum
        from (select il_id, count(*) oy from oyun.oylar
              where secim_id = s.id and il_id is not null group by il_id) x) y;
  insert into oyun.secim_gecesi(secim_id, baslangic, sure_sn, plan, toplam_oy)
  values (s.id, s.sonuc_at, sure, p, top) on conflict (secim_id) do nothing;
  -- Genel "Sonuçlar açıklandı" bildirimi yerine kademeli bildirimler gider
  update oyun.secimler set hatirlatma = hatirlatma || '{"sonuc":true}'::jsonb where id = s.id;
  return true;
end $$;

-- Açılmış illerdeki oyların özeti: toplam, il sayısı, önde olan
create or replace function oyun.secim_gecesi_ozet(p_secim bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s oyun.secimler; g oyun.secim_gecesi; acik int[]; acilan_oy bigint; onde text; n int;
begin
  select * into s from oyun.secimler where id = p_secim;
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  if g.secim_id is null then return null; end if;
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

-- Süzülmüş sonuç: yalnızca açılmış illerin oyları ve sandalyeleri
create or replace function oyun.secim_gecesi_filtre(s oyun.secimler, ham jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare acik int[]; iller_f jsonb; toplam bigint; dolu int; mvtop int; bag_s int; bag_oy bigint;
        ulusal_f jsonb; baraj numeric; bag_f jsonb; cb_top bigint; adaylar_f jsonb;
begin
  if ham is null or not oyun.secim_gecesi_aktif_mi(s.id) then return ham; end if;
  acik := oyun.secim_gecesi_acik_iller(s.id);
  if s.tur = 'mv' then
    baraj := coalesce((ham->>'baraj')::numeric, 0);
    select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) into iller_f
      from jsonb_each(coalesce(ham->'iller', '{}'::jsonb)) e(k, v) where k::int = any(acik);
    select coalesce(sum((v->>'gecerli')::bigint), 0), coalesce(sum((v->>'mv')::int), 0)
      into toplam, mvtop from jsonb_each(iller_f) e(k, v);
    select coalesce(jsonb_agg(b), '[]'::jsonb), coalesce(sum((b->>'oy')::bigint), 0),
           coalesce(sum((b->>'sandalye')::int), 0)
      into bag_f, bag_oy, bag_s
      from jsonb_array_elements(coalesce(ham->'bagimsizlar', '[]'::jsonb)) b
      where (b->>'il_id')::int = any(acik);
    select coalesce(jsonb_agg(jsonb_build_object(
             'parti_id', u->'parti_id', 'kisa', u->'kisa', 'ad', u->'ad', 'renk', u->'renk',
             'oy', t.oy, 'yuzde', case when toplam > 0 then round(t.oy * 100.0 / toplam, 2) else 0 end,
             'gecti', case when toplam > 0 then t.oy * 100.0 / toplam >= baraj else false end,
             'sandalye', t.sandalye) order by t.oy desc), '[]'::jsonb)
      into ulusal_f
      from jsonb_array_elements(coalesce(ham->'ulusal', '[]'::jsonb)) u
      cross join lateral (
        select coalesce(sum((v->'partiler'->((u->>'parti_id'))->>'oy')::bigint), 0) oy,
               coalesce(sum((v->'partiler'->((u->>'parti_id'))->>'sandalye')::int), 0) sandalye
        from jsonb_each(iller_f) e(k, v)) t;
    select coalesce(sum((x->>'sandalye')::int), 0) into dolu from jsonb_array_elements(ulusal_f) x;
    dolu := dolu + bag_s;
    return jsonb_build_object('toplam', toplam, 'baraj', baraj, 'sandalye_toplam', mvtop,
      'dolu', dolu, 'bos', greatest(0, mvtop - dolu), 'bagimsiz_oy', bag_oy, 'bagimsiz_sandalye', bag_s,
      'bagimsizlar', bag_f, 'ulusal', ulusal_f, 'iller', iller_f, 'gece', true);
  elsif s.tur in ('cb','cb2') then
    select count(*) into cb_top from oyun.oylar where secim_id = s.id and il_id = any(acik);
    select coalesce(jsonb_agg(jsonb_set(a, '{oy}', to_jsonb((
             select count(*) from oyun.oylar o
             where o.secim_id = s.id and o.aday_id = (a->>'aday_id')::bigint and o.il_id = any(acik))))
           order by (select count(*) from oyun.oylar o
             where o.secim_id = s.id and o.aday_id = (a->>'aday_id')::bigint and o.il_id = any(acik)) desc), '[]'::jsonb)
      into adaylar_f
      from jsonb_array_elements(coalesce(ham->'adaylar', '[]'::jsonb)) a;
    return jsonb_build_object('toplam', cb_top, 'adaylar', adaylar_f, 'ikinci_tur', false, 'gece', true);
  end if;
  return ham;
end $$;

-- Arayüzün her birkaç saniyede yoklayacağı canlı sayım durumu
create or replace function public.secim_gecesi(p_secim bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare g oyun.secim_gecesi; s oyun.secimler; gecen numeric; acik int[]; oz jsonb; son jsonb;
begin
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  select * into s from oyun.secimler where id = p_secim;
  if g.secim_id is null then return jsonb_build_object('aktif', false, 'var', false); end if;
  gecen := oyun.secim_gecesi_gecen(p_secim);
  if gecen < 0 then
    return jsonb_build_object('aktif', false, 'var', true, 'basliyor', true, 'baslangic', g.baslangic,
                              'saniye_kaldi', ceil(-gecen)::int);
  end if;
  acik := oyun.secim_gecesi_acik_iller(p_secim);
  oz := oyun.secim_gecesi_ozet(p_secim);
  -- son açılan beş il ve ilde önde olan
  select coalesce(jsonb_agg(x order by (x->>'sn')::int desc), '[]'::jsonb) into son from (
    select jsonb_build_object('il_id', (e->>'il')::int, 'ad', i.ad, 'sn', (e->>'sn')::int,
      'onde', case when s.tur = 'mv' then
          (select pa.kisa from oyun.oylar o join oyun.partiler pa on pa.id = o.parti_id
           where o.secim_id = p_secim and o.il_id = (e->>'il')::int and o.parti_id is not null
           group by pa.kisa order by count(*) desc, pa.kisa limit 1)
        else
          (select pr.kad from oyun.oylar o join oyun.adaylar a on a.id = o.aday_id
           join oyun.profiller pr on pr.id = a.user_id
           where o.secim_id = p_secim and o.il_id = (e->>'il')::int
           group by pr.kad order by count(*) desc, pr.kad limit 1) end) x
    from jsonb_array_elements(g.plan) e join oyun.iller i on i.id = (e->>'il')::int
    where (e->>'il')::int = any(acik)
    order by (e->>'sn')::int desc, (e->>'il')::int limit 5) t;
  return oz || jsonb_build_object('aktif', gecen < g.sure_sn, 'var', true, 'tur', s.tur,
    'baslangic', g.baslangic, 'bitis', g.baslangic + make_interval(secs => g.sure_sn),
    'sure_sn', g.sure_sn, 'gecen_sn', least(gecen, g.sure_sn)::int,
    'saniye_kaldi', greatest(0, ceil(g.sure_sn - gecen))::int, 'son_acilan', son);
end $$;

-- Gündem için: şu an sayımı süren seçimler
create or replace function public.secim_gecesi_aktif() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('secim_id', g.secim_id, 'tur', s.tur,
           'bitis', g.baslangic + make_interval(secs => g.sure_sn),
           'yuzde', (oyun.secim_gecesi_ozet(g.secim_id))->'yuzde') order by g.secim_id), '[]'::jsonb)
  from oyun.secim_gecesi g join oyun.secimler s on s.id = g.secim_id
  where oyun.secim_gecesi_aktif_mi(g.secim_id)
$$;

-- Asıl secim_detay'i koru ve yerine süzgeçli sarmalayıcıyı koy. Canlıda fonksiyon
-- kaynaktan farklı olsa da çalışır: mevcut tanım olduğu gibi _secim_detay_ham olur.
do $$ begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'secim_detay'
               and pg_get_functiondef(p.oid) not like '%secim_gecesi_filtre%') then
    drop function if exists oyun._secim_detay_ham(bigint);
    alter function public.secim_detay(bigint) set schema oyun;
    alter function oyun.secim_detay(bigint) rename to _secim_detay_ham;
  end if;
end $$;

create or replace function public.secim_detay(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare r jsonb; s oyun.secimler;
begin
  r := oyun._secim_detay_ham(p_secim);
  select * into s from oyun.secimler where id = p_secim;
  if s.id is not null and s.tur in ('mv','cb','cb2') and oyun.secim_gecesi_aktif_mi(p_secim) then
    r := jsonb_set(r, '{sonuc}', coalesce(oyun.secim_gecesi_filtre(s, r->'sonuc'), 'null'::jsonb))
         || jsonb_build_object('gece', public.secim_gecesi(p_secim));
  end if;
  return r;
end $$;

-- Sayım bitene kadar sonuç manşetini gizle (Gündem yalnızca zaman <= şimdi olanı gösterir)
create or replace function oyun.tg_olay_gece_gizle() returns trigger
language plpgsql set search_path = '' as $$
declare bit timestamptz;
begin
  if new.tur = 'secim' and new.metin ~ '^(Genel seçim sonuçlandı|Cumhurbaşkanı|Cumhurbaşkanlığı seçimi)' then
    select g.baslangic + make_interval(secs => g.sure_sn) into bit
    from oyun.secim_gecesi g where g.baslangic = new.zaman order by g.secim_id limit 1;
    if bit is not null then new.zaman := bit; end if;
  end if;
  return new;
end $$;
drop trigger if exists olay_gece_gizle on oyun.olaylar;
create trigger olay_gece_gizle before insert on oyun.olaylar
  for each row execute function oyun.tg_olay_gece_gizle();

-- Her dakika: planı hazırla, eşiklerde bildirim gönder
create or replace function oyun.secim_gecesi_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); s oyun.secimler; g oyun.secim_gecesi; n int := 0;
        gecen numeric; hedef int; oz jsonb; baslik text; govde text; kisa text;
begin
  for s in select * from oyun.secimler
           where tur in ('mv','cb','cb2') and t >= oy_bit and t < sonuc_at + interval '2 hours' loop
    perform oyun.secim_gecesi_hazirla(s.id);
  end loop;
  for g in select * from oyun.secim_gecesi
           where oyun.secim_gecesi_gecen(secim_id) >= 0
             and oyun.secim_gecesi_gecen(secim_id) < sure_sn + 300 and asama < 4 loop
    select * into s from oyun.secimler where id = g.secim_id;
    continue when s.durum = 'bekliyor';          -- sonuç henüz yazılmadıysa bekle
    gecen := oyun.secim_gecesi_gecen(g.secim_id);
    hedef := case when gecen >= g.sure_sn then 4 when gecen >= g.sure_sn * .75 then 3
                  when gecen >= g.sure_sn * .5 then 2 when gecen >= g.sure_sn * .25 then 1 else 0 end;
    continue when hedef <= g.asama;
    oz := oyun.secim_gecesi_ozet(g.secim_id);
    kisa := case s.tur when 'mv' then 'Genel seçim' when 'cb2' then 'Cumhurbaşkanlığı 2. tur' else 'Cumhurbaşkanlığı' end;
    baslik := case hedef when 0 then kisa || ': sayım başladı'
                         when 4 then kisa || ': sayım tamamlandı'
                         else kisa || ': sayımın %' || (hedef * 25) || '''i tamam' end;
    govde := case hedef when 0 then 'Sandıklar il il açılıyor. Canlı sonuçları izlemek için dokun.'
                        else (oz->>'acilan_il') || '/' || (oz->>'toplam_il') || ' il açıldı'
                             || coalesce('. Önde: ' || (oz->>'onde'), '') || '.' end;
    if s.tur in ('mv','cb2') then
      perform oyun.push_konuya('s_tum', null, baslik, govde,
                               jsonb_build_object('ekran', 'secim', 'id', s.id));
    end if;
    if hedef between 1 and 3 and s.tur in ('mv','cb2') then
      perform oyun.olay('secim', 'Seçim gecesi · ' || baslik || ' · ' || govde);
    end if;
    update oyun.secim_gecesi set asama = hedef where secim_id = g.secim_id;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function public.secim_gecesi(bigint), public.secim_gecesi_aktif(), public.secim_detay(bigint)
  from public, anon;
grant execute on function public.secim_gecesi(bigint), public.secim_gecesi_aktif(), public.secim_detay(bigint)
  to authenticated;

-- Sayım zamanlayıcısı (yalnız pg_cron olan Supabase'de)
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'secim-gecesi';
    perform cron.schedule('secim-gecesi', '* * * * *', 'select oyun.secim_gecesi_tick()');
  end if;
end $$;
