-- Seçim Online: herkes için imza kampanyaları ve resmi vatandaş dilekçeleri
create table if not exists oyun.sos_dilekce(
 id bigint generated always as identity primary key,
 gonderen uuid not null references oyun.profiller(id),
 makam text not null check(makam in ('cb','bel','mv')),
 muhatap uuid not null references oyun.profiller(id),
 il_id smallint references oyun.iller(id),
 baslik text not null check(char_length(baslik) between 5 and 120),
 metin text not null check(char_length(metin) between 10 and 3000),
 olusturma timestamptz not null default now(),
 durum text not null default 'bekliyor' check(durum in ('bekliyor','islemde','kabul','ret')),
 cevap text,
 cevap_at timestamptz,
 imza_kamp_id bigint unique
);
create index if not exists sos_dilekce_z on oyun.sos_dilekce(olusturma desc);
create table if not exists oyun.sos_imza_kamp (
 id bigint generated always as identity primary key,
 acan uuid not null references oyun.profiller(id),
 makam text not null check(makam in ('cb','bel','mv')),
 muhatap uuid not null references oyun.profiller(id),
 il_id smallint references oyun.iller(id),
 baslik text not null check(char_length(baslik) between 5 and 120),
 metin text not null check(char_length(metin) between 10 and 3000),
 bas timestamptz not null default now(),
 bit timestamptz not null default (now()+interval '72 hours'),
 esik int not null check(esik>0),
 durum text not null default 'acik' check(durum in ('acik','basarili','sure_doldu')),
 dilekce_id bigint unique references oyun.sos_dilekce(id)
);
create table if not exists oyun.sos_imza(
 kampanya_id bigint not null references oyun.sos_imza_kamp(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 zaman timestamptz not null default now(),
 primary key(kampanya_id,user_id)
);
create index if not exists sos_imza_kamp_z on oyun.sos_imza_kamp(bas desc);
alter table oyun.sos_dilekce enable row level security;
alter table oyun.sos_imza_kamp enable row level security;
alter table oyun.sos_imza enable row level security;
revoke all on oyun.sos_dilekce,oyun.sos_imza_kamp,oyun.sos_imza from public,anon,authenticated;
do $$ begin
 if not exists(select 1 from pg_constraint where conname='sos_dilekce_kamp_ref' and conrelid='oyun.sos_dilekce'::regclass) then
 alter table oyun.sos_dilekce add constraint sos_dilekce_kamp_ref foreign key (imza_kamp_id) references oyun.sos_imza_kamp(id);
 end if;
end $$;

create or replace function oyun.sos_muhatap(p_makam text,p_kad text,p_il int) returns oyun.makamlar
language plpgsql stable set search_path='' as $$
declare m oyun.makamlar;
begin
 if p_makam not in ('cb','bel','mv') then raise exception 'Yalnızca cumhurbaşkanına, belediye başkanına veya milletvekiline başvurabilirsin.'; end if;
 if p_makam='cb' then
 select * into m from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1;
 elsif p_makam='bel' then
 if p_il is null or not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Belediye ilini seçmelisin.'; end if;
 select * into m from oyun.makamlar where tur='bel' and il_id=p_il and bit is null order by bas desc limit 1;
 elsif p_makam='mv' then
 if nullif(btrim(coalesce(p_kad,'')),'') is null then raise exception 'Milletvekilinin kullanıcı adını yazmalısın.'; end if;
 select m1.* into m from oyun.makamlar m1 join oyun.profiller p on p.id=m1.user_id
 where m1.tur='mv' and m1.bit is null and lower(p.kad)=lower(btrim(p_kad)) order by m1.bas desc limit 1;
 end if;
 if m.id is null then raise exception 'Seçilen makamda şu anda görev yapan oyuncu bulunamadı.'; end if;
 return m;
end $$;
revoke all on function oyun.sos_muhatap(text,text,integer) from public,anon,authenticated;

create or replace function public.sos_dilekceler() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
 'id',d.id,'gonderen',oyun.kad(d.gonderen),'muhatap',oyun.kad(d.muhatap),'makam',d.makam,'il_id',d.il_id,
 'baslik',d.baslik,'metin',d.metin,'olusturma',d.olusturma,'durum',d.durum,'cevap',d.cevap,'cevap_at',d.cevap_at,
 'imza_kamp_id',d.imza_kamp_id,
 'cevaplayabilirim',d.muhatap=u and d.durum in ('bekliyor','islemde')
 and exists(select 1 from oyun.makamlar m where m.tur=d.makam and m.user_id=u and m.bit is null and (d.makam<>'bel' or m.il_id=d.il_id)))
 order by d.id desc)
 from (select * from oyun.sos_dilekce order by id desc limit 100) d),'[]'::jsonb);
end $$;

create or replace function public.sos_dilekce_gonder(p_makam text,p_kad text,p_il int,p_baslik text,p_metin text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); m oyun.makamlar;
 b text:=btrim(coalesce(p_baslik,'')); a text:=btrim(coalesce(p_metin,''));
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 m:=oyun.sos_muhatap(p_makam,p_kad,p_il);
 if char_length(b) not between 5 and 120 or char_length(a) not between 10 and 3000 then raise exception 'Başlık 5–120, dilekçe 10–3000 karakter olmalı.'; end if;
 if (select count(*) from oyun.sos_dilekce where gonderen=u and olusturma>t-interval '24 hours' and imza_kamp_id is null)>=5 then raise exception '24 saatte en fazla 5 doğrudan dilekçe gönderebilirsin.'; end if;
 insert into oyun.sos_dilekce(gonderen,makam,muhatap,il_id,baslik,metin,olusturma)
 values(u,m.tur,m.user_id,m.il_id,b,a,t);
 perform oyun.bildir(m.user_id,format('%s sana resmi dilekçe gönderdi: %s',oyun.kad(u),b),t);
 return public.sos_dilekceler();
