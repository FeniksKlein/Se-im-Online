-- Seçim Simülasyonu Online - biyografi üst sınırı: 5.000 karakter.
-- Mevcut biyografiler, portreler ve kullanıcı hesapları korunur.
begin;

alter table oyun.oyuncu_kimlik
  drop constraint if exists oyuncu_kimlik_biyografi_check;

alter table oyun.oyuncu_kimlik
  add constraint oyuncu_kimlik_biyografi_check
  check (biyografi is null or char_length(biyografi) <= 5000);

create or replace function public.kimlik_guncelle(p_avatar text, p_biyografi text)
returns jsonb
language plpgsql
security definer set search_path = ''
as $biyografi$
declare
  p oyun.profiller := oyun.profilim();
  b text;
begin
  if p_avatar is not null and p_avatar !~ '^[0-9]{1,2}(-[0-9]{1,2}){5,6}$' then
    raise exception 'Geçersiz portre.';
  end if;

  b := nullif(btrim(coalesce(p_biyografi, '')), '');
  if b is not null and char_length(b) > 5000 then
    raise exception 'Biyografi en fazla 5000 karakter olabilir.';
  end if;
  if b is not null and oyun.kufurlu(b) then
    raise exception 'Biyografinde uygunsuz bir ifade var. Hakaret ve küfür yasaktır.';
  end if;

  insert into oyun.oyuncu_kimlik(user_id, avatar, biyografi, guncelleme)
  values (p.id, p_avatar, b, oyun.simdi())
  on conflict (user_id) do update
    set avatar = excluded.avatar,
        biyografi = excluded.biyografi,
        guncelleme = excluded.guncelleme;

  return jsonb_build_object('avatar', p_avatar, 'biyografi', b);
end;
$biyografi$;

commit;
