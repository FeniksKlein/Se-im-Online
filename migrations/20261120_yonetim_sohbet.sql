-- Canlıya 20.11.2026'da Supabase migration'ı olarak uygulandı: yonetim_sohbet_20261120
-- Kaynak: gelistirici/sql/zz_20261120_yonetim_sohbet.sql · tekrar çalıştırmak güvenlidir.
begin;
set local lock_timeout = '5s';

-- 20.11.2026 · SOHBETE YÖNETİM ADINA YAZMA (Ercan'ın kararı: "İşleyelim")
-- İstek: moderatör, sohbete rol karakterinin adıyla değil "Oyun Yöneticisi G-03" gibi görev koduyla yazabilsin.
-- Bugüne kadar bu yalnız Yardım Masası kanalında vardı (public.yardim_yanitla). Diğer kanallarda moderatör ya
-- karakteriyle yazıyordu (kimliği açığa çıkar) ya da uyarmadan doğrudan yaptırım uyguluyordu.
--   1) Yeni yetki: sohbet_resmi ("Sohbete yönetim adına yazma"). İçerik Masası'nın yetkisidir; kurucu her zaman yazar.
--      Kurucu, Moderasyon Merkezi › Ekip ekranından başka bir moderatöre de ek yetki olarak verebilir.
--   2) public.mod_sohbet_yaz(kanal, metin): kanal gerçek kanal kodudur (genel, yardim, meclis, kabine, il:34, belediye:34,
--      parti:3, yonetim:3, ittifak:2, og:15). Moderatörün o kanalın üyesi olması gerekmez (nöbette gördüğü her kanala yazar).
--      Kapalı kanallar (parti, parti yönetimi, ittifak, kabine, belediye, özel gruplar) için ayrıca sohbet_tum gerekir.
--      Gizlilik sözleşmesi kabul edilmiş olmalı. Hız sınırı: 3 saniyede 1, dakikada 6. Her mesaj mod_kayit'a yazılır.
--   3) Mesaj mesajlar.gorevli = true ile saklanır; Yardım Masası'nın bütün gizlilik kuralları aynen geçerlidir:
--      kullanıcı adı / parti / unvan yerine görev unvanı görünür, şikâyetle gizlenemez, engel listesi saklamaz,
--      oyuncu dosyasında yalnız kurucuya görünür.
--   4) Sızıntı kapatıldı: sohbet_ozet (kanal listesindeki "son mesaj" satırı) yönetim mesajında gerçek adı gösteriyordu
--      (Yardım Masası ayrı anahtarda olduğu için bugüne kadar görünmüyordu).
--   5) sohbet_oku dönüşüne resmi_yazabilir ve kanal_kod, mod_sohbet_nobeti dönüşüne resmi_yetki eklendi.
--      Eski mağaza sürümleri bu anahtarları yok sayar; yönetim mesajını "Oyun Yöneticisi G-03" adıyla sıradan balon olarak görür.
-- Oyuncu verisi değişmez (yalnız İçerik Masası moderatörlerinin yetki listesine ekleme). Tekrar çalıştırmak güvenlidir.

-- ---------- Kim yönetim adına sohbete yazabilir ----------
create or replace function oyun.sohbet_resmi_yetkili(p oyun.profiller)
 returns boolean
 language sql
 stable
 set search_path to ''
as $function$
  select case when p.id is null or coalesce(p.yasakli, false) then false
              when coalesce(p.yonetici, false) then true
              when exists (select 1 from oyun.moderatorler m where m.user_id = p.id and m.sozlesme_at is not null)
                then oyun.yetkili(p.id, 'sohbet_resmi')
              else false end
$function$;

-- ---------- Kanal kodu geçerli ve açık mı ----------
create or replace function oyun.sohbet_resmi_kanal(k text)
 returns boolean
 language plpgsql
 stable
 set search_path to ''
