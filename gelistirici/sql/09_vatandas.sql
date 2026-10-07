-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 9) VATANDAŞ EKONOMİSİ VE VAATLER
--
--  Oyuncunun parası:
--    • Maaş kumbarası: maaş saat saat birikir, en fazla 8 saatlik. Oyuncu girip "Topla" der.
--    • Giriş serisi: üst üste her gün +%5 (en fazla +%30).
--    • Statü: kıdem puanı (oyuna girilen gün + kullanılan oy × 3) → 6 basamak; her basamak kıdem primi kadar maaş artışı.
--    • Reklam izle (günde 5): 2 saatlik maaş. Satın alma: ₺ paketleri (RevenueCat → odeme-webhook).
--  Maaş = asgari ücret × statü × il refahı × destekler (+ makam maaşı). Kesintiler: gelir vergisi (asgari ücret muaf),
--  kent vergisi, geçim masrafı (fiyat düzeyiyle artar; belediye hizmetleri ve bakanlık tedbirleri düşürür).
--  Harcamalar: aday adaylığı ücreti (parti kasasına), taşınma, ek propaganda hakkı, parti bağışı.
--
--  Politikalar: yürütme (cumhurbaşkanı + ilgili bakan) asgari ücret, kıdem primi, sosyal destek, gelir vergisi
--  ve taşınma desteğini ayarlar. Vaatler bu ayarlara bağlıdır; maliyeti ülkenin/ilin/partinin mali alanına sığmalıdır.
-- =====================================================================

alter table oyun.ayarlar add column if not exists baslangic_para numeric not null default 10000;
-- Vatandaş maaşı çarpanı (oyun hızı): asgari ücretin saatlik karşılığı bu kadar katıyla ödenir. Makam maaşları etkilenmez.
alter table oyun.ayarlar add column if not exists maas_hizi numeric not null default 3;

-- Önceki taslak sürümün (enerji/deneyim) kalıntıları
do $$
declare r record;
begin
  if exists (select 1 from information_schema.columns where table_schema = 'oyun' and table_name = 'cuzdan' and column_name = 'enerji') then
    drop table oyun.cuzdan cascade;
  end if;
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where (n.nspname = 'public' and p.proname in ('calis','kurs_al','yemek_ye','vaat_katalog','vaat_yaz'))
              or (n.nspname = 'oyun' and p.proname in ('enerji_max','enerji_hiz','enerji_simdi','cuzdan_gun','yemek_fiyat','kurs_fiyat','yemek_hakki',
                   'calis_enerji','maas_hesap','seviye','seviye_esik','makam_odenek','fiyat_endeksi','taahhut_grubu','taahhut_tutuldu','vaat_karnesi','gunluk_odemeler'))
  loop
    execute 'drop function ' || r.f::text;
  end loop;
end $$;
drop table if exists oyun.vaat_katalog cascade;              -- eski taahhüt kataloğu → vaat_turleri
alter table oyun.adaylar drop column if exists taahhut;      -- eski taahhüt listesi → vaatler tablosu

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.cuzdan(
  user_id     uuid primary key references oyun.profiller(id) on delete cascade,
  para        numeric not null default 0 check (para >= 0),
  son_toplama timestamptz not null,
  seri        int not null default 0,
  seri_gun    date,                 -- son toplama günü (Türkiye saati)
  kidem       numeric not null default 0,   -- oyuna girilen günlerden gelen kıdem puanı
  gun         date,                 -- günlük sayaçların günü
  izle_n      int not null default 0,  -- bugün izlenen ödüllü reklam
  son_izle    timestamptz,
  reklam_n    int not null default 0,  -- bugün satın alınan ek yayın hakkı
  reklam_kul  int not null default 0,
  bagis_bugun numeric not null default 0,
  kumbara_bildirim timestamptz
);

create table if not exists oyun.hesap_hareket(
  id      bigserial primary key,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  zaman   timestamptz not null,
  tutar   numeric not null,
  vergi   numeric not null default 0,
  tur     text not null,
  aciklama text not null
);
create index if not exists hesap_hareket_user on oyun.hesap_hareket(user_id, zaman desc);

alter table oyun.partiler add column if not exists kasa numeric not null default 0;
alter table oyun.partiler add column if not exists aday_ucret jsonb not null default '{"mv_on":1,"bel_on":1,"kurultay":1,"cb_on":1}';
create table if not exists oyun.parti_hareket(
  id       bigserial primary key,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  zaman    timestamptz not null,
  tutar    numeric not null,
  aciklama text not null
);
alter table oyun.parti_hareket add column if not exists tur text not null default 'diger';
create index if not exists parti_hareket_parti on oyun.parti_hareket(parti_id, zaman desc);


create table if not exists oyun.politika_kayit(
  id      bigserial primary key,
  kod     text not null,
  eski    numeric, yeni numeric not null,
  user_id uuid not null,
  makam   text not null,
  zaman   timestamptz not null
);
create index if not exists politika_kayit_kod on oyun.politika_kayit(kod, zaman desc);

create table if not exists oyun.paketler(
  urun_id text primary key, ad text not null, miktar numeric not null, sira int not null
);
insert into oyun.paketler(urun_id, ad, miktar, sira) values
  ('tl_10000', 'Cep harçlığı', 10000, 1),
  ('tl_35000', 'Kampanya kasası', 35000, 2),
  ('tl_100000', 'Seçim fonu', 100000, 3)
on conflict (urun_id) do update set ad = excluded.ad, miktar = excluded.miktar, sira = excluded.sira;

create table if not exists oyun.satin_almalar(
  id        bigserial primary key,
  islem_id  text not null unique,
  user_id   uuid references oyun.profiller(id) on delete set null,
  urun_id   text not null,
  miktar    numeric not null,
  zaman     timestamptz not null default now(),
  iade      boolean not null default false,
  olay      jsonb
);

-- Vaat türleri
create table if not exists oyun.vaat_turleri(
  kapsam text not null check (kapsam in ('beyanname','mv','bel','gb')),
  kod    text not null,
  ad     text not null,
  birim  text not null,           -- tl_ay, tl_gun, tl, yuzde, kat, yok
  tip    text not null check (tip in ('surekli','tek')),
  yon    text,                    -- '>=' / '<=' / null (vergi: hedefe göre belirlenir)
  min    numeric, max numeric,
  sira   int not null,
  aciklama text not null,
  primary key (kapsam, kod)
);
-- katalog: silinmez, güncellenir (verilmiş vaatler bu kodlara bağlıdır)
insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama) values
 ('beyanname','asgari','Asgari ücreti artıracağız','tl_ay','surekli','>=',null,null,1,'Herkesin maaşının tabanı. Ekonominin kaldırabileceğinden hızlı artarsa enflasyon yükselir.'),
 ('beyanname','vergi','Gelir vergisini değiştireceğiz','yuzde','surekli',null,0,45,2,'Asgari ücretin üstündeki kazançtan kesilir. İndirmek hazinenin gelirini azaltır; artırmak yeni vaatlere yer açar.'),
 ('beyanname','kidem','Kıdemlilerin maaşını artıracağız','yuzde','surekli','>=',0,20,3,'Kıdem primi: her statü basamağının maaşa eklediği oran.'),
 ('beyanname','destek','Yeni vatandaşlara günlük sosyal destek','tl_gun','surekli','>=',0,1000,4,'Yeni Gelen ve Vatandaş statüsündekilere her gün ödenir; 8 milyon kişiye gider.'),
 ('beyanname','tasinma','Taşınma masrafını devlet karşılayacak','yuzde','surekli','>=',0,80,5,'İl değiştirirken ödenen masrafın bu kadarını devlet öder.'),
 ('beyanname','ikramiye','Bayram ikramiyesi vereceğiz','tl','tek','>=',500,5000,6,'Görev süresinde en az bir kez kişi başı bu tutarda ikramiye; 16 milyon kişiye gider.'),
 ('beyanname','cal_istihdam','İstihdam paketiyle maaşları artıracağız','yok','tek',null,null,null,7,'Çalışma Bakanlığı icraatı: maaşlar 7 gün %10 artar.'),
 ('beyanname','tar_market','Gıdayı ucuzlatacağız (Tarım Kredi marketleri)','yok','tek',null,null,null,8,'Tarım Bakanlığı icraatı: geçim masrafı %15 düşer.'),
 ('beyanname','sag_ucretsiz','Sağlıkta katkı paylarını kaldıracağız','yok','tek',null,null,null,9,'Sağlık Bakanlığı icraatı: geçim masrafı %10 düşer.'),
 ('beyanname','egt_burs','Gençlere burs ve staj vereceğiz','yok','tek',null,null,null,10,'Eğitim Bakanlığı icraatı: yeni oyuncuların maaşı %20 artar.'),
 ('beyanname','tic_fiyat','Fahiş fiyatla mücadele edeceğiz','yok','tek',null,null,null,11,'Ticaret Bakanlığı icraatı: geçim masrafı %10 düşer.'),
 ('beyanname','ula_toplu','Toplu taşımayı ucuzlatacağız','yok','tek',null,null,null,12,'Ulaştırma Bakanlığı icraatı: geçim %5, taşınma %30 düşer.'),
 ('mv','vergi_tavan','Gelir vergisi tavanını indiren bütçeye oy vereceğim','yuzde','tek','<=',0,45,1,'Bütçe kanunundaki vergi bandının üst sınırı. Hükümet vergiyi bu sınırın üstüne çıkaramaz.'),
 ('mv','belediye_payi','Belediyelerin vergi payını artıracağım','yuzde','tek','>=',2,30,2,'Bütçe kanunuyla. Tüm illerin belediye geliri artar.'),
 ('mv','baraj','Seçim barajını indireceğim','yuzde','tek','<=',0,10,3,'Seçim kanunuyla.'),
 ('mv','parti_yardim','Partilere hazine yardımını azaltacağım','tl_gun','tek','<=',0,200000,4,'Bütçe kanunuyla. Partilere giden günlük toplam yardım.'),
 ('bel','kent_vergisi','Kent vergisini indireceğim','yuzde','surekli','<=',0,5,1,'Hemşehrilerin gelirinden kesilen belediye vergisi.'),
 ('bel','hemsehri','Her hemşehriye günlük destek vereceğim','tl_gun','surekli','>=',0,1000,2,'Her gün ilk toplamada cüzdana yatar.'),
 ('bel','lokanta','Kent lokantası açacağım','yok','surekli',null,null,null,3,'Geçim masrafı %15 düşer.'),
 ('bel','ulasim','Toplu ulaşımı ücretsiz yapacağım','yok','surekli',null,null,null,4,'Geçim %10 düşer, taşınma yarı fiyat.'),
 ('bel','kira','Sosyal konut ve kira yardımı yapacağım','yok','surekli',null,null,null,5,'Geçim masrafı %20 düşer.'),
 ('bel','istihdam','İstihdam ofisiyle maaşları artıracağım','yok','surekli',null,null,null,6,'İldeki maaşlar %10 artar.'),
 ('bel','altyapi','Altyapıyı yenileyeceğim','yok','tek',null,null,null,7,'İlin gelişmişliği kalıcı +4.'),
 ('bel','rayli','Raylı sistem hattı yapacağım','yok','tek',null,null,null,8,'İlin gelişmişliği kalıcı +10.'),
 ('gb','aday_ucret','Aday adaylığı ücretlerini düşüreceğim','kat','surekli','<=',0,3,1,'Parti içi seçimlere başvuru ücretinin çarpanı (en yüksek olanı).'),
 ('gb','kampanya','Adaylara kasadan kampanya desteği vereceğim','tl','tek','>=',1000,1000000,2,'Görev süresince adaylara toplam bu kadar destek.')
