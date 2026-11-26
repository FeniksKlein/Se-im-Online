-- 27.11.2026 · Genel Başkan ataması: başka ilde yaşayan üyeyi milletvekili adayı gösterme (sürüm 2026.11.27-2)
-- Soru (Ercan): "Atamayla milletvekili adayı olursa genel başkan İstanbul'da yaşayan birini Kilis'ten aday yapabilir mi, yoksa ekle yapabilmeli."
-- Gerçek usul: milletvekili adaylığında ikamet şartı yoktur; partiler bütün seçim çevrelerinde aday gösterir ve merkez
-- yoklamasıyla başka ilden aday koyabilir. Tek sınır: bir kişi aynı seçimde yalnız BİR seçim çevresinden aday olabilir.
-- Değişiklik (yalnız milletvekili; belediye başkanlığı eskisi gibi o ilde kayıtlı üye):
--   • parti_aday_ata('mv', il, ...) partinin herhangi bir ilde kayıtlı üyesini kabul eder. Kişi başka bir ilin listesindeyse
--     (atama_sira) önce oradan çıkarılması istenir. Kendi ilinde aday adayı başvurusu varsa adaylığı yeni ile taşınır;
--     listeden çıkarılırsa başvurusu kendi iline geri döner.
--   • parti_aday_il: o ilin listesine alınmış dış ildeki üyeleri de gösterir ('dis_il', 'yasadigi_il').
--   • Yeni parti_aday_uye_ara(p_ara): Genel Başkana partinin bütün üyelerinde arama (ad soyad / kullanıcı adı).
--   • aday_vitrini_il: başka ilde yaşayan adayın yanında 'yasadigi_il'.
-- Eski uygulama: parti_aday_ata imzası değişmedi; eski ekran yine yalnız o ildeki üyeleri listeler.

