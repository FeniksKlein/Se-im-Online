-- ADLİYE / YÜKSEK YARGIÇ / PARTİ SÖZCÜSÜ / AF (10.10.2026)
-- Yalnızca eklemeli değişiklik. Oyuncu verileri ve mevcut makamlar korunur.
create table if not exists oyun.adliye_makam (
 id int primary key check(id=1), hakim uuid references oyun.profiller(id),
 atayan uuid references oyun.profiller(id), atama_at timestamptz, degistirme_at timestamptz default now()
);
insert into oyun.adliye_makam(id) values(1) on conflict do nothing;
create table if not exists oyun.adliye_atama_kayit (
 id bigserial primary key, yapan uuid not null references oyun.profiller(id),
 eski uuid references oyun.profiller(id), yeni uuid references oyun.profiller(id),
 gerekce text, zaman timestamptz not null default now()
);
create table if not exists oyun.parti_sozcu (
 parti_id bigint primary key references oyun.partiler(id), user_id uuid references oyun.profiller(id),
 atayan uuid references oyun.profiller(id), zaman timestamptz default now()
);
create table if not exists oyun.parti_sozcu_kayit (
 id bigserial primary key, parti_id bigint not null references oyun.partiler(id),
 yapan uuid not null references oyun.profiller(id),
 eski uuid references oyun.profiller(id), yeni uuid references oyun.profiller(id),
 zaman timestamptz not null default now()
);
create table if not exists oyun.adliye_davalar (
 id bigserial primary key, davaci uuid not null references oyun.profiller(id),
 davaci_parti bigint references oyun.partiler(id),
 davali uuid references oyun.profiller(id),
 davali_parti bigint references oyun.partiler(id),
 tur text not null check(tur in('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger')),
 iddia text not null check(char_length(iddia) between 20 and 1600),
 delil text not null default '',
 acilis timestamptz not null default now(), savunma_son timestamptz not null,
 savunma_geldi boolean not null default false,
 durum text not null default 'acik' check(durum in('acik','karar')),
 hakim uuid references oyun.profiller(id), karar text check(karar in('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur')),
 gerekce text, karar_at timestamptz, ceza_bitis timestamptz, mv_makam_id bigint,
 af_at timestamptz, af_veren uuid references oyun.profiller(id), af_gerekce text,
 constraint adliye_tek_davali check((davali is not null)::int+(davali_parti is not null)::int=1),
 constraint adliye_taraf_farki check(davali is null or davali<>davaci)
);
create index if not exists adliye_davalar_son on oyun.adliye_davalar(id desc);
create index if not exists adliye_davalar_oyuncu on oyun.adliye_davalar(davali,id desc);
create table if not exists oyun.adliye_temsil (
 dava_id bigint not null references oyun.adliye_davalar(id),
 yetki_veren uuid not null references oyun.profiller(id),
 yetki_verildi timestamptz not null default now(), aktif boolean not null default true,
 primary key(dava_id,yetki_veren)
);
create table if not exists oyun.adliye_beyan (
 id bigserial primary key, dava_id bigint not null references oyun.adliye_davalar(id),
 yazar uuid not null references oyun.profiller(id), rol text not null check(rol in('davaci','davali','sozcu')),
 metin text not null check(char_length(metin) between 10 and 2500),
 zaman timestamptz not null default now()
);
create index if not exists adliye_beyan_dava on oyun.adliye_beyan(dava_id,id);
create table if not exists oyun.adliye_yorum (
 id bigserial primary key, dava_id bigint not null references oyun.adliye_davalar(id),
 yazar uuid not null references oyun.profiller(id),
 metin text not null check(char_length(metin) between 3 and 500),
 zaman timestamptz not null default now()
);
create index if not exists adliye_yorum_dava on oyun.adliye_yorum(dava_id,id);
create table if not exists oyun.adliye_aflar (
 id bigserial primary key, cb uuid not null references oyun.profiller(id),
 dava_id bigint references oyun.adliye_davalar(id), tur text not null check(tur in('bireysel','genel')),
 gerekce text not null, affedilen int not null, zaman timestamptz not null default now()
);
alter table oyun.profiller add column if not exists adliye_susturma_bitis timestamptz;
alter table oyun.adliye_makam enable row level security;
alter table oyun.adliye_atama_kayit enable row level security;
alter table oyun.parti_sozcu enable row level security;
alter table oyun.parti_sozcu_kayit enable row level security;
alter table oyun.adliye_davalar enable row level security;
alter table oyun.adliye_temsil enable row level security;
alter table oyun.adliye_beyan enable row level security;
alter table oyun.adliye_yorum enable row level security;
alter table oyun.adliye_aflar enable row level security;
revoke all on oyun.adliye_makam,oyun.adliye_atama_kayit,oyun.parti_sozcu,oyun.parti_sozcu_kayit,oyun.adliye_davalar,oyun.adliye_temsil,oyun.adliye_beyan,oyun.adliye_yorum,oyun.adliye_aflar from public,anon,authenticated;

