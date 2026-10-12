-- Aktif otomasyonun ayarini yenilemek 7 gunluk lisansi ucretsiz uzatmasin.
do $patch$
declare source text;
begin
 select pg_get_functiondef('public.eko_ticaret_islem(text,jsonb)'::regprocedure) into source;
 source:=replace(source,
 'bitis=greatest(oyun.eko_otomatik_tedarik.bitis,excluded.bitis),aktif=true',
 'bitis=case when oyun.eko_otomatik_tedarik.aktif and oyun.eko_otomatik_tedarik.bitis>t
 then oyun.eko_otomatik_tedarik.bitis else excluded.bitis end,aktif=true');
 source:=replace(source,'if e.tur<>''magaza'' or kategori not in',
 'if e.tur<>''magaza'' or kategori not in');
 execute source;
end $patch$;