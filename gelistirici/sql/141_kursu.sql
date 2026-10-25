-- =====================================================================
--  141 · KÜRSÜ — oyunun sosyal medya platformu (26.10.2026)
--  Akış'ın üstüne kurulur; gönderiler, beğeni / beğenmeme, yanıtlar ve
--  #etiketler aynı tablolarda (oyun.akis*) kalır. Eklenenler:
--  · takip / takipçi (oyun.kursu_takip)
--  · yeniden paylaşım (oyun.kursu_yp) ve alıntı (oyun.akis.alinti_id)
--  · Kürsü profili: 160 karakterlik biyografi, kapak, sabitlenmiş gönderi
--  · "Sana özel" (etkileşim sıralı) ve "Takip" (zaman sıralı) akışları
--  · gündem: etiketler, en çok konuşulan kişiler, partiler, dernekler
--  · @anma bildirimi, Kürsü bildirimleri (beğeniler kimin verdiği
--    gösterilmeden toplu sayılır — Akış'ın gizlilik kuralı korunur)
--  Yalnız yeni tablo / sütun / fonksiyon ekler; iki kez çalıştırmak güvenlidir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. TABLOLAR
-- ---------------------------------------------------------------------
alter table oyun.akis add column if not exists alinti_id bigint references oyun.akis(id) on delete set null;
create index if not exists akis_alinti_idx on oyun.akis(alinti_id) where alinti_id is not null;
create index if not exists akis_user_zaman_idx on oyun.akis(user_id, zaman desc);
create index if not exists akis_yanit_idx on oyun.akis(yanit_id) where yanit_id is not null;

create table if not exists oyun.kursu_takip (
  takipci uuid not null references oyun.profiller(id) on delete cascade,
  takip_edilen uuid not null references oyun.profiller(id) on delete cascade,
  zaman timestamptz not null default now(),
  primary key (takipci, takip_edilen),
  check (takipci <> takip_edilen)
);
create index if not exists kursu_takip_edilen_idx on oyun.kursu_takip(takip_edilen, zaman desc);

-- İlk takipte bir kez bildirim gitsin (takip et / bırak döngüsüyle bildirim yağdırılmasın)
create table if not exists oyun.kursu_takip_gecmis (
  takipci uuid not null references oyun.profiller(id) on delete cascade,
  takip_edilen uuid not null references oyun.profiller(id) on delete cascade,
  primary key (takipci, takip_edilen)
);

create table if not exists oyun.kursu_yp (
  akis_id bigint not null references oyun.akis(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  zaman timestamptz not null default now(),
  primary key (akis_id, user_id)
);
create index if not exists kursu_yp_user_idx on oyun.kursu_yp(user_id, zaman desc);

create table if not exists oyun.kursu_profil (
  user_id uuid primary key references oyun.profiller(id) on delete cascade,
  bio text check (bio is null or char_length(bio) <= 160),
  kapak text,
  sabit_id bigint references oyun.akis(id) on delete set null,
  bildirim_okundu timestamptz,
  guncelleme timestamptz
);

alter table oyun.kursu_takip enable row level security;
alter table oyun.kursu_takip_gecmis enable row level security;
alter table oyun.kursu_yp enable row level security;
alter table oyun.kursu_profil enable row level security;

-- ---------------------------------------------------------------------
-- B. YARDIMCILAR
-- ---------------------------------------------------------------------
create or replace function oyun.kursu_engelli(a uuid, b uuid) returns boolean
language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.engellemeler g where (g.engelleyen = a and g.engellenen = b) or (g.engelleyen = b and g.engellenen = a))
$$;

create or replace function oyun.kursu_alinti_json(p_id bigint) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', a.id, 'kad', pr.kad, 'unvan', oyun.unvan(a.user_id), 'parti', oyun.parti_json(a.parti_id),
                            'metin', a.metin, 'zaman', a.zaman)
    from oyun.akis a join oyun.profiller pr on pr.id = a.user_id
   where a.id = p_id and not a.gizli
$$;

-- Akış gönderisi + Kürsü alanları
create or replace function oyun.kursu_json(a oyun.akis, ben uuid) returns jsonb
language sql stable set search_path = '' as $$
  select oyun.akis_json(a, ben) || jsonb_build_object(
    'yp', (select count(*) from oyun.kursu_yp y where y.akis_id = a.id),
    'ypledim', exists (select 1 from oyun.kursu_yp y where y.akis_id = a.id and y.user_id = ben),
    'alinti_sayi', (select count(*) from oyun.akis q where q.alinti_id = a.id and not q.gizli),
    'alinti', case when a.alinti_id is not null then oyun.kursu_alinti_json(a.alinti_id) end,
    'yanit_kad', case when a.yanit_id is not null then (select pr.kad from oyun.akis u join oyun.profiller pr on pr.id = u.user_id where u.id = a.yanit_id) end,
    'takip_ediyorum', exists (select 1 from oyun.kursu_takip t where t.takipci = ben and t.takip_edilen = a.user_id))
