-- 23.11.2026 · CİHAZ YASAĞI (sürüm 2026.11.23-7)
-- İstek (Ercan): ağır hakaret ve tehdit yüzünden engellenen oyuncular farklı adlarla yeniden başvuruyor, kim oldukları
-- anlaşılamıyor. "Cihaz yasağını yürürlüğe sokmak için ne gerekiyorsa yap."
--
-- Bulgu: uygulama her açılışta cihaz kimliğini zaten gönderiyor (oturum_kaydet; telefonda Capacitor Device.getId,
-- web'de tarayıcıya yazılan kimlik). Ama 16.11'deki kayıt onayından beri oyun.ben() onay bekleyen hesabı reddettiği için
-- BAŞVURU AŞAMASINDA cihaz kaydedilmiyordu: cihaz ancak onaydan sonra görülüyor, engellenen kişi yeni hesabıyla
-- moderatörün önüne "temiz" geliyordu. Aynı sebeple cihaz başına hesap sınırı (profil_guvenlik_tg) onay anında boşa düşüyordu.
--
-- Kurallar:
--  1) oturum_kaydet onay bekleyen / reddedilen hesabın cihazını da kaydeder (auth.uid()).
--  2) Yasaklı cihaz listesi oyun_yonetim.cihaz_yasak: yalnız tuzlanmış özet (oyun.ozet), ham kimlik yok. oyun_yonetim
--     şemasında durur; oyun sıfırlansa da silinmez (tuz oyun.ayarlar'da, o da katalog tablosudur).
--  3) Bir hesap KALICI engellenince (yönetim kararı; "Hesap sahibi tarafından silindi" hariç) o hesabın görüldüğü bütün
--     cihazlar kendiliğinden listeye girer. Engel kalkar ya da süreliye çevrilirse o hesaptan gelen yasak da kalkar
--     (aynı cihazda başka kalıcı engelli varsa yasak ona devredilir).
--  4) Yasaklı cihazdan: yeni başvuru yapılamaz, bekleyen başvuru onaylanamaz, hesabı olan da o cihazdan oyuna giremez
--     (durum). Kurucu ve Çoklu hesap ekranından ayrı kişi olduğu onaylanan hesaplar (oyun.hesap_onay) muaftır.
--  5) Engel sürerken (süreli uzaklaştırma dahil) aynı cihazdan yeni hesap başvurusu yapılamaz; cihaz başına hesap sınırı
--     (ayarlar.cihaz_max_hesap) başvuru anında da uygulanır.
--  6) Telefon değiştirene ya da uygulamayı silip kurana karşı: başvuru, engelli bir hesapla aynı bağlantı (IP özeti) +
--     aynı cihaz izinden geliyorsa "güçlü uyarı" alır; moderatör uyarıyı görmeden onaylayamaz (mod_kayit_karar).
--     Yalnız bağlantı eşleşmesi zayıf işarettir (operatör / aile / okul paylaşımı), sadece bilgi olarak gösterilir.
--  Güvenlik supapları: cihaz izi (aynı model telefonlarda aynıdır) hiçbir zaman yasaklanmaz; 5'ten çok hesabın kullandığı
--  kimlik kendiliğinden yasaklanmaz (kurucuya bildirilir); bu dosyadaki hiçbir hata engelleme işleminin kendisini durdurmaz.
-- Yama yardımcısı oyun._yama (zz_20261121_00_yama.sql) bu dosyadan önce gelmelidir. Tekrar çalıştırmak güvenlidir.

-- ---------------------------------------------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------------------------------------------
create table if not exists oyun_yonetim.cihaz_yasak (
  id bigserial primary key,
  cihaz text not null,                       -- oyun.ozet ile tuzlanmış cihaz kimliği özeti
  kaynak_user uuid,                          -- yasağa sebep olan hesap
  kaynak_kad text,
  neden text,
  ekleyen uuid,                              -- engeli veren yönetici (boş: sistem / ilk kurulum)
  zaman timestamptz not null default clock_timestamp(),
  aktif boolean not null default true,
  kaldiran uuid,
  kaldirma_zaman timestamptz,
  kaldirma_not text,
  constraint cihaz_yasak_cihaz_tek unique (cihaz)
);
create index if not exists cihaz_yasak_kaynak_ix on oyun_yonetim.cihaz_yasak(kaynak_user);
alter table oyun_yonetim.cihaz_yasak enable row level security;
revoke all on oyun_yonetim.cihaz_yasak from public, anon, authenticated;
revoke all on sequence oyun_yonetim.cihaz_yasak_id_seq from public, anon, authenticated;

