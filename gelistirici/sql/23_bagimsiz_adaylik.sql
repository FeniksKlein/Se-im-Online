-- =====================================================================
-- SEÇİM SİMÜLASYONU ONLINE — 23) BAĞIMSIZ ADAYLIK
-- Partisiz oyuncular milletvekili, belediye başkanı ve Cumhurbaşkanı
-- seçimlerine bağımsız aday olarak katılabilir.
-- =====================================================================

create or replace function oyun.bagimsiz_hedef_tur(p_on_tur text)
returns text language sql immutable set search_path='' as $$
  select case p_on_tur
    when 'mv_on' then 'mv'
    when 'bel_on' then 'bel'
    when 'cb_on' then 'cb'
  end
$$;

create or replace function oyun.bagimsiz_hedef_secim(p_on_secim bigint)
returns bigint language sql stable set search_path='' as $$
  select h.id
  from oyun.secimler o
  join oyun.secimler h
    on h.donem=o.donem and h.tur=oyun.bagimsiz_hedef_tur(o.tur)
  where o.id=p_on_secim and o.tur in ('mv_on','bel_on','cb_on')
  limit 1
$$;

create or replace function oyun.bagimsiz_adaylik_var(u uuid)
returns boolean language sql stable set search_path='' as $$
  select exists(
    select 1
    from oyun.adaylar a
    join oyun.secimler s on s.id=a.secim_id
    where a.user_id=u
      and a.parti_id is null
      and s.tur in ('mv','bel','cb','cb2')
      and s.durum in ('bekliyor','sonuclandi')
      and coalesce(s.goreve_bas,s.sonuc_at)>=oyun.simdi()
  )
$$;

create or replace function oyun.bagimsiz_parti_kilidi()
returns trigger language plpgsql set search_path='' as $$
begin
  if old.parti_id is null
     and new.parti_id is not null
     and oyun.bagimsiz_adaylik_var(new.id) then
    raise exception 'Bağımsız adaylığın sonuçlanmadan bir partiye katılamaz veya parti kuramazsın. Önce bağımsız adaylığını geri çek.';
  end if;
  return new;
end $$;

drop trigger if exists bagimsiz_parti_kilidi on oyun.profiller;
create trigger bagimsiz_parti_kilidi
before update of parti_id on oyun.profiller
for each row execute function oyun.bagimsiz_parti_kilidi();

create or replace function public.bagimsiz_aday_ol(p_on_secim bigint)
returns jsonb
language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
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
end $$;

create or replace function public.bagimsiz_adaylik_geri_cek(p_on_secim bigint)
returns jsonb
language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
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

  delete from oyun.adaylar
  where secim_id=h.id and user_id=p.id and parti_id is null;
  if not found then raise exception 'Bu seçimde bağımsız adaylığın yok.'; end if;

  return public.durum();
end $$;

create or replace function oyun.secim_ozet(s oyun.secimler,p oyun.profiller,t timestamptz)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'id',s.id,
    'tur',s.tur,
    'donem',s.donem,
    'asama',oyun.asama(s,t),
    'basvuru_bas',s.basvuru_bas,
    'basvuru_bit',s.basvuru_bit,
    'oy_bas',s.oy_bas,
    'oy_bit',s.oy_bit,
    'sonuc_at',s.sonuc_at,
    'goreve_bas',s.goreve_bas,
    'ara',s.ara,
    'hedef_il_id',s.hedef_il_id,
    'hedef_il_ad',(select ad from oyun.iller where id=s.hedef_il_id),
    'hedef_parti_id',s.hedef_parti_id,
    'hedef_parti',oyun.parti_json(s.hedef_parti_id),
    'ara_neden',s.ara_neden,
    'adayim',exists(
      select 1 from oyun.adaylar a
      where a.secim_id=s.id and a.user_id=p.id
    ),
    'bagimsiz_adayim',case
      when p.parti_id is null and s.tur in ('mv_on','bel_on','cb_on') then exists(
        select 1 from oyun.adaylar a
        where a.secim_id=oyun.bagimsiz_hedef_secim(s.id)
          and a.user_id=p.id and a.parti_id is null
      )
      else false end,
    'bagimsiz_hedef_secim_id',case
      when p.parti_id is null and s.tur in ('mv_on','bel_on','cb_on')
      then oyun.bagimsiz_hedef_secim(s.id)
    end,
    'bagimsiz_ucret',case
      when p.parti_id is null and s.tur in ('mv_on','bel_on','cb_on') then
        greatest(0,
          oyun.aday_ucreti(null,s.tur,p.il_id)
          - round(oyun.aday_ucreti(null,s.tur,p.il_id)*oyun.duz('aday_destek')/100)
        )
    end,
    'oy_verdim',exists(
      select 1 from oyun.oylar o where o.secim_id=s.id and o.secmen=p.id
    ),
    'oy_engeli',oyun.oy_engeli(p,s),
    'katilim',case
      when s.durum<>'bekliyor' or t>=s.oy_bas
      then (select count(*) from oyun.oylar o where o.secim_id=s.id)
    end
  )
