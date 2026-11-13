-- =====================================================================
--  13.11.2026 · Halk Hareketleri 5.0 — "Sokağın Faturası"
--
--  İstek (Ercan): Eylemleri ve hükümetin karşı faaliyetlerini artır;
--  yaratıcı, özgün, gerçekçi olsun. Eylemin büyüklüğü ve süresi ülke
--  ekonomisine, devletin kasasına, şirketlere zarar versin; devlet ne kadar
--  kısa sürede söndürürse etkisi o kadar az olsun.
--
--  Ne eklendi:
--   1) Eylem biçimleri (tırmandırma merdiveni): Tencere-tava, Meydan mitingi,
--      Yürüyüş, Çadır kenti, Kepenk kapatma, Traktör/TIR konvoyu, Genel grev.
--      Her biçimin ekonomik profili (ticaret, turizm, üretim, lojistik, hizmet)
--      ve en az katılımcı şartı vardır; basamak basamak tırmanılır.
--   2) Hasar motoru (5 dakikada bir): kayıp = il ekonomisinin payı × biçim
--      katsayısı × eylemin gücü × süre çarpanı × hükümet tepki çarpanı.
--      Süre çarpanı ilk saatlerde 0,25'ten başlar, 3,5 günde 2,4'e çıkar:
--      hızlı söndürülen eylem az, uzayan eylem katlanarak zarar verir.
--      Hükümet ilk 1 saatte somut adım atarsa zarar %30 azalır; 3 saat
--      sessiz kalırsa her saat %2 büyür (en çok %30).
--   3) Zararın gittiği yerler: Hazine (kaybolan vergi, yeni kalem
--      "toplumsal_olay"), büyüme/enflasyon/işsizlik/memnuniyet (günlük
--      tavanlı), eylem ilindeki şirketlerin satışları (saatlik tahsil,
--      şirket hareketinde görünür), belediye kasası, borsa risk primi.
--      Eylem bitince "artçı" etki kalır; süresi eylemin dörtte biri.
--   4) Hükümet araçları: Kriz Koordinasyon Merkezi, Asgari hizmet genelgesi,
--      Alternatif lojistik koridoru, Esnafa zarar tazmini, Piyasa istikrar
--      paketi (Varlık Fonu), Grev erteleme kararı (CB), Maliyet faturası.
--   5) Eylemci araçları: biçim tırmandırma/yumuşatma, şirket sahipleri için
--      "kepenk indir", "Faturayı hükümete kes".
--   6) Kapanışta Ekonomik Etki Raporu ve hükümetin kriz karnesi (A–F).
--
--  Oyuncu verisi değişmez: yalnız yeni tablo, yeni işlev, katalog ve
--  tarife satırları (on conflict). Mevcut 3 aktif eylemin sayacı bu
--  güncellemeyle sıfırdan başlar (geriye dönük zarar yazılmaz).
-- =====================================================================

-- ---------- Ayarlar (Süper Yönetici değiştirebilir) ----------
insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira) values
 ('halk_bedel_aktif',1,'açık/kapalı','kural','Eylemlerin ekonomik bedeli','1: sokak eylemleri ekonomiye, Hazine''ye, şirketlere ve belediyeye zarar verir. 0: kapalı.',910),
 ('halk_bedel_carpan',1,'kat','kural','Eylem zararı çarpanı','Bütün eylem zararlarını birlikte büyütür ya da küçültür (1 = varsayılan).',911),
 ('halk_bedel_sirket_carpan',1,'kat','kural','Eylemde şirket satış kaybı çarpanı','Eylem ilindeki şirketlerin satış kaybını büyütür ya da küçültür (1 = varsayılan).',912),
 ('halk_bedel_vergi_orani',0.30,'oran','kural','Eylem üretim kaybının vergiye yansıması','Eylemin durdurduğu üretimin bu oranı Hazine''nin vergi kaybı olarak yazılır.',913),
 ('halk_piyasa_destek',5,'milyar ₺','kural','Piyasa istikrar paketi tutarı','Piyasa istikrar paketinde Varlık Fonu''ndan kullanılan tutar (milyar ₺).',914)
on conflict (kod) do nothing;

create or replace function oyun.sokak_tarife(p_kod text, p_vars numeric)
returns numeric language sql stable set search_path to '' as $$
 select coalesce((select deger from oyun.tarife where kod=p_kod), p_vars)
$$;

insert into oyun.hazine_kalem(kod,ad,sinif,sira,aciklama) values
 ('toplumsal_olay','Toplumsal olaylar: vergi kaybı','gider',41,'Sokak eylemlerinin durdurduğu üretim yüzünden kaybedilen vergi geliri. Eylem büyüdükçe ve uzadıkça artar.')
on conflict (kod) do nothing;

-- ---------- 1) Eylem biçimleri kataloğu ----------
create table if not exists oyun.sokak_bicim(
 kod text primary key,
 ad text not null,
 ikon text not null default '📣',
 basamak integer not null,
 aciklama text not null,
 gercek text,
 min_kisi integer not null default 1,
 bedel numeric not null default 0,
 guc numeric not null default 0,
 k_gsyh numeric not null,
 k_ticaret numeric not null default 0,
 k_turizm numeric not null default 0,
 k_uretim numeric not null default 0,
 k_lojistik numeric not null default 0,
 k_hizmet numeric not null default 0,
 lojistik_pay numeric not null default 0.1,
 belediye numeric not null default 0.5,
 issizlik boolean not null default false,
 karsi text,
 sira integer not null default 0
);
alter table oyun.sokak_bicim enable row level security;

insert into oyun.sokak_bicim(kod,ad,ikon,basamak,aciklama,gercek,min_kisi,bedel,guc,k_gsyh,k_ticaret,k_turizm,k_uretim,k_lojistik,k_hizmet,lojistik_pay,belediye,issizlik,karsi,sira) values
 ('tencere','Tencere-tava eylemi','🍳',0,
  'Her akşam 21.00''de pencerelerden ve balkonlardan ses verilir. Ekonomiye neredeyse zarar vermez; o saatte meydanın gücüne +4 ekler ve kamuoyunun sempatisini kazanır.',
  'Dünyada ve Türkiye''de en düşük riskli, en geniş katılımlı protesto biçimlerinden biri.',
  2,0,0, 0.004,0.01,0.01,0,0,0, 0,0,false,
  'Ekonomik bedeli yok denecek kadar azdır; hükümet bu biçime çoğunlukla açıklama ve uzlaşmayla karşılık verir.',10),
 ('miting','Meydan mitingi','📣',1,
  'Kalabalık meydanda toplanır, kürsüden konuşulur. Çevredeki dükkânların ve kafelerin cirosu bir miktar düşer.',
  'Türkiye''de 2911 sayılı Toplantı ve Gösteri Yürüyüşleri Kanunu çerçevesinde en yaygın eylem biçimi.',
  1,0,0, 0.03,0.10,0.08,0.02,0.05,0.03, 0.15,0.3,false,
  'Kriz Koordinasyon Merkezi ve asgari hizmet genelgesi zararı azaltır.',20),
 ('yuruyus','Yürüyüş ve kortej','🚶',2,
  'Ana caddeler kortejle kapanır; trafik durur, alışveriş caddeleri ve servisler etkilenir.',
  'Kortejler genellikle valiliğin bildirdiği güzergâhta yürür; güzergâh dışına taşmak gerginliği artırır.',
  3,25000,3, 0.05,0.18,0.15,0.03,0.18,0.05, 0.30,0.6,false,
  'Alternatif lojistik koridoru ve trafik planı zararı yarıya indirir.',30),
 ('cadir','Çadır kenti / direniş nöbeti','⛺',2,
  'Meydana çadır kurulur, eylem gece gündüz sürer. Zarar ilk gün düşüktür ama her gün büyür; güç de her 12 saatte bir birikir (en çok +4).',
  'Uzun soluklu direniş nöbetleri kamuoyunda zamanla büyür; hükümet için en pahalısı onları uzun süre görmezden gelmektir.',
  3,40000,2, 0.025,0.08,0.12,0.02,0.03,0.02, 0.10,0.5,false,
  'Hızlı diyalog ve uzlaşma; zaman geçtikçe zarar katlanır.',40),
 ('kepenk','Kepenk kapatma (esnaf eylemi)','🏪',3,
  'Esnaf dükkânlarını kapatır, ticaret durur. Eylem ilinde işletmesi olan şirket sahipleri işletmeleriyle eyleme katılabilir: kepenk indiren her şirket meydanın gücüne +1,5 ekler ama kendi satışını da kaybeder.',
  'Esnaf ve sanatkâr odalarının çağrısıyla yapılan kepenk kapatma eylemleri Türkiye''de bilinen bir protesto geleneğidir.',
  4,60000,4, 0.10,0.55,0.20,0.05,0.05,0.10, 0.10,1.0,true,
  'Esnafa zarar tazmini paketi kepenk eyleminin gücünü yarıya indirir.',50),
 ('konvoy','Traktör ve TIR konvoyu','🚜',3,
  'Otoyollar ve şehir girişleri konvoyla yavaşlatılır. Fabrikaların tedariki aksar, raflar boşalır, fiyatlar yükselir.',
  'Çiftçi ve nakliyeci konvoyları gerçek dünyada en çok tedarik zincirini vurur; etkisi enflasyonda hissedilir.',
  5,80000,5, 0.09,0.12,0.10,0.35,0.60,0.05, 0.60,0.7,false,
  'Alternatif lojistik koridoru bu biçimin en etkili ilacıdır.',60),
 ('genel_grev','Genel grev ve iş bırakma','🛠️',4,
  'İşyerleri, fabrikalar ve kamu hizmetleri durur. En pahalı ve en güçlü biçim; uzarsa işsizlik de artar.',
  'Gerçekte Cumhurbaşkanı 6356 sayılı Kanun m.63 ile grevi genel sağlık veya millî güvenlik gerekçesiyle 60 gün erteleyebilir; oyunda bu karar da var.',
  8,120000,8, 0.16,0.45,0.30,0.50,0.45,0.35, 0.25,1.0,true,
  'Cumhurbaşkanının grev erteleme kararı, asgari hizmet genelgesi ve piyasa istikrar paketi.',70)
on conflict (kod) do update set ad=excluded.ad, ikon=excluded.ikon, basamak=excluded.basamak, aciklama=excluded.aciklama,
 gercek=excluded.gercek, min_kisi=excluded.min_kisi, bedel=excluded.bedel, guc=excluded.guc, k_gsyh=excluded.k_gsyh,
 k_ticaret=excluded.k_ticaret, k_turizm=excluded.k_turizm, k_uretim=excluded.k_uretim, k_lojistik=excluded.k_lojistik,
 k_hizmet=excluded.k_hizmet, lojistik_pay=excluded.lojistik_pay, belediye=excluded.belediye, issizlik=excluded.issizlik,
 karsi=excluded.karsi, sira=excluded.sira;

-- ---------- 2) Eylem başına fatura ----------
create table if not exists oyun.sokak_bedel(
 eylem_id bigint primary key references oyun.sokak_eylem(id),
 bicim text not null default 'miting' references oyun.sokak_bicim(kod),
 bicim_zaman timestamptz,
 bicim_yapan uuid,
 saat_baz timestamptz not null,
 son timestamptz not null,
 sirket_son timestamptz,
 saatlik_gsyh numeric not null default 0,
 saatlik_hazine numeric not null default 0,
 saatlik_sirket numeric not null default 0,
 toplam_gsyh numeric not null default 0,
 toplam_hazine numeric not null default 0,
 toplam_sirket numeric not null default 0,
 toplam_belediye numeric not null default 0,
 tazmin numeric not null default 0,
 artci_gsyh numeric not null default 0,
 birikim jsonb not null default '{}'::jsonb,
 guncel jsonb not null default '{}'::jsonb,
 ilk_tepki timestamptz,
 kapandi timestamptz,
 artci_bitis timestamptz,
 son_saatlik numeric,
 esik_no integer not null default 0,
 cadir_asama integer not null default 0,
 tencere_gun date,
 rapor jsonb,
 karne text,
 puan integer
);
alter table oyun.sokak_bedel enable row level security;
create index if not exists sokak_bedel_artci on oyun.sokak_bedel(artci_bitis) where kapandi is not null;

