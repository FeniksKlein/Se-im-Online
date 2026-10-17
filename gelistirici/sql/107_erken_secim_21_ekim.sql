-- 17-19 Ekim 2026 arasında kabul edilen erken genel seçim kararı için
-- özel takvim: ön seçim 20 Ekim Salı, genel/CB seçimi 21 Ekim Çarşamba.
-- Seçim kendiliğinden ilan edilmez; yalnız kabul edilmiş Meclis kararı
-- veya görevdeki Cumhurbaşkanının kararından sonra bu fonksiyon çalışır.
-- 20 Ekim 08.00 ön seçimine 8 saatten az kaldığında geçmişe tarih atılmaz;
-- mevcut en erken uygulanabilir tarihe dönülür.
create or replace function oyun.erken_genel_secim_olustur(t timestamptz,p_teklif bigint) returns text
language plpgsql set search_path='' as $$
declare
  ilk date; ongun date; secgun date; dm text; eski text; eski_oy timestamptz;
  karar_sahibi text := case when p_teklif < 0 then 'Cumhurbaşkanı' else 'TBMM' end;
begin
  ilk:=(t at time zone 'Europe/Istanbul')::date;
  if ilk between date '2026-10-17' and date '2026-10-19'
     and t+interval '8 hours'<=oyun.tr_an(date '2026-10-20',8) then
    ongun:=date '2026-10-20';
    secgun:=date '2026-10-21';
  else
    if oyun.tr_an(ilk,8)<t+interval '8 hours' then ilk:=ilk+1; end if;
    ongun:=ilk;
    secgun:=ilk+1;
  end if;
  dm:='erken-genel-'||p_teklif||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
  select donem,oy_bas into eski,eski_oy from oyun.secimler
  where tur='mv' and not ara and durum='bekliyor' and oy_bas>t order by oy_bas limit 1;

  -- Yakın olağan seçim öne alınmıyor veya ertelenmiyor; adaylıklar korunur.
  if eski is not null and eski_oy<=oyun.tr_an(secgun,8)+interval '7 days' then
    perform oyun.olay('secim',format('%s erken seçim kararı aldı. Genel seçim zaten %s günü yapılacağı için takvim değişmedi; başvurular geçerli.',
      karar_sahibi,to_char(eski_oy at time zone 'Europe/Istanbul','DD.MM.YYYY')),null,null,t);
    return eski;
  end if;
  if eski is not null then
    update oyun.secimler set durum='tamam',
      sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','erken_secim')
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
  perform oyun.olay('secim',format('%s erken seçim kararı aldı. Erken genel seçim %s günü yapılacak.',
    karar_sahibi,to_char(secgun,'DD.MM.YYYY')),null,null,t);
  return dm;
end $$;
