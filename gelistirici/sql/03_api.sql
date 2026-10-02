-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 3) UYGULAMA FONKSİYONLARI (RPC)
--  Uygulama yalnızca buradaki public.* fonksiyonlarını çağırabilir.
--  Hepsi giriş yapmış oyuncunun kimliğiyle (auth.uid()) çalışır.
-- =====================================================================

-- ---------- yardımcılar (oyun şeması, dışarı kapalı) ----------
create or replace function oyun.ben() returns uuid language plpgsql stable as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Giriş yapmalısın.'; end if;
  return u;
end $$;

create or replace function oyun.profilim() returns oyun.profiller language plpgsql stable as $$
declare p oyun.profiller;
begin
  select * into p from oyun.profiller where id = oyun.ben();
  if p.id is null then raise exception 'Önce profilini oluştur (kullanıcı adı ve il).'; end if;
  if p.yasakli then raise exception 'Hesabın kural ihlali nedeniyle kapatıldı. İtiraz için oyun yönetimine e-posta gönderebilirsin.'; end if;
  return p;
end $$;

create or replace function oyun.sade(t text) returns text language sql immutable as $$
  select regexp_replace(lower(translate(coalesce(t,''), 'ÇĞİIÖŞÜÂÎÛçğıöşüâîû', 'cgiiosuaiucgiosuaiu')), '[^a-z0-9]', '', 'g')
$$;

-- Gerçek partilere ait adlar ve kaba sözler engellenir
create or replace function oyun.yasakli_ad(t text) returns boolean language sql immutable as $$
  select exists (select 1 from unnest(array[
    'akparti','adaletvekalkinma','cumhuriyethalk','milliyetciharek','demparti','halklarinesitlik','halklarindemokratik',
    'iyiparti','yenidenrefah','zaferpartisi','saadetpartisi','devapartisi','demokrasiveatilim','gelecekpartisi',
    'turkiyeiscipartisi','memleketpartisi','buyukbirlik','demokratparti','vatanpartisi','anahtarparti','emekpartisi',
    'komunistparti','dogruyol','anavatan','refahpartisi','faziletpartisi','demokratiksol','hurdavapartisi',
    'orospu','yarrak','pezevenk','kahpe','amcik','surtuk','serefsiz','yavsak','ibne','gavat','siktir','amina'
  ]) y where oyun.sade(t) like '%' || y || '%')
$$;

create or replace function oyun.yasakli_kisa(t text) returns boolean language sql immutable as $$
  select upper(translate(t, 'çğıöşüi', 'ÇĞIÖŞÜİ')) = any (array['AKP','AK','CHP','MHP','DEM','HDP','İYİ','IYI','YRP','ZP','SP','TİP','TIP',
    'BBP','DP','DSP','EMEP','DEVA','HEDEP','TKP','ANAP','DYP','RP','MP','GP','BTP','HÜDA PAR','HÜDAPAR','HYP','SOL','YSK','TBMM'])
$$;

create or replace function oyun.yasakli_kad(t text) returns boolean language sql immutable as $$
  select oyun.yasakli_ad(t) or oyun.sade(t) in ('admin','yonetici','sistem','ysk','moderator','destek','tbmm','cumhurbaskani')
$$;

create or replace function oyun.uyari(p oyun.profiller, ref timestamptz) returns text language sql stable as $$
  select case when p.olusturma > ref - make_interval(days => (select min_hesap_gun from oyun.ayarlar where id = 1))
    then format('Hesabın en az %s günlük olmalı.', (select min_hesap_gun from oyun.ayarlar where id = 1)) end
$$;

-- İl değiştirmenin kapalı olduğu dönemler: aday adaylığı başvurusundan göreve başlamaya kadar
create or replace function oyun.il_kilit_nedeni(t timestamptz) returns text language sql stable as $$
  select case s.tur when 'mv_on' then 'Genel seçim dönemi (26''sından ayın 2''sine kadar) il değiştirilemez.'
                    else 'Belediye seçim dönemi (6''sından 11''ine kadar) il değiştirilemez.' end
  from oyun.secimler s join oyun.secimler g on g.donem = s.donem and g.tur = case s.tur when 'mv_on' then 'mv' else 'bel' end
  where s.tur in ('mv_on','bel_on') and t >= s.basvuru_bas and t < g.goreve_bas
  limit 1
$$;

create or replace function oyun.parti_json(p_id bigint) returns jsonb language sql stable as $$
  select case when p.id is null then null else jsonb_build_object('id', p.id, 'ad', p.ad, 'kisa', p.kisa, 'renk', p.renk, 'amblem', p.amblem) end
  from (select 1) d left join oyun.partiler p on p.id = p_id