create table if not exists oyun.sokak_bedel_saat(
 eylem_id bigint not null references oyun.sokak_eylem(id),
 saat timestamptz not null,
 gsyh numeric not null default 0,
 hazine numeric not null default 0,
 sirket numeric not null default 0,
 belediye numeric not null default 0,
 primary key(eylem_id,saat)
);
alter table oyun.sokak_bedel_saat enable row level security;

create table if not exists oyun.sokak_bedel_sirket(
 eylem_id bigint not null references oyun.sokak_eylem(id),
 sirket_id bigint not null references oyun.sirketler(id),
 kayip numeric not null default 0,
 tazmin numeric not null default 0,
 kepenk boolean not null default false,
 kepenk_zaman timestamptz,
 kepenk_yapan uuid,
 etki_id bigint,
 bildirildi boolean not null default false,
 son timestamptz,
 primary key(eylem_id,sirket_id)
);
alter table oyun.sokak_bedel_sirket enable row level security;
create index if not exists sokak_bedel_sirket_sirket on oyun.sokak_bedel_sirket(sirket_id);

create table if not exists oyun.sokak_bedel_mudahale(
 id bigint generated by default as identity primary key,
 eylem_id bigint references oyun.sokak_eylem(id),
 taraf text not null default 'devlet',
 tur text not null,
 yapan uuid,
 unvan text,
 bedel numeric not null default 0,
 zaman timestamptz not null,
 bitis timestamptz not null,
 etki jsonb not null default '{}'::jsonb,
 metin text
);
alter table oyun.sokak_bedel_mudahale enable row level security;
create index if not exists sokak_bedel_mudahale_eylem on oyun.sokak_bedel_mudahale(eylem_id, tur, zaman desc);
create index if not exists sokak_bedel_mudahale_bitis on oyun.sokak_bedel_mudahale(bitis);

create table if not exists oyun.sokak_bedel_gun(
 gun date primary key,
 gsyh numeric not null default 0,
 hazine numeric not null default 0,
 sirket numeric not null default 0,
 belediye numeric not null default 0,
 buyume numeric not null default 0,
 enflasyon numeric not null default 0,
 memnuniyet numeric not null default 0,
 issizlik numeric not null default 0
);
alter table oyun.sokak_bedel_gun enable row level security;

-- ---------- 3) Yardımcılar ----------
create or replace function oyun.sokak_gsyh_gunluk()
returns numeric language sql stable set search_path to '' as $$
 select coalesce((select gsyh from oyun.makro_gunluk where gsyh>0 order by gun desc limit 1),
                 (select gsyh_baz from oyun.makro_ayar where id=1), 200)
$$;

create or replace function oyun.sokak_il_pay(p_il integer)
returns numeric language sql stable set search_path to '' as $$
 select coalesce(
  (select e.nufus::numeric*e.gsyh_kisi_usd from oyun.il_ekonomi e where e.il_id=p_il)
   / nullif((select sum(nufus::numeric*gsyh_kisi_usd) from oyun.il_ekonomi),0),
  1.0/81)
$$;

-- Süre çarpanı: ilk saatlerde 0,25; 12. saatte ~1; 24. saatte 1,21; 48. saatte 1,69; 72. saatte 2,17; en çok 2,4.
create or replace function oyun.sokak_sure_carpani(h numeric)
returns numeric language sql immutable set search_path to '' as $$
 select case when h is null or h<0 then 0.25
             when h<=12 then 0.25+0.06*h
             else least(2.4, 0.97+(h-12)*0.02) end
$$;

create or replace function oyun.sokak_tepki_carpani(baz timestamptz, ilk timestamptz, t timestamptz)
returns numeric language sql immutable set search_path to '' as $$
 select case
  when ilk is not null and ilk<=baz+interval '1 hour' then 0.70
  when ilk is not null and ilk<=baz+interval '3 hours' then 0.85
  when ilk is not null and ilk<=baz+interval '8 hours' then 0.95
  when ilk is not null then 1.0
  when t<=baz+interval '3 hours' then 1.0
  else 1.0+least(0.30, extract(epoch from (t-baz-interval '3 hours'))/3600*0.02) end
$$;

-- Hükümetin bu eyleme verdiği ilk somut yanıt (hangi araçla olursa olsun).
create or replace function oyun.sokak_bedel_ilk_tepki(e bigint)
returns timestamptz language sql stable set search_path to '' as $$
 select min(z) from (
  select min(zaman) z from oyun.sokak_karar where eylem_id=e
  union all select min(zaman) from oyun.sokak_tedbir where eylem_id=e
  union all select min(zaman) from oyun.sokak_sert where eylem_id=e
  union all select min(zaman) from oyun.sokak_polis where eylem_id=e
  union all select min(zaman) from oyun.sokak_butce_mudahale where eylem_id=e
  union all select min(zaman) from oyun.sokak_seslenis where eylem_id=e
  union all select min(zaman) from oyun.sokak_yasak where eylem_id=e
  union all select min(zaman) from oyun.sokak_jest where eylem_id=e
  union all select min(zaman) from oyun.sokak_heyet where eylem_id=e
  union all select min(katilma) from oyun.sokak_gorevli where eylem_id=e and not coalesce(otomatik,false)
  union all select yanit_zamani from oyun.sokak_eylem where id=e
  union all select min(zaman) from oyun.sokak_bedel_mudahale where eylem_id=e and taraf='devlet'
 ) q
$$;

-- Etkin hükümet önlemlerinin bir kanaldaki toplam çarpanı (eylem_id boş olanlar ülke geneli).
create or replace function oyun.sokak_bedel_kat(e bigint, k text)
returns numeric language sql stable set search_path to '' as $$
 select coalesce(exp(sum(ln(greatest(0.05, least(3, (m.etki->>k)::numeric))))),1)
 from oyun.sokak_bedel_mudahale m
 where (m.eylem_id=e or m.eylem_id is null) and m.bitis>oyun.simdi() and m.etki ? k
$$;

create or replace function oyun.sokak_sektor_kanal(s text)
returns text language sql immutable set search_path to '' as $$
 select case
  when s in ('banka','medya','sigorta','yayinevi','gazete') then null
  when s in ('market','ticaret','elektronik_magaza','tekstil_magaza','oto_galeri','oto_servis','akaryakit','kuyumcu','restoran','kafe') then 'ticaret'
  when s in ('turizm','otel') then 'turizm'
  when s in ('sanayi','tarim','enerji','geri_donusum','insaat','fabrika','madencilik') then 'uretim'
  when s in ('lojistik','ulasim','e_ticaret') then 'lojistik'
  else 'hizmet' end
$$;

create or replace function oyun.sokak_gercek_katilimci(e bigint)
returns integer language sql stable set search_path to '' as $$
 select count(distinct p.id)::integer from oyun.sokak_eylem_destek dd join oyun.profiller p on p.id=dd.temsilci
 where dd.eylem_id=e and dd.destekci_tur='oyuncu' and dd.destek_turu='katilim' and dd.taraf='muhalefet'
   and not oyun.sokak_yaptirimli(p.id,e) and not p.yasakli
   and p.olusturma<oyun.simdi()-interval '3 days' and p.son_gorulme>oyun.simdi()-interval '14 days'
$$;

create or replace function oyun.sokak_bedel_org(x oyun.sokak_eylem, u uuid)
returns boolean language sql stable set search_path to '' as $$
 select u is not null and (u=x.baslatan
  or (x.org_tur='dernek' and exists(select 1 from oyun.dernekler d where d.id=x.org_id and d.baskan=u))
  or (coalesce(x.org_tur,'parti')<>'dernek' and x.parti_id is not null and exists(select 1 from oyun.partiler p where p.id=x.parti_id and p.gb=u)))
$$;

create or replace function oyun.sokak_bedel_unvan(u uuid, p_il integer)
returns text language sql stable set search_path to '' as $$
 select coalesce(
  (select case m.tur when 'cb' then 'Cumhurbaşkanı' when 'cb_yardimcisi' then 'Cumhurbaşkanı Yardımcısı'
     else case m.bakanlik when 'icisleri' then 'İçişleri Bakanı' when 'maliye' then 'Hazine ve Maliye Bakanı'
       when 'ticaret' then 'Ticaret Bakanı' when 'ulastirma' then 'Ulaştırma ve Altyapı Bakanı'
       when 'calisma' then 'Çalışma ve Sosyal Güvenlik Bakanı' when 'sanayi' then 'Sanayi ve Teknoloji Bakanı'
       when 'tarim' then 'Tarım ve Orman Bakanı' when 'adalet' then 'Adalet Bakanı' when 'egitim' then 'Millî Eğitim Bakanı'
       when 'saglik' then 'Sağlık Bakanı' when 'savunma' then 'Millî Savunma Bakanı' when 'disisleri' then 'Dışişleri Bakanı'
       else 'Bakan' end end
   from oyun.makamlar m where m.user_id=u and m.bit is null and m.tur in ('cb','bakan','cb_yardimcisi')
   order by (m.tur='cb') desc, (m.tur='bakan') desc limit 1),
  (select (select ad from oyun.iller where id=a.il_id)||' Valisi' from oyun.icisleri_atama a
    where a.hedef=u and a.tur='vali' and a.durum='aktif' and (a.bitis is null or a.bitis>oyun.simdi())
      and (p_il is null or a.il_id=p_il) limit 1))
$$;

-- Hükümet araçlarının yetkisi (sunucuda doğrulanır; istemcideki düğme yalnız gösterir).
create or replace function oyun.sokak_bedel_arac_yetki(k text, u uuid, p_il integer)
returns boolean language sql stable set search_path to '' as $$
 with m as (select tur, bakanlik from oyun.makamlar where user_id=u and bit is null),
 v as (select exists(select 1 from oyun.icisleri_atama a where a.hedef=u and a.tur='vali' and a.il_id=p_il and a.durum='aktif' and (a.bitis is null or a.bitis>oyun.simdi())) vali)
 select case k
  when 'kriz_masasi' then exists(select 1 from m where tur='cb' or tur='bakan' and bakanlik='icisleri') or (select vali from v)
  when 'asgari_hizmet' then exists(select 1 from m where tur='cb' or tur='bakan' and bakanlik='icisleri') or (select vali from v)
  when 'lojistik_koridor' then exists(select 1 from m where tur='cb' or tur='bakan' and bakanlik='ulastirma') or (select vali from v)
  when 'esnaf_destek' then exists(select 1 from m where tur='cb' or tur='bakan' and bakanlik in ('ticaret','maliye'))
  when 'piyasa_istikrar' then exists(select 1 from m where tur='cb' or tur='bakan' and bakanlik='maliye')
  when 'grev_erteleme' then exists(select 1 from m where tur='cb')
  when 'fatura' then exists(select 1 from m where tur in ('cb','bakan','cb_yardimcisi'))
  else false end
$$;

create or replace function oyun.sokak_tl(x numeric)
returns text language sql immutable set search_path to '' as $$
 select replace(to_char(round(coalesce(x,0)),'FM999G999G999G990'),',','.')||' ₺'
$$;

create or replace function oyun.sokak_milyar(x numeric)
returns text language sql immutable set search_path to '' as $$
 select case when abs(coalesce(x,0))>=1 then replace(round(x,2)::text,'.',',')||' milyar ₺'
             else replace(to_char(round(coalesce(x,0)*1000),'FM999G990'),',','.')||' milyon ₺' end
$$;

