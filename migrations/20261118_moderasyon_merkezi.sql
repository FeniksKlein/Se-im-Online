-- 18.11.2026 · MODERASYON MERKEZİ — uzmanlık birimleri, iş kuyrukları, dört göz yaptırım, oyuncu dosyası
-- Yayın ölçeği: 14+ moderatör, binlerce oyuncu. Tasarım ilkeleri:
--   • Her moderatörün TEMEL yetkisi "kayit" (başvuru kabul/ret); bu tetikleyiciyle zorunludur, kaldırılamaz.
--   • Her moderatör bir UZMANLIK BİRİMİNE bağlanır; birimin yetkileri otomatik verilir. Yönetici isterse ek yetki açar.
--   • Kuyruk ÜSTLENME: bir moderatör bir kaydı açınca 3 dk boyunca "X inceliyor" görünür; iki kişi aynı işi yapmaz.
--   • DÖRT GÖZ: hesap kapatma yetkisi olmayan moderatör "yaptırım talebi" açar, Yaptırım Kurulu onaylar.
--     Talebi açan kendi talebini onaylayamaz.
--   • OYUNCU DOSYASI: tek ekranda kimlik, kısıt geçmişi, şikâyetler, moderatör notları, bağlı hesaplar, MASAK kayıtları.
--   • SOHBET NÖBETİ: yalnız herkese açık kanallar (genel, Meclis, il). Parti, ittifak, kabine, özel grup ve özel
--     mesajlar nöbette görünmez (yalnız şikâyet edilirse şikâyet masasına düşer).
--   • Her işlem moderasyon günlüğüne yazılır; moderatör kendi günlüğünü, yönetici herkesinkini görür.
-- Oyuncu verisi değiştirilmez; yalnız yeni tablo/sütun/fonksiyon eklenir.

-- ---------------------------------------------------------------------
-- 1) Yetki kataloğu: "destek" eklendi (önceki 13 yetki aynen)
-- ---------------------------------------------------------------------
create or replace function oyun.mod_yetki_tanim()
returns table(kod text, ad text, aciklama text, sira integer)
language sql immutable set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $$
  values ('ozet',        'Özet',                    'Oyuncu sayısı, aktiflik, açık şikâyet gibi özet rakamları görür.', 1),
         ('sikayet',     'Şikâyetler ve sohbet nöbeti', 'Şikâyet edilen mesaj ve yayınları karara bağlar; herkese açık sohbetleri izler, uygunsuz mesajı gizler.', 2),
         ('sustur',      'Susturma',                'Oyuncuyu susturur, susturmayı kaldırır.', 3),
         ('hesap_kapat', 'Engelleme ve hesap kapatma', 'Oyuncuyu süreli ya da kalıcı engeller; yaptırım taleplerini onaylar.', 4),
         ('oyuncu_ara',  'Oyuncu inceleme',         'Oyuncu dosyasını (bilgi, kısıt geçmişi, son mesajlar, notlar) görür.', 5),
         ('eposta',      'E-posta görme',           'Oyuncu incelerken e-posta adresini de görür (kişisel veri; dikkatli ver).', 6),
         ('duyuru',      'Duyuru ve bildirim',      'Tüm oyunculara duyuru, seçtiği oyunculara bildirim gönderir.', 7),
         ('coklu_hesap', 'Çoklu hesap incelemesi',  'Aynı cihazdan açılan hesapları görür, gerçek kişi olanları onaylar.', 8),
         ('kurallar',    'Kurallar ve ayarlar',     'Vatandaşlık, parti kurma, teşkilat, havale ve banka kurallarını değiştirir.', 9),
         ('ekonomi',     'MASAK (ekonomi denetimi)', 'Şüpheli işlem bildirimlerini inceler; temiz, ihtar ya da el koyma kararı verir.', 10),
         ('para',        'Para ve kıdem',           'Oyunculara, bir ile, bir partiye ya da herkese para ve kıdem ekler veya çıkarır.', 11),
         ('makam',       'Görev verme ve alma',     'Oyuncuyu makama atar, görevden alır; parti görevlerini, ilini, partisini ve aday olma yasağını değiştirir.', 12),
         ('kayit',       'Kayıt onayı',             'Yeni oyuncu başvurularını (kullanıcı adı, ad soyad, il) inceler; oyuna kabul eder ya da gerekçeyle reddeder. Her moderatörde bulunur.', 13),
         ('destek',      'Destek talepleri',        'Oyuncuların destek taleplerini yanıtlar ve kapatır.', 14)
$$;

-- ---------------------------------------------------------------------
-- 2) Uzmanlık birimleri (14 moderatör = 7 birim × 2 kişi)
-- ---------------------------------------------------------------------
create or replace function oyun.mod_birim_tanim()
returns table(kod text, ad text, aciklama text, yetkiler text[], hedef integer, renk text, ikon text, sira integer)
language sql immutable set search_path to '' as $$
  values
  ('kayit',    'Kayıt ve Kimlik Masası',         'Yeni oyuncu başvurularını, ad soyad ve kullanıcı adı uygunluğunu denetler; gerçek siyasetçi ve kamuoyunca bilinen kişi adlarını ayıklar.', array['kayit','oyuncu_ara']::text[], 2, '#5b8def', 'kimlik', 1),
  ('sohbet',   'Sohbet ve Küfür Denetimi',       'Genel, Meclis ve il sohbetlerini nöbetle izler; küfür, hakaret, spam ve kışkırtmayı gizler, gerekirse susturur.', array['kayit','sikayet','sustur','oyuncu_ara']::text[], 2, '#e0a43a', 'sohbet', 2),
  ('sikayet',  'Şikâyet ve Destek Masası',       'Oyuncu şikâyetlerini karara bağlar, destek taleplerini yanıtlar.', array['kayit','sikayet','destek','oyuncu_ara']::text[], 2, '#c86cd8', 'sikayet', 3),
  ('masak',    'MASAK · Finans Denetimi',        'Şüpheli para hareketlerini, kredi-sermaye döngülerini, ani servetleri ve davet suistimallerini inceler.', array['kayit','ekonomi','oyuncu_ara','ozet']::text[], 2, '#3fb67a', 'masak', 4),
  ('secim',    'Seçim Güvenliği ve Çoklu Hesap', 'Aynı cihaz ve bağlantıdan açılan hesapları, oy ve parti hareketlerini izler; sahte hesapları ayıklar.', array['kayit','coklu_hesap','oyuncu_ara']::text[], 2, '#4fc1d6', 'sandik', 5),
  ('yaptirim', 'Yaptırım Kurulu',                'Ağır ihlallerde süreli ya da kalıcı engel kararı verir; diğer birimlerin yaptırım taleplerini onaylar ya da reddeder.', array['kayit','hesap_kapat','sustur','oyuncu_ara']::text[], 2, '#e5574f', 'terazi', 6),
  ('topluluk', 'Topluluk ve Duyuru',             'Duyuru ve bildirimleri yayımlar, yeni oyunculara rehberlik eder, topluluk iletişimini yürütür.', array['kayit','duyuru','oyuncu_ara']::text[], 2, '#f07f3c', 'megafon', 7)
