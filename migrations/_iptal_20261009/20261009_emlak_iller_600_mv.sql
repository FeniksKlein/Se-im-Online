-- 2026-10-09: regional property stock, city prices, municipal property tax, 600 seats.
-- Keeps existing properties, titles and active MPs intact.
create table if not exists oyun.emlak_il_vergisi (
 il_id smallint primary key references oyun.iller(id),
 oran numeric not null check (oran between 0 and 1),
 baskan uuid references oyun.profiller(id),
 guncelleme timestamptz not null default now()
);
create table if not exists oyun.emlak_ulusal_vergisi (
 id integer primary key default 1 check(id=1),
 oran numeric not null check(oran between 0 and 1),
 kanun_id bigint references oyun.kanunlar(id),
 guncelleme timestamptz not null default now()
);
insert into oyun.emlak_ulusal_vergisi(id,oran) values(1,0.1) on conflict(id) do nothing;
alter table oyun.emlak_il_vergisi enable row level security;
alter table oyun.emlak_ulusal_vergisi enable row level security;
revoke all on oyun.emlak_il_vergisi,oyun.emlak_ulusal_vergisi from public,anon,authenticated;

create or replace function oyun.emlak_sehir_kapasite(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case p_tip when 'daire' then 8+floor(92*(i.mv::numeric-(select min(mv) from oyun.iller))/greatest(1,(select max(mv)-min(mv) from oyun.iller)))::int
 when 'dukkan' then 3+floor(37*(i.mv::numeric-(select min(mv) from oyun.iller))/greatest(1,(select max(mv)-min(mv) from oyun.iller)))::int
 when 'villa' then 2+floor(18*(i.mv::numeric-(select min(mv) from oyun.iller))/greatest(1,(select max(mv)-min(mv) from oyun.iller)))::int end
 from oyun.iller i where i.id=p_il
$$;
create or replace function oyun.emlak_sehir_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
  * (0.65+1.35*(i.mv::numeric-(select min(mv) from oyun.iller))/greatest(1,(select max(mv)-min(mv) from oyun.iller)))
  * (0.8+coalesce(d.gelisim,50)/250.0),-3)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_vergi_orani(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select coalesce((select oran from oyun.emlak_il_vergisi where il_id=p_il),
                (select oran from oyun.emlak_ulusal_vergisi where id=1),0.1)
$$;

create or replace function public.emlak_iller()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'gelisim',round(d.gelisim,1),
 'vergi',oyun.emlak_vergi_orani(i.id),
 'daire',jsonb_build_object('fiyat',oyun.emlak_sehir_fiyat(i.id,'daire'),'haftalik',round(oyun.emlak_sehir_fiyat(i.id,'daire')*.025),
     'stok',greatest(0,oyun.emlak_sehir_kapasite(i.id,'daire')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire')),
     'kapasite',oyun.emlak_sehir_kapasite(i.id,'daire')),
 'dukkan',jsonb_build_object('fiyat',oyun.emlak_sehir_fiyat(i.id,'dukkan'),'haftalik',round(oyun.emlak_sehir_fiyat(i.id,'dukkan')*.025),
     'stok',greatest(0,oyun.emlak_sehir_kapasite(i.id,'dukkan')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan')),
     'kapasite',oyun.emlak_sehir_kapasite(i.id,'dukkan')),
 'villa',jsonb_build_object('fiyat',oyun.emlak_sehir_fiyat(i.id,'villa'),'haftalik',round(oyun.emlak_sehir_fiyat(i.id,'villa')*.025),
     'stok',greatest(0,oyun.emlak_sehir_kapasite(i.id,'villa')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa')),
     'kapasite',oyun.emlak_sehir_kapasite(i.id,'villa')))
 order by i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_iller() from public,anon;
grant execute on function public.emlak_iller() to authenticated;

create or replace function public.mulk_il_satin_al(p_il smallint,p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric; t timestamptz:=oyun.simdi(); yeni bigint; kapasite int;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Oyuncu hesabı geçerli değil.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl bulunamadı.'; end if;
 perform pg_advisory_xact_lock(711008,p_il::int);
 kapasite:=oyun.emlak_sehir_kapasite(p_il,p_tip);
 if (select count(*) from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip)>=kapasite then
  raise exception 'Bu ilde % stoğu tükendi. Başka bir il seç veya oyuncuların satılık ilanlarına bak.',p_tip;
 end if;
 bedel:=oyun.emlak_sehir_fiyat(p_il,p_tip);kira:=round(bedel*.025,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s alındı',(select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' il bazlı devlet gayrimenkul alımı');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_il_satin_al(smallint,text) from public,anon;
grant execute on function public.mulk_il_satin_al(smallint,text) to authenticated;

-- Former endpoint remains compatible but now enforces stock and local prices.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_il_satin_al(p.il_id,p_tip);
end $$;

-- Weekly municipal property tax charged on due rent cycles, sourced from the property's acquisition price.
-- A late collection processes all due weeks exactly once.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
     then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  emlak_tax:=least(greatest(0,gross-tax),round(m.alis_bedeli*oyun.emlak_vergi_orani(m.il_id)/100*n,2));
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',format('Mulk #%s: %s haftalik kira, devlet vergisi %s, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),t,tax+emlak_tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  if emlak_tax>0 then update oyun.il_durum set kasa=kasa+emlak_tax/1000000 where il_id=m.il_id;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

-- Direct local tax authority: only the sitting mayor, with a 24-hour cooldown.
create or replace function public.belediye_emlak_vergisi(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); il smallint; t timestamptz:=oyun.simdi(); last_change timestamptz;
begin
 select il_id into il from oyun.makamlar where user_id=u and tur='bel' and bit is null limit 1;
 if il is null then raise exception 'Yalnızca görevdeki belediye başkanı bu il için oran belirleyebilir.'; end if;
 if p_oran is null or p_oran<0 or p_oran>1 or p_oran<>round(p_oran,2) then raise exception 'Haftalık oran %%0–%%1 arasında, iki ondalıklı olmalı.'; end if;
 select guncelleme into last_change from oyun.emlak_il_vergisi where il_id=il;
 if last_change>t-interval '24 hours' then raise exception 'Emlak vergisi en fazla 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_il_vergisi(il_id,oran,baskan,guncelleme) values(il,p_oran,u,t)
 on conflict(il_id) do update set oran=excluded.oran,baskan=excluded.baskan,guncelleme=excluded.guncelleme;
 perform oyun.olay('belediye',format('%s Belediyesi haftalık emlak vergisini %s%% olarak belirledi.',(select ad from oyun.iller where id=il),p_oran),il,null,t);
 return jsonb_build_object('il_id',il,'oran',p_oran);
end $$;
revoke all on function public.belediye_emlak_vergisi(numeric) from public,anon;
grant execute on function public.belediye_emlak_vergisi(numeric) to authenticated;

-- Legal majority for ordinary legislation is a majority of actually seated MPs, not nominal 600.
-- Constitutional procedures keep their own existing fractions.
create or replace function oyun.meclis_olcek_hesap(t timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('aktif',(select count(*) from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days'),
 'sandalye',600,'anayasal',600,'olcek',0)
$$;
update oyun.ayarlar set meclis_olcek=0 where id=1;
update oyun.anayasa set deger=600 where kod='milletvekili_sayisi' and deger<>600;
select oyun.dagit_mv_sandalye(600);

-- Existing law mechanism uses active legislators for quorum.
-- Ordinary laws now require floor(active/2)+1 affirmative votes.
create or replace function oyun.kanun_karar_yeter()
returns integer language sql stable set search_path='' as $$
 select floor(oyun.dolu_sandalye()/2.0)::int+1
$$;
