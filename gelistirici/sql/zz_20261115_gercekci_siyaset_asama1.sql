
-- Asama 1: anayasal esikler + eylem imza korumasi (2026-11-15).
-- Beta dunyasi degismez; gercekci_siyaset lansman acilisinda etkinlestirilir.
alter table oyun.ayarlar add column if not exists gercekci_siyaset boolean not null default false;
create or replace function oyun.gercekci_siyaset() returns boolean language sql stable set search_path='' as $f$
 select coalesce((select gercekci_siyaset from oyun.ayarlar where id=1),false)
$f$;
create or replace function oyun.tbmm_tamsayi() returns integer language sql stable set search_path='' as $f$
 select case when oyun.gercekci_siyaset() then coalesce((select round(deger)::int from oyun.anayasa where kod='milletvekili_sayisi'),600) else oyun.dolu_sandalye() end
$f$;
create or replace function oyun.erken_secim_gerekli_oy() returns integer language sql stable set search_path='' as $f$
 select case when oyun.gercekci_siyaset() then ceil(oyun.tbmm_tamsayi()*3/5.0)::int else greatest(1,ceil(oyun.aktif_vekil_sayi()*coalesce((select deger from oyun.anayasa where kod='erken_secim_esigi'),60)/100.0)::int) end
$f$;
create or replace function oyun.grup_esigi(p_dolu integer) returns integer language sql stable set search_path='' as $f$
 select case when oyun.gercekci_siyaset() then 20 else greatest(2,ceil(p_dolu*20/600.0))::int end
$f$;
-- Min 10 veya son 7 gun aktif uygun hesaplarin %1'i, hangisi yuksekse.
create or replace function oyun.sokak_denge() returns oyun.sokak_denge_ayar language sql stable set search_path='' as $f$
 select jsonb_populate_record(null::oyun.sokak_denge_ayar,to_jsonb(a)||jsonb_build_object('imza_sayisi',greatest(10,ceil((select count(*) from oyun.profiller p where not p.yasakli and p.son_gorulme>=oyun.simdi()-interval '7 days')*0.01)::int)))
 from oyun.sokak_denge_ayar a where a.id=1
$f$;
-- Kisa yoldan eylem RPC / dogrudan INSERT girislerini sunucuda kapat.
create or replace function oyun.sokak_eylem_imza_kapisi() returns trigger language plpgsql security invoker set search_path='' as $f$
declare cid text:=nullif(current_setting('oyun.cagri_id',true),''); c oyun.sokak_cagri; gerekli integer; sayi integer;
begin
 if cid is null or cid !~ '^[0-9]+$' then raise exception 'Eylem icin once imza kampanyasi acilmalidir.'; end if;
 select * into c from oyun.sokak_cagri where id=cid::bigint for update;
 if c.id is null or c.durum<>'hazir' or c.acan is distinct from new.baslatan or c.il_id is distinct from new.il_id
     or c.kaynak is distinct from new.org_tur or c.kaynak_id is distinct from new.org_id
     or c.bitis<=oyun.simdi() then raise exception 'Onayli eylem cagrisi bulunamadi.'; end if;
 gerekli:=(oyun.sokak_denge()).imza_sayisi;
 select count(*) into sayi from oyun.sokak_cagri_imza where cagri_id=c.id;
 if sayi<gerekli then raise exception 'Eylem icin % dogrulanmis imza gerekli, mevcut: %.',gerekli,sayi; end if;
 return new;
end $f$;
drop trigger if exists sokak_eylem_imza_kapisi on oyun.sokak_eylem;
create trigger sokak_eylem_imza_kapisi before insert on oyun.sokak_eylem for each row execute function oyun.sokak_eylem_imza_kapisi();
-- Bu yamalar mevcut fonksiyon davranisini beta modunda korur.
do $fix$
declare s text;
begin
 s:=pg_get_functiondef('oyun.kanun_tick(timestamptz)'::regprocedure);
 s:=replace(s,'dolu := oyun.dolu_sandalye();','dolu := oyun.tbmm_tamsayi();');
 s:=replace(s,'(c.kabul + c.ret + c.cekimser) >= ceil(dolu / 2.0) and c.kabul > (c.kabul + c.ret + c.cekimser) / 2.0',
 '(c.kabul + c.ret + c.cekimser) >= (case when oyun.gercekci_siyaset() then ceil(dolu / 3.0) else ceil(dolu / 2.0) end) and c.kabul > (c.kabul + c.ret + c.cekimser) / 2.0 and (not oyun.gercekci_siyaset() or c.kabul >= floor(dolu / 4.0)+1)');
 s:=replace(s,'(c.kabul+c.ret+c.cekimser) >= ceil(dolu/2.0) and c.kabul > (c.kabul+c.ret+c.cekimser)/2.0',
 '(c.kabul+c.ret+c.cekimser) >= (case when oyun.gercekci_siyaset() then ceil(dolu/3.0) else ceil(dolu/2.0) end) and c.kabul > (c.kabul+c.ret+c.cekimser)/2.0 and (not oyun.gercekci_siyaset() or c.kabul >= floor(dolu/2.0)+1)');
 execute s;
 s:=pg_get_functiondef('oyun.meclis_tick(timestamptz)'::regprocedure);
 s:=replace(s,'dolu := oyun.dolu_sandalye();','dolu := oyun.tbmm_tamsayi();');
 execute s;
 s:=pg_get_functiondef('public.kanun_cb_karar(bigint,text,text)'::regprocedure);
 if position('Bütçe kanunu Cumhurbaşkanınca geri gönderilemez.' in s)=0 then
  s:=replace(s,'elsif p_karar = ''veto'' then','elsif p_karar = ''veto'' then' || chr(10) || '    if oyun.gercekci_siyaset() and k.tur = ''butce'' then raise exception ''Bütçe kanunu Cumhurbaşkanınca geri gönderilemez.''; end if;');
  execute s;
 end if;
end $fix$;
