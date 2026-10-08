-- Genel başkanlık ve milletvekilliği aynı anda sürdürülür.
create or replace function oyun.rol_uyumlu(a text,b text)
returns boolean language sql immutable as $$
 select (a=b and a in ('gb','gby')) or (a,b) in
 (('mv','gby'),('gby','mv'),('gb','mv'),('mv','gb'),
 ('gb','cb'),('cb','gb'),('mv','tbmm'),('tbmm','mv'),
 ('mv','bskv'),('bskv','mv'),('mv','grup_bskv'),('grup_bskv','mv'),
 ('gby','grup_bskv'),('grup_bskv','gby'))
$$;
CREATE OR REPLACE FUNCTION public.aday_ol(p_tur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  k oyun.cb_kararlar;
begin
  if p_tur not in ('mv_on','bel_on','kurultay','cb_on') then
    raise exception 'Geçersiz adaylık türü.';
  end if;

  select * into s
  from oyun.secimler
  where tur = p_tur
    and t >= basvuru_bas
    and t < basvuru_bit
    and (
      not ara
      or (p_tur = 'bel_on' and hedef_il_id = p.il_id)
      or (p_tur = 'kurultay' and hedef_parti_id = p.parti_id)
      or p_tur = 'cb_on'
    )
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Bu adaylık için başvuru şu anda açık değil.';
  end if;
  if p.parti_id is null then
    raise exception 'Aday olmak için bir partiye üye olmalısın.';
  end if;
  if p.parti_at > s.basvuru_bas then
    raise exception 'Bu dönem aday olabilmek için başvurular açılmadan önce partiye üye olmalıydın.';
  end if;
  if oyun.uyari(p,t) is not null then
    raise exception '%', oyun.uyari(p,t);
  end if;
  if (select kurulus_bit from oyun.partiler where id = p.parti_id) is not null then
    raise exception 'Partin henüz kuruluş aşamasında: kurucu üye sayısı tamamlanmadan seçime katılamaz.';
  end if;

  if s.ara and s.hedef_il_id is not null
     and p.il_id is distinct from s.hedef_il_id then
    raise exception 'Bu ara seçim senin ilin için değil.';
  end if;

  if s.ara and s.hedef_parti_id is not null
     and p.parti_id is distinct from s.hedef_parti_id then
    raise exception 'Bu olağanüstü kurultay senin partin için değil.';
  end if;

  if p_tur='bel_on'
     and exists(select 1 from oyun.partiler where gb = p.id) then
    raise exception 'Genel başkan belediye başkanı adayı olamaz; milletvekili adaylığı serbesttir.';
  end if;

  if oyun.teskilat_engeli(p,p_tur) is not null then
    raise exception '%', oyun.teskilat_engeli(p,p_tur);
  end if;

  if p_tur = 'cb_on' then
    select * into k
    from oyun.cb_kararlar
    where donem = s.donem and parti_id = p.parti_id;

    if k.yontem in ('kendisi','baskasi') then
      raise exception 'Genel başkan cumhurbaşkanı adayını doğrudan belirledi; ön seçim yapılmayacak.';
    end if;
    if k.yontem = 'destek' then
      raise exception 'Partin cumhurbaşkanlığında ittifak ortağının adayını destekliyor; ön seçim yapılmayacak.';
    end if;
  end if;

  insert into oyun.adaylar(
    secim_id, user_id, parti_id, il_id, basvuru_at
  )
  values (
    s.id, p.id, p.parti_id,
    case when p_tur in ('mv_on','bel_on') then p.il_id end,
    t
  )
  on conflict(secim_id,user_id) do nothing;

  if not found then
    raise exception 'Bu seçime zaten başvurdun.';
  end if;

  perform oyun.aday_ucreti_al(p,p_tur,t);
  return public.durum();
end $function$;
revoke all on function public.aday_ol(text) from public,anon;
grant execute on function public.aday_ol(text) to authenticated;
