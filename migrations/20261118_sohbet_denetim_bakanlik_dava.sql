-- 18.11.2026 · (1) Sohbet moderatörleri bütün grup sohbetlerini görür · (2) Bakanlıklar oyunculara dava açar
-- (1) Yeni moderatör yetkisi "sohbet_tum": parti, parti yönetimi, ittifak, kabine, belediye ve oyuncuların özel
--     gruplarındaki mesajları Sohbet nöbetinde görür. Birebir özel mesajlar (DM) yalnız şikâyet edilince görünür.
--     Hesap verebilirlik: kapalı bir kanalı açan moderatörün adı ve kanal, 10 dakikada bir moderasyon günlüğüne yazılır.
-- (2) Bakan (ya da vekili), bakanlığı adına oyuncuya dava açar. Harç bakanlık kasasından ödenir; davacı bakan görünür,
--     dava metninin başında "… Bakanlığı adına" yazar. Kötüye kullanıma sınır: bakanlık başına günde 5 dava, aynı oyuncuya
--     7 günde 2 dava, en çok 15 açık dava. Dokunulmazlık kuralları (CB, milletvekili) mevcut dava açma kuralından gelir.

-- ---------- (1) ----------
create or replace function oyun.mod_yetki_tanim()
returns table(kod text, ad text, aciklama text, sira integer)
language sql immutable set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $$
  values ('ozet',        'Özet',                    'Oyuncu sayısı, aktiflik, açık şikâyet gibi özet rakamları görür.', 1),
         ('sikayet',     'Şikâyetler ve sohbet nöbeti', 'Şikâyet edilen mesaj ve yayınları karara bağlar; herkese açık sohbetleri izler, uygunsuz mesajı gizler.', 2),
         ('sustur',      'Susturma',                'Oyuncuyu susturur, susturmayı kaldırır.', 3),
         ('hesap_kapat', 'Engelleme ve hesap kapatma', 'Oyuncuyu süreli ya da kalıcı engeller; yaptırım taleplerini onaylar.', 4),
         ('oyuncu_ara',  'Oyuncu inceleme',         'Oyuncu dosyasını (bilgi, kısıt geçmişi, son mesajlar, notlar) görür.', 5),
         ('eposta',      'E-posta görme',           'Oyuncu incelerken e-posta adresini de görür (kişisel veri; dikkatli ver).', 6),
         ('duyuru',      'Duyuru ve bildirim',      'Tüm oyunculara duyuru, seçtiği oyunculara bildirim gönderir.', 7),
         ('coklu_hesap', 'Çoklu hesap incelemesi',  'Aynı cihazdan açılan hesapları görür, gerçek kişi olanları onaylar.', 8),
         ('kurallar',    'Kurallar ve ayarlar',     'Vatandaşlık, parti kurma, teşkilat, havale ve banka kurallarını değiştirir.', 9),
         ('ekonomi',     'MASAK (ekonomi denetimi)', 'Şüpheli işlem bildirimlerini inceler; temiz, ihtar ya da el koyma kararı verir.', 10),
         ('para',        'Para ve kıdem',           'Oyunculara, bir ile, bir partiye ya da herkese para ve kıdem ekler veya çıkarır.', 11),
         ('makam',       'Görev verme ve alma',     'Oyuncuyu makama atar, görevden alır; parti görevlerini, ilini, partisini ve aday olma yasağını değiştirir.', 12),
         ('kayit',       'Kayıt onayı',             'Yeni oyuncu başvurularını (kullanıcı adı, ad soyad, il) inceler; oyuna kabul eder ya da gerekçeyle reddeder. Her moderatörde bulunur.', 13),
         ('destek',      'Destek talepleri',        'Oyuncuların destek taleplerini yanıtlar ve kapatır.', 14),
         ('sohbet_tum',  'Tüm grup sohbetlerini görme', 'Parti, ittifak, kabine, belediye ve oyuncuların özel grup sohbetlerini nöbette görür (küfür denetimi). Açtığı her kapalı kanal günlüğe yazılır.', 15)
$$;