on conflict (kapsam, kod) do update set ad = excluded.ad, birim = excluded.birim, tip = excluded.tip, yon = excluded.yon,
  min = excluded.min, max = excluded.max, sira = excluded.sira, aciklama = excluded.aciklama;

create table if not exists oyun.vaatler(
  id         bigserial primary key,
  kapsam     text not null,
  donem      text not null,
  user_id    uuid references oyun.profiller(id) on delete cascade,  -- beyannamede null
  parti_id   bigint references oyun.partiler(id) on delete cascade,
  il_id      smallint,
  kod        text not null,
  hedef      numeric,
  yon        text,
  olusturma  timestamptz not null,
  durum      text not null default 'bekliyor' check (durum in ('bekliyor','aktif','bitti','secilmedi')),
  makam_id   bigint,
  aktif_bas  timestamptz,
  bitis      timestamptz,
  gun_toplam int not null default 0,
  gun_tutuldu int not null default 0,
  tamam      boolean not null default false
);
create index if not exists vaatler_durum on oyun.vaatler(durum);
create index if not exists vaatler_user on oyun.vaatler(user_id, donem);

create table if not exists oyun.parti_beyanname(
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  donem    text not null,
  metin    text,
  zaman    timestamptz not null,
  primary key (parti_id, donem)
);

-- ---------------------------------------------------------------------
-- YARDIMCILAR
-- ---------------------------------------------------------------------
-- 28075 → "28.075"
create or replace function oyun.tl(x numeric) returns text language sql immutable as $$
  select replace(to_char(round(x), 'FM999,999,999,990'), ',', '.')
$$;
create or replace function oyun.birim_yaz(x numeric, b text) returns text language sql immutable as $$
  select case b when 'tl_ay' then oyun.tl(x) || ' ₺/ay' when 'tl_gun' then oyun.tl(x) || ' ₺/gün' when 'tl' then oyun.tl(x) || ' ₺'
                when 'yuzde' then '%' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'kat' then '×' || replace(regexp_replace(trim(to_char(x, 'FM990.00')), '\.?0+$', ''), '.', ',')
                else coalesce(x::text, '') end
$$;

-- Bakanlık icraatlarının ve açık belediye hizmetlerinin bir oyuncuya (ilinde) toplam etkisi
create or replace function oyun.bonus(p_il smallint, p_tur text, t timestamptz) returns numeric language sql stable as $$
  select coalesce((select sum(deger) from oyun.etkiler where tur = p_tur and (il_id is null or il_id = p_il) and bas <= t and bit > t), 0)
       + coalesce((select sum((e ->> 'deger')::numeric) from oyun.il_hizmet h join oyun.belediye_hizmetleri b on b.kod = h.kod,
                          jsonb_array_elements(b.etki) e where h.il_id = p_il and e ->> 'tur' = p_tur), 0)
$$;

-- İlin gelişmişliği maaşları etkiler: gelişim 0 → ×0,8 · 50 → ×1,0 · 100 → ×1,2
create or replace function oyun.il_carpan(p_il smallint) returns numeric language sql stable as $$
  select round(0.8 + coalesce((select gelisim from oyun.il_durum where il_id = p_il), 50) / 250, 3)
$$;

-- Makam maaşları (aylık ₺). Temmuz 2026 gerçek rakamlarıyla aynı oranda; fiyat düzeyiyle artar.
--   Cumhurbaşkanı 354.497 · Bakan 318.009 · Milletvekili 310.332
--   İl belediye başkanı (nüfusa göre): 2 milyon+ 317.800 · 1-2 milyon 267.800 · 250-500 bin 198.900 · daha küçük 171.400
create or replace function oyun.makam_maasi(p_tur text, p_il smallint) returns numeric language sql stable as $$
  select (case p_tur when 'cb' then 354497 when 'bakan' then 318009 when 'mv' then 310332
            when 'tbmm' then 60000 when 'bskv' then 30000 when 'grup_bskv' then 20000   -- vekil ödeneğine ek görev tazminatı
            when 'bel' then (select case when mv >= 14 then 317800 when mv >= 8 then 267800 when mv >= 4 then 198900 else 171400 end
                             from oyun.iller where id = p_il)
            else 0 end) * (select endeks from oyun.ulke where id = 1)
$$;

-- Süreli etki ekle. Aynı kaynaktan aynı yerde süren etki varsa süresini uzatır.
create or replace function oyun.etki_ekle(p_il smallint, p_kaynak_tur text, p_kaynak_kod text, p_kaynak_ad text,
                                          p_oyuncu jsonb, p_sure_gun int, u uuid, t timestamptz) returns timestamptz language plpgsql as $$
declare e jsonb; son timestamptz; bit_ timestamptz;
begin
  if p_oyuncu is null or jsonb_array_length(p_oyuncu) = 0 or p_sure_gun is null then return null; end if;
  select max(bit) into son from oyun.etkiler where kaynak_kod = p_kaynak_kod and il_id is not distinct from p_il and bit > t;
  bit_ := coalesce(son, t) + make_interval(days => p_sure_gun);
  if son is not null then
    update oyun.etkiler set bit = bit_ where kaynak_kod = p_kaynak_kod and il_id is not distinct from p_il and bit > t;
  else
    for e in select * from jsonb_array_elements(p_oyuncu) loop
      insert into oyun.etkiler(il_id, tur, deger, bas, bit, kaynak_tur, kaynak_kod, kaynak_ad, user_id)
      values (p_il, e ->> 'tur', (e ->> 'deger')::numeric, t, bit_, p_kaynak_tur, p_kaynak_kod, p_kaynak_ad, u);
    end loop;
  end if;
  return bit_;
end $$;

-- Statü
create or replace function oyun.statu_esik(i int) returns int language sql immutable as $$
  select (array[0, 10, 30, 75, 150, 300])[i + 1]
$$;
create or replace function oyun.statu_ad(i int) returns text language sql immutable as $$
  select (array['Yeni Gelen','Vatandaş','Saygın Vatandaş','Kanaat Önderi','Duayen','Yaşayan Efsane'])[i + 1]
$$;
create or replace function oyun.kidem_puani(u uuid) returns numeric language sql stable as $$
  select floor(coalesce((select kidem from oyun.cuzdan where user_id = u), 0) + 3 * (select count(*) from oyun.oylar where secmen = u))
$$;
create or replace function oyun.statu_basamak(p numeric) returns int language sql immutable as $$
  select case when p >= 300 then 5 when p >= 150 then 4 when p >= 75 then 3 when p >= 30 then 2 when p >= 10 then 1 else 0 end
$$;
create or replace function oyun.statu_json(u uuid) returns jsonb language sql stable as $$
  with x as (select oyun.kidem_puani(u) puan), y as (select puan, oyun.statu_basamak(puan) b from x)
  select jsonb_build_object('puan', puan, 'basamak', b, 'ad', oyun.statu_ad(b),
           'carpan', round(1 + b * (select kidem_primi from oyun.ulke where id = 1) / 100, 3),
           'sonraki_ad', case when b < 5 then oyun.statu_ad(b + 1) end, 'sonraki_esik', case when b < 5 then oyun.statu_esik(b + 1) end,
           'bu_esik', oyun.statu_esik(b))
  from y
$$;

