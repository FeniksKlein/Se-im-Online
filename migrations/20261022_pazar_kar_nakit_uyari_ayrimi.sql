-- 2026-10-22: Pazar sirketleri icin finansal bildirim turleri.
-- Sirket kasasi/sermaye orani tek basina zarar kaniti degildir.
-- Para, kar dagitimi, faaliyet ve iflas islemleri degistirilmez.
-- Canli fonksiyonun beklenen surumu kontrol edilir; eszamanli degisiklikte iptal olur.
DO $patch$
DECLARE
  body_before text;
  source_sql text;
  body_after text;
BEGIN
  body_before := $before$  if kasa_son < s.sermaye * 0.25 and (ps.son_uyari is null or ps.son_uyari < t - interval '2 days') then
    update oyun.pazar_sirket set son_uyari = t where sirket_id = p_id;
    for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
      perform oyun.bildir(x.user_id, format('%s zarar ediyor: kasada %s ₺ kaldı. Fiyat/kaliteyi gözden geçir, otopilotu aç ya da ili değiştir; yoksa iflas edebilir.',
        s.ad, oyun.tl(kasa_son)), t);
    end loop;
  end if;$before$;
  body_after := $after$  if kasa_son < s.sermaye * 0.25 and (ps.son_uyari is null or ps.son_uyari < t - interval '2 days') then
    -- Nakit/sermaye orani tek basina faaliyet zarari anlamina gelmez.
    declare
      donem_net numeric := 0;
      donem_gun integer := 0;
      mesaj text;
    begin
      select coalesce(sum(g.net), 0), count(*)
        into donem_net, donem_gun
      from oyun.eko_gunluk g
      where g.sirket_id = p_id
        and g.gun between (t at time zone 'Europe/Istanbul')::date - 6
                      and (t at time zone 'Europe/Istanbul')::date;
      if donem_gun > 0 and donem_net < 0 then
        mesaj := format('%s son 7 günde %s ₺ zarar etti; şirket kasası %s ₺. Faaliyet giderlerini, fiyatı ve kaliteyi kontrol et.',
          s.ad, oyun.tl(abs(donem_net)), oyun.tl(kasa_son));
      elsif donem_gun > 0 and donem_net > 0 then
        mesaj := format('%s son 7 günde %s ₺ net kâr etti; ancak şirket kasasında %s ₺ kaldı (sermayenin %%25 seviyesinin altında). Kâr dağıtımını ve nakit rezervini gözden geçir.',
          s.ad, oyun.tl(donem_net), oyun.tl(kasa_son));
      else
        mesaj := format('%s şirket kasasında %s ₺ kaldı (sermayenin %%25 seviyesinin altında). Nakit rezervini kontrol et.',
          s.ad, oyun.tl(kasa_son));
      end if;
      update oyun.pazar_sirket set son_uyari = t where sirket_id = p_id;
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_id loop
        perform oyun.bildir(x.user_id, mesaj, t);
      end loop;
    end;
  end if;$after$;
  source_sql := pg_get_functiondef('oyun.pazar_hesapla(bigint)'::regprocedure);
  IF strpos(source_sql, body_after) > 0 THEN RETURN; END IF;
  IF md5(source_sql) <> '9debeb6426bf576302fbbd86c36cc530'
     OR strpos(source_sql, body_before) = 0 THEN
    RAISE EXCEPTION 'pazar_hesapla changed since preflight; aborting to avoid overwriting changes';
  END IF;
  EXECUTE replace(source_sql, body_before, body_after);
END
$patch$;
