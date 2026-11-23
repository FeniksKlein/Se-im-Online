-- 24.11.2026 · GENEL KURUL: SÖZ HAKKI VE KONUŞMA SINIRI (sürüm 2026.11.24-1)
-- İstek (Ercan): "Gerçek Mecliste söz alan vekillerin konuşma süresi olduğu gibi burada da karakter sınırı olsun;
-- söz hakkını Meclis Başkanı versin."
-- Gerçek karşılığı (TBMM İçtüzüğü m.60-61): söz Başkandan istenir, Başkan istem sırasına göre verir;
-- kişisel konuşma 10 dk, siyasi parti grubu ve hükümet adına 20 dk, yerinden kısa açıklama çok kısa.
-- Oyunda süre = karakter sınırı; bir söz = Genel Kurul'da tek mesaj.
--   Şahsı adına 800 · Grup adına 1500 · Hükümet adına 1500 · Yerinden kısa söz 250 · Başkanlık (oturumu yöneten) 600 karakter.
-- Kurallar:
--   · Milletvekili, bakan, Cumhurbaşkanı söz ister; Meclis Başkanı ya da başkanvekili sıradan söz verir.
--   · Söz verilince 15 dakika içinde tek mesaj yazılır; kullanılmazsa düşer.
--   · Yayın ölçeği güvencesi (tek yetkilinin yokluğu hakkı durdurmaz): Başkanlık çevrimiçi değilse söz hemen,
--     çevrimiçi ama işlem yapmıyorsa 5 dakika sonra kendiliğinden verilmiş sayılır.
--   · Konuşmadan sonra 2 dakika yeni söz istenemez (kürsü işgali olmasın). Başkan bekleyen istemi gerekçeyle reddedebilir;
--     aynı vekilin sonraki istemi otomatik kuralla yine işler (Başkan bir vekili süresiz susturamaz; onun yolu ihtar).
--   · Meclis Başkanı ve başkanvekilleri oturumu yönetirken söz istemeden yazar (600 karakter).
--   · Mağazadaki eski uygulama: Başkanlık çevrimiçi değilken yazılan mesaj "şahsı adına" söz sayılır (800 karakter);
--     Başkanlık çevrimiçiyken söz istemek için güncel uygulama ya da web gerekir.

create table if not exists oyun.meclis_soz (
  id bigserial primary key,
  user_id uuid not null,
  tur text not null check (tur in ('kisisel', 'grup', 'hukumet', 'yerinden')),
  istek timestamptz not null,
  otomatik timestamptz not null,           -- bu andan sonra kendiliğinden verilmiş sayılır
  veren uuid, verildi timestamptz,
  kullanildi timestamptz,
  durum text not null default 'bekliyor' check (durum in ('bekliyor', 'verildi', 'kullanildi', 'geri', 'ret'))
);
create index if not exists meclis_soz_acik on oyun.meclis_soz (istek) where durum in ('bekliyor', 'verildi');
create index if not exists meclis_soz_kisi on oyun.meclis_soz (user_id, id desc);
alter table oyun.meclis_soz enable row level security;
revoke all on oyun.meclis_soz from public, anon, authenticated;

create or replace function oyun.meclis_soz_tur() returns table(kod text, ad text, sinir int, sira int)
language sql immutable set search_path to '' as $f$
  values ('kisisel', 'Şahsı adına', 800, 1), ('grup', 'Grup adına', 1500, 2), ('hukumet', 'Hükümet adına', 1500, 3), ('yerinden', 'Yerinden kısa söz', 250, 4)
$f$;

-- Oturumu yönetenler: Meclis Başkanı ve başkanvekilleri
create or replace function oyun.meclis_baskanlik_mi(u uuid) returns boolean
language sql stable set search_path to '' as $f$
  select exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur in ('tbmm', 'bskv'))
$f$;

create or replace function oyun.meclis_baskanlik_cevrimici(t timestamptz) returns boolean
language sql stable set search_path to '' as $f$
  select exists (select 1 from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
                  where m.bit is null and m.tur in ('tbmm', 'bskv') and not pr.yasakli and pr.son_gorulme > t - interval '5 minutes')
