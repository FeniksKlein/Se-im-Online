-- Belediye detay: hizmet karnesi, kriz masası, İller Bankası kredisi, bağış birimi düzeltmesi.
-- Kaynak: gelistirici/sql/91_belediye_detay.sql. İki kez çalıştırılabilir.
begin;
-- =====================================================================
--  91) BELEDİYE DETAY: hizmet karnesi, kriz masası, İller Bankası kredisi
--  - Şehre/hazineye bağış artık kamu kuruyla çevrilir (1 milyar kamu ₺ =
--    oyun.pazar_tl_milyar() oyuncu ₺). Önceden 1.000 ₺ bağış 1.000 milyar ₺ ekliyordu.
--  - Gece kasası: gelir 60 günlük tavana kadar birikir; bağış ve kredi parası kesilmez.
--  - Hizmet karnesi: 7 alan (temizlik, su, ulaşım, sağlık-sosyal, eğitim-kültür,
--    güvenlik-afet, yeşil alan). Binalar, hizmetler, programlar ve kriz kararları
--    puan verir; karne ortalaması her gece memnuniyeti kendine çeker.
--  - Kriz masası: başkanlı illerde ara ara şehir olayı çıkar; 24 saatte karar
--    verilmezse "başkan sessiz kaldı" sonucu işler. Kararlar herkese açıktır.
--  - İller Bankası: belediye 10/20/30 günlük kredi çeker; taksitler her gece
--    kasadan düşer, ödenemeyen taksit %5 gecikme cezasıyla borca eklenir.
--  Oyuncu verisini değiştirmez; yalnız yeni tablo, katalog ve fonksiyon ekler.
-- =====================================================================

-- ---------------------------------------------------------------- bağış birimi
do $$
declare d text;
begin
  d := pg_get_functiondef('public.serbest_bagis(text,text,numeric,text)'::regprocedure);
  if position('kasa=kasa+m,gelisim' in d) > 0 then
    d := replace(d, 'update oyun.il_durum set kasa=kasa+m,gelisim',
                    'update oyun.il_durum set kasa=kasa+m/oyun.pazar_tl_milyar(),gelisim');
    d := replace(d, 'insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);',
                    'insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);
   insert into oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama,zaman)
     values(v_id::smallint,''bagis'',m/oyun.pazar_tl_milyar(),left(p.kad||'' bağış yaptı ('' || oyun.tl(m) || '' ₺)'',170),t);');
    d := replace(d, 'update oyun.ulke set hazine=hazine+m where id=1;',
                    'update oyun.ulke set hazine=hazine+m/oyun.pazar_tl_milyar() where id=1;');
    if position('kasa=kasa+m,gelisim' in d) > 0 or position('hazine=hazine+m where' in d) > 0 then
      raise exception 'serbest_bagis yamasi uygulanamadi';
    end if;
    execute d;
  end if;
end $$;

-- ---------------------------------------------------------------- tablolar
create table if not exists oyun.belediye_karne_alan(
  kod text primary key, ad text not null, aciklama text not null, sira int not null default 0);
insert into oyun.belediye_karne_alan(kod, ad, aciklama, sira) values
 ('temizlik','Temizlik ve atık','Çöp toplama, geri dönüşüm, sokak temizliği.',1),
 ('su','Su ve altyapı','İçme suyu, kanalizasyon, yol altyapısı.',2),
 ('ulasim','Ulaşım','Toplu taşıma, trafik, otopark.',3),
 ('saglik','Sağlık ve sosyal','Sağlık hizmeti, sosyal yardım, konut, kreş.',4),
 ('egitim','Eğitim ve kültür','Okul, kütüphane, kültür ve spor.',5),
 ('guvenlik','Güvenlik ve afet','İtfaiye, zabıta, afete hazırlık.',6),
 ('yesil','Yeşil alan ve çevre','Park, temiz hava, yenilenebilir enerji.',7)
