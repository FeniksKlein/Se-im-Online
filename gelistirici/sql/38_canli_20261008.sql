-- =====================================================================
--  38) 2026-10-08 akşamı canlıya doğrudan uygulanan migration'lar — kaynakla eşitlendi.
--  Mantıksal sıra (düzeltmeler en sonda). Hepsi tekrar çalıştırılabilir.
-- =====================================================================

-- ---- 20261008_oyuncu_banka_saatlik ----
-- Oyuncu bankalari v2: saatlik mevduat ve gercek oyunculara kredi.
-- Mevcut 7 gunluk mevduat / kasa / ortaklik kayitlarini degistirmez.
alter table oyun.banka_mevduat
  add column if not exists vade_saat integer not null default 168;
create index if not exists banka_mevduat_aktif_vade_idx
  on oyun.banka_mevduat (banka_id,vade) where not kapandi;
create table if not exists oyun.oyb_vade_oran (
  banka_id bigint not null references oyun.sirketler(id),
  saat smallint not null check (saat in (1,3,6,12,24)),
  oran numeric(6,2) not null check (oran>=0 and oran<=8),
  primary key(banka_id,saat)
);
create table if not exists oyun.oyb_kredi (
  id bigint generated always as identity primary key,
  banka_id bigint not null references oyun.sirketler(id),
  borclu uuid not null references auth.users(id),
  anapara numeric(20,2) not null check (anapara between 1000 and 500000),
  saat smallint not null check (saat in (1,3,6,12,24)),
  oran numeric(7,2) not null check (oran between 0 and 20),
  toplam numeric(20,2) not null check (toplam>=anapara),
  kalan numeric(20,2) not null check (kalan>=0),
  anapara_odendi numeric(20,2) not null default 0,
  durum text not null default 'basvuru' check (durum in ('basvuru','aktif','reddedildi','odendi')),
  basvuru timestamptz not null default now(),
  acilis timestamptz,
  vade timestamptz,
  kapanis timestamptz
);
create index if not exists oyb_kredi_banka_idx on oyun.oyb_kredi(banka_id,durum);
create index if not exists oyb_kredi_borclu_idx on oyun.oyb_kredi(borclu,durum);
create unique index if not exists oyb_kredi_tek_acik_idx
  on oyun.oyb_kredi (borclu) where durum in ('basvuru','aktif');
alter table oyun.oyb_vade_oran enable row level security;
alter table oyun.oyb_kredi enable row level security;
revoke all on oyun.oyb_vade_oran,oyun.oyb_kredi from public,anon,authenticated;

create or replace function oyun.oyb_oran(p_banka bigint,p_saat integer)
returns numeric language plpgsql stable set search_path='' as $$
declare f numeric; s numeric;
begin
  select banka_faiz into f from oyun.sirketler
  where id=p_banka and sektor='banka' and aktif;
  if f is null then raise exception 'Banka bulunamadi'; end if;
  if p_saat=168 then return f; end if;
  if p_saat not in (1,3,6,12,24) or p_saat is null then raise exception 'Gecersiz vade'; end if;
  select oran into s from oyun.oyb_vade_oran
  where banka_id=p_banka and saat=p_saat;
  return coalesce(s, round(least(case p_saat when 1 then .25 when 3 then .80
    when 6 then 1.75 when 12 then 4 else 8 end,
    f * case p_saat when 1 then .05 when 3 then .15 when 6 then .30
       when 12 then .60 else 1 end),2));
end $$;

-- Krediler tahsil edilmedikce nakit DEGILDIR. Temerrutte alacak iskontosu daha yuksektir.
create or replace function oyun.oyb_saglik(p_banka bigint)
returns jsonb language plpgsql stable set search_path='' as $$
declare s oyun.sirketler; y numeric; a numeric; yak numeric; al numeric; tampon numeric; rezerv numeric; limit_k numeric;
begin
  select * into s from oyun.sirketler where id=p_banka and sektor='banka';
  if s.id is null then raise exception 'Banka bulunamadi'; end if;
  select coalesce(sum(round(anapara*(1+faiz/100))),0),
    coalesce(sum(anapara),0),
    coalesce(sum(round(anapara*(1+faiz/100))) filter(where vade<=oyun.simdi()+interval '24 hours'),0)
  into y,a,yak from oyun.banka_mevduat where banka_id=p_banka and not kapandi;
  select coalesce(sum(least(kalan,anapara) *
      case when vade<oyun.simdi() then .25 else .70 end),0)
  into al from oyun.oyb_kredi where banka_id=p_banka and durum='aktif';
  tampon:=greatest(round(s.sermaye*.10,2), round(a*.10,2));
  rezerv:=greatest(round(a*.50,2),yak)+tampon;
  limit_k:=greatest(0,least(s.kasa-rezerv,
    (s.kasa+al-y-tampon)/.30));
  return jsonb_build_object('kasa',s.kasa,'sermaye',s.sermaye,
    'mevduat_anapara',a,'mevduat_yukumluluk',y,'yaklasan_odeme',yak,
    'riskli_kredi_varligi',round(al,2),'tampon',tampon,
    'asgari_likidite',round(rezerv,2),'kredi_verilebilir',round(limit_k,2),
    'dagitilabilir_kar',greatest(0,round(s.kasa-s.sermaye-y,2)));
end $$;

create or replace function public.oyb_liste()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('bankalar',coalesce((
 select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,
   'faiz',s.banka_faiz,'kredi_faiz',s.banka_kredi_faiz,
   'bankam',exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>0),
   'oranlar',jsonb_build_object('1',oyun.oyb_oran(s.id,1),'3',oyun.oyb_oran(s.id,3),
     '6',oyun.oyb_oran(s.id,6),'12',oyun.oyb_oran(s.id,12),
     '24',oyun.oyb_oran(s.id,24),'168',s.banka_faiz))
   order by s.id) from oyun.sirketler s where s.sektor='banka' and s.aktif
 ),'[]'::jsonb));
end $$;