$f$;

-- Oyuncunun isteyebileceği söz türleri
create or replace function oyun.meclis_soz_turlerim(u uuid) returns text[]
language sql stable set search_path to '' as $f$
  select array_remove(array[
    case when exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur = 'mv') then 'kisisel' end,
    case when exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur = 'grup_bskv')
           or (exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur = 'mv')
               and exists (select 1 from oyun.partiler pa where pa.gb = u and not pa.kapali)) then 'grup' end,
    case when exists (select 1 from oyun.makamlar m where m.user_id = u and m.bit is null and m.tur in ('cb', 'bakan', 'cb_yardimcisi'))
           or exists (select 1 from oyun.hukumetler h where h.basbakan = u and h.durum = 'gorevde' and h.bit is null) then 'hukumet' end,
    'yerinden'], null)
$f$;

-- Kullanılabilir (verilmiş ya da kendiliğinden verilmiş sayılan, süresi dolmamış) söz
create or replace function oyun.meclis_soz_gecerli(u uuid, t timestamptz) returns oyun.meclis_soz
language sql stable set search_path to '' as $f$
  select s from oyun.meclis_soz s
   where s.user_id = u and ((s.durum = 'verildi' and s.verildi > t - interval '15 minutes')
                         or (s.durum = 'bekliyor' and s.otomatik <= t and s.otomatik > t - interval '15 minutes'))
   order by s.id desc limit 1
$f$;

revoke all on function oyun.meclis_soz_tur(), oyun.meclis_baskanlik_mi(uuid), oyun.meclis_baskanlik_cevrimici(timestamptz),
  oyun.meclis_soz_turlerim(uuid), oyun.meclis_soz_gecerli(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.meclis_soz_durum() returns jsonb
language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); bsk boolean; s oyun.meclis_soz; b oyun.meclis_soz; son timestamptz;
begin
  bsk := oyun.meclis_baskanlik_mi(p.id);
  s := oyun.meclis_soz_gecerli(p.id, t);
  if s.id is null then
    select * into b from oyun.meclis_soz x where x.user_id = p.id and x.durum = 'bekliyor' and x.otomatik > t order by x.id desc limit 1;
  end if;
  select max(kullanildi) into son from oyun.meclis_soz where user_id = p.id and kullanildi > t - interval '2 minutes';
  return jsonb_build_object(
    'zaman', t, 'yazabilir', oyun.meclis_yazabilir(p.id), 'serbest', coalesce(p.yonetici, false) and not bsk, 'baskanlik', bsk, 'baskanlik_sinir', 600,
    'baskanlik_cevrimici', oyun.meclis_baskanlik_cevrimici(t),
    'turler', (select jsonb_agg(jsonb_build_object('kod', x.kod, 'ad', x.ad, 'sinir', x.sinir) order by x.sira)
                 from oyun.meclis_soz_tur() x where x.kod = any(oyun.meclis_soz_turlerim(p.id))),
    'soz', case when s.id is not null then jsonb_build_object('id', s.id, 'tur', s.tur,
              'ad', (select ad from oyun.meclis_soz_tur() where kod = s.tur), 'sinir', (select sinir from oyun.meclis_soz_tur() where kod = s.tur),
              'bitis', coalesce(s.verildi, s.otomatik) + interval '15 minutes') end,
    'bekleyen', case when b.id is not null then jsonb_build_object('id', b.id, 'tur', b.tur, 'ad', (select ad from oyun.meclis_soz_tur() where kod = b.tur),
              'istek', b.istek, 'otomatik', b.otomatik,
              'sira', (select count(*) from oyun.meclis_soz x where x.durum = 'bekliyor' and x.otomatik > t and x.id <= b.id)) end,
    'bekleme_bitis', case when son is not null then son + interval '2 minutes' end,
    'sira', case when bsk or coalesce(p.yonetici, false) then coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kad', pr.kad, 'parti', pa.kisa, 'renk', pa.renk,
              'tur', x.tur, 'ad', (select ad from oyun.meclis_soz_tur() where kod = x.tur), 'istek', x.istek, 'otomatik', x.otomatik) order by x.id)
            from (select * from oyun.meclis_soz where durum = 'bekliyor' and otomatik > t order by id limit 40) x
            join oyun.profiller pr on pr.id = x.user_id left join oyun.partiler pa on pa.id = pr.parti_id), '[]'::jsonb) end,
    'sira_sayi', (select count(*) from oyun.meclis_soz x where x.durum = 'bekliyor' and x.otomatik > t));
