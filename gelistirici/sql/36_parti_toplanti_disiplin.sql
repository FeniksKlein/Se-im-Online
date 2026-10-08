-- Parti grup toplantısı konuşmaları ve üye oyuyla disiplin kararı.
create table if not exists oyun.parti_grup_duyuru(
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id),
 yazan uuid not null references oyun.profiller(id),
 baslik text not null check(length(baslik) between 5 and 120),
 metin text not null check(length(metin) between 10 and 3000),
 zaman timestamptz not null default now()
);
create index if not exists grup_duyuru_parti on oyun.parti_grup_duyuru(parti_id,id desc);
alter table oyun.parti_grup_duyuru enable row level security;
revoke all on oyun.parti_grup_duyuru from public,anon,authenticated;
create or replace function public.grup_duyurulari(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('yazabilirim',exists(select 1 from oyun.partiler where id=p_parti and gb=auth.uid() and not kapali),
 'kayitlar',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'baslik',g.baslik,'metin',g.metin,
 'tarih',g.zaman,'yazan',oyun.kad(g.yazan)) order by g.id desc)
 from (select * from oyun.parti_grup_duyuru where parti_id=p_parti order by id desc limit 30) g),'[]'::jsonb));
end $$;
create or replace function public.grup_duyuru_yayinla(p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); pid bigint; bas text:=btrim(coalesce(p_baslik,'')); msg text:=btrim(coalesce(p_metin,''));
begin
 select id into pid from oyun.partiler where gb=u and not kapali;
 if u is null or pid is null then raise exception 'Yalnızca genel başkan duyuru yayımlayabilir'; end if;
 if length(bas) not between 5 and 120 or length(msg) not between 10 and 3000 then raise exception 'Başlık 5-120, metin 10-3000 karakter olmalı'; end if;
 if (select count(*) from oyun.parti_grup_duyuru where yazan=u and zaman>now()-interval '1 day')>=3 then raise exception '24 saatte en çok 3 konuşma yayımlayabilirsin'; end if;
 insert into oyun.parti_grup_duyuru(parti_id,yazan,baslik,metin) values(pid,u,bas,msg);
 insert into oyun.bildirimler(user_id,zaman,metin)
 select id,now(),'Partinin genel başkanı yeni grup konuşması yayımladı: '||left(bas,80)
 from oyun.profiller where parti_id=pid and id<>u;
 perform oyun.olay('parti','Yeni grup toplantısı konuşması: '||left(bas,100),null,pid,now());
 return public.grup_duyurulari(pid);
end $$;

create table if not exists oyun.parti_disiplin(
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id),
 hedef uuid not null references oyun.profiller(id),
 baslatan uuid not null references oyun.profiller(id),
 gerekce text not null check(length(gerekce) between 10 and 500),
 bas timestamptz not null default now(),
 bit timestamptz not null,
 uyeler int not null check(uyeler>=1),
 durum text not null default 'oylamada' check(durum in ('oylamada','ihrac','ret'))
);
create unique index if not exists disiplin_acik on oyun.parti_disiplin(hedef) where durum='oylamada';
create table if not exists oyun.parti_disiplin_oy(
 id bigint not null references oyun.parti_disiplin(id),
 user_id uuid not null references oyun.profiller(id),
 oy text not null check(oy in ('evet','hayir')),
 zaman timestamptz not null default now(),
 primary key(id,user_id)
);
alter table oyun.parti_disiplin enable row level security;
alter table oyun.parti_disiplin_oy enable row level security;
revoke all on oyun.parti_disiplin,oyun.parti_disiplin_oy from public,anon,authenticated;
create or replace function oyun.disiplin_sonuclandir()
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare d record; ev int; hy int;
begin
 perform pg_advisory_xact_lock(77250002);
 for d in select * from oyun.parti_disiplin where durum='oylamada' and bit<=now() for update loop
   select count(*) filter(where oy='evet'),count(*) filter(where oy='hayir') into ev,hy
     from oyun.parti_disiplin_oy where id=d.id;
   if ev>hy and ev>=(floor(d.uyeler/2)::int+1) and
      exists(select 1 from oyun.profiller where id=d.hedef and parti_id=d.parti_id)
      and not exists(select 1 from oyun.partiler where id=d.parti_id and gb=d.hedef) then
     perform oyun._ayril(d.hedef,now());
     update oyun.parti_disiplin set durum='ihrac' where id=d.id;
     perform oyun.bildir(d.hedef,'Parti disiplin oylaması sonucunda üyelikten çıkarıldın.',now());
     perform oyun.olay('parti','Parti disiplin kurulunun ihraç kararı sonuçlandı.',null,d.parti_id,now());
   else update oyun.parti_disiplin set durum='ret' where id=d.id;
   end if;
 end loop;
