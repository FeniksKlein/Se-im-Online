-- =====================================================================
--  12 · MEVZUAT, ANAYASA DEĞİŞİKLİĞİ VE HALK OYLAMASI
--
--  Oyuncuları doğrudan etkileyen kurallar (düzenlemeler) ve normlar hiyerarşisi:
--    Anayasa (halk oylaması)  >  Kanun (Meclis)  >  Cumhurbaşkanlığı kararnamesi
--    • Cumhurbaşkanı kanunla düzenlenmiş bir konuyu kararnameyle değiştiremez.
--    • Meclis anayasaya bağlanmış bir konuyu kanunla değiştiremez; ancak yeni bir anayasa değişikliği değiştirir.
--  İl düzenlemeleri (emlak vergisi, hoş geldin desteği) belediye başkanının kararıdır.
--
--  Anayasa değişikliği (gerçek usule yakın):
--    teklif: bir milletvekili verir, 24 saatlik görüşmede dolu sandalyelerin 1/3'ü imza vermeli
--    oylama: GİZLİ oy; ≥ 2/3 → cumhurbaşkanı yürürlüğe koyar ya da halkoyuna sunar (karar vermezse yürürlüğe girer)
--            ≥ 3/5 → doğrudan halk oylamasına gider · daha azı → ret
--    halk oylaması: tüm oyuncular sandığa gider (Evet / Hayır), oy gizlidir; geçerli oyların yarısından fazlası
--                   "Evet" ise yürürlüğe girer. Sonuç il il açıklanır.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.duzenleme_tanim(
  kod        text primary key,
  kapsam     text not null check (kapsam in ('ulke','il')),
  ad         text not null,
  birim      text not null,                 -- binde, tl, tl_gun, yuzde, saat
  varsayilan numeric not null,
  min        numeric not null,
  max        numeric not null,
  adim       numeric not null,
  tur        text not null check (tur in ('kolaylik','yaptirim','gelir')),
  aciklama   text not null,
  oyuncu     text not null,                 -- oyunculara etkisi
  devlet     text not null,                 -- hazineye / ekonomiye etkisi
  sira       int not null
);
insert into oyun.duzenleme_tanim(kod, kapsam, ad, birim, varsayilan, min, max, adim, tur, aciklama, oyuncu, devlet, sira) values
 ('servet_vergisi','ulke','Servet vergisi','binde',0,0,10,0.5,'gelir',
  'Büyük servetlerden alınan günlük vergi. Muafiyet: 250.000 ₺ × fiyat düzeyi.',
  'Cüzdanında muafiyetin üstünde para olan oyuncudan her gün ilk toplamada, aşan kısmın binde bu kadarı kesilir.',
  'Her binde 1 hazineye günde 0,3 milyar ₺ getirir; sermaye kaçışı büyümeyi düşürür, halk memnuniyeti biraz artar.',1),
 ('oy_cezasi','ulke','Sandığa gitmeyene idari para cezası','tl',0,0,5000,250,'yaptirim',
  'Seçimde ya da halk oylamasında oy kullanabilecekken kullanmayan oyuncuya kesilen ceza.',
  'Oy kullanma hakkı olup son 7 günde oyuna girmiş, ama sandığa gitmemiş oyuncunun cüzdanından düşer.',
  'Katılımı artırır; halk memnuniyetini biraz düşürür. Hazine geliri önemsizdir.',2),
 ('yeni_hibe','ulke','Yeni vatandaşa hoş geldin hibesi','tl',0,0,50000,1000,'kolaylik',
  'Oyuna yeni katılan her oyuncuya tek seferlik devlet hibesi.',
  'Yeni hesap açan oyuncunun cüzdanına bir kez yatar.',
  'Ülkede günde 5.000 yeni vatandaşa ödenir: her 10.000 ₺ hazineye günde 0,05 milyar ₺; enflasyonu biraz artırır.',3),
 ('aday_destek','ulke','Siyasi katılım fonu','yuzde',0,0,100,5,'kolaylik',
  'Aday adaylığı başvuru ücretlerinin bu kadarını hazine öder; parti kasasına ücretin tamamı girer.',
  'Aday olmak ucuzlar: oyuncu ücretin yalnızca kalanını öder.',
  'Her %10 hazineye günde 0,04 milyar ₺.',4),
 ('seri_tavan','ulke','Devamlılık primi tavanı','yuzde',30,0,60,5,'kolaylik',
  'Her gün maaşını toplayanın maaşına eklenen seri priminin üst sınırı (günde +%5 artar).',
  'Uzun seri yapan oyuncunun maaşı bu tavana kadar artar.',
  '%30''un üstündeki her 10 puan enflasyonu 0,5 puan artırır; altı enflasyonu düşürür.',5),
 ('kumbara_saat','ulke','Maaş kumbarası kapasitesi','saat',8,6,12,1,'kolaylik',
  'Maaşın en fazla kaç saat birikir (esnek çalışma düzenlemesi).',
  'Uzun kapasite, oyuna seyrek giren oyuncunun maaşını kaybetmemesini sağlar.',
  '8 saatin üstündeki her saat büyümeyi 0,1 puan düşürür, memnuniyeti 0,5 puan artırır.',6),
 ('vekil_kesinti','ulke','Meclis devamsızlık kesintisi','yuzde',0,0,50,5,'yaptirim',
  'Son 7 günde biten kanun oylamalarına katılmayan milletvekilinin makam maaşından kesinti.',
  'Vekilin maaşından: kesinti oranı × katılmadığı oylamaların oranı kadar düşer.',
  'Hazineye etkisi yok; halk memnuniyeti biraz artar.',7),
 ('emlak','il','Emlak vergisi','tl_gun',0,0,300,10,'gelir',
  'İlde yaşayan her oyuncudan günlük emlak vergisi (fiyat düzeyiyle artar).',
  'Her gün ilk toplamada cüzdandan kesilir.',
  'Belediye kasasına ildeki hane sayısıyla orantılı gelir; ildeki memnuniyet düşer.',1),
 ('hosgeldin','il','Yeni hemşehriye hoş geldin desteği','tl',0,0,20000,500,'kolaylik',
  'İle yeni taşınan ya da bu ilde hesap açan oyuncuya bir kez ödenir.',
  'İle ilk kez yerleşen oyuncunun cüzdanına bir kez yatar (her ilde bir kez).',
  'Her ödeme belediye kasasından tutar × 2.000 hane kadar düşer; kasa yetmezse ödenmez.',2)
on conflict (kod) do update set kapsam = excluded.kapsam, ad = excluded.ad, birim = excluded.birim, varsayilan = excluded.varsayilan,
  min = excluded.min, max = excluded.max, adim = excluded.adim, tur = excluded.tur, aciklama = excluded.aciklama,
  oyuncu = excluded.oyuncu, devlet = excluded.devlet, sira = excluded.sira;

create table if not exists oyun.duzenlemeler(
  kod      text primary key references oyun.duzenleme_tanim(kod),
  deger    numeric not null,
  kaynak   text not null check (kaynak in ('kararname','kanun','anayasa')),
  ref_id   bigint,                 -- kararname / kanun id
  zaman    timestamptz not null
);
create table if not exists oyun.il_duzenleme(
  il_id  smallint not null references oyun.iller(id),
  kod    text not null references oyun.duzenleme_tanim(kod),
  deger  numeric not null,
  baskan uuid,
  zaman  timestamptz not null,
  primary key (il_id, kod)
);
create table if not exists oyun.hosgeldin_kayit(
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  il_id   smallint not null,
  zaman   timestamptz not null,
  primary key (user_id, il_id)
);

-- Anayasal sınırlar (yalnız halk oylaması/anayasa değişikliğiyle değişir)
create table if not exists oyun.anayasa(
  kod    text primary key,
  ad     text not null,
  deger  numeric not null,
  min    numeric not null,
  max    numeric not null,
  aciklama text not null,
  kanun_id bigint,
  zaman  timestamptz
);
insert into oyun.anayasa(kod, ad, deger, min, max, aciklama) values
 ('kararname_sinir','Cumhurbaşkanının günlük kararname yetkisi',3,0,5,'Cumhurbaşkanı günde en fazla bu kadar kararname çıkarabilir. 0 olursa kararname yetkisi kalkar.'),
 ('vergi_tavani','Gelir vergisinin anayasal tavanı',45,20,45,'Meclis bütçe kanunuyla vergi bandını bu tavanın üstüne çıkaramaz.')
on conflict (kod) do update set ad = excluded.ad, min = excluded.min, max = excluded.max, aciklama = excluded.aciklama;

-- Kamu varlıkları (özelleştirilebilir) ve borçlar (tahvil)
alter table oyun.ulke add column if not exists kamu_varlik numeric not null default 400;   -- milyar ₺
create table if not exists oyun.borclar(
  id           bigserial primary key,
  kararname_id bigint,
  anapara      numeric not null,
  faiz         numeric not null,         -- toplam faiz oranı (%)
  gunluk       numeric not null,         -- günlük geri ödeme (milyar ₺)
  kalan_gun    int not null,
  zaman        timestamptz not null
);

