begin;
-- =====================================================================
--  16.11.2026 · Aday belirleme yöntemi (ön seçim / Genel Başkan ataması),
--  gerçek D'Hondt + %7 ülke barajı, 7 kurucuyla parti kuruluşu
--
--  Gerçek mevzuat:
--   • 2820 s. SPK md.37: partiler adaylarını tüzüklerinde gösterdikleri usulle
--     belirler — üyelerin oyuyla ön seçim ya da merkez yoklaması (parti merkez
--     organının tespiti). 2024 yerel seçiminde 36 partinin tamamı merkez
--     yoklaması seçti. Oyunda merkez organı = Genel Başkan (oyun uyarlaması).
--   • 2839 s. MSK md.33-34 (7393 s. Kanunla): ülke barajı %7; ittifakın toplam
--     oyu %7'yi geçerse ittifaktaki partiler barajı geçmiş sayılır; sandalyeler
--     her ilde her partinin KENDİ oyuna göre D'Hondt ile dağıtılır; vekiller
--     liste sırasıyla belirlenir. Bağımsız aday ilde D'Hondt'a tek kişi girer.
--   • Belediye başkanı: en çok oyu alan aday kazanır (2972 s. Kanun).
--   • Gerçekte parti kurmak için 30 kurucu gerekir (SPK md.8); oyunda 7
--     (Ercan'ın oyun uyarlaması).
--  Oyuncu verisi silinmez; yeni tablo/sütun eklenir, mevcut partiler ön seçimde
--  kalır (Genel Başkan sonradan değiştirebilir).
-- =====================================================================

-- 1) Kurucu sayısı: sabit 7 (oyun nüfusuyla büyümez)
update oyun.tarife set deger = 7 where kod in ('parti_kurucu_min','parti_kurucu_max');
update oyun.ayarlar set parti_kurucu_sayi = 7 where id = 1;
-- Tek kişiyle anında parti kuran eski beta istisnaları kapanır (kayıtlar silinmez)
do $$ begin
  if to_regprocedure('public.eyetkin_parti_kur(text,text,text,text,text[])') is not null then
    revoke all on function public.eyetkin_parti_kur(text,text,text,text,text[]) from public, anon, authenticated;
  end if;
  if to_regprocedure('public.matestappen_parti_kur(text,text,text,text,text[])') is not null then
    revoke all on function public.matestappen_parti_kur(text,text,text,text,text[]) from public, anon, authenticated;
  end if;
end $$;

-- 2) Milletvekili test modu kapanır: her aday vekil olmaz, gerçek %7 + D'Hondt
insert into oyun.mv_secim_modu(id, her_aday_vekil, aciklama)
values (1, false, 'Gerçek seçim: parti veya ittifak toplamında %7 ülke barajı, illerde D''Hondt')
on conflict (id) do update set her_aday_vekil = false, aciklama = excluded.aciklama;

-- 3) Yöntem tablosu ve aday sütunları
create table if not exists oyun.parti_aday_yontem(
  parti_id   bigint primary key references oyun.partiler(id),
  mv         text not null default 'onsecim' check (mv in ('onsecim','atama')),
  bel        text not null default 'onsecim' check (bel in ('onsecim','atama')),
  belirlendi timestamptz not null default now(),
  belirleyen uuid
);
alter table oyun.parti_aday_yontem enable row level security;
revoke all on oyun.parti_aday_yontem from public, anon, authenticated;

alter table oyun.adaylar add column if not exists atama_sira int;
alter table oyun.adaylar add column if not exists atama_ekleme boolean not null default false;
alter table oyun.kurucu_basvuru add column if not exists mv_yontem text;
alter table oyun.kurucu_basvuru add column if not exists bel_yontem text;

create or replace function oyun.parti_yontem(p_parti bigint, p_tur text) returns text
language sql stable set search_path = '' as $$
  select coalesce((select case when p_tur in ('mv','mv_on') then y.mv else y.bel end
                   from oyun.parti_aday_yontem y where y.parti_id = p_parti), 'onsecim')
