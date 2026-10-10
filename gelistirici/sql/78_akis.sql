-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 78) KISA PAYLAŞIM AKIŞI VE GÜNDEM ETİKETLERİ
--  Oyuncular en çok 280 karakterlik kısa paylaşım yapar, #etiket kullanır; "Gündemdeki etiketler"
--  son 24 saatte en çok kişinin kullandığı etiketleri gösterir. Mevcut sohbet/propaganda sistemine dokunmaz.
--  Güvenlik (mağaza kuralları gereği): şikâyet et, kullanıcıyı engelle (mevcut engel listesi geçerli),
--  3 ayrı şikâyette gönderi otomatik gizlenir, moderatör "şikâyet" yetkisiyle karar verir,
--  küfür süzgeci + bağlantı yasağı + susturma + hız sınırı (20 sn arayla, günde 30 paylaşım).
-- =====================================================================

create table if not exists oyun.akis(
  id       bigserial primary key,
  user_id  uuid not null,
  metin    text not null check (length(metin) between 1 and 280),
  zaman    timestamptz not null default now(),
  il_id    smallint,
  parti_id bigint,
  gizli    boolean not null default false
);
create index if not exists akis_zaman on oyun.akis(id desc) where not gizli;
create index if not exists akis_kullanici on oyun.akis(user_id, zaman desc);

create table if not exists oyun.akis_etiket(
  akis_id bigint not null references oyun.akis(id) on delete cascade,
  etiket  text not null,
  zaman   timestamptz not null default now(),
  user_id uuid not null,
  primary key (akis_id, etiket)
);
create index if not exists akis_etiket_ara on oyun.akis_etiket(etiket, akis_id desc);
create index if not exists akis_etiket_zaman on oyun.akis_etiket(zaman);

create table if not exists oyun.akis_begeni(
  akis_id bigint not null references oyun.akis(id) on delete cascade,
  user_id uuid not null,
  zaman   timestamptz not null default now(),
  primary key (akis_id, user_id)
);

create table if not exists oyun.akis_sikayet(
  akis_id   bigint not null references oyun.akis(id) on delete cascade,
  sikayetci uuid not null,
  neden     text not null,
  zaman     timestamptz not null default now(),
  durum     text not null default 'yeni' check (durum in ('yeni','incelendi')),
  primary key (akis_id, sikayetci)
);

alter table oyun.akis enable row level security;
alter table oyun.akis_etiket enable row level security;
alter table oyun.akis_begeni enable row level security;
alter table oyun.akis_sikayet enable row level security;
revoke all on oyun.akis, oyun.akis_etiket, oyun.akis_begeni, oyun.akis_sikayet from public, anon, authenticated;
revoke all on sequence oyun.akis_id_seq from public, anon, authenticated;

-- Metindeki etiketler (küçük harf, en çok 5)
create or replace function oyun.akis_etiketleri(m text) returns text[]
language sql immutable as $$
  select coalesce((select array_agg(e order by ilk) from (
           select lower(x[1]) e, min(ord) ilk
             from regexp_matches(m, '#([[:alnum:]_]{2,30})', 'g') with ordinality as r(x, ord)
            group by lower(x[1]) order by min(ord) limit 5) q), '{}'::text[])
$$;

create or replace function oyun.akis_json(a oyun.akis, ben uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', a.id, 'kad', pr.kad, 'unvan', oyun.unvan(a.user_id), 'parti', oyun.parti_json(a.parti_id),
           'il', (select ad from oyun.iller where id = a.il_id), 'metin', a.metin, 'zaman', a.zaman,
           'begeni', (select count(*) from oyun.akis_begeni b where b.akis_id = a.id),
           'begendim', exists (select 1 from oyun.akis_begeni b where b.akis_id = a.id and b.user_id = ben),
           'benim', a.user_id = ben)
  from oyun.profiller pr where pr.id = a.user_id
$$;