$$;

create or replace function oyun.kursu_bio(u uuid) returns text
language sql stable set search_path = '' as $$
  select coalesce((select nullif(btrim(bio), '') from oyun.kursu_profil where user_id = u),
                  (select left(regexp_replace(btrim(k.biyografi), '\s+', ' ', 'g'), 160) from oyun.oyuncu_kimlik k where k.user_id = u))
$$;

create or replace function oyun.kursu_kisi_json(u uuid, ben uuid) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('kad', p.kad, 'unvan', oyun.unvan(p.id), 'parti', oyun.parti_json(p.parti_id),
           'bio', oyun.kursu_bio(p.id),
           'takipci', (select count(*) from oyun.kursu_takip t where t.takip_edilen = p.id),
           'takip_ediyorum', exists (select 1 from oyun.kursu_takip t where t.takipci = ben and t.takip_edilen = p.id),
           'beni_takip_ediyor', exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = ben),
           'benim', p.id = ben)
    from oyun.profiller p where p.id = u
$$;

-- @anma bildirimi (gönderi başına en çok 3 kişi)
create or replace function oyun.tg_kursu_anma() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record; v_kad text; v_u uuid; n integer := 0;
begin
  if new.gizli then return new; end if;
  select kad into v_kad from oyun.profiller where id = new.user_id;
  for r in select distinct lower(m[1]) k from regexp_matches(new.metin, '@([[:alnum:]_.]{2,30})', 'g') m loop
    exit when n >= 3;
    v_u := null;
    select id into v_u from oyun.profiller where lower(kad) = r.k and not yasakli;
    if v_u is not null and v_u <> new.user_id and not oyun.kursu_engelli(v_u, new.user_id)
       and not exists (select 1 from oyun.akis y where y.id = new.yanit_id and y.user_id = v_u) then
      perform oyun.bildir(v_u, format('Kürsü: %s senden bahsetti: %s', v_kad, left(new.metin, 90)), new.zaman);
      n := n + 1;
    end if;
  end loop;
  return new;
end $$;
create or replace trigger kursu_anma after insert on oyun.akis for each row execute function oyun.tg_kursu_anma();

-- ---------------------------------------------------------------------
-- C. AKIŞLAR
-- ---------------------------------------------------------------------
-- p_sekme: 'sana' (etkileşim + tazelik sıralı; p_imlec = atlanacak adet),
--          'takip' / 'il' / 'parti' / 'herkes' (zaman sıralı; p_imlec = son öğenin zamanı)
create or replace function public.kursu_akis(p_sekme text default 'sana', p_imlec text default null, p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 40);
  v_t timestamptz := oyun.simdi(); v_once timestamptz; v_atla integer := 0; v_liste jsonb;
