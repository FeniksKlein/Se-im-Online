-- Sigorta sirketlerinin hasar sonucu kesinlesince net polis kazancini ve kurumlar vergisini hesapla.
do $patch$
declare src text;
begin
 select pg_get_functiondef('oyun.eko_kar_yaz(bigint,text,bigint,numeric,numeric,numeric,timestamp with time zone)'::regprocedure) into src;
 src:=replace(src,'''franchise_fee'',''emlak'')','''franchise_fee'',''emlak'',''sigorta'')');
 execute src;
end $patch$;
create or replace function oyun.eko_sigorta_kar_vergisi()
returns trigger language plpgsql security definer set search_path to '' as $$
declare kar numeric;kurumlar numeric;
begin
 if old.durum<>'aktif' or new.durum not in ('hasarsiz','hasar_odendi') then return new;end if;
 if not exists(select 1 from oyun.eko_isletmeler e where e.sirket_id=new.sirket_id and e.tur='sigorta')
 then return new;end if;
 if new.bas<(select min(guncelleme) from oyun.eko_vergi_turleri where kod='kurumlar')
 then return new;end if;
 kar:=new.prim-coalesce(new.odenen,0);
 kurumlar:=oyun.eko_vergi_hesap('kar',greatest(0,kar));
 if kurumlar>0 then
   update oyun.sirketler set kasa=kasa-kurumlar where id=new.sirket_id and kasa>=kurumlar;
   if not found then raise exception 'Sigorta sirketi tahakkuk vergisi icin nakit rezervi tutmali.';end if;
   perform oyun.eko_vergi_tahsil(new.sirket_id,'kar',greatest(0,kar),'sigorta_police',new.id);
 end if;
 perform oyun.eko_kar_yaz(new.sirket_id,'sigorta',new.id,new.prim,kurumlar,kar-kurumlar,oyun.simdi());
 return new;
end $$;
drop trigger if exists eko_sigorta_kar_vergisi on oyun.eko_policeler;
create trigger eko_sigorta_kar_vergisi after update of durum on oyun.eko_policeler
for each row execute function oyun.eko_sigorta_kar_vergisi();
