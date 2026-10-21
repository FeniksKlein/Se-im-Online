-- Seçim Simülasyonu Online · 2026-10-22 · Yönetici Kontrol Merkezi + hata yalıtımlı motor + durum() kilit beklememe (TAM DOSYA)
-- Canlıda A–E bölümleri uygulandı; onay gereken F bölümü ayrı: 20261022_yonetici_kontrol_onayli.sql. İki kez çalıştırmak güvenlidir.
begin;
-- =====================================================================
--  113 · YÖNETİCİ KONTROL MERKEZİ
--  Oyunun sahibi (profiller.yonetici) uygulamanın içinden, anında:
--   • oyunculara / bir ile / bir partiye / herkese para ve kıdem ekler ya da çıkarır,
--   • oyuncuyu süreli ya da kalıcı engeller, susturur, aday olma yasağı koyar,
--   • makam verir (CB, CB yardımcısı, bakan, vekil, belediye başkanı, TBMM görevleri,
--     genel başkan, genel başkan yardımcısı) ya da görevden alır,
--   • oyuncunun partisini, ilini, adını değiştirir; tek tek ya da toplu bildirim gönderir,
--   • kasaları (hazine, il, parti, şirket, dernek) değiştirir, seçim takvimini düzenler,
--   • "Veri düzenleyici" ile oyun şemasındaki her tablonun her satırını görür, düzenler,
--     ekler, siler; her değişiklik önce/sonra hâliyle kaydedilir ve tek dokunuşla geri alınır,
--   • bakım modu, üst duyuru bandı, destek e-postası, reklam/satış kimlikleri gibi uygulama
--     ayarlarını yeni sürüm çıkarmadan sunucudan değiştirir.
--  Ayrıca oyun motoru (oyun.tick) hata yalıtımlı hâle getirildi: bir alt adım hata verirse
--  yalnız o adım geri alınır, seçimler ve diğer adımlar işlemeye devam eder; hata kaydı tutulur.
--  Moderatörlere iki yeni yetki verilebilir: "para" ve "makam". Veri düzenleyici, uygulama
--  ayarları, seçim takvimi ve motor yalnız yöneticiye açıktır.
-- =====================================================================

-- ---------- 1) Yeni sütunlar ve tablolar ----------
alter table oyun.profiller add column if not exists engel_bitis timestamptz;
alter table oyun.profiller add column if not exists engel_neden text;

create table if not exists oyun.uygulama_ayar(
  anahtar      text primary key,
  deger        jsonb not null default 'null'::jsonb,
  aciklama     text,
  herkese_acik boolean not null default true,
  guncelleme   timestamptz not null default now()
);
alter table oyun.uygulama_ayar enable row level security;
revoke all on oyun.uygulama_ayar from public, anon, authenticated;
insert into oyun.uygulama_ayar(anahtar, deger, aciklama) values
  ('iletisim',             '"feniksklein@gmail.com"', 'Oyuncuların ulaşacağı destek e-postası'),
  ('admob_odullu_ios',     'null',  'iOS ödüllü reklam birimi (ca-app-pub-.../...). Boşsa uygulamadaki değer kullanılır.'),
  ('admob_odullu_android', 'null',  'Android ödüllü reklam birimi (ca-app-pub-.../...). Boşsa uygulamadaki değer kullanılır.'),
  ('admob_test',           'null',  'true: test reklamı gösterilir. Boşsa uygulamadaki değer kullanılır.'),
  ('revenuecat_ios',       'null',  'RevenueCat iOS genel anahtarı (appl_...)'),
  ('revenuecat_android',   'null',  'RevenueCat Android genel anahtarı (goog_...)'),
  ('reklam_acik',          'true',  'Ödüllü reklam düğmesi açık mı'),
  ('satis_acik',           'true',  '₺ paketi satışı açık mı'),
  ('magaza_ios',           '"https://apps.apple.com/tr/search?term=Se%C3%A7im%20Sim%C3%BClasyonu%20Online"', 'App Store sayfası'),
  ('magaza_android',       '"https://play.google.com/store/apps/details?id=com.feniksklein.secimonline"', 'Google Play sayfası'),
  ('bakim',                'false', 'Bakım modu: açıkken yalnız yönetici girebilir'),
  ('bakim_mesaj',          '""',    'Bakım ekranında görünen açıklama'),
  ('duyuru_bandi',         '""',    'Uygulamanın üstünde herkese görünen kısa duyuru (boşsa görünmez)')
on conflict (anahtar) do nothing;

create table if not exists oyun.yk_degisiklik(
  id          bigserial primary key,
  zaman       timestamptz not null default now(),
  user_id     uuid,
  kad         text,
  tablo       text not null,
  islem       text not null,
  anahtar     jsonb,
  once        jsonb,
  sonra       jsonb,
  aciklama    text,
  geri_alindi timestamptz
);
create index if not exists yk_degisiklik_zaman on oyun.yk_degisiklik(zaman desc);
alter table oyun.yk_degisiklik enable row level security;
revoke all on oyun.yk_degisiklik from public, anon, authenticated;

create table if not exists oyun.tick_hata(
  id      bigserial primary key,
  zaman   timestamptz not null default now(),
  son     timestamptz not null default now(),
  sayi    int not null default 1,
  adim    text not null,
  hata    text,
  ayrinti text
);
create index if not exists tick_hata_son on oyun.tick_hata(son desc);
alter table oyun.tick_hata enable row level security;
revoke all on oyun.tick_hata from public, anon, authenticated;

-- ---------- 2) Uygulama ayarları (istemci yapılandırması) ----------
create or replace function oyun.uyg_ayar(p_anahtar text) returns jsonb language sql stable as $$
  select deger from oyun.uygulama_ayar where anahtar = p_anahtar
