-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 175) AFİŞ STÜDYOSU VE REKLAM PANOLARI (07.11.2026)
--
--  • Oyuncular, partiler, dernekler, şirketler ve gazeteler afiş tasarlar (oyun.afis).
--    Tasarım resim değil, küçük bir JSON tarifidir; her telefonda aynı SVG çizilir.
--    Bu yüzden yükleme/depolama yükü yoktur ve uygunsuz görsel yüklenemez.
--  • Afiş, il panolarında ya da ülke genelindeki dev panolarda parası ödenen süre kadar yayınlanır
--    (oyun.pano_yayin). İl başına pano sayısı nüfusa göre 2–6, ülke geneli 3 dev panodur.
--    Bütün panolar doluysa yayın sıraya girer (en geç 7 gün sonra başlar).
--  • Fiyat: il nüfusu ve kişi başı gelir, o anki doluluk, seçim sezonu, oyun fiyat endeksi ve
--    belediye başkanının belirlediği belediye reklam tarifesi (0,5x–2x).
--  • Gelir: il panosu kirası o ilin belediye kasasına, ülke geneli panolar Hazine'ye
--    (Harçlar, komisyonlar ve ücretler kalemi) gider.
--  • Seçim günü propaganda yasağı: oy verme saatlerinde parti ve aday reklamları gösterilmez.
--  • Afişin altına herkesin göreceği künye eklenir: "Ödeyen: …".
--  • Şikâyetleri yönetici ve "sikayet" yetkili moderatörler inceler; gerekirse kalan süre iade edilir.
--  • Ayarlar Süper Yönetici Portalı'ndan (Ekonomi grubu) kod yazmadan değiştirilebilir.
--
--  Oyuncu verisini silmez veya sıfırlamaz. Tekrar çalıştırmak güvenlidir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists oyun.pano_ayar (
  id               int primary key default 1 check (id = 1),
  acik             boolean not null default true,
  il_taban         numeric not null default 6000,     -- 1 milyon nüfus, 15.000 $ kişi başı gelirli il için günlük ₺
  ulusal_gunluk    numeric not null default 90000,    -- ülke geneli dev pano günlük ₺
  en_uzun_gun      int not null default 30,
  secim_carpan     numeric not null default 1.35,     -- oy verme başlangıcına 72 saatten az kala
  doluluk_carpan   numeric not null default 0.6,      -- bütün panolar doluyken fiyat (1 + bu) katı
  secim_gunu_yasak boolean not null default true,
  ulusal_slot      smallint not null default 3,
  sira_gun         int not null default 7              -- dolu panoda en fazla kaç gün sonrasına sıra verilir
);
insert into oyun.pano_ayar (id) values (1) on conflict (id) do nothing;
alter table oyun.pano_ayar enable row level security;

create table if not exists oyun.afis (
  id          bigint generated always as identity primary key,
  sahip_tur   text not null check (sahip_tur in ('oyuncu', 'parti', 'dernek', 'sirket', 'gazete')),
  sahip_id    bigint,
  sahip_user  uuid,
  olusturan   uuid not null,
  ad          text not null,
  tasarim     jsonb not null,
  olusturma   timestamptz not null default now(),
  guncelleme  timestamptz not null default now(),
  silindi     boolean not null default false
);
create index if not exists afis_sahip on oyun.afis (sahip_tur, sahip_id) where not silindi;
create index if not exists afis_sahip_user on oyun.afis (sahip_user) where not silindi;
alter table oyun.afis enable row level security;

create table if not exists oyun.pano_yayin (
  id              bigint generated always as identity primary key,
  afis_id         bigint references oyun.afis(id),
  afis_ad         text,
  tasarim         jsonb not null,
  sahip_tur       text not null,
  sahip_id        bigint,
  sahip_user      uuid,
  sahip_ad        text not null,
  siyasi          boolean not null default false,
  odeyen          uuid not null,
  odeme_tur       text not null,
  kapsam          text not null check (kapsam in ('il', 'ulke')),
  il_id           smallint,
  slot            smallint not null,
  bas             timestamptz not null,
  bit             timestamptz not null,
  gun             int not null,
  gunluk          numeric not null,
  tutar           numeric not null,
  durum           text not null default 'aktif' check (durum in ('aktif', 'bitti', 'kaldirildi')),
  gosterim        int not null default 0,
  begeni          int not null default 0,
  bas_bildirim    boolean not null default false,
  kaldiran        uuid,
  kaldirma_neden  text,
  iade            numeric not null default 0,
  olusturma       timestamptz not null default now()
);
create index if not exists pano_yayin_yer on oyun.pano_yayin (kapsam, il_id, slot, bit) where durum = 'aktif';
create index if not exists pano_yayin_odeyen on oyun.pano_yayin (odeyen, id desc);
create index if not exists pano_yayin_sahip on oyun.pano_yayin (sahip_tur, sahip_id, id desc);
alter table oyun.pano_yayin enable row level security;

create table if not exists oyun.pano_gorme (
  yayin_id bigint not null,
  user_id  uuid not null,
  gun      date not null,
  primary key (yayin_id, user_id, gun)
);
alter table oyun.pano_gorme enable row level security;

create table if not exists oyun.pano_begeni (
  yayin_id bigint not null,
  user_id  uuid not null,
  zaman    timestamptz not null default now(),
  primary key (yayin_id, user_id)
);
alter table oyun.pano_begeni enable row level security;

create table if not exists oyun.pano_sikayet (
  id       bigint generated always as identity primary key,
  yayin_id bigint not null,
  user_id  uuid not null,
  neden    text not null,
  zaman    timestamptz not null default now(),
  durum    text not null default 'acik' check (durum in ('acik', 'kapandi')),
  unique (yayin_id, user_id)
);
alter table oyun.pano_sikayet enable row level security;

create table if not exists oyun.pano_il_ayar (
  il_id      smallint primary key,
  carpan     numeric not null default 1 check (carpan between 0.5 and 2),
  guncelleyen uuid,
  zaman      timestamptz
);
alter table oyun.pano_il_ayar enable row level security;

-- ---------------------------------------------------------------------
-- 2) YARDIMCILAR
-- ---------------------------------------------------------------------
create or replace function oyun.pano_bugun() returns date language sql stable set search_path = '' as $$
  select (now() at time zone 'Europe/Istanbul')::date
$$;

-- İl başına pano sayısı nüfusa göre; ülke geneli ayardan.
create or replace function oyun.pano_slot(p_kapsam text, p_il smallint) returns int
language sql stable set search_path = '' as $$
  select case when p_kapsam = 'ulke' then (select greatest(1, a.ulusal_slot) from oyun.pano_ayar a where a.id = 1)
    else coalesce((select case when e.nufus < 300000 then 2 when e.nufus < 1000000 then 3 when e.nufus < 2500000 then 4
                                when e.nufus < 5000000 then 5 else 6 end
                     from oyun.il_ekonomi e where e.il_id = p_il), 2) end
$$;

