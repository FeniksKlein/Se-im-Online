-- 146 (30.10.2026) — MAKAM PROTOKOLÜ, BELEDİYE HİZMETLERİ, SOHBET TEPKİLERİ
-- Yalnız ekler; oyuncu verisini değiştirmez.
-- 1) Resmî program motoru: Cumhurbaşkanı, bakanlar, TBMM Başkanı, milletvekilleri ve belediye başkanları
--    tören, kabul, ziyaret, nişan/belge tevcihi gibi resmî programlar düzenler. Bazılarına oyuncular katılır.
-- 2) Devlet nişanları ve belgeleri: oyuncu kartında görünür.
-- 3) Belediye kataloğu genişler: 6 yeni sürekli hizmet, 9 yeni yatırım.
-- 4) Sohbet tepkileri: kanal ve özel mesajlara emoji tepkisi.

-- ===================== 1) RESMÎ PROGRAM =====================
create table if not exists oyun.resmi_program_tur (
  kod text primary key,
  makam text not null,
  kategori text not null default 'Program',
  ad text not null,
  aciklama text not null default '',
  sira int not null default 0,
  bekleme_saat int not null default 24,
  kaynak text not null default 'yok',          -- yok | hazine | bakanlik | belediye
  maliyet numeric not null default 0,          -- hazine/bakanlık: milyar ₺; belediye: günlük gelirin katı
  il_mod text not null default 'yok',          -- yok | sec | kendi
  hedef boolean not null default false,        -- bir oyuncuya yönelik (kabul / nişan)
  katilim_saat int not null default 0,         -- >0: oyuncular bu süre içinde katılabilir
  etki jsonb not null default '{}'::jsonb,     -- ülke göstergeleri (oyun.etki_uygula)
  il_etki jsonb not null default '{}'::jsonb,  -- il gelişim / memnuniyet
  kidem_yapan numeric not null default 0,
  kidem_hedef numeric not null default 0,
  kidem_katilim numeric not null default 0,
  nisan text,                                  -- doluysa hedefe bu nişan/belge verilir
  secenekler jsonb,                            -- doluysa metin bu listeden seçilir
  metin_ipucu text
);

create table if not exists oyun.resmi_program (
  id bigserial primary key,
  kod text not null references oyun.resmi_program_tur(kod),
  user_id uuid not null,
  makam text not null,
  unvan text,
  bakanlik text,
  il_id smallint,
  hedef uuid,
  metin text,
  zaman timestamptz not null,
  katilim_bit timestamptz,
  katilimci int not null default 0
);
create index if not exists resmi_program_zaman_ix on oyun.resmi_program(zaman desc);
create index if not exists resmi_program_kullanici_ix on oyun.resmi_program(user_id, kod, zaman desc);

create table if not exists oyun.resmi_program_katilim (
  program_id bigint not null references oyun.resmi_program(id),
  user_id uuid not null,
  zaman timestamptz not null,
  odul numeric not null default 0,
  primary key (program_id, user_id)
);
create index if not exists resmi_program_katilim_k_ix on oyun.resmi_program_katilim(user_id, zaman desc);

create table if not exists oyun.devlet_nisan (
  id bigserial primary key,
  user_id uuid not null,
  veren uuid not null,
  program_id bigint,
  ad text not null,
  veren_unvan text,
  gerekce text,
  zaman timestamptz not null
);
create index if not exists devlet_nisan_k_ix on oyun.devlet_nisan(user_id, zaman desc);

alter table oyun.resmi_program_tur enable row level security;
alter table oyun.resmi_program enable row level security;
alter table oyun.resmi_program_katilim enable row level security;
alter table oyun.devlet_nisan enable row level security;

