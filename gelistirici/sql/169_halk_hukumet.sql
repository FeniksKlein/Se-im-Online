-- Cumhurbaşkanı / İçişleri: sınırlı kamu harcaması, uzlaşma, siyasi baskı ve itirazlı yaptırım.
create table if not exists oyun.sokak_karar(
 id bigint generated always as identity primary key,eylem_id bigint not null references oyun.sokak_eylem,
 yapan uuid not null references oyun.profiller,tur text not null check(tur in ('masa','yonlendirme','uyari','dagitma','yaptirim')),
 gerekce text not null check(length(gerekce) between 20 and 500),bedel numeric not null check(bedel>=0),
 hedef uuid references oyun.profiller,zaman timestamptz not null,bitis timestamptz not null,
 durum text not null default 'aktif' check(durum in ('aktif','kabul','ret','itiraz','kaldirildi','onandi')),
 cevap text,cevaplayan uuid references oyun.profiller,cevap_zamani timestamptz
);
create index if not exists sokak_karar_eylem on oyun.sokak_karar(eylem_id,zaman desc);
create index if not exists sokak_karar_hedef on oyun.sokak_karar(hedef,zaman desc) where hedef is not null;
create index if not exists sokak_karar_zaman on oyun.sokak_karar(zaman desc);
alter table oyun.sokak_karar enable row level security;
revoke all on oyun.sokak_karar from public,anon,authenticated;

create or replace function oyun.sokak_yonetebilir(u uuid) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.makamlar where user_id=u and bit is null and (tur='cb' or tur='bakan' and bakanlik='icisleri'))
$$;
create or replace function oyun.sokak_yaptirimli(u uuid,e bigint) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_karar where hedef=u and eylem_id=e and tur='yaptirim' and durum in ('aktif','onandi') and bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_karar_etki(e bigint) returns numeric language sql stable set search_path='' as $$
 select coalesce(sum(case when tur='yonlendirme' and bitis>oyun.simdi() then -10 when tur='uyari' and bitis>oyun.simdi() then -8 when tur='uyari' and bitis+interval '18 hours'>oyun.simdi() then 6 else 0 end),0) from oyun.sokak_karar where eylem_id=e
$$;
create or replace function oyun.sokak_karar_bedel(e bigint,k text) returns numeric language sql stable set search_path='' as $$
 select round(case k when 'masa' then a.baslatma_bedeli*2 when 'yonlendirme' then a.baslatma_bedeli*3 when 'uyari' then a.baslatma_bedeli when 'dagitma' then greatest(a.baslatma_bedeli*5,x.muhalefet_fonu*5-x.iktidar_fonu) when 'yaptirim' then a.baslatma_bedeli*2 end,2) from oyun.sokak_eylem x cross join oyun.sokak_eylem_ayar a where x.id=e and a.id=1
$$;

