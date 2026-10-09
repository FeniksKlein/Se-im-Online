-- 2026-10-09 · Oyuncu deneyimi güncellemesi (gelistirici/sql/39_oyuncu_deneyimi.sql ile aynı)
-- Supabase › SQL Editor'e yapıştır › Run. Oyunu sıfırlamaz; iki kez çalıştırmak güvenlidir.
-- ÖNEMLİ: 1 Kasım genel seçiminden önce çalıştırılmalı (genel seçim sayımındaki hata burada düzeltiliyor).
begin;
-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 39) OYUNCU DENEYİMİ GÜNCELLEMESİ (2026-10-09)
--  Oyunu sıfırlamaz; yalnızca ekler. Tekrar çalıştırılabilir.
--   1. Yeni oyuncu: ilk il seçiminde kütük beklemesi yok, varsayılan kıdem şartı 3
--   2. Meclis oyuncu sayısına göre ölçeklenir (anayasadaki sayı üst sınırdır)
--   3. Sandık 08:00–22:00, sonuç 22:30; aday adaylığı başvuruları 3 gün
--   4. Oyuncuya / şirkete / gazeteye para hediyesi, havaleyle ortak günlük sınıra tabi
--   5. İlk adımlar listesi, Cumhuriyet tarihi arşivi
--   6. Kumbara 16 saat, seri kaçırılınca sıfırlanmaz
--   7. Görev ihmali: 3 gün girmeyen bakan/GBY, 7 gün girmeyen CB/GB/belediye başkanı görevden düşer
--   8. Parti kimliği (ekonomi/toplum ekseni + slogan), oyuncu avatarı ve biyografisi
--   9. Seçim mitingleri
-- =====================================================================

-- ---------- Ayarlar ----------
alter table oyun.ayarlar alter column oy_min_kidem set default 3;
alter table oyun.ayarlar add column if not exists meclis_olcek     numeric  not null default 0.25;  -- aktif oyuncu başına sandalye (0: kapalı)
alter table oyun.ayarlar add column if not exists ihmal_gun_atama  smallint not null default 3;     -- bakan / GBY (0: kapalı)
alter table oyun.ayarlar add column if not exists ihmal_gun_secim  smallint not null default 7;     -- CB / GB / belediye başkanı (0: kapalı)

-- ---------- Yeni tablolar ----------
create table if not exists oyun.meclis_olcek_kayit(
  secim_id bigint primary key references oyun.secimler(id),
  aktif    int not null,
  sandalye int not null,
  anayasal int not null,
  zaman    timestamptz not null default now()
);
create table if not exists oyun.ihmal_uyari(
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  tur     text not null,
  zaman   timestamptz not null,
  primary key (user_id, tur)
);
create table if not exists oyun.oyuncu_kimlik(
  user_id   uuid primary key references oyun.profiller(id) on delete cascade,
  avatar    text check (avatar ~ '^[0-9]{1,2}(-[0-9]{1,2}){5}$'),
  biyografi text check (length(biyografi) <= 160),
  guncelleme timestamptz not null default now()
);
create table if not exists oyun.parti_kimlik(
  parti_id  bigint primary key references oyun.partiler(id) on delete cascade,
  eko       smallint not null default 0 check (eko between -5 and 5),      -- -5 devletçi … +5 serbest piyasa
  toplum    smallint not null default 0 check (toplum between -5 and 5),   -- -5 özgürlükçü … +5 muhafazakâr
  slogan    text check (length(slogan) <= 80),
  guncelleme timestamptz not null default now()
);
create table if not exists oyun.mitingler(
  id        bigint generated always as identity primary key,
  user_id   uuid not null references oyun.profiller(id) on delete cascade,
  secim_id  bigint not null references oyun.secimler(id),
  il_id     smallint not null references oyun.iller(id),
  parti_id  bigint references oyun.partiler(id),
  baslik    text not null check (length(baslik) between 3 and 80),
  bas       timestamptz not null,
  bit       timestamptz not null,
  bedel     numeric not null default 0,
  duyuruldu boolean not null default false,
  sonuc_yazildi boolean not null default false,
  olusturma timestamptz not null default now(),
  unique (user_id, secim_id)
);
create index if not exists mitingler_bas on oyun.mitingler(bas);
create index if not exists mitingler_il on oyun.mitingler(il_id, bas);
create table if not exists oyun.miting_katilim(
  miting_id bigint not null references oyun.mitingler(id) on delete cascade,
  user_id   uuid not null references oyun.profiller(id) on delete cascade,
  zaman     timestamptz not null default now(),
  primary key (miting_id, user_id)
);
do $$ declare t text; begin
  foreach t in array array['meclis_olcek_kayit','ihmal_uyari','oyuncu_kimlik','parti_kimlik','mitingler','miting_katilim'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $$;

-- Takvim: sandık 08:00–22:00, sonuç 22:30; belediye başvurusu 4–6, vekil başvurusu 24–26, CB ön seçim başvurusu 26–27
CREATE OR REPLACE FUNCTION oyun.donem_olustur(p_ay date)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare m date:=date_trunc('month',p_ay)::date; n date:=(date_trunc('month',p_ay)+interval '1 month')::date;
  dm text:=to_char(m,'YYYY-MM'); dn text:=to_char(n,'YYYY-MM'); b timestamptz:=(select baslangic from oyun.ayarlar where id=1);
begin
  if oyun.tr_an(m+3,0)>=b then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
      ('bel_on',dm,oyun.tr_an(m+3,0),oyun.tr_an(m+6,0),oyun.tr_an(m+7,8),oyun.tr_an(m+7,22),oyun.tr_an(m+7,22,30),null),
      ('bel',dm,null,null,oyun.tr_an(m+9,8),oyun.tr_an(m+9,22),oyun.tr_an(m+9,22,30),oyun.tr_an(m+10,0))
    on conflict(tur,donem) do nothing;
  end if;
  if oyun.tr_an(m+14,0)>=b then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
      ('kurultay',dm,oyun.tr_an(m+14,0),oyun.tr_an(m+17,0),oyun.tr_an(m+17,8),oyun.tr_an(m+17,22),oyun.tr_an(m+17,22,30),oyun.tr_an(m+18,0))
    on conflict(tur,donem) do nothing;
  end if;
  if oyun.tr_an(m+23,0)>=b then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
      ('mv_on',dn,oyun.tr_an(m+23,0),oyun.tr_an(m+26,0),oyun.tr_an(m+27,8),oyun.tr_an(m+27,22),oyun.tr_an(m+27,22,30),null),
      ('mv',dn,null,null,oyun.tr_an(n,8),oyun.tr_an(n,22),oyun.tr_an(n,22,30),oyun.tr_an(n+1,0))
    on conflict(tur,donem) do nothing;
    if oyun.cb_secim_gerekli(oyun.tr_an(n,8)) then
      insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
        ('cb',dn,oyun.tr_an(m+18,0),oyun.tr_an(m+25,0),oyun.tr_an(n,8),oyun.tr_an(n,22),oyun.tr_an(n,22,30),oyun.tr_an(n+1,0)),
        ('cb_on',dn,oyun.tr_an(m+25,0),oyun.tr_an(m+27,0),oyun.tr_an(m+27,8),oyun.tr_an(m+27,22),oyun.tr_an(m+27,22,30),null)
      on conflict(tur,donem) do nothing;
    end if;
  end if;
end $function$;

-- CB 2. turu: aynı saatler
CREATE OR REPLACE FUNCTION oyun._sonuc_cb(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  toplam bigint;
  n int;
  birinci record;
  ikinci record;
  t2 oyun.secimler;
  gun date := (s.oy_bas at time zone 'Europe/Istanbul')::date;
  adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);

  select count(*) into toplam
  from oyun.oylar
  where secim_id = s.id;

  select count(*) into n
  from oyun.adaylar
  where secim_id = s.id;

  select coalesce(
    jsonb_agg(
      oyun.aday_json(a.id)
      order by a.oy desc, a.basvuru_at
    ),
    '[]'::jsonb
  )
  into adaylar_j
  from oyun.adaylar a
  where a.secim_id = s.id;

  if n = 0 then
    perform oyun.olay(
      'secim',
      'Cumhurbaşkanlığı seçiminde aday yoktu; makam boş kalacak.',
      null, null, s.sonuc_at
    );

    return jsonb_build_object(
      'toplam', toplam,
      'adaylar', adaylar_j,
      'ikinci_tur', false
    );
  end if;

  select * into birinci
  from oyun.adaylar
  where secim_id = s.id
  order by oy desc, basvuru_at, id
  limit 1;

  if n = 1 or (toplam > 0 and birinci.oy * 2 > toplam) then
    insert into oyun.kazananlar
    values (s.id, birinci.user_id, null, birinci.parti_id)
    on conflict do nothing;

    perform oyun.olay(
      'secim',
      format(
        'Cumhurbaşkanı ilk turda seçildi: %s (%%%s).',
        (select kad from oyun.profiller where id = birinci.user_id),
        case
          when toplam > 0 then round(birinci.oy * 100.0 / toplam,1)
          else 100
        end
      ),
      null, birinci.parti_id, s.sonuc_at
    );

    return jsonb_build_object(
      'toplam', toplam,
      'adaylar', adaylar_j,
      'ikinci_tur', false,
      'kazanan', oyun.aday_json(birinci.id)
    );
  end if;

  select * into ikinci
  from oyun.adaylar
  where secim_id = s.id
    and id <> birinci.id
  order by oy desc, basvuru_at, id
  limit 1;

  insert into oyun.secimler(
    tur, donem, oy_bas, oy_bit, sonuc_at, goreve_bas,
    ara, ara_neden
  )
  values (
    'cb2',
    s.donem,
    oyun.tr_an(gun+1,8),
    oyun.tr_an(gun+1,22),
    oyun.tr_an(gun+1,22,30),
    oyun.tr_an(gun+2,0),
    s.ara,
    s.ara_neden
  )
  on conflict(tur,donem) do nothing
  returning * into t2;

  if t2.id is not null then
    insert into oyun.adaylar(
      secim_id,user_id,parti_id,il_id,basvuru_at,vaat
    )
    values
      (
        t2.id,birinci.user_id,birinci.parti_id,null,
        birinci.basvuru_at,birinci.vaat
      ),
      (
        t2.id,ikinci.user_id,ikinci.parti_id,null,
        ikinci.basvuru_at,ikinci.vaat
      );
  end if;

  perform oyun.olay(
    'secim',
    format(
      'Cumhurbaşkanlığı seçimi ikinci tura kaldı: %s ve %s yarın sandıkta.',
      (select kad from oyun.profiller where id = birinci.user_id),
      (select kad from oyun.profiller where id = ikinci.user_id)
    ),
    null, null, s.sonuc_at
  );

  return jsonb_build_object(
    'toplam', toplam,
    'adaylar', adaylar_j,
    'ikinci_tur', true
  );
end $function$;

-- Erken seçim: aynı saatler
CREATE OR REPLACE FUNCTION oyun.erken_genel_secim_olustur(t timestamp with time zone, p_teklif bigint)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ilk date; ongun date; secgun date; dm text; eski text;
begin
  ilk:=(t at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(ilk,8)<t+interval '8 hours' then ilk:=ilk+1; end if;
  ongun:=ilk; secgun:=ilk+1;
  dm:='erken-genel-'||p_teklif||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
  select donem into eski from oyun.secimler where tur='mv' and not ara and durum='bekliyor' and oy_bas>t order by oy_bas limit 1;
  if eski is not null then
    update oyun.secimler set durum='tamam',sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','erken_secim')
    where donem=eski and durum='bekliyor' and tur in ('mv_on','mv','cb_on','cb','cb2');
  end if;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
   ('mv_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
   ('mv',dm,null,null,oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  if oyun.hukumet_sistemi()=0 then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
     ('cb_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
     ('cb',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  end if;
  perform oyun.olay('secim',format('TBMM erken seçim kararı aldı. Erken genel seçim %s günü yapılacak.',to_char(secgun,'DD.MM.YYYY')),null,null,t);
  return dm;
end $function$;

-- Ara seçimler: aynı saatler; göreve başlama 23:00
CREATE OR REPLACE FUNCTION oyun.ara_secim_olustur(p_tur text, p_parti bigint, p_il smallint, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  ilk_gun date;
  ikinci_gun date;
  o oyun.secimler;
  dm text;
  on_id bigint;
  asil_id bigint;
  asil_bas timestamptz;
begin
  if p_tur not in ('gb','cb','bel') then
    raise exception 'Geçersiz ara seçim türü.';
  end if;

  -- En yakın makul pencere: adaylık süresi en az yaklaşık 8 saat olsun.
  ilk_gun := (t at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(ilk_gun, 8) < t + interval '8 hours' then
    ilk_gun := ilk_gun + 1;
  end if;
  ikinci_gun := ilk_gun + 1;

  if p_tur = 'gb' then
    if p_parti is null then
      raise exception 'Genel başkan ara seçimi için parti gerekli.';
    end if;

    select * into o
    from oyun.secimler
    where tur = 'kurultay'
      and ara
      and hedef_parti_id = p_parti
      and durum <> 'tamam'
      and coalesce(goreve_bas, sonuc_at) > t
    order by coalesce(goreve_bas, sonuc_at)
    limit 1;

    if o.id is not null then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'kurultay', 'ara', true, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    asil_bas := oyun.tr_an(ilk_gun, 23);

    -- Zaten bundan daha erken bitecek olağan kurultay varsa ikinci seçim yaratma.
    select * into o
    from oyun.secimler
    where tur = 'kurultay'
      and not ara
      and durum <> 'tamam'
      and goreve_bas > t
    order by goreve_bas
    limit 1;

    if o.id is not null and o.goreve_bas <= asil_bas then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'kurultay', 'ara', false, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    dm := 'ara-gb-' || p_parti || '-' ||
          to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, hedef_parti_id, ara_neden
    ) values (
      'kurultay', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,22),
      oyun.tr_an(ilk_gun,22,30), asil_bas,
      true, p_parti, 'genel_baskan_istifa'
    )
    returning id into asil_id;

    return jsonb_build_object(
      'secim_id', asil_id, 'tur', 'kurultay', 'ara', true, 'mevcut', false,
      'oy_bas', oyun.tr_an(ilk_gun,8), 'goreve_bas', asil_bas
    );

  elsif p_tur = 'bel' then
    if p_il is null then
      raise exception 'Belediye ara seçimi için il gerekli.';
    end if;

    select * into o
    from oyun.secimler
    where tur = 'bel'
      and ara
      and hedef_il_id = p_il
      and durum <> 'tamam'
      and coalesce(goreve_bas, sonuc_at) > t
    order by coalesce(goreve_bas, sonuc_at)
    limit 1;

    if o.id is not null then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'bel', 'ara', true, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    asil_bas := oyun.tr_an(ikinci_gun, 23);

    -- Yaklaşan olağan belediye seçimi daha erken başkan çıkaracaksa onu kullan.
    select * into o
    from oyun.secimler
    where tur = 'bel'
      and not ara
      and durum <> 'tamam'
      and goreve_bas > t
    order by goreve_bas
    limit 1;

    if o.id is not null and o.goreve_bas <= asil_bas then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', 'bel', 'ara', false, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    dm := 'ara-bel-' || p_il || '-' ||
          to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, hedef_il_id, ara_neden
    ) values (
      'bel_on', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,22),
      oyun.tr_an(ilk_gun,22,30), null,
      true, p_il, 'belediye_baskani_istifa'
    )
    returning id into on_id;

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, hedef_il_id, ara_neden
    ) values (
      'bel', dm,
      null, null,
      oyun.tr_an(ikinci_gun,8), oyun.tr_an(ikinci_gun,22),
      oyun.tr_an(ikinci_gun,22,30), asil_bas,
      true, p_il, 'belediye_baskani_istifa'
    )
    returning id into asil_id;

    return jsonb_build_object(
      'secim_id', asil_id, 'on_secim_id', on_id,
      'tur', 'bel', 'ara', true, 'mevcut', false,
      'oy_bas', oyun.tr_an(ikinci_gun,8), 'goreve_bas', asil_bas
    );

  else
    select * into o
    from oyun.secimler
    where tur in ('cb','cb2')
      and ara
      and durum <> 'tamam'
      and coalesce(goreve_bas, sonuc_at) > t
    order by coalesce(goreve_bas, sonuc_at)
    limit 1;

    if o.id is not null then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', o.tur, 'ara', true, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    asil_bas := oyun.tr_an(ikinci_gun, 23);

    -- Yaklaşan olağan CB seçimi daha erken sonuç verecekse onu kullan.
    select * into o
    from oyun.secimler
    where tur in ('cb','cb2')
      and not ara
      and durum <> 'tamam'
      and goreve_bas > t
    order by goreve_bas
    limit 1;

    if o.id is not null and o.goreve_bas <= asil_bas then
      return jsonb_build_object(
        'secim_id', o.id, 'tur', o.tur, 'ara', false, 'mevcut', true,
        'oy_bas', o.oy_bas, 'goreve_bas', o.goreve_bas
      );
    end if;

    dm := 'ara-cb-' ||
          to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, ara_neden
    ) values (
      'cb_on', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,22),
      oyun.tr_an(ilk_gun,22,30), null,
      true, 'cumhurbaskani_istifa'
    )
    returning id into on_id;

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, ara_neden
    ) values (
      'cb', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ikinci_gun,8), oyun.tr_an(ikinci_gun,22),
      oyun.tr_an(ikinci_gun,22,30), asil_bas,
      true, 'cumhurbaskani_istifa'
    )
    returning id into asil_id;

    return jsonb_build_object(
      'secim_id', asil_id, 'on_secim_id', on_id,
      'tur', 'cb', 'ara', true, 'mevcut', false,
      'oy_bas', oyun.tr_an(ikinci_gun,8), 'goreve_bas', asil_bas
    );
  end if;