$$;

-- Yöntemin değiştirilemediği dönem: ilgili ön seçimin adaylık başvurusu açıldıktan
-- ön seçim sonuçlanana kadar (YSK'ya bildirilen usul sürecin ortasında değişmez).
create or replace function oyun.aday_yontem_kilit(p_tur text, t timestamptz) returns oyun.secimler
language sql stable set search_path = '' as $$
  select s.* from oyun.secimler s
  where s.tur = case when p_tur in ('mv','mv_on') then 'mv_on' else 'bel_on' end
    and s.durum = 'bekliyor' and s.basvuru_bas is not null and not s.ara
    and t >= s.basvuru_bas and t < s.oy_bit
  order by s.oy_bit limit 1
$$;

-- Atamanın yapılabileceği ön seçim (adaylık başvurusundan ön seçim bitişine kadar)
create or replace function oyun.aday_atama_secim(p_tur text, p_il smallint, t timestamptz) returns oyun.secimler
language sql stable set search_path = '' as $$
  select s.* from oyun.secimler s
  where s.tur = case when p_tur = 'mv' then 'mv_on' else 'bel_on' end
    and s.durum = 'bekliyor' and s.basvuru_bas is not null
    and t >= s.basvuru_bas and t < s.oy_bit
    and (not s.ara or s.hedef_il_id = p_il
         or (s.ara_neden = 'erken_secim' and s.hedef_parti_id is null and s.hedef_il_id is null))
  order by s.ara desc, s.oy_bit, s.id desc limit 1
$$;

-- 4) Ön seçimde oy engeli: atama usulündeki partide üye oylaması yapılmaz
create or replace function oyun.oy_engeli(p oyun.profiller, s oyun.secimler)
 returns text language sql stable set search_path to '' as $function$
 SELECT coalesce(
  oyun.uyari(p,s.oy_bas),
  CASE WHEN s.tur IN ('mv','cb','cb2','bel') THEN NULL::text ELSE oyun.ilk_uc_gorev_engel(p) END,
  CASE WHEN s.ara AND s.hedef_il_id IS NOT NULL AND p.il_id IS DISTINCT FROM s.hedef_il_id
    THEN format('Bu olağanüstü seçim yalnızca %s ili içindir.',
      (SELECT ad FROM oyun.iller WHERE id=s.hedef_il_id)) END,
  CASE WHEN s.ara AND s.hedef_parti_id IS NOT NULL AND p.parti_id IS DISTINCT FROM s.hedef_parti_id
    THEN format('Bu olağanüstü kurultay yalnızca %s üyeleri içindir.',
      (SELECT kisa FROM oyun.partiler WHERE id=s.hedef_parti_id)) END,
  CASE WHEN s.tur IN ('mv_on','bel_on') AND p.parti_id IS NOT NULL
            AND oyun.parti_yontem(p.parti_id, s.tur) = 'atama'
       THEN format('%s adaylarını Genel Başkan ataması (merkez yoklaması) ile belirliyor. Bu ön seçimde üye oylaması yapılmaz; %s Genel Başkan tarafından belirlenir.',
            coalesce((SELECT kisa FROM oyun.partiler WHERE id=p.parti_id), 'Partin'),
            CASE WHEN s.tur='mv_on' THEN 'il listeleri ve sıralama' ELSE 'belediye başkanı adayı' END) END,
  CASE WHEN s.tur IN ('mv','bel','mv_on','bel_on') AND p.son_il_degis IS NOT NULL
            AND p.il_at > s.oy_bas - make_interval(days=>(SELECT oy_il_gun FROM oyun.ayarlar WHERE id=1))
       THEN format('Seçmen kütüğü: bu ilde en az %s gün kayıtlı olmalısın.',
            (SELECT oy_il_gun FROM oyun.ayarlar WHERE id=1)) END,
  CASE WHEN s.tur IN ('mv_on','bel_on','kurultay','cb_on') THEN
    CASE WHEN p.parti_id IS NULL THEN 'Bu parti içi seçimde oy kullanmak için bir partiye üye olmalısın.'
         WHEN s.donem='2026-11' AND s.tur IN ('mv_on','cb_on') THEN NULL
         WHEN p.parti_at > oyun.onsecim_uyelik_kesim(s, p.parti_id)
         THEN format('%s üyesisin, ancak partiye %s tarihinde katıldın. Bu %s oy kullanabilmek için en geç %s itibarıyla üye olmak gerekiyordu. Bu kural, son anda partiye girip sonucu etkilemeyi önler; sonraki parti içi seçimlerde oy kullanabilirsin.',
              coalesce((SELECT kisa FROM oyun.partiler WHERE id=p.parti_id), 'Partinin'),
              oyun.tr_tarih_saat(p.parti_at),
              CASE WHEN s.tur='kurultay' THEN 'kurultayda' ELSE 'ön seçimde' END,
              oyun.tr_tarih_saat(oyun.onsecim_uyelik_kesim(s, p.parti_id))) END END)
