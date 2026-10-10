-- Seçim Simülasyonu Online — 2026-10-11 yeni özellikler (tek dosya, tek Run).
-- İçerik: 76 genel seçim sayım düzeltmesi · 75 seçim gecesi · 77 boş makam fırsatı · 78 paylaşım akışı · 79 başarım/ay raporu/gün sonu özeti.
-- Yalnız ekler; oyuncu verisine dokunmaz; iki kez çalıştırılabilir. Kaynak: gelistirici/sql/75–79.
begin;

-- ===== Genel seçim sayım hatası düzeltmesi (76_sonuc_mv_takma_ad_duzeltme.sql) =====
-- =====================================================================
--  76 · GENEL SEÇİM SAYIM HATASI: "column reference l.aday_id is ambiguous"
--
--  KÖK NEDEN: oyun._sonuc_mv (56 ve 72) içinde plpgsql döngü değişkeni "l" ile,
--  bağımsız adayları seçen SQL ifadesindeki tablo takma adı "l" (from _b23_liste l)
--  çakışıyor. PostgreSQL bunu ilk çalıştırmada "column reference "l.aday_id" is
--  ambiguous" diye reddeder ve sayım hiç tamamlanmaz.
--  Canlıda bugüne kadar görünmedi çünkü "her aday vekil" test modu AÇIK
--  (oyun.mv_secim_modu): o modda oyun._sonuc_mv_test çalışır ve bu yola hiç girilmez.
--  Test modu kapatıldığı anda (gerçek oyuncular için kapatılacak) genel seçim,
--  1 Kasım dahil, sayılamazdı ve oyun motoru sonucu yazamazdı.
--
--  DÜZELTME: yalnızca o ifadenin takma adı "bl" yapıldı. Fonksiyonun geri kalanı,
--  canlıda çalışan sürümle (72_parti_birlesme_ortak_mv_listesi) birebir aynıdır.
--  Oyuncu verisine dokunmaz; iki kez çalıştırılabilir.
-- =====================================================================
CREATE OR REPLACE FUNCTION oyun._sonuc_mv(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
      select v.lider as parti_id,
             count(*)::bigint oy,
             (select count(*)
              from oyun.adaylar a
              where a.secim_id=onsecim.id
                and a.il_id=il.id
                and a.parti_id is not null
                and oyun.mv_ortak_liste_partisi(s.id,il.id,a.parti_id)=v.lider
                and a.sira is not null)::int lim
      from (
        select oyun.mv_ortak_liste_partisi(s.id,il.id,o.parti_id) as lider
        from oyun.oylar o
        join _b23_ulusal u on u.parti_id=o.parti_id and u.gecti
        where o.secim_id=s.id and o.il_id=il.id and o.parti_id is not null
      ) v
      group by v.lider
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
      select a.user_id,il.id,a.parti_id,a.id
      from oyun.adaylar a
      where a.secim_id=onsecim.id
        and a.il_id=il.id
        and a.parti_id is not null
        and oyun.mv_ortak_liste_partisi(s.id,il.id,a.parti_id)=l.parti_id
        and a.sira is not null
      order by a.sira, case when a.parti_id=l.parti_id then 0 else 1 end, a.id
      limit l.kaz;
    end loop;

    insert into _b23_kaz(user_id,il_id,parti_id,aday_id)
    select a.user_id,il.id,null,a.id
    from _b23_liste bl
    join oyun.adaylar a on a.id=bl.aday_id
    where bl.parti_id is null and bl.kaz>0;

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

  -- Sandalyeler liste sahibine değil, seçilen adayların kendi partilerine yazılır.
  update _b23_ulusal u set sandalye=(select count(*) from _b23_kaz z where z.parti_id=u.parti_id);

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
end $function$
;

-- ===== Kademeli seçim gecesi (75_secim_gecesi.sql) =====
-- =====================================================================
--  75 · KADEMELİ SEÇİM GECESİ
--
--  Genel seçim (mv), cumhurbaşkanlığı (cb) ve 2. tur (cb2) sonuçları sayım
--  saatinde (22:30) hesaplanır ama oyunculara ANINDA değil, il il, yaklaşık
--  12 dakikada açılır. Küçük iller önce, büyükler sonra; her an yalnızca
--  açılmış illerin oyları toplanır ("ilk sonuçlar"). Süre değişebilir:
--     update oyun.secim_gecesi_ayar set sure_sn = 600;   -- 10 dakika (60-1800)
--
--  Güvenlik ilkesi: motor (oyun.tick, oyun.sonuclandir) ve oy sayımı DEĞİŞMEZ.
--  Gerçek sonuç yine 22:30'da yazılır; bu modül yalnızca oyunculara ne
--  gösterileceğini sınırlar:
--   • public.secim_detay sarmalanır (asıl fonksiyon oyun._secim_detay_ham
--     adıyla korunur); sonuç alanı açılmış illere göre süzülür.
--   • "Genel seçim sonuçlandı / Cumhurbaşkanı seçildi" Gündem satırı sayım
--     bitene kadar ileri tarihlenir (zaman <= şimdi süzgeci gizler).
--   • Sayımın %25-50-75'inde ve bitişinde herkese bildirim gider.
--  Zamanlayıcı (pg_cron) yoksa hiçbir şey gizlenmez; oyun eskisi gibi çalışır.
-- =====================================================================

create table if not exists oyun.secim_gecesi_ayar(
  id     boolean primary key default true check (id),
  sure_sn int not null default 720 check (sure_sn between 60 and 1800)
);
insert into oyun.secim_gecesi_ayar(id) values (true) on conflict (id) do nothing;

create table if not exists oyun.secim_gecesi(
  secim_id   bigint primary key references oyun.secimler(id) on delete cascade,
  baslangic  timestamptz not null,
  sure_sn    int not null,
  plan       jsonb not null,           -- [{"il":12,"oy":40,"sn":35}, ...] açılış sırasıyla
  toplam_oy  bigint not null default 0,
  asama      smallint not null default -1,   -- gönderilen son bildirim eşiği (0..4)
  olusturma  timestamptz not null default now()
);

do $$ declare n text; begin
  foreach n in array array['secim_gecesi_ayar','secim_gecesi'] loop
    execute format('alter table oyun.%I enable row level security', n);
    execute format('revoke all on oyun.%I from public, anon, authenticated', n);
  end loop;
end $$;

create or replace function oyun.secim_gecesi_sure() returns int
language sql stable set search_path = '' as $$
  select coalesce((select sure_sn from oyun.secim_gecesi_ayar where id), 720)
$$;

-- Sayım başlangıcından bu yana geçen saniye (kayıt yoksa null)
create or replace function oyun.secim_gecesi_gecen(p_secim bigint) returns numeric
language sql stable set search_path = '' as $$
  select extract(epoch from (oyun.simdi() - g.baslangic))::numeric
  from oyun.secim_gecesi g where g.secim_id = p_secim
$$;

-- Sayım hâlâ sürüyor mu? (başladı ve süre dolmadı)
create or replace function oyun.secim_gecesi_aktif_mi(p_secim bigint) returns boolean
language sql stable set search_path = '' as $$
  select coalesce((select oyun.secim_gecesi_gecen(g.secim_id) >= 0
                   and oyun.secim_gecesi_gecen(g.secim_id) < g.sure_sn
                   from oyun.secim_gecesi g where g.secim_id = p_secim), false)
$$;

-- Şu ana kadar açılmış il numaraları
create or replace function oyun.secim_gecesi_acik_iller(p_secim bigint) returns int[]
language sql stable set search_path = '' as $$
  select coalesce(array_agg((e->>'il')::int), '{}'::int[])
  from oyun.secim_gecesi g, jsonb_array_elements(g.plan) e
  where g.secim_id = p_secim and (e->>'sn')::numeric <= oyun.secim_gecesi_gecen(p_secim)
$$;

-- Sayım planı: küçük iller önce; ilin açılış zamanı, o ile kadar sayılmış oyların
-- toplam içindeki payıyla orantılı. Oylar kesinleştikten (sandık kapandıktan) sonra çağrılır.
create or replace function oyun.secim_gecesi_hazirla(p_secim bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare s oyun.secimler; sure int := oyun.secim_gecesi_sure(); top bigint; p jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('mv','cb','cb2') then return false; end if;
  if exists (select 1 from oyun.secim_gecesi where secim_id = s.id) then return true; end if;
  select count(*) into top from oyun.oylar where secim_id = s.id and il_id is not null;
  if top = 0 then return false; end if;
  select jsonb_agg(jsonb_build_object('il', il_id, 'oy', oy,
           'sn', least(sure, greatest(15, ceil(sure * kum::numeric / top)::int))) order by kum, il_id)
    into p
  from (select il_id, oy, sum(oy) over (order by oy, il_id) kum
        from (select il_id, count(*) oy from oyun.oylar
              where secim_id = s.id and il_id is not null group by il_id) x) y;
  insert into oyun.secim_gecesi(secim_id, baslangic, sure_sn, plan, toplam_oy)
  values (s.id, s.sonuc_at, sure, p, top) on conflict (secim_id) do nothing;
  -- Genel "Sonuçlar açıklandı" bildirimi yerine kademeli bildirimler gider
  update oyun.secimler set hatirlatma = hatirlatma || '{"sonuc":true}'::jsonb where id = s.id;
  return true;
end $$;

-- Açılmış illerdeki oyların özeti: toplam, il sayısı, önde olan
create or replace function oyun.secim_gecesi_ozet(p_secim bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s oyun.secimler; g oyun.secim_gecesi; acik int[]; acilan_oy bigint; onde text; n int;
begin
  select * into s from oyun.secimler where id = p_secim;
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  if g.secim_id is null then return null; end if;
  acik := oyun.secim_gecesi_acik_iller(p_secim);
  select count(*), coalesce(sum((e->>'oy')::bigint), 0) into n, acilan_oy
  from jsonb_array_elements(g.plan) e where (e->>'il')::int = any(acik);
  if acilan_oy > 0 then
    if s.tur = 'mv' then
      select pa.kisa || ' %' || replace(round(c * 100.0 / acilan_oy, 1)::text, '.', ',') into onde
      from (select parti_id, count(*) c from oyun.oylar
            where secim_id = p_secim and il_id = any(acik) and parti_id is not null
            group by parti_id order by count(*) desc, parti_id limit 1) t
      join oyun.partiler pa on pa.id = t.parti_id;
    else
      select pr.kad || ' %' || replace(round(c * 100.0 / acilan_oy, 1)::text, '.', ',') into onde
      from (select aday_id, count(*) c from oyun.oylar
            where secim_id = p_secim and il_id = any(acik) and aday_id is not null
            group by aday_id order by count(*) desc, aday_id limit 1) t
      join oyun.adaylar a on a.id = t.aday_id
      join oyun.profiller pr on pr.id = a.user_id;
    end if;
  end if;
  return jsonb_build_object('acilan_il', n, 'toplam_il', jsonb_array_length(g.plan),
    'acilan_oy', acilan_oy, 'toplam_oy', g.toplam_oy,
    'yuzde', case when g.toplam_oy > 0 then round(acilan_oy * 100.0 / g.toplam_oy, 1) else 0 end,
    'onde', onde);
end $$;

-- Süzülmüş sonuç: yalnızca açılmış illerin oyları ve sandalyeleri
create or replace function oyun.secim_gecesi_filtre(s oyun.secimler, ham jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare acik int[]; iller_f jsonb; toplam bigint; dolu int; mvtop int; bag_s int; bag_oy bigint;
        ulusal_f jsonb; baraj numeric; bag_f jsonb; cb_top bigint; adaylar_f jsonb;
begin
  if ham is null or not oyun.secim_gecesi_aktif_mi(s.id) then return ham; end if;
  acik := oyun.secim_gecesi_acik_iller(s.id);
  if s.tur = 'mv' then
    baraj := coalesce((ham->>'baraj')::numeric, 0);
    select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) into iller_f
      from jsonb_each(coalesce(ham->'iller', '{}'::jsonb)) e(k, v) where k::int = any(acik);
    select coalesce(sum((v->>'gecerli')::bigint), 0), coalesce(sum((v->>'mv')::int), 0)
      into toplam, mvtop from jsonb_each(iller_f) e(k, v);
    select coalesce(jsonb_agg(b), '[]'::jsonb), coalesce(sum((b->>'oy')::bigint), 0),
           coalesce(sum((b->>'sandalye')::int), 0)
      into bag_f, bag_oy, bag_s
      from jsonb_array_elements(coalesce(ham->'bagimsizlar', '[]'::jsonb)) b
      where (b->>'il_id')::int = any(acik);
    select coalesce(jsonb_agg(jsonb_build_object(
             'parti_id', u->'parti_id', 'kisa', u->'kisa', 'ad', u->'ad', 'renk', u->'renk',
             'oy', t.oy, 'yuzde', case when toplam > 0 then round(t.oy * 100.0 / toplam, 2) else 0 end,
             'gecti', case when toplam > 0 then t.oy * 100.0 / toplam >= baraj else false end,
             'sandalye', t.sandalye) order by t.oy desc), '[]'::jsonb)
      into ulusal_f
      from jsonb_array_elements(coalesce(ham->'ulusal', '[]'::jsonb)) u
      cross join lateral (
        select coalesce(sum((v->'partiler'->((u->>'parti_id'))->>'oy')::bigint), 0) oy,
               coalesce(sum((v->'partiler'->((u->>'parti_id'))->>'sandalye')::int), 0) sandalye
        from jsonb_each(iller_f) e(k, v)) t;
    select coalesce(sum((x->>'sandalye')::int), 0) into dolu from jsonb_array_elements(ulusal_f) x;
    dolu := dolu + bag_s;
    return jsonb_build_object('toplam', toplam, 'baraj', baraj, 'sandalye_toplam', mvtop,
      'dolu', dolu, 'bos', greatest(0, mvtop - dolu), 'bagimsiz_oy', bag_oy, 'bagimsiz_sandalye', bag_s,
      'bagimsizlar', bag_f, 'ulusal', ulusal_f, 'iller', iller_f, 'gece', true);
  elsif s.tur in ('cb','cb2') then
    select count(*) into cb_top from oyun.oylar where secim_id = s.id and il_id = any(acik);
    select coalesce(jsonb_agg(jsonb_set(a, '{oy}', to_jsonb((
             select count(*) from oyun.oylar o
             where o.secim_id = s.id and o.aday_id = (a->>'aday_id')::bigint and o.il_id = any(acik))))
           order by (select count(*) from oyun.oylar o
             where o.secim_id = s.id and o.aday_id = (a->>'aday_id')::bigint and o.il_id = any(acik)) desc), '[]'::jsonb)
      into adaylar_f
      from jsonb_array_elements(coalesce(ham->'adaylar', '[]'::jsonb)) a;
    return jsonb_build_object('toplam', cb_top, 'adaylar', adaylar_f, 'ikinci_tur', false, 'gece', true);
  end if;
  return ham;
end $$;

-- Arayüzün her birkaç saniyede yoklayacağı canlı sayım durumu
create or replace function public.secim_gecesi(p_secim bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare g oyun.secim_gecesi; s oyun.secimler; gecen numeric; acik int[]; oz jsonb; son jsonb;
begin
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  select * into s from oyun.secimler where id = p_secim;
  if g.secim_id is null then return jsonb_build_object('aktif', false, 'var', false); end if;
  gecen := oyun.secim_gecesi_gecen(p_secim);
  if gecen < 0 then
    return jsonb_build_object('aktif', false, 'var', true, 'basliyor', true, 'baslangic', g.baslangic,
                              'saniye_kaldi', ceil(-gecen)::int);
  end if;
  acik := oyun.secim_gecesi_acik_iller(p_secim);
  oz := oyun.secim_gecesi_ozet(p_secim);
  -- son açılan beş il ve ilde önde olan
  select coalesce(jsonb_agg(x order by (x->>'sn')::int desc), '[]'::jsonb) into son from (
    select jsonb_build_object('il_id', (e->>'il')::int, 'ad', i.ad, 'sn', (e->>'sn')::int,
      'onde', case when s.tur = 'mv' then
          (select pa.kisa from oyun.oylar o join oyun.partiler pa on pa.id = o.parti_id
           where o.secim_id = p_secim and o.il_id = (e->>'il')::int and o.parti_id is not null
           group by pa.kisa order by count(*) desc, pa.kisa limit 1)
        else
          (select pr.kad from oyun.oylar o join oyun.adaylar a on a.id = o.aday_id
           join oyun.profiller pr on pr.id = a.user_id
           where o.secim_id = p_secim and o.il_id = (e->>'il')::int
           group by pr.kad order by count(*) desc, pr.kad limit 1) end) x
    from jsonb_array_elements(g.plan) e join oyun.iller i on i.id = (e->>'il')::int
    where (e->>'il')::int = any(acik)
    order by (e->>'sn')::int desc, (e->>'il')::int limit 5) t;
  return oz || jsonb_build_object('aktif', gecen < g.sure_sn, 'var', true, 'tur', s.tur,
    'baslangic', g.baslangic, 'bitis', g.baslangic + make_interval(secs => g.sure_sn),
    'sure_sn', g.sure_sn, 'gecen_sn', least(gecen, g.sure_sn)::int,
    'saniye_kaldi', greatest(0, ceil(g.sure_sn - gecen))::int, 'son_acilan', son);
end $$;

-- Gündem için: şu an sayımı süren seçimler
create or replace function public.secim_gecesi_aktif() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('secim_id', g.secim_id, 'tur', s.tur,
           'bitis', g.baslangic + make_interval(secs => g.sure_sn),
           'yuzde', (oyun.secim_gecesi_ozet(g.secim_id))->'yuzde') order by g.secim_id), '[]'::jsonb)
  from oyun.secim_gecesi g join oyun.secimler s on s.id = g.secim_id
  where oyun.secim_gecesi_aktif_mi(g.secim_id)
$$;

-- Asıl secim_detay'i koru ve yerine süzgeçli sarmalayıcıyı koy. Canlıda fonksiyon
-- kaynaktan farklı olsa da çalışır: mevcut tanım olduğu gibi _secim_detay_ham olur.
do $$ begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'secim_detay'
               and pg_get_functiondef(p.oid) not like '%secim_gecesi_filtre%') then
    drop function if exists oyun._secim_detay_ham(bigint);
    alter function public.secim_detay(bigint) set schema oyun;
    alter function oyun.secim_detay(bigint) rename to _secim_detay_ham;
  end if;
end $$;

create or replace function public.secim_detay(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare r jsonb; s oyun.secimler;
begin
  r := oyun._secim_detay_ham(p_secim);
  select * into s from oyun.secimler where id = p_secim;
  if s.id is not null and s.tur in ('mv','cb','cb2') and oyun.secim_gecesi_aktif_mi(p_secim) then
    r := jsonb_set(r, '{sonuc}', coalesce(oyun.secim_gecesi_filtre(s, r->'sonuc'), 'null'::jsonb))
         || jsonb_build_object('gece', public.secim_gecesi(p_secim));
  end if;
  return r;
end $$;

-- Sayım bitene kadar sonuç manşetini gizle (Gündem yalnızca zaman <= şimdi olanı gösterir)
create or replace function oyun.tg_olay_gece_gizle() returns trigger
language plpgsql set search_path = '' as $$
declare bit timestamptz;
begin
  if new.tur = 'secim' and new.metin ~ '^(Genel seçim sonuçlandı|Cumhurbaşkanı|Cumhurbaşkanlığı seçimi)' then
    select g.baslangic + make_interval(secs => g.sure_sn) into bit
    from oyun.secim_gecesi g where g.baslangic = new.zaman order by g.secim_id limit 1;
    if bit is not null then new.zaman := bit; end if;
  end if;
  return new;
end $$;
drop trigger if exists olay_gece_gizle on oyun.olaylar;
create trigger olay_gece_gizle before insert on oyun.olaylar
  for each row execute function oyun.tg_olay_gece_gizle();

-- Her dakika: planı hazırla, eşiklerde bildirim gönder
create or replace function oyun.secim_gecesi_tick() returns int
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); s oyun.secimler; g oyun.secim_gecesi; n int := 0;
        gecen numeric; hedef int; oz jsonb; baslik text; govde text; kisa text;
begin
  for s in select * from oyun.secimler
           where tur in ('mv','cb','cb2') and t >= oy_bit and t < sonuc_at + interval '2 hours' loop
    perform oyun.secim_gecesi_hazirla(s.id);
  end loop;
  for g in select * from oyun.secim_gecesi
           where oyun.secim_gecesi_gecen(secim_id) >= 0
             and oyun.secim_gecesi_gecen(secim_id) < sure_sn + 300 and asama < 4 loop
    select * into s from oyun.secimler where id = g.secim_id;
    continue when s.durum = 'bekliyor';          -- sonuç henüz yazılmadıysa bekle
    gecen := oyun.secim_gecesi_gecen(g.secim_id);
    hedef := case when gecen >= g.sure_sn then 4 when gecen >= g.sure_sn * .75 then 3
                  when gecen >= g.sure_sn * .5 then 2 when gecen >= g.sure_sn * .25 then 1 else 0 end;
    continue when hedef <= g.asama;
    oz := oyun.secim_gecesi_ozet(g.secim_id);
    kisa := case s.tur when 'mv' then 'Genel seçim' when 'cb2' then 'Cumhurbaşkanlığı 2. tur' else 'Cumhurbaşkanlığı' end;
    baslik := case hedef when 0 then kisa || ': sayım başladı'
                         when 4 then kisa || ': sayım tamamlandı'
                         else kisa || ': sayımın %' || (hedef * 25) || '''i tamam' end;
    govde := case hedef when 0 then 'Sandıklar il il açılıyor. Canlı sonuçları izlemek için dokun.'
                        else (oz->>'acilan_il') || '/' || (oz->>'toplam_il') || ' il açıldı'
                             || coalesce('. Önde: ' || (oz->>'onde'), '') || '.' end;
    if s.tur in ('mv','cb2') then
      perform oyun.push_konuya('s_tum', null, baslik, govde,
                               jsonb_build_object('ekran', 'secim', 'id', s.id));
    end if;
    if hedef between 1 and 3 and s.tur in ('mv','cb2') then
      perform oyun.olay('secim', 'Seçim gecesi · ' || baslik || ' · ' || govde);
    end if;
    update oyun.secim_gecesi set asama = hedef where secim_id = g.secim_id;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function public.secim_gecesi(bigint), public.secim_gecesi_aktif(), public.secim_detay(bigint)
  from public, anon;
grant execute on function public.secim_gecesi(bigint), public.secim_gecesi_aktif(), public.secim_detay(bigint)
  to authenticated;

-- Sayım zamanlayıcısı (yalnız pg_cron olan Supabase'de)
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'secim-gecesi';
    perform cron.schedule('secim-gecesi', '* * * * *', 'select oyun.secim_gecesi_tick()');
  end if;
end $$;

-- ===== Boş makam fırsat bildirimi (77_bos_makam_firsat.sql) =====
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 77) BOŞ MAKAM FIRSAT BİLDİRİMİ
--  Boş bir belediye, milletvekili sandalyesi, genel başkanlık ya da genel başkan yardımcılığı
--  varsa ve oyuncu o işe bugün gerçekten talip olabiliyorsa, ona bildirim gider.
--   • Yalnız GERÇEK bir fırsatta: aday adaylığı açıkken ya da hemen üstlenilebilen genel başkanlıkta.
--   • Sınır: oyuncuya günde en fazla 1 fırsat bildirimi, aynı fırsat 3 günde bir, bir taramada en çok 300 kişi.
--   • Tarama 3 saatte bir, yalnız 09:00–21:59 arası (gece telefonu çalmaz).
--   • Bildirim oyuncunun "kişisel" bildirim tercihine uyar (oyun.bildir → push).
--  Gündem'deki "Fırsatlar" kartı aynı kaynaktan okur: public.bos_makam_firsatlari().
--  Yalnız yeni tablo ve işlev ekler; mevcut hiçbir şeyi değiştirmez.
-- =====================================================================

create table if not exists oyun.firsat_bildirim(
  user_id  uuid not null,
  tur      text not null,
  anahtar  text not null,
  zaman    timestamptz not null default now(),
  primary key (user_id, tur, anahtar)
);
create index if not exists firsat_bildirim_zaman on oyun.firsat_bildirim(user_id, zaman desc);
alter table oyun.firsat_bildirim enable row level security;
revoke all on oyun.firsat_bildirim from public, anon, authenticated;

create table if not exists oyun.firsat_durum(
  id boolean primary key default true check (id),
  son timestamptz
);
insert into oyun.firsat_durum(id, son) values (true, null) on conflict do nothing;
alter table oyun.firsat_durum enable row level security;
revoke all on oyun.firsat_durum from public, anon, authenticated;

-- Fırsat adayları: (oyuncu, tür, anahtar, metin, ekran). p_user doluysa yalnız o oyuncu için.
create or replace function oyun.firsat_adaylari(p_user uuid default null)
returns table(user_id uuid, tur text, anahtar text, metin text, ekran text)
language plpgsql stable as $$
declare t timestamptz := oyun.simdi(); bel oyun.secimler; mv oyun.secimler;
begin
  select * into bel from oyun.secimler s
   where s.tur = 'bel_on' and s.durum = 'bekliyor' and s.basvuru_bas <= t and s.basvuru_bit > t
   order by s.basvuru_bit limit 1;
  select * into mv from oyun.secimler s
   where s.tur = 'mv_on' and s.durum = 'bekliyor' and s.basvuru_bas <= t and s.basvuru_bit > t
   order by s.basvuru_bit limit 1;

  -- 1) Belediye başkanlığı boş ve aday adaylığı açık
  if bel.id is not null then
    return query
    select pr.id, 'belediye'::text, 'bel:' || il.id, format('%s belediye başkanlığı boş. Aday adaylığı %s tarihine kadar açık.',
             il.ad, to_char(bel.basvuru_bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), 'gundem'::text
      from oyun.profiller pr join oyun.iller il on il.id = pr.il_id
     where (p_user is null or pr.id = p_user) and not pr.yasakli
       and not exists (select 1 from oyun.makamlar m where m.tur = 'bel' and m.il_id = il.id and m.bit is null)
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur in ('mv','bel','cb'))
       and not exists (select 1 from oyun.adaylar a where a.secim_id = bel.id and a.user_id = pr.id);
  end if;

  -- 2) Milletvekili sandalyesi boş ve aday adaylığı açık
  if mv.id is not null then
    return query
    select pr.id, 'vekil'::text, 'mv:' || il.id, format('%s için %s milletvekili sandalyesi boş. Aday adaylığı %s tarihine kadar açık.',
             il.ad, il.mv_secim - c.n, to_char(mv.basvuru_bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), 'gundem'::text
      from oyun.profiller pr join oyun.iller il on il.id = pr.il_id
      cross join lateral (select count(*)::int n from oyun.makamlar m where m.tur = 'mv' and m.il_id = il.id and m.bit is null) c
     where (p_user is null or pr.id = p_user) and not pr.yasakli and il.mv_secim > c.n
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur in ('mv','bel','cb'))
       and not exists (select 1 from oyun.adaylar a where a.secim_id = mv.id and a.user_id = pr.id);
  end if;

  -- 3) Genel başkansız parti: üyeler hemen üstlenebilir
  return query
  select pr.id, 'genel_baskan'::text, 'gb:' || pa.id, format('%s genel başkansız. Genel başkanlığı hemen üstlenebilirsin.', pa.ad), 'parti'::text
    from oyun.profiller pr join oyun.partiler pa on pa.id = pr.parti_id
   where (p_user is null or pr.id = p_user) and not pr.yasakli and not pa.kapali and pa.gb is null
     and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur = 'cb');

  -- 4) Genel başkan yardımcısı kadrosu eksik: yalnız genel başkana
  return query
  select pa.gb, 'yardimci'::text, 'gby:' || pa.id, format('%s genel başkan yardımcısı kadrosunda %s yer boş. Üyelerinden atayabilirsin.', pa.ad, 6 - c.n), 'parti'::text
    from oyun.partiler pa
    cross join lateral (select count(*)::int n from oyun.parti_gby g where g.parti_id = pa.id) c
   where pa.gb is not null and not pa.kapali and c.n < 6 and (p_user is null or pa.gb = p_user)
     and (select count(*) from oyun.profiller x where x.parti_id = pa.id and x.id <> pa.gb and not x.yasakli) > c.n;
end $$;
revoke all on function oyun.firsat_adaylari(uuid) from public, anon, authenticated;

-- Tarama: kuyruğa bildirim bırakır
create or replace function oyun.bos_makam_firsat_tick() returns integer
language plpgsql set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); saat int := extract(hour from t at time zone 'Europe/Istanbul')::int; r record; n int := 0;
begin
  if saat < 9 or saat >= 22 then return 0; end if;
  if not pg_try_advisory_xact_lock(424243) then return 0; end if;
  if (select son from oyun.firsat_durum where id) > t - interval '3 hours' then return 0; end if;
  update oyun.firsat_durum set son = t where id;
  delete from oyun.firsat_bildirim where zaman < t - interval '14 days';
  for r in select * from oyun.firsat_adaylari(null) f order by random() loop
    continue when exists (select 1 from oyun.firsat_bildirim b where b.user_id = r.user_id and (b.zaman > t - interval '20 hours'
                  or (b.tur = r.tur and b.anahtar = r.anahtar and b.zaman > t - interval '3 days')));
    insert into oyun.firsat_bildirim(user_id, tur, anahtar, zaman) values (r.user_id, r.tur, r.anahtar, t)
      on conflict (user_id, tur, anahtar) do update set zaman = excluded.zaman;
    perform oyun.bildir(r.user_id, r.metin, t);
    n := n + 1; exit when n >= 300;
  end loop;
  return n;
end $$;
revoke all on function oyun.bos_makam_firsat_tick() from public, anon, authenticated;

-- Gündem kartı
create or replace function public.bos_makam_firsatlari() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('tur', f.tur, 'anahtar', f.anahtar, 'metin', f.metin, 'ekran', f.ekran) order by f.tur, f.anahtar), '[]'::jsonb)
    from oyun.firsat_adaylari(oyun.ben()) f
$$;
revoke all on function public.bos_makam_firsatlari() from public, anon;
grant execute on function public.bos_makam_firsatlari() to authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'bos-makam-firsat';
    perform cron.schedule('bos-makam-firsat', '*/30 * * * *', 'select oyun.bos_makam_firsat_tick()');
  end if;
end $$;

-- ===== Kısa paylaşım akışı ve gündem etiketleri (78_akis.sql) =====
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 78) KISA PAYLAŞIM AKIŞI VE GÜNDEM ETİKETLERİ
--  Oyuncular en çok 280 karakterlik kısa paylaşım yapar, #etiket kullanır; "Gündemdeki etiketler"
--  son 24 saatte en çok kişinin kullandığı etiketleri gösterir. Mevcut sohbet/propaganda sistemine dokunmaz.
--  Güvenlik (mağaza kuralları gereği): şikâyet et, kullanıcıyı engelle (mevcut engel listesi geçerli),
--  3 ayrı şikâyette gönderi otomatik gizlenir, moderatör "şikâyet" yetkisiyle karar verir,
--  küfür süzgeci + bağlantı yasağı + susturma + hız sınırı (20 sn arayla, günde 30 paylaşım).
-- =====================================================================

create table if not exists oyun.akis(
  id       bigserial primary key,
  user_id  uuid not null,
  metin    text not null check (length(metin) between 1 and 280),
  zaman    timestamptz not null default now(),
  il_id    smallint,
  parti_id bigint,
  gizli    boolean not null default false
);
create index if not exists akis_zaman on oyun.akis(id desc) where not gizli;
create index if not exists akis_kullanici on oyun.akis(user_id, zaman desc);

create table if not exists oyun.akis_etiket(
  akis_id bigint not null references oyun.akis(id) on delete cascade,
  etiket  text not null,
  zaman   timestamptz not null default now(),
  user_id uuid not null,
  primary key (akis_id, etiket)
);
create index if not exists akis_etiket_ara on oyun.akis_etiket(etiket, akis_id desc);
create index if not exists akis_etiket_zaman on oyun.akis_etiket(zaman);

create table if not exists oyun.akis_begeni(
  akis_id bigint not null references oyun.akis(id) on delete cascade,
  user_id uuid not null,
  zaman   timestamptz not null default now(),
  primary key (akis_id, user_id)
);

create table if not exists oyun.akis_sikayet(
  akis_id   bigint not null references oyun.akis(id) on delete cascade,
  sikayetci uuid not null,
  neden     text not null,
  zaman     timestamptz not null default now(),
  durum     text not null default 'yeni' check (durum in ('yeni','incelendi')),
  primary key (akis_id, sikayetci)
);

alter table oyun.akis enable row level security;
alter table oyun.akis_etiket enable row level security;
alter table oyun.akis_begeni enable row level security;
alter table oyun.akis_sikayet enable row level security;
revoke all on oyun.akis, oyun.akis_etiket, oyun.akis_begeni, oyun.akis_sikayet from public, anon, authenticated;
revoke all on sequence oyun.akis_id_seq from public, anon, authenticated;

-- Metindeki etiketler (küçük harf, en çok 5)
create or replace function oyun.akis_etiketleri(m text) returns text[]
language sql immutable as $$
  select coalesce((select array_agg(e order by ilk) from (
           select lower(x[1]) e, min(ord) ilk
             from regexp_matches(m, '#([[:alnum:]_]{2,30})', 'g') with ordinality as r(x, ord)
            group by lower(x[1]) order by min(ord) limit 5) q), '{}'::text[])
$$;

create or replace function oyun.akis_json(a oyun.akis, ben uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', a.id, 'kad', pr.kad, 'unvan', oyun.unvan(a.user_id), 'parti', oyun.parti_json(a.parti_id),
           'il', (select ad from oyun.iller where id = a.il_id), 'metin', a.metin, 'zaman', a.zaman,
           'begeni', (select count(*) from oyun.akis_begeni b where b.akis_id = a.id),
           'begendim', exists (select 1 from oyun.akis_begeni b where b.akis_id = a.id and b.user_id = ben),
           'benim', a.user_id = ben)
  from oyun.profiller pr where pr.id = a.user_id
$$;

create or replace function public.akis_yaz(p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m text; id0 bigint; e text;
begin
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 280);
  if m ~* '(https?://|www\.|\.com\b|\.net\b|\.org\b|t\.me/)' then raise exception 'Paylaşımlarda bağlantı kullanılamaz.'; end if;
  if exists (select 1 from oyun.akis where user_id = p.id and zaman > t - interval '20 seconds') then
    raise exception 'Çok sık paylaşıyorsun, biraz bekle.';
  end if;
  if (select count(*) from oyun.akis where user_id = p.id and zaman > t - interval '24 hours') >= 30 then
    raise exception 'Bugünlük paylaşım hakkın doldu; yarın yine yazabilirsin.';
  end if;
  if exists (select 1 from oyun.akis where user_id = p.id and zaman > t - interval '1 day' and lower(metin) = lower(m)) then
    raise exception 'Aynı paylaşımı tekrar yapamazsın.';
  end if;
  insert into oyun.akis(user_id, metin, zaman, il_id, parti_id) values (p.id, m, t, p.il_id, p.parti_id) returning id into id0;
  foreach e in array oyun.akis_etiketleri(m) loop
    insert into oyun.akis_etiket(akis_id, etiket, zaman, user_id) values (id0, e, t, p.id) on conflict do nothing;
  end loop;
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true, 'id', id0);
end $$;

create or replace function public.akis_liste(p_kapsam text default 'herkes', p_etiket text default null, p_onceki bigint default null, p_limit int default 20)
returns jsonb language plpgsql stable security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); et text := nullif(lower(regexp_replace(coalesce(p_etiket, ''), '^#', '')), '');
begin
  if p_kapsam not in ('herkes', 'il', 'parti') then raise exception 'Geçersiz kapsam.'; end if;
  return coalesce((select jsonb_agg(oyun.akis_json(a, p.id) order by a.id desc) from (
    select * from oyun.akis a
     where not a.gizli and (p_onceki is null or a.id < p_onceki)
       and (p_kapsam <> 'il' or a.il_id = p.il_id) and (p_kapsam <> 'parti' or (p.parti_id is not null and a.parti_id = p.parti_id))
       and (et is null or exists (select 1 from oyun.akis_etiket e where e.akis_id = a.id and e.etiket = et))
       and not exists (select 1 from oyun.engellemeler g where (g.engelleyen = p.id and g.engellenen = a.user_id) or (g.engelleyen = a.user_id and g.engellenen = p.id))
     order by a.id desc limit least(greatest(coalesce(p_limit, 20), 1), 40)) a), '[]'::jsonb);
end $$;

-- Gündemdeki etiketler: son 24 saat, en az 2 farklı kişi
create or replace function public.akis_gundem() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('etiket', x.etiket, 'kisi', x.kisi, 'paylasim', x.n) order by x.kisi desc, x.n desc, x.etiket), '[]'::jsonb)
  from (select e.etiket, count(distinct e.user_id) kisi, count(*) n
          from oyun.akis_etiket e join oyun.akis a on a.id = e.akis_id and not a.gizli
         where e.zaman > oyun.simdi() - interval '24 hours'
         group by e.etiket having count(distinct e.user_id) >= 2
         order by count(distinct e.user_id) desc, count(*) desc, e.etiket limit 8) x
$$;

create or replace function public.akis_begen(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); n int;
begin
  if not exists (select 1 from oyun.akis where id = p_id and not gizli) then raise exception 'Paylaşım bulunamadı.'; end if;
  if exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id) then
    delete from oyun.akis_begeni where akis_id = p_id and user_id = p.id;
  else
    if (select count(*) from oyun.akis_begeni where user_id = p.id and zaman > t - interval '1 minute') >= 20 then
      raise exception 'Çok hızlı beğeniyorsun, biraz bekle.';
    end if;
    insert into oyun.akis_begeni(akis_id, user_id, zaman) values (p_id, p.id, t);
  end if;
  select count(*) into n from oyun.akis_begeni where akis_id = p_id;
  return jsonb_build_object('begeni', n, 'begendim', exists (select 1 from oyun.akis_begeni where akis_id = p_id and user_id = p.id));
end $$;

create or replace function public.akis_sil(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  delete from oyun.akis where id = p_id and user_id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.akis_sikayet_et(p_id bigint, p_neden text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); hedef uuid; n int;
begin
  if p_neden not in ('hakaret','nefret','spam','taciz','uygunsuz','diger') then raise exception 'Geçersiz şikâyet nedeni.'; end if;
  select user_id into hedef from oyun.akis where id = p_id;
  if hedef is null then raise exception 'Paylaşım bulunamadı.'; end if;
  if hedef = p.id then raise exception 'Kendi paylaşımını şikâyet edemezsin.'; end if;
  insert into oyun.akis_sikayet(akis_id, sikayetci, neden, zaman) values (p_id, p.id, p_neden, t) on conflict do nothing;
  select count(distinct sikayetci) into n from oyun.akis_sikayet where akis_id = p_id;
  if n >= 3 then update oyun.akis set gizli = true where id = p_id; end if;
  select count(distinct s.sikayetci) into n from oyun.akis_sikayet s join oyun.akis a on a.id = s.akis_id
   where a.user_id = hedef and s.zaman > t - interval '24 hours';
  if n >= 8 then
    update oyun.profiller set susturma_bitis = greatest(coalesce(susturma_bitis, t), t + interval '24 hours') where id = hedef;
  end if;
  return jsonb_build_object('tamam', true);
end $$;

-- Moderatör: şikâyet edilen paylaşımlar
create or replace function public.admin_akis_sikayetleri() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  return coalesce((select jsonb_agg(x order by x->>'ilk' desc) from (
    select jsonb_build_object('id', a.id, 'kad', pr.kad, 'metin', a.metin, 'gizli', a.gizli, 'sayi', count(distinct s.sikayetci),
             'nedenler', jsonb_agg(distinct s.neden), 'ilk', min(s.zaman)) x
      from oyun.akis_sikayet s join oyun.akis a on a.id = s.akis_id join oyun.profiller pr on pr.id = a.user_id
     where s.durum = 'yeni' group by a.id, pr.kad, a.metin, a.gizli limit 100) q), '[]'::jsonb);
end $$;

create or replace function public.admin_akis_karar(p_id bigint, p_islem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); h oyun.profiller; a oyun.akis;
begin
  if p_islem not in ('yok_say', 'gizle', 'gizle_sustur1') then raise exception 'Geçersiz işlem.'; end if;
  select * into a from oyun.akis where id = p_id;
  if a.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  select * into h from oyun.profiller where id = a.user_id;
  if p_islem <> 'yok_say' then perform oyun.korunan_hedef(p, h.id); end if;
  perform oyun.mod_log(p, 'akis_' || p_islem, h.kad, a.metin);
  if p_islem = 'yok_say' then update oyun.akis set gizli = false where id = p_id; else update oyun.akis set gizli = true where id = p_id; end if;
  if p_islem = 'gizle_sustur1' then
    if not oyun.yetkili(p.id, 'sustur') then raise exception 'Susturma yetkin yok; yalnızca "Gizle" diyebilirsin.'; end if;
    update oyun.profiller set susturma_bitis = oyun.simdi() + interval '1 day' where id = h.id;
    perform oyun.bildir(h.id, 'Topluluk kurallarını ihlal eden bir paylaşımın kaldırıldı ve hesabın bir süre mesaj gönderemeyecek.');
  end if;
  update oyun.akis_sikayet set durum = 'incelendi' where akis_id = p_id;
  return public.admin_akis_sikayetleri();
end $$;

-- Eski paylaşımları temizle (30 gün); günlük özet işi (79) çağırır
create or replace function oyun.akis_temizle() returns void language sql as $$
  delete from oyun.akis where zaman < oyun.simdi() - interval '30 days'
$$;
revoke all on function oyun.akis_temizle() from public, anon, authenticated;

revoke all on function public.akis_yaz(text), public.akis_liste(text, text, bigint, int), public.akis_gundem(), public.akis_begen(bigint),
  public.akis_sil(bigint), public.akis_sikayet_et(bigint, text), public.admin_akis_sikayetleri(), public.admin_akis_karar(bigint, text)
  from public, anon;
grant execute on function public.akis_yaz(text), public.akis_liste(text, text, bigint, int), public.akis_gundem(), public.akis_begen(bigint),
  public.akis_sil(bigint), public.akis_sikayet_et(bigint, text), public.admin_akis_sikayetleri(), public.admin_akis_karar(bigint, text)
  to authenticated;

-- ===== Başarımlar, ay raporu, gün sonu özeti (79_basarim_rapor_gun_ozeti.sql) =====
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 79) BAŞARIMLAR, AY SONU RAPOR KARTI, GÜN SONU ÖZETİ
--  • Başarımlar: oyuncunun zaten yaptığı şeylerden (makam, parti, paylaşım, kıdem) türetilir; yeni kural koymaz.
--  • Ay sonu raporu: o ayın kısa dökümü + paylaşılabilir metin; ayın son günü 20:00'de bildirim gider.
--  • Gün sonu özeti: her akşam 21:00'de "Bugün Türkiye'de" bildirimi (en önemli 3 gelişme).
--  Yalnız yeni tablo ve işlev ekler.
-- =====================================================================

create table if not exists oyun.basarim(
  user_id uuid not null,
  kod     text not null,
  zaman   timestamptz not null default now(),
  bildirildi boolean not null default false,
  primary key (user_id, kod)
);
create table if not exists oyun.rapor_bildirim(
  user_id uuid not null,
  ay      date not null,
  primary key (user_id, ay)
);
create table if not exists oyun.gun_ozeti_gonderim(
  gun date primary key,
  zaman timestamptz not null default now(),
  metin text
);
alter table oyun.basarim enable row level security;
alter table oyun.rapor_bildirim enable row level security;
alter table oyun.gun_ozeti_gonderim enable row level security;
revoke all on oyun.basarim, oyun.rapor_bildirim, oyun.gun_ozeti_gonderim from public, anon, authenticated;

-- Başarım tanımları ve oyuncunun durumu
create or replace function oyun.basarim_durum(u uuid)
returns table(kod text, ad text, aciklama text, sinif text, sira int, kazandi boolean)
language plpgsql stable as $$
declare t timestamptz := oyun.simdi(); hesap timestamptz; n_akis int; n_begeni int; mv_gun numeric;
begin
  select pr.olusturma into hesap from oyun.profiller pr where pr.id = u;
  select count(*) into n_akis from oyun.akis where user_id = u;
  select count(*) into n_begeni from oyun.akis_begeni b join oyun.akis a on a.id = b.akis_id where a.user_id = u and b.user_id <> u;
  select coalesce(sum(extract(epoch from coalesce(m.bit, t) - m.bas) / 86400), 0) into mv_gun from oyun.makamlar m where m.user_id = u and m.tur = 'mv';
  return query select * from (values
    ('yerlesik',   'Yerleşik Vatandaş',  'Hesabın 7 günü geçti.',                                'bronz', 1, hesap is not null and hesap <= t - interval '7 days'),
    ('koklu',      'Köklü Vatandaş',     'Hesabın 30 günü geçti.',                               'gumus', 2, hesap is not null and hesap <= t - interval '30 days'),
    ('ilk_soz',    'İlk Söz',            'İlk kısa paylaşımını yaptın.',                         'bronz', 3, n_akis >= 1),
    ('gundem',     'Gündem Belirleyici', '25 paylaşıma ulaştın.',                                'gumus', 4, n_akis >= 25),
    ('sesini',     'Sesini Duyuran',     'Paylaşımların 50 beğeni topladı.',                     'gumus', 5, n_begeni >= 50),
    ('kurucu',     'Parti Kurucusu',     'Bir parti kurdun.',                                    'gumus', 6, exists (select 1 from oyun.partiler pa where pa.kurucu = u)),
    ('genel_baskan','Genel Başkan',      'Bir partinin genel başkanısın.',                       'gumus', 7, exists (select 1 from oyun.partiler pa where pa.gb = u and not pa.kapali)),
    ('vekil',      'Meclis Kürsüsü',     'Milletvekili seçildin.',                               'gumus', 8, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv')),
    ('belediye',   'Şehrin Başkanı',     'Belediye başkanı seçildin.',                           'gumus', 9, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bel')),
    ('bakan',      'Kabine Üyesi',       'Bakan oldun.',                                         'altin', 10, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bakan')),
    ('kidemli',    'Kıdemli Vekil',      'Meclis''te toplam 30 gün görev yaptın.',               'altin', 11, mv_gun >= 30),
    ('cumhurbaskani','Çankaya',          'Cumhurbaşkanı seçildin.',                              'altin', 12, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'cb'))
  ) v(kod, ad, aciklama, sinif, sira, kazandi);
end $$;
revoke all on function oyun.basarim_durum(uuid) from public, anon, authenticated;

-- Kazanılanları kaydeder; yeni kazanılanların kodlarını döndürür
create or replace function oyun.basarim_tara(u uuid) returns text[]
language plpgsql as $$
declare yeni text[];
begin
  with e as (
    insert into oyun.basarim(user_id, kod, zaman)
    select u, d.kod, oyun.simdi() from oyun.basarim_durum(u) d where d.kazandi
    on conflict do nothing returning kod)
  select coalesce(array_agg(kod), '{}') into yeni from e;
  return yeni;
end $$;
revoke all on function oyun.basarim_tara(uuid) from public, anon, authenticated;

create or replace function public.basarimlar() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  perform oyun.basarim_tara(p.id);
  return coalesce((select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'aciklama', d.aciklama, 'sinif', d.sinif,
           'kazandi', b.user_id is not null, 'zaman', b.zaman) order by d.sira)
     from oyun.basarim_durum(p.id) d left join oyun.basarim b on b.user_id = p.id and b.kod = d.kod), '[]'::jsonb);
end $$;

-- Ay raporu (p_ay verilmezse içinde bulunulan ay)
create or replace function public.ay_raporu(p_ay date default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
  ay0 date := date_trunc('month', coalesce(p_ay, (t at time zone 'Europe/Istanbul')::date))::date;
  b timestamptz; s timestamptz; paylasim int; begeni int; gun numeric; yeni jsonb; makamlar jsonb; vekil int; sira int; unv text; basarim_n int;
  adlar text[] := array['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  metin text;
begin
  b := (ay0::timestamp) at time zone 'Europe/Istanbul'; s := ((ay0 + interval '1 month')::timestamp) at time zone 'Europe/Istanbul';
  perform oyun.basarim_tara(p.id);
  select count(*) into paylasim from oyun.akis where user_id = p.id and zaman >= b and zaman < s;
  select count(*) into begeni from oyun.akis_begeni x join oyun.akis a on a.id = x.akis_id
   where a.user_id = p.id and x.user_id <> p.id and x.zaman >= b and x.zaman < s;
  select coalesce(sum(extract(epoch from least(coalesce(m.bit, s), s) - greatest(m.bas, b)) / 86400), 0) into gun
    from oyun.makamlar m where m.user_id = p.id and m.bas < s and coalesce(m.bit, s) > b;
  select coalesce(jsonb_agg(jsonb_build_object('tur', m.tur, 'il', (select ad from oyun.iller where id = m.il_id), 'bas', m.bas) order by m.bas), '[]'::jsonb)
    into makamlar from oyun.makamlar m where m.user_id = p.id and m.bas >= b and m.bas < s;
  select coalesce(jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'sinif', d.sinif) order by d.sira), '[]'::jsonb) into yeni
    from oyun.basarim x join oyun.basarim_durum(p.id) d on d.kod = x.kod where x.user_id = p.id and x.zaman >= b and x.zaman < s;
  select count(*) into basarim_n from oyun.basarim where user_id = p.id;
  if p.parti_id is not null then
    select count(*) into vekil from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = p.parti_id;
    select r into sira from (select pa.id, row_number() over (order by (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id) desc, pa.id) r
                               from oyun.partiler pa where not pa.kapali) q where q.id = p.parti_id;
  end if;
  unv := oyun.unvan(p.id);
  metin := format('%s %s raporum: %s%s%s paylaşım, %s beğeni, %s başarım. Seçim Simülasyonu Online',
     adlar[extract(month from ay0)::int], extract(year from ay0)::int,
     case when unv is not null then unv || ' · ' else '' end,
     case when p.parti_id is not null then (select kisa from oyun.partiler where id = p.parti_id) || ' · ' else '' end,
     paylasim, begeni, basarim_n);
  return jsonb_build_object('ay', to_char(ay0, 'YYYY-MM'), 'ay_ad', adlar[extract(month from ay0)::int] || ' ' || extract(year from ay0)::int,
    'kad', p.kad, 'unvan', unv, 'il', (select ad from oyun.iller where id = p.il_id), 'parti', oyun.parti_json(p.parti_id),
    'parti_vekil', vekil, 'parti_sira', sira, 'paylasim', paylasim, 'begeni', begeni, 'makam_gun', round(gun, 1),
    'yeni_makamlar', makamlar, 'yeni_basarimlar', yeni, 'basarim_toplam', basarim_n, 'paylasim_metni', metin,
    'son_gun', ((s - interval '1 second') at time zone 'Europe/Istanbul')::date);
end $$;

-- "Bugün Türkiye'de": bugünün en önemli gelişmeleri (Gündem kartı + akşam bildirimi)
create or replace function oyun.gun_ozeti_liste(p_gun date) returns jsonb
language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('tur', x.tur, 'metin', x.metin, 'zaman', x.zaman) order by x.oncelik, x.zaman desc), '[]'::jsonb)
  from (select o.tur, o.metin, o.zaman,
               case o.tur when 'secim' then 1 when 'hukumet' then 2 when 'anayasa' then 2 when 'referandum' then 2 when 'meclis' then 3 when 'makam' then 3
                          when 'kararname' then 4 when 'parti' then 5 when 'ittifak' then 5 when 'belediye' then 6 when 'siyaset' then 6 else 8 end oncelik
          from oyun.olaylar o
         where o.zaman >= (p_gun::timestamp) at time zone 'Europe/Istanbul' and o.zaman < ((p_gun + 1)::timestamp) at time zone 'Europe/Istanbul'
           and o.zaman <= oyun.simdi() and o.metin not like 'Seçim gecesi ·%'
         order by 4, o.zaman desc limit 6) x
$$;

create or replace function public.gun_ozeti() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object('gun', (oyun.simdi() at time zone 'Europe/Istanbul')::date,
    'gelismeler', oyun.gun_ozeti_liste((oyun.simdi() at time zone 'Europe/Istanbul')::date),
    'etiketler', (select coalesce(jsonb_agg(e->>'etiket'), '[]'::jsonb) from jsonb_array_elements(public.akis_gundem()) e))
$$;

-- Günlük iş: 21:00'den sonra bir kez özet bildirimi; ayın son günü 20:00'den sonra rapor bildirimi; başarım taraması
create or replace function oyun.gun_sonu_tick() returns integer
language plpgsql set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); yerel timestamp := t at time zone 'Europe/Istanbul'; bugun date := yerel::date; saat int := extract(hour from yerel)::int;
  liste jsonb; govde text; n int := 0; u record; yeni text[]; ay0 date;
begin
  if not pg_try_advisory_xact_lock(424244) then return 0; end if;

  -- 1) gün sonu özeti
  if saat >= 21 and not exists (select 1 from oyun.gun_ozeti_gonderim where gun = bugun) then
    liste := oyun.gun_ozeti_liste(bugun);
    insert into oyun.gun_ozeti_gonderim(gun, zaman) values (bugun, t) on conflict do nothing;
    if jsonb_array_length(liste) > 0 then
      govde := (select string_agg(left(x->>'metin', 90), ' · ') from (select x from jsonb_array_elements(liste) x limit 3) q);
      update oyun.gun_ozeti_gonderim set metin = govde where gun_ozeti_gonderim.gun = bugun;
      perform oyun.push_konuya('s_tum', null, 'Bugün Türkiye''de', govde, '{"ekran":"gundem"}');
      n := n + 1;
    end if;
    perform oyun.akis_temizle();
  end if;

  -- 2) ay raporu bildirimi (ayın son günü 20:00'den sonra, son 14 günde görülmüş oyunculara)
  ay0 := date_trunc('month', yerel)::date;
  if saat >= 20 and bugun = (ay0 + interval '1 month' - interval '1 day')::date then
    for u in select pr.id from oyun.profiller pr
              where not pr.yasakli and pr.son_gorulme > t - interval '14 days'
                and not exists (select 1 from oyun.rapor_bildirim r where r.user_id = pr.id and r.ay = ay0) limit 2000 loop
      insert into oyun.rapor_bildirim(user_id, ay) values (u.id, ay0) on conflict do nothing;
      perform oyun.push_kisiye(u.id, 'kisisel', 'Ay raporun hazır', 'Bu ayın özeti ve başarımların seni bekliyor.', '{"ekran":"rapor"}');
      n := n + 1;
    end loop;
  end if;

  -- 3) başarım taraması (günde bir kez, 03:00 sonrası) — yeni kazanılanlar tek bildirimle haber verilir
  if saat >= 3 and not exists (select 1 from oyun.basarim_tarama where gun = bugun) then
    insert into oyun.basarim_tarama(gun) values (bugun) on conflict do nothing;
    for u in select pr.id from oyun.profiller pr where not pr.yasakli and pr.son_gorulme > t - interval '30 days' loop
      yeni := oyun.basarim_tara(u.id);
      if array_length(yeni, 1) > 0 then
        update oyun.basarim set bildirildi = true where user_id = u.id and kod = any(yeni);
        perform oyun.bildir(u.id, 'Yeni başarım kazandın: ' || (select string_agg(d.ad, ', ') from oyun.basarim_durum(u.id) d where d.kod = any(yeni)));
        n := n + 1;
      end if;
    end loop;
  end if;
  return n;
end $$;
revoke all on function oyun.gun_sonu_tick() from public, anon, authenticated;

create table if not exists oyun.basarim_tarama(gun date primary key);
alter table oyun.basarim_tarama enable row level security;
revoke all on oyun.basarim_tarama from public, anon, authenticated;

revoke all on function public.basarimlar(), public.ay_raporu(date), public.gun_ozeti() from public, anon;
grant execute on function public.basarimlar(), public.ay_raporu(date), public.gun_ozeti() to authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'gun-sonu';
    perform cron.schedule('gun-sonu', '*/15 * * * *', 'select oyun.gun_sonu_tick()');
  end if;
end $$;

commit;