$$;

create or replace function oyun.kad(u uuid) returns text language sql stable as $$
  select kad from oyun.profiller where id = u
$$;

create or replace function oyun.asama(s oyun.secimler, t timestamptz) returns text language sql stable as $$
  select case
    when s.durum <> 'bekliyor' then 'bitti'
    when s.basvuru_bas is not null and t >= s.basvuru_bas and t < s.basvuru_bit then 'basvuru'
    when t >= s.oy_bas and t < s.oy_bit then 'oy'
    when t >= s.oy_bit then 'sayim'
    else 'yakinda' end
$$;

-- Bu oyuncu bu seçimde oy kullanabilir mi? (null = evet, aksi halde neden)
create or replace function oyun.oy_engeli(p oyun.profiller, s oyun.secimler) returns text language sql stable as $$
  select coalesce(
    oyun.uyari(p, s.oy_bas),
    case when s.tur in ('mv_on','bel_on','kurultay','cb_on') then
      case when p.parti_id is null then 'Bu parti içi seçimde oy için bir partiye üye olmalısın.'
           when p.parti_at > s.basvuru_bas then 'Parti içi seçimde oy için başvurular açılmadan önce üye olmuş olmalısın.' end
    end)
$$;

-- ---------- PROFİL ----------
create or replace function public.profil_olustur(p_kad text, p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben();
begin
  if exists (select 1 from oyun.profiller where id = u) then raise exception 'Profilin zaten var.'; end if;
  p_kad := btrim(p_kad);
  if p_kad !~ '^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$' then
    raise exception 'Kullanıcı adı 3-20 karakter olmalı; yalnızca harf, rakam ve _ kullanılabilir.';
  end if;
  if oyun.yasakli_kad(p_kad) then raise exception 'Bu kullanıcı adı kullanılamaz.'; end if;
  if exists (select 1 from oyun.profiller where lower(kad) = lower(p_kad)) then raise exception 'Bu kullanıcı adı alınmış.'; end if;
  if not exists (select 1 from oyun.iller where id = p_il) then raise exception 'Geçersiz il.'; end if;
  insert into oyun.profiller(id, kad, il_id, il_at, olusturma) values (u, p_kad, p_il, oyun.simdi(), oyun.simdi());
  return public.durum();
end $$;

create or replace function public.il_degistir(p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); gun int := oyun.il_bekleme_gun(t); kn text; ucret numeric;
begin
  if not exists (select 1 from oyun.iller where id = p_il) then raise exception 'Geçersiz il.'; end if;
  if p.il_id = p_il then raise exception 'Zaten bu ildesin.'; end if;
  kn := oyun.il_kilit_nedeni(t);
  if kn is not null then raise exception '%', kn; end if;
  if p.son_il_degis is not null and p.son_il_degis + make_interval(days => gun) > t then
    raise exception 'İl en fazla % günde bir değiştirilebilir. Bir sonraki: %', gun,
      to_char((p.son_il_degis + make_interval(days => gun)) at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI');
  end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('mv','bel')) then
    raise exception 'Görevdeki vekil veya belediye başkanı il değiştiremez.';
  end if;
  -- taşınma ücreti (ulaşım ve harç indirimleri düşer)
  ucret := oyun.tasinma_ucreti(p.il_id, p_il::smallint, t);
  if ucret > 0 then
    perform oyun.para_islem(p.id, -ucret, 'tasinma', format('Taşınma: %s → %s', (select ad from oyun.iller where id = p.il_id), (select ad from oyun.iller where id = p_il)), t);
  end if;
  update oyun.profiller set il_id = p_il, il_at = t, son_il_degis = t where id = p.id;
  return public.durum();
end $$;

-- ---------- PARTİ ----------
create or replace function oyun._ayril(u uuid, t timestamptz) returns void language plpgsql as $$
declare pid bigint := (select parti_id from oyun.profiller where id = u);
begin
  if pid is null then return; end if;
  -- Sonuçlanmamış seçimlerdeki adaylıklar düşer (vekil listesi genel seçim bitene kadar bağlıdır)
  delete from oyun.adaylar a using oyun.secimler s
   where a.secim_id = s.id and a.user_id = u
     and (s.durum = 'bekliyor'
          or (s.tur = 'mv_on' and exists (select 1 from oyun.secimler m where m.tur = 'mv' and m.donem = s.donem and m.durum = 'bekliyor')));
  delete from oyun.cb_kararlar k where k.parti_id = pid and k.aday = u
     and exists (select 1 from oyun.secimler s where s.tur = 'cb' and s.donem = k.donem and s.durum = 'bekliyor');
  update oyun.partiler set gb = null where id = pid and gb = u;
  delete from oyun.parti_gby where user_id = u;
  update oyun.profiller set parti_id = null, parti_at = null where id = u;
  update oyun.partiler set kapali = true
   where id = pid and not sistem and not exists (select 1 from oyun.profiller where parti_id = pid);
  perform oyun.ittifak_temizle();
end $$;

create or replace function public.parti_kur(p_ad text, p_kisa text, p_renk text, p_amblem text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); gun int := (select parti_kur_gun from oyun.ayarlar where id = 1); yeni bigint;
begin
  p_ad := btrim(regexp_replace(p_ad, '\s+', ' ', 'g')); p_kisa := upper(btrim(p_kisa));
  if length(p_ad) < 5 or length(p_ad) > 40 then raise exception 'Parti adı 5-40 karakter olmalı.'; end if;
  if p_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then raise exception 'Parti adında yalnızca harf kullanılabilir.'; end if;
  if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' then raise exception 'Kısa ad 2-6 büyük harf olmalı.'; end if;
  if p_renk !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Geçersiz renk.'; end if;
  if p_amblem !~ '^[a-z_]{2,20}$' then raise exception 'Geçersiz amblem.'; end if;
  if oyun.yasakli_ad(p_ad) or oyun.yasakli_kisa(p_kisa) then
    raise exception 'Gerçek bir partiyi çağrıştıran veya uygunsuz adlar kullanılamaz.';
  end if;
  if exists (select 1 from oyun.partiler where not kapali and lower(ad) = lower(p_ad)) then raise exception 'Bu adla bir parti zaten var.'; end if;
  if exists (select 1 from oyun.partiler where not kapali and lower(kisa) = lower(p_kisa)) then raise exception 'Bu kısa ad kullanılıyor.'; end if;
  if oyun.uyari(p, t) is not null then raise exception 'Parti kurmak için %', lower(oyun.uyari(p, t)); end if;
  if p.son_parti_kur is not null and p.son_parti_kur + make_interval(days => gun) > t then
    raise exception 'En fazla % günde bir parti kurabilirsin.', gun;
  end if;
  perform oyun._ayril(p.id, t);
  insert into oyun.partiler(ad, kisa, renk, amblem, gb, kurucu, kurulus) values (p_ad, p_kisa, lower(p_renk), p_amblem, p.id, p.id, t)
  returning id into yeni;
  update oyun.profiller set parti_id = yeni, parti_at = t, son_parti_kur = t where id = p.id;
  perform oyun.olay('parti', format('%s, %s (%s) adıyla yeni bir parti kurdu.', p.kad, p_ad, p_kisa), p.il_id, yeni, t);
  return public.durum();
end $$;

create or replace function public.partiye_katil(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not exists (select 1 from oyun.partiler where id = p_parti and not kapali) then raise exception 'Parti bulunamadı.'; end if;
  if p.parti_id = p_parti then raise exception 'Zaten bu partinin üyesisin.'; end if;
  perform oyun._ayril(p.id, t);
  update oyun.profiller set parti_id = p_parti, parti_at = t where id = p.id;
  return public.durum();
end $$;

create or replace function public.partiden_ayril() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim();
begin
  if p.parti_id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  perform oyun._ayril(p.id, oyun.simdi());
  return public.durum();
end $$;

-- Genel başkan 6 yardımcısını atar (p_kad boş = o sırayı boşalt)
create or replace function public.gby_ata(p_sira int, p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); hedef oyun.profiller; pa oyun.partiler; eski uuid;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then raise exception 'Yalnızca genel başkan yardımcı atayabilir.'; end if;
  if p_sira not between 1 and 6 then raise exception 'Geçersiz sıra (1-6).'; end if;
  select user_id into eski from oyun.parti_gby where parti_id = pa.id and sira = p_sira;
  if coalesce(btrim(p_kad), '') = '' then
    delete from oyun.parti_gby where parti_id = pa.id and sira = p_sira;
    if eski is not null then perform oyun.bildir(eski, format('%s genel başkan yardımcılığı görevin sona erdi.', pa.kisa)); end if;
    return public.durum();
  end if;
  select * into hedef from oyun.profiller where lower(kad) = lower(btrim(p_kad));
  if hedef.id is null or hedef.parti_id is distinct from pa.id then raise exception 'Bu kişi partinin üyesi değil.'; end if;
  if hedef.id = p.id then raise exception 'Kendini yardımcı atayamazsın.'; end if;
  if oyun.rol_cakisma(hedef.id, 'gby') is not null then
    raise exception '% şu anda % görevinde; genel başkan yardımcısı yalnızca milletvekili olabilir.', hedef.kad, oyun.rol_cakisma(hedef.id, 'gby');
  end if;
  if eski = hedef.id then return public.durum(); end if;
  delete from oyun.parti_gby where parti_id = pa.id and (sira = p_sira or user_id = hedef.id);
  insert into oyun.parti_gby(parti_id, sira, user_id, atama) values (pa.id, p_sira, hedef.id, oyun.simdi());
  if eski is not null then perform oyun.bildir(eski, format('%s genel başkan yardımcılığı görevin sona erdi.', pa.kisa)); end if;
  perform oyun.bildir(hedef.id, format('%s Genel Başkanı seni genel başkan yardımcısı olarak atadı.', pa.kisa));
  perform oyun.olay('parti', format('%s, %s genel başkan yardımcılığına atandı.', hedef.kad, pa.kisa), null, pa.id);
  return public.durum();
end $$;

-- Genel başkan cumhurbaşkanı adayı yöntemini seçer (ayın 19-25'i):
--   kendisi | baskasi (p_kad) | onsecim (26'sında başvuru, 28'inde üyeler seçer)
create or replace function public.cb_aday_belirle(p_yontem text, p_kad text default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; pa oyun.partiler; hedef oyun.profiller;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then raise exception 'Bu kararı yalnızca genel başkan verebilir.'; end if;
  select * into s from oyun.secimler where tur = 'cb' and t >= basvuru_bas and t < basvuru_bit;
  if s.id is null then raise exception 'Cumhurbaşkanı adayı kararı ayın 19''u ile 25''i arasında verilir.'; end if;
  if p_yontem not in ('kendisi','baskasi','onsecim') then raise exception 'Geçersiz yöntem.'; end if;
  if p_yontem = 'kendisi' then hedef := p;
  elsif p_yontem = 'baskasi' then
    select * into hedef from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad,'')));
    if hedef.id is null or hedef.parti_id is distinct from pa.id then raise exception 'Aday partinin üyesi olmalı.'; end if;
  end if;
  if hedef.id is not null and oyun.uyari(hedef, t) is not null then raise exception 'Aday için: %', oyun.uyari(hedef, t); end if;
  insert into oyun.cb_kararlar(donem, parti_id, yontem, aday, zaman) values (s.donem, pa.id, p_yontem, hedef.id, t)
  on conflict (donem, parti_id) do update set yontem = excluded.yontem, aday = excluded.aday, destek_parti = null, zaman = excluded.zaman;
  delete from oyun.adaylar where secim_id = s.id and parti_id = pa.id;
  if hedef.id is not null then
    insert into oyun.adaylar(secim_id, user_id, parti_id, basvuru_at) values (s.id, hedef.id, pa.id, t);
  end if;
  return public.durum();
end $$;

-- ---------- ADAYLIK ----------
-- p_tur: mv_on (vekil), bel_on (belediye), kurultay (genel başkan), cb_on (parti CB ön seçimi)
create or replace function public.aday_ol(p_tur text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; k oyun.cb_kararlar;
begin
  if p_tur not in ('mv_on','bel_on','kurultay','cb_on') then raise exception 'Geçersiz adaylık türü.'; end if;
  select * into s from oyun.secimler where tur = p_tur and t >= basvuru_bas and t < basvuru_bit;
  if s.id is null then raise exception 'Bu adaylık için başvuru şu anda açık değil.'; end if;
  if p.parti_id is null then raise exception 'Aday olmak için bir partiye üye olmalısın.'; end if;
  if p.parti_at > s.basvuru_bas then raise exception 'Bu dönem aday olabilmek için başvurular açılmadan önce partiye üye olmalıydın.'; end if;
  if oyun.uyari(p, t) is not null then raise exception '%', oyun.uyari(p, t); end if;
  if p_tur in ('mv_on','bel_on') and exists (select 1 from oyun.partiler where gb = p.id) then
    raise exception 'Genel başkan milletvekili ya da belediye başkanı adayı olamaz. Genel başkan yalnızca cumhurbaşkanı adayı olabilir.';
  end if;
  if p_tur = 'cb_on' then
    select * into k from oyun.cb_kararlar where donem = s.donem and parti_id = p.parti_id;
    if k.yontem in ('kendisi','baskasi') then raise exception 'Genel başkan cumhurbaşkanı adayını doğrudan belirledi; ön seçim yapılmayacak.'; end if;
    if k.yontem = 'destek' then raise exception 'Partin cumhurbaşkanlığında ittifak ortağının adayını destekliyor; ön seçim yapılmayacak.'; end if;
  end if;
  insert into oyun.adaylar(secim_id, user_id, parti_id, il_id, basvuru_at)
  values (s.id, p.id, p.parti_id, case when p_tur in ('mv_on','bel_on') then p.il_id end, t)
  on conflict (secim_id, user_id) do nothing;
  if not found then raise exception 'Bu seçime zaten başvurdun.'; end if;
  -- aday adaylığı başvuru ücreti (parti kasasına); para yetmezse başvuru geri alınır
  perform oyun.aday_ucreti_al(p, p_tur, t);
  return public.durum();
end $$;

create or replace function public.adaylik_geri_cek(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.durum <> 'bekliyor' or t >= s.oy_bas then raise exception 'Oylama başladıktan sonra adaylıktan çekilemezsin.'; end if;
  delete from oyun.adaylar where secim_id = s.id and user_id = p.id;
  if not found then raise exception 'Bu seçimde adaylığın yok.'; end if;
  return public.durum();
end $$;

-- ---------- OY ----------
-- p_hedef: genel seçimde (mv) PARTİ id'si, diğer tüm seçimlerde ADAY id'si
create or replace function public.oy_ver(p_secim bigint, p_hedef bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; a oyun.adaylar; e text; onsecim bigint;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  if s.durum <> 'bekliyor' or t < s.oy_bas or t >= s.oy_bit then raise exception 'Sandık şu anda kapalı (oy saatleri 08:00–17:00).'; end if;
  e := oyun.oy_engeli(p, s);
  if e is not null then raise exception '%', e; end if;
  if exists (select 1 from oyun.oylar where secim_id = s.id and secmen = p.id) then raise exception 'Bu seçimde zaten oy kullandın.'; end if;

  if s.tur = 'mv' then
    select id into onsecim from oyun.secimler where tur = 'mv_on' and donem = s.donem;
    if not exists (select 1 from oyun.adaylar where secim_id = onsecim and il_id = p.il_id and parti_id = p_hedef and sira is not null) then
      raise exception 'Bu partinin ilinde aday listesi yok.';
    end if;
    insert into oyun.oylar(secim_id, secmen, il_id, parti_id, zaman) values (s.id, p.id, p.il_id, p_hedef, t);
  else
    select * into a from oyun.adaylar where id = p_hedef and secim_id = s.id;
    if a.id is null then raise exception 'Aday bulunamadı.'; end if;
    if s.tur in ('mv_on','bel_on') and (a.il_id <> p.il_id or a.parti_id <> p.parti_id) then
      raise exception 'Ön seçimde yalnızca kendi ilindeki kendi partinin adaylarına oy verebilirsin.';
    end if;
    if s.tur in ('kurultay','cb_on') and a.parti_id <> p.parti_id then raise exception 'Yalnızca kendi partinin seçiminde oy kullanabilirsin.'; end if;
    if s.tur = 'bel' and a.il_id <> p.il_id then raise exception 'Yalnızca kendi ilinin belediye seçiminde oy kullanabilirsin.'; end if;
    insert into oyun.oylar(secim_id, secmen, il_id, parti_id, aday_id, zaman) values (s.id, p.id, p.il_id, a.parti_id, a.id, t);
  end if;
  return public.durum();
end $$;

-- ---------- OKUMA ----------
create or replace function oyun.secim_ozet(s oyun.secimler, p oyun.profiller, t timestamptz) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', s.id, 'tur', s.tur, 'donem', s.donem, 'asama', oyun.asama(s, t),
    'basvuru_bas', s.basvuru_bas, 'basvuru_bit', s.basvuru_bit, 'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit,
    'sonuc_at', s.sonuc_at, 'goreve_bas', s.goreve_bas,
    'adayim', exists (select 1 from oyun.adaylar a where a.secim_id = s.id and a.user_id = p.id),
    'oy_verdim', exists (select 1 from oyun.oylar o where o.secim_id = s.id and o.secmen = p.id),
    'oy_engeli', oyun.oy_engeli(p, s),
    'katilim', case when s.durum <> 'bekliyor' or t >= s.oy_bas then (select count(*) from oyun.oylar o where o.secim_id = s.id) end)
$$;

create or replace function public.durum() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben(); p oyun.profiller; t timestamptz := oyun.simdi(); pa oyun.partiler; gun int := oyun.il_bekleme_gun(oyun.simdi());
begin
  select * into p from oyun.profiller where id = u;
  if p.id is null then
    return jsonb_build_object('simdi', t, 'profil', null);
  end if;
  if p.yasakli then raise exception 'Hesabın kural ihlali nedeniyle kapatıldı. İtiraz için oyun yönetimine e-posta gönderebilirsin.'; end if;
  if p.son_gorulme is null or p.son_gorulme < t - interval '5 minutes' then
    update oyun.profiller set son_gorulme = t where id = p.id;
  end if;
  select * into pa from oyun.partiler where id = p.parti_id;
  return jsonb_build_object(
    'simdi', t,
    'profil', jsonb_build_object(
      'id', p.id, 'kad', p.kad, 'il_id', p.il_id, 'il_ad', (select ad from oyun.iller where id = p.il_id),
      'olusturma', p.olusturma, 'parti', oyun.parti_json(p.parti_id), 'parti_at', p.parti_at,
      'gb', pa.gb = p.id, 'gby', exists (select 1 from oyun.parti_gby g where g.user_id = p.id),
      'il_kilit', oyun.il_kilit_nedeni(t),
      'il_serbest', case when p.son_il_degis is null then null else p.son_il_degis + make_interval(days => gun) end,
      'makamlar', coalesce((select jsonb_agg(jsonb_build_object('tur', m.tur, 'il_id', m.il_id, 'il_ad', i.ad, 'bas', m.bas, 'kaynak', m.kaynak,
                                                    'bakanlik', m.bakanlik, 'bakanlik_ad', (select ad from oyun.bakanliklar b where b.kod = m.bakanlik)))
                            from oyun.makamlar m left join oyun.iller i on i.id = m.il_id where m.user_id = p.id and m.bit is null), '[]'::jsonb),
      'hesap_engeli', oyun.uyari(p, t),
      'cb_mi', exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null),
      'yonetici', p.yonetici, 'bildirim_ayar', p.bildirim_ayar,
      'cuzdan', oyun.cuzdan_ozet(p.id, t)),
    'okunmamis', oyun.okunmamis(p),
    'takvim', coalesce((select jsonb_agg(oyun.secim_ozet(s, p, t) order by coalesce(s.basvuru_bas, s.oy_bas), oyun.oncelik(s.tur))
                        from oyun.secimler s
                        where coalesce(s.goreve_bas, s.sonuc_at) >= t - interval '3 days'
                          and coalesce(s.basvuru_bas, s.oy_bas) <= t + interval '40 days'), '[]'::jsonb),
    'cb', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas)
           from oyun.makamlar m where m.tur = 'cb' and m.bit is null limit 1),
    'cb_karar', case when pa.gb = p.id then
       (select jsonb_build_object('secim_id', s.id, 'donem', s.donem, 'acik', t >= s.basvuru_bas and t < s.basvuru_bit,
                                  'yontem', k.yontem, 'aday', oyun.kad(k.aday), 'son', s.basvuru_bit,
                                  'destek', (select kisa from oyun.partiler where id = k.destek_parti))
        from oyun.secimler s left join oyun.cb_kararlar k on k.donem = s.donem and k.parti_id = pa.id
        where s.tur = 'cb' and s.durum = 'bekliyor' order by s.oy_bas limit 1) end
  );
