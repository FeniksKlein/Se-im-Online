begin;
-- Geniş Cumhurbaşkanı Yardımcılığı: iki bağımsız yardımcının koordinasyon masası.
-- Eski makam, oy, cüzdan, kabine ve kararname kayıtlarına dokunmaz.

create table if not exists oyun.cb_yrd_alan (
 sira smallint primary key check (sira in (1,2)),
 alan text not null check (alan in ('ekonomi','sosyal','genel')),
 degistiren uuid references oyun.profiller(id),
 guncelleme timestamptz not null default now()
);
insert into oyun.cb_yrd_alan(sira,alan) values (1,'ekonomi'),(2,'sosyal') on conflict (sira) do nothing;

-- Resmî Gazete'nin haber türü sözlüğünü yalnız genişlet.
alter table oyun.gazete drop constraint if exists gazete_tur_check;
alter table oyun.gazete add constraint gazete_tur_check
 check (tur in ('kanun','kararname','atama','icraat','anayasa','referandum','belediye','duyuru'));

create table if not exists oyun.cb_yrd_dosya (
 id bigint generated always as identity primary key,
 cb uuid not null references oyun.profiller(id),
 yardimci uuid not null references oyun.profiller(id),
 sira smallint not null check (sira in (1,2)),
 tur text not null check (tur in ('gorev','proje','kriz','kararname','toplanti','aciklama','yerel','ekonomi')),
 baslik text not null check (char_length(baslik) between 5 and 120),
 aciklama text not null check (char_length(aciklama) between 15 and 2000),
 bakanlik text references oyun.bakanliklar(kod),
 il_id smallint references oyun.iller(id),
 hedef uuid references oyun.profiller(id),
 veri jsonb not null default '{}'::jsonb,
 durum text not null check (durum in ('bekliyor','calisiliyor','tamamlandi','onay_bekliyor','onaylandi','reddedildi','yayimlandi')),
 yanit text,
 karar_veren uuid references oyun.profiller(id),
 son_tarih timestamptz,
 olusturma timestamptz not null default now(),
 guncelleme timestamptz not null default now()
);
create index if not exists cb_yrd_dosya_cb_zaman on oyun.cb_yrd_dosya(cb,olusturma desc);
create index if not exists cb_yrd_dosya_hedef_bekleyen on oyun.cb_yrd_dosya(hedef,durum) where hedef is not null;
create index if not exists cb_yrd_dosya_yardimci on oyun.cb_yrd_dosya(yardimci,olusturma desc);

create table if not exists oyun.cb_yrd_toplanti_oy (
 dosya_id bigint not null references oyun.cb_yrd_dosya(id),
 user_id uuid not null references oyun.profiller(id),
 oy boolean not null,
 gerekce text not null check (char_length(gerekce) between 10 and 500),
 zaman timestamptz not null default now(),
 primary key(dosya_id,user_id)
);

create table if not exists oyun.cb_yrd_vekalet (
 cb uuid primary key references oyun.profiller(id),
 vekil uuid not null references oyun.profiller(id),
 sira smallint not null check (sira in (1,2)),
 verilen timestamptz not null default now(),
 bitis timestamptz not null,
 check (bitis > verilen and bitis <= verilen + interval '24 hours')
);

alter table oyun.cb_yrd_alan enable row level security;
alter table oyun.cb_yrd_dosya enable row level security;
alter table oyun.cb_yrd_vekalet enable row level security;
alter table oyun.cb_yrd_toplanti_oy enable row level security;
revoke all on oyun.cb_yrd_alan,oyun.cb_yrd_dosya,oyun.cb_yrd_vekalet,oyun.cb_yrd_toplanti_oy from public,anon,authenticated;

-- Yetki her işlemde aktif makamdan okunur; istemcinin gönderdiği kimliğe güvenilmez.
create or replace function oyun.cb_yrd_aktif_sira(p_user uuid) returns smallint
language sql stable set search_path='' as $fn$
 select m.bakanlik::smallint from oyun.makamlar m
 where m.tur='cb_yardimcisi' and m.bit is null and m.user_id=p_user and m.bakanlik in ('1','2')
 and exists(select 1 from oyun.makamlar c where c.tur='cb' and c.bit is null)
 limit 1
