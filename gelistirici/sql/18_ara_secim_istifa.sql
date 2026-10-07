-- =====================================================================
-- SEÇİM SİMÜLASYONU ONLINE — 18) İSTİFA + OLAĞANÜSTÜ SEÇİMLER
-- Canlı Supabase sürümü: 2026.10.07-5
-- Bu dosya canlı fonksiyonlarla eşitlenmiştir; oyuncu verisini silmez.
-- =====================================================================

alter table oyun.secimler add column if not exists ara boolean not null default false;
alter table oyun.secimler add column if not exists hedef_parti_id bigint references oyun.partiler(id);
alter table oyun.secimler add column if not exists hedef_il_id smallint references oyun.iller(id);
alter table oyun.secimler add column if not exists ara_neden text;

create index if not exists secimler_ara_hedef_parti
  on oyun.secimler(hedef_parti_id, durum, goreve_bas) where ara;
create index if not exists secimler_ara_hedef_il
  on oyun.secimler(hedef_il_id, durum, goreve_bas) where ara;

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
    oyun.tr_an(gun+1,17),
    oyun.tr_an(gun+1,18),
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
end $function$

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

    asil_bas := oyun.tr_an(ilk_gun, 19);

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
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,17),
      oyun.tr_an(ilk_gun,18), asil_bas,
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

    asil_bas := oyun.tr_an(ikinci_gun, 19);

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
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,17),
      oyun.tr_an(ilk_gun,18), null,
      true, p_il, 'belediye_baskani_istifa'
    )
    returning id into on_id;

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, hedef_il_id, ara_neden
    ) values (
      'bel', dm,
      null, null,
      oyun.tr_an(ikinci_gun,8), oyun.tr_an(ikinci_gun,17),
      oyun.tr_an(ikinci_gun,18), asil_bas,
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

    asil_bas := oyun.tr_an(ikinci_gun, 19);

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
      oyun.tr_an(ilk_gun,8), oyun.tr_an(ilk_gun,17),
      oyun.tr_an(ilk_gun,18), null,
      true, 'cumhurbaskani_istifa'
    )
    returning id into on_id;

    insert into oyun.secimler(
      tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas,
      ara, ara_neden
    ) values (
      'cb', dm,
      t, oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ikinci_gun,8), oyun.tr_an(ikinci_gun,17),
      oyun.tr_an(ikinci_gun,18), asil_bas,
      true, 'cumhurbaskani_istifa'
    )
    returning id into asil_id;

    return jsonb_build_object(
      'secim_id', asil_id, 'on_secim_id', on_id,
      'tur', 'cb', 'ara', true, 'mevcut', false,
      'oy_bas', oyun.tr_an(ikinci_gun,8), 'goreve_bas', asil_bas
    );
  end if;
end $function$

