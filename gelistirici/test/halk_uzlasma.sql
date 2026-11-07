begin;
set local statement_timeout='30s';set local lock_timeout='3s';
do $$declare cb uuid;u uuid;pa bigint;e bigint;k bigint;ids uuid[];v jsonb;
begin
 select user_id into cb from oyun.makamlar where tur='cb' and bit is null limit 1;
 select id,gb into pa,u from oyun.partiler where not kapali and gb is not null limit 1;
 select array_agg(id) into ids from (select id from oyun.profiller where not yasakli and not oyun.sokak_iktidar(id) limit 3)p;
 update oyun.bakanlik_kasa set kasa=1000 where kod='icisleri';update oyun.il_durum set memnuniyet=40 where il_id=48;
 insert into oyun.sokak_eylem(il_id,parti_id,baslatan,gerekce,baslangic,bitis,muhalefet_fonu) values(48,pa,u,'Uzlaşma regresyon testi gerekçesi',oyun.simdi(),oyun.simdi()+interval '24 hours',50000) returning id into e;
 perform set_config('request.jwt.claim.sub',u::text,true);perform public.sokak_talep_sec(e,'hizmet');
 foreach u in array ids loop
 update oyun.profiller set il_id=48,il_at=oyun.simdi()-interval '5 days' where id=u;
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,taraf,temsilci) values(e,'oyuncu',u::text,'muhalefet',u);
 end loop;
 perform set_config('request.jwt.claim.sub',cb::text,true);
 v:=public.sokak_soz_teklif(e,'Hizmet kalitesini 24 saatte iyileştirme teklifi');k:=(v->>'karar_id')::bigint;
 perform public.sokak_uzlasma_panel();
 begin perform public.sokak_soz_oyla(e,true);raise exception 'TEST seçmen dışı oy';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 begin
  perform set_config('request.jwt.claim.sub',ids[1]::text,true);perform public.sokak_soz_oyla(e,false);
  perform set_config('request.jwt.claim.sub',ids[2]::text,true);perform public.sokak_soz_oyla(e,false);
  if (select durum from oyun.sokak_soz where eylem_id=e)<>'reddedildi' then raise exception 'Ret çoğunluğu işlemedi';end if;
  raise exception using errcode='ZX004',message='Ret dalını geri al';exception when sqlstate 'ZX004' then null;end;
 begin
  update oyun.sokak_soz set oy_sonu=oyun.simdi()-interval '1 second' where eylem_id=e;perform oyun.sokak_soz_tick();
  if (select durum from oyun.sokak_soz where eylem_id=e)<>'reddedildi' then raise exception 'Oylama süre sonu işlemedi';end if;
  raise exception using errcode='ZX005',message='Süre dalını geri al';exception when sqlstate 'ZX005' then null;end;

 begin perform public.sokak_karar_yanit(k,'kabul','Tek kişinin kabulünü engelleme testi');raise exception 'TEST bypass';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',ids[1]::text,true);perform public.sokak_soz_oyla(e,true);
 begin perform public.sokak_soz_oyla(e,true);raise exception 'TEST tekrar oy';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',ids[2]::text,true);perform public.sokak_soz_oyla(e,true);
 if (select durum from oyun.sokak_soz where eylem_id=e)<>'takip' then raise exception 'Çoğunluk kabulü yok';end if;
 begin perform public.sokak_destek(e,'muhalefet');raise exception 'TEST askıda fon';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 update oyun.sokak_soz set son_tarih=oyun.simdi()-interval '1 second' where eylem_id=e;
 begin
 update oyun.il_durum set memnuniyet=45 where il_id=48;perform oyun.sokak_soz_tick();
 if (select durum from oyun.sokak_soz where eylem_id=e)<>'tutuldu' or (select durum from oyun.sokak_eylem where id=e)<>'yatisti' then raise exception 'Tutulan söz kapanmadı';end if;
 raise exception using errcode='ZX003',message='Başarı dalını geri al';exception when sqlstate 'ZX003' then null;end;
 perform oyun.sokak_soz_tick();
 if (select durum from oyun.sokak_soz where eylem_id=e)<>'tutulmadi' or (select durum from oyun.sokak_eylem where id=e)<>'aktif' then raise exception 'Tutulmayan söz devam etmedi';end if;
 perform oyun.sokak_soz_tick();
 if has_function_privilege('authenticated','oyun.sokak_soz_tick()','execute') then raise exception 'İç tick açık';end if;
end $$;
rollback;
select 'PASS: talep, seçmen listesi, çoğunluk, tekrar oy engeli, askı, tutulan/tutulmayan söz, yetki' result;
