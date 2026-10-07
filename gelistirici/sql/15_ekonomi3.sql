-- =====================================================================
--  15 · PARTİ KURULUŞ ÜCRETİ, İL TEŞKİLATLARI, OYUNCUDAN OYUNCUYA PARA GÖNDERME, BANKA
--
--  Parti kuruluşu: kurucu, kuruluş harcını ve genel merkez binasının bedelini cüzdanından öder
--    (parti_kur_ucret × fiyat düzeyi). Genel merkez, kurucunun ilinde ilk il teşkilatı olarak açılır.
--    Kuruluş süresi içinde yeterli kurucu toplanamazsa ücretin yarısı kurucuya iade edilir.
--  İl teşkilatı: parti bir ilde aday (milletvekili, belediye başkanı) gösterebilmek için o ilde teşkilat
--    (il binası) açmalıdır. Bedeli parti kasasından ödenir: teskilat_ucret × il büyüklüğü (1-3) × fiyat düzeyi.
--    Teşkilatı genel başkan ya da yardımcıları açar. Oyunla gelen 5 parti 81 ilde teşkilatlıdır.
--  Para gönderme (havale): seçmen kartı hazır oyuncu başka bir oyuncuya para gönderebilir.
--    Günlük gönderim sınırı: havale_sinir × aylık asgari ücret. Aynı cihazdaki hesaplar arasında gönderilemez.
--  Banka: vadesiz faizli hesap (faiz saat saat işler, her gece hesaba eklenir), vadeli hesap (7/30 gün,
--    sabit ve daha yüksek faiz; erken bozulursa durduğu süre kadar vadesiz faizi), kredi (7/15/30 gün,
--    günlük eşit taksit). Faizler enflasyona bağlıdır: politika faizi = enflasyon + banka_reel_faiz (yıllık).
--    Taksit ödenmezse: gecikme faizi, kredi notu düşer, banka hesabındaki paraya mahsup edilir;
--    3 gün üst üste ödenmezse yasal takip: maaşın yarısına haciz, vadeli hesaplar bozulur, kıdem −5,
--    "Takipteki borçlu" damgası, borç bitene kadar para gönderme/bağış/yeni kredi yok, kapandıktan sonra 30 gün kara liste.
-- =====================================================================

alter table oyun.ayarlar add column if not exists parti_kur_ucret  numeric not null default 25000;
alter table oyun.ayarlar add column if not exists teskilat_ucret   numeric not null default 2000;
alter table oyun.ayarlar add column if not exists teskilat_zorunlu boolean not null default true;
alter table oyun.ayarlar add column if not exists teskilat_gecis   boolean not null default false;   -- mevcut partilere bir kerelik teşkilat verildi mi
alter table oyun.ayarlar add column if not exists havale_sinir     numeric not null default 1;       -- günlük gönderim: aylık asgari ücretin katı
alter table oyun.ayarlar add column if not exists banka_acik       boolean not null default true;
alter table oyun.ayarlar add column if not exists banka_reel_faiz  numeric not null default 5;       -- politika faizi = enflasyon + bu (yıllık puan)
alter table oyun.ayarlar add column if not exists banka_tavan      numeric not null default 2000000; -- kişi başı en fazla mevduat (× fiyat düzeyi)
alter table oyun.ayarlar add column if not exists banka_son_gun    date;

alter table oyun.partiler add column if not exists kurulus_ucret numeric not null default 0;

-- ---------------------------------------------------------------------
-- İL TEŞKİLATLARI
-- ---------------------------------------------------------------------
create table if not exists oyun.parti_teskilat(
  parti_id     bigint not null references oyun.partiler(id) on delete cascade,
  il_id        smallint not null references oyun.iller(id),
  kurulus      timestamptz not null,
  kuran        uuid,
  bedel        numeric not null default 0,
  genel_merkez boolean not null default false,
  primary key (parti_id, il_id)
);
create index if not exists parti_teskilat_il on oyun.parti_teskilat(il_id);

-- Oyunla gelen partiler 81 ilde teşkilatlıdır
insert into oyun.parti_teskilat(parti_id, il_id, kurulus, genel_merkez)
select pa.id, i.id, pa.kurulus, i.id = 6 from oyun.partiler pa cross join oyun.iller i where pa.sistem
on conflict do nothing;

-- Bir kerelik geçiş: bu güncellemeden önce kurulmuş partiler, üyelerinin, adaylarının ve seçilmişlerinin
-- bulunduğu illerde teşkilatlı sayılır (oyuncuların seçim hakları güncelleme yüzünden düşmesin diye).
do $$
begin
  if not (select teskilat_gecis from oyun.ayarlar where id = 1) then
    insert into oyun.parti_teskilat(parti_id, il_id, kurulus, genel_merkez)
    select distinct on (x.parti_id, x.il_id) x.parti_id, x.il_id, pa.kurulus, coalesce(x.il_id = (select il_id from oyun.profiller where id = pa.kurucu), false)
    from (select parti_id, il_id from oyun.profiller where parti_id is not null
          union select pa2.id, pr.il_id from oyun.partiler pa2 join oyun.profiller pr on pr.id = pa2.kurucu
          union select a.parti_id, a.il_id from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
                 where a.parti_id is not null and a.il_id is not null and s.durum <> 'tamam'
          union select parti_id, il_id from oyun.makamlar where bit is null and parti_id is not null and il_id is not null) x
    join oyun.partiler pa on pa.id = x.parti_id
    where not pa.sistem and not pa.kapali and not exists (select 1 from oyun.parti_teskilat t where t.parti_id = pa.id)
    on conflict do nothing;
    update oyun.ayarlar set teskilat_gecis = true where id = 1;
  end if;
end $$;

-- İl büyüklüğü: 14+ vekil 3 · 8-13 vekil 2 · diğerleri 1 (belediye aday ücretindeki gibi)
create or replace function oyun.il_buyukluk(p_il smallint) returns int language sql stable as $$
  select case when mv >= 14 then 3 when mv >= 8 then 2 else 1 end from oyun.iller where id = p_il
$$;
create or replace function oyun.parti_kur_ucreti() returns numeric language sql stable as $$
  select round(a.parti_kur_ucret * u.endeks) from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;
