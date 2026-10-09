-- 2026-10-09: İl bazlı sınırlı emlak, belediye emlak vergisi, 600 TBMM sandalyesi.
-- Var olan mülkler, oyuncular, paralar, kanunlar ve makamlar silinmez.
create table if not exists oyun.emlak_il_stok(
 il_id smallint primary key references oyun.iller(id),
 daire_limit integer not null check(daire_limit>0),
 dukkan_limit integer not null check(dukkan_limit>0),
 villa_limit integer not null check(villa_limit>0),
 fiyat_carpan numeric not null check(fiyat_carpan>0)
);
insert into oyun.emlak_il_stok(il_id,daire_limit,dukkan_limit,villa_limit,fiyat_carpan)
 select i.id,
  8 + round(92*greatest(0,i.mv-1)::numeric/95)::int,
  2 + round(38*greatest(0,i.mv-1)::numeric/95)::int,
  1 + round(24*greatest(0,i.mv-1)::numeric/95)::int,
  round(greatest(.65,least(1.8,.78+greatest(0,i.mv-1)*.008+(coalesce(d.gelisim,50)-50)*.004)),3)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
on conflict(il_id) do nothing;
create table if not exists oyun.emlak_vergi_ulke(
 id integer primary key check(id=1),
 oran numeric not null default 0.2 check(oran between 0 and 1),
 karar_at timestamptz not null default now()
);
insert into oyun.emlak_vergi_ulke(id,oran) values (1,0.2) on conflict do nothing;
create table if not exists oyun.emlak_vergi_il(
 il_id smallint primary key references oyun.iller(id),
 fark numeric not null default 0 check(fark between -1 and 1),
 degistirme timestamptz,
 karar_veren uuid references oyun.profiller(id)
);
create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 il_id smallint not null references oyun.iller(id),
 user_id uuid not null references oyun.profiller(id),
 hafta_sayisi integer not null check(hafta_sayisi>0),
 tutar numeric not null check(tutar>=0),
 oran numeric not null,
 tahsil timestamptz not null
);
create index if not exists emlak_vergi_mulk on oyun.emlak_vergi_kayit(mulk_id,tahsil);
alter table oyun.emlak_vergi_kayit enable row level security;
revoke all on oyun.emlak_vergi_kayit from public,anon,authenticated;

create or replace function oyun.emlak_vergi_orani(p_il smallint) returns numeric
language sql stable set search_path='' as $$
 select greatest(0,least(1,(select oran from oyun.emlak_vergi_ulke where id=1)
   + coalesce((select fark from oyun.emlak_vergi_il where il_id=p_il),0)))
$$;
create or replace function oyun.emlak_bedel(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
     * s.fiyat_carpan * greatest(.8,least(1.2,1+(coalesce(d.gelisim,50)-50)*.003)))
 from oyun.emlak_il_stok s left join oyun.il_durum d on d.il_id=s.il_id where s.il_id=p_il
$$;
create or replace function oyun.emlak_kira(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round(oyun.emlak_bedel(p_il,p_tip) *
   greatest(.018,least(.031,.024 + (coalesce((select gelisim from oyun.il_durum where il_id=p_il),50)-50)*.00007)),2)
$$;
create or replace function oyun.emlak_stok(p_il smallint,p_tip text) returns integer
language sql stable set search_path='' as $$
 select case p_tip when 'daire' then daire_limit when 'dukkan' then dukkan_limit when 'villa' then villa_limit end
 from oyun.emlak_il_stok where il_id=p_il
$$;
create or replace function public.emlak_iller()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',i.id,'il',i.ad,'gelisim',coalesce(d.gelisim,50),
   'vergi_oran',oyun.emlak_vergi_orani(i.id),
   'daire',jsonb_build_object('limit',s.daire_limit,'kalan',greatest(0,s.daire_limit-coalesce(a.daire,0)),
     'bedel',oyun.emlak_bedel(i.id,'daire'),'kira',oyun.emlak_kira(i.id,'daire')),
   'dukkan',jsonb_build_object('limit',s.dukkan_limit,'kalan',greatest(0,s.dukkan_limit-coalesce(a.dukkan,0)),
     'bedel',oyun.emlak_bedel(i.id,'dukkan'),'kira',oyun.emlak_kira(i.id,'dukkan')),
   'villa',jsonb_build_object('limit',s.villa_limit,'kalan',greatest(0,s.villa_limit-coalesce(a.villa,0)),
     'bedel',oyun.emlak_bedel(i.id,'villa'),'kira',oyun.emlak_kira(i.id,'villa')))
 order by i.ad)
 from oyun.iller i join oyun.emlak_il_stok s on s.il_id=i.id
 left join oyun.il_durum d on d.il_id=i.id
 left join lateral (select count(*) filter(where m.tip='daire') daire,
   count(*) filter(where m.tip='dukkan') dukkan,count(*) filter(where m.tip='villa') villa
   from oyun.yatirim_mulkleri m where m.il_id=i.id) a on true),'[]'::jsonb);
