-- Seyrek, güvenli ülke krizleri. Eski oyuncu verisine dokunmaz.
create table if not exists oyun.kriz_ayar (
 id boolean primary key default true check (id),
 aktif boolean not null default true,
 min_aralik_gun integer not null default 14 check (min_aralik_gun between 14 and 90),
 haftalik_ihtimal integer not null default 50 check (haftalik_ihtimal between 0 and 50),
 son_kriz timestamptz not null default now()
);
insert into oyun.kriz_ayar(id) values(true) on conflict(id) do nothing;
create table if not exists oyun.kriz_sablon (
 kod text primary key,
 kategori text not null,
 baslik text not null,
 aciklama text not null,
 bakanlik text not null,
 sektor text not null,
 secenekler jsonb not null
);
create table if not exists oyun.kriz_olay (
 id bigint generated always as identity primary key,
 sablon_kod text not null references oyun.kriz_sablon(kod),
 bas timestamptz not null default now(),
 karar_son timestamptz not null,
 bit timestamptz,
 durum text not null default 'bekliyor' check(durum in ('bekliyor','cozuldu','suresi_doldu')),
 secenek text,
 karar_veren uuid,
 maliyet numeric not null default 0,
 sektor_carpan numeric not null default 1,
 etki_bas timestamptz,
 etki_bit timestamptz
);
create unique index if not exists kriz_tek_aktif on oyun.kriz_olay(durum) where durum='bekliyor';
create index if not exists kriz_sektor_etki_idx on oyun.kriz_olay(etki_bas,etki_bit) where etki_bit is not null;
create table if not exists oyun.kriz_kayit (
 id bigint generated always as identity primary key,
 kriz_id bigint not null references oyun.kriz_olay(id),
 user_id uuid,
 tip text not null,
 aciklama text not null,
 tutar numeric not null default 0,
 zaman timestamptz not null default now()
);
create index if not exists kriz_kayit_kriz_idx on oyun.kriz_kayit(kriz_id,zaman);
alter table oyun.kriz_ayar enable row level security;
alter table oyun.kriz_sablon enable row level security;
alter table oyun.kriz_olay enable row level security;
alter table oyun.kriz_kayit enable row level security;
revoke all on oyun.kriz_ayar,oyun.kriz_sablon,oyun.kriz_olay,oyun.kriz_kayit from PUBLIC,anon,authenticated;

