create or replace function oyun.miting_otobus_ucret(p_kaynak smallint,p_hedef smallint)
returns numeric language plpgsql stable set search_path = '' as $$
declare x oyun.miting_il_konum; y oyun.miting_il_konum; km numeric;
begin
 select * into x from oyun.miting_il_konum where il_id=p_kaynak;
 select * into y from oyun.miting_il_konum where il_id=p_hedef;
 if x.il_id is null or y.il_id is null then raise exception 'Ulaşım tarifesi bulunamadı.'; end if;
 if p_kaynak=p_hedef then return 0; end if;
 km := 1.28 * 6371 * acos(least(1,greatest(-1,
 sin(radians(x.lat::double precision))*sin(radians(y.lat::double precision))+
 cos(radians(x.lat::double precision))*cos(radians(y.lat::double precision))*
 cos(radians((x.lon-y.lon)::double precision)))));
 return least(2000, greatest(400,ceil((300+1.5*km)/100)*100));
end $$;