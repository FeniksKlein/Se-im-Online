-- Şirket vergileri, günlük tahakkuk ve ortak kâr payı: mevcut kayıtlar korunur.
create table if not exists oyun.eko_vergi_turleri(
 kod text primary key check(kod ~ '^[a-z_]{3,35}$'),
 ad text not null check(length(ad) between 3 and 70),
 matrah text not null check(matrah in ('satis','kar','dagitim','sozlesme','genel_gelir')),
 oran numeric not null check(oran between 0 and 50),
 aktif boolean not null default true,
 kaynak_kanun bigint references oyun.kanunlar(id),
 guncelleme timestamptz not null default now()
);
insert into oyun.eko_vergi_turleri(kod,ad,matrah,oran) values
 ('kdv','Katma Değer Vergisi','satis',20),
 ('kurumlar','Kurumlar Vergisi','kar',25),
 ('stopaj','Kâr Payı Stopajı','dagitim',15),
 ('gelir','Gelir Vergisi','genel_gelir',coalesce((select vergi from oyun.ulke where id=1),20)),
 ('damga','Damga Vergisi','sozlesme',1)
on conflict(kod) do nothing;

create table if not exists oyun.eko_vergi_hareket(
 id bigint generated always as identity primary key,
 sirket_id bigint references oyun.sirketler(id),
 oyuncu uuid references auth.users(id),
 kod text not null references oyun.eko_vergi_turleri(kod),
 matrah numeric not null check(matrah>=0),
 oran numeric not null check(oran>=0),
 tutar numeric not null check(tutar>=0),
 kaynak text not null, kaynak_id bigint,
 zaman timestamptz not null default now(),
 unique(kod,kaynak,kaynak_id,sirket_id,oyuncu)
);
create index if not exists eko_vergi_hareket_sirket_idx on oyun.eko_vergi_hareket(sirket_id,zaman desc);

create table if not exists oyun.eko_kar_kayit(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 tur text not null, kaynak_id bigint not null,
 gun date not null,
 ciro numeric not null default 0,
 vergi numeric not null default 0,
 net_kar numeric not null,
 zaman timestamptz not null default now(),
 unique(sirket_id,tur,kaynak_id)
);
create index if not exists eko_kar_kayit_sirket_gun_idx on oyun.eko_kar_kayit(sirket_id,gun);

create table if not exists oyun.eko_ortak_gunluk_hak(
 sirket_id bigint not null references oyun.sirketler(id),
 user_id uuid not null references auth.users(id),
 gun date not null,
 hak numeric not null default 0,
 cekilen numeric not null default 0 check(cekilen>=0),
 primary key(sirket_id,user_id,gun)
);
create index if not exists eko_ortak_hak_oyuncu_idx on oyun.eko_ortak_gunluk_hak(user_id,gun desc);
create table if not exists oyun.eko_kar_odeme(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 user_id uuid not null references auth.users(id),
 gun date not null,
 brut numeric not null check(brut>0),
 stopaj numeric not null check(stopaj>=0),
 net numeric not null check(net>=0),
 zaman timestamptz not null default now()
);
create index if not exists eko_kar_odeme_oyuncu_idx on oyun.eko_kar_odeme(user_id,zaman desc);
alter table oyun.eko_vergi_turleri enable row level security;
alter table oyun.eko_vergi_hareket enable row level security;
alter table oyun.eko_kar_kayit enable row level security;
alter table oyun.eko_ortak_gunluk_hak enable row level security;
alter table oyun.eko_kar_odeme enable row level security;

create or replace function oyun.eko_vergi_oran(p_kod text)
returns numeric language sql stable security definer set search_path to '' as $$
 select coalesce((select oran from oyun.eko_vergi_turleri
  where kod=p_kod and aktif),0) $$;
revoke all on function oyun.eko_vergi_oran(text) from public,anon,authenticated;

-- Tek kaynak anahtarı ile kârın iki kez tahakkuk etmesini önler.
create or replace function oyun.eko_kar_yaz(p_sirket bigint,p_tur text,p_kaynak bigint,
 p_ciro numeric,p_vergi numeric,p_kar numeric,p_zaman timestamptz default now())
