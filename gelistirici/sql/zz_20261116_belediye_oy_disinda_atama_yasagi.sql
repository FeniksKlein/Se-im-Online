-- Belediye baskanligi sadece sandikla kazanilir; yeni profil kaydi bos makama atama yapmaz.
drop trigger if exists yeni_oyuncu_baskan_ata on oyun.profiller;
create or replace function oyun.bos_belediyeye_otomatik_ata(p_oyuncu uuid)
returns smallint language plpgsql security definer set search_path to '' as $fn$
begin
 return null;
end $fn$;
