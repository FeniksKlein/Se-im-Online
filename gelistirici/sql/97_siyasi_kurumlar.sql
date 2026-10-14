-- =====================================================================
-- 97 · SİYASİ KURUMLAR (2026-10-14)
--   1) Davet kodu        — oyuncu getirene ve gelene ödül (çoklu hesap korumalı)
--   2) Ulusal kriz masası — deprem, salgın, kur şoku... aşamalı kararlar, halk karnesi
--   3) Meclis komisyonları — ihtisas komisyonları, d'Hondt kontenjanı, komisyon raporu
--   4) Parti kapatma davası — Anayasa Mahkemesinde kapatma / hazine yardımından yoksunluk
--   5) Gençlik ve kadın kolları — kol başkanı, üyelik, kasa, etkinlik, duyuru
-- Yalnız EKLER: yeni tablolar, yeni fonksiyonlar, tetikleyiciler. Oyuncu verisine dokunmaz.
-- İki kez çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Ortak yardımcılar
-- ---------------------------------------------------------------------
-- Canlıda 2026-10-10 vekâlet güncellemesiyle gelen sütunlar (kaynak kurulumda yoksa eklenir; canlıda değişiklik yapmaz)
alter table oyun.partiler add column if not exists gb_vekil uuid;
alter table oyun.partiler add column if not exists gb_vekil_bas timestamptz;

-- Parti yönetim yetkisi: genel başkan, vekâleten genel başkan ya da ilgili alanda görevli GBY.
create or replace function oyun.sk_parti_yetki(u uuid, p_parti bigint, p_alan text)
returns boolean language sql stable set search_path = '' as $$
  select u is not null and (
    exists (select 1 from oyun.partiler p where p.id = p_parti and not p.kapali and (p.gb = u or p.gb_vekil = u))
    or exists (select 1 from oyun.parti_gby g where g.parti_id = p_parti and g.user_id = u
               and (p_alan is null or oyun.gby_alan(g.gorev) = p_alan)))
$$;

create or replace function oyun.sk_kad(u uuid) returns text language sql stable set search_path = '' as $$
  select kad from oyun.profiller where id = u
$$;

create or replace function oyun.sk_profil_bul(p_kad text) returns uuid language sql stable set search_path = '' as $$
  select id from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, ''))) limit 1
$$;

-- =====================================================================
-- 1) DAVET KODU
-- =====================================================================
create table if not exists oyun.davet_ayar (
  id             boolean primary key default true check (id),
  aktif          boolean not null default true,
  odul_eden      numeric not null default 20000 check (odul_eden between 0 and 1000000),
  odul_edilen    numeric not null default 10000 check (odul_edilen between 0 and 1000000),
  haftalik_tavan integer not null default 10 check (haftalik_tavan between 0 and 100),
  giris_gun      integer not null default 7 check (giris_gun between 1 and 60),
  sure_gun       integer not null default 45 check (sure_gun between 7 and 365)
);
insert into oyun.davet_ayar(id) values (true) on conflict (id) do nothing;

create table if not exists oyun.davet_kod (
  user_id   uuid primary key references oyun.profiller(id) on delete cascade,
  kod       text not null unique,
  olusturma timestamptz not null default now()
);

create table if not exists oyun.davet (
  id            bigint generated always as identity primary key,
  davet_eden    uuid not null references oyun.profiller(id) on delete cascade,
  davet_edilen  uuid not null unique references oyun.profiller(id) on delete cascade,
  kod           text not null,
  zaman         timestamptz not null,
  durum         text not null default 'bekliyor' check (durum in ('bekliyor','odendi','gecersiz')),
  neden         text,
  odul_at       timestamptz,
  odul_eden     numeric,
  odul_edilen   numeric
);
create index if not exists davet_eden_idx on oyun.davet(davet_eden, durum);

alter table oyun.davet_ayar enable row level security;
alter table oyun.davet_kod enable row level security;
alter table oyun.davet enable row level security;
revoke all on oyun.davet_ayar, oyun.davet_kod, oyun.davet from public, anon, authenticated;

-- Oyuncunun kodu (yoksa üretir). Karışan harfler (I, O, 0, 1, L) kullanılmaz.
create or replace function oyun.davet_kodum(u uuid) returns text
language plpgsql set search_path = '' as $$
declare k text; abc text := 'ABCDEFGHJKMNPRSTUVYZ23456789'; i int; deneme int := 0;
begin
  select kod into k from oyun.davet_kod where user_id = u;
  if k is not null then return k; end if;
  loop
    k := '';
    for i in 1..6 loop k := k || substr(abc, 1 + floor(random() * length(abc))::int, 1); end loop;
    begin
      insert into oyun.davet_kod(user_id, kod) values (u, k);
      return k;
    exception when unique_violation then
      select kod into k from oyun.davet_kod where user_id = u;
      if k is not null then return k; end if;
      deneme := deneme + 1;
      if deneme > 20 then raise exception 'Davet kodu üretilemedi, tekrar dene.'; end if;
    end;
  end loop;
end $$;

-- Bekleyen bir daveti değerlendirir: geçersiz mi, ödenmeli mi, beklemeli mi.
create or replace function oyun.davet_kontrol(p_id bigint, t timestamptz) returns text
language plpgsql set search_path = '' as $$
declare d oyun.davet; a oyun.davet_ayar; pe oyun.profiller; pd oyun.profiller; engel text; n int;
begin
  select * into d from oyun.davet where id = p_id for update;
  if d.id is null or d.durum <> 'bekliyor' then return coalesce(d.durum, 'yok'); end if;
  select * into a from oyun.davet_ayar where id;
  select * into pe from oyun.profiller where id = d.davet_eden;
  select * into pd from oyun.profiller where id = d.davet_edilen;
  if pe.id is null or pd.id is null or pe.yasakli or pd.yasakli then
    update oyun.davet set durum = 'gecersiz', neden = 'Hesaplardan biri kapatıldı.' where id = d.id; return 'gecersiz';
  end if;
  if oyun.bagli_hesap_mi(pe.id, pd.id) then
    update oyun.davet set durum = 'gecersiz', neden = 'Aynı cihaz veya bağlantıdan açılmış hesaplar birbirini davet edemez.' where id = d.id;
    return 'gecersiz';
  end if;
  if d.zaman < t - make_interval(days => a.sure_gun) then
    update oyun.davet set durum = 'gecersiz', neden = format('Davet edilen %s gün içinde oy hakkı kazanmadı.', a.sure_gun) where id = d.id;
    return 'gecersiz';
  end if;
  if not a.aktif then return 'bekliyor'; end if;
  engel := oyun.uyari(pd, t);
  if engel is not null then return 'bekliyor'; end if;
  select count(*) into n from oyun.davet where davet_eden = d.davet_eden and durum = 'odendi' and odul_at > t - interval '7 days';
  if n >= a.haftalik_tavan then return 'bekliyor'; end if;
  if a.odul_eden > 0 then
    perform oyun.para_islem(pe.id, a.odul_eden, 'davet', format('Davet ödülü: %s oy hakkı kazandı', pd.kad), t);
  end if;
  if a.odul_edilen > 0 then
    perform oyun.para_islem(pd.id, a.odul_edilen, 'davet', format('Hoş geldin ödülü (%s seni davet etti)', pe.kad), t);
  end if;
  update oyun.davet set durum = 'odendi', odul_at = t, odul_eden = a.odul_eden, odul_edilen = a.odul_edilen, neden = null where id = d.id;
  perform oyun.bildir(pe.id, format('Davet ettiğin %s oy hakkı kazandı. Davet ödülün %s ₺ cüzdanına yattı.', pd.kad, oyun.tl(a.odul_eden)), t);
  perform oyun.bildir(pd.id, format('Oy hakkı kazandın. %s seni davet ettiği için hoş geldin ödülün %s ₺ cüzdanına yattı.', pe.kad, oyun.tl(a.odul_edilen)), t);
  return 'odendi';
end $$;

create or replace function oyun.davet_tick(t timestamptz) returns integer
language plpgsql set search_path = '' as $$
declare r record; n int := 0;
begin
  for r in select id from oyun.davet where durum = 'bekliyor' order by id loop
    if oyun.davet_kontrol(r.id, t) = 'odendi' then n := n + 1; end if;
  end loop;
  return n;
end $$;

create or replace function public.davet_bilgim() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.davet_ayar; k text; ben oyun.davet;
begin
  select * into a from oyun.davet_ayar where id;
  k := oyun.davet_kodum(p.id);
  select * into ben from oyun.davet where davet_edilen = p.id;
  if ben.id is not null and ben.durum = 'bekliyor' then perform oyun.davet_kontrol(ben.id, t); select * into ben from oyun.davet where id = ben.id; end if;
  return jsonb_build_object(
    'kod', k,
    'ayar', jsonb_build_object('aktif', a.aktif, 'odul_eden', a.odul_eden, 'odul_edilen', a.odul_edilen,
                               'haftalik_tavan', a.haftalik_tavan, 'giris_gun', a.giris_gun, 'sure_gun', a.sure_gun),
    'yonetici', coalesce(p.yonetici, false),
    'sayilar', jsonb_build_object(
       'bekliyor', (select count(*) from oyun.davet where davet_eden = p.id and durum = 'bekliyor'),
       'odendi',   (select count(*) from oyun.davet where davet_eden = p.id and durum = 'odendi'),
       'gecersiz', (select count(*) from oyun.davet where davet_eden = p.id and durum = 'gecersiz'),
       'kazanc',   coalesce((select sum(odul_eden) from oyun.davet where davet_eden = p.id and durum = 'odendi'), 0)),
    'davetlerim', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'zaman', d.zaman, 'durum', d.durum, 'neden', d.neden,
                         'eksik', case when d.durum = 'bekliyor' then oyun.uyari(pr, t) end) order by d.zaman desc, d.id desc)
                       from (select * from oyun.davet where davet_eden = p.id order by zaman desc, id desc limit 50) d
                       join oyun.profiller pr on pr.id = d.davet_edilen), '[]'::jsonb),
    'beni_davet_eden', case when ben.id is null then null else jsonb_build_object('kad', oyun.sk_kad(ben.davet_eden), 'durum', ben.durum,
                         'neden', ben.neden, 'eksik', case when ben.durum = 'bekliyor' then oyun.uyari(p, t) end) end,
    'kod_girebilir', ben.id is null and p.olusturma > t - make_interval(days => a.giris_gun),
    'kod_son', p.olusturma + make_interval(days => a.giris_gun),
    'liderler', coalesce((select jsonb_agg(jsonb_build_object('kad', x.kad, 'n', x.n) order by x.n desc, x.kad)
                     from (select pr.kad, count(*) n from oyun.davet d join oyun.profiller pr on pr.id = d.davet_eden
                           where d.durum = 'odendi' and d.odul_at > t - interval '30 days' and not pr.yasakli
                           group by pr.kad order by count(*) desc, pr.kad limit 10) x), '[]'::jsonb));
end $$;

create or replace function public.davet_kodu_gir(p_kod text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.davet_ayar; eden uuid; v_kod text; yeni bigint; sonuc text;
begin
  select * into a from oyun.davet_ayar where id;
  if not a.aktif then raise exception 'Davet sistemi şu an kapalı.'; end if;
  v_kod := upper(regexp_replace(coalesce(p_kod, ''), '[^A-Za-z0-9]', '', 'g'));
  if length(v_kod) <> 6 then raise exception 'Davet kodu 6 karakter olmalı.'; end if;
  if exists (select 1 from oyun.davet where davet_edilen = p.id) then raise exception 'Zaten bir davet kodu kullandın.'; end if;
  if p.olusturma < t - make_interval(days => a.giris_gun) then
    raise exception 'Davet kodu yalnızca hesabın açıldıktan sonraki % gün içinde girilebilir.', a.giris_gun;
  end if;
  select user_id into eden from oyun.davet_kod where kod = v_kod limit 1;
  if eden is null then raise exception 'Bu davet kodu bulunamadı.'; end if;
  if eden = p.id then raise exception 'Kendi davet kodunu kullanamazsın.'; end if;
  if (select yasakli from oyun.profiller where id = eden) then raise exception 'Bu davet kodu artık geçerli değil.'; end if;
  if (select olusturma from oyun.profiller where id = eden) > p.olusturma then
    raise exception 'Senden sonra katılan bir oyuncunun kodunu kullanamazsın.';
  end if;
  if exists (select 1 from oyun.davet where davet_eden = p.id and davet_edilen = eden) then
    raise exception 'Seni davet ettiğin oyuncunun kodunu kullanamazsın.';
  end if;
  if oyun.bagli_hesap_mi(eden, p.id) then
    raise exception 'Aynı cihaz veya bağlantıdan açılmış hesaplar birbirini davet edemez.';
  end if;
  insert into oyun.davet(davet_eden, davet_edilen, kod, zaman) values (eden, p.id, v_kod, t) returning id into yeni;
  perform oyun.bildir(eden, format('%s davet kodunla oyuna katıldı. Oy hakkı kazandığında ikinize de ödül yatacak.', p.kad), t);
  sonuc := oyun.davet_kontrol(yeni, t);
  return jsonb_build_object('tamam', true, 'durum', sonuc, 'davet_eden', oyun.sk_kad(eden));
end $$;

create or replace function public.davet_ayar_kaydet(p_aktif boolean, p_odul_eden numeric, p_odul_edilen numeric, p_haftalik_tavan integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not coalesce(p.yonetici, false) then raise exception 'Yalnız yönetici değiştirebilir.'; end if;
  if p_odul_eden not between 0 and 1000000 or p_odul_edilen not between 0 and 1000000 then raise exception 'Ödüller 0 ile 1.000.000 ₺ arasında olmalı.'; end if;
  if p_haftalik_tavan not between 0 and 100 then raise exception 'Haftalık sınır 0 ile 100 arasında olmalı.'; end if;
  update oyun.davet_ayar set aktif = p_aktif, odul_eden = round(p_odul_eden), odul_edilen = round(p_odul_edilen), haftalik_tavan = p_haftalik_tavan where id;
  return public.davet_bilgim();
end $$;

-- Tek davet ödülü yeni hesabın tamamen kurulmasından sonra işlenir; tablo/fonksiyon yetkileri
revoke all on function oyun.davet_kodum(uuid), oyun.davet_kontrol(bigint, timestamptz), oyun.davet_tick(timestamptz) from public, anon, authenticated;
revoke all on function public.davet_bilgim(), public.davet_kodu_gir(text), public.davet_ayar_kaydet(boolean, numeric, numeric, integer) from public, anon;
grant execute on function public.davet_bilgim(), public.davet_kodu_gir(text), public.davet_ayar_kaydet(boolean, numeric, numeric, integer) to authenticated;

-- =====================================================================
-- 2) ULUSAL KRİZ MASASI
--    Mevcut seyrek ekonomik krizlerden (kriz_olay) ayrı, daha büyük olaylar.
--    Aşama 1: ilk müdahale (ilgili bakan ya da yürütme, 6 saat)
--    Aşama 2: kalıcı çözüm (cumhurbaşkanı / başbakan, 24 saat)
--    Yerel müdahale: il krizlerinde o ilin belediye başkanı (6 saat)
--    Halk karnesi: oy hakkı olan oyuncular hükümeti ve belediyeyi 1-5 puanlar.
-- =====================================================================
create table if not exists oyun.uk_ayar (
  id               boolean primary key default true check (id),
  aktif            boolean not null default true,
  min_aralik_gun   integer not null default 10 check (min_aralik_gun between 3 and 90),
  haftalik_ihtimal integer not null default 40 check (haftalik_ihtimal between 0 and 100),
  son_kriz         timestamptz not null default now(),
  son_cekilis      date
);
insert into oyun.uk_ayar(id) values (true) on conflict (id) do nothing;

create table if not exists oyun.uk_sablon (
  kod        text primary key,
  kapsam     text not null check (kapsam in ('il','ulke')),
  kategori   text not null,
  baslik     text not null,
  aciklama   text not null,
  bakanlik   text not null,
  il_havuzu  text[],
  baslangic  jsonb not null,
  asama1     jsonb not null,
  asama2     jsonb not null,
  yerel      jsonb
);

create table if not exists oyun.uk_olay (
  id           bigint generated always as identity primary key,
  sablon_kod   text not null references oyun.uk_sablon(kod),
  il_id        smallint references oyun.iller(id),
  bas          timestamptz not null,
  asama        smallint not null default 1 check (asama between 1 and 3),
  durum        text not null default 'aktif' check (durum in ('aktif','bitti')),
  a1_son       timestamptz not null,
  a1_karar     text, a1_veren uuid, a1_at timestamptz,
  a2_son       timestamptz,
  a2_karar     text, a2_veren uuid, a2_at timestamptz,
  y_son        timestamptz,
  y_karar      text, y_veren uuid, y_at timestamptz,
  degerlendirme_son timestamptz,
  maliyet      numeric not null default 0,
  afad_toplam  numeric not null default 0,
  puan_karar   numeric, puan_halk numeric, karne numeric,
  bel_puan_karar numeric, bel_puan_halk numeric, bel_karne numeric,
  sorumlular   jsonb not null default '{}'::jsonb,
  bit          timestamptz
);
create unique index if not exists uk_tek_aktif on oyun.uk_olay(durum) where durum = 'aktif';

create table if not exists oyun.uk_degerlendirme (
  olay_id  bigint not null references oyun.uk_olay(id),
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  hukumet  smallint not null check (hukumet between 1 and 5),
  belediye smallint check (belediye between 1 and 5),
  zaman    timestamptz not null,
  primary key (olay_id, user_id)
);

create table if not exists oyun.uk_kayit (
  id       bigint generated always as identity primary key,
  olay_id  bigint not null references oyun.uk_olay(id),
  user_id  uuid,
  tip      text not null,
  aciklama text not null,
  tutar    numeric not null default 0,
  zaman    timestamptz not null
);
create index if not exists uk_kayit_olay_idx on oyun.uk_kayit(olay_id, zaman);

alter table oyun.uk_ayar enable row level security;
alter table oyun.uk_sablon enable row level security;
alter table oyun.uk_olay enable row level security;
alter table oyun.uk_degerlendirme enable row level security;
alter table oyun.uk_kayit enable row level security;
revoke all on oyun.uk_ayar, oyun.uk_sablon, oyun.uk_olay, oyun.uk_degerlendirme, oyun.uk_kayit from public, anon, authenticated;

-- Seçenek alanları: puan (uzman değerlendirmesi, sonunda açıklanır), hazine_oran (hazinenin payı),
-- ulke_mem / il_mem (memnuniyet puanı), afad_tl (ildeki her oyuncuya nakit yardım), kasa_oran (belediye kasasının payı).
insert into oyun.uk_sablon(kod, kapsam, kategori, baslik, aciklama, bakanlik, il_havuzu, baslangic, asama1, asama2, yerel) values
('deprem','il','Afet','Büyük deprem',
 'Şiddetli bir deprem binalarda ve altyapıda ağır hasara yol açtı. Arama kurtarma, barınma ve yeniden inşa kararları bekleniyor.',
 'icisleri', array['İstanbul','İzmir','Kahramanmaraş','Hatay','Malatya','Adıyaman','Elazığ','Bingöl','Erzincan','Düzce','Kocaeli','Sakarya','Bursa','Balıkesir','Manisa','Muğla','Denizli','Van','Muş','Erzurum','Çanakkale','Yalova','Bolu','Tokat','Osmaniye','Gaziantep','Adana','Aydın'],
 '{"ulke_mem":-2,"il_mem":-12,"il_kasa_oran":-0.10}',
 '[{"kod":"afad","ad":"Tüm AFAD ekiplerini ve orduyu bölgeye gönder","aciklama":"Hızlı ve güçlü müdahale; maliyeti yüksek.","puan":90,"hazine_oran":0.04,"ulke_mem":2,"il_mem":6,"afad_tl":8000},
   {"kod":"koordinasyon","ad":"Valilik koordinasyonunda kademeli müdahale","aciklama":"Daha ucuz ama yavaş.","puan":60,"hazine_oran":0.015,"ulke_mem":0,"il_mem":3,"afad_tl":3000},
   {"kod":"bekle","ad":"Hasar tespiti bitmeden kaynak ayırma","aciklama":"Hazine korunur, halk tepki gösterebilir.","puan":20,"hazine_oran":0,"ulke_mem":-2,"il_mem":-4,"afad_tl":0}]',
 '[{"kod":"kentsel","ad":"Depreme dayanıklı kalıcı konut seferberliği","aciklama":"Uzun vadeli ve pahalı.","puan":90,"hazine_oran":0.06,"ulke_mem":2,"il_mem":8},
   {"kod":"kira","ad":"Afetzedelere kira ve onarım desteği","aciklama":"Hızlı, orta maliyetli.","puan":70,"hazine_oran":0.025,"ulke_mem":1,"il_mem":4},
   {"kod":"belediye","ad":"Yeniden inşayı belediyeye bırak","aciklama":"Hazine harcamaz; yük belediyeye kalır.","puan":30,"hazine_oran":0,"ulke_mem":-1,"il_mem":-3}]',
 '[{"kod":"cadir","ad":"Belediye kasasından çadır kent ve aşevi kur","aciklama":"Belediye kasasının %25''i harcanır.","puan":90,"kasa_oran":0.25,"il_mem":6},
   {"kod":"ulasim","ad":"Ücretsiz ulaşım ve su dağıtımı","aciklama":"Belediye kasasının %10''u harcanır.","puan":65,"kasa_oran":0.10,"il_mem":3},
   {"kod":"merkez","ad":"Merkezi hükümetin müdahalesini bekle","aciklama":"Kasa korunur.","puan":20,"kasa_oran":0,"il_mem":-3}]'),
