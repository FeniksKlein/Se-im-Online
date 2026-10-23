-- 131 · Mahkemede avukat zorunluluğu + Parti Sözcüsü resmî açıklama makamı (23.10.2026)
-- * Dava açma, savunma/beyan, istinaf, seçim itirazı ve parti kapatma savunması yalnız avukat eliyle yapılır.
--   Oyuncu, parti (genel başkan), kurum/dernek/şirket yetkilisi müvekkil olur; avukat onun adına işlem yapar.
-- * Dava açmak isteyen "hukuki iş" talebi oluşturur, avukatlar teklif verir, ücret emanete alınır,
--   avukat dilekçeyi mahkemeye sununca ücret avukata geçer. Sunulmadan iptal/çekilmede iade edilir.
-- * İlgili taraf (yargıcın çağırdığı tanık) kendi beyanını verebilir; bu savunma değildir.
-- * Parti sözcüsü mahkemede temsil yapamaz; partisi adına resmî açıklama yapar (akışa da düşer).
-- Yalnız ekleme / create or replace. Mevcut dava ve para kayıtları değişmez; geçişten önce açılmış
-- davaların istinafı eski usulle (sözcü hariç) sürer.

-- ---------------------------------------------------------------- 1) Ayar, yardımcılar, tablolar
alter table oyun.ayarlar add column if not exists avukat_zorunlu_bas timestamptz;
alter table oyun.ayarlar add column if not exists avukat_savunma_saat int not null default 24;
update oyun.ayarlar set avukat_zorunlu_bas=now() where id=1 and avukat_zorunlu_bas is null;

create or replace function oyun.avukat_zorunlu_mu(p_acilis timestamptz) returns boolean language sql stable set search_path='' as $f$
 select p_acilis>=coalesce((select avukat_zorunlu_bas from oyun.ayarlar where id=1),'-infinity'::timestamptz)
$f$;

create or replace function oyun.vekil_islem_mi() returns boolean language sql stable set search_path='' as $f$
 select coalesce(current_setting('oyun.vekil_islem',true),'')<>''
$f$;

-- Avukat, müvekkilin adına mahkeme işlemi yapar: istek bu işlem boyunca müvekkil kimliğiyle çalışır.
create or replace function oyun.vekil_basla(p_muvekkil uuid,p_avukat uuid) returns text language plpgsql set search_path='' as $f$
declare onceki text:=coalesce(current_setting('request.jwt.claim.sub',true),'');
begin
 perform set_config('request.jwt.claim.sub',p_muvekkil::text,true);
 perform set_config('oyun.vekil_islem',p_avukat::text,true);
 return onceki;
end $f$;

create or replace function oyun.vekil_bitir(p_onceki text) returns void language plpgsql set search_path='' as $f$
begin
 perform set_config('request.jwt.claim.sub',coalesce(p_onceki,''),true);
 perform set_config('oyun.vekil_islem','',true);
end $f$;

-- Dosyanın bir tarafı adına avukat tutabilecek kişi: kişi, partinin genel başkanı ya da kurum yetkilisi
create or replace function oyun.dava_muvekkil_mi(d oyun.adliye_davalar,p_taraf text,u uuid) returns boolean language sql stable set search_path='' as $f$
 select case when u is null then false
  when p_taraf='davaci' then (d.davaci=u or exists(select 1 from oyun.partiler pa where pa.id=d.davaci_parti and pa.gb=u))
  when p_taraf='davali' then (d.davali=u or exists(select 1 from oyun.partiler pa where pa.id=d.davali_parti and pa.gb=u)
     or (d.davali_kurum_tur is not null and oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,u)))
  else false end
$f$;

create table if not exists oyun.hukuk_isleri(
 id bigserial primary key,
 tur text not null check(tur in ('dava','secim_itiraz','pkd_savunma')),
 muvekkil uuid not null references oyun.profiller(id),
 parti_id bigint references oyun.partiler(id),
 hedef_tur text,
 hedef text,
 hedef_ad text,
 dava_tur text,
 tazminat_talep numeric,
 secim_id bigint,
 pkd_id bigint,
 metin text not null,
 delil text not null default '',
 durum text not null default 'avukat_bekliyor' check(durum in ('avukat_bekliyor','vekil_atandi','sunuldu','iptal')),
 avukat_id uuid references oyun.profiller(id),
 ucret numeric not null default 0,
 prim numeric not null default 0,
 emanet numeric not null default 0 check(emanet>=0),
 dava_id bigint references oyun.adliye_davalar(id),
 olusturma timestamptz not null default now(),
 atama_at timestamptz,
 sunum_at timestamptz,
 iptal_at timestamptz
);
create index if not exists hukuk_isleri_durum on oyun.hukuk_isleri(durum,id desc);
create index if not exists hukuk_isleri_muvekkil on oyun.hukuk_isleri(muvekkil,id desc);
create table if not exists oyun.hukuk_is_teklifleri(
 id bigserial primary key,
 is_id bigint not null references oyun.hukuk_isleri(id),
 avukat_id uuid not null references oyun.profiller(id),
 tutar numeric not null check(tutar between 0 and 1000000000000),
 prim numeric not null default 0 check(prim between 0 and 25),
 aciklama text not null default '',
 durum text not null default 'bekliyor' check(durum in ('bekliyor','kabul','ret','iptal')),
 zaman timestamptz not null default now()
);
create unique index if not exists hukuk_is_tek_bekleyen on oyun.hukuk_is_teklifleri(is_id,avukat_id) where durum='bekliyor';
create table if not exists oyun.parti_aciklamalar(
 id bigserial primary key,
 parti_id bigint not null references oyun.partiler(id),
 yazar uuid not null references oyun.profiller(id),
 rol text not null check(rol in ('sozcu','gb')),
 baslik text not null check(char_length(baslik) between 3 and 120),
 metin text not null check(char_length(metin) between 10 and 2000),
 zaman timestamptz not null default now(),
 silindi boolean not null default false
);
create index if not exists parti_aciklamalar_parti on oyun.parti_aciklamalar(parti_id,id desc) where not silindi;
do $guard$
declare t text;
begin
 foreach t in array array['hukuk_isleri','hukuk_is_teklifleri','parti_aciklamalar'] loop
  execute format('alter table oyun.%I enable row level security',t);
  execute format('revoke all on oyun.%I from public, anon, authenticated',t);
 end loop;
end $guard$;

