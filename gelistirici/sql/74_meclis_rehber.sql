-- =====================================================================
--  74 · MECLİS REHBERİ (yalnız okuma)
--
--  Devlet › Meclis ekranındaki rehber için tek çağrı:
--   • Meclis'teki partiler, sandalye sayıları, grup durumu
--   • TBMM Başkanı / Geçici Başkan, başkanvekilleri
--   • Her grubun grup başkanı (milletvekili olan genel başkan) ve grup başkanvekilleri
--   • 81 il: kontenjan, dolu sandalye, vekillerin adı, bugünkü partisi,
--     seçildiği liste (parti değiştirdiyse) ve Meclis/parti/hükümet görevleri
--
--  Hiçbir tabloyu değiştirmez; yeni tablo/sütun yoktur. Vekilin partisi
--  "bugünkü parti"dir (oyun.gruplar() ile aynı kural): partisinden istifa
--  eden vekil bağımsız görünür, seçildiği liste ayrıca gösterilir.
-- =====================================================================

create or replace function public.meclis_rehber() returns jsonb
language sql stable security definer set search_path = '' as $$
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
$$;

revoke all on function public.meclis_rehber() from public, anon;
grant execute on function public.meclis_rehber() to authenticated;