end $f$;

create or replace function public.meclis_soz_iste(p_tur text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); son timestamptz; oto timestamptz;
begin
  if not oyun.meclis_yazabilir(p.id) then raise exception '%', oyun.kanal_yaz_hata('meclis'); end if;
  if oyun.meclis_baskanlik_mi(p.id) then raise exception 'Oturumu yönetiyorsun; söz istemeden yazabilirsin.'; end if;
  if oyun.ihtarli(p.id, t) is not null then
    raise exception 'Meclis Başkanlığından ihtar aldın; % saatine kadar Genel Kurul''da söz alamazsın.', to_char(oyun.ihtarli(p.id, t) at time zone 'Europe/Istanbul', 'HH24:MI');
  end if;
  perform oyun.yazabilir_mi(p, t);
  if p_tur is null or not (p_tur = any(oyun.meclis_soz_turlerim(p.id))) then raise exception 'Bu söz türünü isteyemezsin.'; end if;
  perform pg_advisory_xact_lock(hashtext('meclis_soz'), hashtext(p.id::text));
  if (oyun.meclis_soz_gecerli(p.id, t)).id is not null then raise exception 'Zaten söz hakkın var; konuşmanı yaz.'; end if;
  if exists (select 1 from oyun.meclis_soz where user_id = p.id and durum = 'bekliyor' and otomatik > t) then raise exception 'Zaten söz sırasındasın.'; end if;
  select max(kullanildi) into son from oyun.meclis_soz where user_id = p.id and kullanildi > t - interval '2 minutes';
  if son is not null then
    raise exception 'Az önce konuştun; % saatinden sonra yeniden söz isteyebilirsin.', to_char((son + interval '2 minutes') at time zone 'Europe/Istanbul', 'HH24:MI');
  end if;
  oto := case when oyun.meclis_baskanlik_cevrimici(t) then t + interval '5 minutes' else t end;
  insert into oyun.meclis_soz(user_id, tur, istek, otomatik) values (p.id, p_tur, t, oto);
  return public.meclis_soz_durum();
end $f$;

create or replace function public.meclis_soz_vazgec() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim();
begin
  update oyun.meclis_soz set durum = 'geri' where user_id = p.id and durum in ('bekliyor', 'verildi');
  return public.meclis_soz_durum();
end $f$;