create or replace function public.akis_yaz(p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m text; id0 bigint; e text;
begin
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 280);
  if m ~* '(https?://|www\.|\.com\b|\.net\b|\.org\b|t\.me/)' then raise exception 'Paylaşımlarda bağlantı kullanılamaz.'; end if;
  if exists (select 1 from oyun.akis where user_id = p.id and zaman > t - interval '20 seconds') then
    raise exception 'Çok sık paylaşıyorsun, biraz bekle.';
  end if;
  if (select count(*) from oyun.akis where user_id = p.id and zaman > t - interval '24 hours') >= 30 then
    raise exception 'Bugünlük paylaşım hakkın doldu; yarın yine yazabilirsin.';
  end if;
  if exists (select 1 from oyun.akis where user_id = p.id and zaman > t - interval '1 day' and lower(metin) = lower(m)) then
    raise exception 'Aynı paylaşımı tekrar yapamazsın.';
  end if;
  insert into oyun.akis(user_id, metin, zaman, il_id, parti_id) values (p.id, m, t, p.il_id, p.parti_id) returning id into id0;
  foreach e in array oyun.akis_etiketleri(m) loop
    insert into oyun.akis_etiket(akis_id, etiket, zaman, user_id) values (id0, e, t, p.id) on conflict do nothing;
  end loop;
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true, 'id', id0);
end $$;

create or replace function public.akis_liste(p_kapsam text default 'herkes', p_etiket text default null, p_onceki bigint default null, p_limit int default 20)
returns jsonb language plpgsql stable security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); et text := nullif(lower(regexp_replace(coalesce(p_etiket, ''), '^#', '')), '');
begin
  if p_kapsam not in ('herkes', 'il', 'parti') then raise exception 'Geçersiz kapsam.'; end if;
  return coalesce((select jsonb_agg(oyun.akis_json(a, p.id) order by a.id desc) from (
    select * from oyun.akis a
     where not a.gizli and (p_onceki is null or a.id < p_onceki)
       and (p_kapsam <> 'il' or a.il_id = p.il_id) and (p_kapsam <> 'parti' or (p.parti_id is not null and a.parti_id = p.parti_id))
       and (et is null or exists (select 1 from oyun.akis_etiket e where e.akis_id = a.id and e.etiket = et))
       and not exists (select 1 from oyun.engellemeler g where (g.engelleyen = p.id and g.engellenen = a.user_id) or (g.engelleyen = a.user_id and g.engellenen = p.id))
     order by a.id desc limit least(greatest(coalesce(p_limit, 20), 1), 40)) a), '[]'::jsonb);
end $$;

-- Gündemdeki etiketler: son 24 saat, en az 2 farklı kişi
create or replace function public.akis_gundem() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('etiket', x.etiket, 'kisi', x.kisi, 'paylasim', x.n) order by x.kisi desc, x.n desc, x.etiket), '[]'::jsonb)
  from (select e.etiket, count(distinct e.user_id) kisi, count(*) n
          from oyun.akis_etiket e join oyun.akis a on a.id = e.akis_id and not a.gizli
         where e.zaman > oyun.simdi() - interval '24 hours'
         group by e.etiket having count(distinct e.user_id) >= 2
         order by count(distinct e.user_id) desc, count(*) desc, e.etiket limit 8) x
$$;

create or replace function public.akis_begen(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); n int;
begin
  if not exists (select 1 from oyun.akis where id = p_id and not gizli) then raise exception 'Paylaşım bulunamadı.'; end if;
  if exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id) then
    delete from oyun.akis_begeni where akis_id = p_id and user_id = p.id;
  else
    if (select count(*) from oyun.akis_begeni where user_id = p.id and zaman > t - interval '1 minute') >= 20 then
      raise exception 'Çok hızlı beğeniyorsun, biraz bekle.';
    end if;
    insert into oyun.akis_begeni(akis_id, user_id, zaman) values (p_id, p.id, t);
  end if;
  select count(*) into n from oyun.akis_begeni where akis_id = p_id;
  return jsonb_build_object('begeni', n, 'begendim', exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id));
end $$;