-- ---------------------------------------------------------------- 2) Mahkeme kapıları
create or replace function public.adliye_dava_ac(p_hedef_tur text,p_hedef text,p_tur text,p_iddia text,p_delil text default '',p_davaci_parti bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; hedef_parti bigint; t timestamptz:=oyun.simdi(); yeni bigint; h numeric:=(select harc from oyun.mahkeme_ayar);
 sure int:=coalesce((select avukat_savunma_saat from oyun.ayarlar where id=1),24);
begin
 if not oyun.vekil_islem_mi() then raise exception 'Dava açmak için avukat tutmalısın: Adliye > Dava aç ile hukuki iş talebi oluştur, avukatın davayı senin adına mahkemeye sunar.'; end if;
 if p_tur not in('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger') then raise exception 'Dava türü geçersiz.'; end if;
 if char_length(trim(coalesce(p_iddia,''))) not between 20 and 1600 then raise exception 'Dava açıklaması 20–1600 karakter olmalı.'; end if;
 if char_length(coalesce(p_delil,''))>1600 then raise exception 'Delil açıklaması 1600 karakteri aşamaz.'; end if;
 if p_hedef_tur='oyuncu' then
  select * into u from oyun.profiller where lower(kad)=lower(trim(p_hedef)) and not yasakli;
  if u.id is null then raise exception 'Davalı oyuncu bulunamadı.'; end if;
  if u.id=p.id then raise exception 'Kendinize dava açamazsınız.'; end if;
 elsif p_hedef_tur='parti' then
  begin hedef_parti:=p_hedef::bigint; exception when invalid_text_representation then raise exception 'Geçersiz parti.'; end;
  if not exists(select 1 from oyun.partiler where id=hedef_parti and not kapali) then raise exception 'Parti bulunamadı.'; end if;
 else raise exception 'Davalı türü geçersiz.'; end if;
 if p_davaci_parti is not null and not exists(select 1 from oyun.partiler pa where pa.id=p_davaci_parti and not pa.kapali and pa.gb=p.id)
  then raise exception 'Parti adına davayı yalnız genel başkanın tuttuğu avukat açabilir.'; end if;
 if hedef_parti is not null and hedef_parti=p_davaci_parti then raise exception 'Bir parti kendisine dava açamaz.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'Müvekkilin en fazla üç açık davası olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Müvekkil adına yeni dava için 10 dakika bekleyin.'; end if;
 if h>0 then perform oyun.para_islem(p.id,-h,'adliye','Dava harcı',t); end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali,davali_parti,tur,iddia,delil,acilis,savunma_son,karar_son,harc,harc_durum,kesin)
 values(p.id,p_davaci_parti,u.id,hedef_parti,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+make_interval(hours=>sure),
        t+make_interval(hours=>sure)+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)),h,case when h>0 then 'yatirildi' end,false) returning id into yeni;
 if u.id is not null then
  perform oyun.bildir(u.id,format('#%s numaralı davada hakkınızda iddia var. Savunmanızı %s saat içinde avukatınız sunabilir: dosyadaki teklifleri inceleyin ya da Baro''dan adli yardım isteyin.',yeni,sure),t);
 end if;
 if hedef_parti is not null then
  perform oyun.bildir(pa.gb,format('#%s numaralı davada partiniz davalıdır. Savunma için %s saat içinde parti adına avukat tutun (Adliye > dosya).',yeni,sure),t)
   from oyun.partiler pa where pa.id=hedef_parti and pa.gb is not null;
 end if;
 perform oyun.bildir(m.user_id,'Yüksek Mahkeme: #'||yeni||' numaralı yeni dava dosyası açıldı.',t)
  from oyun.mahkeme_uye m where m.user_id is not null and m.user_id<>p.id and m.user_id is distinct from u.id;
 return jsonb_build_object('tamam',true,'id',yeni,'harc',h);
end $f$;

create or replace function public.adliye_kurum_dava_ac(p_hedef_tur text,p_hedef text,p_tur text,p_iddia text,p_delil text default '',p_davaci_parti bigint default null,p_tazminat_talep numeric default null)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); kurum_ad text; t timestamptz:=oyun.simdi(); yeni bigint;
 h numeric:=coalesce((select harc from oyun.mahkeme_ayar),0); sure int:=coalesce((select avukat_savunma_saat from oyun.ayarlar where id=1),24);
begin
 if not oyun.vekil_islem_mi() then raise exception 'Dava açmak için avukat tutmalısın: Adliye > Dava aç ile hukuki iş talebi oluştur, avukatın davayı senin adına mahkemeye sunar.'; end if;
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
  then raise exception 'Parti adına davayı yalnız genel başkanın tuttuğu avukat açabilir.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'Müvekkilin en fazla üç açık davası olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Müvekkil adına yeni dava için 10 dakika bekleyin.'; end if;
 if h>0 then perform oyun.para_islem(p.id,-h,'adliye','Dava harcı',t); end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali_kurum_tur,davali_kurum_id,davali_kurum_ad,tur,iddia,delil,acilis,savunma_son,karar_son,harc,harc_durum,kesin,tazminat_talep)
 values(p.id,p_davaci_parti,p_hedef_tur,p_hedef,kurum_ad,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+make_interval(hours=>sure),
  t+make_interval(hours=>sure)+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)),
  h,case when h>0 then 'yatirildi' end,false,case when p_tur='tazminat' then p_tazminat_talep end) returning id into yeni;
 perform oyun.bildir(q.id,format('Adliye #%s: %s aleyhine dava açıldı. Kurum adına %s saat içinde avukat tutun; savunmayı avukat sunar.',yeni,kurum_ad,sure),t)
  from oyun.profiller q where oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.id) and q.id<>p.id;
 perform oyun.bildir(q.user_id,format('Yüksek Mahkeme: yeni kurum davası #%s',yeni),t)
  from oyun.mahkeme_uye q where q.user_id is not null and q.user_id<>p.id and not oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.user_id);
 return jsonb_build_object('tamam',true,'id',yeni,'harc',h);
end $f$;

