-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 168) SÜPER YÖNETİCİ PORTALI · AŞAMA 2
--  Oyuncu yönetimi + toplu işlem merkezi (07.11.2026)
--
--  164'teki ön izle → uygula → geri al çerçevesine yeni işlemler ekler:
--    oyuncu_para · oyuncu_kidem · oyuncu_il · oyuncu_parti · makam_ver · makam_al ·
--    hesap_engelle · engel_kaldir · sustur · oyuncu_bildirim
--
--  Kurallar
--    • Oyunun kendi kuralları yeniden kullanılır: para_islem (hesap hareketi yazar), kidem_ekle,
--      yk_parti_degistir (_ayril), yk_makam_ver, yk_makam_al (makam_bitir → yedek getir).
--    • Parti / görev işlemlerinin ön izlemesi "kuru çalıştırma"dır: işlem bir alt işlemde gerçekten
--      denenir, kim hangi görevi kaybeder / kazanır ölçülür ve her şey geri sarılır. Böylece ön izleme
--      ile gerçek sonuç aynı kurallardan çıkar.
--    • Toplu işlemde her oyuncu ayrı alt işlemdir: biri başarısız olursa diğerleri etkilenmez;
--      sonuç "eklenen" ve "eklenemeyen" olarak ayrı listelenir.
--    • Yönetici hesabı filtreyle hiçbir toplu işleme girmez; ancak açıkça seçilirse girer.
--    • Oy tercihi hiçbir çıktıda yer almaz; yalnız oy hakkı (engel metni) ve katılım.
--
--  Oyuncu verisini silmez veya sıfırlamaz; yalnız yeni fonksiyon ve katalog satırı ekler.
-- =====================================================================

insert into oyun.yp_katalog (islem, baslik, aciklama, grup, kritik, geri_alinabilir, onay_metni) values
  ('oyuncu_para', 'Para ekle / düş', 'Seçilen oyuncuların cüzdanına para ekler ya da düşer; hesap hareketlerine "yönetici" kaydı yazılır.', 'oyuncu', true, true, 'ONAYLIYORUM'),
  ('oyuncu_kidem', 'Kıdem puanı ekle / düş', 'Seçilen oyuncuların kıdem puanını değiştirir (sıfırın altına inmez).', 'oyuncu', false, true, null),
  ('oyuncu_il', 'İl düzelt / taşı', 'Oyuncunun ilini değiştirir; eski ildeki il başkanlığı kapanır, bekleyen adaylıklar yeni ile taşınır ya da iptal edilir.', 'oyuncu', false, true, null),
  ('oyuncu_parti', 'Partisini değiştir', 'Oyuncuyu başka partiye geçirir ya da bağımsız yapar; oyunun parti ayrılma kuralları uygulanır.', 'oyuncu', true, false, 'ONAYLIYORUM'),
  ('makam_ver', 'Görev ver', 'Oyuncuya CB, bakan, vekil, belediye başkanı, TBMM başkanı, genel başkan vb. görevi verir.', 'oyuncu', true, false, 'ONAYLIYORUM'),
  ('makam_al', 'Görevden al', 'Oyuncunun bir görevini sonlandırır (vekillikte yedek aday göreve gelir).', 'oyuncu', true, false, 'ONAYLIYORUM'),
  ('hesap_engelle', 'Hesabı engelle', 'Hesabı süreli ya da kalıcı engeller. Görevleri ve verileri silinmez.', 'oyuncu', true, true, 'ONAYLIYORUM'),
  ('engel_kaldir', 'Engeli kaldır', 'Hesap engelini kaldırır.', 'oyuncu', false, true, null),
  ('sustur', 'Sohbette sustur / susturmayı kaldır', 'Sohbette yazmayı belirli süre kapatır; 0 saat susturmayı kaldırır.', 'oyuncu', false, true, null),
  ('oyuncu_bildirim', 'Bildirim gönder', 'Seçilen oyunculara oyun içi bildirim gönderir.', 'oyuncu', false, false, null)
on conflict (islem) do update set
  baslik = excluded.baslik, aciklama = excluded.aciklama, grup = excluded.grup,
  kritik = excluded.kritik, geri_alinabilir = excluded.geri_alinabilir, onay_metni = excluded.onay_metni;

-- ---------------------------------------------------------------------
-- 1) Hedef seçimi
--    p.user_id                → tek oyuncu
--    p.kullanicilar [uuid…]   → açıkça seçilen oyuncular (engelli / yönetici dahil)
--    p.filtre {…}             → filtre (yönetici hiç, engelli yalnız durum=engelli iken)
--      ara, il_id, parti_id (0 = bağımsız), durum: tum|herkes|engelli|cevrimici|aktif|pasif|yeni|makamli|susturulmus
-- ---------------------------------------------------------------------
create or replace function oyun.yp_filtre(f jsonb, p_yonetici_dahil boolean default false)
returns setof oyun.profiller language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); d text := coalesce(nullif(f->>'durum', ''), 'herkes');
begin
  return query
  select pr.* from oyun.profiller pr
  where (p_yonetici_dahil or not coalesce(pr.yonetici, false))
    and (case when d = 'tum' then true when d = 'engelli' then pr.yasakli else not pr.yasakli end)
    and (nullif(f->>'ara', '') is null or pr.kad ilike '%' || btrim(f->>'ara') || '%')
    and (nullif(f->>'il_id', '') is null or pr.il_id = (f->>'il_id')::int)
    and (nullif(f->>'parti_id', '') is null
         or (f->>'parti_id' = '0' and pr.parti_id is null)
         or pr.parti_id = nullif(f->>'parti_id', '0')::bigint)
    and (case d
      when 'cevrimici' then pr.son_gorulme > t - interval '15 minutes'
      when 'aktif' then pr.son_gorulme > t - interval '7 days'
      when 'pasif' then pr.son_gorulme is null or pr.son_gorulme <= t - interval '7 days'
      when 'yeni' then pr.olusturma > t - interval '3 days'
      when 'makamli' then exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null)
      when 'susturulmus' then pr.susturma_bitis > t
      else true end)
  order by pr.kad;
end $$;

create or replace function oyun.yp_hedef_listesi(p jsonb)
returns setof oyun.profiller language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
begin
  if nullif(p->>'user_id', '') is not null then
    return query select * from oyun.profiller where id = (p->>'user_id')::uuid;
  elsif jsonb_typeof(p->'kullanicilar') = 'array' and jsonb_array_length(p->'kullanicilar') > 0 then
    return query select * from oyun.profiller
      where id in (select (x #>> '{}')::uuid from jsonb_array_elements(p->'kullanicilar') x) order by kad;
  elsif jsonb_typeof(p->'filtre') = 'object' then
    return query select * from oyun.yp_filtre(p->'filtre', false);
  end if;
end $$;

create or replace function oyun.yp_hedef_ad(p jsonb)
returns text language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare f jsonb := p->'filtre'; n int; parca text[] := '{}';
begin
  if nullif(p->>'user_id', '') is not null then return oyun.kad((p->>'user_id')::uuid); end if;
  if jsonb_typeof(p->'kullanicilar') = 'array' and jsonb_array_length(p->'kullanicilar') > 0 then
    n := jsonb_array_length(p->'kullanicilar');
    if n = 1 then return oyun.kad((p->'kullanicilar'->>0)::uuid); end if;
    return n || ' seçili oyuncu';
  end if;
  if jsonb_typeof(f) <> 'object' then return 'hedef yok'; end if;
  if nullif(f->>'il_id', '') is not null then parca := parca || (select ad from oyun.iller where id = (f->>'il_id')::int); end if;
  if f->>'parti_id' = '0' then parca := parca || 'bağımsızlar'::text;
  elsif nullif(f->>'parti_id', '') is not null then parca := parca || (select kisa from oyun.partiler where id = (f->>'parti_id')::bigint); end if;
  if coalesce(f->>'durum', 'herkes') <> 'herkes' then parca := parca || (f->>'durum'); end if;
  if nullif(f->>'ara', '') is not null then parca := parca || ('"' || (f->>'ara') || '"'); end if;
  return 'Filtre: ' || coalesce(nullif(array_to_string(parca, ' · '), ''), 'bütün oyuncular');
end $$;

create or replace function oyun.yp_oyuncu_kisa(h oyun.profiller)
returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select jsonb_build_object('user_id', h.id, 'kad', h.kad,
    'il', (select ad from oyun.iller where id = h.il_id),
    'parti', (select kisa from oyun.partiler where id = h.parti_id))
$$;

-- Hedef listesi için ortak engeller: boş seçim, çok büyük seçim
create or replace function oyun.yp_hedef_engel(p jsonb, n int)
returns text language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case
    when nullif(p->>'user_id', '') is null and coalesce(jsonb_array_length(case when jsonb_typeof(p->'kullanicilar') = 'array' then p->'kullanicilar' end), 0) = 0
         and coalesce(jsonb_typeof(p->'filtre'), '') <> 'object' then 'Önce oyuncu seç ya da filtre belirle.'
    when n = 0 then 'Seçime uyan oyuncu yok.'
    when n > 2000 then 'Bir seferde en fazla 2000 oyuncuya işlem yapılabilir.'
  end
$$;

-- ---------------------------------------------------------------------
-- 2) Görev izi + oy hakkı (kuru çalıştırmada önce/sonra karşılaştırması)
-- ---------------------------------------------------------------------
-- Parti kolları (gençlik, kadın…) yalnız canlı şemada var; yoksa boş döner.
create or replace function oyun.yp_kol_izi()
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare j jsonb;
begin
  if to_regclass('oyun.parti_kol') is null then return '{}'::jsonb; end if;
  execute $q$select coalesce(jsonb_object_agg('kol' || kl.parti_id || ':' || kl.tur || ':' || kl.baskan,
      jsonb_build_object('user_id', kl.baskan, 'kad', oyun.kad(kl.baskan), 'ad', pa.kisa || ' ' || kl.tur || ' kolu başkanı')), '{}'::jsonb)
    from oyun.parti_kol kl join oyun.partiler pa on pa.id = kl.parti_id where kl.baskan is not null$q$ into j;
  return j;
end $$;

create or replace function oyun.yp_gorev_izi()
returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(jsonb_object_agg(x.k, x.v), '{}'::jsonb) from (
    select 'm' || m.id k, jsonb_build_object('user_id', m.user_id, 'kad', oyun.kad(m.user_id), 'ad', oyun.makam_ad(m.tur, m.il_id, m.bakanlik)) v
      from oyun.makamlar m where m.bit is null
    union all
    select 'gb' || pa.id || ':' || pa.gb, jsonb_build_object('user_id', pa.gb, 'kad', oyun.kad(pa.gb), 'ad', pa.kisa || ' Genel Başkanı')
      from oyun.partiler pa where pa.gb is not null and not coalesce(pa.kapali, false)
    union all
    select 'gby' || g.parti_id || ':' || g.sira || ':' || g.user_id,
           jsonb_build_object('user_id', g.user_id, 'kad', oyun.kad(g.user_id), 'ad', pa.kisa || ' ' || g.sira || '. Genel Başkan Yardımcısı')
      from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id
    union all
    select 'te' || tg.parti_id || ':' || tg.il_id || ':' || tg.user_id,
           jsonb_build_object('user_id', tg.user_id, 'kad', oyun.kad(tg.user_id), 'ad', pa.kisa || ' ' || i.ad || ' İl Başkanı')
      from oyun.parti_teskilat_gorev tg join oyun.partiler pa on pa.id = tg.parti_id join oyun.iller i on i.id = tg.il_id
      where tg.aktif
    union all
    select e.key, e.value from jsonb_each(oyun.yp_kol_izi()) e
    union all
    select 'ad' || a.id, jsonb_build_object('user_id', a.user_id, 'kad', oyun.kad(a.user_id),
           'ad', oyun.yp_tur_ad(s.tur) || ' adaylığı' || coalesce(' · ' || i.ad, '') || coalesce(' · ' || pa.kisa, ''))
      from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
      left join oyun.iller i on i.id = a.il_id left join oyun.partiler pa on pa.id = a.parti_id
      where s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false)
    union all
    select 'pa' || pa.id, jsonb_build_object('user_id', null, 'kad', null, 'ad', 'Parti: ' || pa.ad)
      from oyun.partiler pa where not coalesce(pa.kapali, false)
  ) x