-- Yasaklı cihazdan gelen giriş/başvuru denemeleri (hesap + cihaz başına tek satır)
create table if not exists oyun_yonetim.cihaz_yasak_deneme (
  id bigserial primary key,
  user_id uuid not null,
  cihaz text not null,
  ilk timestamptz not null default clock_timestamp(),
  son timestamptz not null default clock_timestamp(),
  sayi integer not null default 1,
  constraint cihaz_yasak_deneme_tek unique (user_id, cihaz)
);
create index if not exists cihaz_yasak_deneme_son_ix on oyun_yonetim.cihaz_yasak_deneme(son desc);
create index if not exists cihaz_yasak_deneme_cihaz_ix on oyun_yonetim.cihaz_yasak_deneme(cihaz);
alter table oyun_yonetim.cihaz_yasak_deneme enable row level security;
revoke all on oyun_yonetim.cihaz_yasak_deneme from public, anon, authenticated;
revoke all on sequence oyun_yonetim.cihaz_yasak_deneme_id_seq from public, anon, authenticated;

-- "Son kullandığı cihaz" sorgusu her durum() çağrısında çalışır: tek satırlık dizin taraması olsun
create index if not exists oturum_user_son on oyun.oturumlar(user_id, son desc);

-- ---------------------------------------------------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------------------------------------------------
-- Hesabını kendi silen oyuncu yönetim engellisi değildir; cihazı yasaklanmaz, yeniden kayıt olabilir.
create or replace function oyun.cihaz_kendi_silme(p_neden text, p_kad text) returns boolean
language sql immutable set search_path to '' as $f$
  select coalesce(p_neden = 'Hesap sahibi tarafından silindi', false) or coalesce(p_kad like 'Silinmis\_%', false)
$f$;

-- Muaf: kurucu ve "ayrı kişi" olduğu yönetimce onaylanmış hesap
create or replace function oyun.cihaz_yasak_muaf(u uuid) returns boolean
language sql stable set search_path to '' as $f$
  select exists (select 1 from oyun.yonetici_kimlik k where k.user_id = u)
      or exists (select 1 from oyun.profiller p where p.id = u and p.yonetici)
      or exists (select 1 from oyun.hesap_onay h where h.user_id = u)
$f$;

create or replace function oyun.cihaz_yasak_mesaji() returns text
language sql stable set search_path to '' as $f$
  select 'Bu cihazın oyuna erişimi, kural ihlali nedeniyle oyun yönetimi tarafından kapatılmıştır. Bu cihazdan giriş yapılamaz ve yeni hesap açılamaz. Bir yanlışlık olduğunu düşünüyorsan yaz: ' || oyun.iletisim()
$f$;

-- Hesabın yasaklı cihazı var mı? p_son: yalnız son kullandığı cihaza bak (hesabı olan oyuncu); değilse görüldüğü
-- bütün cihazlara (yeni başvuru). Dönen: yasak kaydının no'su ya da null.
create or replace function oyun.cihaz_yasak_bul(u uuid, p_son boolean) returns bigint
language plpgsql stable set search_path to '' as $f$
declare c text; v bigint;
begin
  if p_son then
    select o.cihaz into c from oyun.oturumlar o where o.user_id = u and o.cihaz is not null order by o.son desc limit 1;
    if c is null then return null; end if;
    select y.id into v from oyun_yonetim.cihaz_yasak y where y.cihaz = c and y.aktif;
  else
    select y.id into v from oyun.oturumlar o join oyun_yonetim.cihaz_yasak y on y.cihaz = o.cihaz and y.aktif
     where o.user_id = u limit 1;
  end if;
  return v;
end $f$;

-- Giriş kapısı (durum): yasaklı cihazdaysa reddeder
create or replace function oyun.cihaz_yasak_kapi(u uuid, p_profil boolean) returns void
language plpgsql stable set search_path to '' as $f$
begin
  if oyun.cihaz_yasak_bul(u, p_profil) is null then return; end if;
  if oyun.cihaz_yasak_muaf(u) then return; end if;
  raise exception '%', oyun.cihaz_yasak_mesaji();
end $f$;