('sel','il','Afet','Sel felaketi',
 'Şiddetli yağışların ardından dereler taştı; evler, yollar ve tarım alanları sular altında kaldı.',
 'icisleri', array['Rize','Trabzon','Artvin','Giresun','Ordu','Samsun','Kastamonu','Bartın','Sinop','Zonguldak','Düzce','Antalya','Mersin','Ankara','İstanbul'],
 '{"ulke_mem":-1,"il_mem":-8,"il_kasa_oran":-0.06}',
 '[{"kod":"tahliye","ad":"Riskli bölgeleri hemen tahliye et, ekip gönder","aciklama":"Can kaybını önler, maliyetli.","puan":90,"hazine_oran":0.025,"ulke_mem":1,"il_mem":5,"afad_tl":5000},
   {"kod":"yerel","ad":"Yerel ekiplere ek kaynak aktar","aciklama":"Orta yol.","puan":65,"hazine_oran":0.01,"ulke_mem":0,"il_mem":2,"afad_tl":2000},
   {"kod":"izle","ad":"Durumu izle, açıklama yap","aciklama":"Masrafsız.","puan":25,"hazine_oran":0,"ulke_mem":-1,"il_mem":-4,"afad_tl":0}]',
 '[{"kod":"islah","ad":"Dere ıslahı ve dere yatağındaki yapıların kaldırılması","aciklama":"Kalıcı çözüm, pahalı.","puan":90,"hazine_oran":0.04,"ulke_mem":1,"il_mem":6},
   {"kod":"tazminat","ad":"Hasar tazminatı ve çiftçi desteği","aciklama":"Mağduru rahatlatır.","puan":70,"hazine_oran":0.02,"ulke_mem":1,"il_mem":4},
   {"kod":"sigorta","ad":"Zarar sigortaya kalsın","aciklama":"Hazine harcamaz.","puan":30,"hazine_oran":0,"ulke_mem":-1,"il_mem":-3}]',
 '[{"kod":"altyapi","ad":"Kanalizasyon ve yolları acil onar","aciklama":"Belediye kasasının %20''si harcanır.","puan":85,"kasa_oran":0.20,"il_mem":5},
   {"kod":"temizlik","ad":"Çamur temizliği ve geçici barınma","aciklama":"Belediye kasasının %8''i harcanır.","puan":65,"kasa_oran":0.08,"il_mem":3},
   {"kod":"merkez","ad":"Merkezi hükümeti bekle","aciklama":"Kasa korunur.","puan":20,"kasa_oran":0,"il_mem":-3}]'),
('yangin','il','Afet','Büyük orman yangını',
 'Rüzgârın etkisiyle büyüyen orman yangını yerleşim yerlerine yaklaşıyor.',
 'tarim', array['Antalya','Muğla','İzmir','Aydın','Mersin','Adana','Çanakkale','Manisa','Denizli','Hatay','Osmaniye','Balıkesir'],
 '{"ulke_mem":-1,"il_mem":-7,"il_kasa_oran":-0.05}',
 '[{"kod":"hava","ad":"Yangın uçakları ve helikopterleri kirala","aciklama":"Hızlı söndürme, pahalı.","puan":90,"hazine_oran":0.03,"ulke_mem":2,"il_mem":5,"afad_tl":3000},
   {"kod":"kara","ad":"Komşu illerden kara ekipleri gönder","aciklama":"Daha ucuz, daha yavaş.","puan":65,"hazine_oran":0.01,"ulke_mem":0,"il_mem":2,"afad_tl":1000},
   {"kod":"gonullu","ad":"Gönüllülere çağrı yap","aciklama":"Masrafsız ama riskli.","puan":30,"hazine_oran":0,"ulke_mem":-1,"il_mem":-3,"afad_tl":0}]',
 '[{"kod":"agac","ad":"Ağaçlandırma ve orman yasası","aciklama":"Yanan alanlar imara kapatılır, yeniden ağaçlandırılır.","puan":85,"hazine_oran":0.025,"ulke_mem":2,"il_mem":5},
   {"kod":"filo","ad":"Kalıcı yangın söndürme filosu kur","aciklama":"Pahalı, gelecekteki yangınlara hazırlık.","puan":80,"hazine_oran":0.04,"ulke_mem":1,"il_mem":4},
   {"kod":"turizm","ad":"Yanan alanları turizme aç","aciklama":"Hazine kazanır gibi görünür; halk tepki gösterir.","puan":10,"hazine_oran":0,"ulke_mem":-3,"il_mem":-5}]',
 '[{"kod":"su","ad":"Belediye su tankerlerini ve iş makinelerini seferber et","aciklama":"Belediye kasasının %15''i harcanır.","puan":85,"kasa_oran":0.15,"il_mem":5},
   {"kod":"tahliye","ad":"Mahalle tahliyesini organize et","aciklama":"Belediye kasasının %6''sı harcanır.","puan":70,"kasa_oran":0.06,"il_mem":3},
   {"kod":"merkez","ad":"Bakanlığın ekiplerini bekle","aciklama":"Kasa korunur.","puan":20,"kasa_oran":0,"il_mem":-3}]'),
('maden','il','İş kazası','Maden ocağında göçük',
 'Bir maden ocağında meydana gelen göçükte işçiler mahsur kaldı. Kurtarma ve iş güvenliği kararları bekleniyor.',
 'calisma', array['Zonguldak','Manisa','Bartın','Karabük','Erzincan','Şırnak','Kütahya','Bursa'],
 '{"ulke_mem":-2,"il_mem":-6}',
 '[{"kod":"kurtarma","ad":"Ulusal kurtarma ekiplerini seferber et","aciklama":"Tüm imkânlar kullanılır.","puan":90,"hazine_oran":0.015,"ulke_mem":2,"il_mem":5,"afad_tl":4000},
   {"kod":"sirket","ad":"Kurtarmayı işletmeye bırak, denetle","aciklama":"Masraf az, güven düşük.","puan":45,"hazine_oran":0.003,"ulke_mem":-1,"il_mem":1,"afad_tl":0},
   {"kod":"aciklama","ad":"Kazayı küçümseyen bir açıklama yap","aciklama":"Masrafsız; halk sert tepki gösterir.","puan":5,"hazine_oran":0,"ulke_mem":-4,"il_mem":-6,"afad_tl":0}]',
 '[{"kod":"yasa","ad":"İş güvenliği yasası ve bağımsız denetim","aciklama":"Kalıcı reform.","puan":90,"hazine_oran":0.01,"ulke_mem":3,"il_mem":4},
   {"kod":"tazminat","ad":"Ailelere tazminat ve maaş bağla","aciklama":"Mağdurları korur.","puan":70,"hazine_oran":0.015,"ulke_mem":1,"il_mem":4},
   {"kod":"ceza","ad":"Yalnız işletmeye para cezası kes","aciklama":"Hazine harcamaz.","puan":35,"hazine_oran":0,"ulke_mem":-1,"il_mem":-2}]',
 '[{"kod":"aile","ad":"Aileler için kriz merkezi ve sosyal destek","aciklama":"Belediye kasasının %10''u harcanır.","puan":85,"kasa_oran":0.10,"il_mem":5},
   {"kod":"anma","ad":"Yas ilan et, anma töreni düzenle","aciklama":"Belediye kasasının %2''si harcanır.","puan":55,"kasa_oran":0.02,"il_mem":2},
   {"kod":"sessiz","ad":"Açıklama yapma","aciklama":"Kasa korunur.","puan":10,"kasa_oran":0,"il_mem":-4}]'),
('salgin','ulke','Sağlık','Salgın hastalık',
 'Hızla yayılan bir solunum yolu hastalığı hastanelerde yoğunluğa yol açıyor. Ülke çapında sağlık tedbirleri gerekiyor.',
 'saglik', null,
 '{"ulke_mem":-4}',
 '[{"kod":"karantina","ad":"Hedefli karantina ve ücretsiz test","aciklama":"Yayılımı hızla keser, maliyetli.","puan":85,"hazine_oran":0.03,"ulke_mem":2},
   {"kod":"kapanma","ad":"Tam kapanma ilan et","aciklama":"Salgın durur, ekonomi sarsılır.","puan":60,"hazine_oran":0.05,"ulke_mem":-1},
   {"kod":"serbest","ad":"Hayat normal aksın, sürü bağışıklığı beklensin","aciklama":"Masrafsız, riskli.","puan":15,"hazine_oran":0,"ulke_mem":-4}]',
 '[{"kod":"asi","ad":"Yerli aşı üretimi ve ücretsiz aşılama","aciklama":"Kalıcı çözüm.","puan":90,"hazine_oran":0.05,"ulke_mem":4},
   {"kod":"hastane","ad":"Hastane kapasitesini artır, sağlıkçıya ek ödeme","aciklama":"Sağlık sistemini güçlendirir.","puan":75,"hazine_oran":0.03,"ulke_mem":2},
   {"kod":"maske","ad":"Maske ve mesafe kuralıyla devam et","aciklama":"Ucuz ama yetersiz.","puan":40,"hazine_oran":0.003,"ulke_mem":0}]', null),
('kur','ulke','Ekonomi','Kur şoku',
 'Döviz kuru bir gecede sert yükseldi. Fiyatlar artıyor, piyasalar hükümetten güven veren adımlar bekliyor.',
 'maliye', null,
 '{"ulke_mem":-4}',
 '[{"kod":"aciklama","ad":"Merkez Bankası ile ortak güven açıklaması","aciklama":"Masrafsız, piyasayı yatıştırabilir.","puan":75,"hazine_oran":0,"ulke_mem":1},
   {"kod":"rezerv","ad":"Rezervlerle kura müdahale et","aciklama":"Kısa vadede etkili, pahalı.","puan":55,"hazine_oran":0.05,"ulke_mem":2},
   {"kod":"sessiz","ad":"Spekülatif saldırı açıklaması yap","aciklama":"Güveni azaltır.","puan":15,"hazine_oran":0,"ulke_mem":-3}]',
 '[{"kod":"program","ad":"Orta vadeli ekonomik program ve bütçe disiplini","aciklama":"Kalıcı güven.","puan":90,"hazine_oran":0.005,"ulke_mem":2},
   {"kod":"destek","ad":"Dar gelirliye enflasyon desteği","aciklama":"Halkı rahatlatır, pahalı.","puan":65,"hazine_oran":0.04,"ulke_mem":4},
   {"kod":"kontrol","ad":"Fiyat ve kambiyo kontrolü getir","aciklama":"Piyasayı bozar.","puan":25,"hazine_oran":0,"ulke_mem":-1}]', null),
('enerji','ulke','Enerji','Kış ortasında enerji krizi',
 'Doğal gaz tedarikindeki aksama nedeniyle elektrik ve ısınmada kesintiler başladı.',
 'sanayi', null,
 '{"ulke_mem":-3}',
 '[{"kod":"spot","ad":"Spot piyasadan acil LNG satın al","aciklama":"Kesintiler durur, pahalı.","puan":80,"hazine_oran":0.04,"ulke_mem":3},
   {"kod":"sanayi","ad":"Önce sanayiye kesinti uygula, konutu koru","aciklama":"Halk korunur, üretim düşer.","puan":65,"hazine_oran":0,"ulke_mem":1},
   {"kod":"donusumlu","ad":"Konutlarda dönüşümlü kesinti","aciklama":"Masrafsız, halk tepkili.","puan":30,"hazine_oran":0,"ulke_mem":-3}]',
 '[{"kod":"yenilenebilir","ad":"Yenilenebilir enerji ve depolama seferberliği","aciklama":"Dışa bağımlılığı azaltır.","puan":90,"hazine_oran":0.05,"ulke_mem":3},
   {"kod":"anlasma","ad":"Uzun vadeli gaz anlaşması imzala","aciklama":"Tedarik garantisi.","puan":70,"hazine_oran":0.02,"ulke_mem":1},
   {"kod":"zam","ad":"Enerjiye zam yap, talebi kıs","aciklama":"Hazine kazanır, halk öfkelenir.","puan":25,"hazine_oran":0,"ulke_mem":-4}]', null),
('grev','ulke','Çalışma hayatı','Genel grev',
 'Sendikalar ücret ve çalışma koşulları nedeniyle ülke çapında iş bıraktı. Ulaşım ve kamu hizmetleri aksıyor.',
 'calisma', null,
 '{"ulke_mem":-3}',
 '[{"kod":"masa","ad":"Sendikalarla hemen masaya otur","aciklama":"Uzlaşma yolu açılır.","puan":85,"hazine_oran":0.005,"ulke_mem":2},
   {"kod":"arabulucu","ad":"Bağımsız arabulucu ata","aciklama":"Zaman alır.","puan":60,"hazine_oran":0.002,"ulke_mem":0},
   {"kod":"erteleme","ad":"Grevi milli güvenlik gerekçesiyle ertele","aciklama":"İşler yürür, gerginlik artar.","puan":20,"hazine_oran":0,"ulke_mem":-4}]',
 '[{"kod":"sozlesme","ad":"Enflasyon üstü toplu sözleşme","aciklama":"Kalıcı barış, pahalı.","puan":80,"hazine_oran":0.04,"ulke_mem":3},
   {"kod":"reform","ad":"Çalışma hayatı reformu ve sosyal diyalog kurulu","aciklama":"Uzun vadeli çözüm.","puan":85,"hazine_oran":0.01,"ulke_mem":2},
   {"kod":"sert","ad":"Grevcilere yaptırım uygula","aciklama":"Hazine harcamaz.","puan":15,"hazine_oran":0,"ulke_mem":-4}]', null),
('kuraklik','ulke','Tarım','Kuraklık ve su krizi',
 'Barajlardaki su seviyesi kritik düzeye düştü. Tarım üretimi ve şehirlerin suyu risk altında.',
 'tarim', null,
 '{"ulke_mem":-2}',
 '[{"kod":"tasarruf","ad":"Ulusal su tasarrufu seferberliği","aciklama":"Ucuz ve etkili.","puan":80,"hazine_oran":0.005,"ulke_mem":1},
   {"kod":"ciftci","ad":"Çiftçiye acil kuraklık desteği","aciklama":"Üretici korunur.","puan":70,"hazine_oran":0.025,"ulke_mem":2},
   {"kod":"bekle","ad":"Yağışları bekle","aciklama":"Masrafsız.","puan":15,"hazine_oran":0,"ulke_mem":-3}]',
 '[{"kod":"sulama","ad":"Damla sulama ve su havzası yönetimi","aciklama":"Kalıcı çözüm.","puan":90,"hazine_oran":0.035,"ulke_mem":3},
   {"kod":"baraj","ad":"Yeni baraj ve isale hatları","aciklama":"Pahalı ve yavaş.","puan":65,"hazine_oran":0.05,"ulke_mem":2},
   {"kod":"ithalat","ad":"Eksik ürünü ithalatla kapat","aciklama":"Kısa vadeli.","puan":40,"hazine_oran":0.015,"ulke_mem":0}]', null),
('siber','ulke','Teknoloji','Kamuya siber saldırı',
 'Kamu kurumlarının dijital sistemleri büyük bir siber saldırıyla çöktü. Vatandaş verilerinin güvenliği sorgulanıyor.',
 'ulastirma', null,
 '{"ulke_mem":-2}',
 '[{"kod":"izolasyon","ad":"Sistemleri izole et, uzman ekip kur","aciklama":"Hasarı sınırlar.","puan":85,"hazine_oran":0.01,"ulke_mem":1},
   {"kod":"seffaf","ad":"Vatandaşı bilgilendir, şifre yenileme çağrısı yap","aciklama":"Güven kazandırır.","puan":70,"hazine_oran":0,"ulke_mem":1},
   {"kod":"inkar","ad":"Saldırıyı yalanla","aciklama":"Masrafsız, ortaya çıkarsa güven çöker.","puan":10,"hazine_oran":0,"ulke_mem":-3}]',
 '[{"kod":"kurum","ad":"Ulusal siber güvenlik kurumu ve yerli yazılım","aciklama":"Kalıcı çözüm.","puan":90,"hazine_oran":0.025,"ulke_mem":2},
   {"kod":"veri","ad":"Kişisel verileri koruma yasasını sertleştir","aciklama":"Hukuki güvence.","puan":70,"hazine_oran":0.003,"ulke_mem":2},
   {"kod":"yabanci","ad":"Yabancı şirketten hazır sistem satın al","aciklama":"Hızlı ama bağımlılık yaratır.","puan":40,"hazine_oran":0.02,"ulke_mem":0}]', null),