$$;
create or replace function oyun.iletisim() returns text language sql stable as $$
  select coalesce(nullif(oyun.uyg_ayar('iletisim') #>> '{}', ''), 'feniksklein@gmail.com')
$$;
create or replace function oyun.bakim_acik() returns boolean language sql stable as $$
  select coalesce((oyun.uyg_ayar('bakim') #>> '{}')::boolean, false)
$$;
create or replace function oyun.bakim_mesaji() returns text language sql stable as $$
  select 'Oyun bakımda. ' || coalesce(nullif(oyun.uyg_ayar('bakim_mesaj') #>> '{}', ''), 'Kısa süre içinde geri döneceğiz; hesabın, makamın ve paran güvende.')
$$;

-- Giriş yapmadan da okunabilir: yalnız herkese açık ayarlar
create or replace function public.uygulama_ayar() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_object_agg(anahtar, deger), '{}'::jsonb) from oyun.uygulama_ayar where herkese_acik
$$;

-- ---------- 3) Süreli / kalıcı engel ----------
create or replace function oyun.engel_mesaji(p oyun.profiller) returns text language sql stable as $$
  select case
    when p.engel_bitis is not null then
      format('Hesabın %s tarihine kadar oyun yönetimi tarafından engellendi.%s İtiraz için: %s',
             to_char(p.engel_bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'),
             coalesce(' Gerekçe: ' || nullif(btrim(p.engel_neden), '') || '.', ''), oyun.iletisim())
    else
      format('Hesabın kural ihlali nedeniyle kapatıldı.%s İtiraz için oyun yönetimine e-posta gönderebilirsin: %s',
             coalesce(' Gerekçe: ' || nullif(btrim(p.engel_neden), '') || '.', ''), oyun.iletisim())
  end
$$;

-- Engelli oyuncu: süresi dolduysa engeli kaldırır, dolmadıysa açıklamalı hata verir (değiştirebilen sürüm)
create or replace function oyun.engel_kontrol(p oyun.profiller) returns oyun.profiller language plpgsql as $$
declare y oyun.profiller;
begin
  if not coalesce(p.yasakli, false) then return p; end if;
  if p.engel_bitis is not null and p.engel_bitis <= oyun.simdi() then
    update oyun.profiller set yasakli = false, engel_bitis = null, engel_neden = null where id = p.id returning * into y;
    perform oyun.bildir(p.id, 'Hesabındaki süreli engel sona erdi. Tekrar hoş geldin!', oyun.simdi());
    return y;
  end if;
  raise exception '%', oyun.engel_mesaji(p);
end $$;

-- Her oyun işleminin kapısı (değişiklik yapmaz; süresi dolmuş engeli yok sayar, kaydı motor temizler)
create or replace function oyun.profilim() returns oyun.profiller language plpgsql stable as $$
declare p oyun.profiller;
begin
  select * into p from oyun.profiller where id = oyun.ben();
  if p.id is null then raise exception 'Önce profilini oluştur (kullanıcı adı ve il).'; end if;
  if p.yasakli then
    if p.engel_bitis is not null and p.engel_bitis <= oyun.simdi() then
      p.yasakli := false;
    else
      raise exception '%', oyun.engel_mesaji(p);
    end if;
  end if;
  if not p.yonetici and oyun.bakim_acik() then raise exception '%', oyun.bakim_mesaji(); end if;
  return p;
end $$;

-- durum(): (1) kapalı hesap mesajını açıklamalı engel kontrolüyle değiştir ve bakım modunu ekle,
-- (2) "son görülme" güncellemesi kilitli satırı beklemesin (seçim sonucu gibi yoğun anlarda durum() 8 sn
--     zaman aşımına düşüp oyuncuya hata veriyordu). Gövdenin geri kalanı aynen kalır; iki kez çalışabilir.
do $yama$
declare d text; y text;
begin
  if to_regprocedure('public.durum()') is null then return; end if;
  d := pg_get_functiondef('public.durum()'::regprocedure); y := d;
  if position('oyun.engel_kontrol(p)' in y) = 0 then
    y := regexp_replace(y,
          'raise exception ''Hesabın kural ihlali nedeniyle kapatıldı[^'']*'';',
          'p := oyun.engel_kontrol(p);', '');
    y := regexp_replace(y,
          '(p := oyun\.engel_kontrol\(p\);\s*end if;)',
          E'\\1\n  if not p.yonetici and oyun.bakim_acik() then raise exception ''%'', oyun.bakim_mesaji(); end if;', '');
    if position('oyun.engel_kontrol(p)' in y) = 0 then raise notice 'durum() engel yaması uygulanamadı: beklenen satır bulunamadı'; end if;
  end if;
  if position('for update skip locked' in y) = 0 then
    y := regexp_replace(y,
          'update oyun\.profiller\s+set son_gorulme = t\s+where id = p\.id;',
          'update oyun.profiller set son_gorulme = t where id in (select x.id from oyun.profiller x where x.id = p.id for update skip locked);', '');
  end if;
  if y <> d then execute y; end if;
end $yama$;

-- Süresi dolan engelleri kaldır (motor her dakika çağırır)
create or replace function oyun.yk_engel_tick(t timestamptz) returns void language plpgsql as $$
declare r record;
begin
  for r in update oyun.profiller set yasakli = false, engel_bitis = null, engel_neden = null
           where yasakli and engel_bitis is not null and engel_bitis <= t returning id loop
    perform oyun.bildir(r.id, 'Hesabındaki süreli engel sona erdi. Tekrar hoş geldin!', t);
  end loop;
end $$;

-- ---------- 4) Motor: hata yalıtımlı tick ----------
create or replace function oyun.tick_hata_yaz(p_adim text, p_hata text, p_ayrinti text) returns void language plpgsql as $$
begin
  update oyun.tick_hata set sayi = sayi + 1, son = now()
   where id = (select id from oyun.tick_hata where adim = p_adim and hata is not distinct from left(p_hata, 500)
                 and son > now() - interval '1 hour' order by id desc limit 1);
  if not found then
    insert into oyun.tick_hata(adim, hata, ayrinti) values (left(p_adim, 120), left(p_hata, 500), left(p_ayrinti, 1500));
  end if;
exception when others then null;
end $$;

create or replace function oyun.tick() returns integer language plpgsql set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); ay date; r record; n int := 0; atla bigint[] := '{}'; h text; b text;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay := date_trunc('month', t at time zone 'Europe/Istanbul')::date;
  begin
    perform oyun.donem_olustur(ay); perform oyun.donem_olustur((ay + interval '1 month')::date);
  exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('donem_olustur', h, b); end;
  if (select son_temizlik from oyun.ayarlar where id = 1) is distinct from (t at time zone 'Europe/Istanbul')::date then
    begin
      delete from oyun.mesajlar where zaman < t - interval '30 days'; delete from oyun.yayinlar where zaman < t - interval '30 days'; delete from oyun.bildirimler where zaman < t - interval '60 days';
      delete from oyun.ozel where zaman < t - interval '90 days'; delete from oyun.push_kuyruk where olusturma < now() - interval '7 days';
      delete from oyun.tick_hata where son < now() - interval '14 days';
      update oyun.ayarlar set son_temizlik = (t at time zone 'Europe/Istanbul')::date where id = 1;
    exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('gunluk_temizlik', h, b); end;
  end if;
  -- Seçim sonuçları ve göreve başlamalar: biri hata verirse o seçim bu dakika atlanır, diğerleri işler
  loop
    select * into r from (
      select id, sonuc_at as zaman, 0 as asama, oyun.oncelik(tur) o from oyun.secimler where durum = 'bekliyor' and sonuc_at <= t
      union all select id, goreve_bas, 1, oyun.oncelik(tur) from oyun.secimler where durum = 'sonuclandi' and goreve_bas <= t
    ) x where not (x.id = any(atla)) order by zaman, asama, o limit 1;
    exit when not found;
    begin
      if r.asama = 0 then perform oyun.sonuclandir(r.id); else perform oyun.goreve_baslat(r.id); end if;
    exception when others then
      get stacked diagnostics h = message_text, b = pg_exception_context;
      atla := atla || r.id;
      perform oyun.tick_hata_yaz(case when r.asama = 0 then 'sonuclandir #' else 'goreve_baslat #' end || r.id, h, b);
    end;
    n := n + 1; exit when n > 200;
  end loop;
  begin perform oyun.kanun_tick(t);          exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('kanun_tick', h, b); end;
  begin perform oyun.mevzuat_tick(t);        exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('mevzuat_tick', h, b); end;
  begin perform oyun.meclis_tick(t);         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('meclis_tick', h, b); end;
  begin perform oyun.mahkeme_toplu_tick(t);  exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('mahkeme_toplu_tick', h, b); end;
  begin perform oyun.parti_tuzuk_tick(t);    exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('parti_tuzuk_tick', h, b); end;
  begin perform oyun.siyasi_tick(t);         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('siyasi_tick', h, b); end;
  begin perform oyun.guvenlik_tick(t);       exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('guvenlik_tick', h, b); end;
  begin perform oyun.gunluk_ekonomi(t);      exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('gunluk_ekonomi', h, b); end;
  begin perform oyun.banka_tick(t);          exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('banka_tick', h, b); end;
  begin perform oyun.meclis_olcek_uygula(t); exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('meclis_olcek_uygula', h, b); end;
  begin perform oyun.ihmal_tick(t);          exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('ihmal_tick', h, b); end;
  begin perform oyun.miting_tick(t);         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('miting_tick', h, b); end;
  begin perform oyun.yk_engel_tick(t);       exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('yk_engel_tick', h, b); end;
  begin perform oyun.push_hatirlatmalar(t);  exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('push_hatirlatmalar', h, b); end;
  begin perform oyun.push_tetikle();         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('push_tetikle', h, b); end;
  return n;
end $$;

-- ---------- 5) Yetkiler ----------
create or replace function oyun.mod_yetki_tanim() returns table(kod text, ad text, aciklama text, sira int) language sql immutable as $$
  values ('ozet',        'Özet',                    'Oyuncu sayısı, aktiflik, açık şikâyet gibi özet rakamları görür.', 1),
         ('sikayet',     'Şikâyetler',              'Şikâyet edilen mesaj ve yayınları görür; "sorun yok" ya da "gizle" kararı verir.', 2),
         ('sustur',      'Susturma',                'Oyuncuyu susturur, susturmayı kaldırır.', 3),
         ('hesap_kapat', 'Engelleme ve hesap kapatma', 'Oyuncuyu süreli ya da kalıcı engeller, hesabı kapatır ya da yeniden açar.', 4),
         ('oyuncu_ara',  'Oyuncu inceleme',         'Oyuncunun bilgilerini ve son mesajlarını görür.', 5),
         ('eposta',      'E-posta görme',           'Oyuncu incelerken e-posta adresini de görür (kişisel veri; dikkatli ver).', 6),
         ('duyuru',      'Duyuru ve bildirim',      'Tüm oyunculara duyuru, seçtiği oyunculara bildirim gönderir.', 7),
         ('coklu_hesap', 'Çoklu hesap incelemesi',  'Aynı cihazdan açılan hesapları görür, gerçek kişi olanları onaylar.', 8),
         ('kurallar',    'Kurallar ve ayarlar',     'Vatandaşlık, parti kurma, teşkilat, havale ve banka kurallarını değiştirir.', 9),
         ('ekonomi',     'MASAK (ekonomi denetimi)', 'Şüpheli işlem bildirimlerini inceler; temiz, ihtar ya da el koyma kararı verir.', 10),
         ('para',        'Para ve kıdem',           'Oyunculara, bir ile, bir partiye ya da herkese para ve kıdem ekler veya çıkarır.', 11),
         ('makam',       'Görev verme ve alma',     'Oyuncuyu makama atar, görevden alır; parti görevlerini, ilini, partisini ve aday olma yasağını değiştirir.', 12)
$$;

-- Yalnız oyunun sahibi
create or replace function oyun.yk_sahip() returns oyun.profiller language plpgsql as $$
declare p oyun.profiller := oyun.profilim();
begin
  if not p.yonetici then raise exception 'Bu işlemi yalnızca oyunun yöneticisi yapabilir.'; end if;
  return p;
end $$;

-- ---------- 6) Hedef kümeleri (toplu işlemler) ----------
create or replace function oyun.yk_hedefler(p_hedef text, p_deger text) returns setof uuid language plpgsql stable as $$
declare t timestamptz := oyun.simdi();
begin
  if p_hedef = 'oyuncu' then return query select (oyun.profil_bul(p_deger)).id;
  elsif p_hedef = 'herkes' then return query select id from oyun.profiller where not yasakli;
  elsif p_hedef = 'cevrimici' then return query select id from oyun.profiller where not yasakli and son_gorulme > t - interval '15 minutes';
  elsif p_hedef = 'aktif' then return query select id from oyun.profiller where not yasakli and son_gorulme > t - interval '7 days';
  elsif p_hedef = 'yeni' then return query select id from oyun.profiller where not yasakli and olusturma > t - interval '3 days';
  elsif p_hedef = 'il' then
    if p_deger is null or p_deger !~ '^\d+$' then raise exception 'İl seçmelisin.'; end if;
    return query select id from oyun.profiller where not yasakli and il_id = p_deger::int;
  elsif p_hedef = 'parti' then
    if p_deger is null or p_deger !~ '^\d+$' then raise exception 'Parti seçmelisin.'; end if;
    return query select id from oyun.profiller where not yasakli and parti_id = p_deger::bigint;
  elsif p_hedef = 'makamli' then
    return query select p.id from oyun.profiller p where not p.yasakli and exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null);
  else raise exception 'Geçersiz hedef: %', p_hedef; end if;
