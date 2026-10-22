
-- Seçim Online / B modeli: hukuk akademisi, sinav, staj, kontenjan, burolar ve vekalet
-- Yalniz ekleme; mevcut oyuncu, dava ve para kayitlarini degistirmez.
create table if not exists oyun.hukuk_akademisi (
 user_id uuid primary key references oyun.profiller(id),
 baslangic timestamptz not null default now(),
 sinav_gecildi timestamptz,
 son_sinav timestamptz,
 son_puan int,
 pratik1 timestamptz,
 pratik2 timestamptz,
 son_pratik timestamptz
);
create table if not exists oyun.hukuk_sorulari (
 id int primary key,
 soru text not null,
 secenekler jsonb not null,
 dogru smallint not null check(dogru between 1 and 4)
);
insert into oyun.hukuk_sorulari(id,soru,secenekler,dogru) values
(1,'Bir davada delil sunmanin amaci nedir?','["Iddiayi somutlamak","Rakibi korkutmak","Hakimi secmek","Sonucu garantilemek"]',1),
(2,'Savunma hakki kime aittir?','["Yalniz davaciya","Davaliya da","Yalniz hakime","Yalniz belediyeye"]',2),
(3,'Taraflari temsil etmek icin ne gerekir?','["Yetki/vekalet","Gazete ilani","Parti uyeligi","Oy kullanma"]',1),
(4,'Cikar catismasi ne zaman dogar?','["Taraflar anlasinca","Ayni davada karsit taraflar temsil edilince","Dava kapaninca","Ucret odendiginde"]',2),
(5,'Delil olarak en guclu hangisidir?','["Dogrulanabilir islem kaydi","Dedikodu","Isimsiz tehdit","Begeni sayisi"]',1),
(6,'Mahkeme karari neden gerekceli olmalidir?','["Denetim ve anlasilabilirlik icin","Surekli uzasin diye","Ucreti artirmak icin","Oy toplamak icin"]',1),
(7,'Istinaf nedir?','["Ust inceleme yolu","Yeni parti kurma","Kredi turu","Mulk vergisi"]',1),
(8,'Kesinlesmemis karar nasil anlatilmalidir?','["Kesin suclu","Itiraza acik karar","Karar yokmus gibi","Otomatik iptal"]',2),
(9,'Dava vekaletinde kimin onayi gerekir?','["Yalniz avukatin","Yalniz seyircinin","Yetkili muvekkilin ve avukatin","Belediyenin"]',3),
(10,'Beyan ile avukat savunmasi arasindaki fark nedir?','["Fark yok","Beyan olgulari, savunma hukuki gerekceleri anlatir","Beyan cezadir","Savunma sadece haberdir"]',2),
(11,'Masumiyet karinesi nedir?','["Iddianin kendisi cezadir","Kanitsiz otomatik ceza","Sucluluk kanitlanana kadar masum sayilma","Davaci her zaman haklidir"]',3),
(12,'Tazminat talebinde hangi unsur onemlidir?','["Zarar ve dayanak","Parti rengi","Takipci sayisi","Oyun suresi"]',1),
(13,'Ayni davada yargi heyetinin tarafsizligi neden onemlidir?','["Adil karar icin","Daha cok harc icin","Daha cok reklam icin","Daha az delil icin"]',1),
(14,'Maddi delil bulunmuyorsa en dogru yol nedir?','["Delil uydurmak","Belirsizligi acikca belirtmek","Suclama kesin demek","Rakibi susturmak"]',2),
(15,'Vekalet verilen avukat ne yapamaz?','["Dosyayi incelemek","Savunma sunmak","Muvekkilin yetkisi disinda karsi tarafi temsil etmek","Delil sunmak"]',3),
(16,'Dava harci ile avukatlik ucreti nasil ayrilir?','["Ayni sey","Harc yargilama masrafi, ucret avukata odenir","Ikisi de vergi","Ikisi de tazminat"]',2),
(17,'Muvekkilin gizli bilgisi nasil kullanilmalidir?','["Herkese aciklanir","Yalniz yetki ve dava amaciyla","Gazeteye verilir","Rakibe satilir"]',2),
(18,'Kazanma yuzdesi nasil hesaplanmalidir?','["Rastgele","Sadece kesinlesmis gercek kararlarla","Ucret tutariyla","Takipci sayisiyla"]',2),
(19,'Bir davada avukatlik ucreti nasil belirlenir?','["Taraflar teklif ve kabul ile","Sadece hakim","Sadece vergi dairesi","Rastgele"]',1),
(20,'Davanin dusmesi ne anlama gelir?','["Otomatik beraat disi zafer","Esas hakkinda kazanma sonucu yok","Avukat kesin kazandi","Mahkumiyet"]',2)
on conflict(id) do nothing;
create table if not exists oyun.avukat_ruhsat (
 user_id uuid primary key references oyun.profiller(id),
 durum text not null default 'bekliyor' check(durum in ('bekliyor','aktif','askida','iptal')),
 basvuru_at timestamptz not null default now(),
 ruhsat_at timestamptz,
 siralama bigserial,
 gerekce text
);
create table if not exists oyun.hukuk_burolari(
 id bigserial primary key,
 ad text not null check(char_length(ad) between 4 and 90),
 sehir smallint not null references oyun.iller(id),
 kurucu uuid not null references oyun.profiller(id),
 acilis timestamptz not null default now(),
 aktif boolean not null default true
);
create unique index if not exists hukuk_buro_sahibi on oyun.hukuk_burolari(kurucu) where aktif;
create table if not exists oyun.hukuk_buro_uyeleri(
 buro_id bigint not null references oyun.hukuk_burolari(id),
 avukat_id uuid not null references oyun.profiller(id),
 durum text not null check(durum in ('davet','aktif','ayrildi')),
 tarih timestamptz not null default now(),
 primary key(buro_id,avukat_id)
);
create unique index if not exists hukuk_tek_aktif_buro on oyun.hukuk_buro_uyeleri(avukat_id) where durum='aktif';
create table if not exists oyun.avukat_teklifleri(
 id bigserial primary key,
 dava_id bigint not null references oyun.adliye_davalar(id),
 avukat_id uuid not null references oyun.profiller(id),
 taraf text not null check(taraf in ('davaci','davali')),
 tutar numeric not null check(tutar >= 0 and tutar <= 1000000000000),
 prim_orani numeric not null default 0 check(prim_orani between 0 and 30),
 aciklama text not null default '',
 durum text not null default 'bekliyor' check(durum in ('bekliyor','kabul','ret','iptal')),
 olusturma timestamptz not null default now(),
 kabul_at timestamptz
);
create unique index if not exists avukat_tek_bekleyen_teklif on oyun.avukat_teklifleri(dava_id,avukat_id,taraf) where durum='bekliyor';
create table if not exists oyun.avukat_vekaletleri(
 id bigserial primary key,
 teklif_id bigint not null unique references oyun.avukat_teklifleri(id),
 dava_id bigint not null references oyun.adliye_davalar(id),
 avukat_id uuid not null references oyun.profiller(id),
 muvekkil uuid not null references oyun.profiller(id),
 taraf text not null check(taraf in ('davaci','davali')),
 ucret numeric not null,
 prim_orani numeric not null default 0,
 aktif boolean not null default true,
 tarih timestamptz not null default now(),
 iptal_at timestamptz
);
create unique index if not exists avukat_tek_aktif_temsil on oyun.avukat_vekaletleri(dava_id,taraf) where aktif;
create unique index if not exists avukat_cikar_catismasi on oyun.avukat_vekaletleri(dava_id,avukat_id) where aktif;
create table if not exists oyun.avukat_savunmalar (
 id bigserial primary key,
 vekalet_id bigint not null references oyun.avukat_vekaletleri(id),
 dava_id bigint not null references oyun.adliye_davalar(id),
 avukat_id uuid not null references oyun.profiller(id),
 beyan_id bigint references oyun.adliye_beyan(id),
 yazildi timestamptz not null default now()
);
do $guard$
declare t text;
begin
 foreach t in array array['hukuk_akademisi','hukuk_sorulari','avukat_ruhsat','hukuk_burolari','hukuk_buro_uyeleri','avukat_teklifleri','avukat_vekaletleri','avukat_savunmalar'] loop
  execute format('alter table oyun.%I enable row level security',t);
  execute format('revoke all on oyun.%I from public, anon, authenticated',t);
 end loop;
