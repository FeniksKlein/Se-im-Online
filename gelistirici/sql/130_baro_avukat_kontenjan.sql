-- 130 · Avukatlık kontenjanı 2.0 + Türkiye Barosu (23.10.2026)
-- Yalnız ekleme ve create or replace. Oyuncu hesabı, para, makam ve dava kaydı silinmez.
--  * Kontenjan: yönetici ayarı, otomatik sıra ilerletme, sıkışan sıra düzeltmesi, pasif avukat slot iadesi
--  * Sınav: 60 soruluk banka, her denemede rastgele 20 soru, %25 başarı primi sınırı (Av.K. m.164)
--  * Baro: levha kaydı yalnız ruhsatlı avukatlara, üyelere özel bina, aidat/kasa, başkanlık seçimi,
--    adli yardım, disiplin, avukat bekleyen davalar. Mesleği icra etmek için baro kaydı şarttır.

-- ---------------------------------------------------------------- 1) Ayarlar ve ruhsat sütunları
alter table oyun.ayarlar add column if not exists avukat_kontenjan_elle int;
alter table oyun.ayarlar add column if not exists avukat_oran int not null default 10;
alter table oyun.ayarlar add column if not exists avukat_min int not null default 2;
alter table oyun.ayarlar add column if not exists avukat_pasif_gun int not null default 14;

alter table oyun.avukat_ruhsat add column if not exists harc_odendi boolean not null default false;
alter table oyun.avukat_ruhsat add column if not exists askida_at timestamptz;
alter table oyun.avukat_ruhsat add column if not exists para_uyari_at timestamptz;

create table if not exists oyun.avukat_ruhsat_gecmis(
 id bigserial primary key,
 user_id uuid not null references oyun.profiller(id),
 olay text not null,
 aciklama text not null default '',
 zaman timestamptz not null default now()
);
create index if not exists avukat_ruhsat_gecmis_u on oyun.avukat_ruhsat_gecmis(user_id,zaman desc);

-- ---------------------------------------------------------------- 2) Baro tabloları
create table if not exists oyun.baro(
 id smallint primary key default 1 check(id=1),
 ad text not null default 'Türkiye Barosu',
 kasa numeric not null default 0 check(kasa>=0),
 baskan uuid references oyun.profiller(id),
 baskan_bas timestamptz,
 baskan_secim bigint,
 giris_ucret numeric not null default 10000 check(giris_ucret>=0),
 aidat numeric not null default 5000 check(aidat>=0),
 adli_yardim_ucret numeric not null default 20000 check(adli_yardim_ucret>=0),
 adli_yardim_sinir numeric not null default 50000 check(adli_yardim_sinir>=0),
 ruhsat_pay numeric not null default 0.25 check(ruhsat_pay between 0 and 1),
 kurulus timestamptz not null default now()
);
insert into oyun.baro(id) values(1) on conflict(id) do nothing;

create sequence if not exists oyun.baro_sicil_seq start with 1001;
create table if not exists oyun.baro_uyeleri(
 user_id uuid primary key references oyun.profiller(id),
 sicil_no bigint not null unique default nextval('oyun.baro_sicil_seq'),
 durum text not null default 'aktif' check(durum in ('aktif','ayrildi','silindi')),
 ilk_kayit timestamptz not null default now(),
 kayit_at timestamptz not null default now(),
 aidat_bitis timestamptz not null default now()+interval '30 days',
 aidat_uyari_at timestamptz,
 gonullu boolean not null default false,
 cikis_at timestamptz,
 cikis_neden text
);
create table if not exists oyun.baro_kasa_hareket(
 id bigserial primary key,
 zaman timestamptz not null default now(),
 tutar numeric not null,
 tur text not null,
 aciklama text not null default '',
 user_id uuid references oyun.profiller(id)
);
create table if not exists oyun.baro_mesajlar(
 id bigserial primary key,
 yazar uuid not null references oyun.profiller(id),
 metin text not null check(char_length(metin) between 1 and 1000),
 duyuru boolean not null default false,
 zaman timestamptz not null default now(),
 silindi boolean not null default false
);
create index if not exists baro_mesajlar_zaman on oyun.baro_mesajlar(id desc) where not silindi;
create table if not exists oyun.baro_secimler(
 id bigserial primary key,
 donem text not null unique,
 aday_bas timestamptz not null,
 oy_bas timestamptz not null,
 oy_son timestamptz not null,
 durum text not null default 'aday' check(durum in ('aday','oy','bitti','iptal')),
 kazanan uuid references oyun.profiller(id),
 katilim int not null default 0,
 sonuc jsonb not null default '[]'::jsonb
);
create table if not exists oyun.baro_adaylar(
 secim_id bigint not null references oyun.baro_secimler(id),
 user_id uuid not null references oyun.profiller(id),
 vaat text not null default '' check(char_length(vaat)<=600),
 cekildi boolean not null default false,
 zaman timestamptz not null default now(),
 primary key(secim_id,user_id)
);
create table if not exists oyun.baro_oylar(
 secim_id bigint not null references oyun.baro_secimler(id),
 secmen uuid not null references oyun.profiller(id),
 aday uuid not null references oyun.profiller(id),
 zaman timestamptz not null default now(),
 primary key(secim_id,secmen)
);
create table if not exists oyun.baro_adli_yardim(
 id bigserial primary key,
 dava_id bigint not null references oyun.adliye_davalar(id),
 taraf text not null check(taraf in ('davaci','davali')),
 talep_eden uuid not null references oyun.profiller(id),
 gerekce text not null default '',
 durum text not null default 'bekliyor' check(durum in ('bekliyor','atandi','ret','iptal')),
 avukat_id uuid references oyun.profiller(id),
 ucret numeric not null default 0,
 karar_veren uuid references oyun.profiller(id),
 karar_gerekce text,
 zaman timestamptz not null default now(),
 karar_at timestamptz
);
create unique index if not exists baro_adli_yardim_tek on oyun.baro_adli_yardim(dava_id,taraf) where durum='bekliyor';
create table if not exists oyun.baro_disiplin(
 id bigserial primary key,
 avukat_id uuid not null references oyun.profiller(id),
 sikayetci uuid not null references oyun.profiller(id),
 dava_id bigint references oyun.adliye_davalar(id),
 metin text not null check(char_length(metin) between 30 and 1500),
 durum text not null default 'bekliyor' check(durum in ('bekliyor','karar')),
 ceza text check(ceza in ('ret','uyari','kinama','isten_yasak_3','isten_yasak_7')),
 bitis timestamptz,
 karar_gerekce text,
 karar_veren uuid references oyun.profiller(id),
 zaman timestamptz not null default now(),
 karar_at timestamptz
);
create unique index if not exists baro_disiplin_tek_bekleyen on oyun.baro_disiplin(avukat_id,sikayetci) where durum='bekliyor';

do $guard$
declare t text;
begin
 foreach t in array array['avukat_ruhsat_gecmis','baro','baro_uyeleri','baro_kasa_hareket','baro_mesajlar','baro_secimler','baro_adaylar','baro_oylar','baro_adli_yardim','baro_disiplin'] loop
  execute format('alter table oyun.%I enable row level security',t);
  execute format('revoke all on oyun.%I from public, anon, authenticated',t);
 end loop;
 revoke all on sequence oyun.baro_sicil_seq from public, anon, authenticated;
end $guard$;

-- ---------------------------------------------------------------- 3) Yardımcılar
create or replace function oyun.avukat_kontenjan() returns integer language sql stable set search_path='' as $f$
 select coalesce(a.avukat_kontenjan_elle,
  greatest(coalesce(a.avukat_min,2),
   ceil((select count(*) from oyun.profiller where not yasakli and son_gorulme>now()-interval '7 days')::numeric
        /greatest(coalesce(a.avukat_oran,10),1))::int))
 from oyun.ayarlar a where a.id=1
$f$;

create or replace function oyun.avukat_ruhsatli(u uuid) returns boolean language sql stable set search_path='' as $f$
 select exists(select 1 from oyun.avukat_ruhsat where user_id=u and durum='aktif')
$f$;

create or replace function oyun.baro_uyesi(u uuid) returns boolean language sql stable set search_path='' as $f$
 select exists(select 1 from oyun.baro_uyeleri where user_id=u and durum='aktif')
$f$;

create or replace function oyun.avukat_yasak_bitis(u uuid) returns timestamptz language sql stable set search_path='' as $f$
 select max(bitis) from oyun.baro_disiplin where avukat_id=u and durum='karar' and ceza like 'isten_yasak%' and bitis>now()
$f$;

-- Mesleği icra edebilir mi: ruhsat + baro levhası + disiplin yasağı yok
create or replace function oyun.avukat_mi(u uuid) returns boolean language sql stable set search_path='' as $f$
 select oyun.avukat_ruhsatli(u) and oyun.baro_uyesi(u) and oyun.avukat_yasak_bitis(u) is null
$f$;