on conflict (kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, sira = excluded.sira;

-- kaynak: 'bina:<kod>', 'hizmet:<kod>', 'program:<kod>', 'yatirim:<kod>'
create table if not exists oyun.belediye_karne_harita(
  kaynak text not null, alan text not null references oyun.belediye_karne_alan(kod),
  puan numeric not null, primary key (kaynak, alan));
insert into oyun.belediye_karne_harita(kaynak, alan, puan) values
 ('bina:hastane','saglik',10), ('bina:aile_sagligi','saglik',6),
 ('bina:okul','egitim',8), ('bina:universite','egitim',10), ('bina:kutuphane','egitim',5),
 ('bina:itfaiye','guvenlik',10), ('bina:polis_destek','guvenlik',6),
 ('bina:otobus_garaji','ulasim',8), ('bina:otopark','ulasim',4),
 ('bina:yol_kavsak','ulasim',7), ('bina:yol_kavsak','su',3),
 ('bina:su_aritma','su',12), ('bina:atik_tesisi','temizlik',12), ('bina:atik_tesisi','yesil',3),
 ('bina:sehir_parki','yesil',10), ('bina:gunes_enerji','yesil',6),
 ('bina:hal_pazar','temizlik',2), ('bina:sanayi_sitesi','yesil',-4),
 ('bina:kultur_merkezi','egitim',5), ('bina:spor_tesisi','saglik',4), ('bina:spor_tesisi','egitim',2),
 ('bina:sosyal_konut','saglik',6), ('bina:kreş','saglik',3), ('bina:kreş','egitim',3),
 ('hizmet:lokanta','saglik',6), ('hizmet:ulasim','ulasim',10), ('hizmet:kira','saglik',8), ('hizmet:istihdam','saglik',3),
 ('program:cevre','temizlik',8), ('program:cevre','yesil',4), ('program:afet','guvenlik',8),
 ('program:ulasim','ulasim',6), ('program:egitim_bursu','egitim',6), ('program:konut','saglik',4),
 ('yatirim:altyapi','su',6), ('yatirim:altyapi','ulasim',4), ('yatirim:rayli','ulasim',12)
on conflict (kaynak, alan) do update set puan = excluded.puan;

-- Kriz kararlarından gelen süreli karne etkileri
create table if not exists oyun.belediye_karne_etki(
  id bigint generated by default as identity primary key,
  il_id smallint not null references oyun.iller(id), alan text not null references oyun.belediye_karne_alan(kod),
  puan numeric not null, kaynak text not null default '', bitis timestamptz not null);
create index if not exists belediye_karne_etki_il_idx on oyun.belediye_karne_etki(il_id, bitis);

-- İller Bankası kredileri (borç başkana değil şehre aittir; yeni başkan devralır)
create table if not exists oyun.belediye_borc(
  id bigint generated by default as identity primary key,
  il_id smallint not null references oyun.iller(id), baskan uuid references oyun.profiller(id),
  anapara numeric not null check (anapara > 0), toplam numeric not null, kalan numeric not null,
  taksit numeric not null, gun int not null check (gun in (10, 20, 30)), faiz numeric not null,
  baslangic timestamptz not null, son_odeme date not null, gecikme int not null default 0,
  durum text not null default 'aktif' check (durum in ('aktif','kapandi')), kapanis timestamptz);
create index if not exists belediye_borc_il_idx on oyun.belediye_borc(il_id, durum);

-- Kriz masası
create table if not exists oyun.belediye_kriz_katalog(
  kod text primary key, baslik text not null, metin text not null,
  aylar int[], agirlik int not null default 10,
  secenekler jsonb not null, sessiz jsonb not null);
create table if not exists oyun.belediye_kriz(
  id bigint generated by default as identity primary key,
  il_id smallint not null references oyun.iller(id), kod text not null references oyun.belediye_kriz_katalog(kod),
  baskan uuid references oyun.profiller(id),
  baslangic timestamptz not null, son timestamptz not null,
  durum text not null default 'acik' check (durum in ('acik','cozuldu','sessiz')),
  secim text, maliyet numeric not null default 0, sonuc text, karar_zamani timestamptz);
create index if not exists belediye_kriz_il_idx on oyun.belediye_kriz(il_id, id desc);
create index if not exists belediye_kriz_acik_idx on oyun.belediye_kriz(son) where durum = 'acik';

do $$ declare t text; begin
  foreach t in array array['belediye_karne_alan','belediye_karne_harita','belediye_karne_etki','belediye_borc',
                           'belediye_kriz_katalog','belediye_kriz'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on table oyun.%I from public, anon, authenticated', t);
  end loop;
end $$;

-- Seçenek: k, ad, aciklama, gun (il günlük geliri cinsinden maliyet; eksi = gelir),
-- mem (memnuniyet), gel (gelişmişlik), etki {alan: puan} (14 gün), sans (başarı olasılığı),
-- basarisiz {mem, etki, metin}. sessiz: 24 saatte karar verilmezse işleyen sonuç.
insert into oyun.belediye_kriz_katalog(kod, baslik, metin, aylar, agirlik, secenekler, sessiz) values
('kar','Yoğun kar yağışı','Gece başlayan kar yolları kapattı; ana arterlerde araçlar mahsur kaldı.', array[11,12,1,2,3], 14,
 '[{"k":"a","ad":"Tüm ekipler sahaya, iş makinesi kirala","aciklama":"Pahalı ama şehir sabah açılır.","gun":1.5,"mem":2,"etki":{"ulasim":6}},
   {"k":"b","ad":"Yalnız ana arterleri aç","aciklama":"Mahalle araları birkaç gün kapalı kalır.","gun":0.5,"mem":-1,"etki":{"ulasim":1}},
   {"k":"c","ad":"Okulları tatil et, kar dursun","aciklama":"Bedava ama esnaf ve vatandaş öfkeli.","gun":0,"mem":-3,"etki":{"ulasim":-6}}]',
 '{"mem":-4,"etki":{"ulasim":-8},"metin":"Başkan ortada yoktu; şehir iki gün kardan çıkamadı."}'),
('su','Ana isale hattı patladı','Şehrin yarısında su kesik; vatandaşlar bidonlarla kuyrukta.', null, 12,
 '[{"k":"a","ad":"Acil onarım ve tanker desteği","aciklama":"Su 12 saatte gelir.","gun":1.2,"mem":1,"etki":{"su":5}},
   {"k":"b","ad":"Normal ihaleyle onar","aciklama":"Ucuz, ama kesinti günlerce sürer.","gun":0.4,"mem":-2,"etki":{"su":-4}}]',
 '{"mem":-4,"etki":{"su":-8},"metin":"Belediyeden açıklama gelmedi; kesinti üç gün sürdü."}'),
('cop','Çöp toplama krizi','Temizlik işçileri iş bıraktı, sokaklarda çöp yığılıyor.', null, 12,
 '[{"k":"a","ad":"Toplu sözleşmede zammı kabul et","aciklama":"İşçiler hemen işbaşı yapar.","gun":2,"mem":2,"etki":{"temizlik":6}},
   {"k":"b","ad":"Taşeron firmaya ihale et","aciklama":"Ucuz; firmanın işi beceremeyebilir.","gun":1,"mem":0,"etki":{"temizlik":2},"sans":0.55,"basarisiz":{"mem":-3,"etki":{"temizlik":-5},"metin":"Taşeron yetişemedi; çöp dağları büyüdü."}},
   {"k":"c","ad":"Grevi kanunsuz ilan et","aciklama":"Bedava ama sert tepki çeker.","gun":0,"mem":-4,"etki":{"temizlik":-8}}]',
 '{"mem":-5,"etki":{"temizlik":-10},"metin":"Belediye sessiz kaldı; çöp bir hafta toplanmadı."}'),
('sel','Sağanak ve sel','Dere taştı, alt geçitler ve bodrum katlar su altında.', array[9,10,11,3,4,5], 10,
 '[{"k":"a","ad":"AFAD ile ortak müdahale ve dere ıslahı","aciklama":"Kalıcı önlem; yüksek maliyet.","gun":2,"mem":2,"gel":0.4,"etki":{"guvenlik":6,"su":4}},
   {"k":"b","ad":"Hasar tespiti ve nakdî yardım","aciklama":"Mağdurlar desteklenir, altyapı aynı kalır.","gun":1,"mem":1,"etki":{"saglik":2}},
   {"k":"c","ad":"İl afet müdürlüğüne bırak","aciklama":"Belediye bütçesi korunur.","gun":0,"mem":-3,"etki":{"guvenlik":-5}}]',
 '{"mem":-5,"etki":{"guvenlik":-8,"su":-3},"metin":"Başkan sel bölgesine gitmedi; tepki büyüdü."}'),
