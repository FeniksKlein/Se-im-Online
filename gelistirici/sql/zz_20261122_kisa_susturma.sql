-- 22.11.2026 · Kısa süreli sohbet susturma (15 dk · 30 dk · 1 saat · 3 saat)
-- İstek (Ercan): sohbette ırkçı/hakaret içerikli yazılara karşı moderatörler kısa, caydırıcı susturma verebilsin.
-- Sunucu zaten saat cinsinden kesirli süreyi kabul ediyordu (yk_sustur p_saat numeric; 0.25 = 15 dk).
-- Bu modül yalnız gösterimi düzeltir: 1 saatten kısa süreler "0.3 saat" değil "15 dk" yazılır
-- (bildirim, kısıt kaydı, masa sınırı mesajları ve moderasyon günlüğü).
create or replace function oyun.mod_sure_yaz(s numeric)
returns text language sql immutable set search_path to '' as $f$
  select case when s is null then 'süresiz'
              when s < 1 then round(s * 60)::int::text || ' dk'
              when s < 48 then (case when s = trunc(s) then trunc(s)::text else round(s, 1)::text end) || ' saat'
              else (case when s / 24 = trunc(s / 24) then trunc(s / 24)::text else round(s / 24, 1)::text end) || ' gün' end
$f$;

-- Moderasyon günlüğünde "0.25 saat" yerine "15 dk"
select oyun._yama('public.yk_sustur(text,numeric,text)',
                  $d$case when bitis is not null then p_saat || ' saat' end$d$,
                  $d$case when bitis is not null then /* kisa_sure */ oyun.mod_sure_yaz(p_saat) end$d$,
                  '/* kisa_sure */', true);
