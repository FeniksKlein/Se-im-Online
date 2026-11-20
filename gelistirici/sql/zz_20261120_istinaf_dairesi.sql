-- 20.11.2026 · İSTİNAF DAİRESİ (Ercan'ın kararı, moderatör ekibinin isteği)
-- Eski düzen: istinafı kurayla seçilen 3 oyuncudan oluşan "jüri" inceliyor, üyelerin adı karardan sonra dosyada görünüyordu.
-- Yeni düzen (gerçekte de istinafı bölge adliye mahkemesinin 3 hâkimli dairesi inceler):
--   1) Heyet 3 üyelidir ve tamamı oyun yöneticilerinden (moderatörler) seçilir. Gizlilik sözleşmesini kabul etmiş,
--      son 7 günde oyunda görülmüş, dosyayla çıkar çatışması olmayan yöneticiler arasından; önce son 24 saatte
--      oyunda olanlar ve üzerinde en az açık dosya bulunanlar.
--   2) Tarafsızlık: davanın tarafı / vekili / ilk derece üyesi olan, taraf partilerden birine üye olan, taraflarla
--      aynı cihazı kullanan, aralarında dava ya da şirket ortaklığı bulunan yönetici seçilmez (oyun.mod_cikar_catismasi).
--   3) Tek kişiye bağlı kalmaz: yeterli yönetici yoksa kurucu, o da yoksa SON ÇARE olarak eski vatandaş kurası devreye girer
--      (kurucuya bildirim gider). Görevini yapmayan üyenin yerine yenisi atanır; ihmal yönetim kaydına işlenir.
--   4) Gizlilik (oyun kuralı): üyelerin adı hiçbir oyuncuya gösterilmez; dosyada "Üye 1 / Üye 2 / Üye 3" yazar.
--      Yalnız kurucu gerçek adları görür. Bozma haberi artık üyenin Kürsü hesabından değil, olay akışından duyurulur.
--      Yönetici üyeye istinaf oyu için kıdem verilmez (yalnız yöneticilerin kazanabildiği bir ödül olmasın).
--   5) İstinaf yargılama gideri aynen sürer: reddedilen başvuruda 50.000 ₺ (tazminatta %10, en çok 150.000 ₺).
-- Oyuncu verisi değişmez. Tekrar çalıştırmak güvenlidir.

-- ---------- Uygunluk: oyun yöneticisi (moderatör / kurucu) ----------
create or replace function oyun.istinaf_uye_uygun(d oyun.adliye_davalar, u uuid, t timestamp with time zone)
 returns boolean
 language sql
 stable
 set search_path to ''
as $function$
  select oyun.adliye_juri_uygun(d, u)
    and exists (select 1 from oyun.profiller p where p.id = u and not coalesce(p.yasakli, false)
                 and (p.parti_id is null or not (p.parti_id = any(oyun.dava_taraf_partileri(d)))))
    and (d.davaci is null or oyun.mod_cikar_catismasi(u, d.davaci) is null)
    and (d.davali is null or oyun.mod_cikar_catismasi(u, d.davali) is null)
    and not exists (select 1 from oyun.adliye_ek_taraf et where et.dava_id = d.id and oyun.mod_cikar_catismasi(u, et.user_id) is not null)
    and not exists (select 1 from oyun.juri_ihmal i where i.user_id = u and i.zaman > t - interval '48 hours')
$function$;

