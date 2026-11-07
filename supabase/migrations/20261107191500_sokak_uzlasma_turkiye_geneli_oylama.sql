-- Tum illerden eyleme katilan kullanicilar uzlasma oylamasinda da oy kullanir.
CREATE OR REPLACE FUNCTION public.sokak_soz_teklif(p_eylem bigint, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller;k text;v jsonb;b numeric;h numeric;n integer;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;p:=oyun.profilim();perform pg_advisory_xact_lock(781231,1);
 if not oyun.sokak_yonetebilir(p.id) then raise exception 'Cumhurbaşkanı veya İçişleri yetkisi gerekli';end if;
 select tur into k from oyun.sokak_talep where eylem_id=p_eylem;if k is null then raise exception 'Önce organizatör somut talep seçmeli';end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=p_eylem) then raise exception 'Eylem başına bir uzlaşma teklifi';end if;
 b:=oyun.sokak_olcum(p_eylem,k);h:=case k when 'hizmet' then b+5 when 'issizlik' then b-0.5 else b-1 end;
 if b is null or h<0 or k='hizmet' and h>100 then raise exception 'Bu gösterge için uygulanabilir hedef yok';end if;
 perform set_config('oyun.soz_teklif','evet',true);
 v:=public.sokak_hukumet_karar(p_eylem,'masa',p_metin);
 perform set_config('oyun.soz_teklif','',true);
 insert into oyun.sokak_soz(eylem_id,karar_id,tur,baslangic,hedef,oy_sonu) values(p_eylem,(v->>'karar_id')::bigint,k,b,h,oyun.simdi()+interval '12 hours');
 insert into oyun.sokak_soz_oy(eylem_id,user_id) select distinct p_eylem,d.temsilci from oyun.sokak_eylem_destek d join oyun.profiller pr on pr.id=d.temsilci join oyun.sokak_eylem e on e.id=d.eylem_id where e.id=p_eylem and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and not pr.yasakli and pr.olusturma<oyun.simdi()-interval '3 days';
 get diagnostics n=row_count;if n<3 then raise exception 'Oylama için Türkiye genelinden en az 3 gerçek katılımcı gerekli';end if;
 perform oyun.sokak_duyur(p_eylem,'Somut uzlaşma teklifi oylamaya açıldı. Seçmen listesi sabit; kabul için tüm katılımcıların yarısından fazlası gerekir.');return v;
end $function$
;
revoke execute on function public.sokak_soz_teklif(bigint,text) from public,anon;
grant execute on function public.sokak_soz_teklif(bigint,text) to authenticated;
