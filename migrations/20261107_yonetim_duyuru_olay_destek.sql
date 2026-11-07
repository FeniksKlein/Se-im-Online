-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 173) SÜPER YÖNETİCİ PORTALI · AŞAMA 5
--  Duyuru merkezi, olay merkezi, destek merkezi (07.11.2026)
--
--  İşlem:  duyuru_yayinla — bildirim kutusu (hedef il / parti) ve/veya haber akışı; hemen ya da ileri tarihe planlı.
--                           Geri alma: planlıysa iptal, gönderildiyse kutudan gizle + haber kaydını kaldır.
--          olay_baslat    — ulusal kriz (uk_baslat), ülke krizi (kriz_tick ile aynı kayıt), belediye krizi
--                           (belediye_kriz_baslat). Oyunun kendi kriz motoru çalışır; geri alınamaz.
--          sikayet_karar  — şikâyet edilen içeriği gizle / yok say, isteğe bağlı 1-7 gün susturma (geri alınabilir).
--          destek_yanitla — destek talebine ya da yönetime gelen özel mesaja yanıt.
--  Okuma:  yp_duyurular, yp_olaylar, yp_destek
--  Oyuncu: destek_gonder, destek_taleplerim (uygulamaya "Sorun bildir" ekranı bir sonraki sürümde bağlanır)
--
--  Duyuru bandı ayrı işlem değildir: canlı ayarlardaki uygulama.duyuru_bandi (başlangıç / bitiş saatli) kullanılır.
--  Oyuncu verisini silmez veya sıfırlamaz.
-- =====================================================================

insert into oyun.yp_katalog (islem, baslik, aciklama, grup, kritik, geri_alinabilir, onay_metni) values
  ('duyuru_yayinla', 'Duyuru yayınla', 'Oyun Yönetimi adına bildirim kutusuna ve/veya haber akışına duyuru yayınlar; hedef il / parti seçilebilir, ileri tarihe planlanabilir.', 'duyuru', false, true, null),
  ('olay_baslat', 'Olay / kriz başlat', 'Oyunun kriz motorunu elle tetikler: ulusal kriz, ülke krizi ya da bir ilde belediye krizi. Etkiler başladığı anda uygulanır.', 'olay', true, false, 'ONAYLIYORUM'),
  ('sikayet_karar', 'Şikâyet kararı', 'Şikâyet edilen içeriği gizler ya da yok sayar; gerekirse içeriğin sahibini 1 veya 7 gün susturur.', 'destek', false, true, null),
  ('destek_yanitla', 'Destek yanıtı', 'Destek talebine ya da yönetime gelen özel mesaja yanıt verir; talebi kapatabilir.', 'destek', false, false, null)
on conflict (islem) do update set baslik = excluded.baslik, aciklama = excluded.aciklama, grup = excluded.grup,
  kritik = excluded.kritik, geri_alinabilir = excluded.geri_alinabilir, onay_metni = excluded.onay_metni;

-- ---------------------------------------------------------------------
-- 1) Tablolar
-- ---------------------------------------------------------------------
create table if not exists oyun.yp_duyuru_plan (
  id bigserial primary key,
  islem_id bigint not null,
  zaman timestamptz not null,
  durum text not null default 'bekliyor' check (durum in ('bekliyor', 'gonderildi', 'iptal', 'basarisiz')),
  icerik jsonb not null,
  sonuc jsonb,
  hata text,
  gonderim timestamptz
);
create index if not exists yp_duyuru_plan_bekleyen on oyun.yp_duyuru_plan (zaman) where durum = 'bekliyor';
alter table oyun.yp_duyuru_plan enable row level security;

create table if not exists oyun.destek_talep (
  id bigserial primary key,
  user_id uuid not null,
  kategori text not null check (kategori in ('hata', 'hesap', 'oyuncu', 'oneri', 'diger')),
  metin text not null,
  surum text,
  platform text,
  zaman timestamptz not null default now(),
  durum text not null default 'yeni' check (durum in ('yeni', 'yanitlandi', 'kapali')),
  yanit text,
  yanit_zaman timestamptz,
  yanitlayan uuid,
  okundu boolean not null default true
);
create index if not exists destek_talep_kullanici on oyun.destek_talep (user_id, zaman desc);
create index if not exists destek_talep_acik on oyun.destek_talep (zaman desc) where durum <> 'kapali';
alter table oyun.destek_talep enable row level security;   -- politika yok: yalnız security definer RPC'ler okur/yazar