create or replace function oyun.cuzdanim(u uuid) returns oyun.cuzdan language plpgsql as $$
declare c oyun.cuzdan; t timestamptz := oyun.simdi();
begin
  -- yeni oyuncunun kumbarası dolu başlar
  insert into oyun.cuzdan(user_id, para, son_toplama) values (u, (select baslangic_para from oyun.ayarlar where id = 1), t - interval '8 hours')
  on conflict do nothing;
  update oyun.cuzdan set gun = (t at time zone 'Europe/Istanbul')::date, izle_n = 0, reklam_n = 0, reklam_kul = 0, bagis_bugun = 0
  where user_id = u and gun is distinct from (t at time zone 'Europe/Istanbul')::date;
  select * into c from oyun.cuzdan where user_id = u for update;
  return c;
end $$;

-- Cüzdana para ekle/çıkar (+ hareket kaydı). Yetersiz bakiyede hata verir.
create or replace function oyun.para_islem(u uuid, p_tutar numeric, p_tur text, p_aciklama text, t timestamptz, p_vergi numeric default 0)
returns void language plpgsql as $$
begin
  perform oyun.cuzdanim(u);
  update oyun.cuzdan set para = para + round(p_tutar) where user_id = u and para + round(p_tutar) >= 0;
  if not found then
    raise exception 'Cüzdanında yeterli para yok (% ₺ gerekli, cüzdanında % ₺ var).', oyun.tl(abs(p_tutar)),
      oyun.tl((select para from oyun.cuzdan where user_id = u));
  end if;
  insert into oyun.hesap_hareket(user_id, zaman, tutar, vergi, tur, aciklama) values (u, t, round(p_tutar), round(p_vergi), p_tur, p_aciklama);
end $$;

create or replace function oyun.tasinma_ucreti(p_kaynak smallint, p_hedef smallint, t timestamptz) returns numeric language sql stable as $$
  select round(5000 * u.endeks * (1 - least(90, u.tasinma_destek
                + greatest(oyun.bonus(p_kaynak, 'tasinma', t), oyun.bonus(p_hedef, 'tasinma', t))) / 100))
  from oyun.ulke u where u.id = 1
$$;
create or replace function oyun.il_bekleme_gun(t timestamptz) returns int language sql stable as $$
  select least((select il_degis_gun from oyun.ayarlar where id = 1),
               coalesce((select min(deger)::int from oyun.etkiler where tur = 'il_bekleme' and il_id is null and bas <= t and bit > t),
                        (select il_degis_gun from oyun.ayarlar where id = 1)))
$$;
create or replace function oyun.reklam_fiyat() returns numeric language sql stable as $$
  select round(1500 * endeks) from oyun.ulke where id = 1
$$;

-- Aday adaylığı ücreti: taban × fiyat düzeyi × partinin çarpanı (genel başkan belirler)
create or replace function oyun.aday_ucreti(p_parti bigint, p_tur text, p_il smallint) returns numeric language sql stable as $$
  select round((case p_tur when 'mv_on' then 5000 when 'kurultay' then 10000 when 'cb_on' then 20000
                  when 'bel_on' then 3000 * coalesce((select case when mv >= 14 then 3 when mv >= 8 then 2 else 1 end from oyun.iller where id = p_il), 1)
                  else 0 end)
               * (select endeks from oyun.ulke where id = 1)
               * coalesce((select (aday_ucret ->> p_tur)::numeric from oyun.partiler where id = p_parti), 1))
$$;

-- aday_ol içinden çağrılır: ücret oyuncudan alınır, parti kasasına girer
create or replace function oyun.aday_ucreti_al(p oyun.profiller, p_tur text, t timestamptz) returns numeric language plpgsql as $$
declare ucret numeric := oyun.aday_ucreti(p.parti_id, p_tur, p.il_id); pk text := (select kisa from oyun.partiler where id = p.parti_id);
        fon numeric := round(oyun.aday_ucreti(p.parti_id, p_tur, p.il_id) * oyun.duz('aday_destek') / 100);
begin
  if ucret <= 0 then return 0; end if;
  -- Siyasi katılım fonu (mevzuat): ücretin bir kısmını hazine öder, parti kasasına tamamı girer
  perform oyun.para_islem(p.id, -(ucret - fon), 'aday', format('%s %s başvuru ücreti%s', pk,
    case p_tur when 'mv_on' then 'milletvekili aday adaylığı' when 'bel_on' then 'belediye başkanı aday adaylığı'
               when 'kurultay' then 'genel başkanlık adaylığı' else 'cumhurbaşkanı aday adaylığı' end,
    case when fon > 0 then format(' (%s ₺''sini siyasi katılım fonu ödedi)', oyun.tl(fon)) else '' end), t);
  update oyun.partiler set kasa = kasa + ucret where id = p.parti_id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (p.parti_id, t, ucret, format('%s başvuru ücreti ödedi', p.kad), 'aday');
  return ucret;
end $$;

-- ---------------------------------------------------------------------
-- GELİR HESABI (kumbara)
-- ---------------------------------------------------------------------
create or replace function oyun.gelir_hesap(u uuid, t timestamptz) returns jsonb language plpgsql stable as $$
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
  seri_y := case when c.seri_gun = bugun then c.seri when c.seri_gun = bugun - 1 then c.seri + 1 else 1 end;
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
end $$;

-- Üst çubuk için kısa özet
create or replace function oyun.cuzdan_ozet(u uuid, t timestamptz) returns jsonb language plpgsql as $$
declare c oyun.cuzdan := oyun.cuzdanim(u); g jsonb := oyun.gelir_hesap(u, t);
begin
  return jsonb_build_object('para', c.para, 'birikmis', g -> 'birikmis', 'dolu', g -> 'dolu',
                            'gunun_ilki', c.seri_gun is distinct from (t at time zone 'Europe/Istanbul')::date);
end $$;

-- ---------------------------------------------------------------------
-- HAYAT EKRANI
-- ---------------------------------------------------------------------
create or replace function oyun.etkilerim(p_il smallint, t timestamptz) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(x order by x ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '1' || b.sira, 'kaynak', i.ad || ' Belediyesi · ' || b.ad, 'kaynak_tur', 'belediye', 'yerel', true,
                              'bit', null, 'etkiler', b.etki) x
      from oyun.il_hizmet h join oyun.belediye_hizmetleri b on b.kod = h.kod join oyun.iller i on i.id = h.il_id where h.il_id = p_il
    union all
    select jsonb_build_object('sira', '2' || to_char(max(e.bit), 'YYYYMMDDHH24MI'), 'kaynak', e.kaynak_ad, 'kaynak_tur', e.kaynak_tur,
                              'yerel', e.il_id is not null, 'bit', max(e.bit),
                              'etkiler', jsonb_agg(jsonb_build_object('tur', e.tur, 'deger', e.deger) order by e.id))
      from oyun.etkiler e where (e.il_id is null or e.il_id = p_il) and e.bas <= t and e.bit > t
      group by e.kaynak_ad, e.kaynak_tur, e.kaynak_kod, e.il_id
  ) y
$$;

create or replace function public.hayat() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; u oyun.ulke;
begin
  c := oyun.cuzdanim(p.id);
  select * into u from oyun.ulke where id = 1;
  return jsonb_build_object(
    'para', c.para, 'statu', oyun.statu_json(p.id), 'itibar', oyun.itibar_json(p.id), 'kumbara', oyun.gelir_hesap(p.id, t),
    'seri_gun', c.seri_gun, 'bugun_toplandi', c.seri_gun = (t at time zone 'Europe/Istanbul')::date, 'il_ad', (select ad from oyun.iller where id = p.il_id),
    'makamlar', coalesce((select jsonb_agg(jsonb_build_object('tur', m.tur, 'aylik', round(oyun.makam_maasi(m.tur, m.il_id))))
                          from oyun.makamlar m where m.user_id = p.id and m.bit is null), '[]'::jsonb),
    'reklam', jsonb_build_object('kalan', greatest(0, 5 - c.izle_n),
                                 'hazir', case when c.son_izle > t - interval '60 seconds' then c.son_izle + interval '60 seconds' end),
    'fiyat', jsonb_build_object('tasinma', oyun.tasinma_ucreti(p.il_id, p.il_id, t), 'reklam', oyun.reklam_fiyat(), 'endeks', round(u.endeks, 3)),
    'ek_yayin', jsonb_build_object('kalan_alim', greatest(0, 3 - c.reklam_n), 'elde', greatest(0, c.reklam_n - c.reklam_kul)),
    'bagis', jsonb_build_object('bugun', c.bagis_bugun, 'tavan', u.asgari),
    'ulke', jsonb_build_object('asgari', u.asgari, 'vergi', u.vergi, 'destek', u.destek, 'kidem_primi', u.kidem_primi,
                               'enflasyon', round(u.enflasyon, 1), 'tasinma_destek', u.tasinma_destek),
    'etkiler', oyun.etkilerim(p.il_id, t),
    'mulkler', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'tur', m.tur, 'bedel', m.bedel, 'gunluk', m.gunluk) order by m.alis)
                         from oyun.mulkler m join oyun.iller i on i.id = m.il_id where m.user_id = p.id), '[]'::jsonb),
    'paketler', (select jsonb_agg(jsonb_build_object('urun_id', urun_id, 'ad', ad, 'miktar', miktar) order by sira) from oyun.paketler),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'vergi', h.vergi, 'tur', h.tur, 'aciklama', h.aciklama)
                    order by h.zaman desc, h.id desc)
                  from (select * from oyun.hesap_hareket where user_id = p.id order by zaman desc, id desc limit 25) h), '[]'::jsonb));
