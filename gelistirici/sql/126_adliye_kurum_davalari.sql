
-- Kurum davaları mevcut dosyaları ve bakiyeleri değiştirmeden eklenir.
alter table oyun.adliye_davalar add column if not exists davali_kurum_tur text;
alter table oyun.adliye_davalar add column if not exists davali_kurum_id text;
alter table oyun.adliye_davalar add column if not exists davali_kurum_ad text;
alter table oyun.adliye_davalar add column if not exists kurum_ceza_odenen numeric not null default 0;
alter table oyun.adliye_davalar drop constraint if exists adliye_tek_davali;
alter table oyun.adliye_davalar add constraint adliye_tek_davali check (
 (davali is not null)::int+(davali_parti is not null)::int+(davali_kurum_tur is not null)::int=1
 and ((davali_kurum_tur is null and davali_kurum_id is null and davali_kurum_ad is null)
 or (davali_kurum_tur in ('sirket','dernek','belediye','makam','bakanlik','gazete') and nullif(davali_kurum_id,'') is not null and nullif(davali_kurum_ad,'') is not null))
);
create index if not exists adliye_kurum_dava_idx on oyun.adliye_davalar(davali_kurum_tur,davali_kurum_id,id desc);
create or replace function oyun.adliye_kurum_adi(p_tur text,p_id text)
returns text language plpgsql stable set search_path='' as $$
declare v text;k bigint;
begin
 if p_tur in ('sirket','dernek','belediye','makam','gazete') then
  if p_id !~ '^[0-9]{1,18}$' then return null; end if;
  k:=p_id::bigint;
 end if;
 case p_tur
 when 'sirket' then select ad into v from oyun.sirketler where id=k and aktif;
 when 'dernek' then select ad into v from oyun.dernekler where id=k and not kapali;
 when 'belediye' then select ad||' Belediyesi' into v from oyun.iller where id=k;
 when 'makam' then select concat_ws(' · ','Makam: '||m.tur,i.ad,b.ad)
  into v from oyun.makamlar m left join oyun.iller i on i.id=m.il_id
  left join oyun.bakanliklar b on b.kod=m.bakanlik where m.id=k and m.bit is null;
 when 'bakanlik' then select ad into v from oyun.bakanliklar where kod=p_id;
 when 'gazete' then select ad into v from oyun.oyuncu_gazeteleri where id=k and aktif;
 end case;
 return v;
end $$;
create or replace function oyun.adliye_kurum_yetkili(p_tur text,p_id text,p_user uuid)
returns boolean language plpgsql stable set search_path='' as $$
declare k bigint;
begin
 if p_tur is null or p_id is null or p_user is null then return false; end if;
 if p_tur in ('sirket','dernek','belediye','makam','gazete') then
  if p_id !~ '^[0-9]{1,18}$' then return false; end if;
  k:=p_id::bigint;
 end if;
 case p_tur
 when 'sirket' then return exists(select 1 from oyun.sirketler s where s.id=k and
  (s.yonetici=p_user or (s.yonetici is null and s.kurucu=p_user) or
  exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=p_user and o.pay>0)));
 when 'dernek' then return exists(select 1 from oyun.dernekler d where d.id=k and
  (d.baskan=p_user or (d.baskan is null and d.kurucu=p_user)));
 when 'belediye' then return exists(select 1 from oyun.makamlar m where m.il_id=k and m.tur='bel' and m.bit is null and m.user_id=p_user);
 when 'makam' then return exists(select 1 from oyun.makamlar m where m.id=k and m.bit is null and m.user_id=p_user);
 when 'bakanlik' then return exists(select 1 from oyun.makamlar m where m.tur='bakan' and m.bakanlik=p_id and m.bit is null and m.user_id=p_user)
  or exists(select 1 from oyun.makamlar m where m.tur='cb' and m.bit is null and m.user_id=p_user);
 when 'gazete' then return exists(select 1 from oyun.oyuncu_gazeteleri g where g.id=k and g.sahip=p_user);
 end case;
 return false;