-- Oy verme başlangıcına 72 saatten az kalan ya da süren seçim var mı?
-- Ara seçim (hedef_il_id dolu) yalnız o ilin panolarını etkiler; genel seçim bütün panoları.
create or replace function oyun.pano_secim_sezonu(p_kapsam text default 'ulke', p_il smallint default null) returns boolean
language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.secimler s
                  where s.tur in ('mv', 'bel', 'cb', 'cb2')
                    and coalesce(s.durum, '') <> 'tamam' and coalesce(s.durum, '') not like 'iptal%'
                    and s.oy_bas is not null and s.oy_bit > now() and s.oy_bas < now() + interval '72 hours'
                    and (s.hedef_il_id is null or (p_kapsam = 'il' and s.hedef_il_id = p_il)))
$$;

-- Oy verme saatlerinde siyasi reklam yasağı (YSK propaganda yasağı)
create or replace function oyun.pano_secim_yasagi(p_kapsam text default 'ulke', p_il smallint default null) returns boolean
language sql stable set search_path = '' as $$
  select coalesce((select a.secim_gunu_yasak from oyun.pano_ayar a where a.id = 1), true)
     and exists (select 1 from oyun.secimler s
                  where s.tur in ('mv', 'bel', 'cb', 'cb2')
                    and coalesce(s.durum, '') <> 'tamam' and coalesce(s.durum, '') not like 'iptal%'
                    and now() >= s.oy_bas and now() < s.oy_bit
                    and (s.hedef_il_id is null or (p_kapsam = 'il' and s.hedef_il_id = p_il)))
$$;

-- Günlük fiyat ve çarpanları
create or replace function oyun.pano_fiyat(p_kapsam text, p_il smallint) returns jsonb
language plpgsql stable set search_path = '' as $$
declare a oyun.pano_ayar; n int; dolu int; nuf numeric; gs numeric; carp numeric := 1; baz numeric; endeks numeric; sezon boolean; g numeric;
begin
  select * into a from oyun.pano_ayar where id = 1;
  n := oyun.pano_slot(p_kapsam, p_il);
  select count(distinct y.slot) into dolu from oyun.pano_yayin y
   where y.durum = 'aktif' and y.kapsam = p_kapsam and y.il_id is not distinct from (case when p_kapsam = 'il' then p_il end)
     and y.bas <= now() and y.bit > now() and y.slot <= n;
  if p_kapsam = 'il' then
    select e.nufus, e.gsyh_kisi_usd into nuf, gs from oyun.il_ekonomi e where e.il_id = p_il;
    nuf := greatest(coalesce(nuf, 500000), 50000); gs := greatest(coalesce(gs, 12000), 5000);
    select coalesce(i.carpan, 1) into carp from oyun.pano_il_ayar i where i.il_id = p_il;
    carp := coalesce(carp, 1);
    baz := a.il_taban * power(nuf / 1000000.0, 0.55) * power(gs / 15000.0, 0.6);
  else
    baz := a.ulusal_gunluk;
  end if;
  endeks := greatest(coalesce((select u.endeks from oyun.ulke u where u.id = 1), 1), 0.5);
  sezon := oyun.pano_secim_sezonu(p_kapsam, p_il);
  g := baz * endeks * carp * (1 + a.doluluk_carpan * dolu::numeric / greatest(n, 1)) * (case when sezon then a.secim_carpan else 1 end);
  g := greatest(500, round(g / 50) * 50);
  return jsonb_build_object('gunluk', g, 'baz', round(baz), 'endeks', round(endeks, 4), 'belediye_carpan', carp,
    'dolu', dolu, 'slot', n, 'doluluk', round(dolu::numeric / greatest(n, 1), 2), 'sezon', sezon,
    'sezon_carpan', a.secim_carpan, 'doluluk_carpan', a.doluluk_carpan);
end $$;

create or replace function oyun.pano_indirim(p_gun int) returns numeric language sql immutable set search_path = '' as $$
  select case when p_gun >= 30 then 0.25 when p_gun >= 14 then 0.18 when p_gun >= 7 then 0.10 when p_gun >= 3 then 0.04 else 0 end
$$;

-- En erken boşalan pano (slot) ve boşalma anı
create or replace function oyun.pano_sonraki_bos(p_kapsam text, p_il smallint) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('slot', q.s, 'bos', q.bos)
    from (select s::smallint s,
                 greatest(now(), coalesce((select max(y.bit) from oyun.pano_yayin y
                                            where y.durum = 'aktif' and y.kapsam = p_kapsam and y.slot = s
                                              and y.il_id is not distinct from (case when p_kapsam = 'il' then p_il end)), now())) bos
            from generate_series(1, oyun.pano_slot(p_kapsam, p_il)) s
           order by 2, 1 limit 1) q
$$;

-- Tasarım yetkisi: sahibin adını döner, yetki yoksa hata verir.
create or replace function oyun.pano_tasarim_yetki(u uuid, p_tur text, p_id bigint) returns text
language plpgsql stable security definer set search_path = '' as $$
declare ad text;
begin
  if p_tur = 'oyuncu' then
    select p.kad into ad from oyun.profiller p where p.id = u;
  elsif p_tur = 'parti' then
    select pa.ad into ad from oyun.partiler pa where pa.id = p_id and not pa.kapali
       and (pa.gb = u or pa.gb_vekil = u or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = u));
    if ad is null then raise exception 'Parti afişini genel başkan, genel başkan vekili ve genel başkan yardımcıları hazırlayabilir.'; end if;
  elsif p_tur = 'dernek' then
    select d.ad into ad from oyun.dernekler d where d.id = p_id and not d.kapali
       and (d.baskan = u or exists (select 1 from oyun.dernek_uyeler x where x.dernek_id = d.id and x.user_id = u and x.rol in ('baskan', 'yonetim')));
    if ad is null then raise exception 'Dernek afişini başkan ve yönetim kurulu hazırlayabilir.'; end if;
  elsif p_tur = 'sirket' then
    select s.ad into ad from oyun.sirketler s where s.id = p_id and s.aktif
       and (s.yonetici = u or s.kurucu = u or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = u and o.pay > 0));
    if ad is null then raise exception 'Şirket afişini şirketin yöneticisi ve ortakları hazırlayabilir.'; end if;
  elsif p_tur = 'gazete' then
    select g.ad into ad from oyun.oyuncu_gazeteleri g where g.id = p_id and coalesce(g.aktif, true) and g.sahip = u;
    if ad is null then raise exception 'Gazete afişini gazetenin sahibi hazırlayabilir.'; end if;
  else
    raise exception 'Geçersiz afiş sahibi.';
  end if;
  if ad is null then raise exception 'Önce profilini oluştur.'; end if;
  return ad;
end $$;

