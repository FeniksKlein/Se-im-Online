-- =====================================================================
--  14 · ÇOKLU HESAPLA MÜCADELE, VATANDAŞLIK (OY) ŞARTLARI, PARTİ KURULUŞU
--
--  İlke: "bir insan = bir vatandaş". Aynı kişinin birden çok hesapla oy kullanması, aday olması,
--  parti kurması seçimleri çarpıtır. Kullanılan sinyaller (sektördeki yaygın yöntemler):
--    • cihaz kimliği (uygulamanın cihazda ürettiği kalıcı kimlik) ve tarayıcı/cihaz izi (parmak izi)
--    • bağlantı adresi (IP) — tek başına delil sayılmaz (aile, okul, mobil operatör paylaşımı), yöneticiye gösterilir
--    • tek kullanımlık e-posta servisleri engellenir; e-posta doğrulaması aranır
--  Ham değerler saklanmaz: hepsi gizli bir tuzla SHA-256 özetine çevrilir (KVKK: veri en aza indirme).
--
--  Kural: aynı cihazda/izde daha önce açılmış başka bir hesap varsa yeni hesap "inceleme bekliyor" olur;
--  oy kullanamaz, aday olamaz, parti kuramaz ve kurucu olamaz. Aile içi gerçek paylaşımda yönetici onaylar.
--  Ayrıca aynı cihazdan aynı seçimde yalnızca bir oy kullanılabilir.
--
--  Vatandaşlık (oy ve adaylık) şartları — ayarlardan değiştirilebilir:
--    hesap yaşı (min_hesap_gun) · doğrulanmış e-posta · en az "Vatandaş" statüsü (oy_min_kidem)
--    cihaz doğrulaması · şüpheli hesap olmamak · yerel ve genel seçimde ilde en az oy_il_gun gündür kayıtlı olmak
--  Parti kurma: kurucunun kıdemi en az parti_kurucu_kidem; parti_kurulus_gun içinde parti_kurucu_sayi kurucu üye
--  (şartları taşıyan üye) toplanmazsa kuruluş düşer. (Gerçekte Siyasi Partiler Kanunu en az 30 kurucu arar.)
-- =====================================================================

alter table oyun.ayarlar add column if not exists oy_min_kidem       int     not null default 10;
alter table oyun.ayarlar add column if not exists oy_il_gun          int     not null default 7;
alter table oyun.ayarlar add column if not exists eposta_zorunlu     boolean not null default true;
alter table oyun.ayarlar add column if not exists cihaz_zorunlu      boolean not null default true;
alter table oyun.ayarlar add column if not exists cihaz_max_hesap    int     not null default 2;
alter table oyun.ayarlar add column if not exists parti_kurucu_sayi  int     not null default 5;
alter table oyun.ayarlar add column if not exists parti_kurucu_kidem int     not null default 30;
alter table oyun.ayarlar add column if not exists parti_kurulus_gun  int     not null default 7;
alter table oyun.ayarlar add column if not exists coklu_kontrol      boolean not null default true;
alter table oyun.ayarlar add column if not exists iz_tuz             text    not null default md5(random()::text || clock_timestamp()::text);

create table if not exists oyun.oturumlar(
  id      bigserial primary key,
  user_id uuid not null,                 -- auth.users kimliği (profil açılmadan önce de kaydedilir)
  cihaz   text,                          -- tuzlanmış özet
  iz      text,
  ip      text,
  ilk     timestamptz not null,
  son     timestamptz not null,
  sayi    int not null default 1,
  unique (user_id, cihaz, iz, ip)
);
create index if not exists oturum_cihaz on oyun.oturumlar(cihaz);
create index if not exists oturum_iz on oyun.oturumlar(iz);
create index if not exists oturum_ip on oyun.oturumlar(ip, son);