create or replace function oyun.avukat_engel(u uuid) returns text language sql stable set search_path='' as $f$
 select case
  when not oyun.avukat_ruhsatli(u) then 'Avukatlık ruhsatın aktif değil.'
  when not oyun.baro_uyesi(u) then 'Mesleği icra etmek için Türkiye Barosu levhasına kayıtlı olmalısın (Adliye > Türkiye Barosu).'
  when oyun.avukat_yasak_bitis(u) is not null then 'Baro disiplin kararıyla '||to_char(oyun.avukat_yasak_bitis(u) at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI')||' tarihine kadar işten yasaklısın.'
 end
$f$;

create or replace function oyun.avukat_sira_uygun(u uuid) returns boolean language sql stable set search_path='' as $f$
 select exists(select 1 from oyun.profiller p where p.id=u and not p.yasakli and p.son_gorulme>now()-interval '7 days')
$f$;

-- Bekleme listesindeki gerçek sıra (pasif/engelli adaylar sırayı tıkamaz)
create or replace function oyun.avukat_sira_no(u uuid) returns integer language sql stable set search_path='' as $f$
 select (select count(*)::int from oyun.avukat_ruhsat x
         where x.durum='bekliyor' and x.siralama<=r.siralama and (x.user_id=u or oyun.avukat_sira_uygun(x.user_id)))
 from oyun.avukat_ruhsat r where r.user_id=u and r.durum='bekliyor'
$f$;

create or replace function oyun.avukat_gecmis(u uuid,p_olay text,p_aciklama text) returns void language sql set search_path='' as $f$
 insert into oyun.avukat_ruhsat_gecmis(user_id,olay,aciklama) values(u,p_olay,coalesce(p_aciklama,''))
$f$;

create or replace function oyun.baro_kasa(p_tutar numeric,p_tur text,p_aciklama text,p_user uuid default null) returns void language plpgsql set search_path='' as $f$
begin
 if coalesce(p_tutar,0)=0 then return; end if;
 update oyun.baro set kasa=kasa+round(p_tutar) where id=1 and kasa+round(p_tutar)>=0;
 if not found then raise exception 'Baro kasasında yeterli para yok.'; end if;
 insert into oyun.baro_kasa_hareket(tutar,tur,aciklama,user_id) values(round(p_tutar),p_tur,left(coalesce(p_aciklama,''),300),p_user);
end $f$;

-- Avukat mesleği icra edemez hale gelince açık dosyalardaki vekâletleri biter, müvekkil yeni avukat tutabilir
create or replace function oyun.avukat_vekalet_kapat(u uuid,p_neden text) returns integer language plpgsql set search_path='' as $f$
declare v record; n int:=0;
begin
 for v in select x.id,x.dava_id,x.muvekkil from oyun.avukat_vekaletleri x join oyun.adliye_davalar d on d.id=x.dava_id
   where x.avukat_id=u and x.aktif and d.durum='acik'
 loop
  update oyun.avukat_vekaletleri set aktif=false,iptal_at=now() where id=v.id;
  perform oyun.bildir(v.muvekkil,format('Dava #%s vekiliniz Av. %s bu dosyada artık görev yapamıyor (%s). Yeni avukat tutabilir veya Baro''dan adli yardım isteyebilirsiniz.',v.dava_id,oyun.kad(u),p_neden),oyun.simdi());
  n:=n+1;
 end loop;
 update oyun.avukat_teklifleri set durum='iptal' where avukat_id=u and durum='bekliyor';
 return n;
end $f$;

create or replace function oyun.avukat_askiya_al(u uuid,p_neden text,p_aciklama text) returns void language plpgsql set search_path='' as $f$
begin
 update oyun.avukat_ruhsat set durum='askida',askida_at=now(),gerekce=p_neden where user_id=u and durum='aktif';
 if not found then return; end if;
 perform oyun.avukat_vekalet_kapat(u,p_aciklama);
 update oyun.baro_uyeleri set durum='ayrildi',cikis_at=now(),cikis_neden='ruhsat_aski' where user_id=u and durum='aktif';
 perform oyun.avukat_gecmis(u,'askida',p_aciklama);
end $f$;

create or replace function oyun.baro_baskan() returns uuid language sql stable set search_path='' as $f$
 select coalesce(
  (select b.baskan from oyun.baro b where b.id=1 and b.baskan is not null and oyun.baro_uyesi(b.baskan) and oyun.avukat_ruhsatli(b.baskan)),
  (select u.user_id from oyun.baro_uyeleri u where u.durum='aktif' and oyun.avukat_ruhsatli(u.user_id) order by u.sicil_no limit 1))
$f$;

create or replace function oyun.baro_baskan_secilmis() returns boolean language sql stable set search_path='' as $f$
 select exists(select 1 from oyun.baro b where b.id=1 and b.baskan is not null and oyun.baro_uyesi(b.baskan) and oyun.avukat_ruhsatli(b.baskan))
$f$;

-- Her denemede değişen 20 soruluk set (tohum: oyuncu + son sınav zamanı)
create or replace function oyun.hukuk_sinav_seti(u uuid) returns int[] language sql stable set search_path='' as $f$
 with t as (select coalesce((select son_sinav::text from oyun.hukuk_akademisi where user_id=u),'ilk') tohum)
 select coalesce(array_agg(s.id order by s.sira),'{}'::int[]) from (
  select q.id, md5(q.id::text||u::text||t.tohum) sira from oyun.hukuk_sorulari q, t order by 2 limit 20) s
$f$;

-- ---------------------------------------------------------------- 4) Motorlar (10 dakikada bir)
create or replace function oyun.avukat_sira_isle() returns integer language plpgsql set search_path='' as $f$
declare kota int; aktif int; r record; verilen int:=0; harc numeric:=100000; pay numeric; b oyun.baro;
begin
 perform pg_advisory_xact_lock(20261022,1);
 kota:=oyun.avukat_kontenjan();
 select count(*) into aktif from oyun.avukat_ruhsat where durum='aktif';
 if aktif>=kota then return 0; end if;
 select * into b from oyun.baro where id=1;
 for r in select x.user_id,x.harc_odendi,x.para_uyari_at from oyun.avukat_ruhsat x join oyun.profiller p on p.id=x.user_id
   where x.durum='bekliyor' and not p.yasakli and p.son_gorulme>now()-interval '7 days' order by x.siralama
 loop
  exit when aktif>=kota;
  if not r.harc_odendi then
   if coalesce((select c.para from oyun.cuzdan c where c.user_id=r.user_id),0)<harc then
    if r.para_uyari_at is null or r.para_uyari_at<now()-interval '24 hours' then
     perform oyun.bildir(r.user_id,format('Avukatlık kontenjanında yer açıldı ama ruhsat harcı için cüzdanında %s ₺ bulunmalı. Parayı tamamladığında boş kontenjanda ruhsatın kendiliğinden verilir; sıran korunur.',oyun.tl(harc)),oyun.simdi());
     update oyun.avukat_ruhsat set para_uyari_at=now() where user_id=r.user_id;
    end if;
    continue;
   end if;
   begin
    perform oyun.para_islem(r.user_id,-harc,'adliye','Avukatlık ruhsat harcı',oyun.simdi());
   exception when others then
    continue;
   end;
   pay:=round(harc*coalesce(b.ruhsat_pay,0));
   if pay>0 then perform oyun.baro_kasa(pay,'ruhsat_payi','Ruhsat harcından baro payı · '||oyun.kad(r.user_id),r.user_id); end if;
  end if;
  update oyun.avukat_ruhsat set durum='aktif',ruhsat_at=coalesce(ruhsat_at,now()),harc_odendi=true,askida_at=null,gerekce=null,para_uyari_at=null where user_id=r.user_id;
  perform oyun.avukat_gecmis(r.user_id,'aktif',case when r.harc_odendi then 'Ruhsat yeniden etkinleşti' else 'Kontenjana yerleşti, ruhsat verildi' end);
  -- Ruhsat askısı yüzünden düşen baro kaydı kendiliğinden geri açılır
  update oyun.baro_uyeleri set durum='aktif',kayit_at=now(),cikis_at=null,cikis_neden=null,aidat_bitis=greatest(aidat_bitis,now())
   where user_id=r.user_id and durum='ayrildi' and cikis_neden='ruhsat_aski';
  perform oyun.bildir(r.user_id,case when oyun.baro_uyesi(r.user_id)
    then 'Avukatlık ruhsatın yeniden etkinleşti ve baro kaydın geri açıldı. Dosya almaya başlayabilirsin.'
    else 'Tebrikler, avukatlık ruhsatın verildi! Mesleğe başlamak için Adliye > Türkiye Barosu bölümünden levhaya kaydol.' end,oyun.simdi());
  aktif:=aktif+1; verilen:=verilen+1;
 end loop;
 return verilen;
end $f$;

create or replace function oyun.avukat_pasif_isle() returns integer language plpgsql set search_path='' as $f$
declare r record; n int:=0; gun int;
begin
 select coalesce(avukat_pasif_gun,14) into gun from oyun.ayarlar where id=1;
 for r in select x.user_id,p.yasakli from oyun.avukat_ruhsat x join oyun.profiller p on p.id=x.user_id
   where x.durum='aktif' and (p.yasakli or coalesce(p.son_gorulme,p.olusturma)<now()-make_interval(days=>gun))
 loop
  if r.yasakli then
   perform oyun.avukat_askiya_al(r.user_id,'pasif','Hesap engeli nedeniyle ruhsat askıya alındı');
  else
   perform oyun.avukat_askiya_al(r.user_id,'pasif',format('%s gün oyuna girilmedi',gun));
   perform oyun.bildir(r.user_id,format('%s gündür oyuna girmediğin için avukatlık ruhsatın askıya alındı ve kontenjanın sıradaki adaya açıldı. Döndüğünde Adliye ekranından "Ruhsatımı yeniden etkinleştir" ile harç ödemeden yeniden sıraya girebilirsin.',gun),oyun.simdi());
  end if;
  n:=n+1;
 end loop;
 return n;
end $f$;

