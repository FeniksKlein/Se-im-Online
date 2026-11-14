-- 2026.11.15-3 · MAĞAZA: görünüm ürünleri ve kullanıcı adı değiştirme (Ercan onayı, 15 Kasım 2026)
--  imza_paketi       (hak imza)             : seçilebilir unvan + sohbette parıltılı ad
--  kampanya_tasarim  (hak kampanya_tasarim) : özel afiş şablonları + altın miting sahnesi
--  parti_kimlik      (hak parti_kimlik)     : genel başkan partisine uygular; parti sayfası kurumsal kimlik görünümü
--  ad_degistirme     (tur jeton)            : her satın alma bir kullanıcı adı değiştirme hakkı
--  rozet_yeniyil_2027(hak rozet_yeniyil27)  : sezonluk rozet; yalnız satış penceresinde vitrinde
-- Hiçbiri oy, makam, kıdem ya da seçim gücü vermez. Mevcut veriye dokunmaz.

alter table oyun.paketler add column if not exists satis_bas timestamptz;
alter table oyun.paketler add column if not exists satis_bit timestamptz;
alter table oyun.partiler add column if not exists kimlik_alan uuid references oyun.profiller(id);

create table if not exists oyun.magaza_jeton(
  user_id uuid not null references oyun.profiller(id),
  kod text not null,
  adet int not null default 0 check (adet >= 0),
  primary key (user_id, kod)
);
create table if not exists oyun.oyuncu_gorunum(
  user_id uuid primary key references oyun.profiller(id),
  unvan text
);
create table if not exists oyun.kad_gecmis(
  id bigserial primary key,
  user_id uuid not null references oyun.profiller(id),
  eski text not null,
  yeni text not null,
  zaman timestamptz not null
);
create index if not exists kad_gecmis_eski on oyun.kad_gecmis (lower(eski), zaman desc);
alter table oyun.magaza_jeton enable row level security;
alter table oyun.oyuncu_gorunum enable row level security;
alter table oyun.kad_gecmis enable row level security;
revoke all on oyun.magaza_jeton, oyun.oyuncu_gorunum, oyun.kad_gecmis from public, anon, authenticated;

insert into oyun.paketler(urun_id, ad, miktar, sira, tur, gun, hak, aciklama, etiket, fiyat, satis_bas, satis_bit) values
  ('imza_paketi', 'İmza Paketi', 0, 24, 'kalici', 0, 'imza',
   'Adının yanında seçtiğin unvan ve sohbette altın parıltılı ad. Unvanını dilediğin zaman değiştirirsin. Kalıcıdır.', 'Kalıcı', '₺49,99', null, null),
  ('kampanya_tasarim', 'Kampanya Tasarım Paketi', 0, 25, 'kalici', 0, 'kampanya_tasarim',
   'Afiş atölyesinde 4 özel şablon ve düzenlediğin mitinglerde altın sahne görünümü. Kalıcıdır.', 'Kalıcı', '₺59,99', null, null),
  ('parti_kimlik', 'Parti Kimlik Paketi', 0, 26, 'kalici', 0, 'parti_kimlik',
   'Genel başkanı olduğun partinin sayfasına kurumsal kimlik görünümü: altın çerçeveli amblem ve kimlik şeridi. Partiyi ziyaret eden herkes görür.', 'Parti için', '₺99,99', null, null),
  ('ad_degistirme', 'Kullanıcı Adı Değiştirme', 0, 30, 'jeton', 0, 'ad_degis',
   'Kullanıcı adını bir kez değiştirme hakkı. Değişiklik herkese duyurulur.', null, '₺49,99', null, null),
  ('rozet_yeniyil_2027', 'Yeni Yıl 2027 Rozeti', 0, 40, 'kalici', 0, 'rozet_yeniyil27',
   'Adının yanında Yeni Yıl 2027 rozeti. Yalnız 25 Aralık – 2 Ocak arasında satılır; sonra bir daha çıkmaz.', 'Sezonluk', '₺24,99',
   timestamptz '2026-12-25 00:00+03', timestamptz '2027-01-03 00:00+03')