create or replace function public.sokak_hukumet_karar(p_eylem bigint,p_tur text,p_gerekce text,p_hedef uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); tut numeric; kid bigint;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(781231,1);p:=oyun.profilim();
 if not oyun.sokak_yonetebilir(u) then raise exception 'Yalnız Cumhurbaşkanı veya İçişleri Bakanı kullanabilir'; end if;
 if not coalesce((select aktif from oyun.sokak_eylem_ayar where id=1),false) then raise exception 'Halk hareketleri kapalı'; end if;
 if p_tur is null or p_tur not in ('masa','yonlendirme','uyari','dagitma','yaptirim') or length(btrim(coalesce(p_gerekce,''))) not between 20 and 500 then raise exception 'Geçerli yöntem ve 20–500 karakter gerekçe gerekli'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Eylem aktif değil'; end if;
 if exists(select 1 from oyun.sokak_karar where eylem_id=x.id and zaman>t-interval '6 hours') then raise exception 'Aynı eyleme müdahaleler arasında 6 saat gerekir'; end if;
 if (select count(*) from oyun.sokak_karar where zaman>t-interval '24 hours')>=4 then raise exception 'Hükümetin ülke çapında son 24 saatlik 4 karar sınırı doldu'; end if;
 if p_tur='masa' and exists(select 1 from oyun.sokak_karar where eylem_id=x.id and tur='masa') then raise exception 'Bu eylem için uzlaşma masası zaten teklif edildi'; end if;
 if p_tur='dagitma' then
  if x.kirmizi_baslangic is null or x.kirmizi_baslangic>t-interval '12 hours' then raise exception 'Dağıtma için kesintisiz 12 saat kırmızı seviye gerekir'; end if;
  if exists(select 1 from oyun.sokak_karar where tur='dagitma' and zaman>t-interval '48 hours') then raise exception 'Ülke çapında dağıtma yetkisi 48 saatte bir kullanılabilir'; end if;
 end if;
 if p_tur='yaptirim' then
  if p_hedef is null or p_hedef=u or not exists(select 1 from oyun.sokak_eylem_destek where eylem_id=x.id and temsilci=p_hedef and destekci_tur='oyuncu' and destek_turu='katilim' and taraf='muhalefet') then raise exception 'Bu eyleme katılmış bir oyuncu seçilmeli'; end if;
  if exists(select 1 from oyun.sokak_karar where hedef=p_hedef and tur='yaptirim' and zaman>t-interval '7 days') then raise exception 'Aynı oyuncuya 7 günde bir yaptırım uygulanabilir'; end if;
  if (select count(*) from oyun.sokak_karar where eylem_id=x.id and tur='yaptirim')>=3 then raise exception 'Bir eylemde en fazla 3 yaptırım'; end if;
 elsif p_hedef is not null then raise exception 'Bu yöntemde hedef oyuncu seçilmez'; end if;
 tut:=oyun.sokak_karar_bedel(x.id,p_tur);
 -- Kamu kasası mevcut oyun para ölçeğiyle tahsil edilir; kasa hareketi mevcut tetikleyiciyle yazılır.
 perform oyun.bm_kasa_harca('icisleri',tut/oyun.pazar_tl_milyar(),'gider','Halk hareketi #'||x.id||' / '||p_tur||' / '||tut||' TL');
 insert into oyun.sokak_karar(eylem_id,yapan,tur,gerekce,bedel,hedef,zaman,bitis) values(x.id,u,p_tur,btrim(p_gerekce),tut,p_hedef,t,t+case when p_tur in ('masa','yonlendirme') then interval '12 hours' else interval '6 hours' end) returning id into kid;
 if p_tur='dagitma' then
  update oyun.sokak_eylem set durum='yatisti',kapandi=t,kirmizi_baslangic=null,seviye=0 where id=x.id;
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-4) where id=1;
  update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-5) where il_id=x.il_id;
 elsif p_tur='uyari' then update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
 elsif p_tur='yaptirim' then
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
  perform oyun.bildir(p_hedef,'Eylem #'||x.id||': 6 saatlik katılım/fon kısıtı. Gerekçe: '||btrim(p_gerekce)||'. Halk Hareketleri ekranından itiraz edebilirsin; itiraz uygulamayı durdurur.');
 end if;
 perform oyun.sokak_yenile(x.id);
 if (select count(*) from oyun.sokak_eylem where durum='aktif' and bitis>t and kirmizi_baslangic is not null)<3 then update oyun.sokak_kriz set kirmizi_baslangic=null where id=1; end if;
 perform oyun.sokak_duyur(x.id,'Hükümet eylem #'||x.id||' için '||case p_tur when 'masa' then 'uzlaşma masası' when 'yonlendirme' then 'bilgilendirme ve yönlendirme' when 'uyari' then 'sert siyasi uyarı' when 'dagitma' then 'ek bütçeli dağıtma' else 'süreli yaptırım' end||' kararı aldı. Gider: '||tut||' TL. Gerekçe: '||btrim(p_gerekce));
 return jsonb_build_object('tamam',true,'karar_id',kid,'bedel',tut);
end $$;

