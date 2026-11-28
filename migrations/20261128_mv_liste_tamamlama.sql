-- 28.11.2026 — Milletvekili listesi tamamlama (ön seçim / Genel Başkan ataması sonrası)
-- İstek (Ercan): "CYP ön seçim yaptı ama yeteri kadar kişi aday olmadı; yüksek oya rağmen az vekil gidecek.
--   Ön seçim olsa dahi ya da aday yetersizse, ön seçim sonrası sıralamalar belli olduktan sonra kalan sıralara
--   parti üyelerini genel başkan veya örgütten sorumlu GBY aday olarak atayabilmeli."
-- Kurallar:
--   • Dönem: mv_on sonuçlandıktan (durum tamam/sonuclandi) sonra, aynı dönemin genel seçim (mv) oylaması başlayana kadar.
--   • Yetki: Genel Başkan, Genel Başkan Vekili ya da 'secim' veya 'teskilat' yetkili GBY (oyun.liste_tamamlama_yetkili).
--   • Ön seçimle/atamayla kesinleşen sıralar (sira, tamamlama=false) değişmez; eklenenler onların arkasına (max(sira)+n).
--   • Kontenjan: ilin sandalye sayısı. Kişi tek ilden aday; bağımsız / CB adayı / CB aday adayı eklenemez.
--   • Rızasız görev düşmesin diye belediye başkanı, vali, il teşkilatı görevlisi, oda/baro/sendika başkanı, hâkim eklenemez.
--   • Eklenen üyeye bildirim; oylama başlayana kadar adaylik_geri_cek ile çekilebilir (mv_on ya da mv kimliğiyle).
--   • Mağazadaki eski uygulama il ekranını yalnız mv='atama' iken gösterdiği için panel tamamlama döneminde yetkiliye
--     mv='atama' döndürür (gerçek yöntem gercek_mv); yöntem ayarı bu dönemde mv değişikliğini kabul etmez.
-- Canlı migration'lar: mv_liste_tamamlama_altyapi, _ata_ara_panel, _geri_cekilme, _panel_ara_oncelik,
--   _yetki_null_duzeltme, _eski_istemci_uyum (28.11.2026).

alter table oyun.adaylar add column if not exists tamamlama boolean not null default false;

create or replace function oyun.mv_tamamlama_secim(p_il smallint, t timestamptz)
returns oyun.secimler language sql stable set search_path to '' as $$
  select o.* from oyun.secimler o
  join oyun.secimler m on m.donem = o.donem and m.tur = 'mv' and m.durum = 'bekliyor' and t < m.oy_bas
  where o.tur = 'mv_on' and o.durum in ('tamam','sonuclandi')
    and (not o.ara or o.hedef_il_id = p_il
         or (o.ara_neden = 'erken_secim' and o.hedef_parti_id is null and o.hedef_il_id is null))
  order by m.oy_bas, o.id desc limit 1
$$;

create or replace function oyun.mv_tamamlama_son(o oyun.secimler)
returns timestamptz language sql stable set search_path to '' as $$
  select min(m.oy_bas) from oyun.secimler m where m.donem = o.donem and m.tur = 'mv' and m.durum = 'bekliyor'
$$;

create or replace function oyun.liste_tamamlama_yetkili(u uuid, pa oyun.partiler)
returns boolean language sql stable set search_path to '' as $$
  select coalesce(u is not null and pa.id is not null and not coalesce(pa.kapali,false) and (
    pa.gb is not distinct from u or (pa.gb_vekil is not null and pa.gb_vekil = u)
    or oyun.gby_yetkili(u, pa.id, 'secim') or oyun.gby_yetkili(u, pa.id, 'teskilat')), false)
$$;

