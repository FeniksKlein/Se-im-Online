-- Pazar tipi mevcut sirketleri de sifirlamadan magazacilik sistemine baglayabil.
do $mig$
declare definition text;replacement text;
begin
 select pg_get_functiondef('public.eko_ticaret_islem(text,jsonb)'::regprocedure) into definition;
 if position('p_eylem=''bagla''' in definition)>0 then return;end if;
 replacement:=$body$
 if p_eylem='bagla' then
  if e.sirket_id is not null then raise exception 'Bu sirket zaten yeni ekonomiye bagli.';end if;
  if coalesce((select pay from oyun.sirket_ortaklari where sirket_id=sid and user_id=u),0)<>100
    or s.halka_acik then raise exception 'Yalnizca yuzde yuz sahip oldugun halka kapali sirket baglanabilir.';end if;
  if s.sektor in ('ticaret','market') then
   insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat,magaza_kategori)
   values(sid,'magaza',coalesce((select il_id from oyun.profiller where id=u),1),null,0,9500,'market');
   return jsonb_build_object('tur','magaza','sirket',sid);
  elsif s.sektor in ('tarim','sanayi','teknoloji') then
   if s.sektor='tarim' and ur<>'gida' or s.sektor='teknoloji' and ur<>'teknoloji'
     or s.sektor='sanayi' and ur not in ('gida','teknoloji','malzeme')
   then raise exception 'Fabrika uretim grubu sirket sektorune uygun degil.';end if;
   insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat)
   values(sid,'fabrika',coalesce((select il_id from oyun.profiller where id=u),1),ur,0,0);
   return jsonb_build_object('tur','fabrika','sirket',sid);
  end if;
  raise exception 'Bu sektor uretim veya magazacilik icin uygun degil.';
 end if;
$body$;
 if position('if p_eylem=''uret'' then' in definition)=0 then
  raise exception 'Cannot locate production action in eko_ticaret_islem';end if;
 definition:=replace(definition,'if p_eylem=''uret'' then',replacement||'if p_eylem=''uret'' then');
 execute definition;
end $mig$;
