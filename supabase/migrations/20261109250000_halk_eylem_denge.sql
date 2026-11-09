-- Eylemi büyütmek ve keyfi açmak zorlaşır. Sayılar tek ayar satırındadır.
-- sokak_eylem_baslat ve sokak_org_baslat gövdesine dokunulmaz.
-- Çağrı eşiği dolunca mevcut sokak_org_baslat çağrılır.
-- İkinci kez çalıştırılabilir. Canlıya bu dosyayla uygulanmaz.

create table if not exists oyun.sokak_denge_ayar(
 id integer primary key check(id=1),
 memnuniyet_esik numeric not null default 55,
 memnuniyetsizlik_esik numeric not null default 40,
 olay_saat integer not null default 12,
 hesap_gun integer not null default 7,
 aktif_gun integer not null default 3,
 depozito numeric not null default 50000,
 imza_sayisi integer not null default 4,
 imza_saat integer not null default 6,
 imza_hesap_gun integer not null default 3,
 il_bekleme_saat integer not null default 24,
 orgut_bekleme_saat integer not null default 48,
 ulke_taban integer not null default 2,
 ulke_bolen integer not null default 15,
 saatlik_yuzde numeric not null default 12,
 katilim_egri numeric not null default 8,
 ivme_baslangic numeric not null default 20,
 ivme_akilli numeric not null default 12,
 ivme_zayif numeric not null default -6,
 ivme_tekrar numeric not null default -10,
 ivme_decay_saat numeric not null default 4,
 yorgunluk_saat numeric not null default 8,
 buyuk_ivme numeric not null default 35,
 buyuk_katilim integer not null default 8,
 buyuk_nabiz numeric not null default 45,
 uluslararasi_nabiz numeric not null default 55,
 mesale_hukumet_saat integer not null default 12,
 grev_katilim integer not null default 8,
 nufus_oran numeric not null default 0.35,
 nufus_taban integer not null default 6,
 tekrar_saat integer not null default 6,
 yanit_saat integer not null default 6,
 sohbet_kisi integer not null default 3,
 sohbet_saat integer not null default 2
);
insert into oyun.sokak_denge_ayar(id) values(1) on conflict(id) do nothing;
alter table oyun.sokak_denge_ayar enable row level security;
revoke all on oyun.sokak_denge_ayar from public,anon,authenticated;

create table if not exists oyun.sokak_cagri(
 id bigint generated always as identity primary key,
 il_id integer not null, acan uuid not null, kaynak text not null, kaynak_id bigint not null,
 talep text not null default 'genel', gerekce text not null, depozito numeric not null,
 durum text not null default 'imza' check(durum in ('imza','hazir','acildi','dustu')),
 eylem_id bigint, acilis timestamptz not null, bitis timestamptz not null, hata text
);
create table if not exists oyun.sokak_cagri_imza(
 cagri_id bigint not null references oyun.sokak_cagri, user_id uuid not null, zaman timestamptz not null,
 primary key(cagri_id,user_id)
);
create table if not exists oyun.sokak_ivme(
 eylem_id bigint primary key, ivme numeric not null default 20, yorgunluk numeric not null default 0,
 son timestamptz not null, son_akilli timestamptz not null, son_seviye numeric not null default 0,
 son_seviye_zaman timestamptz not null, son_tur text, son_tur_zaman timestamptz, son_not text
);
alter table oyun.sokak_cagri enable row level security;
alter table oyun.sokak_cagri_imza enable row level security;
alter table oyun.sokak_ivme enable row level security;
revoke all on oyun.sokak_cagri,oyun.sokak_cagri_imza,oyun.sokak_ivme from public,anon,authenticated;

create or replace function oyun.sokak_denge() returns oyun.sokak_denge_ayar
language sql stable set search_path='' as $$
 select * from oyun.sokak_denge_ayar where id=1
$$;

