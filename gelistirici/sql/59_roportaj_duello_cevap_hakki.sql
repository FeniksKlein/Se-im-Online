-- Seçim Online: gazeteci röportajları, haberlerde cevap hakkı, canlı siyasi düellolar
create table if not exists oyun.sos_roportaj (
 id bigint generated always as identity primary key,
 gazete_id bigint not null references oyun.oyuncu_gazeteleri(id),
 gazeteci uuid not null references oyun.profiller(id),
 konuk uuid not null references oyun.profiller(id),
 baslik text not null check(char_length(baslik) between 5 and 120),
 soru text not null check(char_length(soru) between 10 and 3000),
 yanit text,
 durum text not null default 'bekliyor' check(durum in ('bekliyor','yanitlandi','reddedildi','yayinlandi')),
 acilis timestamptz not null default now(),
 yanit_at timestamptz,
 yayin_id bigint unique references oyun.gazete_yayinlari(id)
);
create index if not exists sos_roportaj_z on oyun.sos_roportaj(acilis desc);
create table if not exists oyun.sos_haber_cevap (
 yayin_id bigint not null references oyun.gazete_yayinlari(id) on delete cascade,
 oyuncu_id uuid not null references oyun.profiller(id),
 metin text check(char_length(metin) between 10 and 3000),
 zaman timestamptz,
 ekleyen uuid references oyun.profiller(id),
 primary key(yayin_id,oyuncu_id)
);
create table if not exists oyun.sos_duello (
 id bigint generated always as identity primary key,
 davet_eden uuid not null references oyun.profiller(id),
 davet_edilen uuid not null references oyun.profiller(id),
 baslik text not null check(char_length(baslik) between 5 and 120),
 durum text not null default 'davet' check(durum in ('davet','reddedildi','canli','oylama','bitti')),
 olusturma timestamptz not null default now(),
 kabul_at timestamptz,
 oylama_bas timestamptz,
 bitti_at timestamptz,
 siradaki uuid references oyun.profiller(id),
 tur_sayisi int not null default 0,
 check(davet_eden<>davet_edilen)
);
create index if not exists sos_duello_durum on oyun.sos_duello(durum,olusturma desc);
create table if not exists oyun.sos_duello_soz(
 id bigint generated always as identity primary key,
 duello_id bigint not null references oyun.sos_duello(id) on delete cascade,
 konusan uuid not null references oyun.profiller(id),
 metin text not null check(char_length(metin) between 10 and 2000),
 zaman timestamptz not null default now(),
 tur int not null,
 unique(duello_id,tur)
);
create table if not exists oyun.sos_duello_oy(
 duello_id bigint not null references oyun.sos_duello(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 tercih uuid not null references oyun.profiller(id),
 zaman timestamptz not null default now(),
 primary key(duello_id,user_id)
);
do $$ declare n text; begin
 foreach n in array array['sos_roportaj','sos_haber_cevap','sos_duello','sos_duello_soz','sos_duello_oy'] loop
 execute format('alter table oyun.%I enable row level security',n);
 execute format('revoke all on oyun.%I from public,anon,authenticated',n);
 end loop;
end $$;

create or replace function public.sos_roportajlar() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'gazete',g.ad,'gazete_id',g.id,'gazeteci',oyun.kad(r.gazeteci),'konuk',oyun.kad(r.konuk),
 'baslik',r.baslik,'soru',r.soru,'yanit',r.yanit,'durum',r.durum,'acilis',r.acilis,'yayin_id',r.yayin_id,
 'benim_gorusmem',r.gazeteci=u,'cevaplayabilirim',r.konuk=u and r.durum='bekliyor','yayinlayabilirim',r.gazeteci=u and r.durum in ('yanitlandi','reddedildi'),
 'ilgiliyim',r.gazeteci=u or r.konuk=u) order by r.id desc)
 from (select * from oyun.sos_roportaj where durum='yayinlandi' or gazeteci=u or konuk=u order by id desc limit 80) r
 join oyun.oyuncu_gazeteleri g on g.id=r.gazete_id),'[]'::jsonb);
