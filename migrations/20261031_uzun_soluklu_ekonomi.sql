-- 151 (31.10.2026) — UZUN SOLUKLU EKONOMİ: FİYAT MERDİVENİ, STATÜ KİLİTLERİ, GETİRİ DENGESİ, EKİP PARTİSİ
-- İstek (Ercan): oyun aylarca/yıllarca oynanacak. Ne oyuncu başlar başlamaz zengin olsun ne de uzun sürede hedeflere
-- ulaşamayıp sıkılsın; daha aktif olan daha hızlı ilerlesin. Parti kurmak ekip işi olsun, yüzlerce parti olmasın.
--
-- Ölçülen sorun (30.10.2026 canlı veri, 21 günlük oyun):
--   • Pazar şirketleri haftada sermayenin ortalama %11'ini kazanıyordu (7 haftada ikiye katlanma).
--   • Oto galeri (NPC perakende) haftada %160-225 getiri: iki şirket haftada 4 milyon ₺ üretiyordu.
--   • Enerji şirketleri herkesin elektrik faturasını topluyordu (B2B): haftada %46.
--   • Konut kirası bedelin 1/13'ü: haftada %7,7 (13 haftada kendini ödüyor).
--   • Aynı kişi 3-4 makamın maaşını birden alıyordu (bakan + belediye + vekil).
--   • 25.000 ₺ ve 3 onayla parti kuruluyordu: 50 oyuncuya 11 parti.
--
-- Tasarım: her şey tek tarifeden (oyun.tarife) okunur, yönetici değerleri SQL ile ayarlayabilir.
--   • Statü (kıdem) kilitleri: şirket kurmak "Vatandaş", ajans "Saygın Vatandaş", banka "Kanaat Önderi" ister.
--     Kıdem her gün maaşı toplamak, oy kullanmak ve etkinliklerle artar → aktif oyuncu 3-4 kat hızlı açar.
--   • Şirket hakkı statüyle büyür: 0 / 1 / 2 / 3 / 5 / 8. Mevcut şirketler korunur, yalnız yeni kuruluş sınırlanır.
--   • Getiriler: pazar şirketi ~%7/hafta (iyi yönetilen %13), perakende günlük brüt kâr tavanı, B2B tavanı,
--     kira %2/hafta, ikinci ve sonraki makam maaşı %25.
--   • Parti: kurucular kurulu en az 7 kişi (aktif oyuncunun %2'si, en çok 30), 500.000 ₺ harç + 1.000.000 ₺
--     kuruluş fonu (fon partinin kasasına geçer, kurucular birlikte toplar, parti kurulmazsa iade edilir).
-- Oyuncu verisini dönüştürmez: mevcut şirket, mülk, kira, parti ve paralar aynen kalır.

-- =====================================================================
-- A) TARİFE ve YARDIMCILAR
-- =====================================================================
create table if not exists oyun.tarife (
  kod text primary key,
  deger numeric not null,
  birim text not null default 'tl',      -- tl: sabit ₺ · tl_endeks: fiyat düzeyiyle artan ₺ · oran: % · adet · gun · statu
  kategori text not null,
  ad text not null,
  aciklama text,
  sira int not null default 100,
  guncelleme timestamptz not null default now());
alter table oyun.tarife enable row level security;
revoke all on oyun.tarife from public, anon, authenticated;

-- Değerler yalnız ilk kurulumda yazılır; sonradan yöneticinin ayarladığı değer korunur (etiketler güncellenir).
insert into oyun.tarife(kod, deger, birim, kategori, ad, aciklama, sira) values
  ('kilit_aktif',            1,        'adet',      'kural',   'Statü kilitleri ve şirket hakkı', '1 açık, 0 kapalı', 1),
  ('sirket_statu',           1,        'statu',     'kilit',   'Şirket kurmak', null, 10),
  ('ajans_statu',            2,        'statu',     'kilit',   'Reklam ve anket ajansı kurmak', null, 11),
  ('banka_statu',            3,        'statu',     'kilit',   'Banka kurmak', null, 12),
  ('gazete_statu',           1,        'statu',     'kilit',   'Gazete kurmak', null, 13),
  ('dernek_statu',           1,        'statu',     'kilit',   'Dernek kurmak', null, 14),
  ('parti_kurucu_statu',     2,        'statu',     'kilit',   'Parti kurma başvurusu yapmak', null, 15),
  ('parti_ortak_statu',      1,        'statu',     'kilit',   'Kurucular kurulunda yer almak', null, 16),
  ('slot_0',                 0,        'adet',      'tavan',   'Yeni Gelen · şirket hakkı', null, 20),
  ('slot_1',                 1,        'adet',      'tavan',   'Vatandaş · şirket hakkı', null, 21),
  ('slot_2',                 2,        'adet',      'tavan',   'Saygın Vatandaş · şirket hakkı', null, 22),
  ('slot_3',                 3,        'adet',      'tavan',   'Kanaat Önderi · şirket hakkı', null, 23),
  ('slot_4',                 5,        'adet',      'tavan',   'Duayen · şirket hakkı', null, 24),
  ('slot_5',                 8,        'adet',      'tavan',   'Yaşayan Efsane · şirket hakkı', null, 25),
  ('banka_min',              15000000, 'tl',        'kurulus', 'Banka kuruluş sermayesi', null, 30),
  ('ajans_min',              400000,   'tl',        'kurulus', 'Reklam ve anket ajansı sermayesi', null, 31),
  ('meslek_min',             200000,   'tl',        'kurulus', 'Döviz bürosu / kuyumcu sermayesi', null, 32),
  ('dernek_harc',            50000,    'tl_endeks', 'kurulus', 'Dernek kuruluş harcı', null, 33),
  ('dernek_sube',            5000,     'tl_endeks', 'kurulus', 'Dernek şubesi (il büyüklüğüne göre 1-3 kat)', null, 34),
  ('parti_fon',              1000000,  'tl_endeks', 'parti',   'Parti kuruluş fonu (partinin kasasına geçer)', null, 40),
  ('parti_kurucu_min',       7,        'adet',      'parti',   'Kurucular kurulu en az (başvuran dahil)', null, 41),
  ('parti_kurucu_oran',      2,        'oran',      'parti',   'Kurucular kurulu: son 14 günün aktif oyuncularının yüzdesi', null, 42),
  ('parti_kurucu_max',       30,       'adet',      'parti',   'Kurucular kurulu en çok (Siyasi Partiler Kanunu: 30)', null, 43),
  ('parti_kurucu_hesap_gun', 14,       'gun',       'parti',   'Başvuranın hesap yaşı', null, 44),
  ('parti_ortak_hesap_gun',  7,        'gun',       'parti',   'Kurucu üyenin hesap yaşı', null, 45),
  ('parti_ortak_bekleme_gun',30,       'gun',       'parti',   'Bir partinin kurucusu olduktan sonra yeniden kurucu olmak için bekleme', null, 46),
  ('parti_basvuru_gun',      10,       'gun',       'parti',   'Kuruluş başvurusunun süresi', null, 47),
  ('parti_katki_min',        10000,    'tl',        'parti',   'Kuruluş fonuna en küçük katkı', null, 48),
  ('aday_mv',                15000,    'tl_endeks', 'siyaset', 'Milletvekili aday adaylığı', null, 50),
  ('aday_bel',               10000,    'tl_endeks', 'siyaset', 'Belediye başkanı aday adaylığı (il büyüklüğüne göre 1-3 kat)', null, 51),
  ('aday_kurultay',          50000,    'tl_endeks', 'siyaset', 'Genel başkanlık adaylığı', null, 52),
  ('aday_cb',                150000,   'tl_endeks', 'siyaset', 'Cumhurbaşkanı aday adaylığı', null, 53),
  ('miting',                 5000,     'tl_endeks', 'siyaset', 'Miting (il büyüklüğüne göre 1-3 kat)', null, 54),
  ('tasinma',                20000,    'tl_endeks', 'siyaset', 'Taşınma (devlet taşınma desteği düşülmeden)', null, 55),
  ('kira_verim',             2,        'oran',      'getiri',  'Konut ve dükkân haftalık kira verimi (il taban bedelinin %)', null, 60),
  ('b2b_tavan',              1.2,      'oran',      'getiri',  'Şirketler arası satış (fatura) geliri tavanı: sermayenin günlük %', null, 61),
  ('npc_marj_tavan',         2.5,      'oran',      'getiri',  'Perakende mağaza günlük brüt kâr tavanı: sermayenin %', null, 62),
  ('makam_ek_oran',          25,       'oran',      'gelir',   'İkinci ve sonraki makam için ödenen maaş oranı', null, 70)
on conflict (kod) do update set birim = excluded.birim, kategori = excluded.kategori, ad = excluded.ad,
  aciklama = excluded.aciklama, sira = excluded.sira;

create or replace function oyun.tf(p_kod text) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce((select t.deger from oyun.tarife t where t.kod = p_kod), 0)
$$;

-- Fiyat düzeyiyle (endeks) güncellenen ₺ tutarı, 100'e yuvarlı
create or replace function oyun.tf_tl(p_kod text) returns numeric
language sql stable security definer set search_path = '' as $$
  select round(oyun.tf(p_kod) * coalesce((select u.endeks from oyun.ulke u where u.id = 1), 1) / 100) * 100
$$;

create or replace function oyun.statum(u uuid) returns int
language sql stable set search_path = '' as $$
  select oyun.statu_basamak(oyun.kidem_puani(u))
$$;

create or replace function oyun.statu_kontrol(u uuid, p_kod text, p_is text) returns void
language plpgsql stable set search_path = '' as $$
declare gerek int; b int; k numeric;
begin
  if oyun.tf('kilit_aktif') <> 1 then return; end if;
  gerek := oyun.tf(p_kod)::int; k := oyun.kidem_puani(u); b := oyun.statu_basamak(k);
  if b < gerek then
    raise exception '% için en az "%" statüsü gerekiyor (% kıdem). Şu an "%" statüsündesin (% kıdem). Kıdem; her gün maaşını topladıkça, oy kullandıkça ve etkinliklere katıldıkça artar.',
      p_is, oyun.statu_ad(gerek), oyun.statu_esik(gerek), oyun.statu_ad(b), floor(k);
  end if;
end $$;

