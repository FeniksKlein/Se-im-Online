-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 5) KABİNE + SOSYAL
--  Bakan atama, sohbet kanalları, özel mesaj, propaganda yayınları,
--  bildirim kutusu, şikâyet/engelleme.
-- =====================================================================

-- ---------- yardımcılar ----------
create or replace function oyun.kufurlu(t text) returns boolean language sql immutable as $$
  select exists (select 1 from unnest(array[
    'orospu','yarrak','pezevenk','kahpe','amcik','surtuk','serefsiz','yavsak','ibne','gavat','siktir','amina',
    'aminakoy','anani','sikerim','sikeyim','pust','kaltak','dalyarak','gerizekali'
  ]) y where oyun.sade(t) like '%' || y || '%')
$$;

-- Oyuncunun en yüksek unvanı (sohbet rozetleri ve yayın imzası için)
create or replace function oyun.unvan(u uuid) returns text language sql stable as $$
  select coalesce(
    (select 'Cumhurbaşkanı' from oyun.makamlar where user_id = u and tur = 'cb' and bit is null limit 1),
    (select replace(b.ad, 'Bakanlığı', 'Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik
       where m.user_id = u and m.tur = 'bakan' and m.bit is null limit 1),
    (select pa.kisa || ' Genel Başkanı' from oyun.partiler pa where pa.gb = u and not pa.kapali limit 1),
    (select i.ad || ' Milletvekili' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'mv' and m.bit is null limit 1),
    (select i.ad || ' Belediye Başkanı' from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = u and m.tur = 'bel' and m.bit is null limit 1),
    (select pa.kisa || ' Genel Başkan Yardımcısı' from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id where g.user_id = u limit 1))
$$;

create or replace function oyun.engelli(ben uuid, diger uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.engellemeler where engelleyen = ben and engellenen = diger)
$$;

create or replace function oyun.yayin_gorur(y oyun.yayinlar, p oyun.profiller) returns boolean language sql stable as $$
  select (y.hedef_il is null or y.hedef_il = p.il_id) and (y.hedef_parti is null or y.hedef_parti = p.parti_id)
$$;

create or replace function oyun.okunmamis(p oyun.profiller) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'bildirim',
      (select count(*) from oyun.yayinlar y where not y.gizli and y.gonderen <> p.id and y.zaman > p.bildirim_okundu
         and y.zaman <= oyun.simdi() and oyun.yayin_gorur(y, p) and not oyun.engelli(p.id, y.gonderen))
      + (select count(*) from oyun.bildirimler b where b.user_id = p.id and b.zaman > p.bildirim_okundu and b.zaman <= oyun.simdi()),
    'ozel',
      (select count(*) from oyun.ozel o where o.alici = p.id and not o.okundu and not o.gizli and not oyun.engelli(p.id, o.gonderen)))
$$;

create or replace function oyun.yazabilir_mi(p oyun.profiller, t timestamptz) returns void language plpgsql as $$
begin
  if p.susturma_bitis is not null and p.susturma_bitis > t then
    raise exception 'Hesabın % tarihine kadar mesaj gönderemez (kural ihlali).', to_char(p.susturma_bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI');
  end if;
  if p.son_mesaj is not null and p.son_mesaj > t - interval '3 seconds' then
    raise exception 'Çok hızlı yazıyorsun, birkaç saniye bekle.';
  end if;
  if (select count(*) from oyun.mesajlar where user_id = p.id and zaman > t - interval '1 minute')
   + (select count(*) from oyun.ozel where gonderen = p.id and zaman > t - interval '1 minute') >= 12 then
    raise exception 'Bir dakikada çok fazla mesaj gönderdin, biraz bekle.';
  end if;
end $$;

create or replace function oyun.metin_temizle(m text, enfazla int) returns text language plpgsql as $$
begin
  m := btrim(regexp_replace(coalesce(m, ''), '[\r\n]{3,}', E'\n\n', 'g'));
  if length(m) = 0 then raise exception 'Mesaj boş olamaz.'; end if;
  if length(m) > enfazla then raise exception 'Mesaj en fazla % karakter olabilir.', enfazla; end if;
  if oyun.kufurlu(m) then raise exception 'Mesajında uygunsuz bir ifade var. Hakaret ve küfür yasaktır.'; end if;
  return m;
end $$;

create or replace function oyun.profil_bul(p_kad text) returns oyun.profiller language plpgsql stable as $$
declare h oyun.profiller;
begin
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  return h;
end $$;

-- =====================================================================
--  KABİNE
-- =====================================================================
create or replace function public.kabine() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select jsonb_build_object(
    'cb', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas)
           from oyun.makamlar m where m.tur = 'cb' and m.bit is null limit 1),
    'bakanlar', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad,
                   'kad', oyun.kad(m.user_id),
                   'parti', oyun.parti_json((select parti_id from oyun.profiller where id = m.user_id)),
                   'bas', m.bas) order by b.sira)
                 from oyun.bakanliklar b left join oyun.makamlar m on m.bakanlik = b.kod and m.tur = 'bakan' and m.bit is null))
