-- 2026-10-13 | Is Dunyasi: mevcut oyuncu ve hesap verilerine dokunmadan ek ekonomi modulleri.
-- Butun mutasyonlar yetkili oyuncu tarafindan, tek DB islemi icinde yapilir.
create table if not exists oyun.eko_isletmeler(
 sirket_id bigint primary key references oyun.sirketler(id),
 tur text not null check(tur in ('fabrika','magaza','insaat','sigorta')),
 il_id smallint not null references oyun.iller(id),
 urun text check(urun in ('gida','teknoloji','malzeme')),
 uretim_fiyat numeric not null default 0 check(uretim_fiyat>=0),
 perakende_fiyat numeric not null default 0 check(perakende_fiyat>=0),
 olusturma timestamptz not null default now()
);
create table if not exists oyun.eko_stok(
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null check(urun in ('gida','teknoloji','malzeme')),
 adet integer not null default 0 check(adet>=0),
 primary key(sirket_id,urun)
);
create table if not exists oyun.eko_gunluk_satis(
 sirket_id bigint not null references oyun.sirketler(id),
 gun date not null,
 adet integer not null default 0 check(adet>=0),
 primary key(sirket_id,gun)
);
create table if not exists oyun.eko_projeler(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 il_id smallint not null references oyun.iller(id),
 tip text not null check(tip in ('daire','dukkan','villa')),
 toplam integer not null check(toplam between 1 and 8),
 kalan integer not null check(kalan>=0),
 maliyet numeric not null check(maliyet>0),
 birim_fiyat numeric not null check(birim_fiyat>0),
 hazir timestamptz not null,
 olusturma timestamptz not null default now()
);
create table if not exists oyun.eko_sozlesmeler(
 id bigint generated always as identity primary key,
 satici bigint not null references oyun.sirketler(id),
 alici bigint not null references oyun.sirketler(id),
 konu text not null,
 bedel numeric not null check(bedel>0),
 vade timestamptz not null,
 durum text not null default 'teklif'
   check(durum in ('teklif','aktif','teslim','tamam','iptal')),
 tarih timestamptz not null default now(),
 guncelleme timestamptz not null default now(),
 check(satici<>alici)
);
create table if not exists oyun.eko_markalar(
 sirket_id bigint primary key references oyun.sirketler(id),
 isim_hakki numeric not null check(isim_hakki>=1000),
 komisyon numeric not null check(komisyon between 1 and 15),
 guncelleme timestamptz not null default now()
);
create table if not exists oyun.eko_franchise(
 id bigint generated always as identity primary key,
 marka bigint not null references oyun.sirketler(id),
 sube bigint not null unique references oyun.sirketler(id),
 komisyon numeric not null check(komisyon between 1 and 15),
 isim_hakki numeric not null check(isim_hakki>0),
 tarih timestamptz not null default now(),
 check(marka<>sube)
);
create table if not exists oyun.eko_policeler(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 musteri uuid not null references auth.users(id),
 prim numeric not null check(prim>0),
 teminat numeric not null check(teminat>0),
 bas timestamptz not null default now(),
 bit timestamptz not null,
 durum text not null default 'aktif'
   check(durum in ('aktif','hasarsiz','hasar_odendi')),
 kontrol timestamptz,
 odenen numeric not null default 0 check(odenen>=0)
);
create table if not exists oyun.eko_islem_kayit(
 id bigint generated always as identity primary key,
 sirket_id bigint references oyun.sirketler(id),
 diger_sirket bigint references oyun.sirketler(id),
 oyuncu uuid references auth.users(id),
 tur text not null,
 tutar numeric not null default 0,
 aciklama text not null,
 zaman timestamptz not null default now()
);
create table if not exists oyun.eko_birlesme(
 id bigint generated always as identity primary key,
 alan bigint not null references oyun.sirketler(id),
 katilan bigint not null unique references oyun.sirketler(id),
 yonetici uuid not null references auth.users(id),
 aktaran numeric not null check(aktaran>=0),
 zaman timestamptz not null default now()
);
create index if not exists eko_projeler_sirket_idx on oyun.eko_projeler(sirket_id);
create index if not exists eko_sozlesmeler_taraf_idx on oyun.eko_sozlesmeler(satici,alici,durum);
create index if not exists eko_police_musteri_idx on oyun.eko_policeler(musteri,durum);
create index if not exists eko_islem_sirket_idx on oyun.eko_islem_kayit(sirket_id,zaman desc);
alter table oyun.eko_isletmeler enable row level security;
alter table oyun.eko_stok enable row level security;
alter table oyun.eko_gunluk_satis enable row level security;
alter table oyun.eko_projeler enable row level security;
alter table oyun.eko_sozlesmeler enable row level security;
alter table oyun.eko_markalar enable row level security;
alter table oyun.eko_franchise enable row level security;
alter table oyun.eko_policeler enable row level security;
alter table oyun.eko_islem_kayit enable row level security;
alter table oyun.eko_birlesme enable row level security;
revoke all on oyun.eko_isletmeler,oyun.eko_stok,oyun.eko_gunluk_satis,oyun.eko_projeler,oyun.eko_sozlesmeler,oyun.eko_markalar,oyun.eko_franchise,oyun.eko_policeler,oyun.eko_islem_kayit,oyun.eko_birlesme from public,anon,authenticated;