create or replace function public.akis_sil(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  delete from oyun.akis where id = p_id and user_id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.akis_sikayet_et(p_id bigint, p_neden text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); hedef uuid; n int;
begin
  if p_neden not in ('hakaret','nefret','spam','taciz','uygunsuz','diger') then raise exception 'Geçersiz şikâyet nedeni.'; end if;
  select user_id into hedef from oyun.akis where id = p_id;
  if hedef is null then raise exception 'Paylaşım bulunamadı.'; end if;
  if hedef = p.id then raise exception 'Kendi paylaşımını şikâyet edemezsin.'; end if;
  insert into oyun.akis_sikayet(akis_id, sikayetci, neden, zaman) values (p_id, p.id, p_neden, t) on conflict do nothing;
  select count(distinct sikayetci) into n from oyun.akis_sikayet where akis_id = p_id;
  if n >= 3 then update oyun.akis set gizli = true where id = p_id; end if;
  select count(distinct s.sikayetci) into n from oyun.akis_sikayet s join oyun.akis a on a.id = s.akis_id
   where a.user_id = hedef and s.zaman > t - interval '24 hours';
  if n >= 8 then
    update oyun.profiller set susturma_bitis = greatest(coalesce(susturma_bitis, t), t + interval '24 hours') where id = hedef;
  end if;
  return jsonb_build_object('tamam', true);
end $$;

-- Moderatör: şikâyet edilen paylaşımlar
create or replace function public.admin_akis_sikayetleri() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  return coalesce((select jsonb_agg(x order by x->>'ilk' desc) from (
    select jsonb_build_object('id', a.id, 'kad', pr.kad, 'metin', a.metin, 'gizli', a.gizli, 'sayi', count(distinct s.sikayetci),
             'nedenler', jsonb_agg(distinct s.neden), 'ilk', min(s.zaman)) x
      from oyun.akis_sikayet s join oyun.akis a on a.id = s.akis_id join oyun.profiller pr on pr.id = a.user_id
     where s.durum = 'yeni' group by a.id, pr.kad, a.metin, a.gizli limit 100) q), '[]'::jsonb);
end $$;

create or replace function public.admin_akis_karar(p_id bigint, p_islem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); h oyun.profiller; a oyun.akis;
begin
  if p_islem not in ('yok_say', 'gizle', 'gizle_sustur1') then raise exception 'Geçersiz işlem.'; end if;
  select * into a from oyun.akis where id = p_id;
  if a.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  select * into h from oyun.profiller where id = a.user_id;
  if p_islem <> 'yok_say' then perform oyun.korunan_hedef(p, h.id); end if;
  perform oyun.mod_log(p, 'akis_' || p_islem, h.kad, a.metin);
  if p_islem = 'yok_say' then update oyun.akis set gizli = false where id = p_id; else update oyun.akis set gizli = true where id = p_id; end if;
  if p_islem = 'gizle_sustur1' then
    if not oyun.yetkili(p.id, 'sustur') then raise exception 'Susturma yetkin yok; yalnızca "Gizle" diyebilirsin.'; end if;
    update oyun.profiller set susturma_bitis = oyun.simdi() + interval '1 day' where id = h.id;
    perform oyun.bildir(h.id, 'Topluluk kurallarını ihlal eden bir paylaşımın kaldırıldı ve hesabın bir süre mesaj gönderemeyecek.');
  end if;
  update oyun.akis_sikayet set durum = 'incelendi' where akis_id = p_id;
  return public.admin_akis_sikayetleri();
end $$;

-- Eski paylaşımları temizle (30 gün); günlük özet işi (79) çağırır
create or replace function oyun.akis_temizle() returns void language sql as $$
  delete from oyun.akis where zaman < oyun.simdi() - interval '30 days'
$$;
revoke all on function oyun.akis_temizle() from public, anon, authenticated;

revoke all on function public.akis_yaz(text), public.akis_liste(text, text, bigint, int), public.akis_gundem(), public.akis_begen(bigint),
  public.akis_sil(bigint), public.akis_sikayet_et(bigint, text), public.admin_akis_sikayetleri(), public.admin_akis_karar(bigint, text)
  from public, anon;
grant execute on function public.akis_yaz(text), public.akis_liste(text, text, bigint, int), public.akis_gundem(), public.akis_begen(bigint),
  public.akis_sil(bigint), public.akis_sikayet_et(bigint, text), public.admin_akis_sikayetleri(), public.admin_akis_karar(bigint, text)
  to authenticated;