$fn$;

create or replace function oyun.cb_yrd_bakanlik_uygun(p_sira smallint,p_bakanlik text) returns boolean
language sql stable set search_path='' as $fn$
 select case coalesce((select alan from oyun.cb_yrd_alan where sira=p_sira),'genel')
  when 'genel' then true
  when 'ekonomi' then p_bakanlik = any(array['maliye','sanayi','ticaret','tarim','ulastirma','calisma'])
  else p_bakanlik = any(array['adalet','disisleri','icisleri','savunma','egitim','saglik']) end
$fn$;

create or replace function public.cb_yrd_alan_ayarla(p_sira integer,p_alan text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim();
begin
 perform oyun.cb_zorunlu(p);
 if p_sira is null or p_sira not in (1,2) or p_alan is null or p_alan not in ('ekonomi','sosyal','genel') then
  raise exception 'Yardımcı sırası veya sorumluluk alanı geçersiz.'; end if;
 insert into oyun.cb_yrd_alan(sira,alan,degistiren,guncelleme) values(p_sira,p_alan,p.id,oyun.simdi())
 on conflict (sira) do update set alan=excluded.alan,degistiren=excluded.degistiren,guncelleme=excluded.guncelleme;
 return jsonb_build_object('tamam',true,'sira',p_sira,'alan',p_alan);
end $fn$;

create or replace function public.cb_yrd_vekalet_ayarla(p_sira integer,p_saat integer)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); v_vekil uuid;
begin
 perform oyun.cb_zorunlu(p);
 if p_sira is null or p_sira not in (1,2) then raise exception 'Yardımcı sırası geçersiz.'; end if;
 if p_saat is null or p_saat<0 or p_saat>24 then raise exception 'Vekâlet 0-24 saat olabilir.'; end if;
 if p_saat=0 then
  delete from oyun.cb_yrd_vekalet where cb=p.id;
  return jsonb_build_object('tamam',true,'iptal',true);
 end if;
 select user_id into v_vekil from oyun.makamlar where tur='cb_yardimcisi' and bakanlik=p_sira::text and bit is null limit 1;
 if v_vekil is null then
  raise exception 'Boş yardımcı makamına vekâlet verilemez.'; end if;
 insert into oyun.cb_yrd_vekalet(cb,vekil,sira,verilen,bitis) values(p.id,v_vekil,p_sira,t,t+make_interval(hours=>p_saat))
 on conflict (cb) do update set vekil=excluded.vekil,sira=excluded.sira,verilen=excluded.verilen,bitis=excluded.bitis;
 perform oyun.bildir(v_vekil,
  format('Cumhurbaşkanı sana %s saatlik sınırlı koordinasyon vekâleti verdi. Kararnameler, para harcaması ve atamalar bu vekâletin dışında.',p_saat),t);
 return jsonb_build_object('tamam',true,'bitis',t+make_interval(hours=>p_saat));
end $fn$;

create or replace function public.cb_yrd_dosya_ac(
 p_tur text,p_baslik text,p_aciklama text,p_bakanlik text default null,p_il integer default null,
 p_gun integer default 3,p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); s smallint:=oyun.cb_yrd_aktif_sira(p.id);
 c uuid:=oyun.aktif_cb(); t timestamptz:=oyun.simdi(); v_id bigint; v_hedef uuid; v_durum text;
 v_baslik text; v_aciklama text; v_bakan text; v_il smallint;
