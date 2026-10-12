-- 2026-10-13: satilan belediye parsellerini kontrollu yenile.
-- Her il / imar kapasitesinde ayni anda bir aktif arsa bulunur; satilan arsa tarihi tapu olarak saklanir.
alter table oyun.eko_arsalar drop constraint if exists eko_arsalar_il_id_kademe_key;
create unique index if not exists eko_arsalar_aktif_il_kademe
 on oyun.eko_arsalar(il_id,kademe) where durum='satilik';
create or replace function oyun.eko_belediye_arsa_yenile()
returns trigger language plpgsql security definer set search_path to '' as $$
declare g numeric;
begin
 if new.durum='satildi' and old.durum='satilik' then
  select coalesce(gelisim,50) into g from oyun.il_durum where il_id=new.il_id;
  insert into oyun.eko_arsalar(il_id,kademe,alan_m2,fiyat)
  values(new.il_id,new.kademe,new.alan_m2,
   greatest(round(new.fiyat*1.03),round(oyun.mulk_il_bedel(new.il_id,'daire')*
   new.kademe*.27*(.85+greatest(0,least(g,100))/500))))
  on conflict do nothing;
 end if;
 return new;
end $$;
drop trigger if exists eko_belediye_arsa_yenile_tg on oyun.eko_arsalar;
create trigger eko_belediye_arsa_yenile_tg
 after update of durum on oyun.eko_arsalar for each row
 when (old.durum='satilik' and new.durum='satildi')
 execute function oyun.eko_belediye_arsa_yenile();