$$;

-- Eski "ana görev" adları (16.11) uyumluluk için kalır; yeni birimler önce gelir.
create or replace function oyun.mod_ana_gorev_tanim()
returns table(kod text, ad text, aciklama text, yetkiler text[], sira integer)
language sql immutable set search_path to '' as $$
  select b.kod, b.ad, b.aciklama, b.yetkiler, b.sira from oyun.mod_birim_tanim() b
  union all
  select * from (values
    ('genel',   'Genel moderasyon (eski)',          'Şikâyetleri karara bağlar, sohbet ve yayın düzenini korur.', array['sikayet','sustur','oyuncu_ara']::text[], 101),
    ('finans',  'Finans denetimi (eski)',           'Kredi, sermaye, ani servet ve davet ödüllerini izler.', array['ekonomi','oyuncu_ara','ozet']::text[], 102),
    ('siyaset', 'Seçim ve siyaset gözetimi (eski)', 'Seçim dönemlerinde çoklu hesap, oy ve parti hareketlerini izler.', array['oyuncu_ara','coklu_hesap']::text[], 103),
    ('hukuk',   'Kural ihlali ve yaptırım (eski)',  'Kural ihlali yapan hesaplara süreli engel ve susturma uygular.', array['sustur','hesap_kapat','oyuncu_ara']::text[], 104),
    ('destek',  'Yeni oyuncu desteği (eski)',       'Yeni oyunculara yardım eder, hesap sorunlarını inceler.', array['oyuncu_ara','coklu_hesap']::text[], 105)
  ) x(kod, ad, aciklama, yetkiler, sira)
$$;

-- ---------------------------------------------------------------------
-- 3) Tablolar
-- ---------------------------------------------------------------------
alter table oyun.moderatorler add column if not exists rutbe text not null default 'moderator';
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'moderatorler_rutbe_kontrol') then
    alter table oyun.moderatorler add constraint moderatorler_rutbe_kontrol check (rutbe in ('moderator','kidemli','sorumlu'));
  end if;
end $c$;

-- Kayıt onayı her moderatörün temel yetkisidir
create or replace function oyun.tg_mod_kayit_zorunlu() returns trigger
language plpgsql set search_path to '' as $$
begin
  if not ('kayit' = any(coalesce(new.yetkiler, '{}'::text[]))) then
    new.yetkiler := array(select distinct x from unnest(coalesce(new.yetkiler, '{}'::text[]) || array['kayit']) x order by 1);
  end if;
  return new;
end $$;
drop trigger if exists mod_kayit_zorunlu on oyun.moderatorler;
create trigger mod_kayit_zorunlu before insert or update of yetkiler on oyun.moderatorler
  for each row execute function oyun.tg_mod_kayit_zorunlu();

create table if not exists oyun.mod_ustlenme(
  tur     text not null,
  anahtar text not null,
  user_id uuid not null,
  bitis   timestamptz not null,
  primary key (tur, anahtar)
);

create table if not exists oyun.mod_talep(
  id          bigserial primary key,
  tur         text not null check (tur in ('engel','sustur','eskalasyon')),
  hedef       uuid not null,
  sure        numeric,            -- engel: gün (null/0 = kalıcı) · sustur: saat
  gerekce     text not null,
  kanit       text,
  talep_eden  uuid not null,
  zaman       timestamptz not null default now(),
  durum       text not null default 'acik' check (durum in ('acik','onaylandi','reddedildi','geri_cekildi')),
  karar_veren uuid,
  karar_not   text,
  karar_zaman timestamptz
);
create index if not exists mod_talep_acik on oyun.mod_talep(zaman) where durum = 'acik';
create index if not exists mod_talep_hedef on oyun.mod_talep(hedef, zaman desc);
create index if not exists mod_talep_eden on oyun.mod_talep(talep_eden, zaman desc);

create table if not exists oyun.mod_not(
  id     bigserial primary key,
  hedef  uuid not null,
  yazan  uuid not null,
  metin  text not null,
  zaman  timestamptz not null default now()
);
create index if not exists mod_not_hedef on oyun.mod_not(hedef, zaman desc);

create index if not exists mod_kayit_kullanici on oyun.mod_kayit(user_id, zaman desc);
create index if not exists mod_kayit_hedef_ix on oyun.mod_kayit(lower(hedef), zaman desc);

do $r$
declare t text;
begin
  foreach t in array array['oyun.mod_ustlenme','oyun.mod_talep','oyun.mod_not'] loop
    execute format('alter table %s enable row level security', t);
    execute format('revoke all on %s from public, anon, authenticated', t);
  end loop;
end $r$;

-- ---------------------------------------------------------------------
-- 4) Yardımcılar
-- ---------------------------------------------------------------------
create or replace function oyun.mod_uye_zorunlu() returns oyun.profiller
language plpgsql stable set search_path to '' as $$
declare p oyun.profiller;
begin
  select * into p from oyun.profiller where id = auth.uid();
  if p.id is null or coalesce(p.yasakli, false) then raise exception 'Bu ekran yalnız oyun yönetimi içindir.'; end if;
  if p.yonetici or exists (select 1 from oyun.moderatorler where user_id = p.id) then return p; end if;
  raise exception 'Bu ekran yalnız yönetici ve moderatörler içindir.';
end $$;

create or replace function oyun.mod_kanal_acik(k text) returns boolean
language sql immutable set search_path to '' as $$
  select k = 'genel' or k = 'meclis' or k like 'il:%'