-- Katalog (yalnız ekler/günceller)
insert into oyun.resmi_program_tur(kod,makam,kategori,ad,aciklama,sira,bekleme_saat,kaynak,maliyet,il_mod,hedef,katilim_saat,etki,il_etki,kidem_yapan,kidem_hedef,kidem_katilim,nisan,secenekler,metin_ipucu) values
-- Cumhurbaşkanı
('cb_resepsiyon','cb','Tören','Cumhurbaşkanlığı resepsiyonu','Ülkenin dört bir yanından vatandaşlar davet edilir. 6 saat boyunca herkes katılabilir; katılanlar kıdem kazanır, toplumsal memnuniyet artar.',1,72,'hazine',0.5,'yok',false,6,'{"memnuniyet":0.2}','{}',0.2,0,0.3,null,null,'Resepsiyonun vesilesi (ör. Cumhuriyet Bayramı)'),
('cb_yurt_gezisi','cb','Ziyaret','Yurt gezisi ve halk buluşması','Seçilen ile resmî ziyaret: valilik ve belediye ziyareti, ardından meydanda halk buluşması. İlin gelişimi ve memnuniyeti artar; o ilde yaşayanlar 4 saat içinde buluşmaya katılabilir.',2,24,'hazine',1,'sec',false,4,'{}','{"gelisim":0.8,"memnuniyet":2}',0.2,0,0.3,null,null,'Halka verilecek mesaj'),
('cb_temel_atma','cb','Tören','Toplu açılış ve temel atma töreni','Seçilen ilde tamamlanan kamu yatırımları hizmete açılır, yenilerinin temeli atılır. İlin gelişimi belirgin artar.',3,48,'hazine',3,'sec',false,4,'{}','{"gelisim":1.5,"memnuniyet":1}',0.2,0,0.3,null,null,'Açılan eserler'),
('cb_devlet_konugu','cb','Diplomasi','Devlet konuğu ağırlama','Bir devlet başkanı resmî törenle karşılanır; ikili anlaşmalar imzalanır. Büyüme ve memnuniyete küçük katkı.',4,72,'hazine',0.5,'yok',false,0,'{"buyume":0.1,"memnuniyet":0.1}','{}',0.2,0,0,null,'["Almanya","Azerbaycan","Japonya","Güney Kore","İtalya","Katar","Kazakistan","Brezilya","Kanada","Endonezya","Mısır","Meksika","Birleşik Krallık","Fransa","Malezya"]',null),
('cb_anma','cb','Tören','Anma töreni ve Anıtkabir ziyareti','Devlet erkânıyla resmî anma. 6 saat boyunca herkes törene katılabilir.',5,168,'hazine',0.2,'yok',false,6,'{"memnuniyet":0.2}','{}',0.2,0,0.3,null,null,'Anı defterine yazılacak not'),
('cb_kabul','cb','Kabul','Cumhurbaşkanlığında makam kabulü','Bir oyuncuyu makamında kabul edersin. Kabul edilen kıdem kazanır; görüşme resmî kayda geçer.',6,6,'yok',0,'yok',true,0,'{}','{}',0.2,0.5,0,null,null,'Görüşmenin konusu'),
('cb_nisan','cb','Nişan','Devlet Üstün Hizmet Nişanı','Ülkeye üstün hizmeti geçen oyuncuya devletin en yüksek nişanı. Oyuncu kartında kalıcı olarak görünür.',7,48,'yok',0,'yok',true,0,'{}','{}',0,2,0,'Devlet Üstün Hizmet Nişanı',null,'Nişanın verilme gerekçesi'),
('cb_kultur_odulu','cb','Nişan','Cumhurbaşkanlığı Kültür ve Sanat Büyük Ödülü','Kültür, sanat, basın ya da sivil toplumda iz bırakan oyuncuya. Oyuncu kartında kalıcı olarak görünür.',8,72,'yok',0,'yok',true,0,'{}','{}',0,1.5,0,'Cumhurbaşkanlığı Kültür ve Sanat Büyük Ödülü',null,'Ödülün verilme gerekçesi'),
-- Bakan
('bk_acilis','bakan','Tören','Açılış töreni','Bakanlığın seçilen ildeki tesisini hizmete açarsın. İlin gelişimi ve memnuniyeti artar; o ilde yaşayanlar törene katılabilir.',1,48,'bakanlik',1,'sec',false,4,'{}','{"gelisim":0.6,"memnuniyet":1}',0.2,0,0.3,null,null,'Açılan tesis'),
('bk_calistay','bakan','Program','Ulusal çalıştay','Uzmanlar, sektör ve vatandaşlarla politika çalıştayı. 6 saat boyunca herkes katılabilir.',2,72,'bakanlik',0.5,'yok',false,6,'{"memnuniyet":0.15}','{}',0.2,0,0.3,null,null,'Çalıştayın başlığı'),
('bk_denetim','bakan','Ziyaret','Taşra teşkilatı denetimi','Seçilen ildeki il müdürlüğünü habersiz denetlersin. Hizmet kalitesi ve il memnuniyeti artar.',3,24,'bakanlik',0.3,'sec',false,0,'{}','{"memnuniyet":1.5}',0.2,0,0,null,null,'Denetim notu'),
('bk_istisare','bakan','Program','Sektör temsilcileriyle istişare','Oda, sendika ve sivil toplum temsilcileriyle istişare toplantısı. Ekonomiye küçük katkı; 4 saat katılıma açık.',4,72,'bakanlik',0.2,'yok',false,4,'{"buyume":0.05}','{}',0.2,0,0.25,null,null,'Toplantının gündemi'),
('bk_kabul','bakan','Kabul','Makamında kabul','Bir oyuncuyu bakanlıkta kabul edersin. Kabul edilen kıdem kazanır.',5,6,'yok',0,'yok',true,0,'{}','{}',0.2,0.5,0,null,null,'Görüşmenin konusu'),
('bk_tesekkur','bakan','Nişan','Bakanlık Teşekkür Belgesi','Bakanlığın alanında katkı sunan oyuncuya resmî teşekkür belgesi. Oyuncu kartında görünür.',6,48,'yok',0,'yok',true,0,'{}','{}',0,1,0,'Bakanlık Teşekkür Belgesi',null,'Belgenin gerekçesi'),
-- TBMM Başkanı
('tb_anma','tbmm','Tören','Özel oturum ve anma','Genel Kurul özel oturumla toplanır. 6 saat boyunca herkes izleyici olarak katılabilir.',1,168,'yok',0,'yok',false,6,'{"memnuniyet":0.1}','{}',0.2,0,0.3,null,null,'Oturumun vesilesi'),
('tb_parlamento','tbmm','Diplomasi','Parlamentolar arası resmî ziyaret','Yabancı parlamento heyetini Meclis''te ağırlarsın.',2,72,'yok',0,'yok',false,0,'{"buyume":0.05}','{}',0.2,0,0,null,'["Almanya","Azerbaycan","Japonya","Güney Kore","İtalya","Katar","Kazakistan","Brezilya","Kanada","Endonezya","Mısır","Meksika","Birleşik Krallık","Fransa","Malezya"]',null),
('tb_kabul','tbmm','Kabul','Meclis''te resmî kabul','Bir oyuncuyu TBMM Başkanlığı makamında kabul edersin.',3,6,'yok',0,'yok',true,0,'{}','{}',0.2,0.5,0,null,null,'Görüşmenin konusu'),
('tb_onur','tbmm','Nişan','TBMM Onur Ödülü','Demokrasiye ve Meclis''e katkısı olan oyuncuya. Oyuncu kartında görünür.',4,72,'yok',0,'yok',true,0,'{}','{}',0,1.5,0,'TBMM Onur Ödülü',null,'Ödülün gerekçesi'),
-- Milletvekili
('mv_bolge','mv','Ziyaret','Seçim bölgesinde halk buluşması','Kendi ilinde vatandaşlarla buluşursun. İlin memnuniyeti artar; o ilde yaşayanlar 4 saat içinde katılabilir.',1,24,'yok',0,'kendi',false,4,'{}','{"memnuniyet":0.5}',0.15,0,0.25,null,null,'Buluşmanın konusu'),
('mv_esnaf','mv','Ziyaret','Esnaf, oda ve STK ziyareti','Seçim bölgendeki esnafı ve sivil toplumu ziyaret edersin; talepleri Meclis''e taşırsın.',2,24,'yok',0,'kendi',false,0,'{}','{"memnuniyet":0.4}',0.15,0,0,null,null,'Dinlenen talepler'),
('mv_dostluk','mv','Diplomasi','Parlamentolar arası dostluk grubu','Dostluk grubu heyetiyle resmî görüşme yaparsın.',3,72,'yok',0,'yok',false,0,'{"buyume":0.02}','{}',0.15,0,0,null,'["Almanya","Azerbaycan","Japonya","Güney Kore","İtalya","Katar","Kazakistan","Brezilya","Kanada","Endonezya","Mısır","Meksika","Birleşik Krallık","Fransa","Malezya"]',null),
('mv_tesekkur','mv','Nişan','Milletvekili teşekkür mektubu','Seçim bölgene ya da Meclis''e katkı sunan oyuncuya resmî teşekkür. Oyuncu kartında görünür.',4,48,'yok',0,'yok',true,0,'{}','{}',0,0.5,0,'Milletvekili Teşekkür Mektubu',null,'Mektubun gerekçesi'),
-- Belediye başkanı
('bl_halk_gunu','bel','Program','Halk günü','Belediye başkanlığında kapılar açılır, vatandaş birebir dinlenir. İl memnuniyeti artar; ilde yaşayanlar 4 saat içinde katılabilir.',1,24,'belediye',0.5,'kendi',false,4,'{}','{"memnuniyet":1}',0.15,0,0.25,null,null,'Halk gününün teması'),
('bl_festival','bel','Tören','Kent festivali','Konserler, yöresel lezzetler ve sergilerle üç gün sürecek şehir şenliği. İl memnuniyeti belirgin artar; 6 saat katılıma açık.',2,120,'belediye',3,'kendi',false,6,'{}','{"memnuniyet":2.5}',0.2,0,0.3,null,null,'Festivalin adı'),
('bl_temizlik','bel','Hizmet','Kent temizlik seferberliği','Bütün mahallelerde çöp, moloz ve çevre temizliği. Memnuniyet ve gelişim artar.',3,48,'belediye',1.5,'kendi',false,0,'{}','{"memnuniyet":1.5,"gelisim":0.3}',0.15,0,0,null,null,null),
('bl_kis','bel','Hizmet','Kış hazırlığı ve karla mücadele','Tuzlama, kar küreme ve ısınma merkezleri hazırlanır.',4,96,'belediye',1.2,'kendi',false,0,'{}','{"memnuniyet":1.2}',0.15,0,0,null,null,null),
('bl_kabul','bel','Kabul','Belediye başkanlığında makam kabulü','Bir oyuncuyu makamında kabul edersin. Kabul edilen kıdem kazanır.',5,6,'yok',0,'yok',true,0,'{}','{}',0.15,0.5,0,null,null,'Görüşmenin konusu'),
('bl_fahri','bel','Nişan','Fahrî hemşehrilik beratı','Şehre katkı sunan oyuncuya fahrî hemşehrilik. Oyuncu kartında görünür.',6,72,'yok',0,'yok',true,0,'{}','{}',0,0.8,0,'Fahrî Hemşehrilik Beratı',null,'Beratın gerekçesi'),
('bl_anahtar','bel','Nişan','Şehrin anahtarı','Şehrin verebileceği en yüksek onur. Oyuncu kartında görünür.',7,168,'yok',0,'yok',true,0,'{}','{}',0,1.5,0,'Şehrin Anahtarı',null,'Gerekçe')
on conflict (kod) do update set makam=excluded.makam,kategori=excluded.kategori,ad=excluded.ad,aciklama=excluded.aciklama,sira=excluded.sira,
  bekleme_saat=excluded.bekleme_saat,kaynak=excluded.kaynak,maliyet=excluded.maliyet,il_mod=excluded.il_mod,hedef=excluded.hedef,
  katilim_saat=excluded.katilim_saat,etki=excluded.etki,il_etki=excluded.il_etki,kidem_yapan=excluded.kidem_yapan,kidem_hedef=excluded.kidem_hedef,
  kidem_katilim=excluded.kidem_katilim,nisan=excluded.nisan,secenekler=excluded.secenekler,metin_ipucu=excluded.metin_ipucu;