begin
 if s is null or c is null then raise exception 'Bu işlem için görevde Cumhurbaşkanı Yardımcısı olmalısın.'; end if;
 if oyun.hukumet_sistemi()=1 then
  raise exception 'Parlamenter sistemde yürütme koordinasyonu Başbakana aittir.'; end if;
 if p_tur is null or p_tur not in ('gorev','proje','kriz','kararname','toplanti','aciklama','yerel','ekonomi') then
  raise exception 'Geçersiz görev türü.'; end if;
 v_baslik:=oyun.metin_temizle(p_baslik,120);
 v_aciklama:=oyun.metin_temizle(p_aciklama,2000);
 if length(v_baslik)<5 or length(v_aciklama)<15 then raise exception 'Başlık en az 5, açıklama en az 15 karakter olmalı.'; end if;
 if p_gun is null or p_gun<1 or p_gun>14 then raise exception 'Görev süresi 1-14 gün olmalı.'; end if;
 if p_veri is null or jsonb_typeof(p_veri)<>'object' then raise exception 'İşlem verisi geçersiz.'; end if;
 v_bakan:=nullif(btrim(coalesce(p_bakanlik,'')),'');
 if v_bakan is not null and not exists(select 1 from oyun.bakanliklar where kod=v_bakan) then raise exception 'Bakanlık bulunamadı.'; end if;
 if v_bakan is not null and not oyun.cb_yrd_bakanlik_uygun(s,v_bakan) then raise exception 'Bu bakanlık görev alanının dışında.'; end if;
 if p_tur in ('gorev','proje') and v_bakan is null then raise exception 'Bakanlık görevi ve proje için bakanlık seçmelisin.'; end if;
 if p_tur='yerel' and p_il is null then raise exception 'Yerel görüşme için il seçmelisin.'; end if;
 if p_il is not null and not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl bulunamadı.'; end if;
 if p_tur='kararname' and coalesce(p_veri->>'tur','') not in ('serbest','il_destek','odenek','ikramiye','duzenleme','tahvil','ozellestirme') then
  raise exception 'Kararname türü belirtilmeli.'; end if;
 if (select count(*) from oyun.cb_yrd_dosya where yardimci=p.id and olusturma >= oyun.bugun_bas(t))>=8 then
  raise exception 'Bir yardımcı günde en fazla 8 yeni işlem açabilir.'; end if;
 if p_tur='aciklama' and exists(select 1 from oyun.cb_yrd_dosya where yardimci=p.id and tur='aciklama' and olusturma>=oyun.bugun_bas(t)) then
  raise exception 'Günde yalnız bir resmî basın açıklaması yapabilirsin.'; end if;
 if v_bakan is not null then
  select user_id into v_hedef from oyun.makamlar where tur='bakan' and bakanlik=v_bakan and bit is null order by bas desc limit 1;
 elsif p_tur='yerel' then
  select user_id into v_hedef from oyun.makamlar where tur='bel' and il_id=p_il and bit is null order by bas desc limit 1;
 end if;
 v_durum:=case when p_tur in ('kararname','ekonomi') then 'onay_bekliyor'
  when p_tur='aciklama' then 'yayimlandi' else 'bekliyor' end;
 insert into oyun.cb_yrd_dosya(cb,yardimci,sira,tur,baslik,aciklama,bakanlik,il_id,hedef,veri,durum,son_tarih,olusturma,guncelleme)
 values(c,p.id,s,p_tur,v_baslik,v_aciklama,v_bakan,p_il,v_hedef,p_veri,v_durum,t+make_interval(days=>p_gun),t,t)
 returning id into v_id;
 perform oyun.bildir(c,format('%s. yardımcın %s bir işlem açtı: %s (#%s).',s,p.kad,v_baslik,v_id),t);
 if v_hedef is not null then
  perform oyun.bildir(v_hedef,format('Cumhurbaşkanı Yardımcısı %s: %s (#%s). Yanıtını Devlet > Hükümet bölümünden ver.',p.kad,v_baslik,v_id),t);
 end if;
 if p_tur='toplanti' then
  perform oyun.bildir(m.user_id,format('Bakanlar Kurulu gündemi: %s. Toplantı çağrısı %s. Cumhurbaşkanı Yardımcısı %s.',v_baslik,v_aciklama,p.kad),t)
  from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.user_id<>p.id and m.user_id<>c;
 elsif p_tur='kriz' and v_bakan is null then
  perform oyun.bildir(m.user_id,format('Kriz masası açıldı: %s. Detay: %s',v_baslik,v_aciklama),t)
  from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.user_id<>p.id and m.user_id<>c;
 elsif p_tur='aciklama' then
  perform oyun.olay('duyuru',format('Cumhurbaşkanı Yardımcısı %s: %s — %s',p.kad,v_baslik,left(v_aciklama,300)),null,p.parti_id,t);
  perform oyun.gazete_ekle('duyuru',format('Cumhurbaşkanı Yardımcısı: %s',v_baslik),v_aciklama,v_id,t);
 end if;
 return jsonb_build_object('tamam',true,'id',v_id,'durum',v_durum);
