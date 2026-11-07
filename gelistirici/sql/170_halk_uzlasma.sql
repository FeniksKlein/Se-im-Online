create table if not exists oyun.sokak_talep(eylem_id bigint primary key references oyun.sokak_eylem,tur text not null check(tur in ('hizmet','issizlik','vergi')));
create table if not exists oyun.sokak_soz(eylem_id bigint primary key references oyun.sokak_eylem,karar_id bigint unique not null references oyun.sokak_karar,tur text not null,baslangic numeric not null,hedef numeric not null,oy_sonu timestamptz not null,son_tarih timestamptz,durum text not null default 'oylama' check(durum in ('oylama','reddedildi','takip','tutuldu','tutulmadi','kapandi')),askidan_once_bitis timestamptz);
create table if not exists oyun.sokak_soz_oy(eylem_id bigint references oyun.sokak_soz,user_id uuid references oyun.profiller,oy boolean,zaman timestamptz,primary key(eylem_id,user_id));
create or replace function oyun.sokak_olcum(e bigint,k text) returns numeric language sql stable set search_path='' as $$
 select case k when 'hizmet' then i.memnuniyet when 'issizlik' then u.issizlik when 'vergi' then u.vergi end from oyun.sokak_eylem x join oyun.il_durum i on i.il_id=x.il_id cross join oyun.ulke u where x.id=e and u.id=1
