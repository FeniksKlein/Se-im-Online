-- Oyuncudan oyuncuya bağış: bağlı hesaplar scalar UUID döndürür.
CREATE OR REPLACE FUNCTION public.serbest_bagis(p_tur text, p_id text, p_tutar numeric, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 m numeric; tid bigint; v_id bigint; v_uuid uuid; hedef text;
 note text:=btrim(coalesce(p_aciklama,'')); c oyun.cuzdan; v_min numeric;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 if p_tutar is null or p_tutar::text !~ '^[0-9]+(\.[0-9]+)?$'
   or p_tutar<>trunc(p_tutar) or p_tutar<1 then
   raise exception 'Bağış tutarı en az 1 TL, pozitif tam sayı olmalı';end if;
 m:=p_tutar;
 if length(note)>150 then raise exception 'Bağış notu en fazla 150 karakter';end if;
 select * into p from oyun.profiller where id=u;
 if not found or p.yasakli then raise exception 'Hesabın bağış yapmaya uygun değil';end if;
 perform oyun.takip_engel(u,'bağış yapamazsın');
 if p_tur not in ('oyuncu','parti','sirket','gazete','il','devlet') then raise exception 'Geçersiz bağış hedefi';end if;
 -- Para transferinin alıcısı bulunmadan göndericiden tahsilat yapılmaz.
 if p_tur='oyuncu' then
   select id,kad into v_uuid,hedef from oyun.profiller
    where lower(kad)=lower(btrim(coalesce(p_id,''))) and not yasakli limit 1;
   if v_uuid is null then raise exception 'Alıcı oyuncu bulunamadı';end if;
   if v_uuid=u then raise exception 'Kendine bağış yapamazsın';end if;
   if exists(select 1 from oyun.ayarlar where id=1 and coklu_kontrol)
     and exists(select 1 from oyun.bagli_hesaplar(u) b where b=v_uuid) then
      raise exception 'Aynı cihazdaki bağlı hesaplara bağış yapılamaz';end if;
   if oyun.engelli(v_uuid,u) then raise exception 'Bu oyuncu seni engelledi';end if;
 elsif p_tur in ('parti','sirket','gazete','il') then
   if p_id is null or p_id !~ '^[0-9]{1,15}$' then raise exception 'Geçerli hedef numarası gir';end if;
   v_id:=p_id::bigint;
   if p_tur='parti' then
     select ad into hedef from oyun.partiler where id=v_id and not kapali;
   elsif p_tur='sirket' then
     select ad into hedef from oyun.sirketler where id=v_id and aktif;
   elsif p_tur='gazete' then
     select ad into hedef from oyun.oyuncu_gazeteleri where id=v_id and aktif;
   else
     select ad into hedef from oyun.iller where id=v_id;
   end if;
   if hedef is null then raise exception 'Bağış yapılacak kurum bulunamadı';end if;
 else
   hedef:='Türkiye Cumhuriyeti Hazinesi';
 end if;
 -- Gonderenin bakiyesi oyun.para_islem tarafindan atomik ve kilitli UPDATE ile kontrol edilir.
 perform oyun.para_islem(u,-m,'bagis',left(hedef||' için bağış'||case when note<>'' then ': '||note else '' end,170),t);
 if p_tur='oyuncu' then
   perform oyun.para_islem(v_uuid,m,'bagis',left(p.kad||' tarafından bağış'||case when note<>'' then ': '||note else '' end,170),t);
   perform oyun.bildir(v_uuid,format('%s sana %s ₺ bağışladı.',p.kad,oyun.tl(m)),t);
 elsif p_tur='parti' then
   update oyun.partiler set kasa=kasa+m where id=v_id;
   insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
     values(v_id,t,m,format('%s bağış yaptı',p.kad),'bagis');
 elsif p_tur='sirket' then
   update oyun.sirketler set kasa=kasa+m where id=v_id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
     values(v_id,t,m,p.kad||' oyuncusundan sermaye niteliğinde olmayan karşılıksız bağış');
 elsif p_tur='gazete' then
   update oyun.oyuncu_gazeteleri set kasa=kasa+m where id=v_id;
   insert into oyun.gazete_hareket(gazete_id,zaman,tutar,tur,aciklama)
     values(v_id,t,m,'bagis',p.kad||' bağış yaptı');
 elsif p_tur='il' then
   select asgari into v_min from oyun.ulke where id=1;
   update oyun.il_durum set kasa=kasa+m,gelisim=least(100,gelisim+0.005*m/greatest(1,v_min)) where il_id=v_id;
   insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);
 else
   update oyun.ulke set hazine=hazine+m where id=1;
 end if;
 insert into oyun.serbest_bagis_kayit(gonderen,alici_tur,alici_id,alici_adi,tutar,aciklama,zaman)
 values(u,p_tur,case when p_tur='oyuncu' then v_uuid::text when p_tur='devlet' then '1' else v_id::text end,hedef,m,nullif(note,''),t)
 returning id into tid;
 -- Kıdem kazanımı para miktarıyla sonsuz ölçeklenmez: bağıştan en fazla günlük 1 puan.
 select * into c from oyun.cuzdan where user_id=u for update;
 select asgari into v_min from oyun.ulke where id=1;
 update oyun.cuzdan
 set kidem=kidem+greatest(0,
   least(1,(coalesce(c.bagis_bugun,0)+m)/greatest(1,v_min))
    -least(1,coalesce(c.bagis_bugun,0)/greatest(1,v_min))),
   bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;
 return jsonb_build_object('tamam',true,'id',tid,'gonderen',p.kad,
  'hedef',hedef,'hedef_tur',p_tur,'tutar',m,
  'kalan', (select para from oyun.cuzdan where user_id=u));
end $function$
;