$function$;

-- Sert koruma: hangi yoldan gelirse gelsin atama usulündeki partinin ön seçimine oy yazılmaz
create or replace function oyun.tg_onsecim_atama_oy() returns trigger
language plpgsql set search_path = '' as $$
declare tr text; pid bigint;
begin
  select tur into tr from oyun.secimler where id = new.secim_id;
  if tr in ('mv_on','bel_on') then
    pid := coalesce(new.parti_id, (select parti_id from oyun.profiller where id = new.secmen));
    if pid is not null and oyun.parti_yontem(pid, tr) = 'atama' then
      raise exception 'Partin adaylarını Genel Başkan ataması ile belirliyor; bu ön seçimde üye oylaması yapılmaz.';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists onsecim_atama_oy on oyun.oylar;
create trigger onsecim_atama_oy before insert on oyun.oylar
  for each row execute function oyun.tg_onsecim_atama_oy();

-- 5) Ön seçim sonuçları
-- Milletvekili: ön seçimli partide sıra = en çok oydan en aza; atamalı partide
-- sıra = Genel Başkanın sırası; atanmayan başvuru sahibi listeye girmez.
create or replace function oyun._sonuc_mv_on(s oyun.secimler)
 returns jsonb language plpgsql set search_path to '' as $function$
BEGIN
  PERFORM oyun.aday_oylarini_say(s.id);

  WITH siralama AS (
    SELECT a.id,
           row_number() OVER (
             PARTITION BY a.il_id, a.parti_id
             ORDER BY coalesce(a.oy, 0) DESC,
                      a.basvuru_at ASC NULLS LAST,
                      a.id ASC
           )::integer AS liste_sirasi
    FROM oyun.adaylar a
    WHERE a.secim_id = s.id
      AND (a.parti_id IS NULL OR oyun.parti_yontem(a.parti_id, 'mv') = 'onsecim')
  )
  UPDATE oyun.adaylar a
  SET sira = x.liste_sirasi
  FROM siralama x
  WHERE a.id = x.id;

  WITH atama AS (
    SELECT a.id,
           CASE WHEN a.atama_sira IS NULL THEN NULL
                ELSE row_number() OVER (PARTITION BY a.il_id, a.parti_id, (a.atama_sira IS NULL)
                                        ORDER BY a.atama_sira, a.id)::integer END AS liste_sirasi
    FROM oyun.adaylar a
    WHERE a.secim_id = s.id AND a.parti_id IS NOT NULL
      AND oyun.parti_yontem(a.parti_id, 'mv') = 'atama'
  )
  UPDATE oyun.adaylar a
  SET sira = x.liste_sirasi
  FROM atama x
  WHERE a.id = x.id;

  -- Atanmayan başvuru sahiplerine bilgi
  INSERT INTO oyun.bildirimler(user_id, zaman, metin)
  SELECT a.user_id, coalesce(s.sonuc_at, now()),
         'Partinin Genel Başkanı milletvekili aday listesine seni almadı; bu seçimde aday değilsin.'
  FROM oyun.adaylar a
  WHERE a.secim_id = s.id AND a.parti_id IS NOT NULL AND a.sira IS NULL
    AND oyun.parti_yontem(a.parti_id, 'mv') = 'atama';

  RETURN jsonb_build_object(
    'katilim', (SELECT count(*) FROM oyun.oylar WHERE secim_id = s.id),
    'aday',    (SELECT count(*) FROM oyun.adaylar WHERE secim_id = s.id AND sira IS NOT NULL),
    'liste',   (SELECT count(DISTINCT (il_id, parti_id))
                FROM oyun.adaylar WHERE secim_id = s.id AND sira IS NOT NULL),
    'atamali_parti', (SELECT count(DISTINCT parti_id) FROM oyun.adaylar
                      WHERE secim_id = s.id AND parti_id IS NOT NULL
                        AND oyun.parti_yontem(parti_id, 'mv') = 'atama')
  );
