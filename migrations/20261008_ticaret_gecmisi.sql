-- Alıcı / satıcı arasındaki kesinleşmiş devirlerin denetlenebilir geçmişi.
-- Satış ilanı, şirket hissesi teklifi ve devlet mülk satın alma yollarına bağlanır.
create table if not exists oyun.ticaret_devir_kayit (
 id bigint generated always as identity primary key,
 tur text not null check(tur in ('mulk_devlet','sirket_tam')),
 varlik_id bigint not null,
 satici uuid references auth.users(id),
 alici uuid not null references auth.users(id),
 bedel numeric(20,2) not null check(bedel>=0),
 pay numeric check(pay is null or (pay>0 and pay<=100)),
 zaman timestamptz not null default now(),
 aciklama text
);
create index if not exists ticaret_devir_alici_idx on oyun.ticaret_devir_kayit(alici,zaman desc);
create index if not exists ticaret_devir_satici_idx on oyun.ticaret_devir_kayit(satici,zaman desc);
alter table oyun.ticaret_devir_kayit enable row level security;
revoke all on oyun.ticaret_devir_kayit from public,anon,authenticated;
alter table oyun.sirket_teklif add column if not exists kabul_zamani timestamptz;

CREATE OR REPLACE FUNCTION public.mulk_satin_al(p_tip text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric; t timestamptz:=oyun.simdi(); yeni_mulk_id bigint;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü'; end if;
 bedel:=case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end;
 kira:=round(bedel*0.025,2); -- %2,5 / hafta: sabit emlak kira dengesi
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s satın alındı',p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p.il_id,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni_mulk_id;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni_mulk_id,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $function$
;

CREATE OR REPLACE FUNCTION public.sirket_satilik_al(p_sirket bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;oldowner uuid;t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(98763,hashtext(p_sirket::text));
 select * into s from oyun.sirketler where id=p_sirket and aktif and satilik is not null for update;
 if s.id is null then raise exception 'Satis ilani bulunamadi';end if;
 select user_id into oldowner from oyun.sirket_ortaklari where sirket_id=p_sirket and pay=100 for update;
 if oldowner is null or oldowner=u then raise exception 'Satis uygun degil';end if;
 perform oyun.sirket_hesapla(p_sirket);
 perform oyun.para_islem(u,-s.satilik,'sirket','Sirket satin alimi',t);
 perform oyun.para_islem(oldowner,s.satilik,'sirket','Sirket satis geliri',t);
 delete from oyun.sirket_ortaklari where sirket_id=p_sirket;
 insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(p_sirket,u,100);
 update oyun.sirketler set satilik=null where id=p_sirket;
 update oyun.sirket_teklif set durum='iptal' where sirket_id=p_sirket and durum='bekliyor';
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,pay,zaman,aciklama)
 values('sirket_tam',p_sirket,oldowner,u,s.satilik,100,t,'Sirketin tamami devredildi');
 return jsonb_build_object('tamam',true);
end $function$
;

CREATE OR REPLACE FUNCTION public.sirket_pay_kabul(p_teklif bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid();o oyun.sirket_teklif;ownpay numeric;t timestamptz:=oyun.simdi();
begin
 select * into o from oyun.sirket_teklif where id=p_teklif for update;
 if o.alici is distinct from u or o.durum<>'bekliyor' then raise exception 'Teklif bulunamadi';end if;
 perform pg_advisory_xact_lock(98763,hashtext(o.sirket_id::text));
 select pay into ownpay from oyun.sirket_ortaklari where sirket_id=o.sirket_id and user_id=o.satici for update;
 if ownpay is null or ownpay<o.pay then raise exception 'Saticinin payi yetersiz';end if;
 perform oyun.para_islem(u,-o.bedel,'sirket','Sirket payi satin alimi',t);
 perform oyun.para_islem(o.satici,o.bedel,'sirket','Sirket payi satisi',t);
 update oyun.sirket_ortaklari set pay=pay-o.pay where sirket_id=o.sirket_id and user_id=o.satici;
 delete from oyun.sirket_ortaklari where sirket_id=o.sirket_id and user_id=o.satici and pay=0;
 insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values(o.sirket_id,u,o.pay)
 on conflict(sirket_id,user_id) do update set pay=oyun.sirket_ortaklari.pay+excluded.pay;
 update oyun.sirket_teklif set durum='kabul',kabul_zamani=t where id=p_teklif;
 update oyun.sirketler set satilik=null where id=o.sirket_id;
 update oyun.sirket_teklif set durum='iptal' where sirket_id=o.sirket_id and satici=o.satici and durum='bekliyor' and id<>p_teklif;
 return jsonb_build_object('tamam',true);
end $function$
;

create or replace function public.ticaret_gecmisim()
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid := auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('kayitlar',coalesce((
 with devirler as (
  select 'mulk_oyuncu'::text as tur,a.mulk_id::bigint as varlik_id,
   case m.tip when 'daire' then 'Daire' when 'dukkan' then 'Dükkan'
    when 'villa' then 'Villa' else initcap(m.tip) end||' #'||a.mulk_id
     ||' · '||coalesce(i.ad,'') as varlik,
   null::numeric as pay,a.fiyat as bedel,
   a.satici,a.alici,a.kapanma as zaman,
   'mulk_ilan'::text as kaynak, a.id::bigint as kaynak_id
  from oyun.mulk_ilan a
  join oyun.yatirim_mulkleri m on m.id=a.mulk_id
  left join oyun.iller i on i.id=m.il_id
  where a.durum='satildi' and a.alici is not null
     and a.kapanma is not null and (a.satici=u or a.alici=u)
  union all
  select 'sirket_hisse'::text,st.sirket_id::bigint,
   'Şirket hissesi · '||coalesce(s.ad,'#'||st.sirket_id),
   st.pay,st.bedel,st.satici,st.alici,coalesce(st.kabul_zamani,st.zaman),
   'sirket_teklif'::text,st.id::bigint
  from oyun.sirket_teklif st
  left join oyun.sirketler s on s.id=st.sirket_id
  where st.durum='kabul' and (st.satici=u or st.alici=u)
  union all
  select t.tur,t.varlik_id,
   case when t.tur='sirket_tam'
       then 'Şirket · '||coalesce(s.ad,'#'||t.varlik_id)
     else case m.tip when 'daire' then 'Daire' when 'dukkan' then 'Dükkan'
       when 'villa' then 'Villa' else coalesce(initcap(m.tip),'Gayrimenkul') end
       ||' #'||t.varlik_id||' · '||coalesce(i.ad,'')
     end,
   t.pay,t.bedel,t.satici,t.alici,t.zaman,'ticaret_devir'::text,t.id
  from oyun.ticaret_devir_kayit t
  left join oyun.sirketler s on t.tur='sirket_tam' and s.id=t.varlik_id
  left join oyun.yatirim_mulkleri m on t.tur='mulk_devlet' and m.id=t.varlik_id
  left join oyun.iller i on i.id=m.il_id
  where t.satici=u or t.alici=u
 )
 select jsonb_agg(jsonb_build_object(
  'tur',d.tur,'varlik',d.varlik,'varlik_id',d.varlik_id,'pay',d.pay,
  'bedel',d.bedel,'satici',case when d.satici is null then 'Devlet'
    else coalesce(ps.kad,'Oyuncu (kayıt yok)') end,
  'alici',coalesce(pa.kad,'Oyuncu (kayıt yok)'),
  'benim_rolum',case when d.alici=u then 'alici' else 'satici' end,
  'tarih',d.zaman,'kaynak',d.kaynak,'kaynak_id',d.kaynak_id
 ) order by d.zaman desc,d.kaynak_id desc)
 from (select * from devirler where zaman is not null order by zaman desc,kaynak_id desc limit 100) d
 left join oyun.profiller ps on ps.id=d.satici
 left join oyun.profiller pa on pa.id=d.alici
 ),'[]'::jsonb));
end $function$;
revoke all on function public.ticaret_gecmisim() from public,anon;
grant execute on function public.ticaret_gecmisim() to authenticated;
