begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
do $$
declare u uuid; pid bigint; eid bigint; n integer:=0; kisi record; ids bigint[]; risk numeric; old numeric; cb uuid;
begin
 select p.id,pa.id into u,pid from oyun.partiler pa join oyun.profiller p on p.id=pa.gb where not pa.kapali and not p.yasakli and not oyun.sokak_iktidar(p.id) limit 1;
 update oyun.sokak_eylem_ayar set aktif=true where id=1;
 update oyun.ulke set memnuniyet=0,issizlik=30 where id=1;
 update oyun.il_durum set memnuniyet=0 where il_id in (46,47,48);
 for n in 46..48 loop
  insert into oyun.sokak_eylem(il_id,parti_id,baslatan,gerekce,baslangic,bitis,muhalefet_fonu) values(n,pid,u,'Kriz senaryosu geri alınacak test',oyun.simdi()-interval '80 hours',oyun.simdi()+interval '40 hours',1000000) returning id into eid;
  ids:=array_append(ids,eid);
 end loop;
 n:=0;
 for kisi in select id from oyun.profiller where not yasakli loop
  n:=n+1;
  update oyun.profiller set il_id=46+(n%3),il_at=oyun.simdi()-interval '10 days',olusturma=least(olusturma,oyun.simdi()-interval '10 days'),son_gorulme=oyun.simdi() where id=kisi.id;
  insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,taraf,temsilci) values(ids[1+(n%3)],'oyuncu',kisi.id::text,'muhalefet',kisi.id);
 end loop;
 perform oyun.sokak_tick();
 if (select count(*) from oyun.sokak_eylem where id=any(ids) and kirmizi_baslangic is not null)<>3 then raise exception 'Üç kırmızı il oluşmadı'; end if;
 if (select kirmizi_baslangic from oyun.sokak_kriz where id=1) is null then raise exception 'Ulusal sayaç başlamadı'; end if;
 -- Erken seçim dalı bir alt işlemde sınanır ve tüm takvim değişiklikleri geri alınır.
 begin
  update oyun.sokak_kriz set kirmizi_baslangic=oyun.simdi()-interval '73 hours',son_secim=null where id=1;
  update oyun.makamlar set bas=oyun.simdi()-interval '8 days' where tur='cb' and bit is null;
  update oyun.secimler set durum='tamam',goreve_bas=oyun.simdi()-interval '1 day' where tur in ('mv','cb','cb2') and (durum<>'tamam' or goreve_bas>oyun.simdi());
  perform oyun.sokak_tick();
  if (select son_secim from oyun.sokak_kriz where id=1) is null then raise exception 'Erken seçim tetiklenmedi'; end if;
  if not exists(select 1 from oyun.secimler where donem=(select secim_donem from oyun.sokak_kriz where id=1) and tur='mv') then raise exception 'MV seçimi oluşturulmadı'; end if;
  raise exception using errcode='ZX001',message='Test seçim alt işlemini geri al';
 exception when sqlstate 'ZX001' then null; end;
 risk:=oyun.sokak_piyasa_riski(); if risk<>0.03 then raise exception 'Risk yanlış: %',risk; end if;
 update oyun.sokak_eylem set iktidar_fonu=muhalefet_fonu*3 where id=ids[1];
 perform oyun.sokak_tick();
 if (select kirmizi_baslangic from oyun.sokak_kriz where id=1) is not null then raise exception 'Kesintide sayaç sıfırlanmadı'; end if;
 update oyun.sokak_eylem set bitis=oyun.simdi()-interval '1 second' where id=any(ids);
 perform oyun.sokak_tick();
 if exists(select 1 from oyun.sokak_eylem where id=any(ids) and durum='aktif') then raise exception 'Süre sonu kapanmadı'; end if;
 if oyun.sokak_piyasa_riski()<>0 then raise exception 'Risk kalkmadı'; end if;
end $$;
rollback;
select 'PASS: üç ilde kırmızı, ülke katılım eşiği, 72 saat sayacı başlangıcı/sıfırlanması, piyasa riskinin kalkması, süre sonu' result;
