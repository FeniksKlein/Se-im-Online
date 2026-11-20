-- Canlıya 20.11.2026'da Supabase migration'ı olarak uygulandı: duyuru_sinir_imza_20261120
-- Kaynak: gelistirici/sql/zz_20261120_duyuru_sinir_imza.sql · tekrar çalıştırmak güvenlidir.
begin;
set local lock_timeout = '5s';

-- 20.11.2026 · DUYURU KARAKTER SINIRI + YÖNETİM İMZASI (Ercan'ın kararı, moderatör ekibinin isteği)
-- 1) Herkese açık duyuru: moderatörün hazırladığı karşılama metni sığmıyor, üstüne
--    'new row for relation "yayinlar" violates check constraint "yayinlar_metin_check"' hatası veriyordu.
--    Sebep: admin_duyuru metni 2000 karaktere kadar kabul edip sonuna imza ekliyor, tablo sınırı da 2000 olduğu için
--    sınıra yakın her metin tabloya yazılırken reddediliyordu.
--    Yeni kural: duyuru metni 5000 karakter; tablo sınırı 6000 (imza payı). Diğer yayın türlerinin kendi sınırları değişmez.
-- 2) İmza: "Görevli G-06" yerine "Oyun Yöneticisi G-06"; kurucu "Oyun Kurucusu".
--    Bildirim öneki "Oyun yönetimi (Görevli G-06): …" yerine kısa hâli "Oyun Yöneticisi G-06: …".
-- 3) Yönetim adına yazılan duyuru ve Yardım Masası yanıtı, yazan yönetici oyunda gözaltında olsa da engellenmez.
-- Oyuncu verisi değişmez. Tekrar çalıştırmak güvenlidir.

alter table oyun.yayinlar drop constraint if exists yayinlar_metin_check;
alter table oyun.yayinlar add constraint yayinlar_metin_check check (length(metin) >= 1 and length(metin) <= 6000);

create or replace function oyun.mod_imza(p oyun.profiller)
 returns text
 language sql
 stable
 set search_path to ''
as $function$
  select case when p.yonetici then 'Oyun Kurucusu'
              when exists (select 1 from oyun.moderatorler m where m.user_id = p.id) then 'Oyun Yöneticisi ' || oyun.mod_kod(p.id)
              else 'Oyun Yönetimi' end
$function$;

create or replace function public.admin_duyuru(p_metin text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.yetki_zorunlu('duyuru'); t timestamptz := oyun.simdi(); m text;
begin
  m := oyun.metin_temizle(p_metin, 5000);
  perform oyun.mod_log(p, 'duyuru', null, m);
  insert into oyun.yayinlar(tur, gonderen, metin, zaman, unvan)
  values ('sistem', p.id, m || E'\n\n— ' || oyun.mod_imza(p), t, 'Oyun Yönetimi');
  return jsonb_build_object('tamam', true, 'kitle', (select count(*) from oyun.profiller where not yasakli));
end $function$;

create or replace function public.yk_bildirim(p_hedef text, p_deger text, p_metin text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.yetki_zorunlu('duyuru'); t timestamptz := oyun.simdi(); u uuid; kisi int := 0; m text := oyun.yk_metin(p_metin, 500);
begin
  if m is null then raise exception 'Bildirim metni boş olamaz.'; end if;
  for u in select * from oyun.yk_hedefler(p_hedef, p_deger) loop
    perform oyun.bildir(u, format('%s: %s', oyun.mod_imza(p), m), t); kisi := kisi + 1;
  end loop;
  perform oyun.mod_log(p, 'yk_bildirim', oyun.yk_hedef_ad(p_hedef, p_deger), m);
  return jsonb_build_object('kisi', kisi);
end $function$;

-- Yönetim adına yazılanlar oyun içi konuşma değildir: oyunda gözaltında olan yöneticinin resmî duyurusu ve
-- Yardım Masası'ndaki yönetim yanıtı gözaltı yazı engeline takılmaz (kendi adına yazdıkları yine engellenir).
do $yama$
declare s text;
begin
  s := pg_get_functiondef('oyun.gozalti_yazi_engel_trg()'::regprocedure);
  if position('yonetim_adina' in s) = 0 then
    s := replace(s, 'if coalesce(j->>''rol'','''') in (''sistem'',''reklam'',''bilgi'') then return new; end if;',
      'if coalesce(j->>''rol'','''') in (''sistem'',''reklam'',''bilgi'') then return new; end if;' || E'\n' ||
      '  /* yonetim_adina */ if (tg_table_name = ''yayinlar'' and coalesce(j->>''tur'','''') = ''sistem'') or (tg_table_name = ''mesajlar'' and coalesce(j->>''gorevli'','''') = ''true'') then return new; end if;');
    execute s;
  end if;
end $yama$;

commit;
