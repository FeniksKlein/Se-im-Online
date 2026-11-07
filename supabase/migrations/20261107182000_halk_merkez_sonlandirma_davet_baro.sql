-- Halk hareketleri komuta merkezi; canli veritabaninda uygulanmis degisikliklerin kaynak eslemesi.
-- Mevcut kayitlar ve oyuncu bakiyeleri korunur. Yalniz authenticated rolunun isleme yetkisi vardir.
alter table oyun.sokak_eylem add column if not exists kapanma_nedeni text;
alter table oyun.sokak_davet drop constraint if exists sokak_davet_durum_check;
alter table oyun.sokak_davet add constraint sokak_davet_durum_check check (durum in ('bekliyor','kabul','ret','cekimser'));
create table if not exists oyun.sokak_baro_talep (
 id bigint generated always as identity primary key,
 gozalti_id bigint not null unique references oyun.sokak_gozalti(id),
 talep_eden uuid not null references oyun.profiller(id),
 durum text not null default 'bekliyor' check (durum in ('bekliyor','gorevlendirildi','iptal')),
 avukat uuid references oyun.profiller(id),
 gorevlendiren uuid references oyun.profiller(id),
 basvuru timestamptz not null default now(),
 karar_zamani timestamptz,
 gerekce text
);
create index if not exists sokak_baro_talep_durum on oyun.sokak_baro_talep(durum,basvuru desc);
alter table oyun.sokak_baro_talep enable row level security;
revoke all on oyun.sokak_baro_talep from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sokak_baro_ata(p_gozalti bigint, p_avukat uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti; bt oyun.sokak_baro_talep;
begin
 if u is null or u is distinct from oyun.baro_baskan() then raise exception 'Yalniz baro baskani mudafi atayabilir';end if;
 if p_avukat is null then raise exception 'Avukat secin';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 select * into bt from oyun.sokak_baro_talep where gozalti_id=p_gozalti for update;
 if bt.id is null or bt.durum<>'bekliyor' then raise exception 'Bekleyen baro talebi bulunamadi';end if;
 if g.durum<>'aktif' or g.bitis<=oyun.simdi() then raise exception 'Gozalti sona ermis';end if;
 if p_avukat=g.hedef or not exists(select 1 from oyun.avukat_ruhsat where user_id=p_avukat and durum='aktif')
 or not exists(select 1 from oyun.baro_uyeleri where user_id=p_avukat and durum='aktif') then
 raise exception 'Baroda kayitli ve ruhsati aktif baska bir avukat secin';end if;
 if g.avukat_durum='kabul' then raise exception 'Dosyanin avukati zaten mevcut';end if;
 update oyun.sokak_baro_talep set durum='gorevlendirildi',avukat=p_avukat,
 gorevlendiren=u,karar_zamani=oyun.simdi() where id=bt.id;
 update oyun.sokak_gozalti set avukat=p_avukat,avukat_durum='cagrildi' where id=p_gozalti;
 perform oyun.bildir(p_avukat,'Baro sizi gozalti #'||p_gozalti||' icin mudafi olarak atadi. Kabul / ret yaniti verin.');
 perform oyun.bildir(g.hedef,'Baro gozalti #'||p_gozalti||' icin avukat gorevlendirdi. Avukatin yaniti bekleniyor.');
 return jsonb_build_object('tamam',true,'durum','gorevlendirildi');
end $function$


CREATE OR REPLACE FUNCTION public.sokak_baro_iste(p_gozalti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti; bas uuid;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.hedef is distinct from u then raise exception 'Yalniz kendi gozalti kaydiniz icin talep yapabilirsiniz';end if;
 if g.durum<>'aktif' or g.bitis<=oyun.simdi() then raise exception 'Aktif gozalti yok';end if;
 if g.avukat_durum='kabul' then raise exception 'Zaten kabul etmis bir avukatiniz var';end if;
 if exists(select 1 from oyun.sokak_baro_talep where gozalti_id=p_gozalti and durum='bekliyor') then raise exception 'Baro talebiniz beklemede';end if;
 bas:=oyun.baro_baskan();
 if bas is null then raise exception 'Baroda gorevlendirme yapabilecek yetkili bulunamadi';end if;
 insert into oyun.sokak_baro_talep(gozalti_id,talep_eden,durum,basvuru,avukat,gorevlendiren,karar_zamani)
 values(p_gozalti,u,'bekliyor',oyun.simdi(),null,null,null)
 on conflict (gozalti_id) do update set durum='bekliyor',talep_eden=u,basvuru=excluded.basvuru,
 avukat=null,gorevlendiren=null,karar_zamani=null,gerekce=null;
 perform oyun.bildir(bas,'Gozalti #'||p_gozalti||': barodan mudafi talep edildi. Halk Hareketleri / Hukuk bolumunden gorevlendirin.');
 return jsonb_build_object('tamam',true,'durum','bekliyor');
end $function$


CREATE OR REPLACE FUNCTION public.sokak_davet_karar(p_davet bigint, p_karar text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); v oyun.sokak_davet; x oyun.sokak_eylem; lider uuid;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_karar not in ('kabul','ret','cekimser') or p_karar is null then raise exception 'Gecersiz davet yaniti';end if;
 if p_karar in ('kabul','ret') then return public.sokak_davet_yanit(p_davet,p_karar='kabul');end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into v from oyun.sokak_davet where id=p_davet for update;
 if v.id is null or v.durum<>'bekliyor' then raise exception 'Bekleyen davet yok';end if;
 if v.hedef_tur='parti' then select gb into lider from oyun.partiler where id=v.hedef_id and not kapali;
 else select baskan into lider from oyun.dernekler where id=v.hedef_id and not kapali;end if;
 if lider is distinct from u then raise exception 'Yalniz kurulusun lideri yanitlayabilir';end if;
 select * into x from oyun.sokak_eylem where id=v.eylem_id for update;
 if x.durum<>'aktif' or x.bitis<=oyun.simdi() then raise exception 'Eylem sona ermis';end if;
 update oyun.sokak_davet set durum='cekimser',cevap_zamani=oyun.simdi() where id=p_davet;
 perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' davetine bir kurulus cekimser yanit verdi.');
 return jsonb_build_object('tamam',true,'karar','cekimser');
end $function$


CREATE OR REPLACE FUNCTION public.sokak_eylem_sonlandir(p_eylem bigint, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if length(btrim(coalesce(p_gerekce,''))) not between 15 and 500 then
  raise exception 'Sonlandirma gerekcesi 15-500 karakter olmalidir';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.baslatan is distinct from u then raise exception 'Yalniz eylemi baslatan oyuncu sonlandirabilir';end if;
 if x.durum<>'aktif' or x.bitis<=t then raise exception 'Eylem artik aktif degil';end if;
 update oyun.sokak_eylem set durum='bitti',bitis=t,kapandi=t,
  seviye=0,kirmizi_baslangic=null,kapanma_nedeni=btrim(p_gerekce)
 where id=p_eylem;
 insert into oyun.sokak_aciklama(eylem_id,yapan,taraf,metin,zaman)
 values(p_eylem,u,'muhalefet','Organizator eylemi sonlandirdi: '||btrim(p_gerekce),t);
 if (select count(*) from oyun.sokak_eylem where durum='aktif' and bitis>t and kirmizi_baslangic is not null)<3 then
  update oyun.sokak_kriz set kirmizi_baslangic=null where id=1;
 end if;
 perform oyun.sokak_duyur(p_eylem,'Eylem #'||p_eylem||' organizator karariyla sona erdi: '||left(btrim(p_gerekce),300));
 return jsonb_build_object('tamam',true,'eylem_id',p_eylem,'durum','bitti');
end $function$


CREATE OR REPLACE FUNCTION public.sokak_merkez_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); b jsonb; o jsonb; arr jsonb;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 b:=public.sokak_ek_panel();
 o:=public.sokak_org_panel();
 select coalesce(jsonb_agg(x||jsonb_build_object(
 'katildim',exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=(x->>'id')::bigint and d.destekci_tur='oyuncu' and d.destekci_id=u::text and d.destek_turu='katilim' and d.taraf='muhalefet'),
 'kapanma_nedeni',(select e.kapanma_nedeni from oyun.sokak_eylem e where e.id=(x->>'id')::bigint),
 'davet_ozeti',coalesce((select jsonb_agg(jsonb_build_object('kurulus',case when v.hedef_tur='parti' then (select ad from oyun.partiler where id=v.hedef_id) else (select ad from oyun.dernekler where id=v.hedef_id) end,'durum',v.durum,'cevap_zamani',v.cevap_zamani)) from oyun.sokak_davet v where v.eylem_id=(x->>'id')::bigint),'[]'::jsonb)
 )), '[]'::jsonb) into arr from jsonb_array_elements(b->'eylemler')x;
 return b||jsonb_build_object(
  'eylemler',arr,
  'baslatma_kaynaklari',coalesce(o->'baslatma_kaynaklari','[]'::jsonb),
  'davet_hedefleri',coalesce(o->'davet_hedefleri','[]'::jsonb),
  'davetler',coalesce(o->'davetler','[]'::jsonb),
  'baro_baskani',u=oyun.baro_baskan(),
  'baro_avukatlar',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'ad',p.kad) order by p.kad)
     from oyun.baro_uyeleri bu join oyun.profiller p on p.id=bu.user_id
     join oyun.avukat_ruhsat ar on ar.user_id=p.id
     where bu.durum='aktif' and ar.durum='aktif' and not p.yasakli),'[]'::jsonb),
  'baro_talepleri',coalesce((select jsonb_agg(jsonb_build_object(
     'id',bt.id,'gozalti_id',bt.gozalti_id,'eylem_id',g.eylem_id,
     'hedef',oyun.kad(g.hedef),'durum',bt.durum,'basvuru',bt.basvuru,
     'avukat',oyun.kad(bt.avukat)) order by bt.basvuru desc)
     from oyun.sokak_baro_talep bt join oyun.sokak_gozalti g on g.id=bt.gozalti_id
     where (bt.talep_eden=u or u=oyun.baro_baskan() or bt.avukat=u) and bt.basvuru>oyun.simdi()-interval '7 days'),'[]'::jsonb)
 );
end $function$


revoke all on function
 public.sokak_eylem_sonlandir(bigint,text),
 public.sokak_davet_karar(bigint,text),
 public.sokak_baro_iste(bigint),
 public.sokak_baro_ata(bigint,uuid),
 public.sokak_merkez_panel()
 from public,anon,authenticated;
grant execute on function
 public.sokak_eylem_sonlandir(bigint,text),
 public.sokak_davet_karar(bigint,text),
 public.sokak_baro_iste(bigint),
 public.sokak_baro_ata(bigint,uuid),
 public.sokak_merkez_panel()
 to authenticated;
