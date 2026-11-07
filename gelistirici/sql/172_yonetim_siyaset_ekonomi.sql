-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 172) SÜPER YÖNETİCİ PORTALI · AŞAMA 4
--  Siyaset ve ekonomi yönetimi (07.11.2026)
--
--  Okuma:  yp_siyaset (partiler, ittifaklar, devlet, meclis, yüksek mahkeme, 81 il belediyesi)
--          yp_parti   (parti dosyası)
--          yp_ekonomi (göstergeler, para arzı dağılımı, kasalar, büyük transferler, MASAK, Hazine hareketleri)
--          yp_sirketler (şirket listesi)
--  İşlem:  kurum_kasa   — Hazine / bakanlık / belediye / parti / şirket / dernek kasasına ekle-düş (geri alınabilir)
--          parti_duzenle — parti adı, kısa adı, rengi (oyunun ad kuralları; geri alınabilir)
--  Ayar kataloğu: makro ekonomi, servet dengesi, piyasa ve bakanlık parametreleri eklenir.
--
--  Kasa hareketleri oyunun kendi defterlerine yazılır: Hazine → hazine_hareketleri (tetikleyici),
--  bakanlık → bakanlik_hareket (tetikleyici), şirket → sirket_hareket.
--  Oyuncu verisini silmez veya sıfırlamaz.
-- =====================================================================

insert into oyun.yp_katalog (islem, baslik, aciklama, grup, kritik, geri_alinabilir, onay_metni) values
  ('kurum_kasa', 'Kurum kasası düzelt', 'Hazine, bakanlık, belediye, parti, şirket ya da dernek kasasına para ekler veya düşer; oyunun kasa defterine "Oyun yönetimi" kaydı yazılır.', 'ekonomi', true, true, 'ONAYLIYORUM'),
  ('parti_duzenle', 'Parti adı / rengi düzelt', 'Partinin adını, kısa adını ya da rengini oyunun ad kurallarıyla değiştirir. Partinin 7 günlük ad değiştirme hakkı harcanmaz.', 'siyaset', false, true, null)
on conflict (islem) do update set baslik = excluded.baslik, aciklama = excluded.aciklama, grup = excluded.grup,
  kritik = excluded.kritik, geri_alinabilir = excluded.geri_alinabilir, onay_metni = excluded.onay_metni;

-- ---------------------------------------------------------------------
-- 1) Kurum kasası
--    p: tur (hazine | bakanlik | il | parti | sirket | dernek), id, tutar (±), aciklama
--    Hazine ve bakanlık kasaları milyar ₺ (ondalıklı), diğerleri ₺ (tam sayı).
-- ---------------------------------------------------------------------
create or replace function oyun.yp_kasa_bilgi(p_tur text, p_id text)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare r jsonb;
begin
  if p_tur = 'hazine' then
    select jsonb_build_object('ad', 'Hazine', 'kasa', hazine, 'birim', 'milyar ₺') into r from oyun.ulke where id = 1;
  elsif p_tur = 'bakanlik' then
    select jsonb_build_object('ad', coalesce(b.ad, k.kod) || ' kasası', 'kasa', k.kasa, 'birim', 'milyar ₺')
      into r from oyun.bakanlik_kasa k left join oyun.bakanliklar b on b.kod = k.kod where k.kod = p_id;
  elsif p_tur = 'il' and p_id ~ '^\d+$' then
    select jsonb_build_object('ad', i.ad || ' Belediyesi kasası', 'kasa', coalesce(d.kasa, 0), 'birim', '₺', 'satir_var', d.il_id is not null)
      into r from oyun.iller i left join oyun.il_durum d on d.il_id = i.id where i.id = p_id::int;
  elsif p_tur = 'parti' and p_id ~ '^\d+$' then
    select jsonb_build_object('ad', x.kisa || ' parti kasası', 'kasa', x.kasa, 'birim', '₺', 'kapali', x.kapali) into r from oyun.partiler x where x.id = p_id::bigint;
  elsif p_tur = 'sirket' and p_id ~ '^\d+$' then
    select jsonb_build_object('ad', x.ad || ' şirket kasası', 'kasa', x.kasa, 'birim', '₺', 'kapali', not coalesce(x.aktif, true)) into r from oyun.sirketler x where x.id = p_id::bigint;
  elsif p_tur = 'dernek' and p_id ~ '^\d+$' then
    select jsonb_build_object('ad', x.ad || ' dernek kasası', 'kasa', x.kasa, 'birim', '₺', 'kapali', x.kapali) into r from oyun.dernekler x where x.id = p_id::bigint;
  end if;
  return r;
end $$;