end $guard$;

create or replace function oyun.avukat_kontenjan() returns integer language sql stable set search_path='' as $f$
 select greatest(2,ceil(count(*)::numeric/10)::int)
 from oyun.profiller where not yasakli and son_gorulme>now()-interval '7 days'
$f$;
create or replace function oyun.avukat_mi(u uuid) returns boolean language sql stable set search_path='' as $f$
 select exists(select 1 from oyun.avukat_ruhsat where user_id=u and durum='aktif')
$f$;
create or replace function public.avukat_akademiye_katil() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 if p.olusturma>now()-interval '7 days' then raise exception 'Avukatlik icin hesap en az 7 gunluk olmali.'; end if;
 insert into oyun.hukuk_akademisi(user_id) values(p.id) on conflict do nothing;
 return jsonb_build_object('tamam',true);
end $f$;
create or replace function public.avukat_durum() returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.hukuk_akademisi; l oyun.avukat_ruhsat;
begin
 select * into a from oyun.hukuk_akademisi where user_id=p.id;
 select * into l from oyun.avukat_ruhsat where user_id=p.id;
 return jsonb_build_object(
  'hesap_uygun',p.olusturma<=now()-interval '7 days',
  'kontenjan',oyun.avukat_kontenjan(),
  'aktif_avukat',(select count(*) from oyun.avukat_ruhsat where durum='aktif'),
  'akademi', case when a.user_id is null then null else jsonb_build_object('baslangic',a.baslangic,'egitim_bitti',a.baslangic+interval '24 hours','sinav_gecildi',a.sinav_gecildi,'son_puan',a.son_puan,'pratik1',a.pratik1,'pratik2',a.pratik2,'son_sinav',a.son_sinav) end,
  'ruhsat',case when l.user_id is null then null else jsonb_build_object('durum',l.durum,'sira',l.siralama,'ruhsat_at',l.ruhsat_at) end,
  'sinav_sorular',case when a.user_id is not null and a.baslangic+interval '24 hours'<=now() and a.sinav_gecildi is null then
   (select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'soru',q.soru,'secenekler',q.secenekler) order by md5(q.id::text||p.id::text)),'[]'::jsonb) from oyun.hukuk_sorulari q)
   else '[]'::jsonb end,
  'uygulamalar',case when a.sinav_gecildi is not null then jsonb_build_array(
   jsonb_build_object('id',1,'soru','Muvekkil sozlesme ihlali iddia ediyor. Ilk ne yaparsin?','secenekler',jsonb_build_array('Rakibi tehdit ederim','Sozlesme ve odeme kayitlarini toplarim','Davayi kazandim derim','Delil uydururum')),
   jsonb_build_object('id',2,'soru','Ayni davada karsi taraf seni avukat olarak tutmak istiyor. Ne yaparsin?','secenekler',jsonb_build_array('Iki taraftan da ucret alirim','Yalniz daha cok verenle anlasirim','Cikar catismasi nedeniyle reddederim','Dava kaydini silerim')))
   else '[]'::jsonb end,
  'avukatlar',(select coalesce(jsonb_agg(jsonb_build_object('id',r.user_id,'kad',oyun.kad(r.user_id),'burosu',(select b.ad from oyun.hukuk_buro_uyeleri y join oyun.hukuk_burolari b on b.id=y.buro_id where y.avukat_id=r.user_id and y.durum='aktif' and b.aktif limit 1),'tamamlanan',coalesce(st.toplam,0),'kazanilan',coalesce(st.kazanc,0),'oran',case when coalesce(st.toplam,0)=0 then null else round(st.kazanc*100.0/st.toplam,1) end) order by oyun.kad(r.user_id)),'[]'::jsonb)
   from oyun.avukat_ruhsat r left join lateral (
    select count(*) toplam,count(*) filter(where (v.taraf='davaci' and d.karar not in ('beraat','dusme')) or (v.taraf='davali' and d.karar='beraat')) kazanc
    from oyun.avukat_vekaletleri v join oyun.adliye_davalar d on d.id=v.dava_id
    where v.avukat_id=r.user_id and d.kesin and d.durum='karar' and d.karar <> 'dusme' and d.af_at is null
   ) st on true where r.durum='aktif'),
  'burolar',(select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'ad',b.ad,'kurucu',oyun.kad(b.kurucu),'sehir',i.ad,'uye_sayi',(select count(*) from oyun.hukuk_buro_uyeleri u where u.buro_id=b.id and u.durum='aktif')) order by b.id desc),'[]'::jsonb) from oyun.hukuk_burolari b join oyun.iller i on i.id=b.sehir where b.aktif),
  'benim_burom',(select jsonb_build_object('id',b.id,'ad',b.ad) from oyun.hukuk_burolari b where b.kurucu=p.id and b.aktif limit 1)
 );