end $function$;

-- İl değiştirme kilidi metni
CREATE OR REPLACE FUNCTION oyun.il_kilit_nedeni(t timestamp with time zone)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select case s.tur when 'mv_on' then 'Genel seçim dönemi (24''ünden ayın 2''sine kadar) il değiştirilemez.'
                    else 'Belediye seçim dönemi (4''ünden 11''ine kadar) il değiştirilemez.' end
  from oyun.secimler s join oyun.secimler g on g.donem = s.donem and g.tur = case s.tur when 'mv_on' then 'mv' else 'bel' end
  where s.tur in ('mv_on','bel_on') and t >= s.basvuru_bas and t < g.goreve_bas
  limit 1
$function$;

-- Push hatırlatma metinleri
CREATE OR REPLACE FUNCTION oyun.push_hatirlatmalar(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  s oyun.secimler;
  pid bigint;
  v jsonb;
  kosul text;
begin
  if not oyun.push_acik() then return; end if;

  -- Başvuru açılışları
  for s in
    select *
    from oyun.secimler
    where durum = 'bekliyor'
      and basvuru_bas is not null
      and t >= basvuru_bas
      and t < basvuru_bit
      and tur in ('bel_on','mv_on','kurultay')
      and not (hatirlatma ? 'basvuru')
  loop
    v := jsonb_build_object('ekran','gundem');

    if s.ara and s.tur = 'bel_on' and s.hedef_il_id is not null then
      perform oyun.push_konuya(
        's_il_' || s.hedef_il_id,
        null,
        'Olağanüstü belediye seçimi',
        format('%s için belediye başkanlığı aday adaylığı başvuruları açıldı.',
               (select ad from oyun.iller where id = s.hedef_il_id)),
        v
      );
    elsif s.ara and s.tur = 'kurultay' and s.hedef_parti_id is not null then
      perform oyun.push_konuya(
        's_parti_' || s.hedef_parti_id,
        null,
        'Olağanüstü kurultay',
        'Genel başkan istifası sonrası adaylık başvuruları açıldı.',
        v
      );
    else
      perform oyun.push_konuya(
        's_tum',
        null,
        'Başvurular açıldı',
        case s.tur
          when 'bel_on' then 'Belediye başkanlığı aday adaylığı başvuruları açıldı (3 gün). Adayını çıkar!'
          when 'mv_on' then 'Milletvekili aday adaylığı başvuruları açıldı (3 gün). Listeye girmek için başvur!'
          else 'Genel başkanlık başvuruları açıldı. Kurultay ayın 18''inde.'
        end,
        v
      );
    end if;

    update oyun.secimler
    set hatirlatma = hatirlatma || '{"basvuru":true}'
    where id = s.id;
  end loop;

  -- Sandık açılışları
  for s in
    select *
    from oyun.secimler
    where durum = 'bekliyor'
      and t >= oy_bas
      and t < oy_bit
      and not (hatirlatma ? 'oy')
  loop
    v := jsonb_build_object('ekran','secim','id',s.id);

    if s.tur = 'mv' then
      perform oyun.push_konuya(
        's_tum', null,
        'Bugün seçim var! 🗳️',
        'Genel seçim ve cumhurbaşkanlığı seçimi sandıkları 22:00''ye kadar açık.',
        v
      );

    elsif s.tur in ('cb','cb2') then
      perform oyun.push_konuya(
        's_tum', null,
        case when s.tur = 'cb2' then 'Cumhurbaşkanlığı 2. turu'
             when s.ara then 'Olağanüstü cumhurbaşkanlığı seçimi'
             else 'Cumhurbaşkanlığı seçimi' end,
        'Sandıklar 22:00''de kapanıyor. Oyunu kullanmayı unutma!',
        v
      );

    elsif s.tur = 'bel' then
      if s.ara and s.hedef_il_id is not null then
        perform oyun.push_konuya(
          's_il_' || s.hedef_il_id,
          null,
          'Olağanüstü belediye seçimi 🗳️',
          format('%s belediye başkanlığı sandığı 22:00''ye kadar açık.',
                 (select ad from oyun.iller where id = s.hedef_il_id)),
          v
        );
      else
        perform oyun.push_konuya(
          's_tum', null,
          'Bugün belediye seçimi var! 🗳️',
          'İl belediye başkanlığı sandıkları 22:00''ye kadar açık.',
          v
        );
      end if;

    elsif s.tur in ('bel_on','mv_on','kurultay','cb_on') then
      if s.ara and s.tur = 'kurultay' and s.hedef_parti_id is not null then
        perform oyun.push_konuya(
          's_parti_' || s.hedef_parti_id,
          null,
          'Olağanüstü kurultay başladı',
          'Yeni genel başkanı seçmek için oyunu 22:00''ye kadar kullan.',
          v
        );
      elsif s.ara and s.tur = 'bel_on' and s.hedef_il_id is not null then
        for pid in
          select distinct parti_id
          from oyun.adaylar
          where secim_id = s.id and parti_id is not null
        loop
          kosul := format(
            '''s_parti_%s'' in topics && ''s_il_%s'' in topics',
            pid, s.hedef_il_id
          );
          perform oyun.push_konuya(
            's_tum',
            kosul,
            'Partinde olağanüstü ön seçim var',
            format('%s belediye başkanı ön seçimi 22:00''ye kadar.',
                   (select ad from oyun.iller where id = s.hedef_il_id)),
            v
          );
        end loop;
      else
        for pid in
          select distinct parti_id
          from oyun.adaylar
          where secim_id = s.id and parti_id is not null
        loop
          perform oyun.push_konuya(
            's_parti_' || pid,
            null,
            'Partinde seçim var',
            case s.tur
              when 'bel_on' then 'Belediye başkanı ön seçimi bugün 22:00''ye kadar.'
              when 'mv_on' then 'Milletvekili ön seçimi bugün 22:00''ye kadar. Liste sırasını sen belirle!'
              when 'cb_on' then 'Cumhurbaşkanı aday ön seçimi bugün 22:00''ye kadar.'
              else 'Kurultay bugün! Genel başkanını seç.'
            end,
            v
          );
        end loop;
      end if;
    end if;

    update oyun.secimler
    set hatirlatma = hatirlatma || '{"oy":true}'
    where id = s.id;
  end loop;

  -- Sonuçlar
  for s in
    select *
    from oyun.secimler
    where durum <> 'bekliyor'
      and tur in ('mv','bel','cb','cb2')
      and t >= sonuc_at
      and t < sonuc_at + interval '3 hours'
      and not (hatirlatma ? 'sonuc')
  loop
    if s.tur <> 'cb' then
      if s.ara and s.tur = 'bel' and s.hedef_il_id is not null then
        perform oyun.push_konuya(
          's_il_' || s.hedef_il_id,
          null,
          'Olağanüstü seçim sonucu',
          format('%s belediye başkanlığı seçiminin sonucu açıklandı.',
                 (select ad from oyun.iller where id = s.hedef_il_id)),
          jsonb_build_object('ekran','secim','id',s.id)
        );
      else
        perform oyun.push_konuya(
          's_tum',
          null,
          'Sonuçlar açıklandı',
          case s.tur
            when 'mv' then 'Genel seçim ve cumhurbaşkanlığı sonuçları açıklandı. Meclis''in yeni dağılımını gör!'
            when 'bel' then 'Belediye seçimi sonuçları açıklandı. İlini kim kazandı?'
            else 'Cumhurbaşkanlığı ikinci tur sonucu açıklandı.'
          end,
          jsonb_build_object('ekran','secim','id',s.id)
        );
      end if;
    end if;

    update oyun.secimler
    set hatirlatma = hatirlatma || '{"sonuc":true}'
    where id = s.id;
  end loop;

  perform oyun.kumbara_hatirlat(t);
end $function$;

-- Oy verme hata metni
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
end $function$;

-- Seçmen kütüğü yalnızca il değiştirenlere
CREATE OR REPLACE FUNCTION oyun.oy_engeli(p oyun.profiller, s oyun.secimler)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce(
    oyun.uyari(p, s.oy_bas),

    case
      when s.ara
       and s.hedef_il_id is not null
       and p.il_id is distinct from s.hedef_il_id
      then format(
        'Bu olağanüstü seçim yalnızca %s ili içindir.',
        (select ad from oyun.iller where id = s.hedef_il_id)
      )
    end,

    case
      when s.ara
       and s.hedef_parti_id is not null
       and p.parti_id is distinct from s.hedef_parti_id
      then format(
        'Bu olağanüstü kurultay yalnızca %s üyeleri içindir.',
        (select kisa from oyun.partiler where id = s.hedef_parti_id)
      )
    end,

    case
      when s.tur in ('mv','bel','mv_on','bel_on')
       and p.son_il_degis is not null   -- ilk il seçimi kütük beklemesi gerektirmez (hesap yaşı şartı yeter)
       and p.il_at > s.oy_bas - make_interval(
         days => (select oy_il_gun from oyun.ayarlar where id = 1)
       )
      then format(
        'Seçmen kütüğü: bu ilde oy kullanabilmek için seçimden en az %s gün önce bu ile kayıtlı olmalısın.',
        (select oy_il_gun from oyun.ayarlar where id = 1)
      )
    end,

    case
      when s.tur in ('mv_on','bel_on','kurultay','cb_on') then
        case
          when p.parti_id is null
            then 'Bu parti içi seçimde oy için bir partiye üye olmalısın.'
          when p.parti_at > s.basvuru_bas
            then 'Parti içi seçimde oy için başvurular açılmadan önce üye olmuş olmalısın.'
        end
    end
  )
$function$;

-- Kıdem uyarısı metni
CREATE OR REPLACE FUNCTION oyun.uyari(p oyun.profiller, ref timestamp with time zone)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select coalesce(
    case when p.olusturma > ref - make_interval(days => a.min_hesap_gun)
         then format('Hesabın en az %s günlük olmalı.', a.min_hesap_gun) end,
    case when a.eposta_zorunlu and not exists (select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
         then 'E-posta adresini doğrulamalısın.' end,
    case when a.cihaz_zorunlu and not exists (select 1 from oyun.oturumlar o where o.user_id = p.id)
         then 'Cihaz doğrulaması gerekiyor: uygulamayı güncelleyip yeniden aç.' end,
    oyun.suphe(p.id),
    case when oyun.kidem_puani(p.id) < a.oy_min_kidem
         then format('En az %s kıdem puanın olmalı (şu an %s). Oyuna girdiğin her gün maaşını topla: +1 kıdem.', a.oy_min_kidem, oyun.kidem_puani(p.id)) end)
  from oyun.ayarlar a where a.id = 1
$function$;

-- Seçmen kartı şartları ekranı
CREATE OR REPLACE FUNCTION public.vatandaslik()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.ayarlar; k numeric := oyun.kidem_puani(p.id);
begin
  select * into a from oyun.ayarlar where id = 1;
  return jsonb_build_object(
    'uygun', oyun.uyari(p, t) is null, 'engel', oyun.uyari(p, t),
    'sartlar', jsonb_build_array(
      jsonb_build_object('ad', format('Hesap en az %s günlük', a.min_hesap_gun), 'tamam', p.olusturma <= t - make_interval(days => a.min_hesap_gun),
                         'not', case when p.olusturma > t - make_interval(days => a.min_hesap_gun) then 'Tamamlanma: ' || to_char((p.olusturma + make_interval(days => a.min_hesap_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') end),
      jsonb_build_object('ad', 'E-posta doğrulanmış', 'tamam', not a.eposta_zorunlu or exists (select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)),
      jsonb_build_object('ad', 'Cihaz doğrulanmış', 'tamam', not a.cihaz_zorunlu or exists (select 1 from oyun.oturumlar o where o.user_id = p.id)),
      jsonb_build_object('ad', 'Tek hesap (bu cihazda önceden açılmış hesap yok ya da yönetici onaylı)', 'tamam', oyun.suphe(p.id) is null),
      jsonb_build_object('ad', format('En az %s kıdem puanı (her gün maaşını topla: +1)', a.oy_min_kidem), 'tamam', k >= a.oy_min_kidem, 'not', format('Kıdemin: %s', k)),
      jsonb_build_object('ad', format('Seçmen kütüğü: il değiştirdiysen yeni ilinde en az %s gün', a.oy_il_gun), 'tamam', p.son_il_degis is null or p.il_at <= t - make_interval(days => a.oy_il_gun),
                         'not', case when p.son_il_degis is not null and p.il_at > t - make_interval(days => a.oy_il_gun) then 'Bu ilde oy hakkı: ' || to_char((p.il_at + make_interval(days => a.oy_il_gun)) at time zone 'Europe/Istanbul', 'DD.MM') end)),
    'parti_kurma', jsonb_build_object('kidem', a.parti_kurucu_kidem, 'kurucu', a.parti_kurucu_sayi, 'gun', a.parti_kurulus_gun, 'benim_kidem', k,
                                      'ucret', oyun.parti_kur_ucreti(), 'para', (select para from oyun.cuzdanim(p.id))));
end $function$;

-- Seri: kaçırılan gün sıfırlamaz, bir basamak düşürür
CREATE OR REPLACE FUNCTION oyun.gelir_hesap(u uuid, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
declare p oyun.profiller; c oyun.cuzdan; ul oyun.ulke; st jsonb; ilc numeric; ub numeric; seri_y int; seri_b numeric;
        maas numeric; makam numeric; brut numeric; vergi numeric; kent numeric; gecim numeric; gecim_ind numeric; net numeric;
        saat numeric; v_hiz numeric := coalesce((select maas_hizi from oyun.ayarlar where id = 1), 1); bugun date := (t at time zone 'Europe/Istanbul')::date; destek numeric := 0; hem numeric := 0; asg_saat numeric; kv numeric;
begin
  select * into p from oyun.profiller where id = u;
  select * into c from oyun.cuzdan where user_id = u;
  select * into ul from oyun.ulke where id = 1;
  st := oyun.statu_json(u);
  ilc := oyun.il_carpan(p.il_id);
  ub := oyun.bonus(p.il_id, 'ucret', t) + case when (st ->> 'basamak')::int <= 1 then oyun.bonus(p.il_id, 'ucret_yeni', t) else 0 end;
  -- seri: bir sonraki (ya da bugünkü) toplamada geçerli olan seri
  seri_y := case when c.seri_gun = bugun then c.seri when c.seri_gun = bugun - 1 then c.seri + 1
                when c.seri_gun is null then 1
                else greatest(1, coalesce(c.seri, 1) - (bugun - c.seri_gun - 1)) end;   -- kaçırılan her gün bir basamak
  seri_b := least(oyun.duz('seri_tavan'), 5 * (seri_y - 1));
  asg_saat := ul.asgari / 720;
  maas := asg_saat * v_hiz * (st ->> 'carpan')::numeric * ilc * (1 + ub / 100);
  -- Meclis devamsızlık kesintisi (mevzuat): vekilin katılmadığı oylamalar oranında
  makam := coalesce((select sum(oyun.makam_maasi(m.tur, m.il_id) * case when m.tur = 'mv' then 1 - oyun.vekil_kesinti_orani(u, t) / 100 else 1 end)
                     from oyun.makamlar m where m.user_id = u and m.bit is null), 0) / 720;
  brut := (maas + makam) * (1 + seri_b / 100);
  vergi := greatest(0, brut - asg_saat) * ul.vergi / 100;                 -- asgari ücret gelir vergisinden muaftır
  kv := (select kent_vergisi from oyun.il_durum where il_id = p.il_id);
  kent := brut * kv / 100;
  gecim_ind := least(60, oyun.bonus(p.il_id, 'gecim', t));
  gecim := 350.0 / 24 * ul.endeks * (1 - gecim_ind / 100);
  net := greatest(0, brut - vergi - kent - gecim);
  saat := least(oyun.kumbara_saat(), greatest(0, extract(epoch from (t - c.son_toplama)) / 3600));
  if c.seri_gun is distinct from bugun then
    destek := case when (st ->> 'basamak')::int <= 1 then ul.destek else 0 end;
    hem := (select hemsehri from oyun.il_durum where il_id = p.il_id);
  end if;
  return jsonb_build_object(
    'saat', round(saat, 3), 'dolu', saat >= oyun.kumbara_saat(), 'dolma_an', c.son_toplama + make_interval(hours => oyun.kumbara_saat()::int),
    'kapasite', oyun.kumbara_saat(), 'seri_tavan', oyun.duz('seri_tavan'),
    'vekil_kesinti', case when exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv' and bit is null) then oyun.vekil_kesinti_orani(u, t) end,
    'birikmis', round(net * saat), 'brut_birikmis', round(brut * saat), 'vergi_birikmis', round(vergi * saat),
    'saatlik', jsonb_build_object('maas', round(maas, 2), 'makam', round(makam, 2), 'brut', round(brut, 2), 'vergi', round(vergi, 2),
                                  'kent', round(kent, 2), 'gecim', round(gecim, 2), 'net', round(net, 2)),
    'gunluk_net', round(net * 24), 'asgari', ul.asgari, 'statu_carpan', (st ->> 'carpan')::numeric, 'il_carpan', ilc,
    'ucret_bonus', ub, 'seri', seri_y, 'seri_bonus', seri_b, 'vergi_oran', ul.vergi, 'kent_oran', kv, 'gecim_indirim', gecim_ind,
    'gecim_gunluk', round(350 * ul.endeks * (1 - gecim_ind / 100)),
    'gunluk_destek', jsonb_build_object('devlet', destek, 'belediye', hem),
    'reklam_odul', round(maas * 2));
end $function$;

-- Dakikalık motor: meclis ölçeği, görev ihmali, mitingler
CREATE OR REPLACE FUNCTION oyun.tick()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare t timestamptz:=oyun.simdi(); ay date; r record; n int:=0;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay:=date_trunc('month',t at time zone 'Europe/Istanbul')::date;
  perform oyun.donem_olustur(ay); perform oyun.donem_olustur((ay+interval '1 month')::date);
  if (select son_temizlik from oyun.ayarlar where id=1) is distinct from (t at time zone 'Europe/Istanbul')::date then
    delete from oyun.mesajlar where zaman<t-interval '30 days'; delete from oyun.yayinlar where zaman<t-interval '30 days'; delete from oyun.bildirimler where zaman<t-interval '60 days';
    delete from oyun.ozel where zaman<t-interval '90 days'; delete from oyun.push_kuyruk where olusturma<now()-interval '7 days';
    update oyun.ayarlar set son_temizlik=(t at time zone 'Europe/Istanbul')::date where id=1;
  end if;
  loop
    select * into r from (
      select id,sonuc_at as zaman,0 as asama,oyun.oncelik(tur)o from oyun.secimler where durum='bekliyor' and sonuc_at<=t
      union all select id,goreve_bas,1,oyun.oncelik(tur) from oyun.secimler where durum='sonuclandi' and goreve_bas<=t
    )x order by zaman,asama,o limit 1;
    exit when not found;
    if r.asama=0 then perform oyun.sonuclandir(r.id); else perform oyun.goreve_baslat(r.id); end if;
    n:=n+1; exit when n>200;
  end loop;
  perform oyun.kanun_tick(t); perform oyun.mevzuat_tick(t); perform oyun.meclis_tick(t); perform oyun.parti_tuzuk_tick(t); perform oyun.siyasi_tick(t);
  perform oyun.guvenlik_tick(t); perform oyun.gunluk_ekonomi(t); perform oyun.banka_tick(t); perform oyun.meclis_olcek_uygula(t); perform oyun.ihmal_tick(t); perform oyun.miting_tick(t);
  perform oyun.push_hatirlatmalar(t); perform oyun.push_tetikle();
  return n;
end $function$;

-- Meclis: bu dönemki sandalye sayısı
CREATE OR REPLACE FUNCTION public.meclis()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'toplam',coalesce((select sum(coalesce(mv_secim,mv))::int from oyun.iller),600),
    'anayasal',coalesce((select deger::int from oyun.anayasa where kod='milletvekili_sayisi'),600),
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
$function$;

-- Harita: bu dönemin sandalye sayısı
CREATE OR REPLACE FUNCTION public.harita()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,
    'ad',i.ad,
    'mv',coalesce(i.mv_secim,i.mv),'mv_nufus',i.mv,
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
$function$;

-- Yönetici: yeni kurallar
CREATE OR REPLACE FUNCTION public.admin_kurallar(p jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare y oyun.profiller := oyun.yetki_zorunlu('kurallar'); a oyun.ayarlar;
begin
  if p is not null then
    update oyun.ayarlar set
      min_hesap_gun      = oyun.sinir(coalesce((p ->> 'min_hesap_gun')::int, min_hesap_gun), 0, 30),
      oy_min_kidem       = oyun.sinir(coalesce((p ->> 'oy_min_kidem')::int, oy_min_kidem), 0, 100),
      oy_il_gun          = oyun.sinir(coalesce((p ->> 'oy_il_gun')::int, oy_il_gun), 0, 30),
      cihaz_max_hesap    = oyun.sinir(coalesce((p ->> 'cihaz_max_hesap')::int, cihaz_max_hesap), 1, 5),
      parti_kurucu_sayi  = oyun.sinir(coalesce((p ->> 'parti_kurucu_sayi')::int, parti_kurucu_sayi), 1, 30),
      parti_kurucu_kidem = oyun.sinir(coalesce((p ->> 'parti_kurucu_kidem')::int, parti_kurucu_kidem), 0, 300),
      parti_kurulus_gun  = oyun.sinir(coalesce((p ->> 'parti_kurulus_gun')::int, parti_kurulus_gun), 1, 30),
      -- 15_ekonomi3: parti ücreti, teşkilat, havale, banka
      parti_kur_ucret    = oyun.sinir(coalesce((p ->> 'parti_kur_ucret')::numeric, parti_kur_ucret), 0, 1000000),
      teskilat_ucret     = oyun.sinir(coalesce((p ->> 'teskilat_ucret')::numeric, teskilat_ucret), 0, 100000),
      teskilat_zorunlu   = coalesce((p ->> 'teskilat_zorunlu')::boolean, teskilat_zorunlu),
      havale_sinir       = oyun.sinir(coalesce((p ->> 'havale_sinir')::numeric, havale_sinir), 0, 10),
      banka_acik         = coalesce((p ->> 'banka_acik')::boolean, banka_acik),
      banka_reel_faiz    = oyun.sinir(coalesce((p ->> 'banka_reel_faiz')::numeric, banka_reel_faiz), -10, 30),
      banka_tavan        = oyun.sinir(coalesce((p ->> 'banka_tavan')::numeric, banka_tavan), 0, 100000000),
      meclis_olcek       = oyun.sinir(coalesce((p ->> 'meclis_olcek')::numeric, meclis_olcek), 0, 5),
      ihmal_gun_atama    = oyun.sinir(coalesce((p ->> 'ihmal_gun_atama')::int, ihmal_gun_atama), 0, 30),
      ihmal_gun_secim    = oyun.sinir(coalesce((p ->> 'ihmal_gun_secim')::int, ihmal_gun_secim), 0, 30)
    where id = 1;
    perform oyun.mod_log(y, 'kurallar', null, p::text);
  end if;
  select * into a from oyun.ayarlar where id = 1;
  return jsonb_build_object('min_hesap_gun', a.min_hesap_gun, 'oy_min_kidem', a.oy_min_kidem, 'oy_il_gun', a.oy_il_gun,
    'cihaz_max_hesap', a.cihaz_max_hesap, 'parti_kurucu_sayi', a.parti_kurucu_sayi, 'parti_kurucu_kidem', a.parti_kurucu_kidem,
    'parti_kurulus_gun', a.parti_kurulus_gun,
    'parti_kur_ucret', a.parti_kur_ucret, 'teskilat_ucret', a.teskilat_ucret, 'teskilat_zorunlu', a.teskilat_zorunlu,
    'havale_sinir', a.havale_sinir, 'banka_acik', a.banka_acik, 'banka_reel_faiz', a.banka_reel_faiz, 'banka_tavan', a.banka_tavan,
    'meclis_olcek', a.meclis_olcek, 'ihmal_gun_atama', a.ihmal_gun_atama, 'ihmal_gun_secim', a.ihmal_gun_secim);
end $function$;

-- Havale: hediyelerle ortak günlük sınır
CREATE OR REPLACE FUNCTION public.para_gonder(p_kad text, p_miktar numeric, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  h oyun.profiller;
  m numeric:=round(coalesce(p_miktar,0));
  ack text;
  bugun numeric;
  tavan numeric;
  gm oyun.banka_musteri;
  am oyun.banka_musteri;
  tid bigint;
begin
  perform oyun.banka_acik_mi();
  h:=oyun.profil_bul(p_kad);
  if h.id=p.id then raise exception 'Kendine para gönderemezsin.'; end if;
  if h.yasakli then raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
  if m<100 then raise exception 'En az 100 ₺ gönderebilirsin.'; end if;
  if oyun.uyari(p,t) is not null then raise exception 'Para göndermek için seçmen kartın hazır olmalı: %',oyun.uyari(p,t); end if;
  if (select coklu_kontrol from oyun.ayarlar where id=1)
     and exists(select 1 from oyun.bagli_hesaplar(p.id) b where b=h.id) then
    raise exception 'Aynı cihazda açılmış hesaplar arasında banka transferi yapılamaz.';
  end if;
  if oyun.engelli(h.id,p.id) then raise exception 'Bu oyuncu seni engellediği için ona para gönderemezsin.'; end if;
  perform oyun.takip_engel(p.id,'banka transferi yapamazsın');

  bugun:=oyun.gunluk_aktarim(p.id,t);   -- havale + oyuncu/şirket/gazeteye hediye ortak sınır
  tavan:=round((select asgari from oyun.ulke where id=1)*(select havale_sinir from oyun.ayarlar where id=1));
  if bugun+m>tavan then
    raise exception 'Günlük para aktarma sınırı % ₺ (bugün havale ve hediyeyle % ₺ gönderdin).',oyun.tl(tavan),oyun.tl(bugun);
  end if;

  if nullif(btrim(coalesce(p_aciklama,'')),'') is not null then ack:=oyun.metin_temizle(p_aciklama,100); end if;

  gm:=oyun.vadesiz_isle(p.id,t);
  am:=oyun.vadesiz_isle(h.id,t);
  if gm.vadesiz<m then
    raise exception 'Transfer için vadesiz hesabında yeterli para yok. Bakiye: % ₺.',oyun.tl(gm.vadesiz);
  end if;
  if oyun.mevduat_toplam(h.id)+m>oyun.banka_tavani() then
    raise exception 'Alıcının banka mevduatı üst sınıra çok yakın. Bu transfer alıcının mevduat tavanını aşar.';
  end if;

  update oyun.banka_musteri set vadesiz=vadesiz-m where user_id=p.id;
  update oyun.banka_musteri set vadesiz=vadesiz+m where user_id=h.id;

  insert into oyun.banka_transfer(gonderen,alici,tutar,aciklama,zaman)
  values(p.id,h.id,m,ack,t) returning id into tid;

  perform oyun.banka_kayit(p.id,'vadesiz',-m,
    format('%s adlı oyuncuya banka transferi%s',h.kad,coalesce(': '||ack,'')),t);
  perform oyun.banka_kayit(h.id,'vadesiz',m,
    format('%s adlı oyuncudan banka transferi%s',p.kad,coalesce(': '||ack,'')),t);

  perform oyun.bildir(h.id,format('%s sana banka yoluyla %s ₺ gönderdi.%s',
    p.kad,oyun.tl(m),coalesce(' Not: “'||ack||'”','')),t);

  return jsonb_build_object(
    'tamam',true,'transfer_id',tid,'alici',h.kad,'miktar',m,
    'bakiye',(select vadesiz from oyun.banka_musteri where user_id=p.id),
    'bugun',bugun+m,'tavan',tavan
  );
end $function$;

-- Mevzuat makro etkisi: kumbara taban değeri tanımdan okunur
CREATE OR REPLACE FUNCTION oyun.mevzuat_makro()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  select jsonb_build_object(
    'buyume', -0.08 * oyun.duz('servet_vergisi') - 0.1 * (oyun.duz('kumbara_saat') - (select varsayilan from oyun.duzenleme_tanim where kod = 'kumbara_saat')),
    'enflasyon', 0.05 * (oyun.duz('seri_tavan') - 30) + 0.02 * oyun.duz('yeni_hibe') / 1000,
    'memnuniyet', 0.15 * oyun.duz('servet_vergisi') - 0.4 * oyun.duz('oy_cezasi') / 1000 + 0.04 * oyun.duz('yeni_hibe') / 1000
                  + 0.03 * (oyun.duz('seri_tavan') - 30) + 0.5 * (oyun.duz('kumbara_saat') - (select varsayilan from oyun.duzenleme_tanim where kod = 'kumbara_saat')) + 0.04 * oyun.duz('vekil_kesinti'))
$function$;

-- İl detayı: bu dönemin sandalye sayısı
CREATE OR REPLACE FUNCTION public.il_detay(p_il integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); i oyun.iller; t timestamptz := oyun.simdi();
begin
  select * into i from oyun.iller where id = p_il;
  if i.id is null then raise exception 'İl bulunamadı.'; end if;
  return jsonb_build_object(
    'id', i.id, 'ad', i.ad, 'mv', coalesce(i.mv_secim, i.mv), 'mv_nufus', i.mv,
    'oyuncu', (select count(*) from oyun.profiller where il_id = i.id),
    'partiler', coalesce((select jsonb_agg(oyun.parti_json(x.parti_id) || jsonb_build_object('uye', x.n) order by x.n desc)
                 from (select parti_id, count(*) n from oyun.profiller where il_id = i.id and parti_id is not null group by parti_id) x), '[]'::jsonb),
    'bel', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas)
            from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1),
    'vekiller', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'kaynak', m.kaynak) order by m.parti_id, m.bas)
                 from oyun.makamlar m where m.tur = 'mv' and m.il_id = i.id and m.bit is null), '[]'::jsonb),
    'adaylar', coalesce((select jsonb_agg(oyun.aday_json(a.id) || jsonb_build_object('tur', s.tur) order by s.tur, a.parti_id, a.sira nulls last, a.basvuru_at)
                 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
                 where a.il_id = i.id and (s.durum = 'bekliyor' or (s.tur = 'mv_on' and exists
                   (select 1 from oyun.secimler m where m.tur = 'mv' and m.donem = s.donem and m.durum = 'bekliyor')))), '[]'::jsonb),
    'benim_ilim', p.il_id = i.id,
    'durum', (select jsonb_build_object('gelisim', round(d.gelisim, 1), 'memnuniyet', round(d.memnuniyet, 1), 'kasa', round(d.kasa, 2))
              from oyun.il_durum d where d.il_id = i.id),
    'projeler', coalesce((select jsonb_agg(jsonb_build_object('ad', k.ad, 'zaman', k.zaman, 'baskan', oyun.kad(k.baskan)) order by k.zaman desc)
                 from (select x.*, coalesce(b.ad, y.ad) ad from oyun.belediye_proje_kayit x
                       left join oyun.belediye_hizmetleri b on b.kod = x.kod left join oyun.belediye_yatirimlari y on y.kod = x.kod
                       where x.il_id = i.id order by x.zaman desc limit 5) k), '[]'::jsonb),
    -- ilde yaşayanlara şu an işleyen belediye hizmetleri ve bakanlık tedbirleri
    'hizmetler', oyun.il_hizmet_json(i.id, t),
    'il_carpan', oyun.il_carpan(i.id),
    'kent_vergisi', (select kent_vergisi from oyun.il_durum where il_id = i.id),
    'hemsehri', (select hemsehri from oyun.il_durum where il_id = i.id),
    'tasinma', case when p.il_id <> i.id then oyun.tasinma_ucreti(p.il_id, i.id, t) end,
    'bel_vaatler', (select oyun.vaat_listesi_makam(m.id) from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1));
end $function$;

-- =====================================================================
--  Para aktarma: havale ve hediyeler aynı günlük sınıra tabi
-- =====================================================================
create or replace function oyun.gunluk_aktarim(u uuid, t timestamptz) returns numeric language sql stable set search_path = '' as $$
  select coalesce((select sum(tutar) from oyun.banka_transfer where gonderen = u and zaman >= oyun.bugun_bas(t)), 0)
       + coalesce((select sum(tutar) from oyun.serbest_bagis_kayit where gonderen = u and alici_tur in ('oyuncu','sirket','gazete')
                   and zaman >= oyun.bugun_bas(t)), 0)
$$;

create or replace function oyun.aktarim_tavani() returns numeric language sql stable set search_path = '' as $$
  select round((select asgari from oyun.ulke where id = 1) * (select havale_sinir from oyun.ayarlar where id = 1))
$$;

CREATE OR REPLACE FUNCTION public.serbest_bagis(p_tur text, p_id text, p_tutar numeric, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 m numeric; tid bigint; v_id bigint; v_uuid uuid; hedef text;
 note text:=btrim(coalesce(p_aciklama,'')); c oyun.cuzdan; v_min numeric;
 kisisel boolean:=p_tur in ('oyuncu','sirket','gazete'); bugun numeric; tavan numeric;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 if p_tutar is null or p_tutar::text !~ '^[0-9]+(\.[0-9]+)?$'
   or p_tutar<>trunc(p_tutar) or p_tutar<1 then
   raise exception 'Bağış tutarı en az 1 TL, pozitif tam sayı olmalı';end if;
 m:=p_tutar;
 if length(note)>150 then raise exception 'Bağış notu en fazla 150 karakter';end if;
 if note<>'' and oyun.kufurlu(note) then raise exception 'Notunda uygunsuz bir ifade var.';end if;
 select * into p from oyun.profiller where id=u;
 if not found or p.yasakli then raise exception 'Hesabın bağış yapmaya uygun değil';end if;
 perform oyun.takip_engel(u,'bağış yapamazsın');
 if p_tur not in ('oyuncu','parti','sirket','gazete','il','devlet') then raise exception 'Geçersiz bağış hedefi';end if;
 -- Kişilere ve kişilerin kurumlarına (şirket, gazete) aktarılan para, havaleyle aynı kurallara tabidir:
 -- seçmen kartı hazır olmalı ve günlük aktarma sınırı aşılamaz. Böylece satın alınan para sınırsızca
 -- başka hesaplara taşınamaz; oy ve makam parayla toplanamaz.
 if kisisel then
   if oyun.uyari(p,t) is not null then
     raise exception 'Başka oyunculara para aktarmak için seçmen kartın hazır olmalı: %', oyun.uyari(p,t);
   end if;
   bugun:=oyun.gunluk_aktarim(u,t); tavan:=oyun.aktarim_tavani();
   if bugun+m>tavan then
     raise exception 'Günlük para aktarma sınırı % ₺ (bugün havale ve hediyeyle % ₺ gönderdin; kalan % ₺). Partiye, şehre ve hazineye bağış sınırsızdır.',
       oyun.tl(tavan), oyun.tl(bugun), oyun.tl(greatest(0,tavan-bugun));
   end if;
 end if;
 if p_tur='oyuncu' then
   select id,kad into v_uuid,hedef from oyun.profiller
    where lower(kad)=lower(btrim(coalesce(p_id,''))) and not yasakli limit 1;
   if v_uuid is null then raise exception 'Alıcı oyuncu bulunamadı';end if;
   if v_uuid=u then raise exception 'Kendine bağış yapamazsın';end if;
   if exists(select 1 from oyun.ayarlar where id=1 and coklu_kontrol)
     and exists(select 1 from oyun.bagli_hesaplar(u) b where b=v_uuid) then
      raise exception 'Aynı cihazdaki bağlı hesaplara bağış yapılamaz';end if;
   if oyun.engelli(v_uuid,u) then raise exception 'Bu oyuncu seni engelledi';end if;
 elsif p_tur in ('parti','sirket','gazete','il') then
   if p_id is null or p_id !~ '^[0-9]{1,15}$' then raise exception 'Geçerli hedef numarası gir';end if;
   v_id:=p_id::bigint;
   if p_tur='parti' then
     select ad into hedef from oyun.partiler where id=v_id and not kapali;
   elsif p_tur='sirket' then
     select ad into hedef from oyun.sirketler where id=v_id and aktif;
     if exists(select 1 from oyun.ayarlar where id=1 and coklu_kontrol)
       and exists(select 1 from oyun.sirket_ortaklari o join oyun.bagli_hesaplar(u) b on b=o.user_id where o.sirket_id=v_id and o.pay>0) then
       raise exception 'Aynı cihazdaki bağlı hesapların şirketine bağış yapılamaz';end if;
   elsif p_tur='gazete' then
     select ad into hedef from oyun.oyuncu_gazeteleri where id=v_id and aktif;
   else
     select ad into hedef from oyun.iller where id=v_id;
   end if;
   if hedef is null then raise exception 'Bağış yapılacak kurum bulunamadı';end if;
 else
   hedef:='Türkiye Cumhuriyeti Hazinesi';
 end if;
 perform oyun.para_islem(u,-m,'bagis',left(hedef||' için bağış'||case when note<>'' then ': '||note else '' end,170),t);
 if p_tur='oyuncu' then
   perform oyun.para_islem(v_uuid,m,'bagis',left(p.kad||' tarafından hediye'||case when note<>'' then ': '||note else '' end,170),t);
   perform oyun.bildir(v_uuid,format('%s sana %s ₺ hediye etti.%s',p.kad,oyun.tl(m),case when note<>'' then ' Not: “'||note||'”' else '' end),t);
 elsif p_tur='parti' then
   update oyun.partiler set kasa=kasa+m where id=v_id;
   insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
     values(v_id,t,m,format('%s bağış yaptı',p.kad),'bagis');
 elsif p_tur='sirket' then
   update oyun.sirketler set kasa=kasa+m where id=v_id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
     values(v_id,t,m,p.kad||' oyuncusundan sermaye niteliğinde olmayan karşılıksız bağış');
 elsif p_tur='gazete' then
   update oyun.oyuncu_gazeteleri set kasa=kasa+m where id=v_id;
   insert into oyun.gazete_hareket(gazete_id,zaman,tutar,tur,aciklama)
     values(v_id,t,m,'bagis',p.kad||' bağış yaptı');
 elsif p_tur='il' then
   select asgari into v_min from oyun.ulke where id=1;
   update oyun.il_durum set kasa=kasa+m,gelisim=least(100,gelisim+0.005*m/greatest(1,v_min)) where il_id=v_id;
   insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);
 else
   update oyun.ulke set hazine=hazine+m where id=1;
 end if;
 insert into oyun.serbest_bagis_kayit(gonderen,alici_tur,alici_id,alici_adi,tutar,aciklama,zaman)
 values(u,p_tur,case when p_tur='oyuncu' then v_uuid::text when p_tur='devlet' then '1' else v_id::text end,hedef,m,nullif(note,''),t)
 returning id into tid;
 -- Kıdem yalnızca kamusal bağıştan (parti, şehir, hazine) ve günde en fazla 1 puan.
 if not kisisel then
   select * into c from oyun.cuzdan where user_id=u for update;
   select asgari into v_min from oyun.ulke where id=1;
   update oyun.cuzdan
   set kidem=kidem+greatest(0,
     least(1,(coalesce(c.bagis_bugun,0)+m)/greatest(1,v_min))
      -least(1,coalesce(c.bagis_bugun,0)/greatest(1,v_min))),
     bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;
 end if;
 return jsonb_build_object('tamam',true,'id',tid,'gonderen',p.kad,
  'hedef',hedef,'hedef_tur',p_tur,'tutar',m,
  'kalan', (select para from oyun.cuzdan where user_id=u),
  'aktarim_kalan', case when kisisel then greatest(0,oyun.aktarim_tavani()-oyun.gunluk_aktarim(u,t)) end);
end $function$;
revoke all on function public.serbest_bagis(text,text,numeric,text) from public,anon;
grant execute on function public.serbest_bagis(text,text,numeric,text) to authenticated;

-- Oyuncunun bugünkü aktarma hakkı (bağış ekranı gösterir)
create or replace function public.aktarim_hakki() returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b numeric; v numeric;
begin
  b := oyun.gunluk_aktarim(p.id, t); v := oyun.aktarim_tavani();
  return jsonb_build_object('bugun', b, 'tavan', v, 'kalan', greatest(0, v - b), 'engel', oyun.uyari(p, t));
end $$;

-- Yönetici transfer listesi: havaleler + oyunculara hediyeler (kanal sütunuyla)
CREATE OR REPLACE FUNCTION public.admin_transferler_sayfa(p_limit integer DEFAULT 100, p_offset integer DEFAULT 0, p_ara text DEFAULT NULL::text, p_min numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p oyun.profiller:=oyun.yonetici_zorunlu();
  lim int:=least(greatest(coalesce(p_limit,100),1),250);
  off int:=greatest(coalesce(p_offset,0),0);
  ara text:=lower(btrim(coalesce(p_ara,'')));
  toplam int;
  satirlar jsonb;
begin
  create temp table if not exists _aktarim(id bigint, kanal text, gonderen uuid, alici uuid, tutar numeric, aciklama text, zaman timestamptz) on commit drop;
  delete from _aktarim;
  insert into _aktarim
    select bt.id,'havale',bt.gonderen,bt.alici,bt.tutar,bt.aciklama,bt.zaman from oyun.banka_transfer bt
    union all
    select sb.id,'hediye',sb.gonderen,sb.alici_id::uuid,sb.tutar,sb.aciklama,sb.zaman from oyun.serbest_bagis_kayit sb where sb.alici_tur='oyuncu';

  select count(*) into toplam
  from _aktarim bt
  join oyun.profiller gp on gp.id=bt.gonderen
  join oyun.profiller ap on ap.id=bt.alici
  where (ara='' or lower(gp.kad) like '%'||ara||'%' or lower(ap.kad) like '%'||ara||'%')
    and (p_min is null or bt.tutar>=p_min);

  select coalesce(jsonb_agg(jsonb_build_object(
      'id',t.id,'kanal',t.kanal,'zaman',t.zaman,'gonderen',g.kad,'alici',a.kad,'tutar',t.tutar,'aciklama',t.aciklama,
      'gonderen_olusturma',g.olusturma,'alici_olusturma',a.olusturma,
      'ikili_30gun',(select count(*) from _aktarim z
        where z.zaman>oyun.simdi()-interval '30 days'
          and ((z.gonderen=t.gonderen and z.alici=t.alici) or (z.gonderen=t.alici and z.alici=t.gonderen))),
      'ikili_tutar_30gun',(select coalesce(sum(z.tutar),0) from _aktarim z
        where z.zaman>oyun.simdi()-interval '30 days'
          and ((z.gonderen=t.gonderen and z.alici=t.alici) or (z.gonderen=t.alici and z.alici=t.gonderen))),
      'bagli_hesap',exists(select 1 from oyun.bagli_hesaplar(t.gonderen)b where b=t.alici)
    ) order by t.zaman desc,t.id desc),'[]'::jsonb)
  into satirlar
  from (
    select bt.* from _aktarim bt
    join oyun.profiller gp on gp.id=bt.gonderen
    join oyun.profiller ap on ap.id=bt.alici
    where (ara='' or lower(gp.kad) like '%'||ara||'%' or lower(ap.kad) like '%'||ara||'%')
      and (p_min is null or bt.tutar>=p_min)
    order by bt.zaman desc,bt.id desc
    limit lim offset off
  )t
  join oyun.profiller g on g.id=t.gonderen
  join oyun.profiller a on a.id=t.alici;

  return jsonb_build_object('toplam',toplam,'offset',off,'limit',lim,'satirlar',satirlar);
end $function$;

-- =====================================================================
--  Meclis ölçeği: genel seçim başvurusu açılınca sandalyeler aktif oyuncuya göre dağıtılır
-- =====================================================================
create or replace function oyun.meclis_olcek_hesap(t timestamptz) returns jsonb language plpgsql stable set search_path = '' as $$
declare a numeric := (select meclis_olcek from oyun.ayarlar where id = 1);
        anayasal int := coalesce((select round(deger)::int from oyun.anayasa where kod = 'milletvekili_sayisi'), 600);
        aktif int := (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days');
        n int;
begin
  n := case when coalesce(a, 0) <= 0 then anayasal else least(anayasal, greatest(81, ceil(aktif * a)::int)) end;
  return jsonb_build_object('aktif', aktif, 'sandalye', n, 'anayasal', anayasal, 'olcek', a);
end $$;

create or replace function oyun.meclis_olcek_uygula(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare s oyun.secimler; h jsonb;
begin
  for s in select * from oyun.secimler x where x.tur = 'mv_on' and x.durum = 'bekliyor' and x.basvuru_bas <= t
             and not exists (select 1 from oyun.meclis_olcek_kayit k where k.secim_id = x.id) order by x.id loop
    h := oyun.meclis_olcek_hesap(t);
    perform oyun.dagit_mv_sandalye((h->>'sandalye')::int);
    insert into oyun.meclis_olcek_kayit(secim_id, aktif, sandalye, anayasal, zaman)
      values (s.id, (h->>'aktif')::int, (h->>'sandalye')::int, (h->>'anayasal')::int, t) on conflict do nothing;
    if (h->>'sandalye')::int < (h->>'anayasal')::int then
      perform oyun.olay('meclis', format('Yeni dönem TBMM %s sandalyeden oluşacak: son iki haftada oyuna giren %s vatandaşa göre dağıtıldı (anayasal üst sınır %s).',
        h->>'sandalye', h->>'aktif', h->>'anayasal'), null, null, t);
    end if;
  end loop;
end $$;

-- =====================================================================
--  Görev ihmali: uzun süre oyuna girmeyen makam sahibi görevden düşer (önce uyarılır)
-- =====================================================================
create or replace function oyun.ihmal_tick(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare ga int; gs int; r record; sec jsonb;
begin
  select ihmal_gun_atama, ihmal_gun_secim into ga, gs from oyun.ayarlar where id = 1;
  -- Geri dönen oyuncunun uyarı kaydı silinir (bir sonraki ihmalde yeniden uyarılır)
  delete from oyun.ihmal_uyari u using oyun.profiller p where p.id = u.user_id and p.son_gorulme > u.zaman;

  -- Atanmış görevler: bakan ve genel başkan yardımcısı
  if ga > 0 then
    for r in select m.id, m.user_id, m.bakanlik, p.kad, p.parti_id, p.son_gorulme from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
             where m.tur = 'bakan' and m.bit is null and coalesce(p.son_gorulme, m.bas) < t - make_interval(days => ga)
               and m.bas < t - make_interval(days => ga)
               and exists (select 1 from oyun.ihmal_uyari u where u.user_id = m.user_id and u.tur = 'atama' and u.zaman <= t - interval '1 day') loop
      perform oyun.makam_bitir(r.id, t, 'ihmal');
      perform oyun.bildir(r.user_id, format('%s gündür oyuna girmediğin için %s görevin sona erdi.', ga, oyun.makam_ad('bakan', null, r.bakanlik)), t);
      perform oyun.bildir(m2.user_id, format('%s, %s gündür oyuna girmediği için %s görevinden düştü. Yerine yeni bakan atayabilirsin.', r.kad, ga, oyun.makam_ad('bakan', null, r.bakanlik)), t)
        from oyun.makamlar m2 where m2.tur = 'cb' and m2.bit is null;
      perform oyun.olay('makam', format('%s, görevini ihmal ettiği için %s görevinden düştü.', r.kad, oyun.makam_ad('bakan', null, r.bakanlik)), null, r.parti_id, t);
    end loop;
    for r in select g.parti_id, g.user_id, p.kad, pa.gb from oyun.parti_gby g join oyun.profiller p on p.id = g.user_id join oyun.partiler pa on pa.id = g.parti_id
             where coalesce(p.son_gorulme, g.atama) < t - make_interval(days => ga) and g.atama < t - make_interval(days => ga)
               and exists (select 1 from oyun.ihmal_uyari u where u.user_id = g.user_id and u.tur = 'atama' and u.zaman <= t - interval '1 day') loop
      delete from oyun.parti_gby where user_id = r.user_id;
      perform oyun.bildir(r.user_id, format('%s gündür oyuna girmediğin için genel başkan yardımcılığın sona erdi.', ga), t);
      if r.gb is not null then perform oyun.bildir(r.gb, format('%s, %s gündür oyuna girmediği için yardımcılıktan düştü. Yerine yeni bir yardımcı atayabilirsin.', r.kad, ga), t); end if;
    end loop;
    -- Uyarı: sürenin bitmesine 1 gün kala
    insert into oyun.ihmal_uyari(user_id, tur, zaman)
      select x.user_id, 'atama', t from (
        select m.user_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
          where m.tur = 'bakan' and m.bit is null and coalesce(p.son_gorulme, m.bas) < t - make_interval(days => ga) + interval '1 day'
        union select g.user_id from oyun.parti_gby g join oyun.profiller p on p.id = g.user_id
          where coalesce(p.son_gorulme, g.atama) < t - make_interval(days => ga) + interval '1 day') x
      where not exists (select 1 from oyun.ihmal_uyari u where u.user_id = x.user_id and u.tur = 'atama')
      on conflict do nothing;
  end if;

  -- Seçilmiş görevler: cumhurbaşkanı, belediye başkanı, genel başkan
  if gs > 0 then
    for r in select m.id, m.tur, m.user_id, m.il_id, p.kad, p.parti_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
             where m.tur in ('cb','bel') and m.bit is null and coalesce(p.son_gorulme, m.bas) < t - make_interval(days => gs)
               and m.bas < t - make_interval(days => gs)
               and exists (select 1 from oyun.ihmal_uyari u where u.user_id = m.user_id and u.tur = 'secim' and u.zaman <= t - interval '2 days') loop
      perform oyun.makam_bitir(r.id, t, 'ihmal');
      sec := oyun.ara_secim_olustur(r.tur, null, case when r.tur = 'bel' then r.il_id end, t);
      perform oyun.bildir(r.user_id, format('%s gündür oyuna girmediğin için %s görevin sona erdi.', gs, oyun.makam_ad(r.tur, r.il_id, null)), t);
      perform oyun.olay('makam', format('%s, %s gündür ortada olmadığı için %s görevinden düştü. Olağanüstü seçim takvimi oluşturuldu.',
        r.kad, gs, oyun.makam_ad(r.tur, r.il_id, null)), r.il_id, r.parti_id, t);
    end loop;
    for r in select pa.id, pa.ad, pa.gb, p.kad from oyun.partiler pa join oyun.profiller p on p.id = pa.gb
             where not pa.kapali and coalesce(p.son_gorulme, p.olusturma) < t - make_interval(days => gs)
               and exists (select 1 from oyun.ihmal_uyari u where u.user_id = pa.gb and u.tur = 'secim' and u.zaman <= t - interval '2 days') loop
      update oyun.partiler set gb = null where id = r.id;
      sec := oyun.ara_secim_olustur('gb', r.id, null, t);
      perform oyun.bildir(r.gb, format('%s gündür oyuna girmediğin için %s Genel Başkanlığın sona erdi.', gs, r.ad), t);
      insert into oyun.bildirimler(user_id, zaman, metin)
        select id, t, format('%s Genel Başkanı %s gündür ortada olmadığı için görevden düştü. Olağanüstü kurultay başladı; genel başkanlığı üstlenebilir ya da aday olabilirsin.', r.ad, gs)
        from oyun.profiller where parti_id = r.id and id <> r.gb;
      perform oyun.olay('parti', format('%s, %s Genel Başkanlığından ihmal nedeniyle düştü. Olağanüstü kurultay takvimi oluşturuldu.', r.kad, r.ad), null, r.id, t);
    end loop;
    insert into oyun.ihmal_uyari(user_id, tur, zaman)
      select x.user_id, 'secim', t from (
        select m.user_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
          where m.tur in ('cb','bel') and m.bit is null and coalesce(p.son_gorulme, m.bas) < t - make_interval(days => gs) + interval '2 days'
        union select pa.gb from oyun.partiler pa join oyun.profiller p on p.id = pa.gb
          where not pa.kapali and coalesce(p.son_gorulme, p.olusturma) < t - make_interval(days => gs) + interval '2 days') x
      where not exists (select 1 from oyun.ihmal_uyari u where u.user_id = x.user_id and u.tur = 'secim')
      on conflict do nothing;
  end if;
end $$;

-- Uyarı kaydı eklendiğinde oyuncuya bildirim (telefonuna da düşer)
create or replace function oyun.ihmal_uyari_tg() returns trigger language plpgsql set search_path = '' as $$
begin
  perform oyun.bildir(new.user_id, case new.tur
    when 'atama' then 'Uzun süredir oyuna girmedin. Bir gün içinde girmezsen atandığın görevden (bakanlık / genel başkan yardımcılığı) düşeceksin.'
    else 'Uzun süredir oyuna girmedin. İki gün içinde girmezsen seçildiğin görevden düşeceksin ve olağanüstü seçim yapılacak.' end, new.zaman);
  return new;
end $$;
drop trigger if exists ihmal_uyari_bildir on oyun.ihmal_uyari;
create trigger ihmal_uyari_bildir after insert on oyun.ihmal_uyari for each row execute function oyun.ihmal_uyari_tg();

-- =====================================================================
--  İlk adımlar: yeni oyuncunun ilk günü için görev listesi
-- =====================================================================
create or replace function public.ilk_adimlar() returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u text; adimlar jsonb;
begin
  u := oyun.uyari(p, t);
  adimlar := jsonb_build_array(
    jsonb_build_object('kod','maas','ad','İlk maaşını topla','tamam', exists(select 1 from oyun.hesap_hareket where user_id = p.id and tur = 'maas')),
    jsonb_build_object('kod','kimlik','ad','Portreni ve kısa biyografini hazırla','tamam', exists(select 1 from oyun.oyuncu_kimlik where user_id = p.id and avatar is not null)),
    jsonb_build_object('kod','parti','ad','Sana yakın bir partiye katıl','tamam', p.parti_id is not null),
    jsonb_build_object('kod','sohbet','ad','İl kahvesinde kendini tanıt','tamam', exists(select 1 from oyun.mesajlar where user_id = p.id)),
    jsonb_build_object('kod','anket','ad','Haftalık siyasi ankete katıl','tamam', exists(select 1 from oyun.haftalik_anket_oy where user_id = p.id)),
    jsonb_build_object('kod','oy','ad','İlk oyunu kullan','tamam', exists(select 1 from oyun.oylar where secmen = p.id), 'not', u));
  return jsonb_build_object('adimlar', adimlar, 'secmen_karti', u is null, 'engel', u,
    'yeni', p.olusturma > t - interval '14 days',
    'bitti', not exists (select 1 from jsonb_array_elements(adimlar) x where not (x->>'tamam')::boolean));
end $$;

-- =====================================================================
--  Cumhuriyet tarihi: oyunun hiç silinmeyen geçmişi
-- =====================================================================
create or replace function public.tarih_arsivi() returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'baslangic', (select min(olusturma) from oyun.profiller),
    'cumhurbaskanlari', coalesce((select jsonb_agg(jsonb_build_object('kad', p.kad, 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas, 'bit', m.bit,
        'neden', m.bitis_neden, 'gun', round(extract(epoch from coalesce(m.bit, oyun.simdi()) - m.bas) / 86400, 1)) order by m.bas)
      from oyun.makamlar m join oyun.profiller p on p.id = m.user_id where m.tur = 'cb'), '[]'::jsonb),
    'meclis_baskanlari', coalesce((select jsonb_agg(jsonb_build_object('kad', p.kad, 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas, 'bit', m.bit) order by m.bas)
      from oyun.makamlar m join oyun.profiller p on p.id = m.user_id where m.tur = 'tbmm'), '[]'::jsonb),
    'meclisler', coalesce((select jsonb_agg(jsonb_build_object('donem', s.donem, 'tarih', s.sonuc_at, 'oy', s.sonuc -> 'toplam',
        'dolu', s.sonuc -> 'dolu', 'partiler', (select coalesce(jsonb_agg(jsonb_build_object('parti', oyun.parti_json((x ->> 'parti_id')::bigint),
            'yuzde', x -> 'yuzde', 'sandalye', x -> 'sandalye') order by (x ->> 'sandalye')::int desc), '[]'::jsonb)
          from jsonb_array_elements(coalesce(s.sonuc -> 'ulusal', '[]'::jsonb)) x where (x ->> 'sandalye')::int > 0)) order by s.sonuc_at desc)
      from oyun.secimler s where s.tur = 'mv' and s.durum <> 'bekliyor' and s.sonuc is not null), '[]'::jsonb),
    'kanunlar', jsonb_build_object('toplam', (select count(*) from oyun.kanunlar where no is not null),
      'son', coalesce((select jsonb_agg(x) from (select jsonb_build_object('no', k.no, 'baslik', k.baslik, 'tarih', k.sonuc_at, 'teklif_eden', oyun.kad(k.teklif_eden),
          'parti', oyun.parti_json(k.teklif_parti)) x from oyun.kanunlar k where k.no is not null order by k.no desc limit 12) y), '[]'::jsonb)),
    'partiler', coalesce((select jsonb_agg(jsonb_build_object('parti', oyun.parti_json(pa.id), 'kurulus', pa.kurulus, 'sistem', pa.sistem, 'kapali', pa.kapali,
        'uye', (select count(*) from oyun.profiller pr where pr.parti_id = pa.id and not pr.yasakli)) order by pa.kurulus)
      from oyun.partiler pa where pa.kurulus_bit is null or pa.kapali or pa.sistem or exists (select 1 from oyun.profiller pr where pr.parti_id = pa.id)), '[]'::jsonb),
    'rekorlar', jsonb_build_object(
      'en_cok_oy', (select jsonb_build_object('kad', p.kad, 'oy', a.oy, 'secim', s.tur, 'donem', s.donem) from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
         join oyun.profiller p on p.id = a.user_id where s.tur in ('cb','cb2','bel','kurultay') and a.oy is not null order by a.oy desc, a.id limit 1),
      'en_uzun_cb', (select jsonb_build_object('kad', p.kad, 'gun', round(extract(epoch from coalesce(m.bit, oyun.simdi()) - m.bas) / 86400, 1)) from oyun.makamlar m
         join oyun.profiller p on p.id = m.user_id where m.tur = 'cb' order by coalesce(m.bit, oyun.simdi()) - m.bas desc limit 1),
      'en_cok_kanun', (select jsonb_build_object('kad', oyun.kad(k.teklif_eden), 'sayi', count(*)) from oyun.kanunlar k where k.no is not null
         group by k.teklif_eden order by count(*) desc limit 1),
      'en_kalabalik_miting', (select jsonb_build_object('kad', p.kad, 'il', i.ad, 'kisi', (select count(*) from oyun.miting_katilim c where c.miting_id = mt.id))
         from oyun.mitingler mt join oyun.profiller p on p.id = mt.user_id join oyun.iller i on i.id = mt.il_id where mt.bit < oyun.simdi()
         order by (select count(*) from oyun.miting_katilim c where c.miting_id = mt.id) desc, mt.id limit 1),
      'en_yuksek_katilim', (select jsonb_build_object('donem', s.donem, 'oy', (s.sonuc ->> 'toplam')::int) from oyun.secimler s
         where s.tur = 'mv' and s.sonuc ? 'toplam' order by (s.sonuc ->> 'toplam')::int desc limit 1)))
$$;

-- =====================================================================
--  Parti kimliği: iki eksenli siyasi konum + slogan (genel başkan belirler)
-- =====================================================================
insert into oyun.parti_kimlik(parti_id, eko, toplum, slogan)
select pa.id, v.eko, v.toplum, v.slogan from oyun.partiler pa join (values
  ('CYP', -1::smallint, -3::smallint, 'Cumhuriyetin yolunda, herkes için adalet'),
  ('ABP',  2::smallint,  3::smallint, 'Anadolu''nun gücü, milletin birliği'),
  ('YDP',  4::smallint, -2::smallint, 'Özgür birey, güçlü ekonomi'),
  ('MKP',  0::smallint,  4::smallint, 'Önce millet, önce kalkınma'),
  ('EÖP', -5::smallint, -4::smallint, 'Emeğin, doğanın ve özgürlüğün partisi')
) v(kisa, eko, toplum, slogan) on v.kisa = pa.kisa
where pa.sistem
on conflict (parti_id) do nothing;

create or replace function public.parti_kimlikleri() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('parti', oyun.parti_json(pa.id), 'eko', coalesce(k.eko, 0), 'toplum', coalesce(k.toplum, 0),
      'belirlendi', k.parti_id is not null, 'slogan', k.slogan,
      'uye', (select count(*) from oyun.profiller pr where pr.parti_id = pa.id and not pr.yasakli),
      'vekil', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id),
      'gb', oyun.kad(pa.gb)) order by (select count(*) from oyun.profiller pr where pr.parti_id = pa.id) desc, pa.id), '[]'::jsonb)
  from oyun.partiler pa left join oyun.parti_kimlik k on k.parti_id = pa.id
  where not pa.kapali
$$;

create or replace function public.parti_kimlik_ayarla(p_eko int, p_toplum int, p_slogan text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s text; eski oyun.parti_kimlik;
begin
  select * into pa from oyun.partiler where gb = p.id and not kapali;
  if pa.id is null then raise exception 'Parti kimliğini yalnızca genel başkan belirler.'; end if;
  if p_eko not between -5 and 5 or p_toplum not between -5 and 5 then raise exception 'Eksen değerleri -5 ile 5 arasında olmalı.'; end if;
  s := nullif(btrim(coalesce(p_slogan, '')), '');
  if s is not null then s := oyun.metin_temizle(s, 80); end if;
  select * into eski from oyun.parti_kimlik where parti_id = pa.id;
  if eski.parti_id is not null and eski.guncelleme > t - interval '24 hours' and (eski.eko <> p_eko or eski.toplum <> p_toplum) then
    raise exception 'Partinin siyasi konumu günde en fazla bir kez değiştirilebilir.';
  end if;
  insert into oyun.parti_kimlik(parti_id, eko, toplum, slogan, guncelleme) values (pa.id, p_eko, p_toplum, s, t)
    on conflict (parti_id) do update set eko = excluded.eko, toplum = excluded.toplum, slogan = excluded.slogan,
      guncelleme = case when oyun.parti_kimlik.eko <> excluded.eko or oyun.parti_kimlik.toplum <> excluded.toplum then excluded.guncelleme else oyun.parti_kimlik.guncelleme end;
  if eski.parti_id is null or eski.eko <> p_eko or eski.toplum <> p_toplum then
    perform oyun.olay('parti', format('%s siyasi konumunu açıkladı: ekonomide %s, toplumsal konularda %s.', pa.ad,
      case when p_eko <= -3 then 'devletçi' when p_eko < 0 then 'sosyal devletçi' when p_eko = 0 then 'merkez' when p_eko < 3 then 'piyasa yanlısı' else 'serbest piyasacı' end,
      case when p_toplum <= -3 then 'özgürlükçü' when p_toplum < 0 then 'ılımlı özgürlükçü' when p_toplum = 0 then 'merkez' when p_toplum < 3 then 'ılımlı muhafazakâr' else 'muhafazakâr' end),
      null, pa.id, t);
  end if;
  return public.parti_kimlikleri();
end $$;

-- =====================================================================
--  Oyuncu kimliği: portre (avatar kodu) ve kısa biyografi
-- =====================================================================
create or replace function public.kimlik_guncelle(p_avatar text, p_biyografi text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); b text;
begin
  if p_avatar is not null and p_avatar !~ '^[0-9]{1,2}(-[0-9]{1,2}){5}$' then raise exception 'Geçersiz portre.'; end if;
  b := nullif(btrim(coalesce(p_biyografi, '')), '');
  if b is not null then b := oyun.metin_temizle(b, 160); end if;
  insert into oyun.oyuncu_kimlik(user_id, avatar, biyografi, guncelleme) values (p.id, p_avatar, b, oyun.simdi())
    on conflict (user_id) do update set avatar = excluded.avatar, biyografi = excluded.biyografi, guncelleme = excluded.guncelleme;
  return jsonb_build_object('avatar', p_avatar, 'biyografi', b);
end $$;

-- Birden çok oyuncunun portresi (sohbet, listeler). En fazla 100 ad.
create or replace function public.kimlikler(p_kadlar text[]) returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(p.kad, jsonb_build_object('avatar', k.avatar, 'biyografi', k.biyografi,
      'aktif', case when p.son_gorulme > oyun.simdi() - interval '10 minutes' then 'cevrimici'
                    when p.son_gorulme > oyun.simdi() - interval '1 day' then 'bugun'
                    when p.son_gorulme > oyun.simdi() - interval '7 days' then 'hafta' else 'uzun' end)), '{}'::jsonb)
  from oyun.profiller p left join oyun.oyuncu_kimlik k on k.user_id = p.id
  where lower(p.kad) = any (select lower(x) from unnest(p_kadlar[1:100]) x) and not p.yasakli
$$;

-- =====================================================================
--  Seçim mitingleri: aday ilinde 1 saatlik miting düzenler, ildeki oyuncular katılır
-- =====================================================================
create or replace function oyun.miting_bedel(p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select round(1500 * oyun.il_buyukluk(p_il) * coalesce((select endeks from oyun.ulke where id = 1), 1) / 100) * 100
$$;

create or replace function oyun.miting_son_an(s oyun.secimler) returns timestamptz language sql stable set search_path = '' as $$
  select coalesce((select f.oy_bit from oyun.secimler f where f.donem = s.donem and f.durum = 'bekliyor'
                     and f.tur = case s.tur when 'mv_on' then 'mv' when 'bel_on' then 'bel' when 'cb_on' then 'cb' else s.tur end
                     and f.ara = s.ara order by f.oy_bit desc limit 1), s.oy_bit)
$$;

create or replace function public.miting_duzenle(p_secim bigint, p_bas timestamptz, p_baslik text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; a oyun.adaylar; b text; bedel numeric; son timestamptz; il smallint; mid bigint;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  select * into a from oyun.adaylar where secim_id = s.id and user_id = p.id;
  if a.id is null then raise exception 'Miting yalnızca bu seçimin adayları tarafından düzenlenebilir.'; end if;
  son := oyun.miting_son_an(s);
  if son <= t then raise exception 'Bu seçimin oylaması bitti.'; end if;
  if p_bas is null or p_bas < t + interval '15 minutes' then raise exception 'Mitingi en erken 15 dakika sonrasına koyabilirsin.'; end if;
  if p_bas > t + interval '3 days' then raise exception 'Mitingi en fazla 3 gün sonrasına planlayabilirsin.'; end if;
  if p_bas + interval '1 hour' > son then raise exception 'Miting oylama bitmeden sona ermeli.'; end if;
  if exists (select 1 from oyun.mitingler where user_id = p.id and secim_id = s.id) then raise exception 'Bu seçim için zaten bir miting düzenledin.'; end if;
  b := oyun.metin_temizle(p_baslik, 80);
  if length(b) < 3 then raise exception 'Miting başlığı en az 3 karakter olmalı.'; end if;
  il := coalesce(a.il_id, p.il_id);
  if exists (select 1 from oyun.mitingler m where m.il_id = il and m.bas < p_bas + interval '1 hour' and m.bit > p_bas) then
    raise exception 'Bu saatte ilde başka bir miting var. Meydan dolu; başka bir saat seç.';
  end if;
  bedel := oyun.miting_bedel(il);
  perform oyun.para_islem(p.id, -bedel, 'miting', format('%s mitingi (ses sistemi, sahne, ulaşım)', (select ad from oyun.iller where id = il)), t);
  insert into oyun.mitingler(user_id, secim_id, il_id, parti_id, baslik, bas, bit, bedel)
    values (p.id, s.id, il, p.parti_id, b, p_bas, p_bas + interval '1 hour', bedel) returning id into mid;
  perform oyun.olay('secim', format('%s, %s mitingi düzenleyecek: “%s” (%s).', p.kad,
    (select ad from oyun.iller where id = il), b, to_char(p_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), il, p.parti_id, t);
  return jsonb_build_object('id', mid, 'bedel', bedel);
end $$;

create or replace function public.miting_katil(p_id bigint) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.mitingler; n int; odul boolean := false;
begin
  select * into m from oyun.mitingler where id = p_id;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if t < m.bas then raise exception 'Miting henüz başlamadı.'; end if;
  if t >= m.bit then raise exception 'Miting sona erdi.'; end if;
  if p.il_id <> m.il_id then raise exception 'Yalnızca bu ilde yaşayan oyuncular mitinge katılabilir.'; end if;
  insert into oyun.miting_katilim(miting_id, user_id, zaman) values (m.id, p.id, t) on conflict do nothing;
  if found and m.user_id <> p.id and not exists (select 1 from oyun.miting_katilim c join oyun.mitingler x on x.id = c.miting_id
      where c.user_id = p.id and c.miting_id <> m.id and c.zaman >= oyun.bugun_bas(t) and x.user_id <> p.id) then
    update oyun.cuzdan set kidem = kidem + 1 where user_id = p.id; odul := true;   -- günde bir miting: +1 kıdem (siyasi katılım)
  end if;
  select count(*) into n from oyun.miting_katilim where miting_id = m.id;
  return jsonb_build_object('katilim', n, 'kidem', odul);
end $$;

create or replace function public.mitingler() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'kad', p.kad, 'parti', oyun.parti_json(m.parti_id), 'il_id', m.il_id,
      'il', (select ad from oyun.iller where id = m.il_id), 'baslik', m.baslik, 'bas', m.bas, 'bit', m.bit,
      'katilim', (select count(*) from oyun.miting_katilim c where c.miting_id = m.id),
      'katildim', exists (select 1 from oyun.miting_katilim c where c.miting_id = m.id and c.user_id = auth.uid()),
      'benim_ilim', m.il_id = (select il_id from oyun.profiller where id = auth.uid()),
      'benim', m.user_id = auth.uid(),
      'secim_tur', (select tur from oyun.secimler where id = m.secim_id)) order by m.bas), '[]'::jsonb)
  from oyun.mitingler m join oyun.profiller p on p.id = m.user_id
  where m.bit > oyun.simdi() - interval '6 hours' and m.bas < oyun.simdi() + interval '3 days'
$$;

-- Adayın düzenleyebileceği mitingler (Gündem kartı ve aday ekranı için)
create or replace function public.miting_haklarim() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('secim_id', s.id, 'tur', s.tur, 'son', oyun.miting_son_an(s),
      'bedel', oyun.miting_bedel(coalesce(a.il_id, p.il_id)), 'il', (select ad from oyun.iller where id = coalesce(a.il_id, p.il_id)),
      'duzenledi', exists (select 1 from oyun.mitingler m where m.user_id = p.id and m.secim_id = s.id)) order by s.id), '[]'::jsonb)
  from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id join oyun.profiller p on p.id = a.user_id
  where a.user_id = auth.uid() and s.durum = 'bekliyor' and oyun.miting_son_an(s) > oyun.simdi() + interval '75 minutes'
$$;

create or replace function oyun.miting_tick(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare m record; n int;
begin
  for m in select x.*, p.kad, i.ad il_ad from oyun.mitingler x join oyun.profiller p on p.id = x.user_id join oyun.iller i on i.id = x.il_id
           where not x.duyuruldu and x.bas <= t and x.bit > t loop
    update oyun.mitingler set duyuruldu = true where id = m.id;
    insert into oyun.bildirimler(user_id, zaman, metin)
      select pr.id, t, format('%s şu an %s mitinginde: “%s”. Bir saat içinde Gündem''den katılabilirsin.', m.kad, m.il_ad, m.baslik)
      from oyun.profiller pr where pr.il_id = m.il_id and pr.id <> m.user_id and not pr.yasakli;
    if oyun.push_acik() then
      perform oyun.push_konuya('s_il_' || m.il_id, null, format('%s meydanda!', m.kad),
        format('%s mitingi başladı: “%s”. Katılmak için dokun.', m.il_ad, m.baslik), jsonb_build_object('ekran', 'gundem'));
    end if;
  end loop;
  for m in select x.*, p.kad, i.ad il_ad from oyun.mitingler x join oyun.profiller p on p.id = x.user_id join oyun.iller i on i.id = x.il_id
           where not x.sonuc_yazildi and x.bit <= t loop
    select count(*) into n from oyun.miting_katilim where miting_id = m.id;
    update oyun.mitingler set sonuc_yazildi = true, duyuruldu = true where id = m.id;
    perform oyun.olay('secim', format('%s, %s mitinginde %s kişiye seslendi: “%s”.', m.kad, m.il_ad, n, m.baslik), m.il_id, m.parti_id, t);
    perform oyun.bildir(m.user_id, format('%s mitingin sona erdi: %s kişi katıldı.', m.il_ad, n), t);
  end loop;
end $$;

-- =====================================================================
--  Yetkiler
-- =====================================================================
do $$
declare f text;
begin
  foreach f in array array['aktarim_hakki()','ilk_adimlar()','tarih_arsivi()','parti_kimlikleri()','parti_kimlik_ayarla(int,int,text)',
    'kimlik_guncelle(text,text)','kimlikler(text[])','miting_duzenle(bigint,timestamptz,text)','miting_katil(bigint)','mitingler()',
    'miting_haklarim()','admin_transferler_sayfa(integer,integer,text,numeric)','para_gonder(text,numeric,text)','meclis()','harita()',
    'admin_kurallar(jsonb)','vatandaslik()','oy_ver(bigint,bigint)','il_detay(integer)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- =====================================================================
--  Veri güncellemeleri (tekrar çalıştırılınca bir şey değiştirmez)
-- =====================================================================
-- Kumbara: 16 saat (yasayla 12–24 arası değiştirilebilir). Kabul edilmiş bir yasa değeri varsa ona dokunulmaz.
update oyun.duzenleme_tanim set varsayilan = 16, min = 12, max = 24, adim = 1,
  aciklama = 'Maaşın en fazla kaç saat birikir. Günde bir kez giren oyuncu kaybetmesin diye 16 saat.'
where kod = 'kumbara_saat' and (varsayilan, min, max) is distinct from (16::numeric, 12::numeric, 24::numeric);

-- Henüz kapanmamış seçimlerin sandık saatleri: 08:00–22:00, sonuç 22:30 (ara seçimde göreve başlama 23:00)
update oyun.secimler s set
  oy_bit   = oyun.tr_an((s.oy_bas at time zone 'Europe/Istanbul')::date, 22),
  sonuc_at = oyun.tr_an((s.oy_bas at time zone 'Europe/Istanbul')::date, 22, 30),
  goreve_bas = case when s.goreve_bas is not null and extract(hour from s.goreve_bas at time zone 'Europe/Istanbul') = 19
                    then oyun.tr_an((s.goreve_bas at time zone 'Europe/Istanbul')::date, 23) else s.goreve_bas end
where s.durum = 'bekliyor' and s.oy_bit > oyun.simdi()
  and extract(hour from s.oy_bit at time zone 'Europe/Istanbul') = 17;

-- Henüz açılmamış aday adaylığı başvuruları 3 güne çıkar
update oyun.secimler s set basvuru_bas = greatest(oyun.simdi(), s.basvuru_bas - interval '2 days')
where s.durum = 'bekliyor' and not s.ara and s.tur in ('bel_on','mv_on') and s.basvuru_bas > oyun.simdi()
  and extract(day from s.basvuru_bas at time zone 'Europe/Istanbul') in (6, 26);
update oyun.secimler s set basvuru_bit = s.basvuru_bit + interval '1 day'
where s.durum = 'bekliyor' and not s.ara and s.tur = 'cb_on' and s.basvuru_bit > oyun.simdi()
  and extract(day from s.basvuru_bit at time zone 'Europe/Istanbul') = 27;

-- Genel başkansız kalan partide otomatik halef: önce son 7 günde oyuna girmiş üyeler arasından en kıdemlisi
CREATE OR REPLACE FUNCTION oyun.gb_halef(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare pa record; aday uuid;
begin
  for pa in select id, ad from oyun.partiler where not kapali and gb is null loop
    select pr.id into aday from oyun.profiller pr
     where pr.parti_id = pa.id and not pr.yasakli
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur not in ('cb','mv'))
     order by (coalesce(pr.son_gorulme, pr.olusturma) > t - interval '7 days') desc, oyun.kidem_puani(pr.id) desc, pr.parti_at, pr.id limit 1;
    continue when aday is null;
    delete from oyun.parti_gby where user_id = aday;       -- genel başkan aynı zamanda yardımcı olamaz
    update oyun.partiler set gb = aday where id = pa.id and gb is null;
    perform oyun.bildir(aday, format('%s kurultayda genel başkansız kaldığı için kıdemin en yüksek olduğu üye olarak genel başkan oldun. Bir sonraki kurultayda üyeler genel başkanı yeniden seçecek; 6 genel başkan yardımcını atayabilirsin.', pa.ad), t);
    perform oyun.olay('parti', format('%s genel başkansız kaldı; kıdemi en yüksek üye %s genel başkan oldu.', pa.ad, (select kad from oyun.profiller where id = aday)), null, pa.id, t);
  end loop;
end $function$;

-- HATA DÜZELTMESİ: genel seçim sayımı "l.aday_id is ambiguous" hatasıyla duruyordu (ilk genel seçimde motor kilitlenirdi)
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
    from _b23_liste bl                      -- "l" kayıt değişkeniyle çakışmasın (aday_id belirsizliği hatası)
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
end $function$;

-- HATA DÜZELTMESİ: yedekten dönüş, "generated always" kimlik sütunlu tablolarda (8 Ekim'den beri) hata veriyordu
create or replace function oyun.yedekten_don(p_sema text, p_onay text) returns text language plpgsql as $$
declare y text; t record; liste text; kalan text[]; tur int := 0; sutunlar text; ok boolean; n int;
begin
  if p_onay is distinct from 'GERİ YÜKLE' then
    raise exception 'Geri yüklemek için: select oyun.yedekten_don(''%'', ''GERİ YÜKLE'');', p_sema;
  end if;
  if p_sema !~ '^yedek_' or not exists (select 1 from pg_namespace where nspname = p_sema) then raise exception 'Yedek bulunamadı: %', p_sema; end if;
  y := oyun.yedek_al('Geri yükleme öncesi');
  perform set_config('oyun.sifirlama', 'evet', true);
  select array_agg(c.relname::text) into kalan from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'oyun' and c.relkind = 'r' and c.relname <> 'surumler'
     and exists (select 1 from pg_class c2 join pg_namespace n2 on n2.oid = c2.relnamespace where n2.nspname = p_sema and c2.relname = c.relname);
  select string_agg(format('oyun.%I', x), ', ') into liste from unnest(kalan) x;
  execute 'truncate ' || liste || ' cascade';
  foreach liste in array kalan loop execute format('alter table oyun.%I disable trigger user', liste); end loop;
  -- yabancı anahtar sırası bilinmediği için birkaç turda yükle
  while array_length(kalan, 1) > 0 and tur < 10 loop
    tur := tur + 1;
    foreach liste in array kalan loop
      select string_agg(format('%I', a.attname), ', ') into sutunlar
        from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'oyun' and c.relname = liste and a.attnum > 0 and not a.attisdropped and a.attgenerated = ''
         and exists (select 1 from pg_attribute b join pg_class c2 on c2.oid = b.attrelid join pg_namespace n2 on n2.oid = c2.relnamespace
                     where n2.nspname = p_sema and c2.relname = liste and b.attname = a.attname and not b.attisdropped);
      ok := true;
      begin
        -- overriding system value: "generated always as identity" sütunlu tablolar da yedekten dönebilsin
        execute format('insert into oyun.%I (%s) overriding system value select %s from %I.%I', liste, sutunlar, sutunlar, p_sema, liste);
      exception when foreign_key_violation then ok := false;
      end;
      if ok then kalan := array_remove(kalan, liste); end if;
    end loop;
  end loop;
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r' loop
    execute format('alter table oyun.%I enable trigger user', t.relname);
  end loop;
  if array_length(kalan, 1) > 0 then raise exception 'Geri yükleme tamamlanamadı (%); hiçbir şey değişmedi.', array_to_string(kalan, ', '); end if;
  -- kimlik sayaçlarını yedekteki en büyük değere getir
  for t in select s.relname seq, tc.relname tablo, a.attname sutun from pg_class s
             join pg_depend d on d.objid = s.oid and d.deptype in ('a','i') join pg_class tc on tc.oid = d.refobjid
             join pg_attribute a on a.attrelid = tc.oid and a.attnum = d.refobjsubid join pg_namespace n on n.oid = tc.relnamespace
            where s.relkind = 'S' and n.nspname = 'oyun' loop
    execute format('select coalesce(max(%I), 0) from oyun.%I', t.sutun, t.tablo) into n;
    if n > 0 then execute format('select setval(%L, %s)', 'oyun.' || t.seq, n); end if;
  end loop;
  return format('%s yedeğine dönüldü. Dönüş öncesi durumun yedeği: %s', p_sema, y);
end $$;

commit;