end $$;
revoke all on function public.emlak_iller() from public,anon;
grant execute on function public.emlak_iller() to authenticated;

create or replace function public.mulk_satin_al_il(p_il smallint,p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();bedel numeric;kira numeric;
 sayi int;stok int;id_yeni bigint; sehir text;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then
  raise exception 'Aktif oyuncu profili gerekli.'; end if;
 if p_tip is null or p_tip not in ('daire','dukkan','villa') then raise exception 'Geçersiz mülk türü.'; end if;
 select ad into sehir from oyun.iller where id=p_il for update;
 if sehir is null then raise exception 'Geçersiz il.'; end if;
 stok:=oyun.emlak_stok(p_il,p_tip);
 if stok is null then raise exception 'İlin emlak kontenjanı bulunmuyor.'; end if;
 select count(*) into sayi from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if sayi>=stok then raise exception '% ilinde % için satılabilir yeni mülk tükendi (%/%).',sehir,p_tip,sayi,stok; end if;
 bedel:=oyun.emlak_bedel(p_il,p_tip);
 kira:=oyun.emlak_kira(p_il,p_tip);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s satın alındı',sehir,p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into id_yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',id_yeni,null,u,bedel,t,sehir||' '||p_tip||' devlet gayrimenkul alimi');
 return jsonb_build_object('mulk_id',id_yeni,'il',sehir,'tutar',bedel,'kira',kira);