$$;

create or replace function oyun.mod_kanal_ad(k text) returns text
language sql stable set search_path to '' as $$
  select case when k = 'genel' then 'Genel' when k = 'meclis' then 'Meclis'
              when k like 'il:%' then coalesce((select i.ad from oyun.iller i where i.id::text = split_part(k, ':', 2)), 'İl') || ' sohbeti'
              else k end
$$;

-- Nöbet işaretleri: kesin karar değil, moderatöre "buraya bak" ipucu
create or replace function oyun.mod_metin_isaret(t text) returns text[]
language sql immutable set search_path to '' as $$
  select array_remove(array[
    case when t ~* '(https?://|www\.|\m[a-z0-9-]+\.(com|net|org|xyz|io|gg|me|tr)\M|t\.me/|discord\.gg|bit\.ly)' then 'baglanti' end,
    case when t ~ '(\+?90|0)?[ (]*5[0-9]{2}[) .-]*[0-9]{3}[ .-]*[0-9]{2}[ .-]*[0-9]{2}' then 'telefon' end,
    case when t ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' then 'kisisel' end,
    case when char_length(regexp_replace(t, '[^[:alpha:]]', '', 'g')) >= 12
          and char_length(regexp_replace(t, '[^[:upper:]]', '', 'g'))::numeric / greatest(1, char_length(regexp_replace(t, '[^[:alpha:]]', '', 'g'))) > 0.8 then 'buyuk_harf' end,
    case when t ~ '(.)\1{6,}' or t ~* '(\m\w+\M)(\s+\1\M){3,}' then 'tekrar' end,
    case when oyun.kufurlu(translate(lower(t), '1!03$4@5', 'iioesaas')) then 'kufur' end,
    case when (' ' || regexp_replace(translate(lower(coalesce(t,'')), 'çğıöşüâîû', 'cgiosuaiu'), '[^a-z]+', ' ', 'g') || ' ')
              ~ ' (aptal|salak|dangalak|ahmak|beyinsiz|haysiyetsiz|namussuz|pislik|ite|kopek|hain|vatan haini|terorist|satilmis|soytari|mal|gerzek|embesil|dingil) ' then 'sert' end
  ], null)
$$;

-- Kim hangi talebe karar verebilir
create or replace function oyun.mod_talep_karar_yetkili(u uuid, p_tur text) returns boolean
language sql stable set search_path to '' as $$
  select case p_tur when 'engel' then oyun.yetkili(u, 'hesap_kapat')
                    when 'sustur' then oyun.yetkili(u, 'sustur')
                    else coalesce((select yonetici from oyun.profiller where id = u), false) end
$$;

create or replace function oyun.mod_birim_ad(k text) returns text
language sql immutable set search_path to '' as $$
  select coalesce((select ad from oyun.mod_ana_gorev_tanim() where kod = k), 'Birim atanmadı')
$$;

-- Bir moderatörün o birimin dışından eklenmiş yetkileri
create or replace function oyun.mod_ek_yetkiler(p_birim text, p_yetkiler text[]) returns text[]
language sql immutable set search_path to '' as $$
  select coalesce(array_agg(x order by x), '{}'::text[]) from unnest(coalesce(p_yetkiler, '{}'::text[])) x
   where x <> 'kayit' and not (x = any(coalesce((select b.yetkiler from oyun.mod_birim_tanim() b where b.kod = p_birim), '{}'::text[])))
$$;

-- ---------------------------------------------------------------------
-- 5) Merkez: tek çağrıda moderatörün bütün panosu
-- ---------------------------------------------------------------------
create or replace function public.mod_merkez()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); m oyun.moderatorler; t timestamptz := oyun.simdi();
        y text[]; gun timestamptz; son_id bigint;