end $$;
create or replace function public.adliye_kurum_listesi()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform oyun.profilim();
 return coalesce((select jsonb_agg(jsonb_build_object('tur',v.tur,'id',v.id,'ad',v.ad) order by v.tur,v.ad)
 from (
 select 'sirket'::text tur,id::text id,ad from oyun.sirketler where aktif
 union all select 'dernek',id::text,ad from oyun.dernekler where not kapali
 union all select 'belediye',id::text,ad||' Belediyesi' from oyun.iller
 union all select 'makam',m.id::text,concat_ws(' · ','Makam: '||m.tur,i.ad,b.ad)
  from oyun.makamlar m left join oyun.iller i on i.id=m.il_id
  left join oyun.bakanliklar b on b.kod=m.bakanlik where m.bit is null
 union all select 'bakanlik',kod,ad from oyun.bakanliklar
 union all select 'gazete',id::text,ad from oyun.oyuncu_gazeteleri where aktif
 ) v),'[]'::jsonb);
end $$;
create or replace function public.adliye_kurum_dava_ac(
 p_hedef_tur text,p_hedef text,p_tur text,p_iddia text,p_delil text default '',
 p_davaci_parti bigint default null,p_tazminat_talep numeric default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); kurum_ad text; t timestamptz:=oyun.simdi(); yeni bigint;
 h numeric:=coalesce((select harc from oyun.mahkeme_ayar),0);
begin
 if p_hedef_tur not in ('sirket','dernek','belediye','makam','bakanlik','gazete') then raise exception 'Kurum türü geçersiz.'; end if;
 kurum_ad:=oyun.adliye_kurum_adi(p_hedef_tur,p_hedef);
 if kurum_ad is null then raise exception 'Kurum bulunamadı veya faal değil.'; end if;
 if oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,p.id) then raise exception 'Temsil ettiğiniz kuruma dava açamazsınız.'; end if;
 if p_tur not in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger','tazminat') then raise exception 'Dava türü geçersiz.'; end if;
 if char_length(trim(coalesce(p_iddia,''))) not between 20 and 1600 then raise exception 'İddia 20–1600 karakter olmalıdır.'; end if;
 if char_length(coalesce(p_delil,''))>1600 then raise exception 'Delil en fazla 1600 karakter olabilir.'; end if;
 if p_tur='tazminat' and (p_hedef_tur='makam' or p_tazminat_talep is null or
  p_tazminat_talep<1000 or p_tazminat_talep>500000 or p_tazminat_talep<>trunc(p_tazminat_talep))
  then raise exception 'Tazminat için 1.000–500.000 TL arasında tam sayı tutar gerekir; makamın kasası yoktur.'; end if;
 if p_davaci_parti is not null and not exists(select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id
  where pa.id=p_davaci_parti and not pa.kapali and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id)))
  then raise exception 'Parti adına dava açma yetkiniz yok.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'En fazla üç açık davanız olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Yeni dava için 10 dakika bekleyin.'; end if;
 if h>0 then perform oyun.para_islem(p.id,-h,'adliye','Dava harcı',t); end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali_kurum_tur,davali_kurum_id,davali_kurum_ad,tur,iddia,delil,acilis,savunma_son,karar_son,harc,harc_durum,kesin,tazminat_talep)
 values(p.id,p_davaci_parti,p_hedef_tur,p_hedef,kurum_ad,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+interval '6 hours',
 t+interval '6 hours'+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)),
 h,case when h>0 then 'yatirildi' end,false,case when p_tur='tazminat' then p_tazminat_talep end) returning id into yeni;
 perform oyun.bildir(q.id,format('Adliye #%s: %s aleyhine dava açıldı. Savunma süresi 6 saat.',yeni,kurum_ad),t)
  from oyun.profiller q where oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.id) and q.id<>p.id;
 perform oyun.bildir(q.user_id,format('Yüksek Mahkeme: yeni kurum davası #%s',yeni),t)
  from oyun.mahkeme_uye q where q.user_id is not null and q.user_id<>p.id and not oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.user_id);
 return jsonb_build_object('tamam',true,'id',yeni,'harc',h);
