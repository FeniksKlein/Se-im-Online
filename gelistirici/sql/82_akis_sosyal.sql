-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 82) AKIŞ: SOSYAL PLATFORM (beğen / beğenme, yanıtlar)
--  • Her paylaşımın altında Beğen ve Beğenme var. Yalnız SAYILAR görünür; kimin beğendiği ya da
--    beğenmediği hiçbir işlevde döndürülmez (oyuncu yalnız kendi tepkisini görür).
--  • Bir kişinin tek tepkisi olur: beğenirse beğenmemesi kalkar, tersi de.
--  • Paylaşımların altına yanıt yazılabilir (yanıtlar akışta ayrıca görünmez, paylaşımın altında açılır).
--  78 numaralı modülün üstüne eklenir; mevcut paylaşımlar ve beğeniler korunur.
-- =====================================================================

alter table oyun.akis add column if not exists yanit_id bigint references oyun.akis(id) on delete cascade;
create index if not exists akis_yanitlar on oyun.akis(yanit_id, id) where yanit_id is not null;

create table if not exists oyun.akis_begenmeme(
  akis_id bigint not null references oyun.akis(id) on delete cascade,
  user_id uuid not null,
  zaman   timestamptz not null default now(),
  primary key (akis_id, user_id)
);
alter table oyun.akis_begenmeme enable row level security;
revoke all on oyun.akis_begenmeme from public, anon, authenticated;

create or replace function oyun.akis_json(a oyun.akis, ben uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', a.id, 'kad', pr.kad, 'unvan', oyun.unvan(a.user_id), 'parti', oyun.parti_json(a.parti_id),
           'il', (select ad from oyun.iller where id = a.il_id), 'metin', a.metin, 'zaman', a.zaman, 'yanit_id', a.yanit_id,
           'begeni', (select count(*) from oyun.akis_begeni b where b.akis_id = a.id),
           'begenmeme', (select count(*) from oyun.akis_begenmeme b where b.akis_id = a.id),
           'yanit', (select count(*) from oyun.akis y where y.yanit_id = a.id and not y.gizli),
           'begendim', exists (select 1 from oyun.akis_begeni b where b.akis_id = a.id and b.user_id = ben),
           'begenmedim', exists (select 1 from oyun.akis_begenmeme b where b.akis_id = a.id and b.user_id = ben),
           'benim', a.user_id = ben)
  from oyun.profiller pr where pr.id = a.user_id
$$;

-- Tepki: p_tepki = 'begen' | 'begenme' | null (kaldır). Aynı tepkiye tekrar basmak kaldırır.
create or replace function public.akis_tepki(p_id bigint, p_tepki text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); onceki text;
begin
  if p_tepki is not null and p_tepki not in ('begen', 'begenme') then raise exception 'Geçersiz tepki.'; end if;
  if not exists (select 1 from oyun.akis where id = p_id and not gizli) then raise exception 'Paylaşım bulunamadı.'; end if;
  onceki := case when exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id) then 'begen'
                 when exists (select 1 from oyun.akis_begenmeme where akis_id = p_id and user_id = p.id) then 'begenme' end;
  if p_tepki is not null and p_tepki is distinct from onceki
     and (select count(*) from oyun.akis_begeni where user_id = p.id and zaman > t - interval '1 minute')
       + (select count(*) from oyun.akis_begenmeme where user_id = p.id and zaman > t - interval '1 minute') >= 30 then
    raise exception 'Çok hızlı tepki veriyorsun, biraz bekle.';
  end if;
  delete from oyun.akis_begeni where akis_id = p_id and user_id = p.id;
  delete from oyun.akis_begenmeme where akis_id = p_id and user_id = p.id;
  if p_tepki = 'begen' and onceki is distinct from 'begen' then
    insert into oyun.akis_begeni(akis_id, user_id, zaman) values (p_id, p.id, t);
  elsif p_tepki = 'begenme' and onceki is distinct from 'begenme' then
    insert into oyun.akis_begenmeme(akis_id, user_id, zaman) values (p_id, p.id, t);
  end if;
  return jsonb_build_object(
    'begeni', (select count(*) from oyun.akis_begeni where akis_id = p_id),
    'begenmeme', (select count(*) from oyun.akis_begenmeme where akis_id = p_id),
    'begendim', exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id),
    'begenmedim', exists (select 1 from oyun.akis_begenmeme where akis_id = p_id and user_id = p.id));
