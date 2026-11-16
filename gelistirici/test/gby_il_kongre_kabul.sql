create table if not exists oyun.migration_test_sonuc(ad text not null, sonuc jsonb, zaman timestamptz not null default now());
alter table oyun.migration_test_sonuc enable row level security;
do $kabul$
declare res jsonb:='[]'; pa oyun.partiler; gb uuid; y uuid; il smallint; u3 uuid; u4 uuid; kid bigint; r jsonb; e text;
begin
  begin
  select p.* into pa from oyun.partiler p where not p.kapali and p.gb is not null
    and exists(select 1 from oyun.parti_teskilat t where t.parti_id=p.id)
    order by (select count(*) from oyun.profiller x where x.parti_id=p.id and x.id<>p.gb and not coalesce(x.yasakli,false) and oyun.rol_cakisma(x.id,'gby') is null and not exists(select 1 from oyun.parti_gby g where g.user_id=x.id)) desc, p.id limit 1;
  gb := pa.gb;
  select x.id into y from oyun.profiller x where x.parti_id=pa.id and x.id<>gb and not coalesce(x.yasakli,false) and oyun.rol_cakisma(x.id,'gby') is null and not exists(select 1 from oyun.parti_gby g where g.user_id=x.id) order by x.olusturma limit 1;
  perform set_config('request.jwt.claim.sub',gb::text,true);
  res := res || jsonb_build_object('parti',pa.kisa,'gby_azami',(oyun.parti_tuzuk(pa.id)).gby_azami,'gecis_yetki',(select count(*) from oyun.parti_gby_yetki where aktif));
  perform public.gby_ata(1,oyun.kad(y));
  r := public.gby_yetki_ver(oyun.kad(y),'teskilat');
  r := public.gby_yetki_ver(oyun.kad(y),'mali',1000);
  r := public.gby_yetki_al(oyun.kad(y),'mali');
  res := res || jsonb_build_object('G1_teskilat_kaldi',oyun.teskilat_yonetici(y,pa.id),'mali_gitti',oyun.parti_gorevli(y,array['mali']) is null);
  r := public.parti_tuzuk_ayarla('{"gby_azami":10}');
  perform public.gby_ata(8,oyun.kad((select x.id from oyun.profiller x where x.parti_id=pa.id and x.id not in (gb,y) and not coalesce(x.yasakli,false) and oyun.rol_cakisma(x.id,'gby') is null and not exists(select 1 from oyun.parti_gby g where g.user_id=x.id) limit 1)));
  res := res || jsonb_build_object('G2_8_sira',exists(select 1 from oyun.parti_gby where parti_id=pa.id and sira=8));
  -- il kongresi
  select t.il_id into il from oyun.parti_teskilat t where t.parti_id=pa.id order by (select count(*) from oyun.profiller x where x.parti_id=pa.id and x.il_id=t.il_id) desc limit 1;
  select x.id into u3 from oyun.profiller x where x.parti_id=pa.id and x.il_id=il and not coalesce(x.yasakli,false) order by x.olusturma limit 1;
  update oyun.parti_teskilat_gorev set aktif=false where parti_id=pa.id and il_id=il;
  r := public.il_gecici_baskan_ata(il,oyun.kad(u3));
  res := res || jsonb_build_object('K1_gecici',(select statu from oyun.il_baskanlik where parti_id=pa.id and il_id=il and aktif));
  r := public.il_kongre_ac(il);
  select id into kid from oyun.il_kongre where parti_id=pa.id and il_id=il and durum='aday';
  update oyun.il_kongre set acilis=acilis-interval '1 day' where id=kid;
  perform set_config('request.jwt.claim.sub',u3::text,true);
  r := public.il_kongre_aday_ol(kid,'Test vaadi');
  update oyun.il_kongre set aday_bit=oyun.simdi()-interval '1 second' where id=kid;
  r := public.il_kongre_oy(kid,oyun.kad(u3));
  begin perform public.il_kongre_oy(kid,oyun.kad(u3)); e:='ikinci oy kabul edildi'; exception when others then e:=left(sqlerrm,40); end;
  res := res || jsonb_build_object('K2_ikinci_oy',e);
  update oyun.il_kongre set oy_bit=oyun.simdi()-interval '1 second' where id=kid;
  perform oyun.il_kongre_tick();
  res := res || jsonb_build_object('K3_secilmis',(select statu from oyun.il_baskanlik where parti_id=pa.id and il_id=il and aktif),
     'kongre',(select durum from oyun.il_kongre where id=kid));
  perform set_config('request.jwt.claim.sub',gb::text,true);
  begin perform public.teskilat_gorev_ver(il,oyun.kad(y)); e:='degisti'; exception when others then e:=left(sqlerrm,50); end;
  res := res || jsonb_build_object('K4_secilmis_korunur',e);
  -- başka partiye geçer
  update oyun.profiller set parti_id=(select id from oyun.partiler where id<>pa.id and not kapali limit 1) where id=u3;
  res := res || jsonb_build_object('K5_parti_degisti',not exists(select 1 from oyun.il_baskanlik where parti_id=pa.id and il_id=il and aktif));
  update oyun.profiller set parti_id=null where id=y;
  res := res || jsonb_build_object('G3_uyelik_bitti',not exists(select 1 from oyun.parti_gby_yetki where user_id=y and aktif),'unvan',oyun.gby_unvan(y));
    raise exception using errcode='P0099', message=res::text;
  exception when sqlstate 'P0099' then res := sqlerrm::jsonb;
  end;
  insert into oyun.migration_test_sonuc(ad,sonuc) values('gby_il_kongre_20261116',res);
  if not (coalesce((res->1->>'G1_teskilat_kaldi')::boolean,false) and coalesce((res->1->>'mali_gitti')::boolean,false)
      and coalesce((res->2->>'G2_8_sira')::boolean,false) and res->3->>'K1_gecici'='gecici'
      and res->4->>'K2_ikinci_oy' like '%zaten%' and res->5->>'K3_secilmis'='secilmis'
      and res->6->>'K4_secilmis_korunur' like '%seçilmiş%' and coalesce((res->7->>'K5_parti_degisti')::boolean,false)
      and coalesce((res->8->>'G3_uyelik_bitti')::boolean,false)) then
    raise exception 'KABUL TESTI BASARISIZ: %', res;
  end if;
end $kabul$;