create or replace function oyun.mod_birim_tanim()
returns table(kod text, ad text, aciklama text, yetkiler text[], hedef integer, renk text, ikon text, sira integer)
language sql immutable set search_path to '' as $$
  values
  ('kayit',    'Kayıt ve Kimlik Masası',         'Yeni oyuncu başvurularını, ad soyad ve kullanıcı adı uygunluğunu denetler; gerçek siyasetçi ve kamuoyunca bilinen kişi adlarını ayıklar.', array['kayit','oyuncu_ara']::text[], 2, '#5b8def', 'kimlik', 1),
  ('sohbet',   'Sohbet ve Küfür Denetimi',       'Genel, Meclis, il ve bütün grup sohbetlerini (parti, ittifak, kabine, özel gruplar) nöbetle izler; küfür, hakaret, spam ve kışkırtmayı gizler, gerekirse susturur.', array['kayit','sikayet','sustur','oyuncu_ara','sohbet_tum']::text[], 2, '#e0a43a', 'sohbet', 2),
  ('sikayet',  'Şikâyet ve Destek Masası',       'Oyuncu şikâyetlerini karara bağlar, destek taleplerini yanıtlar.', array['kayit','sikayet','destek','oyuncu_ara']::text[], 2, '#c86cd8', 'sikayet', 3),
  ('masak',    'MASAK · Finans Denetimi',        'Şüpheli para hareketlerini, kredi-sermaye döngülerini, ani servetleri ve davet suistimallerini inceler.', array['kayit','ekonomi','oyuncu_ara','ozet']::text[], 2, '#3fb67a', 'masak', 4),
  ('secim',    'Seçim Güvenliği ve Çoklu Hesap', 'Aynı cihaz ve bağlantıdan açılan hesapları, oy ve parti hareketlerini izler; sahte hesapları ayıklar.', array['kayit','coklu_hesap','oyuncu_ara']::text[], 2, '#4fc1d6', 'sandik', 5),
  ('yaptirim', 'Yaptırım Kurulu',                'Ağır ihlallerde süreli ya da kalıcı engel kararı verir; diğer birimlerin yaptırım taleplerini onaylar ya da reddeder.', array['kayit','hesap_kapat','sustur','oyuncu_ara']::text[], 2, '#e5574f', 'terazi', 6),
  ('topluluk', 'Topluluk ve Duyuru',             'Duyuru ve bildirimleri yayımlar, yeni oyunculara rehberlik eder, topluluk iletişimini yürütür.', array['kayit','duyuru','oyuncu_ara']::text[], 2, '#f07f3c', 'megafon', 7)
$$;

-- Sohbet birimindeki mevcut moderatörlere yeni yetki eklenir (yalnız yetki listesine ekleme)
update oyun.moderatorler set yetkiler = (select array_agg(distinct x order by x) from unnest(yetkiler || array['sohbet_tum']) x)
 where ana_gorev = 'sohbet' and not ('sohbet_tum' = any(yetkiler));

create or replace function oyun.mod_kanal_acik(k text) returns boolean
language sql immutable set search_path to '' as $$
  select k = 'genel' or k = 'meclis' or k like 'il:%'
$$;
create or replace function oyun.mod_kanal_grup(k text) returns boolean
language sql immutable set search_path to '' as $$
  select split_part(k, ':', 1) in ('parti','yonetim','ittifak','kabine','belediye','og')
$$;
create or replace function oyun.mod_kanal_ad(k text) returns text
language sql stable set search_path to '' as $$
  select case split_part(k, ':', 1)
    when 'genel' then 'Genel' when 'meclis' then 'Meclis' when 'kabine' then 'Kabine'
    when 'il' then coalesce((select i.ad from oyun.iller i where i.id::text = split_part(k, ':', 2)), 'İl') || ' sohbeti'
    when 'belediye' then coalesce((select i.ad from oyun.iller i where i.id::text = split_part(k, ':', 2)), 'İl') || ' belediyesi'
    when 'parti' then coalesce((select p.kisa from oyun.partiler p where p.id::text = split_part(k, ':', 2)), 'Parti') || ' parti sohbeti'
    when 'yonetim' then coalesce((select p.kisa from oyun.partiler p where p.id::text = split_part(k, ':', 2)), 'Parti') || ' yönetimi'
    when 'ittifak' then coalesce((select a.ad from oyun.ittifaklar a where a.id::text = split_part(k, ':', 2)), 'İttifak')
    when 'og' then 'Grup: ' || coalesce((select g.ad from oyun.sohbet_grup g where g.id::text = split_part(k, ':', 2)), '#' || split_part(k, ':', 2))
    else k end
