-- 2026-10-10 · GB yardımcılarının görev alanı yetki verir. Kaynak: gelistirici/sql/53_gby_gorev_yetki.sql
begin;
-- =====================================================================
--  53 · GENEL BAŞKAN YARDIMCISI GÖREVLERİNE YETKİ
--  Görev alanı (52) artık yetki de verir. Genel başkan her işi yapmaya devam eder; ek olarak:
--    • Teşkilattan Sorumlu      → il teşkilatı açar, Parti İl Başkanı atar/görevden alır.
--        Partide bu görevde yardımcı yoksa il teşkilatını eskisi gibi tüm yardımcılar açabilir.
--        Bu görevde biri varsa teşkilatı yalnız genel başkan ve o yardımcı açar.
--    • Seçim İşlerinden Sorumlu → miting yetkisi beklemeden 81 ilde parti mitingi düzenler, aday tanıtır.
--    • Tanıtım ve Medyadan Sorumlu → grup konuşması (parti duyurusu) yayımlar, aday tanıtır.
--    • Mali İşlerden Sorumlu    → parti kasasından üyeye kampanya desteği verir, adaylık ücretlerini ayarlar.
--    • Siyasi ve Hukuki İşlerden Sorumlu → üyeyi disipline sevk eder (genel başkanı sevk edemez).
--  Diğer görevler (ve serbest yazılanlar) unvandır, ek yetki vermez.
--  Fonksiyonlar canlıdaki hâllerinin üzerine kuruldu; yalnız yetki satırları değişti.
-- =====================================================================

-- Görev metni → yetki alanı
create or replace function oyun.gby_alan(p_gorev text) returns text language sql immutable set search_path = '' as $$
  select case btrim(coalesce(p_gorev, ''))
    when 'Teşkilattan Sorumlu' then 'teskilat'
    when 'Seçim İşlerinden Sorumlu' then 'secim'
    when 'Tanıtım ve Medyadan Sorumlu' then 'tanitim'
    when 'Mali İşlerden Sorumlu' then 'mali'
    when 'Siyasi ve Hukuki İşlerden Sorumlu' then 'hukuk'
  end
$$;

-- u, verilen alanlardan birinde partisi adına iş yapabiliyorsa partinin id'si (genel başkan her alanda yetkili)
create or replace function oyun.parti_gorevli(u uuid, p_alanlar text[]) returns bigint language sql stable set search_path = '' as $$
  select coalesce(
    (select pa.id from oyun.profiller p join oyun.partiler pa on pa.id = p.parti_id
      where p.id = u and pa.gb = u and not pa.kapali limit 1),
    (select pa.id from oyun.profiller p join oyun.parti_gby g on g.parti_id = p.parti_id and g.user_id = u
       join oyun.partiler pa on pa.id = p.parti_id
      where p.id = u and not pa.kapali and oyun.gby_alan(g.gorev) = any (p_alanlar) limit 1))
$$;

-- İl teşkilatı yöneticisi: genel başkan, Teşkilattan Sorumlu yardımcı; partide o görevde kimse yoksa her yardımcı
create or replace function oyun.teskilat_yonetici(u uuid, p_parti bigint) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.partiler where id = p_parti and gb = u and not kapali)
      or exists (select 1 from oyun.parti_gby g where g.parti_id = p_parti and g.user_id = u
                  and (oyun.gby_alan(g.gorev) = 'teskilat'
                       or not exists (select 1 from oyun.parti_gby x where x.parti_id = p_parti and oyun.gby_alan(x.gorev) = 'teskilat')))
$$;

-- Arayüz için: oturumdaki oyuncunun partide yetkili olduğu alanlar
create or replace function public.parti_yetkilerim() returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'parti_id', p.parti_id,
    'gb', exists (select 1 from oyun.partiler where id = p.parti_id and gb = p.id),
    'alanlar', to_jsonb(array(select a from unnest(array['teskilat','secim','tanitim','mali','hukuk']) a
                              where oyun.parti_gorevli(p.id, array[a]) = p.parti_id)),
    'teskilat_acar', p.parti_id is not null and oyun.teskilat_yonetici(p.id, p.parti_id))
  from oyun.profiller p where p.id = auth.uid()
$$;

