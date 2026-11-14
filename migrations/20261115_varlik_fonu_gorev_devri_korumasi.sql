-- KALICI KURAL (15 Kasım 2026): Görevi biten yürütme, yeni hükümetin Hazine'yi
-- kullanmasını engelleyemez.
-- 1) Genel seçim süreci boyunca (adaylıktan yeni seçilenlerin göreve
--    başlamasına kadar) Hazine'den Varlık Fonu'na aktarım yapılamaz.
-- 2) Fondan çekimdeki 6 saat bekleme ve 7 günlük tavan, yalnız görevdeki
--    Cumhurbaşkanı/Başbakanın KENDİ görev süresindeki çekimlerine göre işler.
--    Selefin çekimleri halefin hakkını tüketmez.
-- Olay: 14 Kasım 23.47'de görevi bitmek üzere olan CB Hazine'nin tamamını
-- (958 milyar ₺) fona yatırıp 1 milyar çekerek beklemeyi başlattı.

-- Görevdeki yürütme başkanının göreve başlama anı.
create or replace function oyun.yurutme_bas() returns timestamptz
language sql stable set search_path='' as $$
  select case when oyun.hukumet_sistemi()=1
    then (select bas from oyun.hukumetler where durum='gorevde' and bit is null order by bas desc limit 1)
    else (select bas from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1)
  end
$$;

create or replace function public.varlik_fonu_aktar(p_yon text, p_tutar numeric, p_gerekce text default null::text)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v oyun.varlik_fonu; x numeric; cek numeric; hz numeric; gr text; b text;
        sistem text := case when oyun.hukumet_sistemi() = 1 then 'Başbakan' else 'Cumhurbaşkanı' end;
        gb timestamptz := coalesce(oyun.yurutme_bas(), '-infinity'::timestamptz);
begin
  if p.id is null or p.id is distinct from oyun.yurutme_user() then
    raise exception 'Varlık Fonu aktarımına yalnız görevdeki % karar verir.', lower(sistem);
  end if;
  if coalesce(p_yon, '') not in ('cek', 'yatir') then raise exception 'Geçersiz işlem.'; end if;
  if p_yon = 'yatir' and oyun.genel_secim_sureci_aktif(t) then
    raise exception 'Genel seçim süreci devam ediyor. Yeni seçilenler göreve başlayana kadar Hazine''den Varlık Fonu''na aktarım yapılamaz.';
  end if;
  x := round(coalesce(p_tutar, 0), 1);
  if x < 0.1 then raise exception 'Tutar en az 0,1 milyar ₺ (100 milyon ₺) olmalı.'; end if;
  gr := nullif(btrim(coalesce(p_gerekce, '')), '');
  if gr is not null then gr := oyun.metin_temizle(gr, 1500); end if;
  perform pg_advisory_xact_lock(920158, 1);
  select * into v from oyun.varlik_fonu where id = 1 for update;
  if p_yon = 'cek' and exists (select 1 from oyun.varlik_fonu_hareket h where h.tur = 'cek'
       and h.user_id = p.id and h.zaman >= gb and h.zaman > t - interval '6 hours') then
    raise exception 'Varlık Fonu''ndan çekim 6 saatte bir yapılabilir. Hazine''den fona iade/yatırım için bekleme yoktur.';
  end if;
  if p_yon = 'cek' then
    select coalesce(sum(h.tutar), 0) into cek from oyun.varlik_fonu_hareket h
     where h.tur = 'cek' and h.user_id = p.id and h.zaman >= gb and h.zaman > t - make_interval(days => v.aktarim_gun);
    if cek + x > v.aktarim_tavan then
      raise exception 'Varlık Fonu''ndan % günde en çok % milyar ₺ çekilebilir; kalan hak % milyar ₺.',
        v.aktarim_gun, oyun.bm_sayi(v.aktarim_tavan, 0), oyun.bm_sayi(greatest(0, v.aktarim_tavan - cek), 1);
    end if;
    if v.bakiye < x then raise exception 'Fonda yeterli varlık yok.'; end if;
    update oyun.varlik_fonu set bakiye = bakiye - x where id = 1;
    insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama, user_id)
    values (t, x, v.bakiye - x, 'cek', coalesce(gr, 'Hazine''ye aktarım'), p.id);
    perform oyun.hazine_kaydet('vf_aktarim', x, 'Varlık Fonu''ndan Hazine''ye aktarım');
    b := format('Türkiye Varlık Fonu''ndan Hazine''ye %s Milyar ₺ Aktarılması Hakkında Karar', oyun.bm_sayi(x, 1));
  else
    select u.hazine into hz from oyun.ulke u where u.id = 1;
    if hz < x then raise exception 'Hazine''de yeterli nakit yok (% milyar ₺ var).', oyun.bm_sayi(hz, 1); end if;
    perform oyun.hazine_kaydet('vf_aktarim', -x, 'Hazine''den Varlık Fonu''na aktarım');
    update oyun.varlik_fonu set bakiye = bakiye + x where id = 1;
    insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama, user_id)
    values (t, x, v.bakiye + x, 'yatir', coalesce(gr, 'Bütçe fazlası fona aktarıldı'), p.id);
    b := format('Hazine''den Türkiye Varlık Fonu''na %s Milyar ₺ Aktarılması Hakkında Karar', oyun.bm_sayi(x, 1));
  end if;
  perform oyun.gazete_ekle('kararname', b,
    coalesce(gr || ' ', '') || format('Aktarım finansman işlemidir; bütçe geliri ya da gideri sayılmaz. Fonda kalan varlık %s milyar ₺.',
      oyun.bm_sayi((select f.bakiye from oyun.varlik_fonu f where f.id = 1), 1)), null, t);
  perform oyun.olay('ekonomi', format('%s %s: %s', sistem, p.kad, b), null, p.parti_id, t);
  return public.butce_raporu(7);