create or replace function public.parti_aday_ata(p_tur text, p_il integer, p_kadlar text[])
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler;
  il oyun.iller; lim int; i int := 0; nick text; h oyun.profiller; secilen uuid[] := '{}'; mevcut oyun.adaylar; diger text;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_tur not in ('mv','bel') then raise exception 'Geçersiz seçim türü.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.id is null or pa.kapali then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id then raise exception 'Adayları yalnız Genel Başkan atayabilir.'; end if;
  if pa.kurulus_bit is not null then raise exception 'Partin henüz kuruluş aşamasında; kuruluş tamamlanmadan aday gösteremez.'; end if;
  if oyun.parti_yontem(pa.id, p_tur) <> 'atama' then
    raise exception 'Partin bu seçimde adaylarını ön seçimle belirliyor. Atama için önce yöntemi "Genel Başkan ataması" yap (adaylık süreci başlamadan önce).'; end if;
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  s := oyun.aday_atama_secim(p_tur, il.id, t);
  if s.id is null then raise exception 'Şu anda aday belirleme dönemi değil. Atama, adaylık başvurusu açıldığı andan ön seçim bitene kadar yapılır.'; end if;
  lim := case when p_tur = 'mv' then coalesce(il.mv_secim, il.mv) else 1 end;
  p_kadlar := coalesce(p_kadlar, '{}');
  if cardinality(p_kadlar) > lim then
    raise exception '% için en çok % aday gösterebilirsin.', il.ad, lim; end if;

  foreach nick in array p_kadlar loop
    nick := btrim(nick);
    continue when nick = '';
    select * into h from oyun.profiller where lower(kad) = lower(nick);
    if h.id is null or h.yasakli then raise exception 'Oyuncu bulunamadı: %', nick; end if;
    if h.parti_id is distinct from pa.id then raise exception '% partinin üyesi değil.', h.kad; end if;
    if p_tur = 'bel' and h.il_id is distinct from il.id then
      raise exception '% bu ilde kayıtlı değil; belediye başkanı adayı yalnız kayıtlı olduğu ilden gösterilir.', h.kad; end if;
    if p_tur = 'bel' and h.id = pa.gb then raise exception 'Genel başkan belediye başkanı adayı olamaz.'; end if;
    if h.id = any(secilen) then raise exception '% listede iki kez yazılmış.', h.kad; end if;
    if oyun.uyari(h, t) is not null then raise exception '%: %', h.kad, oyun.uyari(h, t); end if;
    select * into mevcut from oyun.adaylar where secim_id = s.id and user_id = h.id;
    if mevcut.id is not null and mevcut.parti_id is distinct from pa.id then
      raise exception '% bu seçimde başka bir listeden ya da bağımsız aday adayı.', h.kad; end if;
    if mevcut.id is not null and mevcut.il_id is distinct from il.id and mevcut.atama_sira is not null then
      select ad into diger from oyun.iller where id = mevcut.il_id;
      raise exception '% zaten % listesinde (%. sıra). Bir kişi yalnız bir ilden aday olabilir; önce o listeden çıkar.', h.kad, diger, mevcut.atama_sira; end if;
    secilen := secilen || h.id;
  end loop;

  delete from oyun.adaylar a
   where a.secim_id = s.id and a.parti_id = pa.id and a.il_id = il.id
     and a.atama_ekleme and not (a.user_id = any(secilen));
  -- Listeden çıkarılan, kendi isteğiyle başvurmuş ama başka ilde yaşayan üyenin başvurusu kendi iline döner
  update oyun.adaylar a set il_id = pr.il_id, atama_sira = null
    from oyun.profiller pr
   where pr.id = a.user_id and a.secim_id = s.id and a.parti_id = pa.id and a.il_id = il.id
     and not a.atama_ekleme and not (a.user_id = any(secilen)) and pr.il_id is distinct from il.id and p_tur = 'mv';
  update oyun.adaylar a set atama_sira = null
   where a.secim_id = s.id and a.parti_id = pa.id and a.il_id = il.id and a.atama_sira is not null;

  for i in 1 .. coalesce(cardinality(secilen), 0) loop
    select * into mevcut from oyun.adaylar where secim_id = s.id and user_id = secilen[i];
    select * into h from oyun.profiller where id = secilen[i];
    if mevcut.id is not null then
      update oyun.adaylar set atama_sira = i, il_id = il.id where id = mevcut.id;
      if mevcut.il_id is distinct from il.id then
        perform oyun.bildir(secilen[i], format('Genel Başkan seni %s milletvekili adayı olarak gösterdi (%s. sıra). Adaylığın %s ilinden %s iline taşındı; bir kişi yalnız bir ilden aday olabilir. Liste ön seçim süresi bitince kesinleşir.',
          il.ad, i, coalesce((select ad from oyun.iller where id = mevcut.il_id), '-'), il.ad), t);
      end if;
    else
      insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at, atama_sira, atama_ekleme)
      values (s.id, secilen[i], pa.id, il.id, t, i, true);
      perform oyun.bildir(secilen[i], format('Genel Başkan seni %s %s gösterdi%s%s. Liste ön seçim süresi bitince kesinleşir.',
        il.ad, case when p_tur = 'mv' then 'milletvekili adayı olarak' else 'belediye başkanı adayı olarak' end,
        case when p_tur = 'mv' then format(' (%s. sıra)', i) else '' end,
        case when h.il_id is distinct from il.id then format(' — yaşadığın il %s olsa da milletvekili adaylığında ikamet şartı yoktur', (select ad from oyun.iller where id = h.il_id)) else '' end), t);
    end if;
  end loop;
  return public.parti_aday_il(p_tur, il.id);
end $function$;