-- Oyuncunun program düzenleyebildiği makamlar
create or replace function oyun.rp_makamlar(u uuid)
returns table(makam text, il_id smallint, bakanlik text, unvan text)
language sql stable security definer set search_path = '' as $$
  select case m.tur when 'cb' then 'cb' when 'bakan' then 'bakan' when 'tbmm' then 'tbmm' when 'mv' then 'mv' when 'bel' then 'bel' end,
         m.il_id, m.bakanlik,
         case m.tur when 'cb' then 'Cumhurbaşkanı'
                    when 'bakan' then (select replace(b.ad,'Bakanlığı','Bakanı') from oyun.bakanliklar b where b.kod=m.bakanlik)
                    when 'tbmm' then 'TBMM Başkanı'
                    when 'mv' then (select i.ad||' Milletvekili' from oyun.iller i where i.id=m.il_id)
                    when 'bel' then (select i.ad||' Belediye Başkanı' from oyun.iller i where i.id=m.il_id) end
  from oyun.makamlar m
  where m.user_id = u and m.bit is null and m.tur in ('cb','bakan','tbmm','mv','bel')
$$;

create or replace function oyun.rp_maliyet(r oyun.resmi_program_tur, p_il smallint)
returns numeric language sql stable security definer set search_path = '' as $$
  select case r.kaynak
    when 'belediye' then round(r.maliyet * oyun.il_gunluk_gelir((select mv from oyun.iller where id = p_il)) * (select endeks from oyun.ulke where id = 1), 3)
    when 'yok' then 0 else r.maliyet end
