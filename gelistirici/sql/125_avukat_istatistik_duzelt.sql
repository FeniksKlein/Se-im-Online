
-- Basari istatistikleri ve guvenli savunma butonu gorunurlugu
do $patch$
declare def text; eski text; yeni text;
begin
 select pg_get_functiondef('public.avukat_dava_durum(bigint)'::regprocedure) into def;
 eski:='''benim'',v.avukat_id=p.id or v.muvekkil=p.id';
 yeni:='''benim'',v.avukat_id=p.id or v.muvekkil=p.id,''avukat_miyim'',v.avukat_id=p.id';
 if position(eski in def)=0 then raise exception 'Vekalet API semasi degisti: beklenen alan bulunamadi.'; end if;
 execute replace(def,eski,yeni);
 select pg_get_functiondef('public.avukat_durum()'::regprocedure) into def;
 eski:='where v.avukat_id=r.user_id and d.kesin';
 yeni:='where v.avukat_id=r.user_id and v.tarih<=d.karar_at and (v.iptal_at is null or v.iptal_at>=d.karar_at) and d.kesin';
 if position(eski in def)=0 then raise exception 'Istatistik API semasi degisti: beklenen alan bulunamadi.'; end if;
 execute replace(def,eski,yeni);
end $patch$;