end $f$;
create or replace function public.avukat_sinav_gonder(p_cevaplar jsonb) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.hukuk_akademisi; puan int;
begin
 select * into a from oyun.hukuk_akademisi where user_id=p.id for update;
 if a.user_id is null or a.baslangic+interval '24 hours'>now() then raise exception '24 saatlik hukuk egitimini tamamlayin.'; end if;
 if a.sinav_gecildi is not null then raise exception 'Sinavi zaten gectiniz.'; end if;
 if a.son_sinav>now()-interval '24 hours' then raise exception 'Yeniden sinav icin 24 saat bekleyin.'; end if;
 if jsonb_typeof(p_cevaplar) <> 'object' then raise exception 'Cevaplari gonderin.'; end if;
 if (select count(*) from oyun.hukuk_sorulari where not (p_cevaplar ? id::text) or (p_cevaplar->>id::text) not in ('1','2','3','4'))>0 then raise exception '20 sorunun tamamini cevaplayin.'; end if;
 select count(*) into puan from oyun.hukuk_sorulari where (p_cevaplar->>id::text)=dogru::text;
 update oyun.hukuk_akademisi set son_sinav=now(),son_puan=puan,sinav_gecildi=case when puan>=16 then now() else null end where user_id=p.id;
 return jsonb_build_object('puan',puan,'gecti',puan>=16);
