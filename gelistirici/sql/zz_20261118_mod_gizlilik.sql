-- 18.11.2026 · MODERATÖR GİZLİLİĞİ: moderatörler oyuncu olarak oynar, kim olduğu oyunculara görünmez
-- 1) Takma görev kodu: her moderatörün sabit bir kodu vardır (G-01, G-02 …). Oyunculara giden bildirim, duyuru ve destek
--    yanıtlarında kullanıcı adı yerine bu kod görünür ("Oyun yönetimi (Görevli G-07)"). Kodun kime ait olduğunu yalnız yönetici bilir.
-- 2) Hiçbir oyuncu ekranı/RPC'si kimin moderatör olduğunu döndürmez (unvan, sohbet, profil, arama). Moderatörün kendi şikâyet ve
--    MASAK kayıtları yalnız yöneticiye görünür (diğer moderatörler ve kendisi göremez).
-- 3) Çıkar çatışması: moderatör aynı partideki, aynı cihazı kullanan ya da son 30 günde aralarında dava olan oyuncuya doğrudan
--    yaptırım uygulayamaz; yaptırım talebi açar, tarafsız başka bir moderatör karar verir.
-- 4) İfşa ve taklit koruması: moderatör sohbet, yayın ya da özel mesajda moderatör olduğunu söylerse mesaj yayınlanmaz, yöneticiye
--    bildirilir. Moderatör olmayan biri "ben moderatörüm" derse (dolandırıcılık riski) mesaj yayınlanmaz, kayda geçer.
-- 5) Gizlilik sözleşmesi: moderatör Moderasyon Merkezi'ni ilk açışta kuralları kabul eder; kabul tarihi kayda geçer.
-- Oyuncu verisi değişmez; moderatörlere yeni sütunla kod verilir.

alter table oyun.moderatorler add column if not exists kod_no integer;
alter table oyun.moderatorler add column if not exists sozlesme_at timestamptz;
create unique index if not exists moderatorler_kod_no on oyun.moderatorler(kod_no) where kod_no is not null;

-- Kodsuz moderatörlere (atanma sırasıyla) kod ver
update oyun.moderatorler m set kod_no = z.n
  from (select user_id, (select coalesce(max(kod_no), 0) from oyun.moderatorler) + row_number() over (order by zaman, user_id) n
          from oyun.moderatorler where kod_no is null) z
 where m.user_id = z.user_id;

create or replace function oyun.tg_mod_kod() returns trigger
language plpgsql set search_path to '' as $$
begin
  if new.kod_no is null then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('mod_kod'));
    select coalesce(max(kod_no), 0) + 1 into new.kod_no from oyun.moderatorler;
  end if;
  return new;
end $$;
create or replace trigger mod_kod before insert on oyun.moderatorler for each row execute function oyun.tg_mod_kod();

create or replace function oyun.mod_kod(u uuid) returns text
language sql stable set search_path to '' as $$
  select case when coalesce((select yonetici from oyun.profiller where id = u), false) then 'Yönetici'
              else coalesce((select 'G-' || lpad(kod_no::text, 2, '0') from oyun.moderatorler where user_id = u), 'Görevli') end
$$;

-- Oyunculara görünen imza: kullanıcı adı yerine görev kodu
create or replace function oyun.mod_imza(p oyun.profiller) returns text
language sql stable set search_path to '' as $$
  select case when p.yonetici then 'Oyun yöneticisi' else 'Görevli ' || oyun.mod_kod(p.id) end
$$;

create or replace function public.admin_duyuru(p_metin text)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('duyuru'); t timestamptz := oyun.simdi(); m text;
begin
  m := oyun.metin_temizle(p_metin, 2000);
  perform oyun.mod_log(p, 'duyuru', null, m);
  insert into oyun.yayinlar(tur, gonderen, metin, zaman, unvan)
  values ('sistem', p.id, m || E'\n\n— ' || oyun.mod_imza(p), t, 'Oyun Yönetimi');
  return jsonb_build_object('tamam', true, 'kitle', (select count(*) from oyun.profiller where not yasakli));
