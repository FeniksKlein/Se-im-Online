-- 27.11.2026 · İL BAŞKANLIĞI MASASI + İL BAŞKANLIĞI SEÇİM DİNAMİĞİ (sürüm 2026.11.27-4)
-- İstek (Ercan): "İl başkanlığı masası kur: yapabileceği şeyler ekle, oradaki oyuncuya yetkiler ver; ille ilgili yönetim
--   kurabilsin, kararlar alabilsin, miting vs yapabilsin, iliyle ilgili açıklamalar olsun; il başkanı olan kendini önemli
--   biri hissetsin. Ayrıca il başkanlığı seçimi dinamiğini ekle: genel başkan isterse kendi atasın, isterse il başkanlığı
--   seçimi olsun, aday olabilsinler; genel başkanlık seçiminden önce olsun seçimler."
--
-- A) YÖNTEM (parti tüzüğü, genel başkan seçer): 'secim' (il kongresi, varsayılan) | 'atama' (genel merkez ataması).
--    * Atama: genel başkan / teşkilattan sorumlu GBY il başkanını atar ve dilediğinde değiştirir ("atanmis" statü);
--      il kongresi yapılmaz. (Uygulamada da merkez yönetimi il başkanını görevlendirir ve işten el çektirir.)
--    * Seçim: il başkanını il kongresi seçer (SPK m.19). Olağan il kongreleri her OLAĞAN KURULTAYDAN ÖNCE, "kongre
--      haftasında" yapılır: kurultay aday başvurusunun başladığı günden 5 gün önce 00.00'da açılır, 3 gün önce 08.00'e
--      kadar aday başvurusu, aynı gün 08.00–22.00 oy. Dönemi dolan (tüzük: il_baskan_donem_gun) seçilmiş başkanın, geçici ya
--      da atanmış başkanın ve başkanı olmayan teşkilatın ilinde kongre açılır. Sonuçlar il olayına (oylarıyla) ve partinin
--      kongre haftası özeti olarak ajansa yazılır; ardından genel başkanlık seçimi (kurultay) gelir.
--    * Yöntem değişikliği: 7 günde bir; kongre haftası sürerken yapılamaz. Atamaya geçince açık il kongreleri iptal olur.
-- B) İL BAŞKANLIĞI MASASI (il başkanı; yetki verdiği il yönetim kurulu üyeleri; genel merkez izler):
--    il örgütü kasası (genel merkez ödeneği, bağış), il mitingi (il kasası ya da kendi cebi), il seçim standı,
--    il başkanlığı açıklaması (Kürsü'de kurum adıyla) ve teşkilat içi duyuru, il yönetim kurulu karar defteri
--    (önerge → 24 saat oylama, yeter sayı, karar no "2026/7"), genel merkeze yazı (rapor, öneri, ödenek talebi, aday
--    önerisi; genel merkez yanıtlar, ödenek talebi kabulde kasadan aktarılır), il karnesi ve parti içi sıralama,
--    yönetim kurulu üyelerine yetki devri.
-- Güvenlik/ölçek: her işlem sunucuda yetki denetimli; il kasasından kişiye para çıkmaz (yalnız etkinlik bedeli ve genel
--   merkeze iade); bildirimler yalnız partinin o ildeki üyelerine; günlük sınırlar; zamanlayıcı limitli ve hata yalıtımlı.
--   Kongrede oy ve adaylık için seçmen kartı (oyun.uyari) ve aynı cihazdan ikinci oy engeli (yalnız bu sürümden sonra
--   açılan kongrelerde: kart_zorunlu).
-- Oyuncu verisi değişmez; yalnız tablo/sütun/işlev eklenir, izin listeleri genişler. Tekrar çalıştırmak güvenlidir.
-- Ekran: gelistirici/www/il_baskanligi_masasi.js

-- =========================================================================================
-- 0) Yardımcılar
-- =========================================================================================
create or replace function oyun.ilm_ad(u uuid)
returns text language sql stable set search_path to '' as $$
  select coalesce(nullif(btrim(p.ad_soyad), ''), p.kad) from oyun.profiller p where p.id = u
$$;

-- =========================================================================================
-- A) YÖNTEM, STATÜ, KONGRE TAKVİMİ
-- =========================================================================================
create table if not exists oyun.il_baskanlik_ayar (
  parti_id bigint primary key references oyun.partiler(id),
  yontem text not null default 'secim' check (yontem in ('secim','atama')),
  degisim timestamptz,
  degistiren uuid
);
alter table oyun.il_baskanlik_ayar enable row level security;

create or replace function oyun.il_yontem(p_parti bigint)
returns text language sql stable set search_path to '' as $$
  select coalesce((select a.yontem from oyun.il_baskanlik_ayar a where a.parti_id = p_parti), 'secim')
$$;

-- statü listesi genişler: atanmış (genel merkez ataması)
alter table oyun.il_baskanlik drop constraint if exists il_baskanlik_statu_check;
alter table oyun.il_baskanlik add constraint il_baskanlik_statu_check check (statu in ('gecici','secilmis','atanmis'));

alter table oyun.il_kongre add column if not exists kurultay_id bigint;
alter table oyun.il_kongre add column if not exists kart_zorunlu boolean not null default false;
create index if not exists il_kongre_kurultay_ix on oyun.il_kongre(kurultay_id, parti_id) where kurultay_id is not null;

-- Sıradaki olağan kurultay (genel başkanlık seçimi): tüm partiler için aylık, ara=false
create or replace function oyun.ilm_siradaki_kurultay(t timestamptz)
returns oyun.secimler language sql stable set search_path to '' as $$
  select s from oyun.secimler s
   where s.tur = 'kurultay' and not coalesce(s.ara, false) and s.durum = 'bekliyor' and s.basvuru_bas > t
   order by s.basvuru_bas limit 1
$$;

-- Kongre haftası: kurultay başvurusundan 5 gün önce 00.00 açılış; 3 gün önce 08.00'e kadar aday; 08.00–22.00 oy (TSİ)
create or replace function oyun.ilm_kongre_takvim(p_kurultay_bas timestamptz, out acilis timestamptz, out aday_bit timestamptz, out oy_bit timestamptz)
language sql stable set search_path to '' as $$
  select ((g.d - 5)::timestamp) at time zone 'Europe/Istanbul',
         ((g.d - 3)::timestamp + interval '8 hours') at time zone 'Europe/Istanbul',
         ((g.d - 3)::timestamp + interval '22 hours') at time zone 'Europe/Istanbul'
    from (select (p_kurultay_bas at time zone 'Europe/Istanbul')::date d) g
$$;

-- İl başkanlığı statü eşitleyicisi: atama yönteminde atanan başkan "atanmis" olur (dönem yok)
create or replace function oyun.il_baskanlik_esitle_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi(); st text := nullif(current_setting('oyun.il_baskan_statu',true),'');
  kid bigint := nullif(current_setting('oyun.il_baskan_kongre',true),'')::bigint;
  neden text := coalesce(nullif(current_setting('oyun.il_baskan_neden',true),''),'gorev_bitti');
begin
  st := coalesce(st, 'gecici');
  if st = 'gecici' and oyun.il_yontem(new.parti_id) = 'atama' then st := 'atanmis'; end if;
  if tg_op='UPDATE' and old.aktif and (not new.aktif or new.user_id is distinct from old.user_id) then
    update oyun.il_baskanlik set aktif=false, bitis=t, bitis_neden=neden
     where parti_id=old.parti_id and il_id=old.il_id and aktif;
    update oyun.il_yonetim_kurulu set aktif=false, cikis=t, cikis_neden='il_baskani_degisti'
     where parti_id=old.parti_id and il_id=old.il_id and aktif and new.user_id is distinct from old.user_id;
  end if;
  if new.aktif and (tg_op='INSERT' or not old.aktif or new.user_id is distinct from old.user_id) then
    update oyun.il_baskanlik set aktif=false, bitis=t, bitis_neden=neden where parti_id=new.parti_id and il_id=new.il_id and aktif;
    insert into oyun.il_baskanlik(parti_id,il_id,user_id,statu,bas,donem_bit,kongre_id,atayan)
    values(new.parti_id,new.il_id,new.user_id,st,t,
      case when st='secilmis' then t + make_interval(days => (oyun.parti_tuzuk(new.parti_id)).il_baskan_donem_gun) end,
      kid,new.atayan);
  end if;
  return new;
end $$;

-- Kongre açar (iç): kart_zorunlu=true (seçmen kartı + cihaz denetimi bu kongrelerde uygulanır)
create or replace function oyun.il_kongre_ac_ic(p_parti bigint, p_il smallint, p_tur text, p_acan uuid)
returns bigint language plpgsql security definer set search_path to '' as $$
declare tz oyun.parti_tuzuk_ayar := oyun.parti_tuzuk(p_parti); t timestamptz := oyun.simdi(); kid bigint; ilad text;
begin
  select id into kid from oyun.il_kongre where parti_id=p_parti and il_id=p_il and durum in ('aday','oy');
  if kid is not null then return kid; end if;
  insert into oyun.il_kongre(parti_id,il_id,tur,acan,acilis,aday_bit,oy_bit,kart_zorunlu)
  values(p_parti,p_il,p_tur,p_acan,t,t+make_interval(hours=>tz.il_kongre_aday_saat),t+make_interval(hours=>tz.il_kongre_aday_saat+tz.il_kongre_oy_saat),true)
  returning id into kid;
  select ad into ilad from oyun.iller where id=p_il;
  perform oyun.bildir(p.id, format('%s %s il kongresi açıldı (%s). Aday başvurusu %s''e kadar; oy verme ardından %s saat.',
      (select kisa from oyun.partiler where id=p_parti), ilad,
      case p_tur when 'ilk' then 'ilk kongre' when 'olagan' then 'olağan' else 'olağanüstü' end,
      to_char((t+make_interval(hours=>tz.il_kongre_aday_saat)) at time zone 'Europe/Istanbul','DD.MM HH24:MI'), tz.il_kongre_oy_saat), t)
   from oyun.profiller p where p.parti_id=p_parti and p.il_id=p_il and not coalesce(p.yasakli,false);
  perform oyun.parti_yetki_log(p_parti,p_acan,'teskilat','kongre_acildi',null,format('il %s, %s, kongre #%s',p_il,p_tur,kid));
  return kid;
end $$;

-- Kongre haftası kongresi (iç): sabit takvimle açılır
create or replace function oyun.il_kongre_ac_takvim(p_parti bigint, p_il smallint, p_tur text, p_kurultay bigint,
  p_acilis timestamptz, p_aday_bit timestamptz, p_oy_bit timestamptz)
returns bigint language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi(); kid bigint; ilad text; pk text;
begin
  select id into kid from oyun.il_kongre where parti_id=p_parti and il_id=p_il and durum in ('aday','oy');
  if kid is not null then return kid; end if;
  insert into oyun.il_kongre(parti_id,il_id,tur,acan,acilis,aday_bit,oy_bit,kurultay_id,kart_zorunlu)
  values(p_parti,p_il,p_tur,null,least(p_acilis,t),p_aday_bit,p_oy_bit,p_kurultay,true)
  returning id into kid;
  select ad into ilad from oyun.iller where id=p_il;
  select kisa into pk from oyun.partiler where id=p_parti;
  perform oyun.bildir(p.id, format('🗳️ Kongre haftası: %s %s %s il kongresi açıldı. İl başkanlığına aday başvurusu %s''e kadar; oy %s, 08.00–22.00. Kongreden sonra genel başkanlık seçimi (kurultay) yapılacak.',
      pk, ilad, case p_tur when 'ilk' then 'ilk' else 'olağan' end,
      to_char(p_aday_bit at time zone 'Europe/Istanbul','DD.MM HH24:MI'),
      to_char(p_aday_bit at time zone 'Europe/Istanbul','DD.MM')), t)
   from oyun.profiller p where p.parti_id=p_parti and p.il_id=p_il and not coalesce(p.yasakli,false);
  perform oyun.parti_yetki_log(p_parti,null,'teskilat','kongre_acildi',null,format('il %s, %s, kongre haftası, kurultay #%s, kongre #%s',p_il,p_tur,p_kurultay,kid));
  return kid;
end $$;

-- Eski "İl Başkanı ata" ucu: atama yönteminde seçilmiş başkan da genel merkezce değiştirilebilir
do $e$
declare s text;
begin
  s := pg_get_functiondef('public.teskilat_gorev_ver(integer,text)'::regprocedure);
  if position('oyun.il_yontem(pa.id)' in s) = 0 then
    s := replace(s, $x$b.il_id=p_il and b.aktif and b.statu='secilmis') then$x$, $x$b.il_id=p_il and b.aktif and b.statu='secilmis') and oyun.il_yontem(pa.id)='secim' then$x$);
    if position('oyun.il_yontem(pa.id)' in s) > 0 then execute s; else raise notice 'teskilat_gorev_ver: yöntem yaması uygulanamadı (metin farklı)'; end if;
  end if;
end $e$;

-- =========================================================================================
-- B) MASA: ROL VE YETKİ YARDIMCILARI
-- =========================================================================================
alter table oyun.il_yonetim_kurulu add column if not exists yetkiler text[] not null default '{}';

-- Kişinin parti/il örgütündeki rolü: baskan | yk | gm (genel merkez: GB / teşkilat GBY) | uye | null
create or replace function oyun.ilm_rol(u uuid, p_parti bigint, p_il smallint)
returns text language sql stable set search_path to '' as $$
  select case
    when exists(select 1 from oyun.parti_teskilat_gorev g join oyun.profiller p on p.id=g.user_id and p.parti_id=g.parti_id and not coalesce(p.yasakli,false)
                 where g.parti_id=p_parti and g.il_id=p_il and g.aktif and g.user_id=u) then 'baskan'
    when exists(select 1 from oyun.il_yonetim_kurulu y join oyun.profiller p on p.id=y.user_id and p.parti_id=y.parti_id and p.il_id=y.il_id and not coalesce(p.yasakli,false)
                 where y.parti_id=p_parti and y.il_id=p_il and y.aktif and y.user_id=u) then 'yk'
    when oyun.teskilat_yonetici(u, p_parti) then 'gm'
    when exists(select 1 from oyun.profiller p where p.id=u and p.parti_id=p_parti) then 'uye'
  end
$$;