create or replace function oyun.tamamlama_engeli(u uuid)
returns text language sql stable set search_path to '' as $$
  select coalesce(
    case when exists(select 1 from oyun.makamlar m where m.user_id=u and m.tur='bel' and m.bit is null) then 'belediye başkanı' end,
    case when exists(select 1 from oyun.icisleri_atama a where a.hedef=u and a.tur='vali' and a.durum='aktif' and a.bitis is null) then 'vali' end,
    case when exists(select 1 from oyun.parti_teskilat_gorev g where g.user_id=u and g.aktif) then 'parti il teşkilatı görevlisi' end,
    case when exists(select 1 from oyun.oda o where o.baskan=u) then 'oda başkanı' end,
    case when exists(select 1 from oyun.baro b where b.baskan=u) then 'baro başkanı' end,
    case when exists(select 1 from oyun.sendika s where s.baskan=u) then 'sendika başkanı' end,
    case when exists(select 1 from oyun.adliye_makam h where h.hakim=u) then 'hâkim' end)
$$;

create or replace function oyun._liste_tamamla_il(p_il integer)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; il oyun.iller;
  son timestamptz; lim int; dolu int; kilitli int;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  if not oyun.liste_tamamlama_yetkili(p.id, pa) then
    raise exception 'Liste tamamlamayı yalnız Genel Başkan ya da seçim veya teşkilat yetkili Genel Başkan Yardımcısı yapabilir.'; end if;
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  s := oyun.mv_tamamlama_secim(il.id, t);
  if s.id is null then raise exception 'Şu anda liste tamamlama dönemi değil.'; end if;
  son := oyun.mv_tamamlama_son(s);
  lim := coalesce(il.mv_secim, il.mv);
  select count(*) filter (where sira is not null), count(*) filter (where sira is not null and not tamamlama)
    into dolu, kilitli from oyun.adaylar where secim_id = s.id and parti_id = pa.id and il_id = il.id;
  return jsonb_build_object(
    'il_id', il.id, 'il_ad', il.ad, 'kontenjan', lim, 'tur', 'mv',
    'yontem', 'atama', 'gercek_yontem', oyun.parti_yontem(pa.id, 'mv'),
    'tamamlama', true, 'kilitli_sayi', kilitli, 'dolu', dolu, 'bos', greatest(lim - dolu, 0),
    'dis_il_serbest', true,
    'aciklama', format('Ön seçim/aday belirleme sonrası liste tamamlama: %s listesinde %s sıra dolu, %s boş. Ön seçimle kesinleşen sıralar değiştirilemez; boş sıralara parti üyeleri eklenir. Son: %s.',
                       il.ad, dolu, greatest(lim - dolu, 0), oyun.tr_tarih_saat(son)),
    'secim', jsonb_build_object('id', s.id, 'basvuru_bit', son, 'oy_bas', son, 'oy_bit', son, 'son', son, 'tamamlama', true),
    'uyeler', coalesce((
      select jsonb_agg(jsonb_build_object('kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad), 'gb', pr.id = pa.gb,
        'basvurdu', a.id is not null and a.sira is not null and not a.tamamlama,
        'kilitli', a.id is not null and a.sira is not null and not a.tamamlama,
        'tamamlama', coalesce(a.tamamlama, false),
        'atama_sira', a.sira, 'oy', a.oy,
        'dis_il', pr.il_id is distinct from il.id, 'yasadigi_il', (select ad from oyun.iller where id = pr.il_id),
        'engel', case when a.sira is not null then null
                      else coalesce(oyun.tamamlama_engeli(pr.id), oyun.uyari(pr, t),
                        (select 'zaten ' || i2.ad || ' listesinde' from oyun.adaylar b join oyun.iller i2 on i2.id = b.il_id
                          where b.secim_id = s.id and b.user_id = pr.id and b.il_id <> il.id and b.sira is not null limit 1)) end)
        order by a.sira nulls last, pr.kad)
      from oyun.profiller pr
      left join oyun.adaylar a on a.secim_id = s.id and a.user_id = pr.id and a.il_id = il.id and a.parti_id = pa.id
      where pr.parti_id = pa.id and not pr.yasakli
        and (pr.il_id = il.id or a.id is not null)), '[]'::jsonb));
end $$;