-- Yönetim duyurusu hedefliyse telefon bildirimi de yalnız o kitleye gitsin (push şu an kapalı; açıldığında doğru çalışsın).
create or replace function oyun.tg_yayin_push() returns trigger language plpgsql
set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $$
declare k text := case when new.tur = 'sistem' then 'Oyun Yönetimi' else oyun.kad(new.gonderen) || ' · ' || new.unvan end;
begin
  if new.tur = 'sistem' and new.hedef_il is null and new.hedef_parti is null then
    perform oyun.push_konuya('duyuru', null, 'Oyun Yönetimi', new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_il is null and new.hedef_parti is null then
    perform oyun.push_konuya('p_tum', null, k, new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_parti is null then
    perform oyun.push_konuya('p_il_' || new.hedef_il, null, k, new.metin, '{"ekran":"bildirim"}');
  elsif new.hedef_il is null then
    perform oyun.push_konuya('p_parti_' || new.hedef_parti, null, k, new.metin, '{"ekran":"bildirim"}');
  else
    perform oyun.push_konuya(null, format('''p_il_%s'' in topics && ''p_parti_%s'' in topics', new.hedef_il, new.hedef_parti),
                             k, new.metin, '{"ekran":"bildirim"}');
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------------
-- 2) Duyuru
--    p: metin (3-600), kanallar ["kutu","haber"], hedef_il?, hedef_parti?, zaman? (ISO, 2 dk – 30 gün sonrası)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_push_durum()
returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select jsonb_build_object(
    'aktif', coalesce((select push_aktif from oyun.ayarlar where id = 1), false),
    'adres_var', (select push_url is not null from oyun.ayarlar where id = 1),
    'cihaz', (select count(*) from oyun.cihazlar),
    'cihaz_7g', (select count(*) from oyun.cihazlar where guncelleme > now() - interval '7 days'),
    'bekleyen', (select count(*) from oyun.push_kuyruk where gonderildi is null),
    'son_gonderim', (select max(gonderildi) from oyun.push_kuyruk))
$$;

create or replace function oyun.yp_duyuru_hedef(p_il smallint, p_parti bigint)
returns text language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case
    when p_il is null and p_parti is null then 'Tüm Türkiye'
    when p_parti is null then (select ad from oyun.iller where id = p_il) || '''deki oyuncular'
    when p_il is null then (select kisa from oyun.partiler where id = p_parti) || ' üyeleri'
    else (select kisa from oyun.partiler where id = p_parti) || ' · ' || (select ad from oyun.iller where id = p_il) || ' üyeleri' end
$$;

create or replace function oyun.yp_duyuru_icerik(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v_metin text := oyun.yp_metin(p->>'metin', 3, 600);
        v_kanal jsonb := case when jsonb_typeof(p->'kanallar') = 'array' then p->'kanallar' else '["kutu"]'::jsonb end;
        v_il smallint; v_parti bigint; v_zaman timestamptz; v_kitle int;
begin
  if v_metin is null then return jsonb_build_object('engel', 'Duyuru metni 3-600 karakter olmalı.'); end if;
  if not (v_kanal ? 'kutu') and not (v_kanal ? 'haber') then return jsonb_build_object('engel', 'En az bir kanal seç: bildirim kutusu ya da haber akışı.'); end if;
  if nullif(p->>'hedef_il', '') is not null then
    if p->>'hedef_il' !~ '^\d{1,3}$' then return jsonb_build_object('engel', 'İl geçersiz.'); end if;
    select id into v_il from oyun.iller where id = (p->>'hedef_il')::int;
    if v_il is null then return jsonb_build_object('engel', 'İl bulunamadı.'); end if;
  end if;
  if nullif(p->>'hedef_parti', '') is not null then
    if p->>'hedef_parti' !~ '^\d+$' then return jsonb_build_object('engel', 'Parti geçersiz.'); end if;
    select id into v_parti from oyun.partiler where id = (p->>'hedef_parti')::bigint and not kapali;
    if v_parti is null then return jsonb_build_object('engel', 'Parti bulunamadı ya da kapalı.'); end if;
  end if;
  if nullif(p->>'zaman', '') is not null then
    begin
      v_zaman := (p->>'zaman')::timestamptz;
    exception when others then
      return jsonb_build_object('engel', 'Planlanan zaman okunamadı.');
    end;
    if v_zaman < now() + interval '2 minutes' then
      return jsonb_build_object('engel', 'Planlanan zaman en az 2 dakika sonrası olmalı. Hemen göndermek için zamanı boş bırak.');
    end if;
    if v_zaman > now() + interval '30 days' then return jsonb_build_object('engel', 'En fazla 30 gün sonrasına planlanabilir.'); end if;
  end if;
  select count(*) into v_kitle from oyun.profiller x
  where not x.yasakli and (v_il is null or x.il_id = v_il) and (v_parti is null or x.parti_id = v_parti);
  return jsonb_build_object('metin', v_metin, 'kutu', v_kanal ? 'kutu', 'haber', v_kanal ? 'haber',
    'hedef_il', v_il, 'hedef_parti', v_parti, 'zaman', v_zaman, 'hedef', oyun.yp_duyuru_hedef(v_il, v_parti), 'kitle', v_kitle);
end $$;

create or replace function oyun.yp_duyuru_gonder(c jsonb, p_user uuid, t timestamptz)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v_y bigint; v_o bigint;
begin
  if coalesce((c->>'kutu')::boolean, false) then
    insert into oyun.yayinlar (tur, gonderen, metin, zaman, hedef_il, hedef_parti, unvan)
    values ('sistem', p_user, c->>'metin', t, (c->>'hedef_il')::smallint, (c->>'hedef_parti')::bigint, 'Oyun Yönetimi')
    returning id into v_y;
  end if;
  if coalesce((c->>'haber')::boolean, false) then
    insert into oyun.olaylar (zaman, tur, il_id, parti_id, metin)
    values (t, 'duyuru', (c->>'hedef_il')::smallint, (c->>'hedef_parti')::bigint, 'Oyun Yönetimi: ' || (c->>'metin'))
    returning id into v_o;
  end if;
  return jsonb_build_object('yayin_id', v_y, 'olay_id', v_o, 'zaman', t);
end $$;

create or replace function oyun.yp_on_duyuru_yayinla(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare c jsonb := oyun.yp_duyuru_icerik(p); pu jsonb := oyun.yp_push_durum(); uy jsonb := '[]'::jsonb; v_kanal text; v_zaman text;
begin
  if c->>'engel' is not null then return c; end if;
  v_kanal := concat_ws(' + ', case when (c->>'kutu')::boolean then 'Bildirim kutusu' end, case when (c->>'haber')::boolean then 'Haber akışı' end);
  v_zaman := case when c->>'zaman' is null then 'Hemen' else oyun.tr_tarih_saat((c->>'zaman')::timestamptz) end;
  if (c->>'kutu')::boolean then
    uy := uy || to_jsonb('Hedefe uyan oyuncuların bildirim kutusuna "Oyun Yönetimi" adıyla düşer; hedefe sonradan giren oyuncular da görür.'::text);
    if (c->>'kitle')::int = 0 then uy := uy || to_jsonb('Şu an bu hedefe uyan oyuncu yok.'::text); end if;
  end if;
  if (c->>'haber')::boolean then uy := uy || to_jsonb('Haber akışına "duyuru" olarak düşer.'::text); end if;
  if not (pu->>'aktif')::boolean or (pu->>'cihaz')::int = 0 then
    uy := uy || to_jsonb(format('Telefon anlık bildirimi (push) şu an çalışmıyor (kayıtlı cihaz: %s). Duyuru yalnız oyun içinde görünür.', pu->>'cihaz'));
  end if;
  if c->>'zaman' is not null then
    uy := uy || to_jsonb('Planlanan dakikada otomatik gönderilir (en çok 1 dakika gecikmeyle). Gönderilmeden önce İşlem geçmişinden geri alarak iptal edebilirsin.'::text);
  else
    uy := uy || to_jsonb('Geri alınırsa duyuru bildirim kutusundan gizlenir ve haber kaydı kaldırılır; o ana kadar okuyanlar görmüş olur.'::text);
  end if;
  return jsonb_build_object(
    'ozet', format('%s · %s oyuncu · %s.', c->>'hedef', c->>'kitle', case when c->>'zaman' is null then 'hemen yayınlanacak' else v_zaman || ' için planlanacak' end),
    'degisen', jsonb_build_array(
      jsonb_build_object('alan', 'Kanal', 'eski', '', 'yeni', v_kanal),
      jsonb_build_object('alan', 'Hedef', 'eski', '', 'yeni', c->>'hedef'),
      jsonb_build_object('alan', 'Zaman', 'eski', '', 'yeni', v_zaman),
      jsonb_build_object('alan', 'Metin', 'eski', '', 'yeni', c->>'metin')),
    'sayi', (c->>'kitle')::int, 'uyarilar', uy,
    'parmak', md5((c - 'kitle')::text));
end $$;

create or replace function oyun.yp_uy_duyuru_yayinla(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_duyuru_yayinla(p); c jsonb := oyun.yp_duyuru_icerik(p);
        v_islem bigint := nullif(current_setting('yp.islem_id', true), '')::bigint; ri oyun.yp_islem; r jsonb; v_plan bigint;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  select * into ri from oyun.yp_islem where id = v_islem;
  if c->>'zaman' is not null then
    insert into oyun.yp_duyuru_plan (islem_id, zaman, icerik) values (v_islem, (c->>'zaman')::timestamptz, c - 'kitle') returning id into v_plan;
    return jsonb_build_object('ozet', format('Duyuru %s için planlandı (%s).', oyun.tr_tarih_saat((c->>'zaman')::timestamptz), c->>'hedef'),
      'hedef', c->>'hedef', 'once', '{}'::jsonb, 'sonra', jsonb_build_object('plan_id', v_plan, 'zaman', c->'zaman'),
      'dogrulama', jsonb_build_object('tutarli', v_plan is not null, 'plan_id', v_plan));
  end if;
  r := oyun.yp_duyuru_gonder(c, ri.user_id, oyun.simdi());
  return jsonb_build_object('ozet', format('Duyuru yayınlandı: %s (%s oyuncu).', c->>'hedef', c->>'kitle'),
    'hedef', c->>'hedef', 'once', '{}'::jsonb, 'sonra', r,
    'dogrulama', jsonb_build_object('tutarli', ((c->>'kutu')::boolean = (r->>'yayin_id' is not null)) and ((c->>'haber')::boolean = (r->>'olay_id' is not null)),
      'yayin_id', r->'yayin_id', 'olay_id', r->'olay_id'));
end $$;

create or replace function oyun.yp_gr_duyuru_yayinla(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pl oyun.yp_duyuru_plan; s jsonb := r.sonra; v_y bigint; v_o bigint;
begin
  if s ? 'plan_id' then
    select * into pl from oyun.yp_duyuru_plan where id = (s->>'plan_id')::bigint;
    if pl.id is null then return jsonb_build_object('engel', 'Plan kaydı bulunamadı.'); end if;
    if pl.durum = 'bekliyor' then
      if p_uygula then update oyun.yp_duyuru_plan set durum = 'iptal', hata = 'İşlem #' || r.id || ' geri alındı.' where id = pl.id; end if;
      return jsonb_build_object('ozet', format('%s için planlanan duyuru %s.', oyun.tr_tarih_saat(pl.zaman), case when p_uygula then 'iptal edildi' else 'iptal edilecek' end),
        'sayi', 1, 'once', r.sonra, 'sonra', jsonb_build_object('plan_id', pl.id, 'durum', 'iptal'));
    elsif pl.durum <> 'gonderildi' then
      return jsonb_build_object('engel', 'Planlı duyuru zaten iptal edilmiş ya da gönderilemedi.');
    end if;
    s := pl.sonuc;
  end if;
  v_y := (s->>'yayin_id')::bigint; v_o := (s->>'olay_id')::bigint;
  if p_uygula then
    if v_y is not null then update oyun.yayinlar set gizli = true where id = v_y and tur = 'sistem'; end if;
    if v_o is not null then delete from oyun.olaylar where id = v_o and tur = 'duyuru'; end if;
  end if;
  return jsonb_build_object('ozet', format('Duyuru %s.', case when p_uygula then 'bildirim kutusundan gizlendi, haber kaydı kaldırıldı' else 'bildirim kutusundan gizlenecek, haber kaydı kaldırılacak' end),
    'sayi', 1, 'once', s, 'sonra', jsonb_build_object('yayin_id', v_y, 'gizli', true, 'olay_silindi', v_o));
end $$;

-- Zamanlayıcı: planlı duyurular (dakikada bir)
create or replace function oyun.yp_duyuru_plan_isle()
returns int language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pl oyun.yp_duyuru_plan; ri oyun.yp_islem; r jsonb; n int := 0; h text;
begin
  for pl in select * from oyun.yp_duyuru_plan where durum = 'bekliyor' and zaman <= now() order by zaman, id for update skip locked loop
    begin
      select * into ri from oyun.yp_islem where id = pl.islem_id;
      r := oyun.yp_duyuru_gonder(pl.icerik, ri.user_id, oyun.simdi());
      update oyun.yp_duyuru_plan set durum = 'gonderildi', gonderim = now(), sonuc = r where id = pl.id;
      insert into oyun.mod_kayit (zaman, user_id, kad, islem, hedef, ayrinti)
      values (now(), ri.user_id, ri.kad, 'yp_duyuru_plan', coalesce(pl.icerik->>'hedef', 'Duyuru'), left(format('İşlem #%s · %s', pl.islem_id, pl.icerik->>'metin'), 300));
      n := n + 1;
    exception when others then
      get stacked diagnostics h = message_text;
      update oyun.yp_duyuru_plan set durum = 'basarisiz', hata = h, gonderim = now() where id = pl.id;
    end;
  end loop;
  if n > 0 then perform oyun.uzaktan_sinyal_yay('yonetici'); end if;
  return n;
end $$;

do $zamanlayici$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'yp-duyuru-plan') then
      perform cron.unschedule('yp-duyuru-plan');
    end if;
    perform cron.schedule('yp-duyuru-plan', '* * * * *', 'select oyun.yp_duyuru_plan_isle()');
  end if;
end
$zamanlayici$;

-- ---------------------------------------------------------------------
-- 3) Olay / kriz başlat
--    p: tur (ulusal | ulke | belediye), kod, il_id?
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_olay_baslat(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v_tur text := p->>'tur'; v_kod text := nullif(btrim(coalesce(p->>'kod', '')), ''); v_il smallint; v_ilad text;
        us oyun.uk_sablon; ks oyun.kriz_sablon; bk oyun.belediye_kriz_katalog; v_bas uuid; v_bakan text; v_kitle int; v_ay int;
        uy jsonb := '[]'::jsonb; deg jsonb; v_baslik text; v_gun int; b jsonb; v_etki text[] := '{}';
begin
  if nullif(p->>'il_id', '') is not null then
    if p->>'il_id' !~ '^\d{1,3}$' then return jsonb_build_object('engel', 'İl geçersiz.'); end if;
    select id, ad into v_il, v_ilad from oyun.iller where id = (p->>'il_id')::int;
    if v_il is null then return jsonb_build_object('engel', 'İl bulunamadı.'); end if;
  end if;

  if v_tur = 'ulusal' then
    select * into us from oyun.uk_sablon where kod = v_kod;
    if us.kod is null then return jsonb_build_object('engel', 'Ulusal kriz türü seçmelisin.'); end if;
    if exists (select 1 from oyun.uk_olay where durum = 'aktif') then
      return jsonb_build_object('engel', 'Zaten süren bir ulusal kriz var; aynı anda yalnız bir ulusal kriz olabilir.');
    end if;
    if us.kapsam = 'il' then
      if v_il is null then return jsonb_build_object('engel', 'Bu kriz bir ilde yaşanır; il seçmelisin.'); end if;
      if us.il_havuzu is not null and not (v_ilad = any(us.il_havuzu)) then
        uy := uy || to_jsonb(format('%s bu krizin olağan illeri arasında değil (ör. %s).', v_ilad, array_to_string(us.il_havuzu[1:5], ', ')));
      end if;
      select count(*) into v_kitle from oyun.profiller where il_id = v_il and not yasakli;
    else
      if v_il is not null then uy := uy || to_jsonb('Bu kriz ülke çapındadır; seçilen il dikkate alınmaz.'::text); v_il := null; v_ilad := null; end if;
      select count(*) into v_kitle from oyun.profiller where not yasakli and son_gorulme > oyun.simdi() - interval '14 days';
    end if;
    select ad into v_bakan from oyun.bakanliklar where kod = us.bakanlik;
    b := coalesce(us.baslangic, '{}'::jsonb);
    if b ? 'ulke_mem' then v_etki := v_etki || format('ülke memnuniyeti %s', b->>'ulke_mem'); end if;
    if b ? 'il_mem' and v_il is not null then v_etki := v_etki || format('%s memnuniyeti %s', v_ilad, b->>'il_mem'); end if;
    if b ? 'il_kasa_oran' and v_il is not null then v_etki := v_etki || format('belediye kasası %%%s', round((b->>'il_kasa_oran')::numeric * 100)); end if;
    select min_aralik_gun into v_gun from oyun.uk_ayar where id;
    v_baslik := us.baslik || coalesce(' · ' || v_ilad, '');
    deg := jsonb_build_array(
      jsonb_build_object('alan', 'Ulusal kriz', 'eski', '', 'yeni', v_baslik),
      jsonb_build_object('alan', 'Sorumlu', 'eski', '', 'yeni', coalesce(v_bakan, us.bakanlik) || ' + yürütme' || case when v_il is not null then ' + ' || v_ilad || ' Belediyesi' else '' end),
      jsonb_build_object('alan', 'Anında etki', 'eski', '', 'yeni', coalesce(nullif(array_to_string(v_etki, ', '), ''), 'yok')),
      jsonb_build_object('alan', 'Karar süresi', 'eski', '', 'yeni', 'İlk müdahale 6 saat'));
    uy := uy || to_jsonb(format('%s oyuncuya bildirim gider; haber akışına "ULUSAL KRİZ" düşer.', v_kitle))
              || to_jsonb('Etkiler başladığı anda uygulanır ve geri alınamaz. Krizi bundan sonra oyunun kendi kriz motoru yürütür.'::text)
              || to_jsonb(format('Otomatik ulusal kriz çekilişi en az %s gün ertelenir.', coalesce(v_gun, 10)));
    return jsonb_build_object('ozet', format('Ulusal kriz başlatılacak: %s.', v_baslik), 'degisen', deg, 'sayi', v_kitle, 'uyarilar', uy,
      'baslik_ad', v_baslik,
      'parmak', md5(concat_ws('|', v_tur, us.kod, v_il, (select max(id) from oyun.uk_olay))));

  elsif v_tur = 'ulke' then
    select * into ks from oyun.kriz_sablon where kod = v_kod;
    if ks.kod is null then return jsonb_build_object('engel', 'Ülke krizi türü seçmelisin.'); end if;
    if exists (select 1 from oyun.kriz_olay where durum = 'bekliyor') then
      return jsonb_build_object('engel', 'Karar bekleyen bir ülke krizi var; önce o sonuçlanmalı.');
    end if;
    if v_il is not null then uy := uy || to_jsonb('Ülke krizleri il seçmez; seçilen il dikkate alınmaz.'::text); end if;
    select ad into v_bakan from oyun.bakanliklar where kod = ks.bakanlik;
    select min_aralik_gun into v_gun from oyun.kriz_ayar where id;
    deg := jsonb_build_array(
      jsonb_build_object('alan', 'Ülke krizi', 'eski', '', 'yeni', ks.baslik),
      jsonb_build_object('alan', 'Yetkili makam', 'eski', '', 'yeni', coalesce(v_bakan, ks.bakanlik)),
      jsonb_build_object('alan', 'Etkilenen sektör', 'eski', '', 'yeni', coalesce(ks.sektor, '—')),
      jsonb_build_object('alan', 'Karar süresi', 'eski', '', 'yeni', '4 saat · ' || coalesce(jsonb_array_length(ks.secenekler), 0) || ' seçenek'));
    uy := uy || to_jsonb('Haber akışına "Ülke Kriz Merkezi" duyurusu düşer.'::text)
              || to_jsonb('4 saatte karar verilmezse kriz güvenli geçici planla kapanır: sektör çarpanı 3 gün boyunca %0,5 düşer.'::text)
              || to_jsonb(format('Otomatik ülke krizi çekilişi en az %s gün ertelenir.', coalesce(v_gun, 14)));
    return jsonb_build_object('ozet', format('Ülke krizi başlatılacak: %s.', ks.baslik), 'degisen', deg, 'sayi', 1, 'uyarilar', uy,
      'baslik_ad', ks.baslik,
      'parmak', md5(concat_ws('|', v_tur, ks.kod, (select max(id) from oyun.kriz_olay))));

  elsif v_tur = 'belediye' then
    if v_il is null then return jsonb_build_object('engel', 'Belediye krizi için il seçmelisin.'); end if;
    select user_id into v_bas from oyun.makamlar where tur = 'bel' and il_id = v_il and bit is null order by id desc limit 1;
    if v_bas is null then return jsonb_build_object('engel', v_ilad || '''de görevde belediye başkanı yok; belediye krizi başlatılamaz.'); end if;
    if exists (select 1 from oyun.belediye_kriz where il_id = v_il and durum = 'acik') then
      return jsonb_build_object('engel', v_ilad || '''de zaten açık bir belediye krizi var.');
    end if;
    select * into bk from oyun.belediye_kriz_katalog where kod = v_kod;
    if bk.kod is null then return jsonb_build_object('engel', 'Belediye krizi türü seçmelisin.'); end if;
    v_ay := extract(month from (oyun.simdi() at time zone 'Europe/Istanbul'));
    if bk.aylar is not null and not (v_ay = any(bk.aylar)) then
      uy := uy || to_jsonb('Bu kriz normalde bu ayda çıkmaz (mevsim dışı).'::text);
    end if;
    deg := jsonb_build_array(
      jsonb_build_object('alan', 'Belediye krizi', 'eski', '', 'yeni', bk.baslik || ' · ' || v_ilad),
      jsonb_build_object('alan', 'Belediye başkanı', 'eski', '', 'yeni', oyun.kad(v_bas)),
      jsonb_build_object('alan', 'Karar süresi', 'eski', '', 'yeni', '24 saat · ' || coalesce(jsonb_array_length(bk.secenekler), 0) || ' seçenek'));
    uy := uy || to_jsonb('Başkana bildirim gider ve haber akışına düşer. 24 saatte karar verilmezse "başkan sessiz kaldı" sonucu işler.'::text)
              || to_jsonb('Başlatılan kriz geri alınamaz.'::text);
    return jsonb_build_object('ozet', format('%s''de belediye krizi başlatılacak: %s.', v_ilad, bk.baslik), 'degisen', deg, 'sayi', 1, 'uyarilar', uy,
      'baslik_ad', bk.baslik || ' · ' || v_ilad,
      'parmak', md5(concat_ws('|', v_tur, bk.kod, v_il, v_bas, (select max(id) from oyun.belediye_kriz where il_id = v_il))));
  end if;
  return jsonb_build_object('engel', 'Olay türü seçmelisin: ulusal kriz, ülke krizi ya da belediye krizi.');
end $$;

create or replace function oyun.yp_uy_olay_baslat(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_olay_baslat(p); v_tur text := p->>'tur'; v_kod text := btrim(p->>'kod'); v_il smallint; v_id bigint;
        t timestamptz := oyun.simdi(); ks oyun.kriz_sablon; v_var boolean;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  v_il := nullif(p->>'il_id', '')::smallint;
  if v_tur = 'ulusal' then
    if (select kapsam from oyun.uk_sablon where kod = v_kod) <> 'il' then v_il := null; end if;
    v_id := oyun.uk_baslat(v_kod, t, v_il);
    select exists (select 1 from oyun.uk_olay where id = v_id and durum = 'aktif') into v_var;
  elsif v_tur = 'ulke' then
    select * into ks from oyun.kriz_sablon where kod = v_kod;
    insert into oyun.kriz_olay (sablon_kod, karar_son) values (ks.kod, now() + interval '4 hours') returning id into v_id;
    update oyun.kriz_ayar set son_kriz = now() where id;
    insert into oyun.olaylar (tur, metin, zaman) values ('ulke_krizi',
      format('Ülke Kriz Merkezi: %s. Yetkili makam: %s. Karar süresi 4 saat.', ks.baslik, (select ad from oyun.bakanliklar where kod = ks.bakanlik)), t);
    select exists (select 1 from oyun.kriz_olay where id = v_id and durum = 'bekliyor') into v_var;
  else
    v_id := oyun.belediye_kriz_baslat(v_il, v_kod);
    if v_id is null then raise exception 'Belediye krizi başlatılamadı (başkan yok ya da açık kriz var).'; end if;
    select exists (select 1 from oyun.belediye_kriz where id = v_id and durum = 'acik') into v_var;
  end if;
  return jsonb_build_object('ozet', replace(o->>'ozet', 'başlatılacak', 'başlatıldı'), 'hedef', o->>'baslik_ad',
    'once', '{}'::jsonb, 'sonra', jsonb_build_object('tur', v_tur, 'kod', v_kod, 'il_id', v_il, 'olay_id', v_id),
    'dogrulama', jsonb_build_object('tutarli', coalesce(v_var, false), 'olay_id', v_id));
end $$;

-- ---------------------------------------------------------------------
-- 4) Şikâyet kararı
--    p: tur (mesaj | yayin | ozel | oyuncu), kayit_id, hedef (uuid), karar (yok_say | gizle | gizle_sustur1 | gizle_sustur7)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_sikayet_icerik(p_tur text, p_kayit bigint)
returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case p_tur
    when 'mesaj' then (select jsonb_build_object('metin', metin, 'gizli', gizli, 'zaman', zaman) from oyun.mesajlar where id = p_kayit)
    when 'yayin' then (select jsonb_build_object('metin', metin, 'gizli', gizli, 'zaman', zaman) from oyun.yayinlar where id = p_kayit)
    when 'ozel'  then (select jsonb_build_object('metin', metin, 'gizli', gizli, 'zaman', zaman) from oyun.ozel where id = p_kayit)
  end
$$;

create or replace function oyun.yp_sikayet_hazirla(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v_tur text := p->>'tur'; v_karar text := p->>'karar'; v_kayit bigint; h oyun.profiller; v_ids bigint[]; v_n int; v_neden jsonb;
        ic jsonb; t timestamptz := oyun.simdi(); v_sus timestamptz;
begin
  if v_tur not in ('mesaj', 'yayin', 'ozel', 'oyuncu') then return jsonb_build_object('engel', 'Şikâyet türü geçersiz.'); end if;
  if v_karar not in ('yok_say', 'gizle', 'gizle_sustur1', 'gizle_sustur7') then return jsonb_build_object('engel', 'Karar seçmelisin.'); end if;
  if coalesce(p->>'kayit_id', '0') !~ '^\d+$' then return jsonb_build_object('engel', 'Kayıt geçersiz.'); end if;
  v_kayit := coalesce(nullif(p->>'kayit_id', ''), '0')::bigint;
  if coalesce(p->>'hedef', '') !~ '^[0-9a-fA-F-]{36}$' then return jsonb_build_object('engel', 'Şikâyet edilen oyuncu geçersiz.'); end if;
  select * into h from oyun.profiller where id = (p->>'hedef')::uuid;
  if h.id is null then return jsonb_build_object('engel', 'Şikâyet edilen oyuncu bulunamadı.'); end if;
  select array_agg(id order by id), count(distinct sikayetci), jsonb_agg(distinct neden) into v_ids, v_n, v_neden
  from oyun.sikayetler where tur = v_tur and kayit_id = v_kayit and hedef_user = h.id and durum = 'yeni';
  if coalesce(v_n, 0) = 0 then return jsonb_build_object('engel', 'Bu kayıt için bekleyen şikâyet yok.'); end if;
  if v_karar like '%sustur%' and coalesce(h.yonetici, false) then return jsonb_build_object('engel', 'Yönetici hesabı susturulamaz.'); end if;
  if v_tur = 'oyuncu' and v_karar = 'gizle' then
    return jsonb_build_object('engel', 'Oyuncu şikâyetinde gizlenecek içerik yok; "yok say" ya da susturma seç.');
  end if;
  ic := oyun.yp_sikayet_icerik(v_tur, v_kayit);
  if v_tur <> 'oyuncu' and ic is null then return jsonb_build_object('engel', 'Şikâyet edilen içerik artık bulunamıyor.'); end if;
  v_sus := case v_karar
    when 'gizle_sustur1' then greatest(coalesce(h.susturma_bitis, t), t + interval '1 day')
    when 'gizle_sustur7' then greatest(coalesce(h.susturma_bitis, t), t + interval '7 days')
    else h.susturma_bitis end;
  return jsonb_build_object('tur', v_tur, 'kayit_id', v_kayit, 'hedef', h.id, 'kad', h.kad, 'karar', v_karar, 'ids', to_jsonb(v_ids), 'sayi', v_n,
    'nedenler', v_neden, 'metin', ic->>'metin', 'gizli_once', (ic->>'gizli')::boolean,
    'gizli_sonra', case when v_tur = 'oyuncu' then null else v_karar <> 'yok_say' end,
    'sus_once', h.susturma_bitis, 'sus_sonra', v_sus);
end $$;

create or replace function oyun.yp_on_sikayet_karar(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare z jsonb := oyun.yp_sikayet_hazirla(p); t timestamptz := oyun.simdi(); deg jsonb := '[]'::jsonb; uy jsonb := '[]'::jsonb; v_ad text;
begin
  if z->>'engel' is not null then return z; end if;
  v_ad := case z->>'karar' when 'yok_say' then 'Yok say' when 'gizle' then 'Gizle' when 'gizle_sustur1' then 'Gizle + 1 gün sustur' else 'Gizle + 7 gün sustur' end;
  if z->>'tur' <> 'oyuncu' then
    deg := deg || jsonb_build_array(jsonb_build_object('alan', 'İçerik: “' || left(z->>'metin', 140) || '”',
      'eski', case when (z->>'gizli_once')::boolean then 'Gizli' else 'Görünür' end,
      'yeni', case when (z->>'gizli_sonra')::boolean then 'Gizli' else 'Görünür' end));
  end if;
  if z->>'karar' like '%sustur%' then
    deg := deg || jsonb_build_array(jsonb_build_object('alan', 'Susturma (' || (z->>'kad') || ')',
      'eski', case when (z->>'sus_once')::timestamptz > t then oyun.tr_tarih_saat((z->>'sus_once')::timestamptz) || ' bitişli' else 'Yok' end,
      'yeni', oyun.tr_tarih_saat((z->>'sus_sonra')::timestamptz) || ' bitişli'));
    uy := uy || to_jsonb('Oyuncuya "içeriğin kaldırıldı, bir süre mesaj gönderemeyeceksin" bildirimi gider; bildirim geri alınamaz.'::text);
  end if;
  deg := deg || jsonb_build_array(jsonb_build_object('alan', 'Şikâyet durumu', 'eski', format('Bekliyor (%s kişi)', z->>'sayi'), 'yeni', 'İncelendi'));
  if z->>'tur' = 'ozel' then uy := uy || to_jsonb('Özel mesaj şikâyeti: mesaj zaten şikâyet anında şikâyet edenden gizlenmişti.'::text); end if;
  uy := uy || to_jsonb('Geri alınırsa içerik görünürlüğü, susturma ve şikâyet durumu eski hâline döner.'::text);
  return jsonb_build_object('ozet', format('%s · %s şikâyet · %s.', z->>'kad', z->>'sayi', v_ad), 'degisen', deg, 'sayi', 1, 'uyarilar', uy,
    'parmak', md5(concat_ws('|', z->>'tur', z->>'kayit_id', z->>'hedef', z->>'karar', z->>'ids', z->>'gizli_once', z->>'sus_once')));
end $$;

create or replace function oyun.yp_uy_sikayet_karar(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_sikayet_karar(p); z jsonb := oyun.yp_sikayet_hazirla(p); t timestamptz := oyun.simdi();
        v_kayit bigint; v_g boolean; v_ids bigint[]; v_n int;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  v_kayit := (z->>'kayit_id')::bigint; v_g := (z->>'gizli_sonra')::boolean;
  v_ids := array(select (x #>> '{}')::bigint from jsonb_array_elements(z->'ids') x);
  if z->>'tur' = 'mesaj' then update oyun.mesajlar set gizli = v_g where id = v_kayit;
  elsif z->>'tur' = 'yayin' then update oyun.yayinlar set gizli = v_g where id = v_kayit;
  elsif z->>'tur' = 'ozel' then update oyun.ozel set gizli = v_g where id = v_kayit;
  end if;
  if z->>'karar' like '%sustur%' then
    update oyun.profiller set susturma_bitis = (z->>'sus_sonra')::timestamptz where id = (z->>'hedef')::uuid;
    perform oyun.bildir((z->>'hedef')::uuid, 'Topluluk kurallarını ihlal eden bir içeriğin kaldırıldı ve hesabın bir süre mesaj gönderemeyecek.', t);
  end if;
  update oyun.sikayetler set durum = 'incelendi' where id = any(v_ids) and durum = 'yeni';
  get diagnostics v_n = row_count;
  return jsonb_build_object('ozet', replace(o->>'ozet', ' · ' || (z->>'sayi') || ' şikâyet · ', ' · ' || (z->>'sayi') || ' şikâyet · karar uygulandı: '), 'hedef', z->>'kad',
    'once', jsonb_build_object('tur', z->'tur', 'kayit_id', v_kayit, 'hedef', z->'hedef', 'gizli', z->'gizli_once', 'susturma', z->'sus_once', 'ids', z->'ids'),
    'sonra', jsonb_build_object('tur', z->'tur', 'kayit_id', v_kayit, 'hedef', z->'hedef', 'gizli', z->'gizli_sonra', 'susturma', z->'sus_sonra', 'ids', z->'ids', 'karar', z->'karar'),
    'dogrulama', jsonb_build_object('tutarli', v_n = cardinality(v_ids), 'sikayet', v_n));
end $$;

create or replace function oyun.yp_gr_sikayet_karar(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare s jsonb := r.sonra; e jsonb := r.once; ic jsonb; h oyun.profiller; v_kayit bigint := (s->>'kayit_id')::bigint; notlar jsonb := '[]'::jsonb;
        v_ids bigint[] := array(select (x #>> '{}')::bigint from jsonb_array_elements(r.sonra->'ids') x);
begin
  select * into h from oyun.profiller where id = (s->>'hedef')::uuid;
  if h.id is null then return jsonb_build_object('engel', 'Oyuncu bulunamadı.'); end if;
  ic := oyun.yp_sikayet_icerik(s->>'tur', v_kayit);
  if p_uygula then
    if ic is not null and (ic->>'gizli')::boolean is not distinct from (s->>'gizli')::boolean then
      if s->>'tur' = 'mesaj' then update oyun.mesajlar set gizli = (e->>'gizli')::boolean where id = v_kayit;
      elsif s->>'tur' = 'yayin' then update oyun.yayinlar set gizli = (e->>'gizli')::boolean where id = v_kayit;
      elsif s->>'tur' = 'ozel' then update oyun.ozel set gizli = (e->>'gizli')::boolean where id = v_kayit;
      end if;
    end if;
    if s->>'karar' like '%sustur%' and h.susturma_bitis is not distinct from (s->>'susturma')::timestamptz then
      update oyun.profiller set susturma_bitis = (e->>'susturma')::timestamptz where id = h.id;
    end if;
    update oyun.sikayetler set durum = 'yeni' where id = any(v_ids) and durum = 'incelendi';
  else
    if ic is not null and (ic->>'gizli')::boolean is distinct from (s->>'gizli')::boolean then
      notlar := notlar || to_jsonb('İçeriğin görünürlüğü bu arada değişmiş; olduğu gibi bırakılacak.'::text);
    end if;
    if s->>'karar' like '%sustur%' and h.susturma_bitis is distinct from (s->>'susturma')::timestamptz then
      notlar := notlar || to_jsonb('Susturma süresi bu arada değişmiş; olduğu gibi bırakılacak.'::text);
    end if;
  end if;
  return jsonb_build_object('ozet', format('%s hakkındaki şikâyet kararı %s; şikâyetler yeniden "bekliyor" olur.', h.kad, case when p_uygula then 'geri alındı' else 'geri alınacak' end),
    'sayi', 1, 'uyarilar', notlar, 'once', r.sonra, 'sonra', r.once);
end $$;

-- ---------------------------------------------------------------------
-- 5) Destek yanıtı
--    p: kaynak (talep | ozel), id, metin (2-1000; talep kapatılıyorsa boş olabilir), kapat (yalnız talep)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_destek_yanitla(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v_kaynak text := p->>'kaynak'; v_metin text := oyun.yp_metin(p->>'metin', 2, 1000); v_kapat boolean := coalesce((p->>'kapat')::boolean, false);
        dt oyun.destek_talep; oz oyun.ozel; ben uuid := auth.uid(); deg jsonb; uy jsonb := '[]'::jsonb;
begin
  if coalesce(p->>'id', '') !~ '^\d+$' then return jsonb_build_object('engel', 'Kayıt seçmelisin.'); end if;
  if v_kaynak = 'talep' then
    select * into dt from oyun.destek_talep where id = (p->>'id')::bigint;
    if dt.id is null then return jsonb_build_object('engel', 'Destek talebi bulunamadı.'); end if;
    if dt.durum = 'kapali' then return jsonb_build_object('engel', 'Bu talep kapatılmış.'); end if;
    if v_metin is null and not v_kapat then return jsonb_build_object('engel', 'Yanıt yazmalısın (2-1000 karakter).'); end if;
    deg := jsonb_build_array(jsonb_build_object('alan', format('Talep #%s · %s', dt.id, oyun.kad(dt.user_id)),
             'eski', case dt.durum when 'yeni' then 'Yeni' else 'Yanıtlandı' end, 'yeni', case when v_kapat then 'Kapalı' else 'Yanıtlandı' end));
    if v_metin is not null then deg := deg || jsonb_build_array(jsonb_build_object('alan', 'Yanıt', 'eski', coalesce(dt.yanit, ''), 'yeni', v_metin)); end if;
    uy := uy || to_jsonb('Oyuncuya "Destek yanıtı" bildirimi gider; geri alınamaz.'::text);
    return jsonb_build_object('ozet', format('Talep #%s (%s) %s.', dt.id, oyun.kad(dt.user_id), case when v_metin is null then 'kapatılacak' when v_kapat then 'yanıtlanıp kapatılacak' else 'yanıtlanacak' end),
      'degisen', deg, 'sayi', 1, 'uyarilar', uy,
      'parmak', md5(concat_ws('|', v_kaynak, dt.id, dt.durum, dt.yanit, v_metin, v_kapat)));
  elsif v_kaynak = 'ozel' then
    select * into oz from oyun.ozel where id = (p->>'id')::bigint;
    if oz.id is null or oz.alici is distinct from ben then return jsonb_build_object('engel', 'Sana gelen bir özel mesaj bulunamadı.'); end if;
    if v_metin is null then return jsonb_build_object('engel', 'Yanıt yazmalısın (2-1000 karakter).'); end if;
    if oyun.engelli(oz.gonderen, ben) or oyun.engelli(ben, oz.gonderen) then
      return jsonb_build_object('engel', 'Bu oyuncuyla aranda engelleme var; özel mesaj gönderilemez.');
    end if;
    deg := jsonb_build_array(jsonb_build_object('alan', 'Kime', 'eski', '', 'yeni', oyun.kad(oz.gonderen)),
                             jsonb_build_object('alan', 'Yanıt', 'eski', '', 'yeni', v_metin));
    uy := uy || to_jsonb('Yanıt oyuncunun özel mesaj kutusuna senin hesabından gider; geri alınamaz.'::text)
              || to_jsonb('Bu oyuncudan gelen okunmamış mesajlar okundu sayılır.'::text);
    return jsonb_build_object('ozet', format('%s adlı oyuncuya özel mesajla yanıt verilecek.', oyun.kad(oz.gonderen)), 'degisen', deg, 'sayi', 1, 'uyarilar', uy,
      'parmak', md5(concat_ws('|', v_kaynak, oz.id, v_metin)));
  end if;
  return jsonb_build_object('engel', 'Yanıtlanacak kaydı seçmelisin.');
end $$;

create or replace function oyun.yp_uy_destek_yanitla(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_destek_yanitla(p); v_metin text := oyun.yp_metin(p->>'metin', 2, 1000); v_kapat boolean := coalesce((p->>'kapat')::boolean, false);
        t timestamptz := oyun.simdi(); dt oyun.destek_talep; dy oyun.destek_talep; oz oyun.ozel; v_yeni bigint; v_n int;
        v_islem bigint := nullif(current_setting('yp.islem_id', true), '')::bigint; ri oyun.yp_islem;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  select * into ri from oyun.yp_islem where id = v_islem;
  if p->>'kaynak' = 'talep' then
    select * into dt from oyun.destek_talep where id = (p->>'id')::bigint for update;
    update oyun.destek_talep set yanit = coalesce(v_metin, yanit), yanit_zaman = case when v_metin is not null then now() else yanit_zaman end,
      yanitlayan = ri.user_id, durum = case when v_kapat then 'kapali' else 'yanitlandi' end, okundu = false
    where id = dt.id returning * into dy;
    perform oyun.bildir(dt.user_id, case when v_metin is not null then format('Destek yanıtı (talep #%s): %s', dt.id, v_metin)
                                         else format('Destek talebin #%s kapatıldı.', dt.id) end, t);
    return jsonb_build_object('ozet', format('Talep #%s (%s) %s.', dt.id, oyun.kad(dt.user_id),
        case when v_metin is null then 'kapatıldı' when v_kapat then 'yanıtlandı ve kapatıldı' else 'yanıtlandı' end), 'hedef', oyun.kad(dt.user_id),
      'once', jsonb_build_object('talep', dt.id, 'durum', dt.durum, 'yanit', dt.yanit),
      'sonra', jsonb_build_object('talep', dt.id, 'durum', dy.durum, 'yanit', dy.yanit),
      'dogrulama', jsonb_build_object('tutarli', dy.durum = case when v_kapat then 'kapali' else 'yanitlandi' end));
  end if;
  select * into oz from oyun.ozel where id = (p->>'id')::bigint;
  insert into oyun.ozel (gonderen, alici, metin, zaman) values (ri.user_id, oz.gonderen, v_metin, t) returning id into v_yeni;
  update oyun.ozel set okundu = true where alici = ri.user_id and gonderen = oz.gonderen and not okundu;
  get diagnostics v_n = row_count;
  return jsonb_build_object('ozet', format('%s adlı oyuncuya özel mesajla yanıt verildi.', oyun.kad(oz.gonderen)), 'hedef', oyun.kad(oz.gonderen),
    'once', jsonb_build_object('mesaj', oz.id), 'sonra', jsonb_build_object('yanit_mesaj', v_yeni, 'okundu_sayildi', v_n),
    'dogrulama', jsonb_build_object('tutarli', v_yeni is not null));
end $$;

-- ---------------------------------------------------------------------
-- 6) Oyuncu tarafı: destek talebi (uygulamadaki ekran bir sonraki sürümde bağlanır)
-- ---------------------------------------------------------------------
create or replace function public.destek_gonder(p_kategori text, p_metin text, p_surum text default null, p_platform text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); m text; v_id bigint;
begin
  if coalesce(p_kategori, '') not in ('hata', 'hesap', 'oyuncu', 'oneri', 'diger') then raise exception 'Konu seçmelisin.'; end if;
  m := btrim(regexp_replace(coalesce(p_metin, ''), '[\r\n]{3,}', E'\n\n', 'g'));
  if length(m) < 10 then raise exception 'Sorunu biraz daha ayrıntılı yaz (en az 10 karakter).'; end if;
  if length(m) > 1000 then raise exception 'En fazla 1000 karakter yazabilirsin.'; end if;
  if (select count(*) from oyun.destek_talep where user_id = p.id and durum = 'yeni') >= 3 then
    raise exception 'Yanıt bekleyen 3 talebin var; önce onların yanıtlanmasını bekle.';
  end if;
  if (select count(*) from oyun.destek_talep where user_id = p.id and zaman > now() - interval '24 hours') >= 5 then
    raise exception 'Bir günde en fazla 5 destek talebi gönderebilirsin.';
  end if;
  insert into oyun.destek_talep (user_id, kategori, metin, surum, platform)
  values (p.id, p_kategori, m, left(nullif(btrim(coalesce(p_surum, '')), ''), 40), left(nullif(btrim(coalesce(p_platform, '')), ''), 20))
  returning id into v_id;
  perform oyun.uzaktan_sinyal_yay('yonetici');
  return jsonb_build_object('tamam', true, 'id', v_id);
end $$;

create or replace function public.destek_taleplerim()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); r jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'kategori', d.kategori, 'metin', d.metin, 'zaman', d.zaman, 'durum', d.durum,
      'yanit', d.yanit, 'yanit_zaman', d.yanit_zaman, 'yeni_yanit', not d.okundu) order by d.zaman desc), '[]'::jsonb)
  into r from (select * from oyun.destek_talep where user_id = p.id order by zaman desc limit 20) d;
  update oyun.destek_talep set okundu = true where user_id = p.id and not okundu;
  return r;
end $$;

-- ---------------------------------------------------------------------
-- 7) Okuma
-- ---------------------------------------------------------------------
create or replace function public.yp_duyurular()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'arsiv', coalesce((select jsonb_agg(jsonb_build_object('id', y.id, 'zaman', y.zaman, 'metin', y.metin, 'gizli', y.gizli,
        'hedef', oyun.yp_duyuru_hedef(y.hedef_il, y.hedef_parti), 'gonderen', oyun.kad(y.gonderen), 'gelecek', y.zaman > t,
        'kitle', (select count(*) from oyun.profiller x where not x.yasakli and (y.hedef_il is null or x.il_id = y.hedef_il) and (y.hedef_parti is null or x.parti_id = y.hedef_parti)),
        'islem_id', (select i.id from oyun.yp_islem i where i.islem = 'duyuru_yayinla' and i.durum in ('uygulandi', 'geri_alindi')
                       and (i.sonra->>'yayin_id' = y.id::text
                            or exists (select 1 from oyun.yp_duyuru_plan pl where pl.islem_id = i.id and pl.sonuc->>'yayin_id' = y.id::text)) limit 1))
        order by y.id desc)
      from (select * from oyun.yayinlar where tur = 'sistem' order by id desc limit 60) y), '[]'::jsonb),
    'planlar', coalesce((select jsonb_agg(jsonb_build_object('id', pl.id, 'islem_id', pl.islem_id, 'zaman', pl.zaman, 'durum', pl.durum,
        'metin', pl.icerik->>'metin', 'hedef', pl.icerik->>'hedef', 'kutu', pl.icerik->'kutu', 'haber', pl.icerik->'haber',
        'hata', pl.hata, 'gonderim', pl.gonderim, 'kad', i.kad) order by (pl.durum = 'bekliyor') desc, pl.zaman desc)
      from (select * from oyun.yp_duyuru_plan order by (durum = 'bekliyor') desc, zaman desc limit 30) pl
      left join oyun.yp_islem i on i.id = pl.islem_id), '[]'::jsonb),
    'haberler', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'zaman', o.zaman, 'metin', o.metin) order by o.id desc)
      from (select * from oyun.olaylar where tur = 'duyuru' order by id desc limit 20) o), '[]'::jsonb),
    'bant', jsonb_build_object('deger', coalesce(oyun.uyg_ayar('duyuru_bandi') #>> '{}', ''),
      'planli', exists (select 1 from oyun.yp_ayar_plan pl, jsonb_array_elements(pl.degisiklikler) x
                        where pl.durum = 'bekliyor' and x->>'anahtar' = 'uygulama.duyuru_bandi')),
    'push', oyun.yp_push_durum(),
    'kitle', jsonb_build_object('toplam', (select count(*) from oyun.profiller where not yasakli),
      'aktif_7g', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '7 days')));
end $$;

create or replace function public.yp_olaylar()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); v_ay int := extract(month from (oyun.simdi() at time zone 'Europe/Istanbul'));
begin
  return jsonb_build_object(
    'ulusal_sablon', coalesce((select jsonb_agg(jsonb_build_object('kod', s.kod, 'kapsam', s.kapsam, 'kategori', s.kategori, 'baslik', s.baslik,
        'aciklama', s.aciklama, 'bakanlik', (select ad from oyun.bakanliklar where kod = s.bakanlik), 'il_havuzu', to_jsonb(s.il_havuzu), 'baslangic', s.baslangic)
        order by s.kapsam desc, s.baslik) from oyun.uk_sablon s), '[]'::jsonb),
    'ulke_sablon', coalesce((select jsonb_agg(jsonb_build_object('kod', s.kod, 'kategori', s.kategori, 'baslik', s.baslik, 'aciklama', s.aciklama,
        'bakanlik', (select ad from oyun.bakanliklar where kod = s.bakanlik), 'sektor', s.sektor, 'secenek', jsonb_array_length(s.secenekler))
        order by s.kategori, s.baslik) from oyun.kriz_sablon s), '[]'::jsonb),
    'belediye_sablon', coalesce((select jsonb_agg(jsonb_build_object('kod', s.kod, 'baslik', s.baslik, 'metin', s.metin,
        'mevsiminde', s.aylar is null or v_ay = any(s.aylar), 'secenek', jsonb_array_length(s.secenekler)) order by s.baslik)
        from oyun.belediye_kriz_katalog s), '[]'::jsonb),
    'iller', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad,
        'baskan', (select oyun.kad(m.user_id) from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null order by m.id desc limit 1),
        'acik_kriz', exists (select 1 from oyun.belediye_kriz k where k.il_id = i.id and k.durum = 'acik'),
        'nufus', (select count(*) from oyun.profiller x where x.il_id = i.id and not x.yasakli)) order by i.ad) from oyun.iller i), '[]'::jsonb),
    'aktif', jsonb_build_object(
      'ulusal', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'baslik', s.baslik, 'il', (select ad from oyun.iller where id = o.il_id),
          'bas', o.bas, 'asama', o.asama, 'a1_son', o.a1_son, 'a2_son', o.a2_son, 'karar1', o.a1_karar, 'karar2', o.a2_karar) order by o.bas desc)
        from oyun.uk_olay o join oyun.uk_sablon s on s.kod = o.sablon_kod where o.durum = 'aktif'), '[]'::jsonb),
      'ulke', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'baslik', s.baslik, 'bas', o.bas, 'karar_son', o.karar_son,
          'bakanlik', (select ad from oyun.bakanliklar where kod = s.bakanlik)) order by o.bas desc)
        from oyun.kriz_olay o join oyun.kriz_sablon s on s.kod = o.sablon_kod where o.durum = 'bekliyor'), '[]'::jsonb),
      'belediye', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'il', i.ad, 'baslik', c.baslik, 'baskan', oyun.kad(k.baskan),
          'baslangic', k.baslangic, 'son', k.son) order by k.son)
        from oyun.belediye_kriz k join oyun.iller i on i.id = k.il_id left join oyun.belediye_kriz_katalog c on c.kod = k.kod where k.durum = 'acik'), '[]'::jsonb)),
    'gecmis', coalesce((select jsonb_agg(x order by x->>'bas' desc) from (
        (select jsonb_build_object('tur', 'Ulusal kriz', 'baslik', s.baslik || coalesce(' · ' || (select ad from oyun.iller where id = o.il_id), ''),
           'bas', o.bas, 'bit', o.bit, 'durum', o.durum, 'karne', o.karne) x
         from oyun.uk_olay o join oyun.uk_sablon s on s.kod = o.sablon_kod order by o.bas desc limit 8)
        union all
        (select jsonb_build_object('tur', 'Ülke krizi', 'baslik', s.baslik, 'bas', o.bas, 'bit', o.bit, 'durum', o.durum, 'secenek', o.secenek)
         from oyun.kriz_olay o join oyun.kriz_sablon s on s.kod = o.sablon_kod order by o.bas desc limit 8)
        union all
        (select jsonb_build_object('tur', 'Belediye krizi', 'baslik', coalesce(c.baslik, k.kod) || ' · ' || i.ad, 'bas', k.baslangic, 'bit', k.karar_zamani,
           'durum', k.durum, 'secenek', k.secim)
         from oyun.belediye_kriz k join oyun.iller i on i.id = k.il_id left join oyun.belediye_kriz_katalog c on c.kod = k.kod order by k.baslangic desc limit 8)) z), '[]'::jsonb),
    'otomatik', jsonb_build_object(
      'ulusal', (select jsonb_build_object('aktif', a.aktif, 'min_aralik_gun', a.min_aralik_gun, 'haftalik_ihtimal', a.haftalik_ihtimal, 'son_kriz', a.son_kriz) from oyun.uk_ayar a where a.id),
      'ulke', (select jsonb_build_object('aktif', a.aktif, 'min_aralik_gun', a.min_aralik_gun, 'haftalik_ihtimal', a.haftalik_ihtimal, 'son_kriz', a.son_kriz) from oyun.kriz_ayar a where a.id)),
    'haber', coalesce((select jsonb_agg(jsonb_build_object('zaman', o.zaman, 'tur', o.tur, 'metin', o.metin, 'il', (select ad from oyun.iller where id = o.il_id)) order by o.id desc)
      from (select * from oyun.olaylar where zaman <= t order by id desc limit 40) o), '[]'::jsonb));