-- İl örgütü adına işlem yetkisi: il başkanı her şeyi; yönetim kurulu üyesi yalnız verilen yetkiyle
create or replace function oyun.ilm_yetkili(u uuid, p_parti bigint, p_il smallint, p_yetki text)
returns boolean language sql stable set search_path to '' as $$
  select oyun.ilm_rol(u, p_parti, p_il) = 'baskan'
      or exists(select 1 from oyun.il_yonetim_kurulu y join oyun.profiller p on p.id=y.user_id and p.parti_id=y.parti_id and p.il_id=y.il_id and not coalesce(p.yasakli,false)
                 where y.parti_id=p_parti and y.il_id=p_il and y.aktif and y.user_id=u and p_yetki = any(y.yetkiler))
$$;

-- Kişinin il örgütü (başkanı ya da yönetim kurulu üyesi olduğu il)
create or replace function oyun.ilm_benim_il(u uuid)
returns smallint language sql stable set search_path to '' as $$
  select coalesce(
    (select g.il_id from oyun.parti_teskilat_gorev g join oyun.profiller p on p.id=g.user_id and p.parti_id=g.parti_id where g.user_id=u and g.aktif order by g.atama desc limit 1),
    (select y.il_id from oyun.il_yonetim_kurulu y join oyun.profiller p on p.id=y.user_id and p.parti_id=y.parti_id and p.il_id=y.il_id where y.user_id=u and y.aktif order by y.eklenme desc limit 1))
$$;

-- Genel merkezin mali yetkisi (ödenek / iade / ödenek talebini kabul)
create or replace function oyun.ilm_mali(u uuid, p_parti bigint)
returns boolean language sql stable set search_path to '' as $$
  select oyun.teskilat_yonetici(u, p_parti) or oyun.gby_yetkili(u, p_parti, 'mali')
$$;

-- Karar kurulu: il başkanı + aktif yönetim kurulu üyeleri (partide ve ilde kayıtlı)
create or replace function oyun.ilm_kurul(p_parti bigint, p_il smallint)
returns uuid[] language sql stable set search_path to '' as $$
  select coalesce(array_agg(distinct x.u), '{}') from (
    select g.user_id u from oyun.parti_teskilat_gorev g join oyun.profiller p on p.id=g.user_id and p.parti_id=g.parti_id and not coalesce(p.yasakli,false)
     where g.parti_id=p_parti and g.il_id=p_il and g.aktif
    union all
    select y.user_id from oyun.il_yonetim_kurulu y join oyun.profiller p on p.id=y.user_id and p.parti_id=y.parti_id and p.il_id=y.il_id and not coalesce(p.yasakli,false)
     where y.parti_id=p_parti and y.il_id=p_il and y.aktif) x
$$;

-- Partinin o ildeki üyelerine bildirim (en çok 3000)
create or replace function oyun.ilm_uyelere_bildir(p_parti bigint, p_il smallint, p_metin text, p_haric uuid, t timestamptz)
returns integer language plpgsql security definer set search_path to '' as $$
declare n int;
begin
  insert into oyun.bildirimler(user_id, zaman, metin)
  select p.id, t, left(p_metin, 600) from oyun.profiller p
   where p.parti_id=p_parti and p.il_id=p_il and not coalesce(p.yasakli,false) and p.id is distinct from p_haric
   limit 3000;
  get diagnostics n = row_count;
  return n;
end $$;

-- Genel merkeze (GB + teşkilat GBY, istenirse mali GBY) bildirim
create or replace function oyun.ilm_gm_bildir(p_parti bigint, p_metin text, p_mali boolean, t timestamptz)
returns void language sql security definer set search_path to '' as $$
  insert into oyun.bildirimler(user_id, zaman, metin)
  select distinct x, t, left(p_metin, 600) from (
    select pa.gb x from oyun.partiler pa where pa.id=p_parti and pa.gb is not null
    union all
    select y.user_id from oyun.parti_gby_yetki y where y.parti_id=p_parti and y.aktif and (y.yetki='teskilat' or (p_mali and y.yetki='mali'))) s
  where x is not null
$$;

-- =========================================================================================
-- C) İL ÖRGÜTÜ KASASI
-- =========================================================================================
create table if not exists oyun.il_kasa (
  parti_id bigint not null references oyun.partiler(id),
  il_id smallint not null,
  bakiye numeric not null default 0,
  guncelleme timestamptz,
  primary key (parti_id, il_id),
  constraint il_kasa_eksi_yok check (bakiye >= 0),
  constraint il_kasa_sonlu check (bakiye < 'Infinity'::numeric)
);
alter table oyun.il_kasa enable row level security;
create table if not exists oyun.il_kasa_hareket (
  id bigserial primary key,
  parti_id bigint not null,
  il_id smallint not null,
  zaman timestamptz not null,
  tutar numeric not null,
  tur text not null,
  aciklama text,
  user_id uuid
);
create index if not exists il_kasa_hareket_ix on oyun.il_kasa_hareket(parti_id, il_id, id desc);
alter table oyun.il_kasa_hareket enable row level security;

create or replace function oyun.il_kasa_islem(p_parti bigint, p_il smallint, p_tutar numeric, p_tur text, p_aciklama text, p_user uuid, t timestamptz)
returns numeric language plpgsql security definer set search_path to '' as $$
declare b numeric; v numeric := round(p_tutar);
begin
  if p_tutar is null or p_tutar = 'NaN'::numeric or abs(p_tutar) = 'Infinity'::numeric or v = 0 then raise exception 'Geçersiz tutar.'; end if;
  insert into oyun.il_kasa(parti_id, il_id, bakiye, guncelleme) values (p_parti, p_il, 0, t) on conflict do nothing;
  update oyun.il_kasa set bakiye = bakiye + v, guncelleme = t where parti_id = p_parti and il_id = p_il and bakiye + v >= 0
  returning bakiye into b;
  if b is null then
    raise exception 'İl örgütü kasasında yeterli para yok (% ₺ gerekli, kasada % ₺ var).', oyun.tl(abs(v)),
      oyun.tl(coalesce((select bakiye from oyun.il_kasa where parti_id = p_parti and il_id = p_il), 0));
  end if;
  insert into oyun.il_kasa_hareket(parti_id, il_id, zaman, tutar, tur, aciklama, user_id) values (p_parti, p_il, t, v, p_tur, left(p_aciklama, 200), p_user);
  return b;
end $$;

-- Ödenek (iç): parti kasası → il kasası
create or replace function oyun.il_odenek_ic(p_parti bigint, p_il smallint, p_tutar numeric, p_user uuid, p_not text, t timestamptz)
returns void language plpgsql security definer set search_path to '' as $$
declare pa oyun.partiler; ilad text; v numeric := round(p_tutar); bsk uuid;
begin
  select * into pa from oyun.partiler where id = p_parti and not kapali for update;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if v is null or v < 1000 or v > 50000000 then raise exception 'Ödenek 1.000 ₺ ile 50.000.000 ₺ arasında olmalı.'; end if;
  if not exists (select 1 from oyun.parti_teskilat where parti_id = p_parti and il_id = p_il) then raise exception 'Bu ilde parti teşkilatı yok.'; end if;
  if pa.kasa < v then raise exception 'Parti kasasında yeterli para yok (% ₺ gerekli, kasada % ₺ var).', oyun.tl(v), oyun.tl(pa.kasa); end if;
  select ad into ilad from oyun.iller where id = p_il;
  update oyun.partiler set kasa = kasa - v where id = p_parti;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (p_parti, t, -v, format('%s il örgütüne ödenek · %s', ilad, oyun.ilm_ad(p_user)), 'il_odenek');
  perform oyun.il_kasa_islem(p_parti, p_il, v, 'odenek', coalesce(p_not, 'Genel merkez ödeneği') || ' · ' || oyun.ilm_ad(p_user), p_user, t);
  perform oyun.parti_yetki_log(p_parti, p_user, 'mali', 'il_odenek', v, ilad);
  bsk := oyun.il_baskani(p_parti, p_il);
  if bsk is not null and bsk <> p_user then
    perform oyun.bildir(bsk, format('💰 Genel merkez %s il örgütü kasasına %s ₺ ödenek gönderdi. İl Başkanlığı Masası › Kasa.', ilad, oyun.tl(v)), t);
  end if;
end $$;