create or replace function oyun.sokak_bedel_satir(e bigint)
returns oyun.sokak_bedel language plpgsql set search_path to '' as $$
declare r oyun.sokak_bedel;
begin
 insert into oyun.sokak_bedel(eylem_id,saat_baz,son,sirket_son)
  select x.id, coalesce(x.baslangic,oyun.simdi()), coalesce(x.baslangic,oyun.simdi()), coalesce(x.baslangic,oyun.simdi())
  from oyun.sokak_eylem x where x.id=e and x.durum='aktif'
 on conflict (eylem_id) do nothing;
 select * into r from oyun.sokak_bedel where eylem_id=e;
 return r;
end $$;

-- ---------- 4) Şirket satış kaybı tahsili (saatte bir ve kapanışta) ----------
create or replace function oyun.sokak_bedel_sirket_tahsil(e bigint)
returns numeric language plpgsql security definer set search_path to '' as $$
declare b oyun.sokak_bedel; x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); s record; v_saat numeric; gelir numeric;
 kayip numeric; kep numeric; kanal text; top numeric:=0; carp numeric:=oyun.sokak_tarife('halk_bedel_sirket_carpan',1);
 il_ad text; v_gun2 date:=(oyun.simdi() at time zone 'Europe/Istanbul')::date; sahip uuid;
begin
 select * into b from oyun.sokak_bedel where eylem_id=e for update;
 if b.eylem_id is null then return 0; end if;
 select * into x from oyun.sokak_eylem where id=e;
 select ad into il_ad from oyun.iller where id=x.il_id;
 v_saat:=extract(epoch from (t-coalesce(b.sirket_son,b.saat_baz)))/3600;
 if v_saat<=0.02 then return 0; end if;
 for s in
  with op as (select sirket_id, il_id from oyun.eko_isletmeler union all select sirket_id, il_id from oyun.pazar_sirket),
  sk as (select sirket_id, count(*) filter (where il_id=x.il_id) il_n, count(*) top_n from op group by sirket_id
         having count(*) filter (where il_id=x.il_id)>0)
  select c.id, c.ad, c.sektor, c.kasa, c.kurucu, c.yonetici, sk.il_n, sk.top_n,
   coalesce((select sum(h.faaliyet_gelir) from oyun.sirket_hareket h where h.sirket_id=c.id and h.zaman>t-interval '24 hours' and h.faaliyet_gelir>0),0) g24,
   bs.kepenk, bs.kepenk_zaman, bs.bildirildi
  from sk join oyun.sirketler c on c.id=sk.sirket_id and c.aktif
  left join oyun.sokak_bedel_sirket bs on bs.eylem_id=e and bs.sirket_id=c.id
 loop
  kanal:=oyun.sokak_sektor_kanal(s.sektor);
  if kanal is null then continue; end if;
  gelir:=s.g24/24.0*s.il_n/greatest(1,s.top_n);
  if gelir<=0 then continue; end if;
  kayip:=gelir*coalesce((b.birikim->>kanal)::numeric,0)*carp;
  if coalesce(s.kepenk,false) then
   kep:=extract(epoch from (t-greatest(s.kepenk_zaman,coalesce(b.sirket_son,b.saat_baz))))/3600;
   kayip:=greatest(kayip, gelir*least(greatest(kep,0),v_saat));
  end if;
  kayip:=round(least(kayip, greatest(0,s.kasa)*0.02*greatest(v_saat,0.1), greatest(0,s.kasa)),2);
  if kayip<1 then continue; end if;
  update oyun.sirketler set kasa=kasa-kayip where id=s.id;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider)
   values(s.id,t,-kayip,format('Halk Hareketleri #%s (%s): eylem bölgesinde satış kaybı',e,il_ad),0,kayip);
  insert into oyun.sokak_bedel_sirket(eylem_id,sirket_id,kayip,son) values(e,s.id,kayip,t)
   on conflict (eylem_id,sirket_id) do update set kayip=oyun.sokak_bedel_sirket.kayip+excluded.kayip, son=excluded.son;
  if not coalesce(s.bildirildi,false) then
   sahip:=coalesce(s.yonetici,s.kurucu);
   if sahip is not null then
    perform oyun.bildir(sahip, format('🏪 %s ilindeki eylem (#%s) %s şirketinin oradaki satışlarını düşürüyor. Son saatlerdeki kayıp: %s. Eylem sürdükçe ve büyüdükçe kayıp artar; Halk Hareketleri › eylem › 💸 Bedel sekmesinden izleyebilirsiniz.', il_ad, e, s.ad, oyun.sokak_tl(kayip)));
   end if;
   if s.kurucu is not null and s.kurucu is distinct from sahip then
    perform oyun.bildir(s.kurucu, format('🏪 %s ilindeki eylem (#%s) %s şirketinizin satışlarını düşürüyor (%s).', il_ad, e, s.ad, oyun.sokak_tl(kayip)));
   end if;
   update oyun.sokak_bedel_sirket set bildirildi=true where eylem_id=e and sirket_id=s.id;
  end if;
  top:=top+kayip;
 end loop;
 update oyun.sokak_bedel set birikim='{}'::jsonb, sirket_son=t, toplam_sirket=toplam_sirket+top,
  saatlik_sirket=round(top/greatest(v_saat,0.1),2) where eylem_id=e;
 if top>0 then
  insert into oyun.sokak_bedel_saat(eylem_id,saat,sirket) values(e,date_trunc('hour',t),top)
   on conflict (eylem_id,saat) do update set sirket=oyun.sokak_bedel_saat.sirket+excluded.sirket;
  insert into oyun.sokak_bedel_gun(gun,sirket) values(v_gun2,top)
   on conflict (gun) do update set sirket=oyun.sokak_bedel_gun.sirket+excluded.sirket;
 end if;
 return top;
end $$;

-- ---------- 5) Kapanış raporu ve kriz karnesi ----------
create or replace function oyun.sokak_bedel_kapat(e bigint)
returns void language plpgsql security definer set search_path to '' as $$
declare b oyun.sokak_bedel; x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); kap timestamptz; sure numeric; tepki_dk numeric;
 oran numeric; v_puan int; harf text; artci numeric; il_ad text; bc oyun.sokak_bicim; rap jsonb; G numeric:=oyun.sokak_gsyh_gunluk(); msg text;
begin
 perform oyun.sokak_bedel_sirket_tahsil(e);
 select * into b from oyun.sokak_bedel where eylem_id=e for update;
 if b.eylem_id is null or b.kapandi is not null then return; end if;
 select * into x from oyun.sokak_eylem where id=e;
 select * into bc from oyun.sokak_bicim where kod=b.bicim;
 select ad into il_ad from oyun.iller where id=x.il_id;
 kap:=coalesce(x.kapandi,t);
 sure:=greatest(0,extract(epoch from (kap-b.saat_baz))/3600);
 tepki_dk:=case when b.ilk_tepki is null then null else greatest(0,extract(epoch from (b.ilk_tepki-b.saat_baz))/60) end;
 oran:=b.toplam_gsyh/greatest(G,1)*100;
 v_puan:=100
  -(case when sure<3 then 0 when sure<6 then 5 when sure<12 then 10 when sure<24 then 20 when sure<72 then 30 else 40 end)
  -(case when tepki_dk is null then 20 when tepki_dk<=60 then 0 when tepki_dk<=180 then 5 when tepki_dk<=480 then 10 else 20 end)
  -(case when oran<0.5 then 0 when oran<2 then 10 when oran<5 then 20 else 30 end)
  +(case when x.durum='yatisti' then 10 else 0 end)
  -(case when x.erken_secim_uyarisi then 20 else 0 end);
 v_puan:=greatest(0,least(100,v_puan));
 harf:=case when v_puan>=90 then 'A' when v_puan>=75 then 'B' when v_puan>=60 then 'C' when v_puan>=45 then 'D' else 'F' end;
 artci:=least(24,greatest(0.5,sure*0.25));
 rap:=jsonb_build_object('sure_saat',round(sure,1),'ilk_tepki_dk',round(tepki_dk),'gsyh',round(b.toplam_gsyh,4),
  'hazine',round(b.toplam_hazine,4),'sirket',round(b.toplam_sirket,2),'belediye',round(b.toplam_belediye,2),
  'tazmin',round(b.tazmin,2),'gsyh_oran',round(oran,2),'bicim',b.bicim,'bicim_ad',bc.ad,'durum',x.durum,
  'kapanma',x.kapanma_nedeni,'artci_saat',round(artci,1),'puan',v_puan,'karne',harf,
  'etkilenen_sirket',(select count(*) from oyun.sokak_bedel_sirket where eylem_id=e and kayip>0));
 update oyun.sokak_bedel set kapandi=kap, artci_bitis=t+make_interval(secs=>(artci*3600)::int), son_saatlik=saatlik_gsyh,
  son=t, rapor=rap, karne=harf, puan=v_puan where eylem_id=e;
 update oyun.sokak_bedel_sirket set kepenk=false where eylem_id=e and kepenk;
 msg:=format('📊 Ekonomik etki raporu · %s eylemi #%s %s saat sürdü. Üretim kaybı %s, Hazine''nin vergi kaybı %s, %s şirketin satış kaybı %s, belediye gelir kaybı %s. Hükümetin kriz karnesi: %s (%s/100). Piyasaların toparlanması yaklaşık %s saat sürecek.',
  il_ad, e, replace(round(sure,1)::text,'.',','), oyun.sokak_milyar(b.toplam_gsyh), oyun.sokak_milyar(b.toplam_hazine),
  (rap->>'etkilenen_sirket'), oyun.sokak_tl(b.toplam_sirket), oyun.sokak_tl(b.toplam_belediye), harf, v_puan, replace(round(artci,1)::text,'.',','));
 perform oyun.sokak_duyur(e, msg);
 perform oyun.olay('ekonomi', msg, x.il_id, x.parti_id);
 if b.toplam_gsyh>=1 then perform oyun.sokak_manset_yaz(format('%s eyleminin faturası: %s', il_ad, oyun.sokak_milyar(b.toplam_gsyh))); end if;
end $$;

-- ---------- 6) Hasar motoru ----------
create or replace function oyun.sokak_bedel_tick()
returns void language plpgsql security definer set search_path to '' as $$
declare t timestamptz:=oyun.simdi(); r record; b oyun.sokak_bedel; bc oyun.sokak_bicim; mt oyun.sokak_bicim; x oyun.sokak_eylem;
 G numeric:=oyun.sokak_gsyh_gunluk(); W numeric; dt numeric; h numeric; n int; yg numeric; D numeric; tk numeric; K numeric;
 ilk timestamptz; kirm numeric; ek numeric; ek_loj numeric; ek_ure numeric; mg numeric; ml numeric; mu numeric; ms numeric; mh numeric;
 Lh numeric; L numeric; hk numeric; yog numeric; bel numeric; v_kasa numeric; frac numeric; il_ad text;
 glob numeric:=oyun.sokak_tarife('halk_bedel_carpan',1); vo numeric:=oyun.sokak_tarife('halk_bedel_vergi_orani',0.30);
 top_L numeric:=0; top_hz numeric:=0; enf_w numeric:=0; iss_L numeric:=0; top_bel numeric:=0;
 esik numeric[]:=array[0.25,1,2.5,5,10,25,50]; i int; v_gun date; gn oyun.sokak_bedel_gun;
 dbuy numeric; denf numeric; dmem numeric; diss numeric; asama int; ist timestamp; birik jsonb;