end $f$;
create or replace function public.avukat_pratik_gonder(p_senaryo int,p_cevap int) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.hukuk_akademisi; dogru boolean;
begin
 select * into a from oyun.hukuk_akademisi where user_id=p.id for update;
 if a.sinav_gecildi is null then raise exception 'Once hukuk sinavini gecin.'; end if;
 if p_senaryo not in (1,2) or p_cevap not between 1 and 4 then raise exception 'Pratik secimi gecersiz.'; end if;
 if a.son_pratik>now()-interval '15 minutes' then raise exception 'Pratik denemeleri arasinda 15 dakika bekleyin.'; end if;
 dogru := (p_senaryo=1 and p_cevap=2) or (p_senaryo=2 and p_cevap=3);
 update oyun.hukuk_akademisi set son_pratik=now(),pratik1=case when p_senaryo=1 and dogru then coalesce(pratik1,now()) else pratik1 end,
 pratik2=case when p_senaryo=2 and dogru then coalesce(pratik2,now()) else pratik2 end where user_id=p.id;
 return jsonb_build_object('gecti',dogru,'senaryo',p_senaryo);
end $f$;
create or replace function public.avukat_ruhsat_basvur() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); a oyun.hukuk_akademisi; l oyun.avukat_ruhsat; aktif int; kota int;
begin
 select * into a from oyun.hukuk_akademisi where user_id=p.id;
 if a.sinav_gecildi is null or a.pratik1 is null or a.pratik2 is null then raise exception 'Sinav ve iki uygulamali staj dosyasi tamamlanmali.'; end if;
 perform pg_advisory_xact_lock(20261022,1);
 insert into oyun.avukat_ruhsat(user_id) values(p.id) on conflict do nothing;
 select * into l from oyun.avukat_ruhsat where user_id=p.id for update;
 if l.durum='aktif' then return jsonb_build_object('durum','aktif'); end if;
 if l.durum in ('askida','iptal') then raise exception 'Ruhsatiniz askida veya iptal durumunda.'; end if;
 -- Bekleme sirasi: baska uygun aday siradaysa ileri gecilemez.
 if exists(select 1 from oyun.avukat_ruhsat x where x.durum='bekliyor' and x.siralama<l.siralama) then
  return jsonb_build_object('durum','bekliyor','neden','Siradaki basvurular bekleniyor.');
 end if;
 select count(*) into aktif from oyun.avukat_ruhsat where durum='aktif';kota:=oyun.avukat_kontenjan();
 if aktif>=kota then return jsonb_build_object('durum','bekliyor','kontenjan',kota); end if;
 perform oyun.para_islem(p.id,-100000,'adliye','Avukatlik ruhsat kayit ucreti',oyun.simdi());
 update oyun.avukat_ruhsat set durum='aktif',ruhsat_at=now() where user_id=p.id;
 return jsonb_build_object('durum','aktif','kontenjan',kota);
