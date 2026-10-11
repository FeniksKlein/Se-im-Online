-- 2026 Türkiye uygulaması: alıcı %2 + satıcı %2 tapu harcı, yıllık emlak vergisi ve iki taksit.
-- Mevcut cüzdan/tapu/işlem kayıtları değişmez. Eski tahakkuk etmiş borçlar korunur.
CREATE OR REPLACE FUNCTION oyun.mulk_tapu_bedel_ode(p_alici uuid, p_satici uuid, p_fiyat numeric, p_mulk bigint, p_t timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $tapu$
DECLARE h numeric:=round(p_fiyat*.02,2); para numeric;
BEGIN
 IF p_fiyat IS NULL OR p_fiyat<=0 OR p_alici IS NULL OR p_alici=p_satici THEN RAISE EXCEPTION 'Geçersiz tapu işlemi'; END IF;
 SELECT c.para INTO para FROM oyun.cuzdan c WHERE c.user_id=p_alici FOR UPDATE;
 IF coalesce(para,0) < p_fiyat+h THEN
   RAISE EXCEPTION 'Alıcı bakiye yetersiz. Satış: % TL + alıcı tapu harcı: % TL (%2), toplam: % TL. Mevcut: % TL',
      oyun.tl(p_fiyat),oyun.tl(h),oyun.tl(p_fiyat+h),oyun.tl(coalesce(para,0));
 END IF;
 PERFORM oyun.para_islem(p_alici,-(p_fiyat+h),'emlak',
    format('Tapu devir bedeli ve alıcı %%2 harcı · mülk #%s',p_mulk),p_t,h);
 PERFORM oyun.para_islem(p_satici,p_fiyat-h,'emlak',
    format('Mülk satışı ve satıcı %%2 tapu harcı · mülk #%s',p_mulk),p_t,h);
 UPDATE oyun.ulke SET hazine=hazine+2*h/1000000.0 WHERE id=1;
END $tapu$;
REVOKE ALL ON FUNCTION oyun.mulk_tapu_bedel_ode(uuid,uuid,numeric,bigint,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.mulk_il_buyuksehir(p_il smallint)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO '' AS $$
 SELECT p_il IN (1,6,7,9,10,16,20,21,25,26,27,31,33,34,35,38,41,42,44,45,46,47,48,52,54,55,59,61,63,65)
$$;
CREATE OR REPLACE FUNCTION oyun.mulk_yillik_vergi_hesap(p_il smallint, p_tip text)
RETURNS numeric LANGUAGE sql STABLE SET search_path TO '' AS $$
 -- Oyun şehir rayici, vergi değeri için yaklaşık matrah kabul edilir; gerçek hayatta belediye vergi değeri esastır.
 SELECT round(oyun.mulk_il_bedel(p_il,p_tip) *
   (CASE WHEN p_tip='dukkan' THEN .002 ELSE .001 END) *
   (CASE WHEN oyun.mulk_il_buyuksehir(p_il) THEN 2 ELSE 1 END),2)
$$;
CREATE OR REPLACE FUNCTION oyun.mulk_yillik_vergi_tutar(p_mulk bigint)
RETURNS numeric LANGUAGE sql STABLE SET search_path TO '' AS $$
 SELECT oyun.mulk_yillik_vergi_hesap(m.il_id,m.tip)
 FROM oyun.yatirim_mulkleri m WHERE m.id=p_mulk
$$;
-- Eski istemci/sunucu çağrıları bozulmasın; değer artık YILLIKTIR.
CREATE OR REPLACE FUNCTION oyun.mulk_haftalik_vergi_tutar(p_mulk bigint)
RETURNS numeric LANGUAGE sql STABLE SET search_path TO '' AS $$
 SELECT oyun.mulk_yillik_vergi_tutar(p_mulk)
$$;
CREATE OR REPLACE FUNCTION oyun.mulk_vergi_oran(p_il smallint)
RETURNS numeric LANGUAGE sql STABLE SET search_path TO '' AS $$
 SELECT CASE WHEN oyun.mulk_il_buyuksehir(p_il) THEN .2 ELSE .1 END
$$;
CREATE OR REPLACE FUNCTION oyun.mulk_vergi_ilk_vade(p_alis timestamptz)
RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path TO '' AS $$
 SELECT make_timestamptz(extract(year from p_alis AT TIME ZONE 'Europe/Istanbul')::int+1,5,31,23,59,0,'Europe/Istanbul')
$$;
CREATE OR REPLACE FUNCTION oyun.mulk_vergi_sonraki_vade(p_vade timestamptz)
RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path TO '' AS $$
 SELECT CASE WHEN extract(month from p_vade AT TIME ZONE 'Europe/Istanbul')=5
 THEN make_timestamptz(extract(year from p_vade AT TIME ZONE 'Europe/Istanbul')::int,11,30,23,59,0,'Europe/Istanbul')
 ELSE make_timestamptz(extract(year from p_vade AT TIME ZONE 'Europe/Istanbul')::int+1,5,31,23,59,0,'Europe/Istanbul') END
$$;

CREATE OR REPLACE FUNCTION oyun.mulk_haftalik_vergi(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $yillik$
DECLARE m record; t timestamptz:=oyun.simdi(); v timestamptz;
  yil_vergi numeric; tahakkuk numeric; odeme numeric; hazir numeric; donem integer;
BEGIN
 FOR m IN SELECT m.id,m.il_id,m.vergi_sonraki,m.vergi_borc,m.satin_alma,i.ad il_ad
          FROM oyun.yatirim_mulkleri m JOIN oyun.iller i ON i.id=m.il_id
          WHERE m.user_id=p_user AND (m.vergi_sonraki<=t OR m.vergi_borc>0 OR m.vergi_sonraki IS NULL)
          ORDER BY m.id FOR UPDATE OF m LOOP
   v:=coalesce(m.vergi_sonraki,oyun.mulk_vergi_ilk_vade(m.satin_alma));
   yil_vergi:=coalesce(oyun.mulk_yillik_vergi_tutar(m.id),0);
   tahakkuk:=0;donem:=0;
   WHILE v<=t AND donem<40 LOOP
     tahakkuk:=tahakkuk+round(yil_vergi/2,2);
     v:=oyun.mulk_vergi_sonraki_vade(v);
     donem:=donem+1;
   END LOOP;
   hazir:=greatest(0,coalesce((SELECT para FROM oyun.cuzdan WHERE user_id=p_user),0));
   odeme:=least(coalesce(m.vergi_borc,0)+tahakkuk,floor(hazir));
   UPDATE oyun.yatirim_mulkleri
      SET vergi_borc=greatest(0,coalesce(m.vergi_borc,0)+tahakkuk-odeme),vergi_sonraki=v
      WHERE id=m.id;
   IF odeme>0 THEN
     PERFORM oyun.para_islem(p_user,-odeme,'emlak_vergi',
       format('%s Belediyesi yıllık emlak vergisi (%s taksit) · mülk #%s',m.il_ad,donem,m.id),t,odeme);
     UPDATE oyun.il_durum SET kasa=coalesce(kasa,0)+odeme/1e9 WHERE il_id=m.il_id;
     INSERT INTO oyun.emlak_vergi_tahsilat(il_id,user_id,mulk_id,tutar,zaman)
        VALUES(m.il_id,p_user,m.id,odeme,t);
   END IF;
 END LOOP;
END $yillik$;

CREATE OR REPLACE FUNCTION public.mulk_ilan_satin_al(p_ilan bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); a oyun.mulk_ilan%rowtype; m oyun.yatirim_mulkleri%rowtype;
 v_satis_vergisi numeric; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 select * into a from oyun.mulk_ilan where id=p_ilan for update;
 if not found or a.durum<>'acik' then raise exception 'İlan artık açık değil'; end if;
 if a.satici=u then raise exception 'Kendi mülkünü satın alamazsın'; end if;
 select * into m from oyun.yatirim_mulkleri where id=a.mulk_id for update;
 if not found or m.user_id<>a.satici then raise exception 'Satıcı artık mülkün sahibi değil'; end if;
 perform oyun.mulk_kira_tahsil(a.satici);
 perform oyun.mulk_tapu_bedel_ode(u,a.satici,a.fiyat,a.mulk_id,t);
 update oyun.yatirim_mulkleri set user_id=u,satin_alma=t,alis_bedeli=a.fiyat,
   sonraki_kira=t+interval '7 days',toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=u,kapanma=t where id=a.id;
 perform oyun.bildir(a.satici,'Satıştaki mülkün satıldı. Satıcı tapu harcı %2 kesildi; alıcı ayrıca %2 ödedi.',t);
 return public.mulk_pazar();
end $function$;

CREATE OR REPLACE FUNCTION oyun._emlak_pazarlik_tamamla(p_teklif bigint, p_fiyat numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare z oyun.emlak_pazarlik;i oyun.mulk_ilan; m oyun.yatirim_mulkleri;
  vergi numeric;t timestamptz:=oyun.simdi();
begin
 select * into z from oyun.emlak_pazarlik where id=p_teklif for update;
 if z.id is null or z.durum not in ('bekliyor','karsi') then raise exception 'Teklif artık geçerli değil.'; end if;
 if p_fiyat is null or p_fiyat<10000 or p_fiyat>1000000000 then raise exception 'Geçersiz teklif bedeli.'; end if;
 select * into i from oyun.mulk_ilan where id=z.ilan_id for update;
 if i.id is null or i.durum<>'acik' or i.satici<>z.satici then raise exception 'İlan artık geçerli değil.'; end if;
 select * into m from oyun.yatirim_mulkleri where id=i.mulk_id for update;
 if m.id is null or m.user_id<>i.satici then raise exception 'Mülk artık satışta değil.'; end if;
 if z.alici=z.satici then raise exception 'Kendi mülkünü alamazsın.'; end if;
 perform oyun.mulk_kira_tahsil(z.satici);
 perform oyun.mulk_tapu_bedel_ode(z.alici,z.satici,p_fiyat,i.mulk_id,t);
 update oyun.yatirim_mulkleri set user_id=z.alici,satin_alma=t,alis_bedeli=p_fiyat,sonraki_kira=t+interval '7 days',
   toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=z.alici,kapanma=t where id=i.id;
 update oyun.emlak_pazarlik set durum='kabul',sonuc_at=t where id=z.id;
 update oyun.emlak_pazarlik set durum='iptal',sonuc_at=t where ilan_id=i.id and id<>z.id and durum in ('bekliyor','karsi');
 perform oyun.bildir(z.alici,format('Pazarlık kabul edildi! Mülk #%s %s ₺ karşılığında senin.',i.mulk_id,oyun.tl(p_fiyat)),t);
 perform oyun.bildir(z.satici,format('Mülk #%s %s ₺ karşılığında satıldı; %%2 satıcı tapu harcı kesildi; alıcı ayrıca %%2 ödedi.',i.mulk_id,oyun.tl(p_fiyat)),t);
end $function$;

CREATE OR REPLACE FUNCTION public.mulk_il_satin_al(p_tip text, p_il integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_il smallint := p_il; u uuid := auth.uid(); t timestamptz := oyun.simdi(); c oyun.iller; f numeric; k numeric; yeni bigint; mevcut int;
  tipad text := case p_tip when 'daire' then 'daire' when 'dukkan' then 'dükkân' when 'villa' then 'villa' end;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu profili gerekli.'; end if;
  if tipad is null then raise exception 'Geçersiz mülk türü.'; end if;
  if v_il is null then raise exception 'Satın alacağın ili seç.'; end if;
  select * into c from oyun.iller where id = v_il for update;   -- aynı ilde eş zamanlı alımlar sırayla işlenir
  if c.id is null then raise exception 'İl bulunamadı.'; end if;
  select count(*) into mevcut from oyun.yatirim_mulkleri where il_id = v_il and tip = p_tip;
  if mevcut >= oyun.mulk_il_kota(v_il, p_tip) then
    raise exception '% ilinde satılık yeni % kalmadı. Oyuncuların ilanlarına bakabilirsin.', c.ad, tipad;
  end if;
  f := oyun.mulk_il_bedel(v_il, p_tip); k := oyun.mulk_il_kira(v_il, p_tip);
  perform oyun.mulk_kira_tahsil(u);
  perform oyun.para_islem(u, -round(f*1.02,2), 'emlak', format('%s: yeni %s satın alındı (%%2 alıcı tapu harcı dahil)', c.ad, tipad), t,round(f*.02,2));
  update oyun.ulke set hazine=hazine+round(f*.02,2)/1000000.0 where id=1;
  insert into oyun.yatirim_mulkleri(user_id, il_id, tip, alis_bedeli, haftalik_kira, satin_alma, sonraki_kira, vergi_sonraki)
  values (u, v_il, p_tip, f, k, t, t + interval '7 days', oyun.mulk_vergi_ilk_vade(t)) returning id into yeni;
  insert into oyun.ticaret_devir_kayit(tur, varlik_id, satici, alici, bedel, zaman, aciklama)
  values ('mulk_devlet', yeni, null, u, f, t, format('%s ilinden %s satın alındı', c.ad, tipad));
  return public.mulk_liste();
end $function$;

CREATE OR REPLACE FUNCTION oyun.mulk_devir_vergi()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare ilad text;
begin
  if new.user_id is distinct from old.user_id and old.vergi_borc > 0 then
    select ad into ilad from oyun.iller where id = old.il_id;
    perform oyun.para_islem(old.user_id, -old.vergi_borc, 'emlak_vergi',
      format('%s Belediyesi mülk vergisi borcu (tapu devri) · mülk #%s', ilad, old.id), oyun.simdi(), old.vergi_borc);
    update oyun.il_durum set kasa = coalesce(kasa, 0) + old.vergi_borc / 1e9 where il_id = old.il_id;
    insert into oyun.emlak_vergi_tahsilat(il_id, user_id, mulk_id, tutar, zaman) values (old.il_id, old.user_id, old.id, old.vergi_borc, oyun.simdi());
    new.vergi_borc := 0;
  end if;
  if new.user_id is distinct from old.user_id then
    new.vergi_sonraki := oyun.mulk_vergi_ilk_vade(oyun.simdi());
    new.vergi_borc := 0;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.mulk_liste()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid := auth.uid(); p oyun.profiller; j jsonb;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  select * into p from oyun.profiller where id = u;
  if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
  perform oyun.mulk_kira_tahsil(u);
  select jsonb_build_object(
    'mulkler', coalesce(jsonb_agg(jsonb_build_object(
       'id', m.id, 'tip', m.tip, 'il', i.ad, 'il_id', m.il_id, 'alis', m.alis_bedeli, 'deger', oyun.mulk_il_bedel(m.il_id, m.tip),
       'haftalik', m.haftalik_kira, 'sonraki', m.sonraki_kira,
       'toplam_kira', m.toplam_kira, 'kira_sayisi', m.kira_sayisi,
       'vergi', oyun.mulk_yillik_vergi_tutar(m.id), 'yillik_vergi', oyun.mulk_yillik_vergi_tutar(m.id), 'vergi_sonraki', m.vergi_sonraki, 'vergi_borc', m.vergi_borc
    ) order by m.satin_alma desc, m.id desc), '[]'::jsonb),
    'adet', count(m.id),
    'haftalik_toplam', coalesce(sum(m.haftalik_kira), 0),
    'haftalik_vergi', coalesce(sum(oyun.mulk_yillik_vergi_tutar(m.id)), 0),
    'yillik_vergi_toplam', coalesce(sum(oyun.mulk_yillik_vergi_tutar(m.id)), 0),
    'vergi_borc', coalesce(sum(m.vergi_borc), 0),
    'mulk_degeri', coalesce(sum(m.alis_bedeli), 0),
    'piyasa_degeri', coalesce(sum(oyun.mulk_il_bedel(m.il_id, m.tip)), 0),
    'ulusal_oran', oyun.duz('mulk_vergi_ulusal'),
    'cuzdan', (select para from oyun.cuzdan where user_id = u)
  ) into j
  from oyun.yatirim_mulkleri m join oyun.iller i on i.id = m.il_id where m.user_id = u;
  return j;
end $function$;

CREATE OR REPLACE FUNCTION public.mulk_il_stok()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with sahip as (select il_id, tip, count(*) n from oyun.yatirim_mulkleri group by il_id, tip)
  select coalesce(jsonb_agg(jsonb_build_object(
    'il_id', i.id, 'il', i.ad, 'nufus', i.mv, 'gelismislik', oyun.mulk_il_gelismislik(i.id),
    'benim_ilim', i.id = (select p.il_id from oyun.profiller p where p.id = auth.uid()),
    'vergi_oran', oyun.mulk_vergi_oran(i.id), 'carpan', oyun.il_duz(i.id, 'mulk_vergi_yerel'),
    'urunler', (select jsonb_agg(jsonb_build_object(
        'tip', v.tip, 'kontenjan', oyun.mulk_il_kota(i.id, v.tip),
        'kalan', greatest(0, oyun.mulk_il_kota(i.id, v.tip) - coalesce((select n from sahip s where s.il_id = i.id and s.tip = v.tip), 0)),
        'fiyat', oyun.mulk_il_bedel(i.id, v.tip), 'kira', oyun.mulk_il_kira(i.id, v.tip),
        'vergi', oyun.mulk_yillik_vergi_hesap(i.id, v.tip)) order by v.sira)
      from (values ('daire', 1), ('dukkan', 2), ('villa', 3)) v(tip, sira))
  )), '[]'::jsonb)
  from oyun.iller i
$function$;

-- Eski haftalık tahsilat saatini, edinme yılından sonraki ilk yasal takside öteler.
-- Tahakkuk etmiş eski vergi borçlarını silmez, cüzdanları veya mülk sahiplerini değiştirmez.
UPDATE oyun.yatirim_mulkleri SET vergi_sonraki=oyun.mulk_vergi_ilk_vade(satin_alma)
 WHERE vergi_sonraki IS DISTINCT FROM oyun.mulk_vergi_ilk_vade(satin_alma);