returns boolean language plpgsql security definer set search_path to '' as $$
declare d date:=(p_zaman at time zone 'Europe/Istanbul')::date; x record;
begin
 if p_sirket is null or p_kaynak is null or p_tur not in ('magaza','toptan','franchise','sozlesme')
 then raise exception 'Gecersiz kar tahakkuku.'; end if;
 insert into oyun.eko_kar_kayit(sirket_id,tur,kaynak_id,gun,ciro,vergi,net_kar,zaman)
 values(p_sirket,p_tur,p_kaynak,d,coalesce(p_ciro,0),coalesce(p_vergi,0),coalesce(p_kar,0),p_zaman)
 on conflict(sirket_id,tur,kaynak_id) do nothing;
 if not found then return false;end if;
 for x in select user_id,pay from oyun.sirket_ortaklari where sirket_id=p_sirket
 loop
  insert into oyun.eko_ortak_gunluk_hak(sirket_id,user_id,gun,hak)
  values(p_sirket,x.user_id,d,round(coalesce(p_kar,0)*x.pay/100,2))
  on conflict(sirket_id,user_id,gun) do update
  set hak=oyun.eko_ortak_gunluk_hak.hak+excluded.hak;
 end loop;
 return true;
end $$;
revoke all on function oyun.eko_kar_yaz(bigint,text,bigint,numeric,numeric,numeric,timestamptz) from public,anon,authenticated;

create or replace function public.eko_vergi_panel()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli)
 then raise exception 'Oturum gerekli.';end if;
 return jsonb_build_object(
 'vergiler',coalesce((select jsonb_agg(jsonb_build_object(
 'kod',kod,'ad',ad,'matrah',matrah,'oran',case when kod='gelir' then
  (select vergi from oyun.ulke where id=1) else oran end,'aktif',aktif,
 'kanun',kaynak_kanun) order by kod)
 from oyun.eko_vergi_turleri),'[]'::jsonb),
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object(
 'id',s.id,'ad',s.ad,'kasa',s.kasa,'sermaye',s.sermaye,
 'payim',o.pay,'benim_hak',coalesce((select sum(hak-cekilen) from oyun.eko_ortak_gunluk_hak
 where sirket_id=s.id and user_id=u and gun<(oyun.simdi() at time zone 'Europe/Istanbul')::date),0),
 'bugun_ciro',coalesce((select sum(ciro) from oyun.eko_kar_kayit where sirket_id=s.id
 and gun=(oyun.simdi() at time zone 'Europe/Istanbul')::date),0),
 'bugun_kar',coalesce((select sum(net_kar) from oyun.eko_kar_kayit where sirket_id=s.id
 and gun=(oyun.simdi() at time zone 'Europe/Istanbul')::date),0),
 'son7_vergi',coalesce((select sum(tutar) from oyun.eko_vergi_hareket where sirket_id=s.id
 and zaman>oyun.simdi()-interval '7 days'),0)
 ))
 from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id and o.user_id=u
 where s.aktif and exists(select 1 from oyun.eko_isletmeler where sirket_id=s.id)),'[]'::jsonb),
 'odemeler',coalesce((select jsonb_agg(jsonb_build_object('sirket',s.ad,'brut',o.brut,
 'net',o.net,'stopaj',o.stopaj,'gun',o.gun,'zaman',o.zaman) order by o.zaman desc)
 from (select * from oyun.eko_kar_odeme where user_id=u order by id desc limit 35) o
 join oyun.sirketler s on s.id=o.sirket_id),'[]'::jsonb),
 'meclis_teklifleri',coalesce((select jsonb_agg(jsonb_build_object('id',k.id,
 'baslik',k.baslik,'kod',k.veri->>'kod','durum',k.durum,'islem',k.veri->>'islem')
 order by k.teklif_at desc)
 from (select * from oyun.kanunlar where veri->>'ozel_tur'='sirket_vergisi'
 order by teklif_at desc limit 25) k),'[]'::jsonb)
 );
end $$;
revoke all on function public.eko_vergi_panel() from public,anon;
grant execute on function public.eko_vergi_panel() to authenticated;