('gida','ulke','Ekonomi','Gıda fiyatlarında patlama',
 'Temel gıda ürünlerinin fiyatı birkaç haftada katlandı. Market rafları ve pazarlar gündemin ilk sırasında.',
 'ticaret', null,
 '{"ulke_mem":-3}',
 '[{"kod":"denetim","ad":"Fahiş fiyat denetimi ve stokçuluğa ceza","aciklama":"Hızlı etki, masrafsız.","puan":70,"hazine_oran":0.002,"ulke_mem":2},
   {"kod":"kooperatif","ad":"Tarım kredi marketlerinde indirimli satış","aciklama":"Doğrudan rahatlama, maliyetli.","puan":75,"hazine_oran":0.02,"ulke_mem":2},
   {"kod":"suclu","ad":"Fiyat artışlarını dış güçlere bağla","aciklama":"Masrafsız.","puan":10,"hazine_oran":0,"ulke_mem":-3}]',
 '[{"kod":"uretim","ad":"Üretici destekleri ve hal yasası reformu","aciklama":"Kalıcı çözüm.","puan":90,"hazine_oran":0.03,"ulke_mem":3},
   {"kod":"kdv","ad":"Temel gıdada KDV''yi sıfırla","aciklama":"Hızlı rahatlama, vergi kaybı.","puan":65,"hazine_oran":0.035,"ulke_mem":3},
   {"kod":"tavan","ad":"Tavan fiyat uygula","aciklama":"Kıtlık riski.","puan":30,"hazine_oran":0,"ulke_mem":-1}]', null)
on conflict (kod) do update set kapsam = excluded.kapsam, kategori = excluded.kategori, baslik = excluded.baslik, aciklama = excluded.aciklama,
  bakanlik = excluded.bakanlik, il_havuzu = excluded.il_havuzu, baslangic = excluded.baslangic, asama1 = excluded.asama1, asama2 = excluded.asama2, yerel = excluded.yerel;

create or replace function oyun.uk_mem_ulke(p_delta numeric) returns void language sql set search_path = '' as $$
  update oyun.ulke set memnuniyet = least(100, greatest(0, coalesce(memnuniyet, 50) + coalesce(p_delta, 0))) where id = 1
$$;
create or replace function oyun.uk_mem_il(p_il smallint, p_delta numeric) returns void language sql set search_path = '' as $$
  update oyun.il_durum set memnuniyet = least(100, greatest(0, coalesce(memnuniyet, 50) + coalesce(p_delta, 0))) where il_id = p_il and p_il is not null
$$;

-- Bir krizin karar yetkilileri (güncel makam sahiplerine göre)
create or replace function oyun.uk_bakan(p_bakanlik text) returns uuid language sql stable set search_path = '' as $$
  select user_id from oyun.makamlar where tur = 'bakan' and bakanlik = p_bakanlik and bit is null order by bas desc limit 1
$$;
create or replace function oyun.uk_belediye(p_il smallint) returns uuid language sql stable set search_path = '' as $$
  select user_id from oyun.makamlar where tur = 'bel' and il_id = p_il and bit is null order by bas desc limit 1
$$;

create or replace function oyun.uk_secenek(p_dizi jsonb, p_kod text) returns jsonb language sql immutable set search_path = '' as $$
  select value from jsonb_array_elements(coalesce(p_dizi, '[]'::jsonb)) value where value ->> 'kod' = p_kod limit 1
$$;

-- Bir seçeneğin etkisini uygular. Hazine milyar ₺; oyuncu yardımları oyunun resmî kuruyla hazineden düşer.
create or replace function oyun.uk_uygula(p_olay bigint, sec jsonb, p_tur text, u uuid, t timestamptz) returns text
language plpgsql set search_path = '' as $$
declare o oyun.uk_olay; h numeric; v_maliyet numeric := 0; afad numeric; n int := 0; r record; v_kasa numeric; harcama numeric := 0; ilad text; ozet text;
begin
  select * into o from oyun.uk_olay where id = p_olay for update;
  select ad into ilad from oyun.iller where id = o.il_id;
  if p_tur in ('ilk','kalici') then
    select hazine into h from oyun.ulke where id = 1 for update;
    v_maliyet := round(greatest(coalesce(h, 0), 0) * least(0.10, greatest(0, coalesce((sec ->> 'hazine_oran')::numeric, 0))), 3);
    update oyun.ulke set hazine = hazine - v_maliyet where id = 1;
    perform oyun.uk_mem_ulke((sec ->> 'ulke_mem')::numeric);
    perform oyun.uk_mem_il(o.il_id, (sec ->> 'il_mem')::numeric);
    afad := coalesce((sec ->> 'afad_tl')::numeric, 0);
    if afad > 0 and o.il_id is not null then
      for r in select id from oyun.profiller where il_id = o.il_id and not yasakli loop
        perform oyun.para_islem(r.id, afad, 'afad', format('AFAD afet yardımı (%s)', ilad), t);
        n := n + 1;
      end loop;
      if n > 0 then
        update oyun.ulke set hazine = hazine - (afad * n) / oyun.pazar_tl_milyar() where id = 1;
        insert into oyun.bildirimler(user_id, zaman, metin)
          select id, t, format('%s için kriz yardımı: cüzdanına %s ₺ AFAD yardımı yattı.', ilad, oyun.tl(afad))
          from oyun.profiller where il_id = o.il_id and not yasakli;
      end if;
    end if;
    update oyun.uk_olay set maliyet = maliyet + v_maliyet + (afad * n) / oyun.pazar_tl_milyar(), afad_toplam = afad_toplam + afad * n where id = o.id;
    ozet := format('%s. Hazine maliyeti %s milyar ₺%s.', sec ->> 'ad', round(v_maliyet + (afad * n) / oyun.pazar_tl_milyar(), 2),
                   case when n > 0 then format(', %s oyuncuya %s ₺ AFAD yardımı', n, oyun.tl(afad)) else '' end);
  else
    select il_durum.kasa into v_kasa from oyun.il_durum where il_id = o.il_id for update;
    harcama := round(greatest(coalesce(v_kasa, 0), 0) * least(0.5, greatest(0, coalesce((sec ->> 'kasa_oran')::numeric, 0))), 4);
    update oyun.il_durum set kasa = kasa - harcama where il_id = o.il_id;
    perform oyun.uk_mem_il(o.il_id, (sec ->> 'il_mem')::numeric);
    ozet := format('%s. Belediye kasasından %s milyar ₺ harcandı.', sec ->> 'ad', round(harcama, 3));
  end if;
  insert into oyun.uk_kayit(olay_id, user_id, tip, aciklama, tutar, zaman) values (o.id, u, p_tur, ozet, v_maliyet + harcama, t);
  return ozet;
end $$;

create or replace function oyun.uk_baslat(p_kod text, t timestamptz, p_il smallint default null) returns bigint
language plpgsql set search_path = '' as $$
declare s oyun.uk_sablon; v_il smallint; b jsonb; cb uuid; bakan uuid; bel uuid; yeni bigint; ilad text; baslik text; bakad text;
begin
  select * into s from oyun.uk_sablon where kod = p_kod;
  if s.kod is null then raise exception 'Kriz türü bulunamadı.'; end if;
  if exists (select 1 from oyun.uk_olay where durum = 'aktif') then raise exception 'Zaten süren bir ulusal kriz var.'; end if;
  if s.kapsam = 'il' then
    v_il := p_il;
    if v_il is null then
      select i.id into v_il from oyun.iller i where i.ad = any(s.il_havuzu)
       order by (1 + (select count(*) from oyun.profiller pr where pr.il_id = i.id and not pr.yasakli)) * random() desc limit 1;
    end if;
    if v_il is null then select id into v_il from oyun.iller order by random() limit 1; end if;
    select ad into ilad from oyun.iller where id = v_il;
  end if;
  b := s.baslangic;
  perform oyun.uk_mem_ulke((b ->> 'ulke_mem')::numeric);
  perform oyun.uk_mem_il(v_il, (b ->> 'il_mem')::numeric);
  if v_il is not null and coalesce((b ->> 'il_kasa_oran')::numeric, 0) < 0 then
    update oyun.il_durum set kasa = kasa * (1 + (b ->> 'il_kasa_oran')::numeric) where il_id = v_il and kasa > 0;
  end if;
  cb := oyun.yurutme_user(); bakan := oyun.uk_bakan(s.bakanlik); bel := case when v_il is not null then oyun.uk_belediye(v_il) end;
  insert into oyun.uk_olay(sablon_kod, il_id, bas, a1_son, y_son, sorumlular)
  values (s.kod, v_il, t, t + interval '6 hours', case when v_il is not null then t + interval '6 hours' end,
          jsonb_build_object('yurutme', cb, 'bakan', bakan, 'belediye', bel))
  returning id into yeni;
  baslik := s.baslik || coalesce(' · ' || ilad, '');
  select ad into bakad from oyun.bakanliklar where kod = s.bakanlik;
  insert into oyun.uk_kayit(olay_id, tip, aciklama, zaman) values (yeni, 'basla', s.aciklama, t);
  update oyun.uk_ayar set son_kriz = t where id;
  perform oyun.olay('ulusal_kriz', format('ULUSAL KRİZ: %s. İlk müdahale kararı 6 saat içinde %s ya da yürütme tarafından verilmeli.', baslik, bakad), v_il, null, t);
  perform oyun.bildir(x, format('Ulusal kriz: %s. İlk müdahale kararı için 6 saatin var. Devlet › Kriz Masası.', baslik), t)
    from (select distinct unnest(array[cb, bakan]) x) y where x is not null;
  if bel is not null then
    perform oyun.bildir(bel, format('İlinde kriz: %s. Belediye olarak 6 saat içinde yerel müdahale kararı ver. Devlet › Kriz Masası.', baslik), t);
  end if;
  if v_il is not null then
    insert into oyun.bildirimler(user_id, zaman, metin)
      select id, t, format('İlinde %s yaşandı. Hükümetin ve belediyenin kriz yönetimini Kriz Masası''ndan puanlayabilirsin.', lower(s.baslik))
      from oyun.profiller where il_id = v_il and not yasakli and id is distinct from bel and id is distinct from cb and id is distinct from bakan;
  else
    insert into oyun.bildirimler(user_id, zaman, metin)
      select id, t, format('Ulusal kriz: %s. Hükümetin kriz yönetimini Kriz Masası''ndan takip edip puanlayabilirsin.', s.baslik)
      from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days' and id is distinct from cb and id is distinct from bakan;
  end if;
  return yeni;
end $$;

create or replace function oyun.uk_kidem(u uuid, iyi boolean, p_baslik text, p_karne numeric, p_rol text, t timestamptz) returns void
language plpgsql set search_path = '' as $$
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u) then return; end if;
  perform oyun.kidem_ekle(u, case when iyi then 3 else -2 end);
  perform oyun.bildir(u, case when iyi
    then format('%s krizinde %s olarak aldığın kararlar başarılı bulundu (karne %s/100). Kıdemin +3 arttı.', p_baslik, p_rol, round(p_karne))
    else format('%s krizinde %s olarak kriz yönetimin başarısız bulundu (karne %s/100). Kıdemin 2 azaldı.', p_baslik, p_rol, round(coalesce(p_karne, 0))) end, t);
end $$;

create or replace function oyun.uk_bitir(p_olay bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare o oyun.uk_olay; s oyun.uk_sablon; p1 numeric; p2 numeric; py numeric; hk numeric; hb numeric; nk int; nb int;
  v_karne numeric; v_bkarne numeric; baslik text; sorumlu uuid;
begin
  select * into o from oyun.uk_olay where id = p_olay for update;
  if o.durum <> 'aktif' then return; end if;
  select * into s from oyun.uk_sablon where kod = o.sablon_kod;
  baslik := s.baslik || coalesce(' (' || (select ad from oyun.iller where id = o.il_id) || ')', '');
  p1 := coalesce((oyun.uk_secenek(s.asama1, o.a1_karar) ->> 'puan')::numeric, 0);
  p2 := coalesce((oyun.uk_secenek(s.asama2, o.a2_karar) ->> 'puan')::numeric, 0);
  select avg(hukumet), count(*) into hk, nk from oyun.uk_degerlendirme where olay_id = o.id;
  hk := case when nk >= 3 then round((hk - 1) * 25, 1) end;
  v_karne := case when hk is null then round((p1 + p2) / 2) else round(0.6 * (p1 + p2) / 2 + 0.4 * hk) end;
  if o.il_id is not null then
    py := coalesce((oyun.uk_secenek(s.yerel, o.y_karar) ->> 'puan')::numeric, 0);
    select avg(belediye), count(belediye) into hb, nb from oyun.uk_degerlendirme where olay_id = o.id and belediye is not null;
    hb := case when nb >= 3 then round((hb - 1) * 25, 1) end;
    v_bkarne := case when hb is null then py else round(0.6 * py + 0.4 * hb) end;
  end if;
  update oyun.uk_olay set durum = 'bitti', bit = t, puan_karar = round((p1 + p2) / 2), puan_halk = hk, karne = v_karne,
         bel_puan_karar = py, bel_puan_halk = hb, bel_karne = v_bkarne where id = o.id;
  -- Kararı verenler kıdem kazanır/kaybeder; süresinde karar vermeyen sorumlu kaybeder.
  if o.a1_karar = 'yok' then sorumlu := coalesce((o.sorumlular ->> 'bakan')::uuid, (o.sorumlular ->> 'yurutme')::uuid);
     perform oyun.uk_kidem(sorumlu, false, baslik, v_karne, 'ilk müdahaleden sorumlu yetkili', t);
  else perform oyun.uk_kidem(o.a1_veren, v_karne >= 60, baslik, v_karne, 'ilk müdahale kararını veren', t); end if;
  if o.a2_karar = 'yok' then
     if (o.sorumlular ->> 'yurutme')::uuid is distinct from sorumlu or o.a1_karar <> 'yok' then
       perform oyun.uk_kidem((o.sorumlular ->> 'yurutme')::uuid, false, baslik, v_karne, 'yürütmenin başı', t); end if;
  elsif o.a2_veren is distinct from o.a1_veren then perform oyun.uk_kidem(o.a2_veren, v_karne >= 60, baslik, v_karne, 'kalıcı çözüm kararını veren', t); end if;
  if o.il_id is not null then
    if o.y_karar = 'yok' then perform oyun.uk_kidem((o.sorumlular ->> 'belediye')::uuid, false, baslik, v_bkarne, 'belediye başkanı', t);
    else perform oyun.uk_kidem(o.y_veren, v_bkarne >= 60, baslik, v_bkarne, 'belediye başkanı', t); end if;
  end if;
  insert into oyun.uk_kayit(olay_id, tip, aciklama, zaman) values (o.id, 'karne',
    format('Kriz sona erdi. Hükümet karnesi %s/100%s.', v_karne, case when o.il_id is not null then format(', belediye karnesi %s/100', v_bkarne) else '' end), t);
  perform oyun.olay('ulusal_kriz', format('%s krizi sona erdi. Hükümetin kriz karnesi: %s/100%s.', baslik, v_karne,
     case when o.il_id is not null then format(' · Belediye karnesi: %s/100', v_bkarne) else '' end), o.il_id, null, t);
end $$;

create or replace function oyun.uk_tick(t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare o oyun.uk_olay; a oyun.uk_ayar; gun date; sec text; kriz_acik boolean := false; son text;
begin
  select * into o from oyun.uk_olay where durum = 'aktif' for update;
  if o.id is not null then
    if o.asama = 1 and t >= o.a1_son then
      perform oyun.uk_mem_ulke(-3); perform oyun.uk_mem_il(o.il_id, -6);
      update oyun.uk_olay set a1_karar = 'yok', a1_at = o.a1_son, asama = 2, a2_son = t + interval '24 hours' where id = o.id;
      insert into oyun.uk_kayit(olay_id, tip, aciklama, zaman) values (o.id, 'ilk', 'İlk müdahale kararı süresinde verilmedi; halkın memnuniyeti düştü.', t);
      perform oyun.bildir(x, 'Kriz masası: ilk müdahale süresi doldu. Kalıcı çözüm kararı için 24 saatin var.', t)
        from (select oyun.yurutme_user() x) y where x is not null;
      select * into o from oyun.uk_olay where id = o.id;
    end if;
    if o.y_son is not null and o.y_karar is null and t >= o.y_son then
      perform oyun.uk_mem_il(o.il_id, -5);
      update oyun.uk_olay set y_karar = 'yok', y_at = o.y_son where id = o.id;
      insert into oyun.uk_kayit(olay_id, tip, aciklama, zaman) values (o.id, 'yerel', 'Belediye süresinde yerel müdahale kararı vermedi.', t);
      select * into o from oyun.uk_olay where id = o.id;
    end if;
    if o.asama = 2 and t >= o.a2_son then
      perform oyun.uk_mem_ulke(-2); perform oyun.uk_mem_il(o.il_id, -4);
      update oyun.uk_olay set a2_karar = 'yok', a2_at = o.a2_son, asama = 3, degerlendirme_son = t + interval '24 hours' where id = o.id;
      insert into oyun.uk_kayit(olay_id, tip, aciklama, zaman) values (o.id, 'kalici', 'Kalıcı çözüm kararı süresinde verilmedi. Halk değerlendirmesi 24 saat açık.', t);
      select * into o from oyun.uk_olay where id = o.id;
    end if;
    if o.asama = 3 and t >= o.degerlendirme_son and (o.y_son is null or o.y_karar is not null) then
      perform oyun.uk_bitir(o.id, t);
    end if;
    return;
  end if;
  -- Haftalık çekiliş: çarşamba 18.00'den sonra (Türkiye saati) günde bir kez.
  select * into a from oyun.uk_ayar where id for update;
  gun := (t at time zone 'Europe/Istanbul')::date;
  if not a.aktif or extract(isodow from t at time zone 'Europe/Istanbul') <> 3 or extract(hour from t at time zone 'Europe/Istanbul') < 18
     or a.son_cekilis is not distinct from gun then return; end if;
  update oyun.uk_ayar set son_cekilis = gun where id;
  if a.son_kriz + make_interval(days => a.min_aralik_gun) > t then return; end if;
  if to_regclass('oyun.kriz_olay') is not null then
    execute 'select exists (select 1 from oyun.kriz_olay where durum = ''bekliyor'')' into kriz_acik;
  end if;
  if kriz_acik or random() * 100 >= a.haftalik_ihtimal then return; end if;
  select sablon_kod into son from oyun.uk_olay order by id desc limit 1;
  select kod into sec from oyun.uk_sablon where kod is distinct from son order by random() limit 1;
  if sec is not null then perform oyun.uk_baslat(sec, t, null); end if;
end $$;

-- Ekran verisi
create or replace function oyun.uk_secenek_json(p_dizi jsonb, h numeric) returns jsonb language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('kod', v ->> 'kod', 'ad', v ->> 'ad', 'aciklama', v ->> 'aciklama',
      'maliyet', round(greatest(coalesce(h, 0), 0) * coalesce((v ->> 'hazine_oran')::numeric, 0), 2),
      'ulke_mem', coalesce((v ->> 'ulke_mem')::numeric, 0), 'il_mem', coalesce((v ->> 'il_mem')::numeric, 0),
      'afad_tl', coalesce((v ->> 'afad_tl')::numeric, 0), 'kasa_oran', coalesce((v ->> 'kasa_oran')::numeric, 0))), '[]'::jsonb)
  from jsonb_array_elements(coalesce(p_dizi, '[]'::jsonb)) v
$$;

