-- 2026-10-09 | 81 il emlak stoku, belediye emlak vergisi, 600 TBMM
-- Eski mülkler, hesaplar, partiler ve seçilmiş vekiller korunur.
begin;
create table if not exists oyun.emlak_vergi_ulke(
  id integer primary key check(id=1),
  oran numeric not null default 0.30 check(oran between 0.10 and 1.00),
  zaman timestamptz not null default now()
);
insert into oyun.emlak_vergi_ulke(id,oran) values(1,0.30) on conflict(id) do nothing;
create table if not exists oyun.emlak_vergi_il(
  il_id smallint primary key references oyun.iller(id),
  carpan numeric not null default 1.00 check(carpan between 0.5 and 1.5),
  baskan uuid references oyun.profiller(id),
  zaman timestamptz not null default now()
);
create table if not exists oyun.emlak_vergi_kayit(
  id bigint generated always as identity primary key,
  mulk_id bigint not null references oyun.yatirim_mulkleri(id),
  user_id uuid not null references oyun.profiller(id),
  il_id smallint not null references oyun.iller(id),
  haftalar integer not null check(haftalar>0),
  tutar numeric not null check(tutar>=0),
  zaman timestamptz not null,
  odendi boolean not null default true
);
create index if not exists emlak_vergi_kayit_il on oyun.emlak_vergi_kayit(il_id,zaman);
create table if not exists oyun.emlak_stok_ayar (
 il_id smallint not null references oyun.iller(id),
 tip text not null check(tip in ('daire','dukkan','villa')),
 kapasite integer not null check(kapasite>=0),
 primary key(il_id,tip)
);
-- Sayı, nüfus vekili olan MV dağılımı ile ölçeklenir:
-- İstanbul daire 100 / Bayburt daire 8; dükkan 40 / 3; villa 20 / 2.
insert into oyun.emlak_stok_ayar(il_id,tip,kapasite)
select i.id,x.tip,case x.tip
 when 'daire' then greatest(8,round(8+(i.mv-1)*92.0/95)::int)
 when 'dukkan' then greatest(3,round(3+(i.mv-1)*37.0/95)::int)
 else greatest(2,round(2+(i.mv-1)*18.0/95)::int) end
from oyun.iller i cross join (values('daire'),('dukkan'),('villa')) x(tip)
on conflict(il_id,tip) do nothing;
do $ddl$ declare n text; begin
 foreach n in array array['emlak_vergi_ulke','emlak_vergi_il','emlak_vergi_kayit','emlak_stok_ayar'] loop
   execute format('alter table oyun.%I enable row level security',n);
   execute format('revoke all on oyun.%I from public,anon,authenticated',n);
 end loop;
end $ddl$;

create or replace function oyun.emlak_il_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $fn$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000
 when 'villa' then 520000 else null end)::numeric *
 (0.65+i.mv::numeric*1.10/96 + coalesce(d.gelisim,50)/100*0.15))
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$fn$;

create or replace function oyun.emlak_vergi_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $fn$
 select round(u.oran*coalesce(c.carpan,1),3) from oyun.emlak_vergi_ulke u
 left join oyun.emlak_vergi_il c on c.il_id=p_il where u.id=1
$fn$;

create or replace function public.mulk_il_stok()
returns jsonb language sql stable security definer set search_path='' as $fn$
 select coalesce(jsonb_agg(jsonb_build_object(
 'il_id',a.id,'il',a.ad,'tur',a.tip,'toplam',a.kapasite,
 'satilan',a.satilan,'kalan',greatest(0,a.kapasite-a.satilan),
 'fiyat',oyun.emlak_il_fiyat(a.id,a.tip),
 'haftalik',round(oyun.emlak_il_fiyat(a.id,a.tip)*.025,2),
 'vergi_oran',oyun.emlak_vergi_oran(a.id),
 'gelisim',a.gelisim) order by a.ad,a.tip),'[]'::jsonb)
 from (
  select i.id,i.ad,z.tip,z.kapasite,coalesce(d.gelisim,50) gelisim,
  (select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=z.tip) satilan
  from oyun.iller i join oyun.emlak_stok_ayar z on z.il_id=i.id
  left join oyun.il_durum d on d.il_id=i.id
 ) a