-- Başkanlık: söz ver (p_ver = true) ya da istemi reddet (gerekçe zorunlu)
create or replace function public.meclis_soz_karar(p_id bigint, p_ver boolean, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_soz; g text := btrim(coalesce(p_gerekce, ''));
begin
  if not (oyun.meclis_baskanlik_mi(p.id) or coalesce(p.yonetici, false)) then raise exception 'Söz hakkını yalnız Meclis Başkanı ve başkanvekilleri verir.'; end if;
  select * into s from oyun.meclis_soz where id = p_id for update;
  if s.id is null or s.durum <> 'bekliyor' or s.otomatik <= t then raise exception 'Bu istem artık sırada değil.'; end if;
  if p_ver then
    update oyun.meclis_soz set durum = 'verildi', veren = p.id, verildi = t where id = s.id;
    perform oyun.bildir(s.user_id, format('Meclis Başkanlığı sana söz verdi (%s, en çok %s karakter). 15 dakika içinde Genel Kurul''da konuşmanı yaz.',
      (select ad from oyun.meclis_soz_tur() where kod = s.tur), (select sinir from oyun.meclis_soz_tur() where kod = s.tur)), t);
  else
    if char_length(g) < 5 or char_length(g) > 200 then raise exception 'Ret gerekçesi 5-200 karakter olmalı (vekil görür).'; end if;
    update oyun.meclis_soz set durum = 'ret', veren = p.id, verildi = t where id = s.id;
    perform oyun.bildir(s.user_id, format('Meclis Başkanlığı söz istemini karşılamadı. Gerekçe: %s Yeniden söz isteyebilirsin.', g), t);
  end if;
  return public.meclis_soz_durum();
end $f$;

-- Genel Kurul'da yazma: söz hakkı ve karakter sınırı (diğer kanallar aynen)
create or replace function public.sohbet_yaz(p_kanal text, p_metin text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; m text;
  s oyun.meclis_soz; v_sinir int := 1500; v_ad text; son timestamptz; n int;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  if not oyun.kanal_yazabilir(p, p_kanal) then raise exception '%', oyun.kanal_yaz_hata(p_kanal); end if;
  if p_kanal = 'meclis' and oyun.ihtarli(p.id, t) is not null then
    raise exception 'Meclis Başkanlığından ihtar aldın; % saatine kadar Genel Kurul''da söz alamazsın.', to_char(oyun.ihtarli(p.id, t) at time zone 'Europe/Istanbul', 'HH24:MI');
  end if;
  perform oyun.yazabilir_mi(p, t);
  if p_kanal = 'meclis' and not coalesce(p.yonetici, false) then
    if oyun.meclis_baskanlik_mi(p.id) then
      v_sinir := 600; v_ad := 'Başkanlık';
    else
      perform pg_advisory_xact_lock(hashtext('meclis_soz'), hashtext(p.id::text));
      s := oyun.meclis_soz_gecerli(p.id, t);
      if s.id is null then
        if oyun.meclis_baskanlik_cevrimici(t) then
          raise exception 'Genel Kurul''da konuşmak için önce Meclis Başkanlığından söz iste ("Söz iste" düğmesi). Düğmeyi görmüyorsan uygulamayı güncelle ya da web sürümünü kullan.';
        end if;
        -- Başkanlık yok: söz kendiliğinden, şahsı adına verilmiş sayılır
        select max(kullanildi) into son from oyun.meclis_soz where user_id = p.id and kullanildi > t - interval '2 minutes';
        if son is not null then
          raise exception 'Az önce konuştun; % saatinden sonra yeniden söz alabilirsin.', to_char((son + interval '2 minutes') at time zone 'Europe/Istanbul', 'HH24:MI');
        end if;
        insert into oyun.meclis_soz(user_id, tur, istek, otomatik)
        values (p.id, case when 'kisisel' = any(oyun.meclis_soz_turlerim(p.id)) then 'kisisel' when 'hukumet' = any(oyun.meclis_soz_turlerim(p.id)) then 'hukumet' else 'yerinden' end, t, t)
        returning * into s;
      end if;
      select x.sinir, x.ad into v_sinir, v_ad from oyun.meclis_soz_tur() x where x.kod = s.tur;
    end if;
    n := char_length(btrim(coalesce(p_metin, '')));
    if n > v_sinir then
      raise exception '% konuşması en çok % karakter olabilir (yazdığın: %). Konuşmanı kısalt.', v_ad, v_sinir, n;
    end if;
  end if;
  m := oyun.metin_temizle(p_metin, v_sinir);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values (k, p.id, m, t);
  if s.id is not null then
    update oyun.meclis_soz set durum = 'kullanildi', kullanildi = t, verildi = coalesce(verildi, t) where id = s.id;
  end if;
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true);
end $f$;

revoke all on function public.meclis_soz_durum(), public.meclis_soz_iste(text), public.meclis_soz_vazgec(), public.meclis_soz_karar(bigint, boolean, text) from public, anon;
grant execute on function public.meclis_soz_durum(), public.meclis_soz_iste(text), public.meclis_soz_vazgec(), public.meclis_soz_karar(bigint, boolean, text) to authenticated;