begin
  if p_sekme not in ('sana','takip','il','parti','herkes') then raise exception 'Geçersiz akış.'; end if;
  if p_sekme = 'sana' then
    v_atla := greatest(0, least(coalesce(nullif(p_imlec, '')::integer, 0), 400));
    select coalesce(jsonb_agg(jsonb_build_object('sira', x.skor, 'yp', null, 'g', oyun.kursu_json(a, p.id)) order by x.skor desc, a.id desc), '[]'::jsonb)
      into v_liste
      from (select a.id, ((
                (select count(*) from oyun.akis_begeni b where b.akis_id = a.id) * 2
              + (select count(*) from oyun.akis y where y.yanit_id = a.id and not y.gizli) * 3
              + (select count(*) from oyun.kursu_yp y where y.akis_id = a.id) * 4
              + (select count(*) from oyun.akis q where q.alinti_id = a.id and not q.gizli) * 3
              - (select count(*) from oyun.akis_begenmeme b where b.akis_id = a.id)
              + case when exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = a.user_id) then 6 else 0 end
              + case when p.parti_id is not null and a.parti_id = p.parti_id then 2 else 0 end
              + case when a.il_id = p.il_id then 1 else 0 end + 1)::numeric
              / power(extract(epoch from (v_t - a.zaman)) / 3600 + 2, 1.35)) as skor
              from oyun.akis a
             where not a.gizli and a.yanit_id is null and a.zaman > v_t - interval '7 days'
               and not oyun.kursu_engelli(p.id, a.user_id)
             order by 2 desc, a.id desc offset v_atla limit v_lim) x
      join oyun.akis a on a.id = x.id;
    return jsonb_build_object('liste', v_liste, 'imlec', case when jsonb_array_length(v_liste) = v_lim then (v_atla + v_lim)::text end);
  end if;
  v_once := coalesce(nullif(p_imlec, '')::timestamptz, 'infinity'::timestamptz);
  with u as (
    select a.id akis_id, a.zaman sira, null::text yp_kad from oyun.akis a
     where not a.gizli and a.yanit_id is null and a.zaman < v_once
       and (p_sekme = 'herkes'
         or (p_sekme = 'il' and a.il_id = p.il_id)
         or (p_sekme = 'parti' and p.parti_id is not null and a.parti_id = p.parti_id)
         or (p_sekme = 'takip' and (a.user_id = p.id or exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = a.user_id))))
    union all
    select y.akis_id, y.zaman, pr.kad from oyun.kursu_yp y join oyun.profiller pr on pr.id = y.user_id
     where p_sekme = 'takip' and y.zaman < v_once
       and (y.user_id = p.id or exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = y.user_id))
  ), d as (
    select distinct on (akis_id) akis_id, sira, yp_kad from u order by akis_id, sira desc
  ), s as (
    select d.* from d join oyun.akis a on a.id = d.akis_id and not a.gizli
     where not oyun.kursu_engelli(p.id, a.user_id) order by d.sira desc limit v_lim
  )
  select coalesce(jsonb_agg(jsonb_build_object('sira', s.sira, 'yp', s.yp_kad, 'g', oyun.kursu_json(a, p.id)) order by s.sira desc), '[]'::jsonb)
    into v_liste from s join oyun.akis a on a.id = s.akis_id;
  return jsonb_build_object('liste', v_liste,
    'imlec', case when jsonb_array_length(v_liste) = v_lim then (v_liste -> (v_lim - 1) ->> 'sira') end);
end $$;

