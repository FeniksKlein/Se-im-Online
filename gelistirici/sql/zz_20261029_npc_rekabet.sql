CREATE OR REPLACE FUNCTION oyun.npc_isletme_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s record; st record; z record;
 t timestamptz:=now(); v_gun date:=(now() at time zone 'Europe/Istanbul')::date;
 v_lim integer; v_satilan integer; v_adet integer; v_rakip integer;
 v_gelir numeric; v_maliyet numeric; v_kdv numeric; v_kurum numeric; v_diger numeric; v_bakim numeric;
 v_kar numeric; v_satis_id bigint; v_n integer:=0; v_ciro numeric:=0;
 v_tlm numeric:=oyun.pazar_tl_milyar(); v_oran numeric:=oyun.eko_vergi_oran('kdv');
 v_kv numeric:=oyun.eko_vergi_oran('kurumlar');
begin
 if not oyun.uzaktan_modul_acik('npc_isletme') then return jsonb_build_object('durdu',true); end if;
 if not pg_try_advisory_xact_lock(444722,7) then return jsonb_build_object('kilitli',true); end if;
 for s in
 select c.id,c.ad,c.kasa,c.sermaye,c.sektor,p.il_id,d.gelisim,
       oyun.pazar_il_agirlik(p.il_id) as sehir_carpani
 from oyun.sirketler c join oyun.pazar_sirket p on p.sirket_id=c.id
 join oyun.il_durum d on d.il_id=p.il_id
 where c.aktif and exists(select 1 from oyun.npc_urun_katalog n where n.sektor=c.sektor)
 order by c.id limit 400
 loop
  perform pg_advisory_xact_lock(98763,hashtext(s.id::text));
  perform 1 from oyun.sirketler where id=s.id for update;
  insert into oyun.npc_son_saat(sirket_id,son_saat) values(s.id,t) on conflict do nothing;
  update oyun.npc_son_saat set son_saat=t
  where sirket_id=s.id and son_saat<=t-interval '15 minutes';
  if not found then continue; end if;
  -- Saatlik enerji, personel ve bakım: stok bitse de ödenir.
  v_bakim:=least(greatest(0,(select kasa from oyun.sirketler where id=s.id)),
    round((10+s.sermaye*0.00008)/4,2));
  if v_bakim>0 then
   update oyun.sirketler set kasa=kasa-v_bakim where id=s.id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
   values(s.id,t,-v_bakim,'NPC mağaza 15 dakikalık personel, enerji ve bakım',0,v_bakim,0);
  end if;
  select count(*) into v_rakip from oyun.pazar_sirket ps
   join oyun.sirketler c on c.id=ps.sirket_id
   where ps.il_id=s.il_id and c.aktif and c.sektor=s.sektor;
  for st in select ns.urun,ns.adet,ns.alis_ortalama,ns.satis_fiyati,
    u.gunluk_talep from oyun.npc_stok ns join oyun.npc_urun_katalog u on u.kod=ns.urun
    where ns.sirket_id=s.id and ns.adet>0 order by ns.urun for update of ns
  loop
    insert into oyun.npc_talep_gun(il_id,urun,gun)
    values(s.il_id,st.urun,v_gun) on conflict do nothing;
    select adet into v_satilan from oyun.npc_talep_gun
       where il_id=s.il_id and urun=st.urun and gun=v_gun for update;
    v_lim:=greatest(1,round(2*st.gunluk_talep*greatest(0.7,least(3,s.sehir_carpani))*
      (1+oyun.belediye_yatirim_oran(s.il_id,'talep'))));
    v_adet:=least(st.adet,greatest(0,v_lim-v_satilan),
       greatest(0,floor(st.gunluk_talep*greatest(.7,least(3,s.sehir_carpani))/30*
       (0.65+random()*.7)/sqrt(greatest(1,v_rakip))*
       (0.65+s.gelisim/150.0)*
       greatest(0.2,least(1.7,power(
       oyun.npc_piyasa_fiyati(st.urun,s.il_id,'satis')/greatest(st.satis_fiyati,0.01),3)))
       +random())::integer));
    if v_adet<=0 then continue; end if;
    v_gelir:=round(st.satis_fiyati*v_adet,2);
    v_maliyet:=round(st.alis_ortalama*v_adet,2);
    v_kdv:=round(greatest(0,v_gelir-v_maliyet)*v_oran/(100+v_oran),2);
    v_diger:=round(v_gelir*0.006,2);
    v_kurum:=round(greatest(0,v_gelir-v_maliyet-v_kdv-v_diger)*v_kv/100,2);
    v_kar:=v_gelir-v_maliyet-v_kdv-v_diger-v_kurum;
    update oyun.npc_stok set adet=adet-v_adet,son_guncelleme=t
     where sirket_id=s.id and urun=st.urun;
    update oyun.npc_talep_gun set adet=adet+v_adet
     where il_id=s.il_id and urun=st.urun and gun=v_gun;
    update oyun.sirketler set kasa=kasa+v_gelir-v_kdv-v_diger-v_kurum,son_islem=t where id=s.id;
    insert into oyun.npc_satis_kayit(sirket_id,urun,adet,tutar,maliyet,vergi,isletme_gideri,tur,zaman)
      values(s.id,st.urun,v_adet,v_gelir,v_maliyet,v_kdv+v_kurum,v_diger,'npc_satis',t) returning id into v_satis_id;
    insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
      values(s.id,t,v_kar,format('NPC satış: %s adet %s (KDV ve kâr vergisi dahil)',v_adet,st.urun),
      v_gelir,v_maliyet+v_kdv+v_kurum+v_diger,0);
    if v_kdv+v_kurum>0 then
      update oyun.ulke set hazine=hazine+(v_kdv+v_kurum)/v_tlm where id=1;
      if v_kdv>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kdv',v_gelir,v_oran,v_kdv,'npc_satis',v_satis_id,t);
      end if;
      if v_kurum>0 then
        insert into oyun.eko_vergi_hareket(sirket_id,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
        values(s.id,'kurumlar',greatest(0,v_gelir-v_maliyet-v_kdv-v_diger),v_kv,v_kurum,'npc_satis',v_satis_id,t);
      end if;
    end if;
    v_ciro:=v_ciro+v_gelir;v_n:=v_n+v_adet;
  end loop;
 end loop;
 return jsonb_build_object('satilan',v_n,'ciro',v_ciro,'zaman',t);
end $function$
;
DO $$ DECLARE j record; BEGIN FOR j IN SELECT jobid FROM cron.job WHERE command='select oyun.npc_isletme_tick()' LOOP PERFORM cron.alter_job(j.jobid,schedule := '*/15 * * * *'); END LOOP; END $$;


-- Private cache: clients only receive the deliberately public top-ten aggregates.
create table if not exists oyun.rekabet_onbellek(id integer primary key check(id=1), veri jsonb not null);
alter table oyun.rekabet_onbellek enable row level security;
revoke all on oyun.rekabet_onbellek from public,anon,authenticated;
create or replace function oyun.rekabet_yenile() returns void
language plpgsql security invoker set search_path='' as $$
declare v jsonb;
begin
 if not pg_try_advisory_xact_lock(444722,8) then return; end if;
 with sirket as materialized (
 select s.id,s.ad,oyun.sirket_defter(s.id)+coalesce((select sum(n.adet*n.alis_ortalama) from oyun.npc_stok n where n.sirket_id=s.id),0) deger,
 coalesce((select sum(h.faaliyet_gelir-h.faaliyet_gider) from oyun.sirket_hareket h where h.sirket_id=s.id and h.zaman>=now()-interval '7 days'),0) kar,
 coalesce((select sum(n.tutar) from oyun.npc_satis_kayit n where n.sirket_id=s.id and n.tur='npc_satis' and n.zaman>=now()-interval '7 days'),0) satis
 from oyun.sirketler s where s.aktif and not exists(select 1 from oyun.profiller p where p.id=coalesce(s.yonetici,s.kurucu) and (p.yasakli or p.engel_bitis>now()))
 ), oyuncu as materialized (
 select p.id,p.kad ad,
 coalesce((select para from oyun.cuzdan where user_id=p.id),0)+oyun.mevduat_toplam(p.id)
 +coalesce((select sum(bakiye) from oyun.ib_vadesiz where user_id=p.id),0)
 +coalesce((select sum(anapara) from oyun.banka_mevduat where user_id=p.id and not kapandi),0)
 +coalesce((select sum(x.miktar*k.fiyat) from oyun.meslek_portfoy x join oyun.meslek_kur k using(kod) where x.user_id=p.id),0)
 +coalesce((select sum(x.miktar*k.fiyat) from oyun.piyasa_pozisyon x join oyun.piyasa_varlik k using(kod) where x.user_id=p.id),0)
 +coalesce((select sum(bedel) from oyun.mulkler where user_id=p.id),0)
 +coalesce((select sum(alis_bedeli) from oyun.yatirim_mulkleri where user_id=p.id),0)
 +coalesce((select sum(s.deger*o.pay/100) from oyun.sirket_ortaklari o join sirket s on s.id=o.sirket_id where o.user_id=p.id),0)
 -coalesce((select sum(kalan) from oyun.krediler where user_id=p.id and durum in ('aktif','takip')),0)
 -coalesce((select sum(kalan) from oyun.oyb_kredi where borclu=p.id and durum in ('aktif','takip')),0)
 -coalesce((select sum(borc) from oyun.kredi_kartlari where user_id=p.id),0) deger,
 (select count(*) from oyun.kursu_takip t join oyun.profiller f on f.id=t.takipci where t.takip_edilen=p.id and not coalesce(f.yasakli,false) and (f.engel_bitis is null or f.engel_bitis<=now())) takipci,
 (select count(*) from oyun.mulkler where user_id=p.id)+(select count(*) from oyun.yatirim_mulkleri where user_id=p.id) mulk
 from oyun.profiller p where not coalesce(p.yasakli,false) and (p.engel_bitis is null or p.engel_bitis<=now())
 )
 select jsonb_build_object('zaman',now(),
 'oyuncu',coalesce((select jsonb_agg((to_jsonb(x)-'id') order by deger desc,ad,id) from (select id,ad,round(deger,2) deger from oyuncu order by deger desc,ad,id limit 10)x),'[]'::jsonb),
 'sirket',coalesce((select jsonb_agg((to_jsonb(x)-'id') order by deger desc,ad,id) from (select id,ad,round(deger,2) deger from sirket order by deger desc,ad,id limit 10)x),'[]'::jsonb),
 'kar',coalesce((select jsonb_agg((to_jsonb(x)-'id') order by deger desc,ad,id) from (select id,ad,round(kar,2) deger from sirket where kar>0 order by kar desc,ad,id limit 10)x),'[]'::jsonb),
 'satis',coalesce((select jsonb_agg((to_jsonb(x)-'id') order by deger desc,ad,id) from (select id,ad,round(satis,2) deger from sirket where satis>0 order by satis desc,ad,id limit 10)x),'[]'::jsonb),
 'takipci',coalesce((select jsonb_agg((to_jsonb(x)-'id') order by deger desc,ad,id) from (select id,ad,takipci deger from oyuncu where takipci>0 order by takipci desc,ad,id limit 10)x),'[]'::jsonb),
 'mulk',coalesce((select jsonb_agg((to_jsonb(x)-'id') order by deger desc,ad,id) from (select id,ad,mulk deger from oyuncu where mulk>0 order by mulk desc,ad,id limit 10)x),'[]'::jsonb)) into v;
 insert into oyun.rekabet_onbellek values(1,v) on conflict(id) do update set veri=excluded.veri;
end $$;
revoke all on function oyun.rekabet_yenile() from public,anon,authenticated;
create or replace function oyun.rekabet_oku() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from oyun.profiller where id=auth.uid() and not coalesce(yasakli,false) and (engel_bitis is null or engel_bitis<=now())) then raise exception 'Oturum gerekli'; end if;
 return (select veri from oyun.rekabet_onbellek where id=1);
end $$;
revoke all on function oyun.rekabet_oku() from public,anon;
grant execute on function oyun.rekabet_oku() to authenticated;
create or replace function public.rekabet_paneli() returns jsonb
language sql stable security invoker set search_path='' as $$ select oyun.rekabet_oku() $$;
revoke all on function public.rekabet_paneli() from public,anon;
grant execute on function public.rekabet_paneli() to authenticated;
select oyun.rekabet_yenile();
select cron.schedule('rekabet-panosu-5dk','*/5 * * * *','select oyun.rekabet_yenile()');