create or replace function oyun.baro_aidat_isle() returns integer language plpgsql set search_path='' as $f$
declare r record; b oyun.baro; n int:=0;
begin
 select * into b from oyun.baro where id=1;
 for r in select u.user_id,u.aidat_bitis,u.aidat_uyari_at from oyun.baro_uyeleri u where u.durum='aktif' and u.aidat_bitis<=now() for update of u
 loop
  if b.aidat<=0 then
   update oyun.baro_uyeleri set aidat_bitis=now()+interval '30 days' where user_id=r.user_id;
   continue;
  end if;
  if coalesce((select c.para from oyun.cuzdan c where c.user_id=r.user_id),0)>=b.aidat then
   begin
    perform oyun.para_islem(r.user_id,-b.aidat,'adliye','Türkiye Barosu aylık aidatı',oyun.simdi());
    perform oyun.baro_kasa(b.aidat,'aidat','Aylık aidat · '||oyun.kad(r.user_id),r.user_id);
    update oyun.baro_uyeleri set aidat_bitis=greatest(r.aidat_bitis,now()-interval '7 days')+interval '30 days',aidat_uyari_at=null where user_id=r.user_id;
    n:=n+1;
    continue;
   exception when others then
    null;
   end;
  end if;
  if r.aidat_bitis<=now()-interval '7 days' then
   update oyun.baro_uyeleri set durum='silindi',cikis_at=now(),cikis_neden='aidat' where user_id=r.user_id;
   perform oyun.avukat_vekalet_kapat(r.user_id,'aidat borcu nedeniyle levhadan silindi');
   perform oyun.avukat_gecmis(r.user_id,'baro_silindi','Aidat borcu nedeniyle levhadan silindi');
   perform oyun.bildir(r.user_id,'Aidat borcun 7 gün içinde ödenmediği için Türkiye Barosu levhasından silindin. Ruhsatın duruyor; yeniden kaydolarak mesleğe dönebilirsin.',oyun.simdi());
  elsif r.aidat_uyari_at is null or r.aidat_uyari_at<now()-interval '24 hours' then
   update oyun.baro_uyeleri set aidat_uyari_at=now() where user_id=r.user_id;
   perform oyun.bildir(r.user_id,format('Türkiye Barosu aylık aidatın (%s ₺) cüzdanından tahsil edilemedi. %s tarihine kadar ödenmezse levhadan silinirsin.',oyun.tl(b.aidat),to_char((r.aidat_bitis+interval '7 days') at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI')),oyun.simdi());
  end if;
 end loop;
 return n;
end $f$;

-- Başkanlık seçimi her ay: adaylık 15'i 00:00 → 20'si 10:00, oylama 20'si 10:00-20:00 (Türkiye saati)
create or replace function oyun.baro_secim_isle() returns void language plpgsql set search_path='' as $f$
declare yerel timestamp:=now() at time zone 'Europe/Istanbul';
 yil int:=extract(year from yerel)::int; ay int:=extract(month from yerel)::int;
 v_donem text:=to_char(yerel,'YYYY-MM'); s oyun.baro_secimler; kaz uuid; topl int; son jsonb;
 t_aday timestamptz; t_oy timestamptz; t_son timestamptz;
begin
 t_aday:=make_timestamptz(yil,ay,15,0,0,0,'Europe/Istanbul');
 t_oy:=make_timestamptz(yil,ay,20,10,0,0,'Europe/Istanbul');
 t_son:=make_timestamptz(yil,ay,20,20,0,0,'Europe/Istanbul');
 if now()>=t_aday and now()<t_oy and not exists(select 1 from oyun.baro_secimler where donem=v_donem) then
  insert into oyun.baro_secimler(donem,aday_bas,oy_bas,oy_son) values(v_donem,t_aday,t_oy,t_son);
  perform oyun.bildir(u.user_id,format('Türkiye Barosu başkanlık seçimi için adaylık açıldı. Adaylık %s 10:00''a kadar sürer; oylama aynı gün 10:00-20:00 arası.',to_char(t_oy at time zone 'Europe/Istanbul','DD.MM.YYYY')),oyun.simdi())
   from oyun.baro_uyeleri u where u.durum='aktif';
 end if;
 for s in select * from oyun.baro_secimler where durum in ('aday','oy') order by id for update loop
  if s.durum='aday' and now()>=s.oy_bas then
   if not exists(select 1 from oyun.baro_adaylar a where a.secim_id=s.id and not a.cekildi and oyun.baro_uyesi(a.user_id)) then
    update oyun.baro_secimler set durum='iptal' where id=s.id;
    perform oyun.bildir(u.user_id,'Baro başkanlığı seçimine aday çıkmadığı için seçim yapılamadı; mevcut başkanlık sürüyor.',oyun.simdi())
     from oyun.baro_uyeleri u where u.durum='aktif';
   else
    update oyun.baro_secimler set durum='oy' where id=s.id;
    perform oyun.bildir(u.user_id,'Türkiye Barosu başkanlık seçiminde oylama başladı (20:00''ye kadar). Adliye > Türkiye Barosu > Seçim bölümünden oyunu kullan.',oyun.simdi())
     from oyun.baro_uyeleri u where u.durum='aktif';
   end if;
  elsif s.durum='oy' and now()>=s.oy_son then
   with gecerli as (
    select o.aday from oyun.baro_oylar o join oyun.baro_uyeleri m on m.user_id=o.secmen and m.durum='aktif' where o.secim_id=s.id
   ), sayim as (
    select a.user_id,(select count(*) from gecerli g where g.aday=a.user_id)::int oy,u.sicil_no
    from oyun.baro_adaylar a join oyun.baro_uyeleri u on u.user_id=a.user_id and u.durum='aktif'
    where a.secim_id=s.id and not a.cekildi
   )
   select (select x.user_id from sayim x order by x.oy desc,x.sicil_no limit 1),
          (select coalesce(sum(x.oy),0)::int from sayim x),
          (select coalesce(jsonb_agg(jsonb_build_object('aday',oyun.kad(x.user_id),'oy',x.oy) order by x.oy desc,x.sicil_no),'[]'::jsonb) from sayim x)
   into kaz,topl,son;
   update oyun.baro_secimler set durum='bitti',kazanan=kaz,katilim=topl,sonuc=son where id=s.id;
   if kaz is not null then
    update oyun.baro set baskan=kaz,baskan_bas=now(),baskan_secim=s.id where id=1;
    perform oyun.avukat_gecmis(kaz,'baro_baskan','Türkiye Barosu başkanı seçildi');
    perform oyun.bildir(u.user_id,format('Türkiye Barosu seçimi sonuçlandı: Av. %s baro başkanı seçildi (%s oy).',oyun.kad(kaz),son->0->>'oy'),oyun.simdi())
     from oyun.baro_uyeleri u where u.durum='aktif';
   end if;
  end if;
 end loop;
end $f$;

create or replace function oyun.baro_tick() returns void language plpgsql set search_path='' as $f$
begin
 begin perform oyun.avukat_pasif_isle(); exception when others then raise warning 'avukat_pasif_isle: %',sqlerrm; end;
 begin perform oyun.avukat_sira_isle(); exception when others then raise warning 'avukat_sira_isle: %',sqlerrm; end;
 begin perform oyun.baro_aidat_isle(); exception when others then raise warning 'baro_aidat_isle: %',sqlerrm; end;
 begin perform oyun.baro_secim_isle(); exception when others then raise warning 'baro_secim_isle: %',sqlerrm; end;
end $f$;

-- ---------------------------------------------------------------- 5) Avukatlık API (mevcut adlar korunur)
create or replace function public.avukat_durum() returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.hukuk_akademisi; l oyun.avukat_ruhsat; ay oyun.ayarlar; bu oyun.baro_uyeleri; sset int[];
begin
 select * into a from oyun.hukuk_akademisi where user_id=p.id;
 select * into l from oyun.avukat_ruhsat where user_id=p.id;
 select * into ay from oyun.ayarlar where id=1;
 select * into bu from oyun.baro_uyeleri where user_id=p.id;
 if a.user_id is not null and a.baslangic+interval '24 hours'<=now() and a.sinav_gecildi is null then sset:=oyun.hukuk_sinav_seti(p.id); end if;
 return jsonb_build_object(
  'hesap_uygun',p.olusturma<=now()-interval '7 days',
  'yonetici',coalesce(p.yonetici,false),
  'harc',100000,
  'kontenjan',oyun.avukat_kontenjan(),
  'kontenjan_bilgi',jsonb_build_object('aktif_oyuncu',(select count(*) from oyun.profiller where not yasakli and son_gorulme>now()-interval '7 days'),
     'oran',ay.avukat_oran,'min',ay.avukat_min,'elle',ay.avukat_kontenjan_elle,'pasif_gun',ay.avukat_pasif_gun),
  'aktif_avukat',(select count(*) from oyun.avukat_ruhsat where durum='aktif'),
  'bekleyen',(select count(*) from oyun.avukat_ruhsat x where x.durum='bekliyor' and oyun.avukat_sira_uygun(x.user_id)),
  'bekleme_listesi',(select coalesce(jsonb_agg(jsonb_build_object('sira',q.rn,'kad',oyun.kad(q.user_id),'basvuru',q.basvuru_at,'benim',q.user_id=p.id) order by q.rn),'[]'::jsonb)
     from (select x.user_id,x.basvuru_at,row_number() over(order by x.siralama) rn from oyun.avukat_ruhsat x
           where x.durum='bekliyor' and (x.user_id=p.id or oyun.avukat_sira_uygun(x.user_id))) q where q.rn<=15 or q.user_id=p.id),
  'akademi',case when a.user_id is null then null else jsonb_build_object('baslangic',a.baslangic,'egitim_bitti',a.baslangic+interval '24 hours','sinav_gecildi',a.sinav_gecildi,'son_puan',a.son_puan,'pratik1',a.pratik1,'pratik2',a.pratik2,'son_sinav',a.son_sinav,'soru_sayi',20,'gecme',16) end,
  'ruhsat',case when l.user_id is null then null else jsonb_build_object('durum',l.durum,'sira',oyun.avukat_sira_no(p.id),'ruhsat_at',l.ruhsat_at,'gerekce',l.gerekce,'askida_at',l.askida_at,'harc_odendi',l.harc_odendi,'basvuru_at',l.basvuru_at) end,
  'calisabilir',oyun.avukat_mi(p.id),
  'engel',case when oyun.avukat_ruhsatli(p.id) then oyun.avukat_engel(p.id) end,
  'baro',jsonb_build_object('uyeyim',coalesce(bu.durum='aktif',false),'durum',bu.durum,'sicil',bu.sicil_no,'cikis_neden',bu.cikis_neden,'yasak_bitis',oyun.avukat_yasak_bitis(p.id)),
  'sinav_sorular',case when sset is null then '[]'::jsonb else
    (select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'soru',q.soru,'secenekler',q.secenekler) order by array_position(sset,q.id)),'[]'::jsonb) from oyun.hukuk_sorulari q where q.id=any(sset)) end,
  'uygulamalar',case when a.sinav_gecildi is not null then jsonb_build_array(
    jsonb_build_object('id',1,'soru','Müvekkilin, karşı tarafın sözleşmeyi ihlal ettiğini söylüyor. İlk ne yaparsın?','secenekler',jsonb_build_array('Karşı tarafı tehdit ederim','Sözleşme ve ödeme kayıtlarını toplarım','Davayı kazandık diye duyururum','Delil uydururum')),
    jsonb_build_object('id',2,'soru','Aynı davada karşı taraf da seni avukat olarak tutmak istiyor. Ne yaparsın?','secenekler',jsonb_build_array('İki taraftan da ücret alırım','Yalnız daha çok ödeyenle anlaşırım','Çıkar çatışması nedeniyle reddederim','Dava kaydını sildiririm')))
   else '[]'::jsonb end,
  'avukatlar',(select coalesce(jsonb_agg(jsonb_build_object('id',r.user_id,'kad',oyun.kad(r.user_id),
     'burosu',(select b.ad from oyun.hukuk_buro_uyeleri y join oyun.hukuk_burolari b on b.id=y.buro_id where y.avukat_id=r.user_id and y.durum='aktif' and b.aktif limit 1),
     'sicil',(select u.sicil_no from oyun.baro_uyeleri u where u.user_id=r.user_id and u.durum='aktif'),
     'calisabilir',oyun.avukat_mi(r.user_id),'ruhsat_at',r.ruhsat_at,
     'tamamlanan',coalesce(st.toplam,0),'kazanilan',coalesce(st.kazanc,0),
     'oran',case when coalesce(st.toplam,0)=0 then null else round(st.kazanc*100.0/st.toplam,1) end,
     'disiplin',(select jsonb_build_object('uyari',count(*) filter(where dd.ceza='uyari'),'kinama',count(*) filter(where dd.ceza='kinama'),'yasak',count(*) filter(where dd.ceza like 'isten_yasak%')) from oyun.baro_disiplin dd where dd.avukat_id=r.user_id and dd.durum='karar')
    ) order by oyun.kad(r.user_id)),'[]'::jsonb)
   from oyun.avukat_ruhsat r left join lateral (
    select count(*) toplam,count(*) filter(where (v.taraf='davaci' and d.karar not in ('beraat','dusme')) or (v.taraf='davali' and d.karar='beraat')) kazanc
    from oyun.avukat_vekaletleri v join oyun.adliye_davalar d on d.id=v.dava_id
    where v.avukat_id=r.user_id and v.tarih<=d.karar_at and (v.iptal_at is null or v.iptal_at>=d.karar_at) and d.kesin and d.durum='karar' and d.karar<>'dusme' and d.af_at is null
   ) st on true where r.durum='aktif'),
  'burolar',(select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'ad',b.ad,'kurucu',oyun.kad(b.kurucu),'sehir',i.ad,'uye_sayi',(select count(*) from oyun.hukuk_buro_uyeleri u where u.buro_id=b.id and u.durum='aktif')) order by b.id desc),'[]'::jsonb) from oyun.hukuk_burolari b join oyun.iller i on i.id=b.sehir where b.aktif),
  'benim_burom',(select jsonb_build_object('id',b.id,'ad',b.ad) from oyun.hukuk_burolari b where b.kurucu=p.id and b.aktif limit 1),
  'gecmis',(select coalesce(jsonb_agg(jsonb_build_object('olay',g.olay,'aciklama',g.aciklama,'zaman',g.zaman) order by g.id desc),'[]'::jsonb) from (select * from oyun.avukat_ruhsat_gecmis where user_id=p.id order by id desc limit 12) g)
 );
end $f$;

