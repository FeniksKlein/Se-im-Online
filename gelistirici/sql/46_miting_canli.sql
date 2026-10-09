-- =====================================================================
--  46 · CANLI MİTİNG MEYDANI
--  Miting artık bir "katıl" düğmesinden ibaret değil:
--    • Düzenleyen aday miting süresince kürsüden konuşur (en fazla 20 konuşma, her biri 400 karakter).
--    • Katılanlar her konuşmaya tepki verir: alkış (+1), tezahürat (+2), ıslık (-1), yuh (-2).
--      Tepki değiştirilebilir, her konuşmaya kişi başı bir tepki.
--    • Katılanlar kısa slogan atabilir (80 karakter, 20 saniyede bir, mitingte en fazla 30).
--    • Meydanın coşkusu (0-100) tepkilerden hesaplanır; miting bitince Gündem'e
--      katılım, coşku ve en çok alkış alan cümle haber olur.
--    • Başka ilden oyuncular mitingi canlı izleyebilir; tepki ve slogan yalnız katılanlardan.
--  Mevcut mitingler, katılımlar ve kıdem ödülü aynen korunur.
-- =====================================================================

create table if not exists oyun.miting_konusma(
  id        bigint generated always as identity primary key,
  miting_id bigint not null references oyun.mitingler(id) on delete cascade,
  user_id   uuid not null references oyun.profiller(id) on delete cascade,
  metin     text not null check (length(metin) between 1 and 400),
  zaman     timestamptz not null default now(),
  silindi   boolean not null default false
);
create index if not exists miting_konusma_m on oyun.miting_konusma(miting_id, id);

create table if not exists oyun.miting_tepki(
  konusma_id bigint not null references oyun.miting_konusma(id) on delete cascade,
  miting_id  bigint not null references oyun.mitingler(id) on delete cascade,
  user_id    uuid not null references oyun.profiller(id) on delete cascade,
  tur        text not null check (tur in ('alkis','tezahurat','islik','yuh')),
  zaman      timestamptz not null default now(),
  primary key (konusma_id, user_id)
);
create index if not exists miting_tepki_m on oyun.miting_tepki(miting_id);

create table if not exists oyun.miting_slogan(
  id        bigint generated always as identity primary key,
  miting_id bigint not null references oyun.mitingler(id) on delete cascade,
  user_id   uuid not null references oyun.profiller(id) on delete cascade,
  metin     text not null check (length(metin) between 1 and 80),
  zaman     timestamptz not null default now(),
  silindi   boolean not null default false
);
create index if not exists miting_slogan_m on oyun.miting_slogan(miting_id, id);

alter table oyun.mitingler add column if not exists cosku smallint;   -- bitince yazılır

