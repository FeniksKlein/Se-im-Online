
-- Parti birleşmesi ve il bazında ortak MV listesi. Oyun verilerine dokunulmaz.
create table if not exists oyun.parti_birlesmeler(
 id bigint generated always as identity primary key,
 kaynak_parti bigint not null references oyun.partiler(id),
 hedef_parti bigint not null references oyun.partiler(id),
 teklif_eden uuid not null references oyun.profiller(id),
 durum text not null default 'bekliyor' check(durum in ('bekliyor','kabul','ret','iptal')),
 teklif_at timestamptz not null default now(),
 karar_at timestamptz,
 tasinan_kasa numeric not null default 0,
 tasinan_uye int not null default 0,
 check(kaynak_parti<>hedef_parti)
);
create index if not exists parti_birlesme_aktif_idx on oyun.parti_birlesmeler(kaynak_parti,hedef_parti,durum);
create table if not exists oyun.parti_birlesme_uyeleri(
 birlesme_id bigint not null references oyun.parti_birlesmeler(id),
 user_id uuid not null references oyun.profiller(id),
 eski_parti bigint not null references oyun.partiler(id),
 yeni_parti bigint not null references oyun.partiler(id),
 birlesme_at timestamptz not null default now(),
 primary key(birlesme_id,user_id)
);
create table if not exists oyun.mv_ortak_listeler(
 id bigint generated always as identity primary key,
 secim_id bigint not null references oyun.secimler(id),
 il_id smallint not null references oyun.iller(id),
 teklif_eden_parti bigint not null references oyun.partiler(id),
 ortak_parti bigint not null references oyun.partiler(id),
 lider_parti bigint not null references oyun.partiler(id),
 durum text not null default 'bekliyor' check(durum in ('bekliyor','kabul','ret','iptal')),
 teklif_at timestamptz not null default now(),
 karar_at timestamptz,
 check(teklif_eden_parti<>ortak_parti),
 check(lider_parti in (teklif_eden_parti,ortak_parti))
);
create index if not exists mv_ortak_listeler_lookup on oyun.mv_ortak_listeler(secim_id,il_id,durum);
do $body$
declare n text;
begin
 foreach n in array array['parti_birlesmeler','parti_birlesme_uyeleri','mv_ortak_listeler'] loop
  execute format('alter table oyun.%I enable row level security',n);
  execute format('revoke all on oyun.%I from public,anon,authenticated',n);
  if to_regprocedure('oyun.bosaltma_korumasi()') is not null then
   execute format('drop trigger if exists bosaltma_korumasi on oyun.%I',n);
   execute format('create trigger bosaltma_korumasi before truncate on oyun.%I for each statement execute function oyun.bosaltma_korumasi()',n);
  end if;
 end loop;
end $body$;
-- Birleşme, adaylıklar açıkken ve sandık sürecinde yapılamaz.
create or replace function oyun.parti_birlesme_kilit(t timestamptz) returns text
language sql stable set search_path='' as $body$
 select 'Adaylık, önseçim veya oy verme süreci devam ederken parti birleşmesi yapılamaz.'
 where exists(select 1 from oyun.secimler s
  where s.durum='bekliyor' and s.tur in ('mv','mv_on','bel','bel_on','cb')
   and t>=coalesce(s.basvuru_bas,s.oy_bas) and t<s.sonuc_at)
$body$;
create or replace function oyun.mv_ortak_liste_partisi(p_secim bigint,p_il smallint,p_parti bigint) returns bigint
language sql stable set search_path='' as $body$
 select coalesce((select m.lider_parti from oyun.mv_ortak_listeler m
   where m.secim_id=p_secim and m.il_id=p_il and m.durum='kabul'
    and p_parti in(m.teklif_eden_parti,m.ortak_parti)
   order by m.id desc limit 1),p_parti)