$$;

create or replace function oyun.yp_fark(a jsonb, b jsonb)
returns jsonb language sql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select jsonb_build_object(
    'biten', coalesce((select jsonb_agg(a->k order by a->k->>'kad', a->k->>'ad') from jsonb_object_keys(a) k where not b ? k), '[]'::jsonb),
    'baslayan', coalesce((select jsonb_agg(b->k order by b->k->>'kad', b->k->>'ad') from jsonb_object_keys(b) k where not a ? k), '[]'::jsonb))
$$;

-- Önümüzdeki / süren seçimlerde oy hakkı (yalnız engel metni; tercih yok)
create or replace function oyun.yp_oy_hakki(h oyun.profiller)
returns jsonb language sql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(jsonb_agg(jsonb_build_object('secim_id', s.id, 'secim', oyun.yp_tur_ad(s.tur) || ' · ' || s.donem,
      'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit,
      'engel', case when h.yasakli then 'Hesap engelli.' else oyun.oy_engeli(h, s) end,
      'oy_kullandi', exists (select 1 from oyun.oylar o where o.secim_id = s.id and o.secmen = h.id)) order by s.oy_bas), '[]'::jsonb)
  from oyun.secimler s
  where s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.oy_bit > oyun.simdi()
$$;

-- Bir oyuncunun oy hakkındaki değişimi: önce/sonra listesinden yalnız değişen satırlar
create or replace function oyun.yp_oy_hakki_fark(a jsonb, b jsonb)
returns jsonb language sql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select coalesce(jsonb_agg(jsonb_build_object('secim', y->>'secim',
      'once', coalesce(x->>'engel', 'Oy kullanabilir'), 'sonra', coalesce(y->>'engel', 'Oy kullanabilir'))), '[]'::jsonb)
  from jsonb_array_elements(coalesce(b, '[]'::jsonb)) y
  left join jsonb_array_elements(coalesce(a, '[]'::jsonb)) x on x->>'secim_id' = y->>'secim_id'
  where (x->>'engel') is distinct from (y->>'engel')
$$;

-- Kuru çalıştırma: oyun.yp_ck_<islem>(p) bir alt işlemde denenir, fark ölçülür, her şey geri sarılır.
create or replace function oyun.yp_kuru(p_islem text, p jsonb, p_user uuid default null)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare once jsonb := oyun.yp_gorev_izi(); sonra jsonb; s jsonb; h text; oy0 jsonb; oy1 jsonb; pr oyun.profiller; pr1 oyun.profiller;
begin
  if p_user is not null then select * into pr from oyun.profiller where id = p_user; oy0 := oyun.yp_oy_hakki(pr); end if;
  begin
    execute format('select oyun.%I($1)', 'yp_ck_' || p_islem) into s using p;
    sonra := oyun.yp_gorev_izi();
    if p_user is not null then select * into pr1 from oyun.profiller where id = p_user; oy1 := oyun.yp_oy_hakki(pr1); end if;
    raise exception 'YP_KURU_SON';
  exception when others then
    get stacked diagnostics h = message_text;
    if h <> 'YP_KURU_SON' then return jsonb_build_object('engel', h); end if;
  end;
  return jsonb_build_object('fark', oyun.yp_fark(once, sonra), 'oy_hakki', oyun.yp_oy_hakki_fark(oy0, oy1),
    'parti_once', (select kisa from oyun.partiler where id = pr.parti_id),
    'parti_sonra', (select kisa from oyun.partiler where id = pr1.parti_id));
end $$;

-- Gerçek çalıştırma: aynı çekirdek, önce/sonra izi kaydedilir
create or replace function oyun.yp_gercek(p_islem text, p jsonb, p_user uuid default null)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare once jsonb := oyun.yp_gorev_izi(); sonra jsonb; oy0 jsonb; oy1 jsonb; pr oyun.profiller; pr1 oyun.profiller; f jsonb;
begin
  if p_user is not null then select * into pr from oyun.profiller where id = p_user; oy0 := oyun.yp_oy_hakki(pr); end if;
  execute format('select oyun.%I($1)', 'yp_ck_' || p_islem) using p;
  sonra := oyun.yp_gorev_izi();
  if p_user is not null then select * into pr1 from oyun.profiller where id = p_user; oy1 := oyun.yp_oy_hakki(pr1); end if;
  f := oyun.yp_fark(once, sonra);
  return jsonb_build_object('fark', f, 'oy_hakki', oyun.yp_oy_hakki_fark(oy0, oy1),
    'once', jsonb_build_object('parti_id', pr.parti_id, 'gorevler', f->'biten'),
    'sonra', jsonb_build_object('parti_id', pr1.parti_id, 'gorevler', f->'baslayan'));
end $$;

-- Ortak metin kontrolü
create or replace function oyun.yp_metin(p text, p_en_az int, p_en_cok int)
returns text language sql immutable set search_path to 'oyun', 'public', 'pg_temp' as $$
  select case when char_length(btrim(coalesce(p, ''))) between p_en_az and p_en_cok then btrim(p) end
$$;

-- ---------------------------------------------------------------------
-- 3) İşlem: para ekle / düş (S4)
--    p: hedef + tutar (tam sayı, ±) + aciklama + bildir (varsayılan evet)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_oyuncu_para(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare h oyun.profiller; x numeric; bak numeric; etk jsonb := '[]'::jsonb; har jsonb := '[]'::jsonb; e text; n int; ac text;
begin
  if coalesce(p->>'tutar', '') !~ '^-?\d{1,10}$' then return jsonb_build_object('engel', 'Tutar tam sayı olmalı (ör. 50000 ya da -2000).'); end if;
  x := (p->>'tutar')::numeric;
  if x = 0 then return jsonb_build_object('engel', 'Tutar sıfır olamaz.'); end if;
  if abs(x) > 1000000000 then return jsonb_build_object('engel', 'Tek seferde en fazla 1.000.000.000 ₺.'); end if;
  ac := oyun.yp_metin(p->>'aciklama', 3, 200);
  if ac is null then return jsonb_build_object('engel', 'Açıklama yazmalısın (3-200 karakter). Oyuncunun hesap hareketlerinde görünür.'); end if;
  for h in select * from oyun.yp_hedef_listesi(p) loop
    bak := coalesce((select para from oyun.cuzdan where user_id = h.id), 0);
    if x < 0 and bak + x < 0 then
      har := har || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || jsonb_build_object('neden', format('Bakiyesi yetersiz (%s ₺).', oyun.tl(bak))));
    else
      etk := etk || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || jsonb_build_object('once', bak, 'sonra', bak + x));
    end if;
  end loop;
  n := jsonb_array_length(etk);
  e := oyun.yp_hedef_engel(p, n + jsonb_array_length(har));
  if e is null and n = 0 then e := 'Hiçbir oyuncunun bakiyesi bu tutarı düşmeye yetmiyor.'; end if;
  return jsonb_build_object(
    'ozet', format('%s oyuncunun cüzdanına %s %s ₺ (toplam %s ₺).', n, case when x > 0 then 'eklenecek:' else 'düşülecek:' end,
                   oyun.tl(abs(x)), oyun.tl(abs(x) * n)),
    'hedef_ad', oyun.yp_hedef_ad(p), 'etkilenen', etk, 'haric', har, 'sayi', n, 'engel', e,
    'degisen', jsonb_build_array(jsonb_build_object('alan', 'Cüzdan', 'eski', 'mevcut bakiye', 'yeni', case when x > 0 then '+' else '−' end || oyun.tl(abs(x)) || ' ₺')),
    'uyarilar', (select coalesce(jsonb_agg(u), '[]'::jsonb) from (
        select format('Para arzı %s ₺ %s.', oyun.tl(abs(x) * n), case when x > 0 then 'artacak' else 'azalacak' end) u where n > 1 or abs(x) >= 1000000
        union all select format('%s oyuncu bakiyesi yetersiz olduğu için hariç tutuldu.', jsonb_array_length(har)) where jsonb_array_length(har) > 0
        union all select 'Bakiyeler oyun içi gelirlerle sürekli değişir; uygulamada her oyuncunun o anki bakiyesine eklenir.'::text) z),
    'parmak', md5(x::text || ac || (select coalesce(string_agg(e2->>'user_id', ',' order by e2->>'user_id'), '') from jsonb_array_elements(etk) e2)
                  || '|' || (select coalesce(string_agg(e2->>'user_id', ',' order by e2->>'user_id'), '') from jsonb_array_elements(har) e2)));
end $$;

