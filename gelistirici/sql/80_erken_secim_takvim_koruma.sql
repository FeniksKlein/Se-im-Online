-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 80) ERKEN SEÇİM TAKVİM KORUMASI
--  Hata (11.10.2026): TBMM erken seçim kararı, iki gün sonra yapılacak olağan genel seçimi
--  iptal edip yerine bir gün SONRA yeni seçim kuruyordu; verilmiş aday adaylığı ve CB adaylığı
--  başvuruları boşa gidiyor, ekranda olmamış seçimler "Sonuçlandı" görünüyordu.
--  Kural: olağan genel seçim, erken seçimin yapılacağı günden en geç 7 gün sonra ise takvim
--  değişmez; karar alınır ama mevcut seçim aynen yapılır (başvurular korunur). Erken seçim hiçbir
--  zaman seçimi ileri atmaz.
-- =====================================================================
create or replace function oyun.erken_genel_secim_olustur(t timestamptz, p_teklif bigint) returns text
language plpgsql set search_path to '' as $$
declare ilk date; ongun date; secgun date; dm text; eski text; eski_oy timestamptz;
begin
  ilk:=(t at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(ilk,8)<t+interval '8 hours' then ilk:=ilk+1; end if;
  ongun:=ilk; secgun:=ilk+1;
  dm:='erken-genel-'||p_teklif||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
  select donem, oy_bas into eski, eski_oy from oyun.secimler
   where tur='mv' and not ara and durum='bekliyor' and oy_bas>t order by oy_bas limit 1;
  -- Olağan seçim zaten yakın: takvimi bozma
  if eski is not null and eski_oy <= oyun.tr_an(secgun,8) + interval '7 days' then
    perform oyun.olay('secim',format('TBMM erken seçim kararı aldı. Genel seçim zaten %s günü yapılacağı için takvim değişmedi; başvurular geçerli.',
                      to_char(eski_oy at time zone 'Europe/Istanbul','DD.MM.YYYY')),null,null,t);
    return eski;
  end if;
  if eski is not null then
    update oyun.secimler set durum='tamam',sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','erken_secim')
    where donem=eski and durum='bekliyor' and tur in ('mv_on','mv','cb_on','cb','cb2');
  end if;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
   ('mv_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
   ('mv',dm,null,null,oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  if oyun.hukumet_sistemi()=0 then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
     ('cb_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
     ('cb',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  end if;
  perform oyun.olay('secim',format('TBMM erken seçim kararı aldı. Erken genel seçim %s günü yapılacak.',to_char(secgun,'DD.MM.YYYY')),null,null,t);
  return dm;
end $$;