on conflict (urun_id) do update set ad=excluded.ad, miktar=excluded.miktar, sira=excluded.sira, tur=excluded.tur,
  hak=excluded.hak, aciklama=excluded.aciklama, etiket=excluded.etiket, fiyat=excluded.fiyat,
  satis_bas=excluded.satis_bas, satis_bit=excluded.satis_bit;

-- Seçilebilir unvanlar: resmî makam adı içermez (makam taklidi olmasın)
create or replace function oyun.magaza_unvanlar() returns text[] language sql immutable set search_path = '' as $$
  select array['Halkın Sesi','Meydanların Hatibi','Kulis Kurdu','Sandık Ustası','Demokrasi Neferi','Anadolu Sevdalısı',
               'Kürsü Aslanı','Gönül Elçisi','Teşkilat Emektarı','Reform Gönüllüsü','Hür Kalem','Çay Ocağı Filozofu']
$$;

-- Parti Kimlik Paketi: hak sahibi genel başkan, paketi tek bir partiye uygular
create or replace function oyun.parti_kimlik_uygula(u uuid) returns bigint
language plpgsql set search_path = '' as $$
declare pid bigint;
begin
  if not oyun.hak_var(u, 'parti_kimlik') then return null; end if;
  select id into pid from oyun.partiler where kimlik_alan = u and not kapali limit 1;
  if pid is not null then return pid; end if;
  select id into pid from oyun.partiler where gb = u and not kapali and kimlik_alan is null limit 1;
  if pid is null then return null; end if;
  update oyun.partiler set kimlik_alan = u where id = pid;
  return pid;
end $$;

-- Satın almanın etkisi: işaret 1 = ver, -1 = geri al (iade)
create or replace function oyun.magaza_uygula(u uuid, pk oyun.paketler, isaret integer, t timestamp with time zone)
 returns numeric language plpgsql set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $function$
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
    if pk.tur = 'jeton' and pk.hak is not null then
      insert into oyun.magaza_jeton(user_id, kod, adet) values (u, pk.hak, 1)
      on conflict (user_id, kod) do update set adet = oyun.magaza_jeton.adet + 1;
    elsif pk.hak is not null then
      insert into oyun.oyuncu_hak(user_id, hak, kaynak, aktif, zaman) values (u, pk.hak, 'satin_alma', true, t)
      on conflict (user_id, hak) do update set aktif = true, kaynak = 'satin_alma', zaman = t;
      if pk.hak = 'parti_kimlik' then perform oyun.parti_kimlik_uygula(u); end if;
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
    if pk.tur = 'jeton' and pk.hak is not null then
      update oyun.magaza_jeton set adet = adet - 1 where user_id = u and kod = pk.hak and adet > 0;
    elsif pk.hak is not null then
      update oyun.oyuncu_hak set aktif = false, zaman = t where user_id = u and hak = pk.hak;
      if pk.hak = 'parti_kimlik' then update oyun.partiler set kimlik_alan = null where kimlik_alan = u; end if;
      if pk.hak = 'imza' then update oyun.oyuncu_gorunum set unvan = null where user_id = u; end if;
    end if;
  end if;
  return dus;
end $function$;

-- Oyuncunun gördüğü mağaza: vitrin + kendi durumu
create or replace function public.magaza_durum() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.magaza_hesap;
        bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
