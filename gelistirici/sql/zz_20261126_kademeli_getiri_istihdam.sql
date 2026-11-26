-- 26.11.2026 · KADEMELİ GETİRİ + İSTİHDAM + PATRON ÜRÜNLERİ — sürüm 2026.11.26-12
-- İstek (Ercan): X'teki oyuncu eleştirisi — "400-500 bin yatırıyorum, günde 4 bin geliyor; vakti olan insanlar
--   ekonomide yer bulamadığı için birbirine sarıyor." → "Hem gerçek parayla oyun parası almalarını hem de
--   eleştirileri kaldırmayı kapsayan bir kazanç sistemi kur." → öneriyi onayladı ("Hepsini uygula").
-- Canlı ölçüm (26.11): olgunlukta şirketlerin yarısı günde ≤ %1 net; kendini ortalama 85 günde çıkarıyor,
--   küçük sanayi 170-420 gün. 400 binlik para paketi (en çok satan) şirkete konunca günde 4-6 bin; aynı gün
--   5 ücretsiz ek iş 12.500 ₺'ye kadar. 847 aktif oyuncudan yalnız 48'i şirket sahibi.
--
-- 1) KADEMELİ GETİRİ (oyuncu başına, şirket başına değil). Oyuncunun şirketlerdeki toplam pay sermayesine göre
--    hedef günlük NET getiri: ilk 500 bin %2,5 · 500 bin-2 milyon %1,2 · 2-5 milyon %0,6 · üstü %0,3.
--    Şirketin kazanç tavanı (pazar_tahmin_ic, sd_npc_marj_tavan, sd_perakende_tavan) artık ortaklarının
--    dilimlerinin pay ağırlıklı ortalamasından gelir (oyun.kg_tavan_yuzde); eski denge tavanından AŞAĞI inmez
--    (greatest) → kimsenin tavanı düşmez. Pozitif vergi öncesi kâr "verimlilik" (kg_ayar.verim, 2,3) ile
--    çarpılıp tavana sıkıştırılır: iyi yönetilen şirket hedefe yaklaşır, zarar eden şirket zararda kalır.
--    Şirketi bölmek işe yaramaz (dilim kişiye göre). Ayarlar oyun.kg_ayar; portal › Ekonomi.
-- 2) İSTİHDAM: şirketler gerçek oyuncuları işe alır (ilan → başvuru → kabul). Çalışan günde bir kez "mesai"
--    yapar (günlük 5 ek iş hakkından birini kullanır, yeni angarya yok); maaşı şirket kasasından anında alır.
--    Şirket kasasına katma değer = min(maaş, piyasa ücreti) × 1,35 girer (piyasa ücretini aşan maaş yalnız
--    patrondan çalışana aktarımdır, para basmaz). Kontenjan 1 + her 200 bin sermayede 1, en çok 10. Ortak,
--    kurucu, yönetici ve onlarla aynı cihazı kullanan hesap çalışan olamaz. 7 gün mesai yoksa sözleşme biter.
-- 3) MAĞAZA: "Hızlı Açılış Belgesi" (jeton: şirket merkezinin kuruluş dönemini 9 gün kısaltır) ve
--    "Patron Kartı · 30 gün" (ilk dilim 500 bin → 750 bin). İkisi de aktif=false eklenir; App Store Connect ve
--    Google Play'de aynı kimlikle ürün oluşturulunca portaldan açılır. magaza_durum'a 'getiri' (para paketini
--    şirkete koyarsan tahmini günlük ek getiri), 'patron', 'kademe' alanları eklenir (eski uygulama yok sayar).
-- 4) Bir kerelik: şirket ortaklarına "Kademeli Getiri" bildirimi.
-- Oyuncu verisi DEĞİŞMEZ (yalnız tablo/sütun/işlev eklenir); tekrar çalıştırmak güvenlidir (_yama işaretli).

-- ============ AYARLAR ============
create table if not exists oyun.kg_ayar (
  id int primary key default 1 check (id = 1),
  aktif boolean not null default true,
  d1_sinir numeric not null default 500000,  d1_oran numeric not null default 2.5,
  d2_sinir numeric not null default 2000000, d2_oran numeric not null default 1.2,
  d3_sinir numeric not null default 5000000, d3_oran numeric not null default 0.6,
  d4_oran numeric not null default 0.3,
  verim numeric not null default 2.3,
  patron_ek numeric not null default 250000,
  patron_gun int not null default 30,
  hizli_gun numeric not null default 9,
  ist_acik boolean not null default true,
  maas_taban numeric not null default 1500,
  maas_tavan numeric not null default 20000,
  piyasa_ucret numeric not null default 2500,
  katma_kat numeric not null default 1.35,
  kontenjan_birim numeric not null default 200000,
  kontenjan_max int not null default 10,
  pasif_gun int not null default 7,
  min_hesap_gun int not null default 3,
  basvuru_max int not null default 3,
  guncelleme timestamptz not null default now()
);
insert into oyun.kg_ayar(id) values (1) on conflict (id) do nothing;
revoke all on oyun.kg_ayar from public, anon, authenticated;

alter table oyun.magaza_hesap add column if not exists patron_bitis timestamptz;

create or replace function oyun.kg_a() returns oyun.kg_ayar
language sql stable set search_path = '' as $$ select * from oyun.kg_ayar where id = 1 $$;

create or replace function oyun.kg_patron(u uuid, t timestamptz default null) returns boolean
language sql stable set search_path = '' as $$
  select coalesce((select h.patron_bitis > coalesce(t, oyun.simdi()) from oyun.magaza_hesap h where h.user_id = u), false)
$$;

-- Toplam pay sermayesi p_t için hedef GÜNLÜK NET getiri (₺). p_d1: ilk dilimin sınırı (Patron Kartı genişletir).
create or replace function oyun.kg_gunluk(p_t numeric, p_d1 numeric, a oyun.kg_ayar) returns numeric
language sql immutable set search_path = '' as $$
  select round((
      least(greatest(coalesce(p_t, 0), 0), p_d1) * a.d1_oran
    + greatest(0, least(p_t, greatest(a.d2_sinir, p_d1)) - p_d1) * a.d2_oran
    + greatest(0, least(p_t, greatest(a.d3_sinir, p_d1)) - greatest(a.d2_sinir, p_d1)) * a.d3_oran
    + greatest(0, p_t - greatest(a.d3_sinir, p_d1)) * a.d4_oran) / 100, 2)
$$;

create or replace function oyun.kg_d1(u uuid, a oyun.kg_ayar) returns numeric
language sql stable set search_path = '' as $$
  select a.d1_sinir + case when oyun.kg_patron(u) then a.patron_ek else 0 end
$$;

-- Oyuncunun faal şirketlerdeki pay sermayesi; p_sirket'e p_ek eklenirse oyuncunun payı kadarı dahil edilir.
create or replace function oyun.kg_kisi_sermaye(u uuid, p_sirket bigint default null, p_ek numeric default 0) returns numeric
language sql stable set search_path = '' as $$
  select coalesce((select sum(greatest(s.sermaye, 0) * o.pay / 100)
                     from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id
                    where o.user_id = u and o.pay > 0 and s.aktif), 0)
       + coalesce((select greatest(coalesce(p_ek, 0), 0) * o2.pay / 100
                     from oyun.sirket_ortaklari o2 where o2.sirket_id = p_sirket and o2.user_id = u and o2.pay > 0), 0)
$$;

-- Oyuncunun ortalama hedef günlük net getirisi (yüzde).
create or replace function oyun.kg_kisi_oran(u uuid, p_sirket bigint default null, p_ek numeric default 0) returns numeric
language plpgsql stable set search_path = '' as $$
declare a oyun.kg_ayar := oyun.kg_a(); tt numeric;
begin
  tt := oyun.kg_kisi_sermaye(u, p_sirket, p_ek);
  if tt <= 0 then return a.d1_oran; end if;
  return oyun.kg_gunluk(tt, oyun.kg_d1(u, a), a) * 100 / tt;
end $$;