end $$;

-- Eski "beğen" düğmesi de tek tepki kuralına uysun
create or replace function public.akis_begen(p_id bigint) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select public.akis_tepki(p_id, 'begen')
$$;

-- Yanıt yaz (aynı hız sınırları ve süzgeçler; yanıt sayısı akis_yaz'ın günlük sınırına dahildir)
create or replace function public.akis_yanit_yaz(p_id bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); ana oyun.akis; r jsonb; yeni bigint;
begin
  select * into ana from oyun.akis where id = p_id and not gizli;
  if ana.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  if ana.yanit_id is not null then select * into ana from oyun.akis where id = ana.yanit_id; end if;   -- yanıta yanıt: ana paylaşıma bağla
  if exists (select 1 from oyun.engellemeler g where (g.engelleyen = ana.user_id and g.engellenen = p.id) or (g.engelleyen = p.id and g.engellenen = ana.user_id)) then
    raise exception 'Bu kullanıcıyla engelleme olduğu için yanıt yazamazsın.';
  end if;
  r := public.akis_yaz(p_metin);
  yeni := (r->>'id')::bigint;
  update oyun.akis set yanit_id = ana.id where id = yeni;
  if ana.user_id <> p.id then
    perform oyun.bildir(ana.user_id, format('%s paylaşımına yanıt verdi: %s', p.kad, left(btrim(p_metin), 80)));
  end if;
  return jsonb_build_object('tamam', true, 'id', yeni);
end $$;

-- Bir paylaşım ve yanıtları
create or replace function public.akis_konu(p_id bigint) returns jsonb
language plpgsql stable security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); a oyun.akis;
begin
  select * into a from oyun.akis where id = p_id and not gizli;
  if a.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  if a.yanit_id is not null then select * into a from oyun.akis where id = a.yanit_id and not gizli; end if;
  if a.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  return jsonb_build_object('ana', oyun.akis_json(a, p.id),
    'yanitlar', coalesce((select jsonb_agg(oyun.akis_json(y, p.id) order by y.id) from oyun.akis y
        where y.yanit_id = a.id and not y.gizli
          and not exists (select 1 from oyun.engellemeler g where (g.engelleyen = p.id and g.engellenen = y.user_id) or (g.engelleyen = y.user_id and g.engellenen = p.id))), '[]'::jsonb));
end $$;

-- Akış listesi: yanıtlar ana akışta görünmez
create or replace function public.akis_liste(p_kapsam text default 'herkes', p_etiket text default null, p_onceki bigint default null, p_limit int default 20)
returns jsonb language plpgsql stable security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); et text := nullif(lower(regexp_replace(coalesce(p_etiket, ''), '^#', '')), '');
begin
  if p_kapsam not in ('herkes', 'il', 'parti') then raise exception 'Geçersiz kapsam.'; end if;
  return coalesce((select jsonb_agg(oyun.akis_json(a, p.id) order by a.id desc) from (
    select * from oyun.akis a
     where not a.gizli and a.yanit_id is null and (p_onceki is null or a.id < p_onceki)
       and (p_kapsam <> 'il' or a.il_id = p.il_id) and (p_kapsam <> 'parti' or (p.parti_id is not null and a.parti_id = p.parti_id))
       and (et is null or exists (select 1 from oyun.akis_etiket e where e.akis_id = a.id and e.etiket = et))
       and not exists (select 1 from oyun.engellemeler g where (g.engelleyen = p.id and g.engellenen = a.user_id) or (g.engelleyen = a.user_id and g.engellenen = p.id))
     order by a.id desc limit least(greatest(coalesce(p_limit, 20), 1), 40)) a), '[]'::jsonb);
end $$;

revoke all on function public.akis_tepki(bigint, text), public.akis_yanit_yaz(bigint, text), public.akis_konu(bigint) from public, anon;
grant execute on function public.akis_tepki(bigint, text), public.akis_yanit_yaz(bigint, text), public.akis_konu(bigint) to authenticated;
revoke all on function public.akis_begen(bigint) from public, anon;
grant execute on function public.akis_begen(bigint) to authenticated;