-- Halk oylaması
create table if not exists oyun.referandumlar(
  id        bigserial primary key,
  kanun_id  bigint not null unique references oyun.kanunlar(id) on delete cascade,
  baslik    text not null,
  olusturma timestamptz not null,
  oy_bas    timestamptz not null,
  oy_bit    timestamptz not null,
  durum     text not null default 'bekliyor' check (durum in ('bekliyor','oylamada','sonuclandi')),
  evet      int not null default 0,
  hayir     int not null default 0,
  secmen    int,                         -- oy kullanma hakkı olan oyuncu sayısı (sonuçta)
  sonuc     text check (sonuc in ('kabul','ret')),
  hatirlatma boolean not null default false
);
-- Oy gizliliği: kimin oy kullandığı ayrı, sandıktaki Evet/Hayır sayısı ayrı tutulur; ikisi birbirine bağlanamaz.
create table if not exists oyun.referandum_katilim(
  ref_id bigint not null references oyun.referandumlar(id) on delete cascade,
  secmen uuid not null,
  zaman  timestamptz not null,
  primary key (ref_id, secmen)
);
create table if not exists oyun.referandum_sandik(
  ref_id bigint not null references oyun.referandumlar(id) on delete cascade,
  il_id  smallint not null,
  evet   int not null default 0,
  hayir  int not null default 0,
  primary key (ref_id, il_id)
);
create table if not exists oyun.oy_cezasi_kayit(
  anahtar text primary key,              -- 's<secim_id>' ya da 'r<referandum_id>'
  ceza    numeric not null,
  kisi    int not null,
  toplam  numeric not null,
  zaman   timestamptz not null
);

-- Kanun türleri ve durumları
alter table oyun.kanunlar drop constraint if exists kanunlar_tur_check;
alter table oyun.kanunlar add constraint kanunlar_tur_check check (tur in ('serbest','butce','secim','iptal','duzenleme','anayasa'));
alter table oyun.kanunlar drop constraint if exists kanunlar_durum_check;
alter table oyun.kanunlar add constraint kanunlar_durum_check
  check (durum in ('gorusmede','oylamada','cb_onayinda','israr','yururlukte','ret','dustu','kaduk','geri_cekildi','halkoylamasinda'));
alter table oyun.kanun_oylari drop constraint if exists kanun_oylari_asama_check;
alter table oyun.kanun_oylari add constraint kanun_oylari_asama_check check (asama in ('ilk','israr','imza'));
alter table oyun.kararnameler drop constraint if exists kararnameler_tur_check;
alter table oyun.kararnameler add constraint kararnameler_tur_check
  check (tur in ('serbest','il_destek','odenek','vergi','ikramiye','duzenleme','ozellestirme','tahvil'));
alter table oyun.gazete drop constraint if exists gazete_tur_check;
alter table oyun.gazete add constraint gazete_tur_check check (tur in ('kanun','kararname','atama','icraat','anayasa','referandum','belediye'));

-- ---------------------------------------------------------------------
-- DEĞER OKUMA
-- ---------------------------------------------------------------------
create or replace function oyun.duz(p_kod text) returns numeric language sql stable as $$
  select coalesce((select deger from oyun.duzenlemeler where kod = p_kod), (select varsayilan from oyun.duzenleme_tanim where kod = p_kod), 0)
$$;
create or replace function oyun.il_duz(p_il smallint, p_kod text) returns numeric language sql stable as $$
  select coalesce((select deger from oyun.il_duzenleme where il_id = p_il and kod = p_kod), (select varsayilan from oyun.duzenleme_tanim where kod = p_kod), 0)
$$;
create or replace function oyun.anayasa_deger(p_kod text) returns numeric language sql stable as $$
  select deger from oyun.anayasa where kod = p_kod
$$;
create or replace function oyun.kumbara_saat() returns numeric language sql stable as $$
  select oyun.duz('kumbara_saat')
$$;
create or replace function oyun.birim_yaz(x numeric, b text) returns text language sql immutable as $$
  select case b when 'tl_ay' then oyun.tl(x) || ' ₺/ay' when 'tl_gun' then oyun.tl(x) || ' ₺/gün' when 'tl' then oyun.tl(x) || ' ₺'
                when 'adet' then oyun.tl(x) || ' adet'
                when 'yuzde' then '%' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'binde' then '‰' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'saat' then round(x)::text || ' saat'
                when 'kat' then '×' || replace(regexp_replace(trim(to_char(x, 'FM990.00')), '\.?0+$', ''), '.', ',')
                else coalesce(x::text, '') end
$$;
create or replace function oyun.duz_yaz(p_kod text, x numeric) returns text language sql stable as $$
  select oyun.birim_yaz(x, (select birim from oyun.duzenleme_tanim where kod = p_kod))
$$;
create or replace function oyun.kaynak_ad(k text) returns text language sql immutable as $$
  select case k when 'anayasa' then 'Anayasa' when 'kanun' then 'Kanun' when 'kararname' then 'Cumhurbaşkanlığı kararnamesi' else 'Varsayılan' end
$$;

-- Değer aralık denetimi (adım katına yuvarlar)
create or replace function oyun.duzenleme_dogrula(p_kod text, p_deger numeric, p_kapsam text default 'ulke') returns numeric language plpgsql stable as $$
declare d oyun.duzenleme_tanim; v numeric;
begin
  select * into d from oyun.duzenleme_tanim where kod = p_kod;
  if d.kod is null or d.kapsam <> p_kapsam then raise exception 'Geçersiz düzenleme.'; end if;
  if p_deger is null then raise exception '"%" için bir değer girmelisin.', d.ad; end if;
  v := round(p_deger / d.adim) * d.adim;
  if v < d.min or v > d.max then
    raise exception '"%" % ile % arasında olmalı.', d.ad, oyun.duz_yaz(d.kod, d.min), oyun.duz_yaz(d.kod, d.max);
  end if;
  return v;
end $$;

-- Ülke düzenlemesini uygula. Hiyerarşiye uymazsa false döner (çağıran karar verir).
create or replace function oyun.duzenleme_uygula(p_kod text, p_deger numeric, p_kaynak text, p_ref bigint, t timestamptz) returns boolean language plpgsql as $$
declare mevcut oyun.duzenlemeler;
begin
  select * into mevcut from oyun.duzenlemeler where kod = p_kod for update;
  if mevcut.kod is not null then
    if mevcut.kaynak = 'anayasa' and p_kaynak <> 'anayasa' then return false; end if;
    if mevcut.kaynak = 'kanun' and p_kaynak = 'kararname' then return false; end if;
  end if;
  insert into oyun.duzenlemeler(kod, deger, kaynak, ref_id, zaman) values (p_kod, p_deger, p_kaynak, p_ref, t)
  on conflict (kod) do update set deger = excluded.deger, kaynak = excluded.kaynak, ref_id = excluded.ref_id, zaman = excluded.zaman;
  return true;
end $$;

-- Hiyerarşi engeli: kim değiştiremez, neden?
create or replace function oyun.duzenleme_engel(p_kod text, p_kaynak text) returns text language sql stable as $$
  select case when d.kaynak = 'anayasa' and p_kaynak <> 'anayasa'
                then 'Bu kural anayasada düzenlenmiş; ancak halk oylamasıyla yapılacak bir anayasa değişikliğiyle değiştirilebilir.'
              when d.kaynak = 'kanun' and p_kaynak = 'kararname'
                then 'Bu konu Meclis tarafından kanunla düzenlenmiş; kanunla düzenlenen konuda cumhurbaşkanlığı kararnamesi çıkarılamaz.' end
  from (select 1) x left join oyun.duzenlemeler d on d.kod = p_kod
$$;

-- ---------------------------------------------------------------------
-- EKONOMİYE ETKİ (önizleme, vaat maliyeti, günlük hesap)
--   gunluk > 0: hazineye günlük maliyet (milyar ₺); < 0: gelir
-- ---------------------------------------------------------------------
create or replace function oyun.duzenleme_etki(p_kod text, p_deger numeric) returns jsonb language sql stable as $$
  with x as (select p_deger v, oyun.duz(p_kod) m)
  select jsonb_build_object(
    'gunluk', round(case p_kod when 'servet_vergisi' then -0.3 * (v - m)
                               when 'yeni_hibe' then (v - m) * 5000 / 1e9
                               when 'aday_destek' then 0.004 * (v - m) else 0 end, 3),
    'enflasyon', round(case p_kod when 'seri_tavan' then 0.05 * (v - m) when 'yeni_hibe' then 0.02 * (v - m) / 1000 else 0 end, 2),
    'buyume', round(case p_kod when 'servet_vergisi' then -0.08 * (v - m) when 'kumbara_saat' then -0.1 * (v - m) else 0 end, 2),
    'memnuniyet', round(case p_kod when 'servet_vergisi' then 0.15 * (v - m) when 'oy_cezasi' then -0.4 * (v - m) / 1000
                                   when 'yeni_hibe' then 0.04 * (v - m) / 1000 when 'seri_tavan' then 0.03 * (v - m)
                                   when 'kumbara_saat' then 0.5 * (v - m) when 'vekil_kesinti' then 0.04 * (v - m) else 0 end, 2))
  from x