end $$;

create or replace function oyun.yk_hedef_ad(p_hedef text, p_deger text) returns text language sql stable as $$
  select case p_hedef
    when 'oyuncu' then p_deger
    when 'herkes' then 'tüm oyuncular'
    when 'cevrimici' then 'çevrimiçi oyuncular'
    when 'aktif' then 'son 7 günde girenler'
    when 'yeni' then 'son 3 günde katılanlar'
    when 'il' then coalesce((select ad from oyun.iller where id::text = p_deger), '?') || ' ilindekiler'
    when 'parti' then coalesce((select kisa from oyun.partiler where id::text = p_deger), '?') || ' üyeleri'
    when 'makamli' then 'makam sahipleri'
    else p_hedef end
$$;

create or replace function oyun.yk_metin(m text, enfazla int) returns text language sql immutable as $$
  select nullif(left(btrim(regexp_replace(coalesce(m, ''), '[\r\n]{3,}', E'\n\n', 'g')), enfazla), '')
$$;

-- Kayıt onay sistemi (oyun_yonetim şeması) kurulu değilse de çalışsın
create or replace function oyun.yk_kayit_durumu(u uuid) returns text language plpgsql stable as $$
declare v text;
begin
  if to_regclass('oyun_yonetim.kayit_basvurulari') is null then return null; end if;
  execute 'select durum from oyun_yonetim.kayit_basvurulari where user_id = $1' into v using u;
  return v;
end $$;
create or replace function oyun.yk_bekleyen_kayit() returns int language plpgsql stable as $$
declare n int;
begin
  if to_regclass('oyun_yonetim.kayit_basvurulari') is null then return 0; end if;
  execute 'select count(*) from oyun_yonetim.kayit_basvurulari where durum = ''beklemede'' and basvuru_at is not null' into n;
  return n;
end $$;

-- ---------- 7) Veri düzenleyici çekirdeği ----------
create or replace function oyun.yk_tablo_coz(p_tablo text) returns regclass language plpgsql stable as $$
declare r regclass; s text; n text;
begin
  s := split_part(btrim(coalesce(p_tablo, '')), '.', 1); n := split_part(btrim(coalesce(p_tablo, '')), '.', 2);
  if n = '' then n := s; s := 'oyun'; end if;
  if s not in ('oyun', 'oyun_yonetim') then raise exception 'Yalnız oyun tabloları düzenlenebilir.'; end if;
  select c.oid::regclass into r from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
   where ns.nspname = s and c.relname = n and c.relkind in ('r', 'p');
  if r is null then raise exception 'Tablo bulunamadı: %', p_tablo; end if;
  return r;
end $$;

create or replace function oyun.yk_ad(p_t regclass) returns text language sql stable as $$
  select format('%I.%I', ns.nspname, c.relname) from pg_class c join pg_namespace ns on ns.oid = c.relnamespace where c.oid = p_t
$$;

create or replace function oyun.yk_pk(p_t regclass) returns text[] language sql stable as $$
  select array_agg(a.attname::text order by array_position(i.indkey::int2[], a.attnum))
  from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey::int2[])
  where i.indrelid = p_t and i.indisprimary
$$;

create or replace function oyun.yk_yazilir(p_t regclass) returns text[] language sql stable as $$
  select coalesce(array_agg(attname::text order by attnum), '{}') from pg_attribute
  where attrelid = p_t and attnum > 0 and not attisdropped and attgenerated = ''
$$;

create or replace function oyun.yk_anahtar(p_t regclass, p_satir jsonb) returns jsonb language sql stable as $$
  select jsonb_object_agg(c, p_satir -> c) from unnest(oyun.yk_pk(p_t)) c
$$;

create or replace function oyun.yk_kaydet_log(p oyun.profiller, p_t regclass, p_islem text, p_anahtar jsonb, p_once jsonb, p_sonra jsonb, p_aciklama text)
returns bigint language sql as $$
  insert into oyun.yk_degisiklik(zaman, user_id, kad, tablo, islem, anahtar, once, sonra, aciklama)
  values (now(), p.id, p.kad, oyun.yk_ad(p_t), p_islem, p_anahtar, p_once, p_sonra, left(p_aciklama, 300))
  returning id
$$;

-- Bir satırı günceller; önce/sonra kaydını döner
create or replace function oyun.yk_guncelle(p oyun.profiller, p_t regclass, p_anahtar jsonb, p_degerler jsonb, p_islem text default 'guncelle', p_aciklama text default null)
returns jsonb language plpgsql as $$
declare pk text[] := oyun.yk_pk(p_t); cols text[]; kosul text; once jsonb; sonra jsonb; adet int; tad text := oyun.yk_ad(p_t);
begin
  if pk is null then raise exception 'Bu tablonun birincil anahtarı yok; satır düzenlenemez.'; end if;
  if p_anahtar is null or jsonb_typeof(p_anahtar) <> 'object' or exists (select 1 from unnest(pk) c where not (p_anahtar ? c)) then
    raise exception 'Satır anahtarı eksik.';
  end if;
  if p_degerler is null or jsonb_typeof(p_degerler) <> 'object' then raise exception 'Değerler eksik.'; end if;
  select array_agg(k order by k) into cols from jsonb_object_keys(p_degerler) k where k = any(oyun.yk_yazilir(p_t));
  if cols is null then raise exception 'Değiştirilecek sütun yok.'; end if;
  kosul := (select string_agg(format('t.%I = k.%I', c, c), ' and ') from unnest(pk) c);
  execute format('select to_jsonb(t) from %s t, jsonb_populate_record(null::%s, $1) k where %s for update of t', tad, tad, kosul) into once using p_anahtar;
  if once is null then raise exception 'Satır bulunamadı (silinmiş olabilir).'; end if;
  execute format('update %s t set %s from jsonb_populate_record(null::%s, $1) k, jsonb_populate_record(null::%s, $2) r where %s returning to_jsonb(t)',
                 tad, (select string_agg(format('%I = r.%I', c, c), ', ') from unnest(cols) c), tad, tad, kosul)
    into sonra using p_anahtar, p_degerler;
  get diagnostics adet = row_count;
  if adet <> 1 then raise exception 'Güncelleme % satırı etkiledi; geri alındı.', adet; end if;
  perform oyun.yk_kaydet_log(p, p_t, p_islem, oyun.yk_anahtar(p_t, sonra), once, sonra, p_aciklama);
  return sonra;
end $$;

create or replace function oyun.yk_ekle(p oyun.profiller, p_t regclass, p_degerler jsonb, p_islem text default 'ekle', p_aciklama text default null)
returns jsonb language plpgsql as $$
declare cols text[]; sonra jsonb; tad text := oyun.yk_ad(p_t);
begin
  if p_degerler is null or jsonb_typeof(p_degerler) <> 'object' then raise exception 'Değerler eksik.'; end if;
  select array_agg(k order by k) into cols from jsonb_object_keys(p_degerler) k where k = any(oyun.yk_yazilir(p_t));
  if cols is null then
    execute format('insert into %s as t default values returning to_jsonb(t)', tad) into sonra;
  else
    execute format('insert into %s as t (%s) overriding system value select %s from jsonb_populate_record(null::%s, $1) r returning to_jsonb(t)',
                   tad, (select string_agg(format('%I', c), ', ') from unnest(cols) c),
                   (select string_agg(format('r.%I', c), ', ') from unnest(cols) c), tad)
      into sonra using p_degerler;
  end if;
  perform oyun.yk_kaydet_log(p, p_t, p_islem, case when oyun.yk_pk(p_t) is not null then oyun.yk_anahtar(p_t, sonra) end, null, sonra, p_aciklama);
  return sonra;
end $$;

create or replace function oyun.yk_sil(p oyun.profiller, p_t regclass, p_anahtar jsonb, p_islem text default 'sil', p_aciklama text default null)
returns jsonb language plpgsql as $$
declare pk text[] := oyun.yk_pk(p_t); kosul text; once jsonb; tad text := oyun.yk_ad(p_t);
begin
  if pk is null then raise exception 'Bu tablonun birincil anahtarı yok; satır silinemez.'; end if;
  if p_anahtar is null or exists (select 1 from unnest(pk) c where not (p_anahtar ? c)) then raise exception 'Satır anahtarı eksik.'; end if;
  kosul := (select string_agg(format('t.%I = k.%I', c, c), ' and ') from unnest(pk) c);
  execute format('delete from %s t using jsonb_populate_record(null::%s, $1) k where %s returning to_jsonb(t)', tad, tad, kosul) into once using p_anahtar;
  if once is null then raise exception 'Satır bulunamadı (zaten silinmiş olabilir).'; end if;
  perform oyun.yk_kaydet_log(p, p_t, p_islem, oyun.yk_anahtar(p_t, once), once, null, p_aciklama);
  return once;
