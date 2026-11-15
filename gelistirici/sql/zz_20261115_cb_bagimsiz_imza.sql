-- Bağımsız CB: %3 imza, minimum 10, 50.000 TL iade edilebilir teminat.

create table if not exists oyun.cb_bagimsiz_kampanya(
 id bigint generated always as identity primary key,
 on_secim_id bigint not null references oyun.secimler(id),
 secim_id bigint not null references oyun.secimler(id),
 aday uuid not null references oyun.profiller(id),
 bas timestamptz not null,
 bit timestamptz not null,
 hedef integer not null check(hedef>0),
 teminat numeric not null check(teminat>=0),
 durum text not null default 'imza' check(durum in ('imza','onay','sure_doldu','iptal')),
 unique(secim_id,aday)
);
create index if not exists cb_bagimsiz_kampanya_durum on oyun.cb_bagimsiz_kampanya(durum,bit);
create table if not exists oyun.cb_bagimsiz_destek(
 secim_id bigint not null references oyun.secimler(id),
 kampanya_id bigint not null references oyun.cb_bagimsiz_kampanya(id),
 secmen uuid not null references oyun.profiller(id),
 zaman timestamptz not null,
 primary key(secim_id,secmen)
);
create index if not exists cb_bagimsiz_destek_kamp on oyun.cb_bagimsiz_destek(kampanya_id);
alter table oyun.cb_bagimsiz_kampanya enable row level security;
alter table oyun.cb_bagimsiz_destek enable row level security;
revoke all on oyun.cb_bagimsiz_kampanya,oyun.cb_bagimsiz_destek from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.bagimsiz_aday_ol(p_on_secim bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  o oyun.secimler;
  h oyun.secimler;
  ucret numeric;
  fon numeric;
  ode numeric;
  gorev text;
begin
  select * into o
  from oyun.secimler
  where id=p_on_secim
    and tur in ('mv_on','bel_on','cb_on')
    and durum='bekliyor'
    and t>=basvuru_bas and t<basvuru_bit;

  if o.id is null then
    raise exception 'Bağımsız adaylık başvurusu şu anda açık değil.';
  end if;
  if p.parti_id is not null then
    raise exception 'Bağımsız aday olmak için herhangi bir partiye üye olmamalısın.';
  end if;
  if oyun.uyari(p,t) is not null then
    raise exception '%',oyun.uyari(p,t);
  end if;
  if o.ara and o.hedef_il_id is not null and p.il_id is distinct from o.hedef_il_id then
    raise exception 'Bu olağanüstü seçim senin ilin için değil.';
  end if;

  select * into h
  from oyun.secimler
  where id=oyun.bagimsiz_hedef_secim(o.id);

  if h.id is null or h.durum<>'bekliyor' then
    raise exception 'Bağımsız adaylığın bağlanacağı asıl seçim bulunamadı.';
  end if;
  if exists(select 1 from oyun.adaylar where secim_id=h.id and user_id=p.id) then
    raise exception 'Bu seçimde zaten adaysın.';
  end if;


 if o.tur='cb_on' and oyun.gercekci_siyaset() then
   perform 1 from oyun.ayarlar where id=1 for update;
   if exists(select 1 from oyun.cb_bagimsiz_kampanya where secim_id=h.id and aday=p.id)
      then raise exception 'Bu seçim için zaten adaylık imza kampanyan var.'; end if;
   perform oyun.para_islem(p.id,-50000,'aday','Bağımsız Cumhurbaşkanı adaylık teminatı',t);
   insert into oyun.cb_bagimsiz_kampanya(on_secim_id,secim_id,aday,bas,bit,hedef,teminat)
   values(o.id,h.id,p.id,t,least(o.basvuru_bit,t+interval '72 hours'),
      greatest(10,ceil((select count(*) from oyun.profiller pr where not pr.yasakli and pr.son_gorulme>=t-interval '7 days')*0.03)::int),50000);
   perform oyun.olay('secim',format('%s bağımsız Cumhurbaşkanı adaylığı için imza toplamaya başladı.',p.kad),null,null,t);
   return public.durum();
 end if;
 ucret:=oyun.aday_ucreti(null,o.tur,p.il_id);
  fon:=round(ucret*oyun.duz('aday_destek')/100);
  ode:=greatest(0,ucret-fon);
  gorev:=case o.tur
    when 'mv_on' then 'milletvekili'
    when 'bel_on' then 'belediye başkanı'
    else 'cumhurbaşkanı' end;

  if ode>0 then
    perform oyun.para_islem(
      p.id,-ode,'aday',
      format('Bağımsız %s adaylığı başvuru harcı%s',gorev,
        case when fon>0 then format(' (%s ₺ siyasi katılım fonu desteği)',oyun.tl(fon)) else '' end),
      t
    );
  end if;

  insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,basvuru_at)
  values(
    h.id,p.id,null,
    case when o.tur in ('mv_on','bel_on') then p.il_id end,
    t
  );

  perform oyun.olay(
    'secim',
    format('%s, %s için bağımsız adaylık başvurusu yaptı.',p.kad,gorev),
    case when o.tur in ('mv_on','bel_on') then p.il_id end,
    null,t
  );

  return public.durum();
