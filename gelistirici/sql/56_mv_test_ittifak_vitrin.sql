-- Geçici MV test modu + gerçek %7 baraj altyapısı + herkese açık ittifak listesi.
-- Oyuncu, oy, makam, para veya mevcut ittifak verisi değiştirilmez.
begin;

create table if not exists oyun.mv_secim_modu(
  id int primary key check (id=1),
  her_aday_vekil boolean not null default true,
  aciklama text not null default 'Test: bütün kesinleşmiş adaylar seçilir; normalde tek parti/ittifak barajı %7.'
);
insert into oyun.mv_secim_modu(id,her_aday_vekil)
values (1,true) on conflict(id) do nothing;
alter table oyun.mv_secim_modu enable row level security;
revoke all on oyun.mv_secim_modu from public, anon, authenticated;
do $$ begin
  if to_regproc('oyun.bosaltma_korumasi') is not null then
    drop trigger if exists bosaltma_korumasi on oyun.mv_secim_modu;
    create trigger bosaltma_korumasi before truncate on oyun.mv_secim_modu
      for each statement execute function oyun.bosaltma_korumasi();
  end if;
end $$;

-- Düşük oyuncu sayılı testte bütün kesinleşmiş parti ve bağımsız MV adaylarını seç.
-- Testte il kontenjanı gerekirse aşılabilir; bu yalnız deneme moduna özgüdür.
create or replace function oyun._sonuc_mv_test(s oyun.secimler)
returns jsonb language plpgsql set search_path = '' as $$
declare 
  onsecim oyun.secimler;
  toplam bigint;
  sandalye_top int;
  dolu int;
  bos int;
  bag_oy bigint;
  bag_sandalye int;
  iller_j jsonb := '{}'::jsonb;
  ilj jsonb;
  il record;
  gercek_baraj numeric := (select baraj from oyun.ayarlar where id=1);
