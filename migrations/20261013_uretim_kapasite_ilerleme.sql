-- Uretim kapasitesi: sirket sermayesi ve tamamlanmis uretim ile otomatik ilerleme.
-- Sirket, para, stok veya mevcut uretim emirlerinde UPDATE/DELETE yapmaz.
-- 4 tam parti esdeger uretim = +%25; her 250.000 TL ilave sermaye = +%25.
-- Uretim bonusu en fazla 16 adim, sermaye bonusu 20 adim: toplam en fazla 10 kat.
begin;

create index if not exists eko_uretim_emir_tamamlanan_sirket_idx
 on oyun.eko_uretim_emir(sirket_id) where tamamlandi is not null;

create or replace function oyun.eko_fabrika_kapasite(p_sirket bigint)
returns jsonb language sql stable security definer set search_path to '' as $func$
with fabrika as (
 select s.sermaye
 from oyun.sirketler s
 join oyun.eko_isletmeler i on i.sirket_id=s.id and i.tur='fabrika'
 where s.id=p_sirket and s.aktif
), gecmis as (
 select coalesce(sum(q.adet),0)::bigint as tamamlanan_adet,
 coalesce(sum(q.adet::numeric/k.parti_ust),0) as esdeger_parti
 from oyun.eko_uretim_emir q
 join oyun.eko_urun_katalog k on k.kod=q.urun
 where q.sirket_id=p_sirket and q.tamamlandi is not null
), adim as (
 select f.sermaye,g.tamamlanan_adet,g.esdeger_parti,
 least(16,floor(g.esdeger_parti/4)::integer) as uretim_adim,
 least(20,floor(greatest(f.sermaye-250000,0)/250000)::integer) as sermaye_adim
 from fabrika f cross join gecmis g
)
select jsonb_build_object(
 'katsayi',1::numeric+(a.uretim_adim+a.sermaye_adim)*0.25,
 'tamamlanan_adet',a.tamamlanan_adet,
 'esdeger_parti',round(a.esdeger_parti,2),
 'uretim_adim',a.uretim_adim,
 'sermaye_adim',a.sermaye_adim,
 'sonraki_uretim_esdeger',case when a.uretim_adim<16 then (a.uretim_adim+1)*4 else null end,
 'sonraki_sermaye',case when a.sermaye_adim<20 then 250000+(a.sermaye_adim+1)*250000 else null end
) from adim a
$func$;

revoke all on function oyun.eko_fabrika_kapasite(bigint) from public,anon,authenticated;

do $patch$
declare source text; needle text;
begin
 select pg_get_functiondef('public.eko_ticaret_panel()'::regprocedure) into source;
 needle:='''sermaye'',s.sermaye,''yonetici'',oyun.sirket_yonetici_mi(s.id,u)';
 if position('''kapasite'',case when e.tur=''fabrika''' in source)=0 then
  if position(needle in source)=0 then raise exception 'Ticaret paneline kapasite ekleme noktasi bulunamadi.';end if;
  source:=replace(source,needle,
    '''sermaye'',s.sermaye,''kapasite'',case when e.tur=''fabrika'' then oyun.eko_fabrika_kapasite(s.id) else null end,''yonetici'',oyun.sirket_yonetici_mi(s.id,u)');
  execute source;
 end if;

 select pg_get_functiondef('public.eko_ticaret_islem(text,jsonb)'::regprocedure) into source;
 needle:='or miktar>k.parti_ust then';
 if position(needle in source)>0 then
   source:=replace(source,needle,
     'or miktar>ceil(k.parti_ust*coalesce((oyun.eko_fabrika_kapasite(sid)->>''katsayi'')::numeric,1)) then');
   execute source;
 elsif position('oyun.eko_fabrika_kapasite(sid)' in source)=0 then
   raise exception 'Ticaret uretim sinirina kapasite kontrolu ekleme noktasi bulunamadi.';
 end if;
end $patch$;

commit;