('deprem','Orta şiddette deprem','Can kaybı yok ama eski binalarda çatlaklar var, halk sokakta.', null, 6,
 '[{"k":"a","ad":"Bina tarama ve güçlendirme programı","aciklama":"Pahalı ama şehir afete hazırlanır.","gun":2.5,"mem":2,"gel":0.5,"etki":{"guvenlik":10}},
   {"k":"b","ad":"Çadır kent ve psikososyal destek","aciklama":"Kısa vadeli rahatlama.","gun":0.8,"mem":2,"etki":{"saglik":4}},
   {"k":"c","ad":"Panik yok, açıklama yap","aciklama":"Bedava; güven sorunu doğabilir.","gun":0,"mem":-2,"etki":{"guvenlik":-4}}]',
 '{"mem":-5,"etki":{"guvenlik":-8},"metin":"Belediye deprem gecesi sessiz kaldı."}'),
('festival','Uluslararası festival başvurusu','Bir festival organizasyonu şehrinizde yapılmak için belediye desteği istiyor.', array[4,5,6,7,8,9], 10,
 '[{"k":"a","ad":"Ev sahipliği yap, tüm masrafı üstlen","aciklama":"Turizm ve kültüre büyük katkı.","gun":1.5,"mem":3,"gel":1,"etki":{"egitim":5}},
   {"k":"b","ad":"Sponsorlarla ortak yap","aciklama":"Ucuz; sponsor bulunamayabilir.","gun":0.3,"mem":2,"etki":{"egitim":3},"sans":0.6,"basarisiz":{"mem":-1,"etki":{},"metin":"Sponsor çıkmadı, festival sönük geçti."}},
   {"k":"c","ad":"Teşekkür et, reddet","aciklama":"Bütçe korunur.","gun":0,"mem":0,"etki":{}}]',
 '{"mem":-1,"etki":{},"metin":"Başvuru yanıtsız kaldı, festival komşu ile gitti."}'),
('hayvan','Sokak hayvanları şikâyeti','Mahalle sakinleri sokak hayvanları için belediyeden çözüm istiyor.', null, 8,
 '[{"k":"a","ad":"Barınak ve kısırlaştırma kampanyası","aciklama":"Kalıcı ve insancıl çözüm.","gun":0.8,"mem":1,"etki":{"saglik":3}},
   {"k":"b","ad":"Toplatıp barınağa götür","aciklama":"Ucuz ama hayvanseverler tepkili.","gun":0.2,"mem":-2,"etki":{"saglik":1}}]',
 '{"mem":-2,"etki":{"saglik":-2},"metin":"Şikâyetler cevapsız kaldı."}'),
('kavsak','Kavşakta ölümlü kaza','Aynı kavşakta bu ay üçüncü kaza; mahalleli yolu kapattı.', null, 9,
 '[{"k":"a","ad":"Akıllı kavşak ve üst geçit","aciklama":"Kalıcı çözüm.","gun":1,"mem":2,"etki":{"ulasim":6,"guvenlik":2}},
   {"k":"b","ad":"Hız kesici ve levha","aciklama":"Ucuz geçici önlem.","gun":0.1,"mem":0,"etki":{"ulasim":1}}]',
 '{"mem":-3,"etki":{"ulasim":-4,"guvenlik":-2},"metin":"Belediye taziye bile yayımlamadı."}'),
('rant','Müteahhitten imar teklifi','Büyük bir müteahhit, parkı imara açarsanız kasaya ciddi para bırakacağını söylüyor.', null, 7,
 '[{"k":"a","ad":"Kabul et, parkı imara aç","aciklama":"Kasaya para girer; çevreciler ayakta.","gun":-3,"mem":-3,"gel":0.5,"etki":{"yesil":-8}},
   {"k":"b","ad":"Halka sor (kent konseyi)","aciklama":"Halk onaylarsa uzlaşmalı proje.","gun":0.3,"mem":2,"etki":{"yesil":1},"sans":0.5,"basarisiz":{"mem":-1,"etki":{"yesil":-2},"metin":"Kent konseyi bölündü, proje askıda."}},
   {"k":"c","ad":"Reddet, park kalsın","aciklama":"Kasa boş kalır, halk memnun.","gun":0,"mem":2,"etki":{"yesil":3}}]',
 '{"mem":0,"etki":{},"metin":"Teklif cevapsız kaldı."}'),
('hava','Hava kirliliği alarmı','Kış aylarında partikül değerleri sınırı aştı.', array[11,12,1,2], 9,
 '[{"k":"a","ad":"Doğalgaz dönüşüm desteği","aciklama":"Sobalı evlere hibe.","gun":1.5,"mem":2,"etki":{"yesil":8,"saglik":3}},
   {"k":"b","ad":"Uyarı yayımla, denetim artır","aciklama":"Neredeyse bedava.","gun":0.1,"mem":-1,"etki":{"yesil":1}}]',
 '{"mem":-2,"etki":{"yesil":-4,"saglik":-2},"metin":"Belediye uyarıları görmezden geldi."}'),
('yangin','Orman yangını şehre yaklaşıyor','Yangın kent sınırına 5 km mesafede.', array[6,7,8,9], 10,
 '[{"k":"a","ad":"Tüm ekipleri ve kiralık helikopteri gönder","aciklama":"Yangın hızla kontrol altına alınır.","gun":2,"mem":3,"etki":{"guvenlik":8,"yesil":2}},
   {"k":"b","ad":"İtfaiyeyi yerleşim sınırına yığ","aciklama":"Ev kaybı olmaz, orman yanar.","gun":0.6,"mem":0,"etki":{"guvenlik":2,"yesil":-4}}]',
 '{"mem":-5,"etki":{"guvenlik":-6,"yesil":-6},"metin":"Başkan tatildeydi; yangın günlerce sürdü."}'),
('maas','Belediye işçileri maaş farkı istiyor','Sendika, enflasyon farkı ödenmezse eylem kararı alacağını açıkladı.', null, 10,
 '[{"k":"a","ad":"Talebi tam karşıla","aciklama":"Hizmetler aksamaz.","gun":1.5,"mem":1,"etki":{"temizlik":4}},
   {"k":"b","ad":"Yarısını öde, uzlaş","aciklama":"Sendika kabul edebilir.","gun":0.6,"mem":0,"etki":{"temizlik":2},"sans":0.6,"basarisiz":{"mem":-2,"etki":{"temizlik":-4},"metin":"Sendika uzlaşmayı reddetti, iş yavaşlattı."}},
   {"k":"c","ad":"Reddet","aciklama":"Bütçe korunur, eylem başlar.","gun":0,"mem":-2,"etki":{"temizlik":-6}}]',
 '{"mem":-3,"etki":{"temizlik":-6},"metin":"Sendikanın mektubu yanıtsız kaldı; eylem başladı."}'),