end $$;

create or replace function public.sos_dilekce_yanit(p_id bigint,p_durum text,p_cevap text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); d oyun.sos_dilekce; a text:=btrim(coalesce(p_cevap,''));
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into d from oyun.sos_dilekce where id=p_id for update;
 if d.id is null or d.muhatap<>u or d.durum not in ('bekliyor','islemde') then raise exception 'Bu dilekçeye cevap verme hakkın yok.'; end if;
 if not exists(select 1 from oyun.makamlar where user_id=u and tur=d.makam and bit is null and (d.makam<>'bel' or il_id=d.il_id)) then raise exception 'Artık bu makamda görev yapmıyorsun.'; end if;
 if p_durum not in ('islemde','kabul','ret') then raise exception 'Geçersiz durum.'; end if;
 if char_length(a) not between 5 and 3000 then raise exception 'Resmi açıklama 5–3000 karakter olmalı.'; end if;
 update oyun.sos_dilekce set durum=p_durum,cevap=a,cevap_at=t where id=p_id;
 perform oyun.bildir(d.gonderen,format('“%s” dilekçen yanıtlandı. Durum: %s.',d.baslik,p_durum),t);
 return public.sos_dilekceler();
end $$;

create or replace function public.sos_imza_kampanyalari() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 update oyun.sos_imza_kamp set durum='sure_doldu' where durum='acik' and bit<=t;
 return coalesce((select jsonb_agg(jsonb_build_object(
 'id',k.id,'acan',oyun.kad(k.acan),'muhatap',oyun.kad(k.muhatap),'makam',k.makam,'il_id',k.il_id,
 'baslik',k.baslik,'metin',k.metin,'bas',k.bas,'bit',k.bit,'esik',k.esik,'durum',k.durum,
 'imza',(select count(*) from oyun.sos_imza where kampanya_id=k.id),'imzaladim',exists(select 1 from oyun.sos_imza where kampanya_id=k.id and user_id=u),
 'dilekce_id',k.dilekce_id
 ) order by k.id desc)
 from (select * from oyun.sos_imza_kamp order by id desc limit 100) k),'[]'::jsonb);
end $$;
create or replace function public.sos_imza_baslat(p_makam text,p_kad text,p_il int,p_baslik text,p_metin text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); m oyun.makamlar; b text:=btrim(coalesce(p_baslik,'')); a text:=btrim(coalesce(p_metin,'')); es int; kid bigint;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 m:=oyun.sos_muhatap(p_makam,p_kad,p_il);
 if char_length(b) not between 5 and 120 or char_length(a) not between 10 and 3000 then raise exception 'Başlık 5–120, kampanya metni 10–3000 karakter olmalı.'; end if;
 if (select count(*) from oyun.sos_imza_kamp where acan=u and bas>t-interval '24 hours')>=3 then raise exception '24 saatte en fazla 3 imza kampanyası açabilirsin.'; end if;
 select greatest(3,ceil(count(*)::numeric*0.15)::int) into es from oyun.profiller where not yasakli;
 insert into oyun.sos_imza_kamp(acan,makam,muhatap,il_id,baslik,metin,bas,bit,esik)
 values(u,m.tur,m.user_id,m.il_id,b,a,t,t+interval '72 hours',es) returning id into kid;
 perform oyun.olay('siyaset',format('%s imza kampanyası açtı: %s',oyun.kad(u),b),m.il_id,null,t);
 return public.sos_imza_kampanyalari();
end $$;
create or replace function public.sos_imza_at(p_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); k oyun.sos_imza_kamp; n int; did bigint;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into k from oyun.sos_imza_kamp where id=p_id for update;
 if k.id is null or k.durum<>'acik' or k.bit<=t then raise exception 'Kampanya imzaya kapalı.'; end if;
 insert into oyun.sos_imza(kampanya_id,user_id,zaman) values(k.id,u,t) on conflict do nothing;
 if not found then raise exception 'Bu kampanyayı zaten imzaladın.'; end if;
 select count(*) into n from oyun.sos_imza where kampanya_id=k.id;
 if n>=k.esik then
  insert into oyun.sos_dilekce(gonderen,makam,muhatap,il_id,baslik,metin,olusturma,imza_kamp_id)
  values(k.acan,k.makam,k.muhatap,k.il_id,k.baslik,k.metin,t,k.id) returning id into did;
  update oyun.sos_imza_kamp set durum='basarili',dilekce_id=did where id=k.id;
  perform oyun.bildir(k.muhatap,format('“%s” kampanyası %s imzayla resmi dilekçe olarak makamına sunuldu.',k.baslik,n),t);
  perform oyun.bildir(k.acan,format('“%s” kampanyan hedefe ulaştı ve resmi dilekçeye dönüştü.',k.baslik),t);
  perform oyun.olay('siyaset',format('%s imzayla “%s” kampanyası resmi dilekçeye dönüştü.',n,k.baslik),k.il_id,null,t);
 end if;
 return public.sos_imza_kampanyalari();
end $$;

do $$ declare f text; begin
 foreach f in array array[
 'sos_dilekceler()','sos_dilekce_gonder(text,text,integer,text,text)','sos_dilekce_yanit(bigint,text,text)',
 'sos_imza_kampanyalari()','sos_imza_baslat(text,text,integer,text,text)','sos_imza_at(bigint)'
 ] loop execute 'revoke all on function public.'||f||' from public,anon'; execute 'grant execute on function public.'||f||' to authenticated'; end loop;
end $$;