-- Bir gönderi ve konuşması
create or replace function public.kursu_gonderi(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.akis; ana oyun.akis;
begin
  select * into a from oyun.akis where id = p_id and not gizli;
  if a.id is null then raise exception 'Gönderi bulunamadı ya da silinmiş.'; end if;
  ana := a;
  if a.yanit_id is not null then select * into ana from oyun.akis where id = a.yanit_id and not gizli; end if;
  if ana.id is null then ana := a; end if;
  if oyun.kursu_engelli(p.id, ana.user_id) then raise exception 'Bu kullanıcıyla aranızda engelleme var.'; end if;
  return jsonb_build_object('ana', oyun.kursu_json(ana, p.id), 'odak', a.id,
    'yanitlar', coalesce((select jsonb_agg(oyun.kursu_json(y, p.id) order by y.id) from oyun.akis y
                           where y.yanit_id = ana.id and not y.gizli and not oyun.kursu_engelli(p.id, y.user_id)), '[]'::jsonb),
    'alintilar', coalesce((select jsonb_agg(oyun.kursu_json(q, p.id) order by q.id desc) from (select * from oyun.akis q2
                           where q2.alinti_id = ana.id and not q2.gizli and not oyun.kursu_engelli(p.id, q2.user_id) order by q2.id desc limit 10) q), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- D. ETKİLEŞİM
-- ---------------------------------------------------------------------
create or replace function public.kursu_yp(p_id bigint, p_ac boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.akis; v_t timestamptz := oyun.simdi();
begin
  select * into a from oyun.akis where id = p_id and not gizli;
  if a.id is null then raise exception 'Gönderi bulunamadı.'; end if;
  if oyun.kursu_engelli(p.id, a.user_id) then raise exception 'Bu kullanıcıyla aranızda engelleme var.'; end if;
  if p_ac then
    if (select count(*) from oyun.kursu_yp where user_id = p.id and zaman > v_t - interval '1 hour') >= 60 then
      raise exception 'Bir saatte çok fazla yeniden paylaşım yaptın, biraz bekle.'; end if;
    insert into oyun.kursu_yp(akis_id, user_id, zaman) values (a.id, p.id, v_t) on conflict do nothing;
  else
    delete from oyun.kursu_yp where akis_id = a.id and user_id = p.id;
  end if;
  return jsonb_build_object('yp', (select count(*) from oyun.kursu_yp where akis_id = a.id),
                            'ypledim', exists (select 1 from oyun.kursu_yp where akis_id = a.id and user_id = p.id));
end $$;

create or replace function public.kursu_alinti(p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.akis; r jsonb; v_yeni bigint;
begin
  select * into a from oyun.akis where id = p_id and not gizli;
  if a.id is null then raise exception 'Gönderi bulunamadı.'; end if;
  if oyun.kursu_engelli(p.id, a.user_id) then raise exception 'Bu kullanıcıyla aranızda engelleme var.'; end if;
  r := public.akis_yaz(p_metin);
  v_yeni := (r->>'id')::bigint;
  update oyun.akis set alinti_id = a.id where id = v_yeni;
  if a.user_id <> p.id then
    perform oyun.bildir(a.user_id, format('Kürsü: %s gönderini alıntıladı: %s', p.kad, left(btrim(p_metin), 80)));
  end if;
  return jsonb_build_object('tamam', true, 'id', v_yeni);
end $$;

create or replace function public.kursu_takip_et(p_kad text, p_takip boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_u uuid; v_t timestamptz := oyun.simdi();
begin
  select id into v_u from oyun.profiller where lower(kad) = lower(btrim(p_kad)) and not yasakli;
  if v_u is null then raise exception 'Kullanıcı bulunamadı.'; end if;
  if v_u = p.id then raise exception 'Kendini takip edemezsin.'; end if;
  if p_takip then
    if oyun.kursu_engelli(p.id, v_u) then raise exception 'Bu kullanıcıyla aranızda engelleme var.'; end if;
    if (select count(*) from oyun.kursu_takip where takipci = p.id and zaman > v_t - interval '1 day') >= 150 then
      raise exception 'Bugün çok fazla kişiyi takip ettin; yarın devam edebilirsin.'; end if;
    insert into oyun.kursu_takip(takipci, takip_edilen, zaman) values (p.id, v_u, v_t) on conflict do nothing;
    insert into oyun.kursu_takip_gecmis(takipci, takip_edilen) values (p.id, v_u) on conflict do nothing;
    if found then perform oyun.bildir(v_u, format('Kürsü: %s seni takip etmeye başladı.', p.kad), v_t); end if;
  else
    delete from oyun.kursu_takip where takipci = p.id and takip_edilen = v_u;
  end if;
  return oyun.kursu_kisi_json(v_u, p.id);
end $$;

create or replace function public.kursu_profil_guncelle(p_bio text, p_kapak text, p_sabit bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); b text := nullif(btrim(coalesce(p_bio, '')), '');
begin
  if b is not null and char_length(b) > 160 then raise exception 'Kürsü biyografisi en fazla 160 karakter olabilir.'; end if;
  if b is not null and oyun.kufurlu(b) then raise exception 'Biyografinde uygunsuz bir ifade var. Hakaret ve küfür yasaktır.'; end if;
  if b is not null and b ~* '(https?://|www\.|\.com\b|t\.me/)' then raise exception 'Biyografide bağlantı kullanılamaz.'; end if;
  if p_kapak is not null and p_kapak not in ('mor','gece','gun','deniz','orman','gul','altin','kizil','meclis','yildiz') then raise exception 'Geçersiz kapak.'; end if;
  if p_sabit is not null and not exists (select 1 from oyun.akis where id = p_sabit and user_id = p.id and yanit_id is null and not gizli) then
    raise exception 'Yalnız kendi gönderini sabitleyebilirsin.'; end if;
  insert into oyun.kursu_profil(user_id, bio, kapak, sabit_id, guncelleme) values (p.id, b, p_kapak, p_sabit, oyun.simdi())
  on conflict (user_id) do update set bio = excluded.bio, kapak = excluded.kapak, sabit_id = excluded.sabit_id, guncelleme = excluded.guncelleme;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.kursu_sabitle(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if p_id is not null and not exists (select 1 from oyun.akis where id = p_id and user_id = p.id and yanit_id is null and not gizli) then
    raise exception 'Yalnız kendi gönderini sabitleyebilirsin.'; end if;
  insert into oyun.kursu_profil(user_id, sabit_id, guncelleme) values (p.id, p_id, oyun.simdi())
  on conflict (user_id) do update set sabit_id = excluded.sabit_id, guncelleme = excluded.guncelleme;
  return jsonb_build_object('tamam', true, 'sabit_id', p_id);
end $$;

-- ---------------------------------------------------------------------
-- E. PROFİL, KİŞİLER
-- ---------------------------------------------------------------------
-- p_sekme: 'gonderi' (gönderiler + yeniden paylaşımlar), 'yanit', 'one_cikan' (en çok etkileşim alanlar)
create or replace function public.kursu_profil(p_kad text, p_sekme text default 'gonderi', p_imlec text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; kp oyun.kursu_profil; v_once timestamptz; v_liste jsonb; v_lim integer := 20;
begin
  select * into h from oyun.profiller where lower(kad) = lower(btrim(p_kad));
  if h.id is null or (h.yasakli and h.id <> p.id) then raise exception 'Kullanıcı bulunamadı.'; end if;
  if p_sekme not in ('gonderi','yanit','one_cikan') then raise exception 'Geçersiz sekme.'; end if;
  select * into kp from oyun.kursu_profil where user_id = h.id;
  v_once := coalesce(nullif(p_imlec, '')::timestamptz, 'infinity'::timestamptz);
  if oyun.kursu_engelli(p.id, h.id) then
    v_liste := '[]'::jsonb;
  elsif p_sekme = 'gonderi' then
    with u as (
      select a.id akis_id, a.zaman sira, null::text yp_kad from oyun.akis a where a.user_id = h.id and not a.gizli and a.yanit_id is null and a.zaman < v_once
      union all
      select y.akis_id, y.zaman, h.kad from oyun.kursu_yp y join oyun.akis a on a.id = y.akis_id and not a.gizli where y.user_id = h.id and y.zaman < v_once
    ), s as (select distinct on (akis_id) akis_id, sira, yp_kad from u order by akis_id, sira desc),
    l as (select * from s order by sira desc limit v_lim)
    select coalesce(jsonb_agg(jsonb_build_object('sira', l.sira, 'yp', l.yp_kad, 'g', oyun.kursu_json(a, p.id)) order by l.sira desc), '[]'::jsonb)
      into v_liste from l join oyun.akis a on a.id = l.akis_id;
  elsif p_sekme = 'yanit' then
    select coalesce(jsonb_agg(jsonb_build_object('sira', a.zaman, 'yp', null, 'g', oyun.kursu_json(a, p.id)) order by a.zaman desc), '[]'::jsonb)
      into v_liste from (select * from oyun.akis a2 where a2.user_id = h.id and not a2.gizli and a2.yanit_id is not null and a2.zaman < v_once order by a2.zaman desc limit v_lim) a;
  else
    select coalesce(jsonb_agg(jsonb_build_object('sira', x.puan, 'yp', null, 'g', oyun.kursu_json(a, p.id)) order by x.puan desc), '[]'::jsonb)
      into v_liste from (select a2.id, (select count(*) from oyun.akis_begeni b where b.akis_id = a2.id) * 2
                                   + (select count(*) from oyun.kursu_yp y where y.akis_id = a2.id) * 4
                                   + (select count(*) from oyun.akis r where r.yanit_id = a2.id and not r.gizli) * 3 puan
                           from oyun.akis a2 where a2.user_id = h.id and not a2.gizli and a2.yanit_id is null
                          order by 2 desc, a2.id desc limit 10) x join oyun.akis a on a.id = x.id;
    v_once := null;
  end if;
  return jsonb_build_object(
    'kisi', oyun.kursu_kisi_json(h.id, p.id) || jsonb_build_object(
       'il', (select ad from oyun.iller where id = h.il_id), 'katilim', h.olusturma, 'kapak', coalesce(kp.kapak, 'mor'),
       'bio_kendi', kp.bio,
       'takip', (select count(*) from oyun.kursu_takip t where t.takipci = h.id),
       'gonderi', (select count(*) from oyun.akis a where a.user_id = h.id and not a.gizli),
       'begeni_alinan', (select count(*) from oyun.akis_begeni b join oyun.akis a on a.id = b.akis_id where a.user_id = h.id),
       'engelli', oyun.kursu_engelli(p.id, h.id),
       'ortak', (select count(*) from oyun.kursu_takip t1 join oyun.kursu_takip t2 on t2.takip_edilen = t1.takip_edilen
                  where t1.takipci = p.id and t2.takipci = h.id)),
    'sabit', case when kp.sabit_id is not null and p_sekme = 'gonderi' and p_imlec is null then
               (select oyun.kursu_json(a, p.id) from oyun.akis a where a.id = kp.sabit_id and not a.gizli) end,
    'liste', v_liste,
    'imlec', case when p_sekme <> 'one_cikan' and jsonb_array_length(v_liste) = v_lim then (v_liste -> (v_lim - 1) ->> 'sira') end);
end $$;

create or replace function public.kursu_takip_listesi(p_kad text, p_tur text default 'takipci')
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_u uuid;
begin
  select id into v_u from oyun.profiller where lower(kad) = lower(btrim(p_kad));
  if v_u is null then raise exception 'Kullanıcı bulunamadı.'; end if;
  if p_tur = 'takipci' then
    return coalesce((select jsonb_agg(oyun.kursu_kisi_json(t.takipci, p.id) order by t.zaman desc) from oyun.kursu_takip t
                      join oyun.profiller x on x.id = t.takipci and not x.yasakli where t.takip_edilen = v_u), '[]'::jsonb);
  end if;
  return coalesce((select jsonb_agg(oyun.kursu_kisi_json(t.takip_edilen, p.id) order by t.zaman desc) from oyun.kursu_takip t
                    join oyun.profiller x on x.id = t.takip_edilen and not x.yasakli where t.takipci = v_u), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- F. GÜNDEM, ARAMA, BİLDİRİMLER
-- ---------------------------------------------------------------------
create or replace function public.kursu_gundem()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); v_bas timestamptz; v_saat integer := 48;
  v_et jsonb; v_kisi jsonb; v_parti jsonb; v_dernek jsonb;
begin
  if (select count(*) from oyun.akis where zaman > v_t - interval '48 hours' and not gizli) < 15 then v_saat := 168; end if;
  v_bas := v_t - make_interval(hours => v_saat);
  -- 1) Etiketler: en çok gönderi atılandan en aza
  select coalesce(jsonb_agg(x order by (x->>'sayi')::int desc, (x->>'kisi')::int desc), '[]'::jsonb) into v_et from (
    select jsonb_build_object('tur', 'etiket', 'ad', '#' || e.etiket, 'anahtar', e.etiket, 'sayi', count(*), 'kisi', count(distinct e.user_id)) x
      from oyun.akis_etiket e join oyun.akis a on a.id = e.akis_id and not a.gizli
     where e.zaman > v_bas group by e.etiket order by count(*) desc, count(distinct e.user_id) desc limit 20) t;
  -- 2) En çok konuşulan kişiler: @anma ×3 + aldığı yanıt ×2 + yeniden paylaşım ×2 + beğeni
  select coalesce(jsonb_agg(x order by (x->>'puan')::numeric desc), '[]'::jsonb) into v_kisi from (
    select jsonb_build_object('tur', 'kisi', 'ad', pr.kad, 'anahtar', pr.kad, 'unvan', oyun.unvan(pr.id), 'parti', oyun.parti_json(pr.parti_id),
             'sayi', z.anma + z.yanit, 'anma', z.anma, 'puan', z.anma * 3 + z.yanit * 2 + z.yp * 2 + z.begeni,
             'takip_ediyorum', exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = pr.id)) x
      from (select u.id,
                   (select count(*) from oyun.akis a where a.zaman > v_bas and not a.gizli and a.user_id <> u.id and a.metin ~* ('@' || regexp_replace(u.kad, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g') || '($|[^[:alnum:]_])')) anma,
                   (select count(*) from oyun.akis r join oyun.akis a on a.id = r.yanit_id where a.user_id = u.id and r.user_id <> u.id and r.zaman > v_bas and not r.gizli) yanit,
                   (select count(*) from oyun.kursu_yp y join oyun.akis a on a.id = y.akis_id where a.user_id = u.id and y.user_id <> u.id and y.zaman > v_bas) yp,
                   (select count(*) from oyun.akis_begeni b join oyun.akis a on a.id = b.akis_id where a.user_id = u.id and b.zaman > v_bas) begeni
              from oyun.profiller u
             where not u.yasakli and exists (select 1 from oyun.akis a where a.user_id = u.id and a.zaman > v_t - interval '30 days')) z
      join oyun.profiller pr on pr.id = z.id
     where z.anma * 3 + z.yanit * 2 + z.yp * 2 + z.begeni > 0
     order by z.anma * 3 + z.yanit * 2 + z.yp * 2 + z.begeni desc limit 10) t;
  -- 3) Partiler: adı ya da kısaltması geçen gönderi sayısı
  select coalesce(jsonb_agg(x order by (x->>'sayi')::int desc), '[]'::jsonb) into v_parti from (
    select jsonb_build_object('tur', 'parti', 'ad', pa.ad, 'anahtar', pa.id, 'parti', oyun.parti_json(pa.id), 'sayi', c.n) x
      from oyun.partiler pa
      cross join lateral (select count(*) n from oyun.akis a where a.zaman > v_bas and not a.gizli
                            and (lower(a.metin) like '%' || lower(pa.ad) || '%'
                              or (char_length(pa.kisa) >= 2 and a.metin ~ ('(^|[^[:alnum:]])' || regexp_replace(pa.kisa, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g') || '($|[^[:alnum:]])')))) c
     where not pa.kapali and c.n > 0 order by c.n desc limit 8) t;
  -- 4) Dernekler
  select coalesce(jsonb_agg(x order by (x->>'sayi')::int desc), '[]'::jsonb) into v_dernek from (
    select jsonb_build_object('tur', 'dernek', 'ad', d.ad, 'anahtar', d.id, 'sayi', c.n) x
      from oyun.dernekler d
      cross join lateral (select count(*) n from oyun.akis a where a.zaman > v_bas and not a.gizli and lower(a.metin) like '%' || lower(d.ad) || '%') c
     where not coalesce(d.kapali, false) and c.n > 0 order by c.n desc limit 8) t;
  return jsonb_build_object('saat', v_saat, 'etiketler', v_et, 'kisiler', v_kisi, 'partiler', v_parti, 'dernekler', v_dernek,
    'oneriler', coalesce((select jsonb_agg(oyun.kursu_kisi_json(x.id, p.id) order by x.takipci desc, x.son desc) from (
        select u.id, (select count(*) from oyun.kursu_takip t where t.takip_edilen = u.id) takipci,
               (select max(a.zaman) from oyun.akis a where a.user_id = u.id) son
          from oyun.profiller u
         where not u.yasakli and u.id <> p.id
           and not exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = u.id)
           and not oyun.kursu_engelli(p.id, u.id)
           and exists (select 1 from oyun.akis a where a.user_id = u.id and a.zaman > v_t - interval '7 days')
         order by 2 desc, 3 desc nulls last limit 6) x), '[]'::jsonb));
end $$;

create or replace function public.kursu_ara(p_q text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); q text := btrim(coalesce(p_q, '')); v_q text;
begin
  if char_length(q) < 2 then return jsonb_build_object('kisiler', '[]'::jsonb, 'etiketler', '[]'::jsonb, 'gonderiler', '[]'::jsonb); end if;
  v_q := replace(replace(replace(lower(regexp_replace(q, '^[#@]', '')), '\', '\\'), '%', '\%'), '_', '\_');
  return jsonb_build_object(
    'kisiler', coalesce((select jsonb_agg(oyun.kursu_kisi_json(u.id, p.id) order by (lower(u.kad) = v_q) desc, char_length(u.kad))
                           from (select * from oyun.profiller u2 where not u2.yasakli and lower(u2.kad) like '%' || v_q || '%' order by char_length(u2.kad) limit 8) u), '[]'::jsonb),
    'etiketler', coalesce((select jsonb_agg(jsonb_build_object('ad', '#' || x.etiket, 'anahtar', x.etiket, 'sayi', x.n) order by x.n desc)
                           from (select e.etiket, count(*) n from oyun.akis_etiket e where e.etiket like v_q || '%' group by e.etiket order by count(*) desc limit 6) x), '[]'::jsonb),
    'gonderiler', coalesce((select jsonb_agg(oyun.kursu_json(a, p.id) order by a.id desc) from (
        select * from oyun.akis a2 where not a2.gizli and a2.zaman > oyun.simdi() - interval '60 days' and lower(a2.metin) like '%' || v_q || '%'
           and not oyun.kursu_engelli(p.id, a2.user_id) order by a2.id desc limit 20) a), '[]'::jsonb));
end $$;

-- Etikete göre gönderiler (en yeniden eskiye)
create or replace function public.kursu_etiket(p_etiket text, p_imlec text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); et text := lower(regexp_replace(btrim(coalesce(p_etiket, '')), '^#', '')); v_once bigint; v_liste jsonb;
begin
  v_once := coalesce(nullif(p_imlec, '')::bigint, 9223372036854775807);
  select coalesce(jsonb_agg(jsonb_build_object('sira', a.id, 'yp', null, 'g', oyun.kursu_json(a, p.id)) order by a.id desc), '[]'::jsonb) into v_liste
    from (select * from oyun.akis a2 where not a2.gizli and a2.id < v_once
            and exists (select 1 from oyun.akis_etiket e where e.akis_id = a2.id and e.etiket = et)
            and not oyun.kursu_engelli(p.id, a2.user_id) order by a2.id desc limit 20) a;
  return jsonb_build_object('etiket', et, 'liste', v_liste,
    'sayi', (select count(*) from oyun.akis_etiket e join oyun.akis a on a.id = e.akis_id and not a.gizli where e.etiket = et),
    'imlec', case when jsonb_array_length(v_liste) = 20 then (v_liste -> 19 ->> 'sira') end);
end $$;

-- Kürsü bildirimleri (son 7 gün). Beğeniler kimin verdiği gösterilmeden toplu sayılır.
create or replace function public.kursu_bildirimler(p_okundu boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_t timestamptz := oyun.simdi(); v_bas timestamptz := oyun.simdi() - interval '7 days';
  v_okundu timestamptz; v_liste jsonb; v_kadre text;
begin
  select bildirim_okundu into v_okundu from oyun.kursu_profil where user_id = p.id;
  v_kadre := '@' || regexp_replace(p.kad, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g') || '($|[^[:alnum:]_])';
  select coalesce(jsonb_agg(x order by (x->>'zaman') desc), '[]'::jsonb) into v_liste from (
    select * from (
      select jsonb_build_object('tur', 'takip', 'kad', pr.kad, 'zaman', t.zaman, 'kisi', oyun.kursu_kisi_json(pr.id, p.id)) x, t.zaman z
        from oyun.kursu_takip t join oyun.profiller pr on pr.id = t.takipci where t.takip_edilen = p.id and t.zaman > v_bas
      union all
      select jsonb_build_object('tur', 'yp', 'kad', pr.kad, 'zaman', y.zaman, 'g', oyun.kursu_alinti_json(a.id)), y.zaman
        from oyun.kursu_yp y join oyun.akis a on a.id = y.akis_id and a.user_id = p.id join oyun.profiller pr on pr.id = y.user_id
       where y.user_id <> p.id and y.zaman > v_bas
      union all
      select jsonb_build_object('tur', 'yanit', 'kad', pr.kad, 'zaman', r.zaman, 'g', oyun.kursu_json(r, p.id)), r.zaman
        from oyun.akis r join oyun.akis a on a.id = r.yanit_id and a.user_id = p.id join oyun.profiller pr on pr.id = r.user_id
       where r.user_id <> p.id and not r.gizli and r.zaman > v_bas and not oyun.kursu_engelli(p.id, r.user_id)
      union all
      select jsonb_build_object('tur', 'alinti', 'kad', pr.kad, 'zaman', q.zaman, 'g', oyun.kursu_json(q, p.id)), q.zaman
        from oyun.akis q join oyun.akis a on a.id = q.alinti_id and a.user_id = p.id join oyun.profiller pr on pr.id = q.user_id
       where q.user_id <> p.id and not q.gizli and q.zaman > v_bas
      union all
      select jsonb_build_object('tur', 'anma', 'kad', pr.kad, 'zaman', m.zaman, 'g', oyun.kursu_json(m, p.id)), m.zaman
        from oyun.akis m join oyun.profiller pr on pr.id = m.user_id
       where m.user_id <> p.id and not m.gizli and m.zaman > v_bas and m.metin ~* v_kadre and not oyun.kursu_engelli(p.id, m.user_id)
      union all
      select jsonb_build_object('tur', 'begeni', 'sayi', count(*), 'zaman', max(b.zaman), 'g', oyun.kursu_alinti_json(a.id)), max(b.zaman)
        from oyun.akis_begeni b join oyun.akis a on a.id = b.akis_id and a.user_id = p.id
       where b.user_id <> p.id and b.zaman > v_bas group by a.id
    ) u order by z desc limit 60) t;
  if p_okundu then
    insert into oyun.kursu_profil(user_id, bildirim_okundu) values (p.id, v_t)
    on conflict (user_id) do update set bildirim_okundu = excluded.bildirim_okundu;
  end if;
  return jsonb_build_object('liste', v_liste, 'okundu', v_okundu,
    'yeni', (select count(*) from jsonb_array_elements(v_liste) e where (e->>'zaman')::timestamptz > coalesce(v_okundu, '-infinity'::timestamptz)));
end $$;

-- Kürsü özeti (rozet ve kendi profil bilgisi için hafif çağrı)
create or replace function public.kursu_ben()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_okundu timestamptz;
begin
  select bildirim_okundu into v_okundu from oyun.kursu_profil where user_id = p.id;
  return oyun.kursu_kisi_json(p.id, p.id) || jsonb_build_object(
    'takip', (select count(*) from oyun.kursu_takip t where t.takipci = p.id),
    'yeni', (select count(*) from oyun.kursu_takip t where t.takip_edilen = p.id and t.zaman > coalesce(v_okundu, oyun.simdi() - interval '7 days'))
          + (select count(*) from oyun.akis r join oyun.akis a on a.id = r.yanit_id and a.user_id = p.id where r.user_id <> p.id and not r.gizli and r.zaman > coalesce(v_okundu, oyun.simdi() - interval '7 days'))
          + (select count(*) from oyun.kursu_yp y join oyun.akis a on a.id = y.akis_id and a.user_id = p.id where y.user_id <> p.id and y.zaman > coalesce(v_okundu, oyun.simdi() - interval '7 days')));
end $$;

-- ---------------------------------------------------------------------
-- G. YETKİLER
-- ---------------------------------------------------------------------
do $yetki$
declare f text;
begin
  foreach f in array array[
    'public.kursu_akis(text,text,integer)', 'public.kursu_gonderi(bigint)', 'public.kursu_yp(bigint,boolean)',
    'public.kursu_alinti(bigint,text)', 'public.kursu_takip_et(text,boolean)', 'public.kursu_profil_guncelle(text,text,bigint)',
    'public.kursu_sabitle(bigint)', 'public.kursu_profil(text,text,text)', 'public.kursu_takip_listesi(text,text)',
    'public.kursu_gundem()', 'public.kursu_ara(text)', 'public.kursu_etiket(text,text)', 'public.kursu_bildirimler(boolean)',
    'public.kursu_ben()']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['oyun.tg_kursu_anma()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $yetki$;