create or replace function public.il_kasa_odenek(p_il integer, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if p.parti_id is null or not oyun.ilm_mali(p.id, p.parti_id) then
    raise exception 'İl örgütüne ödeneği genel başkan ya da teşkilattan / mali işlerden sorumlu genel başkan yardımcısı gönderir.'; end if;
  perform oyun.il_odenek_ic(p.parti_id, p_il::smallint, p_tutar, p.id, null, t);
  return public.il_masa(p.parti_id, p_il);
end $$;

create or replace function public.il_kasa_iade(p_il integer, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; v numeric := round(p_tutar); ilad text;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null or not oyun.ilm_mali(p.id, pa.id) then
    raise exception 'İl kasasından genel merkeze aktarımı genel başkan ya da teşkilattan / mali işlerden sorumlu genel başkan yardımcısı yapar.'; end if;
  if v is null or v < 100 then raise exception 'Geçersiz tutar.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.il_kasa_islem(pa.id, p_il::smallint, -v, 'iade', 'Genel merkeze aktarım · ' || oyun.ilm_ad(p.id), p.id, t);
  update oyun.partiler set kasa = kasa + v where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, v, format('%s il örgütü kasasından aktarım · %s', ilad, oyun.ilm_ad(p.id)), 'il_odenek');
  perform oyun.parti_yetki_log(pa.id, p.id, 'mali', 'il_kasa_iade', v, ilad);
  return public.il_masa(pa.id, p_il);
end $$;

create or replace function public.il_kasa_bagis(p_parti bigint, p_il integer, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; v numeric := round(p_tutar); e text; ilad text; bsk uuid;
begin
  if coalesce(p.yasakli, false) then raise exception 'Hesabın kısıtlı.'; end if;
  e := oyun.uyari(p, t); if e is not null then raise exception 'Bağış için seçmen kartın hazır olmalı: %', e; end if;
  select * into pa from oyun.partiler where id = p_parti and not kapali;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if not exists (select 1 from oyun.parti_teskilat where parti_id = pa.id and il_id = p_il) then raise exception 'Partinin bu ilde teşkilatı yok.'; end if;
  if v is null or v < 100 or v > 10000000 then raise exception 'Bağış 100 ₺ ile 10.000.000 ₺ arasında olmalı.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.para_islem(p.id, -v, 'bagis', format('%s %s il örgütüne bağış', pa.kisa, ilad), t);
  perform oyun.il_kasa_islem(pa.id, p_il::smallint, v, 'bagis', 'Bağış · ' || oyun.ilm_ad(p.id), p.id, t);
  bsk := oyun.il_baskani(pa.id, p_il::smallint);
  if bsk is not null and bsk <> p.id and v >= 1000 then
    perform oyun.bildir(bsk, format('💝 %s, %s il örgütü kasasına %s ₺ bağış yaptı.', oyun.ilm_ad(p.id), ilad, oyun.tl(v)), t);
  end if;
  return jsonb_build_object('tamam', true, 'tutar', v, 'il', ilad, 'parti', pa.kisa);
end $$;

-- =========================================================================================
-- D) İL MİTİNGİ (mevcut miting altyapısı: oyun.mitingler tur='parti', il_orgut=true)
-- =========================================================================================
alter table oyun.mitingler add column if not exists il_orgut boolean not null default false;
alter table oyun.mitingler drop constraint if exists mitingler_odeyen_chk;
alter table oyun.mitingler add constraint mitingler_odeyen_chk check (odeyen = any (array['kisi'::text, 'parti'::text, 'il'::text]));

-- Genel merkez önceliği: il örgütünün mitingi genel başkanın / GBY'nin aynı ildeki mitingini 3 gün kuralıyla engellemez
do $e$
declare s text;
begin
  s := pg_get_functiondef('public.parti_miting_duzenle(integer,timestamp with time zone,text,boolean)'::regprocedure);
  if position('not coalesce(m.il_orgut' in s) = 0 then
    s := replace(s, $x$where m.parti_id = pa.id and m.tur = 'parti' and m.il_id = p_il$x$, $x$where m.parti_id = pa.id and m.tur = 'parti' and m.il_id = p_il and not coalesce(m.il_orgut, false)$x$);
    if position('not coalesce(m.il_orgut' in s) > 0 then execute s; else raise notice 'parti_miting_duzenle: il örgütü yaması uygulanamadı'; end if;
  end if;
end $e$;

-- Yetkisi kalmayan düzenleyicinin ileri tarihli mitingini iptal eder (il örgütü mitingi il yetkisine bakar)
create or replace function oyun.parti_miting_temizle(t timestamptz)
returns void language plpgsql set search_path to '' as $$
declare r record;
begin
  for r in select m.id, m.user_id, m.parti_id, m.il_id, coalesce(m.il_orgut, false) io from oyun.mitingler m
           where m.tur = 'parti' and m.bas > t loop
    if (select parti_id from oyun.profiller where id = r.user_id) is distinct from r.parti_id then
      perform oyun.parti_miting_iptal(r.id, 'parti adına miting yetkin kalmadı', t);
    elsif r.io then
      if not oyun.ilm_yetkili(r.user_id, r.parti_id, r.il_id, 'etkinlik') then
        perform oyun.parti_miting_iptal(r.id, 'il örgütü adına miting yetkin kalmadı', t);
      end if;
    elsif oyun.parti_miting_yetki(r.user_id) is null then
      perform oyun.parti_miting_iptal(r.id, 'parti adına miting yetkin kalmadı', t);
    end if;
  end loop;
end $$;

-- İptal: bedel ödeyen kaynağa iade (il kasası dahil)
create or replace function oyun.parti_miting_iptal(p_id bigint, p_neden text, t timestamptz)
returns void language plpgsql set search_path to '' as $$
declare m oyun.mitingler; ilad text;
begin
  delete from oyun.mitingler where id = p_id and tur = 'parti' and bas > t returning * into m;
  if m.id is null then return; end if;
  select ad into ilad from oyun.iller where id = m.il_id;
  if m.bedel > 0 then
    if m.odeyen = 'il' and exists (select 1 from oyun.partiler where id = m.parti_id) then
      perform oyun.il_kasa_islem(m.parti_id, m.il_id, m.bedel, 'miting', format('%s mitingi iptal edildi, bedel iade', ilad), m.user_id, t);
    elsif m.odeyen = 'parti' and exists (select 1 from oyun.partiler where id = m.parti_id) then
      update oyun.partiler set kasa = kasa + m.bedel where id = m.parti_id;
      insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
        values (m.parti_id, t, m.bedel, format('%s mitingi iptal edildi, bedel iade', ilad), 'miting');
    else
      perform oyun.para_islem(m.user_id, m.bedel, 'miting', format('%s mitingi iptal edildi, bedel iade', ilad), t);
    end if;
  end if;
  perform oyun.bildir(m.user_id, format('%s mitingin iptal edildi: %s. Bedeli iade edildi.', ilad, p_neden), t);
end $$;

create or replace function public.il_miting_duzenle(p_bas timestamptz, p_baslik text, p_kaynak text default 'il')
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; il smallint; ilad text; b text;
  bedel numeric; yasak text; mid bigint; gun date; kaynak text := coalesce(nullif(btrim(p_kaynak), ''), 'il'); rol text;
begin
  if p.parti_id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  il := oyun.ilm_benim_il(p.id);
  if il is null or not oyun.ilm_yetkili(p.id, p.parti_id, il, 'etkinlik') then
    raise exception 'İl örgütü adına mitingi il başkanı ya da etkinlik yetkisi verilmiş il yönetim kurulu üyesi düzenler.'; end if;
  if kaynak not in ('il', 'kendi') then raise exception 'Ödeme kaynağı il kasası ya da kendi cüzdanın olmalı.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if not exists (select 1 from oyun.parti_teskilat where parti_id = pa.id and il_id = il) then raise exception 'Bu ilde parti teşkilatı açılmadan miting yapılamaz.'; end if;
  select ad into ilad from oyun.iller where id = il;
  if p_bas is null or p_bas < t + interval '15 minutes' then raise exception 'Mitingi en erken 15 dakika sonrasına koyabilirsin.'; end if;
  if p_bas > t + interval '3 days' then raise exception 'Mitingi en fazla 3 gün sonrasına planlayabilirsin.'; end if;
  yasak := oyun.miting_secim_yasagi(p_bas, p_bas + interval '1 hour');
  if yasak is not null then raise exception 'Seçim yasağı: % oy verme saatlerinde miting yapılamaz. Başka bir saat seç.', yasak; end if;
  b := oyun.metin_temizle(p_baslik, 80);
  if length(b) < 3 then raise exception 'Miting başlığı en az 3 karakter olmalı.'; end if;
  gun := (p_bas at time zone 'Europe/Istanbul')::date;
  if exists (select 1 from oyun.mitingler m where m.user_id = p.id and m.tur = 'parti' and (m.bas at time zone 'Europe/Istanbul')::date = gun) then
    raise exception 'Aynı gün için zaten bir parti mitingi düzenledin. Günde en fazla 1 parti mitingi yapılabilir.'; end if;
  if exists (select 1 from oyun.mitingler m where m.parti_id = pa.id and m.tur = 'parti' and m.il_id = il
             and m.bas > p_bas - interval '3 days' and m.bas < p_bas + interval '3 days') then
    raise exception 'Partin % ilinde 3 gün içinde zaten miting yapıyor ya da yaptı. Aynı ilde iki parti mitingi arasında en az 3 gün olmalı.', ilad; end if;
  if exists (select 1 from oyun.mitingler m where m.il_id = il and m.bas < p_bas + interval '1 hour' and m.bit > p_bas) then
    raise exception 'Bu saatte % meydanında başka bir miting var. Başka bir saat seç.', ilad; end if;
  bedel := oyun.miting_bedel(il);
  if kaynak = 'il' then
    perform oyun.il_kasa_islem(pa.id, il, -bedel, 'miting', format('%s il mitingi (sahne, ses, ulaşım) · %s', ilad, oyun.ilm_ad(p.id)), p.id, t);
  else
    perform oyun.para_islem(p.id, -bedel, 'miting', format('%s il örgütü mitingi (sahne, ses, ulaşım)', ilad), t);
  end if;
  insert into oyun.mitingler(user_id, secim_id, il_id, parti_id, baslik, bas, bit, bedel, tur, odeyen, il_orgut)
    values (p.id, null, il, pa.id, b, p_bas, p_bas + interval '1 hour', bedel, 'parti', case when kaynak = 'il' then 'il' else 'kisi' end, true)
    returning id into mid;
  rol := case when oyun.ilm_rol(p.id, pa.id, il) = 'baskan' then 'İl Başkanı' else 'İl Yönetim Kurulu Üyesi' end;
  perform oyun.olay('parti', format('%s %s İl Başkanlığı mitingi: %s %s, “%s” (%s).', pa.kisa, ilad, rol, oyun.ilm_ad(p.id), b,
      to_char(p_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), il, pa.id, t);
  perform oyun.ilm_uyelere_bildir(pa.id, il, format('📣 %s %s İl Başkanlığı %s''de miting düzenliyor: “%s”. Meydanda buluşalım!',
      pa.kisa, ilad, to_char(p_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'), b), p.id, t);
  perform oyun.kidem_ekle(p.id, 'il_gorev');
  return jsonb_build_object('id', mid, 'bedel', bedel, 'il', ilad, 'odeyen', case when kaynak = 'il' then 'il' else 'kisi' end);
end $$;

create or replace function public.il_miting_iptal(p_miting bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.mitingler;
begin
  select * into m from oyun.mitingler where id = p_miting and tur = 'parti' and coalesce(il_orgut, false);
  if m.id is null then raise exception 'İl örgütü mitingi bulunamadı.'; end if;
  if m.bas <= t then raise exception 'Başlamış ya da bitmiş miting iptal edilemez.'; end if;
  if not (m.user_id = p.id or oyun.ilm_rol(p.id, m.parti_id, m.il_id) = 'baskan'
          or (p.parti_id = m.parti_id and oyun.teskilat_yonetici(p.id, m.parti_id))) then
    raise exception 'İl mitingini düzenleyen, il başkanı ya da genel merkez iptal edebilir.'; end if;
  perform oyun.parti_miting_iptal(m.id, format('%s tarafından iptal edildi', oyun.ilm_ad(p.id)), t);
  return public.il_masa(m.parti_id, m.il_id);
end $$;

-- =========================================================================================
-- E) İL SEÇİM STANDI (mevcut stant altyapısı; parti günde ilde 1 stant)
-- =========================================================================================
create or replace function public.il_stant_ac(p_baslik text, p_kaynak text default 'il')
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; il smallint; ilad text; b text;
  bedel numeric; s oyun.stant; kaynak text := coalesce(nullif(btrim(p_kaynak), ''), 'il');
begin
  if p.parti_id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  il := oyun.ilm_benim_il(p.id);
  if il is null or not oyun.ilm_yetkili(p.id, p.parti_id, il, 'etkinlik') then
    raise exception 'İl örgütü adına standı il başkanı ya da etkinlik yetkisi verilmiş il yönetim kurulu üyesi açar.'; end if;
  if kaynak not in ('il', 'kendi') then raise exception 'Ödeme kaynağı il kasası ya da kendi cüzdanın olmalı.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if not exists (select 1 from oyun.parti_teskilat where parti_id = pa.id and il_id = il) then raise exception 'Bu ilde partinin teşkilatı yok; önce il teşkilatı aç.'; end if;
  if exists (select 1 from oyun.stant where parti_id = pa.id and il_id = il and oyun.sm_gun(bas) = oyun.sm_gun(t)) then
    raise exception 'Partin bugün bu ilde zaten stant açtı.'; end if;
  b := oyun.metin_temizle(p_baslik, 80);
  if length(b) < 3 then raise exception 'Stant başlığı en az 3 karakter olmalı.'; end if;
  bedel := coalesce((select stant_bedel from oyun.ayarlar where id = 1), 2000);
  select ad into ilad from oyun.iller where id = il;
  if kaynak = 'il' then
    perform oyun.il_kasa_islem(pa.id, il, -bedel, 'stant', format('%s seçim standı · %s', ilad, oyun.ilm_ad(p.id)), p.id, t);
  else
    perform oyun.para_islem(p.id, -bedel, 'stant', format('%s il örgütü seçim standı', ilad), t);
  end if;
  insert into oyun.stant(parti_id, il_id, acan, baslik, bas, bit, bedel) values (pa.id, il, p.id, b, t, t + interval '3 hours', bedel) returning * into s;
  perform oyun.ilm_uyelere_bildir(pa.id, il, format('⛺ %s %s İl Başkanlığı parti standı açtı: “%s”. 3 saat boyunca gönüllü olarak standa katılabilirsin.', pa.kisa, ilad, b), p.id, t);
  perform oyun.olay('parti', format('%s %s İl Başkanlığı seçim standı açtı: “%s”', pa.kisa, ilad, b), il, pa.id, t);
  perform oyun.kidem_ekle(p.id, 'il_gorev');
  return oyun.stant_json(s, p.id, t);
end $$;

-- =========================================================================================
-- F) İL BAŞKANLIĞI AÇIKLAMASI (kamu: Kürsü + il olayı) ve TEŞKİLAT İÇİ DUYURU (bildirim)
-- =========================================================================================
create table if not exists oyun.il_aciklama (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  il_id smallint not null,
  yazar uuid not null references oyun.profiller(id),
  rol text not null,
  baslik text not null,
  metin text not null,
  kamu boolean not null default true,
  akis_id bigint,
  zaman timestamptz not null default now(),
  silindi boolean not null default false,
  silen uuid,
  silme_zaman timestamptz
);
create index if not exists il_aciklama_il_ix on oyun.il_aciklama(parti_id, il_id, id desc);
alter table oyun.il_aciklama enable row level security;
drop trigger if exists bolucu_metin on oyun.il_aciklama;
create trigger bolucu_metin before insert or update on oyun.il_aciklama for each row execute function oyun.bolucu_metin_trg('baslik', 'metin');
drop trigger if exists gozalti_yazi_engel on oyun.il_aciklama;
create trigger gozalti_yazi_engel before insert on oyun.il_aciklama for each row execute function oyun.gozalti_yazi_engel_trg('yazar');
drop trigger if exists trg_kurum_durdurma on oyun.il_aciklama;
create trigger trg_kurum_durdurma before insert on oyun.il_aciklama for each row execute function oyun.tg_kurum_durdurma('parti', 'parti_id');

create or replace function public.il_aciklama_yap(p_baslik text, p_metin text, p_kamu boolean default true)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; il smallint; ilad text; b text; m text;
  v_kamu boolean := coalesce(p_kamu, true); v_rol text; n int; aid bigint; yid bigint; gun date := (t at time zone 'Europe/Istanbul')::date;
begin
  if p.parti_id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  il := oyun.ilm_benim_il(p.id);
  if il is null or not oyun.ilm_yetkili(p.id, p.parti_id, il, 'aciklama') then
    raise exception 'İl başkanlığı adına açıklamayı il başkanı ya da açıklama yetkisi verilmiş il yönetim kurulu üyesi yapar.'; end if;
  if coalesce(p.susturma_bitis, '-infinity'::timestamptz) > t or coalesce(p.adliye_susturma_bitis, '-infinity'::timestamptz) > t then
    raise exception 'Susturma cezan sürerken açıklama yapamazsın.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id and not kapali;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  b := oyun.metin_temizle(p_baslik, 120);
  m := oyun.metin_temizle(p_metin, 3000);
  if char_length(b) < 3 then raise exception 'Başlık en az 3 karakter olmalı.'; end if;
  if char_length(m) < 10 then raise exception 'Metin en az 10 karakter olmalı.'; end if;
  if (b || ' ' || m) ~* '(https?://|www\.|t\.me/)' then raise exception 'Açıklamalarda bağlantı kullanılamaz.'; end if;
  perform pg_advisory_xact_lock(hashtext('il_aciklama:' || pa.id || ':' || il));
  if exists (select 1 from oyun.il_aciklama a where a.parti_id = pa.id and a.il_id = il and not a.silindi and a.zaman > t - interval '20 minutes') then
    raise exception 'İl başkanlığı adına yeni açıklama ya da duyuru için 20 dakika bekleyin.'; end if;
  select count(*) into n from oyun.il_aciklama a where a.parti_id = pa.id and a.il_id = il and a.kamu = v_kamu and (a.zaman at time zone 'Europe/Istanbul')::date = gun;
  if v_kamu and n >= 6 then raise exception 'İl başkanlığı günde en çok 6 kamuya açık açıklama yapabilir.'; end if;
  if not v_kamu and n >= 3 then raise exception 'Teşkilat içi duyuru günde en çok 3 kez yapılabilir.'; end if;
  select ad into ilad from oyun.iller where id = il;
  v_rol := case when oyun.ilm_rol(p.id, pa.id, il) = 'baskan' then 'baskan' else 'yk' end;
  insert into oyun.il_aciklama(parti_id, il_id, yazar, rol, baslik, metin, kamu, zaman) values (pa.id, il, p.id, v_rol, b, m, v_kamu, t) returning id into yid;
  if v_kamu then
    insert into oyun.akis(user_id, metin, zaman, il_id, parti_id, kurum_tur, kurum_id, kurum_ad, kurum_rol)
    values (p.id, left('📢 ' || pa.kisa || ' ' || ilad || ' İl Başkanlığı açıklaması — ' || b || ': ' || m, 1000), t, il, pa.id,
            'parti', pa.id::text, left(pa.ad || ' ' || ilad || ' İl Başkanlığı', 120), case v_rol when 'baskan' then 'İl Başkanı' else 'İl Yönetim Kurulu' end)
    returning id into aid;
    update oyun.il_aciklama set akis_id = aid where id = yid;
    perform oyun.olay('parti', format('%s %s İl Başkanlığı açıklama yaptı: “%s”', pa.kisa, ilad, b), il, pa.id, t);
  else
    perform oyun.ilm_uyelere_bildir(pa.id, il, format('📌 %s %s İl Başkanlığı duyurusu — %s: %s', pa.kisa, ilad, b, left(m, 220)), p.id, t);
  end if;
  perform oyun.kidem_ekle(p.id, 'il_gorev');
  return public.il_masa(pa.id, il);
end $$;

create or replace function public.il_aciklamalari(p_parti bigint, p_il integer, p_once bigint default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); ic boolean;
begin
  ic := exists (select 1 from oyun.profiller p where p.id = u and p.parti_id = p_parti and (p.il_id = p_il or coalesce(p.yonetici, false)))
        or oyun.teskilat_yonetici(u, p_parti) or exists (select 1 from oyun.profiller p where p.id = u and coalesce(p.yonetici, false));
  return coalesce((select jsonb_agg(x order by (x->>'id')::bigint desc) from (
    select jsonb_build_object('id', a.id, 'baslik', a.baslik, 'metin', a.metin, 'kamu', a.kamu, 'zaman', a.zaman,
             'kad', oyun.kad(a.yazar), 'ad', oyun.ilm_ad(a.yazar), 'rol', a.rol,
             'silebilir', a.yazar = u or oyun.ilm_rol(u, a.parti_id, a.il_id) = 'baskan' or oyun.teskilat_yonetici(u, a.parti_id)) x
      from oyun.il_aciklama a
     where a.parti_id = p_parti and a.il_id = p_il and not a.silindi and (a.kamu or ic) and (p_once is null or a.id < p_once)
     order by a.id desc limit 20) s), '[]'::jsonb);
end $$;

create or replace function public.il_aciklama_sil(p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.il_aciklama; v_mod boolean := false;
begin
  select * into a from oyun.il_aciklama where id = p_id for update;
  if a.id is null or a.silindi then raise exception 'Açıklama bulunamadı.'; end if;
  if not (a.yazar = p.id or oyun.ilm_rol(p.id, a.parti_id, a.il_id) = 'baskan' or (p.parti_id = a.parti_id and oyun.teskilat_yonetici(p.id, a.parti_id))) then
    perform oyun.yetki_zorunlu('sikayet'); v_mod := true;
  end if;
  update oyun.il_aciklama set silindi = true, silen = p.id, silme_zaman = t where id = a.id;
  if a.akis_id is not null then update oyun.akis set gizli = true where id = a.akis_id; end if;
  if v_mod then perform oyun.mod_log(p, 'il_aciklama_kaldir', oyun.kad(a.yazar), a.baslik); end if;
  return jsonb_build_object('tamam', true);
end $$;

-- =========================================================================================
-- G) İL YÖNETİM KURULU KARAR DEFTERİ
-- =========================================================================================
create table if not exists oyun.il_karar (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  il_id smallint not null,
  yil smallint not null,
  no integer not null,
  tur text not null check (tur in ('genel','oneri')),
  baslik text not null,
  metin text not null,
  oneren uuid not null references oyun.profiller(id),
  durum text not null default 'oylama' check (durum in ('oylama','kabul','ret','dustu','iptal')),
  kurul integer not null default 1,
  olur boolean not null default false,
  acilis timestamptz not null,
  bitis timestamptz not null,
  kapanis timestamptz,
  kabul integer not null default 0,
  ret integer not null default 0,
  cekimser integer not null default 0,
  yazi_id bigint,
  unique (parti_id, il_id, yil, no)
);
create index if not exists il_karar_acik_ix on oyun.il_karar(bitis) where durum = 'oylama';
create index if not exists il_karar_il_ix on oyun.il_karar(parti_id, il_id, id desc);
alter table oyun.il_karar enable row level security;
drop trigger if exists bolucu_metin on oyun.il_karar;
create trigger bolucu_metin before insert or update on oyun.il_karar for each row execute function oyun.bolucu_metin_trg('baslik', 'metin');

create table if not exists oyun.il_karar_oy (
  karar_id bigint not null references oyun.il_karar(id),
  user_id uuid not null references oyun.profiller(id),
  oy text not null check (oy in ('kabul','ret','cekimser')),
  zaman timestamptz not null,
  primary key (karar_id, user_id)
);
alter table oyun.il_karar_oy enable row level security;

-- =========================================================================================
-- H) GENEL MERKEZE YAZI
-- =========================================================================================
create table if not exists oyun.il_gm_yazi (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  il_id smallint not null,
  gonderen uuid not null references oyun.profiller(id),
  tur text not null check (tur in ('rapor','oneri','talep','aday','karar')),
  baslik text not null,
  metin text not null,
  tutar numeric,
  ilgili uuid,
  karar_id bigint,
  zaman timestamptz not null,
  durum text not null default 'bekliyor' check (durum in ('bekliyor','goruldu','kabul','ret')),
  cevap text,
  cevaplayan uuid,
  cevap_zaman timestamptz
);
create index if not exists il_gm_yazi_parti_ix on oyun.il_gm_yazi(parti_id, durum, id desc);
create index if not exists il_gm_yazi_il_ix on oyun.il_gm_yazi(parti_id, il_id, id desc);
alter table oyun.il_gm_yazi enable row level security;
drop trigger if exists bolucu_metin on oyun.il_gm_yazi;
create trigger bolucu_metin before insert or update on oyun.il_gm_yazi for each row execute function oyun.bolucu_metin_trg('baslik', 'metin', 'cevap');

-- Kabul edilen karar: genel → il olayı; öneri → genel merkeze yazı
create or replace function oyun.il_karar_sonuc(p_id bigint)
returns void language plpgsql security definer set search_path to '' as $$
declare k oyun.il_karar; pa oyun.partiler; ilad text; yid bigint; t timestamptz := oyun.simdi();
begin
  select * into k from oyun.il_karar where id = p_id;
  if k.id is null or k.durum <> 'kabul' then return; end if;
  select * into pa from oyun.partiler where id = k.parti_id;
  select ad into ilad from oyun.iller where id = k.il_id;
  if k.tur = 'genel' then
    perform oyun.olay('parti', format('%s %s İl Yönetim Kurulu %s/%s sayılı karar: “%s”', pa.kisa, ilad, k.yil, k.no, k.baslik), k.il_id, k.parti_id, t);
  elsif k.yazi_id is null then
    insert into oyun.il_gm_yazi(parti_id, il_id, gonderen, tur, baslik, metin, karar_id, zaman)
    values (k.parti_id, k.il_id, k.oneren, 'karar', left(k.baslik, 120), left(format('%s İl Yönetim Kurulu %s/%s sayılı kararıyla genel merkeze öneri:%s%s', ilad, k.yil, k.no, E'\n', k.metin), 3000), k.id, t)
    returning id into yid;
    update oyun.il_karar set yazi_id = yid where id = k.id;
    perform oyun.ilm_gm_bildir(k.parti_id, format('📨 %s İl Yönetim Kurulu kararıyla genel merkeze öneri: “%s”. İl Başkanlıkları › Gelen yazılar.', ilad, left(k.baslik, 100)), false, t);
  end if;
end $$;

create or replace function oyun.il_karar_kapat(p_id bigint)
returns void language plpgsql security definer set search_path to '' as $$
declare k oyun.il_karar; t timestamptz := oyun.simdi(); a int; r int; c int; d text; yeter int; ilad text; v_kurul uuid[];
begin
  select * into k from oyun.il_karar where id = p_id for update;
  if k.id is null or k.durum <> 'oylama' then return; end if;
  select count(*) filter (where oy = 'kabul'), count(*) filter (where oy = 'ret'), count(*) filter (where oy = 'cekimser')
    into a, r, c from oyun.il_karar_oy where karar_id = k.id;
  yeter := k.kurul / 2 + 1;
  d := case when a + r + c < yeter then 'dustu' when a > r then 'kabul' else 'ret' end;
  update oyun.il_karar set durum = d, kabul = a, ret = r, cekimser = c, kapanis = t where id = k.id;
  select ad into ilad from oyun.iller where id = k.il_id;
  v_kurul := oyun.ilm_kurul(k.parti_id, k.il_id);
  perform oyun.pdk_toplu_bildir(v_kurul, format('📒 %s İl Yönetim Kurulu %s/%s sayılı önerge “%s”: %s (kabul %s, ret %s, çekimser %s).', ilad, k.yil, k.no, left(k.baslik, 80),
      case d when 'kabul' then 'KABUL EDİLDİ' when 'ret' then 'reddedildi' else 'toplantı yeter sayısı sağlanamadığı için düştü' end, a, r, c), t);
  if d = 'kabul' then perform oyun.il_karar_sonuc(k.id); end if;
end $$;

create or replace function public.il_karar_oner(p_tur text, p_baslik text, p_metin text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; il smallint; ilad text; b text; m text;
  v_kurul uuid[]; n int; v_yil smallint := extract(year from (t at time zone 'Europe/Istanbul'))::smallint; v_no int; kid bigint; v_tur text := coalesce(p_tur, 'genel');
begin
  if p.parti_id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  il := oyun.ilm_benim_il(p.id);
  if il is null or oyun.ilm_rol(p.id, p.parti_id, il) is distinct from 'baskan' then raise exception 'Karar önergesini il başkanı yönetim kuruluna getirir.'; end if;
  if v_tur not in ('genel', 'oneri') then raise exception 'Geçersiz karar türü.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id and not kapali;
  b := oyun.metin_temizle(p_baslik, 120);
  m := oyun.metin_temizle(p_metin, 2000);
  if char_length(b) < 5 then raise exception 'Karar başlığı en az 5 karakter olmalı.'; end if;
  if char_length(m) < 20 then raise exception 'Karar metni en az 20 karakter olmalı.'; end if;
  perform pg_advisory_xact_lock(hashtext('il_karar:' || pa.id || ':' || il));
  if (select count(*) from oyun.il_karar where parti_id = pa.id and il_id = il and durum = 'oylama') >= 3 then
    raise exception 'Aynı anda en çok 3 önerge oylamada olabilir.'; end if;
  select count(*) into n from oyun.il_karar where parti_id = pa.id and il_id = il and acilis > t - interval '24 hours';
  if n >= 6 then raise exception '24 saatte en çok 6 karar önergesi getirilebilir.'; end if;
  select coalesce(max(k.no), 0) + 1 into v_no from oyun.il_karar k where k.parti_id = pa.id and k.il_id = il and k.yil = v_yil;
  v_kurul := oyun.ilm_kurul(pa.id, il);
  select ad into ilad from oyun.iller where id = il;
  if coalesce(array_length(v_kurul, 1), 0) < 3 then
    -- Kurul kurulmamışsa (başkan + en az 2 üye yoksa) il başkanının oluru ile karar
    insert into oyun.il_karar(parti_id, il_id, yil, no, tur, baslik, metin, oneren, durum, kurul, olur, acilis, bitis, kapanis, kabul)
    values (pa.id, il, v_yil, v_no, v_tur, b, m, p.id, 'kabul', 1, true, t, t, t, 1) returning id into kid;
    perform oyun.il_karar_sonuc(kid);
  else
    insert into oyun.il_karar(parti_id, il_id, yil, no, tur, baslik, metin, oneren, durum, kurul, acilis, bitis, kabul)
    values (pa.id, il, v_yil, v_no, v_tur, b, m, p.id, 'oylama', array_length(v_kurul, 1), t, t + interval '24 hours', 1) returning id into kid;
    insert into oyun.il_karar_oy(karar_id, user_id, oy, zaman) values (kid, p.id, 'kabul', t);
    perform oyun.pdk_toplu_bildir(array_remove(v_kurul, p.id), format('🗳️ %s %s İl Yönetim Kurulu: “%s” önergesi oylamada (24 saat). İl Başkanlığı Masası › Kararlar.', pa.kisa, ilad, left(b, 90)), t);
  end if;
  perform oyun.kidem_ekle(p.id, 'il_gorev');
  return public.il_masa(pa.id, il);
end $$;

create or replace function public.il_karar_oy(p_karar bigint, p_oy text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); k oyun.il_karar; v_kurul uuid[]; n int;
begin
  if p_oy not in ('kabul', 'ret', 'cekimser') then raise exception 'Geçersiz oy.'; end if;
  select * into k from oyun.il_karar where id = p_karar for update;
  if k.id is null or k.durum <> 'oylama' or k.bitis <= t then raise exception 'Bu önerge oylamada değil.'; end if;
  v_kurul := oyun.ilm_kurul(k.parti_id, k.il_id);
  if u is null or not (u = any(v_kurul)) then raise exception 'Bu önergede yalnız il başkanı ve il yönetim kurulu üyeleri oy kullanır.'; end if;
  begin
    insert into oyun.il_karar_oy(karar_id, user_id, oy, zaman) values (k.id, u, p_oy, t);
  exception when unique_violation then raise exception 'Bu önergede zaten oy kullandın.';
  end;
  update oyun.il_karar set kabul = kabul + (p_oy = 'kabul')::int, ret = ret + (p_oy = 'ret')::int, cekimser = cekimser + (p_oy = 'cekimser')::int where id = k.id;
  perform oyun.kidem_ekle(u, 'il_yk_oy');
  select count(*) into n from oyun.il_karar_oy o where o.karar_id = k.id and o.user_id = any(v_kurul);
  if n >= coalesce(array_length(v_kurul, 1), 0) then perform oyun.il_karar_kapat(k.id); end if;
  return public.il_masa(k.parti_id, k.il_id);
end $$;

create or replace function public.il_karar_geri_cek(p_karar bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); k oyun.il_karar;
begin
  select * into k from oyun.il_karar where id = p_karar for update;
  if k.id is null or k.durum <> 'oylama' then raise exception 'Bu önerge oylamada değil.'; end if;
  if not (k.oneren = u or oyun.ilm_rol(u, k.parti_id, k.il_id) = 'baskan') then raise exception 'Önergeyi yalnız il başkanı geri çekebilir.'; end if;
  update oyun.il_karar set durum = 'iptal', kapanis = t where id = k.id;
  return public.il_masa(k.parti_id, k.il_id);
end $$;

-- =========================================================================================
-- H2) GENEL MERKEZE YAZI RPC'LERİ
-- =========================================================================================
create or replace function public.il_gm_yazi_gonder(p_tur text, p_baslik text, p_metin text, p_tutar numeric default null, p_ilgili text default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; il smallint; ilad text; b text; m text;
  v_tur text := coalesce(p_tur, 'rapor'); v numeric; h oyun.profiller; n int;
begin
  if p.parti_id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  il := oyun.ilm_benim_il(p.id);
  if il is null or not oyun.ilm_yetkili(p.id, p.parti_id, il, 'yazisma') then
    raise exception 'Genel merkeze yazıyı il başkanı ya da yazışma yetkisi verilmiş il yönetim kurulu üyesi gönderir.'; end if;
  if v_tur not in ('rapor', 'oneri', 'talep', 'aday') then raise exception 'Geçersiz yazı türü.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id and not kapali;
  b := oyun.metin_temizle(p_baslik, 120);
  m := oyun.metin_temizle(p_metin, 3000);
  if char_length(b) < 5 then raise exception 'Başlık en az 5 karakter olmalı.'; end if;
  if char_length(m) < 20 then raise exception 'Yazı en az 20 karakter olmalı.'; end if;
  if v_tur = 'talep' then
    v := round(p_tutar);
    if v is null or v < 1000 or v > 50000000 then raise exception 'Ödenek talebi 1.000 ₺ ile 50.000.000 ₺ arasında olmalı.'; end if;
  end if;
  if v_tur = 'aday' then
    if nullif(btrim(coalesce(p_ilgili, '')), '') is null then raise exception 'Önerdiğin üyeyi seç.'; end if;
    select * into h from oyun.profiller where lower(kad) = lower(btrim(p_ilgili));
    if h.id is null then
      select count(*) into n from oyun.profiller where parti_id = pa.id and lower(btrim(ad_soyad)) = lower(btrim(p_ilgili));
      if n = 1 then select * into h from oyun.profiller where parti_id = pa.id and lower(btrim(ad_soyad)) = lower(btrim(p_ilgili)); end if;
    end if;
    if h.id is null or h.parti_id is distinct from pa.id then raise exception 'Önerilen kişi partinin üyesi olmalı.'; end if;
  end if;
  perform pg_advisory_xact_lock(hashtext('il_gm_yazi:' || pa.id || ':' || il));
  if (select count(*) from oyun.il_gm_yazi where parti_id = pa.id and il_id = il and zaman > t - interval '24 hours') >= 3 then
    raise exception 'İl başkanlığı 24 saatte en çok 3 yazı gönderebilir.'; end if;
  if (select count(*) from oyun.il_gm_yazi where parti_id = pa.id and il_id = il and durum in ('bekliyor', 'goruldu')) >= 10 then
    raise exception 'Genel merkezde yanıt bekleyen 10 yazın var; önce yanıtlanmalarını bekle.'; end if;
  select ad into ilad from oyun.iller where id = il;
  insert into oyun.il_gm_yazi(parti_id, il_id, gonderen, tur, baslik, metin, tutar, ilgili, zaman) values (pa.id, il, p.id, v_tur, b, m, v, h.id, t);
  perform oyun.ilm_gm_bildir(pa.id, format('📨 %s İl Başkanlığından genel merkeze %s: “%s”. İl Başkanlıkları › Gelen yazılar.', ilad,
      case v_tur when 'talep' then 'ödenek talebi (' || oyun.tl(v) || ' ₺)' when 'aday' then 'aday önerisi' when 'oneri' then 'öneri' else 'rapor' end, left(b, 90)), v_tur = 'talep', t);
  perform oyun.kidem_ekle(p.id, 'il_gorev');
  return public.il_masa(pa.id, il);
end $$;

create or replace function public.il_gm_yazi_cevap(p_id bigint, p_durum text, p_cevap text default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); y oyun.il_gm_yazi; c text; ilad text; bsk uuid;
begin
  select * into y from oyun.il_gm_yazi where id = p_id for update;
  if y.id is null then raise exception 'Yazı bulunamadı.'; end if;
  if p.parti_id is distinct from y.parti_id or not (oyun.teskilat_yonetici(p.id, y.parti_id) or (y.tur = 'talep' and oyun.ilm_mali(p.id, y.parti_id))) then
    raise exception 'İl başkanlıklarından gelen yazıları genel başkan ya da teşkilattan sorumlu genel başkan yardımcısı yanıtlar.'; end if;
  if p_durum not in ('goruldu', 'kabul', 'ret') then raise exception 'Geçersiz yanıt.'; end if;
  if y.durum in ('kabul', 'ret') then raise exception 'Bu yazı zaten sonuçlandı.'; end if;
  c := case when nullif(btrim(coalesce(p_cevap, '')), '') is null then null else oyun.metin_temizle(p_cevap, 600) end;
  if p_durum = 'kabul' and y.tur = 'talep' and coalesce(y.tutar, 0) > 0 then
    if not oyun.ilm_mali(p.id, y.parti_id) then raise exception 'Ödenek talebini kabul etmek için mali yetki gerekir.'; end if;
    perform oyun.il_odenek_ic(y.parti_id, y.il_id, y.tutar, p.id, 'Ödenek talebi kabul', t);
  end if;
  update oyun.il_gm_yazi set durum = p_durum, cevap = coalesce(c, cevap), cevaplayan = p.id, cevap_zaman = t where id = y.id;
  select ad into ilad from oyun.iller where id = y.il_id;
  bsk := oyun.il_baskani(y.parti_id, y.il_id);
  perform oyun.pdk_toplu_bildir(array[y.gonderen, bsk], format('📬 Genel merkez %s İl Başkanlığının “%s” yazısını %s.%s', ilad, left(y.baslik, 80),
      case p_durum when 'kabul' then 'KABUL ETTİ' || case when y.tur = 'talep' then ' (' || oyun.tl(y.tutar) || ' ₺ il kasasına aktarıldı)' else '' end
                   when 'ret' then 'reddetti' else 'gördü' end,
      case when c is not null then ' Yanıt: ' || left(c, 200) else '' end), t);
  return public.il_masa_genel();
end $$;

-- =========================================================================================
-- I) YÖNETİM KURULU YETKİ DEVRİ
-- =========================================================================================
create or replace function public.il_yk_yetki(p_il integer, p_kad text, p_yetkiler text[])
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); pid bigint := (select parti_id from oyun.profiller where id = u); h oyun.profiller; ytk text[]; x text; ilad text;
begin
  if pid is null or not (oyun.ilm_rol(u, pid, p_il::smallint) = 'baskan' or oyun.teskilat_yonetici(u, pid)) then
    raise exception 'Yönetim kurulu yetkilerini il başkanı (ya da genel merkez) belirler.'; end if;
  h := oyun.profil_bul(p_kad);
  ytk := coalesce((select array_agg(distinct v) from unnest(coalesce(p_yetkiler, '{}'::text[])) v where v is not null), '{}');
  foreach x in array ytk loop
    if x not in ('etkinlik', 'aciklama', 'yazisma') then raise exception 'Geçersiz yetki: %', x; end if;
  end loop;
  update oyun.il_yonetim_kurulu set yetkiler = ytk where parti_id = pid and il_id = p_il and user_id = h.id and aktif;
  if not found then raise exception 'Bu kişi il yönetim kurulunda değil.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  perform oyun.bildir(h.id, format('%s il yönetim kurulundaki yetkilerin güncellendi: %s.', ilad,
      case when cardinality(ytk) = 0 then 'yetki yok (yalnız karar oyu)' else array_to_string(array(select case v when 'etkinlik' then 'miting ve stant' when 'aciklama' then 'açıklama ve duyuru' else 'genel merkeze yazı' end from unnest(ytk) v), ', ') end), oyun.simdi());
  return public.il_masa(pid, p_il);
