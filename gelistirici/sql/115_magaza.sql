-- =====================================================================
--  115 · MAĞAZA (gerçek parayla satın alınanlar)
--  Ürün türleri (oyun.paketler.tur):
--    para   : cüzdana oyun parası (₺) ekler
--    kart   : Siyaset Kartı — hemen ₺ + N gün boyunca günlük ödül, reklamsız ödüller ve Kart rozeti
--    paket  : Başlangıç Paketi — ₺ + N günlük Kart; hesap başına bir kez
--    kalici : kalıcı hak (reklamsiz = reklam izlemeden reklam ödülü, destekci = Destekçi rozeti)
--  Oy, makam, seçim sonucu ya da sandalye satılmaz. Satın alınan ₺ da oyunun mevcut günlük
--  sınırlarına (bağış, ek yayın hakkı vb.) tabidir.
--  Ödeme yalnız mağazanın (App Store / Google Play) onayından sonra RevenueCat → odeme-webhook →
--  odeme_isle yoluyla işlenir; uygulama kendi başına hiçbir şey veremez. Mevcut veriye dokunmaz.
-- =====================================================================
alter table oyun.paketler add column if not exists tur text not null default 'para';
alter table oyun.paketler add column if not exists gun int not null default 0;
alter table oyun.paketler add column if not exists hak text;
alter table oyun.paketler add column if not exists aciklama text;
alter table oyun.paketler add column if not exists etiket text;
alter table oyun.paketler add column if not exists fiyat text;      -- önerilen liste fiyatı (yalnız bilgi; gerçek fiyat mağazada)
alter table oyun.paketler add column if not exists aktif boolean not null default true;

-- İlk deneme paketleri (hiç satılmadı) vitrinden kalkar; kayıtları silinmez
update oyun.paketler set aktif = false where urun_id in ('tl_10000', 'tl_35000', 'tl_100000');

insert into oyun.paketler(urun_id, ad, miktar, sira, tur, gun, hak, aciklama, etiket, fiyat) values
  ('baslangic_paketi', 'Başlangıç Paketi', 100000, 1, 'paket', 7, null,
   'Cüzdanına 100.000 ₺ ve 7 günlük Siyaset Kartı. Hesap başına bir kez alınabilir.', 'Tek sefer', '₺39,99'),
  ('siyaset_karti', 'Siyaset Kartı · 30 gün', 30000, 2, 'kart', 30, null,
   'Hemen 30.000 ₺, 30 gün boyunca her gün ödül, reklam izlemeden reklam ödülleri ve adının yanında Kart rozeti.', 'En avantajlı', '₺119,99'),
  ('para_cep', 'Cep Harçlığı', 50000, 10, 'para', 0, null, null, null, '₺49,99'),
  ('para_kampanya', 'Kampanya Kasası', 125000, 11, 'para', 0, null, null, '%25 fazla', '₺99,99'),
  ('para_secim', 'Seçim Fonu', 300000, 12, 'para', 0, null, null, '%50 fazla', '₺199,99'),
  ('para_servet', 'Büyük Servet', 1000000, 13, 'para', 0, null, null, '%100 fazla', '₺499,99'),
  ('reklamsiz_odul', 'Reklamsız Ödüller', 0, 20, 'kalici', 0, 'reklamsiz',
   'Günlük 5 reklam ödülünü reklam izlemeden al. Kalıcıdır.', 'Kalıcı', '₺149,99'),
  ('destekci_rozeti', 'Destekçi Rozeti', 0, 21, 'kalici', 0, 'destekci',
   'Adının yanında altın Destekçi yıldızı. Oyunun gelişimine destek olur. Kalıcıdır.', 'Kalıcı', '₺79,99')
on conflict (urun_id) do nothing;

-- Oyuncunun mağaza hesabı (Kart süresi, günlük Kart ödülü, başlangıç paketi)
create table if not exists oyun.magaza_hesap(
  user_id uuid primary key references oyun.profiller(id),
  kart_bitis timestamptz,
  kart_son_odul date,
  baslangic_alindi boolean not null default false
);
-- Kalıcı haklar (iade ya da hesap taşımada aktif=false olur; satır silinmez)
create table if not exists oyun.oyuncu_hak(
  user_id uuid not null references oyun.profiller(id),
  hak text not null,
  kaynak text not null default 'satin_alma',
  aktif boolean not null default true,
  zaman timestamptz not null default now(),
  primary key (user_id, hak)
);