begin
  select * into m from oyun.moderatorler where user_id = p.id;
  y := case when p.yonetici then (select array_agg(kod) from oyun.mod_yetki_tanim()) else m.yetkiler end;
  gun := (date_trunc('day', t at time zone 'Europe/Istanbul')) at time zone 'Europe/Istanbul';
  select coalesce(max(id), 0) - 20000 into son_id from oyun.mesajlar;
  return jsonb_build_object(
    'zaman', t,
    'ben', jsonb_build_object('kad', p.kad, 'ad_soyad', p.ad_soyad, 'yonetici', coalesce(p.yonetici, false), 'birim', m.ana_gorev,
            'birim_ad', case when m.ana_gorev is not null then oyun.mod_birim_ad(m.ana_gorev) end,
            'rutbe', coalesce(m.rutbe, 'moderator'), 'not', m.gorev_notu, 'yetkiler', to_jsonb(y), 'atama', m.zaman),
    'birimler', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'aciklama', b.aciklama, 'yetkiler', to_jsonb(b.yetkiler), 'hedef', b.hedef,
                   'renk', b.renk, 'ikon', b.ikon,
                   'uyeler', (select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'rutbe', x.rutbe,
                                 'cevrimici', pr.son_gorulme > t - interval '15 minutes', 'son_gorulme', pr.son_gorulme)
                                 order by (x.rutbe = 'sorumlu') desc, (x.rutbe = 'kidemli') desc, pr.kad), '[]'::jsonb)
                              from oyun.moderatorler x join oyun.profiller pr on pr.id = x.user_id where x.ana_gorev = b.kod)) order by b.sira)
                 from oyun.mod_birim_tanim() b),
    'kuyruk', jsonb_strip_nulls(jsonb_build_object(
      'kayit', case when 'kayit' = any(y) then (select jsonb_build_object('sayi', count(*), 'en_eski', min(basvuru_at))
                 from oyun_yonetim.kayit_basvurulari where durum = 'beklemede' and basvuru_at is not null) end,
      'sikayet', case when 'sikayet' = any(y) then (select jsonb_build_object('sayi', count(*), 'en_eski', min(ilk))
                 from (select min(zaman) ilk from oyun.sikayetler where durum = 'yeni' group by tur, kayit_id, hedef_user) z) end,
      'sohbet', case when 'sikayet' = any(y) then (select jsonb_build_object('sayi', count(*),
                    'isaretli', count(*) filter (where cardinality(oyun.mod_metin_isaret(x.metin)) > 0 and not x.gizli))
                 from oyun.mesajlar x where x.id > son_id and x.zaman > t - interval '1 hour' and oyun.mod_kanal_acik(x.kanal)) end,
      'masak', case when 'ekonomi' = any(y) then (select jsonb_build_object('sayi', count(*), 'en_eski', min(zaman)) from oyun.masak where durum = 'yeni') end,
      'destek', case when 'destek' = any(y) then (select jsonb_build_object('sayi', count(*), 'en_eski', min(zaman)) from oyun.destek_talep where durum = 'yeni') end,
      'talep', (select jsonb_build_object('sayi', count(*), 'en_eski', min(zaman)) from oyun.mod_talep
                 where durum = 'acik' and talep_eden <> p.id and oyun.mod_talep_karar_yetkili(p.id, tur)),
      'taleplerim', (select jsonb_build_object('sayi', count(*)) from oyun.mod_talep where durum = 'acik' and talep_eden = p.id),
      'coklu', case when 'coklu_hesap' = any(y) then jsonb_build_object('sayi', (select count(*) from (
                   select o.cihaz from oyun.oturumlar o join oyun.profiller pr on pr.id = o.user_id
                    where o.cihaz is not null and not pr.yasakli and not exists (select 1 from oyun.hesap_onay h where h.user_id = o.user_id)
                    group by o.cihaz having count(distinct o.user_id) > 1) z)) end)),
    'istatistik', jsonb_build_object(
      'bugun', (select count(*) from oyun.mod_kayit where user_id = p.id and zaman >= gun),
      'hafta', (select count(*) from oyun.mod_kayit where user_id = p.id and zaman > t - interval '7 days'),
      'ekip_hafta', (select count(*) from oyun.mod_kayit k where k.zaman > t - interval '7 days'
                       and exists (select 1 from oyun.moderatorler x where x.user_id = k.user_id)),
      'sira', (select r from (select user_id, rank() over (order by count(*) desc) r from oyun.mod_kayit
                 where zaman > t - interval '7 days' and user_id in (select user_id from oyun.moderatorler) group by user_id) z where z.user_id = p.id),
      'ekip', (select count(*) from oyun.moderatorler),
      'cevrimici', (select count(*) from oyun.moderatorler x join oyun.profiller pr on pr.id = x.user_id where pr.son_gorulme > t - interval '15 minutes')),
    'son_islemlerim', coalesce((select jsonb_agg(jsonb_build_object('islem', k.islem, 'hedef', k.hedef, 'ayrinti', k.ayrinti, 'zaman', k.zaman) order by k.id desc)
                       from (select * from oyun.mod_kayit where user_id = p.id order by zaman desc, id desc limit 6) k), '[]'::jsonb),
    'kritik_uyari', case when p.yonetici then (select count(*) from oyun.moderatorler x where x.yetkiler && array['para','makam','kurallar','eposta']) end
  );
end $$;

-- ---------------------------------------------------------------------
-- 6) Üstlenme (aynı işe iki moderatör bakmasın)
-- ---------------------------------------------------------------------
create or replace function public.mod_ustlen(p_tur text, p_anahtar text, p_birak boolean default false)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); t timestamptz := clock_timestamp(); r oyun.mod_ustlenme; a text := left(btrim(coalesce(p_anahtar, '')), 80);
begin
  if p_tur not in ('kayit','sikayet','masak','destek','talep','coklu') or a = '' then raise exception 'Geçersiz kayıt.'; end if;
  delete from oyun.mod_ustlenme where bitis < t - interval '1 hour';
  if p_birak then
    delete from oyun.mod_ustlenme where tur = p_tur and anahtar = a and user_id = p.id;
    return jsonb_build_object('tamam', true);
  end if;
  insert into oyun.mod_ustlenme as u (tur, anahtar, user_id, bitis) values (p_tur, a, p.id, t + interval '3 minutes')
  on conflict (tur, anahtar) do update set user_id = excluded.user_id, bitis = excluded.bitis
   where u.user_id = excluded.user_id or u.bitis < t
  returning * into r;
  if r.user_id is null then
    select * into r from oyun.mod_ustlenme where tur = p_tur and anahtar = a;
    return jsonb_build_object('tamam', false, 'inceleyen', oyun.kad(r.user_id), 'bitis', r.bitis);
  end if;
  return jsonb_build_object('tamam', true, 'bitis', r.bitis);
end $$;

create or replace function public.mod_ustlenmeler(p_tur text)
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu();
begin
  return coalesce((select jsonb_object_agg(u.anahtar, jsonb_build_object('kad', oyun.kad(u.user_id), 'ben', u.user_id = p.id, 'bitis', u.bitis))
                     from oyun.mod_ustlenme u where u.tur = p_tur and u.bitis > clock_timestamp()), '{}'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 7) Sohbet nöbeti (yalnız herkese açık kanallar)
-- ---------------------------------------------------------------------
create or replace function public.mod_sohbet_nobeti(p_kanal text default null, p_isaretli boolean default false, p_once bigint default null, p_limit integer default 60)
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); lim int := least(greatest(coalesce(p_limit, 60), 10), 120);
        alt bigint;
begin
  select coalesce(max(id), 0) - 20000 into alt from oyun.mesajlar;
  return jsonb_build_object('zaman', t,
    'kanallar', coalesce((select jsonb_agg(jsonb_build_object('kanal', z.kanal, 'ad', oyun.mod_kanal_ad(z.kanal), 'sayi', z.n) order by z.n desc)
        from (select kanal, count(*) n from oyun.mesajlar where id > alt and zaman > t - interval '24 hours' and oyun.mod_kanal_acik(kanal)
               group by kanal order by count(*) desc limit 15) z), '[]'::jsonb),
    'mesajlar', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kanal', x.kanal, 'kanal_ad', oyun.mod_kanal_ad(x.kanal), 'kad', pr.kad,
          'metin', x.metin, 'zaman', x.zaman, 'gizli', x.gizli, 'isaret', to_jsonb(x.isaret),
          'susturulmus', pr.susturma_bitis > t, 'moderator', exists (select 1 from oyun.moderatorler mm where mm.user_id = x.user_id) or pr.yonetici,
          'sikayet', (select count(*) from oyun.sikayetler s where s.tur = 'mesaj' and s.kayit_id = x.id)) order by x.id desc)
        from (select y.* from (select m.*, oyun.mod_metin_isaret(m.metin) isaret from oyun.mesajlar m
                 where m.id > alt and oyun.mod_kanal_acik(m.kanal)
                   and (p_kanal is null or p_kanal = '' or m.kanal = p_kanal or (p_kanal = 'il' and m.kanal like 'il:%'))
                   and (p_once is null or m.id < p_once)
                 order by m.id desc limit 400) y
               where not coalesce(p_isaretli, false) or (cardinality(y.isaret) > 0 and not y.gizli)
               order by y.id desc limit lim) x
        join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 8) Oyuncu dosyası (360°)
