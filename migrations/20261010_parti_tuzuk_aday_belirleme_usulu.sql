-- 2026-10-10 | Parti tuzugune bagli MV / belediye aday belirleme usulu.
-- Mevcut oyuncular, adayliklar, oylar ve secim tarihleri degistirilmez.
begin;
alter table oyun.partiler add column if not exists mv_aday_yontemi text not null default 'onsecim'
  check (mv_aday_yontemi in ('onsecim','genel_baskan'));
alter table oyun.partiler add column if not exists bel_aday_yontemi text not null default 'onsecim'
  check (bel_aday_yontemi in ('onsecim','genel_baskan'));
alter table oyun.partiler add column if not exists kurulus_aday_yontemi_kullanildi boolean not null default false;
alter table oyun.parti_tuzuk_teklifleri add column if not exists mv_aday_yontemi text
  check (mv_aday_yontemi is null or mv_aday_yontemi in ('onsecim','genel_baskan'));
alter table oyun.parti_tuzuk_teklifleri add column if not exists bel_aday_yontemi text
  check (bel_aday_yontemi is null or bel_aday_yontemi in ('onsecim','genel_baskan'));

-- Basvurular basladiktan sonraki tuzuk degisikligi acik secimi etkilemez.
create table if not exists oyun.parti_aday_usul_donem(
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  secim_id bigint not null references oyun.secimler(id) on delete cascade,
  yontem text not null check(yontem in ('onsecim','genel_baskan')),
  primary key(parti_id,secim_id)
);
alter table oyun.parti_aday_usul_donem enable row level security;
revoke all on oyun.parti_aday_usul_donem from public,anon,authenticated;

create table if not exists oyun.parti_aday_atama(
  secim_id bigint not null references oyun.secimler(id) on delete cascade,
  aday_id bigint not null references oyun.adaylar(id) on delete cascade,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  il_id smallint not null references oyun.iller(id),
  sira int not null check(sira between 1 and 1000),
  belirleyen uuid not null references oyun.profiller(id),
  zaman timestamptz not null default now(),
  primary key(secim_id,aday_id),
  unique(secim_id,parti_id,il_id,sira)
);
create index if not exists parti_aday_atama_il on oyun.parti_aday_atama(secim_id,parti_id,il_id,sira);
alter table oyun.parti_aday_atama enable row level security;
revoke all on oyun.parti_aday_atama from public,anon,authenticated;

create or replace function oyun.parti_aday_usul(p_parti bigint,p_secim bigint)
returns text language sql stable set search_path='' as $$
 select coalesce(
   (select u.yontem from oyun.parti_aday_usul_donem u where u.parti_id=p_parti and u.secim_id=p_secim),
   (select case when s.tur='mv_on' then pa.mv_aday_yontemi else pa.bel_aday_yontemi end
    from oyun.partiler pa cross join oyun.secimler s where pa.id=p_parti and s.id=p_secim)
 )
$$;

-- Tüzük oylamasında yöntem değişikliği ancak teklif kabul edilirse yürür.
create or replace function oyun.parti_tuzuk_tick(t timestamptz)
returns void language plpgsql set search_path='' as $$
declare x oyun.parti_tuzuk_teklifleri; e int; h int; k int; kabul boolean;
begin
 for x in select * from oyun.parti_tuzuk_teklifleri
     where durum='oylama' and bit<=t order by id for update
 loop
   select count(*) filter(where oy='evet'),count(*) filter(where oy='hayir'),count(*)
     into e,h,k from oyun.parti_tuzuk_oylari where teklif_id=x.id;
   kabul:=e>h and e>0;
   update oyun.parti_tuzuk_teklifleri
   set durum=case when kabul then 'kabul' else 'ret' end,
       evet=e,hayir=h,katilim=k,sonuc_at=t where id=x.id;
   if kabul then
     -- Acilmis onsecimler o andaki tüzük yöntemini korur.
     insert into oyun.parti_aday_usul_donem(parti_id,secim_id,yontem)
     select x.parti_id,s.id,
       case when s.tur='mv_on' then pa.mv_aday_yontemi else pa.bel_aday_yontemi end
     from oyun.secimler s cross join oyun.partiler pa
     where pa.id=x.parti_id and s.tur in ('mv_on','bel_on')
       and s.durum='bekliyor' and s.basvuru_bas<=t and s.sonuc_at>t
     on conflict do nothing;
     update oyun.partiler set tuzuk=x.metin,tuzuk_at=t,
       mv_aday_yontemi=coalesce(x.mv_aday_yontemi,mv_aday_yontemi),
       bel_aday_yontemi=coalesce(x.bel_aday_yontemi,bel_aday_yontemi)
     where id=x.parti_id;
   end if;
   insert into oyun.bildirimler(user_id,zaman,metin)
   select id,t,format('Parti tüzük oylaması sonuçlandı: %s — %s Evet, %s Hayır.',
     case when kabul then 'KABUL' else 'RET' end,e,h)
   from oyun.profiller where parti_id=x.parti_id;
   perform oyun.olay('parti',format('%s tüzük oylaması sonuçlandı: %s (%s Evet / %s Hayır).',
     (select kisa from oyun.partiler where id=x.parti_id),
     case when kabul then 'kabul' else 'ret' end,e,h),null,x.parti_id,t);
 end loop;