-- Public RPC is read-only, security definer grants no table-level write permission.
create or replace function public.eko_panel()
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris yapmalisin.';end if;
 return jsonb_build_object(
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad))
 from oyun.sirketler s where s.aktif and s.sektor<>'banka'),'[]'::jsonb),
 'benim',coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'ad',s.ad,'sektor',s.sektor,'tur',i.tur,'il',i.il_id,
    'urun',i.urun,'pay',o.pay,'kasa',s.kasa,'sermaye',s.sermaye,
    'stok',coalesce((select sum(st.adet) from oyun.eko_stok st where st.sirket_id=s.id),0),
    'uretim_fiyat',i.uretim_fiyat,'perakende_fiyat',i.perakende_fiyat))
  from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id and o.user_id=u
  left join oyun.eko_isletmeler i on i.sirket_id=s.id where s.aktif),'[]'::jsonb),
 'fabrikalar',coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'ad',s.ad,'urun',i.urun,'fiyat',i.uretim_fiyat,'stok',
    coalesce((select st.adet from oyun.eko_stok st where st.sirket_id=s.id and st.urun=i.urun),0)))
  from oyun.eko_isletmeler i join oyun.sirketler s on s.id=i.sirket_id
  where i.tur='fabrika' and s.aktif),'[]'::jsonb),
 'markalar',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'bedel',m.isim_hakki,'oran',m.komisyon))
  from oyun.eko_markalar m join oyun.sirketler s on s.id=m.sirket_id where s.aktif),'[]'::jsonb),
 'subeler',coalesce((select jsonb_agg(jsonb_build_object('sube',f.sube,'marka',s.ad,'oran',f.komisyon))
 from oyun.eko_franchise f join oyun.sirketler s on s.id=f.marka
 where f.sube in (select sirket_id from oyun.sirket_ortaklari where user_id=u)),'[]'::jsonb),
 'projeler',coalesce((select jsonb_agg(jsonb_build_object(
    'id',p.id,'sirket',s.ad,'sirket_id',s.id,'il',p.il_id,'tip',p.tip,'kalan',p.kalan,
    'birim_fiyat',p.birim_fiyat,'hazir',p.hazir))
  from oyun.eko_projeler p join oyun.sirketler s on s.id=p.sirket_id
  where p.kalan>0 and s.aktif),'[]'::jsonb),
 'sozlesmeler',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'satici',sa.ad,'alici',al.ad,
   'satici_id',sa.id,'alici_id',al.id,'konu',c.konu,'bedel',c.bedel,'durum',c.durum,'vade',c.vade))
 from oyun.eko_sozlesmeler c join oyun.sirketler sa on sa.id=c.satici join oyun.sirketler al on al.id=c.alici
 where (c.satici in (select sirket_id from oyun.sirket_ortaklari where user_id=u)
 or c.alici in (select sirket_id from oyun.sirket_ortaklari where user_id=u))
 and c.durum not in ('tamam','iptal')),'[]'::jsonb),
 'policeler',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'sirket',s.ad,
  'teminat',p.teminat,'prim',p.prim,'durum',p.durum,'bit',p.bit,'kontrol',p.kontrol))
 from oyun.eko_policeler p join oyun.sirketler s on s.id=p.sirket_id where p.musteri=u),'[]'::jsonb),
 'sigortalar',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa))
 from oyun.eko_isletmeler i join oyun.sirketler s on s.id=i.sirket_id where i.tur='sigorta' and s.aktif),'[]'::jsonb)
 );