create or replace function public.avukat_sinav_gonder(p_cevaplar jsonb) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.hukuk_akademisi; puan int; sset int[]; adet int;
begin
 select * into a from oyun.hukuk_akademisi where user_id=p.id for update;
 if a.user_id is null or a.baslangic+interval '24 hours'>now() then raise exception '24 saatlik hukuk eğitimini tamamlayın.'; end if;
 if a.sinav_gecildi is not null then raise exception 'Sınavı zaten geçtiniz.'; end if;
 if a.son_sinav>now()-interval '24 hours' then raise exception 'Yeniden sınav için 24 saat bekleyin.'; end if;
 if jsonb_typeof(p_cevaplar)<>'object' then raise exception 'Cevapları gönderin.'; end if;
 sset:=oyun.hukuk_sinav_seti(p.id); adet:=coalesce(array_length(sset,1),0);
 if exists(select 1 from unnest(sset) i where not (p_cevaplar ? i::text) or (p_cevaplar->>i::text) not in ('1','2','3','4')) then
  raise exception 'Soru seti yenilenmiş veya eksik cevap var; sınavı yeniden açıp % sorunun tamamını cevaplayın.',adet;
 end if;
 select count(*) into puan from oyun.hukuk_sorulari q where q.id=any(sset) and (p_cevaplar->>q.id::text)=q.dogru::text;
 update oyun.hukuk_akademisi set son_sinav=now(),son_puan=puan,sinav_gecildi=case when puan>=16 then now() else null end where user_id=p.id;
 perform oyun.avukat_gecmis(p.id,'sinav',format('Hukuk sınavı: %s/%s · %s',puan,adet,case when puan>=16 then 'başarılı' else 'başarısız' end));
 return jsonb_build_object('puan',puan,'gecti',puan>=16,'toplam',adet,
  'yanlislar',(select coalesce(jsonb_agg(q.soru order by array_position(sset,q.id)),'[]'::jsonb) from oyun.hukuk_sorulari q where q.id=any(sset) and (p_cevaplar->>q.id::text)<>q.dogru::text));
end $f$;

create or replace function public.avukat_ruhsat_basvur() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.hukuk_akademisi; l oyun.avukat_ruhsat;
begin
 select * into a from oyun.hukuk_akademisi where user_id=p.id;
 if a.sinav_gecildi is null or a.pratik1 is null or a.pratik2 is null then raise exception 'Sınav ve iki uygulamalı staj dosyası tamamlanmalı.'; end if;
 select * into l from oyun.avukat_ruhsat where user_id=p.id;
 if l.durum='askida' and coalesce(l.gerekce,'') in ('pasif','istek') then raise exception 'Ruhsatın askıda. "Ruhsatımı yeniden etkinleştir" düğmesini kullan.'; end if;
 if l.durum in ('askida','iptal') then raise exception 'Ruhsatın askıda veya iptal edilmiş.'; end if;
 if l.user_id is null then
  insert into oyun.avukat_ruhsat(user_id) values(p.id) on conflict do nothing;
  perform oyun.avukat_gecmis(p.id,'basvuru','Ruhsat başvurusu yapıldı, bekleme listesine girildi');
 end if;
 perform oyun.avukat_sira_isle();
 select * into l from oyun.avukat_ruhsat where user_id=p.id;
 return jsonb_build_object('durum',l.durum,'sira',oyun.avukat_sira_no(p.id),'kontenjan',oyun.avukat_kontenjan(),
  'neden',case when l.durum<>'bekliyor' then null
               when coalesce((select c.para from oyun.cuzdan c where c.user_id=p.id),0)<100000 then 'harc' else 'kontenjan' end);
end $f$;

create or replace function public.avukat_ruhsat_yenile() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); l oyun.avukat_ruhsat;
begin
 select * into l from oyun.avukat_ruhsat where user_id=p.id for update;
 if l.user_id is null or l.durum<>'askida' or coalesce(l.gerekce,'') not in ('pasif','istek') then raise exception 'Yeniden etkinleştirilecek askıda bir ruhsatın yok.'; end if;
 update oyun.avukat_ruhsat set durum='bekliyor',siralama=nextval('oyun.avukat_ruhsat_siralama_seq'),basvuru_at=now(),para_uyari_at=null where user_id=p.id;
 perform oyun.avukat_gecmis(p.id,'yenileme','Ruhsatın yeniden etkinleştirilmesi istendi (harç alınmaz)');
 perform oyun.avukat_sira_isle();
 select * into l from oyun.avukat_ruhsat where user_id=p.id;
 return jsonb_build_object('durum',l.durum,'sira',oyun.avukat_sira_no(p.id));
end $f$;

create or replace function public.avukat_ruhsat_birak() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 if not oyun.avukat_ruhsatli(p.id) then raise exception 'Aktif ruhsatın yok.'; end if;
 perform oyun.avukat_askiya_al(p.id,'istek','Avukat ruhsatını kendi isteğiyle askıya aldı');
 perform oyun.avukat_sira_isle();
 return jsonb_build_object('tamam',true);
end $f$;

create or replace function public.avukat_kontenjan_ayarla(p_elle int default null,p_oran int default null,p_min int default null,p_pasif_gun int default null) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 if not coalesce(p.yonetici,false) then raise exception 'Bu ayar yalnız yöneticiye açık.'; end if;
 if p_elle is not null and p_elle not between 0 and 1000 then raise exception 'Sabit kontenjan 0-1000 olmalı.'; end if;
 if p_oran is not null and p_oran not between 1 and 1000 then raise exception 'Oran 1-1000 olmalı.'; end if;
 if p_min is not null and p_min not between 0 and 1000 then raise exception 'Asgari kontenjan 0-1000 olmalı.'; end if;
 if p_pasif_gun is not null and p_pasif_gun not between 3 and 365 then raise exception 'Pasiflik süresi 3-365 gün olmalı.'; end if;
 update oyun.ayarlar set avukat_kontenjan_elle=p_elle,avukat_oran=coalesce(p_oran,avukat_oran),avukat_min=coalesce(p_min,avukat_min),avukat_pasif_gun=coalesce(p_pasif_gun,avukat_pasif_gun) where id=1;
 perform oyun.avukat_sira_isle();
 return jsonb_build_object('kontenjan',oyun.avukat_kontenjan());
end $f$;

create or replace function public.avukat_teklif_ver(p_dava bigint,p_taraf text,p_tutar numeric,p_prim numeric default 0,p_aciklama text default '') returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; tid bigint; engel text; muv uuid;
begin
 engel:=oyun.avukat_engel(p.id);
 if engel is not null then raise exception '%',engel; end if;
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null or d.durum<>'acik' then raise exception 'Açık dava bulunamadı.'; end if;
 if p_taraf not in ('davaci','davali') or p_tutar is null or p_tutar<0 or p_tutar>1000000000000 then raise exception 'Teklif bilgileri geçersiz.'; end if;
 if p_prim is null or p_prim<0 or p_prim>25 then raise exception 'Başarı primi %%0 ile %%25 arasında olmalı (Avukatlık Kanunu m.164).'; end if;
 muv:=case when p_taraf='davaci' then coalesce(d.davaci,(select gb from oyun.partiler where id=d.davaci_parti))
           else coalesce(d.davali,(select gb from oyun.partiler where id=d.davali_parti)) end;
 if muv is null then raise exception 'Bu tarafta avukat tutabilecek bir oyuncu yok.'; end if;
 if p.id in (d.davaci,d.davali) or p.id=muv then raise exception 'Kendi davanızda avukatlık yapamazsınız.'; end if;
 if exists(select 1 from oyun.mahkeme_uye where user_id=p.id) then raise exception 'Yargıç avukatlık yapamaz.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=p_dava and avukat_id=p.id and aktif) then raise exception 'Bu davada zaten vekilsiniz.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=p_dava and taraf=p_taraf and aktif) then raise exception 'Bu tarafın aktif avukatı var.'; end if;
 if exists(select 1 from oyun.avukat_teklifleri where dava_id=p_dava and avukat_id=p.id and taraf=p_taraf and durum='bekliyor') then raise exception 'Bu taraf için bekleyen bir teklifin zaten var.'; end if;
 insert into oyun.avukat_teklifleri(dava_id,avukat_id,taraf,tutar,prim_orani,aciklama)
 values(p_dava,p.id,p_taraf,round(p_tutar),p_prim,left(trim(coalesce(p_aciklama,'')),500)) returning id into tid;
 perform oyun.bildir(muv,format('Adliye #%s için Av. %s teklif verdi: %s ₺, başarı primi %%%s.',p_dava,p.kad,oyun.tl(round(p_tutar)),p_prim),oyun.simdi());
 return jsonb_build_object('tamam',true,'id',tid);
end $f$;

create or replace function public.avukat_karsi_teklif(p_teklif bigint,p_tutar numeric,p_prim numeric) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t oyun.avukat_teklifleri; d oyun.adliye_davalar; yetki boolean;
begin
 select * into t from oyun.avukat_teklifleri where id=p_teklif for update;
 if t.id is null or t.durum<>'bekliyor' then raise exception 'Teklif kapandı.'; end if;
 select * into d from oyun.adliye_davalar where id=t.dava_id;
 if d.durum<>'acik' then raise exception 'Dava kapandı.'; end if;
 yetki:=case when t.taraf='davaci' then (d.davaci=p.id or exists(select 1 from oyun.partiler where id=d.davaci_parti and gb=p.id))
  else (d.davali=p.id or exists(select 1 from oyun.partiler where id=d.davali_parti and gb=p.id)) end;
 if not yetki then raise exception 'Bu davada müvekkil yetkiniz yok.'; end if;
 if p_tutar is null or p_tutar<0 or p_tutar>1000000000000 then raise exception 'Karşı teklif geçersiz.'; end if;
 if p_prim is null or p_prim<0 or p_prim>25 then raise exception 'Başarı primi %%0 ile %%25 arasında olmalı (Avukatlık Kanunu m.164).'; end if;
 insert into oyun.avukat_pazarlik(teklif_id,muvekkil,tutar,prim) values(t.id,p.id,round(p_tutar),p_prim)
 on conflict(teklif_id) do update set muvekkil=excluded.muvekkil,tutar=excluded.tutar,prim=excluded.prim,durum='bekliyor',zaman=now();
 perform oyun.bildir(t.avukat_id,format('Dava #%s için müvekkil karşı teklif sundu: %s ₺, prim %%%s. Dava dosyasından yanıtla.',d.id,oyun.tl(round(p_tutar)),p_prim),oyun.simdi());
 return jsonb_build_object('tamam',true);
end $f$;

-- ---------------------------------------------------------------- 6) Baro API
create or replace function public.baro_durum() returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); b oyun.baro; bu oyun.baro_uyeleri; uye boolean; ic boolean; bas uuid; se oyun.baro_secimler;
 ozet jsonb; yerel timestamp:=now() at time zone 'Europe/Istanbul'; sonraki timestamptz;
