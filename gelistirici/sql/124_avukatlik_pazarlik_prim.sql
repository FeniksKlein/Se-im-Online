
-- Avukatlik B modeli ince ayarlari, pazarlik, basari primi ve mevcut adliye uyumu
alter table oyun.adliye_beyan drop constraint if exists adliye_beyan_rol_check;
alter table oyun.adliye_beyan add constraint adliye_beyan_rol_check check(rol in('davaci','davali','sozcu','ilgili','avukat'));
create or replace function public.avukat_iller() returns jsonb language sql stable security definer set search_path='' as $f$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'ad',ad) order by id),'[]'::jsonb) from oyun.iller
$f$;
create or replace function public.avukat_buro_davetler() returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 return coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'ad',b.ad,'kurucu',oyun.kad(b.kurucu)) order by b.id desc)
 from oyun.hukuk_buro_uyeleri y join oyun.hukuk_burolari b on b.id=y.buro_id
 where y.avukat_id=p.id and y.durum='davet' and b.aktif),'[]'::jsonb);
end $f$;
create table if not exists oyun.avukat_pazarlik (
 teklif_id bigint primary key references oyun.avukat_teklifleri(id),
 muvekkil uuid not null references oyun.profiller(id),
 tutar numeric not null check(tutar between 0 and 1000000000000),
 prim numeric not null check(prim between 0 and 30),
 durum text not null default 'bekliyor' check(durum in('bekliyor','kabul','ret')),
 zaman timestamptz not null default now()
);
alter table oyun.avukat_pazarlik enable row level security;
revoke all on oyun.avukat_pazarlik from public, anon, authenticated;
create or replace function public.avukat_karsi_teklif(p_teklif bigint,p_tutar numeric,p_prim numeric) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t oyun.avukat_teklifleri; d oyun.adliye_davalar; yetki boolean;
begin
 select * into t from oyun.avukat_teklifleri where id=p_teklif for update;
 if t.id is null or t.durum<>'bekliyor' then raise exception 'Teklif kapandi.'; end if;
 select * into d from oyun.adliye_davalar where id=t.dava_id;
 if d.durum<>'acik' then raise exception 'Dava kapandi.'; end if;
 yetki:=case when t.taraf='davaci' then (d.davaci=p.id or exists(select 1 from oyun.partiler where id=d.davaci_parti and gb=p.id))
 else (d.davali=p.id or exists(select 1 from oyun.partiler where id=d.davali_parti and gb=p.id)) end;
 if not yetki then raise exception 'Bu davada muvekkil yetkiniz yok.'; end if;
 if p_tutar is null or p_tutar<0 or p_tutar>1000000000000 or p_prim is null or p_prim<0 or p_prim>30 then raise exception 'Karsi teklif gecersiz.'; end if;
 insert into oyun.avukat_pazarlik(teklif_id,muvekkil,tutar,prim)
 values(t.id,p.id,round(p_tutar),p_prim)
 on conflict(teklif_id) do update set muvekkil=excluded.muvekkil,tutar=excluded.tutar,prim=excluded.prim,durum='bekliyor',zaman=now();
 perform oyun.bildir(t.avukat_id,format('Dava #%s icin muvekkil ucret karsi teklifi sundu: %s TL. Avukatlik ekranindan yanitla.',d.id,round(p_tutar)),oyun.simdi());
 return jsonb_build_object('tamam',true);
end $f$;
create or replace function public.avukat_pazarlik_karar(p_teklif bigint,p_kabul boolean) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); t oyun.avukat_teklifleri; z oyun.avukat_pazarlik;
begin
 select * into t from oyun.avukat_teklifleri where id=p_teklif for update;
 if t.id is null or t.durum<>'bekliyor' or t.avukat_id<>p.id then raise exception 'Teklif yanitlama yetkiniz yok.'; end if;
 select * into z from oyun.avukat_pazarlik where teklif_id=p_teklif and durum='bekliyor' for update;
 if z.teklif_id is null then raise exception 'Bekleyen karsi teklif yok.'; end if;
 if not oyun.avukat_mi(p.id) then raise exception 'Avukat ruhsatiniz aktif degil.'; end if;
 update oyun.avukat_pazarlik set durum=case when p_kabul then 'kabul' else 'ret' end where teklif_id=p_teklif;
 if p_kabul then update oyun.avukat_teklifleri set tutar=z.tutar,prim_orani=z.prim where id=p_teklif; end if;
 perform oyun.bildir(z.muvekkil,format('Dava #%s karsi teklifine avukatin yaniti: %s.',t.dava_id,case when p_kabul then 'Kabul, sozlesmeyi onaylayabilirsiniz' else 'Ret' end),oyun.simdi());
 return jsonb_build_object('durum',case when p_kabul then 'kabul' else 'ret' end);
end $f$;
create or replace function public.avukat_pazarlik_liste(p_dava bigint) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 return coalesce((select jsonb_agg(jsonb_build_object('teklif_id',z.teklif_id,'avukat',oyun.kad(t.avukat_id),'muvekkil',oyun.kad(z.muvekkil),'tutar',z.tutar,'prim',z.prim,'durum',z.durum,'avukat_miyim',t.avukat_id=p.id,'muvekkil_miyim',z.muvekkil=p.id) order by z.teklif_id desc)
 from oyun.avukat_pazarlik z join oyun.avukat_teklifleri t on t.id=z.teklif_id
 where t.dava_id=p_dava and (t.avukat_id=p.id or z.muvekkil=p.id)),'[]'::jsonb);