as $function$
declare tur text; no bigint;
begin
  if k is null then return false; end if;
  if k in ('genel', 'yardim', 'meclis', 'kabine') then return true; end if;
  if k !~ '^(il|belediye|parti|yonetim|ittifak|og):[0-9]{1,9}$' then return false; end if;
  tur := split_part(k, ':', 1); no := split_part(k, ':', 2)::bigint;
  return case tur
    when 'il' then exists (select 1 from oyun.iller i where i.id = no)
    when 'belediye' then exists (select 1 from oyun.iller i where i.id = no)
    when 'parti' then exists (select 1 from oyun.partiler pa where pa.id = no and not pa.kapali)
    when 'yonetim' then exists (select 1 from oyun.partiler pa where pa.id = no and not pa.kapali)
    when 'ittifak' then exists (select 1 from oyun.ittifaklar a where a.id = no)
    when 'og' then exists (select 1 from oyun.sohbet_grup g where g.id = no and not g.kapali)
    else false end;
end $function$;

-- ---------- Bu kişi bu kanala yönetim adına yazabilir mi (sohbet_oku ve mod_sohbet_yaz ortak kuralı) ----------
create or replace function oyun.sohbet_resmi_yazabilir(p oyun.profiller, k text)
 returns boolean
 language sql
 stable
 set search_path to ''
as $function$
  select case when k is null or not oyun.sohbet_resmi_yetkili(p) then false
              when oyun.mod_kanal_acik(k) then true
              when oyun.mod_kanal_grup(k) then oyun.yetkili(p.id, 'sohbet_tum')
              else false end
$function$;

-- ---------- Yönetim adına sohbete yaz ----------
create or replace function public.mod_sohbet_yaz(p_kanal text, p_metin text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text := btrim(coalesce(p_kanal, '')); m text; alt bigint;
begin
  if not oyun.sohbet_resmi_yetkili(p) then
    raise exception 'Sohbete oyun yönetimi adına yazmak için "Sohbete yönetim adına yazma" yetkisi ve kabul edilmiş gizlilik sözleşmesi gerekir.';
  end if;
  if not oyun.sohbet_resmi_kanal(k) then raise exception 'Bu sohbet kanalı bulunamadı ya da kapanmış.'; end if;
  if not oyun.sohbet_resmi_yazabilir(p, k) then
    raise exception 'Kapalı sohbetlere (parti, ittifak, kabine, belediye, özel gruplar) yönetim adına yazmak için "Tüm grup sohbetlerini görme" yetkisi gerekir.';
  end if;
  if p.susturma_bitis is not null and p.susturma_bitis > t then
    raise exception 'Hesabın susturulmuş durumda; yönetim adına da yazamazsın.';
  end if;
  -- Hız sınırı (yalnız son mesajlara bakar; tablo büyüse de hızlı kalır)
  select coalesce(max(id), 0) - 5000 into alt from oyun.mesajlar;
  if exists (select 1 from oyun.mesajlar x where x.id > alt and x.user_id = p.id and x.gorevli and x.zaman > t - interval '3 seconds') then
    raise exception 'Çok hızlı yazıyorsun, birkaç saniye bekle.';
  end if;
  if (select count(*) from oyun.mesajlar x where x.id > alt and x.user_id = p.id and x.gorevli and x.zaman > t - interval '1 minute') >= 6 then
    raise exception 'Bir dakikada en çok 6 yönetim mesajı gönderilebilir. Biraz bekle.';
  end if;
  m := oyun.metin_temizle(p_metin, 1000);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman, gorevli) values (k, p.id, m, t, true);
  perform oyun.mod_log(p, 'sohbet_resmi', k, oyun.mod_kanal_ad(k) || ': ' || m);
  return jsonb_build_object('tamam', true, 'kanal', k, 'kanal_ad', oyun.mod_kanal_ad(k), 'imza', oyun.mod_imza(p));
end $function$;

