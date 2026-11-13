-- =====================================================================
--  201 · SOHBET GRUPLARINA DIŞARIDAN KATILMA İSTEĞİ (13.11.2026)
--  İstek (Ercan): gruplara dışarıdan oyuncular da katılmak isteyebilsin;
--  sohbet listesinin en altında "Özel Gruplar" başlığında gruplar görünsün.
--
--  • Grup herkese görünürse (varsayılan) Özel Gruplar listesinde adı, kurucusu
--    ve üye sayısı görünür; MESAJLARI GÖRÜNMEZ (yalnız üyeler, 200 aynen).
--  • Üye olmayan oyuncu katılma isteği gönderir; kurucuya bildirim gider;
--    yalnız kurucu kabul/ret eder. Kabul edilince üye olur.
--  • Kurucu grubu "listede gizli" yapabilir: o zaman listede çıkmaz ve istek
--    alınmaz, yalnız kurucu ekleyebilir.
--  • Sınırlar: kişi başı en fazla 10 bekleyen istek; reddedilen istek aynı
--    gruba 24 saat sonra yenilenebilir; not en fazla 200 karakter.
--  Oyuncu verisini değiştirmez; yalnız yeni sütun, tablo ve fonksiyonlar.
-- =====================================================================

alter table oyun.sohbet_grup add column if not exists herkese_acik boolean not null default true;

create table if not exists oyun.sohbet_grup_istek(
  id bigserial primary key,
  grup_id bigint not null references oyun.sohbet_grup(id),
  user_id uuid not null references oyun.profiller(id),
  notu text check (notu is null or char_length(notu) <= 200),
  zaman timestamptz not null default now(),
  durum text not null default 'bekliyor' check (durum in ('bekliyor','kabul','ret','iptal')),
  karar_zaman timestamptz,
  karar_veren uuid
);
create unique index if not exists sohbet_grup_istek_tek on oyun.sohbet_grup_istek(grup_id, user_id) where durum = 'bekliyor';
create index if not exists sohbet_grup_istek_grup on oyun.sohbet_grup_istek(grup_id) where durum = 'bekliyor';
create index if not exists sohbet_grup_istek_kisi on oyun.sohbet_grup_istek(user_id, zaman desc);
alter table oyun.sohbet_grup_istek enable row level security;
revoke all on oyun.sohbet_grup_istek from public, anon, authenticated;

-- Üye eklenince (kurucu ekledi ya da istek kabul edildi) bekleyen isteği kapat
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
  update oyun.sohbet_grup_istek set durum = 'kabul', karar_zaman = t, karar_veren = p.id
   where grup_id = s.id and user_id = h.id and durum = 'bekliyor';
  perform oyun.bildir(h.id, p.kad || ' seni "' || s.ad || '" sohbet grubuna ekledi. Mesajlar › Kanallar › Özel Gruplar', t);
  perform oyun.canli_sinyal('kutu:' || h.id::text);
end $$;

-- Herkese görünen gruplar + benim isteklerim + kurucusu olduğum gruplara gelen istek sayıları
create or replace function public.sohbet_grup_kesfet(p_ara text default null, p_limit int default 30) returns jsonb
language plpgsql stable security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); q text := nullif(btrim(coalesce(p_ara, '')), ''); lim int := least(greatest(coalesce(p_limit, 30), 1), 60); liste jsonb; bek jsonb;
begin
  select coalesce(jsonb_agg(z.j order by z.sira desc, z.id desc), '[]'::jsonb) into liste from (
    select s.id, jsonb_build_object('id', s.id, 'ad', s.ad, 'kurucu', pr.kad, 'kurucu_parti', oyun.parti_json(pr.parti_id),
             'uye_sayisi', u.n, 'cevrimici', u.cev, 'olusturma', s.olusturma,
             'istek', (select i.durum from oyun.sohbet_grup_istek i where i.grup_id = s.id and i.user_id = p.id order by i.id desc limit 1),
             'istek_zaman', (select i.zaman from oyun.sohbet_grup_istek i where i.grup_id = s.id and i.user_id = p.id order by i.id desc limit 1),
             'son_etkinlik', (select max(m.zaman) from oyun.mesajlar m where m.kanal = 'og:' || s.id and not m.gizli)) j,
           u.n * 10 + u.cev * 25 sira
    from oyun.sohbet_grup s
    join oyun.profiller pr on pr.id = s.kurucu
    cross join lateral (select count(*)::int n, count(*) filter (where p2.son_gorulme > t - interval '5 minutes')::int cev
                        from oyun.sohbet_grup_uye x join oyun.profiller p2 on p2.id = x.user_id where x.grup_id = s.id and x.aktif) u
    where not s.kapali and s.herkese_acik
      and not oyun.sgrup_uye_mi(s.id, p.id)
      and not oyun.engelli(s.kurucu, p.id) and not oyun.engelli(p.id, s.kurucu)
      and (q is null or s.ad ilike '%' || replace(replace(q, '%', ''), '_', '') || '%' or pr.kad ilike '%' || replace(replace(q, '%', ''), '_', '') || '%')
    order by sira desc, s.id desc
    limit lim
  ) z;
  select coalesce(jsonb_object_agg(s.id::text, x.n), '{}'::jsonb) into bek
  from oyun.sohbet_grup s
  cross join lateral (select count(*)::int n from oyun.sohbet_grup_istek i where i.grup_id = s.id and i.durum = 'bekliyor') x
  where s.kurucu = p.id and not s.kapali and x.n > 0;
  return jsonb_build_object('gruplar', liste, 'bekleyen', bek,
    'istek_toplam', (select coalesce(sum(v::int), 0) from jsonb_each_text(bek) e(k, v)),
    'benim_bekleyen', (select count(*) from oyun.sohbet_grup_istek i join oyun.sohbet_grup s on s.id = i.grup_id where i.user_id = p.id and i.durum = 'bekliyor' and not s.kapali));
