
create table if not exists oyun.uc_ciftlik(
 sirket_id bigint primary key references oyun.sirketler(id),
 tarla int not null default 0 check(tarla between 0 and 30),
 hayvan int not null default 0 check(hayvan between 0 and 80),
 son_sut timestamptz
);
create table if not exists oyun.uc_ekimler(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null check(urun in ('uc_bugday','uc_sebze')),
 tarla int not null check(tarla between 1 and 30),
 ekim timestamptz not null,hazir timestamptz not null,verim numeric not null,
 maliyet numeric not null,hasat timestamptz
);
create index if not exists uc_ekimler_aktif on oyun.uc_ekimler(sirket_id,hazir) where hasat is null;
revoke all on oyun.uc_ciftlik,oyun.uc_ekimler from public,anon,authenticated;
alter table oyun.uc_ciftlik enable row level security;
alter table oyun.uc_ekimler enable row level security;
insert into oyun.eko_urun_katalog(kod,ad,grup,kullanim,maliyet,parti_ust,uretim_dakika,onerilen_satis,talep,aktif)
values ('uc_bugday','Çiftlik buğdayı','gida','market',80,200,120,160,12,true),
('uc_sebze','Taze sebze','gida','market',55,200,120,120,15,true),
('uc_sut','Çiftlik sütü','gida','market',75,180,120,180,13,true),
('uc_et','Çiftlik eti','gida','market',350,90,180,780,10,true)
on conflict (kod) do update set aktif=true,ad=excluded.ad,kullanim='market',onerilen_satis=excluded.onerilen_satis,talep=excluded.talep;
create or replace function oyun.uc_stok_ek(p_sirket bigint,p_urun text,p_adet int,p_maliyet numeric)
returns void language plpgsql security definer set search_path to '' as $$
declare v_fiyat numeric;
begin
 if p_adet<=0 or p_adet>5000 then raise exception 'Stok miktarı geçersiz';end if;
 select greatest(round(p_maliyet*1.4),round(onerilen_satis*.72)) into v_fiyat
 from oyun.eko_urun_katalog where kod=p_urun and aktif;
 if v_fiyat is null then raise exception 'Ürün katalogda bulunamadı';end if;
 insert into oyun.eko_urun_stok(sirket_id,urun,adet,maliyet_birim,satis_fiyati)
 values(p_sirket,p_urun,p_adet,round(p_maliyet,2),v_fiyat)
 on conflict(sirket_id,urun) do update set
 maliyet_birim=round((oyun.eko_urun_stok.maliyet_birim*oyun.eko_urun_stok.adet+
 excluded.maliyet_birim*excluded.adet)/(oyun.eko_urun_stok.adet+excluded.adet),2),
 adet=oyun.eko_urun_stok.adet+excluded.adet,guncelleme=oyun.simdi();
end $$;
revoke all on function oyun.uc_stok_ek(bigint,text,integer,numeric) from public,anon,authenticated;
create or replace function public.uc_tarim_panel() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid();
begin
 perform oyun.profilim();
 return jsonb_build_object(
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,
 'il',e.il_id,'tarla',coalesce(c.tarla,0),'hayvan',coalesce(c.hayvan,0),'son_sut',c.son_sut))
 from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id
 join oyun.eko_isletmeler e on e.sirket_id=s.id and e.tur='fabrika' and e.urun='gida'
 left join oyun.uc_ciftlik c on c.sirket_id=s.id
 where s.aktif and s.sektor='tarim' and o.user_id=u and o.pay>=50),'[]'::jsonb),
 'ekimler',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'sirket',x.sirket_id,
 'urun',x.urun,'tarla',x.tarla,'hazir',x.hazir,'verim',x.verim))
 from oyun.uc_ekimler x join oyun.sirket_ortaklari o on o.sirket_id=x.sirket_id
 where o.user_id=u and x.hasat is null),'[]'::jsonb),
 'stok',coalesce((select jsonb_agg(jsonb_build_object('urun',st.urun,'sirket',st.sirket_id,
 'adet',st.adet,'fiyat',st.satis_fiyati))
 from oyun.eko_urun_stok st join oyun.sirket_ortaklari o on o.sirket_id=st.sirket_id
 where o.user_id=u and st.urun like 'uc_%' and st.adet>0),'[]'::jsonb));
end $$;
revoke all on function public.uc_tarim_panel() from public,anon;
grant execute on function public.uc_tarim_panel() to authenticated;
create or replace function public.uc_tarim_islem(p_islem text,p_sirket bigint,p_adet int default 1,p_urun text default null,p_ekim bigint default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); s oyun.sirketler;
 f oyun.uc_ciftlik; x oyun.uc_ekimler; n int; v int; cost numeric; factor numeric; il int; mn int;