$$;

-- Göstergelerin hedeflerine eklenen kaymalar (her gece)
create or replace function oyun.mevzuat_makro() returns jsonb language sql stable as $$
  select jsonb_build_object(
    'buyume', -0.08 * oyun.duz('servet_vergisi') - 0.1 * (oyun.duz('kumbara_saat') - 8),
    'enflasyon', 0.05 * (oyun.duz('seri_tavan') - 30) + 0.02 * oyun.duz('yeni_hibe') / 1000,
    'memnuniyet', 0.15 * oyun.duz('servet_vergisi') - 0.4 * oyun.duz('oy_cezasi') / 1000 + 0.04 * oyun.duz('yeni_hibe') / 1000
                  + 0.03 * (oyun.duz('seri_tavan') - 30) + 0.5 * (oyun.duz('kumbara_saat') - 8) + 0.04 * oyun.duz('vekil_kesinti'))
$$;

-- Ülkenin günlük hesabı: 07'deki kalemlere servet vergisi, mevzuat giderleri ve borç ödemesi eklendi
create or replace function oyun.ulke_hesap(u oyun.ulke) returns jsonb language sql stable as $$
  with x as (select
      round(u.asgari / 30 * 0.6 * 25e6 * u.vergi / 100 / 1e9, 3) gv,
      round(9.5 * (1 + u.buyume / 50) * u.endeks, 3) diger,
      round(0.3 * oyun.duz('servet_vergisi'), 3) servet,
      round(10 * u.endeks, 3) cari,
      round((select sum(oyun.il_gunluk_gelir(mv)) from oyun.iller) * 0.5 * u.belediye_payi / 10 * u.endeks, 3) bel,
      round(u.destek * 8e6 / 1e9, 3) destek,
      round(oyun.duz('yeni_hibe') * 5000 / 1e9 + 0.004 * oyun.duz('aday_destek'), 3) mevzuat,
      round(coalesce((select sum(gunluk) from oyun.borclar where kalan_gun > 0), 0), 3) borc)
  select jsonb_build_object('gelir_vergisi', gv, 'diger_gelir', diger, 'servet', servet, 'gelir', gv + diger + servet,
                            'cari', cari, 'belediye', bel, 'destek', destek, 'mevzuat', mevzuat, 'borc', borc,
                            'gider', cari + bel + destek + mevzuat + borc,
                            'denge', round(gv + diger + servet - cari - bel - destek - mevzuat - borc, 3)) from x
$$;

-- İlin günlük geliri: emlak vergisi eklendi (ildeki hane × günlük vergi)
create or replace function oyun.il_gelir(p_il smallint) returns numeric language sql stable as $$
  select round(oyun.il_gunluk_gelir(i.mv) * u.endeks * (0.5 + d.gelisim / 100) * (0.5 + 0.5 * u.belediye_payi / 10) * (1 + d.kent_vergisi / 10)
               + oyun.il_duz(i.id, 'emlak') * u.endeks * oyun.nufus('il_hane') * i.mv / 600 / 1e9, 4)
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$$;

-- ---------------------------------------------------------------------
-- OYUNCUYA DOĞRUDAN ETKİLER
-- ---------------------------------------------------------------------
-- Vekilin son 7 günde katılmadığı oylamaların oranı (0-1)
create or replace function oyun.vekil_devamsizlik(u uuid, t timestamptz) returns numeric language sql stable as $$
  with k as (select k.id from oyun.kanunlar k
             where k.oy_bit <= t and k.oy_bit > t - interval '7 days' and k.durum not in ('geri_cekildi','gorusmede','oylamada')
               and exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.asama = 'ilk')   -- gerçekten oylanmış olanlar
               and exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv' and m.bas <= k.oy_bas))
  select case when count(*) = 0 then 0
              else round(1 - count(*) filter (where exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = u and o.asama = 'ilk'))::numeric / count(*), 3) end
  from k
$$;
create or replace function oyun.vekil_kesinti_orani(u uuid, t timestamptz) returns numeric language sql stable as $$
  select round(oyun.duz('vekil_kesinti') * oyun.vekil_devamsizlik(u, t), 1)
$$;

-- Günün ilk toplamasında: servet vergisi ve emlak vergisi
create or replace function oyun.gunluk_kesinti(u uuid, t timestamptz) returns numeric language plpgsql as $$
declare p oyun.profiller; c oyun.cuzdan; s numeric; muaf numeric; ks numeric := 0; em numeric; top numeric := 0; ilad text; banka numeric; a numeric; b numeric;
begin
  select * into p from oyun.profiller where id = u;
  select * into c from oyun.cuzdan where user_id = u;
  s := oyun.duz('servet_vergisi');
  if s > 0 then
    muaf := round(250000 * (select endeks from oyun.ulke where id = 1));
    banka := oyun.mevduat_toplam(u);            -- bankadaki mevduat da servete dahildir (15_ekonomi3)
    ks := floor(greatest(0, c.para + banka - muaf) * s / 1000);
    if ks > 0 then
      a := least(ks, c.para);
      if a > 0 then
        perform oyun.para_islem(u, -a, 'servet', format('Servet vergisi (binde %s, %s ₺ muafiyetin üstü%s)', replace(s::text, '.', ','), oyun.tl(muaf),
                                                       case when banka > 0 then ', banka mevduatı dahil' else '' end), t);
      end if;
      b := least(ks - a, floor(coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0)));
      if b > 0 then
        update oyun.banka_musteri set vadesiz = vadesiz - b where user_id = u;
        perform oyun.banka_kayit(u, 'vadesiz', -b, 'Servet vergisi (cüzdan yetmedi)', t);
      end if;
      top := top + a + b;
    end if;
  end if;
  em := round(oyun.il_duz(p.il_id, 'emlak') * (select endeks from oyun.ulke where id = 1));
  if em > 0 then
    em := least(em, (select para from oyun.cuzdan where user_id = u));
    if em > 0 then
      select ad into ilad from oyun.iller where id = p.il_id;
      perform oyun.para_islem(u, -em, 'emlak', ilad || ' Belediyesi emlak vergisi (günlük)', t);
      top := top + em;
    end if;
  end if;
  perform oyun.kira_ode(u, t);
  return top;
end $$;

-- Hoş geldin: devlet hibesi (yeni hesap) ve belediye hoş geldin desteği (her ilde bir kez)
create or replace function oyun.hosgeldin_ode(u uuid, p_il smallint, p_yeni boolean, t timestamptz) returns void language plpgsql as $$
declare h numeric; hb numeric; maliyet numeric; ilad text;
begin
  if p_yeni then
    hb := round(oyun.duz('yeni_hibe'));
    if hb > 0 then
      perform oyun.para_islem(u, hb, 'hibe', 'Devletin yeni vatandaş hoş geldin hibesi', t);
      perform oyun.bildir(u, format('Hoş geldin! Devlet cüzdanına %s ₺ hoş geldin hibesi yatırdı.', oyun.tl(hb)), t);
    end if;
  end if;
  h := round(oyun.il_duz(p_il, 'hosgeldin'));
  if h <= 0 or exists (select 1 from oyun.hosgeldin_kayit where user_id = u and il_id = p_il) then return; end if;
  maliyet := h * 2000 / 1e9;
  select ad into ilad from oyun.iller where id = p_il;
  update oyun.il_durum set kasa = kasa - maliyet where il_id = p_il and coalesce(kasa, 0) >= maliyet;
  if not found then
    perform oyun.bildir(u, format('%s Belediyesi''nin kasası yetmediği için hoş geldin desteği ödenemedi.', ilad), t);
    return;
  end if;
  insert into oyun.hosgeldin_kayit(user_id, il_id, zaman) values (u, p_il, t);
  perform oyun.para_islem(u, h, 'hosgeldin', ilad || ' Belediyesi hoş geldin desteği', t);
  perform oyun.bildir(u, format('%s''e hoş geldin! Belediye cüzdanına %s ₺ hoş geldin desteği yatırdı.', ilad, oyun.tl(h)), t);
end $$;

create or replace function oyun.profil_hosgeldin_tg() returns trigger language plpgsql security definer set search_path = oyun, public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    perform oyun.hosgeldin_ode(new.id, new.il_id, true, oyun.simdi());
  elsif new.il_id is distinct from old.il_id then
    perform oyun.hosgeldin_ode(new.id, new.il_id, false, oyun.simdi());
  end if;
  return null;
end $$;
drop trigger if exists profil_hosgeldin on oyun.profiller;
create trigger profil_hosgeldin after insert or update of il_id on oyun.profiller
  for each row execute function oyun.profil_hosgeldin_tg();

-- Oy kullanma sayısı kıdemi artırır: halk oylamaları da sayılır
create or replace function oyun.kidem_puani(u uuid) returns numeric language sql stable as $$
  select floor(coalesce((select kidem from oyun.cuzdan where user_id = u), 0)
               + 3 * ((select count(*) from oyun.oylar where secmen = u) + (select count(*) from oyun.referandum_katilim where secmen = u)))
$$;