-- Taraflar ve sözcüler mahkemeye doğrudan yazamaz; yalnız yargıcın çağırdığı ilgili taraf (tanık) beyan verir.
create or replace function public.adliye_beyan_ver(p_dava bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava beyana açık değil.'; end if;
 if not exists(select 1 from oyun.adliye_ek_taraf e where e.dava_id=d.id and e.user_id=p.id) then
  raise exception 'Mahkemeye savunma ve beyanı yalnız dosyadaki avukatın sunabilir. Avukat tutmak için dosyadaki teklifleri incele veya Baro''dan adli yardım iste.';
 end if;
 if char_length(trim(coalesce(p_metin,''))) not between 10 and 2500 then raise exception 'Beyan 10-2500 karakter olmalı.'; end if;
 if exists(select 1 from oyun.adliye_beyan where dava_id=d.id and yazar=p.id and zaman>oyun.simdi()-interval '30 seconds') then raise exception 'Yeni beyan için 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_beyan(dava_id,yazar,rol,metin,zaman) values(d.id,p.id,'ilgili',trim(p_metin),oyun.simdi());
 return jsonb_build_object('tamam',true,'tip','ilgili_beyani');
end $f$;

create or replace function public.adliye_temsil_yetkisi(p_dava bigint,p_izin boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
begin
 perform oyun.profilim();
 raise exception 'Parti sözcüleri artık mahkemede temsil yapamaz. Davanda seni yalnız tuttuğun avukat temsil eder.';
end $f$;

create or replace function public.adliye_secim_itiraz_ac(p_secim bigint,p_parti bigint,p_gerekce text,p_deliller text default '') returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); s oyun.secimler; t timestamptz:=oyun.simdi(); yeni_id bigint;
begin
 if not oyun.vekil_islem_mi() then raise exception 'Seçim itirazını partinin avukatı yapar: Adliye > Seçim sonuçlarına itiraz ile hukuki iş talebi oluştur.'; end if;
 if not exists(select 1 from oyun.partiler pa where pa.id=p_parti and not pa.kapali and pa.gb=p.id)
 then raise exception 'İtirazı yalnız genel başkanın tuttuğu avukat yapabilir.'; end if;
 select * into s from oyun.secimler where id=p_secim;
 if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
 if s.sonuc is null or s.sonuc_at is null or t<s.sonuc_at then raise exception 'Yalnız sonuçlanmış seçimlere itiraz edilebilir.'; end if;
 if t>s.sonuc_at+interval '48 hours' then raise exception '48 saatlik itiraz süresi doldu.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 30 and 1600 then raise exception 'İtiraz gerekçesi 30-1600 karakter olmalı.'; end if;
 if char_length(coalesce(p_deliller,''))>3000 then raise exception 'Deliller en fazla 3000 karakter olabilir.'; end if;
 insert into oyun.adliye_secim_itirazlari(secim_id,parti_id,yapan,gerekce,deliller,zaman)
 values(s.id,p_parti,p.id,trim(p_gerekce),trim(coalesce(p_deliller,'')),t) returning id into yeni_id;
 return jsonb_build_object('tamam',true,'id',yeni_id);
end $f$;

create or replace function public.parti_kapatma_savunma(p_dava bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); d oyun.pkd_dava; pa oyun.partiler; m text;
begin
 if not oyun.vekil_islem_mi() then raise exception 'Parti kapatma davasında savunmayı partinin avukatı sunar: genel başkan hukuki iş talebi oluşturmalı.'; end if;
 select * into d from oyun.pkd_dava where id=p_dava for update;
 if d.id is null or d.durum<>'savunma' or t>=d.savunma_son then raise exception 'Bu dava savunma aşamasında değil.'; end if;
 select * into pa from oyun.partiler where id=d.parti_id;
 if p.id is distinct from pa.gb and p.id is distinct from pa.gb_vekil then raise exception 'Savunmayı yalnız davalı partinin genel başkanının tuttuğu avukat verebilir.'; end if;
 m:=oyun.metin_temizle(p_metin,3000);
 if length(m)<50 then raise exception 'Savunma en az 50 karakter olmalı.'; end if;
 update oyun.pkd_dava set savunma=m,savunan=p.id,savunma_at=t where id=d.id;
 perform oyun.pkd_yargilamaya_al(d.id,t);
 return public.parti_kapatma_davalari(null);
end $f$;

create or replace function public.adliye_sozcu_ata(p_parti bigint,p_kad text default null) returns jsonb language plpgsql security definer set search_path='' as $f$
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
  perform oyun.bildir(eski,'Parti sözcülüğü göreviniz sona erdi; artık parti adına resmî açıklama yapamazsınız.',t);
 end if;
 if u.id is not null then
  perform oyun.bildir(u.id,'Genel başkanınız sizi Parti Sözcüsü olarak atadı. Partiniz adına resmî açıklama yapabilirsiniz (Partiler > partiniz > Parti Sözcüsü).',t);
 end if;
 return jsonb_build_object('tamam',true);
end $f$;

-- İstinaf: yeni usul davalarda yalnız kaybeden tarafın avukatı; sözcü hiçbir davada başvuramaz.
do $patch$
declare def text; yeni text;
begin
 select pg_get_functiondef('public.adliye_istinaf(bigint,text)'::regprocedure) into def;
 yeni:=replace(def,'(pa.gb = p.id or s.user_id = p.id)','pa.gb = p.id');
 if position('oyun.vekil_islem_mi()' in yeni)=0 then
  if position('raise exception ''Bu karar istinafa açık değil.''; end if;' in yeni)=0 then raise exception 'adliye_istinaf beklenen ifade bulunamadı'; end if;
  yeni:=replace(yeni,'raise exception ''Bu karar istinafa açık değil.''; end if;',
   'raise exception ''Bu karar istinafa açık değil.''; end if;'||chr(10)||
   '  if oyun.avukat_zorunlu_mu(d.acilis) and not oyun.vekil_islem_mi() then raise exception ''İstinaf başvurusunu kaybeden tarafın avukatı yapar (dava dosyasındaki avukat paneli).''; end if;');
 end if;
 if yeni<>def then execute yeni; end if;
end $patch$;

-- ---------------------------------------------------------------- 3) Avukat–müvekkil (kurum ve parti dahil)
create or replace function public.avukat_teklif_ver(p_dava bigint,p_taraf text,p_tutar numeric,p_prim numeric default 0,p_aciklama text default '') returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; tid bigint; engel text;
begin
 engel:=oyun.avukat_engel(p.id);
 if engel is not null then raise exception '%',engel; end if;
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null or d.durum<>'acik' then raise exception 'Açık dava bulunamadı.'; end if;
 if p_taraf not in ('davaci','davali') or p_tutar is null or p_tutar<0 or p_tutar>1000000000000 then raise exception 'Teklif bilgileri geçersiz.'; end if;
 if p_prim is null or p_prim<0 or p_prim>25 then raise exception 'Başarı primi %%0 ile %%25 arasında olmalı (Avukatlık Kanunu m.164).'; end if;
 if not exists(select 1 from oyun.profiller q where oyun.dava_muvekkil_mi(d,p_taraf,q.id)) then raise exception 'Bu tarafta avukat tutabilecek bir oyuncu yok.'; end if;
 if oyun.dava_muvekkil_mi(d,'davaci',p.id) or oyun.dava_muvekkil_mi(d,'davali',p.id) then raise exception 'Kendi davanızda ya da temsil ettiğiniz kurumun davasında avukatlık yapamazsınız.'; end if;
 if exists(select 1 from oyun.mahkeme_uye where user_id=p.id) then raise exception 'Yargıç avukatlık yapamaz.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=p_dava and avukat_id=p.id and aktif) then raise exception 'Bu davada zaten vekilsiniz.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=p_dava and taraf=p_taraf and aktif) then raise exception 'Bu tarafın aktif avukatı var.'; end if;
 if exists(select 1 from oyun.avukat_teklifleri where dava_id=p_dava and avukat_id=p.id and taraf=p_taraf and durum='bekliyor') then raise exception 'Bu taraf için bekleyen bir teklifin zaten var.'; end if;
 insert into oyun.avukat_teklifleri(dava_id,avukat_id,taraf,tutar,prim_orani,aciklama)
 values(p_dava,p.id,p_taraf,round(p_tutar),p_prim,left(trim(coalesce(p_aciklama,'')),500)) returning id into tid;
 perform oyun.bildir(q.id,format('Adliye #%s için Av. %s teklif verdi: %s ₺, başarı primi %%%s.',p_dava,p.kad,oyun.tl(round(p_tutar)),p_prim),oyun.simdi())
  from oyun.profiller q where oyun.dava_muvekkil_mi(d,p_taraf,q.id);
 return jsonb_build_object('tamam',true,'id',tid);
end $f$;