begin
  select * into h from oyun.magaza_hesap where user_id = p.id;
  return jsonb_build_object(
    'paketler', (select coalesce(jsonb_agg(jsonb_build_object(
        'urun_id', k.urun_id, 'ad', k.ad, 'miktar', k.miktar, 'tur', k.tur, 'gun', k.gun, 'hak', k.hak,
        'aciklama', k.aciklama, 'etiket', k.etiket, 'fiyat', k.fiyat, 'satis_bit', k.satis_bit,
        'sahip', k.tur <> 'jeton' and k.hak is not null and oyun.hak_var(p.id, k.hak),
        'alinabilir', case when k.tur = 'paket' then not coalesce(h.baslangic_alindi, false)
                           when k.tur = 'jeton' then true
                           when k.hak is not null then not oyun.hak_var(p.id, k.hak) else true end) order by k.sira), '[]'::jsonb)
      from oyun.paketler k where k.aktif
        and (k.satis_bas is null or k.satis_bas <= t)
        and (k.satis_bit is null or k.satis_bit > t or (k.hak is not null and k.tur <> 'jeton' and oyun.hak_var(p.id, k.hak)))),
    'kart', jsonb_build_object('aktif', coalesce(h.kart_bitis > t, false), 'bitis', h.kart_bitis,
        'odul_alinabilir', coalesce(h.kart_bitis > t, false) and (h.kart_son_odul is null or h.kart_son_odul < bugun),
        'gunluk', oyun.kart_gunluk()),
    'haklar', (select coalesce(jsonb_agg(hak order by hak), '[]'::jsonb) from oyun.oyuncu_hak where user_id = p.id and aktif),
    'jetonlar', (select coalesce(jsonb_object_agg(kod, adet), '{}'::jsonb) from oyun.magaza_jeton where user_id = p.id and adet > 0),
    'unvan', (select unvan from oyun.oyuncu_gorunum where user_id = p.id),
    'unvanlar', to_jsonb(oyun.magaza_unvanlar()),
    'parti_kimlik', jsonb_build_object(
        'parti', (select ad from oyun.partiler where kimlik_alan = p.id and not kapali limit 1),
        'gb_parti', (select ad from oyun.partiler where gb = p.id and not kapali limit 1)),
    'reklamsiz', oyun.reklamsiz(p.id, t),
    'satis_acik', coalesce((select deger from oyun.uygulama_ayar where anahtar = 'satis_acik') <> 'false'::jsonb, true),
    'para', (select para from oyun.cuzdan where user_id = p.id)
  );
end $function$;

-- Rozet listesi. Değer virgüllü belirteç dizisidir: destekci, kurucu, cerceve, kart, imza,
-- kampanya_tasarim, u:<unvan>, r:<sezonluk rozet adı>. '#partiler' anahtarı kurumsal kimlikli
-- parti kimliklerini taşır (kullanıcı adında # bulunamaz). Eski uygulama bilmediklerini yok sayar.
create or replace function public.magaza_rozetler() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_object_agg(pr.kad, r.rozet), '{}'::jsonb)
      || jsonb_build_object('#partiler', coalesce((select string_agg(id::text, ',' order by id) from oyun.partiler where kimlik_alan is not null and not kapali), ''))
  from (select user_id, string_agg(rozet, ',' order by rozet) rozet from (
          select user_id, hak rozet from oyun.oyuncu_hak where hak in ('destekci', 'kurucu', 'cerceve', 'imza', 'kampanya_tasarim') and aktif
          union all
          select h.user_id, 'r:' || replace(regexp_replace(k.ad, '\s*Rozeti$', ''), ',', ' ')
            from oyun.oyuncu_hak h join oyun.paketler k on k.hak = h.hak where h.hak like 'rozet\_%' and h.aktif
          union all
          select g.user_id, 'u:' || g.unvan from oyun.oyuncu_gorunum g
           where g.unvan is not null and oyun.hak_var(g.user_id, 'imza')
          union all
          select user_id, 'kart' from oyun.magaza_hesap where kart_bitis > oyun.simdi()) x
        group by user_id) r
  join oyun.profiller pr on pr.id = r.user_id
  where not pr.yasakli
$$;

-- İmza Paketi: unvan seç (null/boş = unvansız)
create or replace function public.magaza_unvan_sec(p_unvan text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); u text := nullif(btrim(coalesce(p_unvan, '')), '');
begin
  if not oyun.hak_var(p.id, 'imza') then raise exception 'Unvan seçmek için İmza Paketi gerekir.'; end if;
  if u is not null and not (u = any(oyun.magaza_unvanlar())) then raise exception 'Geçersiz unvan.'; end if;
  insert into oyun.oyuncu_gorunum(user_id, unvan) values (p.id, u)
  on conflict (user_id) do update set unvan = excluded.unvan;
  return public.magaza_durum();
