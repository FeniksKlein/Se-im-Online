-- 30.10.2026 — Yüksek Mahkeme maaşı (Claude canlıya uyguladı)
begin;
-- 147 (30.10.2026) — Yüksek Mahkeme üyelerine makam maaşı (aylık 315.000 ₺ × fiyat düzeyi).
-- Üyeler oyun.makamlar'da değil oyun.mahkeme_uye'de tutulduğu için maaş hesabına ayrıca eklendi.
create or replace function oyun.makam_maasi(p_tur text, p_il smallint)
 returns numeric language sql stable set search_path to '' as $function$
 select (case p_tur when 'cb' then 354497 when 'cb_yardimcisi' then 330000
 when 'bakan' then 318009 when 'yargic' then 315000 when 'mv' then 310332
 when 'tbmm' then 60000 when 'bskv' then 30000 when 'grup_bskv' then 20000
 when 'bel' then (select case when mv>=14 then 317800 when mv>=8 then 267800 when mv>=4 then 198900 else 171400 end from oyun.iller where id=p_il)
 else 0 end)*(select endeks from oyun.ulke where id=1)
 *coalesce((select carpan from oyun.makam_ucret_ayar where tur=p_tur),1)
$function$;

create or replace function oyun.yargic_maasi(u uuid)
 returns numeric language sql stable set search_path to '' as $function$
 select coalesce((select oyun.makam_maasi('yargic', null) from oyun.mahkeme_uye y
   where y.user_id = u and y.bos_since is null limit 1), 0)
$function$;
revoke all on function oyun.yargic_maasi(uuid) from public, anon, authenticated;

create or replace function oyun.gelir_hesap(u uuid, t timestamp with time zone)
 returns jsonb language plpgsql stable as $function$
declare p oyun.profiller; c oyun.cuzdan; ul oyun.ulke; st jsonb; ilc numeric; ub numeric; seri_y int; seri_b numeric;
        maas numeric; makam numeric; brut numeric; vergi numeric; kent numeric; gecim numeric; gecim_ind numeric; net numeric;
        saat numeric; v_hiz numeric := coalesce((select maas_hizi from oyun.ayarlar where id = 1), 1); bugun date := (t at time zone 'Europe/Istanbul')::date; destek numeric := 0; hem numeric := 0; asg_saat numeric; kv numeric;
begin
  select * into p from oyun.profiller where id = u;
  select * into c from oyun.cuzdan where user_id = u;
  select * into ul from oyun.ulke where id = 1;
  st := oyun.statu_json(u);
  ilc := oyun.il_carpan(p.il_id);
  ub := oyun.bonus(p.il_id, 'ucret', t) + case when (st ->> 'basamak')::int <= 1 then oyun.bonus(p.il_id, 'ucret_yeni', t) else 0 end;
  seri_y := case when c.seri_gun = bugun then c.seri when c.seri_gun = bugun - 1 then c.seri + 1
                when c.seri_gun is null then 1
                else greatest(1, coalesce(c.seri, 1) - (bugun - c.seri_gun - 1)) end;
  seri_b := least(oyun.duz('seri_tavan'), 5 * (seri_y - 1));
  asg_saat := ul.asgari / 720;
  maas := asg_saat * v_hiz * (st ->> 'carpan')::numeric * ilc * (1 + ub / 100);
  makam := (coalesce((select sum(oyun.makam_maasi(m.tur, m.il_id) * case when m.tur = 'mv' then 1 - oyun.vekil_kesinti_orani(u, t) / 100 else 1 end)
                     from oyun.makamlar m where m.user_id = u and m.bit is null), 0) + oyun.yargic_maasi(u)) / 720;
  brut := (maas + makam) * (1 + seri_b / 100);
  vergi := greatest(0, brut - asg_saat) * ul.vergi / 100;
  kv := (select kent_vergisi from oyun.il_durum where il_id = p.il_id);
  kent := brut * kv / 100;
  gecim_ind := least(60, oyun.bonus(p.il_id, 'gecim', t));
  gecim := 350.0 / 24 * ul.endeks * (1 - gecim_ind / 100);
  net := greatest(0, brut - vergi - kent - gecim);
  saat := least(oyun.kumbara_saat(), greatest(0, extract(epoch from (t - c.son_toplama)) / 3600));
  if c.seri_gun is distinct from bugun then
    destek := case when (st ->> 'basamak')::int <= 1 then ul.destek else 0 end;
    hem := (select hemsehri from oyun.il_durum where il_id = p.il_id);
  end if;
  return jsonb_build_object(
    'saat', round(saat, 3), 'dolu', saat >= oyun.kumbara_saat(), 'dolma_an', c.son_toplama + make_interval(hours => oyun.kumbara_saat()::int),
    'kapasite', oyun.kumbara_saat(), 'seri_tavan', oyun.duz('seri_tavan'),
    'vekil_kesinti', case when exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv' and bit is null) then oyun.vekil_kesinti_orani(u, t) end,
    'birikmis', round(net * saat), 'brut_birikmis', round(brut * saat), 'vergi_birikmis', round(vergi * saat),
    'saatlik', jsonb_build_object('maas', round(maas, 2), 'makam', round(makam, 2), 'brut', round(brut, 2), 'vergi', round(vergi, 2),
                                  'kent', round(kent, 2), 'gecim', round(gecim, 2), 'net', round(net, 2)),
    'gunluk_net', round(net * 24), 'asgari', ul.asgari, 'statu_carpan', (st ->> 'carpan')::numeric, 'il_carpan', ilc,
    'ucret_bonus', ub, 'seri', seri_y, 'seri_bonus', seri_b, 'vergi_oran', ul.vergi, 'kent_oran', kv, 'gecim_indirim', gecim_ind,
    'gecim_gunluk', round(350 * ul.endeks * (1 - gecim_ind / 100)),
    'gunluk_destek', jsonb_build_object('devlet', destek, 'belediye', hem),
    'reklam_odul', round(maas * 2));
end $function$;
commit;