create or replace function public.avukat_karsi_teklif(p_teklif bigint,p_tutar numeric,p_prim numeric) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t oyun.avukat_teklifleri; d oyun.adliye_davalar;
begin
 select * into t from oyun.avukat_teklifleri where id=p_teklif for update;
 if t.id is null or t.durum<>'bekliyor' then raise exception 'Teklif kapandı.'; end if;
 select * into d from oyun.adliye_davalar where id=t.dava_id;
 if d.durum<>'acik' then raise exception 'Dava kapandı.'; end if;
 if not oyun.dava_muvekkil_mi(d,t.taraf,p.id) then raise exception 'Bu davada müvekkil yetkiniz yok.'; end if;
 if p_tutar is null or p_tutar<0 or p_tutar>1000000000000 then raise exception 'Karşı teklif geçersiz.'; end if;
 if p_prim is null or p_prim<0 or p_prim>25 then raise exception 'Başarı primi %%0 ile %%25 arasında olmalı (Avukatlık Kanunu m.164).'; end if;
 insert into oyun.avukat_pazarlik(teklif_id,muvekkil,tutar,prim) values(t.id,p.id,round(p_tutar),p_prim)
 on conflict(teklif_id) do update set muvekkil=excluded.muvekkil,tutar=excluded.tutar,prim=excluded.prim,durum='bekliyor',zaman=now();
 perform oyun.bildir(t.avukat_id,format('Dava #%s için müvekkil karşı teklif sundu: %s ₺, prim %%%s. Dava dosyasından yanıtla.',d.id,oyun.tl(round(p_tutar)),p_prim),oyun.simdi());
 return jsonb_build_object('tamam',true);
end $f$;

create or replace function public.avukat_teklif_karar(p_teklif bigint,p_kabul boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t oyun.avukat_teklifleri; d oyun.adliye_davalar;
begin
 select * into t from oyun.avukat_teklifleri where id=p_teklif for update;
 if t.id is null or t.durum<>'bekliyor' then raise exception 'Teklif beklemede değil.'; end if;
 select * into d from oyun.adliye_davalar where id=t.dava_id for update;
 if d.durum<>'acik' then raise exception 'Dava kapandı.'; end if;
 if not oyun.dava_muvekkil_mi(d,t.taraf,p.id) then raise exception 'Teklifin müvekkili değilsiniz.'; end if;
 if not p_kabul then update oyun.avukat_teklifleri set durum='ret' where id=t.id; return jsonb_build_object('durum','ret'); end if;
 if not oyun.avukat_mi(t.avukat_id) then raise exception 'Avukat şu anda mesleği icra edemiyor.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and taraf=t.taraf and aktif) then raise exception 'Bu tarafın zaten avukatı var.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and avukat_id=t.avukat_id and aktif) then raise exception 'Aynı avukat karşı tarafı temsil edemez.'; end if;
 if t.tutar>0 then
  perform oyun.para_islem(p.id,-t.tutar,'adliye','Dava #'||d.id||' avukatlık ücreti',oyun.simdi());
  perform oyun.para_islem(t.avukat_id,t.tutar,'adliye','Dava #'||d.id||' avukatlık ücreti',oyun.simdi());
 end if;
 insert into oyun.avukat_vekaletleri(teklif_id,dava_id,avukat_id,muvekkil,taraf,ucret,prim_orani)
 values(t.id,d.id,t.avukat_id,p.id,t.taraf,t.tutar,t.prim_orani);
 update oyun.avukat_teklifleri set durum='kabul',kabul_at=now() where id=t.id;
 update oyun.avukat_teklifleri set durum='iptal' where dava_id=d.id and taraf=t.taraf and id<>t.id and durum='bekliyor';
 perform oyun.bildir(t.avukat_id,format('Dava #%s avukatlık teklifiniz kabul edildi.',d.id),oyun.simdi());
 return jsonb_build_object('durum','kabul');
end $f$;

create or replace function public.avukat_dava_durum(p_dava bigint) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
begin
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null then raise exception 'Dava bulunamadı.'; end if;
 return jsonb_build_object(
  'teklifler',(select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'avukat',oyun.kad(t.avukat_id),'taraf',t.taraf,'tutar',t.tutar,'prim',t.prim_orani,'aciklama',t.aciklama,'durum',t.durum,'benim',t.avukat_id=p.id,
      'cevaplayabilirim',oyun.dava_muvekkil_mi(d,t.taraf,p.id)) order by t.id desc),'[]'::jsonb)
    from oyun.avukat_teklifleri t where t.dava_id=p_dava and (t.avukat_id=p.id or oyun.dava_muvekkil_mi(d,t.taraf,p.id) or t.durum='kabul')),
  'vekaletler',(select coalesce(jsonb_agg(jsonb_build_object('id',v.id,'avukat',oyun.kad(v.avukat_id),'taraf',v.taraf,'muvekkil',oyun.kad(v.muvekkil),'ucret',v.ucret,'aktif',v.aktif,
      'benim',v.avukat_id=p.id or v.muvekkil=p.id,'avukat_miyim',v.avukat_id=p.id) order by v.id desc),'[]'::jsonb)
    from oyun.avukat_vekaletleri v where v.dava_id=p_dava)
 );
end $f$;

create or replace function public.avukat_istinaf(p_dava bigint,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; v oyun.avukat_vekaletleri; tr text; onceki text; r jsonb; engel text;
begin
 engel:=oyun.avukat_engel(p.id);
 if engel is not null then raise exception '%',engel; end if;
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null or d.durum<>'karar' or d.kesin then raise exception 'Bu karar istinafa açık değil.'; end if;
 tr:=case when d.karar='beraat' then 'davaci' else 'davali' end;
 select * into v from oyun.avukat_vekaletleri where dava_id=d.id and taraf=tr and avukat_id=p.id and aktif order by id desc limit 1;
 if v.id is null then raise exception 'Bu dosyada kararı kaybeden tarafın aktif vekili değilsin.'; end if;
 onceki:=oyun.vekil_basla(v.muvekkil,p.id);
 r:=public.adliye_istinaf(p_dava,p_gerekce);
 perform oyun.vekil_bitir(onceki);
 perform oyun.bildir(v.muvekkil,format('Av. %s, Dava #%s kararına senin adına istinaf başvurusu yaptı.',p.kad,d.id),oyun.simdi());
 return r;
end $f$;

-- ---------------------------------------------------------------- 4) Hukuki iş talepleri (dava açma, seçim itirazı, parti kapatma savunması)
create or replace function public.hukuk_is_olustur(p_tur text,p_parti bigint default null,p_hedef_tur text default null,p_hedef text default null,
 p_dava_tur text default null,p_tazminat numeric default null,p_secim bigint default null,p_pkd bigint default null,p_metin text default '',p_delil text default '')
returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); m text:=trim(coalesce(p_metin,'')); dl text:=trim(coalesce(p_delil,'')); had text; u oyun.profiller; s oyun.secimler; k oyun.pkd_dava; pa oyun.partiler; yid bigint; hp bigint;
begin
 if p_tur not in ('dava','secim_itiraz','pkd_savunma') then raise exception 'İş türü geçersiz.'; end if;
 if (select count(*) from oyun.hukuk_isleri where muvekkil=p.id and durum in ('avukat_bekliyor','vekil_atandi'))>=3 then raise exception 'Aynı anda en fazla üç açık hukuki işin olabilir.'; end if;
 if p_parti is not null then
  select * into pa from oyun.partiler where id=p_parti and not kapali;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if pa.gb is distinct from p.id and not (p_tur='pkd_savunma' and coalesce(pa.gb_vekil=p.id,false)) then raise exception 'Parti adına avukatı yalnız genel başkan tutabilir.'; end if;
 end if;
 if p_tur='dava' then
  if p_dava_tur not in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger','tazminat') then raise exception 'Dava türü geçersiz.'; end if;
  if char_length(m) not between 20 and 1600 then raise exception 'İddia 20–1600 karakter olmalı.'; end if;
  if char_length(dl)>1600 then raise exception 'Delil en fazla 1600 karakter olabilir.'; end if;
  if p_hedef_tur='oyuncu' then
   select * into u from oyun.profiller where lower(kad)=lower(trim(coalesce(p_hedef,''))) and not yasakli;
   if u.id is null then raise exception 'Davalı oyuncu bulunamadı.'; end if;
   if u.id=p.id then raise exception 'Kendinize dava açamazsınız.'; end if;
   had:=u.kad;
  elsif p_hedef_tur='parti' then
   begin hp:=p_hedef::bigint; exception when others then raise exception 'Geçersiz parti.'; end;
   select ad into had from oyun.partiler where id=hp and not kapali;
   if had is null then raise exception 'Parti bulunamadı.'; end if;
   if hp=p_parti then raise exception 'Bir parti kendisine dava açamaz.'; end if;
  elsif p_hedef_tur in ('sirket','dernek','belediye','makam','bakanlik','gazete') then
   had:=oyun.adliye_kurum_adi(p_hedef_tur,p_hedef);
   if had is null then raise exception 'Kurum bulunamadı veya faal değil.'; end if;
   if oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,p.id) then raise exception 'Temsil ettiğiniz kuruma dava açamazsınız.'; end if;
  else raise exception 'Davalı türü geçersiz.'; end if;
  if p_dava_tur='tazminat' then
   if p_hedef_tur='parti' or p_hedef_tur='makam' then raise exception 'Tazminat partiye ya da makama karşı istenemez.'; end if;
   if p_hedef_tur='oyuncu' and p_parti is not null then raise exception 'Oyuncudan tazminatı yalnız kendi adına isteyebilirsin.'; end if;
   if p_tazminat is null or p_tazminat<1000 or p_tazminat>500000 or p_tazminat<>trunc(p_tazminat) then raise exception 'Tazminat talebi 1.000–500.000 ₺ arasında tam sayı olmalı.'; end if;
  end if;
  insert into oyun.hukuk_isleri(tur,muvekkil,parti_id,hedef_tur,hedef,hedef_ad,dava_tur,tazminat_talep,metin,delil)
  values('dava',p.id,p_parti,p_hedef_tur,case when p_hedef_tur='oyuncu' then u.kad else p_hedef end,had,p_dava_tur,case when p_dava_tur='tazminat' then p_tazminat end,m,dl) returning id into yid;
 elsif p_tur='secim_itiraz' then
  if p_parti is null then raise exception 'İtiraz eden partiyi seç.'; end if;
  select * into s from oyun.secimler where id=p_secim;
  if s.id is null or s.sonuc is null or s.sonuc_at is null or now()<s.sonuc_at then raise exception 'Yalnız sonuçlanmış seçimlere itiraz edilebilir.'; end if;
  if now()>s.sonuc_at+interval '48 hours' then raise exception '48 saatlik itiraz süresi doldu.'; end if;
  if exists(select 1 from oyun.hukuk_isleri where tur='secim_itiraz' and secim_id=s.id and parti_id=p_parti and durum in ('avukat_bekliyor','vekil_atandi')) then raise exception 'Bu seçim için bekleyen bir itiraz işiniz var.'; end if;
  if char_length(m) not between 30 and 1600 then raise exception 'İtiraz gerekçesi 30-1600 karakter olmalı.'; end if;
  if char_length(dl)>3000 then raise exception 'Deliller en fazla 3000 karakter olabilir.'; end if;
  insert into oyun.hukuk_isleri(tur,muvekkil,parti_id,secim_id,hedef_ad,metin,delil)
  values('secim_itiraz',p.id,p_parti,s.id,format('Seçim #%s · %s · %s',s.id,s.tur,s.donem),m,dl) returning id into yid;
 else
  select * into k from oyun.pkd_dava where id=p_pkd;
  if k.id is null or k.durum<>'savunma' or now()>=k.savunma_son then raise exception 'Bu parti kapatma davası savunma aşamasında değil.'; end if;
  select * into pa from oyun.partiler where id=k.parti_id;
  if p.id is distinct from pa.gb and p.id is distinct from pa.gb_vekil then raise exception 'Bu iş için avukatı davalı partinin genel başkanı tutar.'; end if;
  if char_length(m) not between 50 and 3000 then raise exception 'Savunma taslağı 50-3000 karakter olmalı.'; end if;
  insert into oyun.hukuk_isleri(tur,muvekkil,parti_id,pkd_id,hedef_ad,metin)
  values('pkd_savunma',p.id,pa.id,k.id,'Parti kapatma davası #'||k.id,m) returning id into yid;
 end if;
 perform oyun.bildir(b.user_id,format('Yeni hukuki iş #%s avukat arıyor (%s). Türkiye Barosu > Davalar bölümünden teklif verebilirsin.',yid,
   case p_tur when 'dava' then 'dava açılışı' when 'secim_itiraz' then 'seçim itirazı' else 'parti kapatma savunması' end),oyun.simdi())
  from oyun.baro_uyeleri b where b.durum='aktif' and b.user_id<>p.id and oyun.avukat_mi(b.user_id);
 return jsonb_build_object('tamam',true,'id',yid);
end $f$;

create or replace function public.hukuk_is_davet(p_is bigint,p_kad text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); h oyun.hukuk_isleri; u uuid;
begin
 select * into h from oyun.hukuk_isleri where id=p_is;
 if h.id is null or h.muvekkil<>p.id or h.durum<>'avukat_bekliyor' then raise exception 'Avukat arayan bir işin bulunamadı.'; end if;
 select id into u from oyun.profiller where lower(kad)=lower(trim(coalesce(p_kad,''))) and not yasakli;
 if u is null or not oyun.avukat_mi(u) then raise exception 'Mesleği icra edebilen böyle bir avukat bulunamadı.'; end if;
 perform oyun.bildir(u,format('%s seni hukuki iş #%s için davet etti (%s). Türkiye Barosu > Davalar bölümünden teklif verebilirsin.',p.kad,h.id,coalesce(h.hedef_ad,'')),oyun.simdi());
 return jsonb_build_object('tamam',true);
end $f$;