-- ---------------------------------------------------------------------
create or replace function public.mod_dosya(p_kad text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('oyuncu_ara'); d jsonb; h oyun.profiller; t timestamptz := oyun.simdi();
begin
  d := public.yk_oyuncu(p_kad);
  select * into h from oyun.profiller where id = (d->>'id')::uuid;
  return d || jsonb_build_object(
    'ad_soyad', h.ad_soyad,
    'korunan', h.yonetici or exists (select 1 from oyun.moderatorler where user_id = h.id),
    'birim', (select oyun.mod_birim_ad(ana_gorev) from oyun.moderatorler where user_id = h.id and ana_gorev is not null),
    'cevrimici', h.son_gorulme > t - interval '15 minutes',
    'notlar', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'yazan', oyun.kad(n.yazan), 'metin', n.metin, 'zaman', n.zaman) order by n.zaman desc)
                 from (select * from oyun.mod_not where hedef = h.id order by zaman desc limit 30) n), '[]'::jsonb),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('islem', k.islem, 'kad', k.kad, 'ayrinti', k.ayrinti, 'zaman', k.zaman) order by k.zaman desc)
                 from (select * from oyun.mod_kayit where lower(hedef) = lower(h.kad) order by zaman desc limit 30) k), '[]'::jsonb),
    'sikayet_ozet', (select jsonb_build_object('toplam', count(*), 'acik', count(*) filter (where durum = 'yeni'),
                        'son30', count(*) filter (where zaman > t - interval '30 days'), 'kisi', count(distinct sikayetci))
                     from oyun.sikayetler where hedef_user = h.id),
    'sikayet_ettigi', (select count(*) from oyun.sikayetler where sikayetci = h.id),
    'bagli', case when oyun.yetkili(p.id, 'coklu_hesap') then coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'yasakli', pr.yasakli, 'olusturma', pr.olusturma))
                 from oyun.bagli_hesaplar(h.id) b join oyun.profiller pr on pr.id = b), '[]'::jsonb) end,
    'onayli', exists (select 1 from oyun.hesap_onay where user_id = h.id),
    'masak', case when oyun.yetkili(p.id, 'ekonomi') then coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tur', x.tur, 'tutar', x.tutar, 'aciklama', x.aciklama,
                 'durum', x.durum, 'zaman', x.zaman) order by x.zaman desc) from (select * from oyun.masak where user_id = h.id order by zaman desc limit 10) x), '[]'::jsonb) end,
    'talepler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tur', x.tur, 'sure', x.sure, 'gerekce', x.gerekce, 'durum', x.durum,
                 'talep_eden', oyun.kad(x.talep_eden), 'karar_veren', oyun.kad(x.karar_veren), 'zaman', x.zaman) order by x.zaman desc)
                 from (select * from oyun.mod_talep where hedef = h.id order by zaman desc limit 10) x), '[]'::jsonb),
    'yetkim', jsonb_build_object('sustur', oyun.yetkili(p.id, 'sustur'), 'hesap_kapat', oyun.yetkili(p.id, 'hesap_kapat'),
                 'makam', oyun.yetkili(p.id, 'makam'), 'para', oyun.yetkili(p.id, 'para'), 'kayit', oyun.yetkili(p.id, 'kayit'),
                 'coklu_hesap', oyun.yetkili(p.id, 'coklu_hesap'), 'ekonomi', oyun.yetkili(p.id, 'ekonomi'), 'yonetici', coalesce(p.yonetici, false))
  );
end $$;

create or replace function public.mod_not_ekle(p_kad text, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); h oyun.profiller := oyun.profil_bul(p_kad); m text := btrim(coalesce(p_metin, ''));
begin
  if char_length(m) < 3 or char_length(m) > 500 then raise exception 'Not 3-500 karakter olmalı.'; end if;
  if (select count(*) from oyun.mod_not where yazan = p.id and zaman > now() - interval '1 hour') >= 60 then raise exception 'Bir saatte en fazla 60 not yazılabilir.'; end if;
  insert into oyun.mod_not(hedef, yazan, metin) values (h.id, p.id, m);
  perform oyun.mod_log(p, 'not_ekle', h.kad, left(m, 200));
  return coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'yazan', oyun.kad(n.yazan), 'metin', n.metin, 'zaman', n.zaman) order by n.zaman desc)
           from (select * from oyun.mod_not where hedef = h.id order by zaman desc limit 30) n), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 9) Dört göz: yaptırım ve yöneticiye iletme talepleri