create or replace function public.parti_aday_il(p_tur text, p_il integer)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; il oyun.iller;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_tur not in ('mv','bel') then raise exception 'Geçersiz seçim türü.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Bu ekran yalnız Genel Başkana açık.'; end if;
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  s := oyun.aday_atama_secim(p_tur, p_il::smallint, t);
  return jsonb_build_object(
    'il_id', il.id, 'il_ad', il.ad, 'kontenjan', case when p_tur = 'mv' then coalesce(il.mv_secim, il.mv) else 1 end,
    'tur', p_tur, 'yontem', oyun.parti_yontem(pa.id, p_tur), 'dis_il_serbest', p_tur = 'mv',
    'secim', case when s.id is not null then jsonb_build_object('id', s.id, 'basvuru_bit', s.basvuru_bit, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit) end,
    'uyeler', coalesce((
      select jsonb_agg(jsonb_build_object('kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad), 'gb', pr.id = pa.gb,
        'basvurdu', a.id is not null and not a.atama_ekleme, 'atama_sira', a.atama_sira, 'oy', a.oy,
        'dis_il', pr.il_id is distinct from il.id, 'yasadigi_il', (select ad from oyun.iller where id = pr.il_id))
        order by a.atama_sira nulls last, (a.id is not null and not a.atama_ekleme) desc, pr.kad)
      from oyun.profiller pr
      left join oyun.adaylar a on a.secim_id = s.id and a.user_id = pr.id and a.il_id = il.id
      where pr.parti_id = pa.id and not pr.yasakli
        and (pr.il_id = il.id or (a.id is not null and a.parti_id = pa.id))), '[]'::jsonb)
  );
end $function$;

-- Genel Başkan için partinin bütün üyelerinde arama (milletvekili listesine başka ilden aday eklemek için)
create or replace function public.parti_aday_uye_ara(p_ara text)
 returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; q text := btrim(coalesce(p_ara, '')); desen text;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Bu arama yalnız Genel Başkana açık.'; end if;
  if char_length(q) < 2 then return '[]'::jsonb; end if;
  q := left(q, 40);
  desen := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  s := oyun.aday_atama_secim('mv', null::smallint, t);
  if s.id is null then
    select * into s from oyun.secimler where tur = 'mv_on' and durum = 'bekliyor' and not ara order by oy_bit limit 1;
  end if;
  return coalesce((
    select jsonb_agg(z order by z->>'ad') from (
      select jsonb_build_object('kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
        'il_id', pr.il_id, 'il', (select ad from oyun.iller where id = pr.il_id),
        'aday_il_id', a.il_id, 'aday_il', (select ad from oyun.iller where id = a.il_id),
        'atama_sira', a.atama_sira, 'basvurdu', a.id is not null and not a.atama_ekleme,
        'uygun', oyun.uyari(pr, t) is null) z
      from oyun.profiller pr
      left join oyun.adaylar a on a.secim_id = s.id and a.user_id = pr.id
      where pr.parti_id = pa.id and not pr.yasakli and (pr.kad ilike desen or pr.ad_soyad ilike desen)
      limit 20) q2), '[]'::jsonb);
end $function$;