-- Başvuru kapısı (kayit_basvuru_gonder, profil_olustur)
create or replace function oyun.cihaz_basvuru_kapi(u uuid) returns void
language plpgsql stable set search_path to '' as $f$
declare a oyun.ayarlar; n integer;
begin
  if oyun.cihaz_yasak_muaf(u) then return; end if;
  select * into a from oyun.ayarlar where id = 1;
  -- 1) Cihaz doğrulaması: uygulama başvurudan hemen önce oturum_kaydet çağırır
  if coalesce(a.cihaz_zorunlu, false) and not exists (select 1 from oyun.oturumlar o where o.user_id = u) then
    raise exception 'Cihaz doğrulaması yapılamadı. Uygulamayı tamamen kapatıp yeniden aç ve tekrar dene.';
  end if;
  -- 2) Yasaklı cihaz (hesabın görüldüğü herhangi bir cihaz)
  if oyun.cihaz_yasak_bul(u, false) is not null then raise exception '%', oyun.cihaz_yasak_mesaji(); end if;
  if not coalesce(a.coklu_kontrol, true) then return; end if;
  -- 3) Aynı cihazda yönetimce engellenmiş ya da uzaklaştırılmış hesap varken yeni hesap açılamaz
  if exists (select 1 from oyun.oturumlar o1
               join oyun.oturumlar o2 on o2.cihaz = o1.cihaz and o2.user_id <> o1.user_id
               join oyun.profiller p on p.id = o2.user_id
              where o1.user_id = u and o1.cihaz is not null and o1.cihaz is distinct from o1.iz
                and p.yasakli and (p.engel_bitis is null or p.engel_bitis > oyun.simdi())
                and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad)) then
    raise exception 'Bu cihazdaki bir hesap oyun yönetimi tarafından engellenmiş ya da uzaklaştırılmış durumda. Engel sürerken bu cihazdan yeni hesap açılamaz. İtiraz için: %', oyun.iletisim();
  end if;
  -- 4) Cihaz başına hesap sınırı (profil_guvenlik_tg ile aynı ölçü; moderatörün önüne hiç gelmesin)
  select count(distinct b) into n from oyun.bagli_hesaplar(u) b;
  if n >= coalesce(a.cihaz_max_hesap, 2) then
    raise exception 'Bu cihazda en fazla % oyuncu hesabı açılabilir. Bir insan yalnızca bir vatandaş olabilir. Aynı cihazı aile içinde paylaşıyorsanız oyun yönetimine yazın: %', coalesce(a.cihaz_max_hesap, 2), oyun.iletisim();
  end if;
end $f$;

-- Kayıt masası uyarıları: {guclu, ozet, satirlar:[{seviye: guclu|zayif|bilgi, metin}]}
create or replace function oyun.cihaz_basvuru_uyari(h uuid) returns jsonb
language plpgsql stable set search_path to '' as $f$
declare t timestamptz := oyun.simdi(); s jsonb := '[]'::jsonb; g boolean := false; oz text; v text; d text[]; gorulen text[] := '{}';
begin
  if not exists (select 1 from oyun.oturumlar o where o.user_id = h) then
    return jsonb_build_object('guclu', false, 'ozet', null, 'satirlar', jsonb_build_array(jsonb_build_object('seviye', 'bilgi',
      'metin', 'Bu başvuru için cihaz bilgisi yok (cihaz kaydı açılmadan önce yapılmış ya da bağlantı sorunu olmuş olabilir).')));
  end if;
  -- Yasaklı cihaz
  select coalesce(y.kaynak_kad, '—') into v from oyun.oturumlar o join oyun_yonetim.cihaz_yasak y on y.cihaz = o.cihaz and y.aktif
   where o.user_id = h limit 1;
  if v is not null then
    g := true; oz := format('yasaklı cihaz (engellenen hesap: %s)', v);
    s := s || jsonb_build_object('seviye', 'guclu', 'metin', format('Yasaklı cihaz: bu telefon ya da tarayıcı, engellenen «%s» hesabı yüzünden yasak listesinde.', v));
  end if;
  -- Aynı cihazda engelli / uzaklaştırılmış hesap
  select string_agg(distinct p.kad, ', '), array_agg(distinct p.kad) into v, d
    from oyun.oturumlar a join oyun.oturumlar b on b.cihaz = a.cihaz and b.user_id <> a.user_id
    join oyun.profiller p on p.id = b.user_id
   where a.user_id = h and a.cihaz is not null and a.cihaz is distinct from a.iz
     and p.yasakli and (p.engel_bitis is null or p.engel_bitis > t) and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad);
  gorulen := gorulen || coalesce(d, '{}');
  if v is not null then
    g := true; oz := coalesce(oz, format('aynı cihazda engelli hesap: %s', v));
    s := s || jsonb_build_object('seviye', 'guclu', 'metin', format('Aynı cihaz: engellenmiş ya da uzaklaştırılmış «%s» ile aynı telefondan / tarayıcıdan geliyor.', v));
  end if;
  -- Aynı bağlantı + aynı cihaz izi (telefon değiştirme, uygulamayı silip kurma, gizli sekme)
  select string_agg(distinct p.kad, ', '), array_agg(distinct p.kad) into v, d
    from oyun.oturumlar a join oyun.oturumlar b on b.ip = a.ip and b.iz = a.iz and b.user_id <> a.user_id
    join oyun.profiller p on p.id = b.user_id
   where a.user_id = h and a.ip is not null and a.iz is not null and greatest(a.son, b.son) > t - interval '60 days'
     and p.yasakli and (p.engel_bitis is null or p.engel_bitis > t) and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad)
     and not (p.kad = any(gorulen));
  gorulen := gorulen || coalesce(d, '{}');
  if v is not null then
    g := true; oz := coalesce(oz, format('engelli «%s» ile aynı bağlantı ve aynı cihaz modeli', v));
    s := s || jsonb_build_object('seviye', 'guclu', 'metin', format('Aynı bağlantı ve aynı cihaz modeli: engellenmiş «%s» ile aynı internet bağlantısından, aynı model ve ayardaki bir cihazdan geliyor. Büyük olasılıkla aynı kişi.', v));
  end if;
  -- Bu cihazdaki diğer (engelsiz) hesaplar
  select string_agg(distinct p.kad, ', ') into v
    from oyun.oturumlar a join oyun.oturumlar b on b.cihaz = a.cihaz and b.user_id <> a.user_id
    join oyun.profiller p on p.id = b.user_id
   where a.user_id = h and a.cihaz is not null and a.cihaz is distinct from a.iz
     and not (p.yasakli and (p.engel_bitis is null or p.engel_bitis > t)) and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad);
  if v is not null then
    s := s || jsonb_build_object('seviye', 'zayif', 'metin', format('Bu cihazda başka hesap var: %s. Aynı kişinin ikinci hesabı olabilir.', v));
  end if;
  -- Yalnız aynı bağlantı (zayıf): son 30 gün
  select string_agg(distinct p.kad, ', ') into v
    from oyun.oturumlar a join oyun.oturumlar b on b.ip = a.ip and b.user_id <> a.user_id
    join oyun.profiller p on p.id = b.user_id
   where a.user_id = h and a.ip is not null and greatest(a.son, b.son) > t - interval '30 days'
     and p.yasakli and (p.engel_bitis is null or p.engel_bitis > t) and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad)
     and not (p.kad = any(gorulen));
  if v is not null then
    s := s || jsonb_build_object('seviye', 'zayif', 'metin', format('Aynı internet bağlantısı: engellenmiş «%s» ile aynı bağlantıdan giriş yapılmış. Zayıf işaret; aile, okul ya da mobil operatör paylaşımı olabilir.', v));
  end if;
  return jsonb_build_object('guclu', g, 'ozet', oz, 'satirlar', s);