create or replace function oyun.yp_uy_oyuncu_para(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_oyuncu_para(p); x numeric := (p->>'tutar')::numeric;
        ac text := oyun.yp_metin(p->>'aciklama', 3, 200); e jsonb; u uuid; b0 numeric; b1 numeric; hh bigint;
        ekl jsonb := '[]'::jsonb; ekn jsonb := '[]'::jsonb; ilk_hh bigint; hat text; hk int; hs numeric; ref text := current_setting('yp.islem_id', true);
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  select coalesce(max(id), 0) into ilk_hh from oyun.hesap_hareket;
  for e in select * from jsonb_array_elements(o->'etkilenen') loop
    u := (e->>'user_id')::uuid;
    begin
      perform oyun.cuzdanim(u);
      select para into b0 from oyun.cuzdan where user_id = u for update;
      perform oyun.para_islem(u, x, 'yonetici', 'Oyun yönetimi: ' || ac, t, 0);
      select para into b1 from oyun.cuzdan where user_id = u;
      select max(id) into hh from oyun.hesap_hareket where user_id = u and tur = 'yonetici' and id > ilk_hh;
      if coalesce(p->>'bildir', 'true') <> 'false' then
        perform oyun.bildir(u, format('Oyun yönetimi hesabına %s ₺ %s. Açıklama: %s', oyun.tl(abs(x)), case when x > 0 then 'ekledi' else 'düştü' end, ac), t);
      end if;
      ekl := ekl || jsonb_build_array(e - 'once' - 'sonra' || jsonb_build_object('once', b0, 'sonra', b1, 'hareket_id', hh));
    exception when others then
      get stacked diagnostics hat = message_text;
      ekn := ekn || jsonb_build_array(e - 'once' - 'sonra' || jsonb_build_object('neden', hat));
    end;
  end loop;
  select count(*), coalesce(sum(tutar), 0) into hk, hs from oyun.hesap_hareket
   where id > ilk_hh and tur = 'yonetici' and user_id in (select (z->>'user_id')::uuid from jsonb_array_elements(ekl) z);
  return jsonb_build_object(
    'ozet', format('%s oyuncuya %s %s ₺.%s', jsonb_array_length(ekl), case when x > 0 then '+' else '−' end, oyun.tl(abs(x)),
                   case when jsonb_array_length(ekn) > 0 then format(' %s oyuncuda uygulanamadı.', jsonb_array_length(ekn)) else '' end),
    'hedef', oyun.yp_hedef_ad(p), 'eklenen', ekl, 'eklenemeyen', ekn || coalesce(o->'haric', '[]'::jsonb),
    'once', jsonb_build_object('kayitlar', (select coalesce(jsonb_agg(jsonb_build_object('user_id', z->>'user_id', 'kad', z->>'kad', 'para', z->'once')), '[]'::jsonb) from jsonb_array_elements(ekl) z)),
    'sonra', jsonb_build_object('tutar', x, 'kayitlar', (select coalesce(jsonb_agg(jsonb_build_object('user_id', z->>'user_id', 'kad', z->>'kad', 'para', z->'sonra', 'hareket_id', z->'hareket_id')), '[]'::jsonb) from jsonb_array_elements(ekl) z)),
    'dogrulama', jsonb_build_object(
      'hesap_hareketi', hk, 'hareket_toplami', hs, 'beklenen_toplam', x * jsonb_array_length(ekl),
      'tutarli', hk = jsonb_array_length(ekl) and hs = x * jsonb_array_length(ekl)
                 and not exists (select 1 from jsonb_array_elements(ekl) z where (z->>'sonra')::numeric - (z->>'once')::numeric <> x)));
end $$;

create or replace function oyun.yp_gr_oyuncu_para(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); x numeric := (r.parametre->>'tutar')::numeric; z jsonb; u uuid; bak numeric;
        ok jsonb := '[]'::jsonb; olmaz jsonb := '[]'::jsonb; hat text;
begin
  for z in select * from jsonb_array_elements(coalesce(r.sonra->'kayitlar', '[]'::jsonb)) loop
    u := (z->>'user_id')::uuid;
    bak := coalesce((select para from oyun.cuzdan where user_id = u), 0);
    if x > 0 and bak < x then
      olmaz := olmaz || jsonb_build_array(jsonb_build_object('user_id', u, 'kad', z->>'kad', 'neden', format('Parayı harcamış; bakiyesi %s ₺.', oyun.tl(bak))));
      continue;
    end if;
    if p_uygula then
      begin
        perform oyun.para_islem(u, -x, 'yonetici', 'Oyun yönetimi düzeltmesi (geri alma): ' || coalesce(r.parametre->>'aciklama', ''), t, 0);
        ok := ok || jsonb_build_array(jsonb_build_object('user_id', u, 'kad', z->>'kad'));
      exception when others then
        get stacked diagnostics hat = message_text;
        olmaz := olmaz || jsonb_build_array(jsonb_build_object('user_id', u, 'kad', z->>'kad', 'neden', hat));
      end;
    else
      ok := ok || jsonb_build_array(jsonb_build_object('user_id', u, 'kad', z->>'kad'));
    end if;
  end loop;
  return jsonb_build_object(
    'ozet', format('%s oyuncudan %s %s ₺ geri %s.', jsonb_array_length(ok), case when x > 0 then '−' else '+' end, oyun.tl(abs(x)),
                   case when p_uygula then 'alındı' else 'alınacak' end),
    'sayi', jsonb_array_length(ok), 'eklenen', ok, 'eklenemeyen', olmaz,
    'uyarilar', case when jsonb_array_length(olmaz) > 0 then jsonb_build_array(format('%s oyuncudan geri alınamaz (bakiye yetersiz). Onlar listede ayrıca görünür.', jsonb_array_length(olmaz))) else '[]'::jsonb end,
    'engel', case when jsonb_array_length(ok) = 0 then 'Geri alınabilecek oyuncu kalmadı.' end,
    'once', '{}'::jsonb, 'sonra', jsonb_build_object('geri_alinan', ok));
end $$;

-- ---------------------------------------------------------------------
-- 4) İşlem: kıdem ekle / düş
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_oyuncu_kidem(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare h oyun.profiller; x numeric; k numeric; etk jsonb := '[]'::jsonb; n int;
begin
  if coalesce(p->>'miktar', '') !~ '^-?\d{1,4}(\.\d{1,2})?$' then return jsonb_build_object('engel', 'Miktar sayı olmalı (ör. 5 ya da -2).'); end if;
  x := (p->>'miktar')::numeric;
  if x = 0 then return jsonb_build_object('engel', 'Miktar sıfır olamaz.'); end if;
  if abs(x) > 1000 then return jsonb_build_object('engel', 'Tek seferde en fazla 1000 kıdem puanı.'); end if;
  for h in select * from oyun.yp_hedef_listesi(p) loop
    k := coalesce((select kidem from oyun.cuzdan where user_id = h.id), 0);
    etk := etk || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || jsonb_build_object('once', round(k, 2), 'sonra', round(greatest(0, k + x), 2)));
  end loop;
  n := jsonb_array_length(etk);
  return jsonb_build_object('ozet', format('%s oyuncunun kıdemi %s%s.', n, case when x > 0 then '+' else '' end, x),
    'hedef_ad', oyun.yp_hedef_ad(p), 'etkilenen', etk, 'sayi', n, 'engel', oyun.yp_hedef_engel(p, n),
    'uyarilar', jsonb_build_array('Kıdem sıfırın altına inmez. Kıdem; oy hakkı, unvan ve bazı görev şartlarını etkiler.'),
    'parmak', md5(x::text || (select coalesce(string_agg(e->>'user_id', ',' order by e->>'user_id'), '') from jsonb_array_elements(etk) e)));
end $$;

create or replace function oyun.yp_uy_oyuncu_kidem(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_oyuncu_kidem(p); x numeric := (p->>'miktar')::numeric;
        e jsonb; u uuid; k0 numeric; k1 numeric; ekl jsonb := '[]'::jsonb; ac text := oyun.yp_metin(p->>'aciklama', 1, 200);
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  for e in select * from jsonb_array_elements(o->'etkilenen') loop
    u := (e->>'user_id')::uuid;
    perform oyun.cuzdanim(u);
    select kidem into k0 from oyun.cuzdan where user_id = u for update;
    perform oyun.kidem_ekle(u, x);
    select kidem into k1 from oyun.cuzdan where user_id = u;
    if coalesce(p->>'bildir', 'false') = 'true' then
      perform oyun.bildir(u, format('Oyun yönetimi kıdem puanını %s%s olarak düzenledi.%s', case when x > 0 then '+' else '' end, x, coalesce(' ' || ac, '')), t);
    end if;
    ekl := ekl || jsonb_build_array(e - 'once' - 'sonra' || jsonb_build_object('once', k0, 'sonra', k1, 'fark', k1 - k0));
  end loop;
  return jsonb_build_object('ozet', format('%s oyuncunun kıdemi değişti.', jsonb_array_length(ekl)),
    'hedef', oyun.yp_hedef_ad(p), 'eklenen', ekl,
    'once', jsonb_build_object('kayitlar', (select jsonb_agg(jsonb_build_object('user_id', z->>'user_id', 'kad', z->>'kad', 'kidem', z->'once')) from jsonb_array_elements(ekl) z)),
    'sonra', jsonb_build_object('kayitlar', (select jsonb_agg(jsonb_build_object('user_id', z->>'user_id', 'kad', z->>'kad', 'kidem', z->'sonra', 'fark', z->'fark')) from jsonb_array_elements(ekl) z)),
    'dogrulama', jsonb_build_object('tutarli', not exists (select 1 from jsonb_array_elements(ekl) z
       where (z->>'sonra')::numeric <> greatest(0, (z->>'once')::numeric + x))));
end $$;

create or replace function oyun.yp_gr_oyuncu_kidem(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare z jsonb; n int := 0;
begin
  for z in select * from jsonb_array_elements(coalesce(r.sonra->'kayitlar', '[]'::jsonb)) loop
    n := n + 1;
    if p_uygula then perform oyun.kidem_ekle((z->>'user_id')::uuid, -(z->>'fark')::numeric); end if;
  end loop;
  return jsonb_build_object('ozet', format('%s oyuncunun kıdem değişikliği %s.', n, case when p_uygula then 'geri alındı' else 'geri alınacak' end),
    'sayi', n, 'engel', case when n = 0 then 'Geri alınacak kayıt yok.' end, 'once', '{}'::jsonb, 'sonra', '{}'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5) İşlem: il düzelt / taşı (S6)
--    p: user_id, il_id, mod: duzeltme (varsayılan; seçmen kütüğü beklemesi başlamaz) | tasinma,
--       adaylik: tasi (varsayılan) | iptal, bildir
-- ---------------------------------------------------------------------
create or replace function oyun.yp_il_adaylari(h oyun.profiller, p_il smallint, p_kip text)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); r record; liste jsonb := '[]'::jsonb; yeni_sira int; islem text; neden text;
begin
  for r in select a.*, s.tur, s.donem from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
           where a.user_id = h.id and s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false)
             and t < s.oy_bas and s.tur in ('mv_on', 'mv', 'bel_on', 'bel') and a.il_id is distinct from p_il
           order by s.oy_bas loop
    islem := case when p_kip = 'iptal' then 'iptal' else 'tasi' end; neden := null; yeni_sira := null;
    if islem = 'tasi' and r.tur = 'bel' and r.parti_id is not null and exists (
         select 1 from oyun.adaylar x where x.secim_id = r.secim_id and x.il_id = p_il and x.parti_id = r.parti_id and x.user_id <> h.id) then
      islem := 'iptal'; neden := 'Yeni ilde partinin belediye başkanı adayı zaten var.';
    end if;
    if islem = 'tasi' and r.sira is not null then
      select coalesce(max(x.sira), 0) + 1 into yeni_sira from oyun.adaylar x
       where x.secim_id = r.secim_id and x.il_id = p_il and x.parti_id is not distinct from r.parti_id;
    end if;
    liste := liste || jsonb_build_array(jsonb_build_object('aday_id', r.id, 'secim_id', r.secim_id, 'secim', oyun.yp_tur_ad(r.tur) || ' · ' || r.donem,
      'eski_il', (select ad from oyun.iller where id = r.il_id), 'yeni_il', (select ad from oyun.iller where id = p_il),
      'parti', (select kisa from oyun.partiler where id = r.parti_id), 'eski_sira', r.sira, 'yeni_sira', yeni_sira,
      'islem', islem, 'neden', neden));
  end loop;
  return liste;