create or replace function oyun.yp_on_kurum_kasa(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare tur text := p->>'tur'; b jsonb; x numeric; ac text := oyun.yp_metin(p->>'aciklama', 3, 200); uy jsonb := '[]'::jsonb; milyar boolean;
begin
  if tur not in ('hazine', 'bakanlik', 'il', 'parti', 'sirket', 'dernek') then return jsonb_build_object('engel', 'Kasa türü seçmelisin.'); end if;
  b := oyun.yp_kasa_bilgi(tur, coalesce(p->>'id', ''));
  if b is null then return jsonb_build_object('engel', 'Kasa bulunamadı.'); end if;
  milyar := tur in ('hazine', 'bakanlik');
  if coalesce(p->>'tutar', '') !~ (case when milyar then '^-?\d{1,6}(\.\d{1,3})?$' else '^-?\d{1,12}$' end) then
    return jsonb_build_object('engel', case when milyar then 'Tutar milyar ₺ olarak yazılmalı (ör. 50 ya da -2.5).' else 'Tutar tam sayı ₺ olmalı.' end);
  end if;
  x := (p->>'tutar')::numeric;
  if x = 0 then return jsonb_build_object('engel', 'Tutar sıfır olamaz.'); end if;
  if ac is null then return jsonb_build_object('engel', 'Açıklama yazmalısın (3-200 karakter); kasa defterinde görünür.'); end if;
  if (b->>'kasa')::numeric + x < 0 and tur <> 'hazine' then
    return jsonb_build_object('engel', format('Kasada yeterli para yok (şu an %s).', case when milyar then (round((b->>'kasa')::numeric, 2))::text || ' milyar ₺' else oyun.tl((b->>'kasa')::numeric) || ' ₺' end));
  end if;
  if tur = 'hazine' and (b->>'kasa')::numeric + x < 0 then uy := uy || to_jsonb('Hazine eksiye düşecek: kamu maliyesi modeli enflasyon üretir, bakanlık ödenekleri kesilir.'::text); end if;
  if coalesce((b->>'kapali')::boolean, false) then uy := uy || to_jsonb('Bu kurum kapalı/pasif durumda.'::text); end if;
  if milyar and abs(x) >= 100 then uy := uy || to_jsonb('Büyük kamu tutarı: bütçe dengesini ve enflasyonu etkileyebilir.'::text); end if;
  uy := uy || to_jsonb('Kasa defterine "Oyun yönetimi" açıklamasıyla kaydedilir.'::text);
  return jsonb_build_object(
    'ozet', format('%s: %s%s %s.', b->>'ad', case when x > 0 then '+' else '−' end,
                   case when milyar then trim(trailing '.' from trim(trailing '0' from abs(x)::text)) else oyun.tl(abs(x)) end, b->>'birim'),
    'degisen', jsonb_build_array(jsonb_build_object('alan', b->>'ad',
      'eski', case when milyar then round((b->>'kasa')::numeric, 2)::text || ' milyar ₺' else oyun.tl((b->>'kasa')::numeric) || ' ₺' end,
      'yeni', case when milyar then round((b->>'kasa')::numeric + x, 2)::text || ' milyar ₺' else oyun.tl((b->>'kasa')::numeric + x) || ' ₺' end)),
    'sayi', 1, 'uyarilar', uy,
    -- kasa bakiyesi oyun içinde sürekli değişir; parmak yalnız hedef ve tutarı kapsar
    'parmak', md5(concat_ws('|', tur, p->>'id', x, ac)));
end $$;

create or replace function oyun.yp_kasa_yaz(p_tur text, p_id text, p_tutar numeric, p_aciklama text)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare once numeric; yeni numeric; n int;
begin
  if p_tur = 'hazine' then
    perform set_config('oyun.hazine_islem', left('Oyun yönetimi: ' || p_aciklama, 200), true);
    perform set_config('oyun.hazine_kalem', case when p_tutar >= 0 then 'diger_gelir' else 'diger_gider' end, true);
    select hazine into once from oyun.ulke where id = 1 for update;
    update oyun.ulke set hazine = hazine + p_tutar where id = 1 returning hazine into yeni;
    perform set_config('oyun.hazine_islem', '', true); perform set_config('oyun.hazine_kalem', '', true);
  elsif p_tur = 'bakanlik' then
    perform set_config('oyun.bk_neden', left('yonetim|Oyun yönetimi: ' || p_aciklama, 220), true);
    select kasa into once from oyun.bakanlik_kasa where kod = p_id for update;
    update oyun.bakanlik_kasa set kasa = kasa + p_tutar where kod = p_id and kasa + p_tutar >= 0 returning kasa into yeni;
    perform set_config('oyun.bk_neden', '', true);
  elsif p_tur = 'il' then
    select coalesce(kasa, 0) into once from oyun.il_durum where il_id = p_id::smallint for update;
    update oyun.il_durum set kasa = coalesce(kasa, 0) + p_tutar where il_id = p_id::smallint and coalesce(kasa, 0) + p_tutar >= 0 returning kasa into yeni;
  elsif p_tur = 'parti' then
    select kasa into once from oyun.partiler where id = p_id::bigint for update;
    update oyun.partiler set kasa = kasa + p_tutar where id = p_id::bigint and kasa + p_tutar >= 0 returning kasa into yeni;
  elsif p_tur = 'sirket' then
    select kasa into once from oyun.sirketler where id = p_id::bigint for update;
    update oyun.sirketler set kasa = kasa + p_tutar where id = p_id::bigint and kasa + p_tutar >= 0 returning kasa into yeni;
    if yeni is not null then
      insert into oyun.sirket_hareket (sirket_id, zaman, tutar, aciklama) values (p_id::bigint, oyun.simdi(), p_tutar, left('Oyun yönetimi: ' || p_aciklama, 200));
    end if;
  elsif p_tur = 'dernek' then
    select kasa into once from oyun.dernekler where id = p_id::bigint for update;
    update oyun.dernekler set kasa = kasa + p_tutar where id = p_id::bigint and kasa + p_tutar >= 0 returning kasa into yeni;
  else
    raise exception 'Geçersiz kasa türü.';
  end if;
  if yeni is null then raise exception 'Kasada yeterli para yok ya da kurum bulunamadı.'; end if;
  return jsonb_build_object('once', once, 'sonra', yeni);
end $$;

create or replace function oyun.yp_uy_kurum_kasa(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_kurum_kasa(p); b jsonb := oyun.yp_kasa_bilgi(p->>'tur', coalesce(p->>'id', '')); x numeric := (p->>'tutar')::numeric; r jsonb;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  r := oyun.yp_kasa_yaz(p->>'tur', p->>'id', x, oyun.yp_metin(p->>'aciklama', 3, 200));
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', b->>'ad',
    'once', jsonb_build_object('tur', p->>'tur', 'id', p->>'id', 'kasa', r->'once'),
    'sonra', jsonb_build_object('tur', p->>'tur', 'id', p->>'id', 'kasa', r->'sonra', 'tutar', x),
    'dogrulama', jsonb_build_object('tutarli', (r->>'sonra')::numeric - (r->>'once')::numeric = x,
      'kasa_once', r->'once', 'kasa_sonra', r->'sonra'));
end $$;

create or replace function oyun.yp_gr_kurum_kasa(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare tur text := r.sonra->>'tur'; v_id text := r.sonra->>'id'; x numeric := (r.sonra->>'tutar')::numeric; b jsonb := oyun.yp_kasa_bilgi(tur, v_id);
begin
  if b is null then return jsonb_build_object('engel', 'Kasa artık bulunamıyor.'); end if;
  if x > 0 and tur <> 'hazine' and (b->>'kasa')::numeric < x then
    return jsonb_build_object('engel', 'Eklenen para harcanmış; kasada geri alınacak kadar para yok.');
  end if;
  if p_uygula then perform oyun.yp_kasa_yaz(tur, v_id, -x, 'İşlem #' || r.id || ' geri alındı'); end if;
  return jsonb_build_object('ozet', format('%s: işlem #%s ters kayıtla %s.', b->>'ad', r.id, case when p_uygula then 'geri alındı' else 'geri alınacak' end),
    'sayi', 1, 'once', r.sonra, 'sonra', r.once);
end $$;

-- ---------------------------------------------------------------------
-- 2) Parti adı / kısa adı / rengi
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_parti_duzenle(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pa oyun.partiler; v_ad text; v_kisa text; v_renk text; deg jsonb := '[]'::jsonb;
begin
  if coalesce(p->>'parti_id', '') !~ '^\d+$' then return jsonb_build_object('engel', 'Parti seçmelisin.'); end if;
  select * into pa from oyun.partiler where id = (p->>'parti_id')::bigint;
  if pa.id is null then return jsonb_build_object('engel', 'Parti bulunamadı.'); end if;
  if pa.kapali then return jsonb_build_object('engel', 'Kapalı parti düzenlenemez.'); end if;
  v_ad := coalesce(nullif(btrim(regexp_replace(coalesce(p->>'ad', ''), '\s+', ' ', 'g')), ''), pa.ad);
  v_kisa := coalesce(nullif(upper(btrim(coalesce(p->>'kisa', ''))), ''), pa.kisa);
  v_renk := coalesce(nullif(lower(btrim(coalesce(p->>'renk', ''))), ''), lower(pa.renk));
  if length(v_ad) < 5 or length(v_ad) > 40 then return jsonb_build_object('engel', 'Parti adı 5-40 karakter olmalı.'); end if;
  if v_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then return jsonb_build_object('engel', 'Parti adında yalnızca harf kullanılabilir.'); end if;
  if v_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' then return jsonb_build_object('engel', 'Kısa ad 2-6 büyük harf olmalı.'); end if;
  if v_renk !~ '^#[0-9a-f]{6}$' then return jsonb_build_object('engel', 'Renk #RRGGBB biçiminde olmalı.'); end if;
  if (v_ad <> pa.ad and oyun.yasakli_ad(v_ad)) or (v_kisa <> pa.kisa and oyun.yasakli_kisa(v_kisa)) then
    return jsonb_build_object('engel', 'Gerçek bir partiyi çağrıştıran veya uygunsuz adlar kullanılamaz.');
  end if;
  if exists (select 1 from oyun.partiler x where x.id <> pa.id and not x.kapali and lower(x.ad) = lower(v_ad)) then
    return jsonb_build_object('engel', 'Bu adla bir parti zaten var.');
  end if;
  if exists (select 1 from oyun.partiler x where x.id <> pa.id and not x.kapali and lower(x.kisa) = lower(v_kisa)) then
    return jsonb_build_object('engel', 'Bu kısa ad kullanılıyor.');
  end if;
  if v_ad <> pa.ad then deg := deg || jsonb_build_array(jsonb_build_object('alan', 'Parti adı', 'eski', pa.ad, 'yeni', v_ad)); end if;
  if v_kisa <> pa.kisa then deg := deg || jsonb_build_array(jsonb_build_object('alan', 'Kısa ad', 'eski', pa.kisa, 'yeni', v_kisa)); end if;
  if v_renk <> lower(coalesce(pa.renk, '')) then deg := deg || jsonb_build_array(jsonb_build_object('alan', 'Renk', 'eski', pa.renk, 'yeni', v_renk)); end if;
  if jsonb_array_length(deg) = 0 then return jsonb_build_object('engel', 'Değişiklik yok.'); end if;
  return jsonb_build_object('ozet', format('%s (%s) düzenlenecek.', pa.ad, pa.kisa), 'degisen', deg, 'sayi', 1,
    'uyarilar', jsonb_build_array('Ad değişirse partinin üyelerine bildirim gider ve haber akışına düşer.',
      'Geçmiş seçim sonuçlarında eski ad, seçim anındaki kayıttan gösterilmeye devam eder.'),
    'parmak', md5(concat_ws('|', pa.id, pa.ad, pa.kisa, pa.renk, v_ad, v_kisa, v_renk)));
end $$;

create or replace function oyun.yp_uy_parti_duzenle(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_parti_duzenle(p); pa oyun.partiler; pb oyun.partiler; v_ad text; v_kisa text; v_renk text; t timestamptz := oyun.simdi();
        v_islem bigint := nullif(current_setting('yp.islem_id', true), '')::bigint; ri oyun.yp_islem;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  select * into pa from oyun.partiler where id = (p->>'parti_id')::bigint for update;
  select * into ri from oyun.yp_islem where id = v_islem;
  v_ad := coalesce(nullif(btrim(regexp_replace(coalesce(p->>'ad', ''), '\s+', ' ', 'g')), ''), pa.ad);
  v_kisa := coalesce(nullif(upper(btrim(coalesce(p->>'kisa', ''))), ''), pa.kisa);
  v_renk := coalesce(nullif(lower(btrim(coalesce(p->>'renk', ''))), ''), pa.renk);
  update oyun.partiler set ad = v_ad, kisa = v_kisa, renk = v_renk where id = pa.id returning * into pb;
  if v_ad <> pa.ad or v_kisa <> pa.kisa then
    insert into oyun.parti_ad_gecmis (parti_id, eski_ad, eski_kisa, yeni_ad, yeni_kisa, degistiren, zaman)
    values (pa.id, pa.ad, pa.kisa, v_ad, v_kisa, ri.user_id, t);
    insert into oyun.bildirimler (user_id, zaman, metin)
    select id, t, format('Oyun yönetimi %s (%s) partisinin adını %s (%s) olarak düzeltti.', pa.ad, pa.kisa, v_ad, v_kisa)
    from oyun.profiller where parti_id = pa.id;
    perform oyun.olay('parti', format('%s (%s) partisinin adı %s (%s) olarak düzeltildi.', pa.ad, pa.kisa, v_ad, v_kisa), null, pa.id, t);
  end if;
  return jsonb_build_object('ozet', format('%s düzenlendi.', pb.kisa), 'hedef', pb.ad,
    'once', jsonb_build_object('parti_id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk),
    'sonra', jsonb_build_object('parti_id', pa.id, 'ad', pb.ad, 'kisa', pb.kisa, 'renk', pb.renk),
    'dogrulama', jsonb_build_object('tutarli', pb.ad = v_ad and pb.kisa = v_kisa));
end $$;

create or replace function oyun.yp_gr_parti_duzenle(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = (r.sonra->>'parti_id')::bigint;
  if pa.id is null or pa.kapali then return jsonb_build_object('engel', 'Parti bulunamadı ya da kapalı.'); end if;
  if pa.ad is distinct from r.sonra->>'ad' or pa.kisa is distinct from r.sonra->>'kisa' or pa.renk is distinct from r.sonra->>'renk' then
    return jsonb_build_object('engel', 'Parti bu işlemden sonra yeniden düzenlenmiş; geri alma eski veriyi bozar.');
  end if;
  if exists (select 1 from oyun.partiler x where x.id <> pa.id and not x.kapali
             and (lower(x.ad) = lower(r.once->>'ad') or lower(x.kisa) = lower(r.once->>'kisa'))) then
    return jsonb_build_object('engel', 'Eski ad ya da kısa ad artık başka bir partide kullanılıyor.');
  end if;
  if p_uygula then
    update oyun.partiler set ad = r.once->>'ad', kisa = r.once->>'kisa', renk = r.once->>'renk' where id = pa.id;
    if pa.ad <> r.once->>'ad' or pa.kisa <> r.once->>'kisa' then
      insert into oyun.parti_ad_gecmis (parti_id, eski_ad, eski_kisa, yeni_ad, yeni_kisa, degistiren, zaman)
      values (pa.id, pa.ad, pa.kisa, r.once->>'ad', r.once->>'kisa', r.user_id, oyun.simdi());
    end if;
  end if;
  return jsonb_build_object('ozet', format('%s eski adına (%s · %s) %s.', pa.kisa, r.once->>'ad', r.once->>'kisa', case when p_uygula then 'döndü' else 'dönecek' end),
    'sayi', 1, 'once', r.sonra, 'sonra', r.once);
end $$;

-- ---------------------------------------------------------------------
-- 3) Ayar kataloğu: makro ekonomi, servet dengesi, piyasa, bakanlık
-- ---------------------------------------------------------------------
insert into oyun.yp_ayar_katalog (anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, sira) values
  ('makro.aktif', 'oyun.makro_ayar', 'aktif', null, 'ekonomi', 'Kamu maliyesi modeli',
   'Bütçe açığı / fazlasının enflasyonu ve bakanlık ödeneklerini etkilediği makro model.', 'evet_hayir', null, null, null, null, 'yuksek', 'Bir sonraki günlük ekonomi hesabında.', 40),
  ('makro.enf_tavan', 'oyun.makro_ayar', 'enf_tavan', null, 'ekonomi', 'Enflasyon tavanı',
   'Modelin hedefleyebileceği en yüksek enflasyon.', 'sayi', '%', 1, 200, null, 'orta', 'Bir sonraki günlük ekonomi hesabında.', 41),
  ('makro.enf_taban', 'oyun.makro_ayar', 'enf_taban', null, 'ekonomi', 'Enflasyon tabanı',
   'Modelin hedefleyebileceği en düşük enflasyon.', 'sayi', '%', -10, 50, null, 'orta', 'Bir sonraki günlük ekonomi hesabında.', 42),
  ('makro.k_acik', 'oyun.makro_ayar', 'k_acik', null, 'ekonomi', 'Açık → enflasyon katsayısı',
   'Bütçe açığının GSYH''ye oranındaki her puanın enflasyon hedefine eklediği puan.', 'sayi', null, 0, 5, null, 'orta', 'Bir sonraki günlük ekonomi hesabında.', 43),
  ('makro.k_fazla', 'oyun.makro_ayar', 'k_fazla', null, 'ekonomi', 'Fazla → dezenflasyon katsayısı',
   'Bütçe fazlasında enflasyonu düşüren katsayı.', 'sayi', null, 0, 5, null, 'orta', 'Bir sonraki günlük ekonomi hesabında.', 44),
  ('makro.k_parasal', 'oyun.makro_ayar', 'k_parasal', null, 'ekonomi', 'Parasal finansman katsayısı',
   'Hazine eksideyken (açık/GSYH) × katsayı enflasyon hedefine eklenir.', 'sayi', null, 0, 50, null, 'orta', 'Bir sonraki günlük ekonomi hesabında.', 45),
  ('makro.odenek_kesinti', 'oyun.makro_ayar', 'odenek_kesinti', null, 'ekonomi', 'Ödenek kesinti çarpanı',
   'Hazine eksideyken günlük bakanlık ödeneklerinin çarpanı (1: kesinti yok).', 'sayi', '×', 0, 1, null, 'orta', 'Bir sonraki günlük ödenekte.', 46),
  ('makro.hedef_gun', 'oyun.makro_ayar', 'hedef_gun', null, 'ekonomi', 'Hazine nakit hedefi',
   'Hazine''de tutulması hedeflenen nakit: kaç günlük cari gider.', 'tamsayi', 'gün', 7, 365, null, 'dusuk', default, 47),
  ('denge.aktif', 'oyun.denge_ayar', 'aktif', null, 'ekonomi', 'Servet dengesi',
   'Medyan servetin çok üstündeki servetlere günlük denge vergisi ve fon dağıtımı.', 'evet_hayir', null, null, null, null, 'yuksek', 'Bir sonraki günlük denge hesabında.', 50),
  ('denge.esik1', 'oyun.denge_ayar', 'esik1', null, 'ekonomi', 'Denge vergisi 1. eşik',
   'Medyan servetin bu katının üstü 1. dilimden vergilenir.', 'sayi', '× medyan', 1, 1000, null, 'orta', 'Bir sonraki günlük denge hesabında.', 51),
  ('denge.esik2', 'oyun.denge_ayar', 'esik2', null, 'ekonomi', 'Denge vergisi 2. eşik',
   'Medyan servetin bu katının üstü 2. dilimden vergilenir.', 'sayi', '× medyan', 1, 1000, null, 'orta', 'Bir sonraki günlük denge hesabında.', 52),
  ('denge.esik3', 'oyun.denge_ayar', 'esik3', null, 'ekonomi', 'Denge vergisi 3. eşik',
   'Medyan servetin bu katının üstü 3. dilimden vergilenir.', 'sayi', '× medyan', 1, 1000, null, 'orta', 'Bir sonraki günlük denge hesabında.', 53),
  ('denge.oran1', 'oyun.denge_ayar', 'oran1', null, 'ekonomi', '1. dilim günlük oran',
   'Günlük oran (0,001 = binde 1).', 'sayi', null, 0, 0.05, null, 'orta', 'Bir sonraki günlük denge hesabında.', 54),
  ('denge.oran2', 'oyun.denge_ayar', 'oran2', null, 'ekonomi', '2. dilim günlük oran',
   'Günlük oran (0,002 = binde 2).', 'sayi', null, 0, 0.05, null, 'orta', 'Bir sonraki günlük denge hesabında.', 55),
  ('denge.oran3', 'oyun.denge_ayar', 'oran3', null, 'ekonomi', '3. dilim günlük oran',
   'Günlük oran (0,0035 = binde 3,5).', 'sayi', null, 0, 0.05, null, 'orta', 'Bir sonraki günlük denge hesabında.', 56),
  ('denge.fon_pay', 'oyun.denge_ayar', 'fon_pay', null, 'ekonomi', 'Denge vergisinin fona giden payı',
   'Toplanan denge vergisinin oyunculara dağıtılan fona giden payı (0–1).', 'sayi', null, 0, 1, null, 'dusuk', default, 57),
  ('denge.rekabet_pay', 'oyun.denge_ayar', 'rekabet_pay', null, 'ekonomi', 'Yıkıcı rekabet pazar payı eşiği',
   'Bu pazar payının üstündeki şirketler yıkıcı rekabet incelemesine girer.', 'sayi', '%', 1, 100, null, 'dusuk', default, 58),
  ('denge.rekabet_ceza', 'oyun.denge_ayar', 'rekabet_ceza', null, 'ekonomi', 'Yıkıcı rekabet cezası',
   'Ceza: şirket kasasının oranı (0,10 = %10).', 'sayi', null, 0, 1, null, 'orta', default, 59),
  ('pazar.kurumlar', 'oyun.pazar_ayar', 'kurumlar', null, 'ekonomi', 'Kurumlar vergisi',
   'Şirket kârlarından alınan kurumlar vergisi.', 'sayi', '%', 0, 60, null, 'orta', default, 60),
  ('pazar.tl_milyar', 'oyun.pazar_ayar', 'tl_milyar', null, 'ekonomi', 'Kamu ₺ ↔ oyuncu ₺ kuru',
   '1 milyar kamu ₺ = bu kadar oyuncu ₺ (fiyat düzeyiyle çarpılır). Kamu ve oyuncu ekonomisi arasındaki bütün aktarımları etkiler.', 'sayi', '₺', 1000, 10000000, null, 'yuksek', default, 61),
  ('muzayede.komisyon', 'oyun.muzayede_ayar', 'komisyon', null, 'ekonomi', 'Müzayede komisyonu',
   'Müzayede satışlarından alınan komisyon oranı (0,07 = %7).', 'sayi', null, 0, 0.5, null, 'dusuk', 'Yeni satışlarda.', 62),
  ('bakanlik.tavan', 'oyun.bakanlik_ayar', 'tavan', null, 'ekonomi', 'Bakanlık kasası tavanı',
   'Bir bakanlık kasasının ulaşabileceği en yüksek bakiye.', 'sayi', 'milyar ₺', 1, 10000, null, 'orta', default, 70),
  ('bakanlik.talep_ust', 'oyun.bakanlik_ayar', 'talep_ust', null, 'ekonomi', 'Ek ödenek talebi üst sınırı',
   'Bakanlığın tek seferde isteyebileceği en fazla ek ödenek.', 'sayi', 'milyar ₺', 0, 1000, null, 'dusuk', default, 71),
  ('bakanlik.aktarim_oran', 'oyun.bakanlik_ayar', 'aktarim_oran', null, 'ekonomi', 'Bakanlıklar arası aktarım oranı',
   'Kaynak bakanlık kasasının en çok yüzde kaçı başka bakanlığa aktarılabilir.', 'sayi', '%', 0, 100, null, 'dusuk', default, 72)
on conflict (anahtar) do update set
  tablo = excluded.tablo, sutun = excluded.sutun, satir = excluded.satir, grup = excluded.grup, baslik = excluded.baslik,
  aciklama = excluded.aciklama, tur = excluded.tur, birim = excluded.birim, en_az = excluded.en_az, en_cok = excluded.en_cok,
  en_uzun = excluded.en_uzun, risk = excluded.risk, etki = excluded.etki, sira = excluded.sira, aktif = true;

update oyun.yp_ayar_katalog k set aktif = false
where to_regclass(k.tablo) is null
   or not exists (select 1 from pg_attribute a where a.attrelid = to_regclass(k.tablo) and a.attname = k.sutun and not a.attisdropped);

-- ---------------------------------------------------------------------
-- 4) Okuma
-- ---------------------------------------------------------------------
create or replace function public.yp_siyaset()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'partiler', coalesce((select jsonb_agg(jsonb_build_object(
        'id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'kapali', pa.kapali, 'sistem', pa.sistem, 'kurulus', pa.kurulus,
        'kurulus_bit', pa.kurulus_bit, 'kasa', pa.kasa, 'gb', oyun.kad(pa.gb), 'gb_id', pa.gb,
        'uye', (select count(*) from oyun.profiller x where x.parti_id = pa.id),
        'aktif_uye', (select count(*) from oyun.profiller x where x.parti_id = pa.id and x.son_gorulme > t - interval '7 days'),
        'teskilat', (select count(*) from oyun.parti_teskilat_gorev g where g.parti_id = pa.id and g.aktif),
        'mv', (select count(*) from oyun.makamlar m where m.parti_id = pa.id and m.tur = 'mv' and m.bit is null),
        'belediye', (select count(*) from oyun.makamlar m where m.parti_id = pa.id and m.tur = 'bel' and m.bit is null),
        'ittifak', (select i.ad from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = pa.id limit 1))
        order by pa.kapali, (select count(*) from oyun.profiller x where x.parti_id = pa.id) desc, pa.kisa)
      from oyun.partiler pa where not pa.kapali or exists (select 1 from oyun.profiller x where x.parti_id = pa.id)), '[]'::jsonb),
    'kapali_parti', (select count(*) from oyun.partiler where kapali),
    'bagimsiz', (select count(*) from oyun.profiller where parti_id is null and not yasakli),
    'ittifaklar', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad, 'kurulus', i.kurulus,
        'partiler', (select jsonb_agg(pa.kisa order by pa.kisa) from oyun.ittifak_uyeler u join oyun.partiler pa on pa.id = u.parti_id where u.ittifak_id = i.id)))
      from oyun.ittifaklar i), '[]'::jsonb),
    'devlet', coalesce((select jsonb_agg(jsonb_build_object('makam_id', m.id, 'tur', m.tur, 'ad', oyun.makam_ad(m.tur, m.il_id, m.bakanlik),
        'kad', oyun.kad(m.user_id), 'user_id', m.user_id, 'parti', (select kisa from oyun.partiler where id = m.parti_id), 'bas', m.bas, 'kaynak', m.kaynak)
        order by case m.tur when 'cb' then 1 when 'cb_yardimcisi' then 2 when 'tbmm' then 3 when 'bakan' then 4 when 'bskv' then 5 else 6 end, m.bakanlik)
      from oyun.makamlar m where m.bit is null and m.tur in ('cb', 'cb_yardimcisi', 'tbmm', 'bakan', 'bskv', 'grup_bskv')), '[]'::jsonb),
    'bos_bakanlik', coalesce((select jsonb_agg(b.ad order by b.sira) from oyun.bakanliklar b
      where not exists (select 1 from oyun.makamlar m where m.bit is null and m.tur = 'bakan' and m.bakanlik = b.kod)), '[]'::jsonb),
    'meclis', jsonb_build_object(
      'kontenjan', (select sum(coalesce(mv_secim, mv)) from oyun.iller),
      'dolu', (select count(*) from oyun.makamlar where tur = 'mv' and bit is null),
      'dagilim', coalesce((select jsonb_agg(jsonb_build_object('parti', coalesce(pa.kisa, 'Bağımsız'), 'renk', pa.renk, 'sandalye', z.n) order by z.n desc)
        from (select parti_id, count(*) n from oyun.makamlar where tur = 'mv' and bit is null group by parti_id) z
        left join oyun.partiler pa on pa.id = z.parti_id), '[]'::jsonb)),
    'mahkeme', coalesce((select jsonb_agg(jsonb_build_object('sira', u.sira, 'kad', oyun.kad(u.user_id), 'user_id', u.user_id, 'kaynak', u.kaynak,
        'bas', u.bas, 'gorev_bit', u.gorev_bit, 'bos', u.user_id is null) order by u.sira) from oyun.mahkeme_uye u), '[]'::jsonb),
    'belediyeler', coalesce((select jsonb_agg(jsonb_build_object('il_id', i.id, 'il', i.ad,
        'baskan', (select oyun.kad(m.user_id) from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.il_id = i.id limit 1),
        'baskan_id', (select m.user_id from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.il_id = i.id limit 1),
        'parti', (select pa.kisa from oyun.makamlar m join oyun.partiler pa on pa.id = m.parti_id where m.tur = 'bel' and m.bit is null and m.il_id = i.id limit 1),
        'renk', (select pa.renk from oyun.makamlar m join oyun.partiler pa on pa.id = m.parti_id where m.tur = 'bel' and m.bit is null and m.il_id = i.id limit 1),
        'kasa', coalesce(d.kasa, 0), 'gelisim', d.gelisim, 'memnuniyet', d.memnuniyet, 'kent_vergisi', d.kent_vergisi,
        'nufus', (select count(*) from oyun.profiller x where x.il_id = i.id and not x.yasakli),
        'mv', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.il_id = i.id), 'mv_kontenjan', coalesce(i.mv_secim, i.mv))
        order by i.ad)
      from oyun.iller i left join oyun.il_durum d on d.il_id = i.id), '[]'::jsonb));