do $$ declare t text; begin
  foreach t in array array['miting_konusma','miting_tepki','miting_slogan'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
    if to_regproc('oyun.bosaltma_korumasi') is not null then
      execute format('drop trigger if exists bosaltma_korumasi on oyun.%I', t);
      execute format('create trigger bosaltma_korumasi before truncate on oyun.%I for each statement execute function oyun.bosaltma_korumasi()', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Hesaplar
-- ---------------------------------------------------------------------
create or replace function oyun.miting_tepki_puan(p_tur text) returns int language sql immutable as $$
  select case p_tur when 'alkis' then 1 when 'tezahurat' then 2 when 'islik' then -1 when 'yuh' then -2 else 0 end
$$;

-- Coşku 0-100: herkes her konuşmayı alkışlasa 75, tezahürat etse 100, yuhalasa 0. Tepki yoksa 50.
create or replace function oyun.miting_cosku(p_miting bigint) returns int language sql stable set search_path = '' as $$
  with k as (select count(*) n from oyun.miting_konusma where miting_id = p_miting and not silindi),
       c as (select count(*) n from oyun.miting_katilim k join oyun.mitingler m on m.id = k.miting_id where k.miting_id = p_miting and k.user_id <> m.user_id),
       tp as (select coalesce(sum(oyun.miting_tepki_puan(t.tur)), 0) net
              from oyun.miting_tepki t join oyun.miting_konusma x on x.id = t.konusma_id and not x.silindi
              where t.miting_id = p_miting)
  select greatest(0, least(100, round(50 + 25.0 * tp.net / greatest(1, c.n * greatest(1, k.n)))))::int from k, c, tp
$$;

create or replace function oyun.miting_cosku_ad(c int) returns text language sql immutable as $$
  select case when c is null then null when c >= 85 then 'Meydan coştu' when c >= 65 then 'Coşkulu'
              when c >= 45 then 'Ilık' when c >= 25 then 'Soğuk' else 'Yuhalandı' end
$$;

create or replace function oyun.miting_canli_mi(m oyun.mitingler, t timestamptz) returns boolean language sql immutable as $$
  select t >= m.bas and t < m.bit
$$;

-- ---------------------------------------------------------------------
-- Meydan ekranı
-- ---------------------------------------------------------------------
create or replace function public.miting_meydan(p_id bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); m oyun.mitingler; ben oyun.profiller; n int; c int;
begin
  select * into m from oyun.mitingler where id = p_id;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  select * into ben from oyun.profiller where id = u;
  select count(*) into n from oyun.miting_katilim where miting_id = m.id and user_id <> m.user_id;
  c := coalesce(case when t >= m.bit then m.cosku end, oyun.miting_cosku(m.id));
  return jsonb_build_object(
    'id', m.id, 'baslik', m.baslik, 'bas', m.bas, 'bit', m.bit, 'simdi', t,
    'canli', t >= m.bas and t < m.bit, 'bitti', t >= m.bit,
    'il', (select ad from oyun.iller where id = m.il_id), 'il_id', m.il_id,
    'kad', (select kad from oyun.profiller where id = m.user_id),
    'unvan', oyun.unvan(m.user_id),
    'parti', oyun.parti_json(m.parti_id),
    'slogan', (select k.slogan from oyun.parti_kimlik k where k.parti_id = m.parti_id),
    'secim_tur', (select tur from oyun.secimler where id = m.secim_id),
    'katilim', n, 'cosku', c, 'cosku_ad', oyun.miting_cosku_ad(c),
    'benim', m.user_id = u,
    'katildim', exists (select 1 from oyun.miting_katilim where miting_id = m.id and user_id = u),
    'katilabilir', ben.id is not null and ben.il_id = m.il_id and m.user_id <> u,
    'konusma_kalan', greatest(0, 20 - (select count(*) from oyun.miting_konusma where miting_id = m.id)),
    'son_katilanlar', (select coalesce(jsonb_agg(x.kad order by x.zaman desc), '[]'::jsonb) from (
        select p.kad, k.zaman from oyun.miting_katilim k join oyun.profiller p on p.id = k.user_id
        where k.miting_id = m.id and k.user_id <> m.user_id order by k.zaman desc limit 12) x),
    'konusmalar', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'metin', x.metin, 'zaman', x.zaman,
        'alkis', (select count(*) from oyun.miting_tepki r where r.konusma_id = x.id and r.tur = 'alkis'),
        'tezahurat', (select count(*) from oyun.miting_tepki r where r.konusma_id = x.id and r.tur = 'tezahurat'),
        'islik', (select count(*) from oyun.miting_tepki r where r.konusma_id = x.id and r.tur = 'islik'),
        'yuh', (select count(*) from oyun.miting_tepki r where r.konusma_id = x.id and r.tur = 'yuh'),
        'tepkim', (select r.tur from oyun.miting_tepki r where r.konusma_id = x.id and r.user_id = u)) order by x.id), '[]'::jsonb)
      from oyun.miting_konusma x where x.miting_id = m.id and not x.silindi),
    'sloganlar', (select coalesce(jsonb_agg(jsonb_build_object('id', y.id, 'kad', y.kad, 'metin', y.metin, 'zaman', y.zaman) order by y.id), '[]'::jsonb) from (
        select s.id, p.kad, s.metin, s.zaman from oyun.miting_slogan s join oyun.profiller p on p.id = s.user_id
        where s.miting_id = m.id and not s.silindi order by s.id desc limit 40) y)
  );