-- Yöneticinin "gerçek kişi, paylaşım meşru" diye onayladığı hesaplar
create table if not exists oyun.hesap_onay(
  user_id  uuid primary key references oyun.profiller(id) on delete cascade,
  yonetici uuid,
  not_     text,
  zaman    timestamptz not null
);
-- Aynı cihazdan aynı seçimde tek oy (oy içeriği değil yalnızca "bu cihaz bu sandıkta oy kullandı" bilgisi)
create table if not exists oyun.oy_cihaz(
  anahtar text not null,                 -- 's<secim_id>' / 'r<referandum_id>'
  cihaz   text not null,
  primary key (anahtar, cihaz)
);
create table if not exists oyun.gecici_eposta(alan text primary key);
insert into oyun.gecici_eposta(alan) values
 ('mailinator.com'),('10minutemail.com'),('guerrillamail.com'),('guerrillamail.net'),('sharklasers.com'),('temp-mail.org'),
 ('tempmail.com'),('tempmail.net'),('yopmail.com'),('yopmail.net'),('trashmail.com'),('getnada.com'),('nada.email'),
 ('dispostable.com'),('maildrop.cc'),('throwawaymail.com'),('fakeinbox.com'),('mintemail.com'),('mohmal.com'),
 ('emailondeck.com'),('tempail.com'),('tempr.email'),('discard.email'),('spamgourmet.com'),('mailnesia.com'),
 ('burnermail.io'),('mytemp.email'),('tmpmail.org'),('tmail.ws'),('moakt.com'),('emailfake.com'),('inboxkitten.com'),
 ('mail.tm'),('1secmail.com'),('dropmail.me'),('tempmailo.com'),('minuteinbox.com'),('linshiyouxiang.net')
on conflict do nothing;

create or replace function oyun.ozet(x text) returns text language sql stable as $$
  select case when nullif(btrim(x), '') is null then null
              else encode(sha256(convert_to((select iz_tuz from oyun.ayarlar where id = 1) || '|' || btrim(x), 'UTF8')), 'hex') end
$$;

create or replace function oyun.istek_ip() returns text language plpgsql stable as $$
declare h json;
begin
  begin h := nullif(current_setting('request.headers', true), '')::json; exception when others then return null; end;
  return nullif(btrim(split_part(coalesce(h ->> 'cf-connecting-ip', h ->> 'x-real-ip', h ->> 'x-forwarded-for', ''), ',', 1)), '');
end $$;