-- Kasadan ödeme yetkisi (tasarımdan daha dar)
create or replace function oyun.pano_odeme_yetki(u uuid, p_tur text, p_id bigint) returns boolean
language sql stable security definer set search_path = '' as $$
  select case p_tur
    when 'parti' then exists (select 1 from oyun.partiler pa where pa.id = p_id and not pa.kapali and (pa.gb = u or pa.gb_vekil = u))
    when 'dernek' then exists (select 1 from oyun.dernekler d where d.id = p_id and not d.kapali
                                 and (d.baskan = u or exists (select 1 from oyun.dernek_uyeler x where x.dernek_id = d.id and x.user_id = u and x.rol = 'baskan')))
    when 'sirket' then exists (select 1 from oyun.sirketler s where s.id = p_id and s.aktif
                                 and (s.yonetici = u
                                      or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = u and o.pay >= 50)
                                      or (s.kurucu = u and not exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id <> u and o.pay > 0))))
    when 'gazete' then exists (select 1 from oyun.oyuncu_gazeteleri g where g.id = p_id and coalesce(g.aktif, true) and g.sahip = u)
    else false end
$$;

-- Oyuncunun adına afiş hazırlayabileceği hesaplar
create or replace function oyun.pano_kaynaklar(u uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(q order by q.sira, q.ad), '[]'::jsonb) from (
    select 0 sira, 'oyuncu' tur, null::bigint id, p.kad ad, coalesce(c.para, 0) kasa, true odeme, pr.renk renk, pr.amblem amblem, pr.kisa kisa
      from oyun.profiller p left join oyun.cuzdan c on c.user_id = p.id left join oyun.partiler pr on pr.id = p.parti_id
     where p.id = u
    union all
    select 1, 'parti', pa.id, pa.ad, pa.kasa, coalesce(pa.gb = u or pa.gb_vekil = u, false), pa.renk, pa.amblem, pa.kisa
      from oyun.partiler pa
     where not pa.kapali and (pa.gb = u or pa.gb_vekil = u or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = u))
    union all
    select 2, 'dernek', d.id, d.ad, d.kasa, oyun.pano_odeme_yetki(u, 'dernek', d.id), null, null, null
      from oyun.dernekler d
     where not d.kapali and (d.baskan = u or exists (select 1 from oyun.dernek_uyeler x where x.dernek_id = d.id and x.user_id = u and x.rol in ('baskan', 'yonetim')))
    union all
    select 3, 'sirket', s.id, s.ad, s.kasa, oyun.pano_odeme_yetki(u, 'sirket', s.id), null, null, s.sektor
      from oyun.sirketler s
     where s.aktif and (s.yonetici = u or s.kurucu = u or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = u and o.pay > 0))
    union all
    select 4, 'gazete', g.id, g.ad, g.kasa, true, null, null, null
      from oyun.oyuncu_gazeteleri g where coalesce(g.aktif, true) and g.sahip = u
  ) q
$$;

