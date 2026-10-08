
create table if not exists oyun.bel_aday_destek (
 secim_id bigint not null references oyun.secimler(id) on delete cascade,
 il_id smallint not null references oyun.iller(id),
 parti_id bigint not null references oyun.partiler(id),
 hedef_parti_id bigint not null references oyun.partiler(id),
 aday_id bigint not null references oyun.adaylar(id) on delete cascade,
 zaman timestamptz not null default now(),
 primary key(secim_id,il_id,parti_id),
 check(parti_id<>hedef_parti_id)
);
create index if not exists bel_aday_destek_hedef_idx on oyun.bel_aday_destek(secim_id,il_id,hedef_parti_id);
alter table oyun.bel_aday_destek enable row level security;
revoke all on oyun.bel_aday_destek from public,anon,authenticated;

create or replace function public.bel_aday_destek(p_il smallint,p_hedef_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid();pa oyun.partiler;s oyun.secimler;os oyun.secimler;
 a oyun.adaylar;t timestamptz:=oyun.simdi();iid bigint;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 select * into pa from oyun.partiler where gb=u and not kapali;
 if not found then raise exception 'Bu karar yalnızca genel başkan tarafından verilir';end if;
 if p_il is null or p_hedef_parti is null or p_hedef_parti=pa.id then raise exception 'Geçerli il ve başka parti seç';end if;
 select * into s from oyun.secimler
 where tur='bel' and durum='bekliyor' and oy_bas>t
   and (not ara or hedef_il_id=p_il)
 order by ara desc,oy_bas limit 1 for update;
 if not found then raise exception 'Bu ilde destek kararı için seçim bulunamadı ya da oy verme başladı';end if;
 select * into os from oyun.secimler where tur='bel_on' and donem=s.donem;
 if os.id is null or t<os.sonuc_at or os.durum='bekliyor' then
   raise exception 'Belediye ön seçimi sonuçlanmadan ortak aday belirlenemez';end if;
 select * into a from oyun.adaylar
 where secim_id=s.id and il_id=p_il and parti_id=p_hedef_parti
 order by basvuru_at,id limit 1;
 if not found then raise exception 'Hedef partinin bu ilde kesinleşmiş adayı bulunmuyor';end if;
 if not exists(select 1 from oyun.partiler where id=p_hedef_parti and not kapali)
 then raise exception 'Hedef parti faal değil';end if;
 insert into oyun.bel_aday_destek(secim_id,il_id,parti_id,hedef_parti_id,aday_id,zaman)
 values(s.id,p_il,pa.id,p_hedef_parti,a.id,t)
 on conflict(secim_id,il_id,parti_id) do update
 set hedef_parti_id=excluded.hedef_parti_id,aday_id=excluded.aday_id,zaman=excluded.zaman;
 delete from oyun.adaylar where secim_id=s.id and il_id=p_il and parti_id=pa.id;
 select x.ittifak_id into iid from oyun.ittifak_uyeler x
 join oyun.ittifak_uyeler y on x.ittifak_id=y.ittifak_id
 where x.parti_id=pa.id and y.parti_id=p_hedef_parti limit 1;
 perform oyun.olay('ittifak',left(pa.kisa||', '||p_il||'. ilde '||
  (select kisa from oyun.partiler where id=p_hedef_parti)||' adayını destekliyor',200),p_il,pa.id,t);
 return jsonb_build_object('tamam',true,'secim',s.id,'il',p_il,
   'aday',oyun.kad(a.user_id),'desteklenen_parti',p_hedef_parti,'ortak_ittifak_adayi',iid is not null);
end $function$;
revoke all on function public.bel_aday_destek(smallint,bigint) from public,anon;
grant execute on function public.bel_aday_destek(smallint,bigint) to authenticated;

create or replace function public.bel_destek_geri_cek(p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid();pa oyun.partiler;s oyun.secimler;a oyun.adaylar;
 t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into pa from oyun.partiler where gb=u and not kapali;
 if not found then raise exception 'Genel başkan yetkisi gerekli';end if;
 select * into s from oyun.secimler where tur='bel' and durum='bekliyor'
   and oy_bas>t and (not ara or hedef_il_id=p_il)
 order by ara desc,oy_bas limit 1 for update;
 if not found then raise exception 'Seçim başladı veya aktif değil';end if;
 delete from oyun.bel_aday_destek where secim_id=s.id and il_id=p_il and parti_id=pa.id;
 if not found then raise exception 'Geri çekilecek destek kararı bulunamadı';end if;
 select a2.* into a from oyun.adaylar a2
 join oyun.secimler os on os.id=a2.secim_id
 where os.tur='bel_on' and os.donem=s.donem and a2.il_id=p_il and a2.parti_id=pa.id
 order by a2.oy desc nulls last,a2.basvuru_at,a2.id limit 1;
 if a.id is not null and not exists(select 1 from oyun.adaylar where secim_id=s.id and user_id=a.user_id) then
   insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,basvuru_at,vaat)
   values(s.id,a.user_id,a.parti_id,a.il_id,a.basvuru_at,a.vaat)
   on conflict(secim_id,user_id) do nothing;
 end if;
 return jsonb_build_object('tamam',true,'il',p_il,'aday_geri_geldi',a.id is not null);
end $function$;
revoke all on function public.bel_destek_geri_cek(smallint) from public,anon;
grant execute on function public.bel_destek_geri_cek(smallint) to authenticated;

create or replace function public.bel_destek_durum(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid();s oyun.secimler;t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.partiler where id=p_parti and not kapali) then raise exception 'Parti bulunamadı';end if;
 select * into s from oyun.secimler where tur='bel' and durum='bekliyor' and oy_bit>=t
 order by ara desc,oy_bas limit 1;
 return jsonb_build_object('secim_id',s.id,'donem',s.donem,
  'acik',s.id is not null and t<s.oy_bas,
  'adaylar',coalesce((
    select jsonb_agg(jsonb_build_object('id',a.id,'il',i.ad,'il_id',a.il_id,
      'kad',pr.kad,'parti_id',a.parti_id,'parti',pa.kisa,
      'ittifak_ortagi',exists(select 1 from oyun.ittifak_uyeler x
         join oyun.ittifak_uyeler y on y.ittifak_id=x.ittifak_id
         where x.parti_id=p_parti and y.parti_id=a.parti_id))
      order by i.ad,pa.kisa)
    from oyun.adaylar a join oyun.profiller pr on pr.id=a.user_id
    join oyun.iller i on i.id=a.il_id join oyun.partiler pa on pa.id=a.parti_id
    where a.secim_id=s.id and a.parti_id<>p_parti
  ),'[]'::jsonb),
  'desteklerim',coalesce((
    select jsonb_agg(jsonb_build_object('il_id',x.il_id,'il',i.ad,
      'aday',oyun.kad(a.user_id),'parti',pa.kisa,'parti_id',x.hedef_parti_id)
      order by i.ad)
    from oyun.bel_aday_destek x join oyun.adaylar a on a.id=x.aday_id
    join oyun.iller i on i.id=x.il_id join oyun.partiler pa on pa.id=x.hedef_parti_id
    where x.secim_id=s.id and x.parti_id=p_parti
  ),'[]'::jsonb));
end $function$;
revoke all on function public.bel_destek_durum(bigint) from public,anon;
grant execute on function public.bel_destek_durum(bigint) to authenticated;