-- ---------------------------------------------------------------------
create or replace function public.mod_talep_ac(p_tur text, p_kad text, p_sure numeric, p_gerekce text, p_kanit text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi();
        g text := btrim(coalesce(p_gerekce, '')); k text := nullif(left(btrim(coalesce(p_kanit, '')), 600), ''); v_id bigint; r record; n int := 0; sure_yazi text;
begin
  if p_tur not in ('engel','sustur','eskalasyon') then raise exception 'Geçersiz talep türü.'; end if;
  if h.id = p.id then raise exception 'Kendin hakkında talep açamazsın.'; end if;
  if p_tur <> 'eskalasyon' then perform oyun.korunan_hedef(p, h.id); end if;
  if char_length(g) < 10 or char_length(g) > 500 then raise exception 'Gerekçe 10-500 karakter olmalı.'; end if;
  if p_tur = 'sustur' and (p_sure is null or p_sure <= 0 or p_sure > 720) then raise exception 'Susturma süresi 1-720 saat olmalı.'; end if;
  if p_tur = 'engel' and p_sure is not null and (p_sure < 0 or p_sure > 3650) then raise exception 'Engel süresi 0-3650 gün olmalı (0 = kalıcı).'; end if;
  if exists (select 1 from oyun.mod_talep where hedef = h.id and tur = p_tur and durum = 'acik') then
    raise exception '% hakkında bu türde açık bir talep zaten var.', h.kad;
  end if;
  if (select count(*) from oyun.mod_talep where talep_eden = p.id and zaman > t - interval '1 hour') >= 20 then raise exception 'Bir saatte en fazla 20 talep açılabilir.'; end if;
  insert into oyun.mod_talep(tur, hedef, sure, gerekce, kanit, talep_eden, zaman)
  values (p_tur, h.id, case when p_tur = 'eskalasyon' then null when p_tur = 'engel' and coalesce(p_sure, 0) = 0 then null else p_sure end, g, k, p.id, t)
  returning id into v_id;
  sure_yazi := case p_tur when 'sustur' then p_sure || ' saat susturma' when 'engel' then case when coalesce(p_sure, 0) = 0 then 'kalıcı engel' else p_sure || ' gün engel' end else 'yöneticiye iletildi' end;
  for r in select pr.id from oyun.profiller pr
            where pr.id <> p.id and not pr.yasakli and oyun.mod_talep_karar_yetkili(pr.id, p_tur)
              and (pr.yonetici or exists (select 1 from oyun.moderatorler x where x.user_id = pr.id)) limit 40 loop
    perform oyun.bildir(r.id, format('Moderasyon: %s, %s hakkında %s talebi açtı. Moderasyon Merkezi › Yaptırım talepleri.', p.kad, h.kad, sure_yazi), t);
    n := n + 1;
  end loop;
  perform oyun.mod_log(p, 'talep_ac', h.kad, format('#%s %s · %s', v_id, sure_yazi, left(g, 200)));
  return jsonb_build_object('id', v_id, 'bildirilen', n);
end $$;

create or replace function public.mod_talepler()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'karar', coalesce((select jsonb_agg(oyun.mod_talep_json(x, p.id) order by x.zaman) from (
        select * from oyun.mod_talep where durum = 'acik' and talep_eden <> p.id and oyun.mod_talep_karar_yetkili(p.id, tur) order by zaman limit 100) x), '[]'::jsonb),
    'diger_acik', coalesce((select jsonb_agg(oyun.mod_talep_json(x, p.id) order by x.zaman) from (
        select * from oyun.mod_talep where durum = 'acik' and talep_eden <> p.id and not oyun.mod_talep_karar_yetkili(p.id, tur) order by zaman limit 50) x), '[]'::jsonb),
    'benim', coalesce((select jsonb_agg(oyun.mod_talep_json(x, p.id) order by x.zaman desc) from (
        select * from oyun.mod_talep where talep_eden = p.id order by zaman desc limit 30) x), '[]'::jsonb),
    'son_kararlar', coalesce((select jsonb_agg(oyun.mod_talep_json(x, p.id) order by x.karar_zaman desc) from (
        select * from oyun.mod_talep where durum in ('onaylandi','reddedildi') and karar_zaman > t - interval '7 days' order by karar_zaman desc limit 30) x), '[]'::jsonb));
end $$;

create or replace function oyun.mod_talep_json(x oyun.mod_talep, ben uuid) returns jsonb
language sql stable set search_path to '' as $$
  select jsonb_build_object('id', x.id, 'tur', x.tur, 'hedef', oyun.kad(x.hedef), 'sure', x.sure, 'gerekce', x.gerekce, 'kanit', x.kanit,
    'talep_eden', oyun.kad(x.talep_eden), 'zaman', x.zaman, 'durum', x.durum, 'karar_veren', oyun.kad(x.karar_veren),
    'karar_not', x.karar_not, 'karar_zaman', x.karar_zaman, 'benim', x.talep_eden = ben,
    'hedef_durum', (select jsonb_build_object('yasakli', pr.yasakli, 'susturma', pr.susturma_bitis,
                      'sikayet', (select count(*) from oyun.sikayetler s where s.hedef_user = pr.id),
                      'onceki_yaptirim', (select count(*) from oyun.mod_talep z where z.hedef = pr.id and z.durum = 'onaylandi'))
                    from oyun.profiller pr where pr.id = x.hedef))
$$;

create or replace function public.mod_talep_karar(p_id bigint, p_onay boolean, p_not text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); x oyun.mod_talep; t timestamptz := oyun.simdi(); h oyun.profiller; n text := nullif(left(btrim(coalesce(p_not, '')), 300), '');
begin
  select * into x from oyun.mod_talep where id = p_id for update;
  if x.id is null then raise exception 'Talep bulunamadı.'; end if;
  if x.durum <> 'acik' then raise exception 'Bu talep zaten sonuçlandı.'; end if;
  if x.talep_eden = p.id then raise exception 'Kendi açtığın talebe karar veremezsin (dört göz ilkesi).'; end if;
  if not oyun.mod_talep_karar_yetkili(p.id, x.tur) then raise exception 'Bu talebe karar verme yetkin yok.'; end if;
  if not p_onay and n is null then raise exception 'Reddederken kısa bir gerekçe yaz.'; end if;
  select * into h from oyun.profiller where id = x.hedef;
  if p_onay then
    if x.tur = 'engel' then
      perform public.yk_engelle(h.kad, x.sure, left(x.gerekce, 200), false);
    elsif x.tur = 'sustur' then
      perform public.yk_sustur(h.kad, x.sure, left(x.gerekce, 200));
    end if;
  end if;
  update oyun.mod_talep set durum = case when p_onay then 'onaylandi' else 'reddedildi' end, karar_veren = p.id, karar_not = n, karar_zaman = t where id = x.id;
  perform oyun.bildir(x.talep_eden, format('Moderasyon: %s hakkındaki talebin (#%s) %s%s.', h.kad, x.id,
     case when p_onay then p.kad || ' tarafından onaylandı' else p.kad || ' tarafından reddedildi' end, coalesce(' · ' || n, '')), t);
  perform oyun.mod_log(p, case when p_onay then 'talep_onay' else 'talep_ret' end, h.kad, format('#%s %s%s', x.id, x.tur, coalesce(' · ' || n, '')));
  return public.mod_talepler();
end $$;

