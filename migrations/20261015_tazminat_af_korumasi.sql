-- Hukuki tazminat alacağı Cumhurbaşkanlığı ceza affının kapsamına girmez.
begin;
CREATE OR REPLACE FUNCTION public.adliye_af_cikar(p_dava bigint, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); d oyun.adliye_davalar; adet int:=0; kalan timestamptz; eski oyun.makamlar;
begin
 if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null) then raise exception 'Yalnız Cumhurbaşkanı af çıkarabilir.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 10 and 1000 then raise exception 'Af gerekçesi 10–1000 karakter olmalı.'; end if;
 for d in select * from oyun.adliye_davalar
  where durum='karar' and af_at is null and karar not in('beraat','tazminat')
    and (p_dava is null or id=p_dava) order by id for update
 loop
  update oyun.adliye_davalar set af_at=t,af_veren=p.id,af_gerekce=trim(p_gerekce) where id=d.id;
  adet:=adet+1;
  if d.davali is not null and d.karar in('sustur_1s','sustur_1g','sustur_1h') then
   -- Yalnızca mahkeme susturmasını kaldır, yönetici susturmalarını değiştirme.
   select max(ceza_bitis) into kalan from oyun.adliye_davalar
   where davali=d.davali and durum='karar' and af_at is null and karar in('sustur_1s','sustur_1g','sustur_1h') and ceza_bitis>t;
   update oyun.profiller set adliye_susturma_bitis=kalan where id=d.davali;
  end if;
  if d.karar='vekillik_dusur' and d.mv_makam_id is not null then
    select * into eski from oyun.makamlar where id=d.mv_makam_id for update;
    if eski.id is not null and eski.bit is not null and eski.bitis_neden='Adliye #'||d.id||' kararı'
      and not exists(select 1 from oyun.makamlar where user_id=eski.user_id and tur='mv' and bit is null)
      and not exists(select 1 from oyun.secimler where tur='mv' and goreve_bas>d.karar_at and goreve_bas<=t)
      and (select count(*) from oyun.makamlar where tur='mv' and bit is null)<600 then
      update oyun.makamlar set bit=null,bitis_neden=null where id=eski.id;
    end if;
  end if;
  if d.davali is not null then
   insert into oyun.bildirimler(user_id,zaman,metin) values(d.davali,t,'Cumhurbaşkanı Adliye #'||d.id||' cezanızı affetti. Detaylar Adliye''de.');
  end if;
 end loop;
 if adet=0 then raise exception 'Affedilebilecek kesinleşmiş ceza bulunamadı.'; end if;
 insert into oyun.adliye_aflar(cb,dava_id,tur,gerekce,affedilen,zaman)
 values(p.id,p_dava,case when p_dava is null then 'genel' else 'bireysel' end,trim(p_gerekce),adet,t);
 return jsonb_build_object('tamam',true,'affedilen',adet);
end $function$
;
commit;