end $$;
create or replace function oyun.adliye_kurum_kes(p_tur text,p_id text,p_tutar numeric)
returns numeric language plpgsql set search_path='' as $$
declare k bigint; v numeric; n numeric;
begin
 if p_tutar is null or p_tutar<=0 or p_tur='makam' then return 0; end if;
 if p_tur in ('sirket','dernek','belediye','gazete') then k:=p_id::bigint; end if;
 case p_tur
 when 'sirket' then select greatest(coalesce(kasa,0),0) into v from oyun.sirketler where id=k for update;
 when 'dernek' then select greatest(coalesce(kasa,0),0) into v from oyun.dernekler where id=k for update;
 when 'belediye' then select greatest(coalesce(kasa,0),0) into v from oyun.il_durum where il_id=k for update;
 when 'bakanlik' then select greatest(coalesce(kasa,0),0) into v from oyun.bakanlik_kasa where kod=p_id for update;
 when 'gazete' then select greatest(coalesce(kasa,0),0) into v from oyun.oyuncu_gazeteleri where id=k for update;
 end case;
 n:=least(coalesce(v,0),p_tutar);
 if n<=0 then return 0; end if;
 case p_tur
 when 'sirket' then update oyun.sirketler set kasa=kasa-n where id=k;
 when 'dernek' then update oyun.dernekler set kasa=kasa-n where id=k;
 when 'belediye' then update oyun.il_durum set kasa=kasa-n where il_id=k;
 when 'bakanlik' then update oyun.bakanlik_kasa set kasa=kasa-n where kod=p_id;
 when 'gazete' then update oyun.oyuncu_gazeteleri set kasa=kasa-n where id=k;
 end case;
 return n;
end $$;
create or replace function oyun.adliye_kurum_kesinlesme() returns trigger language plpgsql set search_path='' as $$
declare tutar numeric:=0; alinan numeric:=0;
begin
 if new.davali_kurum_tur is null or new.af_at is not null then return new; end if;
 if new.karar='para_10b' then tutar:=10000;
 elsif new.karar='para_50b' then tutar:=50000;
 elsif new.karar='tazminat' then tutar:=least(coalesce(new.tazminat_tutar,0),500000);
 end if;
 if tutar>0 then alinan:=oyun.adliye_kurum_kes(new.davali_kurum_tur,new.davali_kurum_id,tutar); end if;
 if new.karar='tazminat' and alinan>0 then
  perform oyun.para_islem(new.davaci,alinan,'adliye','Adliye #'||new.id||' kurum tazminatı',oyun.simdi());
  update oyun.adliye_davalar set tazminat_odenen=coalesce(tazminat_odenen,0)+alinan where id=new.id;
 elsif alinan>0 then
  update oyun.adliye_davalar set kurum_ceza_odenen=coalesce(kurum_ceza_odenen,0)+alinan where id=new.id;
 end if;
 if new.karar not in ('beraat','dusme') and new.harc>0 then
  perform oyun.adliye_kurum_kes(new.davali_kurum_tur,new.davali_kurum_id,new.harc);
 end if;
 perform oyun.bildir(q.id,format('Adliye #%s kurum kararı kesinleşti: %s. Tahsil: %s TL.',new.id,new.karar,alinan),oyun.simdi())
  from oyun.profiller q where oyun.adliye_kurum_yetkili(new.davali_kurum_tur,new.davali_kurum_id,q.id);
 return new;
end $$;
drop trigger if exists adliye_kurum_kesinlesme on oyun.adliye_davalar;
create trigger adliye_kurum_kesinlesme after update of kesin on oyun.adliye_davalar
 for each row when (new.kesin=true and old.kesin=false and new.davali_kurum_tur is not null)
 execute function oyun.adliye_kurum_kesinlesme();
revoke all on function public.adliye_kurum_listesi(),public.adliye_kurum_dava_ac(text,text,text,text,text,bigint,numeric) from public,anon;
grant execute on function public.adliye_kurum_listesi(),public.adliye_kurum_dava_ac(text,text,text,text,text,bigint,numeric) to authenticated;

