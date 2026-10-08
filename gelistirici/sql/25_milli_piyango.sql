-- Tamamen sanal oyun parasıyla milli piyango. Haftalık çekiliş ve devir.
create table if not exists oyun.piyango_donem (
 id bigint generated always as identity primary key,
 baslangic timestamptz not null unique,
 bitis timestamptz not null,
 ikramiye numeric not null default 1000000,
 bilet_sayisi integer not null default 0,
 kazanan_no integer,
 kazanan uuid,
 cekildi boolean not null default false,
 cekilis_at timestamptz
);
create table if not exists oyun.piyango_bilet (
 id bigint generated always as identity primary key,
 donem_id bigint not null references oyun.piyango_donem(id),
 user_id uuid not null references auth.users(id),
 numara integer not null check(numara between 0 and 999999),
 bedel numeric not null,
 alis timestamptz not null default now()
);
create index if not exists piyango_bilet_donem_no on oyun.piyango_bilet(donem_id,numara);
create index if not exists piyango_bilet_user on oyun.piyango_bilet(user_id,donem_id);
alter table oyun.piyango_donem enable row level security;
alter table oyun.piyango_bilet enable row level security;
revoke all on oyun.piyango_donem,oyun.piyango_bilet from public,anon,authenticated;
create or replace function oyun.piyango_guncelle()
returns bigint language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare t timestamptz:=now(); bas timestamptz; curid bigint; prev record; winning integer; winner uuid; roll numeric:=1000000;
begin
 perform pg_advisory_xact_lock(77890011);
 -- Periyotlar Perşembe 00:00 UTC başlangıçlı, tam 7 gün.
 bas:=timestamptz '2026-10-08 00:00:00+00'+floor(extract(epoch from (t-timestamptz '2026-10-08 00:00:00+00'))/604800)*interval '7 days';
 for prev in select * from oyun.piyango_donem where bitis<=t and not cekildi order by baslangic for update loop
   winning:=floor(random()*1000000)::int;
   select user_id into winner from oyun.piyango_bilet
   where donem_id=prev.id and numara=winning order by id limit 1;
   update oyun.piyango_donem set cekildi=true,kazanan_no=winning,kazanan=winner,cekilis_at=t where id=prev.id;
   if winner is not null then
     perform oyun.para_islem(winner,prev.ikramiye,'piyango','Milli piyango büyük ikramiyesi',t);
   end if;
 end loop;
 select id into curid from oyun.piyango_donem where baslangic=bas;
 if curid is null then
   select case when kazanan is null then ikramiye else 1000000 end
   into roll from oyun.piyango_donem where bitis<=bas order by bitis desc limit 1;
   insert into oyun.piyango_donem(baslangic,bitis,ikramiye)
   values(bas,bas+interval '7 days',coalesce(roll,1000000))
   on conflict(baslangic) do update set baslangic=excluded.baslangic returning id into curid;
 end if;
 return curid;
end $$;
revoke all on function oyun.piyango_guncelle() from public,anon,authenticated;

create or replace function public.piyango_durum()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); d bigint; result jsonb;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Önce giriş yapıp profil oluştur.'; end if;
 d:=oyun.piyango_guncelle();
 select jsonb_build_object('ikramiye',p.ikramiye,'bitis',p.bitis,'bilet_bedeli',1000,'bilet_sayisi',p.bilet_sayisi,
 'biletler',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'numara',lpad(b.numara::text,6,'0')) order by b.id desc) from oyun.piyango_bilet b where b.donem_id=d and b.user_id=u),'[]'::jsonb),
 'sonuc',(select jsonb_build_object('kazanan_no',lpad(x.kazanan_no::text,6,'0'),'devretti',x.kazanan is null,'ikramiye',x.ikramiye) from oyun.piyango_donem x where x.cekildi order by x.bitis desc limit 1))
 into result from oyun.piyango_donem p where p.id=d;
 return result;
end $$;

create or replace function public.piyango_bilet_al(p_adet int default 1)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); d bigint; k int;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 if p_adet is null or p_adet<1 or p_adet>10 then raise exception 'Bir işlemde 1-10 bilet alınabilir.'; end if;
 d:=oyun.piyango_guncelle();
 perform oyun.para_islem(u,-1000*p_adet,'piyango','Milli piyango biletleri',now());
 for k in 1..p_adet loop
   insert into oyun.piyango_bilet(donem_id,user_id,numara,bedel)
   values(d,u,floor(random()*1000000)::int,1000);
 end loop;
 update oyun.piyango_donem set bilet_sayisi=bilet_sayisi+p_adet,ikramiye=ikramiye+700*p_adet where id=d;
 -- hazine milyon TL birimiyle tutuluyor.
 update oyun.ulke set hazine=hazine+(300*p_adet)/1000000.0 where id=1;
 return public.piyango_durum();
end $$;
revoke all on function public.piyango_durum() from public,anon;
revoke all on function public.piyango_bilet_al(int) from public,anon;
grant execute on function public.piyango_durum() to authenticated;
grant execute on function public.piyango_bilet_al(int) to authenticated;