end $fn$;

create or replace function public.cb_yrd_dosya_yanitla(p_id bigint,p_durum text,p_yanit text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.cb_yrd_dosya; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.cb_yrd_dosya where id=p_id for update;
 if d.id is null or d.cb is distinct from oyun.aktif_cb() then raise exception 'Görev dosyası bulunamadı veya hükümet değişti.'; end if;
 if d.tur not in ('gorev','proje','kriz','yerel','toplanti') or d.durum not in ('bekliyor','calisiliyor') then
  raise exception 'Bu dosyaya yanıt verilemez.'; end if;
 if not (
  (p.id=d.hedef and exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null
   and ((d.tur='yerel' and m.tur='bel' and m.il_id=d.il_id) or (m.tur='bakan' and m.bakanlik=d.bakanlik))))
  or (p.id=d.yardimci and d.tur in ('toplanti','kriz','yerel') and oyun.cb_yrd_aktif_sira(p.id)=d.sira)
  or (d.tur='toplanti' and exists(select 1 from oyun.makamlar where user_id=p.id and tur='bakan' and bit is null))
  or (d.tur='kriz' and d.bakanlik is null and exists(select 1 from oyun.makamlar where user_id=p.id and tur='bakan' and bit is null))) then
  raise exception 'Bu görev sana ait değil.'; end if;
 if p_durum not in ('calisiliyor','tamamlandi') or p_durum is null then raise exception 'Geçersiz görev durumu.'; end if;
 if char_length(btrim(coalesce(p_yanit,'')))<10 or char_length(p_yanit)>1000 then raise exception 'Yanıt 10-1000 karakter olmalı.'; end if;
 update oyun.cb_yrd_dosya set durum=p_durum,yanit=btrim(p_yanit),guncelleme=t where id=p_id;
 if d.yardimci<>p.id then perform oyun.bildir(d.yardimci,format('%s, #%s %s görevine yanıt verdi: %s',p.kad,p_id,d.baslik,p_durum),t); end if;
 if d.cb<>p.id then perform oyun.bildir(d.cb,format('%s, #%s %s görevini %s olarak bildirdi.',p.kad,p_id,d.baslik,p_durum),t); end if;
 return jsonb_build_object('tamam',true,'durum',p_durum);
end $fn$;