create or replace function public.mod_talep_geri_cek(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); x oyun.mod_talep;
begin
  select * into x from oyun.mod_talep where id = p_id for update;
  if x.id is null or x.talep_eden <> p.id then raise exception 'Yalnız kendi talebini geri çekebilirsin.'; end if;
  if x.durum <> 'acik' then raise exception 'Bu talep zaten sonuçlandı.'; end if;
  update oyun.mod_talep set durum = 'geri_cekildi', karar_zaman = oyun.simdi() where id = x.id;
  perform oyun.mod_log(p, 'talep_geri', oyun.kad(x.hedef), '#' || x.id);
  return public.mod_talepler();
end $$;

-- ---------------------------------------------------------------------
-- 10) Destek masası (moderatör)
-- ---------------------------------------------------------------------
create or replace function public.mod_destek(p_durum text default 'acik')
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('destek'); v_acik boolean := coalesce(p_durum, 'acik') <> 'tum';
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kad', oyun.kad(d.user_id), 'kategori', d.kategori, 'metin', d.metin, 'zaman', d.zaman,
      'durum', d.durum, 'yanit', d.yanit, 'yanit_zaman', d.yanit_zaman, 'yanitlayan', oyun.kad(d.yanitlayan), 'surum', d.surum, 'platform', d.platform,
      'onceki', (select count(*) from oyun.destek_talep z where z.user_id = d.user_id and z.id <> d.id))
      order by (d.durum = 'yeni') desc, d.zaman)
    from (select * from oyun.destek_talep x where (not v_acik and x.zaman > now() - interval '30 days') or x.durum = 'yeni'
           order by (x.durum = 'yeni') desc, x.zaman desc limit 100) d), '[]'::jsonb);
end $$;

create or replace function public.mod_destek_yanitla(p_id bigint, p_metin text, p_kapat boolean default false)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('destek'); d oyun.destek_talep; t timestamptz := oyun.simdi(); m text := nullif(btrim(coalesce(p_metin, '')), '');
begin
  select * into d from oyun.destek_talep where id = p_id for update;
  if d.id is null then raise exception 'Destek talebi bulunamadı.'; end if;
  if d.durum = 'kapali' then raise exception 'Bu talep kapatılmış.'; end if;
  if m is null and not coalesce(p_kapat, false) then raise exception 'Yanıt yaz (2-1000 karakter).'; end if;
  if m is not null and (char_length(m) < 2 or char_length(m) > 1000) then raise exception 'Yanıt 2-1000 karakter olmalı.'; end if;
  update oyun.destek_talep set yanit = coalesce(m, yanit), yanit_zaman = case when m is not null then now() else yanit_zaman end,
         yanitlayan = p.id, durum = case when p_kapat then 'kapali' else 'yanitlandi' end, okundu = false
   where id = d.id;
  perform oyun.bildir(d.user_id, case when m is not null then format('Destek yanıtı (talep #%s): %s', d.id, m) else format('Destek talebin #%s kapatıldı.', d.id) end, t);
  perform oyun.mod_log(p, case when p_kapat then 'destek_kapat' else 'destek_yanit' end, oyun.kad(d.user_id), format('#%s %s', d.id, coalesce(left(m, 200), '')));
  return public.mod_destek('acik');
end $$;

-- ---------------------------------------------------------------------
-- 11) Günlük: moderatör kendi işlemlerini, yönetici herkesinkini görür
-- ---------------------------------------------------------------------
create or replace function public.mod_gunluk(p_kad text default null, p_limit integer default 80, p_once bigint default null)
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); v_kisi uuid; lim int := least(greatest(coalesce(p_limit, 80), 10), 200);
begin
  if p.yonetici then
    if nullif(btrim(coalesce(p_kad, '')), '') is not null then v_kisi := (oyun.profil_bul(p_kad)).id; end if;
  else
    v_kisi := p.id;
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'zaman', k.zaman, 'kad', k.kad, 'islem', k.islem, 'hedef', k.hedef, 'ayrinti', k.ayrinti) order by k.id desc)
    from (select * from oyun.mod_kayit z where (v_kisi is null or z.user_id = v_kisi) and (p_once is null or z.id < p_once) order by z.id desc limit lim) k), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 12) Yönetici: ekip yönetimi
-- ---------------------------------------------------------------------
create or replace function public.admin_mod_ekip()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'birimler', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'aciklama', b.aciklama, 'yetkiler', to_jsonb(b.yetkiler),
                   'hedef', b.hedef, 'renk', b.renk, 'ikon', b.ikon) order by b.sira) from oyun.mod_birim_tanim() b),
    'yetkiler', (select jsonb_agg(jsonb_build_object('kod', y.kod, 'ad', y.ad, 'aciklama', y.aciklama,
                   'kritik', y.kod in ('para','makam','kurallar','eposta'), 'temel', y.kod = 'kayit') order by y.sira) from oyun.mod_yetki_tanim() y),
    'moderatorler', coalesce((select jsonb_agg(jsonb_build_object(
          'kad', pr.kad, 'ad_soyad', pr.ad_soyad, 'birim', m.ana_gorev,
          'birim_gecerli', exists (select 1 from oyun.mod_birim_tanim() b where b.kod = m.ana_gorev),
          'rutbe', m.rutbe, 'not', m.gorev_notu, 'yetkiler', to_jsonb(m.yetkiler),
          'ek', to_jsonb(oyun.mod_ek_yetkiler(m.ana_gorev, m.yetkiler)),
          'kritik', to_jsonb(array(select x from unnest(m.yetkiler) x where x in ('para','makam','kurallar','eposta') order by x)),
          'zaman', m.zaman, 'son_gorulme', pr.son_gorulme, 'cevrimici', pr.son_gorulme > t - interval '15 minutes', 'yasakli', pr.yasakli,
          'islem_1g', (select count(*) from oyun.mod_kayit k where k.user_id = m.user_id and k.zaman > t - interval '1 day'),
          'islem_7g', (select count(*) from oyun.mod_kayit k where k.user_id = m.user_id and k.zaman > t - interval '7 days'),
          'islem_30g', (select count(*) from oyun.mod_kayit k where k.user_id = m.user_id and k.zaman > t - interval '30 days'),
          'kayit_7g', (select count(*) from oyun_yonetim.kayit_karar_log l where l.veren = m.user_id and l.zaman > t - interval '7 days'),
          'son_islem', (select max(zaman) from oyun.mod_kayit k where k.user_id = m.user_id))
        order by m.ana_gorev nulls last, (m.rutbe = 'sorumlu') desc, pr.kad)
      from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id), '[]'::jsonb));
