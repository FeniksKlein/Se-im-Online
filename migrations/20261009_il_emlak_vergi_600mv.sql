-- 2026-10-09: 81 il emlak stoku + belediye emlak vergisi + 600 sandalyeli TBMM
-- Var olan tapu ve cüzdanlar korunur; yerel model oyun içi nüfus temsili olan il mv ağırlığından türetilir.
insert into oyun.yasa_ekonomi_ayar(kod,deger,guncelleme)
 values('emlak_haftalik_baz',0.20,oyun.simdi()) on conflict (kod) do nothing;
create table if not exists oyun.emlak_vergi_il(
 il_id smallint primary key references oyun.iller(id),
 carpan numeric not null default 1 check(carpan between 0.5 and 2),
 baskan uuid references oyun.profiller(id),
 guncelleme timestamptz not null default now()
);
create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 user_id uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 zaman timestamptz not null,
 tutar numeric not null check(tutar>=0),
 hafta integer not null default 1
);
create index if not exists idx_emlak_vergi_kayit_il on oyun.emlak_vergi_kayit(il_id,zaman);
alter table oyun.emlak_vergi_il enable row level security;
alter table oyun.emlak_vergi_kayit enable row level security;
revoke all on oyun.emlak_vergi_il,oyun.emlak_vergi_kayit from public,anon,authenticated;
alter table oyun.yatirim_mulkleri add column if not exists sonraki_vergi timestamptz;
update oyun.yatirim_mulkleri set sonraki_vergi=greatest(oyun.simdi()+interval '7 days',coalesce(sonraki_kira,oyun.simdi()+interval '7 days')) where sonraki_vergi is null;
alter table oyun.yatirim_mulkleri alter column sonraki_vergi set not null;

create or replace function oyun.emlak_vergi_oran_il(p_il smallint)
returns numeric language sql stable set search_path='' as $$
select round(coalesce((select deger from oyun.yasa_ekonomi_ayar where kod='emlak_haftalik_baz'),0.20) *
coalesce((select carpan from oyun.emlak_vergi_il where il_id=p_il),1),3)
$$;
create or replace function oyun.emlak_il_bilgi(p_il smallint,p_tip text)
returns jsonb language plpgsql stable set search_path='' as $$
declare i oyun.iller; d oyun.il_durum; taban int; kapasite int; mevcut int; baz numeric; carpan numeric; bedel numeric; kira numeric; oran numeric;
begin
 if p_tip not in ('daire','dukkan','villa') then raise exception 'Geçersiz mülk türü.'; end if;
 select * into i from oyun.iller where id=p_il;
 if i.id is null then raise exception 'İl bulunamadı.'; end if;
 select * into d from oyun.il_durum where il_id=p_il;
 -- MV dağılımı nüfus ağırlığını temsil eder: İstanbul 100, Bayburt 8 daire.
 taban:=8+floor(92*(greatest(1,i.mv)-1)::numeric/95)::int;
 kapasite:=case p_tip when 'daire' then taban when 'dukkan' then greatest(3,round(taban*0.34)::int)
 else greatest(2,round(taban*0.12)::int) end;
 select count(*) into mevcut from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 baz:=case p_tip when 'daire' then 130000 when 'dukkan' then 260000 else 520000 end;
 carpan:=greatest(0.6,least(1.75,0.65+0.7*(i.mv-1)::numeric/95+(coalesce(d.gelisim,50)-50)/500));
 bedel:=round(baz*carpan/1000)*1000;
 kira:=round(bedel*(0.022+coalesce(d.gelisim,50)/10000),0);
 oran:=oyun.emlak_vergi_oran_il(p_il);
 return jsonb_build_object('il_id',p_il,'il',i.ad,'tip',p_tip,'stok',kapasite,'satilan',mevcut,
   'kalan',greatest(0,kapasite-mevcut),'gelisim',coalesce(d.gelisim,50),
   'fiyat',bedel,'kira',kira,'vergi_oran',oran,'haftalik_vergi',round(bedel*oran/100,0));
end $$;
create or replace function public.emlak_il_katalog()
returns jsonb language sql stable security definer set search_path='' as $$
select coalesce(jsonb_agg(oyun.emlak_il_bilgi(i.id,t.tip) order by i.ad,t.tip),'[]'::jsonb)
from oyun.iller i cross join (values('daire'),('dukkan'),('villa')) t(tip)
$$;
revoke all on function public.emlak_il_katalog() from public,anon;
grant execute on function public.emlak_il_katalog() to authenticated;