begin
 select * into b from oyun.baro where id=1;
 select * into bu from oyun.baro_uyeleri where user_id=p.id;
 bas:=oyun.baro_baskan();
 uye:=coalesce(bu.durum='aktif',false);
 ic:=uye or coalesce(p.yonetici,false);
 select * into se from oyun.baro_secimler order by id desc limit 1;
 sonraki:=(date_trunc('month',yerel)+interval '19 days 10 hours') at time zone 'Europe/Istanbul';
 if now()>=sonraki+interval '10 hours' then sonraki:=(date_trunc('month',yerel)+interval '1 month 19 days 10 hours') at time zone 'Europe/Istanbul'; end if;
 ozet:=jsonb_build_object(
  'ad',b.ad,'kurulus',b.kurulus,
  'uye_sayi',(select count(*) from oyun.baro_uyeleri where durum='aktif'),
  'baskan',oyun.kad(bas),'baskan_id',bas,'gecici',bas is not null and not oyun.baro_baskan_secilmis(),'baskan_bas',b.baskan_bas,
  'giris_ucret',b.giris_ucret,'aidat',b.aidat,
  'uyeyim',uye,'benim_durum',bu.durum,'cikis_neden',bu.cikis_neden,
  'ruhsatliyim',oyun.avukat_ruhsatli(p.id),
  'kayit_olabilir',oyun.avukat_ruhsatli(p.id) and not uye,
  'icerde',ic,'gozlemci',ic and not uye,
  'baskanim',bas is not distinct from p.id and uye,
  'sonraki_secim',sonraki
 );
 if not ic then return ozet; end if;
 return ozet||jsonb_build_object(
  'kasa',b.kasa,'adli_yardim_ucret',b.adli_yardim_ucret,'adli_yardim_sinir',b.adli_yardim_sinir,
  'ben',case when uye then jsonb_build_object('sicil',bu.sicil_no,'kayit',bu.kayit_at,'ilk_kayit',bu.ilk_kayit,'aidat_bitis',bu.aidat_bitis,'gonullu',bu.gonullu,'calisabilir',oyun.avukat_mi(p.id),'engel',oyun.avukat_engel(p.id)) end,
  'duyurular',(select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'yazar',oyun.kad(m.yazar),'metin',m.metin,'zaman',m.zaman,
      'silebilirim',m.yazar=p.id or bas is not distinct from p.id or coalesce(p.yonetici,false)) order by m.id desc),'[]'::jsonb)
     from (select * from oyun.baro_mesajlar where duyuru and not silindi order by id desc limit 10) m),
  'mesajlar',(select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'yazar',oyun.kad(m.yazar),'benim',m.yazar=p.id,'metin',m.metin,'zaman',m.zaman,
      'silebilirim',m.yazar=p.id or bas is not distinct from p.id or coalesce(p.yonetici,false)) order by m.id desc),'[]'::jsonb)
     from (select * from oyun.baro_mesajlar where not duyuru and not silindi order by id desc limit 60) m),
  'levha',(select coalesce(jsonb_agg(jsonb_build_object('id',u.user_id,'kad',oyun.kad(u.user_id),'sicil',u.sicil_no,'kayit',u.ilk_kayit,'gonullu',u.gonullu,'baskan',u.user_id=bas,
      'burosu',(select hb.ad from oyun.hukuk_buro_uyeleri y join oyun.hukuk_burolari hb on hb.id=y.buro_id where y.avukat_id=u.user_id and y.durum='aktif' and hb.aktif limit 1),
      'il',(select i.ad from oyun.profiller pp join oyun.iller i on i.id=pp.il_id where pp.id=u.user_id),
      'aktif_dosya',(select count(*) from oyun.avukat_vekaletleri v join oyun.adliye_davalar d on d.id=v.dava_id where v.avukat_id=u.user_id and v.aktif and d.durum='acik'),
      'yasak_bitis',oyun.avukat_yasak_bitis(u.user_id),
      'disiplin',(select jsonb_build_object('uyari',count(*) filter(where dd.ceza='uyari'),'kinama',count(*) filter(where dd.ceza='kinama'),'yasak',count(*) filter(where dd.ceza like 'isten_yasak%')) from oyun.baro_disiplin dd where dd.avukat_id=u.user_id and dd.durum='karar')
     ) order by u.sicil_no),'[]'::jsonb) from oyun.baro_uyeleri u where u.durum='aktif'),
  'bekleyen_davalar',(select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'tur',d.tur,
      'davaci',coalesce((select pa.ad from oyun.partiler pa where pa.id=d.davaci_parti),oyun.kad(d.davaci)),
      'davali',coalesce(oyun.kad(d.davali),(select pa.ad from oyun.partiler pa where pa.id=d.davali_parti),d.davali_kurum_ad),
      'davaci_bos',not exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.taraf='davaci' and v.aktif),
      'davali_bos',(d.davali is not null or d.davali_parti is not null) and not exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.taraf='davali' and v.aktif),
      'teklif',(select count(*) from oyun.avukat_teklifleri t where t.dava_id=d.id and t.durum='bekliyor'),
      'adli_yardim',exists(select 1 from oyun.baro_adli_yardim y where y.dava_id=d.id and y.durum='bekliyor'),
      'taraf_miyim',p.id in (d.davaci,d.davali),
      'savunma_son',d.savunma_son,'acilis',d.acilis) order by d.id desc),'[]'::jsonb)
     from oyun.adliye_davalar d where d.durum='acik' and (
      not exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.taraf='davaci' and v.aktif)
      or ((d.davali is not null or d.davali_parti is not null) and not exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.taraf='davali' and v.aktif)))),
  'adli_yardim',(select coalesce(jsonb_agg(jsonb_build_object('id',y.id,'dava',y.dava_id,'taraf',y.taraf,'talep_eden',oyun.kad(y.talep_eden),'gerekce',y.gerekce,'durum',y.durum,
      'avukat',oyun.kad(y.avukat_id),'ucret',y.ucret,'karar_gerekce',y.karar_gerekce,'zaman',y.zaman,'karar_at',y.karar_at) order by (y.durum='bekliyor') desc,y.id desc),'[]'::jsonb)
     from (select * from oyun.baro_adli_yardim order by id desc limit 40) y),
  'gonulluler',(select coalesce(jsonb_agg(jsonb_build_object('id',u.user_id,'kad',oyun.kad(u.user_id),'baskan',u.user_id=bas) order by u.sicil_no),'[]'::jsonb)
     from oyun.baro_uyeleri u where u.durum='aktif' and (u.gonullu or u.user_id=bas) and oyun.avukat_mi(u.user_id)),
  'disiplin',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'avukat',oyun.kad(x.avukat_id),'avukat_id',x.avukat_id,'durum',x.durum,'ceza',x.ceza,'bitis',x.bitis,
      'karar_gerekce',x.karar_gerekce,'zaman',x.zaman,'karar_at',x.karar_at,'dava',x.dava_id,
      'metin',case when bas is not distinct from p.id or coalesce(p.yonetici,false) or x.avukat_id=p.id then x.metin end,
      'sikayetci',case when bas is not distinct from p.id or coalesce(p.yonetici,false) then oyun.kad(x.sikayetci) end,
      'karar_verebilirim',x.durum='bekliyor' and ((bas is not distinct from p.id and x.avukat_id<>p.id) or coalesce(p.yonetici,false))
     ) order by (x.durum='bekliyor') desc,x.id desc),'[]'::jsonb)
     from (select * from oyun.baro_disiplin order by id desc limit 60) x
     where x.durum='karar' or bas is not distinct from p.id or coalesce(p.yonetici,false) or x.avukat_id=p.id),
  'secim',case when se.id is null then null else jsonb_build_object('id',se.id,'donem',se.donem,'durum',se.durum,'aday_bas',se.aday_bas,'oy_bas',se.oy_bas,'oy_son',se.oy_son,
      'kazanan',oyun.kad(se.kazanan),'katilim',se.katilim,'sonuc',se.sonuc,
      'adaylar',(select coalesce(jsonb_agg(jsonb_build_object('id',a.user_id,'kad',oyun.kad(a.user_id),'vaat',a.vaat,'benim',a.user_id=p.id) order by a.zaman),'[]'::jsonb)
         from oyun.baro_adaylar a where a.secim_id=se.id and not a.cekildi),
      'oyum',(select oyun.kad(o.aday) from oyun.baro_oylar o where o.secim_id=se.id and o.secmen=p.id),
      'oy_hakkim',uye and bu.kayit_at<se.oy_bas,
      'adayim',exists(select 1 from oyun.baro_adaylar a where a.secim_id=se.id and a.user_id=p.id and not a.cekildi)) end,
  'kasa_hareket',(select coalesce(jsonb_agg(jsonb_build_object('tutar',k.tutar,'tur',k.tur,'aciklama',k.aciklama,'zaman',k.zaman) order by k.id desc),'[]'::jsonb)
     from (select * from oyun.baro_kasa_hareket order by id desc limit 25) k)
 );
end $f$;

create or replace function public.baro_kaydol() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); b oyun.baro; bu oyun.baro_uyeleri;
begin
 if not oyun.avukat_ruhsatli(p.id) then raise exception 'Türkiye Barosu levhasına yalnız aktif ruhsatlı avukatlar kaydolabilir.'; end if;
 select * into b from oyun.baro where id=1 for update;
 select * into bu from oyun.baro_uyeleri where user_id=p.id for update;
 if bu.durum='aktif' then raise exception 'Zaten baro levhasına kayıtlısın.'; end if;
 if b.giris_ucret>0 then
  perform oyun.para_islem(p.id,-b.giris_ucret,'adliye','Türkiye Barosu giriş keseneği',oyun.simdi());
  perform oyun.baro_kasa(b.giris_ucret,'giris','Giriş keseneği · '||p.kad,p.id);
 end if;
 if bu.user_id is null then
  insert into oyun.baro_uyeleri(user_id) values(p.id) returning * into bu;
 else
  update oyun.baro_uyeleri set durum='aktif',kayit_at=now(),aidat_bitis=now()+interval '30 days',aidat_uyari_at=null,cikis_at=null,cikis_neden=null where user_id=p.id returning * into bu;
 end if;
 perform oyun.avukat_gecmis(p.id,'baro_kayit',format('Türkiye Barosu levhasına %s sicil numarasıyla kaydoldu',bu.sicil_no));
 return jsonb_build_object('tamam',true,'sicil',bu.sicil_no);
end $f$;

create or replace function public.baro_aidat_ode() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); b oyun.baro; bu oyun.baro_uyeleri;
begin
 select * into bu from oyun.baro_uyeleri where user_id=p.id and durum='aktif' for update;
 if bu.user_id is null then raise exception 'Baro levhasına kayıtlı değilsin.'; end if;
 select * into b from oyun.baro where id=1;
 if b.aidat<=0 then raise exception 'Şu anda aidat alınmıyor.'; end if;
 if bu.aidat_bitis>now()+interval '60 days' then raise exception 'En fazla 3 aylık aidat peşin ödenebilir.'; end if;
 perform oyun.para_islem(p.id,-b.aidat,'adliye','Türkiye Barosu aylık aidatı (peşin)',oyun.simdi());
 perform oyun.baro_kasa(b.aidat,'aidat','Peşin aidat · '||p.kad,p.id);
 update oyun.baro_uyeleri set aidat_bitis=greatest(aidat_bitis,now())+interval '30 days',aidat_uyari_at=null where user_id=p.id returning * into bu;
 return jsonb_build_object('aidat_bitis',bu.aidat_bitis);
end $f$;

create or replace function public.baro_gonullu(p_acik boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 update oyun.baro_uyeleri set gonullu=coalesce(p_acik,false) where user_id=p.id and durum='aktif';
 if not found then raise exception 'Baro levhasına kayıtlı değilsin.'; end if;
 return jsonb_build_object('gonullu',coalesce(p_acik,false));
end $f$;

create or replace function public.baro_ayril() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); n int;
begin
 update oyun.baro_uyeleri set durum='ayrildi',cikis_at=now(),cikis_neden='istek',gonullu=false where user_id=p.id and durum='aktif';
 if not found then raise exception 'Baro levhasına kayıtlı değilsin.'; end if;
 n:=oyun.avukat_vekalet_kapat(p.id,'avukat barodan ayrıldı');
 perform oyun.avukat_gecmis(p.id,'baro_ayrildi','Barodan kendi isteğiyle ayrıldı');
 return jsonb_build_object('tamam',true,'kapanan_vekalet',n);