create or replace function oyun.teskilat_ucreti(p_il smallint) returns numeric language sql stable as $$
  select round(a.teskilat_ucret * oyun.il_buyukluk(p_il) * u.endeks) from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;
create or replace function oyun.teskilat_var(p_parti bigint, p_il smallint) returns boolean language sql stable as $$
  select exists (select 1 from oyun.parti_teskilat where parti_id = p_parti and il_id = p_il)
$$;

-- aday_ol içinden: milletvekili ve belediye aday adaylığı için partinin o ilde teşkilatı olmalı
create or replace function oyun.teskilat_engeli(p oyun.profiller, p_tur text) returns text language sql stable as $$
  select case when p_tur in ('mv_on','bel_on') and (select teskilat_zorunlu from oyun.ayarlar where id = 1)
                   and p.parti_id is not null and not oyun.teskilat_var(p.parti_id, p.il_id)
    then format('Partinin %s il teşkilatı yok. Bu ilde aday gösterebilmesi için genel başkan ya da yardımcılarından biri önce il teşkilatı açmalı (Partiler › parti sayfası › İl teşkilatları).',
                (select ad from oyun.iller where id = p.il_id)) end
$$;

-- parti_kur içinden: kuruluş harcı ve genel merkez binası (cüzdandan). Para yetmezse kuruluş yapılmaz.
create or replace function oyun.parti_kur_harci(p oyun.profiller, p_ad text, t timestamptz) returns numeric language plpgsql as $$
declare ucret numeric := oyun.parti_kur_ucreti();
begin
  if ucret <= 0 then return 0; end if;
  if (select para from oyun.cuzdanim(p.id)) < ucret then
    raise exception 'Parti kurmak için % ₺ gerekiyor: kuruluş harcı ve genel merkez binası (cüzdanında % ₺ var).', oyun.tl(ucret), oyun.tl((select para from oyun.cuzdan where user_id = p.id));
  end if;
  perform oyun.para_islem(p.id, -ucret, 'parti_kur', format('%s kuruluş harcı ve genel merkez binası', p_ad), t);
  return ucret;
end $$;

-- parti_kur içinden: genel merkez, kurucunun ilinde ilk il teşkilatıdır
create or replace function oyun.genel_merkez_ac(p_parti bigint, p oyun.profiller, p_ucret numeric, t timestamptz) returns void language plpgsql as $$
begin
  update oyun.partiler set kurulus_ucret = p_ucret where id = p_parti;
  insert into oyun.parti_teskilat(parti_id, il_id, kurulus, kuran, bedel, genel_merkez) values (p_parti, p.il_id, t, p.id, 0, true)
  on conflict do nothing;
end $$;

-- parti_kurulus_kontrol içinden: kuruluş düşünce ücretin yarısı kurucuya iade edilir (bina satılır, harç yanar)
create or replace function oyun.parti_kurulus_iade(pa oyun.partiler, t timestamptz) returns void language plpgsql as $$
declare iade numeric := floor(coalesce(pa.kurulus_ucret, 0) / 2);
begin
  if iade < 1 or pa.kurucu is null or not exists (select 1 from oyun.profiller where id = pa.kurucu) then return; end if;
  perform oyun.para_islem(pa.kurucu, iade, 'parti_kur_iade', format('%s kurulamadı: genel merkez binası satıldı, ücretin yarısı iade', pa.ad), t);
  perform oyun.bildir(pa.kurucu, format('%s kurulamadığı için genel merkez binası satıldı; kuruluş ücretinin yarısı (%s ₺) cüzdanına iade edildi.', pa.ad, oyun.tl(iade)), t);
  update oyun.partiler set kurulus_ucret = 0 where id = pa.id;
end $$;

create or replace function oyun.teskilat_json(p_parti bigint, p oyun.profiller) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'sayi', (select count(*) from oyun.parti_teskilat where parti_id = p_parti),
    'iller', coalesce((select jsonb_agg(jsonb_build_object('il_id', t.il_id, 'ad', i.ad, 'kurulus', t.kurulus, 'genel_merkez', t.genel_merkez,
                         'uye', (select count(*) from oyun.profiller pr where pr.parti_id = p_parti and pr.il_id = t.il_id)) order by t.genel_merkez desc, i.ad)
                       from oyun.parti_teskilat t join oyun.iller i on i.id = t.il_id where t.parti_id = p_parti), '[]'::jsonb),
    'yetkili', p.parti_id = p_parti and (exists (select 1 from oyun.partiler where id = p_parti and gb = p.id)
                                         or exists (select 1 from oyun.parti_gby where parti_id = p_parti and user_id = p.id)),
    'zorunlu', (select teskilat_zorunlu from oyun.ayarlar where id = 1),
    'ucretler', jsonb_build_object('1', round(a.teskilat_ucret * u.endeks), '2', round(a.teskilat_ucret * 2 * u.endeks), '3', round(a.teskilat_ucret * 3 * u.endeks)),
    'kasa', (select round(kasa) from oyun.partiler where id = p_parti),
    'benim_ilim_var', p.parti_id = p_parti and oyun.teskilat_var(p_parti, p.il_id))
  from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;

