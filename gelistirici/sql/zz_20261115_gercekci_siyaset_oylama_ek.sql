-- Gercekci Meclis ek duzeltme: olumlu oy hesabinin erken kapanmasini engelle, rehberde cogunlugu dogru goster.
DO $fix$
DECLARE s text;
BEGIN
  s:=pg_get_functiondef('oyun.kanun_tick(timestamptz)'::regprocedure);
  IF position('greatest(1,ceil(oyun.dolu_sandalye()/2.0)::int)' in s)=0 THEN
    RAISE EXCEPTION 'Kanun oylamasi erken sayim metni bulunamadi.';
  END IF;
  s:=replace(s,
    'greatest(1,ceil(oyun.dolu_sandalye()/2.0)::int)',
    '(case when oyun.gercekci_siyaset() then oyun.tbmm_tamsayi()+1 else greatest(1,ceil(oyun.dolu_sandalye()/2.0)::int) end)');
  EXECUTE s;
  s:=pg_get_functiondef('public.meclis_rehber()'::regprocedure);
  IF position('(select dolu / 2 + 1 from sayi)' in s)>0 THEN
    s:=replace(s,'(select dolu / 2 + 1 from sayi)',
      '(case when oyun.gercekci_siyaset() then floor(oyun.tbmm_tamsayi()/2.0)::int+1 else (select dolu / 2 + 1 from sayi) end)');
    EXECUTE s;
  END IF;
END $fix$;