end $function$;

-- TEK SEFERLİK ONARIM: 14 Kasım 23.47'deki son dakika aktarımlarını geri al.
-- Net 958,6 milyar ₺ Hazine'ye 'devir' olarak döner (çekim hakkı sayılmaz).
do $onarim$
declare
  t timestamptz := oyun.simdi();
  net numeric;
  v oyun.varlik_fonu;
begin
  perform pg_advisory_xact_lock(920158, 1);
  if exists(select 1 from oyun.tek_seferlik where anahtar='vf_devir_iade_20261115') then
    raise notice 'Onarim zaten yapilmis'; return;
  end if;
  insert into oyun.tek_seferlik(anahtar,zaman) values('vf_devir_iade_20261115',t);
  select coalesce(sum(case when tur='yatir' then tutar when tur='cek' then -tutar else 0 end),0) into net
    from oyun.varlik_fonu_hareket
   where user_id='c748a5a9-3325-43cb-ac52-d87f4019f796'
     and zaman between timestamptz '2026-11-14 20:40+00' and timestamptz '2026-11-14 21:00+00'
     and tur in ('yatir','cek');
  if net <= 0 then raise notice 'Geri alinacak tutar yok'; return; end if;
  select * into v from oyun.varlik_fonu where id=1 for update;
  if v.bakiye < net then raise exception 'Fon bakiyesi yetersiz'; end if;
  update oyun.varlik_fonu set bakiye=bakiye-net where id=1;
  insert into oyun.varlik_fonu_hareket(zaman,tutar,bakiye,tur,aciklama,user_id)
  values(t,net,v.bakiye-net,'devir',
    'Görevi biten Cumhurbaşkanının seçim süreci içinde yaptığı aktarım geri alındı; Hazine''ye iade.',null);
  perform oyun.hazine_kaydet('vf_aktarim', net, 'Varlık Fonu''ndan Hazine''ye geri iade (görev devri koruması)');
  perform oyun.olay('ekonomi',format(
    'Görevi biten Cumhurbaşkanının seçim süreci içinde Varlık Fonu''na aktardığı %s milyar ₺ Hazine''ye iade edildi. Yeni hükümetin fon çekim hakkı tam.',
    oyun.bm_sayi(net,1)),null,null,t);
end $onarim$;