('tarihi','İnşaatta tarihî eser','Belediye kazısında Roma dönemine ait mozaikler çıktı.', null, 6,
 '[{"k":"a","ad":"Kazıyı genişlet, müze kur","aciklama":"Kültür turizmine yatırım.","gun":1,"mem":2,"gel":0.5,"etki":{"egitim":6}},
   {"k":"b","ad":"Üstünü kapat, inşaata devam","aciklama":"Bedava; ortaya çıkarsa skandal.","gun":0,"mem":0,"etki":{},"sans":0.7,"basarisiz":{"mem":-6,"etki":{"egitim":-4},"metin":"Gizlenen mozaikler basına sızdı; büyük skandal."}}]',
 '{"mem":-1,"etki":{"egitim":-2},"metin":"Kazı kendi hâline bırakıldı."}'),
('sicak','Sıcak hava dalgası','Termometreler 42 dereceyi gösteriyor; yaşlılar risk altında.', array[6,7,8], 9,
 '[{"k":"a","ad":"Serinleme merkezleri ve su dağıtımı","aciklama":"Kırılgan gruplar korunur.","gun":0.5,"mem":2,"etki":{"saglik":4}},
   {"k":"b","ad":"Sadece duyuru yap","aciklama":"Bedava.","gun":0,"mem":-1,"etki":{"saglik":-1}}]',
 '{"mem":-2,"etki":{"saglik":-3},"metin":"Belediye sıcak dalgasında önlem almadı."}'),
('yatirimci','Fabrika yatırımı teklifi','Bir yatırımcı, belediye arsa ve altyapı desteği verirse şehre fabrika kurmak istiyor.', null, 8,
 '[{"k":"a","ad":"Arsa ve altyapıyı belediye karşılasın","aciklama":"İstihdam ve gelişmişlik artar.","gun":1.5,"mem":2,"gel":1.2,"etki":{"yesil":-2}},
   {"k":"b","ad":"Arsayı bedelli ver","aciklama":"Kasaya para girer; yatırımcı vazgeçebilir.","gun":-1,"mem":1,"gel":0.6,"etki":{},"sans":0.5,"basarisiz":{"mem":0,"etki":{},"metin":"Yatırımcı başka ile gitti."}},
   {"k":"c","ad":"Çevre gerekçesiyle reddet","aciklama":"Çevreciler memnun.","gun":0,"mem":0,"etki":{"yesil":2}}]',
 '{"mem":-1,"etki":{},"metin":"Yatırımcı yanıt alamayınca başka ile gitti."}')
on conflict (kod) do update set baslik = excluded.baslik, metin = excluded.metin, aylar = excluded.aylar,
  agirlik = excluded.agirlik, secenekler = excluded.secenekler, sessiz = excluded.sessiz;

-- ---------------------------------------------------------------- karne
-- Büyük ilin aynı puan için daha çok yatırıma ihtiyacı var.
create or replace function oyun.belediye_olcek(p_il smallint) returns numeric
language sql stable set search_path = '' as $$
  select greatest(0.7, least(2.2, sqrt(greatest(1, i.mv)::numeric / 7.4))) from oyun.iller i where i.id = p_il
$$;

create or replace function oyun.belediye_karne_katki(p_il smallint)
returns table(alan text, kaynak text, puan numeric)
language sql stable set search_path = '' as $$
  with t as (select oyun.simdi() s)
  select m.alan, k.ad || ' · ' || b.seviye || '. seviye',
         m.puan * (case b.seviye when 1 then 1 when 2 then 1.6 else 2.1 end)
    from oyun.belediye_bina b join oyun.belediye_bina_katalog k on k.kod = b.kod
    join oyun.belediye_karne_harita m on m.kaynak = 'bina:' || b.kod
   where b.il_id = p_il and b.durum = 'aktif' and b.seviye > 0
  union all
  select m.alan, bh.ad, m.puan
    from oyun.il_hizmet h join oyun.belediye_hizmetleri bh on bh.kod = h.kod
    join oyun.belediye_karne_harita m on m.kaynak = 'hizmet:' || h.kod
   where h.il_id = p_il
  union all
  select m.alan, k.ad || ' (program)',
         m.puan * greatest(0, 1 - extract(epoch from (t.s - x.zaman)) / (7 * 86400.0))
    from oyun.belediye_ekonomi_karar x join oyun.belediye_ekonomi_katalog k on k.kod = x.kod
    join oyun.belediye_karne_harita m on m.kaynak = 'program:' || x.kod, t
   where x.il_id = p_il and x.zaman > t.s - interval '7 days'
  union all
  select m.alan, y.ad,
         case when x.kod = 'rayli' then m.puan
              else m.puan * greatest(0, 1 - extract(epoch from (t.s - x.zaman)) / (30 * 86400.0)) end
    from (select kod, zaman, row_number() over (partition by kod order by zaman desc) n
            from oyun.belediye_proje_kayit where il_id = p_il) x
    join oyun.belediye_yatirimlari y on y.kod = x.kod
    join oyun.belediye_karne_harita m on m.kaynak = 'yatirim:' || x.kod, t
   where (x.kod = 'rayli' and x.n <= 2) or (x.kod <> 'rayli' and x.zaman > t.s - interval '30 days')
  union all
  select e.alan, e.kaynak, e.puan from oyun.belediye_karne_etki e, t
   where e.il_id = p_il and e.bitis > t.s
$$;

