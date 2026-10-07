-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 2) SEÇİM MOTORU
--  Takvim üretimi, sayım (D'Hondt + baraj), göreve başlatma, yedek vekil,
--  ve her dakika çalışan oyun.tick().
--  Tüm saatler Türkiye saatidir (Europe/Istanbul).
-- =====================================================================

-- Türkiye saatiyle belirli bir gün/saat
create or replace function oyun.tr_an(g date, saat int, dk int default 0)
returns timestamptz language sql stable as $$
  select make_timestamptz(extract(year from g)::int, extract(month from g)::int,
                          extract(day from g)::int, saat, dk, 0, 'Europe/Istanbul')
$$;

create or replace function oyun.oncelik(tur text) returns int language sql immutable as $$
  select case tur when 'mv_on' then 1 when 'cb_on' then 2 when 'bel_on' then 3 when 'kurultay' then 4
                  when 'mv' then 5 when 'bel' then 6 when 'cb' then 7 when 'cb2' then 8 else 9 end
$$;

create or replace function oyun.olay(p_tur text, p_metin text, p_il smallint default null, p_parti bigint default null, p_zaman timestamptz default null)
returns void language sql as $$
  insert into oyun.olaylar(zaman, tur, il_id, parti_id, metin)
  values (coalesce(p_zaman, oyun.simdi()), p_tur, p_il, p_parti, p_metin)
$$;

create or replace function oyun.bildir(p_user uuid, p_metin text, p_zaman timestamptz default null)
returns void language sql as $$
  insert into oyun.bildirimler(user_id, zaman, metin) values (p_user, coalesce(p_zaman, oyun.simdi()), p_metin)
$$;

-- ---------------------------------------------------------------------
-- Bir ayın tüm seçimlerini oluşturur (tekrar çağrılırsa bir şey yapmaz).
--   Ayın 6'sı   belediye aday adaylığı   · 8'i ön seçim · 10'u seçim · 11'i göreve başlama
--   15–17'si    genel başkanlık başvurusu · 18'i kurultay · 19'u göreve başlama
--   19–25'i     genel başkan CB adayı kararını verir
--   26'sı       vekil (ve gerekirse CB) aday adaylığı · 28'i ön seçimler
--   Ertesi ayın 1'i genel seçim + CB seçimi · 2'si göreve başlama (CB 2. turu gerekirse 2'si)
-- Bitiş zamanları HARİÇTİR (oy_bit 17:00 → 16:59:59'a kadar oy verilebilir).
-- ---------------------------------------------------------------------
create or replace function oyun.donem_olustur(p_ay date) returns void language plpgsql as $$
declare
  m  date := date_trunc('month', p_ay)::date;
  n  date := (date_trunc('month', p_ay) + interval '1 month')::date;
  dm text := to_char(m, 'YYYY-MM');
  dn text := to_char(n, 'YYYY-MM');
  b  timestamptz := (select baslangic from oyun.ayarlar where id = 1);
  g  int := 1;  -- gün ofseti: m + (gün-1)
begin
  -- Belediye grubu
  if oyun.tr_an(m + 5, 0) >= b then
    insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas) values
      ('bel_on', dm, oyun.tr_an(m+5,0), oyun.tr_an(m+6,0), oyun.tr_an(m+7,8), oyun.tr_an(m+7,17), oyun.tr_an(m+7,18), null),
      ('bel',    dm, null, null,                           oyun.tr_an(m+9,8), oyun.tr_an(m+9,17), oyun.tr_an(m+9,18), oyun.tr_an(m+10,0))
    on conflict (tur, donem) do nothing;
  end if;
  -- Kurultay
  if oyun.tr_an(m + 14, 0) >= b then
    insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas) values
      ('kurultay', dm, oyun.tr_an(m+14,0), oyun.tr_an(m+17,0), oyun.tr_an(m+17,8), oyun.tr_an(m+17,17), oyun.tr_an(m+17,18), oyun.tr_an(m+18,0))
    on conflict (tur, donem) do nothing;
  end if;
  -- Genel seçim grubu (ertesi ayın 1'i)
  if oyun.tr_an(m + 25, 0) >= b then
    insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas) values
      ('cb',    dn, oyun.tr_an(m+18,0), oyun.tr_an(m+25,0), oyun.tr_an(n,8),    oyun.tr_an(n,17),    oyun.tr_an(n,18),    oyun.tr_an(n+1,0)),
      ('mv_on', dn, oyun.tr_an(m+25,0), oyun.tr_an(m+26,0), oyun.tr_an(m+27,8), oyun.tr_an(m+27,17), oyun.tr_an(m+27,18), null),
      ('cb_on', dn, oyun.tr_an(m+25,0), oyun.tr_an(m+26,0), oyun.tr_an(m+27,8), oyun.tr_an(m+27,17), oyun.tr_an(m+27,18), null),
      ('mv',    dn, null, null,                             oyun.tr_an(n,8),    oyun.tr_an(n,17),    oyun.tr_an(n,18),    oyun.tr_an(n+1,0))
    on conflict (tur, donem) do nothing;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Adayların oylarını say, adaylar.oy'a yaz
-- ---------------------------------------------------------------------
create or replace function oyun.aday_oylarini_say(p_sid bigint) returns void language sql as $$
  update oyun.adaylar a set oy = coalesce(x.n, 0)
  from (select a2.id, (select count(*) from oyun.oylar o where o.secim_id = a2.secim_id and o.aday_id = a2.id) n
        from oyun.adaylar a2 where a2.secim_id = p_sid) x
  where a.id = x.id
$$;

create or replace function oyun.aday_json(p_aday_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object('aday_id', a.id, 'user_id', a.user_id, 'kad', coalesce(pr.kad, '(silinmiş)'),
                            'parti_id', a.parti_id, 'kisa', pa.kisa, 'renk', pa.renk, 'il_id', a.il_id, 'oy', coalesce(a.oy,0), 'sira', a.sira, 'vaat', a.vaat)
  from oyun.adaylar a left join oyun.profiller pr on pr.id = a.user_id left join oyun.partiler pa on pa.id = a.parti_id
  where a.id = p_aday_id
$$;

-- ---------------------------------------------------------------------
-- SONUÇLANDIRMA
-- ---------------------------------------------------------------------

-- Vekil ön seçimi: her il + parti için oy sırasına göre liste
create or replace function oyun._sonuc_mv_on(s oyun.secimler) returns jsonb language plpgsql as $$
begin
  perform oyun.aday_oylarini_say(s.id);
  update oyun.adaylar a set sira = x.rn
  from (select id, row_number() over (partition by il_id, parti_id order by oy desc, basvuru_at, id) rn
        from oyun.adaylar where secim_id = s.id) x
  where a.id = x.id;
  return jsonb_build_object(
    'katilim', (select count(*) from oyun.oylar where secim_id = s.id),
    'aday',    (select count(*) from oyun.adaylar where secim_id = s.id),
    'liste',   (select count(distinct (il_id, parti_id)) from oyun.adaylar where secim_id = s.id));
end $$;

-- Parti içi tek kazananlı ön seçimler (bel_on: il+parti başına, cb_on: parti başına)
create or replace function oyun._sonuc_tek_kazanan_on(s oyun.secimler, p_hedef_tur text) returns jsonb language plpgsql as $$
declare hedef oyun.secimler; r record; n int := 0;
begin
  perform oyun.aday_oylarini_say(s.id);
  select * into hedef from oyun.secimler where tur = p_hedef_tur and donem = s.donem;
  for r in
    select distinct on (coalesce(il_id, 0), parti_id) *
    from oyun.adaylar where secim_id = s.id
    order by coalesce(il_id, 0), parti_id, oy desc, basvuru_at, id
  loop
    -- CB: genel başkan "kendisi/başkası" dediyse ön seçim sonucu kullanılmaz
    if p_hedef_tur = 'cb' and exists (select 1 from oyun.cb_kararlar k where k.donem = s.donem and k.parti_id = r.parti_id and k.yontem <> 'onsecim') then
      continue;
    end if;
    if p_hedef_tur = 'cb' and exists (select 1 from oyun.adaylar a where a.secim_id = hedef.id and a.parti_id = r.parti_id) then
      continue;
    end if;
    insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at, vaat)
    values (hedef.id, r.user_id, r.parti_id, r.il_id, r.basvuru_at, r.vaat)
    on conflict (secim_id, user_id) do nothing;
    n := n + 1;
  end loop;
  return jsonb_build_object('katilim', (select count(*) from oyun.oylar where secim_id = s.id),
                            'aday', (select count(*) from oyun.adaylar where secim_id = s.id), 'kazanan', n);
end $$;

-- GENEL SEÇİM: ulusal baraj + her ilde D'Hondt
create or replace function oyun._sonuc_mv(s oyun.secimler) returns jsonb language plpgsql as $$
declare
  baraj   numeric := (select baraj from oyun.ayarlar where id = 1);
  onsecim oyun.secimler;
  toplam  bigint;
  il      record;
  pids    bigint[]; oys bigint[]; kaz int[]; lim int[];
  i int; k int; en int; enq numeric; q numeric;
  iller_j jsonb := '{}'::jsonb; ilj jsonb;
  bos int := 0; dolu int := 0;
begin
  select * into onsecim from oyun.secimler where tur = 'mv_on' and donem = s.donem;
  select count(*) into toplam from oyun.oylar where secim_id = s.id;

  -- ulusal oylar ve baraj (ittifak toplamı da barajı aşmaya yeter)
  create temp table if not exists _ulusal(parti_id bigint primary key, oy bigint, yuzde numeric, gecti boolean, sandalye int default 0) on commit drop;
  delete from _ulusal;
  insert into _ulusal(parti_id, oy)
    select parti_id, count(*) from oyun.oylar where secim_id = s.id group by parti_id;
  update _ulusal set yuzde = case when toplam > 0 then round(oy * 100.0 / toplam, 2) else 0 end;
  update _ulusal u set gecti = (u.yuzde >= baraj) or coalesce((
      select sum(u2.oy) * 100.0 / nullif(toplam, 0) >= baraj
      from oyun.ittifak_uyeler iu join oyun.ittifak_uyeler iu2 on iu2.ittifak_id = iu.ittifak_id
      join _ulusal u2 on u2.parti_id = iu2.parti_id
      where iu.parti_id = u.parti_id), false);

  create temp table if not exists _kaz(user_id uuid, il_id smallint, parti_id bigint) on commit drop;
  delete from _kaz;

  for il in select * from oyun.iller order by id loop
    select array_agg(x.parti_id order by x.oy desc, x.parti_id), array_agg(x.oy order by x.oy desc, x.parti_id),
           array_agg(x.lim order by x.oy desc, x.parti_id)
      into pids, oys, lim
    from (
      select o.parti_id, count(*) oy,
             (select count(*) from oyun.adaylar a where a.secim_id = onsecim.id and a.il_id = il.id and a.parti_id = o.parti_id and a.sira is not null)::int lim
      from oyun.oylar o join _ulusal u on u.parti_id = o.parti_id and u.gecti
      where o.secim_id = s.id and o.il_id = il.id
      group by o.parti_id
    ) x where x.lim > 0;

    kaz := array_fill(0, array[coalesce(array_length(pids,1),0)]);
    if pids is not null then
      for k in 1 .. il.mv loop
        en := null; enq := -1;
        for i in 1 .. array_length(pids,1) loop
          if kaz[i] < lim[i] then
            q := oys[i]::numeric / (kaz[i] + 1);
            if q > enq then enq := q; en := i; end if;   -- eşitlikte toplam oyu fazla olan (dizi sırası) kazanır
          end if;
        end loop;
        exit when en is null;
        kaz[en] := kaz[en] + 1;
      end loop;
      for i in 1 .. array_length(pids,1) loop
        if kaz[i] > 0 then
          insert into _kaz select a.user_id, il.id, pids[i] from oyun.adaylar a
            where a.secim_id = onsecim.id and a.il_id = il.id and a.parti_id = pids[i] and a.sira is not null
            order by a.sira limit kaz[i];
          update _ulusal set sandalye = sandalye + kaz[i] where parti_id = pids[i];
        end if;
      end loop;
    end if;

    select jsonb_build_object(
      'gecerli', (select count(*) from oyun.oylar where secim_id = s.id and il_id = il.id),
      'partiler', coalesce((select jsonb_object_agg(o.parti_id::text, jsonb_build_object('oy', o.n,
                     'sandalye', (select count(*) from _kaz z where z.il_id = il.id and z.parti_id = o.parti_id)))
                   from (select parti_id, count(*) n from oyun.oylar where secim_id = s.id and il_id = il.id group by parti_id) o), '{}'::jsonb),
      'secilen', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti_id', z.parti_id))
                   from _kaz z join oyun.profiller pr on pr.id = z.user_id where z.il_id = il.id), '[]'::jsonb),
      'mv', il.mv)
    into ilj;
    if (ilj->>'gecerli')::int > 0 or jsonb_array_length(ilj->'secilen') > 0 then
      iller_j := iller_j || jsonb_build_object(il.id::text, ilj);
    end if;
  end loop;

  insert into oyun.kazananlar(secim_id, user_id, il_id, parti_id)
    select s.id, user_id, il_id, parti_id from _kaz on conflict do nothing;
  select count(*) into dolu from _kaz;
  bos := 600 - dolu;

  perform oyun.olay('secim', format('Genel seçim sonuçlandı: %s oy kullanıldı, %s sandalye doldu, %s sandalye boş kaldı.', toplam, dolu, bos), null, null, s.sonuc_at);

  return jsonb_build_object(
    'toplam', toplam, 'baraj', baraj, 'dolu', dolu, 'bos', bos,
    'ulusal', coalesce((select jsonb_agg(jsonb_build_object('parti_id', u.parti_id, 'kisa', p.kisa, 'ad', p.ad, 'renk', p.renk,
                         'oy', u.oy, 'yuzde', u.yuzde, 'gecti', u.gecti, 'sandalye', u.sandalye) order by u.oy desc)
                        from _ulusal u join oyun.partiler p on p.id = u.parti_id), '[]'::jsonb),
    'iller', iller_j);
