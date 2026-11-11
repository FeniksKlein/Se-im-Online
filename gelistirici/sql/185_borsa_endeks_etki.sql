-- =====================================================================
--  185 (11.11.2026) · ŞİRKETLER ENDEKSİ DÜZELTMESİ + BORSANIN EKONOMİYE ETKİSİ
--
--  Sorun: Endeks şirketlerin toplam değerini zincirleme ölçüyordu. Ortakların kasaya koyduğu sermaye
--  endeksi şişiriyor, şirketten ortaklara/kişilere aktarılan para (çek, temettü, sermaye azaltımı) da
--  "çöküş" gibi görünüyordu. 10 Kasım'daki %37'lik düşüşün sebebi buydu; para yok olmamış, el değiştirmişti.
--
--  1) Düzeltme (gerçek borsalardaki "sermaye hareketinden arındırılmış / toplam getiri" mantığı):
--       günlük oran = (bugünkü değer − dönem içindeki net sermaye girişi) / dünkü değer
--     Net sermaye girişi = kişilerden şirkete giren sermaye/ortak katkısı/halka arz geliri
--                          − şirketten kişilere çıkan çek ödemesi, temettü, kâr payı, sermaye azaltımı.
--     Şirketten şirkete akan para zaten iki tarafta da sayıldığı için düzeltme gerektirmez.
--     Geçmiş endeks bu kurala göre yeniden hesaplanır; eski değerler ham_deger sütununda saklanır.
--  2) Etki (günde bir kez, bir önceki günün kapanışına göre): gerçek düşüş/yükselişler büyümeyi,
--     halkın memnuniyetini (servet ve güven etkisi) ve sert çöküşte enflasyonu (risk primi) etkiler.
--     Büyüme ve memnuniyet şirket cirolarını (pazar_tahmin) ve işsizliği zaten belirlediği için etki
--     ekonominin geri kalanına kendiliğinden yayılır. Şoklar kalıcı değildir; makro model her gün
--     dengeye doğru çeker. Etkiler oyun.borsa_etki_gunluk tablosunda açıkça kayıtlıdır.
--  Oyuncu bakiyelerine, şirket kasalarına ve hisse fiyatlarına dokunmaz.
-- =====================================================================

alter table oyun.piyasa_endeks add column if not exists ham_deger numeric;
alter table oyun.piyasa_endeks add column if not exists sermaye_akisi numeric;
create index if not exists sirket_hareket_sirket_zaman on oyun.sirket_hareket(sirket_id, zaman);

-- Bir şirketin (bas, bit] aralığındaki kişilerle net sermaye hareketi (+ giriş, − çıkış)
create or replace function oyun.sirket_sermaye_akisi(p_sirket bigint, p_bas timestamptz, p_bit timestamptz) returns numeric
language sql stable set search_path = '' as $$
  select coalesce(sum(h.tutar), 0)
    from oyun.sirket_hareket h
   where h.sirket_id = p_sirket and h.zaman > p_bas and h.zaman <= p_bit
     and (
          h.aciklama ~* '^Ortak .+ şirket kasasına kendi parasından'
       or h.aciklama ~* '^Hakim ortak sermaye katk'
       or h.aciklama ~* 'oyuncusundan sermaye niteliğinde'
       or h.aciklama ~* '^Halka arz: .*yeni sermaye'
       or h.aciklama ~* '^Sermaye (artırımı|azaltımı)'
       or (h.tutar < 0 and h.aciklama ~* '^(Genel kurul kararıyla temettü|Kâr payı dağıtımı|Temettü)')
       or (h.tutar < 0 and h.aciklama ~ '^Çek #\s*\d+ ödemesi' and exists (
             select 1 from oyun.cekler c
              where c.id = (substring(h.aciklama from '^Çek #\s*(\d+)'))::bigint and c.hamil_sirket is null))
     )
$$;

create or replace function oyun.piyasa_degerle()
 returns numeric language plpgsql security definer set search_path to ''