begin
 perform oyun.profilim();
 select * into s from oyun.sirketler where id=p_sirket and aktif and sektor='tarim' for update;
 if s.id is null or not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50)
 or not exists(select 1 from oyun.eko_isletmeler e where e.sirket_id=s.id and e.tur='fabrika' and e.urun='gida')
 then raise exception 'Yönetebildiğin gıda üreticisi tarım şirketi gerekli';end if;
 insert into oyun.uc_ciftlik(sirket_id) values(s.id) on conflict do nothing;
 select * into f from oyun.uc_ciftlik where sirket_id=s.id for update;
 if p_islem='tarla_al' then
  if p_adet not between 1 and 10 or f.tarla+p_adet>30 then raise exception 'Tarla limiti 30';end if;
  cost:=p_adet*30000;
  update oyun.sirketler set kasa=kasa-cost where id=s.id and kasa>=cost;
  if not found then raise exception 'Şirket kasası yetersiz';end if;
  update oyun.uc_ciftlik set tarla=tarla+p_adet where sirket_id=s.id;
  return jsonb_build_object('tarla',f.tarla+p_adet,'gider',cost);
 elsif p_islem='hayvan_al' then
  if p_adet not between 1 and 20 or f.hayvan+p_adet>80 then raise exception 'Hayvan limiti 80';end if;
  cost:=p_adet*12000;
  update oyun.sirketler set kasa=kasa-cost where id=s.id and kasa>=cost;
  if not found then raise exception 'Şirket kasası yetersiz';end if;
  update oyun.uc_ciftlik set hayvan=hayvan+p_adet where sirket_id=s.id;
  return jsonb_build_object('hayvan',f.hayvan+p_adet,'gider',cost);
 elsif p_islem='ek' then
  if p_adet not between 1 and 10 or p_urun not in ('uc_bugday','uc_sebze')
  then raise exception 'Geçersiz ürün veya tarla sayısı';end if;
  select coalesce(sum(tarla),0) into n from oyun.uc_ekimler where sirket_id=s.id and hasat is null;
  if f.tarla-n<p_adet then raise exception 'Boş tarla yetersiz';end if;
  cost:=p_adet*case when p_urun='uc_bugday' then 2600 else 3500 end;
  update oyun.sirketler set kasa=kasa-cost where id=s.id and kasa>=cost;
  if not found then raise exception 'Ekim gideri için kasa yetersiz';end if;
  select il_id into il from oyun.eko_isletmeler where sirket_id=s.id;
  mn:=extract(month from t)::int;
  factor:=case when mn in (12,1,2) then .65 when mn in (6,7,8) then 1.2 else 1 end;
  if (il*13+mn*17+extract(year from t)::int)%11 in (0,1) then factor:=factor*.62;end if;
  insert into oyun.uc_ekimler(sirket_id,urun,tarla,ekim,hazir,verim,maliyet)
  values(s.id,p_urun,p_adet,t,t+make_interval(hours=>case when p_urun='uc_bugday' then 24 else 18 end),factor,cost)
  returning id into v;
  return jsonb_build_object('ekim',v,'verim',factor,'gider',cost,'mesaj','Mevsim ve yerel kuraklık etkisi ekime işlendi');
 elsif p_islem='hasat' then
  select * into x from oyun.uc_ekimler where id=p_ekim and sirket_id=s.id for update;
  if x.id is null or x.hasat is not null or x.hazir>t then raise exception 'Ekim henüz hazır değil';end if;
  n:=greatest(1,round(x.tarla*(case when x.urun='uc_bugday' then 65 else 45 end)*x.verim)::int);
  update oyun.uc_ekimler set hasat=t where id=x.id and hasat is null;
  perform oyun.uc_stok_ek(s.id,x.urun,n,x.maliyet/n);
  return jsonb_build_object('urun',x.urun,'adet',n,'mesaj','Ürün mevcut market tedarik sistemine aktarıldı');
 elsif p_islem='sut' then
  if f.hayvan<1 or (f.son_sut is not null and f.son_sut>t-interval '16 hours')
  then raise exception 'Sağım için hayvan ve 16 saat bekleme gerekiyor';end if;
  cost:=f.hayvan*110;
  update oyun.sirketler set kasa=kasa-cost where id=s.id and kasa>=cost;
  if not found then raise exception 'Yem gideri karşılanamadı';end if;
  update oyun.uc_ciftlik set son_sut=t where sirket_id=s.id;
  n:=f.hayvan*3;
  perform oyun.uc_stok_ek(s.id,'uc_sut',n,cost/n);
  return jsonb_build_object('urun','uc_sut','adet',n,'gider',cost);
 elsif p_islem='kesim' then
  if p_adet not between 1 and 20 or p_adet>f.hayvan then raise exception 'Hayvan sayısı yetersiz';end if;
  cost:=p_adet*800;
  update oyun.sirketler set kasa=kasa-cost where id=s.id and kasa>=cost;
  if not found then raise exception 'Kesim gideri karşılanamadı';end if;
  update oyun.uc_ciftlik set hayvan=hayvan-p_adet where sirket_id=s.id;
  n:=p_adet*30;
  perform oyun.uc_stok_ek(s.id,'uc_et',n,(p_adet*12000+cost)/n);
  return jsonb_build_object('urun','uc_et','adet',n);
 end if;
 raise exception 'Bilinmeyen tarım işlemi';
end $$;
revoke all on function public.uc_tarim_islem(text,bigint,integer,text,bigint) from public,anon;
grant execute on function public.uc_tarim_islem(text,bigint,integer,text,bigint) to authenticated;
