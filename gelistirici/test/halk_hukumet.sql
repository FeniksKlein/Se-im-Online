-- Gerçek sunucuda yalnız BEGIN/ROLLBACK testidir: kararlar, kasa ve bildirimler kalıcılaşmaz.
begin;
set local lock_timeout='3s';set local statement_timeout='30s';
do $$
declare cb uuid; lider uuid; pid bigint; hedef uuid; hakim uuid; e bigint; k bigint; v jsonb; kasa numeric; beklenen numeric; baska uuid; ic uuid;
begin
 select user_id into cb from oyun.makamlar where tur='cb' and bit is null limit 1;
 select user_id into ic from oyun.makamlar where tur='bakan' and bakanlik='icisleri' and bit is null limit 1;
 select p.id,pa.id into lider,pid from oyun.partiler pa join oyun.profiller p on p.id=pa.gb where not pa.kapali and not p.yasakli and not oyun.sokak_iktidar(p.id) limit 1;
 select id into hedef from oyun.profiller where not yasakli and id<>lider and not oyun.sokak_iktidar(id) limit 1;
 select a.hakim into hakim from oyun.adliye_makam a where a.hakim is not null limit 1;
 if cb is null or lider is null or hedef is null then raise exception 'Test rolleri eksik'; end if;
 update oyun.bakanlik_kasa set kasa=1000 where kod='icisleri';
 insert into oyun.sokak_eylem(il_id,parti_id,baslatan,gerekce,baslangic,bitis,muhalefet_fonu) values(48,pid,lider,'Hükümet özellikleri geri alınacak test eylemi',oyun.simdi()-interval '24 hours',oyun.simdi()+interval '72 hours',100000) returning id into e;
 perform set_config('request.jwt.claim.sub',lider::text,true);
 begin perform public.sokak_hukumet_karar(e,'masa','Yetkisiz oyuncu için test açıklaması');raise exception 'TEST yetkisiz erişim';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',cb::text,true);
 select b.kasa into kasa from oyun.bakanlik_kasa b where kod='icisleri';beklenen:=oyun.sokak_karar_bedel(e,'masa')/oyun.pazar_tl_milyar();
 v:=public.sokak_hukumet_karar(e,'masa','Uzlaşma masası için somut çözüm önerimiz');k:=(v->>'karar_id')::bigint;
 if abs((select b.kasa from oyun.bakanlik_kasa b where kod='icisleri')-(kasa-beklenen))>0.000001 then raise exception 'Kamu bütçesi yanlış';end if;
 begin perform public.sokak_hukumet_karar(e,'uyari','Tekrarlı karar bekleme süresi testi');raise exception 'TEST cooldown çalışmadı';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 perform public.sokak_hukumet_panel();
 -- Yanlış kişi kabul edemez; organizatör reddedebilir.
 begin perform public.sokak_karar_yanit(k,'kabul','Yetkisiz uzlaşma kabulünü test ediyoruz');raise exception 'TEST yanlış kişi kabul etti';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',lider::text,true);
 begin
  perform public.sokak_karar_yanit(k,'kabul','Uzlaşma teklifini kabul ediyoruz test açıklaması');
  if (select durum from oyun.sokak_eylem where id=e)<>'yatisti' then raise exception 'Uzlaşma kabulü kapatmadı';end if;
  raise exception using errcode='ZX002',message='Kabul alt işlemini geri al';
 exception when sqlstate 'ZX002' then null;end;
 perform public.sokak_karar_yanit(k,'ret','Bu teklif taleplerimizi karşılamıyor');
 if (select durum from oyun.sokak_eylem where id=e)<>'aktif' then raise exception 'Ret eylemi kapattı';end if;
 update oyun.sokak_karar set zaman=oyun.simdi()-interval '25 hours' where eylem_id=e;
 perform set_config('request.jwt.claim.sub',coalesce(ic,cb)::text,true);
 perform public.sokak_hukumet_karar(e,'yonlendirme','Bilgilendirme ve yönlendirme test kararı');
 if oyun.sokak_karar_etki(e)<>-10 then raise exception 'Yönlendirme etkisi yanlış';end if;
 update oyun.sokak_karar set zaman=oyun.simdi()-interval '25 hours',bitis=oyun.simdi()-interval '1 day' where eylem_id=e;
 perform public.sokak_hukumet_karar(e,'uyari','Sert siyasi uyarı için test gerekçesi');
 if oyun.sokak_karar_etki(e)<>-8 then raise exception 'Uyarı etkisi yanlış';end if;
 update oyun.sokak_karar set bitis=oyun.simdi()-interval '1 hour' where eylem_id=e and tur='uyari';
 if oyun.sokak_karar_etki(e)<>6 then raise exception 'Geri tepme etkisi yanlış';end if;
 update oyun.sokak_karar set zaman=oyun.simdi()-interval '25 hours' where eylem_id=e;
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,taraf,temsilci) values(e,'oyuncu',hedef::text,'muhalefet',hedef);
 v:=public.sokak_hukumet_karar(e,'yaptirim','Süreli yaptırım test gerekçesi ve somut açıklama',hedef);k:=(v->>'karar_id')::bigint;
 if not oyun.sokak_yaptirimli(hedef,e) then raise exception 'Yaptırım uygulanmadı';end if;
 perform set_config('request.jwt.claim.sub',hedef::text,true);
 begin perform public.sokak_destek(e,'muhalefet');raise exception 'TEST yaptırım fon engellemedi';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 perform public.sokak_karar_yanit(k,'itiraz','Yaptırıma itiraz ediyorum gerekçesi yetersiz');
 if oyun.sokak_yaptirimli(hedef,e) then raise exception 'İtiraz uygulamayı durdurmadı';end if;
 if hakim is not null and hakim<>hedef and not oyun.sokak_yonetebilir(hakim) then
  perform set_config('request.jwt.claim.sub',hakim::text,true);perform public.sokak_karar_yanit(k,'onandi','Yargı incelemesi sonucu yaptırım onandı');
  if not oyun.sokak_yaptirimli(hedef,e) then raise exception 'Yargı onayı uygulanmadı';end if;
 end if;
 update oyun.sokak_karar set zaman=oyun.simdi()-interval '25 hours' where eylem_id=e;
 perform set_config('request.jwt.claim.sub',cb::text,true);
 begin perform public.sokak_hukumet_karar(e,'dagitma','Kırmızı olmayan eylemi dağıtma testi');raise exception 'TEST kırmızı şartı yok';exception when others then if sqlerrm like 'TEST%' then raise;end if;end;
 update oyun.sokak_eylem set kirmizi_baslangic=oyun.simdi()-interval '13 hours' where id=e;
 perform public.sokak_hukumet_karar(e,'dagitma','Ek bütçe ile dağıtma kararı test gerekçesi');
 if (select durum from oyun.sokak_eylem where id=e)<>'yatisti' then raise exception 'Dağıtma kapanmadı';end if;
 if has_function_privilege('anon','public.sokak_hukumet_karar(bigint,text,text,uuid)','execute') then raise exception 'Anon açık';end if;
end $$;
rollback;
select 'PASS: CB/İçişleri yetkisi, kamu tahsilatı, bekleme, uzlaşma ret, yönlendirme, uyarı/geri tepme, yaptırım/itiraz/yargı ve dağıtma' result;