end $$;

-- Belediye ve kurultay: tek kazananlı (il başına / parti başına)
create or replace function oyun._sonuc_cok_alanli(s oyun.secimler) returns jsonb language plpgsql as $$
declare r record; liste jsonb := '[]'::jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  for r in
    select distinct on (case when s.tur = 'bel' then il_id::bigint else parti_id end) *
    from oyun.adaylar where secim_id = s.id
    order by (case when s.tur = 'bel' then il_id::bigint else parti_id end), oy desc, basvuru_at, id
  loop
    insert into oyun.kazananlar(secim_id, user_id, il_id, parti_id) values (s.id, r.user_id, r.il_id, r.parti_id)
    on conflict do nothing;
    liste := liste || oyun.aday_json(r.id);
  end loop;
  if s.tur = 'bel' then
    perform oyun.olay('secim', format('Belediye seçimleri sonuçlandı: %s ilde başkan seçildi.', jsonb_array_length(liste)), null, null, s.sonuc_at);
  else
    perform oyun.olay('secim', format('Kurultaylar sonuçlandı: %s partide genel başkan seçildi.', jsonb_array_length(liste)), null, null, s.sonuc_at);
  end if;
  return jsonb_build_object('katilim', (select count(*) from oyun.oylar where secim_id = s.id),
                            'kazananlar', liste,
                            'adaylar', coalesce((select jsonb_agg(oyun.aday_json(a.id) order by a.il_id, a.parti_id, a.oy desc) from oyun.adaylar a where a.secim_id = s.id), '[]'::jsonb));
