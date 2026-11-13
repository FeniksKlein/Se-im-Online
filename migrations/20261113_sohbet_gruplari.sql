begin;
-- =====================================================================
--  200 · OYUNCU SOHBET GRUPLARI (13.11.2026)
--  İstek (Ercan): oyuncular Mesajlar › Kanallar'da WhatsApp grubu gibi kendi
--  gruplarını kurabilsin, ad koyabilsin; kuran üye ekleyip çıkarabilsin;
--  grup sohbetini yalnız üyeler görsün; görünüm diğer kanallarla aynı olsun.
--
--  Kanal kodu: 'og:<grup_id>'. Mesajlar mevcut oyun.mesajlar tablosuna yazılır;
--  okuma/yazma/tepki/canlı sinyal mevcut sohbet_oku / sohbet_yaz /
--  mesaj_tepki_ver / canli_sinyal hattından geçer. Erişim tek noktadan,
--  oyun.kanal_coz içinde, aktif üyelikle doğrulanır.
--  Üyelikten çıkarma kayıt silmez (aktif=false); grup kapatma kapali=true.
--  Gözaltı yazı engeli (mesajlar tetikleyicisi) gruplarda da geçerlidir.
--  Oyuncu verisini değiştirmez; yalnız yeni tablolar ve fonksiyonlar.
-- =====================================================================

create table if not exists oyun.sohbet_grup(
  id bigserial primary key,
  ad text not null check (char_length(ad) between 2 and 40),
  kurucu uuid not null references oyun.profiller(id),
  olusturma timestamptz not null default now(),
  kapali boolean not null default false,
  kapanis timestamptz
);
create index if not exists sohbet_grup_kurucu on oyun.sohbet_grup(kurucu) where not kapali;

create table if not exists oyun.sohbet_grup_uye(
  grup_id bigint not null references oyun.sohbet_grup(id),
  user_id uuid not null references oyun.profiller(id),
  ekleyen uuid,
  katilma timestamptz not null default now(),
  aktif boolean not null default true,
  ayrilma timestamptz,
  cikaran uuid,
  primary key (grup_id, user_id)
);
create index if not exists sohbet_grup_uye_kisi on oyun.sohbet_grup_uye(user_id) where aktif;

alter table oyun.sohbet_grup enable row level security;
alter table oyun.sohbet_grup_uye enable row level security;
revoke all on oyun.sohbet_grup, oyun.sohbet_grup_uye from public, anon, authenticated;

-- Sınırlar (tek yerde)
create or replace function oyun.sgrup_sinir(k text) returns int language sql immutable set search_path = '' as $$
  select case k when 'kurucu_aktif' then 10 when 'gunluk_kurma' then 5 when 'uye' then 100 when 'katildigi' then 50 else 0 end
$$;

-- Aktif üye mi? (grup açık olmalı)
create or replace function oyun.sgrup_uye_mi(g bigint, u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from oyun.sohbet_grup_uye x join oyun.sohbet_grup s on s.id = x.grup_id
                 where x.grup_id = g and x.user_id = u and x.aktif and not s.kapali)
$$;

create or replace function oyun.sgrup_ad_temizle(p_ad text) returns text language plpgsql set search_path = 'oyun', 'public', 'extensions', 'pg_temp' as $$
declare a text := btrim(regexp_replace(coalesce(p_ad, ''), '\s+', ' ', 'g'));
begin
  if char_length(a) < 2 then raise exception 'Grup adı en az 2 karakter olmalı.'; end if;
  if char_length(a) > 40 then raise exception 'Grup adı en fazla 40 karakter olabilir.'; end if;
  if oyun.kufurlu(a) then raise exception 'Grup adında uygunsuz bir ifade var.'; end if;
  return a;
end $$;

