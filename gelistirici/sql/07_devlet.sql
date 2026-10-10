-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 7) DEVLET: ülke ekonomisi, bakanlık
--  icraatları, kanun süreci, cumhurbaşkanı kararnameleri, ittifaklar,
--  Resmî Gazete.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.ulke(
  id          int primary key default 1 check (id = 1),
  hazine      numeric not null default 200,   -- milyar ₺
  vergi       numeric not null default 20,    -- yürürlükteki oran (%)
  vergi_kanun numeric not null default 20,    -- bütçe kanunundaki oran (%)
  buyume      numeric not null default 3,
  enflasyon   numeric not null default 35,
  issizlik    numeric not null default 9,
  memnuniyet  numeric not null default 50,    -- halkın hükümetten memnuniyeti (0-100)
  butce       jsonb not null default '{"adalet":7,"disisleri":5,"icisleri":9,"maliye":6,"savunma":12,"egitim":14,"saglik":13,"sanayi":7,"ticaret":5,"tarim":7,"ulastirma":9,"calisma":6}',
  bekleyen_baraj numeric,                     -- seçim döneminde kabul edilen baraj, seçimden sonra uygulanır
  son_gun     date
);
insert into oyun.ulke(id) values (1) on conflict do nothing;
-- Ekonomi politikaları (oyuncuların cüzdanına doğrudan yansır)
--   Yürütme (cumhurbaşkanı ve ilgili bakan): asgari, kidem_primi, destek, vergi (Meclis bandı içinde), tasinma_destek
--   Meclis (bütçe kanunu): vergi_alt / vergi_ust, belediye_payi, parti_yardim, bakanlık payları
alter table oyun.ulke add column if not exists asgari         numeric not null default 28075;  -- aylık net asgari ücret (₺), 2026
alter table oyun.ulke add column if not exists asgari_ref     numeric not null default 28075;  -- ekonominin enflasyonsuz kaldırabileceği ücret düzeyi
alter table oyun.ulke add column if not exists kidem_primi    numeric not null default 10;     -- statü basamağı başına maaş primi (%)
alter table oyun.ulke add column if not exists destek         numeric not null default 0;      -- yeni oyunculara günlük sosyal destek (₺)
alter table oyun.ulke add column if not exists tasinma_destek numeric not null default 0;      -- taşınma masrafına devlet desteği (%)
alter table oyun.ulke add column if not exists vergi_alt      numeric not null default 10;
alter table oyun.ulke add column if not exists vergi_ust      numeric not null default 35;
alter table oyun.ulke add column if not exists belediye_payi  numeric not null default 10;     -- vergi gelirlerinden belediyelere pay (%)
alter table oyun.ulke add column if not exists parti_yardim   numeric not null default 30000;  -- partilere günlük toplam hazine yardımı (₺)
alter table oyun.ulke add column if not exists endeks         numeric not null default 1;      -- fiyat düzeyi (başlangıç 1)
alter table oyun.ulke drop column if exists temel_gelir;
alter table oyun.ulke drop column if exists katsayi;
update oyun.ulke set asgari = 28075, asgari_ref = 28075 where asgari < 1000;

create table if not exists oyun.ulke_gecmis(
  gun date primary key,
  hazine numeric, vergi numeric, buyume numeric, enflasyon numeric, issizlik numeric, memnuniyet numeric
);

create table if not exists oyun.il_durum(
  il_id      smallint primary key references oyun.iller(id),
  gelisim    numeric not null default 50,      -- 0-100
  memnuniyet numeric not null default 50,      -- ildeki halkın belediyeden memnuniyeti (0-100)
  kasa       numeric                           -- belediye kasası (milyar ₺)
);
insert into oyun.il_durum(il_id) select id from oyun.iller on conflict do nothing;
alter table oyun.il_durum add column if not exists kent_vergisi numeric not null default 2;   -- belediye başkanının belirlediği kent vergisi (%)
alter table oyun.il_durum add column if not exists hemsehri     numeric not null default 0;   -- aktif her il sakinine günlük hemşehri desteği (₺)
alter table oyun.il_durum add column if not exists son_ayar     timestamptz;                  -- kent vergisi / destek son değişiklik
-- İlin günlük taban geliri: 0,02 + 0,004 × vekil sayısı (milyar ₺). Gerçek gelir: gelişmişlik, belediye payı ve kent vergisiyle çarpılır.
-- Başlangıç kasası 5 günlük taban gelir.
create or replace function oyun.il_gunluk_gelir(p_mv int) returns numeric language sql immutable as $$ select 0.02 + 0.004 * p_mv $$;
update oyun.il_durum d set kasa = 5 * oyun.il_gunluk_gelir(i.mv) from oyun.iller i where i.id = d.il_id and d.kasa is null;

create table if not exists oyun.bakanlik_kasa(
  kod  text primary key references oyun.bakanliklar(kod),
  kasa numeric not null default 20             -- milyar ₺
);
insert into oyun.bakanlik_kasa(kod) select kod from oyun.bakanliklar on conflict do nothing;

create table if not exists oyun.icraatlar(
  kod          text primary key,
  bakanlik     text not null references oyun.bakanliklar(kod),
  ad           text not null,
  aciklama     text not null,
  maliyet      numeric not null,
  bekleme_saat int not null,
  il_gerekli   boolean not null default false,
  etki         jsonb not null                  -- buyume, enflasyon, issizlik, memnuniyet, hazine (ulusal) · gelisim (il)
);
-- Oyunculara doğrudan işleyen etkiler (oyuncu: [{tur, deger}], sure_gun gün sürer) ve özel tek seferlik işlemler (ozel)
alter table oyun.icraatlar add column if not exists oyuncu   jsonb not null default '[]';
alter table oyun.icraatlar add column if not exists sure_gun int;
alter table oyun.icraatlar add column if not exists ozel     text;
delete from oyun.icraatlar where kod not in ('adl_harc','adl_ifade','dis_zirve','dis_turizm','ic_nufus','ic_afad','mal_iade','mal_varlik',
  'sav_sanayi','sav_bedelli','egt_burs','egt_seferber','sag_ucretsiz','sag_hastane','san_osb','san_tesvik','tic_fiyat','tic_ihracat',
  'tar_market','tar_sulama','ula_toplu','ula_tren','cal_istihdam','cal_esnaf');
-- oyuncu etkileri: ucret (% maaş) · ucret_yeni (% maaş, yalnız ilk iki statü) · gecim (% geçim masrafı indirimi) · tasinma (% indirim)
--                  il_bekleme (gün) · yayin (+hak/gün) · kidem_x (kıdem puanı çarpanı, %)
insert into oyun.icraatlar(kod, bakanlik, ad, aciklama, maliyet, bekleme_saat, il_gerekli, etki, oyuncu, sure_gun, ozel) values
 ('adl_harc','adalet','Harç muafiyeti','Tapu, nüfus ve noter harçları kaldırılır: taşınma masrafı 7 gün boyunca yarıya iner.',3,168,false,'{"memnuniyet":0.5}','[{"tur":"tasinma","deger":50}]',7,null),
 ('adl_ifade','adalet','İfade özgürlüğü paketi','Propaganda kısıtlamaları gevşer: yayın yetkisi olan herkesin günlük yayın hakkı 7 gün boyunca 1 artar.',4,168,false,'{"memnuniyet":0.5}','[{"tur":"yayin","deger":1}]',7,null),
 ('dis_zirve','disisleri','Uluslararası yatırım zirvesi','Yabancı yatırımcı gelir: hazineye 15 milyar ₺ girer, tüm maaşlar 7 gün boyunca %5 artar.',8,168,false,'{"hazine":15,"buyume":0.2}','[{"tur":"ucret","deger":5}]',7,null),
 ('dis_turizm','disisleri','Turizm tanıtım kampanyası','Seçilen il dünyaya tanıtılır: il kalıcı olarak gelişir, o ilde maaşlar 14 gün boyunca %10 artar.',8,72,true,'{"gelisim":4}','[{"tur":"ucret","deger":10}]',14,null),
 ('ic_nufus','icisleri','Nüfus işlemlerinde kolaylık','Adres değişikliği hızlanır: il değiştirme bekleme süresi 7 gün boyunca 30 günden 7 güne iner.',2,168,false,'{}','[{"tur":"il_bekleme","deger":7}]',7,null),
 ('ic_afad','icisleri','AFAD afet yardımı','Seçilen ilde yaşayan her oyuncunun cüzdanına anında 3.000 ₺ afet yardımı yatar.',6,72,true,'{"memnuniyet":0.3}','[]',null,'il_yardim'),
 ('mal_iade','maliye','Vergi iadesi','Son 7 günde gelirlerinden kesilen verginin yarısı her oyuncuya geri ödenir.',4,168,false,'{"memnuniyet":1,"hazine":-6}','[]',null,'vergi_iade'),
 ('mal_varlik','maliye','Varlık barışı','Kayıt dışı servet kayda alınır: hazineye 25 milyar ₺ girer, enflasyon biraz artar. Yeni vaatlere mali alan açar.',1,168,false,'{"hazine":25,"enflasyon":0.5}','[]',null,null),
 ('sav_sanayi','savunma','Savunma sanayii yatırımı','Seçilen ile savunma fabrikası: o ilde maaşlar 14 gün boyunca %15 artar, il kalıcı olarak gelişir.',12,72,true,'{"gelisim":3,"issizlik":-0.2}','[{"tur":"ucret","deger":15}]',14,null),
 ('sav_bedelli','savunma','Bedelli askerlik düzenlemesi','Bedelli askerlik ücretiyle hazineye 20 milyar ₺ girer; halk memnuniyeti biraz düşer.',1,168,false,'{"hazine":20,"memnuniyet":-1}','[]',null,null),
 ('egt_burs','egitim','Gençlere burs ve staj programı','Yeni Gelen ve Vatandaş statüsündeki oyuncuların maaşı 7 gün boyunca %20 artar.',6,168,false,'{"memnuniyet":0.5}','[{"tur":"ucret_yeni","deger":20}]',7,null),
 ('egt_seferber','egitim','Hayat boyu öğrenme seferberliği','7 gün boyunca kazanılan kıdem puanı iki katına çıkar: herkes daha hızlı statü atlar.',5,168,false,'{"memnuniyet":0.5}','[{"tur":"kidem_x","deger":100}]',7,null),
 ('sag_ucretsiz','saglik','Ücretsiz sağlık hizmeti','Muayene ve ilaç katkı payları kaldırılır: herkesin geçim masrafı 7 gün boyunca %10 düşer.',6,168,false,'{"memnuniyet":1}','[{"tur":"gecim","deger":10}]',7,null),
 ('sag_hastane','saglik','Şehir hastanesi','Seçilen ile şehir hastanesi: il kalıcı olarak gelişir, o ilde geçim masrafı 14 gün boyunca %10 düşer.',15,72,true,'{"gelisim":5,"memnuniyet":0.5}','[{"tur":"gecim","deger":10}]',14,null),
 ('san_osb','sanayi','Organize sanayi bölgesi','Seçilen ile fabrikalar: o ilde maaşlar 14 gün boyunca %15 artar, il kalıcı olarak gelişir.',12,72,true,'{"gelisim":5,"issizlik":-0.3,"buyume":0.2}','[{"tur":"ucret","deger":15}]',14,null),
 ('san_tesvik','sanayi','Teknoloji teşvik paketi','Yerli teknoloji şirketlerine destek: tüm maaşlar 7 gün boyunca %5 artar, büyüme hızlanır.',8,168,false,'{"buyume":0.3}','[{"tur":"ucret","deger":5}]',7,null),
 ('tic_fiyat','ticaret','Fahiş fiyat denetimi','Market ve kira denetimleri: geçim masrafı 7 gün boyunca %10 düşer, enflasyon biraz geriler.',4,168,false,'{"enflasyon":-0.5}','[{"tur":"gecim","deger":10}]',7,null),
 ('tic_ihracat','ticaret','İhracat seferberliği','Döviz girişi artar: enflasyon 2 puan düşer, büyüme hızlanır. Fiyatlar kalıcı olarak yavaşlar.',8,168,false,'{"enflasyon":-2,"buyume":0.3}','[]',null,null),
 ('tar_market','tarim','Tarım Kredi indirim marketleri','Üreticiden tüketiciye ucuz gıda: geçim masrafı 7 gün boyunca %15 düşer.',6,168,false,'{"memnuniyet":0.5,"enflasyon":-0.3}','[{"tur":"gecim","deger":15}]',7,null),
 ('tar_sulama','tarim','Sulama ve kırsal kalkınma','Seçilen ilde baraj ve sulama: il kalıcı olarak gelişir, gıda ucuzlar (o ilde geçim 14 gün %5 düşer).',8,72,true,'{"gelisim":4,"buyume":0.1}','[{"tur":"gecim","deger":5}]',14,null),
 ('ula_toplu','ulastirma','Toplu taşımada indirim','Şehir içi ve şehirlerarası ulaşım ucuzlar: geçim masrafı %5, taşınma masrafı %30 düşer (7 gün).',6,168,false,'{"memnuniyet":0.5}','[{"tur":"gecim","deger":5},{"tur":"tasinma","deger":30}]',7,null),
 ('ula_tren','ulastirma','Hızlı tren hattı','Seçilen il hızlı tren ağına bağlanır: il kalıcı olarak gelişir, o ile/o ilden taşınmak 14 gün yarı fiyat.',20,72,true,'{"gelisim":8,"buyume":0.2}','[{"tur":"tasinma","deger":50}]',14,null),
 ('cal_istihdam','calisma','İstihdam paketi','İşverenlere prim desteği: tüm maaşlar 7 gün boyunca %10 artar.',10,168,false,'{"issizlik":-0.5}','[{"tur":"ucret","deger":10}]',7,null),
 ('cal_esnaf','calisma','Esnaf ve sanatkâra destek kredisi','Ucuz kredi: maaşlar %5 artar, geçim masrafı %5 düşer (7 gün).',6,168,false,'{"memnuniyet":0.5}','[{"tur":"ucret","deger":5},{"tur":"gecim","deger":5}]',7,null)