-- Şirket hakkı: statüye göre aynı anda sahibi olunabilecek şirket sayısı (en büyük ortak sayılır)
create or replace function oyun.sirket_hakki(u uuid) returns jsonb
language sql stable set search_path = '' as $$
  with b as (select oyun.statum(u) b)
  select jsonb_build_object('statu', b.b, 'hak', oyun.tf('slot_' || b.b)::int,
    'kullanilan', (select count(*) from oyun.sirketler s where s.aktif and coalesce(oyun.sirket_sahibi(s.id), s.kurucu) = u),
    'sonraki_ad', case when b.b < 5 then oyun.statu_ad(b.b + 1) end,
    'sonraki_hak', case when b.b < 5 then oyun.tf('slot_' || (b.b + 1))::int end,
    'sonraki_esik', case when b.b < 5 then oyun.statu_esik(b.b + 1) end)
  from b
$$;

-- Ayarlar tablosundaki fiyatlar (bir kez): başlangıç parası, parti harcı, teşkilat, gazete, parti bekleme süresi
do $$ begin
  insert into oyun.tek_seferlik(anahtar) values ('tarife_151_ayarlar') on conflict do nothing;
  if not found then return; end if;
  update oyun.ayarlar set baslangic_para = 150000, parti_kur_ucret = 500000, teskilat_ucret = 10000,
         gazete_kur_ucret = 150000, parti_kur_gun = 90 where id = 1;
end $$;

-- Pazar şirketleri: kapasite ×0,8, sabit gider +0,5 puan, sektöre göre kuruluş sermayesi (mutlak değerler; tekrar çalışınca aynı)
update oyun.pazar_sektor p set
  kapasite = coalesce(v.kap, p.kapasite), sabit = coalesce(v.sab, p.sabit), min_sermaye = v.mins
from (values
  ('danismanlik',  0.176::numeric, 0.035::numeric,  200000::numeric),
  ('oto_servis',   0.208, 0.045,  200000),
  ('tarim',        0.208, 0.050,  200000),
  ('ticaret',      0.224, 0.045,  200000),
  ('teknoloji',    0.208, 0.045,  200000),
  ('sanayi',       0.208, 0.055,  200000),
  ('insaat',       0.200, 0.055,  200000),
  ('medya',        0.208, 0.050,  200000),
  ('market',       0.240, 0.045,  500000),
  ('ulasim',       0.200, 0.055,  500000),
  ('lojistik',     0.224, 0.048,  500000),
  ('e_ticaret',    0.224, 0.050,  500000),
  ('geri_donusum', 0.216, 0.050,  500000),
  ('turizm',       0.216, 0.050,  500000),
  ('ozel_okul',    0.200, 0.050,  500000),
  ('ozel_hastane', 0.200, 0.055, 1000000),
  ('enerji',       0.240, 0.055, 1500000),
  ('tekstil_magaza',    null, null,  500000),
  ('yapi_market',       null, null,  500000),
  ('elektronik_magaza', null, null,  500000),
  ('mobilya_magaza',    null, null,  500000),
  ('akaryakit',         null, null, 1000000),
  ('oto_galeri',        null, null, 2500000)
) v(kod, kap, sab, mins) where p.kod = v.kod;

-- Perakende: zayıf kalan ürünlere gerçekçi talep (günlük brüt kâr tavanı aşırı kazancı keser)
update oyun.npc_urun_katalog n set gunluk_talep = v.t
from (values ('benzin', 900), ('motorin', 1100), ('lpg', 500), ('yapi', 60), ('elektronik', 15), ('giyim', 120), ('mobilya', 20)) v(kod, t)
where n.kod = v.kod;

-- Görev ödülleri ×2 (bir kez): aktif oyuncunun keşif ödülü anlamlı olsun (izin aralığı genişler: 50–10.000)
alter table oyun.gorev_katalog drop constraint if exists gorev_katalog_odul_check;
alter table oyun.gorev_katalog add constraint gorev_katalog_odul_check check (odul >= 50 and odul <= 10000);
do $$ begin
  insert into oyun.tek_seferlik(anahtar) values ('gorev_odul_x2_151') on conflict do nothing;
  if not found then return; end if;
  update oyun.gorev_katalog set odul = round(odul * 2 / 50) * 50 where odul > 0;
end $$;

-- =====================================================================
-- B) GETİRİ DENGESİ
-- =====================================================================
-- Kira: il taban bedelinin haftalık %2'si (eski: 1/13 ≈ %7,7). Yalnız yeni alımlar; eski mülklerin kirası aynen.
create or replace function oyun.mulk_il_kira(p_il smallint, p_tip text) returns numeric
language sql stable set search_path = '' as $$
  select round(oyun.mulk_il_bedel(p_il, p_tip) * oyun.tf('kira_verim') / 100 * (0.85 + oyun.mulk_il_gelismislik(p_il) / 333.0), -1)
$$;

-- Şirketler arası fatura (elektrik, lojistik, reklam): alan şirket günde en çok sermayesinin %1,2'sini toplar
create index if not exists eko_b2b_satici_gun_ix on oyun.eko_b2b(satici, gun);
create or replace function oyun.b2b_ode(p_alici bigint, p_sektor text, p_tutar numeric, p_il smallint, p_kalem text, p_gun date)
 returns numeric language plpgsql security definer set search_path to '' as $function$
declare toplam_w numeric; oyuncu_pay numeric; x record; dagit numeric := 0; parca numeric;
        tavan_oran numeric := oyun.tf('b2b_tavan'); alinan numeric;
begin
  if coalesce(p_tutar, 0) <= 0 then return 0; end if;
  select coalesce(sum(w), 0) into toplam_w from (
    select (1 + 0.35 * p.kalite + p.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p.fiyat), 1.5)
           * case when p.il_id = p_il then 3 else 1 end w
    from oyun.pazar_sirket p join oyun.sirketler s on s.id = p.sirket_id
    where s.sektor = p_sektor and s.aktif and s.id <> p_alici) q;
  if toplam_w <= 0 then
    insert into oyun.eko_b2b(gun, alici, satici, kalem, tutar, islendi) values (p_gun, p_alici, null, p_kalem, round(p_tutar), true);
    return 0;
  end if;
  oyuncu_pay := p_tutar * toplam_w / (toplam_w + 4);
  for x in select s.id, s.sermaye, (1 + 0.35 * p.kalite + p.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p.fiyat), 1.5)
           * case when p.il_id = p_il then 3 else 1 end w
    from oyun.pazar_sirket p join oyun.sirketler s on s.id = p.sirket_id
    where s.sektor = p_sektor and s.aktif and s.id <> p_alici
  loop
    parca := round(oyuncu_pay * x.w / toplam_w);
    if tavan_oran > 0 and parca > 0 then
      select coalesce(sum(e.tutar), 0) into alinan from oyun.eko_b2b e where e.satici = x.id and e.gun = p_gun;
      parca := least(parca, greatest(0, round(coalesce(x.sermaye, 0) * tavan_oran / 100) - alinan));
    end if;
    if parca > 0 then
      update oyun.sirketler set kasa = kasa + parca where id = x.id;
      insert into oyun.eko_b2b(gun, alici, satici, kalem, tutar) values (p_gun, p_alici, x.id, p_kalem, parca);
      dagit := dagit + parca;
    end if;
  end loop;
  if p_tutar - dagit > 0 then
    insert into oyun.eko_b2b(gun, alici, satici, kalem, tutar, islendi) values (p_gun, p_alici, null, p_kalem, round(p_tutar - dagit), true);
  end if;
  return dagit;
end $function$;

-- Perakende (NPC mağaza): günlük brüt kâr sermayenin %2,5'ini aşamaz; kalan talep ildeki rakiplere kalır
create table if not exists oyun.npc_marj_gun (sirket_id bigint not null, gun date not null, marj numeric not null default 0, primary key (sirket_id, gun));
alter table oyun.npc_marj_gun enable row level security;
revoke all on oyun.npc_marj_gun from public, anon, authenticated;

create or replace function oyun.npc_isletme_tick()
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare s record; st record; z record;
 t timestamptz:=now(); v_gun date:=(now() at time zone 'Europe/Istanbul')::date;
 v_lim integer; v_satilan integer; v_adet integer; v_rakip integer;
 v_gelir numeric; v_maliyet numeric; v_kdv numeric; v_kurum numeric; v_diger numeric; v_bakim numeric;
 v_kar numeric; v_satis_id bigint; v_n integer:=0; v_ciro numeric:=0;
 v_tlm numeric:=oyun.pazar_tl_milyar(); v_oran numeric:=oyun.eko_vergi_oran('kdv');
 v_kv numeric:=oyun.eko_vergi_oran('kurumlar');
 v_tavan_oran numeric:=oyun.tf('npc_marj_tavan'); v_tavan numeric; v_marj numeric; v_birim numeric;