end $fn$;

create or replace function public.eko_islem(p_eylem text,p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=auth.uid();t timestamptz:=oyun.simdi();
 a bigint:=nullif(p_veri->>'sirket','')::bigint;
 b bigint:=nullif(p_veri->>'hedef','')::bigint;
 n integer:=coalesce(nullif(p_veri->>'adet','')::integer,0);
 v numeric:=coalesce(nullif(p_veri->>'tutar','')::numeric,0);
 x numeric;y numeric; z numeric; k numeric;
 yeni bigint; tur text; ur text; tip text; il smallint;
 sa oyun.sirketler; sb oyun.sirketler; ia oyun.eko_isletmeler; ib oyun.eko_isletmeler;
 pr oyun.eko_projeler; c oyun.eko_sozlesmeler; po oyun.eko_policeler;
 f oyun.eko_franchise; m oyun.eko_markalar;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris yapmalisin.';end if;
 if p_veri is null or jsonb_typeof(p_veri)<>'object' then raise exception 'Gecersiz islem.';end if;
 if p_eylem='etkinlestir' then
   tur:=p_veri->>'tur';ur:=p_veri->>'urun'; 
   if a is null or tur not in ('fabrika','magaza','insaat','sigorta') then raise exception 'Sektor veya sirket gerekli.';end if;
   select * into sa from oyun.sirketler where id=a for update;
   if sa.id is null or not sa.aktif or sa.halka_acik or sa.sektor='banka'
       or coalesce((select pay from oyun.sirket_ortaklari where sirket_id=a and user_id=u),0)<>100
       or exists(select 1 from oyun.eko_isletmeler where sirket_id=a)
       then raise exception 'Yalnizca %%100 sahibi oldugun, halka acik olmayan, eski bir sirketi etkinlestirebilirsin.';end if;
   if (tur='fabrika' and (sa.sektor not in ('sanayi','teknoloji','tarim') or ur not in ('gida','teknoloji','malzeme')))
   or (tur='magaza' and sa.sektor<>'ticaret')
   or (tur='insaat' and sa.sektor<>'insaat')
   or (tur='sigorta' and sa.sektor<>'ticaret')
   then raise exception 'Bu sirket sektoru secilen isletmeye donusturulemez.';end if;
   il:=coalesce((select il_id from oyun.profiller where id=u),1);
   insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat)
     values(a,tur,il,case when tur='fabrika' then ur else null end,
     case ur when 'gida' then 6000 when 'teknoloji' then 18000 when 'malzeme' then 10000 else 0 end,9500);
   return jsonb_build_object('id',a,'aktiflestirildi',true);
 end if;
 if p_eylem='kur' then
   tur:=p_veri->>'tur';il:=(p_veri->>'il')::smallint;ur:=p_veri->>'urun';
   if tur not in ('fabrika','magaza','insaat','sigorta') or not exists(select 1 from oyun.iller where id=il)
      or (tur='fabrika' and ur not in ('gida','teknoloji','malzeme'))
      or v<>round(v) or v<100000 or v>100000000 then raise exception 'Tur, il veya sermaye gecersiz.';end if;
   select (public.sirket_kur(p_veri->>'ad',case tur when 'fabrika' then 'sanayi' when 'insaat' then 'insaat' else 'ticaret' end,v)->>'id')::bigint into yeni;
   insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat)
   values(yeni,tur,il,case when tur='fabrika' then ur else null end,
   case ur when 'gida' then 6000 when 'teknoloji' then 18000 when 'malzeme' then 10000 else 0 end,9500);
   return jsonb_build_object('id',yeni);
 end if;
 -- Kilit, hak kontrolu ve kasa bakiyesi sorgusu birlikte yapilir.
 if a is not null then
  select * into sa from oyun.sirketler where id=a for update;
  select * into ia from oyun.eko_isletmeler where sirket_id=a;
 end if;
 if p_eylem in ('uretim','fiyat','toptan','satis','proje','sozlesme_teklif','marka_ac','franchise_al','birles') then
   if sa.id is null or not sa.aktif or not oyun.sirket_yonetici_mi(a,u) then raise exception 'Bu sirketi yonetme yetkin yok.';end if;
 end if;
 if p_eylem='uretim' then
   if ia.tur<>'fabrika' or n not between 1 and 250 then raise exception 'Uretim adedi 1-250 olmali.';end if;
   k:=case ia.urun when 'gida' then 4000 when 'teknoloji' then 12000 else 6500 end * n;
   update oyun.sirketler set kasa=kasa-k where id=a and kasa>=k;
   if not found then raise exception 'Uretim icin sirket kasasinda yeterli para yok.';end if;
   insert into oyun.eko_stok(sirket_id,urun,adet) values(a,ia.urun,n)
   on conflict(sirket_id,urun) do update set adet=oyun.eko_stok.adet+excluded.adet;
   insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
    values(a,u,'uretim',-k,format('%s adet %s uretimi',n,ia.urun));
   return jsonb_build_object('uretilen',n,'maliyet',k);
 elsif p_eylem='fiyat' then
   if v<>round(v) then raise exception 'Fiyat tam TL olmali.';end if;
   if ia.tur='fabrika' then
     k:=case ia.urun when 'gida' then 4000 when 'teknoloji' then 12000 else 6500 end;
     if v<k or v>k*2 then raise exception 'Toptan fiyat maliyet ile iki kati arasinda olmali.';end if;
     update oyun.eko_isletmeler set uretim_fiyat=v where sirket_id=a;
   elsif ia.tur='magaza' then
     if v<1000 or v>50000 then raise exception 'Satis fiyati 1.000-50.000 TL arasinda olmali.';end if;
     update oyun.eko_isletmeler set perakende_fiyat=v where sirket_id=a;
   else raise exception 'Bu isletmenin urun fiyati bulunmuyor.';end if;
   return jsonb_build_object('fiyat',v);
 elsif p_eylem='toptan' then
   if ia.tur<>'magaza' or n not between 1 and 250 or b is null or b=a then raise exception 'Magaza, fabrika ve adet sec.';end if;
   select * into sb from oyun.sirketler where id=b for update;
   select * into ib from oyun.eko_isletmeler where sirket_id=b;
   if not sb.aktif or ib.tur<>'fabrika' then raise exception 'Gecerli fabrika sec.';end if;
   x:=ib.uretim_fiyat*n;
   update oyun.eko_stok set adet=adet-n where sirket_id=b and urun=ib.urun and adet>=n;
   if not found then raise exception 'Fabrika stogu yetersiz.';end if;
   update oyun.sirketler set kasa=kasa-x where id=a and kasa>=x;
   if not found then raise exception 'Magaza kasasi yetersiz.';end if;
   update oyun.sirketler set kasa=kasa+x where id=b;
   insert into oyun.eko_stok(sirket_id,urun,adet) values(a,ib.urun,n)
     on conflict(sirket_id,urun) do update set adet=oyun.eko_stok.adet+excluded.adet;
   insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama)
    values(a,b,u,'toptan',-x,format('%s adet %s alimi',n,ib.urun));
   return jsonb_build_object('alindi',n,'tutar',x);
 elsif p_eylem='satis' then
   if ia.tur<>'magaza' or n not between 1 and 100 or (p_veri->>'urun') not in ('gida','teknoloji','malzeme') then raise exception 'Magaza, urun ve miktar sec.';end if;
   ur:=p_veri->>'urun';
   insert into oyun.eko_gunluk_satis(sirket_id,gun,adet) values(a,(t at time zone 'Europe/Istanbul')::date,0)
      on conflict do nothing;
   -- 24 saatte sinirli sanal musteri talebi; franchise magazalarinin pazari daha genis.
   k:=case when exists(select 1 from oyun.eko_franchise where sube=a) then 60 else 45 end;
   update oyun.eko_gunluk_satis set adet=adet+n where sirket_id=a
     and gun=(t at time zone 'Europe/Istanbul')::date and adet+n<=k;
   if not found then raise exception 'Bugunluk sanal musteri talebi doldu.';end if;
   update oyun.eko_stok set adet=adet-n where sirket_id=a and urun=ur and adet>=n;
   if not found then raise exception 'Stok yetersiz.';end if;
   x:=ia.perakende_fiyat*n;z:=0;
   select * into f from oyun.eko_franchise where sube=a;
   if f.id is not null then z:=round(x*f.komisyon/100);end if;
   update oyun.sirketler set kasa=kasa+x-z where id=a;
   if f.id is not null then update oyun.sirketler set kasa=kasa+z where id=f.marka;end if;
   insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama)
    values(a,f.marka,u,'perakende',x-z,format('%s adet %s sanal musteri satisi',n,ur));
   return jsonb_build_object('ciro',x,'franchise_payi',z,'net',x-z);
 elsif p_eylem='proje' then
   if ia.tur<>'insaat' or n not between 1 and 8 then raise exception 'Insaat sirketi ve 1-8 konut sec.';end if;
   tip:=p_veri->>'tip';il:=ia.il_id;
   if tip not in ('daire','dukkan','villa') then raise exception 'Proje turu gecersiz.';end if;
   x:=round(oyun.mulk_il_bedel(il,tip)*.74)*n;
   y:=round(oyun.mulk_il_bedel(il,tip)*1.05);
   update oyun.sirketler set kasa=kasa-x where id=a and kasa>=x;
   if not found then raise exception 'Insaat maliyeti icin sirket kasasi yetersiz.';end if;
   insert into oyun.eko_projeler(sirket_id,il_id,tip,toplam,kalan,maliyet,birim_fiyat,hazir)
     values(a,il,tip,n,n,x,y,t+interval '24 hours') returning id into yeni;
   insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
     values(a,u,'insaat',-x,format('%s adet %s projesi',n,tip));
   return jsonb_build_object('id',yeni,'maliyet',x,'hazir',t+interval '24 hours');
 elsif p_eylem='konut_al' then
   select * into pr from oyun.eko_projeler where id=(p_veri->>'proje')::bigint for update;
   if pr.id is null or pr.kalan<=0 or pr.hazir>t then raise exception 'Proje hazir degil veya stok bitti.';end if;
   perform pg_advisory_xact_lock(90181,pr.il_id::integer);
   if (select count(*) from oyun.yatirim_mulkleri where il_id=pr.il_id and tip=pr.tip)>=oyun.mulk_il_kota(pr.il_id,pr.tip)
     then raise exception 'Bu ilde ilgili gayrimenkul kotasi doldu.';end if;
   x:=round(pr.birim_fiyat*.02); -- Alici tapu harci.
   perform oyun.para_islem(u,-pr.birim_fiyat-x,'emlak','Müteahhitten yeni konut + %2 tapu harci',t,x);
   update oyun.sirketler set kasa=kasa+pr.birim_fiyat-x where id=pr.sirket_id and aktif;
   if not found then raise exception 'Muteahhit sirket faal degil.';end if;
   update oyun.ulke set hazine=hazine+(x*2)/1000000.0 where id=1;
   insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,vergi_sonraki)
    values(u,pr.il_id,pr.tip,pr.birim_fiyat,oyun.mulk_il_kira(pr.il_id,pr.tip),t,t+interval '7 days',oyun.mulk_vergi_ilk_vade(t));
   update oyun.eko_projeler set kalan=kalan-1 where id=pr.id;
   insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
     values(pr.sirket_id,u,'konut_satis',pr.birim_fiyat-x,format('%s ilinde %s satisi',pr.il_id,pr.tip));
   return jsonb_build_object('satildi',true,'bedel',pr.birim_fiyat,'tapu_harci',x*2);
 elsif p_eylem='sozlesme_teklif' then
   if b=a or b is null or v<>round(v) or v<1000 or v>10000000
      or length(btrim(coalesce(p_veri->>'konu',''))) not between 6 and 140
      then raise exception 'Alici, konu veya tutar gecersiz.';end if;
   if not exists(select 1 from oyun.sirketler where id=b and aktif) then raise exception 'Alici sirket yok.';end if;
   insert into oyun.eko_sozlesmeler(satici,alici,konu,bedel,vade)
     values(a,b,btrim(p_veri->>'konu'),v,t+interval '3 days') returning id into yeni;
   return jsonb_build_object('id',yeni,'durum','teklif');
 elsif p_eylem in ('sozlesme_kabul','sozlesme_teslim','sozlesme_onay','sozlesme_iptal') then
   select * into c from oyun.eko_sozlesmeler where id=(p_veri->>'id')::bigint for update;
   if c.id is null then raise exception 'Sozlesme bulunamadi.';end if;
   if p_eylem='sozlesme_kabul' then
     if c.durum<>'teklif' or t>c.vade or not oyun.sirket_yonetici_mi(c.alici,u) then raise exception 'Onay hakkin yok.';end if;
     update oyun.sirketler set kasa=kasa-c.bedel where id=c.alici and aktif and kasa>=c.bedel;
     if not found then raise exception 'Alici sirket kasasi yetersiz.';end if;
     update oyun.eko_sozlesmeler set durum='aktif',guncelleme=t where id=c.id;
   elsif p_eylem='sozlesme_teslim' then
     if c.durum<>'aktif' or t>c.vade or not oyun.sirket_yonetici_mi(c.satici,u) then raise exception 'Teslim hakkin veya suren yok.';end if;
     update oyun.eko_sozlesmeler set durum='teslim',guncelleme=t where id=c.id;
   elsif p_eylem='sozlesme_onay' then
     if c.durum<>'teslim' or not oyun.sirket_yonetici_mi(c.alici,u) then raise exception 'Teslim alici tarafindan onaylanmali.';end if;
     update oyun.sirketler set kasa=kasa+c.bedel where id=c.satici;
     update oyun.eko_sozlesmeler set durum='tamam',guncelleme=t where id=c.id;
     insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama)
      values(c.satici,c.alici,u,'sozlesme',c.bedel,c.konu);
   else
     if c.durum='teklif' and oyun.sirket_yonetici_mi(c.satici,u) then
       update oyun.eko_sozlesmeler set durum='iptal',guncelleme=t where id=c.id;
     elsif c.durum='aktif' and t>c.vade and oyun.sirket_yonetici_mi(c.alici,u) then
       update oyun.sirketler set kasa=kasa+c.bedel where id=c.alici;
       update oyun.eko_sozlesmeler set durum='iptal',guncelleme=t where id=c.id;
     else raise exception 'Sozlesme bu asamada iptal edilemez.';end if;
   end if;
   return jsonb_build_object('id',c.id,'tamam',true);
 elsif p_eylem='marka_ac' then
   if ia.tur<>'magaza' or v<>round(v) or v<1000 or v>1000000 or n not between 1 and 15 then raise exception 'Magaza, isim hakki ve ciro payi sec.';end if;
   insert into oyun.eko_markalar(sirket_id,isim_hakki,komisyon)
     values(a,v,n) on conflict(sirket_id) do update set isim_hakki=excluded.isim_hakki,komisyon=excluded.komisyon,guncelleme=t;
   return jsonb_build_object('tamam',true);
 elsif p_eylem='franchise_al' then
   if ia.tur<>'magaza' or a=b or b is null then raise exception 'Sube veya marka gecersiz.';end if;
   select * into m from oyun.eko_markalar where sirket_id=b;
   if m.sirket_id is null or not exists(select 1 from oyun.sirketler where id=b and aktif) then raise exception 'Marka kullanilabilir degil.';end if;
   if exists(select 1 from oyun.eko_franchise where sube=a) then raise exception 'Subenin zaten bir markasi var.';end if;
   update oyun.sirketler set kasa=kasa-m.isim_hakki where id=a and kasa>=m.isim_hakki;
   if not found then raise exception 'Isim hakki icin sirket kasasi yetersiz.';end if;
   update oyun.sirketler set kasa=kasa+m.isim_hakki where id=b;
   insert into oyun.eko_franchise(marka,sube,komisyon,isim_hakki) values(b,a,m.komisyon,m.isim_hakki);
   insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama)
    values(a,b,u,'franchise',-m.isim_hakki,'Marka isim hakki');
   return jsonb_build_object('tamam',true);
 elsif p_eylem='police_al' then
   if v<>round(v) or v<5000 or v>500000 or b is null then raise exception 'Teminat 5.000-500.000 TL arasi olmali.';end if;
   select * into sb from oyun.sirketler where id=b for update;
   select * into ib from oyun.eko_isletmeler where sirket_id=b;
   if ib.tur<>'sigorta' or not sb.aktif or oyun.sirket_yonetici_mi(b,u) then raise exception 'Kendi sigorta sirketinden police alamazsin.';end if;
   if exists(select 1 from oyun.eko_policeler where musteri=u and durum='aktif' and bit>t) then raise exception 'Zaten aktif policen var.';end if;
   x:=round(v*.12);
   if sb.kasa < v*2 then raise exception 'Sigorta sirketinin odeme rezervi yetersiz.';end if;
   perform oyun.para_islem(u,-x,'sigorta','Sigorta police primi',t);
   update oyun.sirketler set kasa=kasa+x where id=b;
   insert into oyun.eko_policeler(sirket_id,musteri,prim,teminat,bit)
     values(b,u,x,v,t+interval '3 days') returning id into yeni;
   return jsonb_build_object('id',yeni,'prim',x,'teminat',v);
 elsif p_eylem='police_kontrol' then
   select * into po from oyun.eko_policeler where id=(p_veri->>'id')::bigint for update;
   if po.id is null or po.musteri<>u or po.durum<>'aktif' or po.bas+interval '48 hours'>t then raise exception 'Police henuz kontrol edilemez.';end if;
   -- Hasar cekilisi bir kez yapilir, istemci hasar sonucunu belirleyemez.
   if random()<.08 and exists(select 1 from oyun.sirketler where id=po.sirket_id and kasa>=po.teminat) then
     update oyun.sirketler set kasa=kasa-po.teminat where id=po.sirket_id and kasa>=po.teminat;
     if not found then raise exception 'Sigorta sirketi tazminati odeyemiyor.';end if;
     perform oyun.para_islem(u,po.teminat,'sigorta','Sigorta hasar tazminati',t);
     update oyun.eko_policeler set durum='hasar_odendi',odenen=po.teminat,kontrol=t where id=po.id;
     return jsonb_build_object('durum','hasar_odendi','tutar',po.teminat);
   end if;
   update oyun.eko_policeler set durum='hasarsiz',kontrol=t where id=po.id;
   return jsonb_build_object('durum','hasarsiz','tutar',0);
 elsif p_eylem='birles' then
   if b is null or a=b then raise exception 'Iki farkli sirket sec.';end if;
   select * into sb from oyun.sirketler where id=b for update;
   if sb.id is null or not sb.aktif or not sa.aktif or sa.sektor='banka' or sb.sektor='banka'
   or sa.halka_acik or sb.halka_acik then raise exception 'Banka veya halka acik sirketler bu islemle birlesemez.';end if;
   if coalesce((select pay from oyun.sirket_ortaklari where sirket_id=a and user_id=u),0)<>100
     or coalesce((select pay from oyun.sirket_ortaklari where sirket_id=b and user_id=u),0)<>100
     or exists(select 1 from oyun.eko_isletmeler where sirket_id=b)
     or exists(select 1 from oyun.sirket_teklif where sirket_id=b and durum='bekliyor')
     or exists(select 1 from oyun.sirket_hisse_ilanlari where sirket_id=b and durum='acik')
     or sb.satilik is not null
     or exists(select 1 from oyun.halka_arz where sirket_id=b and durum='acik')
     or exists(select 1 from oyun.eko_sozlesmeler where (satici=b or alici=b) and durum in ('teklif','aktif','teslim'))
     or exists(select 1 from oyun.eko_policeler where sirket_id=b and durum='aktif')
     or exists(select 1 from oyun.eko_franchise where marka=b or sube=b)
     or exists(select 1 from oyun.eko_markalar where sirket_id=b)
     or exists(select 1 from oyun.eko_projeler where sirket_id=b and kalan>0)
     or exists(select 1 from oyun.kamu_ihale where kazanan=b and durum not in ('tamam','iptal','bitti','teslim'))
     then raise exception 'Birlesme icin iki sirket de %%100 sana ait olmali ve devrolan sirkette aktif taahhut bulunmamali.';end if;
   update oyun.sirketler set kasa=kasa+sb.kasa,sermaye=sermaye+sb.sermaye where id=a;
   update oyun.sirketler set kasa=0,aktif=false,satilik=null where id=b;
   insert into oyun.eko_birlesme(alan,katilan,yonetici,aktaran) values(a,b,u,sb.kasa);
   insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama)
     values(a,b,u,'birlesme',sb.kasa,'Tam sahipli sirket devir yoluyla birlesti');
   return jsonb_build_object('tamam',true,'aktarilan',sb.kasa);
 else raise exception 'Taninmayan ekonomi islemi.';end if;
