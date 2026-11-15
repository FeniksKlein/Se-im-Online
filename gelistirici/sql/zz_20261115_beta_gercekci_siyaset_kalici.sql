-- 2026-11-15: gercekci siyaset hem mevcut beta hem de tum sonraki kurulumlarda acik.
-- Oyuncular, devam eden secimler ve diger oyun kayitlari korunur.
-- Bu dosya SQL birlestirme listesinin sonunda calismalidir.
alter table oyun.ayarlar alter column gercekci_siyaset set default true;
update oyun.ayarlar set gercekci_siyaset=true where id=1;
do $beta_kontrol$
begin
  if not exists (select 1 from oyun.ayarlar where id=1 and gercekci_siyaset)
  then raise exception 'Beta gercekci siyaset ayari acik olmali.';
  end if;
end $beta_kontrol$;
