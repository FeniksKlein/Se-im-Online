begin;
-- Adliye: mevcut sözcülerin dava bildirimleri ve üyelerin dosyaya özel temsil yetkisi
-- Oyuncu verileri, makamlar ve mevcut dava kayıtları değiştirilmez.
create or replace function public.adliye_sozcu_ata(p_parti bigint,p_kad text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; eski uuid; t timestamptz:=oyun.simdi();
begin
 if not exists(select 1 from oyun.partiler where id=p_parti and gb=p.id and not kapali) then raise exception 'Parti sözcüsünü yalnız partinin genel başkanı belirleyebilir.'; end if;
 if p_kad is not null and trim(p_kad)<>'' then
  select * into u from oyun.profiller where lower(kad)=lower(trim(p_kad)) and parti_id=p_parti and not yasakli;
  if u.id is null then raise exception 'Bu partide böyle bir üye bulunamadı.'; end if;
 end if;
 select user_id into eski from oyun.parti_sozcu where parti_id=p_parti for update;
 insert into oyun.parti_sozcu(parti_id,user_id,atayan,zaman) values(p_parti,u.id,p.id,t)
 on conflict (parti_id) do update set user_id=excluded.user_id,atayan=excluded.atayan,zaman=excluded.zaman;
 insert into oyun.parti_sozcu_kayit(parti_id,yapan,eski,yeni,zaman) values(p_parti,p.id,eski,u.id,t);
 if eski is not null and eski is distinct from u.id then
  insert into oyun.bildirimler(user_id,zaman,metin) values(eski,t,'Parti sözcülüğü göreviniz sona erdi. Yeni davalarda parti adına temsil yetkiniz bulunmuyor.');
 end if;
 if u.id is not null then
  insert into oyun.bildirimler(user_id,zaman,metin) values(u.id,t,'Parti genel başkanınız sizi Parti Sözcüsü olarak atadı. Adliye davalarında partinizi savunabilirsiniz.');
  insert into oyun.bildirimler(user_id,zaman,metin)
  select u.id,t,'Adliye dava #'||d.id||': Partiniz hakkındaki açık davada sözcü olarak savunma yapabilirsiniz.'
  from oyun.adliye_davalar d where d.davali_parti=p_parti and d.durum='acik'
  order by d.id desc limit 20;
  insert into oyun.bildirimler(user_id,zaman,metin)
  select u.id,t,'Adliye dava #'||d.id||': Parti üyenizin size verdiği temsil yetkisiyle kişisel davasında savunma yapabilirsiniz.'
  from oyun.adliye_davalar d
  join oyun.adliye_temsil y on y.dava_id=d.id and y.aktif and y.yetki_veren=d.davali
  join oyun.profiller dav on dav.id=d.davali and dav.parti_id=p_parti
  where d.durum='acik' order by d.id desc limit 20;
 end if;
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.adliye_temsil_yetkisi(p_dava bigint,p_izin boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; sozcu uuid; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.davali<>p.id or d.durum<>'acik' then raise exception 'Bu davada temsil yetkisi veremezsiniz.'; end if;
 if p_izin is null then raise exception 'Temsil izni seçimi geçersiz.'; end if;
 select s.user_id into sozcu from oyun.parti_sozcu s
 join oyun.profiller pr on pr.id=s.user_id and pr.parti_id=s.parti_id and not pr.yasakli
 where s.parti_id=p.parti_id;
 if p_izin and sozcu is null then raise exception 'Partinizde görevli bir sözcü bulunmuyor.'; end if;
 insert into oyun.adliye_temsil(dava_id,yetki_veren,aktif) values(d.id,p.id,p_izin)
 on conflict(dava_id,yetki_veren) do update set aktif=excluded.aktif,yetki_verildi=t;
 if sozcu is not null then
  insert into oyun.bildirimler(user_id,zaman,metin)
  values(sozcu,t,'Adliye dava #'||d.id||': '||p.kad||case when p_izin then ' kişisel davasında size savunma ve beyan yetkisi verdi. Adliye bölümündeki dosyaya girin.' else ' kişisel davasında temsil yetkinizi geri aldı.' end);
 end if;
 return jsonb_build_object('tamam',true);
end $$;

revoke all on function public.adliye_sozcu_ata(bigint,text) from public,anon;
revoke all on function public.adliye_temsil_yetkisi(bigint,boolean) from public,anon;
grant execute on function public.adliye_sozcu_ata(bigint,text) to authenticated;
grant execute on function public.adliye_temsil_yetkisi(bigint,boolean) to authenticated;
commit;