end $$;

create or replace function oyun.yp_on_oyuncu_il(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); h oyun.profiller; hn oyun.profiller; il smallint; kip text := coalesce(nullif(p->>'mod', ''), 'duzeltme');
        tes jsonb; ady jsonb; uy jsonb := '[]'::jsonb; oyf jsonb;
begin
  select * into h from oyun.profiller where id = nullif(p->>'user_id', '')::uuid;
  if h.id is null then return jsonb_build_object('engel', 'Oyuncu seçmelisin.'); end if;
  if coalesce(p->>'il_id', '') !~ '^\d+$' or not exists (select 1 from oyun.iller where id = (p->>'il_id')::int) then
    return jsonb_build_object('engel', 'Yeni il seçmelisin.');
  end if;
  il := (p->>'il_id')::smallint;
  if h.il_id = il then return jsonb_build_object('engel', h.kad || ' zaten bu ilde.'); end if;
  if kip not in ('duzeltme', 'tasinma') then return jsonb_build_object('engel', 'Geçersiz kip.'); end if;

  select coalesce(jsonb_agg(jsonb_build_object('parti', pa.kisa, 'il', i.ad, 'parti_id', tg.parti_id, 'il_id', tg.il_id) order by pa.kisa), '[]'::jsonb) into tes
  from oyun.parti_teskilat_gorev tg join oyun.partiler pa on pa.id = tg.parti_id join oyun.iller i on i.id = tg.il_id
  where tg.user_id = h.id and tg.aktif and tg.il_id <> il;
  ady := oyun.yp_il_adaylari(h, il, p->>'adaylik');

  hn := h; hn.il_id := il;
  if kip = 'tasinma' then hn.il_at := t; hn.son_il_degis := t; end if;
  oyf := oyun.yp_oy_hakki_fark(oyun.yp_oy_hakki(h), oyun.yp_oy_hakki(hn));

  if exists (select 1 from oyun.makamlar where user_id = h.id and bit is null and tur in ('mv', 'bel')) then
    uy := uy || to_jsonb(format('%s görevde (%s). İle bağlı görev eski ilinde devam eder; gerekirse Görevden al ile ayrıca sonlandır.', h.kad,
      (select string_agg(oyun.makam_ad(tur, il_id, bakanlik), ', ') from oyun.makamlar where user_id = h.id and bit is null and tur in ('mv', 'bel'))));
  end if;
  if exists (select 1 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id where a.user_id = h.id and s.durum = 'bekliyor'
             and t >= s.oy_bas and t < s.oy_bit and s.tur in ('mv_on', 'mv', 'bel_on', 'bel') and a.il_id is distinct from il) then
    uy := uy || to_jsonb('Oylaması süren bir seçimdeki adaylığı eski ilinde kalır (sandık açıkken taşınamaz).'::text);
  end if;
  if exists (select 1 from oyun.oylar o join oyun.secimler s on s.id = o.secim_id where o.secmen = h.id and s.durum = 'bekliyor' and s.oy_bit > t) then
    uy := uy || to_jsonb('Süren bir seçimde oyunu zaten kullandı; kullanılmış oy değişmez.'::text);
  end if;
  uy := uy || to_jsonb(case when kip = 'duzeltme'
    then 'Düzeltme kipi: kayıt hatası kabul edilir; seçmen kütüğü beklemesi ve il değiştirme bekleme süresi başlamaz, taşınma ücreti alınmaz.'
    else 'Taşınma kipi: oyuncu bugün taşınmış sayılır; seçmen kütüğü beklemesi ve il değiştirme bekleme süresi başlar (ücret alınmaz).' end);

  return jsonb_build_object(
    'ozet', format('%s: %s → %s (%s).', h.kad, (select ad from oyun.iller where id = h.il_id), (select ad from oyun.iller where id = il),
                   case when kip = 'duzeltme' then 'düzeltme' else 'taşınma' end),
    'etkilenen', jsonb_build_array(oyun.yp_oyuncu_kisa(h)), 'sayi', 1,
    'degisen', jsonb_build_array(jsonb_build_object('alan', 'İl', 'eski', (select ad from oyun.iller where id = h.il_id), 'yeni', (select ad from oyun.iller where id = il))),
    'teskilat', tes, 'adayliklar', ady, 'oy_hakki', oyf, 'uyarilar', uy,
    'parmak', md5(concat_ws('|', h.id, h.il_id, il, kip, p->>'adaylik', tes::text, ady::text)));
end $$;

create or replace function oyun.yp_uy_oyuncu_il(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_oyuncu_il(p); h oyun.profiller; h1 oyun.profiller; il smallint := (p->>'il_id')::smallint;
        kip text := coalesce(nullif(p->>'mod', ''), 'duzeltme'); tes jsonb := '[]'::jsonb; ady jsonb := '[]'::jsonb; z jsonb; a oyun.adaylar; tg oyun.parti_teskilat_gorev;
        eski_il text; yeni_il text;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  select * into h from oyun.profiller where id = (p->>'user_id')::uuid for update;
  eski_il := (select ad from oyun.iller where id = h.il_id); yeni_il := (select ad from oyun.iller where id = il);

  for tg in update oyun.parti_teskilat_gorev set aktif = false where user_id = h.id and aktif and il_id <> il returning * loop
    tes := tes || jsonb_build_array(to_jsonb(tg));
  end loop;
  for z in select * from jsonb_array_elements(o->'adayliklar') loop
    select * into a from oyun.adaylar where id = (z->>'aday_id')::bigint;
    if z->>'islem' = 'tasi' then
      update oyun.adaylar set il_id = il, sira = coalesce((z->>'yeni_sira')::int, sira) where id = a.id;
    else
      delete from oyun.adaylar where id = a.id;
    end if;
    ady := ady || jsonb_build_array(jsonb_build_object('islem', z->>'islem', 'kayit', to_jsonb(a)));
  end loop;

  update oyun.profiller set il_id = il,
    il_at = case when kip = 'tasinma' then t else il_at end,
    son_il_degis = case when kip = 'tasinma' then t else son_il_degis end
  where id = h.id returning * into h1;

  if coalesce(p->>'bildir', 'true') <> 'false' then
    perform oyun.bildir(h.id, format('Oyun yönetimi ilini %s olarak %s.%s', yeni_il,
      case when kip = 'duzeltme' then 'düzeltti' else 'değiştirdi' end,
      case when jsonb_array_length(ady) > 0 then ' Bekleyen adaylıkların da güncellendi.' else '' end), t);
  end if;

  return jsonb_build_object('ozet', format('%s: %s → %s.', h.kad, eski_il, yeni_il), 'hedef', h.kad,
    'once', jsonb_build_object('user_id', h.id, 'il_id', h.il_id, 'il_at', h.il_at, 'son_il_degis', h.son_il_degis, 'teskilat', tes, 'adayliklar', ady),
    'sonra', jsonb_build_object('user_id', h.id, 'il_id', h1.il_id, 'il_at', h1.il_at, 'son_il_degis', h1.son_il_degis),
    'adayliklar', o->'adayliklar', 'teskilat', o->'teskilat', 'oy_hakki', o->'oy_hakki',
    'dogrulama', jsonb_build_object(
      'il_dogru', h1.il_id = il,
      'eski_ilde_aktif_teskilat_yok', not exists (select 1 from oyun.parti_teskilat_gorev where user_id = h.id and aktif and il_id <> il),
      'eski_ilde_bekleyen_adaylik_yok', not exists (select 1 from oyun.adaylar x join oyun.secimler s on s.id = x.secim_id
          where x.user_id = h.id and s.durum = 'bekliyor' and t < s.oy_bas and s.tur in ('mv_on', 'mv', 'bel_on', 'bel') and x.il_id is distinct from il),
      'tutarli', h1.il_id = il and not exists (select 1 from oyun.parti_teskilat_gorev where user_id = h.id and aktif and il_id <> il)));
end $$;

create or replace function oyun.yp_gr_oyuncu_il(r oyun.yp_islem, p_uygula boolean)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); h oyun.profiller; z jsonb; a oyun.adaylar; s oyun.secimler; tg oyun.parti_teskilat_gorev;
        notlar jsonb := '[]'::jsonb; n_tes int := 0; n_ady int := 0;