END
$function$;

-- Belediye başkanı (ve CB): ön seçimli partide en çok oyu alan aday; atamalı
-- partide Genel Başkanın atadığı aday. CB akışı değişmedi.
create or replace function oyun._sonuc_tek_kazanan_on(s oyun.secimler, p_hedef_tur text)
 returns jsonb language plpgsql set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $function$
declare hedef oyun.secimler; r record; n int := 0;
begin
  perform oyun.aday_oylarini_say(s.id);
  select * into hedef from oyun.secimler where tur = p_hedef_tur and donem = s.donem;
  for r in
    select distinct on (coalesce(il_id, 0), parti_id) *
    from oyun.adaylar
    where secim_id = s.id
      and (p_hedef_tur <> 'bel' or parti_id is null
           or oyun.parti_yontem(parti_id, 'bel') = 'onsecim'
           or atama_sira is not null)
    order by coalesce(il_id, 0), parti_id,
             case when p_hedef_tur = 'bel' and parti_id is not null
                       and oyun.parti_yontem(parti_id, 'bel') = 'atama' then atama_sira end nulls last,
             oy desc, basvuru_at, id
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
end $function$;

-- 6) Parti kuruluşunda seçilen yöntem kuruluş tamamlanınca partiye işlenir
create or replace function oyun.tg_kurucu_basvuru_yontem() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.parti_id is not null and old.parti_id is null
     and (new.mv_yontem is not null or new.bel_yontem is not null) then
    insert into oyun.parti_aday_yontem(parti_id, mv, bel, belirlendi, belirleyen)
    values (new.parti_id, coalesce(new.mv_yontem,'onsecim'), coalesce(new.bel_yontem,'onsecim'), now(), new.kurucu)
    on conflict (parti_id) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists kurucu_basvuru_yontem on oyun.kurucu_basvuru;
create trigger kurucu_basvuru_yontem after update of parti_id on oyun.kurucu_basvuru
  for each row execute function oyun.tg_kurucu_basvuru_yontem();

-- 7) RPC'ler
create or replace function public.parti_kur_aday_yontem(p_basvuru bigint, p_mv text, p_bel text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); b oyun.kurucu_basvuru;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_mv not in ('onsecim','atama') or p_bel not in ('onsecim','atama') then
    raise exception 'Aday belirleme yöntemi "ön seçim" ya da "Genel Başkan ataması" olmalı.'; end if;
  select * into b from oyun.kurucu_basvuru where id = p_basvuru for update;
  if b.id is null or b.kurucu <> p.id then raise exception 'Bu kuruluş başvurusu senin değil.'; end if;
  if b.parti_id is not null then raise exception 'Parti kuruldu; yöntemi Partiler › Aday belirleme ekranından değiştir.'; end if;
  update oyun.kurucu_basvuru set mv_yontem = p_mv, bel_yontem = p_bel where id = b.id;
  return jsonb_build_object('basvuru_id', b.id, 'mv', p_mv, 'bel', p_bel);
end $$;