-- Afiş tarifinin doğrulanması: yalnız bilinen öğe türleri, kısa yazılar, geçerli renkler, küfür yok.
create or replace function oyun.afis_dogrula(p jsonb) returns jsonb
language plpgsql stable set search_path = '' as $$
declare og jsonb; x jsonb; k text; v jsonb; metin text := ''; m text; parca jsonb;
begin
  if p is null or jsonb_typeof(p) <> 'object' then raise exception 'Afiş tasarımı okunamadı.'; end if;
  if octet_length(p::text) > 24000 then raise exception 'Afiş tasarımı çok büyük. Bazı öğeleri silip yeniden dene.'; end if;
  og := coalesce(p -> 'ogeler', '[]'::jsonb);
  if jsonb_typeof(og) <> 'array' then raise exception 'Afiş öğeleri okunamadı.'; end if;
  if jsonb_array_length(og) > 32 then raise exception 'Bir afişte en fazla 32 öğe olabilir.'; end if;
  for parca in select value from jsonb_array_elements(og || jsonb_build_array(coalesce(p -> 'zemin', '{}'::jsonb), coalesce(p -> 'efekt', '{}'::jsonb))) loop
    if jsonb_typeof(parca) <> 'object' then raise exception 'Afiş öğesi okunamadı.'; end if;
    for k, v in select key, value from jsonb_each(parca) loop
      if k !~ '^[a-z0-9_]{1,16}$' then raise exception 'Afişte geçersiz alan var.'; end if;
      if k = 'm' then
        if jsonb_typeof(v) <> 'string' then raise exception 'Afiş yazısı okunamadı.'; end if;
        m := v #>> '{}';
        if length(m) > 160 then raise exception 'Afişteki bir yazı en fazla 160 karakter olabilir.'; end if;
        metin := metin || ' ' || m;
      elsif jsonb_typeof(v) = 'string' then
        if k in ('renk', 'arka', 'kenar', 'kontur', 'r1', 'r2', 'r3') then
          if (v #>> '{}') !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Afişte geçersiz renk var.'; end if;
        elsif k = 'kod' then
          if (v #>> '{}') !~ '^[0-9]{1,2}(-[0-9]{1,2}){5,6}$' then raise exception 'Afişteki portre okunamadı.'; end if;
        elsif (v #>> '{}') !~ '^[a-z0-9_]{1,24}$' then
          raise exception 'Afişte geçersiz seçenek var.';
        end if;
      elsif jsonb_typeof(v) not in ('number', 'boolean', 'null') then
        raise exception 'Afişte geçersiz alan var.';
      end if;
    end loop;
    if parca ? 't' and (parca ->> 't') not in ('metin', 'amblem', 'portre', 'sekil', 'ikon') then
      raise exception 'Afişte bilinmeyen öğe var.';
    end if;
  end loop;
  if length(metin) > 700 then raise exception 'Afişteki yazılar toplam 700 karakteri geçemez.'; end if;
  if oyun.kufurlu(metin) then raise exception 'Afişte uygunsuz bir ifade var. Hakaret ve küfür yasaktır.'; end if;
  return p;
end $$;

-- Ödemeyi alır (eksi) ya da iade eder (artı). Kayıtlar her kasanın kendi defterine yazılır.
create or replace function oyun.pano_odeme(p_odeme text, p_tur text, p_id bigint, u uuid, p_tutar numeric, p_aciklama text)
returns void language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi();
begin
  if p_tutar = 0 then return; end if;
  if p_odeme = 'oyuncu' then
    update oyun.cuzdan set para = para + p_tutar where user_id = u and para + p_tutar >= 0;
    if not found then raise exception 'Cüzdanında yeterli para yok. Gereken: % ₺', to_char(-p_tutar, 'FM999G999G999G990'); end if;
    insert into oyun.hesap_hareket (user_id, zaman, tutar, tur, aciklama) values (u, t, p_tutar, case when p_tutar < 0 then 'gider' else 'gelir' end, p_aciklama);
  elsif p_tur = 'parti' then
    update oyun.partiler set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Parti kasası yetersiz. Gereken: % ₺', to_char(-p_tutar, 'FM999G999G999G990'); end if;
    insert into oyun.parti_hareket (parti_id, zaman, tutar, aciklama, tur) values (p_id, t, p_tutar, p_aciklama, case when p_tutar < 0 then 'gider' else 'gelir' end);
  elsif p_tur = 'dernek' then
    update oyun.dernekler set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Dernek kasası yetersiz. Gereken: % ₺', to_char(-p_tutar, 'FM999G999G999G990'); end if;
    insert into oyun.dernek_hareket (dernek_id, zaman, tutar, tur, aciklama, user_id) values (p_id, t, p_tutar, case when p_tutar < 0 then 'gider' else 'gelir' end, p_aciklama, u);
  elsif p_tur = 'sirket' then
    update oyun.sirketler set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Şirket kasası yetersiz. Gereken: % ₺', to_char(-p_tutar, 'FM999G999G999G990'); end if;
    insert into oyun.sirket_hareket (sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (p_id, t, p_tutar, p_aciklama, 0, greatest(-p_tutar, 0), 0);
  elsif p_tur = 'gazete' then
    update oyun.oyuncu_gazeteleri set kasa = kasa + p_tutar where id = p_id and kasa + p_tutar >= 0;
    if not found then raise exception 'Gazete kasası yetersiz. Gereken: % ₺', to_char(-p_tutar, 'FM999G999G999G990'); end if;
    insert into oyun.gazete_hareket (gazete_id, zaman, tutar, tur, aciklama) values (p_id, t, p_tutar, case when p_tutar < 0 then 'gider' else 'gelir' end, p_aciklama);
  else
    raise exception 'Geçersiz ödeme kaynağı.';
  end if;
end $$;

-- Kira gelirini belediyeye ya da Hazine'ye yazar (iade için eksi tutar).
create or replace function oyun.pano_gelir(p_kapsam text, p_il smallint, p_tutar numeric, p_aciklama text)
returns void language plpgsql security definer set search_path = '' as $$
declare kur numeric := nullif(oyun.pazar_tl_milyar(), 0);
begin
  if p_tutar = 0 or kur is null then return; end if;
  if p_kapsam = 'il' then
    update oyun.il_durum set kasa = coalesce(kasa, 0) + p_tutar / kur where il_id = p_il;
    insert into oyun.belediye_sehir_hareket (il_id, tur, tutar, aciklama, zaman)
    values (p_il, case when p_tutar > 0 then 'reklam_geliri' else 'reklam_iadesi' end, p_tutar / kur, p_aciklama, oyun.simdi());
  else
    perform oyun.hazine_kaydet(case when p_tutar > 0 then 'harc_ucret' else 'diger_gider' end, p_tutar / kur, p_aciklama);
  end if;
end $$;

create or replace function oyun.pano_mod_mu(p oyun.profiller) returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(p.yonetici, false) or exists (select 1 from oyun.moderatorler m where m.user_id = p.id and 'sikayet' = any (m.yetkiler))
$$;

-- Bir yayının oyuncuya gösterilecek hâli
create or replace function oyun.pano_json(y oyun.pano_yayin, u uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', y.id, 'afis_id', y.afis_id, 'ad', y.afis_ad, 'tasarim', y.tasarim,
    'sahip_tur', y.sahip_tur, 'sahip_id', y.sahip_id, 'sahip_ad', y.sahip_ad,
    'sahip_renk', case when y.sahip_tur = 'parti' then (select pa.renk from oyun.partiler pa where pa.id = y.sahip_id) end,
    'kapsam', y.kapsam, 'il_id', y.il_id, 'il', (select i.ad from oyun.iller i where i.id = y.il_id), 'slot', y.slot,
    'bas', y.bas, 'bit', y.bit, 'gun', y.gun, 'durum', y.durum, 'siyasi', y.siyasi,
    'gosterim', y.gosterim, 'begeni', y.begeni,
    'begendim', exists (select 1 from oyun.pano_begeni b where b.yayin_id = y.id and b.user_id = u),
    'sikayet_ettim', exists (select 1 from oyun.pano_sikayet s where s.yayin_id = y.id and s.user_id = u))
$$;

-- ---------------------------------------------------------------------
-- 3) OYUNCU İŞLEMLERİ (RPC)
-- ---------------------------------------------------------------------

-- Bir ilin (varsayılan: oyuncunun ili) ve ülke genelinin yayındaki reklamları. Benzersiz görüntüleme sayar.
create or replace function public.pano_vitrin(p_il integer default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); il smallint; yasak_ulke boolean := oyun.pano_secim_yasagi('ulke', null); yasak_il boolean;
  bugun date := oyun.pano_bugun(); ids bigint[]; sonuc jsonb; gizli int;
begin
  il := coalesce(p_il, p.il_id)::smallint;
  if not exists (select 1 from oyun.iller i where i.id = il) then il := p.il_id; end if;
  yasak_il := oyun.pano_secim_yasagi('il', il);
  select array_agg(y.id order by y.kapsam desc, y.slot)
           filter (where not (y.siyasi and ((y.kapsam = 'ulke' and yasak_ulke) or (y.kapsam = 'il' and yasak_il)))),
         count(*) filter (where y.siyasi and ((y.kapsam = 'ulke' and yasak_ulke) or (y.kapsam = 'il' and yasak_il)))
    into ids, gizli
    from oyun.pano_yayin y
   where y.durum = 'aktif' and y.bas <= now() and y.bit > now()
     and (y.kapsam = 'ulke' or (y.kapsam = 'il' and y.il_id = il));
  ids := coalesce(ids, '{}');
  with yeni as (
    insert into oyun.pano_gorme (yayin_id, user_id, gun)
    select x, p.id, bugun from unnest(ids) x
    on conflict do nothing returning yayin_id)
  update oyun.pano_yayin y set gosterim = y.gosterim + 1 where y.id in (select yayin_id from yeni);
  select jsonb_build_object(
    'il_id', il, 'il', (select i.ad from oyun.iller i where i.id = il),
    'acik', (select a.acik from oyun.pano_ayar a where a.id = 1),
    'yasak', yasak_ulke or yasak_il, 'gizlenen', coalesce(gizli, 0),
    'ulke', coalesce((select jsonb_agg(oyun.pano_json(y, p.id) order by y.slot) from oyun.pano_yayin y where y.id = any (ids) and y.kapsam = 'ulke'), '[]'::jsonb),
    'yerel', coalesce((select jsonb_agg(oyun.pano_json(y, p.id) order by y.slot) from oyun.pano_yayin y where y.id = any (ids) and y.kapsam = 'il'), '[]'::jsonb),
    'fiyat_il', oyun.pano_fiyat('il', il), 'fiyat_ulke', oyun.pano_fiyat('ulke', null),
    'simdi', now())
  into sonuc;
  return sonuc;
end $$;

-- Reklam panoları ana ekranı
create or replace function public.pano_merkez() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); kay jsonb := oyun.pano_kaynaklar(p.id); a oyun.pano_ayar; v_mod boolean := oyun.pano_mod_mu(p);
  bel jsonb;
begin
  select * into a from oyun.pano_ayar where id = 1;
  select jsonb_build_object('il_id', m.il_id, 'il', i.ad, 'carpan', coalesce(pi.carpan, 1), 'son_degisim', pi.zaman,
           'gelir_7', coalesce((select sum(y.tutar) from oyun.pano_yayin y where y.kapsam = 'il' and y.il_id = m.il_id and y.olusturma > now() - interval '7 days'), 0),
           'gelir_toplam', coalesce((select sum(y.tutar - y.iade) from oyun.pano_yayin y where y.kapsam = 'il' and y.il_id = m.il_id), 0))
    into bel
    from oyun.makamlar m join oyun.iller i on i.id = m.il_id left join oyun.pano_il_ayar pi on pi.il_id = m.il_id
   where m.user_id = p.id and m.tur = 'bel' and m.bit is null limit 1;
  return jsonb_build_object(
    'ayar', jsonb_build_object('acik', a.acik, 'en_uzun_gun', a.en_uzun_gun, 'secim_gunu_yasak', a.secim_gunu_yasak,
                               'secim_carpan', a.secim_carpan, 'doluluk_carpan', a.doluluk_carpan, 'sira_gun', a.sira_gun,
                               'il_taban', a.il_taban, 'ulusal_gunluk', a.ulusal_gunluk, 'ulusal_slot', a.ulusal_slot),
    'simdi', now(), 'sezon', oyun.pano_secim_sezonu('ulke', null), 'yasak', oyun.pano_secim_yasagi('ulke', null),
    'il_id', p.il_id, 'kaynaklar', kay, 'moderator', v_mod, 'belediye', bel,
    'afisler', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'ad', f.ad, 'sahip_tur', f.sahip_tur, 'sahip_id', f.sahip_id,
                      'tasarim', f.tasarim, 'guncelleme', f.guncelleme,
                      'yayinda', exists (select 1 from oyun.pano_yayin y where y.afis_id = f.id and y.durum = 'aktif'))
                      order by f.guncelleme desc)
                 from (select * from oyun.afis f
                        where not f.silindi
                          and ((f.sahip_tur = 'oyuncu' and f.sahip_user = p.id)
                               or exists (select 1 from jsonb_array_elements(kay) k
                                           where k ->> 'tur' = f.sahip_tur and k ->> 'tur' <> 'oyuncu' and (k ->> 'id')::bigint = f.sahip_id))
                        order by f.guncelleme desc limit 60) f), '[]'::jsonb),
    'yayinlarim', coalesce((select jsonb_agg(oyun.pano_json(y, p.id) || jsonb_build_object('tutar', y.tutar, 'iade', y.iade, 'kaldirma_neden', y.kaldirma_neden,
                      'odeme_tur', y.odeme_tur) order by y.id desc)
                 from oyun.pano_yayin y
                where y.id in (select z.id from oyun.pano_yayin z
                                where z.odeyen = p.id
                                   or (z.sahip_tur = 'oyuncu' and z.sahip_user = p.id)
                                   or exists (select 1 from jsonb_array_elements(kay) k
                                               where k ->> 'tur' = z.sahip_tur and k ->> 'tur' <> 'oyuncu' and (k ->> 'id')::bigint = z.sahip_id)
                                order by z.id desc limit 40)), '[]'::jsonb),
    'iller', (select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad, 'fiyat', f, 'bos', oyun.pano_sonraki_bos('il', i.id)) order by i.ad)
                from oyun.iller i cross join lateral oyun.pano_fiyat('il', i.id) f),
    'ulke', jsonb_build_object('fiyat', oyun.pano_fiyat('ulke', null), 'bos', oyun.pano_sonraki_bos('ulke', null)),
    'sikayetler', case when v_mod then coalesce((select jsonb_agg(jsonb_build_object('yayin', oyun.pano_json(y, p.id), 'sayi', s.sayi, 'nedenler', s.nedenler) order by s.son desc)
                 from (select yayin_id, count(*) sayi, max(zaman) son, jsonb_agg(neden order by zaman desc) nedenler
                         from oyun.pano_sikayet where durum = 'acik' group by yayin_id) s
                 join oyun.pano_yayin y on y.id = s.yayin_id), '[]'::jsonb) else '[]'::jsonb end);
