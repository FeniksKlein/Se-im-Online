-- Genel baskan milletvekili adayi olabilir; ayni donemde kesin CB adayi olamaz.
-- Basvuru takvimi, uyelik ve diger vatandaslik sartlari aynen korunur.
create or replace function oyun.gb_mv_cb_adaylik_kontrol()
returns trigger language plpgsql security invoker
set search_path = '' as $$
declare
  v_tur text;
  v_donem text;
begin
  select s.tur, s.donem into v_tur, v_donem
  from oyun.secimler s where s.id = new.secim_id;
  if v_tur not in ('mv_on','mv','cb','cb2') then
    return new;
  end if;
  if not exists (select 1 from oyun.partiler p where p.gb = new.user_id) then
    return new;
  end if;

  -- Eszamanli iki basvuru birbirini gormeden gecmesin.
  perform 1 from oyun.profiller pr where pr.id = new.user_id for update;

  if v_tur in ('mv_on','mv') and exists (
    select 1 from oyun.adaylar a
    join oyun.secimler s on s.id=a.secim_id
    where a.user_id=new.user_id and s.donem=v_donem
      and s.tur in ('cb','cb2')
      and (tg_op='INSERT' or a.id<>new.id)
  ) then
    raise exception 'Cumhurbaskani adayi olan genel baskan ayni secim doneminde milletvekili adayi olamaz.';
  end if;

  if v_tur in ('cb','cb2') and exists (
    select 1 from oyun.adaylar a
    join oyun.secimler s on s.id=a.secim_id
    where a.user_id=new.user_id and s.donem=v_donem
      and s.tur in ('mv_on','mv')
      and (tg_op='INSERT' or a.id<>new.id)
  ) then
    raise exception 'Milletvekili adayligi bulunan genel baskan ayni donemde cumhurbaskani adayi olamaz. Once milletvekili adayligini geri cekmelisin.';
  end if;
  return new;
end $$;

drop trigger if exists gb_mv_cb_adaylik_kontrol_tg on oyun.adaylar;
create trigger gb_mv_cb_adaylik_kontrol_tg
before insert or update of secim_id,user_id on oyun.adaylar
for each row execute function oyun.gb_mv_cb_adaylik_kontrol();

-- Önceden kayitli, kesin CB adayi olan genel baskanlarin acik MV basvurularini
-- oy ve oyuncu verilerini degistirmeden geri alinabilir sekilde arsivle.
create table if not exists oyun.gb_mv_cb_iptal_arsivi (
  aday_id bigint primary key,
  user_id uuid not null,
  secim_id bigint not null,
  aday_json jsonb not null,
  tanitim_json jsonb not null default '[]'::jsonb,
  sebep text not null,
  iptal_zamani timestamptz not null default now()
);
alter table oyun.gb_mv_cb_iptal_arsivi enable row level security;
revoke all on oyun.gb_mv_cb_iptal_arsivi from public, anon, authenticated;

insert into oyun.gb_mv_cb_iptal_arsivi(aday_id,user_id,secim_id,aday_json,tanitim_json,sebep)
select a.id, a.user_id, a.secim_id, to_jsonb(a),
       coalesce((select jsonb_agg(to_jsonb(x)) from oyun.parti_aday_tanitim x where x.aday_id=a.id),'[]'::jsonb),
       'Ayni donemde kesin cumhurbaskani adayligi bulunduğu icin'
from oyun.adaylar a
join oyun.secimler s on s.id=a.secim_id
join oyun.partiler p on p.gb=a.user_id
where s.tur in ('mv_on','mv')
  and s.durum = 'bekliyor'
  and not exists (select 1 from oyun.oylar o where o.secim_id=s.id)
  and exists (
    select 1 from oyun.adaylar b join oyun.secimler sb on sb.id=b.secim_id
    where b.user_id=a.user_id and sb.donem=s.donem and sb.tur in ('cb','cb2')
  )
on conflict (aday_id) do nothing;

do $$
declare r record;
begin
  for r in
    select a.id,a.user_id
    from oyun.adaylar a
    join oyun.gb_mv_cb_iptal_arsivi ar on ar.aday_id=a.id
    join oyun.secimler s on s.id=a.secim_id
    where s.durum='bekliyor'
      and not exists(select 1 from oyun.oylar o where o.secim_id=s.id)
  loop
    delete from oyun.adaylar where id=r.id;
    perform oyun.bildir(r.user_id,
      'Kesin cumhurbaskani adayligin oldugu icin ayni donemdeki milletvekili adayligin iptal edildi. Genel baskanligin ve diger haklarin devam ediyor.',
      oyun.simdi());
  end loop;
end $$;
