-- Sirketler: 7 gunde bir net faaliyet karini ortaklara aktar; satilik ilan ve sermaye artisi.
alter table oyun.sirketler add column if not exists sonraki_kazanc timestamptz;
update oyun.sirketler set sonraki_kazanc=coalesce(sonraki_kazanc,kurulus+interval '7 days');
alter table oyun.sirketler alter column sonraki_kazanc set default (now()+interval '7 days');
create or replace function oyun.sirket_hesapla(p_id bigint)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;
begin
 perform pg_advisory_xact_lock(p_id,98763);
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()*.8),2);
  cost:=round(s.sermaye*(.025+random()*.055)+w*(.5+random()),2);
  net:=income-cost;
  -- Zararda sirket kasasi erir. Karda dagitilabilir para ortaklara aktarilir.
  if net<0 then
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributed:=least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net));
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    perform oyun.para_islem(x.user_id,round(distributed*x.pay/100,2),'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama) values(p_id,t,net,'7 gunluk faaliyet net sonucu; pozitif tutar ortaklara aktarildi');
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $$;
create or replace function public.sirket_sermaye_artir(p_sirket bigint,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();s oyun.sirketler;t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform oyun.sirket_hesapla(p_sirket);
 select * into s from oyun.sirketler where id=p_sirket and aktif for update;
 if s.id is null or not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=u and pay=100) then raise exception 'Sermaye artirimi icin sirketin tamamina sahip olmalisin';end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<10000 or p_tutar>10000000 or s.sermaye+p_tutar>100000000 then raise exception 'Sermaye artisi 10000-10000000 TL olmali; toplam 100 milyon TL siniri var';end if;
 perform oyun.para_islem(u,-p_tutar,'sirket','Sirket sermaye artirimi',t);
 update oyun.sirketler set sermaye=sermaye+p_tutar,kasa=kasa+p_tutar where id=p_sirket;
 insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama) values(p_sirket,t,p_tutar,'Ortak tarafindan sermaye artirimi');
 return jsonb_build_object('tamam',true,'yeni_sermaye',s.sermaye+p_tutar);
end $$;
create or replace function public.sirket_satiliga_cikar(p_sirket bigint,p_fiyat numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();
begin
 if not exists(select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id=o.sirket_id where s.id=p_sirket and s.aktif and o.user_id=u and o.pay=100) then raise exception 'Yalnizca sirketin %%100 sahibi tam satis ilani verebilir';end if;
 if p_fiyat is not null and (p_fiyat<1000 or p_fiyat>1000000000 or p_fiyat<>round(p_fiyat)) then raise exception 'Fiyat 1000-1000000000 TL olmali';end if;
 update oyun.sirketler set satilik=p_fiyat where id=p_sirket;
 return jsonb_build_object('tamam',true);
end $$;
create or replace function public.sirket_satilik_al(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid();s oyun.sirketler;oldowner uuid;t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(p_sirket,98763);
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
 return jsonb_build_object('tamam',true);
end $$;
revoke all on function public.sirket_sermaye_artir(bigint,numeric),public.sirket_satiliga_cikar(bigint,numeric),public.sirket_satilik_al(bigint) from public,anon;
grant execute on function public.sirket_sermaye_artir(bigint,numeric),public.sirket_satiliga_cikar(bigint,numeric),public.sirket_satilik_al(bigint) to authenticated;
