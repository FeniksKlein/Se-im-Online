
-- Player-run conference/concert/fair with venues, sponsorship, player tickets, bounded NPC audience.
create table if not exists oyun.uc_etkinlik(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id), il_id smallint not null references oyun.iller(id),
 baslik text not null check(length(baslik) between 5 and 90),
 tur text not null check(tur in ('konferans','forum','konser','fuar')),
 zaman timestamptz not null, kapasite int not null check(kapasite between 30 and 500),
 bilet numeric not null check(bilet between 50 and 3000),
 mekan_gider numeric not null, satilan int not null default 0, npc_satis int not null default 0,
 bilet_ciro numeric not null default 0, sponsor_toplam numeric not null default 0,
 son_kar numeric, durum text not null default 'planlandi' check(durum in ('planlandi','bitti')),
 kurulus timestamptz not null default now()
);
create index if not exists uc_etkinlik_takvim on oyun.uc_etkinlik(zaman) where durum='planlandi';
create table if not exists oyun.uc_etkinlik_bilet(
 etkinlik_id bigint not null references oyun.uc_etkinlik(id),
 alici uuid not null references oyun.profiller(id),
 tutar numeric not null,zaman timestamptz not null default now(),primary key(etkinlik_id,alici)
);
create table if not exists oyun.uc_etkinlik_sponsor(
 etkinlik_id bigint not null references oyun.uc_etkinlik(id),
 sirket_id bigint not null references oyun.sirketler(id),
 tutar numeric not null,zaman timestamptz not null default now(),primary key(etkinlik_id,sirket_id)
);
revoke all on oyun.uc_etkinlik,oyun.uc_etkinlik_bilet,oyun.uc_etkinlik_sponsor from public,anon,authenticated;
alter table oyun.uc_etkinlik enable row level security;
alter table oyun.uc_etkinlik_bilet enable row level security;
alter table oyun.uc_etkinlik_sponsor enable row level security;
create or replace function public.uc_etkinlik_panel() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid();
begin
 perform oyun.profilim();
 return jsonb_build_object(
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,'sektor',s.sektor))
 from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id
 where s.aktif and o.user_id=u and o.pay>=50),'[]'::jsonb),
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad) order by ad) from oyun.iller),'[]'::jsonb),
 'etkinlikler',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'baslik',v.baslik,'tur',v.tur,
  'sirket',v.sirket_id,'sirket_ad',s.ad,'il',v.il_id,'zaman',v.zaman,'bilet',v.bilet,
  'kapasite',v.kapasite,'satilan',v.satilan,'npc_satis',v.npc_satis,'ciro',v.bilet_ciro,
  'sponsor',v.sponsor_toplam,'mekan',v.mekan_gider,'kar',v.son_kar,'durum',v.durum,
  'biletim',exists(select 1 from oyun.uc_etkinlik_bilet b where b.etkinlik_id=v.id and b.alici=u)))
  from oyun.uc_etkinlik v join oyun.sirketler s on s.id=v.sirket_id
  where v.durum='planlandi' or v.zaman>oyun.simdi()-interval '7 days'),'[]'::jsonb));
end $$;
revoke all on function public.uc_etkinlik_panel() from public,anon;
grant execute on function public.uc_etkinlik_panel() to authenticated;
create or replace function public.uc_etkinlik_islem(p_islem text,p_id bigint,p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); s oyun.sirketler;
 v oyun.uc_etkinlik; sid bigint; baslik text; tur text; il smallint;
 qty int; price numeric; cost numeric; start_at timestamptz; amount numeric; eventid bigint;