-- Vitrinde başka ilde yaşayan adayın yaşadığı il görünür ('yasadigi_il'); geri kalanı 27.11 sürümüyle aynı.
create or replace function public.aday_vitrini_il(p_il integer, p_donem text default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d text := oyun.alv_donem(p_donem);
  s_on oyun.secimler; s_mv oyun.secimler; il oyun.iller; kesin boolean; asama text;
begin
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  select * into s_on from oyun.secimler where tur = 'mv_on' and donem = d order by id desc limit 1;
  select * into s_mv from oyun.secimler where tur = 'mv' and donem = d order by id desc limit 1;
  kesin := coalesce(s_on.durum = 'tamam', false);
  asama := oyun.alv_asama(s_on, s_mv, t);
  return jsonb_build_object(
    'donem', d, 'asama', asama, 'asama_yazi', oyun.alv_asama_yazi(asama), 'kesin', kesin,
    'il', jsonb_build_object('id', il.id, 'ad', il.ad, 'kontenjan', coalesce(il.mv_secim, il.mv)),
    'benim_ilim', p.il_id = il.id,
    'listeler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'parti', jsonb_build_object('id', pa.id, 'kisa', pa.kisa, 'ad', pa.ad, 'renk', pa.renk, 'amblem', pa.amblem),
        'yontem', oyun.parti_yontem(pa.id, 'mv'),
        'adaylar', (select jsonb_agg(jsonb_build_object(
            'aday_id', a.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
            'sira', case when kesin then a.sira end,
            'oy', case when kesin and oyun.parti_yontem(pa.id, 'mv') = 'onsecim' then coalesce(a.oy, 0) end,
            'vaat', nullif(btrim(coalesce(a.vaat, '')), ''),
            'gb', pa.gb = a.user_id,
            'yasadigi_il', case when pr.il_id is distinct from a.il_id then (select ad from oyun.iller where id = pr.il_id) end,
            'lansman', (select count(*) from oyun.aday_lansman_aday la join oyun.aday_lansman l on l.id = la.lansman_id
                        where la.aday_id = a.id and l.durum = 'planli'),
            'alkis', (select count(*) from oyun.aday_lansman_alkis x join oyun.aday_lansman l on l.id = x.lansman_id
                      where x.aday_id = a.id and l.durum = 'planli'))
            order by case when kesin then a.sira end nulls last, a.basvuru_at, a.id)
          from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
          where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
            and case when kesin then a.sira is not null else not a.atama_ekleme end))
        order by (select count(*) from oyun.adaylar a where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
                    and case when kesin then a.sira is not null else not a.atama_ekleme end) desc, pa.id)
      from oyun.partiler pa
      where not pa.kapali and exists (select 1 from oyun.adaylar a where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
                                        and case when kesin then a.sira is not null else not a.atama_ekleme end)), '[]'::jsonb),
    'bagimsizlar', coalesce((
      select jsonb_agg(jsonb_build_object('aday_id', x.id, 'kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
               'vaat', nullif(btrim(coalesce(x.vaat, '')), '')) order by x.basvuru_at)
      from (select distinct on (a.user_id) a.* from oyun.adaylar a
            where a.secim_id in (s_on.id, s_mv.id) and a.parti_id is null and a.il_id = il.id
            order by a.user_id, (a.secim_id = s_mv.id) desc) x
      join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb),
    'bos_listeli_partiler', coalesce((
      select jsonb_agg(jsonb_build_object('kisa', pa.kisa, 'renk', pa.renk, 'yontem', oyun.parti_yontem(pa.id, 'mv')) order by pa.id)
      from oyun.partiler pa where not pa.kapali
        and not exists (select 1 from oyun.adaylar a where a.secim_id = s_on.id and a.parti_id = pa.id and a.il_id = il.id
                          and case when kesin then a.sira is not null else not a.atama_ekleme end)), '[]'::jsonb),
    'lansmanlar', coalesce((
      select jsonb_agg(oyun.alv_lansman_ozet(la, t) order by la.bas)
      from oyun.aday_lansman la
      where la.donem = d and la.durum = 'planli'
        and (la.il_id = il.id or (la.il_id is null and exists (
              select 1 from oyun.aday_lansman_aday x join oyun.adaylar a on a.id = x.aday_id where x.lansman_id = la.id and a.il_id = il.id)))), '[]'::jsonb));
end $$;

revoke all on function public.parti_aday_uye_ara(text) from public, anon;
grant execute on function public.parti_aday_uye_ara(text) to authenticated;
revoke all on function public.parti_aday_ata(text, integer, text[]), public.parti_aday_il(text, integer), public.aday_vitrini_il(integer, text) from public, anon;
grant execute on function public.parti_aday_ata(text, integer, text[]), public.parti_aday_il(text, integer), public.aday_vitrini_il(integer, text) to authenticated;