begin
 if oyun.sokak_tarife('halk_bedel_aktif',1)<=0 then return; end if;
 if not coalesce((select aktif from oyun.sokak_eylem_ayar where id=1),false) then return; end if;
 if not pg_try_advisory_xact_lock(781231,55) then return; end if;
 select * into mt from oyun.sokak_bicim where kod='miting';

 insert into oyun.sokak_bedel(eylem_id,saat_baz,son,sirket_son)
  select e.id,coalesce(e.baslangic,t),coalesce(e.baslangic,t),coalesce(e.baslangic,t) from oyun.sokak_eylem e
  where e.durum='aktif' on conflict (eylem_id) do nothing;

 -- kapanan eylemler: rapor + artçı başlangıcı
 for r in select bb.eylem_id from oyun.sokak_bedel bb join oyun.sokak_eylem e on e.id=bb.eylem_id
          where bb.kapandi is null and e.durum<>'aktif' loop
  perform oyun.sokak_bedel_kapat(r.eylem_id);
 end loop;

 for r in select e.id from oyun.sokak_eylem e join oyun.sokak_bedel bb on bb.eylem_id=e.id
          where e.durum='aktif' and e.bitis>t and bb.kapandi is null order by e.id loop
  select * into x from oyun.sokak_eylem where id=r.id;
  select * into b from oyun.sokak_bedel where eylem_id=r.id for update;
  dt:=extract(epoch from (t-b.son))/3600;
  if dt<0.03 then continue; end if;
  if dt>1 then dt:=1; end if;
  select * into bc from oyun.sokak_bicim where kod=b.bicim;
  select ad into il_ad from oyun.iller where id=x.il_id;
  n:=oyun.sokak_gercek_katilimci(x.id);

  -- katılımcı biçimin şartının altına düşerse biçim çözülür, mitinge döner
  if bc.kod<>'miting' and n<bc.min_kisi then
   update oyun.sokak_meydan_etki set bitis=t where eylem_id=x.id and tur in ('bicim','cadir','tencere','kepenk') and bitis>t;
   update oyun.sokak_bedel_sirket set kepenk=false where eylem_id=x.id and kepenk;
   update oyun.sokak_bedel set bicim='miting', bicim_zaman=t, cadir_asama=0 where eylem_id=x.id;
   insert into oyun.sokak_bedel_mudahale(eylem_id,taraf,tur,zaman,bitis,metin)
    values(x.id,'eylem','bicim:miting',t,t,format('%s için en az %s gerçek katılımcı gerekiyordu; kalan %s kişiyle eylem mitinge döndü.',bc.ad,bc.min_kisi,n));
   perform oyun.sokak_duyur(x.id, format('%s %s meydanında katılım düştü: "%s" için en az %s gerçek katılımcı gerekiyordu, %s kişi kaldı. Eylem meydan mitingine döndü.', bc.ikon, il_ad, bc.ad, bc.min_kisi, n));
   b.bicim:='miting'; bc:=mt; b.cadir_asama:=0;
  end if;

  W:=oyun.sokak_il_pay(x.il_id);
  h:=greatest(0,extract(epoch from (t-b.saat_baz))/3600);
  D:=oyun.sokak_sure_carpani(h);
  ilk:=coalesce(b.ilk_tepki,oyun.sokak_bedel_ilk_tepki(x.id));
  tk:=oyun.sokak_tepki_carpani(b.saat_baz,ilk,t);
  yg:=case when n=0 then 0 else least(1,greatest(0,coalesce(x.seviye,0))/100.0)*(0.55+0.45*least(1,n/8.0)) end;
  kirm:=case when x.kirmizi_baslangic is not null then 1.25 else 1 end;
  ek:=0; ek_loj:=0; ek_ure:=0;
  if x.grev_bitis>t or exists(select 1 from oyun.sokak_hamle hh where hh.eylem_id=x.id and hh.durum='aktif' and hh.bitis>t and hh.tur='grev') then ek:=ek+0.05; ek_ure:=ek_ure+0.15; end if;
  if exists(select 1 from oyun.sokak_hamle hh where hh.eylem_id=x.id and hh.durum='aktif' and hh.bitis>t and hh.tur='yol') then ek:=ek+0.03; ek_loj:=ek_loj+0.20; end if;
  if exists(select 1 from oyun.sokak_isgal ii where ii.eylem_id=x.id and ii.durum='aktif' and ii.bitis>t) then ek:=ek+0.03; end if;
  mg:=oyun.sokak_bedel_kat(x.id,'gsyh'); ml:=oyun.sokak_bedel_kat(x.id,'lojistik'); mu:=oyun.sokak_bedel_kat(x.id,'uretim');
  ms:=oyun.sokak_bedel_kat(x.id,'sirket'); mh:=oyun.sokak_bedel_kat(x.id,'hizmet');
  K:=(bc.k_gsyh*case when bc.kod='cadir' then 1+least(1.5,h/48.0) else 1 end + ek)
     *(1-least(0.9,bc.lojistik_pay+ek_loj)*(1-ml));
  Lh:=G/24.0*W*K*yg*D*tk*kirm*mg*glob;
  Lh:=least(Lh, G/24.0*W*0.35);
  L:=Lh*dt;
  hk:=L*vo;

  -- şirket kanalları için yoğunluk-saat birikimi (saatlik tahsilde TL'ye çevrilir)
  yog:=yg*D*tk*kirm*ms*glob*dt;
  birik:=jsonb_build_object(
   'ticaret',coalesce((b.birikim->>'ticaret')::numeric,0)+(bc.k_ticaret+ek)*yog,
   'turizm',coalesce((b.birikim->>'turizm')::numeric,0)+bc.k_turizm*yog,
   'uretim',coalesce((b.birikim->>'uretim')::numeric,0)+(bc.k_uretim+ek_ure)*mu*yog,
   'lojistik',coalesce((b.birikim->>'lojistik')::numeric,0)+(bc.k_lojistik+ek_loj)*ml*yog,
   'hizmet',coalesce((b.birikim->>'hizmet')::numeric,0)+bc.k_hizmet*mh*yog);

  -- belediye gelir kaybı (TL)
  select kasa into v_kasa from oyun.il_durum where il_id=x.il_id;
  bel:=round(least(greatest(0,coalesce(v_kasa,0))*0.0012*bc.belediye*yg*D*tk*kirm*mg*glob*dt, greatest(0,coalesce(v_kasa,0))*0.02*dt),2);
  if bel>=1 then update oyun.il_durum set kasa=kasa-bel where il_id=x.il_id; else bel:=0; end if;

  top_L:=top_L+L; top_hz:=top_hz+hk; top_bel:=top_bel+bel;
  enf_w:=enf_w+L*(1+bc.lojistik_pay+ek_loj);
  if bc.issizlik and h>48 then iss_L:=iss_L+L; end if;

  update oyun.sokak_bedel set son=t, saatlik_gsyh=round(Lh,6), saatlik_hazine=round(Lh*vo,6),
   toplam_gsyh=round(toplam_gsyh+L,6), toplam_hazine=round(toplam_hazine+hk,6), toplam_belediye=round(toplam_belediye+bel,2), birikim=birik,
   ilk_tepki=ilk, bicim=b.bicim,
   guncel=jsonb_build_object('yogunluk',round(yg,3),'sure_carpani',round(D,3),'tepki_carpani',round(tk,3),'katilimci',n,
     'katsayi',round(K,4),'il_pay',round(W,4),'kirmizi',kirm>1,'onlem_carpani',round(mg,3),'saat',round(h,2),
     'sirket_carpani',round(ms,3),'lojistik_carpani',round(ml,3))
  where eylem_id=x.id;
  if L>0 or bel>0 then
   insert into oyun.sokak_bedel_saat(eylem_id,saat,gsyh,hazine,belediye) values(x.id,date_trunc('hour',t),round(L,6),round(hk,6),bel)
    on conflict (eylem_id,saat) do update set gsyh=oyun.sokak_bedel_saat.gsyh+excluded.gsyh,
     hazine=oyun.sokak_bedel_saat.hazine+excluded.hazine, belediye=oyun.sokak_bedel_saat.belediye+excluded.belediye;
  end if;

  -- eşikler: faturası büyüyen eylem manşete çıkar
  for i in reverse array_length(esik,1)..1 loop
   if b.toplam_gsyh+L>=esik[i] and b.esik_no<i then
    update oyun.sokak_bedel set esik_no=i where eylem_id=x.id;
    perform oyun.sokak_duyur(x.id, format('💸 %s eyleminin (#%s) ekonomiye faturası %s eşiğini aştı. Hazine''nin vergi kaybı %s; zarar şu an saatte %s büyüyor.',
      il_ad, x.id, oyun.sokak_milyar(esik[i]), oyun.sokak_milyar(b.toplam_hazine+hk), oyun.sokak_milyar(Lh)));
    if esik[i]>=1 then perform oyun.sokak_manset_yaz(format('%s eyleminin faturası %s eşiğini aştı', il_ad, oyun.sokak_milyar(esik[i]))); end if;
    exit;
   end if;
  end loop;

  -- çadır kenti: her 12 saatte bir güç birikir (en çok 4 aşama)
  if b.bicim='cadir' then
   asama:=least(4,floor(extract(epoch from (t-coalesce(b.bicim_zaman,b.saat_baz)))/43200)::int);
   if asama>b.cadir_asama then
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'cadir',1,t+interval '7 days');
    update oyun.sokak_bedel set cadir_asama=asama where eylem_id=x.id;
    perform oyun.sokak_duyur(x.id, format('⛺ %s çadır kentinde %s. gece: direniş nöbeti büyüyor (+1 güç).', il_ad, asama));
   end if;
  end if;
  -- tencere-tava: her akşam 21.00–22.30 arası +4
  if b.bicim='tencere' then
   ist:=t at time zone 'Europe/Istanbul';
   if extract(hour from ist)=21 and b.tencere_gun is distinct from ist::date then
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis)
     values(x.id,'tencere',4,(date_trunc('day',ist)+interval '22 hours 30 minutes') at time zone 'Europe/Istanbul');
    update oyun.sokak_bedel set tencere_gun=ist::date where eylem_id=x.id;
    perform oyun.sokak_duyur(x.id, format('🍳 Saat 21.00: %s''da pencerelerden ve balkonlardan tencere tava sesleri yükseliyor.', il_ad));
   end if;
  end if;

  if coalesce(b.sirket_son,b.saat_baz)<=t-interval '1 hour' then perform oyun.sokak_bedel_sirket_tahsil(x.id); end if;
 end loop;

 -- artçı etki: eylem bitti ama piyasalar hemen toparlanmaz (süre eylemin dörtte biri)
 for r in select eylem_id from oyun.sokak_bedel where kapandi is not null and artci_bitis>t loop
  select * into b from oyun.sokak_bedel where eylem_id=r.eylem_id for update;
  dt:=least(1,extract(epoch from (t-b.son))/3600);
  if dt<0.03 then continue; end if;
  frac:=greatest(0,extract(epoch from (b.artci_bitis-t))/nullif(extract(epoch from (b.artci_bitis-b.kapandi)),0));
  Lh:=coalesce(b.son_saatlik,0)*0.5*coalesce(frac,0);
  L:=Lh*dt; hk:=L*vo;
  top_L:=top_L+L; top_hz:=top_hz+hk; enf_w:=enf_w+L;
  update oyun.sokak_bedel set son=t, saatlik_gsyh=round(Lh,6), saatlik_hazine=round(Lh*vo,6), toplam_gsyh=round(toplam_gsyh+L,6),
   toplam_hazine=round(toplam_hazine+hk,6), artci_gsyh=round(artci_gsyh+L,6) where eylem_id=b.eylem_id;
 end loop;
 update oyun.sokak_bedel set saatlik_gsyh=0, saatlik_hazine=0 where kapandi is not null and artci_bitis<=t and saatlik_gsyh>0;

 -- Hazine: tek kayıt
 if top_hz>0.000001 then
  top_hz:=least(top_hz,0.5);
  perform oyun.hazine_kaydet('toplumsal_olay', -top_hz,
   format('Halk Hareketleri: eylemlerin durdurduğu üretim nedeniyle vergi kaybı (üretim kaybı %s)', oyun.sokak_milyar(top_L)));
 end if;

 -- makro etkiler (günlük tavanlı)
 v_gun:=(t at time zone 'Europe/Istanbul')::date;
 insert into oyun.sokak_bedel_gun(gun) values(v_gun) on conflict (gun) do nothing;
 select * into gn from oyun.sokak_bedel_gun where gun=v_gun for update;
 dbuy:=greatest(0,least(1.5-gn.buyume, top_L/G*25));
 denf:=greatest(0,least(0.6-gn.enflasyon, enf_w/G*6));
 dmem:=greatest(0,least(4-gn.memnuniyet, top_L/G*60));
 diss:=greatest(0,least(0.3-gn.issizlik, iss_L/G*4));
 if dbuy+denf+dmem+diss>0.000001 then
  update oyun.ulke set buyume=greatest(-20,buyume-dbuy), enflasyon=least(200,enflasyon+denf),
   memnuniyet=greatest(0,memnuniyet-dmem), issizlik=least(40,issizlik+diss) where id=1;
 end if;
 update oyun.sokak_bedel_gun set gsyh=round(gsyh+top_L,6), hazine=round(hazine+top_hz,6), belediye=round(belediye+top_bel,2),
  buyume=round(buyume+dbuy,6), enflasyon=round(enflasyon+denf,6), memnuniyet=round(memnuniyet+dmem,6), issizlik=round(issizlik+diss,6) where gun=v_gun;