$fn$;
revoke all on function public.mulk_il_stok() from public,anon;
grant execute on function public.mulk_il_stok() to authenticated;

create or replace function public.mulk_il_satin_al(p_tip text,p_il_id smallint)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=auth.uid();p oyun.profiller;i oyun.iller;
 c integer; sat integer; bedel numeric;kira numeric;t timestamptz:=oyun.simdi();yeni bigint;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Geçerli oyuncu hesabı gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') then raise exception 'Geçersiz mülk türü.'; end if;
 select * into i from oyun.iller where id=p_il_id;
 if i.id is null then raise exception 'Geçerli bir il seç.'; end if;
 -- Eşzamanlı satışların stok limitini geçmesini önlemek için il ve tür bazında kilit.
 perform pg_advisory_xact_lock(683321,hashtext(p_il_id::text||':'||p_tip));
 select kapasite into c from oyun.emlak_stok_ayar where il_id=p_il_id and tip=p_tip;
 if c is null then raise exception 'Bu ilde mülk arzı oluşturulmadı.'; end if;
 select count(*) into sat from oyun.yatirim_mulkleri where il_id=p_il_id and tip=p_tip;
 if sat>=c then raise exception '% ilinde % stoku tükendi.',i.ad,p_tip; end if;
 bedel:=oyun.emlak_il_fiyat(p_il_id,p_tip); kira:=round(bedel*.025,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s / %s satın alındı',i.ad,p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il_id,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,i.ad||' / '||p_tip||' devlet gayrimenkul alımı');
 return public.mulk_liste();
end $fn$;
revoke all on function public.mulk_il_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_il_satin_al(text,smallint) to authenticated;

-- Eski istemciler için de stok kuralını aşma olmasın.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 if il is null then raise exception 'Önce bir il seçmelisin.'; end if;
 return public.mulk_il_satin_al(p_tip,il);
end $fn$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.emlak_vergi_belediye_ayarla(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar; t timestamptz:=oyun.simdi();last_t timestamptz;
begin
 select * into m from oyun.makamlar where user_id=p.id and tur='bel' and bit is null;
 if m.id is null then raise exception 'Bu kararı yalnızca görevdeki il belediye başkanı alabilir.'; end if;
 if p_carpan is null or p_carpan not between 0.5 and 1.5 or p_carpan<>round(p_carpan,2)
 then raise exception 'Yerel emlak vergisi katsayısı 0,50–1,50 arasında olmalı.'; end if;
 select zaman into last_t from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if last_t is not null and last_t>t-interval '24 hours'
 then raise exception 'Vergi katsayısı 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_vergi_il(il_id,carpan,baskan,zaman)
 values(m.il_id,p_carpan,p.id,t) on conflict(il_id) do update set
 carpan=excluded.carpan,baskan=excluded.baskan,zaman=excluded.zaman;
 perform oyun.olay('belediye',format('%s Belediyesi haftalık emlak vergisi katsayısını %s olarak belirledi.',
 (select ad from oyun.iller where id=m.il_id),p_carpan),m.il_id,p.parti_id,t);
 return jsonb_build_object('oran',oyun.emlak_vergi_oran(m.il_id),'carpan',p_carpan);
end $fn$;
revoke all on function public.emlak_vergi_belediye_ayarla(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayarla(numeric) to authenticated;

create or replace function public.emlak_vergisi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare a jsonb; kid bigint;
begin
 if p_oran is null or p_oran not between 0.10 and 1.00 or p_oran<>round(p_oran,2)
 then raise exception 'Ulusal haftalık emlak vergisi oranı %%0,10–%%1,00 arasında olmalı.'; end if;
 a:=public.kanun_teklif('serbest',p_baslik,p_metin,null);
 kid:=(a->>'id')::bigint;
 update oyun.kanunlar set veri=jsonb_build_object('eylem','emlak_vergisi','oran',p_oran)
 where id=kid and teklif_eden=auth.uid();
 if not found then raise exception 'Emlak vergisi kanunu kaydedilemedi.'; end if;
 return a||jsonb_build_object('emlak_vergisi_oran',p_oran);
end $fn$;
revoke all on function public.emlak_vergisi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergisi_kanun_teklif(numeric,text,text) to authenticated;

-- Kanun yürürlüğe girdikten sonra ulusal emlak vergisi oranı değişir;
-- sadece kanun teklifi verilmesi oranı değiştirmez.
do $patch$ declare f text;needle text; begin
 select pg_get_functiondef('oyun.kanun_yururluk(bigint,timestamp with time zone,text)'::regprocedure) into f;
 needle:='  elsif k.tur=''butce'' then';
 if position('k.veri->>''eylem''=''emlak_vergisi''' in f)=0 then
  if position(needle in f)=0 then raise exception 'kanun_yururluk güncelleme yeri bulunamadı'; end if;
  f:=replace(f,needle,
  '  elsif k.tur=''serbest'' and k.veri->>''eylem''=''emlak_vergisi'' then
    update oyun.emlak_vergi_ulke set oran=(k.veri->>''oran'')::numeric,zaman=t where id=1;
    perform oyun.olay(''meclis'',format(''TBMM emlak vergisi haftalık oranını %s olarak belirledi.'',k.veri->>''oran''),null,k.teklif_parti,t);
  elsif k.tur=''butce'' then');
  execute f;
 end if;
end $patch$;

-- Belediye emlak vergisi, kira tahsilinde 7 günlük takvimle otomatik kesilir.
-- Mevcut çoklu mülk vergisi korunur, yeni payın tamamı mülkün bulunduğu il kasasına gider.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $fn$
declare m record;n int;gross numeric;tax numeric;t timestamptz:=oyun.simdi();yerel numeric; net numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and
     (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
     then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  -- Vergi matrahı kiranın hesaplandığı temel gayrimenkul değeridir:
  -- spekülatif mülk satış fiyatı haftalık kirayı veya vergiyi yükseltmez.
  yerel:=round(least(m.alis_bedeli,m.haftalik_kira/0.025)*n*oyun.emlak_vergi_oran(m.il_id)/100,2);
  net:=gross-tax-yerel;
  if net<0 then
    -- Kullanıcının maaşını ve oturumunu bloklamadan kira üstünden tahsil edilebilen pay.
    yerel:=greatest(0,gross-tax);
    net:=0;
  end if;
  perform oyun.para_islem(p_user,net,'kira',format('Mulk #%s: %s haftalik kira, vergi %s TL',m.id,n,tax+yerel),t,tax+yerel);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1; end if;
  if yerel>0 then
    update oyun.il_durum set kasa=kasa+yerel/1000000000 where il_id=m.il_id;
    insert into oyun.emlak_vergi_kayit(mulk_id,user_id,il_id,haftalar,tutar,zaman)
      values(m.id,p_user,m.il_id,n,yerel,t);
  end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
    toplam_kira=toplam_kira+net,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $fn$;

-- 600 sandalye esas; dolu olmayan sandalyeler yasa çoğunluğuna katılmaz.
update oyun.ayarlar set meclis_olcek=0 where id=1;
create or replace function oyun.meclis_olcek_hesap(t timestamptz)
returns jsonb language sql stable set search_path='' as $fn$
 select jsonb_build_object(
 'aktif',(select count(*) from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days'),
 'sandalye',coalesce((select round(deger)::int from oyun.anayasa where kod='milletvekili_sayisi'),600),
 'anayasal',coalesce((select round(deger)::int from oyun.anayasa where kod='milletvekili_sayisi'),600),
 'olcek',0)
$fn$;
select oyun.dagit_mv_sandalye(600);
do $majority$ declare f text; begin
 select pg_get_functiondef('oyun.kanun_tick(timestamp with time zone)'::regprocedure) into f;
 if position('c.kabul >= floor(dolu / 2.0) + 1' in f)=0 then
   if position('c.kabul >= floor(dolu / 4.0) + 1' in f)=0 then raise exception 'Kanun çoğunluğu güncellemesi için eşleşme bulunamadı'; end if;
   f:=replace(f,'c.kabul >= floor(dolu / 4.0) + 1','c.kabul >= floor(dolu / 2.0) + 1');
   f:=replace(f,'floor(dolu / 4.0) + 1','floor(dolu / 2.0) + 1');
   execute f;
 end if;
end $majority$;
commit;