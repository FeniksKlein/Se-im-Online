
-- Books: real manuscript, publisher approval, printing inventory, NPC/player sales and author royalties.
create table if not exists oyun.uc_kitap(
 id bigint generated always as identity primary key,
 yayinevi bigint not null references oyun.sirketler(id),
 yazar uuid not null references oyun.profiller(id),
 baslik text not null check(length(baslik) between 4 and 100),
 tur text not null default 'Siyasi hatırat', ozet text not null default '', icerik text not null,
 durum text not null default 'teklif' check(durum in ('teklif','yayinda','reddedildi')),
 fiyat numeric not null default 0, stok int not null default 0, satilan int not null default 0,
 telif_orani numeric not null default 15, olusturma timestamptz not null default now(),
 yayin timestamptz,son_satis timestamptz
);
create table if not exists oyun.uc_kitap_satis(
 id bigint generated always as identity primary key,
 kitap_id bigint not null references oyun.uc_kitap(id),
 alici uuid references oyun.profiller(id), adet int not null check(adet>0),
 ciro numeric not null, telif numeric not null,
 zaman timestamptz not null default now(), donem timestamptz
);
create unique index if not exists uc_kitap_donem on oyun.uc_kitap_satis(kitap_id,donem) where donem is not null;
create unique index if not exists uc_kitap_alici on oyun.uc_kitap_satis(kitap_id,alici) where alici is not null;
revoke all on oyun.uc_kitap,oyun.uc_kitap_satis from public,anon,authenticated;
alter table oyun.uc_kitap enable row level security;
alter table oyun.uc_kitap_satis enable row level security;
create or replace function oyun.uc_kitap_kazanc(p_id bigint,p_adet int,p_alici uuid,p_donem timestamptz)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare k oyun.uc_kitap; b numeric; royalty numeric; kdv numeric; kv numeric; netmatrah numeric; sale bigint;
begin
 select * into k from oyun.uc_kitap where id=p_id for update;
 if k.id is null or k.durum<>'yayinda' or k.stok<p_adet or p_adet not between 1 and 30
 then raise exception 'Kitap stokta bulunamadı';end if;
 b:=k.fiyat*p_adet; royalty:=round(b*k.telif_orani/100);
 kdv:=oyun.eko_vergi_hesap('satis',b);
 netmatrah:=greatest(0,b-royalty-round(k.fiyat*.4)*p_adet-kdv);
 kv:=oyun.eko_vergi_hesap('kar',netmatrah);
 insert into oyun.uc_kitap_satis(kitap_id,alici,adet,ciro,telif,donem,zaman)
 values(k.id,p_alici,p_adet,b,royalty,p_donem,oyun.simdi()) returning id into sale;
 update oyun.uc_kitap set stok=stok-p_adet,satilan=satilan+p_adet where id=k.id;
 update oyun.sirketler set kasa=kasa+b-royalty-kdv-kv where id=k.yayinevi and aktif;
 if not found then raise exception 'Yayınevi faal değil';end if;
 perform oyun.cuzdanim(k.yazar);
 update oyun.cuzdan set para=para+royalty where user_id=k.yazar;
 if oyun.eko_vergi_tahsil(k.yayinevi,'satis',b,'uc_kitap_satis',sale)<>kdv then raise exception 'KDV tahsilatı uyuşmadı';end if;
 if oyun.eko_vergi_tahsil(k.yayinevi,'kar',netmatrah,'uc_kitap_kar',sale)<>kv then raise exception 'Kâr vergisi tahsilatı uyuşmadı';end if;
 return jsonb_build_object('adet',p_adet,'ciro',b,'telif',royalty,'vergi',kdv+kv);
end $$;
revoke all on function oyun.uc_kitap_kazanc(bigint,integer,uuid,timestamptz) from public,anon,authenticated;
create or replace function public.uc_kitap_panel() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid();
begin
 perform oyun.profilim();
 return jsonb_build_object(
 'yayinevleri',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad,'kasa',kasa))
 from oyun.sirketler where aktif and sektor='medya'),'[]'::jsonb),
 'benim_yayinevleri',coalesce((select jsonb_agg(s.id)
 from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id
 where s.aktif and s.sektor='medya' and o.user_id=u and o.pay>=50),'[]'::jsonb),
 'kitaplar',coalesce((select jsonb_agg(jsonb_build_object('id',k.id,'baslik',k.baslik,'tur',k.tur,
  'ozet',k.ozet,'icerik',k.icerik,'yazar',(select kad from oyun.profiller where id=k.yazar),
  'yazar_benim',k.yazar=u,'yayinevi',k.yayinevi,'yayinevi_ad',s.ad,
  'durum',k.durum,'fiyat',k.fiyat,'stok',k.stok,'satilan',k.satilan,'telif',k.telif_orani,
  'aldim',exists(select 1 from oyun.uc_kitap_satis a where a.kitap_id=k.id and a.alici=u)))
  from oyun.uc_kitap k join oyun.sirketler s on s.id=k.yayinevi
  where k.durum='yayinda' or k.yazar=u or exists(select 1 from oyun.sirket_ortaklari o
    where o.sirket_id=k.yayinevi and o.user_id=u and o.pay>=50)),'[]'::jsonb));