create or replace function public.hukuk_is_teklif_ver(p_is bigint,p_tutar numeric,p_prim numeric default 0,p_aciklama text default '') returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); h oyun.hukuk_isleri; engel text:=oyun.avukat_engel(p.id); tid bigint;
begin
 if engel is not null then raise exception '%',engel; end if;
 select * into h from oyun.hukuk_isleri where id=p_is;
 if h.id is null or h.durum<>'avukat_bekliyor' then raise exception 'Bu iş artık avukat aramıyor.'; end if;
 if h.muvekkil=p.id then raise exception 'Kendi işine avukat olamazsın.'; end if;
 if exists(select 1 from oyun.mahkeme_uye where user_id=p.id) then raise exception 'Yargıç avukatlık yapamaz.'; end if;
 if h.tur='dava' and ((h.hedef_tur='oyuncu' and lower(h.hedef)=lower(p.kad))
   or (h.hedef_tur='parti' and exists(select 1 from oyun.partiler pa where pa.id::text=h.hedef and pa.gb=p.id))
   or (h.hedef_tur in ('sirket','dernek','belediye','makam','bakanlik','gazete') and oyun.adliye_kurum_yetkili(h.hedef_tur,h.hedef,p.id)))
  then raise exception 'Davalı tarafta olduğun işe avukat olamazsın.'; end if;
 if p_tutar is null or p_tutar<0 or p_tutar>1000000000000 then raise exception 'Ücret geçersiz.'; end if;
 if p_prim is null or p_prim<0 or p_prim>25 then raise exception 'Başarı primi %%0 ile %%25 arasında olmalı (Avukatlık Kanunu m.164).'; end if;
 if p_prim>0 and coalesce(h.dava_tur,'')<>'tazminat' then raise exception 'Başarı primi yalnız tazminat davalarında kararlaştırılabilir.'; end if;
 if exists(select 1 from oyun.hukuk_is_teklifleri where is_id=h.id and avukat_id=p.id and durum='bekliyor') then raise exception 'Bu işe bekleyen bir teklifin zaten var.'; end if;
 insert into oyun.hukuk_is_teklifleri(is_id,avukat_id,tutar,prim,aciklama) values(h.id,p.id,round(p_tutar),p_prim,left(trim(coalesce(p_aciklama,'')),500)) returning id into tid;
 perform oyun.bildir(h.muvekkil,format('Hukuki iş #%s için Av. %s teklif verdi: %s ₺%s. Adliye > Hukuki işlerim.',h.id,p.kad,oyun.tl(round(p_tutar)),case when p_prim>0 then format(', başarı primi %%%s',p_prim) else '' end),oyun.simdi());
 return jsonb_build_object('tamam',true,'id',tid);
end $f$;

create or replace function public.hukuk_is_teklif_karar(p_teklif bigint,p_kabul boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t oyun.hukuk_is_teklifleri; h oyun.hukuk_isleri;
begin
 select * into t from oyun.hukuk_is_teklifleri where id=p_teklif for update;
 if t.id is null or t.durum<>'bekliyor' then raise exception 'Teklif beklemede değil.'; end if;
 select * into h from oyun.hukuk_isleri where id=t.is_id for update;
 if h.muvekkil<>p.id then raise exception 'Bu işin müvekkili değilsin.'; end if;
 if h.durum<>'avukat_bekliyor' then raise exception 'Bu işe zaten avukat atandı.'; end if;
 if not p_kabul then
  update oyun.hukuk_is_teklifleri set durum='ret' where id=t.id;
  perform oyun.bildir(t.avukat_id,format('Hukuki iş #%s teklifin reddedildi.',h.id),oyun.simdi());
  return jsonb_build_object('durum','ret');
 end if;
 if not oyun.avukat_mi(t.avukat_id) then raise exception 'Avukat şu anda mesleği icra edemiyor.'; end if;
 if t.tutar>0 then perform oyun.para_islem(p.id,-t.tutar,'adliye','Hukuki iş #'||h.id||' avukatlık ücreti (iş sunulana kadar emanette)',oyun.simdi()); end if;
 update oyun.hukuk_isleri set durum='vekil_atandi',avukat_id=t.avukat_id,ucret=t.tutar,prim=t.prim,emanet=t.tutar,atama_at=now() where id=h.id;
 update oyun.hukuk_is_teklifleri set durum='kabul' where id=t.id;
 update oyun.hukuk_is_teklifleri set durum='iptal' where is_id=h.id and id<>t.id and durum='bekliyor';
 perform oyun.bildir(t.avukat_id,format('Hukuki iş #%s teklifin kabul edildi. Dilekçeyi hazırlayıp mahkemeye sun; ücretin sunumda emanetten ödenir.',h.id),oyun.simdi());
 return jsonb_build_object('durum','kabul');
end $f$;

create or replace function public.hukuk_is_iptal(p_is bigint) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); h oyun.hukuk_isleri;
begin
 select * into h from oyun.hukuk_isleri where id=p_is for update;
 if h.id is null or h.durum not in ('avukat_bekliyor','vekil_atandi') then raise exception 'İş iptal edilebilir durumda değil.'; end if;
 if h.muvekkil=p.id then
  if h.emanet>0 then perform oyun.para_islem(h.muvekkil,h.emanet,'adliye','Hukuki iş #'||h.id||' emanet iadesi',oyun.simdi()); end if;
  update oyun.hukuk_isleri set durum='iptal',emanet=0,iptal_at=now() where id=h.id;
  update oyun.hukuk_is_teklifleri set durum='iptal' where is_id=h.id and durum='bekliyor';
  if h.avukat_id is not null then perform oyun.bildir(h.avukat_id,format('Müvekkil hukuki iş #%s talebini geri çekti.',h.id),oyun.simdi()); end if;
  return jsonb_build_object('durum','iptal','iade',h.emanet);
 elsif h.avukat_id=p.id and h.durum='vekil_atandi' then
  if h.emanet>0 then perform oyun.para_islem(h.muvekkil,h.emanet,'adliye','Hukuki iş #'||h.id||' emanet iadesi (avukat çekildi)',oyun.simdi()); end if;
  update oyun.hukuk_isleri set durum='avukat_bekliyor',avukat_id=null,ucret=0,prim=0,emanet=0,atama_at=null where id=h.id;
  perform oyun.bildir(h.muvekkil,format('Av. %s hukuki iş #%s vekâletinden çekildi; ücretin iade edildi, yeni avukat arayabilirsin.',p.kad,h.id),oyun.simdi());
  return jsonb_build_object('durum','avukat_bekliyor','iade',h.emanet);
 end if;
 raise exception 'Bu işte iptal yetkin yok.';
end $f$;