end $$;

-- ---------- 8) Uygulamanın çağırdığı yönetici fonksiyonları ----------

-- Özet pano
create or replace function public.yk_ozet() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('oyuncu_ara'); t timestamptz := oyun.simdi(); cron_hata int;
begin
  begin
    execute 'select count(*) from cron.job_run_details where status = ''failed'' and start_time > now() - interval ''24 hours''' into cron_hata;
  exception when others then cron_hata := null; end;
  return jsonb_build_object(
    'yonetici', p.yonetici,
    'oyuncu', (select count(*) from oyun.profiller),
    'cevrimici', (select count(*) from oyun.profiller where son_gorulme > t - interval '15 minutes'),
    'aktif24', (select count(*) from oyun.profiller where son_gorulme > t - interval '24 hours'),
    'yeni24', (select count(*) from oyun.profiller where olusturma > t - interval '24 hours'),
    'engelli', (select count(*) from oyun.profiller where yasakli),
    'susturulmus', (select count(*) from oyun.profiller where susturma_bitis > t),
    'bekleyen_kayit', oyun.yk_bekleyen_kayit(),
    'sikayet', (select count(*) from oyun.sikayetler where durum = 'yeni'),
    'toplam_para', (select coalesce(sum(para), 0) from oyun.cuzdan),
    'hazine', (select hazine from oyun.ulke where id = 1),
    'makam', (select count(*) from oyun.makamlar where bit is null),
    'parti', (select count(*) from oyun.partiler where not kapali),
    'acik_secim', (select count(*) from oyun.secimler where durum = 'bekliyor' and oy_bas <= t and oy_bit > t),
    'motor_hata24', (select coalesce(sum(sayi), 0) from oyun.tick_hata where son > now() - interval '24 hours'),
    'cron_hata24', cron_hata,
    'bakim', oyun.bakim_acik(),
    'duyuru_bandi', oyun.uyg_ayar('duyuru_bandi') #>> '{}'
  );
end $$;

-- Oyuncu listesi (arama, süzme, sıralama)
create or replace function public.yk_oyuncular(p_ara text default null, p_filtre text default 'hepsi', p_sirala text default 'son_gorulme', p_limit int default 50, p_offset int default 0)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('oyuncu_ara'); t timestamptz := oyun.simdi(); lim int := least(greatest(coalesce(p_limit, 50), 1), 200); ofs int := greatest(coalesce(p_offset, 0), 0);
        ara text := nullif(btrim(coalesce(p_ara, '')), '');
begin
  return (
    with x as (
      select pr.*, c.para, c.kidem,
             (select count(*) from oyun.makamlar m where m.user_id = pr.id and m.bit is null) makam_say,
             (select oyun.makam_ad(m.tur, m.il_id, m.bakanlik) from oyun.makamlar m where m.user_id = pr.id and m.bit is null order by m.bas limit 1) makam_ilk
      from oyun.profiller pr left join oyun.cuzdan c on c.user_id = pr.id
      where (ara is null or pr.kad ilike '%' || ara || '%' or pr.id::text = ara)
        and case coalesce(p_filtre, 'hepsi')
              when 'cevrimici' then pr.son_gorulme > t - interval '15 minutes'
              when 'engelli' then pr.yasakli
              when 'susturulmus' then pr.susturma_bitis > t
              when 'makamli' then exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null)
              when 'yeni' then pr.olusturma > t - interval '3 days'
              when 'yonetim' then pr.yonetici or exists (select 1 from oyun.moderatorler mo where mo.user_id = pr.id)
              else true end
    )
    select jsonb_build_object(
      'toplam', (select count(*) from x),
      'liste', coalesce((select jsonb_agg(jsonb_build_object(
          'id', y.id, 'kad', y.kad, 'il', (select ad from oyun.iller where id = y.il_id), 'il_id', y.il_id,
          'parti', (select jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'renk', pa.renk) from oyun.partiler pa where pa.id = y.parti_id),
          'para', y.para, 'kidem', y.kidem, 'makam_say', y.makam_say, 'makam', y.makam_ilk,
          'son_gorulme', y.son_gorulme, 'olusturma', y.olusturma, 'yasakli', y.yasakli, 'engel_bitis', y.engel_bitis,
          'susturma_bitis', case when y.susturma_bitis > t then y.susturma_bitis end, 'yonetici', y.yonetici,
          'moderator', exists (select 1 from oyun.moderatorler mo where mo.user_id = y.id)))
        from (select * from x order by
                case when p_sirala = 'para' then x.para end desc nulls last,
                case when p_sirala = 'kidem' then x.kidem end desc nulls last,
                case when p_sirala = 'yeni' then x.olusturma end desc nulls last,
                case when p_sirala = 'ad' then lower(x.kad) end asc,
                x.son_gorulme desc nulls last, x.kad
              limit lim offset ofs) y), '[]'::jsonb)));
end $$;

-- Tek oyuncunun tam kartı
create or replace function public.yk_oyuncu(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('oyuncu_ara'); h oyun.profiller; t timestamptz := oyun.simdi(); c oyun.cuzdan;
begin
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, ''))) or id::text = btrim(coalesce(p_kad, ''));
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  select * into c from oyun.cuzdan where user_id = h.id;
  return jsonb_build_object(
    'id', h.id, 'kad', h.kad, 'il_id', h.il_id, 'il', (select ad from oyun.iller where id = h.il_id),
    'parti', (select jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'gb', pa.gb = h.id) from oyun.partiler pa where pa.id = h.parti_id),
    'gby', (select sira from oyun.parti_gby where user_id = h.id),
    'olusturma', h.olusturma, 'son_gorulme', h.son_gorulme,
    'yasakli', h.yasakli, 'engel_bitis', h.engel_bitis, 'engel_neden', h.engel_neden,
    'susturma_bitis', case when h.susturma_bitis > t then h.susturma_bitis end,
    'adaylik_yasagi_bitis', case when h.adaylik_yasagi_bitis > t then h.adaylik_yasagi_bitis end,
    'yonetici', h.yonetici,
    'moderator', (select to_jsonb(yetkiler) from oyun.moderatorler where user_id = h.id),
    'eposta', case when oyun.yetkili(p.id, 'eposta') then (select email from auth.users where id = h.id) end,
    'para', coalesce(c.para, 0), 'kidem', coalesce(c.kidem, 0),
    'unvan', oyun.unvan(h.id),
    'banka', oyun.banka_ozet(h.id),
    'makamlar', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'tur', m.tur, 'ad', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'kaynak', m.kaynak) order by m.bas)
                           from oyun.makamlar m where m.user_id = h.id and m.bit is null), '[]'::jsonb),
    'gecmis_makam', coalesce((select jsonb_agg(x order by x->>'bit' desc) from (select jsonb_build_object('ad', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'bit', m.bit, 'neden', m.bitis_neden) x
                           from oyun.makamlar m where m.user_id = h.id and m.bit is not null order by m.bit desc limit 8) z), '[]'::jsonb),
    'hareketler', coalesce((select jsonb_agg(jsonb_build_object('zaman', x.zaman, 'tutar', x.tutar, 'tur', x.tur, 'aciklama', x.aciklama) order by x.id desc)
                           from (select * from oyun.hesap_hareket where user_id = h.id order by id desc limit 15) x), '[]'::jsonb),
    'mesajlar', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'kanal', m.kanal, 'metin', m.metin, 'zaman', m.zaman, 'gizli', m.gizli) order by m.id desc)
                           from (select * from oyun.mesajlar where user_id = h.id order by id desc limit 10) m), '[]'::jsonb),
    'sikayet', (select count(*) from oyun.sikayetler where hedef_user = h.id),
    'kayit', oyun.yk_kayit_durumu(h.id)
  );
end $$;

-- Para: + ekler, − çıkarır (cüzdandaki kadarını). Hedef: oyuncu / herkes / cevrimici / aktif / yeni / il / parti / makamli
create or replace function public.yk_para(p_hedef text, p_deger text, p_tutar numeric, p_neden text default null, p_bildir boolean default true)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('para'); t timestamptz := oyun.simdi(); u uuid; mevcut numeric; x numeric; kisi int := 0; toplam numeric := 0;
        neden text := oyun.yk_metin(p_neden, 200);
begin
  if p_tutar is null or p_tutar = 0 or abs(p_tutar) > 1e12 then raise exception 'Geçerli bir tutar yaz (sıfır olamaz).'; end if;
  for u in select * from oyun.yk_hedefler(p_hedef, p_deger) loop
    if p_hedef = 'oyuncu' then perform oyun.korunan_hedef(p, u); end if;
    perform oyun.cuzdanim(u);
    if p_tutar > 0 then x := round(p_tutar);
    else select para into mevcut from oyun.cuzdan where user_id = u; x := -least(round(abs(p_tutar)), coalesce(mevcut, 0)); end if;
    continue when x = 0;
    perform oyun.para_islem(u, x, 'yonetici', 'Oyun yönetimi' || coalesce(': ' || neden, ''), t, 0);
    if p_bildir then
      perform oyun.bildir(u, case when x > 0 then format('Oyun yönetimi cüzdanına %s ₺ yükledi.%s', oyun.tl(x), coalesce(' ' || neden, ''))
                                  else format('Oyun yönetimi cüzdanından %s ₺ düştü.%s', oyun.tl(-x), coalesce(' Gerekçe: ' || neden, '')) end, t);
    end if;
    kisi := kisi + 1; toplam := toplam + x;
  end loop;
  perform oyun.mod_log(p, case when p_tutar > 0 then 'yk_para_ekle' else 'yk_para_al' end, oyun.yk_hedef_ad(p_hedef, p_deger),
                       format('%s ₺ × %s kişi = %s ₺%s', oyun.tl(abs(p_tutar)), kisi, oyun.tl(abs(toplam)), coalesce(' · ' || neden, '')));
  return jsonb_build_object('kisi', kisi, 'toplam', toplam);
