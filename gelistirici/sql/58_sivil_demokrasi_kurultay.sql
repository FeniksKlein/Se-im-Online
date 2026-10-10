-- Seçim Online / Dernek genel kurulları, üye imzaları ve parti kurultayı
-- Sadece ek tablo ve RPC: oyuncu/para/oy/geçmiş silinmez.
create table if not exists oyun.sos_dernek_secim (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 bas timestamptz not null default now(),
 aday_bit timestamptz not null,
 oy_bit timestamptz not null,
 durum text not null default 'acik' check (durum in ('acik','bitti')),
 eski_baskan uuid references oyun.profiller(id),
 yeni_baskan uuid references oyun.profiller(id)
);
create unique index if not exists sos_dernek_tek_acik on oyun.sos_dernek_secim(dernek_id) where durum='acik';
create table if not exists oyun.sos_dernek_aday(
 secim_id bigint not null references oyun.sos_dernek_secim(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 gorev text not null check (gorev in ('baskan','yonetim')),
 primary key(secim_id,user_id)
);
create table if not exists oyun.sos_dernek_oy(
 secim_id bigint not null references oyun.sos_dernek_secim(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 gorev text not null check(gorev in ('baskan','yonetim')),
 aday_id uuid not null references oyun.profiller(id),
 primary key(secim_id,user_id,gorev),
 foreign key(secim_id,aday_id) references oyun.sos_dernek_aday(secim_id,user_id)
);
create table if not exists oyun.sos_dernek_talep(
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 bas timestamptz not null default now(),
 bit timestamptz not null default (now()+interval '7 days'),
 durum text not null default 'acik' check(durum in ('acik','kabul','sure_doldu'))
);
create unique index if not exists sos_dernek_talep_acik on oyun.sos_dernek_talep(dernek_id) where durum='acik';
create table if not exists oyun.sos_dernek_talep_imza(
 talep_id bigint not null references oyun.sos_dernek_talep(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 primary key(talep_id,user_id)
);
do $$ declare n text; begin
 foreach n in array array['sos_dernek_secim','sos_dernek_aday','sos_dernek_oy','sos_dernek_talep','sos_dernek_talep_imza'] loop
  execute format('alter table oyun.%I enable row level security',n);
  execute format('revoke all on oyun.%I from public,anon,authenticated',n);
 end loop;
end $$;

create or replace function oyun.sos_dernek_baslat(p_dernek bigint,t timestamptz)
returns bigint language plpgsql set search_path='' as $$
declare d oyun.dernekler; sid bigint; son timestamptz;
begin
 select * into d from oyun.dernekler where id=p_dernek and not kapali for update;
 if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
 select id into sid from oyun.sos_dernek_secim where dernek_id=d.id and durum='acik';
 if sid is not null then return sid; end if;
 select max(oy_bit) into son from oyun.sos_dernek_secim where dernek_id=d.id;
 if son>t-interval '7 days' then raise exception 'Son genel kurulun üzerinden en az 7 gün geçmeli.'; end if;
 if (select count(*) from oyun.dernek_uyeler where dernek_id=d.id)<2 then raise exception 'Genel kurul için en az iki üye gerekli.'; end if;
 insert into oyun.sos_dernek_secim(dernek_id,bas,aday_bit,oy_bit,eski_baskan)
 values(d.id,t,t+interval '12 hours',t+interval '36 hours',d.baskan) returning id into sid;
 if d.baskan is not null and exists(select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=d.baskan) then
  insert into oyun.sos_dernek_aday(secim_id,user_id,gorev) values(sid,d.baskan,'baskan');
 end if;
 perform oyun.olay('dernek',format('%s genel kurulu açıldı. Üyeler başkan ve yönetim kurulu için aday olabilir.',d.ad),d.merkez_il,null,t);
 return sid;
end $$;
revoke all on function oyun.sos_dernek_baslat(bigint,timestamptz) from public,anon,authenticated;

create or replace function oyun.sos_dernek_bitir(p_id bigint,t timestamptz)
returns void language plpgsql set search_path='' as $$
declare s oyun.sos_dernek_secim; d oyun.dernekler; h uuid; y record;
begin
 select * into s from oyun.sos_dernek_secim where id=p_id for update;
 if s.id is null or s.durum<>'acik' or s.oy_bit>t then return; end if;
 select * into d from oyun.dernekler where id=s.dernek_id for update;
 if d.id is null or d.kapali then update oyun.sos_dernek_secim set durum='bitti' where id=s.id; return; end if;
 select a.user_id into h
 from oyun.sos_dernek_aday a
 join oyun.dernek_uyeler u on u.dernek_id=d.id and u.user_id=a.user_id
 left join oyun.sos_dernek_oy v on v.secim_id=a.secim_id and v.gorev='baskan' and v.aday_id=a.user_id
 where a.secim_id=s.id and a.gorev='baskan'
   and not exists(select 1 from oyun.dernekler x where x.baskan=a.user_id and x.id<>d.id and not x.kapali)
 group by a.user_id order by count(v.user_id) desc,(a.user_id=d.baskan) desc,a.user_id limit 1;
 h:=coalesce(h,d.baskan);
 update oyun.dernek_uyeler set rol='uye' where dernek_id=d.id and rol in ('baskan','yonetim');
 if h is not null and exists(select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=h) then
  update oyun.dernek_uyeler set rol='baskan' where dernek_id=d.id and user_id=h;
  update oyun.dernekler set baskan=h where id=d.id;
 end if;
 for y in
  select a.user_id from oyun.sos_dernek_aday a
  join oyun.dernek_uyeler u on u.dernek_id=d.id and u.user_id=a.user_id
  left join oyun.sos_dernek_oy v on v.secim_id=a.secim_id and v.gorev='yonetim' and v.aday_id=a.user_id
  where a.secim_id=s.id and a.gorev='yonetim' and a.user_id<>h
  group by a.user_id order by count(v.user_id) desc,a.user_id limit 4
 loop update oyun.dernek_uyeler set rol='yonetim' where dernek_id=d.id and user_id=y.user_id; end loop;
 update oyun.sos_dernek_secim set durum='bitti',yeni_baskan=h where id=s.id;
 perform oyun.olay('dernek',format('%s genel kurulunda yeni başkan %s oldu.',d.ad,oyun.kad(h)),d.merkez_il,null,t);
 if h is distinct from s.eski_baskan and h is not null then perform oyun.bildir(h,format('%s genel kurulunda başkan seçildin.',d.ad),t); end if;
end $$;
revoke all on function oyun.sos_dernek_bitir(bigint,timestamptz) from public,anon,authenticated;

create or replace function public.sos_dernek_durum(p_dernek bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); d oyun.dernekler; s oyun.sos_dernek_secim; tal oyun.sos_dernek_talep; n int; son timestamptz;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into d from oyun.dernekler where id=p_dernek and not kapali;
 if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
 select * into s from oyun.sos_dernek_secim where dernek_id=d.id order by id desc limit 1;
 if s.durum='acik' and s.oy_bit<=t then perform oyun.sos_dernek_bitir(s.id,t); select * into s from oyun.sos_dernek_secim where id=s.id; end if;
 if (s.id is null or s.durum='bitti') and (coalesce(s.oy_bit,d.kurulus)<=t-interval '30 days') and
   (select count(*) from oyun.dernek_uyeler where dernek_id=d.id)>=2 then
   perform oyun.sos_dernek_baslat(d.id,t);
   select * into s from oyun.sos_dernek_secim where dernek_id=d.id order by id desc limit 1;
 end if;
 update oyun.sos_dernek_talep set durum='sure_doldu' where dernek_id=d.id and durum='acik' and bit<=t;
 select * into tal from oyun.sos_dernek_talep where dernek_id=d.id and durum='acik' limit 1;
 select count(*) into n from oyun.dernek_uyeler where dernek_id=d.id;
 return jsonb_build_object(
 'dernek_id',d.id,'rolum',(select rol from oyun.dernek_uyeler where dernek_id=d.id and user_id=u),
 'uye_sayisi',n,'esik',greatest(2,ceil(n::numeric/3)::int),
 'talep',case when tal.id is null then null else jsonb_build_object('id',tal.id,'bit',tal.bit,'imza',(select count(*) from oyun.sos_dernek_talep_imza where talep_id=tal.id),'imzaladim',exists(select 1 from oyun.sos_dernek_talep_imza where talep_id=tal.id and user_id=u)) end,
 'secim',case when s.id is null then null else jsonb_build_object(
  'id',s.id,'bas',s.bas,'aday_bit',s.aday_bit,'oy_bit',s.oy_bit,'durum',s.durum,
  'baskan',oyun.kad(coalesce(s.yeni_baskan,d.baskan)),
  'adaylar',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(a.user_id),'user_id',a.user_id,'gorev',a.gorev,'oy',case when s.durum='bitti' then (select count(*) from oyun.sos_dernek_oy v where v.secim_id=s.id and v.gorev=a.gorev and v.aday_id=a.user_id) end,'benim',a.user_id=u) order by a.gorev,a.user_id)
    from oyun.sos_dernek_aday a where a.secim_id=s.id),'[]'::jsonb),
  'oylarim',coalesce((select jsonb_object_agg(v.gorev,v.aday_id) from oyun.sos_dernek_oy v where v.secim_id=s.id and v.user_id=u),'{}'::jsonb),
  'oy_hakkim',exists(select 1 from oyun.dernek_uyeler m where m.dernek_id=d.id and m.user_id=u and m.katilim<=s.bas)
 ) end);