create or replace function oyun.sokak_aktif_sayi(p_il integer default null) returns integer
language sql stable set search_path='' as $$
 select count(*)::int from oyun.profiller p
  where not p.yasakli and p.son_gorulme>oyun.simdi()-interval '7 days'
    and (p_il is null or p.il_id=p_il)
$$;

create or replace function oyun.sokak_ulke_tavan() returns integer
language sql stable set search_path='' as $$
 select greatest(a.ulke_taban, ceil(oyun.sokak_aktif_sayi(null)::numeric/greatest(a.ulke_bolen,1)))::int
 from oyun.sokak_denge_ayar a where a.id=1
$$;

create or replace function oyun.sokak_il_tavan(p_il integer) returns integer
language sql stable set search_path='' as $$
 select greatest(a.nufus_taban, ceil(oyun.sokak_aktif_sayi(p_il)*a.nufus_oran))::int
 from oyun.sokak_denge_ayar a where a.id=1
$$;

create or replace function oyun.sokak_hukumet_yakin(e bigint, saat integer) returns boolean
language plpgsql stable set search_path='' as $$
declare t timestamptz:=oyun.simdi()-make_interval(hours=>saat); var boolean:=false;
begin
 if to_regclass('oyun.sokak_sert') is not null then
  execute 'select exists(select 1 from oyun.sokak_sert where eylem_id=$1 and zaman>$2)' into var using e,t;
  if var then return true; end if;
 end if;
 if to_regclass('oyun.sokak_tedbir') is not null then
  execute 'select exists(select 1 from oyun.sokak_tedbir where eylem_id=$1 and zaman>$2)' into var using e,t;
  if var then return true; end if;
 end if;
 if to_regclass('oyun.sokak_karar') is not null then
  execute 'select exists(select 1 from oyun.sokak_karar where eylem_id=$1 and zaman>$2)' into var using e,t;
  if var then return true; end if;
 end if;
 return false;
end $$;

create or replace function oyun.sokak_sikayet_var(p_il integer) returns boolean
language plpgsql stable set search_path='' as $$
declare a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi(); mem numeric; nabiz numeric; var boolean:=false;
begin
 select memnuniyet into mem from oyun.il_durum where il_id=p_il;
 nabiz:=oyun.sokak_memnuniyetsizlik(p_il);
 if coalesce(mem,50)<a.memnuniyet_esik or coalesce(nabiz,0)>=a.memnuniyetsizlik_esik then return true; end if;
 if to_regclass('oyun.sokak_eylem') is not null and to_regclass('oyun.sokak_sert') is not null then
  execute 'select exists(select 1 from oyun.sokak_sert s join oyun.sokak_eylem e on e.id=s.eylem_id where e.il_id=$1 and s.zaman>$2)' into var using p_il, t-make_interval(hours=>a.olay_saat);
  if var then return true; end if;
 end if;
 if to_regclass('oyun.sokak_manset') is not null then
  execute 'select exists(select 1 from oyun.sokak_manset where zaman>$1)' into var using t-make_interval(hours=>a.olay_saat);
  if var then return true; end if;
 end if;
 return false;
end $$;

create or replace function oyun.sokak_cagri_dustur() returns void
language plpgsql set search_path='' as $$
begin
 update oyun.sokak_cagri set durum='dustu', hata='İmza süresi doldu. Depozito yanar.'
  where durum in ('imza','hazir') and bitis<=oyun.simdi();
end $$;

create or replace function oyun.sokak_kurulus_ode(kaynak text, kid bigint, tutar numeric, aciklama text) returns void
language plpgsql set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
 if kaynak='dernek' then
  update oyun.dernekler set kasa=kasa-tutar where id=kid and kasa>=tutar;
  if not found then raise exception 'Dernek kasası depozito için yetersiz'; end if;
  insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id) values(kid,t,-tutar,'gider',aciklama,u);
 else
  update oyun.partiler set kasa=kasa-tutar where id=kid and kasa>=tutar;
  if not found then raise exception 'Parti kasası depozito için yetersiz'; end if;
  insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(kid,t,-tutar,'gider',aciklama);
 end if;