-- Şirketin haftalık VERGİ ÖNCESİ kazanç tavanı yüzdesi (sermayeye oranla). Kapalıysa ya da eski tavan
-- daha yüksekse eski değer döner: kimsenin tavanı düşmez.
create or replace function oyun.kg_tavan_yuzde(p_sirket bigint, p_eski numeric, p_ek numeric default 0) returns numeric
language plpgsql stable set search_path = '' as $$
declare a oyun.kg_ayar := oyun.kg_a(); r numeric := 0; ptop numeric := 0; x record; kv numeric;
begin
  if a.id is null or not a.aktif then return p_eski; end if;
  for x in select o.user_id, o.pay from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.pay > 0 loop
    r := r + x.pay / 100 * oyun.kg_kisi_oran(x.user_id, p_sirket, p_ek);
    ptop := ptop + x.pay;
  end loop;
  if ptop < 100 then r := r + (100 - greatest(ptop, 0)) / 100 * a.d2_oran; end if;
  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), (select pa.kurumlar from oyun.pazar_ayar pa where pa.id = 1), 25);
  return greatest(coalesce(p_eski, 0), r * 7 / greatest(0.3, 1 - kv / 100));
end $$;

create or replace function oyun.kg_verim() returns numeric
language sql stable set search_path = '' as $$
  select coalesce((select case when a.aktif then greatest(1, a.verim) else 1 end from oyun.kg_ayar a where a.id = 1), 1)
$$;

-- ============ PAZAR TAHMİNİ VE TAVAN YAMALARI (canlı tanım üstüne; işaretli, tekrar çalışmaz) ============
select oyun._yama('oyun.pazar_tahmin_ic(bigint,smallint,smallint,text,timestamptz,numeric)',
  'gecis numeric := 0; gecis_g numeric := 0; kv_e numeric;',
  'gecis numeric := 0; gecis_g numeric := 0; kv_e numeric; /*KG1*/ kg_y numeric; kg_v numeric := 1;', '/*KG1*/', true);
select oyun._yama('oyun.pazar_tahmin_ic(bigint,smallint,smallint,text,timestamptz,numeric)',
  $e$tavan := k_merkez * tavan_yuzde / 100 * olgun + coalesce((v_sube->>'tavan')::numeric, 0);$e$,
  $y$/*KG2*/ kg_y := oyun.kg_tavan_yuzde(s.id, tavan_yuzde, greatest(0, coalesce(p_ek_sermaye, 0))); kg_v := oyun.kg_verim();
    tavan := k_merkez * kg_y / 100 * olgun + coalesce((v_sube->>'tavan')::numeric, 0) * kg_y / greatest(tavan_yuzde, 0.01);
    tavan_yuzde := kg_y;$y$, '/*KG2*/', true);
select oyun._yama('oyun.pazar_tahmin_ic(bigint,smallint,smallint,text,timestamptz,numeric)',
  'if ham_brut > 0 then olcek := oyun.sd_sikistir(ham_brut, tavan, da.serbest) / ham_brut; end if;',
  'if ham_brut > 0 then olcek := oyun.sd_sikistir(ham_brut * kg_v, tavan, da.serbest) / ham_brut; end if; /*KG3*/', '/*KG3*/', true);
select oyun._yama('oyun.pazar_tahmin_ic(bigint,smallint,smallint,text,timestamptz,numeric)',
  $e$'kurulus_destek', round(destek), 'verim_not', v_not);$e$,
  $y$'kurulus_destek', round(destek), 'verim_not', v_not)
    || jsonb_build_object('kademe_yuzde', round(coalesce(kg_y, 0), 2), 'kademe_verim', kg_v) /*KG4*/;$y$, '/*KG4*/', true);
select oyun._yama('oyun.sd_npc_marj_tavan(bigint,timestamptz)',
  'oyun.sd_tavan_yuzde(s.sermaye, a)', 'oyun.kg_tavan_yuzde(s.id, oyun.sd_tavan_yuzde(s.sermaye, a)) /*KG5*/', '/*KG5*/', true);
select oyun._yama('oyun.sd_perakende_tavan(bigint,timestamptz)',
  'oyun.sd_tavan_yuzde(s.sermaye, a)', 'oyun.kg_tavan_yuzde(s.id, oyun.sd_tavan_yuzde(s.sermaye, a)) /*KG5*/', '/*KG5*/', true);

-- ============ ÖZET (şirket ekranı ve mağaza için) ============
create or replace function oyun.kg_ozet(u uuid) returns jsonb
language plpgsql stable set search_path = '' as $$
declare a oyun.kg_ayar := oyun.kg_a(); tt numeric; d1 numeric; g numeric; da oyun.sirket_denge_ayar := oyun.sd_ayar(); t timestamptz := oyun.simdi();
begin
  tt := oyun.kg_kisi_sermaye(u); d1 := oyun.kg_d1(u, a); g := oyun.kg_gunluk(tt, d1, a);
  return jsonb_build_object(
    'aktif', coalesce(a.aktif, false), 'verim', a.verim,
    'sermaye', round(tt), 'gunluk_hedef', round(g), 'oran', case when tt > 0 then round(g * 100 / tt, 2) else a.d1_oran end,
    'dilimler', jsonb_build_array(
      jsonb_build_object('alt', 0, 'ust', d1, 'oran', a.d1_oran),
      jsonb_build_object('alt', d1, 'ust', greatest(a.d2_sinir, d1), 'oran', a.d2_oran),
      jsonb_build_object('alt', greatest(a.d2_sinir, d1), 'ust', greatest(a.d3_sinir, d1), 'oran', a.d3_oran),
      jsonb_build_object('alt', greatest(a.d3_sinir, d1), 'ust', null, 'oran', a.d4_oran)),
    'ilk_dilim_kalan', round(greatest(0, d1 - tt)),
    'patron', jsonb_build_object('aktif', oyun.kg_patron(u), 'bitis', (select h.patron_bitis from oyun.magaza_hesap h where h.user_id = u), 'ek', a.patron_ek),
    'hizli_jeton', coalesce((select j.adet from oyun.magaza_jeton j where j.user_id = u and j.kod = 'hizli_acilis'), 0),
    'hizli_gun', a.hizli_gun,
    'sirketler', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'sermaye', s.sermaye, 'pay', o.pay,
        'olgunluk', round(100 * case when coalesce(da.aktif, false)
            then oyun.sd_olgunluk_h(coalesce((select d.olgun_bas from oyun.sirket_denge_durum d where d.sirket_id = s.id), s.kurulus), t, da.olgun_bas, da.olgun_gun)
            else 1 end)) order by s.sermaye desc)
      from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id where o.user_id = u and o.pay > 0 and s.aktif), '[]'::jsonb));
end $$;

create or replace function public.kademe_ozet() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  return oyun.kg_ozet(p.id);
end $$;

-- Mağaza ekleri: para paketini şirkete koyarsa olgunlukta tahmini günlük EK getiri (hedefin %90'ı, 100'e yuvarlı).
create or replace function oyun.kg_magaza_ek(u uuid) returns jsonb
language plpgsql stable set search_path = '' as $$
declare a oyun.kg_ayar := oyun.kg_a(); tt numeric; d1 numeric; g0 numeric; r jsonb := '{}'::jsonb; k record;
begin
  if a.id is null then return '{}'::jsonb; end if;
  tt := oyun.kg_kisi_sermaye(u); d1 := oyun.kg_d1(u, a); g0 := oyun.kg_gunluk(tt, d1, a);
  if a.aktif then
    for k in select p.urun_id, p.miktar from oyun.paketler p where p.aktif and p.miktar > 0 loop
      r := r || jsonb_build_object(k.urun_id, round((oyun.kg_gunluk(tt + k.miktar, d1, a) - g0) * 0.9 / 100) * 100);
    end loop;
  end if;
  return jsonb_build_object('getiri', r,
    'patron', jsonb_build_object('aktif', oyun.kg_patron(u), 'bitis', (select h.patron_bitis from oyun.magaza_hesap h where h.user_id = u), 'ek', a.patron_ek, 'gun', a.patron_gun),
    'kademe', jsonb_build_object('aktif', a.aktif, 'sermaye', round(tt), 'gunluk_hedef', round(g0), 'ilk_dilim', d1, 'ilk_oran', a.d1_oran));
end $$;