end $$;

-- Bir seçimin ayrıntısı: oy pusulası (bana göre seçenekler) + sonuç
create or replace function public.secim_detay(p_secim bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.secimler; onsecim bigint; secenek jsonb;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
  if s.tur = 'mv' then
    select id into onsecim from oyun.secimler where tur = 'mv_on' and donem = s.donem;
    select coalesce(jsonb_agg(x order by x->>'kisa'), '[]'::jsonb) into secenek from (
      select oyun.parti_json(a.parti_id) || jsonb_build_object('hedef', a.parti_id, 'beyanname', oyun.beyanname_json(a.parti_id, s.donem),
             'liste', jsonb_agg(jsonb_build_object('kad', oyun.kad(a.user_id), 'sira', a.sira, 'vaat', a.vaat,
                                                   'vaatler', oyun.aday_vaatleri(a.user_id, s.id)) order by a.sira)) x
      from oyun.adaylar a where a.secim_id = onsecim and a.il_id = p.il_id and a.sira is not null
      group by a.parti_id) z;
  else
    select coalesce(jsonb_agg(oyun.aday_json(a.id) || jsonb_build_object('hedef', a.id, 'oy', case when s.durum = 'bekliyor' then null else a.oy end,
                     'beyanname', case when s.tur in ('cb','cb2') then oyun.beyanname_json(a.parti_id, s.donem) end)
                     order by a.parti_id, a.basvuru_at), '[]'::jsonb) into secenek
    from oyun.adaylar a
    where a.secim_id = s.id and (
      (s.tur in ('mv_on','bel_on') and a.il_id = p.il_id and a.parti_id = p.parti_id) or
      (s.tur in ('kurultay','cb_on') and a.parti_id = p.parti_id) or
      (s.tur = 'bel' and a.il_id = p.il_id) or
      (s.tur in ('cb','cb2')));
  end if;
  return oyun.secim_ozet(s, p, t) || jsonb_build_object('secenekler', secenek, 'sonuc', s.sonuc,
           'benim_il', p.il_id, 'benim_parti', p.parti_id,
           'destekler', case when s.tur in ('cb','cb2') then coalesce((select jsonb_object_agg(x.destek_parti::text, x.l) from (
               select k.destek_parti, jsonb_agg(oyun.parti_json(k.parti_id)) l from oyun.cb_kararlar k
               where k.donem = s.donem and k.yontem = 'destek' group by k.destek_parti) x), '{}'::jsonb) end);
end $$;

-- Türkiye haritası için il özeti
create or replace function public.harita() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id, 'ad', i.ad, 'mv', i.mv,
    'oyuncu', (select count(*) from oyun.profiller pr where pr.il_id = i.id),
    'bel', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id))
            from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1),
    'vekil', (select coalesce(jsonb_agg(jsonb_build_object('parti_id', x.parti_id, 'renk', pa.renk, 'kisa', pa.kisa, 'n', x.n) order by x.n desc), '[]'::jsonb)
              from (select parti_id, count(*) n from oyun.makamlar m where m.tur = 'mv' and m.il_id = i.id and m.bit is null group by parti_id) x
              join oyun.partiler pa on pa.id = x.parti_id)
  ) order by i.id), '[]'::jsonb)
  from oyun.iller i
