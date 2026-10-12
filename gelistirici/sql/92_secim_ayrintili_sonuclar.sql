-- Ayrintili secim sonuclari / secim gunu ittifak anligi / ikinci tur aday devami.
-- Mevcut oylar, adaylar, secim takvimi ve gecmis sonuclar silinmez.
CREATE TABLE IF NOT EXISTS oyun.secim_ittifak_anlik (
  secim_id bigint NOT NULL REFERENCES oyun.secimler(id) ON DELETE CASCADE,
  ittifak_id bigint NOT NULL, ittifak_ad text NOT NULL,
  parti_id bigint NOT NULL, parti_kisa text NOT NULL,
  PRIMARY KEY(secim_id,ittifak_id,parti_id)
);
ALTER TABLE oyun.secim_ittifak_anlik ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.secim_ittifak_anlik FROM public, anon, authenticated;
CREATE OR REPLACE FUNCTION oyun.secim_ittifak_anlik_yaz(p_secim bigint)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 insert into oyun.secim_ittifak_anlik(secim_id,ittifak_id,ittifak_ad,parti_id,parti_kisa)
 select p_secim,i.id,i.ad,u.parti_id,p.kisa
 from oyun.ittifaklar i join oyun.ittifak_uyeler u on u.ittifak_id=i.id
 join oyun.partiler p on p.id=u.parti_id
 where exists(select 1 from oyun.secimler s where s.id=p_secim and s.tur='mv')
 on conflict do nothing;
$function$
;

CREATE OR REPLACE FUNCTION oyun.secim_ittifak_anlik_tetik()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform oyun.secim_ittifak_anlik_yaz(new.secim_id);
 return new;
end $function$
;

DROP TRIGGER IF EXISTS secim_ittifak_anlik_tetik ON oyun.secim_gecesi;
CREATE TRIGGER secim_ittifak_anlik_tetik
 AFTER INSERT ON oyun.secim_gecesi FOR EACH ROW
 EXECUTE FUNCTION oyun.secim_ittifak_anlik_tetik();
SELECT oyun.secim_ittifak_anlik_yaz(g.secim_id)
 FROM oyun.secim_gecesi g JOIN oyun.secimler s ON s.id=g.secim_id AND s.tur='mv';