select oyun._yama('public.magaza_durum()',
  $e$'para', \(select para from oyun\.cuzdan where user_id = p\.id\)\s*\);$e$,
  $y$'para', (select para from oyun.cuzdan where user_id = p.id)
  ) || oyun.kg_magaza_ek(p.id) /*KG6*/;$y$, '/*KG6*/', false);

-- Mağaza uygulaması: Patron Kartı jetonu süre olarak işlenir (Siyaset Kartı süresine dokunmaz).
create or replace function oyun.magaza_uygula(u uuid, pk oyun.paketler, isaret integer, t timestamp with time zone)
 returns numeric
 language plpgsql
 set search_path to 'oyun', 'public', 'extensions', 'pg_temp'
as $function$
declare dus numeric := 0; pg int := coalesce((select patron_gun from oyun.kg_ayar where id = 1), 30);
begin
  if isaret > 0 then
    if pk.miktar > 0 then perform oyun.para_islem(u, pk.miktar, 'satin_alma', pk.ad || ' (satın alma)', t); end if;
    if pk.gun > 0 then
      insert into oyun.magaza_hesap(user_id, kart_bitis) values (u, t + make_interval(days => pk.gun))
      on conflict (user_id) do update
        set kart_bitis = greatest(coalesce(oyun.magaza_hesap.kart_bitis, t), t) + make_interval(days => pk.gun);
    end if;
    if pk.tur = 'paket' then
      insert into oyun.magaza_hesap(user_id, baslangic_alindi) values (u, true)
      on conflict (user_id) do update set baslangic_alindi = true;
    end if;
    if pk.tur = 'jeton' and pk.hak = 'patron_karti' then
      insert into oyun.magaza_hesap(user_id, patron_bitis) values (u, t + make_interval(days => pg))
      on conflict (user_id) do update
        set patron_bitis = greatest(coalesce(oyun.magaza_hesap.patron_bitis, t), t) + make_interval(days => pg);
      perform oyun.bildir(u, format('Patron Kartın aktif: %s gün boyunca kademeli getirinin ilk dilimi %s ₺ yerine %s ₺.', pg,
        oyun.tl((select d1_sinir from oyun.kg_ayar where id = 1)),
        oyun.tl((select d1_sinir + patron_ek from oyun.kg_ayar where id = 1))), t);
    elsif pk.tur = 'jeton' and pk.hak is not null then
      insert into oyun.magaza_jeton(user_id, kod, adet) values (u, pk.hak, 1)
      on conflict (user_id, kod) do update set adet = oyun.magaza_jeton.adet + 1;
    elsif pk.hak is not null then
      insert into oyun.oyuncu_hak(user_id, hak, kaynak, aktif, zaman) values (u, pk.hak, 'satin_alma', true, t)
      on conflict (user_id, hak) do update set aktif = true, kaynak = 'satin_alma', zaman = t;
      if pk.hak = 'parti_kimlik' then perform oyun.parti_kimlik_uygula(u); end if;
    end if;
  else
    if pk.miktar > 0 then
      perform oyun.cuzdanim(u);
      dus := least(pk.miktar, greatest((select para from oyun.cuzdan where user_id = u), 0));
      if dus > 0 then perform oyun.para_islem(u, -dus, 'iade', 'Mağaza iadesi: ' || pk.ad, t); end if;
    end if;
    if pk.gun > 0 then
      update oyun.magaza_hesap set kart_bitis = kart_bitis - make_interval(days => pk.gun) where user_id = u and kart_bitis is not null;
    end if;
    if pk.tur = 'jeton' and pk.hak = 'patron_karti' then
      update oyun.magaza_hesap set patron_bitis = patron_bitis - make_interval(days => pg) where user_id = u and patron_bitis is not null;
    elsif pk.tur = 'jeton' and pk.hak is not null then
      update oyun.magaza_jeton set adet = adet - 1 where user_id = u and kod = pk.hak and adet > 0;
    elsif pk.hak is not null then
      update oyun.oyuncu_hak set aktif = false, zaman = t where user_id = u and hak = pk.hak;
      if pk.hak = 'parti_kimlik' then update oyun.partiler set kimlik_alan = null where kimlik_alan = u; end if;
      if pk.hak = 'imza' then update oyun.oyuncu_gorunum set unvan = null where user_id = u; end if;
    end if;
  end if;
  return dus;
end $function$;

-- Yeni ürünler (mağazada ürün oluşturulana kadar kapalı). on conflict: fiyat/aktif portaldan değişmişse korunur.
insert into oyun.paketler(urun_id, ad, miktar, sira, tur, gun, hak, aciklama, etiket, fiyat, aktif) values
 ('secimonline.business_fast_start', 'Hızlı Açılış Belgesi', 0, 31, 'jeton', 0, 'hizli_acilis',
  'Şirketinin kuruluş dönemini 9 gün kısaltır; kazancı hemen yükselir. Şirket ekranındaki Kademeli Getiri kartından kullanılır.', 'Şirket', '₺49,99', false),
 ('secimonline.boss_card_30d', 'Patron Kartı · 30 gün', 0, 3, 'jeton', 0, 'patron_karti',
  '30 gün boyunca kademeli getirinin en kârlı ilk dilimi 500 bin yerine 750 bin ₺. Süre üstüne eklenir.', 'Şirket sahipleri için', '₺149,99', false)
on conflict (urun_id) do nothing;

-- Hızlı Açılış Belgesi kullan.
create or replace function public.hizli_acilis_kullan(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kg_ayar := oyun.kg_a(); da oyun.sirket_denge_ayar := oyun.sd_ayar();
  s oyun.sirketler; d oyun.sirket_denge_durum; t timestamptz := oyun.simdi(); o1 numeric; o2 numeric; yeni timestamptz;
begin
  select * into s from oyun.sirketler where id = p_sirket for update;
  if s.id is null or not s.aktif then raise exception 'Şirket bulunamadı ya da faaliyette değil.'; end if;
  if not exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = p.id and o.pay > 0)
     and s.kurucu is distinct from p.id and s.yonetici is distinct from p.id then
    raise exception 'Hızlı Açılış Belgesini yalnız şirketin ortağı ya da yöneticisi kullanabilir.';
  end if;
  if not coalesce(da.aktif, false) then raise exception 'Kuruluş dönemi şu an uygulanmıyor; belgeye gerek yok.'; end if;
  insert into oyun.sirket_denge_durum(sirket_id, sermaye_iz, olgun_bas) values (s.id, s.sermaye, s.kurulus) on conflict (sirket_id) do nothing;
  select * into d from oyun.sirket_denge_durum where sirket_id = s.id for update;
  o1 := oyun.sd_olgunluk_h(coalesce(d.olgun_bas, s.kurulus), t, da.olgun_bas, da.olgun_gun);
  if o1 >= 0.995 then raise exception 'Bu şirket zaten tam kapasitede; belgeyi kuruluş dönemindeki bir şirketinde kullan.'; end if;
  update oyun.magaza_jeton set adet = adet - 1 where user_id = p.id and kod = 'hizli_acilis' and adet > 0;
  if not found then raise exception 'Hızlı Açılış Belgen yok. Mağaza › Hizmetler''den alabilirsin.'; end if;
  yeni := coalesce(d.olgun_bas, s.kurulus) - make_interval(secs => (a.hizli_gun * 86400)::double precision);
  update oyun.sirket_denge_durum set olgun_bas = yeni where sirket_id = s.id;
  o2 := oyun.sd_olgunluk_h(yeni, t, da.olgun_bas, da.olgun_gun);
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama)
    values (s.id, t, 0, format('Hızlı Açılış Belgesi kullanıldı: kuruluş verimi %%%s → %%%s', round(o1 * 100), round(o2 * 100)));
  return jsonb_build_object('once', round(o1 * 100), 'sonra', round(o2 * 100),
    'kalan', coalesce((select j.adet from oyun.magaza_jeton j where j.user_id = p.id and j.kod = 'hizli_acilis'), 0));
end $$;