-- Uygulama her açılışta ve girişte çağırır (profil açılmadan önce de)
create or replace function public.oturum_kaydet(p_cihaz text, p_iz text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben(); t timestamptz := oyun.simdi(); c text := oyun.ozet(left(p_cihaz, 200)); z text := oyun.ozet(left(p_iz, 200)); i text := oyun.ozet(oyun.istek_ip());
begin
  if c is null and z is null then raise exception 'Cihaz bilgisi alınamadı.'; end if;
  insert into oyun.oturumlar(user_id, cihaz, iz, ip, ilk, son) values (u, c, z, i, t, t)
  on conflict (user_id, cihaz, iz, ip) do update set son = excluded.son, sayi = oyun.oturumlar.sayi + 1;
  return jsonb_build_object('tamam', true);
end $$;

-- Bu kullanıcının son kullandığı cihaz özeti
create or replace function oyun.son_cihaz(u uuid) returns text language sql stable as $$
  select cihaz from oyun.oturumlar where user_id = u and cihaz is not null order by son desc limit 1
$$;

-- Aynı cihaz kimliğini paylaşan diğer profiller. (Cihaz izi aynı model telefonlarda çakışabildiği için
-- engel sebebi sayılmaz; yalnızca yönetici panelinde "benzer cihaz" olarak gösterilir.)
create or replace function oyun.bagli_hesaplar(u uuid) returns setof uuid language sql stable as $$
  select distinct o2.user_id from oyun.oturumlar o1
  join oyun.oturumlar o2 on o2.user_id <> o1.user_id and o1.cihaz is not null and o2.cihaz = o1.cihaz
  join oyun.profiller p on p.id = o2.user_id
  where o1.user_id = u
$$;

-- Şüphe: aynı cihazda/izde senden önce açılmış bir hesap varsa (yönetici onaylamadıysa)
create or replace function oyun.suphe(u uuid) returns text language sql stable as $$
  select case when not (select coklu_kontrol from oyun.ayarlar where id = 1) then null
              when exists (select 1 from oyun.hesap_onay where user_id = u) then null
              when exists (select 1 from oyun.bagli_hesaplar(u) b join oyun.profiller x on x.id = b
                           where x.olusturma < (select olusturma from oyun.profiller where id = u))
                then 'Bu cihazda daha önce açılmış başka bir hesap var. Bir insan yalnızca bir vatandaş olabilir; hesabın yönetici incelemesinden geçene kadar oy kullanamaz, aday olamaz ve parti kuramaz. Aynı cihazı aile içinde paylaşıyorsanız yöneticiye bildirin.' end
$$;

-- VATANDAŞLIK ŞARTLARI: oy, adaylık, parti kurma ve kurucu üyelik için ortak kontrol (03'teki uyari'nin yerine geçer)
create or replace function oyun.uyari(p oyun.profiller, ref timestamptz) returns text language sql stable as $$
  select coalesce(
    case when p.olusturma > ref - make_interval(days => a.min_hesap_gun)
         then format('Hesabın en az %s günlük olmalı.', a.min_hesap_gun) end,
    case when a.eposta_zorunlu and not exists (select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null)
         then 'E-posta adresini doğrulamalısın.' end,
    case when a.cihaz_zorunlu and not exists (select 1 from oyun.oturumlar o where o.user_id = p.id)
         then 'Cihaz doğrulaması gerekiyor: uygulamayı güncelleyip yeniden aç.' end,
    oyun.suphe(p.id),
    case when oyun.kidem_puani(p.id) < a.oy_min_kidem
         then format('En az %s kıdem puanın olmalı ("Vatandaş" statüsü; şu an %s). Her gün maaşını toplayarak kıdem kazanırsın.', a.oy_min_kidem, oyun.kidem_puani(p.id)) end)
  from oyun.ayarlar a where a.id = 1
$$;

-- Oy engeli: vatandaşlık şartları + seçmen kütüğü (yerel ve genel seçimde ilde en az N gündür kayıtlı olmak)
create or replace function oyun.oy_engeli(p oyun.profiller, s oyun.secimler) returns text language sql stable as $$
  select coalesce(
    oyun.uyari(p, s.oy_bas),
    case when s.tur in ('mv','bel','mv_on','bel_on') and p.il_at > s.oy_bas - make_interval(days => (select oy_il_gun from oyun.ayarlar where id = 1))
         then format('Seçmen kütüğü: bu ilde oy kullanabilmek için seçimden en az %s gün önce bu ile kayıtlı olmalısın.', (select oy_il_gun from oyun.ayarlar where id = 1)) end,
    case when s.tur in ('mv_on','bel_on','kurultay','cb_on') then
      case when p.parti_id is null then 'Bu parti içi seçimde oy için bir partiye üye olmalısın.'
           when p.parti_at > s.basvuru_bas then 'Parti içi seçimde oy için başvurular açılmadan önce üye olmuş olmalısın.' end
    end)
$$;

-- Aynı cihazdan aynı sandıkta tek oy
create or replace function oyun.oy_cihaz_tg() returns trigger language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare c text; k text;
begin
  if not (select coklu_kontrol from oyun.ayarlar where id = 1) then return new; end if;
  if tg_table_name = 'oylar' then c := oyun.son_cihaz(new.secmen); k := 's' || new.secim_id;
  else c := oyun.son_cihaz(new.secmen); k := 'r' || new.ref_id; end if;
  if c is null then return new; end if;
  insert into oyun.oy_cihaz(anahtar, cihaz) values (k, c) on conflict do nothing;
  if not found then raise exception 'Bu cihazdan bu sandıkta başka bir hesapla oy kullanıldı. Bir cihazdan yalnızca bir oy kullanılabilir.'; end if;
  return new;
end $$;
drop trigger if exists oylar_cihaz on oyun.oylar;
create trigger oylar_cihaz before insert on oyun.oylar for each row execute function oyun.oy_cihaz_tg();
drop trigger if exists ref_cihaz on oyun.referandum_katilim;
create trigger ref_cihaz before insert on oyun.referandum_katilim for each row execute function oyun.oy_cihaz_tg();

-- Profil açarken: tek kullanımlık e-posta engeli ve cihaz başına hesap sınırı
create or replace function oyun.profil_guvenlik_tg() returns trigger language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare v_alan text; n int;
begin
  if not (select coklu_kontrol from oyun.ayarlar where id = 1) then return new; end if;
  v_alan := lower(split_part((select email from auth.users where id = new.id), '@', 2));
  if v_alan <> '' and exists (select 1 from oyun.gecici_eposta g where v_alan = g.alan or v_alan like '%.' || g.alan) then
    raise exception 'Tek kullanımlık e-posta adresleriyle hesap açılamaz. Kalıcı bir e-posta adresi kullan.';
  end if;
  select count(distinct b) into n from oyun.bagli_hesaplar(new.id) b;
  if n >= (select cihaz_max_hesap from oyun.ayarlar where id = 1) then
    raise exception 'Bu cihazda en fazla % oyuncu hesabı açılabilir. Bir insan yalnızca bir vatandaş olabilir.', (select cihaz_max_hesap from oyun.ayarlar where id = 1);
  end if;
  return new;
end $$;
drop trigger if exists profil_guvenlik on oyun.profiller;
create trigger profil_guvenlik before insert on oyun.profiller for each row execute function oyun.profil_guvenlik_tg();

-- ---------------------------------------------------------------------
-- VATANDAŞLIK DURUMU (oyuncunun kendi "seçmen kartı")
-- ---------------------------------------------------------------------
create or replace function public.vatandaslik() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.ayarlar; k numeric := oyun.kidem_puani(p.id);
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
      jsonb_build_object('ad', format('"Vatandaş" statüsü (en az %s kıdem)', a.oy_min_kidem), 'tamam', k >= a.oy_min_kidem, 'not', format('Kıdemin: %s', k)),
      jsonb_build_object('ad', format('Seçmen kütüğü: yerel ve genel seçimde ilinde en az %s gün', a.oy_il_gun), 'tamam', p.il_at <= t - make_interval(days => a.oy_il_gun),
                         'not', case when p.il_at > t - make_interval(days => a.oy_il_gun) then 'Bu ilde oy hakkı: ' || to_char((p.il_at + make_interval(days => a.oy_il_gun)) at time zone 'Europe/Istanbul', 'DD.MM') end)),
    'parti_kurma', jsonb_build_object('kidem', a.parti_kurucu_kidem, 'kurucu', a.parti_kurucu_sayi, 'gun', a.parti_kurulus_gun, 'benim_kidem', k));