begin
 if not oyun.uzaktan_modul_acik('npc_isletme') then return jsonb_build_object('durdu',true); end if;
 if not pg_try_advisory_xact_lock(444722,7) then return jsonb_build_object('kilitli',true); end if;
 for s in
 select c.id,c.ad,c.kasa,c.sermaye,c.sektor,p.il_id,d.gelisim,
       oyun.pazar_il_agirlik(p.il_id) as sehir_carpani
 from oyun.sirketler c join oyun.pazar_sirket p on p.sirket_id=c.id
 join oyun.il_durum d on d.il_id=p.il_id
 where c.aktif and exists(select 1 from oyun.npc_urun_katalog n where n.sektor=c.sektor)
 order by c.id limit 400
 loop
  perform pg_advisory_xact_lock(98763,hashtext(s.id::text));
  perform 1 from oyun.sirketler where id=s.id for update;
  insert into oyun.npc_son_saat(sirket_id,son_saat) values(s.id,t) on conflict do nothing;
  update oyun.npc_son_saat set son_saat=t
  where sirket_id=s.id and son_saat<=t-interval '15 minutes';
  if not found then continue; end if;
  -- Saatlik enerji, personel ve bakım: stok bitse de ödenir.
  v_bakim:=least(greatest(0,(select kasa from oyun.sirketler where id=s.id)),
    round((10+s.sermaye*0.00008)/4,2));
  if v_bakim>0 then
   update oyun.sirketler set kasa=kasa-v_bakim where id=s.id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
   values(s.id,t,-v_bakim,'NPC mağaza 15 dakikalık personel, enerji ve bakım',0,v_bakim,0);
  end if;
  -- 151: günlük brüt kâr tavanı
  v_tavan:=greatest(0,coalesce(s.sermaye,0))*v_tavan_oran/100;
  select coalesce((select m.marj from oyun.npc_marj_gun m where m.sirket_id=s.id and m.gun=v_gun),0) into v_marj;
  select count(*) into v_rakip from oyun.pazar_sirket ps
   join oyun.sirketler c on c.id=ps.sirket_id
   where ps.il_id=s.il_id and c.aktif and c.sektor=s.sektor;
  for st in select ns.urun,ns.adet,ns.alis_ortalama,ns.satis_fiyati,
    u.gunluk_talep from oyun.npc_stok ns join oyun.npc_urun_katalog u on u.kod=ns.urun
    where ns.sirket_id=s.id and ns.adet>0 order by ns.urun for update of ns
  loop
    insert into oyun.npc_talep_gun(il_id,urun,gun)
    values(s.il_id,st.urun,v_gun) on conflict do nothing;
    select adet into v_satilan from oyun.npc_talep_gun
       where il_id=s.il_id and urun=st.urun and gun=v_gun for update;
    v_lim:=greatest(1,round(2*st.gunluk_talep*greatest(0.7,least(3,s.sehir_carpani))*
      (1+oyun.belediye_yatirim_oran(s.il_id,'talep'))));
    v_adet:=least(st.adet,greatest(0,v_lim-v_satilan),
       greatest(0,floor(st.gunluk_talep*greatest(.7,least(3,s.sehir_carpani))/30*
       (0.65+random()*.7)/sqrt(greatest(1,v_rakip))*
       (0.65+s.gelisim/150.0)*
       greatest(0.2,least(1.7,power(
       oyun.npc_piyasa_fiyati(st.urun,s.il_id,'satis')/greatest(st.satis_fiyati,0.01),3)))
       +random())::integer));
    if v_adet<=0 then continue; end if;
    v_birim:=st.satis_fiyati-st.alis_ortalama;
    if v_tavan_oran>0 and v_birim>0 then
      v_adet:=least(v_adet,greatest(0,floor((v_tavan-v_marj)/v_birim))::integer);
      if v_adet<=0 then continue; end if;
    end if;
    v_gelir:=round(st.satis_fiyati*v_adet,2);
    v_maliyet:=round(st.alis_ortalama*v_adet,2);
    v_kdv:=round(greatest(0,v_gelir-v_maliyet)*v_oran/(100+v_oran),2);
    v_diger:=round(v_gelir*0.006,2);
    v_kurum:=round(greatest(0,v_gelir-v_maliyet-v_kdv-v_diger)*v_kv/100,2);
    v_kar:=v_gelir-v_maliyet-v_kdv-v_diger-v_kurum;
    update oyun.npc_stok set adet=adet-v_adet,son_guncelleme=t
     where sirket_id=s.id and urun=st.urun;
    update oyun.npc_talep_gun set adet=adet+v_adet
     where il_id=s.il_id and urun=st.urun and gun=v_gun;
    update oyun.sirketler set kasa=kasa+v_gelir-v_kdv-v_diger-v_kurum,son_islem=t where id=s.id;
    v_marj:=v_marj+greatest(0,v_gelir-v_maliyet);
    insert into oyun.npc_marj_gun(sirket_id,gun,marj) values(s.id,v_gun,greatest(0,v_gelir-v_maliyet))
      on conflict (sirket_id,gun) do update set marj=oyun.npc_marj_gun.marj+excluded.marj;
    insert into oyun.npc_satis_kayit(sirket_id,urun,adet,tutar,maliyet,vergi,isletme_gideri,tur,zaman)
      values(s.id,st.urun,v_adet,v_gelir,v_maliyet,v_kdv+v_kurum,v_diger,'npc_satis',t) returning id into v_satis_id;
    insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
      values(s.id,t,v_kar,format('NPC satış: %s adet %s (KDV ve kâr vergisi dahil)',v_adet,st.urun),
      v_gelir,v_maliyet+v_kdv+v_kurum+v_diger,0);
    if v_kdv+v_kurum>0 then
      update oyun.ulke set hazine=hazine+(v_kdv+v_kurum)/v_tlm where id=1;
      if v_kdv>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kdv',v_gelir,v_oran,v_kdv,'npc_satis',v_satis_id,t);
      end if;
      if v_kurum>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kurumlar',greatest(0,v_gelir-v_maliyet-v_kdv-v_diger),v_kv,v_kurum,'npc_satis',v_satis_id,t);
      end if;
    end if;
    v_ciro:=v_ciro+v_gelir;v_n:=v_n+v_adet;
  end loop;
 end loop;
 return jsonb_build_object('satilan',v_n,'ciro',v_ciro,'zaman',t);
end $function$;

-- Makam maaşı: en yüksek makam tam, diğer her makam %25 (Meclis Başkanlığı / başkanvekilliği / grup başkanvekilliği
-- vekil ödeneğine eklenen görev tazminatıdır, tam ödenir). Gerçekte de iki kamu görevinden iki tam maaş alınmaz.
create or replace function oyun.makam_maas_toplam(u uuid, t timestamptz) returns numeric
language sql stable set search_path = '' as $$
  with m as (
    select oyun.makam_maasi(m.tur, m.il_id) * case when m.tur = 'mv' then 1 - oyun.vekil_kesinti_orani(u, t) / 100 else 1 end v,
           m.tur in ('tbmm', 'bskv', 'grup_bskv') ek
    from oyun.makamlar m where m.user_id = u and m.bit is null
    union all
    select y.v, false from (select oyun.yargic_maasi(u) v) y where y.v > 0),
  a as (select v from m where not ek)
  select coalesce((select max(v) + (sum(v) - max(v)) * oyun.tf('makam_ek_oran') / 100 from a), 0)
       + coalesce((select sum(v) from m where ek), 0)
$$;

create or replace function oyun.gelir_hesap(u uuid, t timestamp with time zone)
 returns jsonb language plpgsql stable as $function$
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
  seri_y := case when c.seri_gun = bugun then c.seri when c.seri_gun = bugun - 1 then c.seri + 1
                when c.seri_gun is null then 1
                else greatest(1, coalesce(c.seri, 1) - (bugun - c.seri_gun - 1)) end;
  seri_b := least(oyun.duz('seri_tavan'), 5 * (seri_y - 1));
  asg_saat := ul.asgari / 720;
  maas := asg_saat * v_hiz * (st ->> 'carpan')::numeric * ilc * (1 + ub / 100);
  -- Meclis devamsızlık kesintisi (mevzuat), Yüksek Mahkeme maaşı (30.10) ve 151: ikinci makamdan %25
  makam := oyun.makam_maas_toplam(u, t) / 720;
  brut := (maas + makam) * (1 + seri_b / 100);
  vergi := greatest(0, brut - asg_saat) * ul.vergi / 100;
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
    'makam_ek_oran', oyun.tf('makam_ek_oran'),
    'reklam_odul', round(maas * 2));
end $function$;

-- =====================================================================
-- C) SİYASİ ÜCRETLER ve KÜÇÜK KURULUŞLAR
-- =====================================================================
create or replace function oyun.aday_ucreti(p_parti bigint, p_tur text, p_il smallint) returns numeric language sql stable as $$
  select round((case p_tur when 'mv_on' then oyun.tf('aday_mv') when 'kurultay' then oyun.tf('aday_kurultay') when 'cb_on' then oyun.tf('aday_cb')
                  when 'bel_on' then oyun.tf('aday_bel') * coalesce((select case when mv >= 14 then 3 when mv >= 8 then 2 else 1 end from oyun.iller where id = p_il), 1)
                  else 0 end)
               * (select endeks from oyun.ulke where id = 1)
               * coalesce((select (aday_ucret ->> p_tur)::numeric from oyun.partiler where id = p_parti), 1))
$$;

create or replace function oyun.tasinma_ucreti(p_kaynak smallint, p_hedef smallint, t timestamptz) returns numeric language sql stable as $$
  select round(oyun.tf('tasinma') * u.endeks * (1 - least(90, u.tasinma_destek
                + greatest(oyun.bonus(p_kaynak, 'tasinma', t), oyun.bonus(p_hedef, 'tasinma', t))) / 100))
  from oyun.ulke u where u.id = 1
$$;

create or replace function oyun.dernek_harci() returns numeric language sql stable set search_path = '' as $$
  select oyun.tf_tl('dernek_harc')
$$;

create or replace function oyun.dernek_sube_ucreti(p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select round(oyun.tf('dernek_sube') * oyun.il_buyukluk(p_il) * coalesce((select endeks from oyun.ulke where id = 1), 1) / 100) * 100
$$;

create or replace function oyun.miting_bedel(p_il smallint) returns numeric language sql stable set search_path = '' as $$
  select round(oyun.tf('miting') * oyun.il_buyukluk(p_il) * coalesce((select endeks from oyun.ulke where id = 1), 1) / 100) * 100
$$;

create or replace function public.meslek_dukkan_ac(p_tur text, p_ad text, p_sermaye numeric)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); il smallint; did bigint; bedel numeric:=5000; minc numeric:=oyun.tf('meslek_min');
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris gerekli';end if;
 perform oyun.statu_kontrol(u,'sirket_statu','Dükkân açmak');
 if p_tur not in ('doviz','kuyumcu') or p_ad is null or length(btrim(p_ad)) not between 3 and 60 then raise exception 'Dukkan turu veya adi gecersiz';end if;
 if p_sermaye is null or p_sermaye<>trunc(p_sermaye) or p_sermaye<minc or p_sermaye>100000000 then
   raise exception 'Sermaye % ile 100.000.000 ₺ arasında tam sayı olmalı.', oyun.tl(minc);end if;
 if exists(select 1 from oyun.meslek_dukkan where sahibi=u and tur=p_tur) then raise exception 'Bu turde zaten dukkanin var';end if;
 perform oyun.para_islem(u,-p_sermaye,'meslek','Dukkan acma ve sermaye: '||p_ad,now());
 select il_id into il from oyun.profiller where id=u;
 insert into oyun.meslek_dukkan(sahibi,tur,ad,il_id,kasa,makas) values(u,p_tur,btrim(p_ad),il,p_sermaye-bedel,case when p_tur='doviz' then 0.7 else 1.5 end) returning id into did;
 update oyun.ulke set hazine=hazine+bedel/oyun.pazar_tl_milyar() where id=1;
 return jsonb_build_object('id',did,'kasa',p_sermaye-bedel,'ruhsat',bedel);
end; $function$;

