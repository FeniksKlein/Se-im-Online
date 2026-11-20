-- Canlıya 20.11.2026'da Supabase migration'ı olarak uygulandı: istinaf_kura_yalniz_moderator_20261120
-- Kaynak: gelistirici/sql/zz_20261120_istinaf_kura.sql · tekrar çalıştırmak güvenlidir.
begin;
set local lock_timeout = '5s';

-- 20.11.2026 (2) · İSTİNAF DAİRESİ: YALNIZ MODERATÖR EKİBİ, HER DOSYADA KURA (Ercan'ın kararı)
-- Sabahki düzen (zz_20261120_istinaf_dairesi.sql): önce son 24 saatte oyunda olan ve yükü en az olan yöneticiler,
-- yetmezse kurucu, o da yoksa son çare vatandaş kurası.
-- Ercan'ın kararı: istinaf üyeleri SADECE moderatör ekibinden, RASTGELE atansın; her dosyada rastgele kişiler.
-- Yeni kural:
--   1) Havuz yalnız oyun.moderatorler. Kurucu ve vatandaş kurası yok (oyun.juri_cek_vatandas artık çağrılmaz).
--   2) Seçim tamamen kura: uygun moderatörler arasından random(); "önce aktif olan / yükü az olan" sıralaması yok.
--      Uygunluk (sıra değil, eleme): tarafsızlık + gizlilik sözleşmesi + son 72 saatte oyunda görülmüş +
--      üzerinde 6'dan az açık istinaf dosyası + son 48 saatte istinaf görevini ihmal etmemiş.
--   3) Böyle 3 kişi çıkmazsa eksik koltuklar YİNE moderatör ekibinden, yalnız tarafsızlık aranarak kurayla tamamlanır.
--      Tarafsızlık hiçbir aşamada gevşemez (taraf, vekil, ilk derece üyesi, taraf partisi üyesi, ortak cihaz, dava, ortaklık).
--   4) Tarafsız moderatör sayısı 2 ise daire 2 üyeyle kurulur (bozma için ikisinin de bozma oyu gerekir) ve kurucuya
--      bildirim gider. 2'den azsa daire kurulmaz; başvuran "daha sonra dene" uyarısı alır (tek üyeli daire kararı
--      bozamayacağı için kurulmaz).
--   5) Üye değişiminde de aynı kura; eski yedek listesi kullanılmaz.
-- Oyuncu verisi değişmez. Tekrar çalıştırmak güvenlidir.

-- ---------- Tarafsızlık (hiçbir aşamada gevşemez) ----------
create or replace function oyun.istinaf_tarafsiz(d oyun.adliye_davalar, u uuid)
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
$function$;

create or replace function oyun.istinaf_uye_uygun(d oyun.adliye_davalar, u uuid, t timestamp with time zone)
 returns boolean
 language sql
 stable
 set search_path to ''
as $function$
  select oyun.istinaf_tarafsiz(d, u)
    and not exists (select 1 from oyun.juri_ihmal i where i.user_id = u and i.zaman > t - interval '48 hours')
$function$;

-- ---------- Kura: yalnız moderatör ekibi ----------
create or replace function oyun.juri_cek(d oyun.adliye_davalar, t timestamp with time zone, p_n integer)
 returns uuid[]
 language plpgsql
 set search_path to ''
as $function$
declare secilen uuid[]; ek uuid[]; eksik int;
begin
  -- 1) Uygun moderatörler arasından tamamen rastgele
  select coalesce(array_agg(q.id order by q.rnd), '{}'::uuid[]) into secilen
  from (
    select m.user_id id, random() rnd
    from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id
    where m.sozlesme_at is not null
      and pr.son_gorulme > t - interval '72 hours'
      and not exists (select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = m.user_id)
      and (select count(*) from oyun.adliye_juri j join oyun.adliye_istinaf s on s.dava_id = j.dava_id
            where j.user_id = m.user_id and s.durum = 'acik' and j.oy is null) < 6
      and oyun.istinaf_uye_uygun(d, m.user_id, t)
    order by 2 limit greatest(p_n, 0)
  ) q;
  eksik := p_n - cardinality(secilen);
  if eksik > 0 then
    -- 2) Eksik koltuk: yine yalnız moderatör ekibi; tarafsızlık aynen, diğer şartlar aranmaz
    select coalesce(array_agg(q.id order by q.rnd), '{}'::uuid[]) into ek
    from (
      select m.user_id id, random() rnd
      from oyun.moderatorler m
      where not (m.user_id = any(secilen))
        and not exists (select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = m.user_id)
        and oyun.istinaf_tarafsiz(d, m.user_id)
      order by 2 limit eksik
    ) q;
    secilen := secilen || ek;
  end if;
  return secilen;