CREATE OR REPLACE FUNCTION oyun.gb_mv_cb_adaylik_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_tur text; v_donem text;
begin
 select s.tur,s.donem into v_tur,v_donem from oyun.secimler s where s.id=new.secim_id;
 if v_tur not in ('mv_on','mv','cb','cb2') then return new; end if;
 if not exists(select 1 from oyun.partiler p where p.gb=new.user_id) then return new; end if;
 -- Ikinci tur yeni bir basvuru degil, ilk tur adayinin devamidir.
 -- Onceki ilk tur adayi oldugu teyit edilen oyuncu icin MV cakismasi engellenmez.
 if v_tur='cb2' and exists (
   select 1 from oyun.adaylar a
   join oyun.secimler s on s.id=a.secim_id
   where a.user_id=new.user_id and s.donem=v_donem and s.tur='cb'
 ) then return new; end if;
 perform 1 from oyun.profiller pr where pr.id=new.user_id for update;
 if v_tur in ('mv_on','mv') and exists (
   select 1 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
   where a.user_id=new.user_id and s.donem=v_donem
   and s.tur in ('cb','cb2') and (tg_op='INSERT' or a.id<>new.id)
 ) then raise exception 'Cumhurbaskani adayi olan genel baskan ayni secim doneminde milletvekili adayi olamaz.'; end if;
 if v_tur in ('cb','cb2') and exists (
   select 1 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
   where a.user_id=new.user_id and s.donem=v_donem
   and s.tur in ('mv_on','mv') and (tg_op='INSERT' or a.id<>new.id)
 ) then raise exception 'Milletvekili adayligi bulunan genel baskan ayni donemde cumhurbaskani adayi olamaz. Once milletvekili adayligini geri cekmelisin.'; end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.secim_ayrintili_sonuclar(p_secim bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 s oyun.secimler; m oyun.secimler; c oyun.secimler;
 mt bigint; ct bigint; p jsonb; a jsonb; it jsonb; iller jsonb:='[]'::jsonb;
 pp jsonb; aa jsonb; ii jsonb; il record; itop bigint; ict bigint;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
 select * into s from oyun.secimler where id=p_secim;
 if s.id is null or s.tur not in ('mv','cb','cb2') then raise exception 'Seçim bulunamadı'; end if;
 select * into m from oyun.secimler where tur='mv' and donem=s.donem order by id desc limit 1;
 select * into c from oyun.secimler where tur=(case when s.tur='cb2' then 'cb2' else 'cb' end) and donem=s.donem order by id desc limit 1;
 if m.id is null or c.id is null or m.durum='bekliyor' or c.durum='bekliyor'
 or m.sonuc is null or c.sonuc is null
 or exists(select 1 from oyun.secim_gecesi g where g.secim_id in(m.id,c.id)
    and oyun.simdi()<g.baslangic+make_interval(secs=>g.sure_sn)) then
   return jsonb_build_object('hazir',false,'mesaj','Sandık sayımları devam ediyor.');
 end if;
 select count(*) into mt from oyun.oylar where secim_id=m.id;
 select count(*) into ct from oyun.oylar where secim_id=c.id;
 select coalesce(jsonb_agg(jsonb_build_object(
   'ad',x.ad,'kisa',x.kisa,'renk',x.renk,'oy',x.oy,
   'yuzde',case when mt>0 then round(x.oy*100.0/mt,2) else 0 end
 ) order by x.oy desc,x.kisa),'[]'::jsonb) into p
 from (select pa.id,pa.ad,pa.kisa,pa.renk,count(*) oy
       from oyun.oylar o join oyun.partiler pa on pa.id=o.parti_id
       where o.secim_id=m.id group by pa.id) x;
 select coalesce(jsonb_agg(jsonb_build_object(
   'kad',x.kad,'kisa',x.kisa,'renk',x.renk,'oy',x.oy,
   'yuzde',case when ct>0 then round(x.oy*100.0/ct,2) else 0 end
 ) order by x.oy desc,x.kad),'[]'::jsonb) into a
 from (select ad.id,pr.kad,pa.kisa,coalesce(pa.renk,'#9298ab') renk,
       count(o.secmen) oy
       from oyun.adaylar ad join oyun.profiller pr on pr.id=ad.user_id
       left join oyun.partiler pa on pa.id=ad.parti_id
       left join oyun.oylar o on o.secim_id=c.id and o.aday_id=ad.id
       where ad.secim_id=c.id group by ad.id,pr.kad,pa.kisa,pa.renk) x;
 select coalesce(jsonb_agg(jsonb_build_object(
   'ad',x.ad,'partiler',x.partiler,'oy',x.oy,
   'yuzde',case when mt>0 then round(x.oy*100.0/mt,2) else 0 end
 ) order by x.oy desc,x.ad),'[]'::jsonb) into it
 from (select z.ittifak_id,max(z.ittifak_ad) ad,
       array_agg(z.parti_kisa order by z.parti_kisa) partiler,
       (select count(*) from oyun.oylar o
        join oyun.secim_ittifak_anlik zz
        on zz.secim_id=m.id and zz.parti_id=o.parti_id
        where o.secim_id=m.id and zz.ittifak_id=z.ittifak_id) oy
       from oyun.secim_ittifak_anlik z
       where z.secim_id=m.id group by z.ittifak_id) x;
 for il in select i.id,i.ad
   from oyun.iller i where exists(
   select 1 from oyun.oylar o where o.il_id=i.id and o.secim_id in(m.id,c.id)
   ) order by i.ad loop
   select count(*) into itop from oyun.oylar o where o.secim_id=m.id and o.il_id=il.id;
   select count(*) into ict from oyun.oylar o where o.secim_id=c.id and o.il_id=il.id;
   select coalesce(jsonb_agg(jsonb_build_object(
     'ad',x.ad,'kisa',x.kisa,'renk',x.renk,'oy',x.oy,
     'yuzde',case when itop>0 then round(x.oy*100.0/itop,2) else 0 end
   ) order by x.oy desc,x.kisa),'[]'::jsonb) into pp
   from (select pa.id,pa.ad,pa.kisa,pa.renk,count(*) oy
         from oyun.oylar o join oyun.partiler pa on pa.id=o.parti_id
         where o.secim_id=m.id and o.il_id=il.id group by pa.id) x;
   select coalesce(jsonb_agg(jsonb_build_object(
     'kad',x.kad,'kisa',x.kisa,'oy',x.oy,
     'yuzde',case when ict>0 then round(x.oy*100.0/ict,2) else 0 end
   ) order by x.oy desc,x.kad),'[]'::jsonb) into aa
   from (select pr.kad,pa.kisa,count(*) oy
         from oyun.oylar o join oyun.adaylar ad on ad.id=o.aday_id
         join oyun.profiller pr on pr.id=ad.user_id
         left join oyun.partiler pa on pa.id=ad.parti_id
         where o.secim_id=c.id and o.il_id=il.id
         group by ad.id,pr.kad,pa.kisa) x;
   select coalesce(jsonb_agg(jsonb_build_object('ad',x.ad,'oy',x.oy)
        order by x.oy desc,x.ad),'[]'::jsonb) into ii
   from (select max(z.ittifak_ad) ad,count(*) oy
         from oyun.oylar o join oyun.secim_ittifak_anlik z
         on z.secim_id=m.id and z.parti_id=o.parti_id
         where o.secim_id=m.id and o.il_id=il.id
         group by z.ittifak_id) x;
   iller:=iller || jsonb_build_array(jsonb_build_object(
    'il_id',il.id,'il',il.ad,'toplam',itop,'cb_toplam',ict,
    'bagimsiz',(select count(*) from oyun.oylar o
                where o.secim_id=m.id and o.il_id=il.id and o.parti_id is null),
    'partiler',pp,'adaylar',aa,'ittifaklar',ii
   ));
 end loop;
 return jsonb_build_object('hazir',true,'donem',s.donem,
   'mv_secim_id',m.id,'cb_secim_id',c.id,
   'mv_toplam',mt,'cb_toplam',ct,
   'bagimsiz_oy',(select count(*) from oyun.oylar
      where secim_id=m.id and parti_id is null),
   'partiler',p,'adaylar',a,'ittifaklar',it,'iller',iller);
end $function$
;

REVOKE ALL ON FUNCTION public.secim_ayrintili_sonuclar(bigint) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.secim_ayrintili_sonuclar(bigint) TO authenticated;
NOTIFY pgrst,'reload schema';