$$;

create or replace function public.secim_detay(p_secim bigint)
returns jsonb
language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
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
    ),'{}'::jsonb) end
  );
end $$;

create or replace function public.oy_ver(p_secim bigint,p_hedef bigint)
returns jsonb
language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  s oyun.secimler;
  a oyun.adaylar;
  e text;
  onsecim bigint;
begin
  select * into s from oyun.secimler where id=p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  if s.durum<>'bekliyor' or t<s.oy_bas or t>=s.oy_bit then
    raise exception 'Sandık şu anda kapalı (oy saatleri 08:00–17:00).';
  end if;
  e:=oyun.oy_engeli(p,s);
  if e is not null then raise exception '%',e; end if;
  if exists(select 1 from oyun.oylar where secim_id=s.id and secmen=p.id) then
    raise exception 'Bu seçimde zaten oy kullandın.';
  end if;

  if s.tur='mv' then
    if p_hedef<0 then
      select * into a
      from oyun.adaylar
      where id=-p_hedef
        and secim_id=s.id
        and parti_id is null
        and il_id=p.il_id;
      if a.id is null then raise exception 'Bağımsız aday bulunamadı.'; end if;
      insert into oyun.oylar(secim_id,secmen,il_id,parti_id,aday_id,zaman)
      values(s.id,p.id,p.il_id,null,a.id,t);
    else
      select id into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;
      if not exists(
        select 1 from oyun.adaylar
        where secim_id=onsecim and il_id=p.il_id
          and parti_id=p_hedef and sira is not null
      ) then
        raise exception 'Bu partinin ilinde aday listesi yok.';
      end if;
      insert into oyun.oylar(secim_id,secmen,il_id,parti_id,zaman)
      values(s.id,p.id,p.il_id,p_hedef,t);
    end if;
  else
    select * into a from oyun.adaylar where id=p_hedef and secim_id=s.id;
    if a.id is null then raise exception 'Aday bulunamadı.'; end if;
    if s.tur in ('mv_on','bel_on')
       and (a.il_id<>p.il_id or a.parti_id<>p.parti_id) then
      raise exception 'Ön seçimde yalnızca kendi ilindeki kendi partinin adaylarına oy verebilirsin.';
    end if;
    if s.tur in ('kurultay','cb_on') and a.parti_id<>p.parti_id then
      raise exception 'Yalnızca kendi partinin seçiminde oy kullanabilirsin.';
    end if;
    if s.tur='bel' and a.il_id<>p.il_id then
      raise exception 'Yalnızca kendi ilinin belediye seçiminde oy kullanabilirsin.';
    end if;
    insert into oyun.oylar(secim_id,secmen,il_id,parti_id,aday_id,zaman)
    values(s.id,p.id,p.il_id,a.parti_id,a.id,t);
  end if;
  return public.durum();
end $$;

create or replace function oyun._sonuc_mv(s oyun.secimler)
returns jsonb
language plpgsql set search_path='' as $$
declare
  baraj numeric:=(select baraj from oyun.ayarlar where id=1);
  onsecim oyun.secimler;
  toplam bigint;
  il record;
  l record;
  k int;
  ana bigint;
  iller_j jsonb:='{}'::jsonb;
  ilj jsonb;
  bos int:=0;
  dolu int:=0;
  sandalye_top int;
  bag_oy bigint;
  bag_sandalye int;
