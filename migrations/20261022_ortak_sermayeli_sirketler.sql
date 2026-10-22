
-- 2026-10-22: Oyuncular arasi ortak sermayeli kurulus ve bedelli/bedelsiz hisse devri.
-- Eski sirketler, ortaklik paylari, bakiyeler ve sirket kayitlari korunur.
create table if not exists oyun.ortak_sirket_kurulus (
 id bigint generated always as identity primary key,
 kurucu uuid not null references auth.users(id),
 ad text not null,
 sektor text not null,
 il_id smallint not null references oyun.iller(id),
 urun text,
 toplam numeric not null check (toplam between 100000 and 100000000),
 durum text not null default 'bekliyor'
  check (durum in ('bekliyor','kuruldu','iptal','reddedildi')),
 sirket_id bigint references oyun.sirketler(id),
 zaman timestamptz not null default now(),
 bitis timestamptz not null default (now()+interval '72 hours')
);
create table if not exists oyun.ortak_sirket_katilim (
 kurulus_id bigint not null references oyun.ortak_sirket_kurulus(id),
 user_id uuid not null references auth.users(id),
 tutar numeric not null check(tutar > 0 and tutar = round(tutar)),
 durum text not null default 'davet' check(durum in ('davet','kabul','ret')),
 primary key (kurulus_id,user_id)
);
create index if not exists ortak_sirket_davet_ind on oyun.ortak_sirket_katilim(user_id,durum);
create table if not exists oyun.ortak_sirket_devir (
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 satici uuid not null references auth.users(id),
 alici uuid not null references auth.users(id),
 pay numeric not null check(pay>0 and pay<=100 and pay=round(pay,6)),
 bedel numeric not null check(bedel>=0 and bedel<=1000000000 and bedel=round(bedel)),
 durum text not null default 'bekliyor'
  check(durum in ('bekliyor','kabul','ret','iptal')),
 zaman timestamptz not null default now(),
 bitis timestamptz not null default (now()+interval '72 hours'),
 kapanis timestamptz
);
create index if not exists ortak_devir_gelen on oyun.ortak_sirket_devir(alici,durum);
create index if not exists ortak_devir_giden on oyun.ortak_sirket_devir(satici,durum);
alter table oyun.ortak_sirket_kurulus enable row level security;
alter table oyun.ortak_sirket_katilim enable row level security;
alter table oyun.ortak_sirket_devir enable row level security;
revoke all on oyun.ortak_sirket_kurulus,oyun.ortak_sirket_katilim,oyun.ortak_sirket_devir from public,anon,authenticated;
revoke all on sequence oyun.ortak_sirket_kurulus_id_seq,oyun.ortak_sirket_devir_id_seq from public,anon,authenticated;

