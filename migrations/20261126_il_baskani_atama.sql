begin;
-- 26.11.2026 · PARTİ İL BAŞKANI ATAMASI: 81 İLDE, O İLDE YAŞAYAN ÜYELER ARASINDAN (sürüm 2026.11.26-2)
-- Bildirim (Ercan, oyuncu tableti): "Parti il başkanı ata kısmı çalışmıyor. Sadece Ankara il başkanı atayabiliyorsun."
-- İstek: "81 ilde, o illerde yaşayan partili üyelerden il başkanı ataması yapılabilmeli, hemen yayına al."
-- Teşhis: sunucu (teskilat_gorev_ver) her ilde doğru çalışıyordu. Sorun istemcideydi: "Parti İl Başkanı ata"
--   düğmesi (teskilat_kongre.js) yalnız atayan kişinin KENDİ ilinin ekranını açıyordu (MKP Genel Başkanı Ankara'da
--   kayıtlı → yalnız Ankara). Ayrıca alan kullanıcı adı istiyordu; oyunda artık Ad Soyad görünüyor (24.11 kararı),
--   oyuncular kullanıcı adını bilmiyor.
-- Bu dosya:
--   1) public.parti_il_uye_listesi(p_parti, p_il): o ilde KAYITLI parti üyeleri (ad soyad + kullanıcı adı).
--      Yalnız partinin teşkilat yöneticisi (genel başkan / teşkilattan sorumlu GBY) ve o ilin il başkanı görür.
--   2) public.il_gecici_baskan_ata: eski uygulama (mağazadaki 1.0.x) için köprü. Ad soyad da kabul edilir
--      (partide tek eşleşme varsa); yazılan üye başka ilde kayıtlıysa KENDİ İLİNE atanır ve atayana bildirim gider.
--      Yeni uygulama her zaman doğru ili ve kullanıcı adını gönderir; yetki/kural denetimi aynen teskilat_gorev_ver'de.
-- Oyuncu verisi değişmez; yalnız işlev eklenir/yenilenir. Tekrar çalıştırmak güvenlidir.
-- Ekran: gelistirici/www/teskilat_kongre.js.

create or replace function public.parti_il_uye_listesi(p_parti bigint, p_il integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $f$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not (oyun.teskilat_yonetici(u, p_parti)
          or exists(select 1 from oyun.il_baskanlik b where b.parti_id = p_parti and b.il_id = p_il and b.aktif and b.user_id = u))
  then raise exception 'İl üyelerini yalnız genel başkan, teşkilattan sorumlu genel başkan yardımcısı ve il başkanı görür.'; end if;
  return jsonb_build_object('il_id', p_il, 'il', (select ad from oyun.iller where id = p_il),
    'uyeler', coalesce((select jsonb_agg(jsonb_build_object(
        'kad', p.kad, 'ad', coalesce(nullif(btrim(p.ad_soyad), ''), p.kad),
        'yasakli', coalesce(p.yasakli, false),
        'il_baskani', exists(select 1 from oyun.il_baskanlik b where b.parti_id = p_parti and b.il_id = p_il and b.aktif and b.user_id = p.id))
      order by coalesce(nullif(btrim(p.ad_soyad), ''), p.kad) collate "tr-TR-x-icu")
      from (select * from oyun.profiller where parti_id = p_parti and il_id = p_il::smallint limit 1000) p), '[]'::jsonb));
end $f$;

create or replace function public.il_gecici_baskan_ata(p_il integer, p_kad text)
returns jsonb language plpgsql security definer set search_path = '' as $f$
declare u uuid := auth.uid(); ben oyun.profiller; h oyun.profiller; n int; il int := p_il; r jsonb;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into ben from oyun.profiller where id = u;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if h.id is null and ben.parti_id is not null then
    -- Oyunda Ad Soyad görünüyor: partide tek eşleşme varsa ad soyadla da bulunur
    select count(*) into n from oyun.profiller where parti_id = ben.parti_id and lower(btrim(ad_soyad)) = lower(btrim(coalesce(p_kad, '')));
    if n = 1 then select * into h from oyun.profiller where parti_id = ben.parti_id and lower(btrim(ad_soyad)) = lower(btrim(coalesce(p_kad, ''))); end if;
    if n > 1 then raise exception 'Bu ad soyadla partinde birden çok üye var; kullanıcı adını yaz.'; end if;
  end if;
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  -- Eski uygulama yalnız atayanın kendi ilini açıyordu: üye başka ilde kayıtlıysa kendi iline atanır
  if h.parti_id is not distinct from ben.parti_id and h.il_id is not null and h.il_id <> p_il then il := h.il_id; end if;
  r := public.teskilat_gorev_ver(il, h.kad);
  if il <> p_il then
    perform oyun.bildir(u, format('%s, kayıtlı olduğu %s ilinin geçici Parti İl Başkanı olarak görevlendirildi.',
      coalesce(nullif(btrim(h.ad_soyad), ''), h.kad), (select ad from oyun.iller where id = il)), oyun.simdi());
  end if;
  return r || jsonb_build_object('il_id', il, 'il_detay', public.il_teskilat_detay(ben.parti_id, il));
end $f$;

revoke all on function public.parti_il_uye_listesi(bigint, integer), public.il_gecici_baskan_ata(integer, text) from public, anon;
grant execute on function public.parti_il_uye_listesi(bigint, integer), public.il_gecici_baskan_ata(integer, text) to authenticated;
commit;