create or replace function public.parti_aday_yontem_ayarla(p_mv text, p_bel text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler;
  eski_mv text; eski_bel text; k oyun.secimler; ad text;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_mv not in ('onsecim','atama') or p_bel not in ('onsecim','atama') then
    raise exception 'Aday belirleme yöntemi "ön seçim" ya da "Genel Başkan ataması" olmalı.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.id is null or pa.kapali then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id then raise exception 'Aday belirleme yöntemini yalnız Genel Başkan seçebilir.'; end if;
  eski_mv := oyun.parti_yontem(pa.id, 'mv'); eski_bel := oyun.parti_yontem(pa.id, 'bel');
  if p_mv <> eski_mv then
    k := oyun.aday_yontem_kilit('mv', t);
    if k.id is not null then
      raise exception 'Milletvekili adaylık süreci sürüyor (% sonuçlanacak). Yöntem, süreç başlamadan önce belirlenir; bu seçimden sonra değiştirebilirsin.', oyun.tr_tarih_saat(k.oy_bit); end if;
  end if;
  if p_bel <> eski_bel then
    k := oyun.aday_yontem_kilit('bel', t);
    if k.id is not null then
      raise exception 'Belediye başkanlığı adaylık süreci sürüyor (% sonuçlanacak). Yöntem, süreç başlamadan önce belirlenir; bu seçimden sonra değiştirebilirsin.', oyun.tr_tarih_saat(k.oy_bit); end if;
  end if;
  insert into oyun.parti_aday_yontem(parti_id, mv, bel, belirlendi, belirleyen)
  values (pa.id, p_mv, p_bel, t, p.id)
  on conflict (parti_id) do update set mv = excluded.mv, bel = excluded.bel, belirlendi = excluded.belirlendi, belirleyen = excluded.belirleyen;
  if p_mv <> eski_mv or p_bel <> eski_bel then
    ad := format('%s aday belirleme usulünü değiştirdi — Milletvekili: %s · Belediye başkanı: %s.', pa.kisa,
      case p_mv when 'atama' then 'Genel Başkan ataması' else 'ön seçim' end,
      case p_bel when 'atama' then 'Genel Başkan ataması' else 'ön seçim' end);
    perform oyun.olay('parti', ad, null, pa.id, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select id, t, ad from oyun.profiller where parti_id = pa.id and id <> p.id;
  end if;
  return public.parti_aday_panel();
end $$;

create or replace function public.parti_aday_panel() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler;
  smv oyun.secimler; sbel oyun.secimler; kmv oyun.secimler; kbel oyun.secimler; gb boolean;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.id is null or pa.kapali then return jsonb_build_object('parti', null); end if;
  gb := pa.gb = p.id;
  select * into smv from oyun.secimler where tur = 'mv_on' and durum = 'bekliyor' and not ara order by oy_bit limit 1;
  select * into sbel from oyun.secimler where tur = 'bel_on' and durum = 'bekliyor' and not ara order by oy_bit limit 1;
  kmv := oyun.aday_yontem_kilit('mv', t); kbel := oyun.aday_yontem_kilit('bel', t);
  return jsonb_build_object(
    'parti', jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk),
    'gb_mi', gb,
    'belirlendi', exists(select 1 from oyun.parti_aday_yontem where parti_id = pa.id),
    'mv', oyun.parti_yontem(pa.id, 'mv'), 'bel', oyun.parti_yontem(pa.id, 'bel'),
    'kilit_mv', case when kmv.id is not null then kmv.oy_bit end,
    'kilit_bel', case when kbel.id is not null then kbel.oy_bit end,
    'secim_mv', case when smv.id is not null then jsonb_build_object('id', smv.id, 'basvuru_bas', smv.basvuru_bas, 'basvuru_bit', smv.basvuru_bit, 'oy_bas', smv.oy_bas, 'oy_bit', smv.oy_bit,
                 'acik', t >= smv.basvuru_bas and t < smv.oy_bit) end,
    'secim_bel', case when sbel.id is not null then jsonb_build_object('id', sbel.id, 'basvuru_bas', sbel.basvuru_bas, 'basvuru_bit', sbel.basvuru_bit, 'oy_bas', sbel.oy_bas, 'oy_bit', sbel.oy_bit,
                 'acik', t >= sbel.basvuru_bas and t < sbel.oy_bit) end,
    'iller', case when gb then coalesce((
      select jsonb_agg(jsonb_build_object('il_id', i.id, 'ad', i.ad, 'mv', coalesce(i.mv_secim, i.mv),
        'uye', x.uye,
        'mv_basvuru', (select count(*) from oyun.adaylar a where a.secim_id = smv.id and a.parti_id = pa.id and a.il_id = i.id and not a.atama_ekleme),
        'mv_atanan', (select count(*) from oyun.adaylar a where a.secim_id = smv.id and a.parti_id = pa.id and a.il_id = i.id and a.atama_sira is not null),
        'bel_atanan', (select pr.kad from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
                       where a.secim_id = sbel.id and a.parti_id = pa.id and a.il_id = i.id and a.atama_sira is not null limit 1))
        order by x.uye desc, i.id)
      from (select il_id, count(*) uye from oyun.profiller where parti_id = pa.id and not yasakli group by il_id) x
      join oyun.iller i on i.id = x.il_id), '[]'::jsonb) end,
    'kural', 'Ön seçimde partinin o ildeki üyeleri oy verir; milletvekili listesi en çok oydan en aza sıralanır, belediye başkanlığında en çok oyu alan aday olur. Genel Başkan ataması seçilirse üye oylaması yapılmaz; listeyi ve sırayı Genel Başkan belirler (merkez yoklaması, SPK md.37). Yöntem adaylık süreci başlamadan önce değiştirilebilir.'
  );
end $$;

create or replace function public.parti_aday_il(p_tur text, p_il int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; il oyun.iller;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_tur not in ('mv','bel') then raise exception 'Geçersiz seçim türü.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Bu ekran yalnız Genel Başkana açık.'; end if;
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  s := oyun.aday_atama_secim(p_tur, p_il::smallint, t);
  return jsonb_build_object(
    'il_id', il.id, 'il_ad', il.ad, 'kontenjan', case when p_tur = 'mv' then coalesce(il.mv_secim, il.mv) else 1 end,
    'tur', p_tur, 'yontem', oyun.parti_yontem(pa.id, p_tur),
    'secim', case when s.id is not null then jsonb_build_object('id', s.id, 'basvuru_bit', s.basvuru_bit, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit) end,
    'uyeler', coalesce((
      select jsonb_agg(jsonb_build_object('kad', pr.kad, 'gb', pr.id = pa.gb,
        'basvurdu', a.id is not null and not a.atama_ekleme, 'atama_sira', a.atama_sira, 'oy', a.oy)
        order by a.atama_sira nulls last, (a.id is not null and not a.atama_ekleme) desc, pr.kad)
      from oyun.profiller pr
      left join oyun.adaylar a on a.secim_id = s.id and a.user_id = pr.id
      where pr.parti_id = pa.id and pr.il_id = il.id and not pr.yasakli), '[]'::jsonb)
  );
end $$;

create or replace function public.parti_aday_ata(p_tur text, p_il int, p_kadlar text[]) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler;
  il oyun.iller; lim int; i int := 0; nick text; h oyun.profiller; secilen uuid[] := '{}'; mevcut oyun.adaylar;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_tur not in ('mv','bel') then raise exception 'Geçersiz seçim türü.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.id is null or pa.kapali then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id then raise exception 'Adayları yalnız Genel Başkan atayabilir.'; end if;
  if pa.kurulus_bit is not null then raise exception 'Partin henüz kuruluş aşamasında; kuruluş tamamlanmadan aday gösteremez.'; end if;
  if oyun.parti_yontem(pa.id, p_tur) <> 'atama' then
    raise exception 'Partin bu seçimde adaylarını ön seçimle belirliyor. Atama için önce yöntemi "Genel Başkan ataması" yap (adaylık süreci başlamadan önce).'; end if;
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  s := oyun.aday_atama_secim(p_tur, il.id, t);
  if s.id is null then raise exception 'Şu anda aday belirleme dönemi değil. Atama, adaylık başvurusu açıldığı andan ön seçim bitene kadar yapılır.'; end if;
  lim := case when p_tur = 'mv' then coalesce(il.mv_secim, il.mv) else 1 end;
  p_kadlar := coalesce(p_kadlar, '{}');
  if cardinality(p_kadlar) > lim then
    raise exception '% için en çok % aday gösterebilirsin.', il.ad, lim; end if;

  foreach nick in array p_kadlar loop
    nick := btrim(nick);
    continue when nick = '';
    select * into h from oyun.profiller where lower(kad) = lower(nick);
    if h.id is null or h.yasakli then raise exception 'Oyuncu bulunamadı: %', nick; end if;
    if h.parti_id is distinct from pa.id then raise exception '% partinin üyesi değil.', h.kad; end if;
    if h.il_id is distinct from il.id then raise exception '% bu ilde kayıtlı değil; aday yalnız kayıtlı olduğu ilden gösterilir.', h.kad; end if;
    if p_tur = 'bel' and h.id = pa.gb then raise exception 'Genel başkan belediye başkanı adayı olamaz.'; end if;
    if h.id = any(secilen) then raise exception '% listede iki kez yazılmış.', h.kad; end if;
    if oyun.uyari(h, t) is not null then raise exception '%: %', h.kad, oyun.uyari(h, t); end if;
    secilen := secilen || h.id;
  end loop;

  -- Eski atamayı temizle: başvuru sahiplerinin başvurusu kalır, yalnız sırası düşer;
  -- Genel Başkanın sonradan eklediği ve listeden çıkardığı kişinin kaydı silinir.
  delete from oyun.adaylar a
   where a.secim_id = s.id and a.parti_id = pa.id and a.il_id = il.id
     and a.atama_ekleme and not (a.user_id = any(secilen));
  update oyun.adaylar a set atama_sira = null
   where a.secim_id = s.id and a.parti_id = pa.id and a.il_id = il.id and a.atama_sira is not null;

  for i in 1 .. coalesce(cardinality(secilen), 0) loop
    select * into mevcut from oyun.adaylar where secim_id = s.id and user_id = secilen[i];
    if mevcut.id is not null then
      if mevcut.parti_id is distinct from pa.id then
        raise exception '% bu seçimde başka bir listeden ya da bağımsız aday adayı.', (select kad from oyun.profiller where id = secilen[i]); end if;
      update oyun.adaylar set atama_sira = i, il_id = il.id where id = mevcut.id;
    else
      insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at, atama_sira, atama_ekleme)
      values (s.id, secilen[i], pa.id, il.id, t, i, true);
      perform oyun.bildir(secilen[i], format('Genel Başkan seni %s %s gösterdi%s. Liste ön seçim süresi bitince kesinleşir.',
        il.ad, case when p_tur = 'mv' then 'milletvekili adayı olarak' else 'belediye başkanı adayı olarak' end,
        case when p_tur = 'mv' then format(' (%s. sıra)', i) else '' end), t);
    end if;
  end loop;
  return public.parti_aday_il(p_tur, il.id);
end $$;

revoke all on function public.parti_kur_aday_yontem(bigint, text, text), public.parti_aday_yontem_ayarla(text, text),
  public.parti_aday_panel(), public.parti_aday_il(text, int), public.parti_aday_ata(text, int, text[]) from public, anon;
grant execute on function public.parti_kur_aday_yontem(bigint, text, text), public.parti_aday_yontem_ayarla(text, text),
  public.parti_aday_panel(), public.parti_aday_il(text, int), public.parti_aday_ata(text, int, text[]) to authenticated;
revoke all on function oyun.parti_yontem(bigint, text), oyun.aday_yontem_kilit(text, timestamptz),
  oyun.aday_atama_secim(text, smallint, timestamptz), oyun.tg_onsecim_atama_oy(), oyun.tg_kurucu_basvuru_yontem()
  from public, anon, authenticated;
commit;