-- Seçim İşlerinden Sorumlu yardımcı ayrıca miting yetkisi beklemez
create or replace function oyun.parti_miting_yetki(u uuid) returns text language sql stable set search_path = '' as $$
  select case
    when exists (select 1 from oyun.profiller p join oyun.partiler pa on pa.id = p.parti_id
                 where p.id = u and pa.gb = u and not pa.kapali) then 'gb'
    when exists (select 1 from oyun.profiller p join oyun.parti_gby g on g.parti_id = p.parti_id and g.user_id = u
                 join oyun.partiler pa on pa.id = p.parti_id
                 where p.id = u and (g.miting_yetkisi or oyun.gby_alan(g.gorev) = 'secim') and not pa.kapali) then 'gby'
  end
$$;


CREATE OR REPLACE FUNCTION public.teskilat_ac2(p_il integer, p_kaynak text DEFAULT 'parti'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  pa oyun.partiler;
  t timestamptz := oyun.simdi();
  ucret numeric;
  ilad text;
  yonetim boolean;
  gorevli boolean;
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali
  for update;

  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;

  yonetim := oyun.teskilat_yonetici(p.id, pa.id);   -- 53
  gorevli := exists(
    select 1 from oyun.parti_teskilat_gorev
    where parti_id = pa.id
      and il_id = p_il
      and user_id = p.id
      and aktif
  );

  if not yonetim and not gorevli then
    raise exception 'Bu ilde teşkilat açma yetkin yok.';
  end if;

  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;

  if gorevli and p.il_id is distinct from p_il::smallint then
    raise exception 'Teşkilat sorumlusu yalnızca kayıtlı olduğu il için ödeme yapabilir.';
  end if;

  if oyun.teskilat_var(pa.id, p_il::smallint) then
    raise exception 'Partinin % ilinde zaten teşkilatı var.', ilad;
  end if;

  ucret := oyun.teskilat_ucreti(p_il::smallint);

  if p_kaynak = 'parti' then
    if not yonetim then
      raise exception 'Parti kasasından ödemeyi yalnızca genel başkan veya yardımcısı yapabilir.';
    end if;
    if pa.kasa < ucret then
      raise exception 'Parti kasasında yeterli para yok (% ₺ gerekli).', oyun.tl(ucret);
    end if;

    update oyun.partiler set kasa = kasa - ucret where id = pa.id;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
    values (
      pa.id, t, -ucret,
      format('%s il teşkilatı açıldı · parti kasası · %s', ilad, p.kad),
      'teskilat'
    );

  elsif p_kaynak = 'kendi' then
    perform oyun.para_islem(
      p.id, -ucret, 'teskilat',
      format('%s %s il teşkilatı kuruluş bedeli', pa.kisa, ilad),
      t
    );
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
    values (
      pa.id, t, 0,
      format('%s il teşkilatı açıldı · %s kendi cüzdanından ödedi', ilad, p.kad),
      'teskilat_uye'
    );
  else
    raise exception 'Ödeme kaynağı parti veya kendi olmalı.';
  end if;

  insert into oyun.parti_teskilat(
    parti_id, il_id, kurulus, kuran, bedel
  ) values (pa.id, p_il, t, p.id, ucret);

  perform oyun.olay(
    'parti',
    format('%s, %s il teşkilatını açtı.', pa.kisa, ilad),
    p_il::smallint,
    pa.id,
    t
  );

  insert into oyun.bildirimler(user_id, zaman, metin)
  select
    id,
    t,
    format(
      '%s artık %s ilinde teşkilatlı: partin bu ilde milletvekili ve belediye başkanı adayı gösterebilir.',
      pa.kisa,
      ilad
    )
  from oyun.profiller
  where parti_id = pa.id
    and il_id = p_il
    and id <> p.id;

  return oyun.teskilat_json(pa.id, p);
end $function$;

CREATE OR REPLACE FUNCTION oyun.teskilat_json(p_parti bigint, p oyun.profiller)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'sayi', (select count(*) from oyun.parti_teskilat where parti_id = p_parti),
    'iller', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', t.il_id,
        'ad', i.ad,
        'kurulus', t.kurulus,
        'genel_merkez', t.genel_merkez,
        'uye', (select count(*) from oyun.profiller pr
                where pr.parti_id = p_parti and pr.il_id = t.il_id),
        'gorevli', (select oyun.kad(g.user_id)
                    from oyun.parti_teskilat_gorev g
                    where g.parti_id = p_parti
                      and g.il_id = t.il_id
                      and g.aktif)
      ) order by t.genel_merkez desc, i.ad)
      from oyun.parti_teskilat t
      join oyun.iller i on i.id = t.il_id
      where t.parti_id = p_parti
    ), '[]'::jsonb),
    'gorevler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', g.il_id,
        'ad', i.ad,
        'kad', oyun.kad(g.user_id),
        'atama', g.atama,
        'teskilat_acik', oyun.teskilat_var(p_parti, g.il_id)
      ) order by i.ad)
      from oyun.parti_teskilat_gorev g
      join oyun.iller i on i.id = g.il_id
      where g.parti_id = p_parti and g.aktif
    ), '[]'::jsonb),
    'benim_gorevler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', g.il_id,
        'ad', i.ad,
        'teskilat_acik', oyun.teskilat_var(p_parti, g.il_id),
        'ucret', oyun.teskilat_ucreti(g.il_id)
      ) order by i.ad)
      from oyun.parti_teskilat_gorev g
      join oyun.iller i on i.id = g.il_id
      where g.parti_id = p_parti and g.user_id = p.id and g.aktif
    ), '[]'::jsonb),
    'yetkili', p.parti_id = p_parti and oyun.teskilat_yonetici(p.id, p_parti),
    'gorev_verebilir', p.parti_id = p_parti and oyun.parti_gorevli(p.id, array['teskilat']) = p_parti,
    'zorunlu', (select teskilat_zorunlu from oyun.ayarlar where id = 1),
    'ucretler', jsonb_build_object(
      '1', round(a.teskilat_ucret * u.endeks),
      '2', round(a.teskilat_ucret * 2 * u.endeks),
      '3', round(a.teskilat_ucret * 3 * u.endeks)
    ),
    'kasa', (select round(kasa) from oyun.partiler where id = p_parti),
    'cuzdan', coalesce((select round(para) from oyun.cuzdan where user_id = p.id), 0),
    'benim_ilim_var', p.parti_id = p_parti
      and oyun.teskilat_var(p_parti, p.il_id)
  )
  from oyun.ayarlar a, oyun.ulke u
  where a.id = 1 and u.id = 1