end $f$;

-- Onay kapısı (admin_kayit_karar2): yasaklı cihazdan gelen başvuru onaylanamaz; güçlü uyarı görülmeden onaylanamaz.
-- Kurucuya kısıt yoktur.
create or replace function oyun.cihaz_onay_kapi(p oyun.profiller, h uuid) returns void
language plpgsql stable set search_path to '' as $f$
declare v text; w jsonb;
begin
  if coalesce(p.yonetici, false) or oyun.cihaz_yasak_muaf(h) then return; end if;
  select coalesce(y.kaynak_kad, '—') into v from oyun.oturumlar o join oyun_yonetim.cihaz_yasak y on y.cihaz = o.cihaz and y.aktif
   where o.user_id = h limit 1;
  if v is not null then
    raise exception 'Bu başvuru yasaklı bir cihazdan yapılmış (engellenen hesap: %). Onaylanamaz; reddet. Yanlışlık olduğunu düşünüyorsan kurucuya ilet.', v;
  end if;
  if coalesce(current_setting('oyun.cihaz_uyari_goruldu', true), '') = 'evet' then return; end if;
  w := oyun.cihaz_basvuru_uyari(h);
  if coalesce((w ->> 'guclu')::boolean, false) then
    raise exception 'Mükerrer hesap uyarısı: %. Bu başvuruyu reddedebilirsin. Onaylamak istiyorsan oyunun web sürümünden ya da güncel uygulamadan Kayıt masasını aç; uyarı ayrıntısını görüp öyle onayla.', w ->> 'ozet';
  end if;
end $f$;

