-- Her yeni oyuncu bankasi ekonomik limitli faizle acilir.
-- Yeni bankalar sonradan eski yuksek varsayilan faizle kurulamasin.
alter table oyun.sirketler alter column banka_faiz set default 1.5;
alter table oyun.sirketler alter column banka_kredi_faiz set default 0.6;
-- Banka kurulusu daha once acilmissa ve eski varsayilan faizleri aliyorsa indir.
update oyun.sirketler set banka_faiz=least(banka_faiz,1.8),
 banka_kredi_faiz=least(banka_kredi_faiz,1.0)
where sektor='banka' and (banka_faiz>1.8 or banka_kredi_faiz>1.0);

-- Eski cached uygulama da 7 gunde %3 teklif etmesin.
CREATE OR REPLACE FUNCTION public.banka_mevduat_teklif(p_banka bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;v_borc numeric;v_anapara numeric;v_odeme numeric;v_guvence numeric;v_uygun boolean;v_ortak boolean;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into s from oyun.sirketler where id=p_banka and aktif and sektor='banka';
 if s.id is null then raise exception 'Banka bulunamadi';end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<1000 or p_tutar>10000000 then
  raise exception 'Mevduat tutari 1.000 - 10.000.000 TL olmali';end if;
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0)
 into v_borc,v_anapara from oyun.banka_mevduat m where m.banka_id=p_banka and not m.kapandi;
 v_odeme:=round(p_tutar*(1+s.banka_faiz/100));
 v_guvence:=greatest(s.sermaye*0.10,(v_anapara+p_tutar)*0.10);
 v_ortak:=exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=p_banka and o.user_id=u and o.pay>0);
 v_uygun:=not v_ortak and s.banka_faiz between 0 and 1.8
       and s.kasa >= v_borc+(v_odeme-p_tutar)+v_guvence;
 return jsonb_build_object(
  'banka',s.ad,'tutar',p_tutar,'haftalik_faiz',s.banka_faiz,
  'vade_sonu_odeme',v_odeme,'faiz_kazanci',v_odeme-p_tutar,
  'kasa',s.kasa,'acik_taahhut',v_borc,'zorunlu_tampon',v_guvence,
  'bankam',v_ortak,'odeme_garantisi_icin_yeterli',v_uygun,
  'uyari',case when v_ortak then 'Kendi bankana mevduat yatiramazsin'
              when not v_uygun then 'Bu tutarin vade sonu faizi kasada guvenceye alinmis degil'
              else 'Vade sonu odeme tutari bankanin kasasinda guvenceye alindi' end);
end $function$
;
CREATE OR REPLACE FUNCTION public.banka_mevduat_yatir(p_banka bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;t timestamptz:=oyun.simdi();
        v_borc numeric; v_anapara numeric; v_yeni_borc numeric; v_guvence numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<1000 or p_tutar>10000000
 then raise exception 'Mevduat 1.000 - 10.000.000 TL arasinda tam sayi olmali';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if s.id is null then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari o
           where o.sirket_id=p_banka and o.user_id=u and o.pay>0)
 then raise exception 'Kendi bankana faizli mevduat yatiramazsin; baska bir oyuncu bankasi sec';end if;
 if s.banka_faiz<0 or s.banka_faiz>1.8 then raise exception 'Banka faiz sinirini asiyor';end if;
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),
        coalesce(sum(m.anapara),0)
 into v_borc,v_anapara from oyun.banka_mevduat m where m.banka_id=p_banka and not m.kapandi;
 v_yeni_borc:=round(p_tutar*(1+s.banka_faiz/100));
 v_guvence:=greatest(s.sermaye*0.10,(v_anapara+p_tutar)*0.10);
 -- After deposit: cash=old cash+principal; liabilities=old liabilities+principal+interest.
 -- Preserve a funded 10 percent reserve on capital and all deposits.
 if s.kasa < v_borc+(v_yeni_borc-p_tutar)+v_guvence
 then raise exception 'Banka likiditesi/teminati yetersiz. Mevduat kabul edilemiyor';end if;
 perform oyun.para_islem(u,-p_tutar,'mevduat','Oyuncu bankasina 7 gun vadeli mevduat',t);
 update oyun.sirketler set kasa=kasa+p_tutar where id=p_banka;
 insert into oyun.banka_mevduat(banka_id,user_id,anapara,faiz,vade)
 values(p_banka,u,p_tutar,s.banka_faiz,t+interval '7 days');
 return jsonb_build_object('tamam',true,'banka',p_banka,'faiz',s.banka_faiz,'vade',t+interval '7 days');
end $function$
;
CREATE OR REPLACE FUNCTION public.oyuncu_banka_liste()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object('bankalar',coalesce(jsonb_agg(jsonb_build_object('id',id,'ad',ad,'faiz',least(banka_faiz,1.8),'kasa',kasa) order by id),'[]'::jsonb))
 from oyun.sirketler where sektor='banka' and aktif
$function$
;

-- Diger hesaplarda da teklif ile gorunen degerler ayni limite uysun.
CREATE OR REPLACE FUNCTION public.oyb_kredi_basvur(p_banka bigint, p_tutar numeric, p_saat integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 oran:=round(least(s.banka_kredi_faiz,1.0)*p_saat/24,2);
 if oran<0 or oran>20 then raise exception 'Banka kredi faizi gecersiz';end if;
 toplam:=round(p_tutar*(1+oran/100));
 insert into oyun.oyb_kredi(banka_id,borclu,anapara,saat,oran,toplam,kalan)
 values(p_banka,u,p_tutar,p_saat,oran,toplam,toplam) returning id into x;
 return jsonb_build_object('id',x,'anapara',p_tutar,'toplam',toplam,
  'oran',oran,'saat',p_saat,'durum','basvuru');
end $function$
;
CREATE OR REPLACE FUNCTION public.oyb_liste()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('bankalar',coalesce((
 select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,
   'faiz',least(s.banka_faiz,1.8),'kredi_faiz',least(s.banka_kredi_faiz,1.0),
   'bankam',exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>0),
   'oranlar',jsonb_build_object('1',oyun.oyb_oran(s.id,1),'3',oyun.oyb_oran(s.id,3),
     '6',oyun.oyb_oran(s.id,6),'12',oyun.oyb_oran(s.id,12),
     '24',oyun.oyb_oran(s.id,24),'168',oyun.oyb_oran(s.id,168)))
   order by s.id) from oyun.sirketler s where s.sektor='banka' and s.aktif
 ),'[]'::jsonb));
end $function$
;
CREATE OR REPLACE FUNCTION public.oyb_yonetim(p_banka bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Banka ortagi degilsin';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka';
 if not found then raise exception 'Banka bulunamadi';end if;
 return jsonb_build_object('id',s.id,'ad',s.ad,'yonetebilir',
 exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>=50),
 'kredi_faiz',least(s.banka_kredi_faiz,1.0),'oranlar',jsonb_build_object(
 '1',oyun.oyb_oran(p_banka,1),'3',oyun.oyb_oran(p_banka,3),'6',oyun.oyb_oran(p_banka,6),
 '12',oyun.oyb_oran(p_banka,12),'24',oyun.oyb_oran(p_banka,24),'168',oyun.oyb_oran(p_banka,168)),
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
end $function$
;