create or replace function public.teskilatlar(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not exists (select 1 from oyun.partiler where id = p_parti) then raise exception 'Parti bulunamadı.'; end if;
  return oyun.teskilat_json(p_parti, p);
end $$;

-- Genel başkan ya da yardımcısı bir ilde teşkilat (il binası) açar; bedel parti kasasından
create or replace function public.teskilat_ac(p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; ucret numeric; ilad text;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id and not exists (select 1 from oyun.parti_gby where parti_id = pa.id and user_id = p.id) then
    raise exception 'İl teşkilatını yalnızca genel başkan ve genel başkan yardımcıları açabilir.';
  end if;
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  if oyun.teskilat_var(pa.id, p_il::smallint) then raise exception 'Partinin % ilinde zaten teşkilatı var.', ilad; end if;
  ucret := oyun.teskilat_ucreti(p_il::smallint);
  if pa.kasa < ucret then
    raise exception '% il binası için parti kasasında % ₺ olmalı (kasada % ₺ var). Üyeler bağış yaparak kasayı doldurabilir.', ilad, oyun.tl(ucret), oyun.tl(pa.kasa);
  end if;
  update oyun.partiler set kasa = kasa - ucret where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -ucret, format('%s il teşkilatı açıldı (il binası) · %s', ilad, p.kad), 'teskilat');
  insert into oyun.parti_teskilat(parti_id, il_id, kurulus, kuran, bedel) values (pa.id, p_il, t, p.id, ucret);
  perform oyun.olay('parti', format('%s, %s il teşkilatını açtı.', pa.kisa, ilad), p_il::smallint, pa.id, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select id, t, format('%s artık %s ilinde teşkilatlı: partin bu ilde milletvekili ve belediye başkanı adayı gösterebilir.', pa.kisa, ilad)
    from oyun.profiller where parti_id = pa.id and il_id = p_il and id <> p.id;
  return oyun.teskilat_json(pa.id, p);
end $$;

-- ---------------------------------------------------------------------
-- BANKA: TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.banka_musteri(
  user_id       uuid primary key references oyun.profiller(id) on delete cascade,
  vadesiz       numeric not null default 0 check (vadesiz >= 0),   -- vadesiz hesap bakiyesi (tam ₺)
  faiz_birikmis numeric not null default 0,                         -- işleyen, henüz hesaba eklenmemiş faiz (kuruşlu)
  son_faiz      timestamptz not null,
  faiz_toplam   numeric not null default 0,                         -- bugüne kadar kazanılan vadesiz faizi
  kredi_notu    int not null default 1100 check (kredi_notu between 0 and 1900),
  kara_liste    timestamptz                                          -- bu ana kadar yeni kredi verilmez
);

create table if not exists oyun.vadeli(
  id       bigserial primary key,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  anapara  numeric not null check (anapara > 0),
  oran     numeric not null,                 -- aylık faiz (%), açılışta sabitlenir
  gun      int not null check (gun in (7, 30)),
  acilis   timestamptz not null,
  vade     timestamptz not null,
  durum    text not null default 'acik' check (durum in ('acik','vade','bozuldu','haciz')),
  getiri   numeric,
  kapanis  timestamptz
);
create index if not exists vadeli_acik on oyun.vadeli(vade) where durum = 'acik';
create index if not exists vadeli_user on oyun.vadeli(user_id, acilis desc);

create table if not exists oyun.krediler(
  id          bigserial primary key,
  user_id     uuid not null references oyun.profiller(id) on delete cascade,
  anapara     numeric not null check (anapara > 0),
  oran        numeric not null,              -- aylık faiz (%)
  gun         int not null check (gun in (7, 15, 30)),
  toplam      numeric not null,              -- anapara + faiz
  taksit      numeric not null,              -- günlük taksit
  kalan       numeric not null,              -- kalan borç (gecikmiş kısım dahil)
  gecikmis    numeric not null default 0,    -- vadesi geçmiş, ödenmemiş kısım
  gecikme_gun int not null default 0,        -- üst üste ödenmeyen gün
  hic_gecikmedi boolean not null default true,
  acilis      timestamptz not null,
  son_tahsil  date,
  durum       text not null default 'aktif' check (durum in ('aktif','takip','kapandi')),
  kapanis     timestamptz
);
create unique index if not exists krediler_tek on oyun.krediler(user_id) where durum in ('aktif','takip');
create index if not exists krediler_acik on oyun.krediler(durum) where durum in ('aktif','takip');

create table if not exists oyun.banka_hareket(
  id       bigserial primary key,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  zaman    timestamptz not null,
  hesap    text not null check (hesap in ('vadesiz','vadeli','kredi')),
  tutar    numeric not null,
  aciklama text not null
);
create index if not exists banka_hareket_user on oyun.banka_hareket(user_id, zaman desc);

-- ---------------------------------------------------------------------
-- BANKA: YARDIMCILAR
-- ---------------------------------------------------------------------
-- Faiz oranları (aylık %). Politika faizi (yıllık) = enflasyon + reel faiz, en az %10.
create or replace function oyun.banka_oranlar() returns jsonb language sql stable as $$
  with x as (select greatest(10, round(u.enflasyon + a.banka_reel_faiz, 1)) py from oyun.ulke u, oyun.ayarlar a where u.id = 1 and a.id = 1)
  select jsonb_build_object('politika', py, 'vadesiz', round(py / 12 * 0.5, 2), 'vadeli7', round(py / 12 * 0.8, 2),
                            'vadeli30', round(py / 12 * 0.95, 2), 'kredi', round(py / 12 * 1.6, 2), 'gecikme_gunluk', 1)
  from x
$$;

create or replace function oyun.not_ad(n int) returns text language sql immutable as $$
  select case when n < 700 then 'Çok riskli' when n < 1100 then 'Orta riskli' when n < 1500 then 'Az riskli' when n < 1700 then 'İyi' else 'Çok iyi' end
$$;
-- Kredi notu kredi limitini ve faizini etkiler
create or replace function oyun.not_limit_kat(n int) returns numeric language sql immutable as $$
  select case when n < 700 then 0 when n < 1100 then 0.5 when n < 1500 then 1 when n < 1700 then 1.5 else 2 end
$$;
create or replace function oyun.not_faiz_kat(n int) returns numeric language sql immutable as $$
  select case when n < 1100 then 1.2 when n >= 1500 then 0.9 else 1 end
$$;

create or replace function oyun.musteri(u uuid, t timestamptz) returns oyun.banka_musteri language plpgsql as $$
declare m oyun.banka_musteri;
begin
  insert into oyun.banka_musteri(user_id, son_faiz) values (u, t) on conflict do nothing;
  select * into m from oyun.banka_musteri where user_id = u for update;
  return m;
end $$;

create or replace function oyun.banka_kayit(u uuid, p_hesap text, p_tutar numeric, p_aciklama text, t timestamptz) returns void language sql as $$
  insert into oyun.banka_hareket(user_id, zaman, hesap, tutar, aciklama) values (u, t, p_hesap, round(p_tutar), p_aciklama)
$$;

-- Vadesiz hesabın faizini bu ana kadar işlet (faiz_birikmis'e). Hesaba ekleme her gece yapılır.
create or replace function oyun.vadesiz_isle(u uuid, t timestamptz) returns oyun.banka_musteri language plpgsql as $$
declare m oyun.banka_musteri := oyun.musteri(u, t); gun numeric; f numeric;
begin
  gun := greatest(0, extract(epoch from (t - m.son_faiz)) / 86400);
  f := m.vadesiz * (oyun.banka_oranlar() ->> 'vadesiz')::numeric / 100 / 30 * gun;
  update oyun.banka_musteri set faiz_birikmis = faiz_birikmis + f, son_faiz = greatest(son_faiz, t) where user_id = u returning * into m;
  return m;
end $$;

create or replace function oyun.mevduat_toplam(u uuid) returns numeric language sql stable as $$
  select coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0)
       + coalesce((select sum(anapara) from oyun.vadeli where user_id = u and durum = 'acik'), 0)
$$;
create or replace function oyun.banka_tavani() returns numeric language sql stable as $$
  select round(a.banka_tavan * u.endeks) from oyun.ayarlar a, oyun.ulke u where a.id = 1 and u.id = 1
$$;

create or replace function oyun.aktif_kredi(u uuid) returns oyun.krediler language sql stable as $$
  select * from oyun.krediler where user_id = u and durum in ('aktif','takip') limit 1
$$;
create or replace function oyun.takipte(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.krediler where user_id = u and durum = 'takip')
$$;
create or replace function oyun.gecikmede(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.krediler where user_id = u and (durum = 'takip' or (durum = 'aktif' and gecikmis > 0)))
$$;
-- Gecikmiş borcu olan oyuncu para çıkaramaz (gönderme, bağış, bankadan çekme, vadeli açma)
create or replace function oyun.takip_engel(u uuid, p_islem text) returns void language plpgsql as $$
begin
  if oyun.gecikmede(u) then
    raise exception '%', format('Gecikmiş kredi borcun varken %s. Önce borcunu öde (Hayat › Banka).', p_islem);
  end if;
end $$;
create or replace function oyun.kredi_uyari(u uuid) returns text language sql stable as $$
  select case when k.durum = 'takip' then format('Kredin yasal takipte: %s ₺ borcun var. Maaşının yarısına haciz uygulanıyor; borcunu ödeyene kadar para gönderemez, bağış yapamazsın.', oyun.tl(k.kalan))
              when k.gecikmis > 0 then format('Kredi taksitin %s gündür ödenmedi (%s ₺ gecikmede). 3. günde kredin yasal takibe düşer.', k.gecikme_gun, oyun.tl(k.gecikmis)) end
  from oyun.krediler k where k.user_id = u and k.durum in ('aktif','takip') limit 1
$$;

-- Kredi limiti: aylık asgari ücret × statü katsayısı × (görevdeyse 1,5) × kredi notu katsayısı
create or replace function oyun.kredi_limiti(u uuid) returns numeric language sql stable as $$
  select floor(ul.asgari * (array[0.5, 1, 1.5, 2, 3, 4])[oyun.statu_basamak(oyun.kidem_puani(u)) + 1]
               * case when exists (select 1 from oyun.makamlar where user_id = u and bit is null) then 1.5 else 1 end
               * oyun.not_limit_kat(coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100)) / 100) * 100
  from oyun.ulke ul where ul.id = 1
$$;
create or replace function oyun.kredi_orani(u uuid) returns numeric language sql stable as $$
  select round((oyun.banka_oranlar() ->> 'kredi')::numeric * oyun.not_faiz_kat(coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100)), 2)