end $$;

-- Afiş kaydet (yeni ya da düzenleme)
create or replace function public.afis_kaydet(p_id bigint, p_sahip_tur text, p_sahip_id bigint, p_ad text, p_tasarim jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); f oyun.afis; ad text; yeni bigint; n int;
begin
  ad := btrim(coalesce(p_ad, ''));
  if length(ad) < 2 or length(ad) > 60 then raise exception 'Afiş adı 2–60 karakter olmalı.'; end if;
  if oyun.kufurlu(ad) then raise exception 'Afiş adında uygunsuz bir ifade var.'; end if;
  perform oyun.afis_dogrula(p_tasarim);
  if p_id is not null then
    select * into f from oyun.afis where id = p_id and not silindi for update;
    if f.id is null then raise exception 'Afiş bulunamadı.'; end if;
    perform oyun.pano_tasarim_yetki(p.id, f.sahip_tur, f.sahip_id);
    if f.sahip_tur = 'oyuncu' and f.sahip_user <> p.id then raise exception 'Bu afiş senin değil.'; end if;
    update oyun.afis set ad = btrim(p_ad), tasarim = p_tasarim, guncelleme = now() where id = f.id;
    return jsonb_build_object('id', f.id, 'tamam', true);
  end if;
  if p_sahip_tur = 'oyuncu' then p_sahip_id := null; end if;
  perform oyun.pano_tasarim_yetki(p.id, p_sahip_tur, p_sahip_id);
  select count(*) into n from oyun.afis
   where not silindi and sahip_tur = p_sahip_tur
     and ((p_sahip_tur = 'oyuncu' and sahip_user = p.id) or (p_sahip_tur <> 'oyuncu' and sahip_id = p_sahip_id));
  if n >= 40 then raise exception 'Bir hesabın en fazla 40 afişi olabilir. Kullanmadıklarını sil.'; end if;
  insert into oyun.afis (sahip_tur, sahip_id, sahip_user, olusturan, ad, tasarim)
  values (p_sahip_tur, p_sahip_id, case when p_sahip_tur = 'oyuncu' then p.id end, p.id, ad, p_tasarim)
  returning id into yeni;
  return jsonb_build_object('id', yeni, 'tamam', true);
end $$;

create or replace function public.afis_sil(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); f oyun.afis;
begin
  select * into f from oyun.afis where id = p_id and not silindi for update;
  if f.id is null then raise exception 'Afiş bulunamadı.'; end if;
  perform oyun.pano_tasarim_yetki(p.id, f.sahip_tur, f.sahip_id);
  if f.sahip_tur = 'oyuncu' and f.sahip_user <> p.id then raise exception 'Bu afiş senin değil.'; end if;
  update oyun.afis set silindi = true, guncelleme = now() where id = f.id;
  return jsonb_build_object('tamam', true, 'not', 'Yayındaki reklamlar süresi bitene kadar panoda kalır.');
end $$;