-- Grubu kurucu olarak yönetme yetkisi
create or replace function oyun.sgrup_kurucu_kontrol(p oyun.profiller, g bigint) returns oyun.sohbet_grup language plpgsql stable security definer set search_path = '' as $$
declare s oyun.sohbet_grup;
begin
  select * into s from oyun.sohbet_grup where id = g;
  if s.id is null or s.kapali then raise exception 'Sohbet grubu bulunamadı.'; end if;
  if s.kurucu <> p.id then raise exception 'Bu işlemi yalnızca grubu kuran kişi yapabilir.'; end if;
  return s;
end $$;

create or replace function oyun.sgrup_gozalti_kontrol(p oyun.profiller) returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if oyun.gozalti_aktif(p.id) is not null then
    raise exception 'Gözaltındasınız; gözaltı süresince sohbet grubu kuramaz ve yönetemezsiniz.';
  end if;
end $$;

-- Üye ekleme çekirdeği (kurma ve sonradan ekleme ortak)
create or replace function oyun.sgrup_uye_ekle_ic(p oyun.profiller, s oyun.sohbet_grup, h oyun.profiller) returns void
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi();
begin
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  if h.id = p.id then return; end if;
  if h.yasakli then raise exception '% şu anda oyundan uzaklaştırılmış; gruba eklenemez.', h.kad; end if;
  if oyun.engelli(h.id, p.id) or oyun.engelli(p.id, h.id) then raise exception '% ile aranızda engelleme olduğu için gruba eklenemez.', h.kad; end if;
  if oyun.sgrup_uye_mi(s.id, h.id) then raise exception '% zaten bu grubun üyesi.', h.kad; end if;
  if (select count(*) from oyun.sohbet_grup_uye where grup_id = s.id and aktif) >= oyun.sgrup_sinir('uye') then
    raise exception 'Bir grupta en fazla % üye olabilir.', oyun.sgrup_sinir('uye');
  end if;
  if (select count(*) from oyun.sohbet_grup_uye x join oyun.sohbet_grup g on g.id = x.grup_id where x.user_id = h.id and x.aktif and not g.kapali) >= oyun.sgrup_sinir('katildigi') then
    raise exception '% en fazla % gruba üye olabilir; daha fazla gruba eklenemez.', h.kad, oyun.sgrup_sinir('katildigi');
  end if;
  insert into oyun.sohbet_grup_uye(grup_id, user_id, ekleyen, katilma, aktif, ayrilma, cikaran)
  values (s.id, h.id, p.id, t, true, null, null)
  on conflict (grup_id, user_id) do update set aktif = true, ekleyen = excluded.ekleyen, katilma = excluded.katilma, ayrilma = null, cikaran = null;
  perform oyun.bildir(h.id, p.kad || ' seni "' || s.ad || '" sohbet grubuna ekledi. Mesajlar › Kanallar › Gruplarım', t);
  perform oyun.canli_sinyal('kutu:' || h.id::text);
end $$;