create or replace function public.ajans_kur(p_ad text, p_sermaye numeric)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); v_id bigint; t timestamptz := oyun.simdi(); minc numeric := oyun.tf('ajans_min');
begin
  if p_ad is null or char_length(btrim(p_ad)) not between 3 and 50 then raise exception 'Ajans adı 3-50 karakter olmalı.'; end if;
  if p_sermaye is null or p_sermaye <> round(p_sermaye) or p_sermaye < minc or p_sermaye > 100000000 then
    raise exception 'Ajans sermayesi en az % ₺, en fazla 100.000.000 ₺ olmalı.', oyun.tl(minc);
  end if;
  if exists (select 1 from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id = s.id
             where s.sektor = 'ajans' and s.aktif and o.user_id = p.id and o.pay >= 50) then
    raise exception 'Zaten çoğunluğuna sahip olduğun bir ajans var.';
  end if;
  perform oyun.para_islem(p.id, -p_sermaye, 'sirket', 'Reklam ve anket ajansı kuruluş sermayesi', t);
  insert into oyun.sirketler(ad, sektor, kurucu, sermaye, kasa, son_islem, kurulus, sonraki_kazanc)
    values (btrim(p_ad), 'ajans', p.id, p_sermaye, p_sermaye, t, t, t + interval '7 days') returning id into v_id;
  insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values (v_id, p.id, 100);
  insert into oyun.ajans(sirket_id) values (v_id);
  perform oyun.olay('ekonomi', format('%s yeni bir reklam ve anket ajansı kurdu: %s.', p.kad, btrim(p_ad)), null, null, t);
  return jsonb_build_object('id', v_id);
end $function$;

-- =====================================================================
-- D) KURULUŞ KİLİTLERİ (tek geçit: tablo tetikleri; oyuncu işlemi değilse dokunulmaz)
-- =====================================================================
create or replace function oyun.tg_kurulus_denge_sirket() returns trigger
language plpgsql security definer set search_path = '' as $$
declare b int; hak int; n int; minc numeric; sad text;
begin
  if new.kurucu is null or auth.uid() is null or oyun.tf('kilit_aktif') <> 1 then return new; end if;
  if new.sektor = 'banka' then
    perform oyun.statu_kontrol(new.kurucu, 'banka_statu', 'Banka kurmak');
    minc := oyun.tf('banka_min'); sad := 'Banka';
  elsif new.sektor = 'ajans' then
    perform oyun.statu_kontrol(new.kurucu, 'ajans_statu', 'Reklam ve anket ajansı kurmak');
    minc := oyun.tf('ajans_min'); sad := 'Reklam ve anket ajansı';
  else
    perform oyun.statu_kontrol(new.kurucu, 'sirket_statu', 'Şirket kurmak');
    select k.min_sermaye, k.ad into minc, sad from oyun.pazar_sektor k where k.kod = new.sektor;
  end if;
  if coalesce(new.sermaye, 0) < coalesce(minc, 0) then
    raise exception '% için kuruluş sermayesi en az % ₺ olmalı.', coalesce(sad, 'Bu şirket türü'), oyun.tl(minc);
  end if;
  b := oyun.statum(new.kurucu); hak := oyun.tf('slot_' || b)::int;
  select count(*) into n from oyun.sirketler s where s.aktif and coalesce(oyun.sirket_sahibi(s.id), s.kurucu) = new.kurucu;
  if n >= hak then
    raise exception 'Şirket hakkın dolu: "%" statüsünde aynı anda en çok % şirketin olabilir (şu an %). %', oyun.statu_ad(b), hak, n,
      case when b < 5 then format('%s kıdeme ulaşıp "%s" olunca hakkın %s şirkete çıkar.', oyun.statu_esik(b + 1), oyun.statu_ad(b + 1), oyun.tf('slot_' || (b + 1))::int)
           else 'Yeni şirket için mevcut şirketlerinden birini sat ya da kapat.' end;
  end if;
  return new;
end $$;
create or replace trigger tg_kurulus_denge_sirket before insert on oyun.sirketler for each row execute function oyun.tg_kurulus_denge_sirket();

create or replace function oyun.tg_kurulus_denge_gazete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.sahip is not null and auth.uid() is not null then perform oyun.statu_kontrol(new.sahip, 'gazete_statu', 'Gazete kurmak'); end if;
  return new;
end $$;
create or replace trigger tg_kurulus_denge_gazete before insert on oyun.oyuncu_gazeteleri for each row execute function oyun.tg_kurulus_denge_gazete();

create or replace function oyun.tg_kurulus_denge_dernek() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kurucu is not null and auth.uid() is not null then perform oyun.statu_kontrol(new.kurucu, 'dernek_statu', 'Dernek kurmak'); end if;
  return new;
end $$;
create or replace trigger tg_kurulus_denge_dernek before insert on oyun.dernekler for each row execute function oyun.tg_kurulus_denge_dernek();

-- =====================================================================
-- E) EKİP PARTİSİ — kurucular kurulu, ortak kuruluş fonu (emanet), süre dolunca iade
-- =====================================================================
alter table oyun.kurucu_davet add column if not exists katki numeric not null default 0;
alter table oyun.kurucu_basvuru add column if not exists gerekli int;
alter table oyun.kurucu_basvuru add column if not exists kurucu_katki numeric not null default 0;

-- Kurucular kurulu büyüklüğü (başvuran dahil): oyuncu sayısıyla büyür, gerçek yasadaki 30 kişide durur
create or replace function oyun.parti_kurucu_gerekli() returns int
language sql stable set search_path = '' as $$
  select least(oyun.tf('parti_kurucu_max'), greatest(oyun.tf('parti_kurucu_min'),
    ceil((select count(*) from oyun.profiller p where not p.yasakli and p.son_gorulme > oyun.simdi() - interval '14 days')
         * oyun.tf('parti_kurucu_oran') / 100.0)))::int
$$;

create or replace function oyun.parti_kurucu_engel(p oyun.profiller, t timestamptz) returns text
language plpgsql stable set search_path = '' as $$
declare k numeric := oyun.kidem_puani(p.id); gerek int := oyun.tf('parti_kurucu_statu')::int;
        g int := oyun.tf('parti_kurucu_hesap_gun')::int; bek int := coalesce((select parti_kur_gun from oyun.ayarlar where id = 1), 0);
begin
  if p.id is null then return 'Profil bulunamadı.'; end if;
  if oyun.uyari(p, t) is not null then return oyun.uyari(p, t); end if;
  if oyun.tf('kilit_aktif') = 1 and oyun.statu_basamak(k) < gerek then
    return format('Parti kurma başvurusu için en az "%s" statüsü (%s kıdem) gerekiyor; kıdemin %s.', oyun.statu_ad(gerek), oyun.statu_esik(gerek), floor(k));
  end if;
  if p.olusturma > t - make_interval(days => g) then return format('Parti kurmak için hesabın en az %s günlük olmalı.', g); end if;
  if p.son_parti_kur is not null and p.son_parti_kur + make_interval(days => bek) > t then
    return format('Yeni bir parti kurabilmen için %s tarihini beklemelisin (iki kuruluş arası %s gün).',
      to_char((p.son_parti_kur + make_interval(days => bek)) at time zone 'Europe/Istanbul', 'DD.MM.YYYY'), bek);
  end if;
  if exists(select 1 from oyun.partiler pa where pa.gb = p.id and not pa.kapali) then
    return 'Genel başkanı olduğun partiden ayrılmadan yeni parti kuramazsın.';
  end if;
  if exists(select 1 from oyun.mahkeme_uye m where m.sira in (1, 2) and m.user_id = p.id) then
    return 'Yüksek Mahkeme üyeleri parti kuramaz.';
  end if;
  return null;
end $$;

create or replace function oyun.parti_ortak_engel(h oyun.profiller, b oyun.kurucu_basvuru, t timestamptz) returns text
language plpgsql stable set search_path = '' as $$
declare k numeric := oyun.kidem_puani(h.id); gerek int := oyun.tf('parti_ortak_statu')::int;
        g int := oyun.tf('parti_ortak_hesap_gun')::int; bek int := oyun.tf('parti_ortak_bekleme_gun')::int;
begin
  if h.id is null or h.yasakli then return 'Hesap kullanılamıyor.'; end if;
  if oyun.uyari(h, t) is not null then return oyun.uyari(h, t); end if;
  if oyun.tf('kilit_aktif') = 1 and oyun.statu_basamak(k) < gerek then
    return format('Kurucu üye olmak için en az "%s" statüsü (%s kıdem) gerekiyor; kıdem %s.', oyun.statu_ad(gerek), oyun.statu_esik(gerek), floor(k));
  end if;
  if h.olusturma > t - make_interval(days => g) then return format('Kurucu üye olmak için hesabın en az %s günlük olmalı.', g); end if;
  if exists(select 1 from oyun.partiler pa where pa.gb = h.id and not pa.kapali) then
    return 'Bir partinin genel başkanı başka bir partinin kurucu üyesi olamaz.';
  end if;
  if exists(select 1 from oyun.mahkeme_uye m where m.sira in (1, 2) and m.user_id = h.id) then
    return 'Yüksek Mahkeme üyeleri parti kurucusu olamaz.';
  end if;
  if (h.son_parti_kur is not null and h.son_parti_kur > t - make_interval(days => bek))
     or exists(select 1 from oyun.kurucu_davet d join oyun.kurucu_basvuru b2 on b2.id = d.basvuru_id
               where d.user_id = h.id and d.durum = 'evet' and b2.durum = 'kuruldu' and b2.id <> b.id
                 and coalesce(d.cevap_at, b2.bas) > t - make_interval(days => bek)) then
    return format('Son %s gün içinde başka bir partinin kurucusu oldun; bu sürede yeniden kurucu üye olunamaz.', bek);
  end if;
  if exists(select 1 from oyun.bagli_hesaplar(h.id) x
            where x = b.kurucu or x in (select d.user_id from oyun.kurucu_davet d where d.basvuru_id = b.id and d.durum = 'evet' and d.user_id <> h.id)) then
    return 'Aynı cihazda açılmış hesaplar aynı kurucular kurulunda yer alamaz.';
  end if;
  return null;
end $$;

-- Emanetteki katkıyı sahibine iade eder
create or replace function oyun.kurucu_iade(p_basvuru bigint, p_user uuid, p_neden text, t timestamptz) returns numeric
language plpgsql security definer set search_path = '' as $$
declare b oyun.kurucu_basvuru; tutar numeric := 0;
begin
  select * into b from oyun.kurucu_basvuru where id = p_basvuru;
  if b.id is null or p_user is null then return 0; end if;
  if p_user = b.kurucu then
    tutar := b.kurucu_katki;
    update oyun.kurucu_basvuru set kurucu_katki = 0 where id = p_basvuru;
  else
    select d.katki into tutar from oyun.kurucu_davet d where d.basvuru_id = p_basvuru and d.user_id = p_user for update;
    update oyun.kurucu_davet set katki = 0 where basvuru_id = p_basvuru and user_id = p_user;
  end if;
  if coalesce(tutar, 0) > 0 then
    perform oyun.para_islem(p_user, tutar, 'iade', format('%s kuruluş fonu katkısı iadesi (%s)', b.ad, p_neden), t);
  end if;
  return coalesce(tutar, 0);