end $$;

-- =========================================================================================
-- J) YÖNTEM AYARI, ATAMA, GÖREVDEN ALMA, KONGRE UÇLARI
-- =========================================================================================
create or replace function public.il_baskan_yontem_ayarla(p_yontem text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; a oyun.il_baskanlik_ayar; eski text; n int := 0; r record;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'İl başkanlarının belirlenme yöntemini yalnız genel başkan seçer.'; end if;
  if p_yontem not in ('secim', 'atama') then raise exception 'Yöntem seçim ya da atama olmalı.'; end if;
  eski := oyun.il_yontem(pa.id);
  if eski = p_yontem then return public.il_masa_genel(); end if;
  select * into a from oyun.il_baskanlik_ayar where parti_id = pa.id;
  if a.degisim is not null and a.degisim > t - interval '7 days' then
    raise exception 'Yöntem 7 günde bir değiştirilebilir. Sonraki değişiklik: %.', oyun.tr_tarih_saat(a.degisim + interval '7 days'); end if;
  if exists (select 1 from oyun.il_kongre k where k.parti_id = pa.id and k.kurultay_id is not null and k.durum in ('aday', 'oy')) then
    raise exception 'Kongre haftası sürerken yöntem değiştirilemez.'; end if;
  insert into oyun.il_baskanlik_ayar(parti_id, yontem, degisim, degistiren) values (pa.id, p_yontem, t, p.id)
  on conflict (parti_id) do update set yontem = excluded.yontem, degisim = excluded.degisim, degistiren = excluded.degistiren;
  if p_yontem = 'atama' then
    for r in select k.id, k.il_id from oyun.il_kongre k where k.parti_id = pa.id and k.durum in ('aday', 'oy') loop
      update oyun.il_kongre set durum = 'iptal', kapanis = t, sonuc = jsonb_build_object('neden', 'Parti il başkanlarını genel merkez ataması ile belirleme kararı aldı') where id = r.id;
      perform oyun.ilm_uyelere_bildir(pa.id, r.il_id, format('%s il başkanlarını artık genel merkez ataması ile belirliyor; %s il kongresi iptal edildi.', pa.kisa, (select ad from oyun.iller where id = r.il_id)), null, t);
      n := n + 1;
    end loop;
    update oyun.il_baskanlik set statu = 'atanmis', donem_bit = null where parti_id = pa.id and aktif and statu = 'gecici';
  else
    update oyun.il_baskanlik set statu = 'gecici' where parti_id = pa.id and aktif and statu = 'atanmis';
  end if;
  perform oyun.parti_yetki_log(pa.id, p.id, 'teskilat', 'il_yontem', null, eski || ' → ' || p_yontem || coalesce(', iptal edilen kongre: ' || n, ''));
  perform oyun.olay('parti', format('%s, il başkanlarını bundan sonra %s belirleyecek.', pa.ad,
      case p_yontem when 'atama' then 'genel merkez ataması ile' else 'il kongrelerinde üyelerin oyuyla' end), null, pa.id, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
  select distinct g.user_id, t, format('%s Genel Başkanı kararı: il başkanları bundan sonra %s.', pa.kisa,
      case p_yontem when 'atama' then 'genel merkez ataması ile belirlenecek; il kongresi yapılmayacak'
                    else 'il kongresinde üyelerin oyuyla seçilecek. Olağan il kongreleri her kurultaydan önceki kongre haftasında yapılır' end)
    from oyun.parti_teskilat_gorev g where g.parti_id = pa.id and g.aktif;
  return public.il_masa_genel();
end $$;

create or replace function public.il_baskan_ata(p_il integer, p_kad text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; h oyun.profiller; ilad text; yontem text; eski uuid; st text; n int;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null or oyun.parti_gorevli(p.id, array['teskilat']) is distinct from pa.id then
    raise exception 'Parti il başkanını yalnızca genel başkan ve Teşkilattan Sorumlu Genel Başkan Yardımcısı atayabilir.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if h.id is null then
    select count(*) into n from oyun.profiller where parti_id = pa.id and lower(btrim(ad_soyad)) = lower(btrim(coalesce(p_kad, '')));
    if n = 1 then select * into h from oyun.profiller where parti_id = pa.id and lower(btrim(ad_soyad)) = lower(btrim(coalesce(p_kad, ''))); end if;
    if n > 1 then raise exception 'Bu ad soyadla partinde birden çok üye var; kullanıcı adını yaz.'; end if;
  end if;
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  if h.parti_id is distinct from pa.id then raise exception 'Yalnızca kendi partinin üyesini il başkanı yapabilirsin.'; end if;
  if h.il_id is distinct from p_il::smallint then raise exception 'İl başkanı, görev yapacağı ilde kayıtlı olmalı.'; end if;
  if coalesce(h.yasakli, false) then raise exception 'Kısıtlı oyuncu il başkanı olamaz.'; end if;
  yontem := oyun.il_yontem(pa.id);
  eski := oyun.il_baskani(pa.id, p_il::smallint);
  if eski = h.id then raise exception '% zaten % il başkanı.', oyun.ilm_ad(h.id), ilad; end if;
  if yontem = 'secim' and exists (select 1 from oyun.il_baskanlik b where b.parti_id = pa.id and b.il_id = p_il and b.aktif and b.statu = 'secilmis') then
    raise exception 'Bu ilde kongrede seçilmiş bir il başkanı var. Değiştirmek için önce gerekçeli "Görevden al" işlemiyle işten el çektirmelisin; ardından olağanüstü kongre açılır.'; end if;
  st := case when yontem = 'atama' then 'atanmis' else 'gecici' end;
  if yontem = 'atama' then
    update oyun.il_kongre set durum = 'iptal', kapanis = t, sonuc = jsonb_build_object('neden', 'Genel merkez il başkanı atadı')
     where parti_id = pa.id and il_id = p_il and durum in ('aday', 'oy');
  end if;
  perform oyun.il_baskan_yaz(pa.id, p_il::smallint, h.id, st, null, p.id, case when eski is not null then 'genel_merkez_degistirdi' end);
  perform oyun.bildir(h.id, case when yontem = 'atama'
      then format('🏛️ %s genel merkezi seni %s İl Başkanı olarak atadı. İl Başkanlığı Masası artık senin: yönetim kurulunu kur, miting ve stant düzenle, açıklama yap, genel merkeze yaz.', pa.kisa, ilad)
      else format('🏛️ %s genel merkezi seni %s GEÇİCİ İl Başkanı olarak görevlendirdi. İl başkanını kongre haftasında üyeler seçecek; aday olabilirsin. İl Başkanlığı Masası şimdiden senin.', pa.kisa, ilad) end, t);
  if eski is not null then
    perform oyun.bildir(eski, format('Genel merkez kararıyla %s il başkanlığın sona erdi; yerine %s görevlendirildi.', ilad, oyun.ilm_ad(h.id)), t);
  end if;
  perform oyun.olay('parti', format('%s %s İl Başkanlığına %s %s.', pa.kisa, ilad, oyun.ilm_ad(h.id), case when yontem = 'atama' then 'atandı' else 'geçici olarak görevlendirildi' end), p_il::smallint, pa.id, t);
  perform oyun.parti_yetki_log(pa.id, p.id, 'teskilat', 'il_baskani_atandi', null, format('il %s, %s (%s)', p_il, h.kad, st));
  return public.il_masa(pa.id, p_il);
end $$;

create or replace function public.il_baskan_gorevden_al(p_il integer, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; h uuid; t timestamptz := oyun.simdi(); yontem text; enaz int;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali;
  if pa.id is null or not oyun.teskilat_yonetici(p.id,pa.id) then raise exception 'İl başkanını genel başkan ya da teşkilat yetkili genel başkan yardımcısı görevden alabilir.'; end if;
  yontem := oyun.il_yontem(pa.id);
  enaz := case when yontem = 'atama' then 10 else 20 end;
  if char_length(btrim(coalesce(p_gerekce,''))) < enaz then
    raise exception 'Görevden alma (işten el çektirme) için en az % karakterlik gerekçe yazılmalı.', enaz; end if;
  h := oyun.il_baskani(pa.id,p_il::smallint);
  if h is null then raise exception 'Bu ilde görevde il başkanı yok.'; end if;
  perform oyun.il_baskan_yaz(pa.id,p_il::smallint,null,null,null,p.id,'gorevden_alindi: '||left(btrim(p_gerekce),300));
  perform oyun.parti_yetki_log(pa.id,p.id,'teskilat','il_baskani_gorevden_alindi',null,format('il %s, %s: %s',p_il,oyun.kad(h),left(btrim(p_gerekce),300)));
  if yontem = 'atama' then
    perform oyun.bildir(h, format('%s genel merkezi %s il başkanlığı görevine son verdi. Gerekçe: %s.',
       pa.kisa,(select ad from oyun.iller where id=p_il),left(btrim(p_gerekce),300)), t);
  else
    perform oyun.bildir(h, format('%s %s il başkanlığı görevinden alındın (işten el çektirme). Gerekçe: %s. İlde olağanüstü kongre açıldı; aday olabilirsin.',
       pa.kisa,(select ad from oyun.iller where id=p_il),left(btrim(p_gerekce),300)), t);
    perform oyun.il_kongre_ac_ic(pa.id,p_il::smallint,'olaganustu',p.id);
  end if;
  return public.il_teskilat_detay(pa.id,p_il);
end $$;

create or replace function public.il_kongre_ac(p_il integer)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; kid bigint; tur text;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali;
  if pa.id is null or not oyun.teskilat_yonetici(p.id,pa.id) then raise exception 'İl kongresini genel başkan ya da teşkilat yetkili genel başkan yardımcısı açabilir.'; end if;
  if oyun.il_yontem(pa.id) = 'atama' then raise exception 'Partin il başkanlarını genel merkez ataması ile belirliyor. İl kongresi için önce tüzükte yöntemi "seçim" yap.'; end if;
  if not exists(select 1 from oyun.parti_teskilat where parti_id=pa.id and il_id=p_il) then raise exception 'Bu ilde parti teşkilatı yok.'; end if;
  if exists(select 1 from oyun.il_kongre where parti_id=pa.id and il_id=p_il and durum in ('aday','oy')) then raise exception 'Bu ilde süren bir kongre var.'; end if;
  if exists(select 1 from oyun.il_baskanlik b where b.parti_id=pa.id and b.il_id=p_il and b.aktif and b.statu='secilmis') then
    raise exception 'Bu ilde kongrede seçilmiş il başkanı var. Olağan kongre kurultaydan önceki kongre haftasında kendiliğinden yapılır; erken kongre için gerekçeli görevden alma (olağanüstü kongre) gerekir.'; end if;
  tur := case when exists(select 1 from oyun.il_kongre where parti_id=pa.id and il_id=p_il and durum='tamam') then 'olagan' else 'ilk' end;
  kid := oyun.il_kongre_ac_ic(pa.id,p_il::smallint,tur,p.id);
  return public.il_teskilat_detay(pa.id,p_il);
end $$;

create or replace function public.il_kongre_aday_ol(p_kongre bigint, p_vaat text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); k oyun.il_kongre; p oyun.profiller; e text;
begin
  select * into k from oyun.il_kongre where id=p_kongre for update;
  if k.id is null or k.durum<>'aday' or oyun.simdi()>=k.aday_bit then raise exception 'Bu kongrede aday başvurusu açık değil.'; end if;
  if not oyun.il_kongre_secmen_mi(k,u) then raise exception 'Aday olmak için kongre açılmadan önce bu ilde partiye üye ve kayıtlı olmalısın.'; end if;
  if oyun.gozalti_aktif(u) is not null then raise exception 'Gözaltındayken aday olunamaz.'; end if;
  if k.kart_zorunlu then
    select * into p from oyun.profiller where id=u;
    e := oyun.uyari(p, oyun.simdi()); if e is not null then raise exception 'Kongrede aday olmak için seçmen kartın hazır olmalı: %', e; end if;
  end if;
  insert into oyun.il_kongre_aday(kongre_id,user_id,vaat) values(k.id,u,left(btrim(coalesce(p_vaat,'')),600))
  on conflict (kongre_id,user_id) do update set cekildi=false, vaat=excluded.vaat;
  return public.il_teskilat_detay(k.parti_id,k.il_id);
end $$;

create or replace function public.il_kongre_oy(p_kongre bigint, p_aday_kad text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); k oyun.il_kongre; a uuid; t timestamptz := oyun.simdi(); p oyun.profiller; e text;
begin
  select * into k from oyun.il_kongre where id=p_kongre;
  if k.id is null or k.durum not in ('aday','oy') or t < k.aday_bit or t >= k.oy_bit then raise exception 'Bu kongrede şu anda oy verilemez.'; end if;
  if not oyun.il_kongre_secmen_mi(k,u) then raise exception 'Bu kongrede oy hakkın yok: kongre açılmadan önce bu ilde partiye üye ve kayıtlı olmalısın.'; end if;
  if k.kart_zorunlu then
    select * into p from oyun.profiller where id=u;
    e := oyun.uyari(p, t); if e is not null then raise exception 'Kongrede oy için seçmen kartın hazır olmalı: %', e; end if;
    if exists(select 1 from oyun.oturumlar y join oyun.oturumlar x on x.cihaz=y.cihaz and x.user_id<>u
                join oyun.il_kongre_oy o on o.kongre_id=k.id and o.secmen=x.user_id
               where y.user_id=u and y.cihaz is not null and y.cihaz<>'') then
      raise exception 'Bu cihazdan bu kongrede başka bir hesapla oy kullanıldı. Her üye kendi cihazından bir kez oy verir.'; end if;
  end if;
  select a2.user_id into a from oyun.il_kongre_aday a2 join oyun.profiller pr on pr.id=a2.user_id
   where a2.kongre_id=k.id and not a2.cekildi and (lower(pr.kad)=lower(btrim(coalesce(p_aday_kad,''))));
  if a is null then raise exception 'Aday bulunamadı.'; end if;
  insert into oyun.il_kongre_oy(kongre_id,secmen,aday,zaman) values(k.id,u,a,t);
  perform oyun.kidem_ekle(u, 'il_kongre_oy');
  return public.il_teskilat_detay(k.parti_id,k.il_id);
exception when unique_violation then raise exception 'Bu kongrede zaten oy kullandın.';
end $$;

-- il_teskilat_detay: eski anahtarlar aynen + ad soyad, yöntem, kongre haftası takvimi
create or replace function public.il_teskilat_detay(p_parti bigint, p_il integer)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); b oyun.il_baskanlik; k oyun.il_kongre; bitti boolean; ks oyun.secimler; h_acilis timestamptz; h_aday timestamptz; h_oy timestamptz; yontem text := oyun.il_yontem(p_parti);
begin
  select * into b from oyun.il_baskanlik where parti_id=p_parti and il_id=p_il and aktif;
  select * into k from oyun.il_kongre where parti_id=p_parti and il_id=p_il order by id desc limit 1;
  bitti := k.id is not null and k.durum in ('tamam','sonucsuz','iptal');
  ks := oyun.ilm_siradaki_kurultay(oyun.simdi());
  if ks.id is not null then select x.acilis, x.aday_bit, x.oy_bit into h_acilis, h_aday, h_oy from oyun.ilm_kongre_takvim(ks.basvuru_bas) x; end if;
  return jsonb_build_object(
    'il_id',p_il,'il',(select ad from oyun.iller where id=p_il),'teskilat',exists(select 1 from oyun.parti_teskilat where parti_id=p_parti and il_id=p_il),
    'baskan',case when b.id is null then null else jsonb_build_object('kad',oyun.kad(b.user_id),'ad',oyun.ilm_ad(b.user_id),'statu',b.statu,'bas',b.bas,'donem_bit',b.donem_bit) end,
    'yonetim_kurulu',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(y.user_id),'ad',oyun.ilm_ad(y.user_id),'gorev',y.gorev,'yetkiler',to_jsonb(y.yetkiler)) order by y.eklenme)
       from oyun.il_yonetim_kurulu y where y.parti_id=p_parti and y.il_id=p_il and y.aktif),'[]'::jsonb),
    'kongre',case when k.id is null then null else jsonb_build_object('id',k.id,'tur',k.tur,'durum',k.durum,'acilis',k.acilis,'aday_bit',k.aday_bit,'oy_bit',k.oy_bit,
       'kazanan',oyun.kad(k.kazanan),'kazanan_ad',oyun.ilm_ad(k.kazanan),'sonuc',k.sonuc,'kongre_haftasi',k.kurultay_id is not null,
       'adaylar',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(a.user_id),'ad',oyun.ilm_ad(a.user_id),'vaat',a.vaat,
            'oy',case when bitti then (select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id and o.aday=a.user_id) end) order by a.basvuru)
          from oyun.il_kongre_aday a where a.kongre_id=k.id and not a.cekildi),'[]'::jsonb),
       'oy_sayisi',(select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id),
       'secmen_mi',oyun.il_kongre_secmen_mi(k,u),
       'oy_verdim',exists(select 1 from oyun.il_kongre_oy o where o.kongre_id=k.id and o.secmen=u),
       'adayim',exists(select 1 from oyun.il_kongre_aday a where a.kongre_id=k.id and a.user_id=u and not a.cekildi)) end,
    'yonetebilir',oyun.teskilat_yonetici(u,p_parti),
    'il_baskaniyim',b.user_id is not distinct from u and b.id is not null,
    'yontem',yontem,
    'kongre_haftasi',case when ks.id is null then null else jsonb_build_object('kurultay_id',ks.id,'kurultay_basvuru',ks.basvuru_bas,'kurultay_oy',ks.oy_bas,
       'acilis',h_acilis,'aday_bit',h_aday,'oy_bit',h_oy,
       'bu_ilde', yontem='secim' and exists(select 1 from oyun.parti_teskilat where parti_id=p_parti and il_id=p_il)
                  and (b.id is null or b.statu<>'secilmis' or b.donem_bit <= ks.basvuru_bas)) end,
    'tuzuk',to_jsonb(oyun.parti_tuzuk(p_parti)) - 'guncelleyen' - 'parti_id');