end $$;

create or replace function oyun.sokak_ivme_satir(e bigint) returns oyun.sokak_ivme
language plpgsql set search_path='' as $$
declare r oyun.sokak_ivme; a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi();
begin
 insert into oyun.sokak_ivme(eylem_id,ivme,yorgunluk,son,son_akilli,son_seviye,son_seviye_zaman)
 values(e,a.ivme_baslangic,0,t,t,0,t) on conflict(eylem_id) do nothing;
 select * into r from oyun.sokak_ivme where eylem_id=e for update;
 return r;
end $$;

create or replace function oyun.sokak_ivme_uygula(e bigint, tur text, puan numeric) returns numeric
language plpgsql set search_path='' as $$
declare a oyun.sokak_denge_ayar:=oyun.sokak_denge(); r oyun.sokak_ivme; t timestamptz:=oyun.simdi();
 saat numeric; n int; nabiz numeric; akilli boolean:=false; delta numeric:=0; notu text; sohbet int:=0; tekrar boolean:=false;
begin
 if puan is null or puan<=0 then return puan; end if;
 r:=oyun.sokak_ivme_satir(e);
 saat:=extract(epoch from (t-r.son))/3600;
 if saat<0 then saat:=0; end if;
 r.ivme:=greatest(0, least(100, r.ivme - a.ivme_decay_saat*saat));
 if r.son_akilli<t-interval '1 hour' then
  r.yorgunluk:=least(100, r.yorgunluk + a.yorgunluk_saat*saat);
 end if;
 select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=e and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
 nabiz:=oyun.sokak_memnuniyetsizlik((select il_id from oyun.sokak_eylem where id=e));
 tekrar:=r.son_tur=tur and r.son_tur_zaman>t-make_interval(hours=>a.tekrar_saat);
 if to_regclass('public.sokak_eylem_sohbet') is not null then
  execute 'select count(distinct user_id) from public.sokak_eylem_sohbet where eylem_id=$1 and zaman>$2' into sohbet using e, t-make_interval(hours=>a.sohbet_saat);
 end if;
 if tekrar then
  delta:=a.ivme_tekrar; notu:='Tekrar eden hamle: halk bıkıyor';
  r.yorgunluk:=least(100, r.yorgunluk+5);
 elsif n<3 then
  delta:=a.ivme_zayif; notu:='Az katılımcıyla hamle: ivme '||delta::int;
 elsif tur='mesale' and not oyun.sokak_hukumet_yakin(e,a.mesale_hukumet_saat) then
  delta:=a.ivme_zayif; notu:='Meşale hükümet hamlesinden sonra anlamlı: ivme '||delta::int;
 elsif tur in ('uluslararasi','propaganda_skandal') and coalesce(nabiz,0)<a.uluslararasi_nabiz and r.ivme<40 then
  delta:=a.ivme_zayif; notu:='Uluslararası çağrı için sempati düşük: ivme '||delta::int;
 elsif tur in ('grev','yol','vergi') and n<a.grev_katilim then
  delta:=a.ivme_zayif; notu:='Kalabalık yetmeden ekonomik hamle: ivme '||delta::int;
 elsif coalesce(nabiz,0)<25 then
  delta:=a.ivme_zayif; notu:='Kamuoyu karşıyken hamle: halk bıkıyor';
 else
  akilli:=true; delta:=a.ivme_akilli;
  if oyun.sokak_hukumet_yakin(e,a.yanit_saat) then delta:=delta+a.ivme_akilli; end if;
  if sohbet>=a.sohbet_kisi then delta:=delta+4; end if;
  notu:='Doğru zamanda hamle: ivme +'||delta::int;
  r.son_akilli:=t;
  r.yorgunluk:=greatest(0, r.yorgunluk-6);
 end if;
 r.ivme:=greatest(0, least(100, r.ivme+delta));
 r.son:=t; r.son_tur:=tur; r.son_tur_zaman:=t; r.son_not:=notu;
 update oyun.sokak_ivme set ivme=r.ivme, yorgunluk=r.yorgunluk, son=r.son, son_akilli=r.son_akilli,
  son_tur=r.son_tur, son_tur_zaman=r.son_tur_zaman, son_not=r.son_not where eylem_id=e;
 if not akilli then return least(puan*0.25, 1); end if;
 return round(puan * (1/sqrt(1+n/greatest(a.katilim_egri,1))) * greatest(0.35, least(1.3,(30+r.ivme)/100.0)) * greatest(0.4, 1-r.yorgunluk/120.0), 2);
