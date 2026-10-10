-- 2026-10-10 | Gayrimenkulde cok turlu karsilikli pazarlik.
-- Mevcut tapu, bakiye ve ilanlari sifirlamaz.
CREATE TABLE IF NOT EXISTS oyun.emlak_pazarlik_adimlari (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pazarlik_id bigint NOT NULL REFERENCES oyun.emlak_pazarlik(id) ON DELETE CASCADE,
  tur integer NOT NULL CHECK (tur > 0),
  teklif_eden uuid NOT NULL REFERENCES oyun.profiller(id),
  fiyat numeric NOT NULL CHECK (fiyat BETWEEN 10000 AND 1000000000 AND fiyat = trunc(fiyat)),
  zaman timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pazarlik_id, tur)
);
CREATE INDEX IF NOT EXISTS emlak_pazarlik_adimlari_sira ON oyun.emlak_pazarlik_adimlari(pazarlik_id,tur);
ALTER TABLE oyun.emlak_pazarlik_adimlari ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.emlak_pazarlik_adimlari FROM PUBLIC, anon, authenticated;
ALTER TABLE oyun.emlak_pazarlik ADD COLUMN IF NOT EXISTS vazgecen uuid REFERENCES oyun.profiller(id);

-- Onceki surumdeki pazarliklari ve ilk teklifleri gorunur tut.
INSERT INTO oyun.emlak_pazarlik_adimlari(pazarlik_id,tur,teklif_eden,fiyat,zaman)
SELECT z.id,1,z.alici,z.teklif,z.zaman FROM oyun.emlak_pazarlik z
WHERE NOT EXISTS (SELECT 1 FROM oyun.emlak_pazarlik_adimlari a WHERE a.pazarlik_id=z.id AND a.tur=1)
ON CONFLICT (pazarlik_id,tur) DO NOTHING;
INSERT INTO oyun.emlak_pazarlik_adimlari(pazarlik_id,tur,teklif_eden,fiyat,zaman)
SELECT z.id,2,z.satici,z.karsi_teklif,z.zaman FROM oyun.emlak_pazarlik z
WHERE z.karsi_teklif IS NOT NULL AND NOT EXISTS
(SELECT 1 FROM oyun.emlak_pazarlik_adimlari a WHERE a.pazarlik_id=z.id AND a.tur=2)
ON CONFLICT (pazarlik_id,tur) DO NOTHING;

CREATE OR REPLACE FUNCTION public.emlak_pazarliklarim()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'id',z.id,'ilan_id',z.ilan_id,'teklif',z.teklif,'karsi_teklif',z.karsi_teklif,
   'durum',z.durum,'zaman',z.zaman,'alici',a.kad,'satici',s.kad,
   'ben_aliciyim',z.alici=auth.uid(),'ben_saticiyim',z.satici=auth.uid(),
   'ilan_acik',i.durum='acik','mulk_id',i.mulk_id,
   'tip',m.tip,'il',il.ad,'ilan_fiyati',i.fiyat,
   'vazgecen',case when z.vazgecen=z.alici then 'alici'
                   when z.vazgecen=z.satici then 'satici' else null end,
   'turlar',coalesce((select jsonb_agg(jsonb_build_object(
      'tur',ad.tur,'fiyat',ad.fiyat,'zaman',ad.zaman,
      'taraf',case when ad.teklif_eden=z.alici then 'alici' else 'satici' end,
      'kullanici',p.kad) order by ad.tur)
      from oyun.emlak_pazarlik_adimlari ad join oyun.profiller p on p.id=ad.teklif_eden
      where ad.pazarlik_id=z.id),'[]'::jsonb)
 ) order by z.zaman desc),'[]'::jsonb)
 from oyun.emlak_pazarlik z
 join oyun.mulk_ilan i on i.id=z.ilan_id
 join oyun.yatirim_mulkleri m on m.id=i.mulk_id
 join oyun.iller il on il.id=m.il_id
 join oyun.profiller a on a.id=z.alici join oyun.profiller s on s.id=z.satici
 where (z.alici=auth.uid() or z.satici=auth.uid())
   and z.zaman>oyun.simdi()-interval '60 days'
$$;
REVOKE ALL ON FUNCTION public.emlak_pazarliklarim() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.emlak_pazarliklarim() TO authenticated;

