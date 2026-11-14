-- 2026-11-14 · Belediye bütçeleri absürt yükseliyordu
--
-- Kök neden: belediye kasası (oyun.il_durum.kasa) "milyar ₺" birimiyle tutulur.
-- Bazı işlemler oyuncunun ödediği ₺ tutarını milyara çevirmeden kasaya ekliyordu:
--   * şirketin belediye arsası alması (public.eko_emlak_islem)      → 201.600 ₺ arsa, kasaya 201.600 milyar
--   * oyuncunun belediyeden daire/dükkân/arsa alması (public.yatirim_pazar_islem)
--   * imza günü salon kirası (oyun.basin_kitap_tick, public.kitap_imza_islem)
-- Ayrıca tahvil tavanı kasaya bağlı olduğu için şişmiş kasa daha büyük tahvile izin veriyordu.
--
-- Bu dosya:
--   1. Dört fonksiyonda tutarı oyun.pazar_tl_milyar() ile milyara çevirir.
--   2. Tahvil tavanını il gelirine bağlar (kasa en çok 30 günlük gelir kadar tahvil açabilir).
--   3. il_durum'a koruma tetikleyicisi ekler: tek işlemde olağan dışı büyük kasa girişi kırpılır
--      ve belediye hareketlerine yazılır. Yönetim portalından elle yapılan kasa işlemi muaf.
--   4. Hatalı girişleri geri alır: yanlış eklenen ₺ tutarı düşülür, doğru (milyar) karşılığı eklenir.
-- Oyuncu cüzdanları, şirketler, mülkler ve tapular değişmez.

select oyun.yedek_al('belediye kasası birim düzeltmesi öncesi');

-- 1) Birim hatalarını düzelt -------------------------------------------------
do $$
declare
  d record; eski text; yeni text;
begin
  for d in select * from (values
    ('public.eko_emlak_islem(text,jsonb)'::regprocedure,
     'update oyun.il_durum set kasa=kasa+ar.fiyat where il_id=ar.il_id',
     'update oyun.il_durum set kasa=kasa+ar.fiyat/oyun.pazar_tl_milyar() where il_id=ar.il_id'),
    ('public.yatirim_pazar_islem(text,jsonb)'::regprocedure,
     'update oyun.il_durum set kasa=coalesce(kasa,0)+fiyat where il_id=il',
     'update oyun.il_durum set kasa=coalesce(kasa,0)+fiyat/oyun.pazar_tl_milyar() where il_id=il'),
    ('oyun.basin_kitap_tick()'::regprocedure,
     'update oyun.il_durum set kasa = kasa + ev.maliyet where il_id = ev.il_id',
     'update oyun.il_durum set kasa = kasa + ev.maliyet / oyun.pazar_tl_milyar() where il_id = ev.il_id'),
    ('oyun.basin_kitap_tick()'::regprocedure,
     'values (ev.il_id, ''kultur'', ev.maliyet, ',
     'values (ev.il_id, ''kultur'', ev.maliyet / oyun.pazar_tl_milyar(), '),
    ('public.kitap_imza_islem(text,bigint,jsonb)'::regprocedure,
     'update oyun.il_durum set kasa = kasa + (ev.maliyet - iade) where il_id = ev.il_id',
     'update oyun.il_durum set kasa = kasa + (ev.maliyet - iade) / oyun.pazar_tl_milyar() where il_id = ev.il_id'),
    ('public.kitap_imza_islem(text,bigint,jsonb)'::regprocedure,
     'values (ev.il_id, ''kultur'', ev.maliyet - iade, ',
     'values (ev.il_id, ''kultur'', (ev.maliyet - iade) / oyun.pazar_tl_milyar(), ')
  ) v(fn, eski_s, yeni_s) loop
    eski := pg_get_functiondef(d.fn);
    if position(d.yeni_s in eski) > 0 then continue; end if;          -- zaten düzeltilmiş
    if position(d.eski_s in eski) = 0 then
      raise exception 'Beklenen satır bulunamadı: % → %', d.fn, d.eski_s;
    end if;
    yeni := replace(eski, d.eski_s, d.yeni_s);
    execute yeni;
  end loop;
end $$;