end $$;

create or replace function public.sokak_cagri_ac(p_il integer, p_gerekce text, p_talep text, p_kaynak text, p_kaynak_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi(); cid bigint; txt text;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.sokak_cagri_dustur();
 perform pg_advisory_xact_lock(781231,1);
 select * into p from oyun.profiller where id=u;
 if p.id is null or p.yasakli then raise exception 'Hesap uygun değil'; end if;
 if p.olusturma>t-make_interval(days=>a.hesap_gun) then raise exception 'Çağrı için hesap en az % gün olmalı', a.hesap_gun; end if;
 if p.son_gorulme<t-make_interval(days=>a.aktif_gun) then raise exception 'Çağrı için hesabın son günlerde oyunda olmalı'; end if;
 if p_kaynak not in ('parti','dernek') then raise exception 'Parti ya da dernek seçilmeli'; end if;
 if p_talep not in ('genel','hizmet','issizlik','vergi') then raise exception 'Geçersiz talep'; end if;
 if p_kaynak='parti' and not exists(select 1 from oyun.partiler where id=p_kaynak_id and gb=u and not kapali) then raise exception 'Çağrıyı partinin genel başkanı açar'; end if;
 if p_kaynak='dernek' and not exists(select 1 from oyun.dernekler where id=p_kaynak_id and baskan=u and not kapali) then raise exception 'Çağrıyı dernek başkanı açar'; end if;
 txt:=btrim(coalesce(p_gerekce,''));
 if char_length(txt)<20 then raise exception 'Gerekçe en az 20 karakter olmalı'; end if;
 if not oyun.sokak_sikayet_var(p_il) then raise exception 'Bu ilde somut bir şikayet yok. Memnuniyet yüksek ve son % saatte sert önlem, skandal ya da manşet de yok.', a.olay_saat; end if;
 if exists(select 1 from oyun.sokak_eylem e where e.il_id=p_il and e.baslangic>t-make_interval(hours=>a.il_bekleme_saat)) then raise exception 'Bu ilde yeni eylem için % saat bekleme var', a.il_bekleme_saat; end if;
 if exists(select 1 from oyun.sokak_cagri c where c.acan=u and c.acilis>t-make_interval(hours=>a.orgut_bekleme_saat) and c.durum<>'dustu') then raise exception 'Aynı kişi % saatte bir çağrı açabilir', a.orgut_bekleme_saat; end if;
 if exists(select 1 from oyun.sokak_eylem e where e.baslatan=u and e.baslangic>t-make_interval(hours=>a.orgut_bekleme_saat)) then raise exception 'Organizatör % saatte bir eylem başlatabilir', a.orgut_bekleme_saat; end if;
 if (select count(*) from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t)>=oyun.sokak_ulke_tavan() then raise exception 'Ülkede aynı anda açık eylem sınırı doldu'; end if;
 if exists(select 1 from oyun.sokak_cagri c where c.il_id=p_il and c.durum in ('imza','hazir')) then raise exception 'Bu ilde zaten açık bir çağrı var'; end if;
 perform oyun.sokak_kurulus_ode(p_kaynak,p_kaynak_id,a.depozito,'Eylem çağrısı depozitosu');
 insert into oyun.sokak_cagri(il_id,acan,kaynak,kaynak_id,talep,gerekce,depozito,acilis,bitis)
  values(p_il,u,p_kaynak,p_kaynak_id,p_talep,txt,a.depozito,t,t+make_interval(hours=>a.imza_saat)) returning id into cid;
 return jsonb_build_object('tamam',true,'cagri_id',cid,'imza',a.imza_sayisi,'depozito',a.depozito,'bitis',t+make_interval(hours=>a.imza_saat));
end $$;

create or replace function oyun.sokak_cagri_baslat(c oyun.sokak_cagri) returns jsonb
language plpgsql set search_path='' as $$
declare u uuid:=auth.uid(); v jsonb;
begin
 perform set_config('oyun.cagri_id', c.id::text, true);
 perform set_config('request.jwt.claim.sub', c.acan::text, true);
 v:=public.sokak_org_baslat(c.il_id, c.gerekce, c.talep, c.kaynak, c.kaynak_id, null);
 perform set_config('request.jwt.claim.sub', u::text, true);
 perform set_config('oyun.cagri_id','', true);
 update oyun.sokak_cagri set durum='acildi', eylem_id=(v->>'eylem_id')::bigint, hata=null where id=c.id;
 return v;
end $$;

create or replace function public.sokak_cagri_imza(p_cagri bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; c oyun.sokak_cagri; a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi(); n int; v jsonb;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.sokak_cagri_dustur();
 perform pg_advisory_xact_lock(781231,1);
 select * into c from oyun.sokak_cagri where id=p_cagri for update;
 if c.id is null or c.durum not in ('imza','hazir') or c.bitis<=t then raise exception 'İmzaya açık çağrı yok'; end if;
 if u=c.acan then raise exception 'Çağrıyı açan kişi imza sayılmaz'; end if;
 select * into p from oyun.profiller where id=u;
 if p.il_id is distinct from c.il_id then raise exception 'İmza için bu ilde yaşıyor olmalısın'; end if;
 if p.yasakli or p.olusturma>t-make_interval(days=>a.imza_hesap_gun) then raise exception 'İmza için hesap en az % gün olmalı', a.imza_hesap_gun; end if;
 insert into oyun.sokak_cagri_imza(cagri_id,user_id,zaman) values(c.id,u,t) on conflict do nothing;
 if not found then raise exception 'Bu çağrıya zaten imza verdin'; end if;
 select count(*) into n from oyun.sokak_cagri_imza where cagri_id=c.id;
 if n<a.imza_sayisi then
  return jsonb_build_object('tamam',true,'imza',n,'gerek',a.imza_sayisi);
 end if;
 update oyun.sokak_cagri set durum='hazir' where id=c.id and durum='imza';
 select * into c from oyun.sokak_cagri where id=c.id;
 begin
  v:=oyun.sokak_cagri_baslat(c);
 exception when others then
  update oyun.sokak_cagri set hata=sqlerrm where id=c.id;
  return jsonb_build_object('tamam',true,'hazir',true,'imza',n,'hata',sqlerrm);
 end;
 return v||jsonb_build_object('imza',n,'hazir',true);
end $$;

create or replace function public.sokak_cagri_tamamla(p_cagri bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c oyun.sokak_cagri; a oyun.sokak_denge_ayar:=oyun.sokak_denge(); n int;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into c from oyun.sokak_cagri where id=p_cagri for update;
 if c.id is null or c.durum<>'hazir' or c.bitis<=oyun.simdi() then raise exception 'Başlatılacak hazır çağrı yok'; end if;
 if u<>c.acan then raise exception 'Eylemi çağrıyı açan kişi başlatır'; end if;
 select count(*) into n from oyun.sokak_cagri_imza where cagri_id=c.id;
 if n<a.imza_sayisi then raise exception 'İmza eşiği dolmadı'; end if;
 return oyun.sokak_cagri_baslat(c);
end $$;

create or replace function public.sokak_denge_panel() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi(); p oyun.profiller;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.sokak_cagri_dustur();
 select * into p from oyun.profiller where id=u;
 return jsonb_build_object(
  'ayar',jsonb_build_object('memnuniyet_esik',a.memnuniyet_esik,'memnuniyetsizlik_esik',a.memnuniyetsizlik_esik,'olay_saat',a.olay_saat,'hesap_gun',a.hesap_gun,'depozito',a.depozito,'imza_sayisi',a.imza_sayisi,'imza_saat',a.imza_saat,'il_bekleme_saat',a.il_bekleme_saat,'orgut_bekleme_saat',a.orgut_bekleme_saat,'ulke_tavan',oyun.sokak_ulke_tavan(),'buyuk_ivme',a.buyuk_ivme,'buyuk_katilim',a.buyuk_katilim,'buyuk_nabiz',a.buyuk_nabiz,'saatlik_yuzde',a.saatlik_yuzde),
  'cagrilar',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'il_id',c.il_id,'durum',c.durum,'gerekce',c.gerekce,'depozito',c.depozito,'bitis',c.bitis,'hata',c.hata,'benim',c.acan=u,'imza',(select count(*) from oyun.sokak_cagri_imza i where i.cagri_id=c.id),'gerek',a.imza_sayisi,'imzaladim',exists(select 1 from oyun.sokak_cagri_imza i where i.cagri_id=c.id and i.user_id=u)) order by c.acilis desc)
    from oyun.sokak_cagri c where c.durum in ('imza','hazir') and (c.il_id=p.il_id or c.acan=u)),'[]'::jsonb),
  'eylemler',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'ivme',round(v.ivme),'yorgunluk',round(v.yorgunluk),'not',v.son_not,'katilim',(select count(*) from oyun.sokak_eylem_destek d where d.eylem_id=e.id and d.destek_turu='katilim' and d.taraf='muhalefet' and d.destekci_tur='oyuncu'),'tavan',oyun.sokak_il_tavan(e.il_id),'nabiz',oyun.sokak_memnuniyetsizlik(e.il_id)))
    from oyun.sokak_eylem e left join oyun.sokak_ivme v on v.eylem_id=e.id where e.durum='aktif' and e.bitis>t),'[]'::jsonb));