create or replace function public.hukuk_is_sun(p_is bigint,p_metin text default null,p_delil text default null) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); h oyun.hukuk_isleri; engel text:=oyun.avukat_engel(p.id); m text; dl text; onceki text; r jsonb; yeni bigint; tid bigint; v_harc numeric;
begin
 if engel is not null then raise exception '%',engel; end if;
 select * into h from oyun.hukuk_isleri where id=p_is for update;
 if h.id is null or h.avukat_id is distinct from p.id or h.durum<>'vekil_atandi' then raise exception 'Bu işin vekili değilsin ya da iş sunulmaya hazır değil.'; end if;
 m:=coalesce(nullif(trim(coalesce(p_metin,'')),''),h.metin);
 dl:=coalesce(p_delil,h.delil);
 if h.tur='dava' then
  v_harc:=coalesce((select ma.harc from oyun.mahkeme_ayar ma),0);
  if v_harc>0 and coalesce((select c.para from oyun.cuzdan c where c.user_id=h.muvekkil),0)<v_harc then
   raise exception 'Müvekkilin cüzdanında dava harcı (% ₺) yok; müvekkiline haber ver.',oyun.tl(v_harc);
  end if;
  onceki:=oyun.vekil_basla(h.muvekkil,p.id);
  if h.hedef_tur in ('sirket','dernek','belediye','makam','bakanlik','gazete') then
   r:=public.adliye_kurum_dava_ac(h.hedef_tur,h.hedef,h.dava_tur,m,dl,h.parti_id,h.tazminat_talep);
  elsif h.dava_tur='tazminat' then
   r:=public.adliye_tazminat_davasi_ac(h.hedef,h.tazminat_talep,m,dl);
  else
   r:=public.adliye_dava_ac(h.hedef_tur,h.hedef,h.dava_tur,m,dl,h.parti_id);
  end if;
  perform oyun.vekil_bitir(onceki);
  yeni:=(r->>'id')::bigint;
  insert into oyun.avukat_teklifleri(dava_id,avukat_id,taraf,tutar,prim_orani,aciklama,durum,kabul_at)
  values(yeni,p.id,'davaci',h.ucret,h.prim,'Hukuki iş #'||h.id||' ile dava açılışı','kabul',now()) returning id into tid;
  insert into oyun.avukat_vekaletleri(teklif_id,dava_id,avukat_id,muvekkil,taraf,ucret,prim_orani) values(tid,yeni,p.id,h.muvekkil,'davaci',h.ucret,h.prim);
 elsif h.tur='secim_itiraz' then
  onceki:=oyun.vekil_basla(h.muvekkil,p.id);
  r:=public.adliye_secim_itiraz_ac(h.secim_id,h.parti_id,m,dl);
  perform oyun.vekil_bitir(onceki);
 else
  onceki:=oyun.vekil_basla(h.muvekkil,p.id);
  r:=public.parti_kapatma_savunma(h.pkd_id,m);
  perform oyun.vekil_bitir(onceki);
 end if;
 if h.emanet>0 then perform oyun.para_islem(p.id,h.emanet,'adliye','Hukuki iş #'||h.id||' avukatlık ücreti',oyun.simdi()); end if;
 update oyun.hukuk_isleri set durum='sunuldu',sunum_at=now(),emanet=0,dava_id=yeni,metin=m,delil=dl where id=h.id;
 perform oyun.bildir(h.muvekkil,case when yeni is not null then format('Av. %s davanı açtı: Adliye #%s. Dosyada vekilin olarak görünüyor.',p.kad,yeni)
   else format('Av. %s hukuki iş #%s kapsamında başvurunu mahkemeye sundu.',p.kad,h.id) end,oyun.simdi());
 return jsonb_build_object('tamam',true,'dava_id',yeni,'sonuc',r);
end $f$;

create or replace function oyun.hukuk_is_json(h oyun.hukuk_isleri,ben uuid) returns jsonb language sql stable set search_path='' as $f$
 select jsonb_build_object('id',h.id,'tur',h.tur,'muvekkil',oyun.kad(h.muvekkil),'parti',(select pa.ad from oyun.partiler pa where pa.id=h.parti_id),
  'hedef_tur',h.hedef_tur,'hedef_ad',h.hedef_ad,'dava_tur',h.dava_tur,'tazminat',h.tazminat_talep,'metin',h.metin,'delil',h.delil,'durum',h.durum,
  'avukat',oyun.kad(h.avukat_id),'ucret',h.ucret,'prim',h.prim,'emanet',h.emanet,'dava_id',h.dava_id,'olusturma',h.olusturma,'sunum_at',h.sunum_at,
  'muvekkilim',h.muvekkil=ben,'vekilim',h.avukat_id=ben,
  'teklifler',(select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'avukat',oyun.kad(t.avukat_id),'tutar',t.tutar,'prim',t.prim,'aciklama',t.aciklama,'durum',t.durum,'benim',t.avukat_id=ben) order by t.id desc),'[]'::jsonb)
    from oyun.hukuk_is_teklifleri t where t.is_id=h.id and (h.muvekkil=ben or t.avukat_id=ben) and t.durum in ('bekliyor','kabul')),
  'teklif_sayi',(select count(*) from oyun.hukuk_is_teklifleri t where t.is_id=h.id and t.durum='bekliyor'))
$f$;

create or replace function public.hukuk_islerim() returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); avk boolean:=oyun.baro_uyesi(p.id);
begin
 return jsonb_build_object(
  'avukat_miyim',oyun.avukat_mi(p.id),
  'benim',(select coalesce(jsonb_agg(oyun.hukuk_is_json(h,p.id) order by h.id desc),'[]'::jsonb) from oyun.hukuk_isleri h
    where h.id in (select x.id from oyun.hukuk_isleri x where x.muvekkil=p.id and (x.durum in ('avukat_bekliyor','vekil_atandi') or coalesce(x.sunum_at,x.iptal_at,x.olusturma)>now()-interval '3 days') order by x.id desc limit 20)),
  'ustlendigim',(select coalesce(jsonb_agg(oyun.hukuk_is_json(h,p.id) order by h.id desc),'[]'::jsonb) from oyun.hukuk_isleri h
    where h.id in (select x.id from oyun.hukuk_isleri x where x.avukat_id=p.id and (x.durum='vekil_atandi' or x.sunum_at>now()-interval '3 days') order by x.id desc limit 20)),
  'acik',case when avk or coalesce(p.yonetici,false) then (select coalesce(jsonb_agg(oyun.hukuk_is_json(h,p.id) order by h.id desc),'[]'::jsonb) from oyun.hukuk_isleri h
    where h.id in (select x.id from oyun.hukuk_isleri x where x.durum='avukat_bekliyor' order by x.id desc limit 40)) else '[]'::jsonb end
 );
end $f$;

