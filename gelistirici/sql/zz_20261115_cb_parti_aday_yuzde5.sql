-- TR Anayasa 101, 6271 s. Kanun 7: CB adayı gösterme için TBMM grubu (20 MV)
-- veya son milletvekili seçiminde tek başına/ittifakla en az %5 oy.
-- Lansman ilk seçiminde geçmiş seçim olmadığından sadece dört sistem partisinin geçici hakki vardir.
create or replace function oyun.cb_parti_aday_gosterebilir(p_parti bigint,p_donem text)
returns boolean language plpgsql stable set search_path='' as $f$
declare v_s oyun.secimler; v_share numeric; v_alliance numeric; v_group int;
begin
 if not oyun.gercekci_siyaset() then return true; end if;
 if p_parti is null or not exists(select 1 from oyun.partiler where id=p_parti and not kapali and kurulus_bit is null)
 then return false; end if;
 if p_donem like 'lansman-%' then
   return exists(select 1 from oyun.partiler where id=p_parti and sistem and not kapali);
 end if;
 select count(distinct m.user_id) into v_group from oyun.makamlar m
   join oyun.profiller pr on pr.id=m.user_id
   where m.tur='mv' and m.bit is null and pr.parti_id=p_parti and not pr.yasakli;
 if v_group>=20 then return true; end if;
 select * into v_s from oyun.secimler s where s.tur='mv' and s.durum='tamam'
   and s.sonuc ? 'ulusal' and not (s.sonuc ? 'iptal')
   and jsonb_typeof(s.sonuc->'ulusal')='array'
 order by s.oy_bit desc,s.id desc limit 1;
 if v_s.id is null then return false; end if;
 with party_votes as (
   select (a->>'parti_id')::bigint id,coalesce((a->>'yuzde')::numeric,0) pct
   from jsonb_array_elements(v_s.sonuc->'ulusal') a
 ) select coalesce(max(pct),0) into v_share from party_votes where id=p_parti;
 if v_share>=5 then return true; end if;
 with party_votes as (
   select (a->>'parti_id')::bigint id,coalesce((a->>'yuzde')::numeric,0) pct
   from jsonb_array_elements(v_s.sonuc->'ulusal') a
 ), joint as (
   select ai.ittifak_id,sum(v.pct) pct
   from oyun.secim_ittifak_anlik ai join party_votes v on v.id=ai.parti_id
   where ai.secim_id=v_s.id and ai.ittifak_id in (
      select aj.ittifak_id from oyun.secim_ittifak_anlik aj
      where aj.secim_id=v_s.id and aj.parti_id=p_parti
   ) group by ai.ittifak_id
 ) select coalesce(max(pct),0) into v_alliance from joint;
 return v_alliance>=5;
end $f$;
create or replace function oyun.cb_parti_aday_hakki_koru() returns trigger
language plpgsql security invoker set search_path='' as $f$
begin
 if oyun.gercekci_siyaset()
   and new.yontem in ('kendisi','baskasi','onsecim')
   and not oyun.cb_parti_aday_gosterebilir(new.parti_id,new.donem)
 then
   raise exception 'Parti Cumhurbaşkanı adayı gösterebilmek için TBMM grubu (en az 20 MV) veya son genel seçimde tek başına/ittifakla yüzde 5 oy şartını sağlamalı.';
 end if;
 return new;
end $f$;
drop trigger if exists cb_parti_aday_hakki_koru on oyun.cb_kararlar;
create trigger cb_parti_aday_hakki_koru before insert or update on oyun.cb_kararlar
 for each row execute function oyun.cb_parti_aday_hakki_koru();