end $$;

-- ---------- Çıkar çatışması ----------
create or replace function oyun.mod_cikar_catismasi(p_mod uuid, h uuid) returns text
language sql stable set search_path to '' as $$
  select case
    when coalesce((select yonetici from oyun.profiller where id = p_mod), false) then null
    when exists (select 1 from oyun.profiller a join oyun.profiller b on b.id = h where a.id = p_mod and a.parti_id is not null and a.parti_id = b.parti_id)
      then 'Çıkar çatışması: bu oyuncuyla aynı partidesiniz.'
    when exists (select 1 from oyun.bagli_hesaplar(p_mod) x where x = h)
      then 'Çıkar çatışması: bu oyuncuyla aynı cihazı kullanıyorsunuz.'
    when exists (select 1 from oyun.adliye_davalar d where ((d.davaci = p_mod and d.davali = h) or (d.davaci = h and d.davali = p_mod))
                   and (d.durum = 'acik' or d.acilis > oyun.simdi() - interval '30 days'))
      then 'Çıkar çatışması: bu oyuncuyla aranızda dava var.'
  end
$$;

-- Yalnız koruma (yönetici/moderatöre işlem yapılamaz) — yaptırım talebi açmak için
create or replace function oyun.mod_koruma(p oyun.profiller, h uuid) returns void
language plpgsql set search_path to '' as $$
begin
  if p.yonetici then return; end if;
  if exists (select 1 from oyun.profiller where id = h and yonetici) or exists (select 1 from oyun.moderatorler where user_id = h) then
    raise exception 'Yöneticiye ya da başka bir moderatöre işlem yapamazsın; gerekirse "Yöneticiye ilet" kullan.';
  end if;
end $$;

-- Doğrudan yaptırım kapısı: koruma + çıkar çatışması
create or replace function oyun.korunan_hedef(p oyun.profiller, h uuid) returns void
language plpgsql set search_path to '' as $$
declare c text;
begin
  perform oyun.mod_koruma(p, h);
  c := oyun.mod_cikar_catismasi(p.id, h);
  if c is not null then raise exception '% Yaptırım talebi aç; tarafsız başka bir moderatör karar versin.', c; end if;
end $$;

-- Talep açmak çıkar çatışmasında da serbest (karar başkasında); koruma sürer
do $p$
declare s text := pg_get_functiondef('public.mod_talep_ac(text,text,numeric,text,text)'::regprocedure);
begin
  if position('oyun.mod_koruma(p, h.id)' in s) = 0 then
    s := replace(s, 'perform oyun.korunan_hedef(p, h.id);', 'perform oyun.mod_koruma(p, h.id);');
    if position('oyun.mod_koruma(p, h.id)' in s) = 0 then raise exception 'mod_talep_ac yaması uygulanamadı'; end if;
    execute s;
  end if;
end $p$;

-- Talebe karar verecek kişi de çatışmasız olmalı
create or replace function oyun.mod_talep_karar_yetkili(u uuid, p_tur text) returns boolean
language sql stable set search_path to '' as $$
  select case p_tur when 'engel' then oyun.yetkili(u, 'hesap_kapat')
                    when 'sustur' then oyun.yetkili(u, 'sustur')
                    else coalesce((select yonetici from oyun.profiller where id = u), false) end
$$;