end $f$;
create or replace function public.avukat_buro_ac(p_ad text,p_il smallint) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); bid bigint;
begin
 if not oyun.avukat_mi(p.id) then raise exception 'Hukuk burosunu yalniz ruhsatli avukat acabilir.'; end if;
 if char_length(trim(coalesce(p_ad,''))) not between 4 and 90 then raise exception 'Buro adi 4-90 karakter olmali.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Il bulunamadi.'; end if;
 if exists(select 1 from oyun.hukuk_burolari where kurucu=p.id and aktif) then raise exception 'Zaten aktif bir hukuk buronuz var.'; end if;
 perform oyun.para_islem(p.id,-250000,'adliye','Hukuk burosu kurulus gideri',oyun.simdi());
 insert into oyun.hukuk_burolari(ad,sehir,kurucu) values(trim(p_ad),p_il,p.id) returning id into bid;
 insert into oyun.hukuk_buro_uyeleri(buro_id,avukat_id,durum) values(bid,p.id,'aktif');
 return jsonb_build_object('id',bid,'tamam',true);
end $f$;
create or replace function public.avukat_buro_davet(p_buro bigint,p_kad text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); u uuid;
begin
 if not exists(select 1 from oyun.hukuk_burolari where id=p_buro and kurucu=p.id and aktif) then raise exception 'Buro sahibi degilsiniz.'; end if;
 select id into u from oyun.profiller where lower(kad)=lower(trim(p_kad)) and not yasakli;
 if u is null or not oyun.avukat_mi(u) or u=p.id then raise exception 'Davet edilecek ruhsatli avukat bulunamadi.'; end if;
 if exists(select 1 from oyun.hukuk_buro_uyeleri where avukat_id=u and durum='aktif') then raise exception 'Bu avukat baska bir buroda calisiyor.'; end if;
 insert into oyun.hukuk_buro_uyeleri(buro_id,avukat_id,durum) values(p_buro,u,'davet') on conflict(buro_id,avukat_id) do update set durum='davet',tarih=now();
 perform oyun.bildir(u,'Bir hukuk burosundan calisma daveti aldiniz. Avukatlik ekranindan cevaplayin.',oyun.simdi());
 return jsonb_build_object('tamam',true);
