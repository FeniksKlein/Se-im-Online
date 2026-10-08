
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

-- CB desteği artık ittifak dışı partilere de açık, fakat gerçek kesin aday şartı korunur.
CREATE OR REPLACE FUNCTION public.cb_destek(p_parti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  s oyun.secimler;
  hedef oyun.partiler;
begin
  pa := oyun.gb_partim(p);

  select * into s
  from oyun.secimler
  where tur = 'cb'
    and t >= basvuru_bas
    and t < basvuru_bit
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Cumhurbaşkanı adayı belirleme dönemi şu anda açık değil.';
  end if;

  select * into hedef
  from oyun.partiler
  where id = p_parti and not kapali;

  if hedef.id is null or hedef.id = pa.id then
    raise exception 'Geçersiz parti.';
  end if;

  -- Gerçek oyun dışındaki partilere de aday desteği verilebilir.
  -- Yalnızca resmen açıklanmış gerçek oyuncu adayı desteklenebilir.
  if not exists(select 1 from oyun.adaylar a
    where a.secim_id=s.id and a.parti_id=hedef.id)
  then raise exception 'Hedef partinin resmen açıklanmış Cumhurbaşkanı adayı yok.';end if;
  if exists(select 1 from oyun.cb_kararlar k
    where k.donem=s.donem and k.parti_id=hedef.id and k.yontem='destek')
  then raise exception 'Zaten başka adayı destekleyen parti hedef seçilemez.';end if;

  insert into oyun.cb_kararlar(
    donem, parti_id, yontem, aday, destek_parti, zaman
  )
  values (
    s.donem, pa.id, 'destek', null, hedef.id, t
  )
  on conflict(donem,parti_id) do update
    set yontem = 'destek',
        aday = null,
        destek_parti = excluded.destek_parti,
        zaman = excluded.zaman;

  delete from oyun.adaylar
  where secim_id = s.id and parti_id = pa.id;

  perform oyun.olay(
    'ittifak',
    format(
      '%s, cumhurbaşkanlığı seçiminde %s''nin adayını destekleme kararı aldı.',
      pa.kisa, hedef.kisa
    ),
    null, pa.id, t
  );

  return public.durum();
end $function$
;

-- Belediye pusulasında ortak destek veren partileri göster; oylar tek oyuncu adayı üzerinde toplanır.
CREATE OR REPLACE FUNCTION public.secim_detay(p_secim bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  s oyun.secimler;
  onsecim bigint;
  secenek jsonb;
begin
  select * into s from oyun.secimler where id=p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;

  if s.tur='mv' then
    select id into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;

    select coalesce(jsonb_agg(x order by x->>'kisa'),'[]'::jsonb)
    into secenek
    from (
      select oyun.parti_json(a.parti_id) || jsonb_build_object(
        'hedef',a.parti_id,
        'bagimsiz',false,
        'beyanname',oyun.beyanname_json(a.parti_id,s.donem),
        'liste',jsonb_agg(jsonb_build_object(
          'kad',oyun.kad(a.user_id),
          'sira',a.sira,
          'vaat',a.vaat,
          'vaatler',oyun.aday_vaatleri(a.user_id,s.id)
        ) order by a.sira)
      ) x
      from oyun.adaylar a
      where a.secim_id=onsecim
        and a.il_id=p.il_id
        and a.parti_id is not null
        and a.sira is not null
      group by a.parti_id
    ) z;

    select secenek || coalesce(jsonb_agg(
      jsonb_build_object(
        'hedef',-a.id,
        'bagimsiz',true,
        'ad',pr.kad,
        'kad',pr.kad,
        'kisa',null,
        'renk','#8e8e93',
        'amblem',null,
        'il_id',a.il_id,
        'vaat',a.vaat,
        'vaatler',oyun.aday_vaatleri(a.user_id,s.id),
        'beyanname',null,
        'liste',jsonb_build_array(jsonb_build_object(
          'kad',pr.kad,'sira',1,'vaat',a.vaat,
          'vaatler',oyun.aday_vaatleri(a.user_id,s.id)
        ))
      ) order by a.basvuru_at,a.id
    ),'[]'::jsonb)
    into secenek
    from oyun.adaylar a
    join oyun.profiller pr on pr.id=a.user_id
    where a.secim_id=s.id
      and a.parti_id is null
      and a.il_id=p.il_id;
  else
    select coalesce(jsonb_agg(
      oyun.aday_json(a.id) || jsonb_build_object(
        'hedef',a.id,
        'oy',case when s.durum='bekliyor' then null else a.oy end,
        'beyanname',case when s.tur in ('cb','cb2') and a.parti_id is not null
                         then oyun.beyanname_json(a.parti_id,s.donem) end
      )
      order by a.parti_id nulls last,a.basvuru_at
    ),'[]'::jsonb)
    into secenek
    from oyun.adaylar a
    where a.secim_id=s.id and (
      (s.tur in ('mv_on','bel_on') and a.il_id=p.il_id and a.parti_id=p.parti_id) or
      (s.tur in ('kurultay','cb_on') and a.parti_id=p.parti_id) or
      (s.tur='bel' and a.il_id=p.il_id) or
      (s.tur in ('cb','cb2'))
    );
  end if;

  return oyun.secim_ozet(s,p,t) || jsonb_build_object(
    'secenekler',secenek,
    'sonuc',s.sonuc,
    'benim_il',p.il_id,
    'benim_parti',p.parti_id,
    'destekler',case when s.tur in ('cb','cb2') then coalesce((
      select jsonb_object_agg(x.destek_parti::text,x.l)
      from (
        select k.destek_parti,jsonb_agg(oyun.parti_json(k.parti_id)) l
        from oyun.cb_kararlar k
        where k.donem=s.donem and k.yontem='destek'
        group by k.destek_parti
      ) x
    ),'{}'::jsonb)
    when s.tur='bel' then coalesce((
      select jsonb_object_agg(z.hedef_parti::text,z.l)
      from (
        select d.hedef_parti_id hedef_parti,
          jsonb_agg(oyun.parti_json(d.parti_id) order by d.parti_id) l
        from oyun.bel_aday_destek d
        join oyun.adaylar a on a.id=d.aday_id and a.secim_id=s.id
          and a.parti_id=d.hedef_parti_id and a.il_id=p.il_id
        where d.secim_id=s.id and d.il_id=p.il_id
        group by d.hedef_parti_id
      ) z
    ),'{}'::jsonb) end
  );
end $function$
;