$$;

-- Erken kapama: henüz işlememiş günlerin faizi alınmaz
create or replace function oyun.erken_kapama(k oyun.krediler) returns numeric language sql immutable as $$
  select greatest(0, k.kalan - round((k.toplam - k.anapara) / k.gun * floor(greatest(0, k.kalan - k.gecikmis) / k.taksit)))
$$;

-- Borç tahsili: önce cüzdandan, yetmezse vadesiz hesaptan (bankanın mahsup hakkı); takipte vadeli hesaplar da bozulur.
create or replace function oyun.tahsil_et(u uuid, p_tutar numeric, p_takip boolean, p_aciklama text, t timestamptz) returns numeric language plpgsql as $$
declare kalan numeric := round(p_tutar); a numeric; m oyun.banka_musteri; v oyun.vadeli; g numeric; ode numeric; odenen numeric := 0;
begin
  if kalan <= 0 then return 0; end if;
  a := least(kalan, (select para from oyun.cuzdanim(u)));
  if a > 0 then perform oyun.para_islem(u, -a, 'kredi', p_aciklama, t); kalan := kalan - a; odenen := a; end if;
  if kalan > 0 then
    m := oyun.vadesiz_isle(u, t);
    a := least(kalan, floor(m.vadesiz));
    if a > 0 then
      update oyun.banka_musteri set vadesiz = vadesiz - a where user_id = u;
      perform oyun.banka_kayit(u, 'vadesiz', -a, 'Kredi borcuna mahsup edildi', t);
      kalan := kalan - a; odenen := odenen + a;
    end if;
  end if;
  if kalan > 0 and p_takip then
    for v in select * from oyun.vadeli where user_id = u and durum = 'acik' order by acilis for update loop
      g := round(v.anapara * (oyun.banka_oranlar() ->> 'vadesiz')::numeric / 100 / 30 * greatest(0, extract(epoch from (t - v.acilis)) / 86400));
      ode := least(kalan, v.anapara + g);
      update oyun.vadeli set durum = 'haciz', getiri = g, kapanis = t where id = v.id;
      perform oyun.banka_kayit(u, 'vadeli', -(v.anapara + g), format('Vadeli hesap (%s ₺) haciz nedeniyle bozuldu', oyun.tl(v.anapara)), t);
      kalan := kalan - ode; odenen := odenen + ode;
      if v.anapara + g - ode > 0 then
        perform oyun.para_islem(u, v.anapara + g - ode, 'banka', 'Bozulan vadeli hesaptan borç sonrası kalan', t);
      end if;
      exit when kalan <= 0;
    end loop;
  end if;
  return odenen;
end $$;