CREATE OR REPLACE FUNCTION public.emlak_pazarlik_teklif(p_ilan bigint,p_fiyat numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();i oyun.mulk_ilan; idd bigint; t timestamptz:=oyun.simdi();
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=u AND NOT yasakli)
   THEN RAISE EXCEPTION 'Oyuncu hesabı gerekli.'; END IF;
 IF p_fiyat IS NULL OR p_fiyat<10000 OR p_fiyat>1000000000 OR p_fiyat<>trunc(p_fiyat)
   THEN RAISE EXCEPTION 'Teklif tutarı 10.000 ile 1 milyar ₺ arasında tam sayı olmalı.'; END IF;
 SELECT * INTO i FROM oyun.mulk_ilan WHERE id=p_ilan FOR UPDATE;
 IF i.id IS NULL OR i.durum<>'acik' THEN RAISE EXCEPTION 'Bu ilan artık satılık değil.'; END IF;
 IF i.satici=u THEN RAISE EXCEPTION 'Kendi mülküne teklif veremezsin.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM oyun.yatirim_mulkleri WHERE id=i.mulk_id AND user_id=i.satici)
   THEN RAISE EXCEPTION 'Mülk artık satıcının değil.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.emlak_pazarlik WHERE ilan_id=p_ilan AND alici=u AND durum IN ('bekliyor','karsi'))
   THEN RAISE EXCEPTION 'Bu ilan için önceki pazarlığın sürüyor.'; END IF;
 INSERT INTO oyun.emlak_pazarlik(ilan_id,alici,satici,teklif,zaman)
 VALUES(p_ilan,u,i.satici,p_fiyat,t) RETURNING id INTO idd;
 INSERT INTO oyun.emlak_pazarlik_adimlari(pazarlik_id,tur,teklif_eden,fiyat,zaman)
 VALUES(idd,1,u,p_fiyat,t);
 PERFORM oyun.bildir(i.satici,format('%s mülk #%s için %s ₺ teklif verdi. Gayrimenkul > Pazarlıklarım bölümünden yanıtla.',
 (SELECT kad FROM oyun.profiller WHERE id=u),i.mulk_id,oyun.tl(p_fiyat)),t);
 RETURN jsonb_build_object('id',idd,'durum','bekliyor');