$body$;
create or replace function public.parti_isbirligi_durum(p_parti bigint) returns jsonb
language plpgsql security definer set search_path='' as $body$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
begin
 return jsonb_build_object(
  'gb_miyim',exists(select 1 from oyun.partiler where id=p_parti and gb=p.id and not kapali),
  'birlesme_kilit',oyun.parti_birlesme_kilit(t),
  'birlesmeler',coalesce((select jsonb_agg(jsonb_build_object(
   'id',b.id,'kaynak',oyun.parti_json(b.kaynak_parti),'hedef',oyun.parti_json(b.hedef_parti),
   'durum',b.durum,'teklif_at',b.teklif_at,'tasınan_uye',b.tasinan_uye,
   'tasinan_kasa',b.tasinan_kasa,'yanitlayabilirim',b.durum='bekliyor' and p.parti_id=b.hedef_parti
      and exists(select 1 from oyun.partiler where id=b.hedef_parti and gb=p.id),
   'iptal_edebilirim',b.durum='bekliyor' and b.teklif_eden=p.id) order by b.id desc)
   from (select * from oyun.parti_birlesmeler where kaynak_parti=p_parti or hedef_parti=p_parti order by id desc limit 20) b),'[]'::jsonb),
  'mv_secim', (select jsonb_build_object('id',s.id,'donem',s.donem,'oy_bas',s.oy_bas)
                from oyun.secimler s where s.tur='mv' and s.durum='bekliyor' and s.oy_bas>t
                order by s.oy_bas limit 1),
  'ortak_listeler',coalesce((select jsonb_agg(jsonb_build_object(
   'id',x.id,'secim_id',x.secim_id,'il_id',x.il_id,'il',(select ad from oyun.iller where id=x.il_id),
   'teklif_eden',oyun.parti_json(x.teklif_eden_parti),'ortak',oyun.parti_json(x.ortak_parti),
   'lider',oyun.parti_json(x.lider_parti),'durum',x.durum,'teklif_at',x.teklif_at,
   'yanitlayabilirim',x.durum='bekliyor' and p.parti_id=x.ortak_parti and exists(select 1 from oyun.partiler where id=x.ortak_parti and gb=p.id),
   'iptal_edebilirim',x.durum='bekliyor' and exists(select 1 from oyun.partiler where id=x.teklif_eden_parti and gb=p.id)
   ) order by x.il_id,x.id desc)
   from oyun.mv_ortak_listeler x
   where (x.teklif_eden_parti=p_parti or x.ortak_parti=p_parti)
    and (x.durum='bekliyor' or (x.durum='kabul' and exists(select 1 from oyun.secimler s where s.id=x.secim_id and s.sonuc_at>t)) or x.karar_at>t-interval '7 days')),'[]'::jsonb)
 );
end $body$;
create or replace function public.parti_birlesme_teklif(p_hedef bigint) returns jsonb
language plpgsql security definer set search_path='' as $body$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); kaynak oyun.partiler; hedef oyun.partiler; kilit text;
begin
 kaynak:=oyun.gb_partim(p); 
 kilit:=oyun.parti_birlesme_kilit(t); if kilit is not null then raise exception '%',kilit; end if;
 select * into hedef from oyun.partiler where id=p_hedef and not kapali and gb is not null;
 if hedef.id is null or hedef.id=kaynak.id then raise exception 'Birleşilecek partinin aktif bir genel başkanı bulunmalı.'; end if;
 if kaynak.kurulus_bit is not null or hedef.kurulus_bit is not null then raise exception 'Kuruluşu tamamlanmamış partiler birleşemez.'; end if;
 if exists(select 1 from oyun.parti_birlesmeler b where b.durum='bekliyor' and 
 (kaynak.id in(b.kaynak_parti,b.hedef_parti) or hedef.id in(b.kaynak_parti,b.hedef_parti))) then
  raise exception 'Taraflardan birinin bekleyen birleşme teklifi var.'; end if;
 insert into oyun.parti_birlesmeler(kaynak_parti,hedef_parti,teklif_eden,teklif_at)
 values(kaynak.id,hedef.id,p.id,t);
 perform oyun.bildir(hedef.gb,format('%s partisi senin partine katılarak birleşmek istiyor. Parti sayfandan kabul et / reddet.',kaynak.kisa),t);
 perform oyun.olay('parti',format('%s, %s ile birleşme görüşmelerini başlattı.',kaynak.kisa,hedef.kisa),null,kaynak.id,t);
 return public.parti_isbirligi_durum(kaynak.id);