end $$;

-- Cumhurbaşkanlığı 1. tur: %50'yi geçen kazanır, yoksa ilk iki aday 2. tura
create or replace function oyun._sonuc_cb(s oyun.secimler) returns jsonb language plpgsql as $$
declare
  toplam bigint; n int; birinci record; ikinci record; t2 oyun.secimler;
  gun date := (s.oy_bas at time zone 'Europe/Istanbul')::date;
  adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  select count(*) into toplam from oyun.oylar where secim_id = s.id;
  select count(*) into n from oyun.adaylar where secim_id = s.id;
  select coalesce(jsonb_agg(oyun.aday_json(a.id) order by a.oy desc, a.basvuru_at), '[]'::jsonb) into adaylar_j
    from oyun.adaylar a where a.secim_id = s.id;
  if n = 0 then
    perform oyun.olay('secim', 'Cumhurbaşkanlığı seçiminde aday yoktu; makam boş kalacak.', null, null, s.sonuc_at);
    return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'ikinci_tur', false);
  end if;
  select * into birinci from oyun.adaylar where secim_id = s.id order by oy desc, basvuru_at, id limit 1;
  if n = 1 or (toplam > 0 and birinci.oy * 2 > toplam) then
    insert into oyun.kazananlar values (s.id, birinci.user_id, null, birinci.parti_id) on conflict do nothing;
    perform oyun.olay('secim', format('Cumhurbaşkanı ilk turda seçildi: %s (%%%s).',
      (select kad from oyun.profiller where id = birinci.user_id),
      case when toplam > 0 then round(birinci.oy * 100.0 / toplam, 1) else 100 end), null, birinci.parti_id, s.sonuc_at);
    return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'ikinci_tur', false,
                              'kazanan', oyun.aday_json(birinci.id));
  end if;
  -- 2. tur: ertesi gün 08:00-17:00, göreve başlama bir sonraki gün 00:00
  select * into ikinci from oyun.adaylar where secim_id = s.id and id <> birinci.id order by oy desc, basvuru_at, id limit 1;
  insert into oyun.secimler(tur, donem, oy_bas, oy_bit, sonuc_at, goreve_bas)
  values ('cb2', s.donem, oyun.tr_an(gun+1,8), oyun.tr_an(gun+1,17), oyun.tr_an(gun+1,18), oyun.tr_an(gun+2,0))
  on conflict (tur, donem) do nothing
  returning * into t2;
  if t2.id is not null then
    insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at, vaat) values
      (t2.id, birinci.user_id, birinci.parti_id, null, birinci.basvuru_at, birinci.vaat),
      (t2.id, ikinci.user_id,  ikinci.parti_id,  null, ikinci.basvuru_at, ikinci.vaat);
  end if;
  perform oyun.olay('secim', format('Cumhurbaşkanlığı seçimi ikinci tura kaldı: %s ve %s yarın sandıkta.',
    (select kad from oyun.profiller where id = birinci.user_id), (select kad from oyun.profiller where id = ikinci.user_id)), null, null, s.sonuc_at);
  return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'ikinci_tur', true);