create or replace function public.cb_yrd_toplanti_oyla(p_id bigint,p_oy boolean,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.cb_yrd_dosya; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.cb_yrd_dosya where id=p_id;
 if d.id is null or d.cb is distinct from oyun.aktif_cb() or d.tur<>'toplanti' or d.durum not in ('bekliyor','calisiliyor') then
  raise exception 'Oy verilebilecek toplantı bulunamadı.'; end if;
 if not exists(select 1 from oyun.makamlar where user_id=p.id and bit is null and tur in ('bakan','cb','cb_yardimcisi')) then
  raise exception 'Toplantıda yalnız kabine üyeleri oy kullanabilir.'; end if;
 if p_oy is null or length(btrim(coalesce(p_gerekce,''))) not between 10 and 500 then
  raise exception 'Oy ve 10-500 karakterlik görüş gerekli.'; end if;
 insert into oyun.cb_yrd_toplanti_oy(dosya_id,user_id,oy,gerekce,zaman)
 values(p_id,p.id,p_oy,btrim(p_gerekce),t)
 on conflict (dosya_id,user_id) do update set oy=excluded.oy,gerekce=excluded.gerekce,zaman=excluded.zaman;
 perform oyun.bildir(d.yardimci,format('Bakanlar Kurulu #%s: %s oy kullandı (%s).',p_id,p.kad,case when p_oy then 'kabul' else 'ret' end),t);
 return jsonb_build_object('tamam',true,'oy',p_oy);
end $fn$;

create or replace function public.cb_yrd_dosya_karar(p_id bigint,p_kabul boolean,p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.cb_yrd_dosya; t timestamptz:=oyun.simdi();
 v_vek boolean:=false; sonuc jsonb:='{}'::jsonb;
begin
 select * into d from oyun.cb_yrd_dosya where id=p_id for update;
 if d.id is null or d.cb is distinct from oyun.aktif_cb() or d.durum<>'onay_bekliyor' then
  raise exception 'Bekleyen bir karar dosyası bulunamadı.'; end if;
 if p_kabul is null then raise exception 'Onay veya ret seçilmelidir.'; end if;
 if p.id<>d.cb then
  select exists(select 1 from oyun.cb_yrd_vekalet v
   join oyun.makamlar m on m.tur='cb_yardimcisi' and m.bit is null and m.bakanlik=v.sira::text
   where v.cb=d.cb and v.bitis>t and v.vekil=p.id and m.user_id=p.id and v.sira<>d.sira) into v_vek;
  if not v_vek or d.tur='kararname' then raise exception 'Bu kararı yalnız Cumhurbaşkanı verebilir.'; end if;
 end if;
 if p_kabul and d.tur='kararname' then
  -- Mevcut kararname motoru CB'nin günlük sınırını, mali kontrolünü ve anayasal kuralları uygular.
  sonuc:=public.kararname_cikar(d.veri->>'tur',d.baslik,d.aciklama,coalesce(d.veri->'veri','{}'::jsonb));
 end if;
 if p_gerekce is not null and length(p_gerekce)>1000 then raise exception 'Gerekçe en fazla 1000 karakter.'; end if;
 update oyun.cb_yrd_dosya set durum=case when p_kabul then 'onaylandi' else 'reddedildi' end,
  yanit=coalesce(nullif(btrim(p_gerekce),''),case when p_kabul then 'Onaylandı' else 'Reddedildi' end),
  karar_veren=p.id,guncelleme=t where id=d.id;
 perform oyun.bildir(d.yardimci,format('#%s %s önerin %s tarafından %s.',d.id,d.baslik,p.kad,case when p_kabul then 'onaylandı' else 'reddedildi' end),t);
 return jsonb_build_object('tamam',true,'durum',case when p_kabul then 'onaylandi' else 'reddedildi' end,'kararname',sonuc);
end $fn$;

create or replace function public.cb_yrd_panel()
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); c uuid:=oyun.aktif_cb();
 s smallint:=oyun.cb_yrd_aktif_sira(p.id); cb_mi boolean:=(c=p.id); bakan_mi boolean;
begin
 bakan_mi:=exists(select 1 from oyun.makamlar where tur in ('bakan','bel') and bit is null and user_id=p.id);
 if not cb_mi and s is null and not bakan_mi then raise exception 'Hükümet koordinasyonuna erişim yetkin yok.'; end if;
 return jsonb_build_object(
  'cb_miyim',cb_mi,'yardimci_sira',s,'bakan_miyim',bakan_mi,
  'kabine_miyim',exists(select 1 from oyun.makamlar where tur='bakan' and bit is null and user_id=p.id),
  'parlamenter',oyun.hukumet_sistemi()=1,
  'alanlar',(select coalesce(jsonb_agg(jsonb_build_object('sira',a.sira,'alan',a.alan,'kad',oyun.kad(m.user_id)) order by a.sira),'[]'::jsonb)
     from oyun.cb_yrd_alan a left join oyun.makamlar m on m.tur='cb_yardimcisi' and m.bit is null and m.bakanlik=a.sira::text),
  'vekalet',(select jsonb_build_object('sira',v.sira,'bitis',v.bitis) from oyun.cb_yrd_vekalet v
    join oyun.makamlar m on m.user_id=v.vekil and m.tur='cb_yardimcisi' and m.bit is null and m.bakanlik=v.sira::text
    where v.cb=c and v.bitis>oyun.simdi()),
  'dosyalar',(select coalesce(jsonb_agg(jsonb_build_object('id',z.id,'tur',z.tur,'baslik',z.baslik,'aciklama',z.aciklama,
    'yardimci',oyun.kad(z.yardimci),'sira',z.sira,'bakanlik',z.bakanlik,'il',il.ad,'hedef',oyun.kad(z.hedef),
    'veri',z.veri,'durum',z.durum,'yanit',z.yanit,'son_tarih',z.son_tarih,'olusturma',z.olusturma,
    'oylar',case when z.tur='toplanti' then (select coalesce(jsonb_agg(jsonb_build_object('kad',oyun.kad(o.user_id),'oy',o.oy,'gerekce',o.gerekce) order by o.zaman),'[]'::jsonb) from oyun.cb_yrd_toplanti_oy o where o.dosya_id=z.id) else '[]'::jsonb end) order by z.olusturma desc),'[]'::jsonb)
    from (select d.* from oyun.cb_yrd_dosya d where d.cb=c and
      (cb_mi or s is not null or d.hedef=p.id or
       (d.tur='toplanti' and bakan_mi and exists(select 1 from oyun.makamlar where user_id=p.id and tur='bakan' and bit is null)) or
       (d.tur='kriz' and bakan_mi and d.bakanlik is null and exists(select 1 from oyun.makamlar where user_id=p.id and tur='bakan' and bit is null)))
     order by d.olusturma desc limit 80) z left join oyun.iller il on il.id=z.il_id),
  'performans',(select coalesce(jsonb_agg(jsonb_build_object('sira',a.sira,
    'tamamlanan',(select count(*) from oyun.cb_yrd_dosya d where d.cb=c and d.sira=a.sira and d.durum in ('tamamlandi','onaylandi','yayimlandi') and d.olusturma>=oyun.simdi()-interval '7 days'),
    'geciken',(select count(*) from oyun.cb_yrd_dosya d where d.cb=c and d.sira=a.sira and d.durum in ('bekliyor','calisiliyor','onay_bekliyor') and d.son_tarih<oyun.simdi()),
    'puan',greatest(0,least(100,50+10*(select count(*) from oyun.cb_yrd_dosya d where d.cb=c and d.sira=a.sira and d.durum in ('tamamlandi','onaylandi','yayimlandi') and d.olusturma>=oyun.simdi()-interval '7 days')-5*(select count(*) from oyun.cb_yrd_dosya d where d.cb=c and d.sira=a.sira and d.durum in ('bekliyor','calisiliyor','onay_bekliyor') and d.son_tarih<oyun.simdi())))) order by a.sira),'[]'::jsonb)
    from oyun.cb_yrd_alan a)
 );
end $fn$;

revoke all on function public.cb_yrd_alan_ayarla(integer,text),public.cb_yrd_vekalet_ayarla(integer,integer),
 public.cb_yrd_dosya_ac(text,text,text,text,integer,integer,jsonb),public.cb_yrd_dosya_yanitla(bigint,text,text),
 public.cb_yrd_dosya_karar(bigint,boolean,text),public.cb_yrd_toplanti_oyla(bigint,boolean,text),public.cb_yrd_panel() from public,anon;
grant execute on function public.cb_yrd_alan_ayarla(integer,text),public.cb_yrd_vekalet_ayarla(integer,integer),
 public.cb_yrd_dosya_ac(text,text,text,text,integer,integer,jsonb),public.cb_yrd_dosya_yanitla(bigint,text,text),
 public.cb_yrd_dosya_karar(bigint,boolean,text),public.cb_yrd_toplanti_oyla(bigint,boolean,text),public.cb_yrd_panel() to authenticated;

commit;
