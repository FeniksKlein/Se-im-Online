-- 2026-10-08: Sanal piyango, kazı kazan ve ortak saatlik yatırım piyasası.
-- Geçmiş oyuncu bakiyesi, biletler ve hesaplar silinmez.

-- 1) Milli Piyango: 6 haneli biletin son 2 hanesi eşleşirse (%1).
-- Aynı çekilişte birden fazla kazanan varsa büyük ikramiye eşit bölüşülür.
alter table oyun.piyango_donem add column if not exists kazanan_adet integer not null default 0;
create table if not exists oyun.piyango_odul (
 bilet_id bigint primary key references oyun.piyango_bilet(id),
 donem_id bigint not null references oyun.piyango_donem(id),
 user_id uuid not null references auth.users(id),
 tutar numeric not null check(tutar >= 0),
 odenme timestamptz not null default now()
);
create index if not exists piyango_odul_user on oyun.piyango_odul(user_id,odenme desc);
alter table oyun.piyango_odul enable row level security;
revoke all on oyun.piyango_odul from public,anon,authenticated;

create or replace function oyun.piyango_guncelle()
returns bigint language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare
 t timestamptz:=now(); bas timestamptz; curid bigint;
 prev record; winning integer; first_winner uuid; cnt int; per_ticket numeric;
 b record; roll numeric:=1000000;
begin
 perform pg_advisory_xact_lock(77890011);
 bas:=timestamptz '2026-10-08 00:00:00+00'+floor(extract(epoch from (t-timestamptz '2026-10-08 00:00:00+00'))/604800)*interval '7 days';
 for prev in select * from oyun.piyango_donem where bitis<=t and not cekildi order by baslangic for update loop
   winning:=floor(random()*1000000)::int;
   select count(*) into cnt from oyun.piyango_bilet
     where donem_id=prev.id and mod(numara,100)=mod(winning,100);
   per_ticket:=case when cnt>0 then trunc(prev.ikramiye/cnt,0) else 0 end;
   first_winner:=null;
   if cnt>0 then
     for b in select id,user_id from oyun.piyango_bilet
       where donem_id=prev.id and mod(numara,100)=mod(winning,100) order by id loop
       insert into oyun.piyango_odul(bilet_id,donem_id,user_id,tutar)
         values(b.id,prev.id,b.user_id,per_ticket) on conflict do nothing;
       if found and per_ticket>0 then
         perform oyun.para_islem(b.user_id,per_ticket,'piyango','Milli Piyango ödülü',t);
       end if;
       first_winner:=coalesce(first_winner,b.user_id);
     end loop;
   end if;
   update oyun.piyango_donem set cekildi=true,kazanan_no=winning,kazanan=first_winner,
     kazanan_adet=cnt,cekilis_at=t where id=prev.id;
 end loop;
 select id into curid from oyun.piyango_donem where baslangic=bas;
 if curid is null then
   select case when kazanan_adet=0 then ikramiye else 1000000 end
     into roll from oyun.piyango_donem where bitis<=bas order by bitis desc limit 1;
   insert into oyun.piyango_donem(baslangic,bitis,ikramiye)
      values(bas,bas+interval '7 days',coalesce(roll,1000000))
      on conflict(baslangic) do update set baslangic=excluded.baslangic returning id into curid;
 end if;
 return curid;
end $$;
revoke all on function oyun.piyango_guncelle() from public,anon,authenticated;

create or replace function public.piyango_durum()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); d bigint; result jsonb;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 d:=oyun.piyango_guncelle();
 select jsonb_build_object('ikramiye',p.ikramiye,'bitis',p.bitis,'bilet_bedeli',1000,
 'bilet_sayisi',p.bilet_sayisi,'kazanma_ihtimali','1/100',
 'biletler',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'numara',lpad(b.numara::text,6,'0')) order by b.id desc)
   from oyun.piyango_bilet b where b.donem_id=d and b.user_id=u),'[]'::jsonb),
 'sonuc',(select jsonb_build_object('kazanan_no',lpad(x.kazanan_no::text,6,'0'),
   'devretti',x.kazanan_adet=0,'kazanan_adet',x.kazanan_adet,'ikramiye',x.ikramiye,
   'kazancim',coalesce((select sum(o.tutar) from oyun.piyango_odul o where o.donem_id=x.id and o.user_id=u),0))
   from oyun.piyango_donem x where x.cekildi order by x.bitis desc limit 1))
 into result from oyun.piyango_donem p where p.id=d;
 return result;
end $$;
revoke all on function public.piyango_durum() from public,anon;
grant execute on function public.piyango_durum() to authenticated;

