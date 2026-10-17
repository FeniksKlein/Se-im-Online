begin;
-- Şehirler arası oyuncu taşınması: il bazlı ara seçimler tüm ülkeyi kilitlemez.
-- Mevcut taşınma süresi, ücret, makam ve seçmen kütüğü kuralları korunur.

create or replace function oyun.il_kilit_nedeni(
  t timestamptz, p_kaynak smallint, p_hedef smallint
) returns text language sql stable set search_path = oyun, pg_temp as $$
  select case s.tur
    when 'mv_on' then 'Genel seçim süreci tamamlanana kadar bu iller arasında taşınamazsın.'
    else 'Belediye seçim süreci tamamlanana kadar bu iller arasında taşınamazsın.'
  end
  from oyun.secimler s
  join oyun.secimler g
    on g.donem = s.donem
   and g.tur = case s.tur when 'mv_on' then 'mv' else 'bel' end
  where s.tur in ('mv_on','bel_on')
    and t >= s.basvuru_bas
    and t < g.goreve_bas
    and (
      coalesce(s.hedef_il_id, g.hedef_il_id) is null
      or p_kaynak = coalesce(s.hedef_il_id, g.hedef_il_id)
      or p_hedef = coalesce(s.hedef_il_id, g.hedef_il_id)
    )
  order by s.basvuru_bas
  limit 1
$$;

-- Eski durum() RPC'si bir parametreli yardımcıyı kullanır. Yalnızca
-- ülke çapındaki genel seçim kilidini göster; il bazlı ara seçimde
-- taşınacak hedef il bilinmediği için yanlış bir genel kilit gösterme.
create or replace function oyun.il_kilit_nedeni(t timestamptz)
returns text language sql stable set search_path = oyun, pg_temp as $$
  select oyun.il_kilit_nedeni(t, null::smallint, null::smallint)
$$;

create or replace function oyun.il_tasinma_engeli(
  p oyun.profiller, p_il smallint, t timestamptz
) returns text language plpgsql stable set search_path = oyun, public, pg_temp as $$
declare
  gun int := oyun.il_bekleme_gun(t);
  kilit text;
begin
  if not exists (select 1 from oyun.iller where id = p_il) then
    return 'Geçersiz il.';
  end if;
  if p.il_id = p_il then return 'Zaten bu ildesin.'; end if;
  kilit := oyun.il_kilit_nedeni(t, p.il_id, p_il);
  if kilit is not null then return kilit; end if;
  if p.son_il_degis is not null
     and p.son_il_degis + make_interval(days => gun) > t then
    return format('İl en fazla %s günde bir değiştirilebilir. Bir sonraki: %s',
      gun, to_char(
        (p.son_il_degis + make_interval(days => gun)) at time zone 'Europe/Istanbul',
        'DD.MM.YYYY HH24:MI'));
  end if;
  if exists (
    select 1 from oyun.makamlar
    where user_id = p.id and bit is null and tur in ('mv','bel')
  ) then
    return 'Görevdeki vekil veya belediye başkanı il değiştiremez.';
  end if;
  if oyun.tasinma_ucreti(p.il_id, p_il, t) >
     coalesce((select para from oyun.cuzdan where user_id = p.id), 0) then
    return format('Cüzdanında yeterli para yok. Taşınma ücreti: %s ₺.',
      oyun.tl(oyun.tasinma_ucreti(p.il_id, p_il, t)));
  end if;
  return null;
end $$;

-- Oyuncu ödeme yapmadan önce taşınma ücretini ve engel nedenini görür.
create or replace function public.il_tasinma_bilgisi(p_il integer)
returns jsonb language plpgsql security definer
set search_path = oyun, public, pg_temp as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  engel text;
begin
  if p.id is null then raise exception 'Oturum açmalısın.'; end if;
  engel := oyun.il_tasinma_engeli(p, p_il::smallint, t);
  return jsonb_build_object(
    'uygun', engel is null,
    'engel', engel,
    'mevcut_il', (select ad from oyun.iller where id = p.il_id),
    'hedef_il', (select ad from oyun.iller where id = p_il),
    'ucret', case when engel is null then oyun.tasinma_ucreti(p.il_id, p_il::smallint, t) else null end,
    'bekleme_gun', oyun.il_bekleme_gun(t),
    'sonraki', case when p.son_il_degis is null then null else p.son_il_degis + make_interval(days => oyun.il_bekleme_gun(t)) end
  );
end $$;

revoke all on function public.il_tasinma_bilgisi(integer) from public, anon;
grant execute on function public.il_tasinma_bilgisi(integer) to authenticated;

-- Eski il_degistir(int) imzası korunur: telefon uygulamalarını bozmaz.
-- Profil satırı kilidi aynı hesabın eşzamanlı iki taşınmayla süreyi aşmasını önler.
create or replace function public.il_degistir(p_il integer)
returns jsonb language plpgsql security definer
set search_path = oyun, public, pg_temp as $$
declare
  p oyun.profiller;
  t timestamptz := oyun.simdi();
  engel text;
  ucret numeric;
begin
  select * into p from oyun.profiller where id = oyun.ben() for update;
  if p.id is null then raise exception 'Oturum açmalısın.'; end if;
  engel := oyun.il_tasinma_engeli(p, p_il::smallint, t);
  if engel is not null then raise exception '%', engel; end if;
  ucret := oyun.tasinma_ucreti(p.il_id, p_il::smallint, t);
  if ucret > 0 then
    perform oyun.para_islem(p.id, -ucret, 'tasinma',
      format('Taşınma: %s → %s',
        (select ad from oyun.iller where id = p.il_id),
        (select ad from oyun.iller where id = p_il)), t);
  end if;
  update oyun.parti_teskilat_gorev
     set aktif = false
   where user_id = p.id and aktif and il_id <> p_il::smallint;
  update oyun.profiller
     set il_id = p_il, il_at = t, son_il_degis = t
   where id = p.id;
  return public.durum();
end $$;
commit;