begin
  select * into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;
  if onsecim.id is null then
    raise exception 'Milletvekili önseçimi bulunamadı.';
  end if;
  select count(*) into toplam from oyun.oylar where secim_id=s.id;
  sandalye_top := coalesce((select sum(mv_secim) from oyun.iller),600);

  create temp table if not exists _test_mv_kaz(
    user_id uuid primary key, il_id smallint, parti_id bigint, aday_id bigint
  ) on commit drop;
  delete from _test_mv_kaz;

  -- Parti listesinde önseçim sonucuyla kesinleşmiş adayların tamamı.
  insert into _test_mv_kaz(user_id,il_id,parti_id,aday_id)
  select distinct on (a.user_id) a.user_id,a.il_id,a.parti_id,a.id
  from oyun.adaylar a
  where a.secim_id=onsecim.id and a.parti_id is not null and a.sira is not null
  order by a.user_id,a.sira,a.id;

  -- Doğrudan genel seçimde aday olan bağımsız adayların tamamı.
  insert into _test_mv_kaz(user_id,il_id,parti_id,aday_id)
  select distinct on (a.user_id) a.user_id,a.il_id,null::bigint,a.id
  from oyun.adaylar a
  where a.secim_id=s.id and a.parti_id is null
    and not exists (select 1 from _test_mv_kaz x where x.user_id=a.user_id)
  order by a.user_id,a.id
  on conflict(user_id) do nothing;

  for il in select * from oyun.iller order by id loop
    select jsonb_build_object(
      'gecerli',(select count(*) from oyun.oylar where secim_id=s.id and il_id=il.id),
      'partiler',coalesce((
        select jsonb_object_agg(v.parti_id::text,jsonb_build_object(
          'oy',v.oy,'sandalye',(select count(*) from _test_mv_kaz z where z.il_id=il.id and z.parti_id=v.parti_id)))
        from (
          select x.parti_id,(select count(*) from oyun.oylar o where o.secim_id=s.id and o.il_id=il.id and o.parti_id=x.parti_id) oy
          from (
            select parti_id from oyun.oylar where secim_id=s.id and il_id=il.id and parti_id is not null
            union
            select parti_id from _test_mv_kaz where il_id=il.id and parti_id is not null
          ) x
        ) v
      ),'{}'::jsonb),
      'bagimsizlar',coalesce((
        select jsonb_agg(jsonb_build_object(
          'aday_id',a.id,'kad',pr.kad,
          'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
          'sandalye',case when exists(select 1 from _test_mv_kaz z where z.aday_id=a.id) then 1 else 0 end
        ) order by a.id)
        from oyun.adaylar a join oyun.profiller pr on pr.id=a.user_id
        where a.secim_id=s.id and a.parti_id is null and a.il_id=il.id
      ),'[]'::jsonb),
      'secilen',coalesce((
        select jsonb_agg(jsonb_build_object(
          'kad',pr.kad,'parti_id',z.parti_id,'bagimsiz',z.parti_id is null
        ) order by z.parti_id nulls last,pr.kad)
        from _test_mv_kaz z join oyun.profiller pr on pr.id=z.user_id where z.il_id=il.id
      ),'[]'::jsonb),
      'mv',coalesce(il.mv_secim,il.mv)
    ) into ilj;
    if (ilj->>'gecerli')::int>0 or jsonb_array_length(ilj->'secilen')>0 then
      iller_j := iller_j || jsonb_build_object(il.id::text,ilj);
    end if;
  end loop;

  insert into oyun.kazananlar(secim_id,user_id,il_id,parti_id)
    select s.id,user_id,il_id,parti_id from _test_mv_kaz
    on conflict do nothing;

  select count(*) into dolu from _test_mv_kaz;
  bos := greatest(0,sandalye_top-dolu);
  select count(*) into bag_oy from oyun.oylar where secim_id=s.id and parti_id is null and aday_id is not null;
  select count(*) into bag_sandalye from _test_mv_kaz where parti_id is null;

  perform oyun.olay('secim',
    format('Test genel seçimi sonuçlandı: %s oy, %s aday milletvekili seçildi. Geçici baraj kaldırıldı.',toplam,dolu),
    null,null,s.sonuc_at);

  return jsonb_build_object(
    'toplam',toplam,'baraj',0,'gercek_baraj',gercek_baraj,'test_modu',true,
    'sandalye_toplam',greatest(sandalye_top,dolu),'dolu',dolu,'bos',bos,
    'test_kontenjan_asimi',greatest(0,dolu-sandalye_top),
    'bagimsiz_oy',bag_oy,'bagimsiz_sandalye',bag_sandalye,
    'bagimsizlar',coalesce((
      select jsonb_agg(jsonb_build_object(
        'aday_id',a.id,'kad',pr.kad,'il_id',a.il_id,
        'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
        'sandalye',case when exists (select 1 from _test_mv_kaz z where z.aday_id=a.id) then 1 else 0 end
      ) order by a.id)
      from oyun.adaylar a join oyun.profiller pr on pr.id=a.user_id
      where a.secim_id=s.id and a.parti_id is null
    ),'[]'::jsonb),
    'ulusal',coalesce((
      select jsonb_agg(jsonb_build_object(
        'parti_id',pa.id,'kisa',pa.kisa,'ad',pa.ad,'renk',pa.renk,
        'oy',coalesce(v.oy,0),
        'yuzde',case when toplam>0 then round(coalesce(v.oy,0)*100.0/toplam,2) else 0 end,
        'gecti',true,
        'sandalye',(select count(*) from _test_mv_kaz z where z.parti_id=pa.id)
      ) order by coalesce(v.oy,0) desc,pa.id)
      from oyun.partiler pa
      left join (select parti_id,count(*) as oy from oyun.oylar
                 where secim_id=s.id and parti_id is not null group by parti_id) v on v.parti_id=pa.id
      where v.parti_id is not null or exists(select 1 from _test_mv_kaz z where z.parti_id=pa.id)
    ),'[]'::jsonb),
    'iller',iller_j);
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
  -- Geçici düşük oyuncu sayısı test modu: her kesinleşmiş aday seçilir.
  if exists (select 1 from oyun.mv_secim_modu where id = 1 and her_aday_vekil) then
    return oyun._sonuc_mv_test(s);
  end if;
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
  set gecti=(coalesce(u.oy*100.0/nullif(toplam,0),0)>=baraj) or coalesce((
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

-- Herkes Partiler ekranında ittifak adını ve tüm üye partileri görebilir.
create or replace function public.partiler() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(oyun.parti_json(pa.id) || jsonb_build_object(
    'uye',(select count(*) from oyun.profiller where parti_id=pa.id),
    'gb',oyun.kad(pa.gb),'sistem',pa.sistem,'kurulus_bit',pa.kurulus_bit,
    'vekil',(select count(*) from oyun.makamlar m where m.tur='mv' and m.bit is null and m.parti_id=pa.id),
    'belediye',(select count(*) from oyun.makamlar m where m.tur='bel' and m.bit is null and m.parti_id=pa.id),
    'test_baraj_kapali',coalesce((select her_aday_vekil from oyun.mv_secim_modu where id=1),false),
    'ittifak',(select jsonb_build_object('id',i.id,'ad',i.ad,
      'uyeler',coalesce((select jsonb_agg(jsonb_build_object(
        'id',p2.id,'ad',p2.ad,'kisa',p2.kisa,'renk',p2.renk) order by p2.kisa,p2.id)
        from oyun.ittifak_uyeler u2 join oyun.partiler p2 on p2.id=u2.parti_id
        where u2.ittifak_id=i.id and not p2.kapali),'[]'::jsonb))
      from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id=u.ittifak_id
      where u.parti_id=pa.id)
  ) order by (select count(*) from oyun.profiller where parti_id=pa.id) desc,pa.id),'[]'::jsonb)
  from oyun.partiler pa where not pa.kapali
$$;

commit;