CREATE OR REPLACE FUNCTION public.adliye_tazminat_oy(p_dava bigint, p_tutar numeric, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 t timestamptz:=oyun.simdi(); cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalniz Yuksek Mahkeme uyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' or d.tur<>'tazminat' or (d.davali is null and (d.davali_kurum_tur is null or d.davali_kurum_tur='makam')) then
  raise exception 'Bu dosyada tazminata hukmedilemez.'; end if;
 if not p.id=any(oyun.dava_heyeti(d)) then raise exception 'Dava tarafi hakim oy kullanamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma suresini bekleyin.'; end if;
 if p_tutar is null or p_tutar<1000 or p_tutar>least(coalesce(d.tazminat_talep,0),500000) or p_tutar<>trunc(p_tutar) then
  raise exception 'Karar tutari 1.000 TL ile davacinin talebi arasinda tam sayi olmali.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekceli oy 20-2000 karakter olmali.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,tazminat_tutar,gerekce,zaman)
 values(d.id,p.id,'tazminat',p_tutar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar='tazminat',tazminat_tutar=excluded.tazminat_tutar,
  gerekce=excluded.gerekce,zaman=excluded.zaman,musadere_tutar=null,musadere_sorumlu=null,musadere_sirket=null;
 cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',cikti,'tutar',p_tutar);
end $function$
;

CREATE OR REPLACE FUNCTION oyun.adliye_kesinlestir(p_dava bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d oyun.adliye_davalar; mv bigint; alinan numeric; davaci_kazandi boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.kesin then return; end if;
 if not d.ceza_uygulandi and d.af_at is null then
  if d.karar='vekillik_dusur' and d.davali is not null then
   select id into mv from oyun.makamlar where user_id=d.davali and tur='mv' and bit is null order by bas desc limit 1;
   if mv is not null then
    update oyun.makamlar set bit=t,bitis_neden='Adliye #'||d.id||' karari'
     where user_id=d.davali and bit is null and tur in ('mv','tbmm','bskv','grup_bskv');
   end if;
  elsif d.karar in ('para_10b','para_50b') and d.davali is not null then
   alinan:=oyun.adliye_tahsil(d.davali,case d.karar when 'para_10b' then 10000 else 50000 end,
    'Adliye #'||d.id||' para cezasi',t);
  elsif d.karar='tazminat' and d.davali is not null then
   -- Odeme davanin kesinlesmesi ardindan takipli icra sistemiyle yapilir.
   null;
  elsif d.karar='aday_yasagi' then
   update oyun.profiller set adaylik_yasagi_bitis=greatest(coalesce(adaylik_yasagi_bitis,t),t+interval '30 days')
    where id=d.davali;
  elsif d.karar='parti_para' and d.davali_parti is not null then
   update oyun.partiler set kasa=kasa-least(kasa,25000) where id=d.davali_parti;
  end if;
 end if;
 davaci_kazandi:=d.karar not in ('beraat','dusme');
 if d.harc>0 and d.harc_durum='yatirildi' then
  if d.karar='dusme' or davaci_kazandi then
   perform oyun.para_islem(d.davaci,d.harc,'adliye','Adliye #'||d.id||' harc iadesi',t);
  end if;
  if davaci_kazandi then
   if d.davali is not null then
    perform oyun.adliye_tahsil(d.davali,d.harc,'Adliye #'||d.id||' yargilama harci',t);
   elsif d.davali_parti is not null then
    update oyun.partiler set kasa=kasa-least(kasa,d.harc) where id=d.davali_parti;
   end if;
  end if;
 end if;
 update oyun.adliye_davalar set kesin=true,ceza_uygulandi=true,
  mv_makam_id=coalesce(mv,mv_makam_id),
  harc_durum=case when harc>0 then case when karar='dusme' or davaci_kazandi then 'iade' else 'hazine' end end
  where id=d.id;
 if d.karar='tazminat' and d.davali is not null and d.af_at is null then
  perform oyun.adliye_tazminat_tahsil(d.id,t);
 end if;
 perform oyun.adliye_musadere_tahsil(d.id,t);
 perform oyun.bildir(x.id,format('Adliye #%s karari kesinlesti: %s.',d.id,d.karar),t)
  from (select d.davaci id union select d.davali where d.davali is not null) x;
end $function$
;

CREATE OR REPLACE FUNCTION oyun.dava_heyeti(d oyun.adliye_davalar)
 RETURNS uuid[]
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce(array_agg(user_id order by sira), '{}') from oyun.mahkeme_uye
   where user_id is not null and user_id is distinct from d.davaci and user_id is distinct from d.davali and not oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,user_id) and not exists (select 1 from oyun.adliye_ek_taraf et where et.dava_id=d.id and et.user_id=oyun.mahkeme_uye.user_id)
$function$
;

CREATE OR REPLACE FUNCTION public.adliye_oy_ver(p_dava bigint, p_karar text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 t timestamptz:=oyun.simdi(); karar_cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalniz Yuksek Mahkeme uyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Acik bir dava bulunamadi.'; end if;
 if not p.id=any(oyun.dava_heyeti(d)) then raise exception 'Yargic kendi davasinda oy kullanamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma suresinin dolmasini bekleyin.'; end if;
 if p_karar not in ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h',
  'vekillik_dusur','para_10b','para_50b','aday_yasagi','parti_para') then raise exception 'Gecersiz karar.'; end if;
 if d.davali_parti is not null and p_karar not in ('beraat','uyari','parti_para') then
  raise exception 'Partiye yalniz beraat, uyari veya hazine yardimi kesintisi verilebilir.'; end if;
 if d.davali_kurum_tur is not null and (p_karar not in ('beraat','uyari','para_10b','para_50b') or (d.davali_kurum_tur='makam' and p_karar not in ('beraat','uyari'))) then raise exception 'Bu kuruma seçilen yaptırım uygulanamaz.'; end if;
 if d.davali is not null and p_karar='parti_para' then raise exception 'Parti cezasi sadece partiye verilir.'; end if;
 if p_karar='vekillik_dusur' and not exists
   (select 1 from oyun.makamlar where user_id=d.davali and tur='mv' and bit is null) then
  raise exception 'Davalinin aktif milletvekilligi yok.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekceli oy 20-2000 karakter olmali.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,gerekce,zaman)
 values(d.id,p.id,p_karar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar=excluded.karar,gerekce=excluded.gerekce,
  zaman=excluded.zaman,tazminat_tutar=null,musadere_tutar=null,
  musadere_sorumlu=null,musadere_sirket=null;
 karar_cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',karar_cikti);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_istinaf(p_dava bigint, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; t timestamptz := oyun.simdi(); yetkili boolean; r record; n int := 0; juri_bit timestamptz;
begin
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if d.id is null or d.durum <> 'karar' or d.kesin then raise exception 'Bu karar istinafa açık değil.'; end if;
  if t > d.istinaf_son then raise exception 'İstinaf süresi doldu.'; end if;
  if exists (select 1 from oyun.adliye_istinaf where dava_id = d.id) then raise exception 'Bu karara zaten istinaf başvurusu yapıldı.'; end if;
  if d.karar = 'beraat' then
    yetkili := d.davaci = p.id or (d.davaci_parti is not null and exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id
                 where pa.id = d.davaci_parti and (pa.gb = p.id or s.user_id = p.id)));
  else
    yetkili := d.davali = p.id or oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,p.id) or (d.davali_parti is not null and exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id
                 where pa.id = d.davali_parti and (pa.gb = p.id or s.user_id = p.id)));
  end if;
  if not yetkili then raise exception 'İstinafa yalnız kararı kaybeden taraf başvurabilir.'; end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 1500 then raise exception 'İstinaf gerekçesi 20–1500 karakter olmalı.'; end if;
  juri_bit := t + make_interval(hours => (select juri_saat from oyun.mahkeme_ayar));
  insert into oyun.adliye_istinaf(dava_id, basvuran, gerekce, bas, bit) values (d.id, p.id, trim(p_gerekce), t, juri_bit);
  -- Kura: davayla ilgisi olmayan partilerin aktif vekilleri; yetmezse son 7 günde görülen tarafsız oyuncular
  for r in
    select x.id from (
      select pr.id, 0 o, random() rnd from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
       where m.tur = 'mv' and m.bit is null and not pr.yasakli
      union all
      select pr.id, 1, random() from oyun.profiller pr where not pr.yasakli and pr.son_gorulme > t - interval '7 days') x
    join oyun.profiller q on q.id = x.id
    where x.id is distinct from d.davaci and x.id is distinct from d.davali and not oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,x.id) and not oyun.mahkeme_uyesi_mi(x.id) and not exists(select 1 from oyun.adliye_ek_taraf et where et.dava_id=d.id and et.user_id=x.id)
      and not exists (select 1 from oyun.makamlar cbm where cbm.user_id = x.id and cbm.tur = 'cb' and cbm.bit is null)
      and (q.parti_id is null or (q.parti_id is distinct from d.davaci_parti and q.parti_id is distinct from d.davali_parti
           and q.parti_id is distinct from (select parti_id from oyun.profiller where id = d.davaci)
           and q.parti_id is distinct from (select parti_id from oyun.profiller where id = d.davali)))
    group by x.id order by min(x.o), min(x.rnd) limit 3
  loop
    insert into oyun.adliye_juri(dava_id, user_id) values (d.id, r.id) on conflict do nothing;
    perform oyun.bildir(r.id, format('Kura ile Adliye #%s istinaf jürisine seçildin. %s saat içinde kararı onayla ya da boz.', d.id,
                                     (select juri_saat from oyun.mahkeme_ayar)), t);
    n := n + 1;
  end loop;
  if n = 0 then
    delete from oyun.adliye_istinaf where dava_id = d.id;
    raise exception 'Şu anda tarafsız jüri oluşturulamadı; daha sonra tekrar dene.';
  end if;
  update oyun.adliye_davalar set istinaf_son = juri_bit where id = d.id;
  perform oyun.olay('adliye', format('Adliye #%s kararı istinafa taşındı; %s kişilik jüri kurayla belirlendi.', d.id, n), null, null, t);
  return jsonb_build_object('tamam', true, 'juri', n);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_dava_ek(p_dava bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; i oyun.adliye_istinaf; heyet uuid[];
begin
  select * into d from oyun.adliye_davalar where id = p_dava;
  if d.id is null then raise exception 'Dava bulunamadı.'; end if;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  heyet := oyun.dava_heyeti(d);
  return jsonb_build_object(
    'kesin', d.kesin, 'karar_son', d.karar_son, 'istinaf_son', d.istinaf_son, 'harc', d.harc, 'harc_durum', d.harc_durum, 'ilk_karar', d.ilk_karar,
    'heyet_sayi', cardinality(heyet), 'gerekli', oyun.cogunluk(cardinality(heyet)),
    'oy_sayi', (select count(*) from oyun.adliye_karar_oy o where o.dava_id = d.id and o.uye = any(heyet)),
    'oyum', (select jsonb_build_object('karar', o.karar, 'tazminat_tutar',o.tazminat_tutar,'gerekce', o.gerekce) from oyun.adliye_karar_oy o where o.dava_id = d.id and o.uye = p.id),
    'oy_verebilirim', d.durum = 'acik' and p.id = any(heyet),
    -- oylar karar çıkana kadar gizli; sonra herkes görür (karşı oy dahil)
    'oylar', case when d.durum = 'karar' then (select jsonb_agg(jsonb_build_object('uye', oyun.kad(o.uye), 'karar', o.karar, 'tazminat_tutar',o.tazminat_tutar,'gerekce', o.gerekce) order by o.zaman)
               from oyun.adliye_karar_oy o where o.dava_id = d.id) end,
    'istinaf', case when i.dava_id is not null then jsonb_build_object('basvuran', oyun.kad(i.basvuran), 'gerekce', i.gerekce, 'bas', i.bas, 'bit', i.bit, 'durum', i.durum,
        'onay', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id and j.oy = 'onay'),
        'boz', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id and j.oy = 'boz'),
        'juri_sayi', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id),
        'juri', case when i.durum <> 'acik' then (select jsonb_agg(jsonb_build_object('kad', oyun.kad(j.user_id), 'oy', j.oy, 'gerekce', j.gerekce)) from oyun.adliye_juri j where j.dava_id = d.id) end,
        'juri_miyim', exists (select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = p.id),
        'juri_oyum', (select j.oy from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = p.id)) end,
    'istinaf_hakkim', d.durum = 'karar' and not d.kesin and i.dava_id is null and oyun.simdi() < d.istinaf_son and (
        (d.karar = 'beraat' and (d.davaci = p.id or exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id where pa.id = d.davaci_parti and (pa.gb = p.id or s.user_id = p.id))))
     or (d.karar not in ('beraat','dusme') and (d.davali = p.id or oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,p.id) or exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id where pa.id = d.davali_parti and (pa.gb = p.id or s.user_id = p.id))))));
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_beyan_ver(p_dava bigint, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; rol text;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava beyana acik degil.'; end if;
 if char_length(trim(coalesce(p_metin,''))) not between 10 and 2500 then raise exception 'Beyan 10-2500 karakter olmali.'; end if;
 if d.davali=p.id then rol:='davali';
 elsif oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,p.id) then rol:='davali';
 elsif d.davaci=p.id then rol:='davaci';
 elsif exists(select 1 from oyun.adliye_ek_taraf e where e.dava_id=d.id and e.user_id=p.id) then rol:='ilgili';
 elsif (d.davali_parti is not null or d.davaci_parti is not null) and exists(
  select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id
  where pa.id in (d.davali_parti,d.davaci_parti) and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))) then rol:='sozcu';
 else raise exception 'Bu davada beyan yetkiniz yok.'; end if;
 if exists(select 1 from oyun.adliye_beyan where dava_id=d.id and yazar=p.id and zaman>oyun.simdi()-interval '30 seconds') then raise exception 'Yeni beyan icin 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_beyan(dava_id,yazar,rol,metin,zaman) values(d.id,p.id,rol,trim(p_metin),oyun.simdi());
 return jsonb_build_object('tamam',true,'tip','olgu_beyani');
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim();
begin
 return jsonb_build_object(
 'ben',p.kad,'parti_id',p.parti_id,
 'cb_miyim',exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null),
 'hakim',(select oyun.kad(hakim) from oyun.adliye_makam where id=1),
 'hakim_miyim',exists(select 1 from oyun.adliye_makam where id=1 and hakim=p.id),
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',pa.id,'ad',pa.ad,'kisa',pa.kisa,'gb',oyun.kad(pa.gb),'sozcu',oyun.kad(s.user_id),
 'gb_miyim',pa.gb=p.id,'sozcu_muyum',s.user_id=p.id) order by pa.ad)
 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where not pa.kapali),'[]'::jsonb),
 'davalar',coalesce((select jsonb_agg(jsonb_build_object(
 'id',d.id,'davaci',oyun.kad(d.davaci),'davaci_parti',dp.ad,'davali',oyun.kad(d.davali),'davali_parti',hp.ad,'davali_kurum_tur',d.davali_kurum_tur,'davali_kurum_id',d.davali_kurum_id,'davali_kurum_ad',d.davali_kurum_ad,
 'tur',d.tur,'iddia',d.iddia,'delil',d.delil,'acilis',d.acilis,'savunma_son',d.savunma_son,
 'savunma_geldi',d.savunma_geldi,'durum',d.durum,'hakim',oyun.kad(d.hakim),
 'karar',d.karar,'tazminat_talep',d.tazminat_talep,'tazminat_tutar',d.tazminat_tutar,'tazminat_odenen',d.tazminat_odenen,'gerekce',d.gerekce,'karar_at',d.karar_at,'ceza_bitis',d.ceza_bitis,
 'af_at',d.af_at,'af_veren',oyun.kad(d.af_veren),'af_gerekce',d.af_gerekce,
 'davalimiyim',(coalesce(d.davali=p.id,false) or oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,p.id)),'davacimiyim',d.davaci=p.id,'temsil_iznim',exists(select 1 from oyun.adliye_temsil a where a.dava_id=d.id and a.yetki_veren=p.id and a.aktif),
 'sozcu_savunabilir',(
  (d.davali_parti is not null and exists(select 1 from oyun.parti_sozcu s join oyun.profiller pr on pr.id=p.id and pr.parti_id=s.parti_id where s.parti_id=d.davali_parti and s.user_id=p.id))
  or (d.davali is not null and exists(select 1 from oyun.adliye_temsil t join oyun.parti_sozcu s on s.user_id=p.id join oyun.profiller pr on pr.id=d.davali and pr.parti_id=s.parti_id where t.dava_id=d.id and t.aktif and t.yetki_veren=d.davali))
 )
 ) order by d.id desc)
 from (select * from oyun.adliye_davalar order by id desc limit 100) d
 left join oyun.partiler dp on dp.id=d.davaci_parti
 left join oyun.partiler hp on hp.id=d.davali_parti),'[]'::jsonb),
 'aflar',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'cb',oyun.kad(a.cb),'tur',a.tur,'dava_id',a.dava_id,'gerekce',a.gerekce,'affedilen',a.affedilen,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_aflar order by id desc limit 20) a),'[]'::jsonb),
 'atamalar',coalesce((select jsonb_agg(jsonb_build_object('yapan',oyun.kad(a.yapan),'eski',oyun.kad(a.eski),'yeni',oyun.kad(a.yeni),'gerekce',a.gerekce,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_atama_kayit order by id desc limit 15) a),'[]'::jsonb)
 );