end $$;

create or replace function oyun.kurucu_basvuru_kapat(p_basvuru bigint, p_durum text, p_neden text, t timestamptz) returns numeric
language plpgsql security definer set search_path = '' as $$
declare b oyun.kurucu_basvuru; x record; top numeric := 0; i numeric;
begin
  select * into b from oyun.kurucu_basvuru where id = p_basvuru for update;
  if b.id is null or b.durum <> 'bekliyor' then return 0; end if;
  top := oyun.kurucu_iade(b.id, b.kurucu, p_neden, t);
  for x in select d.user_id from oyun.kurucu_davet d where d.basvuru_id = b.id and d.katki > 0 loop
    i := oyun.kurucu_iade(b.id, x.user_id, p_neden, t);
    top := top + i;
    if i > 0 then
      perform oyun.bildir(x.user_id, format('%s kuruluş başvurusu kapandı (%s). Kuruluş fonuna yaptığın %s ₺ katkı cüzdanına iade edildi.', b.ad, p_neden, oyun.tl(i)), t);
    end if;
  end loop;
  update oyun.kurucu_basvuru set durum = p_durum where id = b.id;
  return top;
end $$;

create or replace function oyun.kurucu_suresi_dolan() returns int
language plpgsql security definer set search_path = '' as $$
declare b record; n int := 0; t timestamptz := oyun.simdi();
begin
  for b in select id, kurucu, ad from oyun.kurucu_basvuru where durum = 'bekliyor' and bit <= t order by id limit 200 loop
    perform oyun.kurucu_basvuru_kapat(b.id, 'suresi_doldu', 'süre doldu', t);
    perform oyun.bildir(b.kurucu, format('%s kuruluş başvurusunun süresi doldu; kuruluş fonundaki bütün katkılar sahiplerine iade edildi.', b.ad), t);
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.parti_kur_baslat(p_ad text, p_kisa text, p_renk text, p_amblem text, p_ideolojiler text[], p_kadlar text[])
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); idd bigint; nick text; hedef oyun.profiller; sayi int:=0;
 gerek int:=oyun.parti_kurucu_gerekli(); engel text; harc numeric:=greatest(25000,oyun.parti_kur_ucreti()); fon numeric:=oyun.tf_tl('parti_fon');
begin
 p_ad:=btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
 p_kisa:=upper(btrim(coalesce(p_kisa,'')));
 if length(p_ad) not between 5 and 40 or p_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then raise exception 'Parti adı 5-40 harften oluşmalı.'; end if;
 if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' or p_renk !~ '^#[0-9a-fA-F]{6}$' or p_amblem !~ '^[a-z_]{2,20}$' then raise exception 'Kısaltma, renk veya amblem geçersiz.'; end if;
 if not oyun.ideoloji_gecerli(p_ideolojiler) then raise exception 'En az 1 en çok 3 ideoloji seç.'; end if;
 if oyun.yasakli_ad(p_ad) or oyun.yasakli_kisa(p_kisa) then raise exception 'Gerçek bir partiyi çağrıştıran ad kullanılamaz.'; end if;
 if exists(select 1 from oyun.partiler where not kapali and (lower(ad)=lower(p_ad) or lower(kisa)=lower(p_kisa))) then raise exception 'Parti adı veya kısaltması kullanımda.'; end if;
 engel:=oyun.parti_kurucu_engel(p,t);
 if engel is not null then raise exception 'Parti kurma şartı: %',engel; end if;
 perform oyun.kurucu_suresi_dolan();
 if exists(select 1 from oyun.kurucu_basvuru where kurucu=p.id and durum='bekliyor' and bit>t) then
   raise exception 'Süren bir kuruluş başvurun var. Partiler › Kurucu davetleri ekranından yönetebilirsin.'; end if;
 if coalesce(cardinality(p_kadlar),0) not between (gerek-1) and 50 then
   raise exception 'Kurucular kurulu sen dahil en az % kişi olmalı: en az %, en çok 50 oyuncuyu davet et.',gerek,gerek-1; end if;
 insert into oyun.kurucu_basvuru(kurucu,ad,kisa,renk,amblem,ideolojiler,bas,bit,gerekli)
 values(p.id,p_ad,p_kisa,lower(p_renk),p_amblem,p_ideolojiler,t,t+make_interval(days=>oyun.tf('parti_basvuru_gun')::int),gerek)
 returning id into idd;
 foreach nick in array p_kadlar loop
  nick:=btrim(nick);
  select * into hedef from oyun.profiller where lower(kad)=lower(nick) and not yasakli;
  if hedef.id is null or hedef.id=p.id then raise exception 'Kurucu adayı bulunamadı veya kendini davet ettin: %',nick; end if;
  insert into oyun.kurucu_davet(basvuru_id,user_id,zaman) values(idd,hedef.id,t)
   on conflict do nothing;
  if found then
   sayi:=sayi+1;
   perform oyun.bildir(hedef.id,format('%s seni %s (%s) partisinin kurucular kuruluna davet etti (sen dahil en az %s kurucu gerekiyor). Partiler › Kurucu davetleri ekranından yanıtla. Onay verirsen kuruluşta partiye katılırsın; dilersen kuruluş fonuna katkı yapabilirsin, parti kurulmazsa katkın iade edilir.',p.kad,p_ad,p_kisa,gerek),t);
  end if;
 end loop;
 if sayi<gerek-1 then raise exception 'En az % farklı kayıtlı oyuncuyu kurucular kuruluna davet etmelisin.',gerek-1; end if;
 return jsonb_build_object('basvuru_id',idd,'davet',sayi,'gerekli',gerek-1,'kurucu_kurulu',gerek,'harc',harc,'fon',fon,'sermaye',harc+fon);
end $function$;

-- Eski doğrudan kuruluş çağrısı (eski uygulamalar): doğru yönlendirme metni
create or replace function public.parti_kur(p_ad text, p_kisa text, p_renk text, p_amblem text)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
begin
 raise exception 'Yeni parti kurmak için kurucular kurulu gerekir: Partiler › Parti kur ekranından kurucu davetlerini gönder (sen dahil en az % kişi).', oyun.parti_kurucu_gerekli();
end $function$;

create or replace function public.kurucu_davet_ekle(p_basvuru bigint, p_kadlar text[])
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); b oyun.kurucu_basvuru; t timestamptz:=oyun.simdi();
 nick text; hedef oyun.profiller; toplam int; eklenen int:=0; gerek int;
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru for update;
 if b.id is null or b.kurucu is distinct from p.id or b.durum<>'bekliyor' or b.bit<=t then
  raise exception 'Yalnızca kendine ait, süresi dolmamış kuruluş başvurusuna davet ekleyebilirsin.';
 end if;
 gerek:=coalesce(b.gerekli,oyun.parti_kurucu_gerekli());
 if coalesce(cardinality(p_kadlar),0) not between 1 and 50 then raise exception 'En az 1, en çok 50 yeni kurucu adayı yaz.'; end if;
 select count(*) into toplam from oyun.kurucu_davet where basvuru_id=b.id;
 if toplam+cardinality(p_kadlar)>50 then
  raise exception 'Bu başvuruya toplam en fazla 50 kişi davet edebilirsin. Kalan hak: %.',greatest(0,50-toplam);
 end if;
 foreach nick in array p_kadlar loop
  nick:=btrim(coalesce(nick,''));
  if nick='' then raise exception 'Boş kullanıcı adı yazılamaz.'; end if;
  select * into hedef from oyun.profiller where lower(kad)=lower(nick) and not yasakli;
  if hedef.id is null or hedef.id=p.id then raise exception 'Kurucu adayı bulunamadı veya kendini davet ettin: %',nick; end if;
  if exists(select 1 from oyun.kurucu_davet where basvuru_id=b.id and user_id=hedef.id) then raise exception '% bu başvuruya zaten davet edilmiş.',hedef.kad; end if;
  insert into oyun.kurucu_davet(basvuru_id,user_id,zaman) values(b.id,hedef.id,t);
  eklenen:=eklenen+1;
  perform oyun.bildir(hedef.id,format('%s seni %s (%s) partisinin kurucular kuruluna davet etti (sen dahil en az %s kurucu gerekiyor). Partiler › Kurucu davetleri ekranından yanıtla.',p.kad,b.ad,b.kisa,gerek),t);
 end loop;
 return jsonb_build_object('basvuru_id',b.id,'eklenen',eklenen,'toplam',toplam+eklenen,'kalan',50-toplam-eklenen);
end $function$;

create or replace function public.kurucu_davet_yanit(p_basvuru bigint, p_kabul boolean)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); b oyun.kurucu_basvuru; n int; t timestamptz:=oyun.simdi(); engel text; eski text; gerek int;
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru for update;
 if b.id is null or b.durum<>'bekliyor' or b.bit<=t then raise exception 'Bu kurucu daveti geçerli değil.'; end if;
 select d.durum into eski from oyun.kurucu_davet d where d.basvuru_id=b.id and d.user_id=p.id for update;
 if eski is null then raise exception 'Bu başvuruda davetin yok.'; end if;
 if p_kabul then
  if eski<>'bekliyor' then raise exception 'Davetini daha önce yanıtladın.'; end if;
  engel:=oyun.parti_ortak_engel(p,b,t);
  if engel is not null then raise exception 'Kurucu üye şartı: %',engel; end if;
  update oyun.kurucu_davet set durum='evet',cevap_at=t where basvuru_id=b.id and user_id=p.id;
 else
  if eski not in ('bekliyor','evet') then raise exception 'Davetini daha önce yanıtladın.'; end if;
  update oyun.kurucu_davet set durum='hayir',cevap_at=t where basvuru_id=b.id and user_id=p.id;
  perform oyun.kurucu_iade(b.id,p.id,case when eski='evet' then 'onay geri çekildi' else 'davet reddedildi' end,t);
 end if;
 gerek:=coalesce(b.gerekli,oyun.parti_kurucu_gerekli())-1;
 select count(*) into n from oyun.kurucu_davet where basvuru_id=b.id and durum='evet';
 perform oyun.bildir(b.kurucu,format('%s kurucu davetine %s. Onaylar: %s/%s.',p.kad,
   case when p_kabul then 'EVET dedi' when eski='evet' then 'verdiği onayı geri çekti' else 'HAYIR dedi' end,n,gerek),t);
 return jsonb_build_object('kabul',p_kabul,'onay',n,'gerekli',gerek);