begin
  select * into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;
  select count(*) into toplam from oyun.oylar where secim_id=s.id;
  sandalye_top:=coalesce((select sum(mv_secim) from oyun.iller),600);

  create temp table if not exists _b23_ulusal(
    parti_id bigint primary key,
    oy bigint,
    yuzde numeric,
    gecti boolean,
    sandalye int default 0
  ) on commit drop;
  delete from _b23_ulusal;

  insert into _b23_ulusal(parti_id,oy)
  select parti_id,count(*)
  from oyun.oylar
  where secim_id=s.id and parti_id is not null
  group by parti_id;

  update _b23_ulusal
  set yuzde=case when toplam>0 then round(oy*100.0/toplam,2) else 0 end;

  update _b23_ulusal u
  set gecti=(u.yuzde>=baraj) or coalesce((
    select sum(u2.oy)*100.0/nullif(toplam,0)>=baraj
    from oyun.ittifak_uyeler iu
    join oyun.ittifak_uyeler iu2 on iu2.ittifak_id=iu.ittifak_id
    join _b23_ulusal u2 on u2.parti_id=iu2.parti_id
    where iu.parti_id=u.parti_id
  ),false);

  create temp table if not exists _b23_kaz(
    user_id uuid,
    il_id smallint,
    parti_id bigint,
    aday_id bigint
  ) on commit drop;
  delete from _b23_kaz;

  create temp table if not exists _b23_liste(
    anahtar bigint primary key,
    parti_id bigint,
    aday_id bigint,
    oy bigint,
    lim int,
    kaz int default 0
  ) on commit drop;

  for il in select * from oyun.iller order by id loop
    delete from _b23_liste;

    insert into _b23_liste(anahtar,parti_id,aday_id,oy,lim)
    select x.parti_id,x.parti_id,null,x.oy,x.lim
    from (
      select o.parti_id,
             count(*)::bigint oy,
             (select count(*)
              from oyun.adaylar a
              where a.secim_id=onsecim.id
                and a.il_id=il.id
                and a.parti_id=o.parti_id
                and a.sira is not null)::int lim
      from oyun.oylar o
      join _b23_ulusal u on u.parti_id=o.parti_id and u.gecti
      where o.secim_id=s.id and o.il_id=il.id and o.parti_id is not null
      group by o.parti_id
    ) x
    where x.lim>0 and x.oy>0;

    insert into _b23_liste(anahtar,parti_id,aday_id,oy,lim)
    select -a.id,null,a.id,count(o.*)::bigint,1
    from oyun.adaylar a
    join oyun.oylar o
      on o.secim_id=s.id and o.aday_id=a.id
    where a.secim_id=s.id
      and a.parti_id is null
      and a.il_id=il.id
    group by a.id
    having count(o.*)>0;

    for k in 1..coalesce(il.mv_secim,il.mv) loop
      ana:=null;
      select anahtar into ana
      from _b23_liste
      where kaz<lim and oy>0
      order by oy::numeric/(kaz+1) desc,oy desc,anahtar
      limit 1;
      exit when ana is null;
      update _b23_liste set kaz=kaz+1 where anahtar=ana;
    end loop;

    for l in select * from _b23_liste where parti_id is not null and kaz>0 loop
      insert into _b23_kaz(user_id,il_id,parti_id,aday_id)
      select a.user_id,il.id,l.parti_id,a.id
      from oyun.adaylar a
      where a.secim_id=onsecim.id
        and a.il_id=il.id
        and a.parti_id=l.parti_id
        and a.sira is not null
      order by a.sira
      limit l.kaz;

      update _b23_ulusal set sandalye=sandalye+l.kaz where parti_id=l.parti_id;
    end loop;

    insert into _b23_kaz(user_id,il_id,parti_id,aday_id)
    select a.user_id,il.id,null,a.id
    from _b23_liste l
    join oyun.adaylar a on a.id=l.aday_id
    where l.parti_id is null and l.kaz>0;

    select jsonb_build_object(
      'gecerli',(select count(*) from oyun.oylar where secim_id=s.id and il_id=il.id),
      'partiler',coalesce((
        select jsonb_object_agg(o.parti_id::text,jsonb_build_object(
          'oy',o.n,
          'sandalye',(select count(*) from _b23_kaz z where z.il_id=il.id and z.parti_id=o.parti_id)
        ))
        from (
          select parti_id,count(*) n
          from oyun.oylar
          where secim_id=s.id and il_id=il.id and parti_id is not null
          group by parti_id
        ) o
      ),'{}'::jsonb),
      'bagimsizlar',coalesce((
        select jsonb_agg(jsonb_build_object(
          'aday_id',a.id,
          'kad',pr.kad,
          'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
          'sandalye',case when exists(select 1 from _b23_kaz z where z.aday_id=a.id) then 1 else 0 end
        ) order by (select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id) desc,a.id)
        from oyun.adaylar a
        join oyun.profiller pr on pr.id=a.user_id
        where a.secim_id=s.id and a.parti_id is null and a.il_id=il.id
      ),'[]'::jsonb),
      'secilen',coalesce((
        select jsonb_agg(jsonb_build_object(
          'kad',pr.kad,
          'parti_id',z.parti_id,
          'bagimsiz',z.parti_id is null
        ) order by z.parti_id nulls last,pr.kad)
        from _b23_kaz z
        join oyun.profiller pr on pr.id=z.user_id
        where z.il_id=il.id
      ),'[]'::jsonb),
      'mv',coalesce(il.mv_secim,il.mv)
    ) into ilj;

    if (ilj->>'gecerli')::int>0 or jsonb_array_length(ilj->'secilen')>0 then
      iller_j:=iller_j||jsonb_build_object(il.id::text,ilj);
    end if;
  end loop;

  insert into oyun.kazananlar(secim_id,user_id,il_id,parti_id)
  select s.id,user_id,il_id,parti_id from _b23_kaz
  on conflict do nothing;

  select count(*) into dolu from _b23_kaz;
  bos:=sandalye_top-dolu;
  select count(*) into bag_oy
  from oyun.oylar where secim_id=s.id and parti_id is null and aday_id is not null;
  select count(*) into bag_sandalye
  from _b23_kaz where parti_id is null;

  perform oyun.olay(
    'secim',
    format('Genel seçim sonuçlandı: %s oy kullanıldı, %s sandalye doldu, %s sandalye boş kaldı.',toplam,dolu,bos),
    null,null,s.sonuc_at
  );

  return jsonb_build_object(
    'toplam',toplam,
    'baraj',baraj,
    'sandalye_toplam',sandalye_top,
    'dolu',dolu,
    'bos',bos,
    'bagimsiz_oy',bag_oy,
    'bagimsiz_sandalye',bag_sandalye,
    'bagimsizlar',coalesce((
      select jsonb_agg(jsonb_build_object(
        'aday_id',a.id,
        'kad',pr.kad,
        'il_id',a.il_id,
        'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
        'sandalye',case when exists(select 1 from _b23_kaz z where z.aday_id=a.id) then 1 else 0 end
      ) order by (select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id) desc,a.id)
      from oyun.adaylar a
      join oyun.profiller pr on pr.id=a.user_id
      where a.secim_id=s.id and a.parti_id is null
    ),'[]'::jsonb),
    'ulusal',coalesce((
      select jsonb_agg(jsonb_build_object(
        'parti_id',u.parti_id,
        'kisa',p.kisa,
        'ad',p.ad,
        'renk',p.renk,
        'oy',u.oy,
        'yuzde',u.yuzde,
        'gecti',u.gecti,
        'sandalye',u.sandalye
      ) order by u.oy desc)
      from _b23_ulusal u
      join oyun.partiler p on p.id=u.parti_id
    ),'[]'::jsonb),
    'iller',iller_j
  );