end $$;

-- Kumbarayı topla. Günün ilk toplamasında: seri ve kıdem işlenir, günlük destekler yatar.
create or replace function public.topla() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
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
    perform oyun.bildir(p.id, format('Tebrikler! Statün yükseldi: %s. Maaşın arttı.', oyun.statu_ad(sonra)), t);
  end if;
  return public.hayat() || jsonb_build_object('sonuc', jsonb_build_object('maas', tutar, 'ilk', ilk, 'seri', (g ->> 'seri')::int,
    'destek', des + hem, 'statu_atladi', sonra > once));
end $$;

-- Ödüllü reklam izlendi (uygulama reklam bitince çağırır): 2 saatlik maaş, günde 5, en az 60 sn arayla
create or replace function public.reklam_odul() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; odul numeric;
begin
  c := oyun.cuzdanim(p.id);
  if c.izle_n >= 5 then raise exception 'Bugünkü reklam ödüllerini aldın. Yarın yeniden gel.'; end if;
  if c.son_izle is not null and c.son_izle > t - interval '60 seconds' then raise exception 'Bir sonraki reklam için biraz bekle.'; end if;
  odul := (oyun.gelir_hesap(p.id, t) ->> 'reklam_odul')::numeric;
  update oyun.cuzdan set izle_n = izle_n + 1, son_izle = t where user_id = p.id;
  perform oyun.para_islem(p.id, odul, 'reklam_odul', 'Reklam izleme ödülü', t);
  return public.hayat() || jsonb_build_object('sonuc', jsonb_build_object('odul', odul));
end $$;

-- Ek propaganda hakkı (günde en fazla 3; yalnızca yayın yetkisi olanlar)
create or replace function public.reklam_al() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; fiyat numeric := oyun.reklam_fiyat();
begin
  if not exists (select 1 from oyun.yayin_secenekleri(p, t)) then raise exception 'Yayın yetkin olmadığı için ek hak alamazsın.'; end if;
  c := oyun.cuzdanim(p.id);
  if c.reklam_n >= 3 then raise exception 'Bugün en fazla 3 ek yayın hakkı alabilirsin.'; end if;
  perform oyun.para_islem(p.id, -fiyat, 'reklam', 'Ek propaganda yayını hakkı', t);
  update oyun.cuzdan set reklam_n = reklam_n + 1 where user_id = p.id;
  return jsonb_build_object('tamam', true, 'ek_yayin', c.reklam_n + 1 - c.reklam_kul);
end $$;

-- ---------------------------------------------------------------------
-- SATIN ALMA (RevenueCat webhook → odeme-webhook sunucu fonksiyonu → odeme_isle; yalnız service_role)
-- ---------------------------------------------------------------------
create or replace function public.magaza() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('urun_id', urun_id, 'ad', ad, 'miktar', miktar) order by sira), '[]'::jsonb) from oyun.paketler
$$;

create or replace function public.odeme_isle(p_olay jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare e jsonb := coalesce(p_olay -> 'event', p_olay); tur text := e ->> 'type'; u uuid; pk oyun.paketler; islem text; s oyun.satin_almalar; dus numeric;
begin
  islem := coalesce(e ->> 'transaction_id', e ->> 'original_transaction_id', e ->> 'id');
  if tur = 'TEST' then return jsonb_build_object('durum', 'test'); end if;
  begin u := (e ->> 'app_user_id')::uuid; exception when others then return jsonb_build_object('durum', 'kullanici_yok'); end;
  if not exists (select 1 from oyun.profiller where id = u) then return jsonb_build_object('durum', 'kullanici_yok'); end if;
  if tur in ('NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE') then
    select * into pk from oyun.paketler where urun_id = e ->> 'product_id';
    if pk.urun_id is null then return jsonb_build_object('durum', 'urun_yok'); end if;
    if islem is null then return jsonb_build_object('durum', 'islem_yok'); end if;
    insert into oyun.satin_almalar(islem_id, user_id, urun_id, miktar, olay) values (islem, u, pk.urun_id, pk.miktar, e)
    on conflict (islem_id) do nothing;
    if not found then return jsonb_build_object('durum', 'zaten_islendi'); end if;
    perform oyun.para_islem(u, pk.miktar, 'satin_alma', pk.ad || ' (satın alma)', oyun.simdi());
    perform oyun.bildir(u, format('Satın alma tamamlandı: cüzdanına %s ₺ eklendi. Teşekkürler!', oyun.tl(pk.miktar)), oyun.simdi());
    return jsonb_build_object('durum', 'eklendi', 'miktar', pk.miktar);
  elsif tur = 'CANCELLATION' then
    -- mağaza iadesi: eklenen para (cüzdanda kaldığı kadarıyla) geri alınır
    select * into s from oyun.satin_almalar where islem_id = islem for update;
    if s.id is null or s.iade then return jsonb_build_object('durum', 'yok_say'); end if;
    perform oyun.cuzdanim(u);
    dus := least(s.miktar, (select para from oyun.cuzdan where user_id = u));
    update oyun.satin_almalar set iade = true where id = s.id;
    if dus > 0 then perform oyun.para_islem(u, -dus, 'iade', 'Mağaza iadesi', oyun.simdi()); end if;
    return jsonb_build_object('durum', 'iade', 'dusulen', dus);
  end if;
  return jsonb_build_object('durum', 'yok_say');
end $$;

-- ---------------------------------------------------------------------
-- PARTİ KASASI
-- ---------------------------------------------------------------------
-- Bağış: kişi başı günde en fazla 1 aylık asgari ücret (Siyasi Partiler Kanunu'ndaki bağış sınırı gibi)
create or replace function public.bagis_yap(p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); c oyun.cuzdan; tavan numeric;
begin
  if p.parti_id is null then raise exception 'Bağış için bir partiye üye olmalısın.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ bağışlayabilirsin.'; end if;
  c := oyun.cuzdanim(p.id);
  tavan := (select asgari from oyun.ulke where id = 1);
  if c.bagis_bugun + m > tavan then
    raise exception 'Bağış sınırı: kişi başı günde en fazla % ₺ (bugün % ₺ bağışladın).', oyun.tl(tavan), oyun.tl(c.bagis_bugun);
  end if;
  perform oyun.para_islem(p.id, -m, 'bagis', format('%s partisine bağış', (select kisa from oyun.partiler where id = p.parti_id)), t);
  update oyun.cuzdan set bagis_bugun = bagis_bugun + m, kidem = kidem + m / tavan where user_id = p.id;   -- her asgari ücret tutarında bağış 1 kıdem puanı
  update oyun.partiler set kasa = kasa + m where id = p.parti_id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (p.parti_id, t, m, format('%s bağış yaptı', p.kad), 'bagis');
  return public.parti_kasa(p.parti_id);
end $$;

create or replace function public.parti_destek(p_kad text, p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; pa oyun.partiler; m numeric := round(coalesce(p_miktar, 0));
begin
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.gb is distinct from p.id then raise exception 'Parti kasasını yalnızca genel başkan kullanabilir.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pa.id then raise exception 'Yalnızca kendi partinin üyelerine destek verebilirsin.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ destek verebilirsin.'; end if;
  if pa.kasa < m then raise exception 'Parti kasasında yeterli para yok (kasada % ₺ var).', oyun.tl(pa.kasa); end if;
  update oyun.partiler set kasa = kasa - m where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -m, format('%s üyesine kampanya desteği', h.kad), 'destek');
  perform oyun.para_islem(h.id, m, 'parti_destek', format('%s kampanya desteği', pa.kisa), t);
  perform oyun.bildir(h.id, format('Genel Başkan %s, parti kasasından sana %s ₺ kampanya desteği gönderdi.', p.kad, oyun.tl(m)), t);
  return public.parti_kasa(pa.id);
end $$;

-- Genel başkan aday adaylığı ücretlerinin çarpanlarını belirler (0-3)
create or replace function public.parti_ucret_ayarla(p_ucret jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; k text; v jsonb := '{}'; x numeric;
begin
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.gb is distinct from p.id then raise exception 'Aday ücretlerini yalnızca genel başkan belirler.'; end if;
  foreach k in array array['mv_on','bel_on','kurultay','cb_on'] loop
    x := round(coalesce((p_ucret ->> k)::numeric, (pa.aday_ucret ->> k)::numeric, 1), 2);
    if x < 0 or x > 3 then raise exception 'Çarpanlar 0 ile 3 arasında olmalı.'; end if;
    v := v || jsonb_build_object(k, x);
  end loop;
  update oyun.partiler set aday_ucret = v where id = pa.id;
  perform oyun.olay('parti', format('%s aday adaylığı ücretlerini güncelledi.', pa.kisa), null, pa.id, t);
  return public.parti_kasa(pa.id);
end $$;

-- Son genel seçimde %3'ü geçen partiler, oy oranına göre hazine yardımı alır
create or replace function oyun.parti_yardim_paylari() returns table(parti_id bigint, oran numeric) language sql stable as $$
  with s as (select id from oyun.secimler where tur = 'mv' and durum <> 'bekliyor' order by oy_bit desc limit 1),
       o as (select o.parti_id, count(*)::numeric n from oyun.oylar o join s on s.id = o.secim_id where o.parti_id is not null group by o.parti_id),
       tp as (select sum(n) toplam from o),
       g as (select o.parti_id, o.n from o, tp where o.n * 100 / tp.toplam >= 3
             and exists (select 1 from oyun.partiler pa where pa.id = o.parti_id and not pa.kapali))
  select g.parti_id, g.n / sum(g.n) over () from g
$$;
create or replace function oyun.parti_yardim_payi(p_parti bigint) returns numeric language sql stable as $$
  select coalesce(round((select oran from oyun.parti_yardim_paylari() where parti_id = p_parti) * (select parti_yardim from oyun.ulke where id = 1)), 0)
$$;

create or replace function public.parti_kasa(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  return jsonb_build_object('kasa', round(pa.kasa), 'gb_mi', pa.gb = p.id, 'uye_mi', p.parti_id = pa.id,
    'hazine_yardimi', oyun.parti_yardim_payi(pa.id), 'carpanlar', pa.aday_ucret,
    'ucretler', jsonb_build_object('mv_on', oyun.aday_ucreti(pa.id, 'mv_on', p.il_id), 'bel_on', oyun.aday_ucreti(pa.id, 'bel_on', p.il_id),
                                   'kurultay', oyun.aday_ucreti(pa.id, 'kurultay', null), 'cb_on', oyun.aday_ucreti(pa.id, 'cb_on', null)),
    'beyanname', oyun.beyanname_json(pa.id, null), 'iktidar', oyun.iktidar_karnesi(pa.id),
    'beyanname_acik', exists (select 1 from oyun.secimler where tur = 'mv' and durum = 'bekliyor' and oyun.simdi() < oy_bit),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'aciklama', h.aciklama) order by h.zaman desc, h.id desc)
                            from (select * from oyun.parti_hareket where parti_id = pa.id order by zaman desc, id desc limit 15) h), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- GÜNLÜK ÖDEMELER (her gece): partilere hazine yardımı, temizlik
-- ---------------------------------------------------------------------
create or replace function oyun.gunluk_odemeler(g date, t timestamptz) returns void language plpgsql as $$
declare u oyun.ulke; r record; tutar numeric;
begin
  select * into u from oyun.ulke where id = 1;
  if u.parti_yardim > 0 then
    for r in select * from oyun.parti_yardim_paylari() loop
      tutar := round(r.oran * u.parti_yardim);
      continue when tutar <= 0;
      update oyun.partiler set kasa = kasa + tutar where id = r.parti_id;
      insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (r.parti_id, t, tutar, 'Hazine yardımı (' || to_char(g, 'DD.MM') || ')', 'yardim');
    end loop;
  end if;
  delete from oyun.hesap_hareket where zaman < t - interval '60 days';
  delete from oyun.parti_hareket where zaman < t - interval '90 days';
  delete from oyun.etkiler where bit < t - interval '30 days';
end $$;

-- Kumbarası dolan oyuncuya telefon bildirimi (dolum başına bir kez; 3 günden uzun süredir girmeyenlere gönderilmez)
create or replace function oyun.kumbara_hatirlat(t timestamptz) returns void language plpgsql as $$
declare r record;
begin
  for r in select c.user_id from oyun.cuzdan c
           where c.son_toplama <= t - make_interval(hours => oyun.kumbara_saat()::int) and c.son_toplama > t - interval '3 days'
             and (c.kumbara_bildirim is null or c.kumbara_bildirim < c.son_toplama)
             and exists (select 1 from oyun.cihazlar d where d.user_id = c.user_id) loop
    perform oyun.push_kisiye(r.user_id, 'kisisel', 'Kumbaran doldu 💰', format('Maaşın %s saattir birikiyor. Toplamazsan birikme durur.', oyun.kumbara_saat()), '{"ekran":"hayat"}');
    update oyun.cuzdan set kumbara_bildirim = t where user_id = r.user_id;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- POLİTİKALAR (yürütme)
-- ---------------------------------------------------------------------
create or replace function oyun.politika_tanim() returns table(kod text, ad text, birim text, bakanlik text, bekleme_gun int, aciklama text)
language sql immutable as $$
  values ('asgari','Asgari ücret','tl_ay','calisma',7,'Herkesin maaşının tabanı. Düşürülemez; bir seferde en fazla %30 artırılabilir. Ekonominin kaldırabileceğinin üstüne çıkarsa enflasyon yükselir.'),
         ('kidem_primi','Kıdem primi','yuzde','calisma',7,'Her statü basamağının maaşa eklediği prim (%0-20). Yüksek prim enflasyonu biraz artırır.'),
         ('destek','Sosyal destek','tl_gun','calisma',3,'Yeni Gelen ve Vatandaş statüsündekilere günlük destek (0-1.000 ₺). 8 milyon kişiye ödenir.'),
         ('vergi','Gelir vergisi','yuzde','maliye',3,'Asgari ücretin üstündeki kazançtan kesilir. Meclis''in bütçe kanunundaki bant içinde, bir seferde en fazla 5 puan değişir.'),
         ('tasinma_destek','Taşınma desteği','yuzde','ulastirma',7,'İl değiştirirken ödenen masrafın devletin karşıladığı kısmı (%0-80).')
$$;

create or replace function oyun.politika_sinir(p_kod text) returns table(alt numeric, ust numeric) language sql stable as $$
  select case p_kod when 'asgari' then u.asgari when 'vergi' then greatest(u.vergi_alt, u.vergi - 5) else 0 end,
         case p_kod when 'asgari' then round(u.asgari * 1.3) when 'kidem_primi' then 20 when 'destek' then 1000
                    when 'vergi' then least(u.vergi_ust, u.vergi + 5) when 'tasinma_destek' then 80 end
  from oyun.ulke u where u.id = 1
$$;

create or replace function oyun.politika_deger(p_kod text) returns numeric language sql stable as $$
  select case p_kod when 'asgari' then asgari when 'kidem_primi' then kidem_primi when 'destek' then destek
                    when 'vergi' then vergi when 'tasinma_destek' then tasinma_destek end from oyun.ulke where id = 1
$$;

create or replace function oyun.politika_listesi(p_bakanlik text, t timestamptz) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'bakanlik', d.bakanlik, 'aciklama', d.aciklama,
           'deger', oyun.politika_deger(d.kod), 'alt', s.alt, 'ust', s.ust, 'bekleme_gun', d.bekleme_gun,
           'hazir', (select max(k.zaman) + make_interval(days => d.bekleme_gun) from oyun.politika_kayit k where k.kod = d.kod
                     having max(k.zaman) + make_interval(days => d.bekleme_gun) > t))
         order by d.bakanlik, d.kod), '[]'::jsonb)
  from oyun.politika_tanim() d, lateral oyun.politika_sinir(d.kod) s
  where p_bakanlik is null or d.bakanlik = p_bakanlik