$$;

create or replace function public.il_detay(p_il int) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); i oyun.iller; t timestamptz := oyun.simdi();
begin
  select * into i from oyun.iller where id = p_il;
  if i.id is null then raise exception 'İl bulunamadı.'; end if;
  return jsonb_build_object(
    'id', i.id, 'ad', i.ad, 'mv', i.mv,
    'oyuncu', (select count(*) from oyun.profiller where il_id = i.id),
    'partiler', coalesce((select jsonb_agg(oyun.parti_json(x.parti_id) || jsonb_build_object('uye', x.n) order by x.n desc)
                 from (select parti_id, count(*) n from oyun.profiller where il_id = i.id and parti_id is not null group by parti_id) x), '[]'::jsonb),
    'bel', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas)
            from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1),
    'vekiller', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'kaynak', m.kaynak) order by m.parti_id, m.bas)
                 from oyun.makamlar m where m.tur = 'mv' and m.il_id = i.id and m.bit is null), '[]'::jsonb),
    'adaylar', coalesce((select jsonb_agg(oyun.aday_json(a.id) || jsonb_build_object('tur', s.tur) order by s.tur, a.parti_id, a.sira nulls last, a.basvuru_at)
                 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
                 where a.il_id = i.id and (s.durum = 'bekliyor' or (s.tur = 'mv_on' and exists
                   (select 1 from oyun.secimler m where m.tur = 'mv' and m.donem = s.donem and m.durum = 'bekliyor')))), '[]'::jsonb),
    'benim_ilim', p.il_id = i.id,
    'durum', (select jsonb_build_object('gelisim', round(d.gelisim, 1), 'memnuniyet', round(d.memnuniyet, 1), 'kasa', round(d.kasa, 2))
              from oyun.il_durum d where d.il_id = i.id),
    'projeler', coalesce((select jsonb_agg(jsonb_build_object('ad', k.ad, 'zaman', k.zaman, 'baskan', oyun.kad(k.baskan)) order by k.zaman desc)
                 from (select x.*, coalesce(b.ad, y.ad) ad from oyun.belediye_proje_kayit x
                       left join oyun.belediye_hizmetleri b on b.kod = x.kod left join oyun.belediye_yatirimlari y on y.kod = x.kod
                       where x.il_id = i.id order by x.zaman desc limit 5) k), '[]'::jsonb),
    -- ilde yaşayanlara şu an işleyen belediye hizmetleri ve bakanlık tedbirleri
    'hizmetler', oyun.il_hizmet_json(i.id, t),
    'il_carpan', oyun.il_carpan(i.id),
    'kent_vergisi', (select kent_vergisi from oyun.il_durum where il_id = i.id),
    'hemsehri', (select hemsehri from oyun.il_durum where il_id = i.id),
    'tasinma', case when p.il_id <> i.id then oyun.tasinma_ucreti(p.il_id, i.id, t) end,
    'bel_vaatler', (select oyun.vaat_listesi_makam(m.id) from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null limit 1));