end $f$;

create or replace function public.baro_mesaj_gonder(p_metin text,p_duyuru boolean default false) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); mid bigint; m text:=trim(coalesce(p_metin,'')); duy boolean:=coalesce(p_duyuru,false);
begin
 if not oyun.baro_uyesi(p.id) then raise exception 'Baro panosuna yalnız levhaya kayıtlı avukatlar yazabilir.'; end if;
 if char_length(m) not between 1 and 1000 then raise exception 'Mesaj 1-1000 karakter olmalı.'; end if;
 if coalesce(p.susturma_bitis,'-infinity'::timestamptz)>oyun.simdi() or coalesce(p.adliye_susturma_bitis,'-infinity'::timestamptz)>oyun.simdi() then raise exception 'Susturma cezan sürerken mesaj yazamazsın.'; end if;
 if duy and oyun.baro_baskan() is distinct from p.id then raise exception 'Duyuruyu yalnız baro başkanı yayımlayabilir.'; end if;
 if exists(select 1 from oyun.baro_mesajlar where yazar=p.id and zaman>now()-interval '8 seconds') then raise exception 'Yeni mesaj için birkaç saniye bekle.'; end if;
 insert into oyun.baro_mesajlar(yazar,metin,duyuru) values(p.id,m,duy) returning id into mid;
 if duy then
  perform oyun.bildir(u.user_id,'Türkiye Barosu duyurusu: '||left(m,140),oyun.simdi()) from oyun.baro_uyeleri u where u.durum='aktif' and u.user_id<>p.id;
 end if;
 return jsonb_build_object('id',mid);
end $f$;

create or replace function public.baro_mesaj_sil(p_mesaj bigint) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); m oyun.baro_mesajlar;
begin
 select * into m from oyun.baro_mesajlar where id=p_mesaj and not silindi for update;
 if m.id is null then raise exception 'Mesaj bulunamadı.'; end if;
 if not (m.yazar=p.id or (oyun.baro_baskan() is not distinct from p.id and oyun.baro_uyesi(p.id)) or coalesce(p.yonetici,false)) then raise exception 'Bu mesajı silme yetkin yok.'; end if;
 update oyun.baro_mesajlar set silindi=true where id=m.id;
 return jsonb_build_object('tamam',true);
end $f$;

create or replace function public.baro_aday_ol(p_vaat text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); se oyun.baro_secimler; v text:=trim(coalesce(p_vaat,''));
begin
 select * into se from oyun.baro_secimler where durum='aday' and now()<oy_bas order by id desc limit 1;
 if se.id is null then raise exception 'Şu anda adaylık dönemi açık değil. Adaylık her ayın 15''i ile 20''si 10:00 arasında açıktır.'; end if;
 if not oyun.avukat_mi(p.id) then raise exception 'Aday olmak için ruhsatı aktif, levhaya kayıtlı ve disiplin yasağı olmayan bir avukat olmalısın.'; end if;
 if char_length(v) not between 10 and 600 then raise exception 'Seçim vaadi 10-600 karakter olmalı.'; end if;
 insert into oyun.baro_adaylar(secim_id,user_id,vaat) values(se.id,p.id,v)
 on conflict(secim_id,user_id) do update set vaat=excluded.vaat,cekildi=false,zaman=now();
 return jsonb_build_object('tamam',true);
end $f$;

create or replace function public.baro_adaylik_cekil() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); se oyun.baro_secimler;
begin
 select * into se from oyun.baro_secimler where durum='aday' and now()<oy_bas order by id desc limit 1;
 if se.id is null then raise exception 'Adaylıktan yalnız adaylık döneminde çekilebilirsin.'; end if;
 update oyun.baro_adaylar set cekildi=true where secim_id=se.id and user_id=p.id and not cekildi;
 if not found then raise exception 'Bu seçimde aday değilsin.'; end if;
 return jsonb_build_object('tamam',true);
end $f$;

create or replace function public.baro_oy_ver(p_aday uuid) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); se oyun.baro_secimler; bu oyun.baro_uyeleri;
begin
 select * into se from oyun.baro_secimler where durum='oy' order by id desc limit 1 for update;
 if se.id is null or now()<se.oy_bas or now()>=se.oy_son then raise exception 'Şu anda baro seçiminde oylama açık değil.'; end if;
 select * into bu from oyun.baro_uyeleri where user_id=p.id and durum='aktif';
 if bu.user_id is null then raise exception 'Oy kullanmak için baro levhasına kayıtlı olmalısın.'; end if;
 if bu.kayit_at>=se.oy_bas then raise exception 'Oylama başladıktan sonra kaydolan üyeler bu seçimde oy kullanamaz.'; end if;
 if exists(select 1 from oyun.baro_oylar where secim_id=se.id and secmen=p.id) then raise exception 'Bu seçimde oyunu zaten kullandın.'; end if;
 if not exists(select 1 from oyun.baro_adaylar a where a.secim_id=se.id and a.user_id=p_aday and not a.cekildi and oyun.baro_uyesi(a.user_id)) then raise exception 'Aday bulunamadı.'; end if;
 insert into oyun.baro_oylar(secim_id,secmen,aday) values(se.id,p.id,p_aday);
 return jsonb_build_object('tamam',true);
end $f$;

create or replace function public.baro_adli_yardim_iste(p_dava bigint,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; tr text; b oyun.baro; para numeric; yid bigint; bas uuid;
begin
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null or d.durum<>'acik' then raise exception 'Açık dava bulunamadı.'; end if;
 tr:=case when d.davaci=p.id and d.davaci_parti is null then 'davaci' when d.davali=p.id then 'davali' end;
 if tr is null then raise exception 'Adli yardımı yalnız davanın kişisel tarafı (davacı ya da davalı) isteyebilir.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and taraf=tr and aktif) then raise exception 'Bu dosyada zaten avukatın var.'; end if;
 if exists(select 1 from oyun.baro_adli_yardim where dava_id=d.id and taraf=tr and durum='bekliyor') then raise exception 'Bu dosya için bekleyen bir adli yardım talebin var.'; end if;
 select * into b from oyun.baro where id=1;
 select c.para into para from oyun.cuzdan c where c.user_id=p.id;
 if coalesce(para,0)>=b.adli_yardim_sinir then raise exception 'Adli yardım yalnız cüzdanında % ₺''den az parası olanlara verilir.',oyun.tl(b.adli_yardim_sinir); end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 10 and 500 then raise exception 'Talep gerekçesi 10-500 karakter olmalı.'; end if;
 bas:=oyun.baro_baskan();
 if bas is null then raise exception 'Henüz baroya kayıtlı avukat olmadığı için adli yardım verilemiyor.'; end if;
 insert into oyun.baro_adli_yardim(dava_id,taraf,talep_eden,gerekce) values(d.id,tr,p.id,trim(p_gerekce)) returning id into yid;
 perform oyun.bildir(bas,format('Dava #%s için adli yardım talebi geldi. Türkiye Barosu > Davalar bölümünden avukat görevlendirebilirsin.',d.id),oyun.simdi());
 perform oyun.bildir(u.user_id,format('Dava #%s için adli yardım talebi var. Gönüllüysen baro başkanı seni görevlendirebilir.',d.id),oyun.simdi())
  from oyun.baro_uyeleri u where u.durum='aktif' and u.gonullu and u.user_id<>bas and u.user_id not in (coalesce(d.davaci,'00000000-0000-0000-0000-000000000000'::uuid),coalesce(d.davali,'00000000-0000-0000-0000-000000000000'::uuid));
 return jsonb_build_object('id',yid);
end $f$;

create or replace function public.baro_adli_yardim_karar(p_talep bigint,p_avukat uuid,p_gerekce text default '') returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); y oyun.baro_adli_yardim; d oyun.adliye_davalar; b oyun.baro; tid bigint; v_ucret numeric;
begin
 if oyun.baro_baskan() is distinct from p.id or not oyun.baro_uyesi(p.id) then raise exception 'Adli yardım görevlendirmesini yalnız baro başkanı yapar.'; end if;
 select * into y from oyun.baro_adli_yardim where id=p_talep for update;
 if y.id is null or y.durum<>'bekliyor' then raise exception 'Bekleyen talep bulunamadı.'; end if;
 select * into d from oyun.adliye_davalar where id=y.dava_id for update;
 if p_avukat is null then
  if char_length(trim(coalesce(p_gerekce,'')))<10 then raise exception 'Ret gerekçesi en az 10 karakter olmalı.'; end if;
  update oyun.baro_adli_yardim set durum='ret',karar_veren=p.id,karar_gerekce=left(trim(p_gerekce),500),karar_at=now() where id=y.id;
  perform oyun.bildir(y.talep_eden,format('Dava #%s adli yardım talebin reddedildi: %s',y.dava_id,left(trim(p_gerekce),200)),oyun.simdi());
  return jsonb_build_object('durum','ret');
 end if;
 if d.durum<>'acik' then
  update oyun.baro_adli_yardim set durum='iptal',karar_veren=p.id,karar_gerekce='Dava kapandığı için düştü',karar_at=now() where id=y.id;
  return jsonb_build_object('durum','iptal');
 end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and taraf=y.taraf and aktif) then
  update oyun.baro_adli_yardim set durum='iptal',karar_veren=p.id,karar_gerekce='Taraf bu arada avukat tuttu',karar_at=now() where id=y.id;
  return jsonb_build_object('durum','iptal');
 end if;
 if not oyun.avukat_mi(p_avukat) then raise exception 'Seçilen avukat şu anda mesleği icra edemiyor.'; end if;
 if p_avukat<>p.id and not exists(select 1 from oyun.baro_uyeleri where user_id=p_avukat and gonullu and durum='aktif') then raise exception 'Yalnız adli yardım gönüllüsü avukatlar ya da başkanın kendisi görevlendirilebilir.'; end if;
 if p_avukat in (d.davaci,d.davali) then raise exception 'Davanın tarafı olan avukat görevlendirilemez.'; end if;
 if exists(select 1 from oyun.mahkeme_uye where user_id=p_avukat) then raise exception 'Yargıç avukatlık yapamaz.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and aktif and avukat_id=p_avukat) then raise exception 'Bu avukat bu davada karşı tarafın vekili.'; end if;
 select * into b from oyun.baro where id=1 for update;
 v_ucret:=case when p_avukat=p.id then 0 else b.adli_yardim_ucret end;  -- başkan kendine ücret ödeyemez
 if b.kasa<v_ucret then raise exception 'Baro kasasında adli yardım ücreti için yeterli para yok (% ₺ gerekli).',oyun.tl(v_ucret); end if;
 insert into oyun.avukat_teklifleri(dava_id,avukat_id,taraf,tutar,prim_orani,aciklama,durum,kabul_at)
 values(d.id,p_avukat,y.taraf,0,0,'Türkiye Barosu adli yardım görevlendirmesi','kabul',now()) returning id into tid;
 insert into oyun.avukat_vekaletleri(teklif_id,dava_id,avukat_id,muvekkil,taraf,ucret,prim_orani) values(tid,d.id,p_avukat,y.talep_eden,y.taraf,0,0);
 update oyun.avukat_teklifleri set durum='iptal' where dava_id=d.id and taraf=y.taraf and id<>tid and durum='bekliyor';
 if v_ucret>0 then
  perform oyun.baro_kasa(-v_ucret,'adli_yardim',format('Dava #%s adli yardım ücreti · Av. %s',d.id,oyun.kad(p_avukat)),p_avukat);
  perform oyun.para_islem(p_avukat,v_ucret,'adliye',format('Dava #%s Baro adli yardım ücreti',d.id),oyun.simdi());
 end if;
 update oyun.baro_adli_yardim set durum='atandi',avukat_id=p_avukat,ucret=v_ucret,karar_veren=p.id,karar_gerekce=nullif(left(trim(coalesce(p_gerekce,'')),500),''),karar_at=now() where id=y.id;
 perform oyun.bildir(y.talep_eden,format('Dava #%s için Baro adli yardım kapsamında Av. %s ücretsiz vekiliniz olarak görevlendirildi.',d.id,oyun.kad(p_avukat)),oyun.simdi());
 if p_avukat<>p.id then
  perform oyun.bildir(p_avukat,format('Baro başkanı seni Dava #%s için adli yardım avukatı olarak görevlendirdi. %s ₺ ücretin baro kasasından ödendi.',d.id,oyun.tl(v_ucret)),oyun.simdi());
 end if;
 return jsonb_build_object('durum','atandi','ucret',v_ucret);
