-- Gercekci Anayasa md. 175: ilk gorusmeden sonra imzalar kesinlesir.
-- 2. gizli oylama icin ilk teklif imzalari yeniden aranmaz.
do $fix$
declare s text;
begin
  s:=pg_get_functiondef('oyun.kanun_tick(timestamptz)'::regprocedure);
  if strpos(s,'and t >= oy_bas order by oy_bas loop')>0 then
    s:=replace(s, 'and t >= oy_bas order by oy_bas loop',
      'and t >= oy_bas and (not oyun.gercekci_siyaset() or anayasa_tur=0) order by oy_bas loop');
    execute s;
  end if;
  s:=pg_get_functiondef('public.kanun_imza(bigint,boolean)'::regprocedure);
  if strpos(s, 'if k.durum <> ''gorusmede'' or t >= k.oy_bas')>0 then
    s:=replace(s,
      'if k.durum <> ''gorusmede'' or t >= k.oy_bas',
      'if k.durum <> ''gorusmede'' or t >= k.oy_bas or (oyun.gercekci_siyaset() and k.anayasa_tur>0)');
    execute s;
  end if;
end $fix$;
