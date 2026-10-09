-- Emlak 81 il: sınırlı stok, bölgesel fiyat/kira, haftalık belediye vergisi.
-- Meclis: 600 sandalye, yasaların çoğunluğu görevdeki vekil sayısına bağlı.
-- Mevcut tapular, cüzdanlar ve mevcut vekiller korunur.
create table if not exists oyun.emlak_ulke_oran(
 id integer primary key check(id=1),
 haftalik_yuzde numeric(6,3) not null default 0.200 check(haftalik_yuzde between 0 and 0.8),
 guncelleme timestamptz not null default now()
);
insert into oyun.emlak_ulke_oran(id,haftalik_yuzde) values(1,0.200) on conflict(id) do nothing;
create table if not exists oyun.emlak_il_oran(
 il_id smallint primary key references oyun.iller(id),
 carpan numeric(4,2) not null default 1 check(carpan between 0.50 and 1.50),
 baskan uuid references oyun.profiller(id), zaman timestamptz not null default now()
);
alter table oyun.emlak_ulke_oran enable row level security;
alter table oyun.emlak_il_oran enable row level security;
revoke all on oyun.emlak_ulke_oran,oyun.emlak_il_oran from public,anon,authenticated;

create or replace function oyun.emlak_kapasite(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case p_tip when 'daire' then 8+round(92.0*greatest(0,i.mv-1)/95.0)::int
 when 'dukkan' then 3+round(25.0*greatest(0,i.mv-1)/95.0)::int
 when 'villa' then 2+round(18.0*greatest(0,i.mv-1)/95.0)::int else 0 end
 from oyun.iller i where i.id=p_il
$$;
create or replace function oyun.emlak_bolge_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
  * (0.70+1.10*sqrt(i.mv::numeric/96.0))
  * (0.70+coalesce(d.gelisim,50)/150.0),-2)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_bolge_kira(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round(oyun.emlak_bolge_fiyat(p_il,p_tip)*(0.020+coalesce(d.gelisim,50)/10000.0+i.mv/30000.0),2)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_efektif_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select round(coalesce((select haftalik_yuzde from oyun.emlak_ulke_oran where id=1),0.200)
  *coalesce((select carpan from oyun.emlak_il_oran where il_id=p_il),1),3)
$$;
create or replace function public.emlak_iller()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Oturum açmalısın.';end if;
 return jsonb_build_object('iller',coalesce((select jsonb_agg(jsonb_build_object(
  'id',i.id,'ad',i.ad,'nufus_olcegi',i.mv,'gelisim',d.gelisim,
  'emlak_vergi',oyun.emlak_efektif_oran(i.id),
  'fiyatlar',jsonb_build_object(
    'daire',jsonb_build_object('fiyat',oyun.emlak_bolge_fiyat(i.id,'daire'),'kira',oyun.emlak_bolge_kira(i.id,'daire'),
      'stok',oyun.emlak_kapasite(i.id,'daire'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire')),
    'dukkan',jsonb_build_object('fiyat',oyun.emlak_bolge_fiyat(i.id,'dukkan'),'kira',oyun.emlak_bolge_kira(i.id,'dukkan'),
      'stok',oyun.emlak_kapasite(i.id,'dukkan'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan')),
    'villa',jsonb_build_object('fiyat',oyun.emlak_bolge_fiyat(i.id,'villa'),'kira',oyun.emlak_bolge_kira(i.id,'villa'),
      'stok',oyun.emlak_kapasite(i.id,'villa'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa'))
  )) order by i.ad) from oyun.iller i left join oyun.il_durum d on d.il_id=i.id),'[]'::jsonb));
end $$;
revoke all on function public.emlak_iller() from public,anon;
grant execute on function public.emlak_iller() to authenticated;

create or replace function public.mulk_sehir_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric;kira numeric;t timestamptz:=oyun.simdi();mid bigint;
 cap integer;adet integer; ilad text;
begin
 if p_tip not in('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.';end if;
 select ad into ilad from oyun.iller where id=p_il;
 if ilad is null then raise exception 'Geçersiz il.';end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Geçerli oyuncu hesabı gerekli.';end if;
 -- Aynı il ve mülk türüne aynı anda satın alma yapılırsa stok aşılmasın.
 perform pg_advisory_xact_lock(97118,p_il::integer*10+
   case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 cap:=oyun.emlak_kapasite(p_il,p_tip);
 select count(*) into adet from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if adet>=cap then raise exception '% ilinde % için yeni mülk stoku tükendi (%/%). İkinci el ilanlara bak.',ilad,p_tip,adet,cap;end if;
 bedel:=oyun.emlak_bolge_fiyat(p_il,p_tip);
 kira:=oyun.emlak_bolge_kira(p_il,p_tip);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s / %s mülk satın alımı',ilad,p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into mid;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',mid,null,u,bedel,t,ilad||' '||p_tip||' mülk satın alımı');
 return jsonb_build_object('mulk_id',mid,'fiyat',bedel,'haftalik_kira',kira,'il',ilad,'stok_kalan',cap-adet-1);
end $$;
revoke all on function public.mulk_sehir_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_sehir_satin_al(text,smallint) to authenticated;

-- Eski istemciler de şehir kotasını atlamasın: tek parametreli satın alma kayıtlı şehirden satın alır.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 perform public.mulk_sehir_satin_al(p_tip,p.il_id);
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Belediye vergisi kira haftasında ve mülkün bulunduğu ilin kasasına gider.
-- Önceden edinilmiş bütün mülkler korunur. Eski çoklu mülk vergisi de aynen sürer.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric;pay numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
     and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  emlak_tax:=least(greatest(0,gross-tax),round(m.alis_bedeli*oyun.emlak_efektif_oran(m.il_id)*n/100,2));
  pay:=gross-tax-emlak_tax;
  perform oyun.para_islem(p_user,pay,'kira',
    format('Mulk #%s: %s haftalik kira, coklu vergi %s TL, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),
    t,tax+emlak_tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  if emlak_tax>0 then update oyun.il_durum set kasa=kasa+emlak_tax/1000000 where il_id=m.il_id;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
    toplam_kira=toplam_kira+pay,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;
revoke all on function oyun.mulk_kira_tahsil(uuid) from public,anon,authenticated;

-- Belediye başkanı yalnızca kendi ilinin oran çarpanını günde bir değiştirebilir.
create or replace function public.emlak_belediye_oran(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); il smallint; t timestamptz:=oyun.simdi(); son timestamptz; esk numeric;
begin
 if p_carpan is null or p_carpan not between 0.5 and 1.5 or p_carpan<>round(p_carpan,2)
 then raise exception 'Belediyenin emlak vergisi çarpanı 0,50 ile 1,50 arasında olmalı.';end if;
 select il_id into il from oyun.makamlar where user_id=u and tur='bel' and bit is null limit 1;
 if il is null then raise exception 'Yalnızca görevdeki belediye başkanı kendi ilinin emlak vergisini değiştirebilir.';end if;
 select zaman,carpan into son,esk from oyun.emlak_il_oran where il_id=il for update;
 if son is not null and son>t-interval '24 hours' then raise exception 'Emlak vergisi en fazla 24 saatte bir değiştirilebilir.';end if;
 if coalesce(esk,1)=p_carpan then raise exception 'Oranda değişiklik yok.';end if;
 insert into oyun.emlak_il_oran(il_id,carpan,baskan,zaman) values(il,p_carpan,u,t)
 on conflict(il_id) do update set carpan=excluded.carpan,baskan=excluded.baskan,zaman=excluded.zaman;
 perform oyun.olay('belediye',format('%s belediye başkanı haftalık emlak vergisini %%%s olarak ayarladı.',
  (select ad from oyun.iller where id=il),oyun.emlak_efektif_oran(il)),il,null,t);
 return jsonb_build_object('il_id',il,'carpan',p_carpan,'haftalik_yuzde',oyun.emlak_efektif_oran(il));
end $$;
revoke all on function public.emlak_belediye_oran(numeric) from public,anon;
grant execute on function public.emlak_belediye_oran(numeric) to authenticated;

-- Milletvekili, mevcut kanun işleyişiyle bütün illeri etkileyen temel emlak vergisini teklif eder.
create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();sure record;id bigint;
begin
 if not oyun.aktif_vekil(p.id) or exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null)
 then raise exception 'Bu kanun teklifini yalnızca oy hakkı olan milletvekilleri verebilir.';end if;
 if p_oran is null or p_oran not between 0 and 0.8 or p_oran<>round(p_oran,3)
 then raise exception 'Ulusal haftalık emlak vergisi %%0 ile %%0,8 arasında olmalı.';end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr'))
 then raise exception 'Sonuçlanmamış teklifin varken yeni teklif veremezsin.';end if;
 select * into sure from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest','Haftalık emlak vergisi düzenlemesi',
  format('Mülk sahiplerinin haftalık belediye emlak vergisi temel oranı %%%s olarak düzenlensin.',p_oran),
  jsonb_build_object('ozel_tur','emlak_vergi','deger',p_oran),p.id,p.parti_id,t,t+sure.gorusme,t+sure.gorusme+sure.oylama) returning id into id;
 perform oyun.olay('meclis',format('%s haftalık emlak vergisi oranı %%%s için kanun teklif etti.',p.kad,p_oran),null,p.parti_id,t);
 return jsonb_build_object('id',id,'oran',p_oran);
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric) to authenticated;

create or replace function oyun.emlak_vergi_kanun_uygula()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.durum='yururlukte' and old.durum is distinct from 'yururlukte'
    and new.veri->>'ozel_tur'='emlak_vergi' then
  update oyun.emlak_ulke_oran set haftalik_yuzde=(new.veri->>'deger')::numeric,guncelleme=oyun.simdi() where id=1;
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_yururluk on oyun.kanunlar;
create trigger emlak_vergi_kanun_yururluk after update of durum on oyun.kanunlar
for each row execute function oyun.emlak_vergi_kanun_uygula();

-- 81 ilin özgün 600 sandalyesi korunur, otomatik nüfus-oyuncu ölçekleme kapatılır.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