on conflict (kod) do update set bakanlik = excluded.bakanlik, ad = excluded.ad, aciklama = excluded.aciklama, maliyet = excluded.maliyet,
  bekleme_saat = excluded.bekleme_saat, il_gerekli = excluded.il_gerekli, etki = excluded.etki,
  oyuncu = excluded.oyuncu, sure_gun = excluded.sure_gun, ozel = excluded.ozel;

-- Süreli oyuncu etkileri (bakanlık icraatları). il_id null → tüm ülke.
create table if not exists oyun.etkiler(
  id         bigserial primary key,
  il_id      smallint references oyun.iller(id),
  tur        text not null,
  deger      numeric not null,
  bas        timestamptz not null,
  bit        timestamptz not null,
  kaynak_tur text not null,
  kaynak_kod text not null,
  kaynak_ad  text not null,
  user_id    uuid
);
create index if not exists etkiler_aktif on oyun.etkiler(tur, bit);

create table if not exists oyun.icraat_kayit(
  id     bigserial primary key,
  kod    text not null,
  bakan  uuid not null,
  il_id  smallint,
  zaman  timestamptz not null,
  maliyet numeric not null
);
create index if not exists icraat_kayit_kod on oyun.icraat_kayit(kod, zaman desc);

-- Resmî Gazete
create table if not exists oyun.gazete(
  id     bigserial primary key,
  zaman  timestamptz not null,
  tur    text not null check (tur in ('kanun','kararname','atama','icraat')),
  baslik text not null,
  metin  text,
  ref_id bigint
);
create index if not exists gazete_zaman on oyun.gazete(zaman desc);

create sequence if not exists oyun.kanun_no start 8001;
create sequence if not exists oyun.kararname_no start 1;

create table if not exists oyun.kanunlar(
  id          bigserial primary key,
  no          int,                                   -- yürürlüğe girince verilen kanun numarası
  tur         text not null,
  baslik      text not null,
  metin       text not null,
  veri        jsonb,
  teklif_eden uuid not null,
  teklif_parti bigint,
  durum       text not null default 'gorusmede'
              check (durum in ('gorusmede','oylamada','cb_onayinda','israr','yururlukte','ret','dustu','kaduk','geri_cekildi')),
  teklif_at   timestamptz not null,
  oy_bas      timestamptz not null,
  oy_bit      timestamptz not null,
  cb_bit      timestamptz,
  israr_bit   timestamptz,
  veto_gerekce text,
  sonuc_at    timestamptz,
  sonuc_metin text
);
create index if not exists kanunlar_durum on oyun.kanunlar(durum, teklif_at desc);

create table if not exists oyun.kanun_oylari(
  kanun_id bigint not null references oyun.kanunlar(id) on delete cascade,
  asama    text not null check (asama in ('ilk','israr')),
  vekil    uuid not null,
  parti_id bigint,
  oy       text not null check (oy in ('kabul','ret','cekimser')),
  zaman    timestamptz not null,
  primary key (kanun_id, asama, vekil)
);

create table if not exists oyun.kararnameler(
  id     bigserial primary key,
  no     int not null,
  tur    text not null,
  baslik text not null,
  metin  text,
  veri   jsonb,
  cb     uuid not null,
  zaman  timestamptz not null,
  durum  text not null default 'yururlukte' check (durum in ('yururlukte','iptal'))
);
-- kanunlar_tur_check ve kararnameler_tur_check en güncel listeleriyle 12_mevzuat.sql'de tanımlıdır
-- (kalıcılık kuralı: izin verilen değer listeleri yalnızca genişler; eski dosyalar dar listeyi geri kurmaz)

alter table oyun.ittifaklar add column if not exists kurucu_parti bigint;
create table if not exists oyun.ittifak_davetler(
  ittifak_id bigint not null references oyun.ittifaklar(id) on delete cascade,
  parti_id   bigint not null references oyun.partiler(id) on delete cascade,
  zaman      timestamptz not null,
  primary key (ittifak_id, parti_id)
);

-- ---------------------------------------------------------------------
-- YARDIMCILAR
-- ---------------------------------------------------------------------
-- Ülke çapındaki bir ödemenin kaç kişiye yapıldığı (bütçe maliyeti = kişi başı ₺ × kişi / 1e9 milyar ₺)
--   destek   : yeni oyunculara sosyal destek ≈ 8 milyon kişi
--   ikramiye : bayram ikramiyesi ≈ 16 milyon kişi
--   il_hane  : bir ildeki hemşehri desteği alan hane ≈ 5 milyon × ilin vekil payı
create or replace function oyun.nufus(p_kod text) returns numeric language sql immutable as $$
  select case p_kod when 'destek' then 8e6 when 'ikramiye' then 16e6 when 'il_hane' then 5e6 else 0 end
$$;
drop function if exists oyun.kur();

create or replace function oyun.sinir(x numeric, a numeric, b numeric) returns numeric language sql immutable as $$
  select greatest(a, least(b, x))
$$;

create or replace function oyun.gazete_ekle(p_tur text, p_baslik text, p_metin text, p_ref bigint, p_zaman timestamptz)
returns void language sql as $$
  insert into oyun.gazete(zaman, tur, baslik, metin, ref_id) values (p_zaman, p_tur, p_baslik, p_metin, p_ref)
$$;