as $function$
declare g date := (now() at time zone 'Europe/Istanbul')::date; onceki oyun.piyasa_endeks; bugun_t numeric; dun_t numeric; akis numeric; e numeric; n int; oran numeric;
begin
  insert into oyun.sirket_deger_gecmis(sirket_id, gun, defter, kar7, deger, piyasa, guncelleme)
  select s.id, g, oyun.sirket_defter(s.id), oyun.sirket_kar7(s.id), oyun.sirket_deger(s.id),
         case when s.halka_acik then oyun.borsa_son_fiyat(s.id) * 100 end, now()
  from oyun.sirketler s where s.aktif
  on conflict on constraint sirket_deger_gecmis_pkey do update set defter = excluded.defter, kar7 = excluded.kar7,
     deger = excluded.deger, piyasa = excluded.piyasa, guncelleme = excluded.guncelleme;
  select * into onceki from oyun.piyasa_endeks where gun < g order by gun desc limit 1;
  select coalesce(sum(coalesce(piyasa, deger)), 0), count(*) into bugun_t, n from oyun.sirket_deger_gecmis d
    join oyun.sirketler s on s.id = d.sirket_id and s.aktif where d.gun = g;
  if onceki.gun is null then
    e := 1000; akis := 0;
  else
    -- zincirleme endeks: iki günde de var olan şirketler; sermaye hareketleri getiriden ayrılır
    select coalesce(sum(coalesce(b.piyasa, b.deger)), 0), coalesce(sum(coalesce(a.piyasa, a.deger)), 0),
           coalesce(sum(oyun.sirket_sermaye_akisi(b.sirket_id, a.guncelleme, b.guncelleme)), 0)
      into bugun_t, dun_t, akis
    from oyun.sirket_deger_gecmis b join oyun.sirket_deger_gecmis a on a.sirket_id = b.sirket_id and a.gun = onceki.gun
    where b.gun = g;
    oran := case when dun_t > 0 then oyun.sinir((bugun_t - akis) / dun_t, 0.6, 1.6) else 1 end;
    e := round(onceki.deger * oran, 2);
    select coalesce(sum(coalesce(piyasa, deger)), 0) into bugun_t from oyun.sirket_deger_gecmis where gun = g;
  end if;
  insert into oyun.piyasa_endeks(gun, deger, onceki, toplam, sirket_sayisi, guncelleme, sermaye_akisi)
  values (g, e, onceki.deger, bugun_t, n, now(), round(akis))
  on conflict (gun) do update set deger = excluded.deger, onceki = excluded.onceki, toplam = excluded.toplam,
    sirket_sayisi = excluded.sirket_sayisi, guncelleme = excluded.guncelleme, sermaye_akisi = excluded.sermaye_akisi;
  return e;
end $function$;

-- Geçmişi yeniden hesapla (bir kez; ham_deger boşsa eski değeri saklar)
create or replace function oyun.piyasa_endeks_yeniden() returns int
language plpgsql security definer set search_path = '' as $$
declare r record; onceki_gun date; onceki_e numeric; bt numeric; dt numeric; ak numeric; n int := 0;
begin
  update oyun.piyasa_endeks set ham_deger = deger where ham_deger is null;
  for r in select * from oyun.piyasa_endeks order by gun loop
    if onceki_gun is null then
      onceki_gun := r.gun; onceki_e := r.deger; continue;
    end if;
    select coalesce(sum(coalesce(b.piyasa, b.deger)), 0), coalesce(sum(coalesce(a.piyasa, a.deger)), 0),
           coalesce(sum(oyun.sirket_sermaye_akisi(b.sirket_id, a.guncelleme, b.guncelleme)), 0)
      into bt, dt, ak
      from oyun.sirket_deger_gecmis b join oyun.sirket_deger_gecmis a on a.sirket_id = b.sirket_id and a.gun = onceki_gun
     where b.gun = r.gun;
    onceki_e := round(onceki_e * case when dt > 0 then oyun.sinir((bt - ak) / dt, 0.6, 1.6) else 1 end, 2);
    update oyun.piyasa_endeks set onceki = (select deger from oyun.piyasa_endeks where gun = onceki_gun),
           deger = onceki_e, sermaye_akisi = round(ak) where gun = r.gun;
    onceki_gun := r.gun; n := n + 1;
  end loop;
  return n;
end $$;