-- 2) Kazı Kazan: olasılıklar 7200/1800/700/250/45/5 (10.000 üzerinden).
-- Beklenen brüt ödeme: 84,50 TL; uzun dönem beklenen devlet neti: 15,50 TL/bilet.
create table if not exists oyun.kazikazan_kayit (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id),
 zaman timestamptz not null default now(),
 bedel integer not null default 100 check(bedel=100),
 odul integer not null check(odul in (0,100,200,1000,5000,10000))
);
create index if not exists kazikazan_user_zaman on oyun.kazikazan_kayit(user_id,zaman desc);
alter table oyun.kazikazan_kayit enable row level security;
revoke all on oyun.kazikazan_kayit from public,anon,authenticated;

create or replace function public.kazikazan_durum()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 return jsonb_build_object('bedel',100,'cuzdan',(select para from oyun.cuzdan where user_id=u),
 'toplam_bilet',(select count(*) from oyun.kazikazan_kayit where user_id=u),
 'toplam_odul',(select coalesce(sum(odul),0) from oyun.kazikazan_kayit where user_id=u),
 'son',coalesce((select jsonb_agg(to_jsonb(x)) from
     (select id,zaman,bedel,odul from oyun.kazikazan_kayit where user_id=u order by id desc limit 15) x),'[]'::jsonb));
end $$;
create or replace function public.kazikazan_oyna()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); roll int; odul int; no bigint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 -- Ani tekrarlanan istemci çağrılarına sınır; oyuncuların parası ve ödülleri sunucuda hesaplanır.
 if (select count(*) from oyun.kazikazan_kayit where user_id=u and zaman > now()-interval '1 minute')>=30
 then raise exception 'Bir dakikada en fazla 30 Kazı Kazan oynayabilirsin.'; end if;
 perform oyun.para_islem(u,-100,'kazikazan','Kazı Kazan bileti',now());
 roll:=1+floor(random()*10000)::int;
 odul:=case when roll<=7200 then 0 when roll<=9000 then 100 when roll<=9700 then 200
            when roll<=9950 then 1000 when roll<=9995 then 5000 else 10000 end;
 insert into oyun.kazikazan_kayit(user_id,bedel,odul) values(u,100,odul) returning id into no;
 if odul>0 then perform oyun.para_islem(u,odul,'kazikazan','Kazı Kazan ödülü # '||no,now()); end if;
 -- Hazine milyon oyun-TL biriminde. Bilet geliri - ödül, gerçekleşen net tutar.
 update oyun.ulke set hazine=hazine+(100-odul)/1000000.0 where id=1;
 return jsonb_build_object('id',no,'bedel',100,'odul',odul,'net',odul-100,
  'cuzdan',(select para from oyun.cuzdan where user_id=u));
end $$;
revoke all on function public.kazikazan_durum() from public,anon;
revoke all on function public.kazikazan_oyna() from public,anon;
grant execute on function public.kazikazan_durum() to authenticated;
grant execute on function public.kazikazan_oyna() to authenticated;

-- 3) Tek merkezli simülasyon piyasası. Gerçek piyasa API'si değildir.
create table if not exists oyun.piyasa_varlik (
 kod text primary key check (kod ~ '^[A-Z0-9_]+$'),
 ad text not null,
 sinif text not null check(sinif in ('doviz','altin','hisse')),
 fiyat numeric(22,6) not null check(fiyat>0),
 onceki numeric(22,6) not null check(onceki>0),
 oynaklik numeric not null check(oynaklik between 0 and 0.1),
 saat timestamptz not null,
 aktif boolean not null default true
);
create table if not exists oyun.piyasa_fiyat (
 kod text not null references oyun.piyasa_varlik(kod),
 saat timestamptz not null,
 fiyat numeric(22,6) not null check(fiyat>0),
 makro jsonb not null default '{}'::jsonb,
 primary key(kod,saat)
);
create table if not exists oyun.piyasa_pozisyon (
 user_id uuid not null references auth.users(id),
 kod text not null references oyun.piyasa_varlik(kod),
 miktar numeric(28,8) not null default 0 check(miktar>=0),
 maliyet numeric(20,2) not null default 0 check(maliyet>=0),
 primary key(user_id,kod)
);
create table if not exists oyun.piyasa_islem (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id),
 kod text not null references oyun.piyasa_varlik(kod),
 yon text not null check(yon in ('al','sat')),
 miktar numeric(28,8) not null check(miktar>0),
 fiyat numeric(22,6) not null check(fiyat>0),
 brut numeric(20,2) not null check(brut>=0),
 komisyon numeric(20,2) not null check(komisyon>=0),
 zaman timestamptz not null default now()
);
create index if not exists piyasa_islem_user_time on oyun.piyasa_islem(user_id,zaman desc);
create index if not exists piyasa_fiyat_saat on oyun.piyasa_fiyat(saat desc);
alter table oyun.piyasa_varlik enable row level security;
alter table oyun.piyasa_fiyat enable row level security;
alter table oyun.piyasa_pozisyon enable row level security;
alter table oyun.piyasa_islem enable row level security;
revoke all on oyun.piyasa_varlik,oyun.piyasa_fiyat,oyun.piyasa_pozisyon,oyun.piyasa_islem
 from public,anon,authenticated;