create or replace function public.oyb_teklif(p_banka bigint,p_tutar numeric,p_saat integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s oyun.sirketler; f numeric; yeni numeric; y numeric; a numeric; al numeric; tampon numeric; uygun boolean;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1000 or p_tutar>10000000 then
  raise exception 'Tutar 1.000 - 10.000.000 TL arasinda tam sayi olmali';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif;
 if not found then raise exception 'Banka bulunamadi';end if;
 f:=oyun.oyb_oran(p_banka,p_saat);
 yeni:=round(p_tutar*(1+f/100));
 select coalesce(sum(round(anapara*(1+faiz/100))),0),coalesce(sum(anapara),0)
 into y,a from oyun.banka_mevduat where banka_id=p_banka and not kapandi;
 select coalesce(sum(least(kalan,anapara) * case when vade<oyun.simdi() then .25 else .70 end),0)
 into al from oyun.oyb_kredi where banka_id=p_banka and durum='aktif';
 tampon:=greatest(s.sermaye*.10,(a+p_tutar)*.10);
 uygun:=not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
   and not exists(select 1 from oyun.banka_mevduat where banka_id=p_banka and not kapandi and vade<=oyun.simdi())
   and s.kasa+p_tutar+al>=y+yeni+tampon;
 return jsonb_build_object('banka',s.ad,'saat',p_saat,'oran',f,
  'tutar',p_tutar,'faiz_kazanci',yeni-p_tutar,'vade_sonu_odeme',yeni,
  'odeme_gucu_yeterli',uygun,'vade',oyun.simdi()+make_interval(hours=>p_saat),
  'uyari',case when uygun then 'Yeni mevduat icin banka sermayesi ve mevcut yukumlulukler kontrol edildi; kredi riski devam eder.'
    else 'Banka yeni mevduat kabul edecek mali yeterlilikte degil veya kendi bankana yatirmaya calisiyorsun.' end);
end $$;

create or replace function public.oyb_yatir(p_banka bigint,p_tutar numeric,p_saat integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s oyun.sirketler;t timestamptz:=oyun.simdi();f numeric; yeni numeric;y numeric;a numeric;al numeric;tampon numeric;x bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1000 or p_tutar>10000000 then
  raise exception 'Tutar 1.000 - 10.000.000 TL arasinda tam sayi olmali';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if not found then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Kendi bankana faizli mevduat yatiramazsin';end if;
 if exists(select 1 from oyun.banka_mevduat where banka_id=p_banka and not kapandi and vade<=t)
 then raise exception 'Bankanin gecikmis odemesi var; yeni mevduat kabul edilemiyor';end if;
 f:=oyun.oyb_oran(p_banka,p_saat); yeni:=round(p_tutar*(1+f/100));
 select coalesce(sum(round(anapara*(1+faiz/100))),0),coalesce(sum(anapara),0)
 into y,a from oyun.banka_mevduat where banka_id=p_banka and not kapandi;
 select coalesce(sum(least(kalan,anapara) * case when vade<t then .25 else .70 end),0)
 into al from oyun.oyb_kredi where banka_id=p_banka and durum='aktif';
 tampon:=greatest(s.sermaye*.10,(a+p_tutar)*.10);
 if s.kasa+p_tutar+al<y+yeni+tampon
 then raise exception 'Bankanin yeni mevduat ve faiz yukumlulugunu karsilayacak mali gucu yok';end if;
 perform oyun.para_islem(u,-p_tutar,'mevduat','Oyuncu bankasina '||p_saat||' saat vadeli yatirim',t);
 update oyun.sirketler set kasa=kasa+p_tutar where id=p_banka;
 insert into oyun.banka_mevduat(banka_id,user_id,anapara,faiz,acilis,vade,vade_saat)
 values(p_banka,u,p_tutar,f,t,t+make_interval(hours=>p_saat),p_saat) returning id into x;
 return jsonb_build_object('id',x,'vade',t+make_interval(hours=>p_saat),'odeme',yeni);
end $$;

create or replace function public.oyb_portfoy()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 -- Eski tahsil mekanizmasi 1/3/6/12/24 saatlik mevduatlari da odeyebilir.
 perform public.banka_mevduat_tahsil();
 return jsonb_build_object(
 'mevduatlar',coalesce((select jsonb_agg(jsonb_build_object(
   'id',m.id,'banka_id',m.banka_id,'banka',s.ad,
   'anapara',m.anapara,'oran',m.faiz,'getiri',round(m.anapara*m.faiz/100),
   'odeme',round(m.anapara*(1+m.faiz/100)),'saat',m.vade_saat,
   'acilis',m.acilis,'vade',m.vade,'kapandi',m.kapandi,'iptal',m.iptal,
   'cekilebilir',m.kapandi=false and s.kasa>=case when t<m.vade then m.anapara else round(m.anapara*(1+m.faiz/100)) end,
   'durum',case when m.iptal then 'erken_bozuldu' when m.kapandi then 'odendi'
     when m.vade<=t then 'odeme_bekliyor' else 'aktif' end)
    order by m.id desc)
  from (select * from oyun.banka_mevduat where user_id=u order by id desc limit 30)m
    join oyun.sirketler s on s.id=m.banka_id),'[]'::jsonb),
 'krediler',coalesce((select jsonb_agg(jsonb_build_object(
  'id',k.id,'banka',s.ad,'anapara',k.anapara,'toplam',k.toplam,
  'kalan',k.kalan,'oran',k.oran,'vade',k.vade,'durum',
  case when k.durum='aktif' and k.vade<t then 'gecikmis' else k.durum end)
  order by k.id desc) from (select * from oyun.oyb_kredi where borclu=u order by id desc limit 20) k
  join oyun.sirketler s on s.id=k.banka_id),'[]'::jsonb));
end $$;

create or replace function public.oyb_mevduat_cek(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();m oyun.banka_mevduat;s oyun.sirketler;t timestamptz:=oyun.simdi();odeme numeric;erken boolean;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into m from oyun.banka_mevduat where id=p_id and user_id=u;
 if not found then raise exception 'Mevduat bulunamadi';end if;
 select * into s from oyun.sirketler where id=m.banka_id for update;
 select * into m from oyun.banka_mevduat where id=p_id and user_id=u for update;
 if m.kapandi then raise exception 'Bu mevduat daha once odendi veya kapatildi';end if;
 erken:=t<m.vade; odeme:=case when erken then m.anapara else round(m.anapara*(1+m.faiz/100)) end;
 update oyun.sirketler set kasa=kasa-odeme where id=m.banka_id and kasa>=odeme;
 if not found then raise exception 'Banka kasasinda su an odeme icin yeterli nakit yok; mevduatin kayitli, daha sonra tekrar dene';end if;
 update oyun.banka_mevduat set kapandi=true,iptal=erken where id=m.id;
 perform oyun.para_islem(u,odeme,'mevduat',
  case when erken then 'Oyuncu bankasi erken bozma (faizsiz)'
  else 'Oyuncu bankasi anapara ve vade faizi' end,t);
 return jsonb_build_object('tamam',true,'erken',erken,'odenen',odeme);
end $$;

create or replace function public.oyb_oran_ayarla(p_banka bigint,p_saat integer,p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();cap numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id=o.sirket_id
   where s.id=p_banka and s.sektor='banka' and s.aktif and o.user_id=u and o.pay>=50)
 then raise exception 'Banka yonetim yetkin yok (en az %%50 pay gerekir)';end if;
 cap:=case p_saat when 1 then .25 when 3 then .80 when 6 then 1.75
   when 12 then 4 when 24 then 8 else null end;
 if cap is null or p_oran is null or p_oran<0 or p_oran>cap
   or p_oran<>round(p_oran,2)
 then raise exception 'Bu vade icin faiz orani gecersiz veya siniri asiyor';end if;
 insert into oyun.oyb_vade_oran(banka_id,saat,oran)
 values(p_banka,p_saat,p_oran) on conflict(banka_id,saat)
 do update set oran=excluded.oran;
 return jsonb_build_object('tamam',true,'saat',p_saat,'oran',p_oran,'ust_sinir',cap);
end $$;
revoke all on function public.oyb_liste(),public.oyb_teklif(bigint,numeric,integer),
 public.oyb_yatir(bigint,numeric,integer),public.oyb_portfoy(),public.oyb_mevduat_cek(bigint),
 public.oyb_oran_ayarla(bigint,integer,numeric) from public,anon;
grant execute on function public.oyb_liste(),public.oyb_teklif(bigint,numeric,integer),
 public.oyb_yatir(bigint,numeric,integer),public.oyb_portfoy(),public.oyb_mevduat_cek(bigint),
 public.oyb_oran_ayarla(bigint,integer,numeric) to authenticated;


-- ---- 20261008_oyuncu_banka_kredileri ----
-- Oyuncu banka kredisi: yalnizca diger GERCEK oyunculara, banka kasasindan.
-- Talep/karar/odeme sunucu tarafinda atomik, ortak parasi oyuncunun cebine aktarilmaz.
create or replace function public.oyb_kredi_basvur(p_banka bigint,p_tutar numeric,p_saat integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s oyun.sirketler; oran numeric; toplam numeric; x bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1000 or p_tutar>500000
 then raise exception 'Kredi 1.000 - 500.000 TL arasinda tam TL olmali';end if;
 if p_saat not in (1,3,6,12,24) or p_saat is null then raise exception 'Vade 1, 3, 6, 12 ya da 24 saat';end if;
 select * into s from oyun.sirketler where id=p_banka and aktif and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Kendi bankandan kredi alamazsin';end if;
 if exists(select 1 from oyun.oyb_kredi where borclu=u and durum in ('basvuru','aktif'))
 then raise exception 'Once diger oyuncu banka kredini kapat veya cevabini bekle';end if;
 if exists(select 1 from oyun.krediler where user_id=u and durum='takip')
 then raise exception 'Yasal takipteki banka kredin nedeniyle yeni kredi alamazsin';end if;
 oran:=round(s.banka_kredi_faiz*p_saat/24,2);
 if oran<0 or oran>20 then raise exception 'Banka kredi faizi gecersiz';end if;
 toplam:=round(p_tutar*(1+oran/100));
 insert into oyun.oyb_kredi(banka_id,borclu,anapara,saat,oran,toplam,kalan)
 values(p_banka,u,p_tutar,p_saat,oran,toplam,toplam) returning id into x;
 return jsonb_build_object('id',x,'anapara',p_tutar,'toplam',toplam,
  'oran',oran,'saat',p_saat,'durum','basvuru');
end $$;

create or replace function public.oyb_kredi_karar(p_id bigint,p_onay boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();k oyun.oyb_kredi;s oyun.sirketler;t timestamptz:=oyun.simdi();r jsonb;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_onay is null then raise exception 'Karar eksik';end if;
 select * into k from oyun.oyb_kredi where id=p_id;
 if not found then raise exception 'Kredi basvurusu bulunamadi';end if;
 if not exists(select 1 from oyun.sirket_ortaklari o
  where o.sirket_id=k.banka_id and o.user_id=u and o.pay>=50)
 then raise exception 'Bu bankanin kredi yonetim yetkin yok';end if;
 select * into s from oyun.sirketler where id=k.banka_id and aktif and sektor='banka' for update;
 if not found then raise exception 'Banka artik faal degil';end if;
 select * into k from oyun.oyb_kredi where id=p_id for update;
 if k.durum<>'basvuru' then raise exception 'Bu basvuru zaten karara baglandi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=k.banka_id and user_id=k.borclu and pay>0)
 then raise exception 'Banka ortaklarina veya yoneticilerine kredi kullandirilamaz';end if;
 if not p_onay then
   update oyun.oyb_kredi set durum='reddedildi',kapanis=t where id=k.id;
   return jsonb_build_object('tamam',true,'onay',false);
 end if;
 if exists(select 1 from oyun.banka_mevduat where banka_id=s.id and not kapandi and vade<=t)
 then raise exception 'Gecikmis mevduat odemeleri varken kredi verilemez';end if;
 r:=oyun.oyb_saglik(s.id);
 if k.anapara>(r->>'kredi_verilebilir')::numeric
 then raise exception 'Bankanin kredilendirmeye ayirabilecegi guvenli likidite yetersiz';end if;
 update oyun.sirketler set kasa=kasa-k.anapara where id=s.id and kasa>=k.anapara;
 if not found then raise exception 'Banka kasasinda para yok';end if;
 update oyun.oyb_kredi set durum='aktif',acilis=t,
   vade=t+make_interval(hours=>k.saat)
   where id=k.id;
 perform oyun.para_islem(k.borclu,k.anapara,'oyb_kredi','Oyuncu bankasindan kredi #'||k.id,t);
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama)
 values(s.id,0,'Oyuncu kredisi #'||k.id||' verildi: '||k.anapara||' TL');
 perform oyun.bildir(k.borclu,'Oyuncu bankasi kredi basvurun kabul edildi. Geri odeme tutari: '||k.toplam||' TL.',t);
 return jsonb_build_object('tamam',true,'onay',true,'vade',t+make_interval(hours=>k.saat));
end $$;

create or replace function public.oyb_kredi_ode(p_id bigint,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();k oyun.oyb_kredi;s oyun.sirketler;t timestamptz:=oyun.simdi();
  ode numeric; anapara_bolum numeric;faiz_bolum numeric;yeni numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1 or p_tutar>1000000
 then raise exception 'Odeme pozitif tam TL olmali';end if;
 select * into k from oyun.oyb_kredi where id=p_id and borclu=u;
 if not found then raise exception 'Kredi bulunamadi';end if;
 select * into s from oyun.sirketler where id=k.banka_id for update;
 select * into k from oyun.oyb_kredi where id=p_id and borclu=u for update;
 if k.durum<>'aktif' then raise exception 'Kredi aktif degil';end if;
 ode:=least(p_tutar,k.kalan);
 perform oyun.para_islem(u,-ode,'oyb_kredi','Oyuncu bankasi kredi geri odeme #'||k.id,t);
 update oyun.sirketler set kasa=kasa+ode where id=k.banka_id;
 anapara_bolum:=least(ode,greatest(0,k.anapara-k.anapara_odendi));
 faiz_bolum:=ode-anapara_bolum;
 yeni:=k.kalan-ode;
 update oyun.oyb_kredi set kalan=yeni,anapara_odendi=anapara_odendi+anapara_bolum,
   durum=case when yeni<=0 then 'odendi' else 'aktif' end,
   kapanis=case when yeni<=0 then t else null end
 where id=k.id;
 if faiz_bolum>0 then
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama)
 values(k.banka_id,faiz_bolum,'Oyuncu kredisi #'||k.id||' tahsil edilen faiz geliri');
 end if;
 return jsonb_build_object('odendi',ode,'kalan',yeni,
   'tamam',yeni<=0,'faiz_geliri',faiz_bolum);
end $$;

create or replace function public.oyb_kredi_faiz_ayarla(p_banka bigint,p_faiz numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_faiz is null or p_faiz<0 or p_faiz>12 or p_faiz<>round(p_faiz,2)
 then raise exception '24 saatlik kredi faizi 0-12 arasinda olmali';end if;
 update oyun.sirketler s set banka_kredi_faiz=p_faiz
 where id=p_banka and sektor='banka' and aktif and exists(
  select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50);
 if not found then raise exception 'Banka yonetim yetkin yok';end if;
 return jsonb_build_object('tamam',true,'kredi_faiz_24s',p_faiz);
end $$;

create or replace function public.oyb_yonetim(p_banka bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s oyun.sirketler;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Banka ortagi degilsin';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 return jsonb_build_object('id',s.id,'ad',s.ad,'yonetebilir',
 exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>=50),
 'kredi_faiz',s.banka_kredi_faiz,'oranlar',jsonb_build_object(
 '1',oyun.oyb_oran(p_banka,1),'3',oyun.oyb_oran(p_banka,3),'6',oyun.oyb_oran(p_banka,6),
 '12',oyun.oyb_oran(p_banka,12),'24',oyun.oyb_oran(p_banka,24),'168',s.banka_faiz),
 'durum',oyun.oyb_saglik(p_banka),
 'krediler',coalesce((select jsonb_agg(jsonb_build_object('id',k.id,
  'borclu',coalesce(p.kad,'Oyuncu'), 'anapara',k.anapara,'toplam',k.toplam,
  'kalan',k.kalan,'oran',k.oran,'saat',k.saat,'vade',k.vade,
  'durum',case when k.durum='aktif' and k.vade<oyun.simdi() then 'gecikmis' else k.durum end)
  order by k.id desc) from (select * from oyun.oyb_kredi where banka_id=p_banka order by id desc limit 40)k
  left join oyun.profiller p on p.id=k.borclu),'[]'::jsonb),
 'hareketler',coalesce((select jsonb_agg(jsonb_build_object(
   'tutar',h.tutar,'aciklama',h.aciklama,'zaman',h.zaman) order by h.id desc)
   from (select * from oyun.sirket_hareket where sirket_id=p_banka order by id desc limit 20)h),'[]'::jsonb));
end $$;
revoke all on function public.oyb_kredi_basvur(bigint,numeric,integer),
 public.oyb_kredi_karar(bigint,boolean),public.oyb_kredi_ode(bigint,numeric),
 public.oyb_kredi_faiz_ayarla(bigint,numeric),public.oyb_yonetim(bigint)
 from public,anon;
grant execute on function public.oyb_kredi_basvur(bigint,numeric,integer),
 public.oyb_kredi_karar(bigint,boolean),public.oyb_kredi_ode(bigint,numeric),
 public.oyb_kredi_faiz_ayarla(bigint,numeric),public.oyb_yonetim(bigint)
 to authenticated;


-- ---- 20261008_oyuncu_banka_odeme_duzeltme ----
-- Eski 7 gunluk ve yeni saatlik mevduatlari ayni odeme mantigi ile tahsil et.
-- Banka satiri daima mevduat satirindan once kilitlenir. Cuzdan tam TL calisir.
create or replace function public.banka_mevduat_tahsil()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();t timestamptz:=oyun.simdi(); b record; m oyun.banka_mevduat; odeme numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 for b in select distinct banka_id from oyun.banka_mevduat
   where user_id=u and not kapandi and vade<=t order by banka_id loop
  perform 1 from oyun.sirketler where id=b.banka_id for update;
  for m in select * from oyun.banka_mevduat
    where banka_id=b.banka_id and user_id=u and not kapandi and vade<=t
    order by vade,id for update loop
    odeme:=round(m.anapara*(1+m.faiz/100));
    update oyun.sirketler set kasa=kasa-odeme
      where id=m.banka_id and kasa>=odeme;
    if found then
      perform oyun.para_islem(u,odeme,'mevduat',
        'Oyuncu bankasi vadeli mevduat ve faiz odemesi',t);
      update oyun.banka_mevduat set kapandi=true where id=m.id;
    end if;
  end loop;
 end loop;
 return jsonb_build_object('mevduatlar',coalesce((
  select jsonb_agg(jsonb_build_object('id',id,'banka',banka_id,
   'tutar',anapara,'faiz',faiz,'vade',vade,'odendi',kapandi,'iptal',iptal,
   'durum',case when iptal then 'anapara_iade' when kapandi then 'odendi'
    when vade<=t then 'banka_odeme_bekliyor' else 'vadede' end)
   order by id desc)
  from oyun.banka_mevduat where user_id=u),'[]'::jsonb));
end $$;
revoke all on function public.banka_mevduat_tahsil() from public,anon;
grant execute on function public.banka_mevduat_tahsil() to authenticated;


-- ---- 20261008_oyuncu_banka_kredi_ortak_koruma ----
-- Applied after the initial loan migration to prevent related-party credit.
create or replace function public.oyb_kredi_karar(p_id bigint,p_onay boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();k oyun.oyb_kredi;s oyun.sirketler;t timestamptz:=oyun.simdi();r jsonb;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_onay is null then raise exception 'Karar eksik';end if;
 select * into k from oyun.oyb_kredi where id=p_id;
 if not found then raise exception 'Kredi basvurusu bulunamadi';end if;
 if not exists(select 1 from oyun.sirket_ortaklari o
  where o.sirket_id=k.banka_id and o.user_id=u and o.pay>=50)
 then raise exception 'Bu bankanin kredi yonetim yetkin yok';end if;
 select * into s from oyun.sirketler where id=k.banka_id and aktif and sektor='banka' for update;
 if not found then raise exception 'Banka artik faal degil';end if;
 select * into k from oyun.oyb_kredi where id=p_id for update;
 if k.durum<>'basvuru' then raise exception 'Bu basvuru zaten karara baglandi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=k.banka_id and user_id=k.borclu and pay>0)
 then raise exception 'Banka ortaklarina veya yoneticilerine kredi kullandirilamaz';end if;
 if not p_onay then
   update oyun.oyb_kredi set durum='reddedildi',kapanis=t where id=k.id;
   return jsonb_build_object('tamam',true,'onay',false);
 end if;
 if exists(select 1 from oyun.banka_mevduat where banka_id=s.id and not kapandi and vade<=t)
 then raise exception 'Gecikmis mevduat odemeleri varken kredi verilemez';end if;
 r:=oyun.oyb_saglik(s.id);
 if k.anapara>(r->>'kredi_verilebilir')::numeric
 then raise exception 'Bankanin kredilendirmeye ayirabilecegi guvenli likidite yetersiz';end if;
 update oyun.sirketler set kasa=kasa-k.anapara where id=s.id and kasa>=k.anapara;
 if not found then raise exception 'Banka kasasinda para yok';end if;
 update oyun.oyb_kredi set durum='aktif',acilis=t,
   vade=t+make_interval(hours=>k.saat)
   where id=k.id;
 perform oyun.para_islem(k.borclu,k.anapara,'oyb_kredi','Oyuncu bankasindan kredi #'||k.id,t);
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama)
 values(s.id,0,'Oyuncu kredisi #'||k.id||' verildi: '||k.anapara||' TL');
 perform oyun.bildir(k.borclu,'Oyuncu bankasi kredi basvurun kabul edildi. Geri odeme tutari: '||k.toplam||' TL.',t);
 return jsonb_build_object('tamam',true,'onay',true,'vade',t+make_interval(hours=>k.saat));
end $$;



-- ---- 20261008_adaylik_parti_uyelik_tarihi_duzeltme ----
-- Fix: partiye basvuru acildiktan sonra katilan oyuncular da basvuru kapanana kadar aday olabilir.
-- Mevcut secim/aday kayitlarini degistirmez; yalnizca function definition.
CREATE OR REPLACE FUNCTION public.aday_ol(p_tur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  k oyun.cb_kararlar;
begin
  if p_tur not in ('mv_on','bel_on','kurultay','cb_on') then
    raise exception 'Geçersiz adaylık türü.';
  end if;

  select * into s
  from oyun.secimler
  where tur = p_tur
    and t >= basvuru_bas
    and t < basvuru_bit
    and (
      not ara
      or (p_tur = 'bel_on' and hedef_il_id = p.il_id)
      or (p_tur = 'kurultay' and hedef_parti_id = p.parti_id)
      or p_tur = 'cb_on'
    )
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Bu adaylık için başvuru şu anda açık değil.';
  end if;
  if p.parti_id is null then
    raise exception 'Aday olmak için bir partiye üye olmalısın.';
  end if;
  -- Basvuru suresi dolana kadar katilan her mevcut parti uyesi aday olabilir.
  -- Parti uyeligi, basvuru takvimi ve diger oyun sartlari korunur.
  if oyun.uyari(p,t) is not null then
    raise exception '%', oyun.uyari(p,t);
  end if;
  if (select kurulus_bit from oyun.partiler where id = p.parti_id) is not null then
    raise exception 'Partin henüz kuruluş aşamasında: kurucu üye sayısı tamamlanmadan seçime katılamaz.';
  end if;

  if s.ara and s.hedef_il_id is not null
     and p.il_id is distinct from s.hedef_il_id then
    raise exception 'Bu ara seçim senin ilin için değil.';
  end if;

  if s.ara and s.hedef_parti_id is not null
     and p.parti_id is distinct from s.hedef_parti_id then
    raise exception 'Bu olağanüstü kurultay senin partin için değil.';
  end if;

  if p_tur='bel_on'
     and exists(select 1 from oyun.partiler where gb = p.id) then
    raise exception 'Genel başkan belediye başkanı adayı olamaz; milletvekili adaylığı serbesttir.';
  end if;

  if oyun.teskilat_engeli(p,p_tur) is not null then
    raise exception '%', oyun.teskilat_engeli(p,p_tur);
  end if;

  if p_tur = 'cb_on' then
    select * into k
    from oyun.cb_kararlar
    where donem = s.donem and parti_id = p.parti_id;

    if k.yontem in ('kendisi','baskasi') then
      raise exception 'Genel başkan cumhurbaşkanı adayını doğrudan belirledi; ön seçim yapılmayacak.';
    end if;
    if k.yontem = 'destek' then
      raise exception 'Partin cumhurbaşkanlığında ittifak ortağının adayını destekliyor; ön seçim yapılmayacak.';
    end if;
  end if;

  insert into oyun.adaylar(
    secim_id, user_id, parti_id, il_id, basvuru_at
  )
  values (
    s.id, p.id, p.parti_id,
    case when p_tur in ('mv_on','bel_on') then p.il_id end,
    t
  )
  on conflict(secim_id,user_id) do nothing;

  if not found then
    raise exception 'Bu seçime zaten başvurdun.';
  end if;

  perform oyun.aday_ucreti_al(p,p_tur,t);
  return public.durum();
end $function$
;


-- ---- 20261008_mulk_alis_vergi_ve_haftalik_kira_duzeltmesi ----
-- Gayrimenkul pazarindaki ambiguous "vergi" SQL degiskeni duzeltildi.
-- Alim/satim, ilgili odeme ve %2 satis vergisi ayni kalir.
CREATE OR REPLACE FUNCTION public.mulk_ilan_satin_al(p_ilan bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); a oyun.mulk_ilan%rowtype; m oyun.yatirim_mulkleri%rowtype;
 v_satis_vergisi numeric; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 select * into a from oyun.mulk_ilan where id=p_ilan for update;
 if not found or a.durum<>'acik' then raise exception 'İlan artık açık değil'; end if;
 if a.satici=u then raise exception 'Kendi mülkünü satın alamazsın'; end if;
 select * into m from oyun.yatirim_mulkleri where id=a.mulk_id for update;
 if not found or m.user_id<>a.satici then raise exception 'Satıcı artık mülkün sahibi değil'; end if;
 perform oyun.mulk_kira_tahsil(a.satici);
 v_satis_vergisi:=round(a.fiyat*0.02);
 perform oyun.para_islem(u,-a.fiyat,'emlak','Oyuncudan mülk satın alındı #'||a.mulk_id,t);
 perform oyun.para_islem(a.satici,a.fiyat-v_satis_vergisi,'emlak','Mülk satışı #'||a.mulk_id,t);
 update oyun.ulke set hazine=hazine+v_satis_vergisi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=u,satin_alma=t,alis_bedeli=a.fiyat,
   sonraki_kira=t+interval '7 days',toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=u,kapanma=t where id=a.id;
 perform oyun.bildir(a.satici,'Satıştaki mülkün satıldı. Satış vergisi %2.',t);
 return public.mulk_pazar();
end $function$
;

-- Yeni gayrimenkul haftalik kira getirisi %2,5.
CREATE OR REPLACE FUNCTION public.mulk_satin_al(p_tip text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü'; end if;
 bedel:=case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end;
 kira:=round(bedel*0.025,2); -- %2,5 / hafta: sabit emlak kira dengesi
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s satın alındı',p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p.il_id,p_tip,bedel,kira,t,t+interval '7 days');
 return public.mulk_liste();
end $function$
;

-- Eski mulklerde yalnizca gelecek kira tutarlari olceklenir.
-- Kazanilmis/toplanmis kira, oyuncu cuzdanlari, sahiplik, sonraki_kira ve mevcut ilanlar degismez.
create table if not exists oyun.mulk_kira_denge_kayit (
 mulk_id bigint primary key references oyun.yatirim_mulkleri(id),
 eski_haftalik numeric not null,
 yeni_haftalik numeric not null,
 degisim_zamani timestamptz not null default now()
);
insert into oyun.mulk_kira_denge_kayit(mulk_id,eski_haftalik,yeni_haftalik)
 select id, haftalik_kira, round(alis_bedeli*0.025,2)
 from oyun.yatirim_mulkleri
 where haftalik_kira is distinct from round(alis_bedeli*0.025,2)
 on conflict(mulk_id) do nothing;
update oyun.yatirim_mulkleri m
set haftalik_kira=round(m.alis_bedeli*0.025,2)
where m.haftalik_kira is distinct from round(m.alis_bedeli*0.025,2);
alter table oyun.mulk_kira_denge_kayit enable row level security;
revoke all on oyun.mulk_kira_denge_kayit from public,anon,authenticated;


-- ---- 20261008_banka_yeni_kurulus_ve_eski_api_faiz_koruma ----
-- Her yeni oyuncu bankasi ekonomik limitli faizle acilir.
-- Yeni bankalar sonradan eski yuksek varsayilan faizle kurulamasin.
alter table oyun.sirketler alter column banka_faiz set default 1.5;
alter table oyun.sirketler alter column banka_kredi_faiz set default 0.6;
-- Banka kurulusu daha once acilmissa ve eski varsayilan faizleri aliyorsa indir.
update oyun.sirketler set banka_faiz=least(banka_faiz,1.8),
 banka_kredi_faiz=least(banka_kredi_faiz,1.0)
where sektor='banka' and (banka_faiz>1.8 or banka_kredi_faiz>1.0);

-- Eski cached uygulama da 7 gunde %3 teklif etmesin.
CREATE OR REPLACE FUNCTION public.banka_mevduat_teklif(p_banka bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;v_borc numeric;v_anapara numeric;v_odeme numeric;v_guvence numeric;v_uygun boolean;v_ortak boolean;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into s from oyun.sirketler where id=p_banka and aktif and sektor='banka';
 if s.id is null then raise exception 'Banka bulunamadi';end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<1000 or p_tutar>10000000 then
  raise exception 'Mevduat tutari 1.000 - 10.000.000 TL olmali';end if;
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0)
 into v_borc,v_anapara from oyun.banka_mevduat m where m.banka_id=p_banka and not m.kapandi;
 v_odeme:=round(p_tutar*(1+s.banka_faiz/100));
 v_guvence:=greatest(s.sermaye*0.10,(v_anapara+p_tutar)*0.10);
 v_ortak:=exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=p_banka and o.user_id=u and o.pay>0);
 v_uygun:=not v_ortak and s.banka_faiz between 0 and 1.8
       and s.kasa >= v_borc+(v_odeme-p_tutar)+v_guvence;
 return jsonb_build_object(
  'banka',s.ad,'tutar',p_tutar,'haftalik_faiz',s.banka_faiz,
  'vade_sonu_odeme',v_odeme,'faiz_kazanci',v_odeme-p_tutar,
  'kasa',s.kasa,'acik_taahhut',v_borc,'zorunlu_tampon',v_guvence,
  'bankam',v_ortak,'odeme_garantisi_icin_yeterli',v_uygun,
  'uyari',case when v_ortak then 'Kendi bankana mevduat yatiramazsin'
              when not v_uygun then 'Bu tutarin vade sonu faizi kasada guvenceye alinmis degil'
              else 'Vade sonu odeme tutari bankanin kasasinda guvenceye alindi' end);
end $function$
;
CREATE OR REPLACE FUNCTION public.banka_mevduat_yatir(p_banka bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;t timestamptz:=oyun.simdi();
        v_borc numeric; v_anapara numeric; v_yeni_borc numeric; v_guvence numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<1000 or p_tutar>10000000
 then raise exception 'Mevduat 1.000 - 10.000.000 TL arasinda tam sayi olmali';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if s.id is null then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari o
           where o.sirket_id=p_banka and o.user_id=u and o.pay>0)
 then raise exception 'Kendi bankana faizli mevduat yatiramazsin; baska bir oyuncu bankasi sec';end if;
 if s.banka_faiz<0 or s.banka_faiz>1.8 then raise exception 'Banka faiz sinirini asiyor';end if;
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),
        coalesce(sum(m.anapara),0)
 into v_borc,v_anapara from oyun.banka_mevduat m where m.banka_id=p_banka and not m.kapandi;
 v_yeni_borc:=round(p_tutar*(1+s.banka_faiz/100));
 v_guvence:=greatest(s.sermaye*0.10,(v_anapara+p_tutar)*0.10);
 -- After deposit: cash=old cash+principal; liabilities=old liabilities+principal+interest.
 -- Preserve a funded 10 percent reserve on capital and all deposits.
 if s.kasa < v_borc+(v_yeni_borc-p_tutar)+v_guvence
 then raise exception 'Banka likiditesi/teminati yetersiz. Mevduat kabul edilemiyor';end if;
 perform oyun.para_islem(u,-p_tutar,'mevduat','Oyuncu bankasina 7 gun vadeli mevduat',t);
 update oyun.sirketler set kasa=kasa+p_tutar where id=p_banka;
 insert into oyun.banka_mevduat(banka_id,user_id,anapara,faiz,vade)
 values(p_banka,u,p_tutar,s.banka_faiz,t+interval '7 days');
 return jsonb_build_object('tamam',true,'banka',p_banka,'faiz',s.banka_faiz,'vade',t+interval '7 days');
end $function$
;
CREATE OR REPLACE FUNCTION public.oyuncu_banka_liste()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object('bankalar',coalesce(jsonb_agg(jsonb_build_object('id',id,'ad',ad,'faiz',least(banka_faiz,1.8),'kasa',kasa) order by id),'[]'::jsonb))
 from oyun.sirketler where sektor='banka' and aktif
$function$
;

-- Diger hesaplarda da teklif ile gorunen degerler ayni limite uysun.
CREATE OR REPLACE FUNCTION public.oyb_kredi_basvur(p_banka bigint, p_tutar numeric, p_saat integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler; oran numeric; toplam numeric; x bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1000 or p_tutar>500000
 then raise exception 'Kredi 1.000 - 500.000 TL arasinda tam TL olmali';end if;
 if p_saat not in (1,3,6,12,24) or p_saat is null then raise exception 'Vade 1, 3, 6, 12 ya da 24 saat';end if;
 select * into s from oyun.sirketler where id=p_banka and aktif and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Kendi bankandan kredi alamazsin';end if;
 if exists(select 1 from oyun.oyb_kredi where borclu=u and durum in ('basvuru','aktif'))
 then raise exception 'Once diger oyuncu banka kredini kapat veya cevabini bekle';end if;
 if exists(select 1 from oyun.krediler where user_id=u and durum='takip')
 then raise exception 'Yasal takipteki banka kredin nedeniyle yeni kredi alamazsin';end if;
 oran:=round(least(s.banka_kredi_faiz,1.0)*p_saat/24,2);
 if oran<0 or oran>20 then raise exception 'Banka kredi faizi gecersiz';end if;
 toplam:=round(p_tutar*(1+oran/100));
 insert into oyun.oyb_kredi(banka_id,borclu,anapara,saat,oran,toplam,kalan)
 values(p_banka,u,p_tutar,p_saat,oran,toplam,toplam) returning id into x;
 return jsonb_build_object('id',x,'anapara',p_tutar,'toplam',toplam,
  'oran',oran,'saat',p_saat,'durum','basvuru');
end $function$
;
CREATE OR REPLACE FUNCTION public.oyb_liste()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('bankalar',coalesce((
 select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,
   'faiz',least(s.banka_faiz,1.8),'kredi_faiz',least(s.banka_kredi_faiz,1.0),
   'bankam',exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>0),
   'oranlar',jsonb_build_object('1',oyun.oyb_oran(s.id,1),'3',oyun.oyb_oran(s.id,3),
     '6',oyun.oyb_oran(s.id,6),'12',oyun.oyb_oran(s.id,12),
     '24',oyun.oyb_oran(s.id,24),'168',oyun.oyb_oran(s.id,168)))
   order by s.id) from oyun.sirketler s where s.sektor='banka' and s.aktif
 ),'[]'::jsonb));
end $function$
;
CREATE OR REPLACE FUNCTION public.oyb_yonetim(p_banka bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Banka ortagi degilsin';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 return jsonb_build_object('id',s.id,'ad',s.ad,'yonetebilir',
 exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>=50),
 'kredi_faiz',least(s.banka_kredi_faiz,1.0),'oranlar',jsonb_build_object(
 '1',oyun.oyb_oran(p_banka,1),'3',oyun.oyb_oran(p_banka,3),'6',oyun.oyb_oran(p_banka,6),
 '12',oyun.oyb_oran(p_banka,12),'24',oyun.oyb_oran(p_banka,24),'168',oyun.oyb_oran(p_banka,168)),
 'durum',oyun.oyb_saglik(p_banka),
 'krediler',coalesce((select jsonb_agg(jsonb_build_object('id',k.id,
  'borclu',coalesce(p.kad,'Oyuncu'), 'anapara',k.anapara,'toplam',k.toplam,
  'kalan',k.kalan,'oran',k.oran,'saat',k.saat,'vade',k.vade,
  'durum',case when k.durum='aktif' and k.vade<oyun.simdi() then 'gecikmis' else k.durum end)
  order by k.id desc) from (select * from oyun.oyb_kredi where banka_id=p_banka order by id desc limit 40)k
  left join oyun.profiller p on p.id=k.borclu),'[]'::jsonb),
 'hareketler',coalesce((select jsonb_agg(jsonb_build_object(
   'tutar',h.tutar,'aciklama',h.aciklama,'zaman',h.zaman) order by h.id desc)
   from (select * from oyun.sirket_hareket where sirket_id=p_banka order by id desc limit 20)h),'[]'::jsonb));
end $function$
;


-- ---- 20261008_devlet_oyuncu_banka_faiz_dengesi ----
-- Banka vadeleri karsilastirilabilir getiride. Yillik politika faizi gun/saat esasina bolunur.
-- Mevcut vadeli kontratlarin oran/anaparalari ASLA degistirilmez.
CREATE OR REPLACE FUNCTION oyun.banka_oranlar()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with x as (
    select greatest(15,round(u.enflasyon+a.banka_reel_faiz,1)) py
    from oyun.ulke u, oyun.ayarlar a
    where u.id=1 and a.id=1
  )
  select jsonb_build_object(
    'politika',py,'vadesiz',0,
    'vadeli1s',round(py / 365.0 / 24.0,3),
    'vadeli3s',round(py / 365.0 * 3 / 24.0,3),
    'vadeli6s',round(py / 365.0 * 6 / 24.0,3),
    'vadeli12s',round(py / 365.0 * 12 / 24.0,3),
    'vadeli24s',round(py / 365.0,3),
    'vadeli7',round(py / 365.0 * 7,3),
    'vadeli30',round(py / 365.0 * 30,3),
    'kredi',round(py/12*1.60,2),
    'gecikme_gunluk',1
  ) from x
$function$
;

-- Oyuncu bankalari risk primi alabilir; 24s %0,30 ve 7 gun %1,80 tavan.
CREATE OR REPLACE FUNCTION oyun.oyb_oran(p_banka bigint, p_saat integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare f numeric; s numeric;
begin
  select banka_faiz into f from oyun.sirketler
  where id=p_banka and sektor='banka' and aktif;
  if f is null then raise exception 'Banka bulunamadi'; end if;
  if p_saat=168 then return least(f,1.8); end if;
  if p_saat not in (1,3,6,12,24) or p_saat is null then raise exception 'Gecersiz vade'; end if;
  select oran into s from oyun.oyb_vade_oran
  where banka_id=p_banka and saat=p_saat;
  return least(case p_saat when 1 then .03 when 3 then .07 when 6 then .12
    when 12 then .18 else .30 end,
    coalesce(s,round(f * case p_saat when 1 then .015 when 3 then .04
      when 6 then .065 when 12 then .09 else .15 end,2)));
end $function$
;
CREATE OR REPLACE FUNCTION public.oyb_oran_ayarla(p_banka bigint, p_saat integer, p_oran numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();cap numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id=o.sirket_id
   where s.id=p_banka and s.sektor='banka' and s.aktif and o.user_id=u and o.pay>=50)
 then raise exception 'Banka yonetim yetkin yok (en az %%50 pay gerekir)';end if;
 cap:=case p_saat when 1 then .03 when 3 then .07 when 6 then .12
   when 12 then .18 when 24 then .30 else null end;
 if cap is null or p_oran is null or p_oran<0 or p_oran>cap
   or p_oran<>round(p_oran,2)
 then raise exception 'Bu vade icin faiz orani gecersiz veya siniri asiyor';end if;
 insert into oyun.oyb_vade_oran(banka_id,saat,oran)
 values(p_banka,p_saat,p_oran) on conflict(banka_id,saat)
 do update set oran=excluded.oran;
 return jsonb_build_object('tamam',true,'saat',p_saat,'oran',p_oran,'ust_sinir',cap);
end $function$
;
CREATE OR REPLACE FUNCTION public.banka_faiz_belirle(p_banka bigint, p_faiz numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;
 if p_faiz is null or p_faiz<0 or p_faiz>1.8 or p_faiz<>round(p_faiz,2) then
   raise exception 'Haftalik oyuncu bankasi faizi 0-1,8 arasinda ve en fazla iki ondalik olmali';
 end if;
 if not exists(select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id=o.sirket_id
   where s.id=p_banka and s.sektor='banka' and s.aktif and o.user_id=auth.uid() and o.pay>=50)
 then raise exception 'Aktif banka yonetim yetkin yok';end if;
 update oyun.sirketler set banka_faiz=p_faiz where id=p_banka and sektor='banka' and aktif;
 if not found then raise exception 'Banka bulunamadi';end if;
 return jsonb_build_object('tamam',true,'faiz',p_faiz,'faiz_ust_sinir',1.8);
end $function$
;

-- Kredi faizleri de ayni zaman birimine uygun 24s tavan %1.
CREATE OR REPLACE FUNCTION public.oyb_kredi_faiz_ayarla(p_banka bigint, p_faiz numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_faiz is null or p_faiz<0 or p_faiz>1.0 or p_faiz<>round(p_faiz,2)
 then raise exception '24 saatlik kredi faizi 0-1 arasinda olmali';end if;
 update oyun.sirketler s set banka_kredi_faiz=p_faiz
 where id=p_banka and sektor='banka' and aktif and exists(
  select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50);
 if not found then raise exception 'Banka yonetim yetkin yok';end if;
 return jsonb_build_object('tamam',true,'kredi_faiz_24s',p_faiz);
end $function$
;

-- Yalnizca YENI mevduat/kredi icin banka tarafindan teklif edilecek faiz ayarlari dengelenir.
-- ESKI vadeli mevduatlarda oyun.banka_mevduat.faiz ve vadeli.oran dokunulmaz.
update oyun.sirketler set banka_faiz=least(banka_faiz,1.8),
  banka_kredi_faiz=least(banka_kredi_faiz,1)
where sektor='banka' and (banka_faiz>1.8 or banka_kredi_faiz>1);

update oyun.oyb_vade_oran set oran=least(oran,
 case saat when 1 then .03 when 3 then .07 when 6 then .12 when 12 then .18 else .30 end)
where oran>case saat when 1 then .03 when 3 then .07 when 6 then .12 when 12 then .18 else .30 end;


-- ---- 20261008_oyuncu_kredi_basvurusu_iptali ----
-- Oyuncunun bekleyen kredi başvurusunu iptal etmesi.
-- Onay/ret işlemiyle aynı kilit sırası kullanılır: banka -> başvuru.
alter table oyun.oyb_kredi drop constraint if exists oyb_kredi_durum_check;
alter table oyun.oyb_kredi add constraint oyb_kredi_durum_check
 check (durum in ('basvuru','aktif','reddedildi','odendi','iptal'));

create or replace function public.oyb_kredi_basvuru_iptal(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_uid uuid:=auth.uid(); v_kredi oyun.oyb_kredi; v_banka oyun.sirketler; v_t timestamptz:=oyun.simdi();
begin
 if v_uid is null then raise exception 'Oturum açmalısın'; end if;
 if p_id is null then raise exception 'Başvuru seçilmedi'; end if;
 select * into v_kredi from oyun.oyb_kredi
 where id=p_id and borclu=v_uid;
 if not found then raise exception 'Bu kredi başvurusu sana ait değil'; end if;
 select * into v_banka from oyun.sirketler where id=v_kredi.banka_id for update;
 if not found then raise exception 'Banka bulunamadı'; end if;
 select * into v_kredi from oyun.oyb_kredi where id=p_id and borclu=v_uid for update;
 if v_kredi.durum<>'basvuru' then
  raise exception 'Başvuru artık beklemede değil. Onaylanan, reddedilen veya iptal edilen başvurular iptal edilemez.';
 end if;
 update oyun.oyb_kredi
 set durum='iptal',kapanis=v_t
 where id=p_id and borclu=v_uid and durum='basvuru';
 if not found then raise exception 'Başvuru artık beklemede değil'; end if;
 -- Kredi henüz kullandırılmadığı için cüzdan veya banka kasası değişmez.
 return jsonb_build_object('tamam',true,'id',p_id,'durum','iptal','tarih',v_t);
end $function$;

revoke all on function public.oyb_kredi_basvuru_iptal(bigint) from public,anon;
grant execute on function public.oyb_kredi_basvuru_iptal(bigint) to authenticated;


-- ---- 20261008_ticaret_gecmisi ----
-- Alıcı / satıcı arasındaki kesinleşmiş devirlerin denetlenebilir geçmişi.
-- Satış ilanı, şirket hissesi teklifi ve devlet mülk satın alma yollarına bağlanır.
create table if not exists oyun.ticaret_devir_kayit (
 id bigint generated always as identity primary key,
 tur text not null check(tur in ('mulk_devlet','sirket_tam')),
 varlik_id bigint not null,
 satici uuid references auth.users(id),
 alici uuid not null references auth.users(id),
 bedel numeric(20,2) not null check(bedel>=0),
 pay numeric check(pay is null or (pay>0 and pay<=100)),
 zaman timestamptz not null default now(),
 aciklama text
);
create index if not exists ticaret_devir_alici_idx on oyun.ticaret_devir_kayit(alici,zaman desc);
create index if not exists ticaret_devir_satici_idx on oyun.ticaret_devir_kayit(satici,zaman desc);
alter table oyun.ticaret_devir_kayit enable row level security;
revoke all on oyun.ticaret_devir_kayit from public,anon,authenticated;
alter table oyun.sirket_teklif add column if not exists kabul_zamani timestamptz;

CREATE OR REPLACE FUNCTION public.mulk_satin_al(p_tip text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric; t timestamptz:=oyun.simdi(); yeni_mulk_id bigint;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü'; end if;
 bedel:=case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end;
 kira:=round(bedel*0.025,2); -- %2,5 / hafta: sabit emlak kira dengesi
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s satın alındı',p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p.il_id,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni_mulk_id;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni_mulk_id,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $function$
;

CREATE OR REPLACE FUNCTION public.sirket_satilik_al(p_sirket bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;oldowner uuid;t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(98763,hashtext(p_sirket::text));
 select * into s from oyun.sirketler where id=p_sirket and aktif and satilik is not null for update;
 if s.id is null then raise exception 'Satis ilani bulunamadi';end if;
 select user_id into oldowner from oyun.sirket_ortaklari where sirket_id=p_sirket and pay=100 for update;
 if oldowner is null or oldowner=u then raise exception 'Satis uygun degil';end if;
 perform oyun.sirket_hesapla(p_sirket);
 perform oyun.para_islem(u,-s.satilik,'sirket','Sirket satin alimi',t);
 perform oyun.para_islem(oldowner,s.satilik,'sirket','Sirket satis geliri',t);
 delete from oyun.sirket_ortaklari where sirket_id=p_sirket;
 insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(p_sirket,u,100);
 update oyun.sirketler set satilik=null where id=p_sirket;
 update oyun.sirket_teklif set durum='iptal' where sirket_id=p_sirket and durum='bekliyor';
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,pay,zaman,aciklama)
 values('sirket_tam',p_sirket,oldowner,u,s.satilik,100,t,'Sirketin tamami devredildi');
 return jsonb_build_object('tamam',true);
end $function$
;

CREATE OR REPLACE FUNCTION public.sirket_pay_kabul(p_teklif bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid();o oyun.sirket_teklif;ownpay numeric;t timestamptz:=oyun.simdi();
begin
 select * into o from oyun.sirket_teklif where id=p_teklif for update;
 if o.alici is distinct from u or o.durum<>'bekliyor' then raise exception 'Teklif bulunamadi';end if;
 perform pg_advisory_xact_lock(98763,hashtext(o.sirket_id::text));
 select pay into ownpay from oyun.sirket_ortaklari where sirket_id=o.sirket_id and user_id=o.satici for update;
 if ownpay is null or ownpay<o.pay then raise exception 'Saticinin payi yetersiz';end if;
 perform oyun.para_islem(u,-o.bedel,'sirket','Sirket payi satin alimi',t);
 perform oyun.para_islem(o.satici,o.bedel,'sirket','Sirket payi satisi',t);
 update oyun.sirket_ortaklari set pay=pay-o.pay where sirket_id=o.sirket_id and user_id=o.satici;
 delete from oyun.sirket_ortaklari where sirket_id=o.sirket_id and user_id=o.satici and pay=0;
 insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(o.sirket_id,u,o.pay)
 on conflict(sirket_id,user_id) do update set pay=oyun.sirket_ortaklari.pay+excluded.pay;
 update oyun.sirket_teklif set durum='kabul',kabul_zamani=t where id=p_teklif;
 update oyun.sirketler set satilik=null where id=o.sirket_id;
 update oyun.sirket_teklif set durum='iptal' where sirket_id=o.sirket_id and satici=o.satici and durum='bekliyor' and id<>p_teklif;
 return jsonb_build_object('tamam',true);
end $function$
;

create or replace function public.ticaret_gecmisim()
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid := auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('kayitlar',coalesce((
 with devirler as (
  select 'mulk_oyuncu'::text as tur,a.mulk_id::bigint as varlik_id,
   case m.tip when 'daire' then 'Daire' when 'dukkan' then 'Dükkan'
    when 'villa' then 'Villa' else initcap(m.tip) end||' #'||a.mulk_id
     ||' · '||coalesce(i.ad,'') as varlik,
   null::numeric as pay,a.fiyat as bedel,
   a.satici,a.alici,a.kapanma as zaman,
   'mulk_ilan'::text as kaynak, a.id::bigint as kaynak_id
  from oyun.mulk_ilan a
  join oyun.yatirim_mulkleri m on m.id=a.mulk_id
  left join oyun.iller i on i.id=m.il_id
  where a.durum='satildi' and a.alici is not null
     and a.kapanma is not null and (a.satici=u or a.alici=u)
  union all
  select 'sirket_hisse'::text,st.sirket_id::bigint,
   'Şirket hissesi · '||coalesce(s.ad,'#'||st.sirket_id),
   st.pay,st.bedel,st.satici,st.alici,coalesce(st.kabul_zamani,st.zaman),
   'sirket_teklif'::text,st.id::bigint
  from oyun.sirket_teklif st
  left join oyun.sirketler s on s.id=st.sirket_id
  where st.durum='kabul' and (st.satici=u or st.alici=u)
  union all
  select t.tur,t.varlik_id,
   case when t.tur='sirket_tam'
       then 'Şirket · '||coalesce(s.ad,'#'||t.varlik_id)
     else case m.tip when 'daire' then 'Daire' when 'dukkan' then 'Dükkan'
       when 'villa' then 'Villa' else coalesce(initcap(m.tip),'Gayrimenkul') end
       ||' #'||t.varlik_id||' · '||coalesce(i.ad,'')
     end,
   t.pay,t.bedel,t.satici,t.alici,t.zaman,'ticaret_devir'::text,t.id
  from oyun.ticaret_devir_kayit t
  left join oyun.sirketler s on t.tur='sirket_tam' and s.id=t.varlik_id
  left join oyun.yatirim_mulkleri m on t.tur='mulk_devlet' and m.id=t.varlik_id
  left join oyun.iller i on i.id=m.il_id
  where t.satici=u or t.alici=u
 )
 select jsonb_agg(jsonb_build_object(
  'tur',d.tur,'varlik',d.varlik,'varlik_id',d.varlik_id,'pay',d.pay,
  'bedel',d.bedel,'satici',case when d.satici is null then 'Devlet'
    else coalesce(ps.kad,'Oyuncu (kayıt yok)') end,
  'alici',coalesce(pa.kad,'Oyuncu (kayıt yok)'),
  'benim_rolum',case when d.alici=u then 'alici' else 'satici' end,
  'tarih',d.zaman,'kaynak',d.kaynak,'kaynak_id',d.kaynak_id
 ) order by d.zaman desc,d.kaynak_id desc)
 from (select * from devirler where zaman is not null order by zaman desc,kaynak_id desc limit 100) d
 left join oyun.profiller ps on ps.id=d.satici
 left join oyun.profiller pa on pa.id=d.alici
 ),'[]'::jsonb));
end $function$;
revoke all on function public.ticaret_gecmisim() from public,anon;
grant execute on function public.ticaret_gecmisim() to authenticated;


-- ---- 20261008_parti_aday_gorunurluk_tanitim ----
-- Seçimlerin mevcut aday kayıtları korunur.
-- Yalnızca gerçek oyuncular, gerçek parti liderleri ve aktif seçim takvimi kullanılır.
create table if not exists oyun.parti_aday_tanitim (
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id),
 aday_id bigint not null references oyun.adaylar(id) on delete cascade,
 kitle text not null check(kitle in ('herkes','uyeler')),
 metin text not null check(length(metin) between 20 and 600),
 yayinlayan uuid not null references auth.users(id),
 zaman timestamptz not null default now()
);
create index if not exists parti_aday_tanitim_idx on oyun.parti_aday_tanitim(parti_id,zaman desc);
alter table oyun.parti_aday_tanitim enable row level security;
revoke all on oyun.parti_aday_tanitim from public,anon,authenticated;

create or replace function public.parti_aday_kart(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare
 u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
 p oyun.partiler; cb oyun.secimler; k oyun.cb_kararlar;
 cb_id uuid; cb_parti bigint; cb_durum text; ben_uye boolean;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.partiler where id=p_parti and not kapali;
 if not found then raise exception 'Parti bulunamadı'; end if;
 ben_uye:=exists(select 1 from oyun.profiller where id=u and parti_id=p_parti);
 select * into cb from oyun.secimler s
 where s.tur='cb' and s.durum='bekliyor' and s.oy_bit>=t and s.basvuru_bas<=t
 order by s.ara desc,s.oy_bas asc limit 1;
 if cb.id is not null then
  select * into k from oyun.cb_kararlar where donem=cb.donem and parti_id=p_parti;
  if k.yontem='destek' then
   cb_parti:=k.destek_parti; cb_durum:='destek';
  else
   cb_parti:=p_parti;cb_durum:=case when k.yontem='onsecim' then 'onsecim' else 'aday' end;
  end if;
  select a.user_id into cb_id from oyun.adaylar a
   where a.secim_id=cb.id and a.parti_id=cb_parti order by a.basvuru_at limit 1;
  if cb_id is null and cb_parti=p_parti and k.yontem in ('kendisi','baskasi') then cb_id:=k.aday; end if;
 end if;
 return jsonb_build_object(
 'parti_id',p.id,'uye_mi',ben_uye,'genel_baskan_mi',p.gb=u,
 'cb',case when cb.id is null then null else
    jsonb_build_object('secim_id',cb.id,'donem',cb.donem,'aday',oyun.kad(cb_id),
      'aday_id',cb_id,'aday_partisi',coalesce((select kisa from oyun.partiler where id=cb_parti),p.kisa),
      'aday_parti_id',cb_parti,
      'asama',case when cb_id is not null then 'kesin'
        when k.yontem='destek' then 'destek_bekliyor'
        when k.yontem='onsecim' then 'onsecim_bekliyor' else 'henüz_belirlenmedi' end,
      'destekleyenler',coalesce((
       select jsonb_agg(jsonb_build_object('id',pa.id,'kisa',pa.kisa,'ad',pa.ad) order by pa.id)
       from oyun.cb_kararlar x join oyun.partiler pa on pa.id=x.parti_id
       where x.donem=cb.donem and x.yontem='destek' and x.destek_parti=cb_parti
      ),'[]'::jsonb)) end,
 'aday_adaylari',case when ben_uye then coalesce((
   select jsonb_agg(jsonb_build_object(
      'id',a.id,'tur',s.tur,'kad',pr.kad,'il_id',a.il_id,'il',(select ad from oyun.iller where id=a.il_id),
      'secim_id',s.id,'donem',s.donem,'sira',a.sira,'basvuru',a.basvuru_at
   ) order by s.oy_bas,a.basvuru_at,a.id)
   from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
   join oyun.profiller pr on pr.id=a.user_id
   where a.parti_id=p_parti and s.tur in ('mv_on','cb_on')
     and s.durum='bekliyor' and s.basvuru_bas<=t and s.oy_bit>=t
 ),'[]'::jsonb) else '[]'::jsonb end,
 'kesin_adaylar',coalesce((
   select jsonb_agg(jsonb_build_object(
     'id',a.id,'tur',s.tur,'kad',pr.kad,'il_id',a.il_id,
     'il',(select ad from oyun.iller where id=a.il_id),'sira',a.sira,
     'secim_id',s.id,'donem',s.donem
   ) order by s.oy_bas,a.il_id,a.sira,a.id)
   from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
   join oyun.profiller pr on pr.id=a.user_id
   where a.parti_id=p_parti and
      ((s.tur in ('cb','bel') and s.durum='bekliyor' and s.oy_bit>=t) or
       (s.tur='mv_on' and a.sira is not null and exists(
         select 1 from oyun.secimler m where m.tur='mv' and m.donem=s.donem
            and m.durum='bekliyor' and m.oy_bit>=t)))
 ),'[]'::jsonb),
 'tanitimlar',coalesce((
   select jsonb_agg(jsonb_build_object(
     'id',x.id,'tur',s.tur,'kad',oyun.kad(a.user_id),
     'il',(select ad from oyun.iller where id=a.il_id),
     'kitle',x.kitle,'metin',x.metin,'yayinlayan',oyun.kad(x.yayinlayan),'zaman',x.zaman
   ) order by x.zaman desc,x.id desc)
   from (select * from oyun.parti_aday_tanitim
        where parti_id=p_parti and (kitle='herkes' or ben_uye)
        order by zaman desc,id desc limit 30) x
   join oyun.adaylar a on a.id=x.aday_id join oyun.secimler s on s.id=a.secim_id
 ),'[]'::jsonb));
end $function$;
revoke all on function public.parti_aday_kart(bigint) from public,anon;
grant execute on function public.parti_aday_kart(bigint) to authenticated;

create or replace function public.parti_aday_tanit(p_aday bigint,p_kitle text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); p oyun.partiler; a oyun.adaylar; s oyun.secimler;
 t timestamptz:=oyun.simdi(); metin text:=btrim(coalesce(p_metin,'')); newid bigint;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 select * into p from oyun.partiler where gb=u and not kapali;
 if not found then raise exception 'Yalnızca parti genel başkanı aday tanıtabilir';end if;
 if p_kitle not in ('herkes','uyeler') or p_kitle is null then raise exception 'Tanıtım kitlesi geçersiz';end if;
 if length(metin)<20 or length(metin)>600 then raise exception 'Tanıtım 20-600 karakter olmalı';end if;
 select * into a from oyun.adaylar where id=p_aday;
 if not found then raise exception 'Aday kaydı bulunamadı';end if;
 select * into s from oyun.secimler where id=a.secim_id;
 if s.tur not in ('mv_on','cb_on','cb','bel_on','bel')
   or s.durum<>'bekliyor' or s.oy_bit<=t or s.basvuru_bas>t and s.tur in ('mv_on','cb_on','bel_on')
 then raise exception 'Bu seçimde aday tanıtım zamanı kapalı';end if;
 if a.parti_id is distinct from p.id
 and not (
   (s.tur='cb' and exists(select 1 from oyun.cb_kararlar k
      where k.donem=s.donem and k.parti_id=p.id and k.yontem='destek' and k.destek_parti=a.parti_id))
   or
   (s.tur='bel' and exists(select 1 from oyun.bel_aday_destek b
      where b.secim_id=s.id and b.parti_id=p.id and b.aday_id=a.id))
 ) then raise exception 'Yalnızca kendi partinin veya resmen desteklediğin adayı tanıtabilirsin';end if;
 if (select count(*) from oyun.parti_aday_tanitim where parti_id=p.id and zaman>=t-interval '24 hours')>=3
 then raise exception 'Partin 24 saatte en fazla 3 aday tanıtımı yapabilir';end if;
 insert into oyun.parti_aday_tanitim(parti_id,aday_id,kitle,metin,yayinlayan,zaman)
 values(p.id,a.id,p_kitle,metin,u,t) returning id into newid;
 if p_kitle='herkes' then
  perform oyun.olay('parti',left(p.kisa||' aday tanıtımı: '||oyun.kad(a.user_id),120),null,p.id,t);
 end if;
 return jsonb_build_object('tamam',true,'id',newid,'parti_id',p.id,'kitle',p_kitle);
end $function$;
revoke all on function public.parti_aday_tanit(bigint,text,text) from public,anon;
grant execute on function public.parti_aday_tanit(bigint,text,text) to authenticated;


-- ---- 20261008_belediye_ortak_aday ----

create table if not exists oyun.bel_aday_destek (
 secim_id bigint not null references oyun.secimler(id) on delete cascade,
 il_id smallint not null references oyun.iller(id),
 parti_id bigint not null references oyun.partiler(id),
 hedef_parti_id bigint not null references oyun.partiler(id),
 aday_id bigint not null references oyun.adaylar(id) on delete cascade,
 zaman timestamptz not null default now(),
 primary key(secim_id,il_id,parti_id),
 check(parti_id<>hedef_parti_id)
);
create index if not exists bel_aday_destek_hedef_idx on oyun.bel_aday_destek(secim_id,il_id,hedef_parti_id);
alter table oyun.bel_aday_destek enable row level security;
revoke all on oyun.bel_aday_destek from public,anon,authenticated;

create or replace function public.bel_aday_destek(p_il smallint,p_hedef_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid();pa oyun.partiler;s oyun.secimler;os oyun.secimler;
 a oyun.adaylar;t timestamptz:=oyun.simdi();iid bigint;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 select * into pa from oyun.partiler where gb=u and not kapali;
 if not found then raise exception 'Bu karar yalnızca genel başkan tarafından verilir';end if;
 if p_il is null or p_hedef_parti is null or p_hedef_parti=pa.id then raise exception 'Geçerli il ve başka parti seç';end if;
 select * into s from oyun.secimler
 where tur='bel' and durum='bekliyor' and oy_bas>t
   and (not ara or hedef_il_id=p_il)
 order by ara desc,oy_bas limit 1 for update;
 if not found then raise exception 'Bu ilde destek kararı için seçim bulunamadı ya da oy verme başladı';end if;
 select * into os from oyun.secimler where tur='bel_on' and donem=s.donem;
 if os.id is null or t<os.sonuc_at or os.durum='bekliyor' then
   raise exception 'Belediye ön seçimi sonuçlanmadan ortak aday belirlenemez';end if;
 select * into a from oyun.adaylar
 where secim_id=s.id and il_id=p_il and parti_id=p_hedef_parti
 order by basvuru_at,id limit 1;
 if not found then raise exception 'Hedef partinin bu ilde kesinleşmiş adayı bulunmuyor';end if;
 if not exists(select 1 from oyun.partiler where id=p_hedef_parti and not kapali)
 then raise exception 'Hedef parti faal değil';end if;
 insert into oyun.bel_aday_destek(secim_id,il_id,parti_id,hedef_parti_id,aday_id,zaman)
 values(s.id,p_il,pa.id,p_hedef_parti,a.id,t)
 on conflict(secim_id,il_id,parti_id) do update
 set hedef_parti_id=excluded.hedef_parti_id,aday_id=excluded.aday_id,zaman=excluded.zaman;
 delete from oyun.adaylar where secim_id=s.id and il_id=p_il and parti_id=pa.id;
 select x.ittifak_id into iid from oyun.ittifak_uyeler x
 join oyun.ittifak_uyeler y on x.ittifak_id=y.ittifak_id
 where x.parti_id=pa.id and y.parti_id=p_hedef_parti limit 1;
 perform oyun.olay('ittifak',left(pa.kisa||', '||p_il||'. ilde '||
  (select kisa from oyun.partiler where id=p_hedef_parti)||' adayını destekliyor',200),p_il,pa.id,t);
 return jsonb_build_object('tamam',true,'secim',s.id,'il',p_il,
   'aday',oyun.kad(a.user_id),'desteklenen_parti',p_hedef_parti,'ortak_ittifak_adayi',iid is not null);
end $function$;
revoke all on function public.bel_aday_destek(smallint,bigint) from public,anon;
grant execute on function public.bel_aday_destek(smallint,bigint) to authenticated;

create or replace function public.bel_destek_geri_cek(p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid();pa oyun.partiler;s oyun.secimler;a oyun.adaylar;
 t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into pa from oyun.partiler where gb=u and not kapali;
 if not found then raise exception 'Genel başkan yetkisi gerekli';end if;
 select * into s from oyun.secimler where tur='bel' and durum='bekliyor'
   and oy_bas>t and (not ara or hedef_il_id=p_il)
 order by ara desc,oy_bas limit 1 for update;
 if not found then raise exception 'Seçim başladı veya aktif değil';end if;
 delete from oyun.bel_aday_destek where secim_id=s.id and il_id=p_il and parti_id=pa.id;
 if not found then raise exception 'Geri çekilecek destek kararı bulunamadı';end if;
 select a2.* into a from oyun.adaylar a2
 join oyun.secimler os on os.id=a2.secim_id
 where os.tur='bel_on' and os.donem=s.donem and a2.il_id=p_il and a2.parti_id=pa.id
 order by a2.oy desc nulls last,a2.basvuru_at,a2.id limit 1;
 if a.id is not null and not exists(select 1 from oyun.adaylar where secim_id=s.id and user_id=a.user_id) then
   insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,basvuru_at,vaat)
   values(s.id,a.user_id,a.parti_id,a.il_id,a.basvuru_at,a.vaat)
   on conflict(secim_id,user_id) do nothing;
 end if;
 return jsonb_build_object('tamam',true,'il',p_il,'aday_geri_geldi',a.id is not null);
end $function$;
revoke all on function public.bel_destek_geri_cek(smallint) from public,anon;
grant execute on function public.bel_destek_geri_cek(smallint) to authenticated;

create or replace function public.bel_destek_durum(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid();s oyun.secimler;t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.partiler where id=p_parti and not kapali) then raise exception 'Parti bulunamadı';end if;
 select * into s from oyun.secimler where tur='bel' and durum='bekliyor' and oy_bit>=t
 order by ara desc,oy_bas limit 1;
 return jsonb_build_object('secim_id',s.id,'donem',s.donem,
  'acik',s.id is not null and t<s.oy_bas,
  'adaylar',coalesce((
    select jsonb_agg(jsonb_build_object('id',a.id,'il',i.ad,'il_id',a.il_id,
      'kad',pr.kad,'parti_id',a.parti_id,'parti',pa.kisa,
      'ittifak_ortagi',exists(select 1 from oyun.ittifak_uyeler x
         join oyun.ittifak_uyeler y on y.ittifak_id=x.ittifak_id
         where x.parti_id=p_parti and y.parti_id=a.parti_id))
      order by i.ad,pa.kisa)
    from oyun.adaylar a join oyun.profiller pr on pr.id=a.user_id
    join oyun.iller i on i.id=a.il_id join oyun.partiler pa on pa.id=a.parti_id
    where a.secim_id=s.id and a.parti_id<>p_parti
  ),'[]'::jsonb),
  'desteklerim',coalesce((
    select jsonb_agg(jsonb_build_object('il_id',x.il_id,'il',i.ad,
      'aday',oyun.kad(a.user_id),'parti',pa.kisa,'parti_id',x.hedef_parti_id)
      order by i.ad)
    from oyun.bel_aday_destek x join oyun.adaylar a on a.id=x.aday_id
    join oyun.iller i on i.id=x.il_id join oyun.partiler pa on pa.id=x.hedef_parti_id
    where x.secim_id=s.id and x.parti_id=p_parti
  ),'[]'::jsonb));
end $function$;
revoke all on function public.bel_destek_durum(bigint) from public,anon;
grant execute on function public.bel_destek_durum(bigint) to authenticated;

-- CB desteği artık ittifak dışı partilere de açık, fakat gerçek kesin aday şartı korunur.
CREATE OR REPLACE FUNCTION public.cb_destek(p_parti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  s oyun.secimler;
  hedef oyun.partiler;
begin
  pa := oyun.gb_partim(p);

  select * into s
  from oyun.secimler
  where tur = 'cb'
    and t >= basvuru_bas
    and t < basvuru_bit
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Cumhurbaşkanı adayı belirleme dönemi şu anda açık değil.';
  end if;

  select * into hedef
  from oyun.partiler
  where id = p_parti and not kapali;

  if hedef.id is null or hedef.id = pa.id then
    raise exception 'Geçersiz parti.';
  end if;

  -- Gerçek oyun dışındaki partilere de aday desteği verilebilir.
  -- Yalnızca resmen açıklanmış gerçek oyuncu adayı desteklenebilir.
  if not exists(select 1 from oyun.adaylar a
    where a.secim_id=s.id and a.parti_id=hedef.id)
  then raise exception 'Hedef partinin resmen açıklanmış Cumhurbaşkanı adayı yok.';end if;
  if exists(select 1 from oyun.cb_kararlar k
    where k.donem=s.donem and k.parti_id=hedef.id and k.yontem='destek')
  then raise exception 'Zaten başka adayı destekleyen parti hedef seçilemez.';end if;

  insert into oyun.cb_kararlar(
    donem, parti_id, yontem, aday, destek_parti, zaman
  )
  values (
    s.donem, pa.id, 'destek', null, hedef.id, t
  )
  on conflict(donem,parti_id) do update
    set yontem = 'destek',
        aday = null,
        destek_parti = excluded.destek_parti,
        zaman = excluded.zaman;

  delete from oyun.adaylar
  where secim_id = s.id and parti_id = pa.id;

  perform oyun.olay(
    'ittifak',
    format(
      '%s, cumhurbaşkanlığı seçiminde %s''nin adayını destekleme kararı aldı.',
      pa.kisa, hedef.kisa
    ),
    null, pa.id, t
  );

  return public.durum();
end $function$
;

-- Belediye pusulasında ortak destek veren partileri göster; oylar tek oyuncu adayı üzerinde toplanır.
CREATE OR REPLACE FUNCTION public.secim_detay(p_secim bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  s oyun.secimler;
  onsecim bigint;
  secenek jsonb;
begin
  select * into s from oyun.secimler where id=p_secim;
  if s.id is null then raise exception 'Seçim bulunamadı.'; end if;

  if s.tur='mv' then
    select id into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;

    select coalesce(jsonb_agg(x order by x->>'kisa'),'[]'::jsonb)
    into secenek
    from (
      select oyun.parti_json(a.parti_id) || jsonb_build_object(
        'hedef',a.parti_id,
        'bagimsiz',false,
        'beyanname',oyun.beyanname_json(a.parti_id,s.donem),
        'liste',jsonb_agg(jsonb_build_object(
          'kad',oyun.kad(a.user_id),
          'sira',a.sira,
          'vaat',a.vaat,
          'vaatler',oyun.aday_vaatleri(a.user_id,s.id)
        ) order by a.sira)
      ) x
      from oyun.adaylar a
      where a.secim_id=onsecim
        and a.il_id=p.il_id
        and a.parti_id is not null
        and a.sira is not null
      group by a.parti_id
    ) z;

    select secenek || coalesce(jsonb_agg(
      jsonb_build_object(
        'hedef',-a.id,
        'bagimsiz',true,
        'ad',pr.kad,
        'kad',pr.kad,
        'kisa',null,
        'renk','#8e8e93',
        'amblem',null,
        'il_id',a.il_id,
        'vaat',a.vaat,
        'vaatler',oyun.aday_vaatleri(a.user_id,s.id),
        'beyanname',null,
        'liste',jsonb_build_array(jsonb_build_object(
          'kad',pr.kad,'sira',1,'vaat',a.vaat,
          'vaatler',oyun.aday_vaatleri(a.user_id,s.id)
        ))
      ) order by a.basvuru_at,a.id
    ),'[]'::jsonb)
    into secenek
    from oyun.adaylar a
    join oyun.profiller pr on pr.id=a.user_id
    where a.secim_id=s.id
      and a.parti_id is null
      and a.il_id=p.il_id;
  else
    select coalesce(jsonb_agg(
      oyun.aday_json(a.id) || jsonb_build_object(
        'hedef',a.id,
        'oy',case when s.durum='bekliyor' then null else a.oy end,
        'beyanname',case when s.tur in ('cb','cb2') and a.parti_id is not null
                         then oyun.beyanname_json(a.parti_id,s.donem) end
      )
      order by a.parti_id nulls last,a.basvuru_at
    ),'[]'::jsonb)
    into secenek
    from oyun.adaylar a
    where a.secim_id=s.id and (
      (s.tur in ('mv_on','bel_on') and a.il_id=p.il_id and a.parti_id=p.parti_id) or
      (s.tur in ('kurultay','cb_on') and a.parti_id=p.parti_id) or
      (s.tur='bel' and a.il_id=p.il_id) or
      (s.tur in ('cb','cb2'))
    );
  end if;

  return oyun.secim_ozet(s,p,t) || jsonb_build_object(
    'secenekler',secenek,
    'sonuc',s.sonuc,
    'benim_il',p.il_id,
    'benim_parti',p.parti_id,
    'destekler',case when s.tur in ('cb','cb2') then coalesce((
      select jsonb_object_agg(x.destek_parti::text,x.l)
      from (
        select k.destek_parti,jsonb_agg(oyun.parti_json(k.parti_id)) l
        from oyun.cb_kararlar k
        where k.donem=s.donem and k.yontem='destek'
        group by k.destek_parti
      ) x
    ),'{}'::jsonb)
    when s.tur='bel' then coalesce((
      select jsonb_object_agg(z.hedef_parti::text,z.l)
      from (
        select d.hedef_parti_id hedef_parti,
          jsonb_agg(oyun.parti_json(d.parti_id) order by d.parti_id) l
        from oyun.bel_aday_destek d
        join oyun.adaylar a on a.id=d.aday_id and a.secim_id=s.id
          and a.parti_id=d.hedef_parti_id and a.il_id=p.il_id
        where d.secim_id=s.id and d.il_id=p.il_id
        group by d.hedef_parti_id
      ) z
    ),'{}'::jsonb) end
  );
end $function$
;


-- ---- 20261008_ortak_aday_destek_guvenligi ----
-- Ortak aday desteklerinin zincirlenmesini ve üçüncü kişilerin desteklediği adayın habersiz çekilmesini engelle.
CREATE OR REPLACE FUNCTION public.bel_aday_destek(p_il smallint, p_hedef_parti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();pa oyun.partiler;s oyun.secimler;os oyun.secimler;
 a oyun.adaylar;t timestamptz:=oyun.simdi();iid bigint;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 select * into pa from oyun.partiler where gb=u and not kapali;
 if not found then raise exception 'Bu karar yalnızca genel başkan tarafından verilir';end if;
 if p_il is null or p_hedef_parti is null or p_hedef_parti=pa.id then raise exception 'Geçerli il ve başka parti seç';end if;
 select * into s from oyun.secimler
 where tur='bel' and durum='bekliyor' and oy_bas>t
   and (not ara or hedef_il_id=p_il)
 order by ara desc,oy_bas limit 1 for update;
 if not found then raise exception 'Bu ilde destek kararı için seçim bulunamadı ya da oy verme başladı';end if;
 select * into os from oyun.secimler where tur='bel_on' and donem=s.donem;
 if os.id is null or t<os.sonuc_at or os.durum='bekliyor' then
   raise exception 'Belediye ön seçimi sonuçlanmadan ortak aday belirlenemez';end if;
 select * into a from oyun.adaylar
 where secim_id=s.id and il_id=p_il and parti_id=p_hedef_parti
 order by basvuru_at,id limit 1;
 if not found then raise exception 'Hedef partinin bu ilde kesinleşmiş adayı bulunmuyor';end if;
 if not exists(select 1 from oyun.partiler where id=p_hedef_parti and not kapali)
 then raise exception 'Hedef parti faal değil';end if;
 if exists(select 1 from oyun.bel_aday_destek d where d.secim_id=s.id and d.il_id=p_il and d.parti_id=p_hedef_parti)
 then raise exception 'Hedef partinin kendi adayı zaten çekildi; ortak aday olamaz';end if;
 if exists(select 1 from oyun.bel_aday_destek d where d.secim_id=s.id and d.il_id=p_il and d.hedef_parti_id=pa.id)
 then raise exception 'Senin partinin adayını başka partiler destekliyor; adayı çekemezsin';end if;
 insert into oyun.bel_aday_destek(secim_id,il_id,parti_id,hedef_parti_id,aday_id,zaman)
 values(s.id,p_il,pa.id,p_hedef_parti,a.id,t)
 on conflict(secim_id,il_id,parti_id) do update
 set hedef_parti_id=excluded.hedef_parti_id,aday_id=excluded.aday_id,zaman=excluded.zaman;
 delete from oyun.adaylar where secim_id=s.id and il_id=p_il and parti_id=pa.id;
 select x.ittifak_id into iid from oyun.ittifak_uyeler x
 join oyun.ittifak_uyeler y on x.ittifak_id=y.ittifak_id
 where x.parti_id=pa.id and y.parti_id=p_hedef_parti limit 1;
 perform oyun.olay('ittifak',left(pa.kisa||', '||p_il||'. ilde '||
  (select kisa from oyun.partiler where id=p_hedef_parti)||' adayını destekliyor',200),p_il,pa.id,t);
 return jsonb_build_object('tamam',true,'secim',s.id,'il',p_il,
   'aday',oyun.kad(a.user_id),'desteklenen_parti',p_hedef_parti,'ortak_ittifak_adayi',iid is not null);
end $function$
;

CREATE OR REPLACE FUNCTION public.cb_destek(p_parti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  s oyun.secimler;
  hedef oyun.partiler;
begin
  pa := oyun.gb_partim(p);

  select * into s
  from oyun.secimler
  where tur = 'cb'
    and t >= basvuru_bas
    and t < basvuru_bit
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Cumhurbaşkanı adayı belirleme dönemi şu anda açık değil.';
  end if;

  select * into hedef
  from oyun.partiler
  where id = p_parti and not kapali;

  if hedef.id is null or hedef.id = pa.id then
    raise exception 'Geçersiz parti.';
  end if;

  -- Gerçek oyun dışındaki partilere de aday desteği verilebilir.
  -- Yalnızca resmen açıklanmış gerçek oyuncu adayı desteklenebilir.
  if not exists(select 1 from oyun.adaylar a
    where a.secim_id=s.id and a.parti_id=hedef.id)
  then raise exception 'Hedef partinin resmen açıklanmış Cumhurbaşkanı adayı yok.';end if;
  if exists(select 1 from oyun.cb_kararlar k
    where k.donem=s.donem and k.parti_id=hedef.id and k.yontem='destek')
  then raise exception 'Zaten başka adayı destekleyen parti hedef seçilemez.';end if;

  if exists(select 1 from oyun.cb_kararlar x
    where x.donem=s.donem and x.yontem='destek' and x.destek_parti=pa.id)
  then raise exception 'Diğer partiler senin adayını destekliyor; önce desteklerini değiştirmeliler';end if;
  insert into oyun.cb_kararlar(
    donem, parti_id, yontem, aday, destek_parti, zaman
  )
  values (
    s.donem, pa.id, 'destek', null, hedef.id, t
  )
  on conflict(donem,parti_id) do update
    set yontem = 'destek',
        aday = null,
        destek_parti = excluded.destek_parti,
        zaman = excluded.zaman;

  delete from oyun.adaylar
  where secim_id = s.id and parti_id = pa.id;

  perform oyun.olay(
    'ittifak',
    format(
      '%s, cumhurbaşkanlığı seçiminde %s''nin adayını destekleme kararı aldı.',
      pa.kisa, hedef.kisa
    ),
    null, pa.id, t
  );

  return public.durum();
end $function$
;


-- ---- 20261008_cb_destek_aday_listesi ----
create or replace function public.cb_destek_secenekleri()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); s oyun.secimler; p oyun.profiller;
 t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into p from oyun.profiller where id=u;
 select * into s from oyun.secimler where tur='cb' and durum='bekliyor'
  and basvuru_bas<=t and basvuru_bit>t
 order by ara desc,basvuru_bit limit 1;
 return jsonb_build_object('secim_id',s.id,
  'secenekler',coalesce((select jsonb_agg(jsonb_build_object(
     'parti_id',a.parti_id,'parti',pa.ad,'kisa',pa.kisa,'aday',pr.kad,'aday_id',a.id,
     'ittifak_ortagi',exists(select 1 from oyun.ittifak_uyeler x
      join oyun.ittifak_uyeler y on y.ittifak_id=x.ittifak_id
      where x.parti_id=p.parti_id and y.parti_id=a.parti_id))
     order by pa.kisa,pr.kad)
   from oyun.adaylar a join oyun.partiler pa on pa.id=a.parti_id and not pa.kapali
   join oyun.profiller pr on pr.id=a.user_id
   where a.secim_id=s.id and a.parti_id is not null and a.parti_id<>p.parti_id
     and not exists(select 1 from oyun.cb_kararlar k where k.donem=s.donem
       and k.parti_id=a.parti_id and k.yontem='destek')
  ),'[]'::jsonb));
end $f$;
revoke all on function public.cb_destek_secenekleri() from public,anon;
grant execute on function public.cb_destek_secenekleri() to authenticated;


-- ---- 20261008_cb_destek_secenekleri_aday_id ----
create or replace function public.cb_destek_secenekleri()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); s oyun.secimler; p oyun.profiller;
 t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into p from oyun.profiller where id=u;
 select * into s from oyun.secimler where tur='cb' and durum='bekliyor'
  and basvuru_bas<=t and basvuru_bit>t
 order by ara desc,basvuru_bit limit 1;
 return jsonb_build_object('secim_id',s.id,
  'secenekler',coalesce((select jsonb_agg(jsonb_build_object(
     'parti_id',a.parti_id,'parti',pa.ad,'kisa',pa.kisa,'aday',pr.kad,'aday_id',a.id,
     'ittifak_ortagi',exists(select 1 from oyun.ittifak_uyeler x
      join oyun.ittifak_uyeler y on y.ittifak_id=x.ittifak_id
      where x.parti_id=p.parti_id and y.parti_id=a.parti_id))
     order by pa.kisa,pr.kad)
   from oyun.adaylar a join oyun.partiler pa on pa.id=a.parti_id and not pa.kapali
   join oyun.profiller pr on pr.id=a.user_id
   where a.secim_id=s.id and a.parti_id is not null and a.parti_id<>p.parti_id
     and not exists(select 1 from oyun.cb_kararlar k where k.donem=s.donem
       and k.parti_id=a.parti_id and k.yontem='destek')
  ),'[]'::jsonb));
end $f$;
revoke all on function public.cb_destek_secenekleri() from public,anon;
grant execute on function public.cb_destek_secenekleri() to authenticated;


-- ---- 20261008_sirket_faaliyet_ozeti ----
-- Yeni dönemlerde gelir/gider ve dağıtılan kâr ayrı tutulur.
-- Geçmiş hareketlerin olmayan gelir/gider ayrıntısı uydurulmaz.
alter table oyun.sirket_hareket add column if not exists faaliyet_gelir numeric;
alter table oyun.sirket_hareket add column if not exists faaliyet_gider numeric;
alter table oyun.sirket_hareket add column if not exists dagitilan_kar numeric;

CREATE OR REPLACE FUNCTION oyun.sirket_hesapla(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()*.8),2);
  cost:=round(s.sermaye*(.025+random()*.055)+w*(.5+random()),2);
  net:=income-cost;
  distributed:=0;
  -- Zararda sirket kasasi erir. Karda dagitilabilir para ortaklara aktarilir.
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributed:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    perform oyun.para_islem(x.user_id,round(distributed*x.pay/100,2),'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$
;


create or replace function public.sirket_finans_ozeti(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare uid uuid:=auth.uid(); s oyun.sirketler;w numeric;r numeric;
 gelir_min numeric;gelir_max numeric;gider_min numeric;gider_max numeric;
begin
 if uid is null then raise exception 'Oturum açmalısın';end if;
 if not exists(select 1 from oyun.sirket_ortaklari
   where sirket_id=p_sirket and user_id=uid and pay>0)
 then raise exception 'Bu şirketin ortağı değilsin';end if;
 perform oyun.sirket_hesapla(p_sirket);
 select * into s from oyun.sirketler where id=p_sirket and aktif;
 if not found then raise exception 'Şirket bulunamadı';end if;
 select asgari into w from oyun.ulke where id=1;
 r:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15
 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18
 when 'medya' then .16 else .08 end;
 gelir_min:=round(s.sermaye*r*.6);
 gelir_max:=round(s.sermaye*r*1.4);
 gider_min:=round(s.sermaye*.025+w*.5);
 gider_max:=round(s.sermaye*.08+w*1.5);
 return jsonb_build_object(
 'id',s.id,'ad',s.ad,'sektor',s.sektor,'sermaye',s.sermaye,'kasa',s.kasa,
 'benim_payim',(select pay from oyun.sirket_ortaklari where sirket_id=s.id and user_id=uid),
 'sonraki_hesaplama',s.sonraki_kazanc,
 'tahmini_gelir_min',gelir_min,'tahmini_gelir_max',gelir_max,
 'tahmini_gider_min',gider_min,'tahmini_gider_max',gider_max,
 'tahmini_net_min',gelir_min-gider_max,'tahmini_net_max',gelir_max-gider_min,
 'tahmini_ortalama_net',round(s.sermaye*r-s.sermaye*.0525-w),
 'dagitilabilir_kar',greatest(0,s.kasa-s.sermaye-coalesce((
 select sum(round(m.anapara*(1+m.faiz/100)))
 from oyun.banka_mevduat m where m.banka_id=s.id and not m.kapandi),0)),
 'islemler',coalesce((
 select jsonb_agg(jsonb_build_object(
  'tarih',h.zaman,'net',h.tutar,'faaliyet_gelir',h.faaliyet_gelir,
  'faaliyet_gider',h.faaliyet_gider,'dagitilan_kar',h.dagitilan_kar,
  'aciklama',h.aciklama) order by h.zaman desc,h.id desc)
 from (select * from oyun.sirket_hareket
  where sirket_id=s.id order by zaman desc,id desc limit 12) h
 ),'[]'::jsonb));
end $f$;
revoke all on function public.sirket_finans_ozeti(bigint) from public,anon;
grant execute on function public.sirket_finans_ozeti(bigint) to authenticated;


-- ---- 20261008_parti_amblem_ve_adaylik_ucret_ekrani ----
-- Parti amblemi: yalnızca yetkili parti genel başkanı değiştirebilir.
-- Önceden kaydedilmiş parti amblemlerine, adaylara, ücretlere veya seçimlere dokunulmaz.
create table if not exists oyun.parti_amblem_gecmis(
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id),
 eski_amblem text not null,
 yeni_amblem text not null,
 degistiren uuid not null references auth.users(id),
 zaman timestamptz not null default now()
);
create index if not exists parti_amblem_gecmis_parti_idx on oyun.parti_amblem_gecmis(parti_id,zaman desc);
alter table oyun.parti_amblem_gecmis enable row level security;
revoke all on oyun.parti_amblem_gecmis from public,anon,authenticated;

create or replace function public.parti_amblem_degistir(p_amblem text)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare v_u uuid:=auth.uid(); v_p oyun.partiler; v_t timestamptz:=oyun.simdi();
begin
 if v_u is null then raise exception 'Oturum açmalısın';end if;
 select * into v_p from oyun.partiler
 where gb=v_u and not kapali for update;
 if not found then raise exception 'Amblemi yalnızca görevdeki parti genel başkanı değiştirebilir';end if;
 if p_amblem is null or p_amblem <> all (array['a_ayyildiz','a_yildiz','a_hilal','a_ucok','a_gul','a_lale','a_cinar','a_basak','a_gunes','a_dogangunes','a_mesale','a_kartal','a_kurt','a_aslan','a_at','a_boga','a_guvercin','a_yilan','a_ari','a_elma','a_anahtar','a_terazi','a_kalkan','a_cark','a_capa','a_dag','a_el','a_yildirim'])
 then raise exception 'Geçersiz parti amblemi seçimi';end if;
 if p_amblem=v_p.amblem then raise exception 'Parti zaten bu amblemi kullanıyor';end if;
 insert into oyun.parti_amblem_gecmis(parti_id,eski_amblem,yeni_amblem,degistiren,zaman)
 values(v_p.id,v_p.amblem,p_amblem,v_u,v_t);
 update oyun.partiler set amblem=p_amblem where id=v_p.id;
 perform oyun.olay('parti',v_p.kisa||' parti amblemini değiştirdi',null,v_p.id,v_t);
 return public.parti_detay(v_p.id);
end $f$;
revoke all on function public.parti_amblem_degistir(text) from public,anon;
grant execute on function public.parti_amblem_degistir(text) to authenticated;

-- Önceden çalışan aday ücretlendirmesinin net TL karşılığı: mevcut
-- çarpan (0–3) ve ilgili oyuncunun ili dikkate alınır.
-- Ücret değiştirme yetkisini mevcut public.parti_ucret_ayarla RPC'si denetler.
create or replace function public.parti_ucret_tarife(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare v_uid uuid:=auth.uid();v_p oyun.partiler;v_il smallint;
 v_endeks numeric;v_katsayi numeric;
begin
 if v_uid is null then raise exception 'Oturum açmalısın';end if;
 select * into v_p from oyun.partiler where id=p_parti and not kapali;
 if not found then raise exception 'Parti bulunamadı';end if;
 select il_id into v_il from oyun.profiller where id=v_uid;
 select endeks into v_endeks from oyun.ulke where id=1;
 select case when mv>=14 then 3 when mv>=8 then 2 else 1 end
 into v_katsayi from oyun.iller where id=v_il;
 return jsonb_build_object('parti_id',v_p.id,'genel_baskan_miyim',v_p.gb=v_uid,
 'il', (select ad from oyun.iller where id=v_il),
 'carpanlar',v_p.aday_ucret,
 'taban',jsonb_build_object(
  'mv_on',round(5000*v_endeks),
  'bel_on',round(3000*v_endeks*coalesce(v_katsayi,1)),
  'cb_on',round(20000*v_endeks),
  'kurultay',round(10000*v_endeks)),
 'guncel',jsonb_build_object(
  'mv_on',oyun.aday_ucreti(v_p.id,'mv_on',v_il),
  'bel_on',oyun.aday_ucreti(v_p.id,'bel_on',v_il),
  'cb_on',oyun.aday_ucreti(v_p.id,'cb_on',v_il),
  'kurultay',oyun.aday_ucreti(v_p.id,'kurultay',v_il)));
end $f$;
revoke all on function public.parti_ucret_tarife(bigint) from public,anon;
grant execute on function public.parti_ucret_tarife(bigint) to authenticated;


-- ---- 20261008_turkiye_gundem_gazetesi_taban ----
-- Türkiye Gündem / oyun olaylarindan beslenen otomatik, ucretsiz haber gazetesi.
-- Oyuncu gazetelerinin sahibi, yazarlari, abonelikleri degismez.
create table if not exists oyun.ajans_haberleri(
 id bigint generated always as identity primary key,
 kaynak_anahtar text not null unique,
 kategori text not null check(kategori in ('siyaset','secim','adaylar','ittifak','ekonomi','meclis','yerel','gundem','bulten')),
 baslik text not null,
 ozet text not null,
 metin text not null,
 oncelik integer not null default 40 check(oncelik between 0 and 100),
 parti_id bigint references oyun.partiler(id) on delete set null,
 il_id smallint references oyun.iller(id) on delete set null,
 zaman timestamptz not null default now(),
 olusturma timestamptz not null default now()
);
create index if not exists ajans_haberleri_zaman_idx on oyun.ajans_haberleri (zaman desc,id desc);
create index if not exists ajans_haberleri_kategori_idx on oyun.ajans_haberleri (kategori,zaman desc);
alter table oyun.ajans_haberleri enable row level security;
revoke all on oyun.ajans_haberleri from public,anon,authenticated;

create or replace function oyun.ajans_yayinla(
 p_anahtar text,p_kategori text,p_baslik text,p_ozet text,p_metin text,
 p_oncelik integer default 50,p_parti bigint default null,p_il smallint default null,
 p_zaman timestamptz default null
) returns void language plpgsql set search_path='' as $f$
begin
 if p_anahtar is null or length(p_anahtar) not between 3 and 220 then return;end if;
 if p_kategori not in ('siyaset','secim','adaylar','ittifak','ekonomi','meclis','yerel','gundem','bulten')
 or p_baslik is null or btrim(p_baslik)='' then return;end if;
 insert into oyun.ajans_haberleri
 (kaynak_anahtar,kategori,baslik,ozet,metin,oncelik,parti_id,il_id,zaman)
 values(p_anahtar,p_kategori,left(btrim(p_baslik),170),
  left(btrim(coalesce(p_ozet,'')),360),left(btrim(coalesce(p_metin,'')),5000),
  greatest(0,least(100,coalesce(p_oncelik,50))),p_parti,p_il,
  coalesce(p_zaman,oyun.simdi()))
 on conflict(kaynak_anahtar) do nothing;
end $f$;
revoke all on function oyun.ajans_yayinla(text,text,text,text,text,integer,bigint,smallint,timestamptz) from public,anon,authenticated;

create or replace function public.ajans_haberler(
 p_limit integer default 40,p_kategori text default null,p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path='' as $f$
declare uid uuid:=auth.uid(); n int:=least(60,greatest(1,coalesce(p_limit,40)));
 o int:=least(500,greatest(0,coalesce(p_offset,0)));
begin
 if uid is null then raise exception 'Gazeteyi görmek için oturum açmalısın';end if;
 if p_kategori is not null and p_kategori not in
 ('siyaset','secim','adaylar','ittifak','ekonomi','meclis','yerel','gundem','bulten')
 then raise exception 'Geçersiz haber kategorisi';end if;
 return jsonb_build_object(
  'gazete','TÜRKİYE GÜNDEM','slogan','Oyundaki gerçek olayların bağımsız haber akışı',
  'otomatik',true,'ucretsiz',true,'yayin_tarihi',oyun.simdi(),
  'toplam',(select count(*) from oyun.ajans_haberleri
    where p_kategori is null or kategori=p_kategori),
  'manset',(select jsonb_build_object('id',id,'kategori',kategori,'baslik',baslik,
    'ozet',ozet,'metin',metin,'zaman',zaman,'oncelik',oncelik)
    from oyun.ajans_haberleri
    where zaman>=oyun.simdi()-interval '48 hours'
      and (p_kategori is null or kategori=p_kategori)
    order by oncelik desc,zaman desc,id desc limit 1),
  'haberler',coalesce((
   select jsonb_agg(jsonb_build_object('id',h.id,'kategori',h.kategori,
     'baslik',h.baslik,'ozet',h.ozet,'metin',h.metin,'zaman',h.zaman,
     'oncelik',h.oncelik,'il',i.ad,
     'parti',pa.kisa) order by h.zaman desc,h.id desc)
   from (select * from oyun.ajans_haberleri
         where p_kategori is null or kategori=p_kategori
         order by zaman desc,id desc limit n offset o) h
   left join oyun.partiler pa on pa.id=h.parti_id
   left join oyun.iller i on i.id=h.il_id
  ),'[]'::jsonb));
end $f$;
revoke all on function public.ajans_haberler(integer,text,integer) from public,anon;
grant execute on function public.ajans_haberler(integer,text,integer) to authenticated;


-- ---- 20261008_turkiye_gundem_gazetesi_otomasyon ----
-- Otomatik haber motoru. Gercek kayitlar disinda haber uretmez.
-- 5 dakikada bir calisir; her olay kaynak_anahtar ile YALNIZCA bir kez yayinlanir.
create or replace function oyun.ajans_derle()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare t timestamptz:=oyun.simdi();e record; v_count bigint; v_before bigint;
  kind text; ttl text; summary text; article text; pp integer; name text;
begin
 -- pg_cron ayni anda veya oyun motorunda cagrilsa bile yarisma olmaz.
 if not pg_try_advisory_xact_lock(82771,808) then
   return jsonb_build_object('tamam',true,'mesaj','Başka haber taraması sürüyor');
 end if;
 select count(*) into v_before from oyun.ajans_haberleri;

 -- Kamuya acik parti olaylari: ic oylamalarin/tuzuklerin gizli metinlerini alma.
 for e in
   select o.id,o.zaman,o.metin,o.parti_id,o.il_id,coalesce(p.kisa,'Parti') parti
   from oyun.olaylar o left join oyun.partiler p on p.id=o.parti_id
   where o.zaman>=t-interval '21 days'
     and (o.metin ilike '%beyannamesini açıkladı%'
      or o.metin ilike '%genel başkanlığını üstlendi%'
      or o.metin ilike '%adını%olarak değiştirdi%'
      or o.metin ilike '%adayını açıkladı%'
      or o.metin ilike '%adayını destekliyor%'
      or o.metin ilike '%parti amblemini değiştirdi%'
      or o.metin ilike '%genel başkan yardımcılığına atandı%')
   order by o.zaman,o.id
 loop
   kind:='siyaset';pp:=64;
   if e.metin ilike '%beyannamesini açıkladı%' then
     kind:='secim';pp:=90;ttl:=e.parti||' seçim beyannamesini yayımladı';
   elsif e.metin ilike '%genel başkanlığını üstlendi%' then
     ttl:=e.parti||' yönetiminde yeni genel başkan';pp:=86;
   elsif e.metin ilike '%adını%olarak değiştirdi%' then
     ttl:=e.parti||' siyasi kimliğini yeniledi';pp:=77;
   elsif e.metin ilike '%adayını açıkladı%' or e.metin ilike '%adayını destekliyor%' then
     kind:='adaylar';pp:=85;ttl:=e.parti||' adaylık konusunda karar açıkladı';
   elsif e.metin ilike '%genel başkan yardımcılığına atandı%' then
     ttl:=e.parti||' yönetim kadrosuna yeni atama';pp:=65;
   else
     ttl:=e.parti||' amblemini değiştirdi';pp:=60;
   end if;
   summary:=e.metin;
   article:='Türkiye Gündem haber merkezinin oyun içi resmî olay kaydına göre '||
     e.metin||E'\n\n'||
     'Bu gelişme '||to_char(e.zaman at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI')||
     ' tarihinde kayda geçti. Haberdeki açıklama oyun verilerinden aktarılmıştır. '||
     'Seçim sonucu veya oy oranı konusunda henüz doğrulanmamış bir tahmin yapılmamıştır.';
   perform oyun.ajans_yayinla('olay:'||e.id,kind,ttl,summary,article,pp,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Parti beyannameleri: metin resmi tabloya kaydedildiyse tam metni de ver.
 for e in select b.parti_id,b.donem,b.zaman,b.metin,p.kisa,p.ad
   from oyun.parti_beyanname b join oyun.partiler p on p.id=b.parti_id
   where b.zaman>=t-interval '21 days' order by b.zaman
 loop
   ttl:=e.kisa||' '||e.donem||' seçim beyannamesini açıkladı';
   summary:=e.ad||' seçim vaat ve programını duyurdu.';
   article:=e.ad||' tarafından '||e.donem||' dönemi için seçim beyannamesi yayımlandı.'||
    E'\n\n'||case when nullif(btrim(coalesce(e.metin,'')),'') is not null
      then 'Beyanname açıklaması:'||E'\n'||e.metin
      else 'Yazılı beyanname özeti bulunmuyor; partinin oyun içi vaatleri kendi parti sayfasında incelenebilir.' end||
    E'\n\n'||'Bu bir parti açıklamasıdır; gazetenin desteği ya da görüşü değildir.';
   perform oyun.ajans_yayinla('beyanname:'||e.parti_id||':'||e.donem,'secim',ttl,summary,article,92,e.parti_id,null,e.zaman);
 end loop;

 -- Cumhurbaskani kararlari. Sadece KESIN ve gercek aday kaydi olan adaylar.
 for e in
  select k.donem,k.parti_id,k.yontem,k.destek_parti,k.zaman,
   p.kisa,p.ad,coalesce(h.kisa,'') hedef_kisa,
   a.user_id,pr.kad, a.id aday_id
  from oyun.cb_kararlar k
  join oyun.partiler p on p.id=k.parti_id
  join oyun.secimler s on s.tur='cb' and s.donem=k.donem
  left join oyun.partiler h on h.id=k.destek_parti
  left join lateral (
    select aa.id,aa.user_id from oyun.adaylar aa
    where aa.secim_id=s.id and aa.parti_id=case when k.yontem='destek' then k.destek_parti else k.parti_id end
    order by aa.id limit 1
  ) a on true
  left join oyun.profiller pr on pr.id=a.user_id
  where k.zaman>=t-interval '21 days' and a.id is not null
  order by k.zaman
 loop
  if e.yontem='destek' then
    ttl:=e.kisa||' Cumhurbaşkanlığında '||e.hedef_kisa||' adayını destekleyecek';
    summary:=e.kisa||', '||e.kad||' adlı gerçek oyuncunun ortak adaylığını destekleme kararı aldı.';
    kind:='ittifak';
    article:=e.ad||', '||e.donem||' Cumhurbaşkanlığı seçimi için '||
      e.hedef_kisa||' adayı '||e.kad||' lehine destek kararı açıkladı.'||
      E'\n\n'||'Destek veren partinin ayrıca ikinci bir Cumhurbaşkanı adayı bulunmuyor. '||
      'Seçmenler oylarını tek gerçek oyuncu adaya verecek.';
  else
    ttl:=e.kisa||' Cumhurbaşkanı adayını açıkladı: '||e.kad;
    summary:=e.ad||', Cumhurbaşkanı adayı olarak '||e.kad||' adlı oyuncunun ismini kesinleştirdi.';
    kind:='adaylar';
    article:=e.ad||', '||e.donem||' dönemi Cumhurbaşkanlığı seçiminde '||
      e.kad||' adlı oyuncuyu aday gösterdi.'||E'\n\n'||
      'Adayın ve varsa kendisini destekleyen partilerin ayrıntıları parti sayfasından takip edilebilir.';
  end if;
  perform oyun.ajans_yayinla('cb:'||e.donem||':'||e.parti_id||':'||e.yontem||':'||coalesce(e.aday_id::text,''),
      kind,ttl,summary,article,96,e.parti_id,null,e.zaman);
 end loop;

 -- Belediye kesin adaylari ilan edildikce il odakli haber.
 for e in
 select a.id,a.parti_id,a.il_id,a.basvuru_at,s.donem,p.kisa,p.ad,
   pr.kad,i.ad il
 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id and s.tur='bel'
 join oyun.partiler p on p.id=a.parti_id join oyun.profiller pr on pr.id=a.user_id
 left join oyun.iller i on i.id=a.il_id
 where a.basvuru_at>=t-interval '21 days'
 order by a.basvuru_at
 loop
  ttl:=e.il||' için '||e.kisa||' adayı: '||e.kad;
  summary:=e.ad||', '||e.il||' belediye başkanlığına '||e.kad||' adlı oyuncuyu aday gösterdi.';
  article:=summary||E'\n\n'||e.donem||' belediye seçiminde adaylık kesinleşti. '||
    'Oy verme ve seçim sonucuna ilişkin bilgiler oyundaki resmî takvimden takip edilmelidir.';
  perform oyun.ajans_yayinla('bel_aday:'||e.id,'adaylar',ttl,summary,article,73,e.parti_id,e.il_id,e.basvuru_at);
 end loop;

 -- Il bazinda ortak belediye baskan adayi desteği.
 for e in
 select b.secim_id,b.il_id,b.parti_id,b.hedef_parti_id,b.zaman,src.kisa src,
 target.kisa hedef, pr.kad, il.ad il
 from oyun.bel_aday_destek b
 join oyun.partiler src on src.id=b.parti_id
 join oyun.partiler target on target.id=b.hedef_parti_id
 join oyun.adaylar a on a.id=b.aday_id join oyun.profiller pr on pr.id=a.user_id
 join oyun.iller il on il.id=b.il_id
 where b.zaman>=t-interval '21 days'
 loop
   ttl:=e.il||' seçimi: '||e.src||' ile '||e.hedef||' ortak adayda buluştu';
   summary:=e.src||', '||e.il||' belediye seçiminde '||e.kad||
     ' adayını destekliyor.';
   article:=e.src||', '||e.hedef||' partisinin '||e.il||' belediye başkanı adayı '||e.kad||
      ' lehine destek kararı açıkladı.'||E'\n\n'||
      'Destek veren parti aynı ilde ayrı adayla yarışmıyor; seçmenler ortak adaya oy verecek.';
   perform oyun.ajans_yayinla('bel_destek:'||e.secim_id||':'||e.il_id||':'||e.parti_id||':'||e.hedef_parti_id,
      'ittifak',ttl,summary,article,88,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Genel baskanin tum oyunculara yaptigi ADAY tanitimlari; uyeye ozel yayinlar yayinlanmaz.
 for e in
 select a.id,a.parti_id,a.zaman,a.metin,p.kisa,p.ad,pr.kad
 from oyun.parti_aday_tanitim a
 join oyun.partiler p on p.id=a.parti_id
 join oyun.adaylar ad on ad.id=a.aday_id
 join oyun.profiller pr on pr.id=ad.user_id
 where a.kitle='herkes' and a.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' adayını kamuoyuna tanıttı: '||e.kad;
  summary:=e.ad||', adaylık sürecindeki '||e.kad||' için tanıtım duyurusu yayımladı.';
  article:=summary||E'\n\n'||'Partinin açıklaması:'||E'\n'||e.metin||
      E'\n\n'||'Bu metin ilgili partinin kendi tanıtım duyurusudur.';
  perform oyun.ajans_yayinla('aday_tanitim:'||e.id,'adaylar',ttl,summary,article,70,e.parti_id,null,e.zaman);
 end loop;

 -- Ekonomi: yüksek tutarlı bagislar kamuya acik parti kasa hareketlerinden.
 -- Her bagisi paylasmak yerine asgari ucretin 5 kati ustu haberlestirilir.
 for e in
 select h.id,h.parti_id,h.zaman,h.tutar,h.aciklama,p.kisa
 from oyun.parti_hareket h join oyun.partiler p on p.id=h.parti_id
 where h.tur='bagis' and h.tutar>=5*(select asgari from oyun.ulke where id=1)
 and h.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' kasasına önemli bağış: '||oyun.tl(e.tutar)||' ₺';
  summary:='Partinin mali kayıtlarında '||oyun.tl(e.tutar)||' ₺ bağış işlendi.';
  article:=summary||E'\n\n'||e.aciklama||
   E'\n\n'||'Bu tutar parti kasasına geçen oyun içi paradır.';
  perform oyun.ajans_yayinla('parti_bagis:'||e.id,'ekonomi',ttl,summary,article,68,e.parti_id,null,e.zaman);
 end loop;

 -- Secim sonuclari: kanitlanan resmî sonuc aciklamasi; sonucu olmayan secimi haber yapma.
 for e in
 select id,tur,donem,sonuc_at,sonuc from oyun.secimler
 where sonuc is not null and durum<>'bekliyor' and sonuc_at>=t-interval '21 days'
 loop
  ttl:=case e.tur when 'cb' then 'Cumhurbaşkanlığı' when 'mv' then 'Genel'
      when 'bel' then 'Belediye' else 'Ön' end||' seçiminin sonuçları açıklandı';
  summary:=e.donem||' dönemi için resmî seçim sonuçları yayımlandı.';
  article:=summary||E'\n\n'||'Ayrıntılı aday ve oy sonuçları için oyunun Seçimler bölümündeki sonuç ekranına bakın.';
  perform oyun.ajans_yayinla('secim_sonuc:'||e.id,'secim',ttl,summary,article,98,null,null,e.sonuc_at);
 end loop;

 select count(*)-v_before into v_count from oyun.ajans_haberleri;
 return jsonb_build_object('tamam',true,'yeni_haber',v_count,
   'toplam',(select count(*) from oyun.ajans_haberleri));
end $f$;
revoke all on function oyun.ajans_derle() from public,anon,authenticated;

-- Parti degisikligi ancak gerçekten olmuşsa bildirilir; önemli roller manşete çıkar.
create or replace function oyun.ajans_parti_degisim_trigger()
returns trigger language plpgsql set search_path='' as $f$
declare eski text; yeni text; onemli boolean; puan integer; why text;
begin
 if new.parti_id is not distinct from old.parti_id then return new;end if;
 if new.yasakli then return new;end if;
 select kisa into eski from oyun.partiler where id=old.parti_id;
 select kisa into yeni from oyun.partiler where id=new.parti_id;
 onemli:=exists(select 1 from oyun.partiler where gb=new.id)
      or exists(select 1 from oyun.parti_gby where user_id=new.id)
      or exists(select 1 from oyun.makamlar where user_id=new.id and bit is null)
      or exists(select 1 from oyun.adaylar where user_id=new.id);
 puan:=case when onemli then 91 else 49 end;
 why:=case when old.parti_id is null then 'siyasete parti üyeliğiyle katıldı'
   when new.parti_id is null then 'partisinden ayrıldı'
   else coalesce(eski,'eski partisinden')||' partisinden '||coalesce(yeni,'yeni partisine')||' partisine geçti' end;
 perform oyun.ajans_yayinla(
  'parti_degisim:'||new.id::text||':'||txid_current()::text,
  'siyaset',case when onemli then 'Siyasette dikkat çeken değişim: ' else 'Parti üyeliğinde değişiklik: ' end||new.kad,
  new.kad||' '||why||'.',
  new.kad||' adlı oyuncunun parti üyeliği değişti.'||E'\n\n'||
  'Önceki parti: '||coalesce(eski,'Partisiz')||E'\nYeni parti: '||
   coalesce(yeni,'Partisiz')||E'\n\n'||
  case when onemli then 'Oyuncunun mevcut veya geçmiş siyasi adaylık/yönetim kaydı nedeniyle bu değişiklik öne çıkarılmıştır.'
   else 'Bu değişiklik oyuncunun parti üyeliği kaydından doğrulanmıştır.' end,
  puan,new.parti_id,new.il_id,oyun.simdi());
 return new;
end $f$;
drop trigger if exists ajans_parti_degisimi on oyun.profiller;
create trigger ajans_parti_degisimi after update of parti_id on oyun.profiller
 for each row when (old.parti_id is distinct from new.parti_id)
 execute function oyun.ajans_parti_degisim_trigger();

-- Ekonomi ve parti disinda ittifak olusumu icin de otomatik haber.
create or replace function oyun.ajans_ittifak_trigger()
returns trigger language plpgsql set search_path='' as $f$
declare p text; itt text; hit bigint;pid bigint;op text;
begin
 if TG_OP='DELETE' then hit:=old.ittifak_id;pid:=old.parti_id;op:='ayrildi';
 else hit:=new.ittifak_id;pid:=new.parti_id;op:='katildi';end if;
 select kisa into p from oyun.partiler where id=pid;
 select ad into itt from oyun.ittifaklar where id=hit;
 if p is not null and itt is not null then
 perform oyun.ajans_yayinla('ittifak_'||op||':'||pid||':'||hit||':'||txid_current(),
 'ittifak',p||case when TG_OP='INSERT' then ' ittifaka katıldı' else ' ittifaktan ayrıldı' end,
 p||' partisinin '||itt||' ittifakındaki durumu değişti.',
 p||' partisinin '||itt||' ittifakıyla ilgili üyelik değişikliği oyun kayıtlarında doğrulandı.'||
 E'\n\n'||'Resmî seçimlerde ortak aday desteği ayrıca aday kaydı oluşturulduğunda açıklanır.',
 73,pid,null,oyun.simdi());
 end if;
 if TG_OP='DELETE' then return old;end if;
 return new;
end $f$;
drop trigger if exists ajans_ittifak_uyelik on oyun.ittifak_uyeler;
create trigger ajans_ittifak_uyelik after insert or delete on oyun.ittifak_uyeler
 for each row execute function oyun.ajans_ittifak_trigger();

-- Her 5 dakikada bir. Cron veri taramasi idempotenttir; haber tekrarlamaz.
-- (Kurulum dosyasında pg_cron henüz yoksa atlanır; 04_zamanlayici.sql işi yine kurar.)
do $$ begin
  if to_regnamespace('cron') is not null then
    perform cron.schedule('turkiye-gundem-otomatik-gazete','*/5 * * * *','select oyun.ajans_derle()');
  end if;
end $$;


-- ---- 20261008_turkiye_gundem_genis_haber_kaynaklari ----
-- Geniş gazete ekleri: meclis, kararnameler, referandum, ittifak, makam, şirket ve ekonomi raporu.
CREATE OR REPLACE FUNCTION oyun.ajans_derle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t timestamptz:=oyun.simdi();e record; v_count bigint; v_before bigint;
  kind text; ttl text; summary text; article text; pp integer; name text;
begin
 -- pg_cron ayni anda veya oyun motorunda cagrilsa bile yarisma olmaz.
 if not pg_try_advisory_xact_lock(82771,808) then
   return jsonb_build_object('tamam',true,'mesaj','Başka haber taraması sürüyor');
 end if;
 select count(*) into v_before from oyun.ajans_haberleri;

 -- Kamuya acik parti olaylari: ic oylamalarin/tuzuklerin gizli metinlerini alma.
 for e in
   select o.id,o.zaman,o.metin,o.parti_id,o.il_id,coalesce(p.kisa,'Parti') parti
   from oyun.olaylar o left join oyun.partiler p on p.id=o.parti_id
   where o.zaman>=t-interval '21 days'
     and not (o.metin ilike '%beyannamesini açıkladı%' and exists(
       select 1 from oyun.parti_beyanname b where b.parti_id=o.parti_id
       and b.zaman>=o.zaman-interval '2 days'))
     and (o.metin ilike '%beyannamesini açıkladı%'
      or o.metin ilike '%genel başkanlığını üstlendi%'
      or o.metin ilike '%adını%olarak değiştirdi%'
      or o.metin ilike '%adayını açıkladı%'
      or o.metin ilike '%adayını destekliyor%'
      or o.metin ilike '%parti amblemini değiştirdi%'
      or o.metin ilike '%genel başkan yardımcılığına atandı%')
   order by o.zaman,o.id
 loop
   kind:='siyaset';pp:=64;
   if e.metin ilike '%beyannamesini açıkladı%' then
     kind:='secim';pp:=90;ttl:=e.parti||' seçim beyannamesini yayımladı';
   elsif e.metin ilike '%genel başkanlığını üstlendi%' then
     ttl:=e.parti||' yönetiminde yeni genel başkan';pp:=86;
   elsif e.metin ilike '%adını%olarak değiştirdi%' then
     ttl:=e.parti||' siyasi kimliğini yeniledi';pp:=77;
   elsif e.metin ilike '%adayını açıkladı%' or e.metin ilike '%adayını destekliyor%' then
     kind:='adaylar';pp:=85;ttl:=e.parti||' adaylık konusunda karar açıkladı';
   elsif e.metin ilike '%genel başkan yardımcılığına atandı%' then
     ttl:=e.parti||' yönetim kadrosuna yeni atama';pp:=65;
   else
     ttl:=e.parti||' amblemini değiştirdi';pp:=60;
   end if;
   summary:=e.metin;
   article:='Türkiye Gündem haber merkezinin oyun içi resmî olay kaydına göre '||
     e.metin||E'\n\n'||
     'Bu gelişme '||to_char(e.zaman at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI')||
     ' tarihinde kayda geçti. Haberdeki açıklama oyun verilerinden aktarılmıştır. '||
     'Seçim sonucu veya oy oranı konusunda henüz doğrulanmamış bir tahmin yapılmamıştır.';
   perform oyun.ajans_yayinla('olay:'||e.id,kind,ttl,summary,article,pp,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Parti beyannameleri: metin resmi tabloya kaydedildiyse tam metni de ver.
 for e in select b.parti_id,b.donem,b.zaman,b.metin,p.kisa,p.ad
   from oyun.parti_beyanname b join oyun.partiler p on p.id=b.parti_id
   where b.zaman>=t-interval '21 days' order by b.zaman
 loop
   ttl:=e.kisa||' '||e.donem||' seçim beyannamesini açıkladı';
   summary:=e.ad||' seçim vaat ve programını duyurdu.';
   article:=e.ad||' tarafından '||e.donem||' dönemi için seçim beyannamesi yayımlandı.'||
    E'\n\n'||case when nullif(btrim(coalesce(e.metin,'')),'') is not null
      then 'Beyanname açıklaması:'||E'\n'||e.metin
      else 'Yazılı beyanname özeti bulunmuyor; partinin oyun içi vaatleri kendi parti sayfasında incelenebilir.' end||
    E'\n\n'||'Bu bir parti açıklamasıdır; gazetenin desteği ya da görüşü değildir.';
   perform oyun.ajans_yayinla('beyanname:'||e.parti_id||':'||e.donem,'secim',ttl,summary,article,92,e.parti_id,null,e.zaman);
 end loop;

 -- Cumhurbaskani kararlari. Sadece KESIN ve gercek aday kaydi olan adaylar.
 for e in
  select k.donem,k.parti_id,k.yontem,k.destek_parti,k.zaman,
   p.kisa,p.ad,coalesce(h.kisa,'') hedef_kisa,
   a.user_id,pr.kad, a.id aday_id
  from oyun.cb_kararlar k
  join oyun.partiler p on p.id=k.parti_id
  join oyun.secimler s on s.tur='cb' and s.donem=k.donem
  left join oyun.partiler h on h.id=k.destek_parti
  left join lateral (
    select aa.id,aa.user_id from oyun.adaylar aa
    where aa.secim_id=s.id and aa.parti_id=case when k.yontem='destek' then k.destek_parti else k.parti_id end
    order by aa.id limit 1
  ) a on true
  left join oyun.profiller pr on pr.id=a.user_id
  where k.zaman>=t-interval '21 days' and a.id is not null
  order by k.zaman
 loop
  if e.yontem='destek' then
    ttl:=e.kisa||' Cumhurbaşkanlığında '||e.hedef_kisa||' adayını destekleyecek';
    summary:=e.kisa||', '||e.kad||' adlı gerçek oyuncunun ortak adaylığını destekleme kararı aldı.';
    kind:='ittifak';
    article:=e.ad||', '||e.donem||' Cumhurbaşkanlığı seçimi için '||
      e.hedef_kisa||' adayı '||e.kad||' lehine destek kararı açıkladı.'||
      E'\n\n'||'Destek veren partinin ayrıca ikinci bir Cumhurbaşkanı adayı bulunmuyor. '||
      'Seçmenler oylarını tek gerçek oyuncu adaya verecek.';
  else
    ttl:=e.kisa||' Cumhurbaşkanı adayını açıkladı: '||e.kad;
    summary:=e.ad||', Cumhurbaşkanı adayı olarak '||e.kad||' adlı oyuncunun ismini kesinleştirdi.';
    kind:='adaylar';
    article:=e.ad||', '||e.donem||' dönemi Cumhurbaşkanlığı seçiminde '||
      e.kad||' adlı oyuncuyu aday gösterdi.'||E'\n\n'||
      'Adayın ve varsa kendisini destekleyen partilerin ayrıntıları parti sayfasından takip edilebilir.';
  end if;
  perform oyun.ajans_yayinla('cb:'||e.donem||':'||e.parti_id||':'||e.yontem||':'||coalesce(e.aday_id::text,''),
      kind,ttl,summary,article,96,e.parti_id,null,e.zaman);
 end loop;

 -- Belediye kesin adaylari ilan edildikce il odakli haber.
 for e in
 select a.id,a.parti_id,a.il_id,a.basvuru_at,s.donem,p.kisa,p.ad,
   pr.kad,i.ad il
 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id and s.tur='bel'
 join oyun.partiler p on p.id=a.parti_id join oyun.profiller pr on pr.id=a.user_id
 left join oyun.iller i on i.id=a.il_id
 where a.basvuru_at>=t-interval '21 days'
 order by a.basvuru_at
 loop
  ttl:=e.il||' için '||e.kisa||' adayı: '||e.kad;
  summary:=e.ad||', '||e.il||' belediye başkanlığına '||e.kad||' adlı oyuncuyu aday gösterdi.';
  article:=summary||E'\n\n'||e.donem||' belediye seçiminde adaylık kesinleşti. '||
    'Oy verme ve seçim sonucuna ilişkin bilgiler oyundaki resmî takvimden takip edilmelidir.';
  perform oyun.ajans_yayinla('bel_aday:'||e.id,'adaylar',ttl,summary,article,73,e.parti_id,e.il_id,e.basvuru_at);
 end loop;

 -- Il bazinda ortak belediye baskan adayi desteği.
 for e in
 select b.secim_id,b.il_id,b.parti_id,b.hedef_parti_id,b.zaman,src.kisa src,
 target.kisa hedef, pr.kad, il.ad il
 from oyun.bel_aday_destek b
 join oyun.partiler src on src.id=b.parti_id
 join oyun.partiler target on target.id=b.hedef_parti_id
 join oyun.adaylar a on a.id=b.aday_id join oyun.profiller pr on pr.id=a.user_id
 join oyun.iller il on il.id=b.il_id
 where b.zaman>=t-interval '21 days'
 loop
   ttl:=e.il||' seçimi: '||e.src||' ile '||e.hedef||' ortak adayda buluştu';
   summary:=e.src||', '||e.il||' belediye seçiminde '||e.kad||
     ' adayını destekliyor.';
   article:=e.src||', '||e.hedef||' partisinin '||e.il||' belediye başkanı adayı '||e.kad||
      ' lehine destek kararı açıkladı.'||E'\n\n'||
      'Destek veren parti aynı ilde ayrı adayla yarışmıyor; seçmenler ortak adaya oy verecek.';
   perform oyun.ajans_yayinla('bel_destek:'||e.secim_id||':'||e.il_id||':'||e.parti_id||':'||e.hedef_parti_id,
      'ittifak',ttl,summary,article,88,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Genel baskanin tum oyunculara yaptigi ADAY tanitimlari; uyeye ozel yayinlar yayinlanmaz.
 for e in
 select a.id,a.parti_id,a.zaman,a.metin,p.kisa,p.ad,pr.kad
 from oyun.parti_aday_tanitim a
 join oyun.partiler p on p.id=a.parti_id
 join oyun.adaylar ad on ad.id=a.aday_id
 join oyun.profiller pr on pr.id=ad.user_id
 where a.kitle='herkes' and a.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' adayını kamuoyuna tanıttı: '||e.kad;
  summary:=e.ad||', adaylık sürecindeki '||e.kad||' için tanıtım duyurusu yayımladı.';
  article:=summary||E'\n\n'||'Partinin açıklaması:'||E'\n'||e.metin||
      E'\n\n'||'Bu metin ilgili partinin kendi tanıtım duyurusudur.';
  perform oyun.ajans_yayinla('aday_tanitim:'||e.id,'adaylar',ttl,summary,article,70,e.parti_id,null,e.zaman);
 end loop;

 -- Ekonomi: yüksek tutarlı bagislar kamuya acik parti kasa hareketlerinden.
 -- Her bagisi paylasmak yerine asgari ucretin 5 kati ustu haberlestirilir.
 for e in
 select h.id,h.parti_id,h.zaman,h.tutar,h.aciklama,p.kisa
 from oyun.parti_hareket h join oyun.partiler p on p.id=h.parti_id
 where h.tur='bagis' and h.tutar>=5*(select asgari from oyun.ulke where id=1)
 and h.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' kasasına önemli bağış: '||oyun.tl(e.tutar)||' ₺';
  summary:='Partinin mali kayıtlarında '||oyun.tl(e.tutar)||' ₺ bağış işlendi.';
  article:=summary||E'\n\n'||e.aciklama||
   E'\n\n'||'Bu tutar parti kasasına geçen oyun içi paradır.';
  perform oyun.ajans_yayinla('parti_bagis:'||e.id,'ekonomi',ttl,summary,article,68,e.parti_id,null,e.zaman);
 end loop;

 -- Secim sonuclari: kanitlanan resmî sonuc aciklamasi; sonucu olmayan secimi haber yapma.
 for e in
 select id,tur,donem,sonuc_at,sonuc from oyun.secimler
 where sonuc is not null and durum<>'bekliyor' and sonuc_at>=t-interval '21 days'
 loop
  ttl:=case e.tur when 'cb' then 'Cumhurbaşkanlığı' when 'mv' then 'Genel'
      when 'bel' then 'Belediye' else 'Ön' end||' seçiminin sonuçları açıklandı';
  summary:=e.donem||' dönemi için resmî seçim sonuçları yayımlandı.';
  article:=summary||E'\n\n'||'Ayrıntılı aday ve oy sonuçları için oyunun Seçimler bölümündeki sonuç ekranına bakın.';
  perform oyun.ajans_yayinla('secim_sonuc:'||e.id,'secim',ttl,summary,article,98,null,null,e.sonuc_at);
 end loop;


 -- TBMM: oneriler, onaylanan yasalar; oy sonucu ve yasama statüsü uydurulmaz.
 for e in
   select k.id,k.baslik,k.metin,k.teklif_parti,k.teklif_at,k.sonuc_at,k.durum,
     coalesce(pa.kisa,'TBMM') parti
   from oyun.kanunlar k left join oyun.partiler pa on pa.id=k.teklif_parti
   where k.teklif_at>=t-interval '21 days' or k.sonuc_at>=t-interval '21 days'
 loop
   if e.teklif_at>=t-interval '21 days' then
    ttl:='TBMM gündeminde yeni teklif: '||coalesce(e.baslik,'Kanun teklifi');
    summary:=e.parti||' kaynaklı kanun teklifi Meclis gündemine girdi.';
    article:=summary||E'\n\n'||coalesce(left(e.metin,1600),'Teklifin ayrıntıları Meclis kayıtlarında yer alıyor.')||
       E'\n\n'||'Teklifin kabul edildiği anlamına gelmez; oylama sonucunu takip ediniz.';
    perform oyun.ajans_yayinla('kanun_teklif:'||e.id,'meclis',ttl,summary,article,76,e.teklif_parti,null,e.teklif_at);
   end if;
   if e.sonuc_at>=t-interval '21 days' then
    ttl:='TBMM kararını verdi: '||coalesce(e.baslik,'Kanun teklifi');
    summary:=coalesce(e.baslik,'Teklif')||' hakkında resmî sonuç kaydedildi: '||coalesce(e.durum,'Sonuçlandı');
    article:=summary||E'\n\n'||'Meclis kanun kaydı bu sonuca göre güncellendi. '||
     'Oylama sayıları ve varsa yürürlük etkileri için Meclis bölümünü inceleyin.';
    perform oyun.ajans_yayinla('kanun_sonuc:'||e.id,'meclis',ttl,summary,article,91,e.teklif_parti,null,e.sonuc_at);
   end if;
 end loop;

 -- Cumhurbaşkanlığı kararnameleri.
 for e in
 select id,baslik,metin,zaman,durum,tur from oyun.kararnameler
 where zaman>=t-interval '21 days' order by zaman
 loop
  ttl:='Cumhurbaşkanlığı kararnamesi: '||coalesce(e.baslik,'Yeni düzenleme');
  summary:='Cumhurbaşkanlığı oyun yönetiminde yeni bir kararname kaydı oluşturuldu.';
  article:=summary||E'\n\n'||'Konu: '||coalesce(e.baslik,'Belirtilmedi')||
     E'\nDurum: '||coalesce(e.durum,'Kayıtlı')||
     E'\n\n'||coalesce(left(e.metin,1800),'Ayrıntılar devlet yönetimi bölümünde bulunabilir.');
  perform oyun.ajans_yayinla('kararname:'||e.id,'meclis',ttl,summary,article,85,null,null,e.zaman);
 end loop;

 -- Ulusal referandum duyurulari, kesinlesmis sonuclar.
 for e in
 select id,baslik,olusturma,sonuc,oy_bit,durum,evet,hayir
 from oyun.referandumlar where olusturma>=t-interval '21 days'
  or (oy_bit>=t-interval '21 days' and durum='sonuclandi')
 loop
  if e.olusturma>=t-interval '21 days' then
   ttl:='Referandum süreci: '||e.baslik;
   summary:='Oyunda yeni referandum ilan edildi.';
   perform oyun.ajans_yayinla('referandum_yeni:'||e.id,'secim',ttl,summary,
    summary||E'\n\n'||'Oylama tarihleri ve seçenekleri oyun içindeki referandum ekranında açıklanır.',
    87,null,null,e.olusturma);
  end if;
  if e.durum='sonuclandi' and e.oy_bit>=t-interval '21 days' then
   ttl:='Referandum sonuçlandı: '||e.baslik;
   summary:='Resmî referandum sonucu: '||coalesce(e.sonuc,'Sonuçlandı');
   article:=summary||E'\nEvet oyları: '||coalesce(e.evet,0)||E'\nHayır oyları: '||coalesce(e.hayir,0);
   perform oyun.ajans_yayinla('referandum_sonuc:'||e.id,'secim',ttl,summary,article,97,null,null,e.oy_bit);
  end if;
 end loop;

 -- Gercek ittifak kuruluslari.
 for e in
 select it.id,it.ad,it.kurulus,it.kurucu_parti,p.kisa
 from oyun.ittifaklar it left join oyun.partiler p on p.id=it.kurucu_parti
 where it.kurulus>=t-interval '21 days'
 loop
  ttl:='Siyasette yeni ittifak: '||e.ad;
  summary:=coalesce(e.kisa,'Bir siyasi parti')||' öncülüğünde '||e.ad||' ittifakı kuruldu.';
  article:=summary||E'\n\n'||'İttifak üyeleri ve ortak aday açıklamaları ilgili partilerin sayfalarında görülebilir.';
  perform oyun.ajans_yayinla('ittifak_kurulus:'||e.id,'ittifak',ttl,summary,article,80,e.kurucu_parti,null,e.kurulus);
 end loop;

 -- Onemli devlet gorevlerine getirilen oyuncular.
 for e in
 select m.id,m.tur,m.user_id,m.parti_id,m.bas,p.kad,coalesce(pa.kisa,'Partisiz') parti,
   il.ad il
 from oyun.makamlar m join oyun.profiller p on p.id=m.user_id
 left join oyun.partiler pa on pa.id=m.parti_id
 left join oyun.iller il on il.id=m.il_id
 where m.bas>=t-interval '21 days' and m.bit is null
 loop
   ttl:=e.kad||' yeni kamu görevine başladı';
   summary:=e.kad||' ('||e.parti||') oyuncusunun '||
    coalesce(e.il||' ili ','')||e.tur||' görevi kayıtlara geçti.';
   article:=summary||E'\n\n'||'Görevin başlangıcı oyun sistemindeki resmî makam kaydına dayanır.';
   perform oyun.ajans_yayinla('makam:'||e.id,'siyaset',ttl,summary,article,87,e.parti_id,null,e.bas);
 end loop;

 -- Yeni kurulan önemli işletmeler: ör. 500.000 TL+ sermaye.
 for e in
 select s.id,s.ad,s.sektor,s.sermaye,s.kurulus,p.kad from oyun.sirketler s
 join oyun.profiller p on p.id=s.kurucu
 where s.kurulus>=t-interval '21 days' and s.sermaye>=500000 and s.aktif
 loop
  ttl:='İş dünyasında yeni şirket: '||e.ad;
  summary:=e.kad||', '||e.ad||' adlı '||e.sektor||' işletmesini kurdu.';
  article:=summary||E'\n\n'||'Kayıtlı kuruluş sermayesi: '||oyun.tl(e.sermaye)||' ₺.'||
    E'\n\n'||'Sermaye tutarı geçmiş ya da gelecekteki kârı garanti etmez.';
  perform oyun.ajans_yayinla('sirket_kur:'||e.id,'ekonomi',ttl,summary,article,57,null,null,e.kurulus);
 end loop;

 -- Tarihli ulusal ekonomi raporu; mevcut resmi veriler dışında tahmin yok.
 for e in
 select gun,hazine,vergi,buyume,enflasyon,issizlik,memnuniyet
 from oyun.ulke_gecmis where gun>=((t at time zone 'Europe/Istanbul')::date-14)
 order by gun
 loop
  ttl:='Günlük ekonomi bülteni: '||to_char(e.gun,'DD.MM.YYYY');
  summary:='Enflasyon %'||coalesce(e.enflasyon::text,'—')||
    ', işsizlik %'||coalesce(e.issizlik::text,'—')||' olarak kayıtlara geçti.';
  article:='Türkiye Gündem ekonomi servisi, simülasyonun '||e.gun||' tarihli resmi verilerini derledi.'||
   E'\n\nEnflasyon: %'||coalesce(e.enflasyon::text,'—')||
   E'\nİşsizlik: %'||coalesce(e.issizlik::text,'—')||
   E'\nBüyüme: %'||coalesce(e.buyume::text,'—')||
   E'\nMemnuniyet: '||coalesce(e.memnuniyet::text,'—')||
   E'\nDevlet hazinesi: '||coalesce(oyun.tl(e.hazine),'—')||' ₺'||
   E'\n\n'||'Veriler simülasyonun geçmişte kaydedilmiş göstergeleridir; gerçek Türkiye ekonomisini temsil etmez.';
  perform oyun.ajans_yayinla('ekonomi_gun:'||e.gun,'ekonomi',ttl,summary,article,42,null,null,(e.gun::timestamp at time zone 'Europe/Istanbul')+interval '18 hours');
 end loop;


 select count(*)-v_before into v_count from oyun.ajans_haberleri;
 return jsonb_build_object('tamam',true,'yeni_haber',v_count,
   'toplam',(select count(*) from oyun.ajans_haberleri));
end $function$
;


-- ---- 20261008_sinirsiz_oyun_bagis_sistemi ----
-- Limitsiz bagis ve hediye: sadece oyuncunun gercek mevcut cuzdanindan dusulur.
-- Alıcı kişi, siyasi parti, şirket, oyuncu gazetesi, il ya da devlet.
-- Muhasebe çift kayıtlı, kasa tahsilatları atomik; eski bakiyeler korunur.
create table if not exists oyun.serbest_bagis_kayit(
 id bigint generated always as identity primary key,
 gonderen uuid not null references oyun.profiller(id),
 alici_tur text not null check(alici_tur in ('oyuncu','parti','sirket','gazete','il','devlet')),
 alici_id text,
 alici_adi text not null,
 tutar numeric not null check(tutar>0),
 aciklama text,
 zaman timestamptz not null default now()
);
create index if not exists serbest_bagis_gonderen_idx on oyun.serbest_bagis_kayit(gonderen,zaman desc);
alter table oyun.serbest_bagis_kayit enable row level security;
revoke all on oyun.serbest_bagis_kayit from public,anon,authenticated;

create or replace function public.serbest_bagis(
 p_tur text,p_id text,p_tutar numeric,p_aciklama text default null
) returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 m numeric; tid bigint; v_id bigint; v_uuid uuid; hedef text;
 note text:=btrim(coalesce(p_aciklama,'')); c oyun.cuzdan; v_min numeric;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 if p_tutar is null or p_tutar::text !~ '^[0-9]+(\.[0-9]+)?$'
   or p_tutar<>trunc(p_tutar) or p_tutar<1 then
   raise exception 'Bağış tutarı en az 1 TL, pozitif tam sayı olmalı';end if;
 m:=p_tutar;
 if length(note)>150 then raise exception 'Bağış notu en fazla 150 karakter';end if;
 select * into p from oyun.profiller where id=u;
 if not found or p.yasakli then raise exception 'Hesabın bağış yapmaya uygun değil';end if;
 perform oyun.takip_engel(u,'bağış yapamazsın');
 if p_tur not in ('oyuncu','parti','sirket','gazete','il','devlet') then raise exception 'Geçersiz bağış hedefi';end if;
 -- Para transferinin alıcısı bulunmadan göndericiden tahsilat yapılmaz.
 if p_tur='oyuncu' then
   select id,kad into v_uuid,hedef from oyun.profiller
    where lower(kad)=lower(btrim(coalesce(p_id,''))) and not yasakli limit 1;
   if v_uuid is null then raise exception 'Alıcı oyuncu bulunamadı';end if;
   if v_uuid=u then raise exception 'Kendine bağış yapamazsın';end if;
   if exists(select 1 from oyun.ayarlar where id=1 and coklu_kontrol)
     and exists(select 1 from oyun.bagli_hesaplar(u) b where b.id=v_uuid) then
      raise exception 'Aynı cihazdaki bağlı hesaplara bağış yapılamaz';end if;
   if oyun.engelli(v_uuid,u) then raise exception 'Bu oyuncu seni engelledi';end if;
 elsif p_tur in ('parti','sirket','gazete','il') then
   if p_id is null or p_id !~ '^[0-9]{1,15}$' then raise exception 'Geçerli hedef numarası gir';end if;
   v_id:=p_id::bigint;
   if p_tur='parti' then
     select ad into hedef from oyun.partiler where id=v_id and not kapali;
   elsif p_tur='sirket' then
     select ad into hedef from oyun.sirketler where id=v_id and aktif;
   elsif p_tur='gazete' then
     select ad into hedef from oyun.oyuncu_gazeteleri where id=v_id and aktif;
   else
     select ad into hedef from oyun.iller where id=v_id;
   end if;
   if hedef is null then raise exception 'Bağış yapılacak kurum bulunamadı';end if;
 else
   hedef:='Türkiye Cumhuriyeti Hazinesi';
 end if;
 -- Gonderenin bakiyesi oyun.para_islem tarafindan atomik ve kilitli UPDATE ile kontrol edilir.
 perform oyun.para_islem(u,-m,'bagis',left(hedef||' için bağış'||case when note<>'' then ': '||note else '' end,170),t);
 if p_tur='oyuncu' then
   perform oyun.para_islem(v_uuid,m,'bagis',left(p.kad||' tarafından bağış'||case when note<>'' then ': '||note else '' end,170),t);
   perform oyun.bildir(v_uuid,format('%s sana %s ₺ bağışladı.',p.kad,oyun.tl(m)),t);
 elsif p_tur='parti' then
   update oyun.partiler set kasa=kasa+m where id=v_id;
   insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
     values(v_id,t,m,format('%s bağış yaptı',p.kad),'bagis');
 elsif p_tur='sirket' then
   update oyun.sirketler set kasa=kasa+m where id=v_id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
     values(v_id,t,m,p.kad||' oyuncusundan sermaye niteliğinde olmayan karşılıksız bağış');
 elsif p_tur='gazete' then
   update oyun.oyuncu_gazeteleri set kasa=kasa+m where id=v_id;
   insert into oyun.gazete_hareket(gazete_id,zaman,tutar,tur,aciklama)
     values(v_id,t,m,'bagis',p.kad||' bağış yaptı');
 elsif p_tur='il' then
   select asgari into v_min from oyun.ulke where id=1;
   update oyun.il_durum set gelisim=least(100,gelisim+0.005*m/greatest(1,v_min)) where il_id=v_id;
   insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);
 else
   update oyun.ulke set hazine=hazine+m where id=1;
 end if;
 insert into oyun.serbest_bagis_kayit(gonderen,alici_tur,alici_id,alici_adi,tutar,aciklama,zaman)
 values(u,p_tur,case when p_tur='oyuncu' then v_uuid::text when p_tur='devlet' then '1' else v_id::text end,hedef,m,nullif(note,''),t)
 returning id into tid;
 -- Kıdem kazanımı para miktarıyla sonsuz ölçeklenmez: bağıştan en fazla günlük 1 puan.
 select * into c from oyun.cuzdan where user_id=u for update;
 select asgari into v_min from oyun.ulke where id=1;
 update oyun.cuzdan
 set kidem=kidem+greatest(0,
   least(1,(coalesce(c.bagis_bugun,0)+m)/greatest(1,v_min))
    -least(1,coalesce(c.bagis_bugun,0)/greatest(1,v_min))),
   bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;
 return jsonb_build_object('tamam',true,'id',tid,'gonderen',p.kad,
  'hedef',hedef,'hedef_tur',p_tur,'tutar',m,
  'kalan', (select para from oyun.cuzdan where user_id=u));
end $f$;
revoke all on function public.serbest_bagis(text,text,numeric,text) from public,anon;
grant execute on function public.serbest_bagis(text,text,numeric,text) to authenticated;

-- Eski parti bagisi dugmesi sinirsiz yeni mekanizmayi kullanir.
create or replace function public.bagis_yap(p_miktar numeric)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); pid bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select parti_id into pid from oyun.profiller where id=u;
 if pid is null then raise exception 'Bir partiye üye olmalısın';end if;
 perform public.serbest_bagis('parti',pid::text,p_miktar,null);
 return public.parti_kasa(pid);
end $f$;

-- Sehir bagis butonu da ayni sekilde oyuncunun parasiyla sinirsiz.
create or replace function public.il_bagis(p_miktar numeric)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); il smallint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select il_id into il from oyun.profiller where id=u;
 if il is null then raise exception 'Önce yaşadığın ili seçmelisin';end if;
 perform public.serbest_bagis('il',il::text,p_miktar,null);
 return public.il_bagis_durum();
end $f$;

create or replace function public.il_bagis_durum()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();c oyun.cuzdan;
begin
 c:=oyun.cuzdanim(p.id);
 return jsonb_build_object('il_ad',(select ad from oyun.iller where id=p.il_id),
 'gelisim',(select round(gelisim,2) from oyun.il_durum where il_id=p.il_id),
 'bugun',c.bagis_bugun,'tavan',null,
 'ay_toplam',coalesce((select sum(tutar) from oyun.il_bagis_kayit
 where il_id=p.il_id and zaman>t-interval '30 days'),0),
 'benim_toplam',coalesce((select sum(tutar) from oyun.il_bagis_kayit where il_id=p.il_id and user_id=p.id),0),
 'top',(select coalesce(jsonb_agg(jsonb_build_object('kad',x.kad,'toplam',x.s) order by x.s desc),'[]'::jsonb)
 from (select pr.kad,sum(b.tutar) s from oyun.il_bagis_kayit b
 join oyun.profiller pr on pr.id=b.user_id where b.il_id=p.il_id
 and b.zaman>t-interval '30 days' group by pr.kad order by sum(b.tutar) desc limit 5)x));
end $f$;

revoke all on function public.bagis_yap(numeric),public.il_bagis(numeric) from public,anon;
grant execute on function public.bagis_yap(numeric),public.il_bagis(numeric) to authenticated;

create or replace function public.bagis_gecmisim()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 return jsonb_build_object('hareketler',coalesce((
 select jsonb_agg(jsonb_build_object('tur',x.alici_tur,'alici',x.alici_adi,
 'tutar',x.tutar,'tarih',x.zaman,'not',x.aciklama) order by x.zaman desc,x.id desc)
 from (select * from oyun.serbest_bagis_kayit where gonderen=u order by zaman desc,id desc limit 60)x
 ),'[]'::jsonb));
end $f$;
revoke all on function public.bagis_gecmisim() from public,anon;
grant execute on function public.bagis_gecmisim() to authenticated;


-- ---- 20261008_sinirsiz_bagis_hedef_listesi ----
-- Tüm oyuncuların seçebileceği kamuya açık bağış alıcıları.
-- Başka oyuncuların özel mali verileri açıklanmaz.
create or replace function public.bagis_hedefleri()
returns jsonb language plpgsql security definer set search_path='' as $f$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;
 return jsonb_build_object(
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad,'kisa',kisa)
    order by ad) from oyun.partiler where not kapali),'[]'::jsonb),
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad)
    order by ad) from oyun.sirketler where aktif),'[]'::jsonb),
 'gazeteler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad)
    order by ad) from oyun.oyuncu_gazeteleri where aktif),'[]'::jsonb),
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad)
    order by ad) from oyun.iller),'[]'::jsonb));