$$;

-- Bir politika değişikliğinin bütçeye (günlük, milyar ₺; + maliyet / − gelir) ve enflasyona etkisi
create or replace function oyun.politika_etki(p_kod text, p_deger numeric) returns jsonb language plpgsql stable as $$
declare u oyun.ulke; u2 oyun.ulke; enf numeric := 0;
begin
  select * into u from oyun.ulke where id = 1;
  u2 := u;
  if p_kod = 'asgari' then u2.asgari := p_deger;
    enf := (greatest(0, p_deger / u.asgari_ref - 1) - greatest(0, u.asgari / u.asgari_ref - 1)) * 40;
  elsif p_kod = 'vergi' then u2.vergi := p_deger;
  elsif p_kod = 'destek' then u2.destek := p_deger; enf := (p_deger - u.destek) / 100;
  elsif p_kod = 'kidem_primi' then enf := (p_deger - u.kidem_primi) * 0.15;
  end if;
  return jsonb_build_object('gunluk', round((oyun.ulke_hesap(u) ->> 'denge')::numeric - (oyun.ulke_hesap(u2) ->> 'denge')::numeric, 3),
                            'enflasyon', round(enf, 2));
end $$;

create or replace function public.politika_onizle(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  return oyun.politika_etki(p_kod, p_deger) || jsonb_build_object('mali_alan', oyun.mali_alan());
end $$;

create or replace function public.politika_ayarla(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d record; s record; eski numeric; yeni numeric; son timestamptz;
        mk text; unvan text; bas text;
begin
  select * into d from oyun.politika_tanim() x where x.kod = p_kod;
  if d.kod is null then raise exception 'Geçersiz politika.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null) then mk := 'cb'; unvan := 'Cumhurbaşkanı';
  elsif exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'bakan' and bakanlik = d.bakanlik and bit is null) then
    mk := 'bakan'; unvan := (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = d.bakanlik);
  else raise exception 'Bu ayarı yalnızca cumhurbaşkanı ve ilgili bakan yapabilir.'; end if;
  select * into s from oyun.politika_sinir(p_kod);
  eski := oyun.politika_deger(p_kod);
  yeni := case when d.birim in ('tl_ay','tl_gun') then round(p_deger) else round(p_deger, 1) end;
  if yeni is null or yeni = eski then raise exception 'Yeni değer mevcut değerle aynı.'; end if;
  if yeni < s.alt or yeni > s.ust then
    raise exception '% şu an % ile % arasında ayarlanabilir.', d.ad, oyun.birim_yaz(s.alt, d.birim), oyun.birim_yaz(s.ust, d.birim);
  end if;
  select max(zaman) into son from oyun.politika_kayit where kod = p_kod;
  if son is not null and son + make_interval(days => d.bekleme_gun) > t then
    raise exception '% en erken % tarihinde yeniden değiştirilebilir.', d.ad, to_char((son + make_interval(days => d.bekleme_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  execute format('update oyun.ulke set %I = $1 where id = 1', p_kod) using yeni;
  insert into oyun.politika_kayit(kod, eski, yeni, user_id, makam, zaman) values (p_kod, eski, yeni, p.id, mk, t);
  bas := format('%s: %s → %s', d.ad, oyun.birim_yaz(eski, d.birim), oyun.birim_yaz(yeni, d.birim));
  perform oyun.gazete_ekle(case when mk = 'cb' then 'kararname' else 'icraat' end, bas, format('%s %s tarafından belirlendi.', unvan, p.kad), null, t);
  perform oyun.olay('ekonomi', format('%s %s: %s', unvan, p.kad, bas), null, p.parti_id, t);
  return jsonb_build_object('tamam', true, 'kod', p_kod, 'eski', eski, 'yeni', yeni);
end $$;

-- ---------------------------------------------------------------------
-- MALİ ALAN VE VAAT MALİYETİ
-- ---------------------------------------------------------------------
-- Ülkenin vaatlere ayırabileceği günlük alan (milyar ₺): bütçe fazlası + hazinenin 60'ta biri
create or replace function oyun.mali_alan() returns numeric language sql stable as $$
  select round(greatest(0, (oyun.ulke_hesap(u) ->> 'denge')::numeric) + greatest(0, u.hazine) / 60, 3) from oyun.ulke u where u.id = 1
$$;

-- Tek bir vaadin günlük maliyeti (milyar ₺; gb için ₺) ve enflasyon etkisi
create or replace function oyun.vaat_maliyet(p_kapsam text, p_kod text, p_hedef numeric, p_il smallint, p_parti bigint) returns jsonb
language plpgsql stable as $$
declare u oyun.ulke; d oyun.il_durum; m numeric := 0; enf numeric := 0; e jsonb; mal numeric;
begin
  select * into u from oyun.ulke where id = 1;
  if p_kapsam = 'beyanname' then
    if p_kod in ('asgari','vergi','destek','kidem','tasinma') then
      e := oyun.politika_etki(case p_kod when 'kidem' then 'kidem_primi' when 'tasinma' then 'tasinma_destek' else p_kod end, p_hedef);
      m := (e ->> 'gunluk')::numeric; enf := (e ->> 'enflasyon')::numeric;
    elsif p_kod = 'ikramiye' then m := p_hedef * oyun.nufus('ikramiye') / 1e9 / 30;
    elsif exists (select 1 from oyun.duzenleme_tanim where kod = p_kod and kapsam = 'ulke') then
      e := oyun.duzenleme_etki(p_kod, p_hedef);
      m := (e ->> 'gunluk')::numeric; enf := (e ->> 'enflasyon')::numeric;
    elsif p_kod = 'ozellestirme' then m := -10.0 / 30;
    elsif p_kod = 'referandum' then m := 0;
    else
      select maliyet into mal from oyun.icraatlar where kod = p_kod;
      m := coalesce(mal, 0) / 7;
    end if;
  elsif p_kapsam = 'mv' then
    if p_kod = 'vergi_tavan' and p_hedef < u.vergi then m := (oyun.politika_etki('vergi', p_hedef) ->> 'gunluk')::numeric;
    elsif p_kod = 'belediye_payi' and p_hedef > u.belediye_payi then
      m := (oyun.ulke_hesap(u) ->> 'belediye')::numeric * (p_hedef - u.belediye_payi) / u.belediye_payi;
    elsif exists (select 1 from oyun.duzenleme_tanim where kod = p_kod and kapsam = 'ulke') then
      e := oyun.duzenleme_etki(p_kod, p_hedef);
      m := (e ->> 'gunluk')::numeric; enf := (e ->> 'enflasyon')::numeric;
    end if;
  elsif p_kapsam = 'bel' then
    select * into d from oyun.il_durum where il_id = p_il;
    if p_kod = 'kent_vergisi' and p_hedef < d.kent_vergisi then m := oyun.il_gelir(p_il) * (1 - (1 + p_hedef / 10) / (1 + d.kent_vergisi / 10));
    elsif p_kod = 'kent_vergisi' and p_hedef > d.kent_vergisi then m := -oyun.il_gelir(p_il) * ((1 + p_hedef / 10) / (1 + d.kent_vergisi / 10) - 1);
    elsif p_kod = 'hemsehri' and p_hedef > d.hemsehri then m := oyun.hemsehri_gider(p_il, p_hedef - d.hemsehri);
    elsif p_kod in ('lokanta','ulasim','kira','istihdam') and not exists (select 1 from oyun.il_hizmet where il_id = p_il and kod = p_kod) then
      m := oyun.hizmet_gider(p_il, p_kod);
    elsif p_kod = 'emlak' then
      m := -(p_hedef - oyun.il_duz(p_il, 'emlak')) * u.endeks * oyun.nufus('il_hane') * (select mv from oyun.iller where id = p_il) / 600 / 1e9;
    elsif p_kod = 'hosgeldin' then m := greatest(0, p_hedef - oyun.il_duz(p_il, 'hosgeldin')) * 2000 / 1e9;
    elsif p_kod = 'imar_barisi' then m := -4 * oyun.il_gunluk_gelir((select mv from oyun.iller where id = p_il)) * u.endeks / 30;
    elsif p_kod in ('altyapi','rayli') then
      m := (select gun from oyun.belediye_yatirimlari where kod = p_kod) * oyun.il_gunluk_gelir((select mv from oyun.iller where id = p_il)) * u.endeks / 30;
    end if;
  elsif p_kapsam = 'gb' then
    if p_kod = 'kampanya' then m := p_hedef / 30; end if;
  end if;
  return jsonb_build_object('gunluk', round(m, 4), 'enflasyon', round(enf, 2));
end $$;

create or replace function oyun.vaat_alani(p_kapsam text, p_il smallint, p_parti bigint) returns numeric language sql stable as $$
  select case p_kapsam when 'bel' then oyun.il_mali_alan(p_il)
                       when 'gb' then coalesce((select kasa from oyun.partiler where id = p_parti), 0) / 30 + oyun.parti_yardim_payi(p_parti)
                       else oyun.mali_alan() end
$$;

-- Bir vaat listesinin toplamı ve karşılanabilirliği
create or replace function oyun.vaat_degerlendir_liste(p_kapsam text, p_il smallint, p_parti bigint, p_vaatler jsonb) returns jsonb
language plpgsql stable as $$
declare v jsonb; tur oyun.vaat_turleri; c jsonb; liste jsonb := '[]'; toplam numeric := 0; enf numeric := 0; alan numeric := oyun.vaat_alani(p_kapsam, p_il, p_parti); hedef numeric;
begin
  for v in select * from jsonb_array_elements(coalesce(p_vaatler, '[]')) loop
    select * into tur from oyun.vaat_turleri where kapsam = p_kapsam and kod = v ->> 'kod';
    if tur.kod is null then raise exception 'Geçersiz vaat: %', v ->> 'kod'; end if;
    hedef := nullif(v ->> 'hedef', '')::numeric;
    if tur.birim <> 'yok' then
      if hedef is null then raise exception '"%" için bir hedef değer girmelisin.', tur.ad; end if;
      if (tur.min is not null and hedef < tur.min) or (tur.max is not null and hedef > tur.max) then
        raise exception '"%" için hedef % ile % arasında olmalı.', tur.ad, oyun.birim_yaz(tur.min, tur.birim), oyun.birim_yaz(tur.max, tur.birim);
      end if;
      if tur.kod = 'asgari' and hedef <= (select asgari from oyun.ulke where id = 1) then raise exception 'Asgari ücret vaadi bugünkünden yüksek olmalı.'; end if;
    else hedef := null; end if;
    c := oyun.vaat_maliyet(p_kapsam, tur.kod, hedef, p_il, p_parti);
    toplam := toplam + (c ->> 'gunluk')::numeric; enf := enf + (c ->> 'enflasyon')::numeric;
    liste := liste || jsonb_build_object('kod', tur.kod, 'ad', tur.ad, 'hedef', hedef, 'birim', tur.birim,
                                         'hedef_yazi', case when hedef is not null then oyun.birim_yaz(hedef, tur.birim) end,
                                         'gunluk', c -> 'gunluk', 'enflasyon', c -> 'enflasyon');
  end loop;
  return jsonb_build_object('vaatler', liste, 'toplam', round(toplam, 4), 'enflasyon', round(enf, 2), 'alan', round(alan, 4),
    'birim', case p_kapsam when 'gb' then 'tl' else 'milyar' end,
    'karar', case when toplam <= alan * 0.5 and enf <= 3 then 'karsilanabilir'
                  when toplam <= alan and enf <= 6 then 'zorlayici' else 'karsiliksiz' end);
end $$;

-- Vaat seçenekleri ekranı: katalog + bugünkü değerler + mali alan
create or replace function public.vaat_secenekleri(p_kapsam text, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); u oyun.ulke; d oyun.il_durum; il smallint := coalesce(p_il, p.il_id)::smallint;
begin
  select * into u from oyun.ulke where id = 1;
  select * into d from oyun.il_durum where il_id = il;
  return jsonb_build_object('kapsam', p_kapsam, 'il_id', il, 'il_ad', (select ad from oyun.iller where id = il),
    'en_fazla', case p_kapsam when 'beyanname' then 5 when 'bel' then 4 when 'mv' then 3 else 2 end,
    'alan', oyun.vaat_alani(p_kapsam, il, p.parti_id), 'birim', case p_kapsam when 'gb' then 'tl' else 'milyar' end,
    'turler', (select jsonb_agg(jsonb_build_object('kod', t.kod, 'ad', t.ad, 'birim', t.birim, 'tip', t.tip, 'min', t.min, 'max', t.max, 'aciklama', t.aciklama,
                 'mevcut', case t.kod when 'asgari' then u.asgari when 'vergi' then u.vergi when 'kidem' then u.kidem_primi when 'destek' then u.destek
                                      when 'tasinma' then u.tasinma_destek when 'vergi_tavan' then u.vergi_ust when 'belediye_payi' then u.belediye_payi
                                      when 'baraj' then (select baraj from oyun.ayarlar where id = 1) when 'parti_yardim' then u.parti_yardim
                                      when 'kent_vergisi' then d.kent_vergisi when 'hemsehri' then d.hemsehri
                                      when 'aday_ucret' then (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = p.parti_id) end,
                 'acik', case when t.kod in ('lokanta','ulasim','kira','istihdam') then exists (select 1 from oyun.il_hizmet h where h.il_id = il and h.kod = t.kod) end)
               order by t.sira) from oyun.vaat_turleri t where t.kapsam = p_kapsam));
end $$;

create or replace function public.vaat_hesapla(p_kapsam text, p_vaatler jsonb, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  return oyun.vaat_degerlendir_liste(p_kapsam, coalesce(p_il, p.il_id)::smallint, p.parti_id, p_vaatler);
end $$;

create or replace function oyun.vaat_grubu(p_tur text) returns text language sql immutable as $$
  select case when p_tur in ('bel_on','bel') then 'bel' when p_tur in ('mv_on','mv') then 'mv' when p_tur in ('cb_on','cb','cb2') then 'cb'
              when p_tur = 'kurultay' then 'gb' end
$$;

-- Vaatlerin kaydı (bekleyen eski liste silinir, yenisi yazılır). Karşılıksız liste kaydedilemez.
create or replace function oyun.vaatleri_yaz(p_kapsam text, p_donem text, u uuid, p_parti bigint, p_il smallint, p_vaatler jsonb, t timestamptz) returns jsonb
language plpgsql as $$
declare r jsonb; v jsonb; enfazla int := case p_kapsam when 'beyanname' then 5 when 'bel' then 4 when 'mv' then 3 else 2 end; mevcut numeric;
begin
  if jsonb_array_length(coalesce(p_vaatler, '[]')) > enfazla then raise exception 'En fazla % vaat verebilirsin.', enfazla; end if;
  if (select count(distinct x ->> 'kod') from jsonb_array_elements(coalesce(p_vaatler, '[]')) x) < jsonb_array_length(coalesce(p_vaatler, '[]')) then
    raise exception 'Aynı vaadi iki kez veremezsin.';
  end if;
  r := oyun.vaat_degerlendir_liste(p_kapsam, p_il, p_parti, p_vaatler);
  if r ->> 'karar' = 'karsiliksiz' then
    raise exception 'Bu vaatlerin karşılığı yok: günlük maliyet mali alanı aşıyor ya da enflasyonu fazla artırıyor. Vaatleri küçült ya da vergi artışı gibi gelir getiren bir vaatle dengele.';
  end if;
  delete from oyun.vaatler where kapsam = p_kapsam and donem = p_donem and durum = 'bekliyor'
    and (case when p_kapsam = 'beyanname' then parti_id = p_parti else user_id = u end);
  mevcut := (select vergi from oyun.ulke where id = 1);
  for v in select * from jsonb_array_elements(r -> 'vaatler') loop
    insert into oyun.vaatler(kapsam, donem, user_id, parti_id, il_id, kod, hedef, yon, olusturma)
    values (p_kapsam, p_donem, case when p_kapsam = 'beyanname' then null else u end, p_parti, p_il, v ->> 'kod', (v ->> 'hedef')::numeric,
            coalesce((select yon from oyun.vaat_turleri where kapsam = p_kapsam and kod = v ->> 'kod'),
                     case when (v ->> 'hedef')::numeric < coalesce(oyun.vaat_mevcut(p_kapsam, v ->> 'kod', p_il, p_parti), mevcut) then '<=' else '>=' end), t);
  end loop;
  return r;
end $$;

-- Aday: bildirge metni + makamına uygun ölçülebilir vaatler. Oylama bitene kadar değiştirilebilir.
create or replace function public.vaat_yaz(p_secim bigint, p_metin text, p_vaatler jsonb default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; m text; grup text[]; son timestamptz; kapsam text; a oyun.adaylar; r jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or not exists (select 1 from oyun.adaylar x join oyun.secimler y on y.id = x.secim_id
                                 where x.user_id = p.id and y.donem = s.donem and oyun.vaat_grubu(y.tur) = oyun.vaat_grubu(s.tur)) then
    raise exception 'Bu seçimde adaylığın yok.';
  end if;
  grup := case when s.tur in ('bel_on','bel') then array['bel_on','bel'] when s.tur in ('cb_on','cb','cb2') then array['cb_on','cb','cb2']
               when s.tur in ('mv_on','mv') then array['mv_on','mv'] else array[s.tur] end;
  select max(oy_bit) into son from oyun.secimler where donem = s.donem and tur = any(grup) and durum = 'bekliyor';
  if son is null or t >= son then raise exception 'Oylama bittikten sonra bildirge değiştirilemez.'; end if;
  m := nullif(btrim(coalesce(p_metin, '')), '');
  if m is not null then m := oyun.metin_temizle(m, 280); end if;
  update oyun.adaylar x set vaat = m from oyun.secimler y
   where x.secim_id = y.id and x.user_id = p.id and y.donem = s.donem and y.tur = any(grup);
  kapsam := oyun.vaat_grubu(s.tur);
  if p_vaatler is not null then
    if kapsam = 'cb' then raise exception 'Cumhurbaşkanı adayının vaatleri partisinin seçim beyannamesidir; beyannameyi genel başkan yazar.'; end if;
    select x.* into a from oyun.adaylar x join oyun.secimler y on y.id = x.secim_id where x.user_id = p.id and y.donem = s.donem and y.tur = any(grup) limit 1;
    r := oyun.vaatleri_yaz(kapsam, s.donem, p.id, p.parti_id, a.il_id, p_vaatler, t);
  end if;
  return jsonb_build_object('tamam', true, 'vaat', m, 'hesap', r);
end $$;

-- Adayın o seçimdeki bildirgesi ve vaatleri (düzenleme ekranı için)
create or replace function public.vaatlerim(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); s oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_secim;
  return jsonb_build_object('kapsam', oyun.vaat_grubu(s.tur),
    'vaat', (select x.vaat from oyun.adaylar x join oyun.secimler y on y.id = x.secim_id
             where x.user_id = p.id and y.donem = s.donem and oyun.vaat_grubu(y.tur) = oyun.vaat_grubu(s.tur) and x.vaat is not null limit 1),
    'vaatler', oyun.aday_vaatleri(p.id, p_secim));
end $$;

-- Genel başkanın seçim beyannamesi: yaklaşan genel seçim için, oylama bitene kadar
create or replace function public.beyanname_kaydet(p_metin text, p_vaatler jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; m text; r jsonb;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then raise exception 'Seçim beyannamesini yalnızca genel başkan yazar.'; end if;
  select * into s from oyun.secimler where tur = 'mv' and durum = 'bekliyor' and t < oy_bit order by oy_bas limit 1;
  if s.id is null then raise exception 'Yaklaşan bir genel seçim yok.'; end if;
  m := nullif(btrim(coalesce(p_metin, '')), '');
  if m is not null then m := oyun.metin_temizle(m, 600); end if;
  r := oyun.vaatleri_yaz('beyanname', s.donem, null, pa.id, null, p_vaatler, t);
  insert into oyun.parti_beyanname(parti_id, donem, metin, zaman) values (pa.id, s.donem, m, t)
  on conflict (parti_id, donem) do update set metin = excluded.metin, zaman = excluded.zaman;
  perform oyun.olay('parti', format('%s seçim beyannamesini açıkladı.', pa.kisa), null, pa.id, t);
  return jsonb_build_object('tamam', true, 'hesap', r, 'beyanname', oyun.beyanname_json(pa.id, s.donem));
end $$;

-- ---------------------------------------------------------------------
-- VAAT TAKİBİ (her gece)
-- ---------------------------------------------------------------------
create or replace function oyun.vaat_kosul(v oyun.vaatler, t timestamptz) returns boolean language plpgsql stable as $$
declare u oyun.ulke; d oyun.il_durum; v_cb uuid; bas timestamptz := coalesce(v.aktif_bas, t);
begin
  select * into u from oyun.ulke where id = 1;
  if v.kapsam = 'beyanname' then
    case v.kod
      when 'asgari' then return u.asgari >= v.hedef;
      when 'vergi' then return case when v.yon = '<=' then u.vergi <= v.hedef else u.vergi >= v.hedef end;
      when 'kidem' then return u.kidem_primi >= v.hedef;
      when 'destek' then return u.destek >= v.hedef;
      when 'tasinma' then return u.tasinma_destek >= v.hedef;
      when 'ikramiye' then
        v_cb := (select user_id from oyun.makamlar where id = v.makam_id);
        return exists (select 1 from oyun.kararnameler k where k.tur = 'ikramiye' and k.cb = v_cb and k.zaman >= bas and (k.veri ->> 'miktar')::numeric >= v.hedef);
      else return exists (select 1 from oyun.icraat_kayit k where k.kod = v.kod and k.zaman >= bas);
    end case;
  elsif v.kapsam = 'mv' then
    return exists (select 1 from oyun.kanunlar k where k.durum = 'yururlukte' and k.sonuc_at >= bas
      and exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = v.user_id and o.oy = 'kabul')
      and case v.kod
            when 'vergi_tavan' then k.tur = 'butce' and (k.veri ->> 'vergi_ust')::numeric <= v.hedef
            when 'belediye_payi' then k.tur = 'butce' and (k.veri ->> 'belediye_payi')::numeric >= v.hedef
            when 'parti_yardim' then k.tur = 'butce' and (k.veri ->> 'parti_yardim')::numeric <= v.hedef
            when 'baraj' then k.tur = 'secim' and (k.veri ->> 'baraj')::numeric <= v.hedef
            else false end);
  elsif v.kapsam = 'bel' then
    select * into d from oyun.il_durum where il_id = v.il_id;
    case v.kod
      when 'kent_vergisi' then return d.kent_vergisi <= v.hedef;
      when 'hemsehri' then return d.hemsehri >= v.hedef;
      when 'altyapi', 'rayli' then
        return exists (select 1 from oyun.belediye_proje_kayit k where k.kod = v.kod and k.il_id = v.il_id and k.baskan = v.user_id and k.zaman >= bas);
      else return exists (select 1 from oyun.il_hizmet h where h.il_id = v.il_id and h.kod = v.kod);
    end case;
  elsif v.kapsam = 'gb' then
    if v.kod = 'aday_ucret' then
      return (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = v.parti_id) <= v.hedef;
    else
      return coalesce((select -sum(tutar) from oyun.parti_hareket where parti_id = v.parti_id and tur = 'destek' and zaman >= bas), 0) >= v.hedef;
    end if;
  end if;
  return false;
end $$;

create or replace function oyun.vaat_degerlendir(g date, t timestamptz) returns void language plpgsql as $$
declare v oyun.vaatler; m oyun.makamlar; tip text; bitti boolean; secim_bitti boolean;
begin
  -- 1) seçim sonuçlanınca: seçildiyse aktif, seçilmediyse kapanır
  for v in select * from oyun.vaatler where durum = 'bekliyor' loop
    m := null;
    if v.kapsam in ('mv','bel') then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.user_id = v.user_id and x.tur = v.kapsam and s.donem = v.donem and x.bit is null order by x.bas limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = v.kapsam and s.durum <> 'tamam');
    elsif v.kapsam = 'beyanname' then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.tur = 'cb' and x.parti_id = v.parti_id and s.donem = v.donem and x.bit is null limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur in ('cb','cb2') and s.durum <> 'tamam');
    else
      secim_bitti := exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = 'kurultay' and s.durum = 'tamam');
    end if;
    if m.id is not null then
      update oyun.vaatler set durum = 'aktif', makam_id = m.id, aktif_bas = m.bas where id = v.id;
    elsif v.kapsam = 'gb' and secim_bitti and exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id) then
      update oyun.vaatler set durum = 'aktif', aktif_bas = (select goreve_bas from oyun.secimler where donem = v.donem and tur = 'kurultay') where id = v.id;
    elsif secim_bitti then
      update oyun.vaatler set durum = 'secilmedi', bitis = t where id = v.id;
    end if;
  end loop;
  -- 2) görevdekilerin vaatleri her gün kontrol edilir
  for v in select * from oyun.vaatler where durum = 'aktif' loop
    bitti := case when v.kapsam = 'gb' then not exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id)
                  else exists (select 1 from oyun.makamlar where id = v.makam_id and bit is not null) end;
    if bitti then
      update oyun.vaatler set durum = 'bitti', bitis = coalesce((select bit from oyun.makamlar where id = v.makam_id), t) where id = v.id;
      continue;
    end if;
    select x.tip into tip from oyun.vaat_turleri x where x.kapsam = v.kapsam and x.kod = v.kod;
    if tip = 'tek' then
      if not v.tamam and oyun.vaat_kosul(v, t) then update oyun.vaatler set tamam = true where id = v.id; end if;
    else
      update oyun.vaatler set gun_toplam = gun_toplam + 1, gun_tutuldu = gun_tutuldu + case when oyun.vaat_kosul(v, t) then 1 else 0 end where id = v.id;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- VAAT GÖRÜNÜMLERİ
