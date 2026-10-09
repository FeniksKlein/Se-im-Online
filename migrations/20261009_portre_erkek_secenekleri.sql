-- 2026-10-09 - Portre ozellestirme: daha fazla erkek sac/sakal ve bagimsiz sac rengi.
-- Eski 6 bolumlu avatarlar gecerli kalir; yeni kodda 7. bolum sac rengidir.
begin;
alter table oyun.oyuncu_kimlik
  drop constraint if exists oyuncu_kimlik_avatar_check;
alter table oyun.oyuncu_kimlik
  add constraint oyuncu_kimlik_avatar_check
  check (avatar ~ '^[0-9]{1,2}(-[0-9]{1,2}){5,6}$');

create or replace function public.kimlik_guncelle(p_avatar text, p_biyografi text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); b text;
begin
  if p_avatar is not null and p_avatar !~ '^[0-9]{1,2}(-[0-9]{1,2}){5,6}$' then
    raise exception 'Geçersiz portre.';
  end if;
  b := nullif(btrim(coalesce(p_biyografi, '')), '');
  if b is not null then b := oyun.metin_temizle(b, 160); end if;
  insert into oyun.oyuncu_kimlik(user_id, avatar, biyografi, guncelleme)
    values (p.id, p_avatar, b, oyun.simdi())
    on conflict (user_id) do update
      set avatar = excluded.avatar, biyografi = excluded.biyografi, guncelleme = excluded.guncelleme;
  return jsonb_build_object('avatar', p_avatar, 'biyografi', b);
end $$;
revoke all on function public.kimlik_guncelle(text,text) from public,anon;
grant execute on function public.kimlik_guncelle(text,text) to authenticated;
commit;
