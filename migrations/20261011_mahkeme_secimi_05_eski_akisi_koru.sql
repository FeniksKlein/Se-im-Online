-- Eski 72 saatlik yargıç doldurma ve ayrı koltuk oyları yeni iki kişilik sandıkla çakışmasın.
CREATE OR REPLACE FUNCTION oyun.mahkeme_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare t timestamptz := oyun.simdi(); r record; n int := 0; a oyun.mahkeme_ayar;
begin
  if not pg_try_advisory_xact_lock(424245) then return 0; end if;
  select * into a from oyun.mahkeme_ayar;
  -- 1) görev süresi dolan üyeler
  for r in select * from oyun.mahkeme_uye where user_id is not null and gorev_bit <= t loop
    perform oyun.mahkeme_indir(r.sira, null, 'Görev süresi doldu.', t); n := n + 1;
  end loop;
  -- 2) Meclis koltuğu 72 saattir boşsa en çok oy alan (en az 3 vekil) seçilir
  for r in
    select u.sira, o.aday, count(*) c from oyun.mahkeme_uye u join oyun.mahkeme_meclis_oy o on o.sira = u.sira
     join oyun.makamlar m on m.user_id = o.vekil and m.tur = 'mv' and m.bit is null
     where u.user_id is null and u.kaynak = 'meclis' and u.bos_since <= t - interval '72 hours'
       AND NOT (EXISTS (SELECT 1 FROM oyun.secimler g WHERE g.tur='mv'
           AND (g.oy_bas AT TIME ZONE 'Europe/Istanbul')::date=date '2026-10-12')
         AND NOT EXISTS (SELECT 1 FROM oyun.mahkeme_toplu_secim s WHERE s.durum='bitti'))
     group by u.sira, o.aday having count(*) >= 3 order by u.sira, count(*) desc, min(o.zaman)
  loop
    if exists (select 1 from oyun.mahkeme_uye where sira = r.sira and user_id is null) and oyun.yargic_uygunluk(r.aday) is null then
      perform oyun.mahkeme_oturt(r.sira, r.aday, null, t); n := n + 1;
    end if;
  end loop;
  -- 3) karar süresi: hiç üye yoksa süre işlemez; varsa süresi dolan dava düşer
  for r in select id from oyun.adliye_davalar where durum = 'acik' and karar_son is not null and karar_son <= t loop
    if cardinality(oyun.mahkeme_uyeleri()) = 0 then
      update oyun.adliye_davalar set karar_son = t + make_interval(hours => a.karar_saat) where id = r.id;
    else
      update oyun.adliye_davalar set durum = 'karar', karar = 'dusme', ilk_karar = 'dusme', karar_at = t, kesin = false,
             gerekce = 'Mahkeme süresi içinde karar veremediği için dava zamanaşımından düştü; harç iade edildi.' where id = r.id;
      perform oyun.adliye_kesinlestir(r.id, t);
      perform oyun.olay('adliye', format('Adliye #%s süresinde karara bağlanmadığı için düştü.', r.id), null, null, t);
      n := n + 1;
    end if;
  end loop;
  -- 4) istinaf jürisi süresi
  for r in select dava_id from oyun.adliye_istinaf where durum = 'acik' and bit <= t loop
    perform oyun.adliye_istinaf_sonuc(r.dava_id, t); n := n + 1;
  end loop;
  -- 5) istinafa gidilmeyen kararlar kesinleşir
  for r in select d.id from oyun.adliye_davalar d where d.durum = 'karar' and not d.kesin and d.istinaf_son <= t
              and not exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id) loop
    perform oyun.adliye_kesinlestir(r.id, t); n := n + 1;
  end loop;
  -- 6) görevden alma oylamaları
  for r in select id from oyun.mahkeme_azil where durum = 'acik' and bit <= t loop perform oyun.mahkeme_azil_say(r.id, t); end loop;
  -- 7) AYM: süresinde karar çıkmazsa başvuru düşer (kanun yürürlükte kalır)
  for r in select id from oyun.aym_basvuru where durum = 'acik' and karar_son <= t loop
    if cardinality(oyun.mahkeme_uyeleri()) = 0 then
      update oyun.aym_basvuru set karar_son = t + make_interval(hours => a.karar_saat) where id = r.id;
    else
      update oyun.aym_basvuru set durum = 'dustu', karar_at = t, karar_gerekce = 'Süresinde karar çıkmadığı için başvuru düştü; kanun yürürlükte.' where id = r.id;
    end if;
  end loop;
  return n;
end $function$;
CREATE OR REPLACE FUNCTION public.mahkeme_meclis_oy(p_sira integer, p_kad text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.profiller; engel text; n int;
begin
  IF EXISTS (SELECT 1 FROM oyun.secimler g WHERE g.tur='mv'
       AND (g.oy_bas AT TIME ZONE 'Europe/Istanbul')::date=date '2026-10-12')
    AND NOT EXISTS (SELECT 1 FROM oyun.mahkeme_toplu_secim s WHERE s.durum='bitti')
  THEN RAISE EXCEPTION '13 Ekim yüksek mahkeme seçimi için Adliye içindeki iki üyelik sandığını bekleyin.'; END IF;
  if p_sira not in (2,3) then raise exception 'Meclis yalnız 2. ve 3. üyeyi seçer.'; end if;
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null) then raise exception 'Yalnız milletvekilleri oy verebilir.'; end if;
  if exists (select 1 from oyun.mahkeme_uye where sira = p_sira and user_id is not null) then raise exception 'Bu koltuk dolu.'; end if;
  select * into u from oyun.profiller where lower(kad) = lower(trim(coalesce(p_kad, ''))) and not yasakli;
  if u.id is null then raise exception 'Aday bulunamadı.'; end if;
  engel := oyun.yargic_uygunluk(u.id);
  if engel is not null then raise exception '%', engel; end if;
  insert into oyun.mahkeme_meclis_oy(sira, vekil, aday, zaman) values (p_sira, p.id, u.id, t)
  on conflict (sira, vekil) do update set aday = excluded.aday, zaman = excluded.zaman;
  select count(*) into n from oyun.mahkeme_meclis_oy where sira = p_sira and aday = u.id
     and exists (select 1 from oyun.makamlar m where m.user_id = vekil and m.tur = 'mv' and m.bit is null);
  if n >= oyun.salt_cogunluk() then perform oyun.mahkeme_oturt(p_sira::smallint, u.id, null, t); end if;
  return jsonb_build_object('tamam', true, 'oy', n, 'gerekli', oyun.salt_cogunluk(), 'secildi', n >= oyun.salt_cogunluk());
end $function$;