CREATE OR REPLACE FUNCTION oyun.gb_halef(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  pa record;
  aday uuid;
begin
  for pa in
    select id, ad
    from oyun.partiler
    where not kapali
      and gb is null
      and not exists(
        select 1
        from oyun.secimler s
        where s.tur = 'kurultay'
          and s.ara
          and s.hedef_parti_id = oyun.partiler.id
          and s.durum = 'bekliyor'
      )
  loop
    select pr.id into aday
    from oyun.profiller pr
    where pr.parti_id = pa.id
      and not pr.yasakli
      and not exists(
        select 1
        from oyun.makamlar m
        where m.user_id = pr.id
          and m.bit is null
          and m.tur <> 'cb'
      )
    order by oyun.kidem_puani(pr.id) desc, pr.parti_at, pr.id
    limit 1;

    continue when aday is null;

    delete from oyun.parti_gby where user_id = aday;
    update oyun.partiler
    set gb = aday
    where id = pa.id and gb is null;

    perform oyun.bildir(
      aday,
      format(
        '%s kurultayda genel başkansız kaldığı için kıdemin en yüksek olduğu üye olarak genel başkan oldun. Bir sonraki kurultayda üyeler genel başkanı yeniden seçecek; 6 genel başkan yardımcını atayabilirsin.',
        pa.ad
      ),
      t
    );

    perform oyun.olay(
      'parti',
      format(
        '%s genel başkansız kaldı; kıdemi en yüksek üye %s genel başkan oldu.',
        pa.ad,
        (select kad from oyun.profiller where id = aday)
      ),
      null, pa.id, t
    );
  end loop;
end $function$

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
$function$

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
          when 'bel_on' then 'Belediye başkanlığı aday adaylığı başvuruları bugün açık. Adayını çıkar!'
          when 'mv_on' then 'Milletvekili aday adaylığı başvuruları bugün açık. Listeye girmek için başvur!'
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
        'Genel seçim ve cumhurbaşkanlığı seçimi sandıkları 17:00''ye kadar açık.',
        v
      );

    elsif s.tur in ('cb','cb2') then
      perform oyun.push_konuya(
        's_tum', null,
        case when s.tur = 'cb2' then 'Cumhurbaşkanlığı 2. turu'
             when s.ara then 'Olağanüstü cumhurbaşkanlığı seçimi'
             else 'Cumhurbaşkanlığı seçimi' end,
        'Sandıklar 17:00''de kapanıyor. Oyunu kullanmayı unutma!',
        v
      );

    elsif s.tur = 'bel' then
      if s.ara and s.hedef_il_id is not null then
        perform oyun.push_konuya(
          's_il_' || s.hedef_il_id,
          null,
          'Olağanüstü belediye seçimi 🗳️',
          format('%s belediye başkanlığı sandığı 17:00''ye kadar açık.',
                 (select ad from oyun.iller where id = s.hedef_il_id)),
          v
        );
      else
        perform oyun.push_konuya(
          's_tum', null,
          'Bugün belediye seçimi var! 🗳️',
          'İl belediye başkanlığı sandıkları 17:00''ye kadar açık.',
          v
        );
      end if;

    elsif s.tur in ('bel_on','mv_on','kurultay','cb_on') then
      if s.ara and s.tur = 'kurultay' and s.hedef_parti_id is not null then
        perform oyun.push_konuya(
          's_parti_' || s.hedef_parti_id,
          null,
          'Olağanüstü kurultay başladı',
          'Yeni genel başkanı seçmek için oyunu 17:00''ye kadar kullan.',
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
            format('%s belediye başkanı ön seçimi 17:00''ye kadar.',
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
              when 'bel_on' then 'Belediye başkanı ön seçimi bugün 17:00''ye kadar.'
              when 'mv_on' then 'Milletvekili ön seçimi bugün 17:00''ye kadar. Liste sırasını sen belirle!'
              when 'cb_on' then 'Cumhurbaşkanı aday ön seçimi bugün 17:00''ye kadar.'
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
end $function$

CREATE OR REPLACE FUNCTION oyun.secim_ozet(s oyun.secimler, p oyun.profiller, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'id', s.id,
    'tur', s.tur,
    'donem', s.donem,
    'asama', oyun.asama(s,t),
    'basvuru_bas', s.basvuru_bas,
    'basvuru_bit', s.basvuru_bit,
    'oy_bas', s.oy_bas,
    'oy_bit', s.oy_bit,
    'sonuc_at', s.sonuc_at,
    'goreve_bas', s.goreve_bas,
    'ara', s.ara,
    'hedef_il_id', s.hedef_il_id,
    'hedef_il_ad', (select ad from oyun.iller where id = s.hedef_il_id),
    'hedef_parti_id', s.hedef_parti_id,
    'hedef_parti', oyun.parti_json(s.hedef_parti_id),
    'ara_neden', s.ara_neden,
    'adayim', exists(
      select 1 from oyun.adaylar a
      where a.secim_id = s.id and a.user_id = p.id
    ),
    'oy_verdim', exists(
      select 1 from oyun.oylar o
      where o.secim_id = s.id and o.secmen = p.id
    ),
    'oy_engeli', oyun.oy_engeli(p,s),
    'katilim', case
      when s.durum <> 'bekliyor' or t >= s.oy_bas
      then (select count(*) from oyun.oylar o where o.secim_id = s.id)
    end
  )
$function$

CREATE OR REPLACE FUNCTION oyun.tbmm_ara_secim(t timestamp with time zone)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare sid bigint;
begin
  select id into sid
  from oyun.meclis_secim
  where tur = 'baskan' and durum <> 'bitti'
  order by id desc
  limit 1;

  if sid is null then
    insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit)
    values (null, 'baskan', t, t + interval '24 hours')
    returning id into sid;

    perform oyun.olay(
      'meclis',
      'TBMM Başkanlığı boşaldı. Ara seçim için adaylık 24 saat açık.',
      null, null, t
    );
  end if;

  return sid;
end $function$

CREATE OR REPLACE FUNCTION public.aday_ol(p_tur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  k oyun.cb_kararlar;
begin
  if p_tur not in ('mv_on','bel_on','kurultay','cb_on') then
    raise exception 'Geçersiz adaylık türü.';
  end if;

  select * into s
  from oyun.secimler
  where tur = p_tur
    and t >= basvuru_bas
    and t < basvuru_bit
    and (
      not ara
      or (p_tur = 'bel_on' and hedef_il_id = p.il_id)
      or (p_tur = 'kurultay' and hedef_parti_id = p.parti_id)
      or p_tur = 'cb_on'
    )
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Bu adaylık için başvuru şu anda açık değil.';
  end if;
  if p.parti_id is null then
    raise exception 'Aday olmak için bir partiye üye olmalısın.';
  end if;
  if p.parti_at > s.basvuru_bas then
    raise exception 'Bu dönem aday olabilmek için başvurular açılmadan önce partiye üye olmalıydın.';
  end if;
  if oyun.uyari(p,t) is not null then
    raise exception '%', oyun.uyari(p,t);
  end if;
  if (select kurulus_bit from oyun.partiler where id = p.parti_id) is not null then
    raise exception 'Partin henüz kuruluş aşamasında: kurucu üye sayısı tamamlanmadan seçime katılamaz.';
  end if;

  if s.ara and s.hedef_il_id is not null
     and p.il_id is distinct from s.hedef_il_id then
    raise exception 'Bu ara seçim senin ilin için değil.';
  end if;

  if s.ara and s.hedef_parti_id is not null
     and p.parti_id is distinct from s.hedef_parti_id then
    raise exception 'Bu olağanüstü kurultay senin partin için değil.';
  end if;

  if p_tur in ('mv_on','bel_on')
     and exists(select 1 from oyun.partiler where gb = p.id) then
    raise exception 'Genel başkan milletvekili ya da belediye başkanı adayı olamaz. Genel başkan yalnızca cumhurbaşkanı adayı olabilir.';
  end if;

  if oyun.teskilat_engeli(p,p_tur) is not null then
    raise exception '%', oyun.teskilat_engeli(p,p_tur);
  end if;

  if p_tur = 'cb_on' then
    select * into k
    from oyun.cb_kararlar
    where donem = s.donem and parti_id = p.parti_id;

    if k.yontem in ('kendisi','baskasi') then
      raise exception 'Genel başkan cumhurbaşkanı adayını doğrudan belirledi; ön seçim yapılmayacak.';
    end if;
    if k.yontem = 'destek' then
      raise exception 'Partin cumhurbaşkanlığında ittifak ortağının adayını destekliyor; ön seçim yapılmayacak.';
    end if;
  end if;

  insert into oyun.adaylar(
    secim_id, user_id, parti_id, il_id, basvuru_at
  )
  values (
    s.id, p.id, p.parti_id,
    case when p_tur in ('mv_on','bel_on') then p.il_id end,
    t
  )
  on conflict(secim_id,user_id) do nothing;

  if not found then
    raise exception 'Bu seçime zaten başvurdun.';
  end if;

  perform oyun.aday_ucreti_al(p,p_tur,t);
  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.cb_aday_belirle(p_yontem text, p_kad text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  pa oyun.partiler;
  hedef oyun.profiller;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then
    raise exception 'Bu kararı yalnızca genel başkan verebilir.';
  end if;

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

  if p_yontem not in ('kendisi','baskasi','onsecim') then
    raise exception 'Geçersiz yöntem.';
  end if;

  if p_yontem = 'kendisi' then
    hedef := p;
  elsif p_yontem = 'baskasi' then
    select * into hedef
    from oyun.profiller
    where lower(kad) = lower(btrim(coalesce(p_kad,'')));

    if hedef.id is null or hedef.parti_id is distinct from pa.id then
      raise exception 'Aday partinin üyesi olmalı.';
    end if;
  end if;

  if hedef.id is not null and oyun.uyari(hedef,t) is not null then
    raise exception 'Aday için: %', oyun.uyari(hedef,t);
  end if;

  insert into oyun.cb_kararlar(
    donem, parti_id, yontem, aday, zaman
  )
  values (
    s.donem, pa.id, p_yontem, hedef.id, t
  )
  on conflict(donem,parti_id) do update
    set yontem = excluded.yontem,
        aday = excluded.aday,
        destek_parti = null,
        zaman = excluded.zaman;

  delete from oyun.adaylar
  where secim_id = s.id and parti_id = pa.id;

  if hedef.id is not null then
    insert into oyun.adaylar(
      secim_id,user_id,parti_id,basvuru_at
    )
    values (
      s.id,hedef.id,pa.id,t
    );
  end if;

  return public.durum();
end $function$

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

  if not exists(
    select 1
    from oyun.ittifak_uyeler a
    join oyun.ittifak_uyeler b on a.ittifak_id = b.ittifak_id
    where a.parti_id = pa.id
      and b.parti_id = hedef.id
  ) then
    raise exception 'Yalnızca ittifak ortağının adayını destekleyebilirsin.';
  end if;

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

CREATE OR REPLACE FUNCTION public.durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  u uuid := oyun.ben();
  p oyun.profiller;
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  gun int := oyun.il_bekleme_gun(oyun.simdi());
begin
  select * into p from oyun.profiller where id = u;

  if p.id is null then
    return jsonb_build_object('simdi',t,'profil',null);
  end if;

  if p.yasakli then
    raise exception 'Hesabın kural ihlali nedeniyle kapatıldı. İtiraz için oyun yönetimine e-posta gönderebilirsin.';
  end if;

  if p.son_gorulme is null or p.son_gorulme < t - interval '5 minutes' then
    update oyun.profiller
    set son_gorulme = t
    where id = p.id;
  end if;

  select * into pa
  from oyun.partiler
  where id = p.parti_id;

  return jsonb_build_object(
    'simdi', t,

    'profil', jsonb_build_object(
      'id', p.id,
      'kad', p.kad,
      'il_id', p.il_id,
      'il_ad', (select ad from oyun.iller where id = p.il_id),
      'olusturma', p.olusturma,
      'parti', oyun.parti_json(p.parti_id),
      'parti_at', p.parti_at,
      'gb', pa.gb = p.id,
      'gby', exists(
        select 1 from oyun.parti_gby g where g.user_id = p.id
      ),
      'il_kilit', oyun.il_kilit_nedeni(t),
      'il_serbest', case
        when p.son_il_degis is null then null
        else p.son_il_degis + make_interval(days => gun)
      end,
      'makamlar', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'tur',m.tur,
            'il_id',m.il_id,
            'il_ad',i.ad,
            'bas',m.bas,
            'kaynak',m.kaynak,
            'bakanlik',m.bakanlik,
            'bakanlik_ad',(
              select ad from oyun.bakanliklar b where b.kod = m.bakanlik
            )
          )
        )
        from oyun.makamlar m
        left join oyun.iller i on i.id = m.il_id
        where m.user_id = p.id and m.bit is null
      ), '[]'::jsonb),
      'hesap_engeli', oyun.uyari(p,t),
      'cb_mi', exists(
        select 1 from oyun.makamlar m
        where m.user_id = p.id
          and m.tur = 'cb'
          and m.bit is null
      ),
      'yonetici', p.yonetici,
      'bildirim_ayar', p.bildirim_ayar,
      'yetkiler', oyun.yetkilerim(p.id),
      'kredi_uyari', oyun.kredi_uyari(p.id),
      'cuzdan', oyun.cuzdan_ozet(p.id,t)
    ),

    'okunmamis', oyun.okunmamis(p),

    'takvim', coalesce((
      select jsonb_agg(
        oyun.secim_ozet(s,p,t)
        order by coalesce(s.basvuru_bas,s.oy_bas), oyun.oncelik(s.tur)
      )
      from oyun.secimler s
      where coalesce(s.goreve_bas,s.sonuc_at) >= t - interval '3 days'
        and coalesce(s.basvuru_bas,s.oy_bas) <= t + interval '40 days'
        and (
          not s.ara
          or s.tur in ('cb','cb_on','cb2')
          or s.hedef_il_id = p.il_id
          or s.hedef_parti_id = p.parti_id
        )
    ), '[]'::jsonb),

    'cb', (
      select jsonb_build_object(
        'kad', oyun.kad(m.user_id),
        'parti', oyun.parti_json(m.parti_id),
        'bas', m.bas
      )
      from oyun.makamlar m
      where m.tur = 'cb' and m.bit is null
      limit 1
    ),

    'cb_karar', case
      when pa.gb = p.id then (
        select jsonb_build_object(
          'secim_id',s.id,
          'donem',s.donem,
          'acik',t >= s.basvuru_bas and t < s.basvuru_bit,
          'yontem',k.yontem,
          'aday',oyun.kad(k.aday),
          'son',s.basvuru_bit,
          'destek',(select kisa from oyun.partiler where id = k.destek_parti),
          'ara',s.ara
        )
        from oyun.secimler s
        left join oyun.cb_kararlar k
          on k.donem = s.donem
         and k.parti_id = pa.id
        where s.tur = 'cb'
          and s.durum = 'bekliyor'
        order by s.ara desc, s.oy_bas
        limit 1
      )
    end
  );