$$;

create or replace function oyun.rp_json(x oyun.resmi_program, u uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', x.id, 'kod', x.kod, 'ad', t.ad, 'kategori', t.kategori, 'makam', x.makam, 'unvan', x.unvan,
    'kad', oyun.kad(x.user_id), 'parti', (select oyun.parti_json(p.parti_id) from oyun.profiller p where p.id = x.user_id),
    'il', (select ad from oyun.iller where id = x.il_id), 'il_id', x.il_id, 'hedef', oyun.kad(x.hedef), 'metin', x.metin,
    'zaman', x.zaman, 'katilim_bit', x.katilim_bit, 'katilimci', x.katilimci, 'nisan', t.nisan,
    'acik', x.katilim_bit is not null and x.katilim_bit > oyun.simdi(),
    'katildim', exists(select 1 from oyun.resmi_program_katilim k where k.program_id = x.id and k.user_id = u),
    'benim', x.user_id = u)
  from oyun.resmi_program_tur t where t.kod = x.kod
$$;

create or replace function public.resmi_program_panel()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'makamlar', coalesce((select jsonb_agg(jsonb_build_object('makam', r.makam, 'unvan', r.unvan, 'il_id', r.il_id,
        'il', (select ad from oyun.iller where id = r.il_id), 'bakanlik', r.bakanlik,
        'kasa', case r.makam when 'cb' then (select round(hazine,1) from oyun.ulke where id=1)
                             when 'bakan' then (select round(kasa,1) from oyun.bakanlik_kasa where kod = r.bakanlik)
                             when 'bel' then (select round(kasa,3) from oyun.il_durum where il_id = r.il_id) end,
        'programlar', (select coalesce(jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', k.ad, 'kategori', k.kategori, 'aciklama', k.aciklama,
            'kaynak', k.kaynak, 'maliyet', oyun.rp_maliyet(k, r.il_id), 'il_mod', k.il_mod, 'hedef', k.hedef, 'katilim_saat', k.katilim_saat,
            'etki', k.etki, 'il_etki', k.il_etki, 'kidem_hedef', k.kidem_hedef, 'kidem_katilim', k.kidem_katilim, 'nisan', k.nisan,
            'secenekler', k.secenekler, 'metin_ipucu', k.metin_ipucu, 'bekleme_saat', k.bekleme_saat,
            'hazir', (select max(x.zaman) + make_interval(hours => k.bekleme_saat) from oyun.resmi_program x where x.user_id = p.id and x.kod = k.kod))
            order by k.sira), '[]'::jsonb) from oyun.resmi_program_tur k where k.makam = r.makam)) order by array_position(array['cb','tbmm','bakan','bel','mv'], r.makam))
      from oyun.rp_makamlar(p.id) r), '[]'::jsonb),
    'acik', coalesce((select jsonb_agg(oyun.rp_json(x, p.id) order by x.katilim_bit) from oyun.resmi_program x
      where x.katilim_bit > t and (x.il_id is null or x.il_id = p.il_id)), '[]'::jsonb),
    'akis', coalesce((select jsonb_agg(oyun.rp_json(x, p.id) order by x.zaman desc) from
      (select * from oyun.resmi_program order by zaman desc limit 30) x), '[]'::jsonb),
    'nisanlarim', public.oyuncu_nisanlari(p.kad)
  );