-- Kredi borcu bitince
create or replace function oyun.kredi_kapat(k oyun.krediler, t timestamptz) returns void language plpgsql as $$
begin
  update oyun.krediler set kalan = 0, gecikmis = 0, gecikme_gun = 0, durum = 'kapandi', kapanis = t where id = k.id;
  if k.durum = 'takip' then
    update oyun.banka_musteri set kara_liste = t + interval '30 days' where user_id = k.user_id;
    perform oyun.bildir(k.user_id, 'Takipteki kredi borcunu kapattın; haciz kalktı. 30 gün boyunca yeni kredi kullanamazsın.', t);
  elsif k.hic_gecikmedi then
    update oyun.banka_musteri set kredi_notu = least(1900, kredi_notu + 60) where user_id = k.user_id;
    perform oyun.bildir(k.user_id, 'Kredini zamanında kapattın. Kredi notun yükseldi.', t);
  else
    perform oyun.bildir(k.user_id, 'Kredi borcunu kapattın.', t);
  end if;
  perform oyun.banka_kayit(k.user_id, 'kredi', 0, 'Kredi kapandı', t);
end $$;

-- Takipte maaş haczi: toplanan maaşın yarısı borca (topla içinden çağrılır)
create or replace function oyun.haciz_uygula(u uuid, p_maas numeric, t timestamptz) returns numeric language plpgsql as $$
declare k oyun.krediler; h numeric;
begin
  select * into k from oyun.krediler where user_id = u and durum = 'takip' for update;
  if k.id is null or p_maas < 2 then return 0; end if;
  h := least(k.kalan, floor(p_maas / 2), (select para from oyun.cuzdan where user_id = u));
  if h <= 0 then return 0; end if;
  perform oyun.para_islem(u, -h, 'haciz', 'Maaş haczi: takipteki kredi borcuna', t);
  update oyun.krediler set kalan = kalan - h, gecikmis = greatest(0, gecikmis - h) where id = k.id returning * into k;
  perform oyun.banka_kayit(u, 'kredi', -h, 'Maaş haczi', t);
  if k.kalan <= 0 then perform oyun.kredi_kapat(k, t); end if;
  return h;
end $$;

-- Vade dolan vadeli hesap: anapara + faiz cüzdana
create or replace function oyun.vadeli_kapat(v oyun.vadeli, t timestamptz) returns void language plpgsql as $$
declare g numeric := round(v.anapara * v.oran / 100 * v.gun / 30);
begin
  update oyun.vadeli set durum = 'vade', getiri = g, kapanis = t where id = v.id and durum = 'acik';
  if not found then return; end if;
  perform oyun.para_islem(v.user_id, v.anapara + g, 'banka', format('Vadeli hesap vadesi doldu: %s ₺ anapara + %s ₺ faiz', oyun.tl(v.anapara), oyun.tl(g)), t);
  perform oyun.banka_kayit(v.user_id, 'vadeli', -(v.anapara + g), format('%s günlük vadeli hesap kapandı (faiz %s ₺)', v.gun, oyun.tl(g)), t);
  perform oyun.bildir(v.user_id, format('%s günlük vadeli hesabının vadesi doldu: %s ₺ anapara ve %s ₺ faiz cüzdanına yattı.', v.gun, oyun.tl(v.anapara), oyun.tl(g)), t);
end $$;