-- ---------------------------------------------------------------------
-- HALK OYLAMASI
-- ---------------------------------------------------------------------
-- Oylama günü: en az 24 saat kampanya; 08:00-20:00 arası
create or replace function oyun.referandum_baslat(p_kanun bigint, t timestamptz) returns bigint language plpgsql as $$
declare k oyun.kanunlar; gun date; bas timestamptz; yeni bigint;
begin
  select * into k from oyun.kanunlar where id = p_kanun;
  gun := ((t + interval '24 hours') at time zone 'Europe/Istanbul')::date;
  bas := (gun + time '08:00') at time zone 'Europe/Istanbul';
  if bas < t + interval '24 hours' then gun := gun + 1; bas := (gun + time '08:00') at time zone 'Europe/Istanbul'; end if;
  update oyun.kanunlar set durum = 'halkoylamasinda' where id = k.id;
  insert into oyun.referandumlar(kanun_id, baslik, olusturma, oy_bas, oy_bit)
  values (k.id, k.baslik, t, bas, (gun + time '20:00') at time zone 'Europe/Istanbul') returning id into yeni;
  perform oyun.gazete_ekle('referandum', format('Halk oylaması kararı: %s', k.baslik),
    format('Anayasa değişikliği %s tarihinde 08:00-20:00 arasında halkoyuna sunulacak. Oyuna %s tarihinden önce kayıtlı her vatandaş oy kullanabilir.',
           to_char(gun, 'DD.MM.YYYY'), to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')), yeni, t);
  perform oyun.olay('referandum', format('"%s" halkoyuna sunuluyor. Sandıklar %s günü 08:00''de açılacak.', k.baslik, to_char(gun, 'DD.MM.YYYY')), null, null, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.id, t, format('Halk oylaması: "%s" anayasa değişikliği %s günü sandıkta. Evet ya da Hayır, karar senin.', k.baslik, to_char(gun, 'DD.MM.YYYY'))
    from oyun.profiller x where not x.yasakli;
  return yeni;
end $$;

-- Oy kullanma hakkı: kütük (halk oylaması kararından önce kayıtlı), yasaklı değil, hesap yaşı yeterli
create or replace function oyun.ref_engeli(p oyun.profiller, r oyun.referandumlar) returns text language sql stable as $$
  select case when p.yasakli then 'Hesabın askıya alınmış.'
              when p.olusturma > r.olusturma then 'Seçmen kütüğü halk oylaması kararıyla kesinleşti; sonradan açılan hesaplar bu oylamada oy kullanamaz.'
              else oyun.uyari(p, r.oy_bas) end
$$;

create or replace function oyun.ref_secmen_say(r oyun.referandumlar) returns int language sql stable as $$
  select count(*)::int from oyun.profiller p where oyun.ref_engeli(p, r) is null
$$;

create or replace function oyun.ref_json(r oyun.referandumlar, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object('id', r.id, 'kanun_id', r.kanun_id, 'baslik', r.baslik, 'oy_bas', r.oy_bas, 'oy_bit', r.oy_bit, 'olusturma', r.olusturma,
    'durum', r.durum, 'sonuc', r.sonuc, 'evet', r.evet, 'hayir', r.hayir, 'secmen', r.secmen,
    'asama', case when r.durum = 'sonuclandi' then 'bitti' when t >= r.oy_bas and t < r.oy_bit then 'oy' when t < r.oy_bas then 'kampanya' else 'sayim' end,
    'oy_kullandim', exists (select 1 from oyun.referandum_katilim k where k.ref_id = r.id and k.secmen = p.id),
    'engel', oyun.ref_engeli(p, r),
    'veri', (select veri from oyun.kanunlar where id = r.kanun_id),
    'teklif_eden', (select oyun.kad(teklif_eden) from oyun.kanunlar where id = r.kanun_id))
$$;

create or replace function public.referandumlar(p_limit int default 20) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(oyun.ref_json(r, p, t) order by (r.durum <> 'sonuclandi') desc, r.oy_bas desc)
                   from (select * from oyun.referandumlar order by oy_bas desc limit least(greatest(p_limit, 1), 50)) r), '[]'::jsonb);
end $$;

create or replace function public.referandum_detay(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.referandumlar; k oyun.kanunlar;
begin
  select * into r from oyun.referandumlar where id = p_id;
  if r.id is null then raise exception 'Halk oylaması bulunamadı.'; end if;
  select * into k from oyun.kanunlar where id = r.kanun_id;
  return oyun.ref_json(r, p, t) || jsonb_build_object(
    'metin', k.metin, 'meclis', k.sonuc_metin, 'aciklama', oyun.anayasa_aciklama(k.veri),
    'katilim', case when r.durum = 'sonuclandi' then r.evet + r.hayir else (select count(*) from oyun.referandum_katilim where ref_id = r.id) end,
    'iller', case when r.durum = 'sonuclandi' then
      coalesce((select jsonb_agg(jsonb_build_object('il_id', s.il_id, 'ad', i.ad, 'evet', s.evet, 'hayir', s.hayir) order by i.ad)
                from oyun.referandum_sandik s join oyun.iller i on i.id = s.il_id where s.ref_id = r.id), '[]'::jsonb) end);
end $$;

create or replace function public.referandum_oy(p_id bigint, p_oy text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.referandumlar; e text;
begin
  if p_oy not in ('evet','hayir') then raise exception 'Geçersiz oy.'; end if;
  select * into r from oyun.referandumlar where id = p_id for update;
  if r.id is null then raise exception 'Halk oylaması bulunamadı.'; end if;
  if r.durum = 'sonuclandi' or t < r.oy_bas or t >= r.oy_bit then raise exception 'Sandık şu anda kapalı (oy saatleri 08:00–20:00).'; end if;
  e := oyun.ref_engeli(p, r);
  if e is not null then raise exception '%', e; end if;
  insert into oyun.referandum_katilim(ref_id, secmen, zaman) values (r.id, p.id, t) on conflict do nothing;
  if not found then raise exception 'Bu halk oylamasında zaten oy kullandın.'; end if;
  insert into oyun.referandum_sandik(ref_id, il_id, evet, hayir) values (r.id, p.il_id, (p_oy = 'evet')::int, (p_oy = 'hayir')::int)
  on conflict (ref_id, il_id) do update set evet = oyun.referandum_sandik.evet + excluded.evet, hayir = oyun.referandum_sandik.hayir + excluded.hayir;
  return public.referandum_detay(p_id);
end $$;

-- ---------------------------------------------------------------------
-- ANAYASA DEĞİŞİKLİĞİ
--   veri: {madde: 'duzenleme', kod, deger}   bir kuralı anayasaya bağlar (kanun ve kararname artık değiştiremez)
--         {madde: 'serbest_birak', kod}       anayasadaki kuralı kanuna bırakır (Meclis yeniden düzenleyebilir)
--         {madde: 'kararname_sinir', deger}   cumhurbaşkanının günlük kararname sayısı (0-5)
--         {madde: 'vergi_tavani', deger}      gelir vergisinin anayasal tavanı (%20-45)
-- ---------------------------------------------------------------------
create or replace function oyun.anayasa_dogrula(p_veri jsonb) returns jsonb language plpgsql stable as $$
declare m text := p_veri ->> 'madde'; a oyun.anayasa; v numeric;
begin
  if m = 'duzenleme' then
    v := oyun.duzenleme_dogrula(p_veri ->> 'kod', (p_veri ->> 'deger')::numeric, 'ulke');
    return jsonb_build_object('madde', m, 'kod', p_veri ->> 'kod', 'deger', v);
  elsif m = 'serbest_birak' then
    if not exists (select 1 from oyun.duzenlemeler where kod = p_veri ->> 'kod' and kaynak = 'anayasa') then
      raise exception 'Bu kural zaten anayasada değil.';
    end if;
    return jsonb_build_object('madde', m, 'kod', p_veri ->> 'kod');
  elsif m in ('kararname_sinir','vergi_tavani') then
    select * into a from oyun.anayasa where kod = m;
    v := round((p_veri ->> 'deger')::numeric);
    if v is null or v < a.min or v > a.max then raise exception '"%" % ile % arasında olmalı.', a.ad, a.min, a.max; end if;
    if v = a.deger then raise exception 'Bu madde zaten bu değerde.'; end if;
    return jsonb_build_object('madde', m, 'deger', v);
  end if;
  raise exception 'Geçersiz anayasa maddesi.';
end $$;

create or replace function oyun.anayasa_aciklama(v jsonb) returns text language sql stable as $$
  select case v ->> 'madde'
    when 'duzenleme' then format('%s: %s olarak anayasaya bağlanır. Bundan sonra kanunla ya da kararnameyle değiştirilemez.',
                                 (select ad from oyun.duzenleme_tanim where kod = v ->> 'kod'), oyun.duz_yaz(v ->> 'kod', (v ->> 'deger')::numeric))
    when 'serbest_birak' then format('%s anayasadan çıkarılır; Meclis yeniden kanunla düzenleyebilir.', (select ad from oyun.duzenleme_tanim where kod = v ->> 'kod'))
    when 'kararname_sinir' then case when (v ->> 'deger')::numeric = 0 then 'Cumhurbaşkanının kararname yetkisi kaldırılır.'
                                     else format('Cumhurbaşkanı günde en fazla %s kararname çıkarabilir.', v ->> 'deger') end
    when 'vergi_tavani' then format('Gelir vergisinin anayasal tavanı %%%s olur.', v ->> 'deger') end
$$;

create or replace function oyun.anayasa_uygula(k oyun.kanunlar, t timestamptz) returns void language plpgsql as $$
declare v jsonb := k.veri; m text := k.veri ->> 'madde'; tv numeric;
begin
  if m = 'duzenleme' then
    perform oyun.duzenleme_uygula(v ->> 'kod', (v ->> 'deger')::numeric, 'anayasa', k.id, t);
  elsif m = 'serbest_birak' then
    update oyun.duzenlemeler set kaynak = 'kanun', ref_id = k.id, zaman = t where kod = v ->> 'kod' and kaynak = 'anayasa';
  elsif m in ('kararname_sinir','vergi_tavani') then
    update oyun.anayasa set deger = (v ->> 'deger')::numeric, kanun_id = k.id, zaman = t where kod = m;
    if m = 'vergi_tavani' then
      tv := (v ->> 'deger')::numeric;
      update oyun.ulke set vergi_ust = least(vergi_ust, tv), vergi_alt = least(vergi_alt, tv), vergi = least(vergi, tv),
        vergi_kanun = least(vergi_kanun, tv) where id = 1;
    end if;
  end if;
end $$;

-- İmza: anayasa değişikliği teklifine görüşme süresinde vekiller imza verir
create or replace function public.kanun_imza(p_id bigint, p_imza boolean default true) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar;
begin
  if not oyun.aktif_vekil(p.id) then raise exception 'Anayasa değişikliği teklifini yalnızca milletvekilleri imzalayabilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then raise exception 'Meclis Başkanı teklif imzalayamaz.'; end if;
  select * into k from oyun.kanunlar where id = p_id;
  if k.tur <> 'anayasa' then raise exception 'İmza yalnızca anayasa değişikliği tekliflerinde toplanır.'; end if;
  if k.durum <> 'gorusmede' or t >= k.oy_bas then raise exception 'İmza süresi bitti.'; end if;
  if k.teklif_eden = p.id then raise exception 'Teklif sahibinin imzası zaten var.'; end if;
  if p_imza then
    insert into oyun.kanun_oylari(kanun_id, asama, vekil, parti_id, oy, zaman) values (k.id, 'imza', p.id, p.parti_id, 'kabul', t)
    on conflict do nothing;
  else
    delete from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza' and vekil = p.id;
  end if;
  return public.kanun_detay(p_id);
end $$;

-- ---------------------------------------------------------------------
-- ZAMANLAYICI (tick içinden her dakika)
-- ---------------------------------------------------------------------
create or replace function oyun.mevzuat_tick(t timestamptz) returns void language plpgsql as $$
declare r oyun.referandumlar; s oyun.secimler; k oyun.kanunlar; ceza numeric; n int; toplam numeric; pr oyun.profiller; m numeric; yuzde numeric;
        ceza_an timestamptz;
begin
  -- halk oylaması: sandık açılır
  for r in select * from oyun.referandumlar where durum = 'bekliyor' and t >= oy_bas loop
    update oyun.referandumlar set durum = 'oylamada' where id = r.id;
    if not r.hatirlatma then
      perform oyun.push_konuya('s_tum', null, 'Bugün halk oylaması var! 🗳️', format('"%s" için sandıklar 20:00''ye kadar açık. Evet mi, Hayır mı?', r.baslik),
                               jsonb_build_object('ekran', 'referandum', 'id', r.id));
      update oyun.referandumlar set hatirlatma = true where id = r.id;
    end if;
  end loop;
  -- halk oylaması: sayım
  for r in select * from oyun.referandumlar where durum in ('bekliyor','oylamada') and t >= oy_bit order by oy_bit loop
    select coalesce(sum(evet), 0), coalesce(sum(hayir), 0) into r.evet, r.hayir from oyun.referandum_sandik where ref_id = r.id;
    r.secmen := oyun.ref_secmen_say(r);
    r.sonuc := case when r.evet > r.hayir then 'kabul' else 'ret' end;
    update oyun.referandumlar set durum = 'sonuclandi', evet = r.evet, hayir = r.hayir, secmen = r.secmen, sonuc = r.sonuc where id = r.id;
    yuzde := case when r.evet + r.hayir > 0 then round(100.0 * r.evet / (r.evet + r.hayir), 1) else 0 end;
    if r.sonuc = 'kabul' then
      perform oyun.kanun_yururluk(r.kanun_id, r.oy_bit, format('Halk oylamasında %%%s Evet oyuyla kabul edildi (%s Evet, %s Hayır).', replace(yuzde::text, '.', ','), r.evet, r.hayir));
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = r.oy_bit,
        sonuc_metin = format('Halk oylamasında reddedildi: %%%s Hayır (%s Evet, %s Hayır).', replace((100 - yuzde)::text, '.', ','), r.evet, r.hayir) where id = r.kanun_id;
      perform oyun.gazete_ekle('referandum', format('Halk oylaması sonucu: %s — REDDEDİLDİ', r.baslik),
        format('%s Evet, %s Hayır. Anayasa değişikliği yürürlüğe girmedi.', r.evet, r.hayir), r.id, r.oy_bit);
    end if;
    perform oyun.olay('referandum', format('Halk oylaması sonuçlandı: "%s" %s (%%%s Evet, katılım %s/%s).', r.baslik,
      case when r.sonuc = 'kabul' then 'KABUL EDİLDİ' else 'REDDEDİLDİ' end, replace(yuzde::text, '.', ','), r.evet + r.hayir, r.secmen), null, null, r.oy_bit);
  end loop;
  -- sandığa gitmeyene idari para cezası (genel seçim, belediye seçimi, 2. tur ve halk oylaması)
  -- Geriye yürümez: ceza ancak sandık açılmadan önce yürürlükte olan kurala göre kesilir.
  ceza_an := coalesce((select zaman from oyun.duzenlemeler where kod = 'oy_cezasi'), '-infinity'::timestamptz);
  for s in select * from oyun.secimler x where x.tur in ('mv','bel','cb2') and x.durum <> 'bekliyor' and x.oy_bit <= t and x.oy_bit > t - interval '3 days'
             and not exists (select 1 from oyun.oy_cezasi_kayit c where c.anahtar = 's' || x.id) loop
    n := 0; toplam := 0; ceza := case when ceza_an <= s.oy_bas then round(oyun.duz('oy_cezasi')) else 0 end;
    if ceza > 0 then
      for pr in select p.* from oyun.profiller p
                where not p.yasakli and p.son_gorulme > s.oy_bas - interval '7 days' and oyun.oy_engeli(p, s) is null
                  and not exists (select 1 from oyun.oylar o join oyun.secimler s2 on s2.id = o.secim_id where o.secmen = p.id and s2.oy_bas = s.oy_bas)
                  and (s.tur <> 'bel' or exists (select 1 from oyun.adaylar a where a.secim_id = s.id and a.il_id = p.il_id))
                  and (s.tur <> 'mv' or exists (select 1 from oyun.adaylar a join oyun.secimler o on o.id = a.secim_id
                                                 where o.tur = 'mv_on' and o.donem = s.donem and a.il_id = p.il_id and a.sira is not null))
                  and (s.tur <> 'cb2' or exists (select 1 from oyun.adaylar a where a.secim_id = s.id)) loop
        perform oyun.cuzdanim(pr.id);
        m := least(ceza, (select para from oyun.cuzdan where user_id = pr.id));
        if m > 0 then
          perform oyun.para_islem(pr.id, -m, 'ceza', 'Seçimde oy kullanmama idari para cezası', t);
          perform oyun.bildir(pr.id, format('Seçimde oy kullanmadığın için %s ₺ idari para cezası kesildi.', oyun.tl(m)), t);
          n := n + 1; toplam := toplam + m;
        end if;
      end loop;
    end if;
    insert into oyun.oy_cezasi_kayit values ('s' || s.id, ceza, n, toplam, t);
  end loop;
  for r in select * from oyun.referandumlar x where x.durum = 'sonuclandi' and x.oy_bit <= t and x.oy_bit > t - interval '3 days'
             and not exists (select 1 from oyun.oy_cezasi_kayit c where c.anahtar = 'r' || x.id) loop
    n := 0; toplam := 0; ceza := case when ceza_an <= r.oy_bas then round(oyun.duz('oy_cezasi')) else 0 end;
    if ceza > 0 then
      for pr in select p.* from oyun.profiller p
                where p.son_gorulme > r.oy_bas - interval '7 days' and oyun.ref_engeli(p, r) is null
                  and not exists (select 1 from oyun.referandum_katilim rk where rk.ref_id = r.id and rk.secmen = p.id) loop
        perform oyun.cuzdanim(pr.id);
        m := least(ceza, (select para from oyun.cuzdan where user_id = pr.id));
        if m > 0 then
          perform oyun.para_islem(pr.id, -m, 'ceza', 'Halk oylamasında oy kullanmama idari para cezası', t);
          perform oyun.bildir(pr.id, format('Halk oylamasında oy kullanmadığın için %s ₺ idari para cezası kesildi.', oyun.tl(m)), t);
          n := n + 1; toplam := toplam + m;
        end if;
      end loop;
    end if;
    insert into oyun.oy_cezasi_kayit values ('r' || r.id, ceza, n, toplam, t);
  end loop;
  perform oyun.arsa_tick(t);
end $$;

-- Her gece: borç taksitleri (ulke_hesap gideri zaten hazineden düştü)
create or replace function oyun.mevzuat_gunluk(g date, t timestamptz) returns void language plpgsql as $$
begin
  update oyun.borclar set kalan_gun = kalan_gun - 1 where kalan_gun > 0;
end $$;

-- ---------------------------------------------------------------------
-- MEVZUAT EKRANI
-- ---------------------------------------------------------------------
create or replace function public.mevzuat() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.ulke; cbyim boolean; vekilim boolean; baskan smallint;
begin
  select * into u from oyun.ulke where id = 1;
  cbyim := exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null);
  vekilim := oyun.aktif_vekil(p.id);
  baskan := (select il_id from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null limit 1);
  return jsonb_build_object(
    'cb_mi', cbyim, 'vekil_mi', vekilim, 'baskan_il', baskan, 'il_ad', (select ad from oyun.iller where id = p.il_id),
    'kurallar', (select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'tur', d.tur, 'min', d.min, 'max', d.max, 'adim', d.adim,
                   'varsayilan', d.varsayilan, 'aciklama', d.aciklama, 'oyuncu', d.oyuncu, 'devlet', d.devlet,
                   'deger', oyun.duz(d.kod), 'yazi', oyun.duz_yaz(d.kod, oyun.duz(d.kod)),
                   'kaynak', coalesce(z.kaynak, 'varsayilan'), 'kaynak_ad', oyun.kaynak_ad(coalesce(z.kaynak, 'varsayilan')), 'zaman', z.zaman,
                   'ref_no', case z.kaynak when 'kararname' then (select no from oyun.kararnameler where id = z.ref_id)
                                           when 'kanun' then (select no from oyun.kanunlar where id = z.ref_id)
                                           when 'anayasa' then (select no from oyun.kanunlar where id = z.ref_id) end,
                   'cb_engel', oyun.duzenleme_engel(d.kod, 'kararname'), 'kanun_engel', oyun.duzenleme_engel(d.kod, 'kanun'),
                   'hazir', case when z.kaynak = 'kararname' and z.zaman > t - interval '24 hours' then z.zaman + interval '24 hours' end)
                 order by d.sira)
                 from oyun.duzenleme_tanim d left join oyun.duzenlemeler z on z.kod = d.kod where d.kapsam = 'ulke'),
    'il_kurallar', (select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'tur', d.tur, 'min', d.min, 'max', d.max, 'adim', d.adim,
                   'aciklama', d.aciklama, 'oyuncu', d.oyuncu, 'devlet', d.devlet,
                   'deger', oyun.il_duz(p.il_id, d.kod), 'yazi', oyun.duz_yaz(d.kod, oyun.il_duz(p.il_id, d.kod))) order by d.sira)
                    from oyun.duzenleme_tanim d where d.kapsam = 'il'),
    'anayasa', (select jsonb_agg(jsonb_build_object('kod', a.kod, 'ad', a.ad, 'deger', a.deger, 'min', a.min, 'max', a.max, 'aciklama', a.aciklama,
                  'kanun_no', (select no from oyun.kanunlar where id = a.kanun_id), 'zaman', a.zaman) order by a.kod) from oyun.anayasa a),
    'kamu_varlik', round(u.kamu_varlik, 1), 'hazine', round(u.hazine, 1), 'enflasyon', round(u.enflasyon, 1),
    'tahvil_faiz', oyun.tahvil_faiz(),
    'borclar', coalesce((select jsonb_agg(jsonb_build_object('anapara', b.anapara, 'faiz', b.faiz, 'gunluk', round(b.gunluk, 3), 'kalan_gun', b.kalan_gun,
                  'kalan', round(b.gunluk * b.kalan_gun, 1), 'zaman', b.zaman) order by b.zaman desc) from oyun.borclar b where b.kalan_gun > 0), '[]'::jsonb),
    'borc_toplam', round(coalesce((select sum(gunluk * kalan_gun) from oyun.borclar where kalan_gun > 0), 0), 1),
    'beni_etkileyen', jsonb_build_object(
       'servet', case when oyun.duz('servet_vergisi') > 0 then floor(greatest(0, coalesce((select para from oyun.cuzdan where user_id = p.id), 0)
                      - round(250000 * u.endeks)) * oyun.duz('servet_vergisi') / 1000) else 0 end,
       'emlak', round(oyun.il_duz(p.il_id, 'emlak') * u.endeks),
       'vekil_kesinti', case when vekilim then oyun.vekil_kesinti_orani(p.id, t) end,
       'kumbara_saat', oyun.kumbara_saat(), 'seri_tavan', oyun.duz('seri_tavan'), 'aday_destek', oyun.duz('aday_destek'),
       'oy_cezasi', oyun.duz('oy_cezasi')),
    'referandumlar', public.referandumlar(10));
