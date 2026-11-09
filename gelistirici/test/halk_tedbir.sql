-- Gerçek sunucuda yalnız BEGIN/ROLLBACK. Üretim kasasına yazılmaz; işlem geri alınır.
-- Çalıştırmak için mevcut oyun şeması ve 20261109150000 migration'ı gerekir.
begin;
set local lock_timeout='3s'; set local statement_timeout='45s';
do $$
declare cb uuid; lider uuid; pid bigint; e bigint; il integer; v jsonb; once numeric; sonra numeric; kasa numeric; bedel numeric;
begin
 if not exists(select 1 from pg_proc where proname='sokak_tedbir_ac') then raise exception 'Migration uygulanmamış'; end if;
 select user_id into cb from oyun.makamlar where tur='cb' and bit is null limit 1;
 select p.id,pa.id,p.il_id into lider,pid,il from oyun.partiler pa join oyun.profiller p on p.id=pa.gb where not pa.kapali and not p.yasakli limit 1;
 if cb is null or lider is null then raise exception 'Test rolleri eksik'; end if;
 update oyun.bakanlik_kasa set kasa=1000 where kod='icisleri';
 insert into oyun.sokak_eylem(il_id,parti_id,baslatan,gerekce,baslangic,bitis,durum) values(il,pid,lider,'Yeni hükümet araçları geri alınacak test eylemi',oyun.simdi()-interval '2 hours',oyun.simdi()+interval '48 hours','aktif') returning id into e;
 insert into oyun.sokak_talep values(e,'hizmet');
 perform set_config('request.jwt.claim.sub',lider::text,true);
 begin perform public.sokak_tedbir_ac(e,'hizmet','Yetkisiz oyuncu bu aracı açamamalıdır'); raise exception 'TEST yetkisiz'; exception when others then if sqlerrm like 'TEST%' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',cb::text,true);
 begin perform public.sokak_tedbir_ac(e,'vergi_tatil','Vergi aracı hizmet eyleminde açılmamalıdır'); raise exception 'TEST yanlış talep'; exception when others then if sqlerrm like 'TEST%' then raise; end if; end;
 select memnuniyet into once from oyun.il_durum where il_id=il;
 select kasa into kasa from oyun.bakanlik_kasa where kod='icisleri';
 bedel:=oyun.sokak_tedbir_bedel(e,'hizmet');
 if bedel<> (select baslatma_bedeli*5 from oyun.sokak_eylem_ayar where id=1) then raise exception 'Hizmet bedeli 5 kat değil'; end if;
 v:=public.sokak_tedbir_ac(e,'hizmet','İl hizmetini bugün yükseltmeyi taahhüt ediyoruz');
 select memnuniyet into sonra from oyun.il_durum where il_id=il;
 if sonra<>least(100,once+4) then raise exception 'İl memnuniyeti +4 olmadı'; end if;
 if abs((select kasa from oyun.bakanlik_kasa where kod='icisleri')-(kasa-bedel/oyun.pazar_tl_milyar()))>0.0001 then raise exception 'İçişleri kasası yanlış'; end if;
 perform set_config('request.jwt.claim.sub',lider::text,true);
 perform public.sokak_tedbir_hamle(e,'yetersiz','hizmet');
 if (select durum from oyun.sokak_tedbir where id=(v->>'tedbir_id')::bigint)<>'yetersiz' then raise exception 'Tek katılımcının yetersiz oyu işlemedi'; end if;
 if (select memnuniyet from oyun.il_durum where il_id=il)<>once then raise exception 'Yetersiz oy hizmet artışını geri almadı'; end if;
 if has_function_privilege('anon','public.sokak_tedbir_ac(bigint,text,text)','execute') then raise exception 'Anon açık'; end if;
 if has_function_privilege('anon','public.sokak_tedbir_hamle(bigint,text,text)','execute') then raise exception 'Anon hamle açık'; end if;
 if has_function_privilege('authenticated','oyun.sokak_tedbir_tick()','execute') then raise exception 'İç tick açık'; end if;
end $$;
rollback;
select 'PASS: yetki, talep kilidi, hizmet +4, kasa, yetersiz geri alma, anon kapalı' result;
