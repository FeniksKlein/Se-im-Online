-- 21.11.2026 · Nöbetçi hâkimlik (canlı migration: nobetci_hakimlik_sevk_sistemi)
-- CMK m.91, 100, 109 ölçeği: gözaltına alan makam (Cumhurbaşkanı / İçişleri Bakanı) gözaltı süresi içinde şüpheliyi
-- suçlama ve delille nöbetçi hâkimliğe sevk eder. Hâkim sorgu sonunda üç karardan birini verir:
--   serbest bırakma · adli kontrol (tutuksuz yargılama) · tutuklama (tutuklu yargılama).
-- Ceza ya da beraat nöbetçi hâkimden değil, sevk üzerine açılan davada mahkemeden çıkar.
-- Oyun kuralı (süreler tarife tablosunda): sorgu 3 saat, tutukluluk 6 saat, nöbetçi önceliği 60 dakika.
-- Yalnız yonetim_tutuklama (CB/İçişleri gözaltı kararı) sevk edilir; eylem ve mahkeme onaylı İçişleri gözaltıları zaten hâkim denetimindedir.
insert into oyun.tarife(kod, deger, birim, kategori, ad, aciklama, sira) values
 ('nobetci_sorgu_saat', 3, 'saat', 'kural', 'Nöbetçi hâkimlik sorgu süresi', 'Sevkten sonra nöbetçi hâkimin karar vermesi için tanınan süre (saat). Karar çıkmazsa şüpheli kendiliğinden serbest kalır.', 905),
 ('nobetci_tutukluluk_saat', 6, 'saat', 'kural', 'Tutukluluk süresi', 'Nöbetçi hâkim tutuklama kararı verirse gözaltının karardan sonra süreceği süre (saat).', 906),
 ('nobetci_oncelik_dk', 60, 'dakika', 'kural', 'Nöbetçi hâkim önceliği', 'Sevkten sonra dosyaya yalnız o günün nöbetçi hâkiminin bakabildiği süre (dakika); sonra diğer mahkeme üyeleri de karar verebilir.', 907)
on conflict (kod) do nothing;