create or replace function oyun.belediye_karne(p_il smallint) returns jsonb
language plpgsql stable set search_path = '' as $$
declare taban numeric; olcek numeric; sonuc jsonb; ort numeric;
begin
  select 30 + 0.3 * coalesce(d.gelisim, 50) into taban from oyun.il_durum d where d.il_id = p_il;
  olcek := oyun.belediye_olcek(p_il);
  with k as (select * from oyun.belediye_karne_katki(p_il)),
  a as (
    select al.kod, al.ad, al.aciklama, al.sira,
           round(oyun.sinir(coalesce(taban, 45) + coalesce((select sum(k.puan) from k where k.alan = al.kod), 0) / olcek, 0, 100), 1) puan,
           coalesce((select jsonb_agg(jsonb_build_object('kaynak', z.kaynak, 'puan', round(z.p / olcek, 1)) order by abs(z.p) desc)
                       from (select k.kaynak, sum(k.puan) p from k where k.alan = al.kod group by k.kaynak
                             order by abs(sum(k.puan)) desc limit 6) z), '[]'::jsonb) katkilar
      from oyun.belediye_karne_alan al)
  select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad, 'aciklama', aciklama, 'puan', puan, 'katkilar', katkilar) order by sira),
         round(avg(puan), 1)
    into sonuc, ort from a;
  return jsonb_build_object('alanlar', coalesce(sonuc, '[]'::jsonb), 'ortalama', ort,
                            'taban', round(coalesce(taban, 45), 1), 'olcek', round(olcek, 2));
end $$;

create or replace function oyun.belediye_karne_ort(p_il smallint) returns numeric
language sql stable set search_path = '' as $$
  select coalesce((oyun.belediye_karne(p_il)->>'ortalama')::numeric, 45)
$$;

-- ---------------------------------------------------------------- kredi
create or replace function oyun.belediye_kredi_faiz(p_gun int) returns numeric
language sql stable set search_path = '' as $$
  -- dönemin tamamı için: aylık (enflasyon/12 + 1) puan, güne oranlanır
  select round(((coalesce(u.enflasyon, 30) / 12 + 1) / 100) * p_gun / 30.0, 4) from oyun.ulke u where u.id = 1
$$;

create or replace function oyun.belediye_kredi_limit(p_il smallint) returns numeric
language sql stable set search_path = '' as $$
  select round(greatest(0, 20 * oyun.il_gelir(p_il)
           - coalesce((select sum(kalan) from oyun.belediye_borc where il_id = p_il and durum = 'aktif'), 0)), 4)
$$;

create or replace function public.belediye_kredi_al(p_tutar numeric, p_gun int)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); m oyun.makamlar := oyun.baskan_zorunlu(p);
  t timestamptz := oyun.simdi(); lim numeric; f numeric; toplam numeric; yid bigint; ilad text;
begin
  if p_gun is null or p_gun not in (10, 20, 30) then raise exception 'Vade 10, 20 ya da 30 gün olabilir'; end if;
  if p_tutar is null or p_tutar < 0.01 then raise exception 'Kredi en az 0,01 milyar ₺ (10 milyon ₺) olmalı'; end if;
  p_tutar := round(p_tutar, 4);
  perform pg_advisory_xact_lock(772922, m.il_id::integer);
  if (select count(*) from oyun.belediye_borc where il_id = m.il_id and durum = 'aktif') >= 3 then
    raise exception 'Aynı anda en fazla 3 kredi kullanılabilir'; end if;
  if exists (select 1 from oyun.belediye_borc where il_id = m.il_id and baslangic > t - interval '24 hours') then
    raise exception 'İller Bankası 24 saatte bir kredi verir'; end if;
  if exists (select 1 from oyun.belediye_borc where il_id = m.il_id and durum = 'aktif' and gecikme >= 3) then
    raise exception 'Gecikmedeki taksitler ödenmeden yeni kredi verilmez'; end if;
  lim := oyun.belediye_kredi_limit(m.il_id);
  if p_tutar > lim then
    raise exception 'Kredi limiti: % milyar ₺ (20 günlük gelirden mevcut borç düşülür)', to_char(lim, 'FM999990.0000'); end if;
  f := oyun.belediye_kredi_faiz(p_gun);
  toplam := round(p_tutar * (1 + f), 6);
  insert into oyun.belediye_borc(il_id, baskan, anapara, toplam, kalan, taksit, gun, faiz, baslangic, son_odeme)
  values (m.il_id, p.id, p_tutar, toplam, toplam, round(toplam / p_gun, 6), p_gun, f, t, (t at time zone 'Europe/Istanbul')::date)
  returning id into yid;
  update oyun.il_durum set kasa = kasa + p_tutar where il_id = m.il_id;
  insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
  values (m.il_id, 'kredi', p_tutar, format('İller Bankası kredisi · %s gün · geri ödeme %s milyar ₺', p_gun, to_char(toplam, 'FM999990.0000')), t);
  select ad into ilad from oyun.iller where id = m.il_id;
  perform oyun.olay('belediye', format('%s Belediyesi İller Bankası''ndan %s milyar ₺ kredi çekti (%s gün vadeli).',
                    ilad, to_char(p_tutar, 'FM999990.00##'), p_gun), m.il_id, p.parti_id, t);
  return jsonb_build_object('tamam', true, 'id', yid, 'anapara', p_tutar, 'toplam', toplam,
                            'taksit', round(toplam / p_gun, 6), 'faiz', f);
end $$;

create or replace function public.belediye_kredi_kapat(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); m oyun.makamlar := oyun.baskan_zorunlu(p);
  b oyun.belediye_borc; t timestamptz := oyun.simdi(); v_kasa numeric;
begin
  perform pg_advisory_xact_lock(772922, m.il_id::integer);
  select * into b from oyun.belediye_borc where id = p_id and il_id = m.il_id and durum = 'aktif' for update;
  if b.id is null then raise exception 'Kapatılacak kredi bulunamadı'; end if;
  select kasa into v_kasa from oyun.il_durum where il_id = m.il_id for update;
  if v_kasa < b.kalan then
    raise exception 'Kasa yetersiz: kalan borç % milyar ₺', to_char(b.kalan, 'FM999990.0000'); end if;
  update oyun.il_durum set kasa = kasa - b.kalan where il_id = m.il_id;
  update oyun.belediye_borc set kalan = 0, durum = 'kapandi', kapanis = t where id = b.id;
  insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
  values (m.il_id, 'kredi_kapama', -b.kalan, 'İller Bankası kredisi erken kapatıldı', t);
  return jsonb_build_object('tamam', true, 'odenen', b.kalan);
end $$;