end $$;

-- Düzenleyen aday kürsüden konuşur
create or replace function public.miting_konus(p_id bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.mitingler; x text; son timestamptz;
begin
  select * into m from oyun.mitingler where id = p_id for update;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if m.user_id <> p.id then raise exception 'Kürsüde yalnız mitingi düzenleyen aday konuşabilir.'; end if;
  if t < m.bas then raise exception 'Miting henüz başlamadı; konuşmanı başlangıç saatinde yapabilirsin.'; end if;
  if t >= m.bit then raise exception 'Miting sona erdi.'; end if;
  if (select count(*) from oyun.miting_konusma where miting_id = m.id) >= 20 then
    raise exception 'Bir mitingde en fazla 20 kez kürsüye çıkabilirsin.';
  end if;
  select max(zaman) into son from oyun.miting_konusma where miting_id = m.id;
  if son is not null and son > t - interval '15 seconds' then
    raise exception 'Meydan önceki sözünü alkışlıyor; 15 saniye bekle.';
  end if;
  perform oyun.yazabilir_mi(p, t);
  x := oyun.metin_temizle(p_metin, 400);
  insert into oyun.miting_konusma(miting_id, user_id, metin, zaman) values (m.id, p.id, x, t);
  insert into oyun.miting_katilim(miting_id, user_id, zaman) values (m.id, p.id, t) on conflict do nothing;
  update oyun.profiller set son_mesaj = t where id = p.id;
  return public.miting_meydan(m.id);
end $$;

-- Katılan oyuncu bir konuşmaya tepki verir (değiştirebilir)
create or replace function public.miting_tepki(p_konusma bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.miting_konusma; m oyun.mitingler;
begin
  if p_tur not in ('alkis','tezahurat','islik','yuh') then raise exception 'Geçersiz tepki.'; end if;
  select * into k from oyun.miting_konusma where id = p_konusma and not silindi;
  if k.id is null then raise exception 'Konuşma bulunamadı.'; end if;
  select * into m from oyun.mitingler where id = k.miting_id;
  if t < m.bas or t >= m.bit then raise exception 'Miting canlı değil; tepki verilemez.'; end if;
  if m.user_id = p.id then raise exception 'Kendi konuşmana tepki veremezsin.'; end if;
  if not exists (select 1 from oyun.miting_katilim where miting_id = m.id and user_id = p.id) then
    raise exception 'Tepki vermek için önce mitinge katıl.';
  end if;
  insert into oyun.miting_tepki(konusma_id, miting_id, user_id, tur, zaman) values (k.id, m.id, p.id, p_tur, t)
  on conflict (konusma_id, user_id) do update set tur = excluded.tur, zaman = excluded.zaman;
  return public.miting_meydan(m.id);
end $$;

-- Katılan oyuncu kısa slogan atar
create or replace function public.miting_slogan_at(p_id bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.mitingler; x text; son timestamptz;
begin
  select * into m from oyun.mitingler where id = p_id;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if t < m.bas or t >= m.bit then raise exception 'Miting canlı değil.'; end if;
  if m.user_id = p.id then raise exception 'Kürsüdesin; meydana kürsüden seslen.'; end if;
  if not exists (select 1 from oyun.miting_katilim where miting_id = m.id and user_id = p.id) then
    raise exception 'Slogan atmak için önce mitinge katıl.';
  end if;
  select max(zaman) into son from oyun.miting_slogan where miting_id = m.id and user_id = p.id;
  if son is not null and son > t - interval '20 seconds' then raise exception 'Sesin kısıldı; 20 saniye sonra yeniden slogan atabilirsin.'; end if;
  if (select count(*) from oyun.miting_slogan where miting_id = m.id and user_id = p.id) >= 30 then
    raise exception 'Bu mitingde yeterince slogan attın.';
  end if;
  perform oyun.yazabilir_mi(p, t);
  x := oyun.metin_temizle(p_metin, 80);
  insert into oyun.miting_slogan(miting_id, user_id, metin, zaman) values (m.id, p.id, x, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return public.miting_meydan(m.id);
end $$;

-- Moderatör: uygunsuz konuşma ya da sloganı kaldırır (şikâyet yetkisi)
create or replace function public.miting_icerik_sil(p_tur text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare mid bigint;
begin
  perform oyun.yetki_zorunlu('sikayet');
  if p_tur = 'konusma' then update oyun.miting_konusma set silindi = true where id = p_id returning miting_id into mid;
  elsif p_tur = 'slogan' then update oyun.miting_slogan set silindi = true where id = p_id returning miting_id into mid;
  else raise exception 'Geçersiz içerik türü.'; end if;
  if mid is null then raise exception 'İçerik bulunamadı.'; end if;
  return public.miting_meydan(mid);
end $$;

-- ---------------------------------------------------------------------
-- Mevcut fonksiyonların genişletilmesi
-- ---------------------------------------------------------------------
create or replace function public.mitingler() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'kad', p.kad, 'parti', oyun.parti_json(m.parti_id), 'il_id', m.il_id,
      'il', (select ad from oyun.iller where id = m.il_id), 'baslik', m.baslik, 'bas', m.bas, 'bit', m.bit,
      'katilim', (select count(*) from oyun.miting_katilim c where c.miting_id = m.id),
      'katildim', exists (select 1 from oyun.miting_katilim c where c.miting_id = m.id and c.user_id = auth.uid()),
      'benim_ilim', m.il_id = (select il_id from oyun.profiller where id = auth.uid()),
      'benim', m.user_id = auth.uid(),
      'konusma', (select count(*) from oyun.miting_konusma k where k.miting_id = m.id and not k.silindi),
      'cosku', coalesce(m.cosku, case when m.bas <= oyun.simdi() then oyun.miting_cosku(m.id) end),
      'secim_tur', (select tur from oyun.secimler where id = m.secim_id)) order by m.bas), '[]'::jsonb)
  from oyun.mitingler m join oyun.profiller p on p.id = m.user_id
  where m.bit > oyun.simdi() - interval '6 hours' and m.bas < oyun.simdi() + interval '3 days'
$$;

create or replace function oyun.miting_tick(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare m record; n int; c int; enIyi text; konusma int;
begin
  for m in select x.*, p.kad, i.ad il_ad from oyun.mitingler x join oyun.profiller p on p.id = x.user_id join oyun.iller i on i.id = x.il_id
           where not x.duyuruldu and x.bas <= t and x.bit > t loop
    update oyun.mitingler set duyuruldu = true where id = m.id;
    insert into oyun.bildirimler(user_id, zaman, metin)
      select pr.id, t, format('%s şu an %s meydanında: “%s”. Bir saat içinde Gündem''den mitinge katılıp konuşmaları dinleyebilir, tepki verebilirsin.', m.kad, m.il_ad, m.baslik)
      from oyun.profiller pr where pr.il_id = m.il_id and pr.id <> m.user_id and not pr.yasakli;
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
revoke all on function public.miting_meydan(bigint), public.miting_konus(bigint, text), public.miting_tepki(bigint, text),
  public.miting_slogan_at(bigint, text), public.miting_icerik_sil(text, bigint) from public, anon;
grant execute on function public.miting_meydan(bigint), public.miting_konus(bigint, text), public.miting_tepki(bigint, text),
  public.miting_slogan_at(bigint, text), public.miting_icerik_sil(text, bigint) to authenticated;
revoke all on function oyun.miting_cosku(bigint), oyun.miting_tick(timestamptz) from public, anon, authenticated;
