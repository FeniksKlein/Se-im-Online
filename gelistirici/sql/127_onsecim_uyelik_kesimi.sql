-- 22 Ekim 2026: "Partim olduğu halde partin yok diyor" şikâyeti.
-- Sorun: ön seçimde oy hakkı için "başvurular açılmadan önce üye olma" şartı, erken
-- seçimde başvurular 17 Ekim'de açıldığı için 17 Ekim'den sonra kurulan/katılınan
-- partilerde kimseyi (kurucu dahil) oy kullandırmıyordu (33 üyeden 27'si dışarıda).
-- Yeni kural (yalnız mv_on, cb_on, bel_on; kurultay aynen kalır):
--   * Oylama başlamadan en az 24 saat önce üye olan oy kullanır; başvurular 24 saatten
--     kısa sürüyorsa eskisi gibi başvurular açılmadan önce üye olmak gerekir.
--   * Bu kesimden sonra kurulmuş yeni partide oylama başlamadan önce üye olan herkes
--     oy kullanır (kurucu kendi partisinin ön seçiminde oy kullanabilsin).
--   * Oylama sırasında partiye girenler o ön seçimde oy kullanamaz (manipülasyon koruması).
-- Mesaj artık kesim saatini ve oyuncunun katılma saatini açıkça yazar.
-- Oyuncu verisine dokunmaz; tekrar çalıştırmak güvenlidir.

create or replace function oyun.tr_tarih_saat(t timestamptz)
returns text language sql immutable set search_path to '' as $$
  select case when t is null then null else
    extract(day from (t at time zone 'Europe/Istanbul'))::int || ' ' ||
    (array['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'])
      [extract(month from (t at time zone 'Europe/Istanbul'))::int] || ' ' ||
    to_char(t at time zone 'Europe/Istanbul', 'HH24:MI') end
$$;

-- Parti içi ön seçimde oy hakkı için en geç üye olunması gereken an.
create or replace function oyun.onsecim_uyelik_kesim(s oyun.secimler, p_parti bigint)
returns timestamptz language sql stable set search_path to '' as $$
  with k as (
    select case when s.tur in ('mv_on','cb_on','bel_on')
                then greatest(coalesce(s.basvuru_bas, s.oy_bas - interval '24 hours'), s.oy_bas - interval '24 hours')
                else s.basvuru_bas end as kesim
  )
  select case
    when s.tur in ('mv_on','cb_on','bel_on')
     and (select pa.kurulus from oyun.partiler pa where pa.id = p_parti) > k.kesim
    then s.oy_bas
    else k.kesim end
  from k
$$;

CREATE OR REPLACE FUNCTION oyun.oy_engeli(p oyun.profiller, s oyun.secimler)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 SELECT coalesce(
  oyun.uyari(p,s.oy_bas),
  CASE WHEN s.tur IN ('mv','cb','cb2','bel') THEN NULL::text ELSE oyun.ilk_uc_gorev_engel(p) END,
  CASE WHEN s.ara AND s.hedef_il_id IS NOT NULL AND p.il_id IS DISTINCT FROM s.hedef_il_id
    THEN format('Bu olağanüstü seçim yalnızca %s ili içindir.',
      (SELECT ad FROM oyun.iller WHERE id=s.hedef_il_id)) END,
  CASE WHEN s.ara AND s.hedef_parti_id IS NOT NULL AND p.parti_id IS DISTINCT FROM s.hedef_parti_id
    THEN format('Bu olağanüstü kurultay yalnızca %s üyeleri içindir.',
      (SELECT kisa FROM oyun.partiler WHERE id=s.hedef_parti_id)) END,
  CASE WHEN s.tur IN ('mv','bel','mv_on','bel_on') AND p.son_il_degis IS NOT NULL
            AND p.il_at > s.oy_bas - make_interval(days=>(SELECT oy_il_gun FROM oyun.ayarlar WHERE id=1))
       THEN format('Seçmen kütüğü: bu ilde en az %s gün kayıtlı olmalısın.',
            (SELECT oy_il_gun FROM oyun.ayarlar WHERE id=1)) END,
  CASE WHEN s.tur IN ('mv_on','bel_on','kurultay','cb_on') THEN
    CASE WHEN p.parti_id IS NULL THEN 'Bu parti içi seçimde oy kullanmak için bir partiye üye olmalısın.'
         WHEN s.donem='2026-11' AND s.tur IN ('mv_on','cb_on') THEN NULL
         WHEN p.parti_at > oyun.onsecim_uyelik_kesim(s, p.parti_id)
         THEN format('%s üyesisin, ancak partiye %s tarihinde katıldın. Bu %s oy kullanabilmek için en geç %s itibarıyla üye olmak gerekiyordu. Bu kural, son anda partiye girip sonucu etkilemeyi önler; sonraki parti içi seçimlerde oy kullanabilirsin.',
              coalesce((SELECT kisa FROM oyun.partiler WHERE id=p.parti_id), 'Partinin'),
              oyun.tr_tarih_saat(p.parti_at),
              CASE WHEN s.tur='kurultay' THEN 'kurultayda' ELSE 'ön seçimde' END,
              oyun.tr_tarih_saat(oyun.onsecim_uyelik_kesim(s, p.parti_id))) END END)
$function$;