$$;

create or replace function oyun.cb_zorunlu(p oyun.profiller) returns void language plpgsql as $$
begin
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null) then
    raise exception 'Bu yetki yalnızca cumhurbaşkanındadır.';
  end if;
end $$;

-- Cumhurbaşkanı bir bakanlığa atama yapar. Milletvekilliği bakanlıkla birlikte sürdürülebilir;
-- belediye başkanlığı gibi uyumsuz görevler önce bırakılır. Eski bakan görevden alınır.
create or replace function public.bakan_ata(p_bakanlik text, p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; b oyun.bakanliklar; m record;
begin
  perform oyun.cb_zorunlu(p);
  select * into b from oyun.bakanliklar where kod = p_bakanlik;
  if b.kod is null then raise exception 'Bakanlık bulunamadı.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Cumhurbaşkanı kendini bakan atayamaz.'; end if;
  if oyun.uyari(h, t) is not null then raise exception 'Atanacak kişi için: %', oyun.uyari(h, t); end if;
  if exists (select 1 from oyun.makamlar where tur = 'bakan' and bakanlik = b.kod and bit is null and user_id = h.id) then
    raise exception '% zaten bu bakanlıkta.', h.kad;
  end if;
  -- Rol uyumluluğunu kontrol et: milletvekilliği bakanlıkla uyumludur.
  if oyun.rol_cakisma(h.id, 'bakan') is not null then
    raise exception '% şu anda % görevinde. Bakan atanabilmesi için önce o görevden ayrılması gerekir.', h.kad, oyun.rol_cakisma(h.id, 'bakan');
  end if;
  -- bakanlıktaki eski bakan görevden alınır
  for m in select id from oyun.makamlar where tur = 'bakan' and bakanlik = b.kod and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'gorevden_alindi');
  end loop;
  insert into oyun.makamlar(tur, user_id, il_id, parti_id, bakanlik, kaynak, bas)
  values ('bakan', h.id, null, h.parti_id, b.kod, 'atama', t);
  perform oyun.bildir(h.id, format('Cumhurbaşkanı %s seni %s olarak atadı.', p.kad, replace(b.ad, 'Bakanlığı', 'Bakanı')), t);
  perform oyun.olay('makam', format('%s, %s olarak atandı.', h.kad, replace(b.ad, 'Bakanlığı', 'Bakanı')), null, h.parti_id, t);
  perform oyun.gazete_ekle('atama', format('%s''na %s atandı', b.ad, h.kad), format('Cumhurbaşkanı %s tarafından %s olarak atanmıştır.', p.kad, replace(b.ad, 'Bakanlığı', 'Bakanı')), null, t);
  return public.kabine();
end $$;