end $$;

-- ---------------------------------------------------------------------
-- PARTİ KURULUŞU
-- ---------------------------------------------------------------------
create or replace function oyun.kurucu_say(p_parti bigint, t timestamptz) returns int language sql stable as $$
  select count(*)::int from oyun.profiller p where p.parti_id = p_parti and not p.yasakli and oyun.uyari(p, t) is null
$$;

create or replace function oyun.parti_kurulus_kontrol(p_parti bigint, t timestamptz) returns void language plpgsql as $$
declare pa oyun.partiler; n int; u uuid;
begin
  select * into pa from oyun.partiler where id = p_parti for update;
  if pa.id is null or pa.kurulus_bit is null or pa.kapali then return; end if;
  n := oyun.kurucu_say(pa.id, t);
  if n >= (select parti_kurucu_sayi from oyun.ayarlar where id = 1) then
    update oyun.partiler set kurulus_bit = null where id = pa.id;
    perform oyun.olay('parti', format('%s (%s) %s kurucu üyeyle kuruluşunu tamamladı ve seçimlere katılma hakkı kazandı.', pa.ad, pa.kisa, n), null, pa.id, t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select id, t, format('%s kuruluşunu tamamladı. Artık seçimlere aday çıkarabilir.', pa.ad) from oyun.profiller where parti_id = pa.id;
  elsif t >= pa.kurulus_bit then
    for u in select id from oyun.profiller where parti_id = pa.id loop
      perform oyun.bildir(u, format('%s süresi içinde yeterli kurucu üye toplayamadığı için kurulamadı. Üyeliğin sona erdi.', pa.ad), t);
    end loop;
    update oyun.partiler set gb = null where id = pa.id;
    delete from oyun.parti_gby where parti_id = pa.id;
    update oyun.profiller set parti_id = null, parti_at = null where parti_id = pa.id;
    update oyun.partiler set kapali = true where id = pa.id;
    perform oyun.olay('parti', format('%s (%s) kurucu üye sayısını tamamlayamadığı için kurulamadı.', pa.ad, pa.kisa), null, null, t);
  end if;
end $$;

create or replace function oyun.guvenlik_tick(t timestamptz) returns void language plpgsql as $$
declare pid bigint;
begin
  for pid in select id from oyun.partiler where kurulus_bit is not null and not kapali loop
    perform oyun.parti_kurulus_kontrol(pid, t);
  end loop;
  -- silinen hesapların ve 180 gündür kullanılmayan cihaz kayıtlarının temizliği (saatte bir)
  if extract(minute from t) = 0 then
    delete from oyun.oturumlar o where o.son < t - interval '180 days' or not exists (select 1 from auth.users u where u.id = o.user_id);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- YÖNETİCİ: şüpheli hesap kümeleri, onay, kurallar
-- ---------------------------------------------------------------------
create or replace function public.admin_supheler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    -- Güçlü: aynı cihaz kimliği · Zayıf: aynı cihaz izi (aynı model telefonlarda çakışabilir)
    'cihaz', coalesce((select jsonb_agg(k order by k ->> 'son' desc) from (
        select jsonb_build_object('tur', x.tur, 'son', max(o.son),
          'hesaplar', jsonb_agg(distinct jsonb_build_object('kad', pr.kad, 'olusturma', pr.olusturma, 'yasakli', pr.yasakli,
                         'onayli', exists (select 1 from oyun.hesap_onay h where h.user_id = pr.id),
                         'oy', (select count(*) from oyun.oylar where secmen = pr.id),
                         'engel', oyun.suphe(pr.id) is not null))) k
        from (select 'cihaz' tur, cihaz anahtar from oyun.oturumlar where cihaz is not null group by cihaz having count(distinct user_id) > 1
              union select 'iz', iz from oyun.oturumlar where iz is not null group by iz having count(distinct user_id) > 1) x
        join oyun.oturumlar o on (x.tur = 'cihaz' and o.cihaz = x.anahtar) or (x.tur = 'iz' and o.iz = x.anahtar)
        join oyun.profiller pr on pr.id = o.user_id
        group by x.tur, x.anahtar having count(distinct pr.id) > 1 limit 50) z), '[]'::jsonb),
    -- Zayıf: son 7 günde aynı bağlantı adresinden 3+ hesap (aile/okul/operatör olabilir; tek başına delil değildir)
    'ip', coalesce((select jsonb_agg(jsonb_build_object('sayi', n, 'hesaplar', h) order by n desc) from (
        select count(distinct pr.id) n, jsonb_agg(distinct pr.kad) h from oyun.oturumlar o join oyun.profiller pr on pr.id = o.user_id
        where o.ip is not null and o.son > t - interval '7 days' group by o.ip having count(distinct pr.id) >= 3 limit 30) z), '[]'::jsonb));