-- ---------- Yerinde yamalar ----------
do $yama$
declare s text;
begin
  -- Yetki tanımı: 18. satır
  s := pg_get_functiondef('oyun.mod_yetki_tanim()'::regprocedure);
  if position('sohbet_resmi' in s) = 0 and position(', 17)' in s) > 0 then
    s := replace(s, ', 17)', ', 17),' || E'\n' ||
      '         (''sohbet_resmi'', ''Sohbete yönetim adına yazma'', ''Sohbet kanallarına kendi adıyla değil görev koduyla ("Oyun Yöneticisi G-03") uyarı ve bilgilendirme yazar. Adı, partisi ve unvanı görünmez. Kapalı sohbetler için ayrıca "Tüm grup sohbetlerini görme" gerekir. Her mesaj denetim günlüğüne yazılır.'', 18)');
    execute s;
  end if;

  -- İçerik Masası: yetki listesi ve açıklama
  s := pg_get_functiondef('oyun.mod_birim_tanim()'::regprocedure);
  if position('sohbet_resmi' in s) = 0 then
    s := replace(s, '''oyuncu_ara'',''sohbet_tum'']::text[], 5, ''#e0a43a''', '''oyuncu_ara'',''sohbet_tum'',''sohbet_resmi'']::text[], 5, ''#e0a43a''');
    s := replace(s, 'bölücü içeriği anında kaldırır. Yaptırım yetkisi: 7 güne kadar susturma, 24 saat hesap engeli',
                    'bölücü içeriği anında kaldırır; sohbete görev koduyla, oyun yönetimi adına uyarı yazar. Yaptırım yetkisi: 7 güne kadar susturma, 24 saat hesap engeli');
    if position('sohbet_resmi' in s) > 0 then execute s; end if;
  end if;

  -- Okuma: bu kişi bu kanala yönetim adına yazabilir mi + gerçek kanal kodu
  s := pg_get_functiondef('public.sohbet_oku(text, bigint, bigint)'::regprocedure);
  if position('resmi_yazabilir' in s) = 0 then
    s := replace(s, '''gorevli_yazabilir'', k = ''yardim'' and oyun.yardim_gorevli_mi(p));',
                    '''gorevli_yazabilir'', k = ''yardim'' and oyun.yardim_gorevli_mi(p), ''resmi_yazabilir'', oyun.sohbet_resmi_yazabilir(p, k), ''kanal_kod'', k);');
    execute s;
  end if;

  -- Kanal listesi özeti: yönetim mesajında gerçek ad yerine görev unvanı; engel listesi yönetim mesajını saklamaz
  s := pg_get_functiondef('public.sohbet_ozet()'::regprocedure);
  if position('m.gorevli' in s) = 0 then
    s := replace(s, 'jsonb_build_object(''kad'', coalesce(pr.kad, ''(silinmiş)''), ''metin'', m.metin, ''zaman'', m.zaman) into son',
                    'jsonb_build_object(''kad'', case when m.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, ''(silinmiş)'') end, ''metin'', m.metin, ''zaman'', m.zaman, ''gorevli'', m.gorevli) into son');
    s := replace(s, 'm.zaman <= t and not oyun.engelli(p.id, m.user_id) order by m.id desc limit 1',
                    'm.zaman <= t and (m.gorevli or not oyun.engelli(p.id, m.user_id)) order by m.id desc limit 1');
    s := replace(s, 'm.zaman > t - interval ''3 days'' and not oyun.engelli(p.id, m.user_id) limit 100',
                    'm.zaman > t - interval ''3 days'' and (m.gorevli or not oyun.engelli(p.id, m.user_id)) limit 100');
    execute s;
  end if;

  -- Sohbet nöbeti: yönetim adına yazma yetkisi bilgisi
  s := pg_get_functiondef('public.mod_sohbet_nobeti(text, boolean, bigint, integer)'::regprocedure);
  if position('resmi_yetki' in s) = 0 then
    s := replace(s, '''zaman'', t, ''tum_yetki'', tum,', '''zaman'', t, ''tum_yetki'', tum, ''resmi_yetki'', oyun.sohbet_resmi_yetkili(p),');
    execute s;
  end if;
end $yama$;

-- İçerik Masası'ndaki mevcut moderatörlere yeni yetki eklenir (yalnız yetki listesine ekleme)
update oyun.moderatorler set yetkiler = (select array_agg(distinct x order by x) from unnest(yetkiler || array['sohbet_resmi']) x)
 where ana_gorev = 'icerik' and not ('sohbet_resmi' = any(yetkiler));

revoke all on function oyun.sohbet_resmi_yetkili(oyun.profiller) from public, anon, authenticated;
revoke all on function oyun.sohbet_resmi_kanal(text) from public, anon, authenticated;
revoke all on function oyun.sohbet_resmi_yazabilir(oyun.profiller, text) from public, anon, authenticated;
revoke all on function public.mod_sohbet_yaz(text, text) from public, anon;
grant execute on function public.mod_sohbet_yaz(text, text) to authenticated, service_role;

commit;