end $$;

create or replace function public.partiler() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(oyun.parti_json(pa.id) || jsonb_build_object(
    'uye', (select count(*) from oyun.profiller where parti_id = pa.id),
    'gb', oyun.kad(pa.gb), 'sistem', pa.sistem,
    'vekil', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id),
    'belediye', (select count(*) from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.parti_id = pa.id))
    order by (select count(*) from oyun.profiller where parti_id = pa.id) desc, pa.id), '[]'::jsonb)
  from oyun.partiler pa where not pa.kapali
$$;

create or replace function public.parti_detay(p_parti bigint) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  return oyun.parti_json(pa.id) || jsonb_build_object(
    'kapali', pa.kapali, 'sistem', pa.sistem, 'kurulus', pa.kurulus, 'kurucu', oyun.kad(pa.kurucu),
    'gb', oyun.kad(pa.gb),
    'gby', coalesce((select jsonb_agg(jsonb_build_object('sira', g.sira, 'kad', oyun.kad(g.user_id)) order by g.sira)
                     from oyun.parti_gby g where g.parti_id = pa.id), '[]'::jsonb),
    'uye', (select count(*) from oyun.profiller where parti_id = pa.id),
    'uyeler', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'il', i.ad,
                 'makam', (select string_agg(m.tur, ',') from oyun.makamlar m where m.user_id = pr.id and m.bit is null))
                 order by (pr.id = pa.gb) desc, exists (select 1 from oyun.parti_gby g where g.user_id = pr.id) desc, pr.parti_at)
               from (select * from oyun.profiller where parti_id = pa.id order by parti_at limit 300) pr join oyun.iller i on i.id = pr.il_id), '[]'::jsonb),
    'vekil', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pa.id),
    'belediye', (select count(*) from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.parti_id = pa.id),
    'uyesiyim', p.parti_id = pa.id);