end $function$;

create or replace function public.kurucu_katki(p_basvuru bigint, p_tutar numeric)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); b oyun.kurucu_basvuru; t timestamptz:=oyun.simdi(); fon numeric:=oyun.tf_tl('parti_fon');
 emanet numeric; kalan numeric; min_k numeric:=oyun.tf('parti_katki_min');
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru for update;
 if b.id is null or b.durum<>'bekliyor' or b.bit<=t then raise exception 'Kuruluş başvurusu açık değil.'; end if;
 if p.id<>b.kurucu and not exists(select 1 from oyun.kurucu_davet where basvuru_id=b.id and user_id=p.id and durum='evet') then
  raise exception 'Kuruluş fonuna yalnız başvuran ve onay vermiş kurucu üyeler katkı yapabilir.'; end if;
 emanet:=b.kurucu_katki+coalesce((select sum(katki) from oyun.kurucu_davet where basvuru_id=b.id and durum='evet'),0);
 kalan:=greatest(0,fon-emanet);
 if kalan<=0 then raise exception 'Kuruluş fonu tamamlandı; daha fazla katkı gerekmiyor.'; end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<least(min_k,kalan) or p_tutar>kalan then
  raise exception 'Katkı % ₺ ile % ₺ arasında tam sayı olmalı.',oyun.tl(least(min_k,kalan)),oyun.tl(kalan); end if;
 perform oyun.para_islem(p.id,-p_tutar,'parti_kur',format('%s kuruluş fonuna katkı (parti kurulmazsa iade edilir)',b.ad),t);
 if p.id=b.kurucu then update oyun.kurucu_basvuru set kurucu_katki=kurucu_katki+p_tutar where id=b.id;
 else update oyun.kurucu_davet set katki=katki+p_tutar where basvuru_id=b.id and user_id=p.id; end if;
 if p.id<>b.kurucu then
  perform oyun.bildir(b.kurucu,format('%s, %s kuruluş fonuna %s ₺ katkı yaptı. Toplanan: %s / %s ₺.',p.kad,b.ad,oyun.tl(p_tutar),oyun.tl(emanet+p_tutar),oyun.tl(fon)),t);
 end if;
 return jsonb_build_object('katki',p_tutar,'toplanan',emanet+p_tutar,'fon',fon,'kalan',greatest(0,kalan-p_tutar));
end $function$;

create or replace function public.parti_kur_tamamla(p_basvuru bigint)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); b oyun.kurucu_basvuru; t timestamptz:=oyun.simdi();
 n int:=0; gerek int; yeni bigint; harc numeric; fon numeric; emanet numeric:=0; eksik numeric; uid uuid; h oyun.profiller;
 engel text; ilk_engel text; gecerli uuid[]:='{}'; x record;
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru for update;
 if b.id is null or b.kurucu is distinct from p.id or b.durum<>'bekliyor' or b.bit<=t then raise exception 'Aktif kurucu başvurun yok.'; end if;
 engel:=oyun.parti_kurucu_engel(p,t);
 if engel is not null then raise exception 'Kurucu şartı: %',engel; end if;
 gerek:=coalesce(b.gerekli,oyun.parti_kurucu_gerekli());
 for uid in select d.user_id from oyun.kurucu_davet d where d.basvuru_id=b.id and d.durum='evet' order by d.cevap_at, d.user_id loop
  select * into h from oyun.profiller where id=uid;
  engel:=oyun.parti_ortak_engel(h,b,t);
  if engel is null then
   gecerli:=gecerli||uid; n:=n+1;
   emanet:=emanet+coalesce((select katki from oyun.kurucu_davet where basvuru_id=b.id and user_id=uid),0);
  elsif ilk_engel is null then ilk_engel:=format('%s: %s',h.kad,engel);
  end if;
 end loop;
 if n<gerek-1 then
  raise exception 'Kurucular kurulu eksik: sen dahil en az % kişi gerekiyor, şartları taşıyan onay sayısı %.%',gerek,n,
    coalesce(' Şartı taşımayan onay → '||ilk_engel,'');
 end if;
 if exists(select 1 from oyun.partiler where not kapali and (lower(ad)=lower(b.ad) or lower(kisa)=lower(b.kisa))) then raise exception 'Bu isim veya kısaltma artık kullanılıyor.'; end if;
 harc:=greatest(25000,oyun.parti_kur_ucreti()); fon:=oyun.tf_tl('parti_fon');
 emanet:=emanet+b.kurucu_katki;
 eksik:=greatest(0,fon-emanet);
 if (select para from oyun.cuzdanim(p.id))<harc+eksik then
  raise exception 'Kuruluş için % ₺ harç% gerekiyor; cüzdanında % ₺ var. Kurucu üyeler fona katkı yaparak eksiği tamamlayabilir.',oyun.tl(harc),
    case when eksik>0 then format(' ve kuruluş fonunun eksik kalan %s ₺''si',oyun.tl(eksik)) else '' end,
    oyun.tl((select para from oyun.cuzdan where user_id=p.id));
 end if;
 perform oyun.para_islem(p.id,-harc,'parti_kur',format('%s kuruluş harcı ve genel merkez binası',b.ad),t);
 if eksik>0 then perform oyun.para_islem(p.id,-eksik,'parti_kur',format('%s kuruluş fonu (tamamlayıcı katkı)',b.ad),t); end if;
 -- Şartı taşımayan ya da onayını çeken kişilerin emaneti iade edilir; geçerli kurucuların emaneti partiye geçer.
 for x in select d.user_id from oyun.kurucu_davet d where d.basvuru_id=b.id and d.katki>0 and not (d.user_id=any(gecerli)) loop
  perform oyun.kurucu_iade(b.id,x.user_id,'kurucu şartını taşımadığı için',t);
 end loop;
 update oyun.kurucu_davet set katki=0 where basvuru_id=b.id and user_id=any(gecerli);
 update oyun.kurucu_basvuru set kurucu_katki=0 where id=b.id;
 perform oyun._ayril(p.id,t);
 insert into oyun.partiler(ad,kisa,renk,amblem,gb,kurucu,kurulus,kurulus_bit)
 values(b.ad,b.kisa,b.renk,b.amblem,p.id,p.id,t,null) returning id into yeni;
 perform oyun.genel_merkez_ac(yeni,p,harc,t);
 update oyun.partiler set kasa=coalesce(kasa,0)+emanet+eksik where id=yeni;
 insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
 values(yeni,t,emanet+eksik,format('Kurucular kurulunun kuruluş fonu (%s kurucu)',n+1),'kurulus');
 update oyun.profiller set parti_id=yeni,parti_at=t,son_parti_kur=t where id=p.id;
 foreach uid in array gecerli loop
  perform oyun._ayril(uid,t);
  update oyun.profiller set parti_id=yeni,parti_at=t where id=uid and not yasakli;
  perform oyun.bildir(uid,format('%s kuruldu! Kurucular kuruluna katıldın; kuruluş fonu partinin kasasına geçti.',b.ad),t);
 end loop;
 for x in select d.user_id from oyun.kurucu_davet d where d.basvuru_id=b.id and d.durum='evet' and not (d.user_id=any(gecerli)) loop
  perform oyun.bildir(x.user_id,format('%s kuruldu ancak kurucu şartını taşımadığın için kurucular kuruluna alınmadın; katkın varsa iade edildi.',b.ad),t);
 end loop;
 insert into oyun.parti_kimlik(parti_id,ideolojiler,guncelleme) values(yeni,b.ideolojiler,t);
 update oyun.kurucu_basvuru set durum='kuruldu',parti_id=yeni where id=b.id;
 perform oyun.olay('parti',format('%s (%s), %s kişilik kurucular kurulu ve %s ₺ kuruluş fonuyla kuruldu.',b.ad,b.kisa,n+1,oyun.tl(emanet+eksik)),p.il_id,yeni,t);
 return jsonb_build_object('parti_id',yeni,'kurucu_sayi',n+1,'harc',harc,'fon',emanet+eksik,'sermaye',harc);
end $function$;

create or replace function public.parti_kur_iptal(p_basvuru bigint)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); b oyun.kurucu_basvuru; iade numeric;
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru and kurucu=p.id and durum='bekliyor' for update;
 if b.id is null then raise exception 'İptal edilecek başvuru yok.'; end if;
 iade:=oyun.kurucu_basvuru_kapat(b.id,'iptal','başvuru iptal edildi',oyun.simdi());
 return jsonb_build_object('tamam',true,'iade',iade);
end $function$;

create or replace function public.kurucu_davetlerim()
 returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); fon numeric:=oyun.tf_tl('parti_fon'); gerek int:=oyun.parti_kurucu_gerekli();
 harc numeric:=greatest(25000,oyun.parti_kur_ucreti()); b oyun.kurucu_basvuru; basvurum jsonb;
