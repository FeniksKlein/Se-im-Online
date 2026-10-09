-- 2026-10-09 | Il bazli sinirli emlak, haftalik belediye vergisi ve TBMM vekil olcegi.
-- Mevcut tapular, cuzdanlar ve aktif vekillikler korunur.
create table if not exists oyun.emlak_vergi_ayar(
 id integer primary key check (id=1),
 ulusal_oran numeric not null default 0.50 check (ulusal_oran between 0 and 1),
 baslangic timestamptz not null default now(),
 degisiklik timestamptz not null default now()
);
insert into oyun.emlak_vergi_ayar(id,ulusal_oran,baslangic,degisiklik)
values(1,0.50,oyun.simdi(),oyun.simdi()) on conflict(id) do nothing;

create table if not exists oyun.emlak_vergi_il(
 il_id smallint primary key references oyun.iller(id),
 ek_oran numeric not null default 0 check(ek_oran between -0.25 and 0.25),
 baskan uuid references oyun.profiller(id),
 degisiklik timestamptz not null default now()
);
alter table oyun.yatirim_mulkleri add column if not exists emlak_vergi_sonraki timestamptz;
update oyun.yatirim_mulkleri set emlak_vergi_sonraki=oyun.simdi()+interval '7 days'
where emlak_vergi_sonraki is null;
alter table oyun.yatirim_mulkleri alter column emlak_vergi_sonraki set not null;

alter table oyun.emlak_vergi_ayar enable row level security;
alter table oyun.emlak_vergi_il enable row level security;
revoke all on oyun.emlak_vergi_ayar from public,anon,authenticated;
revoke all on oyun.emlak_vergi_il from public,anon,authenticated;

create or replace function oyun.emlak_vergi_orani(p_il smallint) returns numeric
language sql stable set search_path='' as $$
 select greatest(0,least(1,
  (select ulusal_oran from oyun.emlak_vergi_ayar where id=1)
  +coalesce((select ek_oran from oyun.emlak_vergi_il where il_id=p_il),0)))
$$;

-- Oyundaki il milletvekili dagilimi nufus buyuklugunun vekil agirlikli gostergesidir.
-- 96 vekil: 100 daire, 1 vekil: 8 daire; dukkan ve villa stoklari ayridir.
create or replace function oyun.emlak_kapasite(p_il smallint,p_tip text) returns integer
language sql stable set search_path='' as $$
 select greatest(1,
 case p_tip when 'daire' then 8 when 'dukkan' then 2 when 'villa' then 2 else 0 end +
 round((greatest(1,i.mv)-1)::numeric / 95 *
  (case p_tip when 'daire' then 92 when 'dukkan' then 28 when 'villa' then 18 else 0 end)
  *(1+(coalesce(d.gelisim,50)-50)/500.0))::int)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;

create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round(
 (case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
 *(0.62+2.15*greatest(1,i.mv)/96.0)
 *(0.8+coalesce(d.gelisim,50)/250.0)
 ,0)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_kira(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round(oyun.emlak_fiyat(p_il,p_tip)*0.025,0)
$$;

create or replace function public.emlak_il_stok() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Giriş yapmalısın.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'il_id',a.il_id,'il',a.ad,'tur',a.tip,'kapasite',a.kapasite,'satilan',a.satilan,
  'kalan',greatest(0,a.kapasite-a.satilan),'fiyat',oyun.emlak_fiyat(a.il_id,a.tip),
  'haftalik',oyun.emlak_kira(a.il_id,a.tip),'vergi_orani',oyun.emlak_vergi_orani(a.il_id),
  'haftalik_vergi',round(oyun.emlak_fiyat(a.il_id,a.tip)*oyun.emlak_vergi_orani(a.il_id)/100,0)
 ) order by a.ad,a.tip) from (
  select i.id il_id,i.ad,tip,oyun.emlak_kapasite(i.id,tip) kapasite,
    (select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=tip) satilan
  from oyun.iller i cross join (values('daire'),('dukkan'),('villa')) t(tip)
 ) a),'[]'::jsonb);
end $$;
revoke all on function public.emlak_il_stok() from public,anon;
grant execute on function public.emlak_il_stok() to authenticated;

-- Eski cagrilar kendi ilinden satin alir; yeni istemci tum 81 ilden alabilir.
create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric;
 t timestamptz:=oyun.simdi(); yeni_mulk_id bigint; cap int; n int;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Geçerli bir oyuncu profili gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçersiz il.'; end if;
 perform pg_advisory_xact_lock(77124,p_il::int*10+
  case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 cap:=oyun.emlak_kapasite(p_il,p_tip);
 select count(*) into n from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if n>=cap then raise exception 'Bu şehirde satılabilir % stoku doldu.',p_tip; end if;
 bedel:=oyun.emlak_fiyat(p_il,p_tip);
 kira:=oyun.emlak_kira(p_il,p_tip);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s / %s devlet gayrimenkul alımı',p_tip,(select ad from oyun.iller where id=p_il)),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,emlak_vergi_sonraki)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days',t+interval '7 days')
 returning id into yeni_mulk_id;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni_mulk_id,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;

