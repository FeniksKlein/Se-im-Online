-- 19 Ekim 2026: Parti kuruluş başvurusu sürerken yeni kurucu davetleri gönderilebilir.
-- Oyuncuları, mevcut davetleri, verilen cevapları veya başvuru bitiş tarihini değiştirmez.
begin;
create or replace function public.kurucu_davet_ekle(p_basvuru bigint, p_kadlar text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 p oyun.profiller:=oyun.profilim();
 b oyun.kurucu_basvuru;
 t timestamptz:=oyun.simdi();
 nick text;
 hedef oyun.profiller;
 toplam int;
 eklenen int:=0;
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru for update;
 if b.id is null or b.kurucu is distinct from p.id or b.durum<>'bekliyor' or b.bit<=t then
  raise exception 'Yalnızca kendine ait, süresi dolmamış kuruluş başvurusuna davet ekleyebilirsin.';
 end if;
 if coalesce(cardinality(p_kadlar),0) not between 1 and 20 then
  raise exception 'En az 1, en çok 20 yeni kurucu adayı yaz.';
 end if;
 select count(*) into toplam from oyun.kurucu_davet where basvuru_id=b.id;
 if toplam+cardinality(p_kadlar)>20 then
  raise exception 'Bu başvuruya toplam en fazla 20 kişi davet edebilirsin. Kalan hak: %.',greatest(0,20-toplam);
 end if;
 foreach nick in array p_kadlar loop
  nick:=btrim(coalesce(nick,''));
  if nick='' then raise exception 'Boş kullanıcı adı yazılamaz.'; end if;
  select * into hedef from oyun.profiller where lower(kad)=lower(nick) and not yasakli;
  if hedef.id is null or hedef.id=p.id then
   raise exception 'Kurucu adayı bulunamadı veya kendini davet ettin: %',nick;
  end if;
  if exists(select 1 from oyun.kurucu_davet where basvuru_id=b.id and user_id=hedef.id) then
   raise exception '% bu başvuruya zaten davet edilmiş.',hedef.kad;
  end if;
  insert into oyun.kurucu_davet(basvuru_id,user_id,zaman) values(b.id,hedef.id,t);
  eklenen:=eklenen+1;
  perform oyun.bildir(hedef.id,format('%s seni %s (%s) partisinin kurucular kuruluna davet etti. Partiler > Kurucu davetleri ekranından evet/hayır yanıtla. Onay verirsen kuruluşta partiye katılırsın.',p.kad,b.ad,b.kisa),t);
 end loop;
 return jsonb_build_object('basvuru_id',b.id,'eklenen',eklenen,'toplam',toplam+eklenen,'kalan',20-toplam-eklenen);
end $$;
revoke all on function public.kurucu_davet_ekle(bigint,text[]) from public,anon,authenticated;
grant execute on function public.kurucu_davet_ekle(bigint,text[]) to authenticated;
commit;
