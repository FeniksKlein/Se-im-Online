-- 18.11.2026 · Oyun Yönetimi duyurularında gönderen moderatörün kullanıcı adı oyunculara görünmesin
-- Bildirim kutusunda sistem duyurusunun başlığı/portresi gönderenin profilinden geliyordu (kad + parti).
-- Artık sistem duyurularında gönderen "Oyun Yönetimi" görünür, parti gösterilmez; imza görev kodudur (Görevli G-06).
-- Eski duyurulardaki "— Moderatör kullanıcıadı" imzası da okurken görev koduna çevrilir. Oyuncu verisi değişmez.
-- Ayrıca oyuncu bir moderatörü engellemiş olsa da Oyun Yönetimi duyurularını görür (engel, kimin mod olduğunu ele vermesin).
create or replace function public.bildirim_kutusu(p_limit int default 60) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); j jsonb; lim int := least(greatest(p_limit, 1), 100);
begin
  select coalesce(jsonb_agg(u.x order by u.z desc), '[]'::jsonb) into j from (
    (select jsonb_build_object('tur', 'yayin', 'id', y.id, 'yayin_tur', y.tur, 'zaman', y.zaman,
             'metin', case when y.tur = 'sistem' and pr.id is not null
                           then regexp_replace(y.metin, E'\n\n— (Moderatör|Oyun yöneticisi) [^\n]*$', E'\n\n— ' || oyun.mod_imza(pr))
                           else y.metin end,
             'kad', case when y.tur = 'sistem' then 'Oyun Yönetimi' else coalesce(pr.kad, '(silinmiş)') end,
             'unvan', case when y.tur = 'sistem' then 'Oyun Yönetimi' else y.unvan end,
             'parti', case when y.tur = 'sistem' then null else oyun.parti_json(pr.parti_id) end,
             'benim', y.gonderen = p.id, 'yeni', y.zaman > p.bildirim_okundu and y.gonderen <> p.id) x, y.zaman z
     from oyun.yayinlar y left join oyun.profiller pr on pr.id = y.gonderen
     where not y.gizli and y.zaman <= t and oyun.yayin_gorur(y, p) and (y.tur = 'sistem' or not oyun.engelli(p.id, y.gonderen))
     order by y.zaman desc limit lim)
    union all
    (select jsonb_build_object('tur', 'kisisel', 'id', b.id, 'zaman', b.zaman, 'metin', b.metin, 'yeni', b.zaman > p.bildirim_okundu) x, b.zaman z
     from oyun.bildirimler b where b.user_id = p.id and b.zaman <= t
     order by b.zaman desc limit lim)
  ) u;
  update oyun.profiller set bildirim_okundu = t where id = p.id;
  return j;
end $$;
