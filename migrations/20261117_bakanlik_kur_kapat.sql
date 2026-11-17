-- 17.11.2026: Cumhurbaşkanı Bakanlık Kur / Kapat / Yeniden Aç
-- Kapatma arşivlemedir; FK ilişkileri, bütçe hareketi ve makam geçmişi silinmez.
-- Görevli bakan ve bekleyen ödenek talebi olan bakanlık kapanamaz.
-- Sadece aktif Cumhurbaşkanı işlem yapabilir (sadece UI yetkisine güvenilmez).

ALTER TABLE oyun.bakanliklar
 ADD COLUMN IF NOT EXISTS aktif boolean NOT NULL DEFAULT true,
 ADD COLUMN IF NOT EXISTS sistem boolean NOT NULL DEFAULT true,
 ADD COLUMN IF NOT EXISTS kurulus_at timestamptz,
 ADD COLUMN IF NOT EXISTS kapanis_at timestamptz,
 ADD COLUMN IF NOT EXISTS kapanis_gerekce text;
CREATE UNIQUE INDEX IF NOT EXISTS bakanliklar_ad_esitlik_uq ON oyun.bakanliklar (lower(ad));

CREATE OR REPLACE FUNCTION public.bakanlik_yonetimi()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p oyun.profiller:=oyun.profilim();
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN
  RAISE EXCEPTION 'Bakanlık kurma ve kapatma ekranı yalnız görevdeki Cumhurbaşkanına açıktır.';
 END IF;
 RETURN jsonb_build_object(
  'sinir',30,
  'bakanliklar',coalesce((SELECT jsonb_agg(jsonb_build_object(
    'kod',b.kod,'ad',b.ad,'aktif',b.aktif,'sistem',b.sistem,
    'kasa',coalesce(k.kasa,0),'bakan',oyun.kad(m.user_id),
    'kurulus_at',b.kurulus_at,'kapanis_at',b.kapanis_at,
    'kapanis_gerekce',b.kapanis_gerekce) ORDER BY b.sira)
   FROM oyun.bakanliklar b
   LEFT JOIN oyun.bakanlik_kasa k ON k.kod=b.kod
   LEFT JOIN LATERAL (SELECT x.user_id FROM oyun.makamlar x
    WHERE x.tur='bakan' AND x.bakanlik=b.kod AND x.bit IS NULL
    ORDER BY x.bas DESC LIMIT 1) m ON true),'[]'::jsonb)
 );
END $function$