end $$;

create or replace function public.mevzuat_onizle(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  return oyun.duzenleme_etki(p_kod, oyun.duzenleme_dogrula(p_kod, p_deger, 'ulke'));
end $$;

-- Tahvil faizi: enflasyon yükseldikçe borçlanma pahalılaşır (60 günde geri ödenir)
create or replace function oyun.tahvil_faiz() returns numeric language sql stable as $$
  select round(oyun.sinir(8 + enflasyon / 2, 8, 80), 1) from oyun.ulke where id = 1
$$;

-- ---------------------------------------------------------------------
-- BELEDİYE KARARLARI
-- ---------------------------------------------------------------------
create or replace function public.belediye_duzenle(p_kod text, p_deger numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar := oyun.baskan_zorunlu(p); v numeric; d oyun.duzenleme_tanim;
        son timestamptz; onceki numeric; ilad text;
begin
  v := oyun.duzenleme_dogrula(p_kod, p_deger, 'il');
  select * into d from oyun.duzenleme_tanim where kod = p_kod;
  select zaman, deger into son, onceki from oyun.il_duzenleme where il_id = m.il_id and kod = p_kod;
  if coalesce(onceki, d.varsayilan) = v then raise exception 'Değişiklik yok.'; end if;
  if son is not null and son > t - interval '24 hours' then
    raise exception '"%" 24 saatte bir değiştirilebilir (sonraki: %).', d.ad, to_char((son + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  insert into oyun.il_duzenleme(il_id, kod, deger, baskan, zaman) values (m.il_id, p_kod, v, p.id, t)
  on conflict (il_id, kod) do update set deger = excluded.deger, baskan = excluded.baskan, zaman = excluded.zaman;
  select ad into ilad from oyun.iller where id = m.il_id;
  perform oyun.gazete_ekle('belediye', format('%s Belediye Meclisi kararı: %s %s', ilad, d.ad, oyun.duz_yaz(p_kod, v)), d.oyuncu, null, t);
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s: %s %s → %s.', ilad, p.kad, d.ad, oyun.duz_yaz(p_kod, coalesce(onceki, d.varsayilan)), oyun.duz_yaz(p_kod, v)), m.il_id, p.parti_id, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.id, t, format('%s Belediyesi: %s artık %s. %s', ilad, d.ad, oyun.duz_yaz(p_kod, v), d.oyuncu)
    from oyun.profiller x where x.il_id = m.il_id and x.id <> p.id and not x.yasakli;
  return public.belediye_paneli();
end $$;

-- Belediye gelir işlemleri (negatif maliyetli "yatırım"): imar barışı ve arsa satışı
alter table oyun.belediye_yatirimlari add column if not exists tur text not null default 'yatirim';
insert into oyun.belediye_yatirimlari(kod, ad, aciklama, gun, bekleme_saat, gelisim, memnuniyet, sira, tur) values
 ('imar_barisi','İmar barışı','Kaçak yapılara harç karşılığı yapı kayıt belgesi. Kasaya 4 günlük taban gelir girer. Hemşehriye: kayıt dışı konutlar yasallaşınca kira ve geçim masrafı 14 gün %8 düşer. Bedeli: çarpık kentleşme gelişmişliği −3 düşürür; ildeki maaşlar kalıcı olarak yaklaşık %1,2 azalır.',-4,720,-3,2,3,'gelir'),
 ('arsa_satisi','Belediye arsası ihalesi','Kamu arazisi 48 saatlik açık artırmaya çıkar. O ilde yaşayan oyuncular pey sürer; kazanan arsanın sahibi olur ve her gün bedelin binde 4''ü kadar kira geliri alır. Kasaya, satış bedeline göre 6 günlük taban gelir civarında para girer. Diğer hemşehriler için yeşil alan azalır: gelişmişlik −1 (maaşlar ~%0,4 düşer), memnuniyet −3.',-6,336,-1,-3,4,'gelir')
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, gun = excluded.gun, bekleme_saat = excluded.bekleme_saat,
  gelisim = excluded.gelisim, memnuniyet = excluded.memnuniyet, sira = excluded.sira, tur = excluded.tur;

-- Belediye paneline il kuralları eklenir
create or replace function oyun.il_kurallar_json(p_il smallint, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_agg(jsonb_build_object('kod', d.kod, 'ad', d.ad, 'birim', d.birim, 'tur', d.tur, 'min', d.min, 'max', d.max, 'adim', d.adim,
           'aciklama', d.aciklama, 'oyuncu', d.oyuncu, 'devlet', d.devlet, 'deger', oyun.il_duz(p_il, d.kod),
           'yazi', oyun.duz_yaz(d.kod, oyun.il_duz(p_il, d.kod)),
           'hazir', (select z.zaman + interval '24 hours' from oyun.il_duzenleme z where z.il_id = p_il and z.kod = d.kod and z.zaman > t - interval '24 hours'),
           'gunluk_gelir', case when d.kod = 'emlak' then round(oyun.il_duz(p_il, 'emlak') * (select endeks from oyun.ulke where id = 1)
                                                               * oyun.nufus('il_hane') * (select mv from oyun.iller where id = p_il) / 600 / 1e9, 4) end,
           'birim_maliyet', case when d.kod = 'hosgeldin' then round(oyun.il_duz(p_il, 'hosgeldin') * 2000 / 1e9, 4) end) order by d.sira)
  from oyun.duzenleme_tanim d where d.kapsam = 'il'
$$;

-- ---------------------------------------------------------------------
-- BAKAN ADAYLARI (cumhurbaşkanının atama ekranı için arama)
-- ---------------------------------------------------------------------
create or replace function public.bakan_adaylari(p_ara text default '') returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a text := lower(btrim(coalesce(p_ara, '')));
begin
  perform oyun.cb_zorunlu(p);
  return coalesce((select jsonb_agg(x order by (x ->> 'uygun')::boolean desc, (x ->> 'kidem')::numeric desc) from (
    select jsonb_build_object('kad', pr.kad, 'il', (select ad from oyun.iller where id = pr.il_id), 'parti', oyun.parti_json(pr.parti_id),
             'kidem', oyun.kidem_puani(pr.id), 'statu', oyun.statu_ad(oyun.statu_basamak(oyun.kidem_puani(pr.id))),
             'gorev', oyun.rol_cakisma(pr.id, 'bakan'),
             'bakanlik', (select b.ad from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik where m.user_id = pr.id and m.tur = 'bakan' and m.bit is null),
             'uygun', oyun.rol_cakisma(pr.id, 'bakan') is null and oyun.uyari(pr, t) is null,
             'engel', coalesce(oyun.uyari(pr, t), case when oyun.rol_cakisma(pr.id, 'bakan') is not null then 'Şu an ' || oyun.rol_cakisma(pr.id, 'bakan') || ' görevinde' end)) x
    from oyun.profiller pr
    where not pr.yasakli and pr.id <> p.id and (a = '' or lower(pr.kad) like a || '%' or lower(pr.kad) like '%' || a || '%')
    order by (lower(pr.kad) like a || '%') desc, pr.son_gorulme desc nulls last limit 25) y), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- VAATLER: her yeni kuralın vaat karşılığı
-- ---------------------------------------------------------------------
insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama) values
 ('beyanname','servet_vergisi','Servet vergisini değiştireceğiz','binde','surekli',null,0,10,40,'Büyük servetlerden günlük vergi. Artırmak hazineye gelir getirir, büyümeyi biraz düşürür.'),
 ('beyanname','yeni_hibe','Yeni vatandaşa hoş geldin hibesi vereceğiz','tl','surekli','>=',1000,50000,41,'Oyuna yeni katılan her oyuncuya tek seferlik hibe.'),
 ('beyanname','aday_destek','Aday olmayı ucuzlatacağız (siyasi katılım fonu)','yuzde','surekli','>=',10,100,42,'Aday adaylığı ücretinin bu kadarını hazine öder.'),
 ('beyanname','seri_tavan','Düzenli çalışana daha yüksek devamlılık primi','yuzde','surekli','>=',35,60,43,'Seri priminin tavanı. Yükseltmek enflasyonu biraz artırır.'),
 ('beyanname','kumbara_saat','Esnek çalışma: maaş daha uzun birikecek','saat','surekli','>=',9,12,44,'Maaş kumbarasının kapasitesi. Büyümeyi biraz düşürür.'),
 ('beyanname','oy_cezasi','Sandığa gitmeyene cezayı değiştireceğiz','tl','surekli',null,0,5000,45,'Oy kullanmayan oyuncuya idari para cezası.'),
 ('beyanname','vekil_kesinti','Meclis''e gelmeyen vekilin maaşını keseceğiz','yuzde','surekli','>=',5,50,46,'Oylamalara katılmayan vekilin maaşından kesinti.'),
 ('beyanname','ozellestirme','Özelleştirmeyle hazineye kaynak yaratacağız','yok','tek',null,null,null,47,'Görev süresinde en az bir özelleştirme kararı.'),
 ('beyanname','referandum','Anayasa değişikliğini halkoyuna götüreceğiz','yok','tek',null,null,null,48,'Görev süresinde en az bir halk oylaması yapılır.'),
 ('mv','servet_vergisi','Servet vergisini kanunla belirleyeceğim','binde','tek',null,0,10,10,'Bu değeri getiren kanuna ya da anayasa değişikliğine kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','oy_cezasi','Sandığa gitmeyene cezayı kanunla belirleyeceğim','tl','tek',null,0,5000,11,'Bu değeri getiren kanuna kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','yeni_hibe','Yeni vatandaş hibesini kanunlaştıracağım','tl','tek','>=',1000,50000,12,'Bu hibeyi getiren kanuna kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','vekil_kesinti','Devamsız vekile maaş kesintisi getireceğim','yuzde','tek','>=',5,50,13,'Bu kesintiyi getiren kanuna kabul oyu verirsem ve yürürlüğe girerse tutulur.'),
 ('mv','anayasa_imza','Anayasa değişikliği teklifine imza vereceğim','yok','tek',null,null,null,14,'Görev süresinde bir anayasa değişikliği teklifine imza verirsem tutulur.'),
 ('bel','emlak','Emlak vergisini değiştireceğim','tl_gun','surekli',null,0,300,9,'İlde yaşayan herkesten günlük emlak vergisi. Artırmak belediye kasasına gelir getirir.'),
 ('bel','hosgeldin','Yeni hemşehrilere hoş geldin desteği vereceğim','tl','surekli','>=',500,20000,10,'İle yerleşen oyuncuya bir kez ödenir; ilin nüfusunu büyütür.'),
 ('bel','imar_barisi','İmar barışı çıkaracağım','yok','tek',null,null,null,11,'Kasaya gelir getirir, gelişmişliği düşürür.')
on conflict (kapsam, kod) do update set ad = excluded.ad, birim = excluded.birim, tip = excluded.tip, yon = excluded.yon,
  min = excluded.min, max = excluded.max, sira = excluded.sira, aciklama = excluded.aciklama;

-- Bir vaadin "bugünkü değeri"
create or replace function oyun.vaat_mevcut(p_kapsam text, p_kod text, p_il smallint, p_parti bigint) returns numeric language sql stable as $$
  select case
    when p_kod in (select kod from oyun.duzenleme_tanim where kapsam = 'ulke') then oyun.duz(p_kod)
    when p_kod in (select kod from oyun.duzenleme_tanim where kapsam = 'il') then oyun.il_duz(p_il, p_kod)
    else (select case p_kod when 'asgari' then u.asgari when 'vergi' then u.vergi when 'kidem' then u.kidem_primi when 'destek' then u.destek
                   when 'tasinma' then u.tasinma_destek when 'vergi_tavan' then u.vergi_ust when 'belediye_payi' then u.belediye_payi
                   when 'baraj' then (select baraj from oyun.ayarlar where id = 1) when 'parti_yardim' then u.parti_yardim
                   when 'kent_vergisi' then (select kent_vergisi from oyun.il_durum where il_id = p_il)
                   when 'hemsehri' then (select hemsehri from oyun.il_durum where il_id = p_il)
                   when 'uye' then (select count(*) from oyun.profiller where parti_id = p_parti)
                   when 'kasa' then (select round(kasa) from oyun.partiler where id = p_parti)
                   when 'aday_ucret' then (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = p_parti) end
          from oyun.ulke u where u.id = 1) end
$$;

-- Profil zaman damgaları oyun saatini kullanır (üretimde oyun saati = gerçek saat; testte test saati)
alter table oyun.profiller alter column bildirim_okundu set default oyun.simdi();
alter table oyun.profiller alter column olusturma set default oyun.simdi();
alter table oyun.profiller alter column il_at set default oyun.simdi();


-- ---------------------------------------------------------------------
-- ARSA İHALESİ VE MÜLKLER (belediye arsası satışının oyuncuya doğrudan karşılığı)
-- ---------------------------------------------------------------------
create table if not exists oyun.arsa_ihale(
  id         bigserial primary key,
  il_id      smallint not null references oyun.iller(id),
  baskan     uuid,
  muhammen   numeric not null,          -- tahmini bedel (₺): açılış fiyatı
  bas        timestamptz not null,
  bit        timestamptz not null,
  en_yuksek  numeric,
  en_yuksek_user uuid references oyun.profiller(id) on delete set null,
  teklif_sayisi int not null default 0,
  durum      text not null default 'acik' check (durum in ('acik','satildi','satilamadi'))
);
create table if not exists oyun.mulkler(
  id       bigserial primary key,
  user_id  uuid not null references oyun.profiller(id) on delete cascade,
  il_id    smallint not null,
  tur      text not null default 'arsa',
  bedel    numeric not null,
  gunluk   numeric not null,            -- günlük kira geliri (₺)
  alis     timestamptz not null,
  ihale_id bigint
);
create index if not exists mulkler_user on oyun.mulkler(user_id);

create or replace function oyun.arsa_muhammen(p_il smallint) returns numeric language sql stable as $$
  select round(25000 * u.endeks * (1 + i.mv / 20.0) * (0.5 + d.gelisim / 100) / 1000) * 1000
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$$;

create or replace function oyun.arsa_ihale_ac(p_il smallint, p oyun.profiller, t timestamptz) returns bigint language plpgsql as $$
declare yeni bigint; ilad text; mh numeric := oyun.arsa_muhammen(p_il);
begin
  if exists (select 1 from oyun.arsa_ihale where il_id = p_il and durum = 'acik') then raise exception 'İlde süren bir arsa ihalesi var.'; end if;
  insert into oyun.arsa_ihale(il_id, baskan, muhammen, bas, bit) values (p_il, p.id, mh, t, t + interval '48 hours') returning id into yeni;
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.gazete_ekle('belediye', format('%s Belediyesi arsa satış ihalesi', ilad),
    format('Muhammen bedel %s ₺. Teklifler 48 saat boyunca açık artırma usulüyle alınır; yalnızca ilde yaşayan vatandaşlar katılabilir.', oyun.tl(mh)), yeni, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.id, t, format('%s Belediyesi arsa ihalesine çıktı: açılış %s ₺, 48 saat. Kazanan her gün kira geliri alır (Gündem).', ilad, oyun.tl(mh))
    from oyun.profiller x where x.il_id = p_il and x.id <> p.id and not x.yasakli;
  perform oyun.olay('belediye', format('%s Belediye Başkanı %s bir belediye arsasını ihaleye çıkardı.', ilad, p.kad), p_il, p.parti_id, t);
  return yeni;
end $$;

create or replace function public.arsa_teklif(p_ihale bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.arsa_ihale; asgari numeric; tutar numeric := round(p_tutar);
begin
  select * into a from oyun.arsa_ihale where id = p_ihale for update;
  if a.id is null or a.durum <> 'acik' or t >= a.bit then raise exception 'Bu ihale açık değil.'; end if;
  if p.il_id <> a.il_id then raise exception 'İhaleye yalnızca o ilde yaşayan vatandaşlar katılabilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null and il_id = a.il_id) then
    raise exception 'Belediye başkanı kendi belediyesinin ihalesine katılamaz.';
  end if;
  if oyun.uyari(p, t) is not null then raise exception 'İhaleye katılmak için: %', oyun.uyari(p, t); end if;
  if a.en_yuksek_user = p.id then raise exception 'En yüksek teklif zaten senin.'; end if;
  asgari := case when a.en_yuksek is null then a.muhammen else ceil(a.en_yuksek * 1.05 / 100) * 100 end;
  if tutar is null or tutar < asgari then raise exception 'Teklif en az % ₺ olmalı.', oyun.tl(asgari); end if;
  perform oyun.para_islem(p.id, -tutar, 'ihale', format('%s arsa ihalesi teklifi (teminat)', (select ad from oyun.iller where id = a.il_id)), t);
  if a.en_yuksek_user is not null then
    perform oyun.para_islem(a.en_yuksek_user, a.en_yuksek, 'ihale_iade', 'Arsa ihalesinde teklifin geçildi: teminat iadesi', t);
    perform oyun.bildir(a.en_yuksek_user, format('Arsa ihalesinde %s senin teklifini %s ₺ ile geçti. Teminatın iade edildi.', p.kad, oyun.tl(tutar)), t);
  end if;
  update oyun.arsa_ihale set en_yuksek = tutar, en_yuksek_user = p.id, teklif_sayisi = teklif_sayisi + 1,
    bit = greatest(bit, t + interval '10 minutes') where id = a.id;   -- son dakika teklifinde süre 10 dk uzar
  return public.ihaleler();
end $$;

create or replace function public.ihaleler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'acik', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'il_id', a.il_id, 'il', i.ad, 'muhammen', a.muhammen, 'bit', a.bit,
               'en_yuksek', a.en_yuksek, 'lider', oyun.kad(a.en_yuksek_user), 'benim', a.en_yuksek_user = p.id, 'teklif_sayisi', a.teklif_sayisi,
               'asgari', case when a.en_yuksek is null then a.muhammen else ceil(a.en_yuksek * 1.05 / 100) * 100 end,
               'katilabilir', p.il_id = a.il_id, 'kira_orani', 0.004) order by a.bit)
             from oyun.arsa_ihale a join oyun.iller i on i.id = a.il_id where a.durum = 'acik' and (a.il_id = p.il_id or a.en_yuksek_user = p.id)), '[]'::jsonb),
    'mulklerim', coalesce((select jsonb_agg(jsonb_build_object('il', i.ad, 'tur', m.tur, 'bedel', m.bedel, 'gunluk', m.gunluk, 'alis', m.alis) order by m.alis)
             from oyun.mulkler m join oyun.iller i on i.id = m.il_id where m.user_id = p.id), '[]'::jsonb));
end $$;

create or replace function oyun.arsa_tick(t timestamptz) returns void language plpgsql as $$
declare a oyun.arsa_ihale; ilad text; gelir numeric; taban numeric;
begin
  for a in select * from oyun.arsa_ihale where durum = 'acik' and t >= bit order by bit loop
    select ad into ilad from oyun.iller where id = a.il_id;
    if a.en_yuksek_user is null then
      update oyun.arsa_ihale set durum = 'satilamadi' where id = a.id;
      perform oyun.olay('belediye', format('%s Belediyesi arsa ihalesine teklif gelmedi; arsa satılamadı.', ilad), a.il_id, null, a.bit);
      if a.baskan is not null then perform oyun.bildir(a.baskan, 'Arsa ihalesine teklif gelmedi; arsa belediyede kaldı.', a.bit); end if;
      continue;
    end if;
    taban := oyun.il_gunluk_gelir((select mv from oyun.iller where id = a.il_id)) * (select endeks from oyun.ulke where id = 1);
    gelir := round(6 * taban * least(3, a.en_yuksek / a.muhammen), 4);
    update oyun.arsa_ihale set durum = 'satildi' where id = a.id;
    insert into oyun.mulkler(user_id, il_id, tur, bedel, gunluk, alis, ihale_id)
    values (a.en_yuksek_user, a.il_id, 'arsa', a.en_yuksek, round(a.en_yuksek * 0.004), a.bit, a.id);
    update oyun.il_durum set kasa = coalesce(kasa, 0) + gelir, gelisim = oyun.sinir(gelisim - 1, 0, 100), memnuniyet = oyun.sinir(memnuniyet - 3, 0, 100)
      where il_id = a.il_id;
    perform oyun.bildir(a.en_yuksek_user, format('Tebrikler! %s''deki belediye arsasını %s ₺ ile aldın. Her gün %s ₺ kira geliri cüzdanına yatar.',
                                                  ilad, oyun.tl(a.en_yuksek), oyun.tl(round(a.en_yuksek * 0.004))), a.bit);
    perform oyun.gazete_ekle('belediye', format('%s Belediyesi arsa ihalesi sonuçlandı', ilad),
      format('Arsa %s ₺ bedelle %s''e satıldı. Belediye kasasına %s milyar ₺ girdi; yeşil alan azaldı.', oyun.tl(a.en_yuksek), oyun.kad(a.en_yuksek_user), replace(gelir::text, '.', ',')), a.id, a.bit);
    perform oyun.olay('belediye', format('%s''de belediye arsası %s ₺ ile %s''e satıldı.', ilad, oyun.tl(a.en_yuksek), oyun.kad(a.en_yuksek_user)), a.il_id, null, a.bit);
  end loop;
end $$;

-- Mülk kira geliri: günün ilk toplamasında (topla → gunluk_kesinti içinden)
create or replace function oyun.kira_ode(u uuid, t timestamptz) returns numeric language plpgsql as $$
declare k numeric := coalesce((select sum(gunluk) from oyun.mulkler where user_id = u), 0);
begin
  if k > 0 then perform oyun.para_islem(u, k, 'kira', 'Arsa kira geliri (günlük)', t); end if;
  return k;
end $$;
