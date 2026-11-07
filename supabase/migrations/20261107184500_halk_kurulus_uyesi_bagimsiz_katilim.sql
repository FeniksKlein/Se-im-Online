
alter table oyun.sokak_eylem_destek
 add column if not exists katilim_org_tur text check(katilim_org_tur is null or katilim_org_tur in ('parti','dernek'));
alter table oyun.sokak_eylem_destek add column if not exists katilim_org_id bigint;

create or replace function public.sokak_katil_tercih(p_eylem bigint,p_org_tur text default 'bagimsiz',p_org_id bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); ad text;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_org_tur not in ('bagimsiz','parti','dernek') or p_org_tur is null
 then raise exception 'Katılım biçimi geçersiz';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem bulunamadı';end if;
 if p_org_tur='bagimsiz' then
  if p_org_id is not null then raise exception 'Bağımsız katılımda kuruluş seçilmez';end if;
 else
  if p_org_id is null then raise exception 'Katılacağınız kuruluşu seçin';end if;
  if p_org_tur='parti' then
   select pa.ad into ad from oyun.partiler pa join oyun.profiller pr on pr.parti_id=pa.id
   where pr.id=u and pa.id=p_org_id and not pa.kapali;
  else
   select de.ad into ad from oyun.dernekler de join oyun.dernek_uyeler du on du.dernek_id=de.id
   where du.user_id=u and de.id=p_org_id and not de.kapali;
  end if;
  if ad is null then raise exception 'Bu parti veya derneğin üyesi değilsin';end if;
  if not (x.org_tur=p_org_tur and x.org_id=p_org_id)
   and not exists(select 1 from oyun.sokak_davet v where v.eylem_id=x.id and v.hedef_tur=p_org_tur
       and v.hedef_id=p_org_id and v.durum='kabul')
  then raise exception 'Kuruluşun eylem davetini kabul etmesi gerekiyor';end if;
 end if;
 perform public.sokak_destek(p_eylem,'muhalefet','oyuncu',null,0);
 update oyun.sokak_eylem_destek set
  katilim_org_tur=case when p_org_tur='bagimsiz' then null else p_org_tur end,
  katilim_org_id=case when p_org_tur='bagimsiz' then null else p_org_id end
 where eylem_id=p_eylem and destekci_tur='oyuncu' and destekci_id=u::text
  and destek_turu='katilim' and taraf='muhalefet';
 if not found then raise exception 'Katılım kaydı oluşturulamadı';end if;
 return jsonb_build_object('tamam',true,'katilim','kayitli','bicim',p_org_tur,'kurulus',ad);
end $f$;

revoke all on function public.sokak_katil_tercih(bigint,text,bigint) from public,anon,authenticated;
grant execute on function public.sokak_katil_tercih(bigint,text,bigint) to authenticated;

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
 'katilim_sifatim',(select case when d.katilim_org_tur='parti' then 'Parti · '||(select ad from oyun.partiler where id=d.katilim_org_id)
 when d.katilim_org_tur='dernek' then 'Dernek · '||(select ad from oyun.dernekler where id=d.katilim_org_id)
 else 'Bağımsız' end
 from oyun.sokak_eylem_destek d where d.eylem_id=(x->>'id')::bigint and d.destekci_tur='oyuncu'
 and d.destekci_id=u::text and d.destek_turu='katilim' and d.taraf='muhalefet' limit 1),
 'katilim_ayrintilari',coalesce((select jsonb_agg(jsonb_build_object('ad',oyun.kad(d.temsilci),
 'sifat',case when d.katilim_org_tur='parti' then (select ad from oyun.partiler where id=d.katilim_org_id)
 when d.katilim_org_tur='dernek' then (select ad from oyun.dernekler where id=d.katilim_org_id)
 else 'Bağımsız' end))
 from oyun.sokak_eylem_destek d where d.eylem_id=(x->>'id')::bigint and d.destekci_tur='oyuncu'
 and d.destek_turu='katilim' and d.taraf='muhalefet'),'[]'::jsonb),
 'kapanma_nedeni',(select e.kapanma_nedeni from oyun.sokak_eylem e where e.id=(x->>'id')::bigint),
 'davet_ozeti',coalesce((select jsonb_agg(jsonb_build_object('kurulus',case when v.hedef_tur='parti' then (select ad from oyun.partiler where id=v.hedef_id) else (select ad from oyun.dernekler where id=v.hedef_id) end,'durum',v.durum,'cevap_zamani',v.cevap_zamani)) from oyun.sokak_davet v where v.eylem_id=(x->>'id')::bigint),'[]'::jsonb)
 )), '[]'::jsonb) into arr from jsonb_array_elements(b->'eylemler')x;
 return b||jsonb_build_object(
  'eylemler',arr,
  'katilim_kuruluslari',coalesce((select jsonb_agg(to_jsonb(q) order by q.ad) from (
    select ev.id as eylem_id,'parti'::text as tur,pa.id,pa.ad
    from oyun.sokak_eylem ev join oyun.profiller me on me.id=u
    join oyun.partiler pa on pa.id=me.parti_id and not pa.kapali
    where ev.durum='aktif' and ev.bitis>oyun.simdi() and
     ((ev.org_tur='parti' and ev.org_id=pa.id)
      or exists(select 1 from oyun.sokak_davet v where v.eylem_id=ev.id and v.hedef_tur='parti'
       and v.hedef_id=pa.id and v.durum='kabul'))
    union all
    select ev.id as eylem_id,'dernek'::text as tur,de.id,de.ad
    from oyun.sokak_eylem ev
    join oyun.dernek_uyeler du on du.user_id=u
    join oyun.dernekler de on de.id=du.dernek_id and not de.kapali
    where ev.durum='aktif' and ev.bitis>oyun.simdi() and
     ((ev.org_tur='dernek' and ev.org_id=de.id)
      or exists(select 1 from oyun.sokak_davet v where v.eylem_id=ev.id and v.hedef_tur='dernek'
       and v.hedef_id=de.id and v.durum='kabul'))
   )q),'[]'::jsonb),
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