end $$;

-- =========================================================================================
-- K) ZAMANLAYICI: kongre sonuçları + kongre haftası + karar oylamaları
-- =========================================================================================
create or replace function oyun.il_kongre_tick()
returns integer language plpgsql security definer set search_path to '' as $$
declare r record; k oyun.il_kongre; t timestamptz := oyun.simdi(); kaz uuid; v_sonuc jsonb; n int := 0; ilad text; pk text;
  ks oyun.secimler; h_acilis timestamptz; h_aday timestamptz; h_oy timestamptz; kaz_oy int; diger text; acilan int := 0; ozet text; sec int; sonucsuz int; anahtar text;
begin
  if not pg_try_advisory_xact_lock(781240) then return 0; end if;
  update oyun.il_kongre set durum='oy' where durum='aday' and aday_bit<=t;

  -- 1) Süresi biten kongreleri sonuçlandır
  for r in select id from oyun.il_kongre where durum in ('aday','oy') and oy_bit<=t order by oy_bit limit 200 loop
    begin
      select * into k from oyun.il_kongre where id=r.id for update;
      select ad into ilad from oyun.iller where id=k.il_id;
      select kisa into pk from oyun.partiler where id=k.parti_id;
      select coalesce(jsonb_agg(jsonb_build_object('kad',oyun.kad(x.user_id),'ad',oyun.ilm_ad(x.user_id),'oy',x.oy) order by x.oy desc, x.basvuru),'[]'::jsonb) into v_sonuc
        from (select a.user_id, a.basvuru, (select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id and o.aday=a.user_id) oy
                from oyun.il_kongre_aday a where a.kongre_id=k.id and not a.cekildi) x;
      select x.user_id, x.oy into kaz, kaz_oy from (select a.user_id, a.basvuru, (select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id and o.aday=a.user_id) oy
                from oyun.il_kongre_aday a where a.kongre_id=k.id and not a.cekildi) x
       where x.oy>0 and exists(select 1 from oyun.profiller p where p.id=x.user_id and p.parti_id=k.parti_id and p.il_id=k.il_id and not coalesce(p.yasakli,false))
       order by x.oy desc, x.basvuru limit 1;
      if kaz is null or oyun.il_yontem(k.parti_id)='atama' then
        update oyun.il_kongre set durum='sonucsuz', sonuc=jsonb_build_object('adaylar',v_sonuc,'neden',case when kaz is null then 'Geçerli oy alan uygun aday yok' else 'Parti atama yöntemine geçti' end), kapanis=t where id=k.id;
        perform oyun.bildir(p.id, format('%s il kongresi sonuçsuz kaldı (geçerli oy alan aday yok). Mevcut il başkanı görevine devam eder.',ilad),t)
          from oyun.profiller p where p.parti_id=k.parti_id and p.il_id=k.il_id and not coalesce(p.yasakli,false);
        perform oyun.olay('parti', format('%s %s il kongresi sonuçsuz kaldı: geçerli oy alan aday çıkmadı.', pk, ilad), k.il_id, k.parti_id, t);
      else
        perform oyun.il_baskan_yaz(k.parti_id,k.il_id,kaz,'secilmis',k.id,null,'kongre_sonucu');
        update oyun.il_kongre set durum='tamam', kazanan=kaz, sonuc=jsonb_build_object('adaylar',v_sonuc), kapanis=t where id=k.id;
        perform oyun.bildir(p.id, format('%s il kongresi tamamlandı: il başkanı %s seçildi (%s oy).',ilad,oyun.ilm_ad(kaz),kaz_oy),t)
          from oyun.profiller p where p.parti_id=k.parti_id and p.il_id=k.il_id and not coalesce(p.yasakli,false) and p.id<>kaz;
        perform oyun.bildir(kaz, format('🎉 Tebrikler! %s %s il kongresinde %s oyla İl Başkanı seçildin. İl Başkanlığı Masası artık senin: yönetim kurulunu kur, miting ve stant düzenle, açıklama yap, genel merkeze yaz.', pk, ilad, kaz_oy), t);
        select string_agg(x->>'ad' || ' ' || (x->>'oy') || ' oy', ', ') into diger
          from jsonb_array_elements(v_sonuc) x where (x->>'kad') is distinct from oyun.kad(kaz);
        perform oyun.olay('parti', format('%s %s il kongresi: il başkanlığına %s seçildi (%s oy).%s', pk, ilad, oyun.ilm_ad(kaz), kaz_oy,
            case when diger is not null then ' Diğer adaylar: ' || diger || '.' else '' end), k.il_id, k.parti_id, t);
        perform oyun.parti_yetki_log(k.parti_id,kaz,'teskilat','il_baskani_secildi',null,format('il %s, kongre #%s',k.il_id,k.id));
      end if;
      n := n+1;
    exception when others then raise warning 'il_kongre_tick #%: %', r.id, sqlerrm;
    end;
  end loop;

  ks := oyun.ilm_siradaki_kurultay(t);
  if ks.id is not null then select x.acilis, x.aday_bit, x.oy_bit into h_acilis, h_aday, h_oy from oyun.ilm_kongre_takvim(ks.basvuru_bas) x; end if;

  -- 2) Kongre haftası: kurultaydan önce seçim yöntemli partilerde olağan il kongreleri
  if ks.id is not null and t >= h_acilis and t < h_aday then
    for r in select pt.parti_id, pt.il_id,
                    exists(select 1 from oyun.il_kongre kq where kq.parti_id=pt.parti_id and kq.il_id=pt.il_id and kq.durum='tamam') eski_tamam
               from oyun.parti_teskilat pt join oyun.partiler pa on pa.id=pt.parti_id and not pa.kapali
              where oyun.il_yontem(pt.parti_id)='secim'
                and not exists(select 1 from oyun.il_kongre kq where kq.parti_id=pt.parti_id and kq.il_id=pt.il_id and (kq.durum in ('aday','oy') or kq.kurultay_id=ks.id))
                and not exists(select 1 from oyun.il_baskanlik b where b.parti_id=pt.parti_id and b.il_id=pt.il_id and b.aktif and b.statu='secilmis' and b.donem_bit > ks.basvuru_bas)
                and exists(select 1 from oyun.profiller p where p.parti_id=pt.parti_id and p.il_id=pt.il_id and not coalesce(p.yasakli,false)
                             and coalesce(p.parti_at,p.olusturma)<=h_acilis and coalesce(p.il_at,p.olusturma)<=h_acilis)
              order by pt.parti_id, pt.il_id
              limit 150 loop
      begin
        perform oyun.il_kongre_ac_takvim(r.parti_id, r.il_id, case when r.eski_tamam then 'olagan' else 'ilk' end, ks.id, h_acilis, h_aday, h_oy);
        acilan := acilan + 1;
      exception when others then raise warning 'il_kongre_tick hafta %/%: %', r.parti_id, r.il_id, sqlerrm;
      end;
    end loop;
    if acilan > 0 then
      perform oyun.ajans_yayinla('il-kongre-hafta-' || ks.id, 'siyaset', 'Partilerde il kongresi haftası başladı',
        format('Kurultaydan önce il başkanlıkları yenileniyor: aday başvurusu %s''e kadar, oy %s 08.00–22.00.', to_char(h_aday at time zone 'Europe/Istanbul','DD.MM HH24:MI'), to_char(h_aday at time zone 'Europe/Istanbul','DD.MM')),
        'İl başkanlarını üyelerin oyuyla seçen partilerde olağan il kongreleri açıldı. Kongrelerde partinin o ilde kayıtlı üyeleri aday olur ve oy verir. Kongre haftasının ardından genel başkanlık seçimi (kurultay) yapılacak.',
        40, null, null, t);
    end if;
  end if;

  -- 3) Kongre haftası bitti: parti başına özet haber (bir kez)
  if ks.id is not null and t >= h_oy and t < ks.basvuru_bas then
    for r in select distinct k2.parti_id from oyun.il_kongre k2
              where k2.kurultay_id=ks.id
                and not exists(select 1 from oyun.il_kongre k3 where k3.kurultay_id=ks.id and k3.parti_id=k2.parti_id and k3.durum in ('aday','oy'))
                and not exists(select 1 from oyun.ajans_haberleri h where h.kaynak_anahtar='il-kongre-ozet-' || ks.id || '-' || k2.parti_id)
              limit 30 loop
      begin
        anahtar := 'il-kongre-ozet-' || ks.id || '-' || r.parti_id;
        select count(*) filter (where k2.durum='tamam'), count(*) filter (where k2.durum='sonucsuz'),
               string_agg(case when k2.durum='tamam' then i.ad || ': ' || oyun.ilm_ad(k2.kazanan) ||
                 coalesce(' (' || (select x->>'oy' from jsonb_array_elements(k2.sonuc->'adaylar') x where x->>'kad' = oyun.kad(k2.kazanan) limit 1) || ' oy)', '') end, E'\n' order by i.ad)
          into sec, sonucsuz, ozet
          from oyun.il_kongre k2 join oyun.iller i on i.id=k2.il_id where k2.kurultay_id=ks.id and k2.parti_id=r.parti_id;
        select kisa into pk from oyun.partiler where id=r.parti_id;
        perform oyun.ajans_yayinla(anahtar, 'siyaset', case when sec > 0 then format('%s il kongrelerini tamamladı: %s ilde il başkanı seçildi', pk, sec) else format('%s kongre haftasında il başkanı seçemedi', pk) end,
          format('%s kongre haftasında %s ilde başkanını seçti%s. Sırada genel başkanlık seçimi var.', pk, sec,
                 case when sonucsuz>0 then ', ' || sonucsuz || ' ilde kongre sonuçsuz kaldı' else '' end),
          coalesce('Seçilen il başkanları:' || E'\n' || ozet, 'Bu kongre haftasında il başkanı seçilemedi.'), 45, r.parti_id, null, t);
        perform oyun.ilm_gm_bildir(r.parti_id, format('🏁 Kongre haftası bitti: %s ilde il başkanı seçildi%s. Sırada kurultay var.', sec,
          case when sonucsuz>0 then ', ' || sonucsuz || ' ilde kongre sonuçsuz kaldı' else '' end), false, t);
      exception when others then raise warning 'il_kongre_tick özet %: %', r.parti_id, sqlerrm;
      end;
    end loop;
  end if;

  -- 4) Kongre haftası dışında (seçim yöntemi): süresi dolan geçici başkanlık için ilk kongre; kurultay takvimi yoksa dönem sonu kongresi
  for r in select b.parti_id, b.il_id, b.statu from oyun.il_baskanlik b join oyun.partiler pa on pa.id=b.parti_id and not pa.kapali
     where b.aktif and oyun.il_yontem(b.parti_id)='secim'
       and not exists(select 1 from oyun.il_kongre kq where kq.parti_id=b.parti_id and kq.il_id=b.il_id and kq.durum in ('aday','oy'))
       and not exists(select 1 from oyun.il_kongre kq where kq.parti_id=b.parti_id and kq.il_id=b.il_id and kq.kapanis > t - interval '3 days')
       and (ks.id is null or t < h_acilis - interval '7 days')
       and ((b.statu='gecici' and b.bas <= t - make_interval(days=>(oyun.parti_tuzuk(b.parti_id)).il_gecici_azami_gun))
         or (b.statu='secilmis' and ks.id is null and b.donem_bit <= t))
     limit 100 loop
    begin
      perform oyun.il_kongre_ac_ic(r.parti_id,r.il_id,case when not exists(select 1 from oyun.il_kongre kq where kq.parti_id=r.parti_id and kq.il_id=r.il_id and kq.durum='tamam') then 'ilk' else 'olagan' end,null);
    exception when others then raise warning 'il_kongre_tick ac %/%: %', r.parti_id, r.il_id, sqlerrm;
    end;
  end loop;
  return n;
