begin;
-- Bir oyuncu kendi sigorta şirketi üzerinden ayrı işletmesini ve kendi taşınmazını sigortalayabilir.
-- Aynı şirket ID, rezerv, yetki ve para kontrolleri değiştirilmez.

CREATE OR REPLACE FUNCTION public.sigorta_isletme_police_al(p_isletme bigint, p_sigortaci bigint, p_teminat numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); a oyun.sirketler; s oyun.sirketler; v_prim numeric; v_id bigint; risk numeric; borc numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oturum gerekli.';end if;
 if p_isletme is null or p_sigortaci is null or p_isletme=p_sigortaci or p_teminat is null
  or p_teminat<>round(p_teminat) or p_teminat<10000 or p_teminat>500000 then
  raise exception 'Sigortacı, işletme veya 10.000–500.000 TL teminat seçimi geçersiz.';end if;
 if not oyun.sirket_yonetici_mi(p_isletme,u) then raise exception 'Bu işletmeyi sigortalatma yetkin yok.';end if;
 perform pg_advisory_xact_lock(20261022,(p_isletme % 2147483647)::integer);
 select * into a from oyun.sirketler where id=p_isletme for update;
 select * into s from oyun.sirketler where id=p_sigortaci for update;
 if a.id is null or not a.aktif or a.sektor='banka' or s.id is null or not s.aktif
 or not exists(select 1 from oyun.eko_isletmeler i where i.sirket_id=s.id and i.tur='sigorta')
 then raise exception 'Aktif bir işletme ve lisanslı sigortacı seç.';end if;
 if p_teminat>least(500000,round(a.sermaye*1.5)) then raise exception 'Teminat işletmenin sermayesine göre çok yüksek.';end if;
 if exists(select 1 from oyun.sigorta_isletme_policeleri p where p.isletme=a.id and p.bit>now()) then
  raise exception 'Bu işletmenin zaten geçerli poliçesi var.';end if;
 select coalesce(sum(p.teminat),0) into risk from oyun.sigorta_isletme_policeleri p where p.sigortaci=s.id and p.bit>now();
 select coalesce(sum(h.tazminat-h.odenen),0) into borc from oyun.sigorta_isletme_hasarlari h
 join oyun.sigorta_isletme_policeleri p on p.id=h.police_id where p.sigortaci=s.id;
 if s.kasa < round((risk+p_teminat)*0.70)+borc then
  raise exception 'Sigortacı şirketin mevcut tazminat yükümlülükleri için yeterli rezervi yok.';end if;
 v_prim:=greatest(300,round(p_teminat*0.02));
 update oyun.sirketler set kasa=kasa-v_prim where id=a.id and kasa>=v_prim;
 if not found then raise exception 'İşletme kasasında poliçe primini ödeyecek para yok.';end if;
 update oyun.sirketler set kasa=kasa+v_prim where id=s.id;
 insert into oyun.sigorta_isletme_policeleri(sigortaci,isletme,yaptiran,prim,teminat,bit)
 values(s.id,a.id,u,v_prim,p_teminat,now()+interval '72 hours') returning id into v_id;
 insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama)
 values(a.id,s.id,u,'sigorta_prim',-v_prim,'72 saatlik işletme mal sigortası prim ödemesi');
 return jsonb_build_object('id',v_id,'prim',v_prim,'teminat',p_teminat,'bit',now()+interval '72 hours');
end $function$;

CREATE OR REPLACE FUNCTION public.sigorta_mulk_police_al(p_mulk bigint, p_sigortaci bigint, p_teminat numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); m oyun.yatirim_mulkleri; s oyun.sirketler;
 v_prim numeric; v_id bigint; v_risk numeric; v_borc numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli)
 then raise exception 'Oturum açmalısın.'; end if;
 if p_mulk is null or p_sigortaci is null or p_teminat is null
    or p_teminat <> round(p_teminat) or p_teminat<10000 or p_teminat>2000000
 then raise exception '10.000–2.000.000 ₺ arasında geçerli teminat seç.'; end if;
 perform pg_advisory_xact_lock(20261022, (p_mulk % 2147483647)::integer);
 select * into m from oyun.yatirim_mulkleri where id=p_mulk for update;
 select * into s from oyun.sirketler where id=p_sigortaci for update;
 if m.id is null or m.user_id<>u then raise exception 'Yalnızca kendi mülkünü sigortalatabilirsin.';end if;
 if p_teminat>least(2000000,m.alis_bedeli) then raise exception 'Teminat mülk değerini aşamaz.';end if;
 if s.id is null or not s.aktif or not exists(select 1 from oyun.eko_isletmeler i
    where i.sirket_id=s.id and i.tur='sigorta')
 then raise exception 'Geçerli sigorta şirketi seç.';end if;
 if exists(select 1 from oyun.sigorta_mulk_policeleri p
   where p.mulk_id=m.id and p.bit>now())
 then raise exception 'Bu mülk için geçerli poliçe bulunuyor.';end if;
 select coalesce(sum(p.teminat),0) into v_risk
 from oyun.sigorta_mulk_policeleri p where p.sigortaci=s.id and p.bit>now();
 v_risk:=v_risk+coalesce((select sum(p.teminat) from oyun.sigorta_isletme_policeleri p
   where p.sigortaci=s.id and p.bit>now()),0);
 select coalesce(sum(h.tazminat-h.odenen),0) into v_borc from oyun.sigorta_mulk_hasarlari h
   join oyun.sigorta_mulk_policeleri p on p.id=h.police_id where p.sigortaci=s.id;
 v_borc:=v_borc+coalesce((select sum(h.tazminat-h.odenen) from oyun.sigorta_isletme_hasarlari h
   join oyun.sigorta_isletme_policeleri p on p.id=h.police_id where p.sigortaci=s.id),0);
 if coalesce(s.kasa,0) < round((v_risk+p_teminat)*0.25)+v_borc
 then raise exception 'Sigortacı şirketin tazminat rezervi yetersiz.';end if;
 v_prim:=greatest(200,round(p_teminat*0.005));
 perform oyun.para_islem(u,-v_prim,'sigorta_prim',format('Mülk #%s sigortası, sigortacı #%s',p_mulk,p_sigortaci),now());
 update oyun.sirketler set kasa=kasa+v_prim where id=s.id;
 insert into oyun.sigorta_mulk_policeleri(mulk_id,sigortaci,sahip,prim,teminat,bit)
 values(m.id,s.id,u,v_prim,p_teminat,now()+interval '7 days') returning id into v_id;
 insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
 values(s.id,u,'sigorta_prim',v_prim,'Mülk sigortası poliçesi #'||v_id);
 return jsonb_build_object('id',v_id,'prim',v_prim,'teminat',p_teminat,
  'bit',now()+interval '7 days');
end $function$;
commit;
