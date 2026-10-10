-- =====================================================================
--  54 · İTTİFAK TEKLİFİ VE İTTİFAK İÇİ ORTAK ADAY
--
--  1) Doğrudan ittifak teklifi
--     Genel başkan başka bir partinin sayfasından "İttifak teklif et" der.
--     Partisi bir ittifakta değilse ittifak (verdiği adla) kurulur ve teklif gider; ittifaktaysa davet gider.
--     Karşı partinin genel başkanı kabul ya da reddeder (07'deki ittifak_davet_yanit).
--
--  2) Ortak aday teklifi (ittifak ortakları arasında)
--     İttifaktaki bir partinin genel başkanı, ortak aday önerir:
--       • Cumhurbaşkanlığı: "X partisinin adayı ittifakın ortak adayı olsun"
--       • Belediye (il il): "<il>'de X partisinin adayı ittifakın ortak adayı olsun"
--     Öneren parti adayı çıkaran parti değilse kendi adayını o anda çeker ve destek verir.
--     Diğer ortaklar kabul edince kendi adayları çekilir, ortak adayı desteklerler (cb_destek / bel_aday_destek).
--     Reddeden ortak kendi adayıyla yarışmaya devam eder. Tüm ortaklar kabul edince "ittifakın ortak adayı" ilan edilir.
--     Zamanlama mevcut kurallara bağlıdır: CB kararı ayın 19-25'i, belediye ön seçim sonucundan oy verme başlayana kadar.
--  Oyuncu verisi değişmez; yalnız tablo ve fonksiyon eklenir.
-- =====================================================================

create table if not exists oyun.ittifak_ortak_teklif(
  id           bigint generated always as identity primary key,
  ittifak_id   bigint not null references oyun.ittifaklar(id) on delete cascade,
  tur          text not null check (tur in ('cb','bel')),
  secim_id     bigint not null references oyun.secimler(id) on delete cascade,
  il_id        smallint references oyun.iller(id),
  aday_parti   bigint not null references oyun.partiler(id) on delete cascade,
  aday_id      bigint references oyun.adaylar(id) on delete set null,
  teklif_eden  bigint not null references oyun.partiler(id) on delete cascade,
  zaman        timestamptz not null default now(),
  durum        text not null default 'bekliyor' check (durum in ('bekliyor','kabul','iptal'))
);
create index if not exists ittifak_ortak_teklif_i on oyun.ittifak_ortak_teklif(ittifak_id, durum);
create table if not exists oyun.ittifak_ortak_yanit(
  teklif_id bigint not null references oyun.ittifak_ortak_teklif(id) on delete cascade,
  parti_id  bigint not null references oyun.partiler(id) on delete cascade,
  kabul     boolean not null,
  zaman     timestamptz not null default now(),
  primary key (teklif_id, parti_id)
);
do $$ declare t text; begin
  foreach t in array array['ittifak_ortak_teklif','ittifak_ortak_yanit'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
    if to_regproc('oyun.bosaltma_korumasi') is not null then
      execute format('drop trigger if exists bosaltma_korumasi on oyun.%I', t);
      execute format('create trigger bosaltma_korumasi before truncate on oyun.%I for each statement execute function oyun.bosaltma_korumasi()', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 1) Doğrudan teklif
-- ---------------------------------------------------------------------
create or replace function public.ittifak_teklif(p_parti bigint, p_ad text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; hedef oyun.partiler;
begin
  pa := oyun.gb_partim(p);
  select * into hedef from oyun.partiler where id = p_parti and not kapali;
  if hedef.id is null or hedef.id = pa.id then raise exception 'Geçersiz parti.'; end if;
  if exists (select 1 from oyun.ittifak_uyeler a join oyun.ittifak_uyeler b on a.ittifak_id = b.ittifak_id
             where a.parti_id = pa.id and b.parti_id = hedef.id) then
    raise exception '% ile zaten aynı ittifaktasınız.', hedef.kisa;
  end if;
  if exists (select 1 from oyun.ittifak_uyeler where parti_id = hedef.id) then
    raise exception '% başka bir ittifakta (%). Önce o ittifaktan ayrılması gerekir.', hedef.kisa,
      (select i.ad from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = hedef.id);
  end if;
  if not exists (select 1 from oyun.ittifak_uyeler where parti_id = pa.id) then
    if coalesce(btrim(p_ad), '') = '' then raise exception 'Partin henüz bir ittifakta değil; kurulacak ittifaka bir ad ver.'; end if;
    perform public.ittifak_kur(p_ad);
  end if;
  perform public.ittifak_davet(hedef.id);
  return public.ittifak_bilgi(hedef.id);
end $$;

-- ---------------------------------------------------------------------
-- 2) Ortak aday
-- ---------------------------------------------------------------------
-- Bir partinin ittifak adına ortak adayı desteklemesi (kendi adayı çekilir)
create or replace function oyun.ortak_aday_uygula(o oyun.ittifak_ortak_teklif) returns void
language plpgsql set search_path = oyun, public, pg_temp as $$
begin
  if o.tur = 'cb' then perform public.cb_destek(o.aday_parti);
  else perform public.bel_aday_destek(o.il_id, o.aday_parti);
  end if;
end $$;

create or replace function oyun.ortak_teklif_json(o oyun.ittifak_ortak_teklif, benim bigint) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', o.id, 'tur', o.tur, 'il', (select ad from oyun.iller where id = o.il_id), 'il_id', o.il_id,
    'aday_parti', oyun.parti_json(o.aday_parti), 'aday', (select oyun.kad(a.user_id) from oyun.adaylar a where a.id = o.aday_id),
    'teklif_eden', oyun.parti_json(o.teklif_eden), 'zaman', o.zaman, 'durum', o.durum,
    'yanitlar', coalesce((select jsonb_agg(jsonb_build_object('parti', (select kisa from oyun.partiler where id = y.parti_id), 'kabul', y.kabul))
                          from oyun.ittifak_ortak_yanit y where y.teklif_id = o.id), '[]'::jsonb),
    'bekleyenler', coalesce((select jsonb_agg(pa.kisa) from oyun.ittifak_uyeler u join oyun.partiler pa on pa.id = u.parti_id
                             where u.ittifak_id = o.ittifak_id and u.parti_id <> o.aday_parti
                               and not exists (select 1 from oyun.ittifak_ortak_yanit y where y.teklif_id = o.id and y.parti_id = u.parti_id)), '[]'::jsonb),
    'yanit_bekliyor_benden', o.durum = 'bekliyor' and benim is not null and benim <> o.aday_parti
       and exists (select 1 from oyun.ittifak_uyeler u where u.ittifak_id = o.ittifak_id and u.parti_id = benim)
       and not exists (select 1 from oyun.ittifak_ortak_yanit y where y.teklif_id = o.id and y.parti_id = benim))
