-- Seçim Online 2026-11-09: serbest mahkeme para cezasi ve 1.000.000 TL tazminat üst sınırı
-- Eski mahkeme kararları ve fonksiyon imzaları korunur.
alter table oyun.adliye_davalar drop constraint if exists adliye_davalar_karar_check;
alter table oyun.adliye_davalar add constraint adliye_davalar_karar_check check (karar in
 ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur',
  'para_10b','para_50b','para_tutar','aday_yasagi','parti_para','dusme','tazminat','musadere'));
alter table oyun.adliye_karar_oy drop constraint if exists adliye_tazminat_oy_tutar_check;
alter table oyun.adliye_karar_oy add constraint adliye_tazminat_oy_tutar_check check (
 (karar in ('tazminat','para_tutar') and tazminat_tutar between 1000 and 1000000
  and tazminat_tutar=trunc(tazminat_tutar))
 or (karar not in ('tazminat','para_tutar') and tazminat_tutar is null));
CREATE OR REPLACE FUNCTION oyun.adliye_oy_say(p_dava bigint, t timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d oyun.adliye_davalar; heyet uuid[]; r record;
 bitis timestamptz; v_hakim uuid; v_ger text;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.durum<>'acik' then return false; end if;
 heyet:=oyun.dava_heyeti(d);
 if cardinality(heyet)=0 then return false; end if;
 select o.karar,coalesce(o.tazminat_tutar,0) tutar,
  coalesce(o.musadere_tutar,0) musadere_tutar,o.musadere_sorumlu,o.musadere_sirket,
  count(*) n,min(o.zaman) ilk into r from oyun.adliye_karar_oy o
  where o.dava_id=d.id and o.uye=any(heyet)
  group by o.karar,coalesce(o.tazminat_tutar,0),coalesce(o.musadere_tutar,0),o.musadere_sorumlu,o.musadere_sirket
  order by count(*) desc,min(o.zaman) limit 1;
 if r.karar is null or r.n<oyun.cogunluk(cardinality(heyet)) then return false; end if;
 select o.uye,o.gerekce into v_hakim,v_ger from oyun.adliye_karar_oy o
  where o.dava_id=d.id and o.karar=r.karar
   and coalesce(o.tazminat_tutar,0)=r.tutar
   and coalesce(o.musadere_tutar,0)=r.musadere_tutar
   and o.musadere_sorumlu is not distinct from r.musadere_sorumlu
   and o.musadere_sirket is not distinct from r.musadere_sirket
   and o.uye=any(heyet) order by o.zaman limit 1;
 update oyun.adliye_davalar set durum='karar',karar=r.karar,ilk_karar=r.karar,
  gerekce=v_ger,hakim=v_hakim,karar_at=t,
  tazminat_tutar=case when r.karar in ('tazminat','para_tutar') then r.tutar else null end,
  kesin=false,istinaf_son=t+make_interval(hours=>(select istinaf_saat from oyun.mahkeme_ayar))
  where id=d.id returning * into d;
 if r.karar='musadere' then
  insert into oyun.adliye_musadere(dava_id,sorumlu,sirket_id,tutar,aciklama)
   values(d.id,r.musadere_sorumlu,r.musadere_sirket,r.musadere_tutar,v_ger)
   on conflict(dava_id) do nothing;
 end if;
 bitis:=oyun.adliye_hafif_ceza(d,t);
 update oyun.adliye_davalar set ceza_bitis=bitis where id=d.id;
 perform oyun.bildir(x.id,format('Adliye #%s karari: %s. Istinaf yolu acik.',d.id,r.karar),t)
   from (select d.davaci id union select d.davali where d.davali is not null) x;
 perform oyun.adliye_duyur(v_hakim,
  format('Yuksek Mahkeme #%s: %s davasinda karar "%s" (%s/%s oy). Istinaf yolu acik. #Adliye',
   d.id,d.tur,r.karar,r.n,cardinality(heyet)),array['adliye'],t);
 return true;
end $function$;
CREATE OR REPLACE FUNCTION oyun.adliye_kesinlestir(p_dava bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d oyun.adliye_davalar; mv bigint; alinan numeric; davaci_kazandi boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.kesin then return; end if;
 if not d.ceza_uygulandi and d.af_at is null then
  if d.karar='vekillik_dusur' and d.davali is not null then
   select id into mv from oyun.makamlar where user_id=d.davali and tur='mv' and bit is null order by bas desc limit 1;
   if mv is not null then
    update oyun.makamlar set bit=t,bitis_neden='Adliye #'||d.id||' karari'
     where user_id=d.davali and bit is null and tur in ('mv','tbmm','bskv','grup_bskv');
   end if;
  elsif d.karar in ('para_10b','para_50b') and d.davali is not null then
   alinan:=oyun.adliye_tahsil(d.davali,case d.karar when 'para_10b' then 10000 else 50000 end,
    'Adliye #'||d.id||' para cezasi',t);
  elsif d.karar='para_tutar' and d.davali is not null then
   alinan:=oyun.adliye_tahsil(d.davali,least(coalesce(d.tazminat_tutar,0),1000000),
    'Adliye #'||d.id||' para cezasi',t);
  elsif d.karar='tazminat' and d.davali is not null then
   -- Odeme davanin kesinlesmesi ardindan takipli icra sistemiyle yapilir.
   null;
  elsif d.karar='aday_yasagi' then
   update oyun.profiller set adaylik_yasagi_bitis=greatest(coalesce(adaylik_yasagi_bitis,t),t+interval '30 days')
    where id=d.davali;
  elsif d.karar='parti_para' and d.davali_parti is not null then
   update oyun.partiler set kasa=kasa-least(kasa,25000) where id=d.davali_parti;
  end if;
 end if;
 davaci_kazandi:=d.karar not in ('beraat','dusme');
 if d.harc>0 and d.harc_durum='yatirildi' then
  if d.karar='dusme' or davaci_kazandi then
   perform oyun.para_islem(d.davaci,d.harc,'adliye','Adliye #'||d.id||' harc iadesi',t);
  end if;
  if davaci_kazandi then
   if d.davali is not null then
    perform oyun.adliye_tahsil(d.davali,d.harc,'Adliye #'||d.id||' yargilama harci',t);
   elsif d.davali_parti is not null then
    update oyun.partiler set kasa=kasa-least(kasa,d.harc) where id=d.davali_parti;
   end if;
  end if;
 end if;
 update oyun.adliye_davalar set kesin=true,ceza_uygulandi=true,
  mv_makam_id=coalesce(mv,mv_makam_id),
  harc_durum=case when harc>0 then case when karar='dusme' or davaci_kazandi then 'iade' else 'hazine' end end
  where id=d.id;
 if d.karar='tazminat' and d.davali is not null and d.af_at is null then
  perform oyun.adliye_tazminat_tahsil(d.id,t);
 end if;
 perform oyun.adliye_musadere_tahsil(d.id,t);
 perform oyun.bildir(x.id,format('Adliye #%s karari kesinlesti: %s.',d.id,d.karar),t)
  from (select d.davaci id union select d.davali where d.davali is not null) x;
end $function$;
CREATE OR REPLACE FUNCTION oyun.adliye_kurum_kesinlesme()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare tutar numeric:=0; alinan numeric:=0;
begin
 if new.davali_kurum_tur is null or new.af_at is not null then return new; end if;
 if new.karar='para_10b' then tutar:=10000;
 elsif new.karar='para_50b' then tutar:=50000;
 elsif new.karar='para_tutar' then tutar:=least(coalesce(new.tazminat_tutar,0),1000000);
 elsif new.karar='tazminat' then tutar:=least(coalesce(new.tazminat_tutar,0),1000000);
 end if;
 if tutar>0 then alinan:=oyun.adliye_kurum_kes(new.davali_kurum_tur,new.davali_kurum_id,tutar); end if;
 if new.karar='tazminat' and alinan>0 then
  perform oyun.para_islem(new.davaci,alinan,'adliye','Adliye #'||new.id||' kurum tazminatı',oyun.simdi());
  update oyun.adliye_davalar set tazminat_odenen=coalesce(tazminat_odenen,0)+alinan where id=new.id;
 elsif alinan>0 then
  update oyun.adliye_davalar set kurum_ceza_odenen=coalesce(kurum_ceza_odenen,0)+alinan where id=new.id;
 end if;
 if new.karar not in ('beraat','dusme') and new.harc>0 then
  perform oyun.adliye_kurum_kes(new.davali_kurum_tur,new.davali_kurum_id,new.harc);
 end if;
 perform oyun.bildir(q.id,format('Adliye #%s kurum kararı kesinleşti: %s. Tahsil: %s TL.',new.id,new.karar,alinan),oyun.simdi())
  from oyun.profiller q where oyun.adliye_kurum_yetkili(new.davali_kurum_tur,new.davali_kurum_id,q.id);
 return new;
end $function$;
CREATE OR REPLACE FUNCTION oyun.adliye_karar_agirlik(p_karar text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select case p_karar when 'beraat' then 0 when 'uyari' then 1 when 'sustur_1s' then 2 when 'sustur_1g' then 3 when 'para_10b' then 4
  when 'sustur_1h' then 5 when 'parti_para' then 5 when 'para_50b' then 6 when 'para_tutar' then 6 when 'tazminat' then 6 when 'musadere' then 7
  when 'aday_yasagi' then 8 when 'vekillik_dusur' then 9 else 0 end
$function$;
CREATE OR REPLACE FUNCTION oyun.adliye_tazminat_tahsil(p_dava bigint, t timestamp with time zone)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE d oyun.adliye_davalar; alacakli uuid;
 kalan numeric; al numeric; mevcut numeric; toplam numeric:=0; adet numeric; r record;
BEGIN
 SELECT * INTO d FROM oyun.adliye_davalar WHERE id=p_dava FOR UPDATE;
 IF d.id IS NULL OR NOT d.kesin OR d.durum<>'karar' OR d.karar<>'tazminat'
  OR d.davali IS NULL OR d.af_at IS NOT NULL THEN RETURN 0; END IF;
 SELECT coalesce((SELECT a.alacakli FROM oyun.adliye_tazminat_alacakli a WHERE a.dava_id=d.id),d.davaci)
 INTO alacakli;
 IF alacakli IS NULL OR alacakli=d.davali THEN
   RAISE EXCEPTION 'Alacakli hesabini dogrulayin: dava #%s',p_dava;
 END IF;
 -- Dava #22 icin faydalanici yanlis kaydedilmis dilekce sahibine aktarmayi engelle.
 IF d.id=22 AND NOT EXISTS(SELECT 1 FROM oyun.adliye_tazminat_alacakli a WHERE a.dava_id=d.id) THEN
   RAISE EXCEPTION 'Dava #22 alacakli eslestirmesi bulunamadi.';
 END IF;
 kalan:=greatest(0,least(coalesce(d.tazminat_tutar,0),1000000)-coalesce(d.tazminat_odenen,0));
 IF kalan<=0 THEN RETURN 0; END IF;

 PERFORM oyun.cuzdanim(d.davali);
 SELECT greatest(0,coalesce(para,0)) INTO mevcut FROM oyun.cuzdan WHERE user_id=d.davali FOR UPDATE;
 al:=least(kalan,floor(coalesce(mevcut,0)));
 IF al>0 THEN
   PERFORM oyun.para_islem(d.davali,-al,'adliye',format('Adliye #%s tazminat tahsili',p_dava),t);
   INSERT INTO oyun.adliye_tazminat_tahsil_kayit(dava_id,borclu,alacakli,kaynak,tutar,zaman)
   VALUES(p_dava,d.davali,alacakli,'cuzdan',al,t);
   toplam:=toplam+al; kalan:=kalan-al;
 END IF;

 IF kalan>0 THEN
  SELECT greatest(0,coalesce(vadesiz,0)) INTO mevcut
   FROM oyun.banka_musteri WHERE user_id=d.davali FOR UPDATE;
  al:=least(kalan,floor(coalesce(mevcut,0)));
  IF al>0 THEN
    UPDATE oyun.banka_musteri SET vadesiz=vadesiz-al WHERE user_id=d.davali;
    INSERT INTO oyun.banka_hareket(user_id,zaman,hesap,tutar,aciklama)
    VALUES(d.davali,t,'vadesiz',-al,format('Adliye #%s tazminat icra tahsili',p_dava));
    INSERT INTO oyun.adliye_tazminat_tahsil_kayit(dava_id,borclu,alacakli,kaynak,tutar,zaman)
    VALUES(p_dava,d.davali,alacakli,'vadesiz',al,t);
    toplam:=toplam+al; kalan:=kalan-al;
  END IF;
 END IF;

 IF kalan>0 THEN
  FOR r IN
    SELECT p.kod,p.miktar,p.maliyet,v.fiyat
    FROM oyun.piyasa_pozisyon p JOIN oyun.piyasa_varlik v ON v.kod=p.kod
    WHERE p.user_id=d.davali AND p.miktar>0 AND v.fiyat>0
    ORDER BY p.kod FOR UPDATE OF p
  LOOP
    EXIT WHEN kalan<=0;
    adet:=least(r.miktar,ceil(kalan/r.fiyat*100000000)/100000000);
    al:=least(kalan,round(adet*r.fiyat));
    IF adet<=0 OR al<=0 THEN CONTINUE; END IF;
    UPDATE oyun.piyasa_pozisyon SET miktar=greatest(0,miktar-adet),
      maliyet=CASE WHEN miktar-adet<0.00000001 THEN 0
          ELSE round(maliyet*(miktar-adet)/miktar,2) END
    WHERE user_id=d.davali AND kod=r.kod;
    INSERT INTO oyun.piyasa_islem(user_id,kod,yon,miktar,fiyat,brut,komisyon,zaman)
    VALUES(d.davali,r.kod,'sat',adet,r.fiyat,al,0,t);
    INSERT INTO oyun.adliye_tazminat_tahsil_kayit(dava_id,borclu,alacakli,kaynak,kod,miktar,tutar,zaman)
    VALUES(p_dava,d.davali,alacakli,'piyasa',r.kod,adet,al,t);
    toplam:=toplam+al; kalan:=kalan-al;
  END LOOP;
 END IF;

 IF toplam>0 THEN
  PERFORM oyun.para_islem(alacakli,toplam,'adliye',format('Adliye #%s tazminat odemesi',p_dava),t);
  UPDATE oyun.adliye_davalar SET tazminat_odenen=coalesce(tazminat_odenen,0)+toplam
    WHERE id=p_dava;
  PERFORM oyun.bildir(alacakli,format('Adliye #%s: %s TL tazminat hesabina yatirildi. Kalan: %s TL',p_dava,toplam,kalan),t);
  PERFORM oyun.bildir(d.davali,format('Adliye #%s: %s TL tazminat tahsil edildi. Kalan: %s TL',p_dava,toplam,kalan),t);
 END IF;
 RETURN toplam;
END $function$;
CREATE OR REPLACE FUNCTION public.adliye_tazminat_oy(p_dava bigint, p_tutar numeric, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 t timestamptz:=oyun.simdi(); cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalniz Yuksek Mahkeme uyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' or d.tur<>'tazminat' or (d.davali is null and (d.davali_kurum_tur is null or d.davali_kurum_tur='makam')) then
  raise exception 'Bu dosyada tazminata hukmedilemez.'; end if;
 if not p.id=any(oyun.dava_heyeti(d)) then raise exception 'Dava tarafi hakim oy kullanamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma suresini bekleyin.'; end if;
 if p_tutar is null or p_tutar<1000 or p_tutar>least(coalesce(d.tazminat_talep,0),1000000) or p_tutar<>trunc(p_tutar) then
  raise exception 'Karar tutari 1.000 TL ile davacinin talebi arasinda tam sayi olmali.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekceli oy 20-2000 karakter olmali.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,tazminat_tutar,gerekce,zaman)
 values(d.id,p.id,'tazminat',p_tutar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar='tazminat',tazminat_tutar=excluded.tazminat_tutar,
  gerekce=excluded.gerekce,zaman=excluded.zaman,musadere_tutar=null,musadere_sorumlu=null,musadere_sirket=null;
 cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',cikti,'tutar',p_tutar);
end $function$;
CREATE OR REPLACE FUNCTION public.adliye_tazminat_davasi_ac(p_hedef text, p_talep numeric, p_iddia text, p_delil text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); r jsonb; yeni bigint;
begin
 if p_talep is null or p_talep < 1000 or p_talep > 1000000 or p_talep <> trunc(p_talep) then
   raise exception 'Tazminat talebi 1.000–1.000.000 TL arasında tam sayı olmalı.'; end if;
 perform set_config('oyun.tazminat_davasi','1',true);
 r:=public.adliye_dava_ac('oyuncu',p_hedef,'diger',p_iddia,p_delil,null);
 perform set_config('oyun.tazminat_davasi','',true);
 yeni:=(r->>'id')::bigint;
 update oyun.adliye_davalar set tur='tazminat',tazminat_talep=p_talep where id=yeni and davaci=p.id;
 return r || jsonb_build_object('tur','tazminat','talep',p_talep);
end $function$;
CREATE OR REPLACE FUNCTION public.adliye_kurum_dava_ac(p_hedef_tur text, p_hedef text, p_tur text, p_iddia text, p_delil text DEFAULT ''::text, p_davaci_parti bigint DEFAULT NULL::bigint, p_tazminat_talep numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); kurum_ad text; t timestamptz:=oyun.simdi(); yeni bigint;
 h numeric:=coalesce((select harc from oyun.mahkeme_ayar),0); sure int:=coalesce((select avukat_savunma_saat from oyun.ayarlar where id=1),24);
begin
 if p_hedef_tur not in ('sirket','dernek','belediye','makam','bakanlik','gazete') then raise exception 'Kurum türü geçersiz.'; end if;
 kurum_ad:=oyun.adliye_kurum_adi(p_hedef_tur,p_hedef);
 if kurum_ad is null then raise exception 'Kurum bulunamadı veya faal değil.'; end if;
 if oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,p.id) then raise exception 'Temsil ettiğiniz kuruma dava açamazsınız.'; end if;
 if p_tur not in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger','tazminat') then raise exception 'Dava türü geçersiz.'; end if;
 if char_length(trim(coalesce(p_iddia,''))) not between 20 and 1600 then raise exception 'İddia 20–1600 karakter olmalıdır.'; end if;
 if char_length(coalesce(p_delil,''))>1600 then raise exception 'Delil en fazla 1600 karakter olabilir.'; end if;
 if p_tur='tazminat' and (p_hedef_tur='makam' or p_tazminat_talep is null or
  p_tazminat_talep<1000 or p_tazminat_talep>1000000 or p_tazminat_talep<>trunc(p_tazminat_talep))
  then raise exception 'Tazminat için 1.000–1.000.000 TL arasında tam sayı tutar gerekir; makamın kasası yoktur.'; end if;
 if p_davaci_parti is not null and not exists(select 1 from oyun.partiler pa where pa.id=p_davaci_parti and not pa.kapali and pa.gb=p.id)
  then raise exception 'Parti adına davayı yalnız genel başkan açabilir.'; end if;
 if (select count(*) from oyun.adliye_davalar where davaci=p.id and durum='acik')>=3 then raise exception 'Aynı anda en fazla üç açık davan olabilir.'; end if;
 if exists(select 1 from oyun.adliye_davalar where davaci=p.id and acilis>t-interval '10 minutes') then raise exception 'Yeni dava açmadan önce 10 dakika bekleyin.'; end if;
 if h>0 then perform oyun.para_islem(p.id,-h,'adliye','Dava harcı',t); end if;
 insert into oyun.adliye_davalar(davaci,davaci_parti,davali_kurum_tur,davali_kurum_id,davali_kurum_ad,tur,iddia,delil,acilis,savunma_son,karar_son,harc,harc_durum,kesin,tazminat_talep)
 values(p.id,p_davaci_parti,p_hedef_tur,p_hedef,kurum_ad,p_tur,trim(p_iddia),coalesce(p_delil,''),t,t+make_interval(hours=>sure),
  t+make_interval(hours=>sure)+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)),
  h,case when h>0 then 'yatirildi' end,false,case when p_tur='tazminat' then p_tazminat_talep end) returning id into yeni;
 perform oyun.bildir(q.id,format('Adliye #%s: %s aleyhine dava açıldı. Kurum yetkilisi %s saat içinde doğrudan savunma yazabilir veya isteğe bağlı avukat tutabilir.',yeni,kurum_ad,sure),t)
  from oyun.profiller q where oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.id) and q.id<>p.id;
 perform oyun.bildir(q.user_id,format('Yüksek Mahkeme: yeni kurum davası #%s',yeni),t)
  from oyun.mahkeme_uye q where q.user_id is not null and q.user_id<>p.id and not oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,q.user_id);
 return jsonb_build_object('tamam',true,'id',yeni,'harc',h);