end $$;

create or replace function oyun.sokak_eylem_cagri_engel() returns trigger
language plpgsql set search_path='' as $$
declare a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi(); cid bigint; c oyun.sokak_cagri;
begin
 begin cid:=nullif(current_setting('oyun.cagri_id', true),'')::bigint; exception when others then cid:=null; end;
 select * into c from oyun.sokak_cagri where id=cid and durum='hazir' and il_id=new.il_id and acan=new.baslatan and bitis>t for update;
 if c.id is null then
  raise exception 'Eylem keyfi açılamaz. Önce çağrı açılmalı, depozito yatırılmalı ve bu ilden yeterli imza toplanmalı.';
 end if;
 if not oyun.sokak_sikayet_var(new.il_id) then
  raise exception 'Bu ilde somut bir şikayet yok. Memnuniyet yüksek ve yakın zamanda sert önlem ya da manşet de yok.';
 end if;
 if exists(select 1 from oyun.sokak_eylem e where e.il_id=new.il_id and e.id is distinct from new.id and e.baslangic>t-make_interval(hours=>a.il_bekleme_saat)) then
  raise exception 'Bu ilde yeni eylem için % saat bekleme var', a.il_bekleme_saat;
 end if;
 if (select count(*) from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t)>=oyun.sokak_ulke_tavan() then
  raise exception 'Ülkede aynı anda açık eylem sınırı doldu';
 end if;
 return new;
