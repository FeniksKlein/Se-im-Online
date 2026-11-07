-- Gozalti hakim on incelemesi: aninda serbest birakma ya da mevcut sureyi onaylama.
-- Tutuklama/hukmu uzatma degildir; mahkemeye itiraz hakki korunur.
alter table oyun.sokak_gozalti add column if not exists on_inceleme_karari text
 check (on_inceleme_karari is null or on_inceleme_karari in ('serbest','devam'));
alter table oyun.sokak_gozalti add column if not exists on_inceleme_hakim uuid references oyun.profiller(id);
alter table oyun.sokak_gozalti add column if not exists on_inceleme_gerekce text;
alter table oyun.sokak_gozalti add column if not exists on_inceleme_zaman timestamptz;

CREATE OR REPLACE FUNCTION public.sokak_gozalti_hakim_incele(p_gozalti bigint, p_karar text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 u uuid:=auth.uid(); g oyun.sokak_gozalti; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.adliye_makam where hakim=u)
 then raise exception 'Yalnız görevli hâkim inceleme yapabilir';end if;
 if p_karar not in ('serbest','devam') or p_karar is null or
 length(btrim(coalesce(p_gerekce,''))) not between 25 and 700 then
 raise exception 'Karar türü ve 25–700 karakter gerekçe gereklidir';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.durum<>'aktif' or g.bitis<=t or g.karar is not null
 then raise exception 'Hâkim ön incelemesine uygun aktif gözaltı yok';end if;
 if g.on_inceleme_karari is not null then raise exception 'Bu dosyada ön inceleme kararı verilmiş';end if;
 if u=g.hedef or u is not distinct from g.avukat or
 exists(select 1 from oyun.sokak_polis where id=g.polis_id and yapan=u)
 then raise exception 'Çıkar çatışması: bu hâkim dosyayı inceleyemez';end if;
 update oyun.sokak_gozalti set
  on_inceleme_karari=p_karar,on_inceleme_hakim=u,
  on_inceleme_gerekce=btrim(p_gerekce),on_inceleme_zaman=t,
  durum=case when p_karar='serbest' then 'serbest' else durum end,
  bitis=case when p_karar='serbest' then t else bitis end
 where id=g.id;
 perform oyun.bildir(g.hedef,'Gözaltı #'||g.id||' hâkim ön inceleme kararı: '||
 case when p_karar='serbest' then 'Derhal serbest bırakıldı. ' else 'Mevcut bitiş süresi aşılmadı. ' end||
 left(btrim(p_gerekce),400)||' İtiraz hakkınız devam ediyor.');
 perform oyun.sokak_duyur(g.eylem_id,'Hâkim gözaltı #'||g.id||' ön incelemesinde '||
 case when p_karar='serbest' then 'derhal serbest bırakma' else 'kalan sürenin devamı' end||' kararı verdi.');
 return jsonb_build_object('tamam',true,'karar',p_karar,'itiraz_hakki',true);
end $function$


CREATE OR REPLACE FUNCTION public.sokak_merkez_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); b jsonb; o jsonb; arr jsonb;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 b:=public.sokak_ek_panel();
 o:=public.sokak_org_panel();
 select coalesce(jsonb_agg(x||jsonb_build_object(
 'katildim',exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=(x->>'id')::bigint and d.destekci_tur='oyuncu' and d.destekci_id=u::text and d.destek_turu='katilim' and d.taraf='muhalefet'),
 'gozaltilar',coalesce((select jsonb_agg(g||jsonb_build_object(
 'on_inceleme', (select sg.on_inceleme_karari from oyun.sokak_gozalti sg where sg.id=(g->>'id')::bigint),
 'on_inceleme_gerekce', (select sg.on_inceleme_gerekce from oyun.sokak_gozalti sg where sg.id=(g->>'id')::bigint)
 )) from jsonb_array_elements(coalesce(x->'gozaltilar','[]'::jsonb)) g),'[]'::jsonb),
 'kapanma_nedeni',(select e.kapanma_nedeni from oyun.sokak_eylem e where e.id=(x->>'id')::bigint),
 'davet_ozeti',coalesce((select jsonb_agg(jsonb_build_object('kurulus',case when v.hedef_tur='parti' then (select ad from oyun.partiler where id=v.hedef_id) else (select ad from oyun.dernekler where id=v.hedef_id) end,'durum',v.durum,'cevap_zamani',v.cevap_zamani)) from oyun.sokak_davet v where v.eylem_id=(x->>'id')::bigint),'[]'::jsonb)
 )), '[]'::jsonb) into arr from jsonb_array_elements(b->'eylemler')x;
 return b||jsonb_build_object(
  'eylemler',arr,
  'baslatma_kaynaklari',coalesce(o->'baslatma_kaynaklari','[]'::jsonb),
  'davet_hedefleri',coalesce(o->'davet_hedefleri','[]'::jsonb),
  'davetler',coalesce(o->'davetler','[]'::jsonb),
  'baro_baskani',u=oyun.baro_baskan(),
  'baro_avukatlar',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'ad',p.kad) order by p.kad)
     from oyun.baro_uyeleri bu join oyun.profiller p on p.id=bu.user_id
     join oyun.avukat_ruhsat ar on ar.user_id=p.id
     where bu.durum='aktif' and ar.durum='aktif' and not p.yasakli),'[]'::jsonb),
  'baro_talepleri',coalesce((select jsonb_agg(jsonb_build_object(
     'id',bt.id,'gozalti_id',bt.gozalti_id,'eylem_id',g.eylem_id,
     'hedef',oyun.kad(g.hedef),'durum',bt.durum,'basvuru',bt.basvuru,
     'avukat',oyun.kad(bt.avukat)) order by bt.basvuru desc)
     from oyun.sokak_baro_talep bt join oyun.sokak_gozalti g on g.id=bt.gozalti_id
     where (bt.talep_eden=u or u=oyun.baro_baskan() or bt.avukat=u) and bt.basvuru>oyun.simdi()-interval '7 days'),'[]'::jsonb)
 );
end $function$


revoke all on function public.sokak_gozalti_hakim_incele(bigint,text,text) from public,anon,authenticated;
grant execute on function public.sokak_gozalti_hakim_incele(bigint,text,text) to authenticated;