end $$;

-- Parti Kimlik Paketi: genel başkan partisine uygular
create or replace function public.magaza_parti_kimlik_uygula() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); pid bigint;
begin
  if not oyun.hak_var(p.id, 'parti_kimlik') then raise exception 'Önce Parti Kimlik Paketi''ni almalısın.'; end if;
  perform 1 from oyun.profiller where id = p.id for update;
  if exists (select 1 from oyun.partiler where kimlik_alan = p.id and not kapali) then raise exception 'Paketin zaten bir partiye uygulanmış.'; end if;
  if exists (select 1 from oyun.partiler where gb = p.id and not kapali and kimlik_alan is not null) then raise exception 'Partinde kurumsal kimlik zaten var.'; end if;
  pid := oyun.parti_kimlik_uygula(p.id);
  if pid is null then raise exception 'Paketi uygulamak için bir partinin genel başkanı olmalısın.'; end if;
  perform oyun.olay('parti', format('%s kurumsal kimliğine kavuştu.', (select ad from oyun.partiler where id = pid)), null, pid, oyun.simdi());
  return public.magaza_durum();
end $$;

-- Kullanıcı adı değiştirme (her kullanım bir jeton harcar)
create or replace function public.kad_degistir(p_yeni text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); y text := btrim(coalesce(p_yeni, ''));
begin
  perform 1 from oyun.profiller where id = p.id for update;
  if y !~ '^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$' then
    raise exception 'Kullanıcı adı 3-20 karakter olmalı; yalnızca harf, rakam ve _ kullanılabilir.';
  end if;
  if y = p.kad then raise exception 'Yeni ad şimdikiyle aynı.'; end if;
  if oyun.yasakli_kad(y) then raise exception 'Bu kullanıcı adı kullanılamaz.'; end if;
  if exists (select 1 from oyun.profiller where lower(kad) = lower(y) and id <> p.id) then raise exception 'Bu kullanıcı adı alınmış.'; end if;
  -- Başkasının yeni bıraktığı ad 30 gün kimseye verilmez (taklit olmasın)
  if exists (select 1 from oyun.kad_gecmis g where lower(g.eski) = lower(y) and g.user_id <> p.id and g.zaman > t - interval '30 days') then
    raise exception 'Bu ad yakın zamanda başka bir oyuncu tarafından bırakıldı; 30 gün dolmadan alınamaz.';
  end if;
  -- Seçmen pusulada adı görür: seçim sürerken ad değişmez
  if exists (select 1 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id where a.user_id = p.id and s.durum = 'bekliyor') then
    raise exception 'Aday olduğun seçim sonuçlanmadan kullanıcı adını değiştiremezsin.';
  end if;
  update oyun.magaza_jeton set adet = adet - 1 where user_id = p.id and kod = 'ad_degis' and adet > 0;
  if not found then raise exception 'Ad değiştirme hakkın yok. Mağazadan alabilirsin.'; end if;
  update oyun.profiller set kad = y where id = p.id;
  insert into oyun.kad_gecmis(user_id, eski, yeni, zaman) values (p.id, p.kad, y, t);
  perform oyun.olay('duyuru', format('%s kullanıcı adını %s olarak değiştirdi.', p.kad, y), null, null, t);
  perform oyun.bildir(p.id, format('Kullanıcı adın %s olarak değiştirildi.', y), t);
  return jsonb_build_object('kad', y);
end $$;

do $$ declare f text; begin
  foreach f in array array['public.magaza_durum()', 'public.magaza_rozetler()', 'public.magaza_unvan_sec(text)',
                           'public.magaza_parti_kimlik_uygula()', 'public.kad_degistir(text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
