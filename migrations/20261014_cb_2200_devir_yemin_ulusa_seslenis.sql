-- 14.10.2026 — Seçim sonrası 22:00 devir ve cumhurbaşkanlığı töreni.
-- İdempotent, mevcut oyuncu/oy verilerini silmez. Saatler Europe/Istanbul.
BEGIN;

-- Yalnız 14 Ekim ikinci turunu hedefle; henüz devredilmemişse 22:00'ye çek.
UPDATE oyun.secimler
SET goreve_bas = TIMESTAMPTZ '2026-10-14 22:00:00+03'
WHERE id = 45389
  AND tur = 'cb2' AND donem = '2026-11'
  AND durum = 'sonuclandi'
  AND goreve_bas > TIMESTAMPTZ '2026-10-14 22:00:00+03';

CREATE TABLE IF NOT EXISTS oyun.cb_torenleri (
  makam_id bigint PRIMARY KEY REFERENCES oyun.makamlar(id) ON DELETE CASCADE,
  secim_id bigint REFERENCES oyun.secimler(id) ON DELETE SET NULL,
  user_id uuid NOT NULL REFERENCES oyun.profiller(id) ON DELETE CASCADE,
  yemin_at timestamptz,
  hitap_at timestamptz,
  hitap_metin text,
  CONSTRAINT cb_torenleri_metin_boy CHECK (hitap_metin IS NULL OR char_length(hitap_metin) BETWEEN 30 AND 2000)
);
CREATE INDEX IF NOT EXISTS cb_torenleri_hitap_zaman ON oyun.cb_torenleri (hitap_at DESC) WHERE hitap_at IS NOT NULL;
ALTER TABLE oyun.cb_torenleri ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.cb_torenleri FROM PUBLIC, anon, authenticated;

-- İstemci yalnız kendi güncel, seçilmiş CB makamının törenini alabilir.
CREATE OR REPLACE FUNCTION public.cb_toren_durum()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT jsonb_build_object(
     'makam_id',m.id, 'secim_id',m.secim_id, 'kad',p.kad,
     'yemin_at',t.yemin_at, 'hitap_at',t.hitap_at, 'hitap_metin',t.hitap_metin,
     'bas',m.bas
  )
  FROM oyun.makamlar m
  JOIN oyun.profiller p ON p.id=m.user_id
  LEFT JOIN oyun.cb_torenleri t ON t.makam_id=m.id
  WHERE m.tur='cb' AND m.bit IS NULL AND m.secim_id IS NOT NULL
    AND m.user_id=auth.uid()
  ORDER BY m.bas DESC LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.cb_yemin_et()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  m oyun.makamlar;
  v_yemin timestamptz;
BEGIN
  SELECT * INTO m FROM oyun.makamlar
  WHERE tur='cb' AND user_id=auth.uid() AND bit IS NULL AND secim_id IS NOT NULL
  ORDER BY bas DESC LIMIT 1 FOR UPDATE;
  IF m.id IS NULL THEN RAISE EXCEPTION 'Yalnızca göreve başlayan seçilmiş Cumhurbaşkanı yemin edebilir.'; END IF;
  INSERT INTO oyun.cb_torenleri(makam_id,secim_id,user_id)
    VALUES(m.id,m.secim_id,m.user_id) ON CONFLICT(makam_id) DO NOTHING;
  UPDATE oyun.cb_torenleri
    SET yemin_at=oyun.simdi()
    WHERE makam_id=m.id AND yemin_at IS NULL
    RETURNING yemin_at INTO v_yemin;
  IF v_yemin IS NOT NULL THEN
    PERFORM oyun.olay('makam',
      format('Cumhurbaşkanı %s, göreve başlama yeminini etti.', (SELECT kad FROM oyun.profiller WHERE id=m.user_id)),
      NULL, m.parti_id, oyun.simdi());
  END IF;
  RETURN (SELECT jsonb_build_object('yemin_at',yemin_at,'makam_id',makam_id)
          FROM oyun.cb_torenleri WHERE makam_id=m.id);
END $$;

CREATE OR REPLACE FUNCTION public.cb_ulusa_seslen(p_metin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  m oyun.makamlar;
  v_metin text := btrim(coalesce(p_metin,''));
  v_hitap timestamptz;
BEGIN
  IF char_length(v_metin) NOT BETWEEN 30 AND 2000
    THEN RAISE EXCEPTION 'Ulusa sesleniş metni 30–2000 karakter olmalı.'; END IF;
  SELECT * INTO m FROM oyun.makamlar
  WHERE tur='cb' AND user_id=auth.uid() AND bit IS NULL AND secim_id IS NOT NULL
  ORDER BY bas DESC LIMIT 1 FOR UPDATE;
  IF m.id IS NULL THEN RAISE EXCEPTION 'Bu konuşmayı yalnızca görevdeki seçilmiş Cumhurbaşkanı yayımlayabilir.'; END IF;
  INSERT INTO oyun.cb_torenleri(makam_id,secim_id,user_id)
    VALUES(m.id,m.secim_id,m.user_id) ON CONFLICT(makam_id) DO NOTHING;
  UPDATE oyun.cb_torenleri SET hitap_at=oyun.simdi(),hitap_metin=v_metin
   WHERE makam_id=m.id AND yemin_at IS NOT NULL AND hitap_at IS NULL
   RETURNING hitap_at INTO v_hitap;
  IF v_hitap IS NULL THEN
    IF NOT EXISTS(SELECT 1 FROM oyun.cb_torenleri WHERE makam_id=m.id AND yemin_at IS NOT NULL)
      THEN RAISE EXCEPTION 'Önce yemin etmelisin.'; END IF;
    RAISE EXCEPTION 'Bu görev dönemi için ilk ulusa sesleniş zaten yayımlandı.';
  END IF;
  PERFORM oyun.olay('makam',
    format('Cumhurbaşkanı %s ulusa seslendi: %s',
           (SELECT kad FROM oyun.profiller WHERE id=m.user_id),left(v_metin,230)),
    NULL,m.parti_id,oyun.simdi());
  RETURN jsonb_build_object('basarili',true,'hitap_at',v_hitap,'makam_id',m.id);
END $$;

CREATE OR REPLACE FUNCTION public.cb_seslenisler()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.hitap_at DESC),'[]'::jsonb)
  FROM (
    SELECT c.makam_id,c.secim_id,c.hitap_at,c.hitap_metin,p.kad
    FROM oyun.cb_torenleri c
    JOIN oyun.profiller p ON p.id=c.user_id
    WHERE c.hitap_at IS NOT NULL AND auth.uid() IS NOT NULL
    ORDER BY c.hitap_at DESC LIMIT 20
  ) t
$$;

REVOKE ALL ON FUNCTION public.cb_toren_durum() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cb_yemin_et() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cb_ulusa_seslen(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cb_seslenisler() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cb_toren_durum() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cb_yemin_et() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cb_ulusa_seslen(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cb_seslenisler() TO authenticated;

COMMIT;

-- Saat geçmişse göreve başlamayı hemen işlemek için mevcut kronu tetikle.
SELECT oyun.tick() WHERE oyun.simdi() >= TIMESTAMPTZ '2026-10-14 22:00:00+03';