end $body$;
create or replace function public.parti_birlesme_iptal(p_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $body$
declare p oyun.profiller:=oyun.profilim(); b oyun.parti_birlesmeler;
begin
 select * into b from oyun.parti_birlesmeler where id=p_id for update;
 if b.id is null or b.durum<>'bekliyor' or b.teklif_eden<>p.id
   or not exists(select 1 from oyun.partiler where id=b.kaynak_parti and gb=p.id and not kapali) then
  raise exception 'Bu birleşme teklifini iptal edemezsin.'; end if;
 update oyun.parti_birlesmeler set durum='iptal',karar_at=oyun.simdi() where id=p_id;
 return public.parti_isbirligi_durum(b.kaynak_parti);
end $body$;
create or replace function public.parti_birlesme_yanit(p_id bigint,p_kabul boolean) returns jsonb
language plpgsql security definer set search_path='' as $body$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); b oyun.parti_birlesmeler;
 k oyun.partiler; h oyun.partiler; kilit text; n int; para numeric;
begin
 select * into b from oyun.parti_birlesmeler where id=p_id for update;
 if b.id is null or b.durum<>'bekliyor' then raise exception 'Yanıt bekleyen birleşme teklifi yok.'; end if;
 if not exists(select 1 from oyun.partiler where id=b.hedef_parti and gb=p.id and not kapali) then
  raise exception 'Birleşmeyi yalnız hedef partinin genel başkanı kabul edebilir.'; end if;
 if not p_kabul then
   update oyun.parti_birlesmeler set durum='ret',karar_at=t where id=b.id;
   perform oyun.bildir(b.teklif_eden,'Parti birleşmesi teklifin reddedildi.',t);
   return public.parti_isbirligi_durum(b.hedef_parti);
 end if;
 kilit:=oyun.parti_birlesme_kilit(t); if kilit is not null then raise exception '%',kilit; end if;
 -- Eş zamanlı kabul/teklif işlemlerini parti satırlarını sırayla kilitleyerek koru.
 perform id from oyun.partiler where id in(b.kaynak_parti,b.hedef_parti) order by id for update;
 select * into k from oyun.partiler where id=b.kaynak_parti;
 select * into h from oyun.partiler where id=b.hedef_parti;
 if k.kapali or h.kapali or k.gb<>b.teklif_eden or h.gb<>p.id then
  raise exception 'Birleşme teklifi hazırlanırken parti başkanları veya durumları değişmiş.'; end if;
 if k.kurulus_bit is not null or h.kurulus_bit is not null then raise exception 'Kuruluş aşamasındaki parti birleşemez.'; end if;
 para:=k.kasa;
 insert into oyun.parti_birlesme_uyeleri(birlesme_id,user_id,eski_parti,yeni_parti,birlesme_at)
 select b.id,id,k.id,h.id,t from oyun.profiller where parti_id=k.id;
 get diagnostics n=row_count;
 update oyun.profiller set parti_id=h.id where parti_id=k.id;
 -- Geçmiş seçim sonuçları değişmez; halen devam eden milletvekilliği gibi makamlar yeni partiye geçer.
 update oyun.makamlar set parti_id=h.id where parti_id=k.id and bit is null;
 update oyun.partiler set kasa=kasa+para where id=h.id;
 insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
 values(h.id,t,para,format('%s ile birleşmeden devralınan kasa',k.kisa),'birlesme');
 update oyun.partiler set kasa=0,kapali=true,gb=null where id=k.id;
 perform oyun.ittifak_temizle();
 update oyun.parti_birlesmeler set durum='iptal',karar_at=t
   where durum='bekliyor' and id<>b.id
    and (kaynak_parti in(k.id,h.id) or hedef_parti in(k.id,h.id));
 update oyun.parti_birlesmeler set durum='kabul',karar_at=t,tasinan_kasa=para,tasinan_uye=n where id=b.id;
 insert into oyun.bildirimler(user_id,zaman,metin)
 select id,t,format('%s partisi %s ile birleşti. Parti üyeliğin, makamın ve oyun paran korunuyor.',k.kisa,h.kisa)
 from oyun.profiller where parti_id=h.id;
 perform oyun.olay('parti',format('%s partisi %s çatısı altında birleşti: %s üye ve %s TL parti kasası aktarıldı.',k.kisa,h.kisa,n,para),null,h.id,t);
 return public.parti_isbirligi_durum(h.id);
