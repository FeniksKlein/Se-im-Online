-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 174) SÜPER YÖNETİCİ PORTALI · AŞAMA 6
--  Teknik araçlar ve yapay zekâ asistanı kayıtları (07.11.2026)
--
--  Okuma:  yp_sistem      — sürüm, veritabanı boyutu, yedekler, zamanlanmış işler, motor ve zamanlayıcı hataları
--          yp_tutarlilik  — salt okunur tutarlılık kontrolleri (gizli oy: seçmen ile tercih asla birlikte okunmaz)
--          yp_asistan_gecmis — asistan konuşma kaydı
--  İşlem:  yedek_al       — oyunun kendi oyun.yedek_al() fonksiyonuyla tam yedek (son 5 yedek saklanır)
--  Asistan: yp_asistan_kaydet — yp-asistan edge function'ı, sahibin oturumuyla her soruyu/yanıtı buraya yazar.
--
--  Geri yükleme (oyun.yedekten_don) bilerek portala konmadı: o andan sonraki bütün oyuncu
--  ilerlemesini siler; yalnız teknik destekle, sahibin açık izniyle yapılır.
--  Oyuncu verisini silmez veya sıfırlamaz.
-- =====================================================================

insert into oyun.yp_katalog (islem, baslik, aciklama, grup, kritik, geri_alinabilir, onay_metni) values
  ('yedek_al', 'Yedek al', 'Oyunun bütün tablolarının o anki kopyasını alır. Son 5 yedek saklanır; daha eskisi silinir.', 'sistem', false, false, null)
on conflict (islem) do update set baslik = excluded.baslik, aciklama = excluded.aciklama, grup = excluded.grup,
  kritik = excluded.kritik, geri_alinabilir = excluded.geri_alinabilir, onay_metni = excluded.onay_metni;

-- ---------------------------------------------------------------------
-- 1) Yedek al
--    p: aciklama (3-120)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_yedek_listesi()
returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(jsonb_agg(jsonb_build_object('sema', n.nspname, 'aciklama', obj_description(n.oid, 'pg_namespace'),
      'tablo', (select count(*) from pg_class c where c.relnamespace = n.oid and c.relkind = 'r'),
      'boyut', (select coalesce(sum(pg_total_relation_size(c.oid)), 0) from pg_class c where c.relnamespace = n.oid and c.relkind = 'r'))
      order by n.nspname desc), '[]'::jsonb)
  from pg_namespace n where n.nspname like 'yedek\_%'
$$;

