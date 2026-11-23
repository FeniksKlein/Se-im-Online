-- 23.11.2026 · YÖNETİM: TV YAYINI KESME VE KANAL KAPATMA (sürüm 2026.11.23-10)
-- İstek (Ercan): uygunsuz başlıklı canlı yayını ("KAMARBEY VURDURUYOR🏳️‍🌈👌🏻") kapatmak istedi; oyunda yönetimin TV yayını ya da
-- kanalı kapatabileceği bir düğme yoktu (yalnız kanal sahibi ve sunucu bitirebiliyordu). "Düğmeyi ekle" dedi.
-- Bu dosya — Moderasyon Merkezi › "TV yayınları" ekranı:
--   · mod_tv_liste: canlı ve planlı programlar, açık kanallar, yönetimin kapattığı kanallar.
--   · mod_tv_yayin_kes: canlı yayını bitirir (planlıysa iptal eder). Başlık varsayılan olarak
--     "Yayın yönetim kararıyla kesildi" yapılır (uygunsuz başlık arşivde, gündemde ve bildirimlerde kalmasın);
--     özgün başlık denetim günlüğüne yazılır.
--   · mod_tv_kanal_kapat: kanalı kapatır (aktif = false), kanalın canlı/planlı bütün programlarını keser.
--     Kanal listelerden düşer, yeni yayın açılamaz. Kasası ve geçmişi silinmez.
--   · mod_tv_kanal_ac: yönetimin kapattığı kanalı geri açar (yanlış karar telafisi).
-- Yetki: 'sikayet' (İçerik Masası ve Oyuncu Masası; Kürsü paylaşımı gizleme ile aynı yetki) ve oyun kurucusu.
-- Kural: yönetici/moderatörün kanalına ya da sunduğu yayına moderatör işlem yapamaz (oyun.mod_koruma); kurucu yapabilir.
-- Gerekçe zorunlu (5-300 karakter); kanal sahibine ve sunucuya imzalı ("Oyun Yöneticisi G-xx") bildirim gider.

create table if not exists oyun.tv_kanal_yonetim (
  kanal_id bigint primary key references oyun.tv_kanal(id),
  kapatan uuid, zaman timestamptz not null, gerekce text
);
alter table oyun.tv_kanal_yonetim enable row level security;
revoke all on oyun.tv_kanal_yonetim from public, anon, authenticated;

create or replace function oyun.mod_tv_gerekce(p_gerekce text) returns text
language plpgsql immutable set search_path to '' as $f$
declare g text := btrim(coalesce(p_gerekce, ''));
begin
  if char_length(g) < 5 or char_length(g) > 300 then raise exception 'Gerekçe 5-300 karakter olmalı (kanal sahibi ve sunucu görür).'; end if;
  return g;
end $f$;
revoke all on function oyun.mod_tv_gerekce(text) from public, anon, authenticated;