end $body$;
create or replace function public.mv_ortak_liste_teklif(p_ortak bigint,p_lider bigint,p_il int) returns jsonb
language plpgsql security definer set search_path='' as $body$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pa oyun.partiler;
 b oyun.partiler; s oyun.secimler; ilan text;
begin
 pa:=oyun.gb_partim(p);
 select * into b from oyun.partiler where id=p_ortak and not kapali and gb is not null;
 if b.id is null or b.id=pa.id then raise exception 'Ortak liste için başka bir aktif parti seç.'; end if;
 if p_lider not in(pa.id,b.id) then raise exception 'Liste sahibi iki partiden biri olmalı.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl seçimi geçersiz.'; end if;
 if not exists(select 1 from oyun.ittifak_uyeler a join oyun.ittifak_uyeler u on u.ittifak_id=a.ittifak_id
                where a.parti_id=pa.id and u.parti_id=b.id) then
  raise exception 'Ortak liste için partilerin aynı ittifakta olması gerekir.'; end if;
 select * into s from oyun.secimler where tur='mv' and durum='bekliyor' and oy_bas>t order by oy_bas limit 1;
 if s.id is null then raise exception 'Henüz ortak liste kurulabilecek yaklaşan genel seçim yok.'; end if;
 if exists(select 1 from oyun.mv_ortak_listeler x where x.secim_id=s.id and x.il_id=p_il
   and x.durum in('bekliyor','kabul') and
   (pa.id in(x.teklif_eden_parti,x.ortak_parti) or b.id in(x.teklif_eden_parti,x.ortak_parti))) then
  raise exception 'Bu ilde taraflardan birinin bekleyen veya kabul edilmiş ortak listesi var.'; end if;
 insert into oyun.mv_ortak_listeler(secim_id,il_id,teklif_eden_parti,ortak_parti,lider_parti,teklif_at)
 values(s.id,p_il,pa.id,b.id,p_lider,t);
 select ad into ilan from oyun.iller where id=p_il;
 perform oyun.bildir(b.gb,format('%s, %s ili için ortak MV listesi teklif etti. Liste sahibi: %s. Parti sayfandan yanıtla.',
 pa.kisa,ilan,(select kisa from oyun.partiler where id=p_lider)),t);
 perform oyun.olay('ittifak',format('%s ve %s arasında %s ili ortak liste görüşmesi başladı.',pa.kisa,b.kisa,ilan),p_il,pa.id,t);
 return public.parti_isbirligi_durum(pa.id);
end $body$;
create or replace function public.mv_ortak_liste_yanit(p_id bigint,p_kabul boolean) returns jsonb
language plpgsql security definer set search_path='' as $body$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); x oyun.mv_ortak_listeler;
 s oyun.secimler; gb uuid;