end $$;

-- Kıdem: + ekler, − çıkarır (0'ın altına inmez)
create or replace function public.yk_kidem(p_hedef text, p_deger text, p_miktar numeric, p_neden text default null)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('para'); t timestamptz := oyun.simdi(); u uuid; kisi int := 0; neden text := oyun.yk_metin(p_neden, 200);
begin
  if p_miktar is null or p_miktar = 0 or abs(p_miktar) > 1e7 then raise exception 'Geçerli bir kıdem miktarı yaz.'; end if;
  for u in select * from oyun.yk_hedefler(p_hedef, p_deger) loop
    if p_hedef = 'oyuncu' then perform oyun.korunan_hedef(p, u); end if;
    perform oyun.kidem_ekle(u, p_miktar);
    perform oyun.bildir(u, format('Oyun yönetimi kıdemine %s%s puan %s.%s', case when p_miktar > 0 then '+' else '' end, rtrim(to_char(p_miktar, 'FM999999990.##'), '.'),
                                  case when p_miktar > 0 then 'ekledi' else 'düzeltme yaptı' end, coalesce(' ' || neden, '')), t);
    kisi := kisi + 1;
  end loop;
  perform oyun.mod_log(p, 'yk_kidem', oyun.yk_hedef_ad(p_hedef, p_deger), format('%s kıdem × %s kişi%s', p_miktar, kisi, coalesce(' · ' || neden, '')));
  return jsonb_build_object('kisi', kisi);
end $$;

-- Bildirim (oyuncunun zil kutusuna düşer; push açıksa telefona da gider)
create or replace function public.yk_bildirim(p_hedef text, p_deger text, p_metin text)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('duyuru'); t timestamptz := oyun.simdi(); u uuid; kisi int := 0; m text := oyun.yk_metin(p_metin, 500);
begin
  if m is null then raise exception 'Bildirim metni boş olamaz.'; end if;
  for u in select * from oyun.yk_hedefler(p_hedef, p_deger) loop
    perform oyun.bildir(u, 'Oyun yönetimi: ' || m, t); kisi := kisi + 1;
  end loop;
  perform oyun.mod_log(p, 'yk_bildirim', oyun.yk_hedef_ad(p_hedef, p_deger), m);
  return jsonb_build_object('kisi', kisi);
end $$;

-- Engelle: p_gun boş/0 → kalıcı. p_hesabi_kapat → görevlerinden alınır, partiden çıkar, mesajları gizlenir
create or replace function public.yk_engelle(p_kad text, p_gun numeric default null, p_neden text default null, p_hesabi_kapat boolean default false)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('hesap_kapat'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); bitis timestamptz;
        neden text := oyun.yk_metin(p_neden, 200);
begin
  if h.id = p.id then raise exception 'Kendi hesabını engelleyemezsin.'; end if;
  if h.yonetici then raise exception 'Yönetici hesabı engellenemez.'; end if;
  perform oyun.korunan_hedef(p, h.id);
  if p_gun is not null and p_gun > 0 then
    if p_gun > 3650 then raise exception 'En fazla 3650 gün.'; end if;
    bitis := t + make_interval(secs => (p_gun * 86400)::double precision);
  end if;
  if p_hesabi_kapat then perform oyun.hesap_kapat(h.id, t);
  else update oyun.profiller set yasakli = true where id = h.id; end if;
  update oyun.profiller set engel_bitis = bitis, engel_neden = neden where id = h.id;
  perform oyun.bildir(h.id, case when bitis is null then 'Hesabın oyun yönetimi tarafından engellendi.' else format('Hesabın %s tarihine kadar engellendi.', to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')) end
                            || coalesce(' Gerekçe: ' || neden, ''), t);
  perform oyun.mod_log(p, case when bitis is null then 'yk_engel_kalici' else 'yk_engel_sureli' end, h.kad,
                       concat_ws(' · ', case when bitis is not null then 'bitiş ' || to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI') end, neden,
                                 case when p_hesabi_kapat then 'görevleri alındı, mesajları gizlendi' end));
  return public.yk_oyuncu(h.kad);
end $$;

create or replace function public.yk_engel_kaldir(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('hesap_kapat'); h oyun.profiller := oyun.profil_bul(p_kad);
begin
  perform oyun.korunan_hedef(p, h.id);
  if not h.yasakli then raise exception '% zaten engelli değil.', h.kad; end if;
  update oyun.profiller set yasakli = false, engel_bitis = null, engel_neden = null where id = h.id;
  perform oyun.bildir(h.id, 'Hesabındaki engel oyun yönetimi tarafından kaldırıldı. Tekrar hoş geldin!', oyun.simdi());
  perform oyun.mod_log(p, 'yk_engel_kaldir', h.kad, null);
  return public.yk_oyuncu(h.kad);
end $$;

-- Susturma: saat ≤ 0 → kaldır
create or replace function public.yk_sustur(p_kad text, p_saat numeric, p_neden text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sustur'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); bitis timestamptz;
        neden text := oyun.yk_metin(p_neden, 200);
begin
  if h.id = p.id then raise exception 'Kendine işlem yapamazsın.'; end if;
  perform oyun.korunan_hedef(p, h.id);
  if coalesce(p_saat, 0) > 0 then
    if p_saat > 87600 then raise exception 'Süre çok uzun.'; end if;
    bitis := t + make_interval(secs => (p_saat * 3600)::double precision);
  end if;
  update oyun.profiller set susturma_bitis = bitis where id = h.id;
  perform oyun.bildir(h.id, case when bitis is null then 'Sohbet susturman kaldırıldı.'
                                 else format('Oyun yönetimi seni %s tarihine kadar sohbette susturdu.%s', to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), coalesce(' Gerekçe: ' || neden, '')) end, t);
  perform oyun.mod_log(p, case when bitis is null then 'susturma_kaldir' else 'yk_sustur' end, h.kad,
                       concat_ws(' · ', case when bitis is not null then p_saat || ' saat' end, neden));
  return public.yk_oyuncu(h.kad);
end $$;

-- Aday olma yasağı: gün ≤ 0 → kaldır
create or replace function public.yk_adaylik_yasagi(p_kad text, p_gun numeric, p_neden text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); bitis timestamptz;
begin
  perform oyun.korunan_hedef(p, h.id);
  if coalesce(p_gun, 0) > 0 then bitis := t + make_interval(secs => (least(p_gun, 3650) * 86400)::double precision); end if;
  update oyun.profiller set adaylik_yasagi_bitis = bitis where id = h.id;
  perform oyun.bildir(h.id, case when bitis is null then 'Aday olma yasağın kaldırıldı.'
                                 else format('Oyun yönetimi %s tarihine kadar aday olmanı yasakladı.%s', to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), coalesce(' Gerekçe: ' || nullif(btrim(p_neden), ''), '')) end, t);
  perform oyun.mod_log(p, 'yk_adaylik_yasagi', h.kad, coalesce(p_gun::text || ' gün', 'kaldırıldı'));
  return public.yk_oyuncu(h.kad);
end $$;

-- Makam ver. p_tur: cb, cb_yardimcisi (p_sira 1/2), bakan (p_bakanlik), mv (p_il), bel (p_il), tbmm, bskv, grup_bskv, gb, gby (p_sira 1-6)
create or replace function public.yk_makam_ver(p_kad text, p_tur text, p_il int default null, p_bakanlik text default null, p_sira int default null, p_tek_gorev boolean default true)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi();
        m record; v_ad text; bak text; kota int; dolu int; pa oyun.partiler; eski uuid;
begin
  perform oyun.korunan_hedef(p, h.id);
  if h.yasakli then raise exception 'Engelli hesaba görev verilemez. Önce engeli kaldır.'; end if;
  if p_tur not in ('cb','cb_yardimcisi','bakan','mv','bel','tbmm','bskv','grup_bskv','gb','gby') then raise exception 'Geçersiz görev türü.'; end if;
  if p_tur in ('mv','bel') and (p_il is null or not exists (select 1 from oyun.iller where id = p_il)) then raise exception 'İl seçmelisin.'; end if;
  if p_tur = 'bakan' then
    select kod into bak from oyun.bakanliklar where kod = p_bakanlik;
    if bak is null then raise exception 'Bakanlık seçmelisin.'; end if;
  elsif p_tur = 'cb_yardimcisi' then
    if p_sira not in (1, 2) or p_sira is null then raise exception 'Yardımcılık sırası 1 ya da 2 olmalı.'; end if;
    bak := p_sira::text;
  end if;
  if p_tur in ('gb','gby','grup_bskv') then
    select * into pa from oyun.partiler where id = h.parti_id;
    if pa.id is null or pa.kapali then raise exception '% bir partiye üye değil. Önce partisini belirle.', h.kad; end if;
  end if;
  if p_tur = 'gby' and (p_sira is null or p_sira not between 1 and 6) then raise exception 'Genel başkan yardımcılığı sırası 1-6 olmalı.'; end if;

  -- zaten aynı görevde mi?
  if p_tur = 'gb' and pa.gb = h.id then raise exception '% zaten genel başkan.', h.kad; end if;
  if p_tur not in ('gb','gby') and exists (select 1 from oyun.makamlar where user_id = h.id and bit is null and tur = p_tur
        and (p_tur not in ('mv','bel') or il_id = p_il) and (p_tur not in ('bakan','cb_yardimcisi') or bakanlik = bak)) then
    raise exception '% zaten bu görevde.', h.kad;
  end if;

  -- tek görev kuralı: uyumsuz görevleri bitir
  if p_tek_gorev then
    for m in select id, tur from oyun.makamlar where user_id = h.id and bit is null loop
      if not oyun.rol_uyumlu(m.tur, p_tur) or (m.tur = p_tur and p_tur not in ('bakan')) then
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end if;
    end loop;
    if p_tur <> 'gb' and not oyun.rol_uyumlu('gb', p_tur) then update oyun.partiler set gb = null where gb = h.id; end if;
    if p_tur <> 'gby' and not oyun.rol_uyumlu('gby', p_tur) then delete from oyun.parti_gby where user_id = h.id; end if;
  end if;

  if p_tur = 'gb' then
    update oyun.partiler set gb = h.id where id = pa.id;
    v_ad := pa.kisa || ' Genel Başkanlığı';
  elsif p_tur = 'gby' then
    select user_id into eski from oyun.parti_gby where parti_id = pa.id and sira = p_sira;
    delete from oyun.parti_gby where parti_id = pa.id and (sira = p_sira or user_id = h.id);
    insert into oyun.parti_gby(parti_id, sira, user_id, atama) values (pa.id, p_sira, h.id, t);
    if eski is not null and eski <> h.id then perform oyun.bildir(eski, format('%s genel başkan yardımcılığı görevin oyun yönetimi kararıyla sona erdi.', pa.kisa), t); end if;
    v_ad := pa.kisa || ' ' || p_sira || '. Genel Başkan Yardımcılığı';
  else
    -- tek kişilik koltuklar: mevcut sahibi görevden alınır
    if p_tur in ('cb','tbmm','bel','bakan','cb_yardimcisi') then
      for m in select id, user_id from oyun.makamlar where bit is null and tur = p_tur and user_id <> h.id
               and (p_tur <> 'bel' or il_id = p_il) and (p_tur not in ('bakan','cb_yardimcisi') or bakanlik = bak) loop
        perform oyun.makam_bitir(m.id, t, 'yonetici_karari');
        perform oyun.bildir(m.user_id, format('Oyun yönetimi kararıyla %s görevin sona erdi.', oyun.makam_ad(p_tur, p_il::smallint, bak)), t);
      end loop;
    end if;
    if p_tur = 'mv' then
      select mv into kota from oyun.iller where id = p_il;
      select count(*) into dolu from oyun.makamlar where tur = 'mv' and bit is null and il_id = p_il;
      if kota is not null and dolu >= kota then raise exception '% ilinin % milletvekilliği dolu. Önce bir vekili görevden al.', (select i.ad from oyun.iller i where i.id = p_il), kota; end if;
    end if;
    insert into oyun.makamlar(tur, user_id, il_id, parti_id, bakanlik, kaynak, bas)
    values (p_tur, h.id, case when p_tur in ('mv','bel') then p_il end, h.parti_id, bak, 'atama', t);
    v_ad := oyun.makam_ad(p_tur, p_il::smallint, bak);
  end if;
  perform oyun.bildir(h.id, format('Oyun yönetimi seni %s görevine atadı. Hayırlı olsun!', v_ad), t);
  perform oyun.olay('makam', format('%s, %s görevine atandı.', h.kad, v_ad), case when p_tur in ('mv','bel') then p_il::smallint end, h.parti_id, t);
  perform oyun.mod_log(p, 'yk_makam_ver', h.kad, v_ad);
  return public.yk_oyuncu(h.kad);
end $$;

-- Makamdan al (makam numarasıyla)
create or replace function public.yk_makam_al(p_makam bigint, p_neden text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); m oyun.makamlar; t timestamptz := oyun.simdi(); v_ad text; v_kad text;
begin
  select * into m from oyun.makamlar where id = p_makam and bit is null for update;
  if m.id is null then raise exception 'Görev bulunamadı ya da zaten sona ermiş.'; end if;
  perform oyun.korunan_hedef(p, m.user_id);
  v_ad := oyun.makam_ad(m.tur, m.il_id, m.bakanlik); v_kad := oyun.kad(m.user_id);
  perform oyun.makam_bitir(m.id, t, 'yonetici_karari');
  perform oyun.bildir(m.user_id, format('Oyun yönetimi kararıyla %s görevin sona erdi.%s', v_ad, coalesce(' Gerekçe: ' || nullif(btrim(p_neden), ''), '')), t);
  perform oyun.olay('makam', format('%s, %s görevinden alındı.', v_kad, v_ad), m.il_id, m.parti_id, t);
  perform oyun.mod_log(p, 'yk_makam_al', v_kad, v_ad || coalesce(' · ' || nullif(btrim(p_neden), ''), ''));
  return public.yk_oyuncu(v_kad);
end $$;

-- Parti görevinden al: gb / gby
create or replace function public.yk_parti_gorev_al(p_kad text, p_rol text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); pk text;
begin
  perform oyun.korunan_hedef(p, h.id);
  select kisa into pk from oyun.partiler where id = h.parti_id;
  if p_rol = 'gb' then
    update oyun.partiler set gb = null where gb = h.id;
    if not found then raise exception '% genel başkan değil.', h.kad; end if;
    perform oyun.bildir(h.id, format('Oyun yönetimi kararıyla %s genel başkanlığın sona erdi.', coalesce(pk, 'parti')), t);
  elsif p_rol = 'gby' then
    delete from oyun.parti_gby where user_id = h.id;
    if not found then raise exception '% genel başkan yardımcısı değil.', h.kad; end if;
    perform oyun.bildir(h.id, format('Oyun yönetimi kararıyla %s genel başkan yardımcılığın sona erdi.', coalesce(pk, 'parti')), t);
  else raise exception 'Geçersiz parti görevi.'; end if;
  perform oyun.mod_log(p, 'yk_parti_gorev_al', h.kad, p_rol);
  return public.yk_oyuncu(h.kad);
end $$;

-- Partisini değiştir (p_parti boş → bağımsız)
create or replace function public.yk_parti_degistir(p_kad text, p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); pa oyun.partiler;
begin
  perform oyun.korunan_hedef(p, h.id);
  if p_parti is not null then
    select * into pa from oyun.partiler where id = p_parti;
    if pa.id is null or pa.kapali then raise exception 'Parti bulunamadı ya da kapalı.'; end if;
    if h.parti_id = pa.id then raise exception '% zaten bu partide.', h.kad; end if;
  end if;
  if h.parti_id is not null then perform oyun._ayril(h.id, t); end if;
  if p_parti is not null then
    update oyun.profiller set parti_id = pa.id, parti_at = t where id = h.id;
    perform oyun.bildir(h.id, format('Oyun yönetimi seni %s üyesi yaptı.', pa.ad), t);
  else
    perform oyun.bildir(h.id, 'Oyun yönetimi seni partinden çıkardı; artık bağımsızsın.', t);
  end if;
  perform oyun.mod_log(p, 'yk_parti_degistir', h.kad, coalesce(pa.kisa, 'bağımsız'));
  return public.yk_oyuncu(h.kad);
end $$;

-- İlini değiştir
create or replace function public.yk_il_degistir(p_kad text, p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); v_ad text;
begin
  perform oyun.korunan_hedef(p, h.id);
  select i.ad into v_ad from oyun.iller i where i.id = p_il;
  if v_ad is null then raise exception 'İl bulunamadı.'; end if;
  if h.il_id = p_il then raise exception '% zaten %.', h.kad, v_ad; end if;
  update oyun.profiller set il_id = p_il, il_at = t where id = h.id;
  perform oyun.bildir(h.id, format('Oyun yönetimi kaydını %s iline taşıdı.', v_ad), t);
  perform oyun.mod_log(p, 'yk_il_degistir', h.kad, v_ad);
  return public.yk_oyuncu(h.kad);
end $$;

-- Kullanıcı adını değiştir
create or replace function public.yk_ad_degistir(p_kad text, p_yeni text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); h oyun.profiller := oyun.profil_bul(p_kad); y text := btrim(coalesce(p_yeni, ''));
begin
  if y !~ '^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$' then raise exception 'Kullanıcı adı 3-20 karakter olmalı; harf, rakam ve alt çizgi kullanılabilir.'; end if;
  if exists (select 1 from oyun.profiller where lower(kad) = lower(y) and id <> h.id) then raise exception 'Bu kullanıcı adı kullanımda.'; end if;
  update oyun.profiller set kad = y where id = h.id;
  perform oyun.bildir(h.id, format('Oyun yönetimi kullanıcı adını %s olarak değiştirdi.', y), oyun.simdi());
  perform oyun.mod_log(p, 'yk_ad_degistir', h.kad, y);
  return public.yk_oyuncu(y);
end $$;

-- Kasalar: hazine / il / parti / sirket / dernek (+ ekler, − çıkarır; hazine ve il kasası oyundaki birimiyle)
create or replace function public.yk_kasa(p_tur text, p_id text, p_tutar numeric, p_neden text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); tablo text; anahtar jsonb; alan text; once numeric; yeni numeric; v_ad text;
begin
  if p_tutar is null or p_tutar = 0 then raise exception 'Tutar sıfır olamaz.'; end if;
  if p_tur = 'hazine' then tablo := 'oyun.ulke'; anahtar := '{"id":1}'; alan := 'hazine'; select hazine into once from oyun.ulke where id = 1; v_ad := 'Hazine';
  elsif p_tur = 'il' then tablo := 'oyun.il_durum'; anahtar := jsonb_build_object('il_id', p_id::int); alan := 'kasa';
    select coalesce(kasa, 0) into once from oyun.il_durum where il_id = p_id::int; v_ad := (select i.ad from oyun.iller i where i.id = p_id::int) || ' belediye kasası';
  elsif p_tur = 'parti' then tablo := 'oyun.partiler'; anahtar := jsonb_build_object('id', p_id::bigint); alan := 'kasa';
    select x.kasa, x.kisa into once, v_ad from oyun.partiler x where x.id = p_id::bigint; v_ad := v_ad || ' parti kasası';
  elsif p_tur = 'sirket' then tablo := 'oyun.sirketler'; anahtar := jsonb_build_object('id', p_id::bigint); alan := 'kasa';
    select x.kasa, x.ad into once, v_ad from oyun.sirketler x where x.id = p_id::bigint; v_ad := v_ad || ' şirket kasası';
  elsif p_tur = 'dernek' then tablo := 'oyun.dernekler'; anahtar := jsonb_build_object('id', p_id::bigint); alan := 'kasa';
    select x.kasa, x.ad into once, v_ad from oyun.dernekler x where x.id = p_id::bigint; v_ad := v_ad || ' dernek kasası';
  else raise exception 'Geçersiz kasa türü.'; end if;
  if once is null and p_tur <> 'il' then raise exception 'Kayıt bulunamadı.'; end if;
  yeni := greatest(0, coalesce(once, 0) + p_tutar);
  perform oyun.yk_guncelle(p, oyun.yk_tablo_coz(tablo), anahtar, jsonb_build_object(alan, yeni), 'guncelle', 'Kasa: ' || v_ad || coalesce(' · ' || nullif(btrim(p_neden), ''), ''));
  perform oyun.mod_log(p, 'yk_kasa', v_ad, format('%s → %s', once, yeni));
  return jsonb_build_object('ad', v_ad, 'once', once, 'yeni', yeni);
end $$;

-- Makam tablosu + seçim listeleri (iller, bakanlıklar, partiler)
create or replace function public.yk_makamlar() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam');
begin
  return jsonb_build_object(
    'makamlar', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'tur', m.tur, 'ad', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'il_id', m.il_id, 'bakanlik', m.bakanlik,
                                   'kad', pr.kad, 'parti', pa.kisa, 'renk', pa.renk, 'bas', m.bas, 'kaynak', m.kaynak)
                          order by case m.tur when 'cb' then 1 when 'cb_yardimcisi' then 2 when 'bakan' then 3 when 'tbmm' then 4 when 'bskv' then 5 when 'grup_bskv' then 6 when 'bel' then 7 else 8 end, m.bakanlik, m.il_id, pr.kad)
                          from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id left join oyun.partiler pa on pa.id = m.parti_id where m.bit is null), '[]'::jsonb),
    'parti_gorev', coalesce((select jsonb_agg(x) from (
        select jsonb_build_object('rol', 'gb', 'parti', pa.kisa, 'parti_id', pa.id, 'renk', pa.renk, 'kad', pr.kad) x from oyun.partiler pa join oyun.profiller pr on pr.id = pa.gb where not pa.kapali
        union all
        select jsonb_build_object('rol', 'gby', 'sira', g.sira, 'parti', pa.kisa, 'parti_id', pa.id, 'renk', pa.renk, 'kad', pr.kad) from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id join oyun.profiller pr on pr.id = g.user_id) y), '[]'::jsonb),
    'iller', (select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad, 'mv', i.mv, 'mv_dolu', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.il_id = i.id)) order by i.ad) from oyun.iller i),
    'bakanliklar', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad) order by b.ad) from oyun.bakanliklar b),
    'partiler', coalesce((select jsonb_agg(jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'uye', (select count(*) from oyun.profiller x where x.parti_id = pa.id)) order by pa.kisa) from oyun.partiler pa where not pa.kapali), '[]'::jsonb)
  );