-- ---------------------------------------------------------------------
create or replace function oyun.vaat_json(v oyun.vaatler) returns jsonb language sql stable as $$
  select jsonb_build_object('id', v.id, 'kod', v.kod, 'ad', t.ad, 'hedef', v.hedef, 'birim', t.birim, 'tip', t.tip, 'yon', v.yon,
    'hedef_yazi', case when t.birim = 'yok' then null else oyun.birim_yaz(v.hedef, t.birim) end,
    'durum', v.durum, 'gun_toplam', v.gun_toplam, 'gun_tutuldu', v.gun_tutuldu, 'tamam', v.tamam,
    'tutuldu', case when t.tip = 'tek' then v.tamam else v.gun_toplam > 0 and v.gun_tutuldu * 2 >= v.gun_toplam end)
  from oyun.vaat_turleri t where t.kapsam = v.kapsam and t.kod = v.kod
$$;

-- Bir adayın o seçim grubundaki vaatleri
create or replace function oyun.aday_vaatleri(u uuid, p_secim bigint) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(oyun.vaat_json(v) order by v.id), '[]'::jsonb)
  from oyun.vaatler v, oyun.secimler s
  where s.id = p_secim and v.user_id = u and v.donem = s.donem and v.kapsam = oyun.vaat_grubu(s.tur)