end $f$;

create or replace function public.baro_sikayet_et(p_avukat uuid,p_dava bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; sid bigint; bas uuid;
begin
 if p_avukat=p.id then raise exception 'Kendini şikâyet edemezsin.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null then raise exception 'Dava bulunamadı.'; end if;
 if not exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.avukat_id=p_avukat) then raise exception 'Bu avukat bu dosyada vekil olmamış.'; end if;
 if not (p.id in (d.davaci,d.davali) or exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.muvekkil=p.id)
         or exists(select 1 from oyun.partiler pa where pa.id in (d.davaci_parti,d.davali_parti) and pa.gb=p.id)) then
  raise exception 'Yalnız dosyanın tarafları veya müvekkiller şikâyette bulunabilir.';
 end if;
 if char_length(trim(coalesce(p_metin,''))) not between 30 and 1500 then raise exception 'Şikâyet metni 30-1500 karakter olmalı.'; end if;
 if exists(select 1 from oyun.baro_disiplin where avukat_id=p_avukat and sikayetci=p.id and durum='bekliyor') then raise exception 'Bu avukat hakkında bekleyen bir şikâyetin zaten var.'; end if;
 insert into oyun.baro_disiplin(avukat_id,sikayetci,dava_id,metin) values(p_avukat,p.id,d.id,trim(p_metin)) returning id into sid;
 perform oyun.bildir(p_avukat,format('Dava #%s nedeniyle hakkında baroya disiplin şikâyeti yapıldı. Kararı baro başkanı verecek.',d.id),oyun.simdi());
 bas:=oyun.baro_baskan();
 if bas is not null and bas<>p_avukat then
  perform oyun.bildir(bas,format('Av. %s hakkında yeni disiplin şikâyeti var (Türkiye Barosu > Disiplin).',oyun.kad(p_avukat)),oyun.simdi());
 end if;
 return jsonb_build_object('id',sid);
end $f$;

create or replace function public.baro_sikayet_karar(p_sikayet bigint,p_ceza text,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); x oyun.baro_disiplin; v_bitis timestamptz; ad text;
begin
 select * into x from oyun.baro_disiplin where id=p_sikayet for update;
 if x.id is null or x.durum<>'bekliyor' then raise exception 'Bekleyen şikâyet bulunamadı.'; end if;
 if not (coalesce(p.yonetici,false) or (oyun.baro_baskan() is not distinct from p.id and oyun.baro_uyesi(p.id) and x.avukat_id<>p.id)) then
  raise exception 'Disiplin kararını yalnız baro başkanı verir (kendisi hakkındaki şikâyet hariç).';
 end if;
 if p_ceza not in ('ret','uyari','kinama','isten_yasak_3','isten_yasak_7') then raise exception 'Geçersiz karar.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 1000 then raise exception 'Gerekçe 20-1000 karakter olmalı.'; end if;
 v_bitis:=case p_ceza when 'isten_yasak_3' then now()+interval '3 days' when 'isten_yasak_7' then now()+interval '7 days' end;
 ad:=case p_ceza when 'ret' then 'şikâyetin reddi' when 'uyari' then 'uyarma' when 'kinama' then 'kınama' when 'isten_yasak_3' then '3 gün işten yasaklama' else '7 gün işten yasaklama' end;
 update oyun.baro_disiplin set durum='karar',ceza=p_ceza,bitis=v_bitis,karar_gerekce=trim(p_gerekce),karar_veren=p.id,karar_at=now() where id=x.id;
 if v_bitis is not null then perform oyun.avukat_vekalet_kapat(x.avukat_id,'baro disiplin kararıyla işten yasaklandı'); end if;
 if p_ceza<>'ret' then perform oyun.avukat_gecmis(x.avukat_id,'disiplin','Disiplin cezası: '||ad); end if;
 perform oyun.bildir(x.avukat_id,format('Baro disiplin kararı: %s. Gerekçe: %s',ad,left(trim(p_gerekce),200)),oyun.simdi());
 perform oyun.bildir(x.sikayetci,format('Av. %s hakkındaki şikâyetin sonuçlandı: %s.',oyun.kad(x.avukat_id),ad),oyun.simdi());
 return jsonb_build_object('tamam',true,'ceza',p_ceza,'bitis',v_bitis);
end $f$;

create or replace function public.baro_dava_bilgi(p_dava bigint) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; tr text; b oyun.baro; taraf_mi boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null then raise exception 'Dava bulunamadı.'; end if;
 select * into b from oyun.baro where id=1;
 tr:=case when d.davaci=p.id and d.davaci_parti is null then 'davaci' when d.davali=p.id then 'davali' end;
 taraf_mi:=p.id in (d.davaci,d.davali) or exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.muvekkil=p.id)
   or exists(select 1 from oyun.partiler pa where pa.id in (d.davaci_parti,d.davali_parti) and pa.gb=p.id);
 return jsonb_build_object(
  'benim_taraf',tr,
  'vekilim_var',tr is not null and exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.taraf=tr and v.aktif),
  'dava_acik',d.durum='acik',
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
  where n.nspname='public' and p.proname in ('avukat_durum','avukat_sinav_gonder','avukat_ruhsat_basvur','avukat_ruhsat_yenile','avukat_ruhsat_birak','avukat_kontenjan_ayarla',
   'avukat_teklif_ver','avukat_karsi_teklif','baro_durum','baro_kaydol','baro_aidat_ode','baro_gonullu','baro_ayril','baro_mesaj_gonder','baro_mesaj_sil',
   'baro_aday_ol','baro_adaylik_cekil','baro_oy_ver','baro_adli_yardim_iste','baro_adli_yardim_karar','baro_sikayet_et','baro_sikayet_karar','baro_dava_bilgi')
 loop execute format('revoke all on function %s from public, anon; grant execute on function %s to authenticated',f.sig,f.sig); end loop;
 for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='oyun' and p.proname in ('avukat_ruhsatli','baro_uyesi','avukat_yasak_bitis','avukat_engel','avukat_sira_uygun','avukat_sira_no','avukat_gecmis','baro_kasa',
   'avukat_vekalet_kapat','avukat_askiya_al','baro_baskan','baro_baskan_secilmis','hukuk_sinav_seti','avukat_sira_isle','avukat_pasif_isle','baro_aidat_isle','baro_secim_isle','baro_tick')
 loop execute format('revoke all on function %s from public, anon, authenticated',f.sig); end loop;
end $grants$;

-- ---------------------------------------------------------------- 8) Zamanlayıcı
do $cron$
begin
 if exists(select 1 from cron.job where jobname='avukat-baro') then perform cron.unschedule('avukat-baro'); end if;
 perform cron.schedule('avukat-baro','4-59/10 * * * *','select oyun.baro_tick()');
end $cron$;