end $$;

-- Seçimler
create or replace function public.yk_secimler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'tur', s.tur, 'donem', s.donem, 'durum', s.durum, 'ara', s.ara,
           'il', (select ad from oyun.iller where id = s.hedef_il_id), 'parti', (select kisa from oyun.partiler where id = s.hedef_parti_id),
           'basvuru_bas', s.basvuru_bas, 'basvuru_bit', s.basvuru_bit, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit, 'sonuc_at', s.sonuc_at, 'goreve_bas', s.goreve_bas,
           'aday', (select count(*) from oyun.adaylar a where a.secim_id = s.id)) order by coalesce(s.oy_bas, s.sonuc_at), s.id)
    from oyun.secimler s where coalesce(s.goreve_bas, s.sonuc_at, s.oy_bit) > t - interval '7 days' or s.durum = 'bekliyor'), '[]'::jsonb);
end $$;

-- Motoru hemen çalıştır (seçim saatini değiştirdikten sonra beklemeden işlesin)
create or replace function public.yk_motor_calistir() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); n int;
begin
  n := oyun.tick();
  perform oyun.mod_log(p, 'yk_motor', null, n || ' seçim adımı işlendi');
  return jsonb_build_object('islenen', n);
end $$;

-- Sistem hataları: motor adımları + zamanlanmış görev hataları
create or replace function public.yk_sistem_hatalari(p_limit int default 50) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); cronlar jsonb;
begin
  begin
    execute $q$select coalesce(jsonb_agg(x order by (x->>'son') desc), '[]'::jsonb) from (
      select jsonb_build_object('is', j.jobname, 'hata', left(d.return_message, 300), 'sayi', count(*), 'son', max(d.start_time)) x
      from cron.job_run_details d join cron.job j on j.jobid = d.jobid
      where d.status = 'failed' and d.start_time > now() - interval '48 hours' group by j.jobname, left(d.return_message, 300)) z$q$ into cronlar;
  exception when others then cronlar := '[]'::jsonb; end;
  return jsonb_build_object(
    'motor', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'adim', h.adim, 'hata', h.hata, 'ayrinti', h.ayrinti, 'ilk', h.zaman, 'son', h.son, 'sayi', h.sayi) order by h.son desc)
                       from (select * from oyun.tick_hata order by son desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) h), '[]'::jsonb),
    'zamanlayici', cronlar);