create table if not exists oyun.nobetci_sevk (
  id bigint generated always as identity primary key,
  kaynak text not null check (kaynak = 'yonetim'),
  dosya_id bigint not null,
  hedef uuid not null references oyun.profiller(id),
  sevk_eden uuid not null references oyun.profiller(id),
  makam text not null,
  suc_tur text not null check (suc_tur in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger')),
  iddia text not null check (char_length(iddia) between 20 and 3000),
  delil text not null default '' check (char_length(delil) <= 3000),
  zaman timestamptz not null,
  son timestamptz not null,
  nobetci uuid references oyun.profiller(id),
  savunma text check (savunma is null or char_length(savunma) between 20 and 3000),
  savunma_yazan uuid references oyun.profiller(id),
  savunma_at timestamptz,
  durum text not null default 'bekliyor' check (durum in ('bekliyor','serbest','adli_kontrol','tutuklama','sure_doldu','dustu')),
  hakim uuid references oyun.profiller(id),
  gerekce text,
  karar_at timestamptz,
  tutukluluk_bitis timestamptz,
  dava_id bigint references oyun.adliye_davalar(id),
  unique (kaynak, dosya_id),
  check (hedef <> sevk_eden)
);
create index if not exists nobetci_sevk_bekleyen on oyun.nobetci_sevk(son) where durum = 'bekliyor';
create index if not exists nobetci_sevk_hedef on oyun.nobetci_sevk(hedef, zaman desc);
alter table oyun.nobetci_sevk enable row level security;
revoke all on oyun.nobetci_sevk from anon, authenticated;

-- O günün nöbetçi hâkimi: görevdeki Yüksek Mahkeme üyeleri arasında günlük dönüşüm
create or replace function oyun.nobetci_hakim(p_haric uuid[] default '{}')
returns uuid language sql stable set search_path to '' as $fn$
  with u as (
    select m.user_id, row_number() over (order by m.sira) - 1 as rn, count(*) over () as n
      from oyun.mahkeme_uye m join oyun.profiller p on p.id = m.user_id
     where m.user_id is not null and not coalesce(p.yasakli, false)
       and not (m.user_id = any (coalesce(p_haric, '{}')))
  )
  select user_id from u
   where rn = ((oyun.simdi() at time zone 'Europe/Istanbul')::date - date '2026-01-01') % n
$fn$;

-- 1) Sevk
create or replace function public.nobetci_sevk_et(p_kaynak text, p_id bigint, p_tur text, p_iddia text, p_delil text default '')
returns jsonb language plpgsql security definer set search_path to '' as $fn$
declare
  u uuid := auth.uid(); m text; t timestamptz := oyun.simdi();
  y oyun.yonetim_tutuklama; h uuid; e text; v_son timestamptz; yeni bigint; mad text;
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  m := oyun.ifade_makam(u);
  if m is null then raise exception 'Nöbetçi hâkimliğe sevk yetkisi yalnız Cumhurbaşkanı ve İçişleri Bakanındadır.'; end if;
  if p_kaynak is distinct from 'yonetim' then raise exception 'Bu gözaltı türü zaten hâkim denetimindedir; sevk yalnız Cumhurbaşkanlığı / İçişleri gözaltı kararlarında yapılır.'; end if;
  if p_tur is null or p_tur not in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger') then raise exception 'Suçlama türü geçersiz.'; end if;
  if char_length(btrim(coalesce(p_iddia,''))) not between 20 and 3000 then raise exception 'Suçlama açıklaması 20–3000 karakter olmalı.'; end if;
  if char_length(coalesce(p_delil,'')) > 3000 then raise exception 'Delil açıklaması 3000 karakteri aşamaz.'; end if;
  select * into y from oyun.yonetim_tutuklama where id = p_id for update;
  if y.id is null or y.durum <> 'aktif' or y.bitis <= t then raise exception 'Sevk edilebilecek devam eden gözaltı bulunamadı.'; end if;
  if y.hedef = u then raise exception 'Kendi dosyanızı sevk edemezsiniz.'; end if;
  if exists (select 1 from oyun.nobetci_sevk s where s.kaynak = 'yonetim' and s.dosya_id = y.id) then
    raise exception 'Bu gözaltı dosyası zaten nöbetçi hâkimliğe sevk edildi.';
  end if;
  e := oyun.dokunulmazlik_engel(y.hedef, 'ceza');
  if e is not null then raise exception '%', e; end if;
  h := oyun.nobetci_hakim(array[y.hedef, u] || case when y.avukat is not null then array[y.avukat] else '{}'::uuid[] end);
  if h is null then raise exception 'Görevde bu dosyaya bakabilecek nöbetçi hâkim yok (Yüksek Mahkeme üyeleri atanmamış ya da dosyayla ilgili). Sevk yapılamaz; şüpheli gözaltı süresi dolunca serbest kalır.'; end if;
  v_son := greatest(y.bitis, t + make_interval(secs => oyun.gozalti_ayar('nobetci_sorgu_saat', 3) * 3600));
  update oyun.yonetim_tutuklama set bitis = v_son where id = y.id;
  insert into oyun.nobetci_sevk(kaynak, dosya_id, hedef, sevk_eden, makam, suc_tur, iddia, delil, zaman, son, nobetci)
  values ('yonetim', y.id, y.hedef, u, m, p_tur, btrim(p_iddia), coalesce(p_delil,''), t, v_son, h)
  returning id into yeni;
  mad := case m when 'cumhurbaskani' then 'Cumhurbaşkanlığı' else 'İçişleri Bakanlığı' end;
  perform oyun.bildir(y.hedef, format('%s sizi nöbetçi hâkimliğe sevk etti (sevk #%s). Hâkim en geç %s tarihine kadar serbest bırakma, adli kontrol ya da tutuklama kararı verecek. Savunmanızı siz ya da avukatınız yazabilir: Gözaltı ve Avukat ekranı.', mad, yeni, to_char(v_son at time zone 'Europe/Istanbul','DD.MM HH24:MI')), t);
  if y.avukat is not null and y.avukat_durum in ('cagrildi','kabul') then
    perform oyun.bildir(y.avukat, format('Müvekkiliniz %s nöbetçi hâkimliğe sevk edildi (sevk #%s). Savunmayı onun adına yazabilirsiniz; son: %s.', oyun.kad(y.hedef), yeni, to_char(v_son at time zone 'Europe/Istanbul','DD.MM HH24:MI')), t);
  end if;
  perform oyun.bildir(h, format('Nöbetçi hâkimlik: %s hakkında sevk #%s size geldi. Karar süresi %s tarihinde doluyor; karar verilmezse şüpheli serbest kalır.', oyun.kad(y.hedef), yeni, to_char(v_son at time zone 'Europe/Istanbul','DD.MM HH24:MI')), t);
  return jsonb_build_object('tamam', true, 'id', yeni, 'son', v_son, 'nobetci', oyun.kad(h));