end $$;
revoke all on function public.uc_kitap_panel() from public,anon;
grant execute on function public.uc_kitap_panel() to authenticated;
create or replace function public.uc_kitap_islem(p_islem text,p_id bigint,p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); s oyun.sirketler;
 k oyun.uc_kitap; title text; qty int; price numeric; expense numeric; bid bigint;
begin
 perform oyun.profilim();
 if p_veri is null or jsonb_typeof(p_veri)<>'object' then raise exception 'Veri hatalı';end if;
 if p_islem='teklif' then
  select * into s from oyun.sirketler where id=p_id and sektor='medya' and aktif;
  if s.id is null then raise exception 'Yayınevi bulunamadı';end if;
  title:=trim(coalesce(p_veri->>'baslik',''));
  if length(title) not between 4 and 100 or length(coalesce(p_veri->>'icerik','')) not between 100 and 15000
  or length(coalesce(p_veri->>'ozet',''))>600
  then raise exception 'Başlık 4-100, kitap metni 100-15000, özet en çok 600 karakter olmalı';end if;
  if (select count(*) from oyun.uc_kitap where yazar=u and durum='teklif')>=5
  then raise exception 'En fazla 5 bekleyen kitap teklifi olabilir';end if;
  insert into oyun.uc_kitap(yayinevi,yazar,baslik,tur,ozet,icerik,olusturma)
  values(s.id,u,title,left(coalesce(p_veri->>'tur','Siyasi hatırat'),40),
  left(coalesce(p_veri->>'ozet',''),600),p_veri->>'icerik',t) returning id into bid;
  return jsonb_build_object('id',bid,'durum','teklif');
 end if;
 select * into k from oyun.uc_kitap where id=p_id for update;
 if k.id is null then raise exception 'Kitap bulunamadı';end if;
 if p_islem='satinal' then
  if k.durum<>'yayinda' or k.stok<1 or k.yazar=u then raise exception 'Kitap satışı uygun değil';end if;
  if exists(select 1 from oyun.uc_kitap_satis where kitap_id=k.id and alici=u) then raise exception 'Kitabı zaten aldın';end if;
  update oyun.cuzdan set para=para-k.fiyat where user_id=u and para>=k.fiyat;
  if not found then raise exception 'Bakiye yetersiz';end if;
  return oyun.uc_kitap_kazanc(k.id,1,u,null);
 end if;
 select * into s from oyun.sirketler where id=k.yayinevi and aktif for update;
 if s.id is null or not exists(select 1 from oyun.sirket_ortaklari
  where sirket_id=s.id and user_id=u and pay>=50)
 then raise exception 'Yayınevini yönetme yetkin yok';end if;
 if p_islem='reddet' then
  update oyun.uc_kitap set durum='reddedildi' where id=k.id and durum='teklif';
  if not found then raise exception 'Bekleyen teklif bulunamadı';end if;
  return jsonb_build_object('durum','reddedildi');
 elsif p_islem in ('yayinla','yenibaski') then
  if (p_islem='yayinla' and k.durum<>'teklif') or
   (p_islem='yenibaski' and k.durum<>'yayinda')
  then raise exception 'Kitap durumu uygun değil';end if;
  qty:=coalesce(nullif(p_veri->>'adet','')::int,0);
  price:=case when p_islem='yenibaski' then k.fiyat else coalesce(nullif(p_veri->>'fiyat','')::numeric,0) end;
  if qty not between 10 and 200 or price not between 100 and 2000 then raise exception 'Baskı 10-200, fiyat 100-2000 TL olmalı';end if;
  expense:=round(qty*price*.4);
  update oyun.sirketler set kasa=kasa-expense where id=s.id and kasa>=expense;
  if not found then raise exception 'Baskı gideri için kasa yetersiz';end if;
  update oyun.uc_kitap set fiyat=price,stok=stok+qty,durum='yayinda',
    yayin=coalesce(yayin,t),son_satis=coalesce(son_satis,t) where id=k.id;
  return jsonb_build_object('baski',qty,'gider',expense);
 end if;
 raise exception 'Bilinmeyen kitap işlemi';
end $$;
revoke all on function public.uc_kitap_islem(text,bigint,jsonb) from public,anon;
grant execute on function public.uc_kitap_islem(text,bigint,jsonb) to authenticated;
create or replace function oyun.uc_kitap_tick() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare t timestamptz:=oyun.simdi(); k record; qty int; done int:=0; r jsonb;
begin
 if not pg_try_advisory_xact_lock(827614) then return jsonb_build_object('kilitli',true);end if;
 for k in select b.id,b.fiyat,b.stok from oyun.uc_kitap b
  join oyun.sirketler s on s.id=b.yayinevi and s.aktif
  where b.durum='yayinda' and b.stok>0 and b.son_satis<=t-interval '6 hours'
  order by b.id limit 100 for update of b skip locked
 loop
  update oyun.uc_kitap set son_satis=t where id=k.id;
  qty:=least(k.stok,20,greatest(1,round(8*power(400.0/greatest(k.fiyat,100),.6))::int));
  r:=oyun.uc_kitap_kazanc(k.id,qty,null,date_trunc('hour',t));
  done:=done+1;
 end loop;
 return jsonb_build_object('yayinevi_satis_donemi',done);
end $$;
revoke all on function oyun.uc_kitap_tick() from public,anon,authenticated;
do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  perform cron.schedule('uc-kitap-satis','*/10 * * * *','select oyun.uc_kitap_tick();');
 end if;
end $$;