end $$;
create or replace function public.sos_roportaj_davet(p_gazete bigint,p_kad text,p_baslik text,p_soru text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); h oyun.profiller; b text:=btrim(coalesce(p_baslik,'')); s text:=btrim(coalesce(p_soru,'')); v_gazete oyun.oyuncu_gazeteleri; rid bigint;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into v_gazete from oyun.oyuncu_gazeteleri where id=p_gazete and aktif;
 if v_gazete.id is null or not(v_gazete.sahip=u or exists(select 1 from oyun.gazete_yazarlar where gazete_id=p_gazete and user_id=u and aktif)) then
 raise exception 'Bu gazetede yazı yayımlama yetkin yok.'; end if;
 h:=oyun.profil_bul(p_kad);
 if h.id=u then raise exception 'Kendine röportaj daveti gönderemezsin.'; end if;
 if char_length(b) not between 5 and 120 or char_length(s) not between 10 and 3000 then raise exception 'Başlık 5–120, soru 10–3000 karakter olmalı.'; end if;
 if (select count(*) from oyun.sos_roportaj where gazeteci=u and acilis>t-interval '24 hours')>=5 then raise exception '24 saatte en fazla 5 röportaj daveti gönderebilirsin.'; end if;
 insert into oyun.sos_roportaj(gazete_id,gazeteci,konuk,baslik,soru,acilis) values(p_gazete,u,h.id,b,s,t) returning id into rid;
 perform oyun.bildir(h.id,format('%s, %s gazetesi adına röportaj daveti gönderdi: %s',oyun.kad(u),v_gazete.ad,b),t);
 return public.sos_roportajlar();
end $$;
create or replace function public.sos_roportaj_yanit(p_id bigint,p_kabul boolean,p_yanit text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r oyun.sos_roportaj; t timestamptz:=oyun.simdi(); yan text:=btrim(coalesce(p_yanit,''));
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into r from oyun.sos_roportaj where id=p_id for update;
 if r.id is null or r.konuk<>u or r.durum<>'bekliyor' then raise exception 'Yanıt bekleyen bir röportaj davetin yok.'; end if;
 if p_kabul and char_length(yan) not between 10 and 3000 then raise exception 'Yanıt 10–3000 karakter olmalı.'; end if;
 update oyun.sos_roportaj set durum=case when p_kabul then 'yanitlandi' else 'reddedildi' end,yanit=case when p_kabul then yan else null end,yanit_at=t where id=p_id;
 perform oyun.bildir(r.gazeteci,format('%s röportaj davetini %s.',oyun.kad(u),case when p_kabul then 'yanıtladı' else 'reddetti' end),t);
 return public.sos_roportajlar();
end $$;
create or replace function public.sos_roportaj_yayinla(p_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r oyun.sos_roportaj; g oyun.oyuncu_gazeteleri; t timestamptz:=oyun.simdi(); vid bigint;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into r from oyun.sos_roportaj where id=p_id for update;
 if r.id is null or r.gazeteci<>u or r.durum not in ('yanitlandi','reddedildi') then raise exception 'Röportaj henüz yayına uygun değil.'; end if;
 select * into g from oyun.oyuncu_gazeteleri where id=r.gazete_id;
 if g.id is null or not g.aktif or not(g.sahip=u or exists(select 1 from oyun.gazete_yazarlar where gazete_id=g.id and user_id=u and aktif)) then raise exception 'Gazetecilik yetkin sona ermiş.'; end if;
 insert into oyun.gazete_yayinlari(gazete_id,yazar,tur,baslik,metin,zaman)
 values(r.gazete_id,u,'haber',r.baslik,
 'Gazeteci: '||oyun.kad(u)||E'\nKonuk: '||oyun.kad(r.konuk)||E'\n\nSoru: '||r.soru||E'\n\n'||case when r.durum='reddedildi' then 'Konuk röportajı yanıtlamayı reddetti.' else 'Yanıt: '||r.yanit end,t)
 returning id into vid;
 update oyun.sos_roportaj set durum='yayinlandi',yayin_id=vid where id=p_id;
 insert into oyun.sos_haber_cevap(yayin_id,oyuncu_id,ekleyen) values(vid,r.konuk,u) on conflict do nothing;
 perform oyun.bildir(r.konuk,format('%s gazetesinde röportajın yayımlandı. Bir kez cevap hakkını kullanabilirsin.',g.ad),t);
 perform oyun.olay('basin',format('%s gazetesinde %s ile röportaj yayımlandı: %s',g.ad,oyun.kad(r.konuk),r.baslik),null,null,t);
 return public.sos_roportajlar();
end $$;
create or replace function public.sos_haberler() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',y.id,'gazete',g.ad,'gazete_id',g.id,'yazar',oyun.kad(y.yazar),'baslik',y.baslik,
 'metin',y.metin,'zaman',y.zaman,'hedef',oyun.kad(h.oyuncu_id),'cevap',h.metin,'cevap_at',h.zaman,
 'cevaplayabilirim',h.oyuncu_id=u and h.metin is null,'etiketleyebilirim',h.oyuncu_id is null and (g.sahip=u or y.yazar=u))
 order by y.id desc)
 from (select * from oyun.gazete_yayinlari where tur='haber' order by id desc limit 70) y
 join oyun.oyuncu_gazeteleri g on g.id=y.gazete_id
 left join lateral (select * from oyun.sos_haber_cevap where yayin_id=y.id order by oyuncu_id limit 1) h on true),'[]'::jsonb);