-- ============ İSTİHDAM ============
create table if not exists oyun.istihdam_ilan (
  id bigint generated always as identity primary key,
  sirket_id bigint not null unique references oyun.sirketler(id) on delete cascade,
  maas numeric not null check (maas > 0),
  kontenjan int not null check (kontenjan between 1 and 50),
  aciklama text not null default '',
  acik boolean not null default true,
  olusturma timestamptz not null default now(),
  guncelleme timestamptz not null default now(),
  veren uuid
);
alter table oyun.istihdam_ilan add column if not exists kasa_uyari timestamptz;
create table if not exists oyun.istihdam_basvuru (
  id bigint generated always as identity primary key,
  ilan_id bigint not null references oyun.istihdam_ilan(id) on delete cascade,
  sirket_id bigint not null,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  zaman timestamptz not null default now(),
  mesaj text not null default '',
  durum text not null default 'bekliyor' check (durum in ('bekliyor','kabul','ret','geri','kapandi')),
  karar_zaman timestamptz
);
create unique index if not exists istihdam_basvuru_tek on oyun.istihdam_basvuru(ilan_id, user_id) where durum = 'bekliyor';
create index if not exists istihdam_basvuru_kisi on oyun.istihdam_basvuru(user_id, durum);
create index if not exists istihdam_basvuru_sirket on oyun.istihdam_basvuru(sirket_id, durum);
create table if not exists oyun.istihdam (
  id bigint generated always as identity primary key,
  sirket_id bigint not null references oyun.sirketler(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  maas numeric not null check (maas > 0),
  baslama timestamptz not null default now(),
  bitis timestamptz,
  durum text not null default 'aktif' check (durum in ('aktif','ayrildi','cikarildi','sona_erdi')),
  son_mesai date,
  mesai_sayi int not null default 0,
  toplam_maas numeric not null default 0,
  toplam_katma numeric not null default 0
);
create unique index if not exists istihdam_tek_aktif on oyun.istihdam(user_id) where durum = 'aktif';
create index if not exists istihdam_sirket_aktif on oyun.istihdam(sirket_id) where durum = 'aktif';
create table if not exists oyun.istihdam_mesai (
  id bigint generated always as identity primary key,
  istihdam_id bigint not null references oyun.istihdam(id) on delete cascade,
  sirket_id bigint not null,
  user_id uuid not null,
  gun date not null,
  zaman timestamptz not null default now(),
  maas numeric not null,
  katma numeric not null,
  vergi numeric not null default 0
);
create unique index if not exists istihdam_mesai_gun on oyun.istihdam_mesai(user_id, gun);
create index if not exists istihdam_mesai_sirket on oyun.istihdam_mesai(sirket_id, gun);
revoke all on oyun.istihdam_ilan, oyun.istihdam_basvuru, oyun.istihdam, oyun.istihdam_mesai from public, anon, authenticated;

-- Mesai bir ek iş hakkı kullanır: ek iş kaydı bu (listede görünmeyen, başlatılamayan) katalog satırıyla yazılır.
insert into oyun.ek_is_katalog(kod, ad, simge, aciklama, sure_dakika, asgari_ucret, azami_ucret, sira, aktif, kategori, min_kidem, silindi)
values ('mesai', 'Şirkette mesai', '🏢', 'İşe alındığın şirketteki günlük mesai (İş İlanları ekranından).', 15, 1, 1, 999, false, 'diger', 0, true)
on conflict (kod) do nothing;
insert into oyun.kidem_kaynak(kod, ad, puan, gunluk_tavan, sira) values ('mesai', 'Şirkette mesai yapmak', 0.5, 0.5, 40)
on conflict (kod) do nothing;

create or replace function oyun.ist_uygunsuz(p text) returns boolean
language plpgsql stable set search_path = '' as $$
declare r boolean := false;
begin
  if to_regprocedure('oyun.kufurlu(text)') is not null then execute 'select oyun.kufurlu($1)' into r using p; end if;
  return coalesce(r, false);
end $$;

create or replace function oyun.ist_ad(u uuid) returns text
language sql stable set search_path = '' as $$
  select coalesce(nullif(btrim(p.ad_soyad), ''), p.kad) from oyun.profiller p where p.id = u
$$;

create or replace function oyun.ist_kontenjan(p_sirket bigint) returns int
language sql stable set search_path = '' as $$
  select least(a.kontenjan_max, 1 + floor(greatest(0, s.sermaye) / greatest(1, a.kontenjan_birim))::int)
  from oyun.sirketler s, oyun.kg_ayar a where s.id = p_sirket and a.id = 1
$$;

create or replace function oyun.ist_yetkili(p_sirket bigint, u uuid) returns boolean
language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.sirketler s where s.id = p_sirket and s.aktif and (s.kurucu = u or s.yonetici = u))
      or exists (select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id
                  where o.sirket_id = p_sirket and o.user_id = u and o.pay >= 50 and s.aktif)
      or coalesce((select p.yonetici from oyun.profiller p where p.id = u), false)
$$;

-- Çalışan, şirketin ortağı/kurucusu/yöneticisi ya da onlarla aynı cihazı kullanan biri olamaz.
create or replace function oyun.ist_engel(p_sirket bigint, u uuid) returns text
language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif then return 'Şirket faaliyette değil.'; end if;
  if s.kurucu = u or s.yonetici = u or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = u and o.pay > 0) then
    return 'Ortağı ya da yöneticisi olduğun şirkette çalışan olamazsın.';
  end if;
  if exists (select 1 from oyun.oturumlar a join oyun.oturumlar b on b.cihaz = a.cihaz
              where a.user_id = u and coalesce(a.cihaz, '') <> '' and b.user_id <> u
                and (b.user_id = s.kurucu or b.user_id = s.yonetici
                     or b.user_id in (select o.user_id from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.pay > 0))) then
    return 'Bu şirketin sahipleriyle aynı cihazı kullanıyorsun; bu şirkette çalışamazsın.';
  end if;
  return null;
end $$;

