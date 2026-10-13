-- 2026-10-13: Sohbet sekmesinin kirmizi sayaci tum erisilebilir odalari ve ozel mesajlari sayar.
-- Oyuncu, para, gorev veya mesaj verilerinde degisiklik yapmaz.
CREATE OR REPLACE FUNCTION oyun.sohbet_okunmamis(p oyun.profiller)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  WITH kanallar AS (
    SELECT DISTINCT oyun.kanal_coz(p, x.kod) AS kanal
    FROM unnest(ARRAY[
      'genel','il','belediye','parti','yonetim',
      'ittifak','meclis','grup','divan','kabine'
    ]::text[]) AS x(kod)
  )
  SELECT coalesce(sum(s.sayi), 0)::integer
  FROM kanallar k
  CROSS JOIN LATERAL (
    SELECT count(*) AS sayi
    FROM (
      SELECT 1
      FROM oyun.mesajlar m
      LEFT JOIN oyun.kanal_okuma r
        ON r.user_id = p.id AND r.kanal = k.kanal
      WHERE k.kanal IS NOT NULL
        AND m.kanal = k.kanal
        AND m.id > coalesce(r.son_id, 0)
        AND m.user_id <> p.id
        AND NOT m.gizli
        AND m.zaman <= oyun.simdi()
        AND m.zaman > oyun.simdi() - interval '3 days'
        AND NOT oyun.engelli(p.id, m.user_id)
      LIMIT 100
    ) yeni
  ) s;
$$;

-- Eski 'ozel' alani ozel mesaj listesi icin aynen korunur.
-- Yeni 'sohbet' alani: okunmamis ozel mesaj + tum kanallar.
CREATE OR REPLACE FUNCTION oyun.okunmamis(p oyun.profiller)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  WITH sayac AS (
    SELECT
      (
        (SELECT count(*)
           FROM oyun.yayinlar y
          WHERE NOT y.gizli
            AND y.gonderen <> p.id
            AND y.zaman > p.bildirim_okundu
            AND y.zaman <= oyun.simdi()
            AND oyun.yayin_gorur(y, p)
            AND NOT oyun.engelli(p.id, y.gonderen))
        +
        (SELECT count(*)
           FROM oyun.bildirimler b
          WHERE b.user_id = p.id
            AND b.zaman > p.bildirim_okundu
            AND b.zaman <= oyun.simdi())
      ) AS bildirim,
      (SELECT count(*)
         FROM oyun.ozel o
        WHERE o.alici = p.id
          AND NOT o.okundu
          AND NOT o.gizli
          AND NOT oyun.engelli(p.id, o.gonderen)) AS ozel
  )
  SELECT jsonb_build_object(
    'bildirim', sayac.bildirim,
    'ozel', sayac.ozel,
    'sohbet', sayac.ozel + oyun.sohbet_okunmamis(p)
  )
  FROM sayac;
$$;