end $$;

create or replace function public.harita()
returns jsonb
language sql security definer
set search_path='oyun','public','pg_temp' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,
    'ad',i.ad,
    'mv',i.mv,
    'oyuncu',(select count(*) from oyun.profiller pr where pr.il_id=i.id),
    'gelisim',(select round(gelisim,1) from oyun.il_durum d where d.il_id=i.id),
    'bel',(select jsonb_build_object('kad',oyun.kad(m.user_id),'parti',oyun.parti_json(m.parti_id))
           from oyun.makamlar m where m.tur='bel' and m.il_id=i.id and m.bit is null limit 1),
    'vekil',(
      select coalesce(jsonb_agg(jsonb_build_object(
        'parti_id',x.parti_id,
        'renk',coalesce(pa.renk,'#8e8e93'),
        'kisa',coalesce(pa.kisa,'Bağımsız'),
        'n',x.n
      ) order by x.n desc),'[]'::jsonb)
      from (
        select parti_id,count(*) n
        from oyun.makamlar m
        where m.tur='mv' and m.il_id=i.id and m.bit is null
        group by parti_id
      ) x
      left join oyun.partiler pa on pa.id=x.parti_id
    )
  ) order by i.id),'[]'::jsonb)
  from oyun.iller i
$$;

create or replace function public.meclis()
returns jsonb
language sql security definer
set search_path='oyun','public','pg_temp' as $$
  select jsonb_build_object(
    'toplam',coalesce((select deger::int from oyun.anayasa where kod='milletvekili_sayisi'),600),
    'dolu',(select count(*) from oyun.makamlar where tur='mv' and bit is null),
    'bagimsiz',(select count(*) from oyun.makamlar where tur='mv' and bit is null and parti_id is null),
    'partiler',coalesce((
      select jsonb_agg(oyun.parti_json(x.parti_id)||jsonb_build_object('n',x.n) order by x.n desc)
      from (
        select parti_id,count(*) n
        from oyun.makamlar
        where tur='mv' and bit is null and parti_id is not null
        group by parti_id
      ) x
    ),'[]'::jsonb),
    'vekiller',coalesce((
      select jsonb_agg(jsonb_build_object(
        'kad',oyun.kad(m.user_id),
        'il',i.ad,
        'parti_id',m.parti_id,
        'bagimsiz',m.parti_id is null
      ) order by i.ad,m.parti_id nulls last)
      from oyun.makamlar m
      join oyun.iller i on i.id=m.il_id
      where m.tur='mv' and m.bit is null
    ),'[]'::jsonb)
  )
$$;

revoke all on function public.bagimsiz_aday_ol(bigint) from public,anon;
grant execute on function public.bagimsiz_aday_ol(bigint) to authenticated;
revoke all on function public.bagimsiz_adaylik_geri_cek(bigint) from public,anon;
grant execute on function public.bagimsiz_adaylik_geri_cek(bigint) to authenticated;