create or replace function oyun.uk_olay_json(o oyun.uk_olay, p oyun.profiller, t timestamptz) returns jsonb
language plpgsql stable set search_path = '' as $$
declare s oyun.uk_sablon; h numeric; yur uuid := oyun.yurutme_user(); bak uuid; bel uuid; sorumlu boolean; deg oyun.uk_degerlendirme;
begin
  select * into s from oyun.uk_sablon where kod = o.sablon_kod;
  select hazine into h from oyun.ulke where id = 1;
  bak := oyun.uk_bakan(s.bakanlik); bel := case when o.il_id is not null then oyun.uk_belediye(o.il_id) end;
  sorumlu := p.id is not distinct from yur or p.id is not distinct from bak
             or p.id is not distinct from o.a1_veren or p.id is not distinct from o.a2_veren;
  select * into deg from oyun.uk_degerlendirme where olay_id = o.id and user_id = p.id;
  return jsonb_build_object(
    'id', o.id, 'kod', s.kod, 'baslik', s.baslik, 'aciklama', s.aciklama, 'kategori', s.kategori, 'kapsam', s.kapsam,
    'il_id', o.il_id, 'il_ad', (select ad from oyun.iller where id = o.il_id),
    'bakanlik', (select ad from oyun.bakanliklar where kod = s.bakanlik),
    'bas', o.bas, 'asama', o.asama, 'durum', o.durum, 'bit', o.bit,
    'a1_son', o.a1_son, 'a2_son', o.a2_son, 'y_son', o.y_son, 'degerlendirme_son', o.degerlendirme_son,
    'ilk', jsonb_build_object('karar', o.a1_karar, 'ad', oyun.uk_secenek(s.asama1, o.a1_karar) ->> 'ad', 'veren', oyun.sk_kad(o.a1_veren), 'at', o.a1_at,
                              'secenekler', case when o.durum = 'aktif' and o.asama = 1 then oyun.uk_secenek_json(s.asama1, h) end),
    'kalici', jsonb_build_object('karar', o.a2_karar, 'ad', oyun.uk_secenek(s.asama2, o.a2_karar) ->> 'ad', 'veren', oyun.sk_kad(o.a2_veren), 'at', o.a2_at,
                              'secenekler', case when o.durum = 'aktif' and o.asama = 2 then oyun.uk_secenek_json(s.asama2, h) end),
    'yerel', case when o.il_id is null then null else jsonb_build_object('karar', o.y_karar, 'ad', oyun.uk_secenek(s.yerel, o.y_karar) ->> 'ad',
                              'veren', oyun.sk_kad(o.y_veren), 'at', o.y_at,
                              'secenekler', case when o.durum = 'aktif' and o.y_karar is null then oyun.uk_secenek_json(s.yerel, h) end,
                              'il_kasa', (select kasa from oyun.il_durum where il_id = o.il_id)) end,
    'yetkililer', jsonb_build_object('yurutme', oyun.sk_kad(yur), 'bakan', oyun.sk_kad(bak), 'belediye', oyun.sk_kad(bel)),
    'yetki_ilk', coalesce(o.durum = 'aktif' and o.asama = 1 and t < o.a1_son and (p.id = yur or p.id = bak), false),
    'yetki_kalici', coalesce(o.durum = 'aktif' and o.asama = 2 and t < o.a2_son and p.id = yur, false),
    'yetki_yerel', coalesce(o.durum = 'aktif' and o.il_id is not null and o.y_karar is null and t < o.y_son and p.id = bel, false),
    'degerlendirebilir', coalesce(o.durum = 'aktif' and not sorumlu and oyun.uyari(p, t) is null, false),
    'degerlendirme_engel', case when o.durum <> 'aktif' then null when sorumlu then 'Kriz yönetiminden sorumlu olduğun için puan veremezsin.' else oyun.uyari(p, t) end,
    'belediye_puanlayabilir', coalesce(o.il_id is not null and p.il_id = o.il_id and p.id is distinct from bel and p.id is distinct from o.y_veren, false),
    'puanim', case when deg.olay_id is null then null else jsonb_build_object('hukumet', deg.hukumet, 'belediye', deg.belediye) end,
    'halk', jsonb_build_object('n', (select count(*) from oyun.uk_degerlendirme where olay_id = o.id),
                               'hukumet', (select round(avg(hukumet), 1) from oyun.uk_degerlendirme where olay_id = o.id),
                               'belediye', (select round(avg(belediye), 1) from oyun.uk_degerlendirme where olay_id = o.id and belediye is not null)),
    'maliyet', round(o.maliyet, 2), 'afad_toplam', o.afad_toplam,
    'karne', o.karne, 'puan_karar', o.puan_karar, 'puan_halk', o.puan_halk,
    'bel_karne', o.bel_karne, 'bel_puan_karar', o.bel_puan_karar, 'bel_puan_halk', o.bel_puan_halk,
    'zaman_cizelgesi', coalesce((select jsonb_agg(jsonb_build_object('tip', k.tip, 'aciklama', k.aciklama, 'kim', oyun.sk_kad(k.user_id), 'zaman', k.zaman) order by k.zaman, k.id)
                                 from oyun.uk_kayit k where k.olay_id = o.id), '[]'::jsonb));
end $$;

create or replace function public.ulusal_kriz() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); o oyun.uk_olay; a oyun.uk_ayar;
begin
  select * into o from oyun.uk_olay where durum = 'aktif';
  select * into a from oyun.uk_ayar where id;
  return jsonb_build_object(
    'aktif', case when o.id is null then null else oyun.uk_olay_json(o, p, t) end,
    'arsiv', coalesce((select jsonb_agg(oyun.uk_olay_json(x, p, t) order by x.id desc)
                       from (select * from oyun.uk_olay where durum = 'bitti' order by id desc limit 10) x), '[]'::jsonb),
    'hazine', (select round(hazine, 2) from oyun.ulke where id = 1),
    'ayar', jsonb_build_object('aktif', a.aktif, 'haftalik_ihtimal', a.haftalik_ihtimal, 'min_aralik_gun', a.min_aralik_gun, 'son_kriz', a.son_kriz),
    'yonetici', coalesce(p.yonetici, false),
    'katalog', case when coalesce(p.yonetici, false) then (select jsonb_agg(jsonb_build_object('kod', kod, 'baslik', baslik, 'kapsam', kapsam, 'iller', il_havuzu) order by kapsam, baslik) from oyun.uk_sablon) end);
end $$;

create or replace function public.ulusal_kriz_karar(p_olay bigint, p_asama text, p_secenek text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); o oyun.uk_olay; s oyun.uk_sablon; sec jsonb; ozet text; baslik text;
begin
  select * into o from oyun.uk_olay where id = p_olay for update;
  if o.id is null or o.durum <> 'aktif' then raise exception 'Süren bir kriz bulunamadı.'; end if;
  select * into s from oyun.uk_sablon where kod = o.sablon_kod;
  baslik := s.baslik || coalesce(' (' || (select ad from oyun.iller where id = o.il_id) || ')', '');
  if p_asama = 'ilk' then
    if o.asama <> 1 or o.a1_karar is not null then raise exception 'İlk müdahale kararı zaten verildi.'; end if;
    if t >= o.a1_son then raise exception 'İlk müdahale süresi doldu.'; end if;
    if p.id is distinct from oyun.yurutme_user() and p.id is distinct from oyun.uk_bakan(s.bakanlik) then
      raise exception 'İlk müdahale kararını yalnız % ya da yürütmenin başı verebilir.', (select ad from oyun.bakanliklar where kod = s.bakanlik) || ' bakanı';
    end if;
    sec := oyun.uk_secenek(s.asama1, p_secenek);
  elsif p_asama = 'kalici' then
    if o.asama <> 2 or o.a2_karar is not null then raise exception 'Kalıcı çözüm aşamasında değiliz.'; end if;
    if t >= o.a2_son then raise exception 'Kalıcı çözüm süresi doldu.'; end if;
    if p.id is distinct from oyun.yurutme_user() then raise exception 'Kalıcı çözüm kararını yalnız yürütmenin başı (cumhurbaşkanı ya da başbakan) verebilir.'; end if;
    sec := oyun.uk_secenek(s.asama2, p_secenek);
  elsif p_asama = 'yerel' then
    if o.il_id is null then raise exception 'Bu kriz yerel değil.'; end if;
    if o.y_karar is not null then raise exception 'Yerel müdahale kararı zaten verildi.'; end if;
    if t >= o.y_son then raise exception 'Yerel müdahale süresi doldu.'; end if;
    if p.id is distinct from oyun.uk_belediye(o.il_id) then raise exception 'Yerel müdahale kararını yalnız % belediye başkanı verebilir.', (select ad from oyun.iller where id = o.il_id); end if;
    sec := oyun.uk_secenek(s.yerel, p_secenek);
  else raise exception 'Geçersiz aşama.'; end if;
  if sec is null then raise exception 'Geçersiz karar seçeneği.'; end if;
  ozet := oyun.uk_uygula(o.id, sec, p_asama, p.id, t);
  if p_asama = 'ilk' then
    update oyun.uk_olay set a1_karar = p_secenek, a1_veren = p.id, a1_at = t, asama = 2, a2_son = t + interval '24 hours' where id = o.id;
    perform oyun.bildir(x, format('Kriz masası: %s için ilk müdahale kararı verildi. Kalıcı çözüm kararı 24 saat içinde yürütmenin başında.', baslik), t)
      from (select oyun.yurutme_user() x) y where x is not null and x <> p.id;
  elsif p_asama = 'kalici' then
    update oyun.uk_olay set a2_karar = p_secenek, a2_veren = p.id, a2_at = t, asama = 3, degerlendirme_son = t + interval '24 hours' where id = o.id;
  else
    update oyun.uk_olay set y_karar = p_secenek, y_veren = p.id, y_at = t where id = o.id;
  end if;
  perform oyun.olay('ulusal_kriz', format('%s · %s: %s', baslik,
     case p_asama when 'ilk' then 'İlk müdahale' when 'kalici' then 'Kalıcı çözüm' else 'Belediyenin yerel müdahalesi' end, ozet), o.il_id, p.parti_id, t);
  return public.ulusal_kriz();
end $$;

create or replace function public.ulusal_kriz_puanla(p_olay bigint, p_hukumet integer, p_belediye integer default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); o oyun.uk_olay; j jsonb;
begin
  select * into o from oyun.uk_olay where id = p_olay;
  if o.id is null or o.durum <> 'aktif' then raise exception 'Bu kriz için değerlendirme kapandı.'; end if;
  j := oyun.uk_olay_json(o, p, t);
  if not coalesce((j ->> 'degerlendirebilir')::boolean, false) then raise exception '%', coalesce(j ->> 'degerlendirme_engel', 'Puan veremezsin.'); end if;
  if p_hukumet not between 1 and 5 then raise exception 'Puan 1 ile 5 arasında olmalı.'; end if;
  if p_belediye is not null and (p_belediye not between 1 and 5 or not coalesce((j ->> 'belediye_puanlayabilir')::boolean, false)) then
    raise exception 'Belediyeyi yalnız o ilde yaşayan oyuncular 1-5 arası puanlayabilir.';
  end if;
  insert into oyun.uk_degerlendirme(olay_id, user_id, hukumet, belediye, zaman) values (o.id, p.id, p_hukumet, p_belediye, t)
  on conflict (olay_id, user_id) do update set hukumet = excluded.hukumet, belediye = coalesce(excluded.belediye, oyun.uk_degerlendirme.belediye), zaman = excluded.zaman;
  return public.ulusal_kriz();
end $$;

create or replace function public.ulusal_kriz_baslat(p_kod text, p_il text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); v_il smallint;
begin
  if not coalesce(p.yonetici, false) then raise exception 'Yalnız yönetici kriz başlatabilir.'; end if;
  if nullif(btrim(coalesce(p_il, '')), '') is not null then
    select id into v_il from oyun.iller where lower(ad) = lower(btrim(p_il));
    if v_il is null then raise exception 'İl bulunamadı.'; end if;
  end if;
  perform oyun.uk_baslat(p_kod, oyun.simdi(), v_il);
  return public.ulusal_kriz();
end $$;

create or replace function public.ulusal_kriz_ayar(p_aktif boolean, p_ihtimal integer, p_min_gun integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not coalesce(p.yonetici, false) then raise exception 'Yalnız yönetici değiştirebilir.'; end if;
  if p_ihtimal not between 0 and 100 or p_min_gun not between 3 and 90 then raise exception 'Olasılık 0-100, aralık 3-90 gün olmalı.'; end if;
  update oyun.uk_ayar set aktif = p_aktif, haftalik_ihtimal = p_ihtimal, min_aralik_gun = p_min_gun where id;
  return public.ulusal_kriz();
end $$;

revoke all on function oyun.uk_mem_ulke(numeric), oyun.uk_mem_il(smallint, numeric), oyun.uk_uygula(bigint, jsonb, text, uuid, timestamptz),
  oyun.uk_baslat(text, timestamptz, smallint), oyun.uk_kidem(uuid, boolean, text, numeric, text, timestamptz), oyun.uk_bitir(bigint, timestamptz),
  oyun.uk_tick(timestamptz) from public, anon, authenticated;
revoke all on function public.ulusal_kriz(), public.ulusal_kriz_karar(bigint, text, text), public.ulusal_kriz_puanla(bigint, integer, integer),
  public.ulusal_kriz_baslat(text, text), public.ulusal_kriz_ayar(boolean, integer, integer) from public, anon;
grant execute on function public.ulusal_kriz(), public.ulusal_kriz_karar(bigint, text, text), public.ulusal_kriz_puanla(bigint, integer, integer),
  public.ulusal_kriz_baslat(text, text), public.ulusal_kriz_ayar(boolean, integer, integer) to authenticated;

-- =====================================================================
-- 3) MECLİS İHTİSAS KOMİSYONLARI
--    Her kanun teklifi görüşme süresi (24 saat) boyunca konusuna göre bir komisyona havale edilir.
--    Komisyon üyeleri kabul/ret oyu verir, komisyon başkanı rapor yazar.
--    Görüşme bitince: ret oyu kabulden fazla ve en az max(2, üye sayısının üçte biri) ise teklif
--    Genel Kurul'a gelmeden reddedilir; aksi hâlde (raporlu ya da raporsuz) oylamaya geçer.
--    Kontenjan: partilerin Meclis'teki sandalyeleriyle orantılı (d'Hondt). Bağımsızlar tek grup sayılır.
-- =====================================================================
create table if not exists oyun.kom_tanim (
  kod      text primary key,
  ad       text not null,
  kisa     text not null,
  sira     smallint not null,
  aciklama text not null
);
insert into oyun.kom_tanim(kod, ad, kisa, sira, aciklama) values
 ('anayasa',   'Anayasa Komisyonu', 'Anayasa', 1, 'Anayasa değişiklikleri, seçim kanunları ve kararname iptalleri.'),
 ('adalet',    'Adalet Komisyonu', 'Adalet', 2, 'Ceza, yargı, hukuk ve temel haklarla ilgili teklifler.'),
 ('plan_butce','Plan ve Bütçe Komisyonu', 'Plan ve Bütçe', 3, 'Bütçe kanunu, vergiler, faiz, borç ve kamu maliyesi.'),
 ('icisleri',  'İçişleri Komisyonu', 'İçişleri', 4, 'Yerel yönetimler, güvenlik, afet ve iç düzen.'),
 ('sanayi',    'Sanayi, Ticaret, Enerji, Tabii Kaynaklar, Bilgi ve Teknoloji Komisyonu', 'Sanayi ve Ticaret', 5, 'Şirketler, ticaret, enerji, tarım, ulaştırma ve teknoloji.'),
 ('saglik',    'Sağlık, Aile, Çalışma ve Sosyal İşler Komisyonu', 'Sağlık ve Çalışma', 6, 'Sağlık, asgari ücret, çalışma hayatı ve sosyal güvenlik.'),
 ('egitim',    'Millî Eğitim, Kültür, Gençlik ve Spor Komisyonu', 'Eğitim ve Kültür', 7, 'Eğitim, üniversiteler, kültür, gençlik ve spor.'),
 ('disisleri', 'Dışişleri Komisyonu', 'Dışişleri', 8, 'Uluslararası anlaşmalar, dış politika ve savunma.')
on conflict (kod) do update set ad = excluded.ad, kisa = excluded.kisa, sira = excluded.sira, aciklama = excluded.aciklama;

create table if not exists oyun.kom_uye (
  kom_kod  text not null references oyun.kom_tanim(kod),
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  makam_id bigint not null,
  katilma  timestamptz not null,
  primary key (kom_kod, user_id)
);
create index if not exists kom_uye_user_idx on oyun.kom_uye(user_id);

create table if not exists oyun.kom_baskan_oy (
  kom_kod text not null references oyun.kom_tanim(kod),
  secmen  uuid not null references oyun.profiller(id) on delete cascade,
  aday    uuid not null references oyun.profiller(id) on delete cascade,
  zaman   timestamptz not null,
  primary key (kom_kod, secmen)
);

create table if not exists oyun.kom_kanun (
  kanun_id    bigint primary key references oyun.kanunlar(id),
  kom_kod     text not null references oyun.kom_tanim(kod),
  havale_at   timestamptz not null,
  havale_eden uuid,
  rapor       text,
  rapor_yazan uuid,
  rapor_at    timestamptz,
  karar       text check (karar in ('kabul','ret','raporsuz')),
  karar_at    timestamptz,
  kabul       int, ret int, cekimser int
);
create index if not exists kom_kanun_kom_idx on oyun.kom_kanun(kom_kod, karar);

create table if not exists oyun.kom_oy (
  kanun_id bigint not null references oyun.kanunlar(id),
  uye      uuid not null references oyun.profiller(id) on delete cascade,
  oy       text not null check (oy in ('kabul','ret','cekimser')),
  gerekce  text,
  zaman    timestamptz not null,
  primary key (kanun_id, uye)
);

alter table oyun.kom_tanim enable row level security;
alter table oyun.kom_uye enable row level security;
alter table oyun.kom_baskan_oy enable row level security;
alter table oyun.kom_kanun enable row level security;
alter table oyun.kom_oy enable row level security;
revoke all on oyun.kom_tanim, oyun.kom_uye, oyun.kom_baskan_oy, oyun.kom_kanun, oyun.kom_oy from public, anon, authenticated;

create or replace function oyun.kom_boyut() returns integer language sql stable set search_path = '' as $$
  select greatest(3, least(25, ceil(oyun.dolu_sandalye() / 5.0)))::int
$$;

-- d'Hondt: parti_id 0 = bağımsız vekiller
create or replace function oyun.kom_kontenjan() returns table(parti_id bigint, mv integer, kontenjan integer)
language sql stable set search_path = '' as $$
  with g as (select coalesce(m.parti_id, 0) pid, count(*)::int n from oyun.makamlar m where m.tur = 'mv' and m.bit is null group by 1),
       b as (select oyun.kom_boyut() boyut),
       q as (select g.pid, g.n, d, g.n::numeric / d bolum from g, b, generate_series(1, b.boyut) d),
       r as (select q.pid, row_number() over (order by q.bolum desc, q.n desc, q.pid) rn from q)
  select g.pid, g.n, (select count(*)::int from r, b where r.pid = g.pid and r.rn <= b.boyut) from g