begin
  select * into h from oyun.profiller where id = (r.once->>'user_id')::uuid;
  if h.id is null then return jsonb_build_object('engel', 'Oyuncu bulunamadı.'); end if;
  if h.il_id is distinct from (r.sonra->>'il_id')::smallint then
    return jsonb_build_object('engel', 'Oyuncunun ili bu işlemden sonra yeniden değişmiş; geri alma eski veriyi bozar.');
  end if;
  for z in select * from jsonb_array_elements(coalesce(r.once->'teskilat', '[]'::jsonb)) loop
    tg := jsonb_populate_record(null::oyun.parti_teskilat_gorev, z);
    if exists (select 1 from oyun.parti_teskilat_gorev x where x.parti_id = tg.parti_id and x.il_id = tg.il_id and x.user_id = tg.user_id and not x.aktif)
       and h.parti_id = tg.parti_id then
      n_tes := n_tes + 1;
      if p_uygula then update oyun.parti_teskilat_gorev set aktif = true where parti_id = tg.parti_id and il_id = tg.il_id and user_id = tg.user_id; end if;
    else
      notlar := notlar || to_jsonb(format('%s il başkanlığı geri verilemez (görev başkasına geçmiş ya da parti değişmiş).', (select ad from oyun.iller where id = tg.il_id)));
    end if;
  end loop;
  for z in select * from jsonb_array_elements(coalesce(r.once->'adayliklar', '[]'::jsonb)) loop
    a := jsonb_populate_record(null::oyun.adaylar, z->'kayit');
    select * into s from oyun.secimler where id = a.secim_id;
    if s.id is null or s.durum <> 'bekliyor' or t >= s.oy_bas then
      notlar := notlar || to_jsonb(format('%s adaylığı geri alınamaz: oylama başladı.', oyun.yp_tur_ad(s.tur)));
      continue;
    end if;
    if z->>'islem' = 'tasi' then
      if not exists (select 1 from oyun.adaylar where id = a.id) then
        notlar := notlar || to_jsonb(format('%s adaylığı bu arada geri çekilmiş.', oyun.yp_tur_ad(s.tur))); continue;
      end if;
      n_ady := n_ady + 1;
      if p_uygula then update oyun.adaylar set il_id = a.il_id, sira = a.sira where id = a.id; end if;
    else
      if exists (select 1 from oyun.adaylar where secim_id = a.secim_id and user_id = a.user_id) then continue; end if;
      n_ady := n_ady + 1;
      if p_uygula then insert into oyun.adaylar select a.*; end if;
    end if;
  end loop;
  if p_uygula then
    update oyun.profiller set il_id = (r.once->>'il_id')::smallint, il_at = (r.once->>'il_at')::timestamptz,
      son_il_degis = (r.once->>'son_il_degis')::timestamptz where id = h.id;
    perform oyun.bildir(h.id, format('Oyun yönetimi il değişikliğini geri aldı; ilin yeniden %s.', (select ad from oyun.iller where id = (r.once->>'il_id')::int)), t);
  end if;
  return jsonb_build_object('ozet', format('%s yeniden %s iline dönecek; %s il başkanlığı, %s adaylık eski haline gelecek.', h.kad,
      (select ad from oyun.iller where id = (r.once->>'il_id')::int), n_tes, n_ady),
    'sayi', 1, 'uyarilar', notlar, 'once', r.sonra, 'sonra', r.once);
end $$;