end $$;

create or replace function public.yp_parti(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p_id;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  return jsonb_build_object(
    'id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'kapali', pa.kapali, 'sistem', pa.sistem, 'kurulus', pa.kurulus,
    'kurulus_bit', pa.kurulus_bit, 'kasa', pa.kasa, 'aday_ucret', pa.aday_ucret, 'son_ad_degis', pa.son_ad_degis, 'tuzuk_var', pa.tuzuk is not null,
    'gb', oyun.kad(pa.gb), 'gb_id', pa.gb, 'kurucu', oyun.kad(pa.kurucu), 'gb_vekil', oyun.kad(nullif(to_jsonb(pa)->>'gb_vekil', '')::uuid),
    'gby', coalesce((select jsonb_agg(jsonb_build_object('sira', g.sira, 'kad', oyun.kad(g.user_id), 'user_id', g.user_id, 'gorev', g.gorev) order by g.sira)
      from oyun.parti_gby g where g.parti_id = pa.id), '[]'::jsonb),
    'uyeler', coalesce((select jsonb_agg(jsonb_build_object('user_id', x.id, 'kad', x.kad, 'il', i.ad, 'katilim', x.parti_at, 'son_gorulme', x.son_gorulme,
        'cevrimici', x.son_gorulme > t - interval '15 minutes',
        'gorev', (select string_agg(oyun.makam_ad(m.tur, m.il_id, m.bakanlik), ', ') from oyun.makamlar m where m.user_id = x.id and m.bit is null))
        order by x.kad) from oyun.profiller x left join oyun.iller i on i.id = x.il_id where x.parti_id = pa.id), '[]'::jsonb),
    'teskilat', coalesce((select jsonb_agg(jsonb_build_object('il_id', g.il_id, 'il', i.ad, 'kad', oyun.kad(g.user_id), 'aktif', g.aktif) order by i.ad)
      from oyun.parti_teskilat_gorev g join oyun.iller i on i.id = g.il_id where g.parti_id = pa.id), '[]'::jsonb),
    'makamlar', coalesce((select jsonb_agg(jsonb_build_object('makam_id', m.id, 'ad', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'kad', oyun.kad(m.user_id), 'bas', m.bas) order by m.tur, m.il_id)
      from oyun.makamlar m where m.parti_id = pa.id and m.bit is null), '[]'::jsonb),
    'ittifak', (select jsonb_build_object('ad', i.ad, 'partiler', (select jsonb_agg(x.kisa) from oyun.ittifak_uyeler u2 join oyun.partiler x on x.id = u2.parti_id where u2.ittifak_id = i.id))
      from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = pa.id limit 1),
    'gecisler', coalesce((select jsonb_agg(jsonb_build_object('zaman', g.zaman, 'kad', oyun.kad(g.user_id), 'yon', case when g.yeni_parti = pa.id then 'katıldı' else 'ayrıldı' end,
        'diger', (select kisa from oyun.partiler where id = case when g.yeni_parti = pa.id then g.eski_parti else g.yeni_parti end)) order by g.zaman desc)
      from (select * from oyun.parti_gecis where yeni_parti = pa.id or eski_parti = pa.id order by zaman desc limit 15) g), '[]'::jsonb),
    'ad_gecmisi', coalesce((select jsonb_agg(jsonb_build_object('zaman', a.zaman, 'eski', a.eski_ad || ' (' || a.eski_kisa || ')', 'yeni', a.yeni_ad || ' (' || a.yeni_kisa || ')', 'kad', oyun.kad(a.degistiren)) order by a.zaman desc)
      from (select * from oyun.parti_ad_gecmis where parti_id = pa.id order by zaman desc limit 10) a), '[]'::jsonb),
    'adaylar', coalesce((select jsonb_agg(jsonb_build_object('secim', oyun.yp_tur_ad(s.tur) || ' · ' || s.donem, 'kad', oyun.kad(a.user_id), 'il', i.ad, 'sira', a.sira) order by s.oy_bas, i.ad, a.sira)
      from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id left join oyun.iller i on i.id = a.il_id
      where a.parti_id = pa.id and s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false)), '[]'::jsonb));