end $$;

create or replace function oyun.il_masa_tick()
returns integer language plpgsql security definer set search_path to '' as $$
declare r record; n int := 0;
begin
  if not pg_try_advisory_xact_lock(781241) then return 0; end if;
  for r in select id from oyun.il_karar where durum='oylama' and bitis <= oyun.simdi() order by bitis limit 200 loop
    begin perform oyun.il_karar_kapat(r.id); n := n + 1;
    exception when others then raise warning 'il_masa_tick karar #%: %', r.id, sqlerrm; end;
  end loop;
  return n;
end $$;

insert into oyun.zamanlayici_adim(adim,komut,periyot_dk,ofset_dk,sira,aktif)
values('il_masa','select oyun.il_masa_tick()',5,4,121,true)
on conflict (adim) do update set komut=excluded.komut, periyot_dk=excluded.periyot_dk, aktif=true;

-- Kıdem kaynakları (parti görevleri kıdeme bağlanır)
insert into oyun.kidem_kaynak(kod, ad, puan, gunluk_tavan, sira) values
  ('il_gorev', 'İl başkanlığı görevi (açıklama, etkinlik, karar, yazışma)', 1, 1, 36),
  ('il_yk_oy', 'İl yönetim kurulunda karar oyu', 0.5, 0.5, 37),
  ('il_kongre_oy', 'İl kongresinde oy kullanmak', 0.5, 0.5, 38)