-- ---------- Borsanın ekonomiye etkisi ----------
create table if not exists oyun.borsa_etki_gunluk (
  gun        date primary key,
  endeks     numeric not null,
  r1         numeric not null,      -- günlük değişim %
  r7         numeric,               -- 7 günlük değişim %
  dd         numeric not null,      -- son 30 günün zirvesinden uzaklık % (≤ 0)
  rejim      text not null check (rejim in ('cokus','sert_dusus','dusus','normal','yukselis','ralli')),
  buyume     numeric not null default 0,
  memnuniyet numeric not null default 0,
  enflasyon  numeric not null default 0,
  aciklama   text not null,
  olusturma  timestamptz not null default now()
);
alter table oyun.borsa_etki_gunluk enable row level security;
revoke all on oyun.borsa_etki_gunluk from public, anon, authenticated;
grant select, insert, update on oyun.borsa_etki_gunluk to service_role;

create or replace function oyun.borsa_sayi(x numeric, isaret boolean default false) returns text language sql immutable as $$
  select case when isaret and x > 0 then '+' else '' end || replace(trim(to_char(round(x, 2), 'FM999999990.00')), '.', ',')
$$;
create or replace function oyun.borsa_rejim_ad(r text) returns text language sql immutable as $$
  select case r when 'cokus' then 'Borsa çöküşü' when 'sert_dusus' then 'Sert düşüş' when 'dusus' then 'Düşüş eğilimi'
    when 'yukselis' then 'Yükseliş eğilimi' when 'ralli' then 'Güçlü ralli' else 'Olağan seyir' end
$$;

-- Günde bir kez: dünkü kapanışa göre ekonomiye etki uygula
create or replace function oyun.borsa_etki_tick() returns text
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := now(); bugun date := (now() at time zone 'Europe/Istanbul')::date; g date := bugun - 1;
  e oyun.piyasa_endeks; e7 numeric; tepe numeric; r1 numeric; r7 numeric; dd numeric; rj text;
  b numeric := 0; m numeric := 0; enf numeric := 0; acik text; onceki_rj text;
begin
  if exists (select 1 from oyun.borsa_etki_gunluk where gun = g) then return 'zaten'; end if;
  if not pg_try_advisory_xact_lock(hashtext('oyun.borsa_etki_tick')) then return 'kilit'; end if;
  select * into e from oyun.piyasa_endeks where gun = g;
  if e.gun is null or e.onceki is null or e.onceki <= 0 then return 'veri yok'; end if;
  select deger into e7 from oyun.piyasa_endeks where gun <= g - 7 order by gun desc limit 1;
  select max(deger) into tepe from oyun.piyasa_endeks where gun between g - 30 and g;
  r1 := round((e.deger / e.onceki - 1) * 100, 2);
  r7 := case when e7 > 0 then round((e.deger / e7 - 1) * 100, 2) end;
  dd := round(least(0, (e.deger / nullif(tepe, 0) - 1) * 100), 2);
  rj := case when r1 <= -10 or dd <= -25 then 'cokus'
             when r1 <= -5 or dd <= -15 then 'sert_dusus'
             when r1 <= -2 or dd <= -7 then 'dusus'
             when r1 >= 6 or coalesce(r7, 0) >= 20 then 'ralli'
             when r1 >= 2 or coalesce(r7, 0) >= 8 then 'yukselis'
             else 'normal' end;
  -- servet ve güven etkisi (puan): günlük hareket + zirveden uzun süre uzak kalmanın baskısı
  -- yükselişin etkisi düşüşten daha sınırlıdır (kayıptan kaçınma); süren boğa piyasası kalıcı aşırı ısınma yaratmaz
  b := oyun.sinir(r1 * 0.03, -0.35, 0.05) - oyun.sinir((-dd - 10) * 0.01, 0, 0.15);
  m := oyun.sinir(r1 * 0.04, -0.45, 0.08) - oyun.sinir((-dd - 10) * 0.015, 0, 0.20);
  enf := case rj when 'cokus' then 0.15 when 'sert_dusus' then 0.05 else 0 end;   -- risk primi → kur → fiyatlar
  b := round(b, 3); m := round(m, 3);
  update oyun.ulke set buyume = oyun.sinir(buyume + b, -10, 15),
                       memnuniyet = oyun.sinir(memnuniyet + m, 0, 100),
                       enflasyon = oyun.sinir(enflasyon + enf, 0, 200) where id = 1;
  acik := format('Şirketler endeksi %s (%%%s%s). Ekonomiye etkisi: büyüme %s, memnuniyet %s%s puan.',
    translate(to_char(e.deger, 'FM999,999,990.00'), ',.', '.,'), oyun.borsa_sayi(r1, true),
    case when dd < -0.5 then format(', zirveden %%%s', oyun.borsa_sayi(dd)) else '' end,
    oyun.borsa_sayi(b, true), oyun.borsa_sayi(m, true),
    case when enf > 0 then ', enflasyon ' || oyun.borsa_sayi(enf, true) else '' end);
  select rejim into onceki_rj from oyun.borsa_etki_gunluk where gun < g order by gun desc limit 1;
  insert into oyun.borsa_etki_gunluk(gun, endeks, r1, r7, dd, rejim, buyume, memnuniyet, enflasyon, aciklama)
  values (g, e.deger, r1, r7, dd, rj, b, m, enf, acik);
  -- Haber: belirgin hareket ya da rejim değişimi
  if abs(r1) >= 3 or (rj is distinct from coalesce(onceki_rj, 'normal') and rj <> 'normal') then
    perform oyun.olay('ekonomi', case
      when rj = 'cokus' then format('Borsada çöküş: Şirketler endeksi %%%s, son 30 günün zirvesinden %%%s uzakta. Yatırımcı güveni sarsıldı; büyüme ve tüketim baskı altında.', oyun.borsa_sayi(r1, true), oyun.borsa_sayi(-dd))
      when rj = 'sert_dusus' then format('Borsada sert düşüş: Şirketler endeksi %%%s. Piyasalardaki satış baskısı ekonomiye yansıyor.', oyun.borsa_sayi(r1, true))
      when r1 <= -3 then format('Borsa günü kayıpla kapattı: Şirketler endeksi %%%s.', oyun.borsa_sayi(r1, true))
      when rj = 'ralli' then format('Borsada ralli: Şirketler endeksi %%%s. Güçlü piyasalar tüketimi ve büyümeyi destekliyor.', oyun.borsa_sayi(r1, true))
      else format('Borsa günü yükselişle kapattı: Şirketler endeksi %%%s.', oyun.borsa_sayi(r1, true)) end, null, null, t);
  end if;
  return acik;