end $function$;

-- ---------- Dairenin kurulması: en az 2 tarafsız moderatör ----------
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
  -- tek üyeli daire kararı bozamaz; kurulmaz
  if cardinality(secilen) < 2 then return 0; end if;
  taraf := oyun.dava_taraf_metni(d);
  foreach u in array secilen loop
    insert into oyun.adliye_juri(dava_id, user_id, atama) values (d.id, u, t) on conflict do nothing;
    asil := asil + 1;
    perform oyun.bildir(u, format('⚖️ İSTİNAF GÖREVİ: Adliye #%s dosyasında kurayla İstinaf Dairesi üyesi seçildin (%s). 24 saat içinde Adliye › Dosya #%s ekranından kararı onayla ya da boz. Üyeliğin gizlidir: adın hiçbir oyuncuya gösterilmez; sen de bu görevi kimseyle paylaşma. 8 saat oyuna girmezsen ya da 12 saat içinde oy vermezsen görev kurayla başka üyeye geçer.', d.id, taraf, d.id), t);
  end loop;
  if asil < 3 then
    perform oyun.mod_kurucu_bildir(format('İstinaf Dairesi: Adliye #%s dosyasında tarafsız yalnız %s moderatör bulunabildi; daire %s üyeyle kuruldu. Bozma için iki üyenin de bozma oyu gerekir. Taraf partilere üye olmayan moderatör sayısı azaldıysa ekibi gözden geçir.', d.id, asil, asil), t);
  end if;
  return asil;
end $function$;

-- ---------- Üye değişimi: aynı kura, yalnız moderatör ekibi ----------
create or replace function oyun.juri_degistir(p_dava bigint, p_eski uuid, t timestamp with time zone, p_neden text)
 returns uuid
 language plpgsql
 set search_path to ''
as $function$
declare d oyun.adliye_davalar; i oyun.adliye_istinaf; yeni uuid; kalan int;
begin
  if not exists(select 1 from oyun.adliye_juri where dava_id = p_dava and user_id = p_eski and oy is null) then return null; end if;
  select * into d from oyun.adliye_davalar where id = p_dava;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  yeni := (oyun.juri_cek(d, t, 1))[1];
  if yeni is null then return null; end if;
  insert into oyun.juri_ihmal(user_id, dava_id, zaman) values (p_eski, p_dava, t) on conflict do nothing;
  perform oyun.istinaf_ihmal_kaydet(p_eski, p_dava, t, p_neden);
  perform oyun.bildir(p_eski, format('Adliye #%s İstinaf Dairesinde %s; görev kurayla başka üyeye geçti. 48 saat boyunca yeni istinaf dosyası verilmeyecek; durum yönetim kaydına işlendi.', p_dava, p_neden), t);
  update oyun.adliye_juri set user_id = yeni, atama = t, gerekce = null where dava_id = p_dava and user_id = p_eski and oy is null;
  kalan := greatest(1, ceil(extract(epoch from (coalesce(i.bit, t + interval '24 hours') - t)) / 3600))::int;
  perform oyun.bildir(yeni, format('⚖️ İSTİNAF GÖREVİ: Adliye #%s dosyasında kurayla İstinaf Dairesi üyesi seçildin (%s). Oylamanın bitmesine yaklaşık %s saat var; birkaç saat içinde Adliye › Dosya #%s ekranından kararı onayla ya da boz. Üyeliğin gizlidir; bu görevi kimseyle paylaşma.', p_dava, oyun.dava_taraf_metni(d), kalan, p_dava), t);
  return yeni;
end $function$;

-- ---------- Daire kurulamazsa başvurana yol göster ----------
do $yama$
declare s text;
begin
  s := pg_get_functiondef('public.adliye_istinaf(bigint, text)'::regprocedure);
  s := replace(s, 'Şu anda tarafsız İstinaf Dairesi oluşturulamadı; daha sonra tekrar dene.',
                  'Şu anda tarafsız İstinaf Dairesi oluşturulamadı; birkaç saat sonra yeniden dene. Süren dolmak üzereyse Ben › Yönetime Yaz ekranından bildir.');
  execute s;
end $yama$;

revoke all on function oyun.istinaf_tarafsiz(oyun.adliye_davalar, uuid) from public, anon, authenticated;

commit;
