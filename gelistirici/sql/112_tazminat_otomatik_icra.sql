-- Kesinlesmis 225.000 TL tazminat hukmunun tahsili ve takip sistemi.
-- Onay/bozma istinaf kararina dokunmaz; sadece kesinlesmis hukumleri icra eder.
-- Dava #22 hukumde alacakli Mehmet Emin Celik; basvurucu farklidir.

CREATE TABLE IF NOT EXISTS oyun.adliye_tazminat_alacakli(
 dava_id bigint primary key references oyun.adliye_davalar(id),
 alacakli uuid not null references oyun.profiller(id),
 gerekce text not null,
 kayit_at timestamptz not null default now()
);
CREATE TABLE IF NOT EXISTS oyun.adliye_tazminat_tahsil_kayit(
 id bigint generated always as identity primary key,
 dava_id bigint not null references oyun.adliye_davalar(id),
 borclu uuid not null references oyun.profiller(id),
 alacakli uuid not null references oyun.profiller(id),
 kaynak text not null check (kaynak IN ('cuzdan','vadesiz','piyasa')),
 kod text,miktar numeric,tutar numeric not null check (tutar>0),
 zaman timestamptz not null default now()
);
CREATE INDEX IF NOT EXISTS adliye_tazminat_kayit_dava ON oyun.adliye_tazminat_tahsil_kayit(dava_id);
ALTER TABLE oyun.adliye_tazminat_alacakli ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.adliye_tazminat_tahsil_kayit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.adliye_tazminat_alacakli,oyun.adliye_tazminat_tahsil_kayit FROM public,anon,authenticated;

INSERT INTO oyun.adliye_tazminat_alacakli(dava_id,alacakli,gerekce)
SELECT d.id,p.id,'Dava #22 gerekceli hukumde odeme Mehmet Emin Celik icin; basvuruyu farkli oyuncu yapmis.'
FROM oyun.adliye_davalar d JOIN oyun.profiller p ON p.kad='mehmetemincelik'
WHERE d.id=22 AND d.karar='tazminat' AND d.tazminat_tutar=225000
 AND d.gerekce ILIKE '%Mehmet Emin Çelik%' AND d.iddia ILIKE '%Davacı: Mehmet Emin Çelik%'
 AND coalesce(d.tazminat_odenen,0)=0
ON CONFLICT(dava_id) DO NOTHING;

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
 kalan:=greatest(0,least(coalesce(d.tazminat_tutar,0),500000)-coalesce(d.tazminat_odenen,0));
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

CREATE OR REPLACE FUNCTION oyun.adliye_tazminat_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE r record; n integer:=0;
BEGIN
 FOR r IN SELECT id FROM oyun.adliye_davalar
   WHERE kesin AND durum='karar' AND karar='tazminat'
     AND af_at IS NULL AND coalesce(tazminat_odenen,0)<coalesce(tazminat_tutar,0)
   ORDER BY id
 LOOP
   IF oyun.adliye_tazminat_tahsil(r.id,oyun.simdi())>0 THEN n:=n+1; END IF;
 END LOOP;
 RETURN n;
END $function$;

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
  elsif d.karar in ('para_10b','para_50b') then
   alinan:=oyun.adliye_tahsil(d.davali,case d.karar when 'para_10b' then 10000 else 50000 end,
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

REVOKE ALL ON FUNCTION oyun.adliye_tazminat_tahsil(bigint,timestamptz),
 oyun.adliye_tazminat_tick(),oyun.adliye_kesinlestir(bigint,timestamptz)
 FROM public,anon,authenticated;
SELECT cron.schedule('adliye-tazminat-tahsil','*/5 * * * *','select oyun.adliye_tazminat_tick()');