begin
 select * into x from oyun.mv_ortak_listeler where id=p_id for update;
 if x.id is null or x.durum<>'bekliyor' then raise exception 'Yanıtlanacak liste teklifi bulunamadı.'; end if;
 if not exists(select 1 from oyun.partiler where id=x.ortak_parti and gb=p.id and not kapali) then
  raise exception 'Teklife yalnız davet edilen partinin genel başkanı cevap verebilir.'; end if;
 if p_kabul then
  select * into s from oyun.secimler where id=x.secim_id and durum='bekliyor' and oy_bas>t;
  if s.id is null then raise exception 'Genel seçim oylaması başladı; ortak listeyi artık değiştiremezsin.'; end if;
  if not exists(select 1 from oyun.ittifak_uyeler a join oyun.ittifak_uyeler b on b.ittifak_id=a.ittifak_id
                where a.parti_id=x.teklif_eden_parti and b.parti_id=x.ortak_parti) then
   raise exception 'Partiler artık aynı ittifakta değil.'; end if;
  if exists(select 1 from oyun.mv_ortak_listeler m where m.id<>x.id and m.durum='kabul'
    and m.secim_id=x.secim_id and m.il_id=x.il_id
    and (m.teklif_eden_parti in(x.teklif_eden_parti,x.ortak_parti)
     or m.ortak_parti in(x.teklif_eden_parti,x.ortak_parti))) then
    raise exception 'Bu ilde başka bir kabul edilmiş ortak liste var.'; end if;
 end if;
 update oyun.mv_ortak_listeler set durum=case when p_kabul then 'kabul' else 'ret' end,karar_at=t where id=x.id;
 select gb into gb from oyun.partiler where id=x.teklif_eden_parti;
 if gb is not null then perform oyun.bildir(gb,format('Ortak MV listesi teklifin %s.',case when p_kabul then 'kabul edildi' else 'reddedildi' end),t); end if;
 if p_kabul then
  perform oyun.olay('ittifak',format('%s ve %s, %s ilinde %s partisi listesinde ortak seçime giriyor.',
   (select kisa from oyun.partiler where id=x.teklif_eden_parti),
   (select kisa from oyun.partiler where id=x.ortak_parti),
   (select ad from oyun.iller where id=x.il_id),
   (select kisa from oyun.partiler where id=x.lider_parti)),x.il_id,x.lider_parti,t);
 end if;
 return public.parti_isbirligi_durum(x.ortak_parti);
