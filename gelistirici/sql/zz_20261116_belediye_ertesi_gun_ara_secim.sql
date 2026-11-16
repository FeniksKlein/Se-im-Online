-- Belediye baskanligi bosalinca ertesi gun 08-22 yalniz hedef ilde secim; 23:00 devir.
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
  ilk_gun := oyun.secim_ilk_oy_gunu(t); -- önce adaylık (en az 24 saat), sonra ön seçim, sonra seçim
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
    if p_il is null then raise exception 'Belediye ara secimi icin il gerekli.'; end if;
    -- Baskanlik bosaldigi gun adaylik; ertesi gun yalniz o ilin secmenleri sandikta.
    ilk_gun := (t at time zone 'Europe/Istanbul')::date + 1;
    select * into o from oyun.secimler
     where tur='bel' and ara and hedef_il_id=p_il
       and durum<>'tamam' and coalesce(goreve_bas,sonuc_at)>t
     order by coalesce(goreve_bas,sonuc_at) limit 1;
    if o.id is not null then
      return jsonb_build_object('secim_id',o.id,'tur','bel','ara',true,'mevcut',true,
        'oy_bas',o.oy_bas,'goreve_bas',o.goreve_bas);
    end if;
    dm := 'ara-bel-'||p_il||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
    -- Oyun sahibinin ozel kuralı: yalniz bosalan ilde ertesi gun secim.
    -- Genel takvim duzelticisi 'on secimden sonraki gun' diye bu ozel sandigi erteleyemez.
    insert into oyun.secim_takvim_istisna(donem,neden,onaylayan)
    values(dm,'Belediye baskanligi bosalinca yalniz ilgili ilde ertesi gun secim; oyunun ozel belediye ara secimi kurali','Oyun sahibi (2026-11-16 karari)')
    on conflict(donem) do nothing;
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,hedef_il_id,ara_neden)
    values ('bel_on',dm,t,oyun.tr_an(ilk_gun,6),
      oyun.tr_an(ilk_gun,6),oyun.tr_an(ilk_gun,7),
      oyun.tr_an(ilk_gun,7,5),null,true,p_il,'belediye_baskanligi_bosaldi')
    returning id into on_id;
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,hedef_il_id,ara_neden)
    values ('bel',dm,null,null,oyun.tr_an(ilk_gun,8),
      oyun.tr_an(ilk_gun,22),oyun.tr_an(ilk_gun,22,15),oyun.tr_an(ilk_gun,23),
      true,p_il,'belediye_baskanligi_bosaldi')
    returning id into asil_id;
    perform oyun.olay('secim',format('%s ilinde belediye baskanligi bosaldi: ertesi gun yalniz bu ilde secim yapilacak.',(select ad from oyun.iller where id=p_il)),p_il,null,t);
    return jsonb_build_object('secim_id',asil_id,'on_secim_id',on_id,'tur','bel','ara',true,'mevcut',false,
      'oy_bas',oyun.tr_an(ilk_gun,8),'goreve_bas',oyun.tr_an(ilk_gun,23));

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