create or replace function public.bakan_gorevden_al(p_bakanlik text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m record; n int := 0;
begin
  perform oyun.cb_zorunlu(p);
  for m in select id, user_id from oyun.makamlar where tur = 'bakan' and bakanlik = p_bakanlik and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'gorevden_alindi');
    perform oyun.olay('makam', format('%s, %s görevinden alındı.', oyun.kad(m.user_id), (select ad from oyun.bakanliklar where kod = p_bakanlik)), null, null, t);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Bu bakanlık zaten boş.'; end if;
  return public.kabine();
end $$;

-- Bakanlıktan veya genel başkan yardımcılığından istifa
create or replace function public.istifa(p_gorev text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; cb uuid;
begin
  if p_gorev = 'bakan' then
    select * into m from oyun.makamlar where user_id = p.id and tur = 'bakan' and bit is null;
    if m.id is null then raise exception 'Bakan değilsin.'; end if;
    perform oyun.makam_bitir(m.id, t, 'istifa');
    select user_id into cb from oyun.makamlar where tur = 'cb' and bit is null limit 1;
    if cb is not null then perform oyun.bildir(cb, format('%s, %s görevinden istifa etti.', p.kad, oyun.makam_ad('bakan', null, m.bakanlik)), t); end if;
    perform oyun.olay('makam', format('%s, %s görevinden istifa etti.', p.kad, oyun.makam_ad('bakan', null, m.bakanlik)), null, p.parti_id, t);
  elsif p_gorev in ('mv','bel') then
    select * into m from oyun.makamlar where user_id = p.id and tur = p_gorev and bit is null;
    if m.id is null then raise exception 'Bu görevde değilsin.'; end if;
    perform oyun.makam_bitir(m.id, t, 'istifa');
    perform oyun.olay('makam', format('%s, %s görevinden istifa etti.', p.kad, oyun.makam_ad(m.tur, m.il_id, null)), m.il_id, p.parti_id, t);
  elsif p_gorev = 'gby' then
    delete from oyun.parti_gby where user_id = p.id;
    if not found then raise exception 'Genel başkan yardımcısı değilsin.'; end if;
    perform oyun.bildir((select gb from oyun.partiler where id = p.parti_id), format('%s genel başkan yardımcılığından istifa etti.', p.kad), t);
  else
    raise exception 'Geçersiz görev.';
  end if;
  return public.durum();
end $$;

create or replace function public.oyuncu_kart(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  return jsonb_build_object('kad', h.kad, 'il_ad', (select ad from oyun.iller where id = h.il_id), 'il_id', h.il_id,
    'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'katilim', h.olusturma,
    'ben', h.id = p.id, 'engelledim', oyun.engelli(p.id, h.id),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('makam', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'bit', m.bit) order by m.bas desc)
                        from (select * from oyun.makamlar where user_id = h.id order by bas desc limit 20) m), '[]'::jsonb));
end $$;

-- =====================================================================
--  SOHBET KANALLARI: genel · il · parti · meclis
-- =====================================================================
create or replace function oyun.kanal_coz(p oyun.profiller, p_kanal text) returns text language plpgsql stable as $$
begin
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (select 'ittifak:' || u.ittifak_id from oyun.ittifak_uyeler u where u.parti_id = p.parti_id)
    else null end;
end $$;

create or replace function oyun.meclis_yazabilir(u uuid) returns boolean language sql stable as $$
  select exists (select 1 from oyun.makamlar where user_id = u and bit is null and tur in ('mv','cb','bakan'))
$$;

