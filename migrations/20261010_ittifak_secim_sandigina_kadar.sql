-- 2026-10-10 | İttifak teklifi ve üyelik değişiklikleri genel seçime kadar açık.
-- Seçim takvimi veya oyuncu verileri değiştirilmez.
begin;

create or replace function oyun.ittifak_kilit(t timestamptz)
returns text language sql stable as $$
  select 'Genel seçimde oy verme başladı; sonuçlar açıklanana kadar ittifaklarda değişiklik yapılamaz.'
  where exists (
    select 1 from oyun.secimler g
    where g.tur = 'mv'
      and g.durum = 'bekliyor'
      and g.oy_bas is not null
      and t >= g.oy_bas
  )
$$;

commit;
