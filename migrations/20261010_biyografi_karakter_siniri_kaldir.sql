-- Seçim Online: oyuncu biyografilerindeki 160 karakter sınırını kaldır.
-- Mevcut kimlik, portre ve biyografiler korunur.
begin;
alter table oyun.oyuncu_kimlik
  drop constraint if exists oyuncu_kimlik_biyografi_check;

create or replace function public.kimlik_guncelle(p_avatar text, p_biyografi text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim();
  b text;
begin
  if p_avatar is not null and p_avatar !~ '^[0-9]{1,2}(-[0-9]{1,2}){5,6}$' then
    raise exception 'Geçersiz portre.';
  end if;

  -- Karakter sınırı olmadan mevcut boşluk normalizasyonu ve içerik kontrolü.
  b := nullif(btrim(regexp_replace(coalesce(p_biyografi, ''),
                 '[\r\n]{3,}', E'\n\n', 'g')), '');
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
end $$;

commit;