end $$;
create or replace function public.sos_haber_hedefle(p_yayin bigint,p_kad text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); y oyun.gazete_yayinlari; h oyun.profiller;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into y from oyun.gazete_yayinlari where id=p_yayin and tur='haber' for update;
 if y.id is null or not exists(select 1 from oyun.oyuncu_gazeteleri g where g.id=y.gazete_id and (g.sahip=u or y.yazar=u)) then raise exception 'Bu haberin sahibi veya yazarı değilsin.'; end if;
 h:=oyun.profil_bul(p_kad);
 if exists(select 1 from oyun.sos_haber_cevap where yayin_id=p_yayin) then raise exception 'Bu haberin muhatabı zaten belirlendi.'; end if;
 insert into oyun.sos_haber_cevap(yayin_id,oyuncu_id,ekleyen) values(p_yayin,h.id,u);
 perform oyun.bildir(h.id,format('“%s” haberinde muhatap gösterildin. Bir kez cevap hakkı kullanabilirsin.',y.baslik),oyun.simdi());
 return public.sos_haberler();
end $$;
create or replace function public.sos_haber_cevapla(p_yayin bigint,p_metin text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); m text:=btrim(coalesce(p_metin,'')); n int;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 if char_length(m) not between 10 and 3000 then raise exception 'Cevap 10–3000 karakter olmalı.'; end if;
 update oyun.sos_haber_cevap set metin=m,zaman=t where yayin_id=p_yayin and oyuncu_id=u and metin is null;
 get diagnostics n=row_count;
 if n<>1 then raise exception 'Bu haberde cevap hakkın yok veya daha önce kullandın.'; end if;
 return public.sos_haberler();
end $$;