end $f$;
create or replace function public.avukat_buro_davet_cevap(p_buro bigint,p_kabul boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 if not exists(select 1 from oyun.hukuk_buro_uyeleri where buro_id=p_buro and avukat_id=p.id and durum='davet') then raise exception 'Bekleyen davet yok.'; end if;
 if p_kabul and (not oyun.avukat_mi(p.id) or exists(select 1 from oyun.hukuk_buro_uyeleri where avukat_id=p.id and durum='aktif')) then raise exception 'Aktif avukat olmali ve baska buroda bulunmamalısınız.'; end if;
 update oyun.hukuk_buro_uyeleri set durum=case when p_kabul then 'aktif' else 'ayrildi' end,tarih=now() where buro_id=p_buro and avukat_id=p.id;
 return jsonb_build_object('tamam',true);
end $f$;
create or replace function public.avukat_buro_ayril() returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 if exists(select 1 from oyun.hukuk_burolari where kurucu=p.id and aktif) then raise exception 'Kurucu aktif burodan ayrilamaz; once buroyu kapatmali.'; end if;
 update oyun.hukuk_buro_uyeleri set durum='ayrildi',tarih=now() where avukat_id=p.id and durum='aktif';
 return jsonb_build_object('tamam',true);
end $f$;
create or replace function public.avukat_teklif_ver(p_dava bigint,p_taraf text,p_tutar numeric,p_prim numeric default 0,p_aciklama text default '') returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; tid bigint;
begin
 if not oyun.avukat_mi(p.id) then raise exception 'Yalniz aktif ruhsatli avukat teklif verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null or d.durum<>'acik' then raise exception 'Acik dava bulunamadi.'; end if;
 if p_taraf not in ('davaci','davali') or p_tutar is null or p_tutar<0 or p_tutar>1000000000000 or p_prim is null or p_prim<0 or p_prim>30 then raise exception 'Teklif bilgileri gecersiz.'; end if;
 if p.id in (d.davaci,d.davali) then raise exception 'Kendi davanizda avukatlik yapamazsiniz.'; end if;
 if exists(select 1 from oyun.mahkeme_uye where user_id=p.id) then raise exception 'Yargic avukatlik yapamaz.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=p_dava and avukat_id=p.id and aktif) then raise exception 'Bu davada zaten vekilsiniz.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=p_dava and taraf=p_taraf and aktif) then raise exception 'Bu tarafin aktif avukati var.'; end if;
 insert into oyun.avukat_teklifleri(dava_id,avukat_id,taraf,tutar,prim_orani,aciklama)
 values(p_dava,p.id,p_taraf,round(p_tutar),p_prim,left(trim(p_aciklama),500)) returning id into tid;
 perform oyun.bildir(case when p_taraf='davaci' then d.davaci else coalesce(d.davali,(select gb from oyun.partiler where id=d.davali_parti)) end,
   format('Adliye #%s icin avukat %s teklif verdi: %s TL.',p_dava,p.kad,round(p_tutar)),oyun.simdi());
 return jsonb_build_object('tamam',true,'id',tid);
