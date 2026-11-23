-- 23.11.2026 · YÖNETİM: GAZETE VE KARİKATÜR DERGİSİ KAPATMA (sürüm 2026.11.23-12)
-- İstek (Ercan): moderatörler gazete ve dergileri de (TV kanalı gibi) kalıcı kapatabilsin.
--   · mod_kurum_kapat: kurumu kapatır (aktif = false). Listelerden düşer, yeni yayın yapılamaz. Kasası ve geçmişi silinmez.
--   · mod_kurum_ac: yönetimin kapattığı kurumu geri açar (yanlış karar telafisi).
--   · Kapatılan kurumun sahibi 7 gün boyunca aynı türde yeni kurum kuramaz (kapatma, ücret ödeyip yeniden kurarak aşılmasın).
-- Yetki: 'sikayet' (İçerik Masası ve Oyuncu Masası) ve oyun kurucusu. Gerekçe zorunlu (10-300 karakter),
-- sahibine imzalı bildirim, denetim günlüğü. Yöneticinin/moderatörün kurumuna moderatör işlem yapamaz; kurucu yapabilir.
-- TV kanalı için ayrı ekran var (zz_20261123_mod_tv_kapat.sql). Dernek, sendika, şirket ve parti kapatma mahkeme yolundadır.

create table if not exists oyun.mod_kurum_kapatma (
  kurum_tur text not null check (kurum_tur in ('gazete', 'dergi')),
  kurum_id bigint not null, sahip uuid, kapatan uuid, zaman timestamptz not null, gerekce text,
  primary key (kurum_tur, kurum_id)
);
create index if not exists mod_kurum_kapatma_sahip on oyun.mod_kurum_kapatma (sahip, kurum_tur, zaman desc);
alter table oyun.mod_kurum_kapatma enable row level security;
revoke all on oyun.mod_kurum_kapatma from public, anon, authenticated;