begin
 select * into b from oyun.kurucu_basvuru x where x.kurucu=p.id and x.durum='bekliyor' and x.bit>t order by x.id desc limit 1;
 if b.id is not null then
  basvurum:=jsonb_build_object('id',b.id,'ad',b.ad,'kisa',b.kisa,'bit',b.bit,'ideolojiler',b.ideolojiler,
   'onay',(select count(*) from oyun.kurucu_davet d where d.basvuru_id=b.id and d.durum='evet'),
   'gerekli',coalesce(b.gerekli,gerek)-1,'kurucu_kurulu',coalesce(b.gerekli,gerek),
   'harc',harc,'fon',fon,'kurucu_katki',b.kurucu_katki,
   'toplanan',b.kurucu_katki+coalesce((select sum(d.katki) from oyun.kurucu_davet d where d.basvuru_id=b.id and d.durum='evet'),0),
   'davetler',(select coalesce(jsonb_agg(jsonb_build_object('kad',h.kad,'durum',d.durum,'katki',d.katki,
       'engel',case when d.durum='evet' then oyun.parti_ortak_engel(h,b,t) end) order by (d.durum='evet') desc, h.kad),'[]'::jsonb)
     from oyun.kurucu_davet d join oyun.profiller h on h.id=d.user_id where d.basvuru_id=b.id));
 end if;
 return jsonb_build_object(
  'kurallar',jsonb_build_object('kurucu_kurulu',gerek,'harc',harc,'fon',fon,'katki_min',oyun.tf('parti_katki_min'),
    'kurucu_statu',oyun.statu_ad(oyun.tf('parti_kurucu_statu')::int),'ortak_statu',oyun.statu_ad(oyun.tf('parti_ortak_statu')::int),
    'kurucu_hesap_gun',oyun.tf('parti_kurucu_hesap_gun'),'ortak_hesap_gun',oyun.tf('parti_ortak_hesap_gun'),
    'basvuru_gun',oyun.tf('parti_basvuru_gun'),'engel',oyun.parti_kurucu_engel(p,t)),
  'gelen',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'ad',x.ad,'kisa',x.kisa,'kurucu',k.kad,'ideolojiler',x.ideolojiler,'bit',x.bit,
      'durum',d.durum,'gerekli',coalesce(x.gerekli,gerek)-1,
      'onay',(select count(*) from oyun.kurucu_davet d2 where d2.basvuru_id=x.id and d2.durum='evet'),
      'engel',oyun.parti_ortak_engel(p,x,t)) order by x.id desc)
    from oyun.kurucu_davet d join oyun.kurucu_basvuru x on x.id=d.basvuru_id join oyun.profiller k on k.id=x.kurucu
    where d.user_id=p.id and d.durum='bekliyor' and x.durum='bekliyor' and x.bit>t),'[]'::jsonb),
  'onayladiklarim',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'ad',x.ad,'kisa',x.kisa,'kurucu',k.kad,'bit',x.bit,
      'katki',d.katki,'fon',fon,'gerekli',coalesce(x.gerekli,gerek)-1,
      'onay',(select count(*) from oyun.kurucu_davet d2 where d2.basvuru_id=x.id and d2.durum='evet'),
      'toplanan',x.kurucu_katki+coalesce((select sum(d3.katki) from oyun.kurucu_davet d3 where d3.basvuru_id=x.id and d3.durum='evet'),0)) order by x.id desc)
    from oyun.kurucu_davet d join oyun.kurucu_basvuru x on x.id=d.basvuru_id join oyun.profiller k on k.id=x.kurucu
    where d.user_id=p.id and d.durum='evet' and x.durum='bekliyor' and x.bit>t),'[]'::jsonb),
  'basvurum',basvurum);
end $function$;

-- Vatandaşlık ekranındaki "parti kurma" bilgisi (eski uygulamalar 'ucret' alanında toplam tutarı görür)
create or replace function public.vatandaslik()
 returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.ayarlar; k numeric := oyun.kidem_puani(p.id);
        harc numeric := greatest(25000, oyun.parti_kur_ucreti()); fon numeric := oyun.tf_tl('parti_fon');