end $function$;
CREATE OR REPLACE FUNCTION public.hukuk_is_olustur(p_tur text, p_parti bigint DEFAULT NULL::bigint, p_hedef_tur text DEFAULT NULL::text, p_hedef text DEFAULT NULL::text, p_dava_tur text DEFAULT NULL::text, p_tazminat numeric DEFAULT NULL::numeric, p_secim bigint DEFAULT NULL::bigint, p_pkd bigint DEFAULT NULL::bigint, p_metin text DEFAULT ''::text, p_delil text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); m text:=trim(coalesce(p_metin,'')); dl text:=trim(coalesce(p_delil,'')); had text; u oyun.profiller; s oyun.secimler; k oyun.pkd_dava; pa oyun.partiler; yid bigint; hp bigint; v_eng text;
begin
 if p_tur not in ('dava','secim_itiraz','pkd_savunma') then raise exception 'İş türü geçersiz.'; end if;
 if (select count(*) from oyun.hukuk_isleri where muvekkil=p.id and durum in ('avukat_bekliyor','vekil_atandi'))>=3 then raise exception 'Aynı anda en fazla üç açık hukuki işin olabilir.'; end if;
 if p_parti is not null then
  select * into pa from oyun.partiler where id=p_parti and not kapali;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if pa.gb is distinct from p.id and not (p_tur='pkd_savunma' and coalesce(pa.gb_vekil=p.id,false)) then raise exception 'Parti adına avukatı yalnız genel başkan tutabilir.'; end if;
 end if;
 if p_tur='dava' then
  if p_dava_tur not in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger','tazminat') then raise exception 'Dava türü geçersiz.'; end if;
  if char_length(m) not between 20 and 1600 then raise exception 'İddia 20–1600 karakter olmalı.'; end if;
  if char_length(dl)>1600 then raise exception 'Delil en fazla 1600 karakter olabilir.'; end if;
  if p_hedef_tur='oyuncu' then
   select * into u from oyun.profiller where lower(kad)=lower(trim(coalesce(p_hedef,''))) and not yasakli;
   if u.id is null then raise exception 'Davalı oyuncu bulunamadı.'; end if;
   if u.id=p.id then raise exception 'Kendinize dava açamazsınız.'; end if;
   v_eng:=oyun.dokunulmazlik_engel(u.id,p_dava_tur);
   if v_eng is not null then raise exception '%',v_eng; end if;
   had:=u.kad;
  elsif p_hedef_tur='parti' then
   begin hp:=p_hedef::bigint; exception when others then raise exception 'Geçersiz parti.'; end;
   select ad into had from oyun.partiler where id=hp and not kapali;
   if had is null then raise exception 'Parti bulunamadı.'; end if;
   if hp=p_parti then raise exception 'Bir parti kendisine dava açamaz.'; end if;
  elsif p_hedef_tur in ('sirket','dernek','belediye','makam','bakanlik','gazete') then
   had:=oyun.adliye_kurum_adi(p_hedef_tur,p_hedef);
   if had is null then raise exception 'Kurum bulunamadı veya faal değil.'; end if;
   if oyun.adliye_kurum_yetkili(p_hedef_tur,p_hedef,p.id) then raise exception 'Temsil ettiğiniz kuruma dava açamazsınız.'; end if;
  else raise exception 'Davalı türü geçersiz.'; end if;
  if p_dava_tur='tazminat' then
   if p_hedef_tur='parti' or p_hedef_tur='makam' then raise exception 'Tazminat partiye ya da makama karşı istenemez.'; end if;
   if p_hedef_tur='oyuncu' and p_parti is not null then raise exception 'Oyuncudan tazminatı yalnız kendi adına isteyebilirsin.'; end if;
   if p_tazminat is null or p_tazminat<1000 or p_tazminat>1000000 or p_tazminat<>trunc(p_tazminat) then raise exception 'Tazminat talebi 1.000–1.000.000 ₺ arasında tam sayı olmalı.'; end if;
  end if;
  insert into oyun.hukuk_isleri(tur,muvekkil,parti_id,hedef_tur,hedef,hedef_ad,dava_tur,tazminat_talep,metin,delil)
  values('dava',p.id,p_parti,p_hedef_tur,case when p_hedef_tur='oyuncu' then u.kad else p_hedef end,had,p_dava_tur,case when p_dava_tur='tazminat' then p_tazminat end,m,dl) returning id into yid;
 elsif p_tur='secim_itiraz' then
  if p_parti is null then raise exception 'İtiraz eden partiyi seç.'; end if;
  select * into s from oyun.secimler where id=p_secim;
  if s.id is null or s.sonuc is null or s.sonuc_at is null or now()<s.sonuc_at then raise exception 'Yalnız sonuçlanmış seçimlere itiraz edilebilir.'; end if;
  if now()>s.sonuc_at+interval '48 hours' then raise exception '48 saatlik itiraz süresi doldu.'; end if;
  if exists(select 1 from oyun.hukuk_isleri where tur='secim_itiraz' and secim_id=s.id and parti_id=p_parti and durum in ('avukat_bekliyor','vekil_atandi')) then raise exception 'Bu seçim için bekleyen bir itiraz işiniz var.'; end if;
  if char_length(m) not between 30 and 1600 then raise exception 'İtiraz gerekçesi 30-1600 karakter olmalı.'; end if;
  if char_length(dl)>3000 then raise exception 'Deliller en fazla 3000 karakter olabilir.'; end if;
  insert into oyun.hukuk_isleri(tur,muvekkil,parti_id,secim_id,hedef_ad,metin,delil)
  values('secim_itiraz',p.id,p_parti,s.id,format('Seçim #%s · %s · %s',s.id,s.tur,s.donem),m,dl) returning id into yid;
 else
  select * into k from oyun.pkd_dava where id=p_pkd;
  if k.id is null or k.durum<>'savunma' or now()>=k.savunma_son then raise exception 'Bu parti kapatma davası savunma aşamasında değil.'; end if;
  select * into pa from oyun.partiler where id=k.parti_id;
  if p.id is distinct from pa.gb and p.id is distinct from pa.gb_vekil then raise exception 'Bu iş için avukatı davalı partinin genel başkanı tutar.'; end if;
  if char_length(m) not between 50 and 3000 then raise exception 'Savunma taslağı 50-3000 karakter olmalı.'; end if;
  insert into oyun.hukuk_isleri(tur,muvekkil,parti_id,pkd_id,hedef_ad,metin)
  values('pkd_savunma',p.id,pa.id,k.id,'Parti kapatma davası #'||k.id,m) returning id into yid;
 end if;
 perform oyun.bildir(b.user_id,format('Yeni hukuki iş #%s avukat arıyor (%s). Türkiye Barosu > Davalar bölümünden teklif verebilirsin.',yid,
   case p_tur when 'dava' then 'dava açılışı' when 'secim_itiraz' then 'seçim itirazı' else 'parti kapatma savunması' end),oyun.simdi())
  from oyun.baro_uyeleri b where b.durum='aktif' and b.user_id<>p.id and oyun.avukat_mi(b.user_id);
 return jsonb_build_object('tamam',true,'id',yid);