create or replace function oyun.aktif_vekil(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv' and bit is null)
$$;

create or replace function oyun.dolu_sandalye() returns int language sql stable as $$
  select count(*)::int from oyun.makamlar where tur = 'mv' and bit is null
$$;

create or replace function oyun.aktif_cb() returns uuid language sql stable as $$
  select user_id from oyun.makamlar where tur = 'cb' and bit is null limit 1
$$;

-- Ulusal göstergelere etki uygula (icraat ve kararnameler)
create or replace function oyun.etki_uygula(e jsonb, p_il smallint) returns void language plpgsql as $$
begin
  update oyun.ulke set
    buyume     = oyun.sinir(buyume + coalesce((e->>'buyume')::numeric, 0), -10, 15),
    enflasyon  = oyun.sinir(enflasyon + coalesce((e->>'enflasyon')::numeric, 0), 0, 200),
    issizlik   = oyun.sinir(issizlik + coalesce((e->>'issizlik')::numeric, 0), 2, 40),
    memnuniyet = oyun.sinir(memnuniyet + coalesce((e->>'memnuniyet')::numeric, 0), 0, 100),
    hazine     = hazine + coalesce((e->>'hazine')::numeric, 0)
  where id = 1;
  if p_il is not null and e ? 'gelisim' then
    update oyun.il_durum set gelisim = oyun.sinir(gelisim + (e->>'gelisim')::numeric, 0, 100) where il_id = p_il;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- GÜNLÜK EKONOMİ (her gece, tick içinden)
-- ---------------------------------------------------------------------
-- Ülkenin günlük gelir-gider kalemleri (milyar ₺). Politikalar 85 milyonluk ülkeye uygulanır;
-- oyuncular bu ülkenin vatandaşlarıdır. Oyuncu sayısı bütçeyi değiştirmez.
--   gelir vergisi : asgari ücreti aşan kazançlardan (asgari ücret vergiden muaftır)
--   diğer gelirler: KDV, ÖTV, kurumlar vergisi — büyüme ve fiyat düzeyiyle artar
--   cari giderler : 10 × fiyat düzeyi, bütçe kanunundaki paylarla bakanlık kasalarına
--   belediye payı : illerin taban gelirinin yarısı × (belediye payı / %10)
--   sosyal destek : yeni oyunculara verilen günlük destek × 8 milyon kişi
create or replace function oyun.ulke_hesap(u oyun.ulke) returns jsonb language sql stable as $$
  with x as (select
      round(u.asgari / 30 * 0.6 * 25e6 * u.vergi / 100 / 1e9, 3) gv,
      round(9.5 * (1 + u.buyume / 50) * u.endeks, 3) diger,
      round(10 * u.endeks, 3) cari,
      round((select sum(oyun.il_gunluk_gelir(mv)) from oyun.iller) * 0.5 * u.belediye_payi / 10 * u.endeks, 3) bel,
      round(u.destek * 8e6 / 1e9, 3) destek)
  select jsonb_build_object('gelir_vergisi', gv, 'diger_gelir', diger, 'gelir', gv + diger,
                            'cari', cari, 'belediye', bel, 'destek', destek, 'gider', cari + bel + destek,
                            'denge', round(gv + diger - cari - bel - destek, 3)) from x
$$;

-- İlin günlük geliri (milyar ₺): taban × gelişmişlik × (öz gelir + kanundaki belediye payı) × (1 + kent vergisi / 10)
create or replace function oyun.il_gelir(p_il smallint) returns numeric language sql stable as $$
  select round(oyun.il_gunluk_gelir(i.mv) * u.endeks * (0.5 + d.gelisim / 100) * (0.5 + 0.5 * u.belediye_payi / 10) * (1 + d.kent_vergisi / 10), 4)
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$$;

create or replace function oyun.gunluk_ekonomi(t timestamptz) returns void language plpgsql as $$
declare u oyun.ulke; bugun date := (t at time zone 'Europe/Istanbul')::date; g date; h jsonb; hb numeric; he numeric; hi numeric; hm numeric; acik numeric; mk jsonb;
begin
  select * into u from oyun.ulke where id = 1 for update;
  if u.son_gun is null then
    update oyun.ulke set son_gun = bugun where id = 1;
    insert into oyun.ulke_gecmis values (bugun, u.hazine, u.vergi, u.buyume, u.enflasyon, u.issizlik, u.memnuniyet) on conflict do nothing;
    return;
  end if;
  if u.son_gun >= bugun then return; end if;
  g := greatest(u.son_gun + 1, bugun - 31);
  while g <= bugun loop
    h := oyun.ulke_hesap(u);
    u.hazine := u.hazine + (h ->> 'denge')::numeric;
    update oyun.bakanlik_kasa k set kasa = least(100, kasa + (h ->> 'cari')::numeric * coalesce((u.butce ->> k.kod)::numeric, 0) / 100);
    -- belediyeler: gelir girer, açık hizmetlerin ve hemşehri desteğinin günlük gideri düşer
    update oyun.ulke set endeks = u.endeks, belediye_payi = u.belediye_payi where id = 1;
    perform oyun.belediye_gunluk(t);
    -- göstergeler hedeflerine doğru kayar
    mk := oyun.mevzuat_makro();
    hb := 4 - (u.vergi - 20) * 0.15 - greatest(0, u.enflasyon - 30) * 0.03 + (mk ->> 'buyume')::numeric;
    u.buyume := u.buyume + (hb - u.buyume) * 0.05;
    acik := greatest(0, u.asgari / u.asgari_ref - 1);           -- ekonominin kaldıramadığı ücret artışı
    he := 25 + greatest(0, -u.hazine) * 0.05 + (u.buyume - 3) * 0.5 + acik * 40 + (u.kidem_primi - 10) * 0.15 + u.destek / 100 + (mk ->> 'enflasyon')::numeric;
    u.enflasyon := u.enflasyon + (he - u.enflasyon) * 0.03 + case when u.hazine < 0 then 0.2 else 0 end;
    hi := 12 - u.buyume * 0.8;
    u.issizlik := u.issizlik + (hi - u.issizlik) * 0.05;
    hm := oyun.sinir(50 - (u.enflasyon - 30) * 0.4 - (u.issizlik - 9) * 1.5 + (u.buyume - 3) * 2 - (u.vergi - 20) * 0.6 + (mk ->> 'memnuniyet')::numeric, 5, 95);
    u.memnuniyet := u.memnuniyet + (hm - u.memnuniyet) * 0.08;
    u.buyume := oyun.sinir(u.buyume, -10, 15); u.enflasyon := oyun.sinir(u.enflasyon, 0, 200);
    u.issizlik := oyun.sinir(u.issizlik, 2, 40); u.memnuniyet := oyun.sinir(u.memnuniyet, 0, 100);
    -- fiyat düzeyi enflasyonla, ücret kaldırma kapasitesi enflasyon + büyümeyle artar
    u.endeks := round(u.endeks * (1 + u.enflasyon / 36500), 6);
    u.asgari_ref := round(u.asgari_ref * (1 + (u.enflasyon + greatest(0, u.buyume)) / 36500), 2);
    update oyun.ulke set hazine = u.hazine, buyume = u.buyume, enflasyon = u.enflasyon, issizlik = u.issizlik, memnuniyet = u.memnuniyet,
      endeks = u.endeks, asgari_ref = u.asgari_ref where id = 1;
    perform oyun.gunluk_odemeler(g, t);
    perform oyun.mevzuat_gunluk(g, t);
    perform oyun.vaat_degerlendir(g, t);
    select * into u from oyun.ulke where id = 1;
    insert into oyun.ulke_gecmis values (g, round(u.hazine, 1), u.vergi, round(u.buyume, 2), round(u.enflasyon, 2), round(u.issizlik, 2), round(u.memnuniyet, 1))
      on conflict (gun) do update set hazine = excluded.hazine, vergi = excluded.vergi, buyume = excluded.buyume,
        enflasyon = excluded.enflasyon, issizlik = excluded.issizlik, memnuniyet = excluded.memnuniyet;
    g := g + 1;
  end loop;
  update oyun.ulke set son_gun = bugun where id = 1;
end $$;

-- ---------------------------------------------------------------------
-- BAKANLIK İCRAATLARI
-- ---------------------------------------------------------------------
create or replace function public.bakanlik_paneli() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; pay numeric;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bakan' and bit is null;
  if m.id is null then return null; end if;
  pay := coalesce(((select butce from oyun.ulke where id = 1) ->> m.bakanlik)::numeric, 0);
  return jsonb_build_object(
    'politikalar', oyun.politika_listesi(m.bakanlik, t),
    'kod', m.bakanlik, 'ad', (select ad from oyun.bakanliklar where kod = m.bakanlik),
    'kasa', round((select kasa from oyun.bakanlik_kasa where kod = m.bakanlik), 1),
    'gunluk', round(10 * pay / 100, 2), 'pay', pay,
    'icraatlar', (select jsonb_agg(jsonb_build_object('kod', i.kod, 'ad', i.ad, 'aciklama', i.aciklama, 'maliyet', i.maliyet,
                    'il_gerekli', i.il_gerekli, 'etki', i.etki, 'bekleme_saat', i.bekleme_saat,
                    'oyuncu', i.oyuncu, 'sure_gun', i.sure_gun, 'ozel', i.ozel,
                    'aktif_bit', (select max(e.bit) from oyun.etkiler e where e.kaynak_kod = i.kod and e.il_id is null and e.bit > t),
                    'hazir', (select max(k.zaman) + make_interval(hours => i.bekleme_saat) from oyun.icraat_kayit k where k.kod = i.kod))
                  order by i.maliyet) from oyun.icraatlar i where i.bakanlik = m.bakanlik));
end $$;

create or replace function public.icraat_yap(p_kod text, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.icraatlar; m oyun.makamlar; son timestamptz; v_kasa numeric; ilad text;
        bk text; n int; toplam numeric; ek text := ''; vekalet_mi boolean := false;
begin
  select * into i from oyun.icraatlar where kod = p_kod;
  if i.kod is null then raise exception 'İcraat bulunamadı.'; end if;
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bakan' and bit is null and bakanlik = i.bakanlik;
  vekalet_mi := m.id is null and oyun.bakanlik_vekili(p.id, i.bakanlik);     -- boş bakanlığa cumhurbaşkanı vekâlet eder
  if m.id is null and not vekalet_mi then raise exception 'Bu icraatı yalnızca ilgili bakan yapabilir; bakanlık boşsa cumhurbaşkanı vekâleten yapar.'; end if;
  if i.il_gerekli then
    select ad into ilad from oyun.iller where id = p_il;
    if ilad is null then raise exception 'Bir il seçmelisin.'; end if;
  else p_il := null; end if;
  select max(zaman) into son from oyun.icraat_kayit where kod = i.kod;
  if son is not null and son + make_interval(hours => i.bekleme_saat) > t then
    raise exception 'Bu icraat % tarihinden sonra tekrar yapılabilir.', to_char((son + make_interval(hours => i.bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  select k.kasa into v_kasa from oyun.bakanlik_kasa k where k.kod = i.bakanlik for update;
  if v_kasa < i.maliyet then raise exception 'Bakanlık kasasında yeterli ödenek yok (% milyar ₺ gerekli, kasada % var).', i.maliyet, round(v_kasa, 1); end if;
  update oyun.bakanlik_kasa set kasa = kasa - i.maliyet where kod = i.bakanlik;
  perform oyun.etki_uygula(i.etki, p_il::smallint);
  select ad into bk from oyun.bakanliklar where kod = i.bakanlik;
  -- oyunculara süreli etki
  perform oyun.etki_ekle(p_il::smallint, 'bakanlik', i.kod, bk || ' · ' || i.ad || coalesce(' (' || ilad || ')', ''), i.oyuncu, i.sure_gun, p.id, t);
  -- tek seferlik ödemeler
  if i.ozel = 'il_yardim' then
    insert into oyun.cuzdan(user_id, para, son_toplama) select id, (select baslangic_para from oyun.ayarlar where id = 1), t - interval '8 hours'
      from oyun.profiller where il_id = p_il on conflict do nothing;
    with h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select id, t, 3000, 'yardim', 'AFAD afet yardımı (' || ilad || ')' from oyun.profiller where il_id = p_il and not yasakli returning user_id)
    update oyun.cuzdan c set para = para + 3000 from h where c.user_id = h.user_id;
    get diagnostics n = row_count;
    ek := format(' %s oyuncuya 3.000''er ₺ ödendi.', n);
  elsif i.ozel = 'vergi_iade' then
    with v as (select user_id, round(sum(vergi) / 2) iade from oyun.hesap_hareket where vergi > 0 and zaman > t - interval '7 days' group by user_id),
         h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select user_id, t, iade, 'iade', 'Vergi iadesi (son 7 günün vergisinin yarısı)' from v where iade > 0 returning user_id, tutar)
    , c as (update oyun.cuzdan c set para = para + h.tutar from h where c.user_id = h.user_id returning h.tutar)
    select count(*), coalesce(sum(tutar), 0) into n, toplam from c;
    ek := format(' %s oyuncuya toplam %s ₺ iade edildi.', n, toplam);
  end if;
  insert into oyun.icraat_kayit(kod, bakan, il_id, zaman, maliyet) values (i.kod, p.id, p_il, t, i.maliyet);
  perform oyun.gazete_ekle('icraat', i.ad || coalesce(' — ' || ilad, ''),
    format('%s %s tarafından başlatıldı. %s Maliyet: %s milyar ₺.%s', case when vekalet_mi then bk || ' vekâleten Cumhurbaşkanı' else replace(bk, 'Bakanlığı', 'Bakanı') end, p.kad, i.aciklama, i.maliyet, ek), null, t);
  perform oyun.olay('icraat', format('%s: %s%s.', case when vekalet_mi then 'Cumhurbaşkanı ' || p.kad || ' (' || bk || ' vekâleten)' else (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = i.bakanlik) || ' ' || p.kad end, i.ad, coalesce(' (' || ilad || ')', '')), p_il::smallint, p.parti_id, t);
  return public.bakanlik_paneli();
end $$;

-- ---------------------------------------------------------------------
-- ÜLKE KARNESİ
-- ---------------------------------------------------------------------
create or replace function public.ulke_karnesi() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.ulke; e oyun.ulke_gecmis;
begin
  select * into u from oyun.ulke where id = 1;
  select * into e from oyun.ulke_gecmis where gun <= (t at time zone 'Europe/Istanbul')::date - 7 order by gun desc limit 1;
  return jsonb_build_object(
    'hazine', round(u.hazine, 1), 'vergi', u.vergi, 'vergi_alt', u.vergi_alt, 'vergi_ust', u.vergi_ust,
    'buyume', round(u.buyume, 2), 'enflasyon', round(u.enflasyon, 1), 'issizlik', round(u.issizlik, 1), 'memnuniyet', round(u.memnuniyet, 1),
    'baraj', (select baraj from oyun.ayarlar where id = 1), 'bekleyen_baraj', u.bekleyen_baraj,
    'kararname_sinir', oyun.anayasa_deger('kararname_sinir'), 'vergi_tavani', oyun.anayasa_deger('vergi_tavani'),
    'asgari', u.asgari, 'asgari_ref', round(u.asgari_ref), 'kidem_primi', u.kidem_primi, 'destek', u.destek, 'tasinma_destek', u.tasinma_destek,
    'belediye_payi', u.belediye_payi, 'parti_yardim', u.parti_yardim, 'endeks', round(u.endeks, 3),
    'hesap', oyun.ulke_hesap(u), 'mali_alan', oyun.mali_alan(),
    'makam_maaslari', (select jsonb_object_agg(k, round(oyun.makam_maasi(k, null))) from unnest(array['cb','bakan','mv']) k),
    'cb_mi', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null),
    'politikalar', oyun.politika_listesi(null, t),
    'aktif_oyuncu', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '7 days'),
    'ulusal_etkiler', coalesce((select jsonb_agg(jsonb_build_object('kaynak', x.kaynak_ad, 'bit', x.bit, 'etkiler', x.e) order by x.bit)
        from (select kaynak_ad, max(bit) bit, jsonb_agg(jsonb_build_object('tur', tur, 'deger', deger)) e from oyun.etkiler
              where il_id is null and bas <= t and bit > t group by kaynak_ad) x), '[]'::jsonb),
    'once', case when e.gun is null then null else to_jsonb(e) end,
    'gecmis', coalesce((select jsonb_agg(to_jsonb(x) order by x.gun) from (select * from oyun.ulke_gecmis order by gun desc limit 30) x), '[]'::jsonb),
    'butce', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'pay', coalesce((u.butce ->> b.kod)::numeric, 0),
                 'kasa', round(k.kasa, 1)) order by b.sira) from oyun.bakanliklar b join oyun.bakanlik_kasa k on k.kod = b.kod),
    'iller', (select jsonb_agg(jsonb_build_object('id', d.il_id, 'ad', i.ad, 'gelisim', round(d.gelisim, 1)) order by d.gelisim desc)
              from oyun.il_durum d join oyun.iller i on i.id = d.il_id));