end $$;

create or replace function public.yp_ekonomi()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); u oyun.ulke; mevduat numeric := 0; oyb numeric := 0;
begin
  select * into u from oyun.ulke where id = 1;
  begin select coalesce(sum(oyun.mevduat_toplam(x.id)), 0) into mevduat from oyun.profiller x; exception when others then mevduat := null; end;
  begin select coalesce(sum(anapara), 0) into oyb from oyun.banka_mevduat where not coalesce(kapandi, false) and not coalesce(iptal, false); exception when others then oyb := null; end;
  return jsonb_build_object(
    'gosterge', jsonb_build_object('hazine', u.hazine, 'enflasyon', u.enflasyon, 'buyume', u.buyume, 'issizlik', u.issizlik, 'memnuniyet', u.memnuniyet,
      'vergi', u.vergi, 'asgari', u.asgari, 'endeks', u.endeks, 'kamu_varlik', u.kamu_varlik, 'belediye_payi', u.belediye_payi, 'parti_yardim', u.parti_yardim),
    'para_arzi', jsonb_build_object(
      'cuzdan', (select coalesce(sum(para), 0) from oyun.cuzdan),
      'devlet_bankasi', mevduat, 'ozel_banka', oyb,
      'sirket', (select coalesce(sum(kasa), 0) from oyun.sirketler where coalesce(aktif, true)),
      'parti', (select coalesce(sum(kasa), 0) from oyun.partiler where not kapali),
      'dernek', (select coalesce(sum(kasa), 0) from oyun.dernekler where not coalesce(kapali, false)),
      'belediye', (select coalesce(sum(kasa), 0) from oyun.il_durum)),
    'bakanliklar', coalesce((select jsonb_agg(jsonb_build_object('kod', k.kod, 'ad', coalesce(b.ad, k.kod), 'kasa', k.kasa) order by b.sira)
      from oyun.bakanlik_kasa k left join oyun.bakanliklar b on b.kod = k.kod), '[]'::jsonb),
    'zenginler', coalesce((select jsonb_agg(jsonb_build_object('user_id', x.user_id, 'kad', oyun.kad(x.user_id), 'para', x.para) order by x.para desc)
      from (select user_id, para from oyun.cuzdan order by para desc limit 10) x), '[]'::jsonb),
    'gelir_24s', coalesce((select jsonb_agg(jsonb_build_object('tur', z.tur, 'tutar', z.s, 'adet', z.n) order by z.s desc)
      from (select tur, sum(tutar) s, count(*) n from oyun.hesap_hareket where zaman > t - interval '24 hours' and tutar > 0 group by tur order by 2 desc limit 12) z), '[]'::jsonb),
    'gider_24s', coalesce((select jsonb_agg(jsonb_build_object('tur', z.tur, 'tutar', z.s, 'adet', z.n) order by z.s)
      from (select tur, sum(tutar) s, count(*) n from oyun.hesap_hareket where zaman > t - interval '24 hours' and tutar < 0 group by tur order by 2 limit 12) z), '[]'::jsonb),
    'transferler', coalesce((select jsonb_agg(jsonb_build_object('zaman', b.zaman, 'gonderen', oyun.kad(b.gonderen), 'alici', oyun.kad(b.alici), 'tutar', b.tutar,
        'aciklama', b.aciklama, 'bagli', exists (select 1 from oyun.bagli_hesaplar(b.gonderen) h where h = b.alici)) order by b.tutar desc)
      from (select * from oyun.banka_transfer where zaman > t - interval '72 hours' order by tutar desc limit 15) b), '[]'::jsonb),
    'masak', jsonb_build_object(
      'bekleyen', (select count(*) from oyun.masak where durum = 'yeni'),
      'son', coalesce((select jsonb_agg(jsonb_build_object('zaman', m.zaman, 'tur', m.tur, 'kad', oyun.kad(m.user_id), 'tutar', m.tutar, 'durum', m.durum, 'aciklama', m.aciklama) order by m.zaman desc)
        from (select * from oyun.masak order by zaman desc limit 10) m), '[]'::jsonb)),
    'hazine_hareket', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'fark', h.fark, 'aciklama', h.aciklama, 'kalem', k.ad) order by h.id desc)
      from (select * from oyun.hazine_hareketleri order by id desc limit 15) h left join oyun.hazine_kalem k on k.kod = h.kalem), '[]'::jsonb));
