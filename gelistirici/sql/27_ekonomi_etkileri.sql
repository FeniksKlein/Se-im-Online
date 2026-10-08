-- Mevcut sistemlere uygulanabilen ekonomik etkiler.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare m record;n int;gross numeric;tax numeric;t timestamptz:=oyun.simdi();
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
 end loop;
end $$;

create or replace function public.tahvil_al(p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();t timestamptz:=oyun.simdi();r numeric:=oyun.yasa_oran('tahvil_faiz');
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli';end if;
 if r<=0 then raise exception 'Devlet tahvili kanunu henüz yürürlükte değil.';end if;
 if p_tutar is null or p_tutar<1000 or p_tutar>10000000 or p_tutar<>round(p_tutar) then raise exception 'Tahvil tutarı 1.000–10.000.000 TL olmalı';end if;
 perform oyun.para_islem(u,-p_tutar,'tahvil','30 günlük devlet tahvili alımı',t);
 insert into oyun.devlet_tahvil(user_id,anapara,faiz,alis,vade) values(u,p_tutar,r,t,t+interval '30 days');
 update oyun.ulke set hazine=hazine+p_tutar/1000000 where id=1;
 return jsonb_build_object('tamam',true,'vade',t+interval '30 days','getiri',round(p_tutar*r/100,2));
end $$;
create or replace function public.tahvil_portfoy()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();t timestamptz:=oyun.simdi();x record;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 for x in select * from oyun.devlet_tahvil where user_id=u and not odendi and vade<=t for update loop
  perform oyun.para_islem(u,round(x.anapara*(1+x.faiz/100),2),'tahvil','Devlet tahvili anapara ve faiz ödemesi',t);
  update oyun.devlet_tahvil set odendi=true where id=x.id;
  update oyun.ulke set hazine=hazine-round(x.anapara*(1+x.faiz/100),2)/1000000 where id=1;
 end loop;
 return jsonb_build_object('tahviller',coalesce((select jsonb_agg(jsonb_build_object('tutar',anapara,'faiz',faiz,'vade',vade,'odendi',odendi)) from oyun.devlet_tahvil where user_id=u),'[]'::jsonb));
end $$;
revoke all on function public.tahvil_al(numeric),public.tahvil_portfoy() from public,anon;
grant execute on function public.tahvil_al(numeric),public.tahvil_portfoy() to authenticated;