end $$;

create or replace function public.gazete(p_limit int default 50) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'zaman', g.zaman, 'tur', g.tur, 'baslik', g.baslik, 'metin', g.metin, 'ref_id', g.ref_id)
         order by g.zaman desc, g.id desc), '[]'::jsonb)
  from (select * from oyun.gazete where zaman <= oyun.simdi() order by zaman desc, id desc limit least(greatest(p_limit, 1), 100)) g
$$;

-- ---------------------------------------------------------------------
-- CUMHURBAŞKANLIĞI KARARNAMELERİ (günde en fazla 3)
--   serbest   : metin olarak yayımlanır
--   il_destek : hazineden bir ile 1-30 milyar ₺ kalkınma desteği → il gelişmişliği ve memnuniyet
--   odenek    : hazineden bir bakanlığın kasasına 1-30 milyar ₺ ek ödenek
--   ikramiye  : bayram ikramiyesi — son 7 günde oyuna giren her oyuncuya 500-5.000 ₺ (7 günde bir)
--               bütçe maliyeti: tutar × 16 milyon kişi
-- Ekonomi ayarları (vergi, asgari ücret, kıdem primi, sosyal destek, taşınma desteği) politika_ayarla ile yapılır.
-- ---------------------------------------------------------------------
create or replace function public.kararname_cikar(p_tur text, p_baslik text, p_metin text, p_veri jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); n int; miktar numeric; il_ad text; bk text; yeni bigint; v_no int; b text; m text; maliyet numeric;
        sinir int := coalesce(oyun.anayasa_deger('kararname_sinir'), 3)::int; dt record; eng text; deger numeric; faiz numeric; u oyun.ulke;
