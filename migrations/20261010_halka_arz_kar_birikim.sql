-- Halka arz tamamlayicisi: her ortak kendi haftalik karini ister cebine alir ister sirket kasasinda biriktirir.
-- Varsayilan eski davranis korunur: mevcut ve yeni ortaklarin kari cebine aktarilir.
alter table oyun.sirket_ortaklari add column if not exists kar_kasada boolean not null default false;
create or replace function oyun.sirket_hesapla(p_id bigint)
returns void language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;distributable numeric;v_odeme numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()::numeric*.8),2);
  cost:=round(s.sermaye*(.025+random()::numeric*.055)+w*(.5+random()::numeric),2);
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
   distributable:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    if not x.kar_kasada then
      v_odeme:=least(round(distributable*x.pay/100,2),greatest(0,distributable-distributed));
      if v_odeme>0 then
        perform oyun.para_islem(x.user_id,v_odeme,'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
        distributed:=distributed+v_odeme;
      end if;
    end if;
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir,faaliyet_gider,dagitilan_kar)
 values(p_id,t,net,'7 günlük faaliyet: gelir - gider = net sonuç; gerçekleşen ortak ödemesi ayrıca kaydedildi',income,cost,distributed);
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$;
create or replace function public.sirket_kar_birikim_ayarla(p_sirket bigint, p_kasada boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); v_pay numeric;
begin
 if u is null or not exists (select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Aktif oyuncu hesabi gerekli'; end if;
 if p_kasada is null then raise exception 'Tercih secilmeli'; end if;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=u) then raise exception 'Bu sirketin ortagi degilsin'; end if;
 -- Once eski tercihe ait gecikmis haftalik tahakkuklari bitir. Sonraki hafta yeni secime uyacak.
 perform oyun.sirket_hesapla(p_sirket);
 update oyun.sirket_ortaklari set kar_kasada=p_kasada where sirket_id=p_sirket and user_id=u returning pay into v_pay;
 return jsonb_build_object('sirket_id',p_sirket,'kar_kasada',p_kasada,'payim',v_pay);
end $$;
create or replace function public.halka_arz_durum(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); s oyun.sirketler; d record;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  perform oyun.halka_arz_tick();
  select * into s from oyun.sirketler where id = p_sirket and aktif;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  select * into d from oyun.halka_arz_deger_sinir(s.sermaye, s.sektor);
  return jsonb_build_object(
    'id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sermaye', s.sermaye, 'kasa', s.kasa, 'halka_acik', s.halka_acik,
    'payim', coalesce((select pay from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), 0),
    'kar_kasada', coalesce((select kar_kasada from oyun.sirket_ortaklari where sirket_id = s.id and user_id = u), false),
    'asgari_ucret', (select asgari from oyun.ulke where id = 1),
    'ort_net', oyun.sirket_ort_net(s.sermaye, s.sektor),
    'deger_en_az', d.en_az, 'deger_en_cok', d.en_cok, 'deger_onerilen', d.onerilen,
    'en_fazla_tutar', least(100000000 - s.sermaye, floor(d.en_cok * 49 / 51)),
    'acik', (select oyun.halka_arz_json(a, u) from oyun.halka_arz a where a.sirket_id = s.id and a.durum = 'acik'),
    'gecmis', coalesce((select jsonb_agg(oyun.halka_arz_json(a, u) order by a.bas desc)
                        from (select * from oyun.halka_arz where sirket_id = s.id and durum <> 'acik' order by bas desc limit 5) a), '[]'::jsonb));
end $$;
revoke all on function public.sirket_kar_birikim_ayarla(bigint,boolean) from public,anon;
grant execute on function public.sirket_kar_birikim_ayarla(bigint,boolean) to authenticated;
