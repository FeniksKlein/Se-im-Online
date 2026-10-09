-- SADECE YEREL TEST İÇİN. Supabase'deki pg_cron eklentisini taklit eder (iş kaydı tutar, çalıştırmaz).
create schema if not exists cron;
create table if not exists cron.job(jobid bigserial primary key, jobname text unique, schedule text, command text);
create or replace function cron.schedule(p_ad text, p_zaman text, p_komut text) returns bigint language plpgsql as $$
declare i bigint;
begin
  insert into cron.job(jobname, schedule, command) values (p_ad, p_zaman, p_komut)
  on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command returning jobid into i;
  return i;
end $$;
create or replace function cron.unschedule(p_id bigint) returns boolean language sql as $$ delete from cron.job where jobid = p_id returning true $$;
create or replace function cron.unschedule(p_ad text) returns boolean language sql as $$ delete from cron.job where jobname = p_ad returning true $$;