end $function$
;


-- Kurumun adını açık dava listesinde göstermek için son RPC yaması.
CREATE OR REPLACE FUNCTION public.adliye_durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim();
begin
 return jsonb_build_object(
 'ben',p.kad,'parti_id',p.parti_id,
 'cb_miyim',exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null),
 'hakim',(select oyun.kad(hakim) from oyun.adliye_makam where id=1),
 'hakim_miyim',exists(select 1 from oyun.adliye_makam where id=1 and hakim=p.id),
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',pa.id,'ad',pa.ad,'kisa',pa.kisa,'gb',oyun.kad(pa.gb),'sozcu',oyun.kad(s.user_id),
 'gb_miyim',pa.gb=p.id,'sozcu_muyum',s.user_id=p.id) order by pa.ad)
 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where not pa.kapali),'[]'::jsonb),
 'davalar',coalesce((select jsonb_agg(jsonb_build_object(
 'id',d.id,'davaci',oyun.kad(d.davaci),'davaci_parti',dp.ad,'davali',coalesce(oyun.kad(d.davali),d.davali_kurum_ad),'davali_parti',hp.ad,'davali_kurum_tur',d.davali_kurum_tur,'davali_kurum_id',d.davali_kurum_id,'davali_kurum_ad',d.davali_kurum_ad,
 'tur',d.tur,'iddia',d.iddia,'delil',d.delil,'acilis',d.acilis,'savunma_son',d.savunma_son,
 'savunma_geldi',d.savunma_geldi,'durum',d.durum,'hakim',oyun.kad(d.hakim),
 'karar',d.karar,'tazminat_talep',d.tazminat_talep,'tazminat_tutar',d.tazminat_tutar,'tazminat_odenen',d.tazminat_odenen,'gerekce',d.gerekce,'karar_at',d.karar_at,'ceza_bitis',d.ceza_bitis,
 'af_at',d.af_at,'af_veren',oyun.kad(d.af_veren),'af_gerekce',d.af_gerekce,
 'davalimiyim',(coalesce(d.davali=p.id,false) or oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,p.id)),'davacimiyim',d.davaci=p.id,'temsil_iznim',exists(select 1 from oyun.adliye_temsil a where a.dava_id=d.id and a.yetki_veren=p.id and a.aktif),
 'sozcu_savunabilir',(
  (d.davali_parti is not null and exists(select 1 from oyun.parti_sozcu s join oyun.profiller pr on pr.id=p.id and pr.parti_id=s.parti_id where s.parti_id=d.davali_parti and s.user_id=p.id))
  or (d.davali is not null and exists(select 1 from oyun.adliye_temsil t join oyun.parti_sozcu s on s.user_id=p.id join oyun.profiller pr on pr.id=d.davali and pr.parti_id=s.parti_id where t.dava_id=d.id and t.aktif and t.yetki_veren=d.davali))
 )
 ) order by d.id desc)
 from (select * from oyun.adliye_davalar order by id desc limit 100) d
 left join oyun.partiler dp on dp.id=d.davaci_parti
 left join oyun.partiler hp on hp.id=d.davali_parti),'[]'::jsonb),
 'aflar',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'cb',oyun.kad(a.cb),'tur',a.tur,'dava_id',a.dava_id,'gerekce',a.gerekce,'affedilen',a.affedilen,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_aflar order by id desc limit 20) a),'[]'::jsonb),
 'atamalar',coalesce((select jsonb_agg(jsonb_build_object('yapan',oyun.kad(a.yapan),'eski',oyun.kad(a.eski),'yeni',oyun.kad(a.yeni),'gerekce',a.gerekce,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_atama_kayit order by id desc limit 15) a),'[]'::jsonb)
 );
end $function$