create or replace function public.ortak_sirket_panel()
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return jsonb_build_object(
  'sirketler',coalesce((select jsonb_agg(jsonb_build_object(
   'id',s.id,'ad',s.ad,'sektor',s.sektor,'sermaye',s.sermaye,'kasa',s.kasa,
   'benim_pay',o.pay,'tek_ortak',o.pay=100,'ortaklar',
   coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(so.user_id),'pay',so.pay) order by so.pay desc)
    from oyun.sirket_ortaklari so where so.sirket_id=s.id),'[]'::jsonb)))
   from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id
   where s.aktif and o.user_id=p.id),'[]'::jsonb),
  'kuruluslar',coalesce((select jsonb_agg(jsonb_build_object(
   'id',k.id,'ad',k.ad,'sektor',k.sektor,'il',k.il_id,'urun',k.urun,
   'toplam',k.toplam,'durum',k.durum,'kurucu',oyun.kad(k.kurucu),
   'kurucu_benim',k.kurucu=p.id,'bitis',k.bitis,
   'katilimlar',(select jsonb_agg(jsonb_build_object('kad',oyun.kad(a.user_id),
      'tutar',a.tutar,'durum',a.durum,'benim',a.user_id=p.id) order by a.tutar desc)
      from oyun.ortak_sirket_katilim a where a.kurulus_id=k.id)))
    from oyun.ortak_sirket_kurulus k
    where k.durum='bekliyor' and k.bitis>oyun.simdi()
     and (k.kurucu=p.id or exists(select 1 from oyun.ortak_sirket_katilim a where a.kurulus_id=k.id and a.user_id=p.id))
    ),'[]'::jsonb),
  'devirler',coalesce((select jsonb_agg(jsonb_build_object(
    'id',d.id,'sirket',s.ad,'sirket_id',d.sirket_id,'satici',oyun.kad(d.satici),
    'alici',oyun.kad(d.alici),'benim_teklifim',d.satici=p.id,
    'benim_gelen',d.alici=p.id,'pay',d.pay,'bedel',d.bedel,'bitis',d.bitis))
   from oyun.ortak_sirket_devir d join oyun.sirketler s on s.id=d.sirket_id
   where d.durum='bekliyor' and d.bitis>oyun.simdi()
    and (d.satici=p.id or d.alici=p.id)),'[]'::jsonb));
end $$;