create or replace function public.mulk_satin_al_il(p_il smallint,p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); b jsonb; bedel numeric; kira numeric; mid bigint;
begin
 if p_tip not in ('daire','dukkan','villa') then raise exception 'Mülk türünü seç.'; end if;
 -- Eşzamanlı satın alma girişleri kalan konut stokunu aşamaz.
 perform pg_advisory_xact_lock(59410,(p_il::int*10+case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end));
 b:=oyun.emlak_il_bilgi(p_il,p_tip);
 if (b->>'kalan')::int<=0 then raise exception '% % stoku tükendi. Oyuncuların satış ilanlarına bak.',b->>'il',p_tip; end if;
 bedel:=(b->>'fiyat')::numeric;kira:=(b->>'kira')::numeric;
 perform oyun.mulk_kira_tahsil(p.id);
 perform oyun.para_islem(p.id,-bedel,'emlak',format('%s %s satın alındı',b->>'il',p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,sonraki_vergi)
 values(p.id,p_il,p_tip,bedel,kira,t,t+interval '7 days',t+interval '7 days') returning id into mid;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',mid,null,p.id,bedel,t,format('%s %s devlet gayrimenkul alımı',b->>'il',p_tip));
 return public.mulk_liste();
end $$;
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al_il(p.il_id,p_tip);
end $$;
revoke all on function public.mulk_satin_al_il(smallint,text) from public,anon;
grant execute on function public.mulk_satin_al_il(smallint,text) to authenticated;

-- Kira ve yerel emlak vergisi birlikte tahakkuk ettirilir; belediye kasası milyon TL birimindedir.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;tax numeric;etax numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  perform oyun.para_islem(p_user,gross-tax,'kira',format('Mulk #%s: %s haftalik kira, vergi %s TL',m.id,n,tax),t,tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax,kira_sayisi=kira_sayisi+n where id=m.id;
  -- Önceki dönem borcu tahsil edilmez: yalnızca yeni sistemden sonraki haftalar.
  if m.sonraki_vergi<=t then
    etax:=round(m.alis_bedeli*oyun.emlak_vergi_oran_il(m.il_id)/100,0) *
      least(520,floor(extract(epoch from(t-m.sonraki_vergi))/604800)::int+1);
    if etax>0 then
      perform oyun.para_islem(p_user,-etax,'emlak_vergisi',format('Mulk #%s haftalık %s belediye emlak vergisi',m.id,oyun.emlak_vergi_oran_il(m.il_id)),t,etax);
      update oyun.il_durum set kasa=kasa+etax/1000000 where il_id=m.il_id;
      insert into oyun.emlak_vergi_kayit(mulk_id,user_id,il_id,zaman,tutar,hafta) values
       (m.id,p_user,m.il_id,t,etax,least(520,floor(extract(epoch from(t-m.sonraki_vergi))/604800)::int+1));
    end if;
    update oyun.yatirim_mulkleri set sonraki_vergi=m.sonraki_vergi+
     least(520,floor(extract(epoch from(t-m.sonraki_vergi))/604800)::int+1)*interval '7 days' where id=m.id;
  end if;
 end loop;
end $$;
-- Tapu devrinde önceki sahibin gelecek vergisi alıcıya aktarılmaz.
do $pl$ declare d text; def text; begin
 for d in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','oyun') and p.proname in ('mulk_ilan_satin_al','_emlak_pazarlik_tamamla') loop
   def:=pg_get_functiondef(d::regprocedure);
   if position('sonraki_kira=t+interval ''7 days''' in def)>0 and position('sonraki_vergi=t+interval ''7 days''' in def)=0 then
     def:=replace(def,'sonraki_kira=t+interval ''7 days''','sonraki_kira=t+interval ''7 days'',sonraki_vergi=t+interval ''7 days''');
     execute def;
   end if;
 end loop;
end $pl$;
create or replace function public.mulk_liste() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 perform oyun.mulk_kira_tahsil(u);
 return (select jsonb_build_object(
  'mulkler',coalesce(jsonb_agg(jsonb_build_object(
    'id',m.id,'tip',m.tip,'il',i.ad,'alis',m.alis_bedeli,'haftalik',m.haftalik_kira,
    'sonraki',m.sonraki_kira,'toplam_kira',m.toplam_kira,'kira_sayisi',m.kira_sayisi,
    'haftalik_vergi',round(m.alis_bedeli*oyun.emlak_vergi_oran_il(m.il_id)/100),
    'sonraki_vergi',m.sonraki_vergi) order by m.satin_alma desc,m.id desc),'[]'::jsonb),
  'adet',count(m.id),'haftalik_toplam',coalesce(sum(m.haftalik_kira),0),
  'mulk_degeri',coalesce(sum(m.alis_bedeli),0),
  'cuzdan',(select para from oyun.cuzdan where user_id=u))
 from oyun.yatirim_mulkleri m join oyun.iller i on i.id=m.il_id where m.user_id=u);
end $$;

create or replace function public.emlak_vergi_belediye_ayarla(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar:=oyun.baskan_zorunlu(p);t timestamptz:=oyun.simdi();son timestamptz;
begin
 if p_carpan is null or p_carpan<0.5 or p_carpan>2 or p_carpan<>round(p_carpan,2) then raise exception 'Belediye çarpanı 0,50 ile 2,00 arasında olmalı.';end if;
 select guncelleme into son from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if son is not null and son>t-interval '24 hours' then raise exception 'Emlak vergi oranını 24 saatte bir değiştirebilirsin.';end if;
 insert into oyun.emlak_vergi_il(il_id,carpan,baskan,guncelleme)
 values(m.il_id,p_carpan,p.id,t) on conflict(il_id) do update
 set carpan=excluded.carpan,baskan=excluded.baskan,guncelleme=excluded.guncelleme;
 perform oyun.olay('belediye',format('%s belediyesi emlak vergisi çarpanını %s olarak ayarladı.',(select ad from oyun.iller where id=m.il_id),p_carpan),m.il_id,p.parti_id,t);
 return jsonb_build_object('il_id',m.il_id,'carpan',p_carpan,'etkin_oran',oyun.emlak_vergi_oran_il(m.il_id));
end $$;
revoke all on function public.emlak_vergi_belediye_ayarla(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayarla(numeric) to authenticated;
create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();z record;id bigint;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca görevdeki milletvekili kanun teklifi verebilir.';end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then raise exception 'Meclis Başkanı teklif veremez.';end if;
 if p_oran is null or p_oran not between 0.05 and 1.0 or p_oran<>round(p_oran,2) then raise exception 'Haftalık emlak vergi oranı %%0,05 ile %%1 arasında olmalı.';end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then raise exception 'Önce devam eden teklifin sonuçlanmalı.';end if;
 select * into z from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest','Ulusal Emlak Vergisi Düzenlemesi',format('Haftalık emlak vergisinin taban oranı %s%% olarak düzenlensin.',p_oran),
 jsonb_build_object('eylem','emlak_haftalik_baz','oran',p_oran),p.id,p.parti_id,t,t+z.gorusme,t+z.gorusme+z.oylama) returning id into id;
 perform oyun.olay('meclis',format('%s haftalık emlak vergi oranını %s%% yapmak üzere kanun teklifi verdi.',p.kad,p_oran),null,p.parti_id,t);
 return jsonb_build_object('kanun_id',id,'oran',p_oran);
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric) to authenticated;

-- Kabul edilip yayımlanan kanun, ülke genelindeki taban emlak vergisini değiştirir.
do $pl$ declare def text;old text;new_part text; begin
 def:=pg_get_functiondef('oyun.kanun_yururluk(bigint,timestamp with time zone,text)'::regprocedure);
 old:='  elsif k.tur=''butce'' then';
 new_part:='  elsif k.tur=''serbest'' and k.veri->>''eylem''=''emlak_haftalik_baz'' then
    insert into oyun.yasa_ekonomi_ayar(kod,deger,guncelleme)
    values(''emlak_haftalik_baz'',(k.veri->>''oran'')::numeric,t)
    on conflict(kod) do update set deger=excluded.deger,guncelleme=t;
    insert into oyun.bildirimler(user_id,zaman,metin)
    select id,t,format(''TBMM haftalık emlak vergisi taban oranını %s%% olarak belirledi.'',(k.veri->>''oran'')::numeric)
    from oyun.profiller where not yasakli;
' || old;
 if position('emlak_haftalik_baz' in def)=0 then
  if position(old in def)=0 then raise exception 'Kanun yürürlük eşleştirmesi bulunamadı.';end if;
  execute replace(def,old,new_part);
 end if;
end $pl$;
-- Normal kanunlarda 11 görevdeki milletvekili varsa en az 6 kabul oyu aranır.
do $pl$ declare def text; begin
 def:=pg_get_functiondef('oyun.kanun_tick(timestamp with time zone)'::regprocedure);
 if position('floor(dolu / 4.0) + 1' in def)>0 then
  execute replace(def,'floor(dolu / 4.0) + 1','floor(dolu / 2.0) + 1');
 end if;
end $pl$;
-- Her yeni dönem 600 sandalyedir, ama gerçek oyun vekilleri kadar dolu koltuk sayılır.
update oyun.ayarlar set meclis_olcek=0 where id=1 and meclis_olcek<>0;
select oyun.dagit_mv_sandalye(600);
update oyun.meclis_olcek_kayit set sandalye=600 where secim_id in
 (select id from oyun.secimler where tur='mv_on' and durum='bekliyor');