end $$;

create or replace function public.admin_mod_kaydet(p_kad text, p_birim text, p_rutbe text default 'moderator', p_ek text[] default '{}', p_not text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi(); h oyun.profiller := oyun.profil_bul(p_kad);
        b record; y text[]; gecersiz text; vardi boolean; eski oyun.moderatorler; r text := coalesce(nullif(p_rutbe, ''), 'moderator');
        rutbe_ad text;
begin
  if h.id = p.id then raise exception 'Kendini moderatör yapamazsın; sen zaten yöneticisin.'; end if;
  if h.yonetici then raise exception '% zaten yönetici.', h.kad; end if;
  if h.yasakli then raise exception 'Hesabı kapalı oyuncu moderatör yapılamaz.'; end if;
  if r not in ('moderator','kidemli','sorumlu') then raise exception 'Geçersiz rütbe.'; end if;
  select * into b from oyun.mod_birim_tanim() x where x.kod = p_birim;
  if b.kod is null then raise exception 'Bir uzmanlık birimi seç.'; end if;
  select string_agg(x, ', ') into gecersiz from unnest(coalesce(p_ek, '{}')) x where x not in (select kod from oyun.mod_yetki_tanim());
  if gecersiz is not null then raise exception 'Geçersiz yetki: %', gecersiz; end if;
  select array_agg(distinct x order by x) into y from unnest(b.yetkiler || coalesce(p_ek, '{}') || array['kayit']) x where nullif(btrim(x), '') is not null;
  select * into eski from oyun.moderatorler where user_id = h.id for update;
  vardi := eski.user_id is not null;
  insert into oyun.moderatorler(user_id, yetkiler, atayan, zaman, ana_gorev, gorev_notu, rutbe)
  values (h.id, y, p.id, t, b.kod, nullif(left(btrim(coalesce(p_not, '')), 300), ''), r)
  on conflict (user_id) do update set yetkiler = excluded.yetkiler, atayan = excluded.atayan, ana_gorev = excluded.ana_gorev,
                                      gorev_notu = excluded.gorev_notu, rutbe = excluded.rutbe;
  rutbe_ad := case r when 'sorumlu' then 'Birim sorumlusu' when 'kidemli' then 'Kıdemli moderatör' else 'Moderatör' end;
  if not vardi then
    perform oyun.bildir(h.id, format('Oyun yönetimi seni moderatör yaptı. Birimin: %s (%s). Görevine Profilim › Moderasyon Merkezi''nden ulaşırsın. Her moderatör yeni oyuncu başvurularını da onaylayabilir.', b.ad, rutbe_ad), t);
    perform oyun.mod_log(p, 'moderator_ata', h.kad, format('%s · %s', b.ad, rutbe_ad));
  elsif eski.ana_gorev is distinct from b.kod or eski.rutbe is distinct from r or eski.yetkiler is distinct from y then
    perform oyun.bildir(h.id, format('Moderatörlük görevin güncellendi: %s · %s.', b.ad, rutbe_ad), t);
    perform oyun.mod_log(p, 'moderator_birim', h.kad, format('%s · %s · ek: %s', b.ad, rutbe_ad, coalesce(array_to_string(oyun.mod_ek_yetkiler(b.kod, y), ', '), '')));
  end if;
  return public.admin_mod_ekip();
end $$;

-- Birimi olan moderatörlerin yetkilerini yalnız birim yetkilerine indirir (ek ve kritik yetkiler kalkar)
create or replace function public.admin_mod_sadelestir()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); n int := 0; r record;
begin
  for r in select m.user_id, pr.kad, b.yetkiler, b.ad from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id
            join oyun.mod_birim_tanim() b on b.kod = m.ana_gorev
           where m.yetkiler is distinct from (select array_agg(distinct x order by x) from unnest(b.yetkiler || array['kayit']) x) loop
    update oyun.moderatorler set yetkiler = (select array_agg(distinct x order by x) from unnest(r.yetkiler || array['kayit']) x) where user_id = r.user_id;
    perform oyun.mod_log(p, 'moderator_sadelestir', r.kad, r.ad);
    n := n + 1;
  end loop;
  return public.admin_mod_ekip() || jsonb_build_object('sadelesen', n);
end $$;

-- ---------------------------------------------------------------------
-- 13) RPC izinleri (159_rpc_yuzey listesine de eklendi)
-- ---------------------------------------------------------------------
do $g$
declare f text;
begin
  foreach f in array array['public.mod_merkez()','public.mod_ustlen(text,text,boolean)','public.mod_ustlenmeler(text)',
    'public.mod_sohbet_nobeti(text,boolean,bigint,integer)','public.mod_dosya(text)','public.mod_not_ekle(text,text)',
    'public.mod_talep_ac(text,text,numeric,text,text)','public.mod_talepler()','public.mod_talep_karar(bigint,boolean,text)',
    'public.mod_talep_geri_cek(bigint)','public.mod_destek(text)','public.mod_destek_yanitla(bigint,text,boolean)',
    'public.mod_gunluk(text,integer,bigint)','public.admin_mod_ekip()','public.admin_mod_kaydet(text,text,text,text[],text)',
    'public.admin_mod_sadelestir()','public.admin_moderator_ayarla(text,text[])','public.admin_moderatorler()','public.admin_mod_kayit(integer)',
    'public.admin_kayit_basvurulari()','public.admin_sikayetler(text)','public.admin_sikayet_karar(text,bigint,text,text)',
    'public.admin_supheler()','public.admin_hesap_onay(text,boolean,text)','public.admin_masak(text)','public.admin_masak_karar(bigint,text,numeric,text)',
    'public.yk_oyuncu(text)','public.yk_sustur(text,numeric,text)','public.yk_engelle(text,numeric,text,boolean)','public.yk_engel_kaldir(text)'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke all on function %s from public, anon', f);
      execute format('grant execute on function %s to authenticated', f);
    end if;
  end loop;
end $g$;
