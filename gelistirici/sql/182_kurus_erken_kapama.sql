-- 182 · Oyuncu bankası kredilerinde erken kapama 0,01 TL hassasiyetinde tahsil edilir.
-- Eski para_islem tam TL'ye yuvarladığından, erken kapamada sıfır veya fazla tahsilat önlenir.
CREATE OR REPLACE FUNCTION public.oyb_kredi_erken_kapat(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  u uuid := auth.uid();
  t timestamptz := oyun.simdi();
  k oyun.oyb_kredi;
  e jsonb;
  tutar numeric;
  faiz numeric;
BEGIN
  IF u IS NULL THEN RAISE EXCEPTION 'Oturum gerekli.'; END IF;
  PERFORM 1 FROM oyun.sirketler s
    JOIN oyun.oyb_kredi x ON x.banka_id=s.id
    WHERE x.id=p_id FOR UPDATE OF s;
  SELECT * INTO k FROM oyun.oyb_kredi
    WHERE id=p_id AND borclu=u FOR UPDATE;
  IF k.id IS NULL THEN RAISE EXCEPTION 'Kredi bulunamadı.'; END IF;
  IF k.durum <> 'aktif' THEN RAISE EXCEPTION 'Kredi aktif değil.'; END IF;

  e := oyun.oyb_erken_kapama_tutari(k, t);
  tutar := (e->>'tutar')::numeric;
  IF e IS NULL OR tutar IS NULL OR tutar < 0
     OR tutar <> round(tutar,2) THEN
    RAISE EXCEPTION 'Erken kapama tutarı geçersiz.';
  END IF;

  -- Genel para_islem işlevi tam TL'ye yuvarladığından bu yol
  -- kalan 0,14 TL gibi borçlarda tam tutarı tahsil eder.
  IF tutar > 0 THEN
    PERFORM oyun.cuzdanim(u);
    UPDATE oyun.cuzdan SET para=para-tutar
      WHERE user_id=u AND para>=tutar;
    IF NOT FOUND THEN RAISE EXCEPTION 'Cüzdanında yeterli para yok.'; END IF;
    INSERT INTO oyun.hesap_hareket(user_id, zaman, tutar, vergi, tur, aciklama)
      VALUES (u,t,-tutar,0,'oyb_kredi','Kredi #'||k.id||' erken kapama');
  END IF;
  UPDATE oyun.sirketler SET kasa=kasa+tutar WHERE id=k.banka_id;
  faiz := greatest(0,tutar-greatest(0,k.anapara-k.anapara_odendi));
  UPDATE oyun.oyb_kredi SET
    kalan=0, anapara_odendi=anapara, durum='odendi', kapanis=t,
    erken_kapama=true, erken_indirim=(e->>'indirim')::numeric
  WHERE id=k.id;
  IF faiz>0 THEN
    INSERT INTO oyun.sirket_hareket(sirket_id,tutar,aciklama)
      VALUES(k.banka_id,faiz,'Kredi #'||k.id||' erken kapama faiz geliri');
  END IF;
  PERFORM oyun.bildir(o.user_id,
      format('%s, kredi #%s borcunu erken kapattı (%s ₺).',
         oyun.kad(u),k.id,oyun.tl(tutar)),t)
    FROM oyun.sirket_ortaklari o
    WHERE o.sirket_id=k.banka_id AND o.pay>=50;
  RETURN jsonb_build_object('tamam',true,'odenen',tutar,
                            'indirim',(e->>'indirim')::numeric);
END $function$;
