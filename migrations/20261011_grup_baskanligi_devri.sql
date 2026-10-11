-- Parti Meclis Grubu Başkanlığını görevdeki başkan, GB olmayan bir MV'ye devredebilir.
-- İlk açılışta mevcut kurala göre milletvekili olan genel başkan görevini sürdürür.
-- Oyuncu, makam, seçim, oy ve cüzdan kayıtları değiştirilmez.
BEGIN;
CREATE TABLE IF NOT EXISTS oyun.grup_baskan_atamalari (
  parti_id bigint PRIMARY KEY REFERENCES oyun.partiler(id),
  user_id uuid NOT NULL REFERENCES oyun.profiller(id),
  mv_makam_id bigint NOT NULL REFERENCES oyun.makamlar(id),
  devreden uuid NOT NULL REFERENCES oyun.profiller(id),
  zaman timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE oyun.grup_baskan_atamalari ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.grup_baskan_atamalari FROM PUBLIC,anon,authenticated;
DO $block$
BEGIN
 IF to_regprocedure('oyun.bosaltma_korumasi()') IS NOT NULL THEN
   DROP TRIGGER IF EXISTS bosaltma_korumasi ON oyun.grup_baskan_atamalari;
   CREATE TRIGGER bosaltma_korumasi BEFORE TRUNCATE ON oyun.grup_baskan_atamalari
     FOR EACH STATEMENT EXECUTE FUNCTION oyun.bosaltma_korumasi();
 END IF;
END $block$;

-- Aktif milletvekili ve aynı partinin üyesi ise devir geçerlidir; eski dönem devri taşınmaz.
-- Devir henüz yoksa mevcut uygulamanın kuralı (MV olan genel başkan) geçerli kalır.
CREATE OR REPLACE FUNCTION oyun.grup_baskani(p_parti bigint)
RETURNS uuid LANGUAGE sql STABLE SET search_path TO '' AS $baskan$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM oyun.gruplar() g WHERE g.parti_id=p_parti)
  THEN COALESCE(
    (SELECT a.user_id FROM oyun.grup_baskan_atamalari a
       JOIN oyun.makamlar m ON m.id=a.mv_makam_id AND m.user_id=a.user_id AND m.tur='mv' AND m.bit IS NULL
       JOIN oyun.profiller pr ON pr.id=a.user_id AND pr.parti_id=a.parti_id
       JOIN oyun.partiler pa2 ON pa2.id=a.parti_id AND a.user_id IS DISTINCT FROM pa2.gb
       WHERE a.parti_id=p_parti LIMIT 1),
    (SELECT pa.gb FROM oyun.partiler pa
       JOIN oyun.profiller pr ON pr.id=pa.gb AND pr.parti_id=pa.id
       WHERE pa.id=p_parti AND EXISTS (
         SELECT 1 FROM oyun.makamlar m WHERE m.user_id=pa.gb AND m.tur='mv' AND m.bit IS NULL
       ))
  ) END
$baskan$;

