-- Anayasal basamaklari UI tarafina gecir; CB anayasa geri gonderme butonu icin.
CREATE OR REPLACE FUNCTION public.kanun_detay(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; dolu int := oyun.tbmm_tamsayi();
  v_oy_sayisi int; v_katilim int;
begin
  select * into k from oyun.kanunlar where id = p_id;
  if k.id is null then raise exception 'Kanun bulunamadı.'; end if;
  v_katilim := case when oyun.gercekci_siyaset() then ceil(dolu/3.0)::int else greatest(1,ceil(dolu/2.0)::int) end;
  select count(*) into v_oy_sayisi from oyun.kanun_oylari
  where kanun_id = k.id and asama = case when k.durum='israr' then 'israr' else 'ilk' end;
  return oyun.kanun_ozet(k, p, t) || jsonb_build_object(
    'gercekci', oyun.gercekci_siyaset(), 'metin', k.metin, 'veri', k.veri, 'veto_gerekce', k.veto_gerekce, 'sonuc_metin', k.sonuc_metin,
    'kararname', case when k.tur = 'iptal' then (select jsonb_build_object('no', no, 'baslik', baslik) from oyun.kararnameler where id = (k.veri ->> 'kararname_id')::bigint) end,
    'dolu', dolu, 'toplanti_yeter', case when k.tur='anayasa' then ceil(dolu/3.0) else v_katilim end,
    'karar_yeter', case when k.tur='anayasa' then ceil(dolu*3/5.0) when oyun.gercekci_siyaset() then greatest(floor(v_oy_sayisi/2.0)+1,floor(dolu/4.0)+1) else floor(greatest(v_oy_sayisi,v_katilim)/2.0)+1 end,
    'israr_yeter', case when oyun.gercekci_siyaset() then case when k.tur='anayasa' then ceil(dolu*2/3.0) else floor(dolu/2.0)+1 end else floor(greatest(v_oy_sayisi,v_katilim)/2.0)+1 end,
    'kullanilan_oy', v_oy_sayisi,
    'vekilim', oyun.aktif_vekil(p.id),
    'oy_acik', (k.durum = 'oylamada' and t >= k.oy_bas and t < k.oy_bit) or (k.durum = 'israr' and t < k.israr_bit),
    'benim_oyum', (select oy from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = case when k.durum = 'israr' then 'israr' else 'ilk' end),
    'cb_karar_verebilir', k.durum = 'cb_onayinda' and t < k.cb_bit and oyun.aktif_cb() = p.id,
    'anayasa_aciklama', case when k.tur = 'anayasa' then oyun.anayasa_aciklama(k.veri) end,
    'grup', oyun.grup_karar_json(k.id, p), 'tbmm_baskani', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null),
    'duzenleme', case when k.tur = 'duzenleme' then (select jsonb_build_object('ad', d.ad, 'yazi', oyun.duz_yaz(d.kod, (k.veri ->> 'deger')::numeric),
                    'mevcut', oyun.duz_yaz(d.kod, oyun.duz(d.kod)), 'oyuncu', d.oyuncu, 'devlet', d.devlet) from oyun.duzenleme_tanim d where d.kod = k.veri ->> 'kod') end,
    'imza_yeter', ceil(dolu / 3.0), 'uc_bes', ceil(dolu * 3 / 5.0), 'iki_uc', ceil(dolu * 2 / 3.0),
    'imzaladim', exists (select 1 from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = 'imza'),
    'referandum', (select jsonb_build_object('id', r.id, 'oy_bas', r.oy_bas, 'durum', r.durum, 'sonuc', r.sonuc) from oyun.referandumlar r where r.kanun_id = k.id),
    'benim', k.teklif_eden = p.id,
    'oylar', (select jsonb_object_agg(a.asama, a.j) from (
       select o.asama, jsonb_build_object(
         'kabul', count(*) filter (where o.oy = 'kabul'), 'ret', count(*) filter (where o.oy = 'ret'), 'cekimser', count(*) filter (where o.oy = 'cekimser'),
         'liste', case when k.tur = 'anayasa' and o.asama = 'ilk' then '[]'::jsonb
                       else jsonb_agg(jsonb_build_object('kad', oyun.kad(o.vekil), 'oy', o.oy, 'parti', oyun.parti_json(o.parti_id),
                              'aykiri', o.asama <> 'imza' and exists (select 1 from oyun.grup_kararlari g where g.kanun_id = k.id and g.parti_id = o.parti_id
                                                                         and g.karar in ('kabul','ret') and g.karar <> o.oy)) order by o.parti_id, o.zaman) end) j
       from oyun.kanun_oylari o where o.kanun_id = k.id group by o.asama) a));
end $function$
;