-- 18.11.2026 · İFADEYE ÇAĞIRMA ve ZORLA GETİRME (gözaltı modülüne bağlı)
-- Gerçek usul (CMK m.145-146): ifadeye çağrılan şüpheli çağrıya uymazsa zorla getirilir. Oyunda:
--   • Cumhurbaşkanı ve İçişleri Bakanı bir oyuncuyu konusu ve süresi belirtilerek ifadeye çağırır (süre 6-72 saat, oyun kuralı).
--   • Oyuncu süresi içinde yazılı ifadesini verir ya da çağrıyı reddeder.
--   • Süresinde gelmeyen ya da reddeden oyuncu 72 saat içinde "zorla getirme" kararıyla gözaltına alınabilir.
--     Bu gözaltı mevcut CB/İçişleri gözaltısıdır (yonetim_tutuklama): avukat, baro müdafi, iletişim kısıtı ve tahliye aynen işler.
--     Sebepsiz gözaltı kotasını harcamaz; kendi günlük ülke sınırı vardır. Kişi başı haftalık gözaltı sınırı ve 48 saat ara korunur.
--   • Görevdeki Cumhurbaşkanı ve dokunulmazlığı süren milletvekili ifadeye çağrılamaz (Anayasa m.83, m.105).
--   • Geç gelen oyuncu, zorla getirilmeden önce ifadesini verirse zorla getirme düşer.
-- Oyuncu verisi değişmez; yalnız yeni tablo/sütun/fonksiyon.

create table if not exists oyun.ifade_cagri(
  id          bigserial primary key,
  hedef       uuid not null,
  cagiran     uuid not null,
  makam       text not null,
  konu        text not null,
  zaman       timestamptz not null,
  son         timestamptz not null,
  durum       text not null default 'bekliyor' check (durum in ('bekliyor','ifade_verildi','reddetti','gelmedi','zorla_getirildi','iptal')),
  ifade       text,
  ifade_at    timestamptz,
  ret_gerekce text,
  ret_at      timestamptz,
  gozalti_id  bigint,
  zorla_at    timestamptz,
  zorla_veren uuid,
  iptal_eden  uuid,
  bildirildi  boolean not null default false
);
create index if not exists ifade_cagri_hedef on oyun.ifade_cagri(hedef, zaman desc);
create index if not exists ifade_cagri_bekleyen on oyun.ifade_cagri(son) where durum = 'bekliyor';
create index if not exists ifade_cagri_zaman on oyun.ifade_cagri(zaman desc);
alter table oyun.ifade_cagri enable row level security;
revoke all on oyun.ifade_cagri from public, anon, authenticated;

alter table oyun.yonetim_tutuklama add column if not exists ifade_cagri_id bigint;

insert into oyun.tarife(kod, deger, birim, kategori, ad, aciklama) values
  ('ifade_sure_varsayilan', 24, 'saat', 'kural', 'İfadeye çağrı: varsayılan süre', 'Çağrılan oyuncunun ifade vermek için varsayılan süresi'),
  ('ifade_sure_min', 6, 'saat', 'kural', 'İfadeye çağrı: en kısa süre', 'Oyun kuralı; gece uyuyan oyuncu mağdur olmasın diye en az 6 saat'),
  ('ifade_sure_max', 72, 'saat', 'kural', 'İfadeye çağrı: en uzun süre', null),
  ('ifade_cagri_gunluk', 10, 'kişi', 'kural', 'İfadeye çağrı: yetkili başına günlük', 'CB ve İçişleri Bakanı ayrı ayrı'),
  ('ifade_kisi_haftalik', 2, 'kez', 'kural', 'İfadeye çağrı: aynı kişiye haftalık', null),
  ('ifade_zorla_pencere', 72, 'saat', 'kural', 'Zorla getirme kararı için süre', 'Gelmedi/reddetti durumundan sonra bu süre içinde gözaltı kararı verilebilir'),
  ('ifade_zorla_saat', 6, 'saat', 'kural', 'Zorla getirme gözaltı süresi', null),
  ('ifade_zorla_ulke_gunluk', 10, 'kişi', 'kural', 'Zorla getirme: ülke geneli günlük', 'Sebepsiz gözaltı kotasından ayrıdır')
on conflict (kod) do nothing;