insert into oyun.kriz_sablon(kod,kategori,baslik,aciklama,bakanlik,sektor,secenekler) values
('elektrik','Enerji','Ulusal elektrik arzı krizi','Elektrik arzında geçici daralma yaşanıyor. Sanayi ve ticaret işletmeleri etkilenebilir.','sanayi','sanayi','[{"kod":"ithalat","ad":"Yurt dışından elektrik satın al","butce_payi":0.04,"sektor_carpan":1.015},{"kod":"yerli","ad":"Yerli üretim ve altyapı desteği sağla","butce_payi":0.025,"sektor_carpan":1.01},{"kod":"tasarruf","ad":"Planlı tasarruf uygulaması başlat","butce_payi":0,"sektor_carpan":0.99}]'::jsonb),
('doviz','Ekonomi','Döviz piyasasında ani dalgalanma','Dış ticaret şirketleri kur dalgalanması nedeniyle yeni maliyetlerle karşılaşıyor.','maliye','ticaret','[{"kod":"rezerv","ad":"Sınırlı piyasa istikrar desteği","butce_payi":0.02,"sektor_carpan":1.01},{"kod":"ticaret","ad":"İhracat finansmanını destekle","butce_payi":0.03,"sektor_carpan":1.015},{"kod":"izle","ad":"Müdahale etmeden piyasayı izle","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('banka','Finans','Bankacılık sektöründe likidite sıkışıklığı','Finansal piyasalarda nakit erişimi geçici olarak zorlaşıyor.','maliye','ticaret','[{"kod":"destek","ad":"Koşullu likidite destek programı","butce_payi":0.03,"sektor_carpan":1.01},{"kod":"denetim","ad":"Acil banka denetimi ve yapılandırma","butce_payi":0.012,"sektor_carpan":1.005},{"kod":"izle","ad":"Mevcut önlemleri izle","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('enflasyon','Ekonomi','Beklenmedik fiyat artışları','Tedarik maliyetleri yükseliyor; ticaret şirketlerinde baskı oluşuyor.','maliye','ticaret','[{"kod":"tedarik","ad":"Temel ürün tedarikini destekle","butce_payi":0.025,"sektor_carpan":1.01},{"kod":"destek","ad":"Hedefli geçici ekonomik destek","butce_payi":0.03,"sektor_carpan":1.012},{"kod":"bekle","ad":"Fiyatları izle ve raporla","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('yakit','Enerji','Akaryakıt tedarik daralması','Taşıma ve sanayi maliyetlerinde geçici baskı yaşanıyor.','ulastirma','ticaret','[{"kod":"ithalat","ad":"Acil yakıt tedariki","butce_payi":0.035,"sektor_carpan":1.012},{"kod":"rota","ad":"Alternatif lojistik rotaları","butce_payi":0.018,"sektor_carpan":1.009},{"kod":"tasarruf","ad":"Yakıt tasarruf tedbirleri","butce_payi":0,"sektor_carpan":0.992}]'::jsonb),
('vergi','Bütçe','Vergi tahsilatında gerileme','Devlet gelirleri beklenen seviyenin altında kaldı.','maliye','ticaret','[{"kod":"tasarruf","ad":"Kamu harcama tasarrufu","butce_payi":0,"sektor_carpan":1.002},{"kod":"canlandir","ad":"Ticareti canlandırma teşviki","butce_payi":0.028,"sektor_carpan":1.013},{"kod":"incele","ad":"Bütçe izleme komisyonu","butce_payi":0.005,"sektor_carpan":1.004}]'::jsonb),
('issizlik','İstihdam','Geçici işsizlik artışı','İstihdam fırsatlarının azalması çalışma piyasasını etkiliyor.','calisma','sanayi','[{"kod":"tesvik","ad":"Yeni işe alım teşviki","butce_payi":0.035,"sektor_carpan":1.017},{"kod":"egitim","ad":"İşbaşı eğitim programı","butce_payi":0.018,"sektor_carpan":1.01},{"kod":"bekle","ad":"İşgücü piyasasını izle","butce_payi":0,"sektor_carpan":0.997}]'::jsonb),
('iflas','Ekonomi','Büyük işletmede mali sıkıntı','Sanayi sektöründe ödeme güçlüğü yaşayan işletmeler var.','sanayi','sanayi','[{"kod":"yeniden","ad":"Yeniden yapılandırma programı","butce_payi":0.02,"sektor_carpan":1.009},{"kod":"finansman","ad":"Teminatlı işletme desteği","butce_payi":0.03,"sektor_carpan":1.014},{"kod":"serbest","ad":"Piyasa çözümünü bekle","butce_payi":0,"sektor_carpan":0.994}]'::jsonb),
('borc','Bütçe','Kamu borcu ödeme baskısı','Borç servis giderleri hazineyi zorlamaya başladı.','maliye','ticaret','[{"kod":"plan","ad":"Borç ödeme takvimi oluştur","butce_payi":0.005,"sektor_carpan":1.004},{"kod":"denge","ad":"Harcamalarda geçici disiplin","butce_payi":0,"sektor_carpan":1.005},{"kod":"izle","ad":"Mali gelişmeleri izle","butce_payi":0,"sektor_carpan":0.997}]'::jsonb),
('sel','Afet','Bölgesel sel ve altyapı hasarı','Bazı yerleşim yerlerinde yollar ve altyapı zarar gördü.','icisleri','insaat','[{"kod":"onarim","ad":"Acil altyapı onarım programı","butce_payi":0.035,"sektor_carpan":1.018},{"kod":"ekip","ad":"Yerel müdahale ekiplerine destek","butce_payi":0.02,"sektor_carpan":1.012},{"kod":"izle","ad":"Hasar tespit sürecini yürüt","butce_payi":0,"sektor_carpan":0.992}]'::jsonb),
('yangin','Afet','Orman yangınlarıyla mücadele','Bazı orman bölgelerinde acil müdahale gerekiyor.','tarim','tarim','[{"kod":"ekip","ad":"Müdahale ekibi ve ekipman desteği","butce_payi":0.035,"sektor_carpan":1.014},{"kod":"koordinasyon","ad":"İller arası koordinasyon sağla","butce_payi":0.018,"sektor_carpan":1.008},{"kod":"izle","ad":"Mevcut ekiplerle devam et","butce_payi":0,"sektor_carpan":0.993}]'::jsonb),
('deprem','Afet','Deprem sonrası altyapı ihtiyacı','Bir bölgede kamu altyapısında onarım ihtiyacı oluştu.','icisleri','insaat','[{"kod":"onarim","ad":"Denetimli onarım yatırımı","butce_payi":0.04,"sektor_carpan":1.018},{"kod":"barinma","ad":"Geçici barınma ve lojistik","butce_payi":0.028,"sektor_carpan":1.012},{"kod":"tespit","ad":"Hasar tespitine öncelik ver","butce_payi":0,"sektor_carpan":0.992}]'::jsonb),
('kuraklik','Tarım','Kuraklık ve su rezervi baskısı','Tarım üretimi ve su kaynakları üzerinde riskler oluşuyor.','tarim','tarim','[{"kod":"sulama","ad":"Verimli sulama yatırımı","butce_payi":0.03,"sektor_carpan":1.018},{"kod":"destek","ad":"Üreticiye sınırlı girdi desteği","butce_payi":0.025,"sektor_carpan":1.012},{"kod":"tasarruf","ad":"Su tasarrufu tedbirleri","butce_payi":0,"sektor_carpan":0.994}]'::jsonb),
('su','Altyapı','Şehirlerde su şebekesi arızası','Bölgesel su hizmetlerinde teknik aksama yaşanıyor.','ulastirma','insaat','[{"kod":"onarim","ad":"Hızlı şebeke onarım programı","butce_payi":0.027,"sektor_carpan":1.014},{"kod":"yedek","ad":"Alternatif tedarik ağı","butce_payi":0.018,"sektor_carpan":1.009},{"kod":"bekle","ad":"Planlı bakım takvimi","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('ulasim','İstihdam','Toplu taşımada iş bırakma','Ulaşım çalışanlarıyla ücret görüşmeleri çıkmaza girdi.','calisma','ticaret','[{"kod":"uzlasi","ad":"Arabuluculuk ve uzlaşma desteği","butce_payi":0.008,"sektor_carpan":1.012},{"kod":"destek","ad":"Geçici ulaşım hizmet desteği","butce_payi":0.024,"sektor_carpan":1.009},{"kod":"izle","ad":"Görüşmelerin sonucunu bekle","butce_payi":0,"sektor_carpan":0.994}]'::jsonb),
('konut','Konut','Konut arzında daralma','Bazı bölgelerde kiralar ve konut talepleri yükseliyor.','sanayi','insaat','[{"kod":"konut","ad":"Sosyal konut teşvik programı","butce_payi":0.035,"sektor_carpan":1.018},{"kod":"altyapi","ad":"Yeni yerleşim altyapısı desteği","butce_payi":0.025,"sektor_carpan":1.01},{"kod":"izle","ad":"Piyasayı izleme programı","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('hastane','Sağlık','Hastanelerde kapasite baskısı','Sağlık hizmeti talebi geçici olarak artıyor.','saglik','ticaret','[{"kod":"personel","ad":"Ek hizmet kapasitesi finansmanı","butce_payi":0.032,"sektor_carpan":1.012},{"kod":"ortak","ad":"Özel hizmet sağlayıcılarla anlaşma","butce_payi":0.024,"sektor_carpan":1.009},{"kod":"izle","ad":"Sevk ve planlama sistemi","butce_payi":0,"sektor_carpan":0.997}]'::jsonb),
('ilac','Sağlık','İlaç tedarikinde gecikme','Tıbbi ürünlerin tedarik zincirinde aksama var.','saglik','ticaret','[{"kod":"ithalat","ad":"Alternatif ilaç tedariki","butce_payi":0.03,"sektor_carpan":1.015},{"kod":"stok","ad":"Stok ve dağıtım koordinasyonu","butce_payi":0.016,"sektor_carpan":1.01},{"kod":"bekle","ad":"Mevcut stokları planlı kullan","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('ogretmen','Eğitim','Eğitimde personel açığı','Bazı şehirlerde eğitim hizmeti kapasitesi azaldı.','egitim','teknoloji','[{"kod":"atama","ad":"Geçici personel ve eğitim desteği","butce_payi":0.032,"sektor_carpan":1.014},{"kod":"uzaktan","ad":"Uzaktan eğitim altyapısı","butce_payi":0.018,"sektor_carpan":1.012},{"kod":"izle","ad":"Kadro ihtiyacını raporla","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('sinav','Eğitim','Eğitim sınav sisteminde aksama','Sınav kayıt ve organizasyonlarında gecikme oluştu.','egitim','teknoloji','[{"kod":"telafi","ad":"Ek sınav düzenle","butce_payi":0.018,"sektor_carpan":1.012},{"kod":"altyapi","ad":"Sınav altyapısını güçlendir","butce_payi":0.022,"sektor_carpan":1.015},{"kod":"erteleyerek","ad":"Yeni takvim yayımla","butce_payi":0,"sektor_carpan":0.996}]'::jsonb),
('siber','Teknoloji','Kamu dijital sistemlerinde kesinti','Bazı kamu işlemleri yavaşladı; veri bütünlüğü öncelikli.','sanayi','teknoloji','[{"kod":"guvenlik","ad":"Acil siber güvenlik çalışması","butce_payi":0.03,"sektor_carpan":1.018},{"kod":"yedek","ad":"Güvenli yedek hizmetleri devreye al","butce_payi":0.018,"sektor_carpan":1.011},{"kod":"bekle","ad":"Sistemleri kontrollü izle","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('transfer','Finans','Bankalar arası ödeme gecikmesi','Bankalar arası işlemlerde geçici teknik gecikmeler var.','maliye','ticaret','[{"kod":"altyapi","ad":"Ödeme altyapısı onarımı","butce_payi":0.018,"sektor_carpan":1.012},{"kod":"koord","ad":"Bankalar arası acil koordinasyon","butce_payi":0.006,"sektor_carpan":1.008},{"kod":"izle","ad":"Transferleri sıraya al","butce_payi":0,"sektor_carpan":0.996}]'::jsonb),
('secim','Seçim','Seçim sonuç ekranlarında gecikme','Seçim sonuçlarının kamuya aktarılması yavaşladı.','icisleri','teknoloji','[{"kod":"yedek","ad":"Güvenli yedek bildirim altyapısı","butce_payi":0.018,"sektor_carpan":1.01},{"kod":"kontrol","ad":"Bağımsız teknik doğrulama","butce_payi":0.009,"sektor_carpan":1.006},{"kod":"bekle","ad":"Sonuçları doğrulanana kadar beklet","butce_payi":0,"sektor_carpan":0.999}]'::jsonb),
('don','Tarım','Tarımsal don nedeniyle ürün kaybı','Soğuk hava tarım üretim kapasitesini etkiliyor.','tarim','tarim','[{"kod":"destek","ad":"Üretici yeniden ekim desteği","butce_payi":0.03,"sektor_carpan":1.015},{"kod":"sera","ad":"Koruyucu sera yatırımı","butce_payi":0.028,"sektor_carpan":1.018},{"kod":"izle","ad":"Ürün hasarlarını raporla","butce_payi":0,"sektor_carpan":0.992}]'::jsonb),
('hastalik','Tarım','Tarımsal üretimde hastalık riski','Bitki ve hayvan üretim zincirinde önleyici tedbir gerekiyor.','tarim','tarim','[{"kod":"denetim","ad":"Koruyucu denetim ve analiz","butce_payi":0.018,"sektor_carpan":1.013},{"kod":"tedavi","ad":"Üretici biyogüvenlik desteği","butce_payi":0.03,"sektor_carpan":1.017},{"kod":"bekle","ad":"Mevcut kontrolleri sürdür","butce_payi":0,"sektor_carpan":0.995}]'::jsonb),
('gida','Ticaret','Temel gıda tedarik daralması','Bazı temel ürünlerde tedarik süreleri uzuyor.','ticaret','ticaret','[{"kod":"ithalat","ad":"Sınırlı acil tedarik","butce_payi":0.035,"sektor_carpan":1.015},{"kod":"uretim","ad":"Yerli tedarikçi teşviki","butce_payi":0.024,"sektor_carpan":1.013},{"kod":"izle","ad":"Fiyat ve stok raporlaması","butce_payi":0,"sektor_carpan":0.993}]'::jsonb),
('liman','Lojistik','Limanlarda ticari yoğunluk','Liman kapasitesi yetersizliği tedarik gecikmesine yol açıyor.','ulastirma','ticaret','[{"kod":"rota","ad":"Alternatif liman rotaları","butce_payi":0.02,"sektor_carpan":1.013},{"kod":"yatirim","ad":"Liman işleme kapasitesi artırımı","butce_payi":0.035,"sektor_carpan":1.018},{"kod":"izle","ad":"Tedariki önceliklendir","butce_payi":0,"sektor_carpan":0.996}]'::jsonb),
('turizm','Turizm','Turizm rezervasyonlarında gerileme','Turizm bölgelerindeki işletmeler talep kaybı yaşıyor.','ticaret','ticaret','[{"kod":"tanitim","ad":"Turizm tanıtım desteği","butce_payi":0.025,"sektor_carpan":1.015},{"kod":"destek","ad":"Küçük işletme destek programı","butce_payi":0.029,"sektor_carpan":1.012},{"kod":"izle","ad":"Piyasa araştırması yürüt","butce_payi":0,"sektor_carpan":0.994}]'::jsonb),
('ihracat','Ticaret','İhracat siparişlerinde düşüş','Yurt dışı siparişlerindeki azalma sanayiyi etkiliyor.','ticaret','sanayi','[{"kod":"pazar","ad":"Yeni ihracat pazarı teşviki","butce_payi":0.025,"sektor_carpan":1.016},{"kod":"finans","ad":"İhracat finansmanı desteği","butce_payi":0.031,"sektor_carpan":1.013},{"kod":"izle","ad":"Dış ticaret raporlaması","butce_payi":0,"sektor_carpan":0.994}]'::jsonb),
('cevre','Çevre','Sanayi bölgesinde kirlilik bildirimi','Sanayi faaliyetlerinde çevresel uyum denetimi gerekiyor.','sanayi','sanayi','[{"kod":"aritim","ad":"Arıtma altyapı desteği","butce_payi":0.032,"sektor_carpan":1.015},{"kod":"denetim","ad":"Bağımsız çevresel denetim","butce_payi":0.012,"sektor_carpan":1.007},{"kod":"izle","ad":"Ölçüm ve raporlama","butce_payi":0,"sektor_carpan":0.995}]'::jsonb)

on conflict(kod) do update set
 kategori=excluded.kategori,baslik=excluded.baslik,aciklama=excluded.aciklama,
 bakanlik=excluded.bakanlik,sektor=excluded.sektor,secenekler=excluded.secenekler;

-- Kararlar yalnız bakan ve yürütme tarafından verilebilir. Yetkisiz kullanıcı hiçbir zaman tablo yazamaz.
create or replace function public.kriz_merkezi() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kriz_ayar; aktif jsonb;
begin
 select * into a from oyun.kriz_ayar where id=true;
 select jsonb_build_object('id',k.id,'bas',k.bas,'karar_son',k.karar_son,
  'baslik',s.baslik,'aciklama',s.aciklama,'kategori',s.kategori,'bakanlik',s.bakanlik,
  'sektor',s.sektor,'secenekler',s.secenekler,
  'karar_verebilirim', (p.id=oyun.yurutme_user() or exists(
   select 1 from oyun.makamlar m where m.user_id=p.id and m.tur='bakan'
   and m.bakanlik=s.bakanlik and m.bit is null)))
 into aktif from oyun.kriz_olay k join oyun.kriz_sablon s on s.kod=k.sablon_kod
 where k.durum='bekliyor' order by k.id desc limit 1;
 return jsonb_build_object(
  'aktif',aktif,
  'ayar',jsonb_build_object('aktif',a.aktif,'min_aralik_gun',a.min_aralik_gun,
   'haftalik_ihtimal',a.haftalik_ihtimal,'son_kriz',a.son_kriz),
  'yonetici',coalesce(p.yonetici,false),
  'arsiv',coalesce((select jsonb_agg(x) from
    (select k.id,s.baslik,s.kategori,k.durum,k.bas,k.bit,k.maliyet,
     k.secenek,k.sektor_carpan
     from oyun.kriz_olay k join oyun.kriz_sablon s on s.kod=k.sablon_kod
     where k.durum<>'bekliyor' order by k.id desc limit 12) x),'[]'::jsonb),
  'katalog',coalesce((select jsonb_agg(jsonb_build_object('kod',kod,'baslik',baslik,'kategori',kategori)
    order by baslik) from oyun.kriz_sablon),'[]'::jsonb)
 );
end $$;

create or replace function public.kriz_karar_ver(p_kriz bigint, p_secenek text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); k oyun.kriz_olay;
 s oyun.kriz_sablon; sec jsonb; o jsonb; maliyet numeric; h numeric;
 carpan numeric; b timestamptz := now();
begin
 select * into k from oyun.kriz_olay where id=p_kriz for update;
 if k.id is null or k.durum<>'bekliyor' then raise exception 'Aktif kriz bulunamadı.'; end if;
 if b > k.karar_son then raise exception 'Karar süresi doldu.'; end if;
 select * into s from oyun.kriz_sablon where kod=k.sablon_kod;
 if p.id is distinct from oyun.yurutme_user() and not exists
   (select 1 from oyun.makamlar m where m.user_id=p.id and m.tur='bakan'
    and m.bakanlik=s.bakanlik and m.bit is null)
 then raise exception 'Bu kriz için bakan veya cumhurbaşkanı yetkisi gerekir.'; end if;
 select value into sec from jsonb_array_elements(s.secenekler) value
 where value->>'kod'=p_secenek limit 1;
 if sec is null then raise exception 'Geçersiz karar seçeneği.'; end if;
 select hazine into h from oyun.ulke where id=1 for update;
 maliyet:=round(least(greatest(coalesce(h,0),0)*least(0.05,greatest(0,(sec->>'butce_payi')::numeric)),50000),2);
 carpan:=least(1.02,greatest(0.98,(sec->>'sektor_carpan')::numeric));
 update oyun.ulke set hazine=hazine-maliyet where id=1;
 update oyun.kriz_olay set
 durum='cozuldu',secenek=p_secenek,karar_veren=p.id,maliyet=maliyet,
 sektor_carpan=carpan,bit=b,etki_bas=b,etki_bit=b+interval '7 days'
 where id=k.id;
 insert into oyun.kriz_kayit(kriz_id,user_id,tip,aciklama,tutar)
 values(k.id,p.id,'karar',sec->>'ad',maliyet);
 insert into oyun.olaylar(tur,metin,zaman) values('ulke_krizi',
  format('Kriz kararı: %s — %s. Hazine maliyeti %s TL.',
  s.baslik,sec->>'ad',maliyet),b);
 return jsonb_build_object('tamam',true,'baslik',s.baslik,'karar',sec->>'ad',
  'maliyet',maliyet,'sektor',s.sektor,'sektor_carpan',carpan);
end $$;

-- Kullanıcılar geçmiş mali haklarını kaybetmez. Yalnız ilgili sektörün haftalık
-- gelir bileşenine en fazla +/- %2 ve yalnız zaman penceresi içerisinde etki eder.
create or replace function oyun.kriz_sektor_carpani(p_sektor text, p_tarih timestamptz)
returns numeric language sql stable set search_path = '' as $$
 select coalesce((select k.sektor_carpan from oyun.kriz_olay k
 join oyun.kriz_sablon s on s.kod=k.sablon_kod
 where s.sektor=p_sektor and k.etki_bas<=p_tarih and k.etki_bit>p_tarih
 and k.durum<>'bekliyor' order by k.id desc limit 1),1)::numeric
$$;
revoke all on function oyun.kriz_sektor_carpani(text,timestamptz) from PUBLIC,anon,authenticated;

-- Yalnız haftalık faaliyet hesabına, geçmiş dönemleri etkilemeyecek küçük oran.
do $modify$
declare v_sql text;
begin
 select pg_get_functiondef('oyun.sirket_hesapla(bigint)'::regprocedure) into v_sql;
 if v_sql is null then raise exception 'Mevcut şirket hesabı bulunamadı'; end if;
 if position('oyun.kriz_sektor_carpani' in v_sql)=0 then
  if position('net:=income-cost;' in v_sql)=0 then
    raise exception 'Şirket hesaplama sürümü değişmiş; entegrasyon kontrolü gerekli.';
  end if;
  v_sql:=replace(v_sql,'net:=income-cost;',
  'income:=round(income * oyun.kriz_sektor_carpani(s.sektor,s.sonraki_kazanc + (i-1) * interval ''7 days''),2); net:=income-cost;');
  execute v_sql;
 end if;
end $modify$;

-- Yönetici yalnızca seyrek olay ayarlarını değiştirebilir.
create or replace function public.kriz_ayar_degistir(p_aktif boolean, p_ihtimal integer default 50)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
 if not coalesce(p.yonetici,false) then raise exception 'Yalnız yönetici değiştirebilir.'; end if;
 if p_ihtimal < 0 or p_ihtimal > 50 then raise exception 'Haftalık ihtimal 0 ile 50 arasında olmalı.'; end if;
 update oyun.kriz_ayar set aktif=p_aktif,haftalik_ihtimal=p_ihtimal where id=true;
 return jsonb_build_object('aktif',p_aktif,'haftalik_ihtimal',p_ihtimal);
end $$;

-- Saatlik görev süresi dolan olayları sessizce kapatır;
-- haftalık çekiliş olmadan hiçbir yeni kriz oluşturmaz.
create or replace function oyun.kriz_tick(p_cekilis boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare a oyun.kriz_ayar; k record; s oyun.kriz_sablon;
begin
 select * into a from oyun.kriz_ayar where id=true for update;
 if not found then return; end if;
 for k in
   select o.id, t.baslik from oyun.kriz_olay o
   join oyun.kriz_sablon t on t.kod=o.sablon_kod
   where o.durum='bekliyor' and o.karar_son<now() for update of o
 loop
   update oyun.kriz_olay set durum='suresi_doldu',bit=now(),
    sektor_carpan=0.995,etki_bas=now(),etki_bit=now()+interval '3 days'
   where id=k.id;
   insert into oyun.kriz_kayit(kriz_id,tip,aciklama)
   values(k.id,'otomatik','Karar süresi doldu; kriz güvenli geçici planla kapatıldı.');
 end loop;
 if not p_cekilis or not a.aktif then return; end if;
 if a.son_kriz+make_interval(days=>a.min_aralik_gun)>now() then return; end if;
 if exists(select 1 from oyun.kriz_olay where durum='bekliyor') then return; end if;
 if random()*100>=a.haftalik_ihtimal then return; end if;
 select * into s from oyun.kriz_sablon order by random() limit 1;
 if s.kod is null then return; end if;
 insert into oyun.kriz_olay(sablon_kod,karar_son) values(s.kod,now()+interval '4 hours');
 update oyun.kriz_ayar set son_kriz=now() where id=true;
 insert into oyun.olaylar(tur,metin,zaman) values('ulke_krizi',
   format('Ülke Kriz Merkezi: %s. Yetkili makam: %s. Karar süresi 4 saat.',s.baslik,
   (select ad from oyun.bakanliklar where kod=s.bakanlik)),now());
end $$;
revoke all on function oyun.kriz_tick(boolean) from PUBLIC,anon,authenticated;

revoke all on function public.kriz_merkezi() from PUBLIC,anon;
revoke all on function public.kriz_karar_ver(bigint,text) from PUBLIC,anon;
revoke all on function public.kriz_ayar_degistir(boolean,integer) from PUBLIC,anon;
grant execute on function public.kriz_merkezi() to authenticated;
grant execute on function public.kriz_karar_ver(bigint,text) to authenticated;
grant execute on function public.kriz_ayar_degistir(boolean,integer) to authenticated;

-- Haftalık cumartesi 18:00 Türkiye saati (15:00 UTC) çekiliş;
-- her saat sadece bitiş kontrolü. Mevcut cron işlerine dokunulmaz.
select cron.schedule('ulke_krizi_haftalik_20261010','0 15 * * 6','select oyun.kriz_tick(true)');
select cron.schedule('ulke_krizi_sure_20261010','0 * * * *','select oyun.kriz_tick(false)');