end $$;

-- Uygulama ayarları (yönetici görünümü ve kaydı)
create or replace function public.yk_uygulama_ayarlari() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('anahtar', anahtar, 'deger', deger, 'aciklama', aciklama, 'guncelleme', guncelleme) order by anahtar) from oyun.uygulama_ayar), '[]'::jsonb);
end $$;

create or replace function public.yk_uygulama_ayar_kaydet(p jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare y oyun.profiller := oyun.yk_sahip(); k text; v jsonb; once jsonb;
begin
  if p is null or jsonb_typeof(p) <> 'object' then raise exception 'Ayar bilgisi eksik.'; end if;
  for k, v in select * from jsonb_each(p) loop
    if k !~ '^[a-z0-9_]{2,40}$' then raise exception 'Geçersiz ayar adı: %', k; end if;
    select to_jsonb(u) into once from oyun.uygulama_ayar u where anahtar = k;
    insert into oyun.uygulama_ayar(anahtar, deger, guncelleme) values (k, coalesce(v, 'null'::jsonb), now())
    on conflict (anahtar) do update set deger = excluded.deger, guncelleme = excluded.guncelleme;
    perform oyun.yk_kaydet_log(y, 'oyun.uygulama_ayar'::regclass, case when once is null then 'ekle' else 'guncelle' end,
                               jsonb_build_object('anahtar', k), once, (select to_jsonb(u) from oyun.uygulama_ayar u where anahtar = k), 'Uygulama ayarı');
  end loop;
  perform oyun.mod_log(y, 'yk_uygulama_ayar', null, left(p::text, 300));
  return public.yk_uygulama_ayarlari();
end $$;

-- Veri düzenleyici: tablo listesi
create or replace function public.yk_tablolar() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip();
begin
  return (select jsonb_agg(jsonb_build_object('ad', ns.nspname || '.' || c.relname, 'satir', greatest(c.reltuples, 0)::bigint,
                   'pk', (select array_agg(a.attname) from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey::int2[]) where i.indrelid = c.oid and i.indisprimary),
                   'aciklama', obj_description(c.oid, 'pg_class')) order by ns.nspname, c.relname)
          from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
          where ns.nspname in ('oyun', 'oyun_yonetim') and c.relkind in ('r', 'p'));
