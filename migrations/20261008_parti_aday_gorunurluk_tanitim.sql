-- Seçimlerin mevcut aday kayıtları korunur.
-- Yalnızca gerçek oyuncular, gerçek parti liderleri ve aktif seçim takvimi kullanılır.
create table if not exists oyun.parti_aday_tanitim (
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id),
 aday_id bigint not null references oyun.adaylar(id) on delete cascade,
 kitle text not null check(kitle in ('herkes','uyeler')),
 metin text not null check(length(metin) between 20 and 600),
 yayinlayan uuid not null references auth.users(id),
 zaman timestamptz not null default now()
);
create index if not exists parti_aday_tanitim_idx on oyun.parti_aday_tanitim(parti_id,zaman desc);
alter table oyun.parti_aday_tanitim enable row level security;
revoke all on oyun.parti_aday_tanitim from public,anon,authenticated;

create or replace function public.parti_aday_kart(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare
 u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
 p oyun.partiler; cb oyun.secimler; k oyun.cb_kararlar;
 cb_id uuid; cb_parti bigint; cb_durum text; ben_uye boolean;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.partiler where id=p_parti and not kapali;
 if not found then raise exception 'Parti bulunamadı'; end if;
 ben_uye:=exists(select 1 from oyun.profiller where id=u and parti_id=p_parti);
 select * into cb from oyun.secimler s
 where s.tur='cb' and s.durum='bekliyor' and s.oy_bit>=t and s.basvuru_bas<=t
 order by s.ara desc,s.oy_bas asc limit 1;
 if cb.id is not null then
  select * into k from oyun.cb_kararlar where donem=cb.donem and parti_id=p_parti;
  if k.yontem='destek' then
   cb_parti:=k.destek_parti; cb_durum:='destek';
  else
   cb_parti:=p_parti;cb_durum:=case when k.yontem='onsecim' then 'onsecim' else 'aday' end;
  end if;
  select a.user_id into cb_id from oyun.adaylar a
   where a.secim_id=cb.id and a.parti_id=cb_parti order by a.basvuru_at limit 1;
  if cb_id is null and cb_parti=p_parti and k.yontem in ('kendisi','baskasi') then cb_id:=k.aday; end if;
 end if;
 return jsonb_build_object(
 'parti_id',p.id,'uye_mi',ben_uye,'genel_baskan_mi',p.gb=u,
 'cb',case when cb.id is null then null else
    jsonb_build_object('secim_id',cb.id,'donem',cb.donem,'aday',oyun.kad(cb_id),
      'aday_id',cb_id,'aday_partisi',coalesce((select kisa from oyun.partiler where id=cb_parti),p.kisa),
      'aday_parti_id',cb_parti,
      'asama',case when cb_id is not null then 'kesin'
        when k.yontem='destek' then 'destek_bekliyor'
        when k.yontem='onsecim' then 'onsecim_bekliyor' else 'henüz_belirlenmedi' end,
      'destekleyenler',coalesce((
       select jsonb_agg(jsonb_build_object('id',pa.id,'kisa',pa.kisa,'ad',pa.ad) order by pa.id)
       from oyun.cb_kararlar x join oyun.partiler pa on pa.id=x.parti_id
       where x.donem=cb.donem and x.yontem='destek' and x.destek_parti=cb_parti
      ),'[]'::jsonb)) end,
 'aday_adaylari',case when ben_uye then coalesce((
   select jsonb_agg(jsonb_build_object(
      'id',a.id,'tur',s.tur,'kad',pr.kad,'il_id',a.il_id,'il',(select ad from oyun.iller where id=a.il_id),
      'secim_id',s.id,'donem',s.donem,'sira',a.sira,'basvuru',a.basvuru_at
   ) order by s.oy_bas,a.basvuru_at,a.id)
   from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
   join oyun.profiller pr on pr.id=a.user_id
   where a.parti_id=p_parti and s.tur in ('mv_on','cb_on')
     and s.durum='bekliyor' and s.basvuru_bas<=t and s.oy_bit>=t
 ),'[]'::jsonb) else '[]'::jsonb end,
 'kesin_adaylar',coalesce((
   select jsonb_agg(jsonb_build_object(
     'id',a.id,'tur',s.tur,'kad',pr.kad,'il_id',a.il_id,
     'il',(select ad from oyun.iller where id=a.il_id),'sira',a.sira,
     'secim_id',s.id,'donem',s.donem
   ) order by s.oy_bas,a.il_id,a.sira,a.id)
   from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id
   join oyun.profiller pr on pr.id=a.user_id
   where a.parti_id=p_parti and
      ((s.tur in ('cb','bel') and s.durum='bekliyor' and s.oy_bit>=t) or
       (s.tur='mv_on' and a.sira is not null and exists(
         select 1 from oyun.secimler m where m.tur='mv' and m.donem=s.donem
            and m.durum='bekliyor' and m.oy_bit>=t)))
 ),'[]'::jsonb),
 'tanitimlar',coalesce((
   select jsonb_agg(jsonb_build_object(
     'id',x.id,'tur',s.tur,'kad',oyun.kad(a.user_id),
     'il',(select ad from oyun.iller where id=a.il_id),
     'kitle',x.kitle,'metin',x.metin,'yayinlayan',oyun.kad(x.yayinlayan),'zaman',x.zaman
   ) order by x.zaman desc,x.id desc)
   from (select * from oyun.parti_aday_tanitim
        where parti_id=p_parti and (kitle='herkes' or ben_uye)
        order by zaman desc,id desc limit 30) x
   join oyun.adaylar a on a.id=x.aday_id join oyun.secimler s on s.id=a.secim_id
 ),'[]'::jsonb));
end $function$;
revoke all on function public.parti_aday_kart(bigint) from public,anon;
grant execute on function public.parti_aday_kart(bigint) to authenticated;

create or replace function public.parti_aday_tanit(p_aday bigint,p_kitle text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare u uuid:=auth.uid(); p oyun.partiler; a oyun.adaylar; s oyun.secimler;
 t timestamptz:=oyun.simdi(); metin text:=btrim(coalesce(p_metin,'')); newid bigint;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 select * into p from oyun.partiler where gb=u and not kapali;
 if not found then raise exception 'Yalnızca parti genel başkanı aday tanıtabilir';end if;
 if p_kitle not in ('herkes','uyeler') or p_kitle is null then raise exception 'Tanıtım kitlesi geçersiz';end if;
 if length(metin)<20 or length(metin)>600 then raise exception 'Tanıtım 20-600 karakter olmalı';end if;
 select * into a from oyun.adaylar where id=p_aday;
 if not found then raise exception 'Aday kaydı bulunamadı';end if;
 select * into s from oyun.secimler where id=a.secim_id;
 if s.tur not in ('mv_on','cb_on','cb','bel_on','bel')
   or s.durum<>'bekliyor' or s.oy_bit<=t or s.basvuru_bas>t and s.tur in ('mv_on','cb_on','bel_on')
 then raise exception 'Bu seçimde aday tanıtım zamanı kapalı';end if;
 if a.parti_id is distinct from p.id
 and not (
   (s.tur='cb' and exists(select 1 from oyun.cb_kararlar k
      where k.donem=s.donem and k.parti_id=p.id and k.yontem='destek' and k.destek_parti=a.parti_id))
   or
   (s.tur='bel' and exists(select 1 from oyun.bel_aday_destek b
      where b.secim_id=s.id and b.parti_id=p.id and b.aday_id=a.id))
 ) then raise exception 'Yalnızca kendi partinin veya resmen desteklediğin adayı tanıtabilirsin';end if;
 if (select count(*) from oyun.parti_aday_tanitim where parti_id=p.id and zaman>=t-interval '24 hours')>=3
 then raise exception 'Partin 24 saatte en fazla 3 aday tanıtımı yapabilir';end if;
 insert into oyun.parti_aday_tanitim(parti_id,aday_id,kitle,metin,yayinlayan,zaman)
 values(p.id,a.id,p_kitle,metin,u,t) returning id into newid;
 if p_kitle='herkes' then
  perform oyun.olay('parti',left(p.kisa||' aday tanıtımı: '||oyun.kad(a.user_id),120),null,p.id,t);
 end if;
 return jsonb_build_object('tamam',true,'id',newid,'parti_id',p.id,'kitle',p_kitle);
end $function$;
revoke all on function public.parti_aday_tanit(bigint,text,text) from public,anon;
grant execute on function public.parti_aday_tanit(bigint,text,text) to authenticated;