end $$;

create or replace function public.sos_dernek_secim_ac(p_dernek bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d oyun.dernekler;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into d from oyun.dernekler where id=p_dernek and not kapali;
 if d.id is null or d.baskan is distinct from u then raise exception 'Genel kurulu yalnızca başkan açabilir.'; end if;
 perform oyun.sos_dernek_baslat(p_dernek,oyun.simdi());
 return public.sos_dernek_durum(p_dernek);
end $$;

create or replace function public.sos_dernek_imza(p_dernek bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); d oyun.dernekler; tal oyun.sos_dernek_talep; n int; toplam int;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into d from oyun.dernekler where id=p_dernek and not kapali for update;
 if d.id is null or not exists(select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=u) then raise exception 'Yalnızca dernek üyeleri imzalayabilir.'; end if;
 if exists(select 1 from oyun.sos_dernek_secim where dernek_id=d.id and durum='acik') then raise exception 'Zaten genel kurul yapılıyor.'; end if;
 update oyun.sos_dernek_talep set durum='sure_doldu' where dernek_id=d.id and durum='acik' and bit<=t;
 select * into tal from oyun.sos_dernek_talep where dernek_id=d.id and durum='acik' for update;
 if tal.id is null then insert into oyun.sos_dernek_talep(dernek_id,bas,bit) values(d.id,t,t+interval '7 days') returning * into tal; end if;
 insert into oyun.sos_dernek_talep_imza(talep_id,user_id) values(tal.id,u) on conflict do nothing;
 if not found then raise exception 'Bu talebi zaten imzaladın.'; end if;
 select count(*) into n from oyun.sos_dernek_talep_imza where talep_id=tal.id;
 select count(*) into toplam from oyun.dernek_uyeler where dernek_id=d.id;
 if n>=greatest(2,ceil(toplam::numeric/3)::int) then
  perform oyun.sos_dernek_baslat(d.id,t);
  update oyun.sos_dernek_talep set durum='kabul' where id=tal.id;
  perform oyun.bildir(d.baskan,format('%s üyelerinin imzalarıyla olağanüstü genel kurul açıldı.',d.ad),t);
 end if;
 return public.sos_dernek_durum(d.id);
end $$;

create or replace function public.sos_dernek_aday(p_secim bigint,p_gorev text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); s oyun.sos_dernek_secim; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into s from oyun.sos_dernek_secim where id=p_secim for update;
 if s.id is null or s.durum<>'acik' or t>=s.aday_bit then raise exception 'Adaylık süresi kapalı.'; end if;
 if p_gorev not in ('baskan','yonetim') then raise exception 'Geçersiz görev.'; end if;
 if not exists(select 1 from oyun.dernek_uyeler where dernek_id=s.dernek_id and user_id=u and katilim<=s.bas) then raise exception 'Genel kurul başlamadan önce üye olmalısın.'; end if;
 if p_gorev='baskan' and exists(select 1 from oyun.dernekler where baskan=u and id<>s.dernek_id and not kapali) then raise exception 'Başka derneğin başkanısın.'; end if;
 insert into oyun.sos_dernek_aday(secim_id,user_id,gorev) values(s.id,u,p_gorev) on conflict (secim_id,user_id) do update set gorev=excluded.gorev;
 return public.sos_dernek_durum(s.dernek_id);
end $$;

create or replace function public.sos_dernek_oyla(p_secim bigint,p_gorev text,p_aday uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); s oyun.sos_dernek_secim; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into s from oyun.sos_dernek_secim where id=p_secim for update;
 if s.id is null or s.durum<>'acik' or t<s.aday_bit or t>=s.oy_bit then raise exception 'Oy verme süresi kapalı.'; end if;
 if p_gorev not in ('baskan','yonetim') or not exists(select 1 from oyun.sos_dernek_aday where secim_id=s.id and user_id=p_aday and gorev=p_gorev) then raise exception 'Geçersiz aday.'; end if;
 if not exists(select 1 from oyun.dernek_uyeler where dernek_id=s.dernek_id and user_id=u and katilim<=s.bas) then raise exception 'Oy kullanma hakkın yok.'; end if;
 insert into oyun.sos_dernek_oy(secim_id,user_id,gorev,aday_id) values(s.id,u,p_gorev,p_aday)
 on conflict (secim_id,user_id,gorev) do update set aday_id=excluded.aday_id;
 return public.sos_dernek_durum(s.dernek_id);
end $$;

-- Parti üyelerinin imzasıyla olağanüstü kurultay: mevcut kurultay seçim motorunu kullanır.
create table if not exists oyun.sos_parti_imza(
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id),
 acan uuid not null references oyun.profiller(id),
 bas timestamptz not null default now(),
 bit timestamptz not null default (now()+interval '7 days'),
 durum text not null default 'acik' check(durum in ('acik','basarili','sure_doldu')),
 secim_id bigint references oyun.secimler(id)
);
create unique index if not exists sos_parti_imza_acik on oyun.sos_parti_imza(parti_id) where durum='acik';
create table if not exists oyun.sos_parti_imzaci(
 kampanya_id bigint not null references oyun.sos_parti_imza(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 primary key(kampanya_id,user_id)
);
alter table oyun.sos_parti_imza enable row level security;
alter table oyun.sos_parti_imzaci enable row level security;
revoke all on oyun.sos_parti_imza,oyun.sos_parti_imzaci from public,anon,authenticated;

create or replace function public.sos_parti_imza_durum(p_parti bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); c oyun.sos_parti_imza; n int;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 update oyun.sos_parti_imza set durum='sure_doldu' where parti_id=p_parti and durum='acik' and bit<=t;
 select * into c from oyun.sos_parti_imza where parti_id=p_parti order by id desc limit 1;
 select count(*) into n from oyun.profiller where parti_id=p_parti;
 return jsonb_build_object('parti_id',p_parti,'uye_sayisi',n,'esik',greatest(2,ceil(n::numeric/3)::int),
 'uyeyim',exists(select 1 from oyun.profiller where id=u and parti_id=p_parti),
 'kampanya',case when c.id is null then null else jsonb_build_object('id',c.id,'bas',c.bas,'bit',c.bit,'durum',c.durum,'secim_id',c.secim_id,
 'imza',(select count(*) from oyun.sos_parti_imzaci where kampanya_id=c.id),
 'imzaladim',exists(select 1 from oyun.sos_parti_imzaci where kampanya_id=c.id and user_id=u)) end);
end $$;
create or replace function public.sos_parti_imzala(p_parti bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); p oyun.partiler; c oyun.sos_parti_imza; n int; toplam int; o jsonb;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into p from oyun.partiler where id=p_parti and not kapali for update;
 if p.id is null or not exists(select 1 from oyun.profiller where id=u and parti_id=p.id) then raise exception 'Yalnızca bu partinin üyeleri imzalayabilir.'; end if;
 if exists(select 1 from oyun.secimler where tur='kurultay' and ara and hedef_parti_id=p.id and durum<>'tamam' and goreve_bas>t) then raise exception 'Parti için zaten olağanüstü kurultay var.'; end if;
 update oyun.sos_parti_imza set durum='sure_doldu' where parti_id=p.id and durum='acik' and bit<=t;
 select * into c from oyun.sos_parti_imza where parti_id=p.id and durum='acik' for update;
 if c.id is null then insert into oyun.sos_parti_imza(parti_id,acan,bas,bit) values(p.id,u,t,t+interval '7 days') returning * into c; end if;
 if not exists(select 1 from oyun.profiller where id=u and parti_id=p.id and parti_at<=c.bas) and c.acan<>u then raise exception 'İmza kampanyası açıldıktan sonra katılan üyeler bu kampanyada imza atamaz.'; end if;
 insert into oyun.sos_parti_imzaci(kampanya_id,user_id) values(c.id,u) on conflict do nothing;
 if not found then raise exception 'Bu kampanyayı zaten imzaladın.'; end if;
 select count(*) into n from oyun.sos_parti_imzaci where kampanya_id=c.id;
 select count(*) into toplam from oyun.profiller where parti_id=p.id;
 if n>=greatest(2,ceil(toplam::numeric/3)::int) then
   o:=oyun.ara_secim_olustur('gb',p.id,null::smallint,t);
   update oyun.secimler set ara_neden='uye_imza_kampanyasi' where id=(o->>'secim_id')::bigint and ara and ara_neden='genel_baskan_istifa';
   update oyun.sos_parti_imza set durum='basarili',secim_id=(o->>'secim_id')::bigint where id=c.id;
   perform oyun.olay('parti',format('%s üyelerinin imzasıyla olağanüstü kurultay kararı alındı.',p.ad),null,p.id,t);
   if p.gb is not null then perform oyun.bildir(p.gb,format('%s üyeleri olağanüstü kurultay topladı.',p.ad),t); end if;
 end if;
 return public.sos_parti_imza_durum(p.id);
end $$;

do $$ declare f text; begin
 foreach f in array array[
 'sos_dernek_durum(bigint)','sos_dernek_secim_ac(bigint)','sos_dernek_imza(bigint)','sos_dernek_aday(bigint,text)','sos_dernek_oyla(bigint,text,uuid)',
 'sos_parti_imza_durum(bigint)','sos_parti_imzala(bigint)'
 ] loop
 execute 'revoke all on function public.'||f||' from public,anon';
 execute 'grant execute on function public.'||f||' to authenticated';
 end loop;
end $$;