insert into oyun.piyasa_varlik(kod,ad,sinif,fiyat,onceki,oynaklik,saat) values
 ('USD','ABD Doları / TL','doviz',42,42,0.008,date_trunc('hour',now())),
 ('EUR','Avro / TL','doviz',49,49,0.008,date_trunc('hour',now())),
 ('ALTIN','Gram Altın / TL','altin',5200,5200,0.012,date_trunc('hour',now())),
 ('SANAYI','Sanayi Hisseleri','hisse',120,120,0.024,date_trunc('hour',now())),
 ('TEKNO','Teknoloji Hisseleri','hisse',180,180,0.032,date_trunc('hour',now())),
 ('BANKA','Banka Hisseleri','hisse',140,140,0.028,date_trunc('hour',now()))
on conflict (kod) do nothing;

create or replace function oyun.piyasa_guncelle()
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare
 r record; t timestamptz:=date_trunc('hour',now()); ts timestamptz;
 enfl numeric; buy numeric; iss numeric; haz numeric; borc numeric;
 risk numeric; deg numeric; sapma numeric; yeni numeric; i int;
begin
 perform pg_advisory_xact_lock(77890021);
 select coalesce(enflasyon,20),coalesce(buyume,2),coalesce(issizlik,10),coalesce(hazine,0)
 into enfl,buy,iss,haz from oyun.ulke where id=1;
 select coalesce(sum(anapara),0) into borc from oyun.borclar where kalan_gun>0;
 -- Pozitif risk: yüksek enflasyon/işsizlik/borç, düşük büyüme ve düşük hazine.
 risk:=greatest(-1,least(1, (enfl-20)/100 + (iss-10)/60 - buy/40
             +least(1,borc/1000)*0.2 - greatest(-0.3,least(0.3,haz/10000))*0.3));
 for r in select * from oyun.piyasa_varlik where aktif order by kod for update loop
   ts:=r.saat; i:=0;
   -- En fazla 168 saat geçmişi işlem; uzun kesintilerde ilk 168 saat boşluk atlanır.
   if ts<t-interval '168 hours' then ts:=t-interval '168 hours'; end if;
   while ts<t and i<168 loop
     ts:=ts+interval '1 hour'; i:=i+1;
     -- Her varlık için merkezî tek fiyat: hem pozitif hem negatif yön mümkün.
     sapma:=(random()*2-1)*r.oynaklik;
     deg:=case r.sinif
       when 'doviz' then risk*0.0018 + sapma
       when 'altin' then risk*0.0007 + sapma
       else -risk*0.003 + greatest(-0.004,least(0.004,buy/1000)) + sapma end;
     deg:=greatest(-r.oynaklik*1.2,least(r.oynaklik*1.2,deg));
     yeni:=greatest(0.000001,round(r.fiyat*(1+deg),6));
     insert into oyun.piyasa_fiyat(kod,saat,fiyat,makro)
     values(r.kod,ts,yeni,jsonb_build_object('enflasyon',enfl,'buyume',buy,'issizlik',iss,'hazine',haz,'borc',borc,'risk',risk))
     on conflict do nothing;
     update oyun.piyasa_varlik set onceki=r.fiyat,fiyat=yeni,saat=ts where kod=r.kod;
     r.fiyat:=yeni;
   end loop;
 end loop;
end $$;
revoke all on function oyun.piyasa_guncelle() from public,anon,authenticated;