end $$;

create or replace function public.resmi_program_yap(p_kod text, p_il integer default null, p_hedef text default null, p_metin text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.resmi_program_tur; r record;
        il smallint; ilad text; h oyun.profiller; son timestamptz; mal numeric; v_kasa numeric; mt text; pid bigint; n int;
        bas text; ozet text;
begin
  select * into k from oyun.resmi_program_tur where kod = p_kod;
  if k.kod is null then raise exception 'Program bulunamadı.'; end if;
  select * into r from oyun.rp_makamlar(p.id) x where x.makam = k.makam limit 1;
  if r.makam is null then raise exception 'Bu programı yalnızca ilgili makam sahibi düzenleyebilir.'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('resmi_program'), pg_catalog.hashtext(p.id::text || k.kod));
  select max(zaman) into son from oyun.resmi_program where user_id = p.id and kod = k.kod;
  if son is not null and son + make_interval(hours => k.bekleme_saat) > t then
    raise exception 'Bu program % tarihinden sonra yeniden düzenlenebilir.', to_char((son + make_interval(hours => k.bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  -- il
  if k.il_mod = 'sec' then
    select id, ad into il, ilad from oyun.iller where id = p_il;
    if il is null then raise exception 'Bir il seçmelisin.'; end if;
  elsif k.il_mod = 'kendi' then
    il := r.il_id; select ad into ilad from oyun.iller where id = il;
  end if;
  -- hedef oyuncu
  if k.hedef then
    if coalesce(btrim(p_hedef), '') = '' then raise exception 'Bir oyuncu seçmelisin.'; end if;
    h := oyun.profil_bul(p_hedef);
    if h.id is null or h.yasakli then raise exception 'Oyuncu bulunamadı.'; end if;
    if h.id = p.id then raise exception 'Kendine bu programı düzenleyemezsin.'; end if;
    if k.nisan is not null and exists(select 1 from oyun.devlet_nisan where user_id = h.id and ad = k.nisan and zaman > t - interval '30 days') then
      raise exception '% bu oyuncuya son 30 gün içinde zaten verildi.', k.nisan;
    end if;
    if k.nisan is null and exists(select 1 from oyun.resmi_program where kod = k.kod and hedef = h.id and zaman > t - interval '3 days') then
      raise exception 'Bu oyuncu son 3 gün içinde zaten kabul edildi.';
    end if;
  end if;
  -- metin
  if k.secenekler is not null then
    if p_metin is null or not (k.secenekler ? p_metin) then raise exception 'Listeden bir seçim yapmalısın.'; end if;
    mt := p_metin;
  elsif coalesce(btrim(p_metin), '') <> '' then
    mt := regexp_replace(oyun.metin_temizle(p_metin, 280), '\s+', ' ', 'g');
  end if;
  if k.nisan is not null and coalesce(char_length(mt), 0) < 5 then raise exception 'Gerekçe en az 5 karakter olmalı.'; end if;
  -- bütçe
  mal := oyun.rp_maliyet(k, coalesce(il, r.il_id));
  if k.kaynak = 'hazine' and mal > 0 then
    select hazine into v_kasa from oyun.ulke where id = 1 for update;
    if v_kasa < mal then raise exception 'Hazinede yeterli kaynak yok (% milyar ₺ gerekli).', mal; end if;
    update oyun.ulke set hazine = hazine - mal where id = 1;
  elsif k.kaynak = 'bakanlik' and mal > 0 then
    select k2.kasa into v_kasa from oyun.bakanlik_kasa k2 where k2.kod = r.bakanlik for update;
    if coalesce(v_kasa, 0) < mal then raise exception 'Bakanlık kasasında yeterli ödenek yok (% milyar ₺ gerekli).', mal; end if;
    update oyun.bakanlik_kasa set kasa = kasa - mal where kod = r.bakanlik;
  elsif k.kaynak = 'belediye' and mal > 0 then
    select d.kasa into v_kasa from oyun.il_durum d where d.il_id = r.il_id for update;
    if coalesce(v_kasa, 0) < mal then raise exception 'Belediye kasasında yeterli para yok (% milyar ₺ gerekli).', mal; end if;
    update oyun.il_durum set kasa = kasa - mal where il_id = r.il_id;
  end if;
  -- etkiler
  if k.etki <> '{}'::jsonb then perform oyun.etki_uygula(k.etki, il); end if;
  if il is not null and k.il_etki <> '{}'::jsonb then
    update oyun.il_durum set
      gelisim = oyun.sinir(gelisim + coalesce((k.il_etki->>'gelisim')::numeric, 0), 0, 100),
      memnuniyet = oyun.sinir(memnuniyet + coalesce((k.il_etki->>'memnuniyet')::numeric, 0), 0, 100)
    where il_id = il;
  end if;
  insert into oyun.resmi_program(kod, user_id, makam, unvan, bakanlik, il_id, hedef, metin, zaman, katilim_bit)
  values (k.kod, p.id, k.makam, r.unvan, r.bakanlik, il, h.id, mt, t,
          case when k.katilim_saat > 0 then t + make_interval(hours => k.katilim_saat) end)
  returning id into pid;
  if k.kidem_yapan > 0 then perform oyun.kidem_ekle(p.id, k.kidem_yapan); end if;
  bas := r.unvan || ' ' || p.kad;
  if h.id is not null then
    if k.kidem_hedef > 0 then perform oyun.kidem_ekle(h.id, k.kidem_hedef); end if;
    if k.nisan is not null then
      insert into oyun.devlet_nisan(user_id, veren, program_id, ad, veren_unvan, gerekce, zaman) values (h.id, p.id, pid, k.nisan, r.unvan, mt, t);
      perform oyun.bildir(h.id, format('%s sana "%s" verdi. Gerekçe: %s Oyuncu kartında görünecek; kıdemin +%s.', bas, k.nisan, mt, k.kidem_hedef), t);
      ozet := format('%s, %s adlı oyuncuya %s verdi.', bas, h.kad, k.nisan);
    else
      perform oyun.bildir(h.id, format('%s seni makamında kabul etti.%s Kıdemin +%s.', bas, coalesce(' Görüşme: ' || mt || '.', ''), k.kidem_hedef), t);
      ozet := format('%s, %s adlı oyuncuyu makamında kabul etti%s.', bas, h.kad, coalesce(' (' || mt || ')', ''));
    end if;
  else
    ozet := format('%s: %s%s%s.', bas, k.ad, coalesce(' — ' || ilad, ''), coalesce(' · ' || mt, ''));
  end if;
  if il is not null and k.katilim_saat > 0 then
    insert into oyun.bildirimler(user_id, zaman, metin)
      select x.id, t, format('%s ilimizde: %s. %s saat içinde Devlet › Protokol ekranından katılabilirsin.', bas, k.ad, k.katilim_saat)
      from oyun.profiller x where x.il_id = il and x.id <> p.id and not x.yasakli;
    get diagnostics n = row_count;
  end if;
  perform oyun.olay('makam', ozet, il, p.parti_id, t);
  if k.nisan is not null or k.katilim_saat > 0 or k.kategori = 'Diplomasi' then
    perform oyun.gazete_ekle('duyuru', k.ad || coalesce(' — ' || ilad, '') || coalesce(' — ' || h.kad, ''), ozet || coalesce(' ' || k.aciklama, ''), null, t);
  end if;
  return public.resmi_program_panel();
end $$;

create or replace function public.resmi_program_katil(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); x oyun.resmi_program; k oyun.resmi_program_tur; bugun int; v_odul numeric := 0;
begin
  select * into x from oyun.resmi_program where id = p_id for update;
  if x.id is null then raise exception 'Program bulunamadı.'; end if;
  if x.katilim_bit is null or x.katilim_bit <= t then raise exception 'Bu programa katılım süresi doldu.'; end if;
  if x.user_id = p.id then raise exception 'Kendi düzenlediğin programa ev sahibisin.'; end if;
  if x.il_id is not null and x.il_id is distinct from p.il_id then raise exception 'Bu programa yalnızca o ilde yaşayanlar katılabilir.'; end if;
  if exists(select 1 from oyun.resmi_program_katilim where program_id = x.id and user_id = p.id) then raise exception 'Bu programa zaten katıldın.'; end if;
  select * into k from oyun.resmi_program_tur where kod = x.kod;
  select count(*) into bugun from oyun.resmi_program_katilim
   where user_id = p.id and resmi_program_katilim.odul > 0 and zaman >= (date_trunc('day', t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul');
  if bugun < 3 and p.olusturma < t - interval '1 day' then v_odul := k.kidem_katilim; end if;
  insert into oyun.resmi_program_katilim(program_id, user_id, zaman, odul) values (x.id, p.id, t, v_odul);
  update oyun.resmi_program set katilimci = katilimci + 1 where id = x.id;
  if v_odul > 0 then perform oyun.kidem_ekle(p.id, v_odul); end if;
  return public.resmi_program_panel();
end $$;

create or replace function public.oyuncu_nisanlari(p_kad text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('ad', n.ad, 'veren', oyun.kad(n.veren), 'veren_unvan', n.veren_unvan, 'gerekce', n.gerekce, 'zaman', n.zaman) order by n.zaman desc), '[]'::jsonb)
  from oyun.devlet_nisan n join oyun.profiller pr on pr.id = n.user_id
  where lower(pr.kad) = lower(btrim(coalesce(p_kad, '')))
$$;

create or replace function public.resmi_programlar(p_limit integer default 30)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(oyun.rp_json(x, auth.uid()) order by x.zaman desc), '[]'::jsonb)
  from (select * from oyun.resmi_program order by zaman desc limit least(greatest(coalesce(p_limit, 30), 1), 100)) x
$$;

revoke all on function oyun.rp_makamlar(uuid) from public, anon, authenticated;
revoke all on function oyun.rp_maliyet(oyun.resmi_program_tur, smallint) from public, anon, authenticated;
revoke all on function oyun.rp_json(oyun.resmi_program, uuid) from public, anon, authenticated;
revoke all on function public.resmi_program_panel() from public, anon;
revoke all on function public.resmi_program_yap(text, integer, text, text) from public, anon;
revoke all on function public.resmi_program_katil(bigint) from public, anon;
revoke all on function public.oyuncu_nisanlari(text) from public, anon;
revoke all on function public.resmi_programlar(integer) from public, anon;
grant execute on function public.resmi_program_panel() to authenticated;
grant execute on function public.resmi_program_yap(text, integer, text, text) to authenticated;
grant execute on function public.resmi_program_katil(bigint) to authenticated;
grant execute on function public.oyuncu_nisanlari(text) to authenticated;
grant execute on function public.resmi_programlar(integer) to authenticated;

-- ===================== 3) BELEDİYE KATALOĞU =====================
insert into oyun.belediye_hizmetleri(kod, ad, aciklama, oran, etki, sira) values
('kres','Belediye kreşleri','Çalışan ebeveynlere ücretsiz kreş: ildeki maaşlar %5 artar, geçim masrafı %4 düşer.',0.10,'[{"tur":"ucret","deger":5},{"tur":"gecim","deger":4}]',5),
('halk_ekmek','Halk ekmek büfeleri','Uygun fiyatlı ekmek ve temel gıda: geçim masrafı %6 düşer.',0.06,'[{"tur":"gecim","deger":6}]',6),
('saglik_evi','Semt sağlık evleri','Ücretsiz muayene, evde bakım ve yaşlı desteği: geçim masrafı %7 düşer.',0.09,'[{"tur":"gecim","deger":7}]',7),
('genclik','Gençlik ve meslek merkezleri','Kurslar, atölyeler ve kariyer danışmanlığı: yeni oyuncuların maaşları %15 artar.',0.08,'[{"tur":"ucret_yeni","deger":15}]',8),
('wifi','Ücretsiz kent interneti','Meydan, park ve duraklarda ücretsiz internet: ildeki maaşlar %3 artar.',0.05,'[{"tur":"ucret","deger":3}]',9),
('su_indirim','Su ve doğalgaz tarifesinde indirim','Belediye tarifelerinde sosyal indirim: geçim masrafı %8 düşer.',0.11,'[{"tur":"gecim","deger":8}]',10)
on conflict (kod) do update set ad=excluded.ad, aciklama=excluded.aciklama, oran=excluded.oran, etki=excluded.etki, sira=excluded.sira;

insert into oyun.belediye_yatirimlari(kod, ad, aciklama, gun, bekleme_saat, gelisim, memnuniyet, sira, tur) values
('park','Millet bahçesi ve parklar','Yeşil alan, çocuk oyun alanı ve yürüyüş yolları.',6,120,2,3,5,'yatirim'),
('bisiklet','Bisiklet yolları ve yaya bölgeleri','Güvenli bisiklet ağı ve yayalaştırılmış çarşı.',5,96,2,2,6,'yatirim'),
('kavsak','Akıllı kavşak ve trafik yönetimi','Sinyalizasyon, kamera ve trafik merkezi.',6,120,2,2,7,'yatirim'),
('afet','Afet toplanma alanları ve AKOM','Afet koordinasyon merkezi, toplanma alanları ve tatbikat.',7,168,2,2,8,'yatirim'),
('spor','Spor kompleksi ve yüzme havuzu','Kapalı spor salonu, olimpik havuz ve mahalle sahaları.',8,168,3,2,9,'yatirim'),
('kultur_merkezi','Kültür merkezi ve kent kütüphanesi','Tiyatro salonu, sergi alanı ve 7/24 kütüphane.',9,168,3,2,10,'yatirim'),
('aritma','Atık su arıtma ve geri dönüşüm tesisi','Çevre ve halk sağlığı için arıtma ile sıfır atık tesisi.',12,240,5,1,11,'yatirim'),
('ges','Güneş enerjisi santrali (GES)','Belediye binalarının elektriğini güneşten karşılayan santral.',14,240,4,1,12,'yatirim'),
('kentsel_donusum','Kentsel dönüşüm ve depreme dayanıklı konut','Riskli yapıların yenilenmesi; şehrin geleceğine en büyük yatırım.',24,336,9,2,13,'yatirim')
on conflict (kod) do update set ad=excluded.ad, aciklama=excluded.aciklama, gun=excluded.gun, bekleme_saat=excluded.bekleme_saat,
  gelisim=excluded.gelisim, memnuniyet=excluded.memnuniyet, sira=excluded.sira, tur=excluded.tur;

-- ===================== 4) SOHBET TEPKİLERİ =====================
create table if not exists oyun.mesaj_tepki (
  tur text not null check (tur in ('kanal','ozel')),
  mesaj_id bigint not null,
  user_id uuid not null,
  emoji text not null,
  zaman timestamptz not null,
  primary key (tur, mesaj_id, user_id)
);
create index if not exists mesaj_tepki_mesaj_ix on oyun.mesaj_tepki(tur, mesaj_id);
alter table oyun.mesaj_tepki enable row level security;

create or replace function oyun.tepki_erisim(p oyun.profiller, p_kanal text, p_mesaj bigint)
returns text language plpgsql stable security definer set search_path = '' as $$
declare k text;
begin
  if p_kanal is null or p_kanal = 'ozel' then
    if exists(select 1 from oyun.ozel o where o.id = p_mesaj and not o.gizli and (o.gonderen = p.id or o.alici = p.id)) then return 'ozel'; end if;
    raise exception 'Mesaj bulunamadı.';
  end if;
  k := oyun.kanal_coz(p, p_kanal);
  if k is null or not exists(select 1 from oyun.mesajlar m where m.id = p_mesaj and m.kanal = k and not m.gizli) then raise exception 'Mesaj bulunamadı.'; end if;
  return 'kanal';
end $$;

create or replace function public.mesaj_tepki_ver(p_kanal text, p_mesaj bigint, p_emoji text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); tr text; eski text;
begin
  if p_emoji is null or not (p_emoji = any(array['👍','❤️','😂','👏','🔥','🇹🇷','🤝','😮','😢','📌'])) then raise exception 'Bu tepki kullanılamaz.'; end if;
  tr := oyun.tepki_erisim(p, p_kanal, p_mesaj);
  select emoji into eski from oyun.mesaj_tepki where tur = tr and mesaj_id = p_mesaj and user_id = p.id;
  if eski = p_emoji then
    delete from oyun.mesaj_tepki where tur = tr and mesaj_id = p_mesaj and user_id = p.id;
  else
    insert into oyun.mesaj_tepki(tur, mesaj_id, user_id, emoji, zaman) values (tr, p_mesaj, p.id, p_emoji, oyun.simdi())
    on conflict (tur, mesaj_id, user_id) do update set emoji = excluded.emoji, zaman = excluded.zaman;
  end if;
  return public.mesaj_tepkileri(p_kanal, array[p_mesaj]);
end $$;

create or replace function public.mesaj_tepkileri(p_kanal text, p_idler bigint[])
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); tr text; k text; ids bigint[];
begin
  if p_idler is null or cardinality(p_idler) = 0 then return '{}'::jsonb; end if;
  ids := p_idler[1:150];
  if p_kanal is null or p_kanal = 'ozel' then
    tr := 'ozel';
    select array_agg(o.id) into ids from oyun.ozel o where o.id = any(ids) and (o.gonderen = p.id or o.alici = p.id);
  else
    tr := 'kanal'; k := oyun.kanal_coz(p, p_kanal);
    if k is null then return '{}'::jsonb; end if;
    select array_agg(m.id) into ids from oyun.mesajlar m where m.id = any(ids) and m.kanal = k;
  end if;
  if ids is null then return '{}'::jsonb; end if;
  return coalesce((select jsonb_object_agg(z.mesaj_id::text, z.j) from (
    select y.mesaj_id, jsonb_build_object('say', jsonb_object_agg(y.emoji, y.n), 'ben', max(y.ben)) j from (
      select t.mesaj_id, t.emoji, count(*) n, max(case when t.user_id = p.id then t.emoji end) ben
      from oyun.mesaj_tepki t where t.tur = tr and t.mesaj_id = any(ids) group by t.mesaj_id, t.emoji) y
    group by y.mesaj_id) z), '{}'::jsonb);
end $$;

revoke all on function oyun.tepki_erisim(oyun.profiller, text, bigint) from public, anon, authenticated;
revoke all on function public.mesaj_tepki_ver(text, bigint, text) from public, anon;
revoke all on function public.mesaj_tepkileri(text, bigint[]) from public, anon;
grant execute on function public.mesaj_tepki_ver(text, bigint, text) to authenticated;
grant execute on function public.mesaj_tepkileri(text, bigint[]) to authenticated;