end $$;

create or replace function public.yp_sirketler(p_ara text default null, p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'kasa', s.kasa, 'sermaye', s.sermaye, 'aktif', s.aktif,
      'kurucu', oyun.kad(s.kurucu), 'yonetici', oyun.kad(s.yonetici), 'halka_acik', s.halka_acik, 'kurulus', s.kurulus,
      'ortak', (select count(*) from oyun.sirket_ortaklari o where o.sirket_id = s.id)) order by s.kasa desc nulls last)
    from (select * from oyun.sirketler x
          where nullif(btrim(coalesce(p_ara, '')), '') is null or x.ad ilike '%' || btrim(p_ara) || '%' or x.sektor ilike '%' || btrim(p_ara) || '%'
             or exists (select 1 from oyun.profiller pr where pr.id = x.kurucu and pr.kad ilike '%' || btrim(p_ara) || '%')
          order by x.kasa desc nulls last limit least(greatest(coalesce(p_limit, 100), 1), 500)) s), '[]'::jsonb);
end $$;

-- dernekler listesi kasa düzeltmesinde seçim için
create or replace function public.yp_dernekler()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'ad', d.ad, 'kasa', d.kasa, 'baskan', oyun.kad(d.baskan), 'kapali', d.kapali) order by d.kasa desc)
    from oyun.dernekler d), '[]'::jsonb);
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