$function$;

CREATE OR REPLACE FUNCTION public.teskilat_gorev_ver(p_il integer, p_kad text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  h oyun.profiller;
  pa oyun.partiler;
  t timestamptz:=oyun.simdi();
  ilad text;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali;
  if pa.id is null or oyun.parti_gorevli(p.id, array['teskilat']) is distinct from pa.id then
    raise exception 'Parti il başkanını yalnızca genel başkan ve Teşkilattan Sorumlu Genel Başkan Yardımcısı atayabilir.';
  end if;

  h:=oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pa.id then raise exception 'Yalnızca kendi partinin üyesini il başkanı yapabilirsin.'; end if;
  if h.il_id is distinct from p_il::smallint then raise exception 'İl başkanı, görev yapacağı ilde kayıtlı olmalı.'; end if;

  select ad into ilad from oyun.iller where id=p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;

  insert into oyun.parti_teskilat_gorev(parti_id,il_id,user_id,atayan,atama,aktif)
  values(pa.id,p_il,h.id,p.id,t,true)
  on conflict(parti_id,il_id) do update
    set user_id=excluded.user_id,atayan=excluded.atayan,atama=excluded.atama,aktif=true;

  perform oyun.bildir(h.id,
    format('%s %s seni %s Parti İl Başkanı yaptı. Milletvekili olsan da bu görev devam eder. Teşkilat henüz açılmadıysa kuruluş bedelini kendi cüzdanından ödeyebilirsin.',
      case when pa.gb=p.id then pa.kisa||' Genel Başkanı' else oyun.gby_unvan(p.id) end,p.kad,ilad),t);

  return oyun.teskilat_json(pa.id,p);
end $function$;

CREATE OR REPLACE FUNCTION public.teskilat_gorev_al(p_il integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  pa oyun.partiler;
  h uuid;
  t timestamptz:=oyun.simdi();
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali;
  if pa.id is null or oyun.parti_gorevli(p.id, array['teskilat']) is distinct from pa.id then
    raise exception 'Bu görevi yalnızca genel başkan ve Teşkilattan Sorumlu Genel Başkan Yardımcısı kaldırabilir.';
  end if;

  select user_id into h from oyun.parti_teskilat_gorev
  where parti_id=pa.id and il_id=p_il and aktif for update;

  update oyun.parti_teskilat_gorev set aktif=false
  where parti_id=pa.id and il_id=p_il and aktif;

  if h is not null then perform oyun.bildir(h,'Parti İl Başkanlığı görevin sona erdirildi.',t); end if;
  return oyun.teskilat_json(pa.id,p);
end $function$;

CREATE OR REPLACE FUNCTION public.parti_destek(p_kad text, p_miktar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; pa oyun.partiler; m numeric := round(coalesce(p_miktar, 0));
begin
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.id is null or oyun.parti_gorevli(p.id, array['mali']) is distinct from pa.id then
    raise exception 'Parti kasasını yalnızca genel başkan ve Mali İşlerden Sorumlu Genel Başkan Yardımcısı kullanabilir.';
  end if;
  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pa.id then raise exception 'Yalnızca kendi partinin üyelerine destek verebilirsin.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ destek verebilirsin.'; end if;
  if pa.kasa < m then raise exception 'Parti kasasında yeterli para yok (kasada % ₺ var).', oyun.tl(pa.kasa); end if;
  update oyun.partiler set kasa = kasa - m where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -m, format('%s üyesine kampanya desteği', h.kad), 'destek');
  perform oyun.para_islem(h.id, m, 'parti_destek', format('%s kampanya desteği', pa.kisa), t);
  perform oyun.bildir(h.id, format('%s %s, parti kasasından sana %s ₺ kampanya desteği gönderdi.', coalesce(oyun.unvan(p.id), 'Parti yönetiminden'), p.kad, oyun.tl(m)), t);
  return public.parti_kasa(pa.id);
end $function$;

CREATE OR REPLACE FUNCTION public.parti_ucret_ayarla(p_ucret jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; k text; v jsonb := '{}'; x numeric;
begin
  select * into pa from oyun.partiler where id = p.parti_id for update;
  if pa.id is null or oyun.parti_gorevli(p.id, array['mali']) is distinct from pa.id then
    raise exception 'Aday ücretlerini yalnızca genel başkan ve Mali İşlerden Sorumlu Genel Başkan Yardımcısı belirler.';
  end if;
  foreach k in array array['mv_on','bel_on','kurultay','cb_on'] loop
    x := round(coalesce((p_ucret ->> k)::numeric, (pa.aday_ucret ->> k)::numeric, 1), 2);
    if x < 0 or x > 3 then raise exception 'Çarpanlar 0 ile 3 arasında olmalı.'; end if;
    v := v || jsonb_build_object(k, x);
  end loop;
  update oyun.partiler set aday_ucret = v where id = pa.id;
  perform oyun.olay('parti', format('%s aday adaylığı ücretlerini güncelledi.', pa.kisa), null, pa.id, t);
  return public.parti_kasa(pa.id);
end $function$;

CREATE OR REPLACE FUNCTION public.parti_aday_tanit(p_aday bigint, p_kitle text, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); p oyun.partiler; a oyun.adaylar; s oyun.secimler;
 t timestamptz:=oyun.simdi(); metin text:=btrim(coalesce(p_metin,'')); newid bigint;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 select * into p from oyun.partiler where id=oyun.parti_gorevli(u, array['secim','tanitim']) and not kapali;
 if not found then raise exception 'Adayları genel başkan ile Seçim İşlerinden ya da Tanıtım ve Medyadan Sorumlu Genel Başkan Yardımcısı tanıtabilir';end if;
 if p_kitle not in ('herkes','uyeler') or p_kitle is null then raise exception 'Tanıtım kitlesi geçersiz';end if;
 if length(metin)<20 or length(metin)>600 then raise exception 'Tanıtım 20-600 karakter olmalı';end if;
 select * into a from oyun.adaylar where id=p_aday;
 if not found then raise exception 'Aday kaydı bulunamadı';end if;
 select * into s from oyun.secimler where id=a.secim_id;
 if s.tur not in ('mv_on','cb_on','cb','bel_on','bel')
   or s.durum<>'bekliyor' or s.oy_bit<=t or s.basvuru_bas>t and s.tur in ('mv_on','cb_on','bel_on')
 then raise exception 'Bu seçimde aday tanıtım zamanı kapalı';end if;
 if a.parti_id is distinct from p.id
 and not (
   (s.tur='cb' and exists(select 1 from oyun.cb_kararlar k
      where k.donem=s.donem and k.parti_id=p.id and k.yontem='destek' and k.destek_parti=a.parti_id))
   or
   (s.tur='bel' and exists(select 1 from oyun.bel_aday_destek b
      where b.secim_id=s.id and b.parti_id=p.id and b.aday_id=a.id))
 ) then raise exception 'Yalnızca kendi partinin veya resmen desteklediğin adayı tanıtabilirsin';end if;
 if (select count(*) from oyun.parti_aday_tanitim where parti_id=p.id and zaman>=t-interval '24 hours')>=3
 then raise exception 'Partin 24 saatte en fazla 3 aday tanıtımı yapabilir';end if;
 insert into oyun.parti_aday_tanitim(parti_id,aday_id,kitle,metin,yayinlayan,zaman)
 values(p.id,a.id,p_kitle,metin,u,t) returning id into newid;
 if p_kitle='herkes' then
  perform oyun.olay('parti',left(p.kisa||' aday tanıtımı: '||oyun.kad(a.user_id),120),null,p.id,t);
 end if;
 return jsonb_build_object('tamam',true,'id',newid,'parti_id',p.id,'kitle',p_kitle);
end $function$;

CREATE OR REPLACE FUNCTION public.grup_duyuru_yayinla(p_baslik text, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); pid bigint; bas text:=btrim(coalesce(p_baslik,'')); msg text:=btrim(coalesce(p_metin,''));
begin
 pid := oyun.parti_gorevli(u, array['tanitim']);
 if u is null or pid is null then raise exception 'Grup konuşmasını genel başkan ve Tanıtım ve Medyadan Sorumlu Genel Başkan Yardımcısı yayımlayabilir'; end if;
 if length(bas) not between 5 and 120 or length(msg) not between 10 and 3000 then raise exception 'Başlık 5-120, metin 10-3000 karakter olmalı'; end if;
 if (select count(*) from oyun.parti_grup_duyuru where yazan=u and zaman>now()-interval '1 day')>=3 then raise exception '24 saatte en çok 3 konuşma yayımlayabilirsin'; end if;
 insert into oyun.parti_grup_duyuru(parti_id,yazan,baslik,metin) values(pid,u,bas,msg);
 insert into oyun.bildirimler(user_id,zaman,metin)
 select id,now(),coalesce(oyun.unvan(u),'Partinin yönetimi')||' yeni grup konuşması yayımladı: '||left(bas,80)
 from oyun.profiller where parti_id=pid and id<>u;
 perform oyun.olay('parti','Yeni grup toplantısı konuşması: '||left(bas,100),null,pid,now());
 return public.grup_duyurulari(pid);
end $function$;

CREATE OR REPLACE FUNCTION public.disiplin_baslat(p_hedef text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); pid bigint; hedef uuid; cnt int; gerekce text:=btrim(coalesce(p_gerekce,''));
begin
 perform oyun.disiplin_sonuclandir();
 pid := oyun.parti_gorevli(u, array['hukuk']);
 if u is null or pid is null then raise exception 'Disiplin sürecini genel başkan ve Siyasi ve Hukuki İşlerden Sorumlu Genel Başkan Yardımcısı başlatabilir'; end if;
 if length(gerekce) not between 10 and 500 then raise exception 'Gerekçe 10-500 karakter olmalı'; end if;
 select id into hedef from oyun.profiller where lower(kad)=lower(btrim(p_hedef)) and parti_id=pid;
 if hedef is null or hedef=u then raise exception 'Bu partideki başka bir üyeyi seçmelisin'; end if;
 if exists (select 1 from oyun.partiler where id=pid and gb=hedef) then raise exception 'Genel başkan disipline sevk edilemez'; end if;
 select count(*) into cnt from oyun.profiller where parti_id=pid and id<>hedef;
 if cnt<1 then raise exception 'Oylamaya katılacak üye yok'; end if;
 insert into oyun.parti_disiplin(parti_id,hedef,baslatan,gerekce,bit,uyeler)
 values(pid,hedef,u,gerekce,now()+interval '24 hours',cnt);
 perform oyun.bildir(hedef,'Hakkında 24 saatlik parti disiplin oylaması başlatıldı.',now());
 return public.disiplin_durum(pid);
end $function$;


revoke all on function public.parti_yetkilerim() from public, anon;
grant execute on function public.parti_yetkilerim() to authenticated;
revoke all on function oyun.parti_gorevli(uuid, text[]), oyun.teskilat_yonetici(uuid, bigint) from public, anon, authenticated;
commit;
