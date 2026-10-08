-- Sirketler, oyuncu bankalari, asgari ucret ve dokunulmazlik (sanal oyun).
create table if not exists oyun.sirketler(
 id bigint generated always as identity primary key,
 ad text not null, sektor text not null check(sektor in ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka')),
 kurucu uuid not null references auth.users(id),sermaye numeric not null check(sermaye>0),
 kasa numeric not null default 0,son_islem timestamptz not null default now(),
 kurulus timestamptz not null default now(),aktif boolean not null default true,
 satilik numeric, banka_faiz numeric not null default 2, banka_kredi_faiz numeric not null default 5
);
create table if not exists oyun.sirket_ortaklari(
 sirket_id bigint not null references oyun.sirketler(id),user_id uuid not null references auth.users(id),
 pay numeric not null check(pay>0 and pay<=100),primary key(sirket_id,user_id)
);
create table if not exists oyun.sirket_hareket(
 id bigint generated always as identity primary key,sirket_id bigint not null references oyun.sirketler(id),
 zaman timestamptz not null default now(),tutar numeric not null,aciklama text not null
);
create table if not exists oyun.sirket_teklif(
 id bigint generated always as identity primary key,sirket_id bigint not null references oyun.sirketler(id),
 satici uuid not null references auth.users(id),alici uuid not null references auth.users(id),
 pay numeric not null check(pay>0 and pay<=100),bedel numeric not null check(bedel>0),
 durum text not null default 'bekliyor',zaman timestamptz not null default now()
);
create table if not exists oyun.banka_mevduat(
 id bigint generated always as identity primary key,banka_id bigint not null references oyun.sirketler(id),
 user_id uuid not null references auth.users(id),anapara numeric not null check(anapara>0),
 faiz numeric not null,acilis timestamptz not null default now(),vade timestamptz not null,kapandi boolean not null default false
);
create table if not exists oyun.dokunulmazlik_kayit(
 id bigint generated always as identity primary key,kanun_id bigint references oyun.kanunlar(id),
 aktif boolean not null,zaman timestamptz not null default now()
);
insert into oyun.dokunulmazlik_kayit(aktif) select false where not exists(select 1 from oyun.dokunulmazlik_kayit);
alter table oyun.sirketler enable row level security;
alter table oyun.sirket_ortaklari enable row level security;
alter table oyun.sirket_hareket enable row level security;
alter table oyun.sirket_teklif enable row level security;
alter table oyun.banka_mevduat enable row level security;
alter table oyun.dokunulmazlik_kayit enable row level security;
revoke all on oyun.sirketler,oyun.sirket_ortaklari,oyun.sirket_hareket,oyun.sirket_teklif,oyun.banka_mevduat,oyun.dokunulmazlik_kayit from public,anon,authenticated;

create or replace function oyun.sirket_hesapla(p_id bigint)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare s oyun.sirketler;n int;w numeric;ciro numeric;net numeric;factor numeric;t timestamptz:=oyun.simdi();rate numeric;
begin
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif then return;end if;
 n:=least(90,floor(extract(epoch from (t-s.son_islem))/86400)::int);
 if n<=0 then return;end if;
 -- Sektor bazli risk; her gun sabit kazanc garanti edilmez.
 factor:=case s.sektor when 'tarim' then .012 when 'sanayi' then .016 when 'teknoloji' then .022 when 'ticaret' then .014 when 'insaat' then .020 when 'medya' then .018 else .009 end;
 w:=(select asgari from oyun.ulke where id=1);
 ciro:=round(s.sermaye*factor*n*(0.5+random()*1.5),2);
 net:=round(ciro-(s.sermaye*.009*n)-(w*.12*n)-(s.sermaye*random()*.015*n),2);
 if s.sektor='banka' then net:=round(net*.6,2);end if;
 update oyun.sirketler set kasa=kasa+net,son_islem=son_islem+n*interval '1 day' where id=p_id;
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama) values(p_id,net,format('%s gunluk faaliyet sonucu (gelir, maas, gider ve risk)',n));
end $$;
create or replace function public.sirket_kur(p_ad text,p_sektor text,p_sermaye numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();id bigint;t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli';end if;
 if p_ad is null or length(btrim(p_ad)) not between 3 and 50 then raise exception 'Sirket adi 3-50 karakter olmali';end if;
 if p_sektor not in ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka') then raise exception 'Gecersiz sektor';end if;
 if p_sermaye is null or p_sermaye<>round(p_sermaye) or p_sermaye<(case when p_sektor='banka' then 1000000 else 100000 end) or p_sermaye>100000000 then raise exception 'Sermaye alt siniri sirket icin 100.000, banka icin 1.000.000 TL';end if;
 perform oyun.para_islem(u,-p_sermaye,'sirket','Sirket kurulus sermayesi',t);
 insert into oyun.sirketler(ad,sektor,kurucu,sermaye,kasa,son_islem,kurulus) values(btrim(p_ad),p_sektor,u,p_sermaye,p_sermaye,t,t) returning oyun.sirketler.id into id;
 insert into oyun.sirket_ortaklari values(id,u,100);
 return jsonb_build_object('id',id);
end $$;
create or replace function public.sirket_liste()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();x record;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 for x in select distinct s.id from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id where o.user_id=u and s.aktif loop perform oyun.sirket_hesapla(x.id);end loop;
 return jsonb_build_object('sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'sektor',s.sektor,'kasa',s.kasa,'sermaye',s.sermaye,'pay',o.pay,'satilik',s.satilik,'faiz',s.banka_faiz)) from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id where o.user_id=u and s.aktif),'[]'::jsonb),
 'pazar',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad,'sektor',sektor,'fiyat',satilik)) from oyun.sirketler where satilik is not null and aktif),'[]'::jsonb),
 'teklifler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'sirket_id',sirket_id,'pay',pay,'bedel',bedel)) from oyun.sirket_teklif where alici=u and durum='bekliyor'),'[]'::jsonb));
