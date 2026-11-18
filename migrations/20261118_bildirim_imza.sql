-- 18.11.2026 · Moderatör/yönetici bildirimlerinde gönderenin kullanıcı adı görünür
-- Elle gönderilen bildirim, herkese açık duyuru ve destek yanıtı imzalı gider: kimin gönderdiği belli olur.
-- (Otomatik yaptırım bildirimleri — susturma, engel — imzasızdır; moderatörü hedef olmaktan korur. Kim yaptığı günlükte durur.)

create or replace function oyun.mod_imza(p oyun.profiller) returns text
language sql stable set search_path to '' as $$
  select case when p.yonetici then 'Oyun yöneticisi' else 'Moderatör' end || ' ' || p.kad
$$;

create or replace function public.yk_bildirim(p_hedef text, p_deger text, p_metin text)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('duyuru'); t timestamptz := oyun.simdi(); u uuid; kisi int := 0; m text := oyun.yk_metin(p_metin, 500);
begin
  if m is null then raise exception 'Bildirim metni boş olamaz.'; end if;
  for u in select * from oyun.yk_hedefler(p_hedef, p_deger) loop
    perform oyun.bildir(u, format('Oyun yönetimi (%s): %s', oyun.mod_imza(p), m), t); kisi := kisi + 1;
  end loop;
  perform oyun.mod_log(p, 'yk_bildirim', oyun.yk_hedef_ad(p_hedef, p_deger), m);
  return jsonb_build_object('kisi', kisi);
end $$;

create or replace function public.admin_duyuru(p_metin text)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('duyuru'); t timestamptz := oyun.simdi(); m text;
begin
  m := oyun.metin_temizle(p_metin, 2000);
  perform oyun.mod_log(p, 'duyuru', null, m);
  insert into oyun.yayinlar(tur, gonderen, metin, zaman, unvan)
  values ('sistem', p.id, m || E'\n\n— ' || oyun.mod_imza(p), t, 'Oyun Yönetimi · ' || p.kad);
  return jsonb_build_object('tamam', true, 'kitle', (select count(*) from oyun.profiller where not yasakli));
end $$;

create or replace function public.mod_destek_yanitla(p_id bigint, p_metin text, p_kapat boolean default false)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('destek'); d oyun.destek_talep; t timestamptz := oyun.simdi(); m text := nullif(btrim(coalesce(p_metin, '')), '');
begin
  select * into d from oyun.destek_talep where id = p_id for update;
  if d.id is null then raise exception 'Destek talebi bulunamadı.'; end if;
  if d.durum = 'kapali' then raise exception 'Bu talep kapatılmış.'; end if;
  if m is null and not coalesce(p_kapat, false) then raise exception 'Yanıt yaz (2-1000 karakter).'; end if;
  if m is not null and (char_length(m) < 2 or char_length(m) > 1000) then raise exception 'Yanıt 2-1000 karakter olmalı.'; end if;
  update oyun.destek_talep set yanit = coalesce(m, yanit), yanit_zaman = case when m is not null then now() else yanit_zaman end,
         yanitlayan = p.id, durum = case when p_kapat then 'kapali' else 'yanitlandi' end, okundu = false
   where id = d.id;
  perform oyun.bildir(d.user_id, case when m is not null then format('Destek yanıtı (talep #%s, %s): %s', d.id, oyun.mod_imza(p), m)
                                      else format('Destek talebin #%s kapatıldı (%s).', d.id, oyun.mod_imza(p)) end, t);
  perform oyun.mod_log(p, case when p_kapat then 'destek_kapat' else 'destek_yanit' end, oyun.kad(d.user_id), format('#%s %s', d.id, coalesce(left(m, 200), '')));
  return public.mod_destek('acik');
end $$;