end $$;

create or replace function oyun.sokak_eylem_ivme_ac() returns trigger
language plpgsql set search_path='' as $$
declare a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi();
begin
 insert into oyun.sokak_ivme(eylem_id,ivme,yorgunluk,son,son_akilli,son_seviye,son_seviye_zaman,son_not)
 values(new.id,a.ivme_baslangic,0,t,t,coalesce(new.seviye,0),t,'Eylem çağrıdan doğdu.')
 on conflict(eylem_id) do nothing;
 return new;
end $$;

create or replace function oyun.sokak_seviye_dizgin() returns trigger
language plpgsql set search_path='' as $$
declare a oyun.sokak_denge_ayar:=oyun.sokak_denge(); r oyun.sokak_ivme; t timestamptz:=oyun.simdi();
 saat numeric; delta numeric; cap numeric; n int; carpan numeric; eski numeric; yeni numeric;
begin
 if new.seviye is not distinct from old.seviye then return new; end if;
 r:=oyun.sokak_ivme_satir(new.id);
 eski:=coalesce(old.seviye,0); yeni:=coalesce(new.seviye,0); delta:=yeni-eski;
 saat:=greatest(0.05, extract(epoch from (t-r.son_seviye_zaman))/3600);
 r.ivme:=greatest(0, least(100, r.ivme - a.ivme_decay_saat*least(saat,24)));
 if r.son_akilli<t-interval '1 hour' then r.yorgunluk:=least(100, r.yorgunluk + a.yorgunluk_saat*least(saat,24)); end if;
 if delta>0 then
  select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=new.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
  carpan:=(1/sqrt(1+coalesce(n,0)/greatest(a.katilim_egri,1))) * greatest(0.25, least(1.2,(30+r.ivme)/100.0)) * greatest(0.3, 1-r.yorgunluk/120.0);
  cap:=greatest(case when eski<15 then 8 else 2 end, eski*(a.saatlik_yuzde/100.0)*least(saat,1));
  delta:=least(delta, delta*carpan, cap);
  new.seviye:=least(100, eski+delta);
 end if;
 update oyun.sokak_ivme set ivme=r.ivme, yorgunluk=r.yorgunluk, son=t, son_seviye=new.seviye, son_seviye_zaman=t where eylem_id=new.id;
 return new;