create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language sql security definer set search_path='' as $$
 select public.mulk_satin_al(p_tip,(select il_id from oyun.profiller where id=auth.uid()))
$$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.emlak_vergi_durum(p_il smallint default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare il smallint;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
 il:=coalesce(p_il,(select il_id from oyun.profiller where id=auth.uid()));
 return jsonb_build_object('ulusal',(select ulusal_oran from oyun.emlak_vergi_ayar where id=1),
 'yerel',coalesce((select ek_oran from oyun.emlak_vergi_il where il_id=il),0),
 'toplam',oyun.emlak_vergi_orani(il),'il',il,
 'baskan_miyim',exists(select 1 from oyun.makamlar where user_id=auth.uid() and tur='bel' and il_id=il and bit is null),
 'son',(select degisiklik from oyun.emlak_vergi_il where il_id=il));
end $$;
revoke all on function public.emlak_vergi_durum(smallint) from public,anon;
grant execute on function public.emlak_vergi_durum(smallint) to authenticated;

create or replace function public.emlak_vergi_belediye(p_ek_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar:=oyun.baskan_zorunlu(p); oldt timestamptz;
 t timestamptz:=oyun.simdi();
begin
 if p_ek_oran is null or p_ek_oran<>round(p_ek_oran,2) or p_ek_oran not between -0.25 and 0.25 then
  raise exception 'Belediyenin yetkisi ulusal orana -0,25 ile +0,25 puan eklemektir.'; end if;
 select degisiklik into oldt from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if oldt>t-interval '24 hours' then raise exception 'Emlak vergisi 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_vergi_il(il_id,ek_oran,baskan,degisiklik)
 values(m.il_id,p_ek_oran,p.id,t)
 on conflict(il_id) do update set ek_oran=excluded.ek_oran,baskan=excluded.baskan,degisiklik=excluded.degisiklik;
 perform oyun.olay('belediye',format('%s Belediye Başkanı haftalık emlak vergisini %s olarak belirledi.',
 (select ad from oyun.iller where id=m.il_id),oyun.emlak_vergi_orani(m.il_id)),m.il_id,p.parti_id,t);
 return public.emlak_vergi_durum(m.il_id);
end $$;
revoke all on function public.emlak_vergi_belediye(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye(numeric) to authenticated;

create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); su record; bid bigint;
 bas text:=btrim(coalesce(p_baslik,'')); gerekce text;
begin
 if not oyun.aktif_vekil(p.id) or exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null)
 then raise exception 'Yalnızca oy kullanabilen milletvekilleri teklif verebilir.'; end if;
 if p_oran is null or p_oran<>round(p_oran,2) or p_oran not between 0 and 1 then raise exception 'Haftalık emlak vergisi %%0-%%1 arasında olmalıdır.'; end if;
 if length(bas) not between 5 and 120 or oyun.kufurlu(bas) then raise exception 'Geçersiz kanun başlığı.'; end if;
 gerekce:=oyun.metin_temizle(p_metin,3000);
 if length(gerekce)<10 then raise exception 'Gerekçe en az 10 karakter olmalı.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr'))
 then raise exception 'Sonuçlanmamış bir teklifin var.'; end if;
 select * into su from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',bas,gerekce,jsonb_build_object('ozel_tur','emlak_vergisi','oran',p_oran),
 p.id,p.parti_id,t,t+su.gorusme,t+su.gorusme+su.oylama) returning id into bid;
 perform oyun.olay('meclis',format('%s haftalık emlak vergisini %s yapacak kanunu sundu.',p.kad,p_oran),null,p.parti_id,t);
 return jsonb_build_object('id',bid,'oran',p_oran);
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text,text) to authenticated;

create or replace function oyun.emlak_vergi_kanun_yururluk() returns trigger
language plpgsql security definer set search_path='' as $$
declare o numeric;
begin
 if old.durum<>'yururlukte' and new.durum='yururlukte'
 and new.veri->>'ozel_tur'='emlak_vergisi' then
  o:=(new.veri->>'oran')::numeric;
  if o is null or o<0 or o>1 then raise exception 'Geçersiz emlak vergisi kanunu.'; end if;
  update oyun.emlak_vergi_ayar set ulusal_oran=o,degisiklik=oyun.simdi() where id=1;
  perform oyun.olay('meclis',format('TBMM haftalık emlak vergisi ulusal tabanını %s yaptı.',o),null,new.teklif_parti,oyun.simdi());
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_aktif on oyun.kanunlar;
create trigger emlak_vergi_kanun_aktif after update of durum on oyun.kanunlar
for each row execute function oyun.emlak_vergi_kanun_yururluk();

-- Yeniden ölçeklendirmeyi kapat: teorik sandalye sayısı 600, gerçek doluluk oyunculara bağlı.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