-- 2) Tahvil tavanı il gelirine bağlı -----------------------------------------
create or replace function oyun.bel_tahvil_tavan(p_il smallint)
returns numeric language sql stable set search_path = '' as $$
  select round(least(
           greatest(1, coalesce((select kasa from oyun.il_durum where il_id = p_il), 0)),
           greatest(1, 30 * coalesce(oyun.il_gelir(p_il), 0))
         ) * oyun.pazar_tl_milyar())
$$;

-- 3) Koruma tetikleyicisi ----------------------------------------------------
create or replace function oyun.il_kasa_birim_koruma()
returns trigger language plpgsql set search_path = '' as $$
declare g numeric; tavan numeric; fazla numeric;
begin
  if new.kasa is null or old.kasa is null or new.kasa <= old.kasa then return new; end if;
  if coalesce(current_setting('oyun.bel_kasa_serbest', true), '') = 'evet' then return new; end if;
  g := coalesce(oyun.il_gelir(new.il_id), 0);
  -- Tek seferde en çok 150 günlük gelir (ya da 25 milyar ₺) girebilir.
  -- Kredi (20 gün) ve tahvil (30 gün) bu sınırın çok altında kalır.
  tavan := greatest(25, 150 * g);
  if new.kasa - old.kasa > tavan then
    fazla := new.kasa - old.kasa - tavan;
    new.kasa := old.kasa + tavan;
    insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
    values (new.il_id, 'birim_koruma', -fazla,
            'Olağan dışı büyük kasa girişi sınırlandı (hesap hatası koruması)', oyun.simdi());
  end if;
  return new;
end $$;

drop trigger if exists il_kasa_birim_koruma on oyun.il_durum;
create trigger il_kasa_birim_koruma before update of kasa on oyun.il_durum
  for each row execute function oyun.il_kasa_birim_koruma();

-- Yönetim portalından elle kasa işlemi korumaya takılmasın
do $$
declare eski text := pg_get_functiondef('oyun.yp_kasa_yaz(text,text,numeric,text)'::regprocedure);
begin
  if position('bel_kasa_serbest' in eski) = 0 then
    if position('elsif p_tur = ''il'' then' in eski) = 0 then raise exception 'yp_kasa_yaz beklenen biçimde değil'; end if;
    execute replace(eski, 'elsif p_tur = ''il'' then',
      'elsif p_tur = ''il'' then' || chr(10) || '    perform set_config(''oyun.bel_kasa_serbest'', ''evet'', true);');
  end if;
end $$;

-- 4) Hatalı girişleri geri al ------------------------------------------------
do $$
declare
  kur numeric := oyun.pazar_tl_milyar(); r record; once numeric; sonra numeric; taban numeric;
begin
  if exists (select 1 from oyun.belediye_sehir_hareket where tur = 'birim_duzeltme') then return; end if;
  for r in
    select il_id, sum(w) w from (
      select il_id, fiyat w from oyun.eko_arsalar where sahibi_sirket is not null or durum <> 'satilik'
      union all
      select il_id, bedel from oyun.yatirim_pazar_islem where kaynak = 'belediye'
      union all
      select il_id, tutar from oyun.belediye_sehir_hareket where tur = 'kultur' and tutar >= 1
    ) x group by il_id having sum(w) > 0
  loop
    select kasa into once from oyun.il_durum where il_id = r.il_id for update;
    taban := least(once, 5 * coalesce(oyun.il_gelir(r.il_id), 0));
    sonra := greatest(once - r.w + r.w / kur, taban, 0);
    update oyun.il_durum set kasa = sonra where il_id = r.il_id;
    insert into oyun.belediye_sehir_hareket(il_id, tur, tutar, aciklama, zaman)
    values (r.il_id, 'birim_duzeltme', sonra - once,
            'Hesap düzeltmesi: arsa/gayrimenkul/salon kirası gelirleri yanlış birimle eklenmişti (₺ → milyar ₺)', oyun.simdi());
  end loop;
  -- Kayıtlardaki salon kirası tutarlarını da milyar birimine çevir
  update oyun.belediye_sehir_hareket set tutar = tutar / kur where tur = 'kultur' and tutar >= 1;
end $$;