end $$;

create or replace function public.sohbet_grup_katilim_iste(p_grup bigint, p_not text default null) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup; nt text; son oyun.sohbet_grup_istek;
begin
  perform oyun.sgrup_gozalti_kontrol(p);
  select * into s from oyun.sohbet_grup where id = p_grup;
  if s.id is null or s.kapali then raise exception 'Sohbet grubu bulunamadı.'; end if;
  if not s.herkese_acik then raise exception 'Bu grup katılma isteği kabul etmiyor; yalnız kurucusu üye ekleyebilir.'; end if;
  if oyun.sgrup_uye_mi(s.id, p.id) then raise exception 'Zaten bu grubun üyesisin.'; end if;
  if oyun.engelli(s.kurucu, p.id) or oyun.engelli(p.id, s.kurucu) then raise exception 'Bu gruba katılma isteği gönderemezsin (engelleme var).'; end if;
  if exists (select 1 from oyun.sohbet_grup_istek where grup_id = s.id and user_id = p.id and durum = 'bekliyor') then
    raise exception 'Bu gruba zaten katılma isteği gönderdin; kurucunun yanıtını bekle.';
  end if;
  select * into son from oyun.sohbet_grup_istek where grup_id = s.id and user_id = p.id and durum = 'ret' order by id desc limit 1;
  if son.id is not null and son.karar_zaman > t - interval '24 hours' then
    raise exception 'İsteğin reddedildi; bu gruba % saatinden sonra yeniden istek gönderebilirsin.', to_char((son.karar_zaman + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  if (select count(*) from oyun.sohbet_grup_istek i join oyun.sohbet_grup g on g.id = i.grup_id where i.user_id = p.id and i.durum = 'bekliyor' and not g.kapali) >= 10 then
    raise exception 'Aynı anda en fazla 10 bekleyen katılma isteğin olabilir.';
  end if;
  if (select count(*) from oyun.sohbet_grup_uye x join oyun.sohbet_grup g on g.id = x.grup_id where x.user_id = p.id and x.aktif and not g.kapali) >= oyun.sgrup_sinir('katildigi') then
    raise exception 'En fazla % gruba üye olabilirsin.', oyun.sgrup_sinir('katildigi');
  end if;
  nt := nullif(btrim(coalesce(p_not, '')), '');
  if nt is not null then
    if char_length(nt) > 200 then raise exception 'Not en fazla 200 karakter olabilir.'; end if;
    if oyun.kufurlu(nt) then raise exception 'Notunda uygunsuz bir ifade var.'; end if;
  end if;
  insert into oyun.sohbet_grup_istek(grup_id, user_id, notu, zaman) values (s.id, p.id, nt, t);
  perform oyun.bildir(s.kurucu, p.kad || ', "' || s.ad || '" sohbet grubuna katılmak istiyor. Mesajlar › Kanallar › Özel Gruplar › grup bilgisi', t);
  perform oyun.canli_sinyal('kutu:' || s.kurucu::text);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.sohbet_grup_istek_iptal(p_grup bigint) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); n int;
begin
  update oyun.sohbet_grup_istek set durum = 'iptal', karar_zaman = t, karar_veren = p.id
   where grup_id = p_grup and user_id = p.id and durum = 'bekliyor';
  get diagnostics n = row_count;
  if n = 0 then raise exception 'Bu grup için bekleyen bir isteğin yok.'; end if;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.sohbet_grup_istek_karar(p_istek bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.sohbet_grup_istek; s oyun.sohbet_grup; h oyun.profiller;
begin
  select * into i from oyun.sohbet_grup_istek where id = p_istek;
  if i.id is null or i.durum <> 'bekliyor' then raise exception 'Bu istek artık geçerli değil.'; end if;
  s := oyun.sgrup_kurucu_kontrol(p, i.grup_id);
  select * into h from oyun.profiller where id = i.user_id;
  if coalesce(p_kabul, false) then
    perform oyun.sgrup_gozalti_kontrol(p);
    perform oyun.sgrup_uye_ekle_ic(p, s, h);   -- isteği 'kabul' yapar, bildirim gönderir
  else
    update oyun.sohbet_grup_istek set durum = 'ret', karar_zaman = t, karar_veren = p.id where id = i.id;
    perform oyun.bildir(h.id, '"' || s.ad || '" sohbet grubuna katılma isteğin kabul edilmedi.', t);
    perform oyun.canli_sinyal('kutu:' || h.id::text);
  end if;
  perform oyun.canli_sinyal('kutu:' || p.id::text);
  return jsonb_build_object('tamam', true, 'kabul', coalesce(p_kabul, false), 'kad', h.kad);
end $$;

create or replace function public.sohbet_grup_gorunurluk(p_grup bigint, p_acik boolean) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup; u uuid;
begin
  s := oyun.sgrup_kurucu_kontrol(p, p_grup);
  update oyun.sohbet_grup set herkese_acik = coalesce(p_acik, true) where id = s.id;
  if not coalesce(p_acik, true) then
    for u in update oyun.sohbet_grup_istek set durum = 'iptal', karar_zaman = t, karar_veren = p.id
              where grup_id = s.id and durum = 'bekliyor' returning user_id loop
      perform oyun.bildir(u, '"' || s.ad || '" sohbet grubu artık katılma isteği almıyor; isteğin kapandı.', t);
    end loop;
  end if;
  return jsonb_build_object('tamam', true, 'herkese_acik', coalesce(p_acik, true));
end $$;

-- Detay: görünürlük ve (kurucuya) bekleyen istekler
create or replace function public.sohbet_grup_detay(p_grup bigint) returns jsonb
language plpgsql stable security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup; uyeler jsonb; istekler jsonb := '[]';
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
  if s.kurucu = p.id then
    select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'kad', pr.kad, 'unvan', oyun.unvan(pr.id), 'parti', oyun.parti_json(pr.parti_id),
             'not', i.notu, 'zaman', i.zaman, 'cevrimici', pr.son_gorulme > t - interval '5 minutes') order by i.id), '[]'::jsonb)
      into istekler
    from oyun.sohbet_grup_istek i join oyun.profiller pr on pr.id = i.user_id
    where i.grup_id = s.id and i.durum = 'bekliyor';
  end if;
  return jsonb_build_object('id', s.id, 'kanal', 'og:' || s.id, 'ad', s.ad, 'olusturma', s.olusturma,
    'kurucu', (select kad from oyun.profiller where id = s.kurucu), 'benim_kurucu', s.kurucu = p.id,
    'herkese_acik', s.herkese_acik, 'istekler', istekler,
    'uye_sayisi', jsonb_array_length(uyeler), 'uye_sinir', oyun.sgrup_sinir('uye'), 'uyeler', uyeler);
