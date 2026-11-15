-- 15.11.2026 RÜTBE REFORMU / Kalıcı lansman dengesi
-- Oyuncu parası, kıdemi, makamı, oyları ve şirketleri değişmez.
-- Rütbeler (0/10/30/75/150/300), şirket limitleri (0/1/2/3/5/8) korunur.
-- Tek seferlik %5/basamak kıdem primi; hükümet sonradan değiştirebilir.
do $rutbe_ilk$
begin
  if not exists(select 1 from oyun.tarife where kod='rutbe_reformu_20261115') then
    update oyun.ulke set kidem_primi=5 where id=1 and kidem_primi=0;
    insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira)
    values ('rutbe_reformu_20261115',1,'adet','sistem','Rütbe lansman dengesi',
      'Bir defalık maaş primi başlangıcı; hükümetin sonraki ayarları korunur.',999)
    on conflict(kod) do nothing;
  end if;
end
$rutbe_ilk$;

-- Mevcut statü API'siyle geriye uyumlu prestij rozetleri.
-- Seçim ve kamu görevleri için otomatik üstünlük sağlamaz.
CREATE OR REPLACE FUNCTION oyun.statu_json(u uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
  with x as (select oyun.kidem_puani(u) puan), y as (select puan, oyun.statu_basamak(puan) b from x)
  select jsonb_build_object('puan', puan, 'basamak', b, 'ad', oyun.statu_ad(b),
           'carpan', round(1 + b * (select kidem_primi from oyun.ulke where id = 1) / 100, 3),
           'sonraki_ad', case when b < 5 then oyun.statu_ad(b + 1) end, 'sonraki_esik', case when b < 5 then oyun.statu_esik(b + 1) end,
           'bu_esik', oyun.statu_esik(b),
           'simge', (array['○','●','★','✦','🏅','👑'])[b + 1],
           'onur_unvani', case when b = 5 then 'Yaşayan Efsane Nişanı' when b = 4 then 'Duayen Rozeti' end,
           'sirket_hakki', oyun.tf('slot_' || b)::int)
  from y
$function$;

-- Prim %0 olduğunda yanıltıcı maaş bildirimi verme.
CREATE OR REPLACE FUNCTION public.topla()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; g jsonb; bugun date := (t at time zone 'Europe/Istanbul')::date;
        tutar numeric; ilk boolean; des numeric := 0; hem numeric := 0; kx numeric; once int; sonra int;
begin
  c := oyun.cuzdanim(p.id);
  g := oyun.gelir_hesap(p.id, t);
  tutar := (g ->> 'birikmis')::numeric;
  ilk := c.seri_gun is distinct from bugun;
  if tutar < 1 and not ilk then raise exception 'Kumbaran henüz boş. Maaşın saat saat birikiyor.'; end if;
  once := oyun.statu_basamak(oyun.kidem_puani(p.id));
  if tutar >= 1 then
    perform oyun.para_islem(p.id, tutar, 'maas',
      format('Maaş (%s saat%s)', replace(round((g ->> 'saat')::numeric, 1)::text, '.', ','),
             case when (g ->> 'seri_bonus')::numeric > 0 then format(', seri +%%%s', g ->> 'seri_bonus') else '' end),
      t, (g ->> 'vergi_birikmis')::numeric);
    perform oyun.haciz_uygula(p.id, tutar, t);   -- takipteki kredi: maaşın yarısına haciz (15_ekonomi3)
  end if;
  if ilk then
    kx := 1 + oyun.bonus(p.il_id, 'kidem_x', t) / 100;
    update oyun.cuzdan set seri = (g ->> 'seri')::int, seri_gun = bugun, kidem = kidem + kx where user_id = p.id;
    des := (g -> 'gunluk_destek' ->> 'devlet')::numeric; hem := (g -> 'gunluk_destek' ->> 'belediye')::numeric;
    if des > 0 then perform oyun.para_islem(p.id, des, 'destek', 'Devlet sosyal desteği (günlük)', t); end if;
    if hem > 0 then perform oyun.para_islem(p.id, hem, 'hemsehri', (select ad from oyun.iller where id = p.il_id) || ' Belediyesi hemşehri desteği', t); end if;
    perform oyun.gunluk_kesinti(p.id, t);       -- servet vergisi ve emlak vergisi (mevzuat)
  end if;
  update oyun.cuzdan set son_toplama = t, kumbara_bildirim = null where user_id = p.id;
  sonra := oyun.statu_basamak(oyun.kidem_puani(p.id));
  if sonra > once then
    perform oyun.bildir(p.id, format('Tebrikler! Statün yükseldi: %s.%s', oyun.statu_ad(sonra),
      case when coalesce((select kidem_primi from oyun.ulke where id=1), 0)>0 then ' Maaşın arttı.'
           else ' Yeni haklarını Fiyat Tarifesi ekranında incele.' end), t);
  end if;
  return public.hayat() || jsonb_build_object('sonuc', jsonb_build_object('maas', tutar, 'ilk', ilk, 'seri', (g ->> 'seri')::int,
    'destek', des + hem, 'statu_atladi', sonra > once));
end $function$;