-- Görevi sadece o partinin hali hazırdaki grup başkanı devreder.
CREATE OR REPLACE FUNCTION public.grup_baskan_devret(p_hedef uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'oyun','public','pg_temp' AS $devret$
DECLARE
 p oyun.profiller := oyun.profilim();
 pid bigint;
 m_id bigint;
 t timestamptz := oyun.simdi();
 hedef_ad text;
 parti_kisa text;
BEGIN
 IF p_hedef IS NULL OR p_hedef=p.id THEN RAISE EXCEPTION 'Devralacak farklı bir milletvekili seçmelisin.'; END IF;
 SELECT g.parti_id INTO pid FROM oyun.gruplar() g
 WHERE oyun.grup_baskani(g.parti_id)=p.id LIMIT 1;
 IF pid IS NULL THEN RAISE EXCEPTION 'Grup başkanlığı devrini yalnızca görevdeki grup başkanı yapabilir.'; END IF;

 -- Aynı grubun iki eşzamanlı devrini engelle ve kilit sonrası yetkiyi yeniden doğrula.
 PERFORM 1 FROM oyun.partiler WHERE id=pid FOR UPDATE;
 IF oyun.grup_baskani(pid) IS DISTINCT FROM p.id THEN
   RAISE EXCEPTION 'Grup başkanlığı görevin değişti. Sayfayı yenile.'; END IF;
 IF EXISTS (SELECT 1 FROM oyun.partiler WHERE id=pid AND gb=p_hedef) THEN
   RAISE EXCEPTION 'Partinin genel başkanı grup başkanlığını devralamaz.'; END IF;
 SELECT m.id,pr.kad INTO m_id,hedef_ad FROM oyun.makamlar m
 JOIN oyun.profiller pr ON pr.id=m.user_id
 WHERE m.user_id=p_hedef AND m.tur='mv' AND m.bit IS NULL AND pr.parti_id=pid
 ORDER BY m.bas DESC,m.id DESC LIMIT 1;
 IF m_id IS NULL THEN RAISE EXCEPTION 'Seçilen kişi bu partinin görevdeki milletvekili olmalı.'; END IF;
 SELECT kisa INTO parti_kisa FROM oyun.partiler WHERE id=pid;
 INSERT INTO oyun.grup_baskan_atamalari(parti_id,user_id,mv_makam_id,devreden,zaman)
 VALUES(pid,p_hedef,m_id,p.id,t)
 ON CONFLICT(parti_id) DO UPDATE SET user_id=excluded.user_id,
    mv_makam_id=excluded.mv_makam_id,devreden=excluded.devreden,zaman=excluded.zaman;

 INSERT INTO oyun.bildirimler(user_id,zaman,metin)
 SELECT DISTINCT m.user_id,t,
    format('%s Meclis Grubu Başkanlığı %s tarafından %s adlı milletvekiline devredildi.',
      parti_kisa,p.kad,hedef_ad)
 FROM oyun.makamlar m JOIN oyun.profiller pr ON pr.id=m.user_id
 WHERE m.tur='mv' AND m.bit IS NULL AND pr.parti_id=pid;

 PERFORM oyun.olay('meclis',
   format('%s Meclis grubu başkanlığı: %s görevi %s adlı milletvekiline devretti.',parti_kisa,p.kad,hedef_ad),
   NULL,pid,t);
 RETURN jsonb_build_object('ok',true,'parti_id',pid,'baskan',hedef_ad);
END $devret$;
REVOKE ALL ON FUNCTION public.grup_baskan_devret(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.grup_baskan_devret(uuid) TO authenticated;

-- Devreden başkanın yerine yeni başkan grup kararları imzalayabilsin.
CREATE OR REPLACE FUNCTION oyun.grup_karar_yetkisi(u uuid)
 RETURNS bigint
 LANGUAGE sql
 STABLE
AS $function$
  select pid from (
    select m.parti_id pid from oyun.makamlar m where m.user_id = u and m.tur = 'grup_bskv' and m.bit is null
    union all select g.parti_id from oyun.gruplar() g where oyun.grup_baskani(g.parti_id) = u) x
  where pid in (select g.parti_id from oyun.gruplar() g) limit 1
$function$;

-- Meclis başkanlık vitrini, ayrıntılı gruplar ve milletvekili görev etiketleri yeni başkanı göstersin.
CREATE OR REPLACE FUNCTION public.meclis_baskanlik()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); dolu int := oyun.dolu_sandalye();
begin
  -- Sayfa her açıldığında süresi dolan turları ilerlet; cron gecikmesi sonucu etkilemesin.
  perform oyun.meclis_tick(t);
  return jsonb_build_object(
    'baskan', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id), 'bas', m.bas) from oyun.makamlar m where m.tur = 'tbmm' and m.bit is null limit 1),
    'gecici', case when oyun.tbmm_baskani() is null then oyun.kad(oyun.gecici_baskan()) end,
    'baskanvekilleri', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(m.parti_id)) order by m.bas)
                                 from oyun.makamlar m where m.tur = 'bskv' and m.bit is null), '[]'::jsonb),
    'grup_esigi', oyun.grup_esigi(dolu), 'dolu', dolu,
    'gruplar', coalesce((select jsonb_agg(jsonb_build_object('parti', oyun.parti_json(g.parti_id), 'vekil', g.vekil, 'sira', g.sira,
                   'baskan', oyun.kad(oyun.grup_baskani(g.parti_id)),
                   'bskv', coalesce((select jsonb_agg(oyun.kad(m.user_id) order by m.bas) from oyun.makamlar m where m.tur = 'grup_bskv' and m.bit is null and m.parti_id = g.parti_id), '[]'::jsonb))
                 order by g.sira) from oyun.gruplar() g), '[]'::jsonb),
    'secimler', coalesce((select jsonb_agg(oyun.meclis_secim_json(s, p, t) order by (s.tur = 'baskan') desc, s.id)
                          from oyun.meclis_secim s where s.durum <> 'bitti' or s.id in (select max(id) from oyun.meclis_secim where tur = 'baskan')), '[]'::jsonb),
    'yetkim', jsonb_build_object(
       'ihtar', exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv')) or (oyun.tbmm_baskani() is null and oyun.gecici_baskan() = p.id),
       'grup_karari', oyun.grup_karar_yetkisi(p.id) is not null, 'vekil', oyun.aktif_vekil(p.id)));