-- ---------------------------------------------------------------------
--  RPC'ler
-- ---------------------------------------------------------------------
create or replace function public.sohbet_grup_kur(p_ad text, p_uyeler text[] default null) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a text; s oyun.sohbet_grup; k text; h oyun.profiller; eklenen int := 0; atlanan jsonb := '[]';
begin
  perform oyun.sgrup_gozalti_kontrol(p);
  a := oyun.sgrup_ad_temizle(p_ad);
  if (select count(*) from oyun.sohbet_grup where kurucu = p.id and not kapali) >= oyun.sgrup_sinir('kurucu_aktif') then
    raise exception 'En fazla % açık sohbet grubun olabilir. Yeni grup için eskilerden birini kapat.', oyun.sgrup_sinir('kurucu_aktif');
  end if;
  if (select count(*) from oyun.sohbet_grup where kurucu = p.id and olusturma > t - interval '24 hours') >= oyun.sgrup_sinir('gunluk_kurma') then
    raise exception 'Bir günde en fazla % grup kurabilirsin; biraz sonra tekrar dene.', oyun.sgrup_sinir('gunluk_kurma');
  end if;
  if (select count(*) from oyun.sohbet_grup_uye x join oyun.sohbet_grup g on g.id = x.grup_id where x.user_id = p.id and x.aktif and not g.kapali) >= oyun.sgrup_sinir('katildigi') then
    raise exception 'En fazla % gruba üye olabilirsin.', oyun.sgrup_sinir('katildigi');
  end if;
  insert into oyun.sohbet_grup(ad, kurucu, olusturma) values (a, p.id, t) returning * into s;
  insert into oyun.sohbet_grup_uye(grup_id, user_id, ekleyen, katilma) values (s.id, p.id, p.id, t);
  if p_uyeler is not null then
    foreach k in array p_uyeler[1:oyun.sgrup_sinir('uye')] loop
      if k is null or btrim(k) = '' then continue; end if;
      begin
        h := oyun.profil_bul(btrim(k));
        if h.id = p.id then continue; end if;
        perform oyun.sgrup_uye_ekle_ic(p, s, h);
        eklenen := eklenen + 1;
      exception when others then
        atlanan := atlanan || jsonb_build_object('kad', k, 'neden', sqlerrm);
      end;
    end loop;
  end if;
  perform oyun.canli_sinyal('kutu:' || p.id::text);
  return jsonb_build_object('tamam', true, 'id', s.id, 'kanal', 'og:' || s.id, 'ad', s.ad, 'eklenen', eklenen, 'atlanan', atlanan);
end $$;

create or replace function public.sohbet_grup_detay(p_grup bigint) returns jsonb
language plpgsql stable security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup; uyeler jsonb;
begin
  select * into s from oyun.sohbet_grup where id = p_grup;
  if s.id is null or s.kapali or not oyun.sgrup_uye_mi(s.id, p.id) then raise exception 'Bu sohbet grubunun üyesi değilsin.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'kad', pr.kad, 'unvan', oyun.unvan(pr.id), 'parti', oyun.parti_json(pr.parti_id),
      'kurucu', pr.id = s.kurucu, 'ben', pr.id = p.id,
      'cevrimici', pr.son_gorulme > t - interval '5 minutes', 'katilma', x.katilma)
      order by (pr.id = s.kurucu) desc, (pr.son_gorulme > t - interval '5 minutes') desc, lower(pr.kad)), '[]'::jsonb)
    into uyeler
  from oyun.sohbet_grup_uye x join oyun.profiller pr on pr.id = x.user_id
  where x.grup_id = s.id and x.aktif;
  return jsonb_build_object('id', s.id, 'kanal', 'og:' || s.id, 'ad', s.ad, 'olusturma', s.olusturma,
    'kurucu', (select kad from oyun.profiller where id = s.kurucu), 'benim_kurucu', s.kurucu = p.id,
    'uye_sayisi', jsonb_array_length(uyeler), 'uye_sinir', oyun.sgrup_sinir('uye'), 'uyeler', uyeler);
end $$;

create or replace function public.sohbet_grup_ad(p_grup bigint, p_ad text) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sohbet_grup; a text; u uuid;
begin
  perform oyun.sgrup_gozalti_kontrol(p);
  s := oyun.sgrup_kurucu_kontrol(p, p_grup);
  a := oyun.sgrup_ad_temizle(p_ad);
  update oyun.sohbet_grup set ad = a where id = s.id;
  for u in select user_id from oyun.sohbet_grup_uye where grup_id = s.id and aktif loop
    perform oyun.canli_sinyal('kutu:' || u::text);
  end loop;
  return jsonb_build_object('tamam', true, 'ad', a);
end $$;