end $$;

-- Kapatılan grubun bekleyen istekleri de kapanır
create or replace function public.sohbet_grup_kapat(p_grup bigint) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.sohbet_grup; u uuid;
begin
  s := oyun.sgrup_kurucu_kontrol(p, p_grup);
  update oyun.sohbet_grup set kapali = true, kapanis = t where id = s.id;
  update oyun.sohbet_grup_istek set durum = 'iptal', karar_zaman = t, karar_veren = p.id where grup_id = s.id and durum = 'bekliyor';
  for u in select user_id from oyun.sohbet_grup_uye where grup_id = s.id and aktif loop
    if u <> p.id then perform oyun.bildir(u, '"' || s.ad || '" sohbet grubu kurucusu tarafından kapatıldı.', t); end if;
    perform oyun.canli_sinyal('kutu:' || u::text);
  end loop;
  return jsonb_build_object('tamam', true);
end $$;

revoke all on function public.sohbet_grup_kesfet(text, int), public.sohbet_grup_katilim_iste(bigint, text), public.sohbet_grup_istek_iptal(bigint),
  public.sohbet_grup_istek_karar(bigint, boolean), public.sohbet_grup_gorunurluk(bigint, boolean) from public, anon;
grant execute on function public.sohbet_grup_kesfet(text, int), public.sohbet_grup_katilim_iste(bigint, text), public.sohbet_grup_istek_iptal(bigint),
  public.sohbet_grup_istek_karar(bigint, boolean), public.sohbet_grup_gorunurluk(bigint, boolean) to authenticated;
revoke all on function oyun.sgrup_uye_ekle_ic(oyun.profiller, oyun.sohbet_grup, oyun.profiller) from public, anon, authenticated;