$$;

-- Komisyonun üyeleri: Meclis görevi süren vekiller; partisinin kontenjanını aşanlar (sonradan katılanlar) yedek sayılır.
create or replace function oyun.kom_uyeler(p_kom text) returns table(user_id uuid, parti_id bigint, katilma timestamptz, gecerli boolean)
language sql stable set search_path = '' as $$
  with u as (select k.user_id, coalesce(m.parti_id, 0) pid, k.katilma,
                    row_number() over (partition by coalesce(m.parti_id, 0) order by k.katilma, k.user_id) rn
             from oyun.kom_uye k join oyun.makamlar m on m.id = k.makam_id and m.bit is null and m.tur = 'mv'
             where k.kom_kod = p_kom)
  select u.user_id, nullif(u.pid, 0), u.katilma, u.rn <= coalesce(kq.kontenjan, 0)
  from u left join oyun.kom_kontenjan() kq on kq.parti_id = u.pid
$$;

create or replace function oyun.kom_gecerli_uye(p_kom text, u uuid) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.kom_uyeler(p_kom) x where x.user_id = u and x.gecerli)
$$;

create or replace function oyun.kom_baskan(p_kom text) returns uuid language sql stable set search_path = '' as $$
  with g as (select * from oyun.kom_uyeler(p_kom) where gecerli)
  select o.aday from oyun.kom_baskan_oy o join g s on s.user_id = o.secmen join g a on a.user_id = o.aday
  where o.kom_kod = p_kom group by o.aday order by count(*) desc, min(a.katilma), o.aday limit 1
$$;

-- Teklifin konusuna göre otomatik havale
create or replace function oyun.kom_sec(p_tur text, p_baslik text, p_veri jsonb) returns text
language sql immutable set search_path = '' as $$
  select case
    when p_tur in ('anayasa','secim','iptal') then 'anayasa'
    when p_tur = 'butce' then 'plan_butce'
    when lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) ~ '(vergi|bütçe|butce|faiz|borç|borc|maliye|hazine|kredi|harç|harc|kdv|gelir|enflasyon|merkez bankas|tahvil|emlak vergisi)' then 'plan_butce'
    when lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) ~ '(sağlık|saglik|hastane|asgari|ücret|ucret|emek|işçi|isci|sendika|emekli|sosyal|aile|çalışma|calisma|istihdam|işsiz)' then 'saglik'
    when lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) ~ '(eğitim|egitim|okul|üniversite|universite|öğrenci|ogrenci|öğretmen|kültür|kultur|spor|gençlik|genclik|sanat)' then 'egitim'
    when lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) ~ '(şirket|sirket|ticaret|sanayi|enerji|elektrik|doğal gaz|tarım|tarim|çiftçi|ulaşım|ulasim|yol|teknoloji|internet|borsa|piyasa|ihracat|ithalat|maden|turizm|esnaf|ruhsat)' then 'sanayi'
    when lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) ~ '(dış|dis politika|anlaşma|anlasma|savunma|asker|nato|avrupa|büyükelç|diplomasi|sınır|sinir)' then 'disisleri'
    when lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) ~ '(belediye|valilik|il |iller|polis|emniyet|güvenlik|guvenlik|afet|deprem|göç|goc|nüfus|nufus|yerel)' then 'icisleri'
    when lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) ~ '(seçim|secim|baraj|parti|anayasa|meclis|cumhurbaşkan)' then 'anayasa'
    else 'adalet' end
$$;

create or replace function oyun.kom_havale_tg() returns trigger language plpgsql set search_path = '' as $$
declare v_kom text := oyun.kom_sec(new.tur, new.baslik, new.veri);
begin
  insert into oyun.kom_kanun(kanun_id, kom_kod, havale_at) values (new.id, v_kom, coalesce(new.teklif_at, now())) on conflict (kanun_id) do nothing;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.user_id, coalesce(new.teklif_at, now()), format('%s: "%s" teklifi komisyonunuza havale edildi. Genel Kurul''a gitmeden önce komisyonda oyunu kullan.',
                                                         (select ad from oyun.kom_tanim where kod = v_kom), new.baslik)
    from oyun.kom_uyeler(v_kom) x where x.gecerli and x.user_id is distinct from new.teklif_eden;
  return new;
end $$;

create or replace function oyun.kom_karar_tg() returns trigger language plpgsql set search_path = '' as $$
declare kk oyun.kom_kanun; a int; r int; c int; uye int; esik int; kad text; t timestamptz := coalesce(new.oy_bas, now());
begin
  if old.durum <> 'gorusmede' or new.durum <> 'oylamada' then return new; end if;
  select * into kk from oyun.kom_kanun where kanun_id = new.id for update;
  if kk.kanun_id is null or kk.karar is not null then return new; end if;
  select count(*) filter (where o.oy = 'kabul'), count(*) filter (where o.oy = 'ret'), count(*) filter (where o.oy = 'cekimser')
    into a, r, c
    from oyun.kom_oy o join oyun.kom_uyeler(kk.kom_kod) x on x.user_id = o.uye and x.gecerli where o.kanun_id = new.id;
  select count(*) into uye from oyun.kom_uyeler(kk.kom_kod) where gecerli;
  esik := greatest(2, ceil(uye / 3.0))::int;
  select ad into kad from oyun.kom_tanim where kod = kk.kom_kod;
  if r > a and r >= esik then
    update oyun.kom_kanun set karar = 'ret', karar_at = t, kabul = a, ret = r, cekimser = c where kanun_id = new.id;
    new.durum := 'ret';
    new.sonuc_at := t;
    new.sonuc_metin := format('%s teklifi reddetti (%s ret, %s kabul, %s çekimser). Teklif Genel Kurul''a gelmedi.', kad, r, a, c);
    perform oyun.bildir(new.teklif_eden, format('"%s" teklifin %s tarafından reddedildi; Genel Kurul''a gelmeyecek.', new.baslik, kad), t);
    perform oyun.olay('meclis', format('%s "%s" teklifini reddetti (%s ret, %s kabul).', kad, new.baslik, r, a), null, new.teklif_parti, t);
  else
    update oyun.kom_kanun set karar = case when a + r + c = 0 then 'raporsuz' else 'kabul' end, karar_at = t, kabul = a, ret = r, cekimser = c
     where kanun_id = new.id;
    if a + r + c > 0 then
      perform oyun.olay('meclis', format('%s "%s" teklifini Genel Kurul''a gönderdi (%s kabul, %s ret).', kad, new.baslik, a, r), null, new.teklif_parti, t);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists kom_havale on oyun.kanunlar;
create trigger kom_havale after insert on oyun.kanunlar for each row execute function oyun.kom_havale_tg();
drop trigger if exists kom_karar on oyun.kanunlar;
create trigger kom_karar before update of durum on oyun.kanunlar for each row execute function oyun.kom_karar_tg();

-- Görüşmesi süren eski teklifleri de komisyonlara havale et (kurulumda bir kez; tekrar çalışınca dokunmaz).
insert into oyun.kom_kanun(kanun_id, kom_kod, havale_at)
select k.id, oyun.kom_sec(k.tur, k.baslik, k.veri), coalesce(k.teklif_at, now()) from oyun.kanunlar k where k.durum = 'gorusmede'
on conflict (kanun_id) do nothing;

create or replace function oyun.kom_grup_yetkili(u uuid, p_parti bigint) returns boolean language sql stable set search_path = '' as $$
  select u is not null and (
    (p_parti is not null and exists (select 1 from oyun.partiler where id = p_parti and (gb = u or gb_vekil = u)))
    or exists (select 1 from oyun.makamlar where user_id = u and tur = 'grup_bskv' and bit is null and parti_id is not distinct from p_parti))
$$;

create or replace function oyun.kom_json(p_kom text, p oyun.profiller) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('kod', k.kod, 'ad', k.ad, 'kisa', k.kisa, 'aciklama', k.aciklama,
    'baskan', oyun.sk_kad(oyun.kom_baskan(k.kod)),
    'uyeler', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', pa.kisa, 'renk', pa.renk, 'gecerli', x.gecerli,
                'baskan', x.user_id = oyun.kom_baskan(k.kod), 'oy', (select count(*) from oyun.kom_baskan_oy b where b.kom_kod = k.kod and b.aday = x.user_id),
                'cikarabilirim', oyun.kom_grup_yetkili(p.id, x.parti_id) and x.user_id <> p.id)
              order by x.gecerli desc, pa.kisa nulls last, x.katilma)
             from oyun.kom_uyeler(k.kod) x join oyun.profiller pr on pr.id = x.user_id left join oyun.partiler pa on pa.id = x.parti_id), '[]'::jsonb),
    'uyeyim', exists (select 1 from oyun.kom_uye u where u.kom_kod = k.kod and u.user_id = p.id),
    'gecerli_uyeyim', oyun.kom_gecerli_uye(k.kod, p.id),
    'baskan_oyum', (select oyun.sk_kad(aday) from oyun.kom_baskan_oy where kom_kod = k.kod and secmen = p.id),
    'gundem', coalesce((select jsonb_agg(jsonb_build_object('id', kn.id, 'baslik', kn.baslik, 'oy_bas', kn.oy_bas,
                 'kabul', (select count(*) from oyun.kom_oy o where o.kanun_id = kn.id and o.oy = 'kabul'),
                 'ret', (select count(*) from oyun.kom_oy o where o.kanun_id = kn.id and o.oy = 'ret'),
                 'oyum', (select oy from oyun.kom_oy o where o.kanun_id = kn.id and o.uye = p.id)) order by kn.oy_bas)
               from oyun.kom_kanun kk join oyun.kanunlar kn on kn.id = kk.kanun_id
               where kk.kom_kod = k.kod and kk.karar is null and kn.durum = 'gorusmede'), '[]'::jsonb),
    'son_kararlar', coalesce((select jsonb_agg(jsonb_build_object('id', kn.id, 'baslik', kn.baslik, 'karar', kk.karar, 'kabul', kk.kabul, 'ret', kk.ret, 'at', kk.karar_at) order by kk.karar_at desc)
               from (select * from oyun.kom_kanun where kom_kod = k.kod and karar is not null order by karar_at desc limit 8) kk
               join oyun.kanunlar kn on kn.id = kk.kanun_id), '[]'::jsonb))
  from oyun.kom_tanim k where k.kod = p_kom
$$;

create or replace function public.komisyonlar() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  return jsonb_build_object(
    'boyut', oyun.kom_boyut(), 'dolu', oyun.dolu_sandalye(),
    'vekilim', oyun.aktif_vekil(p.id),
    'tbmm_baskani', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null),
    'uyeliklerim', (select count(*) from oyun.kom_uye u join oyun.makamlar m on m.id = u.makam_id and m.bit is null where u.user_id = p.id),
    'azami_uyelik', 2,
    'kontenjan', coalesce((select jsonb_agg(jsonb_build_object('parti', coalesce(pa.kisa, 'Bağımsızlar'), 'renk', pa.renk, 'mv', k.mv, 'kontenjan', k.kontenjan) order by k.mv desc)
                           from oyun.kom_kontenjan() k left join oyun.partiler pa on pa.id = nullif(k.parti_id, 0)), '[]'::jsonb),
    'komisyonlar', (select jsonb_agg(oyun.kom_json(kod, p) order by sira) from oyun.kom_tanim));
end $$;

create or replace function public.komisyon_katil(p_kom text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; dolu int; kont int;
begin
  if not exists (select 1 from oyun.kom_tanim where kod = p_kom) then raise exception 'Komisyon bulunamadı.'; end if;
  select * into m from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null order by bas desc limit 1;
  if m.id is null then raise exception 'Komisyonlara yalnızca milletvekilleri katılabilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then raise exception 'Meclis Başkanı komisyonlarda görev almaz.'; end if;
  delete from oyun.kom_uye where user_id = p.id and makam_id <> m.id;   -- önceki dönemin üyelikleri
  if exists (select 1 from oyun.kom_uye where kom_kod = p_kom and user_id = p.id) then raise exception 'Zaten bu komisyonun üyesisin.'; end if;
  if (select count(*) from oyun.kom_uye where user_id = p.id) >= 2 then raise exception 'Bir vekil en fazla 2 komisyonda görev alabilir.'; end if;
  select kontenjan into kont from oyun.kom_kontenjan() where parti_id = coalesce(m.parti_id, 0);
  select count(*) into dolu from oyun.kom_uyeler(p_kom) where coalesce(parti_id, 0) = coalesce(m.parti_id, 0) and gecerli;
  if dolu >= coalesce(kont, 0) then
    raise exception '% bu komisyondaki kontenjanı (% sandalye) dolu. Grup yönetiminden bir üyenin yer açmasını isteyebilirsin.',
      case when m.parti_id is null then 'Bağımsız vekillerin' else 'Partinin' end, coalesce(kont, 0);
  end if;
  insert into oyun.kom_uye(kom_kod, user_id, makam_id, katilma) values (p_kom, p.id, m.id, t);
  return public.komisyonlar();
end $$;

create or replace function public.komisyon_ayril(p_kom text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  delete from oyun.kom_uye where kom_kod = p_kom and user_id = p.id;
  if not found then raise exception 'Bu komisyonun üyesi değilsin.'; end if;
  delete from oyun.kom_baskan_oy where kom_kod = p_kom and (secmen = p.id or aday = p.id);
  return public.komisyonlar();
end $$;

create or replace function public.komisyon_uye_cikar(p_kom text, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); hedef uuid := oyun.sk_profil_bul(p_kad); hp bigint;
begin
  select x.parti_id into hp from oyun.kom_uyeler(p_kom) x where x.user_id = hedef;
  if hedef is null or not exists (select 1 from oyun.kom_uye where kom_kod = p_kom and user_id = hedef) then raise exception 'Bu kişi komisyonun üyesi değil.'; end if;
  if not oyun.kom_grup_yetkili(p.id, hp) then raise exception 'Üyeyi yalnız kendi partisinin genel başkanı ya da grup başkanvekili komisyondan çekebilir.'; end if;
  delete from oyun.kom_uye where kom_kod = p_kom and user_id = hedef;
  delete from oyun.kom_baskan_oy where kom_kod = p_kom and (secmen = hedef or aday = hedef);
  perform oyun.bildir(hedef, format('Grup yönetimi seni %s üyeliğinden çekti.', (select ad from oyun.kom_tanim where kod = p_kom)), oyun.simdi());
  return public.komisyonlar();
end $$;

create or replace function public.komisyon_baskan_oy(p_kom text, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); hedef uuid := oyun.sk_profil_bul(p_kad); onceki uuid; sonra uuid;
begin
  if not oyun.kom_gecerli_uye(p_kom, p.id) then raise exception 'Komisyon başkanını yalnız komisyonun asıl üyeleri seçer.'; end if;
  if hedef is null or not oyun.kom_gecerli_uye(p_kom, hedef) then raise exception 'Aday komisyonun asıl üyesi olmalı.'; end if;
  onceki := oyun.kom_baskan(p_kom);
  insert into oyun.kom_baskan_oy(kom_kod, secmen, aday, zaman) values (p_kom, p.id, hedef, oyun.simdi())
  on conflict (kom_kod, secmen) do update set aday = excluded.aday, zaman = excluded.zaman;
  sonra := oyun.kom_baskan(p_kom);
  if sonra is distinct from onceki and sonra is not null then
    perform oyun.bildir(sonra, format('%s başkanlığına seçildin.', (select ad from oyun.kom_tanim where kod = p_kom)), oyun.simdi());
    perform oyun.olay('meclis', format('%s, %s başkanı oldu.', oyun.sk_kad(sonra), (select ad from oyun.kom_tanim where kod = p_kom)), null,
                      (select parti_id from oyun.profiller where id = sonra), oyun.simdi());
  end if;
  return public.komisyonlar();
end $$;

create or replace function public.komisyon_kanun(p_kanun bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); kk oyun.kom_kanun; k oyun.kanunlar; bsk uuid; acik boolean;
begin
  select * into kk from oyun.kom_kanun where kanun_id = p_kanun;
  if kk.kanun_id is null then return null; end if;
  select * into k from oyun.kanunlar where id = p_kanun;
  bsk := oyun.kom_baskan(kk.kom_kod);
  acik := kk.karar is null and k.durum = 'gorusmede' and t < k.oy_bas;
  return jsonb_build_object('kom_kod', kk.kom_kod, 'kom_ad', (select ad from oyun.kom_tanim where kod = kk.kom_kod),
    'havale_at', kk.havale_at, 'havale_eden', oyun.sk_kad(kk.havale_eden), 'karar', kk.karar, 'karar_at', kk.karar_at,
    'acik', acik, 'bitis', k.oy_bas, 'baskan', oyun.sk_kad(bsk),
    'rapor', kk.rapor, 'rapor_yazan', oyun.sk_kad(kk.rapor_yazan), 'rapor_at', kk.rapor_at,
    'oylar', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', pa.kisa, 'renk', pa.renk, 'oy', o.oy, 'gerekce', o.gerekce) order by o.zaman)
                       from oyun.kom_oy o join oyun.kom_uyeler(kk.kom_kod) x on x.user_id = o.uye and x.gecerli
                       join oyun.profiller pr on pr.id = o.uye left join oyun.partiler pa on pa.id = x.parti_id
                       where o.kanun_id = p_kanun), '[]'::jsonb),
    'uye_sayisi', (select count(*) from oyun.kom_uyeler(kk.kom_kod) where gecerli),
    'esik', greatest(2, ceil((select count(*) from oyun.kom_uyeler(kk.kom_kod) where gecerli) / 3.0)),
    'oy_verebilirim', acik and oyun.kom_gecerli_uye(kk.kom_kod, p.id),
    'oyum', (select oy from oyun.kom_oy where kanun_id = p_kanun and uye = p.id),
    'rapor_yazabilirim', acik and bsk = p.id,
    'havale_edebilirim', acik and t < kk.havale_at + interval '6 hours' and not exists (select 1 from oyun.kom_oy where kanun_id = p_kanun)
                         and exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null),
    'komisyonlar', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad) order by sira) from oyun.kom_tanim));
end $$;

create or replace function public.komisyon_oy(p_kanun bigint, p_oy text, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); kk oyun.kom_kanun; k oyun.kanunlar; g text;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  select * into kk from oyun.kom_kanun where kanun_id = p_kanun;
  select * into k from oyun.kanunlar where id = p_kanun;
  if kk.kanun_id is null or kk.karar is not null or k.durum <> 'gorusmede' or t >= k.oy_bas then raise exception 'Bu teklif komisyonda görüşülmüyor.'; end if;
  if not oyun.kom_gecerli_uye(kk.kom_kod, p.id) then raise exception 'Yalnız % asıl üyeleri oy kullanabilir.', (select ad from oyun.kom_tanim where kod = kk.kom_kod); end if;
  g := case when btrim(coalesce(p_gerekce, '')) = '' then null else oyun.metin_temizle(p_gerekce, 500) end;
  insert into oyun.kom_oy(kanun_id, uye, oy, gerekce, zaman) values (p_kanun, p.id, p_oy, g, t)
  on conflict (kanun_id, uye) do update set oy = excluded.oy, gerekce = coalesce(excluded.gerekce, oyun.kom_oy.gerekce), zaman = excluded.zaman;
  return public.komisyon_kanun(p_kanun);