$$;

-- p_kanal: '' ya da null = herkese açık kanallar · 'il' = tüm iller · 'grup' = bütün grup sohbetleri · '*' = her şey · tek kanal adı
create or replace function public.mod_sohbet_nobeti(p_kanal text default null, p_isaretli boolean default false, p_once bigint default null, p_limit integer default 60)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); t timestamptz := oyun.simdi(); lim int := least(greatest(coalesce(p_limit, 60), 10), 120);
        alt bigint; tum boolean := oyun.yetkili(p.id, 'sohbet_tum'); k text := nullif(btrim(coalesce(p_kanal, '')), '');
begin
  if k is not null and k not in ('il') and (k in ('grup','*') or oyun.mod_kanal_grup(k)) then
    if not tum then raise exception 'Grup sohbetlerini görmek için "Tüm grup sohbetlerini görme" yetkisi gerekir.'; end if;
    if not exists (select 1 from oyun.mod_kayit where user_id = p.id and islem = 'sohbet_izle' and hedef = k and zaman > t - interval '10 minutes') then
      perform oyun.mod_log(p, 'sohbet_izle', k, case when k in ('grup','*') then 'bütün grup sohbetleri' else oyun.mod_kanal_ad(k) end);
    end if;
  end if;
  select coalesce(max(id), 0) - 20000 into alt from oyun.mesajlar;
  return jsonb_build_object('zaman', t, 'tum_yetki', tum,
    'kanallar', coalesce((select jsonb_agg(jsonb_build_object('kanal', z.kanal, 'ad', oyun.mod_kanal_ad(z.kanal), 'sayi', z.n, 'grup', oyun.mod_kanal_grup(z.kanal)) order by z.n desc)
        from (select kanal, count(*) n from oyun.mesajlar where id > alt and zaman > t - interval '24 hours'
                and (oyun.mod_kanal_acik(kanal) or (tum and oyun.mod_kanal_grup(kanal)))
               group by kanal order by count(*) desc limit 30) z), '[]'::jsonb),
    'mesajlar', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kanal', x.kanal, 'kanal_ad', oyun.mod_kanal_ad(x.kanal), 'kad', pr.kad,
          'metin', x.metin, 'zaman', x.zaman, 'gizli', x.gizli, 'isaret', to_jsonb(x.isaret), 'grup', oyun.mod_kanal_grup(x.kanal),
          'susturulmus', pr.susturma_bitis > t, 'moderator', exists (select 1 from oyun.moderatorler mm where mm.user_id = x.user_id) or pr.yonetici,
          'sikayet', (select count(*) from oyun.sikayetler s where s.tur = 'mesaj' and s.kayit_id = x.id)) order by x.id desc)
        from (select y.* from (select m.*, oyun.mod_metin_isaret(m.metin) isaret from oyun.mesajlar m
                 where m.id > alt
                   and case when k is null then oyun.mod_kanal_acik(m.kanal)
                            when k = 'il' then m.kanal like 'il:%'
                            when k = 'grup' then oyun.mod_kanal_grup(m.kanal)
                            when k = '*' then oyun.mod_kanal_acik(m.kanal) or oyun.mod_kanal_grup(m.kanal)
                            else m.kanal = k end
                   and (oyun.mod_kanal_acik(m.kanal) or (tum and oyun.mod_kanal_grup(m.kanal)))
                   and (p_once is null or m.id < p_once)
                 order by m.id desc limit 400) y
               where not coalesce(p_isaretli, false) or (cardinality(y.isaret) > 0 and not y.gizli)
               order by y.id desc limit lim) x
        join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb));
end $$;

-- Pano: sohbet kutusu, yetkisi olana grupları da sayar
do $m$
declare s text := pg_get_functiondef('public.mod_merkez()'::regprocedure);
begin
  if position('mod_kanal_grup' in s) = 0 then
    s := replace(s, 'from oyun.mesajlar x where x.id > son_id and x.zaman > t - interval ''1 hour'' and oyun.mod_kanal_acik(x.kanal)) end',
                    'from oyun.mesajlar x where x.id > son_id and x.zaman > t - interval ''1 hour'' and (oyun.mod_kanal_acik(x.kanal) or (''sohbet_tum'' = any(y) and oyun.mod_kanal_grup(x.kanal)))) end');
    if position('mod_kanal_grup' in s) = 0 then raise exception 'mod_merkez yaması uygulanamadı'; end if;
    execute s;
  end if;