create or replace function public.ortak_sirket_kur_teklif(
 p_ad text,p_sektor text,p_il integer,p_urun text,p_kendi numeric,p_ortaklar jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
 v_id bigint; v_toplam numeric:=0; v_kisi jsonb; v_tutar numeric;
 v_hedef oyun.profiller; v_kad text; v_adet int;
begin
 if p_ad is null or length(btrim(p_ad)) not between 3 and 50 then raise exception 'Şirket adı 3-50 karakter olmalı.';end if;
 if p_sektor not in ('tarim','sanayi','teknoloji','ticaret','insaat','medya') then
  raise exception 'Ortak kuruluş için geçerli şirket sektörü seç.'; end if;
 if p_il is null or not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçerli il seç.';end if;
 if p_sektor='sanayi' and coalesce(p_urun,'malzeme') not in ('gida','teknoloji','malzeme') then
  raise exception 'Üretim grubu geçersiz.';end if;
 if p_kendi is null or p_kendi<=0 or p_kendi<>round(p_kendi) then raise exception 'Kendi sermayeni tam sayı gir.';end if;
 if p_ortaklar is null or jsonb_typeof(p_ortaklar)<>'array' then raise exception 'Davet listesi gerekli.';end if;
 v_adet:=jsonb_array_length(p_ortaklar);
 if v_adet<1 or v_adet>7 then raise exception 'En az 1, en fazla 7 ortak davet edebilirsin.';end if;
 v_toplam:=p_kendi;
 for v_kisi in select value from jsonb_array_elements(p_ortaklar) loop
  v_kad:=btrim(coalesce(v_kisi->>'kad',''));
  if length(v_kad)<2 then raise exception 'Geçerli oyuncu adı gir.'; end if;
  if coalesce(v_kisi->>'tutar','') !~ '^[0-9]+$' then raise exception '% için sermaye pozitif tam sayı olmalı.',v_kad;end if;
  v_tutar:=(v_kisi->>'tutar')::numeric;
  if v_tutar<=0 then raise exception 'Ortakların sermayesi sıfır olamaz.';end if;
  select * into v_hedef from oyun.profiller
   where lower(kad)=lower(v_kad) and not yasakli;
  if v_hedef.id is null or v_hedef.id=p.id then raise exception 'Oyuncu bulunamadı: %',v_kad;end if;
  v_toplam:=v_toplam+v_tutar;
 end loop;
 if v_toplam < 100000 or v_toplam>100000000 then
  raise exception 'Toplam kuruluş sermayesi 100.000–100.000.000 ₺ olmalı.';end if;
 insert into oyun.ortak_sirket_kurulus(kurucu,ad,sektor,il_id,urun,toplam)
 values(p.id,btrim(p_ad),p_sektor,p_il::smallint,nullif(p_urun,''),v_toplam) returning id into v_id;
 insert into oyun.ortak_sirket_katilim(kurulus_id,user_id,tutar,durum)
 values(v_id,p.id,p_kendi,'kabul');
 for v_kisi in select value from jsonb_array_elements(p_ortaklar) loop
  select * into v_hedef from oyun.profiller where lower(kad)=lower(btrim(v_kisi->>'kad')) and not yasakli;
  insert into oyun.ortak_sirket_katilim(kurulus_id,user_id,tutar)
  values(v_id,v_hedef.id,(v_kisi->>'tutar')::numeric);
  perform oyun.bildir(v_hedef.id,format('%s seni %s şirketine %s ₺ sermaye ile ortak olmaya davet etti. Şirketler > Ortaklık Merkezi ekranından yanıtla.',p.kad,p_ad,oyun.tl((v_kisi->>'tutar')::numeric)),oyun.simdi());
 end loop;
 return jsonb_build_object('tamam',true,'kurulus_id',v_id,'toplam',v_toplam);
end $$;

create or replace function public.ortak_sirket_kur_karar(p_id bigint,p_kabul boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); k oyun.ortak_sirket_kurulus;
begin
 select * into k from oyun.ortak_sirket_kurulus where id=p_id for update;
 if k.id is null or k.durum<>'bekliyor' or k.bitis<=oyun.simdi() then raise exception 'Kuruluş davetinin süresi dolmuş.'; end if;
 if not exists(select 1 from oyun.ortak_sirket_katilim where kurulus_id=p_id and user_id=p.id and durum='davet') then
  raise exception 'Yanıtlanabilir davetin bulunmuyor.';end if;
 update oyun.ortak_sirket_katilim set durum=case when p_kabul then 'kabul' else 'ret' end
 where kurulus_id=p_id and user_id=p.id;
 if not p_kabul then update oyun.ortak_sirket_kurulus set durum='reddedildi' where id=p_id;end if;
 perform oyun.bildir(k.kurucu,format('%s %s şirketi ortaklık davetine %s yanıtı verdi.',p.kad,k.ad,case when p_kabul then 'kabul' else 'ret' end),oyun.simdi());
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.ortak_sirket_kur_iptal(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); k oyun.ortak_sirket_kurulus;
begin
 select * into k from oyun.ortak_sirket_kurulus where id=p_id for update;
 if k.kurucu is distinct from p.id or k.durum<>'bekliyor' then raise exception 'Bekleyen kendi teklifini iptal edebilirsin.';end if;
 update oyun.ortak_sirket_kurulus set durum='iptal' where id=p_id;
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.ortak_sirket_kur_tamamla(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); k oyun.ortak_sirket_kurulus;
 a record; sonuc jsonb; sid bigint; v_pay numeric; v_diger numeric:=0;
begin
 perform pg_advisory_xact_lock(98765,hashtext(p_id::text));
 select * into k from oyun.ortak_sirket_kurulus where id=p_id for update;
 if k.kurucu is distinct from p.id or k.durum<>'bekliyor' or k.bitis<=oyun.simdi()
  then raise exception 'Kuruluş teklifi geçersiz veya yetkisiz işlem.';end if;
 if exists(select 1 from oyun.ortak_sirket_katilim where kurulus_id=p_id and durum<>'kabul') then
  raise exception 'Kuruluş için tüm ortaklar daveti kabul etmeli.';end if;
 if (select count(*) from oyun.ortak_sirket_katilim where kurulus_id=p_id)<2 or
  (select sum(tutar) from oyun.ortak_sirket_katilim where kurulus_id=p_id)<>k.toplam then
  raise exception 'Sermaye ve ortaklık toplamı uyuşmuyor.';end if;
 -- Oyuncu bakiyeleri kararlı sırayla kilitlenir, herkesin fonu teyit edilir.
 for a in select a.user_id,a.tutar from oyun.ortak_sirket_katilim a
  where a.kurulus_id=p_id order by a.user_id loop
  perform 1 from oyun.cuzdan where user_id=a.user_id and para>=a.tutar for update;
  if not found then raise exception '% için % ₺ kullanılabilir bakiye gerekli.',oyun.kad(a.user_id),oyun.tl(a.tutar);end if;
 end loop;
 -- Para hiçbir ara aşamada harcanmaz; tüm katılım tek DB işleminde kaydedilir.
 for a in select a.user_id,a.tutar from oyun.ortak_sirket_katilim a
  where a.kurulus_id=p_id and a.user_id<>p.id order by a.user_id loop
  perform oyun.para_islem(a.user_id,-a.tutar,'sirket',format('Ortak kuruluş sermayesi: %s',k.ad),oyun.simdi());
  perform oyun.para_islem(p.id,a.tutar,'sirket',format('Ortak kuruluş sermayesi aktarımı: %s',k.ad),oyun.simdi());
 end loop;
 if k.sektor in ('tarim','sanayi','teknoloji') then
  sonuc:=public.sirket_kur_aktif_ilde(k.ad,k.sektor,k.toplam,k.urun,k.il_id);
 else
  sonuc:=public.sirket_kur_ilde(k.ad,k.sektor,k.toplam,k.il_id);
  if k.sektor='ticaret' then perform public.eko_ticaret_islem('bagla',jsonb_build_object('sirket',(sonuc->>'id')::bigint)); end if;
 end if;
 sid:=(sonuc->>'id')::bigint;
 -- Yuvarlama farkı yalnızca kurucunun payından düşülür; toplam tam %100 olur.
 for a in select user_id,tutar from oyun.ortak_sirket_katilim
  where kurulus_id=p_id and user_id<>p.id order by user_id loop
  v_pay:=round(a.tutar*100/k.toplam,6);
  if v_pay<=0 then raise exception 'Ortak payı hesaplanamadı.';end if;
  insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(sid,a.user_id,v_pay);
  v_diger:=v_diger+v_pay;
 end loop;
 update oyun.sirket_ortaklari set pay=100-v_diger where sirket_id=sid and user_id=p.id;
 if (select pay from oyun.sirket_ortaklari where sirket_id=sid and user_id=p.id)<=0 then
  raise exception 'Kurucu payı hesaplanamadı.'; end if;
 update oyun.ortak_sirket_kurulus set durum='kuruldu',sirket_id=sid where id=p_id;
 for a in select user_id from oyun.ortak_sirket_katilim where kurulus_id=p_id loop
  perform oyun.bildir(a.user_id,format('%s ortak şirketi kuruldu. Şirketlerim bölümünde payını görebilirsin.',k.ad),oyun.simdi());
 end loop;
 return jsonb_build_object('tamam',true,'sirket_id',sid,'toplam',k.toplam);
end $$;

create or replace function public.ortak_sirket_devir_teklif(p_sirket bigint,p_kad text,p_pay numeric,p_bedel numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); h oyun.profiller; s oyun.sirketler; v_pay numeric; v_id bigint;
begin
 if p_kad is null then raise exception 'Alıcı oyuncuyu gir.';end if;
 select * into h from oyun.profiller where lower(kad)=lower(btrim(p_kad)) and not yasakli;
 if h.id is null or h.id=p.id then raise exception 'Geçerli başka bir oyuncu seç.';end if;
 if p_pay is null or p_pay<=0 or p_pay>100 or p_pay<>round(p_pay,6) then raise exception 'Pay yüzde 0–100 arasında, en fazla 6 basamaklı olmalı.';end if;
 if p_bedel is null or p_bedel<0 or p_bedel>1000000000 or p_bedel<>round(p_bedel) then raise exception 'Bedel sıfır veya pozitif tam sayı olmalı.';end if;
 perform pg_advisory_xact_lock(98763,hashtext(p_sirket::text));
 select * into s from oyun.sirketler where id=p_sirket for update;
 if s.id is null or not s.aktif or s.sektor='banka' then raise exception 'Faaliyetteki uygun bir şirket seç.';end if;
 select pay into v_pay from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=p.id for update;
 if v_pay is null or v_pay<p_pay then raise exception 'Devretmek istediğin kadar hissen yok.';end if;
 if exists(select 1 from oyun.ortak_sirket_devir where sirket_id=p_sirket and satici=p.id and alici=h.id and durum='bekliyor' and bitis>oyun.simdi()) then raise exception 'Bu oyuncuya zaten bekleyen teklif var.';end if;
 insert into oyun.ortak_sirket_devir(sirket_id,satici,alici,pay,bedel)
 values(p_sirket,p.id,h.id,p_pay,p_bedel) returning id into v_id;
 perform oyun.bildir(h.id,format('%s sana %s şirketindeki %s%% hisselerini %s olarak devretmeyi teklif etti. Şirketler > Ortaklık Merkezi bölümünden karar ver.',p.kad,s.ad,p_pay,case when p_bedel=0 then 'bedelsiz' else oyun.tl(p_bedel)||' ₺ karşılığında' end),oyun.simdi());
 return jsonb_build_object('tamam',true,'id',v_id);
end $$;

create or replace function public.ortak_sirket_devir_karar(p_id bigint,p_kabul boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.ortak_sirket_devir; s oyun.sirketler;
 v_pay numeric; v_borsa numeric:=0; v_ilan numeric:=0; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.ortak_sirket_devir where id=p_id;
 if d.id is null or d.alici<>p.id then raise exception 'Sana ait teklif bulunamadı.';end if;
 perform pg_advisory_xact_lock(98763,hashtext(d.sirket_id::text));
 select * into d from oyun.ortak_sirket_devir where id=p_id for update;
 if d.durum<>'bekliyor' or d.bitis<=t then raise exception 'Teklifin süresi doldu.';end if;
 if not p_kabul then
  update oyun.ortak_sirket_devir set durum='ret',kapanis=t where id=p_id;
  return jsonb_build_object('tamam',true,'durum','ret');
 end if;
 select * into s from oyun.sirketler where id=d.sirket_id for update;
 if s.id is null or not s.aktif or s.sektor='banka' then raise exception 'Şirket devre uygun değil.';end if;
 perform oyun.sirket_hesapla(d.sirket_id);
 select pay into v_pay from oyun.sirket_ortaklari where sirket_id=d.sirket_id and user_id=d.satici for update;
 if to_regclass('oyun.borsa_emir') is not null then
  execute 'select coalesce(sum(kalan),0) from oyun.borsa_emir where sirket_id=$1 and satici=$2 and durum=''acik'''
  into v_borsa using d.sirket_id,d.satici;
 end if;
 select coalesce(sum(pay),0) into v_ilan from oyun.sirket_hisse_ilanlari
 where sirket_id=d.sirket_id and satici=d.satici and durum='acik';
 if v_pay is null or v_pay<d.pay+v_borsa+v_ilan then raise exception 'Satıcının serbest hissesi yetersiz.';end if;
 if d.bedel>0 then
  perform oyun.para_islem(p.id,-d.bedel,'sirket',format('%s şirketi hisse alımı',s.ad),t);
  perform oyun.para_islem(d.satici,d.bedel,'sirket',format('%s şirketi hisse satışı',s.ad),t);
 end if;
 if d.pay=v_pay then
  delete from oyun.sirket_ortaklari where sirket_id=d.sirket_id and user_id=d.satici;
 else
  update oyun.sirket_ortaklari set pay=pay-d.pay where sirket_id=d.sirket_id and user_id=d.satici;
 end if;
 insert into oyun.sirket_ortaklari(sirket_id,user_id,pay)
 values(d.sirket_id,p.id,d.pay)
 on conflict(sirket_id,user_id) do update set pay=oyun.sirket_ortaklari.pay+excluded.pay;
 if s.yonetici=d.satici and d.pay=v_pay then
  update oyun.sirketler set yonetici=p.id where id=s.id;
 end if;
 update oyun.sirketler set satilik=null where id=s.id;
 update oyun.ortak_sirket_devir set durum='kabul',kapanis=t where id=p_id;
 update oyun.sirket_teklif set durum='iptal'
 where sirket_id=s.id and satici=d.satici and durum='bekliyor'
  and pay>coalesce((select pay from oyun.sirket_ortaklari where sirket_id=s.id and user_id=d.satici),0);
 update oyun.ortak_sirket_devir set durum='iptal',kapanis=t
 where sirket_id=s.id and satici=d.satici and durum='bekliyor'
  and pay>coalesce((select pay from oyun.sirket_ortaklari where sirket_id=s.id and user_id=d.satici),0);
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,pay,zaman,aciklama)
 values('sirket_hisse',s.id,d.satici,p.id,d.bedel,d.pay,t,format('%s şirketi %s%% hisse devri (%s)',s.ad,d.pay,case when d.bedel=0 then 'bedelsiz' else 'bedelli' end));
 perform oyun.bildir(d.satici,format('%s şirketindeki %s%% hissen %s oyuncusuna devredildi.',s.ad,d.pay,p.kad),t);
 perform oyun.bildir(p.id,format('%s şirketinden %s%% hisse devraldın.',s.ad,d.pay),t);
 return jsonb_build_object('tamam',true,'sirket_id',s.id,'pay',d.pay,'bedel',d.bedel);
end $$;

create or replace function public.ortak_sirket_devir_iptal(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.ortak_sirket_devir;
begin
 select * into d from oyun.ortak_sirket_devir where id=p_id for update;
 if d.satici is distinct from p.id or d.durum<>'bekliyor' then raise exception 'İptal edilebilir teklif bulunamadı.';end if;
 update oyun.ortak_sirket_devir set durum='iptal',kapanis=oyun.simdi() where id=p_id;
 return jsonb_build_object('tamam',true);
end $$;

revoke all on function public.ortak_sirket_panel() from public,anon,authenticated;
revoke all on function public.ortak_sirket_kur_teklif(text,text,integer,text,numeric,jsonb) from public,anon,authenticated;
revoke all on function public.ortak_sirket_kur_karar(bigint,boolean) from public,anon,authenticated;
revoke all on function public.ortak_sirket_kur_iptal(bigint) from public,anon,authenticated;
revoke all on function public.ortak_sirket_kur_tamamla(bigint) from public,anon,authenticated;
revoke all on function public.ortak_sirket_devir_teklif(bigint,text,numeric,numeric) from public,anon,authenticated;
revoke all on function public.ortak_sirket_devir_karar(bigint,boolean) from public,anon,authenticated;
revoke all on function public.ortak_sirket_devir_iptal(bigint) from public,anon,authenticated;
grant execute on function public.ortak_sirket_panel() to authenticated;
grant execute on function public.ortak_sirket_kur_teklif(text,text,integer,text,numeric,jsonb) to authenticated;
grant execute on function public.ortak_sirket_kur_karar(bigint,boolean) to authenticated;
grant execute on function public.ortak_sirket_kur_iptal(bigint) to authenticated;
grant execute on function public.ortak_sirket_kur_tamamla(bigint) to authenticated;
grant execute on function public.ortak_sirket_devir_teklif(bigint,text,numeric,numeric) to authenticated;
grant execute on function public.ortak_sirket_devir_karar(bigint,boolean) to authenticated;
grant execute on function public.ortak_sirket_devir_iptal(bigint) to authenticated;
