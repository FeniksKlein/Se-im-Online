-- SADECE YEREL TEST: sahte oyuncular (botlar). Supabase'e YÜKLENMEZ.
create or replace function oyun.test_bot_olustur(n int, p_olusturma timestamptz) returns void language plpgsql as $$
declare i int; u uuid; il int; pid bigint; aktif int[] := array[34,6,35,16,7,1,42,27,21,61,55,38,20,45,9,41,33,63,65,48];
begin
  for i in 1..n loop
    u := gen_random_uuid();
    insert into auth.users(id, email, email_confirmed_at) values (u, 'bot'||i||'@test', now());
    il := aktif[1 + floor(random() * array_length(aktif,1))::int];
    insert into oyun.profiller(id, kad, il_id, il_at, olusturma) values (u, 'Bot_'||i, il, p_olusturma, p_olusturma);
    pid := (array[1,1,1,2,2,3,3,4,5])[1 + floor(random()*9)::int];
    update oyun.profiller set parti_id = pid, parti_at = p_olusturma where id = u;
  end loop;
end $$;

-- Başvurusu açık seçime botların bir kısmı aday olur
create or replace function oyun.test_bot_aday(p_tur text, oran float) returns int language plpgsql as $$
declare r record; n int := 0;
begin
  for r in select id from oyun.profiller where kad like 'Bot\_%' and random() < oran loop
    perform set_config('request.jwt.claim.sub', r.id::text, true);
    begin perform public.aday_ol(p_tur); n := n + 1; exception when others then null; end;
  end loop;
  return n;
end $$;

-- Sandığı açık seçimde botlar oy verir: kendi partisine/adayına eğilimli, yoksa rastgele
create or replace function oyun.test_bot_oy(p_secim bigint) returns int language plpgsql as $$
declare r record; d jsonb; sec jsonb; h bigint; n int := 0;
begin
  for r in select id, parti_id from oyun.profiller where kad like 'Bot\_%' loop
    perform set_config('request.jwt.claim.sub', r.id::text, true);
    begin
      d := public.secim_detay(p_secim);
      sec := d->'secenekler';
      continue when jsonb_array_length(sec) = 0;
      select (x->>'hedef')::bigint into h from jsonb_array_elements(sec) x
        order by ((coalesce(x->>'parti_id', x->>'id'))::bigint = r.parti_id and random() < 0.8) desc, random() limit 1;
      perform public.oy_ver(p_secim, h); n := n + 1;
    exception when others then null; end;
  end loop;
  return n;
end $$;
