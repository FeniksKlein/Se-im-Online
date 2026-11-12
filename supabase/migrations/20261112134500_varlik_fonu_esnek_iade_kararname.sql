-- 12.11.2026: Varlik Fonu iadelerini beklemesiz, cekimleri 6 saat aralikli yap.
-- Mevcut verileri ve finansal hareketleri degistirmez; yalnizca kural ve kotalari gunceller.
do $patch$
declare
  f text;
  eski_sure text := $old$  if exists (select 1 from oyun.varlik_fonu_hareket h where h.tur in ('cek', 'yatir') and h.zaman > t - interval '24 hours') then
    raise exception 'Varlık Fonu aktarımı 24 saatte bir yapılabilir.';
  end if;$old$;
  yeni_sure text := $new$  -- Fon'a geri yatirim beklemesizdir; yalnizca fon'dan cekimde bekleme vardir.
  if p_yon = 'cek' and exists (select 1 from oyun.varlik_fonu_hareket h where h.tur = 'cek' and h.zaman > t - interval '6 hours') then
    raise exception 'Varlık Fonu''ndan çekim 6 saatte bir yapılabilir. Hazine''den fona iade/yatırım için bekleme yoktur.';
  end if;$new$;
  eski_min text := $old$  if x < 1 then raise exception 'Tutar en az 1 milyar ₺ olmalı.'; end if;$old$;
  yeni_min text := $new$  if x < 0.1 then raise exception 'Tutar en az 0,1 milyar ₺ (100 milyon ₺) olmalı.'; end if;$new$;
begin
  f := pg_get_functiondef('public.varlik_fonu_aktar(text,numeric,text)'::regprocedure);
  if position(eski_sure in f) > 0 then
    f := replace(f, eski_sure, yeni_sure);
  elsif position('interval ''6 hours''' in f) = 0 then
    raise exception 'Varlik Fonu sure siniri beklenenden farkli; elle inceleyin';
  end if;
  if position(eski_min in f) > 0 then
    f := replace(f, eski_min, yeni_min);
  elsif position('if x < 0.1' in f) = 0 then
    raise exception 'Varlik Fonu asgari islem kuralini inceleyin';
  end if;
  execute f;
  update oyun.varlik_fonu set aktarim_tavan = 200, aktarim_gun = 7 where id = 1;
  update oyun.anayasa set deger=10, max=15,
    aciklama='Cumhurbaşkanı günde en fazla bu kadar kararname çıkarabilir. 0 olursa kararname yetkisi kalkar. Anayasal aralık 0–15 kararnamedir.'
    where kod='kararname_sinir' and deger < 10;
end
$patch$;