end $$;

-- Cumhurbaşkanlığı 2. tur: çok oy alan kazanır; eşitlikte 1. turda önde olan
create or replace function oyun._sonuc_cb2(s oyun.secimler) returns jsonb language plpgsql as $$
declare k record; ilk bigint; toplam bigint; adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  select id into ilk from oyun.secimler where tur = 'cb' and donem = s.donem;
  select count(*) into toplam from oyun.oylar where secim_id = s.id;
  select a.* into k from oyun.adaylar a
    left join oyun.adaylar a1 on a1.secim_id = ilk and a1.user_id = a.user_id
    where a.secim_id = s.id order by a.oy desc, a1.oy desc nulls last, a.basvuru_at limit 1;
  select coalesce(jsonb_agg(oyun.aday_json(a.id) order by a.oy desc), '[]'::jsonb) into adaylar_j from oyun.adaylar a where a.secim_id = s.id;
  if k.id is not null then
    insert into oyun.kazananlar values (s.id, k.user_id, null, k.parti_id) on conflict do nothing;
    perform oyun.olay('secim', format('Cumhurbaşkanı ikinci turda seçildi: %s.', (select kad from oyun.profiller where id = k.user_id)), null, k.parti_id, s.sonuc_at);
  end if;
  return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'kazanan', case when k.id is null then null else oyun.aday_json(k.id) end);