end $$;

create or replace function public.yp_destek(p_durum text default 'acik')
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); v_acik boolean := coalesce(p_durum, 'acik') <> 'tum';
begin
  return jsonb_build_object(
    'talepler', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'user_id', d.user_id, 'kad', oyun.kad(d.user_id), 'kategori', d.kategori,
        'metin', d.metin, 'zaman', d.zaman, 'durum', d.durum, 'yanit', d.yanit, 'yanit_zaman', d.yanit_zaman, 'surum', d.surum, 'platform', d.platform,
        'yanitlayan', oyun.kad(d.yanitlayan)) order by (d.durum = 'yeni') desc, d.zaman desc)
      from (select * from oyun.destek_talep x where not v_acik or x.durum <> 'kapali' order by x.zaman desc limit 100) d), '[]'::jsonb),
    'sikayetler', coalesce((select jsonb_agg(x order by x->>'durum' desc, x->>'ilk' desc) from (
        select jsonb_build_object('tur', s.tur, 'kayit_id', s.kayit_id, 'hedef', s.hedef_user, 'kad', oyun.kad(s.hedef_user),
          'durum', max(s.durum), 'sayi', count(distinct s.sikayetci), 'nedenler', jsonb_agg(distinct s.neden), 'ilk', min(s.zaman), 'son', max(s.zaman),
          'sikayetciler', (select jsonb_agg(distinct oyun.kad(z.sikayetci)) from oyun.sikayetler z
                           where z.tur = s.tur and z.kayit_id = s.kayit_id and z.hedef_user = s.hedef_user),
          'icerik', oyun.yp_sikayet_icerik(s.tur, s.kayit_id),
          'hedef_susturma', (select susturma_bitis from oyun.profiller where id = s.hedef_user),
          'hedef_toplam', (select count(*) from oyun.sikayetler z where z.hedef_user = s.hedef_user),
          'islem_id', (select i.id from oyun.yp_islem i where i.islem = 'sikayet_karar' and i.durum = 'uygulandi'
                         and i.sonra->>'tur' = s.tur and (i.sonra->>'kayit_id')::bigint = s.kayit_id and i.sonra->>'hedef' = s.hedef_user::text
                       order by i.id desc limit 1)) x
        from oyun.sikayetler s
        where s.durum = 'yeni' or (not v_acik) or s.zaman > now() - interval '7 days'
        group by s.tur, s.kayit_id, s.hedef_user
        order by max(s.durum) desc, min(s.zaman) desc limit 100) q), '[]'::jsonb),
    'mesajlar', coalesce((select jsonb_agg(jsonb_build_object('user_id', c.kisi, 'kad', oyun.kad(c.kisi), 'son', c.son, 'okunmamis', c.okunmamis,
        'mesajlar', (select jsonb_agg(jsonb_build_object('id', m.id, 'gelen', m.alici = p.id, 'metin', m.metin, 'zaman', m.zaman, 'okundu', m.okundu) order by m.zaman)
                     from (select * from oyun.ozel z where (z.gonderen = c.kisi and z.alici = p.id) or (z.gonderen = p.id and z.alici = c.kisi)
                           order by z.zaman desc limit 8) m),
        'son_gelen', (select max(z.id) from oyun.ozel z where z.gonderen = c.kisi and z.alici = p.id)) order by c.okunmamis > 0 desc, c.son desc)
      from (select z.gonderen kisi, max(z.zaman) son, count(*) filter (where not z.okundu) okunmamis
            from oyun.ozel z where z.alici = p.id group by z.gonderen order by max(z.zaman) desc limit 40) c), '[]'::jsonb),
    'sayac', jsonb_build_object(
      'talep', (select count(*) from oyun.destek_talep where durum = 'yeni'),
      'sikayet', (select count(distinct (tur, kayit_id, hedef_user)) from oyun.sikayetler where durum = 'yeni'),
      'mesaj', (select count(*) from oyun.ozel where alici = p.id and not okundu)));
end $$;

-- ---------------------------------------------------------------------
-- 8) Yetkiler (164 ile aynı kural) + oyuncu destek RPC'leri
-- ---------------------------------------------------------------------
do $yp_yetki$
declare r record;
begin
  for r in select p.oid::regprocedure imza from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'oyun' and p.proname like 'yp\_%' loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.imza);
  end loop;
  for r in select p.oid::regprocedure imza from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'yp\_%' loop
    execute format('revoke execute on function %s from public, anon', r.imza);
    execute format('grant execute on function %s to authenticated', r.imza);
  end loop;
  revoke all on function public.destek_gonder(text, text, text, text) from public, anon;
  grant execute on function public.destek_gonder(text, text, text, text) to authenticated;
  revoke all on function public.destek_taleplerim() from public, anon;
  grant execute on function public.destek_taleplerim() to authenticated;
end
$yp_yetki$;