end $$;

create or replace function oyun.sokak_etki_dizgin() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.puan is not null and new.puan>0 then
  new.puan:=oyun.sokak_ivme_uygula(new.eylem_id, new.tur, new.puan);
 end if;
 return new;
end $$;

create or replace function oyun.sokak_hamle_kapi() returns trigger
language plpgsql set search_path='' as $$
declare a oyun.sokak_denge_ayar:=oyun.sokak_denge(); n int; nabiz numeric; iv numeric;
begin
 if new.tur not in ('grev','isgal','zincir') then return new; end if;
 perform oyun.sokak_ivme_satir(new.eylem_id);
 select ivme into iv from oyun.sokak_ivme where eylem_id=new.eylem_id;
 select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=new.eylem_id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet';
 nabiz:=oyun.sokak_memnuniyetsizlik((select il_id from oyun.sokak_eylem where id=new.eylem_id));
 if coalesce(iv,0)<a.buyuk_ivme or coalesce(n,0)<a.buyuk_katilim or coalesce(nabiz,0)<a.buyuk_nabiz then
  raise exception 'Bu büyük hamle için ivme en az %, katılımcı en az % ve nabız en az % olmalı. Şu an ivme %, katılımcı %, nabız %.', a.buyuk_ivme, a.buyuk_katilim, a.buyuk_nabiz, coalesce(iv,0), coalesce(n,0), coalesce(nabiz,0);
 end if;
 return new;
end $$;