-- Kart günlük ödülü Kontrol Merkezi › Ayarlar'dan değiştirilebilir
insert into oyun.uygulama_ayar(anahtar, deger, aciklama, herkese_acik)
values ('kart_gunluk', '7500'::jsonb, 'Siyaset Kartı günlük ödülü (₺)', true)
on conflict (anahtar) do nothing;

create or replace function oyun.kart_gunluk() returns numeric language sql stable as $$
  select coalesce((select (deger #>> '{}')::numeric from oyun.uygulama_ayar where anahtar = 'kart_gunluk'), 7500)
$$;
create or replace function oyun.hak_var(u uuid, p_hak text) returns boolean language sql stable as $$
  select exists (select 1 from oyun.oyuncu_hak where user_id = u and hak = p_hak and aktif)
$$;
create or replace function oyun.kart_aktif(u uuid, t timestamptz default null) returns boolean language sql stable as $$
  select coalesce((select kart_bitis > coalesce(t, oyun.simdi()) from oyun.magaza_hesap where user_id = u), false)
$$;
create or replace function oyun.reklamsiz(u uuid, t timestamptz default null) returns boolean language sql stable as $$
  select oyun.hak_var(u, 'reklamsiz') or oyun.kart_aktif(u, t)
$$;

-- Satın almanın etkisi: işaret 1 = ver, -1 = geri al (iade)
create or replace function oyun.magaza_uygula(u uuid, pk oyun.paketler, isaret int, t timestamptz) returns numeric
language plpgsql as $$
declare dus numeric := 0;
begin
  if isaret > 0 then
    if pk.miktar > 0 then perform oyun.para_islem(u, pk.miktar, 'satin_alma', pk.ad || ' (satın alma)', t); end if;
    if pk.gun > 0 then
      insert into oyun.magaza_hesap(user_id, kart_bitis) values (u, t + make_interval(days => pk.gun))
      on conflict (user_id) do update
        set kart_bitis = greatest(coalesce(oyun.magaza_hesap.kart_bitis, t), t) + make_interval(days => pk.gun);
    end if;
    if pk.tur = 'paket' then
      insert into oyun.magaza_hesap(user_id, baslangic_alindi) values (u, true)
      on conflict (user_id) do update set baslangic_alindi = true;
    end if;
    if pk.hak is not null then
      insert into oyun.oyuncu_hak(user_id, hak, kaynak, aktif, zaman) values (u, pk.hak, 'satin_alma', true, t)
      on conflict (user_id, hak) do update set aktif = true, kaynak = 'satin_alma', zaman = t;
    end if;
  else
    if pk.miktar > 0 then
      perform oyun.cuzdanim(u);
      dus := least(pk.miktar, greatest((select para from oyun.cuzdan where user_id = u), 0));
      if dus > 0 then perform oyun.para_islem(u, -dus, 'iade', 'Mağaza iadesi: ' || pk.ad, t); end if;
    end if;
    if pk.gun > 0 then
      update oyun.magaza_hesap set kart_bitis = kart_bitis - make_interval(days => pk.gun) where user_id = u and kart_bitis is not null;
    end if;
    if pk.hak is not null then
      update oyun.oyuncu_hak set aktif = false, zaman = t where user_id = u and hak = pk.hak;
    end if;
  end if;
  return dus;
end $$;

-- RevenueCat olayları (yalnız service_role; odeme-webhook çağırır)
create or replace function public.odeme_isle(p_olay jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare e jsonb := coalesce(p_olay -> 'event', p_olay); tur text := e ->> 'type'; u uuid; pk oyun.paketler; islem text;
        s oyun.satin_almalar; dus numeric; t timestamptz := oyun.simdi(); f text; h text; tasinan int := 0;
begin
  islem := coalesce(e ->> 'transaction_id', e ->> 'original_transaction_id', e ->> 'id');
  if tur = 'TEST' then return jsonb_build_object('durum', 'test'); end if;

  -- Aynı mağaza hesabı başka oyun hesabına geçti: kalıcı haklar yeni hesaba taşınır
  if tur = 'TRANSFER' then
    for f in select jsonb_array_elements_text(coalesce(e -> 'transferred_from', '[]'::jsonb)) loop
      for h in select jsonb_array_elements_text(coalesce(e -> 'transferred_to', '[]'::jsonb)) loop
        begin
          if exists (select 1 from oyun.profiller where id = h::uuid) and h <> f then
            insert into oyun.oyuncu_hak(user_id, hak, kaynak, aktif, zaman)
            select h::uuid, x.hak, 'transfer', true, t from oyun.oyuncu_hak x where x.user_id = f::uuid and x.aktif and x.kaynak <> 'yonetici'
            on conflict (user_id, hak) do update set aktif = true, kaynak = 'transfer', zaman = t;
            get diagnostics tasinan = row_count;
            update oyun.oyuncu_hak set aktif = false, zaman = t where user_id = f::uuid and aktif and kaynak <> 'yonetici';
          end if;
        exception when invalid_text_representation then null;
        end;
      end loop;
    end loop;
    return jsonb_build_object('durum', 'transfer', 'tasinan', tasinan);
  end if;

  begin u := (e ->> 'app_user_id')::uuid; exception when others then return jsonb_build_object('durum', 'kullanici_yok'); end;
  if not exists (select 1 from oyun.profiller where id = u) then return jsonb_build_object('durum', 'kullanici_yok'); end if;

  if tur in ('NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE') then
    select * into pk from oyun.paketler where urun_id = e ->> 'product_id';
    if pk.urun_id is null then return jsonb_build_object('durum', 'urun_yok'); end if;
    if islem is null then return jsonb_build_object('durum', 'islem_yok'); end if;
    insert into oyun.satin_almalar(islem_id, user_id, urun_id, miktar, olay, zaman) values (islem, u, pk.urun_id, pk.miktar, e, t)
    on conflict (islem_id) do nothing;
    if not found then return jsonb_build_object('durum', 'zaten_islendi'); end if;
    perform oyun.magaza_uygula(u, pk, 1, t);
    perform oyun.bildir(u, case
      when pk.tur = 'para' then format('Satın alma tamamlandı: cüzdanına %s ₺ eklendi. Teşekkürler!', oyun.tl(pk.miktar))
      when pk.tur in ('kart', 'paket') then format('Satın alma tamamlandı: %s. Siyaset Kartın %s tarihine kadar geçerli. Teşekkürler!', pk.ad,
                                                   to_char((select kart_bitis from oyun.magaza_hesap where user_id = u) at time zone 'Europe/Istanbul', 'DD.MM.YYYY'))
      else format('Satın alma tamamlandı: %s artık hesabında. Teşekkürler!', pk.ad) end, t);
    return jsonb_build_object('durum', 'eklendi', 'urun', pk.urun_id, 'miktar', pk.miktar);
  elsif tur = 'CANCELLATION' then
    -- Tek seferlik ürünlerde CANCELLATION mağaza iadesi demektir
    if coalesce(e ->> 'cancel_reason', 'CUSTOMER_SUPPORT') not in ('CUSTOMER_SUPPORT', 'UNKNOWN') then
      return jsonb_build_object('durum', 'yok_say');
    end if;
    select * into s from oyun.satin_almalar where islem_id = islem for update;
    if s.id is null or s.iade then return jsonb_build_object('durum', 'yok_say'); end if;
    select * into pk from oyun.paketler where urun_id = s.urun_id;
    update oyun.satin_almalar set iade = true where id = s.id;
    pk.miktar := s.miktar;   -- satın alındığı andaki miktar
    if s.user_id is null or pk.urun_id is null then return jsonb_build_object('durum', 'iade', 'dusulen', 0); end if;
    dus := oyun.magaza_uygula(s.user_id, pk, -1, t);
    return jsonb_build_object('durum', 'iade', 'dusulen', dus);
  end if;
  return jsonb_build_object('durum', 'yok_say');
end $$;
revoke all on function public.odeme_isle(jsonb) from public, anon, authenticated;
grant execute on function public.odeme_isle(jsonb) to service_role;

-- Oyuncunun gördüğü mağaza: vitrin + kendi durumu
create or replace function public.magaza_durum() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.magaza_hesap;
        bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
begin
  select * into h from oyun.magaza_hesap where user_id = p.id;
  return jsonb_build_object(
    'paketler', (select coalesce(jsonb_agg(jsonb_build_object(
        'urun_id', k.urun_id, 'ad', k.ad, 'miktar', k.miktar, 'tur', k.tur, 'gun', k.gun, 'hak', k.hak,
        'aciklama', k.aciklama, 'etiket', k.etiket, 'fiyat', k.fiyat,
        'sahip', k.hak is not null and oyun.hak_var(p.id, k.hak),
        'alinabilir', case when k.tur = 'paket' then not coalesce(h.baslangic_alindi, false)
                           when k.hak is not null then not oyun.hak_var(p.id, k.hak) else true end) order by k.sira), '[]'::jsonb)
      from oyun.paketler k where k.aktif),
    'kart', jsonb_build_object('aktif', coalesce(h.kart_bitis > t, false), 'bitis', h.kart_bitis,
        'odul_alinabilir', coalesce(h.kart_bitis > t, false) and (h.kart_son_odul is null or h.kart_son_odul < bugun),
        'gunluk', oyun.kart_gunluk()),
    'haklar', (select coalesce(jsonb_agg(hak order by hak), '[]'::jsonb) from oyun.oyuncu_hak where user_id = p.id and aktif),
    'reklamsiz', oyun.reklamsiz(p.id, t),
    'satis_acik', coalesce((select deger from oyun.uygulama_ayar where anahtar = 'satis_acik') <> 'false'::jsonb, true),
    'para', (select para from oyun.cuzdan where user_id = p.id)
  );
end $$;

-- Siyaset Kartı günlük ödülü
create or replace function public.kart_odul_al() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.magaza_hesap;
        bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; tutar numeric := oyun.kart_gunluk();
begin
  select * into h from oyun.magaza_hesap where user_id = p.id for update;
  if h.user_id is null or h.kart_bitis is null or h.kart_bitis <= t then raise exception 'Siyaset Kartın aktif değil.'; end if;
  if h.kart_son_odul is not null and h.kart_son_odul >= bugun then raise exception 'Bugünkü Kart ödülünü aldın. Yarın yeniden gel.'; end if;
  update oyun.magaza_hesap set kart_son_odul = bugun where user_id = p.id;
  perform oyun.para_islem(p.id, tutar, 'kart', 'Siyaset Kartı günlük ödülü', t);
  return public.magaza_durum() || jsonb_build_object('sonuc', jsonb_build_object('odul', tutar));
end $$;

-- Sohbette ve oyuncu kartında gösterilen rozetler: { "KullaniciAdi": "destekci,kart" }
create or replace function public.magaza_rozetler() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_object_agg(pr.kad, r.rozet), '{}'::jsonb)
  from (select user_id, string_agg(rozet, ',' order by rozet) rozet from (
          select user_id, 'destekci' rozet from oyun.oyuncu_hak where hak = 'destekci' and aktif
          union all
          select user_id, 'kart' from oyun.magaza_hesap where kart_bitis > oyun.simdi()) x
        group by user_id) r
  join oyun.profiller pr on pr.id = r.user_id
  where not pr.yasakli
$$;

-- Yönetici: satış özeti (mağaza fiyatıyla brüt; mağaza payı ve vergiler düşülmeden)
create or replace function public.yk_satislar(p_gun int default 30) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('ozet'); bas timestamptz := oyun.simdi() - make_interval(days => greatest(1, least(coalesce(p_gun, 30), 3650)));
begin
  return jsonb_build_object(
    'gun', p_gun,
    'toplam', (select jsonb_build_object('adet', count(*) filter (where not iade), 'iade', count(*) filter (where iade),
                 'brut_try', round(coalesce(sum((olay ->> 'price_in_purchased_currency')::numeric) filter (where not iade and olay ->> 'currency' = 'TRY'), 0), 2),
                 'brut_usd', round(coalesce(sum((olay ->> 'price')::numeric) filter (where not iade), 0), 2),
                 'alici', count(distinct user_id) filter (where not iade))
               from oyun.satin_almalar where zaman >= bas),
    'urunler', (select coalesce(jsonb_agg(jsonb_build_object('urun_id', x.urun_id, 'ad', coalesce(k.ad, x.urun_id), 'adet', x.adet,
                   'brut_try', x.try) order by x.adet desc), '[]'::jsonb)
                from (select urun_id, count(*) adet, round(coalesce(sum((olay ->> 'price_in_purchased_currency')::numeric) filter (where olay ->> 'currency' = 'TRY'), 0), 2) try
                      from oyun.satin_almalar where zaman >= bas and not iade group by urun_id) x
                left join oyun.paketler k on k.urun_id = x.urun_id),
    'son', (select coalesce(jsonb_agg(jsonb_build_object('zaman', s.zaman, 'kad', coalesce(pr.kad, '(silinmiş)'), 'urun', coalesce(k.ad, s.urun_id),
                 'fiyat', case when s.olay ->> 'currency' is not null then (s.olay ->> 'price_in_purchased_currency') || ' ' || (s.olay ->> 'currency') end,
                 'iade', s.iade) order by s.zaman desc), '[]'::jsonb)
            from (select * from oyun.satin_almalar order by zaman desc limit 20) s
            left join oyun.profiller pr on pr.id = s.user_id left join oyun.paketler k on k.urun_id = s.urun_id)
  );
end $$;

do $$ declare f text; begin
  foreach f in array array['public.magaza_durum()', 'public.kart_odul_al()', 'public.magaza_rozetler()', 'public.yk_satislar(int)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