end $$;
revoke all on function public.mulk_satin_al_il(smallint,text) from public,anon;
grant execute on function public.mulk_satin_al_il(smallint,text) to authenticated;
-- Legacy endpoint also enforces city stock; existing players do not bypass a limit.
create or replace function public.mulk_satin_al(p_tip text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 if il is null then raise exception 'Profil şehrini seç.'; end if;
 perform public.mulk_satin_al_il(il,p_tip);
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Tax is withheld from weekly rental earnings and belongs to the property's city.
-- Existing separate multiple-property treasury tax is preserved.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric;
 rate numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
      and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
      then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  rate:=oyun.emlak_vergi_orani(m.il_id);
  emlak_tax:=least(greatest(0,gross-tax),round(m.alis_bedeli*rate/100*n,2));
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',
     format('Mülk #%s: %s haftalık kira, gelir vergisi %s ₺, belediye emlak vergisi %s ₺',
     m.id,n,tax,emlak_tax),t,tax+emlak_tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1; end if;
  if emlak_tax>0 then
   update oyun.il_durum set kasa=kasa+emlak_tax/1000000000.0 where il_id=m.il_id;
   insert into oyun.emlak_vergi_kayit(mulk_id,il_id,user_id,hafta_sayisi,tutar,oran,tahsil)
    values(m.id,m.il_id,p_user,n,emlak_tax,rate,t);
  end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
    toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

create or replace function public.emlak_vergi_belediye(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar:=oyun.baskan_zorunlu(p);
 eski oyun.emlak_vergi_il; ulke_oran numeric; t timestamptz:=oyun.simdi();
begin
 ulke_oran:=(select oran from oyun.emlak_vergi_ulke where id=1);
 if p_oran is null or p_oran<>round(p_oran,2) or p_oran<0 or p_oran>1 then
  raise exception 'Haftalık emlak vergisi %%0 ile %%1 arasında, en fazla iki ondalık haneli olmalı.'; end if;
 select * into eski from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if eski.degistirme>t-interval '24 hours' then raise exception 'Belediye emlak vergisini 24 saatte bir değiştirebilir.'; end if;
 if eski.il_id is not null and oyun.emlak_vergi_orani(m.il_id)=p_oran then raise exception 'Bu oran zaten geçerli.'; end if;
 insert into oyun.emlak_vergi_il(il_id,fark,degistirme,karar_veren)
 values(m.il_id,p_oran-ulke_oran,t,p.id)
 on conflict(il_id) do update set fark=excluded.fark,degistirme=t,karar_veren=p.id;
 perform oyun.olay('belediye',format('%s Belediyesi haftalık emlak vergisini %s%% olarak belirledi.',
   (select ad from oyun.iller where id=m.il_id),p_oran),m.il_id,p.parti_id,t);
 return jsonb_build_object('il',m.il_id,'oran',p_oran);
end $$;
revoke all on function public.emlak_vergi_belediye(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye(numeric) to authenticated;

create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();s record; k bigint;gerekce text;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Bu kanunu yalnızca aktif milletvekili teklif edebilir.'; end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then raise exception 'Meclis Başkanı teklif veremez.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
   raise exception 'Devam eden kanun teklifin var.'; end if;
 if p_oran is null or p_oran<>round(p_oran,2) or p_oran not between 0 and 1 then
   raise exception 'Emlak vergisi %%0–%%1 arasında olmalı.'; end if;
 gerekce:=oyun.metin_temizle(p_gerekce,3000);
 if length(gerekce)<10 then raise exception 'Gerekçe en az 10 karakter olmalı.'; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',format('Haftalık Emlak Vergisi Oranı %% %s',p_oran),gerekce,
   jsonb_build_object('ozel_tur','emlak_vergi','oran',p_oran),p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama)
 returning id into k;
 insert into oyun.bildirimler(user_id,zaman,metin)
 select m.user_id,t,format('Yeni emlak vergisi kanunu teklifi: %s%%. Oylamada oyunu kullan.',p_oran)
 from oyun.makamlar m where m.tur='mv' and m.bit is null and m.user_id<>p.id;
 perform oyun.olay('meclis',format('%s emlak vergisi için %s%% oran teklif etti.',p.kad,p_oran),null,p.parti_id,t);
 return jsonb_build_object('id',k,'oran',p_oran);
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text) to authenticated;

-- When the normal legislative vote/enactment process completes, activate the law.
create or replace function oyun.emlak_vergi_kanun_yururluk_trigger()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.durum='yururlukte' and old.durum is distinct from new.durum
  and new.tur='serbest' and new.veri->>'ozel_tur'='emlak_vergi' then
   if (new.veri->>'oran')::numeric not between 0 and 1 then
    raise exception 'Emlak vergisi kanunu oranı geçersiz.'; end if;
   update oyun.emlak_vergi_ulke set oran=(new.veri->>'oran')::numeric,karar_at=oyun.simdi() where id=1;
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_uygulama on oyun.kanunlar;
create trigger emlak_vergi_kanun_uygulama after update of durum on oyun.kanunlar
 for each row execute function oyun.emlak_vergi_kanun_yururluk_trigger();

-- 600 constitutional seats; law quorum based on members actually serving.
update oyun.ayarlar set meclis_olcek=0 where id=1;
update oyun.anayasa set deger=600 where kod='milletvekili_sayisi';
select oyun.dagit_mv_sandalye(600);
do $d$
declare def text;
 old_expr text:='c.kabul + c.ret + c.cekimser >= ceil(dolu / 3.0) and c.kabul > c.ret and c.kabul >= floor(dolu / 4.0) + 1';
 new_expr text:='c.kabul >= floor(dolu / 2.0) + 1';
begin
 select pg_get_functiondef(p.oid) into def from pg_proc p
 join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='oyun' and p.proname='kanun_tick';
 if def is null or strpos(def,old_expr)=0 then
  if def is not null and strpos(def,new_expr)>0 then return; end if;
  raise exception 'Kanun sayımı kaynak kodu beklenenden farklı; değiştirilmedi.';
 end if;
 def:=replace(def,old_expr,new_expr);
 def:=replace(def,'floor(dolu / 4.0) + 1','floor(dolu / 2.0) + 1');
 execute def;
end $d$;