-- p_sonra: bu id'den yeni mesajlar (canlı takip) · p_once: bu id'den eski mesajlar (yukarı kaydırma)
create or replace function public.sohbet_oku(p_kanal text, p_once bigint default null, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', case when p_kanal = 'ittifak' then 'Partin bir ittifakta değil.' else 'Parti sohbeti için bir partiye üye olmalısın.' end; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'kad', coalesce(pr.kad, '(silinmiş)'), 'metin', x.metin, 'zaman', x.zaman,
            'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(x.user_id), 'benim', x.user_id = p.id) order by x.id), '[]'::jsonb)
    into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal = k and not m.gizli and m.zaman <= oyun.simdi() and not oyun.engelli(p.id, m.user_id)
      and (p_sonra is null or m.id > p_sonra) and (p_once is null or m.id < p_once)
    order by case when p_sonra is null then -m.id else m.id end
    limit case when p_sonra is null then 40 else 100 end
  ) x left join oyun.profiller pr on pr.id = x.user_id;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste,
    'yazabilir', case when p_kanal = 'meclis' then oyun.meclis_yazabilir(p.id) else true end,
    'baslik', case p_kanal when 'genel' then 'Türkiye Meydanı' when 'il' then (select ad from oyun.iller where id = p.il_id) || ' Kahvesi'
                           when 'parti' then (select ad from oyun.partiler where id = p.parti_id) when 'meclis' then 'TBMM Genel Kurulu'
                           when 'ittifak' then (select i.ad from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = p.parti_id) end);
end $$;

create or replace function public.sohbet_yaz(p_kanal text, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; m text;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', case when p_kanal = 'ittifak' then 'Partin bir ittifakta değil.' else 'Parti sohbeti için bir partiye üye olmalısın.' end; end if;
  if p_kanal = 'meclis' and not oyun.meclis_yazabilir(p.id) then
    raise exception 'Genel Kurul''da yalnızca milletvekilleri, bakanlar ve cumhurbaşkanı söz alabilir.';
  end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 500);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values (k, p.id, m, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- =====================================================================
--  ÖZEL MESAJ
-- =====================================================================
create or replace function public.ozel_liste() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  with ben as (select oyun.ben() id),
  m as (
    select o.*, case when o.gonderen = (select id from ben) then o.alici else o.gonderen end diger
    from oyun.ozel o where (o.gonderen = (select id from ben) or o.alici = (select id from ben)) and not o.gizli
  ),
  son as (select distinct on (diger) * from m order by diger, id desc)
  select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(pr.id),
           'son', s.metin, 'zaman', s.zaman, 'benden', s.gonderen = (select id from ben),
           'okunmamis', (select count(*) from m where m.diger = s.diger and m.alici = (select id from ben) and not m.okundu)) order by s.id desc), '[]'::jsonb)
  from son s join oyun.profiller pr on pr.id = s.diger
  where not oyun.engelli((select id from ben), s.diger)
$$;

create or replace function public.ozel_oku(p_kad text, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; liste jsonb;
begin
  h := oyun.profil_bul(p_kad);
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'metin', x.metin, 'zaman', x.zaman, 'benim', x.gonderen = p.id) order by x.id), '[]'::jsonb) into liste
  from (select * from oyun.ozel o
        where ((o.gonderen = p.id and o.alici = h.id) or (o.gonderen = h.id and o.alici = p.id)) and not o.gizli
          and (p_sonra is null or o.id > p_sonra)
        order by o.id desc limit 60) x;
  update oyun.ozel set okundu = true where alici = p.id and gonderen = h.id and not okundu;
  return jsonb_build_object('kad', h.kad, 'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'mesajlar', liste,
                            'engelledim', oyun.engelli(p.id, h.id));
end $$;

