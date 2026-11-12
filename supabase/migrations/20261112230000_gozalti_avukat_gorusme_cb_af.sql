-- 12.11.2026 | Gözaltı: avukat görüşmesi, barodan doğrudan müdafi, yalnız CB tahliyesi
-- Ercan'ın kuralları:
--  1) Baro, gözaltındaki oyuncuya (talep beklemeden) avukat gönderebilsin.
--  2) Gözaltındaki oyuncu ile avukatı karşılıklı görüşebilsin; avukat süreçte kolaylık sağlasın.
--  3) Cumhurbaşkanı istediği gözaltıyı sonlandırabilsin (eylem ve İçişleri gözaltısı).
--  4) Hâkim / mahkeme başkanı gözaltındakini serbest bırakamasın; süresinden önce
--     yalnız Cumhurbaşkanı kararıyla çıkılır. Süre dolunca gözaltı kendiliğinden biter.
-- Oyuncu verisi değiştirilmez; yalnız yeni tablo/sütun ve fonksiyon güncellemesi.

-- ── 1. Yeni tablo ve sütunlar ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS oyun.gozalti_gorusme (
  id bigserial PRIMARY KEY,
  kaynak text NOT NULL DEFAULT 'sokak' CHECK (kaynak IN ('sokak','icisleri')),
  dosya_id bigint NOT NULL,
  gonderen uuid NOT NULL REFERENCES oyun.profiller(id),
  metin text NOT NULL CHECK (char_length(metin) BETWEEN 1 AND 2000),
  zaman timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gozalti_gorusme_dosya_idx ON oyun.gozalti_gorusme (kaynak, dosya_id, zaman);
ALTER TABLE oyun.gozalti_gorusme ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.gozalti_gorusme FROM PUBLIC, anon, authenticated;

ALTER TABLE oyun.sokak_gozalti ADD COLUMN IF NOT EXISTS cb_dilekce text;
ALTER TABLE oyun.sokak_gozalti ADD COLUMN IF NOT EXISTS cb_dilekce_at timestamptz;
ALTER TABLE oyun.sokak_gozalti ADD COLUMN IF NOT EXISTS cb_dilekce_avukat uuid REFERENCES oyun.profiller(id);
ALTER TABLE oyun.icisleri_tedbir_v2 ADD COLUMN IF NOT EXISTS cb_serbest_birakan uuid REFERENCES oyun.profiller(id);
ALTER TABLE oyun.icisleri_tedbir_v2 ADD COLUMN IF NOT EXISTS cb_serbest_gerekce text;

-- Ön inceleme artık "hukuka aykırılık tespiti" de olabilir (eski 'serbest' kayıtları korunur).
ALTER TABLE oyun.sokak_gozalti DROP CONSTRAINT IF EXISTS sokak_gozalti_on_inceleme_karari_check;
ALTER TABLE oyun.sokak_gozalti ADD CONSTRAINT sokak_gozalti_on_inceleme_karari_check
  CHECK (on_inceleme_karari IS NULL OR on_inceleme_karari IN ('serbest','devam','aykiri'));

CREATE OR REPLACE FUNCTION oyun.cb_mi(u uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $f$
  SELECT u IS NOT NULL AND EXISTS (
    SELECT 1 FROM oyun.makamlar m WHERE m.user_id = u AND m.tur = 'cb' AND m.bit IS NULL)
$f$;

CREATE OR REPLACE FUNCTION oyun.cb_kim()
RETURNS uuid LANGUAGE sql STABLE SET search_path TO '' AS $f$
  SELECT m.user_id FROM oyun.makamlar m WHERE m.tur = 'cb' AND m.bit IS NULL LIMIT 1
$f$;

-- ── 2. Hâkim kararları artık tahliye etmez ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.sokak_gozalti_hakim_incele(p_gozalti bigint, p_karar text, p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare
 u uuid:=auth.uid(); g oyun.sokak_gozalti; t timestamptz:=oyun.simdi(); k text; cb uuid;
begin
 if u is null or not exists(select 1 from oyun.adliye_makam where hakim=u)
 then raise exception 'Yalnız görevli hâkim inceleme yapabilir';end if;
 -- Eski uygulamadan gelen 'serbest' seçimi artık "hukuka aykırılık tespiti" sayılır.
 k:=case when p_karar in ('serbest','aykiri') then 'aykiri' when p_karar='devam' then 'devam' end;
 if k is null or length(btrim(coalesce(p_gerekce,''))) not between 25 and 2000 then
 raise exception 'Karar türü ve 25–2000 karakter gerekçe gereklidir';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.durum<>'aktif' or g.bitis<=t
 then raise exception 'Hâkim ön incelemesine uygun aktif gözaltı yok';end if;
 if g.on_inceleme_karari is not null then raise exception 'Bu dosyada ön inceleme kararı verilmiş';end if;
 if u=g.hedef or u is not distinct from g.avukat or
 exists(select 1 from oyun.sokak_polis where id=g.polis_id and yapan=u)
 then raise exception 'Çıkar çatışması: bu hâkim dosyayı inceleyemez';end if;
 update oyun.sokak_gozalti set
  on_inceleme_karari=k,on_inceleme_hakim=u,
  on_inceleme_gerekce=btrim(p_gerekce),on_inceleme_zaman=t
 where id=g.id;
 perform oyun.bildir(g.hedef,'Gözaltı #'||g.id||' hâkim ön incelemesi: '||
  case when k='aykiri' then 'Gözaltı hukuka aykırı bulundu; tahliye yetkisi Cumhurbaşkanındadır, dosya Cumhurbaşkanlığına iletildi. '
  else 'Gözaltı süresinin devamı uygun bulundu. ' end||left(btrim(p_gerekce),400));
 if k='aykiri' then
  cb:=oyun.cb_kim();
  if cb is not null then perform oyun.bildir(cb,'Hâkim, gözaltı #'||g.id||' ('||oyun.kad(g.hedef)||') için hukuka aykırılık tespit etti. Tahliye kararı sizde: Halk Hareketleri › Hukuk.');end if;
 end if;
 perform oyun.sokak_duyur(g.eylem_id,'Hâkim gözaltı #'||g.id||' ön incelemesinde '||
  case when k='aykiri' then 'hukuka aykırılık tespit etti (tahliye Cumhurbaşkanı kararına bağlı)' else 'gözaltının devamını uygun buldu' end||'.');
 return jsonb_build_object('tamam',true,'karar',k,'itiraz_hakki',true,'tahliye','yalniz_cumhurbaskani');
end $function$;

CREATE OR REPLACE FUNCTION public.sokak_gozalti_itiraz(p_gozalti bigint, p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare u uuid:=auth.uid();g oyun.sokak_gozalti; avk boolean; sure interval;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null then raise exception 'Gözaltı kaydı yok';end if;
 avk:=(u=g.avukat and g.avukat_durum='kabul');
 if u<>g.hedef and not avk then raise exception 'İtiraz yalnız oyuncudan veya kabul eden avukatından yapılabilir';end if;
 if length(btrim(coalesce(p_metin,''))) not between 20 and 2000 then raise exception '20-2000 karakterlik savunma gerekli';end if;
 if g.itiraz is not null then raise exception 'Bu gözaltı için itiraz yapıldı';end if;
 -- Avukatlı dosyada itiraz süresi 48 saat (avukat kolaylığı); avukatsız 24 saat.
 sure:=case when g.avukat_durum='kabul' then interval '48 hours' else interval '24 hours' end;
 if oyun.simdi()>g.baslangic+sure then raise exception 'İtiraz süresi doldu';end if;
 -- İtiraz gözaltıyı sona erdirmez; tahliye yalnız Cumhurbaşkanı kararıyla ya da sürenin dolmasıyla olur.
 update oyun.sokak_gozalti set itiraz=btrim(p_metin),itiraz_at=oyun.simdi() where id=p_gozalti;
 insert into oyun.bildirimler(user_id,zaman,metin)
 select hakim,oyun.simdi(),'Gözaltı #'||g.id||' itirazı açıldı'||case when avk then ' (avukat dilekçesi)' else '' end||'. Halk Hareketleri › Hukuk bölümünden karar verin.'
 from oyun.adliye_makam where hakim is not null;
 perform oyun.sokak_duyur(g.eylem_id,'Gözaltı #'||g.id||' için '||case when avk then 'avukat aracılığıyla ' else '' end||'hukuki itiraz yapıldı; mahkeme incelemesi bekleniyor.');
 return jsonb_build_object('tamam',true,'serbest',false);
end $function$;

CREATE OR REPLACE FUNCTION public.sokak_gozalti_mahkeme(p_gozalti bigint, p_karar text, p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti; x oyun.sokak_eylem;
 a oyun.sokak_eylem_ayar; t numeric:=0; o numeric:=0; cb uuid;
begin
 if u is null or not exists(select 1 from oyun.adliye_makam where hakim=u) then raise exception 'Yalnız görevli hâkim karar verebilir';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.itiraz is null or g.karar is not null then raise exception 'Karar bekleyen geçerli itiraz yok';end if;
 if u=g.hedef or u=g.avukat or exists(select 1 from oyun.sokak_polis where id=g.polis_id and yapan=u) then raise exception 'Çıkar çatışması: bu dosyada karar veremezsiniz';end if;
 if p_karar not in ('haksiz','uygun') or length(btrim(coalesce(p_gerekce,''))) not between 25 and 2000 then raise exception 'Karar ve en az 25 karakter gerekçe gerekli';end if;
 select * into x from oyun.sokak_eylem where id=g.eylem_id;
 select * into a from oyun.sokak_eylem_ayar where id=1;
 if p_karar='haksiz' then
   -- Avukatlı dosyada tazminat %50 fazla (avukat kolaylığı).
   t:=a.baslatma_bedeli/2*case when g.avukat_durum='kabul' then 1.5 else 1 end;
   begin
    perform oyun.bm_kasa_harca('icisleri',t/oyun.pazar_tl_milyar(),'gider','Haksız gözaltı #'||g.id||' tazminatı');
    update oyun.cuzdan set para=para+t where user_id=g.hedef;
    if not found then raise exception 'Cüzdan bulunamadı';end if;
    insert into oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) values(g.hedef,oyun.simdi(),t,'gelir','Haksız gözaltı #'||g.id||' tazminatı');
    o:=t;
   exception when others then
    o:=0;
   end;
 end if;
 -- Mahkeme kararı tazminat ve kayıt içindir; gözaltıyı sona erdirmez.
 update oyun.sokak_gozalti set karar=p_karar,karar_gerekce=btrim(p_gerekce),hakim=u,
 karar_at=oyun.simdi(),tazminat=t,tazminat_odendi=o where id=g.id;
 perform oyun.bildir(g.hedef,'Gözaltı #'||g.id||' mahkeme kararı: '||p_karar||'. Tazminat: '||t||' TL, ödenen: '||o||' TL.'||
  case when p_karar='haksiz' and g.durum='aktif' and g.bitis>oyun.simdi() then ' Tahliye yetkisi Cumhurbaşkanındadır.' else '' end||' Gerekçe: '||left(p_gerekce,400));
 if p_karar='haksiz' and g.durum='aktif' and g.bitis>oyun.simdi() then
  cb:=oyun.cb_kim();
  if cb is not null then perform oyun.bildir(cb,'Mahkeme gözaltı #'||g.id||' ('||oyun.kad(g.hedef)||') için haksız gözaltı kararı verdi. Tahliye kararı sizde: Halk Hareketleri › Hukuk.');end if;
 end if;
 perform oyun.sokak_duyur(g.eylem_id,'Mahkeme gözaltı #'||g.id||' hakkında '||p_karar||' kararı verdi. Tazminat: '||t||' TL. '||left(p_gerekce,400));
 if p_karar='haksiz' then
 update oyun.ulke set memnuniyet=greatest(0,memnuniyet-.5) where id=1;
 update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=x.il_id;
 end if;
 return jsonb_build_object('tamam',true,'karar',p_karar,'tazminat',t,'odenen',o);
end $function$;

-- Polis geri çekilince gözaltılar yalnız Cumhurbaşkanı emriyse sona erer.
CREATE OR REPLACE FUNCTION public.sokak_polis_geri_cek(p_polis bigint, p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare u uuid:=auth.uid();p oyun.sokak_polis; affected int:=0; cb boolean;
begin
 if u is null or not oyun.sokak_yonetebilir(u) then raise exception 'Yalnız Cumhurbaşkanı/İçişleri Bakanı polis çekebilir';end if;
 if length(btrim(coalesce(p_gerekce,''))) not between 20 and 1500 then raise exception '20-1500 karakter gerekçe gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into p from oyun.sokak_polis where id=p_polis for update;
 if p.id is null or p.geri_cekildi is not null or p.zaman+interval '3 hours'<oyun.simdi() then raise exception 'Polis operasyonu artık geri çekilemez';end if;
 cb:=oyun.cb_mi(u);
 update oyun.sokak_polis set geri_cekildi=oyun.simdi() where id=p.id;
 if cb then
  update oyun.sokak_gozalti set durum='serbest',bitis=oyun.simdi(),cb_serbest_birakan=u,cb_serbest_zaman=oyun.simdi(),
   cb_serbest_gerekce=left(btrim(p_gerekce),500)
  where polis_id=p.id and durum='aktif' and bitis>oyun.simdi();
  get diagnostics affected=row_count;
 end if;
 perform oyun.sokak_yenile(p.eylem_id);
 perform oyun.sokak_duyur(p.eylem_id,'Hükümet polisleri geri çekti; '||
  case when cb then affected||' gözaltı Cumhurbaşkanı kararıyla sona erdi. ' else 'mevcut gözaltılar sürüyor (tahliye yetkisi Cumhurbaşkanında). ' end||
  'Gerekçe: '||left(p_gerekce,350));
 return jsonb_build_object('tamam',true,'serbest',affected);
end $function$;

-- ── 3. Cumhurbaşkanı: her türlü aktif gözaltıyı sonlandırır ─────────────────
CREATE OR REPLACE FUNCTION public.sokak_cb_gozaltilar()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $func$
DECLARE u uuid := auth.uid(); t timestamptz := oyun.simdi(); liste jsonb; ic jsonb;
BEGIN
  IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
  IF NOT oyun.cb_mi(u) THEN
    RETURN jsonb_build_object('cb_miyim', false, 'gozaltilar', '[]'::jsonb, 'icisleri_gozaltilar', '[]'::jsonb);
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', g.id, 'eylem_id', g.eylem_id, 'hedef', p.kad, 'il', i.ad,
    'baslangic', g.baslangic, 'bitis', g.bitis,
    'itiraz_var', g.itiraz IS NOT NULL,
    'hakim_incelemesi', g.on_inceleme_karari,
    'mahkeme_karari', g.karar,
    'avukat', oyun.kad(g.avukat), 'avukat_durum', g.avukat_durum,
    'avukat_dilekcesi', g.cb_dilekce, 'avukat_dilekce_at', g.cb_dilekce_at
  ) ORDER BY (g.cb_dilekce IS NOT NULL OR g.karar='haksiz' OR g.on_inceleme_karari IN ('aykiri','serbest')) DESC, g.baslangic DESC), '[]'::jsonb)
  INTO liste
  FROM (SELECT * FROM oyun.sokak_gozalti WHERE durum = 'aktif' AND bitis > t ORDER BY baslangic DESC LIMIT 100) g
  JOIN oyun.profiller p ON p.id = g.hedef
  JOIN oyun.sokak_eylem e ON e.id = g.eylem_id
  JOIN oyun.iller i ON i.id = e.il_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', k.id, 'hedef', oyun.kad(k.hedef), 'gerekce', left(k.gerekce, 300),
    'baslangic', k.karar_at, 'bitis', k.bitis, 'durum', k.durum,
    'avukat', oyun.kad(k.avukat), 'avukat_durum', k.avukat_durum
  ) ORDER BY k.karar_at DESC), '[]'::jsonb)
  INTO ic
  FROM oyun.icisleri_tedbir_v2 k
  WHERE k.tur = 'gozalti' AND k.durum IN ('onay','itiraz') AND k.bitis > t;

  RETURN jsonb_build_object('cb_miyim', true, 'gozaltilar', liste, 'icisleri_gozaltilar', ic);