create or replace function public.sohbet_grup_uye_ekle(p_grup bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sohbet_grup; h oyun.profiller;
begin
  perform oyun.sgrup_gozalti_kontrol(p);
  s := oyun.sgrup_kurucu_kontrol(p, p_grup);
  h := oyun.profil_bul(btrim(coalesce(p_kad, '')));
  if h.id = p.id then raise exception 'Sen zaten bu grubun kurucususun.'; end if;
  perform oyun.sgrup_uye_ekle_ic(p, s, h);
  return jsonb_build_object('tamam', true, 'kad', h.kad);
end $$;

create or replace function public.sohbet_grup_uye_cikar(p_grup bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup; h oyun.profiller;
begin
  s := oyun.sgrup_kurucu_kontrol(p, p_grup);
  h := oyun.profil_bul(btrim(coalesce(p_kad, '')));
  if h.id = p.id then raise exception 'Kurucu gruptan çıkarılamaz. Grubu kapatmak için grup bilgisindeki "Grubu kapat" düğmesini kullan.'; end if;
  if not oyun.sgrup_uye_mi(s.id, h.id) then raise exception '% bu grubun üyesi değil.', h.kad; end if;
  update oyun.sohbet_grup_uye set aktif = false, ayrilma = t, cikaran = p.id where grup_id = s.id and user_id = h.id;
  perform oyun.bildir(h.id, p.kad || ' seni "' || s.ad || '" sohbet grubundan çıkardı.', t);
  perform oyun.canli_sinyal('kutu:' || h.id::text);
  perform oyun.canli_sinyal('sohbet:og:' || s.id);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.sohbet_grup_ayril(p_grup bigint) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup;
begin
  select * into s from oyun.sohbet_grup where id = p_grup;
  if s.id is null or s.kapali or not oyun.sgrup_uye_mi(s.id, p.id) then raise exception 'Bu sohbet grubunun üyesi değilsin.'; end if;
  if s.kurucu = p.id then raise exception 'Kurucu gruptan ayrılamaz. Grubu sonlandırmak için "Grubu kapat" düğmesini kullan.'; end if;
  update oyun.sohbet_grup_uye set aktif = false, ayrilma = t, cikaran = null where grup_id = s.id and user_id = p.id;
  perform oyun.canli_sinyal('kutu:' || p.id::text);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.sohbet_grup_kapat(p_grup bigint) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup; u uuid;
begin
  s := oyun.sgrup_kurucu_kontrol(p, p_grup);
  update oyun.sohbet_grup set kapali = true, kapanis = t where id = s.id;
  for u in select user_id from oyun.sohbet_grup_uye where grup_id = s.id and aktif loop
    if u <> p.id then perform oyun.bildir(u, '"' || s.ad || '" sohbet grubu kurucusu tarafından kapatıldı.', t); end if;
    perform oyun.canli_sinyal('kutu:' || u::text);
  end loop;
  return jsonb_build_object('tamam', true);
end $$;

-- ---------------------------------------------------------------------
--  Mevcut sohbet hattına grup kanalı ('og:<id>')
-- ---------------------------------------------------------------------
create or replace function oyun.kanal_coz(p oyun.profiller, p_kanal text) returns text
language plpgsql stable set search_path = '' as $$
declare gid bigint;
begin
  if p_kanal like 'og:%' then
    if p_kanal !~ '^og:[0-9]{1,18}$' then return null; end if;
    gid := substr(p_kanal, 4)::bigint;
    if oyun.sgrup_uye_mi(gid, p.id) then return 'og:' || gid; end if;
    return null;
  end if;
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'belediye' then 'belediye:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (
      select 'ittifak:' || u.ittifak_id
      from oyun.ittifak_uyeler u
      join oyun.partiler pa on pa.id = u.parti_id
      where u.parti_id = p.parti_id
        and not pa.kapali
        and (
          pa.gb = p.id
          or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = p.id)
          or exists (select 1 from oyun.parti_teskilat_gorev tg where tg.parti_id = pa.id and tg.user_id = p.id and tg.aktif)
          or exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null)
        )
    )
    when 'kabine' then case when exists (
      select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('cb','bakan','cb_yardimcisi')
    ) then 'kabine' end
    when 'grup' then case
      when oyun.aktif_mv_parti(p.id) is not null then 'grup:' || oyun.aktif_mv_parti(p.id)
      when exists (select 1 from oyun.partiler pa where pa.gb = p.id and pa.id = p.parti_id) then 'grup:' || p.parti_id end
    when 'divan' then case when exists (
      select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv','grup_bskv')
    ) then 'divan' end
    when 'yonetim' then (
      select 'yonetim:' || pa.id from oyun.partiler pa
      where pa.id = p.parti_id and not pa.kapali
        and (pa.gb = p.id or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = p.id))
    )
    else null end;