end $$;

create or replace function public.komisyon_rapor(p_kanun bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); kk oyun.kom_kanun; k oyun.kanunlar; m text;
begin
  select * into kk from oyun.kom_kanun where kanun_id = p_kanun;
  select * into k from oyun.kanunlar where id = p_kanun;
  if kk.kanun_id is null or kk.karar is not null or k.durum <> 'gorusmede' or t >= k.oy_bas then raise exception 'Bu teklif komisyonda görüşülmüyor.'; end if;
  if oyun.kom_baskan(kk.kom_kod) is distinct from p.id then raise exception 'Komisyon raporunu yalnız komisyon başkanı yazar.'; end if;
  m := oyun.metin_temizle(p_metin, 3000);
  if length(m) < 20 then raise exception 'Rapor en az 20 karakter olmalı.'; end if;
  update oyun.kom_kanun set rapor = m, rapor_yazan = p.id, rapor_at = t where kanun_id = p_kanun;
  perform oyun.bildir(k.teklif_eden, format('"%s" teklifin için komisyon raporu yazıldı.', k.baslik), t);
  return public.komisyon_kanun(p_kanun);
end $$;

create or replace function public.komisyon_havale(p_kanun bigint, p_kom text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); j jsonb;
begin
  j := public.komisyon_kanun(p_kanun);
  if j is null or not coalesce((j ->> 'havale_edebilirim')::boolean, false) then
    raise exception 'Havaleyi yalnız Meclis Başkanı, teklifin verilmesinden sonraki 6 saat içinde ve komisyonda oy kullanılmadan değiştirebilir.';
  end if;
  if not exists (select 1 from oyun.kom_tanim where kod = p_kom) then raise exception 'Komisyon bulunamadı.'; end if;
  update oyun.kom_kanun set kom_kod = p_kom, havale_eden = p.id, havale_at = t where kanun_id = p_kanun;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.user_id, t, format('%s: "%s" teklifi Meclis Başkanlığınca komisyonunuza havale edildi.', (select ad from oyun.kom_tanim where kod = p_kom),
                                (select baslik from oyun.kanunlar where id = p_kanun))
    from oyun.kom_uyeler(p_kom) x where x.gecerli;
  return public.komisyon_kanun(p_kanun);
end $$;

revoke all on function oyun.kom_havale_tg(), oyun.kom_karar_tg() from public, anon, authenticated;
revoke all on function public.komisyonlar(), public.komisyon_katil(text), public.komisyon_ayril(text), public.komisyon_uye_cikar(text, text),
  public.komisyon_baskan_oy(text, text), public.komisyon_kanun(bigint), public.komisyon_oy(bigint, text, text), public.komisyon_rapor(bigint, text),
  public.komisyon_havale(bigint, text) from public, anon;
grant execute on function public.komisyonlar(), public.komisyon_katil(text), public.komisyon_ayril(text), public.komisyon_uye_cikar(text, text),
  public.komisyon_baskan_oy(text, text), public.komisyon_kanun(bigint), public.komisyon_oy(bigint, text, text), public.komisyon_rapor(bigint, text),
  public.komisyon_havale(bigint, text) to authenticated;

-- =====================================================================
-- 4) PARTİ KAPATMA DAVASI (Anayasa Mahkemesi)
--    Açabilenler: Adalet Bakanı (doğrudan) ya da bir milletvekili; vekil başvurusu dolu sandalyelerin
--    beşte biri kadar vekilin (en az 2, davalı parti dışından) 48 saatte imzasıyla davaya dönüşür.
--    Davalı partinin genel başkanı 24 saat içinde savunma verir. Sonra Yüksek Mahkeme üyeleri oy verir:
--    kapatma için üyelerin üçte ikisi; kapatma + hazine yardımından yoksunluk oyları salt çoğunluğu bulursa
--    parti 30 gün hazine yardımından yoksun bırakılır; aksi hâlde dava reddedilir.
-- =====================================================================
create table if not exists oyun.pkd_dava (
  id            bigint generated always as identity primary key,
  parti_id      bigint not null references oyun.partiler(id),
  acan          uuid not null references oyun.profiller(id),
  acan_rol      text not null check (acan_rol in ('adalet_bakani','vekiller')),
  gerekce_tur   text not null check (gerekce_tur in ('odak','yabanci','mali','diger')),
  iddia         text not null,
  durum         text not null check (durum in ('imza','savunma','yargilama','kapatma','yardim','ret','dustu')),
  bas           timestamptz not null,
  imza_gerek    integer,
  imza_son      timestamptz,
  savunma_son   timestamptz,
  savunma       text,
  savunan       uuid,
  savunma_at    timestamptz,
  karar_son     timestamptz,
  karar_at      timestamptz,
  karar_gerekce text,
  hakim         uuid,
  oy_kapatma    int, oy_yardim int, oy_ret int, heyet int
);
create unique index if not exists pkd_tek_acik on oyun.pkd_dava(parti_id) where durum in ('imza','savunma','yargilama');

create table if not exists oyun.pkd_imza (
  dava_id bigint not null references oyun.pkd_dava(id),
  vekil   uuid not null references oyun.profiller(id) on delete cascade,
  zaman   timestamptz not null,
  primary key (dava_id, vekil)
);
create table if not exists oyun.pkd_oy (
  dava_id bigint not null references oyun.pkd_dava(id),
  uye     uuid not null references oyun.profiller(id) on delete cascade,
  karar   text not null check (karar in ('kapatma','yardim','ret')),
  gerekce text not null,
  zaman   timestamptz not null,
  primary key (dava_id, uye)
);
create table if not exists oyun.pkd_yardim_yasak (
  parti_id bigint primary key references oyun.partiler(id),
  bas      timestamptz not null,
  bit      timestamptz not null,
  dava_id  bigint references oyun.pkd_dava(id)
);
alter table oyun.pkd_dava enable row level security;
alter table oyun.pkd_imza enable row level security;
alter table oyun.pkd_oy enable row level security;
alter table oyun.pkd_yardim_yasak enable row level security;
revoke all on oyun.pkd_dava, oyun.pkd_imza, oyun.pkd_oy, oyun.pkd_yardim_yasak from public, anon, authenticated;

-- Hazine yardımı: yoksun bırakılan partinin payı ödenmez (diğer partilerin payı değişmez).
create or replace function oyun.parti_yardim_paylari()
returns table(parti_id bigint, oran numeric) language sql stable as $$
  with s as (select id from oyun.secimler where tur = 'mv' and durum <> 'bekliyor' order by oy_bit desc limit 1),
       o as (select o.parti_id, count(*)::numeric n from oyun.oylar o join s on s.id = o.secim_id where o.parti_id is not null group by o.parti_id),
       tp as (select sum(n) toplam from o),
       g as (select o.parti_id, o.n from o, tp where o.n * 100 / tp.toplam >= 3
             and exists (select 1 from oyun.partiler pa where pa.id = o.parti_id and not pa.kapali)),
       pay as (select g.parti_id, g.n / sum(g.n) over () oran from g)
  select pay.parti_id, pay.oran from pay
  where not exists (select 1 from oyun.pkd_yardim_yasak y where y.parti_id = pay.parti_id and y.bit > oyun.simdi())
$$;

create or replace function oyun.pkd_gerekce_ad(p text) returns text language sql immutable set search_path = '' as $$
  select case p when 'odak' then 'Demokratik ve laik cumhuriyet ilkelerine aykırı eylemlerin odağı olmak'
                when 'yabanci' then 'Yabancı devlet ya da kuruluşlardan yardım almak'
                when 'mali' then 'Mali denetimde usulsüzlük ve hesap vermemek'
                else 'Siyasi Partiler Kanunu''na aykırı diğer eylemler' end
$$;

create or replace function oyun.pkd_imza_gerek() returns integer language sql stable set search_path = '' as $$
  select greatest(2, ceil(oyun.dolu_sandalye() / 5.0))::int
$$;

create or replace function oyun.pkd_kapat(p_dava bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare d oyun.pkd_dava; pa oyun.partiler; n int; kasa_tl numeric; uyeler uuid[];
begin
  select * into d from oyun.pkd_dava where id = p_dava;
  select * into pa from oyun.partiler where id = d.parti_id for update;
  if pa.kapali then return; end if;
  select coalesce(array_agg(id), '{}') into uyeler from oyun.profiller where parti_id = pa.id;
  n := cardinality(uyeler);
  -- Üyeler bağımsız kalır; süren milletvekilliği ve belediye başkanlığı gibi makamlar bağımsız olarak sürer.
  update oyun.profiller set parti_id = null where parti_id = pa.id;
  update oyun.makamlar set parti_id = null where parti_id = pa.id and bit is null;
  -- Henüz oy verme başlamamış seçimlerdeki adaylıkları düşer.
  delete from oyun.adaylar a using oyun.secimler s
   where a.secim_id = s.id and a.parti_id = pa.id and s.durum = 'bekliyor' and t < s.oy_bas;
  -- Parti kasası hazineye geçer.
  kasa_tl := coalesce(pa.kasa, 0);
  if kasa_tl > 0 then
    update oyun.ulke set hazine = hazine + kasa_tl / oyun.pazar_tl_milyar() where id = 1;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -kasa_tl, 'Kapatma kararıyla kasa hazineye devredildi', 'kapatma');
  end if;
  update oyun.partiler set kasa = 0, kapali = true, gb = null, gb_vekil = null where id = pa.id;
  delete from oyun.parti_gby where parti_id = pa.id;
  perform oyun.ittifak_temizle();
  -- Genel başkana 30 günlük adaylık yasağı
  if pa.gb is not null then
    update oyun.profiller set adaylik_yasagi_bitis = greatest(coalesce(adaylik_yasagi_bitis, t), t + interval '30 days') where id = pa.gb;
  end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x, t, format('Anayasa Mahkemesi %s partisini kapattı. Artık bağımsızsın; makamın ve paran korunuyor. Dilersen başka bir partiye katılabilirsin.', pa.kisa)
    from unnest(uyeler) x;
end $$;

create or replace function oyun.pkd_oy_say(p_dava bigint, t timestamptz, p_son boolean default false) returns boolean
language plpgsql set search_path = '' as $$
declare d oyun.pkd_dava; heyet uuid[] := oyun.mahkeme_uyeleri(); n int; k int; y int; r int; oy int; sonuc text; v_hakim uuid; v_ger text; pa oyun.partiler;
begin
  select * into d from oyun.pkd_dava where id = p_dava for update;
  if d.durum <> 'yargilama' then return false; end if;
  n := cardinality(heyet);
  if n = 0 then return false; end if;
  select count(*) filter (where karar = 'kapatma'), count(*) filter (where karar = 'yardim'), count(*) filter (where karar = 'ret')
    into k, y, r from oyun.pkd_oy where dava_id = d.id and uye = any(heyet);
  oy := k + y + r;
  if k >= ceil(n * 2 / 3.0) then sonuc := 'kapatma';
  elsif k + y >= oyun.cogunluk(n) and (p_son or k + (n - oy) < ceil(n * 2 / 3.0)) then sonuc := 'yardim';
  elsif r >= oyun.cogunluk(n) or p_son then sonuc := 'ret';
  else return false; end if;
  select uye, gerekce into v_hakim, v_ger from oyun.pkd_oy where dava_id = d.id and karar = sonuc and uye = any(heyet) order by zaman limit 1;
  if v_ger is null and sonuc = 'yardim' then
    select uye, gerekce into v_hakim, v_ger from oyun.pkd_oy where dava_id = d.id and karar = 'kapatma' and uye = any(heyet) order by zaman limit 1;
  end if;
  if v_ger is null then v_ger := 'Kapatma ya da yardımdan yoksunluk için gerekli çoğunluk sağlanamadı.'; end if;
  update oyun.pkd_dava set durum = sonuc, karar_at = t, karar_gerekce = v_ger, hakim = v_hakim, oy_kapatma = k, oy_yardim = y, oy_ret = r, heyet = n where id = d.id;
  select * into pa from oyun.partiler where id = d.parti_id;
  if sonuc = 'kapatma' then
    perform oyun.pkd_kapat(d.id, t);
  elsif sonuc = 'yardim' then
    insert into oyun.pkd_yardim_yasak(parti_id, bas, bit, dava_id) values (d.parti_id, t, t + interval '30 days', d.id)
    on conflict (parti_id) do update set bas = excluded.bas, bit = excluded.bit, dava_id = excluded.dava_id;
    perform oyun.bildir(pa.gb, format('Anayasa Mahkemesi partinizi 30 gün hazine yardımından yoksun bıraktı (%s kapatma, %s yoksunluk, %s ret).', k, y, r), t);
  else
    perform oyun.bildir(pa.gb, format('Anayasa Mahkemesi partinize açılan kapatma davasını reddetti (%s kapatma, %s yoksunluk, %s ret).', k, y, r), t);
  end if;
  perform oyun.bildir(d.acan, format('%s hakkındaki kapatma davası sonuçlandı: %s.', pa.kisa,
          case sonuc when 'kapatma' then 'parti kapatıldı' when 'yardim' then 'parti 30 gün hazine yardımından yoksun bırakıldı' else 'dava reddedildi' end), t);
  perform oyun.adliye_duyur(v_hakim, format('Anayasa Mahkemesi %s hakkındaki kapatma davasında karar verdi: %s (%s kapatma, %s yoksunluk, %s ret oyu). #AnayasaMahkemesi #KapatmaDavası',
          pa.kisa, case sonuc when 'kapatma' then 'PARTİ KAPATILDI' when 'yardim' then '30 gün hazine yardımından yoksunluk' else 'dava reddedildi' end, k, y, r),
          array['anayasamahkemesi','kapatmadavasi'], t);
  return true;
end $$;

create or replace function oyun.pkd_json(d oyun.pkd_dava, p oyun.profiller, t timestamptz) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', d.id, 'parti_id', d.parti_id, 'parti', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'kapali', pa.kapali,
    'acan', oyun.sk_kad(d.acan), 'acan_rol', d.acan_rol, 'gerekce_tur', d.gerekce_tur, 'gerekce_ad', oyun.pkd_gerekce_ad(d.gerekce_tur),
    'iddia', d.iddia, 'durum', d.durum, 'bas', d.bas,
    'imza_gerek', d.imza_gerek, 'imza_son', d.imza_son, 'imza', (select count(*) from oyun.pkd_imza where dava_id = d.id),
    'imzaladim', exists (select 1 from oyun.pkd_imza where dava_id = d.id and vekil = p.id),
    'savunma_son', d.savunma_son, 'savunma', d.savunma, 'savunan', oyun.sk_kad(d.savunan), 'savunma_at', d.savunma_at,
    'karar_son', d.karar_son, 'karar_at', d.karar_at, 'karar_gerekce', d.karar_gerekce, 'hakim', oyun.sk_kad(d.hakim),
    'oy_kapatma', d.oy_kapatma, 'oy_yardim', d.oy_yardim, 'oy_ret', d.oy_ret, 'heyet', coalesce(d.heyet, cardinality(oyun.mahkeme_uyeleri())),
    'verilen_oy', (select count(*) from oyun.pkd_oy where dava_id = d.id),
    'oylar', case when d.durum in ('kapatma','yardim','ret') then coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.sk_kad(o.uye), 'karar', o.karar, 'gerekce', o.gerekce) order by o.zaman)
                    from oyun.pkd_oy o where o.dava_id = d.id), '[]'::jsonb) end,
    'oyum', (select karar from oyun.pkd_oy where dava_id = d.id and uye = p.id),
    'imzalayabilirim', d.durum = 'imza' and t < d.imza_son and oyun.aktif_vekil(p.id) and p.parti_id is distinct from d.parti_id
                       and not exists (select 1 from oyun.pkd_imza where dava_id = d.id and vekil = p.id),
    'savunabilirim', d.durum = 'savunma' and t < d.savunma_son and (pa.gb = p.id or pa.gb_vekil = p.id),
    'oy_verebilirim', d.durum = 'yargilama' and oyun.mahkeme_uyesi_mi(p.id))
  from oyun.partiler pa where pa.id = d.parti_id
$$;

create or replace function public.parti_kapatma_davalari(p_parti bigint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); adalet boolean;
begin
  adalet := exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'bakan' and bakanlik = 'adalet' and bit is null);
  return jsonb_build_object(
    'davalar', coalesce((select jsonb_agg(oyun.pkd_json(d, p, t) order by (d.durum in ('imza','savunma','yargilama')) desc, d.id desc)
                         from (select * from oyun.pkd_dava where p_parti is null or parti_id = p_parti order by id desc limit 30) d), '[]'::jsonb),
    'yardim_yasaklari', coalesce((select jsonb_agg(jsonb_build_object('parti', pa.kisa, 'bit', y.bit)) from oyun.pkd_yardim_yasak y
                         join oyun.partiler pa on pa.id = y.parti_id where y.bit > t and (p_parti is null or y.parti_id = p_parti)), '[]'::jsonb),
    'acabilirim', adalet or oyun.aktif_vekil(p.id),
    'acan_rol', case when adalet then 'adalet_bakani' when oyun.aktif_vekil(p.id) then 'vekiller' end,
    'imza_gerek', oyun.pkd_imza_gerek(),
    'heyet', cardinality(oyun.mahkeme_uyeleri()),
    'partiler', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'kisa', kisa, 'ad', ad) order by ad) from oyun.partiler
                          where not kapali and kurulus_bit is null and id is distinct from p.parti_id), '[]'::jsonb),
    'gerekceler', jsonb_build_array(
        jsonb_build_object('kod', 'odak', 'ad', oyun.pkd_gerekce_ad('odak')), jsonb_build_object('kod', 'yabanci', 'ad', oyun.pkd_gerekce_ad('yabanci')),
        jsonb_build_object('kod', 'mali', 'ad', oyun.pkd_gerekce_ad('mali')), jsonb_build_object('kod', 'diger', 'ad', oyun.pkd_gerekce_ad('diger'))));
end $$;