create or replace function public.piyasa_durum()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 perform oyun.piyasa_guncelle();
 return jsonb_build_object('saat',date_trunc('hour',now()),
   'cuzdan',(select para from oyun.cuzdan where user_id=u),
   'varliklar',(select coalesce(jsonb_agg(jsonb_build_object(
     'kod',v.kod,'ad',v.ad,'sinif',v.sinif,'fiyat',v.fiyat,'onceki',v.onceki,
     'degisim',round((v.fiyat/v.onceki-1)*100,2),
     'miktar',coalesce(p.miktar,0),'maliyet',coalesce(p.maliyet,0),
     'deger',round(coalesce(p.miktar,0)*v.fiyat,2),
     'gecmis',coalesce((select jsonb_agg(z.fiyat order by z.saat)
        from (select saat,fiyat from oyun.piyasa_fiyat where kod=v.kod order by saat desc limit 24) z),'[]'::jsonb))
      order by v.kod),'[]'::jsonb)
    from oyun.piyasa_varlik v left join oyun.piyasa_pozisyon p
      on p.kod=v.kod and p.user_id=u where v.aktif),
   'islemler',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from
      (select id,kod,yon,miktar,fiyat,brut,komisyon,zaman
       from oyun.piyasa_islem where user_id=u order by id desc limit 12) x),
   'makro',(select jsonb_build_object('enflasyon',enflasyon,'buyume',buyume,
     'issizlik',issizlik,'hazine',hazine,'borc',(select coalesce(sum(anapara),0)
      from oyun.borclar where kalan_gun>0)) from oyun.ulke where id=1));
end $$;

-- p_tutar TL işlem büyüklüğüdür. Satış da TL tutarıyla yapılır; açığa satış ve borçlanma yok.
create or replace function public.piyasa_emir(p_kod text,p_yon text,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); v oyun.piyasa_varlik%rowtype;
 adet numeric(28,8); pos oyun.piyasa_pozisyon%rowtype;
 brut numeric; kom numeric; toplam numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 if p_yon not in ('al','sat') or p_yon is null then raise exception 'Geçersiz işlem türü'; end if;
 if p_tutar is null or p_tutar<100 or p_tutar>100000000 then raise exception 'Tutar 100 - 100.000.000 TL arasında olmalı.'; end if;
 if p_tutar<>trunc(p_tutar,0) then raise exception 'Tutar tam TL olmalı.'; end if;
 perform oyun.piyasa_guncelle();
 select * into v from oyun.piyasa_varlik where kod=p_kod and aktif for update;
 if not found then raise exception 'Varlık bulunamadı'; end if;
 insert into oyun.piyasa_pozisyon(user_id,kod) values(u,p_kod) on conflict do nothing;
 select * into pos from oyun.piyasa_pozisyon where user_id=u and kod=p_kod for update;
 if p_yon='al' then
   brut:=p_tutar;
   adet:=trunc(brut/v.fiyat,8);
   if adet<=0 then raise exception 'Bu tutarla alınabilecek miktar yok'; end if;
   kom:=greatest(1,round(brut*0.003));
   toplam:=brut+kom;
   perform oyun.para_islem(u,-toplam,'piyasa','Yatırım alımı: '||p_kod,now());
   update oyun.piyasa_pozisyon set miktar=miktar+adet,maliyet=maliyet+brut
     where user_id=u and kod=p_kod;
 else
   adet:=trunc(p_tutar/v.fiyat,8);
   if adet<=0 or pos.miktar<adet then raise exception 'Portföyünde bu satış için yeterli varlık yok.'; end if;
   brut:=round(adet*v.fiyat);
   if brut<100 then raise exception 'Satış en az 100 TL olmalı.'; end if;
   kom:=greatest(1,round(brut*0.003));
   toplam:=brut-kom;
   update oyun.piyasa_pozisyon set miktar=miktar-adet,
     maliyet=case when miktar-adet<0.00000001 then 0 else round(maliyet*(miktar-adet)/miktar,2) end
     where user_id=u and kod=p_kod;
   perform oyun.para_islem(u,toplam,'piyasa','Yatırım satışı: '||p_kod,now());
 end if;
 update oyun.ulke set hazine=hazine+kom/1000000.0 where id=1;
 insert into oyun.piyasa_islem(user_id,kod,yon,miktar,fiyat,brut,komisyon)
 values(u,p_kod,p_yon,adet,v.fiyat,brut,kom);
 return jsonb_build_object('yon',p_yon,'kod',p_kod,'miktar',adet,'fiyat',v.fiyat,
  'brut',brut,'komisyon',kom,'net',case when p_yon='al' then -toplam else toplam end);
end $$;
revoke all on function public.piyasa_durum() from public,anon;
revoke all on function public.piyasa_emir(text,text,numeric) from public,anon;
grant execute on function public.piyasa_durum() to authenticated;
grant execute on function public.piyasa_emir(text,text,numeric) to authenticated;