end $$;

create or replace function public.admin_hesap_onay(p_kad text, p_onay boolean, p_not text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi();
begin
  if p_onay then
    insert into oyun.hesap_onay(user_id, yonetici, not_, zaman) values (h.id, p.id, oyun.metin_temizle(coalesce(p_not, ''), 300), t)
    on conflict (user_id) do update set yonetici = excluded.yonetici, not_ = excluded.not_, zaman = excluded.zaman;
    perform oyun.bildir(h.id, 'Hesabın yönetici incelemesinden geçti. Artık oy kullanabilir ve aday olabilirsin.', t);
  else
    delete from oyun.hesap_onay where user_id = h.id;
  end if;
  return public.admin_supheler();
end $$;

create or replace function public.admin_kurallar(p jsonb default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare y oyun.profiller := oyun.yonetici_zorunlu(); a oyun.ayarlar;
begin
  if p is not null then
    update oyun.ayarlar set
      min_hesap_gun      = oyun.sinir(coalesce((p ->> 'min_hesap_gun')::int, min_hesap_gun), 0, 30),
      oy_min_kidem       = oyun.sinir(coalesce((p ->> 'oy_min_kidem')::int, oy_min_kidem), 0, 100),
      oy_il_gun          = oyun.sinir(coalesce((p ->> 'oy_il_gun')::int, oy_il_gun), 0, 30),
      cihaz_max_hesap    = oyun.sinir(coalesce((p ->> 'cihaz_max_hesap')::int, cihaz_max_hesap), 1, 5),
      parti_kurucu_sayi  = oyun.sinir(coalesce((p ->> 'parti_kurucu_sayi')::int, parti_kurucu_sayi), 1, 30),
      parti_kurucu_kidem = oyun.sinir(coalesce((p ->> 'parti_kurucu_kidem')::int, parti_kurucu_kidem), 0, 300),
      parti_kurulus_gun  = oyun.sinir(coalesce((p ->> 'parti_kurulus_gun')::int, parti_kurulus_gun), 1, 30)
    where id = 1;
  end if;
  select * into a from oyun.ayarlar where id = 1;
  return jsonb_build_object('min_hesap_gun', a.min_hesap_gun, 'oy_min_kidem', a.oy_min_kidem, 'oy_il_gun', a.oy_il_gun,
    'cihaz_max_hesap', a.cihaz_max_hesap, 'parti_kurucu_sayi', a.parti_kurucu_sayi, 'parti_kurucu_kidem', a.parti_kurucu_kidem,
    'parti_kurulus_gun', a.parti_kurulus_gun);
end $$;