create or replace function oyun._liste_tamamla_ata(p_il integer, p_kadlar text[])
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; il oyun.iller;
  son timestamptz; lim int; kilitli int; maxs int; nick text; h oyun.profiller; mevcut oyun.adaylar; secilen uuid[] := '{}';
  e text; diger text; i int; eski oyun.adaylar; unvan text; yeni int := 0;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.id is null or pa.kapali then raise exception 'Bir partiye üye değilsin.'; end if;
  if not oyun.liste_tamamlama_yetkili(p.id, pa) then
    raise exception 'Liste tamamlamayı yalnız Genel Başkan ya da seçim veya teşkilat yetkili Genel Başkan Yardımcısı yapabilir.'; end if;
  if pa.kurulus_bit is not null then raise exception 'Partin henüz kuruluş aşamasında.'; end if;
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  s := oyun.mv_tamamlama_secim(il.id, t);
  if s.id is null then raise exception 'Şu anda liste tamamlama dönemi değil.'; end if;
  son := oyun.mv_tamamlama_son(s);
  lim := coalesce(il.mv_secim, il.mv);
  unvan := case when pa.gb = p.id then 'Genel Başkan' when pa.gb_vekil = p.id then 'Genel Başkan Vekili' else 'Genel Başkan Yardımcısı' end;
  select count(*), coalesce(max(sira), 0) into kilitli, maxs
    from oyun.adaylar where secim_id = s.id and parti_id = pa.id and il_id = il.id and sira is not null and not tamamlama;

  foreach nick in array coalesce(p_kadlar, '{}') loop
    nick := btrim(nick);
    continue when nick = '';
    select * into h from oyun.profiller where lower(kad) = lower(nick);
    if h.id is null or h.yasakli then raise exception 'Oyuncu bulunamadı: %', nick; end if;
    if h.parti_id is distinct from pa.id then raise exception '% partinin üyesi değil.', h.kad; end if;
    select * into mevcut from oyun.adaylar where secim_id = s.id and user_id = h.id;
    if mevcut.id is not null and mevcut.parti_id is distinct from pa.id then
      raise exception '% bu seçimde başka bir listede.', h.kad; end if;
    -- ön seçimle/atamayla kesinleşmiş sıra: dokunulmaz, listede tekrar yazılması sorun değil
    continue when mevcut.id is not null and mevcut.il_id = il.id and mevcut.sira is not null and not mevcut.tamamlama;
    if mevcut.id is not null and mevcut.il_id <> il.id and mevcut.sira is not null then
      select ad into diger from oyun.iller where id = mevcut.il_id;
      raise exception '% zaten % listesinde (%. sıra). Bir kişi yalnız bir ilden aday olabilir.', h.kad, diger, mevcut.sira; end if;
    if exists (select 1 from oyun.adaylar b join oyun.secimler m on m.id = b.secim_id
               where b.user_id = h.id and m.donem = s.donem and m.tur in ('mv','cb','cb_on','cb2')) then
      raise exception '% bu dönemde bağımsız ya da Cumhurbaşkanlığı adayı/aday adayı; milletvekili listesine eklenemez.', h.kad; end if;
    if h.id = any(secilen) then raise exception '% listede iki kez yazılmış.', h.kad; end if;
    e := oyun.tamamlama_engeli(h.id);
    if e is not null then
      raise exception '% şu an % olarak görev yapıyor; adaylık bu görevi sona erdireceği için liste tamamlamayla eklenemez.', h.kad, e; end if;
    e := oyun.uyari(h, t);
    if e is not null then raise exception '%: %', h.kad, e; end if;
    secilen := secilen || h.id;
  end loop;

  if kilitli + cardinality(secilen) > lim then
    raise exception '% listesinde % sıra kesinleşmiş; kontenjan %. En çok % kişi ekleyebilirsin.', il.ad, kilitli, lim, greatest(lim - kilitli, 0); end if;

  for eski in delete from oyun.adaylar
     where secim_id = s.id and parti_id = pa.id and il_id = il.id and tamamlama and not (user_id = any(secilen)) returning * loop
    perform oyun.bildir(eski.user_id, format('%s milletvekili aday listesinden (liste tamamlaması) çıkarıldın.', il.ad), t);
  end loop;

  for i in 1 .. coalesce(cardinality(secilen), 0) loop
    select * into mevcut from oyun.adaylar where secim_id = s.id and user_id = secilen[i];
    if mevcut.id is not null then
      update oyun.adaylar set il_id = il.id, sira = maxs + i, tamamlama = true, atama_ekleme = true where id = mevcut.id;
      if not (mevcut.tamamlama and mevcut.il_id = il.id) then yeni := yeni + 1;
        perform oyun.bildir(secilen[i], format('%s seni liste tamamlamasıyla %s milletvekili aday listesine %s. sıradan ekledi. İstemiyorsan genel seçim oylaması başlayana kadar (%s) adaylıktan çekilebilirsin.',
          unvan, il.ad, maxs + i, oyun.tr_tarih_saat(son)), t);
      end if;
    else
      insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at, sira, atama_ekleme, tamamlama)
      values (s.id, secilen[i], pa.id, il.id, t, maxs + i, true, true);
      yeni := yeni + 1;
      perform oyun.bildir(secilen[i], format('%s seni liste tamamlamasıyla %s milletvekili aday listesine %s. sıradan ekledi. İstemiyorsan genel seçim oylaması başlayana kadar (%s) adaylıktan çekilebilirsin.',
        unvan, il.ad, maxs + i, oyun.tr_tarih_saat(son)), t);
    end if;
  end loop;

  if yeni > 0 then
    perform oyun.olay('secim', format('%s, %s milletvekili listesindeki boş sıraları tamamladı (%s yeni aday).', pa.kisa, il.ad, yeni), il.id, pa.id, t);
  end if;
  if pa.gb is distinct from p.id and pa.gb_vekil is distinct from p.id then
    perform oyun.parti_yetki_log(pa.id, p.id, 'secim', 'liste_tamamlama', null,
      format('%s listesi tamamlandı: %s kişi', il.ad, cardinality(secilen)));
    if pa.gb is not null then
      perform oyun.bildir(pa.gb, format('%s %s milletvekili listesini liste tamamlamasıyla düzenledi (%s ek aday).', p.kad, il.ad, cardinality(secilen)), t);
    end if;
  end if;
  return oyun._liste_tamamla_il(p_il);