create or replace function oyun.yp_on_yedek_al(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare v_ac text := oyun.yp_metin(p->>'aciklama', 3, 120); l jsonb := oyun.yp_yedek_listesi(); n int; uy jsonb := '[]'::jsonb; v_son text;
begin
  if v_ac is null then return jsonb_build_object('engel', 'Yedeğe bir açıklama yaz (3-120 karakter), ör. "Büyük güncelleme öncesi".'); end if;
  n := jsonb_array_length(l); v_son := l->0->>'sema';
  if n >= 5 then
    uy := uy || to_jsonb(format('En fazla 5 yedek saklanır: en eski yedek (%s) silinecek.', coalesce(l->(n - 1)->>'aciklama', l->(n - 1)->>'sema')));
  end if;
  uy := uy || to_jsonb('Yedek alma birkaç saniye sürebilir; oyun bu sırada çalışmaya devam eder.'::text)
            || to_jsonb('Yedekten geri dönüş portaldan yapılmaz: yedekten sonraki bütün oyuncu ilerlemesini siler, yalnız teknik destekle yapılır.'::text);
  return jsonb_build_object('ozet', format('Tam yedek alınacak: “%s”. Şu an %s yedek var.', v_ac, n),
    'degisen', jsonb_build_array(jsonb_build_object('alan', 'Yedek sayısı', 'eski', n::text, 'yeni', least(n + 1, 5)::text)),
    'sayi', 1, 'uyarilar', uy, 'parmak', md5(concat_ws('|', v_ac, v_son)));
end $$;

create or replace function oyun.yp_uy_yedek_al(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_yedek_al(p); v_sema text;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  v_sema := oyun.yedek_al('Portal: ' || oyun.yp_metin(p->>'aciklama', 3, 120));
  return jsonb_build_object('ozet', format('Yedek alındı: %s.', v_sema), 'hedef', v_sema,
    'once', '{}'::jsonb, 'sonra', jsonb_build_object('sema', v_sema),
    'dogrulama', jsonb_build_object('tutarli', exists (select 1 from pg_namespace where nspname = v_sema),
      'tablo', (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = v_sema and c.relkind = 'r')));
end $$;

-- ---------------------------------------------------------------------
-- 2) Sistem durumu
-- ---------------------------------------------------------------------
create or replace function public.yp_sistem()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := now(); v_cron jsonb; v_hata jsonb; v_surum jsonb;
begin
  begin
    execute $q$select coalesce(jsonb_agg(jsonb_build_object('ad', j.jobname, 'zaman', j.schedule, 'aktif', j.active,
        'son', (select max(d.start_time) from cron.job_run_details d where d.jobid = j.jobid),
        'son_durum', (select d.status from cron.job_run_details d where d.jobid = j.jobid order by d.start_time desc limit 1),
        'hata_48s', (select count(*) from cron.job_run_details d where d.jobid = j.jobid and d.status = 'failed' and d.start_time > now() - interval '48 hours'),
        'son_hata', (select left(d.return_message, 400) from cron.job_run_details d where d.jobid = j.jobid and d.status = 'failed' order by d.start_time desc limit 1))
        order by j.active desc, j.jobname), '[]'::jsonb) from cron.job j$q$ into v_cron;
  exception when others then v_cron := '[]'::jsonb; end;
  begin v_surum := to_jsonb(public.surum()); exception when others then v_surum := null; end;
  select coalesce(jsonb_agg(jsonb_build_object('id', h.id, 'adim', h.adim, 'hata', h.hata, 'ayrinti', h.ayrinti, 'ilk', h.zaman, 'son', h.son, 'sayi', h.sayi) order by h.son desc), '[]'::jsonb)
  into v_hata from (select * from oyun.tick_hata order by son desc limit 30) h;
  return jsonb_build_object(
    'zaman', t,
    'surum', v_surum,
    'surum_gecmisi', coalesce((select jsonb_agg(jsonb_build_object('surum', s.surum, 'aciklama', s.aciklama, 'baslangic', s.baslangic, 'bitis', s.bitis) order by s.id desc)
      from (select * from oyun.surumler order by id desc limit 8) s), '[]'::jsonb),
    'oyuncu', jsonb_build_object('toplam', (select count(*) from oyun.profiller where not yasakli),
      'engelli', (select count(*) from oyun.profiller where yasakli),
      'cevrimici', (select count(*) from oyun.profiller where son_gorulme > t - interval '15 minutes'),
      'aktif_24s', (select count(*) from oyun.profiller where son_gorulme > t - interval '24 hours'),
      'aktif_7g', (select count(*) from oyun.profiller where son_gorulme > t - interval '7 days'),
      'yeni_7g', (select count(*) from oyun.profiller where olusturma > t - interval '7 days')),
    'veritabani', jsonb_build_object('boyut', pg_database_size(current_database()),
      'oyun_boyut', (select coalesce(sum(pg_total_relation_size(c.oid)), 0) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r'),
      'tablo_sayisi', (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'oyun' and c.relkind = 'r'),
      'en_buyuk', coalesce((select jsonb_agg(jsonb_build_object('tablo', z.relname, 'boyut', z.b, 'satir', z.satir) order by z.b desc)
        from (select c.relname, pg_total_relation_size(c.oid) b, c.reltuples::bigint satir from pg_class c join pg_namespace n on n.oid = c.relnamespace
              where n.nspname = 'oyun' and c.relkind = 'r' order by 2 desc limit 10) z), '[]'::jsonb)),
    'yedekler', oyun.yp_yedek_listesi(),
    'zamanlayici', v_cron,
    'motor_hatalari', v_hata,
    'push', oyun.yp_push_durum(),
    'portal', jsonb_build_object(
      'islem_7g', (select count(*) from oyun.yp_islem where durum = 'uygulandi' and uygulama > t - interval '7 days'),
      'basarisiz_7g', (select count(*) from oyun.yp_islem where durum = 'basarisiz' and uygulama > t - interval '7 days'),
      'geri_alinan_7g', (select count(*) from oyun.yp_islem where durum = 'geri_alindi' and uygulama > t - interval '7 days'),
      'asistan_7g', (select count(*) from oyun.yp_asistan_kayit where zaman > t - interval '7 days')));
end $$;

-- ---------------------------------------------------------------------
-- 3) Tutarlılık kontrolleri (salt okunur)
--    Her kontrol ayrı çalışır; biri hata verirse diğerleri etkilenmez.
--    Gizli oy: oylar tablosundan yalnız seçim bazında sayı okunur; seçmen kimliği ve tercihi birlikte asla dönmez.
-- ---------------------------------------------------------------------
create or replace function public.yp_tutarlilik()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); k record; v_l jsonb; sonuc jsonb := '[]'::jsonb; h text;
begin
  for k in select * from (values
    ('cift_makam', 'hata', 'Aynı koltukta birden fazla kişi',
     'Cumhurbaşkanı, TBMM Başkanı, bakan ya da belediye başkanı koltuğunda aynı anda birden fazla aktif kayıt var.',
     'Oyuncunun dosyasından ya da Siyaset ekranından fazla kaydı "Görevden al".',
     $q$select format('%s: %s', oyun.makam_ad(min(m.tur), min(m.il_id), min(m.bakanlik)), string_agg(oyun.kad(m.user_id), ', ')) metin, min(m.user_id::text)::uuid user_id
        from oyun.makamlar m where m.bit is null and m.tur in ('cb', 'tbmm', 'bakan', 'bel')
        group by m.tur, coalesce(m.il_id, 0), coalesce(m.bakanlik, '') having count(*) > 1$q$),
    ('cift_gorev', 'uyari', 'Bir oyuncuda aynı türden iki aktif görev',
     'Aynı oyuncunun aynı türden (ör. iki milletvekilliği) birden fazla aktif görevi var.',
     'Oyuncu dosyasında görevleri kontrol et; fazlasını görevden al.',
     $q$select format('%s: %s × %s', oyun.kad(m.user_id), count(*), min(m.tur)) metin, m.user_id from oyun.makamlar m
        where m.bit is null group by m.user_id, m.tur having count(*) > 1$q$),
    ('engelli_makam', 'uyari', 'Engelli hesapta aktif görev',
     'Hesabı engellenmiş oyuncunun hâlâ aktif görevi var; koltuk fiilen boş kalıyor olabilir.',
     'Engel kalıcıysa görevden al; geçiciyse bilgi amaçlıdır.',
     $q$select format('%s · %s', pr.kad, oyun.makam_ad(m.tur, m.il_id, m.bakanlik)) metin, pr.id user_id
        from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id where m.bit is null and pr.yasakli$q$),
    ('kapali_parti_uye', 'hata', 'Kapalı partide görünen üye',
     'Partisi kapatılmış ama profili hâlâ o partiye bağlı oyuncular var.',
     'Oyuncunun dosyasından "Partisini değiştir" ile bağımsız yap.',
     $q$select format('%s · %s (kapalı)', pr.kad, pa.kisa) metin, pr.id user_id
        from oyun.profiller pr join oyun.partiler pa on pa.id = pr.parti_id where pa.kapali$q$),
    ('gb_uye_degil', 'hata', 'Genel başkan kendi partisinin üyesi değil',
     'Açık bir partinin genel başkanı olarak kayıtlı oyuncu o partinin üyesi görünmüyor.',
     'Parti dosyasını ve oyuncunun partisini kontrol et.',
     $q$select format('%s · genel başkan %s (üyeliği: %s)', pa.kisa, pr.kad, coalesce((select kisa from oyun.partiler where id = pr.parti_id), 'bağımsız')) metin, pr.id user_id
        from oyun.partiler pa join oyun.profiller pr on pr.id = pa.gb where not pa.kapali and pr.parti_id is distinct from pa.id$q$),
    ('negatif_kasa', 'hata', 'Eksi bakiyeli kurum kasası',
     'Parti, şirket ya da belediye kasası sıfırın altında (oyuncu cüzdanı ve dernek kasası zaten eksiye düşemez).',
     'Siyaset / Ekonomi ekranlarından "Kasa düzelt".',
     $q$select format('Parti %s: %s ₺', kisa, oyun.tl(kasa)) metin, null::uuid user_id from oyun.partiler where kasa < 0
        union all select format('Şirket %s: %s ₺', ad, oyun.tl(kasa)), null from oyun.sirketler where kasa < 0
        union all select format('%s Belediyesi: %s ₺', i.ad, oyun.tl(d.kasa)), null from oyun.il_durum d join oyun.iller i on i.id = d.il_id where d.kasa < 0$q$),
    ('mv_kontenjan', 'uyari', 'İlde kontenjandan fazla milletvekili',
     'Bir ildeki aktif milletvekili sayısı ilin kontenjanını aşıyor.',
     'Siyaset › Belediyeler tablosundaki MV sütununu ve ilgili seçimi kontrol et.',
     $q$select format('%s: %s / %s', i.ad, z.n, coalesce(i.mv_secim, i.mv)) metin, null::uuid user_id
        from (select il_id, count(*) n from oyun.makamlar where tur = 'mv' and bit is null group by il_id) z
        join oyun.iller i on i.id = z.il_id where z.n > coalesce(i.mv_secim, i.mv)$q$),
    ('takili_secim', 'hata', 'Sonuç saati geçtiği hâlde sonuçlanmamış seçim',
     'Sonuç açıklama saatinden 15 dakikadan uzun süre geçmiş ama seçim hâlâ "bekliyor".',
     'Seçimler ekranından seçimi aç; seçim motorunun çalıştığını Sistem › Zamanlanmış işler bölümünden kontrol et.',
     $q$select format('#%s %s · sonuç saati %s', s.id, oyun.yp_tur_ad(s.tur), oyun.tr_tarih_saat(coalesce(s.sonuc_at, s.oy_bit))) metin, null::uuid user_id
        from oyun.secimler s where s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false)
          and coalesce(s.sonuc_at, s.oy_bit) < now() - interval '15 minutes'$q$),
    ('oy_pencere_disi', 'uyari', 'Oylama saatleri dışında kayıtlı oy',
     'Oy kaydının zamanı seçimin oylama başlangıcı ile bitişi arasında değil. Takvim oy verildikten sonra değiştirildiyse normaldir. Gizli oy gereği yalnız sayı gösterilir.',
     'Seçimin takvim geçmişini İşlem geçmişinden kontrol et.',
     $q$select format('#%s %s: %s oy', s.id, oyun.yp_tur_ad(s.tur), count(*)) metin, null::uuid user_id
        from oyun.oylar o join oyun.secimler s on s.id = o.secim_id
        where o.zaman < s.oy_bas - interval '1 minute' or o.zaman > s.oy_bit + interval '1 minute' group by s.id, s.tur$q$),
    ('takili_plan', 'uyari', 'Zamanı geçmiş ama uygulanmamış plan',
     'Planlı ayar ya da duyuru, zamanından 5 dakikadan uzun süre sonra hâlâ bekliyor. Zamanlayıcı çalışmıyor olabilir.',
     'Sistem › Zamanlanmış işler bölümünde yp-ayar-plan ve yp-duyuru-plan işlerine bak.',
     $q$select format('Ayar planı #%s · %s', id, oyun.tr_tarih_saat(zaman)) metin, null::uuid user_id from oyun.yp_ayar_plan where durum = 'bekliyor' and zaman < now() - interval '5 minutes'
        union all select format('Duyuru planı #%s · %s', id, oyun.tr_tarih_saat(zaman)), null from oyun.yp_duyuru_plan where durum = 'bekliyor' and zaman < now() - interval '5 minutes'$q$),
    ('takili_kriz', 'uyari', 'Süresi geçmiş ama kapanmamış kriz',
     'Karar süresi 1 saatten uzun süre önce dolmuş ama hâlâ açık görünen ülke ya da belediye krizi var.',
     'Olaylar ekranında süren krizlere bak; kriz motorunun çalıştığını Sistem ekranından kontrol et.',
     $q$select format('Ülke krizi #%s · süre %s doldu', id, oyun.tr_tarih_saat(karar_son)) metin, null::uuid user_id from oyun.kriz_olay where durum = 'bekliyor' and karar_son < now() - interval '1 hour'
        union all select format('%s belediye krizi #%s · süre %s doldu', (select ad from oyun.iller where id = k.il_id), k.id, oyun.tr_tarih_saat(k.son)), null
          from oyun.belediye_kriz k where k.durum = 'acik' and k.son < now() - interval '1 hour'$q$),
    ('zamanlayici_hata', 'hata', 'Hata veren zamanlanmış iş',
     'Son 48 saatte en az bir kez hata veren zamanlanmış (cron) işler. Hata veren iş o gün yapması gerekeni yapmamıştır.',
     'Sistem ekranında hatanın ayrıntısına bak; düzeltme kod değişikliği gerektirir.',
     $q$select format('%s: %s kez · %s', j.jobname, count(*), left(max(d.return_message), 160)) metin, null::uuid user_id
        from cron.job_run_details d join cron.job j on j.jobid = d.jobid
        where d.status = 'failed' and d.start_time > now() - interval '48 hours' group by j.jobname$q$),
    ('motor_hata', 'uyari', 'Oyun motorunda son 24 saatteki hatalar',
     'Oyun motorunun dakikalık adımlarından biri hata kaydı yazmış.',
     'Sistem › Motor hataları bölümünde ayrıntıya bak.',
     $q$select format('%s: %s (%s kez)', adim, left(hata, 160), sayi) metin, null::uuid user_id from oyun.tick_hata where son > now() - interval '24 hours'$q$),
    ('profilsiz_cuzdan', 'bilgi', 'Profili olmayan cüzdan',
     'Cüzdan kaydı var ama oyuncu profili yok (silinmiş hesap kalıntısı olabilir).',
     'Bilgi amaçlıdır; oyuncuyu etkilemez.',
     $q$select format('%s · %s ₺', c.user_id, oyun.tl(c.para)) metin, null::uuid user_id from oyun.cuzdan c where not exists (select 1 from oyun.profiller p where p.id = c.user_id)$q$)
  ) v(kod, seviye, baslik, aciklama, cozum, sorgu) loop
    begin
      execute format('select coalesce(jsonb_agg(jsonb_build_object(%L, x.metin, %L, x.user_id)), %L::jsonb) from (%s limit 200) x',
                     'metin', 'user_id', '[]', k.sorgu) into v_l;
      sonuc := sonuc || jsonb_build_array(jsonb_build_object('kod', k.kod, 'seviye', k.seviye, 'baslik', k.baslik, 'aciklama', k.aciklama,
        'cozum', k.cozum, 'sayi', jsonb_array_length(v_l), 'ornekler', (select coalesce(jsonb_agg(e), '[]'::jsonb) from (select e from jsonb_array_elements(v_l) e limit 15) z)));
    exception when others then
      get stacked diagnostics h = message_text;
      sonuc := sonuc || jsonb_build_array(jsonb_build_object('kod', k.kod, 'seviye', k.seviye, 'baslik', k.baslik, 'aciklama', k.aciklama,
        'cozum', k.cozum, 'sayi', null, 'hata', left(h, 300), 'ornekler', '[]'::jsonb));
    end;
  end loop;
  return jsonb_build_object('zaman', now(), 'kontroller', sonuc,
    'sorunlu', (select count(*) from jsonb_array_elements(sonuc) e where coalesce((e->>'sayi')::int, 0) > 0 and e->>'seviye' <> 'bilgi'));
