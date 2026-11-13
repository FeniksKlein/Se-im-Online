-- ═══════════════════════════════════════════════════════════════════════════
-- SEÇİM ÜÇ AŞAMA KURALI (13.11.2026) — değişmez kural
--   1) Önce adaylık süreci (başvuru en az 24 saat açık; Süper Yönetici artırabilir, azaltamaz)
--   2) Sonra aday ön seçimi (ön seçim oylaması adaylık kapanmadan açılmaz)
--   3) En son normal seçim (ön seçim sonucu açıklanmadan seçim sandığı açılmaz)
-- Kapsam: milletvekili, cumhurbaşkanlığı ve belediye seçimleri (olağan, ara, erken,
-- Yönetim Portalı). Kurultay tek aşamalıdır (partinin kendi seçimi); onda da adaylık
-- en az 24 saat ve oylamadan önce. CB 2. tur (cb2) ilk turun devamıdır, kapsam dışı.
--
-- Nasıl korunur:
--   · oyun.secim_takvim_duzelt(donem): dönemin takvimini kurala göre düzeltir
--     (kısa başvuruyu uzatır, ön seçimi ve seçimi gerekirse ileri iter, eksik ön
--     seçimi kurar). Oylaması başlamış seçime dokunmaz.
--   · secimler tablosunda AFTER INSERT/UPDATE tetikleyicisi her yeni ya da değişen
--     takvimde bu düzeltmeyi çalıştırır — hangi fonksiyon seçim kurarsa kursun.
--   · Seçim kuran fonksiyonlar (erken seçim, ara seçim, Yönetim Portalı) ilk günden
--     doğru takvim üretir; duyuru metinleri gerçek tarihle çıkar.
--   · 14 Kasım erken seçimi (adaylık gece 00.01–08.00 arası 8 saat açılmıştı) bir gün
--     ileri alındı: adaylık 14 Kasım 08.00'e kadar, ön seçim 14 Kasım, seçim 15 Kasım.
-- Yedek: yedek_20261113_084724_338177. Tekrar çalıştırmaya güvenlidir.
-- ═══════════════════════════════════════════════════════════════════════════

insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira,guncelleme)
values('secim_min_basvuru_saat',24,'saat','kural','Seçim adaylık süresi (en az)',
 'Her seçimde adaylık başvurusu en az bu kadar saat açık kalır; ön seçim ve seçim ondan sonra yapılır. 24''ün altına inmez.',900,now())
on conflict (kod) do nothing;

create or replace function oyun.secim_min_basvuru() returns interval
language sql stable set search_path to '' as $$
 select make_interval(hours => greatest(24, coalesce((select deger from oyun.tarife where kod='secim_min_basvuru_saat'),24))::int)
$$;

-- Adaylık t anında açılırsa ilk oylama (ön seçim) hangi gün 08.00'de yapılabilir?
create or replace function oyun.secim_ilk_oy_gunu(p timestamptz) returns date
language plpgsql stable set search_path to '' as $$
declare h timestamptz := p + oyun.secim_min_basvuru(); d date := (h at time zone 'Europe/Istanbul')::date;
begin
 if oyun.tr_an(d,8) < h then d := d + 1; end if;
 return d;
end $$;

create or replace function oyun.secim_takvim_duzelt(p_donem text) returns integer
language plpgsql security definer set search_path to '' as $$
declare
 t timestamptz := oyun.simdi(); mn interval := oyun.secim_min_basvuru();
 eski_bayrak text := coalesce(current_setting('oyun.takvim_kurali', true), '');
 r oyun.secimler; n integer := 0; aile record; on_son timestamptz; gerek timestamptz; ilk_ana timestamptz;
 yeni_bit timestamptz; fark interval; gd date; o_bit timestamptz; ozet text[] := '{}';
