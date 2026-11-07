-- =====================================================================
-- 177 (07.11.2026) Pano ihalesi: kesin tahsil (tam bloke) usulü
--   • Teklif verilirken teklif tutarının TAMAMI cüzdandan / şirket kasasından
--     bloke edilir (pano_ihale_teklif.teminat = bloke edilen tutar).
--   • Zarflar açılınca kazananın bloke tutarı doğrudan Hazine'ye geçer;
--     ek tahsilat yoktur, "ödeyemedi" durumu oluşmaz.
--   • Kaybedenlerin bloke tutarı tamamen iade edilir.
--   • Bu sürümden önce %3 teminatla verilmiş açık teklifler için kapanışta
--     kalan bedel eskisi gibi tahsil edilir (geriye uyumluluk).
-- =====================================================================

alter table oyun.pano_ayar alter column ihale_teminat_oran set default 1;
update oyun.pano_ayar set ihale_teminat_oran = 1 where id = 1;

-- Teminat oranı artık ayarlanamaz (her zaman tam bloke)
do $p$ begin
  if to_regclass('oyun.yp_ayar_katalog') is not null then
    delete from oyun.yp_ayar_katalog where anahtar = 'pano.ihale_teminat_oran';
  end if;
end $p$;

create or replace function public.pano_ihale_teklif_ver(p_ihale bigint, p_tur text, p_id bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); i oyun.pano_ihale; a oyun.pano_ayar; v_tutar numeric := round(coalesce(p_tutar, 0)); ad text;
  tur text := case when p_tur = 'sirket' then 'sirket' else 'oyuncu' end; sid bigint; yas uuid[]; n int;
begin
  select * into a from oyun.pano_ayar where id = 1;
  select * into i from oyun.pano_ihale where id = p_ihale for update;
  if i.id is null then raise exception 'İhale bulunamadı.'; end if;
  if i.durum <> 'acik' or i.bit <= now() then raise exception 'Bu ihalenin teklif süresi doldu.'; end if;
  if v_tutar < i.asgari then raise exception 'En az % ₺ teklif vermelisin (muhammen bedel % ₺).', oyun.pano_tl(i.asgari), oyun.pano_tl(i.muhammen); end if;
  if v_tutar > 1000000000 then raise exception 'Teklif çok yüksek.'; end if;
  if tur = 'sirket' then
    sid := p_id;
    if not oyun.pano_odeme_yetki(p.id, 'sirket', sid) then raise exception 'Bu şirket adına teklif vermek için şirketin yöneticisi ya da çoğunluk ortağı olmalısın.'; end if;
    select s.ad into ad from oyun.sirketler s where s.id = sid and s.aktif;
    if ad is null then raise exception 'Şirket bulunamadı.'; end if;
  else
    sid := null; ad := p.kad;
  end if;
  yas := oyun.pano_ihale_yetkilileri(i.kapsam, i.il_id);
  if p.id = any (yas) then
    raise exception 'İhale yetkilisi bu ihaleye katılamaz (%). Belediye başkanı kendi ilinin, Cumhurbaşkanı ve Ulaştırma Bakanı ülke geneli pano ihalesine teklif veremez.', oyun.pano_idare_ad(i.kapsam, i.il_id);
  end if;
  if tur = 'sirket' and exists (select 1 from oyun.sirketler s where s.id = sid and (s.yonetici = any (yas) or s.kurucu = any (yas)))
     or tur = 'sirket' and exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = sid and o.pay > 0 and o.user_id = any (yas)) then
    raise exception 'Bu şirkette ihale yetkilisinin yönetimi ya da ortaklığı var; şirket bu ihaleye katılamaz.';
  end if;
  select count(*) into n from oyun.pano_isletme z
   where z.durum = 'aktif' and z.bit > now()
     and (z.isletmeci_user = p.id or (z.isletmeci_tur = 'sirket' and z.isletmeci_id in (select s.id from oyun.sirketler s where s.yonetici = p.id or s.kurucu = p.id)));
  if n >= a.ihale_en_fazla then raise exception 'Aynı anda en fazla % pano işletmesi tutabilirsin (tekel sınırı).', a.ihale_en_fazla; end if;
  if exists (select 1 from oyun.pano_ihale_teklif t where t.ihale_id = i.id and t.teklif_tur = tur
              and ((tur = 'sirket' and t.teklif_id = sid) or (tur = 'oyuncu' and t.user_id = p.id))) then
    raise exception 'Bu ihaleye zaten teklif verdin. Kapalı teklif usulünde teklif geri alınamaz ve değiştirilemez.';
  end if;
  -- Kesin tahsil: teklifin tamamı bloke edilir (bakiye yetmezse teklif verilemez)
  begin
    perform oyun.pano_odeme(case when tur = 'oyuncu' then 'oyuncu' else 'kasa' end, tur, sid, p.id, -v_tutar, format('İhale teklifi bloke · pano ihalesi #%s', i.id));
  exception when others then
    raise exception 'Teklifin tamamı (% ₺) teklif anında bloke edilir; % yeterli bakiye yok.', oyun.pano_tl(v_tutar),
      case when tur = 'oyuncu' then 'cüzdanında' else 'şirket kasasında' end;
  end;
  insert into oyun.pano_ihale_teklif (ihale_id, teklif_tur, teklif_id, user_id, teklif_ad, tutar, teminat) values (i.id, tur, sid, p.id, ad, v_tutar, v_tutar);
  return jsonb_build_object('tamam', true, 'teminat', v_tutar, 'bloke', v_tutar, 'bit', i.bit);
