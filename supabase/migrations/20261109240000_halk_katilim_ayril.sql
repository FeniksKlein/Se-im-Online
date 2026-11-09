-- Oyuncu kendi katılımını istediği an bitirir. Ödenen bedel ve süre geri gelmez.
-- Canlı fonksiyon gövdesine yama yok. İkinci kez çalıştırılabilir.
-- Canlı veritabanına bu dosyayla uygulanmaz.

create table if not exists oyun.sokak_hamle_kisi(
 hamle_id bigint not null references oyun.sokak_hamle, user_id uuid not null,
 primary key(hamle_id,user_id)
);
create table if not exists oyun.sokak_geri_bekle(
 eylem_id bigint not null, user_id uuid not null, tur text not null, bitis timestamptz not null,
 primary key(eylem_id,user_id,tur)
);
alter table oyun.sokak_hamle_kisi enable row level security;
alter table oyun.sokak_geri_bekle enable row level security;
revoke all on oyun.sokak_hamle_kisi,oyun.sokak_geri_bekle from public,anon,authenticated;

do $$ begin
 alter table oyun.sokak_sizma drop constraint if exists sokak_sizma_durum_check;
 alter table oyun.sokak_sizma add constraint sokak_sizma_durum_check check(durum in ('aktif','ifsa','ayrildi'));
end $$;

create or replace function oyun.sokak_geri_yaz(e bigint, u uuid, k text) returns void
language sql set search_path='' as $$
 insert into oyun.sokak_geri_bekle(eylem_id,user_id,tur,bitis)
 values(e,u,k,oyun.simdi()+interval '15 minutes')
 on conflict(eylem_id,user_id,tur) do update set bitis=excluded.bitis
$$;
create or replace function oyun.sokak_geri_var(e bigint, u uuid, k text) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_geri_bekle b where b.eylem_id=e and b.user_id=u and b.tur=k and b.bitis>oyun.simdi())
$$;

create or replace function oyun.sokak_hamle_kisi_yaz() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.tur in ('grev','yol','vergi') then
  insert into oyun.sokak_hamle_kisi(hamle_id,user_id) values(new.id,new.yapan) on conflict do nothing;
  update oyun.sokak_hamle set etki=etki||jsonb_build_object('kisi',true) where id=new.id;
 end if;
 return new;
end $$;

create or replace function oyun.sokak_geri_bekle_engel() returns trigger
language plpgsql set search_path='' as $$
declare e bigint; u uuid; k text;
begin
 if tg_table_name='sokak_vardiya' then
  select eylem_id into e from oyun.sokak_isgal where id=new.isgal_id;
  u:=new.user_id; k:=new.taraf;
 elsif tg_table_name='sokak_tahliye_katilim' then
  select i.eylem_id into e from oyun.sokak_tahliye q join oyun.sokak_isgal i on i.id=q.isgal_id where q.id=new.tahliye_id;
  u:=new.user_id; k:='tahliye_'||new.taraf;
 elsif tg_table_name='sokak_hamle_kisi' then
  select h.eylem_id,h.tur into e,k from oyun.sokak_hamle h where h.id=new.hamle_id;
  u:=new.user_id;
 else
  e:=new.eylem_id; u:=new.user_id; k:=tg_argv[0];
 end if;
 if e is not null and oyun.sokak_geri_var(e,u,k) then
  raise exception 'Yeni ayrıldın. Aynı katılıma dönmek için kısa bir süre bekle.';
 end if;
 return new;
end $$;

-- Kişi listesi olan grev, yol ve vergi yalnız hâlâ yazılan varsa keser.
-- Eski kayıtta kişi listesi yoksa kesinti eskisi gibi sürer.
create or replace function oyun.sokak_il_gelir_kirp() returns trigger
language plpgsql set search_path='' as $$
declare kes numeric:=0; t timestamptz:=oyun.simdi(); r record; var boolean;
begin
 if new.kasa is null or old.kasa is null or new.kasa<=old.kasa then return new; end if;
 for r in select h.id,h.tur,h.etki from oyun.sokak_hamle h join oyun.sokak_eylem e on e.id=h.eylem_id
           where e.il_id=new.il_id and e.durum='aktif' and h.durum='aktif' and h.bitis>t and h.tur in ('grev','yol','vergi') loop
  var:=exists(select 1 from oyun.sokak_hamle_kisi k where k.hamle_id=r.id);
  if not (r.etki ? 'kisi') or var then
   kes:=kes+case r.tur when 'grev' then 0.40 when 'yol' then 0.20 else 0.25 end;
  end if;
 end loop;
 if kes>0.70 then kes:=0.70; end if;
 if kes>0 then new.kasa:=old.kasa+(new.kasa-old.kasa)*(1-kes); end if;
 return new;