end $fn$;
revoke all on function public.eko_panel() from public,anon;
revoke all on function public.eko_islem(text,jsonb) from public,anon;
grant execute on function public.eko_panel() to authenticated;
grant execute on function public.eko_islem(text,jsonb) to authenticated;

-- Yeni ticari isletmelerin ayni zamanda eski haftalik otomatik getiriyi almasini engelle.
CREATE OR REPLACE FUNCTION oyun.sirket_hesapla(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;distributable numeric;v_odeme numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 -- Yeni Is Dunyasi isletmeleri yalniz stok/satis/sozlesme gelirlerinden kazanir.
 if exists(select 1 from oyun.eko_isletmeler where sirket_id=p_id) then
  update oyun.sirketler set sonraki_kazanc=greatest(sonraki_kazanc,t)+interval '7 days',son_islem=t where id=p_id;
  return;
 end if;
 if exists(select 1 from oyun.pazar_sektor where kod=s.sektor) then perform oyun.pazar_hesapla(p_id); return; end if;
 if s.sektor='ajans' then perform oyun.ajans_hesapla(p_id); return; end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()::numeric*.8),2);
  cost:=round(s.sermaye*(.025+random()::numeric*.055)+w*(.5+random()::numeric),2);
  income:=round(income * oyun.kriz_sektor_carpani(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days')
                       * oyun.sektor_pol_carpan(s.sektor,s.sonraki_kazanc + (i-1) * interval '7 days'),2); net:=income-cost;
  distributed:=0;
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributable:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    if not x.kar_kasada then
      v_odeme:=least(round(distributable*x.pay/100,2),greatest(0,distributable-distributed));
      if v_odeme>0 then
        perform oyun.para_islem(x.user_id,v_odeme,'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
        distributed:=distributed+v_odeme;
      end if;
    end if;
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$;