end $fn$;

-- 2) Savunma (şüpheli ya da avukatı)
create or replace function public.nobetci_savunma(p_sevk bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to '' as $fn$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.nobetci_sevk; y oyun.yonetim_tutuklama;
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  if char_length(btrim(coalesce(p_metin,''))) not between 20 and 3000 then raise exception 'Savunma 20–3000 karakter olmalı.'; end if;
  select * into s from oyun.nobetci_sevk where id = p_sevk for update;
  if s.id is null or s.durum <> 'bekliyor' or s.son <= t then raise exception 'Savunma verilebilecek açık sevk dosyası yok.'; end if;
  select * into y from oyun.yonetim_tutuklama where id = s.dosya_id;
  if u <> s.hedef and not (y.avukat = u and y.avukat_durum = 'kabul') then
    raise exception 'Savunmayı yalnız şüpheli ya da görevi kabul etmiş avukatı yazabilir.';
  end if;
  update oyun.nobetci_sevk set savunma = btrim(p_metin), savunma_yazan = u, savunma_at = t where id = s.id;
  if s.nobetci is not null then
    perform oyun.bildir(s.nobetci, format('Nöbetçi hâkimlik: sevk #%s dosyasına savunma sunuldu.', s.id), t);
  end if;
  return jsonb_build_object('tamam', true);
end $fn$;

-- 3) Karar
create or replace function public.nobetci_karar(p_sevk bigint, p_karar text, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to '' as $fn$
declare
  u uuid := auth.uid(); t timestamptz := oyun.simdi();
  s oyun.nobetci_sevk; y oyun.yonetim_tutuklama; g text := btrim(coalesce(p_gerekce,''));
  v_dava bigint; v_tut timestamptz; sure int; mad text;
begin
  if u is null or not exists (select 1 from oyun.mahkeme_uye where user_id = u) then
    raise exception 'Bu kararı yalnız görevdeki Yüksek Mahkeme üyeleri (nöbetçi hâkim) verebilir.';
  end if;
  if p_karar is null or p_karar not in ('serbest','adli_kontrol','tutuklama') then
    raise exception 'Karar serbest bırakma, adli kontrol ya da tutuklama olmalı. Ceza ve beraat, sevk üzerine açılan davada mahkemece verilir.';
  end if;
  if char_length(g) not between 25 and 2000 then raise exception 'Gerekçe 25–2000 karakter olmalı.'; end if;
  select * into s from oyun.nobetci_sevk where id = p_sevk for update;
  if s.id is null or s.durum <> 'bekliyor' then raise exception 'Karar bekleyen böyle bir sevk dosyası yok.'; end if;
  select * into y from oyun.yonetim_tutuklama where id = s.dosya_id for update;
  if u = s.hedef or u = s.sevk_eden or u is not distinct from y.avukat then
    raise exception 'Çıkar çatışması: bu dosyaya bakamazsınız.';
  end if;
  if u is distinct from s.nobetci
     and t < s.zaman + make_interval(mins => oyun.gozalti_ayar('nobetci_oncelik_dk', 60)::int)
     and exists (select 1 from oyun.mahkeme_uye where user_id = s.nobetci) then
    raise exception 'Dosya önce nöbetçi hâkim %''de. Diğer üyeler % tarihinden sonra karar verebilir.',
      oyun.kad(s.nobetci), to_char((s.zaman + make_interval(mins => oyun.gozalti_ayar('nobetci_oncelik_dk', 60)::int)) at time zone 'Europe/Istanbul','DD.MM HH24:MI');
  end if;
  if s.son <= t or y.id is null or y.durum <> 'aktif' or y.bitis <= t then
    update oyun.nobetci_sevk set durum = case when s.son <= t then 'sure_doldu' else 'dustu' end, karar_at = t where id = s.id;
    return jsonb_build_object('tamam', false, 'mesaj', 'Sorgu süresi doldu ya da şüpheli serbest bırakıldı; dosya kapandı.');
  end if;
  mad := case s.makam when 'cumhurbaskani' then 'Cumhurbaşkanlığı' else 'İçişleri Bakanlığı' end;

  if p_karar = 'tutuklama' then
    v_tut := t + make_interval(secs => greatest(1, least(24, oyun.gozalti_ayar('nobetci_tutukluluk_saat', 6))) * 3600);
    update oyun.yonetim_tutuklama set bitis = v_tut where id = y.id;
  else
    update oyun.yonetim_tutuklama set durum = 'serbest', bitis = t, serbest_birakan = u,
           serbest_gerekce = left('Nöbetçi hâkim kararı: ' || g, 800), serbest_zaman = t where id = y.id;
  end if;

  if p_karar in ('adli_kontrol','tutuklama') then
    sure := coalesce((select avukat_savunma_saat from oyun.ayarlar where id = 1), 24);
    insert into oyun.adliye_davalar(davaci, davali, tur, iddia, delil, acilis, savunma_son, karar_son, harc, kesin)
    values (s.sevk_eden, s.hedef, s.suc_tur,
            format('%s sevki üzerine açılmıştır (nöbetçi hâkimlik sevk #%s, %s kararı). ', mad, s.id,
                   case p_karar when 'tutuklama' then 'tutuklama' else 'adli kontrol' end) || s.iddia,
            s.delil, t, t + make_interval(hours => sure),
            t + make_interval(hours => sure) + make_interval(hours => (select ma.karar_saat from oyun.mahkeme_ayar ma)),
            0, false)
    returning id into v_dava;
    perform oyun.bildir(mu.user_id, 'Yüksek Mahkeme: #' || v_dava || ' numaralı dava dosyası nöbetçi hâkimlik sevkiyle açıldı.', t)
      from oyun.mahkeme_uye mu where mu.user_id is not null and mu.user_id <> u;
  end if;

  update oyun.nobetci_sevk set durum = p_karar, hakim = u, gerekce = g, karar_at = t,
         tutukluluk_bitis = v_tut, dava_id = v_dava where id = s.id;

  perform oyun.bildir(s.hedef, case p_karar
    when 'serbest' then format('Nöbetçi hâkim sizi serbest bıraktı (sevk #%s). Gerekçe: %s', s.id, left(g, 300))
    when 'adli_kontrol' then format('Nöbetçi hâkim adli kontrol kararı verdi: serbestsiniz, tutuksuz yargılanacaksınız (dava #%s). %s saat içinde savunma yazabilir ya da avukat tutabilirsiniz. Gerekçe: %s', v_dava, sure, left(g, 300))
    else format('Nöbetçi hâkim tutuklanmanıza karar verdi: tutukluluğunuz %s tarihine kadar sürecek, yargılama dava #%s dosyasında yapılacak. Cumhurbaşkanı ya da İçişleri Bakanı sizi daha önce tahliye edebilir. Gerekçe: %s', to_char(v_tut at time zone 'Europe/Istanbul','DD.MM HH24:MI'), v_dava, left(g, 300)) end, t);
  perform oyun.bildir(s.sevk_eden, format('Nöbetçi hâkimlik sevk #%s (%s): %s.%s', s.id, oyun.kad(s.hedef),
    case p_karar when 'serbest' then 'şüpheli serbest bırakıldı' when 'adli_kontrol' then 'adli kontrol, tutuksuz yargılama' else 'tutuklama' end,
    coalesce(' Dava #' || v_dava || ' açıldı.', '')), t);
  if y.avukat is not null and y.avukat_durum in ('cagrildi','kabul') then
    perform oyun.bildir(y.avukat, format('Müvekkiliniz %s hakkında nöbetçi hâkim kararı (sevk #%s): %s.%s', oyun.kad(s.hedef), s.id,
      case p_karar when 'serbest' then 'serbest bırakma' when 'adli_kontrol' then 'adli kontrol' else 'tutuklama' end,
      coalesce(' Dava #' || v_dava || '.', '')), t);
  end if;
  return jsonb_build_object('tamam', true, 'karar', p_karar, 'dava_id', v_dava, 'tutukluluk_bitis', v_tut);
end $fn$;

-- 4) Süre denetimi (5 dakikada bir; sınırlı, kilitli kayıt atlanır)
create or replace function oyun.nobetci_tick()
returns integer language plpgsql security definer set search_path to '' as $fn$
declare t timestamptz := oyun.simdi(); r record; n integer := 0; aktif boolean;
begin
  for r in select s.* from oyun.nobetci_sevk s where s.durum = 'bekliyor' order by s.son limit 200 for update skip locked loop
    select (y.durum = 'aktif' and y.bitis > t) into aktif from oyun.yonetim_tutuklama y where y.id = r.dosya_id;
    if r.son <= t then
      update oyun.nobetci_sevk set durum = 'sure_doldu', karar_at = t where id = r.id;
      perform oyun.bildir(r.hedef, format('Nöbetçi hâkim süresi içinde karar vermedi (sevk #%s). Gözaltınız sona erdi, serbestsiniz.', r.id), t);
      perform oyun.bildir(r.sevk_eden, format('Nöbetçi hâkimlik sevk #%s: süresinde karar çıkmadı, %s serbest kaldı.', r.id, oyun.kad(r.hedef)), t);
      n := n + 1;
    elsif not coalesce(aktif, false) then
      update oyun.nobetci_sevk set durum = 'dustu', karar_at = t where id = r.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end $fn$;