end $$;

-- Oyuncu: güncel borsa durumu ve son günlerin etkileri
create or replace function public.borsa_etki_durum() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.borsa_etki_gunluk;
begin
  select * into s from oyun.borsa_etki_gunluk order by gun desc limit 1;
  return jsonb_build_object(
    'son', case when s.gun is not null then jsonb_build_object('gun', s.gun, 'endeks', s.endeks, 'r1', s.r1, 'r7', s.r7, 'dd', s.dd,
            'rejim', s.rejim, 'rejim_ad', oyun.borsa_rejim_ad(s.rejim), 'buyume', s.buyume, 'memnuniyet', s.memnuniyet,
            'enflasyon', s.enflasyon, 'aciklama', s.aciklama) end,
    'yedi_gun', jsonb_build_object(
       'buyume', (select round(coalesce(sum(buyume), 0), 2) from oyun.borsa_etki_gunluk where gun > current_date - 8),
       'memnuniyet', (select round(coalesce(sum(memnuniyet), 0), 2) from oyun.borsa_etki_gunluk where gun > current_date - 8),
       'enflasyon', (select round(coalesce(sum(enflasyon), 0), 2) from oyun.borsa_etki_gunluk where gun > current_date - 8)),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('gun', gun, 'r1', r1, 'rejim', rejim, 'rejim_ad', oyun.borsa_rejim_ad(rejim)) order by gun desc)
       from (select * from oyun.borsa_etki_gunluk order by gun desc limit 14) x), '[]'::jsonb));
end $$;

revoke all on function oyun.sirket_sermaye_akisi(bigint, timestamptz, timestamptz), oyun.piyasa_endeks_yeniden(),
  oyun.borsa_etki_tick(), oyun.borsa_rejim_ad(text), oyun.borsa_sayi(numeric, boolean) from public, anon, authenticated;
revoke all on function public.borsa_etki_durum() from public, anon;
grant execute on function public.borsa_etki_durum() to authenticated, service_role;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, sira, periyot_dk, ofset_dk, komut, aktif)
    values ('borsa_etki', 78, 15, 7, 'select oyun.borsa_etki_tick()', true)
    on conflict (adim) do nothing;
  end if;
exception when others then raise notice 'borsa_etki zamanlanamadı: %', sqlerrm;
end $z$;