begin
  select * into a from oyun.ayarlar where id = 1;
  return jsonb_build_object(
    'uygun', oyun.uyari(p, t) is null, 'engel', oyun.uyari(p, t),
    'sartlar', jsonb_build_array(
      jsonb_build_object('ad', format('Hesap en az %s günlük', a.min_hesap_gun), 'tamam', p.olusturma <= t - make_interval(days => a.min_hesap_gun),
                         'not', case when p.olusturma > t - make_interval(days => a.min_hesap_gun) then 'Tamamlanma: ' || to_char((p.olusturma + make_interval(days => a.min_hesap_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') end),
      jsonb_build_object('ad', 'E-posta doğrulanmış', 'tamam', not a.eposta_zorunlu or exists (select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)),
      jsonb_build_object('ad', 'Cihaz doğrulanmış', 'tamam', not a.cihaz_zorunlu or exists (select 1 from oyun.oturumlar o where o.user_id = p.id)),
      jsonb_build_object('ad', 'Tek hesap (bu cihazda önceden açılmış hesap yok ya da yönetici onaylı)', 'tamam', oyun.suphe(p.id) is null),
      jsonb_build_object('ad', format('En az %s kıdem puanı (her gün maaşını topla: +1)', a.oy_min_kidem), 'tamam', k >= a.oy_min_kidem, 'not', format('Kıdemin: %s', k)),
      jsonb_build_object('ad', format('Seçmen kütüğü: il değiştirdiysen yeni ilinde en az %s gün', a.oy_il_gun), 'tamam', p.son_il_degis is null or p.il_at <= t - make_interval(days => a.oy_il_gun),
                         'not', case when p.son_il_degis is not null and p.il_at > t - make_interval(days => a.oy_il_gun) then 'Bu ilde oy hakkı: ' || to_char((p.il_at + make_interval(days => a.oy_il_gun)) at time zone 'Europe/Istanbul', 'DD.MM') end)),
    'parti_kurma', jsonb_build_object('kidem', oyun.statu_esik(oyun.tf('parti_kurucu_statu')::int), 'kurucu', oyun.parti_kurucu_gerekli(), 'gun', oyun.tf('parti_basvuru_gun'),
                                      'benim_kidem', k, 'ucret', harc + fon, 'harc', harc, 'fon', fon, 'para', (select para from oyun.cuzdanim(p.id)),
                                      'statu', oyun.statu_ad(oyun.tf('parti_kurucu_statu')::int), 'ortak_statu', oyun.statu_ad(oyun.tf('parti_ortak_statu')::int),
                                      'hesap_gun', oyun.tf('parti_kurucu_hesap_gun'), 'ortak_hesap_gun', oyun.tf('parti_ortak_hesap_gun'),
                                      'engel', oyun.parti_kurucu_engel(p, t)));
end $function$;

-- =====================================================================
-- F) FİYAT TARİFESİ (oyuncuya açık, her şey gerçek fonksiyonlardan hesaplanır)
-- =====================================================================
create or replace function public.fiyat_tarifesi()
 returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k numeric; b int; u oyun.ulke; a oyun.ayarlar;
        kil smallint; byk smallint; g jsonb;
        kilitler jsonb := '[["sirket_statu","Şirket ve dükkân kurmak"],["gazete_statu","Gazete kurmak"],["dernek_statu","Dernek kurmak"],["parti_ortak_statu","Parti kurucu üyesi olmak"],["ajans_statu","Reklam ajansı kurmak"],["parti_kurucu_statu","Parti kurma başvurusu"],["banka_statu","Banka kurmak"]]';
begin
  select * into u from oyun.ulke where id = 1;
  select * into a from oyun.ayarlar where id = 1;
  k := coalesce(oyun.kidem_puani(p.id), 0); b := oyun.statu_basamak(k);
  select id into kil from oyun.iller order by mv, id limit 1;
  select id into byk from oyun.iller order by mv desc, id limit 1;
  g := case when p.id is not null then oyun.gelir_hesap(p.id, t) end;
  return jsonb_build_object(
    'endeks', round(u.endeks, 3), 'asgari', u.asgari, 'baslangic', a.baslangic_para,
    'ben', case when p.id is null then null else jsonb_build_object('kidem', floor(k), 'statu', b, 'statu_ad', oyun.statu_ad(b),
       'sonraki_ad', case when b < 5 then oyun.statu_ad(b + 1) end, 'sonraki_esik', case when b < 5 then oyun.statu_esik(b + 1) end,
       'sirket', oyun.sirket_hakki(p.id), 'gunluk_net', (g ->> 'gunluk_net')::numeric, 'para', (select c.para from oyun.cuzdan c where c.user_id = p.id)) end,
    'statuler', (select jsonb_agg(jsonb_build_object('basamak', i, 'ad', oyun.statu_ad(i), 'esik', oyun.statu_esik(i),
        'maas_carpan', round(1 + i * coalesce(u.kidem_primi, 0) / 100.0, 2), 'sirket_hakki', oyun.tf('slot_' || i)::int,
        'acilan', coalesce((select jsonb_agg(e ->> 1) from jsonb_array_elements(kilitler) e where oyun.tf(e ->> 0)::int = i), '[]'::jsonb)) order by i)
      from generate_series(0, 5) i),
    'sektorler', (select jsonb_agg(jsonb_build_object('kod', s.kod, 'ad', s.ad, 'min', s.min_sermaye) order by s.min_sermaye, s.sira) from oyun.pazar_sektor s),
    'kurumlar', jsonb_build_array(
      jsonb_build_object('ad', 'Banka', 'tutar', oyun.tf('banka_min'), 'statu', oyun.statu_ad(oyun.tf('banka_statu')::int), 'not', 'Kuruluş sermayesi; ortaklı kurulabilir'),
      jsonb_build_object('ad', 'Reklam ve anket ajansı', 'tutar', oyun.tf('ajans_min'), 'statu', oyun.statu_ad(oyun.tf('ajans_statu')::int), 'not', 'Kuruluş sermayesi'),
      jsonb_build_object('ad', 'Döviz bürosu / kuyumcu', 'tutar', oyun.tf('meslek_min'), 'statu', oyun.statu_ad(oyun.tf('sirket_statu')::int), 'not', 'Sermaye; 5.000 ₺ ruhsat dahil'),
      jsonb_build_object('ad', 'Hukuk bürosu', 'tutar', 250000, 'statu', null, 'not', 'Baro kaydı gerekir'),
      jsonb_build_object('ad', 'Gazete', 'tutar', oyun.gazete_kur_ucreti(), 'statu', oyun.statu_ad(oyun.tf('gazete_statu')::int), 'not', 'Kuruluş bedeli'),
      jsonb_build_object('ad', 'Dernek', 'tutar', oyun.dernek_harci(), 'statu', oyun.statu_ad(oyun.tf('dernek_statu')::int), 'not', 'Kuruluş harcı'),
      jsonb_build_object('ad', 'Dernek şubesi', 'tutar', oyun.dernek_sube_ucreti(kil), 'en_cok', oyun.dernek_sube_ucreti(byk), 'statu', null, 'not', 'İl büyüklüğüne göre')),
    'parti', jsonb_build_object('kurucu_kurulu', oyun.parti_kurucu_gerekli(), 'harc', greatest(25000, oyun.parti_kur_ucreti()), 'fon', oyun.tf_tl('parti_fon'),
      'kurucu_statu', oyun.statu_ad(oyun.tf('parti_kurucu_statu')::int), 'ortak_statu', oyun.statu_ad(oyun.tf('parti_ortak_statu')::int),
      'kurucu_hesap_gun', oyun.tf('parti_kurucu_hesap_gun'), 'ortak_hesap_gun', oyun.tf('parti_ortak_hesap_gun'), 'bekleme_gun', a.parti_kur_gun,
      'basvuru_gun', oyun.tf('parti_basvuru_gun'), 'oran', oyun.tf('parti_kurucu_oran'), 'en_cok', oyun.tf('parti_kurucu_max'),
      'teskilat', oyun.teskilat_ucreti(kil), 'teskilat_en_cok', oyun.teskilat_ucreti(byk)),
    'siyaset', jsonb_build_array(
      jsonb_build_object('ad', 'Milletvekili aday adaylığı', 'tutar', oyun.aday_ucreti(null, 'mv_on', kil), 'not', 'Partinin kasasına girer; genel başkan çarpanı değiştirebilir'),
      jsonb_build_object('ad', 'Belediye başkanı aday adaylığı', 'tutar', oyun.aday_ucreti(null, 'bel_on', kil), 'en_cok', oyun.aday_ucreti(null, 'bel_on', byk), 'not', 'İl büyüklüğüne göre'),
      jsonb_build_object('ad', 'Genel başkanlık adaylığı', 'tutar', oyun.aday_ucreti(null, 'kurultay', kil), 'not', 'Kurultay'),
      jsonb_build_object('ad', 'Cumhurbaşkanı aday adaylığı', 'tutar', oyun.aday_ucreti(null, 'cb_on', kil), 'not', 'Parti içi ön seçim'),
      jsonb_build_object('ad', 'Miting', 'tutar', oyun.miting_bedel(kil), 'en_cok', oyun.miting_bedel(byk), 'not', 'Sahne, ses, ulaşım'),
      jsonb_build_object('ad', 'Taşınma', 'tutar', oyun.tasinma_ucreti(coalesce(p.il_id, kil), coalesce(p.il_id, kil), t), 'not', format('Devlet desteği %%%s düşülmüş', coalesce(u.tasinma_destek, 0)))),
    'getiri', jsonb_build_array(
      jsonb_build_object('ad', 'Konut ve dükkân kirası', 'oran', oyun.tf('kira_verim'), 'birim', 'hafta', 'not', 'İl taban bedelinin haftalık yüzdesi; önceden alınan mülkler eski kirasıyla devam eder'),
      jsonb_build_object('ad', 'Perakende mağaza günlük brüt kâr tavanı', 'oran', oyun.tf('npc_marj_tavan'), 'birim', 'gün', 'not', 'Sermayenin yüzdesi; kalan talep ildeki rakiplere kalır'),
      jsonb_build_object('ad', 'Şirketler arası fatura geliri tavanı', 'oran', oyun.tf('b2b_tavan'), 'birim', 'gün', 'not', 'Enerji, ulaşım, medya: sermayenin yüzdesi'),
      jsonb_build_object('ad', 'İkinci ve sonraki makam maaşı', 'oran', oyun.tf('makam_ek_oran'), 'birim', 'tam maaşın', 'not', 'En yüksek makam maaşı tam ödenir')),
    'reklam_odul', (g ->> 'reklam_odul')::numeric);
end $function$;

-- =====================================================================
-- G) ZAMANLAYICI, YETKİLER, BİR KERELİK DUYURU
-- =====================================================================
do $zam$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira)
    select 'kurucu_suresi', 'select oyun.kurucu_suresi_dolan()', 15, 4, 49
     where not exists (select 1 from oyun.zamanlayici_adim z where z.adim = 'kurucu_suresi');
  end if;
end $zam$;

revoke all on function oyun.kurucu_iade(bigint, uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function oyun.kurucu_basvuru_kapat(bigint, text, text, timestamptz) from public, anon, authenticated;
revoke all on function oyun.kurucu_suresi_dolan() from public, anon, authenticated;
do $$ declare s text; begin
  foreach s in array array['kurucu_katki(bigint,numeric)', 'fiyat_tarifesi()', 'parti_kur_baslat(text,text,text,text,text[],text[])',
    'kurucu_davet_yanit(bigint,boolean)', 'kurucu_davet_ekle(bigint,text[])', 'kurucu_davetlerim()', 'parti_kur_iptal(bigint)',
    'parti_kur_tamamla(bigint)', 'vatandaslik()', 'meslek_dukkan_ac(text,text,numeric)', 'ajans_kur(text,numeric)'] loop
    execute format('revoke all on function public.%s from public, anon', s);
    execute format('grant execute on function public.%s to authenticated', s);
  end loop;
end $$;

do $$
declare t timestamptz := oyun.simdi(); r record; metin text; harc numeric; fon numeric; gerek int;
begin
  insert into oyun.tek_seferlik(anahtar, zaman) values ('uzun_soluklu_ekonomi_151_duyuru', t) on conflict do nothing;
  if not found then return; end if;
  if not exists(select 1 from oyun.profiller where not yasakli) then return; end if;
  harc := greatest(25000, oyun.parti_kur_ucreti()); fon := oyun.tf_tl('parti_fon'); gerek := oyun.parti_kurucu_gerekli();
  metin := format('Resmî duyuru · Uzun Soluklu Ekonomi düzenlemesi yürürlükte. Fiyatlar ve getiriler aylarca sürecek bir oyuna göre yeniden ayarlandı: '
    || 'statün yükseldikçe yeni şirket hakkı açılır (Vatandaş 1, Saygın Vatandaş 2, Kanaat Önderi 3, Duayen 5, Yaşayan Efsane 8 şirket); '
    || 'şirket sermayesi sektöre göre 200 bin – 2,5 milyon ₺, banka 15 milyon ₺. Parti kurmak artık ekip işi: sen dahil en az %s kişilik kurucular kurulu, '
    || '%s ₺ harç ve %s ₺ kuruluş fonu (partinin kasasına geçer, kurucular birlikte toplar). Şirketlerin, mülklerin, partilerin ve paran aynen korunur. '
    || 'Bütün fiyatlar ve statü hakları: Resmî Gazete ve Ekonomi › Fiyat Tarifesi.', gerek, oyun.tl(harc), oyun.tl(fon));
  for r in select p.id from oyun.profiller p where not p.yasakli loop
    perform oyun.bildir(r.id, metin, t);
  end loop;
  perform oyun.gazete_ekle('duyuru', 'Uzun Soluklu Ekonomi: fiyat merdiveni, statü hakları ve kurucular kurulu', format(
    'Oyunun aylarca ve yıllarca dengeli kalması için fiyatlar ve getiriler yeniden düzenlenmiştir. '
    || '(1) Statü hakları: Şirket, gazete ve dernek kurmak "Vatandaş" (10 kıdem), reklam ajansı ve parti başvurusu "Saygın Vatandaş" (30), banka "Kanaat Önderi" (75) statüsü ister. Aynı anda sahibi olunabilecek şirket sayısı statüyle artar: 0, 1, 2, 3, 5, 8. Kıdem her gün maaşı toplamakla, oy kullanmakla ve etkinliklere katılmakla artar; düzenli oynayan daha hızlı ilerler. '
    || '(2) Kuruluş sermayeleri: küçük işletmeler (ticaret, teknoloji, sanayi, inşaat, medya, tarım, danışmanlık, oto servis) 200.000 ₺; orta ölçekli işletmeler 500.000 ₺; özel hastane ve akaryakıt 1.000.000 ₺; enerji 1.500.000 ₺; otomobil galerisi 2.500.000 ₺; reklam ajansı 400.000 ₺; banka 15.000.000 ₺. Gazete %s ₺, dernek %s ₺. '
    || '(3) Getiriler: pazar şirketlerinin kapasitesi ve sabit giderleri gerçekçi düzeye çekildi (iyi yönetilen şirket haftada sermayesinin yaklaşık %%7-13''ünü kazanır). Perakende mağazalar günde sermayelerinin %%2,5''inden fazla brüt kâr edemez; akaryakıt, giyim, mobilya, elektronik ve yapı malzemesi talebi artırıldı. Şirketler arası fatura geliri günde sermayenin %%1,2''siyle sınırlıdır. Yeni alınan konut ve dükkânların kirası il taban bedelinin haftalık %%2''sidir; önceden alınanlar eski kirasıyla devam eder. '
    || '(4) Makam maaşı: Birden fazla makamı olan en yüksek makamın maaşını tam, diğerlerinin %%25''ini alır (Meclis Başkanlığı ve başkanvekilliği tazminatları tam ödenir). '
    || '(5) Parti kuruluşu: Sen dahil en az %s kişilik kurucular kurulu (aktif oyuncuların %%2''si, en çok 30). Başvuran 14, kurucu üyeler 7 günlük hesap ister; aynı cihazdaki hesaplar aynı kurulda yer alamaz. Kuruluş %s ₺ harç ile %s ₺ kuruluş fonu gerektirir; fonu kurucular birlikte toplar, parti kurulunca kasasına geçer, kurulmazsa herkese iade edilir. İki kuruluş arasında 90 gün beklenir. İl teşkilatı il büyüklüğüne göre %s – %s ₺. '
    || '(6) Aday adaylığı: milletvekili %s ₺, belediye başkanı %s – %s ₺, genel başkanlık %s ₺, cumhurbaşkanı %s ₺ (partinin kasasına girer). Yeni oyuncular %s ₺ ile başlar. '
    || 'Mevcut şirketler, mülkler, partiler ve bakiyeler korunmuştur. Bütün fiyatlar: Ekonomi › Fiyat Tarifesi.',
    oyun.tl(oyun.gazete_kur_ucreti()), oyun.tl(oyun.dernek_harci()), gerek, oyun.tl(harc), oyun.tl(fon),
    oyun.tl(oyun.teskilat_ucreti((select id from oyun.iller order by mv, id limit 1))), oyun.tl(oyun.teskilat_ucreti((select id from oyun.iller order by mv desc, id limit 1))),
    oyun.tl(oyun.aday_ucreti(null, 'mv_on', null)), oyun.tl(oyun.aday_ucreti(null, 'bel_on', (select id from oyun.iller order by mv, id limit 1))),
    oyun.tl(oyun.aday_ucreti(null, 'bel_on', (select id from oyun.iller order by mv desc, id limit 1))),
    oyun.tl(oyun.aday_ucreti(null, 'kurultay', null)), oyun.tl(oyun.aday_ucreti(null, 'cb_on', null)),
    oyun.tl((select baslangic_para from oyun.ayarlar where id = 1))), null, t);
  perform oyun.olay('ekonomi', format('Uzun Soluklu Ekonomi düzenlemesi yürürlüğe girdi: statüye bağlı şirket hakları, sektöre göre kuruluş sermayeleri ve en az %s kişilik kurucular kuruluyla parti kuruluşu.', gerek), null, null, t);
end $$;