-- 5) Ekran verisi
create or replace function public.nobetci_panel()
returns jsonb language plpgsql stable security definer set search_path to '' as $fn$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); hakim_mi boolean; yetkili boolean;
begin
  if u is null then raise exception 'Giriş yapmalısınız'; end if;
  hakim_mi := exists (select 1 from oyun.mahkeme_uye where user_id = u);
  yetkili := oyun.ifade_makam(u) is not null;
  return jsonb_build_object(
    'simdi', t,
    'hakim_mi', hakim_mi,
    'sevk_yetkisi', yetkili,
    'nobetci_hakim', oyun.kad(oyun.nobetci_hakim()),
    'suc_turleri', jsonb_build_array('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger'),
    'kararlar', jsonb_build_array('serbest','adli_kontrol','tutuklama'),
    'sureler', jsonb_build_object('sorgu_saat', oyun.gozalti_ayar('nobetci_sorgu_saat',3), 'tutukluluk_saat', oyun.gozalti_ayar('nobetci_tutukluluk_saat',6), 'oncelik_dk', oyun.gozalti_ayar('nobetci_oncelik_dk',60)),
    'dosyam', (select jsonb_build_object('id', s.id, 'durum', s.durum, 'suc_tur', s.suc_tur, 'iddia', s.iddia, 'delil', s.delil,
                 'sevk_eden', oyun.kad(s.sevk_eden), 'makam', s.makam, 'zaman', s.zaman, 'son', s.son, 'nobetci', oyun.kad(s.nobetci),
                 'savunma', s.savunma, 'savunma_at', s.savunma_at, 'hakim', oyun.kad(s.hakim), 'gerekce', s.gerekce, 'karar_at', s.karar_at,
                 'tutukluluk_bitis', s.tutukluluk_bitis, 'dava_id', s.dava_id)
                from oyun.nobetci_sevk s where s.hedef = u order by s.zaman desc limit 1),
    'muvekkil_dosyalari', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'hedef', oyun.kad(s.hedef), 'suc_tur', s.suc_tur, 'iddia', s.iddia, 'delil', s.delil,
                 'son', s.son, 'savunma', s.savunma) order by s.son)
                from oyun.nobetci_sevk s join oyun.yonetim_tutuklama y on y.id = s.dosya_id
               where s.durum = 'bekliyor' and s.son > t and y.avukat = u and y.avukat_durum = 'kabul'), '[]'::jsonb),
    'hakim_dosyalari', case when hakim_mi then coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'hedef', oyun.kad(s.hedef),
                 'sevk_eden', oyun.kad(s.sevk_eden), 'makam', s.makam, 'suc_tur', s.suc_tur, 'iddia', s.iddia, 'delil', s.delil,
                 'gozalti_gerekce', y.gerekce, 'zaman', s.zaman, 'son', s.son, 'nobetci', oyun.kad(s.nobetci), 'nobetci_benim', s.nobetci = u,
                 'savunma', s.savunma, 'savunma_yazan', oyun.kad(s.savunma_yazan),
                 'bakabilir', not (u = s.hedef or u = s.sevk_eden or u is not distinct from y.avukat)) order by s.son)
                from oyun.nobetci_sevk s join oyun.yonetim_tutuklama y on y.id = s.dosya_id
               where s.durum = 'bekliyor' and s.son > t), '[]'::jsonb) else '[]'::jsonb end,
    'sevk_edilebilir', case when yetkili then coalesce((select jsonb_agg(jsonb_build_object('kaynak', 'yonetim', 'id', y.id, 'hedef', oyun.kad(y.hedef),
                 'gerekce', y.gerekce, 'bitis', y.bitis,
                 'sevk', (select jsonb_build_object('id', s.id, 'durum', s.durum, 'son', s.son) from oyun.nobetci_sevk s where s.kaynak = 'yonetim' and s.dosya_id = y.id)) order by y.bitis)
                from oyun.yonetim_tutuklama y where y.durum = 'aktif' and y.bitis > t and y.hedef <> u), '[]'::jsonb) else '[]'::jsonb end,
    'son_kararlar', coalesce((select jsonb_agg(x.j order by x.karar_at desc) from (
                select s.karar_at, jsonb_build_object('id', s.id, 'hedef', oyun.kad(s.hedef), 'makam', s.makam, 'suc_tur', s.suc_tur,
                       'durum', s.durum, 'gerekce', s.gerekce, 'karar_at', s.karar_at, 'dava_id', s.dava_id) j
                  from oyun.nobetci_sevk s where s.durum <> 'bekliyor' order by s.karar_at desc limit 20) x), '[]'::jsonb)
  );
end $fn$;

revoke all on function oyun.nobetci_hakim(uuid[]) from public;
revoke all on function oyun.nobetci_tick() from public;
grant execute on function oyun.nobetci_hakim(uuid[]) to service_role;
grant execute on function oyun.nobetci_tick() to service_role;
revoke all on function public.nobetci_sevk_et(text,bigint,text,text,text) from public, anon;
revoke all on function public.nobetci_savunma(bigint,text) from public, anon;
revoke all on function public.nobetci_karar(bigint,text,text) from public, anon;
revoke all on function public.nobetci_panel() from public, anon;
grant execute on function public.nobetci_sevk_et(text,bigint,text,text,text) to authenticated, service_role;
grant execute on function public.nobetci_savunma(bigint,text) to authenticated, service_role;
grant execute on function public.nobetci_karar(bigint,text,text) to authenticated, service_role;
grant execute on function public.nobetci_panel() to authenticated, service_role;

insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
values ('nobetci_hakimlik', 'select oyun.nobetci_tick()', 5, 3, 42, true)
on conflict (adim) do update set komut = excluded.komut, periyot_dk = excluded.periyot_dk, ofset_dk = excluded.ofset_dk, sira = excluded.sira, aktif = true;