end $$;

create or replace function public.parti_aday_il(p_tur text, p_il integer)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; il oyun.iller;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_tur not in ('mv','bel') then raise exception 'Geçersiz seçim türü.'; end if;
  if p_tur = 'mv' and (oyun.aday_atama_secim('mv', p_il::smallint, t)).id is null
     and (oyun.mv_tamamlama_secim(p_il::smallint, t)).id is not null then
    return oyun._liste_tamamla_il(p_il);
  end if;
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

create or replace function public.parti_aday_ata(p_tur text, p_il integer, p_kadlar text[])
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler;
  il oyun.iller; lim int; i int := 0; nick text; h oyun.profiller; secilen uuid[] := '{}'; mevcut oyun.adaylar; diger text;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  if p_tur not in ('mv','bel') then raise exception 'Geçersiz seçim türü.'; end if;
  -- Ön seçim/aday belirleme bittikten sonra boş sıraları tamamlama
  if p_tur = 'mv' and (oyun.aday_atama_secim('mv', p_il::smallint, t)).id is null
     and (oyun.mv_tamamlama_secim(p_il::smallint, t)).id is not null then
    return oyun._liste_tamamla_ata(p_il, p_kadlar);
  end if;
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.id is null or pa.kapali then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id then raise exception 'Adayları yalnız Genel Başkan atayabilir.'; end if;
  if pa.kurulus_bit is not null then raise exception 'Partin henüz kuruluş aşamasında; kuruluş tamamlanmadan aday gösteremez.'; end if;
  if oyun.parti_yontem(pa.id, p_tur) <> 'atama' then
    raise exception 'Partin bu seçimde adaylarını ön seçimle belirliyor. Ön seçim sonuçlandıktan sonra boş kalan sıraları liste tamamlamayla doldurabilirsin.'; end if;
  select * into il from oyun.iller where id = p_il;
  if il.id is null then raise exception 'İl bulunamadı.'; end if;
  s := oyun.aday_atama_secim(p_tur, il.id, t);
  if s.id is null then raise exception 'Şu anda aday belirleme dönemi değil. Atama, adaylık başvurusu açıldığı andan ön seçim bitene kadar yapılır; ön seçim sonuçlandıktan sonra boş sıralar liste tamamlamayla doldurulur.'; end if;
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