END $func$;

CREATE OR REPLACE FUNCTION public.sokak_cb_serbest_birak(p_gozalti bigint, p_gerekce text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $func$
DECLARE u uuid := auth.uid(); t timestamptz := oyun.simdi(); g oyun.sokak_gozalti; sebep text;
BEGIN
  IF NOT oyun.cb_mi(u) THEN RAISE EXCEPTION 'Bu işlem yalnızca görevdeki Cumhurbaşkanına aittir'; END IF;
  IF p_gozalti IS NULL OR p_gozalti <= 0 THEN RAISE EXCEPTION 'Geçerli gözaltı dosyası seçilmelidir'; END IF;
  sebep := COALESCE(NULLIF(btrim(p_gerekce), ''), 'Cumhurbaşkanlığı kararı');
  IF char_length(sebep) > 500 THEN RAISE EXCEPTION 'Gerekçe 500 karakteri aşamaz'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(781231, 1);
  SELECT * INTO g FROM oyun.sokak_gozalti WHERE id = p_gozalti FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Gözaltı dosyası bulunamadı'; END IF;
  IF g.durum <> 'aktif' OR g.bitis <= t THEN RAISE EXCEPTION 'Bu dosyada devam eden gözaltı yok'; END IF;
  -- Mahkeme kararı (tazminat) verilmiş dosyalar da serbest bırakılabilir; kayıtlar silinmez.
  UPDATE oyun.sokak_gozalti
  SET durum = 'serbest', bitis = t, cb_serbest_birakan = u, cb_serbest_zaman = t, cb_serbest_gerekce = sebep
  WHERE id = g.id;
  PERFORM oyun.bildir(g.hedef, format('Cumhurbaşkanlığı kararıyla gözaltın (#%s) derhal sonlandırıldı. %s', g.id, sebep), t);
  IF g.avukat IS NOT NULL AND g.avukat_durum = 'kabul' THEN
    PERFORM oyun.bildir(g.avukat, format('Müvekkilinizin gözaltısı (#%s) Cumhurbaşkanlığı kararıyla sona erdi.', g.id), t);
  END IF;
  PERFORM oyun.sokak_duyur(g.eylem_id, format('Cumhurbaşkanı, gözaltı dosyası #%s için serbest bırakma kararı verdi. %s', g.id, sebep));
  RETURN jsonb_build_object('tamam', true, 'gozalti_id', g.id, 'durum', 'serbest', 'zaman', t);
END $func$;

CREATE OR REPLACE FUNCTION public.cb_icisleri_gozalti_serbest(p_id bigint, p_gerekce text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $func$
DECLARE u uuid := auth.uid(); t timestamptz := oyun.simdi(); k oyun.icisleri_tedbir_v2; sebep text;
BEGIN
  IF NOT oyun.cb_mi(u) THEN RAISE EXCEPTION 'Bu işlem yalnızca görevdeki Cumhurbaşkanına aittir'; END IF;
  sebep := COALESCE(NULLIF(btrim(p_gerekce), ''), 'Cumhurbaşkanlığı kararı');
  IF char_length(sebep) > 500 THEN RAISE EXCEPTION 'Gerekçe 500 karakteri aşamaz'; END IF;
  PERFORM pg_advisory_xact_lock(771270, 1);
  SELECT * INTO k FROM oyun.icisleri_tedbir_v2 WHERE id = p_id FOR UPDATE;
  IF k.id IS NULL OR k.tur <> 'gozalti' OR k.durum NOT IN ('onay','itiraz') OR k.bitis <= t THEN
    RAISE EXCEPTION 'Bu dosyada devam eden İçişleri gözaltısı yok'; END IF;
  UPDATE oyun.icisleri_tedbir_v2 SET bitis = t, cb_serbest_birakan = u, cb_serbest_gerekce = sebep WHERE id = k.id;
  PERFORM oyun.bildir(k.hedef, format('Cumhurbaşkanlığı kararıyla İçişleri gözaltın (#%s) derhal sonlandırıldı. %s', k.id, sebep), t);
  IF k.bakan IS NOT NULL THEN
    PERFORM oyun.bildir(k.bakan, format('İçişleri gözaltısı #%s Cumhurbaşkanlığı kararıyla sona erdirildi. %s', k.id, sebep), t);
  END IF;
  RETURN jsonb_build_object('tamam', true, 'id', k.id);
END $func$;

-- İçişleri gözaltısında itiraz ve itiraz kararı gözaltıyı bitirmez (kayıt olarak kalır).
CREATE OR REPLACE FUNCTION public.icisleri_tedbir_itiraz(p_id bigint, p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE u uuid:=auth.uid(); k oyun.icisleri_tedbir_v2; x oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR length(trim(coalesce(p_metin,''))) NOT BETWEEN 30 AND 2500 THEN RAISE EXCEPTION '30–2500 karakter itiraz gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO k FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF k.id IS NULL OR k.durum<>'onay' OR k.itiraz_at IS NOT NULL OR k.karar_at<t-interval '24 hours' THEN RAISE EXCEPTION '24 saatlik itiraz hakkı yok veya kullanıldı'; END IF;
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=k.olay_id;
 IF u NOT IN (x.hedef,x.basvuran) AND NOT (u=k.avukat AND k.avukat_durum='kabul') THEN RAISE EXCEPTION 'Yalnız dosya tarafları veya kabul eden avukat itiraz edebilir'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim IS NOT NULL AND hakim<>k.hakim AND hakim IS DISTINCT FROM k.bakan AND hakim IS DISTINCT FROM x.basvuran AND hakim IS DISTINCT FROM x.hedef) THEN
   IF k.tur='ceza' AND k.tutar>0 THEN
      UPDATE oyun.cuzdan SET para=para+k.tutar WHERE user_id=k.hedef;
      INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(k.hedef,t,k.tutar,'iade','İçişleri ceza itiraz iadesi #'||k.id);
   END IF;
   IF k.tur='gozalti' THEN
      -- Gözaltı yalnız Cumhurbaşkanı kararıyla ya da süre dolunca biter.
      UPDATE oyun.icisleri_tedbir_v2 SET durum='itiraz',itiraz_metin=trim(p_metin),itiraz_at=t,itiraz_karar='İkinci bağımsız hâkim bulunmadı; gözaltı süresi işliyor (tahliye yetkisi Cumhurbaşkanında)',itiraz_karar_at=t WHERE id=k.id;
      RETURN jsonb_build_object('tamam',true,'otomatik_kaldirildi',false);
   END IF;
   UPDATE oyun.icisleri_tedbir_v2 SET durum='kaldirildi',bitis=t,itiraz_metin=trim(p_metin),itiraz_at=t,itiraz_karar='İkinci bağımsız hâkim bulunmadığından tedbir kaldırıldı',itiraz_karar_at=t WHERE id=k.id;
   PERFORM oyun.bildir(k.bakan,'Tedbir #'||k.id||' bağımsız ikinci hâkim yokluğu nedeniyle kaldırıldı.');
   RETURN jsonb_build_object('tamam',true,'otomatik_kaldirildi',true);
 END IF;
 UPDATE oyun.icisleri_tedbir_v2 SET durum='itiraz',bitis=CASE WHEN tur IN ('faaliyet','ihale') THEN t ELSE bitis END,
 itiraz_metin=trim(p_metin),itiraz_at=t WHERE id=k.id;
 PERFORM oyun.bildir(u,'İtiraz alındı.'||CASE WHEN k.tur='gozalti' THEN ' Gözaltı süresi işliyor; erken tahliye yalnız Cumhurbaşkanı kararıyla olur.' ELSE ' Ekonomik kısıtlama varsa durduruldu.' END);
 RETURN jsonb_build_object('tamam',true,'otomatik_kaldirildi',false);
END $function$;

CREATE OR REPLACE FUNCTION public.icisleri_tedbir_itiraz_karar(p_id bigint, p_kaldir boolean, p_gerekce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE u uuid:=auth.uid(); k oyun.icisleri_tedbir_v2; x oyun.icisleri_olay_v2; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.adliye_makam WHERE hakim=u) THEN RAISE EXCEPTION 'Bağımsız hâkim gerekli'; END IF;
 IF p_kaldir IS NULL OR length(trim(coalesce(p_gerekce,''))) NOT BETWEEN 30 AND 2500 THEN RAISE EXCEPTION '30–2500 karakter mahkeme gerekçesi gerekli'; END IF;
 PERFORM pg_advisory_xact_lock(771270,1);
 SELECT * INTO k FROM oyun.icisleri_tedbir_v2 WHERE id=p_id FOR UPDATE;
 IF k.id IS NULL OR k.durum<>'itiraz' THEN RAISE EXCEPTION 'İtiraz incelemesi bulunamadı'; END IF;
 SELECT * INTO x FROM oyun.icisleri_olay_v2 WHERE id=k.olay_id;
 IF u IN (k.hakim,k.bakan,x.basvuran,x.hedef) THEN RAISE EXCEPTION 'Tarafsız ikinci hâkim gerekli'; END IF;
 IF p_kaldir AND k.tur='ceza' AND k.tutar>0 THEN
   UPDATE oyun.cuzdan SET para=para+k.tutar WHERE user_id=k.hedef;
   INSERT INTO oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) VALUES(k.hedef,t,k.tutar,'iade','İçişleri ceza iptali #'||k.id);
 END IF;
 -- Gözaltıda hâkim kararı süreyi kısaltmaz; yalnız kayıt düşülür.
 UPDATE oyun.icisleri_tedbir_v2 SET durum=CASE WHEN k.tur='gozalti' THEN 'onay' WHEN p_kaldir THEN 'kaldirildi' ELSE 'onay' END,
  bitis=CASE WHEN k.tur='gozalti' THEN k.bitis WHEN p_kaldir OR k.tur IN ('faaliyet','ihale') THEN t ELSE k.bitis END,
  itiraz_hakim=u,itiraz_karar=trim(p_gerekce),itiraz_karar_at=t WHERE id=k.id;
 IF k.hedef IS NOT NULL THEN PERFORM oyun.bildir(k.hedef,'İçişleri tedbiri #'||p_id||' itiraz sonucu: '||CASE WHEN p_kaldir THEN 'hukuka aykırı bulundu' ELSE 'onandı' END||
   CASE WHEN k.tur='gozalti' AND k.bitis>t THEN '. Gözaltının erken sona ermesi yalnız Cumhurbaşkanı kararıyla olur.' ELSE '' END); END IF;
 IF p_kaldir AND k.tur='gozalti' AND k.bitis>t AND oyun.cb_kim() IS NOT NULL THEN
   PERFORM oyun.bildir(oyun.cb_kim(),'Hâkim İçişleri gözaltısı #'||k.id||' ('||oyun.kad(k.hedef)||') için hukuka aykırılık kararı verdi. Tahliye kararı sizde: Halk Hareketleri › Hükümet.');
 END IF;
 RETURN jsonb_build_object('tamam',true);
END $function$;

-- ── 4. Baro doğrudan müdafi gönderir ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sokak_baro_gozaltilar()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $func$
DECLARE u uuid := auth.uid(); t timestamptz := oyun.simdi();
BEGIN
  IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
  IF u IS DISTINCT FROM oyun.baro_baskan() THEN
    RETURN jsonb_build_object('baro_baskani', false, 'gozaltilar', '[]'::jsonb);
  END IF;
  RETURN jsonb_build_object('baro_baskani', true, 'gozaltilar', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', g.id, 'eylem_id', g.eylem_id, 'hedef', oyun.kad(g.hedef), 'bitis', g.bitis,
      'avukat', oyun.kad(g.avukat), 'avukat_durum', g.avukat_durum,
      'talep_var', EXISTS (SELECT 1 FROM oyun.sokak_baro_talep b WHERE b.gozalti_id = g.id AND b.durum = 'bekliyor')
    ) ORDER BY g.baslangic DESC)
    FROM oyun.sokak_gozalti g WHERE g.durum = 'aktif' AND g.bitis > t), '[]'::jsonb));