create or replace function oyun.sokak_katilim_tavan() returns trigger
language plpgsql set search_path='' as $$
declare il integer; n int; tavan int;
begin
 if new.destek_turu is distinct from 'katilim' or new.taraf is distinct from 'muhalefet' or new.destekci_tur is distinct from 'oyuncu' then
  return new;
 end if;
 select il_id into il from oyun.sokak_eylem where id=new.eylem_id;
 tavan:=oyun.sokak_il_tavan(il);
 select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=new.eylem_id and d.destek_turu='katilim' and d.taraf='muhalefet' and d.destekci_tur='oyuncu';
 if n>=tavan then raise exception 'Bu ilin aktif oyuncu sayısına göre katılımcı tavanı % kişi', tavan; end if;
 return new;
end $$;

drop trigger if exists sokak_eylem_cagri_engel on oyun.sokak_eylem;
create trigger sokak_eylem_cagri_engel before insert on oyun.sokak_eylem
 for each row execute function oyun.sokak_eylem_cagri_engel();
drop trigger if exists sokak_eylem_ivme_ac on oyun.sokak_eylem;
create trigger sokak_eylem_ivme_ac after insert on oyun.sokak_eylem
 for each row execute function oyun.sokak_eylem_ivme_ac();
drop trigger if exists sokak_seviye_dizgin on oyun.sokak_eylem;
create trigger sokak_seviye_dizgin before update of seviye on oyun.sokak_eylem
 for each row execute function oyun.sokak_seviye_dizgin();

do $$ begin
 if to_regclass('oyun.sokak_meydan_etki') is not null then
  drop trigger if exists sokak_etki_dizgin on oyun.sokak_meydan_etki;
  create trigger sokak_etki_dizgin before insert on oyun.sokak_meydan_etki
   for each row execute function oyun.sokak_etki_dizgin();
 end if;
 if to_regclass('oyun.sokak_hamle') is not null then
  drop trigger if exists sokak_hamle_kapi on oyun.sokak_hamle;
  create trigger sokak_hamle_kapi before insert on oyun.sokak_hamle
   for each row execute function oyun.sokak_hamle_kapi();
 end if;
 if to_regclass('oyun.sokak_eylem_destek') is not null then
  drop trigger if exists sokak_katilim_tavan on oyun.sokak_eylem_destek;
  create trigger sokak_katilim_tavan before insert on oyun.sokak_eylem_destek
   for each row execute function oyun.sokak_katilim_tavan();
 end if;
 if exists(select 1 from pg_extension where extname='pg_cron') then
  if not exists(select 1 from cron.job where jobname='sokak-denge') then
   perform cron.schedule('sokak-denge','*/10 * * * *','select oyun.sokak_cagri_dustur()');
  end if;
 end if;
end $$;

revoke all on function oyun.sokak_denge(),oyun.sokak_aktif_sayi(integer),oyun.sokak_ulke_tavan(),oyun.sokak_il_tavan(integer),
 oyun.sokak_hukumet_yakin(bigint,integer),oyun.sokak_sikayet_var(integer),oyun.sokak_cagri_dustur(),oyun.sokak_kurulus_ode(text,bigint,numeric,text),
 oyun.sokak_ivme_satir(bigint),oyun.sokak_ivme_uygula(bigint,text,numeric),oyun.sokak_cagri_baslat(oyun.sokak_cagri),
 oyun.sokak_eylem_cagri_engel(),oyun.sokak_eylem_ivme_ac(),oyun.sokak_seviye_dizgin(),oyun.sokak_etki_dizgin(),oyun.sokak_hamle_kapi(),oyun.sokak_katilim_tavan(),
 public.sokak_cagri_ac(integer,text,text,text,bigint),public.sokak_cagri_imza(bigint),public.sokak_cagri_tamamla(bigint),public.sokak_denge_panel()
 from public,anon,authenticated;
grant execute on function public.sokak_cagri_ac(integer,text,text,text,bigint),public.sokak_cagri_imza(bigint),public.sokak_cagri_tamamla(bigint),public.sokak_denge_panel() to authenticated;