end $m$;

-- ---------- (2) Bakanlık adına dava ----------
alter table oyun.adliye_davalar add column if not exists davaci_bakanlik text;
create index if not exists adliye_davaci_bakanlik_ix on oyun.adliye_davalar(davaci_bakanlik, acilis desc) where davaci_bakanlik is not null;

insert into oyun.tarife(kod, deger, birim, kategori, ad, aciklama) values
  ('bakanlik_dava_gunluk', 5, 'dava', 'kural', 'Bakanlık başına günlük dava', 'Bakanlıkların oyunculara açabileceği günlük dava sayısı'),
  ('bakanlik_dava_kisi_haftalik', 2, 'dava', 'kural', 'Bakanlığın aynı oyuncuya haftalık davası', null),
  ('bakanlik_dava_acik', 15, 'dava', 'kural', 'Bakanlık başına açık dava sınırı', null)
on conflict (kod) do nothing;

create or replace function oyun.bakanliklarim(u uuid) returns table(kod text, ad text, rol text)
language sql stable set search_path to '' as $$
  select b.kod, b.ad, oyun.bm_yetki(u, b.kod) from oyun.bakanliklar b where b.aktif and oyun.bm_yetki(u, b.kod) is not null order by b.sira
$$;

create or replace function public.bakanlik_dava_bilgi()
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); gun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  return jsonb_build_object(
    'bakanliklar', coalesce((select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad, 'rol', b.rol,
        'kasa_tl', round(coalesce((select k.kasa from oyun.bakanlik_kasa k where k.kod = b.kod), 0) * coalesce(oyun.pazar_tl_milyar(), 1000000)),
        'bugun', (select count(*) from oyun.adliye_davalar d where d.davaci_bakanlik = b.kod and (d.acilis at time zone 'Europe/Istanbul')::date = gun),
        'acik', (select count(*) from oyun.adliye_davalar d where d.davaci_bakanlik = b.kod and d.durum = 'acik'),
        'son', (select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'davali', oyun.kad(d.davali), 'tur', d.tur, 'durum', d.durum, 'karar', d.karar, 'acilis', d.acilis) order by d.id desc), '[]'::jsonb)
                  from (select * from oyun.adliye_davalar d2 where d2.davaci_bakanlik = b.kod order by d2.id desc limit 10) d))) from oyun.bakanliklarim(u) b), '[]'::jsonb),
    'limit', jsonb_build_object('gunluk', oyun.gozalti_ayar('bakanlik_dava_gunluk', 5), 'kisi_haftalik', oyun.gozalti_ayar('bakanlik_dava_kisi_haftalik', 2),
             'acik', oyun.gozalti_ayar('bakanlik_dava_acik', 15), 'harc', (select harc from oyun.mahkeme_ayar)),
    'eylemler', case when exists (select 1 from oyun.bakanliklarim(u) b where b.kod = 'icisleri') then coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'il', (select ad from oyun.iller where id = e.il_id), 'baslatan', oyun.kad(e.baslatan), 'gerekce', left(e.gerekce, 200),
        'durum', e.durum, 'baslangic', e.baslangic, 'aktif', e.kapandi is null) order by e.baslangic desc)
      from (select * from oyun.sokak_eylem where baslatan is not null and baslangic > t - interval '7 days' order by baslangic desc limit 15) e), '[]'::jsonb) end);
end $$;

