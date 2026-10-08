-- Ortak aday desteklerinin zincirlenmesini ve üçüncü kişilerin desteklediği adayın habersiz çekilmesini engelle.
CREATE OR REPLACE FUNCTION public.bel_aday_destek(p_il smallint, p_hedef_parti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 if exists(select 1 from oyun.bel_aday_destek d where d.secim_id=s.id and d.il_id=p_il and d.parti_id=p_hedef_parti)
 then raise exception 'Hedef partinin kendi adayı zaten çekildi; ortak aday olamaz';end if;
 if exists(select 1 from oyun.bel_aday_destek d where d.secim_id=s.id and d.il_id=p_il and d.hedef_parti_id=pa.id)
 then raise exception 'Senin partinin adayını başka partiler destekliyor; adayı çekemezsin';end if;
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
end $function$
;

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

  if exists(select 1 from oyun.cb_kararlar x
    where x.donem=s.donem and x.yontem='destek' and x.destek_parti=pa.id)
  then raise exception 'Diğer partiler senin adayını destekliyor; önce desteklerini değiştirmeliler';end if;
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
