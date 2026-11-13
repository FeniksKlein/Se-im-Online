-- 2026.11.13-8 · KALICI KURAL (Ercan): Cumhurbaşkanı adayı olan milletvekili adayı olamaz — herkes için
-- (eskiden yalnız genel başkanlara uygulanıyordu ve CB ön seçimi (cb_on) hiç denetlenmiyordu).
--  • MV aday adaylığı (mv_on): aynı dönemde CB aday adaylığı/adaylığı varsa reddedilir.
--  • CB aday adaylığı (cb_on): aynı dönemde MV aday adaylığı/adaylığı varsa reddedilir.
--  • Bağımsız MV adaylığı (mv, mv_on kaydı olmadan): CB aday adayı/adayı ise reddedilir.
--  • GB'nin CB adayı belirlemesi / ittifak ortak adayı (cb): kişinin MV ön seçimi henüz oylamaya
--    girmemişse reddedilir; girmişse CB adaylığı öncelikli olur, MV adaylığı (mv) düşer ve bildirim gider.
--  • Ön seçim aktarımı: CB ön seçimini kazanan kişi MV listesine alınmaz / alınmışsa çıkarılır.
--  • 2. tur (cb2) ilk turun devamıdır, yeni başvuru sayılmaz.
-- Yalnız tetikleyici fonksiyonu değişir; mevcut adaylıklara dokunulmaz.
create or replace function oyun.gb_mv_cb_adaylik_kontrol()
returns trigger language plpgsql set search_path to '' as $fn$
declare v_tur text; v_donem text; v_oy_bas timestamptz; t timestamptz := oyun.simdi();
 v_mvon boolean; v_cb boolean; v_cbon boolean; v_mv_bas timestamptz; n int;
begin
 select s.tur,s.donem,s.oy_bas into v_tur,v_donem,v_oy_bas from oyun.secimler s where s.id=new.secim_id;
 if v_tur is null or v_tur not in ('mv_on','mv','cb_on','cb','cb2') then return new; end if;
 if tg_op='UPDATE' and new.secim_id=old.secim_id and new.user_id=old.user_id then return new; end if;
 if v_tur='cb2' and exists(select 1 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
    where a.user_id=new.user_id and s.donem=v_donem and s.tur='cb') then return new; end if;
 perform 1 from oyun.profiller pr where pr.id=new.user_id for update;

 select bool_or(s.tur='mv_on'), bool_or(s.tur in ('cb','cb2')), bool_or(s.tur='cb_on'),
        min(s.oy_bas) filter (where s.tur='mv_on')
   into v_mvon, v_cb, v_cbon, v_mv_bas
 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
 where a.user_id=new.user_id and s.donem=v_donem and (tg_op='INSERT' or a.id<>new.id);
 v_mvon:=coalesce(v_mvon,false); v_cb:=coalesce(v_cb,false); v_cbon:=coalesce(v_cbon,false);

 if v_tur='mv_on' and (v_cb or v_cbon) then
  raise exception 'Cumhurbaşkanı adayı ya da aday adayı olan oyuncu milletvekili adayı olamaz. Önce Cumhurbaşkanlığı adaylığını geri çekmelisin.';
 end if;
 if v_tur='cb_on' and (v_mvon or exists(select 1 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
     where a.user_id=new.user_id and s.donem=v_donem and s.tur='mv')) then
  raise exception 'Milletvekili adaylığın varken Cumhurbaşkanı aday adayı olamazsın. Önce milletvekili adaylığını geri çekmelisin.';
 end if;
 if v_tur='mv' then
  if not v_mvon and (v_cb or v_cbon) then
   raise exception 'Cumhurbaşkanı adayı ya da aday adayı olan oyuncu milletvekili adayı olamaz.';
  end if;
  if v_cb then  -- ön seçim aktarımı: CB adayı MV listesine alınmaz
   perform oyun.bildir(new.user_id,'Cumhurbaşkanı adayı olduğun için milletvekili listesine alınmadın (kural: CB adayı aynı seçimde milletvekili adayı olamaz).',t);
   return null;
  end if;
 end if;
 if v_tur in ('cb','cb2') then
  if v_mvon and v_mv_bas is not null and t < v_mv_bas then
   raise exception 'Bu oyuncunun milletvekili aday adaylığı var. Cumhurbaşkanı adayı olabilmesi için önce milletvekili adaylığını geri çekmeli.';
  end if;
  delete from oyun.adaylar a using oyun.secimler s
   where s.id=a.secim_id and s.donem=v_donem and s.tur='mv' and a.user_id=new.user_id;
  get diagnostics n = row_count;
  if n>0 then
   perform oyun.bildir(new.user_id,'Cumhurbaşkanı adayı oldun. Kural gereği aynı seçimde milletvekili adayı olamayacağın için milletvekili adaylığın düştü.',t);
  end if;
 end if;
 return new;
end $fn$;
