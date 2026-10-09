-- Oyun test sifirlamasi sonrasi oncelikli 13 hesabin kimlik bazli acilis bakiyesi.
-- Ayrı yonetim semasi sifirlama tarafindan temizlenmez, oyunculara acik degildir.
create schema if not exists oyun_yonetim;
revoke all on schema oyun_yonetim from public, anon, authenticated;
create table if not exists oyun_yonetim.onceki_test_oyuncu (
  user_id uuid primary key references auth.users(id) on delete cascade,
  kad text not null,
  eklendi timestamptz not null default now()
);
alter table oyun_yonetim.onceki_test_oyuncu enable row level security;
revoke all on oyun_yonetim.onceki_test_oyuncu from public, anon, authenticated;

create or replace function oyun.test_oncelikli_baslangic()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  -- Yalnizca eski hesap kimligi eslesirse: kullanici adi taklidi bonus vermez.
  if exists (select 1 from oyun_yonetim.onceki_test_oyuncu o
             where o.user_id = new.user_id) then
    new.para := 1000000;
  end if;
  return new;
end
$$;
drop trigger if exists test_oncelikli_baslangic on oyun.cuzdan;
create trigger test_oncelikli_baslangic
before insert on oyun.cuzdan for each row
execute function oyun.test_oncelikli_baslangic();

create or replace function oyun.test_yonetici_profilini_koru()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if exists (select 1 from oyun.yonetici_kimlik k where k.user_id = new.id)
     and not new.yonetici then
    update oyun.profiller set yonetici = true where id = new.id;
  end if;
  return null;
end
$$;
drop trigger if exists test_yonetici_profilini_koru on oyun.profiller;
create trigger test_yonetici_profilini_koru
after insert on oyun.profiller for each row
execute function oyun.test_yonetici_profilini_koru();
