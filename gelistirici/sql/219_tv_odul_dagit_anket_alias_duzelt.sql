CREATE OR REPLACE FUNCTION oyun.tv_odul_dagit(p_program bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t timestamptz:=oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; r record;
 sira integer:=0; pay numeric; bugun numeric; hafta numeric; kanal_hafta numeric;
 ver numeric; kalan numeric; odenen numeric:=0; ilk text; v_open_anket record;
 soru_sayisi integer:=0; katilimci integer:=0; aciklama text:='Ödül şartları sağlanmadı';
begin
 select * into pr from oyun.tv_program where id=p_program for update;
 if pr.id is null or pr.odul_dagitildi or pr.durum not in ('bitti','iptal') then return; end if;
 for v_open_anket in select id from oyun.tv_anket where program_id=pr.id and not kapandi loop
  perform oyun.tv_anket_kapat_ic(v_open_anket.id);
 end loop;
 select * into k from oyun.tv_kanal where id=pr.kanal_id for update;
 kalan:=greatest(0,coalesce(pr.odul,0));
 select count(*) into soru_sayisi from oyun.tv_anket a
 where a.program_id=pr.id and a.tur='yarisma' and a.kapandi and a.havuz_soru_id is not null;
 select count(distinct o.user_id) into katilimci
 from oyun.tv_anket_oy o join oyun.tv_anket q on q.id=o.anket_id
 join oyun.profiller pp on pp.id=o.user_id
 where q.program_id=pr.id and q.tur='yarisma' and q.kapandi and q.havuz_soru_id is not null
   and pp.olusturma<=t-interval '24 hours' and not pp.yasakli
   and o.user_id<>k.sahip and o.user_id<>pr.sunucu
   and not exists(select 1 from oyun.tv_konuk x where x.program_id=pr.id and x.user_id=o.user_id and x.durum='kabul')
   and not exists(select 1 from oyun.tv_sunucu x where x.kanal_id=k.id and x.user_id=o.user_id and x.durum='aktif');
 if kalan>0 and pr.durum='bitti' and pr.tur='yarisma' and soru_sayisi>=5 and katilimci>=5 then
  aciklama:='En az 5 havuz sorusu ve 5 bağımsız katılımcı doğrulandı';
  for r in
   select o.user_id,sum(o.puan)::int puan,min(o.zaman) ilk_cevap
   from oyun.tv_anket_oy o join oyun.tv_anket q on q.id=o.anket_id
   join oyun.profiller pp on pp.id=o.user_id
   where q.program_id=pr.id and q.tur='yarisma' and q.kapandi and q.havuz_soru_id is not null
     and pp.olusturma<=t-interval '24 hours' and not pp.yasakli
     and o.user_id<>k.sahip and o.user_id<>pr.sunucu
     and not exists(select 1 from oyun.tv_konuk x where x.program_id=pr.id and x.user_id=o.user_id and x.durum='kabul')
     and not exists(select 1 from oyun.tv_sunucu x where x.kanal_id=k.id and x.user_id=o.user_id and x.durum='aktif')
   group by o.user_id having count(distinct o.anket_id)>=3 and sum(o.puan)>0
   order by sum(o.puan) desc,min(o.zaman) limit 100
  loop
   if sira>=3 then exit; end if;
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(r.user_id::text,2026));
   if exists(select 1 from oyun.tv_odul_kazanc z join oyun.tv_program pp on pp.id=z.program_id
       where z.user_id=r.user_id and z.tutar>0 and pp.kanal_id=k.id and z.zaman>t-interval '7 days')
    then continue; end if;
   if (select count(*) from oyun.tv_odul_kazanc z
       where z.user_id=r.user_id and z.tutar>0 and z.zaman>t-interval '7 days')>=2
    then continue; end if;
   select coalesce(sum(z.tutar),0) into bugun from oyun.tv_odul_kazanc z
    where z.user_id=r.user_id and (z.zaman at time zone 'Europe/Istanbul')::date=(t at time zone 'Europe/Istanbul')::date;
   select coalesce(sum(z.tutar),0) into hafta from oyun.tv_odul_kazanc z
    where z.user_id=r.user_id and z.tutar>0 and z.zaman>t-interval '7 days';
   select coalesce(sum(z.tutar),0) into kanal_hafta from oyun.tv_odul_kazanc z
    join oyun.tv_program kp on kp.id=z.program_id
    where kp.kanal_id=k.id and z.tutar>0 and z.zaman>t-interval '7 days';
   pay:=round(pr.odul*case sira when 0 then 0.5 when 1 then 0.3 else 0.2 end);
   ver:=least(pay,greatest(0,50000-bugun),greatest(0,100000-hafta),greatest(0,250000-kanal_hafta),kalan);
   if ver<1000 then continue; end if;
   sira:=sira+1;
   insert into oyun.tv_odul_kazanc(program_id,user_id,sira,puan,tutar,zaman)
   values(pr.id,r.user_id,sira,r.puan,ver,t);
   perform oyun.para_islem(r.user_id,ver,'odul',format('%s · "%s" doğrulanmış bilgi yarışması %s.liği',k.ad,pr.baslik,sira),t);
   odenen:=odenen+ver; kalan:=kalan-ver;
   perform oyun.bildir(r.user_id,format('%s · "%s" bilgi yarışmasında %s. oldun (%s puan): %s ₺ ödül cüzdanına geçti.',k.ad,pr.baslik,sira,r.puan,oyun.tl(ver)),t);
   if sira=1 then ilk:=oyun.kad(r.user_id)||' ('||r.puan||' puan)'; end if;
  end loop;
  if ilk is not null then
   perform oyun.olay('basin',format('%s · "%s" bilgi yarışmasının birincisi %s; dağıtılan ödül %s ₺.',k.ad,pr.baslik,ilk,oyun.tl(odenen)),null,null,t);
  end if;
 end if;
 if pr.durum='iptal' then aciklama:='Program iptal edildi'; end if;
 if kalan>0 then
  update oyun.tv_kanal set kasa=kasa+kalan where id=k.id;
  insert into oyun.tv_hareket(kanal_id,zaman,tutar,tur,aciklama)
  values(k.id,t,kalan,'odul_iade',format('"%s" · dağıtılmayan veya güvenlik şartlarını sağlamayan yarışma ödülü iade edildi',pr.baslik));
 end if;
 insert into oyun.tv_odul_denetim(program_id,kanal_id,durum,gecerli_soru,gecerli_katilimci,odul_havuzu,odenen,iade,aciklama,kayit)
 values(pr.id,k.id,case when odenen>0 then 'odendi' else 'iade' end,soru_sayisi,katilimci,pr.odul,odenen,kalan,aciklama,t)
 on conflict(program_id) do nothing;
 update oyun.tv_program set odul_dagitildi=true where id=pr.id;
end $function$