END $$;
REVOKE ALL ON FUNCTION public.emlak_pazarlik_teklif(bigint,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.emlak_pazarlik_teklif(bigint,numeric) TO authenticated;

-- Eski uygulamalardaki satici fonksiyonu ayni imzayla calisir.
CREATE OR REPLACE FUNCTION public.emlak_pazarlik_satici_yanit(p_teklif bigint,p_karar text,p_karsi numeric DEFAULT null)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();z oyun.emlak_pazarlik;i oyun.mulk_ilan;t timestamptz:=oyun.simdi(); n integer;
BEGIN
 SELECT * INTO z FROM oyun.emlak_pazarlik WHERE id=p_teklif FOR UPDATE;
 IF z.id IS NULL OR z.satici IS DISTINCT FROM u OR z.durum<>'bekliyor'
   THEN RAISE EXCEPTION 'Yanıt verebileceğin açık teklif yok.'; END IF;
 SELECT * INTO i FROM oyun.mulk_ilan WHERE id=z.ilan_id;
 IF i.id IS NULL OR i.durum<>'acik' OR i.satici<>u THEN RAISE EXCEPTION 'İlan artık satışta değil.'; END IF;
 IF p_karar NOT IN ('kabul','red','karsi') OR p_karar IS NULL THEN RAISE EXCEPTION 'Geçersiz yanıt.'; END IF;
 IF p_karar='kabul' THEN
   PERFORM oyun._emlak_pazarlik_tamamla(z.id,z.teklif);
 ELSIF p_karar='red' THEN
   UPDATE oyun.emlak_pazarlik SET durum='red',sonuc_at=t WHERE id=z.id;
   PERFORM oyun.bildir(z.alici,'Mülk teklifin satıcı tarafından reddedildi.',t);
 ELSE
   IF p_karsi IS NULL OR p_karsi<10000 OR p_karsi>1000000000 OR p_karsi<>trunc(p_karsi)
     THEN RAISE EXCEPTION 'Geçerli bir karşı teklif tutarı gir.'; END IF;
   IF p_karsi=z.teklif THEN RAISE EXCEPTION 'Aynı tutar için kabul seçeneğini kullan.'; END IF;
   SELECT coalesce(max(tur),0)+1 INTO n FROM oyun.emlak_pazarlik_adimlari WHERE pazarlik_id=z.id;
   INSERT INTO oyun.emlak_pazarlik_adimlari(pazarlik_id,tur,teklif_eden,fiyat,zaman)
   VALUES(z.id,n,u,p_karsi,t);
   UPDATE oyun.emlak_pazarlik SET durum='karsi',karsi_teklif=p_karsi WHERE id=z.id;
   PERFORM oyun.bildir(z.alici,format('%s ₺ karşı teklif geldi. Gayrimenkul > Pazarlıklarım bölümünden kabul et veya yeni fiyat öner.',oyun.tl(p_karsi)),t);
 END IF;
 RETURN jsonb_build_object('durum',p_karar);
END $$;
REVOKE ALL ON FUNCTION public.emlak_pazarlik_satici_yanit(bigint,text,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.emlak_pazarlik_satici_yanit(bigint,text,numeric) TO authenticated;

-- YENI: alici reddetmek yerine yeni bir fiyat bildirir; tur tekrar saticiya gecer.
CREATE OR REPLACE FUNCTION public.emlak_pazarlik_alici_karsi(p_teklif bigint,p_fiyat numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();z oyun.emlak_pazarlik;i oyun.mulk_ilan;t timestamptz:=oyun.simdi();n integer;
BEGIN
 IF u IS NULL OR NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=u AND NOT yasakli)
   THEN RAISE EXCEPTION 'Oyuncu hesabı gerekli.'; END IF;
 IF p_fiyat IS NULL OR p_fiyat<10000 OR p_fiyat>1000000000 OR p_fiyat<>trunc(p_fiyat)
   THEN RAISE EXCEPTION '10.000 - 1.000.000.000 ₺ arası tam sayı tutar gir.'; END IF;
 SELECT * INTO z FROM oyun.emlak_pazarlik WHERE id=p_teklif FOR UPDATE;
 IF z.id IS NULL OR z.alici IS DISTINCT FROM u OR z.durum<>'karsi'
   THEN RAISE EXCEPTION 'Sana gelen cevaplanmamış bir karşı teklif bulunamadı.'; END IF;
 SELECT * INTO i FROM oyun.mulk_ilan WHERE id=z.ilan_id;
 IF i.id IS NULL OR i.durum<>'acik' OR i.satici<>z.satici OR
    NOT EXISTS(SELECT 1 FROM oyun.yatirim_mulkleri WHERE id=i.mulk_id AND user_id=z.satici)
   THEN RAISE EXCEPTION 'Mülk artık satışta değil.'; END IF;
 IF p_fiyat=z.karsi_teklif THEN RAISE EXCEPTION 'Bu tutarı kabul etmek için Kabul et seçeneğini kullan.'; END IF;
 IF p_fiyat=z.teklif THEN RAISE EXCEPTION 'Yeni teklifin önceki fiyatından farklı olmalı.'; END IF;
 SELECT coalesce(max(tur),0)+1 INTO n FROM oyun.emlak_pazarlik_adimlari WHERE pazarlik_id=z.id;
 INSERT INTO oyun.emlak_pazarlik_adimlari(pazarlik_id,tur,teklif_eden,fiyat,zaman)
 VALUES(z.id,n,u,p_fiyat,t);
 UPDATE oyun.emlak_pazarlik SET teklif=p_fiyat,karsi_teklif=NULL,durum='bekliyor' WHERE id=z.id;
 PERFORM oyun.bildir(z.satici,format('%s pazarlığa devam ediyor: yeni teklif %s ₺. Gayrimenkul > Pazarlıklarım bölümünde yanıtla.',
 (SELECT kad FROM oyun.profiller WHERE id=u),oyun.tl(p_fiyat)),t);
 RETURN jsonb_build_object('durum','bekliyor','teklif',p_fiyat,'tur',n);
END $$;
REVOKE ALL ON FUNCTION public.emlak_pazarlik_alici_karsi(bigint,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.emlak_pazarlik_alici_karsi(bigint,numeric) TO authenticated;

-- Taraflar anlaşma tamamlanmadan pazarliktan ayrilabilir. Para veya tapu degismez.
CREATE OR REPLACE FUNCTION public.emlak_pazarlik_vazgec(p_teklif bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid(); z oyun.emlak_pazarlik; t timestamptz:=oyun.simdi();
BEGIN
 SELECT * INTO z FROM oyun.emlak_pazarlik WHERE id=p_teklif FOR UPDATE;
 IF u IS NULL OR z.id IS NULL OR u NOT IN (z.alici,z.satici)
   THEN RAISE EXCEPTION 'Bu pazarlığı sonlandıramazsın.'; END IF;
 IF z.durum NOT IN ('bekliyor','karsi') THEN RAISE EXCEPTION 'Pazarlık zaten sonuçlandı.'; END IF;
 UPDATE oyun.emlak_pazarlik SET durum='red',vazgecen=u,sonuc_at=t WHERE id=z.id;
 PERFORM oyun.bildir(CASE WHEN u=z.alici THEN z.satici ELSE z.alici END,
  'Gayrimenkul pazarlığı karşı tarafça sonlandırıldı.',t);
 RETURN jsonb_build_object('durum','red','vazgecen',CASE WHEN u=z.alici THEN 'alici' ELSE 'satici' END);
END $$;
REVOKE ALL ON FUNCTION public.emlak_pazarlik_vazgec(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.emlak_pazarlik_vazgec(bigint) TO authenticated;