end $$;

create or replace function public.parti_aday_yontem_teklif(
 p_baslik text,p_metin text,p_mv_yontem text,p_bel_yontem text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
 pa oyun.partiler; b text; m text;
begin
 perform oyun.parti_tuzuk_tick(t);
 select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
 if pa.id is null or pa.gb is distinct from p.id then
   raise exception 'Yalnızca genel başkan tüzük değişikliği teklif edebilir.'; end if;
 if exists(select 1 from oyun.parti_tuzuk_teklifleri where parti_id=pa.id and durum='oylama') then
   raise exception 'Partide devam eden bir tüzük oylaması var.'; end if;
 if p_mv_yontem not in ('onsecim','genel_baskan') or p_bel_yontem not in ('onsecim','genel_baskan')
    or p_mv_yontem is null or p_bel_yontem is null then
   raise exception 'Aday belirleme yöntemi geçersiz.'; end if;
 b:=btrim(coalesce(p_baslik,''));
 if length(b)<5 or length(b)>100 or oyun.kufurlu(b) then raise exception 'Tüzük başlığı geçersiz.'; end if;
 m:=oyun.metin_temizle(p_metin,6000);
 if length(m)<50 then raise exception 'Tüzük en az 50 karakter olmalı.'; end if;
 insert into oyun.parti_tuzuk_teklifleri
 (parti_id,baslik,metin,teklif_eden,bas,bit,mv_aday_yontemi,bel_aday_yontemi)
 values(pa.id,b,m,p.id,t,t+interval '24 hours',p_mv_yontem,p_bel_yontem);
 insert into oyun.bildirimler(user_id,zaman,metin)
 select id,t,format('%s genel başkanı aday belirleme usulünü de içeren tüzüğü oylamaya sundu.',pa.kisa)
 from oyun.profiller where parti_id=pa.id and id<>p.id and parti_at<=t;
 perform oyun.olay('parti',format('%s aday belirleme usulünü değiştirebilen yeni tüzüğü üyelerine sundu.',pa.kisa),null,pa.id,t);
 return public.parti_tuzuk(pa.id);
end $$;

-- Parti kurucusu bir kez, kuruluşun ilk yedi gününde usul belirleyebilir.
create or replace function public.parti_kurulus_aday_yontemi(p_mv_yontem text,p_bel_yontem text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); pa oyun.partiler; t timestamptz:=oyun.simdi();
begin
 if p_mv_yontem not in ('onsecim','genel_baskan') or p_bel_yontem not in ('onsecim','genel_baskan')
    or p_mv_yontem is null or p_bel_yontem is null then raise exception 'Geçersiz yöntem.'; end if;
 select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
 if pa.id is null or pa.kurucu is distinct from p.id or pa.gb is distinct from p.id
   or pa.sistem or pa.kurulus_bit is not null or pa.kurulus_aday_yontemi_kullanildi
   or t>pa.kurulus+interval '7 days' then
   raise exception 'Kurucuya tanınan tek seferlik aday belirleme yetkisi kullanılmış veya süresi dolmuş.'; end if;
 if exists(select 1 from oyun.secimler s where s.tur in ('mv_on','bel_on')
   and s.durum='bekliyor' and s.basvuru_bas<=t and s.sonuc_at>t) then
   raise exception 'Açık önseçim sırasında yöntem değiştirilemez; tüzük teklifini kullan.'; end if;
 update oyun.partiler set mv_aday_yontemi=p_mv_yontem,bel_aday_yontemi=p_bel_yontem,
   kurulus_aday_yontemi_kullanildi=true where id=pa.id;
 perform oyun.olay('parti',format('%s kurucusu ilk aday belirleme yöntemini kararlaştırdı.',pa.kisa),null,pa.id,t);
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.parti_aday_yonetimi(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); pa oyun.partiler; t timestamptz:=oyun.simdi();
begin
 select * into pa from oyun.partiler where id=p_parti and not kapali;
 if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
 return jsonb_build_object(
  'parti_id',pa.id,'gb',pa.gb=p.id,
  'mv_yontem',pa.mv_aday_yontemi,'bel_yontem',pa.bel_aday_yontemi,
  'kurulus_hakki',pa.kurucu=p.id and pa.gb=p.id and not pa.sistem
      and pa.kurulus_bit is null and not pa.kurulus_aday_yontemi_kullanildi
      and t<=pa.kurulus+interval '7 days'
      and not exists(select 1 from oyun.secimler s where s.tur in ('mv_on','bel_on')
         and s.durum='bekliyor' and s.basvuru_bas<=t and s.sonuc_at>t),
  'aktif',coalesce((select jsonb_agg(jsonb_build_object(
    'secim_id',s.id,'tur',s.tur,'donem',s.donem,'basvuru_bas',s.basvuru_bas,'oy_bit',s.oy_bit,
    'yontem',oyun.parti_aday_usul(pa.id,s.id),
    'iller',coalesce((select jsonb_agg(jsonb_build_object(
      'il_id',i.id,'il',i.ad,'kontenjan',case when s.tur='mv_on' then coalesce(i.mv_secim,i.mv) else 1 end,
      'adaylar',coalesce((select jsonb_agg(jsonb_build_object(
         'id',a.id,'kad',pr.kad,'sira',(select n.sira from oyun.parti_aday_atama n where n.secim_id=s.id and n.aday_id=a.id)
       ) order by a.basvuru_at,a.id) from oyun.adaylar a join oyun.profiller pr on pr.id=a.user_id
        where a.secim_id=s.id and a.parti_id=pa.id and a.il_id=i.id),'[]'::jsonb)
      ) order by i.id) from oyun.iller i
      where exists(select 1 from oyun.adaylar a where a.secim_id=s.id and a.parti_id=pa.id and a.il_id=i.id)),'[]'::jsonb)
    ) order by s.oy_bas)
    from oyun.secimler s where s.tur in ('mv_on','bel_on') and s.durum='bekliyor'
      and s.basvuru_bas<=t and s.sonuc_at>t),'[]'::jsonb)
 );
end $$;

create or replace function public.parti_aday_listesi_kaydet(p_secim bigint,p_il integer,p_adaylar bigint[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); pa oyun.partiler; s oyun.secimler;
 i oyun.iller; t timestamptz:=oyun.simdi(); n int; gec int;
begin
 select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
 if pa.id is null or pa.gb is distinct from p.id then raise exception 'Aday listesini yalnızca genel başkan belirler.'; end if;
 select * into s from oyun.secimler where id=p_secim and tur in ('mv_on','bel_on') for update;
 if s.id is null or s.durum<>'bekliyor' or t<s.basvuru_bas or t>=s.oy_bit then
   raise exception 'Bu dönem için aday belirleme süresi kapalı.'; end if;
 if oyun.parti_aday_usul(pa.id,s.id)<>'genel_baskan' then
   raise exception 'Parti tüzüğüne göre adaylar önseçimle belirlenir.'; end if;
 select * into i from oyun.iller where id=p_il;
 if i.id is null then raise exception 'İl bulunamadı.'; end if;
 n:=coalesce(cardinality(p_adaylar),0);
 if n>(case when s.tur='mv_on' then coalesce(i.mv_secim,i.mv) else 1 end) then
   raise exception 'İl aday kontenjanı aşıldı.'; end if;
 if n<> (select count(distinct a.id) from oyun.adaylar a
   where a.id=any(coalesce(p_adaylar,'{}'::bigint[])) and a.secim_id=s.id
     and a.parti_id=pa.id and a.il_id=i.id) then
   raise exception 'Listede başka parti/il adayı veya mükerrer kişi bulunuyor.'; end if;
 -- Adaylar kendileri basvurdugu icin rizalari alinmistir.
 delete from oyun.parti_aday_atama where secim_id=s.id and parti_id=pa.id and il_id=i.id;
 insert into oyun.parti_aday_atama(secim_id,aday_id,parti_id,il_id,sira,belirleyen,zaman)
 select s.id,x.aday_id,pa.id,i.id,x.sira::int,p.id,t
 from unnest(coalesce(p_adaylar,'{}'::bigint[])) with ordinality as x(aday_id,sira);
 perform oyun.olay('parti',format('%s %s için %s adaylık listesini belirledi.',
   pa.kisa,i.ad,case when s.tur='mv_on' then 'milletvekili' else 'belediye başkanı' end),i.id,pa.id,t);
 return public.parti_aday_yonetimi(pa.id);
end $$;

-- Onsecim oyuna genel baskan usulunde izin yok; server guvenligi.
create or replace function oyun.parti_atama_onsecim_oy_koru() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_tur text;
begin
 select tur into v_tur from oyun.secimler where id=new.secim_id;
 if v_tur in ('mv_on','bel_on') and new.parti_id is not null
    and oyun.parti_aday_usul(new.parti_id,new.secim_id)='genel_baskan' then
    raise exception 'Bu partinin tüzüğüne göre adayları genel başkan belirler; önseçim yapılmaz.';
 end if;
 return new;
end $$;
drop trigger if exists parti_atama_onsecim_oy_koru on oyun.oylar;
create trigger parti_atama_onsecim_oy_koru
 before insert on oyun.oylar for each row execute function oyun.parti_atama_onsecim_oy_koru();

-- Seçim motoru, tüzük usulüne göre yalnızca atanmış MV listesini sıralar.
create or replace function oyun._sonuc_mv_on(s oyun.secimler) returns jsonb
language plpgsql set search_path='' as $$
begin
 perform oyun.aday_oylarini_say(s.id);
 update oyun.adaylar a set sira=case
   when oyun.parti_aday_usul(a.parti_id,s.id)='genel_baskan'
     then (select at.sira from oyun.parti_aday_atama at where at.secim_id=s.id and at.aday_id=a.id)
   else x.rn end
 from (select id,row_number() over(partition by il_id,parti_id order by oy desc,basvuru_at,id) rn
       from oyun.adaylar where secim_id=s.id) x
 where a.id=x.id;
 return jsonb_build_object(
   'katilim',(select count(*) from oyun.oylar where secim_id=s.id),
   'aday',(select count(*) from oyun.adaylar where secim_id=s.id),
   'liste',(select count(distinct(il_id,parti_id)) from oyun.adaylar where secim_id=s.id and sira is not null)
 );
end $$;

-- Belediye usulunde dogrudan atanan aday kazanmis parti adayi olarak genel secime cikar.
create or replace function oyun._sonuc_tek_kazanan_on(s oyun.secimler,p_hedef_tur text)
returns jsonb language plpgsql set search_path='' as $$
declare hedef oyun.secimler; r record; n int:=0;
begin
 perform oyun.aday_oylarini_say(s.id);
 select * into hedef from oyun.secimler where tur=p_hedef_tur and donem=s.donem;
 for r in
   select distinct on (coalesce(il_id,0),parti_id) *
   from oyun.adaylar where secim_id=s.id
   order by coalesce(il_id,0),parti_id,oy desc,basvuru_at,id
 loop
   if p_hedef_tur='bel' and oyun.parti_aday_usul(r.parti_id,s.id)='genel_baskan' then continue; end if;
   if p_hedef_tur='cb' and exists(
     select 1 from oyun.cb_kararlar k where k.donem=s.donem and k.parti_id=r.parti_id and k.yontem<>'onsecim')
     then continue; end if;
   if p_hedef_tur='cb' and exists(select 1 from oyun.adaylar a where a.secim_id=hedef.id and a.parti_id=r.parti_id)
     then continue; end if;
   insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,basvuru_at,vaat)
   values(hedef.id,r.user_id,r.parti_id,r.il_id,r.basvuru_at,r.vaat)
   on conflict(secim_id,user_id) do nothing;
   n:=n+1;
 end loop;
 if p_hedef_tur='bel' then
   for r in select a.* from oyun.parti_aday_atama at
     join oyun.adaylar a on a.id=at.aday_id
     where at.secim_id=s.id and oyun.parti_aday_usul(at.parti_id,s.id)='genel_baskan'
   loop
     insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,basvuru_at,vaat)
     values(hedef.id,r.user_id,r.parti_id,r.il_id,r.basvuru_at,r.vaat)
     on conflict(secim_id,user_id) do nothing;
     n:=n+1;
   end loop;
 end if;
 return jsonb_build_object('katilim',(select count(*) from oyun.oylar where secim_id=s.id),
                           'aday',(select count(*) from oyun.adaylar where secim_id=s.id),'kazanan',n);
end $$;

revoke all on function public.parti_aday_yontem_teklif(text,text,text,text) from public,anon;
grant execute on function public.parti_aday_yontem_teklif(text,text,text,text) to authenticated;
revoke all on function public.parti_kurulus_aday_yontemi(text,text) from public,anon;
grant execute on function public.parti_kurulus_aday_yontemi(text,text) to authenticated;
revoke all on function public.parti_aday_yonetimi(bigint) from public,anon;
grant execute on function public.parti_aday_yonetimi(bigint) to authenticated;
revoke all on function public.parti_aday_listesi_kaydet(bigint,integer,bigint[]) from public,anon;
grant execute on function public.parti_aday_listesi_kaydet(bigint,integer,bigint[]) to authenticated;
commit;