end $function$
;
CREATE OR REPLACE FUNCTION public.bagimsiz_adaylik_geri_cek(p_on_secim bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  o oyun.secimler;
  h oyun.secimler;
begin
  select * into o from oyun.secimler
  where id=p_on_secim and tur in ('mv_on','bel_on','cb_on');
  if o.id is null then raise exception 'Seçim bulunamadı.'; end if;

  select * into h from oyun.secimler where id=oyun.bagimsiz_hedef_secim(o.id);
  if h.id is null or h.durum<>'bekliyor' or t>=h.oy_bas then
    raise exception 'Bu bağımsız adaylık artık geri çekilemez.';
  end if;


 if o.tur='cb_on' and oyun.gercekci_siyaset() then
   update oyun.cb_bagimsiz_kampanya set durum='iptal'
   where secim_id=h.id and aday=p.id and durum in ('imza','onay');
   if found then
     delete from oyun.adaylar where secim_id=h.id and user_id=p.id and parti_id is null;
     return public.durum();
   end if;
 end if;
 delete from oyun.adaylar
  where secim_id=h.id and user_id=p.id and parti_id is null;
  if not found then raise exception 'Bu seçimde bağımsız adaylığın yok.'; end if;

  return public.durum();
end $function$
;

create or replace function public.cb_bagimsiz_kampanyalar(p_on_secim bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 update oyun.cb_bagimsiz_kampanya set durum='sure_doldu' where durum='imza' and bit<=t;
 return jsonb_build_object('gercekci',oyun.gercekci_siyaset(),
   'liste',coalesce((select jsonb_agg(jsonb_build_object(
      'id',k.id,'on_secim_id',k.on_secim_id,'aday',p.kad,
      'hedef',k.hedef,'toplanan',(select count(*) from oyun.cb_bagimsiz_destek d where d.kampanya_id=k.id),
      'bas',k.bas,'bit',k.bit,'durum',k.durum,'benim',k.aday=u,
      'imzaladim',exists(select 1 from oyun.cb_bagimsiz_destek d where d.secim_id=k.secim_id and d.secmen=u),
      'imza_verebilirim',k.durum='imza' and k.bit>t and not exists(select 1 from oyun.cb_bagimsiz_destek d where d.secim_id=k.secim_id and d.secmen=u)
    ) order by k.id desc)
    from oyun.cb_bagimsiz_kampanya k join oyun.profiller p on p.id=k.aday
    where (p_on_secim is null or k.on_secim_id=p_on_secim)
      and exists(select 1 from oyun.secimler s where s.id=k.secim_id and s.durum='bekliyor' and t<s.oy_bas)
  ),'[]'::jsonb));
end $f$;
create or replace function public.cb_bagimsiz_imzala(p_kampanya bigint) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); k oyun.cb_bagimsiz_kampanya; pr oyun.profiller; n int;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into pr from oyun.profiller where id=u;
 if pr.id is null or pr.yasakli or pr.olusturma>t-interval '1 day'
    or pr.son_gorulme<t-interval '7 days'
 then raise exception 'İmza için kısıtsız, en az bir günlük ve aktif hesap gerekir.'; end if;
 select * into k from oyun.cb_bagimsiz_kampanya where id=p_kampanya for update;
 if k.id is null or k.durum<>'imza' or t<k.bas or t>=k.bit then raise exception 'İmza kampanyası kapalı.'; end if;
 if not exists(select 1 from oyun.secimler where id=k.on_secim_id and durum='bekliyor'
   and t>=basvuru_bas and t<basvuru_bit)
 then raise exception 'Adaylık başvuru süresi kapandı.'; end if;
 if exists(select 1 from oyun.cb_bagimsiz_destek where secim_id=k.secim_id and secmen=u)
 then raise exception 'Bu seçimde zaten bir aday için imza verdin.'; end if;
 insert into oyun.cb_bagimsiz_destek(secim_id,kampanya_id,secmen,zaman) values(k.secim_id,k.id,u,t);
 select count(*) into n from oyun.cb_bagimsiz_destek where kampanya_id=k.id;
 if n>=k.hedef then
   if exists(select 1 from oyun.adaylar where secim_id=k.secim_id and user_id=k.aday)
     then raise exception 'Adayın zaten aynı seçimde kaydı var.'; end if;
   insert into oyun.adaylar(secim_id,user_id,parti_id,basvuru_at) values(k.secim_id,k.aday,null,t);
   update oyun.cb_bagimsiz_kampanya set durum='onay' where id=k.id;
   perform oyun.para_islem(k.aday,k.teminat,'aday','Bağımsız Cumhurbaşkanı imza teminatı iadesi',t);
   perform oyun.bildir(k.aday,format('Bağımsız Cumhurbaşkanı adaylığın %s imzayla kesinleşti; teminatın iade edildi.',n),t);
   perform oyun.olay('secim',format('%s, %s imzayla bağımsız Cumhurbaşkanı adayı oldu.',oyun.kad(k.aday),n),null,null,t);
 end if;
 return public.cb_bagimsiz_kampanyalar(k.on_secim_id);
end $f$;
revoke all on function public.cb_bagimsiz_kampanyalar(bigint),public.cb_bagimsiz_imzala(bigint) from public,anon;
grant execute on function public.cb_bagimsiz_kampanyalar(bigint),public.cb_bagimsiz_imzala(bigint) to authenticated;