end $$;

create or replace function oyun.kanal_baslik(p oyun.profiller, kod text) returns text
language sql stable set search_path = 'oyun', 'public', 'extensions', 'pg_temp' as $$
  select case when kod ~ '^og:[0-9]{1,18}$' then (select g.ad from oyun.sohbet_grup g where g.id = substr(kod, 4)::bigint)
  else case kod
    when 'genel' then 'Türkiye Meydanı'
    when 'il' then (select ad from oyun.iller where id = p.il_id) || ' Kahvesi'
    when 'belediye' then (select ad from oyun.iller where id = p.il_id) || ' Belediye Meclisi'
    when 'parti' then (select ad from oyun.partiler where id = p.parti_id)
    when 'yonetim' then (select kisa from oyun.partiler where id = p.parti_id) || ' Yönetim Kurulu'
    when 'meclis' then 'TBMM Genel Kurulu'
    when 'kabine' then 'Bakanlar Kurulu'
    when 'grup' then (select kisa from oyun.partiler where id = coalesce(oyun.aktif_mv_parti(p.id), p.parti_id)) || ' Meclis Grubu'
    when 'divan' then 'TBMM Başkanlık Divanı ve Danışma Kurulu'
    when 'ittifak' then (select i.ad from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = p.parti_id)
  end end
$$;

create or replace function oyun.kanal_hata(kod text) returns text
language sql immutable set search_path = '' as $$
  select case when kod like 'og:%' then 'Bu sohbet grubunun üyesi değilsin ya da grup kapatıldı.'
  else case kod
    when 'ittifak' then 'İttifak sohbetine yalnızca üye partilerin genel başkanları, yönetimi, il başkanları ve milletvekilleri girebilir.'
    when 'kabine' then 'Bakanlar Kurulu sohbetine yalnızca cumhurbaşkanı ve bakanlar girebilir.'
    when 'yonetim' then 'Parti yönetimi sohbetine yalnızca genel başkan ve genel başkan yardımcıları girebilir.'
    when 'grup' then 'Meclis grubu sohbetine yalnızca partinin milletvekilleri ve genel başkanı girebilir.'
    when 'divan' then 'Başkanlık Divanı sohbetine TBMM Başkanı, başkanvekilleri ve grup başkanvekilleri girebilir.'
    else 'Parti sohbeti için bir partiye üye olmalısın.' end end
$$;

-- Okunmamış sayısına gruplar da girer
create or replace function oyun.sohbet_okunmamis(p oyun.profiller) returns integer
language plpgsql stable set search_path = 'oyun', 'public', 'extensions', 'pg_temp' as $$
declare
  t timestamptz := oyun.simdi();
  kanallar text[];
  k text;
  n int;
  toplam int := 0;