create or replace function public.sokak_karar_yanit(p_karar bigint,p_islem text,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller;k oyun.sokak_karar;x oyun.sokak_eylem;t timestamptz:=oyun.simdi();yargi boolean;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(781231,1);p:=oyun.profilim();
 select * into k from oyun.sokak_karar where id=p_karar for update;
 if k.id is null or k.bitis<=t then raise exception 'Kararın yanıt süresi doldu'; end if;
 select * into x from oyun.sokak_eylem where id=k.eylem_id for update;
 if x.durum<>'aktif' or x.bitis<=t then raise exception 'Eylem sona erdi'; end if;
 if length(btrim(coalesce(p_metin,''))) not between 20 and 500 then raise exception '20–500 karakter açıklama gerekli'; end if;
 yargi:=exists(select 1 from oyun.adliye_makam where hakim=u) and u<>k.yapan and u is distinct from k.hedef and not oyun.sokak_yonetebilir(u);
 if k.tur='masa' and k.durum='aktif' and u=x.baslatan and p_islem in ('kabul','ret') then
  update oyun.sokak_karar set durum=p_islem,cevap=btrim(p_metin),cevaplayan=u,cevap_zamani=t where id=k.id;
  if p_islem='kabul' then
   update oyun.sokak_eylem set durum='yatisti',kapandi=t,kirmizi_baslangic=null,seviye=0 where id=x.id;
   update oyun.il_durum set memnuniyet=least(100,memnuniyet+2) where il_id=x.il_id;
  end if;
 elsif k.tur='yaptirim' and k.durum='aktif' and u=k.hedef and p_islem='itiraz' then
  update oyun.sokak_karar set durum='itiraz',cevap=btrim(p_metin),cevaplayan=u,cevap_zamani=t where id=k.id;
  insert into oyun.bildirimler(user_id,zaman,metin) select hakim,t,'Eylem yaptırımı #'||k.id||' için itiraz var. Halk Hareketleri ekranından inceleyebilirsiniz.' from oyun.adliye_makam where hakim is not null;
 elsif k.tur='yaptirim' and k.durum='itiraz' and yargi and p_islem in ('kaldirildi','onandi') then
  update oyun.sokak_karar set durum=p_islem,cevap=btrim(p_metin),cevaplayan=u,cevap_zamani=t where id=k.id;
  perform oyun.bildir(k.hedef,'Eylem yaptırımı #'||k.id||' yargı kararı: '||p_islem||'. '||btrim(p_metin));
 else raise exception 'Bu karar için yetkiniz veya işlem hakkınız yok'; end if;
 perform oyun.sokak_yenile(x.id);
 if (select count(*) from oyun.sokak_eylem where durum='aktif' and bitis>t and kirmizi_baslangic is not null)<3 then update oyun.sokak_kriz set kirmizi_baslangic=null where id=1; end if;
 perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' / karar #'||k.id||': '||p_islem||'. '||btrim(p_metin));
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.sokak_hukumet_panel() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();v_profil oyun.profiller;b jsonb;arr jsonb;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;v_profil:=oyun.profilim();b:=public.sokak_eylemler();
 select coalesce(jsonb_agg(e||jsonb_build_object('ben_baslattim',e->>'baslatan'=u::text,
 'bedeller',(select jsonb_object_agg(k,oyun.sokak_karar_bedel((e->>'id')::bigint,k)) from unnest(array['masa','yonlendirme','uyari','dagitma','yaptirim'])k),
 'katilimcilar',case when oyun.sokak_yonetebilir(u) then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'ad',p.kad)) from oyun.sokak_eylem_destek d join oyun.profiller p on p.id=d.temsilci where d.eylem_id=(e->>'id')::bigint and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet'),'[]'::jsonb) else '[]'::jsonb end,
 'kararlar',coalesce((select jsonb_agg(to_jsonb(k)||jsonb_build_object('ben_hedefim',k.hedef=u,'yargi_yetki',exists(select 1 from oyun.adliye_makam where hakim=u) and u<>k.yapan and u is distinct from k.hedef and not oyun.sokak_yonetebilir(u),'yapan_ad',oyun.kad(k.yapan),'hedef_ad',oyun.kad(k.hedef),'suresi_doldu',k.bitis<=oyun.simdi()) order by k.zaman desc) from oyun.sokak_karar k where k.eylem_id=(e->>'id')::bigint),'[]'::jsonb))), '[]'::jsonb) into arr from jsonb_array_elements(b->'eylemler')e;
 return b||jsonb_build_object('eylemler',arr,'mudahale_yetki',oyun.sokak_yonetebilir(u),'icisleri_kasa_tl',case when oyun.sokak_yonetebilir(u) then (select kasa*oyun.pazar_tl_milyar() from oyun.bakanlik_kasa where kod='icisleri') else null end);
end $$;

-- Mevcut hesaplama/katılım motoruna küçük ve doğrulanmış ekler. Yeniden uygulamak güvenlidir.
do $$ declare s text; begin
 s:=pg_get_functiondef('oyun.sokak_yenile(bigint)'::regprocedure);
 if position('sokak_karar_etki' in s)=0 then
  if position('oyun.sokak_memnuniyetsizlik(x.il_id)*0.5' in s)=0 then raise exception 'Seviye hesaplama bağlantısı bulunamadı'; end if;
  s:=replace(s,'oyun.sokak_memnuniyetsizlik(x.il_id)*0.5','oyun.sokak_karar_etki(x.id)+oyun.sokak_memnuniyetsizlik(x.il_id)*0.5');
  s:=replace(s,$str$d.taraf='muhalefet' and p.il_id=x.il_id$str$,$str$d.taraf='muhalefet' and not oyun.sokak_yaptirimli(p.id,x.id) and p.il_id=x.il_id$str$);execute s;
 end if;
 s:=pg_get_functiondef('oyun.sokak_tick()'::regprocedure);
 if position('sokak_yaptirimli' in s)=0 then
  s:=replace(s,$str$d.taraf='muhalefet' and not p.yasakli$str$,$str$d.taraf='muhalefet' and not oyun.sokak_yaptirimli(p.id,e.id) and not p.yasakli$str$);execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_destek(bigint,text,text,bigint,numeric)'::regprocedure);
 if position('sokak_yaptirimli' in s)=0 then
  s:=replace(s,'kid:=case',$patch$if oyun.sokak_yaptirimli(u,p_eylem) then raise exception 'Bu eylemde geçici yaptırımınız var; itiraz edebilirsiniz'; end if;
 kid:=case$patch$);execute s;
 end if;
end $$;
revoke all on function oyun.sokak_yonetebilir(uuid),oyun.sokak_yaptirimli(uuid,bigint),oyun.sokak_karar_etki(bigint),oyun.sokak_karar_bedel(bigint,text),public.sokak_hukumet_karar(bigint,text,text,uuid),public.sokak_karar_yanit(bigint,text,text),public.sokak_hukumet_panel() from public,anon,authenticated;
grant execute on function public.sokak_hukumet_karar(bigint,text,text,uuid),public.sokak_karar_yanit(bigint,text,text),public.sokak_hukumet_panel() to authenticated;