$$;

-- Tüm ortaklar kabul ettiyse ortak aday ilan edilir
create or replace function oyun.ortak_teklif_kontrol(p_id bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare o oyun.ittifak_ortak_teklif; iad text; ne text;
begin
  select * into o from oyun.ittifak_ortak_teklif where id = p_id;
  if o.durum <> 'bekliyor' then return; end if;
  if exists (select 1 from oyun.ittifak_uyeler u where u.ittifak_id = o.ittifak_id and u.parti_id <> o.aday_parti
             and not exists (select 1 from oyun.ittifak_ortak_yanit y where y.teklif_id = o.id and y.parti_id = u.parti_id and y.kabul)) then
    return;
  end if;
  update oyun.ittifak_ortak_teklif set durum = 'kabul' where id = o.id;
  select ad into iad from oyun.ittifaklar where id = o.ittifak_id;
  ne := case o.tur when 'cb' then 'cumhurbaşkanı' else (select ad from oyun.iller where id = o.il_id) || ' belediye başkanı' end;
  perform oyun.olay('ittifak', format('%s, %s ortak adayını açıkladı: %s (%s).', iad, ne,
    (select oyun.kad(a.user_id) from oyun.adaylar a where a.id = o.aday_id), (select kisa from oyun.partiler where id = o.aday_parti)),
    o.il_id, o.aday_parti, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.gb, t, format('%s ittifakının %s ortak adayı kesinleşti.', iad, ne)
    from oyun.ittifak_uyeler u join oyun.partiler x on x.id = u.parti_id where u.ittifak_id = o.ittifak_id and x.gb is not null;
end $$;

create or replace function public.ittifak_ortak_aday_teklif(p_tur text, p_il int, p_aday_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; iid bigint; s oyun.secimler;
        a oyun.adaylar; o oyun.ittifak_ortak_teklif; ne text; ilad text;
begin
  pa := oyun.gb_partim(p);
  select ittifak_id into iid from oyun.ittifak_uyeler where parti_id = pa.id;
  if iid is null then raise exception 'Ortak aday önermek için partin bir ittifakta olmalı.'; end if;
  if not exists (select 1 from oyun.ittifak_uyeler where ittifak_id = iid and parti_id = p_aday_parti) then
    raise exception 'Ortak aday yalnız ittifaktaki bir partinin adayı olabilir.';
  end if;
  if (select count(*) from oyun.ittifak_uyeler where ittifak_id = iid) < 2 then raise exception 'İttifakta henüz ortağın yok.'; end if;
  if p_tur = 'cb' then
    select * into s from oyun.secimler where tur = 'cb' and t >= basvuru_bas and t < basvuru_bit order by ara desc, basvuru_bit limit 1;
    if s.id is null then raise exception 'Cumhurbaşkanı ortak adayı, aday belirleme döneminde (ayın 19-25''i) önerilebilir.'; end if;
    select * into a from oyun.adaylar where secim_id = s.id and parti_id = p_aday_parti order by basvuru_at, id limit 1;
    if a.id is null then raise exception '% henüz cumhurbaşkanı adayını açıklamadı.', (select kisa from oyun.partiler where id = p_aday_parti); end if;
    p_il := null; ne := 'cumhurbaşkanı';
  elsif p_tur = 'bel' then
    select ad into ilad from oyun.iller where id = p_il;
    if ilad is null then raise exception 'Geçersiz il.'; end if;
    select * into s from oyun.secimler where tur = 'bel' and durum = 'bekliyor' and oy_bas > t and (not ara or hedef_il_id = p_il)
      order by ara desc, oy_bas limit 1;
    if s.id is null then raise exception 'Belediye seçiminde ortak aday için uygun dönem yok (oy verme başlamadan önce olmalı).'; end if;
    select * into a from oyun.adaylar where secim_id = s.id and il_id = p_il and parti_id = p_aday_parti order by basvuru_at, id limit 1;
    if a.id is null then raise exception '% partisinin % ilinde kesinleşmiş belediye başkanı adayı yok (ön seçim sonucundan sonra önerilebilir).',
      (select kisa from oyun.partiler where id = p_aday_parti), ilad; end if;
    ne := ilad || ' belediye başkanı';
  else
    raise exception 'Ortak aday türü cb ya da bel olmalı.';
  end if;
  if exists (select 1 from oyun.ittifak_ortak_teklif where ittifak_id = iid and secim_id = s.id and il_id is not distinct from p_il and durum in ('bekliyor','kabul')) then
    raise exception 'Bu seçim için ittifakta zaten bir ortak aday önerisi var.';
  end if;
  insert into oyun.ittifak_ortak_teklif(ittifak_id, tur, secim_id, il_id, aday_parti, aday_id, teklif_eden, zaman)
    values (iid, p_tur, s.id, p_il, p_aday_parti, a.id, pa.id, t) returning * into o;
  -- Öneren parti adayı çıkaran değilse kendi adayını çeker, desteği o anda verir
  if pa.id <> p_aday_parti then
    perform oyun.ortak_aday_uygula(o);
    insert into oyun.ittifak_ortak_yanit(teklif_id, parti_id, kabul, zaman) values (o.id, pa.id, true, t);
  end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.gb, t, format('%s, ittifakın %s ortak adayı olarak %s (%s) önerdi. Parti sayfasındaki İttifak kartından yanıtla.', pa.kisa, ne, oyun.kad(a.user_id),
      (select kisa from oyun.partiler where id = p_aday_parti))
    from oyun.ittifak_uyeler u join oyun.partiler x on x.id = u.parti_id
    where u.ittifak_id = iid and x.id <> pa.id and x.gb is not null;
  perform oyun.ortak_teklif_kontrol(o.id, t);
  return public.ittifak_masasi(pa.id);
end $$;

create or replace function public.ittifak_ortak_aday_yanit(p_teklif bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; o oyun.ittifak_ortak_teklif;
begin
  pa := oyun.gb_partim(p);
  select * into o from oyun.ittifak_ortak_teklif where id = p_teklif for update;
  if o.id is null or o.durum <> 'bekliyor' then raise exception 'Bu öneri artık yanıt beklemiyor.'; end if;
  if not exists (select 1 from oyun.ittifak_uyeler where ittifak_id = o.ittifak_id and parti_id = pa.id) then raise exception 'Bu öneri senin ittifakına ait değil.'; end if;
  if pa.id = o.aday_parti then raise exception 'Adayı önerilen parti olarak yanıt vermen gerekmiyor.'; end if;
  if exists (select 1 from oyun.ittifak_ortak_yanit where teklif_id = o.id and parti_id = pa.id) then raise exception 'Bu öneriye zaten yanıt verdin.'; end if;
  if p_kabul then perform oyun.ortak_aday_uygula(o); end if;
  insert into oyun.ittifak_ortak_yanit(teklif_id, parti_id, kabul, zaman) values (o.id, pa.id, p_kabul, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.gb, t, format('%s, ortak aday önerisini %s.', pa.kisa, case when p_kabul then 'kabul etti' else 'reddetti; kendi adayıyla yarışacak' end)
    from oyun.ittifak_uyeler u join oyun.partiler x on x.id = u.parti_id where u.ittifak_id = o.ittifak_id and x.id <> pa.id and x.gb is not null;
  perform oyun.ortak_teklif_kontrol(o.id, t);
  return public.ittifak_masasi(pa.id);
end $$;

-- Öneren parti bekleyen önerisini geri çeker (kabul eden ortakların desteği yerinde kalır; geri almak için mevcut "geri çek" kullanılır)
create or replace function public.ittifak_ortak_aday_iptal(p_teklif bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler;
begin
  pa := oyun.gb_partim(p);
  update oyun.ittifak_ortak_teklif set durum = 'iptal' where id = p_teklif and teklif_eden = pa.id and durum = 'bekliyor';
  if not found then raise exception 'Geri çekilecek bekleyen bir önerin yok.'; end if;
  return public.ittifak_masasi(pa.id);
end $$;

-- İttifak masası: öneriler, ortak adaylar, önerilebilecek adaylar
create or replace function public.ittifak_masasi(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); iid bigint; cbs oyun.secimler; bels oyun.secimler; benim bigint;
begin
  select ittifak_id into iid from oyun.ittifak_uyeler where parti_id = p_parti;
  if iid is null then return jsonb_build_object('ittifak', null); end if;
  benim := case when exists (select 1 from oyun.partiler where id = p.parti_id and gb = p.id) then p.parti_id end;
  select * into cbs from oyun.secimler where tur = 'cb' and t >= basvuru_bas and t < basvuru_bit order by ara desc, basvuru_bit limit 1;
  select * into bels from oyun.secimler where tur = 'bel' and durum = 'bekliyor' and oy_bas > t order by ara desc, oy_bas limit 1;
  return jsonb_build_object(
    'ittifak', iid,
    'uyem', exists (select 1 from oyun.ittifak_uyeler where ittifak_id = iid and parti_id = p.parti_id),
    'gb', benim is not null and exists (select 1 from oyun.ittifak_uyeler where ittifak_id = iid and parti_id = benim),
    'oneriler', coalesce((select jsonb_agg(oyun.ortak_teklif_json(o, benim) order by o.durum = 'bekliyor' desc, o.zaman desc)
                          from oyun.ittifak_ortak_teklif o where o.ittifak_id = iid and o.durum <> 'iptal'
                            and exists (select 1 from oyun.secimler s where s.id = o.secim_id and s.durum = 'bekliyor')), '[]'::jsonb),
    'cb_acik', cbs.id is not null,
    'cb_adaylar', case when cbs.id is null then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('parti_id', a.parti_id,
        'parti', (select kisa from oyun.partiler where id = a.parti_id), 'kad', oyun.kad(a.user_id)))
        from oyun.adaylar a join oyun.ittifak_uyeler u on u.parti_id = a.parti_id and u.ittifak_id = iid where a.secim_id = cbs.id), '[]'::jsonb) end,
    'bel_acik', bels.id is not null,
    'bel_adaylar', case when bels.id is null then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('il_id', a.il_id, 'il', i.ad,
        'parti_id', a.parti_id, 'parti', (select kisa from oyun.partiler where id = a.parti_id), 'kad', oyun.kad(a.user_id)) order by i.ad)
        from oyun.adaylar a join oyun.ittifak_uyeler u on u.parti_id = a.parti_id and u.ittifak_id = iid join oyun.iller i on i.id = a.il_id
        where a.secim_id = bels.id), '[]'::jsonb) end
  );