-- ---------------------------------------------------------------------
-- 6) İşlem: parti değiştir (kuru çalıştırma; geri alınamaz)
--    p: user_id, parti_id (boş ya da 0 = bağımsız)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_ck_oyuncu_parti(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
begin
  return public.yk_parti_degistir(oyun.kad((p->>'user_id')::uuid), nullif(nullif(p->>'parti_id', ''), '0')::bigint);
end $$;

create or replace function oyun.yp_on_oyuncu_parti(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare h oyun.profiller; k jsonb; uy jsonb := '[]'::jsonb; yeni text;
begin
  select * into h from oyun.profiller where id = nullif(p->>'user_id', '')::uuid;
  if h.id is null then return jsonb_build_object('engel', 'Oyuncu seçmelisin.'); end if;
  if coalesce(nullif(p->>'parti_id', ''), '0') !~ '^\d+$' then return jsonb_build_object('engel', 'Geçersiz parti.'); end if;
  if coalesce(nullif(p->>'parti_id', ''), '0') = '0' and h.parti_id is null then return jsonb_build_object('engel', h.kad || ' zaten bağımsız.'); end if;
  yeni := coalesce((select kisa from oyun.partiler where id = nullif(nullif(p->>'parti_id', ''), '0')::bigint), 'bağımsız');
  k := oyun.yp_kuru('oyuncu_parti', p, h.id);
  if k->>'engel' is not null then return jsonb_build_object('engel', k->>'engel'); end if;
  if exists (select 1 from oyun.makamlar where user_id = h.id and bit is null) then
    uy := uy || to_jsonb('Seçimle gelen görevleri (vekil, belediye başkanı vb.) eski partisi adına kayıtlı kalır.'::text);
  end if;
  uy := uy || to_jsonb('Partiye katılım tarihi bugün olur: yakın parti içi seçimlerde oy hakkı oyunun üyelik kuralına göre değişebilir (aşağıda gösterilir).'::text);
  uy := uy || to_jsonb('Bu işlem geri alınamaz: kaybedilen görevler ve iptal edilen adaylıklar otomatik geri gelmez.'::text);
  return jsonb_build_object(
    'ozet', format('%s: %s → %s.', h.kad, coalesce((select kisa from oyun.partiler where id = h.parti_id), 'bağımsız'), yeni),
    'etkilenen', jsonb_build_array(oyun.yp_oyuncu_kisa(h)), 'sayi', 1,
    'degisen', jsonb_build_array(jsonb_build_object('alan', 'Parti', 'eski', coalesce(k->>'parti_once', 'bağımsız'), 'yeni', coalesce(k->>'parti_sonra', 'bağımsız'))),
    'biten', k->'fark'->'biten', 'baslayan', k->'fark'->'baslayan', 'oy_hakki', k->'oy_hakki', 'uyarilar', uy,
    'parmak', md5(concat_ws('|', h.id, h.parti_id, p->>'parti_id', (k->'fark')::text)));
end $$;

create or replace function oyun.yp_uy_oyuncu_parti(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare h oyun.profiller; g jsonb; o jsonb;
begin
  select * into h from oyun.profiller where id = (p->>'user_id')::uuid for update;
  o := oyun.yp_on_oyuncu_parti(p);
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  g := oyun.yp_gercek('oyuncu_parti', p, h.id);
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', h.kad, 'biten', g->'fark'->'biten', 'baslayan', g->'fark'->'baslayan',
    'oy_hakki', g->'oy_hakki', 'once', g->'once', 'sonra', g->'sonra',
    'dogrulama', jsonb_build_object('tutarli', (select parti_id from oyun.profiller where id = h.id) is not distinct from nullif(nullif(p->>'parti_id', ''), '0')::bigint));
end $$;

-- ---------------------------------------------------------------------
-- 7) İşlem: görev ver (kuru çalıştırma; geri alınamaz)
--    p: user_id, tur (cb|cb_yardimcisi|bakan|mv|bel|tbmm|bskv|grup_bskv|gb|gby), il_id, bakanlik, sira, tek_gorev (varsayılan evet)
-- ---------------------------------------------------------------------
create or replace function oyun.yp_ck_makam_ver(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
begin
  return public.yk_makam_ver(oyun.kad((p->>'user_id')::uuid), p->>'tur', nullif(p->>'il_id', '')::int,
    nullif(p->>'bakanlik', ''), nullif(p->>'sira', '')::int, coalesce(p->>'tek_gorev', 'true') <> 'false');
end $$;

create or replace function oyun.yp_on_makam_ver(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare h oyun.profiller; k jsonb; ad text;
begin
  select * into h from oyun.profiller where id = nullif(p->>'user_id', '')::uuid;
  if h.id is null then return jsonb_build_object('engel', 'Oyuncu seçmelisin.'); end if;
  if nullif(p->>'il_id', '') is not null and p->>'il_id' !~ '^\d+$' then return jsonb_build_object('engel', 'Geçersiz il.'); end if;
  if nullif(p->>'sira', '') is not null and p->>'sira' !~ '^\d+$' then return jsonb_build_object('engel', 'Geçersiz sıra.'); end if;
  k := oyun.yp_kuru('makam_ver', p, h.id);
  if k->>'engel' is not null then return jsonb_build_object('engel', k->>'engel'); end if;
  select string_agg(x->>'ad', ', ') into ad from jsonb_array_elements(k->'fark'->'baslayan') x where x->>'user_id' = h.id::text;
  return jsonb_build_object('ozet', format('%s → %s', h.kad, coalesce(ad, p->>'tur')),
    'etkilenen', jsonb_build_array(oyun.yp_oyuncu_kisa(h)), 'sayi', 1,
    'biten', k->'fark'->'biten', 'baslayan', k->'fark'->'baslayan', 'oy_hakki', k->'oy_hakki',
    'uyarilar', jsonb_build_array(
      'Görevden düşecek kişiler (koltuğun önceki sahibi ve oyuncunun uyumsuz görevleri) yukarıda "Bitecek" listesinde.',
      'Bu işlem geri alınamaz; gerekirse Görevden al / Görev ver ile elle düzeltilir.'),
    'parmak', md5(concat_ws('|', h.id, p::text, (k->'fark')::text)));
end $$;

create or replace function oyun.yp_uy_makam_ver(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_makam_ver(p); g jsonb;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  g := oyun.yp_gercek('makam_ver', p, (p->>'user_id')::uuid);
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', oyun.kad((p->>'user_id')::uuid),
    'biten', g->'fark'->'biten', 'baslayan', g->'fark'->'baslayan', 'oy_hakki', g->'oy_hakki', 'once', g->'once', 'sonra', g->'sonra',
    'dogrulama', jsonb_build_object('tutarli', jsonb_array_length(g->'fark'->'baslayan') > 0));
end $$;

-- ---------------------------------------------------------------------
-- 8) İşlem: görevden al (kuru çalıştırma; geri alınamaz)
--    p: makam_id  ya da  user_id + parti_gorev (gb | gby | teskilat), neden
-- ---------------------------------------------------------------------
create or replace function oyun.yp_ck_makam_al(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); u uuid := nullif(p->>'user_id', '')::uuid; neden text := oyun.yp_metin(p->>'neden', 1, 200); n int;
begin
  if nullif(p->>'makam_id', '') is not null then
    return public.yk_makam_al((p->>'makam_id')::bigint, neden);
  end if;
  if u is null then raise exception 'Görev seçmelisin.'; end if;
  if p->>'parti_gorev' = 'gb' then
    update oyun.partiler set gb = null where gb = u; get diagnostics n = row_count;
  elsif p->>'parti_gorev' = 'gby' then
    delete from oyun.parti_gby where user_id = u; get diagnostics n = row_count;
  elsif p->>'parti_gorev' = 'teskilat' then
    update oyun.parti_teskilat_gorev set aktif = false where user_id = u and aktif
      and (nullif(p->>'il_id', '') is null or il_id = (p->>'il_id')::smallint);
    get diagnostics n = row_count;
  else raise exception 'Görev seçmelisin.'; end if;
  if n = 0 then raise exception 'Oyuncunun bu görevi yok.'; end if;
  perform oyun.bildir(u, format('Oyun yönetimi kararıyla %s görevin sona erdi.%s',
    case p->>'parti_gorev' when 'gb' then 'genel başkanlık' when 'gby' then 'genel başkan yardımcılığı' else 'il başkanlığı' end,
    coalesce(' Gerekçe: ' || neden, '')), t);
  return '{}'::jsonb;
end $$;

create or replace function oyun.yp_on_makam_al(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare k jsonb; u uuid; m oyun.makamlar;
begin
  if nullif(p->>'makam_id', '') is not null then
    if p->>'makam_id' !~ '^\d+$' then return jsonb_build_object('engel', 'Geçersiz görev.'); end if;
    select * into m from oyun.makamlar where id = (p->>'makam_id')::bigint;
    if m.id is null or m.bit is not null then return jsonb_build_object('engel', 'Görev bulunamadı ya da zaten sona ermiş.'); end if;
    u := m.user_id;
  else
    u := nullif(p->>'user_id', '')::uuid;
  end if;
  if u is null then return jsonb_build_object('engel', 'Görev seçmelisin.'); end if;
  k := oyun.yp_kuru('makam_al', p, u);
  if k->>'engel' is not null then return jsonb_build_object('engel', k->>'engel'); end if;
  return jsonb_build_object('ozet', format('%s görevden alınacak: %s', oyun.kad(u),
      coalesce((select string_agg(x->>'ad', ', ') from jsonb_array_elements(k->'fark'->'biten') x where x->>'user_id' = u::text), '—')),
    'etkilenen', jsonb_build_array(jsonb_build_object('user_id', u, 'kad', oyun.kad(u))), 'sayi', 1,
    'biten', k->'fark'->'biten', 'baslayan', k->'fark'->'baslayan', 'oy_hakki', k->'oy_hakki',
    'uyarilar', jsonb_build_array(
      'Milletvekilliği biterse sıradaki yedek aday otomatik göreve gelir ("Başlayacak" listesinde).',
      'Bu işlem geri alınamaz.'),
    'parmak', md5(concat_ws('|', u, p::text, (k->'fark')::text)));
end $$;

create or replace function oyun.yp_uy_makam_al(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare o jsonb := oyun.yp_on_makam_al(p); u uuid := ((o->'etkilenen'->0)->>'user_id')::uuid; g jsonb;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  g := oyun.yp_gercek('makam_al', p, u);
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', oyun.kad(u),
    'biten', g->'fark'->'biten', 'baslayan', g->'fark'->'baslayan', 'once', g->'once', 'sonra', g->'sonra',
    'dogrulama', jsonb_build_object('tutarli', jsonb_array_length(g->'fark'->'biten') > 0));
end $$;

-- ---------------------------------------------------------------------
-- 9) İşlem: hesap engelle / engel kaldır / sustur
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_hesap_engelle(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); h oyun.profiller; etk jsonb := '[]'::jsonb; har jsonb := '[]'::jsonb; gun numeric; bitis timestamptz; neden text; n int; ady int;
begin
  if nullif(p->>'gun', '') is not null and p->>'gun' !~ '^\d{1,4}$' then return jsonb_build_object('engel', 'Gün sayısı tam sayı olmalı (0 = kalıcı).'); end if;
  gun := coalesce(nullif(p->>'gun', '')::numeric, 0);
  if gun > 3650 then return jsonb_build_object('engel', 'En fazla 3650 gün.'); end if;
  if gun > 0 then bitis := t + make_interval(days => gun::int); end if;
  neden := oyun.yp_metin(p->>'neden', 3, 200);
  if neden is null then return jsonb_build_object('engel', 'Gerekçe yazmalısın (3-200 karakter); oyuncuya gösterilir.'); end if;
  for h in select * from oyun.yp_hedef_listesi(p) loop
    if coalesce(h.yonetici, false) then har := har || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || '{"neden":"Yönetici hesabı engellenemez."}'::jsonb);
    elsif h.yasakli then har := har || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || '{"neden":"Zaten engelli."}'::jsonb);
    else etk := etk || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || jsonb_build_object(
      'gorev', (select string_agg(oyun.makam_ad(tur, il_id, bakanlik), ', ') from oyun.makamlar where user_id = h.id and bit is null)));
    end if;
  end loop;
  n := jsonb_array_length(etk);
  select count(*) into ady from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
   where s.durum = 'bekliyor' and s.oy_bit > t and a.user_id in (select (e->>'user_id')::uuid from jsonb_array_elements(etk) e);
  return jsonb_build_object(
    'ozet', format('%s hesap %s engellenecek.', n, case when bitis is null then 'kalıcı olarak' else to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI') || ' tarihine kadar' end),
    'hedef_ad', oyun.yp_hedef_ad(p), 'etkilenen', etk, 'haric', har, 'sayi', n,
    'engel', coalesce(oyun.yp_hedef_engel(p, n + jsonb_array_length(har)), case when n = 0 then 'Engellenecek hesap yok.' end),
    'uyarilar', (select jsonb_agg(u) from (
      select 'Engelli oyuncu oyuna giremez, oy kullanamaz. Görevleri, parası ve verileri silinmez.'::text u
      union all select format('%s bekleyen/süren adaylık var; adaylıklar pusulada kalır.', ady) where ady > 0
      union all select 'Görevi olan oyuncular var; görevleri sürer (gerekirse ayrıca Görevden al).' where exists (select 1 from jsonb_array_elements(etk) e where e->>'gorev' is not null)) z),
    'parmak', md5(concat_ws('|', gun, neden, (select string_agg(e->>'user_id', ',' order by e->>'user_id') from jsonb_array_elements(etk) e))));
end $$;

create or replace function oyun.yp_uy_hesap_engelle(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_hesap_engelle(p); e jsonb; h oyun.profiller; gun numeric := coalesce(nullif(p->>'gun', '')::numeric, 0);
        bitis timestamptz; neden text := oyun.yp_metin(p->>'neden', 3, 200); onc jsonb := '[]'::jsonb; snr jsonb := '[]'::jsonb;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  if gun > 0 then bitis := t + make_interval(days => gun::int); end if;
  for e in select * from jsonb_array_elements(o->'etkilenen') loop
    select * into h from oyun.profiller where id = (e->>'user_id')::uuid for update;
    onc := onc || jsonb_build_array(jsonb_build_object('user_id', h.id, 'kad', h.kad, 'yasakli', h.yasakli, 'engel_bitis', h.engel_bitis, 'engel_neden', h.engel_neden));
    update oyun.profiller set yasakli = true, engel_bitis = bitis, engel_neden = neden where id = h.id;
    perform oyun.bildir(h.id, case when bitis is null then 'Hesabın oyun yönetimi tarafından engellendi.'
      else format('Hesabın %s tarihine kadar engellendi.', to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')) end || ' Gerekçe: ' || neden, t);
    snr := snr || jsonb_build_array(jsonb_build_object('user_id', h.id, 'kad', h.kad, 'yasakli', true, 'engel_bitis', bitis, 'engel_neden', neden));
  end loop;
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', oyun.yp_hedef_ad(p), 'eklenen', snr, 'eklenemeyen', o->'haric',
    'once', jsonb_build_object('kayitlar', onc), 'sonra', jsonb_build_object('kayitlar', snr),
    'dogrulama', jsonb_build_object('tutarli', not exists (select 1 from jsonb_array_elements(snr) z join oyun.profiller x on x.id = (z->>'user_id')::uuid where not x.yasakli)));
end $$;

-- Engel / susturma alanlarını önceki haline döndürür (yalnız işlemden sonra değişmemişse)
create or replace function oyun.yp_gr_profil_alanlari(r oyun.yp_islem, p_uygula boolean, p_alanlar text[], p_ad text)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); z jsonb; s jsonb; cur jsonb; n int := 0; atla jsonb := '[]'::jsonb; a text; ayni boolean;
begin
  for z in select * from jsonb_array_elements(coalesce(r.once->'kayitlar', '[]'::jsonb)) loop
    select x into s from jsonb_array_elements(r.sonra->'kayitlar') x where x->>'user_id' = z->>'user_id';
    select to_jsonb(pr) into cur from oyun.profiller pr where pr.id = (z->>'user_id')::uuid;
    ayni := cur is not null;
    foreach a in array p_alanlar loop
      if a in ('engel_bitis', 'susturma_bitis') then
        if (cur->>a)::timestamptz is distinct from (s->>a)::timestamptz then ayni := false; end if;
      elsif (cur->>a) is distinct from (s->>a) then
        ayni := false;
      end if;
    end loop;
    if not ayni then atla := atla || jsonb_build_array(jsonb_build_object('kad', z->>'kad', 'neden', 'Bu işlemden sonra yeniden değişmiş.')); continue; end if;
    n := n + 1;
    if p_uygula then
      update oyun.profiller pr set
        yasakli = case when 'yasakli' = any(p_alanlar) then (z->>'yasakli')::boolean else pr.yasakli end,
        engel_bitis = case when 'engel_bitis' = any(p_alanlar) then (z->>'engel_bitis')::timestamptz else pr.engel_bitis end,
        engel_neden = case when 'engel_neden' = any(p_alanlar) then z->>'engel_neden' else pr.engel_neden end,
        susturma_bitis = case when 'susturma_bitis' = any(p_alanlar) then (z->>'susturma_bitis')::timestamptz else pr.susturma_bitis end
      where pr.id = (z->>'user_id')::uuid;
      perform oyun.bildir((z->>'user_id')::uuid, 'Oyun yönetimi önceki ' || p_ad || ' işlemini geri aldı.', t);
    end if;
  end loop;
  return jsonb_build_object('ozet', format('%s oyuncuda %s eski haline %s.', n, p_ad, case when p_uygula then 'döndü' else 'dönecek' end),
    'sayi', n, 'eklenemeyen', atla,
    'uyarilar', case when jsonb_array_length(atla) > 0 then jsonb_build_array(format('%s oyuncu bu arada yeniden değiştiği için atlanacak.', jsonb_array_length(atla))) else '[]'::jsonb end,
    'engel', case when n = 0 then 'Geri alınabilecek oyuncu kalmadı.' end, 'once', r.sonra, 'sonra', r.once);
end $$;

create or replace function oyun.yp_gr_hesap_engelle(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$
  select oyun.yp_gr_profil_alanlari(r, p_uygula, array['yasakli', 'engel_bitis', 'engel_neden'], 'hesap engeli')
$$;

create or replace function oyun.yp_on_engel_kaldir(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare h oyun.profiller; etk jsonb := '[]'::jsonb; har jsonb := '[]'::jsonb; n int;
begin
  for h in select * from oyun.yp_hedef_listesi(case when jsonb_typeof(p->'filtre') = 'object' then jsonb_set(p, '{filtre,durum}', '"engelli"') else p end) loop
    if not h.yasakli then har := har || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || '{"neden":"Engelli değil."}'::jsonb);
    else etk := etk || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || jsonb_build_object('engel_bitis', h.engel_bitis, 'engel_neden', h.engel_neden)); end if;
  end loop;
  n := jsonb_array_length(etk);
  return jsonb_build_object('ozet', format('%s hesabın engeli kaldırılacak.', n), 'hedef_ad', oyun.yp_hedef_ad(p),
    'etkilenen', etk, 'haric', har, 'sayi', n,
    'engel', coalesce(oyun.yp_hedef_engel(p, n + jsonb_array_length(har)), case when n = 0 then 'Seçilenler arasında engelli hesap yok.' end),
    'parmak', md5(coalesce((select string_agg(e->>'user_id', ',' order by e->>'user_id') from jsonb_array_elements(etk) e), '')));
end $$;

create or replace function oyun.yp_uy_engel_kaldir(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_engel_kaldir(p); e jsonb; h oyun.profiller; onc jsonb := '[]'::jsonb; snr jsonb := '[]'::jsonb;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  for e in select * from jsonb_array_elements(o->'etkilenen') loop
    select * into h from oyun.profiller where id = (e->>'user_id')::uuid for update;
    onc := onc || jsonb_build_array(jsonb_build_object('user_id', h.id, 'kad', h.kad, 'yasakli', h.yasakli, 'engel_bitis', h.engel_bitis, 'engel_neden', h.engel_neden));
    update oyun.profiller set yasakli = false, engel_bitis = null, engel_neden = null where id = h.id;
    perform oyun.bildir(h.id, 'Hesabındaki engel oyun yönetimi tarafından kaldırıldı. Tekrar hoş geldin!', t);
    snr := snr || jsonb_build_array(jsonb_build_object('user_id', h.id, 'kad', h.kad, 'yasakli', false, 'engel_bitis', null, 'engel_neden', null));
  end loop;
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', oyun.yp_hedef_ad(p), 'eklenen', snr, 'eklenemeyen', o->'haric',
    'once', jsonb_build_object('kayitlar', onc), 'sonra', jsonb_build_object('kayitlar', snr),
    'dogrulama', jsonb_build_object('tutarli', not exists (select 1 from jsonb_array_elements(snr) z join oyun.profiller x on x.id = (z->>'user_id')::uuid where x.yasakli)));
end $$;

create or replace function oyun.yp_gr_engel_kaldir(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$
  select oyun.yp_gr_profil_alanlari(r, p_uygula, array['yasakli', 'engel_bitis', 'engel_neden'], 'engel kaldırma')
$$;

create or replace function oyun.yp_on_sustur(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); h oyun.profiller; etk jsonb := '[]'::jsonb; har jsonb := '[]'::jsonb; saat numeric; bitis timestamptz; n int;
begin
  if coalesce(p->>'saat', '') !~ '^\d{1,5}(\.\d+)?$' then return jsonb_build_object('engel', 'Saat sayısı yazmalısın (0 = susturmayı kaldır).'); end if;
  saat := (p->>'saat')::numeric;
  if saat > 87600 then return jsonb_build_object('engel', 'Süre çok uzun (en fazla 87600 saat).'); end if;
  if saat > 0 then bitis := t + make_interval(secs => (saat * 3600)::double precision); end if;
  if saat > 0 and oyun.yp_metin(p->>'neden', 3, 200) is null then return jsonb_build_object('engel', 'Gerekçe yazmalısın (3-200 karakter).'); end if;
  for h in select * from oyun.yp_hedef_listesi(p) loop
    if coalesce(h.yonetici, false) then har := har || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || '{"neden":"Yönetici hesabı."}'::jsonb);
    elsif saat = 0 and not coalesce(h.susturma_bitis > t, false) then har := har || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || '{"neden":"Susturulmuş değil."}'::jsonb);
    else etk := etk || jsonb_build_array(oyun.yp_oyuncu_kisa(h) || jsonb_build_object('once', case when h.susturma_bitis > t then h.susturma_bitis end, 'sonra', bitis)); end if;
  end loop;
  n := jsonb_array_length(etk);
  return jsonb_build_object('ozet', case when bitis is null then format('%s oyuncunun susturması kaldırılacak.', n)
      else format('%s oyuncu %s tarihine kadar sohbette susturulacak.', n, to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')) end,
    'hedef_ad', oyun.yp_hedef_ad(p), 'etkilenen', etk, 'haric', har, 'sayi', n,
    'engel', coalesce(oyun.yp_hedef_engel(p, n + jsonb_array_length(har)), case when n = 0 then 'Uygulanacak oyuncu yok.' end),
    'parmak', md5(concat_ws('|', saat, (select string_agg(e->>'user_id', ',' order by e->>'user_id') from jsonb_array_elements(etk) e))));
end $$;

create or replace function oyun.yp_uy_sustur(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_sustur(p); e jsonb; h oyun.profiller; saat numeric := (p->>'saat')::numeric; bitis timestamptz;
        neden text := oyun.yp_metin(p->>'neden', 3, 200); onc jsonb := '[]'::jsonb; snr jsonb := '[]'::jsonb;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  if saat > 0 then bitis := t + make_interval(secs => (saat * 3600)::double precision); end if;
  for e in select * from jsonb_array_elements(o->'etkilenen') loop
    select * into h from oyun.profiller where id = (e->>'user_id')::uuid for update;
    onc := onc || jsonb_build_array(jsonb_build_object('user_id', h.id, 'kad', h.kad, 'susturma_bitis', h.susturma_bitis));
    update oyun.profiller set susturma_bitis = bitis where id = h.id;
    perform oyun.bildir(h.id, case when bitis is null then 'Sohbet susturman kaldırıldı.'
      else format('Oyun yönetimi seni %s tarihine kadar sohbette susturdu.%s', to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), coalesce(' Gerekçe: ' || neden, '')) end, t);
    snr := snr || jsonb_build_array(jsonb_build_object('user_id', h.id, 'kad', h.kad, 'susturma_bitis', bitis));
  end loop;
  return jsonb_build_object('ozet', o->>'ozet', 'hedef', oyun.yp_hedef_ad(p), 'eklenen', snr, 'eklenemeyen', o->'haric',
    'once', jsonb_build_object('kayitlar', onc), 'sonra', jsonb_build_object('kayitlar', snr),
    'dogrulama', jsonb_build_object('tutarli', true));
end $$;

create or replace function oyun.yp_gr_sustur(r oyun.yp_islem, p_uygula boolean)
returns jsonb language sql set search_path to 'oyun', 'public', 'pg_temp' as $$
  select oyun.yp_gr_profil_alanlari(r, p_uygula, array['susturma_bitis'], 'susturma')
$$;

-- ---------------------------------------------------------------------
-- 10) İşlem: bildirim gönder
-- ---------------------------------------------------------------------
create or replace function oyun.yp_on_oyuncu_bildirim(p jsonb)
returns jsonb language plpgsql stable set search_path to 'oyun', 'public', 'pg_temp' as $$
declare h oyun.profiller; etk jsonb := '[]'::jsonb; m text := oyun.yp_metin(p->>'metin', 3, 500); n int;
begin
  if m is null then return jsonb_build_object('engel', 'Bildirim metni 3-500 karakter olmalı.'); end if;
  for h in select * from oyun.yp_hedef_listesi(p) loop
    if not h.yasakli then etk := etk || jsonb_build_array(oyun.yp_oyuncu_kisa(h)); end if;
  end loop;
  n := jsonb_array_length(etk);
  return jsonb_build_object('ozet', format('%s oyuncuya bildirim gidecek.', n), 'hedef_ad', oyun.yp_hedef_ad(p),
    'etkilenen', etk, 'sayi', n, 'engel', oyun.yp_hedef_engel(p, n),
    'degisen', jsonb_build_array(jsonb_build_object('alan', 'Bildirim', 'eski', '', 'yeni', 'Oyun yönetimi: ' || m)),
    'uyarilar', jsonb_build_array('Bildirim oyun içinde görünür. Telefon anlık bildirimi (push) bu aşamada gönderilmez.', 'Gönderilen bildirim geri alınamaz.'),
    'parmak', md5(m || coalesce((select string_agg(e->>'user_id', ',' order by e->>'user_id') from jsonb_array_elements(etk) e), '')));
end $$;

create or replace function oyun.yp_uy_oyuncu_bildirim(p jsonb)
returns jsonb language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $$
declare t timestamptz := oyun.simdi(); o jsonb := oyun.yp_on_oyuncu_bildirim(p); e jsonb; m text := oyun.yp_metin(p->>'metin', 3, 500); n int := 0;
begin
  if o->>'engel' is not null then raise exception '%', o->>'engel'; end if;
  for e in select * from jsonb_array_elements(o->'etkilenen') loop
    perform oyun.bildir((e->>'user_id')::uuid, 'Oyun yönetimi: ' || m, t); n := n + 1;
  end loop;
  return jsonb_build_object('ozet', format('%s oyuncuya bildirim gönderildi.', n), 'hedef', oyun.yp_hedef_ad(p),
    'eklenen', o->'etkilenen', 'once', '{}'::jsonb, 'sonra', jsonb_build_object('metin', m, 'kisi', n),
    'dogrulama', jsonb_build_object('tutarli', n = jsonb_array_length(o->'etkilenen')));
end $$;

-- ---------------------------------------------------------------------
-- 11) Ön izleme: aynı işlem aynı değerlerle son 24 saatte uygulandıysa uyar (164'teki sürümün yerine)
-- ---------------------------------------------------------------------
create or replace function public.yp_onizle(p_islem text, p_param jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); k oyun.yp_katalog; o jsonb; r oyun.yp_islem; pm text; onceki oyun.yp_islem;
begin
  select * into k from oyun.yp_katalog where islem = p_islem;
  if k.islem is null then raise exception 'Tanımsız işlem: %', p_islem; end if;
  execute format('select oyun.%I($1)', 'yp_on_' || k.islem) into o using coalesce(p_param, '{}'::jsonb);
  pm := coalesce(o->>'parmak', md5(o::text));
  select * into onceki from oyun.yp_islem x where x.islem = k.islem and x.parametre = coalesce(p_param, '{}'::jsonb)
    and x.durum = 'uygulandi' and x.uygulama > now() - interval '24 hours' order by x.id desc limit 1;
  if onceki.id is not null and o->>'engel' is null then
    o := jsonb_set(o, '{uyarilar}', coalesce(o->'uyarilar', '[]'::jsonb) || to_jsonb(format(
      'Dikkat: aynı işlem aynı değerlerle %s tarihinde zaten uygulandı (#%s). Mükerrer olmadığından emin ol.',
      to_char(onceki.uygulama at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), onceki.id)));
    o := o || jsonb_build_object('mukerrer', onceki.id);
  end if;
  insert into oyun.yp_islem (islem, parametre, user_id, kad, gecerlilik, onizleme, parmak)
  values (k.islem, coalesce(p_param, '{}'::jsonb), p.id, p.kad, now() + interval '15 minutes', o, pm)
  returning * into r;
  return o || jsonb_build_object('anahtar', r.anahtar, 'islem_id', r.id, 'gecerlilik', r.gecerlilik,
    'baslik', k.baslik, 'kritik', k.kritik, 'onay_metni', k.onay_metni, 'geri_alinabilir', k.geri_alinabilir);
end $$;

-- ---------------------------------------------------------------------
-- 12) Okuma: oyuncu listesi, oyuncu dosyası, sözlük
-- ---------------------------------------------------------------------
create or replace function public.yp_oyuncular(p_filtre jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0, p_sira text default 'kad')
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); f jsonb := coalesce(p_filtre, '{}'::jsonb);
begin
  if coalesce(f->>'durum', '') = '' then f := f || '{"durum":"tum"}'::jsonb; end if;
  -- yonetici_haric: toplu işlem merkezindeki sayım, işlemlerin kendisi gibi yöneticiyi saymasın
  return (with x as (
    select pr.*, coalesce(c.para, 0) para, coalesce(c.kidem, 0) kidem
    from oyun.yp_filtre(f, coalesce(f->>'yonetici_haric', 'false') <> 'true') pr left join oyun.cuzdan c on c.user_id = pr.id
  )
  select jsonb_build_object(
    'toplam', (select count(*) from x),
    'filtre_ad', oyun.yp_hedef_ad(jsonb_build_object('filtre', f)),
    'kayitlar', coalesce((select jsonb_agg(jsonb_build_object(
        'user_id', y.id, 'kad', y.kad, 'il', i.ad, 'il_id', y.il_id, 'parti', pa.kisa, 'parti_id', y.parti_id, 'renk', pa.renk,
        'para', y.para, 'kidem', round(y.kidem, 1), 'yasakli', y.yasakli, 'yonetici', coalesce(y.yonetici, false),
        'susturma_bitis', case when y.susturma_bitis > t then y.susturma_bitis end,
        'son_gorulme', y.son_gorulme, 'olusturma', y.olusturma,
        'cevrimici', y.son_gorulme > t - interval '15 minutes',
        'gorevler', (select string_agg(oyun.makam_ad(m.tur, m.il_id, m.bakanlik), ', ' order by m.bas) from oyun.makamlar m where m.user_id = y.id and m.bit is null))
        order by y.o)
      from (select x.*, row_number() over (order by
              case when p_sira = 'para' then -x.para when p_sira = 'kidem' then -x.kidem end nulls last,
              case when p_sira = 'son_gorulme' then x.son_gorulme when p_sira = 'olusturma' then x.olusturma end desc nulls last,
              lower(x.kad)) o
            from x order by o limit least(coalesce(p_limit, 50), 500) offset greatest(coalesce(p_offset, 0), 0)) y
      left join oyun.iller i on i.id = y.il_id left join oyun.partiler pa on pa.id = y.parti_id), '[]'::jsonb),
    'tum_idler', case when (select count(*) from x) <= 2000 then (select jsonb_agg(x.id) from x) end));