end $function$;
CREATE OR REPLACE FUNCTION public.meclis_rehber()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with v as (
  select m.user_id, m.il_id, m.bas, m.parti_id as secildigi, pr.kad, pr.parti_id as parti
  from oyun.makamlar m
  join oyun.profiller pr on pr.id = m.user_id
  where m.tur = 'mv' and m.bit is null
),
sayi as (select count(*)::int as dolu from v),
g as (select * from oyun.gruplar()),
gorev as (
  select v.user_id, jsonb_agg(x.g order by x.s) as liste
  from v
  join lateral (
    select 1 as s, 'TBMM Başkanı' as g
      where exists (select 1 from oyun.makamlar m where m.user_id = v.user_id and m.tur = 'tbmm' and m.bit is null)
    union all
    select 2, 'TBMM Başkanvekili'
      where exists (select 1 from oyun.makamlar m where m.user_id = v.user_id and m.tur = 'bskv' and m.bit is null)
    union all
    select 3, 'Genel Başkan'
      where exists (select 1 from oyun.partiler pa where pa.gb = v.user_id and not pa.kapali)
    union all
    select 3, 'Grup Başkanı'
      where exists (select 1 from oyun.gruplar() gp where gp.parti_id = v.parti and oyun.grup_baskani(gp.parti_id) = v.user_id)
    union all
    select 4, 'Grup Başkanvekili'
      where exists (select 1 from oyun.makamlar m where m.user_id = v.user_id and m.tur = 'grup_bskv' and m.bit is null)
    union all
    select 5, coalesce(b.ad, 'Bakan')
      from oyun.makamlar m left join oyun.bakanliklar b on b.kod = m.bakanlik
      where m.user_id = v.user_id and m.tur = 'bakan' and m.bit is null
    union all
    select 6, 'Genel Başkan Yardımcısı'
      where exists (select 1 from oyun.parti_gby y where y.user_id = v.user_id)
  ) x on true
  group by v.user_id
),
partiler as (
  select v.parti as id, count(*)::int as n from v where v.parti is not null group by v.parti
)
select jsonb_build_object(
  'toplam', coalesce((select sum(i.mv)::int from oyun.iller i), 600),
  'dolu', (select dolu from sayi),
  'bagimsiz', (select count(*)::int from v where v.parti is null),
  'cogunluk', (select dolu / 2 + 1 from sayi),
  'grup_esigi', oyun.grup_esigi((select dolu from sayi)),
  'baskan', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(pr.parti_id))
             from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
             where m.tur = 'tbmm' and m.bit is null limit 1),
  'gecici', case when oyun.tbmm_baskani() is null then oyun.kad(oyun.gecici_baskan()) end,
  'baskanvekilleri', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', oyun.parti_json(pr.parti_id)) order by m.bas)
             from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
             where m.tur = 'bskv' and m.bit is null), '[]'::jsonb),
  'partiler', coalesce((select jsonb_agg(oyun.parti_json(p.id) || jsonb_build_object(
        'n', p.n,
        'grup', g.parti_id is not null,
        'sira', g.sira,
        'gb', (select pr.kad from oyun.partiler pa join oyun.profiller pr on pr.id = pa.gb where pa.id = p.id),
        'gb_vekil', exists (select 1 from oyun.partiler pa join v on v.user_id = pa.gb where pa.id = p.id),
        'baskan', case when g.parti_id is not null then oyun.kad(oyun.grup_baskani(p.id)) end,
        'baskan_benim', g.parti_id is not null and oyun.grup_baskani(p.id) = auth.uid(),
        'devir_adaylari', case when g.parti_id is not null and oyun.grup_baskani(p.id) = auth.uid()
           then coalesce((select jsonb_agg(jsonb_build_object('id',pr.id,'kad',pr.kad) order by pr.kad)
             from oyun.profiller pr join oyun.makamlar mm on mm.user_id=pr.id and mm.tur='mv' and mm.bit is null
             where pr.parti_id=p.id and pr.id is distinct from (select gb from oyun.partiler where id=p.id)
                and pr.id<>auth.uid()),'[]'::jsonb)
           else '[]'::jsonb end,
        'bskv', coalesce((select jsonb_agg(pr.kad order by m.bas) from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
                          where m.tur = 'grup_bskv' and m.bit is null and m.parti_id = p.id), '[]'::jsonb),
        'bskv_kota', case when g.parti_id is null then 0 when p.n * 6 > (select dolu from sayi) then 3 else 2 end)
      order by p.n desc, p.id)
    from partiler p left join g on g.parti_id = p.id), '[]'::jsonb),
  'sozluk', coalesce((select jsonb_object_agg(x.id::text, oyun.parti_json(x.id))
    from (select parti as id from v where parti is not null union select secildigi from v where secildigi is not null) x), '{}'::jsonb),
  'iller', coalesce((select jsonb_agg(jsonb_build_object(
        'id', i.id, 'ad', i.ad, 'kontenjan', i.mv,
        'vekiller', coalesce((select jsonb_agg(jsonb_build_object(
              'kad', v.kad,
              'parti_id', v.parti,
              'secildigi_id', case when v.secildigi is distinct from v.parti then v.secildigi end,
              'bagimsiz_secildi', v.secildigi is null,
              'bas', v.bas,
              'gorevler', coalesce(gr.liste, '[]'::jsonb))
            order by v.parti nulls last, v.kad)
          from v left join gorev gr on gr.user_id = v.user_id where v.il_id = i.id), '[]'::jsonb))
      order by i.id)
    from oyun.iller i), '[]'::jsonb)
)
$function$;
NOTIFY pgrst,'reload schema';
COMMIT;