-- ---------- Son çare: vatandaş kurası (20.11.2026 öncesinin juri_cek'i; yöneticiler ve verilen kişiler hariç) ----------
create or replace function oyun.juri_cek_vatandas(d oyun.adliye_davalar, t timestamp with time zone, p_n integer, p_haric uuid[])
 returns uuid[]
 language sql
 set search_path to ''
as $function$
  with havuz as (
    select pr.id, pr.parti_id,
      case when pr.son_gorulme > t - interval '24 hours' then 0 when pr.son_gorulme > t - interval '72 hours' then 1
           when pr.son_gorulme > t - interval '7 days' then 2 else 3 end kat, random() rnd
    from oyun.profiller pr
    where pr.son_gorulme > t - interval '30 days'
      and not coalesce(pr.yonetici, false)
      and not (pr.id = any(coalesce(p_haric, '{}'::uuid[])))
      and not exists(select 1 from oyun.moderatorler mo where mo.user_id = pr.id)
      and not exists(select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = pr.id)
      and not exists(select 1 from oyun.adliye_juri_yedek y where y.dava_id = d.id and y.user_id = pr.id)
      and (select count(*) from oyun.adliye_juri j join oyun.adliye_istinaf s on s.dava_id = j.dava_id
            where j.user_id = pr.id and s.durum = 'acik' and j.oy is null) < 2
      and not exists(select 1 from oyun.adliye_davalar h where h.acilis > t - interval '30 days' and h.id <> d.id
            and ((h.davaci = pr.id and (h.davali = d.davaci or h.davali = d.davali))
              or (h.davali = pr.id and (h.davaci = d.davaci or h.davaci = d.davali))))
      and oyun.juri_aday_uygun(d, pr.id, t)
  ), sirali as (
    select h.id, h.kat, h.rnd,
      (row_number() over (partition by coalesce(h.parti_id::text, h.id::text) order by h.kat, h.rnd) > 1
       or (h.parti_id is not null and exists(select 1 from oyun.adliye_juri j2 join oyun.profiller p2 on p2.id = j2.user_id
             where j2.dava_id = d.id and p2.parti_id = h.parti_id)))::int tekrar
    from havuz h
  )
  select coalesce(array_agg(q.id order by q.o1, q.tekrar, q.kat, q.rnd), '{}'::uuid[]) from (
    select id, tekrar, kat, rnd, (kat > 1)::int o1 from sirali order by (kat > 1)::int, tekrar, kat, rnd limit greatest(p_n, 0)) q
$function$;

-- ---------- Heyet çekimi: yöneticiler → kurucu → (son çare) vatandaş kurası ----------
create or replace function oyun.juri_cek(d oyun.adliye_davalar, t timestamp with time zone, p_n integer)
 returns uuid[]
 language plpgsql
 set search_path to ''
as $function$
declare secilen uuid[]; ek uuid[]; eksik int;
begin
  select coalesce(array_agg(q.id order by q.kat, q.yuk, q.rnd), '{}'::uuid[]) into secilen
  from (
    select h.id, h.kat, h.yuk, h.rnd from (
      select m.user_id id,
             case when pr.son_gorulme > t - interval '24 hours' then 0 when pr.son_gorulme > t - interval '72 hours' then 1 else 2 end kat,
             (select count(*) from oyun.adliye_juri j join oyun.adliye_istinaf s on s.dava_id = j.dava_id
               where j.user_id = m.user_id and s.durum = 'acik' and j.oy is null) yuk,
             random() rnd
      from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id
      where m.sozlesme_at is not null
        and pr.son_gorulme > t - interval '7 days'
        and not exists (select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = m.user_id)
        and oyun.istinaf_uye_uygun(d, m.user_id, t)
    ) h
    where h.yuk < 6
    order by h.kat, h.yuk, h.rnd limit greatest(p_n, 0)
  ) q;
  eksik := p_n - cardinality(secilen);
  if eksik > 0 then
    select coalesce(array_agg(q.id), '{}'::uuid[]) into ek from (
      select pr.id from oyun.profiller pr
      where pr.yonetici and not coalesce(pr.yasakli, false)
        and not (pr.id = any(secilen))
        and not exists (select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = pr.id)
        and oyun.istinaf_uye_uygun(d, pr.id, t)
      order by pr.son_gorulme desc nulls last limit eksik) q;
    secilen := secilen || ek;
    eksik := p_n - cardinality(secilen);
  end if;
  if eksik > 0 then
    ek := oyun.juri_cek_vatandas(d, t, eksik, secilen);
    if cardinality(ek) > 0 then
      secilen := secilen || ek;
      perform oyun.mod_kurucu_bildir(format('İstinaf Dairesi: Adliye #%s için yeterli sayıda tarafsız oyun yöneticisi bulunamadı; %s üyelik vatandaş kurasıyla tamamlandı.', d.id, cardinality(ek)), t);
    end if;
  end if;
  return secilen;
end $function$;

-- ---------- Görev ihmali: yönetim kaydına işlenir ----------
create or replace function oyun.istinaf_ihmal_kaydet(u uuid, p_dava bigint, t timestamp with time zone, p_neden text)
 returns void
 language plpgsql
 set search_path to ''
as $function$
begin
  if u is null then return; end if;
  if exists (select 1 from oyun.moderatorler where user_id = u) then
    insert into oyun.mod_kayit(zaman, user_id, kad, islem, hedef, ayrinti)
    values (t, u, oyun.kad(u), 'istinaf_ihmal', 'Adliye #' || p_dava, left(coalesce(p_neden, 'oy kullanmadı'), 300));
  end if;
end $function$;

-- ---------- Heyetin kurulması: 3 üye, yedek listesi yok (yerine geçecek üye o anda çekilir) ----------
create or replace function oyun.adliye_juri_kur(p_dava bigint, t timestamp with time zone)
 returns integer
 language plpgsql
 set search_path to ''
as $function$
declare d oyun.adliye_davalar; secilen uuid[]; u uuid; asil int := 0; taraf text;
begin
  select * into d from oyun.adliye_davalar where id = p_dava;
  if d.id is null then return 0; end if;
  secilen := oyun.juri_cek(d, t, 3);
  taraf := oyun.dava_taraf_metni(d);
  foreach u in array secilen loop
    insert into oyun.adliye_juri(dava_id, user_id, atama) values (d.id, u, t) on conflict do nothing;
    asil := asil + 1;
    perform oyun.bildir(u, format('⚖️ İSTİNAF GÖREVİ: Adliye #%s dosyasında İstinaf Dairesi üyesi olarak görevlendirildin (%s). 24 saat içinde Adliye › Dosya #%s ekranından kararı onayla ya da boz. Üyeliğin gizlidir: adın hiçbir oyuncuya gösterilmez; sen de bu görevi kimseyle paylaşma. 8 saat oyuna girmezsen ya da 12 saat içinde oy vermezsen görev başka üyeye geçer.', d.id, taraf, d.id), t);
  end loop;
  return asil;
end $function$;

-- ---------- Üye değişimi ----------
create or replace function oyun.juri_degistir(p_dava bigint, p_eski uuid, t timestamp with time zone, p_neden text)
 returns uuid
 language plpgsql
 set search_path to ''
as $function$
declare d oyun.adliye_davalar; i oyun.adliye_istinaf; yeni uuid; kalan int; v_yon boolean;
begin
  if not exists(select 1 from oyun.adliye_juri where dava_id = p_dava and user_id = p_eski and oy is null) then return null; end if;
  select * into d from oyun.adliye_davalar where id = p_dava;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  -- 20.11.2026 öncesinde kurulmuş heyetlerin yedek listesi (yeni heyetlerde yedek tutulmaz)
  select yy.user_id into yeni from oyun.adliye_juri_yedek yy join oyun.profiller pr on pr.id = yy.user_id
   where yy.dava_id = p_dava and not yy.kullanildi and oyun.juri_aday_uygun(d, yy.user_id, t)
     and not exists(select 1 from oyun.adliye_juri j where j.dava_id = p_dava and j.user_id = yy.user_id)
   order by (pr.son_gorulme > t - interval '24 hours') desc, yy.sira limit 1;
  if yeni is not null then
    update oyun.adliye_juri_yedek set kullanildi = true where dava_id = p_dava and user_id = yeni;
  else
    yeni := (oyun.juri_cek(d, t, 1))[1];
  end if;
  if yeni is null then return null; end if;
  v_yon := coalesce((select yonetici from oyun.profiller where id = p_eski), false)
           or exists (select 1 from oyun.moderatorler where user_id = p_eski);
  insert into oyun.juri_ihmal(user_id, dava_id, zaman) values (p_eski, p_dava, t) on conflict do nothing;
  perform oyun.istinaf_ihmal_kaydet(p_eski, p_dava, t, p_neden);
  perform oyun.bildir(p_eski, case when v_yon
      then format('Adliye #%s İstinaf Dairesinde %s; görev başka üyeye geçti. 48 saat boyunca yeni istinaf dosyası verilmeyecek; durum yönetim kaydına işlendi.', p_dava, p_neden)
      else format('Adliye #%s İstinaf Dairesinde %s; yerine başka üye geçti. 14 gün boyunca yeniden görevlendirilmeyeceksin.', p_dava, p_neden) end, t);
  update oyun.adliye_juri set user_id = yeni, atama = t, gerekce = null where dava_id = p_dava and user_id = p_eski and oy is null;
  kalan := greatest(1, ceil(extract(epoch from (coalesce(i.bit, t + interval '24 hours') - t)) / 3600))::int;
  perform oyun.bildir(yeni, format('⚖️ İSTİNAF GÖREVİ: Adliye #%s dosyasında İstinaf Dairesi üyesi olarak görevlendirildin (%s). Oylamanın bitmesine yaklaşık %s saat var; birkaç saat içinde Adliye › Dosya #%s ekranından kararı onayla ya da boz. Üyeliğin gizlidir; bu görevi kimseyle paylaşma.', p_dava, oyun.dava_taraf_metni(d), kalan, p_dava), t);
  return yeni;
end $function$;

-- ---------- Oy: yönetici üyeye kıdem yok, oy yönetim kaydına işlenir ----------
create or replace function public.adliye_juri_oy(p_dava bigint, p_oy text, p_gerekce text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.adliye_istinaf; ek numeric := 0; v_yon boolean;
begin
  if p_oy not in ('onay', 'boz') then raise exception 'Onayla ya da boz.'; end if;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  if i.dava_id is null or i.durum <> 'acik' or t >= i.bit then raise exception 'Bu istinaf oylaması açık değil.'; end if;
  update oyun.adliye_juri set oy = p_oy, gerekce = nullif(left(trim(coalesce(p_gerekce, '')), 800), ''), zaman = t
   where dava_id = p_dava and user_id = p.id and oy is null;
  if not found then raise exception 'Bu dosyanın İstinaf Dairesinde değilsin ya da oyunu zaten verdin.'; end if;
  v_yon := coalesce(p.yonetici, false) or exists (select 1 from oyun.moderatorler where user_id = p.id);
  if v_yon then
    insert into oyun.mod_kayit(zaman, user_id, kad, islem, hedef, ayrinti)
    values (t, p.id, p.kad, 'istinaf_oy', 'Adliye #' || p_dava, case p_oy when 'boz' then 'bozma oyu' else 'onama oyu' end);
  else
    ek := oyun.kidem_ekle(p.id, 'juri_oy');
  end if;
  perform oyun.adliye_istinaf_sonuc(p_dava, t);
  return jsonb_build_object('tamam', true, 'kidem', ek);
end $function$;

-- ---------- Yerinde yamalar: uzun işlevlerde yalnız ilgili ifadeler değişir ----------
do $yama$
declare s text;
begin
  -- Karar: bozma haberi üyenin Kürsü hesabından paylaşılmaz; metinlerde "jüri" yerine "İstinaf Dairesi"
  s := pg_get_functiondef('oyun.adliye_istinaf_sonuc(bigint, timestamp with time zone)'::regprocedure);
  s := replace(s, '(select user_id from oyun.adliye_juri where dava_id = p_dava and oy = ''boz'' order by zaman limit 1)', 'null::uuid');
  if position('istinaf_ihmal_kaydet' in s) = 0 then
    s := replace(s, 'insert into oyun.juri_ihmal(user_id, dava_id, zaman) values (r.user_id, p_dava, t) on conflict do nothing;',
                    'insert into oyun.juri_ihmal(user_id, dava_id, zaman) values (r.user_id, p_dava, t) on conflict do nothing; perform oyun.istinaf_ihmal_kaydet(r.user_id, p_dava, t, ''ek süre dahil oy kullanmadı'');');
  end if;
  s := replace(s, ' 14 gün boyunca jüriye seçilmeyeceksin.', ' Görev ihmali kayda geçti.');
  s := replace(s, 'istinaf jürisinde', 'İstinaf Dairesinde');
  s := replace(s, 'İstinaf jürisi', 'İstinaf Dairesi');
  s := replace(s, 'istinaf jürisi', 'İstinaf Dairesi');
  execute s;

  -- Bozma sonrası iade gerekçeleri
  s := pg_get_functiondef('oyun.adliye_iade_sonuc(bigint, timestamp with time zone)'::regprocedure);
  s := replace(s, 'İstinaf jürisi', 'İstinaf Dairesi');
  execute s;

  -- Başvuru: hata ve olay metni
  s := pg_get_functiondef('public.adliye_istinaf(bigint, text)'::regprocedure);
  s := replace(s, 'Şu anda tarafsız jüri oluşturulamadı; daha sonra tekrar dene.', 'Şu anda tarafsız İstinaf Dairesi oluşturulamadı; daha sonra tekrar dene.');
  s := replace(s, 'Adliye #%s kararı istinafa taşındı; %s asıl ve %s yedek jüri üyesi kurayla belirlendi.', 'Adliye #%s kararı istinafa taşındı; dosya %s üyeli İstinaf Dairesine verildi.');
  execute s;

  -- Dosya: üyelerin adı gizli ("Üye 1…"); yalnız kurucu adları görür
  s := pg_get_functiondef('public.adliye_dava_ek(bigint)'::regprocedure);
  s := replace(s,
    '(select jsonb_agg(jsonb_build_object(''kad'', oyun.kad(j.user_id), ''oy'', j.oy, ''gerekce'', j.gerekce)) from oyun.adliye_juri j where j.dava_id = d.id) end,',
    '(select jsonb_agg(jsonb_build_object(''kad'', case when coalesce(p.yonetici, false) then ''Üye '' || q.sn || '' · '' || oyun.kad(q.user_id) else ''Üye '' || q.sn end, ''oy'', q.oy, ''gerekce'', q.gerekce) order by q.sn) from (select j.user_id, j.oy, j.gerekce, row_number() over (order by md5(j.dava_id::text || j.user_id::text)) sn from oyun.adliye_juri j where j.dava_id = d.id) q) end, ''heyet_gizli'', true,');
  execute s;

  -- Bekleyen işler kartı
  s := pg_get_functiondef('public.bekleyen_islerim()'::regprocedure);
  s := replace(s, '⚖️ Jüri görevi: Adliye #%s istinafı', '⚖️ İstinaf Dairesi görevi: Adliye #%s');
  execute s;
end $yama$;

revoke all on function oyun.istinaf_uye_uygun(oyun.adliye_davalar, uuid, timestamp with time zone) from public, anon, authenticated;
revoke all on function oyun.juri_cek_vatandas(oyun.adliye_davalar, timestamp with time zone, integer, uuid[]) from public, anon, authenticated;
revoke all on function oyun.istinaf_ihmal_kaydet(uuid, bigint, timestamp with time zone, text) from public, anon, authenticated;