create or replace function oyun.sos_duello_guncelle(p_id bigint,t timestamptz)
returns void language plpgsql set search_path='' as $$
declare d oyun.sos_duello; a int; b int; kaz text;
begin
 select * into d from oyun.sos_duello where id=p_id for update;
 if d.id is null then return; end if;
 if d.durum='davet' and t>d.olusturma+interval '24 hours' then
  update oyun.sos_duello set durum='reddedildi',bitti_at=t where id=d.id;
 elsif d.durum='canli' and (d.tur_sayisi>=6 or t>d.kabul_at+interval '24 hours') then
  update oyun.sos_duello set durum='oylama',oylama_bas=t,siradaki=null where id=d.id;
 elsif d.durum='oylama' and t>=d.oylama_bas+interval '24 hours' then
  select count(*) into a from oyun.sos_duello_oy where duello_id=d.id and tercih=d.davet_eden;
  select count(*) into b from oyun.sos_duello_oy where duello_id=d.id and tercih=d.davet_edilen;
  kaz:=case when a=b then 'Berabere' when a>b then oyun.kad(d.davet_eden) else oyun.kad(d.davet_edilen) end;
  update oyun.sos_duello set durum='bitti',bitti_at=t where id=d.id;
  perform oyun.olay('siyaset',format('“%s” siyasi tartışması sonuçlandı: %s (%s–%s).',d.baslik,kaz,a,b),null,null,t);
 end if;
end $$;
revoke all on function oyun.sos_duello_guncelle(bigint,timestamptz) from public,anon,authenticated;
create or replace function public.sos_duellolar() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); d record;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 for d in select id from oyun.sos_duello where durum in ('davet','canli','oylama') and
 (durum<>'davet' or davet_eden=u or davet_edilen=u) order by id desc limit 80 loop
 perform oyun.sos_duello_guncelle(d.id,t);
 end loop;
 return coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'baslik',d.baslik,'birinci',oyun.kad(d.davet_eden),'ikinci',oyun.kad(d.davet_edilen),
 'davet_eden',d.davet_eden,'davet_edilen',d.davet_edilen,'durum',d.durum,'olusturma',d.olusturma,'kabul_at',d.kabul_at,
 'oylama_bas',d.oylama_bas,'tur_sayisi',d.tur_sayisi,'sira_bende',d.durum='canli' and d.siradaki=u,
 'davet_bende',d.durum='davet' and d.davet_edilen=u,'benim_oyum',(select tercih from oyun.sos_duello_oy where duello_id=d.id and user_id=u),
 'oy_bir',(select count(*) from oyun.sos_duello_oy where duello_id=d.id and tercih=d.davet_eden),
 'oy_iki',(select count(*) from oyun.sos_duello_oy where duello_id=d.id and tercih=d.davet_edilen),
 'sozler',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(s.konusan),'metin',s.metin,'tur',s.tur,'zaman',s.zaman) order by s.tur)
 from oyun.sos_duello_soz s where s.duello_id=d.id),'[]'::jsonb)) order by d.id desc)
 from (select * from oyun.sos_duello where durum<>'davet' or davet_eden=u or davet_edilen=u order by id desc limit 80) d),'[]'::jsonb);
end $$;
create or replace function public.sos_duello_davet(p_kad text,p_baslik text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); h oyun.profiller; b text:=btrim(coalesce(p_baslik,'')); pid bigint;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 h:=oyun.profil_bul(p_kad);
 if h.id=u then raise exception 'Kendinle tartışamazsın.'; end if;
 if char_length(b) not between 5 and 120 then raise exception 'Konu 5–120 karakter olmalı.'; end if;
 if (select count(*) from oyun.sos_duello where davet_eden=u and olusturma>t-interval '24 hours')>=3 then raise exception '24 saatte en fazla üç düello daveti gönderebilirsin.'; end if;
 if not(exists(select 1 from oyun.partiler where gb=u and not kapali)
 or exists(select 1 from oyun.makamlar where user_id=u and tur in ('cb','bel','mv','bakan') and bit is null)
 or exists(select 1 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id where a.user_id=u and s.durum='bekliyor' and s.oy_bit>t)) then raise exception 'Canlı siyasi tartışma davetini yalnız parti başkanları, adaylar veya görevdeki siyasetçiler gönderebilir.'; end if;
 insert into oyun.sos_duello(davet_eden,davet_edilen,baslik,olusturma) values(u,h.id,b,t) returning id into pid;
 perform oyun.bildir(h.id,format('%s seni canlı siyasi tartışmaya davet etti: %s',oyun.kad(u),b),t);
 return public.sos_duellolar();