begin
  perform oyun.cb_zorunlu(p);
  if sinir = 0 then raise exception 'Anayasa cumhurbaşkanının kararname yetkisini kaldırdı.'; end if;
  if (select count(*) from oyun.kararnameler k where k.cb = p.id and k.zaman >= oyun.bugun_bas(t)) >= sinir then
    raise exception 'Bugün en fazla % kararname çıkarabilirsin (anayasal sınır).', sinir;
  end if;
  m := nullif(btrim(coalesce(p_metin, '')), '');
  if m is not null then m := oyun.metin_temizle(m, 3000); end if;
  if p_tur = 'serbest' then
    b := btrim(coalesce(p_baslik, ''));
    if length(b) < 5 or length(b) > 120 then raise exception 'Başlık 5-120 karakter olmalı.'; end if;
    if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
    if m is null then raise exception 'Kararname metni boş olamaz.'; end if;
  elsif p_tur = 'il_destek' then
    miktar := (p_veri ->> 'miktar')::numeric;
    select ad into il_ad from oyun.iller where id = (p_veri ->> 'il_id')::int;
    if il_ad is null then raise exception 'Geçersiz il.'; end if;
    if miktar is null or miktar < 1 or miktar > 30 then raise exception 'Destek miktarı 1-30 milyar ₺ olmalı.'; end if;
    b := format('%s İline %s Milyar ₺ Kalkınma Desteği Hakkında Karar', il_ad, miktar);
    update oyun.ulke set hazine = hazine - miktar where id = 1;
    perform oyun.etki_uygula(jsonb_build_object('gelisim', miktar * 0.4, 'memnuniyet', miktar * 0.03), (p_veri ->> 'il_id')::smallint);
  elsif p_tur = 'odenek' then
    miktar := (p_veri ->> 'miktar')::numeric;
    select ad into bk from oyun.bakanliklar where kod = p_veri ->> 'bakanlik';
    if bk is null then raise exception 'Geçersiz bakanlık.'; end if;
    if miktar is null or miktar < 1 or miktar > 30 then raise exception 'Ödenek 1-30 milyar ₺ olmalı.'; end if;
    b := format('%s''na %s Milyar ₺ Ek Ödenek Hakkında Karar', bk, miktar);
    update oyun.ulke set hazine = hazine - miktar where id = 1;
    update oyun.bakanlik_kasa set kasa = kasa + miktar where kod = p_veri ->> 'bakanlik';
  elsif p_tur = 'ikramiye' then
    miktar := round((p_veri ->> 'miktar')::numeric);
    if miktar is null or miktar < 500 or miktar > 5000 then raise exception 'İkramiye kişi başı 500-5.000 ₺ arasında olmalı.'; end if;
    if exists (select 1 from oyun.kararnameler where tur = 'ikramiye' and durum = 'yururlukte' and zaman > t - interval '7 days') then
      raise exception 'Bayram ikramiyesi 7 günde bir verilebilir.';
    end if;
    maliyet := round(miktar * oyun.nufus('ikramiye') / 1e9, 2);
    insert into oyun.cuzdan(user_id, para, son_toplama) select id, (select baslangic_para from oyun.ayarlar where id = 1), t - interval '8 hours'
      from oyun.profiller on conflict do nothing;
    with h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select id, t, miktar, 'ikramiye', 'Bayram ikramiyesi (Cumhurbaşkanlığı kararı)' from oyun.profiller
               where not yasakli and son_gorulme > t - interval '7 days' returning user_id)
    update oyun.cuzdan c set para = para + miktar from h where c.user_id = h.user_id;
    get diagnostics n = row_count;
    update oyun.ulke set hazine = hazine - maliyet where id = 1;
    b := format('Kişi Başı %s ₺ Bayram İkramiyesi Ödenmesi Hakkında Karar', to_char(miktar, 'FM999G999'));
    p_veri := jsonb_build_object('miktar', miktar, 'kisi', n, 'maliyet', maliyet);
  elsif p_tur = 'duzenleme' then
    -- Oyuncuları etkileyen kural (mevzuat): kanunla ya da anayasayla düzenlenmiş konuda kararname çıkarılamaz
    select * into dt from oyun.duzenleme_tanim where kod = p_veri ->> 'kod' and kapsam = 'ulke';
    if dt.kod is null then raise exception 'Geçersiz düzenleme.'; end if;
    eng := oyun.duzenleme_engel(dt.kod, 'kararname');
    if eng is not null then raise exception '%', eng; end if;
    deger := oyun.duzenleme_dogrula(dt.kod, (p_veri ->> 'deger')::numeric, 'ulke');
    if deger = oyun.duz(dt.kod) then raise exception 'Bu kural zaten bu değerde.'; end if;
    if exists (select 1 from oyun.duzenlemeler where kod = dt.kod and kaynak = 'kararname' and zaman > t - interval '24 hours') then
      raise exception 'Aynı kural 24 saatte bir değiştirilebilir.';
    end if;
    p_veri := jsonb_build_object('kod', dt.kod, 'deger', deger,
      'onceki', jsonb_build_object('deger', oyun.duz(dt.kod), 'kaynak', (select kaynak from oyun.duzenlemeler where kod = dt.kod),
                                   'ref_id', (select ref_id from oyun.duzenlemeler where kod = dt.kod)));
    b := format('%s Hakkında Karar (%s)', dt.ad, oyun.duz_yaz(dt.kod, deger));
  elsif p_tur = 'ozellestirme' then
    -- Kamu varlığı satışı: hazineye tek seferlik gelir; işsizlik artar, memnuniyet düşer
    miktar := round((p_veri ->> 'miktar')::numeric);
    if miktar is null or miktar < 10 or miktar > 100 then raise exception 'Özelleştirme 10-100 milyar ₺ arasında olmalı.'; end if;
    if miktar > (select kamu_varlik from oyun.ulke where id = 1) then raise exception 'Satılabilecek kamu varlığı kalmadı (kalan % milyar ₺).', round((select kamu_varlik from oyun.ulke where id = 1), 1); end if;
    if exists (select 1 from oyun.kararnameler where tur = 'ozellestirme' and durum = 'yururlukte' and zaman > t - interval '7 days') then
      raise exception 'Özelleştirme 7 günde bir yapılabilir.';
    end if;
    update oyun.ulke set kamu_varlik = kamu_varlik - miktar where id = 1;
    perform oyun.etki_uygula(jsonb_build_object('hazine', miktar, 'issizlik', miktar / 50.0, 'memnuniyet', -miktar / 25.0, 'buyume', miktar / 200.0), null);
    b := format('%s Milyar ₺ Değerinde Kamu Varlığının Özelleştirilmesi Hakkında Karar', miktar);
    p_veri := jsonb_build_object('miktar', miktar);
  elsif p_tur = 'tahvil' then
    -- Borçlanma: para bugün girer, 60 günde faiziyle geri ödenir (faiz enflasyona bağlı)
    miktar := round((p_veri ->> 'miktar')::numeric);
    if miktar is null or miktar < 10 or miktar > 100 then raise exception 'Tahvil ihracı 10-100 milyar ₺ arasında olmalı.'; end if;
    if coalesce((select sum(gunluk * kalan_gun) from oyun.borclar where kalan_gun > 0), 0) + miktar > 300 then
      raise exception 'Toplam borç stoku 300 milyar ₺''yi aşamaz.';
    end if;
    faiz := oyun.tahvil_faiz();
    perform oyun.etki_uygula(jsonb_build_object('hazine', miktar), null);
    b := format('%s Milyar ₺ Devlet İç Borçlanma Senedi (Tahvil) İhracı Hakkında Karar (faiz %%%s, 60 gün)', miktar, faiz);
    p_veri := jsonb_build_object('miktar', miktar, 'faiz', faiz);
  else
    raise exception 'Geçersiz kararname türü.';
  end if;
  v_no := nextval('oyun.kararname_no');
  insert into oyun.kararnameler(no, tur, baslik, metin, veri, cb, zaman) values (v_no, p_tur, b, m, p_veri, p.id, t) returning id into yeni;
  if p_tur = 'duzenleme' then
    perform oyun.duzenleme_uygula(p_veri ->> 'kod', (p_veri ->> 'deger')::numeric, 'kararname', yeni, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('Cumhurbaşkanlığı kararı: %s artık %s. %s', dt.ad, oyun.duz_yaz(dt.kod, deger), dt.oyuncu)
      from oyun.profiller x where not x.yasakli and x.id <> p.id and x.son_gorulme > t - interval '7 days';
  elsif p_tur = 'tahvil' then
    insert into oyun.borclar(kararname_id, anapara, faiz, gunluk, kalan_gun, zaman)
    values (yeni, miktar, faiz, round(miktar * (1 + faiz / 100) / 60, 4), 60, t);
  end if;
  perform oyun.gazete_ekle('kararname', format('%s sayılı Cumhurbaşkanlığı Kararı: %s', v_no, b), m, yeni, t);
  perform oyun.olay('kararname', format('Cumhurbaşkanı %s, %s sayılı kararı imzaladı: %s', p.kad, v_no, b), null, p.parti_id, t);
  return jsonb_build_object('tamam', true, 'no', v_no, 'baslik', b, 'veri', p_veri);
end $$;

create or replace function public.kararnameler(p_limit int default 30) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'no', k.no, 'tur', k.tur, 'baslik', k.baslik, 'metin', k.metin,
           'cb', oyun.kad(k.cb), 'zaman', k.zaman, 'durum', k.durum) order by k.zaman desc, k.no desc), '[]'::jsonb)
  from (select * from oyun.kararnameler order by zaman desc limit least(greatest(p_limit, 1), 100)) k
$$;

-- ---------------------------------------------------------------------
-- KANUN SÜRECİ
--   Teklif (yalnız milletvekili) → 24 saat görüşme → 24 saat oylama
--   Kabul: katılım ≥ dolu sandalyelerin 1/3'ü, kabul > ret ve kabul ≥ dolu/4 + 1
--   → Cumhurbaşkanı 48 saatte onaylar veya veto eder; karar vermezse yürürlüğe girer
--   → Veto edilirse 24 saat ısrar oylaması: dolu sandalyelerin salt çoğunluğu (yarısından fazlası) gerekir
--   Yeni Meclis göreve başlayınca görüşme/oylama/ısrar aşamasındaki teklifler kadük olur.
-- ---------------------------------------------------------------------
create or replace function oyun.kanun_suresi() returns table(gorusme interval, oylama interval, cb interval) language sql immutable as $$
  select interval '24 hours', interval '24 hours', interval '48 hours'
$$;

