-- 24.11.2026 · EK İŞLER 2.0 (sürüm 2026.11.24-2)
-- İstek (Ercan): günlük ek iş hakkı 5 olsun; 20 meslek gelsin; ücret, süre ve meslekler yönetici panelinden
-- değişsin; ek işler ana ekrandan kolay bulunsun; kazanç gerçek cüzdana ve işlem geçmişine tek sefer işlensin.
--
-- Kurallar (sunucuda zorlanır; arayüz yalnız gösterir):
--   • Günlük hak oyun.ek_is_ayar.gunluk_limit (başlangıç 5). Hak, iş BAŞLATILINCA düşer; gün Türkiye saatiyle
--     00.00'da döner (ek_is_kayit.gun = işin başladığı Türkiye günü).
--   • Aynı anda tek iş (ek_is_tek_aktif benzersiz dizini) ve her işlemde oyuncu satırı kilidi (for update):
--     sayfayı yenilemek, aynı anda çok istek göndermek ya da iki cihaz kullanmak sınırı aşamaz.
--   • Ücret iş başlarken sabitlenir, süre dolmadan ödenmez, bir iş bir kez ödenir (odendi_at + satır kilidi).
--     Ödeme oyun.para_islem ile cüzdana ve hesap hareketlerine ('ek_is') yazılır.
--   • Süresi dolmuş ama ücreti alınmamış iş varken yeni iş başlatılırsa önce o işin ücreti aynı işlemde ödenir.
--   • İşi yarıda bırakma/iptal yoktur (önceki kural aynen).
--   • Katalog yalnız oyunun sahibi tarafından değişir (yk_ek_is_*); her değişiklik oyun.yk_degisiklik'e yazılır.
--     Geçmişi olan meslek silinmez, arşive alınır (ödeme geçmişi ve süren işler bozulmaz).
-- Tekrar çalıştırmak güvenlidir: tohum bir kez uygulanır (ek_is_ayar.tohum); yöneticinin sonradan yaptığı
-- ücret/süre değişikliklerini ezmez. Oyuncu verisi (kayıtlar, cüzdan) değiştirilmez.

alter table oyun.ek_is_katalog add column if not exists kategori text not null default 'hizmet';
alter table oyun.ek_is_katalog add column if not exists min_kidem numeric not null default 0;
alter table oyun.ek_is_katalog add column if not exists silindi boolean not null default false;
alter table oyun.ek_is_katalog add column if not exists guncelleme timestamptz not null default now();

