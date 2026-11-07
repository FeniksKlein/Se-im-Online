-- Bütün test verileri geri alınır; canlı hesaplarda kalıcı değişiklik yapılmaz.
begin;
set local lock_timeout='3s';
set local statement_timeout='25s';
do $$
declare u uuid; pid bigint; eid bigint; bakiye numeric; v jsonb; cb uuid; kisi uuid; once numeric;
begin
 select p.id,pa.id into u,pid from oyun.partiler pa join oyun.profiller p on p.id=pa.gb where not pa.kapali and not p.yasakli and not oyun.sokak_iktidar(p.id) and p.olusturma<oyun.simdi()-interval '7 days' limit 1;
 if u is null then raise exception 'Test için muhalefet genel başkanı yok'; end if;
 select user_id into cb from oyun.makamlar where tur='cb' and bit is null limit 1;
 perform set_config('request.jwt.claim.sub',u::text,true);
 update oyun.sokak_eylem_ayar set aktif=true where id=1;
 update oyun.partiler set kasa=2000000 where id=pid;
 update oyun.il_durum set memnuniyet=0 where il_id=48;
 update oyun.ulke set memnuniyet=0,issizlik=20 where id=1;
 update oyun.profiller set il_id=48,il_at=oyun.simdi()-interval '10 days',olusturma=least(olusturma,oyun.simdi()-interval '10 days'),son_gorulme=oyun.simdi() where id in (select id from oyun.profiller where not yasakli and not oyun.sokak_iktidar(id) limit 8) or id=u;
 v:=public.sokak_eylem_baslat(48,'Test: belediye hizmetlerinde iyileştirme istiyoruz'); eid:=(v->>'eylem_id')::bigint;
 if (select kasa from oyun.partiler where id=pid)<>1950000 then raise exception 'Başlangıç tahsilatı yanlış'; end if;
 begin perform public.sokak_eylem_baslat(48,'Tekrarlı eylem testi gerekçesi'); raise exception 'TEST: cooldown işlemedi'; exception when others then if sqlerrm like 'TEST:%' then raise; end if; end;
 begin perform public.sokak_destek(eid,'muhalefet','oyuncu',null,-1); raise exception 'TEST: negatif tutar kabul edildi'; exception when others then if sqlerrm like 'TEST:%' then raise; end if; end;
 perform public.sokak_destek(eid,'muhalefet','parti',pid,200000);
 if (select kasa from oyun.partiler where id=pid)<>1750000 then raise exception 'Fon tahsilatı yanlış'; end if;
 begin perform public.sokak_destek(eid,'muhalefet','parti',pid,1000); raise exception 'TEST: günlük limit işlemedi'; exception when others then if sqlerrm like 'TEST:%' then raise; end if; end;
 if (select kirmizi_baslangic from oyun.sokak_eylem where id=eid) is not null then raise exception 'Yalnız para kırmızı yaptı'; end if;
 for kisi in select id from oyun.profiller where il_id=48 and not yasakli and not oyun.sokak_iktidar(id) and il_at<oyun.simdi()-interval '3 days' limit 8 loop
  perform set_config('request.jwt.claim.sub',kisi::text,true);
  perform public.sokak_destek(eid,'muhalefet'); perform public.sokak_destek(eid,'muhalefet');
 end loop;
 if (select count(*) from oyun.sokak_eylem_destek where eylem_id=eid and destek_turu='katilim')>8 then raise exception 'Katılım mükerrer'; end if;
 perform set_config('request.jwt.claim.sub',cb::text,true);
 perform public.sokak_yanit(eid,'Test hükümet yanıtı: belediye hizmetleri için çözüm paketi.');
 update oyun.cuzdan set para=1000000 where user_id=cb;
 perform public.sokak_destek(eid,'iktidar','oyuncu',null,300000);
 perform public.sokak_eylemler();
 perform oyun.sokak_tick();
 select memnuniyet into once from oyun.ulke where id=1;
 perform oyun.sokak_tick();
 if (select memnuniyet from oyun.ulke where id=1)<>once then raise exception 'Tick mükerrer etki'; end if;
 update oyun.sokak_eylem set iktidar_fonu=muhalefet_fonu*3 where id=eid;
 perform oyun.sokak_yenile(eid);
 if (select durum from oyun.sokak_eylem where id=eid)<>'yatisti' then raise exception '3x yatışma başarısız'; end if;
 if has_function_privilege('anon','public.sokak_destek(bigint,text,text,bigint,numeric)','execute') then raise exception 'Anon yetkisi açık'; end if;
 if has_function_privilege('authenticated','oyun.sokak_tick()','execute') then raise exception 'Tick istemciye açık'; end if;
end $$;
rollback;
select 'PASS: başlatma, fon, günlük limit, katılım tekilliği, hükümet yanıtı, tick tekilliği, 3x uzlaşma, RPC yetkileri' result;