on conflict (kod) do update set ad = excluded.ad, puan = excluded.puan, gunluk_tavan = excluded.gunluk_tavan, sira = excluded.sira;

-- =========================================================================================
-- L) MASA EKRANI VERİLERİ
-- =========================================================================================
-- Son 14 günün il karnesi (0-100): etkinlik, açıklama, karar, yönetim kurulu doluluğu, üye tabanı
create or replace function oyun.il_karne(p_parti bigint)
returns table(il_id smallint, puan integer, miting integer, stant integer, aciklama integer, karar integer, yk integer, uye integer)
language sql stable set search_path to '' as $$
  with t as (select oyun.simdi() an),
  il as (select pt.il_id from oyun.parti_teskilat pt where pt.parti_id = p_parti),
  mi as (select m.il_id, count(*)::int n from oyun.mitingler m, t where m.parti_id = p_parti and m.tur = 'parti' and m.bas > t.an - interval '14 days' and m.bas < t.an + interval '3 days' group by 1),
  st as (select s.il_id, count(*)::int n from oyun.stant s, t where s.parti_id = p_parti and s.bas > t.an - interval '14 days' group by 1),
  ac as (select a.il_id, count(*)::int n from oyun.il_aciklama a, t where a.parti_id = p_parti and not a.silindi and a.zaman > t.an - interval '14 days' group by 1),
  ka as (select k.il_id, count(*)::int n from oyun.il_karar k, t where k.parti_id = p_parti and k.durum = 'kabul' and k.kapanis > t.an - interval '14 days' group by 1),
  yk as (select y.il_id, count(*)::int n from oyun.il_yonetim_kurulu y where y.parti_id = p_parti and y.aktif group by 1),
  uy as (select p.il_id, count(*)::int n from oyun.profiller p where p.parti_id = p_parti and not coalesce(p.yasakli, false) group by 1)
  select il.il_id,
         least(100, least(36, coalesce(mi.n, 0) * 12) + least(18, coalesce(st.n, 0) * 6) + least(12, coalesce(ac.n, 0) * 3)
           + least(12, coalesce(ka.n, 0) * 4) + least(14, coalesce(yk.n, 0) * 2)
           + case when coalesce(uy.n, 0) >= 50 then 8 when coalesce(uy.n, 0) >= 20 then 6 when coalesce(uy.n, 0) >= 10 then 4 when coalesce(uy.n, 0) >= 3 then 2 else 0 end)::int,
         coalesce(mi.n, 0), coalesce(st.n, 0), coalesce(ac.n, 0), coalesce(ka.n, 0), coalesce(yk.n, 0), coalesce(uy.n, 0)
    from il left join mi on mi.il_id = il.il_id left join st on st.il_id = il.il_id left join ac on ac.il_id = il.il_id
         left join ka on ka.il_id = il.il_id left join yk on yk.il_id = il.il_id left join uy on uy.il_id = il.il_id
$$;