-- ---------------------------------------------------------------- kriz masası
create or replace function oyun.belediye_kriz_etki(p_il smallint, p_etki jsonb, p_kaynak text, p_t timestamptz)
returns void language plpgsql set search_path = '' as $$
declare k text; v text;
begin
  for k, v in select * from jsonb_each_text(coalesce(p_etki, '{}'::jsonb)) loop
    if exists (select 1 from oyun.belediye_karne_alan where kod = k) and v::numeric <> 0 then
      insert into oyun.belediye_karne_etki(il_id, alan, puan, kaynak, bitis)
      values (p_il, k, v::numeric, left(p_kaynak, 120), p_t + interval '14 days');
    end if;
  end loop;
end $$;

create or replace function oyun.belediye_kriz_baslat(p_il smallint, p_kod text default null)
returns bigint language plpgsql set search_path = '' as $$
declare t timestamptz := oyun.simdi(); ay int := extract(month from (oyun.simdi() at time zone 'Europe/Istanbul'));
  v_kod text := p_kod; k oyun.belediye_kriz_katalog; bas uuid; ilad text; yid bigint;
begin
  select user_id into bas from oyun.makamlar where tur = 'bel' and il_id = p_il and bit is null order by id desc limit 1;
  if bas is null or exists (select 1 from oyun.belediye_kriz where il_id = p_il and durum = 'acik') then return null; end if;
  if v_kod is null then
    select c.kod into v_kod from oyun.belediye_kriz_katalog c
     where (c.aylar is null or ay = any(c.aylar))
       and c.kod not in (select x.kod from oyun.belediye_kriz x where x.il_id = p_il order by x.id desc limit 4)
     order by -ln(greatest(random(), 1e-9)) / c.agirlik limit 1;
  end if;
  select * into k from oyun.belediye_kriz_katalog where kod = v_kod;
  if k.kod is null then return null; end if;
  insert into oyun.belediye_kriz(il_id, kod, baskan, baslangic, son)
  values (p_il, k.kod, bas, t, t + interval '24 hours') returning id into yid;
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.bildir(bas, format('Kriz masası: %s. 24 saat içinde karar ver (Yönetim › Belediye › Kriz masası).', k.baslik), t);
  perform oyun.olay('belediye', format('%s''da kriz: %s. Gözler belediye başkanında.', ilad, k.baslik), p_il, null, t);
  return yid;
end $$;

create or replace function oyun.belediye_kriz_uygula(p_kriz bigint, p_secim text, p_t timestamptz)
returns jsonb language plpgsql set search_path = '' as $$
declare x oyun.belediye_kriz; k oyun.belediye_kriz_katalog; s jsonb; v_maliyet numeric := 0; basarili boolean := true;
  mem numeric; gel numeric; etki jsonb; metin text; ilad text; v_durum text; secad text; bkad text;
begin
  select * into x from oyun.belediye_kriz where id = p_kriz and durum = 'acik' for update;
  if x.id is null then raise exception 'Bu kriz kapanmış'; end if;
  select * into k from oyun.belediye_kriz_katalog where kod = x.kod;
  select ad into ilad from oyun.iller where id = x.il_id;
  if p_secim is null then
    v_durum := 'sessiz'; s := k.sessiz; mem := coalesce((s->>'mem')::numeric, 0); gel := 0;
    etki := s->'etki'; metin := s->>'metin'; secad := 'Karar verilmedi';
  else
    select e into s from jsonb_array_elements(k.secenekler) e where e->>'k' = p_secim;
    if s is null then raise exception 'Geçersiz seçenek'; end if;
    v_durum := 'cozuldu'; secad := s->>'ad';
    v_maliyet := round(coalesce((s->>'gun')::numeric, 0) * oyun.il_gelir(x.il_id), 6);
    if v_maliyet > 0 and (select kasa from oyun.il_durum where il_id = x.il_id) < v_maliyet then
      raise exception 'Belediye kasası yetersiz: % milyar ₺ gerekli. İller Bankası''ndan kredi çekebilirsin.',
        to_char(v_maliyet, 'FM999990.0000'); end if;
    basarili := random() < coalesce((s->>'sans')::numeric, 1);
    if basarili then
      mem := coalesce((s->>'mem')::numeric, 0); gel := coalesce((s->>'gel')::numeric, 0); etki := s->'etki';
      metin := format('%s: %s', ilad, s->>'ad');
    else
      mem := coalesce((s->'basarisiz'->>'mem')::numeric, 0); gel := 0; etki := s->'basarisiz'->'etki';
      metin := format('%s: %s', ilad, s->'basarisiz'->>'metin');
    end if;
  end if;
  update oyun.il_durum set kasa = kasa - v_maliyet,
         memnuniyet = oyun.sinir(memnuniyet + mem, 0, 100), gelisim = oyun.sinir(gelisim + gel, 0, 100)
   where il_id = x.il_id;
  perform oyun.belediye_kriz_etki(x.il_id, etki, k.baslik, p_t);
  if v_maliyet <> 0 then
    insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
    values (x.il_id, 'kriz', -v_maliyet, left(k.baslik || ' · ' || secad, 170), p_t);
  end if;
  update oyun.belediye_kriz set durum = v_durum, secim = p_secim, maliyet = v_maliyet,
         sonuc = case when v_durum = 'sessiz' then metin when basarili then 'Başarılı' else s->'basarisiz'->>'metin' end,
         karar_zamani = p_t
   where id = x.id;
  select kad into bkad from oyun.profiller where id = x.baskan;
  perform oyun.olay('belediye',
    case when v_durum = 'sessiz' then format('%s: %s — %s', ilad, k.baslik, metin)
         else format('%s Belediye Başkanı %s, %s krizinde kararını verdi: %s.%s', ilad, coalesce(bkad, ''), lower(k.baslik), secad,
                     case when basarili then '' else ' Ancak sonuç beklendiği gibi olmadı.' end) end,
    x.il_id, (select parti_id from oyun.profiller where id = x.baskan), p_t);
  if v_durum = 'sessiz' and x.baskan is not null then
    perform oyun.bildir(x.baskan, format('Kriz masası: %s için 24 saatte karar vermedin. %s', k.baslik, metin), p_t);
  end if;
  return jsonb_build_object('tamam', true, 'durum', v_durum, 'basarili', basarili, 'maliyet', v_maliyet,
                            'memnuniyet', mem, 'sonuc', metin);
end $$;

