create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function oyun.bildir(u uuid, m text, t timestamptz default null) returns void language sql as $$ select $$;
create function oyun.kad(u uuid) returns text language sql stable as $$ select kad from oyun.profiller where id=u $$;
create function oyun.tl(n numeric) returns text language sql as $$ select n::text $$;
create function oyun.profil_bul(k text) returns oyun.profiller language sql stable as $$ select * from oyun.profiller where lower(kad)=lower(k) $$;
create function oyun.profilim() returns oyun.profiller language sql stable as $$ select * from oyun.profiller where id=auth.uid() $$;
create function oyun.gozalti_aktif(u uuid) returns text language sql as $$ select null::text $$;
drop function oyun.gby_alan(text); create function oyun.gby_alan(p_gorev text) returns text language sql immutable as $$ select case btrim(coalesce(p_gorev,'')) when 'Teşkilattan Sorumlu' then 'teskilat' when 'Mali İşlerden Sorumlu' then 'mali' end $$;
create table oyun.partiler2(x int);
insert into oyun.iller values(6,'Ankara');
insert into oyun.parti_teskilat values(1,6),(1,34);
insert into oyun.partiler values(2,null,false,'BP','B');
insert into oyun.profiller(id,kad,parti_id,il_id,parti_at,il_at,olusturma) values
 ('00000000-0000-0000-0000-000000000003','u3',1,6,now()-interval '9 days',now()-interval '9 days',now()-interval '9 days'),
 ('00000000-0000-0000-0000-000000000004','u4',1,6,now()-interval '9 days',now()-interval '9 days',now()-interval '9 days'),
 ('00000000-0000-0000-0000-000000000005','yeni',1,6,now()+interval '1 hour',now(),now());
update oyun.profiller set parti_at=now()-interval '10 days', il_at=now()-interval '10 days', olusturma=now()-interval '10 days' where kad in ('gb','y');