-- Bir günün banka işleri (gece 00:00'da): vadesiz faizleri hesaba eklenir, kredi taksitleri tahsil edilir
create or replace function oyun.banka_gunluk(g date, t timestamptz) returns void language plpgsql as $$
declare r record; m oyun.banka_musteri; x numeric; k oyun.krediler; borc numeric; odenen numeric; acik numeric; ceza numeric; gun_bas timestamptz := oyun.tr_an(g, 0);
begin
  -- vadesiz faiz
  for r in select user_id from oyun.banka_musteri where vadesiz > 0 or faiz_birikmis >= 1 loop
    m := oyun.vadesiz_isle(r.user_id, greatest(t, gun_bas));
    x := floor(m.faiz_birikmis);
    if x >= 1 then
      update oyun.banka_musteri set vadesiz = vadesiz + x, faiz_birikmis = faiz_birikmis - x, faiz_toplam = faiz_toplam + x where user_id = r.user_id;
      perform oyun.banka_kayit(r.user_id, 'vadesiz', x, 'Faiz geliri (' || to_char(g - 1, 'DD.MM') || ')', t);
    end if;
  end loop;
  -- kredi taksitleri (kredi o günden önce açılmış olmalı)
  for r in select id from oyun.krediler where durum in ('aktif','takip') and acilis < gun_bas and son_tahsil is distinct from g order by id loop
    select * into k from oyun.krediler where id = r.id for update;
    borc := least(k.kalan, k.gecikmis + k.taksit);
    odenen := oyun.tahsil_et(k.user_id, borc, k.durum = 'takip', 'Kredi taksiti (' || to_char(g, 'DD.MM') || ')', t);
    acik := borc - odenen;
    if odenen > 0 then perform oyun.banka_kayit(k.user_id, 'kredi', -odenen, 'Taksit tahsil edildi', t); end if;
    if acik > 0 then
      ceza := ceil(acik * 0.01);                       -- gecikme faizi: gecikmiş tutarın günlük %1'i
      update oyun.krediler set kalan = kalan - odenen + ceza, gecikmis = acik + ceza, gecikme_gun = gecikme_gun + 1, hic_gecikmedi = false, son_tahsil = g
        where id = k.id returning * into k;
      update oyun.banka_musteri set kredi_notu = greatest(0, kredi_notu - 40) where user_id = k.user_id;
      perform oyun.banka_kayit(k.user_id, 'kredi', ceza, 'Gecikme faizi', t);
      if k.durum = 'aktif' and k.gecikme_gun >= 3 then
        update oyun.krediler set durum = 'takip' where id = k.id returning * into k;
        update oyun.banka_musteri set kredi_notu = greatest(0, kredi_notu - 250) where user_id = k.user_id;
        perform oyun.kidem_ekle(k.user_id, -5);
        -- takip başlarken vadeli hesaplar bozulup borca sayılır
        odenen := oyun.tahsil_et(k.user_id, k.gecikmis, true, 'Yasal takip: gecikmiş borç', t);
        if odenen > 0 then
          update oyun.krediler set kalan = kalan - odenen, gecikmis = greatest(0, gecikmis - odenen) where id = k.id returning * into k;
          perform oyun.banka_kayit(k.user_id, 'kredi', -odenen, 'Takip: hesaplardan tahsil', t);
        end if;
        perform oyun.bildir(k.user_id, format('Kredin 3 gündür ödenmediği için yasal takibe düştü. Kalan borç: %s ₺. Toplanan maaşının yarısına haciz uygulanacak, kıdemin 5 puan düştü; borç bitene kadar para gönderemez, bağış yapamaz, yeni kredi alamazsın.', oyun.tl(k.kalan)), t);
        perform oyun.olay('banka', format('%s adlı oyuncunun kredisi yasal takibe düştü.', oyun.kad(k.user_id)), null, null, t);
      elsif k.durum = 'aktif' then
        perform oyun.bildir(k.user_id, format('Kredi taksitin ödenemedi: %s ₺ gecikmede (%s. gün). Cüzdanına ya da vadesiz hesabına para koy; 3. günde kredin yasal takibe düşer.', oyun.tl(k.gecikmis), k.gecikme_gun), t);
      else
        perform oyun.bildir(k.user_id, format('Takipteki kredi borcun: %s ₺. Gecikme faizi işliyor.', oyun.tl(k.kalan)), t);
      end if;
    else
      update oyun.krediler set kalan = kalan - odenen, gecikmis = 0, gecikme_gun = 0, son_tahsil = g where id = k.id returning * into k;
    end if;
    if k.kalan <= 0 then perform oyun.kredi_kapat(k, t); end if;
  end loop;
  delete from oyun.banka_hareket where zaman < t - interval '90 days';
end $$;

-- Her dakika (tick içinden): vadesi dolan vadeli hesaplar; gün dönünce banka_gunluk
create or replace function oyun.banka_tick(t timestamptz) returns void language plpgsql as $$
declare bugun date := (t at time zone 'Europe/Istanbul')::date; son date; v oyun.vadeli;
begin
  for v in select * from oyun.vadeli where durum = 'acik' and vade <= t order by vade limit 500 loop
    perform oyun.vadeli_kapat(v, t);
  end loop;
  select banka_son_gun into son from oyun.ayarlar where id = 1 for update;
  if son is null then update oyun.ayarlar set banka_son_gun = bugun where id = 1; return; end if;
  if son >= bugun then return; end if;
  son := greatest(son, bugun - 31);
  while son < bugun loop
    son := son + 1;
    perform oyun.banka_gunluk(son, t);
  end loop;
  update oyun.ayarlar set banka_son_gun = bugun where id = 1;
end $$;

create or replace function oyun.banka_acik_mi() returns void language plpgsql as $$
begin
  if not (select banka_acik from oyun.ayarlar where id = 1) then raise exception 'Banka şu an kapalı. Oyun yönetimi yeniden açınca kullanabilirsin.'; end if;
end $$;

-- ---------------------------------------------------------------------
-- BANKA: UYGULAMA FONKSİYONLARI
-- ---------------------------------------------------------------------
create or replace function oyun.banka_ozet(u uuid) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'vadesiz', coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0),
    'vadeli', coalesce((select sum(anapara) from oyun.vadeli where user_id = u and durum = 'acik'), 0),
    'kredi', (select kalan from oyun.krediler where user_id = u and durum in ('aktif','takip') limit 1),
    'uyari', oyun.kredi_uyari(u))
$$;

create or replace function public.banka() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.banka_musteri; k oyun.krediler; o jsonb := oyun.banka_oranlar();
        c oyun.cuzdan := oyun.cuzdanim(p.id); hb numeric; ul oyun.ulke;
begin
  m := oyun.vadesiz_isle(p.id, t);
  k := oyun.aktif_kredi(p.id);
  select * into ul from oyun.ulke where id = 1;
  hb := coalesce((select sum(-tutar) from oyun.hesap_hareket where user_id = p.id and tur = 'havale' and tutar < 0 and zaman >= oyun.bugun_bas(t)), 0);
  return jsonb_build_object(
    'acik', (select banka_acik from oyun.ayarlar where id = 1),
    'cuzdan', c.para, 'oranlar', o, 'enflasyon', round(ul.enflasyon, 1),
    'vadesiz', jsonb_build_object('bakiye', m.vadesiz, 'birikmis', round(m.faiz_birikmis, 2), 'faiz_toplam', m.faiz_toplam,
                                  'gunluk', round(m.vadesiz * (o ->> 'vadesiz')::numeric / 100 / 30, 2)),
    'vadeliler', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'anapara', v.anapara, 'oran', v.oran, 'gun', v.gun, 'acilis', v.acilis,
                       'vade', v.vade, 'durum', v.durum, 'getiri', coalesce(v.getiri, round(v.anapara * v.oran / 100 * v.gun / 30)),
                       'bozma', round(v.anapara * (o ->> 'vadesiz')::numeric / 100 / 30 * greatest(0, extract(epoch from (t - v.acilis)) / 86400)))
                       order by v.durum <> 'acik', v.acilis desc)
                     from (select * from oyun.vadeli where user_id = p.id and (durum = 'acik' or kapanis > t - interval '14 days') order by acilis desc limit 10) v), '[]'::jsonb),
    'kredi', case when k.id is not null then jsonb_build_object('id', k.id, 'anapara', k.anapara, 'oran', k.oran, 'gun', k.gun, 'toplam', k.toplam,
                  'taksit', k.taksit, 'kalan', k.kalan, 'gecikmis', k.gecikmis, 'gecikme_gun', k.gecikme_gun, 'durum', k.durum, 'acilis', k.acilis,
                  'erken_kapama', oyun.erken_kapama(k), 'kalan_gun', ceil(greatest(0, k.kalan - k.gecikmis) / k.taksit)) end,
    'kredi_notu', m.kredi_notu, 'not_ad', oyun.not_ad(m.kredi_notu),
    'kredi_oran', oyun.kredi_orani(p.id), 'kredi_limit', oyun.kredi_limiti(p.id),
    'kara_liste', case when m.kara_liste > t then m.kara_liste end,
    'kredi_engel', oyun.uyari(p, t),
    'tavan', oyun.banka_tavani(), 'mevduat', oyun.mevduat_toplam(p.id),
    'uyari', oyun.kredi_uyari(p.id),
    'havale', jsonb_build_object('bugun', hb, 'tavan', round(ul.asgari * (select havale_sinir from oyun.ayarlar where id = 1)), 'engel', oyun.uyari(p, t)),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'hesap', h.hesap, 'tutar', h.tutar, 'aciklama', h.aciklama) order by h.zaman desc, h.id desc)
                            from (select * from oyun.banka_hareket where user_id = p.id order by zaman desc, id desc limit 25) h), '[]'::jsonb));