create or replace function oyun.belediye_kriz_tick(p_olasilik numeric default 0.06)
returns integer language plpgsql set search_path = '' as $$
declare t timestamptz := oyun.simdi(); r record; n int := 0;
begin
  if not pg_try_advisory_xact_lock(772923, 1) then return 0; end if;
  for r in select id from oyun.belediye_kriz where durum = 'acik' and son <= t order by id loop
    perform oyun.belediye_kriz_uygula(r.id, null, t); n := n + 1;
  end loop;
  -- Görevde başkan yoksa açık kriz yöneticisiz kalmasın: başkanı düşen ilin krizi kapanır.
  update oyun.belediye_kriz k set durum = 'sessiz', sonuc = 'Başkanlık boşaldı', karar_zamani = t
   where k.durum = 'acik' and not exists (select 1 from oyun.makamlar m where m.tur = 'bel' and m.il_id = k.il_id and m.bit is null);
  for r in select m.il_id from oyun.makamlar m
            where m.tur = 'bel' and m.bit is null
              and not exists (select 1 from oyun.belediye_kriz k where k.il_id = m.il_id
                                and (k.durum = 'acik' or k.baslangic > t - interval '36 hours'))
              and random() < p_olasilik loop
    if oyun.belediye_kriz_baslat(r.il_id) is not null then n := n + 1; end if;
  end loop;
  return n;
end $$;

create or replace function public.belediye_kriz_karar(p_id bigint, p_secim text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); m oyun.makamlar := oyun.baskan_zorunlu(p);
  t timestamptz := oyun.simdi();
begin
  if p_secim is null or btrim(p_secim) = '' then raise exception 'Bir seçenek seç'; end if;
  perform pg_advisory_xact_lock(772922, m.il_id::integer);
  if not exists (select 1 from oyun.belediye_kriz where id = p_id and il_id = m.il_id and durum = 'acik' and son > t) then
    raise exception 'Bu kriz için karar süresi doldu ya da kriz senin ilinde değil'; end if;
  return oyun.belediye_kriz_uygula(p_id, p_secim, t);
end $$;

-- ---------------------------------------------------------------- paneller
create or replace function oyun.belediye_kriz_json(x oyun.belediye_kriz) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', x.id, 'kod', x.kod, 'baslik', k.baslik, 'metin', k.metin,
    'baslangic', x.baslangic, 'son', x.son, 'durum', x.durum, 'secim', x.secim, 'maliyet', x.maliyet,
    'sonuc', x.sonuc, 'karar_zamani', x.karar_zamani,
    'secim_ad', (select e->>'ad' from jsonb_array_elements(k.secenekler) e where e->>'k' = x.secim),
    'secenekler', (select jsonb_agg(e || jsonb_build_object('maliyet', round(coalesce((e->>'gun')::numeric, 0) * oyun.il_gelir(x.il_id), 6)))
                     from jsonb_array_elements(k.secenekler) e))
  from oyun.belediye_kriz_katalog k where k.kod = x.kod
$$;

create or replace function public.belediye_detay_paneli()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); m oyun.makamlar; d oyun.il_durum;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bel' and bit is null order by id desc limit 1;
  if m.id is null then return null; end if;
  select * into d from oyun.il_durum where il_id = m.il_id;
  return jsonb_build_object(
    'il_id', m.il_id, 'il_ad', (select ad from oyun.iller where id = m.il_id),
    'kasa', d.kasa, 'memnuniyet', d.memnuniyet, 'gelisim', d.gelisim,
    'gunluk_gelir', oyun.il_gelir(m.il_id), 'gunluk_gider', oyun.il_gider(m.il_id),
    'tl_milyar', oyun.pazar_tl_milyar(),
    'karne', oyun.belediye_karne(m.il_id),
    'kredi', jsonb_build_object(
       'limit', oyun.belediye_kredi_limit(m.il_id),
       'faiz', jsonb_build_object('10', oyun.belediye_kredi_faiz(10), '20', oyun.belediye_kredi_faiz(20), '30', oyun.belediye_kredi_faiz(30)),
       'son_kredi', (select max(baslangic) from oyun.belediye_borc where il_id = m.il_id),
       'borclar', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'anapara', anapara, 'toplam', toplam, 'kalan', kalan,
            'taksit', taksit, 'gun', gun, 'faiz', faiz, 'baslangic', baslangic, 'gecikme', gecikme, 'durum', durum) order by id desc)
          from (select * from oyun.belediye_borc where il_id = m.il_id and (durum = 'aktif' or kapanis > oyun.simdi() - interval '7 days')
                order by id desc limit 8) b), '[]'::jsonb),
       'toplam_borc', coalesce((select sum(kalan) from oyun.belediye_borc where il_id = m.il_id and durum = 'aktif'), 0)),
    'kriz', (select oyun.belediye_kriz_json(x) from oyun.belediye_kriz x where x.il_id = m.il_id and x.durum = 'acik' order by id desc limit 1),
    'kriz_gecmis', coalesce((select jsonb_agg(oyun.belediye_kriz_json(x) order by x.id desc)
          from (select * from oyun.belediye_kriz where il_id = m.il_id and durum <> 'acik' order by id desc limit 8) x), '[]'::jsonb));
end $$;