create or replace function public.kanun_teklif(p_tur text, p_baslik text, p_metin text, p_veri jsonb default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b text; m text; v jsonb; top numeric; k text; yeni bigint; s record; pay numeric;
begin
  if not oyun.aktif_vekil(p.id) then raise exception 'Kanun teklifini yalnızca milletvekilleri verebilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then
    raise exception 'Meclis Başkanı kanun teklifi veremez; tarafsız kalmalıdır.';
  end if;
  if exists (select 1 from oyun.kanunlar where teklif_eden = p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
    raise exception 'Sonuçlanmamış bir teklifin varken yeni teklif veremezsin.';
  end if;
  b := btrim(coalesce(p_baslik, ''));
  if length(b) < 5 or length(b) > 120 then raise exception 'Kanun başlığı 5-120 karakter olmalı.'; end if;
  if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
  m := oyun.metin_temizle(p_metin, 3000);
  if length(m) < 10 then raise exception 'Gerekçe en az 10 karakter olmalı.'; end if;
  if p_tur = 'serbest' then v := null;
  elsif p_tur = 'butce' then
    -- Bütçe kanunu: gelir vergisi bandı (yürütme bu bant içinde ayarlar), belediye payı, partilere hazine yardımı, bakanlık payları.
    -- Verilmeyen alan yürürlükteki değerinde kalır.
    select jsonb_build_object('vergi_alt', round(coalesce((p_veri ->> 'vergi_alt')::numeric, u.vergi_alt), 1),
                              'vergi_ust', round(coalesce((p_veri ->> 'vergi_ust')::numeric, u.vergi_ust), 1),
                              'belediye_payi', round(coalesce((p_veri ->> 'belediye_payi')::numeric, u.belediye_payi), 1),
                              'parti_yardim', round(coalesce((p_veri ->> 'parti_yardim')::numeric, u.parti_yardim)),
                              'paylar', '{}'::jsonb)
      into v from oyun.ulke u where u.id = 1;
    if (v ->> 'vergi_alt')::numeric < 0 or (v ->> 'vergi_ust')::numeric > 45 or (v ->> 'vergi_alt')::numeric > (v ->> 'vergi_ust')::numeric then
      raise exception 'Vergi bandı %%0-%%45 arasında olmalı ve taban tavandan büyük olamaz.';
    end if;
    if (v ->> 'belediye_payi')::numeric not between 2 and 30 then raise exception 'Belediye payı %%2-%%30 arasında olmalı.'; end if;
    if (v ->> 'parti_yardim')::numeric not between 0 and 200000 then raise exception 'Partilere hazine yardımı günlük 0-200.000 ₺ arasında olmalı.'; end if;
    top := 0;
    for k in select kod from oyun.bakanliklar loop
      pay := coalesce((p_veri -> 'paylar' ->> k)::numeric, ((select butce from oyun.ulke where id = 1) ->> k)::numeric, 0);
      if pay < 0 or pay > 60 then raise exception 'Her bakanlığın payı 0-60 arasında olmalı (%).', k; end if;
      top := top + pay;
      v := jsonb_set(v, array['paylar', k], to_jsonb(round(pay, 1)));
    end loop;
    if abs(top - 100) > 0.5 then raise exception 'Bakanlık paylarının toplamı 100 olmalı (şu an %).', round(top, 1); end if;
  elsif p_tur = 'secim' then
    if (p_veri ->> 'baraj') is null or (p_veri ->> 'baraj')::numeric not between 0 and 10 then raise exception 'Baraj %%0-%%10 arasında olmalı.'; end if;
    v := jsonb_build_object('baraj', round((p_veri ->> 'baraj')::numeric, 1));
  elsif p_tur = 'iptal' then
    if not exists (select 1 from oyun.kararnameler where id = (p_veri ->> 'kararname_id')::bigint and durum = 'yururlukte') then
      raise exception 'İptal edilecek yürürlükte bir kararname seçmelisin.';
    end if;
    v := jsonb_build_object('kararname_id', (p_veri ->> 'kararname_id')::bigint);
  elsif p_tur = 'duzenleme' then
    if oyun.duzenleme_engel(p_veri ->> 'kod', 'kanun') is not null then raise exception '%', oyun.duzenleme_engel(p_veri ->> 'kod', 'kanun'); end if;
    v := jsonb_build_object('kod', p_veri ->> 'kod', 'deger', oyun.duzenleme_dogrula(p_veri ->> 'kod', (p_veri ->> 'deger')::numeric, 'ulke'));
    if (v ->> 'deger')::numeric = oyun.duz(v ->> 'kod') and (select kaynak from oyun.duzenlemeler where kod = v ->> 'kod') = 'kanun' then
      raise exception 'Bu kural zaten kanunla bu değerde.';
    end if;
  elsif p_tur = 'anayasa' then
    v := oyun.anayasa_dogrula(p_veri);
  else raise exception 'Geçersiz kanun türü.'; end if;
  if p_tur = 'butce' and (v ->> 'vergi_ust')::numeric > oyun.anayasa_deger('vergi_tavani') then
    raise exception 'Anayasa gelir vergisinin tavanını %%% olarak belirlemiştir; vergi bandı bunun üstüne çıkamaz.', oyun.anayasa_deger('vergi_tavani');
  end if;
  select * into s from oyun.kanun_suresi();
  insert into oyun.kanunlar(tur, baslik, metin, veri, teklif_eden, teklif_parti, teklif_at, oy_bas, oy_bit)
  values (p_tur, b, m, v, p.id, p.parti_id, t, t + s.gorusme, t + s.gorusme + s.oylama) returning id into yeni;
  if p_tur = 'anayasa' then
    insert into oyun.kanun_oylari(kanun_id, asama, vekil, parti_id, oy, zaman) values (yeni, 'imza', p.id, p.parti_id, 'kabul', t);
  end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select m2.user_id, t, case when p_tur = 'anayasa'
             then format('Anayasa değişikliği teklifi: "%s" (%s). Oylamaya geçmesi için vekillerin üçte biri %s''a kadar imza vermeli.', b, p.kad, to_char((t + s.gorusme) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'))
             else format('Yeni kanun teklifi: "%s" (%s). Oylama %s''da başlıyor.', b, p.kad, to_char((t + s.gorusme) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')) end
    from oyun.makamlar m2 where m2.tur = 'mv' and m2.bit is null and m2.user_id <> p.id;
  perform oyun.olay('meclis', format('%s Meclis''e kanun teklifi verdi: %s', p.kad, b), null, p.parti_id, t);
  return jsonb_build_object('id', yeni);
end $$;

create or replace function public.kanun_geri_cek(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  update oyun.kanunlar set durum = 'geri_cekildi', sonuc_at = t, sonuc_metin = 'Teklif sahibi geri çekti.'
  where id = p_id and teklif_eden = p.id and durum = 'gorusmede';
  if not found then raise exception 'Yalnızca görüşme aşamasındaki kendi teklifini geri çekebilirsin.'; end if;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.kanun_oy(p_id bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; a text;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri oy kullanabilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then
    raise exception 'Meclis Başkanı Genel Kurul''da oy kullanamaz (Anayasa md. 94).';
  end if;
  select * into k from oyun.kanunlar where id = p_id;
  if k.durum = 'oylamada' and t >= k.oy_bas and t < k.oy_bit then a := 'ilk';
  elsif k.durum = 'israr' and t < k.israr_bit then a := 'israr';
  else raise exception 'Bu teklif şu anda oylamada değil.'; end if;
  insert into oyun.kanun_oylari(kanun_id, asama, vekil, parti_id, oy, zaman) values (k.id, a, p.id, p.parti_id, p_oy, t)
  on conflict (kanun_id, asama, vekil) do update set oy = excluded.oy, zaman = excluded.zaman, parti_id = excluded.parti_id;
  return public.kanun_detay(p_id);
end $$;

create or replace function public.kanun_cb_karar(p_id bigint, p_karar text, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; s record;
begin
  perform oyun.cb_zorunlu(p);
  select * into k from oyun.kanunlar where id = p_id for update;
  if k.durum <> 'cb_onayinda' or t >= k.cb_bit then raise exception 'Bu kanun onayınızı beklemiyor.'; end if;
  if k.tur = 'anayasa' then
    if p_karar = 'onay' then
      perform oyun.kanun_yururluk(k.id, t, format('Meclis''te üçte iki çoğunlukla kabul edildi; Cumhurbaşkanı %s yayımladı.', p.kad));
    elsif p_karar = 'halkoyu' then
      perform oyun.referandum_baslat(k.id, t);
      perform oyun.olay('referandum', format('Cumhurbaşkanı %s, "%s" anayasa değişikliğini halkoyuna sundu.', p.kad, k.baslik), null, p.parti_id, t);
    else raise exception 'Anayasa değişikliği veto edilemez; yayımlayabilir ya da halkoyuna sunabilirsin.'; end if;
    return public.kanun_detay(p_id);
  end if;
  if p_karar = 'onay' then
    perform oyun.kanun_yururluk(k.id, t, format('Cumhurbaşkanı %s tarafından onaylandı.', p.kad));
  elsif p_karar = 'veto' then
    if coalesce(btrim(p_gerekce), '') = '' then raise exception 'Veto için gerekçe yazmalısın.'; end if;
    select * into s from oyun.kanun_suresi();
    update oyun.kanunlar set durum = 'israr', israr_bit = t + s.oylama, veto_gerekce = oyun.metin_temizle(p_gerekce, 1000) where id = k.id;
    perform oyun.bildir(k.teklif_eden, format('Cumhurbaşkanı "%s" kanununu veto etti. Meclis 24 saat içinde salt çoğunlukla ısrar edebilir.', k.baslik), t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select m.user_id, t, format('Veto: "%s" Meclis''e iade edildi. Israr oylaması 24 saat sürecek.', k.baslik)
      from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.user_id <> k.teklif_eden;
    perform oyun.olay('meclis', format('Cumhurbaşkanı %s, "%s" kanununu veto ederek Meclis''e iade etti.', p.kad, k.baslik), null, p.parti_id, t);
  else raise exception 'Geçersiz karar.'; end if;
  return public.kanun_detay(p_id);
end $$;

-- Kanunun yürürlüğe girmesi ve etkileri
create or replace function oyun.kanun_yururluk(p_id bigint, t timestamptz, p_not text) returns void language plpgsql as $$
declare k oyun.kanunlar; v_no int; kr oyun.kararnameler; pencere boolean;
begin
  select * into k from oyun.kanunlar where id = p_id for update;
  v_no := nextval('oyun.kanun_no');
  update oyun.kanunlar set durum = 'yururlukte', no = v_no, sonuc_at = t, sonuc_metin = p_not where id = k.id;
  if k.tur = 'butce' then
    update oyun.kanunlar set veri = veri || jsonb_build_object('onceki',
      (select jsonb_build_object('vergi_alt', vergi_alt, 'vergi_ust', vergi_ust, 'belediye_payi', belediye_payi, 'parti_yardim', parti_yardim, 'vergi', vergi) from oyun.ulke where id = 1))
    where id = k.id;
    update oyun.ulke set vergi_alt = (k.veri ->> 'vergi_alt')::numeric, vergi_ust = (k.veri ->> 'vergi_ust')::numeric,
      vergi = oyun.sinir(vergi, (k.veri ->> 'vergi_alt')::numeric, (k.veri ->> 'vergi_ust')::numeric),
      belediye_payi = (k.veri ->> 'belediye_payi')::numeric, parti_yardim = (k.veri ->> 'parti_yardim')::numeric,
      butce = k.veri -> 'paylar' where id = 1;
  elsif k.tur = 'secim' then
    -- seçim döneminde kabul edilen baraj o seçime uygulanmaz
    select exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                   where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor') into pencere;
    if pencere then update oyun.ulke set bekleyen_baraj = (k.veri ->> 'baraj')::numeric where id = 1;
    else update oyun.ayarlar set baraj = (k.veri ->> 'baraj')::numeric where id = 1; end if;
  elsif k.tur = 'iptal' then
    update oyun.kararnameler set durum = 'iptal' where id = (k.veri ->> 'kararname_id')::bigint returning * into kr;
    if kr.tur = 'vergi' and not exists (select 1 from oyun.kararnameler where tur = 'vergi' and durum = 'yururlukte' and zaman > kr.zaman) then
      update oyun.ulke set vergi = vergi_kanun where id = 1;
    end if;
    -- iptal edilen kararname hâlâ yürürlükteki kuralı belirliyorsa kural bir önceki hâline döner
    if kr.tur = 'duzenleme' and exists (select 1 from oyun.duzenlemeler where kod = kr.veri ->> 'kod' and kaynak = 'kararname' and ref_id = kr.id) then
      if kr.veri -> 'onceki' ->> 'kaynak' is null then delete from oyun.duzenlemeler where kod = kr.veri ->> 'kod';
      else update oyun.duzenlemeler set deger = (kr.veri -> 'onceki' ->> 'deger')::numeric, kaynak = kr.veri -> 'onceki' ->> 'kaynak',
             ref_id = (kr.veri -> 'onceki' ->> 'ref_id')::bigint, zaman = t where kod = kr.veri ->> 'kod'; end if;
    end if;
  elsif k.tur = 'duzenleme' then
    if not oyun.duzenleme_uygula(k.veri ->> 'kod', (k.veri ->> 'deger')::numeric, 'kanun', k.id, t) then
      update oyun.kanunlar set sonuc_metin = p_not || ' Ancak kural bu arada anayasaya bağlandığı için uygulanamadı.' where id = k.id;
    end if;
  elsif k.tur = 'anayasa' then
    perform oyun.anayasa_uygula(k, t);
  end if;
  perform oyun.gazete_ekle(case when k.tur = 'anayasa' then 'anayasa' else 'kanun' end,
    format('%s sayılı %s', v_no, k.baslik), coalesce(case when k.tur = 'anayasa' then oyun.anayasa_aciklama(k.veri) || ' ' end, '') || k.metin, k.id, t);
  perform oyun.bildir(k.teklif_eden, format('Teklifin yasalaştı: %s sayılı "%s" yürürlüğe girdi.', v_no, k.baslik), t);
  perform oyun.olay('meclis', format('%s sayılı "%s" yürürlüğe girdi. %s', v_no, k.baslik, p_not), null, k.teklif_parti, t);
end $$;

create or replace function oyun.kanun_say(p_id bigint, p_asama text) returns table(kabul int, ret int, cekimser int) language sql stable as $$
  select count(*) filter (where oy = 'kabul')::int, count(*) filter (where oy = 'ret')::int, count(*) filter (where oy = 'cekimser')::int
  from oyun.kanun_oylari where kanun_id = p_id and asama = p_asama
$$;

create or replace function oyun.kanun_tick(t timestamptz) returns void language plpgsql as $$
declare k oyun.kanunlar; c record; dolu int; cb uuid; s record;
begin
  select * into s from oyun.kanun_suresi();
  -- anayasa değişikliği: görüşme bitince imza sayısı dolu sandalyelerin üçte birine ulaşmadıysa teklif düşer
  for k in select * from oyun.kanunlar where durum = 'gorusmede' and tur = 'anayasa' and t >= oy_bas order by oy_bas loop
    dolu := oyun.dolu_sandalye();
    if (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza') < ceil(dolu / 3.0) then
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bas,
        sonuc_metin = format('Yeterli imza toplanamadı: %s imza, en az %s gerekliydi (dolu sandalyelerin üçte biri).',
                             (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza'), ceil(dolu / 3.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin yeterli imza toplayamadı.', k.baslik), k.oy_bas);
    end if;
  end loop;
  update oyun.kanunlar set durum = 'oylamada' where durum = 'gorusmede' and t >= oy_bas;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur = 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    cb := oyun.aktif_cb();
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then
      update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
        sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: üçte iki çoğunluk sağlandı.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.bildir(cb, format('"%s" anayasa değişikliği Meclis''ten üçte iki çoğunlukla geçti. 48 saat içinde yayımla ya da halkoyuna sun.', k.baslik), k.oy_bit);
      perform oyun.olay('meclis', format('"%s" anayasa değişikliği üçte iki çoğunlukla kabul edildi (%s kabul). Cumhurbaşkanına sunuldu.', k.baslik, c.kabul), null, k.teklif_parti, k.oy_bit);
    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      update oyun.kanunlar set sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.referandum_baslat(k.id, k.oy_bit);
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = format('Reddedildi: gizli oylamada %s kabul oyu çıktı; halkoyuna sunulması için en az %s (beşte üç) gerekliydi.', c.kabul, ceil(dolu * 3 / 5.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin Meclis''te gerekli çoğunluğu alamadı.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur <> 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul + c.ret + c.cekimser >= ceil(dolu / 3.0) and c.kabul > c.ret and c.kabul >= floor(dolu / 4.0) + 1 then
      cb := oyun.aktif_cb();
      if cb is null then
        perform oyun.kanun_yururluk(k.id, k.oy_bit, format('Meclis''te %s kabul, %s ret oyla kabul edildi (cumhurbaşkanı makamı boş).', c.kabul, c.ret));
      else
        update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
          sonuc_metin = format('Meclis''te %s kabul, %s ret, %s çekimser oyla kabul edildi.', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.bildir(cb, format('"%s" kanunu Meclis''ten geçti ve onayınızı bekliyor. 48 saat içinde onaylayın ya da veto edin.', k.baslik), k.oy_bit);
        perform oyun.olay('meclis', format('"%s" Meclis''te kabul edildi (%s kabul, %s ret). Cumhurbaşkanının onayına sunuldu.', k.baslik, c.kabul, c.ret), null, k.teklif_parti, k.oy_bit);
      end if;
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = case when c.kabul + c.ret + c.cekimser < ceil(dolu / 3.0) then format('Toplantı yeter sayısı sağlanamadı (%s vekil katıldı, en az %s gerekliydi).', c.kabul + c.ret + c.cekimser, ceil(dolu / 3.0))
                           else format('Reddedildi: %s kabul, %s ret, %s çekimser (kabul için en az %s ve retten fazla oy gerekliydi).', c.kabul, c.ret, c.cekimser, floor(dolu / 4.0) + 1) end
      where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" teklifin Meclis''te kabul edilmedi.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'cb_onayinda' and t >= cb_bit order by cb_bit loop
    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = 'anayasa' then 'Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.'
                                                    else 'Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.' end);
  end loop;
  for k in select * from oyun.kanunlar where durum = 'israr' and t >= israr_bit order by israr_bit loop
    select * into c from oyun.kanun_say(k.id, 'israr');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul >= floor(dolu / 2.0) + 1 then
      perform oyun.kanun_yururluk(k.id, k.israr_bit, format('Veto sonrası Meclis %s oyla ısrar etti.', c.kabul));
    else
      update oyun.kanunlar set durum = 'dustu', sonuc_at = k.israr_bit,
        sonuc_metin = format('Veto sonrası ısrar için %s oy gerekiyordu, %s kabul oyu çıktı. Kanun düştü.', floor(dolu / 2.0) + 1, c.kabul) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" veto sonrası ısrar oylamasında düştü.', k.baslik), k.israr_bit);
    end if;
  end loop;
  -- seçim döneminde kabul edilen baraj, seçim bitince uygulanır
  if (select bekleyen_baraj from oyun.ulke where id = 1) is not null
     and not exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                     where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor') then
    update oyun.ayarlar set baraj = (select bekleyen_baraj from oyun.ulke where id = 1) where id = 1;
    update oyun.ulke set bekleyen_baraj = null where id = 1;
  end if;
end $$;

-- Yeni Meclis göreve başlayınca sonuçlanmamış teklifler kadük olur
create or replace function oyun.kanunlar_kaduk(t timestamptz) returns void language sql as $$
  update oyun.kanunlar set durum = 'kaduk', sonuc_at = t, sonuc_metin = 'Yasama dönemi sona erdiği için kadük oldu.'
  where durum in ('gorusmede','oylamada','israr')
$$;

create or replace function oyun.kanun_ozet(k oyun.kanunlar, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', k.id, 'no', k.no, 'tur', k.tur, 'baslik', k.baslik, 'durum', k.durum,
    'teklif_eden', oyun.kad(k.teklif_eden), 'parti', oyun.parti_json(k.teklif_parti),
    'teklif_at', k.teklif_at, 'oy_bas', k.oy_bas, 'oy_bit', k.oy_bit, 'cb_bit', k.cb_bit, 'israr_bit', k.israr_bit, 'sonuc_at', k.sonuc_at,
    'oy_verdim', exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = p.id
                          and o.asama = case when k.durum = 'israr' then 'israr' else 'ilk' end))
$$;

create or replace function public.kanunlar(p_limit int default 40) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(oyun.kanun_ozet(k, p, t) order by
            (k.durum in ('gorusmede','oylamada','cb_onayinda','israr')) desc, k.teklif_at desc)
          from (select * from oyun.kanunlar order by teklif_at desc limit least(greatest(p_limit, 1), 100)) k), '[]'::jsonb);
end $$;

create or replace function public.kanun_detay(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; dolu int := oyun.dolu_sandalye();
begin
  select * into k from oyun.kanunlar where id = p_id;
  if k.id is null then raise exception 'Kanun bulunamadı.'; end if;
  return oyun.kanun_ozet(k, p, t) || jsonb_build_object(
    'metin', k.metin, 'veri', k.veri, 'veto_gerekce', k.veto_gerekce, 'sonuc_metin', k.sonuc_metin,
    'kararname', case when k.tur = 'iptal' then (select jsonb_build_object('no', no, 'baslik', baslik) from oyun.kararnameler where id = (k.veri ->> 'kararname_id')::bigint) end,
    'dolu', dolu, 'toplanti_yeter', ceil(dolu / 3.0), 'karar_yeter', floor(dolu / 4.0) + 1, 'israr_yeter', floor(dolu / 2.0) + 1,
    'vekilim', oyun.aktif_vekil(p.id),
    'oy_acik', (k.durum = 'oylamada' and t >= k.oy_bas and t < k.oy_bit) or (k.durum = 'israr' and t < k.israr_bit),
    'benim_oyum', (select oy from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = case when k.durum = 'israr' then 'israr' else 'ilk' end),
    'cb_karar_verebilir', k.durum = 'cb_onayinda' and t < k.cb_bit and oyun.aktif_cb() = p.id,
    'anayasa_aciklama', case when k.tur = 'anayasa' then oyun.anayasa_aciklama(k.veri) end,
    'grup', oyun.grup_karar_json(k.id, p), 'tbmm_baskani', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null),
    'duzenleme', case when k.tur = 'duzenleme' then (select jsonb_build_object('ad', d.ad, 'yazi', oyun.duz_yaz(d.kod, (k.veri ->> 'deger')::numeric),
                    'mevcut', oyun.duz_yaz(d.kod, oyun.duz(d.kod)), 'oyuncu', d.oyuncu, 'devlet', d.devlet) from oyun.duzenleme_tanim d where d.kod = k.veri ->> 'kod') end,
    'imza_yeter', ceil(dolu / 3.0), 'uc_bes', ceil(dolu * 3 / 5.0), 'iki_uc', ceil(dolu * 2 / 3.0),
    'imzaladim', exists (select 1 from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = 'imza'),
    'referandum', (select jsonb_build_object('id', r.id, 'oy_bas', r.oy_bas, 'durum', r.durum, 'sonuc', r.sonuc) from oyun.referandumlar r where r.kanun_id = k.id),
    'benim', k.teklif_eden = p.id,
    'oylar', (select jsonb_object_agg(a.asama, a.j) from (
       select o.asama, jsonb_build_object(
         'kabul', count(*) filter (where o.oy = 'kabul'), 'ret', count(*) filter (where o.oy = 'ret'), 'cekimser', count(*) filter (where o.oy = 'cekimser'),
         'liste', case when k.tur = 'anayasa' and o.asama = 'ilk' then '[]'::jsonb
                       else jsonb_agg(jsonb_build_object('kad', oyun.kad(o.vekil), 'oy', o.oy, 'parti', oyun.parti_json(o.parti_id),
                              'aykiri', o.asama <> 'imza' and exists (select 1 from oyun.grup_kararlari g where g.kanun_id = k.id and g.parti_id = o.parti_id
                                                                         and g.karar in ('kabul','ret') and g.karar <> o.oy)) order by o.parti_id, o.zaman) end) j
       from oyun.kanun_oylari o where o.kanun_id = k.id group by o.asama) a));
end $$;

-- ---------------------------------------------------------------------
-- İTTİFAKLAR
--   Genel başkanlar kurar, davet eder, kabul eder, ayrılır.
--   Genel seçim için oy verme başlayana dek kurma, teklif, kabul ve ayrılma serbesttir.
--   Sandık açıldığında sonuç açıklanana kadar ittifak işlemleri kilitlenir.
-- ---------------------------------------------------------------------
create or replace function oyun.ittifak_kilit(t timestamptz) returns text language sql stable as $
  select 'Genel seçimde oy verme başladı; sonuçlar açıklanana kadar ittifaklarda değişiklik yapılamaz.'
  where exists (select 1 from oyun.secimler g
                where g.tur = 'mv' and g.durum = 'bekliyor' and g.oy_bas is not null and t >= g.oy_bas)
$;

create or replace function oyun.gb_partim(p oyun.profiller) returns oyun.partiler language plpgsql stable as $$
declare pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p.parti_id and gb = p.id and not kapali;
  if pa.id is null then raise exception 'Bu işlemi yalnızca partinin genel başkanı yapabilir.'; end if;
  return pa;
end $$;

create or replace function oyun.ittifak_temizle() returns void language sql as $$
  delete from oyun.ittifak_uyeler where parti_id in (select id from oyun.partiler where kapali);
  delete from oyun.ittifak_davetler where parti_id in (select id from oyun.partiler where kapali);
  delete from oyun.ittifaklar i where not exists (select 1 from oyun.ittifak_uyeler u where u.ittifak_id = i.id);
$$;

create or replace function public.ittifak_bilgi(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); iid bigint;
begin
  select ittifak_id into iid from oyun.ittifak_uyeler where parti_id = p_parti;
  return jsonb_build_object(
    'kilit', oyun.ittifak_kilit(t),
    'ittifak', case when iid is null then null else (select jsonb_build_object('id', i.id, 'ad', i.ad, 'kurulus', i.kurulus,
        'uyeler', (select jsonb_agg(oyun.parti_json(u.parti_id) order by u.parti_id) from oyun.ittifak_uyeler u where u.ittifak_id = i.id),
        'davetler', coalesce((select jsonb_agg(oyun.parti_json(d.parti_id)) from oyun.ittifak_davetler d where d.ittifak_id = i.id), '[]'::jsonb))
      from oyun.ittifaklar i where i.id = iid) end,
    'gelen_davetler', coalesce((select jsonb_agg(jsonb_build_object('ittifak_id', i.id, 'ad', i.ad,
        'uyeler', (select jsonb_agg(oyun.parti_json(u.parti_id)) from oyun.ittifak_uyeler u where u.ittifak_id = i.id)))
      from oyun.ittifak_davetler d join oyun.ittifaklar i on i.id = d.ittifak_id where d.parti_id = p_parti), '[]'::jsonb),
    'gb_benim', exists (select 1 from oyun.partiler where id = p_parti and gb = p.id));
end $$;

create or replace function public.ittifak_kur(p_ad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; ad text; kl text; yeni bigint;
begin
  pa := oyun.gb_partim(p);
  kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
  if exists (select 1 from oyun.ittifak_uyeler where parti_id = pa.id) then raise exception 'Partin zaten bir ittifakta.'; end if;
  ad := btrim(regexp_replace(coalesce(p_ad, ''), '\s+', ' ', 'g'));
  if length(ad) < 4 or length(ad) > 40 then raise exception 'İttifak adı 4-40 karakter olmalı.'; end if;
  if oyun.yasakli_ad(ad) or oyun.sade(ad) like any (array['%cumhurittifak%','%millet ittifak%','%millettifak%','%emekveozgurluk%']) then
    raise exception 'Gerçek ittifakları çağrıştıran veya uygunsuz adlar kullanılamaz.';
  end if;
  insert into oyun.ittifaklar(ad, kurulus, kurucu_parti) values (ad, t, pa.id) returning id into yeni;
  insert into oyun.ittifak_uyeler(ittifak_id, parti_id) values (yeni, pa.id);
  perform oyun.olay('ittifak', format('%s, %s adıyla yeni bir ittifak kurdu.', pa.kisa, ad), null, pa.id, t);
  return public.ittifak_bilgi(pa.id);
end $$;

create or replace function public.ittifak_davet(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; hedef oyun.partiler; iid bigint; kl text;
begin
  pa := oyun.gb_partim(p);
  kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
  select ittifak_id into iid from oyun.ittifak_uyeler where parti_id = pa.id;
  if iid is null then raise exception 'Önce bir ittifak kurmalısın.'; end if;
  select * into hedef from oyun.partiler where id = p_parti and not kapali;
  if hedef.id is null or hedef.id = pa.id then raise exception 'Geçersiz parti.'; end if;
  if exists (select 1 from oyun.ittifak_uyeler where parti_id = hedef.id) then raise exception '% zaten bir ittifakta.', hedef.kisa; end if;
  insert into oyun.ittifak_davetler(ittifak_id, parti_id, zaman) values (iid, hedef.id, t) on conflict do nothing;
  if hedef.gb is not null then
    perform oyun.bildir(hedef.gb, format('%s, partini %s ittifakına davet etti. Parti sayfasından yanıtlayabilirsin.', pa.kisa, (select ad from oyun.ittifaklar where id = iid)), t);
  end if;
  return public.ittifak_bilgi(pa.id);
end $$;

create or replace function public.ittifak_davet_yanit(p_ittifak bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; kl text; iad text;
begin
  pa := oyun.gb_partim(p);
  if not exists (select 1 from oyun.ittifak_davetler where ittifak_id = p_ittifak and parti_id = pa.id) then raise exception 'Böyle bir davet yok.'; end if;
  select ad into iad from oyun.ittifaklar where id = p_ittifak;
  if p_kabul then
    kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
    if exists (select 1 from oyun.ittifak_uyeler where parti_id = pa.id) then raise exception 'Partin zaten bir ittifakta; önce ayrılmalısın.'; end if;
    insert into oyun.ittifak_uyeler(ittifak_id, parti_id) values (p_ittifak, pa.id);
    delete from oyun.ittifak_davetler where parti_id = pa.id;
    perform oyun.olay('ittifak', format('%s, %s adlı ittifaka katıldı.', pa.kisa, iad), null, pa.id, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.gb, t, format('%s ittifakınıza katıldı.', pa.kisa) from oyun.ittifak_uyeler u join oyun.partiler x on x.id = u.parti_id
      where u.ittifak_id = p_ittifak and x.gb is not null and x.id <> pa.id;
  else
    delete from oyun.ittifak_davetler where ittifak_id = p_ittifak and parti_id = pa.id;
  end if;
  return public.ittifak_bilgi(pa.id);
end $$;

create or replace function public.ittifak_ayril() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; kl text; iid bigint; iad text;
begin
  pa := oyun.gb_partim(p);
  kl := oyun.ittifak_kilit(t); if kl is not null then raise exception '%', kl; end if;
  delete from oyun.ittifak_uyeler where parti_id = pa.id returning ittifak_id into iid;
  if iid is null then raise exception 'Partin bir ittifakta değil.'; end if;
  select ad into iad from oyun.ittifaklar where id = iid;
  -- ittifak ortağını destekleme kararı varsa düşer
  delete from oyun.cb_kararlar k where k.parti_id = pa.id and k.yontem = 'destek'
    and exists (select 1 from oyun.secimler s where s.tur = 'cb' and s.donem = k.donem and s.durum = 'bekliyor');
  perform oyun.ittifak_temizle();
  perform oyun.olay('ittifak', format('%s, %s adlı ittifaktan ayrıldı.', pa.kisa, iad), null, pa.id, t);
  return public.ittifak_bilgi(pa.id);
end $$;

-- Cumhurbaşkanlığında kendi adayını çıkarmak yerine ittifak ortağının adayını destekle
create or replace function public.cb_destek(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; hedef oyun.partiler;
begin
  pa := oyun.gb_partim(p);
  select * into s from oyun.secimler where tur = 'cb' and t >= basvuru_bas and t < basvuru_bit;
  if s.id is null then raise exception 'Cumhurbaşkanı adayı kararı ayın 19''u ile 25''i arasında verilir.'; end if;
  select * into hedef from oyun.partiler where id = p_parti and not kapali;
  if hedef.id is null or hedef.id = pa.id then raise exception 'Geçersiz parti.'; end if;
  if not exists (select 1 from oyun.ittifak_uyeler a join oyun.ittifak_uyeler b on a.ittifak_id = b.ittifak_id
                 where a.parti_id = pa.id and b.parti_id = hedef.id) then
    raise exception 'Yalnızca ittifak ortağının adayını destekleyebilirsin.';
  end if;
  insert into oyun.cb_kararlar(donem, parti_id, yontem, aday, destek_parti, zaman) values (s.donem, pa.id, 'destek', null, hedef.id, t)
  on conflict (donem, parti_id) do update set yontem = 'destek', aday = null, destek_parti = excluded.destek_parti, zaman = excluded.zaman;
  delete from oyun.adaylar where secim_id = s.id and parti_id = pa.id;
  perform oyun.olay('ittifak', format('%s, cumhurbaşkanlığı seçiminde %s''nin adayını destekleme kararı aldı.', pa.kisa, hedef.kisa), null, pa.id, t);
  return public.durum();
end $$;

-- Harita: il gelişmişliği eklendi (03'teki tanımın yerine geçer)
create or replace function public.harita() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id, 'ad', i.ad, 'mv', i.mv,
    'oyuncu', (select count(*) from oyun.profiller pr where pr.il_id = i.id),
    'gelisim', (select round(gelisim, 1) from oyun.il_durum d where d.il_id = i.id),
    'bel', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id))
            from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1),
    'vekil', (select coalesce(jsonb_agg(jsonb_build_object('parti_id', x.parti_id, 'renk', pa.renk, 'kisa', pa.kisa, 'n', x.n) order by x.n desc), '[]'::jsonb)
              from (select parti_id, count(*) n from oyun.makamlar m where m.tur = 'mv' and m.il_id = i.id and m.bit is null group by parti_id) x
              join oyun.partiler pa on pa.id = x.parti_id)
  ) order by i.id), '[]'::jsonb)
  from oyun.iller i
$$;