end $$;

create or replace function public.yp_oyuncu(p_user uuid)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip(); t timestamptz := oyun.simdi(); h oyun.profiller; j jsonb;
begin
  select * into h from oyun.profiller where id = p_user;
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  j := public.yk_oyuncu(h.id::text);
  return j || jsonb_build_object(
    'il_at', h.il_at, 'son_il_degis', h.son_il_degis, 'parti_at', h.parti_at,
    'cevrimici', h.son_gorulme > t - interval '15 minutes',
    'parti_gorevleri', jsonb_build_object(
      'gb', exists (select 1 from oyun.partiler where gb = h.id and not coalesce(kapali, false)),
      'gby', (select sira from oyun.parti_gby where user_id = h.id),
      'teskilat', coalesce((select jsonb_agg(jsonb_build_object('il_id', tg.il_id, 'il', i.ad, 'parti', pa.kisa, 'atama', tg.atama))
          from oyun.parti_teskilat_gorev tg join oyun.iller i on i.id = tg.il_id join oyun.partiler pa on pa.id = tg.parti_id
          where tg.user_id = h.id and tg.aktif), '[]'::jsonb)),
    'sirketler', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'aktif', s.aktif, 'kasa', s.kasa,
          'kurucu', s.kurucu = h.id, 'yonetici', s.yonetici = h.id, 'pay', o.pay) order by s.kasa desc nulls last)
        from oyun.sirketler s left join oyun.sirket_ortaklari o on o.sirket_id = s.id and o.user_id = h.id
        where s.kurucu = h.id or s.yonetici = h.id or o.user_id = h.id), '[]'::jsonb),
    'mulk', (select jsonb_build_object('adet', count(*), 'bedel', coalesce(sum(bedel), 0), 'gunluk', coalesce(sum(gunluk), 0),
          'liste', coalesce(jsonb_agg(jsonb_build_object('tur', m.tur, 'il', i.ad, 'bedel', m.bedel, 'gunluk', m.gunluk, 'alis', m.alis) order by m.bedel desc), '[]'::jsonb))
        from oyun.mulkler m left join oyun.iller i on i.id = m.il_id where m.user_id = h.id),
    'krediler', coalesce((select jsonb_agg(jsonb_build_object('kaynak', 'Merkez', 'anapara', k.anapara, 'kalan', k.kalan, 'gecikmis', k.gecikmis, 'acilis', k.acilis))
        from oyun.krediler k where k.user_id = h.id and k.durum = 'aktif'), '[]'::jsonb)
      || coalesce((select jsonb_agg(jsonb_build_object('kaynak', coalesce(s.ad, 'Banka'), 'anapara', k.anapara, 'kalan', k.kalan, 'vade', k.vade, 'acilis', k.acilis))
        from oyun.oyb_kredi k left join oyun.sirketler s on s.id = k.banka_id where k.borclu = h.id and k.durum = 'aktif'), '[]'::jsonb),
    'mevduat', (select jsonb_build_object('adet', count(*), 'anapara', coalesce(sum(anapara), 0))
        from oyun.banka_mevduat where user_id = h.id and not coalesce(kapandi, false) and not coalesce(iptal, false)),
    'davalar', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'tur', d.tur, 'durum', d.durum, 'karar', d.karar, 'acilis', d.acilis,
          'ceza_bitis', d.ceza_bitis, 'rol', case when d.davaci = h.id then 'davacı' else 'davalı' end,
          'karsi', oyun.kad(case when d.davaci = h.id then d.davali else d.davaci end)) order by d.id desc)
        from (select * from oyun.adliye_davalar where davaci = h.id or davali = h.id order by id desc limit 10) d), '[]'::jsonb),
    'adayliklar', coalesce((select jsonb_agg(jsonb_build_object('aday_id', a.id, 'secim_id', s.id, 'secim', oyun.yp_tur_ad(s.tur) || ' · ' || s.donem,
          'asama', oyun.yp_asama(s, t), 'il', i.ad, 'parti', pa.kisa, 'sira', a.sira) order by s.oy_bas)
        from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id left join oyun.iller i on i.id = a.il_id left join oyun.partiler pa on pa.id = a.parti_id
        where a.user_id = h.id and s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false)), '[]'::jsonb),
    'oy_hakki', oyun.yp_oy_hakki(h),
    'portal_islemleri', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'baslik', k.baslik, 'durum', x.durum, 'zaman', coalesce(x.uygulama, x.olusturma),
          'ozet', coalesce(x.sonuc->>'ozet', x.onizleme->>'ozet', x.hata)) order by x.id desc)
        from (select * from oyun.yp_islem y where y.durum <> 'onizleme'
                and (y.parametre->>'user_id' = h.id::text or y.parametre->'kullanicilar' ? h.id::text or y.sonuc::text like '%' || h.id::text || '%')
              order by y.id desc limit 20) x left join oyun.yp_katalog k on k.islem = x.islem), '[]'::jsonb),
    'yonetim_kayitlari', coalesce((select jsonb_agg(jsonb_build_object('zaman', m.zaman, 'kad', m.kad, 'islem', m.islem, 'ayrinti', m.ayrinti) order by m.id desc)
        from (select * from oyun.mod_kayit where hedef = h.kad order by id desc limit 20) m), '[]'::jsonb));
end $$;

create or replace function public.yp_sozluk()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yp_sahip();
begin
  return jsonb_build_object(
    'iller', (select jsonb_agg(jsonb_build_object('id', id, 'ad', ad, 'mv', coalesce(mv_secim, mv)) order by ad) from oyun.iller),
    'partiler', (select jsonb_agg(jsonb_build_object('id', id, 'kisa', kisa, 'ad', ad, 'renk', renk) order by kisa)
                 from oyun.partiler where not coalesce(kapali, false)),
    'bakanliklar', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad) order by sira) from oyun.bakanliklar),
    'katalog', (select jsonb_agg(to_jsonb(k) order by k.grup, k.islem) from oyun.yp_katalog k));
end $$;

-- ---------------------------------------------------------------------
-- 13) Yetkiler (164 ile aynı kural)
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