create or replace function public.bakanlik_dava_ac(p_bakanlik text, p_kad text, p_tur text, p_iddia text, p_delil text default '')
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare u uuid := auth.uid(); b record; h oyun.profiller; t timestamptz := oyun.simdi(); gun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date;
        v_harc numeric := coalesce((select ma.harc from oyun.mahkeme_ayar ma), 0); v_kasa numeric; birim numeric := coalesce(oyun.pazar_tl_milyar(), 1000000);
        v_eng text; sure int := coalesce((select avukat_savunma_saat from oyun.ayarlar where id = 1), 24); yeni bigint; metin text;
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  select * into b from oyun.bakanliklarim(u) x where x.kod = p_bakanlik;
  if b.kod is null then raise exception 'Bu bakanlık adına dava açma yetkiniz yok (yalnız bakan ya da vekili).'; end if;
  if p_tur not in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger') then raise exception 'Dava türü geçersiz.'; end if;
  if char_length(btrim(coalesce(p_iddia, ''))) not between 20 and 5000 then raise exception 'Dava açıklaması 20–5000 karakter olmalı.'; end if;
  if char_length(coalesce(p_delil, '')) > 5000 then raise exception 'Delil açıklaması 5000 karakteri aşamaz.'; end if;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, ''))) and not yasakli;
  if h.id is null then raise exception 'Davalı oyuncu bulunamadı.'; end if;
  if h.id = u then raise exception 'Bakanlığınız adına kendinize dava açamazsınız.'; end if;
  v_eng := oyun.dokunulmazlik_engel(h.id, p_tur);
  if v_eng is not null then raise exception '%', v_eng; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('bakanlik_dava:' || b.kod));
  if (select count(*) from oyun.adliye_davalar where davaci_bakanlik = b.kod and (acilis at time zone 'Europe/Istanbul')::date = gun) >= oyun.gozalti_ayar('bakanlik_dava_gunluk', 5) then
    raise exception '% bugün en çok % dava açabilir.', b.ad, oyun.gozalti_ayar('bakanlik_dava_gunluk', 5)::int; end if;
  if (select count(*) from oyun.adliye_davalar where davaci_bakanlik = b.kod and durum = 'acik') >= oyun.gozalti_ayar('bakanlik_dava_acik', 15) then
    raise exception '%nın açık dava sayısı sınıra (%) ulaştı.', b.ad, oyun.gozalti_ayar('bakanlik_dava_acik', 15)::int; end if;
  if (select count(*) from oyun.adliye_davalar where davaci_bakanlik = b.kod and davali = h.id and acilis > t - interval '7 days') >= oyun.gozalti_ayar('bakanlik_dava_kisi_haftalik', 2) then
    raise exception '% son 7 günde % hakkında % dava açtı; daha fazla açılamaz.', b.ad, h.kad, oyun.gozalti_ayar('bakanlik_dava_kisi_haftalik', 2)::int; end if;
  if v_harc > 0 then
    select k.kasa into v_kasa from oyun.bakanlik_kasa k where k.kod = b.kod for update;
    if coalesce(v_kasa, 0) * birim < v_harc then raise exception '% kasasında dava harcı (% ₺) için yeterli para yok.', b.ad, oyun.tl(v_harc); end if;
    update oyun.bakanlik_kasa k set kasa = k.kasa - v_harc / birim where k.kod = b.kod;
  end if;
  metin := format('%s adına açılmıştır (%s: %s). ', b.ad, case b.rol when 'vekalet' then 'Bakan vekili' else 'Bakan' end, oyun.kad(u)) || btrim(p_iddia);
  insert into oyun.adliye_davalar(davaci, davali, tur, iddia, delil, acilis, savunma_son, karar_son, harc, harc_durum, kesin, davaci_bakanlik)
  values (u, h.id, p_tur, metin, coalesce(p_delil, ''), t, t + make_interval(hours => sure),
          t + make_interval(hours => sure) + make_interval(hours => (select ma.karar_saat from oyun.mahkeme_ayar ma)), v_harc, case when v_harc > 0 then 'yatirildi' end, false, b.kod)
  returning id into yeni;
  perform oyun.bildir(h.id, format('%s hakkınızda dava açtı (#%s). %s saat içinde savunma yazabilir ya da avukat tutabilirsiniz: Adliye › dosya.', b.ad, yeni, sure), t);
  perform oyun.bildir(m.user_id, 'Yüksek Mahkeme: #' || yeni || ' numaralı yeni dava dosyası açıldı (' || b.ad || ' davacı).', t)
    from oyun.mahkeme_uye m where m.user_id is not null and m.user_id <> u and m.user_id is distinct from h.id;
  return jsonb_build_object('tamam', true, 'id', yeni, 'harc', v_harc);
end $$;

do $g$
declare f text;
begin
  foreach f in array array['public.mod_sohbet_nobeti(text,boolean,bigint,integer)','public.bakanlik_dava_bilgi()','public.bakanlik_dava_ac(text,text,text,text,text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $g$;