-- Bir hesabın görüldüğü cihazları yasak listesine alır. p_yeniden: daha önce elle kaldırılmış yasağı da yeniden açar
-- (yalnız yeni bir kalıcı engel kararında). Dönen: listeye giren cihaz sayısı.
create or replace function oyun.cihaz_yasakla(h uuid, p_neden text, p_ekleyen uuid, p_yeniden boolean default true) returns integer
language plpgsql set search_path to '' as $f$
declare r record; n integer := 0; v_atlanan integer := 0; v_kad text; v_diger text; t timestamptz := oyun.simdi(); v_ekle boolean;
begin
  select p.kad into v_kad from oyun.profiller p where p.id = h;
  for r in select o.cihaz, (select count(distinct x.user_id) from oyun.oturumlar x where x.cihaz = o.cihaz) as hesap
             from oyun.oturumlar o
            where o.user_id = h and o.cihaz is not null and o.cihaz is distinct from o.iz
            group by o.cihaz
  loop
    if r.hesap > 5 then v_atlanan := v_atlanan + 1; continue; end if;
    v_ekle := false;
    if p_yeniden then
      insert into oyun_yonetim.cihaz_yasak as y (cihaz, kaynak_user, kaynak_kad, neden, ekleyen, zaman, aktif)
      values (r.cihaz, h, v_kad, left(p_neden, 300), p_ekleyen, t, true)
      on conflict (cihaz) do update
         set aktif = true, kaynak_user = excluded.kaynak_user, kaynak_kad = excluded.kaynak_kad, neden = excluded.neden,
             ekleyen = excluded.ekleyen, zaman = excluded.zaman, kaldiran = null, kaldirma_zaman = null, kaldirma_not = null
       where not y.aktif
      returning true into v_ekle;
    else
      insert into oyun_yonetim.cihaz_yasak (cihaz, kaynak_user, kaynak_kad, neden, ekleyen, zaman, aktif)
      values (r.cihaz, h, v_kad, left(p_neden, 300), p_ekleyen, t, true)
      on conflict (cihaz) do nothing
      returning true into v_ekle;
    end if;
    if coalesce(v_ekle, false) then n := n + 1; end if;
  end loop;
  if n > 0 or v_atlanan > 0 then
    select string_agg(distinct p.kad, ', ') into v_diger
      from oyun.oturumlar a join oyun.oturumlar b on b.cihaz = a.cihaz and b.user_id <> a.user_id
      join oyun.profiller p on p.id = b.user_id
     where a.user_id = h and a.cihaz is not null and a.cihaz is distinct from a.iz and not p.yasakli;
    if v_diger is not null or v_atlanan > 0 then
      perform oyun.mod_kurucu_bildir(format('Cihaz yasağı: %s kalıcı engellendi, %s cihazı yasak listesine alındı.%s%s',
        coalesce(v_kad, '—'), n,
        coalesce(format(' Aynı cihazda görülen engelsiz hesaplar: %s. Bu hesaplar da o cihazdan giremez; ayrı kişilerse Çoklu hesap ekranından onayla, aynı kişiyse engelle.', v_diger), ''),
        case when v_atlanan > 0 then format(' %s cihaz kimliği 5''ten çok hesapta görüldüğü için kendiliğinden yasaklanmadı; elle incele.', v_atlanan) else '' end), t);
    end if;
  end if;
  return n;
end $f$;

-- Hesabın engeli kalkınca / süreliye çevrilince o hesaptan gelen cihaz yasağını bırakır. Aynı cihazda başka kalıcı
-- engelli varsa yasak ona devredilir.
create or replace function oyun.cihaz_yasak_birak(h uuid, p_kaldiran uuid) returns integer
language plpgsql set search_path to '' as $f$
declare r record; d record; n integer := 0; t timestamptz := oyun.simdi();
begin
  for r in select y.id, y.cihaz from oyun_yonetim.cihaz_yasak y where y.kaynak_user = h and y.aktif for update loop
    select p.id, p.kad, p.engel_neden into d
      from oyun.oturumlar o join oyun.profiller p on p.id = o.user_id
     where o.cihaz = r.cihaz and p.id <> h and p.yasakli and p.engel_bitis is null and not coalesce(p.yonetici, false)
       and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad)
     order by p.olusturma limit 1;
    if d.id is not null then
      update oyun_yonetim.cihaz_yasak set kaynak_user = d.id, kaynak_kad = d.kad, neden = left(d.engel_neden, 300) where id = r.id;
    else
      update oyun_yonetim.cihaz_yasak
         set aktif = false, kaldiran = p_kaldiran, kaldirma_zaman = t, kaldirma_not = 'Hesabın kalıcı engeli kalktı.'
       where id = r.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end $f$;

-- Engel durumu değişince işlem sonunda (commit) bir kez değerlendirilir: yk_engelle yasakli ve engel_bitis'i iki ayrı
-- UPDATE ile yazar; ara durumda karar verilmez. Hata engelleme işlemini durdurmaz.
create or replace function oyun.cihaz_yasak_profil_tg() returns trigger
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller;
begin
  begin
    select * into p from oyun.profiller where id = new.id;
    if p.id is null or coalesce(p.yonetici, false) or oyun.cihaz_kendi_silme(p.engel_neden, p.kad) then return null; end if;
    if p.yasakli and p.engel_bitis is null then
      -- Yeniden açma yalnız gerçek geçişte: bu satır değişikliğinden önce kalıcı engelli değildi
      perform oyun.cihaz_yasakla(p.id, p.engel_neden, auth.uid(), not (coalesce(old.yasakli, false) and old.engel_bitis is null));
    else
      perform oyun.cihaz_yasak_birak(p.id, auth.uid());
    end if;
  exception when others then
    raise warning 'cihaz_yasak_profil_tg: %', sqlerrm;
  end;
  return null;
end $f$;

drop trigger if exists cihaz_yasak_profil on oyun.profiller;
create constraint trigger cihaz_yasak_profil
  after update of yasakli, engel_bitis, engel_neden on oyun.profiller
  deferrable initially deferred
  for each row execute function oyun.cihaz_yasak_profil_tg();