do $kisit$
begin
  if not exists (select 1 from pg_constraint where conname = 'ek_is_katalog_kategori_chk' and conrelid = 'oyun.ek_is_katalog'::regclass) then
    alter table oyun.ek_is_katalog add constraint ek_is_katalog_kategori_chk
      check (kategori in ('hizmet','ulasim','zanaat','egitim_ofis','teknoloji','medya','tarim','diger'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'ek_is_katalog_min_kidem_chk' and conrelid = 'oyun.ek_is_katalog'::regclass) then
    alter table oyun.ek_is_katalog add constraint ek_is_katalog_min_kidem_chk check (min_kidem >= 0);
  end if;
end $kisit$;

create table if not exists oyun.ek_is_ayar(
  id smallint primary key default 1 check (id = 1),
  gunluk_limit smallint not null default 5 check (gunluk_limit between 1 and 24),
  tohum smallint not null default 0,
  guncelleme timestamptz not null default now()
);
insert into oyun.ek_is_ayar(id) values (1) on conflict (id) do nothing;
alter table oyun.ek_is_ayar enable row level security;
revoke all on oyun.ek_is_ayar from public, anon, authenticated;

create index if not exists ek_is_kayit_baslama on oyun.ek_is_kayit(baslama);

-- Başlangıç kataloğu: 20 meslek (Ercan'ın tablosundaki ücretler; süre ≈ saatte 850 ₺ olacak biçimde ücretle orantılı).
-- Önceden var olan beş iş (kurye, taksi, özel ders, tasarım, fotoğraf) aynı kodla yeni değerlerine çekilir;
-- "Ev ve Cihaz Tamiri" olduğu gibi kalır. Yalnız bir kez uygulanır.
do $tohum$
begin
  if (select tohum from oyun.ek_is_ayar where id = 1) >= 2 then return; end if;
  insert into oyun.ek_is_katalog(kod, ad, simge, aciklama, sure_dakika, asgari_ucret, azami_ucret, sira, kategori) values
    ('garson',            'Garsonluk',                  '🍽️', 'Bir restoranda servis yap; vardiya bitince ücretini al.',            55,   750,  750,  1, 'hizmet'),
    ('kurye',             'Paket Kuryeliği',            '🚲', 'Teslimat yap, iş bitince ücretini cüzdanına al.',                    70,  1000, 1000,  2, 'ulasim'),
    ('taksi',             'Taksi Şoförlüğü',            '🚕', 'Şehir içinde yolcu taşı ve sefer ücretini kazan.',                   90,  1250, 1250,  3, 'ulasim'),
    ('market',            'Market Çalışanı',            '🛒', 'Kasada ve reyonda çalış; mesai sonunda ücretini al.',                60,   850,  850,  4, 'hizmet'),
    ('guvenlik',          'Özel Güvenlik',              '🛡️', 'Bir işyerinde nöbet tut; nöbet bitince ödemeni al.',                 80,  1100, 1100,  5, 'hizmet'),
    ('insaat',            'İnşaat İşçiliği',            '🏗️', 'Şantiyede çalış; günün sonunda yevmiyeni al.',                      100,  1400, 1400,  6, 'zanaat'),
    ('oto_tamir',         'Oto Tamirciliği',            '🔧', 'Serviste araç bakımı ve onarımı yap.',                              125,  1750, 1750,  7, 'zanaat'),
    ('elektrik',          'Elektrikçilik',              '💡', 'Ev ve işyerlerinde elektrik arızalarını gider.',                    130,  1800, 1800,  8, 'zanaat'),
    ('tesisat',           'Tesisatçılık',               '🚿', 'Su ve ısıtma tesisatı arızalarını onar.',                           120,  1650, 1650,  9, 'zanaat'),
    ('fotograf',          'Fotoğrafçılık',              '📷', 'Bir etkinliğin ya da ürünün çekimini tamamla.',                     105,  1500, 1500, 10, 'medya'),
    ('ozel_ders',         'Özel Ders Öğretmenliği',     '📚', 'Bir öğrenciye ders ver, ders sonunda ödeme al.',                    125,  1750, 1750, 11, 'egitim_ofis'),
    ('muhasebe',          'Muhasebe Destek İşleri',     '🧾', 'Bir işletmenin defter ve beyanname işlerine yardım et.',            145,  2000, 2000, 12, 'egitim_ofis'),
    ('yazilim',           'Yazılım Geliştirme',         '💻', 'Bir müşteri için yazılım işi tamamla.',                             180,  2500, 2500, 13, 'teknoloji'),
    ('tasarim',           'Grafik Tasarım',             '🎨', 'Bir işletme için afiş ve tasarım işi tamamla.',                     120,  1650, 1650, 14, 'medya'),
    ('sosyal_medya',      'Sosyal Medya Yöneticiliği',  '📱', 'Bir markanın hesaplarını yönet, içerik hazırla.',                   105,  1500, 1500, 15, 'medya'),
    ('gazetecilik',       'Gazetecilik',                '📰', 'Haber takip et, dosya hazırla ve teslim et.',                       100,  1400, 1400, 16, 'medya'),
    ('organizasyon',      'Organizasyon Görevlisi',     '🎪', 'Bir etkinliğin kurulumunda ve karşılamasında görev al.',             85,  1200, 1200, 17, 'hizmet'),
    ('tarim',             'Tarım İşçiliği',             '🌾', 'Tarlada ekim, bakım ya da hasat işinde çalış.',                      65,   950,  950, 18, 'tarim'),
    ('asci',              'Aşçılık',                    '🍳', 'Bir mutfakta yemek hazırla; servis bitince ücretini al.',            95,  1300, 1300, 19, 'hizmet'),
    ('bilgisayar_servis', 'Bilgisayar Teknik Servisi',  '🖥️', 'Bilgisayar ve ağ arızalarını gider, kurulum yap.',                  135,  1900, 1900, 20, 'teknoloji')
  on conflict (kod) do update set ad = excluded.ad, simge = excluded.simge, aciklama = excluded.aciklama,
    sure_dakika = excluded.sure_dakika, asgari_ucret = excluded.asgari_ucret, azami_ucret = excluded.azami_ucret,
    sira = excluded.sira, kategori = excluded.kategori, guncelleme = now();
  update oyun.ek_is_katalog set kategori = 'zanaat', sira = 21, guncelleme = now() where kod = 'tamirat';
  update oyun.ek_is_ayar set gunluk_limit = 5, tohum = 2, guncelleme = now() where id = 1;
end $tohum$;

create or replace function oyun.ek_is_kategori_ad(p_kod text) returns text
language sql immutable set search_path = '' as $fn$
  select case p_kod
    when 'hizmet' then 'Hizmet' when 'ulasim' then 'Ulaşım' when 'zanaat' then 'Zanaat ve teknik'
    when 'egitim_ofis' then 'Eğitim ve ofis' when 'teknoloji' then 'Teknoloji' when 'medya' then 'Medya ve tasarım'
    when 'tarim' then 'Tarım' else 'Diğer' end
$fn$;

create or replace function oyun.ek_is_gunluk_limit() returns integer
language sql stable set search_path = '' as $fn$
  select coalesce((select gunluk_limit::integer from oyun.ek_is_ayar where id = 1), 5)
$fn$;

-- Tek ödeme noktası: kaydı kilitler, süreyi ve tekrar ödemeyi denetler, cüzdana ve hesap hareketlerine yazar.
create or replace function oyun.ek_is_ode(p_user uuid, p_id bigint, t timestamptz) returns jsonb
language plpgsql security definer set search_path = '' as $fn$
declare k oyun.ek_is_kayit; v_ad text;
begin
  select * into k from oyun.ek_is_kayit where id = p_id and user_id = p_user for update;
  if k.id is null then raise exception 'Ek iş kaydı bulunamadı.'; end if;
  if k.odendi_at is not null then raise exception 'Bu ek işin ücreti daha önce ödendi.'; end if;
  if t < k.bitis then raise exception 'İş henüz bitmedi. Bitiş saatini beklemelisin.'; end if;
  update oyun.ek_is_kayit set odendi_at = t where id = k.id and odendi_at is null;
  if not found then raise exception 'Bu ek işin ücreti daha önce ödendi.'; end if;
  select c.ad into v_ad from oyun.ek_is_katalog c where c.kod = k.tur;
  perform oyun.para_islem(p_user, k.ucret, 'ek_is', coalesce(v_ad, 'Ek iş') || ' ek iş ücreti', t);
  return jsonb_build_object('id', k.id, 'ucret', k.ucret, 'odendi_at', t, 'ad', coalesce(v_ad, 'Ek iş'));
end $fn$;

create or replace function public.ek_is_paneli() returns jsonb
language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller := oyun.profilim(); t timestamptz := now();
  g date := (t at time zone 'Europe/Istanbul')::date;
  gun_basi timestamptz := (g::timestamp at time zone 'Europe/Istanbul');
  lim integer := oyun.ek_is_gunluk_limit(); yap integer; kd numeric := null;
begin
  select count(*) into yap from oyun.ek_is_kayit where user_id = p.id and gun = g;
  if exists (select 1 from oyun.ek_is_katalog where aktif and not silindi and min_kidem > 0) then kd := oyun.kidem_puani(p.id); end if;
  return jsonb_build_object(
    'gunluk_limit', lim,
    'bugun_yapilan', yap,
    'kalan', greatest(0, lim - yap),
    'bugun_kazanilan', coalesce((select sum(ucret) from oyun.ek_is_kayit where user_id = p.id and odendi_at >= gun_basi), 0),
    'simdi', t,
    'sifirlanma', ((g + 1)::timestamp at time zone 'Europe/Istanbul'),
    'kidem', kd,
    'isler', coalesce((select jsonb_agg(jsonb_build_object(
        'kod', c.kod, 'ad', c.ad, 'simge', c.simge, 'aciklama', c.aciklama, 'sure_dakika', c.sure_dakika,
        'asgari_ucret', c.asgari_ucret, 'azami_ucret', c.azami_ucret, 'kategori', c.kategori,
        'kategori_ad', oyun.ek_is_kategori_ad(c.kategori), 'min_kidem', c.min_kidem,
        'uygun', (c.min_kidem <= 0 or coalesce(kd, 0) >= c.min_kidem)) order by c.sira, c.ad)
      from oyun.ek_is_katalog c where c.aktif and not c.silindi), '[]'::jsonb),
    'aktif', (select jsonb_build_object('id', k.id, 'tur', k.tur, 'ad', c.ad, 'simge', c.simge,
        'baslama', k.baslama, 'bitis', k.bitis, 'ucret', k.ucret, 'hazir', t >= k.bitis)
      from oyun.ek_is_kayit k join oyun.ek_is_katalog c on c.kod = k.tur
      where k.user_id = p.id and k.odendi_at is null limit 1),
    'gecmis', coalesce((select jsonb_agg(to_jsonb(x) order by x.odendi_at desc) from
      (select k.id, c.ad, c.simge, k.ucret, k.odendi_at from oyun.ek_is_kayit k
       join oyun.ek_is_katalog c on c.kod = k.tur
       where k.user_id = p.id and k.odendi_at is not null order by k.odendi_at desc limit 20) x), '[]'::jsonb)
  );
end $fn$;

-- Ana ekrandaki "Ek İşler" şeridi için hafif özet (tek dizinli sayım + açık iş).
create or replace function public.ek_is_ozet() returns jsonb
language plpgsql stable security definer set search_path = '' as $fn$
declare p oyun.profiller := oyun.profilim(); t timestamptz := now();
  g date := (t at time zone 'Europe/Istanbul')::date; lim integer := oyun.ek_is_gunluk_limit(); yap integer;
begin
  select count(*) into yap from oyun.ek_is_kayit where user_id = p.id and gun = g;
  return jsonb_build_object('gunluk_limit', lim, 'bugun_yapilan', yap, 'kalan', greatest(0, lim - yap), 'simdi', t,
    'sifirlanma', ((g + 1)::timestamp at time zone 'Europe/Istanbul'),
    'aktif', (select jsonb_build_object('id', k.id, 'ad', c.ad, 'simge', c.simge, 'bitis', k.bitis, 'ucret', k.ucret, 'hazir', t >= k.bitis)
      from oyun.ek_is_kayit k join oyun.ek_is_katalog c on c.kod = k.tur
      where k.user_id = p.id and k.odendi_at is null limit 1));
end $fn$;

create or replace function public.ek_is_baslat(p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller := oyun.profilim(); c oyun.ek_is_katalog; k oyun.ek_is_kayit;
  t timestamptz := now(); g date := (t at time zone 'Europe/Istanbul')::date;
  lim integer := oyun.ek_is_gunluk_limit(); yap integer; v_id bigint; v_ucret integer; onceki jsonb := null;
begin
  perform 1 from oyun.profiller where id = p.id for update;
  select * into c from oyun.ek_is_katalog where kod = p_tur and aktif and not silindi;
  if c.kod is null then raise exception 'Bu ek iş mevcut değil.'; end if;
  select * into k from oyun.ek_is_kayit where user_id = p.id and odendi_at is null for update;
  if k.id is not null and t < k.bitis then
    raise exception 'Önce devam eden ek işinin süresinin dolmasını bekleyip ücretini al.';
  end if;
  select count(*) into yap from oyun.ek_is_kayit where user_id = p.id and gun = g;
  if yap >= lim then
    raise exception 'Bugünkü % ek iş hakkını doldurdun. Haklar Türkiye saatiyle 00.00''da yenilenir.', lim;
  end if;
  if c.min_kidem > 0 and oyun.kidem_puani(p.id) < c.min_kidem then
    raise exception 'Bu iş için en az % kıdem puanı gerekir.', c.min_kidem;
  end if;
  if k.id is not null then onceki := oyun.ek_is_ode(p.id, k.id, t); end if;
  v_ucret := c.asgari_ucret + floor(random() * (c.azami_ucret - c.asgari_ucret + 1))::int;
  insert into oyun.ek_is_kayit(user_id, tur, baslama, bitis, gun, ucret)
  values (p.id, c.kod, t, t + c.sure_dakika * interval '1 minute', g, v_ucret) returning id into v_id;
  return jsonb_build_object('id', v_id, 'tur', c.kod, 'ad', c.ad, 'bitis', t + c.sure_dakika * interval '1 minute',
    'ucret', v_ucret, 'gunluk_limit', lim, 'bugun_yapilan', yap + 1, 'kalan', greatest(0, lim - yap - 1), 'onceki_odeme', onceki);
end $fn$;

create or replace function public.ek_is_ucret_al(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller := oyun.profilim();
begin
  perform 1 from oyun.profiller where id = p.id for update;
  return oyun.ek_is_ode(p.id, p_id, now());
end $fn$;

-- ---------- Yönetim (yalnız oyunun sahibi) ----------
create or replace function public.yk_ek_is_liste() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $fn$
declare p oyun.profiller := oyun.yk_sahip(); t timestamptz := now();
  g date := (t at time zone 'Europe/Istanbul')::date;
begin
  return jsonb_build_object(
    'gunluk_limit', oyun.ek_is_gunluk_limit(),
    'kategoriler', (select jsonb_agg(jsonb_build_object('kod', k, 'ad', oyun.ek_is_kategori_ad(k)) order by o)
      from unnest(array['hizmet','ulasim','zanaat','egitim_ofis','teknoloji','medya','tarim','diger']) with ordinality as x(k, o)),
    'bugun', (select jsonb_build_object('baslatilan', count(*), 'oyuncu', count(distinct user_id),
        'odenen', coalesce(sum(ucret) filter (where odendi_at is not null), 0)) from oyun.ek_is_kayit where gun = g),
    'isler', coalesce((select jsonb_agg(to_jsonb(c) || jsonb_build_object('kategori_ad', oyun.ek_is_kategori_ad(c.kategori),
        'adet_7g', coalesce(s.adet, 0), 'odenen_7g', coalesce(s.odenen, 0), 'gecmis_var', exists (select 1 from oyun.ek_is_kayit y where y.tur = c.kod))
        order by c.silindi, c.sira, c.ad)
      from oyun.ek_is_katalog c
      left join (select tur, count(*) adet, sum(ucret) filter (where odendi_at is not null) odenen
                 from oyun.ek_is_kayit where baslama > t - interval '7 days' group by tur) s on s.tur = c.kod), '[]'::jsonb));
end $fn$;

create or replace function public.yk_ek_is_ayar(p_gunluk_limit integer) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $fn$
declare p oyun.profiller := oyun.yk_sahip(); once jsonb; sonra jsonb;
begin
  if p_gunluk_limit is null or p_gunluk_limit < 1 or p_gunluk_limit > 24 then
    raise exception 'Günlük ek iş hakkı 1 ile 24 arasında olmalı.';
  end if;
  select to_jsonb(a) into once from oyun.ek_is_ayar a where id = 1 for update;
  update oyun.ek_is_ayar set gunluk_limit = p_gunluk_limit, guncelleme = now() where id = 1;
  select to_jsonb(a) into sonra from oyun.ek_is_ayar a where id = 1;
  perform oyun.yk_kaydet_log(p, 'oyun.ek_is_ayar'::regclass, 'guncelle', jsonb_build_object('id', 1), once, sonra, 'Ek işler: günlük hak ' || p_gunluk_limit);
  return jsonb_build_object('tamam', true, 'gunluk_limit', p_gunluk_limit);
end $fn$;

-- p_kod boşsa yeni meslek eklenir (kod addan üretilir); doluysa yalnız gönderilen alanlar güncellenir.
create or replace function public.yk_ek_is_kaydet(p_kod text, p_veri jsonb) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $fn$
declare p oyun.profiller := oyun.yk_sahip(); c oyun.ek_is_katalog; once jsonb := null; sonra jsonb;
  v jsonb := coalesce(p_veri, '{}'::jsonb); v_kod text := nullif(btrim(coalesce(p_kod, '')), ''); yeni boolean := false;
  taban text; n integer := 1; alan text;
begin
  foreach alan in array array['sure_dakika','asgari_ucret','azami_ucret','sira'] loop
    if v ? alan and coalesce(v ->> alan, '') !~ '^[0-9]{1,9}$' then raise exception 'Süre, ücret ve sıra alanlarına yalnız tam sayı yaz.'; end if;
  end loop;
  if v ? 'min_kidem' and coalesce(v ->> 'min_kidem', '') !~ '^[0-9]{1,6}([.][0-9]{1,2})?$' then raise exception 'Kıdem şartına sayı yaz (şart yoksa 0).'; end if;
  if v_kod is not null then
    select * into c from oyun.ek_is_katalog where kod = v_kod for update;
    if c.kod is null then raise exception 'Bu meslek bulunamadı.'; end if;
    once := to_jsonb(c);
  else
    yeni := true;
    c.simge := '💼'; c.kategori := 'diger'; c.min_kidem := 0; c.aktif := true; c.silindi := false;
    c.sira := coalesce((select max(sira) from oyun.ek_is_katalog), 0) + 1;
  end if;
  if v ? 'ad' then c.ad := btrim(coalesce(v ->> 'ad', '')); end if;
  if v ? 'simge' then c.simge := coalesce(nullif(btrim(coalesce(v ->> 'simge', '')), ''), '💼'); end if;
  if v ? 'aciklama' then c.aciklama := btrim(coalesce(v ->> 'aciklama', '')); end if;
  if v ? 'sure_dakika' then c.sure_dakika := (v ->> 'sure_dakika')::integer; end if;
  if v ? 'asgari_ucret' then c.asgari_ucret := (v ->> 'asgari_ucret')::integer; end if;
  if v ? 'azami_ucret' then c.azami_ucret := (v ->> 'azami_ucret')::integer;
  elsif v ? 'asgari_ucret' and (yeni or c.azami_ucret < c.asgari_ucret) then c.azami_ucret := c.asgari_ucret; end if;
  if v ? 'kategori' then c.kategori := v ->> 'kategori'; end if;
  if v ? 'min_kidem' then c.min_kidem := (v ->> 'min_kidem')::numeric; end if;
  if v ? 'sira' then c.sira := least((v ->> 'sira')::integer, 32000)::smallint; end if;
  if v ? 'aktif' then c.aktif := coalesce((v ->> 'aktif')::boolean, c.aktif); end if;
  if v ? 'silindi' and not coalesce((v ->> 'silindi')::boolean, true) then c.silindi := false; end if;

  if c.ad is null or char_length(c.ad) < 3 or char_length(c.ad) > 40 then raise exception 'Meslek adı 3–40 karakter olmalı.'; end if;
  if char_length(c.simge) > 12 then raise exception 'Simge tek bir emoji olmalı.'; end if;
  if c.aciklama is null or char_length(c.aciklama) < 5 or char_length(c.aciklama) > 160 then raise exception 'Açıklama 5–160 karakter olmalı.'; end if;
  if c.sure_dakika is null or c.sure_dakika < 15 or c.sure_dakika > 480 then raise exception 'Çalışma süresi 15 ile 480 dakika arasında olmalı.'; end if;
  if c.asgari_ucret is null or c.asgari_ucret < 1 or c.asgari_ucret > 1000000 then raise exception 'Ücret 1 ile 1.000.000 ₺ arasında olmalı.'; end if;
  if c.azami_ucret is null or c.azami_ucret < c.asgari_ucret or c.azami_ucret > 1000000 then raise exception 'En yüksek ücret, en düşük ücretten az olamaz (üst sınır 1.000.000 ₺).'; end if;
  if c.kategori is null or c.kategori not in ('hizmet','ulasim','zanaat','egitim_ofis','teknoloji','medya','tarim','diger') then raise exception 'Meslek türü geçersiz.'; end if;
  if c.min_kidem is null or c.min_kidem < 0 then raise exception 'Kıdem şartı eksi olamaz.'; end if;
  if exists (select 1 from oyun.ek_is_katalog x where lower(x.ad) = lower(c.ad) and not x.silindi and (yeni or x.kod <> c.kod)) then
    raise exception 'Bu adla bir meslek zaten var.';
  end if;

  if yeni then
    taban := btrim(regexp_replace(lower(translate(c.ad, 'çğıİöşüÇĞIÖŞÜâîûÂÎÛ', 'cgiiosucgiosuaiuaiu')), '[^a-z0-9]+', '_', 'g'), '_');
    taban := left(coalesce(nullif(taban, ''), 'is'), 28);
    c.kod := taban;
    while exists (select 1 from oyun.ek_is_katalog x where x.kod = c.kod) loop n := n + 1; c.kod := taban || '_' || n; end loop;
    insert into oyun.ek_is_katalog(kod, ad, simge, aciklama, sure_dakika, asgari_ucret, azami_ucret, sira, aktif, kategori, min_kidem, silindi, guncelleme)
    values (c.kod, c.ad, c.simge, c.aciklama, c.sure_dakika, c.asgari_ucret, c.azami_ucret, c.sira, c.aktif, c.kategori, c.min_kidem, false, now());
  else
    update oyun.ek_is_katalog set ad = c.ad, simge = c.simge, aciklama = c.aciklama, sure_dakika = c.sure_dakika,
      asgari_ucret = c.asgari_ucret, azami_ucret = c.azami_ucret, sira = c.sira, aktif = c.aktif, kategori = c.kategori,
      min_kidem = c.min_kidem, silindi = c.silindi, guncelleme = now() where kod = c.kod;
  end if;
  select to_jsonb(x) into sonra from oyun.ek_is_katalog x where x.kod = c.kod;
  perform oyun.yk_kaydet_log(p, 'oyun.ek_is_katalog'::regclass, case when yeni then 'ekle' else 'guncelle' end,
    jsonb_build_object('kod', c.kod), once, sonra, 'Ek işler: ' || c.ad);
  return jsonb_build_object('tamam', true, 'yeni', yeni, 'is', sonra);
end $fn$;

-- Geçmişi olmayan meslek kalıcı silinir; ödeme geçmişi ya da süren işi olan meslek arşive alınır (oyunculara görünmez).
create or replace function public.yk_ek_is_sil(p_kod text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $fn$
declare p oyun.profiller := oyun.yk_sahip(); c oyun.ek_is_katalog; once jsonb; kalici boolean;
begin
  select * into c from oyun.ek_is_katalog where kod = btrim(coalesce(p_kod, '')) for update;
  if c.kod is null then raise exception 'Bu meslek bulunamadı.'; end if;
  once := to_jsonb(c);
  kalici := not exists (select 1 from oyun.ek_is_kayit where tur = c.kod);
  if kalici then
    delete from oyun.ek_is_katalog where kod = c.kod;
  else
    update oyun.ek_is_katalog set aktif = false, silindi = true, guncelleme = now() where kod = c.kod;
  end if;
  perform oyun.yk_kaydet_log(p, 'oyun.ek_is_katalog'::regclass, case when kalici then 'sil' else 'guncelle' end,
    jsonb_build_object('kod', c.kod), once, case when kalici then null else (select to_jsonb(x) from oyun.ek_is_katalog x where x.kod = c.kod) end,
    'Ek işler: ' || c.ad || case when kalici then ' silindi' else ' arşive alındı' end);
  return jsonb_build_object('tamam', true, 'kalici', kalici, 'kod', c.kod);
end $fn$;

do $izin$
declare f text;
begin
  foreach f in array array['oyun.ek_is_ode(uuid,bigint,timestamptz)', 'oyun.ek_is_gunluk_limit()', 'oyun.ek_is_kategori_ad(text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['public.ek_is_paneli()', 'public.ek_is_ozet()', 'public.ek_is_baslat(text)', 'public.ek_is_ucret_al(bigint)',
      'public.yk_ek_is_liste()', 'public.yk_ek_is_ayar(integer)', 'public.yk_ek_is_kaydet(text,jsonb)', 'public.yk_ek_is_sil(text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $izin$;