end $$;

-- Borsa/şirket değerleme risk primi: kırmızı il primi + canlı hasarın büyüklüğü.
create or replace function oyun.sokak_piyasa_riski()
returns numeric language sql stable set search_path to '' as $$
 select case when coalesce((select aktif from oyun.sokak_eylem_ayar where id=1),false) then
  least(0.12,
   least(0.06,(select count(*) from oyun.sokak_eylem where durum='aktif' and bitis>oyun.simdi() and kirmizi_baslangic is not null)*0.01)
   + coalesce((select sum(b.saatlik_gsyh) from oyun.sokak_bedel b where b.saatlik_gsyh>0),0)
     / greatest(1,oyun.sokak_gsyh_gunluk()/24.0) * 1.5 * oyun.sokak_bedel_kat(null,'piyasa'))
 else 0 end
$$;

-- ---------- 7) Araç kataloğu (arayüz bunu çizer) ----------
create or replace function oyun.sokak_bedel_araclar()
returns jsonb language sql immutable set search_path to '' as $$
 select jsonb_build_array(
  jsonb_build_object('kod','kriz_masasi','ad','Kriz Koordinasyon Merkezi','ikon','🧭','kim','Vali · İçişleri Bakanı · Cumhurbaşkanı',
   'aciklama','Valilik, emniyet, AFAD, belediye ve esnaf odası tek masada toplanır. Eylem boyunca ekonomik zarar %20, şirket kayıpları %15 azalır.',
   'bedel','0,05 milyar ₺ (Hazine)','sinir','Eylem başına bir kez'),
  jsonb_build_object('kod','asgari_hizmet','ad','Asgari hizmet genelgesi','ikon','🚑','kim','Vali · İçişleri Bakanı · Cumhurbaşkanı',
   'aciklama','Hastane, ulaşım ve temel kamu hizmetleri nöbetçi personelle sürer. 12 saat zarar %15, hizmet sektörü kaybı %40 azalır.',
   'bedel','0,03 milyar ₺ (Hazine)','sinir','12 saatte bir'),
  jsonb_build_object('kod','lojistik_koridor','ad','Alternatif lojistik koridoru','ikon','🛣️','kim','Vali · Ulaştırma Bakanı · Cumhurbaşkanı',
   'aciklama','Trafik planı, çevre yolları ve demiryolu ile tedarik sürdürülür. 12 saat lojistik kaybı yarıya, üretim kaybı %30 iner. Yürüyüş, konvoy, kepenk, genel grev ya da yol kapatmada kullanılır.',
   'bedel','0,08 milyar ₺ (Hazine)','sinir','12 saatte bir'),
  jsonb_build_object('kod','esnaf_destek','ad','Esnafa zarar tazmini paketi','ikon','🤝','kim','Ticaret Bakanı · Hazine ve Maliye Bakanı · Cumhurbaşkanı',
   'aciklama','Eylemde satış kaybeden şirketlere kayıplarının %60''ı Hazine''den ödenir; 24 saat yeni kayıplar %30 azalır ve kepenk eyleminin gücü yarıya iner.',
   'bedel','Ödenen tazminat kadar (Hazine)','sinir','24 saatte bir'),
  jsonb_build_object('kod','piyasa_istikrar','ad','Piyasa istikrar paketi','ikon','📈','kim','Hazine ve Maliye Bakanı · Cumhurbaşkanı',
   'aciklama','Varlık Fonu borsaya ve kredi piyasasına destek verir. 24 saat bütün eylemlerin ekonomik zararı %25, borsa risk primi yarı yarıya azalır.',
   'bedel','Varlık Fonu''ndan (Süper Yönetici ayarı, varsayılan 5 milyar ₺)','sinir','Ülke genelinde 24 saatte bir'),
  jsonb_build_object('kod','grev_erteleme','ad','Grev erteleme kararı','ikon','⚖️','kim','Yalnız Cumhurbaşkanı',
   'aciklama','Genel grev ya da süren grev durdurulur, eylem mitinge döner ve 24 saat genel greve dönülemez. Bedeli siyasi: meydanın gücüne 12 saat +6, ülke memnuniyetine −1.',
   'bedel','Siyasi bedel','sinir','Eylem başına bir kez; gerekçe zorunlu'),
  jsonb_build_object('kod','fatura','ad','Maliyet faturasını açıkla','ikon','🧾','kim','Cumhurbaşkanı · CB Yardımcısı · Bakanlar',
   'aciklama','Hükümet eylemin ekonomiye faturasını kamuoyuna açıklar. Kamuoyu sempatisi 50''nin altındaysa meydan 12 saat −6 güç kaybeder; üstündeyse ters teper (+4).',
   'bedel','Ücretsiz · risk var','sinir','12 saatte bir'))
$$;