end $f$;
-- Pazarlik yanitlanmadan eski tutarin kabul edilmesi engellenir.
create or replace function oyun.tg_avukat_pazarlik_koruma() returns trigger language plpgsql set search_path='' as $f$
begin
 if exists(select 1 from oyun.avukat_pazarlik where teklif_id=new.teklif_id and durum='bekliyor') then
  raise exception 'Ucret pazarligi suruyor; avukatin karsi teklifi yanitlamasi beklenmeli.';
 end if;
 return new;
end $f$;
drop trigger if exists avukat_pazarlik_koruma on oyun.avukat_vekaletleri;
create trigger avukat_pazarlik_koruma before insert on oyun.avukat_vekaletleri
for each row execute function oyun.tg_avukat_pazarlik_koruma();

-- Tazminat fiilen tahsil edilince muvekkil-avukat arasindaki prim tahsil edilir.
create table if not exists oyun.avukat_prim_kayit(
 id bigserial primary key,
 vekalet_id bigint not null references oyun.avukat_vekaletleri(id),
 dava_id bigint not null references oyun.adliye_davalar(id),
 muvekkil uuid not null references oyun.profiller(id),
 avukat_id uuid not null references oyun.profiller(id),
 matrah numeric not null,
 prim numeric not null,
 odenen numeric not null default 0,
 zaman timestamptz not null default now(),
 check(prim>=0 and odenen>=0 and odenen<=prim)
);
alter table oyun.avukat_prim_kayit enable row level security;
revoke all on oyun.avukat_prim_kayit from public, anon, authenticated;
create or replace function oyun.avukat_prim_aktar(u uuid,a uuid,istenen numeric,p_dava bigint,t timestamptz) returns numeric language plpgsql set search_path='' as $f$
declare var numeric; tutar numeric;
begin
 if u=a or istenen<=0 then return 0; end if;
 perform oyun.cuzdanim(u);
 select para into var from oyun.cuzdan where user_id=u for update;
 tutar:=least(greatest(0,coalesce(var,0)),istenen);
 if tutar>0 then
  perform oyun.para_islem(u,-tutar,'adliye','Dava #'||p_dava||' kazanma primi',t);
  perform oyun.para_islem(a,tutar,'adliye','Dava #'||p_dava||' kazanma primi',t);
 end if;
 return tutar;
end $f$;
create or replace function oyun.tg_avukat_tazminat_prim() returns trigger language plpgsql set search_path='' as $f$
declare v oyun.avukat_vekaletleri; tutar numeric; al numeric;
begin
 if new.tazminat_odenen<=old.tazminat_odenen or not new.kesin or new.durum<>'karar' or new.karar in('beraat','dusme') then return new; end if;
 for v in select * from oyun.avukat_vekaletleri where dava_id=new.id and taraf='davaci' and prim_orani>0
   and tarih<=new.karar_at and (iptal_at is null or iptal_at>=new.karar_at)
 loop
  tutar:=round((new.tazminat_odenen-old.tazminat_odenen)*v.prim_orani/100);
  if tutar>0 then
   al:=oyun.avukat_prim_aktar(v.muvekkil,v.avukat_id,tutar,new.id,oyun.simdi());
   insert into oyun.avukat_prim_kayit(vekalet_id,dava_id,muvekkil,avukat_id,matrah,prim,odenen)
   values(v.id,new.id,v.muvekkil,v.avukat_id,new.tazminat_odenen-old.tazminat_odenen,tutar,al);
  end if;
 end loop;
 return new;
end $f$;
drop trigger if exists avukat_tazminat_prim on oyun.adliye_davalar;
create trigger avukat_tazminat_prim after update of tazminat_odenen on oyun.adliye_davalar
for each row execute function oyun.tg_avukat_tazminat_prim();

create or replace function public.avukat_primlerim() returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim();
begin
 return coalesce((select jsonb_agg(jsonb_build_object('id',k.id,'dava',k.dava_id,'matrah',k.matrah,'prim',k.prim,'odenen',k.odenen,'kalan',k.prim-k.odenen,'muvekkil',oyun.kad(k.muvekkil),'ben_avukatim',k.avukat_id=p.id) order by k.id desc)
 from oyun.avukat_prim_kayit k where k.avukat_id=p.id or k.muvekkil=p.id),'[]'::jsonb);
end $f$;
create or replace function public.avukat_prim_tahsil(p_kayit bigint) returns jsonb language plpgsql security definer set search_path='' as $f$
declare p oyun.profiller:=oyun.profilim(); k oyun.avukat_prim_kayit; al numeric;
begin
 select * into k from oyun.avukat_prim_kayit where id=p_kayit for update;
 if k.id is null or k.avukat_id<>p.id then raise exception 'Prim dosyasi yok veya yetkiniz yok.'; end if;
 al:=oyun.avukat_prim_aktar(k.muvekkil,k.avukat_id,k.prim-k.odenen,k.dava_id,oyun.simdi());
 update oyun.avukat_prim_kayit set odenen=odenen+al where id=k.id;
 return jsonb_build_object('tahsil',al,'kalan',k.prim-k.odenen-al);
end $f$;
do $g$ declare f record; begin
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
 and p.proname in ('avukat_iller','avukat_buro_davetler','avukat_karsi_teklif','avukat_pazarlik_karar','avukat_pazarlik_liste','avukat_primlerim','avukat_prim_tahsil')
 loop execute format('revoke all on function %s from public, anon; grant execute on function %s to authenticated',f.sig,f.sig); end loop;
end $g$;