create or replace function public.parti_aday_uye_ara(p_ara text)
 returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; s oyun.secimler; q text := btrim(coalesce(p_ara, '')); desen text;
  tm boolean := false;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  s := oyun.mv_tamamlama_secim(null::smallint, t);
  tm := s.id is not null;
  if s.id is null then s := oyun.aday_atama_secim('mv', null::smallint, t); end if;
  if s.id is null then
    select * into s from oyun.secimler where tur = 'mv_on' and durum = 'bekliyor' and not ara order by oy_bit limit 1;
  end if;
  if pa.id is null or not (pa.gb = p.id or (tm and oyun.liste_tamamlama_yetkili(p.id, pa))) then
    raise exception 'Bu arama yalnız Genel Başkana (liste tamamlama döneminde yetkili Genel Başkan Yardımcılarına da) açık.'; end if;
  if char_length(q) < 2 then return '[]'::jsonb; end if;
  q := left(q, 40);
  desen := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(z order by z->>'ad') from (
      select jsonb_build_object('kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad),
        'il_id', pr.il_id, 'il', (select ad from oyun.iller where id = pr.il_id),
        'aday_il_id', a.il_id, 'aday_il', (select ad from oyun.iller where id = a.il_id),
        'atama_sira', case when tm then a.sira else a.atama_sira end,
        'basvurdu', a.id is not null and not a.atama_ekleme,
        'uygun', oyun.uyari(pr, t) is null and (not tm or (oyun.tamamlama_engeli(pr.id) is null and (a.id is null or a.sira is null or a.tamamlama)))) z
      from oyun.profiller pr
      left join oyun.adaylar a on a.secim_id = s.id and a.user_id = pr.id
      where pr.parti_id = pa.id and not pr.yasakli and (pr.kad ilike desen or pr.ad_soyad ilike desen)
      limit 20) q2), '[]'::jsonb);
end $function$;

