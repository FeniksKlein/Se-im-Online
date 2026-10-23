-- 2026-10-23: Milli Piyango ve Kazı Kazan kalıcı olarak kaldırıldı.
-- Oyuncuların geçmiş işlemleri, ikramiyeleri ve kayıtları silinmez.
-- Çekilişi yapılmamış biletlerin bedeli tam iade edilir (idempotent).
-- Eski mobil sürümlerin RPC üzerinden işlem yapması da önlenir.

-- Piyango fonksiyonunun kullandığı kilit: eşzamanlı bilet alışları kapanmadan iade başlamasın.
select pg_advisory_xact_lock(77890011);

create table if not exists oyun.piyango_iadeleri (
  bilet_id bigint primary key references oyun.piyango_bilet(id),
  user_id uuid not null references auth.users(id),
  tutar numeric not null check (tutar >= 0),
  iade_at timestamptz not null default now()
);
alter table oyun.piyango_iadeleri enable row level security;
revoke all on oyun.piyango_iadeleri from public, anon, authenticated;
alter table oyun.piyango_donem add column if not exists iptal_edildi boolean not null default false;

-- İşlev imzalarını koru: yayımlanmış eski uygulamalar hata alır, cüzdanlara dokunmaz.
create or replace function public.piyango_bilet_al(p_adet integer default 1)
returns jsonb language plpgsql security definer
set search_path = 'oyun','public','pg_temp' as $$
begin
  raise exception 'Milli Piyango oyundan kaldırıldı. Bekleyen bilet ücretleri iade edildi.';
end $$;

create or replace function public.kazikazan_oyna()
returns jsonb language plpgsql security definer
set search_path = 'oyun','public','pg_temp' as $$
begin
  raise exception 'Kazı Kazan oyundan kaldırıldı.';
end $$;

create or replace function public.piyango_durum()
returns jsonb language plpgsql security definer
set search_path = 'oyun','public','pg_temp' as $$
begin
  raise exception 'Milli Piyango oyundan kaldırıldı. Bekleyen bilet ücretleri iade edildi.';
end $$;

create or replace function public.kazikazan_durum()
returns jsonb language plpgsql security definer
set search_path = 'oyun','public','pg_temp' as $$
begin
  raise exception 'Kazı Kazan oyundan kaldırıldı.';
end $$;

-- Haftalık çekilişleri ve yeni dönem açılışlarını durdur, mevcut dönemi sakla.
create or replace function oyun.piyango_guncelle()
returns bigint language plpgsql security definer
set search_path = 'oyun','public','pg_temp' as $$
begin
  return (select id from oyun.piyango_donem order by id desc limit 1);
end $$;
revoke all on function oyun.piyango_guncelle() from public, anon, authenticated;

-- Açık dönemleri iptal et, her bilet için tekil iade kayıtlarını tut.
update oyun.piyango_donem set iptal_edildi = true
where not cekildi and not iptal_edildi;

do $$
declare
  kisi record;
  iade numeric;
  adet integer;
begin
  for kisi in
    select distinct b.user_id
    from oyun.piyango_bilet b
    join oyun.piyango_donem d on d.id = b.donem_id
    where d.iptal_edildi and not d.cekildi
  loop
    with yeni as (
      insert into oyun.piyango_iadeleri (bilet_id, user_id, tutar)
      select b.id, b.user_id, b.bedel
      from oyun.piyango_bilet b
      join oyun.piyango_donem d on d.id = b.donem_id
      where d.iptal_edildi and not d.cekildi and b.user_id = kisi.user_id
      on conflict (bilet_id) do nothing
      returning tutar
    )
    select coalesce(sum(tutar),0), count(*)::integer into iade, adet from yeni;
    if iade > 0 then
      perform oyun.para_islem(kisi.user_id, iade, 'piyango',
        format('Milli Piyango kaldırıldı: %s biletin %s TL iadesi', adet, iade), now());
      perform oyun.bildir(kisi.user_id,
        format('Milli Piyango kaldırıldı. %s biletinin toplam %s TL bedeli cüzdanına iade edildi.',
          adet, oyun.tl(iade)), now());
    end if;
  end loop;
end $$;
