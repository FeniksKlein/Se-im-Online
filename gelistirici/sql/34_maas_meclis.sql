-- Cumhurbaşkanı ve milletvekili maaş değişiklikleri: Meclis oylamasıyla yürürlüğe girer.
create table if not exists oyun.makam_ucret_ayar(
 tur text primary key check(tur in ('cb','mv')),
 carpan numeric(8,4) not null default 1 check(carpan between 0.5 and 3),
 son_karar timestamptz
);
insert into oyun.makam_ucret_ayar(tur,carpan) values('cb',1),('mv',1) on conflict do nothing;
create table if not exists oyun.maas_teklif (
 id bigint generated always as identity primary key,
 tur text not null check(tur in ('cb','mv')),
 onerici uuid not null references oyun.profiller(id),
 eski numeric not null,
 yeni numeric not null check(yeni between 0.5 and 3),
 bas timestamptz not null default now(),
 bit timestamptz not null,
 durum text not null default 'oylamada' check(durum in ('oylamada','kabul','ret')),
 evet int not null default 0, hayir int not null default 0
);
create unique index if not exists maas_teklif_aktif on oyun.maas_teklif(tur) where durum='oylamada';
create table if not exists oyun.maas_oy(
 teklif_id bigint not null references oyun.maas_teklif(id),
 user_id uuid not null references oyun.profiller(id),
 oy text not null check(oy in ('evet','hayir')),
 zaman timestamptz not null default now(),
 primary key(teklif_id,user_id)
);
alter table oyun.makam_ucret_ayar enable row level security;
alter table oyun.maas_teklif enable row level security;
alter table oyun.maas_oy enable row level security;
revoke all on oyun.makam_ucret_ayar,oyun.maas_teklif,oyun.maas_oy from public,anon,authenticated;
create or replace function oyun.maas_oylama_sonuc()
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare r record; toplam int; ev int; hy int; gerekli int;
begin
 perform pg_advisory_xact_lock(77250001);
 for r in select * from oyun.maas_teklif where durum='oylamada' and bit<=now() for update loop
   select count(*) into toplam from oyun.makamlar where tur='mv' and bit is null;
   select count(*) filter(where oy='evet'),count(*) filter(where oy='hayir') into ev,hy from oyun.maas_oy where teklif_id=r.id;
   gerekli:=greatest(1,ceil(toplam*0.25)::int);
   if ev>hy and ev>=gerekli then
     update oyun.makam_ucret_ayar set carpan=r.yeni,son_karar=now() where tur=r.tur;
     update oyun.maas_teklif set durum='kabul',evet=ev,hayir=hy where id=r.id;
     perform oyun.olay('meclis',format('%s maaş düzenlemesi Mecliste kabul edildi.',case r.tur when 'cb' then 'Cumhurbaşkanı' else 'Milletvekili' end),null,null,now());
   else
     update oyun.maas_teklif set durum='ret',evet=ev,hayir=hy where id=r.id;
   end if;
 end loop;
end $$;

create or replace function public.maas_durum()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.maas_oylama_sonuc();
 return jsonb_build_object('oranlar',(select jsonb_object_agg(tur,carpan) from oyun.makam_ucret_ayar),
  'cb_miyim',exists(select 1 from oyun.makamlar where tur='cb' and user_id=u and bit is null),
  'vekil_miyim',oyun.aktif_vekil(u),
  'teklifler',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'tur',t.tur,'eski',t.eski,
   'yeni',t.yeni,'bas',t.bas,'bit',t.bit,'durum',t.durum,
   'evet',(select count(*) from oyun.maas_oy v where v.teklif_id=t.id and v.oy='evet'),
   'hayir',(select count(*) from oyun.maas_oy v where v.teklif_id=t.id and v.oy='hayir'),
   'oyum',(select v.oy from oyun.maas_oy v where v.teklif_id=t.id and v.user_id=u))
   order by t.id desc) from (select * from oyun.maas_teklif order by id desc limit 20) t),'[]'::jsonb));