end $f$;
create or replace function public.avukat_teklif_karar(p_teklif bigint,p_kabul boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t oyun.avukat_teklifleri; d oyun.adliye_davalar; yetkili boolean;
begin
 select * into t from oyun.avukat_teklifleri where id=p_teklif for update;
 if t.id is null or t.durum<>'bekliyor' then raise exception 'Teklif beklemede degil.'; end if;
 select * into d from oyun.adliye_davalar where id=t.dava_id for update;
 if d.durum<>'acik' then raise exception 'Dava kapandi.'; end if;
 yetkili:=case when t.taraf='davaci' then (d.davaci=p.id or exists(select 1 from oyun.partiler where id=d.davaci_parti and gb=p.id))
 else (d.davali=p.id or exists(select 1 from oyun.partiler where id=d.davali_parti and gb=p.id)) end;
 if not yetkili then raise exception 'Teklifin muvekkili degilsiniz.'; end if;
 if not p_kabul then update oyun.avukat_teklifleri set durum='ret' where id=t.id; return jsonb_build_object('durum','ret'); end if;
 if not oyun.avukat_mi(t.avukat_id) then raise exception 'Avukatin ruhsati aktif degil.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and taraf=t.taraf and aktif) then raise exception 'Bu tarafin zaten avukati var.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and avukat_id=t.avukat_id and aktif) then raise exception 'Ayni avukat karsi tarafi temsil edemez.'; end if;
 -- Gercek para transferi, tek SQL transaction: eksik bakiye tum islem iptal.
 if t.tutar>0 then
  perform oyun.para_islem(p.id,-t.tutar,'adliye','Dava #'||d.id||' avukatlik ucreti',oyun.simdi());
  perform oyun.para_islem(t.avukat_id,t.tutar,'adliye','Dava #'||d.id||' avukatlik ucreti',oyun.simdi());
 end if;
 insert into oyun.avukat_vekaletleri(teklif_id,dava_id,avukat_id,muvekkil,taraf,ucret,prim_orani)
 values(t.id,d.id,t.avukat_id,p.id,t.taraf,t.tutar,t.prim_orani);
 update oyun.avukat_teklifleri set durum='kabul',kabul_at=now() where id=t.id;
 update oyun.avukat_teklifleri set durum='iptal' where dava_id=d.id and taraf=t.taraf and id<>t.id and durum='bekliyor';
 perform oyun.bildir(t.avukat_id,format('Dava #%s avukatlik teklifiniz kabul edildi.',d.id),oyun.simdi());
 return jsonb_build_object('durum','kabul');
end $f$;
create or replace function public.avukat_vekalet_iptal(p_vekalet bigint) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); v oyun.avukat_vekaletleri;
begin
 select * into v from oyun.avukat_vekaletleri where id=p_vekalet for update;
 if v.id is null or not v.aktif or p.id not in(v.muvekkil,v.avukat_id) then raise exception 'Vekaleti sonlandirma yetkiniz yok.'; end if;
 update oyun.avukat_vekaletleri set aktif=false,iptal_at=now() where id=v.id;
 perform oyun.bildir(case when p.id=v.avukat_id then v.muvekkil else v.avukat_id end,'Dava #'||v.dava_id||' vekalet iliskisi sona erdi.',oyun.simdi());
 return jsonb_build_object('tamam',true);
end $f$;
create or replace function public.avukat_dava_durum(p_dava bigint) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 if not exists(select 1 from oyun.adliye_davalar where id=p_dava) then raise exception 'Dava bulunamadi.'; end if;
 return jsonb_build_object(
  'teklifler',(select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'avukat',oyun.kad(t.avukat_id),'taraf',t.taraf,'tutar',t.tutar,'prim',t.prim_orani,'aciklama',t.aciklama,'durum',t.durum,'benim',t.avukat_id=p.id,'cevaplayabilirim',case when t.taraf='davaci' then (d.davaci=p.id or exists(select 1 from oyun.partiler where id=d.davaci_parti and gb=p.id)) else (d.davali=p.id or exists(select 1 from oyun.partiler where id=d.davali_parti and gb=p.id)) end) order by t.id desc),'[]'::jsonb)
    from oyun.avukat_teklifleri t join oyun.adliye_davalar d on d.id=t.dava_id where t.dava_id=p_dava and (t.avukat_id=p.id or (t.taraf='davaci' and (d.davaci=p.id or exists(select 1 from oyun.partiler where id=d.davaci_parti and gb=p.id))) or (t.taraf='davali' and (d.davali=p.id or exists(select 1 from oyun.partiler where id=d.davali_parti and gb=p.id))) or t.durum='kabul')),
  'vekaletler',(select coalesce(jsonb_agg(jsonb_build_object('id',v.id,'avukat',oyun.kad(v.avukat_id),'taraf',v.taraf,'muvekkil',oyun.kad(v.muvekkil),'ucret',v.ucret,'aktif',v.aktif,'benim',v.avukat_id=p.id or v.muvekkil=p.id) order by v.id desc),'[]'::jsonb) from oyun.avukat_vekaletleri v where v.dava_id=p_dava)
 );