end $function$

CREATE OR REPLACE FUNCTION public.genel_baskanlik_uslen()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  c text;
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali
  for update;

  if pa.id is null then
    raise exception 'Önce bir partiye üye olmalısın.';
  end if;
  if pa.gb is not null then
    raise exception 'Partinin genel başkanı var.';
  end if;

  if exists(
    select 1
    from oyun.secimler s
    where s.tur = 'kurultay'
      and s.ara
      and s.hedef_parti_id = pa.id
      and s.durum <> 'tamam'
  ) then
    raise exception 'Genel başkan istifa ettiği için olağanüstü kurultay süreci başladı. Yeni genel başkan seçimle belirlenecek.';
  end if;

  select oyun.rol_ad(r) into c
  from unnest(oyun.roller(p.id)) r
  where r <> 'gby'
    and not oyun.rol_uyumlu(r,'gb')
  limit 1;

  if c is not null then
    raise exception 'Şu anda % görevindesin; genel başkan olmak için önce o görevden istifa etmelisin.', c;
  end if;

  delete from oyun.parti_gby where user_id = p.id;
  update oyun.partiler set gb = p.id where id = pa.id;

  perform oyun.olay(
    'parti',
    format(
      '%s genel başkansız kalan %s partisinin genel başkanlığını üstlendi.',
      p.kad, pa.ad
    ),
    null, pa.id, t
  );

  perform oyun.bildir(
    p.id,
    format(
      '%s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilir, seçim beyannamesini yazabilirsin. Bir sonraki kurultayda üyeler genel başkanı yeniden seçer.',
      pa.ad
    ),
    t
  );

  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.istifa(p_gorev text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  m oyun.makamlar;
  cb uuid;
  pa oyun.partiler;
  sec jsonb;
begin
  if p_gorev = 'bakan' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'bakan' and bit is null;

    if m.id is null then raise exception 'Bakan değilsin.'; end if;

    perform oyun.makam_bitir(m.id,t,'istifa');

    select user_id into cb
    from oyun.makamlar
    where tur = 'cb' and bit is null
    limit 1;

    if cb is not null then
      perform oyun.bildir(
        cb,
        format(
          '%s, %s görevinden istifa etti.',
          p.kad,
          oyun.makam_ad('bakan',null,m.bakanlik)
        ),
        t
      );
    end if;

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti.',
        p.kad,
        oyun.makam_ad('bakan',null,m.bakanlik)
      ),
      null, p.parti_id, t
    );

  elsif p_gorev = 'mv' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'mv' and bit is null;

    if m.id is null then raise exception 'Milletvekili değilsin.'; end if;

    perform oyun.makam_bitir(m.id,t,'istifa');

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti.',
        p.kad,
        oyun.makam_ad(m.tur,m.il_id,null)
      ),
      m.il_id, p.parti_id, t
    );

  elsif p_gorev = 'bel' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'bel' and bit is null
    for update;

    if m.id is null then
      raise exception 'Belediye başkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    sec := oyun.ara_secim_olustur('bel',null,m.il_id,t);

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti. Yeni başkan en yakın seçimde belirlenecek.',
        p.kad,
        oyun.makam_ad(m.tur,m.il_id,null)
      ),
      m.il_id, p.parti_id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      id,
      t,
      format(
        '%s Belediye Başkanı istifa etti. Yeni başkan için seçim takvimi oluşturuldu.',
        (select ad from oyun.iller where id = m.il_id)
      )
    from oyun.profiller
    where il_id = m.il_id and id <> p.id;

  elsif p_gorev = 'cb' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'cb' and bit is null
    for update;

    if m.id is null then
      raise exception 'Cumhurbaşkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    sec := oyun.ara_secim_olustur('cb',null,null,t);

    perform oyun.olay(
      'makam',
      format(
        '%s Cumhurbaşkanlığı görevinden istifa etti. Olağanüstü seçim takvimi oluşturuldu.',
        p.kad
      ),
      null, p.parti_id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      pa2.gb,
      t,
      'Cumhurbaşkanı istifa etti. Olağanüstü seçim için aday belirleme süreci başladı.'
    from oyun.partiler pa2
    where pa2.gb is not null
      and not pa2.kapali
      and pa2.gb <> p.id;

  elsif p_gorev = 'gb' then
    select * into pa
    from oyun.partiler
    where gb = p.id and not kapali
    for update;

    if pa.id is null then
      raise exception 'Genel başkan değilsin.';
    end if;

    update oyun.partiler
    set gb = null
    where id = pa.id;

    sec := oyun.ara_secim_olustur('gb',pa.id,null,t);

    perform oyun.olay(
      'parti',
      format(
        '%s, %s Genel Başkanlığından istifa etti. Olağanüstü kurultay takvimi oluşturuldu.',
        p.kad, pa.ad
      ),
      null, pa.id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      id,
      t,
      format(
        '%s Genel Başkanı istifa etti. Olağanüstü kurultay için adaylık süreci başladı.',
        pa.ad
      )
    from oyun.profiller
    where parti_id = pa.id and id <> p.id;

  elsif p_gorev = 'tbmm' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'tbmm' and bit is null
    for update;

    if m.id is null then
      raise exception 'TBMM Başkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    perform oyun.tbmm_ara_secim(t);

    perform oyun.olay(
      'meclis',
      format(
        '%s TBMM Başkanlığı görevinden istifa etti. Ara seçim süreci başladı.',
        p.kad
      ),
      null, p.parti_id, t
    );

  elsif p_gorev = 'gby' then
    delete from oyun.parti_gby where user_id = p.id;

    if not found then
      raise exception 'Genel başkan yardımcısı değilsin.';
    end if;

    perform oyun.bildir(
      (select gb from oyun.partiler where id = p.parti_id),
      format(
        '%s genel başkan yardımcılığından istifa etti.',
        p.kad
      ),
      t
    );

  else
    raise exception 'Geçersiz görev.';
  end if;

  return public.durum();
end $function$

CREATE OR REPLACE FUNCTION public.meclis_gorev_birak(p_tur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  m oyun.makamlar;
begin
  select * into m
  from oyun.makamlar
  where user_id = p.id
    and tur = p_tur
    and bit is null
    and tur in ('tbmm','bskv','grup_bskv');

  if m.id is null then
    raise exception 'Bu görevde değilsin.';
  end if;

  perform oyun.makam_bitir(m.id,t,'istifa');

  perform oyun.olay(
    'meclis',
    format(
      '%s, %s görevinden ayrıldı.',
      p.kad,
      oyun.rol_ad(p_tur)
    ),
    null, p.parti_id, t
  );

  if p_tur = 'tbmm' then
    perform oyun.tbmm_ara_secim(t);
  end if;

  return public.meclis_baskanlik();
end $function$

revoke all on function public.istifa(text) from public, anon;
grant execute on function public.istifa(text) to authenticated;
revoke all on function public.meclis_gorev_birak(text) from public, anon;
grant execute on function public.meclis_gorev_birak(text) to authenticated;
