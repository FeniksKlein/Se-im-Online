-- Bakanlık teklifi bildirimine doğrudan kabul/ret işlemi eklenebilmesi için
-- bildirim kutusundaki kişisel bildirimin ilgili bekleyen teklif ID'sini döndür.
-- Yalnızca oturum sahibine ait ve mevcut yürütmenin gönderdiği bekleyen teklifler ilişkilendirilir.
CREATE OR REPLACE FUNCTION public.bildirim_kutusu(p_limit integer DEFAULT 60)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
DECLARE
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  j jsonb;
  lim integer := least(greatest(p_limit, 1), 100);
BEGIN
  SELECT coalesce(jsonb_agg(u.x ORDER BY u.z DESC), '[]'::jsonb)
  INTO j
  FROM (
    (SELECT jsonb_build_object(
       'tur', 'yayin',
       'id', y.id,
       'yayin_tur', y.tur,
       'zaman', y.zaman,
       'metin', y.metin,
       'kad', coalesce(pr.kad, '(silinmiş)'),
       'unvan', y.unvan,
       'parti', oyun.parti_json(pr.parti_id),
       'benim', y.gonderen = p.id,
       'yeni', y.zaman > p.bildirim_okundu AND y.gonderen <> p.id
     ) x, y.zaman z
     FROM oyun.yayinlar y
     LEFT JOIN oyun.profiller pr ON pr.id = y.gonderen
     WHERE NOT y.gizli
       AND y.zaman <= t
       AND oyun.yayin_gorur(y, p)
       AND NOT oyun.engelli(p.id, y.gonderen)
     ORDER BY y.zaman DESC
     LIMIT lim)
    UNION ALL
    (SELECT jsonb_build_object(
       'tur', 'kisisel',
       'id', b.id,
       'zaman', b.zaman,
       'metin', b.metin,
       'yeni', b.zaman > p.bildirim_okundu,
       'teklif_id', (
          SELECT bt.id
          FROM oyun.bakan_teklifleri bt
          WHERE bt.aday = p.id
            AND bt.durum = 'bekliyor'
            AND bt.teklif_eden = oyun.yurutme_user()
            AND bt.zaman = b.zaman
          ORDER BY bt.id DESC
          LIMIT 1
       )
     ) x, b.zaman z
     FROM oyun.bildirimler b
     WHERE b.user_id = p.id AND b.zaman <= t
     ORDER BY b.zaman DESC
     LIMIT lim)
  ) u;
  UPDATE oyun.profiller SET bildirim_okundu = t WHERE id = p.id;
  RETURN j;
END
$function$;