-- ---------- 8) Panel ----------
create or replace function public.sokak_bedel_panel(p_eylem bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; b oyun.sokak_bedel; bc oyun.sokak_bicim; t timestamptz:=oyun.simdi();
 n int; h numeric; org boolean; kat boolean; il_ad text; araclar jsonb:='[]'::jsonb; a jsonb; yetki boolean; uygun boolean; neden text;
 bicimler jsonb:='[]'::jsonb; c oyun.sokak_bicim; son_degisim timestamptz; G numeric:=oyun.sokak_gsyh_gunluk();
 tahmin int; sure numeric; tepki_dk numeric; oran numeric; kep int; benim jsonb; sonraki jsonb; ilk timestamptz;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if x.id is null then raise exception 'Eylem bulunamadı'; end if;
 b:=oyun.sokak_bedel_satir(x.id);
 if b.eylem_id is null then return jsonb_build_object('eylem_id',x.id,'veri',false); end if;
 select * into bc from oyun.sokak_bicim where kod=b.bicim;
 select ad into il_ad from oyun.iller where id=x.il_id;
 n:=oyun.sokak_gercek_katilimci(x.id);
 h:=greatest(0,extract(epoch from (least(t,coalesce(b.kapandi,t))-b.saat_baz))/3600);
 org:=oyun.sokak_bedel_org(x,u);
 kat:=oyun.sokak_katilimci_mi(x.id,u,'muhalefet');
 ilk:=coalesce(b.ilk_tepki,oyun.sokak_bedel_ilk_tepki(x.id));

 -- biçimler: kimin, neden seçebileceği
 select max(zaman) into son_degisim from oyun.sokak_bedel_mudahale where eylem_id=x.id and taraf='eylem' and tur like 'bicim:%';
 for c in select * from oyun.sokak_bicim order by sira loop
  uygun:=org and x.durum='aktif' and x.bitis>t and c.kod<>b.bicim; neden:=null;
  if not org then neden:='Biçimi eylemi başlatan ya da düzenleyen kuruluşun başkanı seçer';
  elsif c.kod=b.bicim then neden:='Şu anki biçim';
  elsif n<c.min_kisi then uygun:=false; neden:=format('En az %s gerçek katılımcı gerekir (şu an %s)',c.min_kisi,n);
  elsif c.basamak>bc.basamak and c.basamak>greatest(bc.basamak,1)+1 then uygun:=false; neden:='Tırmandırma basamak basamak olur; önce bir ara biçime geçin';
  elsif c.basamak>bc.basamak and son_degisim>t-interval '4 hours' then uygun:=false; neden:='Tırmandırma 4 saatte bir yapılabilir';
  elsif c.basamak<=bc.basamak and son_degisim>t-interval '1 hour' then uygun:=false; neden:='Biçim saatte bir değiştirilebilir';
  elsif c.basamak>=3 and c.basamak>bc.basamak and x.baslangic>t-interval '6 hours' then uygun:=false; neden:='Bu biçim için eylemin en az 6 saattir sürmesi gerekir';
  elsif c.basamak>=4 and x.baslangic>t-interval '12 hours' then uygun:=false; neden:='Genel grev için eylemin en az 12 saattir sürmesi gerekir';
  elsif c.kod='genel_grev' and exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='grev_erteleme' and m.bitis>t) then uygun:=false; neden:='Grev erteleme kararı yürürlükte';
  end if;
  bicimler:=bicimler||jsonb_build_object('kod',c.kod,'ad',c.ad,'ikon',c.ikon,'basamak',c.basamak,'aciklama',c.aciklama,'gercek',c.gercek,
   'min_kisi',c.min_kisi,'bedel',c.bedel,'guc',c.guc,'k_gsyh',c.k_gsyh,'karsi',c.karsi,'secili',c.kod=b.bicim,'uygun',uygun,'neden',neden,
   'yon',case when c.basamak>bc.basamak then 'tirman' when c.basamak<bc.basamak then 'yumusat' else 'yatay' end);
 end loop;

 -- hükümet araçları
 for a in select * from jsonb_array_elements(oyun.sokak_bedel_araclar()) loop
  yetki:=oyun.sokak_bedel_arac_yetki(a->>'kod',u,x.il_id);
  uygun:=yetki and x.durum='aktif' and x.bitis>t; neden:=null;
  if not yetki then neden:='Yetkin yok: '||(a->>'kim');
  elsif a->>'kod'='kriz_masasi' and exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='kriz_masasi') then uygun:=false; neden:='Kriz merkezi kuruldu';
  elsif a->>'kod' in ('asgari_hizmet','lojistik_koridor','fatura') and exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur=a->>'kod' and m.zaman>t-interval '12 hours') then uygun:=false; neden:='12 saatte bir kullanılır';
  elsif a->>'kod'='lojistik_koridor' and not (b.bicim in ('yuruyus','konvoy','kepenk','genel_grev') or exists(select 1 from oyun.sokak_hamle hh where hh.eylem_id=x.id and hh.tur='yol' and hh.durum='aktif' and hh.bitis>t)) then uygun:=false; neden:='Bu eylemde lojistik aksama yok';
  elsif a->>'kod'='esnaf_destek' and exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='esnaf_destek' and m.zaman>t-interval '24 hours') then uygun:=false; neden:='24 saatte bir kullanılır';
  elsif a->>'kod'='piyasa_istikrar' and exists(select 1 from oyun.sokak_bedel_mudahale m where m.tur='piyasa_istikrar' and m.zaman>t-interval '24 hours') then uygun:=false; neden:='Ülke genelinde 24 saatte bir';
  elsif a->>'kod'='grev_erteleme' and exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='grev_erteleme') then uygun:=false; neden:='Bu eylemde karar verildi';
  elsif a->>'kod'='grev_erteleme' and not (b.bicim='genel_grev' or x.grev_bitis>t or exists(select 1 from oyun.sokak_hamle hh where hh.eylem_id=x.id and hh.tur='grev' and hh.durum='aktif' and hh.bitis>t)) then uygun:=false; neden:='Eylemde grev yok';
  elsif a->>'kod'='fatura' and b.toplam_gsyh<0.1 then uygun:=false; neden:='Fatura henüz 100 milyon ₺''yi bulmadı';
  end if;
  araclar:=araclar||(a||jsonb_build_object('yetkili',yetki,'uygun',uygun,'neden',neden,
   'kullanildi',(select max(zaman) from oyun.sokak_bedel_mudahale m where m.tur=a->>'kod' and (m.eylem_id=x.id or (a->>'kod'='piyasa_istikrar' and m.eylem_id is null)))));
 end loop;

 -- benim şirketlerim (kepenk)
 select coalesce(jsonb_agg(jsonb_build_object('id',c2.id,'ad',c2.ad,'sektor',c2.sektor,'kanal',oyun.sokak_sektor_kanal(c2.sektor),
   'kepenk',coalesce(bs.kepenk,false),'kayip',coalesce(bs.kayip,0),'tazmin',coalesce(bs.tazmin,0)) order by c2.ad),'[]'::jsonb)
  into benim
 from oyun.sirketler c2 left join oyun.sokak_bedel_sirket bs on bs.eylem_id=x.id and bs.sirket_id=c2.id
 where c2.aktif and (c2.kurucu=u or c2.yonetici=u)
   and (exists(select 1 from oyun.eko_isletmeler ei where ei.sirket_id=c2.id and ei.il_id=x.il_id)
        or exists(select 1 from oyun.pazar_sirket ps where ps.sirket_id=c2.id and ps.il_id=x.il_id));

 select count(*) into kep from oyun.sokak_bedel_sirket where eylem_id=x.id and kepenk;

 -- karne tahmini (şimdi bitse)
 sure:=h; tepki_dk:=case when ilk is null then null else greatest(0,extract(epoch from (ilk-b.saat_baz))/60) end;
 oran:=b.toplam_gsyh/greatest(G,1)*100;
 tahmin:=greatest(0,least(100,100-(case when sure<3 then 0 when sure<6 then 5 when sure<12 then 10 when sure<24 then 20 when sure<72 then 30 else 40 end)
  -(case when tepki_dk is null then 20 when tepki_dk<=60 then 0 when tepki_dk<=180 then 5 when tepki_dk<=480 then 10 else 20 end)
  -(case when oran<0.5 then 0 when oran<2 then 10 when oran<5 then 20 else 30 end)));
 sonraki:=case when h<12 then jsonb_build_object('saat',round(12-h,1),'carpan',round(oyun.sokak_sure_carpani(12),2))
               when h<24 then jsonb_build_object('saat',round(24-h,1),'carpan',round(oyun.sokak_sure_carpani(24),2))
               when h<48 then jsonb_build_object('saat',round(48-h,1),'carpan',round(oyun.sokak_sure_carpani(48),2))
               when h<72 then jsonb_build_object('saat',round(72-h,1),'carpan',round(oyun.sokak_sure_carpani(72),2))
               else null end;

 return jsonb_build_object(
  'veri',true,'eylem_id',x.id,'il',il_ad,'il_id',x.il_id,'durum',x.durum,'bitis',x.bitis,'simdi',t,
  'bicim',jsonb_build_object('kod',bc.kod,'ad',bc.ad,'ikon',bc.ikon,'aciklama',bc.aciklama,'basamak',bc.basamak,'karsi',bc.karsi,'zaman',b.bicim_zaman),
  'bicimler',bicimler,
  'canli',jsonb_build_object('saatlik_gsyh',b.saatlik_gsyh,'saatlik_hazine',b.saatlik_hazine,'saatlik_sirket',b.saatlik_sirket,
    'saniye_tl',round(b.saatlik_gsyh*1e9/3600,2),'son',b.son,'saat',round(h,2),'sure_carpani',round(oyun.sokak_sure_carpani(h),3),
    'sonraki',sonraki,'tepki_carpani',round(oyun.sokak_tepki_carpani(b.saat_baz,ilk,t),3),
    'ilk_tepki',ilk,'ilk_tepki_dk',case when ilk is null then null else round(greatest(0,extract(epoch from (ilk-b.saat_baz))/60)) end,
    'katilimci',n,'kepenk',kep)||b.guncel,
  'toplam',jsonb_build_object('gsyh',round(b.toplam_gsyh,6),'hazine',round(b.toplam_hazine,6),'sirket',round(b.toplam_sirket,2),'belediye',round(b.toplam_belediye,2),
    'tazmin',round(b.tazmin,2),'artci',round(b.artci_gsyh,6),'gsyh_oran',round(oran,3)),
  'seri',coalesce((select jsonb_agg(jsonb_build_object('saat',s.saat,'gsyh',round(s.gsyh,6),'sirket',round(s.sirket,2)) order by s.saat)
    from (select * from oyun.sokak_bedel_saat where eylem_id=x.id order by saat desc limit 36) s),'[]'::jsonb),
  'sirketler',coalesce((select jsonb_agg(jsonb_build_object('ad',c3.ad,'sektor',c3.sektor,'kanal',oyun.sokak_sektor_kanal(c3.sektor),
    'kayip',q.kayip,'tazmin',q.tazmin,'kepenk',q.kepenk) order by q.kepenk desc, q.kayip desc)
    from (select * from oyun.sokak_bedel_sirket where eylem_id=x.id and (kayip>0 or kepenk) order by kepenk desc, kayip desc limit 12) q
    join oyun.sirketler c3 on c3.id=q.sirket_id),'[]'::jsonb),
  'etkilenen_sirket',(select count(*) from oyun.sokak_bedel_sirket where eylem_id=x.id and kayip>0),
  'benim_sirketlerim',benim,
  'mudahaleler',coalesce((select jsonb_agg(jsonb_build_object('tur',m.tur,'taraf',m.taraf,'unvan',m.unvan,'kim',oyun.kad(m.yapan),
    'zaman',m.zaman,'bitis',m.bitis,'aktif',m.bitis>t,'metin',m.metin,'bedel',m.bedel) order by m.zaman desc)
    from (select * from oyun.sokak_bedel_mudahale where eylem_id=x.id or (eylem_id is null and bitis>t) order by zaman desc limit 20) m),'[]'::jsonb),
  'araclar',araclar,
  'rol',jsonb_build_object('org',org,'katilimci',kat,'devlet',exists(select 1 from jsonb_array_elements(araclar) z where (z->>'yetkili')::boolean),
    'unvan',oyun.sokak_bedel_unvan(u,x.il_id)),
  'eylemci',jsonb_build_object('fatura_kes',org and x.durum='aktif' and b.toplam_gsyh>=0.1
     and not exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='fatura_kes' and m.zaman>t-interval '12 hours'),
    'fatura_neden',case when not org then 'Eylemi düzenleyenler kullanır' when b.toplam_gsyh<0.1 then 'Fatura henüz 100 milyon ₺''yi bulmadı'
      when exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='fatura_kes' and m.zaman>t-interval '12 hours') then '12 saatte bir kullanılır' else null end),
  'karne_tahmin',jsonb_build_object('puan',tahmin,'harf',case when tahmin>=90 then 'A' when tahmin>=75 then 'B' when tahmin>=60 then 'C' when tahmin>=45 then 'D' else 'F' end),
  'rapor',b.rapor,'karne',b.karne,'puan',b.puan);
end $$;

-- ---------- 9) Ülke özeti (ana ekran kartı) ----------
create or replace function public.sokak_bedel_ozet()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); v_gun date:=(oyun.simdi() at time zone 'Europe/Istanbul')::date; gn oyun.sokak_bedel_gun;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into gn from oyun.sokak_bedel_gun where gun=v_gun;
 return jsonb_build_object(
  'simdi',t,
  'bugun',jsonb_build_object('gsyh',round(coalesce(gn.gsyh,0),6),'hazine',round(coalesce(gn.hazine,0),6),'sirket',round(coalesce(gn.sirket,0),2),'belediye',round(coalesce(gn.belediye,0),2),
    'buyume',round(coalesce(gn.buyume,0),4),'enflasyon',round(coalesce(gn.enflasyon,0),4),'memnuniyet',round(coalesce(gn.memnuniyet,0),4),'issizlik',round(coalesce(gn.issizlik,0),4),
    'gsyh_oran',round(coalesce(gn.gsyh,0)/greatest(oyun.sokak_gsyh_gunluk(),1)*100,3)),
  'saatlik',coalesce((select sum(saatlik_gsyh) from oyun.sokak_bedel where saatlik_gsyh>0),0),
  'piyasa_riski',round(oyun.sokak_piyasa_riski()*100,2),
  'aktif',coalesce((select jsonb_agg(jsonb_build_object('eylem_id',b.eylem_id,'il',i.ad,'bicim',b.bicim,'bicim_ad',c.ad,'ikon',c.ikon,
     'saatlik_gsyh',b.saatlik_gsyh,'toplam_gsyh',b.toplam_gsyh,'toplam_hazine',b.toplam_hazine,'toplam_sirket',b.toplam_sirket,
     'sure_carpani',b.guncel->'sure_carpani','tepki_carpani',b.guncel->'tepki_carpani','artci',b.kapandi is not null) order by b.saatlik_gsyh desc)
    from oyun.sokak_bedel b join oyun.sokak_eylem e on e.id=b.eylem_id join oyun.iller i on i.id=e.il_id join oyun.sokak_bicim c on c.kod=b.bicim
    where (b.kapandi is null and e.durum='aktif') or b.artci_bitis>t),'[]'::jsonb),
  'raporlar',coalesce((select jsonb_agg(jsonb_build_object('eylem_id',b.eylem_id,'il',i.ad,'kapandi',b.kapandi,'karne',b.karne,'puan',b.puan,'rapor',b.rapor) order by b.kapandi desc)
    from (select * from oyun.sokak_bedel where rapor is not null order by kapandi desc limit 8) b join oyun.sokak_eylem e on e.id=b.eylem_id join oyun.iller i on i.id=e.il_id),'[]'::jsonb),
  'onlemler',coalesce((select jsonb_agg(jsonb_build_object('tur',m.tur,'unvan',m.unvan,'bitis',m.bitis,'metin',m.metin)) from oyun.sokak_bedel_mudahale m where m.eylem_id is null and m.bitis>t),'[]'::jsonb),
  'toplam',jsonb_build_object('gsyh',round(coalesce((select sum(toplam_gsyh) from oyun.sokak_bedel),0),6),'hazine',round(coalesce((select sum(toplam_hazine) from oyun.sokak_bedel),0),6),
    'sirket',coalesce((select sum(toplam_sirket) from oyun.sokak_bedel),0)));
end $$;