end $$;

create or replace function public.meclis() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object(
    'toplam', 600,
    'dolu', (select count(*) from oyun.makamlar where tur = 'mv' and bit is null),
    'partiler', coalesce((select jsonb_agg(oyun.parti_json(x.parti_id) || jsonb_build_object('n', x.n) order by x.n desc)
                 from (select parti_id, count(*) n from oyun.makamlar where tur = 'mv' and bit is null group by parti_id) x), '[]'::jsonb),
    'vekiller', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'il', i.ad, 'parti_id', m.parti_id) order by i.ad, m.parti_id)
                 from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.tur = 'mv' and m.bit is null), '[]'::jsonb))
$$;

create or replace function public.gecmis_secimler(p_limit int default 30) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'tur', s.tur, 'donem', s.donem, 'sonuc_at', s.sonuc_at) order by s.sonuc_at desc), '[]'::jsonb)
  from (select * from oyun.secimler where durum <> 'bekliyor' order by sonuc_at desc limit least(greatest(p_limit,1),100)) s
$$;

create or replace function public.haberler(p_limit int default 40) returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('zaman', o.zaman, 'tur', o.tur, 'metin', o.metin, 'parti', oyun.parti_json(o.parti_id)) order by o.zaman desc, o.id desc), '[]'::jsonb)
  from (select * from oyun.olaylar where zaman <= oyun.simdi() order by zaman desc, id desc limit least(greatest(p_limit,1),100)) o
$$;

-- Hesabı ve tüm kişisel verileri siler (App Store zorunluluğu)
create or replace function public.hesabimi_sil() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben(); t timestamptz := oyun.simdi(); m record;
begin
  for m in select id from oyun.makamlar where user_id = u and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'hesap_silindi');
  end loop;
  perform oyun._ayril(u, t);
  delete from oyun.adaylar a using oyun.secimler s where a.secim_id = s.id and a.user_id = u and s.durum = 'bekliyor';
  update oyun.oylar set secmen = gen_random_uuid() where secmen = u;   -- oy sayısı korunur, kimlik kopar
  delete from oyun.mesajlar where user_id = u;
  delete from oyun.ozel where gonderen = u or alici = u;
  delete from oyun.yayinlar where gonderen = u;
  delete from oyun.bildirimler where user_id = u;
  delete from oyun.engellemeler where engelleyen = u or engellenen = u;
  delete from oyun.profiller where id = u;
  delete from auth.users where id = u;
  return jsonb_build_object('silindi', true);
end $$;

