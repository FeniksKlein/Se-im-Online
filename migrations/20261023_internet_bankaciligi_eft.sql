-- Bankalar arasi EFT (mevcut oyundaki hesaplara zarar vermez)
CREATE OR REPLACE FUNCTION public.ib_eft(p_banka bigint, p_hedef_banka bigint, p_alici text, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); al uuid; t numeric(18,2):=round(p_tutar,2); v numeric(18,2); tm timestamptz:=oyun.simdi(); sb text; hb text;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_banka is null or p_hedef_banka is null or p_banka=p_hedef_banka then
   raise exception 'Baska bir banka secmelisin';end if;
 if t is null or t<1 or t>10000000 then raise exception 'Gecersiz EFT tutari';end if;
 if p_alici is null or length(trim(p_alici))=0 then raise exception 'Alici kullanici adini yaz';end if;
 select id into al from oyun.profiller where lower(kad)=lower(trim(p_alici));
 if al is null then raise exception 'Alici kullanici bulunamadi';end if;
 perform 1 from oyun.sirketler where id in (p_banka,p_hedef_banka) order by id for update;
 select ad into sb from oyun.sirketler where id=p_banka and aktif and sektor='banka';
 select ad into hb from oyun.sirketler where id=p_hedef_banka and aktif and sektor='banka';
 if sb is null or hb is null then raise exception 'Banka aktif degil';end if;
 if not oyun.oyb_hesap_acik(p_banka,u) or not oyun.oyb_hesap_acik(p_hedef_banka,al) then
   raise exception 'Gonderenin kaynak, alicinin hedef bankada acik hesabi olmali';end if;
 insert into oyun.ib_vadesiz(banka_id,user_id) values(p_banka,u),(p_hedef_banka,al) on conflict do nothing;
 perform 1 from oyun.ib_vadesiz where (banka_id=p_banka and user_id=u) or (banka_id=p_hedef_banka and user_id=al) order by banka_id,user_id for update;
 select bakiye into v from oyun.ib_vadesiz where banka_id=p_banka and user_id=u;
 if v<t then raise exception 'Banka bakiyen EFT icin yetersiz';end if;
 update oyun.sirketler set kasa=kasa-t where id=p_banka and kasa>=t;
 if not found then raise exception 'Gonderen banka kasasinda EFT likiditesi yetersiz';end if;
 update oyun.sirketler set kasa=kasa+t where id=p_hedef_banka;
 update oyun.ib_vadesiz set bakiye=bakiye-t,guncelleme=tm where banka_id=p_banka and user_id=u;
 update oyun.ib_vadesiz set bakiye=bakiye+t,guncelleme=tm where banka_id=p_hedef_banka and user_id=al;
 insert into oyun.ib_hareket(banka_id,user_id,tutar,aciklama,zaman)
 values(p_banka,u,-t,'EFT gonderildi: '||p_alici||' · '||hb,tm),
       (p_hedef_banka,al,t,'EFT alindi: '||oyun.kad(u)||' · '||sb,tm);
 perform oyun.bildir(al,'EFT: '||oyun.kad(u)||' tarafindan '||hb||' hesabina '||t||' TL geldi.',tm);
 return jsonb_build_object('tamam',true,'tutar',t,'kaynak',sb,'hedef',hb);
end $function$

revoke all on function public.ib_eft(bigint,bigint,text,numeric) from public,anon;
grant execute on function public.ib_eft(bigint,bigint,text,numeric) to authenticated;