end $body$;
create or replace function public.mv_ortak_liste_iptal(p_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $body$
declare p oyun.profiller:=oyun.profilim(); x oyun.mv_ortak_listeler;
begin
 select * into x from oyun.mv_ortak_listeler where id=p_id for update;
 if x.id is null or x.durum<>'bekliyor' or not exists(select 1 from oyun.partiler where id=x.teklif_eden_parti and gb=p.id and not kapali)
 then raise exception 'Bu bekleyen teklifi geri çekemezsin.'; end if;
 update oyun.mv_ortak_listeler set durum='iptal',karar_at=oyun.simdi() where id=x.id;
 return public.parti_isbirligi_durum(x.teklif_eden_parti);
end $body$;
revoke all on function oyun.mv_ortak_liste_partisi(bigint,smallint,bigint),
 oyun.parti_birlesme_kilit(timestamptz) from public,anon,authenticated;
revoke all on function public.parti_isbirligi_durum(bigint),
 public.parti_birlesme_teklif(bigint),public.parti_birlesme_iptal(bigint),public.parti_birlesme_yanit(bigint,boolean),
 public.mv_ortak_liste_teklif(bigint,bigint,int),public.mv_ortak_liste_yanit(bigint,boolean),
 public.mv_ortak_liste_iptal(bigint) from public,anon;
grant execute on function public.parti_isbirligi_durum(bigint),
 public.parti_birlesme_teklif(bigint),public.parti_birlesme_iptal(bigint),public.parti_birlesme_yanit(bigint,boolean),
 public.mv_ortak_liste_teklif(bigint,bigint,int),public.mv_ortak_liste_yanit(bigint,boolean),
 public.mv_ortak_liste_iptal(bigint) to authenticated;

-- Normal (test disi) milletvekili sayim motoru: il bazli ortak liste destegi.
CREATE OR REPLACE FUNCTION oyun._sonuc_mv(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  baraj numeric:=(select baraj from oyun.ayarlar where id=1);
  onsecim oyun.secimler;
  toplam bigint;
  il record;
  l record;
  k int;
  ana bigint;
  iller_j jsonb:='{}'::jsonb;
  ilj jsonb;
  bos int:=0;
  dolu int:=0;
  sandalye_top int;
  bag_oy bigint;
  bag_sandalye int;
begin
  -- Geçici düşük oyuncu sayısı test modu: her kesinleşmiş aday seçilir.
  if exists (select 1 from oyun.mv_secim_modu where id = 1 and her_aday_vekil) then
    return oyun._sonuc_mv_test(s);
  end if;
  select * into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;
  select count(*) into toplam from oyun.oylar where secim_id=s.id;
  sandalye_top:=coalesce((select sum(mv_secim) from oyun.iller),600);

  create temp table if not exists _b23_ulusal(
    parti_id bigint primary key,
    oy bigint,
    yuzde numeric,
    gecti boolean,
    sandalye int default 0
  ) on commit drop;
  delete from _b23_ulusal;

  insert into _b23_ulusal(parti_id,oy)
  select parti_id,count(*)
  from oyun.oylar
  where secim_id=s.id and parti_id is not null
  group by parti_id;

  update _b23_ulusal
  set yuzde=case when toplam>0 then round(oy*100.0/toplam,2) else 0 end;

  update _b23_ulusal u
  set gecti=(coalesce(u.oy*100.0/nullif(toplam,0),0)>=baraj) or coalesce((
    select sum(u2.oy)*100.0/nullif(toplam,0)>=baraj
    from oyun.ittifak_uyeler iu
    join oyun.ittifak_uyeler iu2 on iu2.ittifak_id=iu.ittifak_id
    join _b23_ulusal u2 on u2.parti_id=iu2.parti_id
    where iu.parti_id=u.parti_id
  ),false);

  create temp table if not exists _b23_kaz(
    user_id uuid,
    il_id smallint,
    parti_id bigint,
    aday_id bigint
  ) on commit drop;
  delete from _b23_kaz;

  create temp table if not exists _b23_liste(
    anahtar bigint primary key,
    parti_id bigint,
    aday_id bigint,
    oy bigint,
    lim int,
    kaz int default 0
  ) on commit drop;

  for il in select * from oyun.iller order by id loop
    delete from _b23_liste;

    insert into _b23_liste(anahtar,parti_id,aday_id,oy,lim)
    select x.parti_id,x.parti_id,null,x.oy,x.lim
    from (
      select v.lider as parti_id,
             count(*)::bigint oy,
             (select count(*)
              from oyun.adaylar a
              where a.secim_id=onsecim.id
                and a.il_id=il.id
                and a.parti_id is not null
                and oyun.mv_ortak_liste_partisi(s.id,il.id,a.parti_id)=v.lider
                and a.sira is not null)::int lim
      from (
        select oyun.mv_ortak_liste_partisi(s.id,il.id,o.parti_id) as lider
        from oyun.oylar o
        join _b23_ulusal u on u.parti_id=o.parti_id and u.gecti
        where o.secim_id=s.id and o.il_id=il.id and o.parti_id is not null
      ) v
      group by v.lider
    ) x
    where x.lim>0 and x.oy>0;

    insert into _b23_liste(anahtar,parti_id,aday_id,oy,lim)
    select -a.id,null,a.id,count(o.*)::bigint,1
    from oyun.adaylar a
    join oyun.oylar o
      on o.secim_id=s.id and o.aday_id=a.id
    where a.secim_id=s.id
      and a.parti_id is null
      and a.il_id=il.id
    group by a.id
    having count(o.*)>0;

    for k in 1..coalesce(il.mv_secim,il.mv) loop
      ana:=null;
      select anahtar into ana
      from _b23_liste
      where kaz<lim and oy>0
      order by oy::numeric/(kaz+1) desc,oy desc,anahtar
      limit 1;
      exit when ana is null;
      update _b23_liste set kaz=kaz+1 where anahtar=ana;
    end loop;

    for l in select * from _b23_liste where parti_id is not null and kaz>0 loop
      insert into _b23_kaz(user_id,il_id,parti_id,aday_id)
      select a.user_id,il.id,a.parti_id,a.id
      from oyun.adaylar a
      where a.secim_id=onsecim.id
        and a.il_id=il.id
        and a.parti_id is not null
        and oyun.mv_ortak_liste_partisi(s.id,il.id,a.parti_id)=l.parti_id
        and a.sira is not null
      order by a.sira, case when a.parti_id=l.parti_id then 0 else 1 end, a.id
      limit l.kaz;
    end loop;

    insert into _b23_kaz(user_id,il_id,parti_id,aday_id)
    select a.user_id,il.id,null,a.id
    from _b23_liste l
    join oyun.adaylar a on a.id=l.aday_id
    where l.parti_id is null and l.kaz>0;

    select jsonb_build_object(
      'gecerli',(select count(*) from oyun.oylar where secim_id=s.id and il_id=il.id),
      'partiler',coalesce((
        select jsonb_object_agg(o.parti_id::text,jsonb_build_object(
          'oy',o.n,
          'sandalye',(select count(*) from _b23_kaz z where z.il_id=il.id and z.parti_id=o.parti_id)
        ))
        from (
          select parti_id,count(*) n
          from oyun.oylar
          where secim_id=s.id and il_id=il.id and parti_id is not null
          group by parti_id
        ) o
      ),'{}'::jsonb),
      'bagimsizlar',coalesce((
        select jsonb_agg(jsonb_build_object(
          'aday_id',a.id,
          'kad',pr.kad,
          'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
          'sandalye',case when exists(select 1 from _b23_kaz z where z.aday_id=a.id) then 1 else 0 end
        ) order by (select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id) desc,a.id)
        from oyun.adaylar a
        join oyun.profiller pr on pr.id=a.user_id
        where a.secim_id=s.id and a.parti_id is null and a.il_id=il.id
      ),'[]'::jsonb),
      'secilen',coalesce((
        select jsonb_agg(jsonb_build_object(
          'kad',pr.kad,
          'parti_id',z.parti_id,
          'bagimsiz',z.parti_id is null
        ) order by z.parti_id nulls last,pr.kad)
        from _b23_kaz z
        join oyun.profiller pr on pr.id=z.user_id
        where z.il_id=il.id
      ),'[]'::jsonb),
      'mv',coalesce(il.mv_secim,il.mv)
    ) into ilj;

    if (ilj->>'gecerli')::int>0 or jsonb_array_length(ilj->'secilen')>0 then
      iller_j:=iller_j||jsonb_build_object(il.id::text,ilj);
    end if;
  end loop;

  -- Sandalyeler liste sahibine değil, seçilen adayların kendi partilerine yazılır.
  update _b23_ulusal u set sandalye=(select count(*) from _b23_kaz z where z.parti_id=u.parti_id);

  insert into oyun.kazananlar(secim_id,user_id,il_id,parti_id)
  select s.id,user_id,il_id,parti_id from _b23_kaz
  on conflict do nothing;

  select count(*) into dolu from _b23_kaz;
  bos:=sandalye_top-dolu;
  select count(*) into bag_oy
  from oyun.oylar where secim_id=s.id and parti_id is null and aday_id is not null;
  select count(*) into bag_sandalye
  from _b23_kaz where parti_id is null;

  perform oyun.olay(
    'secim',
    format('Genel seçim sonuçlandı: %s oy kullanıldı, %s sandalye doldu, %s sandalye boş kaldı.',toplam,dolu,bos),
    null,null,s.sonuc_at
  );

  return jsonb_build_object(
    'toplam',toplam,
    'baraj',baraj,
    'sandalye_toplam',sandalye_top,
    'dolu',dolu,
    'bos',bos,
    'bagimsiz_oy',bag_oy,
    'bagimsiz_sandalye',bag_sandalye,
    'bagimsizlar',coalesce((
      select jsonb_agg(jsonb_build_object(
        'aday_id',a.id,
        'kad',pr.kad,
        'il_id',a.il_id,
        'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
        'sandalye',case when exists(select 1 from _b23_kaz z where z.aday_id=a.id) then 1 else 0 end
      ) order by (select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id) desc,a.id)
      from oyun.adaylar a
      join oyun.profiller pr on pr.id=a.user_id
      where a.secim_id=s.id and a.parti_id is null
    ),'[]'::jsonb),
    'ulusal',coalesce((
      select jsonb_agg(jsonb_build_object(
        'parti_id',u.parti_id,
        'kisa',p.kisa,
        'ad',p.ad,
        'renk',p.renk,
        'oy',u.oy,
        'yuzde',u.yuzde,
        'gecti',u.gecti,
        'sandalye',u.sandalye
      ) order by u.oy desc)
      from _b23_ulusal u
      join oyun.partiler p on p.id=u.parti_id
    ),'[]'::jsonb),
    'iller',iller_j
  );
end $function$
;