CREATE OR REPLACE FUNCTION public.bakanlik_kur(p_ad text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p oyun.profiller:=oyun.profilim();
 v_ad text; v_kod text; v_sira integer; v_t timestamptz:=oyun.simdi();
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN RAISE EXCEPTION 'Bu yetki yalnız görevdeki Cumhurbaşkanına aittir.'; END IF;
 PERFORM pg_advisory_xact_lock(40881117);
 v_ad:=btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
 IF length(v_ad)<5 OR length(v_ad)>80 THEN RAISE EXCEPTION 'Bakanlık adı 5-80 karakter olmalıdır.'; END IF;
 IF v_ad !~* 'Bakanlığı$' THEN v_ad:=v_ad||' Bakanlığı'; END IF;
 IF length(v_ad)>90 THEN RAISE EXCEPTION 'Bakanlık adı fazla uzun.'; END IF;
 IF exists (SELECT 1 FROM oyun.bakanliklar WHERE lower(ad)=lower(v_ad))
 THEN RAISE EXCEPTION 'Bu isimde bir bakanlık zaten var. Kapalıysa yeniden açabilirsin.'; END IF;
 IF (SELECT count(*) FROM oyun.bakanliklar WHERE aktif)>=30 THEN
  RAISE EXCEPTION 'Aynı anda en fazla 30 bakanlık açık olabilir.'; END IF;
 v_kod:='ek_'||substr(replace(gen_random_uuid()::text,'-',''),1,14);
 SELECT coalesce(max(sira),0)+1 INTO v_sira FROM oyun.bakanliklar;
 INSERT INTO oyun.bakanliklar(kod,ad,sira,aktif,sistem,kurulus_at)
 VALUES(v_kod,v_ad,v_sira,true,false,v_t);
 INSERT INTO oyun.bakanlik_kasa(kod,kasa) VALUES(v_kod,0);
 PERFORM oyun.olay('duyuru',format('Cumhurbaşkanı %s, %s kurumunu kurdu.',p.kad,v_ad),null,p.parti_id,v_t);
 RETURN jsonb_build_object('tamam',true,'islem','kuruldu','kod',v_kod,'ad',v_ad);
END $function$


CREATE OR REPLACE FUNCTION public.bakanlik_kapat(p_kod text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p oyun.profiller:=oyun.profilim(); b oyun.bakanliklar; v_t timestamptz:=oyun.simdi(); v_gerekce text;
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN RAISE EXCEPTION 'Bu yetki yalnız görevdeki Cumhurbaşkanına aittir.'; END IF;
 v_gerekce:=btrim(coalesce(p_gerekce,''));
 IF length(v_gerekce)<10 OR length(v_gerekce)>350 THEN
  RAISE EXCEPTION 'Kapatma gerekçesi 10-350 karakter olmalıdır.'; END IF;
 SELECT * INTO b FROM oyun.bakanliklar WHERE kod=p_kod FOR UPDATE;
 IF b.kod IS NULL THEN RAISE EXCEPTION 'Bakanlık bulunamadı.'; END IF;
 IF NOT b.aktif THEN RAISE EXCEPTION 'Bakanlık zaten kapalı.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.makamlar WHERE tur='bakan' AND bakanlik=b.kod AND bit IS NULL)
 THEN RAISE EXCEPTION 'Önce bu bakanlıktaki görevli bakanı Kabine ekranından görevden almalısın.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.bakanlik_odenek_talep WHERE kod=b.kod AND durum='bekliyor')
 THEN RAISE EXCEPTION 'Bu bakanlığın bekleyen ödenek talebi var. Önce sonuçlandır.'; END IF;
 UPDATE oyun.bakan_teklifleri SET durum='iptal',yanit_at=v_t WHERE bakanlik=b.kod AND durum='bekliyor';
 UPDATE oyun.bakanliklar SET aktif=false,kapanis_at=v_t,kapanis_gerekce=v_gerekce WHERE kod=b.kod;
 PERFORM oyun.olay('duyuru',format('Cumhurbaşkanı %s, %s kurumunu kapattı. Gerekçe: %s',p.kad,b.ad,v_gerekce),null,p.parti_id,v_t);
 RETURN jsonb_build_object('tamam',true,'islem','kapatildi','kod',b.kod,'ad',b.ad);
END $function$


CREATE OR REPLACE FUNCTION public.bakanlik_yeniden_ac(p_kod text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p oyun.profiller:=oyun.profilim(); b oyun.bakanliklar; v_t timestamptz:=oyun.simdi();
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN RAISE EXCEPTION 'Bu yetki yalnız görevdeki Cumhurbaşkanına aittir.'; END IF;
 PERFORM pg_advisory_xact_lock(40881117);
 SELECT * INTO b FROM oyun.bakanliklar WHERE kod=p_kod FOR UPDATE;
 IF b.kod IS NULL THEN RAISE EXCEPTION 'Bakanlık bulunamadı.'; END IF;
 IF b.aktif THEN RAISE EXCEPTION 'Bakanlık zaten açık.'; END IF;
 IF (SELECT count(*) FROM oyun.bakanliklar WHERE aktif)>=30 THEN
  RAISE EXCEPTION 'Aynı anda en fazla 30 bakanlık açık olabilir.'; END IF;
 UPDATE oyun.bakanliklar SET aktif=true,kapanis_at=null,kapanis_gerekce=null WHERE kod=b.kod;
 INSERT INTO oyun.bakanlik_kasa(kod,kasa) VALUES(b.kod,0) ON CONFLICT(kod) DO NOTHING;
 PERFORM oyun.olay('duyuru',format('Cumhurbaşkanı %s, %s kurumunu yeniden açtı.',p.kad,b.ad),null,p.parti_id,v_t);
 RETURN jsonb_build_object('tamam',true,'islem','yeniden_acildi','kod',b.kod,'ad',b.ad);
END $function$


CREATE OR REPLACE FUNCTION oyun.bakanlik_aktif_makam_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.tur='bakan' AND NEW.bit IS NULL AND NOT EXISTS
 (SELECT 1 FROM oyun.bakanliklar b WHERE b.kod=NEW.bakanlik AND b.aktif)
 THEN RAISE EXCEPTION 'Kapalı veya bulunamayan bakanlığa bakan atanamaz.'; END IF;
 RETURN NEW;
END $function$


CREATE OR REPLACE FUNCTION oyun.bakanlik_aktif_teklif_kontrol()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.durum='bekliyor' AND NOT EXISTS
 (SELECT 1 FROM oyun.bakanliklar b WHERE b.kod=NEW.bakanlik AND b.aktif)
 THEN RAISE EXCEPTION 'Kapalı veya bulunamayan bakanlığa teklif gönderilemez.'; END IF;
 RETURN NEW;
END $function$


CREATE OR REPLACE FUNCTION public.kabine()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 p oyun.profiller:=oyun.profilim();
 hid bigint:=oyun.aktif_hukumet_id();
 v_cb_id bigint;
 v_sure oyun.cb_kabine_sure;
 v_toplam integer;
 v_dolu integer;
BEGIN
 SELECT id INTO v_cb_id FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL ORDER BY bas DESC LIMIT 1;
 SELECT * INTO v_sure FROM oyun.cb_kabine_sure WHERE makam_id=v_cb_id;
 SELECT count(*) INTO v_toplam FROM oyun.bakanliklar WHERE aktif;
 SELECT count(*) INTO v_dolu FROM oyun.bakanliklar b WHERE b.aktif AND EXISTS(
   SELECT 1 FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL AND m.bakanlik=b.kod);
 RETURN jsonb_build_object(
   'sistem',CASE WHEN oyun.hukumet_sistemi()=1 THEN 'parlamenter' ELSE 'cumhurbaskanligi' END,
   'yurutme_benim',oyun.yurutme_user()=p.id,
   'basbakan',(SELECT jsonb_build_object('kad',oyun.kad(h.basbakan),'parti',oyun.parti_json(h.kuran_parti),'bas',h.bas,'tur',h.tur) FROM oyun.hukumetler h WHERE h.id=hid),
   'hukumet_id',hid,
   'cb',(SELECT jsonb_build_object('kad',oyun.kad(m.user_id),'parti',oyun.parti_json(m.parti_id),'bas',m.bas) FROM oyun.makamlar m WHERE m.tur='cb' AND m.bit IS NULL ORDER BY m.bas DESC LIMIT 1),
   'bakanlar',(SELECT jsonb_agg(jsonb_build_object('kod',b.kod,'ad',b.ad,'kad',oyun.kad(m.user_id),'parti',oyun.parti_json((SELECT parti_id FROM oyun.profiller WHERE id=m.user_id)),'bas',m.bas) ORDER BY b.sira)
     FROM oyun.bakanliklar b LEFT JOIN oyun.makamlar m ON m.bakanlik=b.kod AND m.tur='bakan' AND m.bit IS NULL WHERE b.aktif),
   'kabine_sure',CASE WHEN oyun.hukumet_sistemi()=0 AND v_sure.makam_id IS NOT NULL THEN
      jsonb_build_object(
       'durum',case when v_dolu>=v_toplam then 'tamam' else 'eksik' end,
       'zorunlu',false,
       'aciklama','Boş bakanlık Cumhurbaşkanının görevini etkilemez; atama dilediğin zaman yapılabilir.',
       'son_tarih',null,
       'toplam',v_toplam,
       'dolu',v_dolu,
       'eksik',greatest(0,v_toplam-v_dolu),
       'kalan_saniye',null,
       'eksik_bakanliklar',coalesce((SELECT jsonb_agg(jsonb_build_object('kod',b.kod,'ad',b.ad) ORDER BY b.sira) FROM oyun.bakanliklar b WHERE b.aktif AND NOT EXISTS(
          SELECT 1 FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL AND m.bakanlik=b.kod)), '[]'::jsonb))
      ELSE NULL END
 );
END $function$


CREATE OR REPLACE FUNCTION oyun.cb_kabine_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  t timestamptz := oyun.simdi();
  v_cb oyun.makamlar;
  v_k oyun.cb_kabine_sure;
  dolu integer; toplam integer; eksik text;
begin
  if oyun.hukumet_sistemi() <> 0 then return 0; end if;
  if not pg_try_advisory_xact_lock(40881111) then return 0; end if;
  select * into v_cb from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1;
  if v_cb.id is null then return 0; end if;

  insert into oyun.cb_kabine_sure(makam_id,baslangic,son_tarih)
  values (v_cb.id, coalesce(v_cb.bas,t), coalesce(v_cb.bas,t))
  on conflict (makam_id) do nothing;
  select * into v_k from oyun.cb_kabine_sure where makam_id=v_cb.id for update;

  select count(*) into toplam from oyun.bakanliklar where aktif;
  select count(*) into dolu from oyun.bakanliklar b
   where b.aktif and exists (select 1 from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.bakanlik=b.kod);

  if dolu = toplam and toplam > 0 then
    if v_k.durum <> 'tamam' then
      update oyun.cb_kabine_sure set durum='tamam', ilk_tamam=coalesce(ilk_tamam,t), son_islem=t, son_uyari=0 where makam_id=v_cb.id;
      perform oyun.bildir(v_cb.user_id, format('Kabine tam: %s/%s bakanlıkta görevli bakan var.', dolu, toplam), t);
    end if;
    return 0;
  end if;

  if v_k.durum = 'tamam' then
    update oyun.cb_kabine_sure set durum='yenileme', son_uyari=0, son_islem=t - interval '24 hours' where makam_id=v_cb.id;
    select * into v_k from oyun.cb_kabine_sure where makam_id=v_cb.id;
  end if;
  if v_k.son_uyari = 0 or v_k.son_islem <= t - interval '24 hours' then
    select string_agg(b.ad, ', ' order by b.sira) into eksik from oyun.bakanliklar b
     where b.aktif and not exists (select 1 from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.bakanlik=b.kod);
    update oyun.cb_kabine_sure set son_uyari=son_uyari+1, son_islem=t where makam_id=v_cb.id;
    perform oyun.bildir(v_cb.user_id,
      format('Bilgi: %s bakanlık boş (%s/%s dolu): %s. Dilediğin zaman Yönetim › Kabine ekranından atama yapabilirsin; boş bakanlık görevini etkilemez.',
        toplam-dolu, dolu, toplam, coalesce(eksik,'')), t);
  end if;
  return 0;
end $function$


CREATE OR REPLACE FUNCTION oyun.bakanlik_gunluk_odenek(p_cari numeric, p_butce jsonb)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tav numeric := coalesce((select a.tavan from oyun.bakanlik_ayar a where a.id = 1), 100);
  r record; pay numeric; yeni numeric; fazla numeric := 0; kalan numeric; t timestamptz := oyun.simdi();
begin
  perform oyun.bm_neden('gunluk', 'Günlük bütçe ödeneği (bütçe kanunu payı)');
  for r in select k.kod, k.kasa from oyun.bakanlik_kasa k join oyun.bakanliklar b on b.kod=k.kod where b.aktif order by k.kod for update of k loop
    pay := round(coalesce(p_cari, 0) * coalesce((p_butce ->> r.kod)::numeric, 0) / 100, 6);
    if pay <= 0 then continue; end if;
    if r.kasa >= tav then yeni := r.kasa; else yeni := least(tav, r.kasa + pay); end if;
    kalan := pay - (yeni - r.kasa);
    if yeni > r.kasa then update oyun.bakanlik_kasa set kasa = yeni where kod = r.kod; end if;
    if kalan > 0.0001 then
      fazla := fazla + kalan;
      insert into oyun.bakanlik_hareket(kod, zaman, tutar, bakiye, tur, aciklama)
      values (r.kod, t, 0, round(yeni, 4), 'tavan',
              format('Kasa tavanda (%s milyar ₺): %s milyar ₺ ödenek Hazine''de kaldı', oyun.bm_sayi(tav, 0), oyun.bm_sayi(kalan, 2)));
    end if;
  end loop;
  perform oyun.bm_neden(null, null);
  return round(fazla, 6);
end $function$


DROP TRIGGER IF EXISTS bakanlik_aktif_makam_trg ON oyun.makamlar;
CREATE TRIGGER bakanlik_aktif_makam_trg BEFORE INSERT OR UPDATE ON oyun.makamlar
FOR EACH ROW EXECUTE FUNCTION oyun.bakanlik_aktif_makam_kontrol();

DROP TRIGGER IF EXISTS bakanlik_aktif_teklif_trg ON oyun.bakan_teklifleri;
CREATE TRIGGER bakanlik_aktif_teklif_trg BEFORE INSERT OR UPDATE ON oyun.bakan_teklifleri
FOR EACH ROW EXECUTE FUNCTION oyun.bakanlik_aktif_teklif_kontrol();

REVOKE ALL ON FUNCTION public.bakanlik_yonetimi() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bakanlik_kur(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bakanlik_kapat(text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.bakanlik_yeniden_ac(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bakanlik_yonetimi() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bakanlik_kur(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bakanlik_kapat(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bakanlik_yeniden_ac(text) TO authenticated;