create or replace function public.parti_aday_panel()
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler;
  smv oyun.secimler; sbel oyun.secimler; kmv oyun.secimler; kbel oyun.secimler; gb boolean;
  tm oyun.secimler; tm_son timestamptz; tm_yetki boolean := false;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.id is null or pa.kapali then return jsonb_build_object('parti', null); end if;
  gb := pa.gb = p.id;
  select * into smv from oyun.secimler where tur = 'mv_on' and durum = 'bekliyor' and not ara order by oy_bit limit 1;
  select * into sbel from oyun.secimler where tur = 'bel_on' and durum = 'bekliyor' and not ara order by oy_bit limit 1;
  kmv := oyun.aday_yontem_kilit('mv', t); kbel := oyun.aday_yontem_kilit('bel', t);
  tm := oyun.mv_tamamlama_secim(null::smallint, t);
  if tm.id is not null then
    tm_son := oyun.mv_tamamlama_son(tm);
    tm_yetki := oyun.liste_tamamlama_yetkili(p.id, pa);
    smv := tm;
  end if;
  return jsonb_build_object(
    'parti', jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk),
    'gb_mi', gb or tm_yetki,
    'belirlendi', exists(select 1 from oyun.parti_aday_yontem where parti_id = pa.id),
    'mv', case when tm_yetki then 'atama' else oyun.parti_yontem(pa.id, 'mv') end, 'gercek_mv', oyun.parti_yontem(pa.id, 'mv'), 'bel', oyun.parti_yontem(pa.id, 'bel'),
    'kilit_mv', case when kmv.id is not null then kmv.oy_bit when tm.id is not null then tm_son end,
    'kilit_bel', case when kbel.id is not null then kbel.oy_bit end,
    'tamamlama_mv', case when tm.id is not null then jsonb_build_object('id', tm.id, 'son', tm_son, 'yetkili', tm_yetki,
       'aciklama', 'Ön seçim ya da aday belirleme bitti. Kesinleşen sıralar değişmez; il listelerinde boş kalan sıralara Genel Başkan veya seçim/teşkilat yetkili Genel Başkan Yardımcısı parti üyelerini ekleyebilir. Süre genel seçim oylaması başlayınca biter.') end,
    'secim_mv', case
       when tm.id is not null and smv.id = tm.id then jsonb_build_object('id', tm.id, 'basvuru_bas', tm.sonuc_at, 'basvuru_bit', tm_son, 'oy_bas', tm_son, 'oy_bit', tm_son,
                 'acik', true, 'tamamlama', true)
       when smv.id is not null then jsonb_build_object('id', smv.id, 'basvuru_bas', smv.basvuru_bas, 'basvuru_bit', smv.basvuru_bit, 'oy_bas', smv.oy_bas, 'oy_bit', smv.oy_bit,
                 'acik', t >= smv.basvuru_bas and t < smv.oy_bit) end,
    'secim_bel', case when sbel.id is not null then jsonb_build_object('id', sbel.id, 'basvuru_bas', sbel.basvuru_bas, 'basvuru_bit', sbel.basvuru_bit, 'oy_bas', sbel.oy_bas, 'oy_bit', sbel.oy_bit,
                 'acik', t >= sbel.basvuru_bas and t < sbel.oy_bit) end,
    'iller', case when gb or tm_yetki then coalesce((
      select jsonb_agg(jsonb_build_object('il_id', i.id, 'ad', i.ad, 'mv', coalesce(i.mv_secim, i.mv),
        'uye', x.uye,
        'mv_basvuru', (select count(*) from oyun.adaylar a where a.secim_id = smv.id and a.parti_id = pa.id and a.il_id = i.id and not a.atama_ekleme),
        'mv_atanan', (select count(*) from oyun.adaylar a where a.secim_id = smv.id and a.parti_id = pa.id and a.il_id = i.id
                       and (a.atama_sira is not null or (tm.id is not null and smv.id = tm.id and a.sira is not null))),
        'mv_bos', case when tm.id is not null and smv.id = tm.id then greatest(coalesce(i.mv_secim, i.mv) -
                    (select count(*) from oyun.adaylar a where a.secim_id = tm.id and a.parti_id = pa.id and a.il_id = i.id and a.sira is not null), 0) end,
        'bel_atanan', (select pr.kad from oyun.adaylar a join oyun.profiller pr on pr.id = a.user_id
                       where a.secim_id = sbel.id and a.parti_id = pa.id and a.il_id = i.id and a.atama_sira is not null limit 1))
        order by x.uye desc, i.id)
      from (select il_id, count(*) uye from oyun.profiller where parti_id = pa.id and not yasakli group by il_id
            union select a.il_id, 0 from oyun.adaylar a where tm.id is not null and a.secim_id = tm.id and a.parti_id = pa.id
              and not exists (select 1 from oyun.profiller pr where pr.parti_id = pa.id and not pr.yasakli and pr.il_id = a.il_id)) x
      join oyun.iller i on i.id = x.il_id), '[]'::jsonb) end,
    'kural', 'Ön seçimde partinin o ildeki üyeleri oy verir; milletvekili listesi en çok oydan en aza sıralanır, belediye başkanlığında en çok oyu alan aday olur. Genel Başkan ataması seçilirse üye oylaması yapılmaz; listeyi ve sırayı Genel Başkan belirler (merkez yoklaması, SPK md.37). Yöntem adaylık süreci başlamadan önce değiştirilebilir. Ön seçim/aday belirleme bittikten sonra il listelerinde boş kalan sıraları, genel seçim oylaması başlayana kadar Genel Başkan veya seçim/teşkilat yetkili Genel Başkan Yardımcısı parti üyeleriyle tamamlayabilir; kesinleşen sıralar değişmez.'
  );
end $function$;