begin
  select array_agg(distinct z.c) into kanallar
  from (select oyun.kanal_coz(p, x.kod) c
        from unnest(array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine']::text[]) x(kod)
        union all
        select 'og:' || g.id from oyun.sohbet_grup_uye x join oyun.sohbet_grup g on g.id = x.grup_id
         where x.user_id = p.id and x.aktif and not g.kapali) z
  where z.c is not null;
  if kanallar is null then return 0; end if;
  foreach k in array kanallar loop
    select count(*) into n from (
      select 1
      from oyun.mesajlar m
      where m.kanal = k
        and m.id > coalesce((select r.son_id from oyun.kanal_okuma r where r.user_id = p.id and r.kanal = k), 0)
        and m.user_id <> p.id
        and not m.gizli
        and m.zaman <= t
        and m.zaman > t - interval '3 days'
        and not exists (select 1 from oyun.engellemeler e where e.engelleyen = p.id and e.engellenen = m.user_id)
      limit 100
    ) q;
    toplam := toplam + n;
  end loop;
  return toplam;
end $$;

-- Kanal özetine "Gruplarım" eklenir (yeni alanlar: ozgrup, kurucu, uye_sayisi, grup_id)
create or replace function public.sohbet_ozet() returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); liste jsonb := '[]'; kod text; k text; imlec bigint; okunmamis int; son jsonb; cev int; kilit text; g record;
begin
  foreach kod in array array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine'] loop
    k := oyun.kanal_coz(p, kod);
    kilit := case when k is not null then null else case kod
      when 'parti' then 'Bir partiye katılınca açılır.' when 'yonetim' then 'Genel başkan ya da genel başkan yardımcısı olunca açılır.'
      when 'ittifak' then 'Partin bir ittifaka girince açılır.' when 'kabine' then 'Cumhurbaşkanı ya da bakan olunca açılır.'
      when 'grup' then 'Milletvekili olunca açılır.' when 'divan' then 'TBMM Başkanı, başkanvekili ya da grup başkanvekili olunca açılır.' end end;
    okunmamis := 0; son := null; cev := null; imlec := null;
    if k is not null then
      select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = k;
      select count(*) into okunmamis from (
        select 1 from oyun.mesajlar m where m.kanal = k and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
           and m.zaman <= t and m.zaman > t - interval '3 days' and not oyun.engelli(p.id, m.user_id) limit 100) x;
      select jsonb_build_object('kad', coalesce(pr.kad, '(silinmiş)'), 'metin', m.metin, 'zaman', m.zaman) into son
        from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
       where m.kanal = k and not m.gizli and m.zaman <= t and not oyun.engelli(p.id, m.user_id) order by m.id desc limit 1;
      cev := case kod
        when 'genel' then (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes')
        when 'il' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'belediye' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'parti' then (select count(*) from oyun.profiller where not yasakli and parti_id = p.parti_id and son_gorulme > t - interval '5 minutes')
        end;
    end if;
    liste := liste || jsonb_build_object('kanal', kod, 'baslik', coalesce(oyun.kanal_baslik(p, kod), case kod when 'parti' then 'Parti sohbeti' when 'yonetim' then 'Parti Yönetim Kurulu'
                  when 'ittifak' then 'İttifak sohbeti' when 'kabine' then 'Bakanlar Kurulu' when 'grup' then 'Parti Meclis Grubu'
                  when 'divan' then 'TBMM Başkanlık Divanı' end),
      'kilit', kilit, 'yazabilir', k is not null and oyun.kanal_yazabilir(p, kod), 'okunmamis', okunmamis, 'son', son, 'cevrimici', cev,
      'sinyal', case when k is null then null else 'sohbet:' || k end);
  end loop;
  -- Oyuncunun kendi sohbet grupları
  for g in
    select s.id, s.ad, s.kurucu, s.olusturma
    from oyun.sohbet_grup_uye x join oyun.sohbet_grup s on s.id = x.grup_id
    where x.user_id = p.id and x.aktif and not s.kapali
    order by s.id
  loop
    k := 'og:' || g.id; imlec := null;
    select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = k;
    select count(*) into okunmamis from (
      select 1 from oyun.mesajlar m where m.kanal = k and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
         and m.zaman <= t and m.zaman > t - interval '3 days' and not oyun.engelli(p.id, m.user_id) limit 100) x;
    son := null;
    select jsonb_build_object('kad', coalesce(pr.kad, '(silinmiş)'), 'metin', m.metin, 'zaman', m.zaman) into son
      from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
     where m.kanal = k and not m.gizli and m.zaman <= t and not oyun.engelli(p.id, m.user_id) order by m.id desc limit 1;
    select count(*) filter (where pr.son_gorulme > t - interval '5 minutes' and not pr.yasakli), count(*)
      into cev, imlec
      from oyun.sohbet_grup_uye x join oyun.profiller pr on pr.id = x.user_id where x.grup_id = g.id and x.aktif;
    liste := liste || jsonb_build_object('kanal', k, 'baslik', g.ad, 'kilit', null, 'yazabilir', true, 'okunmamis', okunmamis,
      'son', son, 'cevrimici', cev, 'sinyal', 'sohbet:' || k, 'ozgrup', true, 'grup_id', g.id,
      'kurucu', g.kurucu = p.id, 'uye_sayisi', imlec, 'olusturma', g.olusturma);
  end loop;
  return jsonb_build_object('kanallar', liste,
    'cevrimici', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes'),
    'toplam_okunmamis', (select coalesce(sum((x ->> 'okunmamis')::int), 0) from jsonb_array_elements(liste) x),
    'grup_sinir', jsonb_build_object('kurucu_aktif', oyun.sgrup_sinir('kurucu_aktif'), 'uye', oyun.sgrup_sinir('uye')));
end $$;

-- Canlı sinyal: grup anahtarını yalnız aktif üye görür
create or replace function oyun.canli_sinyal_gorur(p_anahtar text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller; kod text; eid bigint;
begin
 if auth.uid() is null or p_anahtar is null then return false; end if;
 if p_anahtar like 'kutu:%' then return p_anahtar = 'kutu:' || (select auth.uid())::text; end if;
 if p_anahtar ~ '^(miting|secim|yayin|muzayede|kursu|halk):' then return true; end if;
 if p_anahtar like 'eylem:%' then
  begin eid := substr(p_anahtar, 7)::bigint; exception when others then return false; end;
  return oyun.sokak_sohbet_uye(eid);
 end if;
 if p_anahtar ~ '^sohbet:og:[0-9]{1,18}$' then
  return oyun.sgrup_uye_mi(substr(p_anahtar, 11)::bigint, (select auth.uid()));
 end if;
 if p_anahtar like 'sohbet:%' then
  select * into p from oyun.profiller where id = (select auth.uid());
  if p.id is null then return false; end if;
  kod := substr(p_anahtar, 8);
  return exists (
   select 1 from unnest(array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine']::text[]) c
   where oyun.kanal_coz(p, c) = kod);
 end if;
 return false;
end $$;

-- Yetkiler: iç yardımcılar istemciye kapalı, RPC'ler authenticated'a açık
revoke all on function oyun.sgrup_sinir(text), oyun.sgrup_uye_mi(bigint, uuid), oyun.sgrup_ad_temizle(text),
  oyun.sgrup_kurucu_kontrol(oyun.profiller, bigint), oyun.sgrup_gozalti_kontrol(oyun.profiller),
  oyun.sgrup_uye_ekle_ic(oyun.profiller, oyun.sohbet_grup, oyun.profiller) from public, anon, authenticated;
revoke all on function public.sohbet_grup_kur(text, text[]), public.sohbet_grup_detay(bigint), public.sohbet_grup_ad(bigint, text),
  public.sohbet_grup_uye_ekle(bigint, text), public.sohbet_grup_uye_cikar(bigint, text), public.sohbet_grup_ayril(bigint),
  public.sohbet_grup_kapat(bigint) from public, anon;
grant execute on function public.sohbet_grup_kur(text, text[]), public.sohbet_grup_detay(bigint), public.sohbet_grup_ad(bigint, text),
  public.sohbet_grup_uye_ekle(bigint, text), public.sohbet_grup_uye_cikar(bigint, text), public.sohbet_grup_ayril(bigint),
  public.sohbet_grup_kapat(bigint) to authenticated;
grant execute on function oyun.canli_sinyal_gorur(text) to authenticated;
commit;