create or replace function public.il_masa(p_parti bigint default null, p_il integer default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); p oyun.profiller; pa oyun.partiler; il smallint; rol text; gm boolean; mali boolean; ozel boolean; t timestamptz := oyun.simdi();
  b oyun.il_baskanlik; karne jsonb; sira int; toplam int; ytk text[]; gun date := (t at time zone 'Europe/Istanbul')::date; ilad text; tes boolean;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into p from oyun.profiller where id = u;
  select * into pa from oyun.partiler where id = coalesce(p_parti, p.parti_id) and not kapali;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  il := coalesce(p_il::smallint, case when pa.id = p.parti_id then oyun.ilm_benim_il(u) end, p.il_id);
  select ad into ilad from oyun.iller where id = il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  rol := oyun.ilm_rol(u, pa.id, il);
  gm := pa.id = p.parti_id and oyun.teskilat_yonetici(u, pa.id);
  mali := pa.id = p.parti_id and oyun.ilm_mali(u, pa.id);
  ozel := rol in ('baskan', 'yk') or gm or mali or coalesce(p.yonetici, false);
  select y.yetkiler into ytk from oyun.il_yonetim_kurulu y where y.parti_id = pa.id and y.il_id = il and y.user_id = u and y.aktif;
  select * into b from oyun.il_baskanlik where parti_id = pa.id and il_id = il and aktif;
  tes := exists (select 1 from oyun.parti_teskilat where parti_id = pa.id and il_id = il);
  select to_jsonb(k) - 'il_id', k.puan into karne from oyun.il_karne(pa.id) k where k.il_id = il;
  select count(*)::int, (count(*) filter (where k.puan > coalesce((karne->>'puan')::int, 0)))::int + 1 into toplam, sira from oyun.il_karne(pa.id) k;
  return jsonb_build_object(
    'simdi', t,
    'parti', jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'amblem', pa.amblem),
    'il', jsonb_build_object('id', il, 'ad', ilad, 'mv', (select mv from oyun.iller where id = il)),
    'rol', rol, 'gm', gm, 'mali', mali, 'gb', pa.gb = u, 'ozel', ozel,
    'yetkiler', case when rol = 'baskan' then '["etkinlik","aciklama","yazisma","karar","yk"]'::jsonb when rol = 'yk' then to_jsonb(coalesce(ytk, '{}')) else '[]'::jsonb end,
    'yontem', oyun.il_yontem(pa.id),
    'teskilat', tes,
    'detay', public.il_teskilat_detay(pa.id, il),
    'yk_azami', (oyun.parti_tuzuk(pa.id)).il_yk_azami,
    'istatistik', jsonb_build_object(
       'uye', (select count(*) from oyun.profiller x where x.parti_id = pa.id and x.il_id = il and not coalesce(x.yasakli, false)),
       'yeni_7g', (select count(*) from oyun.profiller x where x.parti_id = pa.id and x.il_id = il and not coalesce(x.yasakli, false) and coalesce(x.parti_at, x.olusturma) > t - interval '7 days'),
       'aktif_24s', (select count(*) from oyun.profiller x where x.parti_id = pa.id and x.il_id = il and not coalesce(x.yasakli, false) and x.son_gorulme > t - interval '24 hours'),
       'mv', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.il_id = il and m.parti_id = pa.id),
       'mv_adlar', coalesce((select jsonb_agg(oyun.ilm_ad(m.user_id)) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.il_id = il and m.parti_id = pa.id), '[]'::jsonb),
       'belediye', (select oyun.ilm_ad(m.user_id) from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.il_id = il and m.parti_id = pa.id limit 1)),
    'karne', coalesce(karne, '{}'::jsonb) || jsonb_build_object('sira', sira, 'toplam', toplam),
    'kasa', case when ozel then jsonb_build_object(
       'bakiye', coalesce((select bakiye from oyun.il_kasa where parti_id = pa.id and il_id = il), 0),
       'hareket', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'tur', h.tur, 'aciklama', h.aciklama) order by h.id desc)
          from (select * from oyun.il_kasa_hareket h where h.parti_id = pa.id and h.il_id = il order by h.id desc limit 12) h), '[]'::jsonb),
       'parti_kasa', case when mali then pa.kasa end) end,
    'mitingler', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'baslik', m.baslik, 'bas', m.bas, 'bit', m.bit, 'kad', oyun.kad(m.user_id), 'ad', oyun.ilm_ad(m.user_id),
         'il_orgut', coalesce(m.il_orgut, false), 'odeyen', m.odeyen, 'bedel', m.bedel, 'canli', t >= m.bas and t < m.bit,
         'iptal_edebilir', coalesce(m.il_orgut, false) and m.bas > t and (m.user_id = u or rol = 'baskan' or gm)) order by m.bas desc)
       from (select * from oyun.mitingler m where m.parti_id = pa.id and m.tur = 'parti' and m.il_id = il and m.bas > t - interval '7 days' order by m.bas desc limit 8) m), '[]'::jsonb),
    'stantlar', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'baslik', s.baslik, 'bas', s.bas, 'bit', s.bit, 'ad', oyun.ilm_ad(s.acan), 'canli', t >= s.bas and t < s.bit) order by s.bas desc)
       from (select * from oyun.stant s where s.parti_id = pa.id and s.il_id = il and s.bas > t - interval '7 days' order by s.bas desc limit 6) s), '[]'::jsonb),
    'aciklamalar', public.il_aciklamalari(pa.id, il, null),
    'kararlar', case when ozel then coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'no', k.yil || '/' || k.no, 'tur', k.tur, 'baslik', k.baslik, 'metin', k.metin,
         'durum', k.durum, 'kurul', k.kurul, 'olur', k.olur, 'acilis', k.acilis, 'bitis', k.bitis, 'kabul', k.kabul, 'ret', k.ret, 'cekimser', k.cekimser,
         'oneren', oyun.ilm_ad(k.oneren), 'oyum', (select o.oy from oyun.il_karar_oy o where o.karar_id = k.id and o.user_id = u)) order by k.id desc)
       from (select * from oyun.il_karar k where k.parti_id = pa.id and k.il_id = il order by k.id desc limit 12) k), '[]'::jsonb) end,
    'yazilar', case when ozel then coalesce((select jsonb_agg(jsonb_build_object('id', y.id, 'tur', y.tur, 'baslik', y.baslik, 'metin', y.metin, 'tutar', y.tutar,
         'ilgili', oyun.ilm_ad(y.ilgili), 'zaman', y.zaman, 'durum', y.durum, 'cevap', y.cevap, 'cevaplayan', oyun.ilm_ad(y.cevaplayan), 'gonderen', oyun.ilm_ad(y.gonderen)) order by y.id desc)
       from (select * from oyun.il_gm_yazi y where y.parti_id = pa.id and y.il_id = il order by y.id desc limit 10) y), '[]'::jsonb) end,
    'haklar', jsonb_build_object(
       'miting_bedel', oyun.miting_bedel(il),
       'stant_bedel', coalesce((select stant_bedel from oyun.ayarlar where id = 1), 2000),
       'stant_bugun', exists (select 1 from oyun.stant s where s.parti_id = pa.id and s.il_id = il and oyun.sm_gun(s.bas) = oyun.sm_gun(t)),
       'aciklama_bugun', (select count(*) from oyun.il_aciklama a where a.parti_id = pa.id and a.il_id = il and a.kamu and (a.zaman at time zone 'Europe/Istanbul')::date = gun),
       'duyuru_bugun', (select count(*) from oyun.il_aciklama a where a.parti_id = pa.id and a.il_id = il and not a.kamu and (a.zaman at time zone 'Europe/Istanbul')::date = gun),
       'aciklama_sinir', 6, 'duyuru_sinir', 3,
       'sonraki_aciklama', (select max(a.zaman) + interval '20 minutes' from oyun.il_aciklama a where a.parti_id = pa.id and a.il_id = il and not a.silindi and a.zaman > t - interval '20 minutes'),
       'yazi_24s', (select count(*) from oyun.il_gm_yazi y where y.parti_id = pa.id and y.il_id = il and y.zaman > t - interval '24 hours'), 'yazi_sinir', 3,
       'cuzdan', (select para from oyun.cuzdan where user_id = u)),
    'uyeler', case when ozel then coalesce((select jsonb_agg(jsonb_build_object('kad', x.kad, 'ad', coalesce(nullif(btrim(x.ad_soyad), ''), x.kad),
         'yk', exists (select 1 from oyun.il_yonetim_kurulu y where y.parti_id = pa.id and y.il_id = il and y.user_id = x.id and y.aktif),
         'baskan', x.id = b.user_id) order by coalesce(nullif(btrim(x.ad_soyad), ''), x.kad) collate "tr-TR-x-icu")
       from (select * from oyun.profiller x where x.parti_id = pa.id and x.il_id = il and not coalesce(x.yasakli, false) limit 500) x), '[]'::jsonb) end);
end $$;

-- Genel merkez görünümü: partinin 81 il başkanlığı, karneler, bekleyen yazılar
create or replace function public.il_masa_genel()
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); p oyun.profiller; pa oyun.partiler; gm boolean; mali boolean; ks oyun.secimler; h_acilis timestamptz; h_aday timestamptz; h_oy timestamptz; t timestamptz := oyun.simdi(); a oyun.il_baskanlik_ayar;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into p from oyun.profiller where id = u;
  select * into pa from oyun.partiler where id = p.parti_id and not kapali;
  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  gm := oyun.teskilat_yonetici(u, pa.id); mali := oyun.ilm_mali(u, pa.id);
  if not (gm or mali or coalesce(p.yonetici, false)) then raise exception 'İl başkanlıkları görünümü genel merkez (genel başkan, teşkilat ya da mali işler GBY) içindir.'; end if;
  ks := oyun.ilm_siradaki_kurultay(t);
  if ks.id is not null then select x.acilis, x.aday_bit, x.oy_bit into h_acilis, h_aday, h_oy from oyun.ilm_kongre_takvim(ks.basvuru_bas) x; end if;
  select * into a from oyun.il_baskanlik_ayar where parti_id = pa.id;
  return jsonb_build_object(
    'simdi', t,
    'parti', jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'amblem', pa.amblem, 'kasa', case when mali then pa.kasa end),
    'gb', pa.gb = u, 'gm', gm, 'mali', mali,
    'yontem', oyun.il_yontem(pa.id),
    'yontem_degisim', a.degisim,
    'yontem_sonraki', case when a.degisim is not null and a.degisim > t - interval '7 days' then a.degisim + interval '7 days' end,
    'kongre_haftasi', case when ks.id is null then null else jsonb_build_object('kurultay_id', ks.id, 'kurultay_basvuru', ks.basvuru_bas, 'kurultay_oy', ks.oy_bas,
        'acilis', h_acilis, 'aday_bit', h_aday, 'oy_bit', h_oy,
        'acik_kongre', (select count(*) from oyun.il_kongre k where k.parti_id = pa.id and k.kurultay_id = ks.id and k.durum in ('aday', 'oy'))) end,
    'tuzuk', to_jsonb(oyun.parti_tuzuk(pa.id)) - 'guncelleyen' - 'parti_id',
    'iller', coalesce((select jsonb_agg(jsonb_build_object(
        'il_id', i.id, 'il', i.ad, 'mv', i.mv,
        'teskilat', pt.il_id is not null,
        'baskan', case when b.id is null then null else jsonb_build_object('kad', oyun.kad(b.user_id), 'ad', oyun.ilm_ad(b.user_id), 'statu', b.statu, 'donem_bit', b.donem_bit) end,
        'yk', coalesce(kr.yk, 0), 'uye', coalesce(kr.uye, 0), 'puan', coalesce(kr.puan, 0),
        'kasa', coalesce((select bakiye from oyun.il_kasa ik where ik.parti_id = pa.id and ik.il_id = i.id), 0),
        'kongre', (select jsonb_build_object('id', k.id, 'durum', k.durum, 'aday_bit', k.aday_bit, 'oy_bit', k.oy_bit) from oyun.il_kongre k where k.parti_id = pa.id and k.il_id = i.id and k.durum in ('aday', 'oy') limit 1),
        'bekleyen', (select count(*) from oyun.il_gm_yazi y where y.parti_id = pa.id and y.il_id = i.id and y.durum in ('bekliyor', 'goruldu'))
      ) order by (pt.il_id is null), coalesce(kr.puan, 0) desc, i.ad collate "tr-TR-x-icu")
      from oyun.iller i
      left join oyun.parti_teskilat pt on pt.parti_id = pa.id and pt.il_id = i.id
      left join oyun.il_baskanlik b on b.parti_id = pa.id and b.il_id = i.id and b.aktif
      left join oyun.il_karne(pa.id) kr on kr.il_id = i.id), '[]'::jsonb),
    'gelen', coalesce((select jsonb_agg(jsonb_build_object('id', y.id, 'il_id', y.il_id, 'il', (select ad from oyun.iller where id = y.il_id), 'tur', y.tur, 'baslik', y.baslik, 'metin', y.metin,
        'tutar', y.tutar, 'ilgili', oyun.ilm_ad(y.ilgili), 'ilgili_kad', oyun.kad(y.ilgili), 'gonderen', oyun.ilm_ad(y.gonderen), 'zaman', y.zaman, 'durum', y.durum, 'cevap', y.cevap,
        'karar', (select k.yil || '/' || k.no from oyun.il_karar k where k.id = y.karar_id)) order by (y.durum in ('bekliyor', 'goruldu')) desc, y.id desc)
      from (select * from oyun.il_gm_yazi y where y.parti_id = pa.id order by (y.durum in ('bekliyor', 'goruldu')) desc, y.id desc limit 40) y), '[]'::jsonb));
end $$;

-- Girişler için kısa durum: hangi ilde başkan / kurul üyesiyim, genel merkez miyim, bekleyen iş
create or replace function public.il_masa_benim()
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); p oyun.profiller; il smallint; rol text; gm boolean := false; pa oyun.partiler;
begin
  if u is null then return null; end if;
  select * into p from oyun.profiller where id = u;
  if p.parti_id is null then return jsonb_build_object('parti_id', null); end if;
  select * into pa from oyun.partiler where id = p.parti_id and not kapali;
  if pa.id is null then return jsonb_build_object('parti_id', null); end if;
  il := oyun.ilm_benim_il(u);
  if il is not null then rol := oyun.ilm_rol(u, pa.id, il); end if;
  gm := oyun.teskilat_yonetici(u, pa.id) or oyun.ilm_mali(u, pa.id);
  return jsonb_build_object('parti_id', pa.id, 'parti', pa.kisa, 'il_id', il, 'il', (select ad from oyun.iller where id = il),
    'rol', case when rol in ('baskan', 'yk') then rol end, 'gm', gm, 'gb', pa.gb = u, 'yontem', oyun.il_yontem(pa.id),
    'oy_bekleyen', case when il is not null then (select count(*) from oyun.il_karar k where k.parti_id = pa.id and k.il_id = il and k.durum = 'oylama'
        and not exists (select 1 from oyun.il_karar_oy o where o.karar_id = k.id and o.user_id = u)) else 0 end,
    'gelen_bekleyen', case when gm then (select count(*) from oyun.il_gm_yazi y where y.parti_id = pa.id and y.durum = 'bekliyor') else 0 end);
end $$;

-- =========================================================================================
-- M) İZİNLER
-- =========================================================================================
do $g$
declare f text;
begin
  foreach f in array array['public.il_kasa_odenek(integer,numeric)','public.il_kasa_iade(integer,numeric)','public.il_kasa_bagis(bigint,integer,numeric)',
    'public.il_miting_duzenle(timestamp with time zone,text,text)','public.il_miting_iptal(bigint)','public.il_stant_ac(text,text)',
    'public.il_aciklama_yap(text,text,boolean)','public.il_aciklamalari(bigint,integer,bigint)','public.il_aciklama_sil(bigint)',
    'public.il_karar_oner(text,text,text)','public.il_karar_oy(bigint,text)','public.il_karar_geri_cek(bigint)',
    'public.il_gm_yazi_gonder(text,text,text,numeric,text)','public.il_gm_yazi_cevap(bigint,text,text)','public.il_yk_yetki(integer,text,text[])',
    'public.il_baskan_yontem_ayarla(text)','public.il_baskan_ata(integer,text)','public.il_baskan_gorevden_al(integer,text)','public.il_kongre_ac(integer)',
    'public.il_kongre_aday_ol(bigint,text)','public.il_kongre_oy(bigint,text)','public.il_teskilat_detay(bigint,integer)',
    'public.il_masa(bigint,integer)','public.il_masa_genel()','public.il_masa_benim()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['oyun.ilm_ad(uuid)','oyun.il_yontem(bigint)','oyun.ilm_siradaki_kurultay(timestamp with time zone)','oyun.ilm_kongre_takvim(timestamp with time zone)',
    'oyun.il_kongre_ac_ic(bigint,smallint,text,uuid)','oyun.il_kongre_ac_takvim(bigint,smallint,text,bigint,timestamp with time zone,timestamp with time zone,timestamp with time zone)',
    'oyun.ilm_rol(uuid,bigint,smallint)','oyun.ilm_yetkili(uuid,bigint,smallint,text)','oyun.ilm_benim_il(uuid)','oyun.ilm_mali(uuid,bigint)','oyun.ilm_kurul(bigint,smallint)',
    'oyun.ilm_uyelere_bildir(bigint,smallint,text,uuid,timestamp with time zone)','oyun.ilm_gm_bildir(bigint,text,boolean,timestamp with time zone)',
    'oyun.il_kasa_islem(bigint,smallint,numeric,text,text,uuid,timestamp with time zone)','oyun.il_odenek_ic(bigint,smallint,numeric,uuid,text,timestamp with time zone)',
    'oyun.il_karar_sonuc(bigint)','oyun.il_karar_kapat(bigint)','oyun.il_kongre_tick()','oyun.il_masa_tick()','oyun.il_karne(bigint)',
    'oyun.parti_miting_temizle(timestamp with time zone)','oyun.parti_miting_iptal(bigint,text,timestamp with time zone)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $g$;