-- Kapatılan kurumun sahibi 7 gün aynı türde yenisini kuramaz
create or replace function oyun.tg_kurum_kapatma_bekleme() returns trigger
language plpgsql set search_path to '' as $f$
declare z timestamptz;
begin
  select max(k.zaman) into z from oyun.mod_kurum_kapatma k where k.sahip = new.sahip and k.kurum_tur = tg_argv[0];
  if z is not null and z > oyun.simdi() - interval '7 days' then
    raise exception 'Önceki % oyun yönetimi kararıyla kapatıldı; % tarihine kadar yenisini kuramazsın. İtiraz için Ben › Yönetime Yaz.',
      case tg_argv[0] when 'gazete' then 'gazeten' else 'dergin' end,
      to_char((z + interval '7 days') at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI') using errcode = 'P0001';
  end if;
  return new;
end $f$;
revoke all on function oyun.tg_kurum_kapatma_bekleme() from public, anon, authenticated;
drop trigger if exists trg_kurum_kapatma_bekleme on oyun.oyuncu_gazeteleri;
create trigger trg_kurum_kapatma_bekleme before insert on oyun.oyuncu_gazeteleri for each row execute function oyun.tg_kurum_kapatma_bekleme('gazete');
drop trigger if exists trg_kurum_kapatma_bekleme on oyun.karikatur_dergi;
create trigger trg_kurum_kapatma_bekleme before insert on oyun.karikatur_dergi for each row execute function oyun.tg_kurum_kapatma_bekleme('dergi');

create or replace function public.mod_kurum_kapat(p_tur text, p_id bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); g text := btrim(coalesce(p_gerekce, ''));
  v_ad text; v_sahip uuid; v_aktif boolean; v_tur_ad text;
begin
  if p_tur not in ('gazete', 'dergi') then raise exception 'Buradan yalnız gazete ve karikatür dergisi kapatılır.'; end if;
  if char_length(g) < 10 or char_length(g) > 300 then raise exception 'Gerekçe 10-300 karakter olmalı (kurum sahibi görür).'; end if;
  v_tur_ad := case p_tur when 'gazete' then 'gazete' else 'karikatür dergisi' end;
  if p_tur = 'gazete' then select ad, sahip, aktif into v_ad, v_sahip, v_aktif from oyun.oyuncu_gazeteleri where id = p_id for update;
  else select ad, sahip, aktif into v_ad, v_sahip, v_aktif from oyun.karikatur_dergi where id = p_id for update; end if;
  if v_ad is null then raise exception 'Kurum bulunamadı.'; end if;
  if not v_aktif then raise exception 'Bu kurum zaten kapalı.'; end if;
  if v_sahip is not null then
    if v_sahip = p.id and not coalesce(p.yonetici, false) then raise exception 'Kendi kurumuna işlem yapamazsın; başka bir görevli karar vermeli.'; end if;
    perform oyun.mod_koruma(p, v_sahip);
  end if;
  if p_tur = 'gazete' then update oyun.oyuncu_gazeteleri set aktif = false where id = p_id;
  else update oyun.karikatur_dergi set aktif = false where id = p_id; end if;
  insert into oyun.mod_kurum_kapatma(kurum_tur, kurum_id, sahip, kapatan, zaman, gerekce) values (p_tur, p_id, v_sahip, p.id, t, g)
  on conflict (kurum_tur, kurum_id) do update set sahip = excluded.sahip, kapatan = excluded.kapatan, zaman = excluded.zaman, gerekce = excluded.gerekce;
  if v_sahip is not null then
    perform oyun.bildir(v_sahip, format('%s adlı %s yönetim kararıyla kapatıldı. Gerekçe: %s (%s) Kasası ve geçmişi silinmedi; 7 gün boyunca yenisini kuramazsın. İtiraz için: Ben › Yönetime Yaz.',
      v_ad, v_tur_ad, g, oyun.mod_imza(p)), t);
  end if;
  perform oyun.mod_log(p, 'kurum_kapat', oyun.kad(v_sahip), format('#%s %s: %s · %s', p_id, v_tur_ad, v_ad, left(g, 180)));
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.mod_kurum_ac(p_tur text, p_id bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); v_ad text; v_sahip uuid; v_aktif boolean; v_tur_ad text;
begin
  if p_tur not in ('gazete', 'dergi') then raise exception 'Kurum türü geçersiz.'; end if;
  v_tur_ad := case p_tur when 'gazete' then 'gazete' else 'karikatür dergisi' end;
  if p_tur = 'gazete' then select ad, sahip, aktif into v_ad, v_sahip, v_aktif from oyun.oyuncu_gazeteleri where id = p_id for update;
  else select ad, sahip, aktif into v_ad, v_sahip, v_aktif from oyun.karikatur_dergi where id = p_id for update; end if;
  if v_ad is null then raise exception 'Kurum bulunamadı.'; end if;
  if v_aktif then raise exception 'Bu kurum zaten açık.'; end if;
  if not exists (select 1 from oyun.mod_kurum_kapatma where kurum_tur = p_tur and kurum_id = p_id) then
    raise exception 'Bu kurumu yönetim kapatmadı; yalnız yönetimin kapattığı kurum geri açılır.';
  end if;
  if not coalesce(p.yonetici, false) and v_sahip = p.id then raise exception 'Kendi kurumunu geri açamazsın; tarafsız bir görevli karar vermeli.'; end if;
  begin
    if p_tur = 'gazete' then update oyun.oyuncu_gazeteleri set aktif = true where id = p_id;
    else update oyun.karikatur_dergi set aktif = true where id = p_id; end if;
  exception when unique_violation then
    raise exception 'Sahibinin bu arada açtığı başka bir kurum var ya da ad artık başkasında; geri açılamaz.';
  end;
  delete from oyun.mod_kurum_kapatma where kurum_tur = p_tur and kurum_id = p_id;
  if v_sahip is not null then
    perform oyun.bildir(v_sahip, format('%s adlı %s yönetim kararıyla yeniden açıldı. (%s)', v_ad, v_tur_ad, oyun.mod_imza(p)), t);
  end if;
  perform oyun.mod_log(p, 'kurum_ac', oyun.kad(v_sahip), format('#%s %s: %s', p_id, v_tur_ad, v_ad));
  return jsonb_build_object('tamam', true);
end $f$;

-- Kurum dosyasında "yönetim kapattı" bilgisini göstermek için
create or replace function public.mod_kurum_kapatma_bilgi(p_tur text, p_id bigint) returns jsonb
language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  return (select jsonb_build_object('zaman', k.zaman, 'gerekce', k.gerekce, 'kapatan', oyun.mod_imza((select pp from oyun.profiller pp where pp.id = k.kapatan)))
            from oyun.mod_kurum_kapatma k where k.kurum_tur = p_tur and k.kurum_id = p_id);
end $f$;

revoke all on function public.mod_kurum_kapat(text, bigint, text), public.mod_kurum_ac(text, bigint), public.mod_kurum_kapatma_bilgi(text, bigint) from public, anon;
grant execute on function public.mod_kurum_kapat(text, bigint, text), public.mod_kurum_ac(text, bigint), public.mod_kurum_kapatma_bilgi(text, bigint) to authenticated;