END $func$;

CREATE OR REPLACE FUNCTION public.sokak_baro_gonder(p_gozalti bigint, p_avukat uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti;
begin
 if u is null or u is distinct from oyun.baro_baskan() then raise exception 'Yalnız baro başkanı müdafi gönderebilir';end if;
 if p_avukat is null then raise exception 'Avukat seçin';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.durum<>'aktif' or g.bitis<=oyun.simdi() then raise exception 'Devam eden gözaltı yok';end if;
 if g.avukat_durum='kabul' then raise exception 'Bu dosyanın avukatı zaten görevde';end if;
 if p_avukat=g.hedef or not exists(select 1 from oyun.avukat_ruhsat where user_id=p_avukat and durum='aktif')
 or not exists(select 1 from oyun.baro_uyeleri where user_id=p_avukat and durum='aktif') then
 raise exception 'Baroya kayıtlı ve ruhsatı aktif başka bir avukat seçin';end if;
 if exists(select 1 from oyun.sokak_polis where id=g.polis_id and yapan=p_avukat) then raise exception 'Gözaltı kararını veren görevli müdafi olamaz';end if;
 insert into oyun.sokak_baro_talep(gozalti_id,talep_eden,durum,basvuru,avukat,gorevlendiren,karar_zamani)
 values(p_gozalti,u,'gorevlendirildi',oyun.simdi(),p_avukat,u,oyun.simdi())
 on conflict (gozalti_id) do update set durum='gorevlendirildi',avukat=p_avukat,gorevlendiren=u,karar_zamani=oyun.simdi();
 update oyun.sokak_gozalti set avukat=p_avukat,avukat_durum='cagrildi' where id=p_gozalti;
 perform oyun.bildir(p_avukat,'Baro sizi gözaltı #'||p_gozalti||' ('||oyun.kad(g.hedef)||') için müdafi olarak gönderdi. Halk Hareketleri › Hukuk bölümünden kabul edin; müvekkilinizle görüşebilirsiniz.');
 perform oyun.bildir(g.hedef,'Baro gözaltı #'||p_gozalti||' için size avukat ('||oyun.kad(p_avukat)||') gönderdi. Halk Hareketleri › Hukuk bölümünden görüşebilirsiniz.');
 return jsonb_build_object('tamam',true,'durum','gorevlendirildi');
end $function$;

-- Eski "talep → ata" yolu da çalışmaya devam eder; ret veren avukatın yerine yenisi atanabilir.
CREATE OR REPLACE FUNCTION public.sokak_baro_ata(p_gozalti bigint, p_avukat uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
begin
 return public.sokak_baro_gonder(p_gozalti,p_avukat);
end $function$;

-- Avukat cevabı: kabul edince müvekkil ve baro başkanı haberdar olur.
CREATE OR REPLACE FUNCTION public.sokak_avukat_cevap(p_gozalti bigint, p_kabul boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare u uuid:=auth.uid();g oyun.sokak_gozalti; bas uuid;
begin
 if u is null or p_kabul is null then raise exception 'Oturum ve cevap gerekli';end if;
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.avukat is distinct from u or g.avukat_durum<>'cagrildi' then raise exception 'Sizin için bekleyen avukat çağrısı bulunmuyor';end if;
 update oyun.sokak_gozalti set avukat_durum=case when p_kabul then 'kabul' else 'ret' end where id=p_gozalti;
 perform oyun.bildir(g.hedef,'Avukat '||oyun.kad(u)||' gözaltı #'||g.id||' için '||case when p_kabul then 'savunmanızı üstlendi. Hukuk bölümünden görüşebilirsiniz.' else 'görevi reddetti.' end);
 if not p_kabul and exists(select 1 from oyun.sokak_baro_talep where gozalti_id=g.id and gorevlendiren is not null) then
  bas:=oyun.baro_baskan();
  if bas is not null then perform oyun.bildir(bas,'Gözaltı #'||g.id||': gönderilen avukat görevi reddetti, başka avukat gönderin.');end if;
 end if;
 return jsonb_build_object('tamam',true);
end $function$;

-- ── 5. Gözaltı görüşmesi ve avukat dilekçesi ───────────────────────────────
CREATE OR REPLACE FUNCTION oyun.gozalti_gorusme_yetki(p_gozalti bigint, u uuid)
RETURNS oyun.sokak_gozalti LANGUAGE plpgsql STABLE SET search_path TO '' AS $f$
declare g oyun.sokak_gozalti;
begin
 select * into g from oyun.sokak_gozalti where id=p_gozalti;
 if g.id is null then raise exception 'Gözaltı dosyası bulunamadı';end if;
 if u is null or not (u=g.hedef or (u=g.avukat and g.avukat_durum in ('cagrildi','kabul'))) then
  raise exception 'Görüşme yalnız gözaltındaki oyuncu ile avukatı arasındadır';end if;
 if g.avukat is null or g.avukat_durum not in ('cagrildi','kabul') then
  raise exception 'Önce bir avukat çağırın ya da barodan müdafi isteyin';end if;
 return g;
end $f$;

CREATE OR REPLACE FUNCTION public.gozalti_gorusme_gonder(p_gozalti bigint, p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti; m text:=btrim(coalesce(p_metin,'')); karsi uuid; son int;
begin
 g:=oyun.gozalti_gorusme_yetki(p_gozalti,u);
 if char_length(m) not between 1 and 2000 then raise exception 'Mesaj 1–2000 karakter olmalı';end if;
 if coalesce(g.cb_serbest_zaman,g.bitis) < oyun.simdi()-interval '7 days' then raise exception 'Dosya kapanalı 7 günü geçti; görüşme kapandı';end if;
 select count(*) into son from oyun.gozalti_gorusme where gonderen=u and zaman>oyun.simdi()-interval '1 minute';
 if son>=10 then raise exception 'Çok hızlı mesaj gönderiyorsun; biraz bekle';end if;
 insert into oyun.gozalti_gorusme(kaynak,dosya_id,gonderen,metin,zaman) values('sokak',g.id,u,m,oyun.simdi());
 karsi:=case when u=g.hedef then g.avukat else g.hedef end;
 if not exists(select 1 from oyun.gozalti_gorusme where kaynak='sokak' and dosya_id=g.id and gonderen=u
   and zaman>oyun.simdi()-interval '10 minutes' and zaman<oyun.simdi()) then
  perform oyun.bildir(karsi,'🔒 Gözaltı görüşmesi #'||g.id||': '||oyun.kad(u)||' mesaj gönderdi — '||left(m,120));
 end if;
 return jsonb_build_object('tamam',true);
end $f$;

CREATE OR REPLACE FUNCTION public.gozalti_gorusme_liste(p_gozalti bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $f$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti;
begin
 g:=oyun.gozalti_gorusme_yetki(p_gozalti,u);
 return jsonb_build_object('tamam',true,'gozalti_id',g.id,
  'avukat',oyun.kad(g.avukat),'avukat_durum',g.avukat_durum,'hedef',oyun.kad(g.hedef),
  'cb_dilekce',g.cb_dilekce,'cb_dilekce_at',g.cb_dilekce_at,
  'mesajlar',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'ad',oyun.kad(x.gonderen),'ben',x.gonderen=u,
     'avukat',x.gonderen=g.avukat,'metin',x.metin,'zaman',x.zaman) order by x.zaman)
   from (select * from oyun.gozalti_gorusme where kaynak='sokak' and dosya_id=g.id order by zaman desc limit 100) x),'[]'::jsonb));
end $f$;

CREATE OR REPLACE FUNCTION public.sokak_avukat_cb_dilekce(p_gozalti bigint, p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $f$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti; m text:=btrim(coalesce(p_metin,'')); cb uuid;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.avukat is distinct from u or g.avukat_durum<>'kabul' then raise exception 'Tahliye dilekçesini yalnız dosyanın avukatı verebilir';end if;
 if g.durum<>'aktif' or g.bitis<=oyun.simdi() then raise exception 'Devam eden gözaltı yok';end if;
 if g.cb_dilekce is not null then raise exception 'Bu dosyada Cumhurbaşkanlığına dilekçe zaten verildi';end if;
 if char_length(m) not between 20 and 2000 then raise exception 'Dilekçe 20–2000 karakter olmalı';end if;
 update oyun.sokak_gozalti set cb_dilekce=m,cb_dilekce_at=oyun.simdi(),cb_dilekce_avukat=u where id=g.id;
 cb:=oyun.cb_kim();
 if cb is not null then perform oyun.bildir(cb,'📜 Avukat '||oyun.kad(u)||', gözaltı #'||g.id||' ('||oyun.kad(g.hedef)||') için tahliye dilekçesi verdi. Halk Hareketleri › Hukuk bölümünden karar verebilirsiniz.');end if;
 perform oyun.bildir(g.hedef,'Avukatınız gözaltı #'||g.id||' için Cumhurbaşkanlığına tahliye dilekçesi verdi.');
 return jsonb_build_object('tamam',true,'cb_bildirildi',cb is not null);
end $f$;

REVOKE ALL ON FUNCTION public.cb_icisleri_gozalti_serbest(bigint,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sokak_baro_gozaltilar() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sokak_baro_gonder(bigint,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gozalti_gorusme_gonder(bigint,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gozalti_gorusme_liste(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sokak_avukat_cb_dilekce(bigint,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION oyun.gozalti_gorusme_yetki(bigint,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cb_icisleri_gozalti_serbest(bigint,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sokak_baro_gozaltilar() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sokak_baro_gonder(bigint,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gozalti_gorusme_gonder(bigint,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gozalti_gorusme_liste(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sokak_avukat_cb_dilekce(bigint,text) TO authenticated;

-- İtiraz edilmiş İçişleri gözaltısı da süresi bitene (ya da CB kararına) kadar sürer.
CREATE OR REPLACE FUNCTION oyun.icisleri_gozaltinda_v2(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $function$
 SELECT EXISTS(SELECT 1 FROM oyun.icisleri_tedbir_v2 WHERE hedef=p_user AND tur='gozalti' AND durum IN ('onay','itiraz') AND bitis>oyun.simdi())
$function$;

CREATE OR REPLACE FUNCTION oyun.icisleri_tedbir_aktif(p_user uuid, p_tur text)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $function$
 SELECT EXISTS(SELECT 1 FROM oyun.icisleri_tedbir_v2 WHERE hedef=p_user AND tur=p_tur
   AND (durum='onay' OR (durum='itiraz' AND tur='gozalti')) AND bitis>oyun.simdi())
$function$;