-- ---------- 10) İşlemler ----------
create or replace function public.sokak_bedel_islem(p_eylem bigint, p_islem text, p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); x oyun.sokak_eylem; b oyun.sokak_bedel; bc oyun.sokak_bicim; yeni oyun.sokak_bicim;
 n int; il_ad text; unvan text; bedel numeric; sid bigint; c record; mid bigint; cnt int; v_puan numeric; txt text; sempati numeric;
 top numeric:=0; pay numeric; s record; vf numeric; son_degisim timestamptz; msg text; v_tur text:=coalesce(p_islem,'');
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if oyun.gozalti_aktif(u) is not null then raise exception 'Gözaltındayken bu işlem yapılamaz'; end if;
 perform pg_advisory_xact_lock(781231,55);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli'; end if;
 b:=oyun.sokak_bedel_satir(x.id);
 select * into b from oyun.sokak_bedel where eylem_id=x.id for update;
 select * into bc from oyun.sokak_bicim where kod=b.bicim;
 select ad into il_ad from oyun.iller where id=x.il_id;
 n:=oyun.sokak_gercek_katilimci(x.id);

 -- ===== eylemci tarafı =====
 if v_tur='bicim' then
  if not oyun.sokak_bedel_org(x,u) then raise exception 'Eylemin biçimini yalnız eylemi başlatan ya da düzenleyen kuruluşun başkanı değiştirir'; end if;
  select * into yeni from oyun.sokak_bicim where kod=p_veri->>'kod';
  if yeni.kod is null then raise exception 'Geçersiz eylem biçimi'; end if;
  if yeni.kod=b.bicim then raise exception 'Eylem zaten bu biçimde'; end if;
  select max(zaman) into son_degisim from oyun.sokak_bedel_mudahale where eylem_id=x.id and taraf='eylem' and tur like 'bicim:%';
  if n<yeni.min_kisi then raise exception 'Bu biçim için en az % gerçek katılımcı gerekir (şu an %)', yeni.min_kisi, n; end if;
  if yeni.basamak>bc.basamak then
   if yeni.basamak>greatest(bc.basamak,1)+1 then raise exception 'Tırmandırma basamak basamak olur; önce bir ara biçime geçin'; end if;
   if son_degisim>t-interval '4 hours' then raise exception 'Eylem 4 saatte bir tırmandırılabilir'; end if;
   if yeni.basamak>=3 and x.baslangic>t-interval '6 hours' then raise exception 'Bu biçim için eylemin en az 6 saattir sürmesi gerekir'; end if;
   if yeni.basamak>=4 and x.baslangic>t-interval '12 hours' then raise exception 'Genel grev için eylemin en az 12 saattir sürmesi gerekir'; end if;
   if yeni.kod='genel_grev' and exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='grev_erteleme' and m.bitis>t) then
    raise exception 'Grev erteleme kararı yürürlükte; 24 saat genel greve dönülemez'; end if;
   if yeni.bedel>0 then perform oyun.sokak_org_ode(x, yeni.bedel, 'Eylem biçimi: '||yeni.ad); end if;
  else
   if son_degisim>t-interval '1 hour' then raise exception 'Biçim saatte bir değiştirilebilir'; end if;
  end if;
  perform oyun.sokak_bedel_sirket_tahsil(x.id);
  update oyun.sokak_meydan_etki set bitis=t where eylem_id=x.id and tur in ('bicim','cadir','tencere') and bitis>t;
  if yeni.kod not in ('kepenk','genel_grev') then
   update oyun.sokak_meydan_etki set bitis=t where eylem_id=x.id and tur='kepenk' and bitis>t;
   update oyun.sokak_bedel_sirket set kepenk=false where eylem_id=x.id and kepenk;
  end if;
  if yeni.guc>0 then insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'bicim',yeni.guc,t+interval '7 days'); end if;
  update oyun.sokak_bedel set bicim=yeni.kod, bicim_zaman=t, bicim_yapan=u, cadir_asama=0, tencere_gun=null where eylem_id=x.id;
  msg:=format('%s %s meydanında eylem biçim değiştirdi: %s → %s. %s', yeni.ikon, il_ad, bc.ad, yeni.ad,
   case when yeni.basamak>bc.basamak then format('Eylem tırmanıyor; ekonomik zarar katsayısı %s kat.', replace(round(yeni.k_gsyh/greatest(bc.k_gsyh,0.001),1)::text,'.',','))
        else 'Eylem yumuşadı; ekonomiye verdiği zarar azalacak.' end);
  insert into oyun.sokak_bedel_mudahale(eylem_id,taraf,tur,yapan,unvan,bedel,zaman,bitis,metin)
   values(x.id,'eylem','bicim:'||yeni.kod,u,'Düzenleyen',yeni.bedel,t,t,msg);
  perform oyun.sokak_duyur(x.id, msg);
  if yeni.basamak>=3 and yeni.basamak>bc.basamak then perform oyun.sokak_manset_yaz(format('%s''da %s başladı', il_ad, lower(yeni.ad))); end if;
  perform oyun.sokak_sicil_yaz(u,x.id,'hamle','Eylem biçimi: '||yeni.ad);

 elsif v_tur='kepenk' then
  if b.bicim not in ('kepenk','genel_grev') then raise exception 'Kepenk ancak eylem "Kepenk kapatma" ya da "Genel grev" biçimindeyken indirilir'; end if;
  if exists(select 1 from oyun.makamlar m where m.user_id=u and m.bit is null and m.tur in ('cb','bakan','cb_yardimcisi')) then
   raise exception 'Görevdeki Cumhurbaşkanı, yardımcısı ve bakanlar kepenk eylemine katılamaz'; end if;
  sid:=(p_veri->>'sirket')::bigint;
  select * into c from oyun.sirketler where id=sid and aktif and (kurucu=u or yonetici=u);
  if c.id is null then raise exception 'Bu şirketin sahibi ya da yöneticisi değilsiniz'; end if;
  if oyun.sokak_sektor_kanal(c.sektor) is null then raise exception 'Bu sektördeki şirketler kepenk eylemine katılmaz'; end if;
  if not (exists(select 1 from oyun.eko_isletmeler ei where ei.sirket_id=c.id and ei.il_id=x.il_id)
          or exists(select 1 from oyun.pazar_sirket ps where ps.sirket_id=c.id and ps.il_id=x.il_id)) then
   raise exception 'Şirketinizin % ilinde işletmesi yok', il_ad; end if;
  if exists(select 1 from oyun.sokak_bedel_sirket where eylem_id=x.id and sirket_id=c.id and kepenk) then raise exception 'Bu şirket zaten kepenk indirdi'; end if;
  perform oyun.sokak_bedel_sirket_tahsil(x.id);
  select count(*) into cnt from oyun.sokak_bedel_sirket where eylem_id=x.id and kepenk;
  mid:=null;
  if cnt<8 then insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'kepenk',1.5,t+interval '7 days') returning id, puan into mid, v_puan; end if;
  insert into oyun.sokak_bedel_sirket(eylem_id,sirket_id,kepenk,kepenk_zaman,kepenk_yapan,etki_id,son)
   values(x.id,c.id,true,t,u,mid,t)
   on conflict (eylem_id,sirket_id) do update set kepenk=true, kepenk_zaman=t, kepenk_yapan=u, etki_id=excluded.etki_id;
  msg:=format('🏪 %s meydanına esnaf desteği: %s kepenk indirdi. %s', il_ad, c.ad, case when mid is null then 'Kepenk gücü tavanda (8 şirket).' else format('Meydanın gücüne +%s.', replace(round(v_puan,2)::text,'.',',')) end);
  insert into oyun.sokak_bedel_mudahale(eylem_id,taraf,tur,yapan,unvan,zaman,bitis,metin) values(x.id,'eylem','kepenk',u,c.ad,t,x.bitis,msg);
  perform oyun.sokak_duyur(x.id, msg);

 elsif v_tur='kepenk_ac' then
  sid:=(p_veri->>'sirket')::bigint;
  select * into c from oyun.sirketler where id=sid and (kurucu=u or yonetici=u);
  if c.id is null then raise exception 'Bu şirketin sahibi ya da yöneticisi değilsiniz'; end if;
  select * into s from oyun.sokak_bedel_sirket where eylem_id=x.id and sirket_id=c.id and kepenk;
  if s.sirket_id is null then raise exception 'Bu şirket kepenk indirmemiş'; end if;
  perform oyun.sokak_bedel_sirket_tahsil(x.id);
  update oyun.sokak_bedel_sirket set kepenk=false where eylem_id=x.id and sirket_id=c.id;
  if s.etki_id is not null then update oyun.sokak_meydan_etki set bitis=t where id=s.etki_id and bitis>t; end if;
  msg:=format('🔓 %s, %s''daki işletmelerinin kepenklerini yeniden açtı.', c.ad, il_ad);
  insert into oyun.sokak_bedel_mudahale(eylem_id,taraf,tur,yapan,unvan,zaman,bitis,metin) values(x.id,'eylem','kepenk_ac',u,c.ad,t,t,msg);
  perform oyun.sokak_duyur(x.id, msg);

 elsif v_tur='fatura_kes' then
  if not oyun.sokak_bedel_org(x,u) then raise exception 'Faturayı eylemi düzenleyenler keser'; end if;
  if b.toplam_gsyh<0.1 then raise exception 'Fatura henüz 100 milyon ₺''yi bulmadı'; end if;
  if exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='fatura_kes' and m.zaman>t-interval '12 hours') then raise exception '12 saatte bir kullanılır'; end if;
  v_puan:=case when b.ilk_tepki is null and oyun.sokak_bedel_ilk_tepki(x.id) is null then 5 else 2 end;
  insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'fatura_kes',v_puan,t+interval '6 hours') returning puan into v_puan;
  msg:=format('📢 %s meydanı faturayı hükümete kesti: "Ekonominin kaybı %s, Hazine''nin kaybı %s. %s" (meydana 6 saat +%s güç)', il_ad,
   oyun.sokak_milyar(b.toplam_gsyh), oyun.sokak_milyar(b.toplam_hazine),
   case when v_puan>=5 then 'Hükümet hâlâ tek bir somut adım atmadı.' else 'Sorunu çözmek hükümetin elinde.' end, replace(round(v_puan,1)::text,'.',','));
  insert into oyun.sokak_bedel_mudahale(eylem_id,taraf,tur,yapan,unvan,zaman,bitis,etki,metin) values(x.id,'eylem','fatura_kes',u,'Düzenleyen',t,t+interval '6 hours',jsonb_build_object('guc',v_puan),msg);
  perform oyun.sokak_duyur(x.id, msg);

 -- ===== hükümet tarafı =====
 elsif v_tur in ('kriz_masasi','asgari_hizmet','lojistik_koridor','esnaf_destek','piyasa_istikrar','grev_erteleme','fatura') then
  if not oyun.sokak_bedel_arac_yetki(v_tur,u,x.il_id) then raise exception 'Bu araç için yetkiniz yok'; end if;
  unvan:=coalesce(oyun.sokak_bedel_unvan(u,x.il_id),'Hükümet');

  if v_tur='kriz_masasi' then
   if exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur='kriz_masasi') then raise exception 'Bu eylem için kriz merkezi zaten kuruldu'; end if;
   bedel:=0.05;
   if (select hazine from oyun.ulke where id=1)<bedel then raise exception 'Hazine''de yeterli nakit yok'; end if;
   perform oyun.hazine_kaydet('kriz',-bedel,format('Halk Hareketleri #%s: %s Kriz Koordinasyon Merkezi',x.id,il_ad));
   msg:=format('🧭 %s, %s''da Kriz Koordinasyon Merkezi kurdu: valilik, emniyet, AFAD, belediye ve esnaf odası tek masada. Eylemin ekonomiye zararı %%20 azalacak.', unvan, il_ad);
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,bedel,zaman,bitis,etki,metin)
    values(x.id,v_tur,u,unvan,bedel,t,x.bitis,jsonb_build_object('gsyh',0.8,'sirket',0.85),msg);

  elsif v_tur='asgari_hizmet' then
   if exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur=v_tur and m.zaman>t-interval '12 hours') then raise exception '12 saatte bir kullanılır'; end if;
   bedel:=0.03;
   if (select hazine from oyun.ulke where id=1)<bedel then raise exception 'Hazine''de yeterli nakit yok'; end if;
   perform oyun.hazine_kaydet('kriz',-bedel,format('Halk Hareketleri #%s: %s asgari hizmet genelgesi',x.id,il_ad));
   msg:=format('🚑 %s asgari hizmet genelgesi yayımladı: %s''da hastane, ulaşım ve temel kamu hizmetleri nöbetçi personelle sürecek. 12 saat boyunca zarar %%15 azalacak.', unvan, il_ad);
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,bedel,zaman,bitis,etki,metin)
    values(x.id,v_tur,u,unvan,bedel,t,least(x.bitis,t+interval '12 hours'),jsonb_build_object('gsyh',0.85,'hizmet',0.6),msg);

  elsif v_tur='lojistik_koridor' then
   if exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur=v_tur and m.zaman>t-interval '12 hours') then raise exception '12 saatte bir kullanılır'; end if;
   if not (b.bicim in ('yuruyus','konvoy','kepenk','genel_grev') or exists(select 1 from oyun.sokak_hamle hh where hh.eylem_id=x.id and hh.tur='yol' and hh.durum='aktif' and hh.bitis>t)) then
    raise exception 'Bu eylemde lojistik aksama yok'; end if;
   bedel:=0.08;
   if (select hazine from oyun.ulke where id=1)<bedel then raise exception 'Hazine''de yeterli nakit yok'; end if;
   perform oyun.hazine_kaydet('kriz',-bedel,format('Halk Hareketleri #%s: %s alternatif lojistik koridoru',x.id,il_ad));
   msg:=format('🛣️ %s %s için alternatif lojistik koridoru açtı: çevre yolları, demiryolu ve trafik planıyla tedarik sürüyor. 12 saat lojistik kaybı yarıya inecek.', unvan, il_ad);
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,bedel,zaman,bitis,etki,metin)
    values(x.id,v_tur,u,unvan,bedel,t,least(x.bitis,t+interval '12 hours'),jsonb_build_object('lojistik',0.5,'uretim',0.7),msg);

  elsif v_tur='esnaf_destek' then
   if exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur=v_tur and m.zaman>t-interval '24 hours') then raise exception '24 saatte bir kullanılır'; end if;
   perform oyun.sokak_bedel_sirket_tahsil(x.id);
   select coalesce(sum(round((kayip-tazmin)*0.6,2)),0) into top from oyun.sokak_bedel_sirket where eylem_id=x.id and kayip-tazmin>=2;
   if top<=0 then raise exception 'Henüz tazmin edilecek esnaf zararı yok'; end if;
   if (select hazine from oyun.ulke where id=1)<top/1e9 then raise exception 'Hazine''de yeterli nakit yok'; end if;
   top:=0;
   for s in select q.*, c2.ad, c2.kurucu, c2.yonetici from oyun.sokak_bedel_sirket q join oyun.sirketler c2 on c2.id=q.sirket_id and c2.aktif
            where q.eylem_id=x.id and q.kayip-q.tazmin>=2 loop
    pay:=round((s.kayip-s.tazmin)*0.6,2);
    update oyun.sirketler set kasa=kasa+pay where id=s.sirket_id;
    insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama) values(s.sirket_id,t,pay,format('Devlet esnaf destek paketi: Halk Hareketleri #%s (%s) zarar tazmini',x.id,il_ad));
    update oyun.sokak_bedel_sirket set tazmin=tazmin+pay where eylem_id=x.id and sirket_id=s.sirket_id;
    perform oyun.bildir(coalesce(s.yonetici,s.kurucu), format('🤝 %s esnaf destek paketi açıkladı: %s şirketine %s eylem zararı tazmini ödendi.', unvan, s.ad, oyun.sokak_tl(pay)));
    top:=top+pay;
   end loop;
   if top>0 then perform oyun.hazine_kaydet('sosyal',-top/1e9,format('Halk Hareketleri #%s: %s esnafına zarar tazmini',x.id,il_ad)); end if;
   update oyun.sokak_bedel set tazmin=tazmin+top where eylem_id=x.id;
   update oyun.sokak_meydan_etki set puan=puan/2 where eylem_id=x.id and tur='kepenk' and bitis>t;
   bedel:=top/1e9;
   msg:=format('🤝 %s %s esnafı için zarar tazmini paketi açıkladı: şirketlere %s ödendi, KGF kefaletli kredilerle 24 saat yeni kayıplar %%30 azalacak. Kepenk eyleminin gücü yarıya indi.', unvan, il_ad, oyun.sokak_tl(top));
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,bedel,zaman,bitis,etki,metin)
    values(x.id,v_tur,u,unvan,bedel,t,least(x.bitis,t+interval '24 hours'),jsonb_build_object('sirket',0.7),msg);

  elsif v_tur='piyasa_istikrar' then
   if exists(select 1 from oyun.sokak_bedel_mudahale m where m.tur=v_tur and m.zaman>t-interval '24 hours') then raise exception 'Piyasa istikrar paketi ülke genelinde 24 saatte bir açıklanır'; end if;
   bedel:=oyun.sokak_tarife('halk_piyasa_destek',5);
   select bakiye into vf from oyun.varlik_fonu where id=1 for update;
   if coalesce(vf,0)<bedel then raise exception 'Varlık Fonu''nda yeterli kaynak yok'; end if;
   update oyun.varlik_fonu set bakiye=bakiye-bedel where id=1 returning bakiye into vf;
   insert into oyun.varlik_fonu_hareket(zaman,tutar,bakiye,tur,aciklama,user_id)
    values(t,bedel,vf,'cek','Piyasa istikrar paketi: Halk Hareketleri sırasında borsa ve kredi piyasasına destek',u);
   msg:=format('📈 %s piyasa istikrar paketi açıkladı: Varlık Fonu''ndan %s borsa ve kredi piyasasına aktarıldı. 24 saat bütün eylemlerin ekonomiye zararı %%25, borsa risk primi yarı yarıya azalacak.', unvan, oyun.sokak_milyar(bedel));
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,bedel,zaman,bitis,etki,metin)
    values(null,v_tur,u,unvan,bedel,t,t+interval '24 hours',jsonb_build_object('gsyh',0.75,'piyasa',0.5),msg);
   -- bu eylem için de ilk tepki sayılsın
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,bedel,zaman,bitis,metin)
    values(x.id,'piyasa_istikrar_not',u,unvan,0,t,t,msg);
   perform oyun.olay('ekonomi', msg);
   perform oyun.sokak_manset_yaz('Hükümetten piyasa istikrar paketi');

  elsif v_tur='grev_erteleme' then
   if exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur=v_tur) then raise exception 'Bu eylemde grev erteleme kararı zaten verildi'; end if;
   if not (b.bicim='genel_grev' or x.grev_bitis>t or exists(select 1 from oyun.sokak_hamle hh where hh.eylem_id=x.id and hh.tur='grev' and hh.durum='aktif' and hh.bitis>t)) then
    raise exception 'Eylemde ertelenecek bir grev yok'; end if;
   if char_length(btrim(coalesce(p_veri->>'gerekce','')))<20 then raise exception 'Grev erteleme kararı için en az 20 karakterlik gerekçe yazın (genel sağlık veya millî güvenlik)'; end if;
   txt:=oyun.sokak_temiz(p_veri->>'gerekce',400);
   perform oyun.sokak_bedel_sirket_tahsil(x.id);
   update oyun.sokak_hamle set durum='bitti', bitis=t where eylem_id=x.id and tur='grev' and durum='aktif';
   update oyun.sokak_eylem set grev_bitis=t where id=x.id and grev_bitis>t;
   if b.bicim='genel_grev' then
    update oyun.sokak_meydan_etki set bitis=t where eylem_id=x.id and tur in ('bicim','kepenk') and bitis>t;
    update oyun.sokak_bedel_sirket set kepenk=false where eylem_id=x.id and kepenk;
    update oyun.sokak_bedel set bicim='miting', bicim_zaman=t where eylem_id=x.id;
    insert into oyun.sokak_bedel_mudahale(eylem_id,taraf,tur,yapan,unvan,zaman,bitis,metin) values(x.id,'eylem','bicim:miting',u,unvan,t,t,'Grev erteleme kararıyla eylem mitinge döndü.');
   end if;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'erteleme',6,t+interval '12 hours') returning puan into v_puan;
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
   msg:=format('⚖️ Resmî Gazete: %s, %s''daki grevi 6356 sayılı Kanun m.63 uyarınca erteledi. Gerekçe: "%s". Grev durdu, 24 saat genel greve dönülemez; karar meydanda tepkiyle karşılandı (+%s güç, 12 saat).', unvan, il_ad, txt, replace(round(v_puan,1)::text,'.',','));
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,zaman,bitis,etki,metin)
    values(x.id,v_tur,u,unvan,t,t+interval '24 hours',jsonb_build_object('gerekce',txt),msg);
   perform oyun.olay('siyaset', msg, x.il_id, x.parti_id);
   perform oyun.sokak_manset_yaz(format('%s''da grev ertelendi', il_ad));

  elsif v_tur='fatura' then
   if exists(select 1 from oyun.sokak_bedel_mudahale m where m.eylem_id=x.id and m.tur=v_tur and m.zaman>t-interval '12 hours') then raise exception '12 saatte bir kullanılır'; end if;
   if b.toplam_gsyh<0.1 then raise exception 'Fatura henüz 100 milyon ₺''yi bulmadı'; end if;
   sempati:=coalesce((oyun.sokak_saha_dokum(x.id)->>'sempati')::numeric,50);
   if sempati<50 then
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'fatura',-6,t+interval '12 hours');
    msg:=format('🧾 %s %s eyleminin faturasını açıkladı: ekonomiye %s, Hazine''ye %s, esnafa %s kayıp. Kamuoyu hükümetin yanında (sempati %s): meydan 12 saat −6 güç kaybetti.',
     unvan, il_ad, oyun.sokak_milyar(b.toplam_gsyh), oyun.sokak_milyar(b.toplam_hazine), oyun.sokak_tl(b.toplam_sirket), round(sempati));
   else
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'fatura_ters',4,t+interval '12 hours') returning puan into v_puan;
    msg:=format('🧾 %s %s eyleminin faturasını açıkladı (%s) ama ters tepti: kamuoyu eylemcilerin yanında (sempati %s). "Faturanın sorumlusu çözüm üretmeyen hükümet" tepkisiyle meydan 12 saat +%s güç kazandı.',
     unvan, il_ad, oyun.sokak_milyar(b.toplam_gsyh), round(sempati), replace(round(v_puan,1)::text,'.',','));
   end if;
   insert into oyun.sokak_bedel_mudahale(eylem_id,tur,yapan,unvan,zaman,bitis,etki,metin)
    values(x.id,v_tur,u,unvan,t,t+interval '12 hours',jsonb_build_object('sempati',round(sempati)),msg);
  end if;

  update oyun.sokak_bedel set ilk_tepki=coalesce(ilk_tepki,t) where eylem_id=x.id;
  perform oyun.sokak_duyur(x.id, msg);
 else
  raise exception 'Bilinmeyen işlem';
 end if;

 return public.sokak_bedel_panel(x.id);