end $$;

create or replace function oyun.sokak_isgal_denet(iid bigint) returns void
language plpgsql set search_path='' as $$
declare t timestamptz:=oyun.simdi(); r oyun.sokak_isgal; n int; nobet int; gerek int;
begin
 select * into r from oyun.sokak_isgal where id=iid and durum='aktif' for update;
 if r.id is null then return; end if;
 select count(*) into nobet from oyun.sokak_vardiya v where v.isgal_id=r.id and v.taraf='isgal' and v.bitis>t;
 select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=r.eylem_id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
 gerek:=greatest(2, ceil(coalesce(n,0)/5.0));
 if nobet<gerek and r.bas<=t-interval '15 minutes' then
  update oyun.sokak_isgal set durum='coktu', bitis=t where id=r.id;
  update oyun.sokak_hamle set durum='coktu', bitis=t where eylem_id=r.eylem_id and tur='isgal' and durum='aktif';
  perform oyun.sokak_duyur(r.eylem_id,'Bina nöbeti seyrelince sembolik işgal kendiliğinden dağıldı.');
 end if;
end $$;

create or replace function public.sokak_hamle_kisi_katil(p_eylem bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); hid bigint; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_tur not in ('grev','yol','vergi') then raise exception 'Bu hamleye tek tek yazılınmaz'; end if;
 if not oyun.sokak_katilimci(p_eylem,u) then raise exception 'Önce eyleme katıl'; end if;
 if oyun.sokak_geri_var(p_eylem,u,p_tur) then raise exception 'Yeni ayrıldın. Aynı katılıma dönmek için kısa bir süre bekle.'; end if;
 select id into hid from oyun.sokak_hamle where eylem_id=p_eylem and tur=p_tur and durum='aktif' and bitis>t order by id desc limit 1;
 if hid is null then raise exception 'Süregelen hamle yok'; end if;
 insert into oyun.sokak_hamle_kisi(hamle_id,user_id) values(hid,u) on conflict do nothing;
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.sokak_katilim_liste(p_eylem bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); arr jsonb:= '[]'::jsonb; x oyun.sokak_eylem;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if x.id is null then return jsonb_build_object('tamam',true,'ben','[]'::jsonb); end if;
 if exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destekci_id=u::text and d.destek_turu='katilim') then
  arr:=arr||jsonb_build_array(jsonb_build_object('tur','eylem','ad','Eylem katılımı'));
 end if;
 if exists(select 1 from oyun.sokak_gorevli g where g.eylem_id=x.id and g.user_id=u and g.ayrilma is null) then
  arr:=arr||jsonb_build_array(jsonb_build_object('tur','gorev','ad','Sahadaki görev'));
 end if;
 if exists(select 1 from oyun.sokak_aclik a where a.eylem_id=x.id and a.user_id=u and a.bitis>t) then
  arr:=arr||jsonb_build_array(jsonb_build_object('tur','aclik','ad','Açlık grevi'));
 end if;
 if exists(select 1 from oyun.sokak_isik i where i.eylem_id=x.id and i.user_id=u and i.gun=(t at time zone 'Europe/Istanbul')::date) then
  arr:=arr||jsonb_build_array(jsonb_build_object('tur','mesale','ad','Gece meşalesi'));
 end if;
 if exists(select 1 from oyun.sokak_sizma s where s.eylem_id=x.id and s.user_id=u and s.durum='aktif') then
  arr:=arr||jsonb_build_array(jsonb_build_object('tur','sizma','ad','İçeriden sızma'));
 end if;
 if exists(select 1 from oyun.sokak_nobet_rota r where r.eylem_id=x.id and r.user_id=u and r.gun>=(t at time zone 'Europe/Istanbul')::date) then
  arr:=arr||jsonb_build_array(jsonb_build_object('tur','rota','ad','Şafak nöbet listesi'));
 end if;
 arr:=arr||coalesce((select jsonb_agg(jsonb_build_object('tur','taktik','alt',k.tur,'ad',case k.tur when 'nobet' then 'Nöbet taktiği' when 'grev' then 'Greve katılım' when 'pankart' then 'Pankart' when 'duran' then 'Oturma taktiği' when 'barikat' then 'Barikat' else k.tur end))
  from oyun.sokak_taktik k where k.eylem_id=x.id and k.user_id=u and k.bitis>t and k.tur in ('nobet','grev','pankart','duran','barikat')),'[]'::jsonb);
 arr:=arr||coalesce((select jsonb_agg(jsonb_build_object('tur',v.taraf,'ad',case v.taraf when 'isgal' then 'Bina nöbeti' when 'kusatma' then 'Kuşatma nöbeti' else 'Dayanışma ziyareti' end))
  from oyun.sokak_vardiya v join oyun.sokak_isgal i on i.id=v.isgal_id
  where i.eylem_id=x.id and v.user_id=u and v.bitis>t),'[]'::jsonb);
 arr:=arr||coalesce((select jsonb_agg(jsonb_build_object('tur','tahliye_'||k.taraf,'ad',case k.taraf when 'hukumet' then 'Operasyona katılım' else 'Binayı savunma' end))
  from oyun.sokak_tahliye_katilim k join oyun.sokak_tahliye q on q.id=k.tahliye_id join oyun.sokak_isgal i on i.id=q.isgal_id
  where i.eylem_id=x.id and k.user_id=u and q.durum='geri_sayim' and q.bitis>t),'[]'::jsonb);
 arr:=arr||coalesce((select jsonb_agg(jsonb_build_object('tur',h.tur,'ad',oyun.sokak_hamle_ad(h.tur)))
  from oyun.sokak_hamle_kisi k join oyun.sokak_hamle h on h.id=k.hamle_id
  where h.eylem_id=x.id and k.user_id=u and h.durum='aktif' and h.bitis>t),'[]'::jsonb);
 return jsonb_build_object('tamam',true,'ben',arr);