$$;

create or replace function oyun.beyanname_json(p_parti bigint, p_donem text) returns jsonb language sql stable as $$
  with d as (select coalesce(p_donem, (select donem from oyun.secimler where tur = 'mv' and durum = 'bekliyor' order by oy_bas limit 1)) donem)
  select case when exists (select 1 from oyun.vaatler v, d where v.kapsam = 'beyanname' and v.parti_id = p_parti and v.donem = d.donem)
                or exists (select 1 from oyun.parti_beyanname b, d where b.parti_id = p_parti and b.donem = d.donem) then
    jsonb_build_object('donem', d.donem, 'metin', (select metin from oyun.parti_beyanname b where b.parti_id = p_parti and b.donem = d.donem),
      'vaatler', coalesce((select jsonb_agg(oyun.vaat_json(v) order by v.id) from oyun.vaatler v
                           where v.kapsam = 'beyanname' and v.parti_id = p_parti and v.donem = d.donem), '[]'::jsonb))
  end from d
$$;

-- İktidardaki partinin (cumhurbaşkanı bu partidense) yürürlükteki beyannamesi ve karnesi
create or replace function oyun.iktidar_karnesi(p_parti bigint) returns jsonb language sql stable as $$
  select case when count(*) > 0 then jsonb_build_object('vaatler', jsonb_agg(oyun.vaat_json(v) order by v.id),
           'tutulan', count(*) filter (where (oyun.vaat_json(v) ->> 'tutuldu')::boolean), 'toplam', count(*)) end
  from oyun.vaatler v where v.kapsam = 'beyanname' and v.parti_id = p_parti and v.durum = 'aktif'