end $$;

-- ---------------------------------------------------------------------
-- 4) Yapay zekâ asistanı kaydı
--    Asistan (edge function yp-asistan) sahibin kendi oturumuyla çalışır: yalnız yp_* okuma
--    fonksiyonlarını ve yp_onizle'yi çağırabilir; yp_uygula'yı hiçbir zaman çağırmaz.
--    Her soru, yanıt, kullandığı araçlar ve hazırladığı ön izlemeler burada saklanır.
-- ---------------------------------------------------------------------
create table if not exists oyun.yp_asistan_kayit (
  id bigserial primary key,
  zaman timestamptz not null default now(),
  user_id uuid not null,
  kad text,
  soru text not null,
  yanit text,
  araclar jsonb not null default '[]'::jsonb,
  onizlemeler jsonb not null default '[]'::jsonb,
  model text,
  girdi_token int,
  cikti_token int,
  hata text
);
create index if not exists yp_asistan_kayit_zaman on oyun.yp_asistan_kayit (zaman desc);
alter table oyun.yp_asistan_kayit enable row level security;

create or replace function public.yp_asistan_kaydet(p_soru text, p_yanit text, p_araclar jsonb default '[]'::jsonb, p_onizlemeler jsonb default '[]'::jsonb,
  p_model text default null, p_girdi_token integer default null, p_cikti_token integer default null, p_hata text default null)
returns bigint language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); v_id bigint;
begin
  insert into oyun.yp_asistan_kayit (user_id, kad, soru, yanit, araclar, onizlemeler, model, girdi_token, cikti_token, hata)
  values (p.id, p.kad, left(coalesce(p_soru, ''), 4000), left(p_yanit, 20000),
          case when jsonb_typeof(p_araclar) = 'array' then p_araclar else '[]'::jsonb end,
          case when jsonb_typeof(p_onizlemeler) = 'array' then p_onizlemeler else '[]'::jsonb end,
          left(p_model, 80), p_girdi_token, p_cikti_token, left(p_hata, 1000))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.yp_asistan_gecmis(p_limit integer default 30)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'zaman', k.zaman, 'kad', k.kad, 'soru', k.soru, 'yanit', k.yanit,
      'araclar', k.araclar, 'onizlemeler', k.onizlemeler, 'model', k.model, 'girdi_token', k.girdi_token, 'cikti_token', k.cikti_token, 'hata', k.hata) order by k.id desc)
    from (select * from oyun.yp_asistan_kayit order by id desc limit least(greatest(coalesce(p_limit, 30), 1), 200)) k), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5) Yetkiler (164 ile aynı kural)
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
end
$yp_yetki$;