create or replace function public.ozel_yaz(p_kad text, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; m text;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendine mesaj gönderemezsin.'; end if;
  if oyun.engelli(h.id, p.id) or oyun.engelli(p.id, h.id) then raise exception 'Bu oyuncuyla mesajlaşamazsın (engelleme var).'; end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 1000);
  insert into oyun.ozel(gonderen, alici, metin, zaman) values (p.id, h.id, m, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- =====================================================================
--  PROPAGANDA YAYINLARI
--  Kim, kime, günde kaç kez:
--    Cumhurbaşkanı      → tüm Türkiye              1/gün  (Ulusa sesleniş)
--    Bakan              → tüm Türkiye              1/gün  (Bakanlık açıklaması)
--    Genel başkan       → partinin tüm üyeleri     3/gün  (Parti genelgesi)
--    GB yardımcısı      → partinin tüm üyeleri     1/gün
--    Milletvekili       → ilindeki herkes          1/gün
--    Belediye başkanı   → ilindeki herkes          1/gün
--    Aday (her seçim için ayrı, oylama bitene kadar) 1/gün:
--       ön seçim adayı  → partinin o ildeki üyeleri (vekil/belediye) ya da tüm üyeleri (kurultay/CB)
--       belediye adayı  → ildeki herkes · vekil listesi adayı → ildeki herkes · CB adayı → tüm Türkiye
-- =====================================================================
create or replace function oyun.yayin_secenekleri(p oyun.profiller, t timestamptz)
returns table(tur text, secim_id bigint, unvan text, hedef_il smallint, hedef_parti bigint, gunluk int)
language sql stable as $$
  select 'cb', null::bigint, 'Cumhurbaşkanı', null::smallint, null::bigint, 1
    from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null
  union all
  select 'bakan', null, replace(b.ad, 'Bakanlığı', 'Bakanı'), null, null, 1
    from oyun.makamlar m join oyun.bakanliklar b on b.kod = m.bakanlik where m.user_id = p.id and m.tur = 'bakan' and m.bit is null
  union all
  select 'parti', null, pa.kisa || ' Genel Başkanı', null, pa.id, 3 from oyun.partiler pa where pa.gb = p.id and not pa.kapali
  union all
  select 'parti', null, pa.kisa || ' Genel Başkan Yardımcısı', null, pa.id, 1
    from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id where g.user_id = p.id and pa.gb is distinct from p.id
  union all
  select 'vekil', null, i.ad || ' Milletvekili', m.il_id, null, 1
    from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = p.id and m.tur = 'mv' and m.bit is null
  union all
  select 'belediye', null, i.ad || ' Belediye Başkanı', m.il_id, null, 1
    from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = p.id and m.tur = 'bel' and m.bit is null
  union all
  -- adaylıklar (oylama bitene kadar)
  select 'aday', s.id,
         case s.tur when 'mv_on' then pa.kisa || ' ' || i.ad || ' milletvekili aday adayı'
                    when 'bel_on' then pa.kisa || ' ' || i.ad || ' belediye başkanı aday adayı'
                    when 'bel' then pa.kisa || ' ' || i.ad || ' Belediye Başkanı adayı'
                    when 'kurultay' then pa.kisa || ' genel başkan adayı'
                    when 'cb_on' then pa.kisa || ' cumhurbaşkanı aday adayı'
                    else 'Cumhurbaşkanı adayı' end,
         case when s.tur in ('mv_on','bel_on','bel') then a.il_id end,
         case when s.tur in ('mv_on','bel_on','kurultay','cb_on') then a.parti_id end,
         1
    from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
    left join oyun.partiler pa on pa.id = a.parti_id left join oyun.iller i on i.id = a.il_id
    where a.user_id = p.id and s.durum = 'bekliyor' and t < s.oy_bit
  union all
  -- genel seçimde partisinin listesinde olan aday
  select 'aday', g.id, pa.kisa || ' ' || i.ad || ' milletvekili adayı (' || a.sira || '. sıra)', a.il_id, null, 1
    from oyun.adaylar a join oyun.secimler o on o.id = a.secim_id and o.tur = 'mv_on'
    join oyun.secimler g on g.tur = 'mv' and g.donem = o.donem and g.durum = 'bekliyor' and t < g.oy_bit
    join oyun.partiler pa on pa.id = a.parti_id join oyun.iller i on i.id = a.il_id
    where a.user_id = p.id and a.sira is not null
$$;

create or replace function oyun.bugun_bas(t timestamptz) returns timestamptz language sql stable as $$
  select oyun.tr_an((t at time zone 'Europe/Istanbul')::date, 0)
$$;

create or replace function public.yayin_haklari() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((select jsonb_agg(jsonb_build_object(
      'tur', y.tur, 'secim_id', y.secim_id, 'unvan', y.unvan,
      'hedef', case when y.hedef_il is null and y.hedef_parti is null then 'Tüm Türkiye'
                    when y.hedef_parti is null then (select ad from oyun.iller where id = y.hedef_il) || '''deki tüm oyuncular'
                    when y.hedef_il is null then (select kisa from oyun.partiler where id = y.hedef_parti) || ' üyeleri'
                    else (select kisa from oyun.partiler where id = y.hedef_parti) || ' ' || (select ad from oyun.iller where id = y.hedef_il) || ' üyeleri' end,
      'kitle', (select count(*) from oyun.profiller x where x.id <> p.id
                  and (y.hedef_il is null or x.il_id = y.hedef_il) and (y.hedef_parti is null or x.parti_id = y.hedef_parti)),
      'gunluk', y.gunluk + oyun.bonus(p.il_id, 'yayin', t)::int,
      'kalan', greatest(0, y.gunluk + oyun.bonus(p.il_id, 'yayin', t)::int - (select count(*) from oyun.yayinlar k where k.gonderen = p.id and k.tur = y.tur
                  and k.secim_id is not distinct from y.secim_id and k.unvan = y.unvan and k.zaman >= oyun.bugun_bas(t))))
    order by y.tur, y.secim_id) from oyun.yayin_secenekleri(p, t) y), '[]'::jsonb);
end $$;

create or replace function public.yayin_gonder(p_tur text, p_metin text, p_secim bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); y record; m text; kullanilan int; kitle int;
begin
  select * into y from oyun.yayin_secenekleri(p, t) s where s.tur = p_tur and s.secim_id is not distinct from p_secim limit 1;
  if y.tur is null then raise exception 'Bu türde yayın yapma yetkin yok.'; end if;
  if p.susturma_bitis is not null and p.susturma_bitis > t then raise exception 'Hesabın şu anda yayın yapamaz (kural ihlali).'; end if;
  select count(*) into kullanilan from oyun.yayinlar k where k.gonderen = p.id and k.tur = y.tur
    and k.secim_id is not distinct from y.secim_id and k.unvan = y.unvan and k.zaman >= oyun.bugun_bas(t);
  if kullanilan >= y.gunluk + oyun.bonus(p.il_id, 'yayin', t)::int then
    -- satın alınmış ek yayın hakkı (reklam) varsa onu kullan
    perform oyun.cuzdanim(p.id);
    update oyun.cuzdan set reklam_kul = reklam_kul + 1 where user_id = p.id and reklam_n > reklam_kul;
    if not found then raise exception 'Bugünkü yayın hakkını kullandın. Yarın yeniden gönderebilir ya da Hayat ekranından ek yayın hakkı alabilirsin.'; end if;
  end if;
  m := oyun.metin_temizle(p_metin, 600);
  insert into oyun.yayinlar(tur, gonderen, metin, zaman, hedef_il, hedef_parti, secim_id, unvan)
  values (y.tur, p.id, m, t, y.hedef_il, y.hedef_parti, y.secim_id, y.unvan);
  select count(*) into kitle from oyun.profiller x where x.id <> p.id
    and (y.hedef_il is null or x.il_id = y.hedef_il) and (y.hedef_parti is null or x.parti_id = y.hedef_parti);
  return jsonb_build_object('tamam', true, 'kitle', kitle);
end $$;

-- Bildirim kutusu: bana ulaşan propaganda yayınları + kişisel bildirimler. Açınca okundu sayılır.
create or replace function public.bildirim_kutusu(p_limit int default 60) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); j jsonb; lim int := least(greatest(p_limit, 1), 100);
begin
  select coalesce(jsonb_agg(u.x order by u.z desc), '[]'::jsonb) into j from (
    (select jsonb_build_object('tur', 'yayin', 'id', y.id, 'yayin_tur', y.tur, 'zaman', y.zaman, 'metin', y.metin,
             'kad', coalesce(pr.kad, '(silinmiş)'), 'unvan', y.unvan, 'parti', oyun.parti_json(pr.parti_id),
             'benim', y.gonderen = p.id, 'yeni', y.zaman > p.bildirim_okundu and y.gonderen <> p.id) x, y.zaman z
     from oyun.yayinlar y left join oyun.profiller pr on pr.id = y.gonderen
     where not y.gizli and y.zaman <= t and oyun.yayin_gorur(y, p) and not oyun.engelli(p.id, y.gonderen)
     order by y.zaman desc limit lim)
    union all
    (select jsonb_build_object('tur', 'kisisel', 'id', b.id, 'zaman', b.zaman, 'metin', b.metin, 'yeni', b.zaman > p.bildirim_okundu) x, b.zaman z
     from oyun.bildirimler b where b.user_id = p.id and b.zaman <= t
     order by b.zaman desc limit lim)
  ) u;
  update oyun.profiller set bildirim_okundu = t where id = p.id;
  return j;
end $$;

create or replace function public.rozetler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
begin
  return oyun.okunmamis(oyun.profilim());
end $$;

-- =====================================================================
--  ENGELLEME VE ŞİKÂYET
--  3 farklı oyuncunun şikâyet ettiği mesaj/yayın otomatik gizlenir.
--  24 saatte 8 farklı oyuncudan şikâyet alan hesap 24 saat susturulur.
-- =====================================================================
create or replace function public.engelle(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendini engelleyemezsin.'; end if;
  insert into oyun.engellemeler(engelleyen, engellenen) values (p.id, h.id) on conflict do nothing;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.engel_kaldir(p_kad text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  delete from oyun.engellemeler where engelleyen = p.id and engellenen = h.id;
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.engellenenler() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad) order by pr.kad), '[]'::jsonb)
  from oyun.engellemeler e join oyun.profiller pr on pr.id = e.engellenen where e.engelleyen = oyun.ben()
$$;

create or replace function public.sikayet_et(p_tur text, p_id bigint, p_kad text, p_neden text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); hedef uuid; n int;
begin
  if p_neden not in ('hakaret','nefret','spam','taciz','uygunsuz','diger') then raise exception 'Geçersiz şikâyet nedeni.'; end if;
  if p_tur = 'mesaj' then select user_id into hedef from oyun.mesajlar where id = p_id;
  elsif p_tur = 'ozel' then select gonderen into hedef from oyun.ozel where id = p_id and alici = p.id;
  elsif p_tur = 'yayin' then select gonderen into hedef from oyun.yayinlar where id = p_id;
  elsif p_tur = 'oyuncu' then hedef := (oyun.profil_bul(p_kad)).id; p_id := null;
  else raise exception 'Geçersiz şikâyet türü.'; end if;
  if hedef is null then raise exception 'Şikâyet edilecek kayıt bulunamadı.'; end if;
  if hedef = p.id then raise exception 'Kendini şikâyet edemezsin.'; end if;
  insert into oyun.sikayetler(sikayetci, hedef_user, tur, kayit_id, neden, zaman)
  values (p.id, hedef, p_tur, coalesce(p_id, 0), p_neden, t) on conflict do nothing;
  -- kayıt bazında otomatik gizleme
  if p_tur in ('mesaj','ozel','yayin') then
    select count(distinct sikayetci) into n from oyun.sikayetler where tur = p_tur and kayit_id = p_id;
    if n >= 3 or p_tur = 'ozel' then
      if p_tur = 'mesaj' then update oyun.mesajlar set gizli = true where id = p_id;
      elsif p_tur = 'ozel' then update oyun.ozel set gizli = true where id = p_id;
      else update oyun.yayinlar set gizli = true where id = p_id; end if;
    end if;
  end if;
  -- hesap bazında otomatik susturma
  select count(distinct sikayetci) into n from oyun.sikayetler where hedef_user = hedef and zaman > t - interval '24 hours';
  if n >= 8 then
    update oyun.profiller set susturma_bitis = greatest(coalesce(susturma_bitis, t), t + interval '24 hours') where id = hedef;
  end if;
  return jsonb_build_object('tamam', true);
end $$;
