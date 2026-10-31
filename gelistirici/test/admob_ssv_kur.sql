-- AdMob SSV fonksiyonlarını tam kurulum olmadan sınamak için asgari şema.
-- Gerçek ekonomi yerine sabit 250 ₺ ödül. Yalnız test.
create schema if not exists oyun;
create table if not exists oyun.profiller (id uuid primary key);
create table if not exists oyun.cuzdan (
  user_id uuid primary key references oyun.profiller(id),
  para numeric not null default 0,
  izle_n int not null default 0,
  son_izle timestamptz,
  gun date
);
create table if not exists oyun.ayarlar (id int primary key, test_simdi timestamptz);
insert into oyun.ayarlar(id) values (1) on conflict do nothing;
create table if not exists oyun.uygulama_ayar (
  anahtar text primary key,
  deger jsonb not null default 'null'::jsonb,
  aciklama text,
  herkese_acik boolean not null default true,
  guncelleme timestamptz not null default now()
);

create or replace function oyun.simdi() returns timestamptz language sql stable as $$
  select coalesce((select test_simdi from oyun.ayarlar where id = 1), now())
$$;
create or replace function oyun.profilim() returns oyun.profiller language plpgsql as $$
declare p oyun.profiller;
begin
  select * into p from oyun.profiller where id = nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  if not found then raise exception 'profil yok'; end if;
  return p;
end $$;
create or replace function oyun.cuzdanim(u uuid) returns oyun.cuzdan language plpgsql as $$
declare c oyun.cuzdan; t timestamptz := oyun.simdi();
begin
  insert into oyun.cuzdan(user_id) values (u) on conflict do nothing;
  update oyun.cuzdan set gun = (t at time zone 'Europe/Istanbul')::date, izle_n = 0
   where user_id = u and gun is distinct from (t at time zone 'Europe/Istanbul')::date;
  select * into c from oyun.cuzdan where user_id = u for update;
  return c;
end $$;
create or replace function oyun.reklamsiz(u uuid, t timestamptz default null) returns boolean language sql stable as $$
  select false
$$;
create or replace function oyun.gelir_hesap(u uuid, t timestamptz) returns jsonb language sql stable as $$
  select '{"reklam_odul": 250}'::jsonb
$$;
create or replace function oyun.para_islem(u uuid, p_tutar numeric, p_tur text, p_aciklama text, t timestamptz, p_vergi numeric default 0)
returns void language plpgsql as $$
begin
  update oyun.cuzdan set para = para + round(p_tutar) where user_id = u;
end $$;
create or replace function public.hayat() returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid; c oyun.cuzdan;
begin
  c := oyun.cuzdanim(u);
  return jsonb_build_object('para', c.para, 'reklam', jsonb_build_object('kalan', greatest(0, 5 - c.izle_n)),
    'sonuc', jsonb_build_object('odul', 0));
end $$;
