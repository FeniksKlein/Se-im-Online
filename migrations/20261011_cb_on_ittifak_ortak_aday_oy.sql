-- 2026-10-11: Allow alliance members to vote for confirmed joint CB candidate in CB primary.
-- Also permits a party that explicitly pledged CB support to vote for that supported candidate.
-- Preserves existing candidate rows, votes, election times and all other elections.
BEGIN;

CREATE OR REPLACE FUNCTION oyun.cb_on_oy_hakki(p_parti bigint,p_donem text,p_aday_id bigint)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $izin$
  SELECT EXISTS (
    SELECT 1
    FROM oyun.adaylar a
    JOIN oyun.secimler s ON s.id=a.secim_id
    WHERE a.id=p_aday_id AND s.tur='cb_on' AND s.donem=p_donem
      AND p_parti IS NOT NULL AND a.parti_id IS NOT NULL
      AND (
        -- Own party's candidate always remains on the ballot.
        a.parti_id=p_parti
        -- Explicitly supported candidate, even if the joint-alliance offer is pending.
        OR EXISTS (
          SELECT 1 FROM oyun.cb_kararlar k
          WHERE k.donem=p_donem AND k.parti_id=p_parti
            AND k.yontem='destek' AND k.destek_parti=a.parti_id
        )
        -- Confirmed alliance's joint candidate, identified by user AND party, in this election.
        OR EXISTS (
          SELECT 1
          FROM oyun.ittifak_ortak_teklif ot
          JOIN oyun.secimler ana ON ana.id=ot.secim_id AND ana.tur='cb'
          JOIN oyun.adaylar kaynak ON kaynak.id=ot.aday_id
            AND kaynak.secim_id=ana.id AND kaynak.parti_id=ot.aday_parti
          JOIN oyun.ittifak_uyeler destekci ON destekci.ittifak_id=ot.ittifak_id
            AND destekci.parti_id=p_parti
          JOIN oyun.ittifak_uyeler sahibi ON sahibi.ittifak_id=ot.ittifak_id
            AND sahibi.parti_id=a.parti_id
          WHERE ot.tur='cb' AND ot.durum='kabul' AND ana.donem=p_donem
            AND ot.aday_parti=a.parti_id AND kaynak.user_id=a.user_id
        )
      )
  )
$izin$;

CREATE OR REPLACE FUNCTION oyun._secim_detay_ham(p_secim bigint)
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
      (s.tur='kurultay' and a.parti_id=p.parti_id) or
      (s.tur='cb_on' and oyun.cb_on_oy_hakki(p.parti_id,s.donem,a.id)) or
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
end $function$;

CREATE OR REPLACE FUNCTION public.oy_ver(p_secim bigint, p_hedef bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
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
    raise exception 'Sandık şu anda kapalı (oy saatleri 08:00–22:00).';
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
    if s.tur='kurultay' and a.parti_id is distinct from p.parti_id then
      raise exception 'Yalnızca kendi partinin seçiminde oy kullanabilirsin.';
    end if;
    if s.tur='cb_on' and not oyun.cb_on_oy_hakki(p.parti_id,s.donem,a.id) then
      raise exception 'Yalnızca kendi partinin seçiminde oy kullanabilirsin.';
    end if;
    if s.tur='bel' and a.il_id<>p.il_id then
      raise exception 'Yalnızca kendi ilinin belediye seçiminde oy kullanabilirsin.';
    end if;
    insert into oyun.oylar(secim_id,secmen,il_id,parti_id,aday_id,zaman)
    values(s.id,p.id,p.il_id,a.parti_id,a.id,t);
  end if;
  return public.durum();
end $function$;

NOTIFY pgrst, 'reload schema';
COMMIT;
