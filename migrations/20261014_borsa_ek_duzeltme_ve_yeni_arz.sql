-- 2026-10-14 borsa ek onarım: 14:16–14:20 UTC'de CELAL -> mehmetemincelik
-- Özel Anadolu Hastanesi üzerinde peş peşe 5 adet %0,10 düşük fiyatlı işleme devam etti.
-- Korumaya girmeden hemen önceki bağımsız işlem fiyatı 4.616 TL (%1 pay).
begin;
insert into oyun.borsa_supheli_islem(islem_id,sirket_id,bulgu)
select id,sirket_id,
  '14.10.2026 14:16-14:20 UTC: tek aynı alıcıya ardışık %0,10 satış, her işlemde %20 düşüş'
from oyun.borsa_islem
where sirket_id=13 and id between 22 and 26
on conflict (islem_id) do nothing;

update oyun.borsa_fiyat_referans
set fiyat=4616,ilk_fiyat=4616,son_fiyat_guncelleme=now(),
    gerekce='14 Ekim zincirleme %0,10 yapay düşüşleri hariç; son bağımsız işlem (13 Ekim, işlem 9) 4.616 ₺'
where sirket_id=13 and ilk_fiyat=1512 and fiyat=1512;

insert into oyun.borsa_fiyat_gecmis(sirket_id,fiyat,gerekce)
select 13,4616,'Şüpheli ardışık mini işlemler dışlanarak 13 Ekim işlem 9 fiyatına geri dönüş'
where exists (select 1 from oyun.borsa_fiyat_referans where sirket_id=13 and fiyat=4616)
  and not exists (select 1 from oyun.borsa_fiyat_gecmis where sirket_id=13 and fiyat=4616);

-- Gelecekte tamamlanacak halka arzlar da fiyat tescil sistemine otomatik girsin.
create or replace function oyun.tg_borsa_yeni_sirket_fiyat()
returns trigger language plpgsql security definer set search_path to ''
as $fn$
declare fiyat numeric; eklendi bigint;
begin
  if exists (select 1 from oyun.borsa_fiyat_referans where sirket_id=new.sirket_id) then return new; end if;
  if not exists (select 1 from oyun.sirketler where id=new.sirket_id and halka_acik and aktif) then return new; end if;
  fiyat:=oyun.borsa_son_fiyat(new.sirket_id);
  if fiyat is null or fiyat<=0 then return new; end if;
  insert into oyun.borsa_fiyat_referans(sirket_id,fiyat,ilk_fiyat,gerekce)
    values(new.sirket_id,fiyat,fiyat,'Yeni halka açık şirkette ilk fiyat tescili')
    on conflict(sirket_id) do nothing
    returning sirket_id into eklendi;
  if eklendi is not null then
    insert into oyun.borsa_fiyat_gecmis(sirket_id,fiyat,gerekce)
    values(eklendi,fiyat,'Yeni halka açık şirkette ilk fiyat tescili');
  end if;
  return new;
end $fn$;

drop trigger if exists borsa_fiyat_yeni_sirket on oyun.borsa_emir;
create trigger borsa_fiyat_yeni_sirket after insert on oyun.borsa_emir
for each row execute function oyun.tg_borsa_yeni_sirket_fiyat();

commit;
