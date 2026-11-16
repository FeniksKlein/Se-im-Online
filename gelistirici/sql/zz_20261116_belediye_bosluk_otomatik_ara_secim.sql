-- Belediye makami her olagan disi bosaldiginda hedef ilde ertesi gun secim ac.
-- Normal secim devirlerinde donem_bitti tetiklemez. Tekrarlayan cagri ara_secim_olustur dedup ile engellenir.
create or replace function oyun.belediye_bosaldi_ara_secim_tg()
returns trigger language plpgsql security definer set search_path to '' as $f$
begin
 if old.tur='bel' and old.bit is null and new.bit is not null
    and new.il_id is not null and coalesce(new.bitis_neden,'')<>'donem_bitti' then
   if not exists(
     select 1 from oyun.makamlar m where m.tur='bel' and m.il_id=new.il_id
       and m.bit is null and m.id<>new.id
   ) then
     perform oyun.ara_secim_olustur('bel',null,new.il_id,oyun.simdi());
   end if;
 end if;
 return new;
end $f$;
drop trigger if exists belediye_bosaldi_ara_secim on oyun.makamlar;
create trigger belediye_bosaldi_ara_secim
after update of bit on oyun.makamlar
for each row when (old.tur='bel' and old.bit is null and new.bit is not null)
execute function oyun.belediye_bosaldi_ara_secim_tg();