end $$;

-- Ortaklıktan ayrılan partinin bekleyen önerileri düşer
create or replace function oyun.ortak_teklif_temizle() returns trigger language plpgsql set search_path = '' as $$
begin
  update oyun.ittifak_ortak_teklif set durum = 'iptal'
   where durum = 'bekliyor' and ittifak_id = old.ittifak_id and (teklif_eden = old.parti_id or aday_parti = old.parti_id);
  return old;
end $$;
drop trigger if exists ortak_teklif_temizle on oyun.ittifak_uyeler;
create trigger ortak_teklif_temizle after delete on oyun.ittifak_uyeler for each row execute function oyun.ortak_teklif_temizle();

revoke all on function public.ittifak_teklif(bigint, text), public.ittifak_ortak_aday_teklif(text, int, bigint),
  public.ittifak_ortak_aday_yanit(bigint, boolean), public.ittifak_ortak_aday_iptal(bigint), public.ittifak_masasi(bigint) from public, anon;
grant execute on function public.ittifak_teklif(bigint, text), public.ittifak_ortak_aday_teklif(text, int, bigint),
  public.ittifak_ortak_aday_yanit(bigint, boolean), public.ittifak_ortak_aday_iptal(bigint), public.ittifak_masasi(bigint) to authenticated;
revoke all on function oyun.ortak_aday_uygula(oyun.ittifak_ortak_teklif), oyun.ortak_teklif_kontrol(bigint, timestamptz) from public, anon, authenticated;