create or replace function oyun.ist_bildir_yetkililer(p_sirket bigint, p_metin text, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare x record;
begin
  for x in select distinct u from (
      select s.kurucu u from oyun.sirketler s where s.id = p_sirket
      union select s.yonetici from oyun.sirketler s where s.id = p_sirket and s.yonetici is not null
      union select o.user_id from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.pay >= 50) q where u is not null loop
    perform oyun.bildir(x.u, p_metin, t);
  end loop;
end $$;

create or replace function oyun.ist_bitir(p_id bigint, p_durum text, p_neden text, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare i oyun.istihdam; s_ad text;
begin
  update oyun.istihdam set durum = p_durum, bitis = t where id = p_id and durum = 'aktif' returning * into i;
  if i.id is null then return; end if;
  select ad into s_ad from oyun.sirketler where id = i.sirket_id;
  perform oyun.bildir(i.user_id, format('%s ile iş sözleşmen sona erdi: %s', coalesce(s_ad, 'Şirket'), p_neden), t);
  perform oyun.ist_bildir_yetkililer(i.sirket_id, format('%s, %s şirketindeki işinden ayrıldı: %s', oyun.ist_ad(i.user_id), coalesce(s_ad, 'şirket'), p_neden), t);
end $$;

create or replace function oyun.ist_ilan_json(i oyun.istihdam_ilan) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', i.id, 'sirket_id', s.id, 'sirket', s.ad, 'sektor', coalesce(k.ad, s.sektor),
    'il', (select il.ad from oyun.pazar_sirket ps join oyun.iller il on il.id = ps.il_id where ps.sirket_id = s.id),
    'maas', i.maas, 'kontenjan', least(i.kontenjan, oyun.ist_kontenjan(s.id)),
    'dolu', (select count(*) from oyun.istihdam x where x.sirket_id = s.id and x.durum = 'aktif'),
    'aciklama', i.aciklama, 'acik', i.acik,
    'odeme_guvenli', s.kasa >= i.maas * 7, 'guncelleme', i.guncelleme)
  from oyun.sirketler s left join oyun.pazar_sektor k on k.kod = s.sektor where s.id = i.sirket_id
$$;

-- Oyuncu paneli: işim, başvurularım, açık ilanlar, yönettiğim şirketler.
create or replace function public.istihdam_panel() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kg_ayar := oyun.kg_a(); t timestamptz := oyun.simdi();
  g date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; i oyun.istihdam; ek int;
begin
  select * into i from oyun.istihdam where user_id = p.id and durum = 'aktif';
  select count(*) into ek from oyun.ek_is_kayit where user_id = p.id and gun = g;
  return jsonb_build_object(
    'acik', a.ist_acik, 'piyasa_ucret', a.piyasa_ucret, 'maas_taban', a.maas_taban, 'maas_tavan', a.maas_tavan,
    'katma_kat', a.katma_kat, 'pasif_gun', a.pasif_gun, 'min_hesap_gun', a.min_hesap_gun,
    'ek_is_kalan', greatest(0, oyun.ek_is_gunluk_limit() - ek),
    'is', case when i.id is null then null else jsonb_build_object('id', i.id, 'sirket_id', i.sirket_id,
        'sirket', (select ad from oyun.sirketler where id = i.sirket_id), 'maas', i.maas, 'baslama', i.baslama,
        'son_mesai', i.son_mesai, 'bugun_yapildi', i.son_mesai = g, 'mesai_sayi', i.mesai_sayi, 'toplam_maas', i.toplam_maas,
        'kasa_yeter', (select kasa >= i.maas from oyun.sirketler where id = i.sirket_id)) end,
    'basvurularim', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'ilan_id', b.ilan_id, 'sirket', s.ad, 'durum', b.durum, 'zaman', b.zaman) order by b.zaman desc)
        from oyun.istihdam_basvuru b join oyun.sirketler s on s.id = b.sirket_id
        where b.user_id = p.id and (b.durum = 'bekliyor' or b.zaman > t - interval '3 days')), '[]'::jsonb),
    'ilanlar', coalesce((select jsonb_agg(oyun.ist_ilan_json(il) order by il.maas desc, il.guncelleme desc)
        from (select il.* from oyun.istihdam_ilan il join oyun.sirketler s on s.id = il.sirket_id
              where il.acik and s.aktif
                and (select count(*) from oyun.istihdam x where x.sirket_id = s.id and x.durum = 'aktif') < least(il.kontenjan, oyun.ist_kontenjan(s.id))
              order by il.maas desc, il.guncelleme desc limit 80) il), '[]'::jsonb),
    'sirketlerim', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad,
        'calisan', (select count(*) from oyun.istihdam x where x.sirket_id = s.id and x.durum = 'aktif'),
        'kontenjan', oyun.ist_kontenjan(s.id),
        'bekleyen', (select count(*) from oyun.istihdam_basvuru b where b.sirket_id = s.id and b.durum = 'bekliyor'),
        'ilan_acik', coalesce((select il.acik from oyun.istihdam_ilan il where il.sirket_id = s.id), false)) order by s.sermaye desc)
      from oyun.sirketler s where s.aktif and (s.kurucu = p.id or s.yonetici = p.id
        or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = p.id and o.pay >= 50))), '[]'::jsonb));
end $$;

-- Şirket personel paneli (yetkili).
create or replace function public.istihdam_sirket(p_sirket bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kg_ayar := oyun.kg_a(); s oyun.sirketler; il oyun.istihdam_ilan;
  g date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null then raise exception 'Şirket bulunamadı.'; end if;
  if not oyun.ist_yetkili(s.id, p.id) then raise exception 'Personel işlemleri için şirketin kurucusu, yöneticisi ya da %%50 ve üstü ortağı olmalısın.'; end if;
  select * into il from oyun.istihdam_ilan where sirket_id = s.id;
  return jsonb_build_object('sirket_id', s.id, 'ad', s.ad, 'kasa', s.kasa, 'sermaye', s.sermaye,
    'kontenjan', oyun.ist_kontenjan(s.id), 'kontenjan_birim', a.kontenjan_birim, 'kontenjan_max', a.kontenjan_max,
    'piyasa_ucret', a.piyasa_ucret, 'katma_kat', a.katma_kat, 'maas_taban', a.maas_taban, 'maas_tavan', a.maas_tavan,
    'ilan', case when il.id is null then null else oyun.ist_ilan_json(il) end,
    'basvurular', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'user_id', b.user_id, 'ad', oyun.ist_ad(b.user_id),
        'kidem', round(oyun.kidem_puani(b.user_id), 1), 'mesaj', b.mesaj, 'zaman', b.zaman) order by b.zaman)
      from oyun.istihdam_basvuru b where b.sirket_id = s.id and b.durum = 'bekliyor'), '[]'::jsonb),
    'calisanlar', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'ad', oyun.ist_ad(x.user_id), 'maas', x.maas,
        'baslama', x.baslama, 'son_mesai', x.son_mesai, 'bugun', x.son_mesai = g, 'mesai_sayi', x.mesai_sayi,
        'toplam_maas', x.toplam_maas, 'toplam_katma', x.toplam_katma) order by x.baslama)
      from oyun.istihdam x where x.sirket_id = s.id and x.durum = 'aktif'), '[]'::jsonb),
    'son7', coalesce((select jsonb_build_object('mesai', count(*), 'maas', sum(m.maas), 'katma', sum(m.katma), 'vergi', sum(m.vergi))
      from oyun.istihdam_mesai m where m.sirket_id = s.id and m.gun > g - 7), '{}'::jsonb));
end $$;