-- ---------------------------------------------------------------- 9) Hukuk Akademisi soru bankası (60 soru, her sınavda rastgele 20)
insert into oyun.hukuk_sorulari(id,soru,secenekler,dogru) values
(1,'Bir davada delil sunmanın amacı nedir?','["Karşı tarafı korkutmak", "İddiayı somutlaştırıp ispatlamak", "Hâkimi seçmek", "Sonucu garanti altına almak"]'::jsonb,2),
(2,'Savunma hakkı kime aittir?','["Davalıya da aittir", "Yalnız davacıya", "Yalnız hâkime", "Yalnız belediyeye"]'::jsonb,1),
(3,'Bir tarafı davada temsil etmek için ne gerekir?','["Gazete ilanı", "Parti üyeliği", "Yetki / vekâlet", "Oy kullanmış olmak"]'::jsonb,3),
(4,'Çıkar çatışması ne zaman doğar?','["Taraflar uzlaşınca", "Aynı davada karşıt taraflar aynı avukatça temsil edilince", "Dava kapanınca", "Ücret ödenince"]'::jsonb,2),
(5,'Hangisi en güçlü delildir?','["Dedikodu", "İmzasız tehdit mesajı", "Beğeni sayısı", "Doğrulanabilir işlem kaydı"]'::jsonb,4),
(6,'Mahkeme kararı neden gerekçeli olmalıdır?','["Dava uzasın diye", "Denetlenebilir ve anlaşılır olması için", "Ücreti artırmak için", "Oy toplamak için"]'::jsonb,2),
(7,'İstinaf nedir?','["Yeni parti kurma", "Bir kredi türü", "İlk derece kararının üst mahkemece incelenmesi", "Mülk vergisi"]'::jsonb,3),
(8,'Kesinleşmemiş bir karar nasıl anlatılmalıdır?','["Kesin suçlu ilan edilmiş gibi", "Kanun yolu açık bir karar olarak", "Hiç karar yokmuş gibi", "Otomatik iptal edilmiş gibi"]'::jsonb,2),
(9,'Dava vekâletinin kurulması için kimin iradesi gerekir?','["Yalnız avukatın", "Yalnız izleyicilerin", "Belediyenin", "Müvekkilin ve avukatın"]'::jsonb,4),
(10,'Taraf beyanı ile avukat savunması arasındaki fark nedir?','["Fark yoktur", "Beyan bir cezadır", "Savunma yalnız haberdir", "Beyan olayları, savunma hukuki gerekçeleri anlatır"]'::jsonb,4),
(11,'Masumiyet karinesi neyi ifade eder?','["Suçlama tek başına cezadır", "Delil olmadan ceza verilebilir", "Davacı her zaman haklıdır", "Suçluluğu hükmen sabit oluncaya kadar kimse suçlu sayılamaz"]'::jsonb,4),
(12,'Tazminat talebinde hangi unsur önemlidir?','["Parti rengi", "Takipçi sayısı", "Zarar ve hukuki dayanak", "Oyun süresi"]'::jsonb,3),
(13,'Mahkemenin tarafsızlığı neden önemlidir?','["Adil yargılama için", "Daha çok harç için", "Daha çok reklam için", "Daha az delil için"]'::jsonb,1),
(14,'Maddi delil yoksa en doğru yol hangisidir?','["Belirsizliği açıkça belirtmek", "Delil uydurmak", "Suçlamayı kesinmiş gibi sunmak", "Karşı tarafı susturmak"]'::jsonb,1),
(15,'Vekâlet verilen avukat hangisini yapamaz?','["Aynı davada karşı tarafı da temsil etmek", "Dosyayı incelemek", "Savunma sunmak", "Delil sunmak"]'::jsonb,1),
(16,'Dava harcı ile avukatlık ücreti arasındaki fark nedir?','["Aynı şeydir", "İkisi de vergidir", "Harç yargılama gideridir, ücret avukatın hizmet bedelidir", "İkisi de tazminattır"]'::jsonb,3),
(17,'Müvekkilin sırrı nasıl kullanılmalıdır?','["Herkese açıklanır", "Gazeteye verilir", "Yalnız müvekkilin yararına ve dava amacıyla", "Karşı tarafa satılır"]'::jsonb,3),
(18,'Bir avukatın başarı oranı nasıl hesaplanmalıdır?','["Rastgele", "Aldığı ücret tutarıyla", "Takipçi sayısıyla", "Yalnız kesinleşmiş gerçek kararlarla"]'::jsonb,4),
(19,'Oyunda avukatlık ücreti nasıl belirlenir?','["Yalnız hâkim belirler", "Teklif, pazarlık ve kabul ile", "Yalnız vergi dairesi belirler", "Rastgele"]'::jsonb,2),
(20,'Davanın düşmesi ne anlama gelir?','["Esas hakkında kazanan ya da kaybeden belirlenmeden dosyanın kapanması", "Davalının esastan beraat etmesi", "Avukatın kesin kazanması", "Mahkûmiyet"]'::jsonb,1),
(21,'Türkiye''de avukatlık mesleğini düzenleyen temel kanun hangisidir?','["Türk Ticaret Kanunu", "1136 sayılı Avukatlık Kanunu", "Vergi Usul Kanunu", "Siyasi Partiler Kanunu"]'::jsonb,2),
(22,'Avukatlık yapabilmek için hangi kayıt şartı aranır?','["Bir baronun levhasına yazılmak", "Bir siyasi partiye üye olmak", "Belediyeye kaydolmak", "Bir şirket kurmak"]'::jsonb,1),
(23,'Gerçek hayatta avukatlık stajı ne kadar sürer?','["Bir ay", "On yıl", "Bir yıl", "Staj yoktur"]'::jsonb,3),
(24,'Gerçek hayatta bir ilde baro kurulabilmesi için o ilde en az kaç avukat bulunmalıdır?','["3", "30", "300", "1"]'::jsonb,2),
(25,'Hangisi Avukatlık Kanunu''nda sayılan disiplin cezalarından biridir?','["Hapis", "Sürgün", "Mülk müsaderesi", "Kınama"]'::jsonb,4),
(26,'Avukatlık ücret sözleşmesinde başarıya bağlı ücret, dava değerinin yüzde kaçını aşamaz?','["%5", "%25", "%50", "%100"]'::jsonb,2),
(27,'Avukatlık Asgari Ücret Tarifesi''ni kim hazırlar?','["Merkez Bankası", "Belediye meclisleri", "Türkiye Barolar Birliği", "Siyasi partiler"]'::jsonb,3),
(28,'Avukatın mesleği sebebiyle öğrendiği bilgileri açıklamaması yükümlülüğüne ne denir?','["Reklam serbestisi", "Sır saklama yükümlülüğü", "Kamu duyurusu", "Basın açıklaması"]'::jsonb,2),
(29,'Avukatların reklam yapması konusunda kural nedir?','["Sınırsız reklam serbesttir", "Yalnız seçim döneminde serbesttir", "Reklam zorunludur", "Reklam yasağı vardır"]'::jsonb,4),
(30,'Anayasa''ya göre herkes yargı mercileri önünde hangi hakka sahiptir?','["Yargılanmama hakkı", "Hâkimi seçme hakkı", "Kararı kendisi değiştirme hakkı", "İddia ve savunma ile adil yargılanma hakkı"]'::jsonb,4),
(31,'Ceza muhakemesinde şüpheli veya sanığın savunmasını yapan avukata ne denir?','["Bilirkişi", "Noter", "Kayyum", "Müdafi"]'::jsonb,4),
(32,'Bölge adliye mahkemeleri hangi kanun yolu incelemesini yapar?','["Bireysel başvuru", "Yüce Divan", "İstinaf", "Halk oylaması"]'::jsonb,3),
(33,'Adli yargıda istinaftan sonra temyiz incelemesi kural olarak hangi mahkemede yapılır?','["Yargıtay", "Sayıştay", "Belediye Meclisi", "Rekabet Kurumu"]'::jsonb,1),
(34,'İdari yargının en üst mahkemesi hangisidir?','["Danıştay", "Yargıtay", "Sayıştay", "Uyuşmazlık Mahkemesi"]'::jsonb,1),
(35,'Anayasa Mahkemesine bireysel başvuru, başvuru yolları tüketildikten sonra kaç gün içinde yapılır?','["30 gün", "7 gün", "1 yıl", "Süre yoktur"]'::jsonb,1),
(36,'Cumhurbaşkanı, TBMM Başkanı ve bakanları görevleriyle ilgili suçlardan Yüce Divan sıfatıyla hangi mahkeme yargılar?','["Yargıtay", "Danıştay", "Anayasa Mahkemesi", "Asliye Ceza Mahkemesi"]'::jsonb,3),
(37,'Yüksek Seçim Kurulu kararlarına karşı başka bir mercie başvurulabilir mi?','["Evet, belediyeye", "Evet, siyasi partilere", "Hayır, YSK kararları kesindir", "Evet, bankalara"]'::jsonb,3),
(38,'Hâkim ve savcıların atanması, nakli ve disiplin işleri hangi kurulca yürütülür?','["Yüksek Seçim Kurulu", "Sayıştay", "Merkez Bankası", "Hâkimler ve Savcılar Kurulu"]'::jsonb,4),
(39,'Hâkimin tarafsızlığından şüphe ettiren önemli bir sebep varsa taraf ne yapabilir?','["Hâkimi görevden alabilir", "Hâkimi reddedebilir", "Kararı kendisi verebilir", "Davayı silebilir"]'::jsonb,2),
(40,'Hukuk davasında bir tarafın yaptığı usul işlemini kısmen veya tamamen düzeltmesine ne denir?','["Islah", "Feragat", "Kabul", "Tebligat"]'::jsonb,1),
(41,'Davacının dava konusu talebinden tamamen ya da kısmen vazgeçmesine ne denir?','["Kabul", "Feragat", "Islah", "İstinaf"]'::jsonb,2),
(42,'Davalının davacının talebini tamamen ya da kısmen kabullenmesine ne denir?','["Kabul", "Feragat", "Islah", "Müdahale"]'::jsonb,1),
(43,'Kanun yolları tüketilmiş ya da süresi geçmiş, artık değiştirilemeyen karara ne denir?','["Ara karar", "Tensip zaptı", "Kesin hüküm", "Bilirkişi raporu"]'::jsonb,3),
(44,'Yargılama giderlerini ödeme gücü olmayanlara tanınan imkâna ne denir?','["Konkordato", "Adli yardım", "Müsadere", "İhtiyati haciz"]'::jsonb,2),
(45,'Barolarda ödeme gücü olmayanlara avukat sağlayan birimin adı nedir?','["Vergi dairesi", "Seçim kurulu", "İcra dairesi", "Adli yardım bürosu"]'::jsonb,4),
(46,'İşçilik alacaklarına ilişkin birçok davada dava açmadan önce hangi yola başvurmak zorunludur?','["Yüce Divan", "Arabuluculuk", "Bireysel başvuru", "Halk oylaması"]'::jsonb,2),
(47,'Belirli suçlarda şüpheli ile mağdurun anlaşmasıyla soruşturmanın sona ermesini sağlayan kurum hangisidir?','["Islah", "İstinaf", "Uzlaştırma", "Tahkim"]'::jsonb,3),
(48,'Aynı işte daha önce karşı tarafa hizmet vermiş bir avukat, teklif edilen işi ne yapmalıdır?','["İki taraftan da ücret almalıdır", "Reddetmelidir", "Daha çok ödeyeni seçmelidir", "Gizlice yürütmelidir"]'::jsonb,2),
(49,'Avukatın bir hukuk davasını açabilmesi için müvekkilinden genellikle hangi belgeyi alması gerekir?','["Tapu senedi", "Parti üyelik kartı", "Kira sözleşmesi", "Vekâletname"]'::jsonb,4),
(50,'İspat yükü kural olarak kime düşer?','["Her zaman hâkime", "Her zaman davalıya", "Hiç kimseye", "İddia ettiği olaya dayanarak hak talep eden tarafa"]'::jsonb,4),
(51,'Mahkemenin dava sonunda verdiği ve uyuşmazlığı çözen karara ne denir?','["Ara karar", "Tensip", "Tebligat", "Hüküm"]'::jsonb,4),
(52,'Mahkemenin özel veya teknik bilgi gerektiren konularda görüşüne başvurduğu kişiye ne denir?','["Tanık", "Kayyum", "Bilirkişi", "Müdafi"]'::jsonb,3),
(53,'Kesinleşmiş bir para alacağının zorla tahsili hangi daire eliyle yapılır?','["İcra dairesi", "Nüfus müdürlüğü", "Seçim kurulu", "Tapu müdürlüğü"]'::jsonb,1),
(54,'Kanunsuz suç ve ceza olmaz ilkesi neyi ifade eder?','["Bir fiil ancak kanunda suç olarak tanımlanmışsa cezalandırılabilir", "Hâkim dilediği fiili cezalandırabilir", "Cezalar sonradan da konabilir", "Suçlar genelgeyle konur"]'::jsonb,1),
(55,'Avukatın hangi davranışı meslek kurallarına açıkça aykırıdır?','["Müvekkilinin aleyhine karşı tarafla gizlice anlaşmak", "Dosyayı incelemek", "Süresinde savunma sunmak", "Müvekkiline bilgi vermek"]'::jsonb,1),
(56,'Duruşmaların kural olarak herkese açık olmasının amacı nedir?','["Davayı uzatmak", "Harç toplamak", "Yargının şeffaf ve denetlenebilir olması", "Hâkimi eğlendirmek"]'::jsonb,3),
(57,'Dava dilekçesinde davacının mahkemeden istediğini açıkça yazdığı bölüme ne denir?','["Tebligat", "Tensip", "Talep sonucu", "Gerekçe"]'::jsonb,3),
(58,'Delil olarak sunulacak bir sohbet kaydında en önemli husus nedir?','["Uzun olması", "Büyük harflerle yazılması", "Çok beğeni alması", "Tarih, kanal ve içeriğin doğrulanabilir olması"]'::jsonb,4),
(59,'Bir avukat müvekkilinin parasını kendi işlerinde kullanırsa bu nedir?','["Olağan bir yatırımdır", "Ağır bir meslek ihlali ve güveni kötüye kullanmadır", "Avukatın hakkıdır", "Baronun izniyle serbesttir"]'::jsonb,2),
(60,'Gerçek hayatta baro başkanı nasıl belirlenir?','["Baroya kayıtlı avukatların genel kurulda seçimiyle", "Cumhurbaşkanı atamasıyla", "Kurayla", "Belediye meclisi kararıyla"]'::jsonb,1)
on conflict(id) do update set soru=excluded.soru, secenekler=excluded.secenekler, dogru=excluded.dogru;