end $$;

create or replace function oyun.pano_ihale_kapat(p_ihale bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare i oyun.pano_ihale; t record; k_id bigint; k_tur text; k_tid bigint; k_user uuid; k_ad text; k_tutar numeric; konu text; bas timestamptz; n int; fy jsonb; sayi int := 0; v_kalan numeric;
begin
  select * into i from oyun.pano_ihale where id = p_ihale and durum = 'acik' for update;
  if i.id is null then return; end if;
  konu := case when i.kapsam = 'il' then (select il.ad from oyun.iller il where il.id = i.il_id) || ' il panoları' else 'Ülke geneli dev panolar' end;
  for t in select * from oyun.pano_ihale_teklif where ihale_id = i.id order by tutar desc, zaman asc loop
    sayi := sayi + 1;
    if k_id is null then
      v_kalan := greatest(0, t.tutar - t.teminat);   -- yeni tekliflerde 0 (tamamı bloke)
      begin
        if v_kalan > 0 then
          perform oyun.pano_odeme(case when t.teklif_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, t.teklif_tur, t.teklif_id, t.user_id,
                                  -v_kalan, format('İhale bedeli (teminat düşülmüş) · %s işletme hakkı · ihale #%s', konu, i.id));
        end if;
        k_id := t.id; k_tur := t.teklif_tur; k_tid := t.teklif_id; k_user := t.user_id; k_ad := t.teklif_ad; k_tutar := t.tutar;
        update oyun.pano_ihale_teklif set durum = 'kazandi' where id = t.id;
      exception when others then
        update oyun.pano_ihale_teklif set durum = 'irat' where id = t.id;
        perform oyun.pano_ihale_gelir(i.kapsam, i.il_id, t.teminat, format('Pano ihalesi #%s: bedeli ödenmeyen teklifin teminatı irat kaydedildi', i.id));
        perform oyun.bildir(t.user_id, format('%s ihalesinde en yüksek teklif sizindi ama kalan bedel (%s ₺) ödenemedi. %s ₺ geçici teminat Hazine''ye gelir kaydedildi.',
          konu, oyun.pano_tl(v_kalan), oyun.pano_tl(t.teminat)), oyun.simdi());
      end;
    else
      perform oyun.pano_odeme(case when t.teklif_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, t.teklif_tur, t.teklif_id, t.user_id,
                              t.teminat, format('İhale teklifi iadesi · pano ihalesi #%s', i.id));
      update oyun.pano_ihale_teklif set durum = 'kaybetti' where id = t.id;
    end if;
  end loop;
  if sayi = 0 then update oyun.pano_ihale set durum = 'teklifsiz' where id = i.id; return; end if;
  if k_id is null then update oyun.pano_ihale set durum = 'bozuldu' where id = i.id; return; end if;

  perform oyun.pano_ihale_gelir(i.kapsam, i.il_id, k_tutar, format('Pano işletme hakkı ihale bedeli · %s · ihale #%s · %s', konu, i.id, k_ad));
  n := i.slot;
  bas := greatest(now(), coalesce((select max(z.bit) from oyun.pano_isletme z where z.durum = 'aktif' and z.kapsam = i.kapsam
                                    and z.il_id is not distinct from i.il_id and z.bit > now()), now()));
  fy := oyun.pano_fiyat(i.kapsam, i.il_id);
  insert into oyun.pano_isletme (ihale_id, kapsam, il_id, slot, isletmeci_tur, isletmeci_id, isletmeci_user, isletmeci_ad, bedel, bas, bit, fiyatlar)
  values (i.id, i.kapsam, i.il_id, n, k_tur, k_tid, k_user, k_ad, k_tutar,
          bas, bas + make_interval(days => i.isletme_gun),
          (select jsonb_agg(coalesce((fy ->> 'devlet_gunluk')::numeric, (fy ->> 'gunluk')::numeric, 1000)) from generate_series(1, n)));
  update oyun.pano_ihale set durum = 'sonuclandi', kazanan_teklif = k_id, bedel = k_tutar where id = i.id;
  perform oyun.bildir(k_user, format('Tebrikler! %s işletme hakkı ihalesini %s ₺ ile kazandın (%s teklif). Bloke edilen bedel Hazine''ye aktarıldı. İşletme %s – %s. Pano fiyatlarını Reklam Panoları → İşletmelerim bölümünden belirle.',
    konu, oyun.pano_tl(k_tutar), sayi, to_char(bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'),
    to_char((bas + make_interval(days => i.isletme_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), oyun.simdi());
  for t in select * from oyun.pano_ihale_teklif where ihale_id = i.id and durum = 'kaybetti' loop
    perform oyun.bildir(t.user_id, format('%s ihalesini kazanamadın. Kazanan teklif: %s ₺ (%s). Bloke edilen %s ₺ hesabına iade edildi.',
      konu, oyun.pano_tl(k_tutar), k_ad, oyun.pano_tl(t.teminat)), oyun.simdi());
  end loop;
end $$;

revoke all on function oyun.pano_ihale_kapat(bigint) from public, anon, authenticated;