end $$;
create or replace function public.disiplin_durum(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.disiplin_sonuclandir();
 return jsonb_build_object('gb_miyim',exists(select 1 from oyun.partiler where id=p_parti and gb=u),
 'uye_miyim',exists(select 1 from oyun.profiller where id=u and parti_id=p_parti),
 'kayitlar',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'hedef',oyun.kad(d.hedef),
 'gerekce',d.gerekce,'bas',d.bas,'bit',d.bit,'uyeler',d.uyeler,'durum',d.durum,
 'evet',(select count(*) from oyun.parti_disiplin_oy o where o.id=d.id and o.oy='evet'),
 'hayir',(select count(*) from oyun.parti_disiplin_oy o where o.id=d.id and o.oy='hayir'),
 'oyum',(select oy from oyun.parti_disiplin_oy o where o.id=d.id and o.user_id=u))
 order by d.id desc) from (select * from oyun.parti_disiplin where parti_id=p_parti order by id desc limit 30) d),'[]'::jsonb));
end $$;
create or replace function public.disiplin_baslat(p_hedef text,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); pid bigint; hedef uuid; cnt int; gerekce text:=btrim(coalesce(p_gerekce,''));
begin
 perform oyun.disiplin_sonuclandir();
 select id into pid from oyun.partiler where gb=u and not kapali;
 if u is null or pid is null then raise exception 'Yalnızca genel başkan disiplin süreci başlatabilir'; end if;
 if length(gerekce) not between 10 and 500 then raise exception 'Gerekçe 10-500 karakter olmalı'; end if;
 select id into hedef from oyun.profiller where lower(kad)=lower(btrim(p_hedef)) and parti_id=pid;
 if hedef is null or hedef=u then raise exception 'Bu partideki başka bir üyeyi seçmelisin'; end if;
 select count(*) into cnt from oyun.profiller where parti_id=pid and id<>hedef;
 if cnt<1 then raise exception 'Oylamaya katılacak üye yok'; end if;
 insert into oyun.parti_disiplin(parti_id,hedef,baslatan,gerekce,bit,uyeler)
 values(pid,hedef,u,gerekce,now()+interval '24 hours',cnt);
 perform oyun.bildir(hedef,'Hakkında 24 saatlik parti disiplin oylaması başlatıldı.',now());
 return public.disiplin_durum(pid);
end $$;
create or replace function public.disiplin_oyla(p_id bigint,p_oy text)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); d oyun.parti_disiplin%rowtype;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_oy not in ('evet','hayir') then raise exception 'Geçersiz oy'; end if;
 perform oyun.disiplin_sonuclandir();
 select * into d from oyun.parti_disiplin where id=p_id for update;
 if d.id is null or d.durum<>'oylamada' or d.bit<=now() then raise exception 'Oylama kapalı'; end if;
 if d.hedef=u or not exists(select 1 from oyun.profiller where id=u and parti_id=d.parti_id)
 then raise exception 'Yalnızca hedef dışındaki parti üyeleri oy kullanabilir'; end if;
 insert into oyun.parti_disiplin_oy(id,user_id,oy) values(p_id,u,p_oy)
 on conflict (id,user_id) do update set oy=excluded.oy,zaman=now();
 return public.disiplin_durum(d.parti_id);
end $$;
revoke all on function public.grup_duyurulari(bigint),public.grup_duyuru_yayinla(text,text),
 public.disiplin_durum(bigint),public.disiplin_baslat(text,text),public.disiplin_oyla(bigint,text)
 from public,anon;
grant execute on function public.grup_duyurulari(bigint),public.grup_duyuru_yayinla(text,text),
 public.disiplin_durum(bigint),public.disiplin_baslat(text,text),public.disiplin_oyla(bigint,text) to authenticated;
revoke all on function oyun.disiplin_sonuclandir() from public,anon,authenticated;
