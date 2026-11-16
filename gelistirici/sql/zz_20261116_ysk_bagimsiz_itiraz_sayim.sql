
-- Bagimsiz YSK: Baro kaynakli partisiz mahkeme uyesi karar verir; oylar silinmez.
alter table oyun.adliye_secim_itirazlari add column if not exists il_id smallint references oyun.iller(id);
alter table oyun.adliye_secim_itirazlari add column if not exists karar_islem text;
alter table oyun.adliye_secim_itirazlari add column if not exists eski_sonuc jsonb;
alter table oyun.adliye_secim_itirazlari add column if not exists yeni_sonuc jsonb;
alter table oyun.adliye_secim_itirazlari add column if not exists eski_kazanan jsonb;
alter table oyun.adliye_secim_itirazlari add column if not exists yeni_kazanan jsonb;
alter table oyun.adliye_secim_itirazlari add column if not exists yenileme jsonb;

create or replace function oyun.ysk_yetkili(u uuid) returns boolean language sql stable set search_path to '' as $f$
 select u is not null
  and exists(select 1 from oyun.mahkeme_uye mu where mu.sira=2 and mu.kaynak='baro' and mu.user_id=u)
  and exists(select 1 from oyun.profiller p where p.id=u and p.parti_id is null and not p.yasakli)
  and not exists(select 1 from oyun.makamlar m where m.user_id=u and m.bit is null);
$f$;

create or replace function public.ysk_itiraz_dosyalari() returns jsonb
 language sql stable security definer set search_path to '' as $f$
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'secim',i.secim_id,'parti',p.kisa,
  'gerekce',i.gerekce,'deliller',i.deliller,'durum',i.durum,'il_id',i.il_id,'zaman',i.zaman,
  'karar_islem',i.karar_islem,'karar_gerekce',i.karar_gerekce) order by i.zaman desc),'[]'::jsonb)
 from oyun.adliye_secim_itirazlari i join oyun.partiler p on p.id=i.parti_id
 where oyun.ysk_yetkili(auth.uid()) or p.gb=auth.uid();
$f$;
revoke all on function public.ysk_itiraz_dosyalari() from public,anon;
grant execute on function public.ysk_itiraz_dosyalari() to authenticated;

create or replace function public.ysk_secim_itiraz_ac(p_secim bigint,p_parti bigint,p_il integer,p_gerekce text,p_deliller text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare s oyun.secimler; j jsonb; pid bigint;
begin
 select * into s from oyun.secimler where id=p_secim;
 if s.id is null then raise exception 'Secim yok.';end if;
 if p_il is not null then
  if s.tur<>'bel' or not exists(select 1 from oyun.iller where id=p_il)
    or (s.hedef_il_id is not null and s.hedef_il_id<>p_il::smallint)
  then raise exception 'Il secimi itirazi icin gecerli bir il sec.';end if;
 end if;
 j:=public.adliye_secim_itiraz_ac(p_secim,p_parti,p_gerekce,p_deliller);
 pid:=(j->>'id')::bigint;
 update oyun.adliye_secim_itirazlari set il_id=p_il::smallint where id=pid;
 return j;
end $f$;
revoke all on function public.ysk_secim_itiraz_ac(bigint,bigint,integer,text,text) from public,anon;
grant execute on function public.ysk_secim_itiraz_ac(bigint,bigint,integer,text,text) to authenticated;

create or replace function oyun.ysk_tekrar_secim(s oyun.secimler,p_parti bigint,p_il smallint)
 returns jsonb language plpgsql set search_path to '' as $f$
declare t timestamptz:=oyun.simdi(); q date:=(t at time zone 'Europe/Istanbul')::date+1;
 dm text; a bigint; b bigint; r jsonb;
begin
 if s.tur='bel' then
  p_il:=coalesce(p_il,s.hedef_il_id);
  if p_il is null then raise exception 'Belediye secimi iptali icin il secilmelidir.'; end if;
  return oyun.ara_secim_olustur('bel',null,p_il,t);
 elsif s.tur='kurultay' then
  return oyun.ara_secim_olustur('gb',p_parti,null,t);
 elsif s.tur in ('cb','cb2') then
  return oyun.ara_secim_olustur('cb',null,null,t);
 elsif s.tur='mv' then
  dm:='ysk-tekrar-'||s.id||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,ara,ara_neden)
    values ('mv_on',dm,t,oyun.tr_an(q,8),oyun.tr_an(q,8),oyun.tr_an(q,22),
             oyun.tr_an(q,22,30),true,'ysk_iptal') returning id into a;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden)
    values ('mv',dm,null,null,oyun.tr_an(q+1,8),oyun.tr_an(q+1,22),
             oyun.tr_an(q+1,22,30),oyun.tr_an(q+1,23),true,'ysk_iptal') returning id into b;
  return jsonb_build_object('secim_id',b,'on_secim_id',a,'tur','mv','ara',true,'oy_bas',oyun.tr_an(q+1,8));
 else
  raise exception 'Bu secim turunde YSK yenileme karari su an desteklenmiyor.';
 end if;
end $f$;