end $f$;
revoke all on function public.bagis_hedefleri() from public,anon;
grant execute on function public.bagis_hedefleri() to authenticated;


-- ---- 20261008_gazete_beyanname_tekrari_sehir_bagisi ----
-- Belediye gelisimine ek olarak, oyuncunun sehre gonderdigi para il belediyesinin gercek kasasina girer.
CREATE OR REPLACE FUNCTION public.serbest_bagis(p_tur text, p_id text, p_tutar numeric, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 m numeric; tid bigint; v_id bigint; v_uuid uuid; hedef text;
 note text:=btrim(coalesce(p_aciklama,'')); c oyun.cuzdan; v_min numeric;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 if p_tutar is null or p_tutar::text !~ '^[0-9]+(\.[0-9]+)?$'
   or p_tutar<>trunc(p_tutar) or p_tutar<1 then
   raise exception 'Bağış tutarı en az 1 TL, pozitif tam sayı olmalı';end if;
 m:=p_tutar;
 if length(note)>150 then raise exception 'Bağış notu en fazla 150 karakter';end if;
 select * into p from oyun.profiller where id=u;
 if not found or p.yasakli then raise exception 'Hesabın bağış yapmaya uygun değil';end if;
 perform oyun.takip_engel(u,'bağış yapamazsın');
 if p_tur not in ('oyuncu','parti','sirket','gazete','il','devlet') then raise exception 'Geçersiz bağış hedefi';end if;
 -- Para transferinin alıcısı bulunmadan göndericiden tahsilat yapılmaz.
 if p_tur='oyuncu' then
   select id,kad into v_uuid,hedef from oyun.profiller
    where lower(kad)=lower(btrim(coalesce(p_id,''))) and not yasakli limit 1;
   if v_uuid is null then raise exception 'Alıcı oyuncu bulunamadı';end if;
   if v_uuid=u then raise exception 'Kendine bağış yapamazsın';end if;
   if exists(select 1 from oyun.ayarlar where id=1 and coklu_kontrol)
     and exists(select 1 from oyun.bagli_hesaplar(u) b where b.id=v_uuid) then
      raise exception 'Aynı cihazdaki bağlı hesaplara bağış yapılamaz';end if;
   if oyun.engelli(v_uuid,u) then raise exception 'Bu oyuncu seni engelledi';end if;
 elsif p_tur in ('parti','sirket','gazete','il') then
   if p_id is null or p_id !~ '^[0-9]{1,15}$' then raise exception 'Geçerli hedef numarası gir';end if;
   v_id:=p_id::bigint;
   if p_tur='parti' then
     select ad into hedef from oyun.partiler where id=v_id and not kapali;
   elsif p_tur='sirket' then
     select ad into hedef from oyun.sirketler where id=v_id and aktif;
   elsif p_tur='gazete' then
     select ad into hedef from oyun.oyuncu_gazeteleri where id=v_id and aktif;
   else
     select ad into hedef from oyun.iller where id=v_id;
   end if;
   if hedef is null then raise exception 'Bağış yapılacak kurum bulunamadı';end if;
 else
   hedef:='Türkiye Cumhuriyeti Hazinesi';
 end if;
 -- Gonderenin bakiyesi oyun.para_islem tarafindan atomik ve kilitli UPDATE ile kontrol edilir.
 perform oyun.para_islem(u,-m,'bagis',left(hedef||' için bağış'||case when note<>'' then ': '||note else '' end,170),t);
 if p_tur='oyuncu' then
   perform oyun.para_islem(v_uuid,m,'bagis',left(p.kad||' tarafından bağış'||case when note<>'' then ': '||note else '' end,170),t);
   perform oyun.bildir(v_uuid,format('%s sana %s ₺ bağışladı.',p.kad,oyun.tl(m)),t);
 elsif p_tur='parti' then
   update oyun.partiler set kasa=kasa+m where id=v_id;
   insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
     values(v_id,t,m,format('%s bağış yaptı',p.kad),'bagis');
 elsif p_tur='sirket' then
   update oyun.sirketler set kasa=kasa+m where id=v_id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
     values(v_id,t,m,p.kad||' oyuncusundan sermaye niteliğinde olmayan karşılıksız bağış');
 elsif p_tur='gazete' then
   update oyun.oyuncu_gazeteleri set kasa=kasa+m where id=v_id;
   insert into oyun.gazete_hareket(gazete_id,zaman,tutar,tur,aciklama)
     values(v_id,t,m,'bagis',p.kad||' bağış yaptı');
 elsif p_tur='il' then
   select asgari into v_min from oyun.ulke where id=1;
   update oyun.il_durum set kasa=kasa+m,gelisim=least(100,gelisim+0.005*m/greatest(1,v_min)) where il_id=v_id;
   insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);
 else
   update oyun.ulke set hazine=hazine+m where id=1;
 end if;
 insert into oyun.serbest_bagis_kayit(gonderen,alici_tur,alici_id,alici_adi,tutar,aciklama,zaman)
 values(u,p_tur,case when p_tur='oyuncu' then v_uuid::text when p_tur='devlet' then '1' else v_id::text end,hedef,m,nullif(note,''),t)
 returning id into tid;
 -- Kıdem kazanımı para miktarıyla sonsuz ölçeklenmez: bağıştan en fazla günlük 1 puan.
 select * into c from oyun.cuzdan where user_id=u for update;
 select asgari into v_min from oyun.ulke where id=1;
 update oyun.cuzdan
 set kidem=kidem+greatest(0,
   least(1,(coalesce(c.bagis_bugun,0)+m)/greatest(1,v_min))
    -least(1,coalesce(c.bagis_bugun,0)/greatest(1,v_min))),
   bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;
 return jsonb_build_object('tamam',true,'id',tid,'gonderen',p.kad,
  'hedef',hedef,'hedef_tur',p_tur,'tutar',m,
  'kalan', (select para from oyun.cuzdan where user_id=u));