-- ---------- Moderatörü ilgilendiren kayıtlar yalnız yöneticiye ----------
do $p$
declare s text;
begin
  s := pg_get_functiondef('public.admin_sikayetler(text)'::regprocedure);
  if position('mm_gizle' in s) = 0 then
    s := replace(s, 'from oyun.sikayetler s where s.durum = p_durum',
      'from oyun.sikayetler s where s.durum = p_durum and (p.yonetici or not exists (select 1 from oyun.moderatorler mm_gizle where mm_gizle.user_id = s.hedef_user))');
    if position('mm_gizle' in s) = 0 then raise exception 'admin_sikayetler yaması uygulanamadı'; end if;
    execute s;
  end if;
  s := pg_get_functiondef('public.admin_masak(text)'::regprocedure);
  if position('mm_gizle' in s) = 0 then
    s := replace(s, 'from (select * from oyun.masak where p_durum is null or durum = p_durum order by zaman desc limit 50) m',
      'from (select * from oyun.masak where (p_durum is null or durum = p_durum) and (p.yonetici or masak.user_id is null or not exists (select 1 from oyun.moderatorler mm_gizle where mm_gizle.user_id = masak.user_id)) order by zaman desc limit 50) m');
    if position('mm_gizle' in s) = 0 then raise exception 'admin_masak yaması uygulanamadı'; end if;
    execute s;
  end if;
  s := pg_get_functiondef('public.mod_merkez()'::regprocedure);
  if position('mm_gizle' in s) = 0 then
    s := replace(s, 'from (select min(zaman) ilk from oyun.sikayetler where durum = ''yeni'' group by',
      'from (select min(zaman) ilk from oyun.sikayetler where durum = ''yeni'' and (p.yonetici or not exists (select 1 from oyun.moderatorler mm_gizle where mm_gizle.user_id = sikayetler.hedef_user)) group by');
    s := replace(s, 'from oyun.masak where durum = ''yeni'') end',
      'from oyun.masak where durum = ''yeni'' and (p.yonetici or masak.user_id is null or not exists (select 1 from oyun.moderatorler mm_gizle2 where mm_gizle2.user_id = masak.user_id))) end');
    s := replace(s, '''atama'', m.zaman)', '''atama'', m.zaman, ''kod'', oyun.mod_kod(p.id), ''sozlesme_at'', m.sozlesme_at)');
    if position('mm_gizle2' in s) = 0 or position('sozlesme_at' in s) = 0 then raise exception 'mod_merkez yaması uygulanamadı'; end if;
    execute s;
  end if;
  s := pg_get_functiondef('public.admin_mod_ekip()'::regprocedure);
  if position('sozlesme_at' in s) = 0 then
    s := replace(s, '''rutbe'', m.rutbe,', '''rutbe'', m.rutbe, ''kod'', oyun.mod_kod(m.user_id), ''sozlesme_at'', m.sozlesme_at,');
    if position('sozlesme_at' in s) = 0 then raise exception 'admin_mod_ekip yaması uygulanamadı'; end if;
    execute s;
  end if;
  s := pg_get_functiondef('public.mod_dosya(text)'::regprocedure);
  if position('cikar_catismasi' in s) = 0 then
    s := replace(s, '''cevrimici'', h.son_gorulme > t - interval ''15 minutes'',', '''cevrimici'', h.son_gorulme > t - interval ''15 minutes'', ''cikar_catismasi'', oyun.mod_cikar_catismasi(p.id, h.id),');
    if position('cikar_catismasi' in s) = 0 then raise exception 'mod_dosya yaması uygulanamadı'; end if;
    execute s;
  end if;
end $p$;

-- ---------- İfşa ve taklit koruması ----------
create or replace function oyun.mod_ifsa_metni(t text) returns boolean
language sql immutable set search_path to '' as $$
  select (' ' || regexp_replace(translate(lower(replace(replace(coalesce(t, ''), 'İ', 'i'), 'I', 'ı')), 'çğıöşüâîû', 'cgiosuaiu'), '[^a-z0-9]+', ' ', 'g') || ' ')
    ~ ' (moderatorum|moderatoruz|moderatorlugum|moderatorlerdenim|moderatorlerdeniz|modum|moduz|adminim|adminiz|yetkiliyim|yetkiliyiz|ben (bir )?(mod|moderator|admin|yetkili)|biz (de )?(mod|moderator|admin)|(oyun )?yonetim(indeyim|ekibindeyim|deyim|denim)|mod ekibindeyim|moderasyondayim|moderasyon ekibindeyim|banlayabilirim|susturabilirim|engelleyebilirim|hesabini kapatabilirim|kaydini onayladim|kaydini reddettim|seni (banlarim|susturdum|susturacagim|engellerim)) '
$$;

create or replace function oyun.tg_mod_ifsa() returns trigger
language plpgsql set search_path to '' as $$
declare u uuid; mod boolean; t timestamptz := now(); r record; j jsonb := to_jsonb(new);
begin
  u := coalesce(j->>'user_id', j->>'gonderen')::uuid;
  if u is null or coalesce(new.gizli, false) or not oyun.mod_ifsa_metni(new.metin) then return new; end if;
  if coalesce(j->>'tur', '') = 'sistem' then return new; end if;
  mod := exists (select 1 from oyun.moderatorler where user_id = u);
  if coalesce((select yonetici from oyun.profiller where id = u), false) then return new; end if;
  new.gizli := true;
  insert into oyun.mod_kayit(zaman, user_id, kad, islem, hedef, ayrinti)
  values (t, u, oyun.kad(u), case when mod then 'ifsa_suphe' else 'mod_taklit' end, tg_table_name, left(new.metin, 300));
  perform oyun.bildir(u, case when mod
      then 'Mesajın yayınlanmadı: moderatör gizlilik sözleşmesi gereği oyunda moderatör olduğunu söyleyemezsin. Durum yöneticiye bildirildi.'
      else 'Mesajın yayınlanmadı: oyunda kimse oyun yönetiminden olduğunu iddia edemez. Oyun yönetimi hiçbir zaman sohbetten şifre, para ya da hesap bilgisi istemez.' end, t);
  if not exists (select 1 from oyun.mod_kayit k where k.user_id = u and k.islem in ('ifsa_suphe','mod_taklit') and k.zaman > t - interval '30 minutes' and k.zaman < t) then
    for r in select id from oyun.profiller where yonetici and not yasakli limit 5 loop
      perform oyun.bildir(r.id, format('Moderasyon uyarısı: %s %s (%s). Ayrıntı: Moderasyon Merkezi › Denetim günlüğü.', oyun.kad(u),
        case when mod then 'moderatör olduğunu açıklamaya çalıştı' else 'kendini oyun yönetiminden gösterdi' end,
        case tg_table_name when 'mesajlar' then 'sohbet' when 'ozel' then 'özel mesaj' else 'yayın' end), t);
    end loop;
  end if;
  return new;
end $$;
create or replace trigger mod_ifsa before insert on oyun.mesajlar for each row execute function oyun.tg_mod_ifsa();
create or replace trigger mod_ifsa before insert on oyun.ozel for each row execute function oyun.tg_mod_ifsa();
create or replace trigger mod_ifsa before insert on oyun.yayinlar for each row execute function oyun.tg_mod_ifsa();

-- Gizlenen özel mesaj ve yayın için anlık bildirim (push) gönderilmez
do $p$
declare f text; s text;
begin
  foreach f in array array['oyun.tg_ozel_push()','oyun.tg_yayin_push()'] loop
    if to_regprocedure(f) is null then continue; end if;
    s := pg_get_functiondef(f::regprocedure);
    if position('mod_ifsa_gizli' in s) = 0 then
      s := regexp_replace(s, '\mbegin\M', 'begin /* mod_ifsa_gizli */ if new.gizli then return new; end if;');
      if position('mod_ifsa_gizli' in s) = 0 then raise exception '% yaması uygulanamadı', f; end if;
      execute s;
    end if;
  end loop;
end $p$;

-- ---------- Gizlilik sözleşmesi ----------
create or replace function public.mod_sozlesme_kabul()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); t timestamptz := oyun.simdi();
begin
  if p.yonetici and not exists (select 1 from oyun.moderatorler where user_id = p.id) then return jsonb_build_object('tamam', true); end if;
  update oyun.moderatorler set sozlesme_at = coalesce(sozlesme_at, t) where user_id = p.id;
  perform oyun.mod_log(p, 'sozlesme_kabul', null, 'Moderatör gizlilik ve tarafsızlık sözleşmesi kabul edildi');
  return jsonb_build_object('tamam', true, 'zaman', t);
end $$;

do $g$
begin
  revoke all on function public.mod_sozlesme_kabul() from public, anon;
  grant execute on function public.mod_sozlesme_kabul() to authenticated;
end $g$;
