-- Yeni dönemlerde gelir/gider ve dağıtılan kâr ayrı tutulur.
-- Geçmiş hareketlerin olmayan gelir/gider ayrıntısı uydurulmaz.
alter table oyun.sirket_hareket add column if not exists faaliyet_gelir numeric;
alter table oyun.sirket_hareket add column if not exists faaliyet_gider numeric;
alter table oyun.sirket_hareket add column if not exists dagitilan_kar numeric;

CREATE OR REPLACE FUNCTION oyun.sirket_hesapla(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()*.8),2);
  cost:=round(s.sermaye*(.025+random()*.055)+w*(.5+random()),2);
  net:=income-cost;
  distributed:=0;
  -- Zararda sirket kasasi erir. Karda dagitilabilir para ortaklara aktarilir.
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributed:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    perform oyun.para_islem(x.user_id,round(distributed*x.pay/100,2),'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$
;


create or replace function public.sirket_finans_ozeti(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare uid uuid:=auth.uid(); s oyun.sirketler;w numeric;r numeric;
 gelir_min numeric;gelir_max numeric;gider_min numeric;gider_max numeric;
begin
 if uid is null then raise exception 'Oturum açmalısın';end if;
 if not exists(select 1 from oyun.sirket_ortaklari
   where sirket_id=p_sirket and user_id=uid and pay>0)
 then raise exception 'Bu şirketin ortağı değilsin';end if;
 perform oyun.sirket_hesapla(p_sirket);
 select * into s from oyun.sirketler where id=p_sirket and aktif;
 if not found then raise exception 'Şirket bulunamadı';end if;
 select asgari into w from oyun.ulke where id=1;
 r:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15
 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18
 when 'medya' then .16 else .08 end;
 gelir_min:=round(s.sermaye*r*.6);
 gelir_max:=round(s.sermaye*r*1.4);
 gider_min:=round(s.sermaye*.025+w*.5);
 gider_max:=round(s.sermaye*.08+w*1.5);
 return jsonb_build_object(
 'id',s.id,'ad',s.ad,'sektor',s.sektor,'sermaye',s.sermaye,'kasa',s.kasa,
 'benim_payim',(select pay from oyun.sirket_ortaklari where sirket_id=s.id and user_id=uid),
 'sonraki_hesaplama',s.sonraki_kazanc,
 'tahmini_gelir_min',gelir_min,'tahmini_gelir_max',gelir_max,
 'tahmini_gider_min',gider_min,'tahmini_gider_max',gider_max,
 'tahmini_net_min',gelir_min-gider_max,'tahmini_net_max',gelir_max-gider_min,
 'tahmini_ortalama_net',round(s.sermaye*r-s.sermaye*.0525-w),
 'dagitilabilir_kar',greatest(0,s.kasa-s.sermaye-coalesce((
 select sum(round(m.anapara*(1+m.faiz/100)))
 from oyun.banka_mevduat m where m.banka_id=s.id and not m.kapandi),0)),
 'islemler',coalesce((
 select jsonb_agg(jsonb_build_object(
  'tarih',h.zaman,'net',h.tutar,'faaliyet_gelir',h.faaliyet_gelir,
  'faaliyet_gider',h.faaliyet_gider,'dagitilan_kar',h.dagitilan_kar,
  'aciklama',h.aciklama) order by h.zaman desc,h.id desc)
 from (select * from oyun.sirket_hareket
  where sirket_id=s.id order by zaman desc,id desc limit 12) h
 ),'[]'::jsonb));
end $f$;
revoke all on function public.sirket_finans_ozeti(bigint) from public,anon;
grant execute on function public.sirket_finans_ozeti(bigint) to authenticated;
