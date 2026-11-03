-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 162) İPTAL EDİLEN SEÇİMLER TAKVİMDE GÖRÜNMESİN
--  Sorun (03.11.2026): 23 Ekim erken seçimi, 1 Aralık olağan genel/CB seçimini ve ön
--  seçimlerini iptal etti (durum='tamam', sonuc.iptal='erken_secim'). Bu kayıtların sonuç
--  saati hâlâ ilerideydi; Gündem "son 36 saatte sonuçlanan" süzgeci gelecekteki saati de
--  kabul ettiği için iptal edilen seçimler "Sonuçlandı" kartı olarak görünüyordu. 6 Kasım
--  Cuma seçim takvimi açılınca ikisi yan yana çıkıyordu.
--  Çözüm: durum() takviminden sonuc.iptal işaretli seçimler çıkarılır. Gövdenin geri kalanı
--  aynen kalır; iki kez çalışabilir. Oyuncu verisine dokunmaz.
-- =====================================================================
do $yama$
declare d text; y text;
begin
  if to_regprocedure('public.durum()') is null then return; end if;
  d := pg_get_functiondef('public.durum()'::regprocedure); y := d;
  if position('s.sonuc ? ''iptal''' in y) = 0 then
    y := regexp_replace(y,
          '(and coalesce\(s\.basvuru_bas,\s*s\.oy_bas\)\s*<=\s*t \+ interval ''40 days'')',
          E'\\1\n        and not coalesce(s.sonuc ? ''iptal'', false)', '');
    if position('s.sonuc ? ''iptal''' in y) = 0 then
      raise notice 'durum() iptal yaması uygulanamadı: beklenen satır bulunamadı';
    end if;
  end if;
  if y <> d then execute y; end if;
end $yama$;
