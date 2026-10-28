-- Seçim Online: Avukat tutmak isteğe bağlı. Mevcut vekâletler, dosyalar,
-- hukuk isleri, harclar ve kararlar korunur; yalnız mecburi katılım kaldırılır.
CREATE OR REPLACE FUNCTION public.adliye_dava_ac(p_hedef_tur text, p_hedef text, p_tur text, p_iddia text, p_delil text DEFAULT ''::text, p_davaci_parti bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; hedef_parti bigint; t timestamptz:=oyun.simdi(); yeni bigint; h numeric:=(select harc from oyun.mahkeme_ayar);
 sure int:=coalesce((select avukat_savunma_saat from oyun.ayarlar where id=1),24); v_eng text;
begin
 if p_tur not in('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger') then raise exception 'Dava türü geçersiz.'; end if;
 if char_length(trim(coalesce(p_iddia,''))) not between 20 and 1600 then raise exception 'Dava açıklaması 20–1600 karakter olmalı.'; end if;
 if char_length(coalesce(p_delil,''))>1600 then raise exception 'Delil açıklaması 1600 karakteri aşamaz.'; end if;
 if p_hedef_tur='oyuncu' then
  select * into u from oyun.profiller where lower(kad)=lower(trim(p_hedef)) and not yasakli;
  if u.id is null then raise exception 'Davalı oyuncu bulunamadı.'; end if;
  if u.id=p.id then raise exception 'Kendinize dava açamazsınız.'; end if;
  v_eng:=oyun.dokunulmazlik_engel(u.id,case when coalesce(current_setting('oyun.tazminat_davasi',true),'')='1' then 'tazminat' else p_tur end);
  if v_eng is not null then raise exception '%',v_eng; end if;
 elsif p_hedef_tur='parti' then
  begin hedef_parti:=p_hedef::bigint; exception when invalid_text_representation then raise exception 'Geçersiz parti.'; end;
  if not exists(select 1 from oyun.partiler where id=hedef_parti and not kapali) then raise exception 'Parti bulunamadı.'; end if;
 else raise exception 'Davalı türü geçersiz.'; end if;
 if p_davaci_parti is not null and not exists(select 1 from oyun.partiler pa where pa.id=p_davaci_parti and not pa.kapali and pa.gb=p.id)
  then raise exception 'Parti adına davayı yalnız genel başkan açabilir.'; end if;
 if hedef_parti is not null and hedef_parti=p_davaci_parti then raise exception 'Bir parti kendisine dava açamaz.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'Aynı anda en fazla üç açık davan olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Yeni dava açmadan önce 10 dakika bekleyin.'; end if;
 if h>0 then perform oyun.para_islem(p.id,-h,'adliye','Dava harcı',t); end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali,davali_parti,tur,iddia,delil,acilis,savunma_son,karar_son,harc,harc_durum,kesin)
 values(p.id,p_davaci_parti,u.id,hedef_parti,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+make_interval(hours=>sure),
        t+make_interval(hours=>sure)+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)),h,case when h>0 then 'yatirildi' end,false) returning id into yeni;
 if u.id is not null then
  perform oyun.bildir(u.id,format('#%s numaralı davada hakkınızda iddia var. %s saat içinde kendiniz savunma yazabilir veya isteğe bağlı olarak avukat tutabilirsiniz.',yeni,sure),t);
 end if;
 if hedef_parti is not null then
  perform oyun.bildir(pa.gb,format('#%s numaralı davada partiniz davalıdır. Savunma için %s saat içinde genel başkan beyan verebilir veya isteğe bağlı avukat tutabilir (Adliye > dosya).',yeni,sure),t)
   from oyun.partiler pa where pa.id=hedef_parti and pa.gb is not null;
 end if;
 perform oyun.bildir(m.user_id,'Yüksek Mahkeme: #'||yeni||' numaralı yeni dava dosyası açıldı.',t)
  from oyun.mahkeme_uye m where m.user_id is not null and m.user_id<>p.id and m.user_id is distinct from u.id;
 return jsonb_build_object('tamam',true,'id',yeni,'harc',h);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_kurum_dava_ac(p_hedef_tur text, p_hedef text, p_tur text, p_iddia text, p_delil text DEFAULT ''::text, p_davaci_parti bigint DEFAULT NULL::bigint, p_tazminat_talep numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); kurum_ad text; t timestamptz:=oyun.simdi(); yeni bigint;
 h numeric:=coalesce((select harc from oyun.mahkeme_ayar),0); sure int:=coalesce((select avukat_savunma_saat from oyun.ayarlar where id=1),24);
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
 if p_davaci_parti is not null and not exists(select 1 from oyun.partiler pa where pa.id=p_davaci_parti and not pa.kapali and pa.gb=p.id)
  then raise exception 'Parti adına davayı yalnız genel başkan açabilir.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'Aynı anda en fazla üç açık davan olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Yeni dava açmadan önce 10 dakika bekleyin.'; end if;
 if h>0 then perform oyun.para_islem(p.id,-h,'adliye','Dava harcı',t); end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali_kurum_tur,davali_kurum_id,davali_kurum_ad,tur,iddia,delil,acilis,savunma_son,karar_son,harc,harc_durum,kesin,tazminat_talep)
 values(p.id,p_davaci_parti,p_hedef_tur,p_hedef,kurum_ad,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+make_interval(hours=>sure),
  t+make_interval(hours=>sure)+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)),
  h,case when h>0 then 'yatirildi' end,false,case when p_tur='tazminat' then p_tazminat_talep end) returning id into yeni;
 perform oyun.bildir(q.id,format('Adliye #%s: %s aleyhine dava açıldı. Kurum yetkilisi %s saat içinde doğrudan savunma yazabilir veya isteğe bağlı avukat tutabilir.',yeni,kurum_ad,sure),t)
  from oyun.profiller q where oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.id) and q.id<>p.id;
 perform oyun.bildir(q.user_id,format('Yüksek Mahkeme: yeni kurum davası #%s',yeni),t)
  from oyun.mahkeme_uye q where q.user_id is not null and q.user_id<>p.id and not oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.user_id);
 return jsonb_build_object('tamam',true,'id',yeni,'harc',h);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_beyan_ver(p_dava bigint, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; v_rol text; n int:=0; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava beyana açık değil.'; end if;
 if oyun.dava_muvekkil_mi(d,'davali',p.id) then v_rol:='davali';
 elsif oyun.dava_muvekkil_mi(d,'davaci',p.id) then v_rol:='davaci';
 elsif exists(select 1 from oyun.adliye_ek_taraf e where e.dava_id=d.id and e.user_id=p.id) then v_rol:='ilgili';
 else
  raise exception 'Bu dosyada taraf veya yetkili kurum/parti temsilcisi değilsin.';
 end if;
 if char_length(trim(coalesce(p_metin,''))) not between 10 and 2500 then raise exception 'Beyan 10-2500 karakter olmalı.'; end if;
 if v_rol in ('davali','davaci') then
  select count(*) into n from oyun.adliye_beyan b where b.dava_id=d.id and b.yazar=p.id and b.rol=v_rol;
  if n>=2 then raise exception 'Taraf beyan hakkını kullandın (savunma ve son söz, en fazla 2). Avukat tutmak isteğe bağlıdır.'; end if;
 end if;
 if exists(select 1 from oyun.adliye_beyan where dava_id=d.id and yazar=p.id and zaman>t-interval '30 seconds') then raise exception 'Yeni beyan için 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_beyan(dava_id,yazar,rol,metin,zaman) values(d.id,p.id,v_rol,trim(p_metin),t);
 if v_rol='davali' then update oyun.adliye_davalar set savunma_geldi=true where id=d.id; end if;
 return jsonb_build_object('tamam',true,
   'tip',case v_rol when 'davali' then 'kisisel_savunma' when 'davaci' then 'kisisel_beyan' else 'ilgili_beyani' end,
   'kalan',case when v_rol in ('davali','davaci') then 1-n end);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_secim_itiraz_ac(p_secim bigint, p_parti bigint, p_gerekce text, p_deliller text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); s oyun.secimler; t timestamptz:=oyun.simdi(); yeni_id bigint;
begin
 if not exists(select 1 from oyun.partiler pa where pa.id=p_parti and not pa.kapali and pa.gb=p.id)
 then raise exception 'İtirazı yalnız parti genel başkanı veya usulüne uygun yetkilendirilmiş vekili yapabilir.'; end if;
 select * into s from oyun.secimler where id=p_secim;
 if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
 if s.sonuc is null or s.sonuc_at is null or t<s.sonuc_at then raise exception 'Yalnız sonuçlanmış seçimlere itiraz edilebilir.'; end if;
 if t>s.sonuc_at+interval '48 hours' then raise exception '48 saatlik itiraz süresi doldu.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 30 and 1600 then raise exception 'İtiraz gerekçesi 30-1600 karakter olmalı.'; end if;
 if char_length(coalesce(p_deliller,''))>3000 then raise exception 'Deliller en fazla 3000 karakter olabilir.'; end if;
 insert into oyun.adliye_secim_itirazlari(secim_id,parti_id,yapan,gerekce,deliller,zaman)
 values(s.id,p_parti,p.id,trim(p_gerekce),trim(coalesce(p_deliller,'')),t) returning id into yeni_id;
 return jsonb_build_object('tamam',true,'id',yeni_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.parti_kapatma_savunma(p_dava bigint, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); d oyun.pkd_dava; pa oyun.partiler; m text;
begin
 select * into d from oyun.pkd_dava where id=p_dava for update;
 if d.id is null or d.durum<>'savunma' or t>=d.savunma_son then raise exception 'Bu dava savunma aşamasında değil.'; end if;
 select * into pa from oyun.partiler where id=d.parti_id;
 if p.id is distinct from pa.gb and p.id is distinct from pa.gb_vekil then raise exception 'Savunmayı davalı partinin genel başkanı veya yetkili başkan vekili verebilir; avukat isteğe bağlıdır.'; end if;
 m:=oyun.metin_temizle(p_metin,3000);
 if length(m)<50 then raise exception 'Savunma en az 50 karakter olmalı.'; end if;
 update oyun.pkd_dava set savunma=m,savunan=p.id,savunma_at=t where id=d.id;
 perform oyun.pkd_yargilamaya_al(d.id,t);
 return public.parti_kapatma_davalari(null);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_istinaf(p_dava bigint, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; t timestamptz:=oyun.simdi(); kayb text; kisisel boolean; vekil boolean:=oyun.vekil_islem_mi(); n int;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'karar' or d.kesin or d.karar='dusme' then raise exception 'Bu karar istinafa açık değil.'; end if;
 if t>d.istinaf_son then raise exception 'İstinaf süresi doldu.'; end if;
 if exists(select 1 from oyun.adliye_istinaf where dava_id=d.id) then raise exception 'Bu karara zaten istinaf başvurusu yapıldı.'; end if;
 kayb:=case when d.karar='beraat' then 'davaci' else 'davali' end;
 if not oyun.dava_muvekkil_mi(d,kayb,p.id) then raise exception 'İstinafa yalnız kararı kaybeden taraf ya da avukatı başvurabilir.'; end if;
 kisisel:=(kayb='davali' and d.davali=p.id) or (kayb='davaci' and d.davaci=p.id and d.davaci_parti is null);
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 1500 then raise exception 'İstinaf gerekçesi 20–1500 karakter olmalı.'; end if;
 insert into oyun.adliye_istinaf(dava_id,basvuran,gerekce,bas) values(d.id,p.id,trim(p_gerekce),t);
 n:=oyun.adliye_juri_kur(d.id,t);
 if n=0 then
  -- exception tüm işlemi geri alır (başvuru kaydı da silinir)
  raise exception 'Şu anda tarafsız jüri oluşturulamadı; daha sonra tekrar dene.';
 end if;
 update oyun.adliye_davalar set istinaf_son=(select i.bit from oyun.adliye_istinaf i where i.dava_id=d.id) where id=d.id;
 perform oyun.olay('adliye',format('Adliye #%s kararı istinafa taşındı; %s asıl ve %s yedek jüri üyesi kurayla belirlendi.',d.id,n,
   (select count(*) from oyun.adliye_juri_yedek y where y.dava_id=d.id)),null,null,t);
 return jsonb_build_object('tamam',true,'juri',n,'kisisel',kisisel and not vekil);
end $function$
;
CREATE OR REPLACE FUNCTION oyun.avukat_zorunlu_mu(p_acilis timestamptz)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
  SELECT false
$function$;