begin
 if p_donem is null then return 0; end if;
 perform set_config('oyun.takvim_kurali', '1', true);

 -- 0) Ön seçimi olmayan seçim olmaz: eksikse kur (oylaması başlamamış seçimler için).
 for r in select * from oyun.secimler s where s.donem = p_donem and s.durum = 'bekliyor' and s.tur in ('mv','cb','bel')
          and s.oy_bas > t and not coalesce(s.sonuc ? 'iptal', false)
          and not exists (select 1 from oyun.secimler o where o.donem = s.donem and o.tur = s.tur || '_on') loop
  gd := oyun.secim_ilk_oy_gunu(t);
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden,hedef_parti_id,hedef_il_id)
  values(r.tur||'_on', r.donem, t, oyun.tr_an(gd,8), oyun.tr_an(gd,8), oyun.tr_an(gd,22), oyun.tr_an(gd,22,30), null,
         r.ara, r.ara_neden, r.hedef_parti_id, r.hedef_il_id)
  on conflict do nothing;
  n := n + 1; ozet := ozet || (oyun.yp_tur_ad(r.tur||'_on') || ' eklendi');
 end loop;

 -- 1) Önce adaylık: başvurulu her seçimde başvuru en az mn açık ve oylamadan önce kapanır.
 for r in select * from oyun.secimler s where s.donem = p_donem and s.durum = 'bekliyor'
          and s.tur in ('mv_on','cb_on','bel_on','kurultay') and s.oy_bas > t and not coalesce(s.sonuc ? 'iptal', false)
          order by s.id for update loop
  r.basvuru_bas := coalesce(r.basvuru_bas, t);
  if r.basvuru_bit is null or r.basvuru_bit - r.basvuru_bas < mn or r.basvuru_bit > r.oy_bas then
   yeni_bit := greatest(coalesce(r.basvuru_bit, r.basvuru_bas), oyun.tr_an(oyun.secim_ilk_oy_gunu(r.basvuru_bas),8));
   fark := greatest(yeni_bit - r.oy_bas, interval '0');
   update oyun.secimler set basvuru_bas = r.basvuru_bas, basvuru_bit = yeni_bit,
     oy_bas = oy_bas + fark, oy_bit = oy_bit + fark, sonuc_at = sonuc_at + fark, goreve_bas = goreve_bas + fark
   where id = r.id;
   n := n + 1; ozet := ozet || (oyun.yp_tur_ad(r.tur) || ': adaylık ' || oyun.tr_tarih_saat(yeni_bit) || '''e kadar');
  end if;
 end loop;

 -- 2) Sonra ön seçim, en son seçim: seçimin sandığı ön seçim sonucundan sonraki ilk 08.00'den önce açılmaz.
 for aile in select * from (values (array['mv_on','cb_on'], array['mv','cb']), (array['bel_on'], array['bel'])) v(onlar, analar) loop
  select max(greatest(o.oy_bit, coalesce(o.sonuc_at, o.oy_bit))), max(o.basvuru_bit) into on_son, o_bit
    from oyun.secimler o where o.donem = p_donem and o.tur = any(aile.onlar) and not coalesce(o.sonuc ? 'iptal', false);
  continue when on_son is null;
  gd := (on_son at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(gd,8) <= on_son then gd := gd + 1; end if;
  gerek := oyun.tr_an(gd,8);
  select min(a.oy_bas) into ilk_ana from oyun.secimler a where a.donem = p_donem and a.tur = any(aile.analar)
    and a.durum = 'bekliyor' and a.oy_bas > t and not coalesce(a.sonuc ? 'iptal', false);
  if ilk_ana is not null and ilk_ana < gerek then
   update oyun.secimler set oy_bit = oy_bit + (gerek - oy_bas), sonuc_at = sonuc_at + (gerek - oy_bas),
     goreve_bas = goreve_bas + (gerek - oy_bas), oy_bas = gerek
   where donem = p_donem and tur = any(aile.analar) and durum = 'bekliyor' and oy_bas > t and oy_bas < gerek
     and not coalesce(sonuc ? 'iptal', false);
   n := n + 1; ozet := ozet || ('seçim günü ' || to_char(gd,'DD.MM.YYYY'));
  end if;
  -- bağımsız (CB) başvurusu da en az mn açık kalır ve sandıktan önce kapanır
  update oyun.secimler set basvuru_bit = least(oy_bas, greatest(basvuru_bit, o_bit, oyun.tr_an(oyun.secim_ilk_oy_gunu(basvuru_bas),8)))
  where donem = p_donem and tur = any(aile.analar) and durum = 'bekliyor' and oy_bas > t and basvuru_bas is not null
    and (basvuru_bit - basvuru_bas < mn or basvuru_bit > oy_bas) and not coalesce(sonuc ? 'iptal', false);
  if found then n := n + 1; end if;
 end loop;

 if n > 0 then
  perform oyun.olay('secim', 'Seçim takvimi "önce adaylık, sonra aday ön seçimi, sonra seçim" kuralına göre düzenlendi'
    || case when cardinality(ozet) > 0 then ': ' || array_to_string(ozet, ' · ') else '' end || '.', null, null, t);
 end if;
 perform set_config('oyun.takvim_kurali', eski_bayrak, true);
 return n;
end $$;

create or replace function oyun.secim_takvim_kurali_tg() returns trigger
language plpgsql security definer set search_path to '' as $$
begin
 if coalesce(current_setting('oyun.takvim_kurali', true), '') = '1' then return null; end if;
 if new.durum <> 'bekliyor' or new.tur not in ('mv_on','mv','cb_on','cb','bel_on','bel','kurultay') then return null; end if;
 perform oyun.secim_takvim_duzelt(new.donem);
 return null;
end $$;

drop trigger if exists secim_takvim_kurali on oyun.secimler;
create trigger secim_takvim_kurali after insert or update of basvuru_bas, basvuru_bit, oy_bas, oy_bit on oyun.secimler
 for each row execute function oyun.secim_takvim_kurali_tg();

revoke all on function oyun.secim_takvim_duzelt(text), oyun.secim_takvim_kurali_tg() from public, anon, authenticated;

-- ---------- Seçim kuran fonksiyonlar ilk günden doğru takvim üretsin ----------
select oyun.sokak_yama_uygula('oyun.erken_genel_secim_olustur(timestamptz,bigint)'::regprocedure,
 $a$    if oyun.tr_an(ilk,8)<t+interval '8 hours' then ilk:=ilk+1; end if;$a$,
 $b$    ilk:=oyun.secim_ilk_oy_gunu(t); -- önce adaylık (en az 24 saat), sonra ön seçim, sonra seçim$b$);

select oyun.sokak_yama_uygula('oyun.ara_secim_olustur(text,bigint,smallint,timestamptz)'::regprocedure,
 $a$  ilk_gun := (t at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(ilk_gun, 8) < t + interval '8 hours' then
    ilk_gun := ilk_gun + 1;
  end if;$a$,
 $b$  ilk_gun := oyun.secim_ilk_oy_gunu(t); -- önce adaylık (en az 24 saat), sonra ön seçim, sonra seçim$b$);

select oyun.sokak_yama_uygula('oyun.yp_on_genel_secim_olustur(jsonb)'::regprocedure,
 $a$elsif oyun.tr_an(ongun, 8) < t + interval '1 hour' then e := 'Ön seçim en az 1 saat sonra, saat 08.00''de başlamalı.';$a$,
 $b$elsif oyun.tr_an(ongun, 8) < t + oyun.secim_min_basvuru() then e := format('Önce adaylık: adaylık en az %s saat açık kalmalı. Ön seçim en erken %s 08.00''de olabilir.', extract(epoch from oyun.secim_min_basvuru())::int/3600, to_char(oyun.secim_ilk_oy_gunu(t),'DD.MM.YYYY'));$b$);

select oyun.sokak_yama_uygula('oyun.yp_takvim_engel(oyun.secimler)'::regprocedure,
 $a$  onceki := case s.tur when 'mv' then 'mv_on'$a$,
 $b$  if s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.tur in ('mv_on','cb_on','bel_on','kurultay')
     and (s.basvuru_bas is null or s.basvuru_bit - s.basvuru_bas < oyun.secim_min_basvuru()) then
    return format('Önce adaylık: başvuru en az %s saat açık kalmalı.', extract(epoch from oyun.secim_min_basvuru())::int/3600); end if;
  if s.durum = 'bekliyor' and not coalesce(s.sonuc ? 'iptal', false) and s.tur in ('mv','cb','bel')
     and not exists (select 1 from oyun.secimler o where o.donem = s.donem and o.tur = s.tur || '_on') then
    return 'Önce aday ön seçimi: bu seçimin ön seçimi yok.'; end if;
  onceki := case s.tur when 'mv' then 'mv_on'$b$);

-- ---------- 14 Kasım erken seçimi: adaylık gece 8 saat açılmıştı → bir gün ileri ----------
do $once$
declare t timestamptz := oyun.simdi(); d text := 'erken-genel-14kasim2026'; n integer; metin text;
begin
 if not exists (select 1 from oyun.secimler where donem = d and tur = 'mv_on' and durum = 'bekliyor'
                and basvuru_bit = timestamptz '2026-11-13 08:00+03') then
  raise notice '14 Kasım seçimi zaten düzeltilmiş ya da sonuçlanmış; dokunulmadı'; return;
 end if;
 if t >= timestamptz '2026-11-13 22:00+03' then raise exception 'Ön seçim saati geçti; elle karar gerekir'; end if;
 perform set_config('oyun.takvim_kurali', '1', true);
 update oyun.secimler set basvuru_bit = timestamptz '2026-11-14 08:00+03', oy_bas = timestamptz '2026-11-14 08:00+03',
   oy_bit = timestamptz '2026-11-14 22:00+03', sonuc_at = timestamptz '2026-11-14 22:30+03', hatirlatma = '{}'::jsonb
 where donem = d and tur in ('mv_on','cb_on') and durum = 'bekliyor';
 update oyun.secimler set oy_bas = timestamptz '2026-11-15 08:00+03', oy_bit = timestamptz '2026-11-15 22:00+03',
   sonuc_at = timestamptz '2026-11-15 22:30+03', goreve_bas = timestamptz '2026-11-16 00:00+03', hatirlatma = '{}'::jsonb,
   basvuru_bit = case when basvuru_bit is not null then timestamptz '2026-11-14 08:00+03' end
 where donem = d and tur in ('mv','cb') and durum = 'bekliyor';
 perform set_config('oyun.takvim_kurali', '', true);
 metin := 'Resmî duyuru · Seçim takvimi düzeltildi. Kural artık değişmez: önce adaylık, sonra aday ön seçimi, sonra seçim. '
   || 'Adaylık başvuruları gece yalnız 8 saat açık kaldığı için uzatıldı: milletvekili ve Cumhurbaşkanı aday adaylığı, bağımsız adaylık '
   || 've parti Cumhurbaşkanı adayı kararları 14 Kasım Cumartesi 08.00''e kadar açık. Ön seçimler 14 Kasım 08.00–22.00, '
   || 'genel seçim 15 Kasım Pazar 08.00–22.00. Yapılmış başvurular ve kullanılmış oylar geçerli.';
 perform oyun.olay('secim', 'Seçim takvimi düzeltildi: adaylık 14 Kasım 08.00''e kadar, ön seçim 14 Kasım, genel seçim 15 Kasım Pazar.', null, null, t);
 n := oyun.yp_bildir_herkese(metin, t);
 perform oyun.gazete_ekle('duyuru', 'Seçim 15 Kasım Pazar: adaylık uzatıldı', metin, null, t);
 raise notice 'Bildirim: % oyuncu', n;
end $once$;