revoke all on function oyun.cihaz_kendi_silme(text, text) from public;
revoke all on function oyun.cihaz_yasak_muaf(uuid) from public;
revoke all on function oyun.cihaz_yasak_mesaji() from public;
revoke all on function oyun.cihaz_yasak_bul(uuid, boolean) from public;
revoke all on function oyun.cihaz_yasak_kapi(uuid, boolean) from public;
revoke all on function oyun.cihaz_basvuru_kapi(uuid) from public;
revoke all on function oyun.cihaz_basvuru_uyari(uuid) from public;
revoke all on function oyun.cihaz_onay_kapi(oyun.profiller, uuid) from public;
revoke all on function oyun.cihaz_yasakla(uuid, text, uuid, boolean) from public;
revoke all on function oyun.cihaz_yasak_birak(uuid, uuid) from public;
revoke all on function oyun.cihaz_yasak_profil_tg() from public;

-- ---------------------------------------------------------------------------------------------------------------
-- Oturum kaydı: onay bekleyen hesabın cihazı da kaydedilir; yasaklı cihaz denemesi kayda geçer
-- ---------------------------------------------------------------------------------------------------------------
create or replace function public.oturum_kaydet(p_cihaz text, p_iz text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); c text := oyun.ozet(left(p_cihaz, 200)); z text := oyun.ozet(left(p_iz, 200));
        i text := oyun.ozet(oyun.istek_ip()); y oyun_yonetim.cihaz_yasak; v_sayi integer; v_kad text;
begin
  -- 23.11.2026: oyun.ben() yerine auth.uid(). ben() kayıt onayı bekleyen/reddedilen hesabı reddediyordu; cihaz
  -- başvuru aşamasında kaydedilmediği için engellenen kişi yeni hesabıyla tanınmıyordu.
  if u is null then raise exception 'Giriş yapmalısın.'; end if;
  if c is null and z is null then raise exception 'Cihaz bilgisi alınamadı.'; end if;
  -- Hesap başına satır tavanı (uydurma kimliklerle tablo şişirilemesin): en eski satırlar atılır
  if (select count(*) from oyun.oturumlar o where o.user_id = u) >= 1500 then
    delete from oyun.oturumlar o where o.id in (select x.id from oyun.oturumlar x where x.user_id = u order by x.son limit 200);
  end if;
  insert into oyun.oturumlar(user_id, cihaz, iz, ip, ilk, son) values (u, c, z, i, t, t)
  on conflict (user_id, cihaz, iz, ip) do update set son = excluded.son, sayi = oyun.oturumlar.sayi + 1;
  -- Cihaz yasağı (cihaz izi yedeği kimlik sayılmaz: aynı model telefonlarda aynıdır)
  if c is not null and c is distinct from z then
    select * into y from oyun_yonetim.cihaz_yasak where cihaz = c and aktif;
    if y.id is not null and not oyun.cihaz_yasak_muaf(u) then
      insert into oyun_yonetim.cihaz_yasak_deneme as d (user_id, cihaz, ilk, son, sayi) values (u, c, t, t, 1)
      on conflict (user_id, cihaz) do update set son = excluded.son, sayi = d.sayi + 1
      returning d.sayi into v_sayi;
      if v_sayi = 1 and u is distinct from y.kaynak_user
         and not exists (select 1 from oyun.profiller p where p.id = u and p.yasakli) then
        v_kad := coalesce((select p.kad from oyun.profiller p where p.id = u),
                          (select b.kad from oyun_yonetim.kayit_basvurulari b where b.user_id = u));
        perform oyun.mod_kurucu_bildir(format('Cihaz yasağı: yasaklı bir cihazdan giriş denemesi engellendi. Deneyen hesap: %s. Cihazın yasaklanma sebebi: engellenen %s hesabı. Ayrıntı: Moderasyon Merkezi › Yasaklı cihazlar.',
          coalesce(v_kad, 'yeni hesap (henüz başvurusu yok)'), coalesce(y.kaynak_kad, '—')), t);
      end if;
      return jsonb_build_object('tamam', true, 'cihaz_yasak', true);
    end if;
  end if;
  return jsonb_build_object('tamam', true);
end $f$;
revoke all on function public.oturum_kaydet(text, text) from public, anon;
grant execute on function public.oturum_kaydet(text, text) to authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- Kapılar (işaretli yamalar: /* cihaz_yasak */)
-- ---------------------------------------------------------------------------------------------------------------
-- Giriş: engelli hesap kendi engel mesajını görmeye devam eder; diğer herkes için cihaz kapısı.
-- Hesabı olan oyuncuda son kullandığı cihaza, hesabı olmayanda (başvuru) görüldüğü bütün cihazlara bakılır.
select oyun._yama('public.durum()',
  $d$select * into p from oyun.profiller where id = u;$d$,
  $y$select * into p from oyun.profiller where id = u;
  /* cihaz_yasak */ if p.id is null or not coalesce(p.yasakli, false) then perform oyun.cihaz_yasak_kapi(u, p.id is not null); end if;$y$,
  '/* cihaz_yasak */', true);

