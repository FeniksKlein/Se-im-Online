\set ON_ERROR_STOP 1
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select 'Y1 ver', jsonb_array_length((public.gby_yetki_ver('y','teskilat'))->'yardimcilar');
select public.gby_yetki_ver('y','mali',1000) is not null;
select 'Y2 al mali', public.gby_yetki_al('y','mali')->'yardimcilar'->0->'yetkiler';
select 'Y3 teskilat duruyor', oyun.teskilat_yonetici('00000000-0000-0000-0000-000000000002',1), oyun.parti_gorevli('00000000-0000-0000-0000-000000000002',array['mali']);
update oyun.parti_gby set miting_yetkisi=false where user_id='00000000-0000-0000-0000-000000000002';
select 'Y4 miting senkron', exists(select 1 from oyun.parti_gby_yetki where yetki='miting' and aktif);
-- il: mevcut geçici başkan y; seçilmiş yoksa görevden al + kongre
select 'K1 gorevden al', public.il_baskan_gorevden_al(6,'Teşkilat çalışmalarını yürütmediği için işten el çektirme')->'kongre'->>'tur';
update oyun.il_kongre set aday_bit=now()-interval '1 minute', acilis=now()-interval '2 days';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
do $$ begin perform public.il_kongre_aday_ol((select id from oyun.il_kongre),'vaat'); exception when others then raise notice 'K2 aday süresi geçti: %', sqlerrm; end $$;
update oyun.il_kongre set aday_bit=now()+interval '1 hour';
select 'K2 aday', jsonb_array_length(public.il_kongre_aday_ol((select id from oyun.il_kongre),'vaat')->'kongre'->'adaylar');
update oyun.il_kongre set aday_bit=now()-interval '1 minute';
select 'K3 oy', public.il_kongre_oy((select id from oyun.il_kongre),'u3')->'kongre'->>'oy_sayisi';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',false);
select public.il_kongre_oy((select id from oyun.il_kongre),'u3') is not null;
do $$ begin perform public.il_kongre_oy((select id from oyun.il_kongre),'u3'); exception when others then raise notice 'K4 ikinci oy: %', sqlerrm; end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000005',false);
do $$ begin perform public.il_kongre_oy((select id from oyun.il_kongre),'u3'); exception when others then raise notice 'K5 sonradan üye: %', sqlerrm; end $$;
update oyun.il_kongre set oy_bit=now()-interval '1 second';
select 'K6 tick', oyun.il_kongre_tick();
select 'K6 sonuc', kad, statu, donem_bit is not null from oyun.il_baskanlik b join oyun.profiller p on p.id=b.user_id where aktif;
-- seçilmiş başkanın yerine eski uçtan atama denemesi
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
do $$ begin perform public.teskilat_gorev_ver(6,'u4'); exception when others then raise notice 'K7 secilmis koruma: %', left(sqlerrm,60); end $$;
-- YK
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select 'K8 yk', public.il_yk_ekle(6,'u4','Seçim İşleri')->'yonetim_kurulu';
-- il başkanı başka partiye geçer
update oyun.profiller set parti_id=2 where kad='u3';
select 'K9 parti degisti', (select count(*) from oyun.il_baskanlik where aktif), (select count(*) from oyun.parti_teskilat_gorev where aktif);
-- GBY partiden ayrılır
update oyun.profiller set parti_id=null where kad='y';
select 'Y5 uyelik bitti', count(*) from oyun.parti_gby_yetki where aktif;
select 'Y6 unvan', oyun.gby_unvan('00000000-0000-0000-0000-000000000002');
-- tüzük
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
select 'T1 tuzuk', public.parti_tuzuk_ayarla('{"gby_azami":10}')->'tuzuk'->>'gby_azami';