create or replace function public.parti_kapatma_ac(p_parti bigint, p_gerekce_tur text, p_iddia text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; adalet boolean; m text; yeni bigint; gerek int;
begin
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null or pa.kapali then raise exception 'Parti bulunamadı ya da zaten kapalı.'; end if;
  if pa.kurulus_bit is not null then raise exception 'Kuruluş aşamasındaki partiye kapatma davası açılamaz.'; end if;
  if p.parti_id = pa.id then raise exception 'Kendi partine kapatma davası açamazsın.'; end if;
  if p_gerekce_tur not in ('odak','yabanci','mali','diger') then raise exception 'Geçersiz gerekçe.'; end if;
  if exists (select 1 from oyun.pkd_dava where parti_id = pa.id and durum in ('imza','savunma','yargilama')) then raise exception 'Bu partiye karşı süren bir kapatma davası var.'; end if;
  if exists (select 1 from oyun.pkd_dava where parti_id = pa.id and durum in ('ret','dustu') and coalesce(karar_at, bas) > t - interval '14 days') then
    raise exception 'Bu parti hakkındaki son dava 14 gün içinde sonuçlandı; yeni dava için beklemelisin.';
  end if;
  m := oyun.metin_temizle(p_iddia, 3000);
  if length(m) < 50 then raise exception 'İddianame en az 50 karakter olmalı.'; end if;
  adalet := exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'bakan' and bakanlik = 'adalet' and bit is null);
  if adalet then
    insert into oyun.pkd_dava(parti_id, acan, acan_rol, gerekce_tur, iddia, durum, bas, savunma_son)
    values (pa.id, p.id, 'adalet_bakani', p_gerekce_tur, m, 'savunma', t, t + interval '24 hours') returning id into yeni;
    perform oyun.bildir(coalesce(pa.gb, pa.gb_vekil), format('Adalet Bakanı partinize Anayasa Mahkemesinde kapatma davası açtı. 24 saat içinde savunma vermelisin.'), t);
  elsif oyun.aktif_vekil(p.id) then
    gerek := oyun.pkd_imza_gerek();
    insert into oyun.pkd_dava(parti_id, acan, acan_rol, gerekce_tur, iddia, durum, bas, imza_gerek, imza_son)
    values (pa.id, p.id, 'vekiller', p_gerekce_tur, m, 'imza', t, gerek, t + interval '48 hours') returning id into yeni;
    insert into oyun.pkd_imza(dava_id, vekil, zaman) values (yeni, p.id, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select m2.user_id, t, format('%s, %s hakkında kapatma davası için imza topluyor (%s imza gerekli, 48 saat). Meclis › Kapatma davaları.', p.kad, pa.kisa, gerek)
      from oyun.makamlar m2 left join oyun.profiller pr on pr.id = m2.user_id
      where m2.tur = 'mv' and m2.bit is null and m2.user_id <> p.id and pr.parti_id is distinct from pa.id;
    perform oyun.bildir(coalesce(pa.gb, pa.gb_vekil), format('%s partinize kapatma davası açılması için imza toplamaya başladı.', p.kad), t);
  else
    raise exception 'Kapatma davasını yalnız Adalet Bakanı ya da milletvekilleri başlatabilir.';
  end if;
  perform oyun.adliye_duyur(p.id, format('%s hakkında Anayasa Mahkemesine kapatma davası %s: %s #KapatmaDavası',
          pa.kisa, case when adalet then 'açıldı' else 'için imza toplanıyor' end, left(oyun.pkd_gerekce_ad(p_gerekce_tur), 120)),
          array['kapatmadavasi','anayasamahkemesi'], t);
  return public.parti_kapatma_davalari(null);
end $$;

create or replace function public.parti_kapatma_imza(p_dava bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pkd_dava; n int; pa oyun.partiler;
begin
  select * into d from oyun.pkd_dava where id = p_dava for update;
  if d.id is null or d.durum <> 'imza' or t >= d.imza_son then raise exception 'Bu dava için imza toplanmıyor.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnız milletvekilleri imza verebilir.'; end if;
  if p.parti_id = d.parti_id then raise exception 'Kendi partin hakkındaki davaya imza veremezsin.'; end if;
  insert into oyun.pkd_imza(dava_id, vekil, zaman) values (d.id, p.id, t) on conflict do nothing;
  if not found then raise exception 'Zaten imza verdin.'; end if;
  select count(*) into n from oyun.pkd_imza i join oyun.makamlar m on m.user_id = i.vekil and m.tur = 'mv' and m.bit is null where i.dava_id = d.id;
  if n >= d.imza_gerek then
    select * into pa from oyun.partiler where id = d.parti_id;
    update oyun.pkd_dava set durum = 'savunma', savunma_son = t + interval '24 hours' where id = d.id;
    perform oyun.bildir(coalesce(pa.gb, pa.gb_vekil), format('Partinize karşı kapatma davası %s vekilin imzasıyla Anayasa Mahkemesine taşındı. 24 saat içinde savunma vermelisin.', n), t);
    perform oyun.olay('adliye', format('%s hakkındaki kapatma davası %s imzayla Anayasa Mahkemesine taşındı.', pa.kisa, n), null, pa.id, t);
  end if;
  return public.parti_kapatma_davalari(null);
end $$;

create or replace function oyun.pkd_yargilamaya_al(p_dava bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare d oyun.pkd_dava; pa oyun.partiler;
begin
  select * into d from oyun.pkd_dava where id = p_dava;
  update oyun.pkd_dava set durum = 'yargilama', karar_son = t + make_interval(hours => greatest(24, (select karar_saat from oyun.mahkeme_ayar limit 1))) where id = d.id;
  select * into pa from oyun.partiler where id = d.parti_id;
  perform oyun.bildir(m.user_id, format('Anayasa Mahkemesi: %s hakkındaki kapatma davası oylamanızı bekliyor.', pa.kisa), t)
    from oyun.mahkeme_uye m where m.user_id is not null;
end $$;

create or replace function public.parti_kapatma_savunma(p_dava bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pkd_dava; pa oyun.partiler; m text;
begin
  select * into d from oyun.pkd_dava where id = p_dava for update;
  if d.id is null or d.durum <> 'savunma' or t >= d.savunma_son then raise exception 'Bu dava savunma aşamasında değil.'; end if;
  select * into pa from oyun.partiler where id = d.parti_id;
  if p.id is distinct from pa.gb and p.id is distinct from pa.gb_vekil then raise exception 'Savunmayı yalnız davalı partinin genel başkanı verebilir.'; end if;
  m := oyun.metin_temizle(p_metin, 3000);
  if length(m) < 50 then raise exception 'Savunma en az 50 karakter olmalı.'; end if;
  update oyun.pkd_dava set savunma = m, savunan = p.id, savunma_at = t where id = d.id;
  perform oyun.pkd_yargilamaya_al(d.id, t);
  return public.parti_kapatma_davalari(null);
end $$;

create or replace function public.parti_kapatma_oy(p_dava bigint, p_karar text, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.pkd_dava; g text;
begin
  if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verebilir.'; end if;
  if p_karar not in ('kapatma','yardim','ret') then raise exception 'Geçersiz karar.'; end if;
  select * into d from oyun.pkd_dava where id = p_dava;
  if d.id is null or d.durum <> 'yargilama' then raise exception 'Bu dava oylamada değil.'; end if;
  g := btrim(coalesce(p_gerekce, ''));
  if char_length(g) not between 20 and 2000 then raise exception 'Gerekçeli oy 20–2000 karakter olmalı.'; end if;
  insert into oyun.pkd_oy(dava_id, uye, karar, gerekce, zaman) values (d.id, p.id, p_karar, g, t)
  on conflict (dava_id, uye) do update set karar = excluded.karar, gerekce = excluded.gerekce, zaman = excluded.zaman;
  perform oyun.pkd_oy_say(d.id, t, false);
  return public.parti_kapatma_davalari(null);
end $$;

create or replace function oyun.pkd_tick(t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare r record; n int;
begin
  for r in select * from oyun.pkd_dava where durum = 'imza' and t >= imza_son loop
    select count(*) into n from oyun.pkd_imza where dava_id = r.id;
    update oyun.pkd_dava set durum = 'dustu', karar_at = t, karar_gerekce = format('Yeterli imza toplanamadı (%s/%s).', n, r.imza_gerek) where id = r.id;
    perform oyun.bildir(r.acan, 'Başlattığın kapatma davası yeterli imza toplanamadığı için düştü.', t);
  end loop;
  for r in select * from oyun.pkd_dava where durum = 'savunma' and t >= savunma_son loop
    perform oyun.pkd_yargilamaya_al(r.id, t);
  end loop;
  for r in select * from oyun.pkd_dava where durum = 'yargilama' and t >= karar_son loop
    if cardinality(oyun.mahkeme_uyeleri()) = 0 then
      update oyun.pkd_dava set karar_son = t + interval '24 hours' where id = r.id;   -- mahkeme boşsa süre işlemez
    else
      perform oyun.pkd_oy_say(r.id, t, true);
    end if;
  end loop;
end $$;

-- Güvenlik ağı: kapalı partiden yeni makam başlarsa (ör. oylaması önceden başlamış seçim) bağımsız sayılır.
create or replace function oyun.pkd_makam_tg() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.parti_id is not null and exists (select 1 from oyun.partiler where id = new.parti_id and kapali) then new.parti_id := null; end if;
  return new;
end $$;
drop trigger if exists pkd_makam on oyun.makamlar;
create trigger pkd_makam before insert on oyun.makamlar for each row execute function oyun.pkd_makam_tg();

revoke all on function oyun.pkd_kapat(bigint, timestamptz), oyun.pkd_oy_say(bigint, timestamptz, boolean), oyun.pkd_tick(timestamptz),
  oyun.pkd_yargilamaya_al(bigint, timestamptz), oyun.pkd_makam_tg() from public, anon, authenticated;
revoke all on function public.parti_kapatma_davalari(bigint), public.parti_kapatma_ac(bigint, text, text), public.parti_kapatma_imza(bigint),
  public.parti_kapatma_savunma(bigint, text), public.parti_kapatma_oy(bigint, text, text) from public, anon;
grant execute on function public.parti_kapatma_davalari(bigint), public.parti_kapatma_ac(bigint, text, text), public.parti_kapatma_imza(bigint),
  public.parti_kapatma_savunma(bigint, text), public.parti_kapatma_oy(bigint, text, text) to authenticated;

-- =====================================================================
-- 5) GENÇLİK VE KADIN KOLLARI
--    Her partinin iki kolu vardır. Kol başkanını genel başkan ya da teşkilattan sorumlu GBY atar.
--    Kol başkanı milletvekilliği ve bakanlıkla birlikte yürütülebilir; genel başkanlık, GBY, cumhurbaşkanlığı,
--    belediye başkanlığı ve Meclis Başkanlığı ile birlikte yürütülemez (tek görev kuralı).
--    Kol kasası parti kasasından aktarımla ya da üyelerin bağışıyla dolar; başkan illerde etkinlik düzenler.
-- =====================================================================
create table if not exists oyun.parti_kol (
  parti_id  bigint not null references oyun.partiler(id),
  tur       text not null check (tur in ('genclik','kadin')),
  baskan    uuid references oyun.profiller(id) on delete set null,
  baskan_at timestamptz,
  kasa      numeric not null default 0 check (kasa >= 0),
  son_duyuru timestamptz,
  primary key (parti_id, tur)
);
create table if not exists oyun.parti_kol_uye (
  parti_id bigint not null references oyun.partiler(id),
  tur      text not null check (tur in ('genclik','kadin')),
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  katilma  timestamptz not null,
  primary key (parti_id, tur, user_id)
);
create index if not exists parti_kol_uye_user_idx on oyun.parti_kol_uye(user_id);
create table if not exists oyun.parti_kol_hareket (
  id       bigint generated always as identity primary key,
  parti_id bigint not null references oyun.partiler(id),
  tur      text not null,
  user_id  uuid,
  tutar    numeric not null,
  aciklama text not null,
  zaman    timestamptz not null
);
create index if not exists parti_kol_hareket_idx on oyun.parti_kol_hareket(parti_id, tur, zaman desc);
create table if not exists oyun.kol_etkinlik (
  id         bigint generated always as identity primary key,
  parti_id   bigint not null references oyun.partiler(id),
  tur        text not null check (tur in ('genclik','kadin')),
  il_id      smallint not null references oyun.iller(id),
  tip        text not null check (tip in ('bulusma','egitim','kampanya','dayanisma')),
  baslik     text not null,
  aciklama   text not null,
  bas        timestamptz not null,
  bit        timestamptz not null,
  maliyet    numeric not null,
  olusturan  uuid not null,
  sonuc      text
);
create index if not exists kol_etkinlik_idx on oyun.kol_etkinlik(parti_id, tur, bit desc);
create table if not exists oyun.kol_katilim (
  etkinlik_id bigint not null references oyun.kol_etkinlik(id),
  user_id     uuid not null references oyun.profiller(id) on delete cascade,
  zaman       timestamptz not null,
  uye_miydi   boolean not null,
  primary key (etkinlik_id, user_id)
);
create table if not exists oyun.kol_duyuru (
  id       bigint generated always as identity primary key,
  parti_id bigint not null references oyun.partiler(id),
  tur      text not null,
  yazan    uuid not null,
  baslik   text not null,
  metin    text not null,
  zaman    timestamptz not null
);
alter table oyun.parti_kol enable row level security;
alter table oyun.parti_kol_uye enable row level security;
alter table oyun.parti_kol_hareket enable row level security;
alter table oyun.kol_etkinlik enable row level security;
alter table oyun.kol_katilim enable row level security;
alter table oyun.kol_duyuru enable row level security;
revoke all on oyun.parti_kol, oyun.parti_kol_uye, oyun.parti_kol_hareket, oyun.kol_etkinlik, oyun.kol_katilim, oyun.kol_duyuru from public, anon, authenticated;

create or replace function oyun.kol_ad(p_tur text) returns text language sql immutable set search_path = '' as $$
  select case p_tur when 'genclik' then 'Gençlik Kolları' when 'kadin' then 'Kadın Kolları' end
$$;
create or replace function oyun.kol_tip_ad(p_tip text) returns text language sql immutable set search_path = '' as $$
  select case p_tip when 'bulusma' then 'Buluşma' when 'egitim' then 'Siyaset akademisi' when 'kampanya' then 'Saha kampanyası' when 'dayanisma' then 'Dayanışma etkinliği' end
$$;
create or replace function oyun.kol_tip_ucret(p_tip text) returns numeric language sql immutable set search_path = '' as $$
  select case p_tip when 'bulusma' then 5000 when 'egitim' then 8000 when 'kampanya' then 15000 when 'dayanisma' then 10000 end::numeric
$$;

create or replace function oyun.kol_hazirla(p_parti bigint, p_tur text) returns void language sql set search_path = '' as $$
  insert into oyun.parti_kol(parti_id, tur) values (p_parti, p_tur) on conflict do nothing
$$;

-- Tek görev: kol başkanlığıyla bağdaşmayan roller
create or replace function oyun.kol_rol_engeli(u uuid) returns text language sql stable set search_path = '' as $$
  select oyun.rol_ad(r) from unnest(oyun.roller(u)) r where r in ('gb','gby','cb','cb_yardimcisi','bel','tbmm','bskv') limit 1
$$;

create or replace function oyun.kol_baskan_birak(p_parti bigint, p_tur text, p_neden text, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare b uuid;
begin
  select baskan into b from oyun.parti_kol where parti_id = p_parti and tur = p_tur for update;
  if b is null then return; end if;
  update oyun.parti_kol set baskan = null, baskan_at = null where parti_id = p_parti and tur = p_tur;
  perform oyun.bildir(b, format('%s %s başkanlığın sona erdi: %s', (select kisa from oyun.partiler where id = p_parti), oyun.kol_ad(p_tur), p_neden), t);
end $$;

create or replace function oyun.kol_json(p_parti bigint, p_tur text, p oyun.profiller, t timestamptz) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('tur', p_tur, 'ad', oyun.kol_ad(p_tur),
    'baskan', oyun.sk_kad(k.baskan), 'baskan_at', k.baskan_at,
    'uye_sayisi', (select count(*) from oyun.parti_kol_uye u where u.parti_id = p_parti and u.tur = p_tur),
    'uyeyim', exists (select 1 from oyun.parti_kol_uye u where u.parti_id = p_parti and u.tur = p_tur and u.user_id = p.id),
    'baskanim', k.baskan = p.id,
    'kasa', case when p.parti_id = p_parti then k.kasa end,
    'istatistik', jsonb_build_object(
        'etkinlik', (select count(*) from oyun.kol_etkinlik e where e.parti_id = p_parti and e.tur = p_tur),
        'katilim', (select count(*) from oyun.kol_katilim c join oyun.kol_etkinlik e on e.id = c.etkinlik_id where e.parti_id = p_parti and e.tur = p_tur),
        'kazanilan_uye', (select count(distinct c.user_id) from oyun.kol_katilim c join oyun.kol_etkinlik e on e.id = c.etkinlik_id
                          join oyun.profiller pr on pr.id = c.user_id
                          where e.parti_id = p_parti and e.tur = p_tur and not c.uye_miydi and pr.parti_id = p_parti
                            and pr.parti_at between c.zaman and e.bit + interval '7 days')),
    'etkinlikler', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'il', i.ad, 'il_id', e.il_id, 'tip', e.tip, 'tip_ad', oyun.kol_tip_ad(e.tip),
                    'baslik', e.baslik, 'aciklama', e.aciklama, 'bas', e.bas, 'bit', e.bit, 'aktif', t < e.bit, 'sonuc', e.sonuc,
                    'katilimci', (select count(*) from oyun.kol_katilim c where c.etkinlik_id = e.id),
                    'katildim', exists (select 1 from oyun.kol_katilim c where c.etkinlik_id = e.id and c.user_id = p.id),
                    'katilabilirim', t < e.bit and not exists (select 1 from oyun.kol_katilim c where c.etkinlik_id = e.id and c.user_id = p.id)
                                     and (p.il_id = e.il_id or exists (select 1 from oyun.parti_kol_uye u where u.parti_id = p_parti and u.tur = p_tur and u.user_id = p.id)))
                  order by e.bit desc)
                 from (select * from oyun.kol_etkinlik where parti_id = p_parti and tur = p_tur order by bit desc limit 10) e
                 join oyun.iller i on i.id = e.il_id), '[]'::jsonb),
    'duyurular', case when p.parti_id = p_parti then coalesce((select jsonb_agg(jsonb_build_object('baslik', d.baslik, 'metin', d.metin, 'yazan', oyun.sk_kad(d.yazan), 'zaman', d.zaman) order by d.zaman desc)
                 from (select * from oyun.kol_duyuru where parti_id = p_parti and tur = p_tur order by zaman desc limit 10) d), '[]'::jsonb) end,
    'hareketler', case when k.baskan = p.id or oyun.sk_parti_yetki(p.id, p_parti, 'mali') then coalesce((select jsonb_agg(jsonb_build_object('tutar', h.tutar, 'aciklama', h.aciklama, 'kim', oyun.sk_kad(h.user_id), 'zaman', h.zaman) order by h.zaman desc)
                 from (select * from oyun.parti_kol_hareket where parti_id = p_parti and tur = p_tur order by zaman desc limit 15) h), '[]'::jsonb) end)
  from oyun.parti_kol k where k.parti_id = p_parti and k.tur = p_tur
$$;

create or replace function public.parti_kollari(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if not pa.kapali then perform oyun.kol_hazirla(pa.id, 'genclik'); perform oyun.kol_hazirla(pa.id, 'kadin'); end if;
  return jsonb_build_object('parti_id', pa.id, 'parti', pa.kisa, 'kapali', pa.kapali,
    'uyeyim', p.parti_id = pa.id,
    'atayabilirim', oyun.sk_parti_yetki(p.id, pa.id, 'teskilat'),
    'butce_verebilirim', oyun.sk_parti_yetki(p.id, pa.id, 'mali'),
    'parti_kasa', case when oyun.sk_parti_yetki(p.id, pa.id, 'mali') then pa.kasa end,
    'tipler', (select jsonb_agg(jsonb_build_object('kod', x, 'ad', oyun.kol_tip_ad(x), 'ucret', oyun.kol_tip_ucret(x))) from unnest(array['bulusma','egitim','dayanisma','kampanya']) x),
    'teskilat_illeri', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad) order by i.ad) from oyun.parti_teskilat pt join oyun.iller i on i.id = pt.il_id where pt.parti_id = pa.id), '[]'::jsonb),
    'kollar', jsonb_build_array(oyun.kol_json(pa.id, 'genclik', p, t), oyun.kol_json(pa.id, 'kadin', p, t)));