-- Programı yönetim adına bitir (iç işlev; yetki çağıran RPC'de denetlenir)
create or replace function oyun.mod_tv_program_bitir(pr oyun.tv_program, k oyun.tv_kanal, p oyun.profiller, g text, gizle boolean)
returns void language plpgsql security definer set search_path to '' as $f$
declare t timestamptz := oyun.simdi(); yeni text := case when gizle then 'Yayın yönetim kararıyla kesildi' else pr.baslik end;
begin
  if pr.durum = 'planli' then
    update oyun.tv_program set durum = 'iptal', gercek_bit = t, baslik = yeni where id = pr.id;
    perform oyun.bildir(x.user_id, format('%s · bir program yönetim kararıyla iptal edildi.', k.ad), t)
      from oyun.tv_konuk x where x.program_id = pr.id and x.durum <> 'ret';
  elsif pr.durum = 'canli' then
    update oyun.tv_program set durum = 'bitti', gercek_bit = t, baslik = yeni where id = pr.id;
  else
    if gizle and pr.baslik is distinct from yeni then update oyun.tv_program set baslik = yeni where id = pr.id; end if;
    return;
  end if;
  perform oyun.tv_program_hesapla(pr.id);
  perform oyun.tv_sinyal(pr.id);
end $f$;
revoke all on function oyun.mod_tv_program_bitir(oyun.tv_program, oyun.tv_kanal, oyun.profiller, text, boolean) from public, anon, authenticated;

create or replace function public.mod_tv_liste() returns jsonb
language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  return jsonb_build_object(
    'programlar', coalesce((select jsonb_agg(jsonb_build_object(
        'id', pr.id, 'baslik', pr.baslik, 'durum', pr.durum, 'tur', pr.tur, 'bas', coalesce(pr.gercek_bas, pr.bas),
        'izleyici', coalesce(pr.izleyici, 0), 'kanal_id', k.id, 'kanal', k.ad,
        'sunucu', (select kad from oyun.profiller where id = pr.sunucu), 'sahip', (select kad from oyun.profiller where id = k.sahip))
        order by (pr.durum = 'canli') desc, coalesce(pr.gercek_bas, pr.bas))
      from oyun.tv_program pr join oyun.tv_kanal k on k.id = pr.kanal_id
      where pr.durum in ('canli', 'planli')), '[]'::jsonb),
    'kanallar', coalesce((select jsonb_agg(jsonb_build_object(
        'id', k.id, 'ad', k.ad, 'slogan', k.slogan, 'sahip', (select kad from oyun.profiller where id = k.sahip), 'kurulus', k.kurulus,
        'canli', (select count(*) from oyun.tv_program x where x.kanal_id = k.id and x.durum = 'canli'),
        'planli', (select count(*) from oyun.tv_program x where x.kanal_id = k.id and x.durum = 'planli')) order by k.ad)
      from oyun.tv_kanal k where k.aktif), '[]'::jsonb),
    'kapali', coalesce((select jsonb_agg(jsonb_build_object(
        'id', k.id, 'ad', k.ad, 'sahip', (select kad from oyun.profiller where id = k.sahip), 'zaman', y.zaman, 'gerekce', y.gerekce,
        'kapatan', oyun.mod_imza((select pp from oyun.profiller pp where pp.id = y.kapatan))) order by y.zaman desc)
      from oyun.tv_kanal_yonetim y join oyun.tv_kanal k on k.id = y.kanal_id where not k.aktif), '[]'::jsonb));
end $f$;

create or replace function public.mod_tv_yayin_kes(p_program bigint, p_gerekce text, p_baslik_gizle boolean default true) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); g text := oyun.mod_tv_gerekce(p_gerekce);
  pr oyun.tv_program; k oyun.tv_kanal; durum0 text;
begin
  select * into pr from oyun.tv_program where id = p_program for update;
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  if pr.durum not in ('canli', 'planli') then raise exception 'Bu program zaten bitmiş.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  perform oyun.mod_koruma(p, pr.sunucu);
  perform oyun.mod_koruma(p, k.sahip);
  durum0 := pr.durum;
  perform oyun.mod_tv_program_bitir(pr, k, p, g, coalesce(p_baslik_gizle, true));
  perform oyun.bildir(u, format('%s · "%s" %s yönetim kararıyla %s. Gerekçe: %s (%s) İtiraz için: Ben › Yönetime Yaz.',
      k.ad, left(pr.baslik, 80), case when durum0 = 'canli' then 'yayını' else 'programı' end,
      case when durum0 = 'canli' then 'kesildi' else 'iptal edildi' end, g, oyun.mod_imza(p)), t)
    from (select distinct unnest(array[pr.sunucu, k.sahip]) u) z where u is not null;
  perform oyun.mod_log(p, 'tv_yayin_kes', (select kad from oyun.profiller where id = pr.sunucu),
    format('#%s %s · "%s" · %s', pr.id, k.ad, left(pr.baslik, 100), left(g, 150)));
  return public.mod_tv_liste();
end $f$;