-- ---------------------------------------------------------------- 5) Parti Sözcüsü: resmî açıklama makamı
create or replace function public.parti_aciklama_yap(p_parti bigint,p_baslik text,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); pa oyun.partiler; rol text; b text:=trim(coalesce(p_baslik,'')); m text:=trim(coalesce(p_metin,'')); yid bigint; t timestamptz:=oyun.simdi();
begin
 select * into pa from oyun.partiler where id=p_parti and not kapali;
 if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
 if exists(select 1 from oyun.parti_sozcu s where s.parti_id=pa.id and s.user_id=p.id) and p.parti_id=pa.id then rol:='sozcu';
 elsif pa.gb=p.id then rol:='gb';
 else raise exception 'Parti adına resmî açıklamayı yalnız parti sözcüsü ya da genel başkan yapabilir.'; end if;
 if coalesce(p.susturma_bitis,'-infinity'::timestamptz)>t or coalesce(p.adliye_susturma_bitis,'-infinity'::timestamptz)>t then raise exception 'Susturma cezan sürerken açıklama yapamazsın.'; end if;
 if char_length(b) not between 3 and 120 then raise exception 'Başlık 3-120 karakter olmalı.'; end if;
 if char_length(m) not between 10 and 2000 then raise exception 'Açıklama 10-2000 karakter olmalı.'; end if;
 if m ~* '(https?://|www\.|t\.me/)' then raise exception 'Açıklamalarda bağlantı kullanılamaz.'; end if;
 if exists(select 1 from oyun.parti_aciklamalar where parti_id=pa.id and not silindi and zaman>now()-interval '15 minutes') then raise exception 'Parti adına yeni açıklama için 15 dakika bekleyin.'; end if;
 insert into oyun.parti_aciklamalar(parti_id,yazar,rol,baslik,metin) values(pa.id,p.id,rol,b,m) returning id into yid;
 insert into oyun.akis(user_id,metin,zaman,il_id,parti_id)
 values(p.id,left('📢 '||pa.kisa||' resmî açıklaması — '||b||': '||m,280),t,p.il_id,pa.id);
 perform oyun.bildir(u.id,format('%s resmî açıklaması: %s',pa.kisa,left(b,100)),t)
  from oyun.profiller u where u.parti_id=pa.id and u.id<>p.id and not u.yasakli;
 return jsonb_build_object('tamam',true,'id',yid);
end $f$;

create or replace function public.parti_aciklamalari(p_parti bigint) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); pa oyun.partiler; soz uuid;
begin
 select * into pa from oyun.partiler where id=p_parti;
 if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
 select s.user_id into soz from oyun.parti_sozcu s where s.parti_id=pa.id;
 return jsonb_build_object(
  'sozcu',oyun.kad(soz),'gb_miyim',pa.gb=p.id,
  'yazabilirim',not pa.kapali and (pa.gb=p.id or (soz=p.id and p.parti_id=pa.id)),
  'aciklamalar',(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'yazar',oyun.kad(a.yazar),'rol',a.rol,'baslik',a.baslik,'metin',a.metin,'zaman',a.zaman,
      'silebilirim',a.yazar=p.id or pa.gb=p.id) order by a.id desc),'[]'::jsonb)
    from (select * from oyun.parti_aciklamalar where parti_id=pa.id and not silindi order by id desc limit 20) a)
 );
end $f$;

create or replace function public.parti_aciklama_sil(p_id bigint) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.parti_aciklamalar;
begin
 select * into a from oyun.parti_aciklamalar where id=p_id and not silindi for update;
 if a.id is null then raise exception 'Açıklama bulunamadı.'; end if;
 if not (a.yazar=p.id or exists(select 1 from oyun.partiler pa where pa.id=a.parti_id and pa.gb=p.id)) then raise exception 'Bu açıklamayı kaldırma yetkin yok.'; end if;
 update oyun.parti_aciklamalar set silindi=true where id=a.id;
 return jsonb_build_object('tamam',true);
end $f$;

-- ---------------------------------------------------------------- 6) Dosya bilgisi (arayüz için)
create or replace function public.baro_dava_bilgi(p_dava bigint) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; tr text; b oyun.baro; taraf_mi boolean; kayb text; ist boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null then raise exception 'Dava bulunamadı.'; end if;
 select * into b from oyun.baro where id=1;
 tr:=case when d.davaci=p.id and d.davaci_parti is null then 'davaci' when d.davali=p.id then 'davali' end;
 taraf_mi:=oyun.dava_muvekkil_mi(d,'davaci',p.id) or oyun.dava_muvekkil_mi(d,'davali',p.id) or exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.muvekkil=p.id);
 kayb:=case when d.durum='karar' then case when d.karar='beraat' then 'davaci' else 'davali' end end;
 ist:=d.durum='karar' and not d.kesin and now()<=coalesce(d.istinaf_son,now()) and not exists(select 1 from oyun.adliye_istinaf i where i.dava_id=d.id);
 return jsonb_build_object(
  'benim_taraf',tr,
  'vekilim_var',tr is not null and exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.taraf=tr and v.aktif),
  'dava_acik',d.durum='acik',
  'zorunlu',oyun.avukat_zorunlu_mu(d.acilis),
  'ilgili_miyim',exists(select 1 from oyun.adliye_ek_taraf e where e.dava_id=d.id and e.user_id=p.id),
  'muvekkil_taraf',case when oyun.dava_muvekkil_mi(d,'davaci',p.id) then 'davaci' when oyun.dava_muvekkil_mi(d,'davali',p.id) then 'davali' end,
  'istinaf_vekili',ist and exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.taraf=kayb and v.avukat_id=p.id and v.aktif),
  'istinaf_acik',ist,'kaybeden',kayb,'istinaf_son',d.istinaf_son,
  'sinir',b.adli_yardim_sinir,
  'cuzdan',(select c.para from oyun.cuzdan c where c.user_id=p.id),
  'baro_uye_sayi',(select count(*) from oyun.baro_uyeleri where durum='aktif'),
  'talepler',(select coalesce(jsonb_agg(jsonb_build_object('id',y.id,'taraf',y.taraf,'durum',y.durum,'avukat',oyun.kad(y.avukat_id),'karar_gerekce',y.karar_gerekce,'zaman',y.zaman) order by y.id desc),'[]'::jsonb)
     from oyun.baro_adli_yardim y where y.dava_id=d.id and (y.talep_eden=p.id or oyun.baro_uyesi(p.id))),
  'sikayet_edilebilir',case when taraf_mi then
     (select coalesce(jsonb_agg(distinct jsonb_build_object('id',v.avukat_id,'kad',oyun.kad(v.avukat_id))),'[]'::jsonb) from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.avukat_id<>p.id)
     else '[]'::jsonb end
 );
end $f$;

-- ---------------------------------------------------------------- 7) Yetkiler
do $grants$
declare f record;
begin
 for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('adliye_dava_ac','adliye_kurum_dava_ac','adliye_beyan_ver','adliye_temsil_yetkisi','adliye_secim_itiraz_ac','parti_kapatma_savunma','adliye_sozcu_ata',
   'avukat_teklif_ver','avukat_karsi_teklif','avukat_teklif_karar','avukat_dava_durum','avukat_istinaf','hukuk_is_olustur','hukuk_is_davet','hukuk_is_teklif_ver','hukuk_is_teklif_karar',
   'hukuk_is_iptal','hukuk_is_sun','hukuk_islerim','parti_aciklama_yap','parti_aciklamalari','parti_aciklama_sil','baro_dava_bilgi')
 loop execute format('revoke all on function %s from public, anon; grant execute on function %s to authenticated',f.sig,f.sig); end loop;
 for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='oyun' and p.proname in ('avukat_zorunlu_mu','vekil_islem_mi','vekil_basla','vekil_bitir','dava_muvekkil_mi','hukuk_is_json')
 loop execute format('revoke all on function %s from public, anon, authenticated',f.sig); end loop;
end $grants$;