end $f$;
create or replace function public.avukat_savunma_ver(p_dava bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; v oyun.avukat_vekaletleri; bid bigint;
begin
 if not oyun.avukat_mi(p.id) then raise exception 'Yalniz ruhsatli avukat hukuki savunma sunabilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava savunmaya acik degil.'; end if;
 select * into v from oyun.avukat_vekaletleri where dava_id=p_dava and avukat_id=p.id and aktif limit 1;
 if v.id is null then raise exception 'Bu dava icin aktif vekaletiniz yok.'; end if;
 if char_length(trim(coalesce(p_metin,''))) not between 20 and 2500 then raise exception 'Hukuki savunma 20-2500 karakter olmali.'; end if;
 if exists(select 1 from oyun.adliye_beyan where dava_id=p_dava and yazar=p.id and zaman>oyun.simdi()-interval '30 seconds') then raise exception 'Yeni savunma icin 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_beyan(dava_id,yazar,rol,metin,zaman) values(p_dava,p.id,'avukat',trim(p_metin),oyun.simdi()) returning id into bid;
 insert into oyun.avukat_savunmalar(vekalet_id,dava_id,avukat_id,beyan_id) values(v.id,p_dava,p.id,bid);
 if v.taraf='davali' then update oyun.adliye_davalar set savunma_geldi=true where id=p_dava; end if;
 return jsonb_build_object('tamam',true);
end $f$;
-- Mevcut oyuncular sadece olgu beyaninda bulunabilir; resmi hukuki savunma avukat RPC ile gelir.
create or replace function public.adliye_beyan_ver(p_dava bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; rol text;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava beyana acik degil.'; end if;
 if char_length(trim(coalesce(p_metin,''))) not between 10 and 2500 then raise exception 'Beyan 10-2500 karakter olmali.'; end if;
 if d.davali=p.id then rol:='davali';
 elsif d.davaci=p.id then rol:='davaci';
 elsif exists(select 1 from oyun.adliye_ek_taraf e where e.dava_id=d.id and e.user_id=p.id) then rol:='ilgili';
 elsif (d.davali_parti is not null or d.davaci_parti is not null) and exists(
  select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id
  where pa.id in (d.davali_parti,d.davaci_parti) and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))) then rol:='sozcu';
 else raise exception 'Bu davada beyan yetkiniz yok.'; end if;
 if exists(select 1 from oyun.adliye_beyan where dava_id=d.id and yazar=p.id and zaman>oyun.simdi()-interval '30 seconds') then raise exception 'Yeni beyan icin 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_beyan(dava_id,yazar,rol,metin,zaman) values(d.id,p.id,rol,trim(p_metin),oyun.simdi());
 return jsonb_build_object('tamam',true,'tip','olgu_beyani');
end $f$;
do $grants$
declare f record;
begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('avukat_akademiye_katil','avukat_durum','avukat_sinav_gonder','avukat_pratik_gonder','avukat_ruhsat_basvur','avukat_buro_ac','avukat_buro_davet','avukat_buro_davet_cevap','avukat_buro_ayril','avukat_teklif_ver','avukat_teklif_karar','avukat_vekalet_iptal','avukat_dava_durum','avukat_savunma_ver')
 loop execute format('revoke all on function %s from public, anon; grant execute on function %s to authenticated',f.signature,f.signature); end loop;
end $grants$;