end $$;

create or replace function public.maas_teklif_ver(p_tur text,p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); old_rate numeric; last_date timestamptz;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.maas_oylama_sonuc();
 if p_tur not in ('cb','mv') then raise exception 'Geçersiz maaş türü'; end if;
 if p_tur='cb' and not exists(select 1 from oyun.makamlar where tur='cb' and user_id=u and bit is null)
 then raise exception 'Cumhurbaşkanı maaş teklifini yalnızca Cumhurbaşkanı sunabilir'; end if;
 if p_tur='mv' and not oyun.aktif_vekil(u) then raise exception 'Vekil maaş teklifini milletvekili sunabilir'; end if;
 if p_carpan is null or p_carpan<0.5 or p_carpan>3 then raise exception 'Maaş katsayısı 0,5 - 3 arasında olmalı'; end if;
 select carpan,son_karar into old_rate,last_date from oyun.makam_ucret_ayar where tur=p_tur for update;
 if old_rate=p_carpan then raise exception 'Önerilen maaş zaten geçerli'; end if;
 if last_date>now()-interval '7 days' then raise exception 'Aynı maaş bir hafta içinde tekrar değiştirilemez'; end if;
 if exists(select 1 from oyun.maas_teklif where tur=p_tur and durum='oylamada') then raise exception 'Bu maaş için oylama sürüyor'; end if;
 insert into oyun.maas_teklif(tur,onerici,eski,yeni,bit) values(p_tur,u,old_rate,p_carpan,now()+interval '24 hours');
 perform oyun.olay('meclis','Mecliste yeni maaş düzenlemesi oylamaya sunuldu.',null,null,now());
 return public.maas_durum();
end $$;

create or replace function public.maas_oyla(p_teklif bigint,p_oy text)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); teklif oyun.maas_teklif%rowtype;
begin
 if u is null or not oyun.aktif_vekil(u) then raise exception 'Yalnızca milletvekilleri oy kullanabilir'; end if;
 if exists(select 1 from oyun.makamlar where tur='tbmm' and user_id=u and bit is null) then raise exception 'TBMM Başkanı tarafsızdır'; end if;
 if p_oy not in ('evet','hayir') then raise exception 'Geçersiz oy'; end if;
 perform oyun.maas_oylama_sonuc();
 select * into teklif from oyun.maas_teklif where id=p_teklif for update;
 if teklif.id is null or teklif.durum<>'oylamada' or teklif.bit<=now() then raise exception 'Oylama kapalı'; end if;
 insert into oyun.maas_oy(teklif_id,user_id,oy) values(p_teklif,u,p_oy)
 on conflict (teklif_id,user_id) do update set oy=excluded.oy,zaman=now();
 return public.maas_durum();
end $$;

-- Saatlik makam ücretleri ve maaş kumbarası aynı katsayıyı okur.
create or replace function oyun.makam_maasi(p_tur text,p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select (case p_tur when 'cb' then 354497 when 'bakan' then 318009 when 'mv' then 310332
   when 'tbmm' then 60000 when 'bskv' then 30000 when 'grup_bskv' then 20000
   when 'bel' then (select case when mv>=14 then 317800 when mv>=8 then 267800 when mv>=4 then 198900 else 171400 end from oyun.iller where id=p_il)
   else 0 end)*(select endeks from oyun.ulke where id=1)
   *coalesce((select carpan from oyun.makam_ucret_ayar where tur=p_tur),1)
$$;
revoke all on function public.maas_durum(),public.maas_teklif_ver(text,numeric),public.maas_oyla(bigint,text) from public,anon;
grant execute on function public.maas_durum(),public.maas_teklif_ver(text,numeric),public.maas_oyla(bigint,text) to authenticated;
revoke all on function oyun.maas_oylama_sonuc() from public,anon,authenticated;