end $$;
create or replace function public.sirket_pay_teklif(p_sirket bigint,p_alici uuid,p_pay numeric,p_bedel numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();ownpay numeric;
begin
 if p_alici=u or p_alici is null or not exists(select 1 from oyun.profiller where id=p_alici) then raise exception 'Gecerli baska oyuncu sec';end if;
 select pay into ownpay from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=u for update;
 if ownpay is null or p_pay is null or p_pay<=0 or p_pay>ownpay or p_bedel is null or p_bedel<=0 then raise exception 'Pay veya bedel gecersiz';end if;
 insert into oyun.sirket_teklif(sirket_id,satici,alici,pay,bedel) values(p_sirket,u,p_alici,p_pay,p_bedel);
 return jsonb_build_object('tamam',true);
end $$;
create or replace function public.sirket_pay_kabul(p_teklif bigint)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();o oyun.sirket_teklif;ownpay numeric;t timestamptz:=oyun.simdi();
begin
 select * into o from oyun.sirket_teklif where id=p_teklif for update;
 if o.alici is distinct from u or o.durum<>'bekliyor' then raise exception 'Teklif bulunamadi';end if;
 perform pg_advisory_xact_lock(o.sirket_id);
 select pay into ownpay from oyun.sirket_ortaklari where sirket_id=o.sirket_id and user_id=o.satici for update;
 if ownpay<o.pay then raise exception 'Saticinin payi yetersiz';end if;
 perform oyun.para_islem(u,-o.bedel,'sirket','Sirket payi satin alimi',t);
 perform oyun.para_islem(o.satici,o.bedel,'sirket','Sirket payi satisi',t);
 update oyun.sirket_ortaklari set pay=pay-o.pay where sirket_id=o.sirket_id and user_id=o.satici;
 delete from oyun.sirket_ortaklari where sirket_id=o.sirket_id and user_id=o.satici and pay=0;
 insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(o.sirket_id,u,o.pay)
 on conflict(sirket_id,user_id) do update set pay=oyun.sirket_ortaklari.pay+excluded.pay;
 update oyun.sirket_teklif set durum='kabul' where id=p_teklif;
 update oyun.sirket_teklif set durum='iptal' where sirket_id=o.sirket_id and satici=o.satici and durum='bekliyor' and id<>p_teklif;
 return jsonb_build_object('tamam',true);
end $$;
create or replace function public.sirket_kar_payi(p_sirket bigint,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();s oyun.sirketler;x record;t timestamptz:=oyun.simdi();
begin
 perform oyun.sirket_hesapla(p_sirket);
 select * into s from oyun.sirketler where id=p_sirket for update;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=u and pay>=50) then raise exception 'Kar payi dagitimi icin en az %50 pay gerekli';end if;
 if p_tutar is null or p_tutar<=0 or p_tutar>greatest(s.kasa,0) then raise exception 'Sirket kasasinda yeterli para yok';end if;
 update oyun.sirketler set kasa=kasa-p_tutar where id=p_sirket;
 for x in select * from oyun.sirket_ortaklari where sirket_id=p_sirket loop
 perform oyun.para_islem(x.user_id,round(p_tutar*x.pay/100,2),'sirket','Sirket kar payi',t);
 end loop;
 return jsonb_build_object('tamam',true);
end $$;
create or replace function public.banka_mevduat_yatir(p_banka bigint,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();s oyun.sirketler;t timestamptz:=oyun.simdi();
begin
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if s.id is null then raise exception 'Banka bulunamadi';end if;
 if p_tutar is null or p_tutar<1000 or p_tutar>10000000 then raise exception 'Tutar 1000-10000000 olmali';end if;
 perform oyun.para_islem(u,-p_tutar,'mevduat','Oyuncu bankasina vadeli mevduat',t);
 update oyun.sirketler set kasa=kasa+p_tutar where id=p_banka;
 insert into oyun.banka_mevduat(banka_id,user_id,anapara,faiz,vade) values(p_banka,u,p_tutar,s.banka_faiz,t+interval '7 days');
 return jsonb_build_object('tamam',true);
end $$;
create or replace function public.banka_mevduat_tahsil()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();m record;t timestamptz:=oyun.simdi();pay numeric;
begin
 for m in select * from oyun.banka_mevduat where user_id=u and not kapandi and vade<=t for update loop
  pay:=round(m.anapara*(1+m.faiz/100),2);
  update oyun.sirketler set kasa=kasa-pay where id=m.banka_id and kasa>=pay;
  if found then
    perform oyun.para_islem(u,pay,'mevduat','Oyuncu bankasi mevduat vade odemesi',t);
    update oyun.banka_mevduat set kapandi=true where id=m.id;
  end if;
 end loop;
 return jsonb_build_object('mevduatlar',coalesce((select jsonb_agg(jsonb_build_object('id',id,'banka',banka_id,'tutar',anapara,'faiz',faiz,'vade',vade,'odendi',kapandi)) from oyun.banka_mevduat where user_id=u),'[]'::jsonb));
end $$;
create or replace function public.banka_faiz_belirle(p_banka bigint,p_faiz numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
begin
 if p_faiz is null or p_faiz<0 or p_faiz>15 then raise exception 'Haftalik faiz 0-15 arasinda olmali';end if;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=auth.uid() and pay>=50) then raise exception 'Banka yonetim yetkin yok';end if;
 update oyun.sirketler set banka_faiz=p_faiz where id=p_banka and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 return jsonb_build_object('tamam',true);
end $$;

-- Meclis teklifleri: asgari ucret ve milletvekili dokunulmazligi.
create or replace function public.ozel_yasa_teklif(p_tur text,p_deger numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();s record;id bigint;bas text;met text;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Yalnizca milletvekili teklif verebilir';end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then raise exception 'Meclis baskani teklif veremez';end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then raise exception 'Bekleyen teklifin var';end if;
 if p_tur='asgari' then
  if p_deger is null or p_deger<10000 or p_deger>500000 or p_deger<>round(p_deger) then raise exception 'Asgari ucret 10000-500000 TL olmali';end if;
  bas:='Asgari Ucretin Yeniden Belirlenmesi';met:='Asgari ucret '||p_deger||' TL olarak belirlensin. Sirketlerin personel maliyetleri ve kamu ekonomisi etkilensin.';
 elsif p_tur='dokunulmazlik' then
  if p_deger not in (0,1) then raise exception '0 kaldirma, 1 getirme';end if;
  bas:='Milletvekili Dokunulmazligi Duzenlemesi';met:=case when p_deger=1 then 'Milletvekili dokunulmazligi yururluge girsin.' else 'Milletvekili dokunulmazligi kaldirilsin.' end;
 else raise exception 'Gecersiz teklif turu';end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',bas,met,jsonb_build_object('ozel_yasa',p_tur,'deger',p_deger),p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama) returning oyun.kanunlar.id into id;
 perform oyun.olay('meclis',format('%s yeni yasa teklifi sundu: %s',p.kad,bas),null,p.parti_id,t);
 return jsonb_build_object('id',id);
end $$;
create or replace function oyun.ozel_yasa_yururluk()
returns trigger language plpgsql security definer set search_path='' as $$
declare tur text;val numeric;
begin
 if new.durum<>'yururlukte' or old.durum='yururlukte' then return new;end if;
 tur:=new.veri->>'ozel_yasa';val:=(new.veri->>'deger')::numeric;
 if tur='asgari' then
  update oyun.ulke set asgari=val,asgari_ref=val where id=1;
 elsif tur='dokunulmazlik' then
  insert into oyun.dokunulmazlik_kayit(kanun_id,aktif) values(new.id,val=1);
 end if;
 return new;
end $$;
drop trigger if exists ozel_yasa_yururluk on oyun.kanunlar;
create trigger ozel_yasa_yururluk after update of durum on oyun.kanunlar for each row execute function oyun.ozel_yasa_yururluk();
create or replace function public.ozel_yasa_durum()
returns jsonb language sql security definer set search_path='' as $$
select jsonb_build_object('asgari',(select asgari from oyun.ulke where id=1),
'dokunulmazlik',(select aktif from oyun.dokunulmazlik_kayit order by id desc limit 1))
$$;
revoke all on function public.sirket_kur(text,text,numeric),public.sirket_liste(),public.sirket_pay_teklif(bigint,uuid,numeric,numeric),public.sirket_pay_kabul(bigint),public.sirket_kar_payi(bigint,numeric),public.banka_mevduat_yatir(bigint,numeric),public.banka_mevduat_tahsil(),public.banka_faiz_belirle(bigint,numeric),public.ozel_yasa_teklif(text,numeric),public.ozel_yasa_durum() from public,anon;
grant execute on function public.sirket_kur(text,text,numeric),public.sirket_liste(),public.sirket_pay_teklif(bigint,uuid,numeric,numeric),public.sirket_pay_kabul(bigint),public.sirket_kar_payi(bigint,numeric),public.banka_mevduat_yatir(bigint,numeric),public.banka_mevduat_tahsil(),public.banka_faiz_belirle(bigint,numeric),public.ozel_yasa_teklif(text,numeric),public.ozel_yasa_durum() to authenticated;