end $$;

create or replace function oyun.sonuclandir(p_sid bigint) returns void language plpgsql as $$
declare s oyun.secimler; j jsonb;
begin
  select * into s from oyun.secimler where id = p_sid for update;
  if s.durum <> 'bekliyor' then return; end if;
  j := case s.tur
    when 'mv_on'    then oyun._sonuc_mv_on(s)
    when 'bel_on'   then oyun._sonuc_tek_kazanan_on(s, 'bel')
    when 'cb_on'    then oyun._sonuc_tek_kazanan_on(s, 'cb')
    when 'mv'       then oyun._sonuc_mv(s)
    when 'bel'      then oyun._sonuc_cok_alanli(s)
    when 'kurultay' then oyun._sonuc_cok_alanli(s)
    when 'cb'       then oyun._sonuc_cb(s)
    when 'cb2'      then oyun._sonuc_cb2(s)
  end;
  update oyun.secimler set sonuc = j, durum = case when goreve_bas is null then 'tamam' else 'sonuclandi' end
  where id = p_sid;
end $$;

-- ---------------------------------------------------------------------
-- MAKAMLAR
-- ---------------------------------------------------------------------

-- Boşalan vekilliğe, aynı partinin o ildeki listesinden sıradaki aday gelir
create or replace function oyun.yedek_getir(p_mv_secim bigint, p_il smallint, p_parti bigint, p_zaman timestamptz)
returns void language plpgsql as $$
declare onsecim bigint; y record;
begin
  select o.id into onsecim from oyun.secimler o join oyun.secimler m on m.donem = o.donem and m.tur = 'mv'
    where o.tur = 'mv_on' and m.id = p_mv_secim;
  select a.* into y from oyun.adaylar a
    join oyun.profiller pr on pr.id = a.user_id and pr.parti_id = p_parti
    where a.secim_id = onsecim and a.il_id = p_il and a.parti_id = p_parti and a.sira is not null
      and not exists (select 1 from oyun.makamlar m where m.user_id = a.user_id and m.bit is null)
      and not exists (select 1 from oyun.partiler pg where pg.gb = a.user_id)
      and not exists (select 1 from oyun.makamlar m where m.user_id = a.user_id and m.secim_id = p_mv_secim and m.tur = 'mv')
    order by a.sira limit 1;
  if y.id is not null then
    insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, kaynak, bas)
    values ('mv', y.user_id, p_il, p_parti, p_mv_secim, 'yedek', p_zaman);
    perform oyun.bildir(y.user_id, format('Boşalan bir sandalye nedeniyle %s milletvekili olarak Meclis''e girdin.', (select ad from oyun.iller where id = p_il)), p_zaman);
    perform oyun.olay('makam', format('%s, %s listesinden yedek olarak Meclis''e girdi.', (select kad from oyun.profiller where id = y.user_id),
                      (select ad from oyun.iller where id = p_il)), p_il, p_parti, p_zaman);
  else
    perform oyun.olay('makam', format('%s ilinde bir sandalye boş kaldı: listede yedek kalmadı.', (select ad from oyun.iller where id = p_il)), p_il, p_parti, p_zaman);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- TEK GÖREV KURALI: kimse aynı anda iki görev taşıyamaz. İstisnalar:
--   • milletvekili + genel başkan yardımcısı
--   • genel başkan + cumhurbaşkanı (genel başkan kendini aday gösterip kazanırsa)
-- Görevler: mv, bel, cb, bakan (makamlar tablosu), gb (partiler.gb), gby (parti_gby)
-- ---------------------------------------------------------------------
create or replace function oyun.roller(p_user uuid) returns text[] language sql stable as $$
  select coalesce(array_agg(r), '{}'::text[]) from (
    select tur as r from oyun.makamlar where user_id = p_user and bit is null
    union all select 'gb' from oyun.partiler where gb = p_user
    union all select 'gby' from oyun.parti_gby where user_id = p_user) x
$$;

create or replace function oyun.rol_uyumlu(a text, b text) returns boolean language sql immutable as $$
  select (a = b and a in ('gb','gby')) or (a, b) in (('mv','gby'),('gby','mv'),('gb','cb'),('cb','gb'))
$$;

create or replace function oyun.rol_ad(r text) returns text language sql immutable as $$
  select case r when 'mv' then 'milletvekilliği' when 'bel' then 'belediye başkanlığı' when 'cb' then 'cumhurbaşkanlığı'
                when 'bakan' then 'bakanlık' when 'gb' then 'genel başkanlık' when 'gby' then 'genel başkan yardımcılığı' else r end
$$;

-- p_yeni görevi alınırsa, kişinin elindeki hangi görevle çakışır? (yoksa null)
create or replace function oyun.rol_cakisma(p_user uuid, p_yeni text) returns text language sql stable as $$
  select oyun.rol_ad(r) from unnest(oyun.roller(p_user)) r where not oyun.rol_uyumlu(r, p_yeni) limit 1
$$;

create or replace function oyun.makam_ad(p_tur text, p_il smallint, p_bakanlik text) returns text language sql stable as $$
  select case p_tur when 'mv' then (select ad from oyun.iller where id = p_il) || ' milletvekilliği'
                    when 'bel' then (select ad from oyun.iller where id = p_il) || ' belediye başkanlığı'
                    when 'cb' then 'cumhurbaşkanlığı'
                    else coalesce((select ad from oyun.bakanliklar where kod = p_bakanlik), 'bakanlık') end
$$;

