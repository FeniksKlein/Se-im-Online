-- 181 · Kredi borçlarında 0,01 TL (1 kuruş) alt sınırı ve tam kuruş tahsilatı.
-- Yalnız RPC işlevleri değişir; hesaplar/borçlar ve geçmiş hareketlere dokunulmaz.
-- Kredi kartlarında mevcut 0,01 TL tahsilat davranışı korunur.

CREATE OR REPLACE FUNCTION public.kredi_ode(p_miktar numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  k oyun.krediler;
  c oyun.cuzdan;
  v oyun.banka_musteri;
  m numeric;
  mevcut numeric;
  c_odeme numeric;
  v_odeme numeric;
  kapama boolean := p_miktar IS NULL;
  aciklama text;
BEGIN
  IF p_miktar IS NOT NULL AND
     (p_miktar < 0.01 OR p_miktar <> round(p_miktar, 2)) THEN
    RAISE EXCEPTION 'En az 0,01 TL gir; kuruş için en fazla iki ondalık kullan.';
  END IF;

  SELECT * INTO k FROM oyun.krediler
   WHERE user_id = p.id AND durum IN ('aktif','takip')
   FOR UPDATE;
  IF k.id IS NULL THEN
    RAISE EXCEPTION 'Ödenecek kredin yok.';
  END IF;

  m := CASE WHEN kapama THEN round(oyun.erken_kapama(k), 2)
            ELSE LEAST(p_miktar, round(k.kalan, 2)) END;
  IF m IS NULL OR m < 0.01 THEN
    RAISE EXCEPTION 'Ödeme tutarı en az 0,01 TL olmalı.';
  END IF;
  IF m >= round(oyun.erken_kapama(k), 2) THEN
    kapama := true;
    m := round(oyun.erken_kapama(k), 2);
  END IF;

  c := oyun.cuzdanim(p.id);
  v := oyun.vadesiz_isle(p.id, t);
  mevcut := greatest(0, coalesce(c.para, 0)) + greatest(0, coalesce(v.vadesiz, 0));
  IF mevcut < m THEN
    RAISE EXCEPTION 'Bu ödeme için % TL gerekiyor; cüzdanında ve vadesiz hesabında toplam % TL var.',
      trim(to_char(m, 'FM999999999999990D00')), trim(to_char(mevcut, 'FM999999999999990D00'));
  END IF;

  aciklama := CASE WHEN kapama THEN 'Kredi erken kapama' ELSE 'Kredi ara ödemesi' END;
  c_odeme := LEAST(m, greatest(0, coalesce(c.para, 0)));
  IF c_odeme > 0 THEN
    UPDATE oyun.cuzdan SET para = para - c_odeme
     WHERE user_id = p.id AND para >= c_odeme;
    IF NOT FOUND THEN RAISE EXCEPTION 'Cüzdan bakiyesi yetersiz.'; END IF;
    INSERT INTO oyun.hesap_hareket(user_id, zaman, tutar, vergi, tur, aciklama)
      VALUES(p.id, t, -c_odeme, 0, 'kredi', aciklama);
  END IF;

  v_odeme := round(m - c_odeme, 2);
  IF v_odeme > 0 THEN
    UPDATE oyun.banka_musteri SET vadesiz = vadesiz - v_odeme
     WHERE user_id = p.id AND vadesiz >= v_odeme;
    IF NOT FOUND THEN RAISE EXCEPTION 'Vadesiz hesap bakiyesi yetersiz.'; END IF;
    INSERT INTO oyun.banka_hareket(user_id, zaman, hesap, tutar, aciklama)
      VALUES(p.id, t, 'vadesiz', -v_odeme, 'Kredi borcuna mahsup edildi');
  END IF;

  -- Var olan banka_kayit yardımcı fonksiyonu tam liraya yuvarladığı için
  -- bu ödeme kaydı doğrudan, kuruşları kaybetmeden yazılır.
  INSERT INTO oyun.banka_hareket(user_id, zaman, hesap, tutar, aciklama)
    VALUES(p.id, t, 'kredi', -m, CASE WHEN kapama THEN 'Erken kapama' ELSE 'Ara ödeme' END);

  IF kapama THEN
    PERFORM oyun.kredi_kapat(k, t);
  ELSE
    UPDATE oyun.krediler
       SET kalan = greatest(0, round(kalan - m, 2)),
           gecikmis = greatest(0, round(gecikmis - m, 2)),
           gecikme_gun = CASE WHEN gecikmis - m <= 0 THEN 0 ELSE gecikme_gun END
     WHERE id = k.id;
  END IF;
  RETURN public.banka();
END $function$;

CREATE OR REPLACE FUNCTION public.oyb_kredi_ode(p_id bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  u uuid := auth.uid();
  k oyun.oyb_kredi;
  s oyun.sirketler;
  t timestamptz := oyun.simdi();
  ode numeric;
  anapara_bolum numeric;
  faiz_bolum numeric;
  yeni numeric;
BEGIN
  IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
  IF p_tutar IS NULL OR p_tutar < 0.01 OR p_tutar <> round(p_tutar, 2)
     OR p_tutar > 1000000 THEN
    RAISE EXCEPTION 'Ödeme en az 0,01 TL olmalı; en fazla iki ondalık kullan.';
  END IF;

  SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_id AND borclu=u;
  IF NOT FOUND THEN RAISE EXCEPTION 'Kredi bulunamadı'; END IF;
  SELECT * INTO s FROM oyun.sirketler WHERE id=k.banka_id FOR UPDATE;
  SELECT * INTO k FROM oyun.oyb_kredi WHERE id=p_id AND borclu=u FOR UPDATE;
  IF k.durum<>'aktif' THEN RAISE EXCEPTION 'Kredi aktif değil'; END IF;

  ode := LEAST(p_tutar, k.kalan);
  IF ode < 0.01 THEN RAISE EXCEPTION 'Ödenecek borç bulunamadı'; END IF;
  PERFORM oyun.cuzdanim(u);
  UPDATE oyun.cuzdan SET para=para-ode WHERE user_id=u AND para>=ode;
  IF NOT FOUND THEN RAISE EXCEPTION 'Cüzdanında yeterli para yok'; END IF;

  -- Genel para_islem tam TL'ye yuvarlar; borç ödemesinde kuruşları
  -- korumak için işlem defterine kesin tutar kaydedilir.
  INSERT INTO oyun.hesap_hareket(user_id, zaman, tutar, vergi, tur, aciklama)
    VALUES (u, t, -ode, 0, 'oyb_kredi', 'Oyuncu bankası kredi geri ödeme #'||k.id);
  UPDATE oyun.sirketler SET kasa=kasa+ode WHERE id=k.banka_id;
  anapara_bolum := LEAST(ode, greatest(0, k.anapara-k.anapara_odendi));
  faiz_bolum := ode-anapara_bolum;
  yeni := round(k.kalan-ode, 2);
  UPDATE oyun.oyb_kredi SET
    kalan=yeni,
    anapara_odendi=anapara_odendi+anapara_bolum,
    durum=CASE WHEN yeni<=0 THEN 'odendi' ELSE 'aktif' END,
    kapanis=CASE WHEN yeni<=0 THEN t ELSE NULL END
  WHERE id=k.id;
  IF faiz_bolum>0 THEN
    INSERT INTO oyun.sirket_hareket(sirket_id,tutar,aciklama)
    VALUES(k.banka_id, faiz_bolum,
      'Oyuncu kredisi #'||k.id||' tahsil edilen faiz geliri');
  END IF;
  RETURN jsonb_build_object('odendi',ode,'kalan',yeni,
                            'tamam',yeni<=0,'faiz_geliri',faiz_bolum);
END $function$;