begin
 perform oyun.profilim();
 if p_veri is null or jsonb_typeof(p_veri)<>'object' then raise exception 'Veri hatalı';end if;
 if p_islem='kur' then
  select * into s from oyun.sirketler where id=p_id and aktif and sektor in ('medya','ajans') for update;
  if s.id is null or not exists(select 1 from oyun.sirket_ortaklari o
   where o.sirket_id=s.id and o.user_id=u and o.pay>=50)
  then raise exception 'Etkinlik açmak için yönettiğin medya veya ajans şirketi gerekli';end if;
  baslik:=trim(coalesce(p_veri->>'baslik',''));tur:=p_veri->>'tur';
  il:=nullif(p_veri->>'il','')::smallint;
  start_at:=nullif(p_veri->>'zaman','')::timestamptz;
  qty:=coalesce(nullif(p_veri->>'kapasite','')::int,0);
  price:=coalesce(nullif(p_veri->>'bilet','')::numeric,0);
  if length(baslik) not between 5 and 90 or tur not in ('konferans','forum','konser','fuar')
  or il is null or not exists(select 1 from oyun.iller where id=il)
  or start_at is null or start_at<t+interval '12 hours' or start_at>t+interval '7 days'
  or qty not between 30 and 500 or price not between 50 and 3000
  then raise exception 'Başlık, il, tarih, kapasite veya bilet fiyatı geçersiz';end if;
  if (select count(*) from oyun.uc_etkinlik where sirket_id=s.id and durum='planlandi')>=3
  then raise exception 'Bir şirket en fazla 3 açık organizasyon düzenleyebilir';end if;
  cost:=5000+qty*80;
  update oyun.sirketler set kasa=kasa-cost where id=s.id and kasa>=cost;
  if not found then raise exception 'Salon kirası için şirket kasası yetersiz';end if;
  insert into oyun.uc_etkinlik(sirket_id,il_id,baslik,tur,zaman,kapasite,bilet,mekan_gider,kurulus)
  values(s.id,il,baslik,tur,start_at,qty,price,cost,t) returning id into eventid;
  return jsonb_build_object('id',eventid,'mekan_gider',cost,'durum','planlandi');
 elsif p_islem='bilet_al' then
  select * into v from oyun.uc_etkinlik where id=p_id for update;
  if v.id is null or v.durum<>'planlandi' or v.zaman<=t or v.satilan>=v.kapasite
  then raise exception 'Etkinlik satışa kapalı veya biletler tükendi';end if;
  if exists(select 1 from oyun.uc_etkinlik_bilet where etkinlik_id=p_id and alici=u)
  then raise exception 'Bu etkinlik için zaten biletin var';end if;
  perform oyun.cuzdanim(u);
  update oyun.cuzdan set para=para-v.bilet where user_id=u and para>=v.bilet;
  if not found then raise exception 'Cüzdanında yeterli para yok';end if;
  insert into oyun.uc_etkinlik_bilet(etkinlik_id,alici,tutar,zaman) values(v.id,u,v.bilet,t);
  update oyun.sirketler set kasa=kasa+v.bilet where id=v.sirket_id and aktif;
  if not found then raise exception 'Organizatör şirket faal değil';end if;
  update oyun.uc_etkinlik set satilan=satilan+1,bilet_ciro=bilet_ciro+v.bilet where id=v.id;
  return jsonb_build_object('bilet',v.id,'bedel',v.bilet);
 elsif p_islem='sponsor' then
  select * into v from oyun.uc_etkinlik where id=p_id for update;
  sid:=nullif(p_veri->>'sirket','')::bigint;
  amount:=coalesce(nullif(p_veri->>'tutar','')::numeric,0);
  select * into s from oyun.sirketler where id=sid and aktif for update;
  if v.id is null or v.durum<>'planlandi' or v.zaman<=t or s.id is null
  or s.id=v.sirket_id or amount<1000 or amount>100000
  or not exists(select 1 from oyun.sirket_ortaklari where sirket_id=sid and user_id=u and pay>=50)
  then raise exception 'Sponsorluk yetkisi veya tutarı geçersiz';end if;
  if exists(select 1 from oyun.uc_etkinlik_sponsor where etkinlik_id=v.id and sirket_id=s.id)
  then raise exception 'Bu şirket zaten sponsor oldu';end if;
  update oyun.sirketler set kasa=kasa-amount where id=s.id and kasa>=amount;
  if not found then raise exception 'Şirket kasası yetersiz';end if;
  update oyun.sirketler set kasa=kasa+amount where id=v.sirket_id and aktif;
  if not found then raise exception 'Organizatör faal değil';end if;
  insert into oyun.uc_etkinlik_sponsor(etkinlik_id,sirket_id,tutar,zaman) values(v.id,s.id,amount,t);
  update oyun.uc_etkinlik set sponsor_toplam=sponsor_toplam+amount where id=v.id;
  return jsonb_build_object('etkinlik',v.id,'sponsor',amount);
 end if;
 raise exception 'Bilinmeyen etkinlik işlemi';
end $$;
revoke all on function public.uc_etkinlik_islem(text,bigint,jsonb) from public,anon;
grant execute on function public.uc_etkinlik_islem(text,bigint,jsonb) to authenticated;
create or replace function oyun.uc_etkinlik_tick() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare t timestamptz:=oyun.simdi(); v record; guest int;
 npc numeric; staff numeric; kdv numeric; matrah numeric; kv numeric; cnt int:=0;
begin
 if not pg_try_advisory_xact_lock(927615) then return jsonb_build_object('kilitli',true);end if;
 for v in select x.*,s.aktif from oyun.uc_etkinlik x join oyun.sirketler s on s.id=x.sirket_id
 where x.durum='planlandi' and x.zaman<=t order by x.id limit 100 for update of x skip locked
 loop
  guest:=case when v.aktif then least(v.kapasite-v.satilan,
   greatest(0,round(v.kapasite*.55*sqrt(500.0/greatest(100,v.bilet)))::int)) else 0 end;
  guest:=greatest(0,guest);npc:=guest*v.bilet;
  staff:=round((v.bilet_ciro+npc)*.15);
  kdv:=oyun.eko_vergi_hesap('satis',v.bilet_ciro+npc);
  matrah:=greatest(0,v.bilet_ciro+npc+v.sponsor_toplam-v.mekan_gider-staff-kdv);
  kv:=oyun.eko_vergi_hesap('kar',matrah);
  update oyun.sirketler set kasa=kasa+npc-staff-kdv-kv where id=v.sirket_id;
  if oyun.eko_vergi_tahsil(v.sirket_id,'satis',v.bilet_ciro+npc,'uc_etkinlik_satis',v.id)<>kdv
  then raise exception 'Etkinlik satış vergisi uyuşmadı';end if;
  if oyun.eko_vergi_tahsil(v.sirket_id,'kar',matrah,'uc_etkinlik_kar',v.id)<>kv
  then raise exception 'Etkinlik kâr vergisi uyuşmadı';end if;
  update oyun.uc_etkinlik set satilan=satilan+guest,npc_satis=guest,
  bilet_ciro=bilet_ciro+npc,son_kar=v.bilet_ciro+npc+v.sponsor_toplam-v.mekan_gider-staff-kdv-kv,
  durum='bitti' where id=v.id;
  cnt:=cnt+1;
 end loop;
 return jsonb_build_object('tamamlanan_etkinlik',cnt);
end $$;
revoke all on function oyun.uc_etkinlik_tick() from public,anon,authenticated;
do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  perform cron.schedule('uc-etkinlik-bitir','*/10 * * * *','select oyun.uc_etkinlik_tick();');
 end if;
end $$;