-- Sebepsiz CB/İçişleri gözaltı kotası, zorla getirme gözaltılarını saymaz
create or replace function oyun.yonetim_gozalti_kota_bilgi(u uuid) returns jsonb
language sql stable set search_path to '' as $$
  select jsonb_build_object(
    'kota', oyun.gozalti_ayar('yonetim_gozalti_gunluk_kota',2)::int,
    'kullanilan', (select count(*) from oyun.yonetim_tutuklama y where y.yetkili=u and y.ifade_cagri_id is null
                   and (y.baslangic at time zone 'Europe/Istanbul')::date = (oyun.simdi() at time zone 'Europe/Istanbul')::date)::int,
    'ulke_kota', oyun.gozalti_ayar('yonetim_gozalti_ulke_gunluk',3)::int,
    'ulke_kullanilan', (select count(*) from oyun.yonetim_tutuklama y where y.ifade_cagri_id is null
                   and (y.baslangic at time zone 'Europe/Istanbul')::date = (oyun.simdi() at time zone 'Europe/Istanbul')::date)::int,
    'kisi_haftalik', oyun.gozalti_ayar('gozalti_kisi_haftalik',2)::int,
    'sure_saat', oyun.gozalti_ayar('yonetim_gozalti_saat',3),
    'ara_saat', oyun.gozalti_ayar('gozalti_kisi_ara_saat',48))
$$;

do $y$
declare s text := pg_get_functiondef('public.yonetim_tutuklama_yap(text,text)'::regprocedure);
begin
  if position('ifade_cagri_id is null' in s) = 0 then
    s := replace(s, 'from oyun.yonetim_tutuklama y2 where (y2.baslangic', 'from oyun.yonetim_tutuklama y2 where y2.ifade_cagri_id is null and (y2.baslangic');
    if position('ifade_cagri_id is null' in s) = 0 then raise exception 'yonetim_tutuklama_yap yaması uygulanamadı'; end if;
    execute s;
  end if;
end $y$;

create or replace function oyun.ifade_makam(u uuid) returns text
language sql stable set search_path to '' as $$
  select case when oyun.cb_mi(u) then 'cumhurbaskani' when oyun.bm_yetki(u, 'icisleri') is not null then 'icisleri_bakani' end
$$;
create or replace function oyun.ifade_makam_ad(m text) returns text
language sql immutable set search_path to '' as $$
  select case m when 'cumhurbaskani' then 'Cumhurbaşkanlığı' when 'icisleri_bakani' then 'İçişleri Bakanlığı' else 'Devlet' end
$$;

-- Süresi dolan çağrılar "gelmedi" olur; iki tarafa bildirim gider (zamanlayıcı, 2 dk)
create or replace function oyun.ifade_tick() returns integer
language plpgsql set search_path to '' as $$
declare r record; n int := 0; t timestamptz := oyun.simdi(); pen numeric := oyun.gozalti_ayar('ifade_zorla_pencere', 72);
begin
  for r in select * from oyun.ifade_cagri where durum = 'bekliyor' and son <= t order by son limit 200 for update skip locked loop
    begin
      update oyun.ifade_cagri set durum = 'gelmedi', bildirildi = true where id = r.id;
      perform oyun.bildir(r.hedef, format('İfade çağrısı #%s için süre doldu ve ifade vermediniz. %s saat içinde zorla getirme (gözaltı) kararı verilebilir. Hâlâ ifade verebilirsiniz: Menü › Gözaltı ve Avukat.', r.id, pen::int), t);
      perform oyun.bildir(r.cagiran, format('%s, #%s numaralı ifade çağrısına süresinde gelmedi. %s saat içinde zorla getirme kararı verebilirsiniz: Menü › Gözaltı ve Avukat.', oyun.kad(r.hedef), r.id, pen::int), t);
      n := n + 1;
    exception when others then null;
    end;
  end loop;
  return n;
end $$;
insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
select 'ifade_cagri', 'select oyun.ifade_tick()', 2, 0, 61, true
where to_regclass('oyun.zamanlayici_adim') is not null and not exists (select 1 from oyun.zamanlayici_adim where adim = 'ifade_cagri');

create or replace function oyun.ifade_json(c oyun.ifade_cagri, ben uuid, yetkili boolean) returns jsonb
language sql stable set search_path to '' as $$
  select jsonb_build_object('id', c.id, 'hedef', oyun.kad(c.hedef), 'cagiran', oyun.kad(c.cagiran), 'makam', oyun.ifade_makam_ad(c.makam),
    'konu', c.konu, 'zaman', c.zaman, 'son', c.son,
    'durum', case when c.durum = 'bekliyor' and c.son <= oyun.simdi() then 'gelmedi' else c.durum end,
    'ifade', case when yetkili or c.hedef = ben then c.ifade end, 'ifade_at', c.ifade_at,
    'ret_gerekce', c.ret_gerekce, 'ret_at', c.ret_at, 'zorla_at', c.zorla_at, 'zorla_veren', oyun.kad(c.zorla_veren), 'gozalti_id', c.gozalti_id,
    'zorla_son', case when c.durum in ('gelmedi','reddetti') or (c.durum = 'bekliyor' and c.son <= oyun.simdi())
                      then coalesce(c.ret_at, c.son) + make_interval(secs => oyun.gozalti_ayar('ifade_zorla_pencere', 72) * 3600) end,
    'benim', c.hedef = ben, 'gozaltinda', oyun.gozalti_aktif(c.hedef) is not null)