-- Herkese açık belediye karnesi: seçmen başkanı hizmetle, borçla, krizlerdeki kararlarıyla görür.
create or replace function public.belediye_karnesi(p_il integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare d oyun.il_durum; bas record;
begin
  if auth.uid() is null then raise exception 'Oturum açmalısın'; end if;
  select * into d from oyun.il_durum where il_id = p_il;
  if d.il_id is null then raise exception 'İl bulunamadı'; end if;
  select pr.kad, pr.id, pa.kisa parti, m.bas into bas from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
    left join oyun.partiler pa on pa.id = pr.parti_id
   where m.tur = 'bel' and m.il_id = p_il and m.bit is null order by m.id desc limit 1;
  return jsonb_build_object('il_id', p_il, 'il_ad', (select ad from oyun.iller where id = p_il),
    'baskan', case when bas.kad is null then null else jsonb_build_object('kad', bas.kad, 'parti', bas.parti, 'bas', bas.bas) end,
    'kasa', d.kasa, 'memnuniyet', d.memnuniyet, 'gelisim', d.gelisim,
    'borc', coalesce((select sum(kalan) from oyun.belediye_borc where il_id = p_il and durum = 'aktif'), 0),
    'gecikme', coalesce((select sum(gecikme) from oyun.belediye_borc where il_id = p_il and durum = 'aktif'), 0),
    'aktif_bina', (select count(*) from oyun.belediye_bina where il_id = p_il and durum = 'aktif'),
    'karne', oyun.belediye_karne(p_il::smallint),
    'krizler', coalesce((select jsonb_agg(jsonb_build_object('baslik', k.baslik, 'durum', x.durum, 'zaman', coalesce(x.karar_zamani, x.baslangic),
           'secim_ad', (select e->>'ad' from jsonb_array_elements(k.secenekler) e where e->>'k' = x.secim), 'sonuc', x.sonuc) order by x.id desc)
        from (select * from oyun.belediye_kriz where il_id = p_il order by id desc limit 6) x
        join oyun.belediye_kriz_katalog k on k.kod = x.kod), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------- gece hesabı
create or replace function oyun.belediye_gunluk(t timestamptz) returns void language plpgsql as $$
declare r record; h record; b record; v_kasa numeric; bas uuid; g numeric; pay numeric;
  bugun date := (t at time zone 'Europe/Istanbul')::date;
begin
  for r in select d.il_id, i.ad, i.mv from oyun.il_durum d join oyun.iller i on i.id = d.il_id loop
    g := oyun.il_gelir(r.il_id);
    -- Vergi geliri 60 günlük gelire kadar birikir; bağış ve kredi gibi dış kaynaklar kesilmez.
    update oyun.il_durum set kasa = coalesce(kasa, 0) + least(g, greatest(0, 60 * g - coalesce(kasa, 0))) - oyun.il_gider(r.il_id)
     where il_id = r.il_id returning kasa into v_kasa;
    -- İller Bankası taksitleri
    for b in select * from oyun.belediye_borc where il_id = r.il_id and durum = 'aktif' and son_odeme < bugun order by id loop
      pay := least(b.taksit, b.kalan);
      if v_kasa >= pay then
        update oyun.il_durum set kasa = kasa - pay where il_id = r.il_id returning kasa into v_kasa;
        update oyun.belediye_borc set kalan = round(kalan - pay, 6), son_odeme = bugun,
               durum = case when kalan - pay <= 0.000001 then 'kapandi' else 'aktif' end,
               kapanis = case when kalan - pay <= 0.000001 then t end
         where id = b.id;
        insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
        values (r.il_id, 'kredi_taksit', -pay, 'İller Bankası taksiti', t);
      else
        update oyun.belediye_borc set kalan = round(kalan + b.taksit * 0.05, 6), gecikme = gecikme + 1, son_odeme = bugun
         where id = b.id;
        update oyun.il_durum set memnuniyet = oyun.sinir(memnuniyet - 1, 0, 100) where il_id = r.il_id;
        insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
        values (r.il_id, 'kredi_gecikme', 0, 'İller Bankası taksiti ödenemedi; %5 gecikme cezası borca eklendi', t);
        bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
        if bas is not null then
          perform oyun.bildir(bas, 'İller Bankası taksiti kasada para olmadığı için ödenemedi; %5 gecikme cezası eklendi.', t);
        end if;
        if (b.gecikme + 1) % 3 = 0 then
          perform oyun.olay('belediye', format('Sayıştay uyarısı: %s Belediyesi İller Bankası borcunu %s gündür ödeyemiyor.', r.ad, b.gecikme + 1), r.il_id, null, t);
        end if;
      end if;
    end loop;
    if v_kasa < 0 then
      bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
      update oyun.il_durum set hemsehri = 0 where il_id = r.il_id and hemsehri > 0;
      for h in select k.kod, bh.ad from oyun.il_hizmet k join oyun.belediye_hizmetleri bh on bh.kod = k.kod
               where k.il_id = r.il_id order by bh.oran desc loop
        exit when (select kasa from oyun.il_durum where il_id = r.il_id) >= 0;
        delete from oyun.il_hizmet where il_id = r.il_id and kod = h.kod;
        update oyun.il_durum set kasa = kasa + oyun.hizmet_gider(r.il_id, h.kod) where il_id = r.il_id;
        perform oyun.olay('belediye', format('%s Belediyesi kasası yetmediği için %s hizmetini kapattı.', r.ad, h.ad), r.il_id, null, t);
      end loop;
      if bas is not null then perform oyun.bildir(bas, 'Belediye kasası eksiye düştü: hemşehri desteği durduruldu, gerekirse hizmetler kapatıldı.', t); end if;
      update oyun.il_durum set kasa = greatest(kasa, 0) where il_id = r.il_id;
    end if;
  end loop;
  delete from oyun.belediye_karne_etki where bitis < t - interval '30 days';
  -- gelişmişlik yatırım almazsa yavaşça ortalamaya döner; memnuniyet hizmetlere, desteğe, vergiye
  -- ve hizmet karnesine (binalar, programlar, kriz kararları) göre şekillenir
  update oyun.il_durum d set gelisim = gelisim + (50 - gelisim) * 0.01,
    memnuniyet = oyun.sinir(memnuniyet + (50 + 4 * (select count(*) from oyun.il_hizmet ih where ih.il_id = d.il_id) + least(10, hemsehri / 30)
                                          - kent_vergisi * 2 - oyun.il_duz(d.il_id, 'emlak') / 30
                                          + (oyun.belediye_karne_ort(d.il_id) - 45) * 0.5 - memnuniyet) * 0.05, 0, 100);
end $$;

-- ---------------------------------------------------------------- yetkiler
revoke all on function public.belediye_kredi_al(numeric, int), public.belediye_kredi_kapat(bigint),
  public.belediye_kriz_karar(bigint, text), public.belediye_detay_paneli(), public.belediye_karnesi(integer)
  from public, anon, authenticated;
grant execute on function public.belediye_kredi_al(numeric, int), public.belediye_kredi_kapat(bigint),
  public.belediye_kriz_karar(bigint, text), public.belediye_detay_paneli(), public.belediye_karnesi(integer)
  to authenticated;
revoke all on function oyun.belediye_kriz_tick(numeric), oyun.belediye_kriz_baslat(smallint, text),
  oyun.belediye_kriz_uygula(bigint, text, timestamptz), oyun.belediye_kriz_etki(smallint, jsonb, text, timestamptz)
  from public, anon, authenticated;
select cron.schedule('belediye-kriz', '7 * * * *', 'select oyun.belediye_kriz_tick()');
commit;