-- Fiyat teklifi (para çekmez)
create or replace function public.pano_teklif(p_kapsam text, p_il integer, p_gun integer) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.pano_ayar; il smallint; f jsonb; b jsonb; ind numeric; gun int; bas timestamptz; toplam numeric;
begin
  select * into a from oyun.pano_ayar where id = 1;
  if p_kapsam not in ('il', 'ulke') then raise exception 'Pano türü geçersiz.'; end if;
  gun := coalesce(p_gun, 0);
  if gun < 1 or gun > a.en_uzun_gun then raise exception 'Süre 1–% gün arasında olmalı.', a.en_uzun_gun; end if;
  il := case when p_kapsam = 'il' then p_il::smallint end;
  if p_kapsam = 'il' and not exists (select 1 from oyun.iller i where i.id = il) then raise exception 'İl bulunamadı.'; end if;
  f := oyun.pano_fiyat(p_kapsam, il); b := oyun.pano_sonraki_bos(p_kapsam, il);
  ind := oyun.pano_indirim(gun);
  toplam := round((f ->> 'gunluk')::numeric * gun * (1 - ind));
  bas := (b ->> 'bos')::timestamptz;
  return jsonb_build_object('kapsam', p_kapsam, 'il_id', il, 'il', (select i.ad from oyun.iller i where i.id = il),
    'gun', gun, 'fiyat', f, 'gunluk', (f ->> 'gunluk')::numeric, 'indirim', ind, 'toplam', toplam,
    'bas', bas, 'bit', bas + make_interval(days => gun), 'hemen', bas <= now() + interval '1 minute',
    'sira_dolu', bas > now() + make_interval(days => a.sira_gun), 'slot', (b ->> 'slot')::int,
    'gelir_yeri', case when p_kapsam = 'il' then (select i.ad from oyun.iller i where i.id = il) || ' Belediyesi kasası' else 'Hazine (harç ve ücret geliri)' end,
    'yasak_uyari', a.secim_gunu_yasak);
end $$;

