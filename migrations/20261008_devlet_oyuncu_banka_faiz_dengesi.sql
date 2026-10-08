-- Banka vadeleri karsilastirilabilir getiride. Yillik politika faizi gun/saat esasina bolunur.
-- Mevcut vadeli kontratlarin oran/anaparalari ASLA degistirilmez.
CREATE OR REPLACE FUNCTION oyun.banka_oranlar()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with x as (
    select greatest(15,round(u.enflasyon+a.banka_reel_faiz,1)) py
    from oyun.ulke u, oyun.ayarlar a
    where u.id=1 and a.id=1
  )
  select jsonb_build_object(
    'politika',py,'vadesiz',0,
    'vadeli1s',round(py / 365.0 / 24.0,3),
    'vadeli3s',round(py / 365.0 * 3 / 24.0,3),
    'vadeli6s',round(py / 365.0 * 6 / 24.0,3),
    'vadeli12s',round(py / 365.0 * 12 / 24.0,3),
    'vadeli24s',round(py / 365.0,3),
    'vadeli7',round(py / 365.0 * 7,3),
    'vadeli30',round(py / 365.0 * 30,3),
    'kredi',round(py/12*1.60,2),
    'gecikme_gunluk',1
  ) from b
$function$
;

-- Oyuncu bankalari risk primi alabilir; 24s %0,30 ve 7 gun %1,80 tavan.
CREATE OR REPLACE FUNCTION oyun.oyb_oran(p_banka bigint, p_saat integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare f numeric; s numeric;
begin
  select banka_faiz into f from oyun.sirketler
  where id=p_banka and sektor='banka' and aktif;
  if f is null then raise exception 'Banka bulunamadi'; end if;
  if p_saat=168 then return least(f,1.8); end if;
  if p_saat not in (1,3,6,12,24) or p_saat is null then raise exception 'Gecersiz vade'; end if;
  select oran into s from oyun.oyb_vade_oran
  where banka_id=p_banka and saat=p_saat;
  return least(case p_saat when 1 then .03 when 3 then .07 when 6 then .12
    when 12 then .18 else .30 end,
    coalesce(s,round(f * case p_saat when 1 then .015 when 3 then .04
      when 6 then .065 when 12 then .09 else .15 end,2)));
end $function$
;
CREATE OR REPLACE FUNCTION public.oyb_oran_ayarla(p_banka bigint, p_saat integer, p_oran numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();cap numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id=o.sirket_id
   where s.id=p_banka and s.sektor='banka' and s.aktif and o.user_id=u and o.pay>=50)
 then raise exception 'Banka yonetim yetkin yok (en az %%50 pay gerekir)';end if;
 cap:=case p_saat when 1 then .03 when 3 then .07 when 6 then .12
   when 12 then .18 when 24 then .30 else null end;
 if cap is null or p_oran is null or p_oran<0 or p_oran>cap
   or p_oran<>round(p_oran,2)
 then raise exception 'Bu vade icin faiz orani gecersiz veya siniri asiyor';end if;
 insert into oyun.oyb_vade_oran(banka_id,saat,oran)
 values(p_banka,p_saat,p_oran) on conflict(banka_id,saat)
 do update set oran=excluded.oran;
 return jsonb_build_object('tamam',true,'saat',p_saat,'oran',p_oran,'ust_sinir',cap);
end $function$
;
CREATE OR REPLACE FUNCTION public.banka_faiz_belirle(p_banka bigint, p_faiz numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;
 if p_faiz is null or p_faiz<0 or p_faiz>1.8 or p_faiz<>round(p_faiz,2) then
   raise exception 'Haftalik oyuncu bankasi faizi 0-1,8 arasinda ve en fazla iki ondalik olmali';
 end if;
 if not exists(select 1 from oyun.sirket_ortaklari o join oyun.sirketler s on s.id=o.sirket_id
   where s.id=p_banka and s.sektor='banka' and s.aktif and o.user_id=auth.uid() and o.pay>=50)
 then raise exception 'Aktif banka yonetim yetkin yok';end if;
 update oyun.sirketler set banka_faiz=p_faiz where id=p_banka and sektor='banka' and aktif;
 if not found then raise exception 'Banka bulunamadi';end if;
 return jsonb_build_object('tamam',true,'faiz',p_faiz,'faiz_ust_sinir',1.8);
end $function$
;

-- Kredi faizleri de ayni zaman birimine uygun 24s tavan %1.
CREATE OR REPLACE FUNCTION public.oyb_kredi_faiz_ayarla(p_banka bigint, p_faiz numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_faiz is null or p_faiz<0 or p_faiz>1.0 or p_faiz<>round(p_faiz,2)
 then raise exception '24 saatlik kredi faizi 0-1 arasinda olmali';end if;
 update oyun.sirketler s set banka_kredi_faiz=p_faiz
 where id=p_banka and sektor='banka' and aktif and exists(
  select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50);
 if not found then raise exception 'Banka yonetim yetkin yok';end if;
 return jsonb_build_object('tamam',true,'kredi_faiz_24s',p_faiz);
end $function$
;

-- Yalnizca YENI mevduat/kredi icin banka tarafindan teklif edilecek faiz ayarlari dengelenir.
-- ESKI vadeli mevduatlarda oyun.banka_mevduat.faiz ve vadeli.oran dokunulmaz.
update oyun.sirketler set banka_faiz=least(banka_faiz,1.8),
  banka_kredi_faiz=least(banka_kredi_faiz,1)
where sektor='banka' and (banka_faiz>1.8 or banka_kredi_faiz>1);

update oyun.oyb_vade_oran set oran=least(oran,
 case saat when 1 then .03 when 3 then .07 when 6 then .12 when 12 then .18 else .30 end)
where oran>case saat when 1 then .03 when 3 then .07 when 6 then .12 when 12 then .18 else .30 end;
