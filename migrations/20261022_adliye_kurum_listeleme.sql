CREATE OR REPLACE FUNCTION public.adliye_durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim();
begin
 return jsonb_build_object(
 'ben',p.kad,'parti_id',p.parti_id,
 'cb_miyim',exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null),
 'hakim',(select oyun.kad(hakim) from oyun.adliye_makam where id=1),
 'hakim_miyim',exists(select 1 from oyun.adliye_makam where id=1 and hakim=p.id),
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',pa.id,'ad',pa.ad,'kisa',pa.kisa,'gb',oyun.kad(pa.gb),'sozcu',oyun.kad(s.user_id),
 'gb_miyim',pa.gb=p.id,'sozcu_muyum',s.user_id=p.id) order by pa.ad)
 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where not pa.kapali),'[]'::jsonb),
 'davalar',coalesce((select jsonb_agg(jsonb_build_object(
 'id',d.id,'davaci',oyun.kad(d.davaci),'davaci_parti',dp.ad,'davali',coalesce(oyun.kad(d.davali),d.davali_kurum_ad),'davali_parti',hp.ad,'davali_kurum_tur',d.davali_kurum_tur,'davali_kurum_id',d.davali_kurum_id,'davali_kurum_ad',d.davali_kurum_ad,
 'tur',d.tur,'iddia',d.iddia,'delil',d.delil,'acilis',d.acilis,'savunma_son',d.savunma_son,
 'savunma_geldi',d.savunma_geldi,'durum',d.durum,'hakim',oyun.kad(d.hakim),
 'karar',d.karar,'tazminat_talep',d.tazminat_talep,'tazminat_tutar',d.tazminat_tutar,'tazminat_odenen',d.tazminat_odenen,'gerekce',d.gerekce,'karar_at',d.karar_at,'ceza_bitis',d.ceza_bitis,
 'af_at',d.af_at,'af_veren',oyun.kad(d.af_veren),'af_gerekce',d.af_gerekce,
 'davalimiyim',(coalesce(d.davali=p.id,false) or oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,p.id)),'davacimiyim',d.davaci=p.id,'temsil_iznim',exists(select 1 from oyun.adliye_temsil a where a.dava_id=d.id and a.yetki_veren=p.id and a.aktif),
 'sozcu_savunabilir',(
  (d.davali_parti is not null and exists(select 1 from oyun.parti_sozcu s join oyun.profiller pr on pr.id=p.id and pr.parti_id=s.parti_id where s.parti_id=d.davali_parti and s.user_id=p.id))
  or (d.davali is not null and exists(select 1 from oyun.adliye_temsil t join oyun.parti_sozcu s on s.user_id=p.id join oyun.profiller pr on pr.id=d.davali and pr.parti_id=s.parti_id where t.dava_id=d.id and t.aktif and t.yetki_veren=d.davali))
 )
 ) order by d.id desc)
 from (select * from oyun.adliye_davalar order by id desc limit 100) d
 left join oyun.partiler dp on dp.id=d.davaci_parti
 left join oyun.partiler hp on hp.id=d.davali_parti),'[]'::jsonb),
 'aflar',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'cb',oyun.kad(a.cb),'tur',a.tur,'dava_id',a.dava_id,'gerekce',a.gerekce,'affedilen',a.affedilen,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_aflar order by id desc limit 20) a),'[]'::jsonb),
 'atamalar',coalesce((select jsonb_agg(jsonb_build_object('yapan',oyun.kad(a.yapan),'eski',oyun.kad(a.eski),'yeni',oyun.kad(a.yeni),'gerekce',a.gerekce,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_atama_kayit order by id desc limit 15) a),'[]'::jsonb)
 );
end $function$