$$;

-- ---------------------------------------------------------------------
-- RPC'ler
-- ---------------------------------------------------------------------
create or replace function public.ifade_cagir(p_kad text, p_konu text, p_sure_saat numeric default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); m text := oyun.ifade_makam(auth.uid()); h oyun.profiller; t timestamptz := oyun.simdi();
        k text := btrim(coalesce(p_konu, '')); s numeric; v_id bigint; e text;
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  if m is null then raise exception 'İfadeye çağırma yetkisi yalnız Cumhurbaşkanı ve İçişleri Bakanındadır.'; end if;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, ''))) and not yasakli;
  if h.id is null then raise exception 'Bu kullanıcı adına ait oyuncu bulunamadı.'; end if;
  if h.id = u then raise exception 'Kendinizi ifadeye çağıramazsınız.'; end if;
  e := oyun.dokunulmazlik_engel(h.id, 'ceza');
  if e is not null then raise exception '%', replace(e, 'ceza davası görülemez', 'ifadeye çağrılamaz (soruşturma yapılamaz)'); end if;
  if char_length(k) < 10 or char_length(k) > 600 then raise exception 'İfade konusu 10-600 karakter olmalı (hangi olay hakkında?).'; end if;
  s := coalesce(p_sure_saat, oyun.gozalti_ayar('ifade_sure_varsayilan', 24));
  if s < oyun.gozalti_ayar('ifade_sure_min', 6) or s > oyun.gozalti_ayar('ifade_sure_max', 72) then
    raise exception 'Süre %-% saat arasında olmalı.', oyun.gozalti_ayar('ifade_sure_min', 6)::int, oyun.gozalti_ayar('ifade_sure_max', 72)::int;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ifade:' || h.id::text));
  if exists (select 1 from oyun.ifade_cagri where hedef = h.id and durum = 'bekliyor' and son > t) then
    raise exception '% hakkında süresi dolmamış bir ifade çağrısı zaten var.', h.kad;
  end if;
  if oyun.gozalti_aktif(h.id) is not null then raise exception '% şu an gözaltında.', h.kad; end if;
  if (select count(*) from oyun.ifade_cagri where cagiran = u and (zaman at time zone 'Europe/Istanbul')::date = (t at time zone 'Europe/Istanbul')::date)
     >= oyun.gozalti_ayar('ifade_cagri_gunluk', 10) then
    raise exception 'Bugünkü ifade çağrısı hakkınız doldu (% kişi).', oyun.gozalti_ayar('ifade_cagri_gunluk', 10)::int;
  end if;
  if (select count(*) from oyun.ifade_cagri where hedef = h.id and durum <> 'iptal' and zaman > t - interval '7 days') >= oyun.gozalti_ayar('ifade_kisi_haftalik', 2) then
    raise exception '% son 7 günde % kez ifadeye çağrıldı; daha fazla çağrılamaz.', h.kad, oyun.gozalti_ayar('ifade_kisi_haftalik', 2)::int;
  end if;
  insert into oyun.ifade_cagri(hedef, cagiran, makam, konu, zaman, son)
  values (h.id, u, m, k, t, t + make_interval(secs => s * 3600)) returning id into v_id;
  perform oyun.bildir(h.id, format('%s sizi ifadeye çağırdı (#%s). Konu: %s · Son: %s. İfadenizi vermek ya da çağrıyı reddetmek için: Menü › Gözaltı ve Avukat. Süresinde gelmez ya da reddederseniz zorla getirilip gözaltına alınabilirsiniz.',
     oyun.ifade_makam_ad(m), v_id, k, to_char((t + make_interval(secs => s * 3600)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), t);
  return jsonb_build_object('tamam', true, 'id', v_id, 'son', t + make_interval(secs => s * 3600));
end $$;

create or replace function public.ifade_ver(p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); c oyun.ifade_cagri; t timestamptz := oyun.simdi(); m text := btrim(coalesce(p_metin, '')); gec boolean;
begin
  select * into c from oyun.ifade_cagri where id = p_id for update;
  if c.id is null or c.hedef is distinct from u then raise exception 'Size ait bir ifade çağrısı bulunamadı.'; end if;
  if c.ifade is not null then raise exception 'İfadenizi zaten verdiniz.'; end if;
  if c.durum in ('iptal','reddetti') then raise exception 'Bu çağrı %.', case c.durum when 'iptal' then 'iptal edildi' else 'sizce reddedildi' end; end if;
  if char_length(m) < 20 or char_length(m) > 3000 then raise exception 'İfade 20-3000 karakter olmalı.'; end if;
  gec := c.durum = 'gelmedi' or (c.durum = 'bekliyor' and c.son <= t);
  update oyun.ifade_cagri set ifade = m, ifade_at = t,
         durum = case when c.durum = 'zorla_getirildi' then 'zorla_getirildi' else 'ifade_verildi' end where id = c.id;
  perform oyun.bildir(c.cagiran, format('%s, #%s numaralı çağrıya ifadesini verdi%s. Okumak için: Menü › Gözaltı ve Avukat.', oyun.kad(u), c.id,
     case when c.durum = 'zorla_getirildi' then ' (gözaltındayken; tahliyeye siz karar verirsiniz)' when gec then ' (süre dolduktan sonra)' else '' end), t);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.ifade_reddet(p_id bigint, p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); c oyun.ifade_cagri; t timestamptz := oyun.simdi(); g text := nullif(left(btrim(coalesce(p_gerekce, '')), 500), '');
begin
  select * into c from oyun.ifade_cagri where id = p_id for update;
  if c.id is null or c.hedef is distinct from u then raise exception 'Size ait bir ifade çağrısı bulunamadı.'; end if;
  if c.durum <> 'bekliyor' or c.son <= t then raise exception 'Bu çağrı artık reddedilemez.'; end if;
  update oyun.ifade_cagri set durum = 'reddetti', ret_gerekce = g, ret_at = t where id = c.id;
  perform oyun.bildir(c.cagiran, format('%s, #%s numaralı ifade çağrısını reddetti.%s %s saat içinde zorla getirme (gözaltı) kararı verebilirsiniz.',
     oyun.kad(u), c.id, coalesce(' Gerekçe: ' || g, ''), oyun.gozalti_ayar('ifade_zorla_pencere', 72)::int), t);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.ifade_zorla_getir(p_id bigint, p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); m text := oyun.ifade_makam(auth.uid()); c oyun.ifade_cagri; t timestamptz := oyun.simdi();
        bas timestamptz; e text; sure interval; yid bigint; g text;
begin
  if m is null then raise exception 'Zorla getirme kararı yalnız Cumhurbaşkanı ve İçişleri Bakanındadır.'; end if;
  select * into c from oyun.ifade_cagri where id = p_id for update;
  if c.id is null then raise exception 'Çağrı bulunamadı.'; end if;
  if c.durum = 'bekliyor' and c.son > t then raise exception 'İfade süresi henüz dolmadı (son: %).', to_char(c.son at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'); end if;
  if c.durum not in ('bekliyor','gelmedi','reddetti') or c.ifade is not null then raise exception 'Bu çağrı için zorla getirme kararı verilemez (oyuncu ifade verdi ya da çağrı kapandı).'; end if;
  bas := coalesce(c.ret_at, c.son);
  if t > bas + make_interval(secs => oyun.gozalti_ayar('ifade_zorla_pencere', 72) * 3600) then
    raise exception 'Zorla getirme süresi (% saat) geçti; yeni bir ifade çağrısı yapın.', oyun.gozalti_ayar('ifade_zorla_pencere', 72)::int;
  end if;
  if c.hedef = u then raise exception 'Kendiniz hakkında karar veremezsiniz.'; end if;
  e := oyun.dokunulmazlik_engel(c.hedef, 'ceza');
  if e is not null then raise exception 'Oyuncu artık dokunulmazlığa sahip; zorla getirilemez.'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(c.hedef::text));
  if oyun.gozalti_aktif(c.hedef) is not null then raise exception 'Oyuncu zaten gözaltında.'; end if;
  e := oyun.gozalti_hedef_engel(c.hedef);
  if e is not null then raise exception '%', e; end if;
  if (select count(*) from oyun.yonetim_tutuklama y where y.ifade_cagri_id is not null
       and (y.baslangic at time zone 'Europe/Istanbul')::date = (t at time zone 'Europe/Istanbul')::date) >= oyun.gozalti_ayar('ifade_zorla_ulke_gunluk', 10) then
    raise exception 'Bugünkü ülke geneli zorla getirme sınırı (% kişi) doldu.', oyun.gozalti_ayar('ifade_zorla_ulke_gunluk', 10)::int;
  end if;
  sure := make_interval(secs => greatest(1, least(24, oyun.gozalti_ayar('ifade_zorla_saat', 6))) * 3600);
  g := format('Zorla getirme (CMK m.146): #%s numaralı ifade çağrısına %s. Konu: %s%s', c.id,
              case when c.durum = 'reddetti' then 'uymayı reddetti' else 'süresinde gelmedi' end, left(c.konu, 300),
              coalesce(' · ' || nullif(left(btrim(coalesce(p_gerekce, '')), 200), ''), ''));
  insert into oyun.yonetim_tutuklama(hedef, yetkili, makam, gerekce, baslangic, bitis, ifade_cagri_id)
  values (c.hedef, u, m, g, t, t + sure, c.id) returning id into yid;
  update oyun.ifade_cagri set durum = 'zorla_getirildi', gozalti_id = yid, zorla_at = t, zorla_veren = u where id = c.id;
  perform oyun.bildir(c.hedef, format('%s, ifade çağrısına uymadığınız için zorla getirilmenize ve gözaltına alınmanıza karar verdi (dosya #%s). İfadenizi gözaltındayken de verebilirsiniz.', oyun.ifade_makam_ad(m), yid), t);
  perform oyun.gozalti_basladi_bildir(c.hedef, 'yonetim', yid, t + sure);
  if c.cagiran <> u then perform oyun.bildir(c.cagiran, format('#%s numaralı çağrınız için %s zorla getirme kararı verdi.', c.id, oyun.kad(u)), t); end if;
  return jsonb_build_object('tamam', true, 'gozalti_id', yid, 'bitis', t + sure);
end $$;

create or replace function public.ifade_iptal(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); c oyun.ifade_cagri; t timestamptz := oyun.simdi();
begin
  if oyun.ifade_makam(u) is null then raise exception 'Yalnız Cumhurbaşkanı ve İçişleri Bakanı iptal edebilir.'; end if;
  select * into c from oyun.ifade_cagri where id = p_id for update;
  if c.id is null then raise exception 'Çağrı bulunamadı.'; end if;
  if c.durum not in ('bekliyor','gelmedi','reddetti') then raise exception 'Bu çağrı zaten kapandı.'; end if;
  update oyun.ifade_cagri set durum = 'iptal', iptal_eden = u where id = c.id;
  perform oyun.bildir(c.hedef, format('İfade çağrısı #%s iptal edildi; ifade vermeniz gerekmiyor.', c.id), t);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.ifade_cagrilari()
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); m text := oyun.ifade_makam(auth.uid()); y boolean; t timestamptz := oyun.simdi();
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  y := m is not null;
  return jsonb_build_object(
    'yetkili', y, 'makam', oyun.ifade_makam_ad(m),
    'ayar', jsonb_build_object('varsayilan', oyun.gozalti_ayar('ifade_sure_varsayilan', 24), 'min', oyun.gozalti_ayar('ifade_sure_min', 6),
            'max', oyun.gozalti_ayar('ifade_sure_max', 72), 'pencere', oyun.gozalti_ayar('ifade_zorla_pencere', 72), 'zorla_saat', oyun.gozalti_ayar('ifade_zorla_saat', 6),
            'gunluk', oyun.gozalti_ayar('ifade_cagri_gunluk', 10),
            'bugun', case when y then (select count(*) from oyun.ifade_cagri where cagiran = u and (zaman at time zone 'Europe/Istanbul')::date = (t at time zone 'Europe/Istanbul')::date) end),
    'benim', coalesce((select jsonb_agg(oyun.ifade_json(c, u, y) order by c.zaman desc) from (
        select * from oyun.ifade_cagri where hedef = u and (durum in ('bekliyor','gelmedi','reddetti') or zaman > t - interval '14 days') order by zaman desc limit 20) c), '[]'::jsonb),
    'dosyalar', case when y then coalesce((select jsonb_agg(oyun.ifade_json(c, u, y) order by (c.durum in ('bekliyor','gelmedi','reddetti')) desc, c.zaman desc) from (
        select * from oyun.ifade_cagri where durum in ('bekliyor','gelmedi','reddetti') or zaman > t - interval '14 days' order by zaman desc limit 100) c), '[]'::jsonb) end);
end $$;

do $g$
declare f text;
begin
  foreach f in array array['public.ifade_cagir(text,text,numeric)','public.ifade_ver(bigint,text)','public.ifade_reddet(bigint,text)',
                           'public.ifade_zorla_getir(bigint,text)','public.ifade_iptal(bigint)','public.ifade_cagrilari()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  revoke all on function oyun.ifade_tick() from public, anon, authenticated;
end $g$;