end $$;

create or replace function public.banka_yatir(p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); tav numeric := oyun.banka_tavani();
begin
  perform oyun.banka_acik_mi();
  if m < 100 then raise exception 'En az 100 ₺ yatırabilirsin.'; end if;
  perform oyun.vadesiz_isle(p.id, t);
  if oyun.mevduat_toplam(p.id) + m > tav then
    raise exception 'Bankada en fazla % ₺ tutabilirsin (şu an % ₺ var).', oyun.tl(tav), oyun.tl(oyun.mevduat_toplam(p.id));
  end if;
  perform oyun.para_islem(p.id, -m, 'banka', 'Bankaya yatırıldı (vadesiz hesap)', t);
  update oyun.banka_musteri set vadesiz = vadesiz + m where user_id = p.id;
  perform oyun.banka_kayit(p.id, 'vadesiz', m, 'Cüzdandan yatırıldı', t);
  return public.banka();
end $$;

-- p_miktar boş = tamamını çek
create or replace function public.banka_cek(p_miktar numeric default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); mu oyun.banka_musteri; m numeric;
begin
  if oyun.gecikmede(p.id) then
    raise exception 'Gecikmiş kredi borcun olduğu için bankadaki paran bloke. Borcunu ödeyince çekebilirsin (Banka › Kredi › Borç öde).';
  end if;
  mu := oyun.vadesiz_isle(p.id, t);
  m := coalesce(round(p_miktar), floor(mu.vadesiz));
  if m < 1 then raise exception 'Vadesiz hesabında çekilecek para yok.'; end if;
  if m > mu.vadesiz then raise exception 'Vadesiz hesabında % ₺ var.', oyun.tl(mu.vadesiz); end if;
  update oyun.banka_musteri set vadesiz = vadesiz - m where user_id = p.id;
  perform oyun.banka_kayit(p.id, 'vadesiz', -m, 'Cüzdana çekildi', t);
  perform oyun.para_islem(p.id, m, 'banka', 'Bankadan çekildi (vadesiz hesap)', t);
  return public.banka();
end $$;

create or replace function public.vadeli_ac(p_miktar numeric, p_gun int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); oran numeric; tav numeric := oyun.banka_tavani();
begin
  perform oyun.banka_acik_mi();
  perform oyun.takip_engel(p.id, 'vadeli hesap açamazsın');
  if p_gun not in (7, 30) then raise exception 'Vade 7 ya da 30 gün olabilir.'; end if;
  if m < 1000 then raise exception 'Vadeli hesap en az 1.000 ₺ ile açılır.'; end if;
  if (select count(*) from oyun.vadeli where user_id = p.id and durum = 'acik') >= 3 then raise exception 'Aynı anda en fazla 3 vadeli hesabın olabilir.'; end if;
  perform oyun.musteri(p.id, t);
  if oyun.mevduat_toplam(p.id) + m > tav then
    raise exception 'Bankada en fazla % ₺ tutabilirsin (şu an % ₺ var).', oyun.tl(tav), oyun.tl(oyun.mevduat_toplam(p.id));
  end if;
  oran := (oyun.banka_oranlar() ->> case p_gun when 7 then 'vadeli7' else 'vadeli30' end)::numeric;
  perform oyun.para_islem(p.id, -m, 'banka', format('Vadeli hesap açıldı (%s gün, aylık %%%s)', p_gun, replace(oran::text, '.', ',')), t);
  insert into oyun.vadeli(user_id, anapara, oran, gun, acilis, vade) values (p.id, m, oran, p_gun, t, t + make_interval(days => p_gun));
  perform oyun.banka_kayit(p.id, 'vadeli', m, format('%s günlük vadeli hesap açıldı', p_gun), t);
  return public.banka();
end $$;