create or replace function oyun.makam_bitir(p_id bigint, p_zaman timestamptz, p_neden text) returns void language plpgsql as $$
declare m oyun.makamlar;
begin
  update oyun.makamlar set bit = p_zaman, bitis_neden = p_neden where id = p_id and bit is null returning * into m;
  if m.id is not null and p_neden in ('yeni_gorev','gorevden_alindi','kabine_yenilendi') then
    perform oyun.bildir(m.user_id, case p_neden
      when 'yeni_gorev' then format('Yeni görevine başladığın için %s görevin sona erdi.', oyun.makam_ad(m.tur, m.il_id, m.bakanlik))
      when 'gorevden_alindi' then format('Cumhurbaşkanı seni %s görevinden aldı.', oyun.makam_ad(m.tur, m.il_id, m.bakanlik))
      else format('Yeni cumhurbaşkanı göreve başladığı için %s görevin sona erdi.', oyun.makam_ad(m.tur, m.il_id, m.bakanlik)) end, p_zaman);
  end if;
  if m.id is not null and m.tur = 'mv' and p_neden <> 'donem_bitti' then
    perform oyun.yedek_getir(m.secim_id, m.il_id, m.parti_id, p_zaman);
  end if;
end $$;

create or replace function oyun.goreve_baslat(p_sid bigint) returns void language plpgsql as $$
declare s oyun.secimler; k record; m record; t timestamptz; ilk oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_sid for update;
  if s.durum <> 'sonuclandi' then return; end if;
  t := s.goreve_bas;

  if s.tur = 'kurultay' then
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id and parti_id = k.parti_id);
      if (select gb from oyun.partiler where id = k.parti_id) is distinct from k.user_id then
        delete from oyun.parti_gby where parti_id = k.parti_id;   -- yeni genel başkan kendi ekibini kurar
      end if;
      delete from oyun.parti_gby where user_id = k.user_id;       -- genel başkan aynı zamanda yardımcı olamaz
      -- tek görev kuralı: milletvekili, belediye başkanı, bakan görevleri düşer (cumhurbaşkanlığı kalabilir)
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null and tur <> 'cb' loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      update oyun.partiler set gb = k.user_id where id = k.parti_id;
      perform oyun.bildir(k.user_id, format('Kurultayı kazandın: %s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilirsin.', (select ad from oyun.partiler where id = k.parti_id)), t);
    end loop;
    -- BOŞ MAKAM KURALI: kurultayda kimse aday olmadığı için genel başkansız kalan parti kıdemli üyesini genel başkan yapar
    perform oyun.gb_halef(t);
  elsif s.tur = 'cb' and coalesce((s.sonuc->>'ikinci_tur')::boolean, false) then
    null; -- 2. tur bekleniyor: görevdeki cumhurbaşkanı 2. tur sonucuna kadar devam eder
  else
    -- Milletvekilleri liste usulüyle seçilir: eski Meclis topluca biter. (Boş kalan sandalyeleri yedek listeler doldurur.)
    if s.tur = 'mv' then
      for m in select id from oyun.makamlar where tur = 'mv' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'donem_bitti');
      end loop;
    end if;
    -- BOŞ MAKAM KURALI: belediye başkanlığı ve cumhurbaşkanlığında eski görevli ancak yerine yenisi gerçekten başlayınca düşer.
    -- Seçimde aday çıkmadıysa (ya da kazanan göreve başlayamadıysa) görevdeki, yeni biri seçilene kadar görevine devam eder.
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id);   -- hesap silinmiş
      -- Genel başkan vekil/belediye başkanı olamaz (adaylığı zaten engellenir; yine de güvenceye al)
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) in ('mv','bel')
         and exists (select 1 from oyun.partiler where gb = k.user_id) then
        perform oyun.bildir(k.user_id, 'Genel başkan olduğun için seçildiğin bu görevi üstlenemezsin.', t);
        if s.tur = 'mv' then perform oyun.yedek_getir(s.id, k.il_id, k.parti_id, t); end if;
        continue;
      end if;
      -- Yerine geçilen görevli (aynı ilin belediye başkanı / cumhurbaşkanı) görevi devreder
      if s.tur = 'bel' then
        for m in select id from oyun.makamlar where tur = 'bel' and il_id = k.il_id and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      elsif s.tur in ('cb','cb2') then
        for m in select id from oyun.makamlar where tur = 'cb' and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      end if;
      -- Tek görev kuralı: kişinin elindeki diğer görev düşer (milletvekili + genel başkan yardımcısı ve genel başkan + cumhurbaşkanı hariç)
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) in ('bel','cb') then
        delete from oyun.parti_gby where user_id = k.user_id;
      end if;
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, bas)
      values (case when s.tur = 'cb2' then 'cb' else s.tur end, k.user_id, k.il_id, k.parti_id, s.id, t);
      perform oyun.bildir(k.user_id, case when s.tur in ('cb','cb2') then 'Cumhurbaşkanı olarak göreve başladın. Kabineni kurmak için 12 bakanı atayabilirsin.'
        else format('%s olarak göreve başladın.', case s.tur when 'mv' then (select ad from oyun.iller where id = k.il_id) || ' Milletvekili'
                                                         else (select ad from oyun.iller where id = k.il_id) || ' Belediye Başkanı' end) end, t);
    end loop;
    -- Seçimde kimse kazanamadıysa görevde kalanlara haber ver
    if s.tur in ('cb','cb2') and not exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select user_id from oyun.makamlar where tur = 'cb' and bit is null loop
        perform oyun.bildir(m.user_id, 'Cumhurbaşkanlığı seçiminde yeni bir başkan çıkmadı; yeni cumhurbaşkanı seçilene kadar görevine devam ediyorsun.', t);
      end loop;
    end if;
    -- Yeni Meclis göreve başlayınca sonuçlanmamış kanun teklifleri kadük olur
    if s.tur = 'mv' then perform oyun.kanunlar_kaduk(t); end if;
    -- Yeni bir cumhurbaşkanlığı dönemi gerçekten başlayınca kabine yenilenir; seçimde kimse kazanamadıysa kabine yerinde kalır
    if s.tur in ('cb','cb2') and exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select id from oyun.makamlar where tur = 'bakan' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'kabine_yenilendi');
      end loop;
    end if;
  end if;
  update oyun.secimler set durum = 'tamam' where id = s.id;
