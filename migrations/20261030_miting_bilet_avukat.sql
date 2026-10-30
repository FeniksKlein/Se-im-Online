-- 30.10.2026 — Miting otobüs bileti + avukat kontenjanı 1/5 (Claude canlıya uyguladı)
begin;
-- 149 (30.10.2026)
-- 1) Bireysel miting otobüs bileti: başka ilde yaşayan oyuncu canlı mitinge gidiş-dönüş bilet alıp katılır.
--    İkametgâhı değişmez; miting bitince "evine döner". Partinin kaldırdığı otobüsler aynen sürer.
-- 2) Avukat kontenjanı: her 5 aktif oyuncuya 1 avukat (önceden 10).

create table if not exists oyun.miting_bilet (
  miting_id bigint not null, user_id uuid not null, kaynak_il smallint, ucret numeric not null, zaman timestamptz not null,
  primary key (miting_id, user_id));
alter table oyun.miting_bilet enable row level security;

create or replace function public.miting_bilet_bilgi(p_miting bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); m oyun.mitingler; u numeric;
begin
  select * into m from oyun.mitingler where id = p_miting;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if p.il_id is null or p.il_id = m.il_id then return jsonb_build_object('gerekli', false); end if;
  u := 2 * oyun.miting_otobus_ucret(p.il_id::smallint, m.il_id::smallint);
  return jsonb_build_object('gerekli', true, 'ucret', u,
    'kaynak', (select ad from oyun.iller where id = p.il_id), 'hedef', (select ad from oyun.iller where id = m.il_id),
    'biletim', exists(select 1 from oyun.miting_bilet b where b.miting_id = m.id and b.user_id = p.id)
            or exists(select 1 from oyun.miting_otobus_koltuk k where k.miting_id = m.id and k.user_id = p.id),
    'canli', oyun.simdi() >= m.bas and oyun.simdi() < m.bit);
end $$;

create or replace function public.miting_bilet_al(p_miting bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.mitingler; u numeric; r jsonb;
begin
  select * into m from oyun.mitingler where id = p_miting;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if t < m.bas then raise exception 'Bilet miting başladığında satılır; kalkış o an yapılır.'; end if;
  if t >= m.bit then raise exception 'Miting sona erdi.'; end if;
  if p.il_id is null or p.il_id = m.il_id then return public.miting_katil(m.id); end if;
  if exists(select 1 from oyun.miting_bilet b where b.miting_id = m.id and b.user_id = p.id)
     or exists(select 1 from oyun.miting_otobus_koltuk k where k.miting_id = m.id and k.user_id = p.id) then
    return public.miting_katil(m.id);
  end if;
  u := 2 * oyun.miting_otobus_ucret(p.il_id::smallint, m.il_id::smallint);
  perform oyun.para_islem(p.id, -u, 'ulasim', format('Miting otobüsü gidiş-dönüş: %s → %s',
    (select ad from oyun.iller where id = p.il_id), (select ad from oyun.iller where id = m.il_id)), t);
  insert into oyun.miting_bilet(miting_id, user_id, kaynak_il, ucret, zaman) values (m.id, p.id, p.il_id, u, t);
  r := public.miting_katil(m.id);
  return r || jsonb_build_object('bilet', u);
end $$;

create or replace function public.miting_katil(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.mitingler; n int; odul boolean := false;
begin
  select * into m from oyun.mitingler where id = p_id;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if t < m.bas then raise exception 'Miting henüz başlamadı.'; end if;
  if t >= m.bit then raise exception 'Miting sona erdi.'; end if;
  if p.il_id <> m.il_id
     and not exists (select 1 from oyun.miting_otobus_koltuk k where k.miting_id=m.id and k.user_id=p.id)
     and not exists (select 1 from oyun.miting_bilet b where b.miting_id=m.id and b.user_id=p.id) then
    raise exception 'Başka ilden katılmak için otobüs bileti almalısın (meydandaki "Otobüsle git ve katıl" düğmesi).';
  end if;
  insert into oyun.miting_katilim(miting_id, user_id, zaman) values (m.id, p.id, t) on conflict do nothing;
  if found and m.user_id <> p.id and not exists (select 1 from oyun.miting_katilim c join oyun.mitingler x on x.id = c.miting_id
      where c.user_id = p.id and c.miting_id <> m.id and c.zaman >= oyun.bugun_bas(t) and x.user_id <> p.id) then
    update oyun.cuzdan set kidem = kidem + 1 where user_id = p.id; odul := true;
  end if;
  select count(*) into n from oyun.miting_katilim where miting_id = m.id;
  return jsonb_build_object('katilim', n, 'kidem', odul);
end $$;

revoke all on function public.miting_bilet_bilgi(bigint) from public, anon;
revoke all on function public.miting_bilet_al(bigint) from public, anon;
grant execute on function public.miting_bilet_bilgi(bigint) to authenticated;
grant execute on function public.miting_bilet_al(bigint) to authenticated;

-- Avukat kontenjanı: 5 aktif oyuncuya 1
update oyun.ayarlar set avukat_oran = 5 where id = 1 and avukat_oran is distinct from 5;
select oyun.avukat_sira_isle();
commit;