create or replace function public.mod_tv_kanal_kapat(p_kanal bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); g text := oyun.mod_tv_gerekce(p_gerekce);
  k oyun.tv_kanal; pr oyun.tv_program; n int := 0;
begin
  select * into k from oyun.tv_kanal where id = p_kanal for update;
  if k.id is null then raise exception 'Kanal bulunamadı.'; end if;
  if not k.aktif then raise exception 'Bu kanal zaten kapalı.'; end if;
  perform oyun.mod_koruma(p, k.sahip);
  for pr in select * from oyun.tv_program where kanal_id = k.id and durum in ('canli', 'planli') for update loop
    perform oyun.mod_tv_program_bitir(pr, k, p, g, false);
    if pr.sunucu <> k.sahip then
      perform oyun.bildir(pr.sunucu, format('%s kanalı yönetim kararıyla kapatıldı; sunduğun "%s" programı sona erdi. (%s)', k.ad, left(pr.baslik, 80), oyun.mod_imza(p)), t);
    end if;
    n := n + 1;
  end loop;
  update oyun.tv_kanal set aktif = false where id = k.id;
  insert into oyun.tv_kanal_yonetim(kanal_id, kapatan, zaman, gerekce) values (k.id, p.id, t, g)
  on conflict (kanal_id) do update set kapatan = excluded.kapatan, zaman = excluded.zaman, gerekce = excluded.gerekce;
  perform oyun.bildir(k.sahip, format('%s kanalın yönetim kararıyla kapatıldı. Gerekçe: %s (%s) Kanal kasası ve geçmişi silinmedi. İtiraz için: Ben › Yönetime Yaz.',
    k.ad, g, oyun.mod_imza(p)), t);
  perform oyun.mod_log(p, 'tv_kanal_kapat', (select kad from oyun.profiller where id = k.sahip),
    format('#%s %s · %s program kesildi · %s', k.id, k.ad, n, left(g, 180)));
  return public.mod_tv_liste();
end $f$;

create or replace function public.mod_tv_kanal_ac(p_kanal bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); k oyun.tv_kanal;
begin
  select * into k from oyun.tv_kanal where id = p_kanal for update;
  if k.id is null then raise exception 'Kanal bulunamadı.'; end if;
  if k.aktif then raise exception 'Bu kanal zaten açık.'; end if;
  if not exists (select 1 from oyun.tv_kanal_yonetim where kanal_id = k.id) then raise exception 'Bu kanalı yönetim kapatmadı; yalnız yönetimin kapattığı kanal geri açılır.'; end if;
  if exists (select 1 from oyun.tv_kanal where sahip = k.sahip and aktif) then raise exception 'Kanal sahibinin bu arada açtığı başka bir kanal var; ikisi aynı anda açık olamaz.'; end if;
  if exists (select 1 from oyun.tv_kanal where lower(ad) = lower(k.ad) and aktif) then raise exception 'Bu adla açık başka bir kanal var; geri açılamaz.'; end if;
  update oyun.tv_kanal set aktif = true where id = k.id;
  delete from oyun.tv_kanal_yonetim where kanal_id = k.id;
  perform oyun.bildir(k.sahip, format('%s kanalın yönetim kararıyla yeniden açıldı. (%s)', k.ad, oyun.mod_imza(p)), t);
  perform oyun.mod_log(p, 'tv_kanal_ac', (select kad from oyun.profiller where id = k.sahip), format('#%s %s', k.id, k.ad));
  return public.mod_tv_liste();
end $f$;

revoke all on function public.mod_tv_liste(), public.mod_tv_yayin_kes(bigint, text, boolean),
  public.mod_tv_kanal_kapat(bigint, text), public.mod_tv_kanal_ac(bigint) from public, anon;
grant execute on function public.mod_tv_liste(), public.mod_tv_yayin_kes(bigint, text, boolean),
  public.mod_tv_kanal_kapat(bigint, text), public.mod_tv_kanal_ac(bigint) to authenticated;