$$;

create or replace function oyun.vaat_listesi_makam(p_makam bigint) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(oyun.vaat_json(v) order by v.id), '[]'::jsonb) from oyun.vaatler v where v.makam_id = p_makam
$$;

-- Oyuncunun görev dönemleri ve vaat karnesi
create or replace function oyun.karneler(u uuid) returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(x order by x ->> 'bas' desc), '[]'::jsonb) from (
    select jsonb_build_object('makam', case when v.kapsam = 'gb' then (select kisa from oyun.partiler where id = v.parti_id) || ' genel başkanlığı'
                                            else oyun.makam_ad(m.tur, m.il_id, m.bakanlik) end,
                              'bas', min(v.aktif_bas), 'bit', max(v.bitis), 'beyanname', bool_or(v.kapsam = 'beyanname'),
                              'vaatler', jsonb_agg(oyun.vaat_json(v) order by v.id),
                              'tutulan', count(*) filter (where (oyun.vaat_json(v) ->> 'tutuldu')::boolean), 'toplam', count(*)) x
    from oyun.vaatler v left join oyun.makamlar m on m.id = v.makam_id
    where v.durum in ('aktif','bitti') and (v.user_id = u or (v.kapsam = 'beyanname' and m.user_id = u))
    group by v.kapsam, v.donem, v.parti_id, m.tur, m.il_id, m.bakanlik
    order by min(v.aktif_bas) desc limit 8
  ) y
$$;

-- Aday kartı (02'deki tanımın yerine geçer): bildirge + ölçülebilir vaatler
create or replace function oyun.aday_json(p_aday_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object('aday_id', a.id, 'user_id', a.user_id, 'kad', coalesce(pr.kad, '(silinmiş)'),
                            'parti_id', a.parti_id, 'kisa', pa.kisa, 'renk', pa.renk, 'il_id', a.il_id, 'oy', coalesce(a.oy,0), 'sira', a.sira,
                            'vaat', a.vaat, 'vaatler', oyun.aday_vaatleri(a.user_id, a.secim_id))
  from oyun.adaylar a left join oyun.profiller pr on pr.id = a.user_id left join oyun.partiler pa on pa.id = a.parti_id
  where a.id = p_aday_id
$$;

-- Satın alma işlemcisi yalnızca sunucu fonksiyonundan (service_role) çağrılabilir
revoke all on function public.odeme_isle(jsonb) from public, anon, authenticated;
grant execute on function public.odeme_isle(jsonb) to service_role;
