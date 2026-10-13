-- Ikinci guvenlik katmani: hicbir kod yolu ruhsati otomatik yanlis sirkete baglayamaz.
-- Tarihi yanlis baglanmis kayitlar silinmez, yalniz yeni/kimlik degisimi engellenir.
create or replace function oyun.bel_ruhsat_kimlik_koruma()
returns trigger language plpgsql security definer set search_path='' as $$
declare s oyun.sirketler;
begin
 if new.tur in ('kur_sirket','kur_pazar') and new.sirket_id is not null then
  raise exception 'Yeni sirket kurulus ruhsati mevcut sirket kaydina baglanamaz.';
 end if;
 if new.tur in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta') and new.sirket_id is not null then
  select * into s from oyun.sirketler where id=new.sirket_id;
  if s.id is null or not s.aktif or new.sirket_adi is distinct from s.ad then
   raise exception 'Mevcut sirket ruhsati icin dogru sirket adi zorunlu.';
  end if;
  if (new.tur='kur_fabrika' and s.sektor not in ('tarim','sanayi','teknoloji'))
  or (new.tur='kur_magaza' and s.sektor<>'ticaret')
  or (new.tur='kur_insaat' and s.sektor<>'insaat')
  or (new.tur='kur_sigorta' and s.sektor<>'ticaret') then
   raise exception 'Ruhsat turu mevcut sirketin sektoruyle uyumsuz.';
  end if;
 end if;
 return new;
end $$;
revoke all on function oyun.bel_ruhsat_kimlik_koruma() from public,anon,authenticated;
drop trigger if exists tr_bel_ruhsat_kimlik_koruma on oyun.bel_yatirim_ruhsat;
create trigger tr_bel_ruhsat_kimlik_koruma
before insert or update of sirket_id,sirket_adi,tur on oyun.bel_yatirim_ruhsat
for each row execute function oyun.bel_ruhsat_kimlik_koruma();