end $$;

-- Veri düzenleyici: satırlar
create or replace function public.yk_tablo(p_tablo text, p_ara text default null, p_sutun text default null, p_deger text default null,
                                           p_sirala text default null, p_azalan boolean default true, p_limit int default 50, p_offset int default 0)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); tb regclass := oyun.yk_tablo_coz(p_tablo); tad text; pk text[]; kosul text := 'true'; sira text;
        lim int := least(greatest(coalesce(p_limit, 50), 1), 200); ofs int := greatest(coalesce(p_offset, 0), 0); satirlar jsonb; toplam bigint; sutunlar jsonb; adlar jsonb;
begin
  tad := oyun.yk_ad(tb); pk := oyun.yk_pk(tb);
  select jsonb_agg(jsonb_build_object('ad', a.attname, 'tip', format_type(a.atttypid, a.atttypmod), 'pk', a.attname = any(coalesce(pk, '{}')),
           'bos', not a.attnotnull, 'varsayilan', pg_get_expr(d.adbin, d.adrelid), 'uretilmis', a.attgenerated <> '' or a.attidentity = 'a') order by a.attnum)
    into sutunlar
    from pg_attribute a left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
   where a.attrelid = tb and a.attnum > 0 and not a.attisdropped;
  if nullif(btrim(coalesce(p_ara, '')), '') is not null then kosul := kosul || ' and to_jsonb(t)::text ilike ''%'' || $1 || ''%'''; end if;
  if nullif(btrim(coalesce(p_sutun, '')), '') is not null then
    if not exists (select 1 from pg_attribute where attrelid = tb and attname = p_sutun and attnum > 0 and not attisdropped) then raise exception 'Sütun bulunamadı: %', p_sutun; end if;
    if lower(btrim(coalesce(p_deger, ''))) in ('null', 'boş', 'bos') then kosul := kosul || format(' and t.%I is null', p_sutun);
    elsif position('%' in coalesce(p_deger, '')) > 0 then kosul := kosul || format(' and t.%I::text ilike $2', p_sutun);
    else kosul := kosul || format(' and t.%I::text = $2', p_sutun); end if;
  end if;
  if p_sirala is not null and exists (select 1 from pg_attribute where attrelid = tb and attname = p_sirala and attnum > 0 and not attisdropped) then
    sira := format('t.%I %s nulls last', p_sirala, case when coalesce(p_azalan, true) then 'desc' else 'asc' end);
  elsif pk is not null then
    sira := (select string_agg(format('t.%I %s', c, case when coalesce(p_azalan, true) then 'desc' else 'asc' end), ', ') from unnest(pk) c);
  else sira := '1'; end if;
  execute format('select count(*) from %s t where %s', tad, kosul) into toplam using btrim(coalesce(p_ara, '')), btrim(coalesce(p_deger, ''));
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]''::jsonb) from (select t.* from %s t where %s order by %s limit %s offset %s) x', tad, kosul, sira, lim, ofs)
    into satirlar using btrim(coalesce(p_ara, '')), btrim(coalesce(p_deger, ''));
  select coalesce(jsonb_object_agg(pr.id, pr.kad), '{}'::jsonb) into adlar from oyun.profiller pr
   where pr.id::text in (select e.value #>> '{}' from jsonb_array_elements(satirlar) r, jsonb_each(r) e
                          where jsonb_typeof(e.value) = 'string' and (e.value #>> '{}') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  return jsonb_build_object('tablo', tad, 'pk', to_jsonb(pk), 'sutunlar', sutunlar, 'toplam', toplam, 'satirlar', satirlar, 'adlar', adlar,
                            'aciklama', obj_description(tb, 'pg_class'));
end $$;

-- Veri düzenleyici: kaydet (p_anahtar boşsa yeni satır)
create or replace function public.yk_satir_kaydet(p_tablo text, p_anahtar jsonb, p_degerler jsonb, p_aciklama text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); tb regclass := oyun.yk_tablo_coz(p_tablo); r jsonb;
begin
  if p_anahtar is null or p_anahtar = 'null'::jsonb or p_anahtar = '{}'::jsonb then r := oyun.yk_ekle(p, tb, p_degerler, 'ekle', p_aciklama);
  else r := oyun.yk_guncelle(p, tb, p_anahtar, p_degerler, 'guncelle', p_aciklama); end if;
  perform oyun.mod_log(p, case when p_anahtar is null or p_anahtar = 'null'::jsonb or p_anahtar = '{}'::jsonb then 'yk_veri_ekle' else 'yk_veri_guncelle' end,
                       oyun.yk_ad(tb), left(coalesce(p_anahtar::text, '') || ' ' || p_degerler::text, 300));
  return r;
end $$;

create or replace function public.yk_satir_sil(p_tablo text, p_anahtar jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); tb regclass := oyun.yk_tablo_coz(p_tablo); r jsonb;
begin
  r := oyun.yk_sil(p, tb, p_anahtar);
  perform oyun.mod_log(p, 'yk_veri_sil', oyun.yk_ad(tb), left(p_anahtar::text, 300));
  return r;
end $$;

-- Değişiklik geçmişi ve geri alma
create or replace function public.yk_degisiklikler(p_limit int default 60, p_tablo text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'zaman', d.zaman, 'kad', d.kad, 'tablo', d.tablo, 'islem', d.islem, 'anahtar', d.anahtar,
                   'once', d.once, 'sonra', d.sonra, 'aciklama', d.aciklama, 'geri_alindi', d.geri_alindi) order by d.id desc)
    from (select * from oyun.yk_degisiklik where p_tablo is null or tablo = p_tablo order by id desc limit least(greatest(coalesce(p_limit, 60), 1), 300)) d), '[]'::jsonb);
end $$;

create or replace function public.yk_geri_al(p_id bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yk_sahip(); d oyun.yk_degisiklik; tb regclass; degis jsonb; r jsonb;
begin
  select * into d from oyun.yk_degisiklik where id = p_id for update;
  if d.id is null then raise exception 'Kayıt bulunamadı.'; end if;
  if d.geri_alindi is not null then raise exception 'Bu değişiklik zaten geri alındı.'; end if;
  if d.islem = 'geri_al' then raise exception 'Geri alma işlemi geri alınamaz; ilgili değişikliği yeniden yap.'; end if;
  tb := oyun.yk_tablo_coz(d.tablo);
  if d.islem = 'guncelle' then
    select jsonb_object_agg(k, d.once -> k) into degis from jsonb_object_keys(d.once) k
     where (d.once -> k) is distinct from (d.sonra -> k) and k = any(oyun.yk_yazilir(tb));
    if degis is null then raise exception 'Geri alınacak bir fark yok.'; end if;
    r := oyun.yk_guncelle(p, tb, oyun.yk_anahtar(tb, d.sonra), degis, 'geri_al', 'Geri alındı: #' || d.id);
  elsif d.islem = 'ekle' then
    r := oyun.yk_sil(p, tb, oyun.yk_anahtar(tb, d.sonra), 'geri_al', 'Geri alındı: #' || d.id);
  elsif d.islem = 'sil' then
    select jsonb_object_agg(k, d.once -> k) into degis from jsonb_object_keys(d.once) k where k = any(oyun.yk_yazilir(tb));
    r := oyun.yk_ekle(p, tb, degis, 'geri_al', 'Geri alındı: #' || d.id);
  else raise exception 'Bu işlem geri alınamaz.'; end if;
  update oyun.yk_degisiklik set geri_alindi = now() where id = d.id;
  perform oyun.mod_log(p, 'yk_geri_al', d.tablo, '#' || d.id);
  return r;
end $$;

-- ---------- 9) Erişim izinleri ----------
do $$
declare f text;
begin
  foreach f in array array[
    'yk_ozet()','yk_oyuncular(text,text,text,int,int)','yk_oyuncu(text)',
    'yk_para(text,text,numeric,text,boolean)','yk_kidem(text,text,numeric,text)','yk_bildirim(text,text,text)',
    'yk_engelle(text,numeric,text,boolean)','yk_engel_kaldir(text)','yk_sustur(text,numeric,text)','yk_adaylik_yasagi(text,numeric,text)',
    'yk_makam_ver(text,text,int,text,int,boolean)','yk_makam_al(bigint,text)','yk_parti_gorev_al(text,text)',
    'yk_parti_degistir(text,bigint)','yk_il_degistir(text,int)','yk_ad_degistir(text,text)','yk_kasa(text,text,numeric,text)',
    'yk_makamlar()','yk_secimler()','yk_motor_calistir()','yk_sistem_hatalari(int)',
    'yk_uygulama_ayarlari()','yk_uygulama_ayar_kaydet(jsonb)',
    'yk_tablolar()','yk_tablo(text,text,text,text,text,boolean,int,int)','yk_satir_kaydet(text,jsonb,jsonb,text)','yk_satir_sil(text,jsonb)',
    'yk_degisiklikler(int,text)','yk_geri_al(bigint)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- Giriş ekranından önce de okunur (destek e-postası, bakım modu, mağaza bağlantıları)
  revoke all on function public.uygulama_ayar() from public;
  grant execute on function public.uygulama_ayar() to anon, authenticated;
end $$;

commit;

select cron.schedule('cron-gecmis-temizlik', '23 3 * * *', $$delete from cron.job_run_details where end_time < now() - interval '7 days'$$);
