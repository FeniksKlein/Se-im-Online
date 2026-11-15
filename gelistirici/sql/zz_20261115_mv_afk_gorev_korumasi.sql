-- Secim Simulasyonu Online / kalici gercekci TBMM vekillik korumasi.
-- Beta 7-gun aktif secmen test filtresi korunur, gercekci modda MV makami AFK sebebiyle dusmez.
create or replace function oyun.aktif_vekil(u uuid) returns boolean language sql stable set search_path='' as $f$
 select exists(
   select 1 from oyun.makamlar m join oyun.profiller p on p.id=m.user_id
   where m.user_id=u and m.tur='mv' and m.bit is null
     and not coalesce(p.yasakli,false)
     and (oyun.gercekci_siyaset() or p.son_gorulme >= oyun.simdi()-interval '7 days')
 )
$f$;
create or replace function oyun.dolu_sandalye() returns integer language sql stable set search_path='' as $f$
 select count(distinct m.user_id)::integer
 from oyun.makamlar m join oyun.profiller p on p.id=m.user_id
 where m.tur='mv' and m.bit is null and not coalesce(p.yasakli,false)
   and (oyun.gercekci_siyaset() or p.son_gorulme >= oyun.simdi()-interval '7 days')
$f$;
