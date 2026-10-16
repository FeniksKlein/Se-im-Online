begin;
-- 2026-10-16: 12 bakanlığa üçer yeni oynanabilir görev (36 adet).
-- Yalnızca katalog ekler; oyuncu, makam, kasa, icraat geçmişi ve seçim kayıtlarına dokunmaz.
-- Görevleri mevcut icraat_yap RPC'si yürütür: yetki, bütçe, 72/168 saat bekleme,
-- ülke/il göstergeleri, oyuncu etkileri, Resmî Gazete ve arşiv kayıtları aynı kalır.

insert into oyun.icraatlar
  (kod, bakanlik, ad, aciklama, maliyet, bekleme_saat, il_gerekli, etki, oyuncu, sure_gun)
values
  ('bg_adl_uzak','adalet','Görev: Uzaktan duruşma ağı','Seçilen ilin adli erişimi iyileşir; gelişmişlik 2 puan yükselir.',6,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
  ('bg_adl_adli_yardim','adalet','Görev: Adli yardım seferberliği','7 gün boyunca tüm oyuncuların geçim yükü %3 azalır.',4,168,false,'{"memnuniyet":0.3}'::jsonb,'[{"tur":"gecim","deger":3}]'::jsonb,7),
  ('bg_adl_genc_hukuk','adalet','Görev: Hukukta gençlik stajı','Hukuk stajları 7 gün boyunca yeni oyuncuların kıdem kazanımını %15 artırır.',4,168,false,'{"memnuniyet":0.2}'::jsonb,'[{"tur":"kidem_x","deger":15}]'::jsonb,7),

  ('bg_dis_ticaret','disisleri','Görev: Ticaret diplomasisi','Dış ticaret heyetleri büyümeyi 0,15 puan yükseltir.',6,168,false,'{"buyume":0.15}'::jsonb,'[]'::jsonb,null),
  ('bg_dis_konsolosluk','disisleri','Görev: Dijital konsolosluk hattı','Yurt dışı işlemleri kolaylaşır; 7 gün tüm oyuncuların taşınma maliyeti %10 azalır.',4,168,false,'{"memnuniyet":0.2}'::jsonb,'[{"tur":"tasinma","deger":10}]'::jsonb,7),
  ('bg_dis_turizm_il','disisleri','Görev: Şehir tanıtım anlaşması','Seçilen ilin dış tanıtımı gelişmişliğini 2 puan artırır.',5,72,true,'{"gelisim":2,"buyume":0.05}'::jsonb,'[]'::jsonb,null),

  ('bg_ic_kimlik','icisleri','Görev: Gezici nüfus hizmeti','Seçilen ilde kamu hizmetlerine erişim gelişmişliği 2 puan artırır.',4,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
  ('bg_ic_erken_uyari','icisleri','Görev: Afet erken uyarı ağı','Seçilen ilin afet hazırlığı gelişmişliğe 2 puan ekler.',7,72,true,'{"gelisim":2,"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
  ('bg_ic_siber_ihbar','icisleri','Görev: Siber dolandırıcılık ihbar hattı','Güvenli dijital hizmetler memnuniyeti 0,4 puan artırır.',3,168,false,'{"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),

  ('bg_mal_saydam','maliye','Görev: Kamu harcaması şeffaflığı','Bütçe denetimi memnuniyeti 0,3 puan artırır.',3,168,false,'{"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
  ('bg_mal_girisim_il','maliye','Görev: Yerel girişim fonu','Seçilen ilde 7 gün maaşlar %4 artar; gelişmişlik 1 puan yükselir.',7,72,true,'{"gelisim":1,"buyume":0.05}'::jsonb,'[{"tur":"ucret","deger":4}]'::jsonb,7),
  ('bg_mal_vergi_okur','maliye','Görev: Vergi bilinci desteği','7 gün tüm oyuncuların geçim yükünü %3 azaltan mali rehberlik programı.',4,168,false,'{"memnuniyet":0.2}'::jsonb,'[{"tur":"gecim","deger":3}]'::jsonb,7),

  ('bg_sav_afet','savunma','Görev: Askerî afet lojistik merkezi','Seçilen ilde afet lojistiği yatırımı gelişmişliği 2 puan artırır.',8,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
  ('bg_sav_tedarik','savunma','Görev: Yerli savunma tedariki','Yerli tedarik anlaşmaları ülke büyümesini 0,15 puan artırır.',7,168,false,'{"buyume":0.15}'::jsonb,'[]'::jsonb,null),
  ('bg_sav_gazi','savunma','Görev: Gazi istihdam programı','İstihdam desteği 7 gün ülke genelindeki maaşlara %3 katkı sağlar.',5,168,false,'{"issizlik":-0.1,"memnuniyet":0.2}'::jsonb,'[{"tur":"ucret","deger":3}]'::jsonb,7),

  ('bg_egt_yemek','egitim','Görev: Okul beslenme desteği','Seçilen ilde 7 gün geçim masrafı %4 azalır.',5,72,true,'{"memnuniyet":0.3,"gelisim":1}'::jsonb,'[{"tur":"gecim","deger":4}]'::jsonb,7),
  ('bg_egt_kutuphane','egitim','Görev: Dijital kütüphane ağı','7 gün boyunca kıdem kazanımı %20 artar.',5,168,false,'{"memnuniyet":0.2}'::jsonb,'[{"tur":"kidem_x","deger":20}]'::jsonb,7),
  ('bg_egt_staj','egitim','Görev: Üniversite-sanayi stajları','Seçilen ilde 7 gün maaşlar %4 artar; gelişmişlik 1 puan artar.',6,72,true,'{"gelisim":1,"issizlik":-0.05}'::jsonb,'[{"tur":"ucret","deger":4}]'::jsonb,7),

  ('bg_sag_aile','saglik','Görev: Aile hekimliği ağı','Seçilen ilde 7 gün geçim yükü %5 azalır; gelişmişlik 1 puan artar.',6,72,true,'{"gelisim":1,"memnuniyet":0.3}'::jsonb,'[{"tur":"gecim","deger":5}]'::jsonb,7),
  ('bg_sag_ilac','saglik','Görev: Uygun fiyatlı ilaç erişimi','7 gün bütün oyuncuların geçim masrafı %4 azalır.',6,168,false,'{"memnuniyet":0.4}'::jsonb,'[{"tur":"gecim","deger":4}]'::jsonb,7),
  ('bg_sag_psikoloji','saglik','Görev: Psikososyal destek merkezleri','Seçilen ildeki destek merkezleri gelişmişliği 2 puan artırır.',5,72,true,'{"gelisim":2,"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),

  ('bg_san_akilli','sanayi','Görev: Akıllı fabrika dönüşümü','Seçilen ilde 7 gün maaşlar %5 artar; gelişmişlik 2 puan yükselir.',9,72,true,'{"gelisim":2,"buyume":0.05}'::jsonb,'[{"tur":"ucret","deger":5}]'::jsonb,7),
  ('bg_san_kulucka','sanayi','Görev: Teknoloji kuluçka merkezleri','Yenilikçi girişimlerle ülke büyümesi 0,15 puan artar.',6,168,false,'{"buyume":0.15,"issizlik":-0.05}'::jsonb,'[]'::jsonb,null),
  ('bg_san_verim','sanayi','Görev: Sanayide enerji verimliliği','Seçilen ilde enerji dönüşümü gelişmişliği 2 puan artırır.',7,72,true,'{"gelisim":2,"enflasyon":-0.05}'::jsonb,'[]'::jsonb,null),

  ('bg_tic_sikayet','ticaret','Görev: Tüketici şikâyeti denetimi','Piyasa şeffaflığı enflasyonu 0,15 puan azaltır.',3,168,false,'{"enflasyon":-0.15,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
  ('bg_tic_eihracat','ticaret','Görev: E-ihracat eğitimi','Dijital ticaret desteği ülke büyümesini 0,15 puan artırır.',5,168,false,'{"buyume":0.15}'::jsonb,'[]'::jsonb,null),
  ('bg_tic_yerel','ticaret','Görev: Esnaf yerel pazarları','Seçilen ilin pazar altyapısı gelişmişliği 2 puan artırır.',6,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),

  ('bg_tar_sigorta','tarim','Görev: Çiftçi ürün sigortası','Seçilen ilde kırsal üretim güvencesi gelişmişliği 2 puan artırır.',6,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
  ('bg_tar_soguk','tarim','Görev: Soğuk hava deposu','Seçilen ilde ürün kayıpları azalır; gelişmişlik 2 puan yükselir.',7,72,true,'{"gelisim":2,"enflasyon":-0.05}'::jsonb,'[]'::jsonb,null),
  ('bg_tar_asilama','tarim','Görev: Hayvan sağlığı seferberliği','Hayvancılık desteği gıda enflasyonunu 0,15 puan azaltır.',5,168,false,'{"enflasyon":-0.15,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),

  ('bg_ula_liman','ulastirma','Görev: Bölgesel lojistik bağlantısı','Seçilen ilin lojistik altyapısı gelişmişliği 2 puan artırır.',9,72,true,'{"gelisim":2,"buyume":0.05}'::jsonb,'[]'::jsonb,null),
  ('bg_ula_kirsal','ulastirma','Görev: Kırsal yol erişimi','Seçilen ilde yol yatırımı gelişmişliği 2 puan artırır.',6,72,true,'{"gelisim":2,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
  ('bg_ula_bilet','ulastirma','Görev: Ortak ulaşım bilet sistemi','7 gün ülke genelinde taşınma maliyeti %15 azalır.',5,168,false,'{"memnuniyet":0.2}'::jsonb,'[{"tur":"tasinma","deger":15}]'::jsonb,7),

  ('bg_cal_arabulucu','calisma','Görev: İşçi-işveren uzlaşma masası','Çalışma barışı memnuniyeti 0,4 puan artırır.',3,168,false,'{"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
  ('bg_cal_genc','calisma','Görev: Genç istihdam ofisi','Seçilen ilde 7 gün yeni oyuncuların maaşına %8 katkı sağlanır.',6,72,true,'{"gelisim":1,"issizlik":-0.05}'::jsonb,'[{"tur":"ucret_yeni","deger":8}]'::jsonb,7),
  ('bg_cal_denetim','calisma','Görev: Kayıt dışı çalışma denetimi','Denetimler işsizliği 0,1 puan azaltır, memnuniyeti artırır.',4,168,false,'{"issizlik":-0.1,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null)
on conflict (kod) do nothing;
commit;
