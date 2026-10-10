begin;
create or replace function public.sos_duellolar() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); rec record;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 for rec in select id from oyun.sos_duello where durum in ('davet','canli','oylama') and
 (durum<>'davet' or davet_eden=u or davet_edilen=u) order by id desc limit 80 loop
 perform oyun.sos_duello_guncelle(rec.id,t);
 end loop;
 return coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'baslik',d.baslik,'birinci',oyun.kad(d.davet_eden),'ikinci',oyun.kad(d.davet_edilen),
 'davet_eden',d.davet_eden,'davet_edilen',d.davet_edilen,'durum',d.durum,'olusturma',d.olusturma,'kabul_at',d.kabul_at,
 'oylama_bas',d.oylama_bas,'tur_sayisi',d.tur_sayisi,'sira_bende',d.durum='canli' and d.siradaki=u,
 'davet_bende',d.durum='davet' and d.davet_edilen=u,'benim_oyum',(select tercih from oyun.sos_duello_oy where duello_id=d.id and user_id=u),
 'oy_bir',(select count(*) from oyun.sos_duello_oy where duello_id=d.id and tercih=d.davet_eden),
 'oy_iki',(select count(*) from oyun.sos_duello_oy where duello_id=d.id and tercih=d.davet_edilen),
 'sozler',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(s.konusan),'metin',s.metin,'tur',s.tur,'zaman',s.zaman) order by s.tur)
 from oyun.sos_duello_soz s where s.duello_id=d.id),'[]'::jsonb)) order by d.id desc)
 from (select * from oyun.sos_duello where durum<>'davet' or davet_eden=u or davet_edilen=u order by id desc limit 80) d),'[]'::jsonb);
end $$;
create or replace function public.sos_parti_imzala(p_parti bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); p oyun.partiler; c oyun.sos_parti_imza; n int; toplam int; o jsonb;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into p from oyun.partiler where id=p_parti and not kapali for update;
 if p.id is null or not exists(select 1 from oyun.profiller where id=u and parti_id=p.id) then raise exception 'Yalnızca bu partinin üyeleri imzalayabilir.'; end if;
 if exists(select 1 from oyun.secimler where tur='kurultay' and ara and hedef_parti_id=p.id and durum<>'tamam' and goreve_bas>t) then raise exception 'Parti için zaten olağanüstü kurultay var.'; end if;
 update oyun.sos_parti_imza set durum='sure_doldu' where parti_id=p.id and durum='acik' and bit<=t;
 select * into c from oyun.sos_parti_imza where parti_id=p.id and durum='acik' for update;
 if c.id is null then insert into oyun.sos_parti_imza(parti_id,acan,bas,bit) values(p.id,u,t,t+interval '7 days') returning * into c; end if;
 if not exists(select 1 from oyun.profiller where id=u and parti_id=p.id and coalesce(parti_at,olusturma)<=c.bas) and c.acan<>u then raise exception 'İmza kampanyası açıldıktan sonra katılan üyeler bu kampanyada imza atamaz.'; end if;
 insert into oyun.sos_parti_imzaci(kampanya_id,user_id) values(c.id,u) on conflict do nothing;
 if not found then raise exception 'Bu kampanyayı zaten imzaladın.'; end if;
 select count(*) into n from oyun.sos_parti_imzaci where kampanya_id=c.id;
 select count(*) into toplam from oyun.profiller where parti_id=p.id;
 if n>=greatest(2,ceil(toplam::numeric/3)::int) then
   o:=oyun.ara_secim_olustur('gb',p.id,null::smallint,t);
   update oyun.secimler set ara_neden='uye_imza_kampanyasi' where id=(o->>'secim_id')::bigint and ara and ara_neden='genel_baskan_istifa';
   update oyun.sos_parti_imza set durum='basarili',secim_id=(o->>'secim_id')::bigint where id=c.id;
   perform oyun.olay('parti',format('%s üyelerinin imzasıyla olağanüstü kurultay kararı alındı.',p.ad),null,p.id,t);
   if p.gb is not null then perform oyun.bildir(p.gb,format('%s üyeleri olağanüstü kurultay topladı.',p.ad),t); end if;
 end if;
 return public.sos_parti_imza_durum(p.id);
end $$;
commit;