end $$;
create or replace function public.sos_duello_yanit(p_id bigint,p_kabul boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d oyun.sos_duello; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into d from oyun.sos_duello where id=p_id for update;
 if d.id is null or d.davet_edilen<>u or d.durum<>'davet' or d.olusturma<t-interval '24 hours' then raise exception 'Geçerli tartışma davetin yok.'; end if;
 update oyun.sos_duello set durum=case when p_kabul then 'canli' else 'reddedildi' end,kabul_at=case when p_kabul then t else null end,siradaki=case when p_kabul then d.davet_eden else null end,bitti_at=case when not p_kabul then t else null end where id=p_id;
 perform oyun.bildir(d.davet_eden,format('%s tartışma davetini %s.',oyun.kad(u),case when p_kabul then 'kabul etti' else 'reddetti' end),t);
 if p_kabul then perform oyun.olay('siyaset',format('%s ve %s arasında canlı siyasi tartışma başladı: %s',oyun.kad(d.davet_eden),oyun.kad(u),d.baslik),null,null,t); end if;
 return public.sos_duellolar();
end $$;
create or replace function public.sos_duello_konus(p_id bigint,p_metin text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d oyun.sos_duello; t timestamptz:=oyun.simdi(); msg text:=btrim(coalesce(p_metin,''));
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into d from oyun.sos_duello where id=p_id for update;
 if d.id is null or d.durum<>'canli' or d.siradaki is distinct from u or d.tur_sayisi>=6 or t>d.kabul_at+interval '24 hours' then raise exception 'Şu anda konuşma sırası sende değil.'; end if;
 if char_length(msg) not between 10 and 2000 then raise exception 'Konuşma 10–2000 karakter olmalı.'; end if;
 insert into oyun.sos_duello_soz(duello_id,konusan,metin,zaman,tur) values(d.id,u,msg,t,d.tur_sayisi+1);
 update oyun.sos_duello set tur_sayisi=tur_sayisi+1,siradaki=case when u=d.davet_eden then d.davet_edilen else d.davet_eden end where id=d.id;
 perform oyun.sos_duello_guncelle(d.id,t);
 return public.sos_duellolar();
end $$;
create or replace function public.sos_duello_oyla(p_id bigint,p_aday uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d oyun.sos_duello; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into d from oyun.sos_duello where id=p_id for update;
 if d.id is null or d.durum<>'oylama' or t>=d.oylama_bas+interval '24 hours' then raise exception 'Halk oylaması açık değil.'; end if;
 if u in (d.davet_eden,d.davet_edilen) then raise exception 'Tartışmanın tarafları oy veremez.'; end if;
 if p_aday is distinct from d.davet_eden and p_aday is distinct from d.davet_edilen then raise exception 'Geçersiz tercih.'; end if;
 insert into oyun.sos_duello_oy(duello_id,user_id,tercih,zaman) values(d.id,u,p_aday,t) on conflict do nothing;
 if not found then raise exception 'Bu tartışmada oyun zaten kayıtlı.'; end if;
 return public.sos_duellolar();
end $$;
do $$ declare f text; begin
 foreach f in array array[
 'sos_roportajlar()','sos_roportaj_davet(bigint,text,text,text)','sos_roportaj_yanit(bigint,boolean,text)','sos_roportaj_yayinla(bigint)',
 'sos_haberler()','sos_haber_hedefle(bigint,text)','sos_haber_cevapla(bigint,text)',
 'sos_duellolar()','sos_duello_davet(text,text)','sos_duello_yanit(bigint,boolean)','sos_duello_konus(bigint,text)','sos_duello_oyla(bigint,uuid)'
 ] loop execute 'revoke all on function public.'||f||' from public,anon'; execute 'grant execute on function public.'||f||' to authenticated'; end loop;
end $$;