end $function$
;

-- Seçim beyannamesi haberini resmi kaynaktan bir kere yayinla, olay logundan ikincisini uretme.
CREATE OR REPLACE FUNCTION oyun.ajans_derle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t timestamptz:=oyun.simdi();e record; v_count bigint; v_before bigint;
  kind text; ttl text; summary text; article text; pp integer; name text;
begin
 -- pg_cron ayni anda veya oyun motorunda cagrilsa bile yarisma olmaz.
 if not pg_try_advisory_xact_lock(82771,808) then
   return jsonb_build_object('tamam',true,'mesaj','Başka haber taraması sürüyor');
 end if;
 select count(*) into v_before from oyun.ajans_haberleri;

 -- Kamuya acik parti olaylari: ic oylamalarin/tuzuklerin gizli metinlerini alma.
 for e in
   select o.id,o.zaman,o.metin,o.parti_id,o.il_id,coalesce(p.kisa,'Parti') parti
   from oyun.olaylar o left join oyun.partiler p on p.id=o.parti_id
   where o.zaman>=t-interval '21 days'
     and not (o.metin ilike '%beyannamesini açıkladı%' and exists(
       select 1 from oyun.parti_beyanname b where b.parti_id=o.parti_id
       and b.zaman>=o.zaman-interval '2 days'))
     and (o.metin ilike '%beyannamesini açıkladı%'
      or o.metin ilike '%genel başkanlığını üstlendi%'
      or o.metin ilike '%adını%olarak değiştirdi%'
      or o.metin ilike '%adayını açıkladı%'
      or o.metin ilike '%adayını destekliyor%'
      or o.metin ilike '%parti amblemini değiştirdi%'
      or o.metin ilike '%genel başkan yardımcılığına atandı%')
   order by o.zaman,o.id
 loop
   kind:='siyaset';pp:=64;
   if e.metin ilike '%beyannamesini açıkladı%' then
     kind:='secim';pp:=90;ttl:=e.parti||' seçim beyannamesini yayımladı';
   elsif e.metin ilike '%genel başkanlığını üstlendi%' then
     ttl:=e.parti||' yönetiminde yeni genel başkan';pp:=86;
   elsif e.metin ilike '%adını%olarak değiştirdi%' then
     ttl:=e.parti||' siyasi kimliğini yeniledi';pp:=77;
   elsif e.metin ilike '%adayını açıkladı%' or e.metin ilike '%adayını destekliyor%' then
     kind:='adaylar';pp:=85;ttl:=e.parti||' adaylık konusunda karar açıkladı';
   elsif e.metin ilike '%genel başkan yardımcılığına atandı%' then
     ttl:=e.parti||' yönetim kadrosuna yeni atama';pp:=65;
   else
     ttl:=e.parti||' amblemini değiştirdi';pp:=60;
   end if;
   summary:=e.metin;
   article:='Türkiye Gündem haber merkezinin oyun içi resmî olay kaydına göre '||
     e.metin||E'\n\n'||
     'Bu gelişme '||to_char(e.zaman at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI')||
     ' tarihinde kayda geçti. Haberdeki açıklama oyun verilerinden aktarılmıştır. '||
     'Seçim sonucu veya oy oranı konusunda henüz doğrulanmamış bir tahmin yapılmamıştır.';
   perform oyun.ajans_yayinla('olay:'||e.id,kind,ttl,summary,article,pp,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Parti beyannameleri: metin resmi tabloya kaydedildiyse tam metni de ver.
 for e in select b.parti_id,b.donem,b.zaman,b.metin,p.kisa,p.ad
   from oyun.parti_beyanname b join oyun.partiler p on p.id=b.parti_id
   where b.zaman>=t-interval '21 days' order by b.zaman
 loop
   ttl:=e.kisa||' '||e.donem||' seçim beyannamesini açıkladı';
   summary:=e.ad||' seçim vaat ve programını duyurdu.';
   article:=e.ad||' tarafından '||e.donem||' dönemi için seçim beyannamesi yayımlandı.'||
    E'\n\n'||case when nullif(btrim(coalesce(e.metin,'')),'') is not null
      then 'Beyanname açıklaması:'||E'\n'||e.metin
      else 'Yazılı beyanname özeti bulunmuyor; partinin oyun içi vaatleri kendi parti sayfasında incelenebilir.' end||
    E'\n\n'||'Bu bir parti açıklamasıdır; gazetenin desteği ya da görüşü değildir.';
   perform oyun.ajans_yayinla('beyanname:'||e.parti_id||':'||e.donem,'secim',ttl,summary,article,92,e.parti_id,null,e.zaman);
 end loop;

 -- Cumhurbaskani kararlari. Sadece KESIN ve gercek aday kaydi olan adaylar.
 for e in
  select k.donem,k.parti_id,k.yontem,k.destek_parti,k.zaman,
   p.kisa,p.ad,coalesce(h.kisa,'') hedef_kisa,
   a.user_id,pr.kad, a.id aday_id
  from oyun.cb_kararlar k
  join oyun.partiler p on p.id=k.parti_id
  join oyun.secimler s on s.tur='cb' and s.donem=k.donem
  left join oyun.partiler h on h.id=k.destek_parti
  left join lateral (
    select aa.id,aa.user_id from oyun.adaylar aa
    where aa.secim_id=s.id and aa.parti_id=case when k.yontem='destek' then k.destek_parti else k.parti_id end
    order by aa.id limit 1
  ) a on true
  left join oyun.profiller pr on pr.id=a.user_id
  where k.zaman>=t-interval '21 days' and a.id is not null
  order by k.zaman
 loop
  if e.yontem='destek' then
    ttl:=e.kisa||' Cumhurbaşkanlığında '||e.hedef_kisa||' adayını destekleyecek';
    summary:=e.kisa||', '||e.kad||' adlı gerçek oyuncunun ortak adaylığını destekleme kararı aldı.';
    kind:='ittifak';
    article:=e.ad||', '||e.donem||' Cumhurbaşkanlığı seçimi için '||
      e.hedef_kisa||' adayı '||e.kad||' lehine destek kararı açıkladı.'||
      E'\n\n'||'Destek veren partinin ayrıca ikinci bir Cumhurbaşkanı adayı bulunmuyor. '||
      'Seçmenler oylarını tek gerçek oyuncu adaya verecek.';
  else
    ttl:=e.kisa||' Cumhurbaşkanı adayını açıkladı: '||e.kad;
    summary:=e.ad||', Cumhurbaşkanı adayı olarak '||e.kad||' adlı oyuncunun ismini kesinleştirdi.';
    kind:='adaylar';
    article:=e.ad||', '||e.donem||' dönemi Cumhurbaşkanlığı seçiminde '||
      e.kad||' adlı oyuncuyu aday gösterdi.'||E'\n\n'||
      'Adayın ve varsa kendisini destekleyen partilerin ayrıntıları parti sayfasından takip edilebilir.';
  end if;
  perform oyun.ajans_yayinla('cb:'||e.donem||':'||e.parti_id||':'||e.yontem||':'||coalesce(e.aday_id::text,''),
      kind,ttl,summary,article,96,e.parti_id,null,e.zaman);
 end loop;

 -- Belediye kesin adaylari ilan edildikce il odakli haber.
 for e in
 select a.id,a.parti_id,a.il_id,a.basvuru_at,s.donem,p.kisa,p.ad,
   pr.kad,i.ad il
 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id and s.tur='bel'
 join oyun.partiler p on p.id=a.parti_id join oyun.profiller pr on pr.id=a.user_id
 left join oyun.iller i on i.id=a.il_id
 where a.basvuru_at>=t-interval '21 days'
 order by a.basvuru_at
 loop
  ttl:=e.il||' için '||e.kisa||' adayı: '||e.kad;
  summary:=e.ad||', '||e.il||' belediye başkanlığına '||e.kad||' adlı oyuncuyu aday gösterdi.';
  article:=summary||E'\n\n'||e.donem||' belediye seçiminde adaylık kesinleşti. '||
    'Oy verme ve seçim sonucuna ilişkin bilgiler oyundaki resmî takvimden takip edilmelidir.';
  perform oyun.ajans_yayinla('bel_aday:'||e.id,'adaylar',ttl,summary,article,73,e.parti_id,e.il_id,e.basvuru_at);
 end loop;

 -- Il bazinda ortak belediye baskan adayi desteği.
 for e in
 select b.secim_id,b.il_id,b.parti_id,b.hedef_parti_id,b.zaman,src.kisa src,
 target.kisa hedef, pr.kad, il.ad il
 from oyun.bel_aday_destek b
 join oyun.partiler src on src.id=b.parti_id
 join oyun.partiler target on target.id=b.hedef_parti_id
 join oyun.adaylar a on a.id=b.aday_id join oyun.profiller pr on pr.id=a.user_id
 join oyun.iller il on il.id=b.il_id
 where b.zaman>=t-interval '21 days'
 loop
   ttl:=e.il||' seçimi: '||e.src||' ile '||e.hedef||' ortak adayda buluştu';
   summary:=e.src||', '||e.il||' belediye seçiminde '||e.kad||
     ' adayını destekliyor.';
   article:=e.src||', '||e.hedef||' partisinin '||e.il||' belediye başkanı adayı '||e.kad||
      ' lehine destek kararı açıkladı.'||E'\n\n'||
      'Destek veren parti aynı ilde ayrı adayla yarışmıyor; seçmenler ortak adaya oy verecek.';
   perform oyun.ajans_yayinla('bel_destek:'||e.secim_id||':'||e.il_id||':'||e.parti_id||':'||e.hedef_parti_id,
      'ittifak',ttl,summary,article,88,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Genel baskanin tum oyunculara yaptigi ADAY tanitimlari; uyeye ozel yayinlar yayinlanmaz.
 for e in
 select a.id,a.parti_id,a.zaman,a.metin,p.kisa,p.ad,pr.kad
 from oyun.parti_aday_tanitim a
 join oyun.partiler p on p.id=a.parti_id
 join oyun.adaylar ad on ad.id=a.aday_id
 join oyun.profiller pr on pr.id=ad.user_id
 where a.kitle='herkes' and a.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' adayını kamuoyuna tanıttı: '||e.kad;
  summary:=e.ad||', adaylık sürecindeki '||e.kad||' için tanıtım duyurusu yayımladı.';
  article:=summary||E'\n\n'||'Partinin açıklaması:'||E'\n'||e.metin||
      E'\n\n'||'Bu metin ilgili partinin kendi tanıtım duyurusudur.';
  perform oyun.ajans_yayinla('aday_tanitim:'||e.id,'adaylar',ttl,summary,article,70,e.parti_id,null,e.zaman);
 end loop;

 -- Ekonomi: yüksek tutarlı bagislar kamuya acik parti kasa hareketlerinden.
 -- Her bagisi paylasmak yerine asgari ucretin 5 kati ustu haberlestirilir.
 for e in
 select h.id,h.parti_id,h.zaman,h.tutar,h.aciklama,p.kisa
 from oyun.parti_hareket h join oyun.partiler p on p.id=h.parti_id
 where h.tur='bagis' and h.tutar>=5*(select asgari from oyun.ulke where id=1)
 and h.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' kasasına önemli bağış: '||oyun.tl(e.tutar)||' ₺';
  summary:='Partinin mali kayıtlarında '||oyun.tl(e.tutar)||' ₺ bağış işlendi.';
  article:=summary||E'\n\n'||e.aciklama||
   E'\n\n'||'Bu tutar parti kasasına geçen oyun içi paradır.';
  perform oyun.ajans_yayinla('parti_bagis:'||e.id,'ekonomi',ttl,summary,article,68,e.parti_id,null,e.zaman);
 end loop;

 -- Secim sonuclari: kanitlanan resmî sonuc aciklamasi; sonucu olmayan secimi haber yapma.
 for e in
 select id,tur,donem,sonuc_at,sonuc from oyun.secimler
 where sonuc is not null and durum<>'bekliyor' and sonuc_at>=t-interval '21 days'
 loop
  ttl:=case e.tur when 'cb' then 'Cumhurbaşkanlığı' when 'mv' then 'Genel'
      when 'bel' then 'Belediye' else 'Ön' end||' seçiminin sonuçları açıklandı';
  summary:=e.donem||' dönemi için resmî seçim sonuçları yayımlandı.';
  article:=summary||E'\n\n'||'Ayrıntılı aday ve oy sonuçları için oyunun Seçimler bölümündeki sonuç ekranına bakın.';
  perform oyun.ajans_yayinla('secim_sonuc:'||e.id,'secim',ttl,summary,article,98,null,null,e.sonuc_at);
 end loop;

 select count(*)-v_before into v_count from oyun.ajans_haberleri;
 return jsonb_build_object('tamam',true,'yeni_haber',v_count,
   'toplam',(select count(*) from oyun.ajans_haberleri));
end $function$
;

delete from oyun.ajans_haberleri h
using oyun.olaylar o
where h.kaynak_anahtar='olay:'||o.id
  and o.metin ilike '%beyannamesini açıkladı%'
  and exists(select 1 from oyun.parti_beyanname b
     where b.parti_id=o.parti_id and b.zaman>=o.zaman-interval '2 days');


-- ---- 20261008_serbest_bagis_bagli_hesap_duzeltme ----
-- Oyuncudan oyuncuya bağış: bağlı hesaplar scalar UUID döndürür.
CREATE OR REPLACE FUNCTION public.serbest_bagis(p_tur text, p_id text, p_tutar numeric, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 m numeric; tid bigint; v_id bigint; v_uuid uuid; hedef text;
 note text:=btrim(coalesce(p_aciklama,'')); c oyun.cuzdan; v_min numeric;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 if p_tutar is null or p_tutar::text !~ '^[0-9]+(\.[0-9]+)?$'
   or p_tutar<>trunc(p_tutar) or p_tutar<1 then
   raise exception 'Bağış tutarı en az 1 TL, pozitif tam sayı olmalı';end if;
 m:=p_tutar;
 if length(note)>150 then raise exception 'Bağış notu en fazla 150 karakter';end if;
 select * into p from oyun.profiller where id=u;
 if not found or p.yasakli then raise exception 'Hesabın bağış yapmaya uygun değil';end if;
 perform oyun.takip_engel(u,'bağış yapamazsın');
 if p_tur not in ('oyuncu','parti','sirket','gazete','il','devlet') then raise exception 'Geçersiz bağış hedefi';end if;
 -- Para transferinin alıcısı bulunmadan göndericiden tahsilat yapılmaz.
 if p_tur='oyuncu' then
   select id,kad into v_uuid,hedef from oyun.profiller
    where lower(kad)=lower(btrim(coalesce(p_id,''))) and not yasakli limit 1;
   if v_uuid is null then raise exception 'Alıcı oyuncu bulunamadı';end if;
   if v_uuid=u then raise exception 'Kendine bağış yapamazsın';end if;
   if exists(select 1 from oyun.ayarlar where id=1 and coklu_kontrol)
     and exists(select 1 from oyun.bagli_hesaplar(u) b where b=v_uuid) then
      raise exception 'Aynı cihazdaki bağlı hesaplara bağış yapılamaz';end if;
   if oyun.engelli(v_uuid,u) then raise exception 'Bu oyuncu seni engelledi';end if;
 elsif p_tur in ('parti','sirket','gazete','il') then
   if p_id is null or p_id !~ '^[0-9]{1,15}$' then raise exception 'Geçerli hedef numarası gir';end if;
   v_id:=p_id::bigint;
   if p_tur='parti' then
     select ad into hedef from oyun.partiler where id=v_id and not kapali;
   elsif p_tur='sirket' then
     select ad into hedef from oyun.sirketler where id=v_id and aktif;
   elsif p_tur='gazete' then
     select ad into hedef from oyun.oyuncu_gazeteleri where id=v_id and aktif;
   else
     select ad into hedef from oyun.iller where id=v_id;
   end if;
   if hedef is null then raise exception 'Bağış yapılacak kurum bulunamadı';end if;
 else
   hedef:='Türkiye Cumhuriyeti Hazinesi';
 end if;
 -- Gonderenin bakiyesi oyun.para_islem tarafindan atomik ve kilitli UPDATE ile kontrol edilir.
 perform oyun.para_islem(u,-m,'bagis',left(hedef||' için bağış'||case when note<>'' then ': '||note else '' end,170),t);
 if p_tur='oyuncu' then
   perform oyun.para_islem(v_uuid,m,'bagis',left(p.kad||' tarafından bağış'||case when note<>'' then ': '||note else '' end,170),t);
   perform oyun.bildir(v_uuid,format('%s sana %s ₺ bağışladı.',p.kad,oyun.tl(m)),t);
 elsif p_tur='parti' then
   update oyun.partiler set kasa=kasa+m where id=v_id;
   insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
     values(v_id,t,m,format('%s bağış yaptı',p.kad),'bagis');
 elsif p_tur='sirket' then
   update oyun.sirketler set kasa=kasa+m where id=v_id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
     values(v_id,t,m,p.kad||' oyuncusundan sermaye niteliğinde olmayan karşılıksız bağış');
 elsif p_tur='gazete' then
   update oyun.oyuncu_gazeteleri set kasa=kasa+m where id=v_id;
   insert into oyun.gazete_hareket(gazete_id,zaman,tutar,tur,aciklama)
     values(v_id,t,m,'bagis',p.kad||' bağış yaptı');
 elsif p_tur='il' then
   select asgari into v_min from oyun.ulke where id=1;
   update oyun.il_durum set kasa=kasa+m,gelisim=least(100,gelisim+0.005*m/greatest(1,v_min)) where il_id=v_id;
   insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);
 else
   update oyun.ulke set hazine=hazine+m where id=1;
 end if;
 insert into oyun.serbest_bagis_kayit(gonderen,alici_tur,alici_id,alici_adi,tutar,aciklama,zaman)
 values(u,p_tur,case when p_tur='oyuncu' then v_uuid::text when p_tur='devlet' then '1' else v_id::text end,hedef,m,nullif(note,''),t)
 returning id into tid;
 -- Kıdem kazanımı para miktarıyla sonsuz ölçeklenmez: bağıştan en fazla günlük 1 puan.
 select * into c from oyun.cuzdan where user_id=u for update;
 select asgari into v_min from oyun.ulke where id=1;
 update oyun.cuzdan
 set kidem=kidem+greatest(0,
   least(1,(coalesce(c.bagis_bugun,0)+m)/greatest(1,v_min))
    -least(1,coalesce(c.bagis_bugun,0)/greatest(1,v_min))),
   bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;
 return jsonb_build_object('tamam',true,'id',tid,'gonderen',p.kad,
  'hedef',hedef,'hedef_tur',p_tur,'tutar',m,
  'kalan', (select para from oyun.cuzdan where user_id=u));
end $function$
;