-- Önceden var olan moderasyon susturmasını değiştirmeden mahkeme cezasını ek denetle.
create or replace function oyun.yazabilir_mi(p oyun.profiller,t timestamptz) returns void language plpgsql as $$
begin
 if p.susturma_bitis is not null and p.susturma_bitis>t then
  raise exception 'Hesabın % tarihine kadar mesaj gönderemez (kural ihlali).',to_char(p.susturma_bitis at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI');
 end if;
 if p.adliye_susturma_bitis is not null and p.adliye_susturma_bitis>t then
  raise exception 'Mahkeme kararıyla % tarihine kadar sohbetten susturuldunuz.',to_char(p.adliye_susturma_bitis at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI');
 end if;
 if p.son_mesaj is not null and p.son_mesaj>t-interval '3 seconds' then
  raise exception 'Çok hızlı yazıyorsun, birkaç saniye bekle.';
 end if;
 if (select count(*) from oyun.mesajlar where user_id=p.id and zaman>t-interval '1 minute')
  +(select count(*) from oyun.ozel where gonderen=p.id and zaman>t-interval '1 minute')>=12 then
  raise exception 'Bir dakikada çok fazla mesaj gönderdin, biraz bekle.';
 end if;
end $$;

create or replace function public.adliye_durum() returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 'id',d.id,'davaci',oyun.kad(d.davaci),'davaci_parti',dp.ad,'davali',oyun.kad(d.davali),'davali_parti',hp.ad,
 'tur',d.tur,'iddia',d.iddia,'delil',d.delil,'acilis',d.acilis,'savunma_son',d.savunma_son,
 'savunma_geldi',d.savunma_geldi,'durum',d.durum,'hakim',oyun.kad(d.hakim),
 'karar',d.karar,'gerekce',d.gerekce,'karar_at',d.karar_at,'ceza_bitis',d.ceza_bitis,
 'af_at',d.af_at,'af_veren',oyun.kad(d.af_veren),'af_gerekce',d.af_gerekce,
 'davalimiyim',d.davali=p.id,'davacimiyim',d.davaci=p.id,'temsil_iznim',exists(select 1 from oyun.adliye_temsil a where a.dava_id=d.id and a.yetki_veren=p.id and a.aktif),
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
end $$;

create or replace function public.adliye_detay(p_dava bigint) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 if not exists(select 1 from oyun.adliye_davalar where id=p_dava) then raise exception 'Dava bulunamadı.'; end if;
 return jsonb_build_object(
 'beyanlar',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'yazar',oyun.kad(b.yazar),'rol',b.rol,'metin',b.metin,'zaman',b.zaman) order by b.id)
 from oyun.adliye_beyan b where b.dava_id=p_dava),'[]'::jsonb),
 'yorumlar',coalesce((select jsonb_agg(jsonb_build_object('id',y.id,'yazar',oyun.kad(y.yazar),'metin',y.metin,'zaman',y.zaman) order by y.id)
 from (select * from oyun.adliye_yorum where dava_id=p_dava order by id desc limit 80) y),'[]'::jsonb)
 );
end $$;

