-- Oyuncu banka kredisi: yalnizca diger GERCEK oyunculara, banka kasasindan.
-- Talep/karar/odeme sunucu tarafinda atomik, ortak parasi oyuncunun cebine aktarilmaz.
create or replace function public.oyb_kredi_basvur(p_banka bigint,p_tutar numeric,p_saat integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s oyun.sirketler; oran numeric; toplam numeric; x bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1000 or p_tutar>500000
 then raise exception 'Kredi 1.000 - 500.000 TL arasinda tam TL olmali';end if;
 if p_saat not in (1,3,6,12,24) or p_saat is null then raise exception 'Vade 1, 3, 6, 12 ya da 24 saat';end if;
 select * into s from oyun.sirketler where id=p_banka and aktif and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Kendi bankandan kredi alamazsin';end if;
 if exists(select 1 from oyun.oyb_kredi where borclu=u and durum in ('basvuru','aktif'))
 then raise exception 'Once diger oyuncu banka kredini kapat veya cevabini bekle';end if;
 if exists(select 1 from oyun.krediler where user_id=u and durum='takip')
 then raise exception 'Yasal takipteki banka kredin nedeniyle yeni kredi alamazsin';end if;
 oran:=round(s.banka_kredi_faiz*p_saat/24,2);
 if oran<0 or oran>20 then raise exception 'Banka kredi faizi gecersiz';end if;
 toplam:=round(p_tutar*(1+oran/100));
 insert into oyun.oyb_kredi(banka_id,borclu,anapara,saat,oran,toplam,kalan)
 values(p_banka,u,p_tutar,p_saat,oran,toplam,toplam) returning id into x;
 return jsonb_build_object('id',x,'anapara',p_tutar,'toplam',toplam,
  'oran',oran,'saat',p_saat,'durum','basvuru');
end $$;

create or replace function public.oyb_kredi_karar(p_id bigint,p_onay boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();k oyun.oyb_kredi;s oyun.sirketler;t timestamptz:=oyun.simdi();r jsonb;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_onay is null then raise exception 'Karar eksik';end if;
 select * into k from oyun.oyb_kredi where id=p_id;
 if not found then raise exception 'Kredi basvurusu bulunamadi';end if;
 if not exists(select 1 from oyun.sirket_ortaklari o
  where o.sirket_id=k.banka_id and o.user_id=u and o.pay>=50)
 then raise exception 'Bu bankanin kredi yonetim yetkin yok';end if;
 select * into s from oyun.sirketler where id=k.banka_id and aktif and sektor='banka' for update;
 if not found then raise exception 'Banka artik faal degil';end if;
 select * into k from oyun.oyb_kredi where id=p_id for update;
 if k.durum<>'basvuru' then raise exception 'Bu basvuru zaten karara baglandi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=k.banka_id and user_id=k.borclu and pay>0)
 then raise exception 'Banka ortaklarina veya yoneticilerine kredi kullandirilamaz';end if;
 if not p_onay then
   update oyun.oyb_kredi set durum='reddedildi',kapanis=t where id=k.id;
   return jsonb_build_object('tamam',true,'onay',false);
 end if;
 if exists(select 1 from oyun.banka_mevduat where banka_id=s.id and not kapandi and vade<=t)
 then raise exception 'Gecikmis mevduat odemeleri varken kredi verilemez';end if;
 r:=oyun.oyb_saglik(s.id);
 if k.anapara>(r->>'kredi_verilebilir')::numeric
 then raise exception 'Bankanin kredilendirmeye ayirabilecegi guvenli likidite yetersiz';end if;
 update oyun.sirketler set kasa=kasa-k.anapara where id=s.id and kasa>=k.anapara;
 if not found then raise exception 'Banka kasasinda para yok';end if;
 update oyun.oyb_kredi set durum='aktif',acilis=t,
   vade=t+make_interval(hours=>k.saat)
   where id=k.id;
 perform oyun.para_islem(k.borclu,k.anapara,'oyb_kredi','Oyuncu bankasindan kredi #'||k.id,t);
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama)
 values(s.id,0,'Oyuncu kredisi #'||k.id||' verildi: '||k.anapara||' TL');
 perform oyun.bildir(k.borclu,'Oyuncu bankasi kredi basvurun kabul edildi. Geri odeme tutari: '||k.toplam||' TL.',t);
 return jsonb_build_object('tamam',true,'onay',true,'vade',t+make_interval(hours=>k.saat));
end $$;

create or replace function public.oyb_kredi_ode(p_id bigint,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();k oyun.oyb_kredi;s oyun.sirketler;t timestamptz:=oyun.simdi();
  ode numeric; anapara_bolum numeric;faiz_bolum numeric;yeni numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1 or p_tutar>1000000
 then raise exception 'Odeme pozitif tam TL olmali';end if;
 select * into k from oyun.oyb_kredi where id=p_id and borclu=u;
 if not found then raise exception 'Kredi bulunamadi';end if;
 select * into s from oyun.sirketler where id=k.banka_id for update;
 select * into k from oyun.oyb_kredi where id=p_id and borclu=u for update;
 if k.durum<>'aktif' then raise exception 'Kredi aktif degil';end if;
 ode:=least(p_tutar,k.kalan);
 perform oyun.para_islem(u,-ode,'oyb_kredi','Oyuncu bankasi kredi geri odeme #'||k.id,t);
 update oyun.sirketler set kasa=kasa+ode where id=k.banka_id;
 anapara_bolum:=least(ode,greatest(0,k.anapara-k.anapara_odendi));
 faiz_bolum:=ode-anapara_bolum;
 yeni:=k.kalan-ode;
 update oyun.oyb_kredi set kalan=yeni,anapara_odendi=anapara_odendi+anapara_bolum,
   durum=case when yeni<=0 then 'odendi' else 'aktif' end,
   kapanis=case when yeni<=0 then t else null end
 where id=k.id;
 if faiz_bolum>0 then
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama)
 values(k.banka_id,faiz_bolum,'Oyuncu kredisi #'||k.id||' tahsil edilen faiz geliri');
 end if;
 return jsonb_build_object('odendi',ode,'kalan',yeni,
   'tamam',yeni<=0,'faiz_geliri',faiz_bolum);
end $$;

create or replace function public.oyb_kredi_faiz_ayarla(p_banka bigint,p_faiz numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_faiz is null or p_faiz<0 or p_faiz>12 or p_faiz<>round(p_faiz,2)
 then raise exception '24 saatlik kredi faizi 0-12 arasinda olmali';end if;
 update oyun.sirketler s set banka_kredi_faiz=p_faiz
 where id=p_banka and sektor='banka' and aktif and exists(
  select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50);
 if not found then raise exception 'Banka yonetim yetkin yok';end if;
 return jsonb_build_object('tamam',true,'kredi_faiz_24s',p_faiz);
end $$;

create or replace function public.oyb_yonetim(p_banka bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s oyun.sirketler;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Banka ortagi degilsin';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 return jsonb_build_object('id',s.id,'ad',s.ad,'yonetebilir',
 exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>=50),
 'kredi_faiz',s.banka_kredi_faiz,'oranlar',jsonb_build_object(
 '1',oyun.oyb_oran(p_banka,1),'3',oyun.oyb_oran(p_banka,3),'6',oyun.oyb_oran(p_banka,6),
 '12',oyun.oyb_oran(p_banka,12),'24',oyun.oyb_oran(p_banka,24),'168',s.banka_faiz),
 'durum',oyun.oyb_saglik(p_banka),
 'krediler',coalesce((select jsonb_agg(jsonb_build_object('id',k.id,
  'borclu',coalesce(p.kad,'Oyuncu'), 'anapara',k.anapara,'toplam',k.toplam,
  'kalan',k.kalan,'oran',k.oran,'saat',k.saat,'vade',k.vade,
  'durum',case when k.durum='aktif' and k.vade<oyun.simdi() then 'gecikmis' else k.durum end)
  order by k.id desc) from (select * from oyun.oyb_kredi where banka_id=p_banka order by id desc limit 40)k
  left join oyun.profiller p on p.id=k.borclu),'[]'::jsonb),
 'hareketler',coalesce((select jsonb_agg(jsonb_build_object(
   'tutar',h.tutar,'aciklama',h.aciklama,'zaman',h.zaman) order by h.id desc)
   from (select * from oyun.sirket_hareket where sirket_id=p_banka order by id desc limit 20)h),'[]'::jsonb));
end $$;
revoke all on function public.oyb_kredi_basvur(bigint,numeric,integer),
 public.oyb_kredi_karar(bigint,boolean),public.oyb_kredi_ode(bigint,numeric),
 public.oyb_kredi_faiz_ayarla(bigint,numeric),public.oyb_yonetim(bigint)
 from public,anon;
grant execute on function public.oyb_kredi_basvur(bigint,numeric,integer),
 public.oyb_kredi_karar(bigint,boolean),public.oyb_kredi_ode(bigint,numeric),
 public.oyb_kredi_faiz_ayarla(bigint,numeric),public.oyb_yonetim(bigint)
 to authenticated;