create or replace function public.ysk_secim_itiraz_karar(p_itiraz bigint,p_islem text,p_gerekce text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare u uuid:=auth.uid(); it oyun.adliye_secim_itirazlari; s oyun.secimler;
 eskison jsonb; yenison jsonb; eskik jsonb; yenik jsonb; yenileme jsonb;
 v_durum text; degisti boolean:=false; t timestamptz:=oyun.simdi();
begin
 if not oyun.ysk_yetkili(u) then raise exception 'Itirazi yalnizca bagimsiz Baro kaynakli YSK hakemi karara baglayabilir.';end if;
 if p_islem not in ('ret','yeniden_sayim','iptal') then raise exception 'Karar: ret, yeniden_sayim veya iptal.';end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 30 and 5000 then raise exception 'Gerekceli karar 30-5000 karakter olmalidir.';end if;
 select * into it from oyun.adliye_secim_itirazlari where id=p_itiraz for update;
 if it.id is null or it.durum<>'bekliyor' then raise exception 'Bekleyen itiraz bulunamadi.';end if;
 if p_islem='iptal' and char_length(trim(coalesce(it.deliller,'')))<20 then raise exception 'Secim iptali somut delillere dayanmali.';end if;
 if exists(select 1 from oyun.adaylar a where a.user_id=u and a.secim_id=it.secim_id)
  then raise exception 'Hakem kendi aday oldugu secimi inceleyemez.';end if;
 select * into s from oyun.secimler where id=it.secim_id for update;
 if s.id is null or s.sonuc is null or s.durum not in ('sonuclandi','tamam')
    or s.sonuc ? 'iptal' then raise exception 'Secim sonucu kesinlesmemis veya daha once iptal edilmis.';end if;
 eskison:=s.sonuc;
 select coalesce(jsonb_agg(jsonb_build_object('user',k.user_id,'il',k.il_id,'parti',k.parti_id)
        order by k.user_id,k.il_id),'[]'::jsonb) into eskik from oyun.kazananlar k where k.secim_id=s.id;
 if p_islem='yeniden_sayim' then
   if s.tur not in ('mv','bel','cb','cb2','kurultay') then raise exception 'Bu turde resmi sayim duzeltmesi desteklenmiyor.';end if;
   -- Oy kayitlari DEGISTIRILMEZ. Eski kazananlar bu transaction icinde yeniden hesaplanir.
   delete from oyun.kazananlar where secim_id=s.id;
   yenison:=case s.tur when 'mv' then oyun._sonuc_mv(s)
     when 'bel' then oyun._sonuc_cok_alanli(s)
     when 'kurultay' then oyun._sonuc_cok_alanli(s)
     when 'cb' then oyun._sonuc_cb(s)
     when 'cb2' then oyun._sonuc_cb2(s) end;
   select coalesce(jsonb_agg(jsonb_build_object('user',k.user_id,'il',k.il_id,'parti',k.parti_id)
         order by k.user_id,k.il_id),'[]'::jsonb) into yenik
     from oyun.kazananlar k where k.secim_id=s.id;
   degisti:=eskik is distinct from yenik;
   if degisti and s.durum='tamam' and s.goreve_bas is not null and s.goreve_bas<=t then
     -- Siyasi makamlar hakem tarafindan aniden silinmez; itirazli secim yenilenir.
     yenileme:=oyun.ysk_tekrar_secim(s,it.parti_id,it.il_id);
     yenison:=coalesce(yenison,'{}'::jsonb)||jsonb_build_object('ysk_yenileme',yenileme,'ysk_sayim_degisti',true);
   else
     yenison:=coalesce(yenison,'{}'::jsonb)||jsonb_build_object('ysk_sayim',true);
   end if;
   update oyun.secimler set sonuc=yenison where id=s.id;
 elsif p_islem='iptal' then
   yenileme:=oyun.ysk_tekrar_secim(s,it.parti_id,it.il_id);
   yenison:=eskison||jsonb_build_object('iptal','ysk_karari','ysk_yenileme',yenileme);
   update oyun.secimler set sonuc=yenison,
     durum=case when s.durum='sonuclandi' then 'tamam' else s.durum end where id=s.id;
   yenik:=eskik;
 else
   yenison:=eskison; yenik:=eskik;
 end if;
 v_durum:=case when p_islem='ret' then 'ret' else 'kabul' end;
 update oyun.adliye_secim_itirazlari set durum=v_durum,karar_veren=u,karar_gerekce=trim(p_gerekce),
    karar_at=t,karar_islem=p_islem,eski_sonuc=eskison,yeni_sonuc=yenison,
    eski_kazanan=eskik,yeni_kazanan=yenik,yenileme=yenileme where id=it.id;
 perform oyun.bildir(it.yapan,format('YSK secim itirazi #%s: %s. %s',it.id,p_islem,left(trim(p_gerekce),180)),t);
 perform oyun.olay('secim',format('Bagimsiz YSK hakemi secim itirazi #%s icin %s karari verdi.',it.id,p_islem),null,it.parti_id,t);
 return jsonb_build_object('tamam',true,'karar',p_islem,'degisen_kazanan',degisti,
   'yenileme',yenileme,'eski_kazanan',eskik,'yeni_kazanan',yenik);
end $f$;
revoke all on function public.ysk_secim_itiraz_karar(bigint,text,text) from public,anon;
grant execute on function public.ysk_secim_itiraz_karar(bigint,text,text) to authenticated;

-- Mevcut eski ekran kabul/ret RPC'si ayni bagimsiz YSK guvencesini kullanir.
create or replace function public.adliye_secim_itiraz_karar(p_itiraz bigint,p_karar text,p_gerekce text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
begin
 if p_karar not in ('kabul','ret') then raise exception 'Gecersiz karar.';end if;
 return public.ysk_secim_itiraz_karar(p_itiraz,case when p_karar='kabul' then 'yeniden_sayim' else 'ret' end,p_gerekce);
end $f$;