-- Panoyu kirala: ödeme, gelir, sıra ve yayın kaydı tek işlemde.
create or replace function public.pano_kirala(p_afis bigint, p_kapsam text, p_il integer, p_gun integer, p_odeme_tur text, p_beklenen numeric default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.pano_ayar; f oyun.afis; sahip_ad text; il smallint; fy jsonb; b jsonb;
  ind numeric; gunluk numeric; toplam numeric; bas timestamptz; yid bigint; aciklama text; odeme text;
begin
  select * into a from oyun.pano_ayar where id = 1;
  if not a.acik then raise exception 'Reklam panoları şu anda kapalı.'; end if;
  if p_kapsam not in ('il', 'ulke') then raise exception 'Pano türü geçersiz.'; end if;
  if coalesce(p_gun, 0) < 1 or p_gun > a.en_uzun_gun then raise exception 'Süre 1–% gün arasında olmalı.', a.en_uzun_gun; end if;
  il := case when p_kapsam = 'il' then p_il::smallint end;
  if p_kapsam = 'il' and not exists (select 1 from oyun.iller i where i.id = il) then raise exception 'İl bulunamadı.'; end if;
  select * into f from oyun.afis where id = p_afis and not silindi;
  if f.id is null then raise exception 'Afiş bulunamadı.'; end if;
  sahip_ad := oyun.pano_tasarim_yetki(p.id, f.sahip_tur, f.sahip_id);
  if f.sahip_tur = 'oyuncu' and f.sahip_user <> p.id then raise exception 'Bu afiş senin değil.'; end if;
  perform oyun.afis_dogrula(f.tasarim);
  odeme := case when p_odeme_tur = 'oyuncu' or f.sahip_tur = 'oyuncu' then 'oyuncu' else 'kasa' end;
  if odeme = 'kasa' and not oyun.pano_odeme_yetki(p.id, f.sahip_tur, f.sahip_id) then
    raise exception 'Bu kasadan ödeme yapma yetkin yok. Kendi cüzdanından ödeyebilirsin.';
  end if;

  perform pg_advisory_xact_lock(hashtext('pano:' || p_kapsam || ':' || coalesce(il, 0)));
  fy := oyun.pano_fiyat(p_kapsam, il); b := oyun.pano_sonraki_bos(p_kapsam, il);
  gunluk := (fy ->> 'gunluk')::numeric; ind := oyun.pano_indirim(p_gun);
  toplam := round(gunluk * p_gun * (1 - ind));
  if p_beklenen is not null and toplam > p_beklenen * 1.001 then
    raise exception 'Fiyat değişti (bu arada pano kiralandı ya da seçim sezonu başladı). Yeni tutar: % ₺. Teklifi yenileyip tekrar dene.', to_char(toplam, 'FM999G999G999G990');
  end if;
  bas := (b ->> 'bos')::timestamptz;
  if bas > now() + make_interval(days => a.sira_gun) then
    raise exception 'Bu bölgedeki panolar % günden uzun süre dolu. Başka bir il ya da daha sonra dene.', a.sira_gun;
  end if;
  if bas < now() + interval '1 minute' then bas := now(); end if;

  insert into oyun.pano_yayin (afis_id, afis_ad, tasarim, sahip_tur, sahip_id, sahip_user, sahip_ad, siyasi, odeyen, odeme_tur,
                               kapsam, il_id, slot, bas, bit, gun, gunluk, tutar)
  values (f.id, f.ad, f.tasarim, f.sahip_tur, f.sahip_id, f.sahip_user, sahip_ad, f.sahip_tur in ('parti', 'oyuncu'), p.id, odeme,
          p_kapsam, il, (b ->> 'slot')::smallint, bas, bas + make_interval(days => p_gun), p_gun, gunluk, toplam)
  returning id into yid;

  aciklama := format('Reklam panosu #%s · %s · %s gün', yid,
                     case when p_kapsam = 'il' then (select i.ad from oyun.iller i where i.id = il) else 'Ülke geneli' end, p_gun);
  perform oyun.pano_odeme(odeme, f.sahip_tur, f.sahip_id, p.id, -toplam, aciklama);
  perform oyun.pano_gelir(p_kapsam, il, toplam, format('%s · %s ₺ · %s', aciklama, to_char(toplam, 'FM999G999G999G990'), sahip_ad));

  return jsonb_build_object('tamam', true, 'id', yid, 'bas', bas, 'bit', bas + make_interval(days => p_gun), 'tutar', toplam,
    'hemen', bas <= now() + interval '1 minute', 'slot', (b ->> 'slot')::int,
    'il', (select i.ad from oyun.iller i where i.id = il), 'kapsam', p_kapsam);
end $$;

create or replace function public.pano_begen(p_yayin bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); y oyun.pano_yayin; var boolean;
begin
  select * into y from oyun.pano_yayin where id = p_yayin and durum = 'aktif' for update;
  if y.id is null then raise exception 'Reklam yayında değil.'; end if;
  delete from oyun.pano_begeni where yayin_id = y.id and user_id = p.id;
  var := found;
  if var then
    update oyun.pano_yayin set begeni = greatest(0, begeni - 1) where id = y.id returning begeni into y.begeni;
  else
    insert into oyun.pano_begeni (yayin_id, user_id) values (y.id, p.id);
    update oyun.pano_yayin set begeni = begeni + 1 where id = y.id returning begeni into y.begeni;
  end if;
  return jsonb_build_object('begendim', not var, 'begeni', y.begeni);
end $$;

create or replace function public.pano_sikayet(p_yayin bigint, p_neden text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); y oyun.pano_yayin; n text := btrim(coalesce(p_neden, '')); r record;
begin
  select * into y from oyun.pano_yayin where id = p_yayin and durum = 'aktif';
  if y.id is null then raise exception 'Reklam yayında değil.'; end if;
  if length(n) < 10 or length(n) > 300 then raise exception 'Şikâyet gerekçesi 10–300 karakter olmalı.'; end if;
  insert into oyun.pano_sikayet (yayin_id, user_id, neden) values (y.id, p.id, n)
  on conflict (yayin_id, user_id) do update set neden = excluded.neden, zaman = now(), durum = 'acik';
  for r in select pr.id from oyun.profiller pr where pr.yonetici and pr.id <> p.id loop
    perform oyun.bildir(r.id, format('Reklam panosu şikâyeti: "%s" (%s). Reklam Panoları ekranındaki şikâyet listesinden inceleyebilirsin.', coalesce(y.afis_ad, 'Afiş'), y.sahip_ad), oyun.simdi());
  end loop;
  return jsonb_build_object('tamam', true);
end $$;

-- Belediye başkanı ilinin reklam tarifesini belirler (0,5x – 2x). 12 saatte bir değiştirilebilir.
create or replace function public.pano_il_tarife(p_il integer, p_carpan numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); c numeric := round(coalesce(p_carpan, 1), 2); son timestamptz;
begin
  if not exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'bel' and m.il_id = p_il and m.bit is null) then
    raise exception 'Reklam tarifesini yalnız ilin belediye başkanı belirleyebilir.';
  end if;
  if c < 0.5 or c > 2 then raise exception 'Tarife 0,5 ile 2 kat arasında olmalı.'; end if;
  select zaman into son from oyun.pano_il_ayar where il_id = p_il;
  if son is not null and son > now() - interval '12 hours' then
    raise exception 'Reklam tarifesi 12 saatte bir değiştirilebilir. Sonraki değişiklik: %', to_char((son + interval '12 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  insert into oyun.pano_il_ayar (il_id, carpan, guncelleyen, zaman) values (p_il, c, p.id, now())
  on conflict (il_id) do update set carpan = excluded.carpan, guncelleyen = excluded.guncelleyen, zaman = excluded.zaman;
  return jsonb_build_object('tamam', true, 'carpan', c, 'fiyat', oyun.pano_fiyat('il', p_il::smallint));
end $$;

-- Yayından kaldır: sahibi/ödeyen (iadesiz) ya da moderatör (isteğe bağlı kalan süre iadesi)
create or replace function public.pano_kaldir(p_yayin bigint, p_neden text, p_iade boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); y oyun.pano_yayin; v_mod boolean := oyun.pano_mod_mu(p); sahip boolean; n text := btrim(coalesce(p_neden, ''));
  oran numeric; v_iade numeric := 0;
begin
  select * into y from oyun.pano_yayin where id = p_yayin and durum = 'aktif' for update;
  if y.id is null then raise exception 'Reklam yayında değil.'; end if;
  sahip := y.odeyen = p.id or (y.sahip_tur = 'oyuncu' and y.sahip_user = p.id)
           or (y.sahip_tur <> 'oyuncu' and oyun.pano_odeme_yetki(p.id, y.sahip_tur, y.sahip_id));
  if not (v_mod or sahip) then raise exception 'Bu reklamı yalnız sahibi ya da moderatörler kaldırabilir.'; end if;
  if v_mod and not sahip then
    if length(n) < 10 then raise exception 'Kaldırma gerekçesi en az 10 karakter olmalı.'; end if;
  else
    p_iade := false; n := coalesce(nullif(n, ''), 'Sahibi yayından kaldırdı');
  end if;
  if p_iade then
    oran := greatest(0, least(1, extract(epoch from (y.bit - greatest(now(), y.bas))) / nullif(extract(epoch from (y.bit - y.bas)), 0)));
    v_iade := round(y.tutar * coalesce(oran, 0));
    if v_iade > 0 then
      perform oyun.pano_odeme(y.odeme_tur, y.sahip_tur, y.sahip_id, y.odeyen, v_iade, format('Reklam panosu #%s iadesi (kalan süre)', y.id));
      perform oyun.pano_gelir(y.kapsam, y.il_id, -v_iade, format('Reklam panosu #%s iadesi', y.id));
    end if;
  end if;
  update oyun.pano_yayin set durum = 'kaldirildi', bit = least(bit, now()), kaldiran = p.id, kaldirma_neden = n, iade = v_iade where id = y.id;
  update oyun.pano_sikayet set durum = 'kapandi' where yayin_id = y.id;
  if p.id <> y.odeyen then
    perform oyun.bildir(y.odeyen, format('Reklamın yayından kaldırıldı: "%s". Gerekçe: %s%s', coalesce(y.afis_ad, 'Afiş'), n,
      case when v_iade > 0 then format(' · Kalan süre için %s ₺ iade edildi.', to_char(v_iade, 'FM999G999G999G990')) else '' end), oyun.simdi());
  end if;
  return jsonb_build_object('tamam', true, 'iade', v_iade);
end $$;

-- Şikâyeti reddet (reklam kalır)
create or replace function public.pano_sikayet_kapat(p_yayin bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not oyun.pano_mod_mu(p) then raise exception 'Bu işlem moderatörler içindir.'; end if;
  update oyun.pano_sikayet set durum = 'kapandi' where yayin_id = p_yayin and durum = 'acik';
  return jsonb_build_object('tamam', true);
end $$;

-- ---------------------------------------------------------------------
-- 4) BAKIM (10 dakikada bir): biten yayınlar, sıradan yayına girenler, eski görüntüleme kayıtları
-- ---------------------------------------------------------------------
create or replace function oyun.pano_bakim() returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in update oyun.pano_yayin set durum = 'bitti' where durum = 'aktif' and bit <= now()
           returning id, odeyen, afis_ad, kapsam, il_id, gosterim, begeni loop
    perform oyun.bildir(r.odeyen, format('Reklam süresi doldu: "%s" %s panosunda %s kişiye ulaştı ve %s beğeni aldı. Yeniden yayınlamak için Reklam Panoları ekranına bak.',
      coalesce(r.afis_ad, 'Afiş'), case when r.kapsam = 'il' then (select i.ad from oyun.iller i where i.id = r.il_id) else 'ülke geneli' end,
      r.gosterim, r.begeni), oyun.simdi());
  end loop;
  for r in update oyun.pano_yayin set bas_bildirim = true
            where durum = 'aktif' and not bas_bildirim and bas <= now() and bas > olusturma + interval '5 minutes'
           returning id, odeyen, afis_ad, kapsam, il_id loop
    perform oyun.bildir(r.odeyen, format('Sıradaki reklamın yayına girdi: "%s" artık %s panosunda.',
      coalesce(r.afis_ad, 'Afiş'), case when r.kapsam = 'il' then (select i.ad from oyun.iller i where i.id = r.il_id) else 'ülke geneli' end), oyun.simdi());
  end loop;
  update oyun.pano_yayin set bas_bildirim = true where durum = 'aktif' and not bas_bildirim and bas <= now();
  delete from oyun.pano_gorme where gun < oyun.pano_bugun() - 60;
end $$;

do $zaman$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if not exists (select 1 from cron.job where jobname = 'reklam-panosu-bakim') then
      perform cron.schedule('reklam-panosu-bakim', '*/10 * * * *', 'select oyun.pano_bakim()');
    end if;
  end if;
exception when others then
  raise notice 'reklam-panosu-bakim zamanlanamadı: %', sqlerrm;
end
$zaman$;

-- ---------------------------------------------------------------------
-- 5) SÜPER YÖNETİCİ PORTALI: canlı ayarlar (kod yazmadan)
-- ---------------------------------------------------------------------
do $portal$
begin
  if to_regclass('oyun.yp_ayar_katalog') is not null then
    insert into oyun.yp_ayar_katalog (anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, risk, etki, sira) values
      ('pano.acik', 'oyun.pano_ayar', 'acik', '{"id":"1"}', 'ekonomi', 'Reklam panoları açık',
       'Kapalıyken yeni pano kiralanamaz; yayındaki reklamlar süreleri bitene kadar görünür.', 'evet_hayir', null, null, null, 'orta', 'Hemen: bir sonraki kiralamada.', 300),
      ('pano.il_taban', 'oyun.pano_ayar', 'il_taban', '{"id":"1"}', 'ekonomi', 'İl panosu taban fiyatı (günlük)',
       '1 milyon nüfuslu, kişi başı 15.000 $ gelirli bir ilde bir panonun günlük kirası. Diğer iller nüfus ve gelire göre buna oranlanır (İstanbul ≈ 6 kat, küçük iller ≈ 0,2 kat).', 'para', '₺', 500, 100000, 'orta', 'Yeni kiralamalarda.', 301),
      ('pano.ulusal_gunluk', 'oyun.pano_ayar', 'ulusal_gunluk', '{"id":"1"}', 'ekonomi', 'Ülke geneli dev pano (günlük)',
       'Bütün oyuncuların gördüğü ülke geneli dev panonun günlük kirası.', 'para', '₺', 5000, 2000000, 'orta', 'Yeni kiralamalarda.', 302),
      ('pano.ulusal_slot', 'oyun.pano_ayar', 'ulusal_slot', '{"id":"1"}', 'ekonomi', 'Ülke geneli dev pano sayısı',
       'Aynı anda yayında olabilecek ülke geneli reklam sayısı. Azaltırsan yayındaki reklamlar süreleri bitene kadar kalır.', 'tamsayi', 'pano', 1, 6, 'dusuk', 'Yeni kiralamalarda.', 303),
      ('pano.en_uzun_gun', 'oyun.pano_ayar', 'en_uzun_gun', '{"id":"1"}', 'ekonomi', 'En uzun kiralama süresi',
       'Bir seferde kiralanabilecek en uzun süre.', 'tamsayi', 'gün', 1, 90, 'dusuk', 'Yeni kiralamalarda.', 304),
      ('pano.secim_carpan', 'oyun.pano_ayar', 'secim_carpan', '{"id":"1"}', 'ekonomi', 'Seçim sezonu fiyat çarpanı',
       'Oy verme başlangıcına 72 saatten az kalınca bütün pano fiyatları bu katla çarpılır.', 'sayi', 'kat', 1, 3, 'dusuk', 'Yeni kiralamalarda.', 305),
      ('pano.doluluk_carpan', 'oyun.pano_ayar', 'doluluk_carpan', '{"id":"1"}', 'ekonomi', 'Doluluk zammı',
       'Bir bölgedeki bütün panolar doluyken fiyat (1 + bu değer) katına çıkar; yarı doluyken yarısı kadar.', 'sayi', 'kat', 0, 2, 'dusuk', 'Yeni kiralamalarda.', 306),
      ('pano.secim_gunu_yasak', 'oyun.pano_ayar', 'secim_gunu_yasak', '{"id":"1"}', 'ekonomi', 'Seçim günü propaganda yasağı',
       'Açıkken oy verme saatlerinde parti ve aday reklamları panolarda gösterilmez (süre işlemeye devam eder).', 'evet_hayir', null, null, null, 'dusuk', 'Hemen.', 307)
    on conflict (anahtar) do update set tablo = excluded.tablo, sutun = excluded.sutun, satir = excluded.satir, grup = excluded.grup,
      baslik = excluded.baslik, aciklama = excluded.aciklama, tur = excluded.tur, birim = excluded.birim, en_az = excluded.en_az,
      en_cok = excluded.en_cok, risk = excluded.risk, etki = excluded.etki, sira = excluded.sira, aktif = true;
  end if;
end
$portal$;

-- ---------------------------------------------------------------------
-- 6) YETKİLER (159_rpc_yuzey.sql izin listesinde de bu adlar var)
-- ---------------------------------------------------------------------
revoke all on function public.pano_vitrin(integer), public.pano_merkez(), public.afis_kaydet(bigint, text, bigint, text, jsonb),
  public.afis_sil(bigint), public.pano_teklif(text, integer, integer), public.pano_kirala(bigint, text, integer, integer, text, numeric),
  public.pano_begen(bigint), public.pano_sikayet(bigint, text), public.pano_il_tarife(integer, numeric),
  public.pano_kaldir(bigint, text, boolean), public.pano_sikayet_kapat(bigint) from public, anon;
grant execute on function public.pano_vitrin(integer), public.pano_merkez(), public.afis_kaydet(bigint, text, bigint, text, jsonb),
  public.afis_sil(bigint), public.pano_teklif(text, integer, integer), public.pano_kirala(bigint, text, integer, integer, text, numeric),
  public.pano_begen(bigint), public.pano_sikayet(bigint, text), public.pano_il_tarife(integer, numeric),
  public.pano_kaldir(bigint, text, boolean), public.pano_sikayet_kapat(bigint) to authenticated;
revoke all on function oyun.pano_odeme(text, text, bigint, uuid, numeric, text), oyun.pano_gelir(text, smallint, numeric, text),
  oyun.pano_bakim(), oyun.pano_kaynaklar(uuid), oyun.pano_tasarim_yetki(uuid, text, bigint), oyun.pano_odeme_yetki(uuid, text, bigint),
  oyun.pano_json(oyun.pano_yayin, uuid), oyun.pano_mod_mu(oyun.profiller) from public, anon, authenticated;