select oyun._yama('public.kayit_basvuru_gonder(text,integer,text)',
  $d$if u is null then raise exception 'Önce giriş yap.'; end if;$d$,
  $y$if u is null then raise exception 'Önce giriş yap.'; end if;
  /* cihaz_yasak */ perform oyun.cihaz_basvuru_kapi(u);$y$,
  '/* cihaz_yasak */', true);

select oyun._yama('public.profil_olustur(text,integer)',
  $d$raise exception 'Profilin zaten var.'; end if;$d$,
  $y$raise exception 'Profilin zaten var.'; end if;
  /* cihaz_yasak */ perform oyun.cihaz_basvuru_kapi(u);$y$,
  '/* cihaz_yasak */', true);

select oyun._yama('public.admin_kayit_karar2(uuid,boolean,text)',
  $d$if exists(select 1 from oyun.profiller where lower(kad)=lower(b.kad) and id<>b.user_id) then raise exception 'Bu kullanıcı adı artık kullanımda.'; end if;$d$,
  $y$/* cihaz_yasak */ perform oyun.cihaz_onay_kapi(p, b.user_id);
    if exists(select 1 from oyun.profiller where lower(kad)=lower(b.kad) and id<>b.user_id) then raise exception 'Bu kullanıcı adı artık kullanımda.'; end if;$y$,
  '/* cihaz_yasak */', true);

select oyun._yama('public.admin_kayit_basvurulari()',
  $d$'uyari',case when b.durum='beklemede' then oyun_yonetim.isim_uyari(b.ad_soyad) end,$d$,
  $y$'uyari',case when b.durum='beklemede' then oyun_yonetim.isim_uyari(b.ad_soyad) end,
      /* cihaz_yasak */ 'cihaz_uyari',case when b.durum='beklemede' then oyun.cihaz_basvuru_uyari(b.user_id) end,$y$,
  '/* cihaz_yasak */', true);

-- ---------------------------------------------------------------------------------------------------------------
-- Moderasyon RPC'leri
-- ---------------------------------------------------------------------------------------------------------------
-- Kayıt kararı (yeni istemci): güçlü cihaz uyarısını gördüğünü bildirerek onaylar. Eski admin_kayit_karar2 aynen çalışır;
-- yalnız güçlü uyarılı başvuruyu onaylayamaz (reddedebilir).
create or replace function public.mod_kayit_karar(p_user uuid, p_onay boolean, p_neden text default null, p_uyari_goruldu boolean default false)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller := oyun_yonetim.kayit_yetkili();
begin
  perform set_config('oyun.cihaz_uyari_goruldu', case when coalesce(p_uyari_goruldu, false) then 'evet' else '' end, true);
  return public.admin_kayit_karar2(p_user, p_onay, p_neden);
end $f$;

create or replace function oyun.cihaz_yasak_liste(p oyun.profiller) returns jsonb
language sql stable set search_path to '' as $f$
  select jsonb_build_object(
    'kaldirabilir', coalesce(p.yonetici, false) or exists (select 1 from oyun.moderatorler m where m.user_id = p.id and 'coklu_hesap' = any(m.yetkiler)),
    'aktif', coalesce((select jsonb_agg(z.k order by z.zaman desc) from (
        select y.zaman, jsonb_build_object('id', y.id, 'kaynak', y.kaynak_kad, 'neden', y.neden, 'zaman', y.zaman, 'ekleyen', oyun.kad(y.ekleyen),
          'hesaplar', coalesce((select jsonb_agg(jsonb_build_object('kad', x.kad, 'yasakli', x.yasakli, 'muaf', oyun.cihaz_yasak_muaf(x.id)) order by x.olusturma)
                                  from oyun.profiller x where x.id in (select o.user_id from oyun.oturumlar o where o.cihaz = y.cihaz)), '[]'::jsonb),
          'deneme', (select jsonb_build_object('hesap', count(*), 'toplam', coalesce(sum(d.sayi), 0), 'son', max(d.son))
                       from oyun_yonetim.cihaz_yasak_deneme d where d.cihaz = y.cihaz and d.user_id is distinct from y.kaynak_user)) as k
          from oyun_yonetim.cihaz_yasak y where y.aktif order by y.zaman desc limit 200) z), '[]'::jsonb),
    'kaldirilan', coalesce((select jsonb_agg(z.k order by z.kaldirma_zaman desc nulls last) from (
        select y.kaldirma_zaman, jsonb_build_object('id', y.id, 'kaynak', y.kaynak_kad, 'neden', y.neden, 'zaman', y.zaman,
          'kaldiran', oyun.kad(y.kaldiran), 'kaldirma_zaman', y.kaldirma_zaman, 'kaldirma_not', y.kaldirma_not) as k
          from oyun_yonetim.cihaz_yasak y where not y.aktif order by y.kaldirma_zaman desc nulls last limit 30) z), '[]'::jsonb),
    'denemeler', coalesce((select jsonb_agg(z.k order by z.son desc) from (
        select d.son, jsonb_build_object('kad', coalesce(pr.kad, b.kad), 'hesap_var', pr.id is not null, 'basvuru', b.durum,
          'ilk', d.ilk, 'son', d.son, 'sayi', d.sayi, 'kaynak', y.kaynak_kad) as k
          from oyun_yonetim.cihaz_yasak_deneme d
          left join oyun.profiller pr on pr.id = d.user_id
          left join oyun_yonetim.kayit_basvurulari b on b.user_id = d.user_id
          left join oyun_yonetim.cihaz_yasak y on y.cihaz = d.cihaz
         where d.user_id is distinct from y.kaynak_user
         order by d.son desc limit 50) z), '[]'::jsonb))