-- Vadeden önce bozma: durduğu gün kadar vadesiz faizi işler
create or replace function public.vadeli_boz(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v oyun.vadeli; g numeric;
begin
  select * into v from oyun.vadeli where id = p_id and user_id = p.id for update;
  if v.id is null or v.durum <> 'acik' then raise exception 'Açık bir vadeli hesap bulunamadı.'; end if;
  g := round(v.anapara * (oyun.banka_oranlar() ->> 'vadesiz')::numeric / 100 / 30 * greatest(0, extract(epoch from (t - v.acilis)) / 86400));
  update oyun.vadeli set durum = 'bozuldu', getiri = g, kapanis = t where id = v.id;
  perform oyun.para_islem(p.id, v.anapara + g, 'banka', format('Vadeli hesap bozuldu: %s ₺ anapara + %s ₺ faiz', oyun.tl(v.anapara), oyun.tl(g)), t);
  perform oyun.banka_kayit(p.id, 'vadeli', -(v.anapara + g), 'Vadeli hesap vadeden önce bozuldu', t);
  return public.banka();
end $$;

create or replace function public.kredi_cek(p_miktar numeric, p_gun int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); mu oyun.banka_musteri;
        lim numeric; oran numeric; top numeric; tak numeric;
begin
  perform oyun.banka_acik_mi();
  if oyun.uyari(p, t) is not null then raise exception 'Kredi için seçmen kartın hazır olmalı: %', oyun.uyari(p, t); end if;
  if exists (select 1 from oyun.krediler where user_id = p.id and durum in ('aktif','takip')) then raise exception 'Ödenmemiş bir kredin var. Önce onu kapatmalısın.'; end if;
  mu := oyun.musteri(p.id, t);
  if mu.kara_liste > t then
    raise exception 'Takibe düşen kredin nedeniyle % tarihine kadar yeni kredi alamazsın.', to_char(mu.kara_liste at time zone 'Europe/Istanbul', 'DD.MM.YYYY');
  end if;
  if mu.kredi_notu < 700 then raise exception 'Kredi notun çok düşük (%). Not, kredilerini zamanında ödedikçe yükselir.', mu.kredi_notu; end if;
  if p_gun not in (7, 15, 30) then raise exception 'Vade 7, 15 ya da 30 gün olabilir.'; end if;
  lim := oyun.kredi_limiti(p.id);
  if m < 1000 then raise exception 'En az 1.000 ₺ kredi çekebilirsin.'; end if;
  if m > lim then raise exception 'Kredi limitin % ₺. Statün yükseldikçe ve kredilerini zamanında ödedikçe limitin artar.', oyun.tl(lim); end if;
  oran := oyun.kredi_orani(p.id);
  top := round(m * (1 + oran / 100 * p_gun / 30));
  tak := ceil(top / p_gun);
  insert into oyun.krediler(user_id, anapara, oran, gun, toplam, taksit, kalan, acilis) values (p.id, m, oran, p_gun, top, tak, top, t);
  perform oyun.para_islem(p.id, m, 'kredi', format('Kredi kullanıldı: %s gün vadeli, aylık %%%s faiz', p_gun, replace(oran::text, '.', ',')), t);
  perform oyun.banka_kayit(p.id, 'kredi', top, format('%s ₺ kredi (geri ödeme %s ₺, günlük %s ₺ × %s gün)', oyun.tl(m), oyun.tl(top), oyun.tl(tak), p_gun), t);
  perform oyun.bildir(p.id, format('Kredin hesabına geçti: %s ₺. Yarından itibaren her gece %s ₺ taksit cüzdanından otomatik ödenir (%s gün).', oyun.tl(m), oyun.tl(tak), p_gun), t);
  return public.banka();
end $$;

-- Borç ödeme. p_miktar boş = erken kapama (kalan günlerin faizi alınmaz). Önce cüzdandan, yetmezse vadesiz hesaptan.
create or replace function public.kredi_ode(p_miktar numeric default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.krediler; m numeric; mevcut numeric; kapama boolean := p_miktar is null; odenen numeric;
begin
  select * into k from oyun.krediler where user_id = p.id and durum in ('aktif','takip') for update;
  if k.id is null then raise exception 'Ödenecek kredin yok.'; end if;
  m := case when kapama then oyun.erken_kapama(k) else least(round(p_miktar), k.kalan) end;
  if m < 1 then raise exception 'Geçerli bir tutar gir.'; end if;
  if m >= oyun.erken_kapama(k) then kapama := true; m := oyun.erken_kapama(k); end if;
  mevcut := (select para from oyun.cuzdanim(p.id)) + floor((oyun.vadesiz_isle(p.id, t)).vadesiz);
  if mevcut < m then raise exception 'Bu ödeme için % ₺ gerekiyor; cüzdanında ve vadesiz hesabında toplam % ₺ var.', oyun.tl(m), oyun.tl(mevcut); end if;
  odenen := oyun.tahsil_et(p.id, m, false, case when kapama then 'Kredi erken kapama' else 'Kredi ara ödemesi' end, t);
  perform oyun.banka_kayit(p.id, 'kredi', -odenen, case when kapama then 'Erken kapama' else 'Ara ödeme' end, t);
  if kapama then
    perform oyun.kredi_kapat(k, t);
  else
    update oyun.krediler set kalan = kalan - odenen, gecikmis = greatest(0, gecikmis - odenen),
                             gecikme_gun = case when gecikmis - odenen <= 0 then 0 else gecikme_gun end where id = k.id;
  end if;
  return public.banka();
end $$;

-- ---------------------------------------------------------------------
-- OYUNCUDAN OYUNCUYA PARA GÖNDERME (havale)
-- ---------------------------------------------------------------------
create or replace function public.para_gonder(p_kad text, p_miktar numeric, p_aciklama text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; m numeric := round(coalesce(p_miktar, 0));
        ack text; bugun numeric; tavan numeric;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendine para gönderemezsin.'; end if;
  if h.yasakli then raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ gönderebilirsin.'; end if;
  if oyun.uyari(p, t) is not null then raise exception 'Para göndermek için seçmen kartın hazır olmalı: %', oyun.uyari(p, t); end if;
  if (select coklu_kontrol from oyun.ayarlar where id = 1) and exists (select 1 from oyun.bagli_hesaplar(p.id) b where b = h.id) then
    raise exception 'Aynı cihazda açılmış hesaplar arasında para gönderilemez.';
  end if;
  if oyun.engelli(h.id, p.id) then raise exception 'Bu oyuncu seni engellediği için ona para gönderemezsin.'; end if;
  perform oyun.takip_engel(p.id, 'para gönderemezsin');
  bugun := coalesce((select sum(-tutar) from oyun.hesap_hareket where user_id = p.id and tur = 'havale' and tutar < 0 and zaman >= oyun.bugun_bas(t)), 0);
  tavan := round((select asgari from oyun.ulke where id = 1) * (select havale_sinir from oyun.ayarlar where id = 1));
  if bugun + m > tavan then
    raise exception 'Günlük gönderim sınırı % ₺ (bugün % ₺ gönderdin).', oyun.tl(tavan), oyun.tl(bugun);
  end if;
  if nullif(btrim(coalesce(p_aciklama, '')), '') is not null then ack := oyun.metin_temizle(p_aciklama, 100); end if;
  perform oyun.para_islem(p.id, -m, 'havale', format('%s adlı oyuncuya gönderildi%s', h.kad, coalesce(': ' || ack, '')), t);
  perform oyun.para_islem(h.id, m, 'havale', format('%s gönderdi%s', p.kad, coalesce(': ' || ack, '')), t);
  perform oyun.bildir(h.id, format('%s sana %s ₺ gönderdi.%s', p.kad, oyun.tl(m), coalesce(' Not: “' || ack || '”', '')), t);
  return jsonb_build_object('tamam', true, 'alici', h.kad, 'miktar', m, 'para', (select para from oyun.cuzdan where user_id = p.id),
                            'bugun', bugun + m, 'tavan', tavan);
end $$;