$$;
create or replace function public.sokak_talep_sec(p_eylem bigint,p_tur text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller;begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;p:=oyun.profilim();perform pg_advisory_xact_lock(781231,1);
 if p_tur is null or p_tur not in ('hizmet','issizlik','vergi') then raise exception 'Geçersiz talep';end if;
 if not exists(select 1 from oyun.sokak_eylem where id=p_eylem and baslatan=p.id and durum='aktif' and bitis>oyun.simdi()) then raise exception 'Yalnız aktif eylemin organizatörü talep belirler';end if;
 if exists(select 1 from oyun.sokak_talep where eylem_id=p_eylem) then raise exception 'Talep sonradan değiştirilemez';end if;
 insert into oyun.sokak_talep values(p_eylem,p_tur);return jsonb_build_object('tamam',true);end $$;
create or replace function public.sokak_talepli_baslat(p_il integer,p_gerekce text,p_tur text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v jsonb;begin v:=public.sokak_eylem_baslat(p_il,p_gerekce);perform public.sokak_talep_sec((v->>'eylem_id')::bigint,p_tur);return v;end $$;
create or replace function public.sokak_soz_teklif(p_eylem bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller;k text;v jsonb;b numeric;h numeric;n integer;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;p:=oyun.profilim();perform pg_advisory_xact_lock(781231,1);
 if not oyun.sokak_yonetebilir(p.id) then raise exception 'Cumhurbaşkanı veya İçişleri yetkisi gerekli';end if;
 select tur into k from oyun.sokak_talep where eylem_id=p_eylem;if k is null then raise exception 'Önce organizatör somut talep seçmeli';end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=p_eylem) then raise exception 'Eylem başına bir uzlaşma teklifi';end if;
 b:=oyun.sokak_olcum(p_eylem,k);h:=case k when 'hizmet' then b+5 when 'issizlik' then b-0.5 else b-1 end;
 if b is null or h<0 or k='hizmet' and h>100 then raise exception 'Bu gösterge için uygulanabilir hedef yok';end if;
 perform set_config('oyun.soz_teklif','evet',true);
 v:=public.sokak_hukumet_karar(p_eylem,'masa',p_metin);
 perform set_config('oyun.soz_teklif','',true);
 insert into oyun.sokak_soz(eylem_id,karar_id,tur,baslangic,hedef,oy_sonu) values(p_eylem,(v->>'karar_id')::bigint,k,b,h,oyun.simdi()+interval '12 hours');
 insert into oyun.sokak_soz_oy(eylem_id,user_id) select distinct p_eylem,d.temsilci from oyun.sokak_eylem_destek d join oyun.profiller pr on pr.id=d.temsilci join oyun.sokak_eylem e on e.id=d.eylem_id where e.id=p_eylem and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and not pr.yasakli and pr.il_id=e.il_id and pr.il_at<oyun.simdi()-interval '3 days';
 get diagnostics n=row_count;if n<3 then raise exception 'Oylama için en az 3 yerel katılımcı gerekli';end if;
 perform oyun.sokak_duyur(p_eylem,'Somut uzlaşma teklifi oylamaya açıldı. Seçmen listesi sabit; kabul için tüm katılımcıların yarısından fazlası gerekir.');return v;
end $$;
create or replace function public.sokak_soz_oyla(p_eylem bigint,p_oy boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller;s oyun.sokak_soz;x oyun.sokak_eylem;n integer;evet integer;hayir integer;t timestamptz:=oyun.simdi();
begin
 if auth.uid() is null or p_oy is null then raise exception 'Oturum ve oy gerekli';end if;p:=oyun.profilim();perform pg_advisory_xact_lock(781231,1);
 select * into s from oyun.sokak_soz where eylem_id=p_eylem for update;select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if s.durum is distinct from 'oylama' or s.oy_sonu<=t or x.durum<>'aktif' or x.bitis<=t then raise exception 'Oylama kapalı';end if;
 update oyun.sokak_soz_oy set oy=p_oy,zaman=t where eylem_id=p_eylem and user_id=p.id and oy is null;
 if not found then raise exception 'Oy hakkınız yok veya zaten oy verdiniz';end if;
 select count(*),count(*) filter(where oy),count(*) filter(where not oy) into n,evet,hayir from oyun.sokak_soz_oy where eylem_id=p_eylem;
 if evet>n/2 then
  update oyun.sokak_soz set durum='takip',son_tarih=t+interval '24 hours',askidan_once_bitis=x.bitis where eylem_id=p_eylem;
  update oyun.sokak_eylem set bitis=bitis+interval '24 hours',kirmizi_baslangic=null,seviye=0 where id=p_eylem;
  update oyun.sokak_karar set durum='kabul',cevap='Katılımcı çoğunluğu kabul etti',cevap_zamani=t where id=s.karar_id;
  update oyun.sokak_kriz set kirmizi_baslangic=null where id=1;
  perform oyun.sokak_duyur(p_eylem,'Katılımcılar uzlaşmayı kabul etti. Eylem 24 saat askıda; hedef süre sonunda otomatik ölçülecek.');
 elsif hayir>=ceil(n/2.0) then
  update oyun.sokak_soz set durum='reddedildi' where eylem_id=p_eylem;
  update oyun.sokak_karar set durum='ret',cevap='Katılımcı oylamasında reddedildi',cevap_zamani=t where id=s.karar_id;
  perform oyun.sokak_duyur(p_eylem,'Uzlaşma oylamada reddedildi; eylem devam ediyor.');
 end if;return jsonb_build_object('tamam',true);end $$;
create or replace function oyun.sokak_soz_tick() returns void language plpgsql security definer set search_path='' as $$
declare s record;t timestamptz:=oyun.simdi();v numeric;ok boolean;
begin
 if not pg_try_advisory_xact_lock(781231,1) then return;end if;
 for s in select z.*,e.durum e_durum,e.bitis from oyun.sokak_soz z join oyun.sokak_eylem e on e.id=z.eylem_id where z.durum in ('oylama','takip') for update of z loop
  if s.e_durum<>'aktif' then update oyun.sokak_soz set durum='kapandi' where eylem_id=s.eylem_id;continue;end if;
  if s.durum='oylama' and (s.oy_sonu<=t or s.bitis<=t) then
   update oyun.sokak_soz set durum='reddedildi' where eylem_id=s.eylem_id;update oyun.sokak_karar set durum='ret' where id=s.karar_id;
   perform oyun.sokak_duyur(s.eylem_id,'Uzlaşma oylaması yeterli kabul alamadan kapandı.');
  elsif s.durum='takip' and s.son_tarih<=t then
   v:=oyun.sokak_olcum(s.eylem_id,s.tur);ok:=coalesce(case when s.tur='hizmet' then v>=s.hedef else v<=s.hedef end,false);
   update oyun.sokak_soz set durum=case when ok then 'tutuldu' else 'tutulmadi' end where eylem_id=s.eylem_id;
   if ok then
    update oyun.sokak_eylem set durum='yatisti',kapandi=t,seviye=0,kirmizi_baslangic=null where id=s.eylem_id;
    update oyun.ulke set memnuniyet=least(100,memnuniyet+1) where id=1;
   else
    update oyun.ulke set memnuniyet=greatest(0,memnuniyet-3) where id=1;
    perform oyun.sokak_yenile(s.eylem_id);
   end if;
   perform oyun.sokak_duyur(s.eylem_id,'Uzlaşma takibi: '||case when ok then 'söz tutuldu, eylem sona erdi.' else 'söz tutulmadı, eylem devam ediyor; hükümet güven kaybetti.' end||' Hedef: '||s.hedef||', ölçülen: '||coalesce(v::text,'veri yok'));
  end if;
 end loop;
end $$;
create or replace function public.sokak_uzlasma_panel() returns jsonb language plpgsql security definer set search_path='' as $$
declare b jsonb;a jsonb;u uuid:=auth.uid();begin
 if u is null then raise exception 'Oturum gerekli';end if;b:=public.sokak_hukumet_panel();
 select coalesce(jsonb_agg(e||jsonb_build_object('talep',(select tur from oyun.sokak_talep where eylem_id=(e->>'id')::bigint),'soz',(select to_jsonb(s)||jsonb_build_object('olcum',oyun.sokak_olcum(s.eylem_id,s.tur),'secmen',(select count(*) from oyun.sokak_soz_oy where eylem_id=s.eylem_id),'evet',(select count(*) from oyun.sokak_soz_oy where eylem_id=s.eylem_id and oy),'hayir',(select count(*) from oyun.sokak_soz_oy where eylem_id=s.eylem_id and not oy),'oy_hakki',exists(select 1 from oyun.sokak_soz_oy where eylem_id=s.eylem_id and user_id=u and oy is null)) from oyun.sokak_soz s where s.eylem_id=(e->>'id')::bigint),'durum',case when exists(select 1 from oyun.sokak_soz where eylem_id=(e->>'id')::bigint and durum='takip') then 'askida' else e->>'durum' end)),'[]'::jsonb) into a from jsonb_array_elements(b->'eylemler')e;
 return b||jsonb_build_object('eylemler',a);end $$;
-- Eski istemci tek kişinin kabulüyle yeni oylamayı atlayamaz. Askı süresinde karşılıklı müdahale/fon durur.
do $$declare s text;f text;begin
 s:=pg_get_functiondef('public.sokak_hukumet_karar(bigint,text,text,uuid)'::regprocedure);
 if position('soz_teklif' in s)=0 then s:=replace(s,'tut:=oyun.sokak_karar_bedel', $p$if p_tur='masa' and coalesce(current_setting('oyun.soz_teklif',true),'')<>'evet' then raise exception 'Somut teklif ve katılımcı oylaması kullanın';end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=p_eylem and durum='takip') then raise exception 'Uzlaşma takip süresinde müdahale yapılamaz';end if;
 tut:=oyun.sokak_karar_bedel$p$);execute s;end if;
 s:=pg_get_functiondef('public.sokak_karar_yanit(bigint,text,text)'::regprocedure);
 if position('sokak_soz' in s)=0 then s:=replace(s,$q$if k.tur='masa'$q$,$p$if exists(select 1 from oyun.sokak_soz where karar_id=k.id) then raise exception 'Bu teklif için katılımcı oylaması kullanın';end if;
 if k.tur='masa'$p$);execute s;end if;
 s:=pg_get_functiondef('public.sokak_destek(bigint,text,text,bigint,numeric)'::regprocedure);
 if position('sokak_soz' in s)=0 then s:=replace(s,'kid:=case',$p$if exists(select 1 from oyun.sokak_soz where eylem_id=p_eylem and durum='takip') then raise exception 'Eylem uzlaşma için askıda';end if;
 kid:=case$p$);execute s;end if;
 s:=pg_get_functiondef('oyun.sokak_yenile(bigint)'::regprocedure);
 if position('sokak_soz' in s)=0 then s:=replace(s,'if x.bitis<=t then',$p$if exists(select 1 from oyun.sokak_soz where eylem_id=p_id and durum='takip') then return;end if;
 if x.bitis<=t then$p$);execute s;end if;
 s:=pg_get_functiondef('oyun.sokak_tick()'::regprocedure);
 if position('sokak_soz_tick' in s)=0 then s:=replace(s,'for x in select id', 'perform oyun.sokak_soz_tick(); for x in select id');execute s;end if;
 foreach f in array array['sokak_talep','sokak_soz','sokak_soz_oy'] loop execute format('alter table oyun.%I enable row level security',f);execute format('revoke all on oyun.%I from public,anon,authenticated',f);end loop;
end $$;
revoke all on function oyun.sokak_olcum(bigint,text),oyun.sokak_soz_tick(),public.sokak_talep_sec(bigint,text),public.sokak_talepli_baslat(integer,text,text),public.sokak_soz_teklif(bigint,text),public.sokak_soz_oyla(bigint,boolean),public.sokak_uzlasma_panel() from public,anon,authenticated;
grant execute on function public.sokak_talep_sec(bigint,text),public.sokak_talepli_baslat(integer,text,text),public.sokak_soz_teklif(bigint,text),public.sokak_soz_oyla(bigint,boolean),public.sokak_uzlasma_panel() to authenticated;