-- Yöntem ayarı: tamamlama döneminde milletvekili yöntemi değişmez (eski ekranın gönderdiği uyum değeri 'atama' görmezden gelinir)
do $tamamlama_yontem$
declare d text;
begin
  d := pg_get_functiondef('public.parti_aday_yontem_ayarla'::regproc);
  if position('tamamlanıyor' in d) = 0 then
    d := replace(d, $x$  eski_mv := oyun.parti_yontem(pa.id, 'mv'); eski_bel := oyun.parti_yontem(pa.id, 'bel');$x$,
                    $x$  eski_mv := oyun.parti_yontem(pa.id, 'mv'); eski_bel := oyun.parti_yontem(pa.id, 'bel');
  if p_mv <> eski_mv and (oyun.mv_tamamlama_secim(null::smallint, t)).id is not null then
    if p_mv = 'atama' then p_mv := eski_mv;
    else raise exception 'Milletvekili listeleri tamamlanıyor; yöntemi genel seçimden sonra değiştirebilirsin.'; end if;
  end if;$x$);
    execute d;
  end if;
end $tamamlama_yontem$;

create or replace function public.adaylik_geri_cek(p_secim bigint)
 returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  a oyun.adaylar;
  gorev text;
  son timestamptz;
begin
  if p.id is null or auth.uid() is distinct from p.id then
    raise exception 'Adaylıktan çekilmek için kendi hesabınla giriş yapmalısın.';
  end if;
  select * into s from oyun.secimler where id = p_secim;

  -- Ön seçimi/aday belirlemesi biten milletvekili listesinden, genel seçim oylaması başlayana kadar çekilme
  if s.id is not null and s.tur = 'mv_on' and s.durum <> 'bekliyor' then
    son := oyun.mv_tamamlama_son(s);
    if son is null or t >= son then raise exception 'Oylama başladıktan sonra adaylıktan çekilemezsin.'; end if;
    delete from oyun.adaylar where secim_id = s.id and user_id = p.id and parti_id is not null returning * into a;
    if a.id is null then raise exception 'Bu seçimde adaylığın yok.'; end if;
  else
    if s.id is null or s.durum <> 'bekliyor' or t >= s.oy_bas then
      raise exception 'Oylama başladıktan sonra adaylıktan çekilemezsin.';
    end if;

    delete from oyun.adaylar
     where secim_id = s.id and user_id = p.id
     returning * into a;

    -- Parti listesindeki milletvekili adayı asıl seçim kimliğiyle çekilmek isterse
    if a.id is null and s.tur = 'mv' then
      delete from oyun.adaylar b using oyun.secimler o
       where b.secim_id = o.id and o.donem = s.donem and o.tur = 'mv_on' and o.durum <> 'bekliyor'
         and b.user_id = p.id and b.parti_id is not null
      returning b.* into a;
    end if;
    if a.id is null then
      raise exception 'Bu seçimde adaylığın yok.';
    end if;

    if s.tur in ('mv', 'cb') then
      delete from oyun.adaylar b
      using oyun.secimler onsecim
      where b.secim_id = onsecim.id
        and b.user_id = p.id
        and onsecim.donem = s.donem
        and onsecim.tur = case s.tur when 'mv' then 'mv_on' else 'cb_on' end
        and onsecim.durum = 'bekliyor'
        and t < onsecim.oy_bas;
    end if;

    if s.tur = 'cb' and a.parti_id is not null then
      delete from oyun.cb_kararlar k
      where k.donem = s.donem
        and k.parti_id = a.parti_id
        and k.aday = p.id
        and k.yontem in ('kendisi', 'baskasi');
    end if;
  end if;

  gorev := case
    when s.tur in ('mv', 'mv_on') then 'milletvekilliği'
    when s.tur in ('cb', 'cb_on', 'cb2') then 'cumhurbaşkanlığı'
    when s.tur in ('bel', 'bel_on') then 'belediye başkanlığı'
    else 'seçim' end;

  perform oyun.olay('secim', format('%s, %s adaylığından kendi isteğiyle çekildi.', p.kad, gorev),
                    a.il_id, a.parti_id, t);
  perform oyun.bildir(p.id, format('%s adaylığından çekilmen tamamlandı. Başvuru ücreti iade edilmez.', initcap(gorev)), t);
  if a.tamamlama then
    perform oyun.bildir(pa_gb, format('%s, liste tamamlamasıyla eklendiği %s listesinden çekildi.', p.kad, (select ad from oyun.iller where id = a.il_id)), t)
      from (select gb as pa_gb from oyun.partiler where id = a.parti_id and gb is not null) g;
  end if;

  return public.durum();
end
$function$;