create or replace function public.adliye_hakim_ata(p_kad text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; eski uuid; t timestamptz:=oyun.simdi();
begin
 if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null) then raise exception 'Yüksek Yargıcı yalnız Cumhurbaşkanı atayabilir.'; end if;
 select * into u from oyun.profiller where lower(kad)=lower(trim(p_kad)) and not yasakli;
 if u.id is null then raise exception 'Kullanıcı bulunamadı.'; end if;
 if u.id=p.id then raise exception 'Cumhurbaşkanı kendisini atayamaz.'; end if;
 select hakim into eski from oyun.adliye_makam where id=1 for update;
 if eski=u.id then raise exception 'Bu oyuncu zaten Yüksek Yargıç.'; end if;
 update oyun.adliye_makam set hakim=u.id,atayan=p.id,atama_at=t,degistirme_at=t where id=1;
 insert into oyun.adliye_atama_kayit(yapan,eski,yeni,gerekce,zaman) values(p.id,eski,u.id,'Cumhurbaşkanı ataması',t);
 insert into oyun.bildirimler(user_id,zaman,metin) values(u.id,t,'Cumhurbaşkanı sizi Yüksek Yargıç olarak atadı.');
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.adliye_hakim_al(p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); eski uuid; t timestamptz:=oyun.simdi();
begin
 if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null) then raise exception 'Yalnız Cumhurbaşkanı Yüksek Yargıcı görevden alabilir.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 10 and 500 then raise exception 'Gerekçe 10–500 karakter olmalı.'; end if;
 select hakim into eski from oyun.adliye_makam where id=1 for update;
 if eski is null then raise exception 'Görevde Yüksek Yargıç yok.'; end if;
 update oyun.adliye_makam set hakim=null,atayan=p.id,atama_at=null,degistirme_at=t where id=1;
 insert into oyun.adliye_atama_kayit(yapan,eski,yeni,gerekce,zaman) values(p.id,eski,null,trim(p_gerekce),t);
 insert into oyun.bildirimler(user_id,zaman,metin) values(eski,t,'Cumhurbaşkanı Yüksek Yargıç görevinizi sonlandırdı. Gerekçe: '||left(trim(p_gerekce),200));
 return jsonb_build_object('tamam',true);
end $$;

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

create or replace function public.adliye_dava_ac(p_hedef_tur text,p_hedef text,p_tur text,p_iddia text,p_delil text default '',p_davaci_parti bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; hedef_parti bigint; t timestamptz:=oyun.simdi(); yeni bigint;
begin
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
 if p_davaci_parti is not null and not exists(
  select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id
  where pa.id=p_davaci_parti and not pa.kapali and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))
 ) then raise exception 'Parti adına dava açmak için genel başkan veya sözcü olmalısınız.'; end if;
 if hedef_parti is not null and hedef_parti=p_davaci_parti then raise exception 'Bir parti kendisine dava açamaz.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'En fazla üç açık davanız olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Yeni dava için 10 dakika bekleyin.'; end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali,davali_parti,tur,iddia,delil,acilis,savunma_son)
 values(p.id,p_davaci_parti,u.id,hedef_parti,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+interval '6 hours') returning id into yeni;
 if u.id is not null then insert into oyun.bildirimler(user_id,zaman,metin) values(u.id,t,'#'||yeni||' numaralı davada hakkınızda iddia var. Adliye''den 6 saat içinde savunma yapın.'); end if;
 if hedef_parti is not null then
  insert into oyun.bildirimler(user_id,zaman,metin)
  select distinct z.id,t,'#'||yeni||' numaralı davada partiniz davalıdır. Savunma Adliye''de.'
  from (select gb as id from oyun.partiler where id=hedef_parti union select user_id from oyun.parti_sozcu where parti_id=hedef_parti) z
  where z.id is not null;
 end if;
 return jsonb_build_object('tamam',true,'id',yeni);
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