end $$;

-- ---------- 11) Mevcut aktif eylemler: sayaç bugünden başlar ----------
insert into oyun.sokak_bedel(eylem_id,saat_baz,son,sirket_son,ilk_tepki)
 select e.id, oyun.simdi(), oyun.simdi(), oyun.simdi(), oyun.sokak_bedel_ilk_tepki(e.id)
 from oyun.sokak_eylem e where e.durum='aktif'
on conflict (eylem_id) do nothing;

-- ---------- 12) Yetkiler ----------
do $$
declare f text;
begin
 foreach f in array array['public.sokak_bedel_panel(bigint)','public.sokak_bedel_ozet()','public.sokak_bedel_islem(bigint,text,jsonb)'] loop
  execute 'revoke all on function '||f||' from public, anon';
  execute 'grant execute on function '||f||' to authenticated';
 end loop;
 foreach f in array array['oyun.sokak_tarife(text,numeric)','oyun.sokak_gsyh_gunluk()','oyun.sokak_il_pay(integer)','oyun.sokak_sure_carpani(numeric)',
   'oyun.sokak_tepki_carpani(timestamptz,timestamptz,timestamptz)','oyun.sokak_bedel_ilk_tepki(bigint)','oyun.sokak_bedel_kat(bigint,text)',
   'oyun.sokak_sektor_kanal(text)','oyun.sokak_gercek_katilimci(bigint)','oyun.sokak_bedel_org(oyun.sokak_eylem,uuid)','oyun.sokak_bedel_unvan(uuid,integer)',
   'oyun.sokak_bedel_arac_yetki(text,uuid,integer)','oyun.sokak_tl(numeric)','oyun.sokak_milyar(numeric)','oyun.sokak_bedel_satir(bigint)',
   'oyun.sokak_bedel_sirket_tahsil(bigint)','oyun.sokak_bedel_kapat(bigint)','oyun.sokak_bedel_tick()','oyun.sokak_bedel_araclar()'] loop
  execute 'revoke all on function '||f||' from public, anon, authenticated';
 end loop;
end $$;

-- ---------- 13) Zamanlayıcı (5 dakikada bir, sokak-merkez'den 1 dk sonra) ----------
select cron.schedule('halk-bedel','1-59/5 * * * *','select oyun.sokak_bedel_tick()');

select oyun.sonlu_kisit_kur();
