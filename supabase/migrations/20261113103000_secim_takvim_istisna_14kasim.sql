-- ═══════════════════════════════════════════════════════════════════════════
-- SEÇİM TAKVİMİ İSTİSNASI (13.11.2026) — canlı adı secim_takvim_istisna_14kasim_20261113
-- Üç aşama kuralı (20261113100000_secim_uc_asama_kurali.sql) kalıcıdır; Ercan aksini
-- demedikçe bütün seçimlerde uygulanır. Ercan'ın onayladığı tek seferlik istisnalar
-- oyun.secim_takvim_istisna tablosunda kayıtlıdır; o dönemlere düzeltici dokunmaz.
-- 14 Kasım: adaylık 13 Kasım 15.00'e kadar, ön seçim 15.00–22.00 (adaylar 22.00'de belli),
-- genel seçim ve CB seçimi 14 Kasım 08.00–22.00, göreve başlama 15 Kasım 00.00.
-- Sıra yine korunur: önce adaylık, sonra ön seçim, sonra seçim.
-- ═══════════════════════════════════════════════════════════════════════════
create table if not exists oyun.secim_takvim_istisna(
 donem text primary key,
 neden text not null,
 onaylayan text not null,
 zaman timestamptz not null default now()
);
alter table oyun.secim_takvim_istisna enable row level security;
revoke all on oyun.secim_takvim_istisna from public, anon, authenticated;

select oyun.sokak_yama_uygula('oyun.secim_takvim_duzelt(text)'::regprocedure,
 $a$ if p_donem is null then return 0; end if;$a$,
 $b$ if p_donem is null then return 0; end if;
 if exists (select 1 from oyun.secim_takvim_istisna i where i.donem = p_donem) then return 0; end if; -- yönetici onaylı istisna$b$);

select oyun.sokak_yama_uygula('oyun.yp_takvim_engel(oyun.secimler)'::regprocedure,
 $a$  if s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.tur in ('mv_on','cb_on','bel_on','kurultay')$a$,
 $b$  if s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.tur in ('mv_on','cb_on','bel_on','kurultay')
     and not exists (select 1 from oyun.secim_takvim_istisna i where i.donem = s.donem)$b$);

do $once$
declare t timestamptz := oyun.simdi(); d text := 'erken-genel-14kasim2026'; n integer; metin text;
begin
 if exists (select 1 from oyun.secim_takvim_istisna where donem = d) then raise notice 'İstisna zaten uygulanmış'; return; end if;
 if t >= timestamptz '2026-11-13 15:00+03' then raise exception 'Saat 15.00 geçti; istisna uygulanamaz'; end if;
 insert into oyun.secim_takvim_istisna(donem,neden,onaylayan,zaman)
 values(d,'14 Kasım seçimi: adaylık 13 Kasım 15.00''e kadar, ön seçim 15.00–22.00, adaylar 22.00''de belli, seçim 14 Kasım','Ercan (oyun sahibi)',t);
 perform set_config('oyun.takvim_kurali', '1', true);
 update oyun.secimler set basvuru_bit = timestamptz '2026-11-13 15:00+03', oy_bas = timestamptz '2026-11-13 15:00+03',
   oy_bit = timestamptz '2026-11-13 22:00+03', sonuc_at = timestamptz '2026-11-13 22:00+03', hatirlatma = '{}'::jsonb
 where donem = d and tur in ('mv_on','cb_on') and durum = 'bekliyor';
 update oyun.secimler set oy_bas = timestamptz '2026-11-14 08:00+03', oy_bit = timestamptz '2026-11-14 22:00+03',
   sonuc_at = timestamptz '2026-11-14 22:30+03', goreve_bas = timestamptz '2026-11-15 00:00+03', hatirlatma = '{}'::jsonb,
   basvuru_bit = case when basvuru_bit is not null then timestamptz '2026-11-13 15:00+03' end
 where donem = d and tur in ('mv','cb') and durum = 'bekliyor';
 perform set_config('oyun.takvim_kurali', '', true);
 metin := 'Resmî duyuru · 14 Kasım seçim takvimi kesinleşti. Milletvekili ve Cumhurbaşkanı aday adaylığı, bağımsız adaylık ve '
   || 'parti Cumhurbaşkanı adayı kararları bugün (13 Kasım) saat 15.00''e kadar açık. Ön seçimler bugün 15.00–22.00; adaylar 22.00''de belli olur. '
   || 'Genel seçim ve Cumhurbaşkanlığı seçimi yarın, 14 Kasım Cumartesi 08.00–22.00. Sonuçlar 22.30''da açıklanır.';
 perform oyun.olay('secim', 'Seçim takvimi kesinleşti: adaylık bugün 15.00''e kadar, ön seçim 15.00–22.00, genel ve Cumhurbaşkanlığı seçimi yarın 14 Kasım.', null, null, t);
 n := oyun.yp_bildir_herkese(metin, t);
 perform oyun.gazete_ekle('duyuru', 'Seçim yarın: adaylık bugün 15.00''e kadar', metin, null, t);
end $once$;