create or replace function public.istihdam_ilan_ver(p_sirket bigint, p_maas numeric, p_kontenjan int, p_aciklama text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kg_ayar := oyun.kg_a(); s oyun.sirketler; t timestamptz := oyun.simdi(); k int; m numeric;
  ac text := left(btrim(coalesce(p_aciklama, '')), 300);
begin
  if not a.ist_acik then raise exception 'İş ilanları şu an kapalı.'; end if;
  select * into s from oyun.sirketler where id = p_sirket for update;
  if s.id is null or not s.aktif then raise exception 'Şirket faaliyette değil.'; end if;
  if not oyun.ist_yetkili(s.id, p.id) then raise exception 'İlan vermek için şirketin kurucusu, yöneticisi ya da %%50 ve üstü ortağı olmalısın.'; end if;
  m := round(coalesce(p_maas, 0));
  if m < a.maas_taban or m > a.maas_tavan then
    raise exception 'Günlük maaş % ₺ ile % ₺ arasında olmalı.', oyun.tl(a.maas_taban), oyun.tl(a.maas_tavan);
  end if;
  k := oyun.ist_kontenjan(s.id);
  if coalesce(p_kontenjan, 0) < 1 or p_kontenjan > k then
    raise exception 'Bu şirketin kontenjanı en çok % kişi (her % ₺ sermaye için 1 kişi, en çok %).', k, oyun.tl(a.kontenjan_birim), a.kontenjan_max;
  end if;
  if ac <> '' and oyun.ist_uygunsuz(ac) then raise exception 'İlan metni uygunsuz ifade içeriyor; düzeltip yeniden dene.'; end if;
  insert into oyun.istihdam_ilan(sirket_id, maas, kontenjan, aciklama, acik, olusturma, guncelleme, veren)
  values (s.id, m, p_kontenjan, ac, true, t, t, p.id)
  on conflict (sirket_id) do update set maas = excluded.maas, kontenjan = excluded.kontenjan, aciklama = excluded.aciklama,
    acik = true, guncelleme = t, veren = p.id;
  perform oyun.canli_sinyal('istihdam');
  return public.istihdam_sirket(s.id);
end $$;

create or replace function public.istihdam_ilan_kapat(p_sirket bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not oyun.ist_yetkili(p_sirket, p.id) then raise exception 'Bu şirketin ilanını yönetme yetkin yok.'; end if;
  update oyun.istihdam_ilan set acik = false, guncelleme = t where sirket_id = p_sirket;
  update oyun.istihdam_basvuru set durum = 'kapandi', karar_zaman = t where sirket_id = p_sirket and durum = 'bekliyor';
  return public.istihdam_sirket(p_sirket);
end $$;

create or replace function public.istihdam_basvur(p_ilan bigint, p_mesaj text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kg_ayar := oyun.kg_a(); il oyun.istihdam_ilan; t timestamptz := oyun.simdi();
  e text; dolu int; bid bigint; ms text := left(btrim(coalesce(p_mesaj, '')), 200);
begin
  if not a.ist_acik then raise exception 'İş ilanları şu an kapalı.'; end if;
  perform 1 from oyun.profiller where id = p.id for update;
  if coalesce(p.yasakli, false) or coalesce(p.engel_bitis > t, false) then raise exception 'Hesabın kısıtlı olduğu için iş başvurusu yapamazsın.'; end if;
  if p.olusturma > t - make_interval(days => a.min_hesap_gun) then
    raise exception 'İş başvurusu için hesabın en az % günlük olmalı.', a.min_hesap_gun;
  end if;
  select * into il from oyun.istihdam_ilan where id = p_ilan;
  if il.id is null or not il.acik then raise exception 'İlan kapalı ya da bulunamadı.'; end if;
  e := oyun.ist_engel(il.sirket_id, p.id); if e is not null then raise exception '%', e; end if;
  if exists (select 1 from oyun.istihdam where user_id = p.id and durum = 'aktif') then
    raise exception 'Zaten bir şirkette çalışıyorsun. Yeni işe başvurmak için önce işinden ayrıl.';
  end if;
  if (select count(*) from oyun.istihdam_basvuru where user_id = p.id and durum = 'bekliyor') >= a.basvuru_max then
    raise exception 'Aynı anda en çok % bekleyen başvurun olabilir.', a.basvuru_max;
  end if;
  select count(*) into dolu from oyun.istihdam where sirket_id = il.sirket_id and durum = 'aktif';
  if dolu >= least(il.kontenjan, oyun.ist_kontenjan(il.sirket_id)) then raise exception 'Bu ilanın kontenjanı dolu.'; end if;
  if ms <> '' and oyun.ist_uygunsuz(ms) then raise exception 'Başvuru notu uygunsuz ifade içeriyor; düzeltip yeniden dene.'; end if;
  begin
    insert into oyun.istihdam_basvuru(ilan_id, sirket_id, user_id, zaman, mesaj) values (il.id, il.sirket_id, p.id, t, ms) returning id into bid;
  exception when unique_violation then raise exception 'Bu ilana zaten başvurdun; şirketin kararını bekle.';
  end;
  perform oyun.ist_bildir_yetkililer(il.sirket_id, format('%s, %s şirketinin iş ilanına başvurdu (günlük %s ₺). Şirket › Personel ekranından kabul ya da ret edebilirsin.',
    oyun.ist_ad(p.id), (select ad from oyun.sirketler where id = il.sirket_id), oyun.tl(il.maas)), t);
  return public.istihdam_panel();
end $$;

create or replace function public.istihdam_basvuru_geri(p_basvuru bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  update oyun.istihdam_basvuru set durum = 'geri', karar_zaman = t where id = p_basvuru and user_id = p.id and durum = 'bekliyor';
  if not found then raise exception 'Bekleyen böyle bir başvurun yok.'; end if;
  return public.istihdam_panel();
end $$;

create or replace function public.istihdam_basvuru_karar(p_basvuru bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.istihdam_basvuru; il oyun.istihdam_ilan; s_ad text; e text; dolu int;
begin
  select * into b from oyun.istihdam_basvuru where id = p_basvuru for update;
  if b.id is null or b.durum <> 'bekliyor' then raise exception 'Bu başvuru artık bekleyen durumda değil.'; end if;
  if not oyun.ist_yetkili(b.sirket_id, p.id) then raise exception 'Bu şirketin personel kararlarını verme yetkin yok.'; end if;
  perform 1 from oyun.sirketler where id = b.sirket_id for update;
  select ad into s_ad from oyun.sirketler where id = b.sirket_id;
  if not coalesce(p_kabul, false) then
    update oyun.istihdam_basvuru set durum = 'ret', karar_zaman = t where id = b.id;
    perform oyun.bildir(b.user_id, format('%s şirketine yaptığın iş başvurusu kabul edilmedi.', s_ad), t);
    return public.istihdam_sirket(b.sirket_id);
  end if;
  select * into il from oyun.istihdam_ilan where id = b.ilan_id;
  e := oyun.ist_engel(b.sirket_id, b.user_id);
  if e is null and exists (select 1 from oyun.istihdam where user_id = b.user_id and durum = 'aktif') then
    e := 'Bu oyuncu bu arada başka bir şirkette işe başladı.';
  end if;
  if e is not null then
    update oyun.istihdam_basvuru set durum = 'kapandi', karar_zaman = t where id = b.id;
    return public.istihdam_sirket(b.sirket_id) || jsonb_build_object('uyari', 'Başvuru kapatıldı: ' || e);
  end if;
  select count(*) into dolu from oyun.istihdam where sirket_id = b.sirket_id and durum = 'aktif';
  if dolu >= oyun.ist_kontenjan(b.sirket_id) then raise exception 'Şirketin kontenjanı dolu. Sermaye arttıkça kontenjan da artar.'; end if;
  update oyun.istihdam_basvuru set durum = 'kabul', karar_zaman = t where id = b.id;
  update oyun.istihdam_basvuru set durum = 'kapandi', karar_zaman = t where user_id = b.user_id and durum = 'bekliyor';
  insert into oyun.istihdam(sirket_id, user_id, maas, baslama) values (b.sirket_id, b.user_id, coalesce(il.maas, (select maas_taban from oyun.kg_ayar where id = 1)), t);
  perform oyun.bildir(b.user_id, format('Tebrikler! %s seni işe aldı. Günlük maaşın %s ₺. Her gün Ek İşler › İş Hayatı''ndan "Mesaiye git" ile maaşını al (bir ek iş hakkı kullanır).',
    s_ad, oyun.tl(coalesce(il.maas, 0))), t);
  perform oyun.canli_sinyal('istihdam');
  return public.istihdam_sirket(b.sirket_id);
end $$;

-- Günlük mesai: bir ek iş hakkı kullanır, maaş şirket kasasından anında, katma değer şirket kasasına.
create or replace function public.istihdam_mesai() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kg_ayar := oyun.kg_a(); t timestamptz := oyun.simdi();
  g date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; i oyun.istihdam; s oyun.sirketler; e text; yap int;
  katma numeric; v_vergi numeric; kv numeric; tlm numeric;
begin
  if not a.ist_acik then raise exception 'İstihdam şu an kapalı.'; end if;
  perform 1 from oyun.profiller where id = p.id for update;
  select * into i from oyun.istihdam where user_id = p.id and durum = 'aktif' for update;
  if i.id is null then raise exception 'Bir şirkette çalışmıyorsun. İş İlanları''ndan başvurabilirsin.'; end if;
  if i.son_mesai = g then raise exception 'Bugünkü mesaini yaptın. Yeni mesai Türkiye saatiyle 00.00''da açılır.'; end if;
  select * into s from oyun.sirketler where id = i.sirket_id for update;
  e := oyun.ist_engel(i.sirket_id, p.id);
  if e is not null then perform oyun.ist_bitir(i.id, 'sona_erdi', e, t); return public.istihdam_panel(); end if;
  if exists (select 1 from oyun.ek_is_kayit where user_id = p.id and odendi_at is null and bitis > t) then
    raise exception 'Devam eden ek işin var. O bitince mesaiye gidebilirsin.';
  end if;
  select count(*) into yap from oyun.ek_is_kayit where user_id = p.id and gun = g;
  if yap >= oyun.ek_is_gunluk_limit() then
    raise exception 'Bugünkü % ek iş hakkını doldurdun; mesai de bir hak kullanır. Haklar 00.00''da yenilenir.', oyun.ek_is_gunluk_limit();
  end if;
  if s.kasa < i.maas then
    -- Hata fırlatılmaz (bildirim geri alınmasın): uyarı döner. Patrona 6 saatte en çok bir bildirim.
    update oyun.istihdam_ilan set kasa_uyari = t where sirket_id = s.id and (kasa_uyari is null or kasa_uyari < t - interval '6 hours');
    if found or not exists (select 1 from oyun.istihdam_ilan where sirket_id = s.id) then
      perform oyun.ist_bildir_yetkililer(s.id, format('%s kasası çalışanının günlük maaşını (%s ₺) karşılamıyor; %s mesai yapamadı. Kasaya para koy ya da maaşı düşür.',
        s.ad, oyun.tl(i.maas), oyun.ist_ad(p.id)), t);
    end if;
    return public.istihdam_panel() || jsonb_build_object('uyari', format('Şirket kasası bugünkü maaşını (%s ₺) karşılamıyor. Patronuna bildirim gitti; sonra yeniden dene. Hakkın harcanmadı.', oyun.tl(i.maas)));
  end if;
  katma := round(least(i.maas, a.piyasa_ucret) * a.katma_kat);
  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), (select pa.kurumlar from oyun.pazar_ayar pa where pa.id = 1), 25);
  v_vergi := round(greatest(0, katma - i.maas) * kv / 100);
  -- ek iş hakkı (ödenmiş kayıt; ek iş listesinde görünmez, başlatılamaz)
  insert into oyun.ek_is_kayit(user_id, tur, baslama, bitis, gun, ucret, odendi_at)
  values (p.id, 'mesai', t, t + interval '1 second', g, greatest(1, round(i.maas))::int, t);
  update oyun.sirketler set kasa = kasa - i.maas + katma - v_vergi where id = s.id;
  if v_vergi > 0 then
    tlm := oyun.pazar_tl_milyar();
    update oyun.ulke set hazine = hazine + v_vergi / tlm where id = 1;
  end if;
  perform oyun.para_islem(p.id, i.maas, 'maas', format('%s günlük maaş (mesai)', s.ad), t);
  update oyun.istihdam set son_mesai = g, mesai_sayi = mesai_sayi + 1, toplam_maas = toplam_maas + i.maas, toplam_katma = toplam_katma + katma where id = i.id;
  insert into oyun.istihdam_mesai(istihdam_id, sirket_id, user_id, gun, zaman, maas, katma, vergi) values (i.id, s.id, p.id, g, t, i.maas, katma, v_vergi);
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider)
    values (s.id, t, katma - i.maas - v_vergi, format('Personel mesaisi: %s (maaş %s ₺, katma değer %s ₺)', oyun.ist_ad(p.id), oyun.tl(i.maas), oyun.tl(katma)), katma, i.maas + v_vergi);
  perform oyun.kidem_ekle(p.id, 'mesai');
  return public.istihdam_panel() || jsonb_build_object('odenen', i.maas);
end $$;

create or replace function public.istihdam_ayril() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); i oyun.istihdam;
begin
  select * into i from oyun.istihdam where user_id = p.id and durum = 'aktif';
  if i.id is null then raise exception 'Bir şirkette çalışmıyorsun.'; end if;
  perform oyun.ist_bitir(i.id, 'ayrildi', 'çalışan kendi isteğiyle ayrıldı.', oyun.simdi());
  return public.istihdam_panel();
end $$;

create or replace function public.istihdam_cikar(p_istihdam bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); i oyun.istihdam;
begin
  select * into i from oyun.istihdam where id = p_istihdam and durum = 'aktif';
  if i.id is null then raise exception 'Böyle bir aktif çalışan yok.'; end if;
  if not oyun.ist_yetkili(i.sirket_id, p.id) then raise exception 'Bu şirketin personel kararlarını verme yetkin yok.'; end if;
  perform oyun.ist_bitir(i.id, 'cikarildi', 'şirket yönetimi sözleşmeyi sonlandırdı.', oyun.simdi());
  return public.istihdam_sirket(i.sirket_id);
end $$;

create or replace function public.istihdam_maas(p_istihdam bigint, p_maas numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.kg_ayar := oyun.kg_a(); i oyun.istihdam; m numeric := round(coalesce(p_maas, 0));
begin
  select * into i from oyun.istihdam where id = p_istihdam and durum = 'aktif' for update;
  if i.id is null then raise exception 'Böyle bir aktif çalışan yok.'; end if;
  if not oyun.ist_yetkili(i.sirket_id, p.id) then raise exception 'Bu şirketin personel kararlarını verme yetkin yok.'; end if;
  if m < a.maas_taban or m > a.maas_tavan then raise exception 'Günlük maaş % ₺ ile % ₺ arasında olmalı.', oyun.tl(a.maas_taban), oyun.tl(a.maas_tavan); end if;
  if m = i.maas then return public.istihdam_sirket(i.sirket_id); end if;
  update oyun.istihdam set maas = m where id = i.id;
  perform oyun.bildir(i.user_id, format('%s günlük maaşını %s ₺''den %s ₺''ye %s.', (select ad from oyun.sirketler where id = i.sirket_id),
    oyun.tl(i.maas), oyun.tl(m), case when m > i.maas then 'yükseltti' else 'düşürdü' end), oyun.simdi());
  return public.istihdam_sirket(i.sirket_id);
end $$;

-- Saatlik bakım: hareketsiz sözleşmeler, kapanan şirketler, eski başvurular.
create or replace function oyun.istihdam_tick() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a oyun.kg_ayar := oyun.kg_a(); t timestamptz := oyun.simdi(); g date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
  r record; n1 int := 0; n2 int := 0; hata int := 0;
begin
  if not pg_try_advisory_xact_lock(hashtext('oyun.istihdam_tick')) then return jsonb_build_object('kilitli', true); end if;
  for r in select x.id, s.aktif from oyun.istihdam x join oyun.sirketler s on s.id = x.sirket_id
           where x.durum = 'aktif' and (not s.aktif or coalesce(x.son_mesai, (x.baslama at time zone 'Europe/Istanbul')::date) < g - a.pasif_gun)
           order by x.id limit 300 loop
    begin
      perform oyun.ist_bitir(r.id, 'sona_erdi', case when not r.aktif then 'şirket faaliyetini durdurdu.'
        else format('%s gün üst üste mesai yapılmadı.', a.pasif_gun) end, t);
      n1 := n1 + 1;
    exception when others then hata := hata + 1;
    end;
  end loop;
  with u as (update oyun.istihdam_basvuru b set durum = 'kapandi', karar_zaman = t
             where b.durum = 'bekliyor' and (b.zaman < t - interval '72 hours'
               or not exists (select 1 from oyun.istihdam_ilan il join oyun.sirketler s on s.id = il.sirket_id where il.id = b.ilan_id and il.acik and s.aktif))
             returning 1) select count(*) into n2 from u;
  update oyun.istihdam_ilan il set acik = false, guncelleme = t
   where il.acik and not exists (select 1 from oyun.sirketler s where s.id = il.sirket_id and s.aktif);
  return jsonb_build_object('biten', n1, 'kapanan_basvuru', n2, 'hata', hata);
end $$;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
    values ('istihdam', 'select oyun.istihdam_tick()', 60, 23, 128, true)
    on conflict (adim) do nothing;
  end if;
end $z$;

-- ============ YETKİLER ============
revoke all on function oyun.kg_tavan_yuzde(bigint, numeric, numeric), oyun.kg_kisi_oran(uuid, bigint, numeric), oyun.kg_kisi_sermaye(uuid, bigint, numeric),
  oyun.kg_ozet(uuid), oyun.kg_magaza_ek(uuid), oyun.istihdam_tick(), oyun.ist_bitir(bigint, text, text, timestamptz),
  oyun.ist_bildir_yetkililer(bigint, text, timestamptz), oyun.ist_engel(bigint, uuid), oyun.ist_yetkili(bigint, uuid)
  from public, anon, authenticated;
do $g$
declare f text;
begin
  foreach f in array array['kademe_ozet()', 'hizli_acilis_kullan(bigint)', 'istihdam_panel()', 'istihdam_sirket(bigint)',
    'istihdam_ilan_ver(bigint, numeric, integer, text)', 'istihdam_ilan_kapat(bigint)', 'istihdam_basvur(bigint, text)',
    'istihdam_basvuru_geri(bigint)', 'istihdam_basvuru_karar(bigint, boolean)', 'istihdam_mesai()', 'istihdam_ayril()',
    'istihdam_cikar(bigint)', 'istihdam_maas(bigint, numeric)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $g$;

-- ============ YÖNETİM PORTALI AYARLARI ============
do $p$
begin
  if to_regclass('oyun.yp_ayar_katalog') is null then return; end if;
  insert into oyun.yp_ayar_katalog(anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, sira, aktif) values
  ('kademe.aktif','oyun.kg_ayar','aktif',null,'ekonomi','Kademeli getiri','Şirket kazanç tavanı oyuncunun toplam şirket payına göre kademeli hesaplanır. Kapatılırsa 25.11 kazanç dengesi aynen geçerli olur.','evet_hayir',null,null,null,null,'yuksek','Hemen: bir sonraki tahmin ve günlük hesapta.',100,true),
  ('kademe.d1_oran','oyun.kg_ayar','d1_oran',null,'ekonomi','1. dilim günlük net getiri','Oyuncunun ilk dilimdeki şirket payının, iyi yönetilen şirkette hedef günlük net getirisi.','sayi','%',0,10,null,'yuksek','Hemen.',101,true),
  ('kademe.d1_sinir','oyun.kg_ayar','d1_sinir',null,'ekonomi','1. dilim sınırı','İlk (en kârlı) dilimin üst sınırı.','sayi','₺',0,100000000,null,'yuksek','Hemen.',102,true),
  ('kademe.d2_oran','oyun.kg_ayar','d2_oran',null,'ekonomi','2. dilim günlük net getiri','İlk dilimin üstünden 2. dilim sınırına kadarki pay sermayesinin hedef günlük net getirisi.','sayi','%',0,10,null,'yuksek','Hemen.',103,true),
  ('kademe.d2_sinir','oyun.kg_ayar','d2_sinir',null,'ekonomi','2. dilim sınırı','2. dilimin üst sınırı.','sayi','₺',0,1000000000,null,'yuksek','Hemen.',104,true),
  ('kademe.d3_oran','oyun.kg_ayar','d3_oran',null,'ekonomi','3. dilim günlük net getiri','2. dilim sınırından 3. dilim sınırına kadarki pay sermayesinin hedef günlük net getirisi.','sayi','%',0,10,null,'yuksek','Hemen.',105,true),
  ('kademe.d3_sinir','oyun.kg_ayar','d3_sinir',null,'ekonomi','3. dilim sınırı','3. dilimin üst sınırı; üstü son dilimdir.','sayi','₺',0,1000000000,null,'yuksek','Hemen.',106,true),
  ('kademe.d4_oran','oyun.kg_ayar','d4_oran',null,'ekonomi','Son dilim günlük net getiri','3. dilim sınırının üstündeki pay sermayesi.','sayi','%',0,10,null,'yuksek','Hemen.',107,true),
  ('kademe.verim','oyun.kg_ayar','verim',null,'ekonomi','Şirket verimlilik katsayısı','Kârlı şirketin vergi öncesi kârı bu katsayıyla büyütülüp kademeli tavana sıkıştırılır (1 = büyütme yok). Zarardaki şirkete etkisi yoktur.','sayi','×',1,5,null,'yuksek','Hemen.',108,true),
  ('kademe.patron_ek','oyun.kg_ayar','patron_ek',null,'ekonomi','Patron Kartı ilk dilim ekleme','Patron Kartı süresince ilk dilime eklenen tutar.','sayi','₺',0,10000000,null,'orta','Hemen.',109,true),
  ('kademe.hizli_gun','oyun.kg_ayar','hizli_gun',null,'ekonomi','Hızlı Açılış Belgesi kısaltması','Belgenin şirket merkezinin kuruluş döneminden düştüğü gün.','sayi','gün',1,60,null,'orta','Sonraki kullanımda.',110,true),
  ('istihdam.ist_acik','oyun.kg_ayar','ist_acik',null,'ekonomi','İstihdam (iş ilanları ve mesai)','Kapatılırsa yeni ilan, başvuru ve mesai yapılamaz; mevcut sözleşmeler durur.','evet_hayir',null,null,null,null,'orta','Hemen.',111,true),
  ('istihdam.maas_taban','oyun.kg_ayar','maas_taban',null,'ekonomi','En düşük günlük maaş','İş ilanında ve maaş değişikliğinde verilebilecek en düşük günlük maaş.','sayi','₺',1,1000000,null,'orta','Yeni ilan ve maaş değişikliklerinde.',112,true),
  ('istihdam.maas_tavan','oyun.kg_ayar','maas_tavan',null,'ekonomi','En yüksek günlük maaş','İş ilanında ve maaş değişikliğinde verilebilecek en yüksek günlük maaş.','sayi','₺',1,10000000,null,'orta','Yeni ilan ve maaş değişikliklerinde.',113,true),
  ('istihdam.piyasa_ucret','oyun.kg_ayar','piyasa_ucret',null,'ekonomi','Piyasa ücreti','Mesaide şirkete giren katma değer en çok bu ücret × katsayı kadardır; üstündeki maaş yalnız patrondan çalışana aktarımdır (para basmaz).','sayi','₺',1,1000000,null,'yuksek','Sonraki mesaide.',114,true),
  ('istihdam.katma_kat','oyun.kg_ayar','katma_kat',null,'ekonomi','Mesai katma değer katsayısı','1,35 = piyasa ücretindeki çalışanın her mesaisi şirkete maaşının %35 fazlasını kazandırır (vergi öncesi).','sayi','×',1,3,null,'yuksek','Sonraki mesaide.',115,true),
  ('istihdam.kontenjan_birim','oyun.kg_ayar','kontenjan_birim',null,'ekonomi','Kontenjan için sermaye','Şirket kontenjanı = 1 + her bu kadar sermaye için 1 kişi.','sayi','₺',10000,100000000,null,'orta','Hemen.',116,true),
  ('istihdam.kontenjan_max','oyun.kg_ayar','kontenjan_max',null,'ekonomi','En çok çalışan','Bir şirketin en çok çalışan sayısı.','tamsayi','kişi',1,50,null,'orta','Hemen.',117,true),
  ('istihdam.pasif_gun','oyun.kg_ayar','pasif_gun',null,'ekonomi','Mesaisiz sözleşme bitişi','Bu kadar gün mesai yapılmazsa sözleşme kendiliğinden biter.','tamsayi','gün',1,60,null,'dusuk','Saatlik bakımda.',118,true)
  on conflict (anahtar) do update set tablo = excluded.tablo, sutun = excluded.sutun, grup = excluded.grup, baslik = excluded.baslik,
    aciklama = excluded.aciklama, tur = excluded.tur, birim = excluded.birim, en_az = excluded.en_az, en_cok = excluded.en_cok,
    risk = excluded.risk, etki = excluded.etki, sira = excluded.sira, aktif = excluded.aktif;
end $p$;

-- ============ BİR KERELİK BİLDİRİM (şirket ortaklarına) ============
do $b$
declare x record; a oyun.kg_ayar := oyun.kg_a(); t timestamptz := oyun.simdi(); tt numeric; g numeric;
begin
  if a.id is null or not a.aktif then return; end if;
  if to_regclass('oyun.tek_seferlik') is not null then
    if exists (select 1 from oyun.tek_seferlik where anahtar = 'kademeli_getiri_20261126') then return; end if;
    insert into oyun.tek_seferlik(anahtar) values ('kademeli_getiri_20261126');
  end if;
  for x in select distinct o.user_id from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id where o.pay > 0 and s.aktif loop
    tt := oyun.kg_kisi_sermaye(x.user_id); g := oyun.kg_gunluk(tt, oyun.kg_d1(x.user_id, a), a);
    perform oyun.bildir(x.user_id, format('Yeni: Kademeli Getiri. Şirket kazancı artık oyuncu başına kademeli: şirket payının ilk %s ₺''si günde %%%s, %s ₺''ye kadarı %%%s, sonrası daha düşük net getiri hedefler. Senin payın %s ₺ → iyi yönetilen şirketlerde, kuruluş dönemi bitince günde yaklaşık %s ₺''ye kadar. Hiçbir şirketin kazanç tavanı düşmedi. Ayrıca artık iş ilanı verip gerçek oyuncuları işe alabilirsin (Şirket › Personel; web sürümünde hemen, telefonda bir sonraki uygulama güncellemesiyle).',
      oyun.tl(a.d1_sinir), replace(a.d1_oran::text, '.', ','), oyun.tl(a.d2_sinir), replace(a.d2_oran::text, '.', ','), oyun.tl(round(tt)), oyun.tl(round(g))), t);
  end loop;
end $b$;