$f$;
revoke all on function oyun.cihaz_yasak_liste(oyun.profiller) from public;

-- Yasaklı cihazlar ekranı (engelleme yetkisi olan her yönetici görür)
create or replace function public.mod_cihaz_yasaklari() returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('hesap_kapat');
begin
  return oyun.cihaz_yasak_liste(p);
end $f$;

-- Yasağı kaldır / yeniden aç: kurucu ve Çoklu hesap yetkilisi (Oyuncu Masası). Gerekçe zorunlu, kayda geçer.
create or replace function public.mod_cihaz_yasak_ayarla(p_id bigint, p_aktif boolean, p_not text default null) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('coklu_hesap'); y oyun_yonetim.cihaz_yasak; t timestamptz := oyun.simdi();
        n text := left(btrim(coalesce(p_not, '')), 300); v_ac boolean := coalesce(p_aktif, false);
begin
  select * into y from oyun_yonetim.cihaz_yasak where id = p_id for update;
  if y.id is null then raise exception 'Cihaz yasağı kaydı bulunamadı.'; end if;
  if y.aktif = v_ac then
    raise exception '%', case when v_ac then 'Bu cihaz zaten yasaklı.' else 'Bu cihazın yasağı zaten kaldırılmış.' end;
  end if;
  if char_length(n) < 10 then raise exception 'En az 10 karakterlik gerekçe yaz.'; end if;
  if not coalesce(p.yonetici, false) and exists (select 1 from oyun.oturumlar o where o.user_id = p.id and o.cihaz = y.cihaz) then
    raise exception 'Çıkar çatışması: bu cihazı sen de kullanmışsın. Kararı başka bir yönetici vermeli.';
  end if;
  if v_ac then
    update oyun_yonetim.cihaz_yasak set aktif = true, ekleyen = p.id, zaman = t, kaldiran = null, kaldirma_zaman = null, kaldirma_not = null where id = y.id;
  else
    update oyun_yonetim.cihaz_yasak set aktif = false, kaldiran = p.id, kaldirma_zaman = t, kaldirma_not = n where id = y.id;
  end if;
  perform oyun.mod_log(p, case when v_ac then 'cihaz_yasak_ac' else 'cihaz_yasak_kaldir' end, y.kaynak_kad, n);
  if not coalesce(p.yonetici, false) then
    perform oyun.mod_kurucu_bildir(format('Moderasyon: %s, engellenen %s hesabından gelen cihaz yasağını %s. Gerekçe: %s',
      p.kad, coalesce(y.kaynak_kad, '—'), case when v_ac then 'yeniden açtı' else 'kaldırdı' end, n), t);
  end if;
  return oyun.cihaz_yasak_liste(p);
end $f$;

revoke all on function public.mod_kayit_karar(uuid, boolean, text, boolean) from public, anon;
grant execute on function public.mod_kayit_karar(uuid, boolean, text, boolean) to authenticated;
revoke all on function public.mod_cihaz_yasaklari() from public, anon;
grant execute on function public.mod_cihaz_yasaklari() to authenticated;
revoke all on function public.mod_cihaz_yasak_ayarla(bigint, boolean, text) from public, anon;
grant execute on function public.mod_cihaz_yasak_ayarla(bigint, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- İlk kurulum: hâlen kalıcı engelli olan hesapların cihazları (elle kaldırılmış yasak yeniden açılmaz)
-- ---------------------------------------------------------------------------------------------------------------
select oyun.cihaz_yasakla(p.id, p.engel_neden, null, false)
  from oyun.profiller p
 where p.yasakli and p.engel_bitis is null and not coalesce(p.yonetici, false)
   and not oyun.cihaz_kendi_silme(p.engel_neden, p.kad);
