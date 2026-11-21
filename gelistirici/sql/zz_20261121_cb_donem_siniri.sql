-- 21.11.2026 · Cumhurbaşkanı dönem sınırı ve seçmen imzası yolu (canlı migration'lar:
--   cb_donem_siniri_ve_aday_gosterme_sarti, cb_aday_gosterme_mukerrer_kural_kaldir)
-- Anayasa m.101: bir kimse en fazla iki defa Cumhurbaşkanı seçilebilir.
-- Anayasa m.116: ikinci döneminde seçimleri TBMM yenilerse Cumhurbaşkanı bir kez daha aday olabilir.
-- Aday gösterme şartı (grup / %5) zz_20261115_cb_parti_aday_yuzde5.sql'dedir; burada yalnız imza yolu ona bağlanır:
-- aday gösterme hakkı olmayan partinin üyesi de seçmen imzasıyla aday olabilir.
create or replace function oyun.cb_donem_siniri()
returns integer language sql stable set search_path to '' as $fn$
  select coalesce((select round(deger)::int from oyun.anayasa where kod = 'cb_donem_siniri'), 2)
$fn$;
-- Yalnız seçimle gelinen dönemler sayılır (atama ve vekâlet sayılmaz)
create or replace function oyun.cb_secilme_sayisi(u uuid)
returns integer language sql stable set search_path to '' as $fn$
  select count(distinct m.secim_id)::int from oyun.makamlar m
   where m.user_id = u and m.tur = 'cb' and m.secim_id is not null
$fn$;
create or replace function oyun.cb_donem_engeli(u uuid, p_secim bigint)
returns text language plpgsql stable set search_path to '' as $fn$
declare s oyun.secimler; n int; lim int;
begin
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.tur not in ('cb_on','cb') then return null; end if;
  lim := oyun.cb_donem_siniri();
  n := oyun.cb_secilme_sayisi(u);
  if n < lim then return null; end if;
  -- m.116: erken seçim dönem adı 'erken-genel-<teklif no>-…' ise kararı TBMM vermiştir (Cumhurbaşkanı kararında no eksidir)
  if n = lim and s.donem ~ '^erken-genel-[0-9]+-'
     and exists (select 1 from oyun.makamlar m
                  where m.user_id = u and m.tur = 'cb' and m.bit is null and m.secim_id is not null) then
    return null;
  end if;
  return format('Anayasa m.101: Bir kimse en fazla %s defa Cumhurbaşkanı seçilebilir. %s kez seçildiğin için yeniden aday olamazsın.', lim, n);
end $fn$;
create or replace function oyun.cb_donem_siniri_tg()
returns trigger language plpgsql set search_path to '' as $fn$
declare s oyun.secimler; e text;
begin
  if tg_op = 'UPDATE' and new.secim_id = old.secim_id and new.user_id = old.user_id then return new; end if;
  select * into s from oyun.secimler where id = new.secim_id;
  if s.id is null or s.tur not in ('cb_on','cb') then return new; end if;
  -- Ön seçimde denetlenmiş aday asıl seçime taşınırken yeniden denetlenmez (seçim motoru kilitlenmesin)
  if s.tur = 'cb' and exists (
       select 1 from oyun.adaylar a join oyun.secimler o on o.id = a.secim_id
        where a.user_id = new.user_id and o.donem = s.donem and o.tur = 'cb_on') then
    return new;
  end if;
  e := oyun.cb_donem_engeli(new.user_id, new.secim_id);
  if e is not null then raise exception '%', e; end if;
  return new;
end $fn$;
revoke all on function oyun.cb_donem_siniri() from public;
revoke all on function oyun.cb_secilme_sayisi(uuid) from public;
revoke all on function oyun.cb_donem_engeli(uuid,bigint) from public;
revoke all on function oyun.cb_donem_siniri_tg() from public;
grant execute on function oyun.cb_donem_siniri() to service_role;
grant execute on function oyun.cb_secilme_sayisi(uuid) to service_role;
grant execute on function oyun.cb_donem_engeli(uuid,bigint) to service_role;
grant execute on function oyun.cb_donem_siniri_tg() to service_role;
drop trigger if exists cb_donem_siniri_tg on oyun.adaylar;
create trigger cb_donem_siniri_tg before insert or update of secim_id, user_id on oyun.adaylar
  for each row execute function oyun.cb_donem_siniri_tg();

select oyun._yama('public.bagimsiz_aday_ol(bigint)',
  $re$if\s+p\.parti_id\s+is\s+not\s+null\s+then\s+raise\s+exception\s+'Bağımsız aday olmak için herhangi bir partiye üye olmamalısın\.';\s*end\s+if;$re$,
  $new$if p.parti_id is not null
     and not (o.tur = 'cb_on' and oyun.gercekci_siyaset() and not oyun.cb_parti_aday_gosterebilir(p.parti_id, o.donem)) then
    if o.tur = 'cb_on' and oyun.gercekci_siyaset() then
      raise exception 'Partinin Cumhurbaşkanı adayı gösterme hakkı var; adaylık parti üzerinden belirlenir. Seçmen imzasıyla adaylık, partisiz oyunculara ve aday gösterme hakkı olmayan partilerin üyelerine açıktır.';
    end if;
    raise exception 'Bağımsız aday olmak için herhangi bir partiye üye olmamalısın.';
  end if;$new$,
  'aday gösterme hakkı olmayan partilerin üyelerine');
select oyun._yama('public.bagimsiz_aday_ol(bigint)',
  $re$(if\s+o\.tur\s*=\s*'cb_on'\s+and\s+oyun\.gercekci_siyaset\(\)\s+then\s+perform\s+1\s+from\s+oyun\.ayarlar\s+where\s+id\s*=\s*1\s+for\s+update;)$re$,
  $new$\1
   if oyun.cb_donem_engeli(p.id, h.id) is not null then
     raise exception '%', oyun.cb_donem_engeli(p.id, h.id);
   end if;$new$,
  'oyun.cb_donem_engeli(p.id, h.id)');