end $$;

create or replace function public.sokak_katilim_ayril(p_eylem bigint, p_tur text, p_alt text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n int; iid bigint; qid bigint; hid bigint; isik_gun date;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_tur is null or p_tur='' then raise exception 'Hangi katılımdan ayrıldığın seçilmeli'; end if;
 perform pg_advisory_xact_lock(781231,1);
 if p_tur='eylem' then
  return public.sokak_eylemden_ayril(p_eylem);
 elsif p_tur='gorev' then
  return public.sokak_gorevden_ayril(p_eylem);
 elsif p_tur='aclik' then
  delete from oyun.sokak_aclik where eylem_id=p_eylem and user_id=u and bitis>t;
  get diagnostics n=row_count;
  if n=0 then raise exception 'Açlık grevinde değilsin'; end if;
  perform oyun.sokak_geri_yaz(p_eylem,u,'aclik');
 elsif p_tur='mesale' then
  isik_gun:=(t at time zone 'Europe/Istanbul')::date;
  delete from oyun.sokak_isik q where q.eylem_id=p_eylem and q.user_id=u and q.gun=isik_gun;
  get diagnostics n=row_count;
  if n=0 then raise exception 'Bu gece yaktığın ışık yok'; end if;
  delete from oyun.sokak_meydan_etki where eylem_id=p_eylem and tur='mesale' and bitis>t;
  select count(*) into n from oyun.sokak_isik q where q.eylem_id=p_eylem and q.gun=isik_gun;
  if n>=3 then insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(p_eylem,'mesale',least(12,n*2),t+interval '6 hours'); end if;
  perform oyun.sokak_geri_yaz(p_eylem,u,'mesale');
 elsif p_tur='sizma' then
  update oyun.sokak_sizma set durum='ayrildi' where eylem_id=p_eylem and user_id=u and durum='aktif';
  get diagnostics n=row_count;
  if n=0 then raise exception 'Aktif sızma rolün yok'; end if;
  perform oyun.sokak_geri_yaz(p_eylem,u,'sizma');
 elsif p_tur='rota' then
  delete from oyun.sokak_nobet_rota r where r.eylem_id=p_eylem and r.user_id=u and r.gun>=(t at time zone 'Europe/Istanbul')::date;
  get diagnostics n=row_count;
  if n=0 then raise exception 'Nöbet listesinde değilsin'; end if;
  perform oyun.sokak_geri_yaz(p_eylem,u,'rota');
 elsif p_tur='taktik' then
  if coalesce(p_alt,'') not in ('nobet','grev','pankart','duran','barikat') then raise exception 'Taktik seçilmeli'; end if;
  update oyun.sokak_taktik set bitis=t where eylem_id=p_eylem and user_id=u and tur=p_alt and bitis>t;
  get diagnostics n=row_count;
  if n=0 then raise exception 'Süregelen taktiğin yok'; end if;
 elsif p_tur in ('isgal','kusatma','ziyaret') then
  select v.isgal_id into iid from oyun.sokak_vardiya v join oyun.sokak_isgal i on i.id=v.isgal_id
   where i.eylem_id=p_eylem and v.user_id=u and v.taraf=p_tur and v.bitis>t order by v.bitis desc limit 1;
  if iid is null then raise exception 'Bu nöbette değilsin'; end if;
  update oyun.sokak_vardiya set bitis=t where isgal_id=iid and user_id=u and taraf=p_tur and bitis>t;
  update oyun.sokak_isgal set guc=greatest(0,guc-case p_tur when 'ziyaret' then 3 when 'isgal' then 1 else 0 end) where id=iid;
  perform oyun.sokak_geri_yaz(p_eylem,u,p_tur);
  perform oyun.sokak_isgal_denet(iid);
 elsif p_tur in ('tahliye_hukumet','tahliye_savun') then
  select q.id into qid from oyun.sokak_tahliye q join oyun.sokak_isgal i on i.id=q.isgal_id
   join oyun.sokak_tahliye_katilim k on k.tahliye_id=q.id
   where i.eylem_id=p_eylem and k.user_id=u and k.taraf=case p_tur when 'tahliye_hukumet' then 'hukumet' else 'savun' end
     and q.durum='geri_sayim' and q.bitis>t limit 1;
  if qid is null then raise exception 'Bu sayımda yerin yok'; end if;
  delete from oyun.sokak_tahliye_katilim where tahliye_id=qid and user_id=u;
  perform oyun.sokak_geri_yaz(p_eylem,u,p_tur);
 elsif p_tur in ('grev','yol','vergi') then
  select h.id into hid from oyun.sokak_hamle h join oyun.sokak_hamle_kisi k on k.hamle_id=h.id
   where h.eylem_id=p_eylem and h.tur=p_tur and h.durum='aktif' and h.bitis>t and k.user_id=u limit 1;
  if hid is null then raise exception 'Bu hamlede kişisel yerin yok'; end if;
  delete from oyun.sokak_hamle_kisi where hamle_id=hid and user_id=u;
  perform oyun.sokak_geri_yaz(p_eylem,u,p_tur);
 else raise exception 'Bu katılımdan ayrılma tanımlı değil'; end if;
 return jsonb_build_object('tamam',true,'tur',p_tur);
end $$;

drop trigger if exists sokak_hamle_kisi_yaz on oyun.sokak_hamle;
create trigger sokak_hamle_kisi_yaz after insert on oyun.sokak_hamle
 for each row execute function oyun.sokak_hamle_kisi_yaz();

drop trigger if exists sokak_aclik_geri on oyun.sokak_aclik;
create trigger sokak_aclik_geri before insert on oyun.sokak_aclik
 for each row execute function oyun.sokak_geri_bekle_engel('aclik');
drop trigger if exists sokak_isik_geri on oyun.sokak_isik;
create trigger sokak_isik_geri before insert on oyun.sokak_isik
 for each row execute function oyun.sokak_geri_bekle_engel('mesale');
drop trigger if exists sokak_sizma_geri on oyun.sokak_sizma;
create trigger sokak_sizma_geri before insert on oyun.sokak_sizma
 for each row execute function oyun.sokak_geri_bekle_engel('sizma');
drop trigger if exists sokak_rota_geri on oyun.sokak_nobet_rota;
create trigger sokak_rota_geri before insert on oyun.sokak_nobet_rota
 for each row execute function oyun.sokak_geri_bekle_engel('rota');
drop trigger if exists sokak_vardiya_geri on oyun.sokak_vardiya;
create trigger sokak_vardiya_geri before insert on oyun.sokak_vardiya
 for each row execute function oyun.sokak_geri_bekle_engel('');
drop trigger if exists sokak_tahliye_geri on oyun.sokak_tahliye_katilim;
create trigger sokak_tahliye_geri before insert on oyun.sokak_tahliye_katilim
 for each row execute function oyun.sokak_geri_bekle_engel('');
drop trigger if exists sokak_hamle_kisi_geri on oyun.sokak_hamle_kisi;
create trigger sokak_hamle_kisi_geri before insert on oyun.sokak_hamle_kisi
 for each row execute function oyun.sokak_geri_bekle_engel('');

revoke all on function oyun.sokak_geri_yaz(bigint,uuid,text),oyun.sokak_geri_var(bigint,uuid,text),
 oyun.sokak_hamle_kisi_yaz(),oyun.sokak_geri_bekle_engel(),oyun.sokak_il_gelir_kirp(),oyun.sokak_isgal_denet(bigint),
 public.sokak_hamle_kisi_katil(bigint,text),public.sokak_katilim_liste(bigint),public.sokak_katilim_ayril(bigint,text,text)
 from public,anon,authenticated;
grant execute on function public.sokak_hamle_kisi_katil(bigint,text),public.sokak_katilim_liste(bigint),public.sokak_katilim_ayril(bigint,text,text) to authenticated;