end $$;

-- ---------------------------------------------------------------------
-- TICK: her dakika çalışır. Takvimi üretir, saati gelen sayım ve
-- göreve başlamaları sırayla işler. Kaçırılan dakikaları da telafi eder.
-- ---------------------------------------------------------------------
create or replace function oyun.tick() returns int language plpgsql as $$
declare t timestamptz := oyun.simdi(); ay date; r record; n int := 0;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay := date_trunc('month', t at time zone 'Europe/Istanbul')::date;
  perform oyun.donem_olustur(ay);
  perform oyun.donem_olustur((ay + interval '1 month')::date);
  -- Günde bir kez: 30 günden eski sohbet/propaganda, 60 günden eski bildirim, 90 günden eski özel mesaj silinir
  if (select son_temizlik from oyun.ayarlar where id = 1) is distinct from (t at time zone 'Europe/Istanbul')::date then
    delete from oyun.mesajlar where zaman < t - interval '30 days';
    delete from oyun.yayinlar where zaman < t - interval '30 days';
    delete from oyun.bildirimler where zaman < t - interval '60 days';
    delete from oyun.ozel where zaman < t - interval '90 days';
    delete from oyun.push_kuyruk where olusturma < now() - interval '7 days';
    update oyun.ayarlar set son_temizlik = (t at time zone 'Europe/Istanbul')::date where id = 1;
  end if;
  loop
    select * into r from (
      select id, sonuc_at as zaman, 0 as asama, oyun.oncelik(tur) o from oyun.secimler where durum = 'bekliyor' and sonuc_at <= t
      union all
      select id, goreve_bas, 1, oyun.oncelik(tur) from oyun.secimler where durum = 'sonuclandi' and goreve_bas <= t
    ) x order by zaman, asama, o limit 1;
    exit when not found;
    if r.asama = 0 then perform oyun.sonuclandir(r.id); else perform oyun.goreve_baslat(r.id); end if;
    n := n + 1;
    exit when n > 200;
  end loop;
  perform oyun.kanun_tick(t);
  perform oyun.mevzuat_tick(t);
  perform oyun.meclis_tick(t);
  perform oyun.guvenlik_tick(t);
  perform oyun.gunluk_ekonomi(t);
  perform oyun.banka_tick(t);
  perform oyun.push_hatirlatmalar(t);
  perform oyun.push_tetikle();
  return n;
end $$;