end $function$;
create or replace function public.adliye_para_oy(p_dava bigint,p_tutar numeric,p_gerekce text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 t timestamptz:=oyun.simdi(); cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava açık değil.'; end if;
 if d.tur='tazminat' then raise exception 'Tazminat davalarında davacıya ödenecek tutar için tazminat kararı seçin.'; end if;
 if d.davali is null and (d.davali_kurum_tur is null or d.davali_kurum_tur='makam') then
  raise exception 'Bu davalıya para cezası verilemez.'; end if;
 if not p.id=any(oyun.dava_heyeti(d)) then raise exception 'Dava tarafı veya vekili hâkim oy kullanamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma süresini bekleyin.'; end if;
 if p_tutar is null or p_tutar<1000 or p_tutar>1000000 or p_tutar<>trunc(p_tutar) then
  raise exception 'Para cezası 1.000–1.000.000 TL arasında tam sayı olmalı.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekçe 20–2000 karakter olmalı.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,tazminat_tutar,gerekce,zaman)
 values(d.id,p.id,'para_tutar',p_tutar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar='para_tutar',
  tazminat_tutar=excluded.tazminat_tutar,gerekce=excluded.gerekce,zaman=excluded.zaman,
  musadere_tutar=null,musadere_sorumlu=null,musadere_sirket=null;
 cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',cikti,'tutar',p_tutar);
end $$;
revoke all on function public.adliye_para_oy(bigint,numeric,text) from public,anon;
grant execute on function public.adliye_para_oy(bigint,numeric,text) to authenticated;