create or replace function public.adliye_beyan_ver(p_dava bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; rol text; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava savunmaya açık değil.'; end if;
 if char_length(trim(coalesce(p_metin,''))) not between 10 and 2500 then raise exception 'Beyan 10–2500 karakter olmalı.'; end if;
 if d.davali=p.id then rol:='davali';
 elsif d.davali_parti is not null and exists(select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where pa.id=d.davali_parti
 and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))) then rol:='sozcu';
 elsif d.davali is not null and exists(
 select 1 from oyun.adliye_temsil y join oyun.profiller q on q.id=d.davali
 join oyun.parti_sozcu s on s.parti_id=q.parti_id and s.user_id=p.id
 where y.dava_id=d.id and y.yetki_veren=d.davali and y.aktif and p.parti_id=q.parti_id) then rol:='sozcu';
 elsif d.davaci=p.id then rol:='davaci';
 elsif d.davaci_parti is not null and exists(select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where pa.id=d.davaci_parti
 and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))) then rol:='davaci';
 else raise exception 'Bu davada konuşma yetkiniz yok.'; end if;
 if exists(select 1 from oyun.adliye_beyan where dava_id=d.id and yazar=p.id and zaman>t-interval '30 seconds') then raise exception 'Yeni beyan için 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_beyan(dava_id,yazar,rol,metin,zaman) values(d.id,p.id,rol,trim(p_metin),t);
 if rol in ('davali','sozcu') then update oyun.adliye_davalar set savunma_geldi=true where id=d.id; end if;
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.adliye_yorum_yaz(p_dava bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
begin
 if not exists(select 1 from oyun.adliye_davalar where id=p_dava) then raise exception 'Dava bulunamadı.'; end if;
 if (p.susturma_bitis is not null and p.susturma_bitis>t) or (p.adliye_susturma_bitis is not null and p.adliye_susturma_bitis>t) then raise exception 'Susturma cezanız devam ediyor.'; end if;
 if char_length(trim(coalesce(p_metin,''))) not between 3 and 500 then raise exception 'Yorum 3–500 karakter olmalı.'; end if;
 if exists(select 1 from oyun.adliye_yorum where yazar=p.id and zaman>t-interval '30 seconds') then raise exception 'Yeni yorum için 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_yorum(dava_id,yazar,metin,zaman) values(p_dava,p.id,trim(p_metin),t);
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.adliye_karar_ver(p_dava bigint,p_karar text,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; t timestamptz:=oyun.simdi(); bitis timestamptz; mv bigint;
begin
 if not exists(select 1 from oyun.adliye_makam where id=1 and hakim=p.id) then raise exception 'Yalnız görevdeki Yüksek Yargıç karar verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Açık bir dava bulunamadı.'; end if;
 if d.davaci=p.id or d.davali=p.id then raise exception 'Yargıç kendi davasını karara bağlayamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma süresinin dolmasını bekleyin.'; end if;
 if p_karar not in('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur') then raise exception 'Geçersiz karar.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekçeli karar 20–2000 karakter olmalı.'; end if;
 if d.davali is null and p_karar not in('beraat','uyari') then raise exception 'Partiye yalnız uyarı veya beraat kararı verilebilir.'; end if;
 if p_karar='vekillik_dusur' then
  select id into mv from oyun.makamlar where user_id=d.davali and tur='mv' and bit is null order by bas desc limit 1 for update;
  if mv is null then raise exception 'Davalının aktif milletvekilliği yok.'; end if;
 end if;
 if p_karar in('sustur_1s','sustur_1g','sustur_1h') then
  bitis:=t+case p_karar when 'sustur_1s' then interval '1 hour' when 'sustur_1g' then interval '1 day' else interval '7 days' end;
  update oyun.profiller set adliye_susturma_bitis=greatest(coalesce(adliye_susturma_bitis,t),bitis) where id=d.davali;
 end if;
 if p_karar='vekillik_dusur' then
  update oyun.makamlar set bit=t,bitis_neden='Adliye #'||d.id||' kararı'
  where user_id=d.davali and bit is null and tur in('mv','tbmm','bskv','grup_bskv');
 end if;
 update oyun.adliye_davalar set durum='karar',hakim=p.id,karar=p_karar,gerekce=trim(p_gerekce),
 karar_at=t,ceza_bitis=bitis,mv_makam_id=mv where id=d.id;
 insert into oyun.bildirimler(user_id,zaman,metin)
 select x.id,t,'Adliye #'||d.id||' kararı: '||p_karar||'. Kamuya açık gerekçe için Adliye bölümüne girin.'
 from (select d.davaci as id union select d.davali where d.davali is not null) x;
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.adliye_af_cikar(p_dava bigint,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); d oyun.adliye_davalar; adet int:=0; kalan timestamptz; eski oyun.makamlar;
begin
 if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null) then raise exception 'Yalnız Cumhurbaşkanı af çıkarabilir.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 10 and 1000 then raise exception 'Af gerekçesi 10–1000 karakter olmalı.'; end if;
 for d in select * from oyun.adliye_davalar
  where durum='karar' and af_at is null and karar not in('beraat')
    and (p_dava is null or id=p_dava) order by id for update
 loop
  update oyun.adliye_davalar set af_at=t,af_veren=p.id,af_gerekce=trim(p_gerekce) where id=d.id;
  adet:=adet+1;
  if d.davali is not null and d.karar in('sustur_1s','sustur_1g','sustur_1h') then
   -- Yalnızca mahkeme susturmasını kaldır, yönetici susturmalarını değiştirme.
   select max(ceza_bitis) into kalan from oyun.adliye_davalar
   where davali=d.davali and durum='karar' and af_at is null and karar in('sustur_1s','sustur_1g','sustur_1h') and ceza_bitis>t;
   update oyun.profiller set adliye_susturma_bitis=kalan where id=d.davali;
  end if;
  if d.karar='vekillik_dusur' and d.mv_makam_id is not null then
    select * into eski from oyun.makamlar where id=d.mv_makam_id for update;
    if eski.id is not null and eski.bit is not null and eski.bitis_neden='Adliye #'||d.id||' kararı'
      and not exists(select 1 from oyun.makamlar where user_id=eski.user_id and tur='mv' and bit is null)
      and not exists(select 1 from oyun.secimler where tur='mv' and goreve_bas>d.karar_at and goreve_bas<=t)
      and (select count(*) from oyun.makamlar where tur='mv' and bit is null)<600 then
      update oyun.makamlar set bit=null,bitis_neden=null where id=eski.id;
    end if;
  end if;
  if d.davali is not null then
   insert into oyun.bildirimler(user_id,zaman,metin) values(d.davali,t,'Cumhurbaşkanı Adliye #'||d.id||' cezanızı affetti. Detaylar Adliye''de.');
  end if;
 end loop;
 if adet=0 then raise exception 'Affedilebilecek kesinleşmiş ceza bulunamadı.'; end if;
 insert into oyun.adliye_aflar(cb,dava_id,tur,gerekce,affedilen,zaman)
 values(p.id,p_dava,case when p_dava is null then 'genel' else 'bireysel' end,trim(p_gerekce),adet,t);
 return jsonb_build_object('tamam',true,'affedilen',adet);
end $$;

revoke all on function public.adliye_durum() from public,anon;
revoke all on function public.adliye_detay(bigint) from public,anon;
revoke all on function public.adliye_hakim_ata(text) from public,anon;
revoke all on function public.adliye_hakim_al(text) from public,anon;
revoke all on function public.adliye_sozcu_ata(bigint,text) from public,anon;
revoke all on function public.adliye_dava_ac(text,text,text,text,text,bigint) from public,anon;
revoke all on function public.adliye_temsil_yetkisi(bigint,boolean) from public,anon;
revoke all on function public.adliye_beyan_ver(bigint,text) from public,anon;
revoke all on function public.adliye_yorum_yaz(bigint,text) from public,anon;
revoke all on function public.adliye_karar_ver(bigint,text,text) from public,anon;
revoke all on function public.adliye_af_cikar(bigint,text) from public,anon;
grant execute on function public.adliye_durum() to authenticated;
grant execute on function public.adliye_detay(bigint) to authenticated;
grant execute on function public.adliye_hakim_ata(text) to authenticated;
grant execute on function public.adliye_hakim_al(text) to authenticated;
grant execute on function public.adliye_sozcu_ata(bigint,text) to authenticated;
grant execute on function public.adliye_dava_ac(text,text,text,text,text,bigint) to authenticated;
grant execute on function public.adliye_temsil_yetkisi(bigint,boolean) to authenticated;
grant execute on function public.adliye_beyan_ver(bigint,text) to authenticated;
grant execute on function public.adliye_yorum_yaz(bigint,text) to authenticated;
grant execute on function public.adliye_karar_ver(bigint,text,text) to authenticated;
grant execute on function public.adliye_af_cikar(bigint,text) to authenticated;