end $$;

create or replace function public.kol_katil(p_parti bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if p_tur not in ('genclik','kadin') then raise exception 'Geçersiz kol.'; end if;
  if p.parti_id is distinct from p_parti then raise exception 'Kollara yalnız partinin üyeleri katılabilir.'; end if;
  perform oyun.kol_hazirla(p_parti, p_tur);
  insert into oyun.parti_kol_uye(parti_id, tur, user_id, katilma) values (p_parti, p_tur, p.id, t) on conflict do nothing;
  if not found then raise exception 'Zaten bu kolun üyesisin.'; end if;
  return public.parti_kollari(p_parti);
end $$;

create or replace function public.kol_ayril(p_parti bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  delete from oyun.parti_kol_uye where parti_id = p_parti and tur = p_tur and user_id = p.id;
  if not found then raise exception 'Bu kolun üyesi değilsin.'; end if;
  if exists (select 1 from oyun.parti_kol where parti_id = p_parti and tur = p_tur and baskan = p.id) then
    perform oyun.kol_baskan_birak(p_parti, p_tur, 'koldan ayrıldın.', t);
  end if;
  return public.parti_kollari(p_parti);
end $$;

create or replace function public.kol_baskan_ata(p_parti bigint, p_tur text, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); hedef oyun.profiller; engel text; eski uuid;
begin
  if p_tur not in ('genclik','kadin') then raise exception 'Geçersiz kol.'; end if;
  if not oyun.sk_parti_yetki(p.id, p_parti, 'teskilat') then raise exception 'Kol başkanını yalnız genel başkan ya da teşkilattan sorumlu genel başkan yardımcısı atayabilir.'; end if;
  select * into hedef from oyun.profiller where id = oyun.sk_profil_bul(p_kad);
  if hedef.id is null or hedef.parti_id is distinct from p_parti then raise exception 'Kol başkanı partinin üyesi olmalı.'; end if;
  if hedef.yasakli then raise exception 'Bu hesap kapatılmış.'; end if;
  engel := oyun.kol_rol_engeli(hedef.id);
  if engel is not null then raise exception 'Tek görev kuralı: % ile kol başkanlığı birlikte yürütülemez.', engel; end if;
  if exists (select 1 from oyun.parti_kol where baskan = hedef.id and not (parti_id = p_parti and tur = p_tur)) then
    raise exception 'Bu üye zaten diğer kolun başkanı.';
  end if;
  perform oyun.kol_hazirla(p_parti, p_tur);
  select baskan into eski from oyun.parti_kol where parti_id = p_parti and tur = p_tur for update;
  if eski = hedef.id then raise exception 'Bu üye zaten kol başkanı.'; end if;
  if eski is not null then perform oyun.kol_baskan_birak(p_parti, p_tur, format('yerine %s atandı.', hedef.kad), t); end if;
  update oyun.parti_kol set baskan = hedef.id, baskan_at = t where parti_id = p_parti and tur = p_tur;
  insert into oyun.parti_kol_uye(parti_id, tur, user_id, katilma) values (p_parti, p_tur, hedef.id, t) on conflict do nothing;
  perform oyun.bildir(hedef.id, format('%s %s başkanlığına atandın. Kol kasasıyla illerde etkinlik düzenleyebilir, üyelere duyuru yapabilirsin.',
          (select kisa from oyun.partiler where id = p_parti), oyun.kol_ad(p_tur)), t);
  perform oyun.olay('parti', format('%s, %s %s başkanlığına atandı.', hedef.kad, (select kisa from oyun.partiler where id = p_parti), oyun.kol_ad(p_tur)), null, p_parti, t);
  return public.parti_kollari(p_parti);
end $$;

create or replace function public.kol_baskan_gorevden_al(p_parti bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b uuid;
begin
  select baskan into b from oyun.parti_kol where parti_id = p_parti and tur = p_tur;
  if b is null then raise exception 'Kolun başkanı yok.'; end if;
  if b = p.id then perform oyun.kol_baskan_birak(p_parti, p_tur, 'görevden çekildin.', t);
  elsif oyun.sk_parti_yetki(p.id, p_parti, 'teskilat') then perform oyun.kol_baskan_birak(p_parti, p_tur, 'parti yönetimi görevden aldı.', t);
  else raise exception 'Kol başkanını yalnız genel başkan ya da teşkilattan sorumlu GBY görevden alabilir.'; end if;
  return public.parti_kollari(p_parti);
end $$;

create or replace function public.kol_butce_aktar(p_parti bigint, p_tur text, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v numeric := round(coalesce(p_tutar, 0));
begin
  if p_tur not in ('genclik','kadin') then raise exception 'Geçersiz kol.'; end if;
  if not oyun.sk_parti_yetki(p.id, p_parti, 'mali') then raise exception 'Parti kasasından yalnız genel başkan ya da mali işlerden sorumlu GBY aktarım yapabilir.'; end if;
  if v < 1000 or v > 10000000 then raise exception 'Aktarım 1.000 ile 10.000.000 ₺ arasında olmalı.'; end if;
  update oyun.partiler set kasa = kasa - v where id = p_parti and not kapali and kasa >= v;
  if not found then raise exception 'Parti kasasında yeterli para yok.'; end if;
  perform oyun.kol_hazirla(p_parti, p_tur);
  update oyun.parti_kol set kasa = kasa + v where parti_id = p_parti and tur = p_tur;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (p_parti, t, -v, oyun.kol_ad(p_tur) || ' bütçesi', 'kol');
  insert into oyun.parti_kol_hareket(parti_id, tur, user_id, tutar, aciklama, zaman) values (p_parti, p_tur, p.id, v, 'Parti kasasından aktarım', t);
  return public.parti_kollari(p_parti);
end $$;

create or replace function public.kol_bagis(p_parti bigint, p_tur text, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v numeric := round(coalesce(p_tutar, 0));
begin
  if p_tur not in ('genclik','kadin') then raise exception 'Geçersiz kol.'; end if;
  if p.parti_id is distinct from p_parti then raise exception 'Kola yalnız partinin üyeleri bağış yapabilir.'; end if;
  if v < 100 or v > 1000000 then raise exception 'Bağış 100 ile 1.000.000 ₺ arasında olmalı.'; end if;
  perform oyun.para_islem(p.id, -v, 'kol_bagis', format('%s %s bağışı', (select kisa from oyun.partiler where id = p_parti), oyun.kol_ad(p_tur)), t);
  perform oyun.kol_hazirla(p_parti, p_tur);
  update oyun.parti_kol set kasa = kasa + v where parti_id = p_parti and tur = p_tur;
  insert into oyun.parti_kol_hareket(parti_id, tur, user_id, tutar, aciklama, zaman) values (p_parti, p_tur, p.id, v, 'Üye bağışı', t);
  return public.parti_kollari(p_parti);
end $$;

create or replace function public.kol_etkinlik_duzenle(p_parti bigint, p_tur text, p_tip text, p_il integer, p_baslik text, p_aciklama text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.parti_kol; ucret numeric; b text; a text; ilad text;
begin
  select * into k from oyun.parti_kol where parti_id = p_parti and tur = p_tur for update;
  if k.baskan is distinct from p.id then raise exception 'Etkinliği yalnız kol başkanı düzenler.'; end if;
  if p_tip not in ('bulusma','egitim','kampanya','dayanisma') then raise exception 'Geçersiz etkinlik türü.'; end if;
  if not oyun.teskilat_var(p_parti, p_il::smallint) then raise exception 'Etkinlik yalnız partinin il teşkilatı olan illerde düzenlenebilir.'; end if;
  if exists (select 1 from oyun.kol_etkinlik where parti_id = p_parti and tur = p_tur and bit > t) then raise exception 'Kolun süren bir etkinliği var; bitince yenisini düzenleyebilirsin.'; end if;
  b := btrim(coalesce(p_baslik, ''));
  if length(b) not between 5 and 80 then raise exception 'Etkinlik başlığı 5-80 karakter olmalı.'; end if;
  if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
  a := oyun.metin_temizle(p_aciklama, 600);
  if length(a) < 10 then raise exception 'Açıklama en az 10 karakter olmalı.'; end if;
  ucret := oyun.kol_tip_ucret(p_tip);
  if k.kasa < ucret then raise exception 'Kol kasasında yeterli para yok (% ₺ gerekli).', oyun.tl(ucret); end if;
  update oyun.parti_kol set kasa = kasa - ucret where parti_id = p_parti and tur = p_tur;
  insert into oyun.kol_etkinlik(parti_id, tur, il_id, tip, baslik, aciklama, bas, bit, maliyet, olusturan)
  values (p_parti, p_tur, p_il, p_tip, b, a, t, t + interval '24 hours', ucret, p.id);
  insert into oyun.parti_kol_hareket(parti_id, tur, user_id, tutar, aciklama, zaman) values (p_parti, p_tur, p.id, -ucret, oyun.kol_tip_ad(p_tip) || ': ' || b, t);
  select ad into ilad from oyun.iller where id = p_il;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select distinct x.uid, t, format('%s %s, %s''da "%s" düzenliyor (24 saat). Partiler › %s › Kollar.', (select kisa from oyun.partiler where id = p_parti), oyun.kol_ad(p_tur), ilad, b,
                                    (select kisa from oyun.partiler where id = p_parti))
    from (select user_id uid from oyun.parti_kol_uye where parti_id = p_parti and tur = p_tur
          union select id from oyun.profiller where parti_id = p_parti and il_id = p_il) x
    where x.uid <> p.id;
  perform oyun.olay('parti', format('%s %s, %s''da %s düzenliyor: %s', (select kisa from oyun.partiler where id = p_parti), oyun.kol_ad(p_tur), ilad, lower(oyun.kol_tip_ad(p_tip)), b), p_il::smallint, p_parti, t);
  return public.parti_kollari(p_parti);
end $$;

create or replace function public.kol_etkinlik_katil(p_etkinlik bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); e oyun.kol_etkinlik; kol_uyesi boolean;
begin
  select * into e from oyun.kol_etkinlik where id = p_etkinlik;
  if e.id is null or t >= e.bit then raise exception 'Etkinlik sona erdi.'; end if;
  kol_uyesi := exists (select 1 from oyun.parti_kol_uye where parti_id = e.parti_id and tur = e.tur and user_id = p.id);
  if p.il_id is distinct from e.il_id and not kol_uyesi then raise exception 'Etkinliğe yalnız o ilde yaşayanlar ve kol üyeleri katılabilir.'; end if;
  insert into oyun.kol_katilim(etkinlik_id, user_id, zaman, uye_miydi) values (e.id, p.id, t, p.parti_id is not distinct from e.parti_id) on conflict do nothing;
  if not found then raise exception 'Zaten katıldın.'; end if;
  return public.parti_kollari(e.parti_id);
end $$;

create or replace function public.kol_duyuru_yap(p_parti bigint, p_tur text, p_baslik text, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.parti_kol; b text; m text;
begin
  select * into k from oyun.parti_kol where parti_id = p_parti and tur = p_tur for update;
  if k.baskan is distinct from p.id then raise exception 'Kol duyurusunu yalnız kol başkanı yapar.'; end if;
  if k.son_duyuru > t - interval '6 hours' then raise exception 'Kol duyurusu 6 saatte bir yapılabilir.'; end if;
  b := btrim(coalesce(p_baslik, ''));
  if length(b) not between 3 and 80 or oyun.kufurlu(b) then raise exception 'Başlık 3-80 karakter olmalı ve uygunsuz ifade içermemeli.'; end if;
  m := oyun.metin_temizle(p_metin, 1500);
  if length(m) < 10 then raise exception 'Duyuru en az 10 karakter olmalı.'; end if;
  insert into oyun.kol_duyuru(parti_id, tur, yazan, baslik, metin, zaman) values (p_parti, p_tur, p.id, b, m, t);
  update oyun.parti_kol set son_duyuru = t where parti_id = p_parti and tur = p_tur;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select u.user_id, t, format('%s duyurusu: %s', oyun.kol_ad(p_tur), b) from oyun.parti_kol_uye u where u.parti_id = p_parti and u.tur = p_tur and u.user_id <> p.id;
  return public.parti_kollari(p_parti);
end $$;

create or replace function oyun.kol_tick(t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare e record; n int; yeni int; pa oyun.partiler;
begin
  for e in select * from oyun.kol_etkinlik where sonuc is null and bit <= t loop
    select count(*), count(*) filter (where not uye_miydi) into n, yeni from oyun.kol_katilim where etkinlik_id = e.id;
    select * into pa from oyun.partiler where id = e.parti_id;
    update oyun.kol_etkinlik set sonuc = format('%s katılımcı (%s parti dışından)', n, yeni) where id = e.id;
    perform oyun.bildir(e.olusturan, format('"%s" etkinliğin sona erdi: %s katılımcı, %s kişi parti dışından geldi.', e.baslik, n, yeni), t);
    if pa.gb is not null and pa.gb <> e.olusturan then
      perform oyun.bildir(pa.gb, format('%s "%s" etkinliği %s katılımcıyla tamamlandı.', oyun.kol_ad(e.tur), e.baslik, n), t);
    end if;
    insert into oyun.bildirimler(user_id, zaman, metin)
      select c.user_id, t, format('%s %s etkinliğine katıldığın için teşekkürler. Partiyi tanımak için Partiler › %s sayfasına bakabilirsin.', pa.kisa, oyun.kol_ad(e.tur), pa.kisa)
      from oyun.kol_katilim c join oyun.profiller pr on pr.id = c.user_id
      where c.etkinlik_id = e.id and not c.uye_miydi and pr.parti_id is null and not pa.kapali;
  end loop;
end $$;

-- Partiden ayrılan ya da partisi kapanan üye kollardan çıkar; tek görevle çakışan kol başkanlığı kendiliğinden biter.
create or replace function oyun.kol_profil_tg() returns trigger language plpgsql set search_path = '' as $$
declare r record;
begin
  if old.parti_id is not null and new.parti_id is distinct from old.parti_id then
    for r in select parti_id, tur from oyun.parti_kol where parti_id = old.parti_id and baskan = new.id loop
      perform oyun.kol_baskan_birak(r.parti_id, r.tur, 'partiden ayrıldın.', oyun.simdi());
    end loop;
    delete from oyun.parti_kol_uye where user_id = new.id and parti_id = old.parti_id;
  end if;
  return new;
end $$;
drop trigger if exists kol_profil on oyun.profiller;
create trigger kol_profil after update of parti_id on oyun.profiller for each row execute function oyun.kol_profil_tg();

create or replace function oyun.kol_rol_tg() returns trigger language plpgsql set search_path = '' as $$
declare u uuid; r record;
begin
  if tg_table_name = 'makamlar' then
    if new.tur not in ('cb','cb_yardimcisi','bel','tbmm','bskv') or new.bit is not null then return new; end if;
    u := new.user_id;
  elsif tg_table_name = 'parti_gby' then u := new.user_id;
  elsif tg_table_name = 'partiler' then
    if new.gb is not distinct from old.gb then return new; end if;
    u := new.gb;
  end if;
  if u is null then return new; end if;
  for r in select parti_id, tur from oyun.parti_kol where baskan = u loop
    perform oyun.kol_baskan_birak(r.parti_id, r.tur, 'tek görev kuralı gereği yeni görevin nedeniyle.', oyun.simdi());
  end loop;
  return new;
end $$;
drop trigger if exists kol_rol on oyun.makamlar;
create trigger kol_rol after insert on oyun.makamlar for each row execute function oyun.kol_rol_tg();
drop trigger if exists kol_rol on oyun.parti_gby;
create trigger kol_rol after insert or update of user_id on oyun.parti_gby for each row execute function oyun.kol_rol_tg();
drop trigger if exists kol_rol on oyun.partiler;
create trigger kol_rol after update of gb on oyun.partiler for each row execute function oyun.kol_rol_tg();

revoke all on function oyun.kol_hazirla(bigint, text), oyun.kol_baskan_birak(bigint, text, text, timestamptz), oyun.kol_tick(timestamptz),
  oyun.kol_profil_tg(), oyun.kol_rol_tg() from public, anon, authenticated;
revoke all on function public.parti_kollari(bigint), public.kol_katil(bigint, text), public.kol_ayril(bigint, text), public.kol_baskan_ata(bigint, text, text),
  public.kol_baskan_gorevden_al(bigint, text), public.kol_butce_aktar(bigint, text, numeric), public.kol_bagis(bigint, text, numeric),
  public.kol_etkinlik_duzenle(bigint, text, text, integer, text, text), public.kol_etkinlik_katil(bigint), public.kol_duyuru_yap(bigint, text, text, text) from public, anon;
grant execute on function public.parti_kollari(bigint), public.kol_katil(bigint, text), public.kol_ayril(bigint, text), public.kol_baskan_ata(bigint, text, text),
  public.kol_baskan_gorevden_al(bigint, text), public.kol_butce_aktar(bigint, text, numeric), public.kol_bagis(bigint, text, numeric),
  public.kol_etkinlik_duzenle(bigint, text, text, integer, text, text), public.kol_etkinlik_katil(bigint), public.kol_duyuru_yap(bigint, text, text, text) to authenticated;

-- =====================================================================
-- Ortak zamanlayıcı (5 dakikada bir)
-- =====================================================================
create or replace function oyun.siyasi_kurumlar_tick() returns void
language plpgsql set search_path = '' as $$
declare t timestamptz := oyun.simdi();
begin
  if not pg_try_advisory_xact_lock(970014) then return; end if;
  perform oyun.davet_tick(t);
  perform oyun.uk_tick(t);
  perform oyun.pkd_tick(t);
  perform oyun.kol_tick(t);
end $$;
revoke all on function oyun.siyasi_kurumlar_tick() from public, anon, authenticated;

-- =====================================================================
-- KRİTİK DÜZELTME: oyun.meclis_donem_baslat
-- Fonksiyondaki "g" kayıt değişkeni, alt sorgudaki "oyun.secimler g" takma adıyla çakışıyordu;
-- yeni yasama dönemi başlarken "record g is not assigned yet" hatasıyla tüm seçim motoru (tick) duruyordu.
-- Yalnız takma ad değiştirilir; fonksiyonun geri kalanı aynen korunur.
-- =====================================================================
do $duzelt$
declare v_sql text;
begin
  if to_regprocedure('oyun.meclis_donem_baslat(bigint,timestamptz)') is null then return; end if;
  select pg_get_functiondef('oyun.meclis_donem_baslat(bigint,timestamptz)'::regprocedure) into v_sql;
  if position('oyun.secimler g where g.id=p_mv' in v_sql) > 0 then
    v_sql := replace(v_sql, 'oyun.secimler g where g.id=p_mv and g.tur=''mv'' and', 'oyun.secimler s0 where s0.id=p_mv and s0.tur=''mv'' and');
    v_sql := replace(v_sql, '(g.oy_bas at time zone ''Europe/Istanbul'')::date=date ''2026-10-12''', '(s0.oy_bas at time zone ''Europe/Istanbul'')::date=date ''2026-10-12''');
    execute v_sql;
  end if;
end $duzelt$;
