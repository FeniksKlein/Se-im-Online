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
  select coalesce(sum(round(anapara*(1+faiz/100),2)),0),
    coalesce(sum(anapara),0),
    coalesce(sum(round(anapara*(1+faiz/100),2)) filter(where vade<=oyun.simdi()+interval '24 hours'),0)
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
 yeni:=round(p_tutar*(1+f/100),2);
 select coalesce(sum(round(anapara*(1+faiz/100),2)),0),coalesce(sum(anapara),0)
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
 f:=oyun.oyb_oran(p_banka,p_saat); yeni:=round(p_tutar*(1+f/100),2);
 select coalesce(sum(round(anapara*(1+faiz/100),2)),0),coalesce(sum(anapara),0)
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
   'anapara',m.anapara,'oran',m.faiz,'getiri',round(m.anapara*m.faiz/100,2),
   'odeme',round(m.anapara*(1+m.faiz/100),2),'saat',m.vade_saat,
   'acilis',m.acilis,'vade',m.vade,'kapandi',m.kapandi,'iptal',m.iptal,
   'cekilebilir',m.kapandi=false and s.kasa>=case when t<m.vade then m.anapara else round(m.anapara*(1+m.faiz/100),2) end,
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
 erken:=t<m.vade; odeme:=case when erken then m.anapara else round(m.anapara*(1+m.faiz/100),2) end;
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
