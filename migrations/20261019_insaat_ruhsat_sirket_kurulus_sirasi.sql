-- Insaat sirketi kurulusunda ruhsat tetikleyicisi, sirket ortakligi
-- kaydedilmeden calisiyordu. Bu nedenle gecerli kur_insaat ruhsati
-- olsa bile "Ruhsat icin sirket yonetim yetkisi gerekli" hatasi veriliyordu.
--
-- Ilk kurulusun otomatik insaat isletmesini islemin en sonunda ac:
-- sirket_ortaklari olusmus olur ve varsa eko_islem'in ayni islemde
-- olusturdugu isletme ON CONFLICT ile tekrar kurulmaz.
-- Sektor degistirilince mevcut sirketin tanitilmasi ise aynen surer.
begin;

create or replace function oyun.eko_insaat_sirket_tanit()
returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  -- ON CONFLICT DO NOTHING tek basina yeterli degil: BEFORE INSERT
  -- ruhsat kapisi, cakisacak satir icin bile yeniden harc arar.
  if new.sektor = 'insaat' and new.aktif
    and not exists (
      select 1 from oyun.eko_isletmeler where sirket_id = new.id
    ) then
    insert into oyun.eko_isletmeler
      (sirket_id, tur, il_id, urun, uretim_fiyat, perakende_fiyat)
    values
      (new.id, 'insaat',
       coalesce((select il_id from oyun.profiller where id = new.kurucu), 1),
       null, 0, 0)
    on conflict (sirket_id) do nothing;
  end if;
  return new;
end $function$;

drop trigger if exists eko_insaat_sirket_tanit on oyun.sirketler;

create trigger eko_insaat_sirket_tanit_sektor
after update of sektor on oyun.sirketler
for each row execute function oyun.eko_insaat_sirket_tanit();

create constraint trigger eko_insaat_sirket_tanit_kurulus
after insert on oyun.sirketler
deferrable initially deferred
for each row execute function oyun.eko_insaat_sirket_tanit();

commit;
